/**
 * The join menu's "Other starts" entries: every start the round can offer right now,
 * whatever this player's lobby preference. Each background builds its own entries.
 */
/datum/ship_join_menu/proc/background_starts_data(mob/dead/new_player/user)
	var/list/starts = list()
	for(var/key in BACKGROUND_ALL_KEYS)
		var/datum/background/background = background_by_key(key)
		if(!background)
			continue
		var/list/options = background.latejoin_options(user)
		if(length(options))
			starts += options
	return starts

/// Handles a background join menu action. TRUE when handled.
/datum/ship_join_menu/proc/background_join_act(action, list/params)
	if(action != "join_start")
		return FALSE
	var/id = params?["id"]
	if(!istext(id) || QDELETED(user))
		return TRUE
	// Everything is checked again here: the window is never the authority
	if(!SSticker.IsRoundInProgress())
		to_chat(user, span_danger("The round is either not ready, or has already finished..."))
		return TRUE
	if(SSlag_switch.measures[DISABLE_NON_OBSJOBS])
		to_chat(user, span_warning("An administrator has disabled late join spawning."))
		return TRUE
	if(user.spawning || user.spawning_ship)
		return TRUE
	var/list/entry
	for(var/list/start as anything in background_starts_data(user))
		if(start["id"] == id)
			entry = start
			break
	if(!entry)
		to_chat(user, span_warning("That ship is no longer available."))
		return TRUE
	if(entry["refusal"])
		to_chat(user, span_warning("[entry["refusal"]]."))
		return TRUE
	var/datum/background/background = background_by_key(entry["kind"])
	if(!background)
		return TRUE
	SStgui.close_uis(src)
	INVOKE_ASYNC(background, TYPE_PROC_REF(/datum/background, latejoin), user, id)
	return TRUE
