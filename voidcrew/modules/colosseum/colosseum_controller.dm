/**
 * # Colosseum match controller
 *
 * The state machine running the venue's match loop:
 *
 *   IDLE -> SIGNUP -> SEATING -> LIVE -> RESOLVED -> RESET -> IDLE
 *
 * Who drives each transition:
 * * IDLE -> SIGNUP: a player at the signup console (or an admin verb).
 * * SIGNUP -> SEATING: the signup window timer (roster lock). Fizzles back to
 *   IDLE if fewer than two contestants registered.
 * * SEATING -> LIVE: the seating timer: absentees are dropped, non-contestants
 *   ejected from staging, the rear seals close, contestants are seated, and
 *   after a short countdown the mode's gates pop. Fizzles to IDLE if the
 *   survivors no longer satisfy the mode's minimum.
 * * LIVE -> RESOLVED: win detection: death/deletion signals on contestants,
 *   disconnect grace timers, area-sensitivity forfeits, mode victory checks,
 *   or the match time limit.
 * * RESOLVED -> RESET -> IDLE: automatic timers. The spoils claim window runs
 *   on its own parallel track and never blocks the next match.
 *
 * All contestant tracking is signal-driven (no polling); modes that need a
 * clock (king of the hill) opt into SSprocessing for the LIVE phase only.
 */

/// One registered contestant. Keyed by mind. Bodies can change, minds don't.
/datum/colosseum_contestant
	/// The registered mind
	var/datum/mind/mind
	/// ckey at signup, for rosters and logs
	var/ckey
	/// Contestant display name (mob name at signup)
	var/display_name
	/// Ship affiliation recorded at signup ("Unaffiliated" if none)
	var/ship_name = "Unaffiliated"
	/// The crew team recorded at signup (null when unaffiliated). Team modes
	/// group by this ref. Names can collide, team datums can't.
	var/datum/team/voidcrew/crew_team
	/// Team id (COLOSSEUM_TEAM_*), assigned at roster lock
	var/team = COLOSSEUM_TEAM_SOLO
	/// The body being tracked (signals registered on it). Re-synced on body swaps.
	var/mob/living/body
	/// Whether this contestant is out of the current match
	var/eliminated = FALSE
	/// Why they're out (COLOSSEUM_ELIM_*)
	var/elimination_reason
	/// Pending disconnect-grace timer id (TIMER_STOPPABLE), if any
	var/disconnect_timer

/datum/colosseum_contestant/New(datum/mind/mind)
	src.mind = mind
	ckey = mind.key
	display_name = mind.current ? mind.current.real_name : "unknown"
	var/datum/team/voidcrew/crew = LAZYACCESS(mind.ship_teams, 1)
	if(crew?.ship)
		ship_name = crew.ship.name
		crew_team = crew

/datum/colosseum_contestant/Destroy()
	if(disconnect_timer)
		deltimer(disconnect_timer)
		disconnect_timer = null
	mind = null
	body = null
	crew_team = null
	return ..()

/datum/colosseum_controller
	/// The venue this controller runs
	var/obj/structure/overmap/colosseum/site
	/// Current state (COLOSSEUM_STATE_*)
	var/state = COLOSSEUM_STATE_IDLE
	/// Registered contestants for the current match cycle
	var/list/datum/colosseum_contestant/roster = list()
	/// The mode chosen at roster lock
	var/datum/colosseum_game/mode
	/// Current phase-transition timer id (TIMER_STOPPABLE)
	var/phase_timer
	/// Match time-limit timer id (TIMER_STOPPABLE), running during LIVE
	var/match_timer
	/// world.time the signup window closes (for countdown displays)
	var/signup_closes_at = 0
	/// Whether the SEATING phase has passed its roster cut (gate countdown running)
	var/seals_closed = FALSE
	/// world.time the next signup may open (post-match cooldown)
	var/next_signup_at = 0
	/// Winning minds of the last resolved match (assoc mind -> TRUE)
	var/list/winner_minds = list()
	/// world.time the winners-only spoils claim window ends
	var/claim_until = 0
	/// Claim-window expiry timer id (TIMER_STOPPABLE). Runs parallel to the
	/// phase timers and survives RESET, so it has its own slot.
	var/claim_timer
	/// Dynamic arena event scheduler, running only while a match that wants it is LIVE
	var/datum/colosseum_arena_scheduler/arena_scheduler
	/// Match modifier rolled at roster lock (beasts, temperature, walls, ...)
	var/datum/colosseum_modifier/modifier
	/// The wagering book for the current match cycle (null when no match forming)
	var/datum/colosseum_book/book
	/// Settled books kept alive so old betting slips stay redeemable all round
	var/list/datum/colosseum_book/old_books = list()
	/// Arena floor baseline: turf -> turf typepath, captured at first load
	var/list/arena_baseline_turfs
	/// Arena furniture baseline: list of list(typepath, turf, dir)
	var/list/arena_baseline_objects
	/// Matches resolved this round (flavor + logs)
	var/matches_run = 0

/datum/colosseum_controller/New(obj/structure/overmap/colosseum/site)
	src.site = site
	snapshot_arena()

/datum/colosseum_controller/Destroy()
	if(phase_timer)
		deltimer(phase_timer)
		phase_timer = null
	if(match_timer)
		deltimer(match_timer)
		match_timer = null
	if(claim_timer)
		deltimer(claim_timer)
		claim_timer = null
	QDEL_NULL(arena_scheduler)
	QDEL_NULL(modifier)
	QDEL_NULL(book)
	QDEL_LIST(old_books)
	clear_roster()
	QDEL_NULL(mode)
	winner_minds.Cut()
	arena_baseline_turfs = null
	arena_baseline_objects = null
	site = null
	return ..()

