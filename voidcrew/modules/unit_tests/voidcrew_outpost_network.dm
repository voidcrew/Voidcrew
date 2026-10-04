/**
 * The outpost teleporter network (outpost_network.dm, outpost_teleporter.dm). Two claims with
 * Teleporter rooms; trips are driven by calling start_trip() and finish_trip() directly.
 * Voidcrew defines are not visible here: prices, policies and ids are literals.
 */

/// Two claims with a Teleporter room each, and their pads, into `out`. Null, or an error.
/datum/unit_test/voidcrew_outpost_management/proc/network_test_pair(list/out)
	var/obj/structure/overmap/dynamic/player_outpost/home_a = market_test_claim("netownera")
	var/obj/structure/overmap/dynamic/player_outpost/home_b = market_test_claim("netownerb")
	if(!home_a || !home_b)
		return "A network test outpost did not load."
	var/datum/outpost_upgrade/service/teleporter/room_a = place_test_service_room(home_a, /datum/outpost_upgrade/service/teleporter)
	if(!istype(room_a))
		return "The first teleporter room was not placed: [room_a]"
	var/datum/outpost_upgrade/service/teleporter/room_b = place_test_service_room(home_b, /datum/outpost_upgrade/service/teleporter)
	if(!istype(room_b))
		return "The second teleporter room was not placed: [room_b]"
	out["home_a"] = home_a
	out["home_b"] = home_b
	out["room_a"] = room_a
	out["room_b"] = room_b
	// A breathable corridor outside each door, or the rooms report their exit to vacuum
	for(var/datum/outpost_upgrade/service/teleporter/room as anything in list(room_a, room_b))
		for(var/turf/exit as anything in room.exit_turfs())
			if(!isclosedturf(exit))
				exit.ChangeTurf(/turf/open/floor/iron)
	out["pad_a"] = room_a.pad_ref?.resolve()
	out["pad_b"] = room_b.pad_ref?.resolve()
	if(!out["pad_a"] || !out["pad_b"])
		return "A teleporter room has no pad."
	return null

/datum/unit_test/voidcrew_outpost_management/proc/network_test_cleanup(list/rig)
	GLOB.outpost_network_ready_at.Cut()
	for(var/key in list("room_a", "room_b"))
		var/datum/outpost_upgrade/service/teleporter/room = rig[key]
		if(room)
			settle_room_air(room.room_turfs())

// ===== REGISTRY, TRIP AND FARE =====

/datum/unit_test/voidcrew_outpost_network_trip
	parent_type = /datum/unit_test/voidcrew_outpost_management

