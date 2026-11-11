/**
 * # Outpost police: the core
 *
 * Owner: P0 seams, frozen. Packages never edit this file; they fill the stubs in their own files.
 *
 * One /datum/outpost_police per trader outpost (`outpost.police`). It holds warrants (mind -> heat, this
 * outpost only), the officers on the roster, the station's parts (lift tiles, desk, cells, property lockers,
 * evidence chute) and a one-second tick that runs while there is anything to do. Every crime at the outpost
 * enters through report_crime() (police_wanted.dm). Officers are ambient outpost NPCs with a stealth guard's
 * brain (/datum/ai_controller/basic_controller/human_npc/stealth/outpost_police, in
 * voidcrew/modules/stealth_police/police_stealth.dm: it overrides stealth procs, so it is included after stealth).
 *
 * Who owns what (spec and build plan in the parent checkout's data/outpost-police/):
 * - police_wanted.dm, police_perception.dm: warrants, heat, stars, fines, embargoes, witnesses (P1)
 * - police_units.dm: officer bodies, profiles, police cuffs (P2)
 * - police_life.dm: routines, roles, speech (P3)
 * - police_dispatch.dm, police_force.dm: sectors, lifts, waves, targeting, fire rules (P4)
 * - police_arrest.dm: the arrest case (P5)
 * - police_cell.dm: cells, police doors and cell doors (P6)
 * - police_property.dm: confiscation, evidence chute, property lockers, the jail strip (P12)
 * - police_hud.dm: the wanted alert (P8)
 * - police_cutter.dm: the cutter (P9)
 *
 * Include order: this module comes after ambient_npcs, bounties, human_npcs and npc_ships, and before
 * overmap, player_outposts and trade. An override placed here of a proc that is first declared (proc/) in
 * one of those later modules never runs (traps: dm-language.md); add new procs or subtypes instead.
 */

/**
 * Every crime the police know: crime -> list(points, ceiling, floor). Points are heat; ceiling and floor are
 * stars. A crime never takes a warrant past its ceiling, and always takes it to at least its floor.
 */
GLOBAL_LIST_INIT(outpost_crimes, list(
	(OUTPOST_CRIME_ASSAULT_UNARMED) = list(6, 2, 0),
	(OUTPOST_CRIME_ASSAULT_ARMED) = list(9, 3, 0),
	(OUTPOST_CRIME_ASSAULT_SHOT) = list(25, 3, 0),
	(OUTPOST_CRIME_MURDER) = list(60, 5, 3),
	(OUTPOST_CRIME_VANDALISM) = list(5, 2, 0),
	(OUTPOST_CRIME_ASSAULT_STAFF) = list(8, 2, 0),
	(OUTPOST_CRIME_ASSAULT_CIVILIAN) = list(12, 3, 0),
	(OUTPOST_CRIME_KILL_CIVILIAN) = list(40, 4, 0),
	(OUTPOST_CRIME_WEAPON_DRAWN) = list(0, 1, 1),
	(OUTPOST_CRIME_GUNFIRE) = list(15, 2, 0),
	(OUTPOST_CRIME_CHECKPOINT_BREACH) = list(0, 2, 2),
	(OUTPOST_CRIME_TRESPASS) = list(0, 2, 2),
	(OUTPOST_CRIME_RESIST) = list(8, 3, 0),
	(OUTPOST_CRIME_ASSAULT_OFFICER) = list(30, 4, 3),
	(OUTPOST_CRIME_KILL_OFFICER) = list(45, 5, 3),
	(OUTPOST_CRIME_SLIP_CUFFS) = list(10, 3, 0),
	(OUTPOST_CRIME_ABET) = list(15, 2, 0),
	(OUTPOST_CRIME_JAILBREAK) = list(0, 3, 3),
	(OUTPOST_CRIME_ACCOMPLICE) = list(0, 2, 2),
	(OUTPOST_CRIME_LOCKER_THEFT) = list(0, 2, 2),
	(OUTPOST_CRIME_KILL_STAFF) = list(60, 5, 4),
	(OUTPOST_CRIME_GATE_TAMPER) = list(0, 2, 2),
	(OUTPOST_CRIME_ARMED_ROBBERY) = list(30, 3, 2),
))

