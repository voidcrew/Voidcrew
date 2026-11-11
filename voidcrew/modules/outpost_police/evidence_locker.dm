/**
 * The evidence locker (owner decision 30): what officers take at an arrest goes in here and stays. It is an
 * ordinary tg secure closet: a police ID opens it, an emag breaks the lock, and nobody can take it apart. One per
 * outpost, inside the security area; the outpost's interior scan hands it to the police (link_interior()).
 */
/obj/structure/closet/secure_closet/outpost_evidence
	name = "evidence locker"
	desc = "A locker for seized goods."
	anchored = TRUE
	req_access = list(ACCESS_OUTPOST_POLICE)
	/// Minds that broke it open, reported once each
	var/list/thieves

/obj/structure/closet/secure_closet/outpost_evidence/Initialize(mapload)
	. = ..()
	AddElement(/datum/element/outpost_property)

/**
 * Lockers skip access checks everywhere (voidcrew/edits/ship_access.dm); this one keeps tg's own check, so
 * only a card with ACCESS_OUTPOST_POLICE opens it.
 */
/obj/structure/closet/secure_closet/outpost_evidence/check_access_list(list/access_list)
	if(!length(access_list) || !islist(access_list))
		return FALSE
	for(var/required in req_access)
		if(!(required in access_list))
			return FALSE
	return TRUE

/// No renaming it
/obj/structure/closet/secure_closet/outpost_evidence/tool_interact(obj/item/weapon, mob/living/user)
	if(IS_WRITING_UTENSIL(weapon))
		return TRUE
	return ..()

/// tg's own emag breaks the lock. Seen by an officer, that is a theft.
/obj/structure/closet/secure_closet/outpost_evidence/emag_act(mob/user, obj/item/card/emag/emag_card)
	. = ..()
	if(!. || !isliving(user) || !user.mind)
		return
	var/datum/weakref/key = WEAKREF(user.mind)
	if(LAZYACCESS(thieves, key))
		return
	LAZYSET(thieves, key, world.time)
	get_trader_outpost_for_turf(get_turf(src))?.police?.report_crime(user, OUTPOST_CRIME_LOCKER_THEFT, null, emag_card)

/// Puts `thing` inside, shutting the door first if it stands open, and locks it again unless the lock is broken. TRUE if it is in.
/obj/structure/closet/secure_closet/outpost_evidence/proc/take_evidence(obj/item/thing)
	if(QDELETED(thing))
		return FALSE
	if(opened && !close())
		return FALSE
	thing.forceMove(src)
	if(!broken && !locked)
		locked = TRUE
		update_appearance()
	return thing.loc == src
