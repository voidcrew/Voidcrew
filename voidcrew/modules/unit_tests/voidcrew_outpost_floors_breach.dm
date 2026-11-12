/**
 * Outpost floors (voidcrew/modules/trade_floors/): tests of package P6, breaching and the walk-through
 * (police_breach.dm).
 * Owner: P6. Subtype /datum/unit_test/voidcrew_outpost_floors and use the helpers in
 * voidcrew_outpost_floors_helpers.dm (P0, frozen). Fork defines are included after the tests: write the literal
 * value with a comment naming the define. Pin other packages' outputs directly and never wait for an AI walk.
 *
 * A test floor is 14 x 12: hull at dx/dy 0 and 13/11, deck from 1, 1 to 12, 10, the landing at dy 1 and 2. The tests
 * build a row across it at dy 6, the start below it at dy 3 and the goal above it at dy 9.
 */

/// Puts `turf_type` across `floor` at row `dy`, on top of the deck so a blast leaves the deck (P1: lay_ground first)
/datum/unit_test/voidcrew_outpost_floors/proc/breach_test_row(datum/outpost_floor/floor, dy, turf_type = /turf/closed/wall)
	floor.lay_ground(/turf/open/floor/plating/outpost_deck)
	for(var/dx in 1 to floor.bounds[3] - floor.bounds[1] - 1)
		var/turf/tile = floor_tile(floor, dx, dy)
		tile.place_on_top(turf_type)

/// A crew wall across the floor: the charge goes on the straight way through, and a cheap enough way round is taken instead
/datum/unit_test/voidcrew_outpost_floors/breach_wall

/datum/unit_test/voidcrew_outpost_floors/breach_wall/Run()
	var/obj/structure/overmap/trader_outpost/outpost = test_outpost()
	var/datum/outpost_floor/floor = test_floor(outpost)
	if(!floor)
		return
	breach_test_row(floor, 6)
	var/turf/start = floor_tile(floor, 3, 3)
	var/turf/goal = floor_tile(floor, 3, 9)
	TEST_ASSERT_EQUAL(floor.breach_target(start, goal), floor_tile(floor, 3, 6), "The charge is not on the wall on the straight way through")
	var/list/read = floor.breach_read(floor.breach_field(goal), start)
	TEST_ASSERT_EQUAL(read[1], "blocked", "A wall across the floor does not block the way")
	TEST_ASSERT_EQUAL(read[3], floor_tile(floor, 3, 5), "The charge is not set from the tile beside the wall")
	// A gap four tiles along: walking round (8 more steps) is cheaper than a charge (20, POLICE_BREACH_BLOCKED_COST)
	var/turf/gap = floor_tile(floor, 7, 6)
	gap.ScrapeAway()
	TEST_ASSERT(isopenturf(gap), "The test could not open a gap in the wall")
	TEST_ASSERT_NULL(floor.breach_target(start, goal), "A wall was breached with a short way round it")
	TEST_ASSERT_EQUAL(floor.breach_read(floor.breach_field(goal), start)[1], "open", "A way round a wall is not a clear way")

/// A welded door in a hull row is the target; the same door unwelded and powered is a way through; the hull never is
/datum/unit_test/voidcrew_outpost_floors/breach_welded_door

/datum/unit_test/voidcrew_outpost_floors/breach_welded_door/Run()
	var/obj/structure/overmap/trader_outpost/outpost = test_outpost()
	var/datum/outpost_floor/floor = test_floor(outpost)
	if(!floor)
		return
	breach_test_row(floor, 6, /turf/closed/wall/outpost_floor_hull)
	var/turf/doorway = floor_tile(floor, 9, 6)
	doorway.ChangeTurf(/turf/open/floor/plating/outpost_deck)
	var/obj/machinery/door/airlock/door = allocate(/obj/machinery/door/airlock, doorway)
	door.set_machine_stat(door.machine_stat & ~NOPOWER)
	var/turf/start = floor_tile(floor, 3, 3)
	var/turf/goal = floor_tile(floor, 3, 9)
	TEST_ASSERT(door.density, "The test door is open")
	TEST_ASSERT_NULL(floor.breach_target(start, goal), "A door that opens for an officer was breached")
	door.welded = TRUE
	TEST_ASSERT_EQUAL(floor.breach_target(start, goal), doorway, "A welded door in the only way through is not the target")
	TEST_ASSERT_EQUAL(floor.breach_tile_cost(floor_tile(floor, 3, 6)), 0, "The hull can be breached")
	door.welded = FALSE
	door.locked = TRUE
	TEST_ASSERT_EQUAL(floor.breach_target(start, goal), doorway, "A bolted door in the only way through is not the target")

