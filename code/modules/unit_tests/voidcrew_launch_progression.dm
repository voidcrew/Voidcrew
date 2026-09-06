// Fork defines are included after upstream unit tests. Economic expectations below
// intentionally use their fixed launch values rather than unavailable macros.
/// Replay a real survey completion and a forged repeat action. Survey rewards
/// must be once per ship record, including while a second callback is pending.
/datum/unit_test/voidcrew_survey_reward_once/Run()
	var/obj/machinery/computer/camera_advanced/shuttle_docker/survey/launch_test/console = allocate(/obj/machinery/computer/camera_advanced/shuttle_docker/survey/launch_test)
	var/obj/structure/overmap/star/star = allocate(/obj/structure/overmap/star)
	var/mob/living/carbon/human/user = allocate(/mob/living/carbon/human/consistent)
	console.data = new
	console.test_candidates = list(star)
	console.survey_research_tiers = list("basic")
	console.survey_celestial_object(user, ref(star))
	TEST_ASSERT(console.survey_in_progress, "A fresh in-range star must be surveyable")
	// Advance only this timer, not the world's economy or restock clocks.
	deltimer(console.survey_timer)
	console.complete_survey(star)
	var/first_cash = console.banked_cash
	var/first_points = console.banked_points
	TEST_ASSERT(first_cash > 0 && first_points > 0, "The first survey must pay cash and research")
	TEST_ASSERT(console.is_object_surveyed(star), "Completion must record the target")
	TEST_ASSERT(star.surveyed, "The first-surveyor premium must be consumed globally")
	console.complete_survey(star)
	TEST_ASSERT_EQUAL(console.banked_cash, first_cash, "A repeated completion must not pay cash again")
	TEST_ASSERT_EQUAL(console.banked_points, first_points, "A repeated completion must not pay research again")
	console.survey_celestial_object(user, ref(star))
	TEST_ASSERT(!console.survey_in_progress, "A forged survey action must not restart a completed target")
	var/obj/machinery/computer/camera_advanced/shuttle_docker/survey/launch_test/second = allocate(/obj/machinery/computer/camera_advanced/shuttle_docker/survey/launch_test)
	second.data = new
	second.test_candidates = list(star)
	second.survey_research_tiers = list("basic")
	second.survey_celestial_object(user, ref(star))
	deltimer(second.survey_timer)
	second.complete_survey(star)
	TEST_ASSERT_EQUAL(second.banked_cash, star.survey_value, "Another crew's first scan earns the ordinary reward")
	var/obj/structure/overmap/star/other_star = allocate(/obj/structure/overmap/star)
	second.test_candidates = list(other_star)
	second.survey_celestial_object(user, ref(other_star))
	second.complete_survey(star)
	TEST_ASSERT(second.survey_in_progress, "An old callback must not cancel a newer scan")
	deltimer(second.survey_timer)
	second.test_candidates.Cut()
	second.complete_survey(other_star)
	TEST_ASSERT_EQUAL(second.banked_cash, star.survey_value, "An out-of-range completion must not pay")
	TEST_ASSERT(!second.is_object_surveyed(other_star), "An out-of-range completion must not unlock research")
	second.test_candidates = list(other_star)
	second.update_survey_data()
	TEST_ASSERT(!second.is_object_surveyed(other_star), "Refresh must not bypass the first scan")
	second.survey_celestial_object(user, ref(other_star))
	deltimer(second.survey_timer)
	console.data.update_survey_data(other_star)
	console.transfer_survey_data(console.data, second.data)
	second.complete_survey(other_star)
	TEST_ASSERT_EQUAL(second.banked_cash, star.survey_value, "Importing a target during its scan must prevent duplicate payment")
	second.survey_celestial_object(user, ref(other_star))
	TEST_ASSERT(!second.survey_in_progress, "An imported record must not start another paid scan")
	console.transfer_survey_data(second.data, console.data)
	QDEL_NULL(second.data)
	// Clean up the timer even on the unfixed baseline.
	if(console.survey_timer)
		deltimer(console.survey_timer)
		console.survey_timer = null
	console.survey_in_progress = FALSE
	console.current_survey_target = null
	QDEL_NULL(console.data)

