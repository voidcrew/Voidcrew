// Package: P3 heat. The vent controls and the vent bar a venting player sees.
// A vent starts by using the Furnace in hand, and the tap is the next fire attempt or use in hand (plasma_heat.dm).
// The keybinding has no default key ("V" is the cyberware wheel); players can bind it to start and tap.
// The bar is two images on the venting player's mob, shown only to their client, over their head like a do_after
// bar. The marker's sweep is animated on the client; the tap is judged on the server against vent_started_at (plasma_heat.dm), so the
// grace zones are the latency slack.

/// Pixels the marker slides each way from its resting column (the gold's middle) to the bar's end columns.
/// The bar is 19 px inside, one per unit, so the marker is within half a pixel of the unit the tap is judged in.
#define PLASMA_VENT_MARKER_REACH 9
/// Bar strip pixel_z over a standing body: the art's bottom row (4 px up the strip) sits at the top of the tile, like a do_after bar
#define PLASMA_VENT_BAR_HEAD 28
/// Rise per do_after bar shown on the venter, so the vent bar sits over them
#define PLASMA_VENT_BAR_STACK 8
/// Drop when the venter lies down, on top of the body's own lying offset
#define PLASMA_VENT_BAR_LYING_DROP 4

/datum/keybinding/living/plasma_vent
	hotkey_keys = list("Unbound")
	name = "plasma_vent"
	full_name = "Vent held gun"
	description = "Vent the heat from the Furnace in your hand."
	keybind_signal = COMSIG_KB_LIVING_PLASMA_VENT_DOWN

/datum/keybinding/living/plasma_vent/down(client/user, turf/target)
	. = ..()
	if(.)
		return
	return plasma_vent_held_gun(user.mob)

/// The vent keybinding: starts a vent on the plasma gun in `owner`'s active hand, or taps the one running
/proc/plasma_vent_held_gun(mob/living/owner)
	var/obj/item/gun/energy/plasma_weapon/gun = owner.get_active_held_item()
	if(!istype(gun))
		return FALSE
	return gun.vent_key(owner)

/// Makes the bar and, if `user` has a client, shows it over their head and starts the marker's sweep
/obj/item/gun/energy/plasma_weapon/proc/show_vent_bar(mob/living/user)
	hide_vent_bar()
	vent_bar = make_vent_bar_image(user, "bar", 1)
	vent_marker = make_vent_bar_image(user, "marker", 2)
	// The marker slides by transform; an animated pixel_x left it still in a live client
	vent_marker.transform = matrix(1, 0, -PLASMA_VENT_MARKER_REACH, 0, 1, 0)
	place_vent_bar(user)
	RegisterSignals(user, list(COMSIG_DO_AFTER_BEGAN, COMSIG_LIVING_SET_BODY_POSITION), PROC_REF(on_vent_bar_moved))
	RegisterSignal(user, COMSIG_DO_AFTER_ENDED, PROC_REF(on_vent_user_do_after_ended))
	vent_client = user.client
	if(!vent_client)
		return
	vent_client.images += vent_bar
	vent_client.images += vent_marker
	animate(vent_marker, transform = matrix(1, 0, PLASMA_VENT_MARKER_REACH, 0, 1, 0), time = PLASMA_VENT_SWEEP, easing = LINEAR_EASING)

/// One part of the bar, drawn on `user` like a do_after bar: it walks with them and ignores their turn when they lie down
/obj/item/gun/energy/plasma_weapon/proc/make_vent_bar_image(mob/living/user, state, part_layer)
	var/image/part = image('voidcrew/modules/plasma_weapons/icons/vent_bar.dmi', user, state)
	SET_PLANE_EXPLICIT(part, ABOVE_HUD_PLANE, user)
	part.layer = part_layer
	// PIXEL_SCALE keeps the one-pixel marker sharp while it slides between whole pixels
	part.appearance_flags = APPEARANCE_UI_IGNORE_ALPHA | RESET_TRANSFORM | KEEP_APART | PIXEL_SCALE
	part.mouse_opacity = MOUSE_OPACITY_TRANSPARENT
	// The 32 px strip lines up with the 32 px body
	part.pixel_x = user.get_oversized_icon_offsets()["x"]
	return part

/// Pixels above `user`'s base where the bar's strip goes: over the head, and over any do_after bars on them
/obj/item/gun/energy/plasma_weapon/proc/vent_bar_height(mob/living/user)
	var/height = PLASMA_VENT_BAR_HEAD + user.get_oversized_icon_offsets()["y"]
	var/list/own_bars = LAZYACCESS(user.progressbars, user)
	height += PLASMA_VENT_BAR_STACK * LAZYLEN(own_bars)
	if(user.body_position == LYING_DOWN)
		height -= PLASMA_VENT_BAR_LYING_DROP
	return height

/// Moves the bar to its height. The marker's slide keeps running.
/obj/item/gun/energy/plasma_weapon/proc/place_vent_bar(mob/living/user, time = 0)
	if(!vent_bar || QDELETED(user))
		return
	var/height = vent_bar_height(user)
	if(!time)
		vent_bar.pixel_z = height
		vent_marker.pixel_z = height
		return
	animate(vent_bar, pixel_z = height, time = time, easing = SINE_EASING)
	animate(vent_marker, pixel_z = height, time = time, easing = SINE_EASING, flags = ANIMATION_PARALLEL)

/obj/item/gun/energy/plasma_weapon/proc/on_vent_bar_moved(mob/living/source)
	SIGNAL_HANDLER
	place_vent_bar(source, 2)

/// A do_after bar fades out for a moment after its do_after ends, so the vent bar drops once it has gone
/obj/item/gun/energy/plasma_weapon/proc/on_vent_user_do_after_ended(mob/living/source)
	SIGNAL_HANDLER
	addtimer(CALLBACK(src, PROC_REF(place_vent_bar_for_venter)), 0.6 SECONDS, TIMER_DELETE_ME)

/obj/item/gun/energy/plasma_weapon/proc/place_vent_bar_for_venter()
	if(vent_user)
		place_vent_bar(vent_user, 2)

/// Takes the bar off the client it was shown to and drops it
/obj/item/gun/energy/plasma_weapon/proc/hide_vent_bar()
	if(vent_client)
		vent_client.images -= vent_bar
		vent_client.images -= vent_marker
		vent_client = null
	if(vent_bar?.loc)
		UnregisterSignal(vent_bar.loc, list(COMSIG_DO_AFTER_BEGAN, COMSIG_DO_AFTER_ENDED, COMSIG_LIVING_SET_BODY_POSITION))
	vent_bar = null
	vent_marker = null

#undef PLASMA_VENT_MARKER_REACH
#undef PLASMA_VENT_BAR_HEAD
#undef PLASMA_VENT_BAR_STACK
#undef PLASMA_VENT_BAR_LYING_DROP
