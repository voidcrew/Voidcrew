/**
 * Outpost recovery tests: spec-rehydrate.md 4.1 (recovery_staff.dm). Owner: R2.
 *
 * RESTAFF: a counter whose keeper is gone gets a replacement off the public lift, linked to its shop; police posts
 * are counted from the ambient roles; the ambient roles are held back until REFILL and then come one at a time near
 * clean stops; the escort officers are not response units; the crews leave when their work is done.
 *
 * Trader-free where it can be: the replacement test takes the loaded outpost's own main trader, whatever its type is.
 * Defines are included after the tests: write values out with a comment naming the define. Helpers:
 * voidcrew_outpost_recovery_core.dm (recovery_outpost(), recovery_corpse(), recovery_worker()) and
 * voidcrew_outpost_police_helpers.dm. Tests are written, not run, by the package; the lead runs them once at integration.
 */

// ===== REPLACEMENT KEEPERS =====

/// A vacant counter gets one replacement, linked to its shop, with a new name; a second send makes no second
/// (The links and the new face are shop.set_keeper()'s, R1: this test needs R1's trader conversion merged.)
/datum/unit_test/voidcrew_outpost_recovery_replacement

/datum/unit_test/voidcrew_outpost_recovery_replacement/Run()
	var/obj/structure/overmap/trader_outpost/outpost = police_loaded_outpost()
	if(!outpost)
		return
	var/datum/outpost_recovery/recovery = outpost.recovery
	var/datum/ambient_place/outpost/place = SSambient_npcs.outpost_place(outpost)
	place.occupied = TRUE
	var/mob/living/keeper = outpost.trader
	TEST_ASSERT_NOTNULL(keeper, "The loaded outpost has no main trader")
	if(!keeper)
		return
	var/datum/outpost_shop/shop = outpost.shop
	var/keeper_type = keeper.type
	var/old_name = keeper.real_name

	// The recovery learns the counter while its keeper lives
	recovery.register_posts()
	var/datum/outpost_recovery_post/post = recovery.posts[shop]
	TEST_ASSERT_NOTNULL(post, "The main counter was not learnt")
	if(!post)
		return
	TEST_ASSERT_EQUAL(post.keeper_type, keeper_type, "The post does not know its keeper's type")
	TEST_ASSERT(!(post in recovery.vacant_posts()), "A kept counter is vacant")

	// The keeper vanishes: the counter is vacant and staff_needed() lists it
	qdel(keeper)
	TEST_ASSERT(post in recovery.vacant_posts(), "A counter with no keeper is not vacant")
	TEST_ASSERT(post in recovery.staff_needed(), "staff_needed() does not list the vacant counter")

	// send_staff() makes one replacement off the public lift
	recovery.send_staff()
	var/mob/living/replacement = post.replacement?.resolve()
	TEST_ASSERT_NOTNULL(replacement, "No replacement was made for the vacant counter")
	if(!replacement)
		return
	TEST_ASSERT_EQUAL(replacement.type, keeper_type, "The replacement is not the counter's kind of keeper")
	TEST_ASSERT_EQUAL(outpost.trader, replacement, "The outpost's face is not the replacement")
	TEST_ASSERT_EQUAL(shop.trader_npc, replacement, "The shop does not front the replacement")
	TEST_ASSERT(replacement in outpost.traders, "The replacement is not among the outpost's traders")
	TEST_ASSERT(replacement.real_name != old_name, "The replacement carries the old keeper's name")
	TEST_ASSERT(!(post in recovery.vacant_posts()), "A counter with a replacement is still vacant")
	TEST_ASSERT(!(post in recovery.staff_needed()), "staff_needed() still lists a counter with a replacement on the way")
	var/traders_before = length(outpost.traders)
	recovery.send_staff()
	TEST_ASSERT_EQUAL(length(outpost.traders), traders_before, "A second send made a second replacement")

	// A replacement who dies leaves the counter vacant again
	replacement.death()
	TEST_ASSERT(post in recovery.vacant_posts(), "A dead replacement still keeps the counter")
	qdel(replacement)

