/**
 * Outpost floors (voidcrew/modules/trade_floors/): tests of package P4, rooms and trading.
 * Owner: P4. Subtype /datum/unit_test/voidcrew_outpost_floors and use the helpers in
 * voidcrew_outpost_floors_helpers.dm (P0, frozen). Fork defines are included after the tests: write the literal
 * value with a comment naming the define. Pin other packages' outputs directly and never wait for an AI walk.
 *
 * Rooms are placed for real, with place_outpost_upgrade(), on a P0 test floor (a plain box of hull and deck, not the
 * shell map). The floor's owner is a ckey with nobody behind it unless a test makes them: every trade here is made
 * with none of the floor's people in the world. A visitor is someone on a crew of their own, with an ID card.
 *
 * What these lean on from other packages, so a failure can be traced:
 * - P1: ensure_home_services() must still make the host's treasury (every paid service calls it).
 * - P2: may_visit() decides the pad's lock on an Open floor (the last part of trade_pad).
 * - P12: shop_open() decides the board's "Shop" (board_and_adverts only checks that the two agree).
 */

/// P4's fixtures. It never runs.
/datum/unit_test/voidcrew_outpost_floors/rooms
	abstract_type = /datum/unit_test/voidcrew_outpost_floors/rooms
	/// People given an offline key, which stands in for a player and is cleared before they are deleted
	var/list/mob/rooms_keyed = list()
	/// Stand-ins for clients: mob -> the level whose list of players holds them
	var/list/rooms_stand_ins = list()
	/// Crews people were put on by hand: list(mind, team) each
	var/list/rooms_enlisted = list()
	/// The turfs of every room placed, so their air can settle before the ground goes
	var/list/turf/rooms_built = list()

/datum/unit_test/voidcrew_outpost_floors/rooms/Destroy()
	for(var/mob/person in rooms_stand_ins)
		SSmobs.clients_by_zlevel[rooms_stand_ins[person]] -= person
	rooms_stand_ins.Cut()
	for(var/list/entry as anything in rooms_enlisted)
		var/datum/mind/member = entry[1]
		if(!QDELETED(member))
			LAZYREMOVE(member.ship_teams, entry[2])
	rooms_enlisted.Cut()
	for(var/mob/person in rooms_keyed)
		if(!QDELETED(person))
			person.key = null
	rooms_keyed.Cut()
	rooms_built.Cut()
	return ..()

/**
 * A leased floor of `outpost` ready for rooms: `width` by `height` with its host, owned by `owner_key` (a ckey with
 * nobody behind it), loaded, and drawn in `style`. Null, and the test failed, when the ground could not be had.
 */
/datum/unit_test/voidcrew_outpost_floors/rooms/proc/rooms_floor(obj/structure/overmap/trader_outpost/outpost, number, width, height, owner_key, style = "clean") // OUTPOST_STYLE_CLEAN
	var/datum/outpost_floor/floor = test_floor(outpost, number, width, height, TRUE)
	if(!floor)
		return null
	var/obj/structure/overmap/dynamic/player_outpost/floor/host = floor.host
	host.founder_ckey = owner_key
	host.founder_name = owner_key
	host.loaded = TRUE
	host.outpost_style = style
	return floor

/**
 * Places `upgrade_type`'s room on `floor` with the bottom left of its footprint `dx`, `dy` from the floor's corner,
 * unturned (its entrance faces south). The placed room, or the refusal as text with nothing left behind.
 * One room of a kind a floor: a second of the same kind would take the first one's place in the host's list.
 */
/datum/unit_test/voidcrew_outpost_floors/rooms/proc/rooms_place(datum/outpost_floor/floor, upgrade_type, dx, dy)
	var/obj/structure/overmap/dynamic/player_outpost/floor/host = floor.host
	var/datum/outpost_upgrade/blueprint = new upgrade_type(host)
	host.outpost_upgrades[blueprint.key] = blueprint
	var/refusal = host.place_outpost_upgrade(blueprint, floor_tile(floor, dx, dy), 0, null)
	if(refusal)
		if(!QDELETED(blueprint))
			host.outpost_upgrades -= blueprint.key
			qdel(blueprint)
		return refusal
	var/list/footprint = blueprint.footprint_bounds
	rooms_built += block(footprint[1], footprint[2], footprint[5], footprint[3], footprint[4], footprint[5])
	return blueprint

/// Someone with a mind, the offline key `player_key` and an ID card in their ID slot whose account holds `balance`
/datum/unit_test/voidcrew_outpost_floors/rooms/proc/rooms_person(turf/where, player_key, balance = 0)
	var/mob/living/carbon/human/consistent/person = allocate(/mob/living/carbon/human/consistent, where)
	person.key = player_key
	rooms_keyed += person
	person.mind_initialize()
	ADD_TRAIT(person, TRAIT_PRESERVE_UI_WITHOUT_CLIENT, REF(src))
	var/datum/bank_account/account = allocate(/datum/bank_account, person.real_name, null, 1, FALSE)
	account.account_balance = balance
	// The ID slot needs a jumpsuit; without one the card is deleted instead of worn
	person.equip_to_slot_or_del(allocate(/obj/item/clothing/under/color/grey), ITEM_SLOT_ICLOTHING)
	var/obj/item/card/id/card = allocate(/obj/item/card/id)
	card.registered_account = account
	card.registered_name = person.real_name
	person.equip_to_slot_or_del(card, ITEM_SLOT_ID)
	if(person.wear_id != card)
		TEST_FAIL("[player_key] could not wear the test ID card")
	return person

/// The account on the ID card `person` wears
/datum/unit_test/voidcrew_outpost_floors/rooms/proc/rooms_account(mob/living/person)
	return person.get_idcard(TRUE)?.registered_account

/// Puts `person` on `crew` (a new crew of their own when none is given) and returns it. Undone with the test.
/datum/unit_test/voidcrew_outpost_floors/rooms/proc/rooms_enlist(mob/living/person, datum/team/voidcrew/crew)
	if(!crew)
		crew = allocate(/datum/team/voidcrew)
	LAZYADD(person.mind.ship_teams, crew)
	rooms_enlisted += list(list(person.mind, crew))
	return crew

/// The player behind `person` leaves the round: their key is freed and the body deleted
/datum/unit_test/voidcrew_outpost_floors/rooms/proc/rooms_leave(mob/living/person)
	person.key = null
	rooms_keyed -= person
	qdel(person)

/// Counts `person` as a connected player on their level, as SSmobs counts a client. Undone with the test.
/datum/unit_test/voidcrew_outpost_floors/rooms/proc/rooms_stand_in(mob/person)
	var/z = person.z
	if(!z || length(SSmobs.clients_by_zlevel) < z)
		TEST_FAIL("Fixture: [person] is on no level that counts its players")
		return
	if(person in SSmobs.clients_by_zlevel[z])
		return
	SSmobs.clients_by_zlevel[z] += person
	rooms_stand_ins[person] = z

