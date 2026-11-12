// Tutorial checklist: the HUD outline for "Open Ship Management".
// The Ship Management action button is a per-HUD screen object, so a filter on it is seen only
// by its owner (and anyone observing that HUD). Must be included after tutorial_highlights.dm:
// an override placed before the proc it chains onto never runs.

#define TUTORIAL_HUD_FILTER "tutorial_hud_outline"

/datum/tutorial_highlight
	/// Weakrefs to the HUD screen objects we outlined.
	var/list/hud_outlined = list()

/datum/tutorial_highlight/rebuild(mob/user)
	. = ..()
	if(QDELETED(src))
		return
	set_hud_outline(tutorial_ship_manage_buttons(viewer))

/datum/tutorial_highlight/Destroy()
	set_hud_outline(list())
	return ..()

/// Outlines exactly these screen objects, taking the outline off any others.
/datum/tutorial_highlight/proc/set_hud_outline(list/new_targets)
	for(var/datum/weakref/old_ref as anything in hud_outlined)
		var/atom/movable/screen/old_target = old_ref.resolve()
		if(old_target && !(old_target in new_targets))
			old_target.remove_filter(TUTORIAL_HUD_FILTER)
	hud_outlined = list()
	for(var/atom/movable/screen/target as anything in new_targets)
		if(!target.get_filter(TUTORIAL_HUD_FILTER))
			target.add_filter(TUTORIAL_HUD_FILTER, 10, outline_filter(1, "#FFC83C"))
			// Pulses in step with the world outlines.
			var/hud_filter = target.get_filter(TUTORIAL_HUD_FILTER)
			animate(hud_filter, color = "#8A5A10", time = 0.8 SECONDS, loop = -1, easing = SINE_EASING)
			animate(color = "#FFC83C", time = 0.8 SECONDS, easing = SINE_EASING)
		hud_outlined += WEAKREF(target)

/**
 * The viewer's Ship Management button (and the palette toggle when the button sits in the
 * collapsed palette) while "Open Ship Management" is the undone step of their open item.
 */
/proc/tutorial_ship_manage_buttons(mob/user)
	var/datum/hud/hud = user?.hud_used
	if(!hud)
		return list()
	var/ckey = tutorial_viewer_ckey(user)
	if(!ckey || SSvc_tutorials.has_key(ckey, TUTORIAL_STEP_SHIP_MANAGE))
		return list()
	var/datum/vc_tutorial/item = tutorial_open_item(user)
	if(item?.id != TUTORIAL_ITEM_SHIP)
		return list()
	var/datum/vc_tutorial_step/step = SSvc_tutorials.steps_by_key?[TUTORIAL_STEP_SHIP_MANAGE]
	if(!step || step.excused(user))
		return list()
	var/list/buttons = list()
	for(var/datum/action/innate/captain_management/action in user.actions)
		var/atom/movable/screen/movable/action_button/button = action.viewers[hud]
		if(!button)
			continue
		buttons += button
		if(button.location == SCRN_OBJ_IN_PALETTE && hud.toggle_palette)
			buttons |= hud.toggle_palette
	return buttons

#undef TUTORIAL_HUD_FILTER
