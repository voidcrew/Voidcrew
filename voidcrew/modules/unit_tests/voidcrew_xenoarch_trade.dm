// Xenoarchaeology tests: trade.
//
// Test files compile before voidcrew/_DEFINES, so the values below are literals. They mirror
// voidcrew/_DEFINES/xenoarch.dm and the part-local defines in xenoarch/trade/:
//   bands (ZONE_*): green 1, yellow 2, red 3
//   tiers: common 1, uncommon 2, rare 3, extreme 4
//   COMSIG_ARTIFACT_SOLD "artifact_sold"
//   XENOARCH_FIND_DEMAND 3, XENOARCH_CURIO_DEMAND 6
//   buyer line keys "perfect", "close", "wrong", "blank", "live"
//   checkpoint refusal for a loose find "xenoarch_loose_find"

/// Shared helpers for the trade tests; runs nothing itself.
/datum/unit_test/voidcrew_xenoarch_trade
	abstract_type = /datum/unit_test/voidcrew_xenoarch_trade

/// A seller with a bank card in hand, the way the outpost ledger finds an account without a crew.
/datum/unit_test/voidcrew_xenoarch_trade/proc/make_seller(datum/bank_account/account)
	var/mob/living/carbon/human/consistent/seller = allocate(/mob/living/carbon/human/consistent)
	var/obj/item/card/id/advanced/card = allocate(/obj/item/card/id/advanced)
	qdel(card.registered_account)
	card.registered_account = account
	seller.put_in_hands(card)
	return seller

/// Deletes the receipts and vouchers a sale left in hand or underfoot.
/datum/unit_test/voidcrew_xenoarch_trade/proc/tidy(mob/living/seller)
	for(var/obj/item/paper/xenoarch_receipt/receipt in near_seller(seller))
		qdel(receipt)
	for(var/obj/item/stack/trade_voucher/chits in near_seller(seller))
		qdel(chits)

/// Everything the seller holds, plus everything at their feet.
/datum/unit_test/voidcrew_xenoarch_trade/proc/near_seller(mob/living/seller)
	var/turf/feet = get_turf(seller)
	return seller.get_all_contents() + feet.contents

/// Barnaby, Boffin and Vex buy finds; Vex takes no curios; nobody else buys either.
/datum/unit_test/voidcrew_xenoarch_trade/buyers/Run()
	var/list/expected = list(
		/datum/outpost_shop/general = list(TRUE, TRUE),
		/datum/outpost_shop/vendor/skunkworks = list(TRUE, TRUE),
		/datum/outpost_shop/black_market = list(TRUE, FALSE),
		/datum/outpost_shop/outfitter = list(FALSE, FALSE),
		/datum/outpost_shop/vendor/dregs_bar = list(FALSE, FALSE),
	)
	for(var/shop_type in expected)
		var/datum/outpost_shop/shop = allocate(shop_type)
		var/list/wants = expected[shop_type]
		var/datum/shop_buyback/xenoarch_find/find_row = locate() in shop.buybacks
		var/datum/shop_buyback/xenoarch_curio/curio_row = locate() in shop.buybacks
		TEST_ASSERT_EQUAL(!!find_row, wants[1], "[shop_type] large-find row")
		TEST_ASSERT_EQUAL(!!curio_row, wants[2], "[shop_type] curio row")
		if(find_row)
			TEST_ASSERT(find_row.buyer == shop.xenoarch_buyer, "[shop_type]'s find row has no buyer")
			TEST_ASSERT_EQUAL(find_row.demand, 3, "[shop_type] wants the wrong number of large finds")
			TEST_ASSERT_NULL(find_row.item_path, "[shop_type]'s find row has an item path, so Pike's ledger would sell finds remotely")
			TEST_ASSERT(find_row.get_ui_icon(), "[shop_type]'s find row has no picture")
		if(curio_row)
			TEST_ASSERT_EQUAL(curio_row.demand, 6, "[shop_type] wants the wrong number of curios")
			TEST_ASSERT(curio_row.get_ui_icon(), "[shop_type]'s curio row has no picture")
		// A convoy tops the rows up like any other ledger row
		if(find_row)
			find_row.demand = 0
			shop.convoy_restock()
			TEST_ASSERT(find_row.demand > 0, "[shop_type]'s find demand never comes back")
	// Sarge buys nothing but points the way
	var/datum/outpost_shop/outfitter/depot = allocate(/datum/outpost_shop/outfitter)
	TEST_ASSERT_NOTNULL(depot.xenoarch_buyer, "Sarge has nothing to say about a find")
	TEST_ASSERT(depot.xenoarch_buyer.line("notice"), "Sarge has nothing to say about a find")
	TEST_ASSERT_EQUAL(xenoarch_credits_text(1125), "1,125 cr", "credit formatting")
	TEST_ASSERT_EQUAL(xenoarch_credits_text(250), "250 cr", "credit formatting")
	TEST_ASSERT_EQUAL(xenoarch_credits_text(1000000), "1,000,000 cr", "credit formatting")

