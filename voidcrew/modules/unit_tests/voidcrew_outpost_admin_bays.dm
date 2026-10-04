/// Exercise modal races and administrative authorization without a real admin client.
/datum/outpost_manipulator/unit_test/bays
	var/datum/callback/during_confirmation
	var/accept_confirmation = TRUE
	var/list/operations = list()

/datum/outpost_manipulator/unit_test/bays/confirm(obj/structure/overmap/dynamic/player_outpost/home, mob/user, prompt)
	during_confirmation?.Invoke()
	return accept_confirmation

/datum/outpost_manipulator/unit_test/bays/record(mob/user, obj/structure/overmap/dynamic/player_outpost/home, operation)
	operations += operation

/datum/unit_test/voidcrew_outpost_admin_bays
	parent_type = /datum/unit_test/voidcrew_outpost_management

/datum/unit_test/voidcrew_outpost_admin_bays/proc/revoke_admin(datum/outpost_manipulator/unit_test/panel)
	panel.allow_actions = FALSE

/datum/unit_test/voidcrew_outpost_admin_bays/proc/request_bay(obj/structure/overmap/dynamic/player_outpost/home, obj/structure/overmap/ship/ship)
	home.pending_dock_variants[ship] = "ship_bay"

/datum/unit_test/voidcrew_outpost_admin_bays/Run()
	var/obj/structure/overmap/dynamic/player_outpost/home = allocate(__IMPLIED_TYPE__)
	home.shell_template = allocate(/datum/map_template/player_outpost/test_fixture)
	home.founder_ckey = "anotherowner"
	TEST_ASSERT(home.load_level(), "The admin bay outpost could not load")
	var/mob/living/operator = make_player(run_loc_floor_bottom_left, "bayadministrator")
	var/datum/outpost_manipulator/unit_test/bays/panel = allocate(__IMPLIED_TYPE__, operator)
	panel.selected = home
	var/datum/outpost_manipulator/unauthorized = allocate(__IMPLIED_TYPE__, operator)
	unauthorized.selected = home
	unauthorized.manage_ship_bays(home, operator, "install_bays", list())
	TEST_ASSERT(!home.ship_bay_installed, "A non-admin used the administrative bay grant")
	panel.allow_actions = FALSE
	panel.manage_outpost(home, operator, "install_bays", list())
	TEST_ASSERT(!home.ship_bay_installed, "A revoked admin panel installed ship bays")
	panel.allow_actions = TRUE
	home.loading = TRUE
	panel.manage_outpost(home, operator, "install_bays", list())
	TEST_ASSERT(!home.ship_bay_installed, "Ship bays were installed during an outpost load")
	home.loading = FALSE
	var/obj/machinery/ore_silo/home_silo = home.ship_bay_silo()
	TEST_ASSERT_NOTNULL(home_silo, "The starter silo could not be found")
	var/before_balance = home.treasury.account_balance
	var/before_iron = home_silo.materials.get_material_amount(/datum/material/iron)
	panel.manage_outpost(home, operator, "install_bays", list())
	TEST_ASSERT(home.ship_bay_installed && length(home.bay_berths) == 1, "Admin grant did not enable the single permanent bay")
	TEST_ASSERT_EQUAL(home.treasury.account_balance, before_balance, "Admin installation charged credits")
	TEST_ASSERT_EQUAL(home_silo.materials.get_material_amount(/datum/material/iron), before_iron, "Admin installation consumed materials")
	TEST_ASSERT_EQUAL(length(panel.operations), 1, "Admin installation was not logged exactly once")
	panel.manage_outpost(home, operator, "install_bays", list())
	TEST_ASSERT_EQUAL(length(panel.operations), 1, "Repeated installation logged a second successful grant")
	var/list/data = panel.ship_bay_data(home)
	TEST_ASSERT_EQUAL(length(data["slots"]), 1, "The admin UI hides empty installed bays")
	var/list/first_slot = data["slots"][1]
	TEST_ASSERT_EQUAL(first_slot["status"], "Available", "An empty bay is incorrectly marked occupied")

	var/datum/ship_checkpoint/snapshot = allocate(__IMPLIED_TYPE__)
	snapshot.outpost = home
	home.checkpoints += snapshot
	panel.manage_outpost(home, operator, "remove_bays", list())
	TEST_ASSERT(home.ship_bay_installed, "Admin removal stranded a paid hull registration")
	qdel(snapshot)
	var/obj/structure/overmap/ship/ship = allocate(__IMPLIED_TYPE__)
	SSovermap.simulated_ships |= ship
	panel.during_confirmation = CALLBACK(src, PROC_REF(request_bay), home, ship)
	panel.manage_outpost(home, operator, "remove_bays", list())
	TEST_ASSERT(home.ship_bay_installed, "Removal ignored a docking request made during confirmation")
	home.pending_dock_variants.Cut()
	panel.during_confirmation = CALLBACK(src, PROC_REF(revoke_admin), panel)
	panel.manage_outpost(home, operator, "remove_bays", list())
	TEST_ASSERT(home.ship_bay_installed, "Removal continued after admin rights were revoked")
	panel.allow_actions = TRUE
	panel.during_confirmation = null
	panel.accept_confirmation = FALSE
	panel.manage_outpost(home, operator, "remove_bays", list())
	TEST_ASSERT(home.ship_bay_installed, "Cancelled removal still removed the upgrade")
	panel.accept_confirmation = TRUE

	visitor_port = new(run_loc_floor_bottom_left)
	visitor_port.width = 1
	visitor_port.height = 1
	visitor_port.dwidth = 0
	visitor_port.dheight = 0
	visitor_port.current_ship = ship
	ship.shuttle = visitor_port
	ship.ship_team = new /datum/team/voidcrew
	var/datum/outpost_berth/ship_bay/bay = home.allocate_ship_bay(ship)
	TEST_ASSERT_NOTNULL(bay, "The admin-installed bay could not allocate a real reservation")
	TEST_ASSERT_NOTNULL(panel.bay_removal_denial(home), "An arriving ship's bay could be removed")
	panel.manage_outpost(home, operator, "bay_grant_materials", list("ref" = REF(bay)))
	TEST_ASSERT_NULL(bay.approved_silo, "An approaching ship received material access")
	visitor_turf = get_turf(bay.dock)
	original_visitor_area = get_area(visitor_turf)
	visitor_area = new
	visitor_turf.change_area(original_visitor_area, visitor_area)
	visitor_port.forceMove(visitor_turf)
	visitor_port.shuttle_areas = list()
	visitor_port.shuttle_areas[visitor_area] = TRUE
	visitor_area.shuttle_port = visitor_port
	visitor_port.register()
	ship.docked = home
	ship.state = "idle"
	var/obj/machinery/ore_silo/ship_silo = allocate(__IMPLIED_TYPE__, visitor_turf)
	bay.on_ship_docked(ship)
	TEST_ASSERT(!home.can_spend(operator) && !bay.console.is_crew_member(operator), "The admin fixture unexpectedly owns the claim or ship")
	panel.manage_outpost(home, operator, "bay_select_silo", list("ref" = REF(ship_silo)))
	TEST_ASSERT_NOTNULL(panel.error, "A visiting ship's silo was selected as outpost storage")
	panel.manage_outpost(home, operator, "bay_select_silo", list("ref" = REF(home_silo)))
	TEST_ASSERT_EQUAL(home.service_silo?.resolve(), home_silo, "Admin material-source selection failed")
	panel.manage_outpost(home, operator, "bay_grant_materials", list("ref" = REF(bay)))
	TEST_ASSERT_EQUAL(bay.approved_silo?.resolve(), home_silo, "An authorized admin could not grant outpost materials")
	TEST_ASSERT_EQUAL(bay.console.get_linked_silo(), home_silo, "The administrative grant did not connect the tools")
	panel.manage_outpost(home, operator, "bay_revoke_materials", list("ref" = REF(panel)))
	TEST_ASSERT_EQUAL(bay.approved_silo?.resolve(), home_silo, "An unrelated reference changed the bay's permissions")
	panel.allow_actions = FALSE
	panel.manage_outpost(home, operator, "bay_revoke_materials", list("ref" = REF(bay)))
	TEST_ASSERT_EQUAL(bay.approved_silo?.resolve(), home_silo, "A revoked admin panel changed bay permissions")
	panel.allow_actions = TRUE
	var/obj/machinery/ore_silo/second_silo = allocate(__IMPLIED_TYPE__, get_turf(home.management_console))
	panel.manage_outpost(home, operator, "bay_select_silo", list("ref" = REF(second_silo)))
	TEST_ASSERT_NULL(bay.approved_silo, "Changing the silo retained permission to the old store")
	TEST_ASSERT_EQUAL(bay.console.get_linked_silo(), ship_silo, "Changing the silo did not restore ship materials")
	panel.manage_outpost(home, operator, "bay_grant_materials", list("ref" = REF(bay)))
	TEST_ASSERT_EQUAL(bay.console.get_linked_silo(), second_silo, "The admin grant used the old silo")
	panel.manage_outpost(home, operator, "bay_revoke_materials", list("ref" = REF(bay)))
	TEST_ASSERT_NULL(bay.approved_silo, "Admin revocation retained outpost storage access")
	TEST_ASSERT_EQUAL(bay.console.get_linked_silo(), ship_silo, "Revocation did not restore the ship silo")
	panel.manage_outpost(home, operator, "bay_jump", list("ref" = REF(bay)))
	TEST_ASSERT_EQUAL(get_turf(operator), bay.alcove_turfs[1], "Jump did not use the bay's safe elevator alcove")
	operator.forceMove(run_loc_floor_bottom_left)
	panel.manage_outpost(home, operator, "remove_bays", list())
	TEST_ASSERT(home.ship_bay_installed && !QDELETED(bay), "Removal tore down an occupied bay")
	TEST_ASSERT(!home.can_spend(operator) && !bay.console.is_crew_member(operator), "Admin operations granted permanent player authority")

	visitor_turf.change_area(visitor_area, original_visitor_area)
	visitor_turf = null
	visitor_port.forceMove(run_loc_floor_bottom_left)
	ship_silo.forceMove(run_loc_floor_bottom_left)
	ship.docked = null
	ship.state = "flying"
	home.on_ship_undock_complete(ship)
	TEST_ASSERT(!QDELETED(bay) && bay.is_available(), "Admin-created bay did not survive departure")
	var/next_floor = home.next_bay_floor_id
	panel.manage_outpost(home, operator, "remove_bays", list())
	TEST_ASSERT(!home.ship_bay_installed && !length(home.bay_berths) && QDELETED(bay), "Empty bay upgrade was not removed")
	TEST_ASSERT_EQUAL(home.treasury.account_balance, before_balance, "Removing an admin grant minted a refund")
	panel.manage_outpost(home, operator, "install_bays", list())
	TEST_ASSERT(home.ship_bay_installed, "Removed bays could not be reinstalled")
	TEST_ASSERT_EQUAL(home.next_bay_floor_id, next_floor + 1, "Reinstallation reused a retired elevator destination")
