// The scav den's cameras, guards' eyes, vault and test planet, the guards' radio net and level activators, head-shot
// power and the hostage pose on a buckled body (voidcrew/modules/stealth/scav_camera.dm, scav_den.dm,
// stealth_den_planet.dm, stealth_radio.dm, stealth_crits.dm, stealth_hostage_pose.dm). Unit tests compile before
// voidcrew/_DEFINES, so values from there are written out: camera states SCAN 1, TRACK 2, ALARM 3, OFF 4;
// STEALTH_CALL_ALARM 3; ZONE_RED 3; STEALTH_HEAD_SHOT_NONE 0, STEALTH_HEAD_SHOT_DOWN 2.

/// `person` in the whole scav disguise (fatigues, balaclava, pass), in place of their own clothes.
/datum/unit_test/proc/fix2_den_disguise(mob/living/carbon/human/person)
	var/obj/item/clothing/under/own_clothes = person.w_uniform
	if(own_clothes)
		person.temporarilyRemoveItemFromInventory(own_clothes, force = TRUE)
		qdel(own_clothes)
	stealth_dress(person)
	var/datum/component/stealth_disguise/cache = stealth_disguise_cache(person)
	cache.refresh()

/// A full scav disguise doesn't get past a camera with a gun out or a fallen guard in tow, as it wouldn't get past a guard.
/datum/unit_test/voidcrew_stealth_live/den_camera_breakers

/datum/unit_test/voidcrew_stealth_live/den_camera_breakers/Run()
	TEST_ASSERT(make_room(11, 9), "No room for the test")
	var/obj/machinery/scav_camera/camera = den_fix_camera()
	var/turf/eye = get_turf(camera)
	var/mob/living/carbon/human/npc/guard = guard_at(1, 1, WEST)
	var/datum/ai_controller/basic_controller/human_npc/stealth/guard_ai = stealth_ai(guard)
	guard_ai.stealth_setup()
	TEST_ASSERT_EQUAL(guard_ai.group, camera.scav_cam_group(), "Test fixture: the guard isn't in the camera's den")
	var/mob/living/carbon/human/person = person_at(5, 4, listed = FALSE)
	fix2_den_disguise(person)
	TEST_ASSERT(!camera.scav_cam_sees(person, eye), "Test fixture: the camera doesn't let the whole disguise by")
	// A gun out.
	var/obj/item/gun/ballistic/automatic/pistol/pistol = allocate(/obj/item/gun/ballistic/automatic/pistol)
	person.put_in_active_hand(pistol, forced = TRUE)
	TEST_ASSERT(camera.scav_cam_sees(person, eye), "The camera let a disguise by with a gun out")
	person.dropItemToGround(pistol, force = TRUE)
	TEST_ASSERT(!camera.scav_cam_sees(person, eye), "Test fixture: the disguise didn't pass again with the gun put down")
	// A dead guard dragged along.
	var/mob/living/carbon/human/npc/body = guard_at(5, 3, WEST)
	var/datum/ai_controller/basic_controller/human_npc/stealth/body_ai = stealth_ai(body)
	body_ai.stealth_setup()
	body.death()
	person.start_pulling(body, supress_message = TRUE)
	TEST_ASSERT_EQUAL(person.pulling, body, "Test fixture: the body couldn't be dragged")
	TEST_ASSERT(camera.scav_cam_sees(person, eye), "The camera let a disguise by dragging a dead guard")
	person.stop_pulling()
	TEST_ASSERT(!camera.scav_cam_sees(person, eye), "Test fixture: the disguise didn't pass again once the body was let go")

/// An EMP'd camera comes back on, sweeping, with its cone showing, once the EMP wears off.
/datum/unit_test/voidcrew_stealth_live/den_camera_emp_ends

/datum/unit_test/voidcrew_stealth_live/den_camera_emp_ends/Run()
	TEST_ASSERT(make_room(11, 9), "No room for the test")
	var/obj/machinery/scav_camera/camera = den_fix_camera()
	// Listed (so the camera runs), off to its side where it can't see them.
	person_at(10, 7)
	camera.emp_act(EMP_LIGHT)
	TEST_ASSERT_EQUAL(camera.cam_state, 4, "Test fixture: an EMP didn't shut the camera off")
	camera.process(0.2)
	TEST_ASSERT_EQUAL(camera.cam_state, 4, "The camera came back on while still EMP'd")
	camera.emp_until = world.time
	camera.process(0.2)
	TEST_ASSERT_EQUAL(camera.cam_state, 1, "The camera didn't come back on once the EMP wore off")
	TEST_ASSERT(camera.cone.alpha > 0, "The camera came back on with its cone hidden")

/// The siren's beeping stops when the siren ends and when the feed is cut mid-siren.
/datum/unit_test/voidcrew_stealth_live/den_camera_alarm_loop

