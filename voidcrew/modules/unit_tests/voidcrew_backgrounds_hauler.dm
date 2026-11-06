/// Backgrounds: owned by P5.

// NPC haulers (spec section 6 P5). Unit tests compile before the voidcrew defines, so the
// literals below carry the name of the define they stand for.

/// Loads a hauler on the overmap, in yellow when it can. Null if the load failed.
/proc/hauler_test_spawn()
	var/turf/spawn_turf = SSnpc_ships.get_spawn_turf(list(2)) || SSovermap.get_unused_overmap_square() // ZONE_YELLOW
	if(!spawn_turf)
		return null
	var/obj/structure/overmap/ship/npc/hauler/hauler = SSnpc_ships.create_npc_ship(/datum/map_template/shuttle/voidcrew/hauler, spawn_turf, /obj/structure/overmap/ship/npc/hauler)
	return istype(hauler) ? hauler : null

/// Takes a test hauler away, crew and freight with it
/proc/hauler_test_remove(obj/structure/overmap/ship/npc/hauler/hauler)
	if(QDELETED(hauler))
		return
	hauler.begin_departure()
	if(!QDELETED(hauler))
		qdel(hauler)

/// Everything on `hauler`'s hull, nested contents included
/proc/hauler_test_contents(obj/structure/overmap/ship/npc/hauler/hauler)
	. = list()
	if(!hauler?.shuttle?.shuttle_areas)
		return
	for(var/area/shuttle_area as anything in hauler.shuttle.shuttle_areas)
		for(var/turf/tile in shuttle_area)
			. += tile.get_all_contents()

/// Drops every embargo the test put on `ship`, so no outpost keeps a reference to it
/proc/hauler_test_clear_embargo(obj/structure/overmap/ship/ship)
	if(!ship)
		return
	for(var/obj/structure/overmap/trader_outpost/outpost in GLOB.trader_outposts)
		outpost.embargoed_ships -= ship

// =========================================================================
// THE HULL (map-contracts.md M4). Fails on P0's placeholder map until M4's lands.
// =========================================================================

/datum/unit_test/voidcrew_hauler_hull
	priority = TEST_LONGER
	var/obj/structure/overmap/ship/npc/hauler/hauler

/datum/unit_test/voidcrew_hauler_hull/Destroy()
	hauler_test_remove(hauler)
	hauler = null
	return ..()

/datum/unit_test/voidcrew_hauler_hull/Run()
	hauler = hauler_test_spawn()
	TEST_ASSERT_NOTNULL(hauler, "The Mule-class hull did not load as a hauler")
	var/holopads = 0
	var/bridge_holopads = 0
	var/cargo_markers = 0
	var/crew_markers = 0
	var/cryopods = 0
	var/ports = 0
	var/list/forbidden = list()
	var/static/list/forbidden_types = list(
		/obj/machinery/ship_combat,
		/obj/machinery/shuttle_scrambler,
		/obj/machinery/porta_turret,
		/obj/machinery/computer/mission_board,
		/obj/machinery/computer/bank_machine,
		/obj/item/ship_key,
	)
	for(var/atom/movable/thing in hauler_test_contents(hauler))
		if(istype(thing, /obj/machinery/holopad))
			holopads++
			if(istype(get_area(thing), /area/shuttle/voidcrew/hauler/bridge))
				bridge_holopads++
		else if(istype(thing, /obj/effect/landmark/hauler/cargo))
			cargo_markers++
		else if(istype(thing, /obj/effect/landmark/hauler/crew))
			crew_markers++
		else if(istype(thing, /obj/machinery/cryopod))
			cryopods++
		else if(istype(thing, /obj/docking_port/mobile))
			ports++
		else if(is_type_in_list(thing, forbidden_types))
			forbidden += "[thing.type]"
		else if(isliving(thing) && !istype(thing, /mob/living/basic/ambient_npc/hauler_crew))
			forbidden += "[thing.type]"
	TEST_ASSERT_EQUAL(holopads, 1, "The hauler needs exactly one holopad")
	TEST_ASSERT_EQUAL(bridge_holopads, 1, "The hauler's holopad is not on its bridge")
	TEST_ASSERT_EQUAL(cargo_markers, 5, "The hauler's hold needs five cargo markers")
	TEST_ASSERT_EQUAL(crew_markers, 3, "The hauler needs three crew markers")
	TEST_ASSERT_EQUAL(cryopods, 0, "A hauler with a cryopod shows up in the join menu")
	TEST_ASSERT_EQUAL(ports, 1, "The hauler needs exactly one docking port")
	TEST_ASSERT(!length(forbidden), "The hauler carries what it must not: [english_list(forbidden)]")

