#ifndef VOIDCREW_MISSION_CONSOLE_REWARDS_TESTS
#define VOIDCREW_MISSION_CONSOLE_REWARDS_TESTS

// Included before and after the fork defines; literals below name their corresponding constants.
/datum/mission/m2_rewards_test/generate_mission_details()

/datum/mission/recovery/kill/m2_rewards_test
	weight = 0

/datum/mission/recovery/kill/m2_rewards_test/generate_mission_details()

/datum/mission/recovery/kill/outpost/m2_rewards_test/generate_mission_details()

/obj/structure/overmap/ship/m2_rewards_test
	var/prize_rolls = 0
	var/prize_category = "suit"

/obj/structure/overmap/ship/m2_rewards_test/roll_mission_prize(zone)
	prize_rolls++
	return prize_category

/datum/mission_target/m2_rewards_test
	var/resolved_zone = 1 // ZONE_GREEN

/datum/mission_target/m2_rewards_test/resolve()
	return TRUE

/datum/mission_target/m2_rewards_test/get_zone_type()
	return resolved_zone

/obj/item/stack/spice_pods/m2_rewards_test

/datum/unit_test/voidcrew_m2_rewards
	abstract_type = /datum/unit_test/voidcrew_m2_rewards
	var/old_accepting
	var/list/old_pending
	var/list/old_tallies
	var/list/old_types

/datum/unit_test/voidcrew_m2_rewards/New()
	. = ..()
	old_accepting = SSmetrics.accepting
	old_pending = SSmetrics.pending
	old_tallies = SSmetrics.tallies
	old_types = SSmissions.mission_types
	SSmetrics.accepting = FALSE
	SSmetrics.pending = list()
	SSmetrics.tallies = list()

/datum/unit_test/voidcrew_m2_rewards/Destroy()
	SSmetrics.accepting = old_accepting
	SSmetrics.pending = old_pending
	SSmetrics.tallies = old_tallies
	SSmissions.mission_types = old_types
	return ..()

/datum/unit_test/voidcrew_m2_rewards/proc/test_ship()
	var/obj/structure/overmap/ship/m2_rewards_test/ship = allocate(/obj/structure/overmap/ship/m2_rewards_test)
	ship.ship_team = allocate(/datum/team/voidcrew)
	ship.ship_team.ship = ship
	allocated += ship.get_crew_record()
	ship.ship_account = allocate(/datum/bank_account)
	return ship

/// All targeted base bands, one scaling pass, and the independent research factors.
/datum/unit_test/voidcrew_m2_rewards/bands/Run()
	var/list/bands = list(
		/datum/mission/exploration = list(150, 250),
		/datum/mission/recovery = list(450, 650),
		/datum/mission/recovery/kill = list(500, 700),
		/datum/mission/recovery/survey = list(550, 750),
		/datum/mission/recovery/extraction = list(500, 700),
		/datum/mission/field_expedition = list(500, 700),
		/datum/mission/rescue = list(650, 850),
		/datum/mission/prospect_stake = list(1400, 1800),
		/datum/mission/research/containment = list(350, 550),
		/datum/mission/research/core_sample = list(300, 450),
		/datum/mission/big_game_hunt = list(650, 850),
		/datum/mission/live_capture = list(600, 800),
		/datum/mission/poacher_bust = list(600, 800),
	)
	var/list/multipliers = list(1, 1.5, 2.2)
	var/list/research_multipliers = list(1, 1.4, 1.8)
	for(var/datum/mission/mission_type as anything in bands)
		var/list/band = bands[mission_type]
		TEST_ASSERT_EQUAL(initial(mission_type.value_min), band[1], "[mission_type] has the wrong base minimum")
		TEST_ASSERT_EQUAL(initial(mission_type.value_max), band[2], "[mission_type] has the wrong base maximum")
		for(var/zone in 1 to 3) // ZONE_GREEN/YELLOW/RED
			var/datum/mission/mission = allocate(/datum/mission/m2_rewards_test)
			mission.target = allocate(/datum/mission_target/m2_rewards_test, mission)
			mission.value_min = band[1]
			mission.value_max = band[2]
			mission.research_reward = 500
			mission.apply_zone_scaling(zone)
			TEST_ASSERT_EQUAL(mission.value_min, round(band[1] * multipliers[zone], 10), "Wrong scaled minimum")
			TEST_ASSERT_EQUAL(mission.value_max, round(band[2] * multipliers[zone], 10), "Wrong scaled maximum")
			TEST_ASSERT_EQUAL(mission.research_reward, round(500 * research_multipliers[zone], 10), "Research used the credit factor")
			var/quoted = mission.value_max
			mission.apply_zone_scaling(zone)
			TEST_ASSERT_EQUAL(mission.value_max, quoted, "Scaling applied twice")
			TEST_ASSERT_EQUAL(mission.voucher_count, 0, "Scaling invented a red voucher")
	var/datum/mission/suppression/sweep = allocate(/datum/mission/suppression)
	var/lo = sweep.quote_zone == 3 ? 1100 : 700
	var/hi = sweep.quote_zone == 3 ? 1500 : 1000
	TEST_ASSERT(sweep.value >= lo && sweep.value <= hi, "Suppression must remain flat in its quoted band")
	TEST_ASSERT(sweep.voucher_count in list(0, 1), "Suppression pays at most one ordinary voucher")
	var/datum/mission/rescue/rescue_type = /datum/mission/rescue
	TEST_ASSERT_EQUAL(initial(rescue_type.voucher_count), 0, "Rescue still guarantees vouchers")

