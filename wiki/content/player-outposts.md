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

| Home | Style |
|---|---|
| Salvaged Waystation | Run down: an old roadhouse, rust and grease included. |
| Registry Habitat | Clean: new from the registry's catalogue. |

The style you pick is for good. Every room you buy later, and the ship bay, is built to match it. Both homes work the same way and come with the same things: a bank terminal, cargo console, empty ore silo, resident cryopod, management and construction consoles, and a hangar elevator. A charged SMES and portable generator provide starting power. Keep the generator fuelled or build another power supply.

!!! warning "Where you plant it is permanent"
    You cannot move an outpost later. Ship weapons never fire on outposts, wherever they are.

An outpost fits on one level, with the habitat you build in the middle. A dark border marks where the build area stops; the ship bay, four docking berths and the freight ferry's pad sit around it, out of reach and out of range of anything you build. The only way in or out for a ship is the **hangar elevator**: there is no open landing pad, and a hull with nowhere clear to dock is turned away.

## Managing and building

Use the **outpost management console** to rename the outpost, set a public memo, manage docking and residents, grant permissions, or transfer ownership.

A **Registry uplink** implant adds an **Outpost Management** action that works from anywhere, including other ships and sectors. Splice sells it for **2,800 credits**; it uses **2 neural load**. Choose any outpost you own or have management permission for. The implant grants no additional permissions, and removal or chrome failure disconnects remote access. Without it, use the physical console.

You can delegate management (steward), bank withdrawals (treasurer), service prices (pricer) and construction (builder) separately, from the **People** tab. Your founding ship's crew automatically become residents with construction permission. Other residents need construction permission granted separately. When the console refuses something, it says why in chat.

The **construction console** controls a building drone supplied by your local ore silo. Link the console to the silo with a multitool and deposit materials before building. You can also expand the habitat with ordinary tools. It works like a ship's construction drone (see [Ship Systems](ship-systems.md#changing-the-ship-itself)), and its **Tools** tab also places the hangar elevator.

The construction console's **Door Access** tool sets who a door opens for: pick the tool, then click a door in the camera view for a choice of **Public**, **Members**, **Staff** or **Owner**, and which side always opens from within. A newly built door starts Public; the service rooms' own staff doors start Staff. Setting a door never locks you out of it from inside.

## Money and deliveries

The **bank machine** handles the outpost's money. Deposit from your ID account or physical currency; owners and treasury delegates can withdraw. The bank starts empty and keeps its balance through ownership changes or loss of the founding ship.

Order supplies through the ordinary **cargo console**, or buy sheets through a **Galactic Materials Market** you build locally. Both charge the outpost bank and send a physical freight ferry, which lands on the outpost's **cargo dock**. The cargo dock is a free upgrade: buy it and place it from the **Rooms** tab of the management console. Until it is placed, the cargo console cannot order. No player ship needs to stay docked for deliveries.

Load eligible goods onto the ferry and dispatch it to export them. Payment goes to the outpost bank. Everyone must leave the ferry before it can depart. Failed deliveries refund undelivered purchases. Keep off the landing pad when the alarm sounds: the ferry lands on whatever is there and crushes it.

## Upgrades

The **Rooms** tab of the management console sells prefabricated rooms: the free **cargo dock**, a **prison wing** where the outpost is paid to hold prisoners, **cell block extensions** for the wing (see [Prison Wing](prison-wing.md)), and the service rooms your outpost can sell to visiting crews, such as the cloning bay, medical lab, shop, storage and teleporter. Every room comes in your outpost's style: a run-down outpost gets run-down rooms, a clean one gets clean rooms. The layout can differ between styles, but the room does the same job either way. Buying one needs management and treasury permission and is paid from the outpost bank. Until the room is placed, **Cancel purchase** refunds the full price.

Press **Place** to open the placement map, a plan of the ground around the outpost:

