/// An analyzer with no research web still returns its window data with a sample loaded.
/datum/unit_test/voidcrew_analyzer_without_web

/datum/unit_test/voidcrew_analyzer_without_web/Run()
	var/mob/living/carbon/human/user = allocate(/mob/living/carbon/human/consistent)
	var/obj/machinery/rnd/destructive_analyzer/analyzer = allocate(/obj/machinery/rnd/destructive_analyzer)
	analyzer.connect_techweb(null)
	TEST_ASSERT_NULL(analyzer.stored_research, "The analyzer fixture kept a research web")
	var/obj/item/crowbar/sample = allocate(/obj/item/crowbar, analyzer)
	analyzer.loaded_item = sample

	var/list/data = analyzer.ui_data(user)
	TEST_ASSERT(islist(data), "An unlinked analyzer with a sample returned no window data")
	TEST_ASSERT(!data["server_connected"], "An unlinked analyzer reported a research server")
	var/list/static_data = analyzer.ui_static_data(user)
	TEST_ASSERT_NOTNULL(static_data["research_point_id"], "An unlinked analyzer returned no static window data")

	TEST_ASSERT(!analyzer.user_try_decon_id("research_points"), "An unlinked analyzer accepted a breakdown")
	TEST_ASSERT(!analyzer.destroy_item(TRUE), "An unlinked analyzer destroyed its sample")
	TEST_ASSERT_EQUAL(analyzer.loaded_item, sample, "An unlinked analyzer lost its sample")
	TEST_ASSERT(!QDELETED(sample), "An unlinked analyzer deleted its sample")

	// A web deleted out from under the analyzer counts as no web.
	var/datum/techweb/doomed = allocate(/datum/techweb)
	analyzer.stored_research = doomed
	qdel(doomed)
	data = analyzer.ui_data(user)
	TEST_ASSERT(!data["server_connected"], "An analyzer reported a deleted research web as a server")
	analyzer.stored_research = null
	analyzer.unload_item()

/**
 * A built analyzer aboard a ship links to that ship's server with a plain left-click of the
 * server's multitool, and loses the link again when the source disk comes out.
 * Uses the one-tile ship from voidcrew_research_lifecycle.dm.
 */
/datum/unit_test/voidcrew_experiment_reward_fixture/analyzer_ship_link/Run()
	var/obj/structure/overmap/ship/ship = make_reward_ship(run_loc_floor_bottom_left)
	var/mob/living/carbon/human/user = allocate(/mob/living/carbon/human/consistent)
	user.set_combat_mode(FALSE)
	var/obj/machinery/rnd/server/ship/server = allocate(/obj/machinery/rnd/server/ship)
	var/datum/techweb/web = install_reward_disk(server, user)
	var/obj/machinery/rnd/destructive_analyzer/analyzer = allocate(/obj/machinery/rnd/destructive_analyzer)
	TEST_ASSERT_EQUAL(get_research_service_site(analyzer), ship, "The analyzer fixture is not aboard the ship")

	var/obj/item/multitool/tool = allocate(/obj/item/multitool)
	user.put_in_active_hand(tool)
	server.multitool_act(user, tool)
	TEST_ASSERT_EQUAL(tool.buffer, web, "The ship server did not copy its web to the multitool")

	// Powered, idle and closed, so the analyzer would accept a sample.
	analyzer.set_is_operational(TRUE)
	analyzer.machine_stat = NONE
	click_wrapper(user, analyzer)
	TEST_ASSERT_EQUAL(analyzer.stored_research, web, "A left-click with the server's multitool did not link the analyzer")
	TEST_ASSERT_NULL(analyzer.loaded_item, "A left-click with the server's multitool loaded it as a sample")
	TEST_ASSERT_EQUAL(tool.loc, user, "Linking took the multitool out of the user's hand")

	// Once linked to that web, the same multitool is just a sample again.
	click_wrapper(user, analyzer)
	TEST_ASSERT_EQUAL(analyzer.loaded_item, tool, "A multitool for the already linked web was not loaded as a sample")
	TEST_ASSERT_EQUAL(analyzer.stored_research, web, "Loading a sample changed the analyzer's link")
	var/list/data = analyzer.ui_data(user)
	TEST_ASSERT(data["server_connected"], "A linked analyzer reported no research server")

	server.source_code_hdd.forceMove(run_loc_floor_bottom_left)
	TEST_ASSERT_NULL(analyzer.stored_research, "Removing the source disk left the analyzer linked")
	data = analyzer.ui_data(user)
	TEST_ASSERT(!data["server_connected"], "An analyzer whose disk was removed reported a research server")
	TEST_ASSERT_EQUAL(analyzer.loaded_item, tool, "Removing the source disk lost the analyzer's sample")
	analyzer.busy = FALSE
	analyzer.unload_item()
