/**
 * # Outpost police: a medic for a prisoner in crit
 *
 * Owner decision 60 (playtest, 2026-11-22). A suspect downed by the police is cuffed, searched, dragged to the desk
 * and booked in crit. The police then call one medic for them: an outpost medic comes up by the staff lift, walks
 * to the cell, is let in by the cell's own door, treats the prisoner from the same finite kit and with the same tg
 * items and procs as the recovery medic (recovery_medic.dm next_treatment() and treat()), and once the prisoner is
 * out of crit and no longer bleeding walks out, the door shuts, and they leave by the lift.
 *
 * This is the one exception to decision 31's "medics never treat a player": only a prisoner held in a police cell,
 * only while they are in crit or bleeding, and the medic stops as soon as they are not. Nobody's health is set and
 * nothing is healed that the items do not heal.
 *
 * With no medic to be had (no lift tile free, no outpost place, the recovery port shut after lost crews, already
 * OUTPOST_POLICE_CELL_MEDICS_MAX on their way) or once the one called is not coming after all (killed, blocked,
 * out of kit, out of time), the cell falls back to its medic hold: the door opens for the prisoner's own people
 * (police_cell.dm crit_prisoner()).
 */

// =========================================================================
// THE CALL (the police datum's)
// =========================================================================

/datum/outpost_police
	/// Prisoner body weakref -> weakref to the medic called for them: one medic per prisoner in crit
	var/list/cell_medics = list()

/**
 * Whether `patient` is someone a cell medic may treat: alive, in crit or bleeding, held in one of our cells and on its
 * floor. `treating_in`, the cell a medic is already on the job in: their patient may also be one whose term ran out
 * while they lay there (owner decision 104), as long as they are still on that cell's floor.
 */
/datum/outpost_police/proc/cell_patient_ok(mob/living/carbon/patient, datum/outpost_police_cell/treating_in)
	if(!iscarbon(patient) || QDELETED(patient) || !patient.mind || patient.stat == DEAD)
		return FALSE
	if(!recovery_in_crit(patient) && !patient.is_bleeding())
		return FALSE
	var/datum/outpost_police_cell/cell = cell_holding(patient.mind)
	if(treating_in)
		if(QDELETED(treating_in) || (cell && cell != treating_in))
			return FALSE
		cell = treating_in
	return !!cell && (get_turf(patient) in cell.tiles)

/// The cell `patient` is held in, or failing that the one whose floor they lie on (let out there while a medic is on the way)
/datum/outpost_police/proc/cell_of_patient(mob/living/patient)
	if(!patient)
		return null
	var/datum/outpost_police_cell/cell = patient.mind && cell_holding(patient.mind)
	if(cell)
		return cell
	cell = cell_at(get_turf(patient))
	return (cell && (get_turf(patient) in cell.tiles)) ? cell : null

/// The cell whose floor or doorway `where` is, or null
/datum/outpost_police/proc/cell_at(turf/where)
	if(!where)
		return null
	for(var/datum/outpost_police_cell/cell as anything in cells)
		if((where in cell.tiles) || (!QDELETED(cell.door) && where == get_turf(cell.door)))
			return cell
	return null

/// The medic called for `patient` while they are still on the job, or null (a claim lapses once its medic is gone, dead or done)
/datum/outpost_police/proc/cell_medic_for(mob/living/patient)
	if(!patient)
		return null
	var/datum/weakref/key = WEAKREF(patient)
	var/datum/weakref/medic_ref = cell_medics[key]
	if(!medic_ref)
		return null
	var/mob/living/carbon/human/npc/ambient_npc/outpost/recovery/medic/cell/medic = medic_ref.resolve()
	if(!istype(medic) || QDELETED(medic) || medic.stat != CONSCIOUS || medic.fading || medic.visit_over || medic.cell_patient_ref != key)
		cell_medics -= key
		return null
	return medic

/// Medics on the job for prisoners now
/datum/outpost_police/proc/cell_medic_count()
	. = 0
	for(var/datum/weakref/key as anything in cell_medics.Copy())
		var/mob/living/patient = key.resolve()
		if(!patient)
			cell_medics -= key
			continue
		if(cell_medic_for(patient))
			.++

/**
 * Calls a medic for `patient`, a prisoner in crit: one off the staff lift, as the recovery crews come. A call for
 * someone who already has a medic coming does nothing more. `speaker`, the officer who booked them, says the medic
 * line on the radio; with nobody given, the station says it. TRUE if a medic is coming; FALSE if none can.
 */
