#ifndef VOIDCREW_ZONE_MISSIONS_TESTS
#define VOIDCREW_ZONE_MISSIONS_TESTS

// Fork defines are included later than the test harness. Bands and permissions use literals.
/datum/mission_target/zone_missions_test
	var/band = 1
	var/valid = TRUE
	var/resolve_calls = 0

/datum/mission_target/zone_missions_test/get_zone_type()
	return band

/datum/mission_target/zone_missions_test/is_valid()
	return valid

/datum/mission_target/zone_missions_test/resolve()
	resolve_calls++
	return valid

/datum/mission_objective/zone_missions_test
	completed = TRUE
	var/claim_seen = FALSE
	var/reentrant_result

/datum/mission_objective/zone_missions_test/on_turn_in_finalized(atom/reward_anchor)
	claim_seen = mission.work_receipt?.claimed
	reentrant_result = mission.turn_in(reward_anchor, null, TRUE)

/datum/mission/proc/zone_missions_fixture()
	var/datum/mission_target/zone_missions_test/site = new(src)
	site.band = preferred_zone || 1
	target = site
	quote_zone = site.band
	difficulty = quote_zone
	value = 100
	requires_item = FALSE
	add_objective(new /datum/mission_objective/zone_missions_test())
	prepare_work_receipt()

/datum/mission/zone_missions_test/generate_mission_details()
	zone_missions_fixture()

/datum/mission/zone_missions_test/update_text()

/datum/mission/zone_missions_test/routine/generate_mission_details()
	value = 100
	add_objective(new /datum/mission_objective/zone_missions_test())

/datum/mission/recovery/kill/zone_missions_test
	weight = 0
	mission_limit = 0

/datum/mission/recovery/kill/zone_missions_test/generate_mission_details()
	zone_missions_fixture()

/datum/mission/recovery/kill/zone_missions_test/update_text()

/datum/mission/recovery/kill/zone_missions_test/on_mission_started()

/datum/mission/recovery/kill/outpost/zone_missions_test
	weight = 0
	mission_limit = 0

/datum/mission/recovery/kill/outpost/zone_missions_test/generate_mission_details()
	zone_missions_fixture()

/datum/mission/recovery/kill/outpost/zone_missions_test/update_text()

/datum/mission/recovery/kill/outpost/zone_missions_test/on_mission_started()

/datum/mission/big_game_hunt/zone_missions_test
	weight = 0
	mission_limit = 0

/datum/mission/big_game_hunt/zone_missions_test/generate_mission_details()
	zone_missions_fixture()

/datum/mission/big_game_hunt/zone_missions_test/update_text()

/datum/mission/big_game_hunt/zone_missions_test/on_mission_started()

/datum/mission/big_game_hunt/zone_missions_test/capped
	mission_limit = 1

/datum/mission/live_capture/zone_missions_test
	weight = 0
	mission_limit = 0

/datum/mission/live_capture/zone_missions_test/generate_mission_details()
	zone_missions_fixture()

/datum/mission/live_capture/zone_missions_test/update_text()

/datum/mission/live_capture/zone_missions_test/on_mission_started()

/datum/mission/live_capture/zone_missions_test/capped
	mission_limit = 1

/datum/mission/poacher_bust/zone_missions_test
	weight = 0
	mission_limit = 0

/datum/mission/poacher_bust/zone_missions_test/generate_mission_details()
	zone_missions_fixture()

/datum/mission/poacher_bust/zone_missions_test/update_text()

/datum/mission/poacher_bust/zone_missions_test/on_mission_started()

/datum/mission/poacher_bust/zone_missions_test/capped
	mission_limit = 1

/datum/mission/recovery/survey/zone_missions_test
	weight = 0
	mission_limit = 0

/datum/mission/recovery/survey/zone_missions_test/generate_mission_details()
	zone_missions_fixture()

/datum/mission/recovery/survey/zone_missions_test/update_text()

/datum/mission/recovery/survey/zone_missions_test/on_mission_started()

/datum/mission/research/core_sample/zone_missions_test
	weight = 0
	mission_limit = 0

/datum/mission/research/core_sample/zone_missions_test/generate_mission_details()
	zone_missions_fixture()

/datum/mission/research/core_sample/zone_missions_test/update_text()

/datum/mission/research/core_sample/zone_missions_test/on_mission_started()

/datum/mission/recovery/extraction/zone_missions_test
	weight = 0
	mission_limit = 0

/datum/mission/recovery/extraction/zone_missions_test/generate_mission_details()
	zone_missions_fixture()

/datum/mission/recovery/extraction/zone_missions_test/update_text()

/datum/mission/recovery/extraction/zone_missions_test/on_mission_started()

/datum/mission/prospect_stake/zone_missions_test
	weight = 0
	mission_limit = 0

/datum/mission/prospect_stake/zone_missions_test/generate_mission_details()
	zone_missions_fixture()

/datum/mission/prospect_stake/zone_missions_test/update_text()

/datum/mission/prospect_stake/zone_missions_test/on_mission_started()

/datum/mission/suppression/zone_missions_test
	weight = 0
	mission_limit = 0

/datum/mission/suppression/zone_missions_test/generate_mission_details()
	zone_missions_fixture()

/datum/mission/suppression/zone_missions_test/update_text()

/datum/mission/suppression/zone_missions_test/on_mission_started()

/datum/mission/recovery/zone_missions_test
	weight = 0
	mission_limit = 0

/datum/mission/recovery/zone_missions_test/generate_mission_details()
	zone_missions_fixture()

/datum/mission/recovery/zone_missions_test/update_text()

/datum/mission/recovery/zone_missions_test/on_mission_started()

