/**
 * Outpost police soak: the scenarios. The harness is in voidcrew_outpost_police_soak.dm, the invariants in
 * voidcrew_outpost_police_soak_invariants.dm.
 *
 * A scenario is what the suspect does; the police do the rest by themselves. To add one:
 *
 *	POLICE_SOAK_SCENARIO(my_scenario)
 *	/datum/police_soak_scenario/my_scenario/play(datum/police_soak/run)
 *		run.punch_townsperson(2)
 *		run.stand(60 SECONDS)
 *
 * The macro makes the scenario and its test, /datum/unit_test/voidcrew_police_soak/my_scenario, which plays it on
 * all three real outposts at once. Add the test's path to voidcrew/modules/unit_tests/voidcrew_outpost_police_soak.txt. The verbs a script has are
 * the procs under "THE SUSPECT'S HANDS AND FEET" in the harness: go_to(), go_up_to(), click(), punch_townsperson(),
 * emag_gate(), shove_down(), grab(), give_up(), stand(), wait_for(), ride_to_hangar(). All of them are tg's own
 * click or step; none sets a state on anyone.
 */

/datum/police_soak_scenario
	/// Its name in the trace file and the break reports
	var/name
	/// Game time the script may take before the test gives up on it
	var/limit = 4 MINUTES
	/// Invariant types that do not apply to this scenario
	var/list/skipped_invariants

/// Where the suspect starts, or null for the concourse side of the gate (where a visitor steps in)
/datum/police_soak_scenario/proc/start_turf(datum/police_soak/run, datum/outpost_checkpoint/post)
	return null

/// The script: what the suspect does. It may sleep.
/datum/police_soak_scenario/proc/play(datum/police_soak/run)
	return

#define POLICE_SOAK_SCENARIO(scenario) /datum/unit_test/voidcrew_police_soak/##scenario {\
	scenario_type = /datum/police_soak_scenario/##scenario; \
} \
/datum/police_soak_scenario/##scenario {\
	name = #scenario; \
}

// ----- nothing at all: the beat, the doors and the crowd by themselves -----

POLICE_SOAK_SCENARIO(quiet_visit)

/datum/police_soak_scenario/quiet_visit/play(datum/police_soak/run)
	run.stand(75 SECONDS)

// ----- commit a seen crime and stand still -----

POLICE_SOAK_SCENARIO(seen_crime_stand_still)

/datum/police_soak_scenario/seen_crime_stand_still/play(datum/police_soak/run)
	if(!run.punch_townsperson(2))
		return
	run.give_up()
	run.stand(100 SECONDS)

// ----- commit a crime, run to the far end of the outpost and stand out of sight -----
// The owner's own crime: an emag on the gate's scanner, from the scanner room (two stars).

POLICE_SOAK_SCENARIO(crime_then_hide)

/datum/police_soak_scenario/crime_then_hide/start_turf(datum/police_soak/run, datum/outpost_checkpoint/post)
	return run.scanner_room_tile(post)

/datum/police_soak_scenario/crime_then_hide/play(datum/police_soak/run)
	if(!run.emag_gate())
		return
	run.wait_for("wanted", 15 SECONDS)
	var/turf/corner = run.far_corner()
	if(!corner)
		run.script_failed("no far corner of the concourse out of the officers' sight to run to")
		return
	if(!run.go_to(corner, 0, 60 SECONDS))
		run.script_failed("could not run to the far corner at [run.where(corner)] (got to [run.where(run.suspect)])")
	run.note(">>", "stands at [run.where(run.suspect)], [get_dist(run.suspect, run.police.get_warrant(run.suspect.mind)?.last_seen_turf)] tiles from where the police last saw them")
	run.stand(90 SECONDS)

// ----- the owner's first minute: the gate emag, then stay in the scanner room -----

POLICE_SOAK_SCENARIO(gate_emag_stay)

/datum/police_soak_scenario/gate_emag_stay/start_turf(datum/police_soak/run, datum/outpost_checkpoint/post)
	return run.scanner_room_tile(post)

/datum/police_soak_scenario/gate_emag_stay/play(datum/police_soak/run)
	if(!run.emag_gate())
		return
	run.stand(100 SECONDS)

// ----- the gate emag, then through the open gate and stand just inside the concourse -----

POLICE_SOAK_SCENARIO(gate_emag_step_in)

/datum/police_soak_scenario/gate_emag_step_in/start_turf(datum/police_soak/run, datum/outpost_checkpoint/post)
	return run.scanner_room_tile(post)

/datum/police_soak_scenario/gate_emag_step_in/play(datum/police_soak/run)
	if(!run.emag_gate())
		return
	run.stand(5 SECONDS)
	var/datum/outpost_checkpoint/post = run.outpost.lobby_checkpoint(null)
	if(!run.go_to(post.secured_turf, 0, 30 SECONDS))
		run.script_failed("could not walk through the open gate to [run.where(post.secured_turf)] (got to [run.where(run.suspect)])")
	run.stand(95 SECONDS)