/// What the placement map's survey draws for `tile`: one character, or null off the survey
/datum/unit_test/voidcrew_outpost_floors/rooms/proc/rooms_survey_cell(list/survey, turf/tile)
	var/column = tile.x - survey["x"]
	var/row = tile.y - survey["y"]
	if(column < 0 || row < 0 || column >= survey["width"] || row >= survey["height"])
		return null
	var/index = row * survey["width"] + column + 1
	return copytext(survey["cells"], index, index + 1)

/// Stops a freshly placed wing's own clock and its trouble, as the prison tests do: these tests drive it by hand
/datum/unit_test/voidcrew_outpost_floors/rooms/proc/rooms_quiet_wing(datum/outpost_prison/prison)
	STOP_PROCESSING(SSprocessing, prison)
	prison.pay_clock = 0
	prison.pay_owed = 0
	prison.trouble_enabled = FALSE
	prison.wildcards_enabled = FALSE
	prison.wing_events_enabled = FALSE

// ===== THE CATALOGUE =====

/// A floor's console sells the wing and the service rooms, and no cargo dock, cell block or ship bay
/datum/unit_test/voidcrew_outpost_floors/rooms/catalogue

/datum/unit_test/voidcrew_outpost_floors/rooms/catalogue/Run()
	var/obj/structure/overmap/trader_outpost/outpost = test_outpost()
	var/datum/outpost_floor/floor = rooms_floor(outpost, 1, 14, 12, "floorroomscatalogue")
	if(!floor)
		return
	var/obj/structure/overmap/dynamic/player_outpost/floor/host = floor.host
	// An outpost of the old kind beside it, to show what a floor changes and what it leaves alone
	var/obj/structure/overmap/dynamic/player_outpost/old_kind = new(null)
	made_hosts += old_kind

	for(var/sold_id in list("prison", "shop", "storage", "medical_lab", "cloning_bay", "teleporter")) // "medical_lab" is OUTPOST_MEDICAL_LAB_ID
		var/datum/outpost_upgrade/prototype = GLOB.outpost_upgrade_catalog[sold_id]
		TEST_ASSERT_NOTNULL(prototype, "The [sold_id] room is missing from the catalogue")
		TEST_ASSERT(host.offers_upgrade(prototype), "A floor does not sell the [prototype.name]")
		TEST_ASSERT(old_kind.offers_upgrade(prototype), "An outpost no longer sells the [prototype.name]")
		for(var/room_style in list("clean", "rundown")) // OUTPOST_STYLE_CLEAN, OUTPOST_STYLE_RUNDOWN
			TEST_ASSERT_NOTNULL(prototype.get_template(style = room_style), "The [prototype.name] has no [room_style] map")
	for(var/refused_id in list("cargo_dock", "prison_extension"))
		var/datum/outpost_upgrade/prototype = GLOB.outpost_upgrade_catalog[refused_id]
		TEST_ASSERT_NOTNULL(prototype, "The [refused_id] room is missing from the catalogue")
		TEST_ASSERT(!host.offers_upgrade(prototype), "A floor sells the [prototype.name]")
		TEST_ASSERT(old_kind.offers_upgrade(prototype), "An outpost no longer sells the [prototype.name]")

	// A room made for floors (floors_only, P14's three) is sold on a floor and nowhere else
	var/datum/outpost_upgrade/service/shop/for_floors = new
	for_floors.floors_only = TRUE
	TEST_ASSERT(host.offers_upgrade(for_floors), "A floor does not sell a room made for floors")
	TEST_ASSERT(!old_kind.offers_upgrade(for_floors), "An outpost sells a room made for floors")
	qdel(for_floors)

	// At the console: the owner, in person, with money in the treasury
	var/mob/living/carbon/human/owner = rooms_person(deck_tile(floor), "floorroomscatalogue")
	host.ensure_home_services()
	TEST_ASSERT_NOTNULL(host.treasury, "A floor's host has no treasury")
	host.treasury.adjust_money(50000, "Test float")
	TEST_ASSERT_EQUAL(host.upgrade_purchase_denial(owner, "cargo_dock"), "Not sold here.", "The cargo dock can be bought for a floor")
	TEST_ASSERT_EQUAL(host.upgrade_purchase_denial(owner, "prison_extension"), "Not sold here.", "A cell block can be bought for a floor")
	TEST_ASSERT_NOTNULL(host.buy_outpost_upgrade(owner, "cargo_dock"), "The cargo dock was bought for a floor")
	TEST_ASSERT_EQUAL(host.treasury.account_balance, 50000, "A refused room cost the treasury")
	TEST_ASSERT_NULL(host.upgrade_purchase_denial(owner, "shop"), "The owner cannot buy a Shop for a floor")
	TEST_ASSERT_NULL(host.buy_outpost_upgrade(owner, "shop"), "The owner could not buy a Shop for a floor")
	TEST_ASSERT_EQUAL(host.treasury.account_balance, 48000, "The Shop did not cost the treasury 2,000 cr") // OUTPOST_SHOP_COST
	TEST_ASSERT_NOTNULL(host.pending_upgrade("shop"), "Buying a Shop left the floor no blueprint")

	// The ship bay is not in the catalogue: it is refused paid for, and refused granted by an admin
	TEST_ASSERT_EQUAL(host.ship_bay_install_denial(owner), "Not sold here.", "A ship bay can be installed on a floor")
	TEST_ASSERT_EQUAL(host.install_ship_bay(owner), "Not sold here.", "A ship bay was installed on a floor")
	TEST_ASSERT_EQUAL(host.enable_ship_bays(), "Not sold here.", "A ship bay was granted to a floor")
	TEST_ASSERT(!host.ship_bay_installed && !length(host.bay_berths), "A floor has a ship bay")
	TEST_ASSERT_EQUAL(host.treasury.account_balance, 48000, "A refused ship bay cost the treasury")

// ===== EVERY ROOM, BOTH STYLES =====

/**
 * The wing and the five service rooms all go down on one floor of the real size, in `style`, each one working where
 * it lands (contract_problems(), as the style test checks rooms on an outpost), each one finding its floor (A60),
 * none of them on the hull or the landing (A5), and the deck still under them (A4).
 */
/datum/unit_test/voidcrew_outpost_floors/rooms/place_clean
	/// The style the rooms are drawn in
	var/style = "clean" // OUTPOST_STYLE_CLEAN

/datum/unit_test/voidcrew_outpost_floors/rooms/place_clean/rundown
	style = "rundown" // OUTPOST_STYLE_RUNDOWN

