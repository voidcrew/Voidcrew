// Constructed stand-ins for natural terrain on ship hulls.
//
// A ship's tiles only travel with it (and can be saved in an outpost checkpoint) when they are
// real floors, walls or space. Loose dirt, mineral rock and bare space inside a hull are either
// left behind when the ship moves or refused by the checkpoint snapshot. These keep the same
// look while being ordinary constructed turfs.

/// Looks like open space, but is a deck: rigging and engines on it move with the ship.
/// Airless, and its wiring stays in reach the way it is on a catwalk over real space.
/turf/open/floor/fakespace/airless
	initial_gas_mix = AIRLESS_ATMOS
	temperature = TCMB
	underfloor_accessibility = UNDERFLOOR_INTERACTABLE

/// Packed dirt laid over the deck plating. Looks like /turf/open/misc/dirt/station.
/turf/open/floor/fakedirt
	gender = PLURAL
	name = "dirt flooring"
	desc = "Packed dirt spread over the deck plating."
	icon = 'icons/turf/floors.dmi'
	icon_state = "dirt"
	base_icon_state = "dirt"
	flags_1 = NONE
	bullet_bounce_sound = null
	footstep = FOOTSTEP_SAND
	barefootstep = FOOTSTEP_SAND
	clawfootstep = FOOTSTEP_SAND
	heavyfootstep = FOOTSTEP_GENERIC_HEAVY
	tiled_dirt = FALSE
	rust_resistance = RUST_RESISTANCE_ORGANIC

/// Reinforced rock that looks and smooths like plain asteroid rock. Welding the struts away
/// leaves ordinary mineable rock, as with any reinforced rock.
/turf/closed/wall/rock/hull
	name = "rock"
	icon = MAP_SWITCH('icons/turf/smoothrocks.dmi', 'icons/turf/mining.dmi')
	icon_state = "rock"
	base_icon_state = "smoothrocks"
	smoothing_flags = SMOOTH_BITMASK | SMOOTH_BORDER
	smoothing_groups = SMOOTH_GROUP_CLOSED_TURFS + SMOOTH_GROUP_MINERAL_WALLS
	canSmoothWith = SMOOTH_GROUP_MINERAL_WALLS
	pixel_x = MAP_SWITCH(-4, 0)
	pixel_y = MAP_SWITCH(-4, 0)
