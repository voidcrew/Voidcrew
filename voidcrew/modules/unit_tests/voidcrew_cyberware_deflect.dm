/// The dermal ladder turns bullets from the front: a real glance that leaves
/// the bearer unhurt and keeps the round flying on a new heading, costs a
/// little stamina, never touches lasers or shots into the back, switches off
/// with the chrome, and never lifts dodge plus deflect past the shared cap.
/datum/unit_test/voidcrew_cyberware_deflect

/datum/unit_test/voidcrew_cyberware_deflect/Run()
	var/obj/item/organ/cyberimp/cyberware/dermal_mesh/mesh = allocate(/obj/item/organ/cyberimp/cyberware/dermal_mesh)
	var/obj/item/organ/cyberimp/cyberware/dermal_mesh/hardweave/hardweave = allocate(/obj/item/organ/cyberimp/cyberware/dermal_mesh/hardweave)
	var/obj/item/organ/cyberimp/cyberware/slabskin/slab = allocate(/obj/item/organ/cyberimp/cyberware/slabskin)
	TEST_ASSERT_EQUAL(mesh.deflect_chance, 15, "Dermal Mesh deflects at the wrong chance")
	TEST_ASSERT_EQUAL(hardweave.deflect_chance, 30, "Hardweave deflects at the wrong chance")
	TEST_ASSERT_EQUAL(slab.deflect_chance, 45, "Slabskin deflects at the wrong chance")

	// The cap: dodge + (1 - dodge) * deflect never passes 60%.
	TEST_ASSERT_EQUAL(cyberware_deflect_cap(0), 60, "The deflect cap is wrong with no dodge")
	TEST_ASSERT_EQUAL(cyberware_deflect_cap(60), 0, "A full-cap dodge still left room to deflect")
	for(var/dodge in list(0, 15, 30, 45, 59))
		var/deflect = min(slab.deflect_chance, cyberware_deflect_cap(dodge))
		var/combined = dodge + (100 - dodge) * deflect / 100
		TEST_ASSERT(combined <= 60.001, "Dodge [dodge] plus deflect stops [combined]% of shots")

	var/mob/living/carbon/human/patient = allocate(/mob/living/carbon/human/consistent)
	var/mob/living/carbon/human/shooter = allocate(/mob/living/carbon/human/consistent, run_loc_floor_bottom_left)
	TEST_ASSERT(slab.Insert(patient, TRUE), "Slabskin fixture failed")
	var/datum/component/cyberware_dodge/arbiter = patient.GetComponent(/datum/component/cyberware_dodge)
	TEST_ASSERT_NOTNULL(arbiter, "Slabskin didn't register a deflect source")
	// Force every glance: a 100% plate under a lifted cap. The cap itself is checked above.
	slab.deflect_chance = 100
	arbiter.avoid_cap = 100
	patient.setDir(SOUTH)

	// A bullet from the front (travelling north into a bearer facing south) glances off.
	var/obj/projectile/bullet/c9mm/front = make_shot(/obj/projectile/bullet/c9mm, shooter, 0)
	var/front_damage = front.damage
	TEST_ASSERT_EQUAL(patient.bullet_act(front, BODY_ZONE_CHEST), BULLET_ACT_FORCE_PIERCE, "A bullet from the front didn't glance off")
	TEST_ASSERT_EQUAL(patient.getBruteLoss(), 0, "A glanced bullet still hurt")
	TEST_ASSERT(front.angle != 0, "The glanced bullet kept its heading")
	TEST_ASSERT(front.damage < front_damage, "The glanced bullet lost no energy")
	TEST_ASSERT(patient.getStaminaLoss() > 0, "A glance cost no stamina")

	// Every buckshot pellet is a bullet of its own and rolls on its own.
	var/obj/projectile/bullet/pellet/shotgun_buckshot/pellet = make_shot(/obj/projectile/bullet/pellet/shotgun_buckshot, shooter, 0)
	TEST_ASSERT_EQUAL(patient.bullet_act(pellet, BODY_ZONE_CHEST), BULLET_ACT_FORCE_PIERCE, "A buckshot pellet didn't glance off")

	// A bullet into the back always lands.
	var/obj/projectile/bullet/c9mm/back = make_shot(/obj/projectile/bullet/c9mm, shooter, 180)
	TEST_ASSERT_NOTEQUAL(patient.bullet_act(back, BODY_ZONE_CHEST), BULLET_ACT_FORCE_PIERCE, "A bullet into the back glanced off")
	TEST_ASSERT(patient.getBruteLoss() > 0, "A bullet into the back did nothing")

	// Lasers are never deflected.
	var/obj/projectile/beam/laser/laser = make_shot(/obj/projectile/beam/laser, shooter, 0)
	TEST_ASSERT_NOTEQUAL(patient.bullet_act(laser, BODY_ZONE_CHEST), BULLET_ACT_FORCE_PIERCE, "A laser glanced off the plate")
	TEST_ASSERT(patient.getFireLoss() > 0, "The laser did nothing")

	// A failing plate deflects nothing.
	slab.organ_flags |= ORGAN_FAILING
	var/obj/projectile/bullet/c9mm/failing = make_shot(/obj/projectile/bullet/c9mm, shooter, 0)
	TEST_ASSERT_NOTEQUAL(patient.bullet_act(failing, BODY_ZONE_CHEST), BULLET_ACT_FORCE_PIERCE, "A failing plate still deflected")
	slab.organ_flags &= ~ORGAN_FAILING

	// Taking the plate out takes the deflect with it.
	slab.Remove(patient)
	TEST_ASSERT_NULL(patient.GetComponent(/datum/component/cyberware_dodge), "The deflect source outlived the plate")

/// A hostile shot from the shooter, heading at the given angle, ready for bullet_act().
/datum/unit_test/voidcrew_cyberware_deflect/proc/make_shot(shot_type, mob/living/shooter, heading)
	var/obj/projectile/shot = allocate(shot_type)
	shot.firer = shooter
	shot.def_zone = BODY_ZONE_CHEST
	shot.set_angle(heading)
	return shot
