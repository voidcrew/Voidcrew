// Ship Shield Visual Effects
// Temporary visual effects for shield hits, breaks, and power loss

/// Blue ripple effect when shields absorb damage
/obj/effect/temp_visual/ship_shield_hit
	name = "shield impact"
	desc = "A ripple of energy across the ship's shields."
	icon = 'icons/effects/effects.dmi'
	icon_state = "blueshatter"
	color = "#4488ff"  // Blue tint
	duration = 8
	alpha = 200
	layer = ABOVE_MOB_LAYER
	plane = GAME_PLANE

/obj/effect/temp_visual/ship_shield_hit/Initialize(mapload)
	. = ..()
	// Start small and expand while fading
	var/matrix/M = matrix()
	M.Scale(0.5, 0.5)
	transform = M

	// Animate expansion and fade
	animate(src, transform = matrix(), alpha = 0, time = duration, easing = EASE_OUT)

/// Flicker effect when shields shut down from power loss
/obj/effect/temp_visual/ship_shield_powerdown
	name = "shield power loss"
	desc = "The ship's shields flicker and die."
	icon = 'icons/effects/effects.dmi'
	icon_state = "shield-old"
	color = "#ffaa44"  // Orange/yellow for power warning
	duration = 10
	alpha = 180
	layer = ABOVE_MOB_LAYER
	plane = GAME_PLANE

/obj/effect/temp_visual/ship_shield_powerdown/Initialize(mapload)
	. = ..()
	// Flicker animation - rapid alpha changes then fade
	animate(src, alpha = 50, time = 1, loop = 3)
	animate(alpha = 180, time = 1)
	animate(alpha = 0, time = duration - 6, easing = EASE_IN)
