/// The background this mind is playing, if any
/datum/mind/var/datum/background_state/background_state

/// Every mind that has had a background state this round
GLOBAL_LIST_EMPTY(background_minds)
/// ckey -> list of that player's background facts this round ("paid", "pods", "haul", "stash", "state")
GLOBAL_LIST_EMPTY(background_ledger)
/// Every background state this round, in the order they began. The round-end report lists these.
GLOBAL_LIST_EMPTY(background_states)

/// One life played as one background
/datum/background_state
	/// One of the BACKGROUND_* keys
	var/key
	var/ckey
	var/character_name
	var/datum/weakref/mind_ref
	/// Convict scenario, BACKGROUND_CONVICT_SCENARIO_*
	var/scenario
	/// Crime name
	var/crime
	/// Crime tier, 1 to 3
	var/crime_tier
	/// Goal key, CONVICT_GOAL_* and the like
	var/goal
	var/goal_target = 0
	var/progress = 0
	/// One of the BACKGROUND_OUTCOME_* values
	var/outcome = BACKGROUND_OUTCOME_ONGOING
	var/outcome_line
	var/started_at
	var/ended = FALSE
	var/datum/weakref/warrant_ref
	/// Per-background keys, each with a prefix of its own ("p6_fed")
	var/list/extra = list()
	var/last_seen_site_name
	var/last_seen_zone_value
	var/last_seen_at
	/// TRUE once the background_outcome metric row is written, so each state writes one
	var/outcome_recorded = FALSE

/// The background this state plays
/datum/background_state/proc/get_background()
	RETURN_TYPE(/datum/background)
	return background_by_key(key)

/// The mind playing it, or null
/datum/background_state/proc/get_mind()
	RETURN_TYPE(/datum/mind)
	return mind_ref?.resolve()

/// Adds to the goal's progress and completes it on reaching goal_target
/datum/background_state/proc/add_progress(amount)
	if(ended || outcome != BACKGROUND_OUTCOME_ONGOING || !amount)
		return
	progress += amount
	refresh_memory()
	if(goal_target > 0 && progress >= goal_target)
		complete()

/// Settles the goal as done, once. TRUE if this call settled it.
/datum/background_state/proc/complete(line)
	return settle(BACKGROUND_OUTCOME_DONE, line)

/// Settles the goal as failed, once. TRUE if this call settled it.
/datum/background_state/proc/fail(line)
	return settle(BACKGROUND_OUTCOME_FAILED, line)

/datum/background_state/proc/settle(new_outcome, line)
	PRIVATE_PROC(TRUE)
	if(ended || outcome != BACKGROUND_OUTCOME_ONGOING)
		return FALSE
	outcome = new_outcome
	outcome_line = line
	refresh_memory()
	record_outcome()
	return TRUE

/// Writes this state's one background_outcome row
/datum/background_state/proc/record_outcome()
	if(outcome_recorded)
		return
	outcome_recorded = TRUE
	background_metric("background_outcome", get_mind(), list("outcome" = outcome, "line" = outcome_line), state = src)

/// Re-adds the background memory with the current goal line. Nothing for a background with no goal line.
/datum/background_state/proc/refresh_memory()
	if(ended)
		return
	var/datum/mind/mind = get_mind()
	var/datum/background/background = get_background()
	if(!mind || !background)
		return
	var/line = background.goal_line(src)
	if(!line)
		return
	// Replaces the old memory of this type (_add_memory)
	mind.add_memory(/datum/memory/key/background, line = line)

/// The goal, re-read under IC > Memories. One line, updated in place, never used for stories.
/datum/memory/key/background
	memory_flags = MEMORY_FLAG_NOMOOD|MEMORY_FLAG_NOLOCATION|MEMORY_FLAG_NOPERSISTENCE|MEMORY_SKIP_UNCONSCIOUS|MEMORY_NO_STORY
	/// The goal line
	var/line

