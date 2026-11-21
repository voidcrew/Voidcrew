// Review fixes for the scav den (voidcrew/modules/stealth/scav_camera.dm, scav_den.dm). Unit tests compile before
// voidcrew/_DEFINES, so values are written out: camera states SCAN 1, TRACK 2, ALARM 3, OFF 4; FACTION_SCAV "scav".

/// A den camera on the north wall of a fresh room, driven only by hand (its own sweep on SSfastprocess is stopped).
/datum/unit_test/voidcrew_stealth_live/proc/den_fix_camera(dx = 5, dy = 8)
	allocate(/obj/effect/landmark/stealth_group, at(0, 0))
	var/obj/machinery/scav_camera/camera = allocate(/obj/machinery/scav_camera/directional/north, at(dx, dy))
	camera.end_processing()
	return camera

/// Under it and beside it (its own wall row too) it sees you whichever way it points; a vehicle doesn't hide you,
/// a locker does; scavs, cuffed and downed NPCs are nothing to it.
/datum/unit_test/voidcrew_stealth_live/den_camera_close

/datum/unit_test/voidcrew_stealth_live/den_camera_close/Run()
	TEST_ASSERT(make_room(11, 9), "No room for the test")
	var/obj/machinery/scav_camera/camera = den_fix_camera()
	var/turf/eye = get_turf(camera)
	var/mob/living/carbon/human/person = person_at(5, 8)
	TEST_ASSERT(camera.scav_cam_sees(person, eye), "The camera doesn't see someone right under it")
	for(var/end_of_sweep in list(180 - camera.sweep, 180 + camera.sweep))
		camera.aim = end_of_sweep
		for(var/dx in list(4, 6))
			person.forceMove(at(dx, 8))
			TEST_ASSERT(camera.scav_cam_sees(person, eye), "The camera aimed at [end_of_sweep] doesn't see someone beside it on its wall")
			GLOB.stealth_test_dark_turfs[get_turf(person)] = TRUE
			TEST_ASSERT(camera.scav_cam_sees(person, eye), "The camera doesn't see someone beside it in the dark")
			GLOB.stealth_test_dark_turfs[get_turf(person)] = FALSE
	// Two along its wall it has no angle on them.
	camera.aim = 180
	person.forceMove(at(3, 8))
	TEST_ASSERT(!camera.scav_cam_sees(person, eye), "The camera sees two tiles along its own wall")
	// Following someone under it doesn't swing it round.
	person.forceMove(at(5, 8))
	camera.scav_cam_follow(person, eye, 0.2)
	TEST_ASSERT_EQUAL(camera.aim, 180, "The camera turned to follow someone right under it")

	// In a mech, in plain view: seen, and found, as a guard sees a driver.
	person.forceMove(at(5, 4))
	var/obj/vehicle/sealed/mecha/ripley/mech = allocate(/obj/vehicle/sealed/mecha/ripley, at(5, 4))
	person.forceMove(mech)
	TEST_ASSERT(camera.scav_cam_sees(person, eye), "The camera doesn't see someone driving a mech")
	TEST_ASSERT_EQUAL(camera.scav_cam_find(eye), person, "The camera doesn't pick out someone driving a mech")
	// In a locker: hidden.
	var/obj/structure/closet/locker = allocate(/obj/structure/closet, at(5, 4))
	person.forceMove(locker)
	TEST_ASSERT(!camera.scav_cam_sees(person, eye), "The camera sees into a locker")
	person.forceMove(at(5, 4))

	// One of the scavs.
	var/mob/living/carbon/human/scav = person_at(4, 4, listed = FALSE)
	scav.faction += "scav"
	TEST_ASSERT(!camera.scav_cam_sees(scav, eye), "The camera watches a scav")
	// A crew's captive: cuffed, or out cold.
	var/mob/living/carbon/human/cuffed = person_at(6, 4, listed = FALSE)
	TEST_ASSERT(camera.scav_cam_sees(cuffed, eye), "Test fixture: the camera doesn't see a free NPC")
	cuffed.set_handcuffed(new /obj/item/restraints/handcuffs(cuffed))
	cuffed.update_handcuffed()
	TEST_ASSERT(!camera.scav_cam_sees(cuffed, eye), "The camera watches a cuffed NPC")
	var/mob/living/carbon/human/sleeper = person_at(5, 3, listed = FALSE)
	TEST_ASSERT(camera.scav_cam_sees(sleeper, eye), "Test fixture: the camera doesn't see an NPC that's awake")
	sleeper.Unconscious(1 MINUTES)
	TEST_ASSERT(!camera.scav_cam_sees(sleeper, eye), "The camera watches an NPC out cold")

