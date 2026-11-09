/**
 * # Stealth guards: awareness
 *
 * A human NPC type opts in with `ai_controller = /datum/ai_controller/basic_controller/human_npc/stealth`.
 * Nothing changes for any other human NPC (owner decision 4).
 *
 * The guard is unaware, suspicious, alert or searching (BB_STEALTH_STATE). That is AI state only: the
 * body takes damage, wounds, stuns and crit through tg exactly as before, and players never get a state.
 *
 * - Unaware: walks its patrol (stealth_patrol.dm) or stands its post.
 * - Suspicious: saw something. Turns to it, says so, stares a moment, walks over and looks around, then
 *   gives up and goes back to its route.
 * - Alert: has a target and fights as every human NPC does. It keeps the target all round with tg's
 *   can_attack() (no cone, no darkness); out of sight for STEALTH_LOSE_TARGET_TIME, it searches.
 * - Searching: runs to where it last saw someone and sweeps the spots round it, then gives up.
 *
 * Wary (BB_STEALTH_WARY) is set by any alert, search, hit or surrender: a wider cone and quicker notice
 * (abuse review P4). It fades after STEALTH_WARY_TIME with nothing new: every notice gain, hit, touch and
 * scan spent alert or searching starts that clock again (owner decision 23).
 *
 * Putting its target down (dead or in crit) with nobody else noticed ends the alarm: a short line, a look
 * round where it stands for STEALTH_CALM_LOOK_TIME, then back to its route (decision 23).
 *
 * Every attack or touch gets a reaction, even from out of sight (P3): alert on the attacker if it can see
 * them, otherwise a search at their turf. Detection is a once-a-second scan owned by this controller, never
 * tg's movement-triggered target field (P1). Nothing here runs while the AI is off (no player on the
 * level); timers are world.time stamps, so a guard that wakes after its search ran out steps straight
 * back to unaware and stays wary (T1).
 */
/datum/ai_controller/basic_controller/human_npc/stealth
	blackboard = list(
		BB_TARGETING_STRATEGY = /datum/targeting_strategy/basic/human_npc,
		BB_TARGET_MINIMUM_STAT = HARD_CRIT,
		BB_AGGRO_RANGE = HUMAN_NPC_SIGHT_RANGE,
		BB_HUMAN_NPC_SHOT_DELAY = 3 SECONDS,
		BB_HUMAN_NPC_FIRE_RANGE = 7,
		BB_HUMAN_NPC_KEEP_AWAY = 2,
		BB_STEALTH_STATE = STEALTH_UNAWARE,
	)
	// The patrol subtree decides what an unaware guard does; no random walk.
	idle_behavior = null
	ai_movement = /datum/ai_movement/jps/stealth
	planning_subtrees = list(
		/datum/ai_planning_subtree/human_npc_soft_crit,
		/datum/ai_planning_subtree/escape_captivity,
		/datum/ai_planning_subtree/human_npc_walk_out,
		/datum/ai_planning_subtree/human_npc_surrender,
		/datum/ai_planning_subtree/stealth_perception,
		/datum/ai_planning_subtree/stealth_react,
		/datum/ai_planning_subtree/human_npc_arm,
		/datum/ai_planning_subtree/human_npc_shoot,
		/datum/ai_planning_subtree/human_npc_melee,
		/datum/ai_planning_subtree/stealth_patrol,
	)
	/// Its patrol group (stealth_patrol.dm)
	var/datum/stealth_group/group
	/// Whether it has joined a group and claimed a route
	var/stealth_ready = FALSE
	/// The route id it walks, or null for a sentry
	var/route_id
	/// Index of the stop it is heading for or standing at
	var/route_index = 1
	/// +1 or -1 along the route
	var/route_step = 1
	/// The way a sentry faces at its post
	var/sentry_dir = SOUTH
	/// Stop index => failed tries to reach it
	var/list/stop_fails = list()
	/// Stop index => world.time it may be tried again
	var/list/stop_skip_until = list()
	/// world.time it leaves the stop it stands at
	var/wait_until = 0
	/// Whether it has done its arrival at the current stop
	var/at_stop = FALSE
	/// Where its current stealth walk goes
	var/turf/goto_turf
	/// What that walk is for (STEALTH_GOTO_*)
	var/goto_purpose
	/// "arrived" or "failed" once the walk is over, else null
	var/goto_result
	/// Set while it drops its own walk, so a dropped walk doesn't count as a failure
	var/dropping_walk = FALSE
	/// world.time its current walk began
	var/goto_started = 0
	/// Set when a walk ran out of time
	var/goto_timed_out = FALSE
	/// world.time its current look round ends
	var/look_until = 0
	/// The way it faces while standing (a stop's facing, a sentry's post, where it saw something)
	var/stand_dir = SOUTH
	/// world.time it may next turn its head while standing
	var/next_turn = 0
	/// Suspicious: where it walks to look
	var/turf/investigate_turf
	/// Suspicious: whether it has walked over and looked
	var/investigated = FALSE
	/// world.time of the last notice gain on its focus (suspicion holds STEALTH_SUSPICIOUS_TIMEOUT after it)
	var/last_gain = 0
	/// Searching: the spot it searches round
	var/turf/search_center
	/// Searching: the spots still to check
	var/list/search_queue = list()
	/// Searching: whether it is looking round at the spot it reached
	var/search_looking = FALSE
	/// world.time of its next search line
	var/next_search_bark = 0
	/// Alert: world.time it first failed to see its target in this stretch, or 0
	var/lost_since = 0
	/// world.time of its next look for fallen friends
	var/next_body_scan = 0
	/// Bark kind => world.time it may say that kind again
	var/list/bark_ready_at = list()
	/// Its stat at the last change, to tell recovery from crit
	var/last_stat = CONSCIOUS
	/// Admins watching its sight overlay (stealth_admin.dm)
	var/list/datum/stealth_sight_overlay/watchers
	/// REF(mob) => list(notice, turf last scan, world.time last perceived). Not a blackboard key: the
	/// blackboard's qdel sweep indexes every nested list by its values, and these hold plain numbers.
	var/list/notice_map
	/// world.time wary was last set or refreshed
	var/wary_at = 0
	/// Searching after putting its target down: world.time it calms down, or 0
	var/calm_until = 0