/// A sale pays the sale value once, takes the find, prints a receipt and tells the artifact.
/datum/unit_test/voidcrew_xenoarch_trade/sale
	/// Arguments of the last COMSIG_ARTIFACT_SOLD seen
	var/list/sold_args

/datum/unit_test/voidcrew_xenoarch_trade/sale/proc/on_sold(datum/source, credits, vouchers, mob/seller)
	SIGNAL_HANDLER
	sold_args = list(credits, vouchers, seller)

/datum/unit_test/voidcrew_xenoarch_trade/sale/Run()
	var/datum/outpost_shop/general/shop = allocate(/datum/outpost_shop/general)
	var/datum/shop_buyback/xenoarch_find/row = locate() in shop.buybacks
	var/datum/bank_account/account = allocate(/datum/bank_account, "Xenoarch sale test", null, 1, FALSE)
	var/mob/living/carbon/human/seller = make_seller(account)

	// Never dug: refused, nothing moves
	var/obj/machinery/artifact/stray = allocate(/obj/machinery/artifact, get_step(seller, EAST))
	stray.replace_effects(/datum/artifact_effect/heal, null, 2)
	TEST_ASSERT_EQUAL(row.settle(stray, seller, account, null), 0, "an undug find sold")
	TEST_ASSERT(!QDELETED(stray), "an undug find was taken without pay")
	TEST_ASSERT_EQUAL(account.account_balance, 0, "an undug find paid out")
	TEST_ASSERT_EQUAL(row.demand, 3, "a refused sale used up demand")
	qdel(stray)

	// Dug in yellow, labelled right: full price
	var/obj/machinery/artifact/find = allocate(/obj/machinery/artifact, get_step(seller, EAST), 2)
	find.replace_effects(/datum/artifact_effect/heal, null, 2)
	find.apply_label(new /datum/artifact_label("Heals", artifact_trigger_name(find.main_effect.trigger), "None"))
	var/expected = artifact_sale_value(find)
	TEST_ASSERT_EQUAL(expected, 675, "a perfectly labelled yellow uncommon find is not worth 675")
	TEST_ASSERT(shop.xenoarch_buyer.closing_line(find) in shop.xenoarch_buyer.lines["perfect"], "Barnaby didn't praise a perfect label")
	var/serial = find.serial
	RegisterSignal(find, "artifact_sold", PROC_REF(on_sold))
	TEST_ASSERT_EQUAL(row.settle(find, seller, account, null), expected, "the sale paid the wrong amount")
	TEST_ASSERT_EQUAL(account.account_balance, expected, "the account got the wrong amount")
	TEST_ASSERT(QDELETED(find), "the sold find stayed in the world")
	TEST_ASSERT_EQUAL(row.demand, 2, "a sale did not use up demand")
	TEST_ASSERT_NOTNULL(sold_args, "COMSIG_ARTIFACT_SOLD was not sent")
	TEST_ASSERT_EQUAL(sold_args[1], expected, "COMSIG_ARTIFACT_SOLD carried the wrong credits")
	TEST_ASSERT_EQUAL(sold_args[2], 0, "Barnaby paid a voucher")
	TEST_ASSERT_EQUAL(sold_args[3], seller, "COMSIG_ARTIFACT_SOLD named the wrong seller")
	var/obj/item/paper/xenoarch_receipt/receipt = locate() in near_seller(seller)
	TEST_ASSERT_NOTNULL(receipt, "no receipt was handed over")
	TEST_ASSERT(findtext(receipt.name, serial), "the receipt doesn't name the find")
	TEST_ASSERT(!(locate(/obj/item/stack/trade_voucher) in near_seller(seller)), "Barnaby handed over a voucher")
	tidy(seller)

	// Selling it again is impossible: it is gone
	TEST_ASSERT_EQUAL(row.settle(find, seller, account, null), 0, "a sold find sold twice")
	TEST_ASSERT_EQUAL(account.account_balance, expected, "a second sale of one find paid")

	// Out of demand: refused
	var/obj/machinery/artifact/late = allocate(/obj/machinery/artifact, get_step(seller, EAST), 1)
	row.demand = 0
	TEST_ASSERT_EQUAL(row.settle(late, seller, account, null), 0, "a buyer with no demand left bought a find")
	TEST_ASSERT(!QDELETED(late), "a refused find was taken")

	// No account: refused
	row.demand = 3
	TEST_ASSERT_EQUAL(row.settle(late, seller, null, null), 0, "a find sold with nowhere to pay")
	TEST_ASSERT(!QDELETED(late), "a find was taken with nowhere to pay")

