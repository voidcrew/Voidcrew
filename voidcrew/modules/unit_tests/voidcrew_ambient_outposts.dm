/**
 * World population: tests for outpost_patrons.dm, outpost_workers.dm and outpost_angler.dm
 * in voidcrew/modules/ambient_npcs/.
 *
 * Fork defines are included after the tests, so a test uses the literal value with a comment
 * naming the define. SSambient_npcs does nothing on its own in tests (`ambient_auto`); the core's
 * tests (voidcrew_ambient_core.dm) show how to drive outposts, sites and activities by hand, and
 * give every test ambient_test_outpost() and ambient_test_room_bounds().
 *
 * The test room is 5 by 5; ambient_test_outpost() makes it a concourse whose hangar lift is its top
 * right corner (pa_tile(4, 4)). PA's NPCs keep off the tiles round the lift, so no layout here puts
 * anything they use at (3, 3), (3, 4) or (4, 3).
 *
 * voidcrew_ambient_outpost_angler fishes with PB's /datum/ambient_activity/fish (planet_fishers.dm)
 * and only passes once PB's fishing has merged (merge order PB, PA, PC, PD).
 */

/// A tile of the test room, `dx` and `dy` from its bottom left corner
/datum/unit_test/proc/pa_tile(dx, dy)
	return locate(run_loc_floor_bottom_left.x + dx, run_loc_floor_bottom_left.y + dy, run_loc_floor_bottom_left.z)

/// `outpost`'s place, with its public floor worked out again from what is in the room now
/datum/unit_test/proc/pa_place(obj/structure/overmap/trader_outpost/outpost)
	var/datum/ambient_place/outpost/place = SSambient_npcs.outpost_place(outpost)
	place.public_floor = null
	return place

/// A trader outpost of `outpost_type` (general, outfitter, black_market), mapped onto the test room like ambient_test_outpost()
/datum/unit_test/proc/pa_typed_outpost(outpost_type)
	var/obj/structure/overmap/trader_outpost/outpost = allocate(outpost_type)
	outpost.outpost_template = allocate(/datum/map_template/trader_outpost)
	outpost.outpost_template.width = run_loc_floor_top_right.x - run_loc_floor_bottom_left.x + 1
	outpost.outpost_template.height = run_loc_floor_top_right.y - run_loc_floor_bottom_left.y + 1
	outpost.template_bottom_left = run_loc_floor_bottom_left
	outpost.lobby_alcove_turfs = list(run_loc_floor_top_right)
	return outpost

/// A trader for `outpost` at `where`, running `shop_type`, behind a counter table at `counter` if given
/datum/unit_test/proc/pa_trader(obj/structure/overmap/trader_outpost/outpost, turf/where, turf/counter, shop_type)
	if(counter)
		allocate(/obj/structure/table, counter)
	var/mob/living/basic/outpost_trader/trader = allocate(/mob/living/basic/outpost_trader, where)
	trader.shop_type = shop_type
	trader.outpost = outpost
	outpost.traders += trader
	return trader

/// An NPC of `npc_type` at `where`, belonging to `place`
/datum/unit_test/proc/pa_npc(npc_type, turf/where, datum/ambient_place/place)
	var/mob/living/basic/ambient_npc/npc = allocate(npc_type, where)
	npc.set_place(place)
	return npc

// =========================================================================
// WHO COMES WHERE
// =========================================================================

/// Each role comes to the outposts the spec gives it, brings one of PA's NPCs, and wants a sensible number
/datum/unit_test/voidcrew_ambient_outpost_roles

/datum/unit_test/voidcrew_ambient_outpost_roles/Run()
	var/halcyon = /obj/structure/overmap/trader_outpost/general
	var/quartermain = /obj/structure/overmap/trader_outpost/outfitter
	var/undertow = /obj/structure/overmap/trader_outpost/black_market
	var/list/expected = list(
		/datum/ambient_outpost_role/customer = list(halcyon, quartermain, undertow),
		/datum/ambient_outpost_role/drinker = list(halcyon, quartermain, undertow),
		/datum/ambient_outpost_role/janitor = list(quartermain),
		/datum/ambient_outpost_role/gardener = list(halcyon),
		/datum/ambient_outpost_role/barback = list(undertow),
		/datum/ambient_outpost_role/dock_worker = list(quartermain),
		/datum/ambient_outpost_role/angler = list(halcyon),
		/datum/ambient_outpost_role/mechanic = list(halcyon),
		/datum/ambient_outpost_role/drinker/off_duty_pirate = list(undertow),
	)
	for(var/role_type in expected)
		var/datum/ambient_outpost_role/role = allocate(role_type)
		TEST_ASSERT(ispath(role.npc_type, /mob/living/basic/ambient_npc/outpost), "[role_type] brings nobody of PA's")
		var/list/where = expected[role_type]
		for(var/outpost_type in list(halcyon, quartermain, undertow))
			TEST_ASSERT_EQUAL(!!(outpost_type in role.outpost_types), !!(outpost_type in where), "[role_type] is wrong about coming to [outpost_type]")

	// Customers only where there is a counter; drinkers only where there is a bar
	var/obj/structure/overmap/trader_outpost/outpost = ambient_test_outpost()
	var/datum/ambient_place/outpost/place = pa_place(outpost)
	var/datum/ambient_outpost_role/customer/customers = allocate(/datum/ambient_outpost_role/customer)
	var/datum/ambient_outpost_role/drinker/drinkers = allocate(/datum/ambient_outpost_role/drinker)
	TEST_ASSERT_EQUAL(customers.wanted(place), 0, "Customers come to an outpost with no traders")
	TEST_ASSERT_EQUAL(drinkers.wanted(place), 0, "Drinkers come to an outpost with no bar")
	pa_trader(outpost, pa_tile(2, 4), null, /datum/outpost_shop/vendor/bait_shop)
	TEST_ASSERT_EQUAL(customers.wanted(place), 2, "An outpost with a trader wants [customers.wanted(place)] customers, not 2")

	// Every one of them can come to an outpost with nothing in it and not fall over
	for(var/npc_type in subtypesof(/mob/living/basic/ambient_npc/outpost))
		var/mob/living/basic/ambient_npc/npc = pa_npc(npc_type, pa_tile(1, 1), place)
		npc.pick_activity()
		npc.end_activity()
		qdel(npc)

	// ...or be found there already, holding still, and never on or beside the lift
	for(var/npc_type in subtypesof(/mob/living/basic/ambient_npc/outpost))
		var/mob/living/basic/ambient_npc/npc = pa_npc(npc_type, pa_tile(1, 1), place)
		npc.settle_in()
		TEST_ASSERT(get_dist(npc, pa_tile(4, 4)) > 1, "[npc_type] was found on or beside the lift")
		TEST_ASSERT(HAS_TRAIT(npc, TRAIT_AI_PAUSED), "[npc_type] at an empty outpost is not holding still")
		qdel(npc)

/**
 * The regulars that replaced the mapped loiterers: the mechanic (Halcyon) and the off-duty
 * pirate (the Undertow), how many of each wanted role, and the queue giving up on a crowded spot.
 */
/datum/unit_test/voidcrew_ambient_outpost_regulars

