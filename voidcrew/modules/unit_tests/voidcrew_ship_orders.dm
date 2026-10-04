/// Shipyard orders: new ships bought at the shipyard console and built in the bay.
/// Voidcrew defines are not visible here; prices are the literal 2,500 per part and 10,000 fee.

/// Confirms without a client and builds with directly placed visits.
/datum/ship_checkpoint_ui/order_test
	var/accept_order = TRUE
	var/datum/callback/during_confirmation

/datum/ship_checkpoint_ui/order_test/confirm_order(mob/user, prompt_text)
	during_confirmation?.Invoke()
	return accept_order

/datum/ship_checkpoint_ui/order_test/create_order_job(mob/living/user, datum/ship_order/order, datum/bank_account/account, obj/structure/overmap/ship/paying_ship)
	return new /datum/checkpoint_construction/order(src, outpost, order, user, account, paying_ship, TRUE)

/// An outpost with its ship bay, and its shipyard console.
/datum/unit_test/voidcrew_checkpoints/proc/order_outpost(founder)
	var/obj/structure/overmap/dynamic/player_outpost/registry_test/home = allocate(/obj/structure/overmap/dynamic/player_outpost/registry_test)
	home.shell_template = allocate(/datum/map_template/player_outpost/test_fixture)
	home.founder_ckey = founder
	TEST_ASSERT(home.load_level(), "The outpost did not load")
	TEST_ASSERT_NULL(home.enable_ship_bays(), "The ship bay did not load")
	return home

/// The ship bay's shipyard console, where ships are ordered.
/datum/unit_test/voidcrew_checkpoints/proc/find_console(obj/structure/overmap/dynamic/player_outpost/home)
	return outpost_bay_shipyard_console(LAZYACCESS(home.bay_berths, 1))

/// The shelf hull with the fewest tiles, for cases that only need some ship.
/datum/unit_test/voidcrew_checkpoints/proc/smallest_order_hull()
	var/datum/map_template/shuttle/voidcrew/smallest
	for(var/datum/map_template/shuttle/voidcrew/hull as anything in get_ship_order_hulls())
		if(!smallest || hull.width * hull.height < smallest.width * smallest.height)
			smallest = hull
	return smallest

/// Builds a job to completion with directly placed visits and hands it over.
/datum/unit_test/voidcrew_checkpoints/proc/finish_job(datum/checkpoint_construction/job)
	job.fast_forward()
	if(!QDELETED(job))
		job.hand_over_now()

/// A personal account on an ID the buyer holds.
/datum/unit_test/voidcrew_checkpoints/proc/give_account(mob/living/carbon/human/buyer, balance)
	var/obj/item/card/id/id = allocate(/obj/item/card/id)
	var/datum/bank_account/personal = allocate(/datum/bank_account, "Order buyer", null, 1, FALSE)
	personal.account_balance = balance
	id.registered_account = personal
	TEST_ASSERT(buyer.put_in_active_hand(id), "The buyer could not hold their ID")
	return personal

/**
 * Prices: hull parts x 2,500 + a 10,000 fee, plus 2,500 per part of a non-default theme and of
 * each non-default module. Pills are not sold.
 */
/datum/unit_test/voidcrew_checkpoints/ship_order_prices