/datum/outpost_police/proc/call_cell_medic(mob/living/carbon/patient, mob/living/carbon/human/npc/ambient_npc/outpost/police/speaker)
	if(cell_medic_for(patient))
		return TRUE
	if(!cell_patient_ok(patient) || !recovery_in_crit(patient))
		return FALSE
	if(cell_medic_count() >= OUTPOST_POLICE_CELL_MEDICS_MAX)
		return FALSE
	if(QDELETED(outpost) || !outpost.loaded)
		return FALSE
	var/datum/outpost_recovery/recovery = outpost.ensure_recovery()
	if(!recovery || world.time < recovery.port_shut_until)
		return FALSE
	var/datum/ambient_place/outpost/place = recovery.recovery_place()
	var/turf/where = recovery.crew_arrival_turf()
	if(!place || !where)
		return FALSE
	var/mob/living/carbon/human/npc/ambient_npc/outpost/recovery/medic/cell/medic = new(where)
	// Off the lift with the shortest walk to the cell (owner playtest 2026-11-24: not the far one round the north side)
	var/datum/outpost_police_cell/cell = cell_of_patient(patient)
	life_step_off_nearest(medic, cell?.outside_turf || patient)
	medic.outpost_recovery = recovery
	medic.dialogue_section = profile?.voice_section || "halcyon"
	medic.cell_patient_ref = WEAKREF(patient)
	medic.called_at = world.time
	medic.set_place(place)
	medic.fade_in()
	cell_medics[WEAKREF(patient)] = WEAKREF(medic)
	log_game("OUTPOST POLICE: a medic was called for [key_name(patient)] in a cell at [outpost] ([AREACOORD(patient)]).")
	if(istype(speaker) && speaker.police_say(POLICE_LINE_MEDIC, null, TRUE))
		return TRUE
	cell_station_say(POLICE_LINE_MEDIC)
	return TRUE

// =========================================================================
// THE DOOR (the cell's)
// =========================================================================

/**
 * Lets `medic` in to `patient`: the cell opens its own door (as for an officer at work), the medic steps in by real
 * moves to a tile beside the patient, and the door shuts behind them once the doorway is clear. Sleeps. TRUE if the
 * medic is on the cell floor beside the patient.
 */
/datum/outpost_police_cell/proc/medic_walk_in(mob/living/medic, mob/living/patient)
	var/turf/door_turf = get_turf(door)
	var/turf/entry_tile = cell_entry_tile()
	if(!door_turf || !entry_tile || QDELETED(medic) || QDELETED(patient) || medic.z != door_turf.z || get_dist(medic, door_turf) > 2)
		return FALSE
	if(!open_door(OUTPOST_POLICE_CELL_OPEN, TRUE))
		return FALSE
	var/pause = cell_step_pause()
	for(var/step_try in 1 to 6)
		if(QDELETED(src) || QDELETED(medic) || QDELETED(patient) || medic.stat != CONSCIOUS || HAS_TRAIT(medic, TRAIT_INCAPACITATED))
			return FALSE
		var/turf/here = get_turf(medic)
		if((here in tiles) && medic.Adjacent(patient))
			break
		var/turf/next
		if(here in tiles)
			next = get_step_towards(medic, patient)
			if(!(next in tiles))
				break
		else if(here == door_turf)
			next = entry_tile
		else if(get_dist(here, door_turf) <= 1)
			next = door_turf
		else
			next = get_step_towards(medic, door_turf)
		if(!next)
			break
		cell_clear_step(medic, next)
		medic.Move(next, get_dir(medic, next))
		sleep(pause)
	if(QDELETED(src) || QDELETED(medic) || QDELETED(patient))
		return FALSE
	. = (get_turf(medic) in tiles) && medic.Adjacent(patient)
	if(. && !doorway_blocked())
		shut_door(TRUE)

/**
 * The morgue crew's way out with a body bag (`hauled`, pulled by `worker`): the cell opens its own door as it does
 * for a medic (the crew come in by medic_walk_in()), `worker` walks out by real moves with the bag following, one
 * tile past the lobby tile so the doorway is clear, and the door shuts behind them. Nobody plans a path through a
 * cell door (CanAStarPass()), so this is the only way a body leaves a shut cell. Sleeps. TRUE if the bag is out.
 */
