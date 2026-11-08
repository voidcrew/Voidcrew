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

/// TRUE if two matrices are the same, element by element.
/datum/unit_test/proc/gun_feel_same_matrix(matrix/first, matrix/second)
	return abs(first.a - second.a) < 0.001 && abs(first.b - second.b) < 0.001 && abs(first.c - second.c) < 0.001 && abs(first.d - second.d) < 0.001 && abs(first.e - second.e) < 0.001 && abs(first.f - second.f) < 0.001

/// A flinch moves nothing for good: pixel offsets and transform (including a lying-down turn) are the same after it.
/// animate() sets an atom's vars to the end of the sequence at once, and the flinch's relative steps add up to zero.
/datum/unit_test/voidcrew_gun_feel_flinch
/datum/unit_test/voidcrew_gun_feel_flinch/Run()
	var/mob/living/carbon/human/consistent/target = allocate(/mob/living/carbon/human/consistent)
	var/list/before = list(target.pixel_w, target.pixel_x, target.pixel_y, target.pixel_z)
	var/matrix/before_transform = matrix(target.transform)
	TEST_ASSERT(target.gun_feel_flinch(3, EAST), "A standing mob should flinch.")
	TEST_ASSERT(!target.gun_feel_flinch(3, EAST), "A second flinch should wait for the first one to play out.")
	var/list/after = list(target.pixel_w, target.pixel_x, target.pixel_y, target.pixel_z)
	TEST_ASSERT(after ~= before, "A flinch left the mob's pixel offsets moved: [json_encode(after)] after, [json_encode(before)] before.")
	TEST_ASSERT(gun_feel_same_matrix(target.transform, before_transform), "A flinch changed the mob's transform.")

	// Lying down turns the sprite; a flinch must keep that turn.
	target.gun_feel_flinch_cooldown = 0
	target.set_body_position(LYING_DOWN)
	var/matrix/lying_transform = matrix(target.transform)
	var/list/lying_offsets = list(target.pixel_w, target.pixel_x, target.pixel_y, target.pixel_z)
	TEST_ASSERT(target.gun_feel_flinch(2, null), "A lying mob should flinch.")
	TEST_ASSERT(gun_feel_same_matrix(target.transform, lying_transform), "A flinch undid the lying-down turn.")
	after = list(target.pixel_w, target.pixel_x, target.pixel_y, target.pixel_z)
	TEST_ASSERT(after ~= lying_offsets, "A flinch moved a lying mob's offsets: [json_encode(after)] after, [json_encode(lying_offsets)] before.")

	// A blow through apply_damage flinches; burning (no attacker, no direction) does not.
	target.gun_feel_flinch_cooldown = 0
	target.apply_damage(5, BURN)
	TEST_ASSERT_EQUAL(target.gun_feel_flinch_cooldown, 0, "Damage with no attacker or direction should not flinch.")
	target.apply_damage(10, BRUTE, attack_direction = WEST)
	TEST_ASSERT(target.gun_feel_flinch_cooldown > world.time, "A blow from a direction should flinch.")

/// Troopers bleed when shot, and the blood doesn't hurt or kill them.
/datum/unit_test/voidcrew_gun_feel_npc_blood
/datum/unit_test/voidcrew_gun_feel_npc_blood/Run()
	var/mob/living/basic/trooper/syndicate/trooper = allocate(/mob/living/basic/trooper/syndicate)
	TEST_ASSERT_EQUAL(trooper.blood_volume, 560, "Troopers should have a normal blood volume (BLOOD_VOLUME_NORMAL).")
	for(var/i in 1 to 10)
		trooper.Life(2, i)
	TEST_ASSERT_EQUAL(trooper.stat, CONSCIOUS, "A trooper's blood should not knock it out.")
	TEST_ASSERT_EQUAL(trooper.blood_volume, 560, "A trooper should not lose blood over time.")
	TEST_ASSERT_EQUAL(trooper.health, trooper.maxHealth, "A trooper's blood should not hurt it.")

	var/obj/projectile/bullet/c9mm/bullet = allocate(/obj/projectile/bullet/c9mm)
	trooper.create_projectile_hit_effects(bullet, BODY_ZONE_CHEST, 0)
	TEST_ASSERT_NOTNULL(locate(/obj/effect/temp_visual/dir_setting/bloodsplatter) in get_turf(trooper), "A shot trooper should splatter blood.")

	var/mob/living/basic/viscerator/robot = allocate(/mob/living/basic/viscerator)
	TEST_ASSERT_EQUAL(robot.blood_volume, 0, "Machines should not get blood.")

