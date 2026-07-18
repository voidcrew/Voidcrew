// Voidcrew icemoon ruin templates.
//
// COPY + REDIRECT SCHEME (2026-07-18): every upstream /tg/ icemoon ruin
// (_maps/RandomRuins/IceRuins/) was copied to
// _maps/voidcrew/RandomRuins/IceRuins/ under the same filename, and each copy
// was edited to add voidcrew's zone-aware loot caches
// (/obj/structure/closet/crate/zone_loot) and zone-scaled mob spawners
// (/obj/effect/zone_mobs). The prefix override below re-points the upstream
// /datum/map_template/ruin/icemoon datums (code/datums/ruins/icemoon.dm) at
// those copies — mappath is prefix + suffix, and voidcrew compiles after
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
