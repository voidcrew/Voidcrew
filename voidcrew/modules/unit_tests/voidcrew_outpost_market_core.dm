/**
 * Outpost marketplace core: prices, the pricer role, membership, the one charge proc, the playtest
 * billing toggle, service rooms (area, protection, power, doors) and service doors. Door settings
 * themselves are tested in voidcrew_outpost_door_access.dm. Room power itself (the APC, the wire,
 * joining the grid) is tested in voidcrew_outpost_room_power.dm.
 *
 * Voidcrew defines are not visible from test files, so prices, keys and messages appear as literals.
 * The test room (outpost_service_room_test.dmm) is 5x5: a public door at (3,1) facing south, a staff
 * door at (5,3) facing east, a window at (1,3), a table at (2,4) and a computer at (4,4). It has its
 * own area (a /area/voidcrew/player_outpost/service_room instance), an APC at (2,2) and cable to
 * both exterior doors.
 */

// ===== FIXTURES =====

/datum/map_template/outpost_upgrade/service_room_test
	name = "Outpost Service Room Test"
	mappath = "voidcrew/_maps/map_files/unit_tests/outpost_service_room_test.dmm"

/// A load that builds nothing, for the ground release test
/datum/map_template/outpost_upgrade/service_room_test/failing

/datum/map_template/outpost_upgrade/service_room_test/failing/load_rotated(turf/bottom_left, rotation = 0)
	return null

/// A service room with no id of its own, so it never enters the catalog. Tests set the id.
/datum/outpost_upgrade/service/unit_test
	name = "Service Room Test"
	template_type = /datum/map_template/outpost_upgrade/service_room_test
	var/last_action
	var/abandoned_calls = 0

/datum/outpost_upgrade/service/unit_test/service_ui_data(mob/user)
	return list("kind" = "unit_test", "rotation" = rotation)

/datum/outpost_upgrade/service/unit_test/service_ui_act(mob/user, action, list/params)
	last_action = action
	return TRUE

/datum/outpost_upgrade/service/unit_test/admin_ui_data()
	return list(list("label" = "Probe", "action" = "probe", "ref" = null))

/datum/outpost_upgrade/service/unit_test/admin_ui_act(mob/user, action, list/params)
	last_action = "admin [action]"
	return TRUE

/datum/outpost_upgrade/service/unit_test/on_outpost_abandoned()
	abandoned_calls++

/datum/outpost_upgrade/service/unit_test/failing
	template_type = /datum/map_template/outpost_upgrade/service_room_test/failing

/// The market's owner at the claim's console, with the owner's mind recorded
/datum/unit_test/voidcrew_outpost_management/proc/market_test_owner(obj/structure/overmap/dynamic/player_outpost/home, owner_key)
	var/mob/living/carbon/human/owner = make_player(get_turf(home.management_console), owner_key)
	home.founder_mind = WEAKREF(owner.mind)
	return owner

/// A resident at the claim's console with a delegated role ("steward", "treasurer", "pricer" or null)
/datum/unit_test/voidcrew_outpost_management/proc/market_test_resident(obj/structure/overmap/dynamic/player_outpost/home, player_key, role)
	var/mob/living/carbon/human/resident = make_player(get_turf(home.management_console), player_key)
	home.residents |= resident.mind
	var/list/role_list = home.delegated_role_list(role)
	if(role_list)
		role_list |= resident.mind
	return resident

/// An installed service room with no ground, for the data and lifecycle tests
/datum/unit_test/voidcrew_outpost_management/proc/market_test_probe(obj/structure/overmap/dynamic/player_outpost/home, probe_id)
	var/datum/outpost_upgrade/service/unit_test/probe = new(home)
	probe.id = probe_id
	probe.key = probe.id
	probe.installed = TRUE
	home.outpost_upgrades[probe_id] = probe
	return probe

// ===== 1. SET_PRICE =====

/datum/unit_test/voidcrew_outpost_market_prices
	parent_type = /datum/unit_test/voidcrew_outpost_management

/datum/unit_test/voidcrew_outpost_market_prices/Run()
	var/obj/structure/overmap/dynamic/player_outpost/home = market_test_claim("marketpriceowner")
	TEST_ASSERT_NOTNULL(home, "The pricing test outpost did not load")
	var/mob/living/carbon/human/owner = market_test_owner(home, "marketpriceowner")
	var/list/imprint_row = GLOB.outpost_price_table["clone_imprint"]
	var/max_price = imprint_row["max"]

	TEST_ASSERT_EQUAL(home.get_price("clone_imprint"), 600, "The imprint price did not start at its default")
	TEST_ASSERT_EQUAL(home.get_price("free_lunch"), 0, "An unknown price key had a price")
	TEST_ASSERT_NULL(home.set_price(owner, "clone_imprint", 12.7), "The owner could not set a price")
	TEST_ASSERT_EQUAL(home.get_price("clone_imprint"), 13, "A fractional price was not rounded")
	var/list/last_line = home.service_ledger[length(home.service_ledger)]
	TEST_ASSERT_EQUAL(last_line["amount"], 0, "A price change wrote an amount to the ledger")
	TEST_ASSERT(findtext(last_line["label"], "600 cr to 13 cr"), "The ledger did not record the old and new price: [last_line["label"]]")

	TEST_ASSERT_EQUAL(home.set_price(owner, "clone_imprint", 20), "Too many price changes.", "A second change inside the cooldown was accepted")
	TEST_ASSERT_EQUAL(home.get_price("clone_imprint"), 13, "A refused change still set the price")
	home.price_set_times.Cut()

	TEST_ASSERT_NULL(home.set_price(owner, "clone_imprint", -5), "A negative price was refused instead of clamped")
	TEST_ASSERT_EQUAL(home.get_price("clone_imprint"), 0, "A negative price was not clamped to 0")
	home.price_set_times.Cut()
	TEST_ASSERT_NULL(home.set_price(owner, "clone_imprint", 999999), "A huge price was refused instead of clamped")
	TEST_ASSERT_EQUAL(home.get_price("clone_imprint"), max_price, "A huge price was not clamped to the maximum")
	home.price_set_times.Cut()

	// INFINITY is only 1e31, so INFINITY - INFINITY is 0; 1.#INF is the real thing
	var/infinite = 1.#INF
	var/not_a_number = infinite - infinite
	TEST_ASSERT(isnan(not_a_number), "The test could not make a NaN")
	TEST_ASSERT_EQUAL(home.set_price(owner, "clone_imprint", not_a_number), "Invalid price.", "NaN was accepted as a price")
	TEST_ASSERT_EQUAL(home.set_price(owner, "clone_imprint", "12"), "Invalid price.", "Text was accepted as a price")
	TEST_ASSERT_EQUAL(home.set_price(owner, "free_lunch", 10), "Unknown price.", "An unknown key was accepted")
	TEST_ASSERT_EQUAL(home.set_price(owner, 1, 10), "Unknown price.", "A numeric key was accepted")
	TEST_ASSERT_EQUAL(home.get_price("clone_imprint"), max_price, "A refused price changed the stored price")

	var/ledger_length = length(home.service_ledger)
	TEST_ASSERT_NULL(home.set_price(owner, "clone_imprint", max_price), "Setting the same price was refused")
	TEST_ASSERT_EQUAL(length(home.service_ledger), ledger_length, "Setting the same price wrote a ledger line")

	// The console's Pricing data carries every row, the viewer's own fee and the income ledger.
	var/datum/player_outpost_management_ui/management_test/panel = upgrade_test_panel(home, owner)
	var/list/data = panel.ui_data(owner)
	var/list/pricing = data["pricing"]
	TEST_ASSERT_EQUAL(length(pricing["prices"]), length(GLOB.outpost_price_table), "The Pricing tab is missing price rows")
	for(var/list/row as anything in pricing["prices"])
		for(var/key in list("key", "label", "value", "max", "available"))
			TEST_ASSERT(key in row, "A price row has no [key]")
		if(row["key"] == "clone_imprint")
			TEST_ASSERT_EQUAL(row["value"], max_price, "The Pricing tab shows the wrong imprint price")
			TEST_ASSERT_EQUAL(home.service_price_for(owner, row["value"]), 0, "The owner would pay a fee for their own service")
	var/list/ledger = pricing["ledger"]
	TEST_ASSERT(islist(ledger) && length(ledger), "The owner cannot see the income ledger")
	TEST_ASSERT(islist(pricing["totals"]), "The owner was sent no income totals")
	TEST_ASSERT(!("shop" in pricing), "The Pricing tab still sends a shop summary")
	TEST_ASSERT(length(ledger) <= 10, "The Pricing tab sent more than a short ledger") // OUTPOST_SERVICE_LEDGER_SHOWN

