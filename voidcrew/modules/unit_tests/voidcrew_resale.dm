// Fork defines compile after tests; trait names and expected prices are literals here.
/datum/unit_test/voidcrew_resale
	parent_type = /datum/unit_test/voidcrew_launch_cargo_fixture
	abstract_type = /datum/unit_test/voidcrew_resale

/datum/unit_test/voidcrew_resale/proc/seller()
	var/mob/living/carbon/human/user = allocate(/mob/living/carbon/human/consistent, run_loc_floor_bottom_left)
	var/obj/item/card/id/id = allocate(/obj/item/card/id)
	id.registered_account = allocate(/datum/bank_account, "Resale test", null, 1, FALSE)
	user.put_in_active_hand(id)
	return user

/datum/unit_test/voidcrew_resale/soap/Run()
	save_economy()
	var/mob/living/carbon/human/user = seller()
	var/datum/shop_sku/general/soap/sku = allocate(/datum/shop_sku/general/soap)
	var/obj/item/soap/bought = sku.dispense(user, null)
	TEST_ASSERT(is_trader_good(bought), "Shop soap was not stamped")
	var/datum/export_report/report = export_item_and_contents(bought, apply_elastic = FALSE, dry_run = TRUE)
	TEST_ASSERT_EQUAL(counterlist_sum(report.total_value), 0, "Bought soap paid cargo")
	var/datum/shop_buyback/ledger = allocate(/datum/shop_buyback)
	ledger.item_path = /obj/item/soap
	ledger.pay_credits = 10
	ledger.demand = 2
	TEST_ASSERT(!ledger.matches(bought), "A buyback accepted bought soap")
	TEST_ASSERT(!ledger.try_sell(user, null), "The sale path consumed bought soap")
	TEST_ASSERT(!QDELETED(bought), "Refused goods were consumed")
	TEST_ASSERT_EQUAL(ledger.get_denial_reason(user), "I don't buy back shop stock.", "Bought goods lack their refusal")
	var/obj/item/soap/salvaged = allocate(/obj/item/soap, user)
	report = export_item_and_contents(salvaged, apply_elastic = FALSE, dry_run = TRUE)
	TEST_ASSERT(counterlist_sum(report.total_value) > 0, "An unbought copy no longer exports")
	var/datum/bank_account/account = get_shop_buyback_account(user)
	var/balance = account.account_balance
	TEST_ASSERT(ledger.try_sell(user, null), "An unbought copy no longer sells at a buyback")
	TEST_ASSERT_EQUAL(account.account_balance, balance + 10, "Buyback did not pay for the unbought copy")

/obj/structure/closet/crate/resale_test/PopulateContents()
	var/obj/item/storage/box/nested = new(src)
	new /obj/item/soap(nested)