/datum/unit_test/voidcrew_outpost_floors/rooms/place_clean/Run()
	var/obj/structure/overmap/trader_outpost/outpost = test_outpost()
	// OUTPOST_FLOOR_WIDTH by OUTPOST_FLOOR_HEIGHT
	var/datum/outpost_floor/floor = rooms_floor(outpost, 1, 46, 40, "floorroomsplace[style]", style)
	if(!floor)
		return
	var/obj/structure/overmap/dynamic/player_outpost/floor/host = floor.host
	var/list/bounds = floor.bounds
	// The real landing, OUTPOST_FLOOR_LANDING_WIDTH by OUTPOST_FLOOR_LANDING_HEIGHT at the middle of the south wall
	var/middle = round((bounds[1] + bounds[3]) / 2)
	floor.landing_bounds = list(middle - 4, bounds[2] + 1, middle + 4, bounds[2] + 5, bounds[5])
	var/landing_dx = middle - 4 - bounds[1]
	// A goods lift beside it, east of the landing against the south hull
	floor.goods_turfs = list(floor_tile(floor, 30, 1), floor_tile(floor, 31, 1))

	// The console's map before anything is built: the whole floor, the deck open, hull and landing kept clear
	var/list/survey = host.build_upgrade_survey()
	TEST_ASSERT_NOTNULL(survey, "The placement map has no survey of a floor, so no room could be placed")
	TEST_ASSERT_EQUAL(survey["width"], 46, "The survey is not as wide as the floor")
	TEST_ASSERT_EQUAL(survey["height"], 40, "The survey is not as tall as the floor")
	TEST_ASSERT_EQUAL(length(survey["cells"]), 46 * 40, "The survey does not draw one cell a tile")
	TEST_ASSERT_EQUAL(survey["near"], repeat_string(46 * 40, "1"), "Part of a floor is too far from the outpost to build on")
	TEST_ASSERT_EQUAL(rooms_survey_cell(survey, floor_tile(floor, 0, 0)), "x", "The survey draws the hull as ground a room may cover") // UPGRADE_CELL_RESERVED
	TEST_ASSERT_EQUAL(rooms_survey_cell(survey, floor_tile(floor, landing_dx, 1)), "x", "The survey draws the landing as ground a room may cover (A5)")
	TEST_ASSERT_EQUAL(rooms_survey_cell(survey, floor_tile(floor, 1, 38)), "f", "The survey does not draw the deck as open floor") // UPGRADE_CELL_FLOOR
	// A room is never moved, so the row of deck beside the landing and the goods lift is kept clear of rooms too
	TEST_ASSERT_EQUAL(rooms_survey_cell(survey, floor_tile(floor, landing_dx, 6)), "x", "The survey lets a room stand against the landing")
	TEST_ASSERT_EQUAL(rooms_survey_cell(survey, floor_tile(floor, landing_dx, 7)), "f", "The survey keeps more than one row clear beside the landing")
	TEST_ASSERT_EQUAL(rooms_survey_cell(survey, floor_tile(floor, 30, 1)), "x", "The survey draws the goods lift as ground a room may cover (A5)")
	TEST_ASSERT_EQUAL(rooms_survey_cell(survey, floor_tile(floor, 32, 2)), "x", "The survey lets a room stand against the goods lift")
	TEST_ASSERT_EQUAL(rooms_survey_cell(survey, floor_tile(floor, 33, 3)), "f", "The survey keeps more than one row clear beside the goods lift")

	// Nothing goes over the hull or the landing, or against the landing where it would wall up the front door
	var/hull_try = rooms_place(floor, /datum/outpost_upgrade/service/storage, 0, 0)
	TEST_ASSERT_EQUAL(hull_try, "Position obstructed.", "A room was placed over the hull: [hull_try]")
	var/landing_try = rooms_place(floor, /datum/outpost_upgrade/service/storage, landing_dx - 2, 1)
	TEST_ASSERT_EQUAL(landing_try, "Position obstructed.", "A room was placed over the landing (A5): [landing_try]")
	var/doorstep_try = rooms_place(floor, /datum/outpost_upgrade/service/storage, landing_dx, 6)
	TEST_ASSERT_EQUAL(doorstep_try, "Position obstructed.", "A room was placed against the landing, where it walls up the front door: [doorstep_try]")

	// Along the north hull, then a second row under the first with a clear row between for the doors
	var/list/room_ids = list("prison", "cloning_bay", "storage", "shop", "medical_lab", "teleporter") // "medical_lab" is OUTPOST_MEDICAL_LAB_ID
	var/list/datum/outpost_upgrade/placed = list()
	var/next_dx = 1
	var/row_top = 38
	var/row_bottom = row_top
	for(var/room_id in room_ids)
		var/datum/outpost_upgrade/prototype = GLOB.outpost_upgrade_catalog[room_id]
		var/datum/map_template/template = prototype?.get_template(style = style)
		if(!template)
			TEST_FAIL("The [style] [room_id] has no map")
			continue
		if(next_dx + template.width - 1 > 44)
			next_dx = 1
			row_top = row_bottom - 2
			row_bottom = row_top
		var/dy = row_top - template.height + 1
		var/result = rooms_place(floor, prototype.type, next_dx, dy)
		if(!istype(result, /datum/outpost_upgrade))
			TEST_FAIL("The [style] [prototype.name] could not be placed on a floor at [next_dx],[dy]: [result]")
			continue
		var/datum/outpost_upgrade/built = result
		placed += built
		row_bottom = min(row_bottom, dy)
		next_dx += template.width
		var/datum/outpost_upgrade/prison/built_wing = built
		if(istype(built_wing) && built_wing.prison)
			rooms_quiet_wing(built_wing.prison)
	TEST_ASSERT_EQUAL(length(placed), length(room_ids), "Not every room fits one floor in the [style] style")

	for(var/datum/outpost_upgrade/room as anything in placed)
		TEST_ASSERT(room.installed, "The [style] [room.name] is not installed")
		TEST_ASSERT(istype(room.installed_area, room.area_type), "The [style] [room.name] has no area of its own")
		for(var/problem in room.contract_problems())
			TEST_FAIL("The [style] [room.name] on a floor: [problem]")
		var/machines = 0
		for(var/turf/tile as anything in room.room_lookup())
			if(get_outpost_floor_for_turf(tile) != floor || !host.contains_service_turf(tile))
				TEST_FAIL("The [style] [room.name] runs off its floor at [tile.x],[tile.y]")
				break
			if(!floor.is_buildable(tile))
				TEST_FAIL("The [style] [room.name] covers the hull or the landing at [tile.x],[tile.y] (A5)")
				break
			for(var/obj/machinery/machine in tile)
				machines++
				if(get_outpost_from_atom(machine) != host)
					TEST_FAIL("The [machine.name] in the [style] [room.name] does not find its floor (A60)")
		TEST_ASSERT(machines > 0, "The [style] [room.name] has no machines in it")

	// What each room's own code needs is there
	var/datum/outpost_upgrade/service/shop/shop = host.service_upgrade("shop")
	TEST_ASSERT(shop?.get_stock() && shop.register_ref?.resolve(), "The [style] shop on a floor linked no stock unit or no register")
	var/datum/outpost_upgrade/service/cloning_bay/bay = host.service_upgrade("cloning_bay")
	TEST_ASSERT_EQUAL(length(bay?.room_vats()), 8, "The [style] cloning bay on a floor does not have its eight vats") // OUTPOST_CLONING_BAY_VATS
	var/datum/outpost_upgrade/service/storage/lockers = host.service_upgrade("storage")
	TEST_ASSERT_EQUAL(length(lockers?.live_lockers()), 13, "The [style] storage on a floor does not have its thirteen lockers") // OUTPOST_STORAGE_LOCKERS
	var/datum/outpost_upgrade/service/teleporter/teleporter = host.service_upgrade("teleporter")
	var/obj/machinery/outpost_network_pad/pad = teleporter?.pad_ref?.resolve()
	TEST_ASSERT_NOTNULL(pad, "The [style] teleporter on a floor has no pad")
	TEST_ASSERT_EQUAL(pad.network_host(), host, "A floor's pad is not on the network")
	var/datum/outpost_upgrade/prison/wing = host.outpost_upgrades["prison"]
	TEST_ASSERT_NOTNULL(wing?.prison, "The [style] wing on a floor runs no prison")
	TEST_ASSERT_EQUAL(length(wing.prison.cells), 4, "The [style] wing on a floor does not have four cells")
	TEST_ASSERT_EQUAL(wing.prison.outpost, host, "The [style] wing on a floor is not the floor's")

	// The map after: what is built is no longer open
	survey = host.build_upgrade_survey()
	TEST_ASSERT_NOTNULL(survey, "The placement map lost its survey once rooms were built")
	for(var/datum/outpost_upgrade/room as anything in placed)
		var/list/footprint = room.footprint_bounds
		TEST_ASSERT_EQUAL(rooms_survey_cell(survey, locate(footprint[1], footprint[2], footprint[5])), "x", "The survey draws the [room.name] as ground another room may cover")

	// The deck is still under a room (A4): stripped to plating by the drone and scraped, a room tile is deck, never space
	var/turf/sample
	for(var/turf/open/indestructible/tile in lockers.room_lookup())
		if(!length(tile.contents))
			sample = tile
			break
	if(sample)
		var/sample_x = sample.x
		var/sample_y = sample.y
		var/sample_z = sample.z
		TEST_ASSERT(outpost_strip_service_turf(sample), "A room's floor tile could not be stripped to plating")
		var/reached_deck = FALSE
		for(var/scrape in 1 to 6)
			var/turf/now = locate(sample_x, sample_y, sample_z)
			if(isspaceturf(now))
				break
			if(istype(now, /turf/open/floor/plating/outpost_deck))
				reached_deck = TRUE
				break
			now.ScrapeAway()
		TEST_ASSERT(reached_deck, "Under a room's floor there is [locate(sample_x, sample_y, sample_z)], not the deck (A4)")
	settle_room_air(rooms_built)