// ===== 2 AND 3. THE PRICER ROLE, DELEGATION, CLEANUP AND LIFECYCLE =====

/datum/unit_test/voidcrew_outpost_market_roles
	parent_type = /datum/unit_test/voidcrew_outpost_management

/datum/unit_test/voidcrew_outpost_market_roles/Run()
	var/obj/structure/overmap/dynamic/player_outpost/home = market_test_claim("marketroleowner")
	TEST_ASSERT_NOTNULL(home, "The roles test outpost did not load")
	TEST_ASSERT(!home.ship_bay_installed, "The roles test claim came with a ship bay; visitors would be interactive")
	home.treasury.adjust_money(500)
	var/mob/living/carbon/human/owner = market_test_owner(home, "marketroleowner")
	var/mob/living/carbon/human/steward = market_test_resident(home, "marketrolesteward", "steward")
	var/mob/living/carbon/human/treasurer = market_test_resident(home, "marketroletreasurer", "treasurer")
	var/mob/living/carbon/human/pricer = market_test_resident(home, "marketrolepricer", null)
	var/mob/living/carbon/human/plain = market_test_resident(home, "marketroleplain", null)
	var/datum/player_outpost_management_ui/management_test/owner_panel = upgrade_test_panel(home, owner)
	var/datum/player_outpost_management_ui/management_test/steward_panel = upgrade_test_panel(home, steward)
	var/datum/player_outpost_management_ui/management_test/treasurer_panel = upgrade_test_panel(home, treasurer)
	var/datum/player_outpost_management_ui/management_test/pricer_panel = upgrade_test_panel(home, pricer)
	var/datum/player_outpost_management_ui/management_test/plain_panel = upgrade_test_panel(home, plain)

	// Only the owner grants the role.
	act(steward_panel, steward, "delegate", pricer.mind, list("role" = "pricer"))
	TEST_ASSERT(!(pricer.mind in home.pricers), "A steward granted the pricer role")
	TEST_ASSERT_EQUAL(pricer_panel.ui_status(pricer, GLOB.always_state), UI_UPDATE, "A resident with no role could use the console")
	act(owner_panel, owner, "delegate", pricer.mind, list("role" = "pricer"))
	TEST_ASSERT(pricer.mind in home.pricers, "The owner could not grant the pricer role")
	TEST_ASSERT_EQUAL(pricer_panel.ui_status(pricer, GLOB.always_state), UI_INTERACTIVE, "A pricer's console is not interactive")
	TEST_ASSERT_EQUAL(plain_panel.ui_status(plain, GLOB.always_state), UI_UPDATE, "A resident with no role got an interactive console")

	// Stewards manage but do not price; treasurers and pricers price.
	act(steward_panel, steward, "set_price", null, list("key" = "medlab_pass", "value" = 450))
	TEST_ASSERT_EQUAL(home.get_price("medlab_pass"), 300, "A steward set a price")
	TEST_ASSERT_EQUAL(steward_panel.market_error, "Pricing access required.", "A steward's refused price change gave no reason")
	act(treasurer_panel, treasurer, "set_price", null, list("key" = "medlab_pass", "value" = 450))
	TEST_ASSERT_EQUAL(home.get_price("medlab_pass"), 450, "A treasurer could not set a price through the console")
	act(pricer_panel, pricer, "set_price", null, list("key" = "not_a_price", "value" = 250))
	TEST_ASSERT_EQUAL(pricer_panel.market_error, "Unknown price.", "A pricer's refused price change gave no reason")
	act(pricer_panel, pricer, "set_price", null, list("key" = "storage_rent", "value" = 250))
	TEST_ASSERT_EQUAL(home.get_price("storage_rent"), 250, "A pricer could not set a price through the console")
	TEST_ASSERT_NULL(pricer_panel.market_error, "A pricer's accepted price change left an error")
	act(plain_panel, plain, "set_price", null, list("key" = "storage_rent", "value" = 1))
	TEST_ASSERT_EQUAL(home.get_price("storage_rent"), 250, "A resident with no role set a price")

	// A pricer cannot reach management actions.
	var/old_name = home.name
	var/old_mode = home.dock_mode
	act(pricer_panel, pricer, "set_dock_mode", null, list("mode" = (old_mode == "lockdown" ? "open" : "lockdown")))
	TEST_ASSERT_EQUAL(home.dock_mode, old_mode, "A pricer changed the docking mode")
	act(pricer_panel, pricer, "rename", null, list("name" = "Pricer Rename"))
	TEST_ASSERT_EQUAL(home.name, old_name, "A pricer renamed the outpost")
	act(pricer_panel, pricer, "delegate", pricer.mind, list("role" = "steward"))
	TEST_ASSERT(!(pricer.mind in home.stewards), "A pricer made themselves a steward")

	// What each role is sent.
	var/list/pricer_data = pricer_panel.ui_data(pricer)
	var/list/pricer_pricing = pricer_data["pricing"]
	TEST_ASSERT(pricer_data["can_set_prices"], "The pricer's console says they cannot set prices")
	TEST_ASSERT(!pricer_data["can_select_silo"], "The pricer's console lets them pick the service silo")
	TEST_ASSERT(pricer_data["can_view_income"], "The pricer cannot see the income ledger")
	TEST_ASSERT(islist(pricer_pricing["ledger"]), "The pricer was sent no ledger")
	TEST_ASSERT_EQUAL(length(pricer_data["candidates"]), 0, "A pricer was sent the claim candidates")
	TEST_ASSERT_EQUAL(length(pricer_data["residents"]), 0, "A pricer was sent the resident roster")
	TEST_ASSERT_EQUAL(pricer_data["treasury_balance"], 0, "A pricer was sent the treasury balance")
	var/list/treasurer_data = treasurer_panel.ui_data(treasurer)
	TEST_ASSERT(treasurer_data["can_select_silo"], "A treasurer cannot pick the service silo")
	TEST_ASSERT_EQUAL(treasurer_data["treasury_balance"], 500, "A treasurer was not sent the treasury balance")
	var/list/plain_data = plain_panel.ui_data(plain)
	var/list/plain_pricing = plain_data["pricing"]
	TEST_ASSERT_NULL(plain_pricing["ledger"], "A resident with no role was sent the income ledger")
	TEST_ASSERT(!plain_data["can_set_prices"], "A resident with no role may set prices")
	TEST_ASSERT_EQUAL(length(plain_data["services"]), 0, "A resident with no role was sent the Services tab")
	var/list/owner_data = owner_panel.ui_data(owner)
	var/found_pricer = FALSE
	for(var/list/row as anything in owner_data["residents"])
		if(row["ref"] == REF(pricer.mind))
			found_pricer = row["pricer"]
	TEST_ASSERT(found_pricer, "The owner's resident list does not show the pricer role")
	TEST_ASSERT(islist(owner_data["owner_crews"]), "The owner's console has no owner crew list")

	// Stripped by remove_resident.
	act(owner_panel, owner, "remove_resident", pricer.mind)
	TEST_ASSERT(!(pricer.mind in home.pricers), "Removing a resident left them a pricer")
	TEST_ASSERT_EQUAL(pricer_panel.ui_status(pricer, GLOB.always_state), UI_UPDATE, "A removed pricer kept an interactive console")

	// Stripped by blocking the player (F-10), who also stops being a member.
	home.pricers |= plain.mind
	home.stewards |= plain.mind
	act(owner_panel, owner, "block_resident", null, list("ckey" = plain.ckey))
	for(var/list/role_list in list(home.residents, home.stewards, home.treasurers, home.pricers))
		TEST_ASSERT(!(plain.mind in role_list), "A blocked player's character kept a resident role")
	TEST_ASSERT(!home.is_outpost_member(plain), "A blocked player is still a member")

	// Stripped by the cryo despawn lines.
	home.pricers |= treasurer.mind
	home.strip_resident(treasurer.mind)
	TEST_ASSERT(!(treasurer.mind in home.pricers) && !(treasurer.mind in home.treasurers) && !(treasurer.mind in home.residents), "The cryo strip left a role behind")

	// Stripped from the former owner by an owner transfer, who stops being a member (F-11).
	home.residents |= pricer.mind
	home.pricers |= owner.mind
	TEST_ASSERT(home.transfer_ownership(pricer, owner), "The owner could not transfer the outpost")
	TEST_ASSERT(!(owner.mind in home.pricers), "A transfer left the former owner a pricer")
	TEST_ASSERT(!(owner.mind in home.residents), "A transfer kept the former owner as a resident")
	TEST_ASSERT(!home.is_outpost_member(owner), "The former owner is still a member after a transfer")

	// Stripped by abandonment, with prices and billing reset and every room told.
	var/datum/outpost_upgrade/service/unit_test/probe = market_test_probe(home, "market_abandon_probe")
	home.pricers |= steward.mind
	home.playtest_visitor_ckey = steward.ckey
	home.abandon(pricer)
	TEST_ASSERT_NULL(home.founder_ckey, "The new owner could not abandon")
	TEST_ASSERT_EQUAL(length(home.pricers), 0, "Abandonment kept pricers")
	TEST_ASSERT_EQUAL(length(home.outpost_prices), 0, "Abandonment kept the set prices")
	TEST_ASSERT_EQUAL(home.get_price("medlab_pass"), 300, "Abandonment did not reset a price to its default")
	TEST_ASSERT_NULL(home.playtest_visitor_ckey, "Abandonment kept playtest billing")
	TEST_ASSERT_EQUAL(probe.abandoned_calls, 1, "Abandonment did not reset the installed service room")
	TEST_ASSERT_EQUAL(home.service_price_for(plain, 600), 0, "An ownerless outpost charges visitors")

	// A claimant starts with their own crew, not the old residents (F-11).
	var/mob/living/carbon/human/claimant = make_player(get_turf(home.management_console), "marketroleclaimant")
	TEST_ASSERT(home.transfer_ownership(claimant, claimant), "A visitor could not claim the abandoned outpost")
	TEST_ASSERT(!home.is_outpost_member(pricer), "The previous owner is a member of the claimant's outpost")
	TEST_ASSERT(!home.is_outpost_member(steward), "An old resident is a member of the claimant's outpost")
	TEST_ASSERT(home.is_outpost_member(claimant), "The claimant is not a member of their own outpost")

