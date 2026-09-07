---
title: Player Outposts
category: Economy
order: 5
blurb: Found a home with its own bank, cargo deliveries, research, and resident cryopods.
---

Player outposts are homes on the [overmap](overmap.md) that last for the round. Run a workshop, receive supplies, and welcome returning residents even after your founding ship is gone. Visiting ships keep their own money, equipment links, and crew membership.

## Founding a home

Buy an **outpost deed** from the Colonial Registry shelf at Waystation Halcyon or Quartermain Depot. Each costs **10,000 credits and 3 trade vouchers** and is bound to its buyer. You can own multiple outposts.

Your crew's ship must be stationary on an empty overmap tile, away from planets, ruins, and other outposts. Undock before using the deed. Choose a name and one of two homes:

| Home | Layout |
|---|---|
| Compact Habitat | A small pressurised core with room to expand. |
| Waystation Frame | Separate living and workshop space around a central hall. |

Both include a bank terminal, cargo console, empty ore silo, resident cryopod, management and construction consoles, and a hangar elevator. A charged SMES and portable generator provide starting power. Keep the generator fuelled or build another power supply.

!!! warning "Where you plant it is permanent"
    Zone rules lock in at founding. An outpost founded in the patrolled outer ring is protected from ship weapons. One founded in contested or lawless space is raidable. You cannot move it later.

## Managing and building

Use the **outpost management console** to rename the outpost, set a public memo, manage docking and residents, grant permissions, or transfer ownership.

A **Registry uplink** implant adds an **Outpost Management** action that works from anywhere, including other ships and sectors. Splice sells it for **2,800 credits**; it uses **2 neural load**. Choose any outpost you own or have management permission for. The implant grants no additional permissions, and removal or chrome failure disconnects remote access. Without it, use the physical console.

You can delegate management, bank withdrawals, and construction separately. Your founding ship's crew automatically become residents with construction permission. Other residents need construction permission granted separately.

The **construction console** controls a building drone supplied by your local ore silo. Link the console to the silo with a multitool and deposit materials before building. You can also expand the habitat with ordinary tools.

## Money and deliveries

The **bank machine** handles the outpost's money. Deposit from your ID account or physical currency; owners and treasury delegates can withdraw. The bank starts empty and keeps its balance through ownership changes or loss of the founding ship.

Order supplies through the ordinary **cargo console**, or buy sheets through a **Galactic Materials Market** you build locally. Both charge the outpost bank and send a physical freight ferry. Ride the elevator to **Freight Receiving** to unload it. No player ship needs to stay docked for deliveries.

Load eligible goods onto the ferry and dispatch it to export them. Payment goes to the outpost bank. Everyone must leave the ferry before it can depart. Failed deliveries refund undelivered purchases.

## Research and manufacturing

Build an **R&D server** and install its source-code disk. Copy its link with a multitool, then link R&D consoles, experiment equipment, and fabricators. Link fabricators to the local silo too, and supply materials. See [Research](research.md) for experiments and technologies.

To share research with a ship, build an **R&D relay** aboard it. Print the relay board from Fundamental Science at a circuit imprinter. The relay needs no disk; keep the research server at the outpost.

1. In **Outpost Management > Research**, choose your source server and a docked ship, then press **Invite**. You can send the invitation before its crew builds a relay.
2. A ship crew member clicks the **R&D relay empty-handed** and presses **Accept**.
3. Copy the relay's link with a multitool and connect ship equipment normally. Equipment built later can use the same link.

Any number of ship relays can share the outpost server's **tech tree and research points**, including after undocking. Research earned or purchased at one connected lab is available at the others. Each ship keeps its own bank account, separate research disk, and fabrication materials.

Outpost Management lists invitations and connections. Cancel an invitation or disconnect an individual relay there; the other fleet ships keep their access. Ship crew can also click their relay empty-handed to disconnect. You cannot download a technology disk through the relay.

Keep the relay and outpost server powered. After a power outage, restore power and relink equipment. Removing the source disk, replacing an endpoint, or changing the outpost owner requires a new invitation. A change of ship captain keeps the connection intact.

## Residents and visitors

Use Outpost Management to add residents and invite players back. There is no outpost resident limit. Admission can be **open**, **password**, **approved-only**, or **closed**.

Eligible players choose the outpost in the join menu and arrive through an available resident cryopod with an assistant loadout. Normal respawn rules and cryo cooldowns still apply. Returning residents keep their remembered access unless it is revoked; changing the password clears remembered password access.

Ship docking has separate controls:

- **Open:** visiting ships may dock freely.
- **By request:** approve requests in Outpost Management. A ship still waiting in your sector begins docking when cleared. It needs new clearance after leaving.
- **Lockdown:** only the owner's crew ships may enter. Existing visitors can leave.

Banning a ship overrides docking clearance. Use the hangar elevator to travel between the habitat and occupied visitor berths.

## Advertising

A **broadcast** costs **2,500 credits from the outpost bank** and lasts 20 minutes, with a 10-minute purchase cooldown. Buy it through Outpost Management with treasury permission. It announces the outpost to crewed ships, adds its memo and coordinates to [mission boards](missions.md), and marks it on helm charts. The panel shows why a purchase is refused.

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

## Ownership and abandonment

You can transfer ownership to another player, including someone who already owns an outpost. Abandonment leaves the buildings, bank balance, and research in place, but ends delegated permissions, research connections, and resident admission.

To take over an unowned outpost, visit its management terminal and choose **Claim outpost**. Abandoning or transferring a home does not prevent you from owning another. Outposts and their contents do not carry over between rounds.
