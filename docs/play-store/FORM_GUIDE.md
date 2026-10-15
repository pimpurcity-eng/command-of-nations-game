# Google Play listing and forms - Warfront Mandate

Prepared 15 October 2026 for the EXISTING Google Play app, confirmed running by Matthew.
Source reviewed: `6e32091`. Supersedes the older listing draft. This pack proposes listing/form
updates; it is not a first-launch setup. Play Console has not been changed or submitted. Keep
the existing release, screenshots, distribution and access settings until an update is reviewed.
Claude retains release signing; no upload-key change or app recreation is needed.

## Store listing - copy and paste

App name: **Warfront Mandate: WW3**

Short description:

```text
Command a nation, build a trading economy and let AI defend while you are away
```

Full description:

```text
Build an economy. Command a nation.

Warfront Mandate: WW3 brings modern warfare, industry, trade and diplomacy into one real-time strategy campaign. Lead Russia or Ukraine, develop your cities and choose how your nation will compete.

BUILD YOUR WAY TO VICTORY
Economic power is a real campaign objective. Grow your income and reserves, develop industry and protect your capital. Check the conditions in your match and pursue victory through a strong economy as well as military conquest.

A PLAN FOR WHEN YOU ARE AWAY
Set Guard mode to automate defence. In online matches, an AI caretaker can also take over an absent nation and hand command back when you return. Your country remains part of the match and can still take losses.

TRADE THAT MOVES
Connect trading partners with trains, container ships and oil tankers. Build the stations and ports that support your routes. Delivered cargo contributes to your income and gives infrastructure a place in your strategy.

COMMAND LAND, AIR AND SEA
Deploy infantry, armour, artillery, helicopters, aircraft, drones, missiles and naval forces on a 3D campaign map. Combine ranged fire, air patrols and layered air defence. Research equipment upgrades and decide where your limited resources will make the greatest difference.

DIPLOMACY AND INTELLIGENCE
Negotiate peace, trade agreements and right of way, form coalitions or impose an embargo. Assign spies, protect your cities with counter-intelligence and use costly cyber operations for disruption or limited-area intelligence.

PLAY YOUR WAY
Start a campaign against AI without an account and continue a save on the same device. Sign in with a commander account for the online Russia-Ukraine match, your profile and account progression. Read battle, newspaper and Guard reports to follow what happened.

EARLY ACCESS
The game is in active development. Russia-Ukraine is the current playable campaign; larger Europe and world scenarios are in development. Features and balance continue to evolve.

No ads. An internet connection and account are required for online play. Offline campaign saves are stored on your device.

Music credit: "Bersærkere" by RAVNIR, from Gudlaus (2026), used with the artist's permission.
```

| Store field | Value |
| --- | --- |
| App or game | Game |
| Category | Strategy |
| Tags | Choose the available Strategy / Real-time strategy tags that match the game |
| Website | https://warfrontmandate.com/ |
| Contact email | support@warfrontmandate.com - verify inbox delivery before submission |
| Privacy policy | https://warfrontmandate.com/privacy.html |
| Account-deletion URL | https://warfrontmandate.com/delete-account.html |
| Package identity | `com.warfrontmandate.game` - retain the established Play identity |
| AAB signing | Claude builds/signs the release; this task changes no key or version |

## App content forms

These answers describe checked source. Confirm the released AAB matches before submitting.

| Form / question | Answer for the checked game |
| --- | --- |
| Ads | **No**. No ad integration was identified. |
| App access / sign-in details | **Some functionality is restricted**: online matches and account features require sign-in. |
| Account creation methods | **Username and password** for email/password accounts. Add **OAuth** only for app versions where Google sign-in is available. Current source enables Google only on Web. |
| Target age groups | Existing privacy policy excludes under-13s. A consistent proposed audience is **13-15, 16-17, 18 and over**; the owner must keep the actual intended audience consistent. |
| Appeals to children | **No**, for that intended audience. Do not select younger groups just to lower a rating. |
| News app | **No**. The in-game newspaper reports game events, not a news publication. |
| Government app | **No**. This is a strategy game. |
| Financial features | **No real financial service**. Currency and resource trading are game mechanics. |
| Health features | **No**. |
| Real-money gambling | **No** identified in source. |
| Real-money purchases / paid random items | **No** identified; recheck if billing is added. |
| User interaction | **Yes**: online diplomacy/chat, commander names and leaderboards. |
| Shares physical location with players | **No** identified. |
| Sensitive permissions | Inspected export preset requests Internet. Verify the exact AAB manifest before declaring its permissions. |
| Countries and regions | Keep the owner's existing launch selection. No distribution change is part of this task. |

### Content rating questionnaire

- App type: game. Violence: **Yes** - military combat, infantry, vehicles, explosions and strategic weapons.
- Do not answer "no human violence" because most units are vehicles: infantry is present.
- No developer-authored blood, gore, dismemberment, torture, sexual content, nudity, real-money
  gambling, drug/alcohol content or strong language was identified in this source review. Check
  the release's audiovisual content before answering the exact follow-up questions.
- Players can exchange text: **Yes**. Do not describe online chat as AI-only.
- Describe moderation/filtering truthfully. Do not claim reporting, blocking or profanity
  controls without verifying that they work in the submitted build.