/// A goal ringed by the hull has no way in and nothing to blow; the squad holds the nearest tile it reaches (A15)
/datum/unit_test/voidcrew_outpost_floors/breach_sealed_pocket

/datum/unit_test/voidcrew_outpost_floors/breach_sealed_pocket/Run()
	var/obj/structure/overmap/trader_outpost/outpost = test_outpost()
	var/datum/outpost_floor/floor = test_floor(outpost)
	if(!floor)
		return
	floor.lay_ground(/turf/open/floor/plating/outpost_deck)
	var/turf/goal = floor_tile(floor, 6, 8)
	for(var/dx in 5 to 7)
		for(var/dy in 7 to 9)
			if(dx == 6 && dy == 8)
				continue
			var/turf/ring = floor_tile(floor, dx, dy)
			ring.ChangeTurf(/turf/closed/wall/outpost_floor_hull)
	var/turf/start = floor_tile(floor, 3, 3)
	TEST_ASSERT_NULL(floor.breach_target(start, goal), "A pocket sealed by the hull has a target")
	TEST_ASSERT_EQUAL(floor.breach_read(floor.breach_field(goal), start)[1], "sealed", "A pocket sealed by the hull has a way in")
	var/turf/hold = floor.breach_hold_point(start, goal)
	TEST_ASSERT_NOTNULL(hold, "There is nowhere to hold by a sealed pocket")
	TEST_ASSERT_EQUAL(get_dist(hold, goal), 2, "The hold point is not the nearest the squad can reach")

/// A junk pile is judged on its first 20 atoms (A45) and counts as blocked
/datum/unit_test/voidcrew_outpost_floors/breach_junk_pile

/datum/unit_test/voidcrew_outpost_floors/breach_junk_pile/Run()
	var/obj/structure/overmap/trader_outpost/outpost = test_outpost()
	var/datum/outpost_floor/floor = test_floor(outpost)
	if(!floor)
		return
	breach_test_row(floor, 6, /turf/closed/wall/outpost_floor_hull)
	var/turf/pile = floor_tile(floor, 9, 6)
	pile.ChangeTurf(/turf/open/floor/plating/outpost_deck)
	for(var/i in 1 to 60)
		allocate(/obj/item/paper, pile)
	floor.breach_atoms_looked = 0
	TEST_ASSERT_EQUAL(floor.breach_tile_cost(pile), 20, "A pile past the atom bound is not blocked") // POLICE_BREACH_BLOCKED_COST
	TEST_ASSERT(floor.breach_atoms_looked <= 20, "A tile was searched past its atom bound ([floor.breach_atoms_looked] atoms)")
	var/turf/start = floor_tile(floor, 3, 3)
	var/turf/goal = floor_tile(floor, 3, 9)
	TEST_ASSERT_EQUAL(floor.breach_target(start, goal), pile, "The pile in the only way through is not the target")
	var/tiles = (floor.bounds[3] - floor.bounds[1] + 1) * (floor.bounds[4] - floor.bounds[2] + 1)
	TEST_ASSERT(floor.breach_atoms_looked <= tiles * 20, "The search looked at more than 20 atoms a tile")
	// A few things on the floor are no pile
	var/turf/litter = floor_tile(floor, 4, 4)
	for(var/i in 1 to 3)
		allocate(/obj/item/paper, litter)
	TEST_ASSERT_EQUAL(floor.breach_tile_cost(litter), 1, "A tile with a few loose things on it is blocked")

/// A charge: only under warrant, one at a time; the squad backs off; the blast clears the tile and leaves the deck
/datum/unit_test/voidcrew_outpost_floors/breach_blast