/// Every non-eliminated contestant.
/datum/colosseum_controller/proc/live_entries()
	var/list/result = list()
	for(var/datum/colosseum_contestant/entry as anything in roster)
		if(!entry.eliminated)
			result += entry
	return result

/// The roster entry for a mind, or null.
/datum/colosseum_controller/proc/entry_for_mind(datum/mind/mind)
	for(var/datum/colosseum_contestant/entry as anything in roster)
		if(entry.mind == mind)
			return entry
	return null

/// Whether the winners-only spoils claim window is running right now.
/datum/colosseum_controller/proc/claim_window_active()
	return claim_until && world.time < claim_until && length(winner_minds)

/// Number of distinct crew groups on the roster. Each crewed ship is one
/// group, each unaffiliated contestant their own. Team modes need at least
/// two, or one side of the arena would stand empty.
/datum/colosseum_controller/proc/count_ship_groups()
	var/list/crews_seen = list()
	var/singletons = 0
	for(var/datum/colosseum_contestant/entry as anything in roster)
		if(entry.crew_team)
			crews_seen[entry.crew_team] = TRUE
		else
			singletons++
	return length(crews_seen) + singletons

/// Estimated deciseconds until the arena gates pop (0 outside SIGNUP/SEATING).
/// The ETA boards' headline number.
/datum/colosseum_controller/proc/time_to_gates()
	switch(state)
		if(COLOSSEUM_STATE_SIGNUP)
			return max(0, signup_closes_at - world.time) + COLOSSEUM_SEATING_DURATION + COLOSSEUM_GATE_COUNTDOWN
		if(COLOSSEUM_STATE_SEATING)
			var/phase_left = phase_timer ? timeleft(phase_timer) : 0
			return max(0, phase_left) + (seals_closed ? 0 : COLOSSEUM_GATE_COUNTDOWN)
	return 0

/// Unregisters and clears the whole roster.
/datum/colosseum_controller/proc/clear_roster()
	for(var/datum/colosseum_contestant/entry as anything in roster)
		untrack_contestant(entry)
	QDEL_LIST(roster)

// ===== SIGNUP =====

/// Whether a new signup may open right now (used by the console UI too).
/datum/colosseum_controller/proc/can_open_signup()
	return state == COLOSSEUM_STATE_IDLE && world.time >= next_signup_at

/**
 * IDLE -> SIGNUP. Opened from the signup console or an admin verb; announces
 * galaxy-wide with the venue's overmap coordinates so crews can fly in.
 */
/datum/colosseum_controller/proc/open_signup(mob/opener, forced = FALSE)
	if(state != COLOSSEUM_STATE_IDLE)
		return FALSE
	if(!forced && world.time < next_signup_at)
		return FALSE
	set_state(COLOSSEUM_STATE_SIGNUP)
	signup_closes_at = world.time + COLOSSEUM_SIGNUP_DURATION
	phase_timer = addtimer(CALLBACK(src, PROC_REF(lock_roster)), COLOSSEUM_SIGNUP_DURATION, TIMER_STOPPABLE)
	site.broadcast_galaxy("Registration is OPEN at the Grand Colosseum, [site.coords_text()]! Contestants have [DisplayTimeText(COLOSSEUM_SIGNUP_DURATION)] to sign up at the concourse. Spectators and wagers welcome.")
	log_game("COLOSSEUM: signup opened[opener ? " by [key_name(opener)]" : ""].")
	return TRUE

/// Registers a mind. Returns FALSE with user feedback handled by the console.
/datum/colosseum_controller/proc/register_contestant(mob/living/user)
	if(state != COLOSSEUM_STATE_SIGNUP)
		return FALSE
	if(!istype(user) || !user.mind || user.stat == DEAD)
		return FALSE
	if(entry_for_mind(user.mind))
		return FALSE
	var/datum/colosseum_contestant/entry = new(user.mind)
	roster += entry
	site.venue_message(span_notice("<b>[entry.display_name]</b> ([entry.ship_name]) has entered the roster! ([length(roster)] registered)"))
	to_chat(user, span_boldnotice("You're on the roster. Stay at the venue - your berthed ship counts. The wardens will carry you to your gate when the roster locks."))
	return TRUE

/// Withdraws a mind during the signup window.
/datum/colosseum_controller/proc/withdraw_contestant(mob/living/user)
	if(state != COLOSSEUM_STATE_SIGNUP || !user.mind)
		return FALSE
	var/datum/colosseum_contestant/entry = entry_for_mind(user.mind)
	if(!entry)
		return FALSE
	roster -= entry
	qdel(entry)
	site.venue_message(span_notice("<b>[user.real_name]</b> has withdrawn from the roster. ([length(roster)] registered)"))
	return TRUE

/**
 * SIGNUP -> SEATING (roster lock). Picks the mode, assigns teams, announces
 * mode + stakes, and starts the seating window. Fizzles if under-subscribed.
 */