// =========================================================================
// THE OUTPOST'S POLICE
// =========================================================================

/obj/structure/overmap/trader_outpost
	/// This outpost's police (police_core.dm). Made by ensure_police(), deleted in Destroy().
	var/datum/outpost_police/police

/**
 * Makes the police on first need. SSovermap pre-loads an outpost's interior before SSatoms has run its
 * Initialize (see ensure_main_shop()), so both Initialize and the interior link come through here.
 */
/obj/structure/overmap/trader_outpost/proc/ensure_police()
	if(!police)
		police = new /datum/outpost_police(src)
	return police

/datum/outpost_police
	/// The outpost these officers keep
	var/obj/structure/overmap/trader_outpost/outpost
	/// The zone's profile: names, numbers and kit (police_units.dm, make_profile())
	var/datum/outpost_police_profile/profile
	/// Warrants here: mind -> /datum/outpost_warrant. Written by police_wanted.dm only.
	var/list/warrants = list()
	/// The witness test (police_perception.dm, make_perception()). The one seam the stealth merge swaps.
	var/datum/outpost_police_perception/perception
	/// The station's property lockers (behaviour in police_property.dm)
	var/list/obj/structure/closet/secure_closet/personal/outpost_police/lockers = list()
	/// The evidence chute at the desk
	var/obj/machinery/outpost_police_evidence/chute
	/// Every officer on the roster, alive or dead. Use add_officer() and remove_officer().
	var/list/mob/living/carbon/human/npc/ambient_npc/outpost/police/officers = list()
	/// The police lift tiles behind the police doors on the concourse
	var/list/turf/lift_turfs = list()
	/// The cells, built by build_cells() (police_cell.dm)
	var/list/datum/outpost_police_cell/cells = list()
	/// The sergeant's tile at the desk
	var/turf/desk_turf
	/// Open arrests: mind -> /datum/outpost_police_case. Written by police_arrest.dm only.
	var/list/cases = list()
	/// The looping one-second tick (wake()), or null while asleep
	var/tick_timer
	/// world.time the tick last found nothing to do, or 0
	var/idle_since = 0

/datum/outpost_police/New(obj/structure/overmap/trader_outpost/new_outpost)
	. = ..()
	outpost = new_outpost
	profile = make_profile()
	perception = make_perception()
	// The wanted core's event hooks (police_wanted.dm): here, so a perception subtype never loses them
	hook_events()

/datum/outpost_police/Destroy()
	if(tick_timer)
		deltimer(tick_timer)
		tick_timer = null
	// Typed: a hard-deleted officer leaves a null in the list
	for(var/mob/living/carbon/human/npc/ambient_npc/outpost/police/officer in officers.Copy())
		remove_officer(officer)
		if(officer.police == src)
			officer.police = null
	officers.Cut()
	QDEL_LIST_ASSOC_VAL(cases)
	QDEL_LIST_ASSOC_VAL(warrants)
	QDEL_LIST(cells)
	QDEL_NULL(perception)
	QDEL_NULL(profile)
	lockers.Cut()
	lift_turfs.Cut()
	chute = null
	desk_turf = null
	outpost = null
	return ..()

// ----- the tick -----

/// Starts the tick if it is not running. Safe to call from signal handlers: it never sleeps.
/datum/outpost_police/proc/wake()
	idle_since = 0
	if(tick_timer || QDELETED(src))
		return
	tick_timer = addtimer(CALLBACK(src, PROC_REF(tick)), 1 SECONDS, TIMER_STOPPABLE | TIMER_LOOP | TIMER_DELETE_ME)

/// Once a second while awake. Each step belongs to its package; the order is frozen.
/datum/outpost_police/proc/tick()
	tick_warrants() // P1, police_wanted.dm
	tick_dispatch() // P4, police_dispatch.dm
	tick_cases() // P5, police_arrest.dm
	tick_cells() // P6, police_cell.dm
	tick_life() // P3, police_life.dm
	if(has_work())
		idle_since = 0
		return
	if(!idle_since)
		idle_since = world.time
	else if(world.time - idle_since >= OUTPOST_POLICE_IDLE_STOP)
		sleep_tick()

