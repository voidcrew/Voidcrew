/**
 * Outpost floors (voidcrew/modules/trade_floors/): tests of package P12.
 * Owner: P12. Subtype /datum/unit_test/voidcrew_outpost_floors and use the helpers in
 * voidcrew_outpost_floors_helpers.dm (P0, frozen). Fork defines are included after the tests: write the literal
 * value with a comment naming the define. Pin other packages' outputs directly and never wait for an AI walk.
 *
 * The shop here is made by hand on the test floor's deck: a Shop room datum, its stock unit and its register, with no
 * map loaded. Kits are set down with deploy() and shelves sell with buy(): the waits and the question a player gets
 * are left out.
 */

/// Parent of the shopfront tests. It never runs.
/datum/unit_test/voidcrew_outpost_floors/shopfront
	abstract_type = /datum/unit_test/voidcrew_outpost_floors/shopfront
	/// Shop rooms made by shopfront_room(), freed with the test
	var/list/datum/outpost_upgrade/made_rooms = list()

/datum/unit_test/voidcrew_outpost_floors/shopfront/Destroy()
	// Offline keys stand in for players
	for(var/mob/player in allocated)
		if(!QDELETED(player))
			player.key = null
	QDEL_LIST(made_rooms)
	return ..()

/**
 * A floor with its host, owned by `owner_key`, with a Shop room unless `with_shop` is off. Null, and the test
 * failed, when the ground could not be had.
 */
/datum/unit_test/voidcrew_outpost_floors/shopfront/proc/shopfront_floor(owner_key = "floorshopowner", with_shop = TRUE)
	var/obj/structure/overmap/trader_outpost/outpost = test_outpost()
	var/datum/outpost_floor/floor = test_floor(outpost, 1, 14, 12, TRUE)
	if(!floor)
		return null
	var/obj/structure/overmap/dynamic/player_outpost/floor/host = floor.host
	host.founder_ckey = owner_key
	host.ensure_home_services()
	if(with_shop)
		shopfront_room(floor)
	return floor

/// Gives `floor` its Shop room: the stock unit and the room's own register stand on the deck at the north end
/datum/unit_test/voidcrew_outpost_floors/shopfront/proc/shopfront_room(datum/outpost_floor/floor)
	var/datum/outpost_upgrade/service/shop/room = new(floor.host)
	made_rooms += room
	floor.host.outpost_upgrades["shop"] = room
	room.installed = TRUE
	var/obj/machinery/outpost_shop_stock/stock = allocate(/obj/machinery/outpost_shop_stock, floor_tile(floor, 2, 9))
	var/obj/machinery/computer/outpost_shop_register/register = allocate(/obj/machinery/computer/outpost_shop_register, floor_tile(floor, 4, 9))
	room.stock_ref = WEAKREF(stock)
	room.register_ref = WEAKREF(register)
	return room

/// A person at `where` with a mind, playing `player_key` if one is given, and an ID whose account holds `balance`
/datum/unit_test/voidcrew_outpost_floors/shopfront/proc/shopfront_person(turf/where, player_key, balance = 0)
	var/mob/living/carbon/human/consistent/person = allocate(/mob/living/carbon/human/consistent, where)
	if(player_key)
		person.key = player_key
	person.mind_initialize()
	var/datum/bank_account/account = allocate(/datum/bank_account, person.real_name, null, 1, FALSE)
	account.account_balance = balance
	// The ID slot needs a jumpsuit; without one the card is deleted instead of worn
	person.equip_to_slot_or_del(allocate(/obj/item/clothing/under/color/grey), ITEM_SLOT_ICLOTHING)
	var/obj/item/card/id/card = allocate(/obj/item/card/id)
	card.registered_account = account
	card.registered_name = person.real_name
	person.equip_to_slot_or_del(card, ITEM_SLOT_ID)
	if(person.wear_id != card)
		TEST_FAIL("A shopfront test person could not wear their ID")
	return person

/// Puts `count` of `item_type` into the floor's stock at `price` a unit, as its owner would. Returns the listing.
/datum/unit_test/voidcrew_outpost_floors/shopfront/proc/shopfront_stock(datum/outpost_floor/floor, mob/living/owner, item_type, price, count = 1)
	var/obj/machinery/outpost_shop_stock/stock = floor.shop_stock()
	var/datum/outpost_shop_listing/listing
	for(var/index in 1 to count)
		var/obj/item/item = allocate(item_type, get_turf(owner))
		var/refusal = stock.stock_item(item, owner)
		if(refusal)
			TEST_FAIL("[item_type] would not go into the stock: [refusal]")
			return null
		listing = stock.listing_of[item] || listing
	listing?.price = price
	return listing

/// A kit refuses the landing, the goods lift, the hull, ground that is no floor, a stranger, a floor with no shop and the cap (A82)
/datum/unit_test/voidcrew_outpost_floors/shopfront/kit_refused

