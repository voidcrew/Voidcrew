/**
 * Climbing into a mech has no signal in tg. The Rig Bay's chains and the buyer's hold
 * (rig_bay_clamp.dm) refuse entry through COMSIG_MECHA_TRY_ENTER.
 *
 * This file is included after code/, so this override chains onto the tg one.
 */
/obj/vehicle/sealed/mecha/mob_try_enter(mob/M)
	if(SEND_SIGNAL(src, COMSIG_MECHA_TRY_ENTER, M) & COMPONENT_MECHA_BLOCK_ENTER)
		return FALSE
	return ..()
