// Hyperviolence blood part: directional spray, growing pools, zero-G floating blood.
// Test files compile before voidcrew\_DEFINES and the module's own defines, so the icon paths and
// the count of floating states are spelled out here.
// The test room is five floor tiles square with walls along its west and south edges; the
// bottom-left floor tile has a wall to its west and to its south.

/// The art the blood part draws from has every state the code asks for.
/datum/unit_test/hv_blood_icons/Run()
	var/list/spray_states = icon_states('voidcrew/modules/hyperviolence/blood/icons/blood_spray.dmi')
	for(var/state in list("squirt_greyscale", "splatter_greyscale", "splatterbloodalt_greyscale"))
		TEST_ASSERT(state in spray_states, "blood_spray.dmi has no [state] state")
	var/list/pool_states = icon_states('voidcrew/modules/hyperviolence/blood/icons/blood_pool.dmi')
	for(var/tier in 1 to length(GLOB.hv_blood_pool_thresholds))
		for(var/variant in 1 to 3)
			TEST_ASSERT("pool[tier]_[variant]" in pool_states, "blood_pool.dmi has no pool[tier]_[variant] state")
	var/list/float_states = icon_states('voidcrew/modules/hyperviolence/blood/icons/blood_weightless.dmi')
	for(var/variant in 1 to 12)
		TEST_ASSERT("float[variant]" in float_states, "blood_weightless.dmi has no float[variant] state")

/// One spray line: a streak then a splash along the floor, blood DNA on both, one throw per window,
/// and a second throw over the same tiles turns the decals instead of stacking new ones.
/datum/unit_test/hv_blood_spray_line/Run()
	var/mob/living/carbon/human/victim = allocate(/mob/living/carbon/human/consistent)
	var/turf/streak_turf = get_step(run_loc_floor_bottom_left, EAST)
	var/turf/splash_turf = get_step(streak_turf, EAST)

	TEST_ASSERT(victim.hv_blood_spray(EAST, 2), "A bleeder could not spray")
	var/obj/effect/decal/cleanable/blood/hv_spray/streak/streak = locate() in streak_turf
	var/obj/effect/decal/cleanable/blood/hv_spray/splash
	for(var/obj/effect/decal/cleanable/blood/hv_spray/candidate in splash_turf)
		if(candidate.type == /obj/effect/decal/cleanable/blood/hv_spray)
			splash = candidate
	TEST_ASSERT_NOTNULL(streak, "The spray left no streak on the first tile")
	TEST_ASSERT_NOTNULL(splash, "The spray left no splash on the last tile")
	TEST_ASSERT_EQUAL(streak.dir, EAST, "The streak does not face the way the blood flew")
	TEST_ASSERT_EQUAL(splash.dir, EAST, "The splash does not face the way the blood flew")
	var/list/victim_dna = victim.get_blood_dna_list()
	for(var/dna_key in victim_dna)
		TEST_ASSERT(dna_key in GET_ATOM_BLOOD_DNA(streak), "The streak carries no DNA from the bleeder")
		TEST_ASSERT(dna_key in GET_ATOM_BLOOD_DNA(splash), "The splash carries no DNA from the bleeder")
	TEST_ASSERT(!isnull(streak.color), "The streak was not tinted")
	TEST_ASSERT(!streak.can_bloodcrawl_in(), "A thin streak of blood can be crawled into")

	TEST_ASSERT(!victim.hv_blood_spray(EAST, 2), "A mob sprayed twice inside one window")
	TEST_ASSERT(victim.hv_blood_spray(EAST, 4), "A stronger spray inside the window was refused")
	victim.hv_blood_spray_until = 0
	TEST_ASSERT(victim.hv_blood_spray(EAST, 2), "A spray after the window was refused")
	var/floor_sprays = 0
	for(var/obj/effect/decal/cleanable/blood/hv_spray/found in streak_turf)
		if(!istype(found, /obj/effect/decal/cleanable/blood/hv_spray/wall))
			floor_sprays++
	TEST_ASSERT_EQUAL(floor_sprays, 1, "Repeat sprays stacked decals on one tile")
	floor_sprays = 0
	for(var/obj/effect/decal/cleanable/blood/hv_spray/found in splash_turf)
		if(!istype(found, /obj/effect/decal/cleanable/blood/hv_spray/wall))
			floor_sprays++
	TEST_ASSERT_EQUAL(floor_sprays, 1, "Repeat sprays of different strength stacked decals on one tile")