/datum/unit_test/voidcrew_outpost_floors/shopfront/kit_refused/Run()
	var/datum/outpost_floor/floor = shopfront_floor("floorshopowner", FALSE)
	if(!floor)
		return
	var/mob/living/owner = shopfront_person(deck_tile(floor, 6), "floorshopowner")
	var/mob/living/stranger = shopfront_person(deck_tile(floor, 7), "floorshopstranger")
	var/turf/deck = deck_tile(floor, 2)
	var/obj/item/outpost_floor_kit/till/kit = allocate(/obj/item/outpost_floor_kit/till, get_turf(owner))

	TEST_ASSERT_EQUAL(kit.deploy_refusal(owner, deck), "needs a shop!", "A kit went down on a floor with no Shop room")
	shopfront_room(floor)
	TEST_ASSERT_NULL(kit.deploy_refusal(owner, deck), "The owner's kit was refused on their own deck")

	var/turf/landing = locate(floor.landing_bounds[1], floor.landing_bounds[2], floor.landing_bounds[5])
	TEST_ASSERT_EQUAL(kit.deploy_refusal(owner, landing), "not here!", "A kit went down on the landing")
	TEST_ASSERT_EQUAL(kit.deploy_refusal(owner, floor_tile(floor, 0, 5)), "not here!", "A kit went down on the hull")
	var/turf/goods_tile = deck_tile(floor, 10)
	floor.goods_turfs += goods_tile
	TEST_ASSERT_EQUAL(kit.deploy_refusal(owner, goods_tile), "not here!", "A kit went down on the goods lift")
	floor.goods_turfs -= goods_tile
	// Ground that is nobody's floor: a ship, a berth, the concourse
	TEST_ASSERT_EQUAL(kit.deploy_refusal(owner, run_loc_floor_bottom_left), "not here!", "A kit went down off every floor")
	TEST_ASSERT_EQUAL(kit.deploy_refusal(stranger, deck), "not yours to build on!", "Someone else's kit went down on a crew's floor")
	TEST_ASSERT_NULL(kit.deploy(stranger, deck), "A stranger set a till down")
	TEST_ASSERT_EQUAL(floor.fitting_count("till"), 0, "A refused kit left a fitting behind") // OUTPOST_FLOOR_FITTING_TILL

	// A builder the owner names may; the cap is four tills (OUTPOST_FLOOR_TILLS_MAX)
	floor.host.authorized_builder_ckeys += "floorshopstranger"
	TEST_ASSERT_NULL(kit.deploy_refusal(stranger, deck), "A named builder's kit was refused")
	floor.host.authorized_builder_ckeys -= "floorshopstranger"
	for(var/index in 1 to 4)
		var/obj/item/outpost_floor_kit/till/next_kit = allocate(/obj/item/outpost_floor_kit/till, get_turf(owner))
		var/obj/fitting = next_kit.deploy(owner, deck_tile(floor, index))
		TEST_ASSERT_NOTNULL(fitting, "Till [index] of four would not go down")
		TEST_ASSERT(QDELETED(next_kit), "A kit was still there after its fitting went down")
	TEST_ASSERT_EQUAL(floor.fitting_count("till"), 4, "Four tills down are not counted as four")
	TEST_ASSERT_EQUAL(kit.deploy_refusal(owner, deck_tile(floor, 8)), "no more will fit!", "A fifth till went down")
	// A shelf has its own count, and will not share a tile with a till
	var/obj/item/outpost_floor_kit/shelf/shelf_kit = allocate(/obj/item/outpost_floor_kit/shelf, get_turf(owner))
	TEST_ASSERT_EQUAL(shelf_kit.deploy_refusal(owner, deck_tile(floor, 1)), "not here!", "A shelf went down on a till's tile")
	TEST_ASSERT_NULL(shelf_kit.deploy_refusal(owner, deck_tile(floor, 8)), "A shelf was refused for the tills' cap")

/// A fitting is outpost property: no tool and no blast takes it, it never blocks the way, it is never saved on a ship, and only a manager packs it away (A82, A94)
/datum/unit_test/voidcrew_outpost_floors/shopfront/fitting_property

