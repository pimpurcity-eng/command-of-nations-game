# Gold prices and shorter menus — 15 October 2026

The owner set the package basis to **CA$10.00 for 10,000 gold** and requested higher prices,
time-only completion when resources are available, a surcharge for missing resources, and shorter
menus informed by Call of War and Conflict of Nations. This follows the [unit/economy pass](BALANCE_REVIEW.md).
These are original Warfront balance values. The public competitor wikis do not provide a complete
current numerical gold price book.

## References checked

| Official reference | Application |
|---|---|
| [Call of War Gold & Shop](https://wiki.callofwar.com/wiki/GOLD_%26_SHOP) | Separates resource purchases, time boosts and instant espionage. Package availability/pricing varies by country and platform. |
| [Call of War Resources & Market](https://wiki.callofwar.com/wiki/RESOURCES_%26_MARKET) | Direct gold resource offers have fixed exchange ratios; ordinary player offers use money. |
| [Call of War Main Interface](https://wiki.callofwar.com/wiki/MAIN_INTERFACE) | Major tasks use primary tabs; secondary settings and reports are grouped; army/province orders depend on the selection. |
| [Conflict of Nations User Interface](https://wiki.conflictnations.com/User_Interface) | Separate army/province controls, city management, information and map settings. |

The source descriptions informed organization and pricing mechanics. They do not establish Warfront's
exact rates, current competitor checkout prices, or a claim that the older wiki illustrations are the
latest live client layout.

## Gold price book

The proposed package is recorded in `GoldWallet`: currency CAD, 1,000 Canadian cents, 10,000 gold.
At that rate 1,000 gold represents CA$1.00. The existing 10,000 free gold per match is retained.
**Google Play billing is still unconnected.** The shop shows the planned pack and a disabled purchase
button; no real payment, live product-price change or purchase-grant endpoint was implemented.

| Buy 1,000 of resource | Previous gold | New gold | Package-value equivalent |
|---|---:|---:|---:|
| Money | 100 | 1,000 | CA$1.00 |
| Manpower | 500 | 4,000 | CA$4.00 |
| Food | 300 | 1,000 | CA$1.00 |
| Metal | 500 | 2,000 | CA$2.00 |
| Oil | 500 | 2,000 | CA$2.00 |
| Rare earths | 800 | 5,000 | CA$5.00 |

Both 1,000 and 5,000 resource packs use the same ratio; no bulk discount. The resource rates align
with the world commodity floors, so gold-funded money cannot buy the same resource more cheaply at
those floors. Player sales may still be more expensive and market availability still matters.

Finishing work costs **800 gold per remaining game hour**, rounded up once for time. Previously it
was about 70.83 per hour. Five thousand gold now covers 6.25 game hours rather than about 70.59 hours.
The price falls with unfinished work and reaches zero on completion. Match speed changes actual waits,
not the price of the same remaining work; 1×, 4× and 10× use the same quote. Building speed, morale and
doctrine affect the remaining work time, including Europe's exact 15% research-time discount.

For an unpaid order, the total is the time charge plus the gold value of `max(required - owned, 0)`
for each resource. Available resources are consumed; gold funds only the shortfall. For a paid order,
its resource bill is already settled, so finishing charges only time even if current stock is empty.
Research can be purchased before it starts or finished in progress. Research prerequisites, day gates,
slots, ownership and required production buildings still apply.

| Example, Russian level-I motor infantry | Time gold | Missing-resource gold | Total gold |
|---|---:|---:|---:|
| Full two hours, all resources available | 1,600 | 0 | 1,600 |
| Already paid, one hour remaining | 800 | 0 | 800 |
| Already paid, thirty minutes remaining | 400 | 0 | 400 |
| Full two hours, no resources | 1,600 | 4,320 | 5,920 |
| Full two hours, only the required money owned | 1,600 | 3,240 | 4,840 |

Russian level-I MBT production with no resources costs 14,034 gold (4,800 time + 9,234 resources).
European level-I motor-infantry research with no resources costs 2,940 (1,020 time + 1,920 resources).
Five thousand gold can still finish a few small, already funded orders; it cannot buy an entire
fresh army without resources. These are opening examples, not proven long-match PvP balance.

## Instant espionage

| Action | Previous gold | New gold | Effect |
|---|---:|---:|---|
| Power blackout | 3,000 | 12,000 | Existing three-hour city slowdown |
| Satellite hack | 3,500 | 7,500 | Existing one-hour local reveal |
| Bank hack | 2,500 | 7,500 | 5% of enemy money/metal, now capped at 2,000 each |
| Firewall | 2,000 | 5,000 | Existing six-hour protection |

The bank cap deliberately drops from 10,000 to 2,000 per resource. Its maximum haul is worth
6,000 gold at the new resource rates, below its 7,500 price; leaving the old cap would bypass
the resource-store rebalance. Fixed public hack prices also avoid revealing hidden enemy stock
through a changing quote. A blocked attack retains the existing paid-attempt rule.

## Shorter navigation

The global More menu now has **eight main choices**, down from 42 rows:

| Main choice | Contents |
|---|---|
| Home screen | Existing home/resume flow |
| Commander profile | Existing profile |
| Army roster | Existing army list |
| Espionage | Spies and hackers |
| Reports | War newspaper; battle reports |
| Nation | Victory; doctrine/strategic weapons; annex selected occupied province |
| Settings | Sound; music; game speed; map/camera |
| Game | Save; load; new match |

The six bottom tabs remain. Duplicate research/production/trade/diplomacy entries are removed from
More. Army commands stay on the selected army's controls. Its More menu has five choices at most:
details, fire control, upgrade, organize, and orders (or rebase for aircraft). Merge/select and
waypoint/delay/retreat are grouped. The weapon showcase is removed from player navigation; its
internal tool remains available in source. All speed choices (1×/2×/4×/10×) remain in Settings.

## Payment integrity and release handoff

Online resource purchases, queueing, research/refinements, finishing and hacks now dispatch to the
authenticated match server. It derives the country and recalculates the real cost. The client submits
a spending ceiling, never a price to trust. A changed order ID or increased total is rejected for
review. Lower prices as time passes are accepted. Insufficient gold changes no resources or work;
negative payments are rejected. Snapshots send each player their own gold balance.

Client and server must ship together. [QA results and genuine screenshots](qa/gold-menus-2026-10-15/RESULTS.md)
cover the new transactions and navigation. No live payment, socket match, APK, Android device test,
server deployment or release was performed. Claude retains merge/build/release ownership.
