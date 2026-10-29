/**
 * # Mission wiring and contract caps
 *
 * Two things: the shape of the 21-type contract table (which will keep
 * growing), and the type cap.
 *
 * `mission_limit` used to be enforced only where offers are *generated*. Boards
 * can hold more copies of a capped contract than the cap allows, the
 * generation roll only counts live missions, so N ships could each accept the
 * same "limit 1" job and all run it at once. The cap has to hold at accept
 * time too, which is what mission_type_within_limit(type, excluding) exists
 * for; `excluding` is how an offer being accepted avoids counting against its
 * own cap.
 */

/**
 * Test-only capped contract.
 *
 * weight 0 keeps it out of SSmissions' generation pool (Initialize only
 * collects types with weight > 0), and the generation override keeps it from
 * reaching for an overmap that a CIBUILDING world, which boots MetaStation,
 * does not have.
 */
/datum/mission/unit_test_capped
	name = "Unit Test Capped Contract"
	desc = "Exists only for /datum/unit_test/voidcrew_mission_type_limit."
	weight = 0
	mission_limit = 1

/datum/mission/unit_test_capped/generate_mission_details()
	return

/datum/unit_test/voidcrew_mission_type_limit

/datum/unit_test/voidcrew_mission_type_limit/Run()
	var/list/saved_active = SSmissions.all_active_missions.Copy()
	SSmissions.all_active_missions.Cut()

	var/datum/mission/first = new /datum/mission/unit_test_capped()
	var/datum/mission/second = new /datum/mission/unit_test_capped()

	TEST_ASSERT(mission_type_within_limit(/datum/mission/unit_test_capped, first), "a limit-1 contract was refused with nothing of its type running")

	SSmissions.all_active_missions += first
	first.active = TRUE
	TEST_ASSERT(!mission_type_within_limit(/datum/mission/unit_test_capped, second), "a limit-1 contract was still 'within limit' with one already running, so a second ship can accept the same capped job. Boards hold more copies than the cap allows, so the cap has to hold at accept time (see /obj/structure/overmap/ship/proc/accept_mission).")
	TEST_ASSERT(mission_type_within_limit(/datum/mission/unit_test_capped, first), "the running mission counted against its own cap, accept_mission passes the mission being accepted as `excluding` for exactly this reason")

	SSmissions.all_active_missions -= first
	first.active = FALSE
	TEST_ASSERT(mission_type_within_limit(/datum/mission/unit_test_capped, second), "the cap did not free up after the running mission ended")

	// mission_limit 0 means uncapped, not "capped at zero"
	TEST_ASSERT(mission_type_within_limit(/datum/mission), "an uncapped mission type (mission_limit 0) was refused")

	qdel(first)
	qdel(second)
	SSmissions.all_active_missions.Cut()
	SSmissions.all_active_missions += saved_active

/datum/unit_test/voidcrew_mission_wiring

/// Pirate quotes retain their variance, loot tier and tracking deduction after the cash cut.
/datum/unit_test/voidcrew_pirate_bounty_pay
	var/turf/open/overmap/overmap_tile
	var/original_turf_type
	var/metrics_were_accepting

/datum/unit_test/voidcrew_pirate_bounty_pay/New()
	. = ..()
	metrics_were_accepting = SSmetrics.accepting
	SSmetrics.accepting = FALSE

/datum/unit_test/voidcrew_pirate_bounty_pay/Destroy()
	if(overmap_tile)
		overmap_tile.current_zone = null
		overmap_tile.ChangeTurf(original_turf_type)
	SSmetrics.accepting = metrics_were_accepting
	return ..()

/datum/unit_test/voidcrew_pirate_bounty_pay/Run()
	original_turf_type = run_loc_floor_bottom_left.type
	overmap_tile = run_loc_floor_bottom_left.ChangeTurf(/turf/open/overmap)
	var/obj/structure/overmap/ship/winner = allocate(/obj/structure/overmap/ship)
	winner.ship_account = allocate(/datum/bank_account)
	// Zone (ZONE_YELLOW/RED), low/base/high quote, tracking fee, tracked payout.
	var/list/cases = list(list(2, 3200, 4000, 4800, 1000, 3000), list(3, 9600, 12000, 14400, 3000, 9000))
	var/list/reward_rolls = list(80, 100, 120)
	for(var/list/pay_case as anything in cases)
		overmap_tile.current_zone = allocate(/datum/overmap_zone, pay_case[1])
		var/obj/structure/overmap/ship/npc/pirate = allocate(/obj/structure/overmap/ship/npc, overmap_tile)
		// Teardown must not refill the live pirate pool.
		pirate.spawner_resolved = TRUE
		var/obj/item/ship_key/key = allocate(/obj/item/ship_key, run_loc_floor_top_right, pirate)
		key.spawner_notified = TRUE
		for(var/tracking in list(FALSE, TRUE))
			var/datum/pirate_bounty/bounty = allocate(/datum/pirate_bounty, pirate, key)
			TEST_ASSERT(bounty.reward >= pay_case[2] && bounty.reward <= pay_case[4], "Generated pirate quote is outside the reduced band")
			TEST_ASSERT_EQUAL(bounty.is_heavy_bounty, pay_case[1] == 3, "The cash cut changed the pirate loot tier")
			for(var/index in 1 to length(reward_rolls))
				TEST_ASSERT_EQUAL(bounty.calculate_reward(pirate, reward_rolls[index]), pay_case[index + 1], "Wrong pirate bounty quote at [reward_rolls[index]]%")
			bounty.reward = bounty.calculate_reward(pirate, 100)
			TEST_ASSERT_EQUAL(bounty.get_tracking_cost(), pay_case[5], "Tracking cost did not follow the reduced quote")
			TEST_ASSERT(bounty.add_claimant(winner), "Could not accept the pirate bounty")
			TEST_ASSERT(bounty.can_turn_in(key, winner), "The matching pirate key was refused")
			if(tracking)
				TEST_ASSERT(bounty.enable_tracking(winner), "Could not enable pirate tracking")
			var/expected_pay = tracking ? pay_case[6] : pay_case[3]
			var/balance_before = winner.ship_account.account_balance
			TEST_ASSERT_EQUAL(bounty.complete(winner, null), expected_pay, "Pirate completion returned the wrong payment")
			TEST_ASSERT_EQUAL(winner.ship_account.account_balance - balance_before, expected_pay, "Pirate completion credited the wrong payment")
			TEST_ASSERT(!bounty.can_turn_in(key, winner), "A completed pirate bounty accepted its key again")
			TEST_ASSERT_EQUAL(bounty.complete(winner, null), 0, "A completed pirate bounty paid twice")
			TEST_ASSERT_EQUAL(winner.ship_account.account_balance - balance_before, expected_pay, "Duplicate completion changed the ship balance")

