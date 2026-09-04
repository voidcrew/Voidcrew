/**
 * # Distress beacon
 *
 * One switch on the helm that puts a hull on every chart in the galaxy.
 *
 * A lit beacon does two things at once. It transmits a line of text on Wideband
 * (the galaxy-wide hailing channel, see [[modules/comms]]) immediately and then
 * every three minutes, and it draws the hull as a live contact on every other
 * ship's helm at unlimited range, past the view ring and past any sensor
 * research. Nothing else on the overmap ignores range like this, which is the
 * point: a distress call is the one signal that is supposed to reach everybody.
 *
 * The text is whatever the crew types. Nothing verifies it - not the hull's
 * integrity, not whether anyone aboard is hurt, not whether the ship is even in
 * trouble. A pirate can light the beacon, write a convincing mayday and wait for
 * a good samaritan to fly into weapons range. The position appended to each
 * transmission IS honest (a beacon that lied about where it was could not be
 * answered at all), so the lure costs the liar something real: everyone now
 * knows exactly where they are.
 *
 * The beacon is deliberately not gated on rank, damage or crew state. Anyone who
 * can work the helm can light it, because the situations it exists for are the
 * ones where the officers are already dead, and the console's own hull-critical
 * lockout is bypassed for it for the same reason (see the universal-topics
 * switch in _helm.dm).
 *
 * NPC vessels never light one and never answer one; whether a pirate hull should
 * be able to run this lure on its own is a separate question.
 */

/// How long a lit beacon waits between repeat Wideband transmissions.
#define DISTRESS_REPEAT_INTERVAL (3 MINUTES)
/// Minimum gap between toggling the beacon, so it can't be strobed at the galaxy.
#define DISTRESS_TOGGLE_COOLDOWN (60 SECONDS)

/obj/structure/overmap/ship
	/// Whether the distress beacon is lit. While TRUE this hull is a contact on
	/// every other ship's helm at any range, and repeats on Wideband.
	var/distress_active = FALSE
	/// The crew-written line the beacon repeats. Never trusted, never checked.
	var/distress_message
	/// world.time the beacon was last lit, for the console's readout.
	var/distress_started_at = 0
	/// Timer id of the pending repeat broadcast. Re-armed per transmission rather
	/// than looped, so nothing has to cancel a timer that is already spent.
	var/distress_repeat_timer
	/// Internal Wideband transmitter, built on first use (the contested-cache
	/// pattern, see contested_cache.dm). Most hulls never light a beacon, so most
	/// hulls never carry one.
	var/obj/item/radio/headset/distress_radio
	COOLDOWN_DECLARE(distress_toggle_cooldown)

/**
 * The mayday the console offers the crew as a starting point. They can rewrite
 * it to say anything at all before it goes out.
 */
/obj/structure/overmap/ship/proc/default_distress_message()
	var/list/coords = get_relative_overmap_coords()
	var/where = coords ? "grid [coords[1]],[coords[2]]" : "an unknown position"
	return "MAYDAY: [display_name || name] requesting assistance at [where]"

/**
 * Lights the beacon. Returns TRUE if it went up.
 *
 * * message - what the beacon repeats. Already html-encoded and length-capped by
 *   the console's text prompt; trimmed again here because this is also the entry
 *   point for anything else that wants to raise a distress call.
 * * user - whoever pressed the button, for the log line. May be null.
 */
/obj/structure/overmap/ship/proc/activate_distress_beacon(message, mob/user)
	if(distress_active)
		return FALSE
	message = trim(message, DISTRESS_MESSAGE_MAX_LEN + 1)
	if(!length(message))
		return FALSE

	distress_active = TRUE
	distress_message = message
	distress_started_at = world.time
	COOLDOWN_START(src, distress_toggle_cooldown, DISTRESS_TOGGLE_COOLDOWN)
	// Our own snapshot is dropped now so the sender's helm shows the beacon on
	// the very next frame; everyone else's is a second old at worst.
	contact_snapshot = null
	// A pulsing outline on the overmap sprite, so anything looking at the hull
	// directly can see the beacon without reading a console.
	add_filter("distress_beacon", 2, outline_filter(1, "#ff4d6d"))
	transition_filter("distress_beacon", list("size" = 3), 0.9 SECONDS, SINE_EASING, -1)

	ship_notify("Distress beacon transmitting: \"[message]\"", "DISTRESS", SHIP_NOTIFY_WARNING, 'voidcrew/sound/notify2.ogg')
	log_game("[user ? key_name(user) : "Something"] lit the distress beacon on [display_name || name]: \"[message]\"")
	broadcast_distress()
	return TRUE

/**
 * Shuts the beacon down. Returns TRUE if there was one to shut down.
 *
 * * silent - skip the crew notice and the log line. Used by the teardown path,
 *   where the hull is going away and there is nobody left to tell.
 */
/obj/structure/overmap/ship/proc/deactivate_distress_beacon(mob/user, silent = FALSE)
	if(!distress_active)
		return FALSE
	clear_distress_beacon()
	COOLDOWN_START(src, distress_toggle_cooldown, DISTRESS_TOGGLE_COOLDOWN)
	contact_snapshot = null
	if(!silent)
		ship_notify("Distress beacon shut down.", "DISTRESS", SHIP_NOTIFY_NOTICE)
		log_game("[user ? key_name(user) : "Something"] shut down the distress beacon on [display_name || name].")
	return TRUE

/**
 * Drops everything the beacon holds: the pending repeat, the transmitter and the
 * sprite filter. Safe to call on a hull that never lit one, and safe to call from
 * Destroy(), which is the automatic shutdown the design asks for - a hull that is
 * destroyed or despawned stops broadcasting because it stops existing.
 */
/obj/structure/overmap/ship/proc/clear_distress_beacon()
	distress_active = FALSE
	if(distress_repeat_timer)
		deltimer(distress_repeat_timer)
		distress_repeat_timer = null
	QDEL_NULL(distress_radio)
	remove_filter("distress_beacon")

/**
 * One transmission, then re-arms itself for the next one.
 *
 * The crew's text goes out unchanged and the CURRENT position is appended: the
 * prefilled mayday bakes in the coordinates it was written at, and a drifting
 * hull would otherwise keep calling rescuers to a tile it left twenty minutes
 * ago. Wideband is unscoped, so the overmap z-level this is sent from doesn't
 * matter (see voidcrew/modules/comms/comms.dm).
 */
/obj/structure/overmap/ship/proc/broadcast_distress()
	distress_repeat_timer = null
	if(QDELETED(src) || !distress_active)
		return
	if(!distress_radio)
		distress_radio = new(src)
		distress_radio.subspace_transmission = TRUE
		distress_radio.canhear_range = 0
		distress_radio.set_listening(FALSE)
		distress_radio.recalculateChannels()
	var/list/coords = get_relative_overmap_coords()
	var/where = coords ? "grid [coords[1]],[coords[2]]" : "an unknown position"
	distress_radio.talk_into(src, "[distress_message] (beacon position: [where])", RADIO_CHANNEL_WIDEBAND)
	distress_repeat_timer = addtimer(CALLBACK(src, PROC_REF(broadcast_distress)), DISTRESS_REPEAT_INTERVAL, TIMER_STOPPABLE)

#undef DISTRESS_REPEAT_INTERVAL
#undef DISTRESS_TOGGLE_COOLDOWN