/datum/unit_test/voidcrew_resale/bundles/Run()
	save_economy()
	var/mob/living/carbon/human/user = seller()
	var/datum/shop_sku/sku = allocate(/datum/shop_sku)
	sku.item_path = /obj/structure/closet/crate/resale_test
	var/obj/structure/closet/crate/crate = sku.dispense(user, null)
	TEST_ASSERT(crate.contents_initialized, "A bought crate left lazy stock unstamped")
	var/obj/item/storage/box/nested = locate() in crate
	var/obj/item/soap/soap = locate() in nested
	TEST_ASSERT(is_trader_good(crate) && is_trader_good(nested) && is_trader_good(soap), "Nested delivery contents lost provenance")
	var/obj/item/soap/later_addition = allocate(/obj/item/soap, nested)
	TEST_ASSERT(!is_trader_good(later_addition), "A bought box contaminated later additions")
	var/datum/shop_sku/dregs/party_keg/keg_sku = allocate(/datum/shop_sku/dregs/party_keg)
	var/atom/movable/keg = keg_sku.dispense(user, null)
	var/datum/export_report/report = export_item_and_contents(keg, apply_elastic = FALSE, dry_run = TRUE)
	TEST_ASSERT(is_trader_good(keg), "The keg structure was not stamped")
	TEST_ASSERT_EQUAL(counterlist_sum(report.total_value), 0, "Bought beer keg or its reagents paid cargo")
	var/datum/market_item/entry = allocate(/datum/market_item)
	var/obj/item/market_uplink/uplink = allocate(/obj/item/market_uplink)
	var/datum/market_purchase/purchase = allocate(/datum/market_purchase, entry, uplink, "resale test", TRUE)
	var/obj/item/storage/fish_case/blackmarket/fish_case = allocate(/obj/item/storage/fish_case/blackmarket)
	purchase.post_purchase_effects(fish_case)
	var/obj/item/fish/fish = locate() in fish_case
	TEST_ASSERT_NOTNULL(fish, "The ominous fish case contained no fish")
	TEST_ASSERT(is_trader_good(fish_case) && is_trader_good(fish), "Black market bundle contents were not stamped")
	var/datum/shop_buyback/fish_ledger = allocate(/datum/shop_buyback)
	fish_ledger.item_path = /obj/item/fish
	TEST_ASSERT(!fish_ledger.matches(fish), "A black market fish could be fenced")
	var/datum/supply_pack/custom/golem_pack = allocate(/datum/supply_pack/custom, "Golem", 0, list(/obj/item/slime_extract/grey = 1))
	var/datum/supply_order/disposable/golem_order = allocate(/datum/supply_order/disposable, golem_pack)
	golem_order.manifest_can_fail = FALSE
	var/obj/structure/closet/crate/golem_crate = golem_order.generate(run_loc_floor_bottom_left)
	var/obj/item/slime_extract/grey/extract = locate() in golem_crate
	TEST_ASSERT(is_trader_good(extract), "Cargo-delivered golem orders were not stamped")
	var/obj/item/paper/fluff/jobs/cargo/manifest/manifest = locate() in golem_crate
	TEST_ASSERT(is_trader_good(manifest), "An order-console manifest escaped the stamp")
	var/datum/shop_buyback/skunk/slime_extract/skunk = allocate(/datum/shop_buyback/skunk/slime_extract)
	TEST_ASSERT(!skunk.matches(extract), "Skunkworks bought an ordered extract")
	var/datum/supply_pack/bitrunning/bit_pack = allocate(/datum/supply_pack/bitrunning, "Bitrunner", 0, list(/obj/item/soap = 1))
	var/obj/structure/closet/crate/bit_crate = bit_pack.generate(run_loc_floor_bottom_left)
	var/obj/item/soap/bit_soap = locate() in bit_crate
	TEST_ASSERT(is_trader_good(bit_soap), "The bitrunning cargo fallback delivered unstamped goods")

/datum/unit_test/voidcrew_resale/catalog_food/Run()
	save_economy()
	var/mob/living/carbon/human/user = seller()
	for(var/sku_type in list(
		/datum/shop_sku/diner/fries,
		/datum/shop_sku/diner/hotdog,
		/datum/shop_sku/diner/muffin,
		/datum/shop_sku/diner/plated/house_burger,
		/datum/shop_sku/diner/plated/omelette,
		/datum/shop_sku/diner/plated/egg_fried_rice,
		/datum/shop_sku/diner/plated/fish_and_chips,
		/datum/shop_sku/diner/eggs,
		/datum/shop_sku/diner/plated/rotating/gumbo,
		/datum/shop_sku/diner/plated/rotating/risotto,
		/datum/shop_sku/dregs/fry_basket,
		/datum/shop_sku/dregs/monkey_kebab,
		/datum/shop_sku/dregs/meat_pie,
	))
		var/datum/shop_sku/sku = allocate(sku_type)
		var/atom/movable/goods = sku.dispense(user, null)
		var/datum/export_report/report = export_item_and_contents(goods, apply_elastic = FALSE, dry_run = TRUE)
		TEST_ASSERT_EQUAL(counterlist_sum(report.total_value), 0, "[sku_type] retained its direct food-export loop")