/datum/unit_test/voidcrew_outpost_floors/shopfront/fitting_property/Run()
	var/datum/outpost_floor/floor = shopfront_floor()
	if(!floor)
		return
	var/mob/living/owner = shopfront_person(deck_tile(floor, 6), "floorshopowner")
	var/mob/living/stranger = shopfront_person(deck_tile(floor, 7), "floorshopstranger")
	var/obj/item/outpost_floor_kit/till/till_kit = allocate(/obj/item/outpost_floor_kit/till, get_turf(owner))
	var/obj/item/outpost_floor_kit/shelf/shelf_kit = allocate(/obj/item/outpost_floor_kit/shelf, get_turf(owner))
	var/obj/item/outpost_floor_kit/sign/sign_kit = allocate(/obj/item/outpost_floor_kit/sign, get_turf(owner))
	var/list/obj/fittings = list(
		till_kit.deploy(owner, deck_tile(floor, 5)),
		shelf_kit.deploy(owner, deck_tile(floor, 8)),
		sign_kit.deploy(owner, floor_tile(floor, 1, 6), floor_tile(floor, 0, 6)),
	)
	var/list/tool_types = list(/obj/item/wrench, /obj/item/screwdriver, /obj/item/crowbar, /obj/item/wirecutters)
	for(var/obj/fitting as anything in fittings)
		TEST_ASSERT_NOTNULL(fitting, "A fitting would not go down")
		if(!fitting)
			continue
		var/turf/stands = get_turf(fitting)
		TEST_ASSERT(HAS_TRAIT(fitting, "outpost_property"), "[fitting.type] is not outpost property") // TRAIT_OUTPOST_PROPERTY
		TEST_ASSERT(fitting.anchored, "[fitting.type] can be dragged off")
		TEST_ASSERT(is_type_in_typecache(fitting, GLOB.outpost_checkpoint_excluded), "[fitting.type] would be saved with a ship")
		// A94: it stops nobody
		TEST_ASSERT(!fitting.density, "[fitting.type] blocks the way")
		TEST_ASSERT(fitting.CanPass(stranger, EAST), "Nobody can walk across \a [fitting.type]")
		owner.forceMove(get_step(stands, EAST))
		for(var/tool_type in tool_types)
			var/obj/item/tool = allocate(tool_type, get_turf(owner))
			owner.put_in_active_hand(tool, forced = TRUE)
			tool.melee_attack_chain(owner, fitting)
			TEST_ASSERT(!QDELETED(fitting) && fitting.loc == stands && fitting.anchored, "[fitting.type] came apart under \a [tool]")
			owner.temporarilyRemoveItemFromInventory(tool, force = TRUE)
		EX_ACT(fitting, EXPLODE_DEVASTATE)
		TEST_ASSERT(!QDELETED(fitting) && fitting.loc == stands, "[fitting.type] did not survive a blast")

	// Only a manager packs one away, and it comes back as its kit
	var/obj/till = fittings[1]
	if(!till)
		return
	var/turf/till_turf = get_turf(till)
	TEST_ASSERT(!outpost_fitting_pack(till, stranger, /obj/item/outpost_floor_kit/till, TRUE), "A stranger packed away a crew's till")
	TEST_ASSERT(!QDELETED(till), "A refused packing took the till")
	TEST_ASSERT(outpost_fitting_pack(till, owner, /obj/item/outpost_floor_kit/till, TRUE), "The owner could not pack their till away")
	TEST_ASSERT(QDELETED(till), "A packed till is still standing")
	TEST_ASSERT_EQUAL(floor.fitting_count("till"), 0, "A packed till still counts") // OUTPOST_FLOOR_FITTING_TILL
	var/obj/item/outpost_floor_kit/till/repacked = owner.is_holding_item_of_type(/obj/item/outpost_floor_kit/till) || (locate(/obj/item/outpost_floor_kit/till) in till_turf)
	TEST_ASSERT_NOTNULL(repacked, "A packed till left no kit")
	if(repacked)
		allocated += repacked

/// A shelf sale charges the card once at the price quoted, refuses a moved price, and is written down as a shelf sale
/datum/unit_test/voidcrew_outpost_floors/shopfront/shelf_sale

/datum/unit_test/voidcrew_outpost_floors/shopfront/shelf_sale/Run()
	var/datum/outpost_floor/floor = shopfront_floor()
	if(!floor)
		return
	var/obj/structure/overmap/dynamic/player_outpost/floor/host = floor.host
	var/obj/machinery/outpost_shop_stock/stock = floor.shop_stock()
	var/mob/living/owner = shopfront_person(deck_tile(floor, 6), "floorshopowner")
	var/obj/item/outpost_floor_kit/shelf/kit = allocate(/obj/item/outpost_floor_kit/shelf, get_turf(owner))
	var/obj/structure/outpost_floor_shelf/shelf = kit.deploy(owner, deck_tile(floor, 3))
	TEST_ASSERT_NOTNULL(shelf, "The shelf would not go down")
	if(!shelf)
		return

	// The owner puts one thing on the shelf: it is in the stock, and the shelf shows its listing
	var/obj/item/flashlight/torch = allocate(/obj/item/flashlight, get_turf(owner))
	TEST_ASSERT_NULL(shelf.stock_shelf(owner, torch), "The owner could not stock their own shelf")
	TEST_ASSERT_EQUAL(torch.loc, stock, "A thing put on a shelf did not go into the stock")
	var/datum/outpost_shop_listing/listing = shelf.shown_listing()
	TEST_ASSERT_NOTNULL(listing, "The shelf does not show what was put on it")
	if(!listing)
		return
	TEST_ASSERT_EQUAL(stock.listing_of[torch], listing, "The shelf shows another listing than the one it was stocked with")
	listing.price = 120

	var/mob/living/buyer = shopfront_person(deck_tile(floor, 4), "floorshopbuyer", 500)
	var/datum/bank_account/card = buyer.get_idcard(TRUE).registered_account
	var/treasury_before = host.treasury.account_balance
	// The price moved after the buyer was asked: nothing is charged and nothing leaves
	TEST_ASSERT_NOTNULL(shelf.buy(buyer, listing, 100), "A shelf sold at a price that had moved")
	TEST_ASSERT_EQUAL(card.account_balance, 500, "A refused shelf sale charged the card")
	TEST_ASSERT_EQUAL(torch.loc, stock, "A refused shelf sale let the goods go")
	// From across the room
	var/mob/living/far_buyer = shopfront_person(deck_tile(floor, 9), "floorshopfar", 500)
	TEST_ASSERT_NOTNULL(shelf.buy(far_buyer, listing, 120), "A shelf sold to someone who was not at it")

	TEST_ASSERT_NULL(shelf.buy(buyer, listing, 120), "A shelf would not sell at its listed price")
	TEST_ASSERT_EQUAL(card.account_balance, 380, "A shelf sale did not charge the price once")
	TEST_ASSERT_EQUAL(host.treasury.account_balance, treasury_before + 120, "A shelf sale did not reach the treasury")
	TEST_ASSERT(buyer.is_holding(torch), "The buyer was not handed what they bought")
	var/list/entry = stock.sales_log[length(stock.sales_log)]
	TEST_ASSERT_EQUAL(entry["where"], "shelf", "A shelf sale is not written down as one") // OUTPOST_FLOOR_FITTING_SHELF
	TEST_ASSERT(!entry["npc"], "A player's purchase is written down as an NPC's")
	// The one unit is gone: a second yes buys nothing and charges nothing
	TEST_ASSERT_NOTNULL(shelf.buy(buyer, listing, 120), "An empty shelf sold")
	TEST_ASSERT_EQUAL(card.account_balance, 380, "An empty shelf charged the card")

