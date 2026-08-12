---
title: Piloting Your Ship
category: Your Ship
order: 1
blurb: How to fly, scan, and dock your ship from the helm control console.
---

Everything your crew does starts at the **helm control console**. It flies the ship across the [overmap](overmap.md), runs your sensors, and holds the dock controls. Any crew member can use it (it refuses anyone who isn't on the ship's crew) and wall-mounted **ship viewscreens** show the same display without the controls.

## Getting underway

Press **Undock**. The console runs a ten-second warmup, then holds a twenty-second lockout before you can undock again. Undocking is blocked while your cargo shuttle is still aboard, and while an enemy interdictor has you locked; below 25% fuel the console asks you to confirm first.

## Reading the console

The panels around the chart are your status board:

| Panel | What it tells you |
| --- | --- |
| Hull | Integrity percent, plus bonus plating. Below 50% the ship is disabled and every helm control stops working. |
| Fuel | Average reserve across running engines, then a row per engine with its own level and an on/off switch. |
| Drive | Installed thrust, drives online, and whether something is throttling you. |
| Sensors | Scan radius, and the buttons that run an active scan. |
| Velocity | Speed in tiles per minute, and the time until you cross into the next tile. |

Heading and position sit in the corner of the chart. The ship's name at the top can be changed by the commanding officer.

## Flying

The compass rose commands a **course**: eight direction buttons and a square **brake** in the middle. Press a direction and the ship handles the rest. It sheds any drift working against you, burns up to cruising speed, then cuts the engines and coasts, holding the course on momentum alone. The button stays lit while the course is held, even with the engines cold. Press the lit button to drop the course and coast free. The brake always brakes, whatever the ship is doing; press it again mid-brake to release it.

The vertical slider beside the rose is the **throttle**, 1 to 100 percent. It sets how hard the engines burn *and* the cruising speed the ship settles at. Full throttle is flat out, half throttle cruises at half speed on a fraction of the fuel. Drag it mid-flight and the ship adjusts on the spot: raising it starts a top-up burn, lowering it sheds the difference for free. A diagonal burn puts half the thrust on each axis, so cutting a corner is not free speed.

You can also fly from the keyboard. Click the **wasd** switch in the corner of the Helm panel to take manual control: while it shows *live*, **WASD** or the **arrow keys** command a course (hold two together for a diagonal), **Space** brakes, and **X** cuts the engines to coast, and your character stays put, because the console keeps those keys for itself. The console only holds your keys while its window is the one you are typing at: click into the game world and you walk around as normal, with the switch reading *armed* until you click back in. Click the switch off or close the console to drop manual control entirely.

!!! tip "Nothing stops you automatically"
    Space has no friction. Once the ship reaches cruising speed the engines go cold and it costs nothing to keep going, but keep going it will, forever, until you brake or command something else. Fuel is only ever spent changing your speed, never keeping it.

Burning toward a tile in a different zone band starts a **zone transition**: the engines cut, the ship holds still for ten seconds, then crosses and resumes your course by itself on the far side. The brake cancels the crossing and leaves you where you were.

## The navigation chart

The chart is the middle panel. Drag with the left or middle mouse button to pan, use the wheel or the slider to zoom, and double-click (or press **Recentre**) to snap back onto your ship. The coloured rings are the zone bands.

**Right-click** the chart or a contact for the action menu: set a course for the autopilot, interact with something sharing your tile, run a Ships scan on an unknown vessel, or clear a waypoint you are done with.

The drawer beside the chart has four tabs. **Contacts** lists every mark you know about with live distance and bearing. **At location** lists only things on your tile. The only things you can act on. **Comms** is the hail log (see [Radio & Comms](comms.md)). **Intel** holds sealed rumour charts bought from traders, which reveal a rare signal's coordinates when decrypted.

## Autopilot

Right-click a destination and choose **Set course**. The autopilot flies with the same headings and throttle you would use, so it burns the same fuel and sits out the same zone transitions. It steers, it does not teleport. On a planet, ruin or outpost the same menu offers **Travel & dock**, which flies there and starts the docking approach the moment it arrives. Both commands also appear as buttons under the selected contact in the drawer.

