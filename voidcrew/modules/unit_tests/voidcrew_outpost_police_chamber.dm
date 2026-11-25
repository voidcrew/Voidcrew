/**
 * Outpost police tests: someone wanted who stands in a checkpoint's scan chamber (voidcrew/modules/trade/
 * outpost_checkpoint.dm and outpost_checkpoint_npcs.dm, and what walks officers there in outpost_police/).
 * The soak's gate_emag_stay on all three outposts: the suspect emags the scanner from inside the chamber and stays,
 * and nobody ever takes them, because no officer could walk into a scan chamber.
 *
 * The tests under /datum/unit_test/voidcrew_outpost_police_search/chamber are live: a real outpost map, the police's
 * own one-second tick and the officers' own AI (the harness of voidcrew_outpost_police_search.dm).
 *
 * Fork defines are included after the tests, so values are written out: heat 40 is two stars
 * (OUTPOST_POLICE_STAR_HEAT 10, 25, 50, 90, 140); checkpoint states "idle", "scanning", "passing", "rejecting".
 */

/datum/unit_test/voidcrew_outpost_police_search/chamber
	abstract_type = /datum/unit_test/voidcrew_outpost_police_search/chamber
	/// The outpost whose checkpoint it is
	var/outpost_type
	/// Whether the gate is down, as an emag on its scanner leaves it; else it is working
	var/gate_down = FALSE

/// Whether `thing` is in `post`'s chamber or one of its doorways
/datum/unit_test/voidcrew_outpost_police_search/chamber/proc/in_gate(datum/outpost_checkpoint/post, atom/thing)
	var/turf/where = get_turf(thing)
	return where && ((where in post.chamber_turfs) || where == get_turf(post.inner_door) || where == get_turf(post.outer_door))

/// The officers of `police` standing in `post`'s chamber or doorways
/datum/unit_test/voidcrew_outpost_police_search/chamber/proc/officers_in_gate(datum/outpost_police/police, datum/outpost_checkpoint/post)
	. = list()
	for(var/mob/living/carbon/human/npc/ambient_npc/outpost/police/officer in police.officers)
		if(in_gate(post, officer))
			. += officer

/// The doors and the state of `post`, and who stands in it or in front of its outer door, for a failure message
/datum/unit_test/voidcrew_outpost_police_search/chamber/proc/gate_report(datum/outpost_checkpoint/post)
	var/list/people = list()
	var/turf/outer_turf = get_turf(post.outer_door)
	for(var/turf/tile as anything in post.chamber_turfs + outer_turf + get_turf(post.inner_door) + post.lobby_turf)
		for(var/mob/living/person in tile)
			var/mob/living/carbon/human/npc/ambient_npc/outpost/police/officer = person
			var/where = tile == outer_turf ? "the outer doorway" : (tile == post.lobby_turf ? "front of the outer door" : (tile in post.chamber_turfs ? "the chamber" : "the inner doorway"))
			var/what = "[person.type]"
			if(istype(officer))
				what = "officer ([officer.unit_kind][officer.case ? ", on an arrest" : ""][HAS_TRAIT(officer, "checkpoint_crossing") ? ", going through" : ""])" // TRAIT_CHECKPOINT_CROSSING
			else if(person.mind)
				what = "[person.real_name]"
			people += "[what] in [where]"
	return "checkpoint [post.state], outer door [post.outer_door.density ? "shut" : "open"][post.outer_door.operating ? " and moving" : ""], inner door [post.inner_door.density ? "shut" : "open"], police at work [post.police_at_work() ? "yes" : "no"]; there: [length(people) ? people.Join(", ") : "nobody"]"

/**
 * Two stars, standing in the lobby checkpoint's scan chamber, hands empty, doing as told. An officer comes in for
 * them, cuffs them there and walks them out; no officer is left in the chamber; and the gate works for the next
 * visitor.
 */
