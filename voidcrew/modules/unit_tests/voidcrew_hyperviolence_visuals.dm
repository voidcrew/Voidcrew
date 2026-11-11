/**
 * Hyperviolence visuals (voidcrew/modules/hyperviolence/visuals/).
 *
 * A headless world draws nothing, so these check what the server keeps: every animation leaves the
 * transform and pixel offsets where they were, held poses let go when the body moves, stands up or
 * is revived, and nothing is left behind (components, fling marks). Test files compile before the
 * module's defines, so tags and tunables are written out, each with the define's name.
 */

/// Shared helpers; not a test itself
/datum/unit_test/voidcrew_hv_visuals
	abstract_type = /datum/unit_test/voidcrew_hv_visuals

/// The floor `dx`, `dy` tiles from the test room's bottom-left corner
/datum/unit_test/voidcrew_hv_visuals/proc/spot(dx, dy)
	return locate(run_loc_floor_bottom_left.x + dx, run_loc_floor_bottom_left.y + dy, run_loc_floor_bottom_left.z)

/// Whether two transforms are the same (null counts as the identity)
/datum/unit_test/voidcrew_hv_visuals/proc/same_matrix(matrix/first, matrix/second)
	first = first ? matrix(first) : matrix()
	second = second ? matrix(second) : matrix()
	return abs(first.a - second.a) < 0.001 && abs(first.b - second.b) < 0.001 && abs(first.c - second.c) < 0.001 \
		&& abs(first.d - second.d) < 0.001 && abs(first.e - second.e) < 0.001 && abs(first.f - second.f) < 0.001

/// Where `thing` is drawn at rest: its pixel offsets and transform
/datum/unit_test/voidcrew_hv_visuals/proc/rest_of(atom/movable/thing)
	return list(thing.pixel_x, thing.pixel_y, thing.pixel_w, thing.pixel_z, matrix(thing.transform))

/// Fails unless `thing` is drawn exactly as `rest` says
/datum/unit_test/voidcrew_hv_visuals/proc/check_rest(atom/movable/thing, list/rest, what)
	if(thing.pixel_x != rest[1] || thing.pixel_y != rest[2] || thing.pixel_w != rest[3] || thing.pixel_z != rest[4])
		TEST_FAIL("[what] left [thing]'s pixel offsets changed: x [thing.pixel_x] y [thing.pixel_y] w [thing.pixel_w] z [thing.pixel_z], expected [rest[1]] [rest[2]] [rest[3]] [rest[4]]")
	if(!same_matrix(thing.transform, rest[5]))
		TEST_FAIL("[what] left [thing]'s transform changed")

/// Fails unless the last of `steps` (hv_vis_play() steps) is where `thing` is drawn now
/datum/unit_test/voidcrew_hv_visuals/proc/check_ends_at_rest(atom/movable/thing, list/steps, what)
	if(!length(steps))
		TEST_FAIL("[what] has no steps")
		return
	var/list/last = steps[length(steps)]
	if(last[1] != thing.pixel_w || last[2] != thing.pixel_z || !same_matrix(last[3], thing.transform))
		TEST_FAIL("[what] does not end where the body stands")

/// Fails unless the last of `steps` (hv_vis_play_over() steps) is where `thing` is drawn now
/datum/unit_test/voidcrew_hv_visuals/proc/check_over_ends_at_rest(atom/movable/thing, list/steps, what)
	var/list/last = steps[length(steps)]
	if(last[1] != thing.pixel_y || !same_matrix(last[2], thing.transform))
		TEST_FAIL("[what] does not end where the body lies")

/// How many held poses `body` has
/datum/unit_test/voidcrew_hv_visuals/proc/holds(mob/living/body)
	return length(body.GetComponents(/datum/component/hv_motion_hold))

/// Hits of every size leave the body where it stood, standing or lying, and a tick's pellets add up to one blow
/datum/unit_test/voidcrew_hv_visuals/flinch