/// Only the location discovery is substituted: production survey/reward code runs.
/obj/machinery/computer/camera_advanced/shuttle_docker/survey/launch_test
	var/list/test_candidates = list()

/obj/machinery/computer/camera_advanced/shuttle_docker/survey/launch_test/get_survey_candidates()
	return test_candidates

/obj/machinery/computer/camera_advanced/shuttle_docker/survey/launch_test/get_current_celestial_object()
	return length(test_candidates) ? test_candidates[1] : null

/// Compare actual spawned stack exports with the strongest ordinary shop special.
/// Manufacturing, stock blocks and other exports have separate regression cases.
/datum/unit_test/voidcrew_trader_material_resale/Run()
	var/list/sku_types = list(
		/datum/shop_sku/general/plasma_sheets,
		/datum/shop_sku/general/plasma_ore,
		/datum/shop_sku/general/plasteel,
		/datum/shop_sku/outfitter/plasteel_stock,
	)
	for(var/sku_type in sku_types)
		var/datum/shop_sku/sku = new sku_type
		sku.discount_pct = 30
		var/obj/item/stack/goods = allocate(sku.item_path, run_loc_floor_bottom_left, sku.dispense_amount)
		var/datum/export_report/report = export_item_and_contents(goods, apply_elastic = FALSE, dry_run = TRUE)
		var/resale = counterlist_sum(report.total_value)
		var/purchase = sku.get_credit_price()
		if(resale > purchase)
			TEST_FAIL("[sku.type] costs [purchase] with a normal special but exports for [resale] credits")
		qdel(report)
		qdel(sku)

/// A small real shop with more pool choices than shelf slots.
/datum/outpost_shop/launch_shelf_test
	sku_types = list(/datum/shop_sku/general/beans)
	rotating_pool = list(/datum/shop_sku/general/soap, /datum/shop_sku/general/toolbelt)
	rotating_picks = 1
	rare_pool = list(/datum/shop_sku/fitter/rare/suit_advanced, /datum/shop_sku/skunk/rare/hyper_cell)
	rare_picks_max = 1
	favor_sku_types = list(/datum/shop_sku/favor/field_contract_pad)
	chart_pool = list(/datum/shop_sku/ruin_chart/hospice, /datum/shop_sku/ruin_chart/biolab)
	chart_picks = 1

/// Elapsed time must not change shelf size, gates or ordinary convoy behavior.
/datum/unit_test/voidcrew_launch_normal_shelves
	var/saved_round_start

/datum/unit_test/voidcrew_launch_normal_shelves/Destroy()
	SSticker.round_start_time = saved_round_start
	return ..()