// ===== TRADING: A VISITOR WITH A CARD, AND NOBODY HOME =====

/// The shop sells to a visitor from their card into the floor's treasury, at the price they were shown and no other
/datum/unit_test/voidcrew_outpost_floors/rooms/trade_shop

/datum/unit_test/voidcrew_outpost_floors/rooms/trade_shop/Run()
	var/obj/structure/overmap/trader_outpost/outpost = test_outpost()
	var/datum/outpost_floor/floor = rooms_floor(outpost, 1, 20, 20, "floorroomsshopowner")
	if(!floor)
		return
	var/obj/structure/overmap/dynamic/player_outpost/floor/host = floor.host
	var/datum/outpost_upgrade/service/shop/shop = rooms_place(floor, /datum/outpost_upgrade/service/shop, 2, 5)
	TEST_ASSERT(istype(shop), "The Shop was not placed on a floor: [shop]")
	var/obj/machinery/outpost_shop_stock/stock = shop.get_stock()
	var/obj/machinery/computer/outpost_shop_register/register = shop.register_ref?.resolve()
	TEST_ASSERT(stock && register, "A floor's shop has no stock unit or no register")
	TEST_ASSERT_EQUAL(stock.get_outpost(), host, "A floor's stock unit does not find its floor (A60)")
	TEST_ASSERT_EQUAL(register.get_shop(), shop, "A floor's register does not find its shop (A60)")
	TEST_ASSERT_NULL(stock.closed_reason(), "A floor's shop is shut: [stock.closed_reason()]")

	// The owner stocks a wrench at 120 cr and leaves the round
	var/mob/living/carbon/human/owner = rooms_person(floor_tile(floor, 1, 3), "floorroomsshopowner")
	var/obj/item/wrench/goods = allocate(/obj/item/wrench, get_turf(owner))
	TEST_ASSERT_NULL(stock.stock_item(goods, owner), "The owner could not stock the floor's shop")
	var/datum/outpost_shop_listing/listing = stock.listing_of[goods]
	TEST_ASSERT_NOTNULL(listing, "The stocked wrench has no listing")
	TEST_ASSERT_NULL(stock.owner_action(owner, "set_price", list("ids" = list(listing.id), "price" = 120)), "The owner could not price the wrench")
	rooms_leave(owner)

	var/mob/living/carbon/human/visitor = rooms_person(get_step(register, register.dir), "floorroomsshopvisitor", 1000)
	rooms_enlist(visitor)
	var/datum/bank_account/card = rooms_account(visitor)
	TEST_ASSERT(register.Adjacent(visitor), "Fixture: the customer is not standing at the register")
	TEST_ASSERT(!host.is_outpost_member(visitor), "Fixture: the visitor is one of the floor's people")
	host.ensure_home_services()
	var/takings = host.treasury.account_balance
	TEST_ASSERT_EQUAL(stock.sell(listing, 1, 100, visitor, register), "Price changed to 120 cr.", "A sale at a price that had moved was not refused")
	// Shut, it sells to nobody
	shop.is_open = FALSE
	TEST_ASSERT_EQUAL(stock.sell(listing, 1, 120, visitor, register), "Closed.", "A shut shop sold something")
	shop.is_open = TRUE
	TEST_ASSERT_EQUAL(card.account_balance, 1000, "A refused sale charged the visitor")
	TEST_ASSERT_EQUAL(goods.loc, stock, "A refused sale moved the goods")
	TEST_ASSERT_NULL(stock.sell(listing, 1, 120, visitor, register), "A visitor could not buy at a floor's shop with nobody home")
	TEST_ASSERT_EQUAL(card.account_balance, 880, "The visitor's card was not charged 120 cr")
	TEST_ASSERT_EQUAL(host.treasury.account_balance, takings + 120, "The sale did not reach the floor's treasury") // OUTPOST_SHOP_SALE_FEE_PCT is 0
	TEST_ASSERT(goods.loc == visitor || get_turf(goods) == get_turf(visitor), "The goods did not reach the buyer")
	var/list/line = length(host.service_ledger) ? host.service_ledger[length(host.service_ledger)] : null
	TEST_ASSERT_EQUAL(line?["amount"], 120, "The sale is not in the floor's ledger")
	settle_room_air(rooms_built)

/// The clinic's machines are never free to a stranger (A60); a pass is paid from the card at the price shown
/datum/unit_test/voidcrew_outpost_floors/rooms/trade_clinic

