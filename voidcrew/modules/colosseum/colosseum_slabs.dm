/**
 * # Colosseum stone slabs
 *
 * Arena floor decor recolored from the necropolis boss-floor slabs
 * ('voidcrew/icons/turf/floors/colosseum.dmi', same icon_state layout as
 * 'icons/turf/boss_floors.dmi'). Unlike the necropolis originals, these keep
 * the exact sprite the mapper placed instead of randomizing in Initialize().
 */

/obj/structure/stone_tile/slab/colosseum
	icon = 'voidcrew/icons/turf/floors/colosseum.dmi'
	icon_state = "pristine_slab1"
	desc = "A slab of pale arena stone, worn smooth by generations of footwork."

/obj/structure/stone_tile/slab/colosseum/Initialize(mapload)
	. = ..()
	icon_state = initial(icon_state) // keep the mapped-in sprite; stone_tile randomizes by default

/obj/structure/stone_tile/slab/colosseum/two
	icon_state = "pristine_slab2"

/obj/structure/stone_tile/slab/colosseum/three
	icon_state = "pristine_slab3"

/obj/structure/stone_tile/slab/colosseum/cracked
	name = "cracked stone slab"
	desc = "A slab of pale arena stone, split by one bout too many."
	icon_state = "cracked_slab1"
