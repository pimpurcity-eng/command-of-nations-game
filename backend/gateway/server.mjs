import { createServer } from 'node:http';
import { pathToFileURL } from 'node:url';

const uuid = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const countries = new Set(['russia', 'ukraine']);
const identifier = value => typeof value === 'string' && /^[A-Za-z0-9_.:-]{1,80}$/.test(value);
const exact = (data, keys) => data && typeof data === 'object' && !Array.isArray(data)
  && Object.keys(data).length === keys.length && keys.every(key => Object.hasOwn(data, key));

export function validOrder(data) {
  if (!exact(data, ['request_id', 'kind', 'payload']) || !uuid.test(data.request_id)) return false;
  const p = data.payload;
  if (data.kind === 'move') return exact(p, ['unit_id', 'destination']) && identifier(p.unit_id)
    && exact(p.destination, ['x', 'z']) && [p.destination.x, p.destination.z].every(n =>
      typeof n === 'number' && Number.isFinite(n) && Math.abs(n) <= 1000000);
  if (data.kind === 'research') return exact(p, ['equipment_id']) && identifier(p.equipment_id);
  if (data.kind === 'produce') return exact(p, ['equipment_id', 'city_id'])
    && identifier(p.equipment_id) && identifier(p.city_id);
  return false;
}

export function rateLimiter({ limit = 60, windowMs = 60000, capacity = 10000, now = Date.now } = {}) {
  const entries = new Map();
  return key => {
    const time = now();
    for (const [id, bucket] of entries) if (bucket.until <= time) entries.delete(id);
    let bucket = entries.get(key);
    if (!bucket) {
      if (entries.size >= capacity) return false;
      bucket = { count: 0, until: time + windowMs }; entries.set(key, bucket);
    }
    return ++bucket.count <= limit;
  };
}

export function supabaseService({ url, publicKey, serviceKey, fetchImpl = fetch }) {
  const base = new URL(url);
  if (base.protocol !== 'https:' || base.pathname !== '/' || base.search || base.hash
      || base.username || base.password || !publicKey?.startsWith('sb_publishable_') || !serviceKey)
    throw new Error('Valid HTTPS Supabase URL, public key and server key are required.');
  const call = async (path, headers, body) => {
    const response = await fetchImpl(new URL(path, base), {
      method: body === undefined ? 'GET' : 'POST', headers,
      body: body === undefined ? undefined : JSON.stringify(body),
      signal: AbortSignal.timeout(10000), redirect: 'error'
    });
    if (!response.ok) throw Object.assign(new Error('Backend request failed'), { status: response.status });
    return response.status === 204 ? null : response.json();
  };
  return {
    // The Auth server validates the token. Never trust decoded client claims or a caller's user ID.
    authenticate: token => call('/auth/v1/user', { apikey: publicKey, Authorization: `Bearer ${token}` }),
    rpc: (name, params) => call(`/rest/v1/rpc/${name}`, {
      apikey: serviceKey, 'Content-Type': 'application/json',
      // Legacy service-role JWTs use Bearer too; sb_secret_ keys go in apikey only.
      ...(serviceKey.startsWith('sb_secret_') ? {} : { Authorization: `Bearer ${serviceKey}` })
    }, params)
  };
}