/datum/unit_test/voidcrew_outpost_floors/rooms/trade_clinic/Run()
	var/obj/structure/overmap/trader_outpost/outpost = test_outpost()
	var/datum/outpost_floor/floor = rooms_floor(outpost, 1, 20, 20, "floorroomslabowner")
	if(!floor)
		return
	var/obj/structure/overmap/dynamic/player_outpost/floor/host = floor.host
	var/datum/outpost_upgrade/service/medical_lab/lab = rooms_place(floor, /datum/outpost_upgrade/service/medical_lab, 2, 5)
	TEST_ASSERT(istype(lab), "The Medical Lab was not placed on a floor: [lab]")
	var/obj/machinery/sleeper/machine
	for(var/turf/tile as anything in lab.room_lookup())
		machine = locate(/obj/machinery/sleeper) in tile
		if(machine)
			break
	TEST_ASSERT_NOTNULL(machine, "A floor's lab has no sleeper")
	TEST_ASSERT_EQUAL(outpost_medical_lab_at(machine), lab, "A lab machine on a floor does not find its lab (A60)")

	var/mob/living/carbon/human/visitor = rooms_person(floor_tile(floor, 1, 3), "floorroomslabvisitor", 1000)
	rooms_enlist(visitor)
	visitor.apply_damage(15, BRUTE)
	var/datum/bank_account/card = rooms_account(visitor)
	TEST_ASSERT(!outpost_lab_access(machine, visitor), "A stranger uses a floor's lab free (A60)")
	TEST_ASSERT(!outpost_lab_staff(machine, visitor), "A stranger runs a floor's lab machines (A60)")
	host.ensure_home_services()
	var/takings = host.treasury.account_balance
	TEST_ASSERT_EQUAL(lab.sell_pass(visitor, list(visitor), 250), "Price changed to 300 cr.", "A pass at a price that had moved was not refused") // OUTPOST_MEDLAB_PASS_DEFAULT
	TEST_ASSERT_EQUAL(card.account_balance, 1000, "A refused pass charged the visitor")
	TEST_ASSERT(!outpost_lab_access(machine, visitor), "A refused pass opened the lab")
	TEST_ASSERT_NULL(lab.sell_pass(visitor, list(visitor), 300), "A visitor could not buy a lab pass on a floor with nobody home")
	TEST_ASSERT_EQUAL(card.account_balance, 700, "The visitor's card was not charged 300 cr")
	TEST_ASSERT_EQUAL(host.treasury.account_balance, takings + 300, "The pass did not reach the floor's treasury")
	TEST_ASSERT(outpost_lab_access(machine, visitor), "A paid pass does not open the lab")
	TEST_ASSERT(!outpost_lab_staff(machine, visitor), "A pass lets a visitor run the lab's machines")

	// One of the floor's people uses it free
	var/mob/living/carbon/human/resident = rooms_person(floor_tile(floor, 1, 3), "floorroomslabresident")
	host.residents += resident.mind
	TEST_ASSERT(outpost_lab_access(machine, resident), "One of the floor's people needs a pass for their own lab")
	TEST_ASSERT_EQUAL(host.service_price_for(resident, 300), 0, "One of the floor's people is charged for their own lab")
	settle_room_air(rooms_built)

/// A clone imprint is paid from the card at the price shown, and a vat on a floor is the floor's
/datum/unit_test/voidcrew_outpost_floors/rooms/trade_cloning

/datum/unit_test/voidcrew_outpost_floors/rooms/trade_cloning/Run()
	var/obj/structure/overmap/trader_outpost/outpost = test_outpost()
	var/datum/outpost_floor/floor = rooms_floor(outpost, 1, 20, 20, "floorroomscloneowner")
	if(!floor)
		return
	var/obj/structure/overmap/dynamic/player_outpost/floor/host = floor.host
	var/datum/outpost_upgrade/service/cloning_bay/bay = rooms_place(floor, /datum/outpost_upgrade/service/cloning_bay, 2, 5)
	TEST_ASSERT(istype(bay), "The Cloning Bay was not placed on a floor: [bay]")
	var/list/vats = bay.room_vats()
	TEST_ASSERT(length(vats), "A floor's cloning bay has no vats")
	var/obj/machinery/cloning_vat/outpost/vat = vats[1]
	TEST_ASSERT_EQUAL(vat.host_outpost(), host, "A vat on a floor does not find its floor (A60)")
	TEST_ASSERT(vat.is_single_use(), "A vat on a floor is a free vat that regrows (A60)")

	var/mob/living/carbon/human/visitor = rooms_person(floor_tile(floor, 1, 3), "floorroomsclonevisitor", 1000)
	rooms_enlist(visitor)
	var/datum/bank_account/card = rooms_account(visitor)
	host.ensure_home_services()
	var/takings = host.treasury.account_balance
	TEST_ASSERT_EQUAL(vat.paid_imprint(visitor, host, 500), "Price changed to 600 cr.", "An imprint at a price that had moved was not refused") // OUTPOST_CLONE_IMPRINT_DEFAULT
	TEST_ASSERT_EQUAL(card.account_balance, 1000, "A refused imprint charged the visitor")
	TEST_ASSERT_NULL(vat.imprint_mind_ref, "A refused imprint filled the vat")
	TEST_ASSERT_NULL(vat.paid_imprint(visitor, host, 600), "A visitor could not imprint on a floor with nobody home")
	TEST_ASSERT_EQUAL(card.account_balance, 400, "The visitor's card was not charged 600 cr")
	TEST_ASSERT_EQUAL(host.treasury.account_balance, takings + 600, "The imprint did not reach the floor's treasury")
	TEST_ASSERT_EQUAL(vat.paid_amount, 600, "The vat did not record the payment")
	TEST_ASSERT_EQUAL(vat.imprint_mind_ref?.resolve(), visitor.mind, "The vat does not hold the visitor's imprint")
	settle_room_air(rooms_built)

/// A locker is rented from the card at the price shown, on a floor that is in service
/datum/unit_test/voidcrew_outpost_floors/rooms/trade_lockers