/datum/colosseum_controller/proc/lock_roster()
	if(state != COLOSSEUM_STATE_SIGNUP)
		return
	stop_phase_timer()
	signup_closes_at = 0

	// Prune entries whose minds evaporated during the window
	for(var/datum/colosseum_contestant/entry as anything in roster.Copy())
		if(!entry.mind || !entry.mind.current)
			roster -= entry
			qdel(entry)

	if(length(roster) < 2)
		fizzle("Registration closed with too few contestants. No match today.")
		return

	mode = pick_mode()
	if(!mode)
		fizzle("No suitable game could be arranged for [length(roster)] contestants.")
		return
	mode.controller = src
	mode.assign_teams(roster)
	modifier = pick_modifier()
	book = new(src)
	book.open = TRUE

	seals_closed = FALSE
	set_state(COLOSSEUM_STATE_SEATING)
	for(var/datum/colosseum_contestant/entry as anything in roster)
		track_contestant(entry)
	phase_timer = addtimer(CALLBACK(src, PROC_REF(close_seating)), COLOSSEUM_SEATING_DURATION, TIMER_STOPPABLE)
	site.broadcast_galaxy("Roster LOCKED: [length(roster)] contestants. Game: [mode.name]. Arena condition: [modifier.name]. Stakes: [mode.stakes_text(length(roster))]. Contestants, stay at the venue - your berthed ship counts. The wardens will seat you when the seals close in [DisplayTimeText(COLOSSEUM_SEATING_DURATION)]. Bets close when the gates open.")
	site.venue_message(span_notice("<b>[mode.name]</b>: [mode.desc]<br><b>[modifier.name]</b>: [modifier.desc]"))
	log_game("COLOSSEUM: roster locked with [length(roster)] contestants, mode [mode.name], modifier [modifier.name].")

/// Weighted-random match modifier eligible for the roster size. Never null.
/datum/colosseum_controller/proc/pick_modifier()
	var/list/eligible = list()
	var/n = length(roster)
	for(var/modifier_type in subtypesof(/datum/colosseum_modifier))
		var/datum/colosseum_modifier/candidate = modifier_type
		if(!initial(candidate.name))
			continue
		if(n < initial(candidate.min_roster))
			continue
		eligible[modifier_type] = initial(candidate.weight)
	var/chosen_type = pick_weight(eligible) || /datum/colosseum_modifier/clean
	var/datum/colosseum_modifier/chosen = new chosen_type
	chosen.controller = src
	return chosen

/// Weighted-random mode eligible for the roster size.
/datum/colosseum_controller/proc/pick_mode()
	var/list/eligible = list()
	var/n = length(roster)
	var/groups = count_ship_groups()
	for(var/mode_type in subtypesof(/datum/colosseum_game))
		var/datum/colosseum_game/candidate = mode_type
		if(!initial(candidate.name)) // abstract bases
			continue
		if(n < initial(candidate.min_players) || n > initial(candidate.max_players))
			continue
		if(initial(candidate.team_based) && groups < 2)
			continue // a lone crew rolling red-vs-blue would win at the bell
		eligible[mode_type] = initial(candidate.weight)
	var/chosen_type = pick_weight(eligible)
	if(!chosen_type)
		// Every mode's max_players is exceeded, a full house. Waive the caps
		// rather than fizzle the best-attended match of the round; seating
		// round-robins overflow into the ready rooms, so big fields still work.
		for(var/fallback_type in subtypesof(/datum/colosseum_game))
			var/datum/colosseum_game/fallback = fallback_type
			if(!initial(fallback.name) || n < initial(fallback.min_players))
				continue
			if(initial(fallback.team_based) && groups < 2)
				continue
			eligible[fallback_type] = initial(fallback.weight)
		chosen_type = pick_weight(eligible)
	return chosen_type ? new chosen_type : null

/// Any-state failure exit back to IDLE, with an announcement.
/datum/colosseum_controller/proc/fizzle(message)
	site.broadcast_galaxy(message)
	var/was_live = (state == COLOSSEUM_STATE_LIVE)
	stop_phase_timer()
	stop_match_timer()
	QDEL_NULL(arena_scheduler)
	if(modifier?.started)
		modifier.on_match_end() // admin cancel mid-LIVE: beasts/walls must not linger
	QDEL_NULL(modifier)
	settle_book(list()) // all bets refund at face value
	// A cancel mid-fight leaves contestants sealed behind closed gates, collect
	// their bodies now, walk them out once the tracking signals are gone.
	var/list/mob/living/stranded = list()
	for(var/datum/colosseum_contestant/entry as anything in roster)
		var/mob/living/body = entry.mind?.current || entry.body
		if(isliving(body))
			stranded += body
	clear_roster()
	QDEL_NULL(mode)
	site.gates_to_idle()
	next_signup_at = world.time + COLOSSEUM_SIGNUP_COOLDOWN
	set_state(COLOSSEUM_STATE_IDLE)
	for(var/mob/living/stranded_body as anything in stranded)
		if(QDELETED(stranded_body))
			continue
		var/area/body_area = get_area(stranded_body)
		if(istype(body_area, /area/voidcrew/colosseum/arena) || istype(body_area, /area/voidcrew/colosseum/staging))
			site.bounce_to_lobby(stranded_body, "The match is off. The wardens walk you back to the concourse.")
	if(was_live)
		reset_arena() // rake the blood and hazard debris out of a half-fought match

// ===== SEATING =====

/**
 * SEATING -> LIVE. Drops absentees, ejects gatecrashers, seals staging, seats
 * everyone in their mode-assigned positions and starts the gate countdown.
 * Contestants don't walk to staging themselves. Being anywhere inside the
 * venue is enough, and seat_contestants() teleports them to their assigned
 * cell or ready room (one contestant per solo cell).
 */
