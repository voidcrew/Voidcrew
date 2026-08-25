---
title: Ship Combat
category: Danger
order: 1
blurb: Missiles, laser turrets, shields and boarding actions. How two ships kill each other on the overmap, and where you're allowed to try.
---

Ship-to-ship combat is fought from a weapons system console by one crewmember while everyone else keeps the ship alive. You lock a target on the overmap, switch to a camera view of their hull, and shoot at specific rooms. Missiles blow holes in their ship; lasers strip their shields; an interdiction system stops them running. None of it exists until you research and build it, and most of it is illegal outside the deepest band of the galaxy.

## Where you're allowed to fight

Combat rules are set by the [overmap zone](overmap.md) your ship is sitting in.

| Zone | Weapons | Interdiction & forced docking |
|---|---|---|
| Neutral Zone (green) | No | No |
| Contested Zone (yellow) | No | Yes |
| Lawless Zone (red) | Yes | Yes |

Both ships are checked. If either of you slips into the Neutral Zone the lock breaks immediately and the attack ends, which makes green space a genuine escape route. The Contested Zone is the interesting middle: you cannot shoot another ship there, but you can pin one in place, force it to dock with you and board it on foot.

There is one exception to the weapons ban. Missiles (never lasers) may be fired outside the Lawless Zone when the locked target is a raidable [player outpost](player-outposts.md), and only if your own ship is not sitting in patrolled green space. Laser targeting cannot resolve station-scale targets at all, so sieging a claim is missile work.

## The weapons system

Every weapon is a separate machine that has to be linked to a **weapons system** console. Machines built on your own ship link themselves automatically a couple of seconds after they power up; anything you salvage or move can be relinked by buffering it with a multitool and using the multitool on the console.

!!! warning "Weapons only fire from the hull's outer edge"
    A launcher or turret must sit on a tile that touches the outside of the ship. Anything buried inside the hull shows **NOT ON EXTERIOR** when you examine it and will never fire. Unwrench it, drag it to the rim, wrench it down again.

The console also only answers to your own crew, and it refuses to acquire a lock while you are docked.

Everything here comes off the research tree. **Shuttle Warfare Systems** unlocks the console; missiles, shields, lasers, cloaking, interdiction and the data siphon all branch off it, with standard and heavy warheads behind two further nodes. Cargo sells missile parts and a launcher kit if you would rather buy than print. See [ship systems](ship-systems.md) for the machines themselves.

## Missiles

A missile is built by hand, not printed whole. Take a missile frame, wire it with cable, install a tracking circuit, insert a warhead, then seal it with a screwdriver. Frames are too heavy to carry, you drag them. Drag the finished missile onto a launcher to load it.

| Warhead | Damage | Blast |
|---|---|---|
| Light | 200 | Small |
| Standard | 400 | Medium |
| Heavy | 600 | Large |

A fully assembled chemical grenade can go into a frame instead of a warhead: small blast, then it dumps its reagents inside the target ship. Shields stop the chemical payload completely.

A launcher holds one missile at a time and takes a few seconds to load, so sustained fire means a loading crew, not a gunner.

## Lasers

Laser turrets are the anti-shield weapon: they do **one and a half times** damage to shields, where missiles do only half. Each turret carries its own power cell that trickle-charges off the ship grid, so a turret with no grid power simply stops working after a few shots.

Turret output is set from the console as a single power level for all of them, from 25% to 200%, trading cell charge for damage. Base output is 50 damage per shot at 100% with a two-second cooldown; better micro-lasers raise damage, capacitors charge the cell faster, servos shorten the cooldown. You can link up to ten turrets to one ship, and firing them all at once combines their damage into a single heavy beam.

## Shields

A ship shield generator contributes 500 shield health and 10 points per second of regeneration to a shared ship-wide pool, and several generators stack. Power allocation runs from 0% (off) to 200% and is set from the console. Power draw scales with the size of your hull, so shields on a big ship are a serious load on the grid.

When shields are up, physical barriers appear around the hull and block **everything**: missiles, meteors, boarding pods and people.

