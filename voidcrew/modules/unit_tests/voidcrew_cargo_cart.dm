/// Keep this fixture on existing test ground; cart, account and permission behavior are real.
/obj/structure/overmap/dynamic/player_outpost/cargo_cart_test
	var/turf/service_turf

/obj/structure/overmap/dynamic/player_outpost/cargo_cart_test/contains_service_turf(turf/location)
	return location == service_turf

/// Substitute only the ship lookup; both consoles use the ship's real shared controller.
/obj/machinery/computer/voidcrew_cargo/cargo_loan_test
	var/obj/structure/overmap/ship/loan_ship

/obj/machinery/computer/voidcrew_cargo/cargo_loan_test/get_cargo_shuttle()
	if(QDELETED(loan_ship))
		return null
	return loan_ship.get_cargo_shuttle()

/obj/machinery/computer/voidcrew_cargo/cargo_loan_test/Destroy()
	. = ..()
	loan_ship = null

/// Exercise failed deposits without changing normal account bookkeeping.
/datum/bank_account/cargo_loan_test
	var/refuse_payment = FALSE

/datum/bank_account/cargo_loan_test/adjust_money(amount, reason)
	if(refuse_payment)
		return FALSE
	return ..()

/datum/unit_test/voidcrew_cargo_loan_once/Run()
	var/obj/structure/overmap/ship/ship = allocate(__IMPLIED_TYPE__)
	var/datum/voidcrew_cargo_shuttle/ferry = ship.get_cargo_shuttle()
	var/obj/machinery/computer/voidcrew_cargo/cargo_loan_test/console = allocate(__IMPLIED_TYPE__)
	var/obj/machinery/computer/voidcrew_cargo/cargo_loan_test/other_console = allocate(__IMPLIED_TYPE__)
	console.loan_ship = ship
	other_console.loan_ship = ship
	TEST_ASSERT_EQUAL(console.get_cargo_shuttle(), ferry, "The first console must resolve the ship's shared loan offer.")
	TEST_ASSERT_EQUAL(other_console.get_cargo_shuttle(), ferry, "The second console must resolve the same loan offer.")
	var/obj/machinery/computer/bank_machine/bank = allocate(__IMPLIED_TYPE__)
	var/datum/bank_account/account = allocate(/datum/bank_account, "Cargo loan test", null, 1, FALSE)
	account.account_balance = 1000
	bank.synced_bank_account = account
	console.link_ship_bank(bank)
	other_console.link_ship_bank(bank)
	ferry.linked_console = console
	var/mob/living/carbon/human/consistent/user = allocate(__IMPLIED_TYPE__)
	var/datum/tgui/ui = allocate(/datum/tgui, user, console, "Cargo")
	var/datum/tgui/other_ui = allocate(/datum/tgui, user, other_console, "Cargo")
	var/datum/callback/accept = CALLBACK(console, TYPE_PROC_REF(/datum, ui_act), "accept_loan", list(), ui)
	var/datum/callback/other_accept = CALLBACK(other_console, TYPE_PROC_REF(/datum, ui_act), "accept_loan", list(), other_ui)
	TEST_ASSERT(ferry.receive_loan_offer(/datum/voidcrew_shuttle_loan), "The idle shuttle must receive a loan offer.")
	var/datum/voidcrew_shuttle_loan/first_offer = ferry.pending_loan
	first_offer.bonus_credits = 100

	for(var/repeat in 1 to 3)
		world.push_usr(user, accept)
		world.push_usr(user, other_accept)
	TEST_ASSERT(ferry.loan_accepted, "A loan accepted through the console must latch on the shared controller.")
	TEST_ASSERT(!ferry.accept_loan(), "A repeated direct acceptance must also be rejected.")
	TEST_ASSERT_EQUAL(account.account_balance, 1100, "Repeated acceptance through two consoles must pay only once.")
	TEST_ASSERT_EQUAL(length(ferry.transaction_history), 1, "Repeated acceptance must create one transaction.")
	var/list/entry = ferry.transaction_history[1]
	TEST_ASSERT_EQUAL(entry["type"], "loan", "The single transaction must be the loan bonus.")
	TEST_ASSERT_EQUAL(entry["value"], 100, "The loan transaction must record exactly the paid bonus.")

	// A failed arrival runs the real cleanup path and permits delivery to be retried.
	for(var/retry in 1 to 2)
		ferry.state = 1 // CARGO_SHUTTLE_ARRIVING; Voidcrew defines load after unit tests.
		TEST_ASSERT(!ferry.complete_arrival(), "An arrival without a destination must fail.")
		TEST_ASSERT_EQUAL(ferry.state, initial(ferry.state), "Failed delivery must return the shuttle to AWAY.")
		TEST_ASSERT(ferry.loan_accepted, "Failed delivery must retain the acceptance latch.")
		TEST_ASSERT_EQUAL(ferry.pending_loan, first_offer, "Failed delivery must retain the accepted offer.")
		world.push_usr(user, other_accept)
	TEST_ASSERT_EQUAL(account.account_balance, 1100, "Retrying delivery and acceptance must not pay again.")
	TEST_ASSERT_EQUAL(length(ferry.transaction_history), 1, "Delivery retries must not duplicate bonus history.")

	ferry.decline_loan()
	TEST_ASSERT_NULL(ferry.pending_loan, "Clearing an offer must remove it.")
	TEST_ASSERT(!ferry.loan_accepted, "Clearing an offer must release its acceptance latch.")
	TEST_ASSERT(ferry.receive_loan_offer(/datum/voidcrew_shuttle_loan), "A fresh offer must be available after the previous offer is cleared.")
	ferry.pending_loan.bonus_credits = 100
	world.push_usr(user, other_accept)
	world.push_usr(user, accept)
	TEST_ASSERT(ferry.loan_accepted, "The fresh offer must accept normally.")
	TEST_ASSERT_EQUAL(account.account_balance, 1200, "A fresh offer must pay one new bonus.")
	TEST_ASSERT_EQUAL(length(ferry.transaction_history), 2, "Each distinct paid offer must have one history entry.")