/datum/unit_test/voidcrew_outpost_police_search/chamber/Run()
	var/obj/structure/overmap/trader_outpost/outpost = search_outpost(outpost_type)
	if(!outpost)
		return
	var/datum/outpost_police/police = outpost.police
	var/datum/outpost_checkpoint/post = outpost.lobby_checkpoint()
	var/gate = gate_down ? "gate down" : "gate working"
	TEST_ASSERT_NOTNULL(post?.sensor, "[outpost_type] has no lobby checkpoint with a scanner")
	TEST_ASSERT_NOTNULL(police.desk_turf, "[outpost_type] has no police desk")
	// Beside the scanner, where the emag is used from
	var/turf/stand
	for(var/turf/tile as anything in post.chamber_turfs)
		if(tile.is_blocked_turf(exclude_mobs = TRUE))
			continue
		if(!stand || (tile.Adjacent(post.sensor) && !stand.Adjacent(post.sensor)))
			stand = tile
	TEST_ASSERT_NOTNULL(stand, "[outpost_type]: no free tile in the scan chamber")
	duty_officer(outpost, /mob/living/carbon/human/npc/ambient_npc/outpost/police/sergeant, police.desk_turf)
	beat_officers(outpost)
	var/mob/living/carbon/human/suspect = wanted_at(outpost, stand, stand, 40)
	suspect.real_name = "Chamber Suspect"
	suspect.name = suspect.real_name
	if(gate_down)
		// OUTPOST_CHECKPOINT_EMAG_TIME
		post.disabled_until = world.time + 3 MINUTES
		post.update_sensor()
	else
		// As the game leaves someone wanted who walked in: scanned, refused, the outer door open for them to go back out
		TEST_ASSERT(post.request_cycle(suspect), "[outpost_type]: the chamber would not scan someone standing in it")
		sleep(4 SECONDS)
		TEST_ASSERT_EQUAL(post.state, "rejecting", "[outpost_type]: the gate did not refuse someone wanted") // CHECKPOINT_REJECTING
		TEST_ASSERT(!post.outer_door.density, "[outpost_type]: the outer door did not open for someone refused")
	police.wake()

	// Cuffed where they stand
	var/started = world.time
	var/cuffed_after = -1
	while(world.time - started < 75 SECONDS)
		if(suspect.handcuffed)
			cuffed_after = world.time - started
			break
		sleep(0.5 SECONDS)
	var/datum/outpost_police_case/case = police.cases[suspect.mind]
	var/turf/corner = outpost.template_bottom_left
	if(cuffed_after < 0)
		police.sleep_tick()
		TEST_FAIL("[outpost_type], [gate]: two stars, standing in the scan chamber at [stand.x - corner.x + 1],[stand.y - corner.y + 1]: not in cuffs after 75 s (arrest [case ? "on its \"[case.step]\" step" : "never opened"], [police.get_stars(suspect.mind)] stars, the suspect now at [suspect.x - corner.x + 1],[suspect.y - corner.y + 1], [gate_report(post)]). [officers_report(outpost)]")
		dispatch_clear(police)
		return
	TEST_ASSERT(in_gate(post, suspect), "[outpost_type], [gate]: the suspect was cuffed at [suspect.x - corner.x + 1],[suspect.y - corner.y + 1], not in the chamber they stood in (fixture)")

	// Walked out of the chamber, an officer's hand on them
	started = world.time
	var/out_after = -1
	while(world.time - started < 60 SECONDS)
		if(!in_gate(post, suspect) && (is_outpost_police_npc(suspect.pulledby) || police.cell_holding(suspect.mind)))
			out_after = world.time - started
			break
		sleep(0.5 SECONDS)
	if(out_after < 0)
		case = police.cases[suspect.mind]
		police.sleep_tick()
		TEST_FAIL("[outpost_type], [gate]: cuffed in the scan chamber and still [in_gate(post, suspect) ? "in it" : "let go of"] 60 s later (arrest [case ? "on its \"[case.step]\" step" : "closed"], [gate_report(post)]). [officers_report(outpost)]")
		dispatch_clear(police)
		return

	// Nobody is left in there
	started = world.time
	var/list/inside = officers_in_gate(police, post)
	while(length(inside) && world.time - started < 30 SECONDS)
		sleep(0.5 SECONDS)
		inside = officers_in_gate(police, post)
	TEST_ASSERT(!length(inside), "[outpost_type], [gate]: [length(inside)] of the officers still in the scan chamber 30 s after the prisoner left it ([gate_report(post)]). [officers_report(outpost)]")
	log_test("[outpost_type], [gate]: cuffed in the chamber after [cuffed_after / 10] s, out of it [out_after / 10] s later")

	// And the gate is a gate again for the next one
	if(gate_down)
		post.disabled_until = 0
		post.end_disable()
	started = world.time
	while(world.time - started < 20 SECONDS && (!post.outer_door.density || !post.inner_door.density || post.outer_door.operating || post.inner_door.operating || post.state != "idle")) // CHECKPOINT_IDLE
		sleep(0.5 SECONDS)
	TEST_ASSERT(post.outer_door.density && post.inner_door.density && !post.outer_door.operating && !post.inner_door.operating && post.state == "idle", "[outpost_type], [gate]: 20 s after the arrest the gate has not settled ([gate_report(post)])")
	// The next visitor walks up to the outer door, in when it opens, and is scanned and let through. On their own feet:
	// put down inside the chamber by hand they would land past whichever of the outpost's people was walking in, and
	// leave them standing in the doorway
	var/mob/living/carbon/human/visitor = dispatch_suspect(outpost, 0, post.lobby_turf)
	var/turf/outer_turf = get_turf(post.outer_door)
	started = world.time
	while(world.time - started < 30 SECONDS && !(visitor.loc in post.chamber_turfs))
		if(post.outer_door.density)
			if(!post.outer_door.operating)
				post.outer_door.bumpopen(visitor)
		else if(visitor.loc == outer_turf)
			for(var/turf/tile as anything in post.chamber_turfs)
				if(get_dist(tile, outer_turf) == 1 && !tile.is_blocked_turf(exclude_mobs = FALSE) && visitor.Move(tile, get_dir(visitor, tile)))
					break
		else if(get_dist(visitor, outer_turf) <= 1)
			visitor.Move(outer_turf, get_dir(visitor, outer_turf))
		else
			visitor.forceMove(post.lobby_turf)
		sleep(0.5 SECONDS)
	TEST_ASSERT(visitor.loc in post.chamber_turfs, "[outpost_type], [gate]: after the arrest a visitor could not walk in at the outer door in 30 s ([gate_report(post)])")
	started = world.time
	while(world.time - started < 40 SECONDS && (post.inner_door.density || post.state != "passing")) // CHECKPOINT_PASSING
		sleep(0.5 SECONDS)
	TEST_ASSERT(!post.inner_door.density && post.state == "passing", "[outpost_type], [gate]: after the arrest a visitor with nothing on them, standing in the chamber, was not let through in 40 s ([gate_report(post)])")
	police.sleep_tick()
	dispatch_clear(police)

