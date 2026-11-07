/// Money moving through a ship account writes the ledger, cash deposits name the depositor, a bank
/// terminal's vault withdrawal is tallied instead of written per tick, and cargo exports keep stock
/// blocks apart from raw sheets. No database is involved: rows are read back from the queue.
/datum/unit_test/voidcrew_economy_metrics
	var/was_accepting
	var/list/old_pending
	var/list/old_tallies

/datum/unit_test/voidcrew_economy_metrics/Run()
	was_accepting = SSmetrics.accepting
	old_pending = SSmetrics.pending
	old_tallies = SSmetrics.tallies
	SSmetrics.accepting = TRUE
	SSmetrics.pending = list()
	SSmetrics.tallies = list()

	var/obj/structure/overmap/ship/ship = allocate(/obj/structure/overmap/ship)
	var/datum/job/assistant/captain = allocate(/datum/job/assistant)
	captain.crew_ship_ref = WEAKREF(ship)
	var/datum/bank_account/ship/account = allocate(/datum/bank_account/ship, "Metrics test ship", captain, 1, FALSE)
	ship.ship_account = account
	account.account_balance = 1000
	TEST_ASSERT_EQUAL(metric_account_ship(account), ship, "The account's crew slot should lead back to its ship")

	account.adjust_money(250, "Test income")
	TEST_ASSERT_EQUAL(length(SSmetrics.pending), 1, "A ship account change should write one ledger row")
	var/list/row = SSmetrics.pending[1]
	// A literal: the METRIC_* defines are included after the unit tests.
	TEST_ASSERT_EQUAL(row["category"], "economy", "ledger category")
	TEST_ASSERT_EQUAL(row["event"], "ship_account_change", "ledger event")
	TEST_ASSERT_EQUAL(row["credits"], 250, "the ledger records the change")
	TEST_ASSERT_EQUAL(row["subject"], "Test income", "the ledger subject is the reason given")
	TEST_ASSERT_EQUAL(row["ship_name"], ship.name, "the ledger names the account's ship")
	TEST_ASSERT(findtext(row["details"], "\"balance\":1250"), "the ledger records the balance after the change")

	account.adjust_money(-100)
	TEST_ASSERT_EQUAL(length(SSmetrics.pending), 2, "A spend should write one ledger row")
	row = SSmetrics.pending[2]
	TEST_ASSERT_EQUAL(row["credits"], -100, "spending is negative credits")
	TEST_ASSERT(findtext(row["subject"], "voidcrew_economy_metrics"), "A change with no reason should name the proc that made it, got [row["subject"]]")

	TEST_ASSERT(!account.adjust_money(-100000), "The account should refuse an overdraft")
	TEST_ASSERT_EQUAL(length(SSmetrics.pending), 2, "A refused spend should not be recorded")

	var/datum/bank_account/personal = allocate(/datum/bank_account, "Metrics test personal", null, 1, FALSE)
	personal.adjust_money(500, "Test")
	TEST_ASSERT_EQUAL(length(SSmetrics.pending), 2, "Accounts that aren't a ship's or an outpost's stay out of the ledger")

	var/mob/living/carbon/human/consistent/user = allocate(/mob/living/carbon/human/consistent)
	var/obj/item/card/id/card = allocate(/obj/item/card/id)
	card.registered_account = account
	var/obj/item/holochip/chip = allocate(/obj/item/holochip, null, 40)
	TEST_ASSERT(card.insert_money(chip, user), "The ID should take the holochip")
	TEST_ASSERT_EQUAL(length(SSmetrics.pending), 4, "A deposit should write a ledger row and a cash_deposit row")
	row = SSmetrics.pending[4]
	TEST_ASSERT_EQUAL(row["event"], "cash_deposit", "deposit event")
	TEST_ASSERT_EQUAL(row["credits"], 40, "the deposit records the cash's value")
	TEST_ASSERT_EQUAL(row["subject"], "/obj/item/holochip", "the deposit records what was paid in")
	TEST_ASSERT_EQUAL(row["ship_name"], ship.name, "the deposit names the account's ship")

	var/obj/machinery/computer/bank_machine/bank = allocate(/obj/machinery/computer/bank_machine)
	bank.synced_bank_account = account
	bank.start_siphon(user)
	bank.process(1)
	bank.end_siphon()
	TEST_ASSERT_EQUAL(account.account_balance, 1090, "The terminal should have withdrawn one tick's worth")
	TEST_ASSERT_EQUAL(length(SSmetrics.pending), 4, "A vault withdrawal tick should be tallied, not written as a row")
	TEST_ASSERT_EQUAL(length(SSmetrics.tallies), 1, "A vault withdrawal tick should start one tally")
	var/list/tally = SSmetrics.tallies[SSmetrics.tallies[1]]
	TEST_ASSERT_EQUAL(tally["event"], "ship_account_drain", "drain event")
	TEST_ASSERT_EQUAL(tally["credits"], -100, "the drain tally sums what left the account")

	if(!length(GLOB.exports_list))
		setupExports()
	var/datum/export/material/market/gold/gold_export = locate(/datum/export/material/market/gold) in GLOB.exports_list
	TEST_ASSERT_NOTNULL(gold_export, "The gold export should exist")
	var/datum/export_report/report = new
	metric_watch_exports(report)
	var/obj/item/stock_block/block = allocate(/obj/item/stock_block)
	var/obj/item/stack/sheet/mineral/gold/sheets = allocate(/obj/item/stack/sheet/mineral/gold, null, 5)
	metric_note_export(report, gold_export, block, 300, 3 * gold_export.amount_report_multiplier)
	metric_note_export(report, gold_export, sheets, 200, 5 * gold_export.amount_report_multiplier)
	report.total_amount[gold_export] = 8 * gold_export.amount_report_multiplier
	report.total_value[gold_export] = 500
	metric_cargo_exports(report, account, null)
	TEST_ASSERT_EQUAL(length(SSmetrics.pending), 6, "Stock blocks and raw sheets of one material should be separate export rows")
	row = SSmetrics.pending[5]
	TEST_ASSERT_EQUAL(row["event"], "cargo_export", "export event")
	TEST_ASSERT(findtext(row["details"], "\"kind\":\"stock_block\""), "the first sale was a stock block")
	TEST_ASSERT_EQUAL(row["credits"], 300, "the stock block row records its own value")
	TEST_ASSERT_EQUAL(row["quantity"], 3, "export quantities are counted in sheets")
	row = SSmetrics.pending[6]
	TEST_ASSERT(findtext(row["details"], "\"kind\":\"material\""), "the second sale was raw sheets")
	TEST_ASSERT_EQUAL(row["credits"], 200, "the sheet row records its own value")
	qdel(report)