/// Verify every delivery row and accept stored goods, including account loss before partial delivery.
/datum/unit_test/voidcrew_m2_rewards/deliveries/Run()
	var/datum/mission/delivery/catalog = allocate(/datum/mission/delivery)
	var/list/expected = list(
		/obj/item/stack/spice_pods = list(3, 1, 320, 400),
		/obj/item/stack/sheet/sinew = list(2, 1, 260, 340),
		/obj/item/stack/sheet/animalhide/goliath_hide = list(2, 2, 400, 550),
		/obj/item/stack/glacial_core = list(3, 2, 550, 700),
		/obj/item/stack/telecrystal_raw = list(5, 3, 1500, 1700),
		/obj/item/sea_crystal = list(1, 3, 1000, 1200),
		/obj/item/documents/syndicate = list(1, 3, 3000, 3300),
	)
	TEST_ASSERT_EQUAL(catalog.weight, 10, "Delivery suspension was not lifted")
	TEST_ASSERT_EQUAL(length(catalog.delivery_asks), length(expected), "Delivery catalog has extra or missing rows")
	var/obj/structure/overmap/ship/ship = test_ship()
	for(var/list/row as anything in catalog.delivery_asks)
		var/list/wanted = expected[row["type"]]
		TEST_ASSERT_NOTNULL(wanted, "Delivery asks for an unapproved item")
		TEST_ASSERT_EQUAL(row["amount"], wanted[1], "Delivery quantity changed")
		TEST_ASSERT_EQUAL(row["difficulty"], wanted[2], "Delivery difficulty changed")
		TEST_ASSERT_EQUAL(row["value_min"], wanted[3], "Wrong delivery minimum")
		TEST_ASSERT_EQUAL(row["value_max"], wanted[4], "Wrong delivery maximum")
		var/datum/mission/mission = allocate(/datum/mission/m2_rewards_test)
		mission.value_min = row["value_min"]
		mission.value_max = row["value_max"]
		var/datum/mission_objective/deliver/console/ask = new
		ask.required_type = row["type"]
		ask.required_amount = row["amount"]
		mission.add_objective(ask)
		mission.requires_item = TRUE
		TEST_ASSERT(mission.start_mission(ship), "Stored-goods delivery did not start")
		var/obj/item/item
		if(ispath(ask.required_type, /obj/item/stack))
			item = allocate(ask.required_type, run_loc_floor_bottom_left, ask.required_amount + 2, FALSE)
		else
			item = allocate(ask.required_type)
		TEST_ASSERT(mission.turn_in(run_loc_floor_bottom_left, item), "Stored qualifying goods were refused")
		if(isstack(item))
			var/obj/item/stack/left = item
			TEST_ASSERT_EQUAL(left.amount, 2, "Delivery consumed excess goods")
		TEST_ASSERT(!mission.turn_in(run_loc_floor_bottom_left, item), "Stale hand-in paid twice")
	var/datum/mission/delivery/flat = allocate(/datum/mission/delivery, null, null, 3)
	var/list/flat_row
	for(var/list/row as anything in flat.delivery_asks)
		if(row["type"] == flat.required_type)
			flat_row = row
	TEST_ASSERT_EQUAL(flat.value_min, flat_row["value_min"], "Red scaled a flat delivery")
	TEST_ASSERT_EQUAL(flat.difficulty, flat_row["difficulty"], "Red replaced ask difficulty")
	TEST_ASSERT_EQUAL(flat.voucher_count, 0, "Delivery gained a voucher")
	var/datum/mission/partial = allocate(/datum/mission/m2_rewards_test)
	var/datum/mission_objective/deliver/ask = new
	ask.required_type = /obj/item/sea_crystal
	ask.required_amount = 2
	partial.add_objective(ask)
	partial.requires_item = TRUE
	partial.start_mission(ship)
	var/obj/item/first = allocate(/obj/item/sea_crystal)
	var/obj/item/second = allocate(/obj/item/sea_crystal)
	var/datum/bank_account/account = ship.ship_account
	ship.ship_account = null
	TEST_ASSERT(!partial.turn_in(run_loc_floor_bottom_left, first), "Accountless partial delivery succeeded")
	TEST_ASSERT(!QDELETED(first) && !ask.delivered_count, "Rejected delivery consumed goods")
	ship.ship_account = account
	TEST_ASSERT(partial.turn_in(run_loc_floor_bottom_left, first), "Valid partial delivery failed")
	TEST_ASSERT(!partial.turn_in(run_loc_floor_bottom_left, first), "Consumed partial item counted twice")
	ship.ship_account = null
	TEST_ASSERT(!partial.turn_in(run_loc_floor_bottom_left, second), "Accountless final delivery succeeded")
	TEST_ASSERT(!QDELETED(second), "Rejected final delivery consumed goods")
	ship.ship_account = account
	TEST_ASSERT(partial.turn_in(run_loc_floor_bottom_left, second), "Final delivery failed after account recovery")
	var/datum/mission_objective/deliver/console/exact = allocate(/datum/mission_objective/deliver/console)
	exact.required_type = /obj/item/stack/spice_pods
	var/obj/item/descendant = allocate(/obj/item/stack/spice_pods/m2_rewards_test)
	TEST_ASSERT(!exact.can_turn_in(descendant), "A descendant bypassed the exact goods path")