/datum/unit_test/voidcrew_hv_visuals/flinch/Run()
	var/mob/living/carbon/human/consistent/victim = allocate(/mob/living/carbon/human/consistent, spot(2, 2))
	var/list/standing = rest_of(victim)
	victim.apply_damage(25, BRUTE, BODY_ZONE_CHEST, wound_bonus = CANT_WOUND, attack_direction = EAST)
	check_rest(victim, standing, "A pistol-sized hit")
	victim.apply_damage(20, BRUTE, BODY_ZONE_HEAD, wound_bonus = CANT_WOUND, attack_direction = WEST)
	check_rest(victim, standing, "A hit to the head")
	TEST_ASSERT_EQUAL(victim.hv_vis_hit_zone, BODY_ZONE_HEAD, "The head hit was not noted on the head")
	victim.fully_heal(HEAL_ALL)
	standing = rest_of(victim)
	var/before = victim.hv_vis_hit_time == world.time ? victim.hv_vis_hit_damage : 0
	for(var/pellet in 1 to 8)
		victim.apply_damage(7, BRUTE, BODY_ZONE_CHEST, wound_bonus = CANT_WOUND, attack_direction = NORTH)
	check_rest(victim, standing, "A shotgun's pellets")
	TEST_ASSERT(victim.hv_vis_hit_damage - before >= 56, "A tick's pellets were not added up into one blow (got [victim.hv_vis_hit_damage - before])")
	TEST_ASSERT_EQUAL(victim.hv_vis_resolving, 0, "A hit was left counted as still being resolved")

	victim.fully_heal(HEAL_ALL)
	victim.Paralyze(10 SECONDS)
	TEST_ASSERT_EQUAL(victim.body_position, LYING_DOWN, "Test fixture: the victim did not lie down")
	var/list/lying = rest_of(victim)
	victim.apply_damage(30, BRUTE, BODY_ZONE_CHEST, wound_bonus = CANT_WOUND, attack_direction = EAST)
	check_rest(victim, lying, "A hit on a body lying down")
	victim.apply_damage(30, STAMINA, BODY_ZONE_CHEST, attack_direction = SOUTH)
	check_rest(victim, lying, "A stamina hit")

/// Every animation's steps end where the body is, standing and lying
/datum/unit_test/voidcrew_hv_visuals/steps_end_at_rest

/datum/unit_test/voidcrew_hv_visuals/steps_end_at_rest/Run()
	var/mob/living/carbon/human/consistent/body = allocate(/mob/living/carbon/human/consistent, spot(2, 2))
	for(var/pass in 1 to 2)
		var/state = pass == 1 ? "standing" : "lying"
		for(var/hit_dir in GLOB.alldirs)
			check_ends_at_rest(body, body.hv_vis_flinch_steps(25, hit_dir), "A flinch ([state], [dir2text(hit_dir)])")
			check_ends_at_rest(body, body.hv_vis_flinch_steps(60, hit_dir, TRUE, 1.5), "A held stagger to the head ([state], [dir2text(hit_dir)])")
			check_ends_at_rest(body, body.hv_vis_slide_steps(hit_dir, 30, 1.5), "A death slide ([state], [dir2text(hit_dir)])")
		for(var/zone in list(BODY_ZONE_L_ARM, BODY_ZONE_R_ARM, BODY_ZONE_L_LEG, BODY_ZONE_R_LEG))
			check_ends_at_rest(body, body.hv_vis_lurch_steps(zone), "A lurch ([state], [zone])")
			check_ends_at_rest(body, body.hv_vis_limp_steps(zone), "A limping step ([state], [zone])")
		check_ends_at_rest(body, body.hv_vis_curl_steps(3), "A burned curl ([state])")
		check_ends_at_rest(body, body.hv_vis_twitch_steps(4, 4), "Twitches ([state])")
		body.Paralyze(10 SECONDS)

	// The fall over-rides end where tg laid the body down.
	body.death()
	TEST_ASSERT_EQUAL(body.body_position, LYING_DOWN, "Test fixture: the body is not lying down")
	check_over_ends_at_rest(body, body.hv_vis_kneel_collapse_steps(), "The bleed-out kneel")
	check_over_ends_at_rest(body, body.hv_vis_hold_then_fall_steps(3, 2), "The held fall")
	var/list/upright = body.hv_vis_upright()
	TEST_ASSERT(same_matrix(upright[2], matrix()), "The pose a body stood in before it fell is not upright")

/// A body killed by a blow from the side falls away from it, lies exactly as tg lays it, slides and
/// twitches as held poses, and is drawn as it should be once revived
/datum/unit_test/voidcrew_hv_visuals/death_falls_away