/// A till sells from the Shop room's stock and writes "till"; the room's own register writes nothing new; a loose register sells nothing
/datum/unit_test/voidcrew_outpost_floors/shopfront/till_sale

/datum/unit_test/voidcrew_outpost_floors/shopfront/till_sale/Run()
	var/datum/outpost_floor/floor = shopfront_floor()
	if(!floor)
		return
	var/obj/structure/overmap/dynamic/player_outpost/floor/host = floor.host
	var/obj/machinery/outpost_shop_stock/stock = floor.shop_stock()
	var/mob/living/owner = shopfront_person(deck_tile(floor, 6), "floorshopowner")
	var/datum/outpost_shop_listing/listing = shopfront_stock(floor, owner, /obj/item/flashlight, 50, 3)
	if(!listing)
		return
	var/obj/item/outpost_floor_kit/till/kit = allocate(/obj/item/outpost_floor_kit/till, get_turf(owner))
	var/obj/machinery/computer/outpost_shop_register/floor_till/till = kit.deploy(owner, deck_tile(floor, 3))
	TEST_ASSERT_NOTNULL(till, "The till would not go down")
	if(!till)
		return
	TEST_ASSERT(host.owns_till(till), "A floor does not own its till")
	TEST_ASSERT_EQUAL(till.get_stock(), stock, "A till does not sell from the Shop room's stock")
	// A plain register that is not the room's own sells nothing, on a floor as anywhere
	var/obj/machinery/computer/outpost_shop_register/loose = allocate(/obj/machinery/computer/outpost_shop_register, deck_tile(floor, 11))
	TEST_ASSERT(!host.owns_till(loose), "A floor owns a register that is no till of its")
	TEST_ASSERT_NULL(loose.get_shop(), "A loose register sells from the floor's shop")

	var/mob/living/buyer = shopfront_person(deck_tile(floor, 4), "floorshopbuyer", 500)
	var/datum/bank_account/card = buyer.get_idcard(TRUE).registered_account
	var/treasury_before = host.treasury.account_balance
	TEST_ASSERT_NULL(till.buy(buyer, listing.id, 1, 50), "A till would not sell")
	TEST_ASSERT_EQUAL(card.account_balance, 450, "A till sale did not charge the card once")
	TEST_ASSERT_EQUAL(host.treasury.account_balance, treasury_before + 50, "A till sale did not reach the treasury")
	var/list/entry = stock.sales_log[length(stock.sales_log)]
	TEST_ASSERT_EQUAL(entry["where"], "till", "A till sale is not written down as one") // OUTPOST_FLOOR_FITTING_TILL
	TEST_ASSERT_NOTNULL(till.buy(buyer, listing.id, 1, 40), "A till sold at a price that had moved")
	TEST_ASSERT_EQUAL(card.account_balance, 450, "A refused till sale charged the card")

	// The room's own register is the stock unit's own sale and is left as it was
	var/obj/machinery/computer/outpost_shop_register/counter = floor.shop_room().register_ref.resolve()
	buyer.forceMove(get_step(counter, SOUTH))
	TEST_ASSERT_NULL(counter.buy(buyer, listing.id, 1, 50), "The room's own register would not sell")
	entry = stock.sales_log[length(stock.sales_log)]
	TEST_ASSERT_NULL(entry["where"], "The room's own register writes a place it was never given")

	// The till's window: staff get the open flag and the sales, a customer gets neither
	var/list/staff_data = till.ui_data(owner)
	TEST_ASSERT(staff_data["can_toggle"], "The owner cannot open and shut the shop at a till")
	TEST_ASSERT_EQUAL(length(staff_data["sales"]), 2, "The till does not show its staff the sales")
	var/list/buyer_data = till.ui_data(buyer)
	TEST_ASSERT(!buyer_data["can_toggle"], "A customer can open and shut the shop at a till")
	TEST_ASSERT_NULL(buyer_data["sales"], "A customer is shown the shop's sales")

/// A hired hand stocks, opens and shuts, and nothing else: no price, no taking out, no unlisting, no free stock (A80)
/datum/unit_test/voidcrew_outpost_floors/shopfront/hand_rights

