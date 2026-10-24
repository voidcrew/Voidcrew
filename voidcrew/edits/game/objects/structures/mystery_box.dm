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

/// How many spins one crew gets out of a treasure chest before it stops opening for them.
/// Pooled across the crew rather than handed out per person: a full ship would otherwise
/// strip every use out of a chest on its own, while a two-man crew could never spend more
/// than a fraction of them.
#define TREASURE_CHEST_CREW_SPINS 6

/obj/structure/mystery_box/fishing/examine(mob/user)
	. = ..()
	var/datum/weakref/pool = get_spin_pool(user)
	if(!pool)
		return
	var/spins_left = max(TREASURE_CHEST_CREW_SPINS - LAZYACCESS(spins_by_crew, pool), 0)
	if(!spins_left)
		. += span_warning("It has nothing left for your crew.")
		return
	. += span_notice("It has [spins_left] spin[spins_left == 1 ? "" : "s"] left for your crew.")

/obj/structure/mystery_box/fishing/activate(mob/living/user)
	var/datum/weakref/pool = get_spin_pool(user)
	if(pool && LAZYACCESS(spins_by_crew, pool) >= TREASURE_CHEST_CREW_SPINS)
		to_chat(user, span_warning("[src] refuses to open for your crew anymore. Perhaps you should hand it off to another one..."))
		return
	. = ..()
	if(pool)
		LAZYINITLIST(spins_by_crew)
		spins_by_crew[pool] += 1

#undef TREASURE_CHEST_CREW_SPINS