/datum/mission/rescue/zone_missions_test
	weight = 0
	mission_limit = 0

/datum/mission/rescue/zone_missions_test/generate_mission_details()
	zone_missions_fixture()

/datum/mission/rescue/zone_missions_test/update_text()

/datum/mission/rescue/zone_missions_test/on_mission_started()

/datum/mission/outpost_courier/zone_missions_test
	weight = 0
	mission_limit = 0

/datum/mission/outpost_courier/zone_missions_test/generate_mission_details()
	zone_missions_fixture()

/datum/mission/outpost_courier/zone_missions_test/update_text()

/datum/mission/outpost_courier/zone_missions_test/on_mission_started()

/datum/mission/outpost_courier/zone_missions_test/can_turn_in_at(atom/reward_anchor)
	return TRUE

/datum/mission/survey/zone_missions_test
	weight = 0
	mission_limit = 0

/datum/mission/survey/zone_missions_test/generate_mission_details()
	zone_missions_fixture()

/datum/mission/survey/zone_missions_test/update_text()

/datum/mission/survey/zone_missions_test/on_mission_started()

/datum/mission/research/telemetry/zone_missions_test
	weight = 0
	mission_limit = 0

/datum/mission/research/telemetry/zone_missions_test/generate_mission_details()
	zone_missions_fixture()

/datum/mission/research/telemetry/zone_missions_test/update_text()

/datum/mission/research/telemetry/zone_missions_test/on_mission_started()

/datum/mission/gas_harvest/zone_missions_test
	weight = 0
	mission_limit = 0

/datum/mission/gas_harvest/zone_missions_test/generate_mission_details()
	zone_missions_fixture()

/datum/mission/gas_harvest/zone_missions_test/update_text()

/datum/mission/gas_harvest/zone_missions_test/on_mission_started()

/datum/mission/outpost_supply/zone_missions_test
	weight = 0
	mission_limit = 0

/datum/mission/outpost_supply/zone_missions_test/generate_mission_details()
	zone_missions_fixture()

/datum/mission/outpost_supply/zone_missions_test/update_text()

/datum/mission/outpost_supply/zone_missions_test/on_mission_started()

/datum/mission/outpost_supply/cook/zone_missions_test
	weight = 0
	mission_limit = 0

/datum/mission/outpost_supply/cook/zone_missions_test/generate_mission_details()
	zone_missions_fixture()

/datum/mission/outpost_supply/cook/zone_missions_test/update_text()

/datum/mission/outpost_supply/cook/zone_missions_test/on_mission_started()

/datum/mission/outpost_supply/angler/zone_missions_test
	weight = 0
	mission_limit = 0

/datum/mission/outpost_supply/angler/zone_missions_test/generate_mission_details()
	zone_missions_fixture()

/datum/mission/outpost_supply/angler/zone_missions_test/update_text()

/datum/mission/outpost_supply/angler/zone_missions_test/on_mission_started()

/datum/mission/delivery/zone_missions_test
	weight = 0
	mission_limit = 0

/datum/mission/delivery/zone_missions_test/generate_mission_details()
	zone_missions_fixture()

/datum/mission/delivery/zone_missions_test/update_text()

/datum/mission/delivery/zone_missions_test/on_mission_started()

/obj/structure/overmap/ship/zone_missions_test/roll_mission_prize(zone)
	return null

/datum/controller/subsystem/missions/zone_missions_test
	var/fail_work = FALSE
	var/work_attempts = 0
	var/fail_first_families = 0
	var/list/failed_families = list()

/datum/controller/subsystem/missions/zone_missions_test/create_mission(mission_type, preferred_zone, posting_zone, list/eligible_zones, create_field_contact = FALSE)
	var/family = zone_reputation_family(mission_type)
	if(family)
		work_attempts++
		if(length(failed_families) < fail_first_families)
			failed_families |= family
		if(fail_work || (family in failed_families))
			return null
	return ..()

/datum/controller/subsystem/missions/zone_missions_test/get_weighted_mission_type()
	return /datum/mission/zone_missions_test/routine

/datum/controller/subsystem/missions/zone_missions_test/ensure_safe_exploration_offer(obj/structure/overmap/ship/ship)
	ship.available_missions += new /datum/mission/zone_missions_test(null, 1)
	return TRUE

/datum/controller/subsystem/overmap/zone_missions_test
	var/capacity = FALSE
	var/any_band_calls = 0
	var/turf/destination

/datum/controller/subsystem/overmap/zone_missions_test/mission_contact_capacity(tenant_class)
	return capacity

/datum/controller/subsystem/overmap/zone_missions_test/get_unused_overmap_square_in_zone_band(band, thing_not_to_have = /obj/structure/overmap, tries = 40)
	return destination

/datum/controller/subsystem/overmap/zone_missions_test/get_unused_overmap_square(thing_not_to_have = /obj/structure/overmap, tries = 40, force = FALSE)
	any_band_calls++
	return null

/datum/unit_test/voidcrew_zone_missions
	abstract_type = /datum/unit_test/voidcrew_zone_missions
	var/list/records = list()
	var/list/old_types
	var/old_metrics
	var/list/old_tallies

/datum/unit_test/voidcrew_zone_missions/New()
	. = ..()
	old_types = SSmissions.mission_types
	old_metrics = SSmetrics.accepting
	old_tallies = SSmetrics.tallies
	SSmetrics.accepting = FALSE
	SSmetrics.tallies = list()

/datum/unit_test/voidcrew_zone_missions/Destroy()
	SSmissions.mission_types = old_types
	SSmetrics.accepting = old_metrics
	SSmetrics.tallies = old_tallies
	QDEL_LIST(records)
	return ..()