/// Steal-objective guns exist at spawn; opening any gun cache yields one gun total.
/datum/unit_test/voidcrew_pirate_reward_guns/Run()
	var/list/cache_guns = list(
		/obj/structure/closet/crate/secure/weapon/pirate_loot/lasers = /obj/item/gun/energy/laser,
		/obj/structure/closet/crate/secure/weapon/pirate_loot/disablers = /obj/item/gun/energy/disabler,
		/obj/structure/closet/crate/secure/weapon/pirate_loot/heavy/energy_guns = /obj/item/gun/energy/e_gun,
		/obj/structure/closet/crate/secure/weapon/pirate_loot/heavy/combat_shotguns = /obj/item/gun/energy/laser,
		/obj/structure/closet/crate/secure/weapon/pirate_loot/heavy/laser_carbines = /obj/item/gun/energy/e_gun,
	)
	var/list/immediate_caches = list(
		/obj/structure/closet/crate/secure/weapon/pirate_loot/lasers,
		/obj/structure/closet/crate/secure/weapon/pirate_loot/disablers,
		/obj/structure/closet/crate/secure/weapon/pirate_loot/heavy/energy_guns,
		/obj/structure/closet/crate/secure/weapon/pirate_loot/heavy/combat_shotguns,
		/obj/structure/closet/crate/secure/weapon/pirate_loot/heavy/laser_carbines,
	)
	var/turf/cache_turf = run_loc_floor_bottom_left
	for(var/cache_type in cache_guns)
		var/obj/structure/closet/crate/secure/weapon/pirate_loot/cache = allocate(cache_type, cache_turf)
		var/expected_before = (cache_type in immediate_caches) ? 1 : 0
		TEST_ASSERT_EQUAL(length(cache.get_all_contents_type(/obj/item/gun)), expected_before, "[cache_type] has the wrong gun count before opening")
		TEST_ASSERT_EQUAL(length(cache.get_all_contents_type(cache_guns[cache_type])), expected_before, "[cache_type] has the wrong gun type before opening")
		TEST_ASSERT(!cache.contents_initialized, "[cache_type] must retain lazy population of other contents")
		TEST_ASSERT(cache.open(null, TRUE, FALSE), "[cache_type] could not open")
		TEST_ASSERT_EQUAL(length(cache_turf.get_all_contents_type(/obj/item/gun)), 1, "[cache_type] must contain exactly one gun after opening")
		TEST_ASSERT_EQUAL(length(cache_turf.get_all_contents_type(cache_guns[cache_type])), 1, "[cache_type] must retain its gun type")
		if(cache_type == /obj/structure/closet/crate/secure/weapon/pirate_loot/heavy/combat_shotguns)
			TEST_ASSERT_EQUAL(length(cache_turf.get_all_contents_type(/obj/item/storage/belt/bandolier)), 0, "The replacement laser cache must not retain shotgun bandoliers")
		TEST_ASSERT(cache.close(), "[cache_type] could not close")
		TEST_ASSERT(cache.open(null, TRUE, FALSE), "[cache_type] could not reopen")
		TEST_ASSERT_EQUAL(length(cache_turf.get_all_contents_type(/obj/item/gun)), 1, "Reopening [cache_type] duplicated its gun")
		for(var/atom/movable/drop in cache_turf.contents - cache)
			if(!istype(drop, /obj/effect/landmark))
				qdel(drop)
		qdel(cache)

/// Initial, rebuilt and refilled SolGov inventories cannot recreate the removed sword.
/datum/unit_test/voidcrew_solgov_vendor_stock/Run()
	var/obj/machinery/vending/security/marine/solgov/vendor = allocate(/obj/machinery/vending/security/marine/solgov)
	assert_no_sword(vendor)
	TEST_ASSERT(!outpost_checkpoint_saves(vendor), "Ship checkpoints must exclude SolGov vendors")
	vendor.update_canister()
	vendor.RefreshParts()
	assert_no_sword(vendor)
	var/obj/item/vending_refill/security/refill = allocate(/obj/item/vending_refill/security)
	// Old stock in a canister must not add a product absent from the new inventory.
	refill.products = list(/obj/item/melee/energy/sword/saber/blue = 1, /obj/item/restraints/handcuffs = 10)
	for(var/datum/data/vending_product/product in vendor.product_records)
		product.amount = 0
	TEST_ASSERT(vendor.restock(refill) > 0, "The refill must still replenish supported products")
	assert_no_sword(vendor)

/datum/unit_test/voidcrew_solgov_vendor_stock/proc/assert_no_sword(obj/machinery/vending/security/marine/solgov/vendor)
	TEST_ASSERT(!(/obj/item/melee/energy/sword/saber/blue in vendor.products), "SolGov's products still include the blue sword")
	for(var/datum/data/vending_product/product in vendor.product_records + vendor.hidden_records + vendor.coin_records)
		TEST_ASSERT(!ispath(product.product_path, /obj/item/melee/energy/sword/saber/blue), "SolGov's live inventory still includes the blue sword")

