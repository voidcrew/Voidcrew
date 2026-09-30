/// Exercise countdowns, arrivals, late occupants and admin readouts without sweeping test turfs.
/datum/unit_test/voidcrew_ruin_cleanup_timers
	var/list/obj/structure/overmap/space_ruin/sites = list()

/datum/unit_test/voidcrew_ruin_cleanup_timers/Destroy()
	for(var/obj/structure/overmap/space_ruin/site as anything in sites)
		if(QDELETED(site))
			continue
		site.cancel_despawn_timer()
		site.mapzone = null
		site.footprint = null
	return ..()

/datum/unit_test/voidcrew_ruin_cleanup_timers/Run()
	var/turf/inside = run_loc_floor_bottom_left
	var/turf/outside = get_step(inside, EAST)
	var/datum/map_zone/zone = allocate(/datum/map_zone)
	zone.z_levels = list(reservation)
	var/datum/map_footprint/footprint = allocate(/datum/map_footprint)
	footprint.z_value = inside.z
	footprint.set_rect(inside.x, inside.y, 1, 1)
	var/obj/structure/overmap/space_ruin/site = allocate(/obj/structure/overmap/space_ruin)
	sites += site
	site.mapzone = zone
	site.footprint = footprint
	site.loaded = TRUE

	site.check_start_despawn()
	var/datum/timedevent/countdown = SStimer.timer_id_dict[site.despawn_timer_id]
	TEST_ASSERT_NOTNULL(countdown, "An empty, unvisited ruin never armed a cleanup timer")
	// Voidcrew defines are included after unit tests, so spell the delays out here.
	TEST_ASSERT_EQUAL(countdown.wait, 15 MINUTES, "A survey-only ruin did not receive fifteen minutes")
	var/original_timer = site.despawn_timer_id
	site.load_level()
	TEST_ASSERT_EQUAL(site.despawn_timer_id, original_timer, "Refreshing an already loaded ruin reset its countdown")
	TEST_ASSERT(!site.visited, "Surveying marked a ruin as docked at")
	TEST_ASSERT_EQUAL(site.admin_status(), "Unload scheduled", "The ruin countdown was absent from Overmap Management")
	var/list/details = site.admin_cleanup_details()
	TEST_ASSERT_EQUAL(details["timer_label"], "Unload interior", "The ruin's countdown was not identified as an unload")
	TEST_ASSERT(details["seconds"] > 0 && details["seconds"] <= 900, "The admin countdown did not report its real remaining time")

	var/obj/structure/overmap/ship/visitor = allocate(/obj/structure/overmap/ship, outside)
	visitor.forceMove(site)
	TEST_ASSERT(site.visited, "A docked ship did not mark the ruin visited")
	TEST_ASSERT_NULL(site.despawn_timer_id, "A ship arriving failed to cancel cleanup")
	TEST_ASSERT_EQUAL(site.admin_status(), "Cleanup blocked", "A docked ship was still shown as scheduled for cleanup")
	visitor.forceMove(outside)
	site.check_start_despawn()
	countdown = SStimer.timer_id_dict[site.despawn_timer_id]
	TEST_ASSERT_NOTNULL(countdown, "The empty visited ruin did not restart its countdown")
	TEST_ASSERT_EQUAL(countdown.wait, 5 MINUTES, "A visited ruin did not receive five minutes")
	// The pending eligibility check must not hide the longer, armed countdown.
	details = site.admin_cleanup_details()
	TEST_ASSERT_EQUAL(details["timer_label"], "Unload interior", "An older retry obscured the cleanup countdown")

	var/mob/living/basic/body = allocate(/mob/living/basic, inside)
	body.mind_initialize()
	var/obj/structure/closet/container = allocate(/obj/structure/closet, inside)
	body.forceMove(container)
	site.cancel_despawn_timer()
	site.attempt_despawn()
	TEST_ASSERT(site.loaded && site.mapzone == zone && !QDELETED(body), "Countdown expiry deleted a newly arrived player body")
	TEST_ASSERT_NULL(site.despawn_timer_id, "A blocked ruin still had an unload countdown")
	TEST_ASSERT(length(site.admin_cleanup_timers()), "Refused cleanup never scheduled another eligibility check")
	container.forceMove(outside)
	site.check_start_despawn()
	countdown = SStimer.timer_id_dict[site.despawn_timer_id]
	TEST_ASSERT_NOTNULL(countdown, "A body leaving without a ship undocking did not allow cleanup")
	TEST_ASSERT_EQUAL(countdown.wait, 5 MINUTES, "Cleanup did not grant a fresh grace after the blocker left")

	site.first_dock_taken = TRUE
	site.check_start_despawn()
	TEST_ASSERT_NULL(site.despawn_timer_id, "A reserved berth did not stop cleanup")
	site.first_dock_taken = FALSE
	site.second_dock_taken = TRUE
	site.check_start_despawn()
	TEST_ASSERT_NULL(site.despawn_timer_id, "The secondary berth did not stop cleanup")
	site.second_dock_taken = FALSE
	site.check_start_despawn()
	site.mission_locked = TRUE
	site.cancel_despawn_timer()
	site.attempt_despawn()
	TEST_ASSERT(site.loaded && site.mapzone == zone, "A mission lock acquired during the countdown was ignored")
	site.check_start_despawn()
	TEST_ASSERT_NULL(site.despawn_timer_id, "An active mission armed automatic cleanup")
	site.mission_locked = FALSE
	site.mapzone = null
	site.footprint = null
	site.check_and_respawn()
	site.check_start_despawn()
	TEST_ASSERT(!QDELETED(site), "A stale cleanup callback deleted an unloaded contact")
	TEST_ASSERT_NULL(site.despawn_timer_id, "An unloaded ruin armed another countdown")

	for(var/site_type in list(/obj/structure/overmap/space_ruin/vestige, /obj/structure/overmap/space_ruin/contested_cache, /obj/structure/overmap/space_ruin/lich_lair))
		var/obj/structure/overmap/space_ruin/special = allocate(site_type)
		sites += special
		special.mapzone = zone
		special.footprint = footprint
		special.loaded = TRUE
		special.check_start_despawn()
		if(istype(special, /obj/structure/overmap/space_ruin/lich_lair))
			TEST_ASSERT_NULL(special.despawn_timer_id, "The persistent lich lair armed automatic cleanup")
			TEST_ASSERT_EQUAL(length(special.admin_cleanup_timers()), 0, "The lich lair started a cleanup retry loop")
		else
			TEST_ASSERT_NOTNULL(special.despawn_timer_id, "[site_type] did not monitor its empty interior")