/// In an off-limits room the disguise needs the pass, unless the mark lets nobody in.
/datum/unit_test/voidcrew_stealth_live/den_camera_off_limits

/datum/unit_test/voidcrew_stealth_live/den_camera_off_limits/Run()
	TEST_ASSERT(make_room(11, 9), "No room for the test")
	var/obj/machinery/scav_camera/camera = den_fix_camera()
	var/turf/eye = get_turf(camera)
	var/obj/effect/landmark/stealth_restricted/mark = allocate(/obj/effect/landmark/stealth_restricted, at(5, 6))
	mark.reach = 1
	var/datum/stealth_group/group = camera.scav_cam_group()
	TEST_ASSERT_NOTNULL(group, "Test fixture: the camera has no guards")
	for(var/how in list("no pass", "pass", "pass, nobody allowed"))
		mark.allowed = how != "pass, nobody allowed"
		group.restricted = null
		var/mob/living/carbon/human/person = person_at(5, 6, listed = FALSE)
		var/obj/item/clothing/under/own_clothes = person.w_uniform
		if(own_clothes)
			person.temporarilyRemoveItemFromInventory(own_clothes, force = TRUE)
			qdel(own_clothes)
		stealth_dress(person, TRUE, TRUE, how != "no pass")
		var/datum/component/stealth_disguise/cache = stealth_disguise_cache(person)
		cache.refresh()
		TEST_ASSERT_EQUAL(camera.scav_cam_sees(person, eye), how != "pass", "Off limits, [how]: the camera got it wrong")
		// Out of the room the same disguise passes.
		person.forceMove(at(5, 3))
		TEST_ASSERT(!camera.scav_cam_sees(person, eye), "Outside the off-limits room, [how]: the camera doesn't let the disguise by")
		qdel(person)

/// It stands still with no player on its level; once it has sounded, it waits out its cooldown before sounding again.
/datum/unit_test/voidcrew_stealth_live/den_camera_alarm_again

/datum/unit_test/voidcrew_stealth_live/den_camera_alarm_again/Run()
	TEST_ASSERT(make_room(11, 9), "No room for the test")
	var/obj/machinery/scav_camera/camera = den_fix_camera()
	var/mob/living/carbon/human/person = person_at(5, 4, listed = FALSE)
	var/turf/eye = get_turf(camera)
	TEST_ASSERT(!length(SSmobs.clients_by_zlevel[eye.z]), "Test fixture: someone is listed on the test level")
	var/start_aim = camera.aim
	for(var/tick in 1 to 10)
		camera.process(0.2)
	TEST_ASSERT_EQUAL(camera.aim, start_aim, "The camera swept with no player on its level")
	TEST_ASSERT_EQUAL(camera.notice, 0, "The camera noticed someone with no player on its level")
	TEST_ASSERT_EQUAL(camera.cam_state, 1, "The camera woke with no player on its level")
	// A player arrives.
	SSmobs.clients_by_zlevel[eye.z] += person
	players[person] = eye.z
	for(var/tick in 1 to 15)
		camera.process(0.2)
		if(camera.cam_state == 3)
			break
	TEST_ASSERT_EQUAL(camera.cam_state, 3, "Three seconds in plain view didn't sound the camera's alarm")
	// The siren ends; full again inside the cooldown, it holds its peace.
	camera.alarm_until = world.time
	camera.process(0.2)
	TEST_ASSERT_EQUAL(camera.cam_state, 2, "The camera didn't go back to following once its siren ended")
	for(var/tick in 1 to 15)
		camera.process(0.2)
	TEST_ASSERT_EQUAL(camera.notice, 1, "The camera's notice didn't fill again")
	TEST_ASSERT_EQUAL(camera.cam_state, 2, "The camera sounded again inside its cooldown")
	// Cooldown over: it sounds.
	camera.alarm_ready_at = world.time
	camera.process(0.2)
	TEST_ASSERT_EQUAL(camera.cam_state, 3, "The camera didn't sound again after its cooldown")