/datum/unit_test/voidcrew_mission_wiring/Run()
	var/checked = 0
	for(var/datum/mission/mission_type as anything in subtypesof(/datum/mission))
		if(mission_type == /datum/mission/unit_test_capped)
			continue // the fixture above
		checked++
		if(!length(initial(mission_type.name)))
			TEST_FAIL("[mission_type] has no name, the board lists a blank contract")
		if(!length(initial(mission_type.desc)))
			TEST_FAIL("[mission_type] has no desc")
		var/value_min = initial(mission_type.value_min)
		var/value_max = initial(mission_type.value_max)
		if(value_min > value_max)
			TEST_FAIL("[mission_type] has value_min [value_min] above value_max [value_max], so the reward roll is inverted")
		if(value_min < 0)
			TEST_FAIL("[mission_type] has a negative pay floor ([value_min])")
		if(initial(mission_type.duration) <= 0)
			TEST_FAIL("[mission_type] has duration [initial(mission_type.duration)]. The timeout fires the moment it is accepted")
		if(initial(mission_type.weight) < 0)
			TEST_FAIL("[mission_type] has a negative weight")
		if(initial(mission_type.mission_limit) < 0)
			TEST_FAIL("[mission_type] has a negative mission_limit; 0 means uncapped")
		if(initial(mission_type.voucher_count) < 0)
			TEST_FAIL("[mission_type] pays a negative number of vouchers")
		// Literals 0/1 = MISSION_QUEST_LOST_FAIL / MISSION_QUEST_LOST_RETARGET
		// (voidcrew/_DEFINES/missions.dm). Unit-test files compile before
		// voidcrew/_DEFINES, so the fork defines are not available here.
		var/policy = initial(mission_type.quest_lost_policy)
		if(policy != 0 && policy != 1)
			TEST_FAIL("[mission_type] has quest_lost_policy [policy]; the only values are 0 (fail the contract) and 1 (retarget it)")
		var/reward = initial(mission_type.mission_reward)
		if(reward && !ispath(reward, /atom/movable))
			TEST_FAIL("[mission_type].mission_reward [reward] is not a spawnable movable, so turn-in pays out nothing")
	TEST_ASSERT(checked >= 15, "only [checked] mission types were checked")

	for(var/datum/mission_objective/deliver/objective_type as anything in subtypesof(/datum/mission_objective/deliver))
		var/required = initial(objective_type.required_type)
		// null is legitimate: several deliver objectives pick their ask at generation
		if(required && !ispath(required, /obj/item))
			TEST_FAIL("[objective_type].required_type [required] is not an item path, so can_turn_in() can never match anything")
		if(initial(objective_type.required_amount) < 1)
			TEST_FAIL("[objective_type] asks for [initial(objective_type.required_amount)] of something. It can never be satisfied by handing anything over")

/// Delivery selection must search past unrelated pad contents for every core type.
/datum/unit_test/voidcrew_mission_pad_cores/Run()
	var/obj/machinery/mission_pad/pad = allocate(/obj/machinery/mission_pad)
	var/obj/item/cigarette/cigarette = allocate(/obj/item/cigarette)
	var/list/core_types = list(
		/obj/item/assembly/signaler/anomaly/grav,
		/obj/item/assembly/signaler/anomaly/flux,
		/obj/item/assembly/signaler/anomaly/hallucination,
		/obj/item/assembly/signaler/anomaly/pyro,
		/obj/item/assembly/signaler/anomaly/bioscrambler,
	)
	for(var/core_type in core_types)
		var/datum/mission/mission = allocate(/datum/mission)
		mission.value = 0
		mission.servant = allocate(/obj/structure/overmap/ship)
		mission.servant.ship_account = allocate(/datum/bank_account)
		mission.active = TRUE
		mission.requires_item = TRUE
		var/datum/mission_objective/deliver/delivery = new
		delivery.required_type = core_type
		mission.add_objective(delivery)
		var/obj/item/core = allocate(core_type)
		mission.register_quest_atom(core)
		var/list/pad_items = pad.get_items_on_pad()
		TEST_ASSERT_EQUAL(pad_items[1], cigarette, "The regression setup must have a cigarette ahead of the core")
		TEST_ASSERT_EQUAL(mission.pick_turn_in_item(pad_items), core, "[core_type] must be selected past an unrelated cigarette")
		TEST_ASSERT(mission.turn_in(pad, mission.pick_turn_in_item(pad_items)), "[core_type] should complete its delivery")
		TEST_ASSERT(QDELETED(core), "The accepted core should be consumed")
		TEST_ASSERT(!QDELETED(cigarette), "Turning in a core must leave the cigarette alone")
		TEST_ASSERT(QDELETED(mission), "Consuming a tracked core must finish the mission, not trigger quest loss")

/// A matching type is insufficient when a larger stack or better fish is available.
/datum/unit_test/voidcrew_mission_pad_requirements/Run()
	var/datum/mission/mission = allocate(/datum/mission)
	mission.value = 0
	mission.servant = allocate(/obj/structure/overmap/ship)
	mission.servant.ship_account = allocate(/datum/bank_account)
	mission.active = TRUE
	mission.requires_item = TRUE
	var/datum/mission_objective/deliver/delivery = new
	delivery.required_type = /obj/item/stack/ore/iron
	delivery.required_amount = 10
	mission.add_objective(delivery)
	var/obj/item/unrelated = allocate(/obj/item/cigarette)
	var/obj/item/stack/ore/iron/short_stack = allocate(/obj/item/stack/ore/iron, run_loc_floor_bottom_left, 5, FALSE)
	var/obj/item/stack/ore/iron/full_stack = allocate(/obj/item/stack/ore/iron, run_loc_floor_bottom_left, 15, FALSE)
	TEST_ASSERT_EQUAL(mission.pick_turn_in_item(list(unrelated, short_stack, full_stack)), full_stack, "A sufficient stack must take priority over a short stack")
	TEST_ASSERT_EQUAL(mission.pick_turn_in_item(list(unrelated, short_stack)), short_stack, "Keep a short stack available for the quantity error")
	TEST_ASSERT_EQUAL(mission.get_failure_reason(short_stack), "Need 10, only have 5.", "A quantity shortfall must not be reported as a type mismatch")
	TEST_ASSERT(!mission.turn_in(null, short_stack), "A near match must not be accepted")
	TEST_ASSERT(mission.turn_in(run_loc_floor_bottom_left, full_stack), "A sufficient stack should complete the delivery")
	TEST_ASSERT_EQUAL(full_stack.amount, 5, "Only the requested amount should be consumed")
	TEST_ASSERT_EQUAL(short_stack.amount, 5, "The short stack should remain untouched")

	var/datum/mission/fish_mission = allocate(/datum/mission)
	fish_mission.requires_item = TRUE
	var/datum/mission_objective/deliver/fish/fish_delivery = new
	fish_delivery.min_weight = 2500
	fish_mission.add_objective(fish_delivery)
	var/obj/item/fish/small_fish = allocate(/obj/item/fish)
	small_fish.weight = 500
	var/obj/item/fish/large_fish = allocate(/obj/item/fish)
	large_fish.weight = 3000
	TEST_ASSERT_EQUAL(fish_mission.pick_turn_in_item(list(unrelated, small_fish, large_fish)), large_fish, "Selection must honor quality requirements, not just item type")
	TEST_ASSERT_EQUAL(fish_mission.pick_turn_in_item(list(unrelated, small_fish)), small_fish, "Keep an undersized fish available for the weight error")
	TEST_ASSERT(!fish_mission.can_turn_in(small_fish), "An undersized fish must still be refused")
	TEST_ASSERT_NULL(fish_mission.pick_turn_in_item(list(unrelated)), "Unrelated items must not be offered")
	TEST_ASSERT_NULL(fish_mission.pick_turn_in_item(list()), "An empty pad must not offer an item")

