/// Keep service ownership local while exercising real bank deposit handling.
/obj/structure/overmap/dynamic/player_outpost/bank_deposit_test
	var/turf/service_turf

/obj/structure/overmap/dynamic/player_outpost/bank_deposit_test/contains_service_turf(turf/location)
	return location == service_turf

/// Crew can switch a card between ships without moving funds or redirecting a terminal.
/datum/unit_test/voidcrew_bank_id_linking
	var/list/test_ports = list()
	var/mob/living/carbon/human/consistent/user
	var/list/test_ships = list()
	var/list/original_areas = list()
	var/list/test_areas = list()

/datum/unit_test/voidcrew_bank_id_linking/Destroy()
	for(var/obj/structure/overmap/ship/ship as anything in test_ships)
		if(user?.mind && (user.mind in ship.ship_team?.members))
			ship.ship_team.remove_member(user.mind)
	for(var/obj/docking_port/mobile/voidcrew/port as anything in test_ports)
		port.current_ship = null
		qdel(port, force = TRUE)
	for(var/turf/location as anything in original_areas)
		location.change_area(get_area(location), original_areas[location])
	QDEL_LIST(test_areas)
	return ..()

/datum/unit_test/voidcrew_bank_id_linking/proc/make_bank(turf/location, account_name, balance)
	var/area/shuttle/ship_area = new()
	test_areas += ship_area
	original_areas[location] = get_area(location)
	location.change_area(get_area(location), ship_area)
	var/obj/structure/overmap/ship/ship = allocate(/obj/structure/overmap/ship)
	test_ships += ship
	ship.ship_team = new /datum/team/voidcrew()
	ship.ship_team.ship = ship
	ship.ship_account = allocate(/datum/bank_account/ship, account_name, null, 1, FALSE)
	ship.ship_account.account_balance = balance
	var/obj/docking_port/mobile/voidcrew/port = new(location, list(get_area(location)))
	test_ports += port
	port.width = 1
	port.height = 1
	port.current_ship = ship
	port.register()
	var/obj/machinery/computer/bank_machine/bank = allocate(/obj/machinery/computer/bank_machine, location)
	bank.machine_stat = 0
	return bank

