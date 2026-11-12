/**
 * # Outpost floors: the lift and who may come up
 *
 * Owner: P2 (spec 5). The lift itself is trade/outpost_elevator.dm; its floor seams call the
 * /obj/structure/overmap base procs in trade/outpost_hangar.dm (may_enter_floor(), extra_floor_rows(),
 * lift_leaves_behind(), on_lift_ride(), on_lift_emagged(), lift_refusal_text()), which answer as before floors.
 * This file overrides them on /obj/structure/overmap/trader_outpost, and get_floor_alcove() for ids 101 and up.
 * The panel's `floor`, `forced_until` and `force_ready_at` vars are declared in the lift file.
 *
 * Who the lift takes up (spec 5.1):
 * - the floor's own people, always (is_member(), floor_datum.dm);
 * - nobody the owner has barred, whatever else they are;
 * - a hired hand, and anyone holding a pass, whatever the setting;
 * - on an Invited floor the guest list, on an Open floor everyone;
 * - anyone at all to a floor its owner gave up, because it is claimed in person.
 * Whoever stands in the car when one of those sends it rides along, except a wing's prisoners (abuse A22) and a
 * barred rider with none of the floor's people in the car.
 *
 * may_visit() is that standing right and nothing else. A forced panel is the lift's own business
 * (may_enter_floor(), extra_floor_rows()): it opens every floor from the car it was forced in, and gives nobody a
 * right the floor's pad or doors would honour.
 */

/// Most characters of a floor's name or crew sent to the lift's window (build plan, OutpostElevator); the window cuts shorter
#define LIFT_ROW_TEXT_MAX 40
/// Whether a lift id is a leased floor's (101 and up), not the concourse's or a berth's
#define LIFT_IS_FLOOR_ID(id) (isnum(id) && (id) > OUTPOST_FLOOR_ID_BASE)

// ===== PRIVATE STATE =====

/datum/outpost_floor
	/// Passes (grant_pass()): weakref to a mind -> the world.time it runs out. OUTPOST_FLOOR_LIST_MAX at most.
	var/list/lift_passes
	/// The last departure lift_escorted() looked at: list(world.time, the car's first tile, whether one of the floor's people was aboard)
	var/list/lift_escort_cache

// ===== THE SETTING AND THE LISTS =====

/// Sets who the lift takes up (OUTPOST_FLOOR_ENTRY_*). With a `user` it is the owner's or a steward's to set; code passes none.
/// Wider or narrower, the lift follows at once: a car already on its way up is asked again when it leaves.
/datum/outpost_floor/proc/set_entry(new_entry, mob/user)
	if(!(new_entry in list(OUTPOST_FLOOR_ENTRY_CREW, OUTPOST_FLOOR_ENTRY_INVITED, OUTPOST_FLOOR_ENTRY_OPEN)))
		return FALSE
	if(user && !host?.can_manage(user))
		return FALSE
	if(entry_policy == new_entry)
		return TRUE
	var/old_entry = entry_policy
	entry_policy = new_entry
	log_game("OUTPOST FLOORS: [user ? key_name(user) : "the game"] set floor [number] of [outpost] from '[old_entry]' to '[new_entry]'.")
	record_floor_metric("floor_setting", src, user)
	outpost?.refresh_elevator_uis()
	// An Open floor keeps the police tick awake (police_floors.dm floors_have_work())
	outpost?.police?.wake()
	return TRUE

/// Whether the lift goes to this floor at all: it has been let and its shell stands
/datum/outpost_floor/proc/lift_serves()
	return (state == OUTPOST_FLOOR_STATE_OWNED || state == OUTPOST_FLOOR_STATE_VACANT) && length(alcove_turfs) > 0

/**
 * Whether `person` may send the car up to this floor alone: by being one of its people, by its setting and guest
 * list, as a hired hand or by a pass. A forced panel is not asked here (see the top of this file).
 */
/datum/outpost_floor/proc/may_visit(mob/person)
	if(!person || !lift_serves())
		return FALSE
	// Given up by its owner: anyone may come up and take it, in person (spec 7)
	if(state == OUTPOST_FLOOR_STATE_VACANT)
		return TRUE
	if(is_member(person))
		return TRUE
	if(is_barred(person))
		return FALSE
	if(is_hand(person) || lift_has_pass(person))
		return TRUE
	switch(entry_policy)
		if(OUTPOST_FLOOR_ENTRY_OPEN)
			return TRUE
		if(OUTPOST_FLOOR_ENTRY_INVITED)
			return is_guest(person)
	return FALSE

