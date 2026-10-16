# Note for ChatGPT — 16 Oct 2026 (evening), from Claude

> **Shared handoff:** start with `docs/HANDOFF.md` on branch `claude/wip-oct16` (live fix status, branch rules, session state). Where this file disagrees with it, `docs/HANDOFF.md` wins.

Read this together with `CHATGPT_HANDOFF.md`. No passwords, keys or tokens are in this note.

## 1. Play upload key — FOUND (update to handoff §5)
- The original upload key was on Claude's build session machine and has been checked:
  alias `upload`, certificate CN=Warfront Mandate, O=Yaska, C=CA,
  SHA-256 `52:E5:01:BA:65:57:58:0B:21:BB:76:42:6B:F1:F5:04:6B:86:CC:E7:41:DE:22:49:C3:44:6F:3F:26:AB:94:61`.
- Matthew now has the keystore file and its password (sent to him privately). A note with the alias and
  fingerprint is in his private Drive folder "Command of Nations - App signing (PRIVATE, do not share)".
- The upload-key reset scheduled for 18 Oct 2026 16:41 UTC is no longer needed once Matthew has saved the key.
  Matthew decides whether to cancel it. Never put the key or password in Git.

## 2. Branches
- `claude/v0.26-fixes` — still the buildable game (unchanged by the work below). Build from here.
- `claude/wip-oct16` — **unfinished, untested work. Do not build from it.** It holds Matthew's Oct 16 list
  in progress. It will be merged back into `claude/v0.26-fixes` when finished and tested
  (that merge must revert commit `20c7171`, the commit that moved the WIP off `claude/v0.26-fixes`).

## 3. How Matthew wants the work done now
**One fix at a time, one helper at a time.** Finish one item, test it, commit it, tell Matthew, then the next.
Do not batch several fixes together.

## 4. Matthew's Oct 16 fix list (numbered as he uses them)
Status: D = done on `claude/wip-oct16` (needs in-game testing), P = partly done there, unfinished and untested,
S = Matthew said skip, W = being worked on now.

Money/resources: 1 S colour bar check · 2 S same start amount in every slot · 3 S 6 vs 7 cities ·
4 W more money (Call of War style; currently being raised to ~40-50k/day per country) ·
5 D can't buy too much at the start · 6 D units cost money + manpower + 2 resources, not all of them.
Accounts: 7 D Google sign-in in the Android app (needs Supabase redirect URL `warfrontmandate://auth-callback`,
Site URL `https://play.warfrontmandate.com/`) · 8 D create account without a code box
(turn off "Confirm email" in Supabase to skip the email step) · 9 P Premium account groundwork
(`docs/PREMIUM.md`, `backend/migrations/005_premium.sql` not applied).
Camera: 10 P units render earlier when zooming/tapping · 11 P units easier to tap · 12 P camera jiggle.
Diplomacy/news: 13 P messages in Diplomacy · 14 P Diplomacy shows this map's alliance only ·
15 P show which country is leading · 16 P better newspaper anyone can post in.
Sound: 17 P remove the horse-racing sound.
Time: 18 P game speed affects every timer · 19 P units move too fast · 20 P faster on own land, terrain matters ·
21 P level-1 buildings 30 min at 1x, harder after · 22 P level-1 unit research 30 min-2 h ·
23 P every unit's first level by day 6 (except nukes).
Combat: 24 P battle animation 5 s then stop until next shot · 25 P plane won't attack enemy plane ·
26 P patrol does too little damage · 27 P air defence didn't hit a patrolling plane · 28 P heal armies with gold ·
29 P attacking at a city showed "defending" · 30 P fire modes (fire at will / return fire / hold fire).
City screen: 31 P remove tank picture, resources only · 32 P visible production countdown ·
33 P clear building vs unit icons at the top.
Reports: 34 P bigger reports. Victory: 35 P show how you won; check why the win came early.
Troops: 36 P rally spot for new troops · 37 P queued troops go to the rally spot (free, not premium).
Trains/ships: 38 P units 2x faster by train · 39 P bigger tracks · 40 P show and raise train/ship capacity per level.
Question: 41 transport helicopter is only a weak combat helicopter today (carries no troops); ask Matthew.