/// A real load must arm cleanup even when no ship ever visits it.
/datum/unit_test/voidcrew_ruin_cleanup_load
	var/obj/structure/overmap/space_ruin/site

/datum/unit_test/voidcrew_ruin_cleanup_load/Destroy()
	if(!QDELETED(site))
		site.remove_docks()
		site.remove_mapzone()
	return ..()

/datum/unit_test/voidcrew_ruin_cleanup_load/Run()
	var/datum/map_template/ruin/space/template = allocate(/datum/map_template/ruin/space/empty_shell)
	site = allocate(/obj/structure/overmap/space_ruin, null, template)
	// Keep the contact after cleanup, as a recovery contract does, without blocking unloading.
	site.mission_claims = 1
	site.load_level()
	TEST_ASSERT(site.is_loaded(), "The test ruin could not load its real interior")
	TEST_ASSERT(!site.visited, "Loading alone marked the ruin visited")
	TEST_ASSERT_NOTNULL(site.despawn_timer_id, "A real load with no ship left the ruin without a cleanup timer")
	var/datum/map_zone/zone = site.mapzone
	var/datum/map_footprint/footprint = site.footprint
	var/slots_before = zone.used_slot_count()
	site.cancel_despawn_timer()
	site.attempt_despawn()
	TEST_ASSERT(!site.loaded && !site.mapzone && !site.footprint, "Timer expiry retained the empty ruin's interior")
	TEST_ASSERT(QDELETED(footprint), "Cleanup retained the ruin's map footprint")
	TEST_ASSERT_EQUAL(zone.used_slot_count(), slots_before - 1, "Cleanup did not release the ruin's map slot")
	TEST_ASSERT(!QDELETED(site), "Cleanup deleted a contact claimed by a mission")
	TEST_ASSERT_NULL(site.despawn_timer_id, "Unloading left a stale countdown")
	site.check_and_respawn()
	TEST_ASSERT_EQUAL(length(site.admin_cleanup_timers()), 0, "A stale callback started retrying an already unloaded ruin")
