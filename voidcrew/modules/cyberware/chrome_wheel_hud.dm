/**
 * Screen objects for the chrome wheel (chrome_wheel.dm).
 *
 * Everything the player sees hangs off one hub at the centre of the view, in
 * its vis_contents, on the above-HUD plane. None of it takes the mouse: a
 * near-invisible full-view catcher sits under it and reports every move and
 * click to the wheel, which works out the slice from the mouse position.
 * Every piece opts out of clear_screen(), because a knockdown rebuilds the HUD
 * mid-hold; the wheel takes its own pieces off the screen when it closes.
 */
/atom/movable/screen/chrome_wheel
	icon = 'icons/hud/radial.dmi'
	icon_state = null
	plane = ABOVE_HUD_PLANE
	layer = 2
	mouse_opacity = MOUSE_OPACITY_TRANSPARENT
	vis_flags = VIS_INHERIT_PLANE
	clear_with_screen = FALSE

/// The wheel's anchor at the centre of the view. Draws nothing itself.
/atom/movable/screen/chrome_wheel/hub
	screen_loc = "CENTER"

/// One position on the wheel: an ability, one of its sub-options, the centre,
/// or a dim placeholder for an empty body region.
/atom/movable/screen/chrome_wheel/slice
	icon_state = "radial_slice"
	layer = 3
	/// The ability this slice fires.
	var/datum/weakref/ability_ref
	/// Set on sub-option slices: the option's id within the ability.
	var/option_id
	/// Set on sub-option slices: the option's icon.
	var/mutable_appearance/option_look
	/// Offset from the wheel centre, in pixels.
	var/slice_x = 0
	var/slice_y = 0
	/// Cooldown wipe, made the first time this slice cools down.
	var/atom/movable/screen/chrome_wheel/shade/shade
	/// The cooldown end the shade is animating towards.
	var/cooldown_until = 0
	/// What the slice was last drawn as, so unchanged slices are left alone.
	var/drawn_state

/atom/movable/screen/chrome_wheel/slice/Destroy()
	vis_contents.Cut()
	QDEL_NULL(shade)
	ability_ref = null
	option_look = null
	return ..()

/// A dark copy of the slice shape laid over a slice while it cools down.
/atom/movable/screen/chrome_wheel/shade
	icon_state = "radial_slice"
	color = COLOR_BLACK
	alpha = 0
	layer = 4
	// APPEARANCE_UI without RESET_TRANSFORM: grows with its slice when that is pointed at.
	appearance_flags = RESET_COLOR|NO_CLIENT_COLOR|PIXEL_SCALE

/// The name of the slice the mouse is on, under the wheel.
/atom/movable/screen/chrome_wheel/label
	layer = 5
	maptext_width = 192
	maptext_height = 32
	maptext_x = -80

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