/// Abuse MF3 (M31): a keeper carried off the outpost alive keeps the counter a minute, then is replaced as if dead and never takes it back from off the outpost
/datum/unit_test/voidcrew_outpost_recovery_keeper_carried_off

/datum/unit_test/voidcrew_outpost_recovery_keeper_carried_off/Run()
	var/obj/structure/overmap/trader_outpost/outpost = police_loaded_outpost()
	if(!outpost)
		return
	var/datum/outpost_recovery/recovery = outpost.recovery
	var/datum/ambient_place/outpost/place = SSambient_npcs.outpost_place(outpost)
	place.occupied = TRUE
	var/mob/living/keeper = outpost.trader
	TEST_ASSERT_NOTNULL(keeper, "The loaded outpost has no main trader")
	if(!keeper)
		return
	var/turf/counter = get_turf(keeper)
	recovery.register_posts()
	var/datum/outpost_recovery_post/post = recovery.posts[outpost.shop]
	TEST_ASSERT_NOTNULL(post, "The main counter was not learnt")
	if(!post)
		return
	TEST_ASSERT(!(post in recovery.vacant_posts()), "A kept counter is vacant")

	// Carried off alive (the test room is off the outpost): a minute's grace, then vacant
	keeper.forceMove(run_loc_floor_bottom_left)
	TEST_ASSERT(!recovery.keeper_on_post(keeper), "A keeper off the outpost is still on post")
	TEST_ASSERT(!(post in recovery.vacant_posts()), "A keeper just dragged off left the counter vacant at once")
	TEST_ASSERT(post.away_since, "The time the keeper went was not noted")
	post.away_since = world.time - 1 MINUTES - 1 // RECOVERY_KEEPER_AWAY_MAX
	TEST_ASSERT(post in recovery.vacant_posts(), "A keeper carried off alive for a minute still keeps the counter")
	recovery.watch()
	TEST_ASSERT_EQUAL(recovery.state, 1, "A counter left vacant by a keeper carried off made no trouble") // OUTPOST_RECOVERY_TROUBLE

	// The replacement comes; the original, still off the outpost, does not take the counter back
	recovery.send_staff()
	var/mob/living/replacement = post.replacement?.resolve()
	TEST_ASSERT_NOTNULL(replacement, "No replacement was made for a keeper carried off")
	if(!replacement)
		return
	recovery.turn_round_replacements()
	TEST_ASSERT_EQUAL(post.replacement?.resolve(), replacement, "An original off the outpost took the counter back")
	TEST_ASSERT_EQUAL(outpost.shop.keeper?.resolve(), replacement, "The shop's keeper is not the replacement")

	// Back at the outpost before the replacement reaches the counter: the original takes it back
	keeper.forceMove(counter)
	TEST_ASSERT(recovery.keeper_on_post(keeper), "A keeper back at the outpost is not on post")
	recovery.turn_round_replacements()
	TEST_ASSERT_NULL(post.replacement, "A replacement still on the way kept the counter from its original")
	qdel(replacement)

/// Abuse MF5: bodies or people parked in the lift alcove never keep a replacement trader away
/datum/unit_test/voidcrew_outpost_recovery_alcove_blocked

