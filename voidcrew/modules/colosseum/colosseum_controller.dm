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
 * * SEATING -> LIVE: the seating timer — absentees are dropped, non-contestants
 *   ejected from staging, the rear seals close, contestants are seated, and
 *   after a short countdown the mode's gates pop. Fizzles to IDLE if the
 *   survivors no longer satisfy the mode's minimum.
 * * LIVE -> RESOLVED: win detection — death/deletion signals on contestants,
 *   disconnect grace timers, area-sensitivity forfeits, mode victory checks,
 *   or the match time limit.
 * * RESOLVED -> RESET -> IDLE: automatic timers. The spoils claim window runs
 *   on its own parallel track and never blocks the next match.
 *
 * All contestant tracking is signal-driven (no polling); modes that need a
 * clock (king of the hill) opt into SSprocessing for the LIVE phase only.
 */

/// One registered contestant. Keyed by mind — bodies can change, minds don't.
/datum/colosseum_contestant
	/// The registered mind
	var/datum/mind/mind
	/// ckey at signup, for rosters and logs
	var/ckey
	/// Contestant display name (mob name at signup)
	var/display_name
	/// Ship affiliation recorded at signup ("Unaffiliated" if none)
	var/ship_name = "Unaffiliated"
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

/datum/colosseum_contestant/Destroy()
	if(disconnect_timer)
		deltimer(disconnect_timer)
		disconnect_timer = null
	mind = null
	body = null
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
	/// world.time the next signup may open (post-match cooldown)
	var/next_signup_at = 0
	/// Winning minds of the last resolved match (assoc mind -> TRUE)
	var/list/winner_minds = list()
	/// world.time the winners-only spoils claim window ends
	var/claim_until = 0
	/// Dynamic arena event scheduler, running only while a match that wants it is LIVE
	var/datum/colosseum_arena_scheduler/arena_scheduler
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
	QDEL_NULL(arena_scheduler)
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
		fizzle("Registration closed with too few contestants. The Master of Games sighs. Another day, perhaps.")
		return

	mode = pick_mode()
	if(!mode)
		fizzle("No suitable game could be arranged for [length(roster)] contestants.")
		return
	mode.controller = src
	mode.assign_teams(roster)

	set_state(COLOSSEUM_STATE_SEATING)
	for(var/datum/colosseum_contestant/entry as anything in roster)
		track_contestant(entry)
	phase_timer = addtimer(CALLBACK(src, PROC_REF(close_seating)), COLOSSEUM_SEATING_DURATION, TIMER_STOPPABLE)
	site.broadcast_galaxy("The roster is LOCKED: [length(roster)] contestants. Tonight's game: [mode.name]. Stakes: [mode.stakes_text(length(roster))]. Contestants, report to the staging halls — the seals close in [DisplayTimeText(COLOSSEUM_SEATING_DURATION)].")
	log_game("COLOSSEUM: roster locked with [length(roster)] contestants, mode [mode.name].")

/// Weighted-random mode eligible for the roster size.
/datum/colosseum_controller/proc/pick_mode()
	var/list/eligible = list()
	var/n = length(roster)
	for(var/mode_type in subtypesof(/datum/colosseum_game))
		var/datum/colosseum_game/candidate = mode_type
		if(!initial(candidate.name)) // abstract bases
			continue
		if(n < initial(candidate.min_players) || n > initial(candidate.max_players))
			continue
		eligible[mode_type] = initial(candidate.weight)
	var/chosen_type = pick_weight(eligible)
	return chosen_type ? new chosen_type : null

/// Any-state failure exit back to IDLE, with an announcement.
/datum/colosseum_controller/proc/fizzle(message)
	site.broadcast_galaxy(message)
	stop_phase_timer()
	stop_match_timer()
	QDEL_NULL(arena_scheduler)
	clear_roster()
	QDEL_NULL(mode)
	site.gates_to_idle()
	next_signup_at = world.time + COLOSSEUM_SIGNUP_COOLDOWN
	set_state(COLOSSEUM_STATE_IDLE)

// ===== SEATING =====

/**
 * SEATING -> LIVE. Drops absentees, ejects gatecrashers, seals staging, seats
 * everyone in their mode-assigned positions and starts the gate countdown.
 */
/datum/colosseum_controller/proc/close_seating()
	if(state != COLOSSEUM_STATE_SEATING)
		return
	stop_phase_timer()

	// Re-sync bodies (people swap bodies, get borged, etc.) and drop anyone
	// not physically in staging. Dead contestants count as absent.
	for(var/datum/colosseum_contestant/entry as anything in roster.Copy())
		var/mob/living/current_body = entry.mind?.current
		if(!isliving(current_body) || current_body.stat == DEAD || !istype(get_area(current_body), /area/voidcrew/colosseum/staging))
			site.venue_message(span_warning("<b>[entry.display_name]</b> failed to report to staging and is struck from the roster."))
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
				to_chat(loiterer, span_warning("Colosseum wardens haul you out of the staging halls — contestants only past this point."))

	if(length(live_entries()) < mode.min_players)
		fizzle("Too many no-shows — the [mode.name] match is called off.")
		return

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
	site.broadcast_galaxy("The gates are OPEN — [mode.name] has begun at the Grand Colosseum! [length(live_entries())] contestants. Time limit: [DisplayTimeText(time_limit)].")
	log_game("COLOSSEUM: match live — [mode.name], [length(live_entries())] contestants.")
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
 * (body swap fires logout on the old shell) — re-sync instead of forfeiting
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