/datum/unit_test/voidcrew_zone_missions/proc/make_ship(permission = 0)
	var/obj/structure/overmap/ship/ship = allocate(/obj/structure/overmap/ship/zone_missions_test)
	ship.ship_team = new
	ship.ship_team.ship = ship
	var/datum/voidcrew_crew_record/record = ship.get_crew_record()
	records += record
	ship.ship_account = allocate(/datum/bank_account)
	if(permission >= 1)
		for(var/family in list("named_kill", "hunt", "capture"))
			record.claim_zone_work(family, 1, 1, "setup_green_[family]")
	if(permission >= 2)
		for(var/family in list("named_kill", "hunt", "capture"))
			record.claim_zone_work(family, 2, 2, "setup_yellow_[family]")
	if(permission >= 3)
		for(var/family in list("named_kill", "hunt", "capture"))
			record.claim_zone_work(family, 3, 3, "setup_red_[family]")
	return ship

/// Console and board variants all settle through the real shell, with claims before finalizers.
/datum/unit_test/voidcrew_zone_missions/families/Run()
	var/list/types = list(
		/datum/mission/recovery/kill/zone_missions_test = "named_kill",
		/datum/mission/recovery/kill/outpost/zone_missions_test = "named_kill",
		/datum/mission/big_game_hunt/zone_missions_test = "hunt",
		/datum/mission/live_capture/zone_missions_test = "capture",
		/datum/mission/poacher_bust/zone_missions_test = "poachers",
		/datum/mission/recovery/survey/zone_missions_test = "pylons",
		/datum/mission/research/core_sample/zone_missions_test = "pylons",
		/datum/mission/recovery/extraction/zone_missions_test = "extraction",
	)
	for(var/mission_type in types)
		for(var/band in 1 to 3)
			var/obj/structure/overmap/ship/ship = make_ship(band - 1)
			var/datum/voidcrew_crew_record/record = ship.get_crew_record()
			var/datum/mission/mission = allocate(mission_type, null, band)
			var/datum/mission_work_receipt/receipt = mission.work_receipt
			var/datum/mission_objective/zone_missions_test/finalizer = mission.objectives[1]
			ship.available_missions += mission
			TEST_ASSERT_EQUAL(receipt.family, types[mission_type], "Wrong family for [mission_type]")
			TEST_ASSERT_EQUAL(ship.accept_mission(mission), TRUE, "Eligible work was denied")
			TEST_ASSERT_EQUAL(receipt.crew, record, "Acceptance did not bind the crew")
			TEST_ASSERT(mission.turn_in(run_loc_floor_bottom_left, null), "Successful work did not settle")
			TEST_ASSERT_EQUAL(record.zone_totals["[band]"], band, "Wrong band gain")
			TEST_ASSERT(finalizer.claim_seen, "A finalizer ran before the claim")
			TEST_ASSERT(!finalizer.reentrant_result, "A finalizer settled the mission twice")
			TEST_ASSERT(!mission.turn_in(run_loc_floor_bottom_left, null, TRUE), "Stale completion settled again")

/// Renaming and buying difficult routine asks cannot invent guarded work.
/datum/unit_test/voidcrew_zone_missions/exclusions/Run()
	var/list/types = list(
		/datum/mission/prospect_stake/zone_missions_test,
		/datum/mission/suppression/zone_missions_test,
		/datum/mission/recovery/zone_missions_test,
		/datum/mission/rescue/zone_missions_test,
		/datum/mission/outpost_courier/zone_missions_test,
		/datum/mission/survey/zone_missions_test,
		/datum/mission/research/telemetry/zone_missions_test,
		/datum/mission/gas_harvest/zone_missions_test,
		/datum/mission/outpost_supply/zone_missions_test,
		/datum/mission/outpost_supply/cook/zone_missions_test,
		/datum/mission/outpost_supply/angler/zone_missions_test,
		/datum/mission/delivery/zone_missions_test,
	)
	var/obj/structure/overmap/ship/ship = make_ship(2)
	var/datum/voidcrew_crew_record/record = ship.get_crew_record()
	for(var/mission_type in types)
		var/datum/mission/mission = allocate(mission_type, null, 3)
		mission.name = "Kill Contract"
		mission.difficulty = 3
		TEST_ASSERT_NULL(mission.work_receipt, "Excluded work obtained a receipt")
		TEST_ASSERT(mission.start_mission(ship), "Existing nonqualifying work was denied")
		TEST_ASSERT(mission.turn_in(run_loc_floor_bottom_left, null), "Existing reward path stopped settling")
	TEST_ASSERT_EQUAL(record.zone_totals["3"], 0, "Routine work earned red progression")
	var/obj/structure/overmap/ship/public_ship = make_ship()
	var/datum/mission/routine = allocate(/datum/mission/zone_missions_test/routine, null, null, 3)
	routine.difficulty = 3
	TEST_ASSERT(routine.start_mission(public_ship), "Targetless ask was gated by the posting zone")
	TEST_ASSERT(routine.turn_in(run_loc_floor_bottom_left, null), "Targetless routine work did not pay")

