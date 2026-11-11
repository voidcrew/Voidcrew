// Package: P8 effects. Impact splash, wall glow, floor soot, gutter-out, vent puff, the near-miss
// hiss and the distant firing sound.

/// Splash, wall glow and soot for a bolt hitting `target`
/obj/projectile/energy/plasma_bolt/proc/plasma_impact_visuals(atom/target, blocked)
	return

/// The gutter-out where a bolt runs out of range
/obj/projectile/energy/plasma_bolt/proc/plasma_gutter_visual()
	return

/// The hiss a bolt makes passing close by a mob, once per mob
/obj/projectile/energy/plasma_bolt/proc/plasma_hissby_check()
	return

/// A puff of vented plasma at `where`
/proc/plasma_vent_puff(turf/where)
	return

/// Plays `far_file` to listeners too far away to hear `source`'s normal firing sound
/proc/plasma_weapons_far_sound(atom/source, far_file)
	return