export function gateway({ authenticate, rpc, allow = rateLimiter(), multiplayerEnabled = false,
  origins = ['https://warfrontmandate.com', 'https://warfront-mandate.pages.dev'] }) {
  return async (request, clientAddress = 'local') => {
    const origin = request.headers.get('origin');
    const headers = { 'Content-Type': 'application/json', 'Cache-Control': 'no-store',
      'X-Content-Type-Options': 'nosniff', Vary: 'Origin' };
    const reply = (status, value) => new Response(JSON.stringify(value), { status, headers });
    if (origin && !origins.includes(origin)) return reply(403, { error: 'Origin not allowed' });
    if (origin) headers['Access-Control-Allow-Origin'] = origin;
    if (request.method === 'OPTIONS') return new Response(null, { status: 204, headers: {
      ...headers, 'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
      'Access-Control-Allow-Headers': 'Authorization, Content-Type' } });
    const path = new URL(request.url).pathname;
    if (path === '/health' && request.method === 'GET') return reply(200,
      { status: 'ok', multiplayer: multiplayerEnabled ? 'enabled' : 'not_ready' });
    if (!allow(`ip:${clientAddress}`)) return reply(429, { error: 'Too many requests' });
    const token = /^Bearer ([^\s]{1,8192})$/.exec(request.headers.get('authorization') || '')?.[1];
    if (!token) return reply(401, { error: 'Sign in required' });
    let user;
    try { user = await authenticate(token); }
    catch (error) { return reply([400,401,403].includes(error.status) ? 401 : 503,
      { error: 'Authentication unavailable or session invalid' }); }
    if (!user || !uuid.test(user.id) || !user.email_confirmed_at || user.is_anonymous)
      return reply(403, { error: 'Confirmed account required' });
    if (!allow(`user:${user.id}`)) return reply(429, { error: 'Too many requests' });
    if (path === '/v1/me' && request.method === 'GET') return reply(200, { id: user.id });
    if (!multiplayerEnabled) return reply(503, { error: 'Multiplayer is not open yet' });
    try {
      if (request.method === 'POST' && !request.headers.get('content-type')?.startsWith('application/json'))
        return reply(415, { error: 'JSON required' });
      const body = request.method === 'POST' ? await request.text() : '';
      if (Buffer.byteLength(body) > 8192) return reply(413, { error: 'Request too large' });
      let data;
      try { data = body ? JSON.parse(body) : {}; } catch { return reply(400, { error: 'Invalid JSON' }); }
      if (path === '/v1/matches' && request.method === 'POST') {
        if (!exact(data, ['country']) || !countries.has(data.country)) return reply(400, { error: 'Invalid country' });
        return reply(201, { id: await rpc('server_create_match', { actor: user.id, country: data.country }) });
      }
      const match = /^\/v1\/matches\/([^/]+)(?:\/(join|orders))?$/.exec(path);
      if (!match || !uuid.test(match[1])) return reply(404, { error: 'Not found' });
      const params = { actor: user.id, target: match[1] };
      if (!match[2] && request.method === 'GET') return reply(200, await rpc('server_match_info', params));
      if (match[2] === 'join' && request.method === 'POST') {
        if (!exact(data, ['country']) || !countries.has(data.country)) return reply(400, { error: 'Invalid country' });
        await rpc('server_join_match', { ...params, country: data.country }); return reply(200, { joined: true });
      }
      if (match[2] === 'orders' && request.method === 'POST') {
        if (!validOrder(data)) return reply(400, { error: 'Invalid order' });
        const sequence = await rpc('server_enqueue_order', { ...params, request: data.request_id,
          kind: data.kind, payload: data.payload });
        return reply(202, { sequence, status: 'queued' });
      }
      return reply(405, { error: 'Method not allowed' });
    } catch (error) {
      // Do not return database details, raw tokens or credentials to clients.
      return reply(error.status === 403 ? 403 : error.status >= 500 || !error.status ? 503 : 409,
        { error: 'Request could not be completed' });
    }
  };
}

export function startServer(config) {
  const handler = gateway({ ...supabaseService(config), multiplayerEnabled: config.multiplayerEnabled });
  const server = createServer(async (req, res) => {
    try {
      const chunks = []; let size = 0;
      for await (const chunk of req) {
        size += chunk.length;
        if (size > 8192) { res.writeHead(413); res.end(); return; }
        chunks.push(chunk);
      }
      const body = Buffer.concat(chunks);
      const request = new Request(`http://localhost${req.url}`, { method: req.method, headers: req.headers,
        ...(['GET','HEAD'].includes(req.method) ? {} : { body }) });
      const response = await handler(request, req.socket.remoteAddress);
      res.writeHead(response.status, Object.fromEntries(response.headers));
      res.end(Buffer.from(await response.arrayBuffer()));
    } catch { res.writeHead(400); res.end(); }
  });
  server.requestTimeout = 15000; server.headersTimeout = 10000;
  return server.listen(config.port || 8080, config.host || '127.0.0.1');
}
if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  startServer({ url: process.env.WM_SUPABASE_URL, publicKey: process.env.WM_SUPABASE_PUBLIC_KEY,
    serviceKey: process.env.WM_SUPABASE_SERVER_KEY, port: Number(process.env.PORT || 8080),

    host: process.env.WM_BIND_HOST || '127.0.0.1',
    multiplayerEnabled: process.env.WM_MULTIPLAYER_ENABLED === 'true' });
}