/datum/unit_test/voidcrew_outpost_network_trip/Run()
	var/list/rig = list()
	var/error = network_test_pair(rig)
	TEST_ASSERT_NULL(error, error)
	var/obj/structure/overmap/dynamic/player_outpost/home_b = rig["home_b"]
	var/datum/outpost_upgrade/service/teleporter/room_b = rig["room_b"]
	var/obj/machinery/outpost_network_pad/pad_a = rig["pad_a"]
	var/obj/machinery/outpost_network_pad/pad_b = rig["pad_b"]
	TEST_ASSERT_EQUAL(pad_a.network_host(), rig["home_a"], "The first pad is not on the network")
	TEST_ASSERT_EQUAL(pad_b.network_host(), home_b, "The second pad is not on the network")
	TEST_ASSERT(pad_b.arrival_turf && room_b.is_inside(pad_b.arrival_turf), "The arrival spot is not inside the room")
	TEST_ASSERT_EQUAL(pad_b.arrival_turf, get_turf(pad_b), "Arrivals do not land on the pad")
	TEST_ASSERT_EQUAL(room_b.arrival_policy, "open", "Arrivals do not default to open")
	TEST_ASSERT(!istype(pad_a, /obj/machinery/quantumpad), "The network pad is a quantum pad")

	// A pad outside a Teleporter room is never on the network
	var/obj/machinery/outpost_network_pad/stray = allocate(/obj/machinery/outpost_network_pad, get_step(pad_a, NORTH))
	TEST_ASSERT(stray in GLOB.outpost_network_pads, "A new pad did not register")
	TEST_ASSERT_NULL(stray.network_host(), "A stray pad joined the network")

	var/mob/living/carbon/human/visitor = make_market_visitor(get_turf(pad_a), "netvisitor", 1000)
	var/datum/bank_account/account = visitor.get_idcard(TRUE)?.registered_account
	var/obj/item/toy/plush/carried = allocate(/obj/item/toy/plush)
	visitor.put_in_hands(carried)
	var/list/data = pad_a.ui_data(visitor)
	var/list/row
	for(var/list/entry as anything in data["destinations"])
		if(entry["id"] == pad_b.network_id)
			row = entry
		TEST_ASSERT(entry["id"] != stray.network_id, "A stray pad was listed as a destination")
	TEST_ASSERT_NOTNULL(row, "The second outpost was not listed")
	TEST_ASSERT_EQUAL(row["fee"], 200, "The default arrival fare is not 200 cr")
	TEST_ASSERT(row["available"], "The second outpost was not available: [row["reason"]]")

	// A wrong fare is refused, then a real trip moves the traveller and what they carry
	TEST_ASSERT_EQUAL(pad_a.start_trip(visitor, pad_b, 0), "Price changed to 200 cr.", "A trip started at the wrong fare")
	var/treasury_before = home_b.treasury.account_balance
	TEST_ASSERT_NULL(pad_a.start_trip(visitor, pad_b, 200), "The trip did not start")
	TEST_ASSERT(pad_a.is_charging() && pad_b.is_receiving(), "The pads did not claim the trip")
	var/mob/living/carbon/human/second = make_market_visitor(get_step(pad_a, SOUTH), null, 0)
	TEST_ASSERT_EQUAL(pad_b.arrival_denial(second, pad_a), "Busy", "A second trip could aim at a busy pad")
	TEST_ASSERT_NULL(pad_a.finish_trip(), "The trip did not finish")
	TEST_ASSERT_EQUAL(get_turf(visitor), pad_b.arrival_turf, "The traveller did not arrive on the arrival spot")
	TEST_ASSERT_EQUAL(get_turf(carried), pad_b.arrival_turf, "What the traveller carried did not travel")
	TEST_ASSERT_EQUAL(account.account_balance, 800, "The fare was not taken exactly once")
	TEST_ASSERT_EQUAL(home_b.treasury.account_balance, treasury_before + 200, "The fare did not reach the destination's treasury")
	TEST_ASSERT_EQUAL(room_b.trips_in, 1, "The arrival was not counted")
	TEST_ASSERT(!pad_a.is_charging() && !pad_b.is_receiving(), "The pads kept their claim after the trip")

	// Two minutes before the next trip
	visitor.forceMove(get_turf(pad_b))
	TEST_ASSERT(findtext(pad_b.departure_denial(visitor), "Recharging"), "The traveller could leave again at once")
	GLOB.outpost_network_ready_at.Cut()

	// Members travel free
	var/mob/living/carbon/human/owner_b = make_market_visitor(get_turf(pad_a), "netownerb", 0)
	TEST_ASSERT_EQUAL(pad_b.arrival_fee(owner_b), 0, "A member was charged a fare home")
	TEST_ASSERT_NULL(pad_a.start_trip(owner_b, pad_b, 0), "A member could not start a free trip")
	TEST_ASSERT_NULL(pad_a.finish_trip(), "A member's free trip did not finish")
	TEST_ASSERT_EQUAL(get_turf(owner_b), pad_b.arrival_turf, "The member did not arrive")
	network_test_cleanup(rig)

// ===== CANCELLING AND REFUSALS =====

/datum/unit_test/voidcrew_outpost_network_refusals
	parent_type = /datum/unit_test/voidcrew_outpost_management