/datum/unit_test/voidcrew_outpost_floors/shopfront/hand_rights/Run()
	var/datum/outpost_floor/floor = shopfront_floor()
	if(!floor)
		return
	var/obj/structure/overmap/dynamic/player_outpost/floor/host = floor.host
	var/obj/machinery/outpost_shop_stock/stock = floor.shop_stock()
	var/datum/outpost_upgrade/service/shop/room = floor.shop_room()
	var/mob/living/owner = shopfront_person(deck_tile(floor, 6), "floorshopowner")
	var/mob/living/hand = shopfront_person(deck_tile(floor, 4), "floorshophand", 500)
	var/mob/living/stranger = shopfront_person(deck_tile(floor, 7), "floorshopstranger")
	var/datum/outpost_shop_listing/listing = shopfront_stock(floor, owner, /obj/item/flashlight, 80, 2)
	if(!listing)
		return

	TEST_ASSERT(!host.is_shop_hand(hand), "Someone nobody hired is a hand")
	TEST_ASSERT(!stock.can_stock(hand), "Someone nobody hired can stock the shop")
	floor.hands += hand.mind
	TEST_ASSERT(host.is_shop_hand(hand), "A hired hand is not one")
	TEST_ASSERT(!host.is_shop_hand(stranger), "A stranger is a hand")
	TEST_ASSERT(!host.is_outpost_member(hand), "A hand is one of the floor's people")

	// Stocks: at the stock unit and at a shelf
	var/obj/item/flashlight/torch = allocate(/obj/item/flashlight, get_turf(hand))
	TEST_ASSERT_NULL(stock.stock_item(torch, hand), "A hand could not stock the shop")
	var/obj/item/outpost_floor_kit/shelf/kit = allocate(/obj/item/outpost_floor_kit/shelf, get_turf(owner))
	TEST_ASSERT_EQUAL(kit.deploy_refusal(hand, deck_tile(floor, 3)), "not yours to build on!", "A hand set a fitting down")
	var/obj/structure/outpost_floor_shelf/shelf = kit.deploy(owner, deck_tile(floor, 3))
	TEST_ASSERT_NOTNULL(shelf, "The shelf would not go down")
	if(!shelf)
		return
	var/obj/item/flashlight/second_torch = allocate(/obj/item/flashlight, get_turf(hand))
	TEST_ASSERT_NULL(shelf.stock_shelf(hand, second_torch), "A hand could not stock a shelf")
	TEST_ASSERT_NOTNULL(shelf.stock_shelf(stranger, allocate(/obj/item/flashlight, get_turf(stranger))), "A stranger stocked a shelf")

	// Opens and shuts
	TEST_ASSERT_NULL(room.set_open(hand, FALSE), "A hand could not shut the shop")
	TEST_ASSERT(!room.is_open, "The shop a hand shut is open")
	TEST_ASSERT_NOTNULL(room.set_open(stranger, TRUE), "A stranger opened the shop")
	TEST_ASSERT_NULL(stock.owner_action(hand, "toggle_open", list()), "A hand could not open the shop at the stock unit")
	TEST_ASSERT(room.is_open, "The shop a hand opened is shut")

	// And nothing else
	var/list/chosen = list("ids" = list(listing.id), "price" = 1)
	TEST_ASSERT(!stock.can_price(hand), "A hand may price")
	TEST_ASSERT_NOTNULL(stock.owner_action(hand, "set_price", chosen), "A hand set a price")
	TEST_ASSERT_EQUAL(listing.price, 80, "A hand's price took")
	TEST_ASSERT_NOTNULL(stock.owner_action(hand, "unlist", chosen), "A hand took a listing off sale")
	TEST_ASSERT_NOTNULL(stock.owner_action(hand, "eject", chosen), "A hand took stock out")
	TEST_ASSERT_EQUAL(listing.unit_count(), 4, "Stock left the shop at a hand's word")
	TEST_ASSERT(!host.can_take_shop_stock(hand), "A hand takes stock free")
	// A hand pays like anyone
	var/obj/machinery/computer/outpost_shop_register/counter = room.register_ref.resolve()
	hand.forceMove(get_step(counter, SOUTH))
	TEST_ASSERT_NOTNULL(counter.buy(hand, listing.id, 1, 0), "A hand took stock free at the register")
	TEST_ASSERT_NULL(counter.buy(hand, listing.id, 1, 80), "A hand could not buy at the listed price")
	TEST_ASSERT_EQUAL(hand.get_idcard(TRUE).registered_account.account_balance, 420, "A hand did not pay the listed price")

	// Let go, they are a stranger again; and nobody is a hand of a floor with no owner
	floor.hands -= hand.mind
	TEST_ASSERT(!host.is_shop_hand(hand), "Someone let go is still a hand")
	floor.hands += hand.mind
	host.founder_ckey = null
	TEST_ASSERT(!host.is_shop_hand(hand), "A floor with no owner has hands")

/// A shut shop sells nothing at any till or shelf, to a player or an NPC, and its signs say so
/datum/unit_test/voidcrew_outpost_floors/shopfront/shut_shop