/datum/unit_test/voidcrew_resale/stacks/Run()
	var/obj/item/stack/sheet/iron/bought = create_trader_goods(/obj/item/stack/sheet/iron, run_loc_floor_bottom_left, 10)
	var/obj/item/stack/sheet/iron/split = bought.split_stack(3)
	TEST_ASSERT(is_trader_good(split), "Splitting laundered bought sheets")
	var/obj/item/stack/sheet/iron/salvaged = allocate(/obj/item/stack/sheet/iron, null, 2, FALSE)
	TEST_ASSERT_EQUAL(split.merge_without_del(salvaged), 3, "The stacks did not merge")
	TEST_ASSERT(is_trader_good(salvaged), "Merging bought sheets into salvage laundered them")
	var/obj/item/stack/sheet/iron/other = allocate(/obj/item/stack/sheet/iron, null, 2, FALSE)
	TEST_ASSERT_EQUAL(other.merge_without_del(bought), 2, "The reverse merge failed")
	TEST_ASSERT(is_trader_good(bought), "Merging salvage into bought sheets cleared the mark")
	qdel(split)
	var/obj/item/storage/box/bundle = allocate(/obj/item/storage/box)
	create_trader_goods(/obj/item/stack/sheet/iron, bundle, 125)
	var/total = 0
	for(var/obj/item/stack/sheet/iron/stack in bundle)
		total += stack.amount
		TEST_ASSERT(is_trader_good(stack), "An overflow stack escaped the delivery stamp")
	TEST_ASSERT_EQUAL(total, 125, "An oversized delivery lost sheets")

/datum/unit_test/voidcrew_resale/contract_rewards/Run()
	var/obj/structure/overmap/ship/ship = allocate(/obj/structure/overmap/ship)
	var/datum/mission/m1_board_test/mission = allocate(/datum/mission/m1_board_test)
	mission.servant = ship
	mission.value = 0
	mission.voucher_count = 0
	mission.mission_reward = null
	mission.mission_rewards = list(/obj/item/soap, /obj/item/stack/sheet/iron)
	mission.reward_amounts = list(/obj/item/stack/sheet/iron = 75)
	mission.distribute_rewards(run_loc_floor_bottom_left)
	var/obj/item/soap/soap = locate() in run_loc_floor_bottom_left
	TEST_ASSERT(is_trader_good(soap), "Contract reward goods were not stamped")
	var/total = 0
	for(var/obj/item/stack/sheet/iron/stack in run_loc_floor_bottom_left)
		total += stack.amount
		TEST_ASSERT(is_trader_good(stack), "A contract reward stack was not stamped")
	TEST_ASSERT_EQUAL(total, 75, "The contract lost its bundled stack count")

/datum/unit_test/voidcrew_resale/cooking/Run()
	save_economy()
	var/mob/living/carbon/human/user = seller()
	user.mind_initialize()
	var/datum/shop_sku/sku = allocate(/datum/shop_sku)
	sku.item_path = /obj/item/food/piedough
	var/obj/item/food/piedough/dough = sku.dispense(user, null)
	TEST_ASSERT(is_trader_good(dough), "The bought ingredient was not stamped")
	var/obj/item/plate/oven_tray/tray = allocate(/obj/item/plate/oven_tray, run_loc_floor_bottom_left)
	dough.forceMove(tray)
	var/datum/component/bakeable/baking = dough.GetComponent(/datum/component/bakeable)
	TEST_ASSERT_NOTNULL(baking, "Dough lost its baking recipe")
	baking.on_baking_start(dough, tray, user)
	baking.finish_baking(tray)
	var/obj/item/food/pie/plain/bread = locate() in tray
	TEST_ASSERT_NOTNULL(bread, "The bought ingredient did not cook")
	TEST_ASSERT(!is_trader_good(bread), "Cooking copied the ingredient's resale mark")
	var/datum/export_report/report = export_item_and_contents(bread, apply_elastic = FALSE, dry_run = TRUE)
	TEST_ASSERT(counterlist_sum(report.total_value) > 0, "Cooked food from a bought ingredient no longer exports")
	bread.forceMove(user)
	var/datum/shop_buyback/diner/home_cooking/ledger = allocate(/datum/shop_buyback/diner/home_cooking)
	TEST_ASSERT(ledger.try_sell(user, null), "A cooked product was refused at the diner")