/datum/outpost_police_cell/proc/body_walk_out(mob/living/worker, atom/movable/hauled)
	var/turf/door_turf = get_turf(door)
	var/turf/entry_tile = cell_entry_tile()
	if(!door_turf || !entry_tile || !outside_turf || QDELETED(worker) || QDELETED(hauled) || worker.pulling != hauled)
		return FALSE
	if(!(get_turf(worker) in tiles) && get_turf(worker) != door_turf)
		return FALSE
	if(!open_door(OUTPOST_POLICE_CELL_OPEN, TRUE))
		return FALSE
	// Past the lobby tile, away from the door, so the bag ends on the lobby tile and out of the doorway
	var/turf/beyond = get_step(outside_turf, get_dir(door_turf, outside_turf))
	if(!beyond || beyond.is_blocked_turf(exclude_mobs = TRUE) || (beyond in tiles))
		beyond = null
		for(var/direction in GLOB.cardinals)
			var/turf/candidate = get_step(outside_turf, direction)
			if(candidate && candidate != door_turf && !(candidate in tiles) && !candidate.is_blocked_turf(exclude_mobs = TRUE))
				beyond = candidate
				break
	var/pause = cell_step_pause()
	for(var/step_try in 1 to 8)
		if(QDELETED(src) || QDELETED(worker) || QDELETED(hauled) || worker.stat != CONSCIOUS || HAS_TRAIT(worker, TRAIT_INCAPACITATED) || worker.pulling != hauled)
			break
		var/turf/here = get_turf(worker)
		var/turf/bag_turf = get_turf(hauled)
		if(bag_turf != door_turf && !(bag_turf in tiles))
			break
		var/turf/next
		if(here == outside_turf)
			next = beyond
		else if(here == door_turf)
			next = outside_turf
		else if(here == entry_tile)
			next = door_turf
		else if(here in tiles)
			next = get_step_towards(worker, entry_tile)
			if(!(next in tiles))
				next = entry_tile
		if(!next)
			break
		cell_clear_step(worker, next)
		worker.Move(next, get_dir(worker, next))
		sleep(pause)
	if(QDELETED(src) || QDELETED(hauled))
		return FALSE
	var/turf/bag_turf = get_turf(hauled)
	. = bag_turf != door_turf && !(bag_turf in tiles)
	if(. && !doorway_blocked())
		shut_door(TRUE)

// =========================================================================
// THE MEDIC
// =========================================================================

/// A medic called to one prisoner in crit (police_cell_medic.dm). Not one of a recovery wave's crew.
/mob/living/carbon/human/npc/ambient_npc/outpost/recovery/medic/cell
	routine = list(/datum/ambient_activity/treat_prisoner = 1)
	counts_for_wave = FALSE
	/// The prisoner they were called to
	var/datum/weakref/cell_patient_ref
	/// world.time they were called
	var/called_at = 0
	/// Done with the prisoner (treated, lost or given up): the claim lapses and they go
	var/visit_over = FALSE
	/// Said the lift line on the way out
	var/said_leaving = FALSE

/mob/living/carbon/human/npc/ambient_npc/outpost/recovery/medic/cell/shift_times(delay)
	. = ..()
	called_at = ambient_shifted(called_at, delay)

/mob/living/carbon/human/npc/ambient_npc/outpost/recovery/medic/cell/pick_activity()
	var/datum/outpost_police/police = cell_police()
	if(!visit_over && world.time - called_at >= OUTPOST_POLICE_CELL_MEDIC_LIMIT)
		end_visit()
	var/inside = police?.cell_at(get_turf(src))
	if(!visit_over || inside)
		var/mob/living/patient = cell_patient()
		var/datum/outpost_police_cell/cell = police?.cell_of_patient(patient)
		if(!inside && cell?.outside_turf && needs_checkpoint_cross(cell.outside_turf))
			var/datum/ambient_activity/cross = start_activity(new /datum/ambient_activity/cross_checkpoint(src))
			if(cross)
				return cross
		var/datum/ambient_activity/job = start_activity(new /datum/ambient_activity/treat_prisoner(src))
		if(job)
			return job
	end_visit()
	if(!said_leaving)
		said_leaving = TRUE
		crew_radio(RECOVERY_LINE_LIFT)
	return start_activity(new /datum/ambient_activity/leave(src))

