/// Banked parts in memory, with failures to order. The real queries need a database.
/datum/ship_economy_db/exchange_fake
	var/list/held = list("combat" = 0, "science" = 0, "trade" = 0, "misc" = 0)
	var/offline = FALSE
	/// Adds of this class fail, except refunds.
	var/fail_adds_of
	/// Classes log_extraction() was called with.
	var/list/logged = list()

/datum/ship_economy_db/exchange_fake/is_available()
	return !offline

/datum/ship_economy_db/exchange_fake/get_parts(ckey)
	return held.Copy()

/datum/ship_economy_db/exchange_fake/deduct_part_class(ckey, part_class, amount)
	if(held[part_class] < amount)
		return FALSE
	held[part_class] -= amount
	return TRUE

/datum/ship_economy_db/exchange_fake/add_part(ckey, part_class, quantity = 1, method = "unspecified")
	if(part_class == fail_adds_of && method != "refund")
		return FALSE
	held[part_class] += quantity
	return TRUE

/datum/ship_economy_db/exchange_fake/log_extraction(ckey, part_class, extraction_location = "unknown", part_uid = null)
	logged += part_class

/// Banked parts trade on per-class terms, one trade at a time, and are never lost.
/datum/unit_test/voidcrew_ship_parts_exchange

/datum/unit_test/voidcrew_ship_parts_exchange/Run()
	// The terms for every pair, pay:get, and every trade loses value, so no chain of trades makes parts.
	var/static/list/expected = list(
		"combat" = list("trade" = list(2, 1), "misc" = list(2, 1), "science" = list(4, 1)),
		"trade" = list("combat" = list(2, 1), "misc" = list(2, 1), "science" = list(4, 1)),
		"misc" = list("combat" = list(1, 1), "trade" = list(1, 1), "science" = list(3, 1)),
		"science" = list("combat" = list(1, 2), "trade" = list(1, 2), "misc" = list(1, 1)),
	)
	for(var/from_class in expected)
		var/list/row = expected[from_class]
		for(var/to_class in row)
			var/list/wanted = row[to_class]
			var/list/terms = ship_part_exchange_terms(from_class, to_class)
			TEST_ASSERT_NOTNULL(terms, "[from_class] -> [to_class] has no terms")
			TEST_ASSERT_EQUAL(terms[1], wanted[1], "[from_class] -> [to_class] asks for the wrong number of parts")
			TEST_ASSERT_EQUAL(terms[2], wanted[2], "[from_class] -> [to_class] gives the wrong number of parts")
			var/value_from = GLOB.ship_part_exchange_values[from_class]
			var/value_to = GLOB.ship_part_exchange_values[to_class]
			TEST_ASSERT(terms[2] * value_to < terms[1] * value_from, "[from_class] -> [to_class] doesn't lose value")
		TEST_ASSERT_NULL(ship_part_exchange_terms(from_class, from_class), "[from_class] trades for itself")
	TEST_ASSERT_NULL(ship_part_exchange_terms("gold", "misc"), "A class that isn't one has terms")
	TEST_ASSERT_NULL(ship_part_exchange_terms(1, "misc"), "A number has terms")
	var/list/table = ship_part_exchange_table()
	TEST_ASSERT_EQUAL(length(table["misc"]), 3, "The screen's table is missing pairs")
	TEST_ASSERT_EQUAL(table["science"]["combat"][2], 2, "The screen's table disagrees with the terms")

	var/datum/ship_economy_db/exchange_fake/economy = new
	var/player = "exchangetester"

	// The terms, and a log of each part gained.
	economy.held["trade"] = 5
	TEST_ASSERT_NULL(economy.exchange_parts(player, "trade", "science"), "An affordable exchange failed")
	TEST_ASSERT_EQUAL(economy.held["trade"], 1, "The exchange took the wrong number of parts")
	TEST_ASSERT_EQUAL(economy.held["science"], 1, "The exchange gave the wrong number of parts")
	TEST_ASSERT_EQUAL(length(economy.logged), 1, "The part gained wasn't logged")
	TEST_ASSERT_EQUAL(economy.logged[1], "science", "The wrong part was logged")
	TEST_ASSERT_NULL(economy.exchange_parts(player, "science", "combat"), "Science for combat failed")
	TEST_ASSERT_EQUAL(economy.held["science"], 0, "Science for combat took the wrong number of parts")
	TEST_ASSERT_EQUAL(economy.held["combat"], 2, "Science for combat gave the wrong number of parts")
	TEST_ASSERT_EQUAL(length(economy.logged), 3, "Each part gained wasn't logged")

	// Short: refused, and nothing changes.
	TEST_ASSERT_EQUAL(economy.exchange_parts(player, "trade", "science"), "You need 4 trade parts.", "A short exchange went through")
	TEST_ASSERT_EQUAL(economy.held["trade"], 1, "A refused exchange took parts")
	TEST_ASSERT_EQUAL(economy.held["science"], 0, "A refused exchange gave parts")

	// Only two different, real classes.
	economy.held["trade"] = 10
	for(var/list/pair in list(list("trade", "trade"), list("trade", "gold"), list(null, "science"), list("<b>", "misc")))
		TEST_ASSERT_EQUAL(economy.exchange_parts(player, pair[1], pair[2]), "Pick two different parts.", "[pair[1]] -> [pair[2]] was accepted")
	TEST_ASSERT_EQUAL(economy.held["trade"], 10, "A bad exchange took parts")

	// A failed add puts the paid parts back.
	economy.fail_adds_of = "combat"
	TEST_ASSERT_EQUAL(economy.exchange_parts(player, "trade", "combat"), "The exchange failed.", "A failed add reported success")
	TEST_ASSERT_EQUAL(economy.held["trade"], 10, "A failed add kept the paid parts")
	TEST_ASSERT_EQUAL(economy.held["combat"], 2, "A failed add gave a part anyway")
	economy.fail_adds_of = null

	// One at a time per player, and nothing while records are offline.
	economy.exchange_locks[player] = TRUE
	TEST_ASSERT_EQUAL(economy.exchange_parts(player, "trade", "misc"), "Already under way.", "Two exchanges ran at once")
	economy.exchange_locks -= player
	economy.offline = TRUE
	TEST_ASSERT_EQUAL(economy.exchange_parts(player, "trade", "misc"), "Shipyard records are offline.", "An exchange ran with records offline")
	economy.offline = FALSE
	TEST_ASSERT_EQUAL(economy.held["trade"], 10, "A refused exchange took parts")
	TEST_ASSERT_NULL(economy.exchange_parts(player, "trade", "misc"), "An exchange after a refusal failed")
	TEST_ASSERT(!economy.exchange_locks[player], "A finished exchange kept its lock")
	qdel(economy)