/// A wall in the way takes the splash, drawn from the tile in front of it.
/datum/unit_test/hv_blood_spray_wall/Run()
	var/mob/living/carbon/human/victim = allocate(/mob/living/carbon/human/consistent)
	var/turf/start = run_loc_floor_bottom_left
	TEST_ASSERT(victim.hv_blood_spray(WEST, 2), "A bleeder with a wall at its back could not spray")
	var/obj/effect/decal/cleanable/blood/hv_spray/wall/smear = locate() in start
	TEST_ASSERT_NOTNULL(smear, "Nothing was left on the wall")
	TEST_ASSERT_EQUAL(smear.pixel_x, -32, "The smear is not drawn onto the wall to the west")
	TEST_ASSERT_EQUAL(smear.pixel_y, 0, "The smear is offset on the wrong axis")
	TEST_ASSERT_EQUAL(smear.dir, WEST, "The smear does not face the wall")
	TEST_ASSERT_NULL(locate(/obj/effect/decal/cleanable/blood/hv_spray/streak) in start, "A floor streak was laid where the wall is")

/// Anyone standing in the line is drenched and stops it.
/datum/unit_test/hv_blood_spray_drench/Run()
	var/mob/living/carbon/human/victim = allocate(/mob/living/carbon/human/consistent)
	var/turf/streak_turf = get_step(run_loc_floor_bottom_left, EAST)
	var/turf/bystander_turf = get_step(streak_turf, EAST)
	var/turf/beyond_turf = get_step(bystander_turf, EAST)
	var/mob/living/carbon/human/bystander = allocate(/mob/living/carbon/human/consistent, bystander_turf)
	TEST_ASSERT_EQUAL(GET_ATOM_BLOOD_DNA_LENGTH(bystander), 0, "The bystander started out bloody")
	victim.hv_blood_spray(EAST, 4)
	TEST_ASSERT(GET_ATOM_BLOOD_DNA_LENGTH(bystander) > 0, "The bystander in the line was not drenched")
	TEST_ASSERT_NULL(locate(/obj/effect/decal/cleanable/blood/hv_spray) in beyond_turf, "The spray went through the bystander")
	TEST_ASSERT_NOTNULL(locate(/obj/effect/decal/cleanable/blood/hv_spray/streak) in streak_turf, "The spray left no streak before the bystander")

/// Big brute hits spray, small ones do not, and a hit tg already sprayed for is not sprayed twice.
/datum/unit_test/hv_blood_heavy_hit/Run()
	var/mob/living/carbon/human/victim = allocate(/mob/living/carbon/human/consistent)
	var/turf/east = get_step(run_loc_floor_bottom_left, EAST)
	var/obj/item/bodypart/chest = victim.get_bodypart(BODY_ZONE_CHEST)

	// The damage signal is wired up on every mob, and remembers which way a brute hit travelled.
	victim.apply_damage(5, BRUTE, BODY_ZONE_CHEST, attack_direction = EAST)
	TEST_ASSERT_EQUAL(victim.hv_blood_hit_dir, EAST, "The damage signal did not reach the blood part")
	TEST_ASSERT_NULL(locate(/obj/effect/decal/cleanable/blood/hv_spray) in east, "A light hit sprayed blood")

	// The rest calls the handler directly, so wounds from a real hit cannot get in the way.
	victim.hv_blood_tg_spray_tick = world.time
	victim.hv_blood_on_damaged(victim, 40, BRUTE, chest, 0, 0, 0, NONE, EAST, null, TRUE)
	TEST_ASSERT_NULL(locate(/obj/effect/decal/cleanable/blood/hv_spray) in east, "A hit sprayed on top of tg's own spray")

	victim.hv_blood_tg_spray_tick = -1
	victim.hv_blood_on_damaged(victim, 14, BURN, chest, 0, 0, 0, NONE, EAST, null, TRUE)
	TEST_ASSERT_NULL(locate(/obj/effect/decal/cleanable/blood/hv_spray) in east, "Burn damage sprayed blood")
	victim.hv_blood_on_damaged(victim, 40, BRUTE, chest, 0, 0, 0, NONE, null, null, TRUE)
	TEST_ASSERT_NULL(locate(/obj/effect/decal/cleanable/blood/hv_spray) in east, "A hit with no direction sprayed blood")

	victim.hv_blood_on_damaged(victim, 40, BRUTE, chest, 0, 0, 0, NONE, EAST, null, TRUE)
	TEST_ASSERT_NOTNULL(locate(/obj/effect/decal/cleanable/blood/hv_spray) in east, "A heavy hit did not spray")

