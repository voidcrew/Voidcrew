// Vex wants legion cores fresh or stabilized, on contracts and at the voucher window,
// and Sawbones wants every monster gland the same way.
// Fork defines compile after tests; mission item results are literals here.

/// Supply contracts refuse a rotted core, checked on the core at hand-over.
/datum/unit_test/voidcrew_fresh_cores_contract/Run()
	var/obj/structure/overmap/ship/receiving_ship = allocate(/obj/structure/overmap/ship)
	receiving_ship.ship_account = allocate(/datum/bank_account)
	var/datum/mission/mission = allocate(/datum/mission)
	mission.requires_item = TRUE
	mission.servant = receiving_ship
	mission.active = TRUE
	var/datum/mission_objective/deliver/procurement/ask = new
	ask.required_type = /obj/item/organ/monster_core/regenerative_core/legion
	ask.required_amount = 2
	mission.add_objective(ask)

	var/obj/item/organ/monster_core/regenerative_core/legion/dead = allocate(/obj/item/organ/monster_core/regenerative_core/legion)
	TEST_ASSERT(dead.go_inert(), "The fixture core would not rot")
	TEST_ASSERT(ask.matches_ask(dead), "A rotted core must still read as the asked goods, so the refusal can name it")
	TEST_ASSERT(!mission.can_turn_in(dead), "A rotted core satisfied the contract")
	TEST_ASSERT_EQUAL(mission.get_failure_reason(dead), "That core's gone dead.", "A rotted core had the wrong refusal")
	TEST_ASSERT(!mission.turn_in(run_loc_floor_bottom_left, dead), "A rotted core was accepted")
	TEST_ASSERT_EQUAL(ask.accept_item(dead, run_loc_floor_bottom_left), 0, "Direct acceptance took a rotted core") // MISSION_ITEM_REFUSED
	TEST_ASSERT(!QDELETED(dead), "A refused core was consumed")
	TEST_ASSERT_EQUAL(ask.delivered_count, 0, "A rotted core counted toward the contract")

	var/obj/item/organ/monster_core/regenerative_core/legion/fresh = allocate(/obj/item/organ/monster_core/regenerative_core/legion)
	TEST_ASSERT_EQUAL(mission.pick_turn_in_item(list(dead, fresh)), fresh, "The pad offered a rotted core ahead of a fresh one")
	TEST_ASSERT_EQUAL(mission.pick_turn_in_item(list(dead)), dead, "A lone rotted core must stay available for its refusal")

	// A core that rots while it waits on the pad is judged as it is at hand-over
	var/obj/item/organ/monster_core/regenerative_core/legion/rotting = allocate(/obj/item/organ/monster_core/regenerative_core/legion)
	TEST_ASSERT(mission.can_turn_in(rotting), "A fresh core was refused before it rotted")
	TEST_ASSERT(rotting.go_inert(), "The waiting core would not rot")
	TEST_ASSERT(!mission.turn_in(run_loc_floor_bottom_left, rotting), "A core that rotted on the pad was accepted")
	TEST_ASSERT(!QDELETED(rotting), "A core that rotted on the pad was consumed")

	TEST_ASSERT(mission.turn_in(run_loc_floor_bottom_left, fresh), "A fresh core was refused")
	TEST_ASSERT(QDELETED(fresh), "The fresh core was not consumed")
	TEST_ASSERT_EQUAL(ask.delivered_count, 1, "The fresh core did not count")
	TEST_ASSERT(!mission.turn_in(run_loc_floor_bottom_left, fresh), "A consumed core was counted twice")

	var/obj/item/organ/monster_core/regenerative_core/legion/stabilized = allocate(/obj/item/organ/monster_core/regenerative_core/legion)
	TEST_ASSERT(stabilized.preserve(), "The fixture core would not stabilize")
	TEST_ASSERT(mission.turn_in(run_loc_floor_bottom_left, stabilized), "A stabilized core was refused")
	TEST_ASSERT(QDELETED(stabilized), "The stabilized core was not consumed")
	TEST_ASSERT(QDELETED(mission), "Two good cores did not finish the contract")
	TEST_ASSERT(!QDELETED(dead), "Finishing the contract consumed the rotted core")