/// Recovery contracts must choose their own current item among other quest items.
/datum/unit_test/voidcrew_mission_pad_binding/Run()
	var/datum/mission/mission = allocate(/datum/mission)
	mission.requires_item = TRUE
	mission.add_objective(new /datum/mission_objective/deliver/bound)
	var/datum/mission/other_mission = allocate(/datum/mission)
	var/obj/item/mission_recovery/foreign_item = allocate(/obj/item/mission_recovery)
	other_mission.bind_item(foreign_item)
	var/obj/item/mission_recovery/stale_item = allocate(/obj/item/mission_recovery)
	mission.bind_item(stale_item)
	mission.binding_serial++
	var/obj/item/mission_recovery/current_item = allocate(/obj/item/mission_recovery)
	mission.bind_item(current_item)
	TEST_ASSERT_EQUAL(mission.pick_turn_in_item(list(foreign_item, stale_item, current_item)), current_item, "Select the item bound to this contract's current target")
	TEST_ASSERT(!mission.can_turn_in(foreign_item), "Another contract's item must remain invalid")
	TEST_ASSERT(!mission.can_turn_in(stale_item), "An item from before retargeting must remain invalid")
	TEST_ASSERT_EQUAL(mission.pick_turn_in_item(list(stale_item)), stale_item, "Keep an expired binding available for the binding error")

/**
 * # Ruin contracts never point at an occupied site
 *
 * A recovery-family contract picks a live ruin signal out of
 * GLOB.space_ruin_signals. Nothing used to stop it picking the ruin the
 * accepting crew was docked at that second, and that pick is self-destructing:
 * the field objective arms immediately (the interior is loaded, because they
 * are standing in it), and then undocking runs check_and_respawn(), which frees
 * the interior out from under the contract. From the helm, taking a job and
 * leaving made the job disappear.
 *
 * `loaded` is the tell. A ruin is only ever loaded because somebody is there or
 * has just left. All three tiers of the pick are exercised here, because the two
 * preferences are not interchangeable and the first attempt at this fix folded
 * them into one set: with the boards holding enough offers to keep most of the
 * sector claimed, a combined "cold AND unclaimed" set empties out routinely and
 * falls through to picking anything at all, occupied berth included. Avoiding an
 * occupied site has to outrank avoiding a double-booked one.
 */
/datum/unit_test/voidcrew_mission_ruin_target_picker

/datum/unit_test/voidcrew_mission_ruin_target_picker/Run()
	var/list/obj/structure/overmap/space_ruin/live_ruins = list()
	for(var/obj/structure/overmap/space_ruin/ruin as anything in GLOB.space_ruin_signals)
		if(QDELETED(ruin) || ruin.mission_locked || ruin.mission_exclusive)
			continue
		if(!istype(get_turf(ruin), /turf/open/overmap))
			continue
		live_ruins += ruin
	if(length(live_ruins) < 2)
		return // no overmap worth testing against in this world

	// Remember what we are about to lie about, so the round gets it back
	var/list/saved_loaded = list()
	var/list/saved_claims = list()
	for(var/obj/structure/overmap/space_ruin/ruin as anything in live_ruins)
		saved_loaded[ruin] = ruin.loaded
		saved_claims[ruin] = ruin.mission_claims

	var/obj/structure/overmap/space_ruin/occupied = live_ruins[1]
	occupied.loaded = TRUE
	for(var/i in 2 to length(live_ruins))
		var/obj/structure/overmap/space_ruin/cold = live_ruins[i]
		cold.loaded = FALSE
		cold.mission_claims = 0

	var/datum/mission_target/space_ruin/target = new(null)

	// Tier 1: cold and unclaimed sites exist, so one of those is the pick
	for(var/_ in 1 to 40)
		if(!target.resolve())
			TEST_FAIL("space_ruin target resolve() found nothing with [length(live_ruins)] ruins on the overmap")
			break
		if(target.ruin == occupied)
			TEST_FAIL("a ruin contract targeted a loaded (occupied) ruin while [length(live_ruins) - 1] cold, unclaimed ruins were available")
			break

	// Tier 2: every cold site is already spoken for. Double-booking one of them
	// is still correct - the loaded ruin is the one pick that voids itself.
	for(var/i in 2 to length(live_ruins))
		var/obj/structure/overmap/space_ruin/cold = live_ruins[i]
		cold.mission_claims = 1
	for(var/_ in 1 to 40)
		if(!target.resolve())
			TEST_FAIL("space_ruin target resolve() found nothing once every cold ruin was claimed")
			break
		if(target.ruin == occupied)
			TEST_FAIL("with every cold ruin already claimed, the picker fell back to a loaded (occupied) ruin instead of double-booking a cold one. Accepting that contract while docked there arms the objective inside the site the crew is standing in, and undocking recycles the site out from under it (see check_and_respawn). Avoiding an occupied site outranks avoiding a double-booking.")
			break

	// Tier 3: nowhere cold left. The picker must still hand something back rather
	// than fail generation and drop the contract off the board entirely.
	for(var/obj/structure/overmap/space_ruin/ruin as anything in live_ruins)
		ruin.loaded = TRUE
	TEST_ASSERT(target.resolve(), "with every ruin loaded, the picker refused to pick any of them instead of falling back. Recovery contracts stop generating entirely")

	qdel(target)
	for(var/obj/structure/overmap/space_ruin/ruin as anything in live_ruins)
		ruin.loaded = saved_loaded[ruin]
		ruin.mission_claims = saved_claims[ruin]

