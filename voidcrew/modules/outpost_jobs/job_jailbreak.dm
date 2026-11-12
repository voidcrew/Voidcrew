/**
 * # Outpost jobs: jailbreak
 *
 * Owner: P7. Spec 6.6: an NPC prisoner held in a real cell through the cell's ward list (police_cell.dm, P0 seam:
 * hold_ward(), drop_ward(), cell_for_ward(), cell_of_ward(), COMSIG_OUTPOST_POLICE_CELL_FORCED).
 *
 * The job brings its own prisoner (the ward). Staging builds him on a free tile of the police's emptiest cell, puts
 * him on that cell's ward list and shuts the door. The cell only keeps the list: everything else is here.
 * - In the cell he sits on the chair, paces, uses the toilet, knocks on the glass and needles the sergeant, who
 *   answers in his own voice (the police file's "cell_reply"). A roster member at the glass gets "Took you long
 *   enough." Every tg system works on him as on anyone: he is an ambient outpost NPC (L9).
 * - Getting him out: forcing the door is the police's own rule (a jailbreak, three stars, every time). If the
 *   forcer is on the roster he follows them. A roster member who talks to him (an empty hand) while the door is
 *   open also gets him following. He ignores anyone off the roster.
 * - Leaving the cell while held and not through a forced door (abuse J10): whoever leads, pulls, carries or throws
 *   him out is reported for OUTPOST_CRIME_JAILBREAK.
 * - The run: the stray's follow (recruit.dm) with two changes. When his leader is in a hangar lift alcove he steps
 *   into the alcove too, so the lift (a forceMove of everything in the alcove, outpost_elevator.dm) takes both of
 *   them; and he never holds still while following, so an empty concourse does not freeze him in the hangar.
 * - The deed: aboard the job's ship (its deckhand place's aboard()), alive, with a roster member aboard within
 *   FIXER_WARD_FOLLOW_RANGE. Aboard another ship nothing happens. He is then a passenger on the ship's place: not a
 *   deckhand, never in the place's `taken` count or `pending_ref`, so no recruit limit sees him.
 * - Lost: out of the cell with no leader who is up, free and within range for FIXER_WARD_LOST_TIME. He gives up
 *   (tg's *surrender), an officer within 3 tiles cuffs him with the police's own cuffs, and the job fails. A ward
 *   who gave up stands with his AI off (he gave up; nothing about his body is faked) and is taken away while no
 *   player can see. He is not walked back to the cell: his escape AI would fight the cuffs all the way, and a failed
 *   job's ward is gone anyway.
 * - The deadline: the sergeant says the transfer is here, and he is gone when nobody is looking.
 * - Passenger: thanks his crew and sits down. He leaves at the next trader outpost the ship docks at that is not
 *   his jail, or FIXER_WARD_STAY_TIME after the job ends, while nobody is looking.
 *
 * Every behaviour is a proc a test can call with him already in place (ward_tick(), on_cell_forced(),
 * ward_left_cell(), check_aboard(), give_up(), talked_to()).
 */

/// Held in his cell (on its ward list)
#define WARD_HELD "held"
/// Out of the cell, on the run
#define WARD_OUT "out"
/// Aboard the job's ship: the deed is done
#define WARD_ABOARD "aboard"
/// He gave up: hands up, the job failed
#define WARD_TAKEN "taken"
/// His job is over: he goes when nobody is looking
#define WARD_GONE "gone"
/// Trait source for this file
#define JAILBREAK_TRAIT "outpost_jobs_jailbreak"
/// How close a roster member must be to the ward for "Took you long enough."
#define WARD_GREET_RANGE 3
/// An officer this close cuffs a ward who gave up
#define WARD_CUFF_RANGE 3
/// The sergeant answers a heckle from this far
#define WARD_SERGEANT_RANGE 9
/// How long a ducking ward keeps his head down
#define WARD_DUCK_TIME (4 SECONDS)
/// A forced door is taken to be open from the force this long after it, even while it is still shut
#define WARD_FORCE_GRACE (3 SECONDS)
/// Following: the weight a stray's follow has (recruit.dm STRAY_FOLLOW_PRIORITY), above a reaction
#define WARD_FOLLOW_PRIORITY 60
/// The jail, as the note and the offer say it
#define WARD_PLACE_WORDS "the lockup"

// =========================================================================
// THE JOB
// =========================================================================

/datum/mission/fixer_job/jailbreak
	job_kind = FIXER_JOB_JAILBREAK
	base_pay = FIXER_PAY_JAILBREAK
	duration = FIXER_TIME_JAILBREAK
	trust_tier = FIXER_TRUST_TIER2
	slate_weight = FIXER_WEIGHT_JAILBREAK
	noise_floor = FIXER_JAILBREAK_FLOOR
	// A cell door forced at the job's outpost is the job's own noise (its victim is null, so only the kind can name it)
	scene_crimes = list(OUTPOST_CRIME_JAILBREAK)
	/// The prisoner, once staged
	var/datum/weakref/ward_ref
	/// Who he is, rolled the first time the offer is made so the offer, the note and the man match:
	/// list("name", "gender", "outfit") for ambient_build_npc()'s identity
	var/list/ward_identity

/datum/mission/fixer_job/jailbreak/Destroy()
	var/mob/living/carbon/human/npc/ambient_npc/outpost/job_ward/ward = ward()
	if(ward)
		ward.job_over(src)
	ward_ref = null
	ward_identity = null
	return ..()

/// The prisoner, if he is still about
/datum/mission/fixer_job/jailbreak/proc/ward()
	var/mob/living/carbon/human/npc/ambient_npc/outpost/job_ward/ward = ward_ref?.resolve()
	return QDELETED(ward) ? null : ward

/// Who the prisoner is: rolled once, kept for the job
/datum/mission/fixer_job/jailbreak/proc/get_ward_identity()
	if(ward_identity)
		return ward_identity
	var/gender = pick(MALE, FEMALE)
	var/static/list/outfits = list(
		/datum/outfit/outpost_prisoner,
		/datum/outfit/outpost_prisoner/glasses,
		/datum/outfit/outpost_prisoner/beanie,
	)
	ward_identity = list("name" = generate_random_name(gender), "gender" = gender, "outfit" = pick(outfits))
	return ward_identity

/// The words for how he looks, by outfit
/datum/mission/fixer_job/jailbreak/proc/ward_look()
	var/list/identity = get_ward_identity()
	switch(identity["outfit"])
		if(/datum/outfit/outpost_prisoner/glasses)
			return "prison orange and glasses"
		if(/datum/outfit/outpost_prisoner/beanie)
			return "prison orange, orange beanie"
	return "prison orange"