/datum/unit_test/voidcrew_hv_visuals/death_falls_away/Run()
	for(var/blow_dir in list(EAST, WEST))
		var/mob/living/carbon/human/consistent/victim = allocate(/mob/living/carbon/human/consistent, spot(2, 2))
		victim.adjustToxLoss(185, updating_health = FALSE, forced = TRUE)
		TEST_ASSERT_EQUAL(victim.body_position, STANDING_UP, "Test fixture: the victim fell before the killing blow")
		victim.apply_damage(25, BRUTE, BODY_ZONE_CHEST, wound_bonus = CANT_WOUND, attack_direction = blow_dir)
		TEST_ASSERT_EQUAL(victim.stat, DEAD, "Test fixture: the killing blow did not kill")
		// LYING_ANGLE_EAST 90 (head to the east), LYING_ANGLE_WEST 270
		TEST_ASSERT_EQUAL(victim.lying_angle, blow_dir == EAST ? 90 : 270, "A body killed by a blow going [dir2text(blow_dir)] did not fall that way")
		var/matrix/laid = matrix()
		laid.Turn(victim.lying_angle)
		TEST_ASSERT(same_matrix(victim.transform, laid), "The death animations changed how the body lies")
		TEST_ASSERT_EQUAL(victim.pixel_w, 0, "The death animations moved the body sideways")
		TEST_ASSERT_EQUAL(victim.pixel_z, 0, "The death animations moved the body up or down")
		TEST_ASSERT(holds(victim) >= 1, "The death slide and twitches are not held")

		victim.revive(ADMIN_HEAL_ALL)
		TEST_ASSERT_EQUAL(victim.body_position, STANDING_UP, "Test fixture: the revived body did not stand")
		TEST_ASSERT_EQUAL(holds(victim), 0, "A held death pose outlived the revival")
		TEST_ASSERT(same_matrix(victim.transform, matrix()), "A revived body stands skewed")
		TEST_ASSERT_EQUAL(victim.pixel_y, 0, "A revived body stands too low")
		TEST_ASSERT_EQUAL(victim.pixel_w, 0, "A revived body stands off to the side")

/// The kind of death decides the fall
/datum/unit_test/voidcrew_hv_visuals/death_kinds

/datum/unit_test/voidcrew_hv_visuals/death_kinds/Run()
	// HV_VIS_DEATH_QUIET 0, _HIT 1, _HEADSHOT 2, _BURNED 3, _BLED_OUT 4, _EXECUTED 5
	var/mob/living/carbon/human/consistent/shot = allocate(/mob/living/carbon/human/consistent, spot(1, 1))
	shot.adjustToxLoss(185, updating_health = FALSE, forced = TRUE)
	shot.apply_damage(25, BRUTE, BODY_ZONE_HEAD, wound_bonus = CANT_WOUND, attack_direction = NORTH)
	TEST_ASSERT_EQUAL(shot.hv_vis_death_kind(), 2, "A head shot did not read as a head shot")
	var/matrix/laid = matrix()
	laid.Turn(shot.lying_angle)
	TEST_ASSERT(same_matrix(shot.transform, laid), "The head shot drop changed how the body lies")

	var/mob/living/carbon/human/consistent/burned = allocate(/mob/living/carbon/human/consistent, spot(3, 1))
	burned.adjustToxLoss(185, updating_health = FALSE, forced = TRUE)
	burned.apply_damage(25, BURN, BODY_ZONE_CHEST, wound_bonus = CANT_WOUND, attack_direction = WEST)
	TEST_ASSERT_EQUAL(burned.hv_vis_death_kind(), 3, "A burning blow did not read as burned")
	TEST_ASSERT(holds(burned) >= 1, "The burned curl is not held")
	laid = matrix()
	laid.Turn(burned.lying_angle)
	TEST_ASSERT(same_matrix(burned.transform, laid), "The curl changed how the body lies")
	burned.forceMove(spot(3, 2))
	TEST_ASSERT_EQUAL(holds(burned), 0, "Moving a curled body did not let the curl go")

	var/mob/living/carbon/human/consistent/drained = allocate(/mob/living/carbon/human/consistent, spot(1, 3))
	drained.blood_volume = 50
	drained.death()
	TEST_ASSERT_EQUAL(drained.hv_vis_death_kind(), 4, "A body out of blood did not read as bled out")
	laid = matrix()
	laid.Turn(drained.lying_angle)
	TEST_ASSERT(same_matrix(drained.transform, laid), "The bleed-out kneel left the body standing")

	var/mob/living/carbon/human/consistent/quiet = allocate(/mob/living/carbon/human/consistent, spot(3, 3))
	quiet.death()
	TEST_ASSERT_EQUAL(quiet.hv_vis_death_kind(), 0, "A death with nothing behind it read as something")
	quiet.hv_vis_execution_time = world.time
	TEST_ASSERT_EQUAL(quiet.hv_vis_death_kind(), 5, "An execution did not read as one")