// ===== 3 (MANIPULATOR) AND 5. ADMIN CONTROLS AND PLAYTEST BILLING =====

/datum/unit_test/voidcrew_outpost_market_admin
	parent_type = /datum/unit_test/voidcrew_outpost_management

/datum/unit_test/voidcrew_outpost_market_admin/Run()
	var/obj/structure/overmap/dynamic/player_outpost/home = market_test_claim("marketadminowner")
	TEST_ASSERT_NOTNULL(home, "The admin test outpost did not load")
	var/mob/living/carbon/human/owner = market_test_owner(home, "marketadminowner")
	var/mob/living/carbon/human/resident = market_test_resident(home, "marketadminresident", null)
	var/datum/outpost_manipulator/unit_test/manipulator = allocate(/datum/outpost_manipulator/unit_test, owner)
	manipulator.selected = home

	manipulator.manage_outpost(home, owner, "delegate", list("ref" = REF(resident.mind), "role" = "pricer"))
	TEST_ASSERT(resident.mind in home.pricers, "The manipulator could not grant the pricer role")
	manipulator.manage_outpost(home, owner, "delegate", list("ref" = REF(resident.mind), "role" = "pricer"))
	TEST_ASSERT(!(resident.mind in home.pricers), "The manipulator could not revoke the pricer role")
	home.pricers |= resident.mind
	manipulator.manage_outpost(home, owner, "remove_resident", list("ref" = REF(resident.mind)))
	TEST_ASSERT(!(resident.mind in home.pricers), "The manipulator's resident removal left a pricer")

	// Room admin rows and actions.
	var/datum/outpost_upgrade/service/unit_test/probe = market_test_probe(home, "market_admin_probe")
	var/list/selected_data = list()
	manipulator.market_admin_data(home, selected_data)
	var/list/service_rows
	for(var/list/service as anything in selected_data["services"])
		if(service["id"] == probe.id)
			service_rows = service["rows"]
	TEST_ASSERT_EQUAL(length(service_rows), 1, "The manipulator did not list the room's admin rows")
	manipulator.manage_outpost(home, owner, "service_admin", list("id" = probe.id, "service_action" = "probe"))
	TEST_ASSERT_EQUAL(probe.last_action, "admin probe", "The manipulator did not route a room admin action")
	manipulator.manage_outpost(home, owner, "service_admin", list("id" = 1, "service_action" = "probe"))
	TEST_ASSERT_EQUAL(manipulator.error, "No such room.", "A numeric room id was accepted")

	// Bill me as a visitor: the owner pays like a visitor and keeps every permission.
	TEST_ASSERT(home.is_outpost_member(owner), "The owner is not a member")
	manipulator.manage_outpost(home, owner, "playtest_visitor", list())
	TEST_ASSERT_EQUAL(home.playtest_visitor_ckey, owner.ckey, "The playtest toggle did not bill the admin as a visitor")
	selected_data = list()
	manipulator.market_admin_data(home, selected_data)
	TEST_ASSERT_EQUAL(selected_data["playtest_visitor"], owner.ckey, "The manipulator does not show who is billed as a visitor")
	TEST_ASSERT(!home.is_outpost_member(owner), "A playtest visitor is still a member")
	TEST_ASSERT_EQUAL(home.service_price_for(owner, 600), 600, "A playtest visitor is not charged")
	TEST_ASSERT(home.is_current_management_user(owner), "Playtest billing removed management permission")
	TEST_ASSERT(home.is_current_pricing_user(owner), "Playtest billing removed pricing permission")
	var/datum/player_outpost_management_ui/management_test/panel = upgrade_test_panel(home, owner)
	var/list/data = panel.ui_data(owner)
	TEST_ASSERT(data["playtest_visitor"], "The console does not show the playtest billing banner")
	manipulator.manage_outpost(home, owner, "playtest_visitor", list())
	TEST_ASSERT_NULL(home.playtest_visitor_ckey, "The playtest toggle did not turn off")
	TEST_ASSERT(home.is_outpost_member(owner), "The owner did not become a member again")

