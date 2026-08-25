---
title: Fuel & Gas
category: Economy
order: 4
blurb: Where thruster fuel comes from, nebula scooping, plasma sublimation, and selling exotic gas to traders.
---

Most ships fly on burnt gas, and gas costs money. A crew that buys every canister off a trader will spend a large fraction of its income on getting anywhere. There are two ways to stop doing that: scoop your fuel out of a nebula, or bake it out of plasma you mined. Both are machines you build once and run forever, and the second-order effect is that the rarer gases become something you *sell* rather than burn.

## How ships burn fuel

Fuelled thrusters do not hold their own fuel. Each one draws from an **engine heater** parked directly behind it and facing the same way. The heater is the tank; the thruster is the nozzle. For how these fit into the rest of the hull. See [Ship Systems](ship-systems.md).

A heater feeds from one of two sources, toggled by alt-clicking it:

- **Tank mode**, where it drinks from a gas tank you slotted into it. Simple, portable, and small.
- **Pipe mode**, where it drinks from whatever pipe network it is wrenched onto. This is the mode that matters, because it is what lets a fuel machine somewhere else on the ship keep the engines topped up automatically.

The two common fuelled thrusters differ a lot in appetite. A **plasma thruster** burns plasma specifically, and is the efficient one. An **expulsion thruster** burns literally any gas and is far less efficient per mole. It is what you install when you have more gas than sense, or when the only thing you can scoop is nitrogen.

Heavier ships burn proportionally more per burn, so a big hull with a small fuel supply is a bad combination. See [Piloting](piloting.md) for how burns work at the helm.

## Nebulas

Nebulas are common features on the [overmap](overmap.md), and in Voidcrew every one of them **carries a specific gas**. Which gas depends on how deep the nebula is: the safe outer ring holds plasma, nitrogen and water vapour; the contested band adds tritium and miasma; and the lawless deep is where hypernoblium, pluoxium and nitrium pool.

Your helm names each nebula after its gas and tints it on the chart, so you can pick a tritium cloud out of a bank of them without flying into each one.

Nebulas also **block sensors**. Sitting inside one lets you engage nebula concealment and disappear off other crews' contact lists, which makes them the standard place to hide from a ship that is hunting you.

## The ram scoop

A **nebula ram scoop** is an external intake you build on your hull and wrench onto a pipe network. It harvests only when three things are true at once: the intake is open, your ship is **inside a nebula**, and your ship is **holding still**. Click it to open or close the intake.

Harvested gas feeds straight into the connected pipes. Run those pipes to an engine heater in pipe mode and your engines refuel themselves; run them to a connector port instead and you can fill canisters and tanks to sell or carry.

Scoop rate depends on the gas. The common fuels come in fast; the valuable ones come in slowly on top of only existing in dangerous space. Better micro-lasers in the scoop multiply the rate, a full set of top-tier lasers roughly quadruples it.

!!! danger "Scooping is loud"
    Running the scoop **cancels nebula concealment and rips away any concealment you already had**, and keeps you visible for ten seconds after the last harvest tick. You cannot refuel and hide at the same time. Every crew in the galaxy knows the fuel stop is also the ambush spot.

Close the intake before you try to hide.

## The sublimation chamber

The **plasma sublimation chamber** is the other half of the loop, for crews who mine rather than fly around looking for clouds. Feed it raw **plasma sheets** by hand (the hopper holds fifty) and it bakes each sheet down into 30 moles of clean plasma gas, trickled into whatever pipe network it is wrenched onto. Alt-click empties the hopper back into sheets if you change your mind.

Micro-lasers set the output rate here too. Since planets and asteroids hand out plasma ore fairly freely, a mining crew with a sublimator effectively never buys fuel again.

Both machines are unlocked by the same early research node as the engine heater, so any ship that can research at all can print both boards. Waystation Halcyon also sells the **ram scoop board** over the counter for 600 credits, which is the route for crews with no research bay.

## Buying fuel

If you would rather just buy it, both the general waystation and the outfitter depot keep fuel and breathing gas on the shelf:

| Item | Waystation Halcyon | Quartermain Depot |
|---|---|---|
| Full plasma canister | 1800 cr | 1100 cr |
| Welding fuel tank | 400 cr | 400 cr |
| Full oxygen tank | 150 cr | 120 cr |
| Nebula ram scoop board | 600 cr | - |

Quartermain is cheaper on plasma because it sits further out; Halcyon's markup is the haul to the safe ring.

## Selling gas

Exotic gas is worth real money, and there is exactly one buyer: **Vex at the Undertow Exchange**, in the lawless deep. Vex buys gas by the **tank**. Fill a tank off your scooped pipe network at a connector port, carry it to the counter, and the tank goes with the sale.

| Gas | Pays | Minimum in one tank |
|---|---|---|
| Hypernoblium | 1200 cr | 200 mol |
| Pluoxium | 300 cr | 200 mol |
| Nitrium | 300 cr | 200 mol |

All three only pool in deep-band nebulas, and all three scoop slowly, so the payout is gated by how long you are willing to sit still in the most dangerous space in the galaxy with your position broadcast. See [Trader Outposts](trader-outposts.md) for getting to Vex.

**Gas Harvest contracts** on your ship's mission board are the other sink. Each asks for a tank holding a required quantity of one specific gas, and the board only ever asks for a gas that a nebula somewhere in this round's galaxy actually carries. The common gases pay 700–1200 credits for 600–900 moles; tritium pays 1500–2200 and a voucher; the deep-band exotics pay 2000–3200 and a voucher for as little as 150 moles. Any tank works, and the contract keeps the tank. See [Missions](missions.md).

## Practical advice for a new crew

- **Build the scoop early.** It is one board, it costs less than three canisters, and it removes your largest recurring expense.
- **Put the heater in pipe mode.** A heater on a tank has to be hand-fed. A heater on the pipe network refuels itself off the scoop or sublimator while you do something else.
- **Scoop plasma in green space first.** The outer ring is thick with plasma nebulas, they scoop fast, and nobody is going to jump you there.
- **Don't scoop while running.** If you are being hunted, close the intake and hide. Fuel is replaceable; the ship is not.
- **Overfill before a deep run.** Filling spare canisters while parked in a safe nebula is far better than discovering you are dry in the lawless deep.
- **Sell the exotics, burn the common stuff.** Hypernoblium is worth 1200 credits a tank at Vex's counter and does nothing useful in a thruster. Plasma gets you home.
