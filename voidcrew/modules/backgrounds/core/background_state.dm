/// Backgrounds: owned by P1. See data/backgrounds/spec.md.

/// The background this mind is playing, if any
/datum/mind/var/datum/background_state/background_state

/// Every mind that has had a background state this round
GLOBAL_LIST_EMPTY(background_minds)
/// ckey -> list of that player's background facts this round ("paid", "pods", "haul", "stash", "state")
GLOBAL_LIST_EMPTY(background_ledger)

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
	/// Per-package keys, each prefixed with its package ("p6_fed")
	var/list/extra = list()
	var/last_seen_site_name
	var/last_seen_zone_value
	var/last_seen_at

/datum/background_state/proc/add_progress(amount)
	progress += amount

/datum/background_state/proc/complete(line)
	if(outcome != BACKGROUND_OUTCOME_ONGOING)
		return
	outcome = BACKGROUND_OUTCOME_DONE
	outcome_line = line

/datum/background_state/proc/fail(line)
	if(outcome != BACKGROUND_OUTCOME_ONGOING)
		return
	outcome = BACKGROUND_OUTCOME_FAILED
	outcome_line = line

/// Re-adds the background memory with the current goal line
/datum/background_state/proc/refresh_memory()
	return

/// Starts a background for this mind and returns its state
/proc/background_begin(datum/mind/mind, key, scenario)
	if(!mind || !key)
		return null
	var/datum/background_state/state = new
	state.key = key
	state.ckey = mind.key ? ckey(mind.key) : null
	state.character_name = mind.current?.real_name || mind.name
	state.mind_ref = WEAKREF(mind)
	state.scenario = scenario
	state.started_at = world.time
	mind.background_state = state
	GLOB.background_minds |= mind
	return state

/// Ends this mind's background state
/proc/background_end(datum/mind/mind, outcome)
	var/datum/background_state/state = mind?.background_state
	if(!state || state.ended)
		return
	state.ended = TRUE
	if(outcome && state.outcome == BACKGROUND_OUTCOME_ONGOING)
		state.outcome = outcome

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
