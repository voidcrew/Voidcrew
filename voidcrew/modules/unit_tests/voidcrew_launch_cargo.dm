/// Production settlement and export tests; only ferry turf discovery is substituted.
/datum/unit_test/voidcrew_launch_cargo_fixture
	abstract_type = /datum/unit_test/voidcrew_launch_cargo_fixture
	var/list/saved_prices
	var/list/saved_quantities
	var/list/saved_packs
	var/list/saved_audit
	var/saved_modifier
	var/saved_import_total
	var/saved_export_total
	var/list/saved_export_costs

/datum/unit_test/voidcrew_launch_cargo_fixture/proc/save_economy()
	saved_prices = SSstock_market.materials_prices.Copy()
	saved_quantities = SSstock_market.materials_quantity.Copy()
	saved_packs = SSshuttle.supply_packs.Copy()
	saved_audit = SSeconomy.audit_log.Copy()
	saved_modifier = SSeconomy.pack_price_modifier
	saved_import_total = SSeconomy.import_total
	saved_export_total = SSeconomy.export_total
	if(!length(GLOB.exports_list))
		setupExports()
	saved_export_costs = list()
	for(var/datum/export/exporter as anything in GLOB.exports_list)
		saved_export_costs[exporter] = exporter.cost
		exporter.cost = exporter.init_cost

/datum/unit_test/voidcrew_launch_cargo_fixture/Destroy()
	if(saved_prices)
		SSstock_market.materials_prices = saved_prices
		SSstock_market.materials_quantity = saved_quantities
		SSshuttle.supply_packs = saved_packs
		SSeconomy.audit_log = saved_audit
		SSeconomy.pack_price_modifier = saved_modifier
		SSeconomy.import_total = saved_import_total
		SSeconomy.export_total = saved_export_total
		for(var/datum/export/exporter as anything in saved_export_costs)
			exporter.cost = saved_export_costs[exporter]
	return ..()

/obj/machinery/computer/voidcrew_cargo/launch_cargo_test
	var/datum/voidcrew_cargo_shuttle/launch_cargo_test/test_ferry

/obj/machinery/computer/voidcrew_cargo/launch_cargo_test/get_cargo_shuttle()
	return test_ferry

/datum/voidcrew_cargo_shuttle/launch_cargo_test
	var/list/test_turfs = list()

/datum/voidcrew_cargo_shuttle/launch_cargo_test/get_cargo_bay_turfs()
	return test_turfs

/// Listing and actual cart insertion must reject the same inaccessible packs.
/datum/unit_test/voidcrew_launch_cargo_fixture/guards/Run()
	save_economy()
	var/obj/machinery/computer/voidcrew_cargo/console = allocate(/obj/machinery/computer/voidcrew_cargo)
	var/mob/living/carbon/human/user = allocate(/mob/living/carbon/human/consistent)
	var/datum/supply_pack/pack = allocate(/datum/supply_pack)
	pack.id = "launch_cargo_guard_fixture"
	pack.group = "Launch test"
	pack.contains = list(/obj/item/screwdriver)
	pack.access_view = ACCESS_SECURITY
	SSshuttle.supply_packs[pack.id] = pack
	TEST_ASSERT(console.can_order_pack(pack), "Ordinary ship orders must not inherit station access restrictions")
	TEST_ASSERT_EQUAL(length(console.get_packs_data(pack.group)), 1, "Ordinary pack is absent from the ship catalog")
	pack.hidden = TRUE
	TEST_ASSERT_EQUAL(length(console.get_packs_data(pack.group)), 0, "Hidden pack appeared without an emag")
	TEST_ASSERT(!console.add_item(list("id" = pack.id), user), "A forged hidden ID entered the cart")
	console.obj_flags |= EMAGGED
	TEST_ASSERT(console.can_order_pack(pack), "Emag must enable hidden packs")
	pack.contraband = TRUE
	TEST_ASSERT(!console.add_item(list("id" = pack.id), user), "Contraband flag was not checked by cart insertion")
	console.contraband = TRUE
	pack.special = TRUE
	TEST_ASSERT(!console.add_item(list("id" = pack.id), user), "Emag incorrectly bypassed a disabled special pack")
	pack.special_enabled = TRUE
	pack.drop_pod_only = TRUE
	TEST_ASSERT(!console.add_item(list("id" = pack.id), user), "Pod-only pack entered the ship ferry cart")
	pack.drop_pod_only = FALSE
	for(var/invalid in list(0, -1, 0.5, CARGO_MAX_ORDER + 1, "invalid", null))
		TEST_ASSERT(!console.add_item(list("id" = pack.id, "amount" = invalid), user), "Invalid cargo quantity [invalid] entered the cart")
	TEST_ASSERT_EQUAL(length(console.checkout_list), 0, "Rejected orders modified the cart")
	TEST_ASSERT(console.add_item(list("id" = pack.id), user), "Catalog's omitted amount must order one item")
	TEST_ASSERT(console.add_item(list("id" = pack.id, "amount" = CARGO_MAX_ORDER - 1), user), "Valid remaining quantity was rejected")
	TEST_ASSERT(!console.add_item(list("id" = pack.id), user), "Repeated adds exceeded the UI's per-pack cap")
	TEST_ASSERT_EQUAL(length(console.checkout_list), CARGO_MAX_ORDER, "Cart contains the wrong accepted quantity")

	TEST_ASSERT(!valid_material_order_contents(list(/obj/item/stack/sheet/iron = -1)), "Negative material order accepted")
	TEST_ASSERT(!valid_material_order_contents(list(/obj/item/stack/sheet/iron = 1.5)), "Fractional material order accepted")
	TEST_ASSERT(!valid_material_order_contents(list(/obj/item/stack/sheet/iron = MAX_STACK_SIZE * 10 + 1)), "Initial material order bypassed ten-stack cap")
	TEST_ASSERT(!valid_material_order_contents(list(/obj/item/stack/sheet/iron = MAX_STACK_SIZE * 10, /obj/item/stack/sheet/glass = 1)), "Mixed materials bypassed ten-stack cap")
	TEST_ASSERT(valid_material_order_contents(list(/obj/item/stack/sheet/iron = MAX_STACK_SIZE * 9, /obj/item/stack/sheet/glass = MAX_STACK_SIZE)), "Ten valid mixed stacks were rejected")

