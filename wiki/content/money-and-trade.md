---
title: Money & Trade
category: Economy
order: 1
blurb: Credits, trade vouchers, the ship bank, the cargo console, and the schematics that unlock new gear.
---

Voidcrew has no station budget and no paychecks. Every credit your crew spends is one you earned by selling something, finishing a contract, or taking it off somebody else. There are two in-round currencies. Credits, which live in your ship's shared bank account, and trade vouchers, which are physical chits you carry, and they buy different things on purpose.

## The two currencies

**Credits** are the everyday money. They sit in one bank account shared by the whole crew: when you spawn, your ID is bound to the ship's account rather than a personal one, so anything anyone earns goes into the same pot and anything anyone spends comes out of it. The account starts empty. Credits pay for cargo orders, most trader stock, neural imprint fees, outpost deeds, and bounties you post yourself.

**Trade vouchers** are tamper-sealed chits that stack in your pocket like cash. They cannot be bought with credits, ever. You earn them by finishing dangerous contracts and by selling traders loot that can't be manufactured aboard a ship. Planet minerals, fauna harvests, ruin finds, deep-band gases. Any trader outpost honours them. Being a physical item, they can also be dropped, stolen and demanded as pirate tribute, so carrying a large stack into the deep is a real decision.

!!! tip "What vouchers are for"
    Vouchers buy the tier of gear no shop will sell for money: weapon schematics, syndicate MODsuit hardware, ship shield and interdiction boards, military-grade [cyberware](cyberware.md), top-tier [exploit software](ship-hacking.md), and the charts that reveal rare ruins. If you want any of that, you have to go somewhere dangerous.

There is also an out-of-round currency, **ship parts**, extracted at the end of a round and spent between rounds on new hulls and modules. See [Ship Upgrades](ship-upgrades.md); it has nothing to do with the credits in your bank.

## The ship bank

Every standard hull carries a **bank machine** among its [ship systems](ship-systems.md). It displays the account balance and is what the cargo console draws money from. Examining it tells you which account it is connected to.

If the machine ever loses its link (you built a new one, or the ship changed hands) swipe an ID card on it to connect that card's account. A multitool copies the machine into its buffer so you can point a cargo console at it.

The bank machine is also where **physical money** turns into spendable credits. Loose cash and holochips looted out of a ruin do nothing sitting in your bag; feed them to the machine and the value lands in the ship's account. It refuses cash while it has no account connected, so nobody wastes a holochip on an unlinked machine.

Your own ID is what pays at trader counters, at the neural imprinter, and for outpost broadcasts. If your ID has no account on it, those machines will refuse you.

## The cargo console

The **cargo console** is how you buy supply crates and bulk-sell salvage. It orders from the standard supply catalogue, and it only works when your ship is **docked in empty space** and **holding still**. You cannot call cargo while flying, at a planet, or at an outpost.

The flow:

1. Add packs to the cart. The total is checked against the ship account.
2. Hit send. A cargo shuttle arrives after about 30 seconds and docks alongside your ship.
3. Your order materialises in its bay and a requisition form prints at the console. Carry the crates aboard.
4. Load anything you want to **sell** into the bay.
5. Hit send again. The shuttle takes 5 seconds to leave, then everything left in its bay is sold and the proceeds land in the ship account.

The console announces what sold and for how much, and keeps a scrollable transaction history.

!!! warning "Clear the shuttle before you send it"
    The shuttle refuses to depart with a living creature aboard, and everything else left in the bay is sold. Do not leave your toolbox on the floor.

Export values are roughly a quarter of what the same item costs to buy, so you cannot make money by cycling crates. Cargo turns salvage, ore and unwanted loot into credits; it is not an arbitrage machine.

Two extras: coupons found in loot slot into the console for a discount on a matching pack, and supply companies occasionally offer a **loan**, free credits now in exchange for a crate of their goods riding along on the next delivery.

## Selling to traders

The cargo console is not the only buyer. Every trader outpost keeps a **wanted ledger**: a short list of things that trader is buying this round, with a fixed payout each. See [Trader Outposts](trader-outposts.md) for where to find them.

Selling at a counter differs from cargo in three ways:

- The trader takes goods from anywhere on you: hands first, then bags and pockets. Anything you are **wearing** is skipped, so you cannot accidentally sell the suit off your back.
- Credit payouts go to your ID's account. Voucher payouts appear in your hand.
- Each ledger entry has limited demand for the round. Once the trader has bought all they want, that line closes until a supply convoy comes through.

