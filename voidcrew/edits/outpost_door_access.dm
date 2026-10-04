/**
 * Door access on player outposts: where the lock bites.
 *
 * The owner or a steward keys an outpost's airlocks and windoors to members, staff or the owner
 * from the construction console (voidcrew/modules/player_outposts/outpost_door_access.dm, which
 * holds the rules). This file only hangs the refusal on the door, the way the crew-only ship lock
 * in ship_access.dm does: ahead of `emergency` and `unres_sides`, on allowed(), on the access bypass
 * a janitor key or an exterior airlock's safety takes, and on thrown items. Nothing else about the
 * door changes: hacking, emags, prying and bolts work as they always have.
 *
 * GLOB.outpost_access_doors holds every door that carries a setting. While it is empty, which is
 * every round until someone keys a door, each check here is a single list read.
 */

/// Whether this door must refuse `user` because of its outpost door access setting
/obj/machinery/door/proc/outpost_access_refuses(mob/user)
	if(!length(GLOB.outpost_access_doors))
		return FALSE
	var/datum/component/outpost_door_access/lock = GetComponent(/datum/component/outpost_door_access)
	if(!lock)
		return FALSE
	return !lock.admits(user, get_turf(user))

/// Tells a refused player what the door is keyed to, at most every few seconds: walking into a door repeats the check.
/obj/machinery/door/proc/tell_outpost_access_refusal(mob/user)
	if(!user || !GET_CLIENT(user) || !TIMER_COOLDOWN_FINISHED(user, "outpost_door_refusal"))
		return
	TIMER_COOLDOWN_START(user, "outpost_door_refusal", 3 SECONDS)
	var/datum/component/outpost_door_access/lock = GetComponent(/datum/component/outpost_door_access)
	if(lock)
		balloon_alert(user, lock.sign_text())

/obj/machinery/door/airlock/allowed(mob/user)
	if(outpost_access_refuses(user))
		tell_outpost_access_refusal(user)
		return FALSE
	return ..()

/obj/machinery/door/window/allowed(mob/user)
	if(outpost_access_refuses(user))
		tell_outpost_access_refusal(user)
		return FALSE
	return ..()

// A janitor's access key and an exterior airlock's safety both skip allowed(). Neither opens a keyed door.
/obj/machinery/door/airlock/try_to_activate_door(mob/living/user, access_bypass = FALSE)
	if(access_bypass && requiresID() && outpost_access_refuses(user))
		access_bypass = FALSE
	return ..()

/obj/machinery/door/window/try_to_activate_door(mob/user, access_bypass = FALSE)
	if(access_bypass && outpost_access_refuses(user))
		access_bypass = FALSE
	return ..()

// A thrown item opens a door by the door's own access check (door.dm Bumped()), never allowed(),
// and an outpost door has no access list to refuse it. Judge whoever threw it, from where they stood.
/obj/machinery/door/airlock/Bumped(atom/movable/AM)
	if(!isitem(AM) || !density || operating || !length(GLOB.outpost_access_doors))
		return ..()
	var/obj/item/item = AM
	// Small items without access never open a door upstream either
	if((item.w_class >= WEIGHT_CLASS_NORMAL || LAZYLEN(item.GetAccess())) && outpost_access_refuses(item.throwing?.get_thrower()))
		run_animation(DOOR_DENY_ANIMATION)
		return
	return ..()
