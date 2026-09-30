/// A ghost that left its body for good (suicide, DNR, the Ghost verb) keeps no mind, only its ckey.
/// It may still claim its vat clone once the body is dead; a lobby observer or the ghost of a living
/// body may not.
/datum/unit_test/voidcrew_cloning_vat_claim
	/// Mobs this test made outside allocate(), deleted with their offline keys cleared
	var/list/mob/made_mobs = list()

/datum/unit_test/voidcrew_cloning_vat_claim/Destroy()
	for(var/mob/made as anything in made_mobs + allocated)
		if(ismob(made) && !QDELETED(made))
			made.key = null
	for(var/mob/made as anything in made_mobs)
		if(!QDELETED(made))
			qdel(made)
	made_mobs.Cut()
	return ..()

/datum/unit_test/voidcrew_cloning_vat_claim/Run()
	var/obj/machinery/cloning_vat/vat = allocate(/obj/machinery/cloning_vat, run_loc_floor_bottom_left)
	var/mob/living/carbon/human/consistent/original = allocate(/mob/living/carbon/human/consistent, run_loc_floor_bottom_left)
	original.key = "clonevatclaimtest"
	original.mind_initialize()
	var/datum/mind/mind = original.mind
	vat.do_imprint(original)
	TEST_ASSERT_EQUAL(vat.imprint_mind_ref?.resolve(), mind, "Imprinting did not bind the vat to the player's mind")

	// The Ghost verb while alive: the ghost has no mind and the body lives on.
	var/mob/dead/observer/ghost = original.ghostize(FALSE)
	TEST_ASSERT_NOTNULL(ghost, "The test body could not ghost")
	made_mobs += ghost
	TEST_ASSERT_NULL(ghost.mind, "A ghost that cannot re-enter its body kept the mind")
	TEST_ASSERT_EQUAL(ghost.ckey, "clonevatclaimtest", "The ghost did not keep the player's ckey")
	TEST_ASSERT(!vat.holder_matches(ghost, mind), "The ghost of a living body matched the vat's imprint")

	original.death()
	TEST_ASSERT(vat.holder_matches(ghost, mind), "A mindless ghost of the dead imprinted player did not match the vat")
	// holder_ghost() finds a mindless ghost through its connected client (GLOB.directory), and test mobs have none

	ghost.started_as_observer = TRUE
	TEST_ASSERT(!vat.holder_matches(ghost, mind), "A lobby observer with the imprinted ckey matched the vat")
	ghost.started_as_observer = FALSE

	vat.growth_progress = vat.growth_time
	vat.body_ready = TRUE
	vat.claim(ghost, mind)
	var/mob/living/carbon/human/clone = mind.current
	TEST_ASSERT(clone && clone != original, "Claiming the vat did not move the player into a new body")
	made_mobs += clone
	TEST_ASSERT(clone.stat != DEAD, "The claimed clone is dead")
	TEST_ASSERT_EQUAL(clone.ckey, "clonevatclaimtest", "The player's key did not move into the clone")
	TEST_ASSERT(!vat.body_ready && vat.growth_progress == 0, "The vat did not start regrowing after the claim")