/datum/unit_test/voidcrew_ambient_outpost_regulars/Run()
	var/general = /obj/structure/overmap/trader_outpost/general
	var/outfitter = /obj/structure/overmap/trader_outpost/outfitter
	var/black_market = /obj/structure/overmap/trader_outpost/black_market

	// Halcyon: Roux runs the diner (the bar) and a second trader for customers
	var/obj/structure/overmap/trader_outpost/halcyon_outpost = pa_typed_outpost(general)
	pa_trader(halcyon_outpost, pa_tile(0, 4), null, /datum/outpost_shop/vendor/diner)
	pa_trader(halcyon_outpost, pa_tile(2, 4), null, /datum/outpost_shop/vendor/bait_shop)
	var/datum/ambient_place/outpost/halcyon_place = pa_place(halcyon_outpost)

	// Quartermain: a coffee machine for the crew room, a trader for customers
	var/obj/structure/overmap/trader_outpost/quartermain_outpost = pa_typed_outpost(outfitter)
	allocate(/obj/machinery/vending/coffee, pa_tile(0, 4))
	pa_trader(quartermain_outpost, pa_tile(2, 4), null, /datum/outpost_shop/vendor/bait_shop)
	var/datum/ambient_place/outpost/quartermain_place = pa_place(quartermain_outpost)

	// The Undertow: Dram runs the Dregs (the bar) and a second trader for customers
	var/obj/structure/overmap/trader_outpost/undertow_outpost = pa_typed_outpost(black_market)
	pa_trader(undertow_outpost, pa_tile(0, 4), null, /datum/outpost_shop/vendor/dregs_bar)
	pa_trader(undertow_outpost, pa_tile(2, 4), null, /datum/outpost_shop/vendor/bait_shop)
	var/datum/ambient_place/outpost/undertow_place = pa_place(undertow_outpost)

	// Customers: two everywhere but the Undertow, which wants one
	var/datum/ambient_outpost_role/customer/customer_role = allocate(/datum/ambient_outpost_role/customer)
	TEST_ASSERT_EQUAL(customer_role.wanted(halcyon_place), 2, "Halcyon wants [customer_role.wanted(halcyon_place)] customers, not 2")
	TEST_ASSERT_EQUAL(customer_role.wanted(quartermain_place), 2, "Quartermain wants [customer_role.wanted(quartermain_place)] customers, not 2")
	TEST_ASSERT_EQUAL(customer_role.wanted(undertow_place), 1, "The Undertow wants [customer_role.wanted(undertow_place)] customers, not 1")

	// One drinker at each bar
	var/datum/ambient_outpost_role/drinker/drinker_role = allocate(/datum/ambient_outpost_role/drinker)
	TEST_ASSERT_EQUAL(drinker_role.wanted(halcyon_place), 1, "Halcyon wants [drinker_role.wanted(halcyon_place)] drinkers, not 1")
	TEST_ASSERT_EQUAL(drinker_role.wanted(quartermain_place), 1, "Quartermain wants [drinker_role.wanted(quartermain_place)] drinkers, not 1")
	TEST_ASSERT_EQUAL(drinker_role.wanted(undertow_place), 1, "The Undertow wants [drinker_role.wanted(undertow_place)] drinkers, not 1")

	// The off-duty pirate: only the Undertow
	var/datum/ambient_outpost_role/drinker/off_duty_pirate/pirate_role = allocate(/datum/ambient_outpost_role/drinker/off_duty_pirate)
	TEST_ASSERT(!pirate_role.applies_to(halcyon_outpost), "An off-duty pirate applies to Halcyon")
	TEST_ASSERT(!pirate_role.applies_to(quartermain_outpost), "An off-duty pirate applies to Quartermain")
	TEST_ASSERT(pirate_role.applies_to(undertow_outpost), "An off-duty pirate does not apply to the Undertow")
	TEST_ASSERT_EQUAL(pirate_role.wanted(undertow_place), 1, "The Undertow wants [pirate_role.wanted(undertow_place)] off-duty pirates, not 1")

	// The mechanic: only Halcyon
	var/datum/ambient_outpost_role/mechanic/mechanic_role = allocate(/datum/ambient_outpost_role/mechanic)
	TEST_ASSERT(mechanic_role.applies_to(halcyon_outpost), "A mechanic does not apply to Halcyon")
	TEST_ASSERT(!mechanic_role.applies_to(quartermain_outpost), "A mechanic applies to Quartermain")
	TEST_ASSERT(!mechanic_role.applies_to(undertow_outpost), "A mechanic applies to the Undertow")
	TEST_ASSERT_EQUAL(mechanic_role.wanted(halcyon_place), 1, "Halcyon wants [mechanic_role.wanted(halcyon_place)] mechanics, not 1")

	// The janitor and dock worker: only Quartermain now; the barback: only the Undertow now
	var/datum/ambient_outpost_role/janitor/janitor_role = allocate(/datum/ambient_outpost_role/janitor)
	TEST_ASSERT(!janitor_role.applies_to(halcyon_outpost), "A janitor still applies to Halcyon")
	TEST_ASSERT(janitor_role.applies_to(quartermain_outpost), "A janitor does not apply to Quartermain")
	var/datum/ambient_outpost_role/dock_worker/dock_role = allocate(/datum/ambient_outpost_role/dock_worker)
	TEST_ASSERT_EQUAL(dock_role.wanted(quartermain_place), 1, "Quartermain wants [dock_role.wanted(quartermain_place)] dock workers, not 1")
	var/datum/ambient_outpost_role/barback/barback_role = allocate(/datum/ambient_outpost_role/barback)
	TEST_ASSERT(!barback_role.applies_to(halcyon_outpost), "A barback still applies to Halcyon")
	TEST_ASSERT(barback_role.applies_to(undertow_outpost), "A barback does not apply to the Undertow")

	// The floor crowd matches spec exactly, and never crosses the transient cap
	var/list/expected_crowd = list()
	expected_crowd[halcyon_place] = 7
	expected_crowd[quartermain_place] = 7
	expected_crowd[undertow_place] = 6
	for(var/datum/ambient_place/outpost/crowd_place as anything in expected_crowd)
		var/obj/structure/overmap/trader_outpost/crowd_outpost = crowd_place.outpost()
		var/total = 0
		for(var/role_type in subtypesof(/datum/ambient_outpost_role))
			var/datum/ambient_outpost_role/role = allocate(role_type)
			if(!role.npc_type || !role.applies_to(crowd_outpost))
				continue
			total += role.wanted(crowd_place)
		TEST_ASSERT_EQUAL(total, expected_crowd[crowd_place], "[crowd_outpost.type] wants [total] floor crowd, not [expected_crowd[crowd_place]]")
		TEST_ASSERT(total <= 8, "[crowd_outpost.type] wants more than the ambient outpost transient cap") // AMBIENT_OUTPOST_TRANSIENT_CAP

	// Twelve mechanics wear at least two different outfits, all from outfit_choices
	var/list/mechanic_outfits = list()
	for(var/i in 1 to 12)
		var/mob/living/basic/ambient_npc/outpost/worker/mechanic/mechanic = pa_npc(/mob/living/basic/ambient_npc/outpost/worker/mechanic, pa_tile(0, 0), halcyon_place)
		TEST_ASSERT(mechanic.outfit in mechanic.outfit_choices, "A mechanic wore an outfit not in outfit_choices")
		mechanic_outfits[mechanic.outfit] = TRUE
		qdel(mechanic)
	TEST_ASSERT(length(mechanic_outfits) >= 2, "Twelve mechanics all wore the same outfit")

	// A mechanic next to a rack starts work and drops the worker component after (on the bottom row, clear of the counters' reach)
	allocate(/obj/structure/rack, pa_tile(2, 0))
	var/mob/living/basic/ambient_npc/outpost/worker/mechanic/rack_mechanic = pa_npc(/mob/living/basic/ambient_npc/outpost/worker/mechanic, pa_tile(1, 0), halcyon_place)
	var/datum/ambient_activity/work/work = rack_mechanic.start_activity(new /datum/ambient_activity/work(rack_mechanic))
	TEST_ASSERT_NOTNULL(work, "A mechanic next to a rack could not start work")
	TEST_ASSERT_NOTNULL(rack_mechanic.GetComponent(/datum/component/outpost_ambient_worker), "A working mechanic has no worker component")
	rack_mechanic.end_activity()
	TEST_ASSERT_NULL(rack_mechanic.GetComponent(/datum/component/outpost_ambient_worker), "A mechanic kept the worker component after the job")
	qdel(rack_mechanic)

	// The pirate speaks their own line idle, and falls back to the drinker's staged line once drunk
	var/mob/living/basic/ambient_npc/outpost/drinker/off_duty_pirate/pirate = pa_npc(/mob/living/basic/ambient_npc/outpost/drinker/off_duty_pirate, pa_tile(1, 1), undertow_place)
	var/list/idle_lines = pirate.get_lines("idle") // AMBIENT_LINE_IDLE
	TEST_ASSERT("Everyone's armed in the red zone. That's why it's polite here." in idle_lines, "An off-duty pirate's idle line is not one of their own")
	pirate.drunk = 2
	var/list/staged = ambient_dialogue_lines(pirate.dialogue_file, pirate.dialogue_section, "talk_2")
	TEST_ASSERT(length(staged), "The drinker has no talk_2 staged lines to compare against")
	TEST_ASSERT_EQUAL(pirate.get_lines("talk"), staged, "A drunk off-duty pirate did not fall back to the drinker's staged line") // AMBIENT_LINE_TALK
	var/datum/outfit/pirate_outfit = new pirate.outfit()
	TEST_ASSERT_NULL(pirate_outfit.r_hand, "An off-duty pirate's outfit put something in their hand")
	TEST_ASSERT_EQUAL(pirate_outfit.back, /obj/item/claymore/cutlass, "An off-duty pirate's outfit has no cutlass on the back")
	qdel(pirate_outfit)
	qdel(pirate)

	// A drinker's finished glass is dropped, not left on a table, where there is no barback (Halcyon, now)
	var/mob/living/basic/ambient_npc/outpost/drinker/no_barback_drinker = pa_npc(/mob/living/basic/ambient_npc/outpost/drinker, pa_tile(1, 1), halcyon_place)
	var/obj/structure/table/drink_table = allocate(/obj/structure/table, pa_tile(1, 0))
	var/obj/item/reagent_containers/cup/glass/drinkingglass/glass = new(no_barback_drinker)
	no_barback_drinker.held_item = glass
	var/datum/ambient_activity/drink/bar/drink_finish = new(no_barback_drinker)
	drink_finish.table_ref = WEAKREF(drink_table)
	drink_finish.finish()
	TEST_ASSERT(QDELETED(glass), "A drinker's glass was left instead of dropped where there is no barback")

	// ambient_waiting_spot(): loiter tiles only, and none once those are crowded
	qdel(no_barback_drinker)
	var/turf/wait_tile = pa_tile(0, 0)
	halcyon_place.get_loiter_floor()
	halcyon_place.loiter_floor = list()
	halcyon_place.loiter_floor[wait_tile] = TRUE
	var/mob/living/basic/ambient_npc/outpost/customer/asker = pa_npc(/mob/living/basic/ambient_npc/outpost/customer, pa_tile(3, 0), halcyon_place)
	TEST_ASSERT_EQUAL(ambient_waiting_spot(asker, pa_tile(1, 1), 0, 3, list()), wait_tile, "A waiting spot was not the one loiter tile")
	pa_npc(/mob/living/basic/ambient_npc/outpost/customer, pa_tile(0, 1), halcyon_place)
	pa_npc(/mob/living/basic/ambient_npc/outpost/customer, pa_tile(1, 1), halcyon_place)
	TEST_ASSERT_NULL(ambient_waiting_spot(asker, pa_tile(1, 1), 0, 3, list()), "A waiting spot was found on a crowded loiter tile")
	TEST_ASSERT_NOTNULL(ambient_waiting_spot(asker, pa_tile(1, 1), 0, 3, list(), loiter = FALSE), "A work spot gave up on a crowd")