// ===== 4. CHARGE_SERVICE =====

/datum/unit_test/voidcrew_outpost_market_charge
	parent_type = /datum/unit_test/voidcrew_outpost_management

/datum/unit_test/voidcrew_outpost_market_charge/Run()
	var/obj/structure/overmap/dynamic/player_outpost/home = market_test_claim("marketchargeowner")
	TEST_ASSERT_NOTNULL(home, "The charge test outpost did not load")
	var/turf/here = get_turf(home.management_console)
	var/mob/living/carbon/human/owner = market_test_owner(home, "marketchargeowner")
	var/mob/living/carbon/human/resident = make_market_visitor(here, "marketchargeresident", 1000)
	home.residents |= resident.mind
	var/mob/living/carbon/human/crewmate = make_market_visitor(here, "marketchargecrew", 1000)
	var/mob/living/carbon/human/visitor = make_market_visitor(here, "marketchargevisitor", 1000)
	var/datum/team/voidcrew/crew = allocate(/datum/team/voidcrew)
	LAZYADD(owner.mind.ship_teams, crew)
	LAZYADD(crewmate.mind.ship_teams, crew)
	var/datum/bank_account/treasury = home.treasury

	// Members pay nothing, and the fee they are shown is 0 (charge_service() compares the effective fee).
	for(var/mob/living/member as anything in list(owner, resident, crewmate))
		TEST_ASSERT(home.is_outpost_member(member), "[member.ckey] is not a member")
		TEST_ASSERT_EQUAL(home.service_price_for(member, 600), 0, "[member.ckey] owes a member's fee")
		TEST_ASSERT_NULL(home.charge_service(member, "clone_imprint", 600, 0, "Test imprint"), "[member.ckey] was refused a free service")
	TEST_ASSERT_EQUAL(treasury.account_balance, 0, "A member's free service moved money")
	TEST_ASSERT_EQUAL(length(home.service_ledger), 0, "A member's free service wrote a ledger line")

	// A visitor is charged once, into the treasury, with a ledger line naming them.
	var/obj/item/card/id/card = visitor.get_idcard(TRUE)
	var/datum/bank_account/visitor_account = card.registered_account
	TEST_ASSERT_EQUAL(home.charge_service(visitor, "clone_imprint", 600, 500, "Test imprint"), "Price changed to 600 cr.", "A stale shown price was accepted")
	TEST_ASSERT_EQUAL(home.charge_service(visitor, "clone_imprint", 600, 0, "Test imprint"), "Price changed to 600 cr.", "A visitor shown 0 was charged")
	TEST_ASSERT_EQUAL(visitor_account.account_balance, 1000, "A refused charge moved the visitor's money")
	TEST_ASSERT_NULL(home.charge_service(visitor, "clone_imprint", 600, 600, "Test imprint"), "A visitor could not pay")
	TEST_ASSERT_EQUAL(visitor_account.account_balance, 400, "The visitor was not charged exactly once")
	TEST_ASSERT_EQUAL(treasury.account_balance, 600, "The treasury was not credited exactly once")
	TEST_ASSERT_EQUAL(length(home.service_ledger), 1, "The payment wrote the wrong number of ledger lines")
	var/list/line = home.service_ledger[1]
	TEST_ASSERT_EQUAL(line["payer"], visitor.real_name, "The ledger does not name the payer")
	TEST_ASSERT_EQUAL(line["account"], visitor_account.account_holder, "The ledger does not name the paying account")
	TEST_ASSERT_EQUAL(line["amount"], 600, "The ledger has the wrong amount")
	var/list/totals = home.service_totals["clone_imprint"]
	TEST_ASSERT_EQUAL(totals["total"], 600, "The service total was not updated")

	// Refusals move nothing.
	TEST_ASSERT_EQUAL(home.charge_service(visitor, "clone_imprint", 600, 600, "Test imprint"), "Insufficient credits.", "A short account paid")
	visitor_account.account_balance = 1000
	visitor_account.mark_siphoned()
	TEST_ASSERT_EQUAL(home.charge_service(visitor, "clone_imprint", 600, 600, "Test imprint"), "Insufficient credits.", "A siphon-locked account paid")
	TEST_ASSERT_EQUAL(visitor_account.account_balance, 1000, "A siphon-locked account was debited")
	visitor_account.siphon_lock_until = 0
	var/mob/living/carbon/human/no_card = make_player(here, "marketchargenocard")
	TEST_ASSERT_EQUAL(home.charge_service(no_card, "clone_imprint", 600, 600, "Test imprint"), "No bank account on your ID.", "A visitor with no ID paid")
	card.registered_account = treasury
	TEST_ASSERT_EQUAL(home.charge_service(visitor, "clone_imprint", 600, 600, "Test imprint"), "Payment declined.", "The treasury paid itself")
	card.registered_account = visitor_account
	TEST_ASSERT_EQUAL(treasury.account_balance, 600, "A refused charge changed the treasury")

	// A zero price is free and writes nothing; an ownerless outpost charges nothing.
	var/ledger_length = length(home.service_ledger)
	TEST_ASSERT_NULL(home.charge_service(visitor, "clone_imprint", 0, 0, "Test imprint"), "A zero price was refused")
	TEST_ASSERT_EQUAL(length(home.service_ledger), ledger_length, "A zero price wrote a ledger line")
	home.founder_ckey = null
	TEST_ASSERT_EQUAL(home.service_price_for(visitor, 600), 0, "An ownerless outpost charges visitors")
	TEST_ASSERT_NULL(home.charge_service(visitor, "clone_imprint", 600, 0, "Test imprint"), "An ownerless outpost refused a free service")
	home.founder_ckey = "marketchargeowner"
	TEST_ASSERT_EQUAL(visitor_account.account_balance, 1000, "A free service moved the visitor's money")

	// Refunds are exact, and refused with nothing moved when the treasury is short.
	TEST_ASSERT(home.refund_payment(visitor_account, 250, "clone_imprint", "Test refund"), "A covered refund was refused")
	TEST_ASSERT_EQUAL(visitor_account.account_balance, 1250, "The refund paid the wrong amount")
	TEST_ASSERT_EQUAL(treasury.account_balance, 350, "The refund took the wrong amount from the treasury")
	TEST_ASSERT(!home.refund_payment(visitor_account, 351, "clone_imprint", "Test refund"), "A refund larger than the treasury went through")
	TEST_ASSERT_EQUAL(visitor_account.account_balance, 1250, "A refused refund paid the visitor")
	TEST_ASSERT_EQUAL(treasury.account_balance, 350, "A refused refund changed the treasury")

	LAZYREMOVE(owner.mind.ship_teams, crew)
	LAZYREMOVE(crewmate.mind.ship_teams, crew)