/// Vex's voucher window refuses a rotted core and pays for a fresh or stabilized one.
/datum/unit_test/voidcrew_fresh_cores_vouchers/Run()
	var/mob/living/carbon/human/seller = allocate(/mob/living/carbon/human/consistent, run_loc_floor_bottom_left)
	var/datum/shop_buyback/black_market/legion_core/ledger = allocate(/datum/shop_buyback/black_market/legion_core)
	ledger.demand = 5

	var/obj/item/organ/monster_core/regenerative_core/legion/dead = allocate(/obj/item/organ/monster_core/regenerative_core/legion)
	TEST_ASSERT(dead.go_inert(), "The fixture core would not rot")
	TEST_ASSERT(seller.put_in_hands(dead), "The seller could not hold the rotted core")
	TEST_ASSERT(!ledger.matches(dead), "Vex's window matched a rotted core")
	TEST_ASSERT_EQUAL(ledger.count_carried_units(seller), 0, "A rotted core counted as goods to sell")
	TEST_ASSERT_EQUAL(ledger.get_denial_reason(seller), "That core's gone dead.", "A rotted core had the wrong refusal")
	TEST_ASSERT(!ledger.try_sell(seller, null), "Vex bought a rotted core")
	TEST_ASSERT_EQUAL(ledger.try_sell_bulk(seller, null), 0, "A bulk sale took a rotted core")
	TEST_ASSERT(!QDELETED(dead), "A refused core was consumed")
	TEST_ASSERT_EQUAL(ledger.demand, 5, "A refused core used up demand")
	var/obj/item/stack/trade_voucher/unearned = locate() in seller.get_all_contents()
	TEST_ASSERT_NULL(unearned, "A rotted core paid a voucher")

	var/obj/item/organ/monster_core/regenerative_core/legion/fresh = allocate(/obj/item/organ/monster_core/regenerative_core/legion)
	TEST_ASSERT(seller.put_in_hands(fresh), "The seller could not hold the fresh core")
	TEST_ASSERT_NULL(ledger.get_denial_reason(seller), "A fresh core was refused")
	TEST_ASSERT(ledger.try_sell(seller, null), "Vex refused a fresh core")
	TEST_ASSERT(QDELETED(fresh), "The fresh core was not consumed")
	TEST_ASSERT(!QDELETED(dead), "The sale took the rotted core instead of the fresh one")
	TEST_ASSERT_EQUAL(ledger.demand, 4, "The fresh sale did not use one demand")
	var/obj/item/stack/trade_voucher/payout = locate() in seller.get_all_contents()
	TEST_ASSERT_NOTNULL(payout, "The fresh core paid no voucher")
	TEST_ASSERT_EQUAL(payout.amount, 1, "The fresh core paid the wrong number of vouchers")
	qdel(payout)

	var/obj/item/organ/monster_core/regenerative_core/legion/stabilized = allocate(/obj/item/organ/monster_core/regenerative_core/legion)
	TEST_ASSERT(stabilized.preserve(), "The fixture core would not stabilize")
	TEST_ASSERT(seller.put_in_hands(stabilized), "The seller could not hold the stabilized core")
	TEST_ASSERT(ledger.try_sell(seller, null), "Vex refused a stabilized core")
	TEST_ASSERT(QDELETED(stabilized), "The stabilized core was not consumed")
	TEST_ASSERT_EQUAL(ledger.demand, 3, "The stabilized sale did not use one demand")
	TEST_ASSERT(!QDELETED(dead), "Selling the stabilized core took the rotted one")

/// Sawbones' gland intake refuses any rotted monster gland and pays for a fresh or stabilized one.
/datum/unit_test/voidcrew_fresh_cores_clinic/Run()
	var/mob/living/carbon/human/seller = allocate(/mob/living/carbon/human/consistent, run_loc_floor_bottom_left)
	var/obj/item/card/id/id = allocate(/obj/item/card/id)
	var/datum/bank_account/account = allocate(/datum/bank_account, "Gland test", null, 1, FALSE)
	id.registered_account = account
	TEST_ASSERT(seller.put_in_hands(id), "The seller could not hold their ID")
	var/datum/shop_buyback/clinic/monster_gland/ledger = allocate(/datum/shop_buyback/clinic/monster_gland)
	ledger.demand = 5
	var/balance = account.account_balance

	var/obj/item/organ/monster_core/rush_gland/dead = allocate(/obj/item/organ/monster_core/rush_gland, seller)
	TEST_ASSERT(dead.go_inert(), "The fixture gland would not rot")
	TEST_ASSERT(!ledger.matches(dead), "Sawbones matched a rotted gland")
	TEST_ASSERT_EQUAL(ledger.count_carried_units(seller), 0, "A rotted gland counted as goods to sell")
	TEST_ASSERT_EQUAL(ledger.get_denial_reason(seller), "That core's gone dead.", "A rotted gland had the wrong refusal")
	TEST_ASSERT(!ledger.try_sell(seller, null), "Sawbones bought a rotted gland")
	TEST_ASSERT_EQUAL(ledger.try_sell_bulk(seller, null), 0, "A bulk sale took a rotted gland")
	TEST_ASSERT(!QDELETED(dead), "A refused gland was consumed")
	TEST_ASSERT_EQUAL(ledger.demand, 5, "A refused gland used up demand")
	TEST_ASSERT_EQUAL(account.account_balance, balance, "A rotted gland was paid for")

	var/obj/item/organ/monster_core/regenerative_core/legion/fresh = allocate(/obj/item/organ/monster_core/regenerative_core/legion, seller)
	TEST_ASSERT_NULL(ledger.get_denial_reason(seller), "A fresh core was refused")
	TEST_ASSERT(ledger.try_sell(seller, null), "Sawbones refused a fresh core")
	TEST_ASSERT(QDELETED(fresh), "The fresh core was not consumed")
	TEST_ASSERT(!QDELETED(dead), "The sale took the rotted gland instead of the fresh core")
	TEST_ASSERT_EQUAL(ledger.demand, 4, "The fresh sale did not use one demand")
	TEST_ASSERT_EQUAL(account.account_balance, balance + 250, "The fresh core paid the wrong amount")

	var/obj/item/organ/monster_core/rush_gland/stabilized = allocate(/obj/item/organ/monster_core/rush_gland, seller)
	TEST_ASSERT(stabilized.preserve(), "The fixture gland would not stabilize")
	TEST_ASSERT(ledger.try_sell(seller, null), "Sawbones refused a stabilized gland")
	TEST_ASSERT(QDELETED(stabilized), "The stabilized gland was not consumed")
	TEST_ASSERT(!QDELETED(dead), "Selling the stabilized gland took the rotted one")
	TEST_ASSERT_EQUAL(ledger.demand, 3, "The stabilized sale did not use one demand")
	TEST_ASSERT_EQUAL(account.account_balance, balance + 500, "The stabilized gland paid the wrong amount")