// =========================================================================
// ALREADY THERE WHEN PLAYERS COME
// =========================================================================

/**
 * Found already at the outpost: a customer at the counter part-way through their visit, a drinker
 * on a stool with a glass and at most two stages in, holding still until a player comes. Then the
 * time they stood still is added to what they were waiting for, and a drunk's slurring keeps.
 */
/datum/unit_test/voidcrew_ambient_outpost_settle

/datum/unit_test/voidcrew_ambient_outpost_settle/Run()
	// Dram behind a counter at the top left: the one tile in front of it is (0, 2). A bar stool at a table.
	var/obj/structure/overmap/trader_outpost/outpost = ambient_test_outpost()
	var/mob/living/basic/outpost_trader/dram = pa_trader(outpost, pa_tile(0, 4), pa_tile(0, 3), /datum/outpost_shop/vendor/dregs_bar)
	var/obj/structure/chair/stool/bar/stool = allocate(/obj/structure/chair/stool/bar, pa_tile(2, 1))
	allocate(/obj/structure/table, pa_tile(2, 0))
	var/datum/ambient_place/outpost/place = pa_place(outpost)

	// A customer at the counter, part-way through their visit
	var/mob/living/basic/ambient_npc/outpost/customer/customer = pa_npc(/mob/living/basic/ambient_npc/outpost/customer, pa_tile(4, 0), place)
	customer.stalls_left = 2
	TEST_ASSERT(customer.settle_in(), "A customer could not be found already at the outpost")
	var/datum/ambient_activity/shop_visit/visit = customer.activity
	TEST_ASSERT(istype(visit), "A customer found at an outpost with a free counter is [customer.activity?.name || "doing nothing"], not shopping")
	TEST_ASSERT_EQUAL(get_turf(customer), pa_tile(0, 2), "A customer was found somewhere other than the front of the counter")
	TEST_ASSERT_EQUAL(visit.stage, "counter", "A customer found at the counter is still walking to it") // VISIT_COUNTER
	TEST_ASSERT(customer.leave_at > world.time && customer.leave_at <= world.time + 4800, "A customer found at the outpost leaves in [(customer.leave_at - world.time) / 10] seconds") // PATRON_VISIT_HIGH
	TEST_ASSERT(HAS_TRAIT(customer, TRAIT_AI_PAUSED), "A customer at an empty outpost is not holding still")

	// A drinker on the stool with a glass in hand, having ordered long ago, a stage or two in at most
	var/mob/living/basic/ambient_npc/outpost/drinker/drinker = pa_npc(/mob/living/basic/ambient_npc/outpost/drinker, pa_tile(4, 1), place)
	drinker.set_bar(dram, dram, "bar_dregs")
	TEST_ASSERT(drinker.settle_in(), "A drinker could not be found already at the bar")
	var/datum/ambient_activity/drink/bar/drink = drinker.activity
	TEST_ASSERT(istype(drink), "A drinker found at the bar is [drinker.activity?.name || "doing nothing"], not drinking")
	TEST_ASSERT_EQUAL(drinker.buckled, stool, "A drinker found at the bar is not on the stool")
	TEST_ASSERT(istype(drinker.held_item, /obj/item/reagent_containers/cup/glass/drinkingglass), "A drinker found at the bar has no glass")
	TEST_ASSERT(drinker.ordered, "A drinker found at the bar still has to go and order")
	TEST_ASSERT(drinker.drunk >= 0 && drinker.drunk <= 2, "A drinker was found [drinker.drunk] stages drunk")
	TEST_ASSERT(!drinker.cut_off, "A drinker was found already cut off")
	TEST_ASSERT(HAS_TRAIT(drinker, TRAIT_AI_PAUSED), "A drinker at an empty outpost is not holding still")

	// Say they stood still for ten minutes: a player comes and they carry on where they stopped
	var/sip_before = drink.next_sip
	var/order_before = visit.order_at
	var/leave_before = customer.leave_at
	customer.paused_at = world.time - 6000
	drinker.paused_at = world.time - 6000
	SSambient_npcs.update_outpost(place, 1, list())
	TEST_ASSERT(!HAS_TRAIT(customer, TRAIT_AI_PAUSED) && !HAS_TRAIT(drinker, TRAIT_AI_PAUSED), "A player came and the outpost's people still hold still")
	TEST_ASSERT_EQUAL(drink.next_sip, sip_before + 6000, "Ten minutes standing still were not added to a drinker's next sip")
	TEST_ASSERT_EQUAL(visit.order_at, order_before + 6000, "Ten minutes standing still were not added to a customer's order")
	TEST_ASSERT_EQUAL(customer.leave_at, leave_before + 6000, "Ten minutes standing still counted towards a customer's visit")

	// A drunk's slurring does not wear off while nobody is there
	drinker.get_drunker(3 - drinker.drunk)
	TEST_ASSERT(drinker.has_status_effect(/datum/status_effect/speech/slurring/generic), "A stage 3 drinker does not slur")
	SSambient_npcs.update_outpost(place, 0, list(), 0)
	TEST_ASSERT(!drinker.has_status_effect(/datum/status_effect/speech/slurring/generic), "A drunk's slurring ran on with nobody there")
	SSambient_npcs.update_outpost(place, 1, list())
	TEST_ASSERT(drinker.has_status_effect(/datum/status_effect/speech/slurring/generic), "A drunk stopped slurring after holding still")

	// The janitor is found at something, where they may stand
	var/mob/living/basic/ambient_npc/outpost/worker/janitor/janitor = pa_npc(/mob/living/basic/ambient_npc/outpost/worker/janitor, pa_tile(4, 0), place)
	SSambient_npcs.update_outpost(place, 0, list(), 0)
	TEST_ASSERT(janitor.settle_in(), "The janitor could not be found already at work")
	TEST_ASSERT(janitor.activity?.arrived, "The janitor found at the outpost is still on their way to something")
	TEST_ASSERT(janitor.standable(get_turf(janitor)), "The janitor was found where outpost staff keep off")

// =========================================================================
// CUSTOMERS (owner item 3)
// =========================================================================

/// A customer walks up in front of the counter, says a line for that trader, gets the trader's answer, walks off with a bag; they wait behind a player and step aside for one
/datum/unit_test/voidcrew_ambient_outpost_customers

