# Gold and menu QA

Godot 4.6.3; focused headless tests and native X11 / OpenGL Compatibility / llvmpipe rendering.
Changes follow the unit/economy source tree `4f65fea45237d79246a34e8fc16782110d449671`.

| Test | Result |
|---|---|
| `test_gold_prices.gd` | 2,876 checks, zero failures; 94 families × five levels, split time/shortfall charges, paid/unpaid/partial-resource transactions, insufficient-funds atomicity, stale-price/order rejection, country/factory/research gating, speed independence, real server command dispatch, recording-client routing and bank resource bypass |
| `test_gold_menus.gd`, headless | 21 checks, zero failures |
| `test_gold_menus.gd`, native | 21 checks, zero failures; seven actual panel captures below |
| `test_economy_balance.gd` | 9,030 checks, zero failures; the relocated 10× menu still dispatches correctly |
| `test_unit_details.gd` | 30 checks, zero failures with the gold footer |
| `test_espionage.gd` | 38 checks, zero failures with the new prices and bank cap |
| `test_game_audio.gd` | 15 passes, zero assertion failures; relocated Sound/Music controls and persistence work. Exit reports ObjectDB/resources still in use; this is not a clean resource-lifetime result. |
| `test_home_button.gd` | Five passes, zero failures; Home, Resume and Commander profile retain their behavior |
| Editor import | Exit 0, no script/parse errors |
| `git diff --check` | Passed |

Gold panel bounds were checked at physical window sizes 640×1280, 720×1440 and 1440×900, using
the stretched viewport's logical coordinates. Menu counts, hidden ground-only aircraft commands,
price labels, disabled unaffordable purchases and actual research purchase callbacks are checked.
Tests do not contact a payment provider. Network tests call the real authenticated-command handler
and record client commands; they do not establish a live WebSocket match result.

## Native panel captures

- [Eight-choice More menu](More_Eight_Choices.png)
- [Grouped settings](Settings_Grouped.png)
- [Grouped army commands](Army_Commands_Grouped.png)
- [Resource prices](Gold_Resource_Prices.png)
- [Canadian package basis and unavailable checkout](Gold_Canadian_Pack.png)
- [Research with missing resources](Research_Missing_Resources.png)
- [Paid research with time-only charge](Research_Time_Only.png)

Screenshots render real reusable Godot controls with existing unit artwork in a standalone UI
fixture. They are not generated mockups, live web captures or Android screenshots. The empty map
background is intentional in this UI fixture. The previous [unit-balance QA](../unit-balance-2026-10-15/RESULTS.md)
records broader baseline/private-asset limitations; the full regression suite was not rerun here.

Raw focused logs are in [test-results.txt](test-results.txt).
