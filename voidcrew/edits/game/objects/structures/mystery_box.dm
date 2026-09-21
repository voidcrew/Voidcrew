// Voidcrew extensions to code/game/objects/structures/mystery_box.dm.

/obj/structure/mystery_box/fishing/Destroy()
	spins_by_crew = null
	return ..()

/// Which spin pool this opener draws from: the ship they crew for, or their own mind if they crew for none.
/obj/structure/mystery_box/fishing/proc/get_spin_pool(mob/user)
	var/obj/structure/overmap/ship/crew_ship = get_crew_ship(user)
	if(crew_ship)
		return WEAKREF(crew_ship)
	return user?.mind ? WEAKREF(user.mind) : null

/obj/structure/mystery_box/fishing
	/// Weakref of a crew - their ship, or the opener's own mind when they crew for none - to the spins that crew has already taken out of this chest.
	var/list/spins_by_crew
