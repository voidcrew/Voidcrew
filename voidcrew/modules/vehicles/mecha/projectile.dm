// Mech-fired projectiles must not collide with their firing mech.
/obj/projectile/proc/ignore_target(atom/thing)
	impacted[WEAKREF(thing)] = TRUE
