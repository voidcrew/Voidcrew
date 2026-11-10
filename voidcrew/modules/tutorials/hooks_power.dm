// Tutorial checklist hooks. Part C: SMES, generator and APC hooks.
// Overrides chain with any others of the same proc; each returns the parent's value unchanged.

/obj/machinery/power/smes/ui_interact(mob/user, datum/tgui/ui)
	. = ..()
	if(user?.ckey && !SSvc_tutorials.progress[user.ckey]?[TUTORIAL_STEP_POWER_SMES] && get_ship_from_atom(src))
		tutorial_credit(user, TUTORIAL_STEP_POWER_SMES)

/obj/machinery/power/port_gen/pacman/ui_act(action, list/params, datum/tgui/ui, datum/ui_state/state)
	var/was_active = active
	. = ..()
	if(action == "toggle_power" && active && !was_active)
		tutorial_credit(ui?.user || usr, TUTORIAL_STEP_POWER_GENERATOR)

/obj/machinery/power/apc/ui_interact(mob/user, datum/tgui/ui)
	. = ..()
	if(user?.ckey && !SSvc_tutorials.progress[user.ckey]?[TUTORIAL_STEP_POWER_APC] && get_ship_from_atom(src))
		tutorial_credit(user, TUTORIAL_STEP_POWER_APC)
