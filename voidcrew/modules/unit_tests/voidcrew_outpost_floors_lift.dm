/**
 * Outpost floors (voidcrew/modules/trade_floors/): tests of package P2, the lift and who may come up.
 * Owner: P2. Subtype /datum/unit_test/voidcrew_outpost_floors and use the helpers in
 * voidcrew_outpost_floors_helpers.dm (P0, frozen). Fork defines are included after the tests: write the literal
 * value with a comment naming the define. Pin other packages' outputs directly and never wait for an AI walk.
 *
 * A floor's own people are whoever floor.is_member() says (P1: the host's owner, its residents and the owner's
 * crew), so a member here is a resident of a host that has an owner. Nobody in these tests has a key.
 * world.time does not move inside a test, and the lift keeps "who was aboard" for one departure by its time
 * (lift_escort_cache), so a test that asks twice clears it in between.
 */

/// Parent of the lift tests. It never runs. A lobby car, panels and riders for the tests below.
/datum/unit_test/voidcrew_outpost_floors/lift
	abstract_type = /datum/unit_test/voidcrew_outpost_floors/lift
	/// Minds put on a crew by hand, taken off again afterwards
	var/list/datum/mind/crewed = list()
	/// The ship whose crew lift_cast() put on the guest list
	var/obj/structure/overmap/ship/guest_ship
	/// What a floor said of its last arrival: list(riders, rider, forced)
	var/list/heard

/datum/unit_test/voidcrew_outpost_floors/lift/Destroy()
	for(var/datum/mind/mind in crewed)
		mind.ship_teams = null
	crewed.Cut()
	guest_ship = null
	heard = null
	return ..()

/// A leased floor of `outpost` with its host, whose owner is nobody in the test
/datum/unit_test/voidcrew_outpost_floors/lift/proc/lift_floor(obj/structure/overmap/trader_outpost/outpost, number = 1)
	var/datum/outpost_floor/floor = test_floor(outpost, number, 14, 12, TRUE)
	if(!floor)
		return null
	floor.host.founder_ckey = "floorsliftowner[number]"
	return floor

/// A player: a body with a mind
/datum/unit_test/voidcrew_outpost_floors/lift/proc/lift_player(turf/where)
	var/mob/living/carbon/human/consistent/player = allocate(/mob/living/carbon/human/consistent, where)
	player.mind_initialize()
	return player

/// Gives `outpost` a concourse car of three tiles in the test room, and its panel
/datum/unit_test/voidcrew_outpost_floors/lift/proc/lift_lobby(obj/structure/overmap/trader_outpost/outpost)
	var/turf/first = run_loc_floor_top_right
	var/turf/second = get_step(first, WEST)
	var/turf/third = get_step(second, WEST)
	if(!isfloorturf(second) || !isfloorturf(third))
		TEST_FAIL("The test room is too small for a lift car")
	outpost.lobby_alcove_turfs = list(first, second, third)
	var/obj/machinery/outpost_elevator/panel = allocate(/obj/machinery/outpost_elevator, first)
	panel.outpost = outpost
	panel.is_lobby = TRUE
	outpost.lobby_panels += panel
	return panel

/// The panel in `floor`'s own alcove
/datum/unit_test/voidcrew_outpost_floors/lift/proc/lift_floor_panel(obj/structure/overmap/trader_outpost/outpost, datum/outpost_floor/floor)
	var/obj/machinery/outpost_elevator/panel = allocate(/obj/machinery/outpost_elevator, floor.alcove_turfs[1])
	panel.outpost = outpost
	panel.floor = floor
	floor.panel = panel
	return panel

/// A ship with a crew
/datum/unit_test/voidcrew_outpost_floors/lift/proc/lift_ship()
	var/obj/structure/overmap/ship/ship = allocate(/obj/structure/overmap/ship)
	ship.ship_team = new /datum/team/voidcrew
	return ship

/// Puts `person` on `ship`'s crew
/datum/unit_test/voidcrew_outpost_floors/lift/proc/lift_join(mob/living/person, obj/structure/overmap/ship/ship)
	LAZYADD(person.mind.ship_teams, ship.ship_team)
	crewed |= person.mind

/**
 * One rider of each kind for `floor`, all standing at `where`, by name: its "member", a "guest", someone on a
 * "listed crew" (their ship is on the guest list, as `guest_ship`), a "hand", a "stranger" and someone "barred".
 */
/datum/unit_test/voidcrew_outpost_floors/lift/proc/lift_cast(datum/outpost_floor/floor, turf/where)
	var/list/cast = list()
	for(var/role in list("member", "guest", "listed crew", "hand", "stranger", "barred"))
		cast[role] = lift_player(where)
	var/mob/living/member = cast["member"]
	floor.host.residents |= member.mind
	var/mob/living/guest = cast["guest"]
	floor.guests += guest.mind
	guest_ship = lift_ship()
	lift_join(cast["listed crew"], guest_ship)
	floor.guests += guest_ship
	var/mob/living/hand = cast["hand"]
	floor.hands += hand.mind
	var/mob/living/barred = cast["barred"]
	floor.barred += barred.mind
	return cast

