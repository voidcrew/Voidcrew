/**
 * Outpost floors (voidcrew/modules/trade_floors/): tests of package P9.
 * Owner: P9. Subtype /datum/unit_test/voidcrew_outpost_floors and use the helpers in
 * voidcrew_outpost_floors_helpers.dm (P0, frozen). Fork defines are included after the tests: write the literal
 * value with a comment naming the define. Pin other packages' outputs directly and never wait for an AI walk.
 *
 * What P9 covers: the three counters sell the floor lease and none sells the deed, the admin panel lists a floor and
 * refuses what a floor cannot do, the dock terminal's housing list names a floor by its place, the derelict's claim
 * is left alone, and record_floor_metric() writes the rows spec 10 lists.
 */

// ===== THE COUNTERS =====

/// The three trader shops put the floor lease on the Colonial Registry shelf, at the one price, and hold it once
/datum/unit_test/voidcrew_outpost_floors/migration_counters
	var/list/shop_types = list(
		/datum/outpost_shop/general,
		/datum/outpost_shop/outfitter,
		/datum/outpost_shop/black_market,
	)

/datum/unit_test/voidcrew_outpost_floors/migration_counters/Run()
	for(var/shop_type in shop_types)
		var/datum/outpost_shop/shop = allocate(shop_type)
		TEST_ASSERT(/datum/shop_sku/outpost_floor in shop.sku_types, "[shop_type] does not list the floor lease")
		TEST_ASSERT("Colonial Registry" in shop.categories, "[shop_type] has no Colonial Registry tab, so the lease would never draw")
		var/leases = 0
		for(var/datum/shop_sku/sku as anything in shop.skus)
			if(!istype(sku, /datum/shop_sku/outpost_floor))
				continue
			leases++
			TEST_ASSERT_EQUAL(sku.category, "Colonial Registry", "[shop_type] sells the lease under the wrong tab")
			TEST_ASSERT_EQUAL(sku.price_credits, 6000, "[shop_type] sells the lease at another price") // OUTPOST_FLOOR_COST_CREDITS
			TEST_ASSERT_EQUAL(sku.price_vouchers, 2, "[shop_type] asks another number of vouchers") // OUTPOST_FLOOR_COST_VOUCHERS
			TEST_ASSERT(sku.fixed_price, "[shop_type] lets the lease go on special")
			TEST_ASSERT(!sku.contract_reward, "[shop_type] could pay a contract in leases")
		TEST_ASSERT_EQUAL(leases, 1, "[shop_type] should hold the lease once, holds it [leases] times")

/// The deed is an admin spawn only: the item and its shelf entry still exist, and no shop carries it on any shelf
/datum/unit_test/voidcrew_outpost_floors/migration_deed_kept

/datum/unit_test/voidcrew_outpost_floors/migration_deed_kept/Run()
	TEST_ASSERT(ispath(/obj/item/outpost_deed, /obj/item), "The deed item is gone; it stays as an admin spawn")
	TEST_ASSERT(ispath(/datum/shop_sku/outpost_deed, /datum/shop_sku), "The deed's shelf entry is gone; the founding tests use it")
	for(var/shop_type in subtypesof(/datum/outpost_shop))
		var/datum/outpost_shop/shop = allocate(shop_type)
		var/list/occurrences = shop.sku_types + shop.rotating_pool + shop.rare_pool + shop.favor_sku_types + shop.chart_pool
		for(var/datum/shop_rotation/rotation as anything in shop.live_rotations)
			occurrences |= rotation.pool
		TEST_ASSERT(!(/datum/shop_sku/outpost_deed in occurrences), "[shop_type] sells the deed")
		for(var/datum/shop_sku/sku as anything in shop.skus)
			TEST_ASSERT(!istype(sku, /datum/shop_sku/outpost_deed), "[shop_type] has a deed on its shelves")

// ===== THE ADMIN PANEL =====

/// The panel lists a floor by its place, reads it without an overmap position, and refuses what a floor cannot do
/datum/unit_test/voidcrew_outpost_floors/migration_admin
	var/mob/living/carbon/human/consistent/operator

/datum/unit_test/voidcrew_outpost_floors/migration_admin/Destroy()
	if(operator)
		operator.key = null
	return ..()

