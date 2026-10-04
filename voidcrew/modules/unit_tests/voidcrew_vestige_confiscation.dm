/// An unchanged booking still returns the actual stolen item through its ordinary timed throw.
/datum/unit_test/vestige_confiscation_return
	var/return_throws = 0

/datum/unit_test/vestige_confiscation_return/proc/on_return_throw(datum/source)
	SIGNAL_HANDLER
	return_throws++

/datum/unit_test/vestige_confiscation_return/Run()
	var/turf/center = get_step(get_step(run_loc_floor_bottom_left, NORTH), EAST)
	var/mob/living/carbon/human/consistent/victim = allocate(/mob/living/carbon/human/consistent, center)
	var/mob/living/basic/vestige_mutant/boss = allocate(/mob/living/basic/vestige_mutant, get_step(center, EAST))
	ADD_TRAIT(boss, TRAIT_AI_PAUSED, TRAIT_SOURCE_UNIT_TESTS)
	boss.begin_revision()
	var/datum/action/cooldown/mob_cooldown/vestige_tk/confiscate/confiscate = boss.confiscate
	var/obj/item/crowbar/prize = allocate(/obj/item/crowbar)
	TEST_ASSERT(victim.put_in_hands(prize), "The ordinary return route must begin with a real held item.")
	RegisterSignal(prize, COMSIG_MOVABLE_POST_THROW, PROC_REF(on_return_throw))
	TEST_ASSERT(confiscate.Trigger(target = victim), "The real boss action must confiscate the ordinary prize.")
	var/deadline = world.time + confiscate.hold_time + 2 SECONDS
	while(length(confiscate.booked_property) && world.time < deadline)
		sleep(world.tick_lag)
	TEST_ASSERT_EQUAL(return_throws, 1, "The actual unshortened callback must throw an unchanged prize back exactly once.")
	TEST_ASSERT_EQUAL(length(confiscate.booked_property), 0, "The ordinary return must retire its pending booking.")
	TEST_ASSERT(!prize.get_filter("vestige_telekinesis"), "The ordinary return must clear its pending outline before flight.")

/// Deleting a real Confiscation action or its boss releases only its pending prize outline.
/datum/unit_test/vestige_confiscation_deletion/Run()
	var/turf/center = get_step(get_step(run_loc_floor_bottom_left, NORTH), EAST)
	for(var/delete_boss in list(FALSE, TRUE))
		var/mob/living/carbon/human/consistent/victim = allocate(/mob/living/carbon/human/consistent, center)
		var/mob/living/basic/vestige_mutant/boss = allocate(/mob/living/basic/vestige_mutant, get_step(center, EAST))
		ADD_TRAIT(boss, TRAIT_AI_PAUSED, TRAIT_SOURCE_UNIT_TESTS)
		boss.begin_revision()
		var/datum/action/cooldown/mob_cooldown/vestige_tk/confiscate/confiscate = boss.confiscate
		var/obj/item/crowbar/prize = allocate(/obj/item/crowbar)
		TEST_ASSERT(victim.put_in_hands(prize), "The victim must actually hold the prize before Confiscation.")
		TEST_ASSERT(confiscate.Trigger(target = victim), "The boss's real action trigger must take the held prize.")
		TEST_ASSERT_EQUAL(get_turf(prize), get_turf(boss), "Confiscation must physically put the victim's property at the boss's feet.")
		TEST_ASSERT(prize in confiscate.booked_property, "The real stolen item must be booked until its return.")
		TEST_ASSERT(prize.get_filter("vestige_telekinesis"), "The pending return must have its actual telekinetic outline.")
		prize.add_filter("unit_test_independent_outline", 1, list("type" = "outline", "color" = COLOR_RED, "size" = 1))
		if(delete_boss)
			qdel(boss)
		else
			qdel(confiscate)
		TEST_ASSERT(QDELETED(confiscate), "Both the action and boss deletion paths must reclaim the pending action.")
		TEST_ASSERT(!QDELETED(prize), "Canceling Confiscation must preserve the victim's actual property.")
		TEST_ASSERT(!prize.get_filter("vestige_telekinesis"), "Cancellation must not strand its outline on the surviving prize.")
		TEST_ASSERT(prize.get_filter("unit_test_independent_outline"), "Cancellation must preserve unrelated effects even after render-filter rebuilding.")
		qdel(prize)
		qdel(victim)
		if(!QDELETED(boss))
			qdel(boss)