/datum/unit_test/voidcrew_cargo_loan_payment/Run()
	var/datum/voidcrew_cargo_shuttle/ferry = allocate(__IMPLIED_TYPE__)
	var/obj/machinery/computer/voidcrew_cargo/console = allocate(__IMPLIED_TYPE__)
	var/obj/machinery/computer/bank_machine/bank = allocate(__IMPLIED_TYPE__)
	console.link_ship_bank(bank)
	ferry.linked_console = console
	TEST_ASSERT(ferry.receive_loan_offer(/datum/voidcrew_shuttle_loan), "The idle shuttle must receive a loan offer.")
	var/datum/voidcrew_shuttle_loan/offer = ferry.pending_loan
	offer.bonus_credits = 100
	TEST_ASSERT(!ferry.accept_loan(), "A positive bonus must require a receiving account.")
	TEST_ASSERT(!ferry.loan_accepted, "A missing account must leave the offer unaccepted.")
	TEST_ASSERT_EQUAL(ferry.pending_loan, offer, "A missing account must leave the offer available.")
	TEST_ASSERT_EQUAL(length(ferry.transaction_history), 0, "A missing account must not record a bonus.")

	var/datum/bank_account/cargo_loan_test/account = allocate(/datum/bank_account/cargo_loan_test, "Cargo loan test", null, 1, FALSE)
	account.account_balance = 1000
	account.refuse_payment = TRUE
	bank.synced_bank_account = account
	TEST_ASSERT(!ferry.accept_loan(), "Failed bonus payment must reject acceptance.")
	TEST_ASSERT(!ferry.loan_accepted, "Failed payment must release the acceptance latch.")
	TEST_ASSERT_EQUAL(ferry.pending_loan, offer, "Failed payment must leave the same offer available.")
	TEST_ASSERT_EQUAL(account.account_balance, 1000, "Failed payment must leave the balance unchanged.")
	TEST_ASSERT_EQUAL(length(ferry.transaction_history), 0, "Failed payment must not record a transaction.")
	account.refuse_payment = FALSE
	TEST_ASSERT(ferry.accept_loan(), "Restoring payment must allow the same offer to be accepted.")
	TEST_ASSERT_EQUAL(account.account_balance, 1100, "The retried payment must pay exactly one bonus.")
	TEST_ASSERT_EQUAL(length(ferry.transaction_history), 1, "Only the successful payment must enter history.")

	ferry.decline_loan()
	TEST_ASSERT(ferry.receive_loan_offer(/datum/voidcrew_shuttle_loan), "A zero-bonus offer must be available normally.")
	ferry.pending_loan.bonus_credits = 0
	bank.synced_bank_account = null
	TEST_ASSERT(ferry.accept_loan(), "A zero-bonus offer must accept without a receiving account.")
	TEST_ASSERT(ferry.loan_accepted, "A zero-bonus acceptance must still latch.")
	TEST_ASSERT(!ferry.accept_loan(), "A zero-bonus offer must also reject repeated acceptance.")
	TEST_ASSERT_EQUAL(account.account_balance, 1100, "A zero-bonus offer must leave the balance unchanged.")
	TEST_ASSERT_EQUAL(length(ferry.transaction_history), 1, "A zero-bonus offer must not record a payment.")