/// The row of the lift's list that `user` is sent for `floor_id`, or null
/datum/unit_test/voidcrew_outpost_floors/lift/proc/lift_row_for(obj/structure/overmap/trader_outpost/outpost, mob/user, floor_id)
	for(var/list/row as anything in outpost.extra_floor_rows(user))
		if(row["id"] == floor_id)
			return row
	return null

/// COMSIG_OUTPOST_FLOOR_ENTERED
/datum/unit_test/voidcrew_outpost_floors/lift/proc/note_arrival(datum/source, list/riders, mob/rider, forced)
	SIGNAL_HANDLER
	heard = list(riders, rider, forced)

// ===== WHO MAY COME UP =====

/// Each setting against a member, a guest, a listed crew, a hand, a stranger and a barred rider (spec 5.1)
/datum/unit_test/voidcrew_outpost_floors/lift/settings

/datum/unit_test/voidcrew_outpost_floors/lift/settings/Run()
	var/obj/structure/overmap/trader_outpost/outpost = test_outpost()
	var/datum/outpost_floor/floor = lift_floor(outpost, 1)
	if(!floor)
		return
	lift_lobby(outpost)
	var/list/cast = lift_cast(floor, outpost.lobby_alcove_turfs[1])
	// OUTPOST_FLOOR_ENTRY_CREW, OUTPOST_FLOOR_ENTRY_INVITED, OUTPOST_FLOOR_ENTRY_OPEN
	var/list/welcome_by_setting = list(
		"crew" = list("member", "hand"),
		"invited" = list("member", "hand", "guest", "listed crew"),
		"open" = list("member", "hand", "guest", "listed crew", "stranger"),
	)
	for(var/setting in welcome_by_setting)
		floor.entry_policy = setting
		var/list/welcome = welcome_by_setting[setting]
		for(var/role in cast)
			var/mob/living/rider = cast[role]
			var/want = (role in welcome)
			TEST_ASSERT_EQUAL(!!floor.may_visit(rider), want, "On a floor set '[setting]' the [role] [want ? "may not" : "may"] come up")
			// 101 is OUTPOST_FLOOR_ID_BASE + 1
			TEST_ASSERT_EQUAL(!!outpost.may_enter_floor(101, rider), want, "The lift [want ? "refuses" : "takes"] the [role] to a floor set '[setting]'")

	// Barring wins over the guest list and a hand's place, and never over the floor's own people
	floor.entry_policy = "open"
	var/mob/living/guest = cast["guest"]
	floor.barred += guest.mind
	TEST_ASSERT(!floor.may_visit(guest), "A barred guest rides up to an Open floor")
	floor.barred -= guest.mind
	var/mob/living/hand = cast["hand"]
	floor.barred += hand.mind
	TEST_ASSERT(!floor.may_visit(hand), "A barred hand rides up")
	floor.barred -= hand.mind
	var/mob/living/member = cast["member"]
	floor.barred += member.mind
	TEST_ASSERT(floor.may_visit(member), "One of the floor's own people was barred from it")
	floor.barred -= member.mind

	// A crew entry covers whoever is on that ship's crew at the time
	var/mob/living/shipmate = cast["listed crew"]
	TEST_ASSERT(floor.is_guest(shipmate) && !floor.is_barred(shipmate), "A listed crew's member is not a guest")
	floor.guests -= guest_ship
	floor.barred += guest_ship
	TEST_ASSERT(floor.is_barred(shipmate) && !floor.is_guest(shipmate), "A barred crew's member is not barred")
	TEST_ASSERT(!floor.may_visit(shipmate), "A barred crew's member rides up to an Open floor")
	shipmate.mind.ship_teams = null
	TEST_ASSERT(floor.may_visit(shipmate), "Someone who left a barred crew is still barred with it")

	// Only a floor that has been let is on the lift; one its owner gave up is anyone's to come and take
	var/mob/living/stranger = cast["stranger"]
	var/mob/living/barred = cast["barred"]
	floor.entry_policy = "crew"
	floor.state = "vacant" // OUTPOST_FLOOR_STATE_VACANT
	TEST_ASSERT(floor.may_visit(stranger) && floor.may_visit(barred), "A floor its owner gave up cannot be reached to take it")
	for(var/unlet in list("letting", "tenant")) // OUTPOST_FLOOR_STATE_LETTING, OUTPOST_FLOOR_STATE_TENANT
		floor.state = unlet
		TEST_ASSERT(!floor.may_visit(member), "The lift goes up to a floor that is '[unlet]'")
		TEST_ASSERT_NULL(outpost.get_floor_alcove(101), "A floor that is '[unlet]' has a lift alcove")
	floor.state = "owned" // OUTPOST_FLOOR_STATE_OWNED
	TEST_ASSERT(!outpost.may_enter_floor(101, null), "The car goes up with nobody in it who sent it")
	TEST_ASSERT(!outpost.may_enter_floor(104, member), "The car goes up to a floor that is not there")