/// Bullets pick an impact sound from what they hit.
/datum/unit_test/voidcrew_gun_feel_surfaces
/datum/unit_test/voidcrew_gun_feel_surfaces/Run()
	TEST_ASSERT_EQUAL(gun_feel_surface_of(allocate(/mob/living/carbon/human/consistent)), "flesh", "People should sound like flesh.")
	TEST_ASSERT_EQUAL(gun_feel_surface_of(allocate(/obj/structure/window)), "glass", "Windows should sound like glass.")
	TEST_ASSERT_EQUAL(gun_feel_surface_of(allocate(/obj/structure/table/wood)), "wood", "Wooden tables should sound like wood.")
	TEST_ASSERT_EQUAL(gun_feel_surface_of_type(/turf/closed/wall), "metal", "Plain walls should sound like metal.")
	TEST_ASSERT_EQUAL(gun_feel_surface_of_type(/turf/closed/mineral/random), "stone", "Rock should sound like stone.")
	TEST_ASSERT_EQUAL(gun_feel_surface_of_type(/turf/closed/mineral/snowmountain), "snow", "Snowy rock should sound like snow.")

	var/obj/projectile/bullet/c9mm/round = allocate(/obj/projectile/bullet/c9mm)
	TEST_ASSERT_EQUAL(round.icon_state, "gauss", "Bullets should draw the streak.")
	TEST_ASSERT_NULL(round.hitsound, "Bullets should leave their hit sound to gun_feel.")
	TEST_ASSERT_NULL(round.hitsound_wall, "Bullets should not ricochet-ping off walls any more.")

/// Powder guns play their shots at the recorded pitch with Shiptest's recordings; lasers keep a small spread.
/datum/unit_test/voidcrew_gun_feel_sounds
/datum/unit_test/voidcrew_gun_feel_sounds/Run()
	var/obj/item/gun/ballistic/automatic/pistol/pistol = allocate(/obj/item/gun/ballistic/automatic/pistol)
	TEST_ASSERT(!pistol.vary_fire_sound, "Powder guns should not vary their shot's pitch.")
	TEST_ASSERT_EQUAL("[pistol.fire_sound]", "voidcrew/modules/gun_feel/sound/pistol/shot.ogg", "The pistol should use the swapped pistol shot.")
	TEST_ASSERT_NULL(pistol.gun_feel_fire_frequency(), "A powder gun should play its shot as recorded.")

	var/obj/item/gun/ballistic/automatic/wt550/rifle = allocate(/obj/item/gun/ballistic/automatic/wt550)
	TEST_ASSERT_EQUAL("[rifle.load_sound]", "voidcrew/modules/gun_feel/sound/rifle/ar_reload.ogg", "Long automatics should use the rifle reload.")

	var/obj/item/gun/energy/laser/laser = allocate(/obj/item/gun/energy/laser)
	TEST_ASSERT(laser.vary_fire_sound, "Energy weapons keep their pitch spread.")
	var/frequency = laser.gun_feel_fire_frequency()
	TEST_ASSERT(frequency >= 0.9 && frequency <= 1.1, "Energy pitch spread should be narrow, got [frequency].")

/// Casings on a floor lie at an angle; a held casing stands straight.
/datum/unit_test/voidcrew_gun_feel_casing_rest
/datum/unit_test/voidcrew_gun_feel_casing_rest/Run()
	var/mob/living/carbon/human/consistent/holder = allocate(/mob/living/carbon/human/consistent)
	var/obj/item/ammo_casing/c9mm/casing = allocate(/obj/item/ammo_casing/c9mm)
	TEST_ASSERT(holder.put_in_hands(casing), "The holder could not pick up the casing.")
	TEST_ASSERT(gun_feel_same_matrix(casing.transform, matrix()), "A held casing should stand straight.")
	holder.dropItemToGround(casing)
	TEST_ASSERT(isturf(casing.loc), "The casing should be on the floor.")
	var/matrix/resting = casing.transform
	// A rotation keeps a = e and b = -d, and its scale stays 1.
	TEST_ASSERT(abs(resting.a - resting.e) < 0.001 && abs(resting.b + resting.d) < 0.001 && abs(resting.a * resting.a + resting.b * resting.b - 1) < 0.001, "A dropped casing should only be turned, not scaled or skewed.")
