/// Trader rental lockers stay put, ignore Knock, never hold a person, take items by click when open,
/// and still rent for 150 credits to the swiped card.
/datum/unit_test/voidcrew_trader_rental_locker

/datum/unit_test/voidcrew_trader_rental_locker/Run()
	var/obj/structure/closet/secure_closet/outpost_rental/locker = allocate(/obj/structure/closet/secure_closet/outpost_rental, run_loc_floor_bottom_left)
	var/turf/locker_turf = get_turf(locker)
	var/mob/living/carbon/human/consistent/renter = allocate(/mob/living/carbon/human/consistent, get_step(locker_turf, EAST))
	renter.set_combat_mode(FALSE)

	TEST_ASSERT(locker.anchored, "A rental locker is not anchored")
	TEST_ASSERT(!renter.start_pulling(locker), "A rental locker could be pulled")
	TEST_ASSERT(renter.pulling != locker, "A rental locker was pulled")

	var/obj/item/card/id/card = allocate(/obj/item/card/id)
	var/datum/bank_account/account = allocate(/datum/bank_account, "Locker renter", null, 1, FALSE)
	account.account_balance = 1000
	card.registered_account = account
	card.registered_name = "Locker renter"
	TEST_ASSERT(renter.put_in_active_hand(card), "The renter could not hold the ID")
	locker.attackby(card, renter)
	TEST_ASSERT_EQUAL(account.account_balance, 850, "Renting did not charge 150 credits")
	TEST_ASSERT(locker.locked, "Renting did not lock the locker")
	TEST_ASSERT_EQUAL(locker.id_card?.resolve(), card, "Renting did not bind the locker to the card")

	SEND_SIGNAL(locker_turf, COMSIG_ATOM_MAGICALLY_UNLOCKED, null, renter)
	TEST_ASSERT(locker.locked && !locker.opened, "Knock opened a rented locker")

	var/mob/living/carbon/human/consistent/stowaway = allocate(/mob/living/carbon/human/consistent, locker_turf)
	TEST_ASSERT(!locker.insertion_allowed(stowaway), "A rental locker accepts a person")
	stowaway.forceMove(locker)
	TEST_ASSERT_EQUAL(stowaway.loc, locker_turf, "A person moved straight into a rental locker stayed inside")

	locker.locked = FALSE
	TEST_ASSERT(locker.open(renter), "The unlocked rental locker would not open")
	// Swiping keeps the card in hand; put it away to free the hand
	TEST_ASSERT(renter.dropItemToGround(card), "The renter could not put the ID down")
	var/obj/item/wrench/stored = allocate(/obj/item/wrench)
	TEST_ASSERT(renter.put_in_active_hand(stored), "The renter could not hold the item to store")
	var/integrity = locker.get_integrity()
	locker.attackby(stored, renter)
	TEST_ASSERT_EQUAL(stored.loc, locker_turf, "Clicking an open rental locker with an item did not put it in")
	TEST_ASSERT_EQUAL(locker.get_integrity(), integrity, "Clicking an open rental locker with an item attacked it")
