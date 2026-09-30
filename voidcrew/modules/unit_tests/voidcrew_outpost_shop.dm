/**
 * Outpost owner shop (spec 3.3, R1, abuse review F-25 to F-27): the room at every rotation, what
 * the stock unit refuses, who may stock, price and take, listings, sales and their refusals,
 * hardened UI params, the stock unit surviving abuse, teardown, and the UI payload.
 *
 * Voidcrew defines are not visible from test files, so prices, ids and sizes appear as literals.
 * The shop has one map per outpost style; the tests find the register, queue, staff side and
 * doors in the placed room (shop_queue_turf() and friends), so they hold for every style.
 */

/// A stock unit whose payment always fails after the goods are staged (F-26)
/obj/machinery/outpost_shop_stock/refusing_payment

/obj/machinery/outpost_shop_stock/refusing_payment/take_payment(mob/living/buyer, datum/bank_account/account, total, label)
	return "Payment failed."

/// The claim's shop, placed at `rotation` beside the shell; the blueprint or an error string
/datum/unit_test/voidcrew_outpost_management/proc/place_test_shop(obj/structure/overmap/dynamic/player_outpost/home, rotation = 0)
	var/datum/outpost_upgrade/service/shop/blueprint = new(home)
	home.outpost_upgrades["shop"] = blueprint
	return place_test_service_room(home, blueprint, list(rotation))

// Spots in the placed shop, found by what stands there rather than by map coordinates, so the tests
// hold for every shop map in every style.

/// The customer's tile in front of the register
/datum/unit_test/voidcrew_outpost_management/proc/shop_queue_turf(datum/outpost_upgrade/service/shop/shop)
	var/obj/machinery/computer/outpost_shop_register/register = shop.register_ref?.resolve()
	var/list/customer = shop.visitor_reach()
	for(var/direction in GLOB.cardinals)
		var/turf/front = get_step(register, direction)
		if(customer[front] && !outpost_room_edge_blocked(front, get_turf(register)))
			return front
	return null

/// A clear floor tile beside the stock unit, which only staff reach
/datum/unit_test/voidcrew_outpost_management/proc/shop_staff_turf(datum/outpost_upgrade/service/shop/shop)
	var/list/routes = shop.exit_routes()
	var/list/staff = outpost_room_walk(routes[1][1], shop.room_lookup())
	for(var/direction in GLOB.cardinals)
		var/turf/beside = get_step(shop.get_stock(), direction)
		if(staff[beside] && !beside.is_blocked_turf(exclude_mobs = TRUE))
			return beside
	return null

/// A customer's tile well away from the register: just inside the entrance
/datum/unit_test/voidcrew_outpost_management/proc/shop_away_turf(datum/outpost_upgrade/service/shop/shop)
	var/list/routes = shop.exit_routes()
	return routes[1][1]

/// Units of `stack_type` a mob holds or stands on
/datum/unit_test/voidcrew_outpost_management/proc/shop_units_near(mob/living/holder, stack_type)
	. = 0
	var/turf/floor = get_turf(holder)
	for(var/obj/item/stack/stack in holder.get_all_contents_type(stack_type) + floor.contents)
		if(istype(stack, stack_type))
			. += stack.amount

// ===== THE ROOM AT EVERY ROTATION =====

/datum/unit_test/voidcrew_outpost_shop_placement
	parent_type = /datum/unit_test/voidcrew_outpost_management