/datum/unit_test/voidcrew_outpost_floors/rooms/trade_lockers/Run()
	var/obj/structure/overmap/trader_outpost/outpost = test_outpost()
	var/datum/outpost_floor/floor = rooms_floor(outpost, 1, 20, 20, "floorroomslockerowner")
	if(!floor)
		return
	var/obj/structure/overmap/dynamic/player_outpost/floor/host = floor.host
	var/datum/outpost_upgrade/service/storage/room = rooms_place(floor, /datum/outpost_upgrade/service/storage, 2, 5)
	TEST_ASSERT(istype(room), "Safe Storage was not placed on a floor: [room]")
	var/list/lockers = room.live_lockers()
	TEST_ASSERT(length(lockers), "A floor's storage has no lockers")
	var/obj/structure/closet/secure_closet/outpost_storage/locker = lockers[1]
	TEST_ASSERT_EQUAL(locker.get_home(), host, "A locker on a floor does not find its floor (A60)")
	var/turf/stand = storage_test_stand(locker)
	TEST_ASSERT_NOTNULL(stand, "Nobody can stand at a floor's locker")

	var/mob/living/carbon/human/visitor = rooms_person(stand, "floorroomslockervisitor", 1000)
	rooms_enlist(visitor)
	// The lock is the player's: a body with nobody connected rents nothing
	visitor.mock_client = new()
	var/datum/bank_account/card = rooms_account(visitor)
	host.ensure_home_services()
	var/takings = host.treasury.account_balance
	// Lockers need the floor in service (A61: the shell's supply console, bank terminal and cryopod make it so)
	host.loaded = FALSE
	TEST_ASSERT_EQUAL(locker.complete_rental(visitor, 200), "Out of service.", "A locker was rented on a floor that is not in service")
	host.loaded = TRUE
	TEST_ASSERT_EQUAL(locker.complete_rental(visitor, 150), "Price changed to 200 cr.", "A rental at a price that had moved was not refused") // OUTPOST_STORAGE_RENT_DEFAULT
	TEST_ASSERT_EQUAL(card.account_balance, 1000, "A refused rental charged the visitor")
	TEST_ASSERT_NULL(locker.renter_ckey, "A refused rental took the locker")
	TEST_ASSERT_NULL(locker.complete_rental(visitor, 200), "A visitor could not rent a locker on a floor with nobody home")
	TEST_ASSERT_EQUAL(card.account_balance, 800, "The visitor's card was not charged 200 cr")
	TEST_ASSERT_EQUAL(host.treasury.account_balance, takings + 200, "The rent did not reach the floor's treasury")
	TEST_ASSERT_EQUAL(locker.renter_ckey, "floorroomslockervisitor", "The locker is not the visitor's")
	TEST_ASSERT(locker.locked, "A rented locker is not locked")
	settle_room_air(rooms_built)

/**
 * The pad follows the floor's setting (A54): a stranger is refused at a Crew only floor and one of its people is
 * not, and on an Open floor a stranger pays the fare shown from their card, before they go (A62).
 */
/datum/unit_test/voidcrew_outpost_floors/rooms/trade_pad

/datum/unit_test/voidcrew_outpost_floors/rooms/trade_pad/Run()
	var/obj/structure/overmap/trader_outpost/outpost = test_outpost()
	// Two floors of one outpost with a Teleporter room each: a trip between them is driven by hand
	var/datum/outpost_floor/from_floor = rooms_floor(outpost, 1, 16, 16, "floorroomspadfrom")
	var/datum/outpost_floor/to_floor = rooms_floor(outpost, 2, 16, 16, "floorroomspadto")
	if(!from_floor || !to_floor)
		return
	var/obj/structure/overmap/dynamic/player_outpost/floor/host = to_floor.host
	var/datum/outpost_upgrade/service/teleporter/from_room = rooms_place(from_floor, /datum/outpost_upgrade/service/teleporter, 2, 5)
	TEST_ASSERT(istype(from_room), "The first Teleporter was not placed on a floor: [from_room]")
	var/datum/outpost_upgrade/service/teleporter/to_room = rooms_place(to_floor, /datum/outpost_upgrade/service/teleporter, 2, 5)
	TEST_ASSERT(istype(to_room), "The second Teleporter was not placed on a floor: [to_room]")
	var/obj/machinery/outpost_network_pad/from_pad = from_room.pad_ref?.resolve()
	var/obj/machinery/outpost_network_pad/to_pad = to_room.pad_ref?.resolve()
	TEST_ASSERT(from_pad && to_pad, "A floor's Teleporter has no pad")
	TEST_ASSERT_EQUAL(from_pad.network_host(), from_floor.host, "The first floor's pad is not on the network")
	TEST_ASSERT_EQUAL(to_pad.network_host(), host, "The second floor's pad is not on the network")
	TEST_ASSERT(!host.pad_follows_dock_modes(), "A floor's pad follows docking modes a floor does not have")
	TEST_ASSERT_EQUAL(host.network_zone_turf(), get_turf(outpost), "A floor's pad does not read its outpost's place on the chart")
	var/turf/leaving = get_turf(from_pad)
	host.ensure_home_services()
	var/takings = host.treasury.account_balance

	// Crew only: a stranger is refused, at the list and at the pad
	var/mob/living/carbon/human/visitor = rooms_person(leaving, "floorroomspadvisitor", 1000)
	rooms_enlist(visitor)
	var/datum/bank_account/card = rooms_account(visitor)
	TEST_ASSERT_EQUAL(to_floor.entry_policy, "crew", "Fixture: a new floor is not Crew only") // OUTPOST_FLOOR_ENTRY_CREW
	TEST_ASSERT(!host.pad_admits(visitor), "A Crew only floor's pad admits a stranger (A54)")
	TEST_ASSERT_EQUAL(to_pad.arrival_denial(visitor, from_pad), "Private", "A stranger may arrive on a Crew only floor's pad (A54)")
	TEST_ASSERT_EQUAL(from_pad.start_trip(visitor, to_pad, 200), "Private", "A stranger's trip to a Crew only floor started (A54)") // OUTPOST_TELEPORT_ARRIVAL_DEFAULT
	TEST_ASSERT(!from_pad.is_charging(), "A refused trip left the pad charging")

	// One of the floor's own people goes home by it, free, whatever the setting
	var/mob/living/carbon/human/resident = rooms_person(leaving, "floorroomspadresident")
	host.residents += resident.mind
	TEST_ASSERT_NULL(to_pad.arrival_denial(resident, from_pad), "One of the floor's people may not arrive on their own pad")
	TEST_ASSERT_EQUAL(to_pad.arrival_fee(resident), 0, "One of the floor's people is charged a fare home")
	TEST_ASSERT_NULL(from_pad.start_trip(resident, to_pad, 0), "One of the floor's people could not start a trip home")
	TEST_ASSERT_NULL(from_pad.finish_trip(), "One of the floor's people did not get home by the pad")
	TEST_ASSERT_EQUAL(get_turf(resident), to_pad.arrival_turf, "One of the floor's people did not arrive on the pad")
	TEST_ASSERT(to_floor.contains_turf(get_turf(resident)), "The pad's arrival is not on the floor")
	resident.forceMove(floor_tile(to_floor, 1, 3))

	// Open: the lift's own rule (may_visit(), floor_lift.dm) lets a stranger in, and they pay the fare they were shown
	to_floor.entry_policy = "open" // OUTPOST_FLOOR_ENTRY_OPEN
	TEST_ASSERT_EQUAL(host.pad_admits(visitor), !!to_floor.may_visit(visitor), "A floor's pad and its lift disagree about a stranger")
	TEST_ASSERT_NULL(to_pad.arrival_denial(visitor, from_pad), "A stranger may not arrive on an Open floor's pad")
	TEST_ASSERT_EQUAL(to_pad.arrival_fee(visitor), 200, "A stranger's fare to a floor is not 200 cr")
	TEST_ASSERT_EQUAL(from_pad.start_trip(visitor, to_pad, 150), "Price changed to 200 cr.", "A trip at a fare that had moved was not refused")
	// An empty card is turned away before the trip, so there is never a free ride to chase (A62)
	var/mob/living/carbon/human/broke = rooms_person(leaving, "floorroomspadbroke", 0)
	rooms_enlist(broke)
	TEST_ASSERT_EQUAL(from_pad.start_trip(broke, to_pad, 200), "Insufficient credits.", "A trip started on an empty card (A62)")
	TEST_ASSERT_EQUAL(get_turf(broke), leaving, "A traveller with an empty card left the pad (A62)")
	// The card is emptied while the pad charges: the trip is refused at the end, and nobody moves
	TEST_ASSERT_NULL(from_pad.start_trip(visitor, to_pad, 200), "A stranger's trip to an Open floor did not start")
	card.account_balance = 0
	TEST_ASSERT_EQUAL(from_pad.finish_trip(), "Insufficient credits.", "A trip finished on a card emptied while it charged (A62)")
	TEST_ASSERT_EQUAL(get_turf(visitor), leaving, "A traveller whose card was emptied arrived all the same (A62)")
	TEST_ASSERT_EQUAL(host.treasury.account_balance, takings, "A refused trip paid the floor")
	card.account_balance = 1000
	GLOB.outpost_network_ready_at -= "floorroomspadvisitor"
	TEST_ASSERT_NULL(from_pad.start_trip(visitor, to_pad, 200), "A stranger's trip to an Open floor did not start again")
	TEST_ASSERT_NULL(from_pad.finish_trip(), "A stranger's trip to an Open floor did not finish")
	TEST_ASSERT_EQUAL(get_turf(visitor), to_pad.arrival_turf, "The stranger did not arrive on the floor's pad")
	TEST_ASSERT_EQUAL(card.account_balance, 800, "The fare was not taken from the card exactly once")
	TEST_ASSERT_EQUAL(host.treasury.account_balance, takings + 200, "The fare did not reach the floor's treasury")
	TEST_ASSERT_EQUAL(to_room.trips_in, 2, "The arrivals were not counted")

	// Given up, the floor's pad takes nobody
	host.founder_ckey = null
	TEST_ASSERT_EQUAL(to_pad.arrival_denial(broke, from_pad), "Closed", "A floor nobody holds takes arrivals by pad")
	for(var/player_key in list("floorroomspadvisitor", "floorroomspadresident", "floorroomspadbroke"))
		GLOB.outpost_network_ready_at -= player_key
	settle_room_air(rooms_built)

