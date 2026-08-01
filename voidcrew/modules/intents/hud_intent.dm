// Intent selector HUD element
// Classic SS13 4-quadrant intent selector

/// The intent selector screen object
/// Layout:
/// ┌─────┬─────┐
/// │ Help│Disarm│
/// ├─────┼─────┤
/// │ Harm│ Grab │
/// └─────┴─────┘
/atom/movable/screen/intent_selector
	name = "intent selector"
	icon = 'icons/obj/toys/intents.dmi'
	icon_state = "help"
	// upstream renamed ui_combat_toggle -> ui_acti; same "EAST-3:24,SOUTH:5" coordinates
	screen_loc = ui_acti
	mouse_over_pointer = MOUSE_HAND_POINTER
	/// Reference to the intent component
	var/datum/component/intents/intent_component
	/// When recovering from minimizing our HUD, this is where we'll be set to. Set in Initialize.
	/// We sit at the HUD_MOB_INTENTS key in place of the combat toggle, and show_hud() reads this
	/// var off whatever object occupies that key -- so it has to exist here too or show_hud() runtimes.
	var/default_screen_location

/atom/movable/screen/intent_selector/Initialize(mapload, datum/hud/hud_owner, default_screen_location)
	. = ..()
	update_appearance()
	if(default_screen_location)
		screen_loc = default_screen_location
	src.default_screen_location = screen_loc

/atom/movable/screen/intent_selector/Destroy()
	intent_component = null
	return ..()

/atom/movable/screen/intent_selector/Click(location, control, params)
	if(!isliving(usr))
		return TRUE

	var/list/modifiers = params2list(params)
	var/icon_x = text2num(LAZYACCESS(modifiers, ICON_X))
	var/icon_y = text2num(LAZYACCESS(modifiers, ICON_Y))

	// Determine which quadrant was clicked
	var/new_intent
	if(icon_y > 16)
		// Top row
		if(icon_x < 16)
			new_intent = INTENT_HELP // Top-left
		else
			new_intent = INTENT_DISARM // Top-right
	else
		// Bottom row
		if(icon_x < 16)
			new_intent = INTENT_HARM // Bottom-left
		else
			new_intent = INTENT_GRAB // Bottom-right

	if(intent_component)
		intent_component.set_intent(new_intent)

	return TRUE

/atom/movable/screen/intent_selector/update_icon_state()
	. = ..()
	if(!intent_component)
		icon_state = "help"
		return
	// Icon states match intent names directly
	icon_state = intent_component.current_intent