- Turn the mouse wheel to zoom. Drag with the middle mouse button, or use the arrow keys, to pan. Hold Shift with the arrows to move faster.
- The red line is the build range: part of the room must be within 8 tiles of the outpost or one of its rooms.
- Grey is floor, light grey is wall, blue is window, amber is door and brown is something in the way. Dark red ground can never be built on: docking berths, the hangar elevator, the arrival point, other rooms and ground outside the claim.
- The room follows the cursor, green where it fits and red where it does not, with the blocked tiles marked. Click to bring up **Build** and **Rotate**. A greyed-out Build says why in its tooltip.
- Lattice and loose items do not block a room. They are cleared out of its way when it is built. People do: nobody can be standing on the spot when you build.
- A cell block extension only joins a free side wall of the prison wing. The map outlines each free spot, already turned the right way, and yellow squares show where the wall opens into the wing.
- **Rescan** surveys the ground again, for example after you clear something away.

Placement is permanent. A built room cannot be moved or refunded.

## Service rooms

Service rooms sell things to visiting crews. Members use them free: the owner, residents, and the crews of the owner's ships. Everyone else pays the outpost's price from the ID they present, and the money goes to the outpost bank. An outpost with no owner charges nobody.

| Room | Cost | What it sells | Default price | Highest price |
|---|---|---|---|---|
| Cloning Bay | 3,000 cr | A clone in one of eight vats | 600 cr | 5,000 cr |
| Medical Lab | 2,000 cr | A 30 minute lab pass | 300 cr | 2,000 cr |
| Shop | 2,000 cr | Whatever the staff stock | set per item | 1,000,000 cr |
| Safe Storage | 1,000 cr | One of thirteen lockers for the round | 200 cr | 5,000 cr |
| Teleporter | 6,000 cr | Arrival by network pad | 200 cr | 2,000 cr |

Set prices on the **Pricing** tab of the management console. Who may use a service room is set door by door, with the construction console's Door Access tool. The teleporter has no door to set; its own arrival policy controls who may arrive.

### Who runs the market

Three roles from the **People** tab share the work:

- **Stewards** manage the outpost, open and close rooms and evict ships from the ship bay.
- **Treasurers** withdraw from the bank and set prices.
- **Pricers** set prices and nothing else.

The owner, stewards, treasurers and pricers stock the shop and take items out of it free. Other residents pay at the register like anyone else.

### Cloning bay

Imprint yourself at a vat while you are alive. Each player can hold one clone per outpost, and a clone is used once: waking in it spends it. When the clone is grown you get a **Clone Ready** alert, and after you die you pick where to wake with the **Wake in a Clone** button on your ghost.

While the outpost has an owner, a visitor cannot wake there during a lockdown or while their crew is banned. The clone is kept, so they can wake once the block lifts.

Clones step out naked, so the bay has a wardrobe that hands out clothes free.

### Medical lab

A lab pass lasts **30 minutes** and covers the auto-surgeon, the sleepers and the cryo cells. You can renew it once it has less than 5 minutes left. The terminal only sells a pass when the lab can actually treat the patient, either with a procedure or because they are hurt. A visitor can pay for other people's passes; members cannot buy passes for visitors.

### Safe storage

A locker rents for the rest of the round. You can rent one locker per outpost. It opens for you and nobody else, not even the owner, and it still knows you after death, cloning or a rejoin. There are no refunds: giving the locker up, which you can only do while it is open, returns nothing.

Lockers refuse people and animals, bombs, grenades and anything that can set one off, ship keys and contract goods.

### Shop

Staff fill the stock cabinet in the back room and price each listing. Customers buy at the register out front, up to 10 items or a full stack at a time. Unpriced stock is not for sale.

### Teleporter

Network pads send one person at a time from outpost to outpost. The network covers every player outpost with a Teleporter room and a public pad at each trading outpost, and trips can cross zones. Trading outpost pads only reach player outposts, never each other.

- **The destination sets the fare.** It is taken from your ID account when the pad fires, never for leaving. Members of the destination and anyone arriving at a trading outpost travel free. A cancelled trip costs nothing.
- **Charge time:** stand on the pad for 5 seconds, or 10 across zones. Stepping off, taking damage or passing out cancels the trip. You arrive on the other outpost's pad.
- **Cooldown:** 2 minutes between trips. A pad someone is leaving from, or arriving on, is busy until they are gone.
- **What stays behind:** other people, carried or pulled; animals; freight pods; contract goods and ship keys.

