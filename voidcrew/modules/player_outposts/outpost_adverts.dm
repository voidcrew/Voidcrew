/**
 * # Outpost Advertisements
 *
 * Paid galaxy-wide broadcasts. Buying one (at the outpost management console)
 * pushes a one-time notification to every crewed ship, lists the outpost on
 * the mission board's broadcast feed, and pins it on every helm's nav chart
 * for the advert's duration.
 */

/// All live outpost advertisements
GLOBAL_LIST_EMPTY(outpost_adverts)

/datum/outpost_advert
	/// The advertised outpost
	var/datum/weakref/outpost_ref
	/// Snapshot of the outpost's name at purchase time
	var/outpost_name
	/// Snapshot of the outpost's memo at purchase time
	var/blurb
	/// Relative overmap coordinates at purchase time (outposts never move)
	var/coord_x
	var/coord_y
	/// world.time the advert lapses
	var/expires_at
	var/expiry_timer

/datum/outpost_advert/New(obj/structure/overmap/dynamic/player_outpost/outpost)
	..()
	outpost_ref = WEAKREF(outpost)
	outpost_name = outpost.name
	blurb = length(outpost.memo) ? outpost.memo : "All frequencies welcome."
	var/list/coords = outpost.get_relative_overmap_coords()
	coord_x = coords ? coords[1] : 0
	coord_y = coords ? coords[2] : 0
	expires_at = world.time + OUTPOST_ADVERT_DURATION
	expiry_timer = addtimer(CALLBACK(src, PROC_REF(expire)), OUTPOST_ADVERT_DURATION, TIMER_STOPPABLE)
	GLOB.outpost_adverts += src
	broadcast()

/datum/outpost_advert/Destroy()
	GLOB.outpost_adverts -= src
	if(expiry_timer)
		deltimer(expiry_timer)
		expiry_timer = null
	var/obj/structure/overmap/dynamic/player_outpost/outpost = outpost_ref?.resolve()
	if(outpost?.current_advert == src)
		outpost.current_advert = null
	return ..()

/// One-time notification to every simulated ship at purchase
/datum/outpost_advert/proc/broadcast()
	for(var/obj/structure/overmap/ship/ship as anything in SSovermap.simulated_ships)
		ship.ship_notify("[outpost_name] ([coord_x], [coord_y]): [blurb]", "OUTPOST BROADCAST", SHIP_NOTIFY_NOTICE, 'voidcrew/sound/notify.ogg', 20)

/datum/outpost_advert/proc/expire()
	expiry_timer = null
	qdel(src)

/// Seconds until this advert lapses (for UI display)
/datum/outpost_advert/proc/get_remaining_seconds()
	return max(0, round((expires_at - world.time) / 10))
