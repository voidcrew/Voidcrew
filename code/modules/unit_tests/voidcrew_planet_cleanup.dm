/// Occupancy must protect connected survivors without counting abandoned minds or neighbours.
/datum/unit_test/voidcrew_planet_cleanup_occupancy
	var/obj/structure/overmap/planet/site
	var/list/test_players = list()

/datum/unit_test/voidcrew_planet_cleanup_occupancy/Destroy()
	GLOB.player_list -= test_players
	for(var/mob/player in allocated)
		if(!QDELETED(player))
			player.key = null
	if(!QDELETED(site))
		// This fixture borrows the test level; it never owns or clears its turfs.
		site.mapzone = null
		site.footprint = null
	return ..()

/datum/unit_test/voidcrew_planet_cleanup_occupancy/Run()
	var/turf/inside = run_loc_floor_bottom_left
	var/turf/outside = get_step(inside, EAST)
	var/datum/map_zone/zone = allocate(/datum/map_zone)
	zone.z_levels = list(reservation)
	var/datum/map_footprint/footprint = allocate(/datum/map_footprint)
	footprint.z_value = inside.z
	footprint.set_rect(inside.x, inside.y, 1, 1)
	site = allocate(/obj/structure/overmap/planet)
	site.mapzone = zone
	site.footprint = footprint
	var/mob/living/basic/body = allocate(/mob/living/basic, inside)
	body.mind_initialize()
	TEST_ASSERT(body in zone.get_mind_mobs_in(footprint), "The fixture must reproduce a living body retaining its mind")
	TEST_ASSERT(site.can_release_interior(), "A ghosted body's mind pinned the planet")

	// Match Login/Logout's player-list membership without connecting to the test world.
	test_players += body
	GLOB.player_list |= body
	TEST_ASSERT(!site.can_release_interior(), "Reconnecting to the stranded body did not protect it")
	body.stat = UNCONSCIOUS
	TEST_ASSERT(!site.can_release_interior(), "An unconscious connected survivor was treated as abandoned")
	body.stat = DEAD
	TEST_ASSERT(site.can_release_interior(), "A corpse pinned the planet")
	body.stat = CONSCIOUS

	var/obj/structure/closet/container = allocate(/obj/structure/closet, inside)
	body.forceMove(container)
	TEST_ASSERT(!site.can_release_interior(), "A connected survivor inside a container was missed")
	site.footprint = null
	TEST_ASSERT(!site.can_release_interior(), "The whole-zone fallback missed a connected survivor inside a container")
	site.footprint = footprint
	container.forceMove(outside)
	TEST_ASSERT(site.can_release_interior(), "A neighbour's player on the same z-level pinned this footprint")
	container.forceMove(inside)

	GLOB.player_list -= body
	var/mob/dead/observer/ghost = allocate(/mob/dead/observer, body)
	test_players += ghost
	GLOB.player_list |= ghost
	TEST_ASSERT_EQUAL(ghost.mind, body.mind, "The observer must retain the abandoned body's mind reference")
	TEST_ASSERT(site.can_release_interior(), "A ghost watching its living body pinned the planet")
	site.footprint = null
	TEST_ASSERT(site.can_release_interior(), "The whole-zone fallback counted a ghost or disconnected body")
	site.footprint = footprint

	// SSD retains a real key without a client, including inside a container.
	body.key = "planetcleanupssd"
	body.last_logout_time = world.time
	TEST_ASSERT_NULL(body.client, "The SSD fixture unexpectedly connected a real client")
	TEST_ASSERT(!site.can_release_interior(), "A recently disconnected player lost their reconnection grace")
	TEST_ASSERT(site.can_release_interior(ignore_ssd_grace = TRUE), "SSD grace prevented the countdown from being armed")
	TEST_ASSERT_EQUAL(site.get_despawn_delay(), 10 MINUTES, "SSD did not extend cleanup to ten minutes")
	var/mob/living/basic/other_ssd = allocate(/mob/living/basic, inside)
	other_ssd.key = "planetcleanupotherssd"
	other_ssd.last_logout_time = world.time - 2 MINUTES
	TEST_ASSERT_EQUAL(site.get_despawn_delay(), 10 MINUTES, "An older SSD body shortened a newer player's grace")
	body.last_logout_time = world.time - 10 MINUTES
	TEST_ASSERT_EQUAL(site.get_despawn_delay(), 8 MINUTES, "Cleanup did not honor the remaining player's disconnect time")
	body.last_logout_time = world.time
	other_ssd.key = null
	site.footprint = null
	TEST_ASSERT(!site.can_release_interior(), "The whole-zone fallback missed an SSD player in a container")
	site.footprint = footprint
	container.forceMove(outside)
	TEST_ASSERT(site.can_release_interior(), "An SSD player in the neighbouring footprint pinned this planet")
	TEST_ASSERT_EQUAL(site.get_despawn_delay(), 5 MINUTES, "A neighbouring SSD player extended this planet's countdown")
	container.forceMove(inside)

	body.key = "@planetcleanupadmin"
	TEST_ASSERT(site.can_release_interior(), "An admin ghost's fake key was treated as SSD")
	TEST_ASSERT_EQUAL(site.get_despawn_delay(), 5 MINUTES, "An admin ghost extended cleanup beyond the catatonic delay")
	body.key = "planetcleanupssd"
	ADD_TRAIT(body, TRAIT_SUICIDED, REF(src))
	TEST_ASSERT(site.can_release_interior(), "A suicided body's key was treated as a returning SSD player")
	REMOVE_TRAIT(body, TRAIT_SUICIDED, REF(src))
	body.stat = DEAD
	TEST_ASSERT(site.can_release_interior(), "A keyed corpse received SSD protection")
	body.stat = CONSCIOUS
	body.last_logout_time = world.time - 10 MINUTES
	TEST_ASSERT(site.can_release_interior(), "An old SSD body pinned the planet after its grace expired")
	TEST_ASSERT_EQUAL(site.get_despawn_delay(), 5 MINUTES, "Expired SSD protection extended the base countdown")

	body.key = null
	ghost.can_reenter_corpse = TRUE
	TEST_ASSERT(ghost.stay_dead(), "The DNR fixture could not relinquish its body")
	TEST_ASSERT_NULL(ghost.mind, "DNR did not detach the observer from the body")
	TEST_ASSERT(site.can_release_interior(), "A DNR body's retained mind pinned the planet")
	TEST_ASSERT_EQUAL(site.get_despawn_delay(), 5 MINUTES, "DNR did not use the catatonic cleanup delay")

	var/mob/living/basic/mindless_player = allocate(/mob/living/basic, inside)
	TEST_ASSERT_NULL(mindless_player.mind, "The connected-mob fixture unexpectedly already had a mind")
	test_players += mindless_player
	GLOB.player_list |= mindless_player
	TEST_ASSERT(!site.can_release_interior(), "A connected living mob without a mind was unprotected")
	GLOB.player_list -= mindless_player

	site.preserve_level = TRUE
	TEST_ASSERT(!site.can_release_interior(), "Cleanup ignored a preserved planet")
	site.preserve_level = FALSE
	site.loading = TRUE
	TEST_ASSERT(!site.can_release_interior(), "Cleanup ignored an in-progress build")
	site.loading = FALSE
	site.first_dock_taken = TRUE
	TEST_ASSERT(!site.can_release_interior(), "Cleanup ignored the primary berth")
	site.first_dock_taken = FALSE
	site.second_dock_taken = TRUE
	TEST_ASSERT(!site.can_release_interior(), "Cleanup ignored the secondary berth")
	site.second_dock_taken = FALSE
	var/obj/structure/overmap/ship/ship = allocate(/obj/structure/overmap/ship, site)
	TEST_ASSERT(!site.can_release_interior(), "Cleanup ignored a docked ship")
	ship.forceMove(inside)
	TEST_ASSERT(site.can_release_interior(), "The abandoned planet remained blocked after its ship left")