/// The rows each kind of rider is sent, by setting: only floors they may visit, their own first (spec 5.2)
/datum/unit_test/voidcrew_outpost_floors/lift/rows

/datum/unit_test/voidcrew_outpost_floors/lift/rows/Run()
	var/obj/structure/overmap/trader_outpost/outpost = test_outpost()
	var/datum/outpost_floor/floor = lift_floor(outpost, 1)
	var/datum/outpost_floor/home = lift_floor(outpost, 3)
	if(!floor || !home)
		return
	// Floor 2 is still a tenant's: it has no ground and is never on the lift
	var/datum/outpost_floor/tenant = new(outpost, 2)
	made_floors += tenant
	outpost.floors[2] = tenant
	var/obj/machinery/outpost_elevator/lobby = lift_lobby(outpost)
	var/list/cast = lift_cast(floor, outpost.lobby_alcove_turfs[1])
	floor.floor_name = "The Rusty Anchor"

	// The mark each rider's list gives floor 1; no entry is no row
	var/list/marks_by_setting = list(
		"crew" = list("member" = "yours", "hand" = "private"),
		"invited" = list("member" = "yours", "hand" = "private", "guest" = "private", "listed crew" = "private"),
		"open" = list("member" = "yours", "hand" = "open", "guest" = "open", "listed crew" = "open", "stranger" = "open"),
	)
	for(var/setting in marks_by_setting)
		floor.entry_policy = setting
		var/list/marks = marks_by_setting[setting]
		for(var/role in cast)
			var/list/row = lift_row_for(outpost, cast[role], 101) // OUTPOST_FLOOR_ID_BASE + 1
			var/want = marks[role]
			if(isnull(want))
				TEST_ASSERT_NULL(row, "The lift lists a floor set '[setting]' to the [role]")
				continue
			TEST_ASSERT_NOTNULL(row, "The lift does not list a floor set '[setting]' to the [role]")
			TEST_ASSERT_EQUAL(row["mark"], want, "A floor set '[setting]' is marked wrongly for the [role]")
			TEST_ASSERT_EQUAL(!!row["your_ship"], role == "member", "A floor set '[setting]' is [role == "member" ? "not " : ""]the [role]'s own")
		TEST_ASSERT_NULL(lift_row_for(outpost, cast["member"], 102), "A tenant's floor is on the lift")

	// What a row carries (build plan, OutpostElevator)
	floor.entry_policy = "open"
	var/mob/living/stranger = cast["stranger"]
	var/list/sent = lift_row_for(outpost, stranger, 101)
	TEST_ASSERT_NOTNULL(sent, "An Open floor is not on a stranger's lift")
	TEST_ASSERT_EQUAL(sent["kind"], "floor", "A floor's row is not marked as a floor")
	TEST_ASSERT_EQUAL(sent["name"], "The Rusty Anchor", "A floor's row does not carry its name")
	TEST_ASSERT(sent["occupied"], "A floor that can be ridden to reads as empty")
	TEST_ASSERT_EQUAL(sent["accent"], floor.accent_colour(), "A floor's row does not carry its colour")
	TEST_ASSERT(istext(sent["crew"]) && length_char(sent["crew"]) <= 40, "A floor's crew line is not bounded text")
	TEST_ASSERT(!("locked" in sent), "A floor's row says whether it is locked: one the rider may not visit is never sent")
	var/long_name = ""
	for(var/i in 1 to 60)
		long_name += "W"
	floor.floor_name = long_name
	sent = lift_row_for(outpost, stranger, 101)
	TEST_ASSERT_EQUAL(length_char(sent["name"]), 40, "A long floor name is sent whole")
	floor.floor_name = null
	sent = lift_row_for(outpost, stranger, 101)
	TEST_ASSERT_EQUAL(sent["name"], "Floor 1", "A floor with no name has no row name")

	// A rider's own floor comes first, whatever its number
	var/mob/living/dweller = lift_player(run_loc_floor_bottom_left)
	home.host.residents |= dweller.mind
	var/list/rows = outpost.extra_floor_rows(dweller)
	TEST_ASSERT_EQUAL(length(rows), 2, "A rider with a floor of their own and an Open one to visit is not sent two rows")
	var/list/first_row = rows[1]
	var/list/second_row = rows[2]
	TEST_ASSERT(first_row["id"] == 103 && first_row["mark"] == "yours" && first_row["your_ship"], "A rider's own floor is not first on the lift")
	TEST_ASSERT_EQUAL(second_row["id"], 101, "The Open floor is not after the rider's own")
	// The window gets them after the concourse and the berths
	var/list/data = lobby.ui_data(dweller)
	var/list/window_rows = data["floors"]
	var/list/top_row = window_rows[1]
	var/list/last_row = window_rows[length(window_rows)]
	TEST_ASSERT_EQUAL(top_row["id"], 0, "The concourse is not the lift's first row")
	TEST_ASSERT_EQUAL(last_row["id"], 101, "The floors are not the lift's last rows")

	// Whoever is standing on a floor is told where they are, even one they could not have come up to alone
	floor.entry_policy = "crew"
	TEST_ASSERT_NULL(lift_row_for(outpost, stranger, 101), "A Crew only floor is listed to a stranger downstairs")
	stranger.forceMove(deck_tile(floor))
	sent = lift_row_for(outpost, stranger, 101)
	TEST_ASSERT_NOTNULL(sent, "A rider on a floor is not sent the floor they stand on")
	TEST_ASSERT_EQUAL(sent["mark"], "private", "A Crew only floor is not marked private to a visitor")

	// A floor its owner gave up is listed to anyone, and is nobody's and not private
	floor.state = "vacant" // OUTPOST_FLOOR_STATE_VACANT
	sent = lift_row_for(outpost, cast["barred"], 101)
	TEST_ASSERT_NOTNULL(sent, "A floor its owner gave up is not on the lift")
	TEST_ASSERT_EQUAL(sent["crew"], "Vacant", "A floor its owner gave up still reads as someone's")
	TEST_ASSERT(!("mark" in sent), "A floor its owner gave up carries a mark")