/datum/unit_test/voidcrew_outpost_recovery_alcove_blocked/Run()
	var/obj/structure/overmap/trader_outpost/outpost = police_loaded_outpost()
	if(!outpost)
		return
	var/datum/outpost_recovery/recovery = outpost.recovery
	var/datum/ambient_place/outpost/place = SSambient_npcs.outpost_place(outpost)
	place.occupied = TRUE
	TEST_ASSERT(length(outpost.lobby_alcove_turfs), "The loaded outpost has no lift alcove")
	var/mob/living/keeper = outpost.trader
	TEST_ASSERT_NOTNULL(keeper, "The loaded outpost has no main trader")
	if(!keeper || !length(outpost.lobby_alcove_turfs))
		return
	recovery.register_posts()
	var/datum/outpost_recovery_post/post = recovery.posts[outpost.shop]
	TEST_ASSERT_NOTNULL(post, "The main counter was not learnt")
	if(!post)
		return
	qdel(keeper)

	// A body on every alcove tile
	for(var/turf/alcove as anything in outpost.lobby_alcove_turfs)
		var/mob/living/carbon/human/body = allocate(/mob/living/carbon/human/consistent, alcove)
		body.death()
	TEST_ASSERT_NULL(SSambient_npcs.lift_arrival_turf(outpost), "Setup: the ambient lift still takes arrivals")
	recovery.send_staff()
	var/mob/living/replacement = post.replacement?.resolve()
	TEST_ASSERT_NOTNULL(replacement, "Bodies in the lift alcove kept the replacement away")
	TEST_ASSERT(get_turf(replacement) in outpost.lobby_alcove_turfs, "The replacement did not come up the public lift")
	if(replacement)
		replacement.death()
		qdel(replacement)

	// Someone standing on every alcove tile: he still comes, and steps round them
	for(var/turf/alcove as anything in outpost.lobby_alcove_turfs)
		allocate(/mob/living/carbon/human/consistent, alcove)
	recovery.send_staff()
	replacement = post.replacement?.resolve()
	TEST_ASSERT_NOTNULL(replacement, "People standing in the lift alcove kept the replacement away")
	if(replacement)
		qdel(replacement)

/// A fake outpost is not loaded: it learns no post, has none vacant and the watch makes no trouble
/datum/unit_test/voidcrew_outpost_recovery_posts

/datum/unit_test/voidcrew_outpost_recovery_posts/Run()
	var/obj/structure/overmap/trader_outpost/outpost = recovery_outpost()
	var/datum/outpost_recovery/recovery = outpost.recovery
	recovery.register_posts()
	TEST_ASSERT_EQUAL(length(recovery.posts), 0, "A fake outpost learnt a post")
	TEST_ASSERT_EQUAL(length(recovery.vacant_posts()), 0, "A fake outpost has vacant posts")
	TEST_ASSERT_EQUAL(length(recovery.staff_needed()), 0, "A fake outpost with no station needs staff")
	recovery.watch()
	TEST_ASSERT_EQUAL(recovery.state, 0, "The watch made trouble at a quiet outpost") // OUTPOST_RECOVERY_NORMAL

// ===== POLICE POSTS =====

/// With a police station, a missing sergeant and missing beat officers are posts
/datum/unit_test/voidcrew_outpost_recovery_police_posts

/datum/unit_test/voidcrew_outpost_recovery_police_posts/Run()
	var/obj/structure/overmap/trader_outpost/outpost = recovery_outpost()
	var/datum/outpost_recovery/recovery = outpost.recovery
	var/datum/outpost_police/police = outpost.police
	police.desk_turf = wanted_spot(1, 1) // a desk makes it a station (life_has_station())
	var/sergeants = 0
	var/beats = 0
	for(var/datum/outpost_recovery_post/post as anything in recovery.staff_needed())
		if(post.role_type == /datum/ambient_outpost_role/police_sergeant)
			sergeants += post.missing
		else if(post.role_type == /datum/ambient_outpost_role/police_beat)
			beats += post.missing
	TEST_ASSERT_EQUAL(sergeants, 1, "A station with no sergeant is not short of one")
	TEST_ASSERT(beats > 0, "A station with no beat officers is not short of any")

	// A sergeant at the desk is no longer missing
	police_officer(outpost, /mob/living/carbon/human/npc/ambient_npc/outpost/police/sergeant, wanted_spot(1, 1))
	sergeants = 0
	for(var/datum/outpost_recovery_post/post as anything in recovery.staff_needed())
		if(post.role_type == /datum/ambient_outpost_role/police_sergeant)
			sergeants += post.missing
	TEST_ASSERT_EQUAL(sergeants, 0, "A sergeant on the roster is still missing")

/// An escort officer is not a response unit (dispatch leaves it at its watch), and a dispatch_unit_built() for an escort wave marks it
/datum/unit_test/voidcrew_outpost_recovery_escort