/datum/unit_test/voidcrew_bank_id_linking/Run()
	user = allocate(/mob/living/carbon/human/consistent)
	user.mind_initialize()
	var/obj/item/card/id/card = allocate(/obj/item/card/id)
	TEST_ASSERT(user.put_in_active_hand(card), "The crew member could not hold the ID.")
	var/obj/machinery/computer/bank_machine/first_bank = make_bank(run_loc_floor_bottom_left, "First ship", 1000)
	var/obj/machinery/computer/bank_machine/second_bank = make_bank(get_step(run_loc_floor_bottom_left, EAST), "Second ship", 2000)
	var/obj/structure/overmap/ship/first_ship = test_ships[1]
	var/obj/structure/overmap/ship/second_ship = test_ships[2]
	var/datum/bank_account/first_account = first_ship.ship_account
	var/datum/bank_account/second_account = second_ship.ship_account
	TEST_ASSERT_EQUAL(first_bank.synced_bank_account, first_account, "The first terminal is not linked to its own ship.")
	TEST_ASSERT_EQUAL(second_bank.synced_bank_account, second_account, "The second terminal is not linked to its own ship.")
	first_ship.enlist_crewmember(user)
	card.registered_account = first_account
	first_account.bank_cards += card
	var/obj/item/card/id/other_card = allocate(/obj/item/card/id)
	other_card.registered_account = first_account
	first_account.bank_cards += other_card

	second_bank.attackby(card, user)
	TEST_ASSERT_EQUAL(card.registered_account, first_account, "A visitor linked their ID to another ship's account.")
	TEST_ASSERT(!(card in second_account.bank_cards), "A refused ID was registered on the destination account.")

	// The membership granted by claiming or joining another crew permits a manual switch.
	second_ship.enlist_crewmember(user)
	second_bank.machine_stat |= NOPOWER
	second_bank.attackby(card, user)
	TEST_ASSERT_EQUAL(card.registered_account, first_account, "An unpowered terminal linked an ID.")
	second_bank.machine_stat &= ~NOPOWER
	user.stat = UNCONSCIOUS
	second_bank.attackby(card, user)
	TEST_ASSERT_EQUAL(card.registered_account, first_account, "An incapacitated user linked an ID.")
	user.stat = CONSCIOUS

	second_bank.attackby(card, user)
	TEST_ASSERT_EQUAL(card.registered_account, second_account, "A member of both crews could not select the second ship's account.")
	TEST_ASSERT(!(card in first_account.bank_cards), "The old account retained the switched card.")
	TEST_ASSERT(card in second_account.bank_cards, "The new account did not register the switched card.")
	TEST_ASSERT_EQUAL(other_card.registered_account, first_account, "Switching one card redirected another crew member's card.")
	second_bank.attackby(card, user)
	TEST_ASSERT_EQUAL(length(second_account.bank_cards), 1, "Repeated swipes duplicated the card registration.")

	first_bank.attackby(card, user)
	TEST_ASSERT_EQUAL(card.registered_account, first_account, "The crew member could not switch back to the first ship.")
	TEST_ASSERT(!(card in second_account.bank_cards), "Switching back left a stale registration on the second ship.")
	TEST_ASSERT_EQUAL(length(first_account.bank_cards), 2, "Switching back lost or duplicated a card registration.")
	TEST_ASSERT_EQUAL(first_bank.synced_bank_account, first_account, "Swiping redirected the first terminal's account.")
	TEST_ASSERT_EQUAL(second_bank.synced_bank_account, second_account, "Swiping redirected the second terminal's account.")
	TEST_ASSERT_EQUAL(first_account.account_balance, 1000, "Switching accounts changed the first ship's balance.")
	TEST_ASSERT_EQUAL(second_account.account_balance, 2000, "Switching accounts changed the second ship's balance.")
	TEST_ASSERT(!QDELETED(first_account) && !QDELETED(second_account), "Switching deleted a ship account.")

	second_ship.ship_team.remove_member(user.mind)
	second_bank.attackby(card, user)
	TEST_ASSERT_EQUAL(card.registered_account, first_account, "A former crew member could link an ID after leaving the roster.")
	second_ship.enlist_crewmember(user)
	second_bank.synced_bank_account = first_account
	TEST_ASSERT(!second_bank.link_id_account(card, user), "A terminal accepted a link despite mismatched ship ownership.")
	TEST_ASSERT_EQUAL(card.registered_account, first_account, "A terminal linked an ID despite mismatched ship ownership.")
	second_bank.synced_bank_account = second_account
	second_bank.forceMove(get_step(run_loc_floor_bottom_left, NORTH))
	second_bank.attackby(card, user)
	TEST_ASSERT_EQUAL(card.registered_account, first_account, "A terminal moved off its ship still linked an ID to that ship.")

