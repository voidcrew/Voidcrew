/// The Outpost Manipulator's free checkpoint tools, on a real hull in a real bay.
/datum/unit_test/voidcrew_outpost_admin_checkpoints
	parent_type = /datum/unit_test/voidcrew_outpost_management
	var/list/obj/structure/overmap/ship/test_ships = list()

/datum/unit_test/voidcrew_outpost_admin_checkpoints/Destroy()
	for(var/obj/structure/overmap/ship/ship as anything in test_ships)
		if(!QDELETED(ship))
			qdel(ship)
	return ..()

/datum/unit_test/voidcrew_outpost_admin_checkpoints/proc/dock_in_bay(obj/structure/overmap/dynamic/player_outpost/home, obj/structure/overmap/ship/ship)
	var/datum/outpost_berth/ship_bay/bay = home.allocate_ship_bay(ship)
	TEST_ASSERT_NOTNULL(bay, "Could not allocate the bay for [ship]")
	adjust_reserve_dock_to_shuttle(bay.dock, ship.shuttle)
	ship.shuttle.mode = SHUTTLE_PREARRIVAL
	ship.shuttle.initiate_docking(bay.dock)
	ship.shuttle.mode = SHUTTLE_IDLE
	ship.docked = home
	ship.forceMove(home)
	ship.state = "idle"
	bay.on_ship_docked(ship)
	TEST_ASSERT(bay.is_ship_present(), "[ship] did not land in the bay")
	return bay

/datum/unit_test/voidcrew_outpost_admin_checkpoints/proc/send_to_transit(obj/structure/overmap/dynamic/player_outpost/home, obj/structure/overmap/ship/ship)
	var/obj/docking_port/stationary/transit/transit = ship.shuttle.assigned_transit || SSshuttle.generate_transit_dock(ship.shuttle)
	ship.shuttle.mode = SHUTTLE_PREARRIVAL
	TEST_ASSERT_EQUAL(ship.shuttle.initiate_docking(transit), DOCKING_SUCCESS, "[ship] could not leave the bay")
	ship.shuttle.mode = SHUTTLE_IDLE
	ship.docked = null
	ship.forceMove(get_turf(home))
	ship.state = "flying"
	home.on_ship_undock_complete(ship)

/// Waits for a rushed job to reach commissioning, or to finish outright.
/datum/unit_test/voidcrew_outpost_admin_checkpoints/proc/wait_for_hull(datum/checkpoint_construction/job)
	var/deadline = world.time + 60 SECONDS
	while(!QDELETED(job) && job.state != "commissioning" && world.time < deadline)
		sleep(2)
	TEST_ASSERT(QDELETED(job) || job.state == "commissioning", "A rushed rebuild did not finish placing within a minute")

