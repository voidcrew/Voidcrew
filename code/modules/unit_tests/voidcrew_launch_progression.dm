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

/// Convoys must expose every ordinary family and refill it without duplicating SKUs.
/datum/unit_test/voidcrew_launch_full_catalog/Run()
	var/list/saved_charts = GLOB.dealt_rumor_charts.Copy()
	for(var/shop_type in subtypesof(/datum/outpost_shop))
		var/datum/outpost_shop/shop = new shop_type(null)
		shop.open_full_catalog()
		var/list/expected = shop.sku_types | shop.rotating_pool | shop.rare_pool | shop.chart_pool
		var/list/found = list()
		for(var/datum/shop_sku/sku as anything in shop.skus)
			if(sku.type in found)
				TEST_FAIL("[shop_type] duplicates [sku.type] after the full manifest opens")
			found += sku.type
			if(sku.shelf == "favor")
				continue
			if(sku.shelf != "core" || sku.stock < 1)
				TEST_FAIL("[shop_type] failed to make [sku.type] available and restockable")
			sku.stock = 0
		if(length(expected - found))
			TEST_FAIL("[shop_type] omits [length(expected - found)] ordinary catalog lines")
		var/count_before = length(shop.skus)
		shop.open_full_catalog()
		shop.convoy_restock()
		if(length(shop.skus) != count_before)
			TEST_FAIL("Repeated maturity/restock changed [shop_type]'s SKU count")
		for(var/datum/shop_sku/sku as anything in shop.skus)
			if(sku.shelf != "favor" && sku.stock < 1)
				TEST_FAIL("[shop_type] did not refill [sku.type]")
		qdel(shop)
	GLOB.dealt_rumor_charts = saved_charts

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

/// A lost sealed chart releases its reservation; completed encounters stay unique.
/datum/unit_test/voidcrew_launch_chart_claim/Run()
	var/list/saved_claims = GLOB.claimed_rumor_charts.Copy()
	var/chart_type = /datum/map_template/ruin/space/rare/hospice
	var/datum/rumor_chart/chart = new
	chart.ruin_template_path = chart_type
	chart.owns_claim = TRUE
	GLOB.claimed_rumor_charts[chart_type] = TRUE
	qdel(chart)
	if(GLOB.claimed_rumor_charts[chart_type])
		TEST_FAIL("Deleting a hull's unrevealed chart must release its reservation")
	chart = new
	chart.ruin_template_path = chart_type
	chart.owns_claim = TRUE
	chart.revealed = TRUE
	GLOB.claimed_rumor_charts[chart_type] = TRUE
	qdel(chart)
	if(!GLOB.claimed_rumor_charts[chart_type])
		TEST_FAIL("Deleting a consumed chart must not allow a second encounter")
	GLOB.claimed_rumor_charts = saved_claims

/// Repriced and depleted shelves still fund contract bands and real stack quantities.
/datum/unit_test/voidcrew_launch_contract_rewards/Run()
	var/list/saved_charts = GLOB.dealt_rumor_charts.Copy()
	for(var/shop_type in list(/datum/outpost_shop/general, /datum/outpost_shop/outfitter, /datum/outpost_shop/black_market))
		var/datum/outpost_shop/shop = new shop_type(null)
		shop.open_full_catalog()
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
	GLOB.dealt_rumor_charts = saved_charts
