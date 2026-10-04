/// A jetpack that can fire keeps its wearer out of the hyperspace pull, and hands them back to it the moment it can't.
/datum/unit_test/hyperspace_jetpack
	var/list/turf/changed_turfs = list()
	var/list/original_turf_types = list()
	/// Whether the test jetpacks have anything left to fire.
	var/fuelled = TRUE

/datum/unit_test/hyperspace_jetpack/Destroy()
	for(var/i in 1 to length(changed_turfs))
		var/turf/changed = changed_turfs[i]
		changed.ChangeTurf(original_turf_types[i])
	return ..()

/datum/unit_test/hyperspace_jetpack/proc/check_fuel(use_fuel)
	return fuelled

/datum/unit_test/hyperspace_jetpack/proc/strap_on(mob/living/wearer)
	var/obj/item/pack = allocate(/obj/item)
	var/datum/component/jetpack/jet = pack.AddComponent(/datum/component/jetpack/hyperspace_test, TRUE, 1 NEWTONS, 1 NEWTONS, COMSIG_JETPACK_ACTIVATED, COMSIG_JETPACK_DEACTIVATED, JETPACK_ACTIVATION_FAILED, CALLBACK(src, PROC_REF(check_fuel)), null, null)
	SEND_SIGNAL(pack, COMSIG_JETPACK_ACTIVATED, wearer)
	return jet

/datum/unit_test/hyperspace_jetpack/Run()
	// A patch of hyperspace with no hull anywhere near it.
	for(var/offset in 0 to 2)
		var/turf/corridor = locate(run_loc_floor_bottom_left.x + 1 + offset, run_loc_floor_bottom_left.y + 1, run_loc_floor_bottom_left.z)
		original_turf_types += corridor.type
		changed_turfs += corridor.ChangeTurf(/turf/open/space/transit)
	var/turf/open/space/transit/drift_tile = changed_turfs[2]

	var/mob/living/carbon/human/consistent/rider = allocate(/mob/living/carbon/human/consistent)
	rider.forceMove(drift_tile)
	var/datum/component/shuttle_cling/cling = rider.GetComponent(/datum/component/shuttle_cling)
	TEST_ASSERT(cling && !QDELETED(cling), "Hyperspace did not take hold of a rider away from any hull.")
	TEST_ASSERT_NOTNULL(cling.hyperloop, "Hyperspace is not pulling a rider with no jetpack.")

	var/datum/component/jetpack/first_jet = strap_on(rider)
	TEST_ASSERT_EQUAL(first_jet.user, rider, "A test jetpack did not switch on.")
	first_jet.update_hyperspace_freedom()
	TEST_ASSERT(HAS_TRAIT(rider, TRAIT_FREE_HYPERSPACE_MOVEMENT), "A running jetpack did not free its wearer in hyperspace.")
	TEST_ASSERT_NULL(cling.hyperloop, "Hyperspace kept pulling a rider on a running jetpack.")
	TEST_ASSERT(!hyperspace_free_without_jetpack(rider), "A jetpack's exemption was counted as one that refuses the hull grip.")

	fuelled = FALSE
	first_jet.update_hyperspace_freedom()
	TEST_ASSERT(!HAS_TRAIT(rider, TRAIT_FREE_HYPERSPACE_MOVEMENT), "A jetpack with nothing to fire still freed its wearer.")
	TEST_ASSERT_NOTNULL(cling.hyperloop, "Hyperspace did not take the rider back when their jetpack could not fire.")

	fuelled = TRUE
	first_jet.update_hyperspace_freedom()
	TEST_ASSERT_NULL(cling.hyperloop, "Refuelling did not free the rider again.")

	// Two running at once: switching one off must not ground the wearer.
	var/datum/component/jetpack/second_jet = strap_on(rider)
	TEST_ASSERT_EQUAL(second_jet.user, rider, "A test jetpack did not switch on.")
	second_jet.update_hyperspace_freedom()
	SEND_SIGNAL(first_jet.parent, COMSIG_JETPACK_DEACTIVATED, rider)
	TEST_ASSERT(HAS_TRAIT(rider, TRAIT_FREE_HYPERSPACE_MOVEMENT), "Switching off one of two jetpacks grounded the wearer.")
	TEST_ASSERT_NULL(cling.hyperloop, "Switching off one of two jetpacks started the pull.")

	// Losing the jetpack outright lets go too.
	qdel(second_jet.parent)
	TEST_ASSERT(!HAS_TRAIT(rider, TRAIT_FREE_HYPERSPACE_MOVEMENT), "Deleting a running jetpack left its wearer free.")
	TEST_ASSERT_NOTNULL(cling.hyperloop, "Deleting a running jetpack did not start the pull.")

	// Only a jetpack's exemption lets a rider take the hull grip; a carp's still refuses it.
	ADD_TRAIT(rider, TRAIT_FREE_HYPERSPACE_MOVEMENT, "hyperspace_jetpack_test")
	TEST_ASSERT(hyperspace_free_without_jetpack(rider), "An exemption from something other than a jetpack was not recognised.")
	REMOVE_TRAIT(rider, TRAIT_FREE_HYPERSPACE_MOVEMENT, "hyperspace_jetpack_test")

	// Out of hyperspace, a running jetpack holds no exemption.
	var/datum/component/jetpack/third_jet = strap_on(rider)
	TEST_ASSERT_EQUAL(third_jet.user, rider, "A test jetpack did not switch on.")
	third_jet.update_hyperspace_freedom()
	TEST_ASSERT(HAS_TRAIT(rider, TRAIT_FREE_HYPERSPACE_MOVEMENT), "A second switch-on did not free the rider.")
	rider.forceMove(run_loc_floor_bottom_left)
	third_jet.update_hyperspace_freedom()
	TEST_ASSERT(!HAS_TRAIT(rider, TRAIT_FREE_HYPERSPACE_MOVEMENT), "A jetpack kept its hyperspace exemption outside hyperspace.")

/// Unit tests have no clients, and a real jetpack only fires for a player at the controls.
/datum/component/jetpack/hyperspace_test/should_trigger(mob/source)
	return TRUE

/// The trail effect reads the missing client's input, and this jetpack has no trail anyway.
/datum/component/jetpack/hyperspace_test/move_react(mob/source)
	SIGNAL_HANDLER
	return