// ===== PASSES =====

/// A pass lets one person up for a while, runs out, loses to a bar, and the list is capped
/datum/unit_test/voidcrew_outpost_floors/lift/pass

/datum/unit_test/voidcrew_outpost_floors/lift/pass/Run()
	var/obj/structure/overmap/trader_outpost/outpost = test_outpost()
	var/datum/outpost_floor/floor = lift_floor(outpost, 1)
	if(!floor)
		return
	var/mob/living/courier = lift_player(run_loc_floor_bottom_left)
	TEST_ASSERT(!floor.may_visit(courier), "A stranger rides up to a Crew only floor")
	TEST_ASSERT(!floor.grant_pass(null, 5 MINUTES), "A pass was given to nobody")
	TEST_ASSERT(!floor.grant_pass(courier.mind, 0), "A pass was given for no time")
	TEST_ASSERT(!floor.grant_pass(courier.mind, -5 MINUTES), "A pass was given for less than no time")
	TEST_ASSERT(!floor.may_visit(courier), "A refused pass lets its holder up")

	TEST_ASSERT(floor.grant_pass(courier.mind, 5 MINUTES), "A pass was refused")
	TEST_ASSERT(floor.may_visit(courier), "A pass does not let its holder up to a Crew only floor")
	TEST_ASSERT(outpost.may_enter_floor(101, courier), "The lift refuses a pass") // OUTPOST_FLOOR_ID_BASE + 1
	TEST_ASSERT_NOTNULL(lift_row_for(outpost, courier, 101), "The lift does not list the floor to a pass holder")
	floor.barred += courier.mind
	TEST_ASSERT(!floor.may_visit(courier), "A pass lets a barred rider up")
	floor.barred -= courier.mind

	// It runs out
	floor.lift_passes[WEAKREF(courier.mind)] = world.time - 1
	TEST_ASSERT(!floor.may_visit(courier), "A pass that has run out still lets its holder up")
	TEST_ASSERT_NULL(lift_row_for(outpost, courier, 101), "The lift lists the floor to a pass that has run out")

	// Thirty at most (OUTPOST_FLOOR_LIST_MAX); a pass that has run out gives up its place, and a holder renews theirs
	floor.lift_passes = null
	var/datum/mind/first_holder
	for(var/i in 1 to 30)
		var/datum/mind/holder = allocate(/datum/mind, "floorsliftpass[i]")
		first_holder ||= holder
		TEST_ASSERT(floor.grant_pass(holder, 5 MINUTES), "Pass [i] of thirty was refused")
	var/datum/mind/late = allocate(/datum/mind, "floorsliftpasslate")
	TEST_ASSERT(!floor.grant_pass(late, 5 MINUTES), "A thirty-first pass was given")
	TEST_ASSERT(floor.grant_pass(first_holder, 10 MINUTES), "A holder could not renew their pass with the list full")
	TEST_ASSERT_EQUAL(length(floor.lift_passes), 30, "Renewing a pass added one")
	floor.lift_passes[WEAKREF(first_holder)] = world.time - 1
	TEST_ASSERT(floor.grant_pass(late, 5 MINUTES), "A pass that has run out still holds its place")
	TEST_ASSERT_EQUAL(length(floor.lift_passes), 30, "The pass list is not thirty after one ran out and one was given")

// ===== A FORCED PANEL =====

/// An emag opens every floor from that car for three minutes, cannot be repeated for five more (A30), and gives no standing right
/datum/unit_test/voidcrew_outpost_floors/lift/forced

