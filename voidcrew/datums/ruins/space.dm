// Voidcrew space ruin templates.
//
// COPY + REDIRECT SCHEME (2026-07-18): every upstream /tg/ space ruin
// (_maps/RandomRuins/SpaceRuins/) was copied to
// _maps/voidcrew/RandomRuins/SpaceRuins/ under the same filename, and each
// copy was edited to add voidcrew's zone-aware loot caches
// (/obj/structure/closet/crate/zone_loot) and zone-scaled mob spawners
// (/obj/effect/zone_mobs). The prefix override below re-points the upstream
// /datum/map_template/ruin/space datums (code/datums/ruins/space.dm) at those
// copies — mappath is computed as prefix + suffix in
// /datum/map_template/ruin/New(), and voidcrew files compile after code/, so
// this single declaration redirects all of them without touching upstream
// files. The upstream originals remain as merge reference only.
//
// The voidcrew-owned space ruin subtypes (/rare in rare_space.dm, /vestige in
// antag_space.dm) set their own prefix to the same folder and are unaffected.
//
// When upstream adds a new space ruin: copy its .dmm into
// _maps/voidcrew/RandomRuins/SpaceRuins/, add a themed zone_loot cache in its
// most secure room and zone_mobs markers at its chokepoints, and it will load
// from the copy automatically. Never add templates whose maps only exist in
// the upstream folder — dead entries poison the space-ruin picker.
/datum/map_template/ruin/space
	prefix = "_maps/voidcrew/RandomRuins/SpaceRuins/"