// =========================================================================
// SPAWNING: no key, not in the pool, never on SSbounty, nobody claims it (ECO-8, ECO-11)
// =========================================================================

/datum/unit_test/voidcrew_hauler_spawn
	priority = TEST_LONGER
	var/obj/structure/overmap/ship/npc/hauler/hauler
	var/datum/hauler_slot/test_slot

/datum/unit_test/voidcrew_hauler_spawn/Destroy()
	if(test_slot)
		GLOB.hauler_director.release_slot(test_slot, world.time, hauler)
		GLOB.hauler_director.slots -= test_slot
		QDEL_NULL(test_slot)
	hauler_test_remove(hauler)
	hauler = null
	return ..()

/datum/unit_test/voidcrew_hauler_spawn/Run()
	hauler = hauler_test_spawn()
	TEST_ASSERT_NOTNULL(hauler, "The hauler did not load")
	TEST_ASSERT(istype(hauler.ai_controller, /datum/ai_controller/npc_ship/hauler), "The hauler flies on the pirates' controller")
	TEST_ASSERT(!hauler.hostile, "The hauler is hostile")
	TEST_ASSERT(length(hauler.tracked_crew) >= 1 && length(hauler.tracked_crew) <= 3, "The hauler has [length(hauler.tracked_crew)] crew, not two or three")
	for(var/mob/living/hand in hauler.tracked_crew)
		TEST_ASSERT(istype(hand, /mob/living/basic/ambient_npc/hauler_crew), "A hauler crewed by [hand.type]")
	for(var/obj/item/ship_key/key in hauler_test_contents(hauler))
		TEST_FAIL("A hauler spawned with a ship key ([key.name]) at [AREACOORD(key)]")
	TEST_ASSERT_EQUAL(length(hauler.cargo_aboard()), 3, "The hauler is not carrying its freight") // BACKGROUND_HAULER_CASES
	TEST_ASSERT(hauler.ship_account?.account_balance >= 600 && hauler.ship_account.account_balance <= 1800, "The hauler's hold is [hauler.ship_account?.account_balance] cr") // HOLD_MIN x green to HOLD_MAX x red
	TEST_ASSERT(!(hauler in SSnpc_ships.active_ships), "The hauler joined the pirate pool's ship list")
	TEST_ASSERT(!SSbounty.pirate_ship_crewed(hauler), "SSbounty would post a bounty on a hauler")

	// The Hijack case: a plain case aboard swapped for a marked one
	test_slot = new /datum/hauler_slot(2) // ZONE_YELLOW
	GLOB.hauler_director.slots += test_slot
	GLOB.hauler_director.fill_slot(test_slot, hauler)
	TEST_ASSERT(hauler in hauler_live_haulers(), "A hauler in a slot is not live")
	var/obj/item/hauler_cargo/marked/marked = hauler_mark_case(null)
	TEST_ASSERT_NOTNULL(marked, "No case was marked on a live hauler")
	TEST_ASSERT(hauler.holds(marked), "The marked case is not aboard the hauler")
	var/list/cargo = hauler.cargo_aboard()
	TEST_ASSERT_EQUAL(length(cargo), 3, "Marking a case changed how much freight is aboard")
	TEST_ASSERT(marked in cargo, "The hauler does not count the marked case as its freight")

	// Abandoning it opens no claim window: it leaves, crew and all
	var/list/crew = hauler.tracked_crew.Copy()
	hauler.abandon_ship()
	TEST_ASSERT(QDELETED(hauler), "An abandoned hauler stayed out to be claimed")
	for(var/mob/living/hand in crew)
		TEST_ASSERT(QDELETED(hand), "A crew hand outlived the hauler that jumped out")
	TEST_ASSERT_NULL(test_slot.hauler_ref, "The director kept the slot of a hauler that left")