/datum/unit_test/voidcrew_launch_normal_shelves/Run()
	saved_round_start = SSticker.round_start_time
	for(var/elapsed in list(0, 180 MINUTES, 420 MINUTES))
		SSticker.round_start_time = world.time - elapsed
		var/datum/outpost_shop/shop = allocate(/datum/outpost_shop/launch_shelf_test)
		TEST_ASSERT_EQUAL(length(shop.skus), 5, "Round age expanded the shop beyond its normal shelf picks")
		var/list/found = list()
		var/datum/shop_sku/core
		var/datum/shop_sku/rotating
		var/datum/shop_sku/rare
		var/datum/shop_sku/favor
		var/datum/shop_sku/chart
		for(var/datum/shop_sku/sku as anything in shop.skus)
			TEST_ASSERT(!(sku.type in found), "Normal shelves duplicated a SKU")
			found += sku.type
			if(sku.type in shop.sku_types)
				core = sku
				TEST_ASSERT_EQUAL(sku.shelf, "core", "Core goods lost their normal shelf")
			else if(sku.type in shop.rotating_pool)
				rotating = sku
				TEST_ASSERT_EQUAL(sku.shelf, "rotating", "Rotating goods were promoted by round age")
			else if(sku.type in shop.rare_pool)
				rare = sku
				TEST_ASSERT_EQUAL(sku.shelf, "rare", "Rare goods were promoted by round age")
			else if(sku.type in shop.favor_sku_types)
				favor = sku
				TEST_ASSERT_EQUAL(sku.shelf, "favor", "Favor goods lost their gate")
			else if(sku.type in shop.chart_pool)
				chart = sku
				TEST_ASSERT_EQUAL(sku.shelf, "rotating", "Chart picks must stay on their own rotating shelf")
		TEST_ASSERT(core && rotating && rare && favor && chart, "A normal shelf family was missing")
		var/rotating_type = rotating.type
		var/chart_type = chart.type
		core.stock = 0
		rotating.stock = 0
		rare.stock = 0
		chart.stock = 0
		SSticker.round_start_time = world.time - (420 MINUTES)
		shop.convoy_restock()
		TEST_ASSERT_EQUAL(length(shop.skus), 5, "A late convoy expanded the catalog")
		TEST_ASSERT(core.stock > 0, "Core goods did not replenish")
		TEST_ASSERT_EQUAL(rare.stock, 0, "Normal rare stock became endlessly restockable")
		TEST_ASSERT_EQUAL(chart.stock, chart.stock_max, "Named charts did not replenish for another paid expedition")
		TEST_ASSERT_EQUAL(chart.type, chart_type, "Chart restock substituted unrelated goods")
		TEST_ASSERT_EQUAL(favor.shelf, "favor", "Restock removed the favor gate")
		var/replacement_found = FALSE
		for(var/datum/shop_sku/sku as anything in shop.skus)
			if(sku.type in shop.rotating_pool)
				replacement_found = sku.type != rotating_type && sku.shelf == "rotating" && sku.stock > 0
		TEST_ASSERT(replacement_found, "Sold rotating stock did not rotate into another pool choice")
	// Buying/dealing a named template at one shop cannot reserve it galaxy-wide.
	var/datum/outpost_shop/first = allocate(/datum/outpost_shop)
	first.chart_pool = list(/datum/shop_sku/ruin_chart/hospice)
	var/datum/outpost_shop/second = allocate(/datum/outpost_shop)
	second.chart_pool = first.chart_pool.Copy()
	TEST_ASSERT_EQUAL(length(first.deal_chart_picks()), 1, "First shop could not deal its chart")
	TEST_ASSERT_EQUAL(length(second.deal_chart_picks()), 1, "First shop reserved the second shop's chart")

/// A sparse reward pool must meet the actual ask premium within600cr tolerance.
/datum/unit_test/voidcrew_launch_thin_contract/Run()
	var/datum/outpost_shop/shop = allocate(/datum/outpost_shop)
	shop.add_sku(/datum/shop_sku/general/beans, "core")
	var/datum/mission/mission = allocate(/datum/mission)
	mission.difficulty = 1
	TEST_ASSERT(shop.roll_contract_reward(mission, 12000), "A thin priced catalog must still fund its contract")
	var/datum/shop_sku/sku = shop.skus[1]
	var/value = shop.get_sku_value(sku) + mission.voucher_count * 1200
	TEST_ASSERT(value >= 12000 * 1.6 - 600, "Sparse rewards fell below the actual ask premium after voucher rounding")
	TEST_ASSERT_EQUAL(length(mission.mission_rewards), 1, "Thin reward generation duplicated the same item")

