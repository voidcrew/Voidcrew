/**
 * # Stealth guards: noise
 *
 * stealth_noise() is the only way a guard hears anything but footsteps (those its own scan listens for,
 * stealth_hearing.dm). The sources are tg's own actions (stealth_noise_sources.dm).
 *
 * No sound ever gives a guard a target. Hearing turns a guard, moves it, makes it search and makes it wary;
 * only sight and touch set BB_BASIC_MOB_CURRENT_TARGET.
 *
 * A noise reaches the stealth groups of its own level and map region. Walls and closed doors on the straight
 * line to each guard eat reach (stealth_muffled_dist()). What the hearers do is decided for the group as a
 * whole (dispatch_noise()): a door makes them glance; a small noise sends one guard to look, the next one at
 * the same spot two, the third everyone; gunfire, blasts and screams send the nearest few running while
 * sentries hold their posts. A guard that went to look and isn't back in STEALTH_CHECKIN_TIME is missed by
 * the ones who watched it go.
 *
 * Cost: with no group alive, one length() check. With no living player on the level, or in airless space,
 * the noise is dropped before any guard is looked at. The same kind of noise within STEALTH_NOISE_COALESCE
 * and STEALTH_NOISE_COALESCE_RANGE of the last is dropped before any per-guard work. Listeners come from the
 * group's roster, never from view() or hearers(). Nothing here runs on a timer: lures, alarms and checks
 * are small lists of world.time stamps on the group, pruned when read.
 */

/// A guard that went to look at a noise, and the ones who know it went.
/datum/stealth_check
	/// Weakref to the guard that went
	var/datum/weakref/who
	/// What its friends call it, or null if it has no name of its own
	var/name
	/// Where the noise was
	var/turf/where
	/// world.time it is missed
	var/due = 0
	/// Weakrefs to the guards that saw or heard it go
	var/list/datum/weakref/waiters = list()

/datum/stealth_group
	/// Noise kind => list(world.time, turf) of the last one its guards heard
	var/list/noise_stamps = list()
	/// list(turf, world.time) for each small noise it sent someone to
	var/list/lures = list()
	/// list(world.time, weight) for each alarm it answered (a lure counts half)
	var/list/alarms = list()
	/// Guards out looking at a noise
	var/list/datum/stealth_check/checks = list()
	/// world.time the checks are next looked over
	var/next_overdue_check = 0
	/// world.time the next radio alarm may go out
	var/next_radio_alarm = 0
	/// Admin noise view only: guard => what it made of the noise being dealt with, else null
	var/list/noise_notes
	/// Reach of the noise being dealt with
	var/noise_reach = 0