/datum/unit_test/voidcrew_outpost_floors/migration_admin/Run()
	operator = test_person(run_loc_floor_bottom_left)
	operator.key = "floorsadmintest"
	operator.mind_initialize()
	var/obj/structure/overmap/trader_outpost/outpost = test_outpost()
	var/datum/outpost_floor/floor = test_floor(outpost, 1, with_host = TRUE)
	if(!floor)
		return
	var/obj/structure/overmap/dynamic/player_outpost/floor/host = floor.host
	host.name = "Rock Bottom"
	host.display_name = "Rock Bottom"
	host.loaded = TRUE
	var/datum/outpost_manipulator/unit_test/panel = allocate(/datum/outpost_manipulator/unit_test, operator)
	panel.selected = host

	var/place = "Rock Bottom, [format_text(outpost.name)]"
	TEST_ASSERT_EQUAL(outpost_place_name(host), place, "A floor is not named by its place")
	var/list/data = panel.ui_data(operator)
	TEST_ASSERT(islist(data) && islist(data["outposts"]), "The panel's data did not build with a floor host in the world")
	var/list/listed
	for(var/list/row as anything in data["outposts"])
		if(row["ref"] == REF(host))
			listed = row
	TEST_ASSERT_NOTNULL(listed, "The panel does not list the floor")
	TEST_ASSERT_EQUAL(listed["name"], place, "The panel lists the floor by another name")
	TEST_ASSERT(findtext(listed["coords"], "Floor 1,") == 1, "The panel does not say which floor it is: [listed["coords"]]")
	var/list/selected_data = data["selected"]
	TEST_ASSERT_NOTNULL(selected_data, "The panel gave no details for the selected floor")
	TEST_ASSERT_EQUAL(selected_data["name"], place, "The details name the floor another way")
	TEST_ASSERT_EQUAL(selected_data["coords"], listed["coords"], "The details place the floor elsewhere")
	TEST_ASSERT_EQUAL(selected_data["shell"], "Floor shell", "The details claim a shell the floor does not keep")

	// Nothing docks at a floor, and a lockdown would shut visitors out of its clone vat and its pad
	var/mode_before = host.dock_mode
	panel.manage_outpost(host, operator, "dock_mode", list("mode" = "lockdown")) // OUTPOST_DOCK_MODE_LOCKDOWN
	TEST_ASSERT_EQUAL(host.dock_mode, mode_before, "The panel changed a floor's dock mode")
	TEST_ASSERT_NOTNULL(panel.error, "The panel refused a dock mode without saying so")
	panel.error = null
	// It is not on the overmap, so there is nothing to jump to
	var/turf/standing = get_turf(operator)
	panel.manage_outpost(host, operator, "jump_overmap", list())
	TEST_ASSERT_EQUAL(get_turf(operator), standing, "The panel sent the admin somewhere for a floor's overmap jump")
	TEST_ASSERT_NOTNULL(panel.error, "The panel refused the overmap jump without saying so")
	panel.error = null
	// A floor has no ship bay, paid or granted
	panel.manage_outpost(host, operator, "install_bays", list())
	TEST_ASSERT(!host.ship_bay_installed, "The panel installed a ship bay on a floor")
	TEST_ASSERT_NOTNULL(panel.error, "The panel refused the ship bay without saying so")

// ===== HOUSING =====

/// A terminal with no client and no window, for the housing list alone
/datum/lobby_terminal/floors_migration_test

/datum/lobby_terminal/floors_migration_test/New()
	return // no ..(): no client, no window

/// The dock terminal and the admin panel name a floor "<floor>, <outpost>", and a site that is not a floor by its name
/datum/unit_test/voidcrew_outpost_floors/migration_housing
	var/mob/living/carbon/human/consistent/guest

/datum/unit_test/voidcrew_outpost_floors/migration_housing/Destroy()
	if(guest)
		guest.key = null
	return ..()

/datum/unit_test/voidcrew_outpost_floors/migration_housing/Run()
	guest = test_person(run_loc_floor_bottom_left)
	guest.key = "floorshousingtest"
	var/obj/structure/overmap/trader_outpost/outpost = test_outpost()
	var/datum/outpost_floor/floor = test_floor(outpost, 1, with_host = TRUE)
	if(!floor)
		return
	var/obj/structure/overmap/dynamic/player_outpost/floor/host = floor.host
	host.name = "Rock Bottom"
	host.loaded = TRUE
	var/place = "Rock Bottom, [format_text(outpost.name)]"
	TEST_ASSERT_EQUAL(outpost_place_name(host), place, "A floor is not named by its place")
	TEST_ASSERT(findtext(outpost_place_name(host), "improper") == 0, "The outpost's name kept its text macro")

	// An unowned floor is not on the list; an owned, loaded one is, under its place
	var/datum/lobby_terminal/floors_migration_test/terminal = allocate(/datum/lobby_terminal/floors_migration_test)
	TEST_ASSERT(!(host in terminal.housing_outposts()), "An unowned floor is offered as a home")
	host.founder_ckey = "floorsowner"
	TEST_ASSERT(host in terminal.housing_outposts(), "A floor with an owner is not offered as a home")
	var/list/data = terminal.housing_data(guest)
	var/list/row
	for(var/list/candidate as anything in data["outposts"])
		if(candidate["ref"] == REF(host))
			row = candidate
	TEST_ASSERT_NOTNULL(row, "The housing list has no row for the floor")
	TEST_ASSERT_EQUAL(row["name"], place, "The housing list names the floor by something else")

	// A host that is part of no floor keeps its own name
	host.floor = null
	TEST_ASSERT_EQUAL(outpost_place_name(host), "Rock Bottom", "A host with no floor is named by something else")
	TEST_ASSERT_EQUAL(outpost_place_name(null), "", "A missing site has a name")
	host.floor = floor