/// Aliases, capped claims and crew changes retain one encounter's original recipient.
/datum/unit_test/voidcrew_zone_missions/receipts/Run()
	var/obj/structure/overmap/ship/ship = make_ship()
	var/obj/structure/overmap/ship/other = make_ship()
	var/datum/voidcrew_crew_record/original = ship.get_crew_record()
	var/datum/voidcrew_crew_record/different = other.get_crew_record()
	var/datum/outpost_shop/shop = allocate(/datum/outpost_shop)
	var/datum/mission/first = allocate(/datum/mission/recovery/kill/zone_missions_test, shop)
	var/datum/mission/alias = allocate(/datum/mission/recovery/kill/outpost/zone_missions_test)
	var/datum/mission_work_receipt/receipt = first.work_receipt
	alias.work_receipt = receipt
	TEST_ASSERT(first.start_mission(ship), "Original receipt did not bind")
	TEST_ASSERT(!alias.start_mission(other), "An alias redirected the receipt to another crew")
	TEST_ASSERT(alias.start_mission(ship), "Same-crew alias could not bind")
	ship.ship_team.set_crew_record(different)
	TEST_ASSERT(first.turn_in(run_loc_floor_bottom_left, null), "Crew change prevented the original settlement")
	TEST_ASSERT_EQUAL(original.zone_totals["1"], 1, "Original crew did not receive its work")
	TEST_ASSERT_EQUAL(different.zone_totals["1"], 0, "Current hull affiliation stole an accepted receipt")
	TEST_ASSERT_EQUAL(original.trader_favor[shop.favor_key()], 1, "Board favor left the accepting crew")
	TEST_ASSERT_EQUAL(different.trader_favor[shop.favor_key()] || 0, 0, "Current hull affiliation stole trader favor")
	TEST_ASSERT(alias.turn_in(run_loc_floor_bottom_left, null), "Alias lost its ordinary reward")
	TEST_ASSERT_EQUAL(original.zone_totals["1"], 1, "Alias credited the encounter twice")
	var/datum/mission/next = allocate(/datum/mission/recovery/kill/zone_missions_test)
	TEST_ASSERT(next.work_receipt.serial != receipt.serial, "New encounter reused an old serial")
	ship.ship_team.set_crew_record(original)
	TEST_ASSERT(next.start_mission(ship), "A capped family stopped ordinary work")
	var/datum/mission_work_receipt/capped = next.work_receipt
	TEST_ASSERT(next.turn_in(run_loc_floor_bottom_left, null), "Capped encounter did not settle")
	TEST_ASSERT(capped.claimed && original.settlement_claims["[capped.serial]:named_kill"], "Capped work was not claimed")
	TEST_ASSERT_EQUAL(original.zone_totals["1"], 1, "Capped encounter exceeded the family cap")

/// Retargeting cannot change the work band or mint a new objective receipt.
/datum/unit_test/voidcrew_zone_missions/retarget/Run()
	var/obj/structure/overmap/ship/ship = make_ship()
	var/datum/mission/mission = allocate(/datum/mission/recovery/kill/zone_missions_test)
	var/datum/mission_target/zone_missions_test/target = mission.target
	var/datum/mission_work_receipt/receipt = mission.work_receipt
	target.band = 99
	TEST_ASSERT(!mission.can_accept_work(ship), "Unknown band passed admission")
	target.band = 2
	TEST_ASSERT(!mission.resolve_quoted_target(), "Retarget escaped its pinned band")
	TEST_ASSERT(!mission.start_mission(ship), "Mismatched quote was accepted")
	target.band = 1
	TEST_ASSERT(mission.start_mission(ship), "Original band was refused")
	mission.named_kill_completed = TRUE
	mission.boss_cash_issued = TRUE
	mission.retarget()
	TEST_ASSERT_EQUAL(mission.work_receipt, receipt, "Retarget replaced the encounter receipt")
	TEST_ASSERT(mission.named_kill_completed && mission.boss_cash_issued, "Retarget reset S06 lifetime flags")
	TEST_ASSERT(!mission.create_field_contact, "Active work retained permission to mint contacts")
	target.band = 2
	TEST_ASSERT(!mission.turn_in(run_loc_floor_bottom_left, null), "Moving work laundered its band")

/// Viewer projections never consume the shared offer or mutate another crew's package.
/datum/unit_test/voidcrew_zone_missions/shared_offers/Run()
	var/obj/structure/overmap/trader_outpost/outpost = allocate(/obj/structure/overmap/trader_outpost)
	var/obj/structure/overmap/ship/public_ship = make_ship()
	var/obj/structure/overmap/ship/advanced_ship = make_ship(2)
	var/datum/mission/offer = allocate(/datum/mission/zone_missions_test, outpost.shop, 3)
	outpost.shop_offers += offer
	TEST_ASSERT_EQUAL(length(outpost.get_contract_offers_for(public_ship)), 0, "Public crew saw denied work")
	TEST_ASSERT_EQUAL(length(outpost.get_contract_offers_for(advanced_ship)), 1, "Eligible crew lost the shared offer")
	TEST_ASSERT(offer in outpost.shop_offers, "Filtering deleted a shared offer")
	public_ship.available_missions += offer
	TEST_ASSERT(public_ship.accept_mission(offer) != TRUE, "Stale action bypassed authoritative admission")
	public_ship.available_missions -= offer
	TEST_ASSERT(offer in outpost.shop_offers, "Denied acceptance consumed the shared offer")

/datum/unit_test/voidcrew_zone_missions/proc/package_offer(datum/shop_sku/sku)
	var/datum/mission/mission = allocate(/datum/mission/zone_missions_test/routine)
	mission.contract_quote = 2400
	mission.contract_stock = list()
	mission.contract_item_values = list()
	mission.contract_stock[sku.item_path] = sku
	mission.contract_item_values[sku.item_path] = 900
	mission.mission_rewards = list(sku.item_path)
	mission.reward_amounts = list()
	mission.reward_amounts[sku.item_path] = 1
	mission.set_contract_currency(1500)
	return mission