/datum/unit_test/voidcrew_outpost_floors/shopfront/shut_shop/Run()
	var/datum/outpost_floor/floor = shopfront_floor()
	if(!floor)
		return
	var/datum/outpost_upgrade/service/shop/room = floor.shop_room()
	var/mob/living/owner = shopfront_person(deck_tile(floor, 6), "floorshopowner")
	var/datum/outpost_shop_listing/listing = shopfront_stock(floor, owner, /obj/item/flashlight, 40, 3)
	if(!listing)
		return
	var/obj/item/outpost_floor_kit/till/till_kit = allocate(/obj/item/outpost_floor_kit/till, get_turf(owner))
	var/obj/item/outpost_floor_kit/shelf/shelf_kit = allocate(/obj/item/outpost_floor_kit/shelf, get_turf(owner))
	var/obj/item/outpost_floor_kit/sign/sign_kit = allocate(/obj/item/outpost_floor_kit/sign, get_turf(owner))
	var/obj/machinery/computer/outpost_shop_register/floor_till/till = till_kit.deploy(owner, deck_tile(floor, 3))
	var/obj/structure/outpost_floor_shelf/shelf = shelf_kit.deploy(owner, deck_tile(floor, 5))
	var/obj/structure/sign/outpost_floor/hung = sign_kit.deploy(owner, floor_tile(floor, 1, 6), floor_tile(floor, 0, 6))
	if(!till || !shelf || !hung)
		TEST_FAIL("The fittings would not go down")
		return
	shelf.show_listing(listing)
	var/mob/living/buyer = shopfront_person(deck_tile(floor, 4), "floorshopbuyer", 500)
	var/datum/bank_account/card = buyer.get_idcard(TRUE).registered_account

	TEST_ASSERT(floor.shop_open(), "A shop that is open reads shut")
	TEST_ASSERT_EQUAL(floor.shop_sign_status(), "OPEN", "The signs of an open shop do not say OPEN")
	TEST_ASSERT(length(floor.npc_sale_points()) >= 3, "An open shop with a register, a till and a shelf has fewer than three places to buy")

	TEST_ASSERT_NULL(room.set_open(owner, FALSE), "The owner could not shut the shop")
	TEST_ASSERT(!floor.shop_open(), "A shut shop reads open")
	TEST_ASSERT_EQUAL(floor.shop_sign_status(), "SHUT", "The signs of a shut shop do not say SHUT")
	TEST_ASSERT(findtext(hung.maptext, "SHUT"), "The sign on the wall was not redrawn when the shop shut")
	TEST_ASSERT_NOTNULL(till.buy(buyer, listing.id, 1, 40), "A till sold while the shop was shut")
	TEST_ASSERT_NOTNULL(shelf.buy(buyer, listing, 40), "A shelf sold while the shop was shut")
	TEST_ASSERT_EQUAL(card.account_balance, 500, "A shut shop charged a card")
	TEST_ASSERT_EQUAL(listing.unit_count(), 3, "A shut shop let stock go")
	TEST_ASSERT_EQUAL(length(floor.npc_sale_points()), 0, "A shut shop has somewhere for an NPC to buy")
	TEST_ASSERT_NULL(floor.npc_offer(shelf), "A shut shop offers an NPC something")
	TEST_ASSERT_NULL(floor.npc_buy(buyer, shelf), "A shut shop sold to an NPC")

	// A visitor's forged click opens nothing; the owner's does, and the sign follows
	TEST_ASSERT_NOTNULL(room.set_open(buyer, TRUE), "A customer opened the shop")
	TEST_ASSERT_NULL(room.set_open(owner, TRUE), "The owner could not open the shop")
	TEST_ASSERT(findtext(hung.maptext, "OPEN"), "The sign on the wall was not redrawn when the shop opened")
	TEST_ASSERT_NULL(shelf.buy(buyer, listing, 40), "A reopened shop would not sell")

/// The opening call goes out once in its window, from an Open floor with an open shop, and never otherwise (A88)
/datum/unit_test/voidcrew_outpost_floors/shopfront/opening_call

/datum/unit_test/voidcrew_outpost_floors/shopfront/opening_call/Run()
	var/datum/outpost_floor/floor = shopfront_floor()
	if(!floor)
		return
	var/datum/outpost_upgrade/service/shop/room = floor.shop_room()
	var/mob/living/owner = shopfront_person(deck_tile(floor, 6), "floorshopowner")

	// Crew only: opening the shop tells nobody downstairs
	floor.entry_policy = "crew" // OUTPOST_FLOOR_ENTRY_CREW
	TEST_ASSERT(!floor.shop_opening_call(), "A private floor's shop was called over the speakers")
	TEST_ASSERT_EQUAL(floor.shop_call_ready_at, 0, "A call that never went out used up the window")

	floor.entry_policy = "open" // OUTPOST_FLOOR_ENTRY_OPEN
	room.is_open = FALSE
	TEST_ASSERT(!floor.shop_opening_call(), "A shut shop was called as open")
	// The owner opens it: the call goes out and the window starts
	TEST_ASSERT_NULL(room.set_open(owner, TRUE), "The owner could not open the shop")
	var/ready_at = floor.shop_call_ready_at
	TEST_ASSERT(ready_at > world.time, "Opening the shop on an Open floor sent no call")
	// Shut and open again, at once and as often as they like: no second call
	for(var/flip in 1 to 3)
		room.set_open(owner, FALSE)
		room.set_open(owner, TRUE)
	TEST_ASSERT_EQUAL(floor.shop_call_ready_at, ready_at, "Flipping the shop open and shut sent another call")
	TEST_ASSERT(!floor.shop_opening_call(), "A second call went out inside the window")
	// The window has run out
	floor.shop_call_ready_at = world.time
	TEST_ASSERT(floor.shop_opening_call(), "No call went out once the window had passed")
	TEST_ASSERT(floor.shop_call_ready_at > world.time, "A call did not start a new window")

/// An NPC is offered only what costs 60 cr or less, food and drink can be stocked, and a sale to an NPC moves one unit and one price or nothing at all
/datum/unit_test/voidcrew_outpost_floors/shopfront/npc_sale