/// A heavy killing blow slides the corpse a whole tile, never into a wall or a standing person
/datum/unit_test/voidcrew_hv_visuals/full_slide

/datum/unit_test/voidcrew_hv_visuals/full_slide/Run()
	// The bottom-left floor has walls to its west and south.
	var/mob/living/carbon/human/consistent/corpse = allocate(/mob/living/carbon/human/consistent, spot(0, 0))
	corpse.death()
	TEST_ASSERT(!corpse.hv_vis_can_slide_tile(WEST), "A corpse could slide into a wall")
	TEST_ASSERT(!corpse.hv_vis_can_slide_tile(SOUTH), "A corpse could slide into a wall")
	TEST_ASSERT(corpse.hv_vis_can_slide_tile(EAST), "A corpse could not slide onto open floor")
	var/mob/living/carbon/human/consistent/bystander = allocate(/mob/living/carbon/human/consistent, spot(1, 0))
	TEST_ASSERT(!corpse.hv_vis_can_slide_tile(EAST), "A corpse could slide into someone standing there")
	qdel(bystander)
	corpse.hv_vis_slide_tile(EAST)
	TEST_ASSERT_EQUAL(get_turf(corpse), spot(1, 0), "The corpse did not slide a tile")

	// Through a real killing blow, next tick
	var/mob/living/carbon/human/consistent/victim = allocate(/mob/living/carbon/human/consistent, spot(1, 2))
	victim.adjustToxLoss(185, updating_health = FALSE, forced = TRUE)
	victim.apply_damage(50, BRUTE, BODY_ZONE_CHEST, wound_bonus = CANT_WOUND, attack_direction = EAST)
	TEST_ASSERT_EQUAL(victim.stat, DEAD, "Test fixture: the killing blow did not kill")
	sleep(3)
	TEST_ASSERT_EQUAL(get_turf(victim), spot(2, 2), "A heavy killing blow did not slide the body a tile along it")

	// A living body is never slid
	var/mob/living/carbon/human/consistent/alive = allocate(/mob/living/carbon/human/consistent, spot(3, 3))
	alive.hv_vis_slide_tile(EAST)
	TEST_ASSERT_EQUAL(get_turf(alive), spot(3, 3), "A living body was slid")

/// A severed arm flies the way the blow went, tumbling, streaks blood, and lands with nothing left on it
/datum/unit_test/voidcrew_hv_visuals/tumble

/datum/unit_test/voidcrew_hv_visuals/tumble/Run()
	var/mob/living/carbon/human/consistent/victim = allocate(/mob/living/carbon/human/consistent, spot(1, 1))
	var/list/standing = rest_of(victim)
	victim.hv_blood_hit_dir = EAST
	victim.hv_blood_hit_time = world.time
	var/obj/item/bodypart/arm = victim.get_bodypart(BODY_ZONE_L_ARM)
	var/turf/start = get_turf(victim)
	TEST_ASSERT(arm.dismember(BRUTE, TRUE, WOUND_SLASH), "Test fixture: the arm did not come off")
	TEST_ASSERT_NULL(arm.hv_vis_tumble, "The flight did not use up the arm's fling")
	TEST_ASSERT_NULL(arm.throwing, "The severed arm was thrown with tg's throw")
	var/datum/component/hv_tumble/tumble = arm.GetComponent(/datum/component/hv_tumble)
	TEST_ASSERT_NOTNULL(tumble, "A severed arm did not tumble")
	TEST_ASSERT_EQUAL(tumble.fling_dir, EAST, "The arm was not flung the way the blow went")
	// Its first step waits a tick: stepped at once, it would first be seen a tile from the body
	TEST_ASSERT_EQUAL(get_turf(arm), start, "The arm left the body's tile in the tick it came off")
	TEST_ASSERT_NOTNULL(tumble.from, "The arm's flight does not start from its place on the body")
	check_rest(victim, standing, "Losing an arm")
	TEST_ASSERT_NOTNULL(victim.get_filter("hv_vis_flash"), "Losing an arm got no hit-stop flash")
	// Wait for the landing rather than a fixed time: a busy server flies it slower.
	for(var/i in 1 to 50)
		if(!arm.GetComponent(/datum/component/hv_tumble))
			break
		sleep(1)
	TEST_ASSERT(isturf(arm.loc), "The arm did not land")
	TEST_ASSERT(arm.x > start.x && arm.y == start.y, "The arm did not fly the way the blow went")
	TEST_ASSERT_NULL(arm.GetComponent(/datum/component/hv_tumble), "The tumble outlived the landing")
	TEST_ASSERT_EQUAL(arm.pixel_w, 0, "The landed arm is drawn off to the side")
	TEST_ASSERT_EQUAL(arm.pixel_z, 0, "The landed arm is drawn in the air")
	TEST_ASSERT(same_matrix(arm.transform, matrix()), "The landed arm is left turned")
	TEST_ASSERT_NOTNULL(locate(/obj/effect/decal/cleanable/blood/hv_spray/streak) in start, "The arm left no blood along its way")

