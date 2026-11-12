/**
 * # Outpost floors: the police
 *
 * Owner: P5 (spec 6). Lives here and not in voidcrew/modules/outpost_police so that it may override anything trade
 * or the police declare. The police tick calls tick_floors() after tick_warrants(); has_work() asks
 * floors_have_work(); dispatch, perception, the morgue crew and the door hook fall through to the procs below.
 * `warrant_in_force` and `public_ground` on a floor are written here and nowhere else (P1's leave_ground() clears
 * both when a floor loses its ground).
 *
 * The two flags are the whole of the law on a floor: get_trader_outpost_for_turf() (trade/outpost.dm) counts a floor
 * as the outpost's ground while either is set, and every crime, witness, arrest and morgue rule downstairs then
 * works there unchanged. What this file adds is when they are set, what a floor is to dispatch (a sector whose lift
 * tiles are its alcove), who opens a floor's doors, and the crimes the lift reports.
 *
 * - Public ground (spec 6.3, L24, L38): set at once while the floor is Open. Narrowed, it stays set for
 *   OUTPOST_FLOOR_CLOSING_TIME at least, and after that while anyone but the floor's own people is up there, alive
 *   or dead, and while one of its people is wanted here. Guests and hired hands are visitors for this.
 * - Warrant (spec 6.4, L12, A51): a living suspect of POLICE_FLOOR_WARRANT_STARS or more on the floor, any setting.
 *   POLICE_FLOOR_WARRANT_TAIL with none there and the squad is stood down; the warrant then lasts while an officer
 *   or a morgue worker is still up there, POLICE_FLOOR_WARRANT_MAX_TAIL at most.
 *
 * The tick only runs while the police are awake. Anything that changes a floor wakes them: a lift arrival
 * (COMSIG_OUTPOST_FLOOR_ENTERED), the console asking visitors_upstairs(), and every counted crime.
 */

/datum/outpost_floor
	/// world.time the floor stopped being Open while it was public ground, or 0
	var/police_narrowed_at = 0
	/// world.time a suspect of POLICE_FLOOR_WARRANT_STARS or more was last on the floor
	var/police_suspect_at = 0
	/// world.time the squad was stood down from this floor's warrant, or 0
	var/police_stood_down_at = 0
	/// Whether the police hear this floor's lift arrivals (COMSIG_OUTPOST_FLOOR_ENTERED)
	var/police_listening = FALSE

// =========================================================================
// THE TICK
// =========================================================================

/// Once a second: warrants on floors start and end, and each floor's `public_ground` is kept (spec 6.3, 6.4, L38)
/datum/outpost_police/proc/tick_floors()
	if(!outpost || !length(outpost.floors))
		return
	var/list/suspects_on = floors_suspects_by_floor()
	for(var/datum/outpost_floor/floor in outpost.floors)
		if(!floor.police_listening)
			floor.police_listening = TRUE
			RegisterSignal(floor, COMSIG_OUTPOST_FLOOR_ENTERED, PROC_REF(floors_on_arrival))
		if(length(floor.bounds) < 5)
			floors_clear(floor)
			continue
		floors_keep_warrant(floor, suspects_on[floor])
		floors_keep_public(floor)
	floors_settle_woken()
	breach_walk_offer_idle()

/// Whether a floor gives the police something to do: a warrant, public ground, or an Open floor not yet marked public
/datum/outpost_police/proc/floors_have_work()
	if(LAZYLEN(floors_woken))
		return TRUE
	for(var/datum/outpost_floor/floor in outpost?.floors)
		if(floor.warrant_in_force || floor.public_ground)
			return TRUE
		if(length(floor.bounds) >= 5 && floor.entry_policy == OUTPOST_FLOOR_ENTRY_OPEN)
			return TRUE
	return FALSE