/// Fixed sets survive acceptance, failure, deletion and rebuilding until the scheduled refresh.
/datum/unit_test/voidcrew_m2_rewards/offers/Run()
	SSmissions.mission_types = list(/datum/mission/delivery)
	var/obj/structure/overmap/ship/ship = test_ship()
	TEST_ASSERT(SSmissions.refresh_ship_missions(ship), "Initial offer set was not posted")
	TEST_ASSERT_EQUAL(length(ship.available_missions), 5, "Initial board does not contain five offers")
	TEST_ASSERT_EQUAL(ship.next_mission_refresh, world.time + 20 MINUTES, "Offer timer is not twenty minutes")
	var/datum/mission/taken = ship.available_missions[1]
	TEST_ASSERT(taken.start_mission(ship), "Offer could not be accepted")
	taken.fail("Abandoned.")
	var/datum/mission/destroyed = ship.available_missions[1]
	ship.available_missions -= destroyed
	qdel(destroyed)
	var/datum/mission/retained = ship.available_missions[1]
	var/refresh_at = ship.next_mission_refresh
	var/obj/machinery/computer/mission_board/console = allocate(/obj/machinery/computer/mission_board)
	qdel(console)
	console = allocate(/obj/machinery/computer/mission_board)
	TEST_ASSERT(!SSmissions.force_refresh_ship_missions(ship), "Manual refresh bypassed the schedule")
	TEST_ASSERT_EQUAL(length(ship.available_missions), 3, "Vacancies refilled before the timer")
	TEST_ASSERT(retained in ship.available_missions, "Rebuilding or failing an offer rerolled the set")
	TEST_ASSERT_EQUAL(ship.next_mission_refresh, refresh_at, "A console reset the ship timer")
	ship.next_mission_refresh = world.time
	TEST_ASSERT(SSmissions.refresh_ship_missions(ship), "Scheduled refresh did not run")
	TEST_ASSERT(QDELETED(retained), "Scheduled refresh retained an old offer")
	TEST_ASSERT_EQUAL(length(ship.available_missions), 5, "Scheduled refresh failed to replace the full set")
	var/datum/mission/quoted = allocate(/datum/mission/m2_rewards_test)
	var/datum/mission_target/m2_rewards_test/target = allocate(/datum/mission_target/m2_rewards_test, quoted)
	quoted.target = target
	quoted.quote_zone = 1
	target.resolved_zone = 2
	TEST_ASSERT(!quoted.resolve_quoted_target(), "Retarget escaped the quoted band")
	target.resolved_zone = 1
	TEST_ASSERT(quoted.resolve_quoted_target(), "Same-band retarget failed")

