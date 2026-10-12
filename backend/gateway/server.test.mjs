import test from 'node:test';
import assert from 'node:assert/strict';
import { gateway, rateLimiter, supabaseService, validOrder } from './server.mjs';
const player = '11111111-1111-4111-8111-111111111111';
const match = '22222222-2222-4222-8222-222222222222';
const requestId = '33333333-3333-4333-8333-333333333333';
const confirmed = { id: player, email_confirmed_at: '2026-10-12T00:00:00Z', is_anonymous: false };
function request(path, data, headers = {}) {
  return new Request(`https://api.example.org${path}`, { method: data === undefined ? 'GET' : 'POST',
    headers: { Authorization: 'Bearer test-token', 'Content-Type': 'application/json', ...headers },
    ...(data === undefined ? {} : { body: JSON.stringify(data) }) });
}
test('Missing, invalid and unconfirmed authentication never reaches match persistence', async () => {
  let calls = 0;
  for (const user of [null, { ...confirmed, email_confirmed_at: null }, { ...confirmed, is_anonymous: true }]) {
    const h = gateway({ authenticate: async () => user, rpc: async () => calls++, multiplayerEnabled: true });
    assert.equal((await h(request('/v1/matches', { country: 'russia' }))).status, 403);
  }
  const h = gateway({ authenticate: async () => { throw { status: 401 }; }, rpc: async () => calls++ });
  assert.equal((await h(request('/v1/me'))).status, 401);
  assert.equal((await h(request('/v1/me', undefined, { Authorization: '' }))).status, 401);
  assert.equal(calls, 0);
});
test('Provider outage fails closed and does not leak its error', async () => {
  const h = gateway({ authenticate: async () => { throw Error('private-provider-response'); } });
  const r = await h(request('/v1/me'));
  assert.equal(r.status, 503); assert.doesNotMatch(await r.text(), /private-provider-response/);
});
test('Multiplayer remains closed until explicitly enabled', async () => {
  const h = gateway({ authenticate: async () => confirmed, rpc: () => assert.fail('RPC called') });
  assert.equal((await h(request('/v1/matches', { country: 'russia' }))).status, 503);
  assert.deepEqual(await (await h(request('/health'))).json(), { status: 'ok', multiplayer: 'not_ready' });
});
test('Client identity cannot override provider-validated player identity', async () => {
  const calls = [];
  const h = gateway({ authenticate: async () => confirmed, multiplayerEnabled: true,
    rpc: async (...args) => { calls.push(args); return match; } });
  assert.equal((await h(request('/v1/matches', { country: 'russia', actor: match }))).status, 400);
  assert.equal((await h(request('/v1/matches', { country: 'russia' }))).status, 201);
  assert.deepEqual(calls, [['server_create_match', { actor: player, country: 'russia' }]]);
});
test('Membership denial stays denied without returning raw database errors', async () => {
  const h = gateway({ authenticate: async () => confirmed, multiplayerEnabled: true,
    rpc: async () => { throw { status: 403, message: 'private-table-name' }; } });
  const r = await h(request(`/v1/matches/${match}`));
  assert.equal(r.status, 403); assert.doesNotMatch(await r.text(), /private-table-name/);
});
test('Valid orders carry stable retry IDs and actor identity, with queued status only', async () => {
  let actual;
  const h = gateway({ authenticate: async () => confirmed, multiplayerEnabled: true,
    rpc: async (...args) => { actual = args; return 7; } });
  const order = { request_id: requestId, kind: 'move', payload: { unit_id: 'unit-1', destination: { x: 1, z: 2 } } };
  const r = await h(request(`/v1/matches/${match}/orders`, order));
  assert.equal(r.status, 202); assert.deepEqual(await r.json(), { sequence: 7, status: 'queued' });
  assert.equal(actual[1].actor, player); assert.equal(actual[1].request, requestId);
  assert.equal(validOrder({ ...order, payload: { ...order.payload, owner: match } }), false);
  assert.equal(validOrder({ ...order, payload: { unit_id: 'unit-1', destination: { x: NaN, z: 0 } } }), false);
  assert.equal(validOrder({ ...order, kind: 'award_xp' }), false);
});
test('Clients have no route for results, checkpoints or starting the simulation', async () => {
  const h = gateway({ authenticate: async () => confirmed, multiplayerEnabled: true,
    rpc: () => assert.fail('Privileged RPC called') });
  for (const action of ['finish', 'checkpoint', 'start', 'results'])
    assert.equal((await h(request(`/v1/matches/${match}/${action}`, { won: true }))).status, 404);
});
test('Malformed, oversized and unexpected input is rejected before persistence', async () => {
  const h = gateway({ authenticate: async () => confirmed, multiplayerEnabled: true,
    rpc: () => assert.fail('RPC called') });
  assert.equal((await h(request('/v1/matches', { country: 'invalid' }))).status, 400);
  assert.equal((await h(request('/v1/matches', { country: 'x'.repeat(9000) }))).status, 413);
  assert.equal((await h(request('/v1/matches', {}, { 'Content-Type': 'text/plain' }))).status, 415);
  assert.equal((await h(new Request('https://api.example.org/v1/matches', { method: 'POST',
    headers: { Authorization: 'Bearer test-token', 'Content-Type': 'application/json' }, body: '{' }))).status, 400);
});
test('Origin restriction and request throttling are enforced', async () => {
  const h = gateway({ authenticate: async () => confirmed, allow: () => false });
  assert.equal((await h(request('/v1/me', undefined, { Origin: 'https://untrusted.example' }))).status, 403);
  assert.equal((await h(request('/v1/me'))).status, 429);
  let time = 0;
  const allow = rateLimiter({ limit: 2, capacity: 1, windowMs: 1000, now: () => time });
  assert.equal(allow('a'), true); assert.equal(allow('a'), true); assert.equal(allow('a'), false);
  assert.equal(allow('b'), false); time = 1000; assert.equal(allow('b'), true);
});
test('Provider validation uses HTTPS Auth, and server keys never authenticate clients', async () => {
  let seen;
  const service = supabaseService({ url: 'https://example.supabase.co', publicKey: 'sb_publishable_test',
    serviceKey: 'sb_secret_test', fetchImpl: async (url, options) => { seen = [String(url), options];
      return Response.json(confirmed); } });
  await service.authenticate('player-token');
  assert.equal(seen[0], 'https://example.supabase.co/auth/v1/user');
  assert.equal(seen[1].headers.apikey, 'sb_publishable_test');
  await service.rpc('server_match_info', { actor: player, target: match });
  assert.equal(seen[1].headers.apikey, 'sb_secret_test');
  assert.equal(seen[1].headers.Authorization, undefined);
  assert.throws(() => supabaseService({ url: 'http://example.supabase.co', publicKey: 'sb_publishable_x', serviceKey: 'x' }));
});