/// The car set someone down on `source`: an Open floor is public ground at once, and the police look at it
/datum/outpost_police/proc/floors_on_arrival(datum/outpost_floor/source, list/riders, mob/rider, forced)
	SIGNAL_HANDLER
	if(length(source.bounds) >= 5 && source.entry_policy == OUTPOST_FLOOR_ENTRY_OPEN)
		source.public_ground = TRUE
		source.police_narrowed_at = 0
	wake()

/// A floor with no ground is nobody's ground
/datum/outpost_police/proc/floors_clear(datum/outpost_floor/floor)
	floor.warrant_in_force = FALSE
	floor.public_ground = FALSE
	floor.police_narrowed_at = 0
	floor.police_suspect_at = 0
	floor.police_stood_down_at = 0

/// Each floor of this outpost with a living suspect of POLICE_FLOOR_WARRANT_STARS or more on it, to a list of their warrants
/datum/outpost_police/proc/floors_suspects_by_floor()
	. = list()
	for(var/datum/mind/mind as anything in warrants)
		if(!mind)
			continue
		var/datum/outpost_warrant/warrant = warrants[mind]
		if(!warrant || stars_of(warrant.heat) < POLICE_FLOOR_WARRANT_STARS)
			continue
		var/mob/living/body = mind.current
		if(!isliving(body) || body.stat == DEAD)
			continue
		var/datum/outpost_floor/floor = outpost.floor_at(get_turf(body))
		if(!floor)
			continue
		var/list/on_floor = .[floor]
		if(!on_floor)
			on_floor = list()
			.[floor] = on_floor
		on_floor += warrant

/// Starts, keeps and ends `floor`'s warrant. `suspects`: the warrants of 3+ star suspects on it now (A51)
/datum/outpost_police/proc/floors_keep_warrant(datum/outpost_floor/floor, list/suspects)
	if(length(suspects))
		floor.police_suspect_at = world.time
		floor.police_stood_down_at = 0
		if(!floor.warrant_in_force)
			floor.warrant_in_force = TRUE
			floors_warrant_wake()
			log_game("OUTPOST POLICE: a warrant is in force on floor [floor.number] of [outpost].")
		// The lift tells security where the car went: they always know which floor, never where on it
		var/turf/landing = floors_landing_point(floor)
		for(var/datum/outpost_warrant/warrant as anything in suspects)
			if(landing && !floor.contains_turf(warrant.last_seen_turf))
				warrant.last_seen_turf = landing
		return
	if(!floor.warrant_in_force)
		return
	if(!floor.police_stood_down_at)
		if(world.time - floor.police_suspect_at < POLICE_FLOOR_WARRANT_TAIL)
			return
		floor.police_stood_down_at = world.time
		floors_stand_down(floor)
	if(world.time - floor.police_stood_down_at < POLICE_FLOOR_WARRANT_MAX_TAIL && floors_staff_upstairs(floor))
		return
	floor.warrant_in_force = FALSE
	floor.police_suspect_at = 0
	floor.police_stood_down_at = 0
	log_game("OUTPOST POLICE: the warrant on floor [floor.number] of [outpost] has ended.")

/**
 * Keeps `floor.public_ground` (spec 6.3, L24, L38, A56, A78). Opening is at once. Narrowing takes effect only once
 * OUTPOST_FLOOR_CLOSING_TIME has passed, nobody but the floor's own people is up there, alive or dead, and none of
 * its people is wanted here.
 */
/datum/outpost_police/proc/floors_keep_public(datum/outpost_floor/floor)
	if(floor.entry_policy == OUTPOST_FLOOR_ENTRY_OPEN)
		floor.public_ground = TRUE
		floor.police_narrowed_at = 0
		return
	if(!floor.public_ground)
		floor.police_narrowed_at = 0
		return
	if(!floor.police_narrowed_at)
		floor.police_narrowed_at = world.time
	if(world.time - floor.police_narrowed_at < OUTPOST_FLOOR_CLOSING_TIME)
		return
	if(length(floor.visitors_upstairs()) || floors_member_wanted(floor))
		return
	floor.public_ground = FALSE
	floor.police_narrowed_at = 0
	log_game("OUTPOST POLICE: floor [floor.number] of [outpost] is private again.")