/datum/unit_test/voidcrew_outpost_floors/lift/forced/Run()
	var/obj/structure/overmap/trader_outpost/outpost = test_outpost()
	var/obj/machinery/outpost_elevator/lobby = lift_lobby(outpost)
	var/list/turf/car = outpost.lobby_alcove_turfs
	var/mob/living/burglar = lift_player(car[2])
	TEST_ASSERT(!outpost.on_lift_emagged(lobby, burglar), "A lift with no leased floor above it was forced")
	TEST_ASSERT_EQUAL(lobby.forced_until, 0, "A refused emag opened a window")

	var/datum/outpost_floor/floor = lift_floor(outpost, 1)
	var/datum/outpost_floor/other = lift_floor(outpost, 2)
	if(!floor || !other)
		return
	var/datum/outpost_floor/tenant = new(outpost, 3)
	made_floors += tenant
	outpost.floors.len = 3
	outpost.floors[3] = tenant
	var/mob/living/bystander = lift_player(run_loc_floor_bottom_left)
	TEST_ASSERT(get_dist(bystander, lobby) > 1 && !(get_turf(bystander) in car), "The test room is too small to stand clear of the panel")
	// 101 to 103 are OUTPOST_FLOOR_ID_BASE + the floor's number
	TEST_ASSERT(!outpost.may_enter_floor(101, burglar), "A stranger rides up to a Crew only floor")
	TEST_ASSERT(!outpost.on_lift_emagged(null, burglar), "An emag on no panel did something")

	TEST_ASSERT(lobby.emag_act(burglar), "An emag did nothing to a lift panel")
	TEST_ASSERT_EQUAL(lobby.forced_until, world.time + 3 MINUTES, "A forced panel does not stay open for OUTPOST_FLOOR_LIFT_EMAG_TIME")
	TEST_ASSERT_EQUAL(lobby.force_ready_at, world.time + 8 MINUTES, "A forced panel is not safe for OUTPOST_FLOOR_LIFT_EMAG_COOLDOWN after its window")
	TEST_ASSERT(outpost.may_enter_floor(101, burglar) && outpost.may_enter_floor(102, burglar), "A forced panel does not open every leased floor")
	TEST_ASSERT(!outpost.may_enter_floor(103, burglar), "A forced panel opens a tenant's floor")
	TEST_ASSERT(!floor.may_visit(burglar), "A forced panel gave its rider a standing right to the floor")
	TEST_ASSERT_EQUAL(length(outpost.extra_floor_rows(burglar)), 2, "A forced panel does not list the two leased floors and no other")
	TEST_ASSERT(!outpost.may_enter_floor(101, bystander), "A forced panel opens the floors to someone who is not in its car")
	TEST_ASSERT_EQUAL(length(outpost.extra_floor_rows(bystander)), 0, "A forced panel lists the floors to someone who is not at it")

	// A second emag does nothing and does not restart the window (A30)
	var/window_end = lobby.forced_until
	TEST_ASSERT(!lobby.emag_act(burglar), "A second emag did something to a panel already forced")
	TEST_ASSERT_EQUAL(lobby.forced_until, window_end, "A second emag restarted a forced panel's window")

	// A forced lock is a forced lock: it takes a barred rider up too
	floor.barred += burglar.mind
	TEST_ASSERT(outpost.may_enter_floor(101, burglar), "A forced panel refuses a barred rider")
	TEST_ASSERT(!outpost.lift_leaves_behind(burglar, 101, burglar), "A forced car left a barred rider behind")
	floor.barred -= burglar.mind
	floor.lift_escort_cache = null

	// The window ends, and the panel cannot be forced again until its cooldown is over
	lobby.forced_until = world.time - 1
	TEST_ASSERT(!outpost.may_enter_floor(101, burglar), "A panel stays forced after its window")
	TEST_ASSERT_EQUAL(length(outpost.extra_floor_rows(burglar)), 0, "A panel lists every floor after its window")
	TEST_ASSERT(!lobby.emag_act(burglar), "A panel was forced again inside its cooldown")
	TEST_ASSERT(lobby.forced_until < world.time, "A refused emag opened a window")
	lobby.force_ready_at = world.time - 1
	TEST_ASSERT(lobby.emag_act(burglar), "A panel cannot be forced again after its cooldown")
	lobby.forced_until = world.time - 1
	var/lobby_ready_at = lobby.force_ready_at

	// A floor's own panel is a lift panel like any other, with a lock and a cooldown of its own
	var/obj/machinery/outpost_elevator/upstairs = lift_floor_panel(outpost, floor)
	burglar.forceMove(floor.alcove_turfs[2])
	TEST_ASSERT(!outpost.may_enter_floor(102, burglar), "A stranger rides from one Crew only floor to another")
	TEST_ASSERT(upstairs.emag_act(burglar), "A floor's own panel cannot be forced")
	TEST_ASSERT(outpost.may_enter_floor(102, burglar), "A forced panel on a floor does not open the other floors")
	TEST_ASSERT_EQUAL(lobby.force_ready_at, lobby_ready_at, "Forcing one panel changed another's cooldown")

// ===== WHO THE CAR LEAVES =====

