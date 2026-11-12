/**
 * Outpost jobs (voidcrew/modules/outpost_jobs/): helpers every outpost jobs test uses.
 * Owner: P0 seams, frozen. Package tests live in voidcrew_outpost_jobs_<package>.dm.
 *
 * Fork defines are included after the tests, so a test uses the literal value with a comment naming the
 * define. Tests call procs with the mobs already in place and step clocks by writing times; none waits for an
 * AI walk.
 *
 * What is here:
 * - jobs_outpost(): a fake trader outpost over the test room, with its police on the fake witness switch
 *   (/datum/outpost_police_perception/jobs_test: `seen`, `delay`, `can_report_now`, `witness`).
 * - jobs_spot(), jobs_person(), jobs_ship() and jobs_cleanup(): tiles, people with minds, a ship with a crew record
 *   and an account, and taking the ships apart again.
 * - jobs_cells(): two holding cells built on the test room for any police (the police cell tests' layout).
 * - /datum/jobs_test_listener: writes down every signal it is registered for.
 */

// ===== THE FAKE WITNESS SWITCH =====

/**
 * The police's witness test, set by hand. While `seen` every crime is witnessed (by `witness`, or else a turf by
 * the offender, which never dies), reported after `delay`; while not `seen` nobody saw anything. `can_report_now`
 * FALSE keeps a waiting report waiting (a witness out cold) until it lapses.
 */
/datum/outpost_police_perception/jobs_test
	var/seen = TRUE
	var/delay = 0
	var/can_report_now = TRUE
	/// Who saw it; null for the offender's turf
	var/atom/witness

/datum/outpost_police_perception/jobs_test/Destroy()
	witness = null
	return ..()

/datum/outpost_police_perception/jobs_test/witness_of(mob/living/offender, crime, atom/victim, obj/item/source)
	last_witness = null
	last_witnesses = null
	if(!seen || !offender)
		return 0 // POLICE_WITNESS_NONE
	last_witness = witness || get_turf(offender)
	return 1 // POLICE_WITNESS_SAW

/datum/outpost_police_perception/jobs_test/report_delay(atom/witness, crime)
	return delay

/datum/outpost_police_perception/jobs_test/reports_by_call(atom/witness)
	return FALSE

/datum/outpost_police_perception/jobs_test/can_report(atom/witness)
	return can_report_now

// ===== FIXTURES =====

/// A fake trader outpost over the test room (a `size` by `size` template from its corner), its police on the fake witness switch
/datum/unit_test/proc/jobs_outpost(size = 20)
	var/obj/structure/overmap/trader_outpost/outpost = allocate(/obj/structure/overmap/trader_outpost)
	outpost.outpost_template = allocate(/datum/map_template/trader_outpost)
	outpost.outpost_template.width = size
	outpost.outpost_template.height = size
	outpost.template_bottom_left = run_loc_floor_bottom_left
	var/datum/outpost_police/police = outpost.police
	if(!police)
		TEST_FAIL("The fake trader outpost has no police")
		return outpost
	var/datum/outpost_police_perception/jobs_test/witness_switch = new(police)
	qdel(police.perception)
	police.perception = witness_switch
	return outpost

/// The fake witness switch of `outpost`'s police
/datum/unit_test/proc/jobs_witness(obj/structure/overmap/trader_outpost/outpost)
	return outpost?.police?.perception

/// The test room's tile `dx`, `dy` from its corner
/datum/unit_test/proc/jobs_spot(dx, dy)
	return locate(run_loc_floor_bottom_left.x + dx, run_loc_floor_bottom_left.y + dy, run_loc_floor_bottom_left.z)

/// A conscious human with a mind at `where`
/datum/unit_test/proc/jobs_person(turf/where)
	var/mob/living/carbon/human/person = allocate(/mob/living/carbon/human/consistent, where)
	person.mind_initialize()
	allocated += person.mind
	return person

/**
 * A ship with an account holding `balance`, its team and crew record. Each of `people` (mobs with minds) joins
 * the crew. Take it apart with jobs_cleanup().
 */
/datum/unit_test/proc/jobs_ship(list/people, balance = 0)
	var/obj/structure/overmap/ship/ship = allocate(/obj/structure/overmap/ship)
	var/datum/team/voidcrew/team = allocate(/datum/team/voidcrew)
	team.ship = ship
	ship.ship_team = team
	var/datum/bank_account/account = allocate(/datum/bank_account, "Jobs test [REF(ship)]", null, 1, FALSE)
	account.account_balance = balance
	ship.ship_account = account
	for(var/mob/living/person as anything in people)
		team.join_member(person.mind)
	return ship

/// Takes the ships' teams and their crew records apart, or none of them is ever collected
/datum/unit_test/proc/jobs_cleanup(list/ships)
	for(var/obj/structure/overmap/ship/ship as anything in ships)
		var/datum/team/voidcrew/team = ship.ship_team
		if(!team)
			continue
		var/datum/voidcrew_crew_record/record = team.crew_record
		for(var/datum/mind/member as anything in team.members.Copy())
			team.remove_member(member)
		team.ship = null
		ship.ship_team = null
		if(record)
			qdel(record)

/**
 * Two holding cells for `police` on the test room, built the way link_interior() builds them: cell "a" is 2x2 at
 * the bottom left with its door east of the bottom row (the lobby tile outside is x+3); cell "b" is 1x2, three rows
 * up. Returns cell "a".
 */
/datum/unit_test/proc/jobs_cells(datum/outpost_police/police)
	var/list/landmarks = list()
	for(var/list/spot in list(list(0, 0, "a"), list(1, 0, "a"), list(0, 1, "a"), list(1, 1, "a"), list(0, 3, "b"), list(1, 3, "b")))
		var/obj/effect/landmark/outpost_police_cell/mark = allocate(/obj/effect/landmark/outpost_police_cell, jobs_spot(spot[1], spot[2]))
		mark.cell_id = spot[3]
		landmarks += mark
	var/obj/machinery/door/airlock/outpost/glass/police_cell/door_a = allocate(/obj/machinery/door/airlock/outpost/glass/police_cell, jobs_spot(2, 0))
	door_a.cell_id = "a"
	var/obj/machinery/door/airlock/outpost/glass/police_cell/door_b = allocate(/obj/machinery/door/airlock/outpost/glass/police_cell, jobs_spot(2, 3))
	door_b.cell_id = "b"
	police.build_cells(landmarks, list(door_a, door_b), list())
	for(var/datum/outpost_police_cell/cell in police.cells)
		if(cell.cell_id == "a")
			return cell
	TEST_FAIL("The test cells did not assemble")
	return null

// ===== A SIGNAL LISTENER =====

/// Writes down every signal it is registered for (one signal per listener reads best): `heard` holds each call's args, source dropped, in order
/datum/jobs_test_listener
	var/list/heard = list()

/datum/jobs_test_listener/proc/listen(datum/source, signal)
	RegisterSignal(source, signal, PROC_REF(on_signal))

/datum/jobs_test_listener/proc/on_signal(datum/source, ...)
	SIGNAL_HANDLER
	var/list/entry = args.Copy(2)
	heard += list(entry)

/// The last call's args, or null
/datum/jobs_test_listener/proc/last()
	return length(heard) ? heard[length(heard)] : null
