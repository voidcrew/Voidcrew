/**
 * The evidence locker (owner decision 30): what officers take at an arrest goes in here and stays. It is an
 * ordinary tg secure closet: a police ID opens it, an emag breaks the lock, and nobody can take it apart. One per
 * outpost, inside the security area; the outpost's interior scan hands it to the police (link_interior()).
 *
 * An emagged lock mends after OUTPOST_CHECKPOINT_EMAG_TIME, as the outpost's doors do (decision 33): the door shuts
 * once nobody stands in it, and locks once nobody is inside. What it holds is watched until it leaves: whoever
 * without police access first takes a seized item out is reported for LOCKER_THEFT (the witness test is the police's).
 */
/obj/structure/closet/secure_closet/outpost_evidence
	name = "evidence locker"
	desc = "A locker for seized goods."
	anchored = TRUE
	req_access = list(ACCESS_OUTPOST_POLICE)
	/// Weakrefs to the seized items put in here that have not been taken out by a hand yet
	var/list/watched

/obj/structure/closet/secure_closet/outpost_evidence/Initialize(mapload)
	. = ..()
	AddElement(/datum/element/outpost_property)

/obj/structure/closet/secure_closet/outpost_evidence/Destroy()
	for(var/datum/weakref/ref as anything in watched)
		var/obj/item/thing = ref?.resolve()
		if(thing)
			UnregisterSignal(thing, COMSIG_MOVABLE_MOVED)
	watched = null
	return ..()

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

/// tg's own emag breaks the lock. Seen by an officer, that is a theft. The lock mends after a while.
/obj/structure/closet/secure_closet/outpost_evidence/emag_act(mob/user, obj/item/card/emag/emag_card)
	. = ..()
	if(!.)
		return
	addtimer(CALLBACK(src, PROC_REF(mend_lock)), OUTPOST_CHECKPOINT_EMAG_TIME, TIMER_UNIQUE | TIMER_DELETE_ME)
	if(isliving(user) && user.mind)
		evidence_police()?.report_crime(user, OUTPOST_CRIME_LOCKER_THEFT, null, emag_card)

/// The police of the outpost this locker stands in, if any
/obj/structure/closet/secure_closet/outpost_evidence/proc/evidence_police()
	return get_trader_outpost_for_turf(get_turf(src))?.police

/// The emag wears off: the lock works again, the door shuts once its doorway is clear and locks once nobody is inside
/obj/structure/closet/secure_closet/outpost_evidence/proc/mend_lock()
	if(QDELETED(src) || !broken)
		return
	broken = FALSE
	do_sparks(2, TRUE, src)
	visible_message(span_notice("[src] sparks, and its lock lights up again."))
	update_appearance()
	shut_when_clear()

/// Shuts and locks once nobody stands in the doorway or hides inside, trying again every few seconds
/obj/structure/closet/secure_closet/outpost_evidence/proc/shut_when_clear()
	if(QDELETED(src) || broken || locked)
		return
	if((locate(/mob/living) in get_turf(src)) || (locate(/mob/living) in src) || (opened && !close()))
		addtimer(CALLBACK(src, PROC_REF(shut_when_clear)), 5 SECONDS, TIMER_UNIQUE | TIMER_OVERRIDE | TIMER_DELETE_ME)
		return
	lock()
	update_appearance()

/**
 * Puts `thing` inside and locks the door again unless the lock is broken or someone is in the way. A door that
 * cannot shut (someone in the doorway, a crate on its tile) still takes it: it goes inside all the same, out of
 * reach until the door is next shut and opened. Never fails while the locker exists (review S2). TRUE if it is in.
 */
/obj/structure/closet/secure_closet/outpost_evidence/proc/take_evidence(obj/item/thing)
	if(QDELETED(thing) || QDELETED(src))
		return FALSE
	// Never shut anyone in: close() pulls in whoever stands on the tile
	if(opened && !(locate(/mob/living) in get_turf(src)))
		close()
	thing.forceMove(src)
	if(thing.loc != src)
		return FALSE
	watch(thing)
	if(!opened && !broken && !locked && !(locate(/mob/living) in src))
		lock()
		update_appearance()
	return TRUE

/// Watches `thing` until a hand takes it out
/obj/structure/closet/secure_closet/outpost_evidence/proc/watch(obj/item/thing)
	var/datum/weakref/ref = WEAKREF(thing)
	if(ref in watched)
		return
	LAZYADD(watched, ref)
	RegisterSignal(thing, COMSIG_MOVABLE_MOVED, PROC_REF(on_watched_moved))

/obj/structure/closet/secure_closet/outpost_evidence/proc/unwatch(obj/item/thing)
	LAZYREMOVE(watched, WEAKREF(thing))
	UnregisterSignal(thing, COMSIG_MOVABLE_MOVED)

/// A seized item moved. Inside, or lying where an open door spilled it, is fine; in a hand it has been taken.
/obj/structure/closet/secure_closet/outpost_evidence/proc/on_watched_moved(obj/item/source, atom/old_loc, movement_dir, forced, list/old_locs)
	SIGNAL_HANDLER
	if(QDELETED(source) || QDELETED(src) || !source.loc)
		return
	var/atom/movable/top = get_atom_on_turf(source)
	if(!isliving(top))
		return
	unwatch(source)
	var/mob/living/taker = top
	// Officers, and anyone with police access, may take what they like
	if(istype(taker, /mob/living/carbon/human/npc/ambient_npc/outpost/police) || allowed(taker) || !taker.mind)
		return
	evidence_police()?.report_crime(taker, OUTPOST_CRIME_LOCKER_THEFT, null, source)