/datum/memory/key/background/New(
	datum/mind/memorizer_mind,
	atom/protagonist,
	atom/deuteragonist,
	atom/antagonist,
	line,
)
	src.line = line
	return ..()

/datum/memory/key/background/get_names()
	return list(line)

/datum/memory/key/background/get_starts()
	return list(line)

/// This player's ledger entry, made on first use. Null without a ckey.
/proc/background_ledger_entry(player_ckey)
	if(!player_ckey)
		return null
	var/list/entry = GLOB.background_ledger[player_ckey]
	if(!entry)
		entry = list()
		GLOB.background_ledger[player_ckey] = entry
	return entry

/// The latest state this ckey played this round, or null
/proc/background_latest_state(player_ckey)
	RETURN_TYPE(/datum/background_state)
	var/list/entry = player_ckey ? GLOB.background_ledger[player_ckey] : null
	var/datum/weakref/state_ref = entry?["state"]
	return state_ref?.resolve()

/**
 * Starts a background for this mind and returns its state.
 *
 * Call it after any ship registration: register_crewmember() wipes the mind's memories.
 * Whatever this ckey played before ends here, so a respawn can never keep two lives' goals.
 */
/proc/background_begin(datum/mind/mind, key, scenario)
	if(!mind || !key)
		return null
	var/datum/background/background = background_by_key(key)
	if(!background)
		stack_trace("background_begin() called with an unknown background key: [key]")
		return null
	var/player_ckey = mind.key ? ckey(mind.key) : null

	// The previous life of this ckey, and anything this mind still held, end now
	var/datum/background_state/previous = background_latest_state(player_ckey)
	if(previous && !previous.ended)
		previous.end_state(BACKGROUND_OUTCOME_ENDED)
	if(mind.background_state && !mind.background_state.ended)
		mind.background_state.end_state(BACKGROUND_OUTCOME_ENDED)

	var/datum/background_state/state = new
	state.key = key
	state.ckey = player_ckey
	state.character_name = mind.current?.real_name || mind.name
	state.mind_ref = WEAKREF(mind)
	state.scenario = scenario
	state.started_at = world.time
	mind.background_state = state
	GLOB.background_minds |= mind
	GLOB.background_states += state
	var/list/entry = background_ledger_entry(player_ckey)
	if(entry)
		entry["state"] = WEAKREF(state)

	background.on_started(mind, state)
	state.refresh_memory()
	var/line = background.goal_line(state)
	if(line && mind.current)
		to_chat(mind.current, boxed_message(span_notice(line)))
	background_metric("background_chosen", mind, list(
		"crime" = state.crime,
		"scenario" = state.scenario,
		"roundstart" = !SSticker.HasRoundStarted(),
	), state = state)
	log_game("[key_name(mind)] began the [background.name] background as [state.character_name].")
	return state

/// Ends this mind's background state
/proc/background_end(datum/mind/mind, outcome)
	var/datum/background_state/state = mind?.background_state
	if(!state)
		return
	state.end_state(outcome)

/**
 * Freezes the state: nothing changes it afterwards. An ongoing goal takes `outcome`
 * (BACKGROUND_OUTCOME_ENDED when none is given); a settled one keeps its result.
 */
/datum/background_state/proc/end_state(new_outcome)
	if(ended)
		return
	if(outcome == BACKGROUND_OUTCOME_ONGOING)
		outcome = new_outcome || BACKGROUND_OUTCOME_ENDED
	ended = TRUE
	record_outcome()
	var/datum/mind/mind = get_mind()
	if(mind?.background_state == src)
		mind.wipe_memory_type(/datum/memory/key/background)
	get_background()?.on_ended(mind, src)

/// Minds whose state has this key (any key when null) and has not ended
/proc/background_active_minds(key)
	var/list/minds = list()
	for(var/datum/mind/mind in GLOB.background_minds)
		var/datum/background_state/state = mind.background_state
		if(!state || state.ended)
			continue
		if(key && state.key != key)
			continue
		minds += mind
	return minds