/// Permission/stock loss uses M1's exact remainder, with original-crew cap reservation/release.
/datum/unit_test/voidcrew_zone_missions/packages/Run()
	var/obj/structure/overmap/ship/public_ship = make_ship()
	var/obj/structure/overmap/ship/advanced_ship = make_ship(2)
	var/datum/voidcrew_crew_record/record = advanced_ship.get_crew_record()
	var/datum/shop_sku/sku = allocate(/datum/shop_sku/general/beans)
	sku.zone_permission = 2
	sku.stock = 2
	sku.crew_limit = 1
	var/datum/mission/offer = package_offer(sku)
	var/list/low = offer.get_effective_contract_package(public_ship.get_crew_record())
	var/list/high = offer.get_effective_contract_package(record)
	TEST_ASSERT_EQUAL(length(low["items"]), 0, "Public package included denied goods")
	TEST_ASSERT_EQUAL(length(high["items"]), 1, "Permitted package lost available goods")
	TEST_ASSERT_EQUAL(low["credits"] + low["vouchers"] * 1200, 2400, "Public fallback changed total value")
	TEST_ASSERT_EQUAL(length(offer.mission_rewards), 1, "Viewing rewrote the shared package")
	TEST_ASSERT_EQUAL(sku.stock, 2, "Viewing reserved stock")
	TEST_ASSERT(offer.start_mission(advanced_ship), "Permitted package did not reserve")
	TEST_ASSERT_EQUAL(sku.reserved_stock, 1, "Acceptance lost its stock hold")
	TEST_ASSERT_EQUAL(record.favor_unique_purchases[sku.type], 1, "Acceptance did not claim the crew cap")
	var/datum/mission/racing = package_offer(sku)
	TEST_ASSERT(racing.start_mission(advanced_ship), "A capped package should still accept currency")
	TEST_ASSERT_EQUAL(length(racing.get_reward_types()), 0, "Two packages charged the same crew cap")
	TEST_ASSERT_EQUAL(racing.value + racing.voucher_count * 1200, 2400, "Cap fallback lost value")
	offer.fail("Cancelled.")
	TEST_ASSERT_EQUAL(sku.stock, 2, "Cancellation lost held stock")
	TEST_ASSERT_EQUAL(record.favor_unique_purchases[sku.type], 0, "Cancellation lost the crew's purchase slot")
	var/datum/mission/settlement = package_offer(sku)
	TEST_ASSERT(settlement.start_mission(advanced_ship), "Second reservation failed")
	record.zone_totals["1"] = 0
	TEST_ASSERT(settlement.turn_in(run_loc_floor_bottom_left, null), "Permission loss blocked currency settlement")
	TEST_ASSERT_EQUAL(sku.stock, 2, "Denied settlement consumed the restricted goods")
	TEST_ASSERT_EQUAL(sku.reserved_stock, 0, "Denied settlement retained its hold")
	TEST_ASSERT_EQUAL(record.favor_unique_purchases[sku.type], 0, "Denied settlement consumed the original cap")
	TEST_ASSERT_EQUAL(public_ship.get_crew_record().favor_unique_purchases[sku.type] || 0, 0, "Another crew's cap was charged")
	var/datum/mission/drained = package_offer(sku)
	sku.stock = 0
	TEST_ASSERT(drained.start_mission(public_ship), "Empty shelf prevented currency settlement")
	TEST_ASSERT_EQUAL(length(drained.get_reward_types()), 0, "Unavailable stock remained in the bound package")
	TEST_ASSERT_EQUAL(drained.value + drained.voucher_count * 1200, 2400, "Empty shelf lost quoted value")

/// Original crew disposal releases stock and references without granting restricted goods later.
/datum/unit_test/voidcrew_zone_missions/cleanup/Run()
	var/obj/structure/overmap/ship/ship = make_ship(2)
	var/datum/voidcrew_crew_record/record = ship.get_crew_record()
	var/datum/shop_sku/sku = allocate(/datum/shop_sku/general/beans)
	sku.zone_permission = 2
	sku.stock = 1
	sku.crew_limit = 1
	var/datum/mission/mission = package_offer(sku)
	TEST_ASSERT(mission.start_mission(ship), "Cleanup fixture could not reserve")
	qdel(record)
	TEST_ASSERT_NULL(mission.accepting_crew, "Accepted work retained a disposed crew record")
	TEST_ASSERT_EQUAL(sku.stock, 1, "Crew disposal lost held stock")
	TEST_ASSERT_EQUAL(sku.reserved_stock, 0, "Crew disposal retained held stock")
	TEST_ASSERT_EQUAL(length(mission.get_reward_types()), 0, "Disposed crew retained restricted package goods")
	TEST_ASSERT_EQUAL(mission.value + mission.voucher_count * 1200, 2400, "Crew disposal changed the fixed quote")
	TEST_ASSERT(mission.turn_in(run_loc_floor_bottom_left, null), "Crew disposal prevented ordinary currency settlement")