/datum/unit_test/voidcrew_checkpoints/ship_order_prices/Run()
	var/list/hulls = get_ship_order_hulls()
	TEST_ASSERT(length(hulls) >= 7, "The shelf has only [length(hulls)] hulls")
	for(var/datum/map_template/shuttle/voidcrew/hull as anything in hulls)
		TEST_ASSERT(!istype(hull, /datum/map_template/shuttle/voidcrew/pill) && !istype(hull, /datum/map_template/shuttle/voidcrew/pill_black), "[hull.type] is a Pill on the shelf")
	// Every hull the lobby shelf sells, less the Pills.
	for(var/datum/map_template/shuttle/voidcrew/lobby_hull as anything in get_purchasable_ship_templates())
		var/is_pill = istype(lobby_hull, /datum/map_template/shuttle/voidcrew/pill) || istype(lobby_hull, /datum/map_template/shuttle/voidcrew/pill_black)
		TEST_ASSERT_EQUAL(!!(lobby_hull in hulls), !is_pill, "[lobby_hull.type] is [is_pill ? "a Pill" : "a lobby hull"] but is[is_pill ? "" : " not"] on the shelf")

	// A modular hull with its defaults: the fee alone.
	var/datum/map_template/shuttle/voidcrew/delta = find_ship_template_by_type("[/datum/map_template/shuttle/voidcrew/delta]")
	TEST_ASSERT(delta in hulls, "The Delta is not on the shelf")
	var/datum/ship_order/plain = new(delta)
	TEST_ASSERT_NULL(plain.denial(), "A default Delta cannot be ordered: [plain.denial()]")
	TEST_ASSERT(plain.theme?.is_default, "A new order did not start on the default theme")
	TEST_ASSERT_EQUAL(plain.price(), 10000, "A default modular hull does not cost the 10,000 fee")
	TEST_ASSERT_EQUAL(length(plain.price_lines()), 1, "A default modular hull lists extra charges")

	// A non-default theme and non-default modules add 2,500 per part each.
	var/list/delta_themes = get_themes_for_ship(delta.type)
	var/datum/ship_theme/syndicate = delta_themes["syndicate"]
	TEST_ASSERT_NOTNULL(syndicate, "The Delta has no syndicate theme")
	var/datum/ship_order/custom = new(delta)
	custom.set_theme(syndicate)
	var/expected = 10000 + ship_order_part_count(syndicate.part_cost) * 2500
	TEST_ASSERT_EQUAL(ship_order_theme_price(syndicate), 22500, "The 9-part syndicate theme does not cost 22,500")
	var/modules_bought = 0
	for(var/slot_key in custom.slot_ids())
		for(var/datum/ship_upgrade_module/module as anything in get_modules_for_ship_slot(delta.type, "syndicate", slot_key))
			if(module.is_default || !ship_order_part_count(module.part_cost))
				continue
			TEST_ASSERT(custom.module_fits(module, slot_key), "[module.id] does not fit its own slot")
			custom.upgrade_selections[slot_key] = module
			expected += ship_order_part_count(module.part_cost) * 2500
			modules_bought++
			break
	TEST_ASSERT(modules_bought >= 2, "Only [modules_bought] paid modules fit the syndicate Delta")
	TEST_ASSERT_NULL(custom.denial(), "A custom Delta cannot be ordered: [custom.denial()]")
	TEST_ASSERT_EQUAL(custom.price(), expected, "The custom Delta price is wrong")
	TEST_ASSERT_EQUAL(length(custom.price_lines()), 2 + modules_bought, "The breakdown does not list the fee, theme and each module")
	log_test("Custom Delta: [custom.price()] credits ([modules_bought] modules)")
	// Default modules add nothing even when they list a part cost.
	var/datum/ship_order/defaults = new(delta)
	defaults.set_theme(syndicate)
	TEST_ASSERT_EQUAL(defaults.price(), 22500 + 10000, "Default modules were charged")
	// Modules of another theme do not fit.
	var/datum/ship_order/mismatched = new(delta)
	for(var/slot_key in mismatched.slot_ids())
		for(var/datum/ship_upgrade_module/module as anything in get_modules_for_ship_slot(delta.type, "syndicate", slot_key))
			if(!is_module_available_for_theme(module, mismatched.theme.id))
				TEST_ASSERT(!mismatched.module_fits(module, slot_key), "[module.id] fits a theme it is not made for")
				mismatched.upgrade_selections[slot_key] = module
				TEST_ASSERT_NOTNULL(mismatched.denial(), "An order with another theme's module was accepted")
				break

	// A classic hull costs its parts: the Box is one science part. It is not on the lobby shelf.
	var/datum/map_template/shuttle/voidcrew/box = find_ship_template_by_type("[/datum/map_template/shuttle/voidcrew/box]")
	TEST_ASSERT_EQUAL(ship_order_hull_price(box), 12500, "A one-part classic hull does not cost 12,500")
	TEST_ASSERT(!is_ship_order_hull(box), "A classic hull missing from the lobby shelf is sold here")

	// Pills cannot be bought, whether ordered directly or picked on the console.
	var/datum/map_template/shuttle/voidcrew/pill = find_ship_template_by_type("[/datum/map_template/shuttle/voidcrew/pill]")
	TEST_ASSERT(is_player_purchasable_ship(pill), "The Pill left the lobby shelf; this case needs a new fixture")
	var/datum/ship_order/pill_order = new(pill)
	TEST_ASSERT_NOTNULL(pill_order.denial(), "A Pill order was accepted")
	var/obj/structure/overmap/dynamic/player_outpost/registry_test/home = order_outpost("pricefounder")
	var/obj/machinery/computer/ship_checkpoint/console = find_console(home)
	var/mob/living/carbon/human/buyer = make_player(get_turf(console), "pricebuyer")
	var/datum/ship_checkpoint_ui/order_test/panel = allocate(/datum/ship_checkpoint_ui/order_test, home, console, buyer)
	panel.ensure_cart()
	panel.shop_act(buyer, "shop_hull", list("id" = "[pill.type]"))
	TEST_ASSERT(!istype(panel.cart.hull, /datum/map_template/shuttle/voidcrew/pill), "The console put a Pill in the cart")
	var/list/static_data = panel.shop_static_data()
	for(var/list/hull_entry as anything in static_data["catalog"])
		TEST_ASSERT(hull_entry["id"] != "[pill.type]", "The console lists the Pill")
	// The console shows the same breakdown.
	panel.shop_act(buyer, "shop_hull", list("id" = "[delta.type]"))
	panel.shop_act(buyer, "shop_theme", list("id" = "syndicate"))
	var/list/shop = panel.shop_data(buyer)
	TEST_ASSERT_EQUAL(shop["price"], 32500, "The console priced a default syndicate Delta wrong")
	TEST_ASSERT_EQUAL(length(shop["lines"]), 2, "The console breakdown is wrong")

