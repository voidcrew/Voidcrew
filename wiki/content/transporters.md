---
title: Transporters
category: Your Ship
order: 4
blurb: Beam crew down to a planet and back without ever landing the ship.
---

A **transporter** puts people on a surface and pulls them back while the ship stays in orbit. It is the late-game answer to the drop pod: instead of a one-way crate fired at a planet, you get a two-way lift you can use over and over. It costs a lot of research and a lot of bluespace crystal to get there.

## Researching it

Three nodes, in order. Each needs surveys from your [orbital survey console](ship-systems.md) as well as points, so you cannot buy your way past the exploring.

| Node | Points | Also requires | What it gives you |
| --- | --- | --- | --- |
| Molecular Transporter | 12,000 | 3 planets surveyed | The pad, console and transponder designs. Beam down to open ground the computer picks; beam up transponder carriers standing in the open. |
| Transporter Pattern Targeting | 20,000 | 5 planets, 2 asteroids surveyed | The targeting scanner: pick the exact tile at either end, beam through a roof, and pull up anything standing on the coordinates. |
| Transporter Biofilter Matrix | 30,000 | - | Stops passengers taking damage in transit, cuts 20 seconds off the pad's recharge, and lets the console detect a sabotaged pad. |

## Building it

Three pieces, all printed from an R&D suite:

- **Transporter pad**: the platform. Its board is expensive on its own, and assembling the machine also eats **six bluespace crystals** on top of the usual capacitors, servos, scanning module and matter bin.
- **Transporter control console**: aims the pad and holds the research unlocks.
- **Site-to-ship transponder**: a pocket-sized beacon, printed on a protolathe, that the crew carries down with them.

A console adopts an unclaimed pad within a few tiles of it on its own, so a pad built next to a console just works. Otherwise save the pad to a **multitool** buffer and use the multitool on the console; the pad has to be on the same vessel.

The console also needs a **research uplink**: multitool your ship's R&D server, then the console. Without it the console behaves as if you have researched nothing.

## Getting a lock

The transporter beams onto whatever your ship is **sharing a tile with** on the overmap, a planet, a space ruin, or a meteor field. You do not dock; you sit in orbit alongside it. Empty space is not a target.

An orbital lock only holds while the ship is still. **The moment the engines burn, the lock drops** and anyone using the targeting scanner is thrown out of it. Park, then beam.

## Beaming down

Everything standing on the pad goes. Walk on, have someone at the console press the button, and stay put.

Without the targeting node the console picks the site: a random patch of open ground on the planet below. It will not choose a cave. It also only does this for planets. A ruin or a meteor field has no charted open ground to fall back on, so those need the targeting scanner.

With the targeting node, **Open scanner** gives the operator a remote view of the surface and a crosshair that turns green on a legal tile and red on an illegal one. Set the pattern lock, close the scanner, and beam. A locked site can be under a roof or inside a structure; without the node, beams need open sky. Walking away from the console closes the scanner.

### What the beam does

A beam is a **cycle**, not an instant. A column of light comes down at both ends and stands there for the whole cycle, ten seconds on a stock pad, as low as four with the best servos. Only what is still standing in the column when the cycle ends actually moves.

That cuts both ways. Someone who steps clear of the light in time stays behind, unharmed. Someone who walks *into* a column at the destination end is standing where people are about to arrive. The arrival column is visible from a long way off under open sky, so the far end always gets warning.

Anything you are dragging is not in the pattern buffer and does not come with you.

If the pad loses power mid-cycle, it drops the pattern lock and nobody moves.

## Transponders

A transponder is how the ship finds you again. Touch one to a pad to pair it, and that pad's console can see where it is and pull it home. At the console, each transponder in range is listed with who is carrying it, where they are, and whether that spot can take a beam.

Squeeze it in your hand to **request a beam-up**. That works with nobody at the console, as long as the pad is powered, idle and off cooldown, if it isn't, the transponder buzzes the reason at you. It is not a teleporter of its own; all it does is talk to the pad.

!!! tip "Everyone going down carries one"
    Without the targeting node, a transponder is the *only* way back up. Lose it, or wander into a roofed area, and the ship cannot find you.

Once the targeting node is researched the console can pull up whatever is standing on a locked tile, transponder or not, willing or not. Consider what that means when you land on a planet another crew is already on.

## What a pattern buffer will hold

A stock pad moves **two** things per cycle, going up by one for each tier of scanning module above the first. Living things are loaded first, so a pile of crates cannot crowd a person out of a small buffer.

It will not move anchored objects, anyone strapped into a bolted chair, mechs, or megafauna. Those are too big for a buffer at any tier.

## Upgrading the pad

| Part | Effect |
| --- | --- |
| Capacitors | Shorter recharge between cycles, and less power per beam. |
| Servos | Shorter beam cycle, down from ten seconds to four. |
| Scanning module | More objects per cycle. |
| Matter bin | Closes the biofilter gap, so passengers arrive in better shape. |

A stock pad takes 100 seconds to recharge between cycles. Fully upgraded, plus the biofilter node, that floors at 25 seconds.

## Arriving in one piece

A cheap pad hurts. Until the biofilter matrix is researched, anyone riding a pad with undersized matter bins takes burn damage on arrival. The smaller the bin, the worse it is. Upgrading the bins reduces it; the biofilter node removes it entirely.

Examine a pad and it will tell you outright when its biofilter is undersized for its buffer.

## Sabotage

A transporter pad can be **emagged**, and this is the reason to care who has access to your machine room.

An emagged pad shows nothing. No message, no icon change, no alarm. It looks and behaves exactly like a working pad right up until someone rides it. When they do, the interlocks that check an arriving pattern against the one that left are gone, and they rematerialise wrong: usually maimed and badly burned, sometimes not finishing at all.

!!! danger "Only one thing detects it"
    A console with the **biofilter matrix** researched reports pattern integrity as *corrupted*. Below that tier it reads *unknown* and a cut interlock is indistinguishable from a healthy pad. If you have people beaming down and back regularly, that node is a safety device, not a luxury.

Replacing or rebuilding the pad clears it.
