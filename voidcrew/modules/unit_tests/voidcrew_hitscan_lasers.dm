/// Standard lasers are hitscan with a visible tracer; the beams we chose to keep as bolts are not.
/datum/unit_test/voidcrew_hitscan_lasers/Run()
	var/list/obj/projectile/hitscan_types = list(
		/obj/projectile/beam/laser,
		/obj/projectile/beam/laser/carbine,
		/obj/projectile/beam/laser/carbine/cybersun,
		/obj/projectile/beam/laser/hellfire,
		/obj/projectile/beam/laser/heavylaser,
		/obj/projectile/beam/laser/musket,
		/obj/projectile/beam/laser/outpost,
		/obj/projectile/beam/scatter,
		/obj/projectile/beam/weak/penetrator,
		/obj/projectile/beam/practice,
	)
	for(var/obj/projectile/laser_type as anything in hitscan_types)
		TEST_ASSERT(initial(laser_type.hitscan), "[laser_type] is not hitscan")
		TEST_ASSERT_NOTNULL(initial(laser_type.tracer_type), "[laser_type] is hitscan with no tracer, so its beam is invisible")

	var/list/obj/projectile/bolt_types = list(
		/obj/projectile/beam/disabler,
		/obj/projectile/beam/xray,
		/obj/projectile/beam/pulse,
		/obj/projectile/beam/emitter,
		/obj/projectile/beam/ship_defense,
		/obj/projectile/beam/laser/accelerator,
		/obj/projectile/beam/laser/laser_eyes,
		/obj/projectile/beam/laser/mech,
		/obj/projectile/beam/laser/heavylaser/mech,
	)
	for(var/obj/projectile/bolt_type as anything in bolt_types)
		TEST_ASSERT(!initial(bolt_type.hitscan), "[bolt_type] became hitscan")

	var/obj/item/mecha_parts/mecha_equipment/weapon/energy/laser/mech_laser = /obj/item/mecha_parts/mecha_equipment/weapon/energy/laser
	TEST_ASSERT_EQUAL(initial(mech_laser.projectile), /obj/projectile/beam/laser/mech, "The mech laser fires a hitscan laser")

/// A hitscan laser fired at someone three tiles away lands, from a bare projectile and from a trigger pull.
/// The beam finishes on the firing tick unless the tick is overrun, which it always is in a test, so wait for it.
/datum/unit_test/voidcrew_hitscan_laser_lands/Run()
	var/mob/living/carbon/human/consistent/shooter = allocate(/mob/living/carbon/human/consistent, run_loc_floor_bottom_left)
	var/turf/target_turf = locate(run_loc_floor_bottom_left.x + 3, run_loc_floor_bottom_left.y, run_loc_floor_bottom_left.z)
	var/mob/living/carbon/human/consistent/target = allocate(/mob/living/carbon/human/consistent, target_turf)

	var/obj/projectile/beam/laser/beam = new(run_loc_floor_bottom_left)
	beam.aim_projectile(target, shooter)
	beam.firer = shooter
	beam.fire()
	UNTIL(QDELETED(beam))
	TEST_ASSERT(target.getFireLoss() > 0, "A hitscan laser fired at a target three tiles away missed")

	var/before = target.getFireLoss()
	var/obj/item/gun/energy/laser/rifle = allocate(/obj/item/gun/energy/laser)
	TEST_ASSERT(shooter.put_in_active_hand(rifle), "The shooter could not hold the laser rifle")
	var/charge_before = rifle.cell.charge
	rifle.fire_gun(target, shooter, FALSE)
	TEST_ASSERT(rifle.cell.charge < charge_before, "The laser rifle did not fire")
	sleep(1 SECONDS)
	TEST_ASSERT(target.getFireLoss() > before, "A laser rifle shot three tiles away missed")
