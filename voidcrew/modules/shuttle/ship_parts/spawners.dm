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

// ========== COMPETITIVE-EVENT PRIZE ==========

/**
 * Prize crate for competitive events (contested cache, etc).
 * The parts themselves are rolled by spawn_ship_part_prize() below; the crate
 * only guarantees an extraction case so a caseless crew isn't stuck banking
 * their winnings. Unlocked: the event gating the prize is the lock.
 */
/obj/structure/closet/crate/secure/ship_part_prize
	name = "bonded prize crate"
	desc = "A heavy-duty bonded courier crate. Somebody has already dealt with the lock, so it opens right up."
	icon_state = "secgearcrate"
	base_icon_state = "secgearcrate"
	locked = FALSE

/obj/structure/closet/crate/secure/ship_part_prize/PopulateContents()
	. = ..()
	new /obj/item/storage/briefcase/secure/extraction(src)

/**
 * Spawns the ship-part prize crate for competitive events.
 * Mirrors spawn_bounty_loot() (voidcrew/modules/npc_ships/code/bounty/bounty.dm):
 * physical, class-weighted parts the winners must case, carry home and extract -
 * never a direct database grant.
 *
 * Arguments:
 * * spawn_loc - turf to spawn the crate on
 * * count - number of parts rolled into the crate
 * * class_weights - optional pick_weight() list of /obj/item/ship_parts subtypes; defaults to combat-heavy
 * Returns the crate, or null if spawn_loc is invalid.
 */
/proc/spawn_ship_part_prize(turf/spawn_loc, count = SHIP_PART_PRIZE_COUNT, list/class_weights)
	if(!spawn_loc)
		return null
	// Winning fights unlocks fighting ships, so the pot leans combat - with a
	// splash of every other class, since this is the only guaranteed source of some.
	var/static/list/default_prize_weights = list(
		/obj/item/ship_parts/combat = 55,
		/obj/item/ship_parts/science = 15,
		/obj/item/ship_parts/trade = 15,
		/obj/item/ship_parts/misc = 15,
	)
	var/obj/structure/closet/crate/secure/ship_part_prize/crate = new(spawn_loc)
	for(var/i in 1 to count)
		var/part_type = pick_weight(class_weights || default_prize_weights)
		new part_type(crate)
	return crate