/// A limb torn off throws blood the way the blow that took it travelled.
/datum/unit_test/hv_blood_dismember_spray/Run()
	var/mob/living/carbon/human/victim = allocate(/mob/living/carbon/human/consistent)
	var/turf/east = get_step(run_loc_floor_bottom_left, EAST)
	victim.hv_blood_hit_dir = EAST
	victim.hv_blood_hit_time = world.time
	var/obj/item/bodypart/arm = victim.get_bodypart(BODY_ZONE_L_ARM)
	TEST_ASSERT_NOTNULL(arm, "The test human has no left arm")
	TEST_ASSERT(arm.dismember(), "The arm would not come off")
	TEST_ASSERT_NOTNULL(locate(/obj/effect/decal/cleanable/blood/hv_spray) in east, "A torn-off limb threw no blood")

/// Splatters step up to bigger pools as they fill, one decal per tile, and never step back down.
/datum/unit_test/hv_blood_pool_growth/Run()
	var/turf/spot = run_loc_floor_bottom_left
	var/obj/effect/decal/cleanable/blood/pool = allocate(/obj/effect/decal/cleanable/blood, spot)
	TEST_ASSERT_EQUAL(pool.hv_pool_tier, 0, "A fresh splatter was already a pool")
	var/expected_tier = 0
	for(var/step in list(45, 50, 60, 60))
		pool.adjust_bloodiness(step)
		expected_tier++
		TEST_ASSERT_EQUAL(pool.hv_pool_tier, expected_tier, "Bloodiness [pool.bloodiness] did not make a tier [expected_tier] pool")
		TEST_ASSERT_EQUAL(pool.icon, 'voidcrew/modules/hyperviolence/blood/icons/blood_pool.dmi', "A tier [expected_tier] pool does not use the pool art")
		TEST_ASSERT(findtext(pool.icon_state, "pool[expected_tier]_") == 1, "A tier [expected_tier] pool shows [pool.icon_state]")
	pool.adjust_bloodiness(-150)
	TEST_ASSERT_EQUAL(pool.hv_pool_tier, 4, "A pool shrank when it lost blood")
	var/pools = 0
	for(var/obj/effect/decal/cleanable/blood/found in spot)
		pools++
	TEST_ASSERT_EQUAL(pools, 1, "The pool is not the only blood on its tile")

/// A bleeder who stays put adds to the splatter under them; one who moves does not.
/datum/unit_test/hv_blood_pool_feed/Run()
	var/turf/spot = run_loc_floor_bottom_left
	var/obj/effect/decal/cleanable/blood/pool = allocate(/obj/effect/decal/cleanable/blood, spot)
	var/mob/living/carbon/human/bleeder = allocate(/mob/living/carbon/human/consistent, spot)
	var/before = pool.bloodiness
	bleeder.bleed(10)
	TEST_ASSERT_EQUAL(pool.bloodiness, before, "A bleeder's first bleed on a tile fed the pool")
	bleeder.bleed(10)
	TEST_ASSERT_EQUAL(pool.bloodiness, before + 10, "A standing bleeder did not feed the pool")
	bleeder.forceMove(get_step(spot, EAST))
	bleeder.bleed(10)
	TEST_ASSERT_EQUAL(pool.bloodiness, before + 10, "A bleeder who had moved fed the old pool")

/// Blood where nothing pulls it down hangs in the air, does not dry, and falls when gravity returns.
/datum/unit_test/hv_blood_weightless
	var/turf/weightless_turf

/datum/unit_test/hv_blood_weightless/Destroy()
	if(weightless_turf)
		weightless_turf.force_no_gravity = FALSE
	return ..()