// ----- shove an officer down, then another -----

POLICE_SOAK_SCENARIO(shove_officers)

/datum/police_soak_scenario/shove_officers/play(datum/police_soak/run)
	var/list/shoved = list()
	for(var/turn in 1 to 2)
		var/mob/living/officer = run.nearest_officer(shoved)
		if(!officer)
			run.script_failed("no [turn == 1 ? "officer" : "second officer"] on their feet to shove")
			break
		shoved += officer
		if(!run.go_up_to(officer, 45 SECONDS))
			run.script_failed("could not walk up to [run.who(officer)] at [run.where(officer)]")
			continue
		if(!run.shove_down(officer))
			run.script_failed("could not shove [run.who(officer)] down")
		run.stand(4 SECONDS)
	run.stand(60 SECONDS)

// ----- get stunned and lie there; get up when the stun ends -----

POLICE_SOAK_SCENARIO(stunned_then_up)

/datum/police_soak_scenario/stunned_then_up/play(datum/police_soak/run)
	if(!run.punch_townsperson(2))
		return
	// Does not give up: fists stay up and they keep stepping about until an officer puts them down
	var/until = world.time + 75 SECONDS
	while(world.time < until && !run.finished && !run.is_now("down") && !run.is_now("cuffed"))
		run.fidget()
		sleep(1 SECONDS)
	if(!run.is_now("down"))
		run.script_failed("nobody put a suspect who would not give up on the floor in 75s")
	else
		run.note(">>", "is down at [run.where(run.suspect)]; lies there")
	// A body gets up by itself when the stun ends
	run.wait_for("up", 60 SECONDS)
	run.stand(45 SECONDS)

// ----- be cuffed, walked to the desk and jailed; shove the officer in the cell once uncuffed; walk out of the cell -----

POLICE_SOAK_SCENARIO(jailed_shove_walk_out)

/datum/police_soak_scenario/jailed_shove_walk_out
	limit = 7 MINUTES

/datum/police_soak_scenario/jailed_shove_walk_out/play(datum/police_soak/run)
	if(!run.punch_townsperson(2))
		return
	run.give_up()
	if(!run.wait_for("uncuffed in a cell", 240 SECONDS))
		run.script_failed("was not in a cell with the cuffs off within 240s of giving up")
		return
	// The moment the cuffs come off: a shove for the officer who brought them in
	var/mob/living/officer = run.nearest_officer()
	if(officer && get_dist(officer, run.suspect) <= 2)
		if(!run.shove_down(officer, 4))
			run.note(">>", "[run.who(officer)] did not go down")
	else
		run.script_failed("no officer within reach when the cuffs came off (nearest: [run.who(officer)] at [run.where(officer)])")
	run.stand(25 SECONDS)
	// Out of the cell, if the door lets them
	var/datum/outpost_police_cell/cell = run.police.cell_holding(run.suspect.mind)
	if(cell?.outside_turf)
		if(run.go_to(cell.outside_turf, 0, 15 SECONDS))
			run.note(">>", "walked out of cell [cell.cell_id]")
		else
			run.note(">>", "could not walk out of cell [cell.cell_id]: the door stayed shut")
	run.stand(60 SECONDS)

// ----- take one of the outpost's people hostage at gunpoint and hold them past a minute -----

POLICE_SOAK_SCENARIO(hostage)

/datum/police_soak_scenario/hostage/play(datum/police_soak/run)
	var/mob/living/local = run.townsperson()
	if(!local)
		run.script_failed("no townsperson to take hostage")
		return
	var/obj/item/gun/ballistic/automatic/pistol/gun = run.test.allocate(/obj/item/gun/ballistic/automatic/pistol, get_turf(run.suspect))
	run.suspect.put_in_active_hand(gun, forced = TRUE)
	run.note(">>", "draws a pistol")
	if(!run.go_up_to(local, 45 SECONDS))
		run.script_failed("could not walk up to [local] at [run.where(local)]")
		return
	// tg's neck grab with a gun in hand is the hold (stealth_hostage_of())
	var/got_hold = run.grab(local, GRAB_NECK, 45 SECONDS)
	// tg brings someone held by the neck onto the holder's tile as the holder moves: a step or two
	for(var/shuffle in 1 to 4)
		if(!got_hold || stealth_hostage_of(run.suspect) == local)
			break
		run.fidget()
		sleep(5)
	if(!got_hold || stealth_hostage_of(run.suspect) != local)
		run.script_failed("could not get [run.who(local)] by the neck with tg's grab in 45s (grab state [run.suspect.grab_state], holding [run.who(run.suspect.pulling)])")
		run.stand(30 SECONDS)
		return
	run.note(">>", "holds [run.who(local)] ([local.real_name]) hostage at gunpoint at [run.where(run.suspect)]")
	// OUTPOST_POLICE_STANDOFF_MAX is one minute
	var/until = world.time + 85 SECONDS
	var/said_lost = FALSE
	while(world.time < until && !run.finished)
		if(!said_lost && stealth_hostage_of(run.suspect) != local)
			said_lost = TRUE
			run.note(">>", "no longer holds the hostage")
		sleep(1 SECONDS)

