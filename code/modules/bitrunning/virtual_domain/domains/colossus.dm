/datum/lazy_template/virtual_domain/colossus
	name = "Celestial Trial"
	cost = BITRUNNER_COST_APEX_BOSS // VOIDCREW EDIT: research prices virtual boss domains and supplies their domain briefing.
	desc = "A massive, ancient beast named the Colossus. Judgment comes."
	difficulty = BITRUNNER_DIFFICULTY_HIGH
	forced_outfit = /datum/outfit/job/miner
	// VOIDCREW EDIT START: research prices virtual boss domains and supplies their domain briefing.
	help_text = "The Colossus is holding the cache. Kill it, take the cache, and carry it back to \
		the safehouse goal tile. It barely moves. Everything it does is projectiles, and every \
		pattern has a gap in it, so the fight is about reading the spread and standing in the gap. \
		It gets faster as its health drops. Take the whole armoury with you."
	// VOIDCREW EDIT END
	key = "colossus"
	map_name = "colossus"
	reward_points = BITRUNNER_REWARD_HIGH