It routes around storms, asteroid fields and known hostile vessels, but only around things **this ship has actually seen**. It also halves cruise speed while flying into tiles you have never laid eyes on, so it has time to react to what turns up.

It stands down on its own if you are locked on by weapons, take hull damage, get caught in an interdiction field, or end up inside a hazard; touching the compass rose also drops it. On arrival it stops the ship and holds station.

## Sensors and radar

Two ranges matter here, and keeping them straight is most of navigating well.

Your **view ring** is a fixed four tiles and never changes. Everything inside it draws on the chart for free (planets, ruins, outposts, nebulas, storms, ships) and is then remembered permanently, drawn faded once you leave it behind. You chart the galaxy by flying it.

Your **sensor range** is how far an **active scan** reaches, and it is what radar research buys. A scan sweeps one category at a time and charts what it finds as a permanent waypoint. Scans have a one-minute cooldown, but an empty sweep costs nothing and can be retried at once.

| Research node | Cost | Scan range | Also gives you |
| --- | --- | --- | --- |
| *(none)* | - | 4 tiles | |
| Radar Array | 1000 | 6 tiles | |
| Radar Array: Signal Analysis | 2500 | 8 tiles | Names space ruins on the chart instead of "unknown signal" |
| Radar Array: Vessel Tracking | 5000 | 10 tiles | Plots and names other crews' ships out to full sensor range |

Vessels are the exception. They move, so they are never recorded. A ship is a live contact or nothing. Without the top radar tier you only see ships inside your view ring, and they read as **unknown contact** until a Ships scan resolves them. An unidentified blip hides whether it is a trader or a pirate, which is the point.

Storms and nebulas cannot be scanned at all. Either fly past one to record it, or buy a **star chart** from a trader and insert the disk into the helm, which charts a whole zone band at once.

Markers also arrive from elsewhere: accepted [missions](missions.md), bounties and revealed rumours all push one onto the chart, and trader outposts are permanently listed on every helm.

## Docking

Make a **slow approach**: at up to half speed (30 tiles per minute) the Dock button finishes the stop for you; any faster and it refuses until you brake. It labels itself with whatever is actually under you, so you can see whether you are about to land on a planet, a ruin, an outpost, or hold station in empty space. Docking runs a ten-second warmup and cannot be started while you are interdicted.

Docking at a **planet** loads its surface and puts your ship down on it. With an upgraded orbital survey console you can choose where on the surface you land instead of taking the default berth.

Docking with **another player ship** is a two-way handshake: one crew sends a request from the helm, and the other has to send one back within thirty seconds. Neither ship can be moving. A disabled NPC ship needs no handshake. You can dock straight onto a wreck and board it.

## Fuel and thrust

Ships carry two kinds of drive, and most hulls carry both.

**Plasma thrusters** burn plasma gas out of the **engine heater** on the tile behind them. Alt-click a heater to choose where it draws from: a gas tank slotted into it, or the ship's pipe network. In tank mode, refuelling is swapping in a full plasma tank; in pipe mode the engines run off whatever your gas system feeds them. See [Gas & Fuel](gas-economy.md).

**Ion thrusters** burn no gas. They pull off the ship's power grid, so their fuel gauge is really your SMES charge. Less thrust than a plasma drive, but they never need a fuel run.

Fuel use scales with your ship's **mass**, so a bigger hull costs more per burn (see [Ship Upgrades](ship-upgrades.md)). Individual engines can be switched off from the Fuel panel to save fuel; switch them all off and you are drifting.

## Damage and disabling

Below 50% hull integrity the helm refuses every command. Rebuilding hull mass (replacing destroyed floor and wall tiles) brings it back, and a ship that crash-landed needs 65% before it flies again. See [Ship Combat](ship-combat.md).

## Bluespace jump

The **Bluespace** button calibrates a jump out of the system. Calibration takes three minutes, then the pylon fires.

!!! danger "A bluespace jump ends your round"
    Your ship and everyone on it are removed from the round permanently. This is the "we are done, cash out" button, not a fast-travel option. The console asks you to confirm; press Bluespace again during calibration to cancel.