- Let IARC assign regional ratings. Do not promise a particular PEGI/ESRB result.

## Data safety - what to tick

Top level: **Yes, collects user data**. **Yes, encrypted in transit**, if the release retains the
inspected HTTPS account and WSS multiplayer connections. Hosting processors fall under Google's
service-provider exception to sharing; collection still has to be declared.

| Data type | Collected | Purposes | Ephemeral? | Optional / required |
| --- | --- | --- | --- | --- |
| Personal info -> Email address | Yes | Account management, App functionality | No | Optional only if every distributed version allows a campaign without sign-in |
| Personal info -> User IDs | Yes: account ID / commander identity | Account management, App functionality | No | Same condition as email |
| Personal info -> Name | Yes: chosen commander display name, if identifiable | Account management, App functionality | No | Same condition as email |
| App activity -> Other actions | Yes: game results, XP, achievements, online orders and participation | App functionality; Account management for progression | No | Local-only play can be skipped; check all versions before marking optional |
| Messages -> Other in-app messages | Yes: online diplomacy/chat text and recipients | App functionality | **No**: server saves include messages | Optional: sending a message is a player choice |

For **Other in-app messages**, do not select SMS/MMS or Emails. Sending a confirmation email
does not mean the app reads the user's mailbox. Network/hosting logs, crash reporting or analytics
must also be included if the actual services collect reportable data; source alone does not
establish the full logging setup.

Sharing: **No non-exempt sharing identified in the inspected game**. Recheck service agreements
and actual SDK behaviour. Sending chat to the recipient the player chose may qualify for the
user-initiated-action exception. Do not assume all public leaderboard disclosures or automatic
transfers qualify; mark Shared too wherever the actual transfer is non-exempt.

No app collection of location, contacts, photos, microphone recordings, browsing history, payment
details or advertising identifiers was identified. Add crash/diagnostic/analytics types if the
release or its providers actually transmit them. Do not claim an independent security review,
certification or Families commitment that has not been completed.

### Account/data deletion - not yet ready to certify

The in-app account-removal path exists: **Account** on home, or **More -> Player account** in a
campaign, then **Delete account**, type **DELETE**, then **Delete my account forever**. No real
account was deleted in this task.

The app is already running on Google Play. For its next form update, verify the existing deletion
URL and support inbox. Live browser checking on 15 October reproduced a hidden contact email and
a Cloudflare protection page. Matthew has asked to leave the website as it is, so this finding is
reported for review; no website fix is being merged in this task.

The older policy promises everything is deleted, but the online server separately saves seats
and diplomacy messages. `delete_my_account` removes Supabase account data; no connection to the
separate match-save removal was found. Claude must verify removal or anonymisation of account
IDs, commander names and messages in those records/backups, and align the policy and retention
schedule. Profile removal alone is insufficient evidence for a complete-deletion claim.

## App access - reviewer instructions

Select **Some functionality is restricted**, then add English instructions. Enter a working,
already-confirmed reviewer email/password in Play Console's private credential fields, never
in Git or this guide. Do not use Matthew's personal account. No reviewer account was created here.

Suggested "Any other instructions" text:

```text
The campaign against AI is available without signing in: choose a nation on the home screen and start a campaign. Account/profile features and Online Match require the reviewer credentials supplied above. Open Account on the home screen and sign in with email and password. The reviewer account must already have its email confirmed. Google sign-in is not required. The current online scenario has Russia and Ukraine; a full match may have no free nation seat. Offline campaign features remain available.
```

Verify that the review account can actually reach the restricted online features, including a
free nation seat. A working password alone does not finish review access. Add specific match or
review-environment instructions only after that environment exists.

## Replacement graphics and next-update status

- Icon: supplied at **512 x 512**, PNG, square canvas, existing shield/globe identity.
- Feature graphic: supplied at **1024 x 500**, RGB PNG. Promotional artwork, not a screenshot.
- **Keep the current Play screenshots.** Any replacement screenshots must come from the exact
  Android release they depict. For replacements, use 2-8 genuine PNG/JPEG
  screenshots without alpha, 320-3840 px per side, longest side at most twice the shortest.
  Sequence: home, campaign map, city construction, research, economy/victory, Guard report,
  trade, diplomacy. Include only screens implemented and reachable in that AAB.
- Claude's 14 October note says five real 1080 x 2160 screenshots were made. Their image files
  were not in the checked repository or Notes folder. Recover and verify them before reusing.
  Old repository review images are not relabelled as current Android captures.
- This session's browser lacks WebGL2 and could not reach the live game's menu. It cannot
  provide genuine gameplay screenshots or a full-match pass.

Before submitting a listing/form update: check the corresponding AAB, genuine screenshots, reviewer access, chat/UGC
declarations, support delivery and privacy/deletion consistency. This pack does not establish
that these proposed updates have been submitted. It does not question the existing running app.

## Official sources checked 15 October 2026

- https://support.google.com/googleplay/android-developer/answer/9866151 (graphics)
- https://support.google.com/googleplay/android-developer/answer/10787469 (data safety)
- https://support.google.com/googleplay/android-developer/answer/9859455 (app content/review access)
- https://support.google.com/googleplay/android-developer/answer/13327111 (account deletion)
- Music credit retained from `docs/AUDIO_LICENCES.md`; no new licence is asserted.
