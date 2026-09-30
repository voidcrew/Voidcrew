/**
 * Outpost marketplace foundation hardening: the charge compares effective prices, service rooms
 * survive a singularity, a room cannot be sealed at placement and reports a blocked or airless
 * exit, room dressing stays bolted, service doors keep no id, and a shop sale breaks summon marks.
 *
 * Voidcrew defines are not visible from test files, so prices and ids appear as literals.
 */

/// Five by three: a closet and two floor tiles behind one public service door, centred on the south edge
/datum/map_template/outpost_upgrade/p0_exit_test
	name = "Service Exit Test Room"
	mappath = "voidcrew/_maps/map_files/unit_tests/outpost_service_exit_test.dmm"

/// Never in the catalog: the test gives it an id at runtime
/datum/outpost_upgrade/service/p0_exit_test
	name = "service exit test room"
	template_type = /datum/map_template/outpost_upgrade/p0_exit_test

/// F-01: the charge compares what this payer owes now with the effective price they were shown
/datum/unit_test/voidcrew_outpost_market_p0_charge
	parent_type = /datum/unit_test/voidcrew_outpost_management

/datum/unit_test/voidcrew_outpost_market_p0_charge/Run()
	var/obj/structure/overmap/dynamic/player_outpost/home = market_test_claim("p0chargeowner")
	TEST_ASSERT_NOTNULL(home, "The charge test outpost did not load")
	var/turf/console_turf = get_turf(home.management_console)
	var/mob/living/carbon/human/owner = make_market_visitor(console_turf, "p0chargeowner", 1000)
	var/mob/living/carbon/human/visitor = make_market_visitor(console_turf, "p0chargevisitor", 1000)
	var/datum/bank_account/owner_account = owner.get_idcard(TRUE)?.registered_account
	var/datum/bank_account/visitor_account = visitor.get_idcard(TRUE)?.registered_account
	TEST_ASSERT(home.is_outpost_member(owner), "The owner is not a member")
	TEST_ASSERT(!home.is_outpost_member(visitor), "The visitor is a member")
	var/treasury_start = home.treasury.account_balance

	// A member shown 0 at a listed 200 uses the service free
	TEST_ASSERT_NULL(home.charge_service(owner, "clone_imprint", 200, 0, "Test"), "A member shown the free price was refused")
	TEST_ASSERT_EQUAL(owner_account.account_balance, 1000, "A member was charged")
	// A member shown the listed price was quoted wrong, and nothing moves
	TEST_ASSERT_NOTNULL(home.charge_service(owner, "clone_imprint", 200, 200, "Test"), "A member was charged the listed price")
	TEST_ASSERT_EQUAL(owner_account.account_balance, 1000, "A refused member charge moved money")

	// A visitor shown 0 is refused, and nothing moves
	TEST_ASSERT_NOTNULL(home.charge_service(visitor, "clone_imprint", 200, 0, "Test"), "A visitor shown 0 was let through")
	TEST_ASSERT_EQUAL(visitor_account.account_balance, 1000, "A refused visitor charge moved money")
	TEST_ASSERT_EQUAL(home.treasury.account_balance, treasury_start, "A refused visitor charge paid the treasury")

	// A visitor shown 200 pays once
	TEST_ASSERT_NULL(home.charge_service(visitor, "clone_imprint", 200, 200, "Test"), "A visitor shown the right price was refused")
	TEST_ASSERT_EQUAL(visitor_account.account_balance, 800, "The visitor was not charged exactly once")
	TEST_ASSERT_EQUAL(home.treasury.account_balance, treasury_start + 200, "The treasury was not paid exactly once")

	// A member who became a visitor after seeing 0 is refused, and nothing moves
	home.playtest_visitor_ckey = owner.ckey
	TEST_ASSERT_NOTNULL(home.charge_service(owner, "clone_imprint", 200, 0, "Test"), "A lapsed member was charged without seeing the price")
	TEST_ASSERT_EQUAL(owner_account.account_balance, 1000, "A lapsed member's refused charge moved money")
	TEST_ASSERT_EQUAL(home.treasury.account_balance, treasury_start + 200, "A lapsed member's refused charge paid the treasury")
	home.playtest_visitor_ckey = null

	// A price with no number is refused
	TEST_ASSERT_NOTNULL(home.charge_service(visitor, "clone_imprint", 200, "200", "Test"), "A text shown price was accepted")
	TEST_ASSERT_EQUAL(visitor_account.account_balance, 800, "A text shown price moved money")

