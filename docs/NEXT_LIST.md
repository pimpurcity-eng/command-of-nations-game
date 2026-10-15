# Warfront Mandate — what's left (after 0.52, 15 Oct 2026)

## Needs Matthew (one-time)
1. **Switch on stats and alliances.** Supabase dashboard → SQL Editor → paste
   `backend/migrations/004_stats_alliances.sql` → Run. Until then the profile shows the old stats,
   the top-commander tabs fall back to XP, and Alliance says "being switched on".
2. **City look.** Approve or change ChatGPT's two city concepts in `docs/concepts/cities-2026-10-15/`.
3. **Google sign-in** (website): follow `docs/GOOGLE_SIGN_IN_2026_10_15.md` (ChatGPT's guide).
4. **Play upload:** `warfront-mandate-0.52.aab` in the builds repo → Play Console → Internal testing.

## Claude next
5. Lag with about 20 armies on screen (phones).
6. Paths from coastal provinces to the sea for ships.
7. Smaller Play updates: get the bundle under the size that forces a full re-download
   (about 190 MB sits in the install-time asset pack).
8. Check the home-screen music stops when a match starts (could not reproduce).
9. Other automatic war triggers: an army set to "aggressive" fire, or walking into the centre
   of an enemy province, still declares war without asking. Decide: ask first like Attack does?
10. Full play-through on a real phone: build, produce, move, attack, win - fix anything that blocks.

## ChatGPT next (see `docs/CHATGPT_NOTE_2026_10_15.md`)
11. Painted unit cards for the Warmate, GlobalEye and Lynx KF41 in the same style as the others
    (Claude's rendered cards are in place until then).
12. Bring the old tests up to date with the new start (no buildings, nothing researched).
13. Balance review against Conflict of Nations (`docs/BALANCE_REVIEW.md`), for Matthew to approve.
14. Optional: Groq key on the server to switch on the smarter country AI (`docs/EXTERNAL_COUNTRY_AI.md`).

## Done in 0.52
- Armies move at the normal 1x pace (they were 3x).
- Same units on both sides, 44 each: Ukraine gets the Warmate, Saab GlobalEye, Gripen E interceptor and
  Lynx KF41; European weapons only for Ukraine; four doctrines (Russian, European, American, Chinese).
- Every missile launcher raises its arm and fires from the tube; silo missiles rise out of the silo.
- Queue up to 5 buildings and 5 units per city.
- Tap the army to select it, tap the town to open the city; capitals bigger with more buildings.
- Same-size ground units; infantry the same size in the field and in cities.
- Camera pans the whole map and follows the finger.
- Health bar under every army tag; range rings (yours blue, enemy red, selected gold).
- Attack never declares war by itself; at peace the game asks first; you can't target your own armies.
- One tap on the destination sends the army and closes the order panel.
- More menu: Home screen (match saved and paused, Resume carries on) and Commander profile.
- Profile: K/D, kills, losses, provinces, win rate, streaks, time played; top commander tabs;
  alliances with chat, roles, join requests and one-tap operations into an online match.
- Cargo ships and oil tankers: one model each, bigger and carrying more at each of 5 levels
  (ChatGPT/Codex transport market, PR 14, merged).
- On phones, armies never stay blank while a model downloads.
- Cleaned up old screenshots, notes and old builds.