/// A later real player grab owns the property through both the old return timer and action deletion.
/datum/unit_test/vestige_confiscation_newer_hold/Run()
	var/turf/center = get_step(get_step(run_loc_floor_bottom_left, NORTH), EAST)
	for(var/delete_action in list(FALSE, TRUE))
		var/mob/living/carbon/human/consistent/victim = allocate(/mob/living/carbon/human/consistent, center)
		var/mob/living/basic/vestige_mutant/boss = allocate(/mob/living/basic/vestige_mutant, get_step(center, EAST))
		ADD_TRAIT(boss, TRAIT_AI_PAUSED, TRAIT_SOURCE_UNIT_TESTS)
		boss.begin_revision()
		var/datum/action/cooldown/mob_cooldown/vestige_tk/confiscate/confiscate = boss.confiscate
		var/obj/item/crowbar/prize = allocate(/obj/item/crowbar)
		TEST_ASSERT(victim.put_in_hands(prize), "The newer-hold scenario must begin with an actually held item.")
		TEST_ASSERT(confiscate.Trigger(target = victim), "The actual boss action must confiscate the item before the player's grab.")
		var/datum/action/cooldown/spell/greater_telekinesis/field = allocate(/datum/action/cooldown/spell/greater_telekinesis, victim)
		field.Grant(victim)
		TEST_ASSERT(field.Trigger(), "The real player action must raise its telekinetic field.")
		victim.ClickOn(prize, "")
		TEST_ASSERT(prize in field.lifted, "The actual player click must take the confiscated prize into a newer hold.")
		TEST_ASSERT_EQUAL(prize.orbiting?.parent, victim, "The newer player field must physically own the orbit.")
		var/list/new_outline = prize.filter_data["vestige_telekinesis"]
		if(delete_action)
			qdel(confiscate)
		else
			var/deadline = world.time + confiscate.hold_time + 2 SECONDS
			while(length(confiscate.booked_property) && world.time < deadline)
				sleep(world.tick_lag)
			TEST_ASSERT_EQUAL(length(confiscate.booked_property), 0, "The actual unshortened return timer must release its old booking.")
		TEST_ASSERT(prize in field.lifted, "An old Confiscation must not remove a newer player's hold.")
		TEST_ASSERT_EQUAL(prize.filter_data["vestige_telekinesis"], new_outline, "Old cleanup must preserve the exact newer outline.")
		TEST_ASSERT_EQUAL(prize.orbiting?.parent, victim, "Old cleanup must preserve the newer physical orbit.")
		TEST_ASSERT(!prize.throwing, "The expired old return must not throw property owned by a newer field.")
		field.stop_lifting(silent = TRUE)
		TEST_ASSERT(!prize.get_filter("vestige_telekinesis") && !prize.orbiting, "The newer field must still release its own hold normally.")
		qdel(field)
		qdel(prize)
		qdel(victim)
		qdel(boss)

/// Deleted return targets and deleted prizes must both settle through the real timer without stale bookings.
/datum/unit_test/vestige_confiscation_target_deleted/Run()
	var/turf/center = get_step(get_step(run_loc_floor_bottom_left, NORTH), EAST)
	for(var/delete_victim in list(FALSE, TRUE))
		var/mob/living/carbon/human/consistent/victim = allocate(/mob/living/carbon/human/consistent, center)
		var/mob/living/basic/vestige_mutant/boss = allocate(/mob/living/basic/vestige_mutant, get_step(center, EAST))
		ADD_TRAIT(boss, TRAIT_AI_PAUSED, TRAIT_SOURCE_UNIT_TESTS)
		boss.begin_revision()
		var/datum/action/cooldown/mob_cooldown/vestige_tk/confiscate/confiscate = boss.confiscate
		var/obj/item/crowbar/prize = allocate(/obj/item/crowbar)
		TEST_ASSERT(victim.put_in_hands(prize), "The deletion scenario must begin with an actually held prize.")
		TEST_ASSERT(confiscate.Trigger(target = victim), "The actual Confiscation trigger must book its return.")
		if(delete_victim)
			qdel(victim)
		else
			qdel(prize)
		var/deadline = world.time + confiscate.hold_time + 2 SECONDS
		while(length(confiscate.booked_property) && world.time < deadline)
			sleep(world.tick_lag)
		TEST_ASSERT_EQUAL(length(confiscate.booked_property), 0, "A deleted target or prize must leave no booking after the actual return callback.")
		if(delete_victim)
			TEST_ASSERT(!QDELETED(prize) && !prize.throwing, "A deleted victim must leave their surviving property resting safely.")
			TEST_ASSERT(!prize.get_filter("vestige_telekinesis"), "A deleted victim must not leave the surviving prize outlined.")
			qdel(prize)
		else
			qdel(victim)
		qdel(boss)