/// Five slots, useful distinct families, partial supply, bounded vacancies and a fixed hull clock.
/datum/unit_test/voidcrew_zone_missions/opportunities/Run()
	var/datum/controller/subsystem/missions/zone_missions_test/controller = allocate(__IMPLIED_TYPE__)
	controller.mission_types = list(
		/datum/mission/recovery/kill/zone_missions_test,
		/datum/mission/big_game_hunt/zone_missions_test,
		/datum/mission/live_capture/zone_missions_test,
		/datum/mission/poacher_bust/zone_missions_test,
		/datum/mission/recovery/survey/zone_missions_test,
		/datum/mission/recovery/extraction/zone_missions_test,
	)
	var/obj/structure/overmap/ship/ship = make_ship()
	TEST_ASSERT(controller.refresh_ship_missions(ship), "Scheduled board generation failed")
	TEST_ASSERT_EQUAL(length(ship.available_missions), 5, "Board did not preserve five slots")
	var/list/families = list()
	for(var/datum/mission/offer in ship.available_missions)
		if(offer.work_receipt)
			families |= offer.work_receipt.family
			TEST_ASSERT_EQUAL(offer.quote_zone, 1, "New crew received higher-band useful work")
	TEST_ASSERT_EQUAL(length(families), 3, "Reserved work did not offer three distinct families")
	TEST_ASSERT_EQUAL(ship.next_mission_refresh, world.time + 20 MINUTES, "Scheduled interval changed")
	var/refresh_at = ship.next_mission_refresh
	var/datum/mission/accepted = ship.available_missions[1]
	TEST_ASSERT_EQUAL(ship.accept_mission(accepted), TRUE, "Reserved green travel fixture did not accept")
	var/datum/mission/deleted = ship.available_missions[1]
	ship.available_missions -= deleted
	qdel(deleted)
	var/attempts_before = controller.work_attempts
	TEST_ASSERT(!controller.force_refresh_ship_missions(ship), "Vacancies triggered a reroll")
	TEST_ASSERT_EQUAL(controller.work_attempts, attempts_before, "A premature refresh attempted generation")
	TEST_ASSERT_EQUAL(ship.next_mission_refresh, refresh_at, "A vacancy reset the hull's clock")
	controller.fail_work = TRUE
	ship.next_mission_refresh = world.time
	TEST_ASSERT(controller.refresh_ship_missions(ship), "Scheduled shortage did not refresh")
	TEST_ASSERT_EQUAL(length(ship.available_missions), 2, "Failed useful slots were silently filled with unrelated work")
	TEST_ASSERT(controller.work_attempts - attempts_before <= 48, "Shortage retries exceeded eight attempts for each of six useful families")
	TEST_ASSERT(accepted in ship.active_missions, "Refresh removed accepted work")
	var/obj/structure/overmap/ship/partial = make_ship()
	var/datum/voidcrew_crew_record/record = partial.get_crew_record()
	var/list/contributions = record.zone_families["1"]
	for(var/family in zone_reputation_families())
		contributions[family] = 1
	contributions["capture"] = 0
	contributions["poachers"] = 0
	controller.fail_work = FALSE
	var/missing = controller.reserve_useful_family_offers(partial)
	TEST_ASSERT_EQUAL(missing, 0, "Available uncapped work left a vacancy")
	TEST_ASSERT_EQUAL(length(partial.available_missions), 2, "A partial useful pool reserved unrelated families")
	record.zone_totals["1"] = 3
	TEST_ASSERT_EQUAL(controller.next_work_band(record), 2, "Next unmet band was not yellow")
	record.zone_totals["2"] = 6
	TEST_ASSERT_EQUAL(controller.next_work_band(record), 3, "Next unmet band was not red")
	record.zone_totals["3"] = 9
	TEST_ASSERT_NULL(controller.next_work_band(record), "Elite crew retained reserved progression work")

/// Globally held families cannot reserve failed slots ahead of available work.
/datum/unit_test/voidcrew_zone_missions/globally_capped_opportunities/Run()
	var/datum/controller/subsystem/missions/zone_missions_test/controller = allocate(__IMPLIED_TYPE__)
	var/obj/structure/overmap/ship/holder = make_ship()
	SSovermap.simulated_ships |= holder
	var/list/capped_types = list(
		/datum/mission/big_game_hunt/zone_missions_test/capped,
		/datum/mission/live_capture/zone_missions_test/capped,
		/datum/mission/poacher_bust/zone_missions_test/capped,
	)
	for(var/mission_type in capped_types)
		var/datum/mission/held = allocate(mission_type)
		holder.available_missions += held
		TEST_ASSERT(!mission_type_within_limit(mission_type), "Another hull's offer did not occupy its global cap")
	controller.mission_types = capped_types + list(/datum/mission/recovery/kill/zone_missions_test)
	var/obj/structure/overmap/ship/partial = make_ship()
	TEST_ASSERT(controller.refresh_ship_missions(partial), "Partial useful supply did not refresh")
	TEST_ASSERT_EQUAL(length(partial.available_missions), 5, "Globally capped families consumed otherwise available board slots")
	TEST_ASSERT_EQUAL(controller.work_attempts, 1, "Partial supply did not reserve exactly its one available family")

	controller.mission_types += /datum/mission/recovery/survey/zone_missions_test
	controller.mission_types += /datum/mission/recovery/extraction/zone_missions_test
	var/obj/structure/overmap/ship/ship = make_ship()
	TEST_ASSERT(controller.refresh_ship_missions(ship), "Globally capped supply did not refresh")
	var/list/families = list()
	for(var/datum/mission/offer in ship.available_missions)
		if(offer.work_receipt)
			families |= offer.work_receipt.family
			TEST_ASSERT_EQUAL(offer.quote_zone, 1, "Zero-standing crew received higher-band work")
	TEST_ASSERT_EQUAL(length(families), 3, "Held hunt, capture and poacher jobs hid available useful families")
	for(var/family in list("named_kill", "pylons", "extraction"))
		TEST_ASSERT(family in families, "Available [family] work was not reserved")
	TEST_ASSERT_EQUAL(length(ship.available_missions), 5, "Global caps left a board vacancy despite useful supply")

