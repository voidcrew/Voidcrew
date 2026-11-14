// Package: P3 heat. The vent key and the vent bar a venting player sees.
// The bar is two screen objects shown only to the venting player's client, above the hands. The marker's sweep
// is animated on the client; the tap is judged on the server against vent_started_at (plasma_heat.dm), so the
// grace zones are the latency slack.

/// Pixels from the marker's resting x (the bar's middle) to the bar's left and right inner edges
#define PLASMA_VENT_MARKER_REACH 38

/datum/keybinding/living/plasma_vent
	hotkey_keys = list("V")
	name = "plasma_vent"
	full_name = "Vent held gun"
	description = "Vent the heat from the Furnace in your hand."
	keybind_signal = COMSIG_KB_LIVING_PLASMA_VENT_DOWN

/datum/keybinding/living/plasma_vent/down(client/user, turf/target)
	. = ..()
	if(.)
		return
	var/mob/living/owner = user.mob
	var/obj/item/gun/energy/plasma_weapon/gun = owner.get_active_held_item()
	if(!istype(gun))
		return FALSE
	return gun.vent_key(owner)

/atom/movable/screen/plasma_vent_bar
	name = "vent"
	icon = 'voidcrew/modules/plasma_weapons/icons/vent_bar.dmi'
	icon_state = "bar"
	// Above the swap-hand buttons, centred on the hands
	screen_loc = "CENTER-1,SOUTH+2:4"
	mouse_opacity = MOUSE_OPACITY_TRANSPARENT
	// show_hud() clears the screen on every lie-down; the bar stays until its vent ends
	clear_with_screen = FALSE

/atom/movable/screen/plasma_vent_marker
	name = "vent"
	icon = 'voidcrew/modules/plasma_weapons/icons/vent_bar.dmi'
	icon_state = "marker"
	screen_loc = "CENTER-1,SOUTH+2:4"
	plane = ABOVE_HUD_PLANE
	mouse_opacity = MOUSE_OPACITY_TRANSPARENT
	clear_with_screen = FALSE

/// Makes the bar and, if `user` has a client, shows it and starts the marker's sweep
/obj/item/gun/energy/plasma_weapon/proc/show_vent_bar(mob/living/user)
	hide_vent_bar()
	vent_bar = new
	vent_marker = new
	// The marker slides by transform; an animated pixel_x left it still in a live client
	vent_marker.transform = matrix(1, 0, -PLASMA_VENT_MARKER_REACH, 0, 1, 0)
	vent_client = user.client
	if(!vent_client)
		return
	vent_client.screen += vent_bar
	vent_client.screen += vent_marker
	animate(vent_marker, transform = matrix(1, 0, PLASMA_VENT_MARKER_REACH, 0, 1, 0), time = PLASMA_VENT_SWEEP, easing = LINEAR_EASING)

/// Takes the bar off the screen it was shown on and deletes it
/obj/item/gun/energy/plasma_weapon/proc/hide_vent_bar()
	if(vent_client)
		vent_client.screen -= vent_bar
		vent_client.screen -= vent_marker
		vent_client = null
	QDEL_NULL(vent_bar)
	QDEL_NULL(vent_marker)

#undef PLASMA_VENT_MARKER_REACH