/// list(reach, level, flags) for a STEALTH_NOISE_* kind, or null.
/proc/stealth_noise_profile(kind)
	var/static/list/profiles
	if(isnull(profiles))
		profiles = list(
			STEALTH_NOISE_GUN_QUIET = list(STEALTH_NOISE_RANGE_GUN_QUIET, STEALTH_HEAR_INVESTIGATE, STEALTH_NOISE_LOS_ONLY),
			STEALTH_NOISE_GUN_PISTOL = list(STEALTH_NOISE_RANGE_GUN_PISTOL, STEALTH_HEAR_ALARM, STEALTH_NOISE_LOUD),
			STEALTH_NOISE_GUN_SMG = list(STEALTH_NOISE_RANGE_GUN_SMG, STEALTH_HEAR_ALARM, STEALTH_NOISE_LOUD),
			STEALTH_NOISE_GUN_LONG = list(STEALTH_NOISE_RANGE_GUN_LONG, STEALTH_HEAR_ALARM, STEALTH_NOISE_LOUD),
			STEALTH_NOISE_IMPACT = list(STEALTH_NOISE_RANGE_IMPACT, STEALTH_HEAR_INVESTIGATE, NONE),
			STEALTH_NOISE_BLAST = list(STEALTH_NOISE_RANGE_BLAST, STEALTH_HEAR_ALARM, STEALTH_NOISE_LOUD),
			STEALTH_NOISE_GLASS = list(STEALTH_NOISE_RANGE_GLASS, STEALTH_HEAR_INVESTIGATE, NONE),
			STEALTH_NOISE_THROWN = list(STEALTH_NOISE_RANGE_THROWN_SMALL, STEALTH_HEAR_INVESTIGATE, NONE),
			STEALTH_NOISE_KNOCK = list(STEALTH_NOISE_RANGE_KNOCK, STEALTH_HEAR_INVESTIGATE, NONE),
			STEALTH_NOISE_BASH = list(STEALTH_NOISE_RANGE_BASH, STEALTH_HEAR_INVESTIGATE, NONE),
			STEALTH_NOISE_DOOR = list(STEALTH_NOISE_RANGE_DOOR, STEALTH_HEAR_GLANCE, NONE),
			STEALTH_NOISE_THUD = list(STEALTH_NOISE_RANGE_THUD, STEALTH_HEAR_INVESTIGATE, STEALTH_NOISE_ALLIES_COUNT),
			STEALTH_NOISE_VOICE = list(STEALTH_NOISE_RANGE_VOICE, STEALTH_HEAR_INVESTIGATE, NONE),
			STEALTH_NOISE_SCREAM = list(STEALTH_NOISE_RANGE_SCREAM, STEALTH_HEAR_ALARM, STEALTH_NOISE_LOUD | STEALTH_NOISE_ALLIES_COUNT),
			STEALTH_NOISE_SHOUT = list(STEALTH_NOISE_RANGE_SHOUT, STEALTH_HEAR_SHOUT, STEALTH_NOISE_LOUD | STEALTH_NOISE_GROUP_ONLY),
			STEALTH_NOISE_CRUNCH = list(STEALTH_NOISE_RANGE_CRUNCH, STEALTH_HEAR_INVESTIGATE, NONE),
		)
	return profiles[kind]

/// Whether `kind` is a gunshot loud enough to be a call for help when one of their own fires it.
/proc/stealth_noise_is_gunfire(kind)
	return kind == STEALTH_NOISE_GUN_PISTOL || kind == STEALTH_NOISE_GUN_SMG || kind == STEALTH_NOISE_GUN_LONG

/**
 * Something made a noise guards can hear. Does nothing unless a stealth group has awake members on that level.
 * source: where it happened (any atom; its turf is used). kind: STEALTH_NOISE_*. reach: tiles in open air, or
 * null for the kind's default. actor: the living mob that made it, if known. only: one group to tell, or null
 * for every group in earshot.
 * Returns the number of guards that heard it (tests and the admin view).
 */
/proc/stealth_noise(atom/source, kind, reach = null, mob/living/actor = null, datum/stealth_group/only = null)
	if(!length(GLOB.stealth_groups))
		return 0
	var/turf/where = get_turf(source)
	var/list/profile = stealth_noise_profile(kind)
	if(isnull(where) || isnull(profile))
		return 0
	// Nobody to play for: guards sleep with their level.
	if(where.z > length(SSmobs.clients_by_zlevel) || !length(SSmobs.clients_by_zlevel[where.z]))
		return 0
	if(isnull(reach))
		reach = profile[STEALTH_PROFILE_REACH]
	if(reach <= 0)
		return 0
	// A door nobody is named for may be one of their own going through.
	var/door = isnull(actor) && istype(source, /obj/machinery/door)
	var/aired = FALSE
	. = 0
	for(var/datum/stealth_group/group as anything in (only ? list(only) : GLOB.stealth_groups.Copy()))
		if(QDELETED(group) || group.home?.z != where.z || !group.region_matches(where))
			continue
		if(!aired)
			aired = TRUE
			if(!stealth_noise_carries(where, actor))
				return 0
		. += group.hear(where, kind, reach, profile[STEALTH_PROFILE_LEVEL], profile[STEALTH_PROFILE_FLAGS], actor, door)

/// Whether there is air at `where` to carry a sound, as for players (playsound_local scales by pressure). A
/// noise on a wall or a window tile is judged where its maker stands.
/proc/stealth_noise_carries(turf/where, mob/living/actor)
	var/turf/air_turf = where
	if(isclosedturf(air_turf))
		air_turf = get_turf(actor)
		if(isnull(air_turf) || isclosedturf(air_turf))
			return TRUE
	var/datum/gas_mixture/air = air_turf.return_air()
	return !isnull(air) && air.return_pressure() >= SOUND_MINIMUM_PRESSURE

