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