/datum/unit_test/voidcrew_economy_metrics/Destroy()
	SSmetrics.accepting = was_accepting
	SSmetrics.pending = old_pending
	SSmetrics.tallies = old_tallies
	return ..()

/// Printable disks have no special export reward, regardless of their saved programs.
/datum/unit_test/voidcrew_nanite_disk_exports/Run()
	if(!length(GLOB.exports_list))
		setupExports()
	var/datum/export/nanite_disk/disk_export = locate(/datum/export/nanite_disk) in GLOB.exports_list
	TEST_ASSERT_NOTNULL(disk_export, "The nanite disk export should exist")
	TEST_ASSERT_EQUAL(disk_export.cost, 0, "Nanite disks should have no special export reward")
	TEST_ASSERT_EQUAL(disk_export.init_cost, 0, "Non-elastic nanite disk valuation should also be zero")

	var/datum/design/nanite_disk/design = allocate(/datum/design/nanite_disk)
	var/obj/item/disk/nanite_program/source_disk = allocate(design.build_path)
	var/datum/nanite_program/source_program = new /datum/nanite_program/regenerative
	source_program.trigger_code = 321
	source_disk.backup += source_program

	for(var/apply_elastic in list(FALSE, TRUE))
		var/datum/export_report/sale_report = allocate(/datum/export_report)
		for(var/batch in 1 to 3)
			for(var/disk_state in list("blank", "programmed", "copied"))
				var/obj/item/disk/nanite_program/disk = allocate(design.build_path)
				// Fabricated items retain the materials spent on their design.
				disk.set_custom_materials(design.materials)
				switch(disk_state)
					if("programmed")
						disk.backup += new /datum/nanite_program/regenerative
					if("copied")
						// The cloud controller saves backups through program.copy().
						var/datum/nanite_program/copied_program = source_program.copy()
						disk.backup += copied_program
						TEST_ASSERT(copied_program != source_program, "A copied disk should contain an independent program")
						TEST_ASSERT_EQUAL(copied_program.trigger_code, 321, "The copied disk should retain its saved programming")

				var/context = "[disk_state] disk, batch [batch], elasticity [apply_elastic]"
				TEST_ASSERT_EQUAL(disk_export.get_cost(disk, apply_elastic), 0, "[context] should have no special export value")
				var/backup_count = length(disk.backup)
				var/datum/export_report/quote = export_item_and_contents(disk, apply_elastic = apply_elastic, dry_run = TRUE)
				TEST_ASSERT_NULL(quote.total_value[disk_export], "Dry-run valuation should not reward [context]")
				TEST_ASSERT_NULL(quote.total_amount[disk_export], "Dry-run valuation should not count [context] as a special export")
				TEST_ASSERT(!QDELETED(disk), "Dry-run valuation should preserve [context]")
				TEST_ASSERT_EQUAL(length(disk.backup), backup_count, "Dry-run valuation should preserve the programs on [context]")
				qdel(quote)

				var/list/recyclable = disk.get_material_composition()
				TEST_ASSERT_EQUAL(recyclable[GET_MATERIAL_REF(/datum/material/iron)], 300, "[context] should retain its recyclable iron")
				TEST_ASSERT_EQUAL(recyclable[GET_MATERIAL_REF(/datum/material/glass)], 100, "[context] should retain its recyclable glass")
				export_item_and_contents(disk, apply_elastic = apply_elastic, dry_run = FALSE, external_report = sale_report)
				TEST_ASSERT(QDELETED(disk), "An actual cargo export should consume [context]")
				TEST_ASSERT_NULL(sale_report.total_value[disk_export], "Repeated manufacture/export should not reward [context]")
				TEST_ASSERT_NULL(sale_report.total_amount[disk_export], "Repeated manufacture/export should not count [context] as a special export")

	disk_export.process()
	TEST_ASSERT_EQUAL(disk_export.cost, 0, "Export price recovery should not restore a nanite disk reward")

