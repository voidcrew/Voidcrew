// What the Weird Route puts on its player's screen: the text box, the choice, and what's drawn over
// the world (the black, the white, the pinwheel).

/atom/movable/screen/weird_route
	icon = 'voidcrew/modules/weird_route/icons/weird_route.dmi'
	icon_state = null
	plane = HUD_PLANE
	mouse_opacity = MOUSE_OPACITY_TRANSPARENT
	appearance_flags = PIXEL_SCALE | NO_CLIENT_COLOR
	/// The route this is for: clicks go to it.
	var/datum/weird_route/route

/atom/movable/screen/weird_route/Initialize(mapload, datum/hud/hud_owner, datum/weird_route/route)
	. = ..()
	src.route = route

/atom/movable/screen/weird_route/Destroy()
	route = null
	return ..()

/// The box's fill and border, coloured apart (see /datum/weird_route/proc/colour_box()). Clicking it
/// moves the text on, as a confirm press would.
/atom/movable/screen/weird_route/box
	icon = 'voidcrew/modules/weird_route/icons/weird_route_box.dmi'
	icon_state = "fill"
	screen_loc = "CENTER-7:16,SOUTH:6"
	layer = 1
	mouse_opacity = MOUSE_OPACITY_OPAQUE
	color = COLOR_BLACK

/atom/movable/screen/weird_route/box/Click(location, control, params)
	route?.confirm()

/atom/movable/screen/weird_route/box/border
	icon_state = "border"
	layer = 2
	mouse_opacity = MOUSE_OPACITY_TRANSPARENT
	color = COLOR_WHITE

/// Moffer's face, beside his lines: added on, its black let through.
/atom/movable/screen/weird_route/box/portrait
	icon_state = "moffer"
	layer = 3
	mouse_opacity = MOUSE_OPACITY_TRANSPARENT
	color = null
	blend_mode = BLEND_ADD

/atom/movable/screen/weird_route/text
	screen_loc = "CENTER-7:16,SOUTH:6"
	layer = 4
	maptext_width = 420
	maptext_height = 92
	maptext_x = 18
	maptext_y = 12

/// One of the choice's two options. Clicking it chooses it.
/atom/movable/screen/weird_route/text/option
	maptext_width = 140
	// Room for a whole line of the font, or BYOND shows none of it.
	maptext_height = 40
	maptext_y = WEIRD_ROUTE_OPTION_Y - 26
	mouse_opacity = MOUSE_OPACITY_OPAQUE
	/// 1 for the left, 2 for the right.
	var/index = 1

/atom/movable/screen/weird_route/text/option/Click(location, control, params)
	route?.choose(index)

/// The heart beside whichever option's picked: an ordinary one, out of someone's chest. Placed by
/// /datum/weird_route/proc/update_choices().
/atom/movable/screen/weird_route/heart
	icon = 'icons/obj/medical/organs/organs.dmi'
	icon_state = "heart-on"
	screen_loc = "CENTER-7:16,SOUTH:6"
	layer = 5

/atom/movable/screen/weird_route/heart/Initialize(mapload, datum/hud/hud_owner, datum/weird_route/route)
	. = ..()
	// Its 6x9 pixels as big as the game's heart is in its box.
	transform = matrix() * WEIRD_ROUTE_HEART_SCALE

/// A colour over the whole screen, under the box.
/atom/movable/screen/weird_route/fill
	icon_state = "solid"
	screen_loc = "WEST,SOUTH to EAST,NORTH"
	plane = FULLSCREEN_PLANE
	alpha = 0

/// White behind the two of them as they go under: over the lake, under them.
/atom/movable/screen/weird_route/fill/behind
	plane = GAME_PLANE
	layer = MOB_LAYER - 0.2

/// Part of the pinwheel behind the monologue (a memory, the wedge it shows through, the silhouette), or
/// one of the ominous clouds before it: over the lake, under the two of them.
/atom/movable/screen/weird_route/pinwheel
	icon = 'voidcrew/modules/weird_route/icons/weird_route_pinwheel.dmi'
	screen_loc = "CENTER-7,CENTER-7"
	plane = GAME_PLANE
	layer = MOB_LAYER - 0.3
	alpha = 0