/// Whether one of `floor`'s own people is wanted at this outpost (one star or more)
/datum/outpost_police/proc/floors_member_wanted(datum/outpost_floor/floor)
	for(var/datum/mind/mind as anything in warrants)
		if(!mind || !mind.current)
			continue
		var/datum/outpost_warrant/warrant = warrants[mind]
		if(warrant && stars_of(warrant.heat) >= 1 && floor.is_member(mind.current))
			return TRUE
	return FALSE

/// Whether an officer or a morgue worker of this outpost is still on `floor`
/datum/outpost_police/proc/floors_staff_upstairs(datum/outpost_floor/floor)
	for(var/mob/living/carbon/human/npc/ambient_npc/outpost/police/officer in officers)
		if(officer.stat != DEAD && floor.contains_turf(get_turf(officer)))
			return TRUE
	for(var/mob/living/carbon/human/npc/ambient_npc/outpost/recovery/worker in floor.police_people())
		if(worker.stat != DEAD)
			return TRUE
	return FALSE

/// Response units on `floor` that are after nobody else at the outpost leave by its alcove, and one calls it in
/datum/outpost_police/proc/floors_stand_down(datum/outpost_floor/floor)
	var/called_in = FALSE
	for(var/mob/living/carbon/human/npc/ambient_npc/outpost/police/officer in officers)
		if(officer.stat == DEAD || officer.case || officer.npc_exit || !dispatch_is_response_unit(officer))
			continue
		if(!floor.contains_turf(get_turf(officer)))
			continue
		// Still after someone wanted elsewhere at the outpost: the sectors take them there
		var/datum/mind/target = officer.dispatch_mind?.resolve()
		var/mob/living/suspect = target?.current
		if(isliving(suspect) && suspect.stat != DEAD && get_stars(target) > 0 && dispatch_at_outpost(suspect) && !floor.contains_turf(get_turf(suspect)))
			continue
		officer.dispatch_mind = null
		var/turf/exit = dispatch_nearest_lift_point(floor, officer)
		officer.npc_walk_out(exit || get_turf(officer))
		if(!called_in)
			called_in = TRUE
			INVOKE_ASYNC(officer, TYPE_PROC_REF(/mob/living/carbon/human/npc/ambient_npc/outpost/police, police_say), POLICE_LINE_CLEAR, null, TRUE)

/// The middle tile of `floor`'s alcove, where the car sets people down
/datum/outpost_police/proc/floors_landing_point(datum/outpost_floor/floor)
	var/list/turf/alcove = floor.alcove_turfs
	if(!length(alcove))
		return null
	return alcove[round((length(alcove) + 1) / 2)]

// =========================================================================
// SECTORS AND CAMERAS
// =========================================================================

/// Whether `floor` is this outpost's ground for the law now: public, or under warrant
/datum/outpost_police/proc/floors_in_reach(datum/outpost_floor/floor)
	return istype(floor) && floor.outpost == outpost && (floor.public_ground || floor.warrant_in_force)

/// The sector `where` is in when it is on one of this outpost's floors (the /datum/outpost_floor), else null.
/// A floor is a sector only while it is the outpost's ground and has an alcove to arrive in.
/datum/outpost_police/proc/floor_sector_of(turf/where)
	var/datum/outpost_floor/floor = outpost?.floor_at(get_turf(where))
	if(!floors_in_reach(floor) || !length(floor.alcove_turfs))
		return null
	return floor

/// The lift tiles of a floor sector: its alcove
/datum/outpost_police/proc/floor_lift_tiles(sector)
	var/datum/outpost_floor/floor = sector
	if(!floors_in_reach(floor))
		return list()
	return floor.alcove_turfs

