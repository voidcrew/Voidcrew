/**
 * Standard hangar berths are crew-only.
 *
 * Only the berthed ship's crew can send the elevator down to it. Anyone riding with
 * them comes along, but the crew member who pressed the button must still be in the
 * car, awake, when it leaves. Anyone can leave a berth, and anyone can enter once the
 * ship is abandoned. The outpost owner gets no exception.
 */
/datum/unit_test/voidcrew_outpost_berth_access
	parent_type = /datum/unit_test/voidcrew_outpost_management
	/// Bare mobile port standing in for the visiting hull; docking ports only delete when forced.
	var/obj/docking_port/mobile/voidcrew/fake_port

/datum/unit_test/voidcrew_outpost_berth_access/Destroy()
	if(fake_port && !QDELETED(fake_port))
		if(fake_port.current_ship)
			fake_port.current_ship.shuttle = null
		fake_port.current_ship = null
		qdel(fake_port, force = TRUE)
	fake_port = null
	return ..()

/datum/unit_test/voidcrew_outpost_berth_access/Run()
	var/obj/structure/overmap/dynamic/player_outpost/home = allocate(__IMPLIED_TYPE__)
	home.shell_template = allocate(/datum/map_template/player_outpost/small)
	home.founder_ckey = "berthaccessowner"
	TEST_ASSERT(home.load_level(), "Could not load the berth access test outpost")
	TEST_ASSERT(home.has_hangar_elevator(), "The berth access test outpost has no hangar elevator")
	var/obj/machinery/outpost_elevator/lobby_panel = home.lobby_panels[1]
	var/list/turf/lobby_car = home.lobby_alcove_turfs
	var/turf/outside = get_turf(home.management_console)

	var/obj/structure/overmap/ship/ship = allocate(/obj/structure/overmap/ship)
	fake_port = new(run_loc_floor_bottom_left)
	fake_port.width = 5
	fake_port.height = 7
	fake_port.dwidth = 2
	fake_port.dheight = 0
	fake_port.port_direction = NORTH
	fake_port.current_ship = ship
	ship.shuttle = fake_port
	ship.ship_team = new /datum/team/voidcrew
	var/datum/outpost_berth/berth = home.allocate_berth(ship)
	TEST_ASSERT_NOTNULL(berth, "No standard berth for the test ship")
	var/floor_id = berth.berth_number
	var/list/turf/berth_car = berth.alcove_turfs

	var/mob/living/carbon/human/crew = make_player(lobby_car[1], "berthaccesscrew")
	ship.ship_team.add_member(crew.mind)
	var/mob/living/carbon/human/stranger = make_player(lobby_car[2], "berthaccessstranger")
	var/mob/living/carbon/human/owner = make_player(outside, "berthaccessowner")

	TEST_ASSERT(berth.allows_entry(crew), "The crew cannot enter their own berth")
	TEST_ASSERT(!berth.allows_entry(stranger), "A stranger can enter another crew's berth")
	TEST_ASSERT(!berth.allows_entry(owner), "The outpost owner can enter a visiting ship's berth")
	var/list/crew_floor = berth_floor(lobby_panel, crew, floor_id)
	TEST_ASSERT(crew_floor["your_ship"] && !crew_floor["locked"], "The crew's own berth is not open to them in the elevator")
	var/list/stranger_floor = berth_floor(lobby_panel, stranger, floor_id)
	TEST_ASSERT(stranger_floor["locked"], "The elevator does not show a stranger that the berth is locked")

	// Only the crew can send the car down.
	press(lobby_panel, stranger, floor_id)
	TEST_ASSERT(!lobby_panel.moving, "A stranger sent the elevator to another crew's berth")
	press(lobby_panel, crew, floor_id)
	TEST_ASSERT(lobby_panel.moving, "The crew could not send the elevator to their own berth")
	deltimer(lobby_panel.move_timer)
	lobby_panel.move_timer = null
	lobby_panel.moving = FALSE

	// A guest riding with the crew comes along.
	lobby_panel.complete_ride(floor_id, WEAKREF(crew))
	TEST_ASSERT(get_turf(crew) in berth_car, "The crew did not reach their berth")
	TEST_ASSERT(get_turf(stranger) in berth_car, "A guest riding with the crew was left behind")

	// Anyone can leave.
	crew.forceMove(outside)
	press(berth.panel, stranger, 0)
	TEST_ASSERT(berth.panel.moving, "A guest could not ride back up to the concourse")
	deltimer(berth.panel.move_timer)
	berth.panel.move_timer = null
	berth.panel.moving = FALSE
	berth.panel.complete_ride(0, WEAKREF(stranger))
	TEST_ASSERT(get_turf(stranger) in lobby_car, "A guest did not reach the concourse")

	// The car refuses to leave once the crew member who pressed the button steps out.
	stranger.forceMove(lobby_car[2])
	lobby_panel.complete_ride(floor_id, WEAKREF(crew))
	TEST_ASSERT(get_turf(stranger) in lobby_car, "A stranger rode down alone after the crew member stepped out")

	// Or is knocked out.
	crew.forceMove(lobby_car[1])
	crew.set_stat(UNCONSCIOUS)
	lobby_panel.complete_ride(floor_id, WEAKREF(crew))
	crew.set_stat(CONSCIOUS)
	TEST_ASSERT(get_turf(stranger) in lobby_car, "A stranger rode down with an unconscious crew member")
	crew.forceMove(outside)

	// An abandoned ship is open to anyone.
	ship.abandoned = TRUE
	TEST_ASSERT(berth.allows_entry(stranger), "An abandoned ship's berth stayed locked")
	stranger_floor = berth_floor(lobby_panel, stranger, floor_id)
	TEST_ASSERT(!stranger_floor["locked"], "The elevator still shows an abandoned ship's berth as locked")
	lobby_panel.complete_ride(floor_id, WEAKREF(stranger))
	TEST_ASSERT(get_turf(stranger) in berth_car, "A stranger could not ride down to an abandoned ship")
	ship.abandoned = FALSE

	// Leaving the crew takes access away.
	ship.ship_team.remove_member(crew.mind)
	TEST_ASSERT(!berth.allows_entry(crew), "A former crew member can still enter the berth")

	berth.release(force = TRUE)

/// Presses a floor button the way the UI does.
/datum/unit_test/voidcrew_outpost_berth_access/proc/press(obj/machinery/outpost_elevator/panel, mob/user, floor_id)
	var/datum/tgui/ui = allocate(/datum/tgui, user, panel, "OutpostElevator")
	panel.ui_act("goto", list("id" = "[floor_id]"), ui)

/// The floor entry a user sees for one floor id.
/datum/unit_test/voidcrew_outpost_berth_access/proc/berth_floor(obj/machinery/outpost_elevator/panel, mob/user, floor_id)
	var/list/data = panel.ui_data(user)
	for(var/list/floor as anything in data["floors"])
		if(floor["id"] == floor_id)
			return floor
	TEST_FAIL("Floor [floor_id] is missing from the elevator")
	return list()
