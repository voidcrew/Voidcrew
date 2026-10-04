/**
 * Outpost residents: every creature that exists when a trader outpost's map loads (mapped
 * mobs, and anything a mapped object spawns during the load, such as an apiary's bees).
 * Outpost turrets never treat them as wild hostiles, so mappers can place any creature
 * without checking its AI against the turret rules. Creatures that arrive later are judged normally.
 */

/mob/living/Initialize(mapload)
	. = ..()
	if(SSatoms.initialized != INITIALIZATION_INNEW_MAPLOAD)
		return
	if(istype(get_area(src), /area/voidcrew/trader_outpost))
		ADD_TRAIT(src, TRAIT_OUTPOST_RESIDENT, INNATE_TRAIT)
