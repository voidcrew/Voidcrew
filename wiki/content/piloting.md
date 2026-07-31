---
title: Piloting Your Ship
category: Your Ship
order: 1
blurb: How to fly, scan, and dock your ship from the helm control console.
---

Everything your crew does starts at the **helm control console**. It flies the ship across the [overmap](overmap.md), runs your sensors, and holds the dock controls. Any crew member can use it — it refuses anyone who isn't on the ship's crew — and wall-mounted **ship viewscreens** show the same display without the controls.

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

Thrust is set with the compass rose: eight direction buttons and a square **brake** in the middle. A direction starts a continuous burn that runs until you press it again, pick another direction, or brake. Braking costs no fuel — you only pay to speed up.

The vertical slider beside the rose is the **throttle**, 1 to 100 percent. It sets how hard the engines burn, which is both how fast you accelerate and how fast you empty your tanks. Drag it, or focus it and use the arrow keys to step by 5. A diagonal burn puts half the thrust on each axis, so cutting a corner is not free speed.

!!! tip "Nothing stops you automatically"
    Space has no friction. If you set a burn and walk away from the console, the ship keeps accelerating and keeps going. Brake before you expect to arrive.

Burning toward a tile in a different zone band starts a **zone transition**: the engines cut, the ship holds still for ten seconds, then crosses. The brake cancels it and leaves you where you were.

## The navigation chart

The chart is the middle panel. Drag with the left or middle mouse button to pan, use the wheel or the slider to zoom, and double-click (or press **Recentre**) to snap back onto your ship. The coloured rings are the zone bands.

**Right-click** the chart or a contact for the action menu: set a course for the autopilot, interact with something sharing your tile, run a Ships scan on an unknown vessel, or clear a waypoint you are done with.

The drawer beside the chart has four tabs. **Contacts** lists every mark you know about with live distance and bearing. **At location** lists only things on your tile — the only things you can act on. **Comms** is the hail log (see [Radio & Comms](comms.md)). **Intel** holds sealed rumour charts bought from traders, which reveal a rare signal's coordinates when decrypted.

## Autopilot

Right-click a destination and choose **Set course**. The autopilot flies with the same headings and throttle you would use, so it burns the same fuel and sits out the same zone transitions — it steers, it does not teleport.

It routes around storms, asteroid fields and known hostile vessels, but only around things **this ship has actually seen**. It also halves cruise speed while flying into tiles you have never laid eyes on, so it has time to react to what turns up.

It stands down on its own if you are locked on by weapons, take hull damage, get caught in an interdiction field, or end up inside a hazard; touching the compass rose also drops it. On arrival it stops the ship and holds station.

## Sensors and radar

Two ranges matter here, and keeping them straight is most of navigating well.

Your **view ring** is a fixed four tiles and never changes. Everything inside it draws on the chart for free — planets, ruins, outposts, nebulas, storms, ships — and is then remembered permanently, drawn faded once you leave it behind. You chart the galaxy by flying it.

Your **sensor range** is how far an **active scan** reaches, and it is what radar research buys. A scan sweeps one category at a time and charts what it finds as a permanent waypoint. Scans have a one-minute cooldown, but an empty sweep costs nothing and can be retried at once.

| Research node | Cost | Scan range | Also gives you |
| --- | --- | --- | --- |
| *(none)* | — | 4 tiles | |
| Radar Array | 1000 | 6 tiles | |
| Radar Array — Signal Analysis | 2500 | 8 tiles | Names space ruins on the chart instead of "unknown signal" |
| Radar Array — Vessel Tracking | 5000 | 10 tiles | Plots and names other crews' ships out to full sensor range |

Vessels are the exception. They move, so they are never recorded — a ship is a live contact or nothing. Without the top radar tier you only see ships inside your view ring, and they read as **unknown contact** until a Ships scan resolves them. An unidentified blip hides whether it is a trader or a pirate, which is the point.

Storms and nebulas cannot be scanned at all. Either fly past one to record it, or buy a **star chart** from a trader and insert the disk into the helm, which charts a whole zone band at once.

Markers also arrive from elsewhere: accepted [missions](missions.md), bounties and revealed rumours all push one onto the chart, and trader outposts are permanently listed on every helm.

## Docking

Come to a **full stop** first — the Dock button refuses while you are moving. It labels itself with whatever is actually under you, so you can see whether you are about to land on a planet, a ruin, an outpost, or hold station in empty space. Docking runs a ten-second warmup and cannot be started while you are interdicted.

Docking at a **planet** loads its surface and puts your ship down on it. With an upgraded orbital survey console you can choose where on the surface you land instead of taking the default berth.

Docking with **another player ship** is a two-way handshake: one crew sends a request from the helm, and the other has to send one back within thirty seconds. Neither ship can be moving. A disabled NPC ship needs no handshake — you can dock straight onto a wreck and board it.

## Fuel and thrust

Ships carry two kinds of drive, and most hulls carry both.

**Plasma thrusters** burn plasma gas out of the **engine heater** on the tile behind them. Alt-click a heater to choose where it draws from: a gas tank slotted into it, or the ship's pipe network. In tank mode, refuelling is swapping in a full plasma tank; in pipe mode the engines run off whatever your gas system feeds them — see [Gas & Fuel](gas-economy.md).

**Ion thrusters** burn no gas. They pull off the ship's power grid, so their fuel gauge is really your SMES charge. Less thrust than a plasma drive, but they never need a fuel run.

Fuel use scales with your ship's **mass**, so a bigger hull costs more per burn (see [Ship Upgrades](ship-upgrades.md)). Individual engines can be switched off from the Fuel panel to save fuel; switch them all off and you are drifting.

## Damage and disabling

Below 50% hull integrity the helm refuses every command. Rebuilding hull mass — replacing destroyed floor and wall tiles — brings it back, and a ship that crash-landed needs 65% before it flies again. See [Ship Combat](ship-combat.md).

## Bluespace jump

The **Bluespace** button calibrates a jump out of the system. Calibration takes three minutes, then the pylon fires.

!!! danger "A bluespace jump ends your round"
    Your ship and everyone on it are removed from the round permanently. This is the "we are done, cash out" button, not a fast-travel option. The console asks you to confirm; press Bluespace again during calibration to cancel.