/// Failures use bounded retries, then the remaining useful families in the same scheduled batch.
/datum/unit_test/voidcrew_zone_missions/remaining_families/Run()
	var/datum/controller/subsystem/missions/zone_missions_test/controller = allocate(__IMPLIED_TYPE__)
	controller.mission_types = list(
		/datum/mission/recovery/kill/zone_missions_test,
		/datum/mission/big_game_hunt/zone_missions_test,
		/datum/mission/live_capture/zone_missions_test,
		/datum/mission/poacher_bust/zone_missions_test,
		/datum/mission/recovery/survey/zone_missions_test,
		/datum/mission/recovery/extraction/zone_missions_test,
	)
	controller.fail_first_families = 3
	var/obj/structure/overmap/ship/ship = make_ship()
	TEST_ASSERT(controller.refresh_ship_missions(ship), "Scheduled fallback did not refresh")
	TEST_ASSERT_EQUAL(length(controller.failed_families), 3, "Fixture did not exhaust the first three chosen families")
	TEST_ASSERT_EQUAL(controller.work_attempts, 27, "Fallback did not bound retries and try all remaining families")
	var/list/families = list()
	for(var/datum/mission/offer in ship.available_missions)
		if(offer.work_receipt)
			families |= offer.work_receipt.family
			TEST_ASSERT(!(offer.work_receipt.family in controller.failed_families), "A failed family produced an offer")
	TEST_ASSERT_EQUAL(length(families), 3, "Remaining useful families did not fill the reserved slots")
	TEST_ASSERT_EQUAL(length(ship.available_missions), 5, "Family fallback lost a board slot")
	var/attempts_before = controller.work_attempts
	var/refresh_at = ship.next_mission_refresh
	TEST_ASSERT(!controller.force_refresh_ship_missions(ship), "Family fallback allowed an immediate reroll")
	TEST_ASSERT_EQUAL(controller.work_attempts, attempts_before, "An immediate refresh retried useful families")
	TEST_ASSERT_EQUAL(ship.next_mission_refresh, refresh_at, "Family fallback changed the fixed refresh clock")

/// Actual contact entry points fail closed at capacity and never fall back across bands.
/datum/unit_test/voidcrew_zone_missions/capacity/Run()
	var/datum/controller/subsystem/overmap/zone_missions_test/controller = allocate(__IMPLIED_TYPE__)
	var/planets_before = length(GLOB.overmap_planets)
	var/ruins_before = length(GLOB.space_ruin_signals)
	TEST_ASSERT_NULL(controller.spawn_mission_planet(1), "Full world created a planet contact")
	TEST_ASSERT_NULL(controller.spawn_mission_ruin(1), "Full world created a ruin contact")
	TEST_ASSERT_EQUAL(length(GLOB.overmap_planets), planets_before, "Capacity refusal leaked a planet")
	TEST_ASSERT_EQUAL(length(GLOB.space_ruin_signals), ruins_before, "Capacity refusal leaked a ruin")
	controller.capacity = TRUE
	TEST_ASSERT_NULL(controller.spawn_mission_planet(1), "Empty overmap created an invalid contact")
	TEST_ASSERT_NULL(controller.spawn_dynamic_planet(/obj/structure/overmap/planet/lava, 1, 1, null, TRUE), "Strict contact creation invented a destination")
	TEST_ASSERT_EQUAL(controller.any_band_calls, 0, "A strict contact fell back outside its band")

/// Mixed occupancy, unknown zones and absent coordinate bands never trigger a higher-band fallback.
/datum/unit_test/voidcrew_zone_missions/strict_targets
	var/list/saved_planets
	var/list/saved_ruins
	var/list/saved_outposts
	var/turf/green
	var/turf/red
	var/green_type
	var/red_type

/datum/unit_test/voidcrew_zone_missions/strict_targets/Destroy()
	. = ..()
	if(green)
		green.ChangeTurf(green_type)
	if(red)
		red.ChangeTurf(red_type)
	if(saved_planets)
		GLOB.overmap_planets = saved_planets
	if(saved_ruins)
		GLOB.space_ruin_signals = saved_ruins
	if(saved_outposts)
		GLOB.trader_outposts = saved_outposts

