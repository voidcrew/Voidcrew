/// Living humans get cut into moving pieces, and get their sprite back when they die.
/datum/unit_test/limb_rig

/datum/unit_test/limb_rig/Run()
	var/mob/living/carbon/human/consistent/dummy = allocate(/mob/living/carbon/human/consistent)
	dummy.update_limb_rig()
	TEST_ASSERT_NULL(dummy.limb_rig, "A human without the Overanimated quirk got a limb rig.")
	dummy.add_quirk(/datum/quirk/overanimated)
	TEST_ASSERT_NOTNULL(dummy.limb_rig, "A living human did not get a limb rig.")
	var/body = dummy.overlays_standing[BODYPARTS_LAYER]
	TEST_ASSERT_NOTNULL(body, "The human has no body overlays to rig.")
	TEST_ASSERT(!(body in dummy.overlays), "The rigged human still draws its body on the mob.")
	var/obj/effect/abstract/limb_rig_part/torso = dummy.limb_rig.parts["chest"]
	TEST_ASSERT(length(torso.overlays), "The rig's torso piece has nothing on it.")

	// Redraws while rigged go to the pieces, not the mob.
	dummy.update_body_parts(update_limb_data = TRUE)
	TEST_ASSERT(!(dummy.overlays_standing[BODYPARTS_LAYER] in dummy.overlays), "A redraw put the body back on the rigged mob.")

	dummy.death()
	TEST_ASSERT_NULL(dummy.limb_rig, "A dead human kept its limb rig.")
	TEST_ASSERT(length(dummy.overlays), "A human that lost its rig didn't get its sprite back.")