/datum/unit_test/voidcrew_outpost_shop_placement/Run()
	var/obj/structure/overmap/dynamic/player_outpost/home = market_test_claim("shopplacer")
	TEST_ASSERT_NOTNULL(home, "The shop placement outpost did not load")
	var/datum/outpost_upgrade/service/shop/prototype = GLOB.outpost_upgrade_catalog["shop"]
	TEST_ASSERT(istype(prototype), "The shop is missing from the upgrade catalog")
	TEST_ASSERT_EQUAL(prototype.price, 2000, "The shop's price is wrong")
	var/list/room_turfs = list()
	for(var/rotation in list(0, 90, 180, 270))
		var/mapping_log_count = length(GLOB.unit_test_mapping_logs)
		var/result = place_test_shop(home, rotation)
		TEST_ASSERT(istype(result, /datum/outpost_upgrade/service/shop), "The shop was not placed at [rotation] degrees: [result]")
		var/datum/outpost_upgrade/service/shop/shop = result
		if(length(GLOB.unit_test_mapping_logs) > mapping_log_count)
			TEST_FAIL("Placing the shop at [rotation] degrees logged mapping errors: [jointext(GLOB.unit_test_mapping_logs.Copy(mapping_log_count + 1), "; ")]")
		var/list/footprint = shop.room_turfs()
		room_turfs += footprint
		for(var/turf/tile as anything in footprint)
			TEST_ASSERT_EQUAL(tile.loc, shop.installed_area, "Shop tile [tile.x],[tile.y] is not in the room's own area at [rotation] degrees")

		// The fixtures stand where the map puts them and the room knows them
		var/obj/machinery/outpost_shop_stock/stock = shop.get_stock()
		var/obj/machinery/computer/outpost_shop_register/register = shop.register_ref?.resolve()
		TEST_ASSERT_NOTNULL(stock, "The shop linked no stock unit at [rotation] degrees")
		TEST_ASSERT_NOTNULL(register, "The shop linked no register at [rotation] degrees")
		for(var/problem in shop.contract_problems())
			TEST_FAIL("The shop at [rotation] degrees: [problem]")
		var/turf/queue = shop_queue_turf(shop)
		TEST_ASSERT_NOTNULL(queue, "No customer tile in front of the register at [rotation] degrees")
		TEST_ASSERT_EQUAL(register.dir, get_dir(register, queue), "The register does not face the customers at [rotation] degrees")
		TEST_ASSERT(HAS_TRAIT(stock, "outpost_property"), "The stock unit is not outpost property at [rotation] degrees")
		TEST_ASSERT(stock.flags_1 & PREVENT_CONTENTS_EXPLOSION_1, "Explosions reach the stock at [rotation] degrees")
		TEST_ASSERT(HAS_TRAIT(register, "outpost_property"), "The register is not outpost property at [rotation] degrees")
		TEST_ASSERT(register.Adjacent(queue), "The queue tile does not reach the register at [rotation] degrees")

		// One door out with a fan; the staff door opens freely only from the staff side
		var/obj/machinery/door/airlock/outpost/service/staff/staff_door
		for(var/turf/tile as anything in footprint)
			staff_door ||= locate() in tile
		TEST_ASSERT_NOTNULL(staff_door, "No staff door at [rotation] degrees")
		var/list/customer = shop.visitor_reach()
		var/turf/staff_side = get_step(staff_door, staff_door.unres_sides)
		TEST_ASSERT(staff_side && !customer[staff_side], "The staff door opens freely from the customers' side at [rotation] degrees")
		var/list/doors_out = upgrade_exterior_doors(footprint)
		TEST_ASSERT_EQUAL(length(doors_out[1]), 1, "The shop should have one door out at [rotation] degrees")
		TEST_ASSERT(!length(doors_out[2]), "The shop's door out has no tiny fan at [rotation] degrees")
		var/obj/machinery/door/airlock/outpost/service/entrance = doors_out[1][1]
		TEST_ASSERT(!istype(entrance, /obj/machinery/door/airlock/outpost/service/staff), "The entrance is a staff door at [rotation] degrees")
		for(var/turf/tile as anything in footprint)
			for(var/obj/structure/fixture in tile)
				TEST_ASSERT(fixture.anchored, "[fixture] in the shop is not anchored at [rotation] degrees")

		// Management console plumbing
		TEST_ASSERT(shop.installed && shop.is_open, "The shop is not installed and open at [rotation] degrees")

		// One shop per claim: forget this one so the next rotation can be placed
		home.outpost_upgrades -= "shop"
		qdel(shop)
	settle_room_air(room_turfs)

// ===== STOCK, PERMISSIONS, SALES =====

/datum/unit_test/voidcrew_outpost_shop_trade
	parent_type = /datum/unit_test/voidcrew_outpost_management