/**
 * Knocks a contestant out of the running and lets the mode react. The corpse
 * (if any) stays where it fell — the end-of-match sweep collects it.
 */
/datum/colosseum_controller/proc/eliminate(datum/colosseum_contestant/entry, reason)
	if(entry.eliminated)
		return
	entry.eliminated = TRUE
	entry.elimination_reason = reason
	if(entry.disconnect_timer)
		deltimer(entry.disconnect_timer)
		entry.disconnect_timer = null
	site.venue_message(span_boldannounce("[entry.display_name] ([entry.ship_name]) has been [reason]! [length(live_entries())] remain[length(live_entries()) == 1 ? "s" : ""]."))
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

/// Match clock expiry: the mode names winners (possibly none — a draw).
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

	if(length(winner_names))
		site.broadcast_galaxy("The match is DECIDED! Victor[length(winner_names) > 1 ? "s" : ""] of the [mode.name]: [english_list(winner_names)]. Spoils and prizes await them in the vault — the claim window closes in [DisplayTimeText(COLOSSEUM_CLAIM_WINDOW)].")
	else
		site.broadcast_galaxy("The [mode.name] ends without a victor. The spoils vault opens to anyone bold enough to walk in.")
	log_game("COLOSSEUM: match resolved — winners: [length(winner_names) ? english_list(winner_names) : "none"].")

	// Open everything: winners and stragglers walk off the floor while the
	// wardens sweep. Gates return to idle posture at RESET.
	for(var/gate_id in list(COLOSSEUM_GATE_RED, COLOSSEUM_GATE_BLUE, COLOSSEUM_GATE_SOLO, COLOSSEUM_SEAL))
		site.set_gates(gate_id, TRUE)

	sweep_arena()
	award_prizes(length(roster))

	claim_until = world.time + COLOSSEUM_CLAIM_WINDOW
	site.spoils_vault?.on_match_resolved()
	addtimer(CALLBACK(src, PROC_REF(end_claim_window)), COLOSSEUM_CLAIM_WINDOW, TIMER_STOPPABLE)

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
				if(casualty.stat == DEAD)
					if(vault)
						casualty.forceMove(vault)
						swept++
				else if(!winner_minds[casualty.mind] && length(infirmary))
					casualty.forceMove(pick(infirmary))
					to_chat(casualty, span_notice("Colosseum stretcher-bearers carry you off the sand to the infirmary."))
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

/datum/colosseum_controller/proc/award_prizes(contestant_count)
	var/obj/machinery/colosseum_vault/vault = site.spoils_vault
	if(!vault)
		return
	var/list/tier = get_prize_tier(contestant_count)
	var/multiplier = mode?.reward_multiplier || 1
	var/parts = round(tier[1] * multiplier)
	var/credits = round(tier[2] * multiplier)
	var/vouchers = round(tier[3] * multiplier)

	var/static/list/part_weights = list(
		/obj/item/ship_parts/combat = 55,
		/obj/item/ship_parts/science = 15,
		/obj/item/ship_parts/trade = 15,
		/obj/item/ship_parts/misc = 15,
	)
	for(var/i in 1 to parts)
		var/part_type = pick_weight(part_weights)
		new part_type(vault)
	if(credits)
		new /obj/item/holochip(vault, credits)
	if(vouchers)
		new /obj/item/stack/trade_voucher(vault, vouchers)

/**
 * Claim window over: the vault unlocks for everyone and the dead are laid out
 * in the infirmary for their crews to retrieve.
 */
/datum/colosseum_controller/proc/end_claim_window()
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
	site.venue_message(span_notice("The sand is raked, the cover restocked. The Grand Colosseum stands ready for its next match."))

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
	log_game("COLOSSEUM: arena snapshot — [length(arena_baseline_turfs)] turfs, [length(arena_baseline_objects)] baseline objects.")

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
				var/turf/eject_to = site.get_random_lobby_turf()
				if(eject_to)
					thing.forceMove(eject_to)
				continue
			if(istype(thing, /obj/machinery/door))
				continue // gate poddoors stay put whatever happens
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

// ===== PLUMBING =====

/datum/colosseum_controller/proc/set_state(new_state)
	state = new_state
	site.signup_console?.update_static_ui()
	site.spoils_vault?.update_static_ui()

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