/datum/unit_test/voidcrew_outpost_police_search/chamber/halcyon_down
	outpost_type = /obj/structure/overmap/trader_outpost/general
	gate_down = TRUE

/datum/unit_test/voidcrew_outpost_police_search/chamber/halcyon_working
	outpost_type = /obj/structure/overmap/trader_outpost/general

/datum/unit_test/voidcrew_outpost_police_search/chamber/quartermain_down
	outpost_type = /obj/structure/overmap/trader_outpost/outfitter
	gate_down = TRUE

/datum/unit_test/voidcrew_outpost_police_search/chamber/quartermain_working
	outpost_type = /obj/structure/overmap/trader_outpost/outfitter

/datum/unit_test/voidcrew_outpost_police_search/chamber/undertow_down
	outpost_type = /obj/structure/overmap/trader_outpost/black_market
	gate_down = TRUE

/datum/unit_test/voidcrew_outpost_police_search/chamber/undertow_working
	outpost_type = /obj/structure/overmap/trader_outpost/black_market

// ===== THE KEY, BY ITS RULES =====
// On the small checkpoint of voidcrew_trader_checkpoint.dm: lobby below, a chamber of two tiles (the first between the
// doors, the second beside it), the concourse above.

/// An officer of the fixture's outpost at `where`, on its roster
/datum/unit_test/voidcrew_trader_checkpoint/proc/key_officer(turf/where)
	host.ensure_police()
	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/officer/cop = allocate(/mob/living/carbon/human/npc/ambient_npc/outpost/police/officer, where)
	host.police.add_officer(cop)
	return cop

/**
 * An officer's key at the checkpoint: nothing for an officer with no business in the chamber; the outer door for one
 * walking to someone in it, whatever the chamber is doing, short of an open inner door; the inner door only with the
 * gate down; and the way out for one standing in it.
 */
/datum/unit_test/voidcrew_trader_checkpoint/police_key/Run()
	TEST_ASSERT(fixture(FALSE), "Could not prepare the checkpoint")
	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/officer/cop = key_officer(lobby)
	var/datum/can_pass_info/cop_walk = new(cop, list())
	var/mob/living/carbon/human/suspect = visitor(chamber[2])
	police_pin_warrant(host.police, suspect.mind, 40)
	// Nothing to do in there: the doors are walls to it, as to any NPC
	TEST_ASSERT(!outer.CanAStarPass(NORTH, cop_walk) && !inner.CanAStarPass(SOUTH, cop_walk), "An officer with no business in the chamber paths through its doors")
	outer.bumpopen(cop)
	inner.bumpopen(cop)
	sleep(1.5 SECONDS)
	TEST_ASSERT(outer.density && inner.density, "An officer with no business in the chamber opened a door by walking into it")
	// Walking to someone in it: the outer door is its to open, the inner door is not
	cop.ai_controller.set_movement_target(type, suspect)
	TEST_ASSERT(outer.CanAStarPass(NORTH, cop_walk), "An officer walking to someone in the chamber cannot path through the outer door")
	TEST_ASSERT(!inner.CanAStarPass(SOUTH, cop_walk), "With the gate working an officer paths in through the shut inner door")
	inner.bumpopen(cop)
	sleep(1.5 SECONDS)
	TEST_ASSERT(inner.density, "With the gate working an officer's key opened the inner door")
	// A scan under way stops for it
	checkpoint.start_scan()
	TEST_ASSERT_EQUAL(checkpoint.state, "scanning", "Fixture: the chamber did not scan") // CHECKPOINT_SCANNING
	outer.bumpopen(cop)
	TEST_ASSERT_EQUAL(checkpoint.state, "idle", "A scan went on with an officer's key in the outer door") // CHECKPOINT_IDLE
	sleep(1.5 SECONDS)
	TEST_ASSERT(!outer.density, "An officer's key did not open the outer door on someone wanted in the chamber")
	TEST_ASSERT(inner.density, "The inner door opened with the outer door")
	// Any other NPC still gets nothing, key or no key about
	suspect.forceMove(secured)
	settle()
	var/mob/living/carbon/human/npc/ambient_npc/outpost/customer/npc = allocate(/mob/living/carbon/human/npc/ambient_npc/outpost/customer, lobby)
	var/datum/can_pass_info/npc_walk = new(npc, list())
	suspect.forceMove(chamber[2])
	npc.ai_controller?.set_movement_target(type, suspect)
	TEST_ASSERT(!outer.CanAStarPass(NORTH, npc_walk), "A townsperson walking to someone in the chamber paths through its door")
	outer.bumpopen(npc)
	sleep(1.5 SECONDS)
	TEST_ASSERT(outer.density, "A townsperson opened the outer door by walking into it")
	// The lock holds for the key: never the outer door while the inner one is open
	var/mob/living/carbon/human/clean = visitor(chamber[1])
	suspect.forceMove(secured)
	TEST_ASSERT(scan_now(clean), "Fixture: could not scan a clean visitor through")
	sleep(2 SECONDS)
	TEST_ASSERT(!inner.density, "Fixture: the inner door did not open for a clean visitor")
	suspect.forceMove(chamber[2])
	TEST_ASSERT(outer.CanAStarPass(NORTH, cop_walk), "An officer's way in is not the outer door while the inner door is open")
	outer.bumpopen(cop)
	sleep(1.5 SECONDS)
	TEST_ASSERT(outer.density, "An officer's key opened the outer door with the inner door open")
	clean.forceMove(secured)
	TEST_ASSERT(wait_shut(inner, 10 SECONDS), "Fixture: the inner door did not shut after its pass")
	outer.bumpopen(cop)
	sleep(1.5 SECONDS)
	TEST_ASSERT(!outer.density, "With the inner door shut again an officer's key did not open the outer door")
	suspect.forceMove(secured)
	settle()
	// The gate down: either door, as for anyone, and still nothing for a townsperson walking into one
	suspect.forceMove(chamber[2])
	checkpoint.disabled_until = world.time + 1800
	cop.forceMove(secured)
	TEST_ASSERT(inner.CanAStarPass(SOUTH, cop_walk), "With the gate down an officer cannot path in through the inner door")
	inner.bumpopen(npc)
	sleep(1.5 SECONDS)
	TEST_ASSERT(inner.density, "With the gate down a townsperson opened the inner door by walking into it")
	inner.bumpopen(cop)
	sleep(1.5 SECONDS)
	TEST_ASSERT(!inner.density, "With the gate down an officer's key did not open the inner door")
	checkpoint.disabled_until = 0
	suspect.forceMove(lobby)
	settle()
	// Standing in it: the way out is its own, wherever it is going
	cop.ai_controller.set_movement_target(type, null)
	cop.forceMove(chamber[1])
	TEST_ASSERT(outer.CanAStarPass(SOUTH, cop_walk), "An officer in the chamber cannot path out through the outer door")
	TEST_ASSERT(!inner.CanAStarPass(NORTH, cop_walk), "With the gate working an officer in the chamber paths out through the shut inner door")
	outer.bumpopen(cop)
	sleep(1.5 SECONDS)
	TEST_ASSERT(!outer.density, "An officer shut in the chamber could not let itself out")
	cop.forceMove(lobby)
	settle()
	// Someone playing an officer's body has no key
	suspect.forceMove(chamber[2])
	cop.ai_controller.set_movement_target(type, suspect)
	TEST_ASSERT(checkpoint.police_key_holder(cop), "Fixture: the officer has no business in the chamber")
	cop.mind_initialize()
	TEST_ASSERT(!checkpoint.police_key_holder(cop), "A played officer's body has the police's key")
	qdel(cop)

