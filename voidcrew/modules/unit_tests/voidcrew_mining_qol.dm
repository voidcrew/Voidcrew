/// Regression guards for the mining quality-of-life changes.

/datum/unit_test/voidcrew_orm_claims_without_silo

/datum/unit_test/voidcrew_orm_claims_without_silo/Run()
	var/obj/machinery/mineral/ore_redemption/orm_type = /obj/machinery/mineral/ore_redemption
	TEST_ASSERT(!initial(orm_type.requires_silo), "An ORM must pay out mining points without an ore silo.")

/datum/unit_test/voidcrew_mining_console_quotes_its_price

/datum/unit_test/voidcrew_mining_console_quotes_its_price/Run()
	var/obj/machinery/computer/order_console/mining/console_type = /obj/machinery/computer/order_console/mining
	TEST_ASSERT_EQUAL(initial(console_type.cargo_cost_multiplier), initial(console_type.express_cost_multiplier), "The mining console must quote the price it charges.")

/// Exercise real material intake and its payout signal for every displayed raw ore rate.
/datum/unit_test/voidcrew_orm_quotes_actual_points

/datum/unit_test/voidcrew_orm_quotes_actual_points/Run()
	for(var/upgrade in list(1, 1.7))
		var/obj/machinery/mineral/ore_redemption/orm = allocate(/obj/machinery/mineral/ore_redemption)
		orm.point_upgrade = upgrade
		var/list/data = orm.ui_data(null)
		var/checked_titanium = FALSE
		for(var/list/entry as anything in data["materials"])
			if(entry["category"] != "material")
				continue
			var/datum/material/material = locate(entry["id"])
			TEST_ASSERT_NOTNULL(material, "An ORM material row must refer to a material datum.")
			var/obj/item/stack/ore/ore_type = material.ore_type
			if(!ispath(ore_type, /obj/item/stack/ore) || !initial(ore_type.refined_type))
				TEST_ASSERT_EQUAL(entry["value"], 0, "Materials without redeemable ore must quote zero points.")
				continue
			var/ore_count = 5
			var/obj/item/stack/ore/ore = allocate(ore_type, run_loc_floor_bottom_left, ore_count)
			var/points_before = orm.points
			TEST_ASSERT(orm.materials.insert_item(ore, orm.ore_multiplier) > 0, "The ORM must consume [ore_type] through its real intake.")
			var/awarded_points = orm.points - points_before
			TEST_ASSERT_EQUAL(entry["value"] * ore_count, awarded_points, "The ORM quote must match the [ore_type] payout with point_upgrade [upgrade].")
			if(material.type != /datum/material/titanium)
				continue
			checked_titanium = TRUE
			var/recovered_sheets = orm.materials.mat_container.retrieve_sheets(ore_count, material)
			TEST_ASSERT_EQUAL(recovered_sheets, ore_count, "Raw titanium must retain its sheet yield.")
			TEST_ASSERT_EQUAL(awarded_points, recovered_sheets * 40 * upgrade, "Raw titanium must pay 40 points per recovered sheet before point upgrades.")
		TEST_ASSERT(checked_titanium, "The ORM must display titanium.")

/datum/unit_test/voidcrew_titanium_boulder_points

/datum/unit_test/voidcrew_titanium_boulder_points/Run()
	var/datum/material/titanium = GET_MATERIAL_REF(/datum/material/titanium)
	for(var/sheet_count in list(1, 5))
		var/obj/machinery/bouldertech/refinery/smelter/smelter = allocate(/obj/machinery/bouldertech/refinery/smelter)
		STOP_PROCESSING(SSmachines, smelter)
		var/obj/item/boulder/boulder = allocate(/obj/item/boulder, smelter)
		boulder.set_custom_materials(list((titanium) = sheet_count * SHEET_MATERIAL_AMOUNT))
		boulder.durability = 0
		smelter.process()
		TEST_ASSERT(QDELETED(boulder), "The smelter must consume the titanium boulder.")
		var/recovered_sheets = smelter.silo_materials.mat_container.retrieve_sheets(sheet_count, titanium)
		TEST_ASSERT_EQUAL(recovered_sheets, sheet_count, "Boulder titanium must retain its sheet yield.")
		TEST_ASSERT_EQUAL(smelter.points_held, recovered_sheets * 40, "Boulder titanium must pay 40 points per recovered sheet after the machine multiplier.")
		var/points_before = smelter.points_held
		smelter.process()
		TEST_ASSERT_EQUAL(smelter.points_held, points_before, "A consumed boulder must not award points twice.")

/datum/unit_test/voidcrew_mining_cash_bill

/datum/unit_test/voidcrew_mining_cash_bill/Run()
	var/datum/orderable_item/consumables/space_cash/product = allocate(/datum/orderable_item/consumables/space_cash)
	var/obj/machinery/computer/order_console/mining/console = allocate(/obj/machinery/computer/order_console/mining)
	var/datum/bank_account/account = allocate(/datum/bank_account, "Mining bill test", null, 1, FALSE)
	var/obj/item/card/id/card = allocate(/obj/item/card/id)
	card.registered_account = account
	console.grocery_list[product] = 1
	account.mining_points = 1999
	TEST_ASSERT(!console.purchase_items(card, TRUE), "A bill must not be sold for fewer than 2000 mining points.")
	TEST_ASSERT_EQUAL(account.mining_points, 1999, "A refused purchase must not spend mining points.")
	account.mining_points = 2000
	TEST_ASSERT(console.purchase_items(card, TRUE), "One bill must be purchasable for 2000 mining points.")
	TEST_ASSERT_EQUAL(account.mining_points, 0, "One bill must spend exactly 2000 mining points.")
	var/obj/item/stack/spacecash/bill = allocate(product.purchase_path)
	TEST_ASSERT_EQUAL(bill.amount, 1, "One order must produce one bill.")
	TEST_ASSERT_EQUAL(bill.get_item_credit_value(), 500, "The ordered bill must be worth 500 credits.")