/datum/ai_controller/basic_controller/human_npc/stealth/TryPossessPawn(atom/new_pawn)
	. = ..()
	if(. & AI_CONTROLLER_INCOMPATIBLE)
		return
	notice_map = list()
	blackboard[BB_STEALTH_BODIES_SEEN] = list()
	blackboard[BB_STEALTH_STATE_SINCE] = world.time
	RegisterSignal(new_pawn, COMSIG_LIVING_GET_PULLED, PROC_REF(on_pulled))
	RegisterSignal(new_pawn, COMSIG_ATOM_BUMPED, PROC_REF(on_bumped))
	RegisterSignal(new_pawn, COMSIG_CARBON_HELP_ACT, PROC_REF(on_helped))
	RegisterSignal(new_pawn, COMSIG_PROJECTILE_PREHIT, PROC_REF(on_projectile_prehit))
	RegisterSignal(new_pawn, COMSIG_LIVING_STATUS_REMOVED, PROC_REF(on_status_removed))
	RegisterSignal(new_pawn, COMSIG_AI_BLACKBOARD_KEY_SET(BB_BASIC_MOB_CURRENT_TARGET), PROC_REF(on_target_set))

/datum/ai_controller/basic_controller/human_npc/stealth/UnpossessPawn(destroy)
	if(pawn)
		UnregisterSignal(pawn, list(
			COMSIG_LIVING_GET_PULLED,
			COMSIG_ATOM_BUMPED,
			COMSIG_CARBON_HELP_ACT,
			COMSIG_PROJECTILE_PREHIT,
			COMSIG_LIVING_STATUS_REMOVED,
			COMSIG_AI_BLACKBOARD_KEY_SET(BB_BASIC_MOB_CURRENT_TARGET),
		))
	group?.remove_member(pawn)
	group = null
	for(var/datum/stealth_sight_overlay/overlay as anything in watchers?.Copy())
		qdel(overlay)
	watchers = null
	goto_turf = null
	investigate_turf = null
	search_center = null
	search_queue = null
	return ..()

// ===== State =====

/datum/ai_controller/basic_controller/human_npc/stealth/proc/stealth_state()
	return blackboard[BB_STEALTH_STATE]

/// Changes state, stamping the time, and drops whatever walk it was on.
/datum/ai_controller/basic_controller/human_npc/stealth/proc/stealth_set_state(new_state)
	var/old_state = blackboard[BB_STEALTH_STATE]
	if(old_state == STEALTH_UNAWARE && new_state != STEALTH_UNAWARE)
		blackboard[BB_STEALTH_UNAWARE_LOST_AT] = world.time
	blackboard[BB_STEALTH_STATE] = new_state
	blackboard[BB_STEALTH_STATE_SINCE] = world.time
	look_until = 0
	lost_since = 0
	calm_until = 0
	if(new_state == STEALTH_ALERT || new_state == STEALTH_SEARCHING)
		stealth_set_wary()
	stealth_drop_walk()
	var/run = (new_state == STEALTH_ALERT || new_state == STEALTH_SEARCHING)
	stealth_set_pace(run)
	human_npc_set_ai_movement(src, new_state == STEALTH_ALERT ? /datum/ai_movement/basic_avoidance : /datum/ai_movement/jps/stealth)
	for(var/datum/stealth_sight_overlay/overlay as anything in watchers)
		overlay.refresh()

/// Makes it wary, or starts the wary clock again.
/datum/ai_controller/basic_controller/human_npc/stealth/proc/stealth_set_wary()
	blackboard[BB_STEALTH_WARY] = TRUE
	wary_at = world.time

/datum/ai_controller/basic_controller/human_npc/stealth/proc/stealth_clear_wary()
	blackboard[BB_STEALTH_WARY] = FALSE
	wary_at = 0

/// Each scan: alert or searching keeps it wary; otherwise wary fades once STEALTH_WARY_TIME passes with nothing new.
/datum/ai_controller/basic_controller/human_npc/stealth/proc/stealth_update_wary()
	if(!blackboard[BB_STEALTH_WARY])
		return
	var/state = stealth_state()
	if(state == STEALTH_ALERT || state == STEALTH_SEARCHING)
		wary_at = world.time
	else if(world.time - wary_at >= STEALTH_WARY_TIME)
		stealth_clear_wary()

/// Walks (calm) or runs, through tg's own move intent, as bounty_ai_set_pace() does.
/datum/ai_controller/basic_controller/human_npc/stealth/proc/stealth_set_pace(run)
	var/mob/living/body = pawn
	if(!isliving(body) || QDELETED(body))
		return
	if(run != (body.move_intent == MOVE_INTENT_RUN))
		body.toggle_move_intent()

/// Ends its own stealth walk, if it has one, without counting it as a failed path.
/datum/ai_controller/basic_controller/human_npc/stealth/proc/stealth_drop_walk()
	var/datum/ai_behavior/walk = GET_AI_BEHAVIOR(/datum/ai_behavior/stealth_goto)
	if(walk && current_behaviors[walk])
		dropping_walk = TRUE
		fail_behavior(walk)
		dropping_walk = FALSE
	goto_turf = null
	goto_result = null

/// `where` pulled back to within STEALTH_LEASH_RANGE of home (abuse R3). Null if nowhere sensible.
/datum/ai_controller/basic_controller/human_npc/stealth/proc/stealth_leash(turf/where)
	var/turf/home = blackboard[BB_STEALTH_HOME_TURF]
	if(isnull(where) || isnull(home) || where.z != home.z)
		return where
	if(get_dist(home, where) <= STEALTH_LEASH_RANGE)
		return where
	var/turf/clamped = get_ranged_target_turf_direct(home, where, STEALTH_LEASH_RANGE)
	if(isnull(clamped) || clamped.is_blocked_turf(exclude_mobs = TRUE))
		return null
	return clamped