Sample lines: Barnaby at the waystation pays 300 credits per five gold ore, 500 per two diamonds, 150 for any fresh fish. Roux at the waystation diner pays 60 per home-cooked meal, 120 per hand-made pie and 180 per whole cake, real cooking only, never vending-machine food or her own plates. Sarge at the depot pays 250 per two goliath hide plates, 400 per three glacial cores. Vex at the black market is the only trader who pays in vouchers, one per five raw telecrystals, one per legion core, two per set of syndicate documents. Traders also buy **gas** by the tank; see [Fuel & Gas](gas-economy.md).

## Blueprints and the imprinter

Some weapons cannot be researched, bought assembled, or printed. They exist only as **schematics**: rolled-up paper you find in ruin loot or buy from a trader.

While you are carrying a schematic anywhere on your person, its recipe appears in your ordinary crafting menu. No workbench is involved; you can build it wherever you are standing. Gun recipes still consume a machined weapon component (printed at a protolathe behind its research node) plus a firing pin, so the schematic is the permission, not the whole cost.

**Crafted ballistic weapons arrive unloaded**, with no detachable magazine or chambered round. Manufacture or find ammunition separately.

The **L6 SAW** is a major manufacturing investment. Material quantities below are in sheets, before lathe discounts:

| Step | Materials |
|---|---|
| Print the receiver | 100 iron, 30 titanium, 20 plastic, 10 silver, 10 diamond |
| Assemble the gun (45 seconds) | Receiver, 20 plasteel, one firing pin |
| Print a 50-round 7mm magazine | 50 iron, 10 titanium, 10 plasma, 5 plastic |

Receiver research costs **160 points** after Exotic Ammunition. Ammunition research costs **80 points** after Exotic Ammunition and Automatic Ammunition, independently of receiver research, so it can supply a salvaged L6.

The receiver exceeds a basic protolathe's local storage, so upgrade its matter bins or supply it through a material silo. Fully upgraded lathes reduce printed material costs to 40%; the assembly's plasteel requirement stays at 20 sheets.

Firing pins cost 250 credits at Quartermain Depot. Fit one to a crafted or salvaged gun that has no pin. You cannot reuse a pin from another gun: prying one out destroys it.

Six schematics exist:

| Schematic | Tier | Sold at |
|---|---|---|
| C-20r SMG | Yellow | Quartermain Depot, 3 vouchers |
| WT-550 autorifle | Yellow | Quartermain Depot, 3 vouchers |
| Laser carbine | Yellow | Quartermain Depot, 2 vouchers + 3000 cr |
| L6 SAW | Red | Undertow Exchange, 5 vouchers |
| Anti-materiel sniper rifle | Red | Undertow Exchange, 5 vouchers |
| Bulldog shotgun | Red | Undertow Exchange, 5 vouchers |

All six also turn up as ruin loot, so a schematic you can't afford this round may still be sitting in a derelict.

The **neural schematic imprinter** is a machine at a trader outpost that converts a schematic into knowledge. Slot the scroll into the open cradle, climb in, seal yourself shut, and pay the fee. The posted rates are 750 credits at green tier, 1500 at yellow and 3000 at red, so a gun schematic costs you either 1500 or 3000. The fee comes out of cash you loaded into the cradle first, then your ID's account for the remainder.

What you get is the recipe bound to you for the rest of the round: theft-proof, and nothing to carry. What you lose is the paper. A physical schematic is shareable, resellable and stealable; an imprint is none of those things. The imprinter refuses if you already know a recipe, so no scroll gets wasted twice on the same gun.

## Job packs

**Starter packs** contain department circuit boards and hand equipment. You still need frames, stock parts, power, and working supplies to build and use the machines.

| Pack | Sold by | Price |
|---|---|---|
| Botany starter pack | Fern, The Potting Shed (Waystation Halcyon) | 1000 cr |
| Robotics starter pack | Boffin, The Skunkworks (Quartermain Depot) | 1200 cr |
| Xenobiology starter pack | Boffin, The Skunkworks (Quartermain Depot) | 1800 cr |
| Genetics starter pack | Sawbones, the Patch-Up Clinic (the Undertow) | 2400 cr |

The xenobiology pack includes a grey slime extract, liquid plasma, and monkey cubes. Build a secure pen in view of a ship camera before injecting at least 1 unit of plasma into the extract to hatch a slime. Add water to monkey cubes for food. Use a screwdriver on the processor board to select slime mode before building it.

To print more boards yourself, build a circuit imprinter from the autolathe's **Research & Development Kit** and research the designs you need. See [Research](research.md).