/datum/unit_test/voidcrew_outpost_floors/breach_blast/Run()
	var/obj/structure/overmap/trader_outpost/outpost = test_outpost()
	var/datum/outpost_police/police = outpost.police
	var/datum/outpost_floor/floor = test_floor(outpost)
	if(!floor)
		return
	breach_test_row(floor, 6)
	var/turf/target = floor_tile(floor, 6, 6)
	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/officer = police_test_officer(outpost, floor_tile(floor, 6, 5))
	TEST_ASSERT(!police.plant_breach(officer, target), "A charge was set with no warrant on the floor")
	floor.warrant_in_force = TRUE
	officer.forceMove(floor_tile(floor, 1, 5))
	TEST_ASSERT(!police.plant_breach(officer, floor_tile(floor, 0, 5)), "A charge was set on the hull")
	officer.forceMove(floor_tile(floor, 6, 5))
	TEST_ASSERT(police.plant_breach(officer, target), "No charge was set on a crew wall under warrant")
	var/obj/structure/outpost_breach_charge/charge = floor.breach_charge
	TEST_ASSERT(istype(charge) && get_turf(charge) == target, "The charge is not on its tile")
	TEST_ASSERT(!police.plant_breach(officer, floor_tile(floor, 7, 6)), "A second charge was set while one was live")
	var/datum/ai_controller/basic_controller/human_npc/stealth/outpost_police/brain = officer.ai_controller
	if(istype(brain))
		TEST_ASSERT(brain.breach_back_turf && get_dist(brain.breach_back_turf, target) >= 3, "The officer who set it does not back off") // POLICE_BREACH_STANDOFF
	hold_blasts()
	charge.detonate()
	apply_blast()
	TEST_ASSERT(QDELETED(charge), "The charge outlived its blast")
	TEST_ASSERT_NULL(floor.breach_charge, "The floor still has a live charge after the blast")
	TEST_ASSERT(istype(target, /turf/open/floor/plating/outpost_deck), "The blast did not leave the deck where the wall was ([target.type])")
	TEST_ASSERT(istype(floor_tile(floor, 0, 6), /turf/closed/wall/outpost_floor_hull), "The blast broke the hull")

/// A walk-through is due on an Open floor with visitors upstairs, never on an Invited or Crew only floor, nor an empty one
/datum/unit_test/voidcrew_outpost_floors/breach_walk_open_only

/datum/unit_test/voidcrew_outpost_floors/breach_walk_open_only/Run()
	var/obj/structure/overmap/trader_outpost/outpost = test_outpost()
	var/datum/outpost_police/police = outpost.police
	var/datum/outpost_floor/open = test_floor(outpost, 1)
	var/datum/outpost_floor/invited = test_floor(outpost, 2)
	var/datum/outpost_floor/crew_only = test_floor(outpost, 3)
	if(!open || !invited || !crew_only)
		return
	open.entry_policy = "open" // OUTPOST_FLOOR_ENTRY_OPEN
	open.public_ground = TRUE
	invited.entry_policy = "invited" // OUTPOST_FLOOR_ENTRY_INVITED
	crew_only.entry_policy = "crew" // OUTPOST_FLOOR_ENTRY_CREW
	var/mob/living/carbon/human/visitor = police_test_person(deck_tile(open, 4))
	for(var/datum/outpost_floor/floor as anything in list(open, invited, crew_only))
		if(floor != open)
			police_test_person(deck_tile(floor, 4))
		floor.breach_walk_due_at = 1
	TEST_ASSERT_EQUAL(police.breach_walk_due_floor(), open, "An Open floor with a visitor is not due a walk-through")
	open.entry_policy = "invited" // OUTPOST_FLOOR_ENTRY_INVITED
	TEST_ASSERT_NULL(police.breach_walk_due_floor(), "A narrowed floor, an Invited one or a Crew only one is due a walk-through")
	TEST_ASSERT_EQUAL(invited.breach_walk_due_at, 0, "An Invited floor keeps a walk-through clock")
	TEST_ASSERT_EQUAL(crew_only.breach_walk_due_at, 0, "A Crew only floor keeps a walk-through clock")
	open.entry_policy = "open" // OUTPOST_FLOOR_ENTRY_OPEN
	TEST_ASSERT_NULL(police.breach_walk_due_floor(), "A floor that has just opened is walked at once")
	TEST_ASSERT(open.breach_walk_due_at > world.time, "A floor that has just opened gets no walk-through clock")
	open.breach_walk_due_at = 1
	visitor.forceMove(floor_tile(invited, 8, 8))
	TEST_ASSERT_NULL(police.breach_walk_due_floor(), "An Open floor with nobody upstairs is due a walk-through")
	open.warrant_in_force = TRUE
	visitor.forceMove(deck_tile(open, 4))
	open.breach_walk_due_at = 1
	TEST_ASSERT_NULL(police.breach_walk_due_floor(), "A floor under warrant is due a walk-through")

/// An officer on a walk-through walks the floor while it is Open, heads home when it narrows, and is done once off it
/datum/unit_test/voidcrew_outpost_floors/breach_walk_stands_down