/datum/unit_test/voidcrew_resale/clinic/Run()
	var/mob/living/carbon/human/user = seller()
	var/datum/shop_buyback/clinic/heart/ledger = allocate(/datum/shop_buyback/clinic/heart)
	var/obj/item/organ/heart/cybernetic/cyber = allocate(/obj/item/organ/heart/cybernetic, user)
	TEST_ASSERT(!ledger.matches(cyber), "Sawbones accepted a cybernetic heart")
	TEST_ASSERT(!ledger.try_sell(user, null), "Sawbones bought a cybernetic heart")
	var/obj/item/organ/heart/natural = allocate(/obj/item/organ/heart)
	user.put_in_hands(natural)
	var/datum/bank_account/account = get_shop_buyback_account(user)
	var/balance = account.account_balance
	TEST_ASSERT(ledger.try_sell(user, null), "Sawbones refused a natural heart")
	TEST_ASSERT_EQUAL(account.account_balance, balance + 150, "Natural-heart intake price changed")
	var/obj/machinery/limbgrower/printer = allocate(/obj/machinery/limbgrower, run_loc_floor_bottom_left)
	printer.being_built = allocate(/datum/design/heart)
	printer.build_item(list())
	var/obj/item/organ/heart/printed = locate() in run_loc_floor_bottom_left
	TEST_ASSERT_NOTNULL(printed, "The limbgrower did not print a heart")
	TEST_ASSERT(HAS_TRAIT(printed, "printed_organ"), "Printed natural-type organs lost their provenance")
	TEST_ASSERT(!ledger.matches(printed), "Sawbones accepted a printed organic heart")
	var/datum/outpost_shop/vendor/patchup_clinic/clinic = allocate(/datum/outpost_shop/vendor/patchup_clinic)
	for(var/datum/shop_buyback/intake as anything in clinic.buybacks)
		TEST_ASSERT(!ispath(intake.item_path, /obj/item/defibrillator), "The clinic still buys defibrillators")
	TEST_ASSERT_EQUAL(length(clinic.buybacks), 4, "The clinic lost another intake line")

/datum/unit_test/voidcrew_resale/market_floor/Run()
	save_economy()
	var/list/expected_floors = list(
		/datum/material/diamond = 230,
		/datum/material/bluespace = 160,
		/datum/material/gold = 80,
		/datum/material/titanium = 80,
		/datum/material/uranium = 60,
		/datum/material/silver = 30,
		/datum/material/plasma = 15,
		/datum/material/iron = 5,
		/datum/material/glass = 5,
	)
	SSeconomy.pack_price_modifier = 0.1
	for(var/datum/material/material as anything in expected_floors)
		var/floor_price = expected_floors[material]
		SSstock_market.materials_prices[material] = 1
		TEST_ASSERT_EQUAL(material_market_buy_price(material), floor_price, "[material] has the wrong crashed-price ask")
		var/list/contents = list()
		contents[initial(material.sheet_type)] = 3
		var/datum/supply_pack/custom/minerals/pack = allocate(/datum/supply_pack/custom/minerals, "Floor test", 3, contents)
		var/datum/supply_order/disposable/materials/order = allocate(/datum/supply_order/disposable/materials, pack)
		order.paying_account = allocate(/datum/bank_account, "Floor test", null, 1, FALSE)
		order.applied_coupon = allocate(/obj/item/coupon)
		order.applied_coupon.discount_pct_off = 1
		TEST_ASSERT_EQUAL(order.get_final_cost(), floor_price * 3 + CARGO_CRATE_VALUE, "[material] fell below its floor after modifiers")
		SSstock_market.materials_prices[material] = floor_price + 10
		order.append_order(contents, 0)
		TEST_ASSERT_EQUAL(order.get_final_cost(), floor_price * 3 + (floor_price + 10) * 3 + CARGO_CRATE_VALUE, "Appending a material order lost its live ask or earlier quote")
		TEST_ASSERT_EQUAL(SSstock_market.materials_prices[material], floor_price + 10, "A buy floor changed the sale bid")