/// Run real buy(), bank debits, material preflight, crate construction and manifests.
/datum/unit_test/voidcrew_launch_cargo_fixture/settlement/Run()
	save_economy()
	SSstock_market.materials_prices[/datum/material/iron] = 5
	SSstock_market.materials_prices[/datum/material/plasma] = 20
	SSstock_market.materials_quantity[/datum/material/iron] = 100
	SSstock_market.materials_quantity[/datum/material/plasma] = 100
	SSeconomy.pack_price_modifier = 0.8
	var/turf/bay = get_step(run_loc_floor_bottom_left, EAST)
	var/obj/machinery/computer/voidcrew_cargo/launch_cargo_test/console = allocate(/obj/machinery/computer/voidcrew_cargo/launch_cargo_test)
	var/datum/voidcrew_cargo_shuttle/launch_cargo_test/ferry = allocate(/datum/voidcrew_cargo_shuttle/launch_cargo_test)
	ferry.test_turfs = list(bay)
	console.test_ferry = ferry
	var/obj/machinery/computer/bank_machine/bank = allocate(/obj/machinery/computer/bank_machine)
	var/datum/bank_account/account = allocate(/datum/bank_account, "Cargo settlement test", null, 1, FALSE)
	bank.synced_bank_account = account
	console.link_ship_bank(bank)
	var/datum/supply_pack/custom/minerals/pack = allocate(/datum/supply_pack/custom/minerals, "Cargo test", 360, list(/obj/item/stack/sheet/iron = 12, /obj/item/stack/sheet/mineral/plasma = 15))
	var/datum/supply_order/disposable/materials/order = allocate(/datum/supply_order/disposable/materials, pack)
	order.manifest_can_fail = FALSE
	order.applied_coupon = allocate(/obj/item/coupon)
	order.applied_coupon.discount_pct_off = 0.5
	console.checkout_list += order
	TEST_ASSERT_EQUAL(order.get_final_cost(), 560, "A material quote must include freight and ignore pack/coupon discounts")
	account.account_balance = 500
	console.buy()
	TEST_ASSERT_EQUAL(account.account_balance, 500, "Failed payment changed the account")
	TEST_ASSERT_EQUAL(SSstock_market.materials_quantity[/datum/material/iron], 100, "Failed payment consumed iron")
	TEST_ASSERT_EQUAL(SSstock_market.materials_quantity[/datum/material/plasma], 100, "Failed payment consumed plasma")
	TEST_ASSERT(order in console.checkout_list, "Unpaid order disappeared")
	TEST_ASSERT(!(locate(/obj/structure/closet/crate) in bay), "Unpaid material order generated a crate")

	account.account_balance = 1000
	SSstock_market.materials_quantity[/datum/material/plasma] = 10
	console.buy()
	TEST_ASSERT_EQUAL(account.account_balance, 1000, "A partially available pooled order was charged")
	TEST_ASSERT_EQUAL(pack.contains[/obj/item/stack/sheet/mineral/plasma], 15, "Unavailable order was silently reduced")
	TEST_ASSERT_EQUAL(SSstock_market.materials_quantity[/datum/material/iron], 100, "Refused mixed order consumed its available material")
	TEST_ASSERT(order in console.checkout_list, "Unavailable order disappeared instead of remaining retryable")
	TEST_ASSERT(!(locate(/obj/structure/closet/crate) in bay), "Partial material order generated a crate")

	SSstock_market.materials_quantity[/datum/material/plasma] = 100
	account.siphon_lock_until = world.time + 100
	console.buy()
	TEST_ASSERT_EQUAL(account.account_balance, 1000, "Siphon-locked account was billed")
	TEST_ASSERT_EQUAL(SSstock_market.materials_quantity[/datum/material/plasma], 100, "Refused bank withdrawal consumed stock")
	account.siphon_lock_until = 0
	console.buy()
	TEST_ASSERT_EQUAL(account.account_balance, 440, "Delivered material debit differed from the displayed 560-credit quote")
	TEST_ASSERT_EQUAL(SSstock_market.materials_quantity[/datum/material/iron], 88, "Successful shipment did not consume exactly twelve iron")
	TEST_ASSERT_EQUAL(SSstock_market.materials_quantity[/datum/material/plasma], 85, "Successful shipment did not consume exactly fifteen plasma")
	TEST_ASSERT_EQUAL(SSstock_market.materials_prices[/datum/material/iron], 5, "Import raised its own resale price")
	TEST_ASSERT_EQUAL(SSstock_market.materials_prices[/datum/material/plasma], 20, "Plasma import raised its own resale price")
	TEST_ASSERT_EQUAL(length(console.checkout_list), 0, "Paid order remained in the cart")
	var/obj/structure/closet/crate/delivery = locate() in bay
	TEST_ASSERT_NOTNULL(delivery, "Successful material payment produced no crate")
	var/obj/item/stack/sheet/iron/iron = locate() in delivery
	var/obj/item/stack/sheet/mineral/plasma/plasma = locate() in delivery
	TEST_ASSERT_EQUAL(iron?.amount, 12, "Delivered iron quantity is wrong")
	TEST_ASSERT_EQUAL(plasma?.amount, 15, "Delivered plasma quantity is wrong")
	var/obj/item/paper/fluff/jobs/cargo/manifest/manifest = delivery.manifest?.resolve()
	TEST_ASSERT_EQUAL(manifest?.order_cost, 560, "Manifest recorded nominal materials cost instead of actual payment")
	TEST_ASSERT(!order.settle_ship_order(account), "The same order was paid a second time")
	TEST_ASSERT_EQUAL(account.account_balance, 440, "Repeated settlement debited money")
	qdel(delivery)

	// An ordinary discounted shipment must record the final paid bill as well.
	var/datum/supply_pack/plating_pack = allocate(/datum/supply_pack/security/modsuit_plating)
	var/datum/supply_order/plating_order = allocate(/datum/supply_order, plating_pack)
	plating_order.manifest_can_fail = FALSE
	plating_order.applied_coupon = allocate(/obj/item/coupon)
	plating_order.applied_coupon.discount_pct_off = 0.5
	console.checkout_list += plating_order
	console.buy()
	TEST_ASSERT_EQUAL(account.account_balance, 360, "Ordinary .8 modifier and .5 coupon did not debit the displayed 80-credit price")
	delivery = locate() in bay
	manifest = delivery?.manifest?.resolve()
	TEST_ASSERT_EQUAL(manifest?.order_cost, 80, "Discounted shipment retained an inflated 200-credit manifest")
	TEST_ASSERT_EQUAL(length(console.checkout_list), 0, "Paid discounted order remained queued")
	qdel(delivery)

	// Coupon Master can generate75% flash coupons, including cheap25-credit goodies.
	for(var/discount in list(0.5, 0.75))
		var/datum/supply_pack/goody_pack = allocate(/datum/supply_pack/goody/fish_catalog)
		var/datum/supply_order/goody_order = allocate(/datum/supply_order, goody_pack)
		goody_order.manifest_can_fail = FALSE
		goody_order.applied_coupon = allocate(/obj/item/coupon)
		goody_order.applied_coupon.discount_pct_off = discount
		var/paid = goody_order.get_final_cost()
		var/before_payment = account.account_balance
		console.checkout_list += goody_order
		console.buy()
		TEST_ASSERT_EQUAL(account.account_balance, before_payment - paid, "Discounted goody did not debit its displayed bill")
		var/obj/item/storage/box/goody = locate() in bay
		TEST_ASSERT_NOTNULL(goody, "Paid goody was not delivered")
		manifest = locate() in goody
		TEST_ASSERT_EQUAL(manifest?.order_cost, paid, "Goody manifest did not record its actual discounted bill")
		manifest.stamp_cache = list("stamp-ok")
		var/datum/export_report/goody_report = export_item_and_contents(goody, apply_elastic = FALSE, dry_run = FALSE)
		TEST_ASSERT_EQUAL(counterlist_sum(goody_report.total_value), FLOOR(paid * 0.1, 1), "Cheap goody paperwork retained its twenty-credit refund")
		TEST_ASSERT(counterlist_sum(goody_report.total_value) < paid, "Discounted goody refunded more than its bill")

	// The wooden tattoo-kit crate alone formerly exceeded its72-credit flash-sale bill.
	var/datum/supply_pack/wood_pack = allocate(/datum/supply_pack/misc/tattoo_kit)
	var/datum/supply_order/wood_order = allocate(/datum/supply_order, wood_pack)
	wood_order.manifest_can_fail = FALSE
	wood_order.applied_coupon = allocate(/obj/item/coupon)
	wood_order.applied_coupon.discount_pct_off = 0.75
	console.checkout_list += wood_order
	console.buy()
	delivery = locate() in bay
	TEST_ASSERT_EQUAL(delivery?.cargo_paid_cost, 72, "Paid wooden crate lacks its actual flash-sale payment")
	manifest = delivery?.manifest?.resolve()
	manifest.stamp_cache = list("stamp-ok")
	var/datum/export_report/wood_manifest_report = export_item_and_contents(manifest, apply_elastic = FALSE, dry_run = FALSE)
	TEST_ASSERT_EQUAL(counterlist_sum(wood_manifest_report.total_value), 7, "Wooden shipment manifest exceeds ten percent of payment")
	// Removing the paperwork must not remove the crate's cap.
	var/datum/export_report/wood_report = export_single_item(delivery, apply_elastic = FALSE, dry_run = FALSE)
	TEST_ASSERT_EQUAL(counterlist_sum(wood_report.total_value), 7, "Removing its manifest restored a discounted crate's uncapped refund")

	for(var/tank_pack_type in list(/datum/supply_pack/materials/watertank, /datum/supply_pack/materials/fueltank))
		account.account_balance = 1000
		var/datum/supply_pack/tank_pack = allocate(tank_pack_type)
		TEST_ASSERT_EQUAL(tank_pack.discountable, SUPPLY_PACK_NOT_DISCOUNTABLE, "Tank floor calculation assumes coupons cannot select this pack")
		var/datum/supply_order/tank_order = allocate(/datum/supply_order, tank_pack)
		tank_order.manifest_can_fail = FALSE
		var/tank_paid = tank_order.get_final_cost()
		console.checkout_list += tank_order
		console.buy()
		TEST_ASSERT_EQUAL(account.account_balance, 1000 - tank_paid, "Tank import did not pay its favorable trait bill")
		delivery = locate() in bay
		TEST_ASSERT_NOTNULL(delivery, "Paid tank shipment was not delivered")
		manifest = delivery.manifest?.resolve()
		manifest.stamp_cache = list("stamp-ok")
		var/datum/export_report/tank_report = export_item_and_contents(delivery, apply_elastic = TRUE, dry_run = FALSE)
		TEST_ASSERT(counterlist_sum(tank_report.total_value) < tank_paid, "Full tank and packaging export exceeded the supported discounted bill")

	// Follow the strongest eligible coupon through actual ship debit, Wick sales,
	// and a real cargo export deposit back into the same account.
	account.account_balance = 1000
	var/datum/supply_pack/spacewear_pack = allocate(/datum/supply_pack/emergency/plasma_spacesuit)
	TEST_ASSERT(spacewear_pack.discountable != SUPPLY_PACK_NOT_DISCOUNTABLE, "Spacewear regression must use a genuinely coupon-eligible pack")
	var/datum/supply_order/spacewear_order = allocate(/datum/supply_order, spacewear_pack)
	spacewear_order.manifest_can_fail = FALSE
	spacewear_order.applied_coupon = allocate(/obj/item/coupon)
	spacewear_order.applied_coupon.discount_pct_off = 0.75
	console.checkout_list += spacewear_order
	console.buy()
	TEST_ASSERT_EQUAL(account.account_balance, 860, "Spacewear flash coupon did not charge its actual140-credit bill")
	delivery = locate() in bay
	TEST_ASSERT_NOTNULL(delivery, "Paid spacewear was not delivered")
	var/mob/living/carbon/human/seller = allocate(/mob/living/carbon/human/consistent)
	var/obj/item/card/id/advanced/seller_id = allocate(/obj/item/card/id/advanced)
	seller_id.registered_account = account
	TEST_ASSERT(seller.put_in_hands(seller_id), "Seller could not carry their paying ID")
	var/datum/shop_buyback/suits = allocate(/datum/shop_buyback/fitter/salvage_spacesuit)
	var/datum/shop_buyback/helmets = allocate(/datum/shop_buyback/fitter/salvage_space_helmet)
	var/suit_demand_before = suits.demand
	var/helmet_demand_before = helmets.demand
	var/garments_sold = 0
	for(var/obj/item/clothing/apparel in delivery.contents.Copy())
		TEST_ASSERT(seller.put_in_hands(apparel), "Delivered spacewear could not be handed to Wick")
		var/datum/shop_buyback/buyer = istype(apparel, /obj/item/clothing/suit/space) ? suits : helmets
		TEST_ASSERT(buyer.try_sell(seller, null, TRUE), "Wick's real buyback rejected an ordinary delivered garment")
		garments_sold++
	TEST_ASSERT_EQUAL(garments_sold, 4, "Spacewear pack must deliver and sell both full pairs")
	TEST_ASSERT_EQUAL(suits.demand, suit_demand_before - 2, "Suit resale did not consume real demand")
	TEST_ASSERT_EQUAL(helmets.demand, helmet_demand_before - 2, "Helmet resale did not consume real demand")
	TEST_ASSERT_EQUAL(account.account_balance, 960, "Wick's actual buyback paid more than100 for two suit/helmet pairs")
	manifest = delivery.manifest?.resolve()
	manifest.stamp_cache = list("stamp-ok")
	TEST_ASSERT(console.sell(), "The real ship export refused the remaining packaging")
	TEST_ASSERT_EQUAL(account.account_balance, 988, "Spacewear resale plus stamped packaging must return128 against140 paid")
	TEST_ASSERT(account.account_balance < 1000, "The complete cargo-to-Wick-to-cargo route generated credits")

