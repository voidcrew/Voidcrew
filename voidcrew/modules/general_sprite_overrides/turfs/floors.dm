/turf/open/floor/iron/freezer/edge
	icon = 'voidcrew/icons/turf/floors/floors.dmi'
	icon_state = "freezer_edge"
	base_icon_state = "freezer_edge"
	floor_tile = /obj/item/stack/tile/iron/freezer/edge

/turf/open/floor/iron/freezer/half
	icon = 'voidcrew/icons/turf/floors/floors.dmi'
	icon_state = "freezer_half"
	base_icon_state = "freezer_half"
	floor_tile = /obj/item/stack/tile/iron/freezer/half

/turf/open/floor/iron/freezer/corner
	icon = 'voidcrew/icons/turf/floors/floors.dmi'
	icon_state = "freezer_corner"
	base_icon_state = "freezer_corner"
	floor_tile = /obj/item/stack/tile/iron/freezer/corner

/turf/open/floor/iron/freezer/large
	icon = 'voidcrew/icons/turf/floors/floors.dmi'
	icon_state = "freezer_large"
	base_icon_state = "freezer_large"
	floor_tile = /obj/item/stack/tile/iron/freezer/large

/turf/open/floor/iron/showroomfloor
	icon_state = "showroomfloor"
	base_icon_state = "showroomfloor"
	floor_tile = /obj/item/stack/tile/iron/showroomfloor

/turf/open/floor/iron/solarpanel
	icon = 'voidcrew/icons/turf/floors/floors.dmi'

/turf/open/floor/catwalk_floor
	icon = 'voidcrew/icons/turf/floors/catwalk_plating.dmi'

/turf/open/indestructible
	icon = 'voidcrew/icons/turf/floors/floors.dmi'

/turf/open/indestructible/cobble
	name = "cobblestone path"
	desc = "A simple but beautiful path made of various sized stones."
	icon = 'voidcrew/icons/turf/floors/floors.dmi'
	icon_state = "cobble"
	baseturfs = /turf/open/indestructible/cobble
	footstep = FOOTSTEP_FLOOR
	barefootstep = FOOTSTEP_HARD_BAREFOOT
	clawfootstep = FOOTSTEP_HARD_CLAW
	heavyfootstep = FOOTSTEP_GENERIC_HEAVY

/turf/open/indestructible/cobble/side
	icon_state = "cobble_side"

/turf/open/indestructible/cobble/corner
	icon_state = "cobble_corner"

/turf/open/floor/plating/reinforced
	icon = 'icons/turf/floors.dmi'

/turf/open/floor/iron/white/textured_large/airless
	initial_gas_mix = AIRLESS_ATMOS

/turf/open/floor/circuit
	icon = 'voidcrew/icons/turf/floors/floors.dmi'

/turf/open/floor/light/broken_states()
	return list("damaged1", "damaged2", "damaged3", "damaged4", "damaged5")

/turf/open/floor/engine/cult
	icon = 'voidcrew/icons/turf/floors/floors.dmi'

/obj/effect/cult_turf
	icon = 'voidcrew/icons/turf/floors/floors.dmi'

/turf/open/floor/cult/broken_states()
	return list("damaged1", "damaged2", "damaged3", "damaged4", "damaged5")

/turf/open/floor/bamboo
	icon = 'voidcrew/icons/turf/floors/bamboo_mat.dmi'

/turf/open/floor/bamboo/tatami
	icon = 'voidcrew/icons/turf/floors/floor_variations.dmi'

/turf/open/floor/bamboo/tatami/purple
	icon = 'voidcrew/icons/turf/floors/floor_variations.dmi'

/turf/open/floor/bamboo/tatami/black
	icon = 'voidcrew/icons/turf/floors/floor_variations.dmi'

// TRAM FLOORS

/turf/open/floor/noslip/tram
	icon = 'voidcrew/icons/turf/floors/tram.dmi'

/turf/open/floor/tram
	icon = 'voidcrew/icons/turf/floors/tram.dmi'

/turf/open/floor/tram/plate
	icon = 'voidcrew/icons/turf/floors/tram.dmi'

/turf/open/indestructible/tram
	icon = 'voidcrew/icons/turf/floors/tram.dmi'

/turf/open/floor/tram/broken_states()
	return list("damaged1", "damaged2", "damaged3", "damaged4", "damaged5")

/turf/open/floor/tram/tram_platform/burnt_states()
	return list("damaged1", "damaged2", "damaged3", "damaged4", "damaged5")

/turf/open/floor/tram/plate/broken_states()
	return list("damaged1", "damaged2", "damaged3", "damaged4", "damaged5")

/turf/open/floor/tram/plate/burnt_states()
	return list("damaged1", "damaged2", "damaged3", "damaged4", "damaged5")

/turf/open/floor/tram/plate/energized/broken_states()
	return list("damaged1", "damaged2", "damaged3", "damaged4", "damaged5")

/turf/open/floor/tram/plate/energized/burnt_states()
	return list("damaged1", "damaged2", "damaged3", "damaged4", "damaged5")

// LIVING FLOORS

/mob/living/basic/living_floor
	icon = 'voidcrew/icons/turf/floors/floors.dmi'

// OBJECT BASED
// I know these are objects but it's more organized if we keep specific ones here.

/obj/item/stack/tile
	icon = 'voidcrew/icons/obj/tiles.dmi'

/obj/item/stack/light_w
	icon = 'voidcrew/icons/obj/tiles.dmi'

/obj/item/stack/tile/mineral/bananium
	tile_rotate_dirs = list(SOUTH, NORTH, EAST, WEST, SOUTHEAST, SOUTHWEST, NORTHEAST, NORTHWEST)

/obj/structure/broken_flooring
	icon = 'voidcrew/icons/obj/fluff/brokentiling.dmi'

/obj/structure/transport/linear/public
	icon = 'voidcrew/icons/turf/floors/floors.dmi'

/obj/structure/thermoplastic
	icon = 'voidcrew/icons/turf/floors/tram.dmi'