/// Wirecutters from beside it: it sees who cuts, and a cut camera leaves SSfastprocess for good. A broken one leaves
/// too, and comes back when repaired.
/datum/unit_test/voidcrew_stealth_live/den_camera_cut

/datum/unit_test/voidcrew_stealth_live/den_camera_cut/Run()
	TEST_ASSERT(make_room(11, 9), "No room for the test")
	var/obj/machinery/scav_camera/camera = den_fix_camera()
	var/turf/eye = get_turf(camera)
	var/mob/living/carbon/human/person = person_at(4, 8)
	var/obj/item/wirecutters/cutters = allocate(/obj/item/wirecutters)
	person.put_in_active_hand(cutters, forced = TRUE)
	TEST_ASSERT(camera.scav_cam_sees(person, eye), "The camera doesn't see someone cutting it from its wall")
	TEST_ASSERT_EQUAL(camera.wirecutter_act(person, cutters), ITEM_INTERACT_SUCCESS, "The feed wasn't cut")
	TEST_ASSERT(camera.feed_cut, "A cut camera doesn't know it")
	TEST_ASSERT_EQUAL(camera.cam_state, 4, "A cut camera is still on")
	TEST_ASSERT_EQUAL(camera.process(0.2), PROCESS_KILL, "A cut camera keeps processing")

	var/obj/machinery/scav_camera/broken = allocate(/obj/machinery/scav_camera/directional/north, at(2, 8))
	broken.end_processing()
	broken.atom_break()
	TEST_ASSERT(broken.machine_stat & BROKEN, "Test fixture: the camera didn't break")
	TEST_ASSERT_EQUAL(broken.process(0.2), PROCESS_KILL, "A broken camera keeps processing")
	broken.atom_fix()
	TEST_ASSERT(broken.datum_flags & DF_ISPROCESSING, "A repaired camera didn't start processing again")
	broken.end_processing()
	broken.process(0.2)
	TEST_ASSERT_EQUAL(broken.cam_state, 1, "A repaired camera didn't come back on")

/// A den guard's red chrome eyes burn out when it dies, like the rest of an NPC's chrome.
/datum/unit_test/voidcrew_stealth_den_eyes_burn_out

/datum/unit_test/voidcrew_stealth_den_eyes_burn_out/Run()
	var/mob/living/carbon/human/npc/guard = allocate(/mob/living/carbon/human/npc/ruin/trooper/scav/den, run_loc_floor_bottom_left)
	TEST_ASSERT(istype(guard.get_organ_slot(ORGAN_SLOT_EYES), /obj/item/organ/eyes/robotic), "Test fixture: the den guard has no chrome eyes")
	guard.death()
	TEST_ASSERT_EQUAL(guard.stat, DEAD, "Test fixture: the den guard didn't die")
	TEST_ASSERT_NULL(guard.get_organ_slot(ORGAN_SLOT_EYES), "A dead den guard kept its chrome eyes")
	TEST_ASSERT_NULL(locate(/obj/item/organ/eyes/robotic) in get_turf(guard), "A dead den guard's chrome eyes lie there whole")
	TEST_ASSERT_NOTNULL(locate(/obj/item/burnt_chrome) in get_turf(guard), "A dead den guard's chrome eyes left no scrap")

/// The vault rolls once, on first opening, by the zone where it was placed; moving it and opening it again change nothing.
/datum/unit_test/voidcrew_stealth_den_vault_once