/// Whether `person` is on the guest list, themselves or by a crew they are on
/datum/outpost_floor/proc/is_guest(mob/person)
	return lift_listed(guests, person)

/// Whether `person` is barred, themselves or by a crew they are on
/datum/outpost_floor/proc/is_barred(mob/person)
	return lift_listed(barred, person)

/// Whether `person` is one of the floor's hired hands
/datum/outpost_floor/proc/is_hand(mob/person)
	return !!person?.mind && (person.mind in hands)

/// Whether `person` is in `entries` (minds and ships): themselves, or by a listed ship whose crew they are on now
/datum/outpost_floor/proc/lift_listed(list/entries, mob/person)
	var/datum/mind/mind = person?.mind
	if(!mind || !length(entries))
		return FALSE
	if(mind in entries)
		return TRUE
	if(!length(mind.ship_teams))
		return FALSE
	for(var/obj/structure/overmap/ship/crew_ship in entries)
		if(!QDELETED(crew_ship) && crew_ship.ship_team && (crew_ship.ship_team in mind.ship_teams))
			return TRUE
	return FALSE

/**
 * Lets one person send the car up for `duration`, whatever the floor's setting. A second pass for the same person
 * replaces the first. Nothing in this build calls it; it is there for outpost jobs. TRUE when the pass was given.
 */
/datum/outpost_floor/proc/grant_pass(datum/mind/holder, duration)
	if(!istype(holder) || !isnum(duration) || duration <= 0)
		return FALSE
	lift_prune_passes()
	var/datum/weakref/holder_ref = WEAKREF(holder)
	if(!holder_ref)
		return FALSE
	if(!LAZYACCESS(lift_passes, holder_ref) && LAZYLEN(lift_passes) >= OUTPOST_FLOOR_LIST_MAX)
		return FALSE
	LAZYSET(lift_passes, holder_ref, world.time + duration)
	return TRUE

/// Whether `person` holds a pass that has not run out
/datum/outpost_floor/proc/lift_has_pass(mob/person)
	var/datum/mind/mind = person?.mind
	if(!mind || !LAZYLEN(lift_passes))
		return FALSE
	var/runs_out = lift_passes[WEAKREF(mind)]
	return !!runs_out && runs_out > world.time

/// Drops the passes that have run out and those whose holder is gone
/datum/outpost_floor/proc/lift_prune_passes()
	var/list/spent = list()
	for(var/datum/weakref/holder_ref as anything in lift_passes)
		if(lift_passes[holder_ref] <= world.time || !holder_ref.resolve())
			spent += holder_ref
	for(var/datum/weakref/holder_ref as anything in spent)
		LAZYREMOVE(lift_passes, holder_ref)

/// Whether the two are on a ship's crew together
/datum/outpost_floor/proc/lift_same_crew(mob/first, mob/second)
	var/list/first_teams = first?.mind?.ship_teams
	var/list/second_teams = second?.mind?.ship_teams
	if(!length(first_teams) || !length(second_teams))
		return FALSE
	for(var/datum/team/voidcrew/team in first_teams)
		if(team in second_teams)
			return TRUE
	return FALSE

// ===== THE CAR =====

/// This floor's row in the lift's window (build plan, OutpostElevator). `is_own`: the viewer is one of its people.
/datum/outpost_floor/proc/lift_row(is_own)
	var/vacant = (state == OUTPOST_FLOOR_STATE_VACANT)
	var/list/row = list(
		"id" = lift_id(),
		"kind" = "floor",
		"name" = copytext_char(floor_name || "Floor [number]", 1, LIFT_ROW_TEXT_MAX + 1),
		"occupied" = TRUE,
		"your_ship" = !!is_own,
		"crew" = copytext_char(vacant ? "Vacant" : (crew_name() || ""), 1, LIFT_ROW_TEXT_MAX + 1),
		"accent" = accent_colour(),
	)
	// A floor nobody holds is neither private nor anybody's: it carries no mark
	if(is_own)
		row["mark"] = "yours"
	else if(!vacant)
		row["mark"] = (entry_policy == OUTPOST_FLOOR_ENTRY_OPEN) ? "open" : "private"
	return row

