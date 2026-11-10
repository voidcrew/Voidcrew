// Tutorial checklist hooks. Part B: captain management, helm and construction console hooks.
// Every override calls the parent with its exact argument list and returns its value.
// Overrides of the same proc in other files (Part C's ruin cache closet hook) chain.

/datum/captain_management_ui/ui_interact(mob/user, datum/tgui/ui)
	. = ..()
	tutorial_credit(user, TUTORIAL_STEP_SHIP_MANAGE)

/// Lockers and crates aboard a ship. Hot path: one ckey lookup once the step is done.
/obj/structure/closet/open(mob/living/user, force = FALSE, special_effects = TRUE)
	. = ..()
	if(. != TRUE || !ismob(user))
		return
	var/user_ckey = user.ckey
	if(!user_ckey || SSvc_tutorials.has_key(user_ckey, TUTORIAL_STEP_SHIP_SEARCH))
		return
	if(get_ship_from_atom(src))
		tutorial_credit(user, TUTORIAL_STEP_SHIP_SEARCH)

/// Alt-click tile search.
/datum/lootpanel/open(turf/tile)
	. = ..()
	var/mob/viewer = owner?.mob
	if(viewer)
		tutorial_credit(viewer, TUTORIAL_STEP_SHIP_SEARCH)

/// Only a course this click actually changed counts, so refused clicks (viewer helms,
/// non-crew, a busy ship) never credit a course someone else set.
/obj/machinery/computer/helm/ui_act(action, list/params, datum/tgui/ui, datum/ui_state/state)
	var/obj/structure/overmap/ship/ship_before = current_ship
	var/course_before = current_ship?.commanded_course
	var/autopilot_before = current_ship?.autopilot_engaged
	. = ..()
	if(!current_ship || current_ship != ship_before)
		return
	var/plotted = FALSE
	switch(action)
		if("change_heading", "set_course")
			plotted = current_ship.commanded_course != BURN_NONE && current_ship.commanded_course != course_before
		if("autopilot")
			plotted = current_ship.autopilot_engaged && !autopilot_before
	if(!plotted)
		return
	var/mob/pilot = ui?.user || usr
	if(ismob(pilot))
		tutorial_credit(pilot, TUTORIAL_STEP_SHIP_COURSE)

/obj/machinery/computer/camera_advanced/base_construction/ship/ui_interact(mob/user, datum/tgui/ui)
	. = ..()
	if(current_ship)
		tutorial_credit(user, TUTORIAL_STEP_SHIP_BUILD)