/// Every scan/gas row and all six utility cells retain ask difficulty independently of zone.
/datum/unit_test/voidcrew_m2_rewards/asks/Run()
	var/datum/mission/survey/survey = allocate(/datum/mission/survey)
	var/list/survey_rows = list(
		list("any", 3, 100, 160, 1), list("nebulas", 2, 80, 120, 1), list("asteroids", 2, 100, 160, 1),
		list("planets", 2, 180, 260, 2), list("electric_storms", 2, 160, 240, 2), list("space_ruins", 2, 180, 260, 2),
		list("stars", 1, 160, 240, 3), list("emp_storms", 2, 240, 360, 3), list("planets", 4, 320, 440, 3),
	)
	var/datum/mission/research/telemetry/telemetry = allocate(/datum/mission/research/telemetry)
	TEST_ASSERT(!telemetry.generation_failed, "Telemetry generation failed")
	var/list/telemetry_rows = list(
		list("nebulas", 2, 60, 100, 1), list("asteroids", 2, 60, 100, 1), list("any", 3, 80, 120, 1),
		list("planets", 2, 100, 160, 2), list("space_ruins", 2, 100, 160, 2), list("electric_storms", 2, 100, 160, 2),
		list("emp_storms", 2, 160, 240, 3), list("stars", 1, 100, 160, 3),
	)
	check_asks(survey.survey_targets, survey_rows)
	check_asks(telemetry.telemetry_asks, telemetry_rows)
	var/list/medium = list(
		list(/obj/item/gps, /obj/item/extraction_pack),
		list(/obj/item/t_scanner/adv_mining_scanner, /obj/item/analyzer/ranged),
		list(/obj/item/clothing/glasses/meson/night, /obj/item/inducer/orderable),
	)
	var/list/hard = list(
		list(/obj/item/t_scanner/adv_mining_scanner, /obj/item/survivalcapsule),
		list(/obj/item/healthanalyzer/advanced, /obj/item/tank/jetpack/oxygen),
		list(/obj/item/construction/rcd, /obj/item/survivalcapsule),
	)
	var/list/multipliers = list(1, 1.5, 2.2)
	for(var/zone in 1 to 3)
		for(var/ask_difficulty in 2 to 3)
			survey.quote_zone = zone
			survey.difficulty = ask_difficulty
			var/list/pool = survey.get_utility_pool()
			var/list/wanted = ask_difficulty == 3 ? hard[zone] : medium[zone]
			TEST_ASSERT_EQUAL(length(pool), 2, "Utility cell must have exactly two equal choices")
			TEST_ASSERT_EQUAL(length(pool & wanted), 2, "Wrong utility pool for zone and difficulty")
		var/datum/mission/survey/posted = allocate(/datum/mission/survey, null, null, zone)
		var/list/ask = matching_ask(posted.survey_targets, posted.target_type, posted.required_amount)
		TEST_ASSERT_EQUAL(posted.value_min, round(ask["value_min"] * multipliers[zone], 10), "Survey scaling preceded the ask roll")
		TEST_ASSERT_EQUAL(posted.difficulty, ask["difficulty"], "Survey lost its ask difficulty")
		var/prize = posted.mission_reward
		var/fee = posted.value
		posted.update_text()
		posted.apply_zone_scaling(1)
		TEST_ASSERT_EQUAL(posted.mission_reward, prize, "Reopening changed utility")
		TEST_ASSERT_EQUAL(posted.value, fee, "Moving changed the posted quote")
		var/datum/mission/research/telemetry/science = allocate(/datum/mission/research/telemetry, null, null, zone)
		ask = matching_ask(science.telemetry_asks, science.target_type, science.required_amount)
		TEST_ASSERT_EQUAL(science.value_max, round(ask["value_max"] * multipliers[zone], 10), "Telemetry credits did not scale after details")
		var/list/research_mult = list(1, 1.4, 1.8)
		TEST_ASSERT_EQUAL(science.research_reward, round(ask["research"] * research_mult[zone], 10), "Telemetry research lost its separate factor")
	var/datum/mission/gas_harvest/gas = allocate(/datum/mission/gas_harvest)
	TEST_ASSERT(!gas.generation_failed, "Gas fallback generation failed")
	var/list/gas_rows = list(
		/datum/gas/plasma = list(600, 900, 250, 350, 1, 0),
		/datum/gas/nitrogen = list(600, 900, 220, 320, 1, 0),
		/datum/gas/water_vapor = list(600, 900, 220, 320, 1, 0),
		/datum/gas/miasma = list(400, 700, 300, 450, 2, 0),
		/datum/gas/tritium = list(250, 450, 450, 650, 2, 1),
		/datum/gas/pluoxium = list(200, 350, 650, 850, 3, 1),
		/datum/gas/nitrium = list(200, 350, 650, 850, 3, 1),
		/datum/gas/hypernoblium = list(150, 300, 750, 950, 3, 1),
	)
	TEST_ASSERT_EQUAL(length(gas.gas_asks), 8, "Gas catalog changed size")
	for(var/gas_type in gas.gas_asks)
		var/list/ask = gas.gas_asks[gas_type]
		var/list/wanted = gas_rows[gas_type]
		TEST_ASSERT_NOTNULL(wanted, "Unapproved gas row")
		TEST_ASSERT_EQUAL(ask["moles"][1], wanted[1], "Gas minimum quantity changed")
		TEST_ASSERT_EQUAL(ask["moles"][2], wanted[2], "Gas maximum quantity changed")
		TEST_ASSERT_EQUAL(ask["value"][1], wanted[3], "Wrong gas minimum")
		TEST_ASSERT_EQUAL(ask["value"][2], wanted[4], "Wrong gas maximum")
		TEST_ASSERT_EQUAL(ask["difficulty"], wanted[5], "Gas ask difficulty changed")
		TEST_ASSERT_EQUAL(ask["vouchers"], wanted[6], "Gas voucher count changed")
	for(var/zone in 1 to 3)
		var/datum/mission/gas_harvest/posted = allocate(/datum/mission/gas_harvest, null, null, zone)
		var/list/ask = posted.gas_asks[posted.gas_type]
		TEST_ASSERT_EQUAL(posted.value_max, round(ask["value"][2] * multipliers[zone], 10), "Gas quote did not use the posting zone")
		TEST_ASSERT_EQUAL(posted.voucher_count, ask["vouchers"], "Gas gained an extra zone voucher")