/datum/ai_controller/basic_controller/human_npc/stealth/proc/stealth_go_unaware()
	var/list/notice = notice_map
	notice?.Cut()
	clear_blackboard_key(BB_STEALTH_FOCUS)
	search_queue?.Cut()
	stealth_set_state(STEALTH_UNAWARE)
	stealth_rejoin_route()

/// Suspicious of something at `where`. `purpose` is STEALTH_GOTO_INVESTIGATE or STEALTH_GOTO_BODY.
/datum/ai_controller/basic_controller/human_npc/stealth/proc/stealth_go_suspicious(turf/where, purpose = STEALTH_GOTO_INVESTIGATE)
	var/mob/living/body = pawn
	stealth_set_state(STEALTH_SUSPICIOUS)
	goto_purpose = purpose
	investigate_turf = stealth_leash(where)
	investigated = FALSE
	last_gain = world.time
	set_blackboard_key(BB_STEALTH_LAST_SEEN_TURF, where)
	blackboard[BB_STEALTH_LAST_SEEN_AT] = world.time
	if(where && get_turf(body) != where)
		stand_dir = get_dir(body, where)
		body.setDir(stand_dir)
	stealth_bark(purpose == STEALTH_GOTO_BODY ? STEALTH_BARK_BODY : STEALTH_BARK_SUSPICIOUS)

/// Searching round `where`.
/datum/ai_controller/basic_controller/human_npc/stealth/proc/stealth_go_searching(turf/where)
	stealth_set_wary()
	if(isnull(where))
		where = get_turf(pawn)
	stealth_set_state(STEALTH_SEARCHING)
	search_center = stealth_leash(where) || get_turf(pawn)
	search_queue = stealth_search_spots(search_center)
	search_looking = FALSE
	next_search_bark = world.time + STEALTH_SEARCH_BARK_INTERVAL
	set_blackboard_key(BB_STEALTH_LAST_SEEN_TURF, where)
	blackboard[BB_STEALTH_LAST_SEEN_AT] = world.time

/// Alert on `target` (a mob, or the mech or vehicle someone sits in).
/datum/ai_controller/basic_controller/human_npc/stealth/proc/stealth_go_alert(atom/target)
	if(QDELETED(target))
		return
	if(stealth_state() != STEALTH_ALERT)
		stealth_set_state(STEALTH_ALERT)
	stealth_set_wary()
	set_blackboard_key(BB_STEALTH_FOCUS, target)
	set_blackboard_key(BB_STEALTH_LAST_SEEN_TURF, get_turf(target))
	blackboard[BB_STEALTH_LAST_SEEN_AT] = world.time
	set_blackboard_key(BB_BASIC_MOB_CURRENT_TARGET, target)

/// The spots a search checks: the centre first, then a few open tiles round it in its line of sight.
/datum/ai_controller/basic_controller/human_npc/stealth/proc/stealth_search_spots(turf/center)
	. = list()
	if(isnull(center))
		return
	. += center
	var/list/pool = list()
	var/datum/region = map_region_for_turf(center)
	for(var/turf/open/spot in RANGE_TURFS(STEALTH_SEARCH_RADIUS, center))
		if(spot == center || spot.is_blocked_turf(exclude_mobs = TRUE))
			continue
		if(map_region_excludes_turf(region, spot) || !stealth_leash(spot))
			continue
		pool += spot
	var/picked = 0
	while(length(pool) && picked < STEALTH_SEARCH_POINTS)
		var/turf/spot = pick_n_take(pool)
		if(!can_see(center, spot, STEALTH_SEARCH_RADIUS))
			continue
		. += spot
		picked++

/// Says a stealth line, at most once per STEALTH_BARK_KIND_COOLDOWN for each kind (abuse P14).
/datum/ai_controller/basic_controller/human_npc/stealth/proc/stealth_bark(kind)
	var/mob/living/carbon/human/npc/body = pawn
	if(!ishumannpc(body) || body.stat != CONSCIOUS)
		return FALSE
	if(world.time < bark_ready_at[kind])
		return FALSE
	bark_ready_at[kind] = world.time + STEALTH_BARK_KIND_COOLDOWN
	return body.npc_bark(kind, force = TRUE)

/// Moves every awareness timestamp back by `time`, as if that long had passed (unit tests, admin tools).
/datum/ai_controller/basic_controller/human_npc/stealth/proc/stealth_rewind(time)
	blackboard[BB_STEALTH_STATE_SINCE] -= time
	if(blackboard[BB_STEALTH_LAST_SEEN_AT])
		blackboard[BB_STEALTH_LAST_SEEN_AT] -= time
	if(blackboard[BB_STEALTH_UNAWARE_LOST_AT])
		blackboard[BB_STEALTH_UNAWARE_LOST_AT] -= time
	last_gain -= time
	wary_at -= time
	if(calm_until)
		calm_until -= time
	if(lost_since)
		lost_since -= time
	wait_until -= time
	look_until -= time
	next_body_scan -= time
	for(var/kind in bark_ready_at)
		bark_ready_at[kind] -= time

// ===== The scan =====

/**
 * One scan: expires a suspicion or search whose time has run out (also how a guard catches up after
 * sleeping), keeps an alert guard's target, or looks for someone new and for fallen friends.
 */
/datum/ai_controller/basic_controller/human_npc/stealth/proc/stealth_scan_once()
	var/mob/living/carbon/human/guard = pawn
	if(QDELETED(guard) || guard.stat != CONSCIOUS)
		return
	stealth_setup()
	stealth_update_wary()
	var/state = stealth_state()
	if(state == STEALTH_SEARCHING && calm_until)
		if(world.time >= calm_until)
			stealth_go_unaware()
	else if(state == STEALTH_SEARCHING && world.time - blackboard[BB_STEALTH_STATE_SINCE] >= STEALTH_SEARCH_TIME)
		stealth_bark(STEALTH_BARK_GIVE_UP)
		stealth_go_unaware()
	else if(state == STEALTH_SUSPICIOUS && world.time - last_gain >= STEALTH_SUSPICIOUS_TIMEOUT)
		stealth_bark(STEALTH_BARK_GIVE_UP)
		stealth_go_unaware()
	if(stealth_state() == STEALTH_ALERT)
		stealth_keep_target()
	else
		stealth_look()
		if(stealth_state() != STEALTH_ALERT && world.time >= next_body_scan)
			stealth_check_bodies()
	for(var/datum/stealth_sight_overlay/overlay as anything in watchers)
		overlay.refresh()

