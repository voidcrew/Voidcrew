/datum/lazy_template/virtual_domain/wendigo
	name = "Glacial Devourer"
	cost = BITRUNNER_COST_APEX_BOSS
	desc = "Legends speak of the ravenous Wendigo hidden deep within the caves of Icemoon."
	difficulty = BITRUNNER_DIFFICULTY_HIGH
	forced_outfit = /datum/outfit/job/miner
	help_text = "The wendigo has the cache. Kill it, take the cache, and bring it back to the \
		safehouse goal tile. It slams the ground to throw you across the arena and fires shockwaves \
		in spirals and expanding walls, so distance on its own will not keep you safe. Below half \
		health it teleports back to where the fight started and opens up with heavier shockwave \
		patterns. The bodies out there are the last crew that tried this."
	key = "wendigo"
	map_name = "wendigo"
	reward_points = BITRUNNER_REWARD_HIGH

/obj/effect/mob_spawn/corpse/human/bitrunner/special(mob/living/spawned_mob)
	. = ..()
	spawned_mob.apply_status_effect(/datum/status_effect/gutted)

/obj/effect/mob_spawn/corpse/human/cyber_police/special(mob/living/spawned_mob)
	. = ..()
	spawned_mob.apply_status_effect(/datum/status_effect/gutted)