/**
 * The police at work in the chamber (an officer and someone it is after, both inside): no scan, the outer door stays
 * open behind them, the outpost's people keep out, and a player cannot cycle the gate on them. Done, the gate goes on
 * as it would have. An officer alone in there, or one only going through, holds nothing up.
 */
/datum/unit_test/voidcrew_trader_checkpoint/police_at_work/Run()
	TEST_ASSERT(fixture(FALSE), "Could not prepare the checkpoint")
	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/officer/cop = key_officer(lobby)
	var/mob/living/carbon/human/npc/ambient_npc/outpost/customer/npc = allocate(/mob/living/carbon/human/npc/ambient_npc/outpost/customer, lobby)
	var/mob/living/carbon/human/suspect = visitor(chamber[2])
	var/datum/outpost_warrant/warrant = police_pin_warrant(host.police, suspect.mind, 40)
	// An officer and nobody wanted, or someone wanted and no officer: no work
	cop.forceMove(chamber[1])
	suspect.forceMove(secured)
	TEST_ASSERT(!checkpoint.police_at_work(), "An officer alone in the chamber counts as the police at work")
	suspect.forceMove(chamber[2])
	cop.forceMove(lobby)
	TEST_ASSERT(!checkpoint.police_at_work(), "Someone wanted alone in the chamber counts as the police at work")
	// In for them: the door stays open behind the officer past its usual four seconds, and nothing is scanned
	cop.ai_controller.set_movement_target(type, suspect)
	outer.bumpopen(cop)
	sleep(1.5 SECONDS)
	TEST_ASSERT(!outer.density, "Fixture: the officer's key did not open the outer door")
	cop.forceMove(chamber[1])
	TEST_ASSERT(checkpoint.police_at_work(), "An officer in the chamber with someone wanted is not the police at work")
	sleep(7 SECONDS) // OUTPOST_CHECKPOINT_OUTER_HOLD is 4 s
	TEST_ASSERT(!outer.density, "The outer door shut on an officer at work in the chamber")
	TEST_ASSERT_EQUAL(checkpoint.state, "idle", "The chamber went on with its cycle with the police at work in it") // CHECKPOINT_IDLE
	// Nobody walks in on it or works the gate on them
	TEST_ASSERT_NULL(checkpoint.chamber_place_for(npc), "A townsperson was given a place in the chamber during an arrest")
	TEST_ASSERT(!checkpoint.request_outer(npc), "A townsperson's ask was answered with the police at work in the chamber")
	TEST_ASSERT(!outer.density, "A townsperson's ask shut the outer door on the police")
	TEST_ASSERT(!checkpoint.request_cycle(suspect), "Someone in the chamber cycled the gate on the officer arresting them")
	checkpoint.request_outer(suspect)
	sleep(2.5 SECONDS)
	TEST_ASSERT(!outer.density, "A click on the outer door shut it on an officer at work in the chamber")
	// The officer only going through to the concourse holds nothing up
	ADD_TRAIT(cop, "checkpoint_crossing", "outpost_police_checkpoint") // TRAIT_CHECKPOINT_CROSSING, as checkpoint_step_to_concourse() gives it
	TEST_ASSERT(!checkpoint.police_at_work(), "An officer going through the checkpoint counts as the police at work")
	REMOVE_TRAIT(cop, "checkpoint_crossing", "outpost_police_checkpoint")
	// Done (the officer walks out; the suspect is left, still wanted): the gate goes on as for anyone wanted. The door
	// shuts, they are scanned and refused, and it opens for them to leave.
	cop.ai_controller.set_movement_target(type, null)
	cop.forceMove(lobby)
	var/refused = FALSE
	for(var/i in 1 to 150)
		if(checkpoint.state == "rejecting" && !outer.density) // CHECKPOINT_REJECTING
			refused = TRUE
			break
		sleep(0.1 SECONDS)
	TEST_ASSERT(refused, "With the police gone the gate did not go on to scan and refuse who was left in it (checkpoint [checkpoint.state], outer door [outer.density ? "shut" : "open"])")
	// And with nobody wanted left, the queue has its places back
	host.police.remove_warrant(warrant)
	suspect.forceMove(secured)
	TEST_ASSERT(wait_shut(outer, 15 SECONDS), "The outer door did not shut once the refused person had gone")
	TEST_ASSERT_EQUAL(checkpoint.state, "idle", "The gate did not settle after the police left") // CHECKPOINT_IDLE
	TEST_ASSERT(checkpoint.request_outer(npc), "After the police left a townsperson could not ask the outer door")
	sleep(1.5 SECONDS)
	TEST_ASSERT(checkpoint.chamber_place_for(npc) in chamber, "After the police left a townsperson had no place in the chamber")

