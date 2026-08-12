// Voidcrew space ruin templates.
//
// COPY + REDIRECT SCHEME (2026-07-18): every upstream /tg/ space ruin
// (_maps/RandomRuins/SpaceRuins/) was copied to
// _maps/voidcrew/RandomRuins/SpaceRuins/ under the same filename, and each
// copy was edited to add voidcrew's zone-aware loot caches
// (/obj/structure/closet/crate/zone_loot) and zone-scaled mob spawners
// (/obj/effect/zone_mobs). The prefix override below re-points the upstream
// /datum/map_template/ruin/space datums (code/datums/ruins/space.dm) at those
// copies, mappath is computed as prefix + suffix in
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
// the upstream folder, dead entries poison the space-ruin picker.
/datum/map_template/ruin/space
	prefix = "_maps/voidcrew/RandomRuins/SpaceRuins/"

// Charlie Station is 112x64. load_level() reserves the ruin plus a maximum-size
// docking berth on two opposite sides (112 + 56*2 + 3*2 = 230 wide) but the
// largest block any reservation z-level can hand out is 222x222 (the band inset
// by SHUTTLE_TRANSIT_BORDER, less the cordon ring). So it can never be boarded:
// it surfaced as a normal signal that answered every dock attempt with "Failed to
// load the location.", leaking a fresh 255x255 reservation z-level per attempt.
//
// Keep it out of the pickers until the map is trimmed under 104 wide (or the dock
// berths are laid out along its short axis, which would fit at 198x182 but changes
// docking rotation, see the dock rotation invariant before trying that).
/datum/map_template/ruin/space/oldstation
	unpickable = TRUE