/// F-02, F-03, F-04, F-06, F-07 on a placed room
/datum/unit_test/voidcrew_outpost_market_p0_room
	parent_type = /datum/unit_test/voidcrew_outpost_management

/datum/unit_test/voidcrew_outpost_market_p0_room/Run()
	var/obj/structure/overmap/dynamic/player_outpost/home = market_test_claim("p0roomowner")
	TEST_ASSERT_NOTNULL(home, "The room test outpost did not load")
	var/datum/outpost_upgrade/service/p0_exit_test/blueprint = allocate(__IMPLIED_TYPE__, home)
	blueprint.id = "p0_exit_test"
	blueprint.key = blueprint.id
	home.outpost_upgrades[blueprint.id] = blueprint
	var/datum/map_template/template = blueprint.get_template()
	TEST_ASSERT_NOTNULL(template, "The exit test room map did not load")

	// The door offsets read from the map as drawn
	var/list/offsets = blueprint.template_door_offsets()
	TEST_ASSERT_EQUAL(length(offsets), 1, "The exit test room should have one service door")
	var/list/door_offset = offsets[1]
	TEST_ASSERT_EQUAL(door_offset[1], 2, "The door's column was read wrong")
	TEST_ASSERT_EQUAL(door_offset[2], 0, "The door's row was read wrong")

	// F-03: a wall just outside the door refuses the placement, and claims nothing
	var/turf/corner = service_room_test_corner(home, blueprint, 0)
	TEST_ASSERT_NOTNULL(corner, "No test corner for the room")
	var/turf/door_spot = locate(corner.x + 2, corner.y, corner.z)
	var/turf/outside = get_step(door_spot, SOUTH)
	var/outside_type = outside.type
	outside.ChangeTurf(/turf/closed/wall)
	TEST_ASSERT_EQUAL(home.place_outpost_upgrade(blueprint, corner, 0, null), "Entrance blocked.", "A room was placed with a wall against its door")
	TEST_ASSERT(!blueprint.installed && !blueprint.placing && !blueprint.footprint_bounds, "A refused placement claimed the blueprint")
	outside = outside.ChangeTurf(outside_type)

	var/placed = place_test_service_room(home, blueprint, list(0))
	TEST_ASSERT(placed == blueprint, "The exit test room was not placed: [placed]")
	var/list/room_turfs = blueprint.room_turfs()

	// F-06 and F-02 on the door
	TEST_ASSERT_EQUAL(length(blueprint.doors), 1, "The room adopted the wrong number of doors")
	var/datum/weakref/door_ref = blueprint.doors[1]
	var/obj/machinery/door/airlock/outpost/service/door = door_ref.resolve()
	TEST_ASSERT_NOTNULL(door, "The adopted door is gone")
	TEST_ASSERT_NULL(door.id_tag, "A service door kept the id_tag its map gave it")
	TEST_ASSERT_EQUAL(door.singularity_act(), 0, "A singularity ate a service door")
	TEST_ASSERT(!QDELETED(door), "A singularity deleted a service door")

	// F-04: every structure is bolted down for good; F-02: every fixture is spared by singularities
	var/obj/structure/closet/closet
	for(var/turf/tile as anything in room_turfs)
		for(var/obj/fixture in tile)
			if(!ismachinery(fixture) && !isstructure(fixture))
				continue
			TEST_ASSERT(singularity_spares(fixture), "[fixture] in the room is not singularity-proof")
			if(isstructure(fixture))
				TEST_ASSERT(fixture.anchored, "[fixture] in the room is not anchored")
			if(istype(fixture, /obj/structure/closet))
				closet = fixture
	TEST_ASSERT_NOTNULL(closet, "The test room lost its closet")
	TEST_ASSERT(!closet.anchorable, "The room's closet can be unbolted")

	// F-02: the singularity's eat path skips room fixtures, and a tear on a room tile collapses
	var/turf/inside = locate(corner.x + 2, corner.y + 1, corner.z)
	TEST_ASSERT(is_outpost_service_tile(inside), "The room's floor is not a service tile")
	var/obj/item/loose = allocate(/obj/item/wrench, run_loc_floor_bottom_left)
	TEST_ASSERT(!singularity_spares(loose), "A loose item is singularity-proof")
	var/obj/item/anchor_point = allocate(/obj/item/wrench, run_loc_floor_bottom_left)
	var/datum/component/singularity/hole = anchor_point.AddComponent(/datum/component/singularity, consume_range = 0, grav_pull = 0, notify_admins = FALSE, roaming = FALSE)
	hole.consume(null, closet)
	TEST_ASSERT(!QDELETED(closet), "A singularity ate a room's closet")
	qdel(hole)
	var/obj/reality_tear/tear = allocate(/obj/reality_tear, inside)
	tear.start_disaster()
	TEST_ASSERT(QDELETED(tear), "A reality tear in a service room was not neutralized")

	// F-03: an exit onto space is open; a wall is blocked; then clear
	outside = outside.ChangeTurf(/turf/open/space/basic)
	TEST_ASSERT_NULL(blueprint.exit_denial(), "An exit onto space was reported: [blueprint.exit_denial()]")
	outside = outside.ChangeTurf(/turf/closed/wall)
	TEST_ASSERT_EQUAL(blueprint.exit_denial(), "Exit blocked", "A wall against the door was not reported")
	// With the door walled off, an opening the owner makes in the room's own wall is a way out
	var/turf/wall_gap = locate(corner.x, corner.y + 1, corner.z)
	var/turf/beyond_gap = get_step(wall_gap, WEST)
	var/wall_type = wall_gap.type
	var/beyond_type = beyond_gap.type
	beyond_gap = beyond_gap.ChangeTurf(/turf/open/floor/iron)
	TEST_ASSERT_EQUAL(blueprint.exit_denial(), "Exit blocked", "A closed room wall counted as a way out")
	wall_gap = wall_gap.ChangeTurf(/turf/open/floor/iron)
	TEST_ASSERT_NULL(blueprint.exit_denial(), "An opening in the room's wall was not a way out: [blueprint.exit_denial()]")
	wall_gap.ChangeTurf(wall_type)
	beyond_gap.ChangeTurf(beyond_type)
	TEST_ASSERT_EQUAL(blueprint.exit_denial(), "Exit blocked", "A rebuilt room wall still counted as a way out")
	outside = outside.ChangeTurf(/turf/open/floor/iron)
	// A wall turned to floor averages its neighbours' air (vacuum here); give the corridor station air
	var/turf/open/corridor = outside
	corridor.air.copy_from(SSair.parse_gas_string(OPENTURF_DEFAULT_ATMOS, /datum/gas_mixture/turf))
	TEST_ASSERT_NULL(blueprint.exit_denial(), "A breathable corridor outside the door was reported: [blueprint.exit_denial()]")
	// B-11: removable clutter never closes a room, only fixed or protected blockers do
	var/obj/structure/grille/grille = allocate(__IMPLIED_TYPE__, outside)
	TEST_ASSERT_NULL(blueprint.exit_denial(), "A cuttable grille across the door closed the room")
	grille.resistance_flags |= INDESTRUCTIBLE
	TEST_ASSERT_EQUAL(blueprint.exit_denial(), "Exit blocked", "An indestructible grille across the door was not reported")
	qdel(grille)

	settle_room_air(room_turfs)