/datum/unit_test/voidcrew_stealth_den_vault_once/Run()
	var/obj/structure/closet/crate/secure/scav_vault/crate = allocate(/obj/structure/closet/crate/secure/scav_vault, run_loc_floor_bottom_left)
	TEST_ASSERT_EQUAL(crate.spawn_turf, run_loc_floor_bottom_left, "The vault didn't note where it was placed")
	TEST_ASSERT(!crate.vault_rolled, "The vault rolled before anyone opened it")
	crate.forceMove(run_loc_floor_top_right)
	TEST_ASSERT_EQUAL(crate.spawn_turf, run_loc_floor_bottom_left, "Moving the vault changed where it reads its zone")
	crate.locked = FALSE
	TEST_ASSERT(crate.open(null, force = TRUE), "Test fixture: the vault didn't open")
	TEST_ASSERT(crate.vault_rolled, "Opening the vault didn't roll it")
	TEST_ASSERT_NULL(crate.spawn_turf, "The vault kept its spawn turf after rolling")
	var/first = den_vault_pieces(crate)
	// Green 2, yellow 3, red 4 pieces of chrome, plus any stealth gear.
	var/zone = clamp(SSovermap_zones?.get_zone_type_anywhere(run_loc_floor_bottom_left) || 1, 1, 3)
	TEST_ASSERT_EQUAL(first, zone + 1 + (length(crate.scav_vault_stealth_loot()) ? 1 : 0), "A zone [zone] vault paid [first] pieces")
	TEST_ASSERT(crate.close(), "Test fixture: the vault didn't close")
	TEST_ASSERT(crate.open(null, force = TRUE), "Test fixture: the vault didn't open again")
	TEST_ASSERT_EQUAL(den_vault_pieces(crate), first, "Opening the vault again paid more")

/// Chrome and stealth gear from `crate`'s vault on its tile or in it.
/datum/unit_test/voidcrew_stealth_den_vault_once/proc/den_vault_pieces(obj/structure/closet/crate/secure/scav_vault/crate)
	. = 0
	var/list/stealth_loot = crate.scav_vault_stealth_loot()
	for(var/obj/item/piece in get_turf(crate))
		if(istype(piece, /obj/item/organ) || stealth_loot[piece.type])
			.++
	for(var/obj/item/piece in crate)
		if(istype(piece, /obj/item/organ) || stealth_loot[piece.type])
			.++

/// A sealed den chart opens once the slot is free, and the den it reveals takes the slot and is kept off contracts.
/datum/unit_test/voidcrew_stealth_den_chart_reveal
	var/list/spawned_sites = list()

/datum/unit_test/voidcrew_stealth_den_chart_reveal/Destroy()
	for(var/obj/structure/overmap/space_ruin/site as anything in spawned_sites)
		if(!QDELETED(site))
			site.remove_docks()
			qdel(site)
	return ..()

/datum/unit_test/voidcrew_stealth_den_chart_reveal/Run()
	TEST_ASSERT_NULL(scav_den_on_map(), "Test fixture: a den is already on the map")
	var/obj/structure/overmap/ship/ship = allocate(/obj/structure/overmap/ship)
	var/datum/rumor_chart/scav_den/chart = allocate(/datum/rumor_chart/scav_den)
	chart.ruin_template_path = /datum/map_template/ruin/space/rare/scav_den
	chart.spawn_zone = 2
	var/obj/structure/overmap/space_ruin/den = chart.reveal(ship)
	TEST_ASSERT_NOTNULL(den, "A den chart didn't open with no den on the map")
	spawned_sites += den
	TEST_ASSERT(chart.revealed, "An opened den chart isn't used up")
	TEST_ASSERT(den.mission_exclusive, "A revealed den can be held by a contract")
	TEST_ASSERT_EQUAL(scav_den_on_map(), den, "A revealed den doesn't hold the slot")
	var/datum/rumor_chart/scav_den/second = allocate(/datum/rumor_chart/scav_den)
	second.ruin_template_path = /datum/map_template/ruin/space/rare/scav_den
	second.spawn_zone = 2
	var/obj/structure/overmap/space_ruin/other = second.reveal(ship)
	if(other)
		spawned_sites += other
	TEST_ASSERT_NULL(other, "A second den opened while one was out there")