/// Stops the tick (TIMER_DELETE_ME: this runs from the timer's own callback)
/datum/outpost_police/proc/sleep_tick()
	if(tick_timer)
		deltimer(tick_timer)
		tick_timer = null
	idle_since = 0

/// Whether there is a warrant, a response unit or a prisoner to look after
/datum/outpost_police/proc/has_work()
	if(length(warrants) || length(cases))
		return TRUE
	for(var/datum/outpost_police_cell/cell as anything in cells)
		if(length(cell.prisoners))
			return TRUE
	for(var/mob/living/carbon/human/npc/ambient_npc/outpost/police/officer in officers)
		if(officer.stat != DEAD && officer.unit_kind != POLICE_UNIT_BEAT && officer.unit_kind != POLICE_UNIT_SERGEANT)
			return TRUE
	return FALSE

// ----- the roster -----

/// `officer` is one of ours now
/datum/outpost_police/proc/add_officer(mob/living/carbon/human/npc/ambient_npc/outpost/police/officer)
	if(QDELETED(officer) || (officer in officers))
		return
	if(officer.police && officer.police != src)
		officer.police.remove_officer(officer)
	officer.police = src
	officers += officer
	RegisterSignal(officer, COMSIG_QDELETING, PROC_REF(on_officer_deleted))

/// `officer` leaves the roster (and so the caps). Their `police` stays set; the caller decides what they do next.
/datum/outpost_police/proc/remove_officer(mob/living/carbon/human/npc/ambient_npc/outpost/police/officer)
	if(!(officer in officers))
		return
	officers -= officer
	UnregisterSignal(officer, COMSIG_QDELETING)

/datum/outpost_police/proc/on_officer_deleted(mob/living/carbon/human/npc/ambient_npc/outpost/police/officer)
	SIGNAL_HANDLER
	remove_officer(officer)
	officer.police = null

// ----- the station -----

/**
 * The outpost's interior link (trade/outpost.dm) hands over everything the template placed for the police:
 * `landmarks` (lift, desk and cell landmarks), `doors` (police doors and cell doors), `signs` (cell signs),
 * `lockers` (property lockers) and the evidence `chute`. The cells and the property are built from them,
 * then the landmarks are deleted.
 */
/datum/outpost_police/proc/link_interior(list/landmarks, list/doors, list/signs, list/new_lockers, obj/machinery/outpost_police_evidence/new_chute)
	var/list/cell_landmarks = list()
	var/list/cell_doors = list()
	for(var/obj/effect/landmark/mark as anything in landmarks)
		if(istype(mark, /obj/effect/landmark/outpost_police_lift))
			lift_turfs |= get_turf(mark)
		else if(istype(mark, /obj/effect/landmark/outpost_police_desk))
			if(desk_turf)
				log_mapping("OUTPOST POLICE: [outpost] has more than one desk landmark ([AREACOORD(mark)]).")
			desk_turf = get_turf(mark)
		else if(istype(mark, /obj/effect/landmark/outpost_police_cell))
			cell_landmarks += mark
	for(var/obj/machinery/door/airlock/outpost/door as anything in doors)
		door.outpost = outpost
		if(istype(door, /obj/machinery/door/airlock/outpost/glass/police_cell))
			cell_doors += door
	for(var/obj/structure/closet/secure_closet/personal/outpost_police/locker as anything in new_lockers)
		lockers |= locker
	if(new_chute)
		if(chute && chute != new_chute)
			log_mapping("OUTPOST POLICE: [outpost] has more than one evidence chute ([AREACOORD(new_chute)]).")
		chute = new_chute
	// The cells read their landmarks' tiles, so the landmarks go only after
	build_cells(cell_landmarks, cell_doors, signs) // P6, police_cell.dm
	build_property(lockers, chute) // P12, police_property.dm
	read_stop_tags() // P13, voidcrew/modules/stealth_police/police_stealth.dm
	for(var/obj/effect/landmark/mark as anything in landmarks)
		qdel(mark)

