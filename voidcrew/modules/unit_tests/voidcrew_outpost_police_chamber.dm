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

/// The doors and the state of `post`, for a failure message
/datum/unit_test/voidcrew_outpost_police_search/chamber/proc/gate_report(datum/outpost_checkpoint/post)
	return "checkpoint [post.state], outer door [post.outer_door.density ? "shut" : "open"], inner door [post.inner_door.density ? "shut" : "open"]"

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
	while(world.time - started < 20 SECONDS && (!post.outer_door.density || !post.inner_door.density || post.state != "idle")) // CHECKPOINT_IDLE
		sleep(0.5 SECONDS)
	TEST_ASSERT(post.outer_door.density && post.inner_door.density && post.state == "idle", "[outpost_type], [gate]: 20 s after the arrest the gate has not settled ([gate_report(post)])")
	var/mob/living/carbon/human/visitor = dispatch_suspect(outpost, 0, post.lobby_turf)
	TEST_ASSERT(post.request_outer(visitor), "[outpost_type], [gate]: after the arrest the outer door would not open for a visitor")
	sleep(2 SECONDS)
	TEST_ASSERT(!post.outer_door.density, "[outpost_type], [gate]: after the arrest the outer door did not open for a visitor")
	visitor.forceMove(stand)
	started = world.time
	while(world.time - started < 20 SECONDS && (post.inner_door.density || post.state != "passing")) // CHECKPOINT_PASSING
		sleep(0.5 SECONDS)
	TEST_ASSERT(!post.inner_door.density && post.state == "passing", "[outpost_type], [gate]: after the arrest a visitor with nothing on them was not let through in 20 s ([gate_report(post)])")
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