/// Whether `where` is a lift tile of one of this outpost's floors that is a sector now
/datum/outpost_police/proc/floor_is_lift_tile(turf/where)
	for(var/datum/outpost_floor/floor in outpost?.floors)
		if(floors_in_reach(floor) && (where in floor.alcove_turfs))
			return TRUE
	return FALSE

/// The lift panels of floors that are public ground or under warrant: witnesses, like the lobby's (L25)
/datum/outpost_police/proc/floor_cameras()
	. = list()
	for(var/datum/outpost_floor/floor in outpost?.floors)
		if(floors_in_reach(floor) && !QDELETED(floor.panel))
			. += floor.panel

// =========================================================================
// CRIMES
// =========================================================================

/**
 * A crime at the lift (OUTPOST_CRIME_LIFT_TAMPER, OUTPOST_CRIME_ABDUCTION), seen at `where`: the panel that was
 * forced, or the alcove the car left from (spec 6.6, A17, L13). The lift reports after the car has moved, so the
 * offender may be upstairs by now; witnesses are judged at `where`, and only when `where` is this outpost's ground.
 * Counted at once when seen: the camera, an officer, a trader, a townsperson or a player not on the offender's crew.
 */
/datum/outpost_police/proc/floor_lift_report(mob/offender, crime, turf/where, mob/victim)
	SHOULD_NOT_SLEEP(TRUE)
	where = get_turf(where)
	if(QDELETED(src) || !outpost || !isliving(offender) || !offender.mind || !where)
		return
	// Private ground is nobody's business (L8)
	if(get_trader_outpost_for_turf(where) != outpost)
		return
	var/atom/witness = floors_witness_at(offender, where, victim)
	if(!witness)
		log_game("OUTPOST POLICE: [key_name(offender)] committed [crime] at [outpost] ([AREACOORD(where)]) and nobody saw.")
		return
	count_crime(offender, crime, victim)

/// Who or what sees `where` now for a crime by `offender`, or null. The victim is no witness to their own abduction.
/datum/outpost_police/proc/floors_witness_at(mob/living/offender, turf/where, mob/victim)
	for(var/atom/camera as anything in perception.cameras())
		if(!QDELETED(camera) && can_see(camera, where, OUTPOST_POLICE_NPC_WITNESS_RANGE))
			return camera
	for(var/mob/living/carbon/human/npc/ambient_npc/outpost/police/officer in officers)
		if(officer.stat == CONSCIOUS && can_see(officer, where, OUTPOST_POLICE_WITNESS_RANGE))
			return officer
	for(var/mob/living/carbon/human/npc/ambient_npc/outpost/trader/trader in outpost.traders)
		if(trader.stat == CONSCIOUS && can_see(trader, where, OUTPOST_POLICE_NPC_WITNESS_RANGE))
			return trader
	var/datum/ambient_place/outpost/place = SSambient_npcs.outposts?[outpost]
	if(place)
		for(var/mob/living/carbon/human/npc/ambient_npc/person in place.npcs)
			if(person.stat == CONSCIOUS && can_see(person, where, OUTPOST_POLICE_NPC_WITNESS_RANGE))
				return person
	var/datum/voidcrew_crew_record/own_crew = offender.mind?.get_reputation_crew()
	for(var/mob/living/player in GLOB.alive_player_list)
		if(player == offender || player == victim || player.stat != CONSCIOUS || perception.on_crew(player, own_crew))
			continue
		if(get_trader_outpost_for_turf(get_turf(player)) == outpost && can_see(player, where, OUTPOST_POLICE_WITNESS_RANGE))
			return player
	return null