/// The cone half-angle it sees with now.
/datum/ai_controller/basic_controller/human_npc/stealth/proc/stealth_half_angle()
	if(stealth_state() == STEALTH_SEARCHING)
		return STEALTH_SEARCH_HALF_ANGLE
	if(blackboard[BB_STEALTH_WARY])
		return STEALTH_WARY_HALF_ANGLE
	return STEALTH_CONE_HALF_ANGLE

/// Whether its eyes work: not blind, not lying down (the close radius still works either way).
/datum/ai_controller/basic_controller/human_npc/stealth/proc/stealth_eyes_open()
	var/mob/living/guard = pawn
	return !guard.is_blind() && guard.body_position != LYING_DOWN

/// How far it sees onto `tile` in its cone: shorter in the dark unless it sees in the dark.
/datum/ai_controller/basic_controller/human_npc/stealth/proc/stealth_range_onto(turf/tile)
	if(!HAS_TRAIT(pawn, TRAIT_NIGHT_VISION) && stealth_tile_is_dark(tile))
		return STEALTH_DARK_SIGHT_RANGE
	return STEALTH_SIGHT_RANGE

/// Looks for someone new: raises notice on whoever it perceives, decays the rest, changes state.
/datum/ai_controller/basic_controller/human_npc/stealth/proc/stealth_look()
	var/mob/living/carbon/human/guard = pawn
	var/list/notice = notice_map
	var/datum/targeting_strategy/strategy = GET_TARGETING_STRATEGY(blackboard[BB_TARGETING_STRATEGY])
	if(isnull(strategy) || !isturf(guard.loc))
		return
	var/state = stealth_state()
	var/wary = blackboard[BB_STEALTH_WARY]
	var/atom/focus = blackboard[BB_STEALTH_FOCUS]
	var/eyes = stealth_eyes_open()
	var/half_angle = stealth_half_angle()
	var/scan_seconds = STEALTH_SCAN_INTERVAL / (1 SECONDS)
	var/list/perceived = list()
	for(var/mob/living/candidate as anything in stealth_candidates(guard, HUMAN_NPC_SIGHT_RANGE))
		// A mech or vehicle is never hidden: seen all round, no darkness, straight to alert (abuse P9).
		var/atom/vehicle = stealth_vehicle_of(candidate)
		if(vehicle)
			if(strategy.can_attack(guard, vehicle, HUMAN_NPC_SIGHT_RANGE))
				stealth_go_alert(vehicle)
				return
			continue
		// In a locker, a crate or anything else: unseen.
		if(!isturf(candidate.loc))
			continue
		var/turf/where = candidate.loc
		var/dist = get_dist(guard, where)
		if(dist > STEALTH_SIGHT_RANGE)
			continue
		if(!strategy.can_attack(guard, candidate, STEALTH_SIGHT_RANGE))
			continue
		var/rate = 0
		if(eyes && !stealth_is_cloaked(candidate) && stealth_in_cone(guard, where, half_angle))
			var/cap = stealth_range_onto(where)
			if(dist <= cap)
				rate = STEALTH_NOTICE_RATE * clamp((cap + 1 - dist) / cap, STEALTH_NOTICE_MIN_FALLOFF, 1)
				if(cap < STEALTH_SIGHT_RANGE)
					rate *= STEALTH_DARK_MULT
		var/felt = FALSE
		if(!rate && dist <= STEALTH_CLOSE_RANGE)
			// At its shoulder: light doesn't matter (abuse P7).
			rate = STEALTH_BEHIND_RATE
			felt = TRUE
		if(!rate)
			continue
		var/key = REF(candidate)
		var/list/entry = notice[key]
		if(isnull(entry))
			entry = list(0, null, 0)
			notice[key] = entry
		// First seen counts as moving: it just came into view.
		var/moved = entry[STEALTH_ENTRY_TURF] != where
		// STEP 2 STAND-IN: move intent stands in for "running is loud" until real footstep hearing lands.
		var/running = moved && candidate.move_intent == MOVE_INTENT_RUN
		if(running)
			rate *= STEALTH_RUN_MULT
		else if(!moved)
			rate *= STEALTH_STILL_MULT
		if(candidate.body_position == LYING_DOWN)
			rate *= STEALTH_LYING_MULT
		if(state == STEALTH_SUSPICIOUS && focus == candidate)
			rate *= STEALTH_SUSPICIOUS_MULT
		if(state == STEALTH_SEARCHING)
			rate *= STEALTH_SEARCHING_MULT
		if(wary)
			rate *= STEALTH_WARY_MULT
			wary_at = world.time
		entry[STEALTH_ENTRY_NOTICE] += rate * scan_seconds
		if(felt && running)
			entry[STEALTH_ENTRY_NOTICE] = max(entry[STEALTH_ENTRY_NOTICE], STEALTH_SUSPICIOUS_AT)
			guard.setDir(get_dir(guard, where))
		entry[STEALTH_ENTRY_TURF] = where
		entry[STEALTH_ENTRY_SEEN_AT] = world.time
		perceived[key] = candidate
	// Decay whoever it didn't perceive; forget anyone unseen for long enough.
	var/best_key
	var/best_notice = 0
	for(var/key in notice)
		var/list/entry = notice[key]
		if(!perceived[key])
			entry[STEALTH_ENTRY_NOTICE] = max(0, entry[STEALTH_ENTRY_NOTICE] - STEALTH_NOTICE_DECAY * scan_seconds)
			if(world.time - entry[STEALTH_ENTRY_SEEN_AT] > STEALTH_NOTICE_FORGET)
				notice -= key
				continue
		if(entry[STEALTH_ENTRY_NOTICE] > best_notice)
			best_notice = entry[STEALTH_ENTRY_NOTICE]
			best_key = key
	if(isnull(best_key))
		clear_blackboard_key(BB_STEALTH_FOCUS)
		return
	var/mob/living/best = perceived[best_key] || locate(best_key)
	if(!isliving(best) || QDELETED(best))
		notice -= best_key
		return
	set_blackboard_key(BB_STEALTH_FOCUS, best)
	var/list/best_entry = notice[best_key]
	var/turf/best_turf = best_entry[STEALTH_ENTRY_TURF]
	var/seen_now = !!perceived[best_key]
	switch(state)
		if(STEALTH_UNAWARE)
			if(best_notice >= STEALTH_SUSPICIOUS_AT)
				stealth_go_suspicious(best_turf)
		if(STEALTH_SUSPICIOUS, STEALTH_SEARCHING)
			if(!seen_now)
				return
			// No alert by sight from off-screen (abuse P8).
			if(best_notice >= STEALTH_ALERT_AT && get_dist(guard, best_turf) <= STEALTH_ALERT_MAX_RANGE)
				stealth_go_alert(best)
				return
			if(state == STEALTH_SEARCHING)
				if(best_notice >= STEALTH_SUSPICIOUS_AT)
					stealth_go_suspicious(best_turf)
				return
			last_gain = world.time
			set_blackboard_key(BB_STEALTH_LAST_SEEN_TURF, best_turf)
			blackboard[BB_STEALTH_LAST_SEEN_AT] = world.time