/datum/unit_test/voidcrew_m2_rewards/asks/proc/matching_ask(list/rows, object_type, amount)
	for(var/list/row as anything in rows)
		if(row["type"] == object_type && row["amount"] == amount)
			return row

/datum/unit_test/voidcrew_m2_rewards/asks/proc/check_asks(list/rows, list/expected)
	TEST_ASSERT_EQUAL(length(rows), length(expected), "Scan ask catalog changed size")
	for(var/index in 1 to length(expected))
		var/list/row = rows[index]
		var/list/wanted = expected[index]
		TEST_ASSERT_EQUAL(row["type"], wanted[1], "Wrong scan object")
		TEST_ASSERT_EQUAL(row["amount"], wanted[2], "Scan quota changed")
		TEST_ASSERT_EQUAL(row["value_min"], wanted[3], "Wrong scan minimum")
		TEST_ASSERT_EQUAL(row["value_max"], wanted[4], "Wrong scan maximum")
		TEST_ASSERT_EQUAL(row["difficulty"], wanted[5], "Scan difficulty changed")

/// Exact disjoint odds, all seven green prizes, shared caps, and one completion roll.
/datum/unit_test/voidcrew_m2_rewards/prizes/Run()
	var/list/suits = list(30, 40, 200)
	var/list/gadgets = list(15, 20, 100)
	for(var/zone in 1 to 3)
		var/suit_count = 0
		var/gadget_count = 0
		for(var/roll in 1 to 1000)
			var/outcome = mission_prize_outcome(zone, roll)
			suit_count += outcome == "suit"
			gadget_count += outcome == "gadget"
		TEST_ASSERT_EQUAL(suit_count, suits[zone], "Wrong suit chance")
		TEST_ASSERT_EQUAL(gadget_count, gadgets[zone], "Wrong gadget chance")
	var/list/green_prizes = list()
	for(var/family in list("kill", "hunt", "poacher", "capture", "waves"))
		green_prizes |= mission_prize_pool(family, "suit")
		green_prizes |= mission_prize_pool(family, "gadget")
	TEST_ASSERT_EQUAL(length(green_prizes), 7, "Green work cannot reach all seven named prizes")
	var/obj/structure/overmap/ship/m2_rewards_test/ship = test_ship()
	for(var/mission_type in list(/datum/mission/recovery/kill/m2_rewards_test, /datum/mission/recovery/kill/outpost/m2_rewards_test))
		var/datum/mission/mission = allocate(mission_type)
		mission.quote_zone = 1
		mission.value = 600
		mission.voucher_count = 1
		mission.start_mission(ship)
		var/before = ship.ship_account.account_balance
		TEST_ASSERT(mission.turn_in(run_loc_floor_bottom_left), "Completed guarded work failed")
		TEST_ASSERT_EQUAL(ship.ship_account.account_balance - before, 600, "Prize replaced ordinary credits")
		TEST_ASSERT(!mission.turn_in(run_loc_floor_bottom_left), "A stale completion succeeded")
		mission.finish_mission(run_loc_floor_bottom_left)
	TEST_ASSERT_EQUAL(ship.prize_rolls, 2, "Each completion must roll once, including outpost kills")
	TEST_ASSERT(ship.mission_suit_paid && !ship.mission_gadget_paid, "Capped suit rerolled into a gadget")
	TEST_ASSERT_EQUAL(length(run_loc_floor_bottom_left.get_all_contents_type(/obj/item/mod/control/pre_equipped/traitor_elite)), 1, "Suit cap allowed a duplicate")
	ship.prize_category = "gadget"
	TEST_ASSERT_EQUAL(ship.award_guarded_prize("kill", 1, run_loc_floor_bottom_left), /obj/item/gun/energy/laser/captain, "Suit cap blocked the separate gadget")
	TEST_ASSERT_NULL(ship.award_guarded_prize("hunt", 3, run_loc_floor_bottom_left), "A different family bypassed the gadget cap")
	var/rolls_before = ship.prize_rolls
	var/datum/mission/failed = allocate(/datum/mission/recovery/kill/m2_rewards_test)
	failed.start_mission(ship)
	failed.fail("Abandoned.")
	TEST_ASSERT_EQUAL(ship.prize_rolls, rolls_before, "Failed work rolled a prize")
	TEST_ASSERT_NULL(ship.award_guarded_prize("stake", 1, run_loc_floor_bottom_left), "Green stake became eligible")
	TEST_ASSERT_NULL(mission_prize_pool("suppression", "suit"), "Suppression gained a prize pool")
	TEST_ASSERT_NULL(mission_prize_pool("expedition", "suit"), "Expedition ambush gained a prize pool")
	var/list/families = list(
		/datum/mission/recovery/kill = "kill", /datum/mission/recovery/kill/outpost = "kill",
		/datum/mission/big_game_hunt = "hunt", /datum/mission/live_capture = "capture", /datum/mission/poacher_bust = "poacher",
		/datum/mission/recovery/survey = "waves", /datum/mission/recovery/extraction = "waves", /datum/mission/research/core_sample = "waves",
		/datum/mission/prospect_stake = "stake",
	)
	for(var/datum/mission/mission_type as anything in families)
		TEST_ASSERT_EQUAL(initial(mission_type.guarded_prize_family), families[mission_type], "Mission has the wrong guarded prize family")