/datum/unit_test/voidcrew_outpost_network_refusals/Run()
	var/list/rig = list()
	var/error = network_test_pair(rig)
	TEST_ASSERT_NULL(error, error)
	var/obj/structure/overmap/dynamic/player_outpost/home_b = rig["home_b"]
	var/obj/machinery/outpost_network_pad/pad_a = rig["pad_a"]
	var/obj/machinery/outpost_network_pad/pad_b = rig["pad_b"]
	var/turf/pad_turf = get_turf(pad_a)
	var/turf/beside = pad_a.pad_step_off_turf()
	TEST_ASSERT_NOTNULL(beside, "No free tile beside the pad")
	var/mob/living/carbon/human/visitor = make_market_visitor(pad_turf, "netrefused", 1000)
	var/datum/bank_account/account = visitor.get_idcard(TRUE)?.registered_account
	var/treasury_before = home_b.treasury.account_balance

	// Damage, stepping off and passing out each cancel with nothing charged
	TEST_ASSERT_NULL(pad_a.start_trip(visitor, pad_b, 200), "The trip did not start")
	visitor.apply_damage(10, BRUTE)
	TEST_ASSERT(!pad_a.is_charging(), "Damage did not cancel the charge")
	TEST_ASSERT_EQUAL(visitor.alpha, 255, "The traveller was left faded after a cancel")
	visitor.fully_heal()
	TEST_ASSERT_NULL(pad_a.start_trip(visitor, pad_b, 200), "The trip did not restart after damage")
	visitor.forceMove(beside)
	TEST_ASSERT(!pad_a.is_charging(), "Leaving the pad did not cancel the charge")
	visitor.forceMove(pad_turf)
	// B-14: walking off a charge costs a short recharge
	TEST_ASSERT(findtext(pad_a.start_trip(visitor, pad_b, 200), "Recharging"), "Stepping off a charging pad cost no recharge")
	TEST_ASSERT(GLOB.outpost_network_ready_at["netrefused"] <= world.time + 15 SECONDS, "The cancel recharge is longer than 15 seconds")
	GLOB.outpost_network_ready_at.Cut()
	TEST_ASSERT_NULL(pad_a.start_trip(visitor, pad_b, 200), "The trip did not restart after stepping off")
	visitor.set_stat(UNCONSCIOUS)
	TEST_ASSERT(!pad_a.is_charging(), "Passing out did not cancel the charge")
	visitor.set_stat(CONSCIOUS)
	// Passing out knocked them down, and lying down blocks pulling later on
	visitor.get_up(instant = TRUE)
	TEST_ASSERT_EQUAL(account.account_balance, 1000, "A cancelled trip charged the traveller")
	TEST_ASSERT_EQUAL(home_b.treasury.account_balance, treasury_before, "A cancelled trip paid the destination")

	// A fare raised during the charge refuses the trip
	TEST_ASSERT_NULL(pad_a.start_trip(visitor, pad_b, 200), "The trip did not restart after passing out")
	home_b.outpost_prices["teleport_arrival"] = 300
	TEST_ASSERT_EQUAL(pad_a.finish_trip(), "Price changed to 300 cr.", "A raised fare was charged without consent")
	TEST_ASSERT_EQUAL(get_turf(visitor), pad_turf, "The traveller moved on a refused trip")
	TEST_ASSERT_EQUAL(account.account_balance, 1000, "A refused trip charged the traveller")
	home_b.outpost_prices -= "teleport_arrival"

	// Someone who was just in a fight still travels
	var/mob/living/carbon/human/attacker = make_market_visitor(beside, "netattacker", 0)
	attacker.set_combat_mode(TRUE)
	GLOB.outpost_pvp_enforcement.on_outpost_pvp_unarmed_attack(visitor, attacker, list())
	TEST_ASSERT_NULL(pad_a.departure_denial(visitor), "A fight stopped the traveller leaving")

	// What cannot travel
	TEST_ASSERT_EQUAL(pad_a.departure_denial(attacker), "Stand on the pad.", "Someone off the pad could leave")
	var/obj/structure/closet/crate/crate = allocate(/obj/structure/closet/crate, beside)
	visitor.start_pulling(crate)
	TEST_ASSERT_EQUAL(visitor.pulling, crate, "The traveller could not pull the crate")
	TEST_ASSERT_EQUAL(pad_a.departure_denial(visitor), "Let go first.", "A traveller could pull a crate along")
	visitor.stop_pulling()
	var/obj/item/storage/box/box = allocate(/obj/item/storage/box)
	visitor.put_in_hands(box)
	var/mob/living/basic/mouse/mouse = allocate(/mob/living/basic/mouse, box)
	TEST_ASSERT(findtext(pad_a.departure_denial(visitor), "You are carrying"), "A mob in a box travelled")
	qdel(mouse)
	var/obj/item/ship_key/key = allocate(/obj/item/ship_key, box)
	TEST_ASSERT(findtext(pad_a.departure_denial(visitor), "The pad refuses"), "A ship key travelled")
	qdel(key)
	var/obj/item/mission_recovery/cargo = allocate(/obj/item/mission_recovery, box)
	TEST_ASSERT(findtext(pad_a.departure_denial(visitor), "The pad refuses"), "Contract cargo travelled")
	qdel(cargo)
	ADD_TRAIT(visitor, TRAIT_RESTRAINED, TRAIT_SOURCE_UNIT_TESTS)
	TEST_ASSERT_EQUAL(pad_a.departure_denial(visitor), "Restrained.", "A restrained traveller could leave")
	REMOVE_TRAIT(visitor, TRAIT_RESTRAINED, TRAIT_SOURCE_UNIT_TESTS)
	ADD_TRAIT(visitor, TRAIT_NO_TELEPORT, TRAIT_SOURCE_UNIT_TESTS)
	TEST_ASSERT_EQUAL(pad_a.departure_denial(visitor), "Something holds you in place.", "TRAIT_NO_TELEPORT was ignored")
	REMOVE_TRAIT(visitor, TRAIT_NO_TELEPORT, TRAIT_SOURCE_UNIT_TESTS)
	var/obj/structure/chair/chair = allocate(/obj/structure/chair, pad_turf)
	chair.buckle_mob(visitor, force = TRUE)
	TEST_ASSERT_EQUAL(pad_a.departure_denial(visitor), "Get up first.", "A buckled traveller could leave")
	chair.unbuckle_mob(visitor, force = TRUE)
	qdel(chair)
	var/leftover = pad_a.departure_denial(visitor)
	TEST_ASSERT_NULL(leftover, "The cleared traveller still could not leave: [leftover]")

	// A clientless body on the pad is stepped off for someone waiting (F-37). The traveller above
	// has no client either, so take them off first: the sleeper must be the only body on the pad.
	visitor.forceMove(beside)
	var/mob/living/carbon/human/sleeper = make_market_visitor(pad_turf, null, 0)
	var/list/on_pad = list()
	for(var/mob/living/occupant in pad_turf)
		on_pad += occupant
	TEST_ASSERT_EQUAL(length(on_pad), 1, "Someone besides the idle body is on the pad")
	var/turf/aside = pad_a.pad_step_off_turf()
	TEST_ASSERT_NOTNULL(aside, "No free tile to step the idle body onto")
	TEST_ASSERT_EQUAL(pad_a.clear_idle_occupant(attacker), sleeper, "An idle body was not cleared off the pad")
	TEST_ASSERT_EQUAL(get_turf(sleeper), aside, "The idle body was not stepped off beside the pad")
	network_test_cleanup(rig)