// =========================================================================
// SHARED DATUMS (vars only; behaviour lives with each owner)
// =========================================================================

/// One person's record at one outpost. Every var is written by police_wanted.dm (P1) only; everyone reads.
/datum/outpost_warrant
	/// Whose record this is
	var/datum/mind/mind
	/// Current heat (0 to OUTPOST_POLICE_HEAT_CAP)
	var/heat = 0
	/// Highest heat this incident
	var/peak = 0
	/// Heat a faded warrant left behind: the next crime starts from it
	var/prior = 0
	/// world.time the prior was set
	var/prior_set_at = 0
	/// world.time of the last counted crime
	var/last_crime_at = 0
	/// world.time an officer last saw them
	var/last_seen_at = 0
	/// Where they were last seen
	var/turf/last_seen_turf
	/// world.time since when no officer has seen them, or 0
	var/unseen_since = 0
	/// An arrest stood by them in crit and gave up (police_arrest.dm step_downed()): while they lie in crit, nobody
	/// counts as seeing them, so the hide clock runs. Cleared once they are out of crit.
	var/left_lying = FALSE
	/// world.time since when they have been away from the outpost, or 0
	var/away_since = 0
	/// world.time until which they are refused service (a faded warrant of three stars or more)
	var/barred_until = 0
	/// The crew they were on at their first crime (abuse M7): fine, bail, embargo and accomplices use it
	var/datum/voidcrew_crew_record/crew
	/// Officers they killed this incident
	var/officers_killed = 0
	/// Victims hit lately: weakref -> world.time of the last counted hit (for killings)
	var/list/recent_victims
	/// Weakrefs to the items used in counted crimes, OUTPOST_POLICE_EVIDENCE_MAX at most, oldest first
	var/list/evidence
	/// The fine's star level, fixed at the first charge so bail asks for the same sum (1 or 2), or 0
	var/fine_level = 0

/datum/outpost_warrant/Destroy()
	mind = null
	crew = null
	last_seen_turf = null
	evidence = null
	recent_victims = null
	return ..()

/// A zone's police: what they are called, how many walk the beat, the fine, the comply time, mercy, voice and kit.
/// police_units.dm (P2) sets the values on the three subtypes and picks one in make_profile().
/datum/outpost_police_profile
	/// What the force is called ("Halcyon Port Authority"), shown on the wanted alert
	var/force_name = "Outpost Police"
	/// Beat officers on the concourse
	var/beat_count = 2
	/// The fine is multiplied by this
	var/fine_multiplier = 1
	/// How long a suspect is given to comply with an order
	var/comply_time = 3 SECONDS
	/// Whether officers leave a downed suspect alone at three stars and up
	var/spares_downed = TRUE
	/// Section of AMBIENT_STRINGS_POLICE the officers speak from
	var/voice_section = "halcyon"
	/// POLICE_UNIT_* -> /datum/outfit type
	var/list/outfits = list()

/// One arrest in progress. Vars written by police_arrest.dm (P5) only.
/datum/outpost_police_case
	/// The warrant being served
	var/datum/outpost_warrant/warrant
	/// The step it is on (P5's names)
	var/step
	/// Weakrefs to the arresting officer, then the cover officer
	var/list/officers = list()
	/// world.time the current step started
	var/step_started_at = 0
	/// Times a step timed out and the case went back to the start
	var/resets = 0

/// One holding cell. Vars written by police_cell.dm (P6) only.
/datum/outpost_police_cell
	/// The id its landmarks, door and sign share
	var/cell_id
	/// The cell's floor
	var/list/turf/tiles = list()
	/// Its door
	var/obj/machinery/door/airlock/outpost/glass/police_cell/door
	/// Its sign
	var/obj/machinery/status_display/outpost_berth/police_cell/sign
	/// Prisoners: mind -> world.time they are let out
	var/list/prisoners = list()
	/// Prisoners serving a jail term rather than processing: mind -> TRUE
	var/list/jailed = list()