/// When he is moved: the deadline, as a station clock ("14:20")
/datum/mission/fixer_job/jailbreak/proc/ward_clock()
	var/deadline = (time_started || world.time) + duration
	return station_time_timestamp("hh:mm", deadline)

// The outpost must have a cell he can be held in
/datum/mission/fixer_job/jailbreak/allowed_at(obj/structure/overmap/trader_outpost/outpost, datum/voidcrew_crew_record/crew)
	var/datum/outpost_police_cell/cell = outpost?.police?.cell_for_ward()
	return !!cell?.usable()

/datum/mission/fixer_job/jailbreak/offer_tokens()
	var/list/identity = get_ward_identity()
	return list(
		FIXER_TOKEN_NAME = html_encode(jailbreak_cut(identity["name"], FIXER_BOUND_NAME)),
		FIXER_TOKEN_LOOK = html_encode(jailbreak_cut(ward_look(), FIXER_BOUND_LOOK)),
		FIXER_TOKEN_CLOCK = ward_clock(),
		FIXER_TOKEN_PLACE = html_encode(jailbreak_cut(WARD_PLACE_WORDS, FIXER_BOUND_PLACE)),
	)

// The name is html_encode()d here (spec 11), as offer_tokens() are: P1 must not encode these lines again
/datum/mission/fixer_job/jailbreak/note_lines()
	var/list/identity = get_ward_identity()
	var/name = html_encode(jailbreak_cut(identity["name"], FIXER_BOUND_NAME))
	var/pronoun = identity["gender"] == FEMALE ? "her" : "him"
	return list(
		jailbreak_cut("[name], in [WARD_PLACE_WORDS].", FIXER_BOUND_NOTE_LINE),
		jailbreak_cut("Moved at [ward_clock()].", FIXER_BOUND_NOTE_LINE),
		jailbreak_cut("Get [pronoun] aboard.", FIXER_BOUND_NOTE_LINE),
	)

/**
 * The prisoner, into the police's emptiest usable cell: built on a free tile, put on its ward list, the door shut.
 * FALSE when the outpost has no usable cell or he could not be built.
 */
/datum/mission/fixer_job/jailbreak/stage()
	var/obj/structure/overmap/trader_outpost/outpost = job_outpost
	var/datum/outpost_police/police = outpost?.police
	var/datum/outpost_police_cell/cell = police?.cell_for_ward()
	if(!cell?.usable())
		return FALSE
	var/turf/tile = cell.free_tile()
	if(!tile)
		return FALSE
	var/list/identity = get_ward_identity()
	var/mob/living/carbon/human/npc/ambient_npc/outpost/job_ward/ward = ambient_build_npc(/mob/living/carbon/human/npc/ambient_npc/outpost/job_ward, tile, null, identity.Copy())
	if(!istype(ward))
		if(ward)
			qdel(ward)
		return FALSE
	ward_ref = WEAKREF(ward)
	fixer_job_npc_setup(ward, src)
	if(!ward.place)
		ward.set_place(SSambient_npcs.outpost_place(outpost))
	if(!ward.hold_in(src, cell))
		ward_ref = null
		qdel(ward)
		return FALSE
	log_game("OUTPOST JOBS: jailbreak staged, [ward] held in cell [cell.cell_id] at [AREACOORD(ward)]")
	return TRUE

// The prisoner is his own: he goes in the world (job_over()), never with the parent's deletion of tracked things
/datum/mission/fixer_job/jailbreak/unstage()
	var/mob/living/carbon/human/npc/ambient_npc/outpost/job_ward/ward = ward()
	if(ward)
		if(job_atoms)
			job_atoms -= WEAKREF(ward)
		ward.job_over(src)
	ward_ref = null
	return ..()

// Time is up in the cell: the sergeant says the transfer is here, then the job fails
/datum/mission/fixer_job/jailbreak/on_deadline()
	var/mob/living/carbon/human/npc/ambient_npc/outpost/job_ward/ward = ward()
	if(ward?.ward_state == WARD_HELD)
		ward.sergeant_transfer()
	return ..()

/// `text` cut to `bound` characters, an ellipsis last when it was cut
/proc/jailbreak_cut(text, bound)
	if(length_char(text) <= bound)
		return text
	return "[copytext_char(text, 1, bound)]…"

// =========================================================================
// THE PRISONER
// =========================================================================

/// The prisoner
/mob/living/carbon/human/npc/ambient_npc/outpost/job_ward
	name = "prisoner"
	desc = "Someone in prison orange."
	// A prisoner carries nothing: no cash, no loot (his kit is locked to him like anyone's)
	death_cash_low = 0
	death_cash_high = 0
	outfit_choices = list(
		/datum/outfit/outpost_prisoner,
		/datum/outfit/outpost_prisoner/glasses,
		/datum/outfit/outpost_prisoner/beanie,
	)
	dialogue_file = FIXER_STRINGS_JAILBREAK
	dialogue_section = "ward"
	routine = list(
		/datum/ambient_activity/ward_cell/sit = 3,
		/datum/ambient_activity/ward_cell/pace = 3,
		/datum/ambient_activity/ward_cell/toilet = 1,
		/datum/ambient_activity/ward_cell/knock = 2,
	)
	/// WARD_*
	var/ward_state = WARD_HELD
	/// His job
	var/datum/weakref/job_ref
	/// The outpost he is held at, kept after the job is gone
	var/datum/weakref/jail_ref
	/// The police whose cell holds him (for the forced-door signal)
	var/datum/weakref/police_ref
	/// Who he follows, if anyone
	var/datum/weakref/leader_ref
	/// world.time his cell door was last forced, while it may still be open from it; 0 when not
	var/forced_at = 0
	/// world.time he went without a leader he can follow, or 0
	var/lost_since = 0
	/// He said "Took you long enough."
	var/greeted = FALSE
	/// world.time he leaves the ship he rode, or 0
	var/leave_at = 0
	/// He said goodbye at another port
	var/said_goodbye = FALSE
	/// What he does aboard
	var/list/passenger_routine = list(
		/datum/ambient_activity/sit = 3,
		/datum/ambient_activity/idle = 2,
		/datum/ambient_activity/wander = 1,
	)

/mob/living/carbon/human/npc/ambient_npc/outpost/job_ward/Initialize(mapload, datum/human_npc_order/order)
	// ambient_dialogue_lines() only loads from AMBIENT_STRINGS_DIR: this feature's file goes in the cache first
	load_strings_file(FIXER_STRINGS_JAILBREAK, FIXER_STRINGS_DIR)
	. = ..()
	RegisterSignal(src, COMSIG_MOVABLE_MOVED, PROC_REF(ward_moved))

