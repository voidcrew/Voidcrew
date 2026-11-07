/// Timed rounds defer ordinary early endings; explicit admin endings remain available.
/datum/controller/subsystem/ticker/fire()
	if(SSovermap.round_end_time && force_ending == FORCE_END_ROUND)
		force_ending = END_ROUND_AS_NORMAL
	return ..()

/// Voidcrew: a completed fleet jump ends the round through the usual completion report.
/datum/controller/subsystem/ticker/check_finished()
	if(SSovermap.jump_mode == BS_JUMP_COMPLETED)
		return TRUE
	if(SSovermap.round_end_time)
		return FALSE
	return ..()

/// The End Round verb otherwise uses the same flag as player votes and round-ending events.
/datum/admin_verb/end_round/__avd_do_verb(client/user)
	var/confirm = tgui_alert(user, "End the round and restart the game world?", "End Round", list("Yes", "Cancel"))
	if(confirm != "Yes")
		return
	SSticker.force_ending = ADMIN_FORCE_END_ROUND
	BLACKBOX_LOG_ADMIN_VERB("End Round")
