/**
 * # Outpost police: the wanted alert
 *
 * Owner: P8. Stars as a HUD alert icon (owner decision 10), no chat text. Spec 12.
 *
 * One standard tg alert per wanted person, category "outpost_wanted": one to five stars lit left to right,
 * and a second set that blinks while no officer has them in sight or while they are away from the outpost.
 * Nothing else is shown: the name is "Wanted" and the description says who by.
 *
 * The alert shows the warrant at the outpost the person is at; with none there, the one with the most
 * stars at any outpost (they are away from it, so it blinks). update_hud() is the one entry point: the
 * wanted core calls it when stars change, and it listens to COMSIG_OUTPOST_POLICE_STARS too. The alert also
 * re-reads its warrant once a second, so a blink that starts or stops with no change in stars still shows.
 * Everything here runs inside signal handlers: it never sleeps.
 */

#define OUTPOST_WANTED_ALERT "outpost_wanted"

/atom/movable/screen/alert/outpost_wanted
	name = "Wanted"
	desc = "Wanted by outpost security."
	icon = 'voidcrew/modules/outpost_police/icons/wanted.dmi'
	icon_state = "wanted1"
	/// The person it shows, so the alert can follow them and clear itself
	var/datum/weakref/wanted_mind
	/// The once-a-second look at the warrant (TIMER_DELETE_ME: it can clear its own alert)
	var/refresh_timer

/atom/movable/screen/alert/outpost_wanted/Destroy()
	if(refresh_timer)
		deltimer(refresh_timer)
		refresh_timer = null
	wanted_mind = null
	return ..()

/// Shows `stars` (1 to 5) for `who`, blinking or not, under `force_name`
/atom/movable/screen/alert/outpost_wanted/proc/show_wanted(datum/mind/who, stars, blink, force_name)
	wanted_mind = WEAKREF(who)
	icon_state = "wanted[clamp(stars, 1, 5)][blink ? "_fade" : ""]"
	desc = "Wanted by [force_name || "outpost security"]."
	if(!refresh_timer)
		refresh_timer = addtimer(CALLBACK(src, PROC_REF(refresh)), 1 SECONDS, TIMER_STOPPABLE | TIMER_LOOP | TIMER_DELETE_ME)

/// Looks at the warrant again. Follows the person to a new body, and goes when there is nothing left to show.
/atom/movable/screen/alert/outpost_wanted/proc/refresh()
	var/mob/body = owner
	if(QDELETED(body))
		qdel(src)
		return
	var/datum/mind/who = wanted_mind?.resolve()
	if(!who)
		body.clear_alert(OUTPOST_WANTED_ALERT)
		return
	if(who.current != body)
		body.clear_alert(OUTPOST_WANTED_ALERT)
	refresh_outpost_wanted_alert(who)

/**
 * Throws, updates or clears `who`'s wanted alert on their current body. The warrant shown is the one at the
 * outpost they are at, or failing that the one with the most stars anywhere.
 */
/proc/refresh_outpost_wanted_alert(datum/mind/who)
	SHOULD_NOT_SLEEP(TRUE)
	var/mob/body = who?.current
	if(QDELETED(body))
		return
	var/obj/structure/overmap/trader_outpost/here = get_trader_outpost_for_turf(get_turf(body))
	var/datum/outpost_police/shown_police
	var/shown_stars = 0
	// Typed, not `as anything`: a hard-deleted outpost leaves a null in the list
	for(var/obj/structure/overmap/trader_outpost/outpost in GLOB.trader_outposts)
		var/datum/outpost_police/police = outpost.police
		if(!police || QDELETED(outpost))
			continue
		var/stars = police.get_stars(who)
		if(stars < 1)
			continue
		if(!shown_police || outpost == here || (shown_police.outpost != here && stars > shown_stars))
			shown_police = police
			shown_stars = stars
	if(!shown_police)
		body.clear_alert(OUTPOST_WANTED_ALERT)
		return
	var/datum/outpost_warrant/warrant = shown_police.get_warrant(who)
	var/blink = shown_police.outpost != here || warrant?.unseen_since || warrant?.away_since
	var/atom/movable/screen/alert/outpost_wanted/alert = body.throw_alert(OUTPOST_WANTED_ALERT, /atom/movable/screen/alert/outpost_wanted)
	alert?.show_wanted(who, shown_stars, !!blink, shown_police.profile?.force_name)

/// Throws or clears `who`'s wanted alert (see refresh_outpost_wanted_alert())
/datum/outpost_police/proc/update_hud(datum/mind/who)
	SHOULD_NOT_SLEEP(TRUE)
	refresh_outpost_wanted_alert(who)

#undef OUTPOST_WANTED_ALERT