/mob/living/carbon/human/npc/ambient_npc/outpost/job_ward/Destroy()
	var/datum/outpost_police/police = police_ref?.resolve()
	if(police)
		UnregisterSignal(police, COMSIG_OUTPOST_POLICE_CELL_FORCED)
		police.cell_of_ward(src)?.drop_ward(src)
	job_ref = null
	jail_ref = null
	police_ref = null
	leader_ref = null
	return ..()

// ----- what he belongs to -----

/// His job, while it lasts
/mob/living/carbon/human/npc/ambient_npc/outpost/job_ward/proc/job()
	var/datum/mission/fixer_job/jailbreak/job = job_ref?.resolve()
	return QDELETED(job) ? null : job

/// The outpost he is held at
/mob/living/carbon/human/npc/ambient_npc/outpost/job_ward/proc/jail_outpost()
	var/obj/structure/overmap/trader_outpost/outpost = jail_ref?.resolve()
	return QDELETED(outpost) ? null : outpost

/// The police of his jail
/mob/living/carbon/human/npc/ambient_npc/outpost/job_ward/proc/ward_police()
	var/datum/outpost_police/police = police_ref?.resolve()
	return QDELETED(police) ? jail_outpost()?.police : police

/// The cell holding him on its ward list, or null
/mob/living/carbon/human/npc/ambient_npc/outpost/job_ward/proc/ward_cell()
	return ward_police()?.cell_of_ward(src)

/// Who he follows, if they are still there
/mob/living/carbon/human/npc/ambient_npc/outpost/job_ward/proc/ward_leader()
	var/mob/living/leader = leader_ref?.resolve()
	return QDELETED(leader) ? null : leader

/// Whether he is following someone right now
/mob/living/carbon/human/npc/ambient_npc/outpost/job_ward/proc/ward_following()
	return istype(activity, /datum/ambient_activity/stray_follow/ward)

/// Whether `who` is on his job's roster
/mob/living/carbon/human/npc/ambient_npc/outpost/job_ward/proc/on_job_roster(mob/living/who)
	var/datum/mission/fixer_job/jailbreak/job = job()
	return !!(job && isliving(who) && who.mind && job.on_roster(who.mind))

/**
 * Takes him into `cell` for `job`: on its ward list, on its floor, the door shut, the forced-door signal heard.
 * TRUE if he is held.
 */
/mob/living/carbon/human/npc/ambient_npc/outpost/job_ward/proc/hold_in(datum/mission/fixer_job/jailbreak/job, datum/outpost_police_cell/cell)
	if(QDELETED(cell) || !cell.police)
		return FALSE
	job_ref = WEAKREF(job)
	jail_ref = WEAKREF(job?.job_outpost || cell.police.outpost)
	if(!cell.hold_ward(src))
		return FALSE
	if(!(get_turf(src) in cell.tiles))
		forceMove(cell.free_tile())
	home = get_turf(src)
	ward_state = WARD_HELD
	var/datum/outpost_police/old_police = police_ref?.resolve()
	if(old_police && old_police != cell.police)
		UnregisterSignal(old_police, COMSIG_OUTPOST_POLICE_CELL_FORCED)
	police_ref = WEAKREF(cell.police)
	RegisterSignal(cell.police, COMSIG_OUTPOST_POLICE_CELL_FORCED, PROC_REF(on_cell_forced), override = TRUE)
	cell.shut_door()
	return TRUE

// ----- the clock (once a Life) -----

/mob/living/carbon/human/npc/ambient_npc/outpost/job_ward/Life(seconds_per_tick = SSMOBS_DT, times_fired)
	. = ..()
	if(QDELETED(src) || stat == DEAD)
		return
	ward_tick()

/// Everything he keeps an eye on, about once a Life. Never sleeps.
/mob/living/carbon/human/npc/ambient_npc/outpost/job_ward/proc/ward_tick()
	if(QDELETED(src) || stat == DEAD)
		return
	var/datum/mission/fixer_job/jailbreak/job = job()
	switch(ward_state)
		if(WARD_HELD)
			if(!job)
				ward_go()
				return
			var/datum/outpost_police_cell/cell = ward_cell() || ward_rehold()
			if(!cell)
				return
			if(forced_at && world.time > forced_at + WARD_FORCE_GRACE && (QDELETED(cell.door) || cell.door.density))
				forced_at = 0
			if(ward_following() && !leader_ok(ward_leader()))
				stop_follow()
			look_for_friends()
		if(WARD_OUT)
			if(!job)
				ward_go()
				return
			if(check_aboard())
				return
			var/mob/living/leader = ward_leader()
			if(leader_ok(leader))
				lost_since = 0
				if(!ward_following() && can_act())
					ward_follow(leader)
				return
			lost_since ||= world.time
			if(world.time - lost_since >= FIXER_WARD_LOST_TIME)
				give_up()
		if(WARD_ABOARD)
			passenger_tick()
		if(WARD_TAKEN, WARD_GONE)
			// Taken away, or moved from his cell, while nobody is looking
			if(!human_npc_watched(src))
				ward_take_away()

/// Whether `leader` can still be followed: up, free and within FIXER_WARD_FOLLOW_RANGE on this level
/mob/living/carbon/human/npc/ambient_npc/outpost/job_ward/proc/leader_ok(mob/living/leader)
	if(QDELETED(leader) || leader.stat != CONSCIOUS || HAS_TRAIT(leader, TRAIT_RESTRAINED) || HAS_TRAIT(leader, TRAIT_INCAPACITATED))
		return FALSE
	var/turf/here = get_turf(src)
	var/turf/there = get_turf(leader)
	return here && there && here.z == there.z && get_dist(here, there) <= FIXER_WARD_FOLLOW_RANGE

/// A cell rebuild dropped every ward: back onto the list of the cell whose floor he is on, or into another while nobody is looking
/mob/living/carbon/human/npc/ambient_npc/outpost/job_ward/proc/ward_rehold()
	var/datum/outpost_police/police = ward_police()
	if(!police)
		return null
	var/turf/here = get_turf(src)
	for(var/datum/outpost_police_cell/cell as anything in police.cells)
		if((here in cell.tiles) && cell.usable() && cell.hold_ward(src))
			return cell
	if(human_npc_watched(src))
		return null
	var/datum/outpost_police_cell/cell = police.cell_for_ward()
	if(!cell?.usable())
		return null
	forceMove(cell.free_tile())
	if(!cell.hold_ward(src))
		return null
	home = get_turf(src)
	cell.shut_door()
	return cell

