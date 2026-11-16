/**
 * Screen objects for the chrome wheel (chrome_wheel.dm).
 *
 * Everything the player sees hangs off one hub at the centre of the view, in
 * its vis_contents, on the above-HUD plane. None of it takes the mouse: a
 * near-invisible full-view catcher sits under it and reports every move and
 * click to the wheel, which works out the chip from the mouse position.
 * Every piece opts out of clear_screen(), because a knockdown rebuilds the HUD
 * mid-hold; the wheel takes its own pieces off the screen when it closes.
 *
 * Pieces keep the alpha and transform of whatever they hang off, so the hub's
 * fade reaches everything and a chip's pop carries its brackets, shade and
 * count with it. Each sets its own colour.
 *
 * Layers, bottom up: backdrop, body, body glow, arcs, leaders, nodes, empty
 * sockets, chips (and their shade, count and brackets), readout.
 */
/atom/movable/screen/chrome_wheel
	icon = CHROME_WHEEL_ICON
	icon_state = null
	plane = ABOVE_HUD_PLANE
	layer = 3
	mouse_opacity = MOUSE_OPACITY_TRANSPARENT
	vis_flags = VIS_INHERIT_PLANE
	clear_with_screen = FALSE
	appearance_flags = RESET_COLOR | NO_CLIENT_COLOR | PIXEL_SCALE

/// The wheel's anchor at the centre of the view. Draws nothing itself.
/atom/movable/screen/chrome_wheel/hub
	screen_loc = "CENTER"

/**
 * A piece of the 240x240 ring art (chrome_wheel_ring.dmi). The art is centred
 * on the ring, which sits CHROME_WHEEL_CENTRE_Y above the middle of the view.
 */
/atom/movable/screen/chrome_wheel/art
	icon = CHROME_WHEEL_RING_ICON
	layer = 2.1
	pixel_x = -104
	pixel_y = -102

/// The soft dark backdrop. Stored at half size and drawn doubled, smoothly.
/atom/movable/screen/chrome_wheel/art/backdrop
	icon_state = "scrim"
	layer = 2
	appearance_flags = RESET_COLOR | NO_CLIENT_COLOR

/atom/movable/screen/chrome_wheel/art/backdrop/Initialize(mapload, datum/hud/hud_owner)
	. = ..()
	transform = matrix(2, 0, 0, 0, 2, 0)

/// The dim dashed outline of a socket with nothing in it.
/atom/movable/screen/chrome_wheel/empty_socket
	icon_state = "socket"
	layer = 2.5

/// One ability on the ring.
/atom/movable/screen/chrome_wheel/chip
	icon_state = "frame_22"
	/// The ability this chip fires.
	var/datum/weakref/ability_ref
	/// CHROME_WHEEL_SOCKET_* it sits in, and its position there, from 1.
	var/socket
	var/index = 1
	/// Which leader lights when it is pointed at: its socket's, or for hand
	/// chrome its own run to the hand ("l_hand_2").
	var/leader_key
	/// Which part of the body lights when it is pointed at.
	var/region
	/// Offset of its centre from the centre of the view, in pixels.
	var/chip_x = 0
	var/chip_y = 0
	/// What the chip was last drawn as, so unchanged chips are left alone.
	var/drawn_state
	/// What its cooldown count last showed.
	var/count_state
	/// Size it was last drawn at: 22, or 26 while pointed at.
	var/size = 22
	/// Cooldown wipe and its top edge, made the first time the chip cools down.
	var/atom/movable/screen/chrome_wheel/chip_part/shade
	var/atom/movable/screen/chrome_wheel/chip_part/shade_edge
	/// Cooldown seconds.
	var/atom/movable/screen/chrome_wheel/chip_part/count
	/// The pick's corner brackets, made the first time this chip is picked.
	var/list/brackets

/atom/movable/screen/chrome_wheel/chip/Destroy()
	vis_contents.Cut()
	QDEL_NULL(shade)
	QDEL_NULL(shade_edge)
	QDEL_NULL(count)
	QDEL_LIST(brackets)
	ability_ref = null
	return ..()

/// Something drawn on a chip: the cooldown wipe, its edge or its count.
/atom/movable/screen/chrome_wheel/chip_part
	icon_state = "px"
	layer = 3.1

/// One corner of the lock brackets on the picked chip.
/atom/movable/screen/chrome_wheel/bracket
	icon = CHROME_WHEEL_BRACKET_ICON
	layer = 3.4
	color = CHROME_WHEEL_PICKED_COLOR
	/// Which way is outward from the chip, for the snap in: -1 or 1 on each axis.
	var/out_x = 0
	var/out_y = 0

/// A part of the readout panel under the ring: a flat block, or a line of text.
/atom/movable/screen/chrome_wheel/readout
	icon_state = "px"
	layer = 4

/**
 * tg's cursor catcher (the scope's), lifted above the HUD so the mouse reaches
 * the wheel wherever it is on the map. Its icon is white at alpha 1: invisible,
 * but solid to the mouse.
 */
/atom/movable/screen/fullscreen/cursor_catcher/chrome_wheel
	// overlay_fullscreen() appends a severity to the base state; nothing here goes
	// through it, so name the state that exists.
	icon_state = "fullscreen_blocker0"
	plane = ABOVE_HUD_PLANE
	layer = 1
	clear_with_screen = FALSE
	/// The wheel to report to.
	var/datum/component/chrome_wheel/wheel

/atom/movable/screen/fullscreen/cursor_catcher/chrome_wheel/Destroy()
	wheel = null
	owner = null
	return ..()

/atom/movable/screen/fullscreen/cursor_catcher/chrome_wheel/MouseMove(location, control, params)
	. = ..()
	if(usr == owner)
		wheel?.mouse_moved(params)

/atom/movable/screen/fullscreen/cursor_catcher/chrome_wheel/Click(location, control, params)
	if(usr == owner)
		wheel?.mouse_clicked(params)