/// Rescue bonuses affect credits alone, once, and never return after revival.
/datum/unit_test/voidcrew_mission_rescue_reward/Run()
	var/turf/pad_turf = run_loc_floor_bottom_left
	var/obj/machinery/mission_pad/pad = allocate(/obj/machinery/mission_pad, pad_turf)
	var/obj/structure/overmap/ship/ship = allocate(/obj/structure/overmap/ship)
	ship.ship_account = allocate(/datum/bank_account/ship, "Rescue Test", null, 1, FALSE)
	ship.linked_mission_pads = list(pad)
	var/datum/mission/rescue/rescue_type = /datum/mission/rescue
	var/expected_vouchers = 0
	var/list/delivery_cases = list(
		list("healthy", 0, FALSE, 1250),
		list("80% health", 12, FALSE, 1250),
		list("injured", 13, FALSE, 1000),
		list("revived and healed", 13, TRUE, 1000),
	)
	for(var/list/delivery_case as anything in delivery_cases)
		var/datum/mission/mission = allocate(/datum/mission)
		mission.value = 1000
		mission.voucher_count = initial(rescue_type.voucher_count)
		mission.servant = ship
		mission.active = TRUE
		var/datum/mission_objective/field/escort/escort = new
		mission.add_objective(escort)
		escort.spawn_field_objects(pad_turf)
		var/mob/living/survivor = escort.survivor
		survivor.adjustBruteLoss(delivery_case[2])
		if(delivery_case[3])
			survivor.death()
			TEST_ASSERT(escort.grace_timer, "The survivor's death must start the revival window")
			survivor.revive(ADMIN_HEAL_ALL)
			TEST_ASSERT(survivor.stat != DEAD, "The survivor must actually revive")
			TEST_ASSERT_EQUAL(survivor.health, survivor.maxHealth, "The revived survivor must be fully healed")
			TEST_ASSERT(escort.was_revived, "Healing must preserve the survivor's revival history")
			TEST_ASSERT_NULL(escort.grace_timer, "Revival must clear the recovery timer")
		var/balance_before = ship.ship_account.account_balance
		expected_vouchers += mission.voucher_count
		TEST_ASSERT(mission.turn_in(pad), "The [delivery_case[1]] survivor must be accepted")
		TEST_ASSERT_EQUAL(ship.ship_account.account_balance - balance_before, delivery_case[4], "The [delivery_case[1]] survivor paid the wrong credits")
		TEST_ASSERT(QDELETED(survivor), "The delivered survivor must be removed")
		TEST_ASSERT(QDELETED(mission), "Delivering the survivor must complete the mission")
		var/vouchers_paid = 0
		for(var/obj/item/stack/trade_voucher/vouchers in pad_turf)
			vouchers_paid += vouchers.amount
		TEST_ASSERT_EQUAL(vouchers_paid, expected_vouchers, "The [delivery_case[1]] survivor must leave the voucher payout unchanged")

	// Exercise the finalizer twice while the mission and objective still exist.
	var/datum/mission/repeated = allocate(/datum/mission)
	repeated.value = 1000
	repeated.voucher_count = initial(rescue_type.voucher_count)
	var/datum/mission_objective/field/escort/repeated_escort = new
	repeated.add_objective(repeated_escort)
	repeated_escort.survivor = allocate(/mob/living/basic/mission_survivor, pad_turf)
	repeated_escort.on_turn_in_finalized(pad)
	TEST_ASSERT_EQUAL(repeated.value, 1250, "A healthy survivor must add 25% to credits")
	TEST_ASSERT_NULL(repeated_escort.survivor, "Finalization must clear the survivor reference")
	repeated_escort.on_turn_in_finalized(pad)
	TEST_ASSERT_EQUAL(repeated.value, 1250, "Repeated finalization must not stack the bonus")
	TEST_ASSERT_EQUAL(repeated.voucher_count, initial(rescue_type.voucher_count), "Repeated finalization must not change vouchers")

/**
 * A contract that marks itself exclusive_site must get a wreck to itself.
 *
 * Double-booking a ruin is cosmetic for salvage and fatal for a rescue. A bounty
 * contract spawns its named target plus a paid entourage at a random interior
 * turf; a rescue spawns a 60 HP survivor who never fights back at another random
 * interior turf in the same small template. Playtesting turned that up the
 * obvious way - the crew flew out to a rescue, found the survivor dead, and left
 * with the identification tag of somebody else's bounty target instead.
 *
 * So: an exclusive pick only ever comes out of the cold-and-unclaimed tier, it
 * flags the site so nothing else can aim there, it refuses to generate rather
 * than share, and it gives the flag back when the contract lets go.
 */
/datum/unit_test/voidcrew_mission_exclusive_site