/datum/colosseum_controller/proc/close_seating()
	if(state != COLOSSEUM_STATE_SEATING)
		return
	stop_phase_timer()

	// Re-sync bodies (people swap bodies, get borged, etc.) and drop anyone
	// not physically inside the venue. Dead contestants count as absent.
	for(var/datum/colosseum_contestant/entry as anything in roster.Copy())
		var/mob/living/current_body = entry.mind?.current
		if(!isliving(current_body) || current_body.stat == DEAD || !site.mob_at_venue(current_body))
			site.venue_message(span_warning("<b>[entry.display_name]</b> never showed up and is off the roster."))
			book?.scratch(entry.mind) // their backers get their money back
			untrack_contestant(entry)
			roster -= entry
			qdel(entry)
			continue
		if(entry.body != current_body)
			untrack_contestant(entry)
			entry.body = current_body
			track_contestant(entry)

	// Nobody sneaks in behind a contestant: anyone in staging who isn't on the
	// roster gets ushered back to the concourse before the seals drop.
	for(var/turf/staging_turf as anything in site.get_area_turfs_cached(/area/voidcrew/colosseum/staging))
		for(var/mob/living/loiterer in staging_turf)
			if(entry_for_mind(loiterer.mind))
				continue
			var/turf/eject_to = site.get_random_lobby_turf()
			if(eject_to)
				loiterer.forceMove(eject_to)
				to_chat(loiterer, span_warning("Colosseum wardens drag you out of the staging halls. Contestants only."))

	if(length(live_entries()) < mode.min_players)
		fizzle("Too many no-shows. The [mode.name] match is called off.")
		return

	// A team match with an empty side would resolve at the bell, no free purses.
	if(mode.team_based)
		var/red_present = FALSE
		var/blue_present = FALSE
		for(var/datum/colosseum_contestant/entry as anything in live_entries())
			if(entry.team == COLOSSEUM_TEAM_RED)
				red_present = TRUE
			else if(entry.team == COLOSSEUM_TEAM_BLUE)
				blue_present = TRUE
		if(!red_present || !blue_present)
			fizzle("A whole side failed to show. The [mode.name] match is called off.")
			return

	seals_closed = TRUE
	site.set_gates(COLOSSEUM_SEAL, FALSE)
	mode.seat_contestants()
	site.venue_message(span_boldannounce("The staging seals grind shut. The gates open in [COLOSSEUM_GATE_COUNTDOWN / 10] seconds!"))
	phase_timer = addtimer(CALLBACK(src, PROC_REF(go_live)), COLOSSEUM_GATE_COUNTDOWN, TIMER_STOPPABLE)

/// The gates pop: SEATING -> LIVE.
/datum/colosseum_controller/proc/go_live()
	if(state != COLOSSEUM_STATE_SEATING)
		return
	stop_phase_timer()
	set_state(COLOSSEUM_STATE_LIVE)
	for(var/gate_id in mode.get_gate_ids())
		site.set_gates(gate_id, TRUE)
	var/time_limit = mode.time_limit || COLOSSEUM_DEFAULT_TIME_LIMIT
	match_timer = addtimer(CALLBACK(src, PROC_REF(on_time_limit)), time_limit, TIMER_STOPPABLE)
	if(mode.arena_events)
		arena_scheduler = new(src)
	mode.on_match_start()
	modifier?.on_match_start()
	if(book)
		book.close_book()
		if(book.total_pool)
			site.venue_message(span_boldannounce("The book is CLOSED, [book.total_pool] credits ride on this match!"))
	site.broadcast_galaxy("The gates are OPEN, [mode.name] has begun at the Grand Colosseum! [length(live_entries())] contestants. Time limit: [DisplayTimeText(time_limit)].")
	log_game("COLOSSEUM: match live, [mode.name], [length(live_entries())] contestants.")
	// A death during the countdown can already have decided things
	check_victory()

/// Restarts the match clock (tournament rounds re-arm it between rounds).
/datum/colosseum_controller/proc/restart_match_timer(duration)
	stop_match_timer()
	match_timer = addtimer(CALLBACK(src, PROC_REF(on_time_limit)), duration || COLOSSEUM_DEFAULT_TIME_LIMIT, TIMER_STOPPABLE)

// ===== CONTESTANT TRACKING (signal-driven, no polling) =====

/// Hooks elimination signals onto a contestant's current body.
/datum/colosseum_controller/proc/track_contestant(datum/colosseum_contestant/entry)
	var/mob/living/body = entry.mind?.current
	if(!isliving(body))
		return
	entry.body = body
	RegisterSignal(body, COMSIG_LIVING_DEATH, PROC_REF(on_contestant_death))
	RegisterSignal(body, COMSIG_QDELETING, PROC_REF(on_contestant_deleted))
	RegisterSignal(body, COMSIG_MOB_LOGOUT, PROC_REF(on_contestant_logout))
	RegisterSignal(body, COMSIG_MOB_LOGIN, PROC_REF(on_contestant_login))
	body.become_area_sensitive(COLOSSEUM_TRAIT)
	RegisterSignal(body, COMSIG_ENTER_AREA, PROC_REF(on_contestant_area_change))

/// Removes all tracking from a contestant's body.
/datum/colosseum_controller/proc/untrack_contestant(datum/colosseum_contestant/entry)
	if(entry.disconnect_timer)
		deltimer(entry.disconnect_timer)
		entry.disconnect_timer = null
	var/mob/living/body = entry.body
	if(QDELETED(body))
		entry.body = null
		return
	UnregisterSignal(body, list(COMSIG_LIVING_DEATH, COMSIG_QDELETING, COMSIG_MOB_LOGOUT, COMSIG_MOB_LOGIN, COMSIG_ENTER_AREA))
	body.lose_area_sensitivity(COLOSSEUM_TRAIT)
	entry.body = null