/**
 * The payer is charged exactly once, at the first piece. Short funds are refused at the start
 * and at commitment, a stop before the first piece charges nothing, and only a ship the buyer
 * commands can pay from its account. The buyer takes command at handover.
 */
/datum/unit_test/voidcrew_checkpoints/ship_order_payment

/datum/unit_test/voidcrew_checkpoints/ship_order_payment/Run()
	var/obj/structure/overmap/dynamic/player_outpost/registry_test/home = order_outpost("paymentfounder")
	var/obj/machinery/computer/ship_checkpoint/console = find_console(home)
	TEST_ASSERT_NOTNULL(console, "The outpost has no shipyard console")
	TEST_ASSERT_EQUAL(console.name, "shipyard console", "The console was not renamed")
	var/turf/console_turf = get_turf(console)
	var/mob/living/carbon/human/buyer = make_player(console_turf, "paymentbuyer")
	var/mob/living/carbon/human/other = make_player(console_turf, "paymentother")
	var/datum/outpost_berth/ship_bay/bay = home.bay_berths[1]
	var/datum/map_template/shuttle/voidcrew/hull = smallest_order_hull()
	var/datum/ship_checkpoint_ui/order_test/panel = allocate(/datum/ship_checkpoint_ui/order_test, home, console, buyer)
	panel.ensure_cart()
	panel.shop_act(buyer, "shop_hull", list("id" = "[hull.type]"))
	TEST_ASSERT_EQUAL(panel.cart.hull, hull, "The console did not select the hull")
	var/price = panel.cart.price()
	var/treasury = home.treasury.account_balance

	// No ID: nothing to pay with.
	TEST_ASSERT(!panel.place_order(buyer), "An order started with no account to pay")
	var/datum/bank_account/personal = give_account(buyer, price - 1)
	// Short at the start.
	TEST_ASSERT(!panel.place_order(buyer), "An order started without enough credits")
	TEST_ASSERT(!length(home.checkpoint_jobs) && bay.is_available(), "A refused order kept a job or the bay")
	TEST_ASSERT_EQUAL(personal.account_balance, price - 1, "A refused order charged the buyer")
	// Cancelled at the prompt.
	personal.account_balance = price * 3
	panel.accept_order = FALSE
	TEST_ASSERT(!panel.place_order(buyer), "A cancelled order started")
	panel.accept_order = TRUE
	TEST_ASSERT(bay.is_available(), "A cancelled order kept the bay")
	// Funds spent while the prompt is open are rechecked.
	panel.during_confirmation = CALLBACK(src, PROC_REF(set_balance), personal, price - 1)
	TEST_ASSERT(!panel.place_order(buyer), "An order started after its funds were spent at the prompt")
	panel.during_confirmation = null
	TEST_ASSERT_EQUAL(personal.account_balance, price - 1, "An order refused at the prompt charged the buyer")

	// Started, then stopped before the first piece: nothing is charged.
	personal.account_balance = price * 3
	TEST_ASSERT(panel.place_order(buyer), "The order did not start: [panel.error]")
	var/datum/checkpoint_construction/order/job = home.checkpoint_jobs[1]
	TEST_ASSERT(istype(job), "The order made no order job")
	TEST_ASSERT_EQUAL(job.state, "marking", "The order is not marked out")
	TEST_ASSERT(!bay.is_available(), "A started order did not reserve the bay")
	TEST_ASSERT_EQUAL(personal.account_balance, price * 3, "The order charged before the first piece")
	TEST_ASSERT_NULL(SSshuttle.loading_order, "The order stayed on the loader")
	TEST_ASSERT_NULL(SSshuttle.active_template_load, "The order held the loader")
	TEST_ASSERT(!panel.place_order(buyer), "A second order took the reserved bay")
	job.abort("Test stop.")
	TEST_ASSERT(QDELETED(job) && bay.is_available(), "A stopped order kept its job or bay")
	TEST_ASSERT_EQUAL(personal.account_balance, price * 3, "An order stopped before its first piece charged the buyer")
	TEST_ASSERT_EQUAL(count_bay_ship_tiles(bay), 0, "An order stopped before its first piece left pieces")

	// Short at commitment: stopped unpaid.
	TEST_ASSERT(panel.place_order(buyer), "The second order did not start: [panel.error]")
	job = home.checkpoint_jobs[1]
	personal.account_balance = price - 1
	job.fast_forward(1)
	TEST_ASSERT(QDELETED(job) && !job.committed, "An order committed without the funds")
	TEST_ASSERT_EQUAL(personal.account_balance, price - 1, "A refused commitment charged the buyer")
	TEST_ASSERT(bay.is_available() && !count_bay_ship_tiles(bay), "A refused commitment kept the bay or left pieces")

	// A ship's account pays only for its captain.
	var/obj/structure/overmap/ship/paying_ship = SSshuttle.create_ship(hull.type)
	TEST_ASSERT_NOTNULL(paying_ship, "Could not spawn the paying ship")
	test_ships += paying_ship
	paying_ship.enlist_crewmember(other)
	paying_ship.claimed_captain = other.mind
	paying_ship.ship_account.account_balance = price * 2
	for(var/list/option as anything in panel.payer_options(buyer))
		TEST_ASSERT(option["id"] != REF(paying_ship), "Another captain's ship was offered as a payer")
	panel.shop_act(buyer, "shop_payer", list("id" = REF(paying_ship)))
	TEST_ASSERT(!panel.place_order(buyer), "A ship the buyer does not command paid")
	paying_ship.enlist_crewmember(buyer)
	paying_ship.claimed_captain = buyer.mind
	var/offered = FALSE
	for(var/list/option as anything in panel.payer_options(buyer))
		if(option["id"] == REF(paying_ship))
			offered = TRUE
	TEST_ASSERT(offered, "The buyer's own ship was not offered as a payer")
	// Command lost before the first piece: stopped unpaid.
	TEST_ASSERT(panel.place_order(buyer), "The ship-paid order did not start: [panel.error]")
	job = home.checkpoint_jobs[1]
	paying_ship.claimed_captain = other.mind
	job.fast_forward(1)
	TEST_ASSERT(QDELETED(job) && !job.committed, "An order committed after the buyer lost command of the paying ship")
	TEST_ASSERT_EQUAL(paying_ship.ship_account.account_balance, price * 2, "The former ship paid")
	paying_ship.claimed_captain = buyer.mind

	// Paid once, at the first piece, from the ship; never from the buyer or to the outpost.
	var/personal_before = personal.account_balance
	TEST_ASSERT(panel.place_order(buyer), "The paid order did not start: [panel.error]")
	job = home.checkpoint_jobs[1]
	TEST_ASSERT_EQUAL(paying_ship.ship_account.account_balance, price * 2, "The ship paid before the first piece")
	job.fast_forward(1)
	TEST_ASSERT(job.committed, "The first piece did not commit the order")
	TEST_ASSERT_EQUAL(job.charged, price, "The order recorded the wrong charge")
	TEST_ASSERT_EQUAL(paying_ship.ship_account.account_balance, price, "The first piece did not charge the ship exactly once")
	// Spending the rest cannot stop a paid build.
	paying_ship.ship_account.account_balance = 0
	finish_job(job)
	TEST_ASSERT(QDELETED(job), "The paid order did not finish")
	TEST_ASSERT_EQUAL(paying_ship.ship_account.account_balance, 0, "The order charged again after the first piece")
	TEST_ASSERT_EQUAL(personal.account_balance, personal_before, "The buyer's own account was charged for a ship-paid order")
	TEST_ASSERT_EQUAL(home.treasury.account_balance, treasury, "Order money reached the outpost treasury")
	var/obj/structure/overmap/ship/built = bay.ship
	TEST_ASSERT_NOTNULL(built, "The order was not handed over")
	test_ships += built
	TEST_ASSERT(built.is_ship_captain(buyer), "The buyer did not take command")
	TEST_ASSERT(!built.abandoned, "The delivered ship was left abandoned")
	TEST_ASSERT(paying_ship.is_ship_captain(buyer), "Taking the new ship removed command of the old one")
	TEST_ASSERT_EQUAL(built.source_template.type, hull.type, "The ship record has the wrong template")
	TEST_ASSERT(built.source_template != hull, "The ship record shares the shelf's template")
	TEST_ASSERT_EQUAL(built.theme, panel.cart.theme?.id, "The ship record has the wrong theme")
	TEST_ASSERT(length(built.helm_consoles), "The delivered ship has no connected helm")

	// After the first piece, an admin stop removes the pieces and refunds nothing.
	leave_order_bay(home, built)
	personal.account_balance = price * 2
	panel.shop_act(buyer, "shop_payer", list("id" = "personal"))
	TEST_ASSERT(panel.place_order(buyer), "The last order did not start: [panel.error]")
	job = home.checkpoint_jobs[1]
	job.fast_forward(10)
	TEST_ASSERT(job.committed && count_bay_ship_tiles(bay) > 0, "No pieces were placed")
	TEST_ASSERT_EQUAL(personal.account_balance, price, "The first piece did not charge the buyer")
	job.abort("Stopped by an administrator.")
	TEST_ASSERT(QDELETED(job) && bay.is_available(), "The stopped build kept its bay")
	TEST_ASSERT_EQUAL(count_bay_ship_tiles(bay), 0, "The stopped build left pieces in the bay")
	TEST_ASSERT_EQUAL(personal.account_balance, price, "A stopped build was refunded")