/**
 * Whether one of this floor's people is in the car at `car`, awake, as it leaves. complete_ride() empties the car
 * tile by tile, so the answer is taken once, before the first passenger has moved, and kept for that departure.
 */
/datum/outpost_floor/proc/lift_escorted(list/turf/car)
	if(!length(car))
		return FALSE
	if(lift_escort_cache && lift_escort_cache[1] == world.time && lift_escort_cache[2] == car[1])
		return lift_escort_cache[3]
	var/escorted = FALSE
	for(var/turf/tile as anything in car)
		for(var/mob/living/person in tile)
			if(person.stat == CONSCIOUS && is_member(person))
				escorted = TRUE
				break
		if(escorted)
			break
	lift_escort_cache = list(world.time, car[1], escorted)
	return escorted

/**
 * The players among `people` whom `rider` carried up with no say in it (spec 5.3, abuse A17): alive, cuffed or
 * out cold, with no right to come up alone, and not on the rider's crew. An NPC is never one: a bounty in cuffs
 * goes up to the wing like any other.
 */
/datum/outpost_floor/proc/lift_abducted(list/people, mob/rider)
	. = list()
	if(!rider?.mind)
		return
	for(var/mob/living/victim in people)
		if(victim == rider || !victim.mind || victim.stat == DEAD)
			continue
		if(victim.stat < UNCONSCIOUS && !HAS_TRAIT(victim, TRAIT_RESTRAINED))
			continue
		if(may_visit(victim) || lift_same_crew(victim, rider))
			continue
		. += victim

// ===== THE LIFT'S HOST =====

/// A leased floor's alcove for ids 101 and up, while the lift serves it; the concourse and the berths as ever
/obj/structure/overmap/trader_outpost/get_floor_alcove(floor_id)
	if(!LIFT_IS_FLOOR_ID(floor_id))
		return ..()
	var/datum/outpost_floor/floor = floor_by_id(floor_id)
	return floor?.lift_serves() ? floor.alcove_turfs : null

/// The lock on a floor: its setting and lists, or a panel forced in the rider's car. Riding down is the berth rule.
/obj/structure/overmap/trader_outpost/may_enter_floor(floor_id, mob/rider)
	if(!LIFT_IS_FLOOR_ID(floor_id))
		return ..()
	var/datum/outpost_floor/floor = floor_by_id(floor_id)
	// Nobody in the car who sent it (they stepped out, or went down): it does not go up
	if(!rider || !floor?.lift_serves())
		return FALSE
	return floor.may_visit(rider) || lift_forced_for(rider)

/// The floors `user` may ride to and no others, their own first; the one they stand on is always there
/obj/structure/overmap/trader_outpost/extra_floor_rows(mob/user)
	. = ..()
	if(!length(floors))
		return
	var/forced = lift_forced_for(user)
	var/datum/outpost_floor/standing_on = user ? floor_at(get_turf(user)) : null
	var/list/own_rows = list()
	var/list/other_rows = list()
	for(var/datum/outpost_floor/floor in floors)
		if(!floor.lift_serves())
			continue
		var/is_own = floor.is_member(user)
		if(!is_own && !forced && floor != standing_on && !floor.may_visit(user))
			continue
		if(is_own)
			own_rows += list(floor.lift_row(TRUE))
		else
			other_rows += list(floor.lift_row(FALSE))
	. += own_rows
	. += other_rows

/**
 * Who the car leaves standing in the alcove. A wing's prisoners never leave by the lift, on their feet or shut in
 * anything (abuse A22). Going up, someone the floor has barred stays down unless one of the floor's people is in
 * the car, or its lock was forced.
 */
/obj/structure/overmap/trader_outpost/lift_leaves_behind(atom/movable/thing, floor_id, mob/rider)
	. = ..()
	if(. || !thing)
		return
	// Going up to a floor that bars anyone: who is aboard is read now, on every call, so that the first call of a
	// departure reads it before anybody has moved (lift_escorted())
	var/datum/outpost_floor/floor = LIFT_IS_FLOOR_ID(floor_id) ? floor_by_id(floor_id) : null
	if(floor && (floor.state != OUTPOST_FLOOR_STATE_OWNED || !length(floor.barred)))
		floor = null
	var/turf/where = get_turf(thing)
	var/escorted = floor ? floor.lift_escorted(lift_car_at(where)) : TRUE
	var/list/mob/living/people = lift_people_in(thing)
	if(!length(people))
		return FALSE
	if(locate(/mob/living/carbon/human/npc/outpost_prisoner) in people)
		return TRUE
	if(!floor || escorted)
		return FALSE
	for(var/mob/living/person as anything in people)
		if(floor.is_barred(person) && !floor.is_member(person))
			return !lift_forced_at(where)
	return FALSE