/// Lair claims use the same flags after the existing atomic bounty completion.
/datum/unit_test/voidcrew_m2_rewards/lair/Run()
	var/obj/structure/overmap/ship/m2_rewards_test/ship = test_ship()
	var/obj/machinery/mission_pad/pad = allocate(/obj/machinery/mission_pad)
	var/datum/criminal_bounty/kill_only/lair/posting = allocate(/datum/criminal_bounty/kill_only/lair)
	posting.record = bounty_kill_record("Test Boss", "testing", MALE, 5000, "test")
	posting.value = 5000
	posting.board_vouchers = 3
	posting.board_zone = 2 // ZONE_YELLOW
	var/obj/item/bounty_proof/trophy/proof = allocate(/obj/item/bounty_proof/trophy)
	posting.kill_bind_trophy(proof)
	var/before = ship.ship_account.account_balance
	TEST_ASSERT(islist(posting.board_claim(ship, pad, proof, "dead")), "Lair trophy claim failed")
	TEST_ASSERT_EQUAL(ship.ship_account.account_balance - before, 5000, "Lair pay changed")
	TEST_ASSERT_EQUAL(ship.prize_rolls, 1, "Successful lair must roll one prize")
	TEST_ASSERT(ship.mission_suit_paid, "Lair did not claim the hull's suit flag")
	TEST_ASSERT(!islist(posting.board_claim(ship, pad, proof, "dead")), "Closed lair paid twice")
	TEST_ASSERT_EQUAL(ship.prize_rolls, 1, "Closed lair rolled again")