/datum/unit_test/voidcrew_stealth_live/den_camera_alarm_loop/Run()
	TEST_ASSERT(make_room(11, 9), "No room for the test")
	var/obj/machinery/scav_camera/camera = den_fix_camera()
	var/mob/living/carbon/human/person = person_at(5, 4)
	fix2_den_sound(camera)
	TEST_ASSERT_EQUAL(camera.cam_state, 3, "Test fixture: three seconds in plain view didn't sound the camera's alarm")
	TEST_ASSERT_NOTNULL(camera.alarm_loop.timer_id, "The siren sounded without its beeping")
	camera.alarm_until = world.time
	camera.process(0.2)
	TEST_ASSERT(camera.cam_state != 3, "Test fixture: the siren didn't end")
	TEST_ASSERT_NULL(camera.alarm_loop.timer_id, "The beeping went on after the siren ended")
	// Again, and the feed cut from beside it while it sounds.
	camera.alarm_ready_at = world.time
	fix2_den_sound(camera)
	TEST_ASSERT_EQUAL(camera.cam_state, 3, "Test fixture: the camera didn't sound again")
	TEST_ASSERT_NOTNULL(camera.alarm_loop.timer_id, "Test fixture: the second siren has no beeping")
	person.forceMove(at(4, 8))
	var/obj/item/wirecutters/cutters = allocate(/obj/item/wirecutters)
	person.put_in_active_hand(cutters, forced = TRUE)
	TEST_ASSERT_EQUAL(camera.wirecutter_act(person, cutters), ITEM_INTERACT_SUCCESS, "Test fixture: the feed wasn't cut")
	TEST_ASSERT_NULL(camera.alarm_loop.timer_id, "The beeping went on after the feed was cut")

/// Runs `camera` until it sounds (at most three seconds of ticks).
/datum/unit_test/voidcrew_stealth_live/proc/fix2_den_sound(obj/machinery/scav_camera/camera)
	for(var/tick in 1 to 15)
		camera.process(0.2)
		if(camera.cam_state == 3)
			return

/// A living den guard's red chrome eyes taken out of it burn out, as when it dies.
/datum/unit_test/voidcrew_stealth_fix2_den_eyes_taken_out

/datum/unit_test/voidcrew_stealth_fix2_den_eyes_taken_out/Run()
	var/mob/living/carbon/human/npc/guard = allocate(/mob/living/carbon/human/npc/ruin/trooper/scav/den, run_loc_floor_bottom_left)
	var/obj/item/organ/eyes/robotic/chrome = guard.get_organ_slot(ORGAN_SLOT_EYES)
	TEST_ASSERT(istype(chrome), "Test fixture: the den guard has no chrome eyes")
	chrome.Remove(guard)
	chrome.forceMove(run_loc_floor_bottom_left)
	TEST_ASSERT_EQUAL(guard.stat, CONSCIOUS, "Test fixture: the den guard isn't alive and awake")
	var/deadline = world.time + 2 SECONDS
	while(!QDELETED(chrome) && world.time < deadline)
		sleep(1)
	TEST_ASSERT(QDELETED(chrome), "A living den guard's chrome eyes came out whole")
	TEST_ASSERT_NOTNULL(locate(/obj/item/burnt_chrome) in run_loc_floor_bottom_left, "A living den guard's chrome eyes left no scrap")
	// Its later death finds nothing to burn out, and nothing breaks.
	guard.death()
	TEST_ASSERT_EQUAL(guard.stat, DEAD, "Test fixture: the den guard didn't die")

/// The vault pays by the zone it noted, wherever it is opened.
/datum/unit_test/voidcrew_stealth_fix2_den_vault_zone

/datum/unit_test/voidcrew_stealth_fix2_den_vault_zone/Run()
	var/obj/structure/closet/crate/secure/scav_vault/crate = allocate(/obj/structure/closet/crate/secure/scav_vault, run_loc_floor_bottom_left)
	// As if its den had come up in a red zone.
	crate.vault_zone = 3
	crate.spawn_turf = null
	crate.forceMove(run_loc_floor_top_right)
	crate.locked = FALSE
	TEST_ASSERT(crate.open(null, force = TRUE), "Test fixture: the vault didn't open")
	var/pieces = 0
	var/list/stealth_loot = crate.scav_vault_stealth_loot()
	for(var/obj/item/piece in get_turf(crate))
		if(istype(piece, /obj/item/organ) || stealth_loot[piece.type])
			pieces++
	for(var/obj/item/piece in crate)
		if(istype(piece, /obj/item/organ) || stealth_loot[piece.type])
			pieces++
	TEST_ASSERT_EQUAL(pieces, 4 + (length(stealth_loot) ? 1 : 0), "A vault that noted a red zone paid [pieces] pieces")

