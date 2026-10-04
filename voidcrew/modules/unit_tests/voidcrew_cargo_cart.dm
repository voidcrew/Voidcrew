/// Keep this fixture on existing test ground; cart, account and permission behavior are real.
/obj/structure/overmap/dynamic/player_outpost/cargo_cart_test
	var/turf/service_turf

/obj/structure/overmap/dynamic/player_outpost/cargo_cart_test/contains_service_turf(turf/location)
	return location == service_turf

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
