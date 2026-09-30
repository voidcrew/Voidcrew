/datum/lazy_template/virtual_domain/ash_drake
	name = "Ashen Inferno"
	cost = BITRUNNER_COST_BOSS // VOIDCREW EDIT: research prices virtual boss domains and supplies their domain briefing.
	desc = "Home of the ash drake, a powerful dragon that scours the surface of Lavaland."
	difficulty = BITRUNNER_DIFFICULTY_MEDIUM
	forced_outfit = /datum/outfit/job/miner
	// VOIDCREW EDIT START: research prices virtual boss domains and supplies their domain briefing.
	help_text = "There is no crate waiting for you out there. The drake is carrying it. \
		Kill it, take the cache off the body, and haul it back to the safehouse goal tile. \
		It breathes fire in a cone, calls down meteors, throws out rings of fireballs, and swoops \
		into the air to land somewhere else. Below half health it walls the fight into a ring of \
		lava, and leaving that ring only makes it angrier. Take the armoury with you."
	// VOIDCREW EDIT END
	key = "ash_drake"
	map_name = "ash_drake"
	reward_points = BITRUNNER_REWARD_MEDIUM