/**
 * Alert: keeps its target with tg's all-round can_attack() at the NPC's sight range (abuse P2). Out of
 * sight for STEALTH_LOSE_TARGET_TIME, it searches where it last saw them, not where they are now.
 */
/datum/ai_controller/basic_controller/human_npc/stealth/proc/stealth_keep_target()
	var/mob/living/guard = pawn
	var/atom/target = blackboard[BB_BASIC_MOB_CURRENT_TARGET]
	var/atom/remembered = target || blackboard[BB_STEALTH_FOCUS]
	if(QDELETED(remembered))
		stealth_go_searching(blackboard[BB_STEALTH_LAST_SEEN_TURF])
		return
	var/datum/targeting_strategy/strategy = GET_TARGETING_STRATEGY(blackboard[BB_TARGETING_STRATEGY])
	if(strategy?.can_attack(guard, remembered, HUMAN_NPC_SIGHT_RANGE))
		lost_since = 0
		set_blackboard_key(BB_STEALTH_LAST_SEEN_TURF, get_turf(remembered))
		blackboard[BB_STEALTH_LAST_SEEN_AT] = world.time
		if(!target)
			set_blackboard_key(BB_BASIC_MOB_CURRENT_TARGET, remembered)
		return
	// In plain sight but no longer worth fighting.
	if(get_dist(guard, remembered) <= HUMAN_NPC_SIGHT_RANGE && can_see(guard, remembered, HUMAN_NPC_SIGHT_RANGE))
		clear_blackboard_key(BB_BASIC_MOB_CURRENT_TARGET)
		clear_blackboard_key(BB_STEALTH_FOCUS)
		var/mob/living/fallen = remembered
		if(isliving(fallen) && (fallen.stat != CONSCIOUS || HAS_TRAIT(fallen, TRAIT_INCAPACITATED)))
			stealth_target_downed(fallen)
		else
			// An ally now, or out of reach: look round where it last was.
			stealth_go_searching(get_turf(remembered))
		return
	if(!lost_since)
		lost_since = world.time
	if(world.time - lost_since < STEALTH_LOSE_TARGET_TIME)
		return
	clear_blackboard_key(BB_BASIC_MOB_CURRENT_TARGET)
	stealth_bark(STEALTH_BARK_LOST)
	stealth_go_searching(blackboard[BB_STEALTH_LAST_SEEN_TURF])

/**
 * Its target is down (decision 23). Anyone else it has noticed keeps the alarm going as usual: alert on
 * someone it can see who hit it or was nearly spotted, otherwise suspicious or searching where they were.
 * With nobody else it says so, looks round where it stands, and calms down once STEALTH_CALM_LOOK_TIME is
 * up. The fallen one is forgotten: if they get up, they are noticed afresh (against a wary guard).
 */
/datum/ai_controller/basic_controller/human_npc/stealth/proc/stealth_target_downed(mob/living/fallen)
	var/mob/living/guard = pawn
	var/list/notice = notice_map
	notice -= REF(fallen)
	stealth_set_state(STEALTH_SEARCHING)
	search_center = get_turf(guard)
	search_queue?.Cut()
	search_looking = FALSE
	calm_until = world.time + STEALTH_CALM_LOOK_TIME
	look_until = calm_until
	stand_dir = guard.dir
	// Anyone it noticed lately or who hit it during the fight, read before this look decays them.
	var/best_notice = 0
	var/turf/best_turf
	var/mob/living/best
	for(var/key in notice)
		var/list/entry = notice[key]
		if(entry[STEALTH_ENTRY_NOTICE] < STEALTH_SUSPICIOUS_AT || entry[STEALTH_ENTRY_NOTICE] <= best_notice)
			continue
		if(world.time - entry[STEALTH_ENTRY_SEEN_AT] > STEALTH_NOTICE_FORGET)
			continue
		var/mob/living/someone = locate(key)
		if(!isliving(someone) || QDELETED(someone) || someone.stat == DEAD)
			continue
		best_notice = entry[STEALTH_ENTRY_NOTICE]
		best_turf = entry[STEALTH_ENTRY_TURF]
		best = someone
	// One look now: anyone else in view goes the normal way (suspicious or alert).
	stealth_look()
	if(stealth_state() != STEALTH_SEARCHING || !calm_until)
		return
	if(best)
		var/datum/targeting_strategy/strategy = GET_TARGETING_STRATEGY(blackboard[BB_TARGETING_STRATEGY])
		if(best_notice >= STEALTH_ALERT_AT && strategy?.can_attack(guard, best, HUMAN_NPC_SIGHT_RANGE))
			stealth_go_alert(best)
		else if(best_notice >= STEALTH_ALERT_AT)
			stealth_go_searching(best_turf)
		else
			stealth_go_suspicious(best_turf)
		return
	stealth_bark(STEALTH_BARK_DOWNED)

