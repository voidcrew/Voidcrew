/**
 * Dock terminal shipyard bill (voidcrew/modules/lobby_terminal/lobby_yard.dm).
 *
 * Covers the single commission bill: which lines it charges, the total, the refund when a
 * multi-class spend fails halfway, the join lock being released on every path, and
 * FREE_SHIPS charging nothing. A stand-in ledger replaces the database.
 */

/// Ledger stand-in: balances in memory, one class can be made to fail.
/datum/ship_economy_db/lobby_bill_test
	var/list/balance = list()
	var/fail_class
	var/list/refunded = list()
	var/list/spent_calls = list()
	var/list/unlocked = list()

/datum/ship_economy_db/lobby_bill_test/is_available()
	return TRUE

/datum/ship_economy_db/lobby_bill_test/get_parts(ckey)
	var/list/parts = list()
	for(var/part_class in GLOB.ship_part_classes)
		parts[part_class] = balance[part_class] || 0
	return parts

/datum/ship_economy_db/lobby_bill_test/deduct_part_class(ckey, part_class, amount)
	if(part_class == fail_class || (balance[part_class] || 0) < amount)
		return FALSE
	balance[part_class] -= amount
	return TRUE

/datum/ship_economy_db/lobby_bill_test/add_part(ckey, part_class, quantity = 1, method = "unspecified")
	balance[part_class] = (balance[part_class] || 0) + quantity
	if(method == "refund")
		refunded[part_class] = (refunded[part_class] || 0) + quantity
	return TRUE

/datum/ship_economy_db/lobby_bill_test/spend_parts(ckey, list/requirements)
	spent_calls += list(requirements.Copy())
	return ..()

/datum/ship_economy_db/lobby_bill_test/is_ship_unlocked(ckey, ship_template)
	return ("hull|[ship_template]" in unlocked)

/datum/ship_economy_db/lobby_bill_test/unlock_ship(ckey, ship_template)
	unlocked += "hull|[ship_template]"
	return TRUE

/datum/ship_economy_db/lobby_bill_test/get_unlocked_themes_for_ship(ckey, ship_template)
	var/list/ids = list()
	for(var/entry in unlocked)
		var/list/entry_parts = splittext(entry, "|")
		if(entry_parts[1] == "finish" && entry_parts[2] == "[ship_template]")
			ids += entry_parts[3]
	return ids

/datum/ship_economy_db/lobby_bill_test/unlock_theme(ckey, ship_template, theme_id)
	unlocked += "finish|[ship_template]|[theme_id]"
	return TRUE

/datum/ship_economy_db/lobby_bill_test/get_unlocked_upgrades_for_ship(ckey, ship_template)
	var/list/ids = list()
	for(var/entry in unlocked)
		var/list/entry_parts = splittext(entry, "|")
		if(entry_parts[1] == "module" && entry_parts[2] == "[ship_template]")
			ids += entry_parts[3]
	return ids

/datum/ship_economy_db/lobby_bill_test/unlock_upgrade(ckey, ship_template, upgrade_id)
	unlocked += "module|[ship_template]|[upgrade_id]"
	return TRUE

/// A terminal with no client or browser window, for calling the bill procs directly.
/datum/lobby_terminal/bill_test

/datum/lobby_terminal/bill_test/New()
	return // No client: skip the window and signal setup.

/datum/unit_test/lobby_terminal_bill
	var/datum/map_template/shuttle/voidcrew/hull
	var/datum/ship_theme/finish
	var/datum/ship_upgrade_module/paid_module
	var/datum/ship_upgrade_module/stock_module
	var/datum/ship_upgrade_module/owned_module
	var/list/selections
	/// FREE_SHIPS before the test, restored in Destroy().
	var/was_free_ships

/datum/unit_test/lobby_terminal_bill/Destroy()
	CONFIG_SET(flag/free_ships, was_free_ships)
	return ..()

/datum/unit_test/lobby_terminal_bill/Run()
	was_free_ships = CONFIG_GET(flag/free_ships)
	CONFIG_SET(flag/free_ships, FALSE)
	for(var/datum/map_template/shuttle/voidcrew/candidate as anything in get_purchasable_ship_templates())
		if(length(lobby_yard_cost(candidate.part_requirements)))
			hull = candidate
			break
	TEST_ASSERT(hull, "No hull on the shelf costs parts")

	finish = new
	finish.id = "lobby_bill_finish"
	finish.name = "Test Finish"
	finish.part_cost = list("science" = 2)

	paid_module = new
	paid_module.id = "lobby_bill_paid"
	paid_module.slot = "slot_a"
	paid_module.part_cost = list("combat" = 3, "science" = 1)

	stock_module = new
	stock_module.id = "lobby_bill_stock"
	stock_module.slot = "slot_b"
	stock_module.is_default = TRUE
	stock_module.part_cost = list("combat" = 50)

	owned_module = new
	owned_module.id = "lobby_bill_owned"
	owned_module.slot = "slot_c"
	owned_module.part_cost = list("trade" = 4)

	selections = list("slot_a" = paid_module, "slot_b" = stock_module, "slot_c" = owned_module)

	check_bill_lines()
	check_partial_spend_refund()
	check_commission_paths()
	check_free_ships()