/// Vex pays one voucher on top for an extreme main effect, and only for that.
/datum/unit_test/voidcrew_xenoarch_trade/vex_voucher/Run()
	var/datum/outpost_shop/black_market/shop = allocate(/datum/outpost_shop/black_market)
	var/datum/shop_buyback/xenoarch_find/row = locate() in shop.buybacks
	var/datum/bank_account/account = allocate(/datum/bank_account, "Xenoarch voucher test", null, 1, FALSE)
	var/mob/living/carbon/human/seller = make_seller(account)

	var/obj/machinery/artifact/plain = allocate(/obj/machinery/artifact, get_step(seller, EAST), 3)
	plain.replace_effects(/datum/artifact_effect/heal, null, 3)
	TEST_ASSERT_EQUAL(shop.xenoarch_buyer.vouchers_for(plain), 0, "Vex pays a voucher for an uncommon find")
	TEST_ASSERT(row.settle(plain, seller, account, null) > 0, "Vex refused a dug red find")
	TEST_ASSERT(!(locate(/obj/item/stack/trade_voucher) in near_seller(seller)), "Vex handed over a voucher for an uncommon find")
	tidy(seller)

	var/obj/machinery/artifact/live = allocate(/obj/machinery/artifact, get_step(seller, EAST), 3)
	live.replace_effects(/datum/artifact_effect/tesla, null, 3)
	TEST_ASSERT_EQUAL(live.main_effect.tier, 4, "the tesla effect is no longer extreme; pick another extreme effect for this test")
	TEST_ASSERT(shop.xenoarch_buyer.closing_line(live) in shop.xenoarch_buyer.lines["live"], "Vex didn't remark on an extreme find")
	var/before = account.account_balance
	var/expected = artifact_sale_value(live)
	TEST_ASSERT_EQUAL(expected, 560, "an unlabelled red extreme find is not worth 560")
	TEST_ASSERT_EQUAL(row.settle(live, seller, account, null), expected, "Vex paid the wrong credits for an extreme find")
	TEST_ASSERT_EQUAL(account.account_balance - before, expected, "the account got the wrong amount")
	var/vouchers = 0
	for(var/obj/item/stack/trade_voucher/chits in near_seller(seller))
		vouchers += chits.amount
	TEST_ASSERT_EQUAL(vouchers, 1, "Vex didn't pay exactly one voucher for an extreme find")
	tidy(seller)

	// The others pay credits only, extreme or not
	var/datum/outpost_shop/general/halcyon = allocate(/datum/outpost_shop/general)
	var/obj/machinery/artifact/other = allocate(/obj/machinery/artifact, get_step(seller, EAST), 3)
	other.replace_effects(/datum/artifact_effect/tesla, null, 3)
	TEST_ASSERT_EQUAL(halcyon.xenoarch_buyer.vouchers_for(other), 0, "Barnaby pays vouchers")