/datum/unit_test/voidcrew_ambient_outpost_customers/Run()
	// Pike behind a counter at the top of the room: the only tile in front of it is (2, 2)
	var/obj/structure/overmap/trader_outpost/outpost = ambient_test_outpost()
	var/mob/living/basic/outpost_trader/pike = pa_trader(outpost, pa_tile(2, 4), pa_tile(2, 3), /datum/outpost_shop/vendor/bait_shop)
	var/datum/ambient_place/outpost/place = pa_place(outpost)
	TEST_ASSERT_EQUAL(ambient_trader_section(pike), "pike", "Pike's customers have no lines of their own")
	TEST_ASSERT(length(ambient_dialogue_lines("outpost_patrons.json", "pike", "order")), "Pike's customers have nothing to ask for")
	TEST_ASSERT(length(ambient_dialogue_lines("outpost_patrons.json", "pike", "trader_reply")), "Pike has no answers for his customers")

	var/mob/living/basic/ambient_npc/outpost/customer/customer = pa_npc(/mob/living/basic/ambient_npc/outpost/customer, pa_tile(0, 0), place)
	TEST_ASSERT(!HAS_TRAIT(customer, TRAIT_GODMODE), "A customer cannot be hurt")
	for(var/turf/spot as anything in ambient_counter_spots(customer, pike))
		TEST_ASSERT_EQUAL(get_dist(spot, pike), 2, "A customer would be served from [spot], beside the trader")
		TEST_ASSERT(locate(/obj/structure/table) in get_step(pike, get_dir(pike, spot)), "A customer would be served from [spot], with no counter between")
	TEST_ASSERT(!customer.standable(pa_tile(2, 2)), "An NPC with no business at a counter would go and stand in front of it")

	// Up to the counter
	var/datum/ambient_activity/shop_visit/visit = customer.start_activity(new /datum/ambient_activity/shop_visit(customer, pike))
	TEST_ASSERT_NOTNULL(visit, "A customer could not visit a free counter")
	TEST_ASSERT_EQUAL(visit.spot, pa_tile(2, 2), "A customer is not headed for the front of the counter")
	customer.forceMove(visit.spot)
	TEST_ASSERT_EQUAL(customer.activity_step(1), 0, "A customer at the counter walked off at once") // AMBIENT_STEP_CONTINUE
	visit.order_at = world.time
	customer.activity_step(1)
	TEST_ASSERT(visit.ordered, "A customer at the counter never said what they wanted")

	// The trader answers in their own voice, and not over their own last line
	TEST_ASSERT(ambient_trader_answer(WEAKREF(pike), WEAKREF(customer), "outpost_patrons.json", "pike", "trader_reply"), "The trader did not answer a customer")
	TEST_ASSERT(pike.speak_cooldown > world.time, "The trader's answer did not start their pause")
	TEST_ASSERT(!ambient_trader_answer(WEAKREF(pike), WEAKREF(customer), "outpost_patrons.json", "pike", "trader_reply"), "The trader talked over their own last line")

	// Served: off with a bag, and that counter is done for this visit
	visit.done_at = world.time
	TEST_ASSERT_EQUAL(customer.activity_step(1), 2, "A served customer stayed at the counter") // AMBIENT_STEP_DONE
	TEST_ASSERT_NOTNULL(customer.held_visual, "A served customer left with nothing in hand")
	TEST_ASSERT(customer.has_visited(pike), "A customer forgot where they shopped")
	customer.end_activity()
	customer.forceMove(pa_tile(0, 0))

	// A player at the counter: the next customer waits out of reach
	var/mob/living/carbon/human/consistent/player = allocate(/mob/living/carbon/human/consistent, pa_tile(1, 2))
	var/mob/living/basic/ambient_npc/outpost/customer/second = pa_npc(/mob/living/basic/ambient_npc/outpost/customer, pa_tile(4, 0), place)
	var/datum/ambient_activity/shop_visit/queued = second.start_activity(new /datum/ambient_activity/shop_visit(second, pike))
	TEST_ASSERT_NOTNULL(queued, "A customer could not wait behind a player")
	TEST_ASSERT(get_dist(queued.spot, pike) > 2, "A customer waits within reach of a counter a player is using") // TRADER_COUNTER_RANGE
	// The player goes: they step up
	player.forceMove(pa_tile(4, 1))
	second.forceMove(queued.spot)
	TEST_ASSERT_EQUAL(second.activity_step(1), 1, "A waiting customer did not step up to a free counter") // AMBIENT_STEP_MOVE
	TEST_ASSERT_EQUAL(queued.spot, pa_tile(2, 2), "A waiting customer stepped up somewhere other than the counter")
	// A player comes back while they are at it: they make room
	second.forceMove(queued.spot)
	second.activity_step(1)
	player.forceMove(pa_tile(1, 2))
	TEST_ASSERT_EQUAL(second.activity_step(1), 1, "A customer at the counter did not make room for a player") // AMBIENT_STEP_MOVE
	TEST_ASSERT(get_dist(queued.spot, pike) > 2, "A customer made room by staying within reach of the counter")

// =========================================================================
// DRINKERS (owner item 2)
// =========================================================================

/// A drinker orders at the bar, sits, drinks a real glass, gets drunker every two strong sips, slurs, is cut off, sleeps it off on a sofa and leaves; a drink handed to them is drunk
/datum/unit_test/voidcrew_ambient_outpost_drinkers

/datum/unit_test/voidcrew_ambient_outpost_drinkers/Run()
	// Dram behind a counter at the top left; a bar stool at a table; a sofa in the corner
	var/obj/structure/overmap/trader_outpost/outpost = ambient_test_outpost()
	var/mob/living/basic/outpost_trader/dram = pa_trader(outpost, pa_tile(0, 4), pa_tile(0, 3), /datum/outpost_shop/vendor/dregs_bar)
	var/obj/structure/chair/stool/bar/stool = allocate(/obj/structure/chair/stool/bar, pa_tile(2, 1))
	allocate(/obj/structure/table, pa_tile(2, 0))
	var/obj/structure/chair/sofa/corp/sofa = allocate(/obj/structure/chair/sofa/corp, pa_tile(0, 0))
	var/datum/ambient_place/outpost/place = pa_place(outpost)
	var/mob/living/basic/ambient_npc/outpost/drinker/drinker = pa_npc(/mob/living/basic/ambient_npc/outpost/drinker, pa_tile(4, 1), place)
	drinker.set_bar(dram, dram, "bar_dregs")

	// Ordering: up to the bar
	var/datum/ambient_activity/bar_order/order = drinker.start_activity(new /datum/ambient_activity/bar_order(drinker, dram))
	TEST_ASSERT_NOTNULL(order, "A drinker could not order at a free bar")
	TEST_ASSERT_EQUAL(order.spot, pa_tile(0, 2), "A drinker orders from somewhere other than the front of the bar")
	drinker.end_activity()

	// Drinking: the bar stool, a real glass of something strong
	var/datum/ambient_activity/drink/bar/drink = drinker.start_activity(new /datum/ambient_activity/drink/bar(drinker, dram))
	TEST_ASSERT_NOTNULL(drink, "A drinker found no seat")
	TEST_ASSERT_EQUAL(drink.spot, get_turf(stool), "A drinker passed up a free bar stool at a table")
	drinker.forceMove(drink.spot)
	drinker.activity_step(1)
	TEST_ASSERT_EQUAL(drinker.buckled, stool, "A drinker did not sit on the stool")
	TEST_ASSERT(istype(drinker.held_item, /obj/item/reagent_containers/cup/glass/drinkingglass), "A drinker has no glass")
	TEST_ASSERT(drinker.glass_is_strong(), "The Dregs poured a drinker something soft")

	// Two sips of something strong: one stage drunker
	for(var/sip in 1 to 2)
		drink.next_sip = world.time
		drinker.activity_step(1)
	TEST_ASSERT_EQUAL(drinker.drunk, 1, "Two strong sips made a drinker [drinker.drunk] stages drunk, not 1")

	// Stage 3 slurs; stage 4 is cut off
	drinker.get_drunker(2)
	TEST_ASSERT(drinker.has_status_effect(/datum/status_effect/speech/slurring/generic), "A stage 3 drinker does not slur")
	drinker.get_drunker(1)
	TEST_ASSERT(drinker.cut_off, "A drinker at the last stage was not cut off")
	var/obj/item/glass = drinker.held_item
	drinker.end_activity()
	// Nobody works the bar at the test outpost, so the finished glass goes rather than onto the table
	TEST_ASSERT(QDELETED(glass) || isnull(glass.loc), "A drinker's glass was left behind where nobody clears glasses")

	// Sleeping it off on the sofa
	drinker.pick_activity()
	var/datum/ambient_activity/sleep_it_off/nap = drinker.activity
	TEST_ASSERT(istype(nap), "A drinker at the last stage did not go to sleep it off")
	TEST_ASSERT_EQUAL(nap.spot, get_turf(sofa), "A drinker went to sleep somewhere other than the sofa")
	drinker.forceMove(nap.spot)
	drinker.activity_step(1)
	TEST_ASSERT(drinker.asleep, "A drinker on the sofa is not asleep")
	TEST_ASSERT_EQUAL(drinker.buckled, sofa, "A sleeping drinker is not on the sofa")
	TEST_ASSERT(length(drinker.get_lines("talk")), "A sleeping drinker has nothing to mumble") // AMBIENT_LINE_TALK
	drinker.end_activity()
	TEST_ASSERT(!drinker.asleep, "A drinker who slept it off is still lying down")
	drinker.pick_activity()
	TEST_ASSERT(istype(drinker.activity, /datum/ambient_activity/leave), "A drinker who slept it off did not head home")

	// A drink handed over is drunk: something strong takes them further, coffee brings them back, poison they refuse
	var/mob/living/carbon/human/consistent/player = allocate(/mob/living/carbon/human/consistent, pa_tile(4, 0))
	var/mob/living/basic/ambient_npc/outpost/drinker/regular = pa_npc(/mob/living/basic/ambient_npc/outpost/drinker, pa_tile(3, 0), place)
	regular.set_bar(dram, dram, "bar_dregs")
	regular.drunk = 1
	var/obj/item/reagent_containers/cup/glass/drinkingglass/beer = allocate(/obj/item/reagent_containers/cup/glass/drinkingglass, pa_tile(4, 0))
	beer.reagents.add_reagent(/datum/reagent/consumable/ethanol/beer, 30)
	TEST_ASSERT_EQUAL(regular.item_interaction(player, beer, list()), 1, "Handing a drinker a beer did nothing") // ITEM_INTERACT_SUCCESS
	TEST_ASSERT_EQUAL(regular.drunk, 2, "A beer handed over did not make a drinker drunker")
	TEST_ASSERT(beer.reagents.total_volume < 30, "A drinker did not drink the beer handed over")
	TEST_ASSERT(!regular.accept_drink(player, beer), "A drinker drank two handed drinks back to back")
	LAZYREMOVE(regular.reaction_cooldowns, "handed")
	var/obj/item/reagent_containers/cup/glass/drinkingglass/poison = allocate(/obj/item/reagent_containers/cup/glass/drinkingglass, pa_tile(4, 0))
	poison.reagents.add_reagent(/datum/reagent/toxin/plasma, 30)
	TEST_ASSERT(!regular.accept_drink(player, poison), "A drinker drank poison")
	TEST_ASSERT_EQUAL(poison.reagents.total_volume, 30, "A drinker sipped the poison")
	LAZYREMOVE(regular.reaction_cooldowns, "handed")
	var/obj/item/reagent_containers/cup/glass/drinkingglass/coffee = allocate(/obj/item/reagent_containers/cup/glass/drinkingglass, pa_tile(4, 0))
	coffee.reagents.add_reagent(/datum/reagent/consumable/coffee, 30)
	TEST_ASSERT(regular.accept_drink(player, coffee), "A drinker would not take a coffee")
	TEST_ASSERT_EQUAL(regular.drunk, 1, "A coffee did not sober a drinker up")

	// The crew room: coffee first, then something stronger
	var/mob/living/basic/ambient_npc/outpost/drinker/crew = pa_npc(/mob/living/basic/ambient_npc/outpost/drinker, pa_tile(1, 1), place)
	crew.set_bar(null, null, "bar_crew_room")
	crew.take_drink(crew.bar_drink())
	TEST_ASSERT(!crew.glass_is_strong(), "The crew room did not start with coffee")
	crew.on_sip(FALSE)
	crew.on_sip(FALSE)
	TEST_ASSERT(crew.glass_is_strong(), "The crew room never moved on to something stronger")