/// Bounty ship parts follow the pirate's faction, and the bounty keeps them after its ship is gone.
/datum/unit_test/voidcrew_bounty_part_weights

/datum/unit_test/voidcrew_bounty_part_weights/Run()
	var/static/list/expected = list(
		/obj/structure/overmap/ship/npc/pirate = list(/obj/item/ship_parts/combat = 70, /obj/item/ship_parts/misc = 30),
		/obj/structure/overmap/ship/npc/pirate/irs = list(/obj/item/ship_parts/trade = 70, /obj/item/ship_parts/misc = 30),
		/obj/structure/overmap/ship/npc/pirate/silverscale = list(/obj/item/ship_parts/trade = 70, /obj/item/ship_parts/misc = 30),
		/obj/structure/overmap/ship/npc/pirate/medieval = list(/obj/item/ship_parts/combat = 70, /obj/item/ship_parts/misc = 30),
		/obj/structure/overmap/ship/npc/pirate/skeleton = list(/obj/item/ship_parts/combat = 70, /obj/item/ship_parts/misc = 30),
		/obj/structure/overmap/ship/npc/pirate/interdyne = list(/obj/item/ship_parts/science = 70, /obj/item/ship_parts/misc = 30),
		/obj/structure/overmap/ship/npc/pirate/lustrous = list(/obj/item/ship_parts/science = 70, /obj/item/ship_parts/misc = 30),
		/obj/structure/overmap/ship/npc/pirate/grey = list(/obj/item/ship_parts/misc = 60, /obj/item/ship_parts/trade = 20, /obj/item/ship_parts/combat = 20),
	)
	for(var/ship_type in expected)
		var/obj/structure/overmap/ship/npc/pirate/pirate = allocate(ship_type)
		// Already resolved, so deleting the test hull doesn't make the pirate pool spawn a replacement
		pirate.spawner_resolved = TRUE
		var/list/weights = pirate.bounty_part_weights()
		var/list/wanted = expected[ship_type]
		TEST_ASSERT_EQUAL(length(weights), length(wanted), "[ship_type] pays the wrong part classes")
		for(var/part_type in wanted)
			TEST_ASSERT_EQUAL(weights[part_type], wanted[part_type], "[ship_type] weighs [part_type] wrong")
		TEST_ASSERT(weights == pirate.bounty_part_weights(), "[ship_type] builds a new weight list every call")

	// The bounty reads its ship's weights when it is posted.
	var/obj/structure/overmap/ship/npc/pirate/interdyne/lab = allocate(__IMPLIED_TYPE__)
	lab.spawner_resolved = TRUE
	var/obj/item/ship_key/key = allocate(__IMPLIED_TYPE__)
	var/datum/pirate_bounty/bounty = new(lab, key)
	TEST_ASSERT(bounty.part_weights == lab.bounty_part_weights(), "The bounty didn't take its ship's part weights")
	qdel(bounty)

