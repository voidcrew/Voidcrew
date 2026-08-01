/// Voidcrew: a completed bluespace jump ends the round, on top of the usual endgame conditions.
/datum/controller/subsystem/ticker/check_finished()
	if(SSovermap.jump_mode == BS_JUMP_COMPLETED)
		return TRUE
	return ..()