// =========================================================================
// STAFF (owner item 4)
// =========================================================================

/// The janitor mops fresh mess under a wet floor sign and takes the sign back; the map's own grime, other items and a player's things are left alone; a mess reported brings them over
/datum/unit_test/voidcrew_ambient_outpost_janitor

/datum/unit_test/voidcrew_ambient_outpost_janitor/Run()
	var/obj/structure/overmap/trader_outpost/outpost = ambient_test_outpost()
	var/obj/effect/decal/cleanable/vomit/decor = allocate(/obj/effect/decal/cleanable/vomit, pa_tile(0, 0))
	var/datum/ambient_place/outpost/place = pa_place(outpost)
	var/mob/living/basic/ambient_npc/outpost/worker/janitor/janitor = pa_npc(/mob/living/basic/ambient_npc/outpost/worker/janitor, pa_tile(0, 2), place)

	// What was there when they first looked is the map's
	janitor.pick_activity()
	janitor.end_activity()
	TEST_ASSERT(HAS_TRAIT(decor, "ambient_outpost_decor"), "The map's own mess was not marked as decor") // TRAIT_AMBIENT_OUTPOST_DECOR
	TEST_ASSERT(!ambient_is_mess(decor), "The janitor would clean the map's own decor")
	var/obj/effect/decal/cleanable/dirt/dirt = allocate(/obj/effect/decal/cleanable/dirt, pa_tile(1, 0))
	TEST_ASSERT(!ambient_is_mess(dirt), "The janitor would clean ordinary dirt")

	// Fresh blood, a wrapper and a pen on one tile
	var/turf/mess_tile = pa_tile(2, 2)
	var/obj/effect/decal/cleanable/blood/blood = allocate(/obj/effect/decal/cleanable/blood, mess_tile)
	var/obj/item/trash/chips/wrapper = allocate(/obj/item/trash/chips, mess_tile)
	var/obj/item/pen/pen = allocate(/obj/item/pen, mess_tile)
	var/datum/ambient_activity/mop_mess/mop = janitor.start_activity(new /datum/ambient_activity/mop_mess(janitor))
	TEST_ASSERT_NOTNULL(mop, "The janitor found no mess to mop")
	TEST_ASSERT_EQUAL(mop.mess_tile, mess_tile, "The janitor went for the wrong tile")
	TEST_ASSERT(get_dist(mop.spot, mess_tile) <= 1, "The janitor mops from too far away")
	janitor.forceMove(mop.spot)
	janitor.activity_step(1)
	var/obj/item/clothing/suit/caution/sign = locate() in mess_tile
	TEST_ASSERT_NOTNULL(sign, "The janitor mopped without a wet floor sign")
	mop.mop_until = world.time
	janitor.activity_step(1)
	TEST_ASSERT(QDELETED(blood), "The janitor left the blood")
	TEST_ASSERT(QDELETED(wrapper), "The janitor left the wrapper")
	TEST_ASSERT(!QDELETED(pen) && pen.loc == mess_tile, "The janitor took a pen off the floor")
	TEST_ASSERT(!QDELETED(decor), "The janitor cleaned the map's decor")
	TEST_ASSERT_NOTNULL(mess_tile.GetComponent(/datum/component/wet_floor), "A mopped floor under a sign is not wet")
	mop.dry_until = world.time
	TEST_ASSERT_EQUAL(janitor.activity_step(1), 2, "The janitor never finished mopping") // AMBIENT_STEP_DONE
	TEST_ASSERT(QDELETED(sign), "The janitor left the sign behind")
	TEST_ASSERT_EQUAL(janitor.signs_left, 2, "The janitor lost a sign they took back") // WORKER_JANITOR_SIGNS
	TEST_ASSERT_NULL(mess_tile.GetComponent(/datum/component/wet_floor), "The floor is still wet with the sign gone")
	janitor.end_activity()

	// A sign a player walks off with is theirs, and the janitor has one fewer
	var/mob/living/carbon/human/consistent/player = allocate(/mob/living/carbon/human/consistent, pa_tile(4, 0))
	allocate(/obj/effect/decal/cleanable/blood, mess_tile)
	mop = janitor.start_activity(new /datum/ambient_activity/mop_mess(janitor))
	janitor.forceMove(mop.spot)
	janitor.activity_step(1)
	sign = locate() in mess_tile
	TEST_ASSERT_NOTNULL(sign, "The janitor put no sign down the second time")
	sign.forceMove(player)
	mop.mop_until = world.time
	janitor.activity_step(1)
	mop.dry_until = world.time
	janitor.activity_step(1)
	TEST_ASSERT(!QDELETED(sign) && sign.loc == player, "The janitor took a sign out of a player's hands")
	TEST_ASSERT_EQUAL(janitor.signs_left, 1, "A janitor whose sign was taken still has [janitor.signs_left] signs")
	janitor.end_activity()

	// Mess reported: they come over
	var/obj/effect/decal/cleanable/vomit/sick = allocate(/obj/effect/decal/cleanable/vomit, pa_tile(2, 0))
	ambient_outpost_report_mess(place, sick)
	TEST_ASSERT(istype(janitor.activity, /datum/ambient_activity/mop_mess), "A janitor told about a mess did not come to mop it")

/// The gardener waters the outpost's own trays and never a player's, fills the can at a sink, and keeps three tiles from the hives
/datum/unit_test/voidcrew_ambient_outpost_gardener