/**
 * The car has arrived on a floor: the floor hears of it (COMSIG_OUTPOST_FLOOR_ENTERED, the chime), and the police
 * hear of a forced lock or of someone carried up who had no say in it. They judge it by who saw the car leave.
 */
/obj/structure/overmap/trader_outpost/on_lift_ride(obj/machinery/outpost_elevator/panel, floor_id, mob/rider, list/passengers)
	. = ..()
	if(!LIFT_IS_FLOOR_ID(floor_id))
		return
	var/datum/outpost_floor/floor = floor_by_id(floor_id)
	if(!floor)
		return
	// Who is upstairs now, whatever they came in: only those the car really set down
	var/list/mob/living/people = list()
	for(var/atom/movable/passenger in passengers)
		for(var/mob/living/person as anything in lift_people_in(passenger))
			if(get_turf(person) in floor.alcove_turfs)
				people |= person
	// The car only leaves for a rider with a right to go up or a forced lock, so no right means the lock
	var/forced = !!rider && !floor.may_visit(rider)
	SEND_SIGNAL(floor, COMSIG_OUTPOST_FLOOR_ENTERED, people, rider, forced)
	floor.on_lift_arriving()
	var/visitors = 0
	for(var/mob/living/person as anything in people)
		if(person.mind && !floor.is_member(person))
			visitors++
	if(visitors)
		record_floor_metric("floor_visit", floor, rider, visitors)
	if(!rider)
		return
	var/list/turf/left_from = panel?.get_own_alcove()
	var/turf/seen_at = length(left_from) ? left_from[round((length(left_from) + 1) / 2)] : get_turf(panel)
	if(forced)
		log_game("OUTPOST FLOORS: [key_name(rider)] rode a forced lift to floor [floor.number] of [src].")
		record_floor_metric("floor_lift_forced", floor, rider)
		police?.floor_lift_report(rider, OUTPOST_CRIME_LIFT_TAMPER, get_turf(panel) || seen_at, null)
	for(var/mob/living/victim as anything in floor.lift_abducted(people, rider))
		log_game("OUTPOST FLOORS: [key_name(rider)] took [key_name(victim)] up to floor [floor.number] of [src], cuffed or out cold.")
		police?.floor_lift_report(rider, OUTPOST_CRIME_ABDUCTION, seen_at, victim)

/**
 * An emag on a lift panel opens every floor from that panel's car for OUTPOST_FLOOR_LIFT_EMAG_TIME, the gate rule
 * (police L31). The panel cannot be forced again until OUTPOST_FLOOR_LIFT_EMAG_COOLDOWN after the lock came back,
 * so a second emag never restarts the window (abuse A30). Every floor's people are told. TRUE if it was forced.
 */
/obj/structure/overmap/trader_outpost/on_lift_emagged(obj/machinery/outpost_elevator/panel, mob/user)
	. = ..()
	if(. || QDELETED(panel) || panel.outpost != src)
		return
	var/any_floor = FALSE
	for(var/datum/outpost_floor/floor in floors)
		if(floor.lift_serves())
			any_floor = TRUE
			break
	if(!any_floor || panel.forced_until > world.time || world.time < panel.force_ready_at)
		if(user)
			panel.balloon_alert(user, "no response")
		return FALSE
	panel.forced_until = world.time + OUTPOST_FLOOR_LIFT_EMAG_TIME
	panel.force_ready_at = panel.forced_until + OUTPOST_FLOOR_LIFT_EMAG_COOLDOWN
	addtimer(CALLBACK(src, PROC_REF(lift_lock_mended), WEAKREF(panel)), OUTPOST_FLOOR_LIFT_EMAG_TIME, TIMER_DELETE_ME)
	log_game("OUTPOST FLOORS: [key_name(user)] forced the lift panel at [AREACOORD(panel)] of [src].")
	do_sparks(3, TRUE, panel)
	playsound(panel, SFX_SPARKS, 50, TRUE, SILENCED_SOUND_EXTRARANGE)
	if(user)
		panel.balloon_alert(user, "lock shorted")
	for(var/datum/outpost_floor/floor in floors)
		if(floor.state == OUTPOST_FLOOR_STATE_OWNED && floor.lift_serves())
			floor.host?.ship_notify("Lift override on your floor.", "SECURITY", SHIP_NOTIFY_WARNING, 'voidcrew/sound/notify.ogg', 30)
	if(user)
		police?.floor_lift_report(user, OUTPOST_CRIME_LIFT_TAMPER, get_turf(panel), null)
	SStgui.update_uis(panel)
	return TRUE