/**
 * A scan that falls due while the police are at work in the chamber waits for them, and is made once they are done:
 * the gate comes back up with its inner door open on an arrest, the door shuts on the two of them, nobody is
 * scanned; the officer gone, whoever is left shut in is.
 */
/datum/unit_test/voidcrew_trader_checkpoint/police_scan_after/Run()
	TEST_ASSERT(fixture(FALSE), "Could not prepare the checkpoint")
	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/officer/cop = key_officer(chamber[1])
	var/mob/living/carbon/human/suspect = visitor(chamber[2])
	police_pin_warrant(host.police, suspect.mind, 40)
	TEST_ASSERT(checkpoint.police_at_work(), "Fixture: the police are not at work")
	// The gate down and its inner door open, as the officer came in by it
	checkpoint.disabled_until = world.time + 1800
	TEST_ASSERT(checkpoint.open_freely(inner), "Fixture: the inner door of a gate that is down did not open")
	sleep(1.5 SECONDS)
	TEST_ASSERT(!inner.density, "Fixture: the inner door is not open")
	// The gate comes back up: the inner door shuts on them, and the scan that is due waits
	checkpoint.disabled_until = world.time - 1
	checkpoint.end_disable()
	TEST_ASSERT(wait_shut(inner, 5 SECONDS), "The inner door of a mended gate did not shut")
	sleep(0.5 SECONDS)
	TEST_ASSERT_EQUAL(checkpoint.state, "idle", "A chamber the police were at work in was scanned") // CHECKPOINT_IDLE
	// The officer is done and gone, the doors still shut: who is left is scanned
	cop.forceMove(lobby)
	var/scanned = FALSE
	for(var/i in 1 to 100)
		if(checkpoint.state == "scanning" || checkpoint.state == "rejecting") // CHECKPOINT_SCANNING, CHECKPOINT_REJECTING
			scanned = TRUE
			break
		sleep(0.1 SECONDS)
	TEST_ASSERT(scanned, "Someone left shut in the chamber when the police were done was never scanned (checkpoint [checkpoint.state])")

/**
 * The officer making an arrest gets to its suspect in the chamber past a colleague standing in the only place beside
 * them: the two trade places. (Anyone else's walk ends beside whoever is on the tile it wanted: police_movement.dm.)
 */