/datum/unit_test/voidcrew_ambient_outpost_gardener/Run()
	var/obj/structure/overmap/trader_outpost/outpost = ambient_test_outpost()
	var/obj/structure/beebox/hive = allocate(/obj/structure/beebox, pa_tile(0, 0))
	var/obj/machinery/hydroponics/constructable/own_tray = allocate(/obj/machinery/hydroponics/constructable, pa_tile(0, 2))
	own_tray.AddElement(/datum/element/outpost_property)
	var/obj/machinery/hydroponics/constructable/player_tray = allocate(/obj/machinery/hydroponics/constructable, pa_tile(2, 0))
	var/obj/structure/sink/directional/west/sink = allocate(/obj/structure/sink/directional/west, pa_tile(4, 1))
	var/datum/ambient_place/outpost/place = pa_place(outpost)
	var/mob/living/basic/ambient_npc/outpost/worker/gardener/gardener = pa_npc(/mob/living/basic/ambient_npc/outpost/worker/gardener, pa_tile(2, 2), place)
	gardener.can_water = 4 // WORKER_CAN_POURS

	var/datum/ambient_activity/tend_plants/tend = gardener.start_activity(new /datum/ambient_activity/tend_plants(gardener))
	TEST_ASSERT_NOTNULL(tend, "The gardener found no tray to water")
	TEST_ASSERT_EQUAL(tend.target_ref?.resolve(), own_tray, "The gardener went for a tray that isn't the outpost's")
	TEST_ASSERT(get_dist(tend.spot, hive) >= 3, "The gardener stands [get_dist(tend.spot, hive)] tiles from a hive")
	gardener.forceMove(tend.spot)
	gardener.activity_step(1)
	tend.done_at = world.time
	TEST_ASSERT_EQUAL(gardener.activity_step(1), 2, "The gardener never finished watering") // AMBIENT_STEP_DONE
	TEST_ASSERT(own_tray.waterlevel > 0, "The gardener's pour did not water the tray")
	TEST_ASSERT_EQUAL(player_tray.waterlevel, 0, "The gardener watered a player's tray")
	TEST_ASSERT_EQUAL(gardener.can_water, 3, "Watering a tray did not use the can")
	gardener.end_activity()

	// An empty can is filled at the sink
	gardener.can_water = 0
	tend = gardener.start_activity(new /datum/ambient_activity/tend_plants(gardener))
	TEST_ASSERT_NOTNULL(tend, "A gardener with an empty can did nothing")
	TEST_ASSERT(tend.refilling && tend.target_ref?.resolve() == sink, "A gardener with an empty can did not go to the sink")
	gardener.forceMove(tend.spot)
	gardener.activity_step(1)
	tend.done_at = world.time
	gardener.activity_step(1)
	TEST_ASSERT_EQUAL(gardener.can_water, 4, "The sink did not fill the watering can") // WORKER_CAN_POURS

/// The barback takes empty glasses off tables, never one with a drink in it or one in a hand, washes them, and walks a sleeping drunk to the lift
/datum/unit_test/voidcrew_ambient_outpost_barback

/datum/unit_test/voidcrew_ambient_outpost_barback/Run()
	var/obj/structure/overmap/trader_outpost/outpost = ambient_test_outpost()
	allocate(/obj/structure/table, pa_tile(0, 0))
	var/obj/item/reagent_containers/cup/glass/drinkingglass/empty = allocate(/obj/item/reagent_containers/cup/glass/drinkingglass, pa_tile(0, 0))
	var/obj/item/reagent_containers/cup/glass/drinkingglass/full = allocate(/obj/item/reagent_containers/cup/glass/drinkingglass, pa_tile(0, 0))
	full.reagents.add_reagent(/datum/reagent/consumable/ethanol/beer, 10)
	var/mob/living/carbon/human/consistent/player = allocate(/mob/living/carbon/human/consistent, pa_tile(4, 0))
	var/obj/item/reagent_containers/cup/glass/drinkingglass/held = allocate(/obj/item/reagent_containers/cup/glass/drinkingglass, pa_tile(4, 0))
	player.put_in_hands(held)
	allocate(/obj/structure/sink/directional/west, pa_tile(4, 1))
	var/datum/ambient_place/outpost/place = pa_place(outpost)
	var/mob/living/basic/ambient_npc/outpost/worker/barback/barback = pa_npc(/mob/living/basic/ambient_npc/outpost/worker/barback, pa_tile(2, 2), place)

	var/datum/ambient_activity/collect_glasses/collect = barback.start_activity(new /datum/ambient_activity/collect_glasses(barback))
	TEST_ASSERT_NOTNULL(collect, "The barback found no empty glass")
	TEST_ASSERT_EQUAL(collect.glass_ref?.resolve(), empty, "The barback went for a glass that isn't empty")
	barback.forceMove(collect.spot)
	barback.activity_step(1)
	collect.pick_at = world.time
	barback.activity_step(1)
	TEST_ASSERT(QDELETED(empty), "The barback left the empty glass")
	TEST_ASSERT(!QDELETED(full) && full.reagents.total_volume, "The barback took a glass with a drink in it")
	TEST_ASSERT(!QDELETED(held) && held.loc == player, "The barback took a glass out of a player's hand")
	TEST_ASSERT_EQUAL(barback.glasses, 1, "The barback's tray holds [barback.glasses] glasses, not 1")
	barback.end_activity()

	var/datum/ambient_activity/wash_glasses/wash = barback.start_activity(new /datum/ambient_activity/wash_glasses(barback))
	TEST_ASSERT_NOTNULL(wash, "The barback had nowhere to wash the glasses")
	barback.forceMove(wash.spot)
	barback.activity_step(1)
	wash.done_at = world.time
	barback.activity_step(1)
	TEST_ASSERT_EQUAL(barback.glasses, 0, "Washing up left glasses on the tray")
	barback.end_activity()

	// A drinker asleep where they stand: the barback wakes them and walks them out
	var/mob/living/basic/ambient_npc/outpost/drinker/drunk = pa_npc(/mob/living/basic/ambient_npc/outpost/drinker, pa_tile(0, 2), place)
	drunk.start_activity(new /datum/ambient_activity/sleep_it_off(drunk))
	drunk.activity_step(1)
	TEST_ASSERT(drunk.asleep, "A drinker sleeping it off is not asleep")
	var/datum/ambient_activity/escort/escort = barback.start_activity(new /datum/ambient_activity/escort(barback, drunk))
	TEST_ASSERT_NOTNULL(escort, "The barback would not walk a sleeping drinker out")
	barback.forceMove(pa_tile(1, 2))
	barback.activity_step(1)
	TEST_ASSERT(istype(drunk.activity, /datum/ambient_activity/leave), "A drinker the barback woke did not head for the lift")
	TEST_ASSERT(!drunk.asleep, "A drinker walked out is still lying down")
	TEST_ASSERT_EQUAL(barback.activity_step(1), 0, "The barback left the drinker's side") // AMBIENT_STEP_CONTINUE

/// On the convoy the dock worker carries crates from the lift to the counter and back, a few times; the crates are only a look
/datum/unit_test/voidcrew_ambient_outpost_dock_workers

/datum/unit_test/voidcrew_ambient_outpost_dock_workers/Run()
	var/obj/structure/overmap/trader_outpost/outpost = ambient_test_outpost()
	var/mob/living/basic/outpost_trader/sarge = pa_trader(outpost, pa_tile(0, 4), null, null)
	outpost.trader = sarge
	var/datum/ambient_place/outpost/place = pa_place(outpost)
	var/mob/living/basic/ambient_npc/outpost/worker/dock/worker = pa_npc(/mob/living/basic/ambient_npc/outpost/worker/dock, pa_tile(0, 0), place)

	// The convoy comes on a timer, players or not: with nobody on the concourse nobody stirs
	SEND_SIGNAL(outpost, "trader_outpost_convoy") // COMSIG_TRADER_OUTPOST_CONVOY
	TEST_ASSERT(!istype(worker.activity, /datum/ambient_activity/convoy_unload), "The dock worker unloaded a convoy with nobody on the concourse")
	SSambient_npcs.update_outpost(place, 1, list())
	SEND_SIGNAL(outpost, "trader_outpost_convoy") // COMSIG_TRADER_OUTPOST_CONVOY
	var/datum/ambient_activity/convoy_unload/unload = worker.activity
	TEST_ASSERT(istype(unload), "The convoy did not set the dock worker unloading")
	TEST_ASSERT(get_dist(unload.pickup, pa_tile(4, 4)) <= 3, "The dock worker picks up crates away from the lift")
	TEST_ASSERT(get_dist(unload.dropoff, sarge) > 2, "The dock worker drops crates within reach of the counter") // TRADER_COUNTER_RANGE
	for(var/trip in 1 to 3) // WORKER_CONVOY_TRIPS
		worker.forceMove(unload.pickup)
		worker.activity_step(1)
		unload.wait_until = world.time
		TEST_ASSERT_EQUAL(worker.activity_step(1), 1, "The dock worker did not set off with a crate on trip [trip]") // AMBIENT_STEP_MOVE
		TEST_ASSERT(unload.carrying && worker.held_visual, "The dock worker is not carrying a crate on trip [trip]")
		worker.forceMove(unload.dropoff)
		worker.activity_step(1)
		unload.wait_until = world.time
		var/step = worker.activity_step(1)
		TEST_ASSERT_EQUAL(step, trip == 3 ? 2 : 1, "The dock worker's trip [trip] ended wrong") // AMBIENT_STEP_DONE, AMBIENT_STEP_MOVE
		TEST_ASSERT(!unload.carrying && !worker.held_visual, "The dock worker kept a crate after setting it down")
	TEST_ASSERT_NULL(locate(/obj/structure/closet/crate) in range(5, worker), "Carrying a convoy crate made a real crate")

// =========================================================================
// THE ANGLER (owner item 5)
// =========================================================================