/**
 * How far off a sound from `origin` seems at `ear`: the distance plus STEALTH_MUFFLE_WALL for each wall and
 * STEALTH_MUFFLE_DOOR for each closed solid door (or anything else you can't see through) on the straight
 * line between them. Glass costs nothing. Loud sounds lose half as much. INFINITY when unheard: more than
 * STEALTH_MUFFLE_MAX_BLOCKERS in the way, or any at all for a STEALTH_NOISE_LOS_ONLY sound. The two end
 * turfs are never counted, so a knock on a wall is heard on both sides of it.
 */
/proc/stealth_muffled_dist(turf/origin, turf/ear, flags = NONE)
	if(isnull(origin) || isnull(ear) || origin.z != ear.z)
		return INFINITY
	var/dist = get_dist(origin, ear)
	if(dist <= 1)
		return dist
	var/list/line = get_line(origin, ear)
	var/blockers = 0
	var/penalty = 0
	for(var/index in 2 to length(line) - 1)
		var/turf/between = line[index]
		var/cost = 0
		if(isclosedturf(between))
			cost = STEALTH_MUFFLE_WALL
		else if(between.directional_opacity == ALL_CARDINALS)
			cost = STEALTH_MUFFLE_DOOR
		if(!cost)
			continue
		if(flags & STEALTH_NOISE_LOS_ONLY)
			return INFINITY
		blockers++
		if(blockers > STEALTH_MUFFLE_MAX_BLOCKERS)
			return INFINITY
		penalty += cost
	if(flags & STEALTH_NOISE_LOUD)
		penalty *= STEALTH_MUFFLE_LOUD_MULT
	return dist + penalty

/// Where a guard standing on `listener` goes to look at a noise at `where`: the spot, or, when the spot is a
/// wall or a window tile, the open tile beside it nearest the guard (its own side of the wall).
/proc/stealth_hear_spot(turf/where, turf/listener)
	if(isnull(where))
		return null
	if(isopenturf(where) && !where.is_blocked_turf(exclude_mobs = TRUE))
		return where
	var/turf/best
	var/best_dist = INFINITY
	for(var/turf/open/near in RANGE_TURFS(1, where))
		if(near == where || near.is_blocked_turf(exclude_mobs = TRUE))
			continue
		// Straight-line distance: of two tiles as many steps away, the one more directly on its side.
		var/dist = listener ? get_dist_euclidean(near, listener) : 0
		if(dist < best_dist)
			best = near
			best_dist = dist
	return best || where

// ===== The group's side =====