/datum/unit_test/voidcrew_outpost_floors/shopfront/npc_sale/Run()
	var/datum/outpost_floor/floor = shopfront_floor()
	if(!floor)
		return
	var/obj/structure/overmap/dynamic/player_outpost/floor/host = floor.host
	var/obj/machinery/outpost_shop_stock/stock = floor.shop_stock()
	var/mob/living/owner = shopfront_person(deck_tile(floor, 6), "floorshopowner")
	// Food and drink go into the stock like anything else
	var/datum/outpost_shop_listing/cola = shopfront_stock(floor, owner, /obj/item/reagent_containers/cup/soda_cans/cola, 61, 2)
	var/datum/outpost_shop_listing/burger = shopfront_stock(floor, owner, /obj/item/food/burger/plain, 30, 1)
	var/datum/outpost_shop_listing/torch = shopfront_stock(floor, owner, /obj/item/flashlight, 500, 1)
	if(!cola || !burger || !torch)
		return
	var/obj/item/outpost_floor_kit/shelf/kit = allocate(/obj/item/outpost_floor_kit/shelf, get_turf(owner))
	var/obj/structure/outpost_floor_shelf/shelf = kit.deploy(owner, deck_tile(floor, 3))
	if(!shelf)
		TEST_FAIL("The shelf would not go down")
		return
	var/mob/living/customer = test_person(deck_tile(floor, 4))

	// 61 cr is over the most an NPC pays for one thing (OUTPOST_FLOOR_NPC_ITEM_MAX, 60)
	shelf.show_listing(cola)
	TEST_ASSERT_NULL(floor.npc_offer(shelf), "An NPC is offered something dearer than 60 cr")
	TEST_ASSERT_NULL(floor.npc_buy(customer, shelf), "An NPC bought something dearer than 60 cr")
	TEST_ASSERT(!(shelf in floor.npc_sale_points()), "A shelf with nothing an NPC would buy is somewhere to buy")
	cola.price = 60
	var/list/offer = floor.npc_offer(shelf)
	TEST_ASSERT_NOTNULL(offer, "An NPC is not offered a 60 cr drink")
	if(!offer)
		return
	TEST_ASSERT_EQUAL(offer["price"], 60, "The offer's price is not the listing's")
	TEST_ASSERT(offer["consumable"], "A can of cola is not something to drink")
	TEST_ASSERT(shelf in floor.npc_sale_points(), "A shelf with a 60 cr drink on it is nowhere to buy")
	// The room's register offers only what is cheap enough
	var/obj/machinery/computer/outpost_shop_register/counter = floor.shop_room().register_ref.resolve()
	for(var/attempt in 1 to 10)
		var/list/counter_offer = floor.npc_offer(counter)
		TEST_ASSERT(counter_offer && counter_offer["price"] <= 60, "The register offered an NPC something dearer than 60 cr")
		floor.shop_npc_picks = null
	shelf.show_listing(torch)
	TEST_ASSERT_NULL(floor.npc_offer(shelf), "An NPC is offered a 500 cr torch")
	shelf.show_listing(burger)
	var/list/burger_offer = floor.npc_offer(shelf)
	TEST_ASSERT(burger_offer && burger_offer["consumable"], "A burger is not something to eat")

	// The sale: the floor's NPC budget decides (floor_customers.dm). Either one unit goes for exactly its price, or nothing moves.
	shelf.show_listing(cola)
	var/treasury_before = host.treasury.account_balance
	var/units_before = cola.unit_count()
	// From across the room: an NPC is served where the goods are, like anyone
	customer.forceMove(deck_tile(floor, 9))
	TEST_ASSERT_NULL(floor.npc_buy(customer, shelf), "An NPC bought from across the room")
	customer.forceMove(deck_tile(floor, 4))
	var/obj/item/bought = floor.npc_buy(customer, shelf)
	if(bought)
		TEST_ASSERT(istype(bought, /obj/item/reagent_containers/cup/soda_cans/cola), "An NPC was handed something other than what it bought")
		TEST_ASSERT_EQUAL(cola.unit_count(), units_before - 1, "A sale to an NPC did not take one unit from the stock")
		TEST_ASSERT_EQUAL(host.treasury.account_balance, treasury_before + 60, "A sale to an NPC did not pay the treasury its price")
		TEST_ASSERT(customer.is_holding(bought) || bought.loc == get_turf(customer), "An NPC's purchase was not handed over")
		var/list/entry = stock.sales_log[length(stock.sales_log)]
		TEST_ASSERT(entry["npc"], "A sale to an NPC is not written down as one")
		TEST_ASSERT_EQUAL(entry["where"], "shelf", "A sale to an NPC at a shelf is not written down as a shelf sale") // OUTPOST_FLOOR_FITTING_SHELF
	else
		TEST_ASSERT_EQUAL(cola.unit_count(), units_before, "A sale the budget refused took stock")
		TEST_ASSERT_EQUAL(host.treasury.account_balance, treasury_before, "A sale the budget refused paid the treasury")

/// A floor sign needs a wall, shows the floor's name and its shop, counts to four, and the map's nameplate is no fitting
/datum/unit_test/voidcrew_outpost_floors/shopfront/signs

