// Package: P3 heat. Furnace heat: gain per shot, cooling from turf air in process(), boiling, the
// manual vent, the post-vent firing lock, boil damage and the coil overlay steps.

/// Raises heat by `amount`, boils if due, and starts cooling.
/obj/item/gun/energy/plasma_weapon/proc/add_heat(amount)
	return

/// Takes up to `mol` from the chamber and releases it on the turf at the barrel's temperature. Returns mol released.
/obj/item/gun/energy/plasma_weapon/proc/vent_plasma(mol, mob/user, boil = FALSE)
	return 0

/// FALSE while a vent blocks firing
/obj/item/gun/energy/plasma_weapon/proc/can_fire_heat()
	return TRUE

/// Updates the coil overlay step and the inhand
/obj/item/gun/energy/plasma_weapon/proc/update_heat_step()
	return

/obj/item/gun/energy/plasma_weapon/attack_self(mob/living/user)
	. = ..()
	if(.)
		return
	if(uses_heat)
		vent_plasma(PLASMA_VENT_MOL, user)