/// An arm cut from a body on the floor comes off turned as the body lies and ends as a loose arm lies; cut
/// from a body on its feet, or from one that went down this very tick, it comes off as it always did
/datum/unit_test/voidcrew_hv_visuals/tumble_off_the_floor

/datum/unit_test/voidcrew_hv_visuals/tumble_off_the_floor/Run()
	var/mob/living/carbon/human/consistent/victim = allocate(/mob/living/carbon/human/consistent, spot(1, 3))
	TEST_ASSERT_EQUAL(victim.hv_vis_lying_turn(), 0, "A body on its feet counts as turned")
	victim.Paralyze(10 SECONDS)
	TEST_ASSERT_EQUAL(victim.body_position, LYING_DOWN, "Test fixture: the body is not lying down")
	// Nobody has seen it fall yet: a part cut off it in the same tick starts as it stood
	TEST_ASSERT_EQUAL(victim.hv_vis_lying_turn(), 0, "A body counts as turned in the tick it goes down")
	sleep(world.tick_lag)
	if(victim.body_position == LYING_DOWN)
		victim.set_lying_angle(LYING_ANGLE_EAST)
	TEST_ASSERT_EQUAL(victim.hv_vis_lying_turn(), 90, "A body lying head east is not a quarter turn clockwise")
	victim.set_lying_angle(LYING_ANGLE_WEST)
	TEST_ASSERT_EQUAL(victim.hv_vis_lying_turn(), -90, "A body lying head west is not a quarter turn the other way")

	victim.hv_blood_hit_dir = EAST
	victim.hv_blood_hit_time = world.time
	var/obj/item/bodypart/arm = victim.get_bodypart(BODY_ZONE_L_ARM)
	TEST_ASSERT(arm.dismember(BRUTE, TRUE, WOUND_SLASH), "Test fixture: the arm did not come off")
	TEST_ASSERT_NULL(arm.hv_vis_fling_turn, "The flight did not use up the arm's turn")
	var/datum/component/hv_tumble/tumble = arm.GetComponent(/datum/component/hv_tumble)
	TEST_ASSERT_NOTNULL(tumble, "An arm cut from a body on the floor did not tumble")
	TEST_ASSERT_EQUAL(tumble.starts_turned, -90, "An arm cut from a body on the floor did not come off as it lay")
	// Its spin starts as it lay on the body, at once, and ends as the loose arm really lies
	var/list/pivot = arm.hv_vis_spin_pivot()
	var/list/steps = hv_vis_spin_steps(arm, 2, 3, 1, -90)
	var/list/first = steps[1]
	TEST_ASSERT_EQUAL(first[4], 0, "The spin of an arm cut from a body on the floor takes time to start as it lay")
	TEST_ASSERT(same_matrix(first[3], hv_vis_turned(matrix(arm.transform), -90, pivot[2], pivot[1])), "The spin of an arm cut from a body on the floor does not start as it lay")
	check_ends_at_rest(arm, steps, "The spin of an arm cut from a body on the floor")
	// Off a body on its feet the spin is the one it always was: whole turns, nothing before them
	TEST_ASSERT_EQUAL(length(hv_vis_spin_steps(arm, 2, 3, 1)), 6, "The spin of an arm cut from a body on its feet changed")
	for(var/i in 1 to 50)
		if(!arm.GetComponent(/datum/component/hv_tumble))
			break
		sleep(1)
	TEST_ASSERT_NULL(arm.GetComponent(/datum/component/hv_tumble), "The tumble outlived the landing")
	TEST_ASSERT(same_matrix(arm.transform, matrix()), "The landed arm is left turned")