// =========================================================================
// GIVING UP (ECO-7, Q8)
// =========================================================================

/datum/unit_test/voidcrew_hauler_surrender
	priority = TEST_LONGER
	var/obj/structure/overmap/ship/npc/hauler/hauler
	var/obj/structure/overmap/ship/robber
	var/list/taken_args
	var/list/lost_args

/datum/unit_test/voidcrew_hauler_surrender/Destroy()
	hauler_test_clear_embargo(robber)
	hauler_test_remove(hauler)
	hauler = null
	robber = null
	return ..()

/datum/unit_test/voidcrew_hauler_surrender/proc/on_taken(datum/source, obj/structure/overmap/ship/target, amount, how)
	SIGNAL_HANDLER
	taken_args = list(source, target, amount, how)

/datum/unit_test/voidcrew_hauler_surrender/proc/on_lost(datum/source, obj/structure/overmap/ship/taker, amount, how)
	SIGNAL_HANDLER
	lost_args = list(source, taker, amount, how)

/datum/unit_test/voidcrew_hauler_surrender/Run()
	TEST_ASSERT(length(ambient_dialogue_lines("hauler_crew.json", "hauler", "hail")), "The hauler crew's dialogue file has no hails")
	TEST_ASSERT(length(ambient_dialogue_lines("hauler_crew.json", "hauler", "surrender")), "The hauler crew's dialogue file has no surrender lines")
	hauler = hauler_test_spawn()
	TEST_ASSERT_NOTNULL(hauler, "The hauler did not load")
	robber = allocate(/obj/structure/overmap/ship)
	var/obj/structure/overmap/trader_outpost/general/halcyon = allocate(/obj/structure/overmap/trader_outpost/general)
	var/obj/structure/overmap/trader_outpost/black_market/undertow = allocate(/obj/structure/overmap/trader_outpost/black_market)
	hauler.ship_account.account_balance = 1000
	RegisterSignal(robber, "background_credits_taken", PROC_REF(on_taken)) // COMSIG_BACKGROUND_CREDITS_TAKEN
	RegisterSignal(hauler, "background_credits_lost", PROC_REF(on_lost)) // COMSIG_BACKGROUND_CREDITS_LOST

	// A lock makes it run
	var/datum/ai_controller/npc_ship/hauler/controller = hauler.ai_controller
	TEST_ASSERT(controller.start_flight(robber), "The hauler did not run from a ship locking on")
	TEST_ASSERT_EQUAL(controller.flight_threat(), robber, "The hauler is running from the wrong ship")
	TEST_ASSERT_NULL(controller.get_target(), "The hauler took a combat target")

	// An NPC's interdictor gets nothing; a player crew's gets the hold
	var/obj/machinery/ship_combat/interdictor/interdictor = allocate(/obj/machinery/ship_combat/interdictor)
	var/obj/structure/overmap/ship/npc/pirate/npc_pirate = allocate(/obj/structure/overmap/ship/npc/pirate)
	interdictor.linked_ship_ref = WEAKREF(npc_pirate)
	SEND_SIGNAL(hauler, "ship_interdicted", interdictor, 1) // COMSIG_SHIP_INTERDICTED
	TEST_ASSERT(!hauler.surrendered, "The hauler gave up to an NPC")
	interdictor.linked_ship_ref = WEAKREF(robber)
	SEND_SIGNAL(hauler, "ship_interdicted", interdictor, 1) // COMSIG_SHIP_INTERDICTED
	interdictor.linked_ship_ref = null
	TEST_ASSERT(hauler.surrendered, "The hauler did not give up to a player crew's interdictor")

	TEST_ASSERT_EQUAL(hauler.ship_account.account_balance, 0, "Giving up left money in the hold")
	TEST_ASSERT(hauler.ship_account.account_balance < 50, "A siphon would still find money in the hold") // SIPHON_MINIMUM_TARGET_BALANCE
	var/obj/item/storage/hauler_strongbox/strongbox = hauler.strongbox_ref?.resolve()
	TEST_ASSERT_NOTNULL(strongbox, "Giving up made no strongbox")
	TEST_ASSERT(hauler.holds(strongbox), "The strongbox is not aboard the hauler")
	var/obj/item/holochip/chip = locate() in strongbox
	TEST_ASSERT_EQUAL(chip?.credits, 1000, "The strongbox does not hold the whole hold")
	TEST_ASSERT_EQUAL(length(taken_args), 4, "The robber was not told it took credits")
	TEST_ASSERT_EQUAL(taken_args[2], hauler, "The credits-taken signal names the wrong ship")
	TEST_ASSERT_EQUAL(taken_args[3], 1000, "The credits-taken signal carries the wrong amount")
	TEST_ASSERT_EQUAL(taken_args[4], "surrender", "The credits-taken signal carries the wrong source")
	TEST_ASSERT_EQUAL(length(lost_args), 4, "The hauler was not told it lost credits")
	TEST_ASSERT_EQUAL(lost_args[2], robber, "The credits-lost signal names the wrong ship")
	TEST_ASSERT_EQUAL(lost_args[3], 1000, "The credits-lost signal carries the wrong amount")
	TEST_ASSERT_EQUAL(lost_args[4], "surrender", "The credits-lost signal carries the wrong source")
	TEST_ASSERT(halcyon.is_ship_embargoed(robber), "A crew that robbed a hauler is not embargoed at Halcyon")
	TEST_ASSERT(!undertow.is_ship_embargoed(robber), "The Undertow embargoed a hauler robber")

	// Hove to, and only once
	TEST_ASSERT(hauler.is_holding_still(), "The hauler is not hove to after giving up")
	TEST_ASSERT_NULL(controller.flight_threat(), "The hauler is still running after giving up")
	TEST_ASSERT(!controller.start_flight(robber), "A hauler ran while hove to")
	taken_args = null
	TEST_ASSERT(!hauler.surrender(robber), "The hauler gave up twice")
	TEST_ASSERT_NULL(taken_args, "A second surrender paid out again")