/// Its guards hear a noise at `where`, those that can. Returns how many did.
/datum/stealth_group/proc/hear(turf/where, kind, reach, level, flags, mob/living/actor, door = FALSE)
	var/list/views = length(GLOB.stealth_sight_overlays) ? stealth_noise_views(where.z) : null
	// The same noise again (full auto, a burst, pellets): one event, not ten.
	var/list/stamp = noise_stamps[kind]
	if(stamp && world.time - stamp[1] < STEALTH_NOISE_COALESCE && get_dist(stamp[2], where) <= STEALTH_NOISE_COALESCE_RANGE)
		for(var/datum/stealth_noise_view/view as anything in views)
			view.show(where, kind, reach, null, TRUE)
		return 0
	var/list/guards = living_members()
	if(!length(guards))
		return 0
	if((flags & STEALTH_NOISE_GROUP_ONLY) && !(actor in guards))
		return 0
	if(door && member_beside(where, guards))
		return 0
	var/mob/living/any_guard = guards[1]
	var/ally = !isnull(actor) && any_guard.faction_check_atom(actor)
	var/gunfire = stealth_noise_is_gunfire(kind)
	// One of their own making an everyday noise.
	if(ally && !gunfire && !(flags & (STEALTH_NOISE_ALLIES_COUNT | STEALTH_NOISE_GROUP_ONLY)))
		return 0
	// An ally's gunfire means an ally is in a fight: it is a call for help from where they stand.
	if(ally && gunfire)
		level = STEALTH_HEAR_SHOUT
	noise_notes = views ? list() : null
	noise_reach = reach
	// list(guard, muffled distance), nearest first
	var/list/hearers = list()
	for(var/mob/living/carbon/human/npc/guard as anything in guards)
		var/datum/ai_controller/basic_controller/human_npc/stealth/guard_ai = guard.ai_controller
		if(guard == actor || !istype(guard_ai))
			continue
		var/turf/guard_turf = get_turf(guard)
		if(guard_turf?.z != where.z)
			continue
		// Its ear (decision 38): quiet noises carry further to a sharp guard, less far to a sloppy one.
		var/guard_reach = reach
		if(!gunfire && !(flags & STEALTH_NOISE_LOUD) && kind != STEALTH_NOISE_GUN_QUIET)
			guard_reach = round(reach * guard_ai.stealth_skill().hearing_mult, 1)
		var/dist = get_dist(guard_turf, where)
		if(dist > guard_reach)
			continue
		if(guard_ai.ai_status == AI_STATUS_OFF || guard.client || guard.stat != CONSCIOUS || guard_ai.stealth_captive() || guard_ai.blackboard_key_exists(BB_HUMAN_NPC_EXIT))
			note(guard, "busy")
			continue
		if(!guard.can_hear())
			note(guard, "deaf")
			continue
		// Fighting: only an alarm made by someone else tells it anything, and that before the line walk.
		if(guard_ai.stealth_state() == STEALTH_ALERT && (level != STEALTH_HEAR_ALARM || !isliving(actor)))
			note(guard, "busy")
			continue
		var/muffled = stealth_muffled_dist(where, guard_turf, flags)
		if(muffled > guard_reach)
			note(guard, muffled == INFINITY ? "muffled" : "muffled [muffled]/[guard_reach]")
			continue
		var/index = 1
		while(index <= length(hearers) && hearers[index][2] <= muffled)
			index++
		hearers.Insert(index, null)
		hearers[index] = list(guard, muffled)
		guard_ai.last_heard = list(kind, world.time)
		note(guard, "heard [muffled]/[guard_reach]")
	if(length(hearers))
		noise_stamps[kind] = list(world.time, where)
		// Far off, they misjudge the spot: all of them by the same error, so they end up in one place.
		var/turf/spot = where
		var/list/nearest = hearers[1]
		var/fuzz = min(STEALTH_NOISE_FUZZ_MAX, round((nearest[2] - STEALTH_NOISE_EXACT_RANGE) / STEALTH_NOISE_FUZZ_STEP, 1))
		if(fuzz > 0 && level != STEALTH_HEAR_SHOUT)
			var/turf/guess = locate(clamp(where.x + rand(-fuzz, fuzz), 1, world.maxx), clamp(where.y + rand(-fuzz, fuzz), 1, world.maxy), where.z)
			guess = stealth_open_near(guess, 2)
			if(guess && region_matches(guess))
				spot = guess
		dispatch_noise(hearers, where, kind, level, actor, spot)
	for(var/datum/stealth_noise_view/view as anything in views)
		view.show(where, kind, reach, noise_notes, FALSE)
	noise_notes = null
	return length(hearers)

/// Admin noise view: what `guard` made of the noise being dealt with.
/datum/stealth_group/proc/note(mob/living/guard, text, append = FALSE)
	if(isnull(noise_notes))
		return
	noise_notes[guard] = append ? "[noise_notes[guard]] -> [text]" : text

/// Whether a conscious guard of the group stands within a tile of `where`.
/datum/stealth_group/proc/member_beside(turf/where, list/guards)
	for(var/mob/living/guard as anything in guards)
		if(guard.stat == CONSCIOUS && guard.z == where.z && get_dist(guard, where) <= 1)
			return TRUE
	return FALSE