/// A limb taken off by a blow flies the way that same blow travelled: tg severs it in the middle of the
/// hit, before the hit's damage is counted
/datum/unit_test/voidcrew_hv_visuals/sever_follows_blow

/datum/unit_test/voidcrew_hv_visuals/sever_follows_blow/Run()
	var/mob/living/carbon/human/consistent/victim = allocate(/mob/living/carbon/human/consistent, spot(2, 2))
	var/obj/item/bodypart/arm = victim.get_bodypart(BODY_ZONE_R_ARM)
	// Cut to the bone and broken, so tg's wound roll is certain to take it off
	arm.force_wound_upwards(/datum/wound/slash/flesh/critical)
	arm.force_wound_upwards(/datum/wound/blunt/bone/critical)
	victim.apply_damage(100, BRUTE, BODY_ZONE_R_ARM, wound_bonus = 50, sharpness = SHARP_EDGED, attack_direction = WEST)
	TEST_ASSERT_NULL(victim.get_bodypart(BODY_ZONE_R_ARM), "Test fixture: the blow did not take the arm off")
	var/datum/component/hv_tumble/tumble = arm.GetComponent(/datum/component/hv_tumble)
	TEST_ASSERT_NOTNULL(tumble, "The severed arm did not fly")
	TEST_ASSERT_EQUAL(tumble.fling_dir, WEST, "The arm did not fly the way the blow that took it off travelled")

/// A burst head's brain tumbles out and lands clean, and no organ keeps a fling mark
/datum/unit_test/voidcrew_hv_visuals/brain_tumble

/datum/unit_test/voidcrew_hv_visuals/brain_tumble/Run()
	var/mob/living/carbon/human/consistent/victim = allocate(/mob/living/carbon/human/consistent, spot(2, 0))
	var/obj/item/organ/brain/brain = victim.get_organ_slot(ORGAN_SLOT_BRAIN)
	var/list/obj/item/organ/head_organs = list()
	for(var/obj/item/organ/organ in victim.get_bodypart(BODY_ZONE_HEAD))
		head_organs += organ
	TEST_ASSERT(victim.hv_burst_head(NORTH), "Test fixture: the head did not burst")
	TEST_ASSERT_NOTNULL(brain.GetComponent(/datum/component/hv_tumble), "The brain did not tumble out")
	for(var/obj/item/organ/organ as anything in head_organs)
		if(!QDELETED(organ))
			TEST_ASSERT_NULL(organ.hv_vis_tumble, "[organ] kept its fling mark after the burst")
	TEST_ASSERT(!GLOB.hv_vis_arcing_gibs, "The burst left gibs arcing")
	for(var/i in 1 to 50)
		if(!brain.GetComponent(/datum/component/hv_tumble))
			break
		sleep(1)
	TEST_ASSERT_NULL(brain.GetComponent(/datum/component/hv_tumble), "The brain's tumble outlived its landing")
	TEST_ASSERT_EQUAL(brain.pixel_w, 0, "The landed brain is drawn off to the side")
	TEST_ASSERT_EQUAL(brain.pixel_z, 0, "The landed brain is drawn in the air")
	TEST_ASSERT(same_matrix(brain.transform, matrix()), "The landed brain is left squashed or turned")

/// Flying gore is never thrown: someone standing in its way is not hit, hurt or moved, and the part
/// comes down short of them
/datum/unit_test/voidcrew_hv_visuals/flying_gore_touches_nobody