/datum/unit_test/voidcrew_outpost_recovery_escort/Run()
	var/obj/structure/overmap/trader_outpost/outpost = recovery_outpost()
	var/datum/outpost_recovery/recovery = outpost.recovery
	var/datum/outpost_police/police = outpost.police
	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/officer/officer = police_officer(outpost, /mob/living/carbon/human/npc/ambient_npc/outpost/police/officer, wanted_spot(2, 2))
	TEST_ASSERT(police.dispatch_is_response_unit(officer), "A response officer is not a response unit")
	officer.recovery_escort = TRUE
	TEST_ASSERT(!police.dispatch_is_response_unit(officer), "An escort is a response unit")

	// An officer built into an escort wave is marked and counted with the crew
	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/officer/built = police_officer(outpost, /mob/living/carbon/human/npc/ambient_npc/outpost/police/officer, wanted_spot(3, 3))
	var/datum/outpost_police_wave/wave = police.dispatch_new_wave("concourse", null) // POLICE_SECTOR_CONCOURSE
	recovery.escort_waves += WEAKREF(wave)
	police.dispatch_unit_built(wave, null, built)
	TEST_ASSERT(built.recovery_escort, "An officer built into an escort wave is not marked")
	TEST_ASSERT(WEAKREF(built) in recovery.crew, "An escort is not counted with the crew")
	// ...and one built into some other wave is not
	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/officer/other = police_officer(outpost, /mob/living/carbon/human/npc/ambient_npc/outpost/police/officer, wanted_spot(4, 4))
	var/datum/outpost_police_wave/other_wave = police.dispatch_new_wave("concourse", null) // POLICE_SECTOR_CONCOURSE
	police.dispatch_unit_built(other_wave, null, other)
	TEST_ASSERT(!other.recovery_escort, "An ordinary response officer was marked as an escort")

	// NORMAL releases the escorts
	recovery.set_state(1) // OUTPOST_RECOVERY_TROUBLE
	recovery.set_state(0) // OUTPOST_RECOVERY_NORMAL
	TEST_ASSERT(!built.recovery_escort, "An escort was not released when the outpost went back to normal")
	TEST_ASSERT(police.dispatch_is_response_unit(built), "A released escort is not a response unit again")

// ===== THE AMBIENT ROLES' GATE =====

/// The ambient roles have no open slot while the outpost is in trouble, cleaned or restaffed; in REFILL one every minute to ninety seconds
/datum/unit_test/voidcrew_outpost_recovery_refill_pacing

/datum/unit_test/voidcrew_outpost_recovery_refill_pacing/Run()
	var/obj/structure/overmap/trader_outpost/outpost = recovery_outpost()
	var/datum/outpost_recovery/recovery = outpost.recovery
	var/datum/ambient_place/outpost/place = SSambient_npcs.outpost_place(outpost)
	// A role that wants people here: the beat, once the map has a station. Not registered with the subsystem.
	outpost.police.desk_turf = wanted_spot(1, 1)
	var/datum/ambient_outpost_role/police_beat/role = new
	TEST_ASSERT(place.open_slots(role) > 0, "A NORMAL outpost short of beat officers has no open slot")

	for(var/closed_state in list(1, 2, 3)) // OUTPOST_RECOVERY_TROUBLE, _CLEANUP, _RESTAFF
		recovery.state = closed_state
		TEST_ASSERT_EQUAL(place.open_slots(role), 0, "State [closed_state] let the ambient roles fill a slot")

	recovery.state = 4 // OUTPOST_RECOVERY_REFILL
	recovery.next_refill_at = world.time + 30 SECONDS
	TEST_ASSERT_EQUAL(place.open_slots(role), 0, "REFILL brought someone back before its turn")
	recovery.next_refill_at = world.time
	TEST_ASSERT(place.open_slots(role) > 0, "REFILL held a slot back at its turn")

	// An arrival sets the gap before the next; officers do not
	var/mob/living/carbon/human/npc/ambient_npc/outpost/customer/customer = allocate(/mob/living/carbon/human/npc/ambient_npc/outpost/customer, wanted_spot(1, 3))
	customer.set_place(place)
	var/gap = recovery.next_refill_at - world.time
	TEST_ASSERT(gap >= 600 && gap <= 900, "The gap after an arrival is [gap / 10] seconds, not 60 to 90") // OUTPOST_RECOVERY_REFILL_GAP_MIN to _MAX
	TEST_ASSERT_EQUAL(place.open_slots(role), 0, "REFILL let a second arrival follow at once")
	recovery.next_refill_at = world.time
	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/beat/officer = allocate(/mob/living/carbon/human/npc/ambient_npc/outpost/police/beat, wanted_spot(2, 3))
	officer.set_place(place)
	TEST_ASSERT_EQUAL(recovery.next_refill_at, world.time, "An officer's arrival set the refill gap")

