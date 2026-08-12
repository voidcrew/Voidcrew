// Voidcrew icemoon ruin templates.
//
// COPY + REDIRECT SCHEME (2026-07-18): every upstream /tg/ icemoon ruin
// (_maps/RandomRuins/IceRuins/) was copied to
// _maps/voidcrew/RandomRuins/IceRuins/ under the same filename, and each copy
// was edited to add voidcrew's zone-aware loot caches
// (/obj/structure/closet/crate/zone_loot) and zone-scaled mob spawners
// (/obj/effect/zone_mobs). The prefix override below re-points the upstream
// /datum/map_template/ruin/icemoon datums (code/datums/ruins/icemoon.dm) at
// those copies, mappath is prefix + suffix, and voidcrew compiles after
// code/, so no upstream file needs editing. The underground subtypes inherit
// this prefix. Upstream originals remain as merge reference only.
//
// When upstream adds a new icemoon ruin: copy its .dmm into
// _maps/voidcrew/RandomRuins/IceRuins/, add a themed zone_loot cache in its
// most secure room and zone_mobs markers at its chokepoints.
/datum/map_template/ruin/icemoon
	prefix = "_maps/voidcrew/RandomRuins/IceRuins/"

// These two upstream datums override prefix to AnywhereRuins, so they need
// their own redirect to the copied files.
/datum/map_template/ruin/icemoon/fountain
	prefix = "_maps/voidcrew/RandomRuins/AnywhereRuins/"

/datum/map_template/ruin/icemoon/underground/free_golem
	prefix = "_maps/voidcrew/RandomRuins/AnywhereRuins/"

// ---- Voidcrew micro-POIs ----
// Tiny (4x4 to 7x5) scattered setpieces that soak up leftover ruin budget:
// cost 1-2, duplicates allowed, low weight so they season the pool rather
// than dominate. Voidcrew-native (not upstream copies); they inherit the
// redirected prefix above. Base icemoon defaults are cost = 5 and
// allow_duplicates = FALSE, so both must be overridden here.

/datum/map_template/ruin/icemoon/micro_pod
	name = "Ice-Micro Crashed Escape Pod"
	id = "micro-ice-pod"
	description = "An escape pod that made it down in one piece. The crew froze waiting. The cold kept them fresh."
	suffix = "icemoon_micro_pod.dmm"
	cost = 2
	allow_duplicates = TRUE
	placement_weight = 0.5

/datum/map_template/ruin/icemoon/micro_cairn
	name = "Ice-Micro Frozen Cairn"
	id = "micro-ice-cairn"
	description = "Somebody buried a friend out on the white and stacked what stones the ice would give up."
	suffix = "icemoon_micro_cairn.dmm"
	cost = 1
	allow_duplicates = TRUE
	placement_weight = 0.5