/datum/unit_test/voidcrew_checkpoints/ship_order_payment/proc/set_balance(datum/bank_account/account, amount)
	account.account_balance = amount

/// Flies a delivered ship out of the bay and deletes it.
/datum/unit_test/voidcrew_checkpoints/proc/leave_order_bay(obj/structure/overmap/dynamic/player_outpost/home, obj/structure/overmap/ship/ship)
	TEST_ASSERT(lose_original(home, ship), "[ship] could not leave the bay")

/**
 * An order and a checkpoint rebuild at two outposts share the shipyard queue: both wait with
 * their bays reserved while the loader is busy, load in the order they asked, and finish.
 */
/datum/unit_test/voidcrew_checkpoints/ship_order_queue
	var/datum/shuttle_template_load/held
	var/list/prepared = list()

/datum/unit_test/voidcrew_checkpoints/ship_order_queue/Destroy()
	if(held)
		SSshuttle.release_template_load(held)
	return ..()

/datum/unit_test/voidcrew_checkpoints/ship_order_queue/Run()
	var/datum/map_template/shuttle/voidcrew/hull = smallest_order_hull()
	var/obj/structure/overmap/dynamic/player_outpost/registry_test/rebuild_home = order_outpost("queuerebuildfounder")
	var/obj/structure/overmap/dynamic/player_outpost/registry_test/order_home = order_outpost("queueorderfounder")
	var/mob/living/carbon/human/captain = make_player(run_loc_floor_bottom_left, "queuecaptain")
	var/mob/living/carbon/human/buyer = make_player(run_loc_floor_bottom_left, "queuebuyer")
	var/datum/bank_account/personal = give_account(buyer, 100000)
	var/datum/ship_checkpoint/snapshot = save_class(rebuild_home, captain, hull.type)
	TEST_ASSERT(istype(snapshot), "[hull.type] could not be saved: [snapshot]")
	TEST_ASSERT(lose_original(rebuild_home, snapshot.source_ship.resolve()), "The original could not be removed")

	held = SSshuttle.acquire_template_load()
	var/datum/checkpoint_construction/rebuild = new(null, snapshot, captain, TRUE)
	var/datum/ship_order/order = new(hull)
	var/price = order.price()
	var/datum/checkpoint_construction/order/purchase = new(null, order_home, order, buyer, personal, null, TRUE)
	TEST_ASSERT(rebuild.bay && purchase.bay, "A job could not reserve its bay")
	INVOKE_ASYNC(src, PROC_REF(prepare_job), rebuild)
	INVOKE_ASYNC(src, PROC_REF(prepare_job), purchase)
	for(var/datum/checkpoint_construction/job as anything in list(rebuild, purchase))
		TEST_ASSERT(job.queued, "[job.type] did not wait for the busy loader")
		TEST_ASSERT_EQUAL(job.status_line(), "Waiting for the shipyard", "[job.type] reported the wrong status while queued")
		TEST_ASSERT_EQUAL(job.bay.status_text(), "Queued", "[job.type]'s bay sign is wrong while queued")
		TEST_ASSERT(!job.bay.is_available(), "[job.type] released its bay while queued")
	SSshuttle.release_template_load(held)
	held = null
	var/deadline = world.time + 3 MINUTES
	UNTIL((prepared[rebuild] && prepared[purchase]) || world.time > deadline)
	TEST_ASSERT_EQUAL(prepared[rebuild], "started", "The queued rebuild did not start: [rebuild.error]")
	TEST_ASSERT_EQUAL(prepared[purchase], "started", "The queued order did not start: [purchase.error]")
	TEST_ASSERT(rebuild.load_started_at <= purchase.load_started_at, "The order loaded ahead of the earlier rebuild")
	TEST_ASSERT_EQUAL(purchase.bay_status(), "Building", "The order's bay sign is wrong")
	var/datum/outpost_berth/ship_bay/rebuild_bay = rebuild.bay
	var/datum/outpost_berth/ship_bay/order_bay = purchase.bay
	finish_job(rebuild)
	finish_job(purchase)
	TEST_ASSERT(QDELETED(rebuild) && rebuild_bay.ship, "The rebuild was not handed over")
	TEST_ASSERT(QDELETED(purchase) && order_bay.ship, "The order was not handed over")
	test_ships += rebuild_bay.ship
	test_ships += order_bay.ship
	TEST_ASSERT(rebuild_bay.ship.is_ship_captain(captain), "The rebuilt ship's captain lacks command")
	TEST_ASSERT(order_bay.ship.is_ship_captain(buyer), "The buyer lacks command of the new ship")
	TEST_ASSERT_EQUAL(personal.account_balance, 100000 - price, "The queued order was not charged exactly once")