/datum/unit_test/voidcrew_zone_missions/strict_targets/Run()
	saved_planets = GLOB.overmap_planets
	saved_ruins = GLOB.space_ruin_signals
	saved_outposts = GLOB.trader_outposts
	GLOB.overmap_planets = list()
	GLOB.space_ruin_signals = list()
	GLOB.trader_outposts = list()
	green_type = run_loc_floor_bottom_left.type
	red_type = run_loc_floor_top_right.type
	green = run_loc_floor_bottom_left.ChangeTurf(/turf/open/overmap)
	red = run_loc_floor_top_right.ChangeTurf(/turf/open/overmap)
	var/turf/open/overmap/green_tile = green
	var/turf/open/overmap/red_tile = red
	green_tile.current_zone = allocate(/datum/overmap_zone, 1)
	red_tile.current_zone = allocate(/datum/overmap_zone, 3)
	var/obj/structure/overmap/space_ruin/green_ruin = allocate(__IMPLIED_TYPE__, green)
	var/obj/structure/overmap/space_ruin/red_ruin = allocate(__IMPLIED_TYPE__, red)
	green_ruin.loaded = TRUE
	var/datum/mission/mission = allocate(/datum/mission/zone_missions_test, null, 1)
	var/datum/mission_target/space_ruin/ruin_target = allocate(__IMPLIED_TYPE__, mission)
	TEST_ASSERT(ruin_target.resolve(), "An eligible loaded site was hidden by a cold site in another band")
	TEST_ASSERT_EQUAL(ruin_target.ruin, green_ruin, "Ruin preference escaped its band")
	ruin_target.unhook()
	TEST_ASSERT_EQUAL(green_ruin.mission_claims, 0, "Unhook retained the ruin claim")
	mission.exclusive_site = TRUE
	TEST_ASSERT(!ruin_target.resolve(), "Exclusive work fell back to an ineligible cold ruin")
	mission.exclusive_site = FALSE
	var/obj/structure/overmap/planet/lava/green_planet = allocate(__IMPLIED_TYPE__, green)
	var/obj/structure/overmap/planet/lava/red_planet = allocate(__IMPLIED_TYPE__, red)
	var/datum/mission_target/planet/planet_target = allocate(__IMPLIED_TYPE__, mission)
	TEST_ASSERT(planet_target.resolve(), "Eligible planet was not selected")
	TEST_ASSERT_EQUAL(planet_target.planet, green_planet, "Planet resolution escaped its band")
	planet_target.unhook()
	green_planet.mission_exclusive = TRUE
	TEST_ASSERT(!planet_target.resolve(), "Planet selection ignored site exclusivity")
	green_planet.mission_exclusive = FALSE
	var/list/tables = list(/datum/overmap/planet/lava = TRUE)
	TEST_ASSERT_EQUAL(length(mission.get_work_biomes(tables)), 1, "Eligible biome pool was empty")
	green_tile.current_zone = null
	TEST_ASSERT(!planet_target.resolve(), "Unknown planet band was accepted")
	TEST_ASSERT(!ruin_target.resolve(), "Unknown ruin band was accepted")
	TEST_ASSERT_EQUAL(length(mission.get_work_biomes(tables)), 0, "Biome preselection included unknown or denied sites")
	mission.create_field_contact = TRUE
	TEST_ASSERT_EQUAL(length(mission.get_work_biomes(tables)), 1, "Scheduled empty-site generation lost the repeatable biome pool")
	mission.create_field_contact = FALSE
	var/datum/mission_target/coords/coords = allocate(__IMPLIED_TYPE__, mission)
	coords.zone_weights = list("2" = 1, "3" = 1)
	TEST_ASSERT_NULL(coords.pick_zone_band(), "Coordinate target fell back from an unavailable band")
	var/obj/structure/overmap/trader_outpost/post = allocate(__IMPLIED_TYPE__, red)
	var/datum/mission_target/outpost/courier = allocate(__IMPLIED_TYPE__, mission)
	TEST_ASSERT(!courier.resolve(), "Courier destination fell back to a denied band")
	// Keep fixture locals alive through the assertions; cleanup must not touch real sites.
	TEST_ASSERT(red_ruin && red_planet && post, "Mixed-band fixtures disappeared")

/// Factory output stays unloaded and uses only ordinary repeatable content in the pinned band.
/datum/unit_test/voidcrew_zone_missions/field_contacts
	var/turf/destination
	var/original_type

/datum/unit_test/voidcrew_zone_missions/field_contacts/Destroy()
	. = ..()
	if(destination)
		destination.ChangeTurf(original_type)

/datum/unit_test/voidcrew_zone_missions/field_contacts/Run()
	original_type = run_loc_floor_bottom_left.type
	destination = run_loc_floor_bottom_left.ChangeTurf(/turf/open/overmap)
	var/turf/open/overmap/tile = destination
	tile.current_zone = allocate(/datum/overmap_zone, 2)
	var/datum/controller/subsystem/overmap/zone_missions_test/controller = allocate(__IMPLIED_TYPE__)
	controller.capacity = TRUE
	controller.destination = destination
	var/obj/structure/overmap/planet/planet = controller.spawn_mission_planet(2, /datum/overmap/planet/lava)
	TEST_ASSERT_NOTNULL(planet, "An empty eligible planet pool could not create a contact")
	allocated += planet
	TEST_ASSERT_EQUAL(planet.zone_band, 2, "Field planet escaped its band")
	TEST_ASSERT(!planet.loaded && !planet.mapzone && !planet.footprint, "Offer generation loaded a planet interior")
	// Use the production registry: the old synthetic duplicate-enabled template hid an empty pool.
	var/list/approved = list()
	TEST_ASSERT_EQUAL(length(controller.mission_ruin_templates), 3, "The approved ordinary combat ruin list changed")
	for(var/datum/map_template/ruin/space/template_type as anything in controller.mission_ruin_templates)
		var/datum/map_template/ruin/space/template = SSmapping.space_ruins_templates[initial(template_type.name)]
		TEST_ASSERT_NOTNULL(template, "Approved ruin [template_type] is absent from the production registry")
		TEST_ASSERT_EQUAL(template.type, template_type, "Approved ruin resolved to a different template")
		TEST_ASSERT(!template.unpickable && !template.allow_duplicates, "Mission approval changed natural seeding or selected unique content")
		TEST_ASSERT(template.width > 0 && template.height > 0 && fexists(template.mappath), "Approved ruin has no production map")
		TEST_ASSERT(controller.ruin_fits_in_level(template), "Approved ruin cannot be docked")
		approved += template
		// Every approved template is already in use; mission replacement must still be allowed.
		var/obj/structure/overmap/space_ruin/existing = allocate(__IMPLIED_TYPE__, destination)
		existing.set_ruin_template(template)
		existing.mission_claims = 1
	var/obj/structure/overmap/space_ruin/ruin = controller.spawn_mission_ruin(2)
	TEST_ASSERT_NOTNULL(ruin, "An empty eligible ruin pool could not create a contact")
	allocated += ruin
	TEST_ASSERT(ruin.ruin_template in approved, "A field contact reused unapproved, chart or unique content")
	TEST_ASSERT(!ruin.loaded && !ruin.mapzone && !ruin.footprint, "Offer generation loaded a ruin interior")
	TEST_ASSERT_EQUAL(SSovermap_zones.get_zone_type(get_turf(ruin)), 2, "Field ruin escaped its pinned band")

#endif
