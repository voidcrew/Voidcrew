// Voidcrew: the standard laser family is hitscan. A laser lands the moment it is fired and leaves
// tg's beam tracer along its path, instead of flying as a bolt. Same damage as upstream; the instant
// hit is the change. Reflection, blocking, glass and every on-hit signal run exactly as for a bolt,
// because tg's hitscan walks the same per-tile movement and hit code (projectile.dm process_hitscan).
//
// Stays a travelling bolt: disablers and other stun beams, X-ray, pulse, emitters, the ship defense
// turret, lasertag, CTF, mech lasers (below) and the two lasers whose look is the projectile itself.

/obj/projectile/beam/laser
	hitscan = TRUE

/// Its ball grows as it flies (reduce_range), which a hitscan beam never shows.
/obj/projectile/beam/laser/accelerator
	hitscan = FALSE

/// Genetics laser eyes keep their own eye-beam sprite.
/obj/projectile/beam/laser/laser_eyes
	hitscan = FALSE

// Lasers outside /beam/laser that laser guns and turrets fire. Upstream gives them no tracer.

/// Laser scattershot and scatter laser shells.
/obj/projectile/beam/scatter
	hitscan = TRUE
	tracer_type = /obj/effect/projectile/tracer/laser
	muzzle_type = /obj/effect/projectile/muzzle/laser
	impact_type = /obj/effect/projectile/impact/laser

/// Laser gatling and some turrets.
/obj/projectile/beam/weak
	hitscan = TRUE
	tracer_type = /obj/effect/projectile/tracer/laser
	muzzle_type = /obj/effect/projectile/muzzle/laser
	impact_type = /obj/effect/projectile/impact/laser

/// Practice laser guns.
/obj/projectile/beam/practice
	hitscan = TRUE
	tracer_type = /obj/effect/projectile/tracer/laser
	muzzle_type = /obj/effect/projectile/muzzle/laser
	impact_type = /obj/effect/projectile/impact/laser

// Mech lasers stay bolts: exosuit weapons are balanced on their own, apart from hand guns.

/obj/projectile/beam/laser/mech
	hitscan = FALSE

/obj/projectile/beam/laser/heavylaser/mech
	hitscan = FALSE

/obj/item/mecha_parts/mecha_equipment/weapon/energy/laser
	projectile = /obj/projectile/beam/laser/mech

/obj/item/mecha_parts/mecha_equipment/weapon/energy/laser/heavy
	projectile = /obj/projectile/beam/laser/heavylaser/mech

// Coloured lasers draw a beam in their own bolt's colours instead of tg's red one.

/obj/effect/projectile/tracer/laser/amber
	icon = 'voidcrew/icons/obj/guns/laser_tracers.dmi'
	icon_state = "beam_amber"

/obj/effect/projectile/muzzle/laser/amber
	icon = 'voidcrew/icons/obj/guns/laser_tracers.dmi'
	icon_state = "muzzle_amber"

/obj/effect/projectile/impact/laser/amber
	icon = 'voidcrew/icons/obj/guns/laser_tracers.dmi'
	icon_state = "impact_amber"

/obj/effect/projectile/tracer/laser/plasma
	icon = 'voidcrew/icons/obj/guns/laser_tracers.dmi'
	icon_state = "beam_plasma"

/obj/effect/projectile/muzzle/laser/plasma
	icon = 'voidcrew/icons/obj/guns/laser_tracers.dmi'
	icon_state = "muzzle_plasma"

/obj/effect/projectile/impact/laser/plasma
	icon = 'voidcrew/icons/obj/guns/laser_tracers.dmi'
	icon_state = "impact_plasma"

/obj/effect/projectile/tracer/laser/violet
	icon = 'voidcrew/icons/obj/guns/laser_tracers.dmi'
	icon_state = "beam_violet"

/obj/effect/projectile/muzzle/laser/violet
	icon = 'voidcrew/icons/obj/guns/laser_tracers.dmi'
	icon_state = "muzzle_violet"

/obj/effect/projectile/impact/laser/violet
	icon = 'voidcrew/icons/obj/guns/laser_tracers.dmi'
	icon_state = "impact_violet"

/obj/effect/projectile/tracer/laser/crimson
	icon = 'voidcrew/icons/obj/guns/laser_tracers.dmi'
	icon_state = "beam_crimson"

/obj/effect/projectile/muzzle/laser/crimson
	icon = 'voidcrew/icons/obj/guns/laser_tracers.dmi'
	icon_state = "muzzle_crimson"

/obj/effect/projectile/impact/laser/crimson
	icon = 'voidcrew/icons/obj/guns/laser_tracers.dmi'
	icon_state = "impact_crimson"

/obj/projectile/beam/laser/carbine
	tracer_type = /obj/effect/projectile/tracer/laser/amber
	muzzle_type = /obj/effect/projectile/muzzle/laser/amber
	impact_type = /obj/effect/projectile/impact/laser/amber
	hitscan_light_color_override = LIGHT_COLOR_ORANGE
	muzzle_flash_color_override = LIGHT_COLOR_ORANGE
	impact_light_color_override = LIGHT_COLOR_ORANGE

/obj/projectile/beam/laser/carbine/cybersun
	tracer_type = /obj/effect/projectile/tracer/laser/plasma
	muzzle_type = /obj/effect/projectile/muzzle/laser/plasma
	impact_type = /obj/effect/projectile/impact/laser/plasma
	hitscan_light_color_override = LIGHT_COLOR_FIRE
	muzzle_flash_color_override = LIGHT_COLOR_FIRE
	impact_light_color_override = LIGHT_COLOR_FIRE

/obj/projectile/beam/laser/cybersun
	tracer_type = /obj/effect/projectile/tracer/laser/plasma
	muzzle_type = /obj/effect/projectile/muzzle/laser/plasma
	impact_type = /obj/effect/projectile/impact/laser/plasma
	hitscan_light_color_override = LIGHT_COLOR_FIRE
	muzzle_flash_color_override = LIGHT_COLOR_FIRE
	impact_light_color_override = LIGHT_COLOR_FIRE

/obj/projectile/beam/laser/musket
	tracer_type = /obj/effect/projectile/tracer/laser/violet
	muzzle_type = /obj/effect/projectile/muzzle/laser/violet
	impact_type = /obj/effect/projectile/impact/laser/violet
	hitscan_light_color_override = COLOR_STRONG_VIOLET
	muzzle_flash_color_override = COLOR_STRONG_VIOLET
	impact_light_color_override = COLOR_STRONG_VIOLET

/obj/projectile/beam/laser/hellfire
	tracer_type = /obj/effect/projectile/tracer/laser/crimson
	muzzle_type = /obj/effect/projectile/muzzle/laser/crimson
	impact_type = /obj/effect/projectile/impact/laser/crimson
	hitscan_light_color_override = "#FF969D"
	muzzle_flash_color_override = "#FF969D"
	impact_light_color_override = "#FF969D"

/obj/projectile/beam/laser/flare
	tracer_type = /obj/effect/projectile/tracer/laser/crimson
	muzzle_type = /obj/effect/projectile/muzzle/laser/crimson
	impact_type = /obj/effect/projectile/impact/laser/crimson