/datum/unit_test/voidcrew_outpost_shop_trade/Run()
	var/obj/structure/overmap/dynamic/player_outpost/home = market_test_claim("shopowner")
	TEST_ASSERT_NOTNULL(home, "The shop trade outpost did not load")
	var/result = place_test_shop(home, 0)
	TEST_ASSERT(istype(result, /datum/outpost_upgrade/service/shop), "The shop was not placed: [result]")
	var/datum/outpost_upgrade/service/shop/shop = result
	var/obj/machinery/outpost_shop_stock/stock = shop.get_stock()
	var/obj/machinery/computer/outpost_shop_register/register = shop.register_ref.resolve()
	var/turf/staff_spot = shop_staff_turf(shop)
	var/turf/queue = shop_queue_turf(shop)
	var/turf/away = shop_away_turf(shop)

	var/mob/living/carbon/human/owner = make_market_visitor(staff_spot, "shopowner", 0)
	home.founder_mind = WEAKREF(owner.mind)
	var/mob/living/carbon/human/steward = make_market_visitor(staff_spot, "shopsteward", 0)
	var/mob/living/carbon/human/treasurer = make_market_visitor(staff_spot, "shoptreasurer", 0)
	var/mob/living/carbon/human/pricer = make_market_visitor(staff_spot, "shoppricer", 0)
	var/mob/living/carbon/human/resident = make_market_visitor(queue, "shopresident", 1000)
	var/mob/living/carbon/human/visitor = make_market_visitor(queue, "shopvisitor", 1000)
	home.residents += list(steward.mind, treasurer.mind, pricer.mind, resident.mind)
	home.stewards += steward.mind
	home.treasurers += treasurer.mind
	home.pricers += pricer.mind
	var/datum/bank_account/visitor_account = visitor.get_idcard(TRUE).registered_account
	var/datum/bank_account/resident_account = resident.get_idcard(TRUE).registered_account

	// --- Permissions (R1, spec 1.4) ---
	TEST_ASSERT(stock.can_stock(owner) && stock.can_price(owner), "The owner cannot run the shop")
	TEST_ASSERT(stock.can_stock(steward) && !stock.can_price(steward), "A steward's shop rights are wrong")
	TEST_ASSERT(!stock.can_stock(treasurer) && stock.can_price(treasurer), "A treasurer's shop rights are wrong")
	TEST_ASSERT(!stock.can_stock(pricer) && stock.can_price(pricer), "A pricer's shop rights are wrong")
	for(var/mob/living/outsider as anything in list(resident, visitor))
		TEST_ASSERT(!stock.can_stock(outsider) && !stock.can_price(outsider), "[outsider.ckey] can use the stock unit")
		TEST_ASSERT_EQUAL(stock.owner_action(outsider, "toggle_open", list()), "Staff only.", "[outsider.ckey] reached the owner window")
		TEST_ASSERT_EQUAL(stock.ui_status(outsider, GLOB.physical_state), UI_CLOSE, "[outsider.ckey] can keep the owner window open")
	var/obj/item/wrench/probe = allocate(__IMPLIED_TYPE__, staff_spot)
	TEST_ASSERT_NOTNULL(stock.stock_item(probe, treasurer), "A treasurer stocked the shop")
	TEST_ASSERT_NULL(stock.stock_item(probe, steward), "A steward could not stock the shop")
	var/datum/outpost_shop_listing/probe_listing = stock.listing_of[probe]
	var/list/probe_ids = list(probe_listing.id)
	TEST_ASSERT_EQUAL(stock.owner_action(steward, "set_price", list("ids" = probe_ids, "price" = 5)), "Not authorised.", "A steward set a price")
	TEST_ASSERT_EQUAL(stock.owner_action(steward, "eject", list("ids" = probe_ids)), "Not authorised.", "A steward took stock out")
	TEST_ASSERT_NULL(stock.owner_action(pricer, "set_price", list("ids" = probe_ids, "price" = 5)), "A pricer could not set a price")
	TEST_ASSERT_NULL(stock.owner_action(treasurer, "eject", list("ids" = probe_ids)), "A treasurer could not take stock out")
	TEST_ASSERT(probe.loc != stock, "The eject left the wrench in stock")
	// A retired owner body keeps the ckey but not the controls
	home.founder_mind = WEAKREF(allocate(/datum/mind, "someone else"))
	TEST_ASSERT(!stock.can_stock(owner) && !stock.can_price(owner), "A retired owner body runs the shop")
	home.founder_mind = WEAKREF(owner.mind)

	// --- Refusals, one per row (spec 3.3.1) ---
	var/list/refused = list()
	var/obj/item/toy/plush/pet_holder = allocate(__IMPLIED_TYPE__, staff_spot)
	allocate(/mob/living/basic/mouse, pet_holder)
	refused["a mob inside"] = pet_holder
	refused["an ID"] = allocate(/obj/item/card/id, staff_spot)
	var/obj/item/storage/box/full_box = allocate(__IMPLIED_TYPE__, staff_spot)
	allocate(/obj/item/pen, full_box)
	refused["a full box"] = full_box
	var/obj/item/bodybag/bag = allocate(__IMPLIED_TYPE__, staff_spot)
	allocate(/obj/item/pen, bag)
	refused["a folded bag with contents"] = bag
	refused["vouchers"] = allocate(/obj/item/stack/trade_voucher, staff_spot)
	refused["cash"] = allocate(/obj/item/stack/spacecash/c100, staff_spot)
	refused["a holochip"] = allocate(/obj/item/holochip, staff_spot, 100)
	refused["contract goods"] = allocate(/obj/item/mission_recovery, staff_spot)
	var/obj/item/grenade/frag/armed = allocate(__IMPLIED_TYPE__, staff_spot)
	armed.active = TRUE
	refused["a primed grenade"] = armed
	var/obj/item/weldingtool/lit = allocate(__IMPLIED_TYPE__, staff_spot)
	lit.welding = TRUE
	refused["a lit welder"] = lit
	refused["a TTV"] = allocate(/obj/item/transfer_valve, staff_spot)
	var/obj/item/wrench/ghostly = allocate(__IMPLIED_TYPE__, staff_spot)
	ghostly.item_flags |= ABSTRACT
	refused["an abstract item"] = ghostly
	for(var/label in refused)
		var/obj/item/thing = refused[label]
		TEST_ASSERT_NOTNULL(stock.stock_item(thing, owner), "The stock unit took [label]")
		TEST_ASSERT(thing.loc != stock, "A refused [label] ended up in stock")
	lit.welding = FALSE
	armed.active = FALSE
	for(var/accepted_type in list(/obj/item/wrench, /obj/item/storage/box, /obj/item/crowbar, /obj/item/screwdriver, /obj/item/pen))
		var/obj/item/good = allocate(accepted_type, staff_spot)
		TEST_ASSERT_NULL(stock.stock_item(good, owner), "The stock unit refused a [good.name]")

	// --- Listings (F-27 state keys, stacks, emptied listings) ---
	var/obj/item/wrench/first = allocate(__IMPLIED_TYPE__, staff_spot)
	var/obj/item/wrench/second = allocate(__IMPLIED_TYPE__, staff_spot)
	var/obj/item/wrench/renamed = allocate(__IMPLIED_TYPE__, staff_spot)
	renamed.name = "golden wrench"
	stock.stock_item(first, owner)
	stock.stock_item(second, owner)
	stock.stock_item(renamed, owner)
	TEST_ASSERT_EQUAL(stock.listing_of[first], stock.listing_of[second], "Two plain wrenches made two listings")
	TEST_ASSERT(stock.listing_of[first] != stock.listing_of[renamed], "A renamed wrench joined the plain ones")
	var/obj/item/reagent_containers/syringe/clean = allocate(__IMPLIED_TYPE__, staff_spot)
	var/obj/item/reagent_containers/syringe/also_clean = allocate(__IMPLIED_TYPE__, staff_spot)
	var/obj/item/reagent_containers/syringe/poisoned = allocate(__IMPLIED_TYPE__, staff_spot)
	poisoned.reagents.add_reagent(/datum/reagent/toxin, 5)
	for(var/obj/item/syringe_unit as anything in list(clean, also_clean, poisoned))
		TEST_ASSERT_NULL(stock.stock_item(syringe_unit, owner), "A syringe was refused")
	TEST_ASSERT_EQUAL(stock.listing_of[clean], stock.listing_of[also_clean], "Two empty syringes made two listings")
	TEST_ASSERT(stock.listing_of[clean] != stock.listing_of[poisoned], "A poisoned syringe shares a listing with clean ones")

	var/obj/item/stack/sheet/iron/sheets = allocate(__IMPLIED_TYPE__, staff_spot, 30)
	TEST_ASSERT_NULL(stock.stock_item(sheets, owner), "Iron sheets were refused")
	// Made only once the first stack is in stock, so the two never merge on the floor
	var/obj/item/stack/sheet/iron/more_sheets = allocate(__IMPLIED_TYPE__, staff_spot, 30)
	TEST_ASSERT_EQUAL(sheets.amount, 30, "The stocked stack merged with one on the floor")
	TEST_ASSERT_NULL(stock.stock_item(more_sheets, owner), "More iron sheets were refused")
	var/datum/outpost_shop_listing/iron = stock.listing_of[sheets]
	TEST_ASSERT_NOTNULL(iron, "The iron sheets have no listing")
	TEST_ASSERT_EQUAL(iron.unit_count(), 60, "Stocking lost or made sheets")
	TEST_ASSERT_EQUAL(sheets.amount, 50, "The first stack was not topped up to its maximum")
	TEST_ASSERT_EQUAL(more_sheets.amount, 10, "The second stack did not keep what was left after the top-up")
	TEST_ASSERT_EQUAL(length(iron.units), 2, "The sheets did not fill one stack before starting another")
	TEST_ASSERT(iron.is_stack, "The iron listing is not priced per unit")

	var/datum/outpost_shop_listing/wrenches = stock.listing_of[first]
	TEST_ASSERT_NULL(stock.owner_action(owner, "set_price", list("ids" = list(wrenches.id), "price" = 40)), "The owner could not price the wrenches")
	TEST_ASSERT_NULL(stock.owner_action(owner, "eject", list("ids" = list(wrenches.id))), "The owner could not empty the wrench listing")
	TEST_ASSERT_EQUAL(wrenches.unit_count(), 0, "The wrench listing is not empty")
	TEST_ASSERT_EQUAL(stock.listings_by_id[wrenches.id], wrenches, "An emptied listing was dropped")
	var/obj/item/wrench/returned = allocate(__IMPLIED_TYPE__, staff_spot)
	stock.stock_item(returned, owner)
	TEST_ASSERT_EQUAL(stock.listing_of[returned], wrenches, "A returned wrench did not rejoin its listing")
	TEST_ASSERT_EQUAL(wrenches.price, 40, "An emptied listing lost its price")
	var/datum/outpost_shop_listing/goldens = stock.listing_of[renamed]
	stock.owner_action(owner, "eject", list("ids" = list(goldens.id)))
	TEST_ASSERT_NULL(stock.owner_action(owner, "forget", list("ids" = list(goldens.id))), "An empty listing could not be forgotten")
	TEST_ASSERT_NULL(stock.listings_by_id[goldens.id], "Forgetting kept the listing")
	TEST_ASSERT_NOTNULL(stock.owner_action(owner, "forget", list("ids" = list(wrenches.id))), "A stocked listing was forgotten")

	// --- A visitor buys sheets (charged exactly, treasury credited exactly, units conserved) ---
	stock.owner_action(owner, "set_price", list("ids" = list(iron.id), "price" = 7))
	var/treasury_start = home.treasury.account_balance
	TEST_ASSERT_NULL(stock.sell(iron, 12, 7, visitor, register), "The visitor could not buy sheets")
	TEST_ASSERT_EQUAL(visitor_account.account_balance, 1000 - 84, "The visitor was not charged 12 x 7")
	TEST_ASSERT_EQUAL(home.treasury.account_balance, treasury_start + 84, "The treasury was not paid 12 x 7")
	TEST_ASSERT_EQUAL(iron.unit_count(), 48, "The sale did not take 12 sheets from stock")
	TEST_ASSERT_EQUAL(shop_units_near(visitor, /obj/item/stack/sheet/iron), 12, "The visitor did not get 12 sheets")
	var/list/last_sale = stock.sales_log[length(stock.sales_log)]
	TEST_ASSERT_EQUAL(last_sale["total"], 84, "The sales log has the wrong total")

	// F-26: a failed payment after staging moves nothing, even with a same stack under the buyer
	var/obj/item/stack/sheet/iron/floor_stack = allocate(__IMPLIED_TYPE__, queue, 5)
	var/obj/machinery/outpost_shop_stock/refusing_payment/refuser = allocate(__IMPLIED_TYPE__, get_turf(stock))
	shop.stock_ref = WEAKREF(refuser)
	var/obj/item/stack/sheet/iron/refuser_sheets = allocate(__IMPLIED_TYPE__, staff_spot, 20)
	TEST_ASSERT_NULL(refuser.stock_item(refuser_sheets, owner), "The refusing unit took no sheets")
	var/datum/outpost_shop_listing/refuser_iron = refuser.listing_of[refuser_sheets]
	refuser_iron.price = 7
	var/held_before = shop_units_near(visitor, /obj/item/stack/sheet/iron)
	var/balance_before = visitor_account.account_balance
	TEST_ASSERT_EQUAL(refuser.sell(refuser_iron, 5, 7, visitor, register), "Payment failed.", "A failed payment still sold")
	TEST_ASSERT_EQUAL(refuser_iron.unit_count(), 20, "A failed payment lost stock")
	TEST_ASSERT_EQUAL(length(refuser_iron.units), 1, "A failed payment left the stock split")
	TEST_ASSERT_EQUAL(floor_stack.amount, 5, "Goods merged into the buyer's floor stack before payment")
	TEST_ASSERT_EQUAL(shop_units_near(visitor, /obj/item/stack/sheet/iron), held_before, "The buyer kept goods from a failed payment")
	TEST_ASSERT_EQUAL(visitor_account.account_balance, balance_before, "A failed payment moved money")
	shop.stock_ref = WEAKREF(stock)
	qdel(refuser)

	// R1: a plain resident pays; staff take free (and must be shown 0)
	TEST_ASSERT_EQUAL(stock.sell(iron, 1, 0, resident, register), "Price changed to 7 cr.", "A resident took stock free")
	TEST_ASSERT_NULL(stock.sell(iron, 2, 7, resident, register), "A resident could not buy")
	TEST_ASSERT_EQUAL(resident_account.account_balance, 1000 - 14, "A resident was not charged like a visitor")
	steward.forceMove(queue)
	var/datum/bank_account/steward_account = steward.get_idcard(TRUE).registered_account
	TEST_ASSERT_EQUAL(stock.sell(iron, 1, 7, steward, register), "Price changed to 0 cr.", "Staff were charged the listed price")
	TEST_ASSERT_NULL(stock.sell(iron, 3, 0, steward, register), "A steward could not take stock")
	TEST_ASSERT_EQUAL(steward_account.account_balance, 0, "Taking stock moved money")
	last_sale = stock.sales_log[length(stock.sales_log)]
	TEST_ASSERT(last_sale["taken"], "A free take was not logged as taken")

	// --- Refusals with no money moved ---
	var/stock_before = iron.unit_count()
	balance_before = visitor_account.account_balance
	var/treasury_before = home.treasury.account_balance
	var/nan = text2num("nan")
	TEST_ASSERT_NOTNULL(stock.sell(iron, 1, 6, visitor, register), "A stale price sold")
	TEST_ASSERT_NOTNULL(stock.sell(iron, 51, 7, visitor, register), "More than one stack's worth sold")
	TEST_ASSERT_NOTNULL(stock.sell(iron, 1.5, 7, visitor, register), "A fractional quantity sold")
	TEST_ASSERT_NOTNULL(stock.sell(iron, -1, 7, visitor, register), "A negative quantity sold")
	TEST_ASSERT_NOTNULL(stock.sell(iron, "2", 7, visitor, register), "A text quantity sold")
	TEST_ASSERT_NOTNULL(stock.sell(iron, nan, 7, visitor, register), "A NaN quantity sold")
	TEST_ASSERT_NOTNULL(stock.sell(iron, 1, nan, visitor, register), "A NaN price sold")
	visitor.forceMove(away)
	TEST_ASSERT_EQUAL(stock.sell(iron, 1, 7, visitor, register), "Step up to the register.", "A buyer away from the register was served")
	visitor.forceMove(queue)
	visitor_account.mark_siphoned()
	TEST_ASSERT_EQUAL(stock.sell(iron, 1, 7, visitor, register), "Insufficient credits.", "A siphon-locked account paid")
	visitor_account.siphon_lock_until = 0
	visitor_account.account_balance = 3
	TEST_ASSERT_EQUAL(stock.sell(iron, 1, 7, visitor, register), "Insufficient credits.", "A short account paid")
	visitor_account.account_balance = balance_before
	var/obj/item/card/id/card = visitor.get_idcard(TRUE)
	// Take it out of the ID slot; moving it to nullspace alone leaves wear_id pointing at it
	visitor.temporarilyRemoveItemFromInventory(card, force = TRUE)
	TEST_ASSERT_NULL(visitor.get_idcard(TRUE), "The buyer still has an ID after taking it off")
	TEST_ASSERT_EQUAL(stock.sell(iron, 1, 7, visitor, register), "No bank account on your ID.", "A buyer with no ID paid")
	visitor.equip_to_slot_or_del(card, ITEM_SLOT_ID)
	// The door decides who reaches the register: a visitor at the counter gets past any door setting (a stale price proves it, and moves nothing)
	var/list/shop_doors = list()
	for(var/datum/weakref/shop_door_ref as anything in shop.doors)
		var/obj/machinery/door/shop_door = shop_door_ref.resolve()
		if(shop_door)
			shop_doors[shop_door] = outpost_door_access_of(shop_door)
			home.apply_door_access(shop_door, "owner")
	TEST_ASSERT_EQUAL(stock.sell(iron, 1, 6, visitor, register), "Price changed to 7 cr.", "A shop with keyed doors turned a visitor away at the counter")
	for(var/obj/machinery/door/shop_door as anything in shop_doors)
		home.apply_door_access(shop_door, shop_doors[shop_door])
	shop.is_open = FALSE
	TEST_ASSERT_EQUAL(stock.sell(iron, 1, 7, visitor, register), "Closed.", "A closed shop sold")
	shop.is_open = TRUE
	home.founder_ckey = null
	TEST_ASSERT_NOTNULL(stock.sell(iron, 1, 7, visitor, register), "An ownerless shop sold")
	home.founder_ckey = "shopowner"
	stock.owner_action(owner, "unlist", list("ids" = list(iron.id)))
	TEST_ASSERT_EQUAL(stock.sell(iron, 1, 7, visitor, register), "Not for sale.", "An unlisted item sold")
	stock.owner_action(owner, "set_price", list("ids" = list(iron.id), "price" = 7))
	TEST_ASSERT_EQUAL(iron.unit_count(), stock_before, "A refused sale moved stock")
	TEST_ASSERT_EQUAL(visitor_account.account_balance, balance_before, "A refused sale moved the buyer's money")
	TEST_ASSERT_EQUAL(home.treasury.account_balance, treasury_before, "A refused sale paid the treasury")

	// The register's own path: a buy through the UI handler charges once
	TEST_ASSERT_NULL(register.buy(visitor, iron.id, 1, 7), "The register could not sell")
	TEST_ASSERT_EQUAL(visitor_account.account_balance, balance_before - 7, "The register did not charge once")
	TEST_ASSERT_NOTNULL(register.buy(visitor, 1, 1, 7), "The register accepted a numeric id")

	// --- Param hardening on the owner window ---
	TEST_ASSERT_EQUAL(stock.owner_action(owner, "set_price", list("ids" = list(1), "price" = 5)), "Invalid selection.", "A numeric id was accepted")
	TEST_ASSERT_EQUAL(stock.owner_action(owner, "set_price", list("ids" = list(iron.id), "price" = nan)), "Invalid price.", "A NaN price was accepted")
	TEST_ASSERT_NOTNULL(stock.owner_action(owner, "set_price", list("ids" = list(iron.id), "price" = -5)), "A negative price was accepted")
	TEST_ASSERT_NOTNULL(stock.owner_action(owner, "set_price", list("ids" = list(iron.id), "price" = 2000000)), "A price over the cap was accepted")
	TEST_ASSERT_NULL(stock.owner_action(owner, "set_price", list("ids" = list(iron.id), "price" = 7.6)), "A fractional price was refused")
	TEST_ASSERT_EQUAL(iron.price, 8, "A fractional price was not rounded")
	var/list/too_many = list()
	for(var/index in 1 to 151)
		too_many += "[index]"
	TEST_ASSERT_EQUAL(stock.owner_action(owner, "eject", list("ids" = too_many)), "Invalid selection.", "An oversized id list was accepted")
	TEST_ASSERT_EQUAL(stock.owner_action(owner, "move", list("ids" = list(iron.id), "category" = "nope")), "Unknown category.", "An unknown category was accepted")
	TEST_ASSERT_EQUAL(stock.owner_action(owner, "move", list("ids" = list(iron.id), "category" = 1)), "Unknown category.", "A numeric category was accepted")
	TEST_ASSERT_NULL(stock.owner_action(owner, "add_category", list("name" = "Materials")), "A category could not be added")
	var/category_id = stock.categories[2]
	TEST_ASSERT_NULL(stock.owner_action(owner, "move", list("ids" = list(iron.id), "category" = category_id)), "A listing could not be moved")
	TEST_ASSERT_EQUAL(iron.category_id, category_id, "The move did not take")
	TEST_ASSERT_NULL(stock.owner_action(owner, "delete_category", list("id" = category_id)), "A category could not be deleted")
	TEST_ASSERT_EQUAL(iron.category_id, "0", "Deleting a category stranded its listings")
	TEST_ASSERT_NOTNULL(stock.owner_action(owner, "delete_category", list("id" = "0")), "Unsorted was deleted")

	// --- The stock unit keeps its stock ---
	var/stocked = length(stock.listing_of)
	EX_ACT(stock, EXPLODE_DEVASTATE)
	stock.dump_contents()
	stock.singularity_act()
	TEST_ASSERT(!QDELETED(stock), "The stock unit was destroyed")
	TEST_ASSERT_EQUAL(length(stock.listing_of), stocked, "Stock left the unit by force")
	TEST_ASSERT(stock.powered(), "The stock unit needs power")
	TEST_ASSERT(blocks_magic_recall(stock), "Summons can pull items out of stock")
	var/obj/item/pen/intruder = allocate(__IMPLIED_TYPE__, staff_spot)
	intruder.forceMove(stock)
	TEST_ASSERT(intruder.loc != stock, "Something got into stock around the insert path")

	// F-25: a unit marked by the seller cannot be recalled once sold
	var/obj/item/wrench/marked = allocate(__IMPLIED_TYPE__, staff_spot)
	marked.name = "marked wrench"
	var/datum/action/cooldown/spell/summonitem/summons = allocate(__IMPLIED_TYPE__, owner)
	summons.mark_item(marked)
	stock.stock_item(marked, owner)
	var/datum/outpost_shop_listing/marked_listing = stock.listing_of[marked]
	stock.owner_action(owner, "set_price", list("ids" = list(marked_listing.id), "price" = 1))
	TEST_ASSERT_NULL(stock.sell(marked_listing, 1, 1, visitor, register), "The marked wrench did not sell")
	TEST_ASSERT(HAS_TRAIT(marked, "recall_severed"), "A sold unit was not severed from summon marks")
	summons.try_recall_item(owner)
	TEST_ASSERT_NULL(summons.marked_item, "The seller's mark survived the sale")
	TEST_ASSERT(get(marked, /mob) == visitor || get_turf(marked) == queue, "The seller recalled a sold item")

	// --- Buyer and owner data ---
	var/list/buyer_data = register.ui_data(visitor)
	TEST_ASSERT(buyer_data["open"], "The buyer window says the shop is closed")
	TEST_ASSERT_EQUAL(buyer_data["account_credits"], visitor_account.account_balance, "The buyer window shows the wrong wallet")
	for(var/list/row as anything in buyer_data["listings"])
		TEST_ASSERT(row["price"] > 0, "The buyer window lists unpriced stock")
	var/list/staff_data = register.ui_data(treasurer)
	TEST_ASSERT(staff_data["free_take"], "The buyer window does not tell staff they take free")
	for(var/list/row as anything in staff_data["listings"])
		TEST_ASSERT_EQUAL(row["price"], 0, "Staff are shown a price")
	var/list/detail = shop.service_ui_data(treasurer)
	TEST_ASSERT_EQUAL(detail["kind"], "shop", "The Services tab detail has the wrong kind")
	TEST_ASSERT(detail["can_toggle"], "A treasurer cannot toggle the shop")
	TEST_ASSERT(shop.service_ui_act(treasurer, "toggle_open", list()), "The Services tab toggle was not handled")
	TEST_ASSERT(!shop.is_open, "The Services tab toggle did not close the shop")
	var/list/resident_detail = shop.service_ui_data(resident)
	TEST_ASSERT(!resident_detail["can_toggle"], "A resident can toggle the shop")
	shop.set_open(owner, TRUE)
	settle_room_air(shop.room_turfs())

