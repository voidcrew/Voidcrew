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

/atom/movable/screen/ship_combat/targeting_reticle/Initialize(mapload, obj/machinery/computer/camera_advanced/ship_combat/console)
	. = ..()
	// Add a pulsing effect
	animate(src, alpha = 128, time = 0.5 SECONDS, loop = -1)
	animate(alpha = 255, time = 0.5 SECONDS)