/// A killed person's place is no longer shut for twenty minutes: the recovery brings it back
/datum/unit_test/voidcrew_outpost_recovery_no_killed_slot_wait

/datum/unit_test/voidcrew_outpost_recovery_no_killed_slot_wait/Run()
	var/obj/structure/overmap/trader_outpost/outpost = recovery_outpost()
	var/datum/ambient_place/outpost/place = SSambient_npcs.outpost_place(outpost)
	var/mob/living/carbon/human/npc/ambient_npc/outpost/customer/customer = allocate(/mob/living/carbon/human/npc/ambient_npc/outpost/customer, wanted_spot(1, 1))
	customer.set_place(place)
	customer.role = /datum/ambient_outpost_role/customer
	customer.death()
	TEST_ASSERT_EQUAL(length(place.killed_until), 0, "A death at a trader outpost started the twenty minute wait")

/// In REFILL nobody settles within a patrol stop's range of a stop that is still dirty
/datum/unit_test/voidcrew_outpost_recovery_dirty_stop

/datum/unit_test/voidcrew_outpost_recovery_dirty_stop/Run()
	var/obj/structure/overmap/trader_outpost/outpost = recovery_outpost()
	var/datum/outpost_recovery/recovery = outpost.recovery
	var/turf/stop = wanted_spot(5, 5)
	var/turf/near = wanted_spot(5, 8)
	var/turf/far = wanted_spot(5, 14)
	recovery.dirty_stops[stop] = TRUE
	TEST_ASSERT(!recovery.near_dirty_stop(near), "A tile was avoided outside REFILL")
	recovery.state = 4 // OUTPOST_RECOVERY_REFILL
	TEST_ASSERT(recovery.near_dirty_stop(near), "A tile three from a dirty stop is not avoided in REFILL") // OUTPOST_RECOVERY_STOP_RANGE is 6
	TEST_ASSERT(!recovery.near_dirty_stop(far), "A tile nine from a dirty stop is avoided")
	recovery.dirty_stops[stop] = FALSE
	TEST_ASSERT(!recovery.near_dirty_stop(near), "A clean stop still keeps people away")

/// A death in the box seeds dirt at the patrol stops near it
/datum/unit_test/voidcrew_outpost_recovery_dirty_seed

/datum/unit_test/voidcrew_outpost_recovery_dirty_seed/Run()
	var/obj/structure/overmap/trader_outpost/outpost = recovery_outpost()
	var/datum/outpost_recovery/recovery = outpost.recovery
	var/turf/near_stop = wanted_spot(3, 3)
	var/turf/far_stop = wanted_spot(15, 15)
	outpost.police.stop_activities[near_stop] = ""
	outpost.police.stop_activities[far_stop] = ""
	recovery_corpse(outpost, wanted_spot(2, 2))
	TEST_ASSERT(recovery.dirty_stops[near_stop], "A stop beside a death is not dirty")
	TEST_ASSERT(!recovery.dirty_stops[far_stop], "A stop far from any death is dirty")

// ===== THE CREWS LEAVE =====

/// RESTAFF lets the crews go when nobody holds a body, or when the grace is over
/datum/unit_test/voidcrew_outpost_recovery_crew_leaves