/datum/unit_test/voidcrew_cargo_clear_cart/Run()
	var/obj/structure/overmap/dynamic/player_outpost/cargo_cart_test/home = allocate(__IMPLIED_TYPE__)
	home.service_turf = run_loc_floor_bottom_left
	home.founder_ckey = "cartowner"
	home.ensure_home_services()
	home.treasury.account_balance = 1000
	var/obj/machinery/computer/voidcrew_cargo/console = allocate(__IMPLIED_TYPE__)
	var/obj/machinery/computer/voidcrew_cargo/other_console = allocate(__IMPLIED_TYPE__)
	TEST_ASSERT_EQUAL(console.cargo_account(), home.treasury, "The cart fixture must use its claim treasury.")
	TEST_ASSERT_EQUAL(other_console.cargo_account(), home.treasury, "Both consoles must share the same claim cart.")
	var/mob/living/carbon/human/consistent/user = allocate(__IMPLIED_TYPE__)
	user.mind_initialize()
	home.residents |= user.mind
	var/datum/tgui/ui = allocate(/datum/tgui, user, console, "Cargo")
	var/datum/callback/clear_cart = CALLBACK(console, TYPE_PROC_REF(/datum, ui_act), "clear", list(), ui)
	var/datum/supply_pack/pack = allocate(/datum/supply_pack)
	var/datum/supply_order/first = allocate(/datum/supply_order, pack)
	var/datum/supply_order/protected = allocate(/datum/supply_order, pack)
	protected.can_be_cancelled = FALSE
	var/datum/supply_order/last = allocate(/datum/supply_order, pack)
	home.cargo_cart += list(first, protected, last)

	world.push_usr(user, clear_cart)
	TEST_ASSERT_EQUAL(length(home.cargo_cart), 3, "A resident without spending authority must not clear the cart.")
	home.treasurers |= user.mind
	home.freight.state = 1 // CARGO_SHUTTLE_ARRIVING; Voidcrew defines load after unit tests.
	world.push_usr(user, clear_cart)
	TEST_ASSERT_EQUAL(length(home.cargo_cart), 3, "A dispatched manifest must remain intact even for a treasurer.")
	home.freight.state = initial(home.freight.state)
	world.push_usr(user, clear_cart)
	TEST_ASSERT_EQUAL(length(home.cargo_cart), 1, "One Clear action must remove every cancellable order, including ones after a protected order.")
	TEST_ASSERT(protected in home.cargo_cart, "Clear must retain orders that cannot be cancelled.")
	TEST_ASSERT_EQUAL(other_console.checkout_list, home.cargo_cart, "Clearing must preserve the shared cart object.")
	TEST_ASSERT_EQUAL(length(other_console.checkout_list), 1, "Other consoles must immediately see the cleared cart.")
	TEST_ASSERT_EQUAL(home.treasury.account_balance, 1000, "Clearing unpaid orders must not change the treasury balance.")
	world.push_usr(user, clear_cart)
	TEST_ASSERT_EQUAL(length(home.cargo_cart), 1, "Repeated Clear must retain the protected order.")

	// ui_act passes the numeric ID of a matched item into remove_item().
	var/datum/supply_pack/individual_pack = allocate(/datum/supply_pack)
	individual_pack.name = "Individual removal fixture"
	var/datum/supply_order/individual = allocate(/datum/supply_order, individual_pack)
	home.cargo_cart += individual
	world.push_usr(user, CALLBACK(console, TYPE_PROC_REF(/datum, ui_act), "remove", list("order_name" = individual_pack.name), ui))
	TEST_ASSERT(!(individual in home.cargo_cart), "Per-item Remove must accept the numeric order ID supplied by ui_act.")
	TEST_ASSERT(protected in home.cargo_cart, "Removing another item must retain the protected order.")