!!! danger "Shields will kill your own crew"
    The shield wall gibs anyone standing where it forms, and nobody can walk in or out while it is up. Turn shields off before an EVA, and warn the deck before you turn them on.

Break the shields and they stay down for thirty seconds, and any charge they were holding is gone.

## Getting a lock and firing

Enemy ships show on sensors within three tiles, and you can lock one at that range. The lock takes five seconds and **the target is warned the moment you start**, their ship blares a combat alarm. Moving out of sensor range, losing line of sight in a nebula, or either ship entering the Neutral Zone all break it.

With a lock you enter attack mode: a camera view of the target's interior. Aim at a specific tile and fire: one missile, every missile, one turret, every turret at once, or an assault pod with your boarding party inside it. You can also choose which side the missiles come in from, which matters when the room you want is behind three layers of wall. Attack mode needs the ships within two tiles of each other, so the shooter has to close. Firing anything breaks your own cloak.

## Support systems

- **Assault pod tube.** A hull-mounted tube that throws a crewed [drop pod](drop-pods.md) at the target. The pod flies in like a missile, cuts a hole through the plating and puts the people inside it on the other side of it. It dies against a live shield, so it is the move you make *after* the guns have done their work.
- **Interdiction system.** Pins a target within two tiles: kills their momentum, throws everything inside them across the deck, halves their engine speed and blocks their cloak. Five-minute cooldown, legal in the Contested Zone. Share an overmap tile with an interdicted ship and you can force it to dock with yours: the other way boarding starts, and it cannot undock for two minutes.
- **Cloaking device.** Hides your ship on the overmap for thirty seconds base, longer with better capacitors. Drops the instant you fire or someone completes a lock on you.
- **Data siphon.** With a lock held, drains credits out of the target's ship account.
- **Electronic warfare suite.** Uses a held lock to hack the target's onboard systems (lights, doors, air alarms, engines, shields, fire control) instead of damaging the hull. Everything it does is temporary, and everything it does builds toward a trace that names you. See [Ship Hacking](ship-hacking.md).
- **Nebula concealment.** Free. Hold position on a nebula tile for ten seconds and your ship goes dark, dropping every combat connection on you. Not available while interdicted, and a running ram scoop lights you back up.

## Taking hits

Your hull integrity is literally your ship's floor and walls. Every tile blown into space lowers it; every tile you rebuild raises it. Reinforced walls count for more than plain walls, and plain walls for more than floor.

A missile that lands inside your hull does what any large bomb does: it deletes tiles, opens the compartment to space and starts fires. Expect breaches, depressurisation, wrecked machinery and casualties.

At 60% integrity the ship starts screaming a critical damage alarm. At **50% the ship goes down**. It stops dead, throws sparks through every compartment and emergency-lands: onto the planet below you if there is one, otherwise into a crash site other crews can find. It is not deleted, and neither are you. Rebuild the hull back to 65% and the engines come back online.

## Being boarded, and repairing after

Pirates deliver boarders by drop pod, and only when your shields are down. Player crews arrive either through a hull breach cut by an [assault pod](drop-pods.md) or on foot after a forced dock. Either way the fight moves inside your ship, where hull weapons are useless and what matters is doors, chokepoints and whether anyone thought to buy guns. A pod entry announces itself (the ship calls the breach the moment it lands) and leaves a hole in the wall that has to be welded shut afterwards.

There is no repair button afterward. Rebuilding the hull is engineering work: plating and rods for floors, metal for walls, a welder for the rest. Broken weapons need their parts replaced, machines shaken loose by the blast need rewrenching, and anything now buried inside a rebuilt hull will not fire until you move it back to the rim. Dock at a [trader outpost](trader-outposts.md) if you can. Nothing can shoot you there, and random events skip ships in a safe harbour.

## Getting out

In rough order of reliability: fly for the Neutral Zone; go dark in a nebula; cloak and drift; kill the interdictor; or, against pirates, answer their hail and pay them off (see [Pirates & NPC Ships](pirates-and-npc-ships.md)). There is no formal surrender between player crews. You hand over cargo, dock, or run.