/// How many small noises it sent someone to within STEALTH_LURE_RADIUS of `where` and STEALTH_LURE_MEMORY.
/datum/stealth_group/proc/lure_count(turf/where)
	. = 0
	for(var/list/lure as anything in lures)
		if(world.time - lure[2] > STEALTH_LURE_MEMORY)
			lures -= list(lure)
			continue
		if(get_dist(lure[1], where) <= STEALTH_LURE_RADIUS)
			.++

/// How many alarms it answered within STEALTH_ALARM_MEMORY (a lure counts half).
/datum/stealth_group/proc/alarm_count()
	. = 0
	for(var/list/alarm as anything in alarms)
		if(world.time - alarm[1] > STEALTH_ALARM_MEMORY)
			alarms -= list(alarm)
			continue
		. += alarm[2]

/// Forgets every noise (admin tools).
/datum/stealth_group/proc/forget_noises()
	noise_stamps = list()
	lures = list()
	alarms = list()
	checks = list()
	next_radio_alarm = 0
	door_guard_used = list()
	door_cues = list()

/// Moves every noise stamp back by `time`, as if that long had passed (unit tests, admin tools).
/datum/stealth_group/proc/rewind(time)
	for(var/kind in noise_stamps)
		var/list/stamp = noise_stamps[kind]
		stamp[1] -= time
	for(var/list/lure as anything in lures)
		lure[2] -= time
	for(var/list/alarm as anything in alarms)
		alarm[1] -= time
	for(var/datum/stealth_check/check as anything in checks)
		check.due -= time
	next_overdue_check -= time
	next_radio_alarm -= time
	for(var/key in door_guard_used)
		door_guard_used[key] -= time
	for(var/key in door_cues)
		var/list/stamps = door_cues[key]
		for(var/index in 1 to length(stamps))
			stamps[index] -= time

/**
 * What the guards that heard a noise do, decided for the group. `hearers` is list(guard, muffled distance),
 * nearest first. `where` is where it really was (lures are counted there); `spot` is where they think it was.
 */
/datum/stealth_group/proc/dispatch_noise(list/hearers, turf/where, kind, level, mob/living/actor, turf/spot)
	spot ||= where
	switch(level)
		if(STEALTH_HEAR_GLANCE)
			for(var/list/hearer as anything in hearers)
				var/mob/living/guard = hearer[1]
				var/datum/ai_controller/basic_controller/human_npc/stealth/guard_ai = guard.ai_controller
				if(guard_ai.stealth_state() == STEALTH_UNAWARE)
					guard_ai.stealth_glance(spot)
					note(guard, "glance", TRUE)
		if(STEALTH_HEAR_INVESTIGATE)
			dispatch_investigate(hearers, where, spot)
		if(STEALTH_HEAR_ALARM)
			dispatch_alarm(hearers, where, spot, kind, actor)
		if(STEALTH_HEAR_SHOUT)
			dispatch_shout(hearers, spot)