/datum/unit_test/lobby_terminal_bill/proc/check_bill_lines()
	var/list/lines = lobby_yard_bill_lines(hull, finish, selections, FALSE, list(), list("lobby_bill_owned"))
	TEST_ASSERT_EQUAL(length(lines), 3, "An unowned hull, finish and paid module should make three lines; stock and owned items are free")
	var/list/expected = lobby_yard_cost(hull.part_requirements)
	expected["science"] = (expected["science"] || 0) + 3
	expected["combat"] = (expected["combat"] || 0) + 3
	var/list/total = lobby_yard_bill_total(lines)
	for(var/part_class in GLOB.ship_part_classes)
		TEST_ASSERT_EQUAL(total[part_class] || 0, expected[part_class] || 0, "Bill total for [part_class] is wrong")

	lines = lobby_yard_bill_lines(hull, finish, selections, TRUE, list("lobby_bill_finish"), list("lobby_bill_owned"))
	TEST_ASSERT_EQUAL(length(lines), 1, "Owned hull and finish still billed")
	TEST_ASSERT_EQUAL(lines[1]["id"], "lobby_bill_paid", "The remaining line should be the paid module")

	finish.is_default = TRUE
	lines = lobby_yard_bill_lines(hull, finish, list(), TRUE, list(), list())
	TEST_ASSERT_EQUAL(length(lines), 0, "A stock finish was billed")
	finish.is_default = FALSE

/datum/unit_test/lobby_terminal_bill/proc/check_partial_spend_refund()
	var/datum/ship_economy_db/lobby_bill_test/ledger = new
	ledger.balance = list("combat" = 10, "science" = 10)
	ledger.fail_class = "science"
	TEST_ASSERT(!ledger.spend_parts("lobbybilltest", list("combat" = 3, "science" = 2)), "A spend with a failing class went through")
	TEST_ASSERT_EQUAL(ledger.refunded["combat"], 3, "The class taken before the failure was not refunded")
	TEST_ASSERT_EQUAL(ledger.balance["combat"], 10, "Combat parts were lost on a failed spend")
	TEST_ASSERT_EQUAL(ledger.balance["science"], 10, "Science parts changed on a failed spend")

/datum/unit_test/lobby_terminal_bill/proc/check_commission_paths()
	var/test_ckey = "lobbybilltest"
	var/datum/lobby_terminal/bill_test/terminal = new
	var/datum/ship_economy_db/lobby_bill_test/ledger = new
	var/list/total = lobby_yard_bill_total(lobby_yard_bill_lines(hull, finish, selections, FALSE, list(), list()))

	// Short on parts: nothing spent, lock released, a notice.
	GLOB.lobby_join_locks[test_ckey] = world.time
	terminal.run_commission(null, test_ckey, hull, finish, selections, FALSE, ledger)
	TEST_ASSERT(!GLOB.lobby_join_locks[test_ckey], "A refused bill kept the join lock")
	TEST_ASSERT_EQUAL(length(ledger.spent_calls), 0, "A bill the player can't afford was charged")
	TEST_ASSERT(terminal.notice, "A refused bill gave no notice")

	// Enough parts: one spend for the whole bill, every line unlocked, lock released.
	for(var/part_class in total)
		ledger.balance[part_class] = total[part_class] + 1
	terminal.notice = null
	GLOB.lobby_join_locks[test_ckey] = world.time
	terminal.run_commission(null, test_ckey, hull, finish, selections, FALSE, ledger)
	TEST_ASSERT(!GLOB.lobby_join_locks[test_ckey], "A paid bill kept the join lock")
	TEST_ASSERT_EQUAL(length(ledger.spent_calls), 1, "The bill was not charged once ([terminal.notice?["text"] || "no notice"])")
	for(var/part_class in total)
		TEST_ASSERT_EQUAL(ledger.balance[part_class], 1, "Wrong [part_class] charge")
	TEST_ASSERT(("hull|[hull.type]" in ledger.unlocked), "The hull was not unlocked")
	TEST_ASSERT(("finish|[hull.type]|lobby_bill_finish" in ledger.unlocked), "The finish was not unlocked")
	TEST_ASSERT(("module|[hull.type]|lobby_bill_paid" in ledger.unlocked), "The module was not unlocked")
	TEST_ASSERT(!("module|[hull.type]|lobby_bill_stock" in ledger.unlocked), "A stock module was recorded as bought")

	// Everything owned now: a second commission costs nothing.
	GLOB.lobby_join_locks[test_ckey] = world.time
	terminal.run_commission(null, test_ckey, hull, finish, selections, FALSE, ledger)
	TEST_ASSERT(!GLOB.lobby_join_locks[test_ckey], "A free relaunch kept the join lock")
	TEST_ASSERT_EQUAL(length(ledger.spent_calls), 1, "Owned items were charged again")
	qdel(terminal)

/datum/unit_test/lobby_terminal_bill/proc/check_free_ships()
	var/datum/lobby_terminal/bill_test/terminal = new
	var/datum/ship_economy_db/lobby_bill_test/ledger = new
	CONFIG_SET(flag/free_ships, TRUE)
	var/result = terminal.yard_settle(null, "lobbybilltest", hull, finish, selections, ledger)
	CONFIG_SET(flag/free_ships, FALSE)
	TEST_ASSERT_EQUAL(result, TRUE, "FREE_SHIPS refused a commission")
	TEST_ASSERT_EQUAL(length(ledger.spent_calls), 0, "FREE_SHIPS charged parts")
	qdel(terminal)
