// Voidcrew defines load after the unit tests, so this mirrors SHIP_PART_EXCHANGE_RATE.
#define SHIP_PARTS_TEST_EXCHANGE_RATE 2

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

/// Banked parts trade at a fixed rate, one at a time, and are never lost.
/datum/unit_test/voidcrew_ship_parts_exchange

/datum/unit_test/voidcrew_ship_parts_exchange/Run()
	var/datum/ship_economy_db/exchange_fake/economy = new
	var/player = "exchangetester"

	// The rate, and a log of the part gained.
	economy.held["trade"] = 5
	TEST_ASSERT_NULL(economy.exchange_parts(player, "trade", "science"), "An affordable exchange failed")
	TEST_ASSERT_EQUAL(economy.held["trade"], 5 - SHIP_PARTS_TEST_EXCHANGE_RATE, "The exchange took the wrong number of parts")
	TEST_ASSERT_EQUAL(economy.held["science"], 1, "The exchange gave the wrong number of parts")
	TEST_ASSERT_EQUAL(length(economy.logged), 1, "The part gained wasn't logged")
	TEST_ASSERT_EQUAL(economy.logged[1], "science", "The wrong part was logged")

	// Short: refused, and nothing changes.
	economy.held["trade"] = SHIP_PARTS_TEST_EXCHANGE_RATE - 1
	TEST_ASSERT_EQUAL(economy.exchange_parts(player, "trade", "science"), "You need [SHIP_PARTS_TEST_EXCHANGE_RATE] trade parts.", "A short exchange went through")
	TEST_ASSERT_EQUAL(economy.held["trade"], SHIP_PARTS_TEST_EXCHANGE_RATE - 1, "A refused exchange took parts")
	TEST_ASSERT_EQUAL(economy.held["science"], 1, "A refused exchange gave parts")

	// Only two different, real classes.
	economy.held["trade"] = 10
	for(var/list/pair in list(list("trade", "trade"), list("trade", "gold"), list(null, "science"), list("<b>", "misc")))
		TEST_ASSERT_EQUAL(economy.exchange_parts(player, pair[1], pair[2]), "Pick two different parts.", "[pair[1]] -> [pair[2]] was accepted")
	TEST_ASSERT_EQUAL(economy.held["trade"], 10, "A bad exchange took parts")

	// A failed add puts the paid parts back.
	economy.fail_adds_of = "combat"
	TEST_ASSERT_EQUAL(economy.exchange_parts(player, "trade", "combat"), "The exchange failed.", "A failed add reported success")
	TEST_ASSERT_EQUAL(economy.held["trade"], 10, "A failed add kept the paid parts")
	TEST_ASSERT_EQUAL(economy.held["combat"], 0, "A failed add gave a part anyway")
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

#undef SHIP_PARTS_TEST_EXCHANGE_RATE