/// One test den planet at a time: the slot is held from the zone prompt on, and only its own run lets it go.
/datum/unit_test/voidcrew_stealth_fix2_den_planet_slot

/datum/unit_test/voidcrew_stealth_fix2_den_planet_slot/Run()
	var/old_claim = GLOB.stealth_test_den_claim
	var/old_time = GLOB.stealth_test_den_claim_time
	GLOB.stealth_test_den_claim = 0
	TEST_ASSERT(!stealth_test_den_claimed(), "Test fixture: the slot is held with no claim")
	var/first = stealth_test_den_take_slot()
	TEST_ASSERT(stealth_test_den_claimed(), "A run waiting on its zone prompt doesn't hold the slot")
	var/second = stealth_test_den_take_slot()
	TEST_ASSERT(first != second, "Two runs got the same claim")
	stealth_test_den_release(first)
	TEST_ASSERT(stealth_test_den_claimed(), "An earlier run let go of a slot a later run holds")
	TEST_ASSERT_EQUAL(GLOB.stealth_test_den_claim, second, "The slot isn't the later run's")
	stealth_test_den_release(second)
	TEST_ASSERT(!stealth_test_den_claimed(), "The slot is still held after its run let go")
	GLOB.stealth_test_den_claim = old_claim
	GLOB.stealth_test_den_claim_time = old_time

/// A radio call reaches only earpieces on the same site as the call: a lookout carried off neither gets the den's
/// calls nor raises the den with its own.
/datum/unit_test/voidcrew_stealth_fix2_den_radio_site

/datum/unit_test/voidcrew_stealth_fix2_den_radio_site/Run()
	var/datum/turf_reservation/block = stealth_block(8, 5)
	TEST_ASSERT_NOTNULL(block, "No room for the test")
	var/datum/turf_reservation/away = stealth_block(5, 5)
	TEST_ASSERT_NOTNULL(away, "No room for the test")
	var/obj/effect/landmark/stealth_group/marker = allocate(/obj/effect/landmark/stealth_group, stealth_at(block, 6, 4))
	var/datum/stealth_group/group = marker.group
	var/mob/living/carbon/human/npc/first = allocate(/mob/living/carbon/human/npc/ruin/trooper/scav/lookout, stealth_at(block, 2, 2))
	var/mob/living/carbon/human/npc/second = allocate(/mob/living/carbon/human/npc/ruin/trooper/scav/lookout, stealth_at(block, 5, 2))
	var/datum/ai_controller/basic_controller/human_npc/stealth/first_ai = first.ai_controller
	var/datum/ai_controller/basic_controller/human_npc/stealth/second_ai = second.ai_controller
	first_ai.stealth_setup()
	second_ai.stealth_setup()
	TEST_ASSERT(first_ai.group == group && second_ai.group == group, "Test fixture: the lookouts aren't in the marker's group")
	first_ai.set_ai_status(AI_STATUS_ON)
	second_ai.set_ai_status(AI_STATUS_ON)
	group.next_radio_alarm = 0
	TEST_ASSERT_EQUAL(group.radio_call(null, 3, stealth_at(block, 1, 1)), 2, "Test fixture: an alarm at the den didn't reach both lookouts")
	// The second is carried off to another site.
	second.forceMove(stealth_at(away, 2, 2))
	second_ai.set_ai_status(AI_STATUS_ON)
	group.next_radio_alarm = 0
	TEST_ASSERT_EQUAL(group.radio_call(null, 3, stealth_at(block, 1, 1)), 1, "An alarm at the den reached a lookout on another site")
	group.next_radio_alarm = 0
	TEST_ASSERT_EQUAL(group.radio_call(second, 3, stealth_at(away, 1, 1)), 0, "A lookout's call from another site reached the den")
	TEST_ASSERT(first_ai.stealth_state() == "unaware", "The den answered a call from another site")

/// A multitool can't tune a guard's earpiece: it says so and binds it to nothing.
/datum/unit_test/voidcrew_stealth_fix2_den_earpiece_multitool

/datum/unit_test/voidcrew_stealth_fix2_den_earpiece_multitool/Run()
	var/mob/living/carbon/human/person = allocate(/mob/living/carbon/human/consistent, run_loc_floor_bottom_left)
	var/obj/item/radio/headset/guard_net/scav/earpiece = allocate(/obj/item/radio/headset/guard_net/scav, run_loc_floor_bottom_left)
	var/obj/item/multitool/tool = allocate(/obj/item/multitool)
	person.put_in_active_hand(tool, forced = TRUE)
	TEST_ASSERT_EQUAL(earpiece.multitool_act(person, tool), ITEM_INTERACT_BLOCKING, "A multitool tuned a guard's earpiece")
	TEST_ASSERT_NULL(earpiece.comms_outpost_ref, "A multitool bound a guard's earpiece to an outpost")
	TEST_ASSERT_NULL(earpiece.get_bound_comms_ship(), "A guard's earpiece is bound to a ship")

