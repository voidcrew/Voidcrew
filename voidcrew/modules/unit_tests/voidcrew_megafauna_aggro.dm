/// Aggro changes must be visible before damage, without logging every AI tick.
/datum/unit_test/voidcrew_megafauna_aggro

/datum/unit_test/voidcrew_megafauna_aggro/proc/attack_history(mob/subject)
	var/list/entries = subject.logging["[LOG_ATTACK]"]
	var/list/messages = list()
	for(var/entry in entries)
		messages += entries[entry]
	return jointext(messages, "\n")

/datum/unit_test/voidcrew_megafauna_aggro/Run()
	var/mob/living/simple_animal/hostile/megafauna/boss = allocate(/mob/living/simple_animal/hostile/megafauna, run_loc_floor_bottom_left)
	var/mob/living/basic/first = allocate(/mob/living/basic, get_step(run_loc_floor_bottom_left, EAST))
	var/mob/living/basic/second = allocate(/mob/living/basic, get_step(run_loc_floor_bottom_left, NORTH))

	boss.GiveTarget(first)
	var/history = attack_history(boss)
	TEST_ASSERT(findtext(history, "MEGAFAUNA AGGRO"), "Initial aggro was not logged")
	TEST_ASSERT(findtext(history, "acquired target"), "Initial aggro was not distinguished from a switch")
	TEST_ASSERT(findtext(history, first.tag), "Target mob identity was missing")
	TEST_ASSERT(findtext(history, loc_name(first)), "Target coordinates were missing")
	TEST_ASSERT(findtext(history, "zone="), "Target ship/zone context was missing")
	TEST_ASSERT(findtext(attack_history(first), boss.tag), "The player's individual log omitted the boss")
	var/initial_count = length(boss.logging["[LOG_ATTACK]"])
	boss.GiveTarget(first)
	TEST_ASSERT_EQUAL(length(boss.logging["[LOG_ATTACK]"]), initial_count, "An unchanged target produced duplicate aggro logs")

	boss.GiveTarget(second)
	TEST_ASSERT(findtext(attack_history(boss), "switched target"), "Switching targets was not logged")
	TEST_ASSERT(findtext(attack_history(first), "switched target"), "The former target's history omitted the switch")
	TEST_ASSERT(findtext(attack_history(second), first.tag), "The new target's history omitted the previous target")

	boss.LoseTarget()
	TEST_ASSERT(findtext(attack_history(second), "lost target"), "Losing aggro was not logged")
	var/lost_count = length(boss.logging["[LOG_ATTACK]"])
	boss.LoseTarget()
	TEST_ASSERT_EQUAL(length(boss.logging["[LOG_ATTACK]"]), lost_count, "An idle boss produced repeated lost-target logs")

	boss.GiveTarget(first)
	var/before_deletion = length(boss.logging["[LOG_ATTACK]"])
	qdel(first)
	TEST_ASSERT_NULL(boss.target, "Deleting a target did not clear it")
	TEST_ASSERT_EQUAL(length(boss.logging["[LOG_ATTACK]"]), before_deletion + 1, "Target deletion must produce exactly one lost-target event")

	var/obj/vehicle/sealed/mecha/ripley/mech = allocate(/obj/vehicle/sealed/mecha/ripley, get_step(run_loc_floor_bottom_left, EAST))
	mech.add_occupant(second, VEHICLE_CONTROL_DRIVE)
	boss.GiveTarget(mech)
	TEST_ASSERT(findtext(boss.aggro_target_description(mech), second.tag), "A mech target concealed its pilot's identity")
	TEST_ASSERT(findtext(attack_history(second), REF(mech)), "The mech pilot's individual log omitted the targeted mech")
	boss.LoseTarget()
	mech.remove_occupant(second)