/datum/unit_test/voidcrew_trader_checkpoint/police_arrest_place/Run()
	TEST_ASSERT(fixture(FALSE), "Could not prepare the checkpoint")
	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/officer/lead = key_officer(lobby)
	var/datum/outpost_police/police = host.police
	// In the chamber, on the tile between its doors: from the lobby the only place beside them is the outer doorway
	var/mob/living/carbon/human/suspect = visitor(chamber[1])
	var/datum/outpost_warrant/warrant = police_pin_warrant(police, suspect.mind, 40)
	var/datum/outpost_police_case/case = police.open_case(warrant)
	police.sleep_tick()
	TEST_ASSERT_EQUAL(case?.arresting(), lead, "Fixture: the officer in the lobby did not take the arrest")
	// A colleague not on the arrest got there first and stands in that doorway
	lead.ai_controller.set_movement_target(type, suspect)
	lead.ai_controller.set_blackboard_key(BB_CURRENT_MIN_MOVE_DISTANCE, 1)
	outer.bumpopen(lead)
	sleep(1.5 SECONDS)
	TEST_ASSERT(!outer.density, "Fixture: the officer's key did not open the outer door")
	var/turf/doorway = get_turf(outer)
	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/officer/other = key_officer(doorway)
	TEST_ASSERT_NULL(other.case, "Fixture: the colleague is on the arrest")
	TEST_ASSERT(!lead.Adjacent(suspect), "Fixture: the suspect is in reach from the lobby")
	lead.Move(doorway, NORTH)
	TEST_ASSERT_EQUAL(get_turf(lead), doorway, "The officer making the arrest did not get the place beside its suspect from a colleague standing in it")
	TEST_ASSERT_EQUAL(get_turf(other), lobby, "The colleague did not trade places with the officer making the arrest")
	TEST_ASSERT(lead.Adjacent(suspect), "From the place it traded for, the officer making the arrest cannot reach its suspect")
	// The colleague walking back into it gets nothing: nobody trades with the officer making the arrest
	other.ai_controller.set_movement_target(type, suspect)
	other.ai_controller.set_blackboard_key(BB_CURRENT_MIN_MOVE_DISTANCE, 1)
	COOLDOWN_RESET(other, police_swap_cooldown)
	other.Move(doorway, NORTH)
	TEST_ASSERT_EQUAL(get_turf(lead), doorway, "A colleague took the place back from the officer making the arrest")
	police.close_case(suspect.mind)

/**
 * Last seen in the scan chamber and seen by nobody since: the first officer is sent into the chamber itself, the next
 * to its door; a look from outside the door is no look into it, and the place goes to another officer.
 */
/datum/unit_test/voidcrew_trader_checkpoint/police_search_inside/Run()
	TEST_ASSERT(fixture(FALSE), "Could not prepare the checkpoint")
	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/officer/first = key_officer(lobby)
	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/officer/second = key_officer(locate(lobby.x - 1, lobby.y, lobby.z))
	var/datum/outpost_police/police = host.police
	var/mob/living/carbon/human/suspect = visitor(secured)
	var/datum/outpost_warrant/warrant = police_pin_warrant(police, suspect.mind, 40)
	warrant.last_seen_turf = chamber[2]
	warrant.last_seen_at = world.time
	warrant.unseen_since = world.time
	TEST_ASSERT_EQUAL(police.search_gate(chamber[2]), checkpoint, "The police do not know a chamber tile for the checkpoint's")
	TEST_ASSERT_EQUAL(police.search_gate(get_turf(outer)), checkpoint, "The police do not know a doorway for the checkpoint's")
	TEST_ASSERT_NULL(police.search_gate(lobby), "The police take the lobby for part of the checkpoint")
	TEST_ASSERT_EQUAL(police.search_start(chamber[2], first), lobby, "With the gate working the search for someone last seen in the chamber does not start on the lobby side")
	TEST_ASSERT_EQUAL(police.search_place(warrant, first), chamber[2], "The first officer was not sent into the chamber they were last seen in")
	TEST_ASSERT_EQUAL(police.search_place(warrant, second), lobby, "The second officer was not sent to the chamber's door")
	var/datum/outpost_police_search/search = police.searches[suspect.mind]
	TEST_ASSERT_NOTNULL(search, "No search was started")
	// A look from the lobby, the door between: not a look into the chamber
	police.search_looked(warrant, first, lobby)
	TEST_ASSERT(!search.done[chamber[2]], "A look from outside its door counted as a look into the chamber")
	police.search_looked(warrant, second, lobby)
	TEST_ASSERT(search.done[lobby], "A look from the lobby side did not count for the lobby side")
	TEST_ASSERT_EQUAL(police.search_place(warrant, second), chamber[2], "The chamber did not go to the next officer")
	police.search_looked(warrant, second, chamber[1])
	TEST_ASSERT(search.done[chamber[2]], "A look from inside the chamber did not count")
	// In someone's sight in there (a colleague inside, the scanner): the officer making the arrest is sent in to them,
	// everyone else to the door
	warrant.unseen_since = 0
	var/datum/outpost_police_case/case = police.open_case(warrant)
	police.sleep_tick()
	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/lead = case?.arresting()
	TEST_ASSERT_NOTNULL(lead, "Fixture: no officer took the arrest")
	TEST_ASSERT_EQUAL(police.search_place(warrant, lead), chamber[2], "With eyes on someone in the chamber the officer making the arrest was sent to its door, not in to them")
	// Out of sight again with the arrest open: the chamber is for the arrest's officer to look into, nobody else
	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/officer/fourth = key_officer(locate(lobby.x + 1, lobby.y, lobby.z))
	TEST_ASSERT_NULL(fourth.case, "Fixture: an officer made after the arrest opened is on it")
	warrant.last_seen_at = world.time + 1
	warrant.unseen_since = world.time
	TEST_ASSERT(police.search_place(warrant, fourth) != chamber[2], "With an arrest open, an officer not on it was sent into the chamber ahead of the one making it")
	TEST_ASSERT_EQUAL(police.search_place(warrant, lead), chamber[2], "With an arrest open, its officer was not sent into the chamber they were last seen in")
	warrant.unseen_since = 0
	qdel(fourth)
	// From where its outer door cannot be walked to (a hatch onto the hull, seen from the concourse) the door is as far
	// as anyone is sent while the gate works; with the gate down the inner door is a way in
	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/officer/third = key_officer(secured)
	QDEL_NULL(police.search_main)
	TEST_ASSERT_NULL(police.search_inside(chamber[2], third), "An officer is sent into a working gate's chamber whose outer door it cannot walk to")
	TEST_ASSERT_EQUAL(police.search_place(warrant, third), secured, "With eyes on someone in the chamber an officer not on the arrest was not sent to its door")
	checkpoint.disabled_until = world.time + 1800
	TEST_ASSERT_EQUAL(police.search_inside(chamber[2], third), chamber[2], "With the gate down the chamber is not somewhere an officer on the concourse is sent into")
	checkpoint.disabled_until = 0
	police.close_case(suspect.mind)
	qdel(third)
	// No part of the floor: an officer who stood in it while the floor was read does not make it one
	first.forceMove(chamber[1])
	QDEL_NULL(police.search_main)
	var/datum/outpost_police_floor/floor = police.search_floor(lobby, first)
	TEST_ASSERT_NOTNULL(floor, "The floor was not read")
	TEST_ASSERT(!floor.walkable[chamber[1]] && !floor.walkable[chamber[2]] && !floor.walkable[get_turf(outer)], "The scan chamber was read as part of the floor officers walk")