/// Roster entry whose tracked body is the given mob, or null.
/datum/colosseum_controller/proc/entry_for_body(mob/body)
	for(var/datum/colosseum_contestant/entry as anything in roster)
		if(entry.body == body)
			return entry
	return null

/datum/colosseum_controller/proc/on_contestant_death(mob/living/source, gibbed)
	SIGNAL_HANDLER
	var/datum/colosseum_contestant/entry = entry_for_body(source)
	if(entry)
		eliminate(entry, COLOSSEUM_ELIM_DEATH)

/datum/colosseum_controller/proc/on_contestant_deleted(mob/living/source)
	SIGNAL_HANDLER
	var/datum/colosseum_contestant/entry = entry_for_body(source)
	if(!entry)
		return
	untrack_contestant(entry)
	eliminate(entry, COLOSSEUM_ELIM_DELETED)

/datum/colosseum_controller/proc/on_contestant_logout(mob/living/source)
	SIGNAL_HANDLER
	var/datum/colosseum_contestant/entry = entry_for_body(source)
	if(!entry || entry.eliminated || entry.disconnect_timer)
		return
	entry.disconnect_timer = addtimer(CALLBACK(src, PROC_REF(check_disconnect), entry), COLOSSEUM_DISCONNECT_GRACE, TIMER_STOPPABLE)

/datum/colosseum_controller/proc/on_contestant_login(mob/living/source)
	SIGNAL_HANDLER
	var/datum/colosseum_contestant/entry = entry_for_body(source)
	if(entry?.disconnect_timer)
		deltimer(entry.disconnect_timer)
		entry.disconnect_timer = null

/**
 * Disconnect grace expiry. The mind may have moved into a fresh connected body
 * (body swap fires logout on the old shell), re-sync instead of forfeiting
 * when the player is demonstrably still in the fight.
 */
/datum/colosseum_controller/proc/check_disconnect(datum/colosseum_contestant/entry)
	entry.disconnect_timer = null
	if(entry.eliminated || QDELETED(src))
		return
	var/mob/living/current_body = entry.mind?.current
	if(isliving(current_body) && current_body.client && current_body.stat != DEAD)
		if(entry.body != current_body)
			untrack_contestant(entry)
			entry.body = current_body
			track_contestant(entry)
		return
	eliminate(entry, COLOSSEUM_ELIM_DISCONNECT)

/// Auto-forfeit: leaving arena/staging during a live match is quitting the fight.
/datum/colosseum_controller/proc/on_contestant_area_change(mob/living/source, area/new_area)
	SIGNAL_HANDLER
	if(state != COLOSSEUM_STATE_LIVE)
		return
	if(istype(new_area, /area/voidcrew/colosseum/arena) || istype(new_area, /area/voidcrew/colosseum/staging))
		return
	var/datum/colosseum_contestant/entry = entry_for_body(source)
	if(entry)
		eliminate(entry, COLOSSEUM_ELIM_FLED)

/// The announcement predicate for an elimination reason ("X <phrase>!").
/// The COLOSSEUM_ELIM_* strings themselves stay terse for logs and rosters.
/datum/colosseum_controller/proc/elimination_phrase(reason)
	switch(reason)
		if(COLOSSEUM_ELIM_DEATH)
			return "has been slain"
		if(COLOSSEUM_ELIM_DELETED)
			return "has vanished"
		if(COLOSSEUM_ELIM_DISCONNECT)
			return "has abandoned the match"
		if(COLOSSEUM_ELIM_FLED)
			return "has fled the arena"
		if(COLOSSEUM_ELIM_CUT)
			return "has been cut from the bracket"
	return "is out of the running"

/**
 * Knocks a contestant out of the running and lets the mode react. The corpse
 * (if any) stays where it fell, the end-of-match sweep collects it.
 */
/datum/colosseum_controller/proc/eliminate(datum/colosseum_contestant/entry, reason)
	if(entry.eliminated)
		return
	entry.eliminated = TRUE
	entry.elimination_reason = reason
	if(entry.disconnect_timer)
		deltimer(entry.disconnect_timer)
		entry.disconnect_timer = null
	if(state == COLOSSEUM_STATE_SEATING)
		book?.scratch(entry.mind) // out before the gates ever opened: backers refund
	site.venue_message(span_boldannounce("[entry.display_name] ([entry.ship_name]) [elimination_phrase(reason)]! [length(live_entries())] remain[length(live_entries()) == 1 ? "s" : ""]."))
	log_game("COLOSSEUM: [entry.ckey] eliminated ([reason]).")
	if(state == COLOSSEUM_STATE_LIVE)
		mode?.on_elimination(entry)
		check_victory()

/// Asks the mode whether the match is decided; resolves if so.
/datum/colosseum_controller/proc/check_victory()
	if(state != COLOSSEUM_STATE_LIVE || !mode)
		return
	var/list/winners = mode.check_victory()
	if(islist(winners))
		resolve(winners)

/// Match clock expiry: the mode names winners (possibly none, a draw).
/datum/colosseum_controller/proc/on_time_limit()
	match_timer = null
	if(state != COLOSSEUM_STATE_LIVE || !mode)
		return
	if(mode.on_time_expiry())
		return // mode handled it internally (tournament round cuts)
	resolve(mode.expiry_winners())

// ===== RESOLUTION =====

/**
 * LIVE -> RESOLVED. Announces winners, opens every gate so the floor drains,
 * sweeps the arena into the spoils vault, banks the prize pool and starts the
 * claim window + reset timers.
 */
