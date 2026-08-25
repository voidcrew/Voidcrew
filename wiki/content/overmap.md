---
title: The Overmap
category: Exploration
order: 1
blurb: The galaxy map your ship flies across. What is out there, how to find it, and why the middle of the map will kill you.
---

The overmap is the galaxy: a 51-by-51 grid of tiles with a star burning at the centre, on which your entire ship is a single icon. Every planet, ruin, trader, storm and rival crew occupies one tile of it. Flying is done from the [helm console](piloting.md), and everything you do in a round starts with picking a tile and going there. The single most important thing on this map is not any one destination. It is the three concentric rings of law that decide whether other crews are allowed to shoot you.

## Moving around

Your ship burns its engines in a direction and keeps coasting until you brake, so it handles like a ship and not like a cursor. The helm gives you a heading, a throttle percentage, an engine list and a Stop button that switches between cutting thrust and actively braking. Engines need power and fuel, so a ship that has run dry is a ship that drifts.

You can also plot a course: click a charted destination and the autopilot flies there. It routes around known storms, and if it blunders into one anyway it hands control straight back rather than pressing on. Touching the heading controls takes the ship off autopilot silently. Full details are on [Piloting](piloting.md).

## What is out there

| Contact | What it is |
| --- | --- |
| Planets | Landable worlds: lava, ice, jungle, beach and wasteland. Ore, ruins, weather and fauna. See [Planets](planets.md). |
| Space ruins | Twelve to twenty-four derelicts, stations and wrecks per round, each a loaded interior with loot and something guarding it. See [Ruins](ruins.md). |
| Asteroid storms | Landable rock fields, guaranteed at least three per round, and the dependable place to mine in space. Flying *through* one damages the hull. See [Mining](mining.md). |
| Ion and electrical storms | Hazards. Ion storms EMP random parts of your ship. Electrical storms blow out lights and throw lightning around inside the hull, while quietly topping up your power storage. |
| Nebulas | Harmless clouds of a specific gas that a ram scoop can harvest, and the only place a ship can hide itself. See [Gas Economy](gas-economy.md). |
| Trader outposts | Three permanent markets, one in each ring. They broadcast sector-wide, so they are on your chart from the start. See [Trader Outposts](trader-outposts.md). |
| Other ships | Player crews and [NPC ships](pirates-and-npc-ships.md), including pirates who will hail you and then interdict you. |
| Dread signals | Vestige ruins, which surface one at a time as the round ages, marked in red and named for the patron inside. See [Vestige Ruins](vestige-ruins.md). |
| Empty space | An empty tile can still be docked into, which is how two ships park next to each other. |

Other things surface on a schedule rather than at roundstart (contested caches, the [Grand Colosseum](colosseum.md) and the lich's lair) and announce themselves on Wideband when they do.

## Seeing it

Two different ranges matter and they are deliberately not the same thing.

**Sight** is a fixed ring of four tiles around your ship. It costs nothing, needs no research, and everything physically inside it draws on the helm chart immediately. Anything you see this way is remembered for the rest of the round, drawn faded once you leave, you chart the sector by flying it.

**Sensors** are an active scan on a one-minute cooldown, and they reach further than you can see. A scan does not reveal things around you; it *charts* what it finds into your navigation list, where it stays at any distance. It starts at the same four tiles as your sight and grows to six, eight and ten through the radar research tree, which also teaches your sensors to name space ruins instead of listing them as unknown signals, and eventually to identify vessels automatically.

Two things escape both. Other ships are never recorded, because they move. An unscanned vessel is an anonymous blip. And storms cannot be scanned at all; the only ways to learn where one is are to fly past it or to buy a **star chart** from a trader, a one-use slate that charts every contact in one whole ring at once. Traders also sell **rumor charts**, which name a specific rare ruin and spawn it somewhere uncharted when you decrypt one at the helm.

## The three zones

The map is divided into three static concentric rings measured from the star. They never move and never rotate, so the ring a tile is in is simply how far from the centre it sits.

| Ring | Zone | Ship weapons | Interdiction and forced docking |
| --- | --- | --- | --- |
| Outer third (map edge) | Neutral Zone | Disabled | Not allowed |
| Middle third | Contested Zone | Disabled | Allowed |
| Inner third (nearest the star) | Lawless Zone | Allowed | Allowed |

In plain terms: the outer ring is safe, the middle ring lets someone stop your ship and board it but not shoot it, and the inner ring is open season. The star charts traders sell label the three rings the neutral ring, the contested lanes and the lawless deep.

You can always tell which one you are in. The helm names the current zone, describes it, and says outright whether weapons and interdiction are permitted here; the overmap tiles themselves are tinted green, yellow and red. Every player ship spawns in the outer ring at roundstart, so if you have not deliberately flown inward, you are safe.

Crossing a boundary is a deliberate act. Thrusting at a tile in a different zone does not move you. It starts a ten-second transition instead, during which your engines are cut and you cannot thrust. The helm announces the zone you are entering and counts down. Pressing Stop cancels it, so you get a free chance to change your mind.

!!! danger "The middle ring is not a soft warning"
    Weapons being disabled in the Contested Zone does not make it safe. Anyone can interdict you there, pin you in place and force a dock, and then the fight happens with guns inside your hull. Boarding is the whole point of that ring.

## Why anyone goes deeper

Everything worth having is closer to the star, because the rings scale rewards as well as danger.

Rock on planets yields half again as much ore in the Contested Zone and double in the Lawless Zone. Planet wildlife spawns thirty percent denser in yellow and sixty percent denser in red, and each spawn has a twenty or forty percent chance of upgrading to the biome's genuinely dangerous list instead of its ordinary one. Weather comes more often, gives less warning and lasts longer the deeper you go. Loot caches roll from a per-ring table and lock in their contents where they spawned, so a cache found in the deep is a better cache.

The markets follow the same gradient: the general store sits in the neutral ring, the outfitter in the contested lanes and the black market in the lawless deep, so the best goods are behind the worst neighbourhood. Planets are placed into a specific ring when the round is built and generated to match it, which means a jungle world in the red is a meaningfully harder jungle world.

## Docking

To land on anything, bring the ship to a **full stop** on its tile and press Dock, or use the Interact button on that contact in your chart list. A moving ship will refuse. Docking into an empty tile parks you in open space, which is also how two ships end up alongside each other; a docking request sent to another ship expires after thirty seconds.

Docking is where the overmap hands you back to normal play: you walk out of an airlock onto a planet, a ruin, an outpost or someone else's deck. [Piloting](piloting.md) has the full procedure, and [Drop Pods](drop-pods.md) covers reaching a surface without landing the whole ship.