// ===== 6 AND 7. SERVICE ROOMS AND SERVICE DOORS =====

/datum/unit_test/voidcrew_outpost_market_service_rooms
	parent_type = /datum/unit_test/voidcrew_outpost_management

/datum/unit_test/voidcrew_outpost_market_service_rooms/Run()
	var/obj/structure/overmap/dynamic/player_outpost/home = market_test_claim("marketroomowner")
	TEST_ASSERT_NOTNULL(home, "The service room test outpost did not load")
	TEST_ASSERT_NOTNULL(home.outpost_area, "The service room test outpost has no outpost area")
	var/mob/living/carbon/human/owner = market_test_owner(home, "marketroomowner")
	var/list/placed = list()

	// A load that builds nothing gives the ground back.
	var/datum/outpost_upgrade/service/unit_test/failing/broken = new(home)
	broken.id = "service_room_test_broken"
	broken.key = broken.id
	var/turf/broken_corner = service_room_test_corner(home, broken, 0)
	TEST_ASSERT_NOTNULL(broken_corner, "No test spot for the failing room")
	var/list/broken_footprint = broken.footprint_at(broken_corner, 0)
	var/list/broken_turfs = broken_footprint["turfs"]
	var/list/old_areas = list()
	for(var/turf/tile as anything in broken_turfs)
		old_areas[tile] = get_area(tile)
	var/broken_result = place_test_service_room(home, broken, list(0), owner)
	TEST_ASSERT(istext(broken_result), "A load that built nothing was reported as placed")
	for(var/turf/tile as anything in broken_turfs)
		TEST_ASSERT_EQUAL(get_area(tile), old_areas[tile], "A failed load left [tile.x],[tile.y] in the outpost area")
	home.outpost_upgrades -= broken.id
	qdel(broken)

	for(var/rotation in list(0, 90, 180, 270))
		var/datum/outpost_upgrade/service/unit_test/room = new(home)
		room.id = "service_room_test_[rotation]"
		room.key = room.id
		var/mapping_log_count = length(GLOB.unit_test_mapping_logs)
		var/result = place_test_service_room(home, room, list(rotation), owner)
		TEST_ASSERT_EQUAL(result, room, "The test room was not placed at [rotation] degrees: [result]")
		placed += room
		if(length(GLOB.unit_test_mapping_logs) > mapping_log_count)
			TEST_FAIL("Placing the test room at [rotation] degrees logged mapping errors: [jointext(GLOB.unit_test_mapping_logs.Copy(mapping_log_count + 1), "; ")]")
		TEST_ASSERT(room.installed_area && room.installed_area != home.outpost_area, "The room did not get an area of its own at [rotation] degrees")
		TEST_ASSERT(istype(room.installed_area, /area/voidcrew/player_outpost/service_room), "The room's area is not a service room area at [rotation] degrees")
		var/list/room_turfs = room.room_turfs()
		TEST_ASSERT_EQUAL(length(room_turfs), 25, "The room's footprint is the wrong size at [rotation] degrees")
		var/list/inside = list()
		for(var/turf/tile as anything in room_turfs)
			inside[tile] = TRUE
			TEST_ASSERT_EQUAL(get_area(tile), room.installed_area, "[tile.x],[tile.y] is not in the room's own area at [rotation] degrees")
			for(var/obj/fixture in tile)
				if(istype(fixture, /obj/structure/cable))
					continue
				if(!ismachinery(fixture) && !isstructure(fixture))
					continue
				TEST_ASSERT(HAS_TRAIT(fixture, "outpost_property"), "[fixture] ([fixture.type]) is not outpost property at [rotation] degrees")
				TEST_ASSERT(fixture.flags_1 & PREVENT_CONTENTS_EXPLOSION_1, "[fixture] ([fixture.type]) can lose its parts to explosions at [rotation] degrees")
		var/door_count = 0
		for(var/turf/tile as anything in room_turfs)
			for(var/obj/machinery/door/airlock/outpost/service/door in tile)
				door_count++
				var/outward
				for(var/direction in GLOB.cardinals)
					if(!inside[get_step(tile, direction)])
						outward = direction
				TEST_ASSERT_NOTNULL(outward, "[door] does not lead out of the room at [rotation] degrees")
				TEST_ASSERT_EQUAL(door.unres_sides, turn(outward, 180), "[door] opens freely from the wrong side at [rotation] degrees")
		TEST_ASSERT_EQUAL(door_count, 2, "The room has the wrong number of service doors at [rotation] degrees")
		TEST_ASSERT_EQUAL(length(room.doors), 2, "The room did not adopt its doors at [rotation] degrees")
		settle_room_air(room_turfs)

	var/list/owned = home.outpost_owned_turfs()
	TEST_ASSERT_EQUAL(length(owned), length(unique_list(owned)), "The outpost's owned turfs list a tile twice")

	// Power: the room's machine runs on its own area and follows its own equipment channel. An
	// outage in the habitat stays in the habitat (voidcrew_outpost_room_power.dm covers the APC
	// and the wire that join a room to the habitat's grid).
	var/datum/outpost_upgrade/service/unit_test/first_room = placed[1]
	var/obj/machinery/computer/terminal
	for(var/turf/tile as anything in first_room.room_turfs())
		terminal = locate(/obj/machinery/computer) in tile
		if(terminal)
			break
	TEST_ASSERT_NOTNULL(terminal, "The test room has no computer")
	var/area/room_area = first_room.installed_area
	TEST_ASSERT_NOTNULL(room_area, "The test room has no area of its own")
	var/old_room_equip = room_area.power_equip
	room_area.power_equip = TRUE
	room_area.power_change()
	TEST_ASSERT(!(terminal.machine_stat & NOPOWER), "The room's machine is unpowered while its own area has equipment power")
	room_area.power_equip = FALSE
	room_area.power_change()
	TEST_ASSERT(terminal.machine_stat & NOPOWER, "The room's machine kept power with its own area's equipment channel off")

	// The habitat's own outage never touches an installed room's own area.
	room_area.power_equip = TRUE
	room_area.power_change()
	var/area/home_area = home.outpost_area
	var/old_home_equip = home_area.power_equip
	home_area.power_equip = FALSE
	home_area.power_change()
	TEST_ASSERT(!(terminal.machine_stat & NOPOWER), "The room's machine lost power when the habitat's equipment channel went off")
	home_area.power_equip = old_home_equip
	home_area.power_change()
	room_area.power_equip = old_room_equip
	room_area.power_change()

	// The console's Services tab and its actions.
	var/datum/player_outpost_management_ui/management_test/panel = upgrade_test_panel(home, owner)
	var/list/owner_data = panel.ui_data(owner)
	var/list/services = owner_data["services"]
	TEST_ASSERT_EQUAL(length(services), 4, "The Services tab does not list every installed room")
	for(var/list/card as anything in services)
		for(var/key in list("id", "name", "detail"))
			TEST_ASSERT(key in card, "A Services card has no [key]")
		TEST_ASSERT(!("visitors_allowed" in card), "A Services card still sends the old visitor switch")
		var/list/detail = card["detail"]
		TEST_ASSERT_EQUAL(detail["kind"], "unit_test", "A Services card lost its room's detail")
	act(panel, owner, "service_act", null, list("id" = first_room.id, "service_action" = "poke"))
	TEST_ASSERT_EQUAL(first_room.last_action, "poke", "A Services tab action did not reach its room")
	act(panel, owner, "service_act", null, list("id" = 1, "service_action" = "poke"))
	TEST_ASSERT_EQUAL(panel.market_error, "No such room.", "A numeric room id was accepted")

	// Doors (on the first room): the entrance starts public, the staff door staff.
	var/obj/machinery/door/airlock/outpost/service/public_door
	var/obj/machinery/door/airlock/outpost/service/staff_door
	for(var/datum/weakref/door_ref as anything in first_room.doors)
		var/obj/machinery/door/airlock/outpost/service/door = door_ref.resolve()
		if(door?.door_policy == "staff")
			staff_door = door
		else if(door)
			public_door = door
	TEST_ASSERT_NOTNULL(public_door, "The test room has no public door")
	TEST_ASSERT_NOTNULL(staff_door, "The test room has no staff door")
	TEST_ASSERT_EQUAL(outpost_door_access_of(public_door), "public", "The room's entrance did not start public")
	TEST_ASSERT_EQUAL(outpost_door_access_of(staff_door), "staff", "The room's staff door did not start staff only")
	var/turf/staff_outside = get_step(staff_door, turn(staff_door.unres_sides, 180))
	var/turf/staff_inside = get_step(staff_door, staff_door.unres_sides)
	var/turf/public_outside = get_step(public_door, turn(public_door.unres_sides, 180))
	var/mob/living/carbon/human/visitor = make_market_visitor(staff_outside, "marketroomvisitor", 0)
	var/mob/living/carbon/human/resident = make_player(staff_outside, "marketroomresident")
	home.residents |= resident.mind
	var/mob/living/carbon/human/crewmate = make_player(staff_outside, "marketroomcrew")
	var/datum/team/voidcrew/crew = allocate(/datum/team/voidcrew)
	LAZYADD(owner.mind.ship_teams, crew)
	LAZYADD(crewmate.mind.ship_teams, crew)
	var/mob/living/carbon/human/steward = market_test_resident(home, "marketroomsteward", "steward")
	steward.forceMove(staff_outside)

	// Staff only: the owner and role holders, not ordinary members
	TEST_ASSERT(!staff_door.allowed(visitor), "A visitor passed a staff door")
	TEST_ASSERT(staff_door.allowed(owner), "The owner was refused at a staff door")
	TEST_ASSERT(staff_door.allowed(steward), "A steward was refused at a staff door")
	TEST_ASSERT(!staff_door.allowed(resident), "A resident with no role passed a staff door")
	TEST_ASSERT(!staff_door.allowed(crewmate), "The owner's crewmate passed a staff door")
	TEST_ASSERT(findtext(jointext(staff_door.examine(visitor), " "), "Staff only."), "A staff door does not say so")
	visitor.forceMove(staff_inside)
	TEST_ASSERT(staff_door.allowed(visitor), "A visitor inside the room could not leave by the staff door")
	visitor.forceMove(staff_outside)

	// A thrown item opens nothing for a visitor.
	var/obj/item/storage/toolbox/toolbox = allocate(/obj/item/storage/toolbox, staff_outside)
	toolbox.throwing = new /datum/thrownthing(toolbox, get_turf(staff_door), get_dir(staff_outside, staff_door), 7, 1, visitor)
	staff_door.Bumped(toolbox)
	TEST_ASSERT(staff_door.density, "A toolbox thrown by a visitor opened a staff door")
	QDEL_NULL(toolbox.throwing)
	// Janitor keys, emags, Knock and prying all fail for a visitor.
	staff_door.try_to_activate_door(visitor, access_bypass = TRUE)
	TEST_ASSERT(staff_door.density, "A janitor key's bypass opened a staff door for a visitor")
	TEST_ASSERT(!staff_door.emag_act(visitor, null), "An emag worked on a service door")
	SEND_SIGNAL(staff_door, COMSIG_ATOM_MAGICALLY_UNLOCKED, null, visitor)
	TEST_ASSERT(staff_door.density, "Knock opened a staff door")
	staff_door.try_to_crowbar(null, visitor, TRUE)
	TEST_ASSERT(staff_door.density, "A visitor forced a staff door open")
	var/mob/living/silicon/robot/borg = allocate(/mob/living/silicon/robot, staff_outside)
	TEST_ASSERT(!staff_door.allowed(borg), "A silicon visitor passed a staff door")

	// The entrance admits visitors until the owner keys it to members.
	visitor.forceMove(public_outside)
	TEST_ASSERT(public_door.allowed(visitor), "A visitor was refused at a public entrance")
	TEST_ASSERT_NULL(home.set_door_access(owner, public_door, "members"), "The owner could not key the entrance to members")
	TEST_ASSERT(!public_door.allowed(visitor), "A members-only entrance admitted a visitor")
	resident.forceMove(public_outside)
	TEST_ASSERT(public_door.allowed(resident), "A members-only entrance refused a member")
	TEST_ASSERT_EQUAL(home.set_door_access(resident, public_door, "public"), "Not authorised.", "A resident with no role changed a door")
	TEST_ASSERT_EQUAL(outpost_door_access_of(public_door), "members", "A refused change still changed the door")
	TEST_ASSERT(public_door.unres_sides, "Keying the entrance lost its free side")

	// A blocked resident is out (F-10).
	act(panel, owner, "block_resident", null, list("ckey" = resident.ckey))
	TEST_ASSERT(!public_door.allowed(resident), "A blocked resident passed a members-only door")

	// Abandonment tells every room, and every door goes back to its default.
	home.abandon(owner)
	for(var/datum/outpost_upgrade/service/unit_test/room as anything in placed)
		TEST_ASSERT_EQUAL(room.abandoned_calls, 1, "Abandonment did not reach [room.id]")
	TEST_ASSERT_EQUAL(outpost_door_access_of(public_door), "public", "Abandonment left the entrance keyed")
	TEST_ASSERT_EQUAL(outpost_door_access_of(staff_door), "staff", "Abandonment took the staff door off staff")
	TEST_ASSERT(public_door.allowed(visitor), "An ownerless outpost's door refused a visitor")

	LAZYREMOVE(owner.mind.ship_teams, crew)
	LAZYREMOVE(crewmate.mind.ship_teams, crew)