/datum/unit_test/voidcrew_mission_exclusive_site/Run()
	var/list/obj/structure/overmap/space_ruin/live_ruins = list()
	for(var/obj/structure/overmap/space_ruin/ruin as anything in GLOB.space_ruin_signals)
		if(QDELETED(ruin) || ruin.mission_locked || ruin.mission_exclusive)
			continue
		if(!istype(get_turf(ruin), /turf/open/overmap))
			continue
		live_ruins += ruin
	if(length(live_ruins) < 3)
		return // no overmap worth testing against in this world

	var/list/saved_loaded = list()
	var/list/saved_claims = list()
	for(var/obj/structure/overmap/space_ruin/ruin as anything in live_ruins)
		saved_loaded[ruin] = ruin.loaded
		saved_claims[ruin] = ruin.mission_claims
		ruin.loaded = FALSE
		ruin.mission_claims = 0

	var/datum/mission/exclusive_mission = new()
	exclusive_mission.exclusive_site = TRUE
	var/datum/mission/sharing_mission = new()

	var/datum/mission_target/space_ruin/exclusive_target = new(exclusive_mission)
	var/datum/mission_target/space_ruin/sharing_target = new(sharing_mission)

	if(!exclusive_target.resolve())
		TEST_FAIL("an exclusive contract found no site with [length(live_ruins)] cold, unclaimed ruins on the overmap")
	else
		var/obj/structure/overmap/space_ruin/taken = exclusive_target.ruin
		TEST_ASSERT(taken.mission_exclusive, "an exclusive contract claimed a ruin without flagging it exclusive, so the next contract can still aim into it")

		// Nobody else may land on it, however many rolls they get. Released between
		// rolls so the "never re-pick the previous site" rule doesn't starve the
		// candidate set on a small overmap and read as a failure.
		for(var/_ in 1 to 40)
			sharing_target.unhook()
			if(!sharing_target.resolve())
				TEST_FAIL("a normal contract found no site at all while [length(live_ruins) - 1] unclaimed ruins were free")
				break
			if(sharing_target.ruin == taken)
				TEST_FAIL("a normal contract targeted a ruin an exclusive contract is holding - this is the bounty-in-the-rescue's-wreck case that kills the survivor before the crew arrives")
				break

		// Nothing cold and unclaimed left: refuse rather than share
		sharing_target.unhook() // its claim would otherwise come back off below
		for(var/obj/structure/overmap/space_ruin/ruin as anything in live_ruins)
			if(ruin != taken)
				ruin.mission_claims = 1
		var/datum/mission_target/space_ruin/starved_target = new(exclusive_mission)
		TEST_ASSERT(!starved_target.resolve(), "an exclusive contract double-booked a site once every other ruin was claimed; it should fail generation and let the board roll something else")
		qdel(starved_target)

		// ...and the flag comes back off when the contract lets go
		qdel(exclusive_target)
		exclusive_target = null
		TEST_ASSERT(!taken.mission_exclusive, "a released exclusive claim left the ruin flagged, so no contract can ever target that site again this round")

	if(exclusive_target)
		qdel(exclusive_target)
	qdel(sharing_target)
	qdel(exclusive_mission)
	qdel(sharing_mission)
	for(var/obj/structure/overmap/space_ruin/ruin as anything in live_ruins)
		ruin.loaded = saved_loaded[ruin]
		ruin.mission_claims = saved_claims[ruin]

/// Isolate mission lifecycle tests from overmap generation and bank accounts.
/datum/mission/kill_rewind_test
	var/reward_calls = 0

/datum/mission/kill_rewind_test/generate_mission_details()
	return

/datum/mission/kill_rewind_test/distribute_rewards(atom/reward_anchor)
	reward_calls++

/// The far corner is the site; the near corner represents the crew's ship.
/datum/mission_target/kill_rewind_test
	var/turf/spawn_turf
	var/interior_loaded = TRUE

/datum/mission_target/kill_rewind_test/resolve()
	return TRUE

/datum/mission_target/kill_rewind_test/get_zone_type()
	return 1 // ZONE_GREEN: lifecycle fixtures still need an identified work band.

/datum/mission_target/kill_rewind_test/is_interior_loaded()
	return interior_loaded

/datum/mission_target/kill_rewind_test/get_spawn_turf()
	return spawn_turf

/datum/mission_target/kill_rewind_test/contains_turf(turf/where)
	return where == spawn_turf

/datum/mission_target/kill_rewind_test/get_interior_bounds()
	return list(spawn_turf.x, spawn_turf.y, spawn_turf.x, spawn_turf.y, spawn_turf.z)

/// Retain the original body so real revival can exercise the cash handler.
/mob/living/basic/trooper/pirate/faction/boss/mission_rewind_test
	ai_controller = null
	basic_mob_flags = NONE
	use_dynamic_appearance = FALSE
	corpse = null
	loot = null
	loot_pool = null
	plunder_credits = 3000
	unsuitable_cold_damage = 0
	unsuitable_heat_damage = 0

/datum/unit_test/voidcrew_mission_kill_rewind
	abstract_type = /datum/unit_test/voidcrew_mission_kill_rewind

/datum/unit_test/voidcrew_mission_kill_rewind/proc/make_hunt(big_game = FALSE)
	var/datum/mission/kill_rewind_test/mission = allocate(__IMPLIED_TYPE__)
	mission.servant = allocate(/obj/structure/overmap/ship)
	mission.servant.ship_account = allocate(/datum/bank_account)
	mission.active = TRUE
	mission.quote_zone = 1 // ZONE_GREEN
	mission.requires_item = TRUE
	mission.objective_name = "Old Testbeard"
	var/datum/mission_target/kill_rewind_test/target = allocate(__IMPLIED_TYPE__, mission)
	mission.target = target
	target.spawn_turf = run_loc_floor_top_right
	var/datum/mission_objective/field/kill_named/hunt
	var/datum/mission_objective/set_lure/lure
	if(big_game)
		lure = allocate(__IMPLIED_TYPE__)
		mission.add_objective(lure)
		var/datum/mission_objective/field/kill_named/big_game/trophy_hunt = allocate(__IMPLIED_TYPE__)
		trophy_hunt.trophy_part = "scarred jawbone"
		trophy_hunt.health_override = 450
		hunt = trophy_hunt
		lure.hunt_objective = trophy_hunt
	else
		hunt = allocate(__IMPLIED_TYPE__)
	hunt.target_mob_type = /mob/living/basic/trooper/pirate/faction/boss/mission_rewind_test
	hunt.guard_types = list(/mob/living/basic/trooper/pirate/faction/boss/mission_rewind_test)
	mission.add_objective(hunt)
	mission.add_objective(allocate(big_game ? /datum/mission_objective/deliver/bound/trophy : /datum/mission_objective/deliver/bound/proof))
	if(lure)
		lure.kit = allocate(/obj/item/hunting_lure, target.spawn_turf)
		mission.register_quest_atom(lure.kit)
	mission.activate_current_objective()
	if(lure)
		lure.on_planted(null, target.spawn_turf)
		// The single-turf fixture stands in for the whole hunting ground.
		hunt.target_mob.forceMove(target.spawn_turf)
	return mission

