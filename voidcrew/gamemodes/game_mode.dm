/datum/controller/subsystem/ticker/check_finished()
	if(SSovermap.jump_mode == BS_JUMP_COMPLETED)
		return TRUE
	..()
