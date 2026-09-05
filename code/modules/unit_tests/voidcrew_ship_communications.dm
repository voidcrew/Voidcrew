/// Two ships and the surrounding station share a z-level. Commands must stay aboard.
/datum/unit_test/voidcrew_ship_communications
	var/list/original_areas = list()
	var/list/ship_areas = list()
	var/list/ships = list()
	var/list/test_players = list()

/datum/unit_test/voidcrew_ship_communications/Destroy()
	GLOB.player_list -= test_players
	for(var/obj/docking_port/mobile/ship as anything in ships)
		qdel(ship, force = TRUE)
	for(var/turf/changed_turf as anything in original_areas)
		changed_turf.change_area(get_area(changed_turf), original_areas[changed_turf])
	QDEL_LIST(ship_areas)
	return ..()

/datum/unit_test/voidcrew_ship_communications/proc/make_ship(turf/ship_turf)
	var/area/shuttle/ship_area = new
	ship_areas += ship_area
	original_areas[ship_turf] = get_area(ship_turf)
	ship_turf.change_area(get_area(ship_turf), ship_area)
	var/obj/docking_port/mobile/ship = new(ship_turf, list(ship_area))
	ships += ship
	ship.register()
	return ship

/datum/unit_test/voidcrew_ship_communications/Run()
	var/turf/first_turf = run_loc_floor_bottom_left
	var/turf/second_turf = get_step(first_turf, EAST)
	var/turf/shore_turf = get_step(second_turf, EAST)
	var/obj/docking_port/mobile/first_ship = make_ship(first_turf)
	var/obj/docking_port/mobile/second_ship = make_ship(second_turf)
	var/obj/machinery/computer/communications/first_console = allocate(/obj/machinery/computer/communications, first_turf)
	var/obj/machinery/computer/communications/other_console = allocate(/obj/machinery/computer/communications, first_turf)
	var/obj/machinery/computer/communications/syndicate/second_console = allocate(/obj/machinery/computer/communications/syndicate, second_turf)
	var/mob/living/basic/first_player = allocate(/mob/living/basic, first_turf)
	var/mob/living/basic/second_player = allocate(/mob/living/basic, second_turf)
	var/mob/living/basic/shore_player = allocate(/mob/living/basic, shore_turf)
	test_players = list(first_player, second_player, shore_player)
	GLOB.player_list |= test_players

	var/list/receivers = first_console.get_communication_players()
	TEST_ASSERT(first_player in receivers, "The ship's own crew did not receive its announcement")
	TEST_ASSERT(!(second_player in receivers), "Announcements reached another ship on the same z-level")
	TEST_ASSERT(!(shore_player in receivers), "Announcements reached someone outside the hull")
	TEST_ASSERT_EQUAL(length(voidcrew_announcement_players(null)), 0, "A missing source broadcast globally")
	receivers = second_console.get_communication_players()
	TEST_ASSERT(second_player in receivers, "Syndicate consoles lost their own crew")
	TEST_ASSERT(!(first_player in receivers), "Syndicate announcements leaked to another ship")
	var/news_count = GLOB.news_network.message_count
	priority_announce("Private ship announcement", type = ANNOUNCEMENT_TYPE_CAPTAIN, players = first_console.get_communication_players())
	TEST_ASSERT_EQUAL(GLOB.news_network.message_count, news_count, "A local captain announcement was published to the global news feed")

	// Moving aboard changes the audience immediately, regardless of crew membership.
	second_player.forceMove(first_turf)
	receivers = first_console.get_communication_players()
	TEST_ASSERT(second_player in receivers, "A visitor aboard could not hear local announcements")
	second_player.forceMove(second_turf)

	var/datum/communciations_controller/first_controller = first_console.get_announcement_controller()
	var/datum/communciations_controller/second_controller = second_console.get_announcement_controller()
	TEST_ASSERT_EQUAL(first_controller, other_console.get_announcement_controller(), "Consoles on one ship did not share cooldowns")
	COOLDOWN_START(first_controller, nonsilicon_message_cooldown, 30 SECONDS)
	COOLDOWN_START(first_controller, silicon_message_cooldown, 30 SECONDS)
	TEST_ASSERT(!first_controller.can_announce(first_player, FALSE), "Captain announcement cooldown was not enforced")
	TEST_ASSERT(!first_controller.can_announce(first_player, TRUE), "AI announcement cooldown was not enforced")
	TEST_ASSERT(second_controller.can_announce(second_player, FALSE), "Another ship's captain was blocked by our cooldown")
	TEST_ASSERT(second_controller.can_announce(second_player, TRUE), "Another ship's AI was blocked by our cooldown")

	var/obj/machinery/status_display/evac/first_display = allocate(/obj/machinery/status_display/evac, first_turf)
	var/obj/machinery/status_display/evac/second_display = allocate(/obj/machinery/status_display/evac, second_turf)
	first_console.post_status("message", "LOCAL", "ONLY")
	TEST_ASSERT_EQUAL(first_display.message1, "LOCAL", "The local status display did not receive the command")
	TEST_ASSERT(second_display.message1 != "LOCAL", "The status command changed another ship's display")
	TEST_ASSERT_EQUAL(other_console.get_status_display_message()?[1], "LOCAL", "Another console aboard did not remember the status message")
	TEST_ASSERT_NULL(second_console.get_status_display_message(), "Another ship inherited our saved status message")

	var/global_security_level = SSsecurity_level.get_current_level_as_number()
	first_console.post_status("alert", "greenalert")
	second_console.post_status("alert", "greenalert")
	first_console.set_communications_security_level(SEC_LEVEL_BLUE)
	TEST_ASSERT_EQUAL(first_ship.comms_security_level, SEC_LEVEL_BLUE, "The ship's alert level did not change")
	TEST_ASSERT_EQUAL(second_ship.comms_security_level, SEC_LEVEL_GREEN, "The alert change affected another ship")
	TEST_ASSERT_EQUAL(SSsecurity_level.get_current_level_as_number(), global_security_level, "A console aboard a ship changed the global alert level")
	TEST_ASSERT_EQUAL(first_display.last_picture, "bluealert", "The local alert display did not follow the new level")
	TEST_ASSERT_EQUAL(second_display.last_picture, "greenalert", "The alert change reached another ship's display")

	var/obj/machinery/door/airlock/first_door = allocate(/obj/machinery/door/airlock, first_turf)
	var/obj/machinery/door/airlock/second_door = allocate(/obj/machinery/door/airlock, second_turf)
	first_door.req_access = list(ACCESS_MAINT_TUNNELS)
	second_door.req_access = list(ACCESS_MAINT_TUNNELS)
	var/global_emergency_access = GLOB.emergency_access
	make_maint_all_access(first_console)
	TEST_ASSERT(first_door.emergency, "Emergency maintenance access did not open local maintenance doors")
	TEST_ASSERT(!second_door.emergency, "Emergency maintenance access opened another ship's doors")
	TEST_ASSERT(other_console.get_communications_emergency_access(), "Other consoles aboard did not see emergency access enabled")
	TEST_ASSERT(!second_console.get_communications_emergency_access(), "Emergency access state leaked to another ship")
	TEST_ASSERT_EQUAL(GLOB.emergency_access, global_emergency_access, "Ship emergency access changed global state")
	revoke_maint_all_access(other_console)
	TEST_ASSERT(!first_door.emergency, "A second console aboard could not revoke emergency access")