/**
 * Fallen friends (abuse P13): group members that are dead, in crit, cuffed or lying down, in its sight.
 * It reacts to each body once. The first guard to find one is suspicious and walks over; a guard that
 * finds a body someone already reported just searches there.
 */
/datum/ai_controller/basic_controller/human_npc/stealth/proc/stealth_check_bodies()
	next_body_scan = world.time + STEALTH_BODY_SCAN_INTERVAL
	if(isnull(group))
		return
	var/mob/living/guard = pawn
	var/list/seen = blackboard[BB_STEALTH_BODIES_SEEN]
	var/eyes = stealth_eyes_open()
	var/half_angle = stealth_half_angle()
	for(var/mob/living/member as anything in group.living_members())
		if(member == guard)
			continue
		if(!(member.stat == DEAD || HAS_TRAIT(member, TRAIT_CRITICAL_CONDITION) || HAS_TRAIT(member, TRAIT_RESTRAINED) || member.body_position == LYING_DOWN))
			continue
		var/key = REF(member)
		if(key in seen)
			continue
		// A body stuffed in a locker, a crate or a bag is hidden, as a living person there is.
		if(!isturf(member.loc))
			continue
		var/turf/where = member.loc
		if(isnull(where) || where.z != guard.z)
			continue
		var/dist = get_dist(guard, where)
		if(dist > STEALTH_SIGHT_RANGE)
			continue
		var/in_sight = dist <= STEALTH_CLOSE_RANGE
		if(!in_sight && eyes && stealth_in_cone(guard, where, half_angle))
			in_sight = dist <= stealth_range_onto(where)
		if(!in_sight || !can_see(guard, where, STEALTH_SIGHT_RANGE))
			continue
		seen += key
		if((key in group.reported_bodies) || stealth_state() == STEALTH_SEARCHING)
			stealth_go_searching(where)
		else
			group.reported_bodies += key
			stealth_go_suspicious(where, STEALTH_GOTO_BODY)
		return

// ===== Touches, hits and recovery =====

/**
 * Anyone touching or hurting it (abuse P3): alert on them if it can see them, otherwise a search at
 * their turf. Always wary. Allies are ignored. Returns TRUE if it took a target.
 */
/datum/ai_controller/basic_controller/human_npc/stealth/proc/stealth_touched(atom/source)
	var/mob/living/guard = pawn
	if(QDELETED(source) || QDELETED(guard) || source == guard || guard.stat == DEAD)
		return FALSE
	if(ismovable(source) && guard.faction_check_atom(source))
		return FALSE
	stealth_set_wary()
	if(stealth_state() == STEALTH_ALERT && blackboard_key_exists(BB_BASIC_MOB_CURRENT_TARGET))
		// Busy with someone else: it remembers who else is hurting it for when that fight ends.
		if(isliving(source) && source != blackboard[BB_BASIC_MOB_CURRENT_TARGET])
			var/list/notice = notice_map
			var/list/entry = notice[REF(source)]
			if(isnull(entry))
				entry = list(0, null, 0)
				notice[REF(source)] = entry
			entry[STEALTH_ENTRY_NOTICE] = max(entry[STEALTH_ENTRY_NOTICE], STEALTH_ALERT_AT)
			entry[STEALTH_ENTRY_TURF] = get_turf(source)
			entry[STEALTH_ENTRY_SEEN_AT] = world.time
		return FALSE
	var/atom/who = isliving(source) ? bounty_ai_target_for(source) : source
	var/datum/targeting_strategy/strategy = GET_TARGETING_STRATEGY(blackboard[BB_TARGETING_STRATEGY])
	if(strategy?.can_attack(guard, who))
		stealth_go_alert(who)
		return TRUE
	stealth_go_searching(get_turf(source))
	stealth_bark(STEALTH_BARK_HIT_UNSEEN)
	return FALSE

/datum/ai_controller/basic_controller/human_npc/stealth/on_pawn_attacked(mob/living/source, atom/attacker, attack_flags)
	if(stealth_touched(attacker))
		return
	if(!blackboard_key_exists(BB_BASIC_MOB_CURRENT_TARGET))
		return ..()

/datum/ai_controller/basic_controller/human_npc/stealth/proc/on_pulled(mob/living/source, atom/movable/puller)
	SIGNAL_HANDLER
	stealth_touched(puller)

/datum/ai_controller/basic_controller/human_npc/stealth/proc/on_bumped(atom/source, atom/movable/bumper)
	SIGNAL_HANDLER
	if(isliving(bumper))
		stealth_touched(bumper)

/datum/ai_controller/basic_controller/human_npc/stealth/proc/on_helped(mob/living/source, mob/living/helper)
	SIGNAL_HANDLER
	stealth_touched(helper)

/// relay_attackers only reports a mob firer; a turret or other machine shooting it counts the same.
/datum/ai_controller/basic_controller/human_npc/stealth/proc/on_projectile_prehit(atom/source, obj/projectile/hit_projectile)
	SIGNAL_HANDLER
	if(!hit_projectile.is_hostile_projectile() || isnull(hit_projectile.firer) || ismob(hit_projectile.firer))
		return
	stealth_touched(hit_projectile.firer)

/// Anything else that sets a target (an admin, another subtree) makes it alert.
/datum/ai_controller/basic_controller/human_npc/stealth/proc/on_target_set(datum/source)
	SIGNAL_HANDLER
	var/atom/target = blackboard[BB_BASIC_MOB_CURRENT_TARGET]
	if(isnull(target) || stealth_state() == STEALTH_ALERT)
		return
	stealth_set_state(STEALTH_ALERT)
	stealth_set_wary()
	set_blackboard_key(BB_STEALTH_FOCUS, target)

