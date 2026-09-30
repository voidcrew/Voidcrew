/datum/lazy_template/virtual_domain/blood_drunk_miner
	name = "Sanguine Excavation"
	cost = BITRUNNER_COST_BOSS // VOIDCREW EDIT: research prices virtual boss domains and supplies their domain briefing.
	desc = "Few escape the surface of Lavaland without a few scars. Some remain, maddened by the hunt."
	difficulty = BITRUNNER_DIFFICULTY_MEDIUM
	forced_outfit = /datum/outfit/job/miner
	// VOIDCREW EDIT START: research prices virtual boss domains and supplies their domain briefing.
	help_text = "The miner is carrying the cache. Kill it, pick the cache up off the body, and \
		bring it back to the safehouse goal tile. It dashes to close distance and hits hard with \
		its saw, so it will not let you kite it for long. It also eats the dead to heal, which \
		means a downed teammate left on the floor hands it most of its health back. \
		Everything in the safehouse armoury is yours."
	// VOIDCREW EDIT END
	key = "blood_drunk_miner"
	map_name = "blood_drunk_miner"
	reward_points = BITRUNNER_REWARD_MEDIUM