/// What the lift says when it will not go up to a floor
/obj/structure/overmap/trader_outpost/lift_refusal_text(floor_id, spoken = FALSE)
	if(!LIFT_IS_FLOOR_ID(floor_id))
		return ..()
	return spoken ? "Floor [floor_id - OUTPOST_FLOOR_ID_BASE] is private." : "private floor!"

/// The floors' own panels show the list too
/obj/structure/overmap/trader_outpost/refresh_elevator_uis()
	..()
	for(var/datum/outpost_floor/floor in floors)
		if(floor.panel)
			SStgui.update_uis(floor.panel)

// ===== HELPERS =====

/// Every lift panel of this outpost: the concourse's, the berths' and the floors'
/obj/structure/overmap/trader_outpost/proc/lift_panels()
	. = list()
	for(var/obj/machinery/outpost_elevator/panel in lobby_panels)
		. += panel
	for(var/datum/outpost_berth/berth in berths)
		if(berth.panel)
			. += berth.panel
	for(var/datum/outpost_floor/floor in floors)
		if(floor.panel)
			. += floor.panel

/// The lift alcove `where` is a tile of: the concourse's, a berth's or a floor's. Null when it is in none.
/obj/structure/overmap/trader_outpost/proc/lift_car_at(turf/where)
	if(!where)
		return null
	if(where in lobby_alcove_turfs)
		return lobby_alcove_turfs
	for(var/datum/outpost_berth/berth in berths)
		if(where in berth.alcove_turfs)
			return berth.alcove_turfs
	for(var/datum/outpost_floor/floor in floors)
		if(where in floor.alcove_turfs)
			return floor.alcove_turfs
	return null

/// Whether the car `where` is a tile of has a forced panel
/obj/structure/overmap/trader_outpost/proc/lift_forced_at(turf/where)
	if(!where)
		return FALSE
	for(var/obj/machinery/outpost_elevator/panel as anything in lift_panels())
		if(panel.forced_until > world.time && (where in panel.get_own_alcove()))
			return TRUE
	return FALSE

/// Whether `user` is at a forced panel: in its car, or close enough to work it
/obj/structure/overmap/trader_outpost/proc/lift_forced_for(mob/user)
	var/turf/where = get_turf(user)
	if(!where)
		return FALSE
	for(var/obj/machinery/outpost_elevator/panel as anything in lift_panels())
		if(panel.forced_until <= world.time)
			continue
		if((where in panel.get_own_alcove()) || (panel.z == where.z && get_dist(panel, where) <= 1))
			return TRUE
	return FALSE

/// The living mobs `thing` is, holds or carries, however deep: someone in a locker, a body bag folded into a pack,
/// whoever is strapped to a bed
/obj/structure/overmap/trader_outpost/proc/lift_people_in(atom/movable/thing)
	if(QDELETED(thing) || isobserver(thing) || iseffect(thing))
		return list()
	. = thing.get_all_contents_type(/mob/living)
	for(var/mob/living/strapped in thing.buckled_mobs)
		. |= strapped.get_all_contents_type(/mob/living)

/// A forced panel's time is up: its lock is seen coming back
/obj/structure/overmap/trader_outpost/proc/lift_lock_mended(datum/weakref/panel_ref)
	var/obj/machinery/outpost_elevator/panel = panel_ref?.resolve()
	if(QDELETED(panel) || panel.forced_until > world.time)
		return
	playsound(panel, 'sound/machines/ping.ogg', 40, FALSE, SILENCED_SOUND_EXTRARANGE)
	panel.visible_message(span_notice("[panel] clicks, and its lock light comes back on."))
	SStgui.update_uis(panel)

#undef LIFT_IS_FLOOR_ID
#undef LIFT_ROW_TEXT_MAX
