/// Living human-shaped mobs outside the roundstart species get cut into moving pieces with the
/// Overanimated quirk, and get their sprite back when they die.
/datum/unit_test/limb_rig

/datum/unit_test/limb_rig/Run()
	var/mob/living/carbon/human/consistent/dummy = allocate(/mob/living/carbon/human/consistent)
	dummy.set_species(/datum/species/skeleton)
	dummy.update_limb_rig()
	TEST_ASSERT_NULL(dummy.limb_rig, "A skeleton without the Overanimated quirk got a limb rig.")
	dummy.add_quirk(/datum/quirk/overanimated)
	TEST_ASSERT_NOTNULL(dummy.limb_rig, "A living skeleton with the quirk did not get a limb rig.")
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

/// Every roundstart species is rigged without the quirk, and a tail comes out onto its own piece.
/datum/unit_test/limb_rig_species

/datum/unit_test/limb_rig_species/Run()
	for(var/species_type in list(/datum/species/human, /datum/species/human/felinid, /datum/species/lizard, /datum/species/moth, /datum/species/plasmaman, /datum/species/ethereal))
		var/mob/living/carbon/human/consistent/person = allocate(/mob/living/carbon/human/consistent)
		person.set_species(species_type)
		person.update_limb_rig()
		TEST_ASSERT_NOTNULL(person.limb_rig, "[species_type] is not rigged without the Overanimated quirk.")
		TEST_ASSERT(istype(person.limb_rig, /datum/limb_rig/sprites/humanoid), "[species_type] is not on the generated body.")
		var/datum/limb_rig/sprites/humanoid/rig = person.limb_rig
		TEST_ASSERT(length(rig.head_images), "[species_type]'s own head is not on its generated body.")
		TEST_ASSERT(length(rig.skin_images) == 12, "[species_type]'s generated body is missing pieces of skin.")
	var/mob/living/carbon/human/consistent/lizard = allocate(/mob/living/carbon/human/consistent)
	lizard.set_species(/datum/species/lizard)
	lizard.update_limb_rig()
	if(lizard.get_organ_slot(ORGAN_SLOT_EXTERNAL_TAIL))
		TEST_ASSERT(length(lizard.limb_rig.tail_part.overlays), "A lizard's tail did not come out onto its tail piece.")

/// Experiments are always rigged, quirk or not, built from their own piece sprites, with worn
/// clothes going on the cloth pieces rather than the body ones.
/datum/unit_test/limb_rig_experiment

/datum/unit_test/limb_rig_experiment/Run()
	var/mob/living/carbon/human/consistent/expie = allocate(/mob/living/carbon/human/consistent)
	expie.set_species(/datum/species/experiment)
	expie.update_limb_rig()
	TEST_ASSERT(istype(expie.limb_rig, /datum/limb_rig/sprites), "An Experiment without the Overanimated quirk has no sprite-built limb rig.")
	var/datum/limb_rig/sprites/rig = expie.limb_rig
	var/uniform = allocate(/obj/item/clothing/under/color/grey)
	TEST_ASSERT(expie.equip_to_slot_if_possible(uniform, ITEM_SLOT_ICLOTHING), "The Experiment could not put on a jumpsuit.")
	var/obj/effect/abstract/limb_rig_part/torso = rig.parts["chest"]
	var/obj/effect/abstract/limb_rig_part/torso_cloth = rig.cloth_parts["chest"]
	TEST_ASSERT_EQUAL(length(torso.overlays), 1, "An Experiment's torso piece shows more than its own sprite.")
	TEST_ASSERT(length(torso_cloth.overlays), "An Experiment's jumpsuit is not on its torso's cloth piece.")
	TEST_ASSERT_EQUAL(expie.get_bloodtype()?.id, "EXP", "An Experiment does not have its yellow blood.")
	expie.apply_damage(40, BRUTE, BODY_ZONE_CHEST)
	expie.update_damage_overlays()
	TEST_ASSERT(length(torso.overlays) > 1, "A wounded Experiment's torso piece shows no wounds.")
	expie.death()
	TEST_ASSERT_NULL(expie.limb_rig, "A dead Experiment kept its limb rig.")

/// Milkies are Experiments on their own sprites: white, short-legged, with faces of their own.
/datum/unit_test/limb_rig_milkie

/datum/unit_test/limb_rig_milkie/Run()
	var/mob/living/carbon/human/consistent/milkie = allocate(/mob/living/carbon/human/consistent)
	milkie.set_species(/datum/species/experiment/milkie)
	milkie.update_limb_rig()
	TEST_ASSERT(istype(milkie.limb_rig, /datum/limb_rig/sprites/experiment/milkie), "A Milkie has no Milkie limb rig.")
	var/datum/limb_rig/sprites/rig = milkie.limb_rig
	TEST_ASSERT_EQUAL(rig.sprite_icon, 'voidcrew/modules/expie/icons/milkie_rig.dmi', "A Milkie is drawn with the wrong sprites.")
	var/list/leg = rig.skeleton["east"]["l_leg"]
	var/list/hips = leg[1]
	TEST_ASSERT(hips[2] < 20, "A Milkie's legs are as long as an Experiment's.")
	TEST_ASSERT_EQUAL(milkie.get_bloodtype()?.id, "EXP", "A Milkie does not have an Experiment's blood.")
	var/list/body_states = icon_states('voidcrew/modules/expie/icons/milkie_bodyparts.dmi')
	for(var/obj/item/bodypart/limb as anything in milkie.bodyparts)
		TEST_ASSERT("[limb.limb_id]_[limb.body_zone]" in body_states, "A Milkie's [limb.body_zone] has no sprite.")
	var/list/face_states = icon_states('voidcrew/modules/fnf/icons/fnf_faces_experiment.dmi')
	var/list/corrupt_states = icon_states('voidcrew/modules/fnf/icons/fnf_faces_experiment_corrupt.dmi')
	for(var/expression in list("idle", "left", "down", "up", "right", "miss", "hey", "dead"))
		TEST_ASSERT("milkie_[expression]" in face_states, "A Milkie has no [expression] face.")
		TEST_ASSERT("milkie_corrupt_[expression]" in corrupt_states, "A Milkie has no corrupted [expression] face.")
		TEST_ASSERT("milkie_corrupthalf_[expression]" in corrupt_states, "A Milkie has no half-freed [expression] grin.")
		TEST_ASSERT("milkie_window_[expression]" in face_states, "A Milkie has no half-freed [expression] eye.")
	TEST_ASSERT("hands_milkie_l_forearm" in icon_states('voidcrew/modules/fnf/icons/corruption_64.dmi'), "A Milkie's hands can't be corrupted.")