/// A wing's prisoners never ride (A22); a barred rider rides only with one of the floor's people; anyone rides down
/datum/unit_test/voidcrew_outpost_floors/lift/left_behind

/datum/unit_test/voidcrew_outpost_floors/lift/left_behind/Run()
	var/obj/structure/overmap/trader_outpost/outpost = test_outpost()
	var/datum/outpost_floor/floor = lift_floor(outpost, 1)
	if(!floor)
		return
	var/obj/machinery/outpost_elevator/lobby = lift_lobby(outpost)
	var/list/turf/car = outpost.lobby_alcove_turfs
	var/turf/outside = run_loc_floor_bottom_left
	var/mob/living/member = lift_player(car[1])
	floor.host.residents |= member.mind
	var/mob/living/visitor = lift_player(car[2])
	floor.guests += visitor.mind
	floor.entry_policy = "invited" // OUTPOST_FLOOR_ENTRY_INVITED
	var/mob/living/unwelcome = lift_player(car[3])
	floor.barred += unwelcome.mind
	var/mob/living/carbon/human/npc/outpost_prisoner/prisoner = allocate(/mob/living/carbon/human/npc/outpost_prisoner, car[2])

	// A22: up, down or across, on their feet or shut in something. 101 is OUTPOST_FLOOR_ID_BASE + 1.
	for(var/to_floor in list(0, 1, 101))
		TEST_ASSERT(outpost.lift_leaves_behind(prisoner, to_floor, member), "The lift takes a prisoner to floor [to_floor]")
	var/obj/structure/closet/locker = allocate(/obj/structure/closet, car[3])
	TEST_ASSERT(!outpost.lift_leaves_behind(locker, 0, member), "The lift leaves an empty locker behind")
	prisoner.forceMove(locker)
	TEST_ASSERT(outpost.lift_leaves_behind(locker, 0, member), "A prisoner shut in a locker rides the lift")
	prisoner.forceMove(car[2])
	TEST_ASSERT(!outpost.lift_leaves_behind(visitor, 101, member), "Someone riding along with one of the floor's people was left behind")
	TEST_ASSERT(!outpost.lift_leaves_behind(member, 101, member), "The lift leaves its own sender behind")

	// Barred: up with one of the floor's people in the car, awake, and not otherwise. Never kept from going down.
	floor.lift_escort_cache = null
	TEST_ASSERT(!outpost.lift_leaves_behind(unwelcome, 101, member), "A barred rider with one of the floor's people in the car was left behind")
	member.forceMove(outside)
	floor.lift_escort_cache = null
	TEST_ASSERT(outpost.lift_leaves_behind(unwelcome, 101, visitor), "A barred rider went up with none of the floor's people in the car")
	member.forceMove(car[1])
	member.set_stat(UNCONSCIOUS)
	floor.lift_escort_cache = null
	TEST_ASSERT(outpost.lift_leaves_behind(unwelcome, 101, visitor), "A barred rider went up beside one of the floor's people who was out cold")
	member.set_stat(CONSCIOUS)
	TEST_ASSERT(!outpost.lift_leaves_behind(unwelcome, 0, visitor), "A barred rider is kept from riding down")
	TEST_ASSERT(!outpost.lift_leaves_behind(unwelcome, 1, visitor), "A barred rider is kept from a berth")

	// A guest sends the car with none of the floor's people in it: the guest arrives, the barred rider and the prisoner stay
	member.forceMove(outside)
	floor.lift_escort_cache = null
	lobby.complete_ride(101, WEAKREF(visitor))
	TEST_ASSERT(get_turf(visitor) in floor.alcove_turfs, "A guest did not reach an Invited floor")
	TEST_ASSERT(get_turf(unwelcome) in car, "A barred rider reached the floor in a guest's car")
	TEST_ASSERT(get_turf(prisoner) in car, "A prisoner rode up")

	// One of the floor's people sends it from the car's first tile, so they have moved before the barred rider on its
	// last tile is looked at: who was aboard is read before anyone moves
	member.forceMove(car[1])
	floor.lift_escort_cache = null
	lobby.complete_ride(101, WEAKREF(member))
	TEST_ASSERT(get_turf(member) in floor.alcove_turfs, "One of the floor's people did not reach their floor")
	TEST_ASSERT(get_turf(unwelcome) in floor.alcove_turfs, "A barred rider in the car with one of the floor's people was left behind")
	TEST_ASSERT(get_turf(prisoner) in car, "A prisoner rode up with one of the floor's people")

	// Riding down: anyone, whoever sent the car and even if they have gone; a prisoner in the car stays upstairs
	var/obj/machinery/outpost_elevator/upstairs = lift_floor_panel(outpost, floor)
	TEST_ASSERT(upstairs.may_ride_to(0, unwelcome), "A rider on a floor cannot go down to the concourse")
	TEST_ASSERT(upstairs.may_ride_to(0, null), "The car does not go down once its sender has stepped out")
	prisoner.forceMove(floor.alcove_turfs[2])
	upstairs.complete_ride(0, WEAKREF(unwelcome))
	TEST_ASSERT(get_turf(unwelcome) in car, "A barred rider could not ride down")
	TEST_ASSERT((get_turf(member) in car) && (get_turf(visitor) in car), "Those in the car did not ride down with it")
	TEST_ASSERT(get_turf(prisoner) in floor.alcove_turfs, "A prisoner rode down to the concourse")