/// Carried off the level: drops its route and holds where it is (abuse R3). The base controller already
/// listens for the level change.
/datum/ai_controller/basic_controller/human_npc/stealth/on_changed_z_level(atom/source, turf/old_turf, turf/new_turf, same_z_layer, notify_contents)
	. = ..()
	if(stealth_ready && new_turf)
		stealth_become_sentry(new_turf)

/datum/ai_controller/basic_controller/human_npc/stealth/on_stat_changed(mob/living/source, new_stat)
	. = ..()
	var/was = last_stat
	last_stat = new_stat
	if(new_stat == CONSCIOUS && was != CONSCIOUS && was != DEAD)
		stealth_came_round()

/datum/ai_controller/basic_controller/human_npc/stealth/proc/on_status_removed(mob/living/source, datum/status_effect/effect)
	SIGNAL_HANDLER
	if(istype(effect, /datum/status_effect/incapacitating/stamcrit))
		stealth_came_round()

/// Back on its feet after crit or stamcrit: it knows something happened.
/datum/ai_controller/basic_controller/human_npc/stealth/proc/stealth_came_round()
	var/mob/living/guard = pawn
	if(QDELETED(guard) || guard.stat == DEAD)
		return
	stealth_set_wary()
	if(blackboard_key_exists(BB_BASIC_MOB_CURRENT_TARGET))
		return
	stealth_go_searching(get_turf(guard))

// A guard that gives up is wary.
/mob/living/carbon/human/npc/npc_surrender()
	. = ..()
	if(.)
		var/datum/ai_controller/basic_controller/human_npc/stealth/stealth_ai = ai_controller
		if(istype(stealth_ai))
			stealth_ai.stealth_set_wary()

/**
 * Step 3 hook. TRUE if this guard was unaware when the current blow began: unaware now, or it stopped
 * being unaware during this same tick (relay_attackers flips it before damage for hands and bullets,
 * abuse P12). FALSE for any NPC without the stealth controller.
 */
/mob/living/carbon/human/npc/proc/stealth_was_unaware()
	var/datum/ai_controller/basic_controller/human_npc/stealth/stealth_ai = ai_controller
	if(!istype(stealth_ai))
		return FALSE
	if(stealth_ai.stealth_state() == STEALTH_UNAWARE)
		return TRUE
	return stealth_ai.blackboard[BB_STEALTH_UNAWARE_LOST_AT] == world.time

// ===== Planning =====

/// Pathfinding movement with room for a long patrol leg.
/datum/ai_movement/jps/stealth
	maximum_length = STEALTH_PATROL_MAX_PATH

/// Queues the scan every plan. Never ends planning.
/datum/ai_planning_subtree/stealth_perception

/datum/ai_planning_subtree/stealth_perception/SelectBehaviors(datum/ai_controller/basic_controller/human_npc/stealth/controller, seconds_per_tick)
	var/mob/living/guard = controller.pawn
	if(guard.stat != CONSCIOUS || !istype(controller))
		return
	controller.stealth_setup()
	controller.queue_behavior(/datum/ai_behavior/stealth_scan)

/datum/ai_behavior/stealth_scan
	action_cooldown = STEALTH_SCAN_INTERVAL
	behavior_flags = AI_BEHAVIOR_CAN_PLAN_DURING_EXECUTION

/datum/ai_behavior/stealth_scan/perform(seconds_per_tick, datum/ai_controller/basic_controller/human_npc/stealth/controller)
	if(istype(controller))
		controller.stealth_scan_once()
	return AI_BEHAVIOR_DELAY

/// Suspicious: stare, walk over, look round. Searching: sweep the spots. Ends planning while it acts.
/datum/ai_planning_subtree/stealth_react

/datum/ai_planning_subtree/stealth_react/SelectBehaviors(datum/ai_controller/basic_controller/human_npc/stealth/controller, seconds_per_tick)
	if(!istype(controller) || controller.blackboard_key_exists(BB_BASIC_MOB_CURRENT_TARGET))
		return
	var/mob/living/guard = controller.pawn
	switch(controller.stealth_state())
		if(STEALTH_SUSPICIOUS)
			if(world.time < controller.blackboard[BB_STEALTH_STATE_SINCE] + STEALTH_INVESTIGATE_DELAY)
				controller.queue_behavior(/datum/ai_behavior/stealth_stand)
				return SUBTREE_RETURN_FINISH_PLANNING
			if(!controller.investigated)
				var/turf/dest = controller.investigate_turf
				if(dest && get_turf(guard) != dest && controller.goto_result != "failed")
					controller.stealth_walk(dest, controller.goto_purpose)
					return SUBTREE_RETURN_FINISH_PLANNING
				controller.investigated = TRUE
				controller.stealth_drop_walk()
				if(controller.goto_purpose == STEALTH_GOTO_BODY)
					controller.stealth_go_searching(get_turf(guard))
					return SUBTREE_RETURN_FINISH_PLANNING
				controller.look_until = world.time + STEALTH_LOOK_AROUND_TIME
			controller.queue_behavior(/datum/ai_behavior/stealth_stand)
			return SUBTREE_RETURN_FINISH_PLANNING
		if(STEALTH_SEARCHING)
			// Its target is down: it looks round where it stands until it calms down.
			if(controller.calm_until)
				controller.queue_behavior(/datum/ai_behavior/stealth_stand)
				return SUBTREE_RETURN_FINISH_PLANNING
			if(world.time >= controller.next_search_bark)
				controller.next_search_bark = world.time + STEALTH_SEARCH_BARK_INTERVAL
				controller.stealth_bark(STEALTH_BARK_SEARCH)
			if(controller.search_looking)
				if(world.time < controller.look_until)
					controller.queue_behavior(/datum/ai_behavior/stealth_stand)
					return SUBTREE_RETURN_FINISH_PLANNING
				controller.search_looking = FALSE
				if(length(controller.search_queue))
					controller.search_queue.Cut(1, 2)
			if(!length(controller.search_queue))
				controller.search_queue = controller.stealth_search_spots(controller.search_center)
			if(!length(controller.search_queue))
				controller.queue_behavior(/datum/ai_behavior/stealth_stand)
				return SUBTREE_RETURN_FINISH_PLANNING
			var/turf/spot = controller.search_queue[1]
			if(get_turf(guard) == spot || (controller.goto_turf == spot && controller.goto_result))
				controller.stealth_drop_walk()
				controller.search_looking = TRUE
				controller.look_until = world.time + STEALTH_LOOK_AROUND_TIME
				controller.queue_behavior(/datum/ai_behavior/stealth_stand)
				return SUBTREE_RETURN_FINISH_PLANNING
			controller.stealth_walk(spot, STEALTH_GOTO_SEARCH)
			return SUBTREE_RETURN_FINISH_PLANNING