/**
 * A close of a door left over from an earlier cycle (a retry queued while the door was shutting) that lands as the
 * outer door opens again took the door, still solid partway through opening, for shut: the checkpoint went idle and
 * dropped the timer that would have shut it, and the outer door stood open for good (pass 3: chamber/halcyon_down and
 * chamber/halcyon_working, now and then). Here the leftover call is made by hand at that moment, so it happens every
 * time: the outer door still shuts after its hold, and nobody inside is scanned with it open.
 */
/datum/unit_test/voidcrew_trader_checkpoint/stale_close

/datum/unit_test/voidcrew_trader_checkpoint/stale_close/Run()
	TEST_ASSERT(fixture(FALSE), "Could not prepare the checkpoint")
	var/mob/living/carbon/human/walker = visitor(lobby)
	// The outer door's own leftover close
	TEST_ASSERT(checkpoint.request_outer(walker), "Fixture: the outer door would not open")
	TEST_ASSERT(outer.density && outer.operating, "Fixture: the outer door is not partway open")
	checkpoint.close_door(outer)
	sleep(1.5 SECONDS)
	TEST_ASSERT(!outer.density, "Fixture: the outer door did not open")
	TEST_ASSERT(wait_shut(outer, 8 SECONDS), "A leftover close landing as the outer door opened left it open (checkpoint [checkpoint.state])")
	TEST_ASSERT_EQUAL(checkpoint.state, "idle", "The checkpoint is not idle after the outer door shut") // CHECKPOINT_IDLE
	settle()
	// The inner door's leftover close, someone in the chamber
	var/mob/living/carbon/human/inside = visitor(chamber[2])
	TEST_ASSERT(checkpoint.request_outer(walker), "Fixture: the outer door would not open a second time")
	TEST_ASSERT(outer.density && outer.operating, "Fixture: the outer door is not partway open the second time")
	checkpoint.close_door(inner)
	TEST_ASSERT_EQUAL(checkpoint.state, "idle", "The chamber scanned with its outer door opening") // CHECKPOINT_IDLE
	sleep(1.5 SECONDS)
	TEST_ASSERT(!outer.density, "Fixture: the outer door did not open the second time")
	TEST_ASSERT(wait_shut(outer, 8 SECONDS), "A leftover close of the inner door landing as the outer door opened left it open (checkpoint [checkpoint.state])")
	TEST_ASSERT_NOTNULL(inside, "The visitor in the chamber went missing")

/**
 * Halcyon's working lobby gate: someone wanted stands refused in the scan chamber, and a friend of theirs stands in
 * combat mode in the outer doorway, the only way in. The officer coming for the suspect walks into the friend: the
 * friend is told to make way, and charged with resisting only some seconds after that, if they are still there.
 */
/datum/unit_test/voidcrew_outpost_police_search/chamber/halcyon_doorway