/// A small noise: one guard goes to look, the rest glance. The second time at one spot two go; from the third
/// everyone who hears it searches there, and they call it in.
/datum/stealth_group/proc/dispatch_investigate(list/hearers, turf/where, turf/spot)
	var/earlier = lure_count(where)
	lures += list(list(where, world.time))
	alarms += list(list(world.time, 0.5))
	if(earlier >= 2)
		var/shouted = FALSE
		for(var/list/hearer as anything in hearers)
			var/mob/living/carbon/human/npc/guard = hearer[1]
			var/datum/ai_controller/basic_controller/human_npc/stealth/guard_ai = guard.ai_controller
			// A sentry still doesn't leave its door for something far off.
			if(isnull(guard_ai.route_id) && get_dist(guard, spot) > STEALTH_SENTRY_INVESTIGATE_RANGE)
				guard_ai.stealth_hold(spot)
				note(guard, "holds", TRUE)
			else if(guard_ai.stealth_respond(spot))
				note(guard, "searches", TRUE)
				if(!shouted)
					shouted = TRUE
					guard_ai.stealth_bark(STEALTH_BARK_HELP)
					guard_ai.stealth_shout()
			if(guard.stealth_radio)
				guard_ai.stealth_start_call(STEALTH_CALL_ALARM, spot)
		return
	var/wanted = earlier + 1
	var/list/went = list()
	var/list/stayed = list()
	for(var/list/hearer as anything in hearers)
		var/mob/living/carbon/human/npc/guard = hearer[1]
		var/datum/ai_controller/basic_controller/human_npc/stealth/guard_ai = guard.ai_controller
		var/sentry_too_far = isnull(guard_ai.route_id) && get_dist(guard, spot) > STEALTH_SENTRY_INVESTIGATE_RANGE
		if(length(went) < wanted && !sentry_too_far && guard_ai.stealth_can_investigate())
			guard_ai.stealth_go_heard(spot, earlier >= 1 && !length(went))
			went += guard
			note(guard, "goes", TRUE)
			if(guard.stealth_radio)
				guard_ai.stealth_start_call(STEALTH_CALL_REPORT, spot)
			continue
		stayed += WEAKREF(guard)
		switch(guard_ai.stealth_state())
			if(STEALTH_UNAWARE)
				guard_ai.stealth_glance(spot)
				note(guard, "glance", TRUE)
			if(STEALTH_SEARCHING)
				if(guard_ai.stealth_respond(spot))
					note(guard, "searches", TRUE)
	for(var/mob/living/carbon/human/npc/guard as anything in went)
		var/datum/stealth_check/check = new
		check.who = WEAKREF(guard)
		check.name = stealth_first_name(guard)
		check.where = where
		check.due = world.time + STEALTH_CHECKIN_TIME
		check.waiters = stayed.Copy()
		checks += check

/// Gunfire, a blast, a scream: the nearest few that aren't sentries run to it and search; every other hearer
/// holds where it is, wary. After two alarms in memory fewer go: it may be a draw.
/datum/stealth_group/proc/dispatch_alarm(list/hearers, turf/where, turf/spot, kind, mob/living/actor)
	var/cap = alarm_count() >= 2 ? STEALTH_ALARM_RESPONDERS_LATER : STEALTH_ALARM_RESPONDERS
	alarms += list(list(world.time, 1))
	var/responders = 0
	for(var/list/hearer as anything in hearers)
		var/mob/living/carbon/human/npc/guard = hearer[1]
		var/datum/ai_controller/basic_controller/human_npc/stealth/guard_ai = guard.ai_controller
		if(guard_ai.stealth_state() == STEALTH_ALERT)
			// Fighting someone else: it now knows there is another one about (never a target from sound).
			var/atom/target = guard_ai.blackboard[BB_BASIC_MOB_CURRENT_TARGET]
			if(isliving(actor) && actor != target && bounty_ai_target_for(actor) != target && !guard.faction_check_atom(actor))
				guard_ai.stealth_remember(actor)
				note(guard, "notes", TRUE)
			continue
		if(!isnull(guard_ai.route_id) && responders < cap)
			if(guard_ai.stealth_respond(spot))
				if(!responders)
					guard_ai.stealth_bark(stealth_noise_is_gunfire(kind) ? STEALTH_BARK_GUNFIRE : STEALTH_BARK_HEARD, spot)
				note(guard, "goes", TRUE)
			responders++
		else
			guard_ai.stealth_hold(spot)
			note(guard, "holds", TRUE)
		if(guard.stealth_radio)
			guard_ai.stealth_start_call(STEALTH_CALL_ALARM, spot)

/// A friend calling for help from `spot`: whoever hears it and isn't a sentry runs to them. They heard a
/// friend, they saw nobody, so they search where the friend stood.
/datum/stealth_group/proc/dispatch_shout(list/hearers, turf/spot)
	for(var/list/hearer as anything in hearers)
		var/mob/living/carbon/human/npc/guard = hearer[1]
		var/datum/ai_controller/basic_controller/human_npc/stealth/guard_ai = guard.ai_controller
		if(guard_ai.stealth_state() == STEALTH_ALERT)
			continue
		if(isnull(guard_ai.route_id))
			guard_ai.stealth_hold(spot)
			note(guard, "holds", TRUE)
		else if(guard_ai.stealth_respond(spot))
			note(guard, "goes", TRUE)
		if(guard.stealth_radio)
			guard_ai.stealth_start_call(STEALTH_CALL_ALARM, spot)

