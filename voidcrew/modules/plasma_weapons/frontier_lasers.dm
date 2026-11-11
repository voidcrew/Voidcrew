// Package: P4 frontier lasers. The Kestrel laser pistol and Hornet laser SMG, their casings and the
// Kestrel's projectile.

/obj/item/gun/energy/frontier_laser/shoot_live_shot(mob/living/user, pointblank = FALSE, atom/pbtarget = null, message = TRUE)
	. = ..()
	plasma_weapons_far_sound(src, far_fire_sound)
