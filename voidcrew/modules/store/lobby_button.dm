/**
 * Voidcrew Player Shop System - Lobby Button
 *
 * Adds a "Shop" button to the lobby HUD for accessing the store.
 */

/// Shop button for the lobby - bottom row alongside settings, changelog, etc.
/atom/movable/screen/lobby/button/bottom/shop
	name = "Voidcrew Shop"
	icon_state = "shop"
	base_icon_state = "shop"
	screen_loc = "TOP:-122,CENTER:-54"

/atom/movable/screen/lobby/button/bottom/shop/Click(location, control, params)
	. = ..()
	if(!.)
		return
	usr.client?.open_voidcrew_store()
