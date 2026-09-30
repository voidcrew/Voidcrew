/**
 * # Outpost service doors
 *
 * The airlocks of outpost service rooms (outpost_service_rooms.dm). They are keyed like any outpost
 * door (outpost_door_access.dm): the room starts its entrance public and its staff doors staff, and
 * the owner or a steward can change either. Every door opens from its free side, the room's inside,
 * so nobody is ever locked in. A visitor who paid for what is inside (a locker, a lab pass) always
 * gets through the room's entrance.
 *
 * Every route that opens an airlock is checked: bumps, clicks, telekinesis and bots all come
 * through allowed(); thrown items, janitor keys, prying tools, emags and Knock each get their own
 * override below. The parent makes the door indestructible, unhackable and closed to the AI.
 */
/obj/machinery/door/airlock/outpost/service
	name = "service airlock"
	desc = "A glass airlock on an outpost's service room."
	icon = 'icons/obj/doors/airlocks/public/glass.dmi'
	overlays_file = 'icons/obj/doors/airlocks/public/overlays.dmi'
	opacity = FALSE
	glass = TRUE
	opens_with_door_remote = FALSE
	// Never set: a door button with a matching id opens, bolts and shocks it. adopt_doors() clears map edits.
	id_tag = null
	/// OUTPOST_DOOR_PUBLIC or OUTPOST_DOOR_STAFF: the setting the room gives the door when it is built
	var/door_policy = OUTPOST_DOOR_PUBLIC

/obj/machinery/door/airlock/outpost/service/medical
	name = "medical service airlock"
	icon = 'icons/obj/doors/airlocks/station/medical.dmi'
	overlays_file = 'icons/obj/doors/airlocks/station/overlays.dmi'

/obj/machinery/door/airlock/outpost/service/vault
	name = "vault service door"
	desc = "A heavy vault door on an outpost's service room."
	icon = 'icons/obj/doors/airlocks/vault/vault.dmi'
	overlays_file = 'icons/obj/doors/airlocks/vault/overlays.dmi'
	opacity = TRUE
	glass = FALSE

/obj/machinery/door/airlock/outpost/service/staff
	name = "staff airlock"
	desc = "An outpost airlock marked for staff."
	icon = 'icons/obj/doors/airlocks/station/command.dmi'
	overlays_file = 'icons/obj/doors/airlocks/station/overlays.dmi'
	opacity = TRUE
	glass = FALSE
	door_policy = OUTPOST_DOOR_STAFF

// Other looks for the outpost styles (outpost_styles.dm). Same rules as the doors above.

/obj/machinery/door/airlock/outpost/service/mining
	name = "service airlock"
	icon = 'icons/obj/doors/airlocks/station/mining.dmi'
	overlays_file = 'icons/obj/doors/airlocks/station/overlays.dmi'

/obj/machinery/door/airlock/outpost/service/research
	name = "service airlock"
	icon = 'icons/obj/doors/airlocks/station/research.dmi'
	overlays_file = 'icons/obj/doors/airlocks/station/overlays.dmi'

/obj/machinery/door/airlock/outpost/service/maintenance
	name = "service door"
	desc = "A scuffed maintenance door on an outpost's service room."
	icon = 'icons/obj/doors/airlocks/station/maintenance.dmi'
	overlays_file = 'icons/obj/doors/airlocks/station/overlays.dmi'
	opacity = TRUE
	glass = FALSE

/obj/machinery/door/airlock/outpost/service/wood
	name = "wooden door"
	desc = "A wooden door hung in an airlock frame."
	icon = 'icons/obj/doors/airlocks/station/wood.dmi'
	overlays_file = 'icons/obj/doors/airlocks/station/overlays.dmi'
	opacity = TRUE
	glass = FALSE

/obj/machinery/door/airlock/outpost/service/staff/maintenance
	name = "staff door"
	desc = "A maintenance door marked for staff."
	icon = 'icons/obj/doors/airlocks/station/maintenance.dmi'

/obj/machinery/door/airlock/outpost/service/staff/wood
	name = "staff door"
	desc = "A wooden door marked for staff."
	icon = 'icons/obj/doors/airlocks/station/wood.dmi'

/// Whether this door opens for `user`: its setting, from where they stand (outpost_door_access.dm)
/obj/machinery/door/airlock/outpost/service/proc/admits(mob/user)
	if(user && isAdminGhostAI(user))
		return TRUE
	return !outpost_access_refuses(user)

/// Whether `user` paid for what is inside this door's room (admits_visitor_extra()). Never through a staff door.
/obj/machinery/door/airlock/outpost/service/proc/admits_paying_visitor(mob/user)
	if(!user || door_policy != OUTPOST_DOOR_PUBLIC)
		return FALSE
	var/datum/outpost_upgrade/service/room = service_room()
	return !!room?.admits_visitor_extra(user)

/// The room this door belongs to, if it stands in one
/obj/machinery/door/airlock/outpost/service/proc/service_room()
	var/obj/structure/overmap/dynamic/player_outpost/home = get_outpost_from_atom(src)
	var/datum/outpost_upgrade/service/room = home?.upgrade_at_turf(get_turf(src))
	return istype(room) ? room : null

// Never ..(): that would add emergency access, the resident override and req_access
/obj/machinery/door/airlock/outpost/service/allowed(mob/M)
	if(admits(M))
		return TRUE
	tell_outpost_access_refusal(M)
	return FALSE

// A thrown item opens a door by the door's own access check, never allowed(). Judge its thrower.
/obj/machinery/door/airlock/outpost/service/Bumped(atom/movable/AM)
	if(isitem(AM) && density && !operating)
		var/obj/item/item = AM
		if((item.w_class >= WEIGHT_CLASS_NORMAL || LAZYLEN(item.GetAccess())) && !admits(item.throwing?.get_thrower()))
			run_animation(DOOR_DENY_ANIMATION)
			return
	return ..()

// The janitor's access key bypasses access; not here
/obj/machinery/door/airlock/outpost/service/try_to_activate_door(mob/living/user, access_bypass = FALSE)
	if(access_bypass && !admits(user))
		access_bypass = FALSE
	return ..()

// Jaws, fireaxes and mech clamps pry doors open by force
/obj/machinery/door/airlock/outpost/service/try_to_crowbar(obj/item/tool, mob/living/user, forced = FALSE)
	if(!admits(user))
		if(user)
			balloon_alert(user, "won't budge!")
		return
	return ..()

/obj/machinery/door/airlock/outpost/service/emag_act(mob/user, obj/item/card/emag/emag_card)
	if(user)
		balloon_alert(user, "no effect!")
	return FALSE

/obj/machinery/door/airlock/outpost/service/on_magic_unlock(datum/source, datum/action/cooldown/spell/aoe/knock/spell, mob/living/caster)
	SIGNAL_HANDLER
	return

// A singularity or reality tear deletes any obj whatever its resistance flags (obj_defense.dm)
/obj/machinery/door/airlock/outpost/service/singularity_act()
	return 0

/obj/machinery/door/airlock/outpost/service/singularity_pull(atom/singularity, current_size)
	return
