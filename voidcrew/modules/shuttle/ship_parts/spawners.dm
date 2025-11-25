/**
 * Ship Parts Spawners - Rarity-Based System
 *
 * Random spawners for ship parts with appropriate rarity weighting.
 */

/// Standard ship part spawner - weighted by rarity
/obj/effect/spawner/random/ship_parts
	name = "ship part spawner"
	loot = list(
		/obj/item/ship_parts/common = 50,
		/obj/item/ship_parts/uncommon = 30,
		/obj/item/ship_parts/rare = 15,
		/obj/item/ship_parts/epic = 4,
		/obj/item/ship_parts/legendary = 1,
	)

/// Guaranteed common part spawner
/obj/effect/spawner/random/ship_parts/common
	name = "common ship part spawner"
	loot = list(
		/obj/item/ship_parts/common = 1,
	)

/// Guaranteed uncommon part spawner
/obj/effect/spawner/random/ship_parts/uncommon
	name = "uncommon ship part spawner"
	loot = list(
		/obj/item/ship_parts/uncommon = 1,
	)

/// Guaranteed rare part spawner
/obj/effect/spawner/random/ship_parts/rare
	name = "rare ship part spawner"
	loot = list(
		/obj/item/ship_parts/rare = 1,
	)

/// Guaranteed epic part spawner
/obj/effect/spawner/random/ship_parts/epic
	name = "epic ship part spawner"
	loot = list(
		/obj/item/ship_parts/epic = 1,
	)

/// Guaranteed legendary part spawner
/obj/effect/spawner/random/ship_parts/legendary
	name = "legendary ship part spawner"
	loot = list(
		/obj/item/ship_parts/legendary = 1,
	)

/// High-value spawner - biased towards better rarities
/obj/effect/spawner/random/ship_parts/high_value
	name = "valuable ship part spawner"
	loot = list(
		/obj/item/ship_parts/rare = 50,
		/obj/item/ship_parts/epic = 35,
		/obj/item/ship_parts/legendary = 15,
	)