// =========================================================================
// THE EMBARGO (Q8)
// =========================================================================

/datum/unit_test/voidcrew_hauler_embargo
	var/obj/structure/overmap/ship/spacer
	var/obj/structure/overmap/ship/pirate_hull

/datum/unit_test/voidcrew_hauler_embargo/Destroy()
	hauler_test_clear_embargo(spacer)
	hauler_test_clear_embargo(pirate_hull)
	spacer = null
	pirate_hull = null
	return ..()

/datum/unit_test/voidcrew_hauler_embargo/Run()
	var/obj/structure/overmap/trader_outpost/general/halcyon = allocate(/obj/structure/overmap/trader_outpost/general)
	var/obj/structure/overmap/trader_outpost/outfitter/quartermain = allocate(/obj/structure/overmap/trader_outpost/outfitter)
	var/obj/structure/overmap/trader_outpost/black_market/undertow = allocate(/obj/structure/overmap/trader_outpost/black_market)
	spacer = allocate(/obj/structure/overmap/ship)
	pirate_hull = allocate(/obj/structure/overmap/ship)
	pirate_hull.pirate_crew = TRUE
	var/obj/structure/overmap/ship/npc/pirate/npc_pirate = allocate(/obj/structure/overmap/ship/npc/pirate)

	TEST_ASSERT(!hauler_embargo_robber(spacer, 0, "siphon", null), "An empty take embargoed a crew")
	TEST_ASSERT(!halcyon.is_ship_embargoed(spacer), "An empty take embargoed a crew at Halcyon")
	TEST_ASSERT(!hauler_embargo_robber(npc_pirate, 500, "siphon", null), "An NPC robber was embargoed")
	TEST_ASSERT(!hauler_embargo_robber(pirate_hull, 500, "siphon", null), "A pirate hull was embargoed for robbing a hauler")
	TEST_ASSERT(!halcyon.is_ship_embargoed(pirate_hull), "A pirate hull was embargoed at Halcyon")
	TEST_ASSERT(hauler_embargo_robber(spacer, 500, "siphon", null), "A spacefaring robber was not embargoed")
	TEST_ASSERT(halcyon.is_ship_embargoed(spacer), "A spacefaring robber is not embargoed at Halcyon")
	TEST_ASSERT(quartermain.is_ship_embargoed(spacer), "A spacefaring robber is not embargoed at Quartermain")
	TEST_ASSERT(!undertow.is_ship_embargoed(spacer), "The Undertow embargoed a hauler robber")

