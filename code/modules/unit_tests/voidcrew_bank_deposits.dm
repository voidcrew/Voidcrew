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

	var/obj/item/card/id/id = allocate(/obj/item/card/id)
	var/datum/bank_account/personal = allocate(/datum/bank_account, "Coin test personal", null, 1, FALSE)
	personal.account_balance = 100
	id.registered_account = personal
	TEST_ASSERT(user.put_in_active_hand(id), "The user could not hold the account ID.")
	user.forceMove(home.service_turf)
	var/list/ui_data = shore_bank.ui_data(user)
	TEST_ASSERT(ui_data["is_outpost"], "The claim bank did not expose its treasury workflow.")
	TEST_ASSERT_EQUAL(ui_data["user_account"], personal.account_holder, "The claim bank did not show the held ID account.")
	TEST_ASSERT(!ui_data["can_withdraw"], "An unrecognized user could withdraw from the claim treasury.")
	TEST_ASSERT(!shore_bank.transfer_outpost_account(null, "deposit", 1), "A missing user could transfer claim funds.")
	TEST_ASSERT(!shore_bank.transfer_outpost_account(user, "withdraw", 25), "An unauthorized user could withdraw from the claim treasury.")
	TEST_ASSERT(shore_bank.transfer_outpost_account(user, "deposit", 40), "The claim bank rejected a valid ID deposit.")
	TEST_ASSERT_EQUAL(personal.account_balance, 60, "The claim bank did not debit the payer account.")
	TEST_ASSERT_EQUAL(home.treasury.account_balance, 200 + coin_value + 40, "The claim bank did not credit the treasury.")
	TEST_ASSERT(home.treasury.transaction_history.len >= 2, "The claim bank did not record its account deposit.")
	user.ckey = "coinowner"
	home.founder_ckey = user.ckey
	TEST_ASSERT(shore_bank.transfer_outpost_account(user, "withdraw", 25), "The claim bank rejected an authorized ID withdrawal.")
	TEST_ASSERT_EQUAL(personal.account_balance, 85, "The claim bank did not credit the withdrawal recipient.")
	TEST_ASSERT_EQUAL(home.treasury.account_balance, 200 + coin_value + 15, "The claim bank debited the wrong withdrawal amount.")
	shore_bank.machine_stat |= NOPOWER
	TEST_ASSERT(!shore_bank.transfer_outpost_account(user, "deposit", 1), "An unpowered claim bank accepted a transfer.")
	shore_bank.machine_stat &= ~NOPOWER
	user.stat = UNCONSCIOUS
	TEST_ASSERT(!shore_bank.transfer_outpost_account(user, "deposit", 1), "An incapacitated user transferred claim funds.")
	user.stat = CONSCIOUS

	user.drop_all_held_items()
	shore_bank.forceMove(run_loc_floor_bottom_left)
	TEST_ASSERT(!shore_bank.transfer_outpost_account(user, "deposit", 1), "A moved claim bank retained its transfer account.")
	var/list/moved_ui_data = shore_bank.ui_data(user)
	TEST_ASSERT(!moved_ui_data["is_outpost"], "A moved bank retained its claim UI state.")
	TEST_ASSERT_NULL(moved_ui_data["user_account"], "A moved bank exposed an account from its former claim.")
	TEST_ASSERT(!moved_ui_data["can_withdraw"], "A moved bank exposed withdrawal authority from its former claim.")
	TEST_ASSERT_NULL(moved_ui_data["history"], "A moved bank exposed transaction history from its former claim.")
	coin = allocate(/obj/item/coin/gold)
	TEST_ASSERT(user.put_in_active_hand(coin), "The user could not hold the moved-terminal deposit coin.")
	shore_bank.attackby(coin, user)
	TEST_ASSERT_NULL(shore_bank.synced_bank_account, "A moved terminal retained its former claim's treasury.")
	TEST_ASSERT(!QDELETED(coin), "A moved terminal consumed a coin after losing its account.")
	TEST_ASSERT_EQUAL(coin.loc, user, "The moved terminal removed a refused coin from the user's inventory.")
	TEST_ASSERT_EQUAL(home.treasury.account_balance, 200 + coin_value, "A refused deposit changed the former claim balance.")
	TEST_ASSERT_EQUAL(ship.ship_account.account_balance, coin_value, "A refused deposit changed the ship balance.")