// ===== 8. THE OWNER'S DRONE REWORKS A SERVICE ROOM =====

/**
 * The construction drone takes a service room's walls and floors down to plating for the owner, and
 * pays nothing for them. A hand RCD cannot, even the owner's; a visitor at the console cannot; the
 * drone leaves a fixture's floor, the fixture itself and indestructible walls outside the rooms alone;
 * and a visitor's RCD builds nothing on the plating left behind. Drives the console's own RCD the way
 * its Deconstruct tool does: mode, rcd_vals(), rcd_create().
 */
/datum/unit_test/voidcrew_outpost_service_room_rebuild
	parent_type = /datum/unit_test/voidcrew_outpost_management

/datum/unit_test/voidcrew_outpost_service_room_rebuild/Run()
	var/obj/structure/overmap/dynamic/player_outpost/home = market_test_claim("roomrebuildowner")
	TEST_ASSERT_NOTNULL(home, "The room rebuild test outpost did not load")
	var/mob/living/carbon/human/owner = market_test_owner(home, "roomrebuildowner")
	var/mob/living/carbon/human/visitor = make_player(get_turf(home.management_console), "roomrebuildvisitor")
	var/datum/outpost_upgrade/service/unit_test/room = new(home)
	room.id = "service_room_rebuild_test"
	room.key = room.id
	var/result = place_test_service_room(home, room, list(0, 90, 180, 270), owner)
	TEST_ASSERT_EQUAL(result, room, "The test room was not placed: [result]")
	var/list/room_turfs = room.room_turfs()

	// A bare wall, a bare floor, the table and the computer (outpost_service_room_test.dmm)
	var/turf/wall
	var/turf/floor
	var/obj/structure/table/table
	var/obj/machinery/computer/terminal
	for(var/turf/tile as anything in room_turfs)
		if(!table)
			table = locate(/obj/structure/table) in tile
		if(!terminal)
			terminal = locate(/obj/machinery/computer) in tile
		if(locate(/obj/structure) in tile)
			continue
		if(locate(/obj/machinery) in tile)
			continue
		if(!wall && istype(tile, /turf/closed/indestructible))
			wall = tile
		else if(!floor && istype(tile, /turf/open/indestructible))
			floor = tile
	TEST_ASSERT_NOTNULL(wall, "The test room has no bare indestructible wall")
	TEST_ASSERT_NOTNULL(floor, "The test room has no bare indestructible floor")
	TEST_ASSERT_NOTNULL(table, "The test room has no table")
	TEST_ASSERT_NOTNULL(terminal, "The test room has no computer")
	var/wall_x = wall.x
	var/wall_y = wall.y
	var/floor_x = floor.x
	var/floor_y = floor.y
	var/site_z = wall.z

	var/obj/machinery/computer/camera_advanced/base_construction/ship/outpost/console = home.construction_console
	TEST_ASSERT_NOTNULL(console, "The test outpost has no construction console")
	TEST_ASSERT(console.can_build_at(wall) && console.can_build_at(floor), "The test room is outside the build region")
	var/obj/item/construction/rcd/internal/ship/drone_rcd = console.internal_rcd
	var/obj/machinery/ore_silo/silo = console.get_linked_silo()
	if(!silo)
		silo = allocate(/obj/machinery/ore_silo, get_turf(console))
		TEST_ASSERT(console.link_internal_device(drone_rcd, drone_rcd.silo_mats, silo), "The construction console could not link a silo")
	drone_rcd.silo_link = TRUE
	var/silo_before = silo.materials.total_amount()
	var/old_mode = drone_rcd.mode
	var/old_delay_mod = drone_rcd.delay_mod
	drone_rcd.mode = RCD_DECONSTRUCT
	drone_rcd.delay_mod = 0

	// Hand tools: a hand RCD gets nothing, even in the owner's hands
	var/obj/item/construction/rcd/loaded/hand_rcd = allocate(/obj/item/construction/rcd/loaded, get_turf(owner))
	hand_rcd.mode = RCD_DECONSTRUCT
	hand_rcd.delay_mod = 0
	TEST_ASSERT(!length(wall.rcd_vals(owner, hand_rcd)), "A hand RCD could take a service room wall apart")
	TEST_ASSERT(!length(floor.rcd_vals(owner, hand_rcd)), "A hand RCD could lift a service room floor")
	hand_rcd.rcd_create(wall, owner)
	hand_rcd.rcd_create(floor, owner)
	TEST_ASSERT(istype(locate(wall_x, wall_y, site_z), /turf/closed/indestructible), "A hand RCD took a service room wall apart")
	TEST_ASSERT(istype(locate(floor_x, floor_y, site_z), /turf/open/indestructible), "A hand RCD lifted a service room floor")

	// A visitor at the console gets nothing either
	TEST_ASSERT(!length(wall.rcd_vals(visitor, drone_rcd)), "A visitor at the construction console could take a service room wall apart")
	drone_rcd.rcd_create(wall, visitor)
	TEST_ASSERT(istype(locate(wall_x, wall_y, site_z), /turf/closed/indestructible), "A visitor at the construction console took a service room wall apart")

	// The drone leaves an indestructible wall outside the service rooms alone
	var/turf/lone_spot = locate(home.build_bounds[1] + 1, home.build_bounds[2] + 1, site_z)
	TEST_ASSERT(console.can_build_at(lone_spot) && !home.upgrade_at_turf(lone_spot), "No free build region tile for the lone wall")
	var/lone_type = lone_spot.type
	var/lone_baseturfs = lone_spot.baseturfs
	var/turf/lone_wall = lone_spot.ChangeTurf(/turf/closed/indestructible)
	TEST_ASSERT(!length(lone_wall.rcd_vals(owner, drone_rcd)), "The drone could take apart an indestructible wall outside the service rooms")
	lone_wall.ChangeTurf(lone_type, lone_baseturfs)

	// Fixtures: the drone neither lifts a fixture's floor nor takes the fixture apart
	var/turf/table_tile = get_turf(table)
	TEST_ASSERT(!length(table_tile.rcd_vals(owner, drone_rcd)), "The drone could lift the floor under a room fixture")
	drone_rcd.rcd_create(table, owner)
	TEST_ASSERT(!QDELETED(table) && table.loc == table_tile, "The drone took a room fixture apart")
	TEST_ASSERT(istype(table_tile, /turf/open/indestructible), "The drone lifted the floor under a room fixture")

	// The owner's drone takes a floor down to plating that the drone's own tools build on again
	TEST_ASSERT(length(floor.rcd_vals(owner, drone_rcd)), "The drone cannot lift a service room floor")
	drone_rcd.rcd_create(floor, owner)
	var/turf/stripped_floor = locate(floor_x, floor_y, site_z)
	TEST_ASSERT_EQUAL(stripped_floor.type, /turf/open/floor/plating, "The drone did not take a service room floor down to plating")
	TEST_ASSERT_EQUAL(get_area(stripped_floor), room.installed_area, "A stripped floor left the room's own area")
	var/list/below = islist(stripped_floor.baseturfs) ? stripped_floor.baseturfs : list(stripped_floor.baseturfs)
	for(var/layer in below)
		TEST_ASSERT(!ispath(layer, /turf/closed/indestructible) && !ispath(layer, /turf/open/indestructible), "A stripped floor kept an indestructible layer underneath: [layer]")
	TEST_ASSERT(drone_rcd.can_refloor(stripped_floor, /turf/open/floor/mineral/titanium), "The drone cannot lay a new floor on a stripped service room tile")

	// And a wall
	TEST_ASSERT(length(wall.rcd_vals(owner, drone_rcd)), "The drone cannot take a service room wall apart")
	drone_rcd.rcd_create(wall, owner)
	var/turf/stripped_wall = locate(wall_x, wall_y, site_z)
	TEST_ASSERT_EQUAL(stripped_wall.type, /turf/open/floor/plating, "The drone did not take a service room wall down to plating")
	// Close the gap the way the drone's wall tool does, before the room's air finds it
	stripped_wall = stripped_wall.place_on_top(/turf/closed/wall)
	TEST_ASSERT(istype(stripped_wall, /turf/closed/wall), "A stripped service room wall could not be rebuilt")
	TEST_ASSERT_EQUAL(silo.materials.total_amount(), silo_before, "Taking a service room apart paid out materials")

	// The fixtures stay outpost property
	TEST_ASSERT(HAS_TRAIT(terminal, "outpost_property") && (terminal.resistance_flags & INDESTRUCTIBLE), "The room's computer lost its protection")
	TEST_ASSERT(HAS_TRAIT(table, "outpost_property") && (table.resistance_flags & INDESTRUCTIBLE), "The room's table lost its protection")

	// A visitor's RCD builds nothing on the plating left behind
	hand_rcd.mode = RCD_TURF
	hand_rcd.rcd_design_path = /turf/open/floor/plating/rcd
	TEST_ASSERT_EQUAL(hand_rcd.rcd_create(stripped_floor, visitor), ITEM_INTERACT_BLOCKING, "A visitor's RCD was not refused in a service room")
	var/turf/after_visitor = locate(floor_x, floor_y, site_z)
	TEST_ASSERT_EQUAL(after_visitor.type, /turf/open/floor/plating, "A visitor's RCD built on a stripped service room tile")

	drone_rcd.mode = old_mode
	drone_rcd.delay_mod = old_delay_mod
	settle_room_air(room_turfs)