/datum/unit_test/voidcrew_bank_id_siphoning/Run()
	var/mob/living/carbon/human/consistent/user = allocate(__IMPLIED_TYPE__)
	var/obj/machinery/computer/bank_machine/bank = allocate(__IMPLIED_TYPE__)
	var/obj/item/card/id/id = allocate(__IMPLIED_TYPE__)
	var/datum/bank_account/personal = allocate(/datum/bank_account, "ID siphon test", null, 1, FALSE)
	personal.account_balance = 1000
	id.registered_account = personal
	TEST_ASSERT(user.put_in_active_hand(id), "The user could not hold the account ID.")

	bank.attackby(id, user)
	TEST_ASSERT_NULL(bank.synced_bank_account, "Swiping an ID linked an unassigned bank terminal to its account.")
	bank.start_siphon(user)
	bank.process(1)
	TEST_ASSERT_EQUAL(personal.account_balance, 1000, "An unassigned bank terminal siphoned funds from an ID.")
	TEST_ASSERT_EQUAL(bank.syphoning_credits, 0, "An unassigned bank terminal created siphoned credits.")
	bank.end_siphon()

	var/datum/bank_account/ship/ship_account = allocate(/datum/bank_account/ship, "ID siphon test ship", null, 1, FALSE)
	ship_account.account_balance = 1000
	bank.synced_bank_account = ship_account
	bank.attackby(id, user)
	TEST_ASSERT_EQUAL(bank.synced_bank_account, ship_account, "Swiping an ID replaced the terminal's ship account.")
	bank.start_siphon(user)
	bank.attackby(id, user)
	bank.process(1)
	TEST_ASSERT_EQUAL(bank.synced_bank_account, ship_account, "Swiping an ID redirected an active siphon.")
	TEST_ASSERT_EQUAL(personal.account_balance, 1000, "An active bank terminal siphoned funds from an ID.")
	TEST_ASSERT_EQUAL(ship_account.account_balance, 900, "The terminal no longer siphons from its ship account.")
	TEST_ASSERT_EQUAL(bank.syphoning_credits, 100, "The terminal did not retain the credits withdrawn from its ship account.")
	bank.end_siphon()

/datum/unit_test/voidcrew_bank_coin_deposits
	var/obj/docking_port/mobile/voidcrew/test_port

/datum/unit_test/voidcrew_bank_coin_deposits/Destroy()
	for(var/mob/player in allocated)
		if(!QDELETED(player))
			player.key = null
			player.ckey = null
	if(!QDELETED(test_port))
		test_port.current_ship = null
		qdel(test_port, force = TRUE)
	return ..()

/datum/unit_test/voidcrew_bank_coin_deposits/Run()
	var/mob/living/carbon/human/consistent/user = allocate(__IMPLIED_TYPE__)
	ADD_TRAIT(user, TRAIT_PRESERVE_UI_WITHOUT_CLIENT, REF(src))
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
	shore_bank.attackby(id, user)
	TEST_ASSERT_EQUAL(id.registered_account, personal, "Swiping at an outpost linked the ID directly to its treasury.")
	TEST_ASSERT_EQUAL(shore_bank.synced_bank_account, home.treasury, "Swiping redirected the outpost terminal's account.")
	var/list/ui_data = shore_bank.ui_data(user)
	TEST_ASSERT(ui_data["is_outpost"], "The claim bank did not expose its treasury workflow.")
	TEST_ASSERT_EQUAL(ui_data["user_account"], personal.account_holder, "The claim bank did not show the held ID account.")
	TEST_ASSERT(!ui_data["can_withdraw"], "An unrecognized user could withdraw from the claim treasury.")
	TEST_ASSERT(!shore_bank.transfer_outpost_account(null, "deposit", 1), "A missing user could transfer claim funds.")
	TEST_ASSERT(!shore_bank.transfer_outpost_account(user, "withdraw", 25), "An unauthorized user could withdraw from the claim treasury.")
	var/datum/tgui/bank_ui = allocate(/datum/tgui, user, shore_bank, "BankMachine")
	world.push_usr(user, CALLBACK(shore_bank, TYPE_PROC_REF(/datum, ui_act), "deposit", list("amount" = "40"), bank_ui))
	TEST_ASSERT_EQUAL(personal.account_balance, 60, "The claim bank did not debit the payer account.")
	TEST_ASSERT_EQUAL(home.treasury.account_balance, 200 + coin_value + 40, "The claim bank did not credit the treasury.")
	TEST_ASSERT(home.treasury.transaction_history.len >= 2, "The claim bank did not record its account deposit.")
	user.key = "coinowner"
	home.founder_ckey = user.ckey
	world.push_usr(user, CALLBACK(shore_bank, TYPE_PROC_REF(/datum, ui_act), "withdraw", list("amount" = "25"), bank_ui))
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
	TEST_ASSERT_EQUAL(home.treasury.account_balance, 200 + coin_value + 15, "A refused deposit changed the former claim balance.")
	TEST_ASSERT_EQUAL(ship.ship_account.account_balance, coin_value, "A refused deposit changed the ship balance.")