/datum/unit_test/voidcrew_outpost_floors/breach_walk_stands_down/Run()
	var/obj/structure/overmap/trader_outpost/outpost = test_outpost()
	var/datum/outpost_floor/floor = test_floor(outpost)
	if(!floor)
		return
	floor.entry_policy = "open" // OUTPOST_FLOOR_ENTRY_OPEN
	floor.public_ground = TRUE
	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/officer = police_test_officer(outpost, deck_tile(floor, 4))
	var/datum/ai_controller/basic_controller/human_npc/stealth/outpost_police/brain = officer.ai_controller
	TEST_ASSERT(istype(brain), "A beat officer has no police brain")
	if(!istype(brain))
		return
	brain.breach_walk_begin(floor, null)
	TEST_ASSERT_EQUAL(brain.breach_walk_review(), "loop", "An officer up on an Open floor does not walk it")
	TEST_ASSERT(length(brain.breach_walk_stops), "A walk-through has no stops")
	for(var/turf/stop as anything in brain.breach_walk_stops)
		TEST_ASSERT(floor.contains_turf(stop) && isopenturf(stop), "A walk-through stop is off the floor or in a wall")
	// Narrowed: still public ground for its closing time, but the officer heads home at once
	floor.entry_policy = "crew" // OUTPOST_FLOOR_ENTRY_CREW
	TEST_ASSERT_EQUAL(brain.breach_walk_review(), "down", "An officer walking a floor did not stand down when it narrowed")
	floor.entry_policy = "open" // OUTPOST_FLOOR_ENTRY_OPEN
	TEST_ASSERT_EQUAL(brain.breach_walk_review(), "down", "An officer heading home turned back")
	var/datum/turf_reservation/ground = test_ground(4, 4)
	if(!ground)
		return
	officer.forceMove(ground.bottom_left_turfs[1])
	TEST_ASSERT_NULL(brain.breach_walk_review(), "A walk-through is not over once the officer is off the floor")
	TEST_ASSERT_NULL(brain.breach_walk_ref, "An officer back from a walk-through still has its floor")

/// The empty-concourse pause never holds still an officer walking a floor or answering a floor warrant; one woken for
/// a floor holds still again once it is back off the floors with nobody on the concourse
/datum/unit_test/voidcrew_outpost_floors/breach_duty_not_paused

/datum/unit_test/voidcrew_outpost_floors/breach_duty_not_paused/Run()
	var/obj/structure/overmap/trader_outpost/outpost = test_outpost()
	var/datum/outpost_police/police = outpost.police
	var/datum/outpost_floor/floor = test_floor(outpost)
	if(!floor)
		return
	var/datum/ambient_place/outpost/place = SSambient_npcs.outpost_place(outpost)
	place.occupied = FALSE
	floor.entry_policy = "open" // OUTPOST_FLOOR_ENTRY_OPEN
	floor.public_ground = TRUE
	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/officer = police_test_officer(outpost, deck_tile(floor, 4))
	var/datum/ai_controller/basic_controller/human_npc/stealth/outpost_police/brain = officer.ai_controller
	TEST_ASSERT(istype(brain), "A beat officer has no police brain")
	if(!istype(brain))
		return
	officer.pause_routine()
	TEST_ASSERT(officer.paused_at, "An officer with no floor duty is not held still on an empty concourse")
	officer.resume_routine()
	brain.breach_walk_begin(floor, null)
	officer.pause_routine()
	TEST_ASSERT(!officer.paused_at, "An officer walking a floor was held still because the concourse is empty")
	brain.breach_walk_clear()
	floor.warrant_in_force = TRUE
	officer.pause_routine()
	TEST_ASSERT(!officer.paused_at, "An officer answering a floor warrant was held still because the concourse is empty")
	floor.warrant_in_force = FALSE
	// Held still, woken for the floor, and held again only once off it
	officer.pause_routine()
	TEST_ASSERT(officer.paused_at, "Fixture: the officer is not held still")
	police.floors_wake_officer(officer)
	TEST_ASSERT(!officer.paused_at, "A held officer did not wake for a floor")
	police.floors_settle_woken()
	TEST_ASSERT(!officer.paused_at, "An officer still up on a floor was held still")
	var/datum/turf_reservation/ground = test_ground(4, 4)
	if(!ground)
		return
	officer.forceMove(ground.bottom_left_turfs[1])
	police.floors_settle_woken()
	TEST_ASSERT(officer.paused_at, "An officer back off the floors was not held still again on an empty concourse")
	TEST_ASSERT(!LAZYLEN(police.floors_woken), "An officer held still again is still on the woken list")
	officer.resume_routine()