/datum/unit_test/voidcrew_checkpoints/ship_order_queue/proc/prepare_job(datum/checkpoint_construction/job)
	prepared[job] = job.prepare() ? "started" : "stopped"

/**
 * An order builds exactly what create_ship() spawns for the same choices: every class on its
 * defaults, and every class again with a non-default theme and non-default modules. Turf, room
 * and fitting types are compared tile by tile, pipes and plumbing as a whole, and the ship
 * record's template, theme, modules and crew. Items and creatures are compared by count: some
 * are rolled at random when they load. Landmarks delete themselves once registered.
 */
/datum/unit_test/voidcrew_checkpoints/every_ship/ship_orders

/datum/unit_test/voidcrew_checkpoints/every_ship/ship_orders/Run()
	var/obj/structure/overmap/dynamic/player_outpost/registry_test/home = order_outpost("orderequalfounder")
	var/mob/living/carbon/human/buyer = make_player(run_loc_floor_bottom_left, "orderequalbuyer")
	var/list/report = list()
	var/configurations = 0
	var/position = 0
	var/sharded = FALSE
	for(var/datum/map_template/shuttle/voidcrew/hull as anything in get_ship_order_hulls())
		if(!voidcrew_test_shard_takes(++position))
			sharded = TRUE
			continue
		var/datum/ship_order/defaults = new(hull)
		report += "[hull.type] defaults ([defaults.theme?.id]): [compare_order(home, buyer, defaults)]"
		configurations++
		var/datum/ship_order/custom = custom_order(hull)
		if(!custom)
			report += "[hull.type]: no non-default configuration"
			continue
		var/list/names = list()
		for(var/slot_key in custom.upgrade_selections)
			var/datum/ship_upgrade_module/module = custom.upgrade_selections[slot_key]
			if(!module.is_default)
				names += module.id
		report += "[hull.type] [custom.theme?.id] with [names.Join(", ")]: [compare_order(home, buyer, custom)]"
		configurations++
	if(!sharded)
		TEST_ASSERT(configurations >= 14, "Only [configurations] configurations were built")
	log_test("Orders against create_ship():\n[report.Join("\n")]")