/datum/unit_test/voidcrew_outpost_police_search/chamber/halcyon_doorway/Run()
	var/obj/structure/overmap/trader_outpost/outpost = search_outpost(/obj/structure/overmap/trader_outpost/general)
	if(!outpost)
		return
	var/datum/outpost_police/police = outpost.police
	var/datum/outpost_checkpoint/post = outpost.lobby_checkpoint()
	TEST_ASSERT_NOTNULL(post?.sensor, "Halcyon has no lobby checkpoint with a scanner")
	var/turf/stand
	for(var/turf/tile as anything in post.chamber_turfs)
		if(!tile.is_blocked_turf(exclude_mobs = TRUE) && (!stand || get_dist(tile, post.outer_door) > get_dist(stand, post.outer_door)))
			stand = tile
	TEST_ASSERT_NOTNULL(stand, "Halcyon: no free tile in the scan chamber")
	duty_officer(outpost, /mob/living/carbon/human/npc/ambient_npc/outpost/police/sergeant, police.desk_turf)
	beat_officers(outpost)
	var/mob/living/carbon/human/suspect = wanted_at(outpost, stand, stand, 40)
	TEST_ASSERT(post.request_cycle(suspect), "Halcyon: the chamber would not scan someone standing in it")
	sleep(4 SECONDS)
	TEST_ASSERT_EQUAL(post.state, "rejecting", "Halcyon: the gate did not refuse someone wanted") // CHECKPOINT_REJECTING
	TEST_ASSERT(!post.outer_door.density, "Halcyon: the outer door did not open for someone refused")
	var/mob/living/carbon/human/friend = dispatch_suspect(outpost, 0, get_turf(post.outer_door))
	friend.set_combat_mode(TRUE)
	police.wake()

	var/started = world.time
	var/told_at = 0
	var/charged_at = 0
	while(world.time - started < 90 SECONDS && !charged_at)
		var/datum/outpost_police_case/case = police.cases[suspect.mind]
		var/list/entry = case ? LAZYACCESS(case.blockers, WEAKREF(friend.mind)) : null
		if(!told_at && length(entry) && entry[1])
			told_at = entry[1]
		var/datum/outpost_warrant/friend_warrant = police.get_warrant(friend.mind)
		if(friend_warrant?.heat > 0)
			charged_at = world.time
		for(var/datum/outpost_pending_report/pending as anything in police.pending_reports)
			if(pending.offender?.resolve() == friend && pending.crime == "resist") // OUTPOST_CRIME_RESIST
				charged_at = world.time
		if(get_turf(friend) != get_turf(post.outer_door))
			break
		sleep(0.5 SECONDS)
	var/datum/outpost_police_case/case = police.cases[suspect.mind]
	var/report = "arrest [case ? "on its \"[case.step]\" step" : "never opened"], [gate_report(post)]. [officers_report(outpost)]"
	TEST_ASSERT_EQUAL(get_turf(friend), get_turf(post.outer_door), "The friend in the doorway was moved off it ([report])")
	TEST_ASSERT(told_at, "The friend standing in the gate's only doorway was never told to make way in 90 s ([report])")
	TEST_ASSERT(charged_at, "The friend who stayed in the gate's only doorway after being told was never charged ([report])")
	TEST_ASSERT(charged_at - told_at >= 4 SECONDS, "The friend in the doorway was charged [(charged_at - told_at) / 10] s after being told, with no time to step aside") // CASE_BLOCK_GRACE
	police.sleep_tick()
	dispatch_clear(police)

/**
 * Halcyon's working lobby gate, three stars: someone wanted stands in the scan chamber, on its tile furthest from the
 * outer door. No arrest opens on someone on their feet at three stars, and the scanner keeps them in the police's sight
 * the whole time. An officer still comes into the chamber, or gets them in its own sight, within 40 s. The pass 11 soak
 * (four_star_crawl): every officer stood at the outer door for 45 s and more while the suspect stood 2 tiles off.
 */
/datum/unit_test/voidcrew_outpost_police_search/chamber/halcyon_three_stars

/datum/unit_test/voidcrew_outpost_police_search/chamber/halcyon_three_stars/Run()
	var/obj/structure/overmap/trader_outpost/outpost = search_outpost(/obj/structure/overmap/trader_outpost/general)
	if(!outpost)
		return
	var/datum/outpost_police/police = outpost.police
	var/datum/outpost_checkpoint/post = outpost.lobby_checkpoint()
	TEST_ASSERT_NOTNULL(post?.sensor, "Halcyon has no lobby checkpoint with a scanner")
	var/turf/stand
	for(var/turf/tile as anything in post.chamber_turfs)
		if(!tile.is_blocked_turf(exclude_mobs = TRUE) && (!stand || get_dist(tile, post.outer_door) > get_dist(stand, post.outer_door)))
			stand = tile
	TEST_ASSERT_NOTNULL(stand, "Halcyon: no free tile in the scan chamber")
	duty_officer(outpost, /mob/living/carbon/human/npc/ambient_npc/outpost/police/sergeant, police.desk_turf)
	beat_officers(outpost)
	// Heat 60 is three stars
	var/mob/living/carbon/human/suspect = wanted_at(outpost, stand, stand, 60)
	police.wake()

	var/started = world.time
	var/reached_after = -1
	while(world.time - started < 40 SECONDS)
		for(var/mob/living/carbon/human/npc/ambient_npc/outpost/police/officer in police.officers)
			if(officer.stat == CONSCIOUS && (in_gate(post, officer) || police.perception.sees(officer, suspect)))
				reached_after = world.time - started
				break
		if(reached_after >= 0)
			break
		sleep(0.5 SECONDS)
	var/datum/outpost_police_case/case = police.cases[suspect.mind]
	police.sleep_tick()
	TEST_ASSERT(reached_after >= 0, "Halcyon, three stars, standing in the scan chamber: no officer came into it or had them in its own sight in 40 s ([police.get_stars(suspect.mind)] stars, arrest [case ? "on its \"[case.step]\" step" : "none"], [gate_report(post)]). [officers_report(outpost)]")
	log_test("Halcyon, three stars in the scan chamber: an officer in it or with them in sight after [reached_after / 10] s")
	dispatch_clear(police)
