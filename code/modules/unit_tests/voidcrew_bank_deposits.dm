/// Keep service ownership local while exercising real bank deposit handling.
/obj/structure/overmap/dynamic/player_outpost/bank_deposit_test
	var/turf/service_turf

/obj/structure/overmap/dynamic/player_outpost/bank_deposit_test/contains_service_turf(turf/location)
	return location == service_turf

/datum/unit_test/voidcrew_bank_coin_deposits
	var/obj/docking_port/mobile/voidcrew/test_port

/datum/unit_test/voidcrew_bank_coin_deposits/Destroy()
	if(!QDELETED(test_port))
		test_port.current_ship = null
		qdel(test_port, force = TRUE)
	return ..()

/datum/unit_test/voidcrew_bank_coin_deposits/Run()
	var/mob/living/carbon/human/consistent/user = allocate(__IMPLIED_TYPE__)
	var/obj/machinery/computer/bank_machine/bank = allocate(__IMPLIED_TYPE__)
	var/obj/item/coin/gold/coin = allocate(__IMPLIED_TYPE__)
	var/coin_value = coin.value
	TEST_ASSERT(coin_value > 0, "The deposit fixture must contain a valuable coin.")
	TEST_ASSERT(user.put_in_active_hand(coin), "The user could not hold the deposit coin.")
	TEST_ASSERT_NULL(bank.synced_bank_account, "A rebuilt bank terminal should start unlinked.")
	bank.attackby(coin, user)
	TEST_ASSERT(!QDELETED(coin), "An unlinked bank terminal consumed a coin without crediting an account.")
	TEST_ASSERT_EQUAL(coin.loc, user, "A refused deposit must leave the coin in the user's inventory.")

	var/obj/structure/overmap/ship/ship = allocate(__IMPLIED_TYPE__)
	ship.ship_account = allocate(/datum/bank_account/ship, "Coin test ship", null, 1, FALSE)
	ship.ship_account.account_balance = 0
	test_port = new(run_loc_floor_bottom_left)
	test_port.register()
	test_port.current_ship = ship
	bank.connect_to_shuttle(FALSE, test_port)
	TEST_ASSERT_EQUAL(bank.synced_bank_account, ship.ship_account, "The terminal did not link to its ship account.")
	bank.attackby(coin, user)
	TEST_ASSERT(QDELETED(coin), "An accepted ship deposit must consume its coin.")
	TEST_ASSERT_EQUAL(ship.ship_account.account_balance, coin_value, "The ship did not receive exactly the coin's value.")

	var/obj/structure/overmap/dynamic/player_outpost/bank_deposit_test/home = allocate(__IMPLIED_TYPE__)
	home.service_turf = get_step(run_loc_floor_bottom_left, NORTH)
	home.founder_ckey = "coinowner"
	home.ensure_home_services()
	home.treasury.account_balance = 200
	var/obj/machinery/computer/bank_machine/shore_bank = allocate(__IMPLIED_TYPE__, home.service_turf)
	coin = allocate(/obj/item/coin/gold)
	TEST_ASSERT(user.put_in_active_hand(coin), "The user could not hold the treasury deposit coin.")
	shore_bank.attackby(coin, user)
	TEST_ASSERT(QDELETED(coin), "An accepted treasury deposit must consume its coin.")
	TEST_ASSERT_EQUAL(shore_bank.synced_bank_account, home.treasury, "The shore terminal did not resolve its claim treasury.")
	TEST_ASSERT_EQUAL(home.treasury.account_balance, 200 + coin_value, "The claim did not receive exactly the coin's value.")
	TEST_ASSERT_EQUAL(ship.ship_account.account_balance, coin_value, "A treasury deposit changed the ship's account.")

	shore_bank.forceMove(run_loc_floor_bottom_left)
	coin = allocate(/obj/item/coin/gold)
	TEST_ASSERT(user.put_in_active_hand(coin), "The user could not hold the moved-terminal deposit coin.")
	shore_bank.attackby(coin, user)
	TEST_ASSERT_NULL(shore_bank.synced_bank_account, "A moved terminal retained its former claim's treasury.")
	TEST_ASSERT(!QDELETED(coin), "A moved terminal consumed a coin after losing its account.")
	TEST_ASSERT_EQUAL(coin.loc, user, "The moved terminal removed a refused coin from the user's inventory.")
	TEST_ASSERT_EQUAL(home.treasury.account_balance, 200 + coin_value, "A refused deposit changed the former claim balance.")
	TEST_ASSERT_EQUAL(ship.ship_account.account_balance, coin_value, "A refused deposit changed the ship balance.")
