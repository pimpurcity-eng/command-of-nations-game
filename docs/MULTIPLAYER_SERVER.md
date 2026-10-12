# Online multiplayer: how it works and how to run it

Phase 6 of the Call of War / Conflict of Nations gap list (owner request 2026-10-12).

## What players get

- **ONLINE MATCH** on the start screen. You must be signed in to your account. You get the
  country you picked if its seat is free, otherwise the other one.
- **Persistent match.** The match keeps running on the server around the clock, in real time, like
  Call of War. Players come and go.
- **Join in progress.** Anyone can take a free seat at any time.
- **Your seat is yours.** When you come back, from any phone, you get the same country. Signing in
  on a second phone moves you to it.
- **The AI covers for you.** The AI plays every empty seat. It takes over a player who has been
  away 10 minutes (setting `WM_INACTIVE`), and hands control back the moment they return.
  Everyone gets a news line when this happens.
- **Fair fog of war.** The server only sends a phone the armies its country can see. Enemy routes
  and targets are never sent, so a modified app cannot reveal them.
- **Cheat-proof orders.** Every order is checked on the server against the sender's country:
  moving, attacking, retreating, producing, research, building, annexing, diplomacy, chat and
  strategic weapons. Orders are limited to 20 a second per player.
- **Player-to-player diplomacy.** Peace and other proposals wait for the other player's answer.
  Chat works too.

## How it is built

| Part | File |
| --- | --- |
| Server: the full game, simulated headless, as the only authority | `game/scripts/net/match_server.gd` |
| Server launcher (command line / environment settings) | `game/scripts/net/server_main.gd` |
| Phone client: sends orders, shows the server's state | `game/scripts/net/match_client.gd` |
| AI for several seats at once | `MatchSystem.set_ai_countries` |
| Server orders / phone display | `UnitSystem.command`, `apply_remote`, `glide` |
| Tests | `game/tests/test_multiplayer.gd` (34 checks), `test_multiplayer_phone.gd` (9 checks) |

**Protocol.** JSON over WebSocket. The phone sends `hello` (account token, match, country) and
then `cmd` messages. The server replies with `welcome` (everything this player may see), a `tick`
twice a second (armies in sight, borders, own economy; diplomacy and research every 2 seconds),
`result` for each order, and `event` for news.

**Sign-in.** The phone sends its Supabase access token. The server checks it with Supabase
(`/auth/v1/user`). Test sign-ins (`dev:<name>`) only work with `WM_ALLOW_DEV_TOKENS=1`; never set
that on the real server.

**Saving.** The match is saved every minute and when the server stops. On start, the server
resumes the save and its seats (`<match>.json`, `<match>_seats.json`).

**Current limits.**
- Online matches use the Russia–Ukraine map: 2 seats.
- The Europe (20) and world (100) maps can use the same server once ChatGPT's 0.22 gameplay runs on
  them. `MatchServer.COUNTRIES` becomes the map's player list; nothing else in the protocol changes.
- One process runs one match. Run more processes, one per match, for more matches.

## Running it (about $5–10 a month)

1. **Rent a small Linux server** (VPS) with 2 GB of memory, for example Hetzner CX22 or DigitalOcean.
   One server holds several matches.
2. **Point DNS at it.** In Cloudflare, add an `A` record: `play` → the server's IP address.
3. **Install Docker and Caddy** on the server. Copy this repository there.
4. **Configure.** In `server/`, create a `.env` file:
   ```
   SUPABASE_URL=https://wrnmscdtwbezcmrlukvg.supabase.co   # the Warfront Mandate project
   SUPABASE_ANON_KEY=<the anon public key>
   ```
   These are the same public values the app already uses. **Do not use the service-role key.**
5. **Start it:** `docker compose -f server/docker-compose.yml up -d --build`
6. **Turn on TLS:** copy `server/Caddyfile` to `/etc/caddy/Caddyfile`, then `systemctl reload caddy`.
   Phones connect to `wss://play.warfrontmandate.com`, which is the default in the game
   (`main.gd` `ONLINE_SERVER`).
7. **Check it:** `docker compose logs -f` should show
   `Warfront Mandate match 'main' listening on port 8910`.

**Local test without a server:**

```
WM_ALLOW_DEV_TOKENS=1 godot --headless --path game --script res://scripts/net/server_main.gd -- --port 8910 --match main
```

Then set `server_url = "ws://<your PC's IP>:8910"` under `[online]` in the phone's
`user://settings.cfg`.

## Push notifications (next step, needs Firebase)

In-game alerts already work while the app is open: being attacked, a city lost, a weapon or
research finished. Alerts on a phone that is closed need Firebase Cloud Messaging (FCM). The plan:

1. Create a free Firebase project and add the Android app (package id from task 15).
2. Add a Godot FCM plugin. The app stores its device token in a new Supabase table
   `player_devices` (only the player can write their own row).
3. The match server sends a push when a seat's player is offline and their country is attacked,
   loses a city, or a war is declared on it. It uses a Supabase Edge Function holding the FCM key,
   so the key never sits on the game server.
4. Players can turn alerts on and off in Settings. Google Play also needs the "Notifications"
   permission prompt (Android 13+).