/// F-25: selling an item breaks summon marks made before the sale, but not the buyer's own
/datum/unit_test/voidcrew_outpost_market_p0_recall

/datum/unit_test/voidcrew_outpost_market_p0_recall/Run()
	var/mob/living/carbon/human/consistent/seller = allocate(__IMPLIED_TYPE__, run_loc_floor_bottom_left)
	var/mob/living/carbon/human/consistent/buyer = allocate(__IMPLIED_TYPE__, run_loc_floor_top_right)
	var/obj/item/toy/plush/goods = allocate(__IMPLIED_TYPE__, run_loc_floor_bottom_left)
	var/datum/action/cooldown/spell/summonitem/summons = allocate(__IMPLIED_TYPE__, seller)
	summons.mark_item(goods)

	sever_magic_recall(goods)
	buyer.put_in_hands(goods)
	summons.try_recall_item(seller)
	TEST_ASSERT_NULL(summons.marked_item, "The seller's mark survived the sale")
	TEST_ASSERT_EQUAL(goods.loc, buyer, "The seller recalled a sold item")

	// The buyer's own mark, made after the sale, is kept
	var/datum/action/cooldown/spell/summonitem/buyer_summons = allocate(__IMPLIED_TYPE__, buyer)
	buyer_summons.mark_item(goods)
	TEST_ASSERT(!buyer_summons.recall_severed(null), "A mark made after the sale was broken")
	TEST_ASSERT_EQUAL(buyer_summons.marked_item, goods, "The buyer lost their mark")

	// Sold again: that mark breaks too
	sever_magic_recall(goods)
	TEST_ASSERT(buyer_summons.recall_severed(null), "A second sale did not break the earlier mark")
	TEST_ASSERT_NULL(buyer_summons.marked_item, "A broken mark stayed on the spell")