/// Chip amounts on both mission surfaces remain separate from the completion fee.
/datum/unit_test/voidcrew_m2_rewards/chips/Run()
	var/datum/mission/recovery/kill/kill_type = allocate(/datum/mission/recovery/kill/m2_rewards_test)
	TEST_ASSERT_EQUAL(kill_type.guarded_prize_family, "kill", "Kill fixture lost its production prize family")
	var/easy_cash = 0
	for(var/mob/living/basic/trooper/pirate/faction/pirate_type as anything in kill_type.easy_targets)
		easy_cash += initial(pirate_type.plunder_credits)
	TEST_ASSERT_EQUAL(easy_cash / length(kill_type.easy_targets), 300, "Wrong green kill-chip expectation")
	var/medium_cash = 0
	for(var/mob/living/basic/trooper/pirate/faction/pirate_type as anything in kill_type.medium_targets)
		medium_cash += initial(pirate_type.plunder_credits)
	TEST_ASSERT_EQUAL(medium_cash / length(kill_type.medium_targets) + 300, 568.75, "Wrong yellow kill-chip expectation")
	for(var/mob/living/basic/trooper/pirate/faction/pirate_type as anything in kill_type.hard_targets)
		TEST_ASSERT_EQUAL(initial(pirate_type.plunder_credits) + 2 * 25, 3050, "Wrong red kill-chip expectation")
	var/mob/living/basic/trooper/pirate/faction/medieval/captain/captain_type = /mob/living/basic/trooper/pirate/faction/medieval/captain
	TEST_ASSERT_EQUAL(initial(captain_type.plunder_credits), 1000, "Medieval captain kept its melee chip value")