// =========================================================================
// THE FENCE (ECO-7)
// =========================================================================

/datum/unit_test/voidcrew_hauler_fence

/datum/unit_test/voidcrew_hauler_fence/Run()
	var/datum/outpost_shop/black_market/undertow_shop = allocate(/datum/outpost_shop/black_market, null)
	var/datum/shop_buyback/black_market/hauler_cargo/window = locate() in undertow_shop.buybacks
	TEST_ASSERT_NOTNULL(window, "The Undertow does not fence hauler freight")
	TEST_ASSERT_EQUAL(window.demand, 6, "The fence's demand is not six cases a round") // BACKGROUND_HAULER_FENCE_DEMAND

	var/mob/living/carbon/human/consistent/seller = allocate(/mob/living/carbon/human/consistent)
	var/datum/bank_account/account = allocate(/datum/bank_account, "Hauler fence test", null, 1, FALSE)
	var/obj/item/card/id/advanced/card = allocate(/obj/item/card/id/advanced)
	card.registered_account = account
	TEST_ASSERT(seller.put_in_hands(card), "The seller could not hold their ID")

	var/obj/item/hauler_cargo/marked/marked = allocate(/obj/item/hauler_cargo/marked)
	var/obj/item/storage/toolbox/toolbox = allocate(/obj/item/storage/toolbox)
	TEST_ASSERT(!window.matches(marked), "The fence takes the Hijack case")
	TEST_ASSERT(!window.matches(toolbox), "The fence takes any old thing")
	TEST_ASSERT(seller.put_in_hands(marked), "The seller could not hold the marked case")
	TEST_ASSERT(!window.try_sell(seller, null, TRUE), "The fence bought a marked case")
	TEST_ASSERT_EQUAL(account.account_balance, 0, "The fence paid for a marked case")
	seller.dropItemToGround(marked)

	for(var/i in 1 to 6) // BACKGROUND_HAULER_FENCE_DEMAND
		var/obj/item/hauler_cargo/freight = allocate(/obj/item/hauler_cargo)
		TEST_ASSERT(seller.put_in_hands(freight), "The seller could not hold a freight case")
		TEST_ASSERT(window.try_sell(seller, null, TRUE), "The fence refused freight case [i] of its demand")
	TEST_ASSERT_EQUAL(account.account_balance, 1200, "Six cases did not pay 1,200 cr") // 6 x BACKGROUND_HAULER_CASE_PAY
	var/obj/item/hauler_cargo/extra = allocate(/obj/item/hauler_cargo)
	TEST_ASSERT(seller.put_in_hands(extra), "The seller could not hold the last freight case")
	TEST_ASSERT(!window.try_sell(seller, null, TRUE), "The fence kept buying after its demand ran out")
	TEST_ASSERT_EQUAL(account.account_balance, 1200, "The fence paid past its demand")

// =========================================================================
// THE DIRECTOR (ECO-7, ECO-8): its own slots, and a lost slot refills only after the delay
// =========================================================================

/// The real director with the hull load swapped for a note of which slot asked
/datum/hauler_director/unit_test
	var/list/spawn_calls = list()

