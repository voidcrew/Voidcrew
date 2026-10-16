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

// Observe dispatch without loading a shuttle; cart actions and buy() remain real.
/obj/machinery/computer/voidcrew_cargo/launch_cargo_test/restricted_dispatch_test/get_shuttle_error_message()
	return null

/datum/voidcrew_cargo_shuttle/launch_cargo_test/restricted_dispatch_test
	var/dispatch_attempted = FALSE

/datum/voidcrew_cargo_shuttle/launch_cargo_test/restricted_dispatch_test/call_shuttle(obj/structure/overmap/ship/ship)
	dispatch_attempted = TRUE
	return "Dispatch fixture"

/// Exercise forged actions, dispatch validation and real settlement.
/datum/unit_test/voidcrew_launch_cargo_fixture/denied_packs/Run()
	save_economy()
	SSshuttle.supply_packs = list()
	var/turf/bay = get_step(run_loc_floor_bottom_left, EAST)
	var/list/original_contents = bay.contents.Copy()
	var/obj/machinery/computer/voidcrew_cargo/launch_cargo_test/restricted_dispatch_test/console = allocate(__IMPLIED_TYPE__)
	var/datum/voidcrew_cargo_shuttle/launch_cargo_test/restricted_dispatch_test/ferry = allocate(__IMPLIED_TYPE__)
	ferry.test_turfs = list(bay)
	console.test_ferry = ferry
	var/obj/machinery/computer/bank_machine/bank = allocate(__IMPLIED_TYPE__)
	var/datum/bank_account/account = allocate(/datum/bank_account, "Cargo restriction test", null, 1, FALSE)
	bank.synced_bank_account = account
	console.link_ship_bank(bank)
	account.account_balance = 1000000
	var/mob/living/carbon/human/consistent/user = allocate(__IMPLIED_TYPE__)
	var/datum/tgui/ui = allocate(/datum/tgui, user, console, "Cargo")
	var/list/banned_types = typesof(/datum/supply_pack/security) + list(
		/datum/supply_pack/goody/mars_single,
		/datum/supply_pack/goody/ballistic_single,
		/datum/supply_pack/goody/disabler_single,
		/datum/supply_pack/goody/energy_single,
		/datum/supply_pack/goody/laser_single,
		/datum/supply_pack/goody/thermal_single,
		/datum/supply_pack/goody/double_barrel,
		/datum/supply_pack/goody/hell_single,
	)
	var/list/banned_packs = list()
	for(var/pack_type in banned_types)
		var/datum/supply_pack/pack = allocate(pack_type)
		pack.special_enabled = TRUE
		pack.drop_pod_only = FALSE
		SSshuttle.supply_packs[pack_type] = pack
		banned_packs += pack
		for(var/unlocked in list(FALSE, TRUE))
			if(unlocked)
				console.obj_flags |= EMAGGED
			else
				console.obj_flags &= ~EMAGGED
			console.contraband = unlocked
			pack.hidden = unlocked
			pack.contraband = unlocked
			TEST_ASSERT(!console.can_order_pack(pack), "[pack_type] is orderable with emag/contraband [unlocked].")
			TEST_ASSERT(!console.add_item(list("id" = "[pack_type]"), user), "A forged [pack_type] ID entered the cart.")
			world.push_usr(user, CALLBACK(console, TYPE_PROC_REF(/datum, ui_act), "add", list("id" = "[pack_type]"), ui))
			world.push_usr(user, CALLBACK(console, TYPE_PROC_REF(/datum, ui_act), "add_by_name", list("order_name" = pack.name), ui))
			world.push_usr(user, CALLBACK(console, TYPE_PROC_REF(/datum, ui_act), "modify", list("order_name" = pack.name, "amount" = 1), ui))
			TEST_ASSERT_EQUAL(length(console.checkout_list), 0, "A forged cart action added [pack_type].")
		TEST_ASSERT_EQUAL(length(console.get_packs_data(pack.group)), 0, "Forbidden pack group [pack.group] has catalog entries.")
	var/list/catalog = console.ui_static_data(user)
	TEST_ASSERT_EQUAL(length(catalog["supplies"]), 0, "Empty cargo groups remain visible.")

	// A cart loaded before the restriction must be rechecked before payment or spawning.
	for(var/datum/supply_pack/pack as anything in banned_packs)
		var/datum/supply_order/order = allocate(/datum/supply_order, pack)
		order.applied_coupon = allocate(/obj/item/coupon)
		console.checkout_list += order
	world.push_usr(user, CALLBACK(console, TYPE_PROC_REF(/datum, ui_act), "send", list(), ui))
	TEST_ASSERT(!ferry.dispatch_attempted, "A forbidden cart reached dispatch, where outpost freight would reserve payment.")
	TEST_ASSERT(console.buy(), "The stale-cart fixture did not reach the shipment loop.")
	TEST_ASSERT_EQUAL(account.account_balance, 1000000, "A forbidden stale order was charged.")
	TEST_ASSERT_EQUAL(length(console.checkout_list), length(banned_packs), "Rejected stale orders must remain cancellable in the cart.")
	TEST_ASSERT_EQUAL(length(bay.contents - original_contents), 0, "A forbidden stale order generated cargo.")
	for(var/datum/supply_order/order as anything in console.checkout_list)
		TEST_ASSERT_NULL(order.ship_paid_cost, "[order.pack.type] was settled despite the restriction.")
		TEST_ASSERT_NOTNULL(order.applied_coupon, "Rejecting [order.pack.type] consumed its coupon.")

	// Unrelated cargo must still settle in a cart that also holds forbidden orders.
	var/datum/supply_pack/ordinary_pack = allocate(/datum/supply_pack)
	ordinary_pack.group = "Cargo control"
	ordinary_pack.contains = list(/obj/item/screwdriver)
	SSshuttle.supply_packs[ordinary_pack.type] = ordinary_pack
	catalog = console.ui_static_data(user)
	TEST_ASSERT_EQUAL(length(catalog["supplies"]), 1, "The catalog must show only its nonempty group.")
	TEST_ASSERT_NOTNULL(catalog["supplies"][ordinary_pack.group], "An ordinary cargo group disappeared.")
	var/datum/supply_order/ordinary_order = allocate(/datum/supply_order, ordinary_pack)
	ordinary_order.manifest_can_fail = FALSE
	console.checkout_list += ordinary_order
	var/ordinary_cost = ordinary_order.get_final_cost()
	TEST_ASSERT(console.can_order_pack(ordinary_pack), "The restriction blocked an ordinary pack.")
	console.buy()
	TEST_ASSERT_EQUAL(account.account_balance, 1000000 - ordinary_cost, "A mixed cart must bill only its ordinary cargo.")
	TEST_ASSERT(!(ordinary_order in console.checkout_list), "Ordinary cargo did not leave the cart after settlement.")
	TEST_ASSERT_EQUAL(length(console.checkout_list), length(banned_packs), "Settling ordinary cargo changed forbidden orders.")
	var/obj/structure/closet/crate/delivery = locate() in bay
	TEST_ASSERT_NOTNULL(delivery, "Ordinary cargo did not arrive.")
	TEST_ASSERT(locate(/obj/item/screwdriver) in delivery, "Ordinary cargo lost its contents.")
	qdel(delivery)

	console.checkout_list.Cut()
	console.checkout_list += allocate(/datum/supply_order, ordinary_pack)
	world.push_usr(user, CALLBACK(console, TYPE_PROC_REF(/datum, ui_act), "send", list(), ui))
	TEST_ASSERT(ferry.dispatch_attempted, "An ordinary cart must still reach dispatch.")