/datum/colosseum_controller/proc/resolve(list/datum/mind/winners)
	if(state != COLOSSEUM_STATE_LIVE)
		return
	stop_match_timer()
	stop_phase_timer()
	QDEL_NULL(arena_scheduler) // also restores any live hazard patches
	set_state(COLOSSEUM_STATE_RESOLVED)
	matches_run++

	winner_minds = list()
	var/list/winner_names = list()
	for(var/datum/mind/winner as anything in winners)
		winner_minds[winner] = TRUE
		var/datum/colosseum_contestant/entry = entry_for_mind(winner)
		winner_names += entry ? "[entry.display_name] ([entry.ship_name])" : (winner.current?.real_name || winner.key)

	mode.on_match_end()
	// Modifier cleanup + bonus payouts land before the sweep and claim window
	if(modifier?.started)
		modifier.on_match_end()
	QDEL_NULL(modifier)
	settle_book(winners)

	if(length(winner_names))
		site.broadcast_galaxy("The match is DECIDED! Winner[length(winner_names) > 1 ? "s" : ""] of the [mode.name]: [english_list(winner_names)]. Their prizes are in the spoils vault. The claim window closes in [DisplayTimeText(COLOSSEUM_CLAIM_WINDOW)].")
	else
		site.broadcast_galaxy("The [mode.name] ends in a draw. The spoils vault is open to anyone who walks in.")
	log_game("COLOSSEUM: match resolved, winners: [length(winner_names) ? english_list(winner_names) : "none"].")

	// Open everything: winners and stragglers walk off the floor while the
	// wardens sweep. Gates return to idle posture at RESET.
	for(var/gate_id in list(COLOSSEUM_GATE_RED, COLOSSEUM_GATE_BLUE, COLOSSEUM_GATE_SOLO, COLOSSEUM_SEAL))
		site.set_gates(gate_id, TRUE)

	sweep_arena()
	award_prizes(length(roster))
	// The games end, the convoy lands: the concourse gear stall restocks
	site.restock_armory()

	claim_until = world.time + COLOSSEUM_CLAIM_WINDOW
	site.secure_vault_chamber()
	site.spoils_vault?.on_match_resolved()
	// A previous window's timer would otherwise fire inside this one and close it early
	if(claim_timer)
		deltimer(claim_timer)
	claim_timer = addtimer(CALLBACK(src, PROC_REF(end_claim_window)), COLOSSEUM_CLAIM_WINDOW, TIMER_STOPPABLE)

	phase_timer = addtimer(CALLBACK(src, PROC_REF(do_reset)), 15 SECONDS, TIMER_STOPPABLE)

/**
 * Moves every corpse and loose item on the fighting floor into the spoils
 * vault. Living eliminated stragglers get carried to the infirmary instead.
 * Winners standing on the sand are left alone.
 */
/datum/colosseum_controller/proc/sweep_arena()
	var/obj/machinery/colosseum_vault/vault = site.spoils_vault
	var/list/infirmary = site.get_infirmary_turfs()
	var/swept = 0
	for(var/turf/arena_turf as anything in site.get_area_turfs_cached(/area/voidcrew/colosseum/arena))
		for(var/atom/movable/thing as anything in arena_turf.contents.Copy())
			if(isobserver(thing) || istype(thing, /obj/effect/landmark))
				continue
			if(isliving(thing))
				var/mob/living/casualty = thing
				if(!casualty.mind && !casualty.client)
					qdel(casualty) // stray beasts and carcasses get dragged back to the undercroft
					continue
				if(casualty.stat == DEAD)
					if(vault)
						casualty.forceMove(vault)
						swept++
					continue
				if(winner_minds[casualty.mind])
					continue
				var/datum/colosseum_contestant/entry = casualty.mind ? entry_for_mind(casualty.mind) : null
				if(state == COLOSSEUM_STATE_LIVE && entry && !entry.eliminated)
					continue // mid-tournament turnaround: still in the fight, leave them be
				if(length(infirmary))
					casualty.forceMove(pick(infirmary))
					to_chat(casualty, span_notice("Colosseum stretcher-bearers carry you off the sand to the infirmary."))
				continue
			if(istype(thing, /obj/structure/closet) && vault)
				// Crates don't get to keep their loot: the reset would delete the
				// weapons inside along with the crate, and the fiction says
				// everything that falls on the sand ends up in the vault.
				var/obj/structure/closet/box = thing
				for(var/obj/item/loot in box.contents.Copy())
					loot.forceMove(vault)
					swept++
				continue
			if(isitem(thing) && !thing.anchored && vault)
				thing.forceMove(vault)
				swept++
	log_game("COLOSSEUM: swept [swept] corpses/items into the spoils vault.")

/**
 * Banks the prize pool into the spoils vault, scaled by roster size and the
 * mode's reward multiplier. Ship parts lean combat (this is the fighting
 * venue), plus credits and trade vouchers from the existing economy.
 */
/// Prize tier for a roster size: list(ship parts, credits, trade vouchers).
/datum/colosseum_controller/proc/get_prize_tier(contestant_count)
	switch(contestant_count)
		if(0 to 3)
			return list(2, 500, 0)
		if(4 to 5)
			return list(3, 1000, 1)
		if(6 to 8)
			return list(5, 2000, 2)
		else
			return list(7, 3000, 3)

/**
 * The prize pool is one pot per MATCH, split between however many minds won
 * it: a team victory deals the same parts/credits/vouchers out in equal
 * shares, one champion's extraction case per winner (parts ride in the cases
 * so they extract alongside a standard case, see extraction.dm). A draw
 * banks a single unclaimed case for whoever dares the public vault.
 */