/datum/hauler_director/unit_test/spawn_hauler(datum/hauler_slot/slot, serial)
	spawn_calls += slot
	return null

/datum/hauler_director/unit_test/Destroy()
	spawn_calls = null
	return ..()

/datum/unit_test/voidcrew_hauler_director

/datum/unit_test/voidcrew_hauler_director/Run()
	var/datum/hauler_director/unit_test/director = allocate(/datum/hauler_director/unit_test)
	TEST_ASSERT_EQUAL(length(director.slots), 2, "The director does not keep two haulers") // BACKGROUND_HAULER_COUNT
	var/datum/hauler_slot/yellow = director.slots[1]
	var/datum/hauler_slot/red = director.slots[2]
	TEST_ASSERT_EQUAL(yellow.zone, 2, "The first hauler does not fly in yellow") // ZONE_YELLOW
	TEST_ASSERT_EQUAL(red.zone, 3, "The second hauler does not fly in red") // ZONE_RED

	var/start = world.time + 10 MINUTES
	TEST_ASSERT(director.start(start), "The director did not start")
	TEST_ASSERT(!director.start(start), "The director started twice")
	director.tick(start - 1)
	TEST_ASSERT_EQUAL(length(director.spawn_calls), 0, "The director loaded a hauler before its slots opened")
	director.tick(start)
	TEST_ASSERT_EQUAL(length(director.spawn_calls), 1, "The director did not load one hauler on its first tick")
	TEST_ASSERT_EQUAL(director.spawn_calls[1], yellow, "The yellow slot did not load first")
	director.tick(start)
	TEST_ASSERT_EQUAL(length(director.spawn_calls), 2, "The director did not load the second hauler on the next tick")
	director.tick(start)
	TEST_ASSERT_EQUAL(length(director.spawn_calls), 2, "The director loaded over a load already under way")

	// Keep the red slot out of the way: its load "under way" would time out and reload meanwhile
	red.spawning = FALSE
	red.ready_at = INFINITY

	// A hauler that leaves frees its slot, and the slot waits out the respawn delay
	var/obj/structure/overmap/ship/npc/hauler/leaver = allocate(/obj/structure/overmap/ship/npc/hauler)
	director.fill_slot(yellow, leaver)
	TEST_ASSERT(leaver in director.live_haulers(), "A hauler in a slot is not live")
	var/lost_at = start + 5 MINUTES
	leaver.departing = TRUE
	TEST_ASSERT(!(leaver in director.live_haulers()), "A leaving hauler is still live")
	director.tick(lost_at)
	TEST_ASSERT_NULL(yellow.hauler_ref, "The slot of a leaving hauler was not freed")
	TEST_ASSERT_EQUAL(yellow.ready_at, lost_at + 20 MINUTES, "The freed slot does not wait the respawn delay") // BACKGROUND_HAULER_RESPAWN
	var/yellow_loads = 0
	for(var/datum/hauler_slot/called in director.spawn_calls)
		if(called == yellow)
			yellow_loads++
	director.tick(lost_at + 20 MINUTES - 1)
	TEST_ASSERT_EQUAL(length(director.spawn_calls), 2, "A freed slot refilled before the respawn delay")
	director.tick(lost_at + 20 MINUTES)
	TEST_ASSERT_EQUAL(length(director.spawn_calls), 3, "A freed slot did not refill after the respawn delay")
	TEST_ASSERT_EQUAL(director.spawn_calls[3], yellow, "The wrong slot refilled")
	TEST_ASSERT_EQUAL(yellow_loads, 1, "The yellow slot loaded more than once before it was freed")

	// A hauler deleted outright frees its slot the same way
	var/obj/structure/overmap/ship/npc/hauler/wreck = allocate(/obj/structure/overmap/ship/npc/hauler)
	red.ready_at = 0
	director.fill_slot(red, wreck)
	qdel(wreck)
	TEST_ASSERT_NULL(red.hauler_ref, "The slot of a deleted hauler was not freed")
	TEST_ASSERT(red.ready_at > world.time, "The slot of a deleted hauler refills at once")