/// A roster member came to the glass: "Took you long enough.", once
/mob/living/carbon/human/npc/ambient_npc/outpost/job_ward/proc/look_for_friends()
	if(greeted || !can_act())
		return
	var/turf/here = get_turf(src)
	if(!here)
		return
	for(var/mob/living/person in SSspatial_grid.orthogonal_range_search(here, SPATIAL_GRID_CONTENTS_TYPE_CLIENTS, WARD_GREET_RANGE))
		if(person == src || person.stat != CONSCIOUS || !can_see(here, get_turf(person), WARD_GREET_RANGE))
			continue
		if(!on_job_roster(person))
			continue
		greeted = TRUE
		if(!buckled)
			face_atom(person)
		speak_context("arrived", person, force = TRUE)
		return

// ----- getting out -----

/**
 * Someone forced a cell door at his jail. His own cell: the door is open from a force (so leaving through it is
 * no new crime), and if the forcer is on the roster he goes with them.
 */
/mob/living/carbon/human/npc/ambient_npc/outpost/job_ward/proc/on_cell_forced(datum/source, datum/outpost_police_cell/cell, mob/living/user)
	SIGNAL_HANDLER
	if(ward_state != WARD_HELD || !cell || cell != ward_cell())
		return
	forced_at = world.time
	if(!on_job_roster(user) || !can_act())
		return
	if(!ward_follow(user))
		return
	if(!buckled)
		face_atom(user)
	if(greeted)
		speak_context("follow", user, force = TRUE)
	else
		greeted = TRUE
		speak_context("arrived", user, force = TRUE)

/// He follows `leader` from now on. Returns the activity, or null.
/mob/living/carbon/human/npc/ambient_npc/outpost/job_ward/proc/ward_follow(mob/living/leader)
	if(QDELETED(leader))
		return null
	leader_ref = WEAKREF(leader)
	lost_since = 0
	// Following someone, he never holds still for an empty concourse (pause_routine())
	if(paused_at)
		resume_routine()
	return start_activity(new /datum/ambient_activity/stray_follow/ward(src, leader))

/// He stops following whoever it was
/mob/living/carbon/human/npc/ambient_npc/outpost/job_ward/proc/stop_follow()
	leader_ref = null
	if(ward_following())
		end_activity()

/// He moved. Off his cell's floor while held: he is out (ward_left_cell()).
/mob/living/carbon/human/npc/ambient_npc/outpost/job_ward/proc/ward_moved(datum/source, atom/old_loc, movement_dir, forced, list/old_locs)
	SIGNAL_HANDLER
	if(ward_state != WARD_HELD || stat == DEAD)
		return
	var/datum/outpost_police_cell/cell = ward_cell()
	if(!cell || (get_turf(src) in cell.tiles))
		return
	ward_left_cell(cell)

/**
 * He left `cell` while held. Through a door that was forced, the forcer already has the jailbreak. Otherwise
 * whoever pulled, carried, threw or led him out is reported for it (abuse J10). He is off the ward list either way.
 */
/mob/living/carbon/human/npc/ambient_npc/outpost/job_ward/proc/ward_left_cell(datum/outpost_police_cell/cell)
	var/mob/living/leader = ward_following() ? ward_leader() : null
	var/mob/living/mover = cell.mover_now(src) || leader
	if(!forced_at && isliving(mover) && mover != src)
		cell.police?.report_crime(mover, OUTPOST_CRIME_JAILBREAK, null, null)
		log_game("OUTPOST JOBS: [key_name(mover)] took [src] out of cell [cell.cell_id] through an open door at [AREACOORD(src)]")
	cell.drop_ward(src)
	ward_state = WARD_OUT
	lost_since = 0
	forced_at = 0

// Following, he goes wherever his leader leads that he can cross; held, his cell's floor is all there is
/mob/living/carbon/human/npc/ambient_npc/outpost/job_ward/leash_ok(turf/tile)
	var/turf/where = get_turf(tile)
	switch(ward_state)
		if(WARD_HELD)
			if(ward_following())
				return !!where?.can_cross_safely(src)
			var/datum/outpost_police_cell/cell = ward_cell()
			if(cell)
				return (where in cell.tiles)
		if(WARD_GONE)
			var/datum/outpost_police_cell/cell = ward_cell()
			if(cell)
				return (where in cell.tiles)
			return !!where?.can_cross_safely(src)
		if(WARD_OUT, WARD_TAKEN)
			return !!where?.can_cross_safely(src)
	return ..()

// On the run he never holds still for an empty concourse: his leader may have taken him down to the hangar
/mob/living/carbon/human/npc/ambient_npc/outpost/job_ward/pause_routine()
	if(ward_state == WARD_OUT || ward_following())
		return
	return ..()

// In the cell he keeps to his cell; aboard he lives as a passenger
/mob/living/carbon/human/npc/ambient_npc/outpost/job_ward/pick_activity()
	if(ward_state == WARD_HELD || (ward_state == WARD_GONE && ward_cell()))
		. = ..()
		if(istype(activity, /datum/ambient_activity/idle))
			// The base's fallback looks for a spot on the concourse: he has his cell
			end_activity()
			return start_activity(new /datum/ambient_activity/ward_cell(src))
		return
	if(ward_state == WARD_OUT)
		// Out with nobody to follow: he stays where he is and waits for them
		return start_activity(new /datum/ambient_activity/idle/ward_wait(src))
	if(ward_state == WARD_ABOARD)
		home = get_turf(src)
	return ..()

// ----- talking -----

// An empty hand from a roster member while the door is open: he comes. Anyone else gets a look.
/mob/living/carbon/human/npc/ambient_npc/outpost/job_ward/talked_to(mob/living/user)
	if(!talk_ready(user))
		return
	if(!buckled)
		face_atom(user)
	switch(ward_state)
		if(WARD_HELD, WARD_OUT)
			if(!on_job_roster(user))
				speak_context("refuse", user, force = TRUE)
				return
			var/datum/outpost_police_cell/cell = ward_cell()
			if(ward_state == WARD_HELD && cell && !QDELETED(cell.door) && cell.door.density)
				speak_context("wait", user, force = TRUE)
				return
			if(ward_follow(user))
				speak_context(greeted ? "follow" : "arrived", user, force = TRUE)
				greeted = TRUE
		else
			speak_context(AMBIENT_LINE_TALK, user, force = TRUE)

// ----- reactions: he keeps his head down, and never runs off to the lift -----

/mob/living/carbon/human/npc/ambient_npc/outpost/job_ward/react_attacked(atom/attacker)
	if(stat != CONSCIOUS || fading || !reaction_ready("attacked"))
		return
	speak_context(AMBIENT_LINE_ATTACKED, attacker, force = TRUE)
	ward_duck()

