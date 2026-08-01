/**
 * Ship interiors carry no internal access control.
 *
 * A hull is run by a handful of people who between them hold one department's ID
 * each, so stock /tg/ department locks mostly amount to the medic being unable to
 * reach a toolbox and nobody aboard being able to touch the air alarms. Inside a
 * crewed hull every lock opens for anyone standing in it, whatever their ID says.
 *
 * Ships still under AI control are the exception. A pirate frigate's armory is
 * loot, and it stays shut until the crew takes the hull with a ship key - claiming
 * an NPC ship clears its ai_controller, which is what opens its locks.
 *
 * Everything outside a ship - outposts, ruins, planets, the colosseum - sits in
 * /area/voidcrew or an upstream area root and is untouched by this.
 */
/atom/movable/proc/in_unrestricted_ship()
	var/area/shuttle/voidcrew/ship_area = get_area(src)
	if(!istype(ship_area))
		return FALSE
	var/obj/structure/overmap/ship/ship = ship_area.shuttle_port?.current_ship
	return !isnull(ship) && isnull(ship.ai_controller)

/**
 * check_access_list() is the single choke point every lock funnels through:
 * allowed() calls it via check_access(), and the machines that read an ID
 * directly - the bank machine, APC control, comms console, ore redemption - call
 * check_access() themselves. Overriding here catches both paths.
 *
 * The req_access length test comes first so the common case (a ship door mapped
 * with no access at all) stays a pair of list reads. This runs on every airlock
 * bump and inside bot pathfinding, so the area lookup has to stay off that path.
 */
/obj/check_access_list(list/access_list)
	if((length(req_access) || length(req_one_access)) && in_unrestricted_ship())
		return TRUE
	return ..()

/mob/check_access_list(list/access_list)
	if((length(req_access) || length(req_one_access)) && in_unrestricted_ship())
		return TRUE
	return ..()

/**
 * Lockers never check access at all, anywhere.
 *
 * /tg/ maps department access onto most of its secure furniture, which on a hull
 * with five people aboard mostly means the toolbox and the spare hardsuit sit
 * behind a lock nobody present can open. Unlike the rule above this is not scoped
 * to ships: a locker in a ruin or aboard an NPC frigate is guarded by whatever is
 * standing next to it, not by an ID card that nobody in this codebase is issued.
 *
 * req_access is deliberately left populated. Deconstructing a secure closet still
 * pops out electronics carrying its original access list, and a player who wires
 * that into something else gets a working lock.
 *
 * A closet a player has ID-locked with a multitool is unaffected, because that
 * path compares the stored card reference instead of an access list. Personal
 * lockers are the exception: their can_unlock() treats allowed() as an override on
 * top of the registered card, so with access gone they open for the whole crew.
 */
/obj/structure/closet/check_access_list(list/access_list)
	return TRUE