/// The most expensive non-default theme, with the first non-default module in every slot.
/datum/unit_test/voidcrew_checkpoints/every_ship/ship_orders/proc/custom_order(datum/map_template/shuttle/voidcrew/hull)
	var/list/themes = get_themes_for_ship(hull.type)
	var/datum/ship_theme/chosen
	for(var/theme_id in themes)
		var/datum/ship_theme/theme = themes[theme_id]
		if(theme.is_default)
			continue
		if(!chosen || ship_order_part_count(theme.part_cost) > ship_order_part_count(chosen.part_cost))
			chosen = theme
	var/datum/ship_order/order = new(hull, chosen)
	var/changed = !!chosen
	for(var/slot_key in order.slot_ids())
		for(var/datum/ship_upgrade_module/module as anything in get_modules_for_ship_slot(hull.type, order.theme?.id, slot_key))
			if(!module.is_default)
				order.upgrade_selections[slot_key] = module
				changed = TRUE
				break
	return changed ? order : null

/datum/unit_test/voidcrew_checkpoints/every_ship/ship_orders/proc/compare_order(obj/structure/overmap/dynamic/player_outpost/registry_test/home, mob/living/carbon/human/buyer, datum/ship_order/order)
	var/label = "[order.hull_type] [order.theme?.id]"
	TEST_ASSERT_NULL(order.denial(), "[label]: the order is refused: [order.denial()]")
	var/obj/structure/overmap/ship/spawned = SSshuttle.create_ship(order.hull_type, order.upgrade_selections, order.theme)
	if(!spawned)
		TEST_FAIL("[label]: create_ship() failed")
		return "create_ship() failed"
	test_ships += spawned
	var/datum/checkpoint_construction/order/job = new(null, home, order.copy(), buyer, null, null, TRUE, TRUE)
	if(!job.bay || !job.prepare())
		TEST_FAIL("[label]: the order did not start: [job.error]")
		spawned.shuttle.admin_delete_shuttle()
		return "not started"
	TEST_ASSERT_NULL(SSshuttle.loading_order, "[label]: the order stayed on the loader")
	var/datum/outpost_berth/ship_bay/bay = job.bay
	finish_job(job)
	var/obj/structure/overmap/ship/built = bay.ship
	if(!QDELETED(job) || !built)
		TEST_FAIL("[label]: the order was not handed over")
		spawned.shuttle.admin_delete_shuttle()
		return "not handed over"
	test_ships += built
	var/list/problems = list()
	// The ship record.
	if(built.source_template.type != spawned.source_template.type)
		problems += "template [built.source_template.type], spawned [spawned.source_template.type]"
	if(built.theme != spawned.theme)
		problems += "theme [built.theme], spawned [spawned.theme]"
	if(selection_text(built.upgrade_selections) != selection_text(spawned.upgrade_selections))
		problems += "modules [selection_text(built.upgrade_selections)], spawned [selection_text(spawned.upgrade_selections)]"
	if(job_text(built) != job_text(spawned))
		problems += "crew [job_text(built)], spawned [job_text(spawned)]"
	if(!built.is_ship_captain(buyer))
		problems += "the buyer does not command it"
	if(length(built.shuttle.shuttle_areas) != length(spawned.shuttle.shuttle_areas))
		problems += "[length(built.shuttle.shuttle_areas)] rooms, spawned [length(spawned.shuttle.shuttle_areas)]"
	// A bought ship keeps every emergency closet its map places; a lobby spawn may roll one away.
	var/built_closets = 0
	var/spawned_closets = 0
	for(var/turf/tile as anything in built.shuttle.return_turfs())
		if(tile.loc in built.shuttle.shuttle_areas)
			for(var/obj/structure/closet/emcloset/closet in tile)
				built_closets++
	for(var/turf/tile as anything in spawned.shuttle.return_turfs())
		if(tile.loc in spawned.shuttle.shuttle_areas)
			for(var/obj/structure/closet/emcloset/closet in tile)
				spawned_closets++
	if(built_closets < spawned_closets)
		problems += "[built_closets] emergency closets, spawned [spawned_closets]"
	// Tile by tile, in the port's own frame, so a bay that turns the hull still lines up.
	var/swept = job.swept_leftovers ? jointext(job.swept_leftovers, ", ") : "nothing"
	var/left = job.left_behind ? jointext(job.left_behind, ", ") : "nothing"
	var/list/built_loose = list()
	var/list/spawned_loose = list()
	var/list/built_tiles = tile_lines(built.shuttle, built_loose)
	var/list/spawned_tiles = tile_lines(spawned.shuttle, spawned_loose)
	var/tile_differences = 0
	var/rolled_tiles = 0
	for(var/i in 1 to max(length(built_tiles), length(spawned_tiles)))
		var/built_line = i <= length(built_tiles) ? built_tiles[i] : "(none)"
		var/spawned_line = i <= length(spawned_tiles) ? spawned_tiles[i] : "(none)"
		if(built_line != spawned_line && rolled_alike(built_line, spawned_line))
			rolled_tiles++
		else if(built_line != spawned_line)
			if(tile_differences < 5)
				problems += "tile [i]: built [built_line]; spawned [spawned_line]"
			tile_differences++
	if(tile_differences > 5)
		problems += "[tile_differences - 5] more tiles differ"
	if(tile_differences)
		// Whether a differing fitting was lost or only ended up elsewhere.
		var/list/built_totals = fitting_totals(built_tiles)
		var/list/spawned_totals = fitting_totals(spawned_tiles)
		var/list/totals = list()
		for(var/type_name in (built_totals | spawned_totals))
			if(built_totals[type_name] != spawned_totals[type_name])
				totals += "[type_name] [built_totals[type_name] || 0]/[spawned_totals[type_name] || 0]"
		problems += "fitting totals built/spawned: [length(totals) ? totals.Join(", ") : "equal"]"
	// Loose structures (crates, buckets, boxes) are often rolled by random spawners: compared in total.
	var/loose_tiles = 0
	for(var/i in 1 to min(length(built_loose), length(spawned_loose)))
		if(built_loose[i] != spawned_loose[i])
			loose_tiles++
	var/built_loose_count = loose_count(built_loose)
	var/spawned_loose_count = loose_count(spawned_loose)
	if(built_loose_count < spawned_loose_count * 0.8)
		problems += "[built_loose_count] loose structures aboard, spawned with [spawned_loose_count]"
	// Starting supplies are not scrubbed. Random loot rolls differently each load.
	var/list/built_cargo = cargo_counts(built.shuttle)
	var/list/spawned_cargo = cargo_counts(spawned.shuttle)
	if(built_cargo["items"] < spawned_cargo["items"] * 0.8)
		problems += "[built_cargo["items"]] items aboard, spawned with [spawned_cargo["items"]]"
	if(built_cargo["mobs"] < spawned_cargo["mobs"])
		problems += "[built_cargo["mobs"]] creatures aboard ([built_cargo["mob_types"]]), spawned with [spawned_cargo["mobs"]] ([spawned_cargo["mob_types"]])"
	// Networks, once atmospherics has joined everything up.
	settle_order_networks()
	var/list/built_plumbing = plumbing_state(built.shuttle)
	var/list/spawned_plumbing = plumbing_state(spawned.shuttle)
	for(var/key in (built_plumbing | spawned_plumbing))
		if(built_plumbing[key] != spawned_plumbing[key])
			problems += "plumbing [key] [built_plumbing[key] || 0], spawned [spawned_plumbing[key] || 0]"
	var/list/built_atmos = atmos_problems(built.shuttle)
	var/list/spawned_atmos = atmos_problems(spawned.shuttle)
	if(length(built_atmos) > length(spawned_atmos))
		problems += "[length(built_atmos)] pipe problems, spawned with [length(spawned_atmos)]: [built_atmos.Join("; ")]"
	for(var/problem in problems)
		TEST_FAIL("[label]: [problem]")
	var/summary = "[length(problems) ? "[length(problems)] differences" : "identical"]; [length(built_tiles)] tiles, [built_cargo["items"]]/[spawned_cargo["items"]] items, [built_cargo["mobs"]]/[spawned_cargo["mobs"]] creatures, [built_loose_count]/[spawned_loose_count] loose structures ([loose_tiles] tiles differ), [rolled_tiles] fittings rolled differently; swept [swept]; left off-hull [left]"
	leave_bay(built, home, order.hull_type)
	spawned.shuttle.admin_delete_shuttle()
	return summary