/mob/living/carbon/human/npc/ambient_npc/outpost/job_ward/react_violence(mob/living/offender)
	if(stat != CONSCIOUS || fading || ward_state == WARD_TAKEN || !reaction_ready("violence"))
		return
	ward_duck()
	if(prob(50))
		speak_context(AMBIENT_LINE_VIOLENCE, offender, force = TRUE)

/mob/living/carbon/human/npc/ambient_npc/outpost/job_ward/react_shootout(turf/refuge)
	if(stat != CONSCIOUS || fading || ward_state == WARD_TAKEN)
		return
	if(prob(40))
		speak_context(AMBIENT_LINE_COVER, null, force = TRUE)
	ward_duck()

/mob/living/carbon/human/npc/ambient_npc/outpost/job_ward/react_storm(datum/weather/storm)
	if(ward_state != WARD_ABOARD)
		return
	return ..()

/mob/living/carbon/human/npc/ambient_npc/outpost/job_ward/react_convoy(obj/structure/overmap/trader_outpost/outpost)
	return

/// Head down for a moment, where he stands
/mob/living/carbon/human/npc/ambient_npc/outpost/job_ward/proc/ward_duck()
	if(buckled || ward_state == WARD_TAKEN)
		return
	crouch()
	addtimer(CALLBACK(src, PROC_REF(ward_stand)), WARD_DUCK_TIME, TIMER_UNIQUE | TIMER_OVERRIDE | TIMER_DELETE_ME)

/mob/living/carbon/human/npc/ambient_npc/outpost/job_ward/proc/ward_stand()
	if(crouching && !buckled && stat == CONSCIOUS)
		stand_up()

// ----- the sergeant -----

/// He needled the sergeant: the sergeant, awake and in earshot, answers in his own voice
/mob/living/carbon/human/npc/ambient_npc/outpost/job_ward/proc/sergeant_answer()
	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/sergeant = ward_sergeant()
	if(!sergeant || get_dist(sergeant, src) > WARD_SERGEANT_RANGE || !reaction_ready("sergeant", 20 SECONDS))
		return
	addtimer(CALLBACK(src, PROC_REF(sergeant_says), WEAKREF(sergeant)), rand(AMBIENT_REPLY_DELAY_LOW, AMBIENT_REPLY_DELAY_HIGH) + 1 SECONDS, TIMER_DELETE_ME)

/mob/living/carbon/human/npc/ambient_npc/outpost/job_ward/proc/sergeant_says(datum/weakref/sergeant_ref)
	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/sergeant = sergeant_ref?.resolve()
	if(QDELETED(sergeant) || QDELETED(src) || sergeant.stat != CONSCIOUS || sergeant.fading || sergeant.paused_at)
		return
	if(!sergeant.buckled)
		sergeant.face_atom(src)
	sergeant.speak_context("cell_reply", src, force = TRUE)

/// His jail's sergeant, awake and about, or null
/mob/living/carbon/human/npc/ambient_npc/outpost/job_ward/proc/ward_sergeant()
	var/datum/outpost_police/police = ward_police()
	for(var/mob/living/carbon/human/npc/ambient_npc/outpost/police/officer in police?.officers)
		if(officer.unit_kind == POLICE_UNIT_SERGEANT && officer.stat == CONSCIOUS && !officer.fading)
			return officer
	return null

/// The deadline: the sergeant (or, failing him, the officer nearest the cell) says the transfer is here
/mob/living/carbon/human/npc/ambient_npc/outpost/job_ward/proc/sergeant_transfer()
	var/list/lines = ambient_dialogue_lines(FIXER_STRINGS_JAILBREAK, "sergeant", "transfer")
	if(!length(lines))
		return
	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/speaker = ward_sergeant()
	if(!speaker || get_dist(speaker, src) > WARD_SERGEANT_RANGE)
		speaker = ward_police()?.life_nearest_officer(get_turf(src), WARD_SERGEANT_RANGE)
	if(!speaker || speaker.paused_at)
		return
	speaker.say_line(speaker.fill_line(pick(lines), src))

// ----- the deed -----

/**
 * Whether he is aboard his job's ship with a roster member aboard near him: if so he is a passenger now and the
 * deed is done. Aboard another ship, or with nobody of the roster there, nothing happens. TRUE if he boarded.
 */
/mob/living/carbon/human/npc/ambient_npc/outpost/job_ward/proc/check_aboard()
	var/datum/mission/fixer_job/jailbreak/job = job()
	if(!job || job.deed_done || ward_state != WARD_OUT || !can_act())
		return FALSE
	var/obj/structure/overmap/ship/ship = job.servant
	if(QDELETED(ship))
		return FALSE
	var/datum/ambient_place/ship/deck = ambient_ship_place(ship)
	var/turf/here = get_turf(src)
	if(!deck || !here || !deck.aboard(here))
		return FALSE
	var/mob/living/with = roster_aboard(deck)
	if(!with)
		return FALSE
	board(deck, with)
	return TRUE

/// A roster member, up and about, aboard `deck` within FIXER_WARD_FOLLOW_RANGE of him: his leader first. Null if none.
/mob/living/carbon/human/npc/ambient_npc/outpost/job_ward/proc/roster_aboard(datum/ambient_place/ship/deck)
	var/turf/here = get_turf(src)
	var/list/candidates = list()
	var/mob/living/leader = ward_leader()
	if(leader)
		candidates += leader
	for(var/mob/living/person in SSspatial_grid.orthogonal_range_search(here, SPATIAL_GRID_CONTENTS_TYPE_CLIENTS, FIXER_WARD_FOLLOW_RANGE))
		candidates |= person
	for(var/mob/living/person as anything in candidates)
		if(person == src || person.stat == DEAD || !on_job_roster(person))
			continue
		var/turf/there = get_turf(person)
		if(!there || there.z != here.z || get_dist(here, there) > FIXER_WARD_FOLLOW_RANGE || !deck.aboard(there))
			continue
		return person
	return null

/// Aboard with `with` of the roster: the deed is done, and he is a passenger on `deck`
/mob/living/carbon/human/npc/ambient_npc/outpost/job_ward/proc/board(datum/ambient_place/ship/deck, mob/living/with)
	var/datum/mission/fixer_job/jailbreak/job = job()
	ward_state = WARD_ABOARD
	leader_ref = null
	lost_since = 0
	end_activity()
	// A passenger: the ship's place keeps him aboard, and neither `taken` nor `pending_ref` ever names him
	set_place(deck)
	home = get_turf(src)
	leash_bounds = null
	routine = passenger_routine.Copy()
	var/list/lines = ambient_dialogue_lines(dialogue_file, "ward", "aboard")
	if(length(lines))
		if(!buckled)
			face_atom(with)
		say_line(fill_line(pick(lines), with))
	dialogue_section = "passenger"
	log_game("OUTPOST JOBS: [src] came aboard the [deck.name] with [key_name(with)]")
	if(job)
		INVOKE_ASYNC(job, TYPE_PROC_REF(/datum/mission/fixer_job, mark_deed), with)
	start_activity(new /datum/ambient_activity/sit(src))