// ----- walk to the hangar and wait -----
// Wanted first (the gate emag), then down the public lift to a berth.

POLICE_SOAK_SCENARIO(hangar_wait)

/datum/police_soak_scenario/hangar_wait/start_turf(datum/police_soak/run, datum/outpost_checkpoint/post)
	return run.scanner_room_tile(post)

/datum/police_soak_scenario/hangar_wait/play(datum/police_soak/run)
	if(!run.emag_gate())
		return
	run.wait_for("wanted", 15 SECONDS)
	if(!run.ride_to_hangar())
		return
	run.stand(100 SECONDS)

// ----- a full scanner room while more of the outpost's people arrive -----
// The owner's report: people waiting in the door while four stand in the scanner room. Visitors fill the room but
// for one tile, townspeople come up the lift behind the suspect, and the suspect takes the last tile, leaving the
// outer door open behind them.

POLICE_SOAK_SCENARIO(crowded_gate)

/datum/police_soak_scenario/crowded_gate/start_turf(datum/police_soak/run, datum/outpost_checkpoint/post)
	return post?.lobby_turf

/datum/police_soak_scenario/crowded_gate/play(datum/police_soak/run)
	var/datum/outpost_checkpoint/post = run.outpost.lobby_checkpoint(null)
	var/list/turf/free = list()
	for(var/turf/tile as anything in post?.chamber_turfs)
		if(!tile.is_blocked_turf(TRUE))
			free += tile
	if(!length(free))
		run.script_failed("the scanner room has no free tile")
		return
	// The tile left for the suspect: the one nearest the outer door
	var/turf/last_tile = free[1]
	for(var/turf/tile as anything in free)
		if(get_dist(tile, post.outer_door) < get_dist(last_tile, post.outer_door))
			last_tile = tile
	var/others = 0
	for(var/turf/tile as anything in free - last_tile)
		if(others >= 3)
			break
		run.test.police_arrest_person(tile)
		others++
	run.note(">>", "[others] other visitors stand in the scanner room ([length(post.chamber_turfs)] tiles); one tile is left at [run.where(last_tile)]")
	run.arrival()
	run.stand(6 SECONDS)
	run.arrival()
	run.stand(4 SECONDS)
	if(!run.go_to(last_tile, 0, 20 SECONDS))
		run.script_failed("could not step into the scanner room at [run.where(last_tile)] (got to [run.where(run.suspect)])")
	run.note(">>", "stands in the scanner room at [run.where(run.suspect)]; the room is full")
	for(var/wave in 1 to 2)
		run.stand(10 SECONDS)
		run.arrival()
	run.stand(60 SECONDS)

// ----- give up at gunpoint, then bolt from the cuffs -----
// Two stars (the gate emag), then stand just inside the concourse with empty hands until the cuffs come out. Nobody
// may fire on or strike someone who stands there. Then they run for it, and are anyone's again.

POLICE_SOAK_SCENARIO(give_up_then_bolt)

/datum/police_soak_scenario/give_up_then_bolt/start_turf(datum/police_soak/run, datum/outpost_checkpoint/post)
	return run.scanner_room_tile(post)

/datum/police_soak_scenario/give_up_then_bolt/play(datum/police_soak/run)
	if(!run.emag_gate())
		return
	run.give_up()
	var/datum/outpost_checkpoint/post = run.outpost.lobby_checkpoint(null)
	if(!run.go_to(post.secured_turf, 0, 30 SECONDS))
		run.script_failed("could not walk through the open gate to [run.where(post.secured_turf)] (got to [run.where(run.suspect)])")
		return
	var/stood_at = world.time
	run.note(">>", "stands at [run.where(run.suspect)] with empty hands")
	var/until = world.time + 60 SECONDS
	while(world.time < until && !run.finished && !run.police.arrest_cuffing(run.suspect) && !run.is_now("cuffed"))
		sleep(2)
	// A shot at someone still walking, or in the air as they stopped, is fair: three seconds' grace
	var/hits = 0
	for(var/list/event as anything in run.force_events)
		if(event[1] > stood_at + 3 SECONDS)
			hits++
	if(hits)
		run.script_failed("was hit [hits] time\s while standing still with empty hands at two stars, before the cuffs were on")
	if(run.finished || !run.police.arrest_cuffing(run.suspect))
		if(!run.is_now("cuffed"))
			run.note(">>", "nobody went for the cuffs in 60s")
		run.stand(40 SECONDS)
		return
	var/turf/corner = run.far_corner()
	if(!corner)
		run.script_failed("no far corner of the concourse to run to")
		return
	run.note(">>", "bolts from the cuffs for [run.where(corner)]")
	run.go_to(corner, 0, 20 SECONDS)
	run.note(">>", "stops at [run.where(run.suspect)]")
	run.stand(75 SECONDS)

#undef POLICE_SOAK_SCENARIO