/datum/unit_test/voidcrew_hv_visuals/flying_gore_touches_nobody/Run()
	var/mob/living/carbon/human/consistent/attacker = allocate(/mob/living/carbon/human/consistent, spot(0, 1))
	var/mob/living/carbon/human/consistent/victim = allocate(/mob/living/carbon/human/consistent, spot(1, 1))
	var/mob/living/carbon/human/consistent/bystander = allocate(/mob/living/carbon/human/consistent, spot(3, 1))
	// An arm cut off by a blow going east, toward the bystander two tiles on
	victim.hv_blood_hit_dir = EAST
	victim.hv_blood_hit_time = world.time
	var/obj/item/bodypart/arm = victim.get_bodypart(BODY_ZONE_L_ARM)
	TEST_ASSERT(arm.dismember(BRUTE, TRUE, WOUND_SLASH), "Test fixture: the arm did not come off")
	TEST_ASSERT_NULL(arm.throwing, "A severed arm was thrown")
	TEST_ASSERT_NOTNULL(arm.GetComponent(/datum/component/hv_tumble), "A severed arm did not fly")
	for(var/i in 1 to 50)
		if(!arm.GetComponent(/datum/component/hv_tumble))
			break
		sleep(1)
	TEST_ASSERT_EQUAL(get_turf(arm), spot(2, 1), "The arm did not come down on the tile before the person in its way")
	TEST_ASSERT_EQUAL(get_turf(bystander), spot(3, 1), "A flying arm moved someone")
	TEST_ASSERT_EQUAL(bystander.getBruteLoss(), 0, "A flying arm hurt someone")

	// A head burst by a blow going west, at the attacker standing right there
	var/obj/item/organ/brain/brain = victim.get_organ_slot(ORGAN_SLOT_BRAIN)
	TEST_ASSERT(victim.hv_burst_head(WEST), "Test fixture: the head did not burst")
	TEST_ASSERT_NULL(brain.throwing, "A burst head's brain was thrown")
	for(var/i in 1 to 50)
		if(!brain.GetComponent(/datum/component/hv_tumble))
			break
		sleep(1)
	TEST_ASSERT_EQUAL(get_turf(brain), spot(1, 1), "The brain did not drop short of the person in its way")
	TEST_ASSERT_EQUAL(get_turf(attacker), spot(0, 1), "A burst head moved the attacker")
	TEST_ASSERT_EQUAL(attacker.getBruteLoss(), 0, "A burst head hurt the attacker")

/// One leg gone: a limp while it is gone, none once it is back
/datum/unit_test/voidcrew_hv_visuals/limp

/datum/unit_test/voidcrew_hv_visuals/limp/Run()
	var/mob/living/carbon/human/consistent/victim = allocate(/mob/living/carbon/human/consistent, spot(1, 1))
	var/obj/item/bodypart/leg = victim.get_bodypart(BODY_ZONE_L_LEG)
	leg.drop_limb(FALSE, TRUE)
	TEST_ASSERT_NOTNULL(victim.GetComponent(/datum/component/hv_limp), "Losing a leg left no limp")
	var/list/rest = rest_of(victim)
	victim.Move(spot(2, 1), EAST)
	check_rest(victim, rest, "A limping step")
	leg.try_attach_limb(victim)
	TEST_ASSERT_NULL(victim.GetComponent(/datum/component/hv_limp), "The limp outlived the leg coming back")

/// Soft crit brings the pleading lean; leaving it takes it away. Moving while down plays nothing.
/datum/unit_test/voidcrew_hv_visuals/downed

/datum/unit_test/voidcrew_hv_visuals/downed/Run()
	var/mob/living/carbon/human/consistent/victim = allocate(/mob/living/carbon/human/consistent, spot(1, 1))
	victim.apply_damage(110, BRUTE, BODY_ZONE_CHEST, wound_bonus = CANT_WOUND)
	TEST_ASSERT_EQUAL(victim.stat, SOFT_CRIT, "Test fixture: the victim is not in soft crit")
	TEST_ASSERT_NOTNULL(victim.GetComponent(/datum/component/hv_downed), "Soft crit did not bring the pleading lean")
	// tg lays a body down facing a random side and turns it to the way it crawls (lying_angle_on_movement()):
	// lay it the way the move goes, so only the plea could change how it is drawn.
	if(victim.body_position == LYING_DOWN)
		victim.set_lying_angle(LYING_ANGLE_EAST)
	var/list/rest = rest_of(victim)
	victim.Move(spot(2, 1), EAST)
	victim.hv_vis_plead(null)
	check_rest(victim, rest, "A move and a plea")
	victim.fully_heal(HEAL_ALL)
	TEST_ASSERT_NULL(victim.GetComponent(/datum/component/hv_downed), "The pleading lean outlived soft crit")

/// A surrender trembles until they stand back up
/datum/unit_test/voidcrew_hv_visuals/surrender

/datum/unit_test/voidcrew_hv_visuals/surrender/Run()
	var/mob/living/carbon/human/consistent/victim = allocate(/mob/living/carbon/human/consistent, spot(1, 1))
	victim.emote("surrender")
	TEST_ASSERT_EQUAL(victim.body_position, LYING_DOWN, "Test fixture: the surrender did not put them on the floor")
	TEST_ASSERT_EQUAL(holds(victim), 1, "The surrender tremble is not held")
	victim.SetParalyzed(0)
	victim.get_up(instant = TRUE) // tg's own get-up takes a second
	TEST_ASSERT_EQUAL(victim.body_position, STANDING_UP, "Test fixture: they did not stand back up")
	TEST_ASSERT_EQUAL(holds(victim), 0, "The tremble outlived getting back up")