/**
 * The angler takes a spot at the pond's edge with a chair, fishes there with PB's fishing, shows
 * Pike a catch that is only a picture, has a word when a player nearby lands a fish, and takes
 * their chair with them. Needs PB's /datum/ambient_activity/fish (planet_fishers.dm).
 */
/datum/unit_test/voidcrew_ambient_outpost_angler
	/// The test room tile turned into the pond, and what it was
	var/turf/pond_tile
	var/pond_tile_type
	var/pond_tile_baseturfs

/datum/unit_test/voidcrew_ambient_outpost_angler/Destroy()
	if(pond_tile && pond_tile_type)
		pond_tile.ChangeTurf(pond_tile_type, pond_tile_baseturfs)
	pond_tile = null
	return ..()

/datum/unit_test/voidcrew_ambient_outpost_angler/Run()
	var/obj/structure/overmap/trader_outpost/outpost = ambient_test_outpost()
	pond_tile = pa_tile(0, 4)
	pond_tile_type = pond_tile.type
	pond_tile_baseturfs = pond_tile.baseturfs
	pond_tile = pond_tile.ChangeTurf(/turf/open/water/outpost_pond)
	// Pike's counter on the right, out of reach of the pond's edge; the one tile in front of it is (2, 1)
	var/mob/living/basic/outpost_trader/pike = pa_trader(outpost, pa_tile(4, 1), pa_tile(3, 1), /datum/outpost_shop/vendor/bait_shop)
	var/datum/ambient_place/outpost/place = pa_place(outpost)
	var/mob/living/basic/ambient_npc/outpost/angler/angler = pa_npc(/mob/living/basic/ambient_npc/outpost/angler, pa_tile(1, 1), place)

	// A spot at the edge, with a chair
	TEST_ASSERT(angler.find_pond_spot(), "The angler found no spot at the pond")
	TEST_ASSERT_EQUAL(angler.water, pond_tile, "The angler is fishing into something that isn't the pond")
	TEST_ASSERT(angler.fishing_spot.Adjacent(pond_tile) && !istype(angler.fishing_spot, /turf/open/water), "The angler's spot is not at the water's edge")
	var/obj/structure/chair/chair = locate() in angler.fishing_spot
	TEST_ASSERT_NOTNULL(chair, "The angler brought no chair")

	// Fishing: PB's activity, anchored on the water
	angler.pick_activity()
	TEST_ASSERT(istype(angler.activity, /datum/ambient_activity/fish), "The angler is [angler.activity?.name || "doing nothing"], not fishing (PB's fishing activity)")
	angler.end_activity()

	// A catch for Pike: only a picture, and the pond is not touched
	var/datum/ambient_activity/show_catch/show = angler.start_activity(new /datum/ambient_activity/show_catch(angler))
	TEST_ASSERT_NOTNULL(show, "The angler could not show Pike a catch")
	TEST_ASSERT(ispath(show.fish_type, /obj/item/fish), "The angler is holding up [show.fish_type], not a fish")
	TEST_ASSERT_EQUAL(get_dist(show.spot, pike), 2, "The angler shows Pike the fish from somewhere other than his counter")
	TEST_ASSERT_NULL(locate(/obj/item/fish) in range(5, angler), "Showing Pike a catch made a real fish")
	angler.forceMove(show.spot)
	angler.activity_step(1)
	show.next_step_at = world.time
	angler.activity_step(1)
	angler.forceMove(angler.fishing_spot)
	angler.activity_step(1)
	show.next_step_at = world.time
	TEST_ASSERT_EQUAL(angler.activity_step(1), 2, "The angler never let the fish go") // AMBIENT_STEP_DONE
	TEST_ASSERT_NULL(angler.held_visual, "The angler is still holding the fish they let go")
	TEST_ASSERT_NULL(locate(/obj/item/fish) in range(5, angler), "Letting a fish go made a real fish")
	angler.end_activity()

	// A player near them lands a fish: a word from the angler
	var/mob/living/carbon/human/consistent/player = allocate(/mob/living/carbon/human/consistent, pa_tile(4, 0))
	angler.watch_player(player)
	SEND_SIGNAL(player, "mob_complete_fishing", null, TRUE) // COMSIG_MOB_COMPLETE_FISHING
	TEST_ASSERT(LAZYACCESS(angler.reaction_cooldowns, "player_fish") > world.time, "The angler said nothing about a player's catch")

	// Their chair goes with them
	qdel(angler)
	TEST_ASSERT(QDELETED(chair), "The angler left their folding chair behind")

	// Found already at the pond when players come: in a chair at the edge, with a line out
	var/mob/living/basic/ambient_npc/outpost/angler/regular = pa_npc(/mob/living/basic/ambient_npc/outpost/angler, pa_tile(1, 1), place)
	TEST_ASSERT(regular.settle_in(), "The angler could not be found already at the pond")
	var/datum/ambient_activity/fish/fishing = regular.activity
	TEST_ASSERT(istype(fishing), "The angler found at the pond is [regular.activity?.name || "doing nothing"], not fishing (PB's fishing activity)")
	TEST_ASSERT_NOTNULL(fishing.float, "The angler found at the pond has no line in the water")
	TEST_ASSERT(istype(regular.buckled, /obj/structure/chair), "The angler found at the pond is not in a chair")
	TEST_ASSERT(get_dist(regular, pond_tile) <= 2, "The angler found at the pond is sitting away from the water")
	TEST_ASSERT(HAS_TRAIT(regular, TRAIT_AI_PAUSED), "The angler at an empty outpost is not holding still")

// =========================================================================
// KEEPING CLEAR
// =========================================================================

/// PA's NPCs never go and stand in or beside a doorway, in the lift's mouth, in the pond, within two tiles of a hive, or in the kingpin's lounge
/datum/unit_test/voidcrew_ambient_outpost_keep_clear

/datum/unit_test/voidcrew_ambient_outpost_keep_clear/Run()
	var/obj/structure/overmap/trader_outpost/outpost = ambient_test_outpost()
	allocate(/obj/machinery/door/airlock/public, pa_tile(0, 2))
	allocate(/obj/structure/beebox, pa_tile(0, 0))
	var/datum/ambient_place/outpost/place = pa_place(outpost)
	var/mob/living/basic/ambient_npc/outpost/customer/npc = pa_npc(/mob/living/basic/ambient_npc/outpost/customer, pa_tile(2, 4), place)
	TEST_ASSERT(!npc.standable(pa_tile(0, 2)), "An outpost NPC would stand in a doorway")
	TEST_ASSERT(!npc.standable(pa_tile(0, 3)), "An outpost NPC would stand right in front of a door")
	// The janitor never leaves a doorway wet
	TEST_ASSERT(ambient_by_a_door(pa_tile(0, 3)) && !ambient_by_a_door(pa_tile(3, 1)), "The doorway check is wrong")
	TEST_ASSERT(!npc.standable(pa_tile(3, 3)), "An outpost NPC would stand in the lift's mouth")
	TEST_ASSERT(!npc.standable(pa_tile(2, 0)), "An outpost NPC would stand two tiles from a hive")
	TEST_ASSERT(npc.standable(pa_tile(3, 0)), "An outpost NPC may not stand three tiles from a hive")
	TEST_ASSERT(npc.standable(pa_tile(3, 1)), "An outpost NPC may not stand in the middle of the floor")
	TEST_ASSERT(npc.standable(pa_tile(1, 4)), "An outpost NPC may not stand by the top wall")
	// A railing blocks an edge, not the tile: people queue on railed lanes
	allocate(/obj/structure/railing, pa_tile(4, 1))
	TEST_ASSERT(npc.standable(pa_tile(4, 1)), "An outpost NPC may not stand on a tile with a railing along one edge")
	// The kingpin's lounge: nobody stands near his seat, and nobody sits within four tiles of it
	allocate(/obj/effect/landmark/bounty_kingpin/seat, pa_tile(4, 0))
	TEST_ASSERT(!npc.standable(pa_tile(3, 0)), "An outpost NPC would stand in the kingpin's lounge")
	var/obj/structure/chair/lounge_chair = allocate(/obj/structure/chair, pa_tile(1, 4))
	TEST_ASSERT(!npc.seat_usable(lounge_chair), "An outpost NPC would sit in the kingpin's lounge")

/// A fight near them: visitors duck and leave by the lift; the staff duck and stay at work
/datum/unit_test/voidcrew_ambient_outpost_violence