/// Only a find the seller hauls counts: pulled loose, or in a shut crate they pull.
/datum/unit_test/voidcrew_xenoarch_trade/hauling/Run()
	var/datum/outpost_shop/vendor/skunkworks/shop = allocate(/datum/outpost_shop/vendor/skunkworks)
	var/datum/shop_buyback/xenoarch_find/row = locate() in shop.buybacks
	var/datum/bank_account/account = allocate(/datum/bank_account, "Xenoarch hauling test", null, 1, FALSE)
	var/mob/living/carbon/human/seller = make_seller(account)
	var/turf/beside = get_step(seller, EAST)

	var/obj/machinery/artifact/find = allocate(/obj/machinery/artifact, beside, 2)
	TEST_ASSERT_EQUAL(length(row.sellable_finds(seller)), 0, "a find nobody pulls counted as hauled")
	TEST_ASSERT_EQUAL(row.count_carried_units(seller), 0, "a find nobody pulls showed on the ledger")
	seller.start_pulling(find)
	TEST_ASSERT(seller.pulling == find, "the seller could not pull the find")
	TEST_ASSERT_EQUAL(length(row.sellable_finds(seller)), 1, "a pulled find did not count")
	seller.stop_pulling()

	var/obj/structure/closet/crate/specimen/crate = allocate(/obj/structure/closet/crate/specimen, beside)
	if(crate.opened)
		crate.close()
	find.forceMove(crate)
	TEST_ASSERT(find.loc == crate, "the find would not go in the crate")
	TEST_ASSERT(findtext(jointext(crate.examine(seller), " "), find.serial), "the crate lid doesn't show the find's tag")
	seller.start_pulling(crate)
	TEST_ASSERT_EQUAL(length(row.sellable_finds(seller)), 1, "a find in a pulled crate did not count")
	TEST_ASSERT_EQUAL(xenoarch_find_holder(find), crate, "a crated find's holder is not its crate")
	crate.open()
	TEST_ASSERT_EQUAL(length(row.sellable_finds(seller)), 0, "an open crate still counted as holding the find")
	seller.stop_pulling()

	// A plain crate works too
	var/obj/structure/closet/crate/plain = allocate(/obj/structure/closet/crate, beside)
	if(plain.opened)
		plain.close()
	find.forceMove(plain)
	seller.start_pulling(plain)
	TEST_ASSERT_EQUAL(length(row.sellable_finds(seller)), 1, "a find in a pulled plain crate did not count")
	seller.stop_pulling()

	// An undug find shows as hauled but never sellable
	var/obj/machinery/artifact/stray = allocate(/obj/machinery/artifact, get_step(seller, NORTH))
	seller.start_pulling(stray)
	TEST_ASSERT_EQUAL(length(xenoarch_hauled_finds(seller)), 1, "an undug pulled find wasn't hauled")
	TEST_ASSERT_EQUAL(length(row.sellable_finds(seller)), 0, "an undug find was sellable")
	TEST_ASSERT_NOTNULL(row.get_denial_reason(seller), "an undug find could be sold")
	seller.stop_pulling()

	// The find row never matches an inventory item (plunder appraisal, Pike's ledger)
	var/obj/item/relic/relic = allocate(/obj/item/relic)
	TEST_ASSERT(!row.matches(relic), "the large-find row matched an item")