/// Aboard: he gets off at another port, or a while after his job is over, while nobody is looking
/mob/living/carbon/human/npc/ambient_npc/outpost/job_ward/proc/passenger_tick()
	if(fading)
		return
	if(!job() && !leave_at)
		leave_at = world.time + FIXER_WARD_STAY_TIME
	if(leave_at && world.time >= leave_at)
		ward_drop_given()
		fade_out()
		return
	if(said_goodbye)
		return
	var/datum/ambient_place/ship/deck = place
	if(!istype(deck))
		return
	var/obj/structure/overmap/trader_outpost/docked = deck.docked_outpost()
	if(docked && docked != jail_outpost())
		ward_goodbye()

/// Another port: a handshake, a word, and he goes
/mob/living/carbon/human/npc/ambient_npc/outpost/job_ward/proc/ward_goodbye()
	said_goodbye = TRUE
	if(!can_act())
		return
	var/datum/ambient_place/ship/deck = place
	var/obj/structure/overmap/ship/ship = istype(deck) ? deck.ship() : null
	var/turf/here = get_turf(src)
	var/mob/living/crewmate
	for(var/mob/living/person in SSspatial_grid.orthogonal_range_search(here, SPATIAL_GRID_CONTENTS_TYPE_CLIENTS, 3))
		if(person != src && person.stat == CONSCIOUS && ship && ambient_crew_ship(person) == ship)
			crewmate = person
			break
	if(crewmate)
		if(!buckled)
			face_atom(crewmate)
		manual_emote("shakes hands.")
	speak_context(AMBIENT_LINE_LEAVE, crewmate, force = TRUE)
	ward_drop_given()
	start_activity(new /datum/ambient_activity/leave(src, null, 3 SECONDS))

// ----- lost, dead, done -----

/**
 * His leader is gone, down, cuffed or too far for too long: he gives up. Hands up (tg's *surrender), an officer
 * within WARD_CUFF_RANGE cuffs him with real cuffs, and the job fails. He stands there with his AI off until he
 * is taken away while nobody is looking.
 */
/mob/living/carbon/human/npc/ambient_npc/outpost/job_ward/proc/give_up()
	if(ward_state != WARD_OUT && ward_state != WARD_HELD)
		return
	var/datum/mission/fixer_job/jailbreak/job = job()
	stop_follow()
	ward_state = WARD_TAKEN
	lost_since = 0
	ADD_TRAIT(src, TRAIT_AI_PAUSED, JAILBREAK_TRAIT)
	if(stat == CONSCIOUS)
		speak_context("lost", null, force = TRUE)
		INVOKE_ASYNC(src, TYPE_PROC_REF(/mob/living/carbon/human/npc, npc_surrender))
		var/mob/living/carbon/human/npc/ambient_npc/outpost/police/officer = ward_police()?.life_nearest_officer(get_turf(src), WARD_CUFF_RANGE)
		if(officer)
			INVOKE_ASYNC(src, PROC_REF(cuffed_by), officer)
	log_game("OUTPOST JOBS: [src] gave up at [AREACOORD(src)]")
	if(job)
		job.fail_reason = FIXER_FAIL_LOST
		INVOKE_ASYNC(job, TYPE_PROC_REF(/datum/mission, fail))

/// `officer` walks up and cuffs him with the police's own cuffs (tg's cuffing, in the officer's hands). Sleeps.
/mob/living/carbon/human/npc/ambient_npc/outpost/job_ward/proc/cuffed_by(mob/living/carbon/human/npc/ambient_npc/outpost/police/officer)
	for(var/attempt in 1 to WARD_CUFF_RANGE + 1)
		if(QDELETED(officer) || QDELETED(src) || officer.stat != CONSCIOUS || handcuffed)
			return
		if(officer.Adjacent(src))
			break
		step_towards(officer, src)
		sleep(0.4 SECONDS)
	if(QDELETED(officer) || QDELETED(src) || handcuffed || !officer.Adjacent(src))
		return
	var/obj/item/restraints/handcuffs/cuffs = officer.get_cuffs()
	if(!cuffs)
		return
	officer.face_atom(src)
	officer.police_say(POLICE_LINE_CUFF)
	cuffs.attempt_to_cuff(src, officer)
	if(!QDELETED(officer))
		officer.police_put_away(cuffs)

// Dead before the deed: the job fails. His body is the outpost's dead like anyone's, and stays.
/mob/living/carbon/human/npc/ambient_npc/outpost/job_ward/death(gibbed)
	var/was_alive = stat != DEAD
	. = ..()
	if(!was_alive || stat != DEAD)
		return
	var/datum/mission/fixer_job/jailbreak/job = job()
	leader_ref = null
	ward_cell()?.drop_ward(src)
	if(ward_state == WARD_ABOARD)
		return
	ward_state = WARD_GONE
	if(job && !job.deed_done)
		job.fail_reason = FIXER_FAIL_LOST
		INVOKE_ASYNC(job, TYPE_PROC_REF(/datum/mission, fail))

/// His job is over (paid, failed or gone): a passenger rides on a while; anyone else goes when nobody is looking
/mob/living/carbon/human/npc/ambient_npc/outpost/job_ward/proc/job_over(datum/mission/fixer_job/jailbreak/job)
	if(job_ref?.resolve() == job)
		job_ref = null
	if(QDELETED(src) || stat == DEAD)
		return
	switch(ward_state)
		if(WARD_ABOARD)
			leave_at ||= world.time + FIXER_WARD_STAY_TIME
		if(WARD_HELD, WARD_OUT)
			ward_go()

/// Done with: he stops following; out of the cell he heads off by the lift, in it he waits to be moved unseen
/mob/living/carbon/human/npc/ambient_npc/outpost/job_ward/proc/ward_go()
	stop_follow()
	ward_state = WARD_GONE
	if(!ward_cell() && can_act())
		start_activity(new /datum/ambient_activity/leave(src))

/// Gone now: what was handed to him is set down, and he is removed (only ever while nobody is looking)
/mob/living/carbon/human/npc/ambient_npc/outpost/job_ward/proc/ward_take_away()
	if(QDELETED(src) || stat == DEAD || fading)
		return
	log_game("OUTPOST JOBS: [src] was taken away unseen at [AREACOORD(src)]")
	ward_drop_given()
	fade_out(instant = TRUE)