/datum/unit_test/voidcrew_checkpoints/every_ship/ship_orders/proc/selection_text(list/selections)
	var/list/parts = list()
	for(var/slot_key in selections)
		var/datum/ship_upgrade_module/module = selections[slot_key]
		parts += "[slot_key]=[module?.id]"
	sortTim(parts, GLOBAL_PROC_REF(cmp_text_asc))
	return parts.Join(",")

/datum/unit_test/voidcrew_checkpoints/every_ship/ship_orders/proc/job_text(obj/structure/overmap/ship/ship)
	var/list/parts = list()
	for(var/datum/job/crew_job as anything in ship.job_slots)
		parts += "[crew_job.title]=[ship.job_slots[crew_job]]"
	sortTim(parts, GLOBAL_PROC_REF(cmp_text_asc))
	return parts.Join(",")

/**
 * One line per tile: turf, room and every anchored fitting's type, compared exactly. Unanchored
 * structures go to loose_lines instead, one line per tile. Loose items, creatures, landmarks
 * and pipe cap visuals are left out (see cargo_counts()).
 */
/datum/unit_test/voidcrew_checkpoints/every_ship/ship_orders/proc/tile_lines(obj/docking_port/mobile/port, list/loose_lines)
	var/list/lines = list()
	for(var/turf/tile as anything in port.return_ordered_turfs(port.x, port.y, port.z, port.dir))
		if(!(tile.loc in port.shuttle_areas))
			lines += "outside"
			loose_lines += ""
			continue
		var/list/things = list()
		var/list/loose = list()
		for(var/obj/thing in tile)
			if(isitem(thing) || istype(thing, /obj/effect/landmark) || istype(thing, /obj/effect/overlay/cap_visual) || istype(thing, /obj/docking_port))
				continue
			// Every mapped emergency closet deletes itself 1% of the time at load (tg's
			// emcloset Initialize), so any two loads of a hull can differ by one.
			if(istype(thing, /obj/structure/closet/emcloset))
				continue
			if(isstructure(thing) && !thing.anchored)
				loose += "[thing.type]"
				continue
			things += "[thing.type]"
		sortTim(things, GLOBAL_PROC_REF(cmp_text_asc))
		sortTim(loose, GLOBAL_PROC_REF(cmp_text_asc))
		lines += "[tile.type] [tile.loc.type] [things.Join(",")]"
		loose_lines += loose.Join(",")
	return lines