/**
 * Out of crit, only a bleeding limb is seen to (the suture on it): the medic stops once the prisoner is out of
 * crit and stable, and never heals a prisoner beyond that.
 */
/mob/living/carbon/human/npc/ambient_npc/outpost/recovery/medic/cell/next_treatment(mob/living/carbon/patient)
	. = ..()
	var/list/next = .
	if(!next || recovery_in_crit(patient))
		return
	var/obj/item/bodypart/limb = patient.get_bodypart(next[2])
	if(!istype(next[1], /obj/item/stack/medical/suture) || !limb || limb.get_modified_bleed_rate() <= 0)
		return null

/// The police of the outpost they work at
/mob/living/carbon/human/npc/ambient_npc/outpost/recovery/medic/cell/proc/cell_police()
	return medic_recovery()?.outpost?.police

/// The prisoner they were called to, if still about
/mob/living/carbon/human/npc/ambient_npc/outpost/recovery/medic/cell/proc/cell_patient()
	var/mob/living/carbon/patient = cell_patient_ref?.resolve()
	return QDELETED(patient) ? null : patient

/// Their work for the prisoner is over: the claim lapses (the cell's door hold takes over if they are still in crit)
/mob/living/carbon/human/npc/ambient_npc/outpost/recovery/medic/cell/proc/end_visit()
	visit_over = TRUE

// =========================================================================
// THE JOB
// =========================================================================

/// What the job is doing in its own proc (it sleeps)
#define CELL_MEDIC_ACT_WALK_IN "walk_in"
#define CELL_MEDIC_ACT_TREAT "treat"
#define CELL_MEDIC_ACT_WALK_OUT "walk_out"
/// An action that has not come back in this long is taken as broken (a runtime inside it) and let go
#define CELL_MEDIC_ACTION_STUCK (1 MINUTES)

/**
 * One prisoner: to the cell door, in, the kit until they are out of crit and not bleeding, then out. A medic found
 * standing in a cell (a reaction pulled them off the job half way) picks it up again, or walks out.
 */
/datum/ambient_activity/treat_prisoner
	name = "treating a prisoner"
	/// The cell the prisoner is held in
	var/datum/outpost_police_cell/cell
	/// The running action (CELL_MEDIC_ACT_*), or null
	var/acting
	var/acting_since = 0
	/// Tries at getting in beside the prisoner
	var/entry_tries = 0
	/// Whether anything from the kit went on the prisoner
	var/treated = FALSE
	/// Said the found line
	var/said_found = FALSE

/datum/ambient_activity/treat_prisoner/setup()
	var/mob/living/carbon/human/npc/ambient_npc/outpost/recovery/medic/cell/medic = doer
	if(!istype(medic) || !isturf(medic.loc))
		return FALSE
	var/datum/outpost_police/police = medic.cell_police()
	if(!police)
		return FALSE
	var/datum/outpost_police_cell/inside = police.cell_at(get_turf(medic))
	if(inside)
		cell = inside
		go_to(null)
		return TRUE
	if(medic.visit_over)
		return FALSE
	var/mob/living/carbon/patient = medic.cell_patient()
	cell = police.cell_of_patient(patient)
	if(!police.cell_patient_ok(patient, cell))
		medic.end_visit()
		return FALSE
	if(!cell?.usable())
		medic.end_visit()
		return FALSE
	go_to(cell.outside_turf, 1)
	return TRUE

/datum/ambient_activity/treat_prisoner/Destroy()
	cell = null
	return ..()

/datum/ambient_activity/treat_prisoner/shift_times(delay)
	. = ..()
	acting_since = ambient_shifted(acting_since, delay)

/datum/ambient_activity/treat_prisoner/spot_unreachable()
	. = ..()
	var/mob/living/carbon/human/npc/ambient_npc/outpost/recovery/medic/cell/medic = doer
	if(istype(medic))
		medic.end_visit()

/// Whether the job is still on: their visit not over, and the prisoner held in this cell and in need of them
/datum/ambient_activity/treat_prisoner/proc/still_needed(mob/living/carbon/patient)
	var/mob/living/carbon/human/npc/ambient_npc/outpost/recovery/medic/cell/medic = doer
	if(!istype(medic) || medic.visit_over || QDELETED(cell))
		return FALSE
	var/datum/outpost_police/police = medic.cell_police()
	if(!police?.cell_patient_ok(patient, cell))
		return FALSE
	return world.time - medic.called_at < OUTPOST_POLICE_CELL_MEDIC_LIMIT