/datum/unit_test/hv_blood_weightless/Run()
	weightless_turf = run_loc_floor_bottom_left
	weightless_turf.force_no_gravity = TRUE
	var/obj/effect/decal/cleanable/blood/bead = allocate(/obj/effect/decal/cleanable/blood, weightless_turf)
	sleep(0.5 SECONDS)
	TEST_ASSERT(bead.hv_floating, "Blood in no gravity did not float")
	TEST_ASSERT(bead in GLOB.hv_floating_blood, "Floating blood is not tracked")
	TEST_ASSERT(!bead.can_dry, "Floating blood can dry")
	TEST_ASSERT(!(bead.datum_flags & DF_ISPROCESSING), "Floating blood is still drying out")
	TEST_ASSERT_EQUAL(bead.icon, 'voidcrew/modules/hyperviolence/blood/icons/blood_weightless.dmi', "Floating blood does not use the floating art")
	TEST_ASSERT(!bead.can_bloodcrawl_in(), "Floating blood can be crawled into")

	// Nothing has changed, so nothing falls.
	hv_blood_recheck_floating()
	TEST_ASSERT(bead.hv_floating, "Blood fell with no gravity to pull it down")

	weightless_turf.force_no_gravity = FALSE
	hv_blood_recheck_floating()
	TEST_ASSERT(!bead.hv_floating, "Blood did not fall when gravity came back")
	TEST_ASSERT(!(bead in GLOB.hv_floating_blood), "Fallen blood is still tracked as floating")
	TEST_ASSERT(bead.can_dry, "Fallen blood cannot dry")
	TEST_ASSERT(bead.datum_flags & DF_ISPROCESSING, "Fallen blood is not drying out")
	TEST_ASSERT_EQUAL(bead.icon, initial(bead.icon), "Fallen blood still shows the floating art")
	TEST_ASSERT_EQUAL(bead.pixel_y, 0, "Fallen blood is still raised")

/// Floating blood does not run into blood already lying there, and joins it when it falls.
/datum/unit_test/hv_blood_weightless_merge
	var/turf/weightless_turf

/datum/unit_test/hv_blood_weightless_merge/Destroy()
	if(weightless_turf)
		weightless_turf.force_no_gravity = FALSE
	return ..()

/datum/unit_test/hv_blood_weightless_merge/Run()
	weightless_turf = run_loc_floor_bottom_left
	var/obj/effect/decal/cleanable/blood/lying = allocate(/obj/effect/decal/cleanable/blood, weightless_turf)
	var/before = lying.bloodiness
	weightless_turf.force_no_gravity = TRUE
	var/obj/effect/decal/cleanable/blood/bead = allocate(/obj/effect/decal/cleanable/blood, weightless_turf)
	TEST_ASSERT(!QDELETED(bead), "Floating blood merged into blood lying on the floor")
	sleep(0.5 SECONDS)
	TEST_ASSERT(bead.hv_floating, "New blood in no gravity did not float over old blood")
	TEST_ASSERT(!lying.hv_floating, "Blood already on the floor lifted off")

	weightless_turf.force_no_gravity = FALSE
	hv_blood_recheck_floating()
	TEST_ASSERT(QDELETED(bead), "Fallen blood did not join the blood already there")
	TEST_ASSERT_EQUAL(lying.bloodiness, before + BLOOD_AMOUNT_PER_DECAL, "The blood already there did not take on the fallen blood")

/// In no gravity a bleed leaves floating beads rather than a drip, and a mob getting gravity back lets them fall.
/datum/unit_test/hv_blood_weightless_bleed
	var/turf/weightless_turf

/datum/unit_test/hv_blood_weightless_bleed/Destroy()
	if(weightless_turf)
		weightless_turf.force_no_gravity = FALSE
	return ..()

/datum/unit_test/hv_blood_weightless_bleed/Run()
	weightless_turf = run_loc_floor_bottom_left
	weightless_turf.force_no_gravity = TRUE
	var/mob/living/carbon/human/bleeder = allocate(/mob/living/carbon/human/consistent, weightless_turf)
	var/datum/blood_type/blood_type = bleeder.get_bloodtype()
	var/obj/effect/decal/cleanable/blood/left_behind = blood_type.make_blood_splatter(bleeder, weightless_turf, TRUE)
	TEST_ASSERT_NOTNULL(left_behind, "A bleed in no gravity left nothing behind")
	TEST_ASSERT(!istype(left_behind, /obj/effect/decal/cleanable/blood/drip), "A bleed in no gravity left a drip with nothing to fall onto")
	sleep(0.5 SECONDS)
	TEST_ASSERT(left_behind.hv_floating, "Blood from a bleed in no gravity did not float")

	// Gravity returns; the mob standing in it is what announces that.
	weightless_turf.force_no_gravity = FALSE
	bleeder.refresh_gravity()
	sleep(0.5 SECONDS)
	TEST_ASSERT(!left_behind.hv_floating, "Floating blood did not fall when a mob's gravity came back")