/// Raw, refined, captured and aged plasma exports all obey the same fuel bid.
/datum/unit_test/voidcrew_launch_cargo_fixture/plasma_exports/Run()
	save_economy()
	SSstock_market.materials_prices[/datum/material/plasma] = 60
	var/obj/item/stack/sheet/mineral/plasma/sheets = allocate(/obj/item/stack/sheet/mineral/plasma, run_loc_floor_bottom_left, 20)
	var/obj/item/stack/ore/plasma/ore = allocate(/obj/item/stack/ore/plasma, run_loc_floor_bottom_left, 15)
	var/datum/export_report/sheet_report = export_item_and_contents(sheets, apply_elastic = FALSE, dry_run = TRUE)
	var/datum/export_report/ore_report = export_item_and_contents(ore, apply_elastic = FALSE, dry_run = TRUE)
	TEST_ASSERT_EQUAL(counterlist_sum(sheet_report.total_value), 200, "Direct plasma sheets bypassed the ten-credit bid ceiling")
	TEST_ASSERT_EQUAL(counterlist_sum(ore_report.total_value), 120, "Raw plasma export lost its .8 whole-stack yield")

	var/obj/machinery/materials_market/market = allocate(/obj/machinery/materials_market)
	market.machine_stat &= ~NOPOWER
	var/mob/living/carbon/human/user = allocate(/mob/living/carbon/human/consistent)
	market.attackby(sheets, user)
	var/obj/item/stock_block/block = locate() in get_turf(market)
	TEST_ASSERT_NOTNULL(block, "Real plasma sheet conversion produced no stock block")
	TEST_ASSERT_EQUAL(block.quantity, 20, "Stock block changed refined quantity")
	TEST_ASSERT_EQUAL(block.export_value, 200, "New block captured the former inflated quote")
	var/datum/export_report/block_report = export_item_and_contents(block, apply_elastic = FALSE, dry_run = TRUE)
	TEST_ASSERT_EQUAL(counterlist_sum(block_report.total_value), 200, "Fixed plasma block bypassed the common bid")
	block.export_value = 1600 // A pre-change, stale or otherwise overvalued fixed quote.
	block_report = export_item_and_contents(block, apply_elastic = FALSE, dry_run = TRUE)
	TEST_ASSERT_EQUAL(counterlist_sum(block_report.total_value), 200, "Old fixed quote bypassed the bid ceiling")
	block.export_value = 100
	block_report = export_item_and_contents(block, apply_elastic = FALSE, dry_run = TRUE)
	TEST_ASSERT_EQUAL(counterlist_sum(block_report.total_value), 100, "Fixed block failed to preserve a lower captured price")
	block.update_value() // Advance this three-minute callback, not the economy clock.
	TEST_ASSERT(block.fluid, "Stock block never entered fluid pricing")
	TEST_ASSERT_EQUAL(block.export_value, 200, "Aged plasma block displays a price above the common bid")
	block_report = export_item_and_contents(block, apply_elastic = FALSE, dry_run = TRUE)
	TEST_ASSERT_EQUAL(counterlist_sum(block_report.total_value), 200, "Fluid plasma block used the sixty-credit market ask")
	SSstock_market.materials_prices[/datum/material/plasma] = 7
	sheet_report = export_item_and_contents(ore, apply_elastic = FALSE, dry_run = TRUE)
	block_report = export_item_and_contents(block, apply_elastic = FALSE, dry_run = TRUE)
	TEST_ASSERT_EQUAL(counterlist_sum(sheet_report.total_value), 84, "Raw plasma failed to follow a live bid below the cap")
	TEST_ASSERT_EQUAL(counterlist_sum(block_report.total_value), 140, "Fluid block failed to follow a live bid below the cap")

