/**
 * # Overmap Transmissions
 *
 * Ship-to-ship hails sent from the helm's comms tab. A transmission is a
 * position, a name and a line of text, delivered to every vessel that could see
 * the sender when it fired, the view ring, exactly as far as the crew can look.
 *
 * This replaces a maptext overlay that used to be drawn onto the ship atom and
 * rendered by the helm's BYOND camera map. That camera is gone (`cam_screen` is
 * no longer allocated), so the overlay had no renderer left and broadcasts were
 * silently invisible to everyone including the sender. Transmissions are now
 * data the helm reads, which also means receivers get a chart marker and a log
 * instead of three seconds of floating text they had to be looking at.
 *
 * Transmitting gives you away: a hail resolves the sender on the receiver's
 * chart the same way a Ships scan would (see [[ship_sensors]]). Radio silence is
 * a tactic, and a lurking pirate has a reason not to say hello.
 */

/// How long a transmission keeps drawing its pulse on the navigation chart.
#define TRANSMISSION_CHART_LIFETIME (8 SECONDS)
/// How many received transmissions a ship keeps in its comms log.
#define COMMS_LOG_LENGTH 8

/obj/structure/overmap/ship
	/// Transmissions this ship has heard, oldest first, capped at COMMS_LOG_LENGTH.
	var/list/datum/overmap_transmission/comms_log

/datum/overmap_transmission
	/// The text that was sent.
	var/message
	/// Sender's name as it read when the hail fired. A later rename can't rewrite
	/// history, and the log outlives the ship.
	var/sender_name
	/// The sending vessel, if it still exists. Used to identify it on the receiver's
	/// chart and to mark the receiver's own transmissions.
	var/datum/weakref/sender_ref
	/// Sender's position in relative overmap coordinates when the hail fired.
	var/coord_x = 0
	var/coord_y = 0
	/// world.time the hail fired.
	var/created_at = 0

/datum/overmap_transmission/New(obj/structure/overmap/ship/sender, message, coord_x, coord_y)
	src.message = message
	src.coord_x = coord_x
	src.coord_y = coord_y
	created_at = world.time
	if(sender)
		sender_name = sender.name
		sender_ref = WEAKREF(sender)

/// Whether this hail is recent enough to still pulse on the chart.
/datum/overmap_transmission/proc/is_live()
	return (world.time - created_at) < TRANSMISSION_CHART_LIFETIME

/// Seconds since the hail fired, for the comms log's "12s ago".
/datum/overmap_transmission/proc/age_seconds()
	return round((world.time - created_at) / 10)

/**
 * Sends a hail from this ship. Reaches every vessel inside the view ring,
 * including the sender, so the crew sees their own transmission go out.
 */
/obj/structure/overmap/ship/proc/ship_broadcast_runechat(message)
	var/list/origin = get_relative_overmap_coords()
	if(!origin)
		return
	var/datum/overmap_transmission/transmission = new(src, message, origin[1], origin[2])
	// Walked from the ship list rather than range(): a docked ship sits inside its
	// berth rather than on the overmap turf, and get_relative_overmap_coords()
	// resolves that where a turf sweep would miss it.
	for(var/obj/structure/overmap/ship/receiver as anything in SSovermap.simulated_ships)
		if(QDELETED(receiver))
			continue
		if(!in_view_ring(origin, receiver.get_relative_overmap_coords()))
			continue
		receiver.receive_transmission(transmission)

/**
 * Files an incoming hail: appends it to the comms log, resolves the sender on our
 * chart, and pushes a frame so the pulse starts now rather than on the next
 * heartbeat.
 */
/obj/structure/overmap/ship/proc/receive_transmission(datum/overmap_transmission/transmission)
	LAZYADD(comms_log, transmission)
	if(length(comms_log) > COMMS_LOG_LENGTH)
		comms_log.Cut(1, (length(comms_log) - COMMS_LOG_LENGTH) + 1)

	// Whoever just spoke is no longer an anonymous blip. mark_vessel_identified
	// also drops the cached snapshot, so the name appears with the message rather
	// than a beat after it.
	mark_vessel_identified(transmission.sender_ref?.resolve())

	push_helm_frame()

#undef TRANSMISSION_CHART_LIFETIME
#undef COMMS_LOG_LENGTH
