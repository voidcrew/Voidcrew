/mob/living/basic/mining/ice_demon/random/Initialize()
	. = ..()
	if(prob(15))
		new /mob/living/basic/mining/ice_demon(loc)
		return INITIALIZE_HINT_QDEL