// ===== CARRIED UP =====

/// Who counts as carried up with no say in it (A17), and what the floor is told of an arrival
/datum/unit_test/voidcrew_outpost_floors/lift/abduction

/datum/unit_test/voidcrew_outpost_floors/lift/abduction/Run()
	var/obj/structure/overmap/trader_outpost/outpost = test_outpost()
	var/datum/outpost_floor/floor = lift_floor(outpost, 1)
	if(!floor)
		return
	var/obj/machinery/outpost_elevator/lobby = lift_lobby(outpost)
	var/list/turf/car = outpost.lobby_alcove_turfs
	var/mob/living/carbon/human/captor = lift_player(car[1])
	floor.host.residents |= captor.mind
	var/mob/living/carbon/human/victim = lift_player(car[2])
	var/list/people = list(captor, victim)
	TEST_ASSERT_EQUAL(length(floor.lift_abducted(people, captor)), 0, "A stranger on their feet, riding along, was carried off")

	var/obj/item/restraints/handcuffs/cuffs = new(victim)
	victim.set_handcuffed(cuffs)
	TEST_ASSERT(HAS_TRAIT(victim, TRAIT_RESTRAINED), "The test's cuffs do not restrain")
	var/list/taken = floor.lift_abducted(people, captor)
	TEST_ASSERT(length(taken) == 1 && taken[1] == victim, "Riding up to a Crew only floor with a cuffed stranger carries nobody off")
	TEST_ASSERT_EQUAL(length(floor.lift_abducted(people, null)), 0, "A car nobody sent carried someone off")

	// Not on the sender's crew
	var/obj/structure/overmap/ship/ship = lift_ship()
	lift_join(captor, ship)
	lift_join(victim, ship)
	TEST_ASSERT_EQUAL(length(floor.lift_abducted(people, captor)), 0, "Taking a cuffed crewmate up is carrying them off")
	victim.mind.ship_teams = null

	// Someone who could have come up alone
	floor.entry_policy = "open" // OUTPOST_FLOOR_ENTRY_OPEN
	TEST_ASSERT_EQUAL(length(floor.lift_abducted(people, captor)), 0, "Taking a cuffed visitor up to an Open floor is carrying them off")
	floor.entry_policy = "invited" // OUTPOST_FLOOR_ENTRY_INVITED
	TEST_ASSERT_EQUAL(length(floor.lift_abducted(people, captor)), 1, "Taking a cuffed stranger up to an Invited floor carries nobody off")
	floor.guests += victim.mind
	TEST_ASSERT_EQUAL(length(floor.lift_abducted(people, captor)), 0, "Taking a cuffed guest up is carrying them off")
	floor.guests -= victim.mind
	floor.entry_policy = "crew" // OUTPOST_FLOOR_ENTRY_CREW

	// Out cold counts as cuffed does; the dead do not
	victim.set_handcuffed(null)
	qdel(cuffs)
	TEST_ASSERT_EQUAL(length(floor.lift_abducted(people, captor)), 0, "A stranger out of their cuffs was carried off")
	victim.set_stat(UNCONSCIOUS)
	TEST_ASSERT_EQUAL(length(floor.lift_abducted(people, captor)), 1, "Riding up with a stranger who is out cold carries nobody off")
	victim.set_stat(CONSCIOUS)
	victim.death()
	TEST_ASSERT_EQUAL(length(floor.lift_abducted(people, captor)), 0, "A body taken up was carried off")

	// An NPC in cuffs is a bounty on its way to the wing
	var/mob/living/carbon/human/bounty = test_person(car[3])
	bounty.set_handcuffed(new /obj/item/restraints/handcuffs(bounty))
	TEST_ASSERT_EQUAL(length(floor.lift_abducted(list(captor, bounty), captor)), 0, "Taking a cuffed NPC up is carrying them off")

	// Someone shut in a locker is in the car too
	var/obj/structure/closet/locker = allocate(/obj/structure/closet, car[3])
	var/mob/living/carbon/human/stowed = lift_player(car[3])
	stowed.forceMove(locker)
	TEST_ASSERT(stowed in outpost.lift_people_in(locker), "Someone shut in a locker is not counted as in the car")

	// Someone strapped to a bed is counted with the bed, so a prisoner on one keeps it down
	var/obj/structure/bed/bed = allocate(/obj/structure/bed, car[2])
	var/mob/living/carbon/human/npc/outpost_prisoner/prisoner = allocate(/mob/living/carbon/human/npc/outpost_prisoner, car[2])
	TEST_ASSERT(!outpost.lift_leaves_behind(bed, 0, captor), "The lift leaves an empty bed behind")
	TEST_ASSERT(bed.buckle_mob(prisoner, TRUE), "The test's prisoner could not be strapped to a bed")
	TEST_ASSERT(outpost.lift_leaves_behind(bed, 0, captor), "A bed with a prisoner strapped to it rides the lift")
	bed.unbuckle_mob(prisoner, TRUE)

	// What the floor hears of an arrival ("outpost_floor_entered" is COMSIG_OUTPOST_FLOOR_ENTERED): the car has set
	// its riders down by then, and someone it left downstairs is not among them
	RegisterSignal(floor, "outpost_floor_entered", PROC_REF(note_arrival))
	captor.forceMove(floor.alcove_turfs[1])
	locker.forceMove(floor.alcove_turfs[2])
	var/mob/living/carbon/human/left_below = lift_player(car[1])
	outpost.on_lift_ride(lobby, 101, captor, list(captor, locker, left_below)) // OUTPOST_FLOOR_ID_BASE + 1
	TEST_ASSERT(islist(heard), "A floor is not told of an arrival")
	var/list/riders = heard[1]
	TEST_ASSERT((captor in riders) && (stowed in riders), "A floor is not told everyone who rode up")
	TEST_ASSERT(!(left_below in riders), "A floor is told of someone the car left downstairs")
	TEST_ASSERT_EQUAL(heard[2], captor, "A floor is not told who sent the car")
	TEST_ASSERT(!heard[3], "One of the floor's own people coming home reads as a forced lock")
	heard = null
	var/mob/living/carbon/human/burglar = lift_player(floor.alcove_turfs[3])
	outpost.on_lift_ride(lobby, 101, burglar, list(burglar))
	TEST_ASSERT(islist(heard) && heard[3], "A rider with no right to come up does not read as a forced lock")
	heard = null
	outpost.on_lift_ride(lobby, 0, captor, list(captor))
	TEST_ASSERT_NULL(heard, "A floor is told of a ride down to the concourse")
	UnregisterSignal(floor, "outpost_floor_entered")

