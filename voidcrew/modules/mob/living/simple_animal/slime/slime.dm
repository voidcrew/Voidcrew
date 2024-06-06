/mob/living/basic/slime/pet/beach
	faction = list("neutral", "beach")

/mob/living/basic/slime/random/beach
	faction = list(FACTION_BEACH)
	powerlevel = SLIME_MAX_POWER
	amount_grown = 9

/mob/living/basic/slime/random/beach/Initialize(mapload, new_colour, new_life_stage)
	. = ..()
	ai_controller?.set_blackboard_key(BB_SLIME_RABID, TRUE)