/// The witness test. Procs in police_perception.dm (P1), the only police file that names can_see.
/datum/outpost_police_perception
	/// The police it works for
	var/datum/outpost_police/police
	/// Whoever witnessed the last crime witness_of() was asked about
	var/atom/last_witness

/datum/outpost_police_perception/New(datum/outpost_police/new_police)
	. = ..()
	police = new_police

/datum/outpost_police_perception/Destroy()
	police = null
	last_witness = null
	return ..()

// =========================================================================
// OFFICERS
// =========================================================================

/**
 * An outpost police officer: an ambient outpost NPC (routines, talk, the empty-outpost pause) with a human
 * NPC's fighting brain. Bodies, kit and profiles are police_units.dm's (P2).
 */
/mob/living/carbon/human/npc/ambient_npc/outpost/police
	name = "outpost officer"
	desc = "Keeps the peace here."
	ai_controller = /datum/ai_controller/basic_controller/human_npc/stealth/outpost_police
	/// The police they serve
	var/datum/outpost_police/police
	/// POLICE_UNIT_*
	var/unit_kind = POLICE_UNIT_BEAT
	/// The arrest they are working, if any. Written by police_arrest.dm (P5).
	var/datum/outpost_police_case/case
	/// How hard they go at their target, POLICE_FORCE_*. Written by police_force.dm (P4).
	var/force = POLICE_FORCE_NONE

/mob/living/carbon/human/npc/ambient_npc/outpost/police/Destroy()
	police?.remove_officer(src)
	police = null
	case = null
	return ..()

/// Walks the concourse
/mob/living/carbon/human/npc/ambient_npc/outpost/police/beat
	unit_kind = POLICE_UNIT_BEAT

/// Runs the desk
/mob/living/carbon/human/npc/ambient_npc/outpost/police/sergeant
	unit_kind = POLICE_UNIT_SERGEANT

/// A response officer, sent by dispatch
/mob/living/carbon/human/npc/ambient_npc/outpost/police/officer
	unit_kind = POLICE_UNIT_OFFICER

/// The heavy response
/mob/living/carbon/human/npc/ambient_npc/outpost/police/tactical
	unit_kind = POLICE_UNIT_TACTICAL

/// The top of the ladder
/mob/living/carbon/human/npc/ambient_npc/outpost/police/marshal
	unit_kind = POLICE_UNIT_MARSHAL

// The officers' brain is a stealth guard's: see voidcrew/modules/stealth_police/police_stealth.dm.

// =========================================================================
// THE MAP KIT (placed by P7; behaviour by P6 and P12)
// =========================================================================

/// A police lift tile, behind a police door on the concourse. Consumed at link.
/obj/effect/landmark/outpost_police_lift
	name = "outpost police lift"

/// The sergeant's tile at the desk. Consumed at link.
/obj/effect/landmark/outpost_police_desk
	name = "outpost police desk"

/// One floor tile of a holding cell; the tiles of one cell share a `cell_id`. Consumed at link.
/obj/effect/landmark/outpost_police_cell
	name = "outpost police cell"
	/// Which cell
	var/cell_id

/// A door officers use between the concourse and their lift. Behaviour in police_cell.dm (P6).
/obj/machinery/door/airlock/outpost/police
	name = "police door"
	req_access = list(ACCESS_OUTPOST_POLICE)

/// A holding cell's glass door. Opens only through its cell (police_cell.dm, P6).
/obj/machinery/door/airlock/outpost/glass/police_cell
	name = "cell door"
	/// Which cell
	var/cell_id

/// The sign over a cell door. Text from police_cell.dm (P6).
/obj/machinery/status_display/outpost_berth/police_cell
	name = "cell display"
	/// Which cell
	var/cell_id

MAPPING_DIRECTIONAL_HELPERS(/obj/machinery/status_display/outpost_berth/police_cell, 32)

/**
 * Whether outpost property lets a crowbar get to work on this (see /datum/element/outpost_property). Only a
 * checkpoint's inner door says yes (trade/outpost_checkpoint.dm), and a cell door (police_cell.dm, P6).
 * Declared here rather than in trade/ so the police module, included earlier, can override it.
 */
/obj/proc/outpost_forceable()
	return FALSE
