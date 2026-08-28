// ========== TARGETING RETICLE ==========

/atom/movable/screen/ship_combat
	icon = 'icons/hud/screen_gen.dmi'
	mouse_opacity = MOUSE_OPACITY_TRANSPARENT

/atom/movable/screen/ship_combat/targeting_reticle
	name = "targeting reticle"
	icon_state = "selector"
	screen_loc = "CENTER"
	color = "#ff0000"
	plane = HUD_PLANE
	layer = ABOVE_MOB_LAYER

/**
 * Slot 2 of /atom/movable/screen/Initialize is `datum/hud/hud_owner`, and a non-null value
 * there is fed straight to set_new_hud(). This used to declare the slot as the owning
 * console, and console_parent.dm built it with new(null, src) - so `hud` was set to a
 * machine, COMSIG_QDELETING was registered on it, and get_mob() would have read `mymob`
 * off an /obj/machinery. The reticle is added directly to user.client.screen and never
 * belongs to a hud, so the slot is left empty and `hud` stays null. The console already
 * owns the reticle through its own `reticle` var, and the body never read the parameter.
 */
/atom/movable/screen/ship_combat/targeting_reticle/Initialize(mapload)
	. = ..()
	// Add a pulsing effect
	animate(src, alpha = 128, time = 0.5 SECONDS, loop = -1)
	animate(alpha = 255, time = 0.5 SECONDS)