/// Rewinding and reviving a kill still yields one chip, one settlement and one prize roll.
/datum/unit_test/voidcrew_m2_rewards/rewind/Run()
	var/obj/structure/overmap/ship/m2_rewards_test/ship = test_ship()
	var/datum/mission/recovery/kill/m2_rewards_test/mission = allocate(/datum/mission/recovery/kill/m2_rewards_test)
	mission.objective_name = "Testbeard"
	mission.quote_zone = 1
	mission.value = 600
	mission.requires_item = TRUE
	var/datum/mission_target/kill_rewind_test/target = allocate(/datum/mission_target/kill_rewind_test, mission)
	target.spawn_turf = run_loc_floor_top_right
	mission.target = target
	var/datum/mission_objective/field/kill_named/hunt = new
	hunt.target_mob_type = /mob/living/basic/trooper/pirate/faction/boss/mission_rewind_test
	mission.add_objective(hunt)
	mission.add_objective(new /datum/mission_objective/deliver/bound/proof)
	TEST_ASSERT(mission.start_mission(ship), "Rewind hunt did not start")
	var/datum/mission_work_receipt/receipt = mission.work_receipt
	var/mob/living/basic/trooper/pirate/faction/boss/mission_rewind_test/boss = hunt.target_mob
	TEST_ASSERT_NOTNULL(boss, "Rewind fixture did not spawn its boss")
	boss.death(FALSE)
	TEST_ASSERT(mission.named_kill_completed && mission.boss_cash_issued, "Initial kill did not preserve S06 flags")
	TEST_ASSERT(boss.revive(ADMIN_HEAL_ALL), "Test boss could not revive")
	boss.death(FALSE)
	for(var/rewind in 1 to 2)
		var/obj/item/mission_recovery/old_proof = mission.quest_atom
		target.interior_loaded = FALSE
		mission.on_target_interior_unloaded()
		qdel(old_proof)
		target.interior_loaded = TRUE
		mission.on_target_interior_loaded()
		TEST_ASSERT(mission.can_turn_in(mission.quest_atom), "Rewind lost proof recovery")
		TEST_ASSERT_EQUAL(mission.work_receipt, receipt, "Rewind replaced the progression receipt")
		TEST_ASSERT_NULL(hunt.target_mob, "Completed kill respawned a boss")
	TEST_ASSERT_EQUAL(length(run_loc_floor_top_right.get_all_contents_type(/obj/item/holochip)), 1, "Rewind or revival issued another boss chip")
	var/before = ship.ship_account.account_balance
	TEST_ASSERT(mission.turn_in(run_loc_floor_bottom_left, mission.quest_atom), "Recovered proof did not settle")
	TEST_ASSERT(receipt.claimed && receipt.credited == 1, "Recovered proof did not claim exactly one green contribution")
	TEST_ASSERT_EQUAL(ship.ship_account.account_balance - before, 600, "Recovered proof paid the wrong fee")
	TEST_ASSERT_EQUAL(ship.prize_rolls, 1, "Recovered proof must make exactly one completion roll")
	TEST_ASSERT(!mission.turn_in(run_loc_floor_bottom_left, null, TRUE), "Repeated proof settlement succeeded")
	mission.finish_mission(run_loc_floor_bottom_left)
	TEST_ASSERT_EQUAL(ship.prize_rolls, 1, "Stale completion rolled another prize")
	TEST_ASSERT_EQUAL(ship.ship_account.account_balance - before, 600, "Stale completion paid another fee")

/// Named prizes record the receiving hull, quote zone, value and first-suit time.
/datum/unit_test/voidcrew_m2_rewards/prize_metrics/Run()
	SSmetrics.accepting = TRUE
	var/obj/structure/overmap/ship/m2_rewards_test/ship = test_ship()
	ship.award_guarded_prize("kill", 1, run_loc_floor_bottom_left, /datum/mission/recovery/kill)
	TEST_ASSERT_EQUAL(length(SSmetrics.pending), 1, "A suit should write one prize row")
	var/list/row = SSmetrics.pending[1]
	TEST_ASSERT_EQUAL(row["event"], "guarded_prize_paid", "Wrong prize event")
	TEST_ASSERT_EQUAL(row["zone"], "green", "Prize metric lost its quote zone")
	var/list/details = json_decode(row["details"])
	TEST_ASSERT_EQUAL(details["item_value"], 9000, "Wrong suit value")
	TEST_ASSERT_EQUAL(details["first_suit_s"], ship.mission_first_suit_seconds, "First suit time was not recorded")
	ship.award_guarded_prize("kill", 3, run_loc_floor_bottom_left)
	TEST_ASSERT_EQUAL(length(SSmetrics.pending), 1, "A capped outcome wrote another prize payment")

#endif