// ===== TEARDOWN =====

/datum/unit_test/voidcrew_outpost_shop_teardown
	parent_type = /datum/unit_test/voidcrew_outpost_management

/datum/unit_test/voidcrew_outpost_shop_teardown/Run()
	var/obj/structure/overmap/dynamic/player_outpost/home = market_test_claim("shopteardownowner")
	TEST_ASSERT_NOTNULL(home, "The shop teardown outpost did not load")
	var/result = place_test_shop(home, 0)
	TEST_ASSERT(istype(result, /datum/outpost_upgrade/service/shop), "The shop was not placed: [result]")
	var/datum/outpost_upgrade/service/shop/shop = result
	var/obj/machinery/outpost_shop_stock/stock = shop.get_stock()
	var/mob/living/carbon/human/owner = make_market_visitor(shop_staff_turf(shop), "shopteardownowner", 0)

	// Stock goes with the outpost (M4)
	var/obj/item/wrench/goods = allocate(__IMPLIED_TYPE__, get_turf(owner))
	TEST_ASSERT_NULL(stock.stock_item(goods, owner), "The owner could not stock a wrench")
	var/datum/outpost_manipulator/unit_test/panel = allocate(__IMPLIED_TYPE__, owner)
	owner.forceMove(run_loc_floor_bottom_left)
	TEST_ASSERT_NULL(panel.deletion_denial(home), "The shop blocked deleting the outpost: [panel.deletion_denial(home)]")
	settle_room_air(shop.room_turfs())
	qdel(home)
	var/deadline = world.time + 30 SECONDS
	UNTIL(QDELETED(stock) || world.time > deadline)
	TEST_ASSERT(QDELETED(stock), "The stock unit outlived its outpost")
	TEST_ASSERT(QDELETED(goods), "Stock outlived its outpost")

