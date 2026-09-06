/// Exercises the actual admin operations without attaching a client to the test world.
/datum/outpost_manipulator/unit_test
	var/allow_actions = TRUE

/datum/outpost_manipulator/unit_test/authorized(mob/user)
	return !QDELETED(src) && user == admin && allow_actions

/datum/outpost_manipulator/unit_test/confirm(obj/structure/overmap/dynamic/player_outpost/home, mob/user, prompt)
	return valid_selection(home, user)

/datum/unit_test/voidcrew_outpost_admin
	var/mob/living/carbon/human/consistent/operator
	var/obj/structure/overmap/dynamic/player_outpost/home

/datum/unit_test/voidcrew_outpost_admin/Destroy()
	if(operator)
		GLOB.player_outpost_founder_ckeys -= operator.ckey
		operator.key = null
	return ..()

/datum/unit_test/voidcrew_outpost_admin/Run()
	operator = allocate(/mob/living/carbon/human/consistent, run_loc_floor_bottom_left)
	operator.key = "outpostadmintest"
	operator.mind_initialize()
	var/datum/outpost_manipulator/unit_test/panel = allocate(/datum/outpost_manipulator/unit_test, operator)
	var/turf/sector = SSovermap.get_unused_overmap_square()
	TEST_ASSERT_NOTNULL(sector, "No free overmap sector for admin creation")
	home = panel.create_home(operator, sector, /datum/map_template/player_outpost/small, "Admin Fixture")
	TEST_ASSERT_NOTNULL(home, "Admin creation did not produce a physical home")
	allocated += home
	panel.selected = home
	TEST_ASSERT(home.loaded && home.home_bundle_installed && home.arrival_turf, "Admin creation skipped the complete purchased-home loader")
	TEST_ASSERT(home.treasury && home.freight_berth?.dock && length(home.resident_pods), "Admin-created home lacks bank, freight or cryo services")
	TEST_ASSERT_NULL(home.founder_ckey, "Unowned admin creation silently assigned an owner")
	TEST_ASSERT_EQUAL(home.resident_mode, "closed", "Unowned admin creation allowed resident arrivals")
	TEST_ASSERT(!(operator.ckey in GLOB.player_outpost_founder_ckeys), "Unowned admin creation consumed the operator's founding allowance")
	TEST_ASSERT_NULL(panel.create_home(operator, sector, /datum/map_template/player_outpost/small, "Duplicate"), "Admin creation accepted an occupied sector")
	TEST_ASSERT_NULL(panel.create_home(operator, SSovermap.get_unused_overmap_square(), /datum/map_template/player_outpost/nothing, "Bare Claim"), "Admin creation accepted an unsupported shell")

	// The public override parameter must not be an authorization bypass for players.
	TEST_ASSERT(!home.transfer_ownership(operator, operator, admin_override = TRUE), "A non-admin used the administrative ownership override")
	home.founder_ckey = operator.ckey
	home.founder_mind = WEAKREF(operator.mind)
	home.residents |= operator.mind
	home.abandon(operator, admin_override = TRUE)
	TEST_ASSERT_EQUAL(home.founder_ckey, operator.ckey, "A non-admin used the administrative abandonment override")

	var/datum/bank_account/original_account = home.treasury
	original_account.adjust_money(200)
	panel.manage_outpost(home, operator, "relink", list())
	TEST_ASSERT_EQUAL(home.treasury, original_account, "Service rescan replaced the claim treasury")
	TEST_ASSERT_EQUAL(home.treasury.account_balance, 200, "Service rescan created or removed funds")
	var/cargo_count = 0
	for(var/obj/machinery/computer/voidcrew_cargo/cargo as anything in SSmachines.get_machines_by_type_and_subtypes(/obj/machinery/computer/voidcrew_cargo))
		if(get_outpost_from_atom(cargo) == home)
			cargo_count++
			TEST_ASSERT_EQUAL(cargo.cargo_account(), original_account, "Admin-created cargo terminal did not use the claim treasury")
	TEST_ASSERT_EQUAL(cargo_count, 1, "Service rescan changed the founding cargo-console count")

	panel.manage_outpost(home, operator, "dock_mode", list("mode" = OUTPOST_DOCK_MODE_LOCKDOWN))
	TEST_ASSERT_EQUAL(home.dock_mode, OUTPOST_DOCK_MODE_LOCKDOWN, "Admin docking control did not update policy")
	panel.manage_outpost(home, operator, "resident_mode", list("mode" = "approved"))
	TEST_ASSERT_EQUAL(home.resident_mode, "approved", "Admin resident control did not update policy")
	panel.manage_outpost(home, operator, "delegate", list("ref" = REF(operator.mind), "role" = "treasurer"))
	TEST_ASSERT(operator.mind in home.treasurers, "Admin delegation did not update treasury authority")
	panel.allow_actions = FALSE
	panel.manage_outpost(home, operator, "dock_mode", list("mode" = OUTPOST_DOCK_MODE_OPEN))
	TEST_ASSERT_EQUAL(home.dock_mode, OUTPOST_DOCK_MODE_LOCKDOWN, "A stale admin panel operated after losing authorization")
	panel.allow_actions = TRUE

	var/obj/structure/overmap/ship/visitor = allocate(/obj/structure/overmap/ship)
	visitor.docked = home
	TEST_ASSERT(panel.deletion_denial(home), "Deletion allowed a docked visiting ship")
	visitor.docked = null
	home.arrival_reservations[operator.ckey] = TRUE
	TEST_ASSERT(panel.deletion_denial(home), "Deletion allowed a pending resident arrival")
	home.arrival_reservations.Cut()
	operator.forceMove(home.arrival_turf)
	TEST_ASSERT(panel.deletion_denial(home), "Deletion allowed a living occupant")
	operator.forceMove(run_loc_floor_bottom_left)
	TEST_ASSERT_NULL(panel.deletion_denial(home), "An empty idle admin-created home could not be deleted")
	panel.manage_outpost(home, operator, "delete", list())
	TEST_ASSERT(QDELETED(home), "Confirmed admin deletion did not remove the empty home")