/**
 * The guard who never came back (abuse P6). Run from each member's scan, at most once per
 * STEALTH_SCAN_INTERVAL. A guard that went to look and is back on its round, or found someone, closes its
 * check. One that is past due and gone, down, cuffed or still out is missed: the nearest two who know it
 * went search where it went, and the next noise there brings everyone.
 */
/datum/stealth_group/proc/check_overdue()
	if(world.time < next_overdue_check || !length(checks))
		return
	next_overdue_check = world.time + STEALTH_SCAN_INTERVAL
	for(var/datum/stealth_check/check as anything in checks.Copy())
		var/mob/living/carbon/human/npc/gone = check.who?.resolve()
		var/datum/ai_controller/basic_controller/human_npc/stealth/gone_ai = gone?.ai_controller
		var/down = QDELETED(gone) || !istype(gone_ai) || gone.stat != CONSCIOUS || HAS_TRAIT(gone, TRAIT_RESTRAINED)
		// Already found and called out as a body: nobody asks where it got to (decision 32).
		if(down && !QDELETED(gone) && (REF(gone) in reported_bodies))
			checks -= check
			continue
		if(!down)
			var/state = gone_ai.stealth_state()
			if(state == STEALTH_UNAWARE || state == STEALTH_ALERT)
				checks -= check
				continue
		if(world.time < check.due)
			continue
		checks -= check
		// Who misses it: conscious, free, not fighting. Nearest to the spot first.
		var/list/missers = list()
		for(var/datum/weakref/waiter_ref as anything in check.waiters)
			var/mob/living/carbon/human/npc/waiter = waiter_ref.resolve()
			var/datum/ai_controller/basic_controller/human_npc/stealth/waiter_ai = waiter?.ai_controller
			if(QDELETED(waiter) || waiter == gone || !istype(waiter_ai) || waiter.stat != CONSCIOUS || waiter.client)
				continue
			if(waiter_ai.ai_status == AI_STATUS_OFF || waiter_ai.stealth_captive() || waiter_ai.stealth_state() == STEALTH_ALERT)
				continue
			var/dist = get_dist(waiter, check.where)
			var/index = 1
			while(index <= length(missers) && get_dist(missers[index], check.where) <= dist)
				index++
			missers.Insert(index, waiter)
		if(!length(missers))
			continue
		// The next noise there brings everyone.
		lures += list(list(check.where, world.time), list(check.where, world.time))
		var/sent = 0
		for(var/mob/living/carbon/human/npc/waiter as anything in missers)
			var/datum/ai_controller/basic_controller/human_npc/stealth/waiter_ai = waiter.ai_controller
			if(sent < 2 && (!isnull(waiter_ai.route_id) || get_dist(waiter, check.where) <= STEALTH_SENTRY_INVESTIGATE_RANGE))
				if(waiter_ai.stealth_respond(check.where))
					sent++
					waiter_ai.stealth_bark(STEALTH_BARK_MISSING, check.where, check.name)
			if(waiter.stealth_radio)
				waiter_ai.stealth_start_call(STEALTH_CALL_MISSING, check.where, check.name)

/// A blast anywhere: its own guards hear it if it is near enough. Registered per group, not per guard.
/datum/stealth_group/proc/on_explosion(datum/source, turf/epicenter)
	SIGNAL_HANDLER
	if(isnull(epicenter) || epicenter.z != home?.z)
		return
	INVOKE_ASYNC(GLOBAL_PROC, GLOBAL_PROC_REF(stealth_noise), epicenter, STEALTH_NOISE_BLAST, null, null, src)

/// What its friends call `guard`: the first word of its name, or null when it has only its type's name
/// ("Scav Guard"). An NPC's name, never player text.
/proc/stealth_first_name(mob/living/carbon/human/npc/guard)
	var/full = guard.real_name
	if(!istext(full) || !length(full) || full == guard.npc_name || full == initial(guard.name))
		return null
	var/space = findtext(full, " ")
	return space ? copytext(full, 1, space) : full