// ===== WHO MAY ARRIVE =====

/datum/unit_test/voidcrew_outpost_network_policies
	parent_type = /datum/unit_test/voidcrew_outpost_management

/datum/unit_test/voidcrew_outpost_network_policies/Run()
	var/list/rig = list()
	var/error = network_test_pair(rig)
	TEST_ASSERT_NULL(error, error)
	var/obj/structure/overmap/dynamic/player_outpost/home_b = rig["home_b"]
	var/datum/outpost_upgrade/service/teleporter/room_b = rig["room_b"]
	var/obj/machinery/outpost_network_pad/pad_a = rig["pad_a"]
	var/obj/machinery/outpost_network_pad/pad_b = rig["pad_b"]
	var/mob/living/carbon/human/visitor = make_market_visitor(get_turf(pad_a), "netpolicy", 1000)
	var/mob/living/carbon/human/owner_b = make_market_visitor(get_step(pad_a, SOUTH), "netownerb", 0)

	room_b.arrival_policy = "members"
	TEST_ASSERT_EQUAL(pad_b.arrival_denial(visitor, pad_a), "Members only", "A visitor passed a members-only pad")
	TEST_ASSERT_NULL(pad_b.arrival_denial(owner_b, pad_a), "A member was refused at home")
	room_b.arrival_policy = "allowlist"
	TEST_ASSERT_EQUAL(pad_b.arrival_denial(visitor, pad_a), "Not on the list", "An unlisted source passed the allow list")
	room_b.allowed_pads += pad_a.network_id
	TEST_ASSERT_NULL(pad_b.arrival_denial(visitor, pad_a), "A listed source was refused")
	room_b.arrival_policy = "closed"
	TEST_ASSERT_EQUAL(pad_b.arrival_denial(visitor, pad_a), "Closed", "A closed pad admitted a visitor")
	room_b.arrival_policy = "open"
	TEST_ASSERT_NULL(pad_b.arrival_denial(visitor, pad_a), "An open pad refused a visitor")

	// Docking modes apply to pad arrivals (R8, R9)
	home_b.dock_mode = "request"
	TEST_ASSERT_EQUAL(pad_b.arrival_denial(visitor, pad_a), "Approved crews only", "REQUEST mode left the pad open")
	home_b.dock_mode = "lockdown"
	TEST_ASSERT_EQUAL(pad_b.arrival_denial(visitor, pad_a), "Lockdown", "Lockdown admitted a visitor")
	TEST_ASSERT_NULL(pad_b.arrival_denial(owner_b, pad_a), "Lockdown refused a member")
	home_b.dock_mode = "open"

	// The room door stays public and the door tool refuses it; the arrival policy is the owner's lever (F-33)
	var/datum/weakref/room_door_ref = LAZYACCESS(room_b.doors, 1)
	var/obj/machinery/door/room_door = room_door_ref?.resolve()
	TEST_ASSERT_NOTNULL(room_door, "The teleporter room has no door")
	TEST_ASSERT_EQUAL(outpost_door_access_of(room_door), "public", "The teleporter room's door did not start public")
	TEST_ASSERT_EQUAL(home_b.set_door_access(owner_b, room_door, "members"), "Stays public.", "The teleporter room's door could be keyed")
	TEST_ASSERT_EQUAL(outpost_door_access_of(room_door), "public", "The teleporter room's door was keyed")

	// A room that opens onto space still takes arrivals: what is outside is the owner's business
	var/list/exits = room_b.exit_turfs()
	TEST_ASSERT(length(exits), "The teleporter room has no exit")
	var/turf/exit = exits[1]
	exit = exit.ChangeTurf(/turf/open/space/basic)
	TEST_ASSERT_NULL(pad_b.arrival_denial(visitor, pad_a), "A room opening onto space refused arrivals")
	exit.ChangeTurf(/turf/open/floor/iron)

	// A blocked arrival spot refuses arrivals
	// B-11: a wrenched-down closet is clutter and never closes the pad; a fixed blocker does
	var/obj/structure/closet/blocker = allocate(/obj/structure/closet, pad_b.arrival_turf)
	blocker.set_anchored(TRUE)
	TEST_ASSERT_NULL(pad_b.arrival_denial(visitor, pad_a), "A wrenched closet on the arrival spot closed the pad")
	blocker.resistance_flags |= INDESTRUCTIBLE
	TEST_ASSERT_EQUAL(pad_b.arrival_denial(visitor, pad_a), "Arrival blocked", "A fixed blocker on the arrival spot took arrivals")
	qdel(blocker)

	// Abandonment: arrivals close while unowned; the settings go back to defaults
	room_b.arrival_policy = "members"
	room_b.on_outpost_abandoned()
	TEST_ASSERT_EQUAL(room_b.arrival_policy, "open", "Abandonment did not reset the arrival policy")
	TEST_ASSERT(!length(room_b.allowed_pads), "Abandonment kept the allow list")
	home_b.founder_ckey = null
	TEST_ASSERT_EQUAL(pad_b.arrival_denial(visitor, pad_a), "Closed", "An unowned outpost took arrivals")
	home_b.founder_ckey = "netownerb"

	// Management actions need management access
	room_b.service_ui_act(visitor, "set_teleporter_arrivals", list("mode" = "closed"))
	TEST_ASSERT_EQUAL(room_b.arrival_policy, "open", "A visitor changed the arrival policy")
	room_b.service_ui_act(owner_b, "set_teleporter_arrivals", list("mode" = "closed"))
	TEST_ASSERT_EQUAL(room_b.arrival_policy, "closed", "The owner could not change the arrival policy")
	room_b.service_ui_act(owner_b, "teleporter_allow", list("target" = pad_a.network_id))
	TEST_ASSERT(pad_a.network_id in room_b.allowed_pads, "The owner could not allow a source pad")
	var/list/detail = room_b.service_ui_data(owner_b)
	for(var/key in list("kind", "padName", "arrivals", "allowlist", "candidates", "can_edit"))
		TEST_ASSERT(key in detail, "The management card is missing [key]")
	TEST_ASSERT(!("visitors_allowed" in detail), "The management card sends visitors_allowed")
	room_b.service_ui_act(owner_b, "teleporter_disallow", list("target" = pad_a.network_id))
	TEST_ASSERT(!(pad_a.network_id in room_b.allowed_pads), "The owner could not remove a source pad")
	network_test_cleanup(rig)

