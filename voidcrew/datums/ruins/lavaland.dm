// Voidcrew lavaland ruin templates.
//
// COPY + REDIRECT SCHEME (2026-07-18): every upstream /tg/ lavaland ruin
// (_maps/RandomRuins/LavaRuins/) was copied to
// _maps/voidcrew/RandomRuins/LavaRuins/ under the same filename, and each
// copy was edited to add voidcrew's zone-aware loot caches
// (/obj/structure/closet/crate/zone_loot) and zone-scaled mob spawners
// (/obj/effect/zone_mobs). The prefix override below re-points the upstream
// /datum/map_template/ruin/lavaland datums (code/datums/ruins/lavaland.dm) at
// those copies, mappath is prefix + suffix, and voidcrew compiles after
// code/, so no upstream file needs editing. Upstream originals remain as
// merge reference only.
//
// When upstream adds a new lavaland ruin: copy its .dmm into
// _maps/voidcrew/RandomRuins/LavaRuins/, add a themed zone_loot cache in its
// most secure room and zone_mobs markers at its chokepoints.
/datum/map_template/ruin/lavaland
	default_area = /area/overmap_encounter/planet_ruin
	prefix = "_maps/voidcrew/RandomRuins/LavaRuins/"

// These two upstream datums override prefix to AnywhereRuins, so they need
// their own redirect to the copied files.
/datum/map_template/ruin/lavaland/free_golem
	prefix = "_maps/voidcrew/RandomRuins/AnywhereRuins/"

/datum/map_template/ruin/lavaland/fountain
	prefix = "_maps/voidcrew/RandomRuins/AnywhereRuins/"

// ---- Voidcrew micro-POIs ----
// Tiny (5x5) scattered setpieces that soak up leftover ruin budget: cost 1-2,
// duplicates allowed, low weight so they season the pool rather than dominate.
// These are voidcrew-native (not upstream copies) and inherit the redirected
// prefix above.

/datum/map_template/ruin/lavaland/micro_camp
	name = "Lava-Micro Claim-Jumped Prospector Camp"
	id = "micro-lava-camp"
	description = "A one-man mining claim on the basalt flats. The bedroll is still occupied, technically."
	suffix = "lavaland_micro_camp.dmm"
	cost = 2
	allow_duplicates = TRUE
	placement_weight = 0.5

/datum/map_template/ruin/lavaland/micro_meteor
	name = "Lava-Micro Meteor Impact Scar"
	id = "micro-lava-meteor"
	description = "Something hit hard enough to glass the basalt and shove fresh ore up through the crust."
	suffix = "lavaland_micro_meteor.dmm"
	cost = 1
	allow_duplicates = TRUE
	placement_weight = 0.5