// ===== UI PAYLOAD =====

/datum/unit_test/voidcrew_outpost_shop_payload
	parent_type = /datum/unit_test/voidcrew_outpost_management

/datum/unit_test/voidcrew_outpost_shop_payload/Run()
	var/obj/structure/overmap/dynamic/player_outpost/home = market_test_claim("shoppayloadowner")
	TEST_ASSERT_NOTNULL(home, "The shop payload outpost did not load")
	var/result = place_test_shop(home, 0)
	TEST_ASSERT(istype(result, /datum/outpost_upgrade/service/shop), "The shop was not placed: [result]")
	var/datum/outpost_upgrade/service/shop/shop = result
	var/obj/machinery/outpost_shop_stock/stock = shop.get_stock()
	var/obj/machinery/computer/outpost_shop_register/register = shop.register_ref.resolve()
	var/turf/staff_spot = shop_staff_turf(shop)
	var/mob/living/carbon/human/owner = make_market_visitor(staff_spot, "shoppayloadowner", 0)
	var/list/ids = list()
	for(var/index in 1 to 150)
		var/obj/item/wrench/unit = allocate(__IMPLIED_TYPE__, staff_spot)
		unit.name = "stock wrench number [index]"
		TEST_ASSERT_NULL(stock.stock_item(unit, owner), "Stocking listing [index] failed")
		var/datum/outpost_shop_listing/listing = stock.listing_of[unit]
		ids += listing.id
	var/obj/item/wrench/overflow = allocate(__IMPLIED_TYPE__, staff_spot)
	overflow.name = "one wrench too many"
	TEST_ASSERT_NOTNULL(stock.stock_item(overflow, owner), "A 151st listing was made")
	stock.owner_action(owner, "set_price", list("ids" = ids, "price" = 999999))
	var/owner_size = length(json_encode(stock.ui_data(owner)))
	var/buyer_size = length(json_encode(register.ui_data(owner)))
	TEST_ASSERT(owner_size < 40000, "The owner window sends [owner_size] bytes for 150 listings")
	TEST_ASSERT(buyer_size < 40000, "The buyer window sends [buyer_size] bytes for 150 listings")
	settle_room_air(shop.room_turfs())

