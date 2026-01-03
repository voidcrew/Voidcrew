/**
 * Ship Parts Spawners - Class-Based System
 *
 * Context-based spawners for ship parts.
 * Place appropriate spawners in relevant locations:
 * - Combat: wrecks, combat zones, military installations
 * - Science: labs, research sites, anomalies
 * - Trade: stations, trade posts, cargo areas
 * - Misc: general loot areas, derelicts
 */

/// Random ship part spawner - equal chance for any class
/obj/effect/spawner/random/ship_parts
	name = "ship part spawner"
	loot = list(
		/obj/item/ship_parts/combat = 25,
		/obj/item/ship_parts/science = 25,
		/obj/item/ship_parts/trade = 25,
		/obj/item/ship_parts/misc = 25,
	)

/// Combat part spawner - for wrecks, combat zones, military areas
/obj/effect/spawner/random/ship_parts/combat
	name = "combat ship part spawner"
	loot = list(
		/obj/item/ship_parts/combat = 1,
	)

/// Science part spawner - for labs, research sites, anomalies
/obj/effect/spawner/random/ship_parts/science
	name = "science ship part spawner"
	loot = list(
		/obj/item/ship_parts/science = 1,
	)

/// Trade part spawner - for stations, trade posts, cargo areas
/obj/effect/spawner/random/ship_parts/trade
	name = "trade ship part spawner"
	loot = list(
		/obj/item/ship_parts/trade = 1,
	)

/// Misc part spawner - for general loot areas, derelicts
/obj/effect/spawner/random/ship_parts/misc
	name = "misc ship part spawner"
	loot = list(
		/obj/item/ship_parts/misc = 1,
	)

/// Combat-biased spawner - mostly combat with some misc
/obj/effect/spawner/random/ship_parts/combat_zone
	name = "combat zone ship part spawner"
	loot = list(
		/obj/item/ship_parts/combat = 70,
		/obj/item/ship_parts/misc = 30,
	)

/// Science-biased spawner - mostly science with some misc
/obj/effect/spawner/random/ship_parts/research_site
	name = "research site ship part spawner"
	loot = list(
		/obj/item/ship_parts/science = 70,
		/obj/item/ship_parts/misc = 30,
	)

/// Trade-biased spawner - mostly trade with some misc
/obj/effect/spawner/random/ship_parts/trade_post
	name = "trade post ship part spawner"
	loot = list(
		/obj/item/ship_parts/trade = 70,
		/obj/item/ship_parts/misc = 30,
	)

/// Wreck spawner - combat and misc parts common in ship wrecks
/obj/effect/spawner/random/ship_parts/wreck
	name = "wreck ship part spawner"
	loot = list(
		/obj/item/ship_parts/combat = 50,
		/obj/item/ship_parts/misc = 35,
		/obj/item/ship_parts/trade = 15,
	)

/// Station spawner - trade-focused with variety
/obj/effect/spawner/random/ship_parts/station
	name = "station ship part spawner"
	loot = list(
		/obj/item/ship_parts/trade = 40,
		/obj/item/ship_parts/misc = 30,
		/obj/item/ship_parts/science = 20,
		/obj/item/ship_parts/combat = 10,
	)
