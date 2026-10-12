# Monetization plan (draft for the owner's decision)

Nothing here is built yet. Every item needs the owner's approval first, and Google Play's rules
apply. How Call of War and Conflict of Nations do it: free to play, plus a premium currency,
memberships and speed-ups.

## Recommended: fair free-to-play

| Item | What it gives | Price idea | Notes |
| --- | --- | --- | --- |
| **Commander Pass** (monthly membership) | Faster research queue (2 at once), extra build-queue slot, 3 save slots, ad-free, a badge on the leaderboard | $4.99 / month | The main income in CoW-style games. Must not make a player unbeatable. |
| **Gold** (premium currency) | Finish a production or building job early (capped: at most 25% of a job's time per day); cosmetic flags and army colours | $0.99 – $49.99 packs | Keep the speed-up cap so free players can still win. |
| **Cosmetics** | Unit skins, map themes, profile frames, victory banners | $0.99 – $4.99 | No gameplay effect. The safest money. |
| **Scenario packs** | Extra single-player scenarios and maps (e.g. Europe 20, World 100 offline vs AI) | $2.99 each | One-time purchases. |
| **Rewarded ads** (optional) | Watch an ad for a small resource bonus, once every few hours | — | Only if wanted. Never forced ads mid-battle. |

## Rules to keep it fair (and inside Google Play policy)

- **No loot boxes** (random paid rewards). If ever added, the odds must be shown.
- **Online matches.** Gold speed-ups are capped per day, and every match can turn them off
  ("Pure matches").
- **Payments go through Google Play Billing only** (Godot plugin: GodotGooglePlayBilling).
- **Purchases are checked on a server.** A Supabase Edge Function verifies each purchase token with
  Google and only then credits the player's account (table `player_wallet`, never written by the
  app). The match server reads a player's membership when they join.
- **Refunds.** Google's Real-time Developer Notifications remove the item again.
- **Store listing:** "Contains in-app purchases". Set the age rating questionnaire accordingly.

## Costs

- Google takes 15% of the first $1M a year (small-business programme; sign up for it).
- Servers: about $5–10 a month per VPS (several matches each), plus Supabase free tier, then
  $25 a month on Pro when players grow.

## Suggested order

1. Launch free, with no purchases. Get testers and the 14-day closed test done.
2. Add cosmetics and the Commander Pass.
3. Add Gold speed-ups only if players ask for them, with the caps above.