// ===== THE WING =====

/**
 * A wing on a floor takes prisoners in where it stands, pays the floor's treasury and releases. Home is the floor,
 * not the level (A1): who counts as at the wing, and whose presence wakes it, is whoever is on that floor.
 */
/datum/unit_test/voidcrew_outpost_floors/rooms/wing

/datum/unit_test/voidcrew_outpost_floors/rooms/wing/Run()
	var/obj/structure/overmap/trader_outpost/outpost = test_outpost()
	var/datum/outpost_floor/floor = rooms_floor(outpost, 1, 26, 26, "floorroomswingowner")
	var/datum/outpost_floor/next_floor = test_floor(outpost, 2)
	var/datum/turf_reservation/elsewhere = test_ground(6, 6)
	if(!floor || !next_floor || !elsewhere)
		return
	var/obj/structure/overmap/dynamic/player_outpost/floor/host = floor.host
	var/datum/outpost_upgrade/prison/wing = rooms_place(floor, /datum/outpost_upgrade/prison, 2, 5)
	TEST_ASSERT(istype(wing), "The Prison Wing was not placed on a floor: [wing]")
	var/datum/outpost_prison/prison = wing.prison
	TEST_ASSERT_NOTNULL(prison, "A wing on a floor runs no prison")
	rooms_quiet_wing(prison)
	TEST_ASSERT_EQUAL(prison.outpost, host, "A floor's wing is not the floor's")
	TEST_ASSERT_EQUAL(length(prison.cells), 4, "A floor's wing does not have four cells")

	// Arrivals come in where the wing stands: no pad, no ferry
	var/mob/living/carbon/human/npc/outpost_prisoner/arrival = prison.admit_next(TRUE)
	TEST_ASSERT_NOTNULL(arrival, "No prisoner could be brought to a floor's wing")
	TEST_ASSERT(arrival in prison.prisoners, "An arrival is not on the wing's roster")
	TEST_ASSERT(wing.contains_turf(get_turf(arrival)) && floor.contains_turf(get_turf(arrival)), "A prisoner arrived somewhere other than the floor's wing")
	TEST_ASSERT_NOTNULL(arrival.cell, "An arrival has no cell")

	// The stipend and the release bonus are the floor's
	host.ensure_home_services()
	var/datum/bank_account/treasury = host.treasury
	TEST_ASSERT_NOTNULL(treasury, "A floor's host has no treasury")
	var/before = treasury.account_balance
	prison.pay_owed = 36.4
	TEST_ASSERT_EQUAL(prison.deposit_pay(), 36, "The wing's stipend was not deposited")
	TEST_ASSERT_EQUAL(treasury.account_balance, before + 36, "The stipend did not reach the floor's treasury")
	var/datum/outpost_prison_cell/free_cell
	for(var/datum/outpost_prison_cell/cell as anything in prison.cells)
		if(!cell.occupant && cell.arrival_turf())
			free_cell = cell
			break
	TEST_ASSERT_NOTNULL(free_cell, "The wing has no second cell to book a prisoner into")
	var/mob/living/carbon/human/npc/outpost_prisoner/served = new(free_cell.arrival_turf())
	prison.admit(served, free_cell)
	ADD_TRAIT(served, TRAIT_IMMOBILIZED, TRAIT_SOURCE_UNIT_TESTS)
	served.sentence_left = 3600
	served.served_seconds = 600
	served.kept_seconds = 600
	before = treasury.account_balance
	TEST_ASSERT_EQUAL(prison.release(served), 200, "A sentence served in full care did not pay the release bonus") // OUTPOST_PRISON_RELEASE_BONUS
	TEST_ASSERT_EQUAL(treasury.account_balance, before + 200, "The release bonus did not reach the floor's treasury")

	// Home is the floor: two of its people, one upstairs and one off the floor on the same level
	var/turf/off_floor = elsewhere.bottom_left_turfs[1]
	var/mob/living/carbon/human/member_up = rooms_person(floor_tile(floor, 22, 5), "floorroomswingup")
	var/mob/living/carbon/human/member_down = rooms_person(off_floor, "floorroomswingdown")
	var/mob/living/neighbour = test_person(deck_tile(next_floor))
	host.residents += list(member_up.mind, member_down.mind)
	TEST_ASSERT(prison.is_member(member_up) && prison.is_member(member_down), "Fixture: the floor's residents are not members of its wing")
	TEST_ASSERT(member_down.z == floor.bounds[5] && neighbour.z == floor.bounds[5], "Fixture: the test floors are on different levels, so nothing is proven")
	var/datum/ai_controller/brain = arrival.ai_controller
	TEST_ASSERT_NOTNULL(brain, "Fixture: a prisoner has no AI")

	// A player on the next floor and one of the wing's own people downstairs: nobody is at the wing, and it sleeps
	rooms_stand_in(member_down)
	rooms_stand_in(neighbour)
	var/list/at_wing = prison.wing_clients()
	TEST_ASSERT(!(member_down in at_wing), "One of the floor's people off the floor counts as home (A1)")
	TEST_ASSERT(!(neighbour in at_wing), "A player on another floor of the level counts as at this wing (A1)")
	brain.set_ai_status(AI_STATUS_OFF)
	TEST_ASSERT(!outpost_prison_ai_running(arrival), "A player elsewhere on the level wakes a floor's wing (A1)")

	// One of them upstairs: at the wing, and it wakes
	rooms_stand_in(member_up)
	at_wing = prison.wing_clients()
	TEST_ASSERT(member_up in at_wing, "One of the floor's people on the floor does not count as home")
	TEST_ASSERT(!(member_down in at_wing) && !(neighbour in at_wing), "Someone off the floor counts as at the wing once a player is upstairs (A1)")
	brain.set_ai_status(AI_STATUS_OFF)
	TEST_ASSERT(outpost_prison_ai_running(arrival), "A player on the floor does not wake its wing")
	settle_room_air(rooms_built)

