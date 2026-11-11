// Package: P1 bolt. The plasma bolts and their casings: stats, fuel ignition in Moved(), fire stacks
// and ash registration in on_hit(), and the calls out to the P8 effects.

/obj/projectile/energy/plasma_bolt/on_hit(atom/target, blocked = 0, pierce_hit)
	. = ..()
	plasma_impact_visuals(target, blocked)

/obj/projectile/energy/plasma_bolt/on_range()
	plasma_gutter_visual()
	return ..()

/obj/projectile/energy/plasma_bolt/scan_moved_turf()
	. = ..()
	plasma_hissby_check()