// ===== LIFECYCLE AND THE ZONE SEAM =====

/datum/unit_test/voidcrew_outpost_network_lifecycle
	parent_type = /datum/unit_test/voidcrew_outpost_management

/datum/unit_test/voidcrew_outpost_network_lifecycle/Run()
	var/list/rig = list()
	var/error = network_test_pair(rig)
	TEST_ASSERT_NULL(error, error)
	var/datum/outpost_upgrade/service/teleporter/room_b = rig["room_b"]
	var/obj/machinery/outpost_network_pad/pad_a = rig["pad_a"]
	var/obj/machinery/outpost_network_pad/pad_b = rig["pad_b"]
	var/mob/living/carbon/human/visitor = make_market_visitor(get_turf(pad_a), "netlife", 1000)
	var/datum/bank_account/account = visitor.get_idcard(TRUE)?.registered_account

	// Only the pad committing this traveller onto this arrival spot may cross zones
	TEST_ASSERT(!outpost_network_may_cross(visitor, pad_b.arrival_turf, "outpost_network"), "A traveller could cross with no trip")
	pad_a.committing_ref = WEAKREF(visitor)
	pad_a.committing_turf = pad_b.arrival_turf
	TEST_ASSERT(outpost_network_may_cross(visitor, pad_b.arrival_turf, "outpost_network"), "The committing trip could not cross")
	TEST_ASSERT(!outpost_network_may_cross(visitor, pad_b.arrival_turf, "quantum"), "Another channel could cross")
	TEST_ASSERT(!outpost_network_may_cross(visitor, get_step(pad_b, NORTH), "outpost_network"), "A trip could cross onto another tile")
	pad_a.committing_ref = null
	pad_a.committing_turf = null

	// A destination deleted mid-charge aborts with nothing charged
	TEST_ASSERT_NULL(pad_a.start_trip(visitor, pad_b, 200), "The trip did not start")
	qdel(pad_b)
	TEST_ASSERT(!(pad_b in GLOB.outpost_network_pads), "A deleted pad stayed registered")
	TEST_ASSERT(!pad_a.is_charging(), "A charge toward a deleted pad kept running")
	TEST_ASSERT_EQUAL(account.account_balance, 1000, "A trip to a deleted pad charged the traveller")
	TEST_ASSERT_NULL(room_b.pad_ref?.resolve(), "The room kept a deleted pad")

	// Trading outposts get a public pad at load, if the test world has any
	var/checked = 0
	for(var/obj/structure/overmap/trader_outpost/market as anything in GLOB.trader_outposts)
		if(!market.loaded)
			continue
		var/obj/machinery/outpost_network_pad/trader/public_pad = market.network_pad_ref?.resolve()
		TEST_ASSERT(istype(public_pad), "[market.name] has no network pad")
		TEST_ASSERT(istype(get_area(public_pad), /area/voidcrew/trader_outpost), "[market.name]'s pad is outside its concourse")
		TEST_ASSERT(!(get_turf(public_pad) in market.lobby_alcove_turfs), "[market.name]'s pad is in the elevator alcove")
		TEST_ASSERT_NULL(public_pad.arrival_tile_denial(), "[market.name]'s arrival spot is blocked")
		TEST_ASSERT_EQUAL(public_pad.arrival_denial(visitor, public_pad), "No route", "A trader pad routes to itself")
		checked++
	if(!checked)
		log_test("No trading outpost is loaded in this test world; trader pads were not checked.")
	network_test_cleanup(rig)