/// Exercise the real countdown, reconnect refusal, and teardown on a small map slot.
/datum/unit_test/voidcrew_planet_cleanup_lifecycle
	var/obj/structure/overmap/planet/site
	var/mob/living/basic/body
	var/ssd_key = "planetcleanuplatessd"
	var/turf/cleanup_turf
	var/original_turf_type
	var/original_baseturfs
	var/area/original_area

/datum/unit_test/voidcrew_planet_cleanup_lifecycle/Destroy()
	GLOB.player_list -= body
	for(var/mob/player in allocated)
		if(!QDELETED(player))
			player.key = null
	// Teardown creates this observer outside allocate(); release its simulated offline key.
	for(var/mob/dead/observer/ghost in GLOB.dead_mob_list)
		if(ghost.ckey == ssd_key)
			ghost.key = null
			qdel(ghost)
	if(!QDELETED(site))
		site.cancel_despawn_timer()
		site.remove_docks()
		if(site.mapzone)
			site.remove_mapzone(throttled = FALSE)
	if(cleanup_turf && original_turf_type)
		cleanup_turf = cleanup_turf.ChangeTurf(original_turf_type, original_baseturfs)
		cleanup_turf.change_area(get_area(cleanup_turf), original_area)
	return ..()

/datum/unit_test/voidcrew_planet_cleanup_lifecycle/Run()
	site = allocate(/obj/structure/overmap/planet)
	cleanup_turf = locate(run_loc_floor_bottom_left.x + 2, run_loc_floor_bottom_left.y + 2, run_loc_floor_bottom_left.z)
	original_turf_type = cleanup_turf.type
	original_baseturfs = islist(cleanup_turf.baseturfs) ? cleanup_turf.baseturfs.Copy() : cleanup_turf.baseturfs
	original_area = get_area(cleanup_turf)
	var/turf/neighbour_turf = get_step(cleanup_turf, EAST)
	var/datum/map_zone/zone = allocate(/datum/map_zone)
	zone.z_levels = list(reservation)
	var/datum/map_footprint/footprint = zone.claim_slot()
	var/datum/map_footprint/neighbour = zone.claim_slot()
	TEST_ASSERT(footprint && neighbour, "Could not claim both cleanup fixture slots")
	// Keep a neighbour allocated so the real teardown clears only our one turf.
	footprint.set_rect(cleanup_turf.x, cleanup_turf.y, 1, 1)
	neighbour.set_rect(neighbour_turf.x, neighbour_turf.y, 1, 1)
	var/mob/living/basic/neighbour_mob = allocate(/mob/living/basic, neighbour_turf)
	site.mapzone = zone
	site.footprint = footprint
	site.loaded = TRUE
	var/slots_before = zone.used_slot_count()
	body = allocate(/mob/living/basic, cleanup_turf)
	body.mind_initialize()
	var/obj/structure/closet/container = allocate(/obj/structure/closet, cleanup_turf)
	body.forceMove(container)
	var/mob/dead/observer/watcher = allocate(/mob/dead/observer, cleanup_turf)
	watcher.forceMove(cleanup_turf)
	site.check_start_despawn()
	var/datum/timedevent/countdown = SStimer.timer_id_dict[site.despawn_timer_id]
	TEST_ASSERT_NOTNULL(countdown, "An abandoned minded body prevented the unload countdown")
	TEST_ASSERT_EQUAL(countdown.wait, 5 MINUTES, "A catatonic body did not receive the five-minute base countdown")

	// Someone disconnects after the shorter countdown was armed. Teardown must recheck.
	body.key = ssd_key
	body.last_logout_time = world.time
	TEST_ASSERT(!site.unload_level(), "The shorter countdown bypassed a newly SSD player's grace")
	TEST_ASSERT(site.loaded && !QDELETED(body), "A newly SSD player lost their planet")

	// A player returns just before expiry. Invoke the callback without sleeping.
	GLOB.player_list |= body
	site.cancel_despawn_timer()
	site.attempt_despawn()
	TEST_ASSERT(site.loaded && site.mapzone == zone, "A reconnecting survivor lost their planet at countdown expiry")
	TEST_ASSERT(!QDELETED(body), "A reconnecting survivor was deleted")
	var/datum/timedevent/retry
	for(var/datum/timedevent/timer as anything in site._active_timers)
		if(timer.callBack.delegate == TYPE_PROC_REF(/obj/structure/overmap/planet, check_start_despawn))
			retry = timer
			break
	TEST_ASSERT_NOTNULL(retry, "A refused unload did not restart eligibility checks")
	GLOB.player_list -= body
	body.last_logout_time = world.time
	qdel(retry)
	site.check_start_despawn()
	countdown = SStimer.timer_id_dict[site.despawn_timer_id]
	TEST_ASSERT_NOTNULL(countdown, "Disconnecting again left the planet without a countdown")
	TEST_ASSERT_EQUAL(countdown.wait, 10 MINUTES, "Disconnecting again did not grant a fresh reconnection window")
	body.last_logout_time = world.time - 11 MINUTES
	site.cancel_despawn_timer()
	site.attempt_despawn()
	TEST_ASSERT(!site.loaded && !site.mapzone, "An abandoned planet did not unload")
	TEST_ASSERT(QDELETED(body), "Planet teardown left the abandoned living body behind")
	TEST_ASSERT(!QDELETED(watcher), "Planet teardown deleted an observer watching the site")
	var/mob/dead/observer/released_player
	for(var/mob/dead/observer/ghost in GLOB.dead_mob_list)
		if(ghost.ckey == ssd_key)
			released_player = ghost
			break
	TEST_ASSERT_NOTNULL(released_player, "Planet teardown did not preserve the SSD player's key on an observer")
	TEST_ASSERT(!released_player.can_reenter_corpse, "The released SSD player could reenter a deleted body")
	TEST_ASSERT(QDELETED(footprint), "Planet teardown retained its footprint")
	TEST_ASSERT_EQUAL(zone.used_slot_count(), slots_before - 1, "Planet teardown did not release its map slot")
	TEST_ASSERT(!QDELETED(neighbour) && !QDELETED(neighbour_mob), "Planet teardown cleared the neighbouring encounter")

