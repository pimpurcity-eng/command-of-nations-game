# Premium account (design note)

Owner 2026-10-16: "For premium account, I want you to start creating the premium account."

Premium is a monthly membership in the style of Call of War's premium membership: it gives
**conveniences, never power**. Every unit, building, research level and map stays open to free
commanders, and a free commander can always beat a Premium one.

## Free for everyone (owner 2026-10-16)

- **Rally points**: choose a spot on the map for a city; every new unit from that city marches
  there by itself ("You can choose a rally spot for when new troops come out ... That's not on
  premium account").
- **City production queue of five units**, built one after another.
- All units, buildings, research, online matches, alliances, leaderboards and achievements.
- Gold stays its own thing (see MONETIZATION_PLAN.md); Premium is not needed to use it.

## What Premium gives

| Benefit | Status | Notes |
| --- | --- | --- |
| 8 production queue slots per city (free: 5) | **Live** (`PlayerPremium.plan_limit`) | Only for your own country, single-player; online matches use the server's rules (5) until the match server reads the membership. |
| Premium badge and gold commander name on the profile | **Live** | Profile screen shows "★ PREMIUM COMMANDER · until date". |
| Monthly gold bonus | Planned | e.g. 5,000 gold credited on each renewal (server side, from the purchase webhook). |
| Army templates / formations | Planned | Save an army mix and queue it again with one tap. |
| Advanced army statistics | Planned | Full combat numbers, terrain bonuses, battle forecast in army details. |
| More match slots | Planned | More online matches and save slots at once. |
| Extra profile statistics | Planned | Match history, favourite units, win rate per country. |
| Ad-free | Planned | Only matters if adverts are ever added for free players. |
| Badge on leaderboards and alliance lists | Planned | Needs the leaderboard functions to return premium. |

Open question for the owner: Guard mode (the AI defends your land while you sleep,
`defence_ai.gd`) was once "planned for the premium account". It is currently free; decide
whether it stays free.

## Price idea

- **$4.99 / month** Google Play subscription (Call of War charges about the same).
- Optional: $12.99 / 3 months, $39.99 / year.
- A 7-day free trial for new commanders.

## How it works (built 2026-10-16)

- **Data**: `premium_until timestamptz` on `public.player_profiles`
  (`backend/migrations/005_premium.sql`). The player can read it, never write it. The server
  (service role) extends it with `private.grant_premium(player, days, source, reference)`, which
  also writes an audit row to `private.premium_grants`. **The migration must be applied in the
  Supabase SQL editor**; until then every commander is simply free.
- **Game**: `scripts/accounts/player_premium.gd` (`PlayerPremium.is_premium()`) reads the flag
  after sign-in. Nothing is stored on the device, so editing local files cannot unlock it.
  `PlayerPremium.test_override` is the test toggle (tests; and a "Test build" button on the
  Premium screen in debug builds only).
- **Screen**: `scripts/accounts/premium_panel.gd`, opened from the home screen
  ("★ PREMIUM MEMBERSHIP") and the commander profile ("★ Premium membership"). The buy button
  says "Coming soon — Google Play subscription"; nothing is charged yet.

## Still to build for real billing

1. Google Play Console: create the subscription product (e.g. `premium_monthly`).
2. Godot Google Play Billing plugin in the Android export; the web build sells through a
   separate web checkout later (or shows "buy in the app").
3. A Supabase Edge Function that verifies each purchase token with the Google Play Developer
   API, then calls `private.grant_premium` (service role). Real-time Developer Notifications end
   it early on refund or cancellation.
4. The match server reads `premium_until` when a player joins, so online matches can give the
   same conveniences.
