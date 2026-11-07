// voidcrew/modules/gun_feel. Voidcrew defines are not visible here, so values are literals.

/// Drives a movable_physics component to the end of its flight without waiting on the subsystem.
/datum/unit_test/proc/gun_feel_finish_flight(datum/component/movable_physics/flight)
	for(var/step in 1 to 200)
		if(QDELETED(flight))
			return TRUE
		flight.process(0.05)
	return QDELETED(flight)

/// A fired pistol flashes, and its casing lands as an ordinary item on an open turf with no physics left on it.
/datum/unit_test/voidcrew_gun_feel_casing
/datum/unit_test/voidcrew_gun_feel_casing/Run()
	var/mob/living/carbon/human/consistent/shooter = allocate(/mob/living/carbon/human/consistent)
	var/obj/item/gun/ballistic/automatic/pistol/pistol = allocate(/obj/item/gun/ballistic/automatic/pistol)
	TEST_ASSERT(shooter.put_in_hands(pistol), "The shooter could not hold the pistol.")
	var/obj/item/ammo_casing/casing = pistol.chambered
	TEST_ASSERT_NOTNULL(casing, "A new pistol should start with a round chambered.")
	TEST_ASSERT(pistol.process_fire(run_loc_floor_top_right, shooter, FALSE, null, "", 0), "The pistol did not fire.")
	TEST_ASSERT(!QDELETED(casing), "The fired casing was deleted instead of ejected.")
	TEST_ASSERT_NOTNULL(locate(/obj/effect/temp_visual/gun_feel_muzzle_flash) in shooter.vis_contents, "A powder round should show a muzzle flash on the shooter.")
	TEST_ASSERT_NOTNULL(pistol.gun_feel_light, "A powder round should light the shooter up.")

	// The test level may have no gravity, in which case the casing drops the old way and has no flight.
	var/datum/component/movable_physics/flight = casing.GetComponent(/datum/component/movable_physics)
	if(flight)
		TEST_ASSERT(gun_feel_finish_flight(flight), "The casing's flight never ended.")
	TEST_ASSERT(isturf(casing.loc), "The casing should end up on a turf, not in [casing.loc || "nullspace"].")
	var/turf/landing = casing.loc
	TEST_ASSERT(!landing.density, "The casing landed inside a dense turf ([landing.type]).")
	TEST_ASSERT_NULL(casing.GetComponent(/datum/component/movable_physics), "A settled casing kept its physics component.")
	TEST_ASSERT_EQUAL(casing.pixel_z, casing.base_pixel_z, "A settled casing was left floating.")
	if(flight)
		TEST_ASSERT(!(flight in SSmovable_physics.processing), "A finished flight is still being processed.")

/// A movable thrown hard at the corner glances off walls and still settles on an open turf.
/datum/unit_test/voidcrew_gun_feel_physics_walls
/datum/unit_test/voidcrew_gun_feel_physics_walls/Run()
	for(var/angle in list(0, 135, 225, 315))
		var/obj/item/ammo_casing/c9mm/casing = allocate(/obj/item/ammo_casing/c9mm)
		var/datum/component/movable_physics/flight = casing.AddComponent(/datum/component/movable_physics, 10, 3, angle, 8, FALSE, FALSE)
		TEST_ASSERT_NOTNULL(flight, "The physics component refused a casing on a floor.")
		TEST_ASSERT(gun_feel_finish_flight(flight), "A flight at [angle] degrees never ended.")
		TEST_ASSERT(isturf(casing.loc), "A flight at [angle] degrees left the casing in [casing.loc || "nullspace"].")
		var/turf/landing = casing.loc
		TEST_ASSERT(!landing.density, "A flight at [angle] degrees ended inside a dense turf ([landing.type]).")
		TEST_ASSERT(abs(casing.pixel_x - casing.base_pixel_x) <= 16 && abs(casing.pixel_y - casing.base_pixel_y) <= 16, "A flight at [angle] degrees left the casing drawn off its tile.")
		TEST_ASSERT_EQUAL(casing.pixel_z, casing.base_pixel_z, "A flight at [angle] degrees left the casing floating.")

/// Long guns are hip-fired until both hands have been on them for the shoulder delay (0.4 s).
/datum/unit_test/voidcrew_gun_feel_shouldering
/datum/unit_test/voidcrew_gun_feel_shouldering/Run()
	var/mob/living/carbon/human/consistent/shooter = allocate(/mob/living/carbon/human/consistent)
	var/obj/item/gun/ballistic/automatic/wt550/rifle = allocate(/obj/item/gun/ballistic/automatic/wt550)
	TEST_ASSERT(shooter.put_in_hands(rifle), "The shooter could not hold the rifle.")
	TEST_ASSERT(rifle.gun_feel_long, "The WT-550 should be a long gun.")
	TEST_ASSERT(rifle.gun_feel_hip_spread(shooter) > 0, "A long gun should not be shouldered the moment it is drawn.")

	rifle.gun_feel_brace_start = max(1, world.time - 1 SECONDS)
	TEST_ASSERT_EQUAL(rifle.gun_feel_hip_spread(shooter), 0, "A long gun held in both hands past the delay should be shouldered.")

	var/obj/item/pen/pen = allocate(/obj/item/pen)
	TEST_ASSERT(shooter.put_in_hands(pen), "The shooter could not hold a pen in the other hand.")
	TEST_ASSERT_EQUAL(rifle.gun_feel_brace_start, 0, "Filling the off hand should drop the shoulder.")
	TEST_ASSERT(rifle.gun_feel_hip_spread(shooter) > 0, "A long gun held one-handed should fire from the hip.")

	shooter.dropItemToGround(pen)
	TEST_ASSERT(rifle.gun_feel_brace_start, "Freeing the off hand should start the shoulder clock.")
	TEST_ASSERT(rifle.gun_feel_hip_spread(shooter) > 0, "A long gun should not be shouldered the moment the off hand frees up.")

	var/obj/item/gun/ballistic/automatic/pistol/pistol = allocate(/obj/item/gun/ballistic/automatic/pistol)
	TEST_ASSERT_EQUAL(pistol.gun_feel_hip_spread(shooter), 0, "Pistols have no hip-fire penalty.")