/// Curios sell only with the dug mark, at their own price; only Boffin takes strange objects.
/datum/unit_test/voidcrew_xenoarch_trade/curios/Run()
	var/datum/outpost_shop/general/halcyon = allocate(/datum/outpost_shop/general)
	var/datum/outpost_shop/vendor/skunkworks/skunkworks = allocate(/datum/outpost_shop/vendor/skunkworks)
	var/datum/shop_buyback/xenoarch_curio/barnaby_row = locate() in halcyon.buybacks
	var/datum/shop_buyback/xenoarch_curio/boffin_row = locate() in skunkworks.buybacks

	var/obj/item/relic/maint_relic = allocate(/obj/item/relic)
	TEST_ASSERT(!boffin_row.matches(maint_relic), "an unmarked strange object passed as a find")
	var/obj/item/relic/dug_relic = allocate(/obj/item/relic)
	TEST_ASSERT(xenoarch_mark_curio(dug_relic, 200), "could not mark a strange object as dug")
	TEST_ASSERT(boffin_row.matches(dug_relic), "Boffin refused a dug strange object")
	TEST_ASSERT(!barnaby_row.matches(dug_relic), "Barnaby took a strange object")
	TEST_ASSERT(!xenoarch_mark_curio(maint_relic, 0), "a curio was marked as worth nothing")

	var/datum/bank_account/account = allocate(/datum/bank_account, "Xenoarch curio test", null, 1, FALSE)
	var/mob/living/carbon/human/seller = make_seller(account)
	var/obj/item/statuebust/shard = allocate(/obj/item/statuebust)
	xenoarch_mark_curio(shard, 50)
	seller.put_in_hands(shard)
	TEST_ASSERT_EQUAL(barnaby_row.count_carried_units(seller), 1, "a carried curio didn't count")
	TEST_ASSERT_NULL(barnaby_row.get_denial_reason(seller), "a carried curio was refused")
	TEST_ASSERT(barnaby_row.try_sell(seller, null), "a curio didn't sell")
	TEST_ASSERT_EQUAL(account.account_balance, 50, "a curio paid the wrong amount")
	TEST_ASSERT(QDELETED(shard), "a sold curio stayed in hand")
	TEST_ASSERT_EQUAL(barnaby_row.demand, 5, "a curio sale did not use up demand")
	TEST_ASSERT(!barnaby_row.try_sell(seller, null), "a curio sold that wasn't there")

/// The checkpoint turns back a loose find, lets a crated one through, and never stops one leaving.
/datum/unit_test/voidcrew_xenoarch_trade/checkpoint/Run()
	var/datum/outpost_checkpoint/checkpoint = allocate(/datum/outpost_checkpoint)
	var/turf/chamber = run_loc_floor_bottom_left
	checkpoint.chamber_turfs = list(chamber)
	TEST_ASSERT_EQUAL(length(checkpoint.inspect_chamber()), 0, "an empty chamber refused something")

	var/obj/machinery/artifact/find = allocate(/obj/machinery/artifact, chamber, 1)
	var/list/refused = checkpoint.inspect_chamber()
	TEST_ASSERT_EQUAL(refused[find], "xenoarch_loose_find", "a loose find walked through the checkpoint")
	TEST_ASSERT(checkpoint.refusing_only_loose_finds(), "a loose find read as something else")

	checkpoint.exit_request = TRUE
	var/list/leaving = checkpoint.inspect_chamber()
	TEST_ASSERT(!leaving[find], "a find was stopped on its way out")
	checkpoint.exit_request = FALSE

	var/obj/structure/closet/crate/specimen/crate = allocate(/obj/structure/closet/crate/specimen, chamber)
	if(crate.opened)
		crate.close()
	find.forceMove(crate)
	TEST_ASSERT_EQUAL(length(checkpoint.inspect_chamber()), 0, "a crated find was turned back")

	var/datum/outpost_shop/vendor/checkpoint/halcyon/desk = allocate(/datum/outpost_shop/vendor/checkpoint/halcyon)
	TEST_ASSERT(desk.get_line("xenoarch_loose_find") in desk.xenoarch_loose_lines, "Hollis has nothing to say about a loose find")
	TEST_ASSERT(desk.get_line("checkpoint_pass"), "Hollis lost his ordinary lines")
	var/obj/machinery/outpost_checkpoint_sensor/sensor = allocate(/obj/machinery/outpost_checkpoint_sensor)
	TEST_ASSERT(sensor.machine_line("xenoarch_loose_find"), "the wall scanner has nothing to say about a loose find")