/// An empty planet may reap its fauna, but never animals or bodies in ships and outposts.
/datum/unit_test/voidcrew_planet_mobs_protected_areas
	var/turf/protected_turf
	var/area/original_area

/datum/unit_test/voidcrew_planet_mobs_protected_areas/Destroy()
	if(protected_turf && original_area)
		protected_turf.change_area(get_area(protected_turf), original_area)
	return ..()

/datum/unit_test/voidcrew_planet_mobs_protected_areas/Run()
	protected_turf = run_loc_floor_bottom_left
	original_area = get_area(protected_turf)
	var/turf/surface_turf = get_step(protected_turf, EAST)
	var/turf/neighbour_turf = get_step(surface_turf, EAST)
	var/datum/map_footprint/footprint = allocate(/datum/map_footprint)
	footprint.z_value = protected_turf.z
	footprint.set_rect(protected_turf.x, protected_turf.y, 2, 1)
	var/datum/planet_mob_tracker/tracker = allocate(/datum/planet_mob_tracker)
	tracker.surface_z = protected_turf.z
	tracker.footprint = footprint
	TEST_ASSERT(!SSplanet_mobs.check_players(tracker), "The cleanup fixture must have no connected players")

	var/mob/living/basic/slime/pet_slime = allocate(/mob/living/basic/slime, protected_turf)
	var/mob/living/carbon/human/consistent/stored_body = allocate(/mob/living/carbon/human/consistent, protected_turf)
	stored_body.death()
	TEST_ASSERT_NULL(stored_body.mind, "The stored corpse must rely on area protection, not a player mind")
	var/mob/living/basic/neighbour_mob = allocate(/mob/living/basic, neighbour_turf)

	var/list/protected_area_types = list(
		/area/shuttle/voidcrew/phalanx/nanites/a,
		/area/shuttle/voidcrew/phalanx/medbay/a,
		/area/voidcrew/trader_outpost,
		/area/voidcrew/outpost_hangar,
		/area/voidcrew/player_outpost,
	)
	for(var/area_type in protected_area_types)
		// Ships are not singletons: look through all areas before creating a test fixture.
		var/area/protected_area = locate(area_type) in GLOB.areas
		if(!protected_area)
			protected_area = allocate(area_type)
		protected_turf.change_area(get_area(protected_turf), protected_area)
		var/mob/living/basic/surface_mob = allocate(/mob/living/basic, surface_turf)
		var/mob/living/carbon/human/consistent/surface_body = allocate(/mob/living/carbon/human/consistent, surface_turf)
		surface_body.death()
		tracker.populated = TRUE
		TEST_ASSERT_EQUAL(SSplanet_mobs.count_planet_mobs(tracker), 1, "[area_type]: ship/outpost animals counted as planet fauna")
		SSplanet_mobs.despawn_planet_mobs(tracker)
		TEST_ASSERT(!QDELETED(pet_slime), "[area_type]: cleanup deleted a protected slime")
		TEST_ASSERT(!QDELETED(stored_body), "[area_type]: cleanup deleted a stored human corpse")
		TEST_ASSERT(QDELETED(surface_mob) && QDELETED(surface_body), "[area_type]: cleanup stopped clearing ordinary planet mobs and corpses")
		TEST_ASSERT(!QDELETED(neighbour_mob), "[area_type]: cleanup escaped the planet footprint")
		TEST_ASSERT(!tracker.populated, "[area_type]: cleanup did not finish depopulating the planet")
