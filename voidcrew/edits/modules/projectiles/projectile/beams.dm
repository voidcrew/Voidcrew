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

// A hitscan beam ends its tracer at impact_x/y. tg puts that at the clicked pixel for the target clicked on, as if
// the body stood upright, and half a tile past where the beam crossed into the tile for anything else. A body
// lying down is turned on its side and drawn in the low half of its tile, so either point often sits on the
// empty floor beside it, and an automatic gun fires every shot at the same clicked pixel. A beam that hit a
// lying body ends on that body instead. Damage and the hit itself are unchanged; this only moves the tracer's end.
/obj/projectile/on_hit(atom/target, blocked = 0, pierce_hit)
	. = ..()
	if(!hitscan || . != BULLET_ACT_HIT || !isliving(target))
		return
	var/mob/living/lying = target
	if(lying.body_position != LYING_DOWN)
		return
	impact_x = clamp(isnull(impact_x) ? 0 : impact_x, lying.pixel_x - 12, lying.pixel_x + 12)
	impact_y = clamp(isnull(impact_y) ? 0 : impact_y, lying.pixel_y - 3, lying.pixel_y + 3)