/// Sets down what players gave him and any restraints that are not the police's own: none of it is his to take away
/mob/living/carbon/human/npc/ambient_npc/outpost/job_ward/proc/ward_drop_given()
	for(var/obj/item/held in held_items)
		if(held == held_prop || held == held_item || HAS_TRAIT(held, TRAIT_HUMAN_NPC_GEAR))
			continue
		dropItemToGround(held, force = TRUE)
	for(var/obj/item/restraint in list(handcuffed, legcuffed))
		if(!QDELETED(restraint) && !istype(restraint, /obj/item/restraints/handcuffs/outpost_police/used))
			dropItemToGround(restraint, force = TRUE)
	npc_drop_not_gear()

// =========================================================================
// ACTIVITIES
// =========================================================================

/// Following his leader out: the stray's follow, into the lift alcove with them, and no giving up of its own
/datum/ambient_activity/stray_follow/ward
	name = "following out"
	priority = WARD_FOLLOW_PRIORITY

// In a hangar lift alcove, he steps into the alcove too, so the ride takes him
/datum/ambient_activity/stray_follow/ward/at_spot()
	var/mob/living/leader = anchor()
	var/mob/living/carbon/human/npc/ambient_npc/outpost/job_ward/ward = doer
	var/list/alcove = (istype(ward) && in_reach(leader)) ? jailbreak_alcove_of(leader, ward.jail_outpost()) : null
	if(!alcove)
		return ..()
	var/turf/here = get_turf(doer)
	if(here in alcove)
		if(!doer.buckled)
			doer.face_atom(leader)
		return TRUE
	var/turf/step_in = (spot in alcove) ? spot : jailbreak_free_alcove_tile(alcove, leader)
	if(!step_in)
		return ..()
	if(spot != step_in)
		go_to(step_in)
	return FALSE

// The ward's own clock (ward_tick()) decides when he is lost
/datum/ambient_activity/stray_follow/ward/act(seconds)
	var/mob/living/leader = anchor()
	if(!in_reach(leader))
		return AMBIENT_STEP_CONTINUE
	if(get_dist(doer, leader) <= 2 && !doer.buckled)
		doer.face_atom(leader)
	chatter(AMBIENT_LINE_IDLE, 60 SECONDS, 120 SECONDS)
	return AMBIENT_STEP_CONTINUE

/// The hangar lift alcove of `outpost` (the concourse's or a berth's) that `thing` stands in, or null
/proc/jailbreak_alcove_of(atom/thing, obj/structure/overmap/trader_outpost/outpost)
	var/turf/tile = get_turf(thing)
	if(!tile || QDELETED(outpost))
		return null
	if(tile in outpost.lobby_alcove_turfs)
		return outpost.lobby_alcove_turfs
	for(var/datum/outpost_berth/berth as anything in outpost.berths)
		if(berth && (tile in berth.alcove_turfs))
			return berth.alcove_turfs
	return null

/// A free tile of `alcove` that is not `leader`'s, or null
/proc/jailbreak_free_alcove_tile(list/alcove, mob/living/leader)
	var/turf/leader_turf = get_turf(leader)
	for(var/turf/tile as anything in alcove)
		if(tile == leader_turf || tile.is_blocked_turf(exclude_mobs = FALSE))
			continue
		return tile
	return null

/// Out of the cell with nobody to follow: standing where he is, looking round for them
/datum/ambient_activity/idle/ward_wait
	name = "waiting for someone"
	accepts_company = FALSE
	duration_low = 5 SECONDS
	duration_high = 10 SECONDS

/datum/ambient_activity/idle/ward_wait/setup()
	set_duration()
	next_line = world.time + rand(10 SECONDS, 30 SECONDS)
	return TRUE

/// Something he does in his cell. The base stands about, looks round and mutters (the fallback).
/datum/ambient_activity/ward_cell
	name = "waiting in a cell"
	duration_low = 20 SECONDS
	duration_high = 50 SECONDS

/// His cell, while he is held in it
/datum/ambient_activity/ward_cell/proc/cell()
	var/mob/living/carbon/human/npc/ambient_npc/outpost/job_ward/ward = doer
	return istype(ward) ? ward.ward_cell() : null

/datum/ambient_activity/ward_cell/setup()
	if(!cell())
		return FALSE
	set_duration()
	next_line = world.time + rand(15 SECONDS, 40 SECONDS)
	return TRUE

/datum/ambient_activity/ward_cell/act(seconds)
	if(!cell())
		return AMBIENT_STEP_DONE
	if(prob(8) && !doer.buckled)
		doer.setDir(pick(GLOB.cardinals))
	chatter(AMBIENT_LINE_IDLE, 40 SECONDS, 90 SECONDS)
	return AMBIENT_STEP_CONTINUE

/// A free tile of his cell's floor, not `avoid`, or null
/datum/ambient_activity/ward_cell/proc/free_cell_tile(turf/avoid)
	var/datum/outpost_police_cell/cell = cell()
	var/list/options = list()
	for(var/turf/tile as anything in cell?.tiles)
		if(tile == avoid || tile.is_blocked_turf(exclude_mobs = FALSE) || LAZYACCESS(failed_spots, tile))
			continue
		options += tile
	return length(options) ? pick(options) : null

/// Sitting on the cell's chair a while
/datum/ambient_activity/ward_cell/sit
	name = "sitting in a cell"
	duration_low = 45 SECONDS
	duration_high = 2 MINUTES
	var/datum/weakref/seat_ref

/datum/ambient_activity/ward_cell/sit/setup()
	var/datum/outpost_police_cell/cell = cell()
	if(!cell)
		return FALSE
	for(var/turf/tile as anything in cell.tiles)
		var/obj/structure/chair/seat = locate() in tile
		if(seat && (!seat.has_buckled_mobs() || doer.buckled == seat))
			seat_ref = WEAKREF(seat)
			go_to(tile)
			set_duration()
			next_line = world.time + rand(15 SECONDS, 40 SECONDS)
			return TRUE
	return FALSE

/datum/ambient_activity/ward_cell/sit/arrive()
	var/obj/structure/chair/seat = seat_ref?.resolve()
	if(!seat || !doer.sit_on(seat))
		seat_ref = null

/datum/ambient_activity/ward_cell/sit/act(seconds)
	if(!seat_ref || !cell())
		return AMBIENT_STEP_DONE
	chatter(AMBIENT_LINE_IDLE, 40 SECONDS, 90 SECONDS)
	return AMBIENT_STEP_CONTINUE