/// The visit is over: a word on the radio for how it went, and the claim lapses
/datum/ambient_activity/treat_prisoner/proc/close_visit(mob/living/carbon/patient)
	var/mob/living/carbon/human/npc/ambient_npc/outpost/recovery/medic/cell/medic = doer
	if(!istype(medic) || medic.visit_over)
		return
	if(treated && patient)
		if(patient.stat == DEAD)
			medic.crew_radio(RECOVERY_LINE_MEDIC_LOST)
		else if(!recovery_in_crit(patient))
			medic.crew_radio(RECOVERY_LINE_MEDIC_STABLE)
	medic.end_visit()

/// Runs `action` on its own (it sleeps); act() waits for it
/datum/ambient_activity/treat_prisoner/proc/begin_action(action, mob/living/carbon/patient)
	acting = action
	acting_since = world.time
	go_to(null)
	INVOKE_ASYNC(src, PROC_REF(run_action), action, patient)

/datum/ambient_activity/treat_prisoner/proc/run_action(action, mob/living/carbon/patient)
	var/mob/living/carbon/human/npc/ambient_npc/outpost/recovery/medic/cell/medic = doer
	var/datum/outpost_police_cell/where = cell
	if(istype(medic) && !QDELETED(where))
		switch(action)
			if(CELL_MEDIC_ACT_WALK_IN)
				if(!where.medic_walk_in(medic, patient) && !QDELETED(src))
					entry_tries++
			if(CELL_MEDIC_ACT_TREAT)
				if(medic.treat(patient) && !QDELETED(src))
					treated = TRUE
			if(CELL_MEDIC_ACT_WALK_OUT)
				where.cell_walk_out(medic)
				if(!QDELETED(where) && !length(where.medic_bodies))
					where.shut_door()
	if(!QDELETED(src) && acting == action)
		acting = null

/datum/ambient_activity/treat_prisoner/act(seconds)
	var/mob/living/carbon/human/npc/ambient_npc/outpost/recovery/medic/cell/medic = doer
	if(acting)
		if(world.time - acting_since < CELL_MEDIC_ACTION_STUCK)
			return AMBIENT_STEP_CONTINUE
		acting = null
	if(!istype(medic) || QDELETED(cell))
		return AMBIENT_STEP_DONE
	var/datum/outpost_police/police = medic.cell_police()
	var/inside = police?.cell_at(get_turf(medic)) == cell
	var/mob/living/carbon/patient = medic.cell_patient()
	if(!still_needed(patient))
		close_visit(patient)
		if(inside)
			begin_action(CELL_MEDIC_ACT_WALK_OUT)
			return AMBIENT_STEP_CONTINUE
		return AMBIENT_STEP_DONE
	if(entry_tries >= OUTPOST_POLICE_CELL_MEDIC_TRIES)
		medic.end_visit()
		if(inside)
			begin_action(CELL_MEDIC_ACT_WALK_OUT)
			return AMBIENT_STEP_CONTINUE
		return AMBIENT_STEP_DONE
	if(!inside || !(get_turf(medic) in cell.tiles) || !medic.Adjacent(patient))
		if(!inside && get_dist(medic, cell.outside_turf) > 1)
			go_to(cell.outside_turf, 1)
			return AMBIENT_STEP_MOVE
		begin_action(CELL_MEDIC_ACT_WALK_IN, patient)
		return AMBIENT_STEP_CONTINUE
	if(!said_found)
		said_found = TRUE
		medic.speak_context(RECOVERY_LINE_MEDIC_FOUND, patient, force = TRUE)
	// Nothing more in the kit for them: they wait while the epinephrine works, else they are done here
	if(!medic.next_treatment(patient))
		if(recovery_in_crit(patient) && patient.reagents?.has_reagent(/datum/reagent/medicine/epinephrine))
			return AMBIENT_STEP_CONTINUE
		close_visit(patient)
		begin_action(CELL_MEDIC_ACT_WALK_OUT)
		return AMBIENT_STEP_CONTINUE
	begin_action(CELL_MEDIC_ACT_TREAT, patient)
	return AMBIENT_STEP_CONTINUE

#undef CELL_MEDIC_ACT_WALK_IN
#undef CELL_MEDIC_ACT_TREAT
#undef CELL_MEDIC_ACT_WALK_OUT
#undef CELL_MEDIC_ACTION_STUCK