/datum/unit_test/voidcrew_mission_kill_rewind/proc/test_mobs()
	var/list/mobs = list()
	for(var/mob/living/basic/trooper/pirate/faction/boss/mission_rewind_test/boss in GLOB.mob_list)
		if(!QDELETED(boss))
			mobs += boss
	return mobs

/datum/unit_test/voidcrew_mission_kill_rewind/proc/floor_items(item_type)
	var/list/items = list()
	for(var/turf/tile in block(run_loc_floor_bottom_left, run_loc_floor_top_right))
		for(var/obj/item/item in tile.contents)
			if(istype(item, item_type) && !QDELETED(item))
				items += item
	return items

/// Kill, strand the proof and rebuild the interior more than once.
/datum/unit_test/voidcrew_mission_kill_rewind/repeated/Run()
	check_repeated_rewinds(FALSE)

/// The same lifecycle must restore trophies without another lure or beast.
/datum/unit_test/voidcrew_mission_kill_rewind/trophy/Run()
	check_repeated_rewinds(TRUE)

/datum/unit_test/voidcrew_mission_kill_rewind/proc/check_repeated_rewinds(big_game)
	var/datum/mission/kill_rewind_test/mission = make_hunt(big_game)
	var/datum/mission_target/kill_rewind_test/target = mission.target
	var/datum/mission_objective/field/kill_named/hunt = mission.current_objective()
	var/mob/living/basic/trooper/pirate/faction/boss/mission_rewind_test/boss = hunt.target_mob
	TEST_ASSERT_EQUAL(length(test_mobs()), 2, "The initial hunt must spawn a target and guard")
	boss.death(FALSE)
	TEST_ASSERT(mission.named_kill_completed, "The mission must retain the completed kill")
	TEST_ASSERT(mission.boss_cash_issued, "The first death must claim the mission's cash entitlement")
	var/obj/item/mission_recovery/proof = mission.quest_atom
	TEST_ASSERT(istype(proof, big_game ? /obj/item/mission_recovery/trophy : /obj/item/mission_recovery/proof), "The initial proof must have the right subtype")
	TEST_ASSERT(mission.can_turn_in(proof), "The original proof must be deliverable")

	SEND_SIGNAL(boss, COMSIG_LIVING_DEATH, FALSE)
	hunt.on_target_death(boss, FALSE)
	TEST_ASSERT(boss.revive(ADMIN_HEAL_ALL), "The retained original boss must be revivable")
	boss.death(FALSE)
	TEST_ASSERT_EQUAL(mission.quest_atom, proof, "Duplicate death signals and revival must not replace the proof")
	TEST_ASSERT_EQUAL(length(floor_items(/obj/item/mission_recovery)), 1, "A revived boss must not create another proof")
	var/list/cash = floor_items(/obj/item/holochip)
	TEST_ASSERT_EQUAL(length(cash), 1, "Duplicate deaths and revival must issue one holochip")
	var/obj/item/holochip/payment = cash[1]
	TEST_ASSERT_EQUAL(payment.credits, boss.plunder_credits, "The boss cash amount must stay unchanged")
	payment.forceMove(run_loc_floor_bottom_left)
	var/retargets_before = mission.retargets_left

	for(var/rewind in 1 to 3)
		var/obj/item/mission_recovery/old_proof = mission.quest_atom
		var/old_serial = mission.binding_serial
		target.interior_loaded = FALSE
		mission.on_target_interior_unloaded()
		TEST_ASSERT_NULL(mission.quest_atom, "Unload must forget stranded proof before the wipe")
		TEST_ASSERT_EQUAL(mission.current_objective(), hunt, "A completed kill must wait at proof recovery")
		TEST_ASSERT(mission.named_kill_completed && mission.boss_cash_issued, "Rewind must retain both lifetime flags")
		TEST_ASSERT(mission.binding_serial > old_serial, "Replacement proof must get a fresh binding")
		for(var/mob/living/left_behind in test_mobs())
			qdel(left_behind)
		// Keep one obsolete proof through reload to check stale-binding rejection.
		if(rewind != 1)
			qdel(old_proof)
		TEST_ASSERT(!mission.failed && !QDELETED(mission), "Deleting forgotten quest atoms must not trigger quest loss")
		target.interior_loaded = TRUE
		mission.on_target_interior_loaded()
		var/obj/item/mission_recovery/replacement = mission.quest_atom
		TEST_ASSERT_NOTNULL(replacement, "Reload must place replacement proof")
		TEST_ASSERT(replacement != old_proof, "Reload must bind a newly created proof")
		TEST_ASSERT_EQUAL(replacement.type, big_game ? /obj/item/mission_recovery/trophy : /obj/item/mission_recovery/proof, "Reload must preserve the proof subtype")
		TEST_ASSERT_EQUAL(replacement.name, big_game ? "Old Testbeard's scarred jawbone" : "Old Testbeard's identification tag", "Reload must preserve the proof's identity")
		TEST_ASSERT(mission.can_turn_in(replacement), "Reload must resume the delivery step")
		if(rewind == 1)
			TEST_ASSERT(!mission.can_turn_in(old_proof), "Stranded proof must not match the new binding")
			qdel(old_proof)
		mission.on_target_interior_loaded()
		hunt.do_field_spawn()
		TEST_ASSERT_EQUAL(length(test_mobs()), 0, "Completed hunts must never respawn a boss or guards")
		TEST_ASSERT_EQUAL(length(floor_items(/obj/item/mission_recovery)), 1, "Repeated load callbacks must leave exactly one proof")
		TEST_ASSERT_EQUAL(length(floor_items(/obj/item/holochip)), 1, "Rewinds must not issue more boss cash")
		TEST_ASSERT_EQUAL(mission.retargets_left, retargets_before, "Interior rewinds must not consume retargets")
		if(big_game)
			var/datum/mission_objective/set_lure/lure = mission.objectives[1]
			TEST_ASSERT(lure.completed, "A completed trophy hunt must never ask for another lure")

	TEST_ASSERT(mission.turn_in(run_loc_floor_bottom_left, mission.quest_atom), "Replacement proof must finish the mission")
	TEST_ASSERT(!mission.failed && mission.completed, "Proof consumption must finish rather than void the mission")
	TEST_ASSERT(!mission.turn_in(run_loc_floor_bottom_left, null, TRUE), "Repeated forced turn-in must still honor mission completion")
	TEST_ASSERT_EQUAL(mission.reward_calls, 1, "Repeated turn-in must not distribute rewards twice")