/datum/ambient_activity/ward_cell/sit/spot_unreachable()
	. = ..()
	seat_ref = null

/// Pacing the cell: a few tiles, a pause at each
/datum/ambient_activity/ward_cell/pace
	name = "pacing a cell"
	duration_low = 30 SECONDS
	duration_high = 60 SECONDS
	var/stops_left = 0
	var/linger_until = 0

/datum/ambient_activity/ward_cell/pace/setup()
	if(!..())
		return FALSE
	stops_left = rand(3, 5)
	var/turf/stop = free_cell_tile(get_turf(doer))
	if(!stop)
		return FALSE
	go_to(stop)
	return TRUE

/datum/ambient_activity/ward_cell/pace/arrive()
	linger_until = world.time + rand(2 SECONDS, 5 SECONDS)

/datum/ambient_activity/ward_cell/pace/act(seconds)
	if(!cell())
		return AMBIENT_STEP_DONE
	if(world.time < linger_until)
		chatter(AMBIENT_LINE_IDLE, 40 SECONDS, 90 SECONDS)
		return AMBIENT_STEP_CONTINUE
	if(--stops_left <= 0)
		return AMBIENT_STEP_DONE
	var/turf/stop = free_cell_tile(get_turf(doer))
	if(!stop)
		return AMBIENT_STEP_DONE
	go_to(stop)
	return AMBIENT_STEP_MOVE

/datum/ambient_activity/ward_cell/pace/shift_times(delay)
	. = ..()
	linger_until = ambient_shifted(linger_until, delay)

/// The cell's toilet: a while at it, then a real flush
/datum/ambient_activity/ward_cell/toilet
	name = "using a cell toilet"
	duration_low = 20 SECONDS
	duration_high = 20 SECONDS
	var/datum/weakref/toilet_ref
	var/flush_at = 0

/datum/ambient_activity/ward_cell/toilet/setup()
	var/datum/outpost_police_cell/cell = cell()
	if(!cell)
		return FALSE
	for(var/turf/tile as anything in cell.tiles)
		var/obj/structure/toilet/toilet = locate() in tile
		if(!toilet)
			for(var/direction in GLOB.cardinals)
				toilet = locate() in get_step(tile, direction)
				if(toilet)
					break
		if(!toilet)
			continue
		toilet_ref = WEAKREF(toilet)
		var/turf/toilet_turf = get_turf(toilet)
		go_to((toilet_turf in cell.tiles) ? toilet_turf : tile)
		set_duration()
		return TRUE
	return FALSE

/datum/ambient_activity/ward_cell/toilet/arrive()
	var/obj/structure/toilet/toilet = toilet_ref?.resolve()
	if(toilet && !doer.buckled)
		doer.setDir(toilet.loc == doer.loc ? REVERSE_DIR(toilet.dir) : get_dir(doer, toilet))
	flush_at = world.time + rand(8 SECONDS, 14 SECONDS)

/datum/ambient_activity/ward_cell/toilet/act(seconds)
	var/obj/structure/toilet/toilet = toilet_ref?.resolve()
	if(!toilet || !cell())
		return AMBIENT_STEP_DONE
	if(flush_at && world.time >= flush_at)
		flush_at = 0
		if(doer.Adjacent(toilet) && !toilet.flushing)
			toilet.attack_hand_secondary(doer)
	return AMBIENT_STEP_CONTINUE

/datum/ambient_activity/ward_cell/toilet/shift_times(delay)
	. = ..()
	flush_at = ambient_shifted(flush_at, delay)

/// Knocking on the cell's glass and needling the sergeant, who answers
/datum/ambient_activity/ward_cell/knock
	name = "knocking on a cell window"
	duration_low = 10 SECONDS
	duration_high = 15 SECONDS
	/// The window or door he knocks on
	var/datum/weakref/glass_ref
	var/knocks_left = 0
	var/next_knock = 0

/datum/ambient_activity/ward_cell/knock/setup()
	var/datum/outpost_police_cell/cell = cell()
	if(!cell)
		return FALSE
	var/turf/door_turf = get_turf(cell.door)
	var/turf/stand
	var/atom/glass
	for(var/turf/tile as anything in shuffle(cell.tiles.Copy()))
		if(tile != get_turf(doer) && tile.is_blocked_turf(exclude_mobs = FALSE))
			continue
		if(door_turf && get_dist(tile, door_turf) == 1 && (get_dir(tile, door_turf) in GLOB.cardinals))
			stand = tile
			glass = cell.door
			break
		for(var/direction in GLOB.cardinals)
			var/obj/structure/window/window = locate() in get_step(tile, direction)
			if(window)
				stand = tile
				glass = window
				break
		if(stand)
			break
	if(!stand || !glass)
		return FALSE
	glass_ref = WEAKREF(glass)
	knocks_left = rand(2, 3)
	go_to(stand)
	set_duration()
	return TRUE

/datum/ambient_activity/ward_cell/knock/arrive()
	var/atom/glass = glass_ref?.resolve()
	if(glass && !doer.buckled)
		doer.face_atom(glass)
	next_knock = world.time + 1 SECONDS

/datum/ambient_activity/ward_cell/knock/act(seconds)
	var/atom/glass = glass_ref?.resolve()
	if(!glass || !cell())
		return AMBIENT_STEP_DONE
	if(knocks_left <= 0 || world.time < next_knock)
		return AMBIENT_STEP_CONTINUE
	knocks_left--
	next_knock = world.time + rand(2 SECONDS, 4 SECONDS)
	if(istype(glass, /obj/structure/window))
		glass.attack_hand(doer)
	else
		doer.visible_message(span_notice("[doer] knocks on [glass]."))
		playsound(glass, 'sound/effects/glass/glassknock.ogg', 50, TRUE)
	if(!knocks_left)
		doer.speak_context("heckle", null, force = TRUE)
		var/mob/living/carbon/human/npc/ambient_npc/outpost/job_ward/ward = doer
		if(istype(ward))
			ward.sergeant_answer()
	return AMBIENT_STEP_CONTINUE

/datum/ambient_activity/ward_cell/knock/shift_times(delay)
	. = ..()
	next_knock = ambient_shifted(next_knock, delay)

#undef WARD_HELD
#undef WARD_OUT
#undef WARD_ABOARD
#undef WARD_TAKEN
#undef WARD_GONE
#undef JAILBREAK_TRAIT
#undef WARD_GREET_RANGE
#undef WARD_CUFF_RANGE
#undef WARD_SERGEANT_RANGE
#undef WARD_DUCK_TIME
#undef WARD_FORCE_GRACE
#undef WARD_FOLLOW_PRIORITY
#undef WARD_PLACE_WORDS