// ===== THE DERELICT =====

/// A crew with a floor may still claim the round's derelict: the one-floor rule is the floor host's alone
/datum/unit_test/voidcrew_outpost_floors/migration_derelict_claim
	var/mob/living/carbon/human/consistent/holder

/datum/unit_test/voidcrew_outpost_floors/migration_derelict_claim/Destroy()
	if(holder)
		holder.key = null
	return ..()

/datum/unit_test/voidcrew_outpost_floors/migration_derelict_claim/Run()
	holder = test_person(run_loc_floor_bottom_left)
	holder.key = "floorsholdertest"
	holder.mind_initialize()
	var/obj/structure/overmap/trader_outpost/outpost = test_outpost()
	var/datum/outpost_floor/floor = test_floor(outpost, 1, with_host = TRUE)
	if(!floor)
		return
	floor.host.founder_ckey = "floorsholdertest"
	TEST_ASSERT_NOTNULL(floor_holder_denial(holder), "The test person does not hold a floor")
	var/obj/structure/overmap/dynamic/player_outpost/derelict/derelict = allocate(/obj/structure/overmap/dynamic/player_outpost/derelict)
	TEST_ASSERT_NULL(derelict.claim_denial(holder), "Holding a floor stops a crew claiming the derelict")

// ===== ROUND METRICS =====

/// record_floor_metric() writes the columns the catalog in floor_metrics.dm promises
/datum/unit_test/voidcrew_outpost_floors/migration_metrics
	var/was_accepting
	var/list/old_pending
	var/list/old_tallies
	var/mob/living/carbon/human/consistent/owner
	var/mob/living/carbon/human/consistent/visitor

/datum/unit_test/voidcrew_outpost_floors/migration_metrics/Destroy()
	SSmetrics.accepting = was_accepting
	SSmetrics.pending = old_pending
	SSmetrics.tallies = old_tallies
	if(owner)
		owner.key = null
	if(visitor)
		visitor.key = null
	return ..()

/// The row record_floor_metric() just queued after `rows_before` were there, or null when it queued none or several
/datum/unit_test/voidcrew_outpost_floors/migration_metrics/proc/queued_row(rows_before)
	if(length(SSmetrics.pending) != rows_before + 1)
		return null
	return SSmetrics.pending[length(SSmetrics.pending)]