// ===== ONE CHARGE PER PAD, BUSY RULES, CLUTTER (abuse review B-06, B-11, B-12, B-14) =====

/datum/unit_test/voidcrew_outpost_network_pad_holds
	parent_type = /datum/unit_test/voidcrew_outpost_management

/datum/unit_test/voidcrew_outpost_network_pad_holds/Run()
	var/list/rig = list()
	var/error = network_test_pair(rig)
	TEST_ASSERT_NULL(error, error)
	var/obj/structure/overmap/dynamic/player_outpost/home_b = rig["home_b"]
	var/datum/outpost_upgrade/service/teleporter/room_b = rig["room_b"]
	var/obj/machinery/outpost_network_pad/pad_a = rig["pad_a"]
	var/obj/machinery/outpost_network_pad/pad_b = rig["pad_b"]
	var/mob/living/carbon/human/traveller = make_market_visitor(get_turf(pad_a), "netdouble", 1000)

	// B-06: a second confirm on a charging pad is refused and the first trip stands
	TEST_ASSERT_NULL(pad_a.start_trip(traveller, pad_b, 200), "The first trip did not start")
	TEST_ASSERT_EQUAL(pad_a.start_trip(traveller, pad_b, 200), "Pad in use.", "A second confirm restarted the charge")
	TEST_ASSERT_EQUAL(pad_a.charge_target_ref?.resolve(), pad_b, "The charge changed its destination")

	// Arrivals land on the pad: a pad with someone on the way in holds its own departures, and a pad
	// someone is leaving from takes no arrivals
	var/mob/living/carbon/human/outbound = make_market_visitor(get_turf(pad_b), "netoutbound", 1000)
	TEST_ASSERT(pad_b.is_receiving(), "The second pad is not receiving")
	TEST_ASSERT_EQUAL(pad_b.departure_denial(outbound), "Pad in use.", "A pad with an arrival on the way let someone leave")
	TEST_ASSERT_EQUAL(pad_a.arrival_denial(outbound, pad_b), "Pad in use", "A pad someone was leaving from took an arrival")

	TEST_ASSERT_NULL(pad_a.finish_trip(), "The trip did not finish")
	TEST_ASSERT_EQUAL(get_turf(traveller), pad_b.arrival_turf, "The traveller did not arrive")
	TEST_ASSERT_EQUAL(traveller.alpha, 255, "The traveller arrived faded")
	traveller.forceMove(get_turf(pad_a))

	// B-11: a closet a visitor wrenched down never closes the pad or the room
	var/obj/structure/closet/clutter = allocate(/obj/structure/closet, pad_b.arrival_turf)
	clutter.set_anchored(TRUE)
	TEST_ASSERT_NULL(pad_b.arrival_tile_denial(), "A wrenched-down closet blocked the arrival spot")
	qdel(clutter)
	var/list/exit_clutter = list()
	for(var/turf/exit as anything in room_b.exit_turfs())
		var/obj/structure/closet/blocker = allocate(/obj/structure/closet, exit)
		blocker.set_anchored(TRUE)
		exit_clutter += blocker
	TEST_ASSERT_NULL(room_b.exit_denial(), "A wrenched-down closet outside the door closed the room: [room_b.exit_denial()]")
	TEST_ASSERT_NULL(pad_b.arrival_denial(traveller, pad_a), "Clutter outside the door refused arrivals: [pad_b.arrival_denial(traveller, pad_a)]")
	QDEL_LIST(exit_clutter)

	// B-12: something nobody can remove just inside the door does close it
	var/list/fixed = list()
	for(var/list/route as anything in room_b.exit_routes())
		var/turf/inside = route[1]
		if(!inside)
			continue
		var/obj/structure/closet/fixed_blocker = allocate(/obj/structure/closet, inside)
		fixed_blocker.set_anchored(TRUE)
		fixed_blocker.resistance_flags |= INDESTRUCTIBLE
		fixed += fixed_blocker
	TEST_ASSERT(length(fixed), "The teleporter room has no tile inside its door")
	TEST_ASSERT_EQUAL(room_b.exit_denial(), "Exit blocked", "A fixed block inside the door did not close the room")
	QDEL_LIST(fixed)

	// B-12: visitors cannot build or bolt things down inside a service room; members can
	var/turf/room_tile = pad_b.arrival_turf
	var/mob/living/carbon/human/builder = make_market_visitor(room_tile, "netbuilder", 0)
	var/mob/living/carbon/human/owner_b = make_market_visitor(room_tile, "netownerb", 0)
	TEST_ASSERT(!outpost_service_build_allowed(builder, room_tile), "A visitor may build in a service room")
	TEST_ASSERT(outpost_service_build_allowed(owner_b, room_tile), "The owner may not build in their own service room")
	TEST_ASSERT(outpost_service_build_allowed(builder, get_turf(home_b.management_console)), "The build guard reached outside the service rooms")
	var/obj/item/stack/sheet/iron/iron = allocate(/obj/item/stack/sheet/iron, room_tile, 50)
	var/datum/stack_recipe/girder_recipe
	for(var/datum/stack_recipe/recipe in iron.recipes)
		if(ispath(recipe.result_type, /obj/structure/girder))
			girder_recipe = recipe
			break
	TEST_ASSERT_NOTNULL(girder_recipe, "Iron has no girder recipe")
	TEST_ASSERT(!iron.building_checks(builder, girder_recipe, 1), "A visitor passed the girder checks in a service room")
	var/obj/structure/disposalconstruct/disposal = allocate(/obj/structure/disposalconstruct, room_tile)
	disposal.set_anchored(FALSE)
	var/obj/item/wrench/wrench = allocate(/obj/item/wrench)
	builder.put_in_hands(wrench)
	disposal.wrench_act(builder, wrench)
	TEST_ASSERT(!disposal.anchored, "A visitor bolted a disposal part down in a service room")
	network_test_cleanup(rig)