/// Carried proof stays valid while the crew revisits an emptied site.
/datum/unit_test/voidcrew_mission_kill_rewind/carried/Run()
	for(var/big_game in list(FALSE, TRUE))
		var/datum/mission/kill_rewind_test/mission = make_hunt(big_game)
		var/datum/mission_target/kill_rewind_test/target = mission.target
		var/datum/mission_objective/field/kill_named/hunt = mission.current_objective()
		var/mob/living/basic/trooper/pirate/faction/boss/mission_rewind_test/boss = hunt.target_mob
		boss.death(FALSE)
		var/obj/item/mission_recovery/proof = mission.quest_atom
		var/mob/living/carbon/human/carrier = allocate(__IMPLIED_TYPE__)
		TEST_ASSERT(carrier.put_in_hands(proof), "The crew must be able to carry out the proof")
		var/serial_before = mission.binding_serial
		var/datum/mission_objective/delivery = mission.current_objective()
		for(var/rewind in 1 to 3)
			target.interior_loaded = FALSE
			mission.on_target_interior_unloaded()
			target.interior_loaded = TRUE
			mission.on_target_interior_loaded()
			TEST_ASSERT_EQUAL(mission.quest_atom, proof, "Extracted proof must stay tracked")
			TEST_ASSERT_EQUAL(mission.binding_serial, serial_before, "Extracted proof must keep its binding")
			TEST_ASSERT_EQUAL(mission.current_objective(), delivery, "Extracted proof must stay on delivery")
			TEST_ASSERT(mission.can_turn_in(proof), "Carried proof must remain valid")
		TEST_ASSERT(mission.turn_in(run_loc_floor_bottom_left, proof), "Carried proof must still finish the contract")
		TEST_ASSERT(!mission.turn_in(run_loc_floor_bottom_left, proof), "The same proof cannot pay twice")
		TEST_ASSERT_EQUAL(mission.reward_calls, 1, "Carried proof must pay once")
		var/cash_count = length(floor_items(/obj/item/holochip))
		boss.on_death_drop_credits(boss)
		TEST_ASSERT_EQUAL(length(floor_items(/obj/item/holochip)), cash_count, "An expired mission reference must never become an unbound cash drop")

/// An abandoned live target and its replacement share the same cash entitlement.
/datum/unit_test/voidcrew_mission_kill_rewind/replacement/Run()
	var/datum/mission/kill_rewind_test/mission = make_hunt()
	var/datum/mission_target/kill_rewind_test/target = mission.target
	var/datum/mission_objective/field/kill_named/hunt = mission.current_objective()
	var/mob/living/basic/trooper/pirate/faction/boss/mission_rewind_test/original = hunt.target_mob
	target.interior_loaded = FALSE
	mission.on_target_interior_unloaded()
	TEST_ASSERT(!mission.named_kill_completed && !mission.boss_cash_issued, "A live target's rewind must not invent completion or spend cash")
	TEST_ASSERT_NULL(hunt.target_mob, "Reset must release the original target")
	target.interior_loaded = TRUE
	mission.on_target_interior_loaded()
	var/mob/living/basic/trooper/pirate/faction/boss/mission_rewind_test/replacement = hunt.target_mob
	TEST_ASSERT(replacement && replacement != original, "An unfinished hunt must spawn a replacement target")
	original.death(FALSE)
	TEST_ASSERT(!mission.named_kill_completed, "The original target's old death handler must be unregistered")
	TEST_ASSERT_EQUAL(mission.quest_atom, replacement, "An obsolete target must not replace the live quest atom")
	TEST_ASSERT_EQUAL(length(floor_items(/obj/item/mission_recovery)), 0, "An obsolete target must not drop proof")
	replacement.death(FALSE)
	TEST_ASSERT(mission.named_kill_completed, "The current target must complete the kill")
	TEST_ASSERT_EQUAL(length(floor_items(/obj/item/holochip)), 1, "Original and replacement targets must share one cash payment")
	var/obj/item/mission_recovery/old_proof = mission.quest_atom
	var/mob_count = length(test_mobs())
	var/retargets_before = mission.retargets_left
	mission.retarget()
	TEST_ASSERT(!mission.failed && mission.active, "A same-band retarget must keep the contract active")
	TEST_ASSERT_EQUAL(mission.retargets_left, retargets_before - 1, "A real retarget must consume one retarget")
	TEST_ASSERT(mission.named_kill_completed && mission.boss_cash_issued, "Retargeting must preserve both lifetime flags")
	TEST_ASSERT_EQUAL(length(test_mobs()), mob_count, "Retargeting a completed kill must restore proof without more mobs")
	TEST_ASSERT(!mission.can_turn_in(old_proof), "A retarget must reject the obsolete proof")
	TEST_ASSERT(mission.can_turn_in(mission.quest_atom), "A retarget must resume proof delivery")
	qdel(old_proof)
	SEND_SIGNAL(original, COMSIG_LIVING_DEATH, FALSE)
	SEND_SIGNAL(replacement, COMSIG_LIVING_DEATH, FALSE)
	TEST_ASSERT_EQUAL(length(floor_items(/obj/item/holochip)), 1, "Retargeting must not replenish the boss cash entitlement")
	TEST_ASSERT(mission.turn_in(run_loc_floor_bottom_left, mission.quest_atom), "Retargeted proof must finish the mission")
	TEST_ASSERT(!mission.turn_in(run_loc_floor_bottom_left, null, TRUE), "Retargeted proof must not allow another turn-in")
	TEST_ASSERT_EQUAL(mission.reward_calls, 1, "Retargeted proof must pay the mission reward once")