/datum/colosseum_controller/proc/award_prizes(contestant_count)
	var/obj/machinery/colosseum_vault/vault = site.spoils_vault
	if(!vault)
		return
	var/list/tier = get_prize_tier(contestant_count)
	var/multiplier = mode?.reward_multiplier || 1
	var/parts = round(tier[1] * multiplier)
	var/credits = round(tier[2] * multiplier)
	var/vouchers = round(tier[3] * multiplier)
	var/shares = max(1, length(winner_minds))

	var/list/obj/item/storage/briefcase/secure/extraction/tournament/cases = list()
	for(var/i in 1 to shares)
		cases += new /obj/item/storage/briefcase/secure/extraction/tournament(vault)

	var/static/list/part_weights = list(
		/obj/item/ship_parts/combat = 55,
		/obj/item/ship_parts/science = 15,
		/obj/item/ship_parts/trade = 15,
		/obj/item/ship_parts/misc = 15,
	)
	for(var/i in 1 to parts)
		var/part_type = pick_weight(part_weights)
		new part_type(cases[((i - 1) % shares) + 1])
	for(var/i in 1 to shares)
		var/credit_share = round(credits / shares) + (i <= (credits % shares) ? 1 : 0)
		if(credit_share)
			new /obj/item/holochip(cases[i], credit_share)
		var/voucher_share = round(vouchers / shares) + (i <= (vouchers % shares) ? 1 : 0)
		if(voucher_share)
			new /obj/item/stack/trade_voucher(cases[i], voucher_share)

/**
 * Claim window over: the vault unlocks for everyone and the dead are laid out
 * in the infirmary for their crews to retrieve.
 */
/datum/colosseum_controller/proc/end_claim_window()
	// Safe to call early (dryrun, admin): cancels the pending expiry timer so it
	// can't fire the whole thing a second time.
	if(claim_timer)
		deltimer(claim_timer)
		claim_timer = null
	claim_until = 0
	if(QDELETED(site))
		return
	var/obj/machinery/colosseum_vault/vault = site.spoils_vault
	var/list/infirmary = site.get_infirmary_turfs()
	if(vault && length(infirmary))
		for(var/mob/living/casualty in vault.contents)
			casualty.forceMove(pick(infirmary))
	site.venue_message(span_notice("The spoils vault unlocks for the public. The fallen have been moved to the infirmary."))
	site.spoils_vault?.update_static_ui()
	site.update_status_displays() // boards drop the CLAIM countdown immediately

// ===== RESET =====

/// RESOLVED -> RESET -> IDLE. Restores the arena to its snapshot baseline.
/datum/colosseum_controller/proc/do_reset()
	if(state != COLOSSEUM_STATE_RESOLVED)
		return
	stop_phase_timer()
	set_state(COLOSSEUM_STATE_RESET)
	reset_arena()
	clear_roster()
	QDEL_NULL(mode)
	site.gates_to_idle()
	next_signup_at = world.time + COLOSSEUM_SIGNUP_COOLDOWN
	set_state(COLOSSEUM_STATE_IDLE)
	site.venue_message(span_notice("The sand is raked and the cover is restocked. The Colosseum is ready for the next match."))

/// Captures the arena floor's pristine state at first load.
/datum/colosseum_controller/proc/snapshot_arena()
	arena_baseline_turfs = list()
	arena_baseline_objects = list()
	for(var/turf/arena_turf as anything in site.get_area_turfs_cached(/area/voidcrew/colosseum/arena))
		arena_baseline_turfs[arena_turf] = arena_turf.type
		for(var/obj/fixture in arena_turf)
			if(istype(fixture, /obj/machinery) || istype(fixture, /obj/effect) || istype(fixture, /obj/docking_port))
				continue
			arena_baseline_objects += list(list(fixture.type, arena_turf, fixture.dir))
	log_game("COLOSSEUM: arena snapshot, [length(arena_baseline_turfs)] turfs, [length(arena_baseline_objects)] baseline objects.")

/**
 * Restores the arena footprint from the snapshot: relocates any straggler
 * mobs, deletes debris/blood/leftovers, reverts changed turfs and rebuilds
 * the mapped cover. Matches must be repeatable indefinitely.
 */
/datum/colosseum_controller/proc/reset_arena()
	for(var/turf/arena_turf as anything in site.get_area_turfs_cached(/area/voidcrew/colosseum/arena))
		for(var/atom/movable/thing as anything in arena_turf.contents.Copy())
			if(isobserver(thing) || istype(thing, /obj/effect/landmark) || istype(thing, /obj/docking_port))
				continue
			if(ismob(thing))
				var/mob/straggler = thing
				if(isliving(straggler) && !straggler.mind && !straggler.client)
					qdel(straggler) // leftover arena beasts don't get to tour the concourse
					continue
				if(state == COLOSSEUM_STATE_LIVE && straggler.mind)
					var/datum/colosseum_contestant/entry = entry_for_mind(straggler.mind)
					if(entry && !entry.eliminated)
						continue // mid-tournament turnaround: fighters stay on the sand
				var/turf/eject_to = site.get_random_lobby_turf()
				if(eject_to)
					straggler.forceMove(eject_to)
					if(straggler.client)
						to_chat(straggler, span_notice("The wardens usher you off the sand while the arena is reset."))
				continue
			if(istype(thing, /obj/machinery))
				continue // gates, mapped lights and cameras are venue fixtures; nothing match-spawned is machinery
			qdel(thing)
		var/baseline_type = arena_baseline_turfs?[arena_turf]
		if(baseline_type && arena_turf.type != baseline_type)
			arena_turf.ChangeTurf(baseline_type, flags = CHANGETURF_IGNORE_AIR)
	for(var/list/fixture_entry as anything in arena_baseline_objects)
		var/turf/home_turf = fixture_entry[2]
		if(QDELETED(home_turf))
			continue
		var/fixture_type = fixture_entry[1]
		var/obj/fixture = new fixture_type(home_turf)
		fixture.setDir(fixture_entry[3])