/// Starts (or keeps) its stealth walk to `dest`.
/datum/ai_controller/basic_controller/human_npc/stealth/proc/stealth_walk(turf/dest, purpose)
	var/datum/ai_behavior/walk = GET_AI_BEHAVIOR(/datum/ai_behavior/stealth_goto)
	if(goto_turf != dest && current_behaviors[walk])
		stealth_drop_walk()
	if(goto_turf != dest)
		goto_result = null
	goto_turf = dest
	goto_purpose = purpose
	queue_behavior(/datum/ai_behavior/stealth_goto)

/**
 * Walks to the controller's goto_turf with its pathfinding movement. Ends on arrival, or as a failure
 * when the pathfinder gives up or the leg takes far too long (abuse R2).
 */
/datum/ai_behavior/stealth_goto
	required_distance = 0
	action_cooldown = 0.5 SECONDS
	behavior_flags = AI_BEHAVIOR_REQUIRE_MOVEMENT | AI_BEHAVIOR_MOVE_AND_PERFORM | AI_BEHAVIOR_CAN_PLAN_DURING_EXECUTION

/datum/ai_behavior/stealth_goto/setup(datum/ai_controller/basic_controller/human_npc/stealth/controller)
	. = ..()
	if(!istype(controller) || isnull(controller.goto_turf))
		return FALSE
	controller.goto_started = world.time
	set_movement_target(controller, controller.goto_turf)

/datum/ai_behavior/stealth_goto/perform(seconds_per_tick, datum/ai_controller/basic_controller/human_npc/stealth/controller)
	var/turf/dest = controller.goto_turf
	if(isnull(dest))
		return AI_BEHAVIOR_INSTANT | AI_BEHAVIOR_FAILED
	var/turf/here = get_turf(controller.pawn)
	if(here == dest)
		return AI_BEHAVIOR_INSTANT | AI_BEHAVIOR_SUCCEEDED
	// Someone stands on the spot: next to it will do.
	if(get_dist(here, dest) <= 1 && dest.is_blocked_turf(exclude_mobs = FALSE) && !dest.is_blocked_turf(exclude_mobs = TRUE))
		return AI_BEHAVIOR_INSTANT | AI_BEHAVIOR_SUCCEEDED
	if(world.time - controller.goto_started > STEALTH_PATROL_MAX_PATH * max(controller.movement_delay, 0.4 SECONDS) * 1.5)
		controller.goto_timed_out = TRUE
		return AI_BEHAVIOR_INSTANT | AI_BEHAVIOR_FAILED
	return AI_BEHAVIOR_INSTANT

/datum/ai_behavior/stealth_goto/finish_action(datum/ai_controller/basic_controller/human_npc/stealth/controller, succeeded)
	if(istype(controller) && !controller.dropping_walk)
		if(succeeded)
			controller.goto_result = "arrived"
		else
			// Only a real path failure counts; being re-planned away from a walk does not.
			var/path_failed = controller.goto_timed_out || controller.consecutive_pathing_attempts >= controller.ai_movement.max_pathing_attempts
			if(path_failed)
				controller.goto_result = "failed"
				controller.stealth_walk_failed()
		controller.goto_timed_out = FALSE
	return ..()

/**
 * Standing: at a stop, a sentry's post, staring at something, or looking round. Turns its head now and
 * then. Never finishes by itself; planning replaces it.
 */
/datum/ai_behavior/stealth_stand
	action_cooldown = 1 SECONDS
	behavior_flags = AI_BEHAVIOR_CAN_PLAN_DURING_EXECUTION

/datum/ai_behavior/stealth_stand/perform(seconds_per_tick, datum/ai_controller/basic_controller/human_npc/stealth/controller)
	var/mob/living/guard = controller.pawn
	if(!istype(controller) || guard.stat != CONSCIOUS || !isturf(guard.loc))
		return AI_BEHAVIOR_DELAY
	if(world.time < controller.look_until)
		// Looking round: two other ways over STEALTH_LOOK_AROUND_TIME.
		if(world.time >= controller.next_turn)
			controller.next_turn = world.time + STEALTH_LOOK_AROUND_TIME / 2
			guard.setDir(turn(controller.stand_dir, pick(90, -90, 180)))
		return AI_BEHAVIOR_DELAY
	if(world.time < controller.next_turn)
		return AI_BEHAVIOR_DELAY
	var/state = controller.stealth_state()
	if(state == STEALTH_SUSPICIOUS && !controller.investigated)
		guard.setDir(controller.stand_dir)
		return AI_BEHAVIOR_DELAY
	var/sentry = isnull(controller.route_id)
	controller.next_turn = world.time + (sentry ? STEALTH_SENTRY_TURN_INTERVAL : STEALTH_LOOK_TURN_INTERVAL)
	if(guard.dir != controller.stand_dir)
		guard.setDir(controller.stand_dir)
	else if(sentry || prob(STEALTH_LOOK_TURN_CHANCE))
		guard.setDir(turn(controller.stand_dir, pick(STEALTH_LOOK_TURN_ARC, -STEALTH_LOOK_TURN_ARC)))
	return AI_BEHAVIOR_DELAY