/datum/unit_test/voidcrew_outpost_admin_checkpoints/Run()
	var/obj/structure/overmap/dynamic/player_outpost/home = allocate(__IMPLIED_TYPE__)
	home.shell_template = allocate(/datum/map_template/player_outpost/test_fixture)
	home.founder_ckey = "checkpointfounder"
	TEST_ASSERT(home.load_level(), "The outpost did not load")
	TEST_ASSERT_NULL(home.enable_ship_bays(), "The ship bay did not load")
	var/mob/living/carbon/human/operator = make_player(run_loc_floor_bottom_left, "checkpointadmin")
	var/datum/outpost_manipulator/unit_test/bays/panel = allocate(__IMPLIED_TYPE__, operator)
	panel.selected = home
	var/datum/outpost_berth/ship_bay/bay = home.bay_berths[1]
	var/list/bay_rooms = list()
	for(var/turf/tile as anything in bay.get_block())
		bay_rooms[tile] = tile.loc

	var/obj/structure/overmap/ship/original = SSshuttle.create_ship(/datum/map_template/shuttle/voidcrew/box)
	TEST_ASSERT_NOTNULL(original, "Could not create the source hull")
	test_ships += original
	original.ship_account.account_balance = 1234
	dock_in_bay(home, original)
	var/before_treasury = home.treasury.account_balance

	panel.allow_actions = FALSE
	panel.manage_outpost(home, operator, "checkpoint_rebuild_docked", list())
	TEST_ASSERT(!length(home.checkpoints) && !QDELETED(original), "A revoked admin panel used the checkpoint tools")
	panel.allow_actions = TRUE

	// Free saves: no fee, no captain, one per owner and one per ship.
	var/datum/ship_checkpoint/first = panel.save_free_checkpoint(home, operator, original, "freeowner")
	TEST_ASSERT_NOTNULL(first, "Free save failed: [panel.error]")
	TEST_ASSERT_EQUAL(first.captain_ckey, "freeowner", "The free checkpoint has the wrong owner")
	TEST_ASSERT_EQUAL(original.ship_account.account_balance, 1234, "A free save charged the ship")
	TEST_ASSERT_EQUAL(home.treasury.account_balance, before_treasury, "A free save touched the treasury")
	var/datum/ship_checkpoint/second = panel.save_free_checkpoint(home, operator, original, "freeowner")
	TEST_ASSERT(second && QDELETED(first) && length(home.checkpoints) == 1, "Saving again did not replace the owner's checkpoint")
	TEST_ASSERT_EQUAL(original.checkpoint_ref?.resolve(), second, "The ship is not linked to its checkpoint")
	TEST_ASSERT_NULL(panel.save_free_checkpoint(home, operator, original, "otherowner"), "One ship was saved for two owners")
	TEST_ASSERT(!panel.admin_rebuild(home, operator, second), "A rebuild started while the original filled the bay")

	// Removing the docked ship moves people out and gives the pad back its own room.
	var/turf/deck
	for(var/turf/open/floor/tile in original.shuttle.return_turfs())
		if(get_area(tile) in original.shuttle.shuttle_areas)
			deck = tile
			break
	var/mob/living/carbon/human/crew = make_player(deck, "checkpointcrew")
	// A deleted duct drops a stack of duct; none of that may be left on the pad.
	new /obj/machinery/duct(deck)
	var/list/pad = original.shuttle.return_turfs()
	panel.manage_outpost(home, operator, "bay_remove_ship", list("ref" = REF(bay)))
	for(var/turf/tile as anything in pad)
		var/obj/item/debris = locate() in tile
		if(debris)
			TEST_FAIL("Remove Ship left [debris] on the pad at [tile.x],[tile.y]")
			break
	TEST_ASSERT(QDELETED(original), "Remove Ship left the hull: [panel.error]")
	TEST_ASSERT(crew.stat != DEAD && (get_turf(crew) in bay.alcove_turfs), "Someone aboard was not moved to the bay elevator")
	TEST_ASSERT(bay.is_available(), "The bay was not released after removing its ship")
	for(var/turf/tile as anything in bay_rooms)
		if(tile.loc != bay_rooms[tile])
			TEST_FAIL("Bay tile [tile.x],[tile.y] kept [tile.loc] instead of its own hangar room")
			break
	crew.key = null

	// A lost original: the normal rebuild, rushed and handed over to an absent owner.
	panel.manage_outpost(home, operator, "checkpoint_rebuild", list("ref" = REF(second)))
	TEST_ASSERT_EQUAL(length(home.checkpoint_jobs), 1, "The admin rebuild did not start: [panel.error]")
	var/datum/checkpoint_construction/job = home.checkpoint_jobs[1]
	TEST_ASSERT(!job.manual, "Admin rebuilds must run on the real controller")
	var/list/fleet = job.drones.Copy()
	panel.manage_outpost(home, operator, "rebuild_rush", list("ref" = REF(job)))
	TEST_ASSERT(job.rushed && job.state == "building", "Finish Now did not skip the survey")
	wait_for_hull(job)
	TEST_ASSERT(QDELETED(job), "The finished hull was not handed over at once")
	var/obj/structure/overmap/ship/rebuilt = bay.ship
	TEST_ASSERT_NOTNULL(rebuilt, "The rebuilt hull did not take the bay")
	test_ships += rebuilt
	TEST_ASSERT(rebuilt.abandoned, "A hull nobody collected cannot be claimed")
	TEST_ASSERT(!length(home.checkpoints), "The admin rebuild did not use up the checkpoint")
	var/deadline = world.time + 30 SECONDS
	var/drones_left = TRUE
	while(drones_left && world.time < deadline)
		drones_left = FALSE
		for(var/obj/effect/checkpoint_build_drone/drone as anything in fleet)
			if(!QDELETED(drone))
				drones_left = TRUE
		if(drones_left)
			sleep(2)
	TEST_ASSERT(!drones_left, "Drones did not go home after the build")

	// An original still in service is left alone: the rebuild is an extra copy.
	rebuilt.abandoned = FALSE
	rebuilt.ship_account.account_balance = 777
	var/datum/ship_checkpoint/copy_source = panel.save_free_checkpoint(home, operator, rebuilt, "copyowner")
	TEST_ASSERT_NOTNULL(copy_source, "Could not save the rebuilt ship: [panel.error]")
	send_to_transit(home, rebuilt)
	TEST_ASSERT(panel.admin_rebuild(home, operator, copy_source), "The copy rebuild did not start: [panel.error]")
	job = home.checkpoint_jobs[1]
	TEST_ASSERT_NULL(job.original_ref, "A copy rebuild took over the ship in service")
	job.rush()
	wait_for_hull(job)
	TEST_ASSERT(QDELETED(job), "The finished copy was not handed over at once")
	TEST_ASSERT(!rebuilt.retired_by_checkpoint && rebuilt.ship_account.account_balance == 777, "A copy rebuild retired or charged the original")
	var/obj/structure/overmap/ship/copy = bay.ship
	TEST_ASSERT(copy && copy != rebuilt, "The finished copy did not take the bay")
	test_ships += copy
	TEST_ASSERT(!length(home.checkpoints), "The copy rebuild did not use up its checkpoint")
	TEST_ASSERT_NULL(rebuilt.checkpoint_ref?.resolve(), "The original kept a link to a used checkpoint")
	TEST_ASSERT(panel.remove_docked_ship(home, operator, bay, copy), "The copy could not be removed from the bay: [panel.error]")
	TEST_ASSERT(bay.is_available(), "Removing the copy did not free the bay")

	// Stop before the first piece: the bay is freed and the checkpoint kept.
	var/datum/ship_checkpoint/stop_source = panel.save_free_checkpoint(home, operator, rebuilt, "copyowner")
	TEST_ASSERT_NOTNULL(stop_source, "Could not save the ship to test Stop: [panel.error]")
	TEST_ASSERT(panel.admin_rebuild(home, operator, stop_source), "The rebuild to stop did not start: [panel.error]")
	job = home.checkpoint_jobs[1]
	TEST_ASSERT(!job.committed, "The rebuild placed a piece before it could be stopped")
	panel.manage_outpost(home, operator, "rebuild_stop", list("ref" = REF(job)))
	TEST_ASSERT(QDELETED(job) && bay.is_available(), "Stop did not end the build and free the bay")
	TEST_ASSERT(!QDELETED(stop_source) && !stop_source.busy, "Stop before the first piece lost the checkpoint")
	qdel(stop_source)

	// One click: save the docked ship, delete it and rebuild it for its owner.
	dock_in_bay(home, rebuilt)
	panel.manage_outpost(home, operator, "checkpoint_rebuild_docked", list())
	TEST_ASSERT(QDELETED(rebuilt), "Rebuild Docked Ship kept the old hull: [panel.error]")
	TEST_ASSERT_EQUAL(length(home.checkpoint_jobs), 1, "Rebuild Docked Ship did not start a rebuild: [panel.error]")
	job = home.checkpoint_jobs[1]
	TEST_ASSERT_EQUAL(job.captain_ckey, operator.ckey, "An ownerless ship was not rebuilt for the admin")
	job.rush()
	wait_for_hull(job)
	if(!QDELETED(job))
		job.hand_over_now()
	TEST_ASSERT(QDELETED(job) && bay.ship, "The one-click rebuild did not finish")
	test_ships += bay.ship
	TEST_ASSERT_EQUAL(bay.ship.claimed_captain, operator.mind, "The one-click rebuild was not handed to its owner")