/// Repeated purchases use real payment, stock and crew lookup, even with a sealed copy.
/datum/unit_test/voidcrew_launch_chart_purchases/Run()
	var/datum/outpost_shop/shop = allocate(/datum/outpost_shop)
	shop.add_sku(/datum/shop_sku/ruin_chart/hospice, "rotating")
	var/datum/shop_sku/ruin_chart/sku = shop.skus[1]
	var/obj/structure/overmap/ship/ship = allocate(/obj/structure/overmap/ship)
	var/mob/living/carbon/human/buyer = allocate(/mob/living/carbon/human/consistent)
	buyer.mind_initialize()
	allocated += buyer.mind
	var/datum/team/voidcrew/team = allocate(/datum/team/voidcrew)
	team.ship = ship
	buyer.mind.ship_teams = list(team)
	var/datum/bank_account/account = allocate(/datum/bank_account, "Chart purchase test", null, 1, FALSE)
	account.account_balance = 20000
	var/obj/item/card/id/advanced/id_card = allocate(/obj/item/card/id/advanced)
	qdel(id_card.registered_account)
	id_card.registered_account = account
	TEST_ASSERT(buyer.put_in_hands(id_card), "Buyer could not carry their paying ID")
	var/price = sku.get_credit_price(buyer)
	TEST_ASSERT(sku.try_purchase(buyer, null), "First chart purchase failed")
	TEST_ASSERT_EQUAL(account.account_balance, 20000 - price, "First chart charged the wrong bill")
	TEST_ASSERT_EQUAL(length(ship.pending_rumors), 1, "Purchase did not upload a sealed chart")
	var/datum/rumor_chart/first = ship.pending_rumors[1]
	TEST_ASSERT(!sku.try_purchase(buyer, null), "Out-of-stock chart could be bought again")
	TEST_ASSERT_EQUAL(account.account_balance, 20000 - price, "Refused purchase charged money")
	shop.convoy_restock()
	price = sku.get_credit_price(buyer) // Convoys may roll a new ordinary special.
	var/balance_before = account.account_balance
	TEST_ASSERT(sku.try_purchase(buyer, null), "An existing sealed chart blocked a second paid copy")
	TEST_ASSERT_EQUAL(account.account_balance, balance_before - price, "Restocked chart did not charge its quoted price")
	TEST_ASSERT_EQUAL(length(ship.pending_rumors), 2, "Second purchase reused the first sealed chart")
	var/datum/rumor_chart/second = ship.pending_rumors[2]
	TEST_ASSERT(first != second, "Purchases must own separate reveal state")
	TEST_ASSERT_EQUAL(first.ruin_template_path, second.ruin_template_path, "Restock changed the purchased template")
	qdel(ship)
	TEST_ASSERT(QDELETED(first) && QDELETED(second), "Hull loss left its sealed charts alive")
	buyer.mind.ship_teams = null
	team.ship = null

/// Repriced and depleted shelves still fund contract bands and real stack quantities.
/datum/unit_test/voidcrew_launch_contract_rewards/Run()
	for(var/shop_type in list(/datum/outpost_shop/general, /datum/outpost_shop/outfitter, /datum/outpost_shop/black_market))
		var/datum/outpost_shop/shop = new shop_type(null)
		for(var/datum/shop_sku/sku as anything in shop.skus)
			sku.stock = 0
		for(var/difficulty in list(1, 2, 3))
			for(var/attempt in 1 to 20)
				var/datum/mission/mission = new
				mission.difficulty = difficulty
				if(!shop.roll_contract_reward(mission))
					TEST_FAIL("[shop_type] cannot fund a [difficulty] contract")
					qdel(mission)
					continue
				var/value = mission.voucher_count * 1200
				for(var/item_type in mission.mission_rewards)
					if(item_type in mission.rare_reward_types)
						value += 3600
						continue
					for(var/datum/shop_sku/sku as anything in shop.skus)
						if(sku.item_path != item_type || sku.shelf == "favor")
							continue
						value += shop.get_sku_value(sku)
						if(sku.dispense_amount > 1 && mission.reward_amounts?[item_type] != sku.dispense_amount)
							TEST_FAIL("[shop_type] awards the wrong quantity of [item_type]")
						break
				var/minimum = 1400
				if(difficulty == 2)
					minimum = 2600
				else if(difficulty == 3)
					minimum = 5500
				if(value < minimum - 600)
					TEST_FAIL("[shop_type] pays [value] against minimum [minimum] with tolerance [600]")
				qdel(mission)
		qdel(shop)
