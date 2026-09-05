---
title: Player Outposts
category: Economy
order: 5
blurb: Buying a deed, founding your own station on the overmap, building it out, and defending it from siege.
---

For 10,000 credits and three trade vouchers you can stop renting space and found your own station. A player outpost is a permanent structure on the [overmap](overmap.md) with its own interior, its own hangar, and a build region you fill in however you like. It lasts the whole round, and where you plant it decides whether anyone is allowed to shoot at it.

## Buying the deed

**Outpost deeds** are sold over the counter at Waystation Halcyon and Quartermain Depot, on their Colonial Registry shelf. The price is 10,000 credits plus 3 trade vouchers, and it does not go down.

A deed is bound to the buyer by name. Nobody else can use it, and each person may hold **one active claim per round**. If you already founded an outpost this shift, the registry refuses to sell you another deed.

## Founding

To found, your crew's ship has to be **holding still on an empty overmap tile**, not docked, not moving, and not on top of a planet, ruin or another outpost. Use the deed in hand and the registry catalogue opens.

Pick a shell and a name:

| Shell | What you get |
|---|---|
| Compact Habitat | One pressurised room with the essential consoles, a hangar elevator, and a charged power bay. Cheap on materials and quick to expand. |
| Waystation Frame | A proper station core: separate work and living space, a powered workshop bay, and a hangar elevator off the main hall. More to defend, more room to grow. |
| Bare Claim | No prefab at all. An empty sector, a survey pad, and a crate holding the two registry console boards. Bring your own everything, including the floor and the air. |

Confirming registers the claim, announces it galaxy-wide, and drops the outpost onto the overmap where your ship is sitting. Then fly over and dock to move in.

The two prefab shells arrive with lights, a pressurised core, an APC and cable, a charged SMES with an input terminal, and an **unanchored portable generator with fuel**. The area needs power, so once the SMES buffer drains it is on you to keep the generator fed or build something better.

!!! warning "Where you plant it is permanent"
    Zone rules lock in at founding and never change. An outpost founded in the patrolled outer ring is **protected from ship weapons forever**. An outpost founded in the contested band or the lawless deep is **raidable forever**. Nothing you build later changes that, and you cannot move it.

## The consoles

Every shell ships with two consoles, and if either is destroyed you can rebuild it, a fresh console relinks itself to whatever outpost's z-level it is standing on. The Bare Claim's starter crate holds both boards.

The **management console** is the owner's control panel. Ownership is tied to your account rather than your body, so it survives death and respawn. Everyone else gets a read-only view. From it you can:

- Rename the outpost (announced galaxy-wide, on a 5-minute cooldown) and set a public memo.
- Set the docking policy.
- Authorise other people to use the construction console.
- Buy a galaxy-wide **broadcast**.
- Transfer ownership to somebody standing on the outpost, or abandon the claim.

The **construction console** puts you behind a remote drone with a built-in RCD, RTD, RPD and RLD, fed from the outpost's ore silo. It is the same tool ships use to expand their hulls, pointed at your claim instead. Anything the drone builds is automatically pulled into the outpost's powered area so it gets light, gravity and APC coverage; anything you build by hand gets swept in the same way within half a minute.

The claim's **survey bounds** cover its entire z-level: **255 by 255 tiles**, with the starting shell centered on it. Every shell gets the same build area. If you use the ordinary landing pads, keep them clear for arriving ships.

## The hangar

Both prefab shells arrive with a **hangar elevator** already installed, which means visiting ships get their own private berth from the moment you found the place, exactly like a trader outpost. Ride the elevator from the concourse to any occupied berth and back.

If you took the Bare Claim, or you want the elevator somewhere else, the construction console has a three-step workflow for it: **plan** projects a coloured blueprint of the elevator kit under your drone, **rotate** turns it to face another way, and **confirm** stamps it down and wires it in.

Without an elevator, an outpost still has two ordinary landing pads, and that is all.

## Who is allowed in

The management console sets one of three docking policies:

- **Open**: anybody may dock without asking. This is the default.
- **By request**: a visiting ship's dock attempt queues a request, the owner is notified wherever they are, and they approve or deny it from the console. Approved ships stay approved.
- **Lockdown**: only the owner's own crew gets in.

You can also **ban** specific ships outright, which overrides everything including an existing approval.

## Advertising

A **broadcast** costs 2500 credits off your ID's account and runs for 20 minutes, with a 10-minute cooldown between purchases. Buying one pushes a one-time notification to every crewed ship in the galaxy, lists your outpost with its memo and coordinates on every ship's [mission board](missions.md) feed, and pins it on every helm's nav chart for the duration. It is the only way anyone finds a shop, bar or repair yard you have built out in the middle of nowhere.

## Raiding and siege

An outpost founded outside patrolled space is a legitimate military target and shows up on other crews' combat consoles as one. The rules are narrow: only outposts founded outside green space can be locked at all, and a missile launcher will only fire on one while the **attacking ship** is itself sitting in the contested band or the lawless deep. Nobody shoots at anything from inside patrolled space.

Siege damage lands as missiles, and there is no ship-to-ship shield to soak them. What you can build instead is an **outpost shield generator**.

## Shield generators

The generator is a machine you research (through the shuttle shield systems node), build into a frame, and wrench down **inside the claim's survey bounds**. While it is anchored, powered and holding charge, incoming missiles detonate at the edge of your survey bounds instead of hitting your buildings.

The numbers matter:

- A generator starts with a **1000-point** charge pool. Better capacitors add 50% per tier.
- A missile drains charge equal to its damage: 200 for a light missile, 400 for a standard, 600 for a heavy. So a base pool eats roughly two standard missiles before it collapses.
- It recharges at 5 points per second off outpost power, faster with better micro-lasers, and takes about three and a half minutes to refill from empty.
- **Recharging pauses for ten seconds after every hit.** Sustained bombardment outruns regeneration; shields do not heal under fire.
- It draws 10 kW while charging and 1 kW while holding a full field, so your power supply has to be real.

Building a second generator does **not** double your shield. Only the first working unit holds the field; the rest sit cold on standby and take over (empty) if it dies or loses power. Stacking generators buys redundancy, not capacity. Both sides get told what happened on every absorbed hit, including the charge you have left.

!!! danger "When the shield collapses, everything lands"
    Once the charge pool hits zero, missiles strike your buildings directly. A depleted shield with an attacker still on station is the point at which you either drive them off or lose the station.

Nothing stops boarders. The shield is anti-ordnance only; a crew that docks at your hangar walks in the same as anybody else, which is what the docking policy and ban list are for.

## Endings

There is no cross-round persistence. When the round ends, the outpost, its contents and its deed are all gone. Nothing carries over.

Two things can happen before then. You can **transfer** ownership to somebody standing on the outpost, provided they have not already founded a claim this round. Their account becomes the owner and yours does not get a second claim. Or you can **abandon** it, which announces the abandonment galaxy-wide, clears ownership, reopens docking to everybody and kills any live broadcast. The station itself stays standing, unowned, with the doors open. Your account still cannot found another.