// ===== THE BOARD, ADVERTS AND RESEARCH =====

/// What a floor offers on the board, what its advert names, and which ship counts as docked at it
/datum/unit_test/voidcrew_outpost_floors/rooms/board_and_adverts

/datum/unit_test/voidcrew_outpost_floors/rooms/board_and_adverts/Run()
	var/obj/structure/overmap/trader_outpost/outpost = test_outpost()
	var/datum/outpost_floor/floor = rooms_floor(outpost, 3, 14, 12, "floorroomsboardowner")
	if(!floor)
		return
	var/obj/structure/overmap/dynamic/player_outpost/floor/host = floor.host
	TEST_ASSERT_EQUAL(length(floor.offers()), 0, "A bare floor offers something on the board")

	// Rooms pinned as built, without loading their maps
	for(var/room_type in list(/datum/outpost_upgrade/service/teleporter, /datum/outpost_upgrade/service/storage, /datum/outpost_upgrade/service/cloning_bay, /datum/outpost_upgrade/service/medical_lab))
		var/datum/outpost_upgrade/service/room = new room_type(host)
		room.installed = TRUE
		host.outpost_upgrades[room.key] = room
	TEST_ASSERT_EQUAL(jointext(floor.offers(), ", "), "Clinic, Cloning, Lockers, Teleporter", "The board's words for a floor's rooms are wrong or out of order")
	// The wing is nothing a visitor buys
	var/datum/outpost_upgrade/prison/wing = new(host)
	wing.installed = TRUE
	host.outpost_upgrades[wing.key] = wing
	TEST_ASSERT_EQUAL(length(floor.offers()), 4, "The board offers visitors the prison wing")

	// Shop only while the shop is open (shop_open(), floor_shopfront.dm)
	var/datum/outpost_upgrade/service/shop/shop = new(host)
	shop.installed = TRUE
	host.outpost_upgrades[shop.key] = shop
	var/list/words = floor.offers()
	TEST_ASSERT_EQUAL(("Shop" in words), !!floor.shop_open(), "The board and the shop disagree about whether it is open")
	if("Shop" in words)
		TEST_ASSERT_EQUAL(words[1], "Shop", "Shop is not the first word on the board")
	shop.is_open = FALSE
	TEST_ASSERT(!("Shop" in floor.offers()), "The board offers a shop that is shut")

	// A floor nobody holds offers nothing
	host.founder_ckey = null
	TEST_ASSERT_EQUAL(length(floor.offers()), 0, "A floor nobody holds offers something on the board")
	host.founder_ckey = "floorroomsboardowner"

	// An advert names the floor and its outpost, and is pinned where the outpost is
	var/outpost_name = format_text(outpost.name)
	TEST_ASSERT(length(outpost_name), "Fixture: the trader outpost has no name")
	floor.floor_name = "The Rusty Anchor"
	TEST_ASSERT_EQUAL(host.advert_place(), "The Rusty Anchor, [outpost_name]", "An advert does not name the floor and its outpost")
	floor.floor_name = null
	TEST_ASSERT_EQUAL(host.advert_place(), outpost_name, "An advert for an unnamed floor does not name its outpost")
	floor.floor_name = "The Rusty Anchor"
	var/list/pinned = host.advert_coords()
	var/list/chart = outpost.get_relative_overmap_coords()
	TEST_ASSERT(islist(pinned) && islist(chart), "An advert for a floor has no place on the chart")
	TEST_ASSERT(pinned[1] == chart[1] && pinned[2] == chart[2], "An advert for a floor is not pinned on its outpost")
	var/datum/outpost_advert/advert = new(host)
	TEST_ASSERT_EQUAL(advert.outpost_name, "The Rusty Anchor, [outpost_name]", "A broadcast does not name the floor and its outpost")
	TEST_ASSERT(advert.coord_x == chart[1] && advert.coord_y == chart[2], "A broadcast is not pinned on the floor's outpost")
	qdel(advert)

	// Docked here, for research links: a ship of the floor's own people in one of this outpost's berths
	var/mob/living/carbon/human/owner = rooms_person(deck_tile(floor), "floorroomsboardowner")
	host.founder_mind = WEAKREF(owner.mind)
	var/obj/structure/overmap/ship/crew_ship = allocate(/obj/structure/overmap/ship)
	crew_ship.ship_team = rooms_enlist(owner)
	var/obj/structure/overmap/ship/strange_ship = allocate(/obj/structure/overmap/ship)
	strange_ship.ship_team = allocate(/datum/team/voidcrew)
	TEST_ASSERT(!host.ship_is_home(crew_ship), "A ship that is not docked counts as docked at a floor")
	crew_ship.docked = outpost
	strange_ship.docked = outpost
	TEST_ASSERT(host.ship_is_home(crew_ship), "The crew's own ship in the outpost's berth does not count as docked at their floor")
	TEST_ASSERT(!host.ship_is_home(strange_ship), "A stranger's ship in the outpost's berth counts as docked at a floor")
	// A resident's ship counts too
	var/mob/living/carbon/human/resident = rooms_person(deck_tile(floor), "floorroomsboardresident")
	host.residents += resident.mind
	strange_ship.ship_team.members |= resident.mind
	TEST_ASSERT(host.ship_is_home(strange_ship), "A resident's ship in the outpost's berth does not count as docked at their floor")
	strange_ship.ship_team.members -= resident.mind
	// Another outpost's berth is not this one's
	var/obj/structure/overmap/trader_outpost/other_outpost = test_outpost(/obj/structure/overmap/trader_outpost/outfitter)
	crew_ship.docked = other_outpost
	TEST_ASSERT(!host.ship_is_home(crew_ship), "The crew's ship at another outpost counts as docked at their floor")
	crew_ship.docked = null
	strange_ship.docked = null