/datum/unit_test/voidcrew_outpost_floors/migration_metrics/Run()
	was_accepting = SSmetrics.accepting
	old_pending = SSmetrics.pending
	old_tallies = SSmetrics.tallies
	SSmetrics.accepting = TRUE
	SSmetrics.pending = list()
	SSmetrics.tallies = list()

	owner = test_person(run_loc_floor_bottom_left)
	owner.key = "floorsownertest"
	owner.mind_initialize()
	visitor = test_person(run_loc_floor_bottom_left)
	visitor.key = "floorsvisitortest"
	visitor.mind_initialize()
	var/obj/structure/overmap/trader_outpost/outpost = test_outpost()
	var/datum/outpost_floor/floor = test_floor(outpost, 1, with_host = TRUE)
	if(!floor)
		return
	floor.host.founder_ckey = "floorsownertest"
	var/subject = "[format_text(outpost.name)], floor 1"
	var/list/row

	// The fixture's own rows (people and a host made for the test) are not the floor's
	SSmetrics.pending = list()
	// A sale: the buyer spends credits and vouchers, and is the floor's owner, so nobody else is named
	record_floor_metric("floor_bought", floor, owner, 6000) // OUTPOST_FLOOR_COST_CREDITS
	row = queued_row(0)
	TEST_ASSERT_NOTNULL(row, "A sale queued no row, or more than one")
	TEST_ASSERT_EQUAL(row["category"], "floor", "The sale is in another category") // METRIC_FLOOR
	TEST_ASSERT_EQUAL(row["event"], "floor_bought", "The sale has another event name")
	TEST_ASSERT_EQUAL(row["ckey"], "floorsownertest", "The sale is about another person")
	TEST_ASSERT_NULL(row["other_ckey"], "The buyer is named as a second person on their own floor")
	TEST_ASSERT_EQUAL(row["credits"], -6000, "A purchase is not minus its price")
	TEST_ASSERT_EQUAL(row["vouchers"], -2, "A purchase is not minus its vouchers") // OUTPOST_FLOOR_COST_VOUCHERS
	TEST_ASSERT_EQUAL(row["quantity"], 1, "A sale is not one floor")
	TEST_ASSERT_EQUAL(row["subject"], subject, "A row is about another floor")
	var/list/details = json_decode(row["details"])
	TEST_ASSERT_EQUAL(details["floor"], 1, "The details give another floor number")
	TEST_ASSERT_EQUAL(details["entry"], "crew", "The details give another setting") // OUTPOST_FLOOR_ENTRY_CREW

	// A visit by someone else: they are the person, the owner is the other
	floor.entry_policy = "open" // OUTPOST_FLOOR_ENTRY_OPEN
	record_floor_metric("floor_visit", floor, visitor, 3)
	row = queued_row(1)
	TEST_ASSERT_NOTNULL(row, "A visit queued no row")
	TEST_ASSERT_EQUAL(row["ckey"], "floorsvisitortest", "A visit is about another person")
	TEST_ASSERT_EQUAL(row["other_ckey"], "floorsownertest", "A visit does not name whose floor it was")
	TEST_ASSERT_EQUAL(row["quantity"], 3, "A visit does not count the visitors")
	TEST_ASSERT_EQUAL(row["credits"], 0, "A visit moved money")
	details = json_decode(row["details"])
	TEST_ASSERT_EQUAL(details["entry"], "open", "A row does not carry the setting as it stood") // OUTPOST_FLOOR_ENTRY_OPEN

	// A delivery has nobody to be about: the owner is the other, and the treasury pays
	record_floor_metric("floor_supply_order", floor, null, 450)
	row = queued_row(2)
	TEST_ASSERT_NOTNULL(row, "A delivery queued no row")
	TEST_ASSERT_NULL(row["ckey"], "A delivery is about a person")
	TEST_ASSERT_EQUAL(row["other_ckey"], "floorsownertest", "A delivery does not name the floor's owner")
	TEST_ASSERT_EQUAL(row["credits"], -450, "A delivery is not minus what was paid")
	TEST_ASSERT_EQUAL(row["quantity"], 1, "A delivery is not one order")

	// An NPC customer pays the treasury
	record_floor_metric("floor_npc_sale", floor, null, 60)
	row = queued_row(3)
	TEST_ASSERT_NOTNULL(row, "An NPC sale queued no row")
	TEST_ASSERT_EQUAL(row["credits"], 60, "An NPC sale is not plus what the treasury took")
	TEST_ASSERT_EQUAL(row["quantity"], 1, "An NPC sale is not one sale")

	// The rest are counts
	record_floor_metric("floor_fitting", floor, owner, 1)
	row = queued_row(4)
	TEST_ASSERT_NOTNULL(row, "A fitting queued no row")
	TEST_ASSERT_EQUAL(row["quantity"], 1, "A fitting is not counted")
	TEST_ASSERT_EQUAL(row["credits"], 0, "A fitting moved money")
	record_floor_metric("floor_setting", floor, owner)
	record_floor_metric("floor_hand", floor, visitor)
	record_floor_metric("floor_given_up", floor, owner)
	record_floor_metric("floor_claimed", floor, visitor)
	record_floor_metric("floor_lift_forced", floor, visitor)
	record_floor_metric("floor_warrant", floor, null, 3)
	record_floor_metric("floor_breach", floor, null, 1)
	TEST_ASSERT_EQUAL(length(SSmetrics.pending), 12, "Twelve events were recorded and [length(SSmetrics.pending)] rows were queued")
	var/list/seen = list()
	for(var/list/each as anything in SSmetrics.pending)
		TEST_ASSERT_EQUAL(each["category"], "floor", "A row is outside the floor category") // METRIC_FLOOR
		seen[each["event"]] = TRUE
	TEST_ASSERT_EQUAL(length(seen), 12, "The twelve events of spec 10 were not each written once")

	// A name nobody listed is still written, as a count, so a typo is visible in the table
	record_floor_metric("floor_typo", floor, null, 7)
	row = queued_row(12)
	TEST_ASSERT_NOTNULL(row, "An unlisted event was dropped")
	TEST_ASSERT_EQUAL(row["quantity"], 7, "An unlisted event is not written as a count")

	// Nothing is queued once metrics are off, or for no floor
	SSmetrics.accepting = FALSE
	record_floor_metric("floor_bought", floor, owner, 6000) // OUTPOST_FLOOR_COST_CREDITS
	TEST_ASSERT_EQUAL(length(SSmetrics.pending), 13, "A row was queued while metrics were off")
	SSmetrics.accepting = TRUE
	record_floor_metric("floor_bought", null, owner, 6000) // OUTPOST_FLOOR_COST_CREDITS
	TEST_ASSERT_EQUAL(length(SSmetrics.pending), 13, "A row was queued for no floor")