The owner chooses who may arrive: **Open**, **Members**, **Allow list** (chosen outposts' pads) or **Closed**. Lockdown admits members only. With docking set to **By request**, an open pad admits members and approved crews only.

### Docking fee

The ship bay can charge a docking fee, set on the Pricing tab (up to 5,000 cr; the default is nothing). The owner's own ships and any ship docking at an ownerless outpost pay nothing.

The ship holds position and its helm shows the fee. The captain approves it there, or any crew member when there is no captain. An approval lasts 2 minutes. The fee leaves the ship account and is held until the ship arrives in the bay, then paid to the outpost. If the dock falls through, the fee goes back to the ship.

The owner or a steward can evict a ship from the bay. It gets three minutes to undock, and its fee back if it arrived in the last 30 minutes. A hull with nobody aboard while its crew is at the outpost is moved to a hangar berth instead.

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

Use the **People** tab of Outpost Management to add residents and to invite players back by account name. There is no outpost resident limit. Admission can be **open**, **password**, **approved-only**, or **closed**. The People tab warns when no resident cryopod is free.

Eligible players choose the outpost in the join menu and arrive through an available resident cryopod with an assistant loadout. Normal respawn rules and cryo cooldowns still apply. Returning residents keep their remembered access unless it is revoked; changing the password clears remembered password access.

Ship docking has separate controls:

- **Open:** visiting ships may dock freely.
- **By request:** approve requests in Outpost Management. A ship still waiting in your sector begins docking when cleared. It needs new clearance after leaving.
- **Lockdown:** only the owner's crew ships may enter. Existing visitors can leave.

Banning a ship overrides docking clearance. The outpost has four **standard berths**, each sized to fit the ship docking into it; if none is free, an arriving ship is told parking is unavailable. Visitor berths work as they do at [trader outposts](trader-outposts.md): only the visiting ship's crew can take the hangar elevator down to one. The owner gets no exception.

A hull defense turret bolted to the outpost answers only to its owner, stewards, treasurers, residents and builders. Visitors cannot switch it off, change its targeting, unbolt it or scrap it. The same goes for turrets built on the outpost and for turret control panels. A cleanbot can pass a prison wing's staff doors, so one built in the office can clean the yard.

## Ship Bay

The **Rooms** tab sells a permanent **ship bay** for 10,000 credits, 100 iron and 50 glass from the outpost silo; it needs a working hangar elevator. Ships reach it through the **Ship Bay** option at the helm, and people by elevator. When a ship in the bay asks to use the outpost silo, the request appears on its bay row. An evicted ship has three minutes to undock, and gets its docking fee back if it paid in the last 30 minutes.

The bay's own **shipyard console**, found only in the bay itself, has two tabs:

- **Shop** orders a new ship, built at the bay by your delivery drones and stocked with its usual starting supplies, paid from the outpost bank or your own account.
- **Checkpoints** saves a captain's docked ship: **10,000 credits** the first time, **5,000 credits** to update it later. If that ship is ever lost or its hull abandoned, the same captain can pay to have it rebuilt from the saved checkpoint. The delivery drones do the rebuilding in one visible pass, then the ship launches into the bay.

## Advertising

A **broadcast** costs **2,500 credits from the outpost bank** and lasts 20 minutes, with a 10-minute purchase cooldown. Buy it through Outpost Management with treasury permission. It announces the outpost to crewed ships and marks it on helm charts. A refused purchase says why in chat.

## Ownership and abandonment

You can transfer ownership to another player, including someone who already owns an outpost. Abandonment leaves the buildings, bank balance, and research in place, but ends delegated permissions, research connections, and resident admission.

To take over an unowned outpost, visit its management terminal and choose **Claim outpost**. Abandoning or transferring a home does not prevent you from owning another. Outposts and their contents do not carry over between rounds.