// ===== WHAT IS INSIDE A UNIT (abuse review B-04, B-07, B-09) =====

/datum/unit_test/voidcrew_outpost_shop_contents
	parent_type = /datum/unit_test/voidcrew_outpost_management

/datum/unit_test/voidcrew_outpost_shop_contents/Run()
	var/obj/structure/overmap/dynamic/player_outpost/home = market_test_claim("shopinnerowner")
	TEST_ASSERT_NOTNULL(home, "The shop contents outpost did not load")
	var/result = place_test_shop(home, 0)
	TEST_ASSERT(istype(result, /datum/outpost_upgrade/service/shop), "The shop was not placed: [result]")
	var/datum/outpost_upgrade/service/shop/shop = result
	var/obj/machinery/outpost_shop_stock/stock = shop.get_stock()
	var/obj/machinery/computer/outpost_shop_register/register = shop.register_ref.resolve()
	var/turf/staff_spot = shop_staff_turf(shop)
	var/turf/queue = shop_queue_turf(shop)
	var/mob/living/carbon/human/owner = make_market_visitor(staff_spot, "shopinnerowner", 0)
	home.founder_mind = WEAKREF(owner.mind)
	var/mob/living/carbon/human/buyer = make_market_visitor(queue, "shopinnerbuyer", 1000)

	// B-04: a mark on the cell inside a sold gun does not recall the gun
	var/obj/item/gun/energy/laser/gun = allocate(__IMPLIED_TYPE__, staff_spot)
	var/obj/item/cell = gun.cell
	TEST_ASSERT_NOTNULL(cell, "The test gun has no cell")
	var/datum/action/cooldown/spell/summonitem/summons = allocate(__IMPLIED_TYPE__, owner)
	summons.mark_item(cell)
	TEST_ASSERT_NULL(stock.stock_item(gun, owner), "The gun could not be stocked")
	var/datum/outpost_shop_listing/gun_listing = stock.listing_of[gun]
	stock.owner_action(owner, "set_price", list("ids" = list(gun_listing.id), "price" = 1))
	TEST_ASSERT_NULL(stock.sell(gun_listing, 1, 1, buyer, register), "The gun did not sell")
	var/turf/sold_at = get_turf(gun)
	summons.try_recall_item(owner)
	TEST_ASSERT_NULL(summons.marked_item, "A mark on a sold gun's cell survived the sale")
	TEST_ASSERT(gun.loc == buyer || get_turf(gun) == sold_at, "A mark on a part recalled the whole sold gun")
	TEST_ASSERT_EQUAL(cell.loc, gun, "A mark on a part pulled the part out of the sold gun")

	// B-07: units that differ inside never share a listing
	var/list/grenades = list()
	for(var/reagent_type in list(/datum/reagent/water, /datum/reagent/toxin, null, null))
		var/obj/item/grenade/chem_grenade/grenade = allocate(__IMPLIED_TYPE__, staff_spot)
		var/obj/item/reagent_containers/cup/beaker/beaker = allocate(__IMPLIED_TYPE__, staff_spot)
		if(reagent_type)
			beaker.reagents.add_reagent(reagent_type, 10)
		beaker.forceMove(grenade)
		grenades += grenade
	TEST_ASSERT_NOTEQUAL(stock.listing_key(grenades[1]), stock.listing_key(grenades[2]), "Grenades with different beakers share a listing")
	TEST_ASSERT_EQUAL(stock.listing_key(grenades[3]), stock.listing_key(grenades[4]), "Grenades with the same empty beakers were split")
	var/obj/item/grenade/chem_grenade/bare = allocate(__IMPLIED_TYPE__, staff_spot)
	TEST_ASSERT_NOTEQUAL(stock.listing_key(bare), stock.listing_key(grenades[3]), "A grenade with a beaker shares a listing with an empty one")

	// B-09: nothing a signal can set off goes into stock
	var/obj/item/tank/internals/plasma/tank = allocate(__IMPLIED_TYPE__, staff_spot)
	var/obj/item/assembly_holder/holder = allocate(__IMPLIED_TYPE__, staff_spot)
	holder.forceMove(tank)
	tank.tank_assembly = holder
	TEST_ASSERT_NOTNULL(stock.refusal_reason(tank), "A tank bomb could be stocked")
	var/obj/item/assembly/signaler/signaler = allocate(__IMPLIED_TYPE__, staff_spot)
	TEST_ASSERT_NULL(stock.refusal_reason(signaler), "A bare signaler was refused: [stock.refusal_reason(signaler)]")
	var/obj/item/toy/plush/stuffed = allocate(__IMPLIED_TYPE__, staff_spot)
	var/obj/item/assembly/signaler/hidden = allocate(__IMPLIED_TYPE__, staff_spot)
	hidden.forceMove(stuffed)
	TEST_ASSERT_NOTNULL(stock.refusal_reason(stuffed), "An item hiding a signaler could be stocked")
	TEST_ASSERT(SEND_SIGNAL(stock, COMSIG_ATOM_INTERNAL_EXPLOSION, list()) & COMSIG_CANCEL_EXPLOSION, "An explosion inside the stock unit is not contained")

	// B-13: nobody is placed onto the counter, past its window, into the back room
	var/obj/structure/table/counter
	for(var/turf/tile as anything in shop.room_turfs())
		for(var/obj/structure/table/table in tile)
			TEST_ASSERT_NULL(table.GetComponent(/datum/component/table_smash), "[table] at [table.x],[table.y] still takes people placed on it")
			if(!counter && (locate(/obj/structure/window) in tile))
				counter = table
	TEST_ASSERT_NOTNULL(counter, "The shop has no counter")
	var/turf/counter_front = get_step(counter, SOUTH)
	var/mob/living/carbon/human/accomplice = make_market_visitor(counter_front, "shopinneraccomplice", 0)
	buyer.forceMove(counter_front)
	buyer.start_pulling(accomplice)
	counter.attack_hand(buyer)
	TEST_ASSERT(get_turf(accomplice) != get_turf(counter), "A visitor was placed onto the counter")
	buyer.stop_pulling()
	settle_room_air(shop.room_turfs())