/datum/unit_test/voidcrew_outpost_floors/shopfront/signs/Run()
	var/datum/outpost_floor/floor = shopfront_floor()
	if(!floor)
		return
	var/mob/living/owner = shopfront_person(deck_tile(floor, 6), "floorshopowner")
	floor.floor_name = "The Rusty Anchor"
	var/obj/item/outpost_floor_kit/sign/kit = allocate(/obj/item/outpost_floor_kit/sign, get_turf(owner))
	// No wall, a wall across the room, a deck tile for a wall
	TEST_ASSERT_EQUAL(kit.deploy_refusal(owner, deck_tile(floor, 6)), "needs a wall!", "A sign went up with no wall")
	TEST_ASSERT_EQUAL(kit.deploy_refusal(owner, deck_tile(floor, 6), floor_tile(floor, 0, 5)), "needs a wall!", "A sign went up on a wall across the room")
	TEST_ASSERT_EQUAL(kit.deploy_refusal(owner, deck_tile(floor, 6), deck_tile(floor, 7)), "needs a wall!", "A sign went up on open deck")
	// On the west hull, from the tile beside it
	var/obj/structure/sign/outpost_floor/hung = kit.deploy(owner, floor_tile(floor, 1, 6), floor_tile(floor, 0, 6))
	TEST_ASSERT_NOTNULL(hung, "A sign would not go up on the hull")
	if(!hung)
		return
	TEST_ASSERT_EQUAL(hung.pixel_x, -32, "A sign on the west wall was not shifted onto it")
	TEST_ASSERT_EQUAL(hung.name, "The Rusty Anchor", "A sign does not carry the floor's name")
	TEST_ASSERT(findtext(hung.maptext, "The Rusty Anchor"), "A sign does not show the floor's name")
	TEST_ASSERT(findtext(hung.maptext, "OPEN"), "The sign of an open shop does not say OPEN")
	TEST_ASSERT(findtext(hung.maptext, floor.accent_colour()), "A sign's name is not in the floor's colour")
	// Its name and colour change with the floor's
	floor.floor_name = "Sable Row"
	floor.accent = "teal" // OUTPOST_FLOOR_ACCENT_TEAL
	floor.shop_refresh_signs()
	TEST_ASSERT_EQUAL(hung.name, "Sable Row", "A sign kept the floor's old name")
	TEST_ASSERT(findtext(hung.maptext, "#2fb3a8"), "A sign kept the floor's old colour") // OUTPOST_FLOOR_ACCENTS, teal
	// One to a wall face, four to a floor (OUTPOST_FLOOR_SIGNS_MAX)
	var/obj/item/outpost_floor_kit/sign/spare = allocate(/obj/item/outpost_floor_kit/sign, get_turf(owner))
	TEST_ASSERT_EQUAL(spare.deploy_refusal(owner, floor_tile(floor, 1, 6), floor_tile(floor, 0, 6)), "not here!", "Two signs went up on one wall face")
	// Side by side on one wall two names would run together: four tiles apart at least
	var/obj/item/outpost_floor_kit/sign/north_kit = allocate(/obj/item/outpost_floor_kit/sign, get_turf(owner))
	TEST_ASSERT_NOTNULL(north_kit.deploy(owner, floor_tile(floor, 6, 10), floor_tile(floor, 6, 11)), "A sign would not go up on the north hull")
	TEST_ASSERT_EQUAL(spare.deploy_refusal(owner, floor_tile(floor, 8, 10), floor_tile(floor, 8, 11)), "not here!", "Two signs went up side by side")
	TEST_ASSERT_NULL(spare.deploy_refusal(owner, floor_tile(floor, 10, 10), floor_tile(floor, 10, 11)), "A sign four tiles along the wall was refused")
	for(var/index in 1 to 2)
		var/obj/item/outpost_floor_kit/sign/next_kit = allocate(/obj/item/outpost_floor_kit/sign, get_turf(owner))
		TEST_ASSERT_NOTNULL(next_kit.deploy(owner, floor_tile(floor, 1, 6 + index), floor_tile(floor, 0, 6 + index)), "Sign [index + 2] of four would not go up")
	TEST_ASSERT_EQUAL(floor.fitting_count("sign"), 4, "Four signs up are not counted as four") // OUTPOST_FLOOR_FITTING_SIGN
	TEST_ASSERT_EQUAL(spare.deploy_refusal(owner, floor_tile(floor, 12, 6), floor_tile(floor, 13, 6)), "no more will fit!", "A fifth sign went up")

	// The shell map's nameplate shows the same, never counts and is nobody's to pack away
	var/obj/structure/sign/outpost_floor/nameplate/plate = allocate(/obj/structure/sign/outpost_floor/nameplate, floor_tile(floor, 12, 8))
	TEST_ASSERT_EQUAL(plate.name, "Sable Row", "The nameplate does not carry the floor's name")
	TEST_ASSERT_EQUAL(floor.fitting_count("sign"), 4, "The nameplate counts as one of the crew's signs")
	TEST_ASSERT(!outpost_fitting_pack(plate, owner, /obj/item/outpost_floor_kit/sign, TRUE), "The owner packed the outpost's nameplate away")
	floor.floor_name = "Brask and Daughters"
	floor.shop_refresh_signs()
	TEST_ASSERT_EQUAL(plate.name, "Brask and Daughters", "The nameplate kept the floor's old name")
	// With no shop a sign shows the name alone
	floor.host.outpost_upgrades -= "shop"
	floor.shop_refresh_signs()
	TEST_ASSERT_NULL(floor.shop_sign_status(), "A floor with no shop has a sign that says open or shut")
	TEST_ASSERT(!findtext(hung.maptext, "OPEN") && !findtext(hung.maptext, "SHUT"), "A sign says open or shut with no shop")