// ===== SHARED ARENA EVENT HELPERS =====
// Used by both the one-off scheduler and match modifiers.

/**
 * A clear tile for an arena event: a mapped arena_event landmark spot if one
 * is free, else random clear sand. Null only if the floor is somehow full.
 */
/datum/colosseum_controller/proc/arena_event_turf()
	var/list/marked = site.get_landmark_turfs(/obj/effect/landmark/colosseum/arena_event)
	if(length(marked))
		var/list/candidates = shuffle(marked.Copy())
		for(var/turf/spot as anything in candidates)
			if(!spot.is_blocked_turf())
				return spot
	return site.get_random_clear_turf(/area/voidcrew/colosseum/arena)

/// Telegraphed supply-pod delivery of a crate of arena weapons.
/datum/colosseum_controller/proc/drop_weapon_crate()
	var/turf/landing_turf = arena_event_turf()
	if(!landing_turf)
		return
	var/static/list/weapon_weights = list(
		/obj/item/spear = 25,
		/obj/item/knife/combat = 20,
		/obj/item/melee/baseball_bat = 20,
		/obj/item/shield/riot = 10,
		/obj/item/gun/ballistic/shotgun/doublebarrel = 10,
		/obj/item/gun/energy/laser = 10,
		/obj/item/restraints/legcuffs/beartrap = 5,
	)
	var/obj/structure/closet/crate/weapon_crate = new()
	for(var/i in 1 to rand(2, 3))
		var/weapon_type = pick_weight(weapon_weights)
		new weapon_type(weapon_crate)
	var/obj/structure/closet/supplypod/pod = new
	new /obj/effect/pod_landingzone(landing_turf, pod, weapon_crate)
	site.venue_message(span_boldannounce("The crowd roars as a weapon crate drops onto the sand!"))

/// Settles the current book (empty winners = refunds) and archives it.
/datum/colosseum_controller/proc/settle_book(list/datum/mind/winners)
	if(!book)
		return
	book.settle(winners)
	old_books += book
	book = null

// ===== PLUMBING =====

/datum/colosseum_controller/proc/set_state(new_state)
	state = new_state
	site.signup_console?.update_static_ui()
	site.spoils_vault?.update_static_ui()
	site.update_status_displays()

/datum/colosseum_controller/proc/stop_phase_timer()
	if(phase_timer)
		deltimer(phase_timer)
		phase_timer = null

/datum/colosseum_controller/proc/stop_match_timer()
	if(match_timer)
		deltimer(match_timer)
		match_timer = null

// ===== ADMIN / DEBUG VERBS =====
// These drive playtesting: force each transition without waiting on windows.

ADMIN_VERB(colosseum_control, R_ADMIN, "Colosseum Match Control", "Force the Grand Colosseum's match state machine through its transitions.", ADMIN_CATEGORY_EVENTS)
	var/obj/structure/overmap/colosseum/site = GLOB.colosseum_site
	if(!site?.controller)
		to_chat(user, span_warning("No Grand Colosseum exists this round. Use 'Spawn Grand Colosseum' first."))
		return
	var/datum/colosseum_controller/controller = site.controller
	var/list/options = list("Status")
	switch(controller.state)
		if(COLOSSEUM_STATE_IDLE)
			options += "Open Signup"
		if(COLOSSEUM_STATE_SIGNUP)
			options += list("Lock Roster Now", "Cancel Match")
		if(COLOSSEUM_STATE_SEATING)
			options += list("Close Seating Now", "Cancel Match")
		if(COLOSSEUM_STATE_LIVE)
			options += list("Force End (survivors win)", "Force End (draw)")
		if(COLOSSEUM_STATE_RESOLVED)
			options += "Reset Now"
	var/choice = tgui_input_list(user, "Colosseum state: [controller.state] | roster: [length(controller.roster)] | mode: [controller.mode ? controller.mode.name : "none"]", "Colosseum Match Control", options)
	if(!choice || !site.controller)
		return
	switch(choice)
		if("Status")
			var/list/lines = list("State: [controller.state], matches run: [controller.matches_run]")
			for(var/datum/colosseum_contestant/entry as anything in controller.roster)
				lines += "- [entry.display_name] ([entry.ckey], [entry.ship_name]) team=[entry.team] [entry.eliminated ? "OUT ([entry.elimination_reason])" : "in"]"
			to_chat(user, span_notice(jointext(lines, "\n")))
			return
		if("Open Signup")
			controller.open_signup(user, forced = TRUE)
		if("Lock Roster Now")
			controller.lock_roster()
		if("Close Seating Now")
			controller.close_seating()
		if("Cancel Match")
			controller.fizzle("The match has been called off by the Master of Games.")
		if("Force End (survivors win)")
			var/list/winners = list()
			for(var/datum/colosseum_contestant/entry as anything in controller.live_entries())
				winners += entry.mind
			controller.resolve(winners)
		if("Force End (draw)")
			controller.resolve(list())
		if("Reset Now")
			controller.do_reset()
	message_admins("[key_name_admin(user)] used Colosseum Match Control: [choice].")
	log_admin("[key_name(user)] used Colosseum Match Control: [choice].")
	BLACKBOX_LOG_ADMIN_VERB("Colosseum Match Control")