// ===== THE SETTING =====

/// Who may set it, that the lift follows at once, and what the lift says when it will not go
/datum/unit_test/voidcrew_outpost_floors/lift/setting

/datum/unit_test/voidcrew_outpost_floors/lift/setting/Run()
	var/obj/structure/overmap/trader_outpost/outpost = test_outpost()
	var/datum/outpost_floor/floor = lift_floor(outpost, 1)
	var/datum/outpost_floor/bare = test_floor(outpost, 2)
	if(!floor || !bare)
		return
	var/obj/machinery/outpost_elevator/lobby = lift_lobby(outpost)
	var/list/turf/car = outpost.lobby_alcove_turfs
	var/mob/living/steward = lift_player(run_loc_floor_bottom_left)
	floor.host.stewards += steward.mind
	var/mob/living/visitor = lift_player(car[1])

	// "crew", "invited" and "open" are OUTPOST_FLOOR_ENTRY_CREW, _INVITED and _OPEN
	TEST_ASSERT(!floor.set_entry("open", visitor), "A visitor changed who the lift takes up")
	TEST_ASSERT_EQUAL(floor.entry_policy, "crew", "A refused change still changed the setting")
	TEST_ASSERT(floor.set_entry("open", steward), "A steward could not open the floor")
	TEST_ASSERT_EQUAL(floor.entry_policy, "open", "The setting did not change")
	TEST_ASSERT(!floor.set_entry("everyone", steward), "A made-up setting was taken")
	TEST_ASSERT(floor.set_entry("open", steward), "Setting what is already set was refused")
	TEST_ASSERT(floor.set_entry("invited"), "The game itself could not change a floor's setting")
	TEST_ASSERT(!bare.set_entry("open", steward), "A floor with nobody to manage it took a player's word")

	// Wider is at once; narrower stops a car that was already called
	floor.set_entry("open", steward)
	TEST_ASSERT(lobby.may_ride_to(101, visitor), "An opened floor still refuses a stranger") // OUTPOST_FLOOR_ID_BASE + 1
	floor.set_entry("crew", steward)
	lobby.complete_ride(101, WEAKREF(visitor))
	TEST_ASSERT(get_turf(visitor) in car, "A car already called went up after the floor was closed")

	// Where the car goes, and what it says when it will not
	TEST_ASSERT_EQUAL(outpost.get_floor_alcove(101), floor.alcove_turfs, "The lift cannot reach a leased floor")
	TEST_ASSERT_NULL(outpost.get_floor_alcove(103), "A floor that is not there has a lift alcove")
	TEST_ASSERT_EQUAL(outpost.lift_refusal_text(101), "private floor!", "The lift's refusal for a floor is not the spec's")
	TEST_ASSERT_EQUAL(outpost.lift_refusal_text(101, TRUE), "Floor 1 is private.", "The panel's spoken refusal does not name the floor")
	TEST_ASSERT_EQUAL(outpost.lift_refusal_text(2), "crew only!", "The lift's refusal for a berth changed")