/datum/unit_test/voidcrew_checkpoints/every_ship/ship_orders/proc/loose_count(list/loose_lines)
	. = 0
	for(var/line in loose_lines)
		if(line)
			. += length(splittext(line, ","))

/datum/unit_test/voidcrew_checkpoints/every_ship/ship_orders/proc/cargo_counts(obj/docking_port/mobile/port)
	var/list/counts = list("items" = 0, "mobs" = 0)
	var/list/mob_types = list()
	for(var/turf/tile as anything in port.return_turfs())
		if(!(tile.loc in port.shuttle_areas))
			continue
		for(var/atom/movable/thing as anything in tile.get_all_contents())
			if(isitem(thing))
				counts["items"]++
			else if(isliving(thing) && isturf(thing.loc))
				// Mapped creatures. Stowaways inside fittings (wardrobe moths) are rolled at random.
				counts["mobs"]++
				mob_types += "[thing.type]"
	counts["mob_types"] = mob_types.Join(", ")
	return counts

/// settle_networks(), with room for a large hull's first rebuild.
/datum/unit_test/voidcrew_checkpoints/every_ship/ship_orders/proc/settle_order_networks()
	var/deadline = world.time + 60 SECONDS
	while((length(SSair.rebuild_queue) || length(SSair.expansion_queue)) && world.time < deadline)
		sleep(1)
	TEST_ASSERT(SSair.can_fire, "Atmospherics was left paused")
	sleep(5)

/**
 * Whether two tile lines differ only by what a random spawner picked: the same turf and room,
 * the same number of fittings, and every differing fitting paired with a relative (the same
 * /obj/x/y family, such as a cardboard box and a metal one). The build moves the objects the
 * load made and never swaps one type for another, so such a swap is the load's own roll.
 */
/datum/unit_test/voidcrew_checkpoints/every_ship/ship_orders/proc/rolled_alike(built_line, spawned_line)
	var/list/built_parts = splittext(built_line, " ")
	var/list/spawned_parts = splittext(spawned_line, " ")
	if(length(built_parts) != 3 || length(spawned_parts) != 3)
		return FALSE
	if(built_parts[1] != spawned_parts[1] || built_parts[2] != spawned_parts[2])
		return FALSE
	var/list/built_things = splittext(built_parts[3], ",")
	var/list/spawned_things = splittext(spawned_parts[3], ",")
	if(length(built_things) != length(spawned_things))
		return FALSE
	for(var/thing in built_things.Copy())
		if(thing in spawned_things)
			built_things -= thing
			spawned_things -= thing
	for(var/thing in built_things)
		var/list/family = splittext(thing, "/")
		if(length(family) < 4)
			return FALSE
		var/prefix = "/[family[2]]/[family[3]]/[family[4]]"
		var/matched
		for(var/other in spawned_things)
			if(other == prefix || findtext(other, "[prefix]/") == 1)
				matched = other
				break
		if(!matched)
			return FALSE
		spawned_things -= matched
	return TRUE

/// Every fitting type in a set of tile lines, counted.
/datum/unit_test/voidcrew_checkpoints/every_ship/ship_orders/proc/fitting_totals(list/lines)
	var/list/totals = list()
	for(var/line in lines)
		var/list/parts = splittext(line, " ")
		if(length(parts) != 3 || !parts[3])
			continue
		for(var/type_name in splittext(parts[3], ","))
			totals[type_name]++
	return totals