/// Head-shot power adds up across the pellets of one gun's shot, never across two guns firing in the same tick.
/datum/unit_test/voidcrew_stealth_fix2_den_pellets

/datum/unit_test/voidcrew_stealth_fix2_den_pellets/Run()
	var/datum/turf_reservation/block = stealth_block(8, 5)
	TEST_ASSERT_NOTNULL(block, "No room for the test")
	var/mob/living/carbon/human/npc/guard = d45_bare_guard(block, 4, 2)
	var/obj/item/bodypart/head = guard.get_bodypart(BODY_ZONE_HEAD)
	var/mob/living/carbon/human/shooter = stealth_person(block, 3, 2)
	shooter.zone_selected = BODY_ZONE_HEAD
	var/obj/item/gun/first_gun = allocate(/obj/item/gun/ballistic/automatic/pistol)
	var/obj/item/gun/second_gun = allocate(/obj/item/gun/ballistic/automatic/pistol)
	// Two guns, one light pellet each, in one tick: neither is a head shot alone, and they don't add up.
	fix2_den_pellet(guard, head, shooter, first_gun)
	fix2_den_pellet(guard, head, shooter, second_gun)
	TEST_ASSERT_EQUAL(guard.stealth_head_shot_power, 10, "Pellets from two guns added up")
	TEST_ASSERT_EQUAL(guard.stealth_head_shot_done, 0, "Two light pellets from two guns made a head shot")
	// Two pellets of one gun's shot, in the same tick, do.
	fix2_den_pellet(guard, head, shooter, first_gun)
	fix2_den_pellet(guard, head, shooter, first_gun)
	TEST_ASSERT_EQUAL(guard.stealth_head_shot_power, 20, "The pellets of one gun's shot didn't add up")
	TEST_ASSERT_EQUAL(guard.stealth_head_shot_done, 2, "Two pellets of one shot that add up to a head shot didn't make one")

/// One light pellet (10 brute, no wound bonus) from `gun` in `shooter`'s hand landing on `guard`'s `head`.
/datum/unit_test/proc/fix2_den_pellet(mob/living/carbon/human/npc/guard, obj/item/bodypart/head, mob/living/carbon/human/shooter, obj/item/gun/gun)
	var/obj/projectile/bullet/pellet = allocate(/obj/projectile/bullet, get_turf(shooter))
	pellet.damage = 10
	pellet.damage_type = BRUTE
	pellet.stamina = 0
	pellet.wound_bonus = 0
	pellet.firer = shooter
	pellet.fired_from = gun
	guard.stealth_head_shot(pellet.damage, head, pellet.wound_bonus, EAST, pellet)

/// Held at gunpoint while buckled to a chair, a body is left as tg leaves it: no hostage pose.
/datum/unit_test/voidcrew_stealth_fix2_den_buckled_hostage

/datum/unit_test/voidcrew_stealth_fix2_den_buckled_hostage/Run()
	var/datum/turf_reservation/block = stealth_block(8, 5)
	TEST_ASSERT_NOTNULL(block, "No room for the test")
	var/turf/spot = stealth_at(block, 4, 2)
	var/obj/structure/chair/chair = allocate(/obj/structure/chair, spot)
	var/mob/living/carbon/human/holder = stealth_person(block, 4, 2)
	var/mob/living/carbon/human/seated = stealth_person(block, 4, 2)
	TEST_ASSERT(chair.buckle_mob(seated, force = TRUE), "Test fixture: couldn't buckle the body to the chair")
	var/obj/item/gun/ballistic/automatic/pistol/pistol = allocate(/obj/item/gun/ballistic/automatic/pistol)
	holder.put_in_active_hand(pistol, forced = TRUE)
	holder.setDir(EAST)
	stealth_test_grab(holder, seated, GRAB_NECK)
	TEST_ASSERT_EQUAL(seated.buckled, chair, "Test fixture: the grab took the body off the chair")
	TEST_ASSERT_EQUAL(stealth_hostage_of(holder), seated, "Test fixture: a neck grab with a gun on someone in a chair isn't a hostage")
	TEST_ASSERT_EQUAL(seated.hostage_pose_dir, 0, "A body buckled to a chair was posed as a hostage")
	holder.setDir(NORTH)
	TEST_ASSERT_EQUAL(seated.hostage_pose_dir, 0, "A body buckled to a chair was posed when the holder turned")
	holder.stop_pulling()
	seated.buckled?.unbuckle_mob(seated, force = TRUE)