/// Cargo quotes and sales pay only for the shell, even with large exotic gas mixtures.
/datum/unit_test/voidcrew_gas_canister_exports
	var/datum/export/large/gas_canister/canister_export
	var/saved_cost

/datum/unit_test/voidcrew_gas_canister_exports/Run()
	if(!length(GLOB.exports_list))
		setupExports()
	canister_export = locate(/datum/export/large/gas_canister) in GLOB.exports_list
	TEST_ASSERT_NOTNULL(canister_export, "The gas canister export should exist")
	saved_cost = canister_export.cost
	var/list/fillings = list(
		"empty" = list(),
		"tritium" = list(/datum/gas/tritium = 1000000),
		"mixed" = list(/datum/gas/antinoblium = 1000000, /datum/gas/nitrium = 1000000),
	)
	for(var/apply_elastic in list(FALSE, TRUE))
		for(var/dry_run in list(TRUE, FALSE))
			var/empty_value
			for(var/filling in fillings)
				var/obj/machinery/portable_atmospherics/canister/canister = allocate(/obj/machinery/portable_atmospherics/canister)
				var/datum/gas_mixture/mixture = canister.return_air()
				var/list/gases = fillings[filling]
				for(var/gas_type in gases)
					mixture.assert_gas(gas_type)
					mixture.gases[gas_type][MOLES] = gases[gas_type]
				// Compare each filling at the same shell price before sale elasticity.
				canister_export.cost = canister_export.init_cost
				var/datum/export_report/report = allocate(/datum/export_report)
				export_item_and_contents(canister, apply_elastic = apply_elastic, dry_run = dry_run, external_report = report)
				var/value = counterlist_sum(report.total_value)
				var/context = "[filling] canister, elasticity [apply_elastic], dry run [dry_run]"
				TEST_ASSERT_EQUAL(report.total_amount[canister_export], 1, "Cargo should count one shell for [context]")
				TEST_ASSERT_EQUAL(value, canister_export.init_cost, "Cargo should pay only the shell value for [context]")
				if(filling == "empty")
					empty_value = value
				else
					TEST_ASSERT_EQUAL(value, empty_value, "Gas contents should not increase the empty canister payout for [context]")
				TEST_ASSERT_EQUAL(!!QDELETED(canister), !dry_run, "Only an actual cargo sale should consume [context]")

/datum/unit_test/voidcrew_gas_canister_exports/Destroy()
	if(canister_export)
		canister_export.cost = saved_cost
	return ..()