/// Someone hit a floor's fitting: vandalism on public ground, by anyone but the floor's people (L39, spec 6.6).
/// It goes through the witness seam where the offender stands, as a blow to the outpost's own machinery does.
/datum/outpost_police/proc/floor_fitting_hit(mob/offender, atom/fitting, obj/item/tool)
	if(!outpost || !isliving(offender) || !offender.mind || QDELETED(fitting))
		return
	var/datum/outpost_floor/floor = outpost.floor_at(get_turf(fitting))
	if(!floor?.public_ground || floor.is_member(offender))
		return
	outpost.register_aggression(offender, OUTPOST_CRIME_VANDALISM, fitting, tool)

// =========================================================================
// THE MORGUE CREW, THE DOORS, THE VISITORS
// =========================================================================

/**
 * Whether the morgue crew may take `body`, which lies on a floor at `where` (spec 6.3). The caller has already made
 * the checks that hold anywhere (dead, loose, not held, not done) and that the floor is this outpost's ground now.
 * A body stays while an awake player of its own crew is beside it: for one of the floor's own, one of the floor's
 * people; for anyone else, a shipmate. The floor's crew standing over a visitor keeps nothing (A57).
 */
/datum/outpost_recovery/proc/floor_body_free(mob/living/body, turf/where)
	var/datum/outpost_floor/floor = get_outpost_floor_for_turf(where)
	if(!floor || floor.outpost != outpost)
		return FALSE
	var/one_of_theirs = floor.is_member(body)
	for(var/mob/living/someone in range(OUTPOST_RECOVERY_FREE_RANGE, where))
		if(someone == body || someone.stat != CONSCIOUS || !morgue_is_player(someone))
			continue
		if(one_of_theirs ? floor.is_member(someone) : floors_shipmates(body, someone))
			return FALSE
	return TRUE

/// Whether `first` and `second` are on a ship crew together
/datum/outpost_recovery/proc/floors_shipmates(mob/living/first, mob/living/second)
	if(!first.mind || !second.mind)
		return FALSE
	for(var/datum/team/voidcrew/team as anything in first.mind.ship_teams)
		if(team in second.mind.ship_teams)
			return TRUE
	return FALSE

/**
 * Whether `door` must open for `user` whatever its setting: an outpost police NPC of the floor's own outpost, on a
 * floor under warrant (L11). Never an access number or a card (A42). allowed() asks this for every airlock and
 * windoor in the game, so it returns on its first line for anyone else.
 */
/proc/police_floor_door_override(obj/machinery/door/door, mob/user)
	if(!istype(user, /mob/living/carbon/human/npc/ambient_npc/outpost/police))
		return FALSE
	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/officer = user
	if(officer.stat != CONSCIOUS || !officer.police || outpost_npc_played(officer))
		return FALSE
	var/datum/outpost_floor/floor = get_outpost_floor_for_turf(get_turf(door))
	if(!floor?.warrant_in_force)
		return FALSE
	return officer.police == floor.outpost?.police

/// Everyone on the floor, alive or dead, who is a player or was one and is not one of its own people. Guests and
/// hired hands are visitors here (L38). The console asks this, so a change it shows wakes the police.
/datum/outpost_floor/proc/visitors_upstairs()
	. = list()
	for(var/mob/living/person as anything in police_people())
		// NPC customers and patrons are no visitors: they would keep a narrowed floor public (P11)
		if(istype(person, /mob/living/carbon/human/npc/ambient_npc) && !person.ckey)
			continue
		if(outpost_npc_played(person) && !is_member(person))
			. += person
	var/datum/outpost_police/police = outpost?.police
	if(police && length(bounds) >= 5 && (entry_policy == OUTPOST_FLOOR_ENTRY_OPEN) != public_ground)
		police.wake()

/// Every living mob on the floor, in anything or not
/datum/outpost_floor/proc/police_people()
	. = list()
	if(length(bounds) < 5)
		return
	var/floor_z = bounds[5]
	for(var/mob/living/person in GLOB.mob_living_list)
		var/turf/where = get_turf(person)
		if(where?.z == floor_z && contains_turf(where))
			. += person