/datum/unit_test/voidcrew_ambient_outpost_violence/Run()
	var/obj/structure/overmap/trader_outpost/outpost = ambient_test_outpost()
	var/datum/ambient_place/outpost/place = pa_place(outpost)
	var/mob/living/basic/ambient_npc/outpost/customer/customer = pa_npc(/mob/living/basic/ambient_npc/outpost/customer, pa_tile(0, 0), place)
	var/mob/living/basic/ambient_npc/outpost/worker/janitor/janitor = pa_npc(/mob/living/basic/ambient_npc/outpost/worker/janitor, pa_tile(1, 0), place)
	var/mob/living/carbon/human/consistent/brawler = allocate(/mob/living/carbon/human/consistent, pa_tile(2, 2))
	SEND_SIGNAL(outpost, "trader_outpost_violence", brawler) // COMSIG_TRADER_OUTPOST_VIOLENCE
	TEST_ASSERT(istype(customer.activity, /datum/ambient_activity/leave), "A customer stayed through a fight")
	TEST_ASSERT(istype(janitor.activity, /datum/ambient_activity/duck), "The janitor did not duck in a fight")
	TEST_ASSERT(janitor.crouching, "The ducking janitor is not down")
	janitor.activity.ends_at = world.time
	TEST_ASSERT_EQUAL(janitor.activity_step(1), 2, "The janitor never got up again") // AMBIENT_STEP_DONE
	janitor.end_activity()
	TEST_ASSERT(!janitor.crouching, "The janitor stayed down after the fight")
	TEST_ASSERT(!janitor.fading, "The janitor left over a fight")

// =========================================================================
// KILLING
// =========================================================================

/**
 * Every outpost NPC can be killed: they die of their wounds and drop 5 to 30 cr once, never again
 * after a revive, and the outpost's turrets count them as its own. A killed person's place stays
 * empty a good while, made up neither in place nor off the lift; the outpost's people drop no more
 * than 300 cr between them; a blow to one is violence at the outpost; bodies are taken away.
 */
/datum/unit_test/voidcrew_ambient_outpost_deaths

/datum/unit_test/voidcrew_ambient_outpost_deaths/Run()
	var/obj/structure/overmap/trader_outpost/outpost = ambient_test_outpost()
	var/datum/ambient_place/outpost/place = pa_place(outpost)

	// Each of them dies, and drops a little cash, once
	var/turf/spot = pa_tile(1, 1)
	var/list/types = subtypesof(/mob/living/basic/ambient_npc/outpost) + subtypesof(/mob/living/basic/ambient_npc/recruiter)
	for(var/npc_type in types)
		place.cash_dropped = 0
		var/cash_before = ambient_test_cash_on(spot)
		var/mob/living/basic/ambient_npc/npc = pa_npc(npc_type, spot, place)
		TEST_ASSERT(!HAS_TRAIT(npc, TRAIT_GODMODE), "[npc_type] cannot be hurt")
		TEST_ASSERT(FACTION_TURRET in npc.faction, "The outpost's turrets would shoot [npc_type]")
		npc.apply_damage(npc.maxHealth * 2, BRUTE)
		TEST_ASSERT_EQUAL(npc.stat, DEAD, "[npc_type] did not die of their wounds")
		var/dropped = ambient_test_cash_on(spot) - cash_before
		TEST_ASSERT(dropped >= 5 && dropped <= 30, "[npc_type] dropped [dropped] cr, not 5 to 30") // AMBIENT_DEATH_CASH_LOW/HIGH
		npc.revive(ADMIN_HEAL_ALL)
		npc.death()
		TEST_ASSERT_EQUAL(ambient_test_cash_on(spot) - cash_before, dropped, "[npc_type] dropped cash again after a revive")
		qdel(npc)

	// A killed person's place stays empty a good while
	var/datum/ambient_outpost_role/core_test/role = allocate(/datum/ambient_outpost_role/core_test)
	role.npc_type = /mob/living/basic/ambient_npc/outpost/customer
	role.max_count = 1
	var/list/roles = list(role)
	SSambient_npcs.update_outpost(place, 0, roles, 5)
	TEST_ASSERT_EQUAL(place.count_role(role.type), 1, "The role was not filled in place")
	var/list/settled = place.living_npcs()
	var/mob/living/basic/ambient_npc/victim = settled[1]
	victim.apply_damage(victim.maxHealth * 2, BRUTE)
	TEST_ASSERT_EQUAL(place.killed_slots(role.type), 1, "A killing did not leave its place empty")
	var/list/until = place.killed_until[role.type]
	TEST_ASSERT(until[1] - world.time >= 11900 && until[1] - world.time <= 12000, "A killed person's place opens again in [(until[1] - world.time) / 10] seconds, not twenty minutes") // AMBIENT_OUTPOST_KILLED_SLOT_TIME
	// Nobody there: the body goes, and nobody is made in their place
	place.needs_settling = TRUE
	TEST_ASSERT_EQUAL(SSambient_npcs.update_outpost(place, 0, roles, 5), 0, "A killed person was made up in place at once")
	TEST_ASSERT(QDELETED(victim), "A body stayed at an outpost nobody is on")
	// A player comes: nobody off the lift for them either
	for(var/i in 1 to 3)
		place.arrivals_at = world.time
		SSambient_npcs.update_outpost(place, 1, roles)
	TEST_ASSERT_EQUAL(place.count_role(role.type), 0, "A killed person was replaced off the lift at once")
	// Once their place opens again, someone comes
	until[1] = world.time - 1
	place.arrivals_at = world.time
	SSambient_npcs.update_outpost(place, 1, roles)
	TEST_ASSERT_EQUAL(place.count_role(role.type), 1, "A killed person's place never opened again")
	for(var/mob/living/basic/ambient_npc/arrival in pa_tile(4, 4))
		arrival.forceMove(pa_tile(0, 4))

	// The outpost's people drop no more than 300 cr between them in a round
	place.cash_dropped = 295
	var/turf/purse_spot = pa_tile(0, 0)
	var/mob/living/basic/ambient_npc/outpost/customer/rich = pa_npc(/mob/living/basic/ambient_npc/outpost/customer, purse_spot, place)
	rich.death()
	var/last_cash = ambient_test_cash_on(purse_spot)
	TEST_ASSERT(last_cash <= 5, "Someone dropped [last_cash] cr with 5 left under the outpost's cap") // AMBIENT_OUTPOST_CASH_CAP
	var/mob/living/basic/ambient_npc/outpost/customer/broke = pa_npc(/mob/living/basic/ambient_npc/outpost/customer, purse_spot, place)
	broke.death()
	TEST_ASSERT_EQUAL(ambient_test_cash_on(purse_spot), last_cash, "Someone dropped cash past the outpost's cap")

	// A real blow to one of them is violence at the outpost: a strike, and everyone near ducks and goes
	var/mob/living/carbon/human/consistent/brute = allocate(/mob/living/carbon/human/consistent, pa_tile(4, 0))
	brute.mind_initialize()
	var/mob/living/basic/ambient_npc/outpost/customer/witness = pa_npc(/mob/living/basic/ambient_npc/outpost/customer, pa_tile(2, 0), place)
	var/mob/living/basic/ambient_npc/outpost/customer/target = pa_npc(/mob/living/basic/ambient_npc/outpost/customer, pa_tile(3, 1), place)
	SEND_SIGNAL(target, COMSIG_ATOM_WAS_ATTACKED, brute, ATTACKER_DAMAGING_ATTACK)
	TEST_ASSERT(outpost.aggressor_strikes[brute.mind], "A blow to one of the outpost's people was no strike")
	TEST_ASSERT(istype(witness.activity, /datum/ambient_activity/leave), "Nobody near ducked and left when one of the outpost's people was hit")

	// With players there a body lies a while, then is taken away
	var/mob/living/basic/ambient_npc/outpost/customer/body = pa_npc(/mob/living/basic/ambient_npc/outpost/customer, pa_tile(1, 2), place)
	body.death()
	SSambient_npcs.update_outpost(place, 1, list())
	TEST_ASSERT(!body.fading && !QDELETED(body), "A body was taken away the moment someone died in front of players")
	body.timeofdeath = world.time - 3001 // AMBIENT_OUTPOST_BODY_TIME
	SSambient_npcs.update_outpost(place, 1, list())
	TEST_ASSERT(QDELETED(body) || body.fading, "A body lay at the outpost past five minutes with players there")

/// Nobody new comes up the lift while someone is still in it
/datum/unit_test/voidcrew_ambient_outpost_lift_one_at_a_time

/datum/unit_test/voidcrew_ambient_outpost_lift_one_at_a_time/Run()
	var/obj/structure/overmap/trader_outpost/outpost = pa_typed_outpost(/obj/structure/overmap/trader_outpost/general)
	outpost.lobby_alcove_turfs = list(run_loc_floor_top_right, get_step(run_loc_floor_top_right, WEST))
	TEST_ASSERT_NOTNULL(SSambient_npcs.lift_arrival_turf(outpost), "An empty lift had no room for an arrival")
	var/mob/living/basic/ambient_npc/waiting = allocate(/mob/living/basic/ambient_npc, run_loc_floor_top_right)
	TEST_ASSERT_NULL(SSambient_npcs.lift_arrival_turf(outpost), "Someone came up while [waiting] was still in the lift")
	waiting.forceMove(run_loc_floor_bottom_left)
	TEST_ASSERT_NOTNULL(SSambient_npcs.lift_arrival_turf(outpost), "The lift stayed shut after [waiting] stepped out")