/// Spilled guts hold their strand at once, and slither without moving off their spot
/datum/unit_test/voidcrew_hv_visuals/guts

/datum/unit_test/voidcrew_hv_visuals/guts/Run()
	var/mob/living/carbon/human/consistent/victim = allocate(/mob/living/carbon/human/consistent, spot(1, 1))
	var/obj/item/bodypart/chest/chest = victim.get_bodypart(BODY_ZONE_CHEST)
	var/datum/wound/slash/flesh/critical/disembowel/spill = chest.hv_spill_guts(EAST, "test")
	TEST_ASSERT_NOTNULL(spill, "Test fixture: the guts did not spill")
	var/obj/item/hv_intestines/guts = spill.guts
	TEST_ASSERT_NOTNULL(spill.tether.strand, "The guts spilled without a strand to the body")
	var/list/rest = rest_of(guts)
	guts.forceMove(spot(2, 2))
	check_rest(guts, rest, "A slither")

/// A finisher leaves both of them drawn as they were, however its poses went
/datum/unit_test/voidcrew_hv_visuals/finisher_release

/datum/unit_test/voidcrew_hv_visuals/finisher_release/Run()
	var/mob/living/basic/hoarfrost_matriarch/matriarch = allocate(/mob/living/basic/hoarfrost_matriarch, spot(1, 1))
	var/mob/living/carbon/human/consistent/victim = allocate(/mob/living/carbon/human/consistent, spot(2, 1))
	victim.Paralyze(100 SECONDS)
	var/list/boss_rest = rest_of(matriarch)
	var/datum/hv_finisher/hoarfrost/finisher = new(matriarch, victim)
	TEST_ASSERT(finisher.start(), "Test fixture: the finisher did not start")
	for(var/i in 1 to 20)
		if(!finisher.running)
			break
		finisher.advance()
	TEST_ASSERT(!finisher.running, "Test fixture: the finisher did not finish")
	check_rest(matriarch, boss_rest, "A finisher")
	TEST_ASSERT_EQUAL(victim.pixel_w, 0, "A finisher left the victim off to the side")
	TEST_ASSERT_EQUAL(victim.pixel_z, 0, "A finisher left the victim lifted")
	qdel(finisher)

/// A pool creeping out to its new size keeps creeping when tg stops the decal's animations (it does each
/// time the blood dries a little or more lands on it), and forgets the creep once it is done
/datum/unit_test/voidcrew_hv_visuals/paint_survives_drying

/datum/unit_test/voidcrew_hv_visuals/paint_survives_drying/Run()
	var/obj/effect/decal/cleanable/blood/pool = allocate(/obj/effect/decal/cleanable/blood, spot(2, 2))
	var/matrix/rest = matrix(pool.transform)
	var/rest_alpha = pool.alpha
	pool.hv_vis_pool_creep(0.5)
	TEST_ASSERT_NOTNULL(pool.hv_vis_painting, "A creeping pool does not remember its creep")
	pool.update_blood_color()
	TEST_ASSERT_NOTNULL(pool.hv_vis_painting, "tg working the colour out again made the pool forget its creep")
	TEST_ASSERT(same_matrix(pool.transform, rest), "The creep left the pool's transform changed")
	TEST_ASSERT_EQUAL(pool.alpha, rest_alpha, "The creep left the pool's alpha changed")
	// HV_VIS_POOL_CREEP is 1.8 seconds
	sleep(2.5 SECONDS)
	pool.update_blood_color()
	TEST_ASSERT_NULL(pool.hv_vis_painting, "A finished creep was kept")

/// The hit-stop flash goes on, and comes off on a timer that dies with the body
/datum/unit_test/voidcrew_hv_visuals/flash

/datum/unit_test/voidcrew_hv_visuals/flash/Run()
	var/mob/living/carbon/human/consistent/victim = allocate(/mob/living/carbon/human/consistent, spot(1, 1))
	victim.hv_vis_flash()
	TEST_ASSERT_NOTNULL(victim.get_filter("hv_vis_flash"), "The hit-stop did not flash")
	TEST_ASSERT(length(victim._active_timers), "Nothing will take the flash off")
	sleep(1 SECONDS)
	TEST_ASSERT_NULL(victim.get_filter("hv_vis_flash"), "The flash stayed on")