/datum/unit_test/voidcrew_outpost_recovery_crew_leaves/Run()
	var/obj/structure/overmap/trader_outpost/outpost = recovery_outpost()
	var/datum/outpost_recovery/recovery = outpost.recovery
	var/mob/living/carbon/human/npc/ambient_npc/outpost/customer/body = recovery_corpse(outpost, wanted_spot(2, 2))
	var/mob/living/carbon/human/npc/ambient_npc/outpost/recovery/worker = recovery_worker(outpost, wanted_spot(1, 1))
	recovery.state = 3 // OUTPOST_RECOVERY_RESTAFF
	recovery.restaff_started_at = world.time
	// A worker holding a body stays through the grace
	recovery.claims[WEAKREF(body)] = WEAKREF(worker)
	recovery.tick_restaff()
	TEST_ASSERT_EQUAL(length(recovery.crew), 1, "The crew left with a body in hand")
	// ...and goes when the grace is over
	recovery.restaff_started_at = world.time - 2 MINUTES // RECOVERY_CREW_GRACE
	recovery.tick_restaff()
	TEST_ASSERT_EQUAL(length(recovery.crew), 0, "The crew did not leave after the grace")

	// With nothing held, they go at once
	var/mob/living/carbon/human/npc/ambient_npc/outpost/recovery/second = recovery_worker(outpost, wanted_spot(3, 1), /mob/living/carbon/human/npc/ambient_npc/outpost/recovery/janitor)
	recovery.claims.Cut()
	recovery.restaff_started_at = world.time
	recovery.tick_restaff()
	TEST_ASSERT_EQUAL(length(recovery.crew), 0, "An idle crew did not leave")
	TEST_ASSERT_NOTNULL(second, "The test worker is gone")

/// A player-possessed or fleeing keeper vacates the shop and counter; a replacement inside a container does not block the original returning
/datum/unit_test/voidcrew_outpost_recovery_keeper_played_and_container_turnaround

/datum/unit_test/voidcrew_outpost_recovery_keeper_played_and_container_turnaround/Run()
	var/obj/structure/overmap/trader_outpost/outpost = recovery_outpost()
	r1_site(outpost)
	var/datum/outpost_recovery/recovery = outpost.recovery
	var/datum/outpost_shop/shop = outpost.ensure_main_shop()
	var/turf/counter = wanted_spot(2, 2)
	var/mob/living/carbon/human/npc/ambient_npc/outpost/trader/keeper = r1_keeper(shop, counter)
	recovery.register_posts()
	var/datum/outpost_recovery_post/post = recovery.posts[shop]
	TEST_ASSERT_NOTNULL(post, "Setup: main shop post was not registered")

	// Player mind in the keeper's body closes the shop and vacates the counter
	keeper.mind_initialize()
	allocated += keeper.mind
	TEST_ASSERT(!shop.is_open(), "A keeper body controlled by a player kept the shop open")
	TEST_ASSERT(!recovery.keeper_alive(keeper), "A keeper body controlled by a player still counted as an NPC keeper")
	TEST_ASSERT(post in recovery.vacant_posts(), "A player-inhabited keeper blocked replacement staff")
	keeper.mind.set_current(null)
	keeper.last_mind = null
	TEST_ASSERT(shop.is_open(), "Clearing the test mind did not reopen the shop")

	// Fleeing keeper (leave activity) closes the shop and vacates the counter
	keeper.start_activity(new /datum/ambient_activity/leave(keeper, wanted_spot(8, 8)))
	TEST_ASSERT(!shop.is_open(), "A fleeing keeper kept the shop open")
	TEST_ASSERT(!recovery.keeper_alive(keeper), "A fleeing keeper still held the post")
	keeper.end_activity()

	// Replacement shut inside a locker far from the counter (get_dist == 0 trap) still yields to the original keeper
	var/mob/living/carbon/human/npc/ambient_npc/outpost/trader/replacement = allocate(/mob/living/carbon/human/npc/ambient_npc/outpost/trader, wanted_spot(8, 8))
	post.replacement = WEAKREF(replacement)
	shop.set_keeper(replacement)
	var/obj/structure/closet/locker = allocate(/obj/structure/closet, wanted_spot(8, 8))
	replacement.forceMove(locker)
	recovery.turn_round_replacements()
	TEST_ASSERT_NULL(post.replacement, "A replacement inside a distant locker appeared adjacent to the counter and stayed")
	TEST_ASSERT_EQUAL(shop.keeper?.resolve(), keeper, "The original keeper did not take the shop back from a boxed replacement")
	replacement.forceMove(wanted_spot(8, 8))