/// A real cheap pack, crate and approved manifest must not refund its whole bill.
/datum/unit_test/voidcrew_launch_cargo_fixture/packaging/Run()
	save_economy()
	var/datum/supply_pack/pack = allocate(/datum/supply_pack/security/modsuit_plating)
	var/datum/supply_order/order = allocate(/datum/supply_order, pack)
	order.manifest_can_fail = FALSE
	var/obj/structure/closet/crate/crate = order.generate(run_loc_floor_bottom_left)
	var/obj/item/paper/fluff/jobs/cargo/manifest/manifest = crate.manifest.resolve()
	manifest.stamp_cache = list("stamp-ok")
	var/datum/export_report/pack_report = export_item_and_contents(crate, apply_elastic = FALSE, dry_run = FALSE)
	var/returned = counterlist_sum(pack_report.total_value)
	TEST_ASSERT_EQUAL(returned, 70, "Crate and approved manifest should return fifty plus twenty credits")
	TEST_ASSERT(returned < round(pack.cost * 0.8 * 0.5), "Packaging refunded more than even the strongest supported pack/coupon combination")
	var/obj/structure/closet/crate/wooden/salvage = allocate(/obj/structure/closet/crate/wooden)
	var/datum/export_report/salvage_report = export_single_item(salvage, apply_elastic = FALSE, dry_run = TRUE)
	TEST_ASSERT_EQUAL(counterlist_sum(salvage_report.total_value), 96, "Existing unmarked wooden salvage lost its distinct return")
	var/obj/item/stack/sheet/plasteel/plasteel = allocate(/obj/item/stack/sheet/plasteel, run_loc_floor_bottom_left, 20)
	var/datum/export_report/steel_report = export_item_and_contents(plasteel, apply_elastic = FALSE, dry_run = TRUE)
	TEST_ASSERT_EQUAL(counterlist_sum(steel_report.total_value), 400, "Plasteel direct resale retained its former inflated material price")
	TEST_ASSERT(counterlist_sum(steel_report.total_value) < 630, "Repair-stock resale exceeds Barnaby's strongest special")
