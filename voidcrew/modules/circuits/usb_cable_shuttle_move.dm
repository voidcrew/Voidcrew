/**
 * # USB cable links and ship movement
 *
 * Every voidcrew ship is a shuttle, so a dock, an undock or an overmap jump drags the whole
 * hull - and every USB cable link inside it - through /obj/docking_port/mobile/initiate_docking().
 * A shuttle move relocates atoms one turf at a time, so halfway through the move the two ends
 * of a USB link are tens of tiles apart and sitting on different z levels.
 *
 * Upstream tries to cope with that by latching a "don't range check right now" flag between
 * COMSIG_ATOM_BEFORE_SHUTTLE_MOVE and COMSIG_ATOM_AFTER_SHUTTLE_MOVE. That latch has two holes:
 *
 * 1. beforeShuttleMove() is called on every turf content during preflight_check(), but
 *    afterShuttleMove() is only called for the atoms that made it into moved_atoms. Any abort
 *    after preflight - a blocked dock, a failed canMove(), a null destination turf - latches the
 *    flag on permanently, and from then on the link can never be broken by walking away either.
 * 2. The flag is latched from signals registered directly on the port's parent and on the
 *    circuit's physical object, and only *direct turf contents* have the shuttle move procs
 *    called on them. An endpoint inside a crate, a locker, a bag or another machine never
 *    latches at all, so it is range checked against a half-moved partner.
 *
 * Instead of enumerating every ordering, stop trusting a single instantaneous range sample.
 * A failed check schedules a re-check for after the world has settled (a zero-delay timer
 * cannot fire until initiate_docking() next sleeps, which is after takeoff() has moved
 * everything), and only a link that is *still* out of range then actually snaps. Endpoints that
 * genuinely separated - somebody carried the shell away - still disconnect, one tick later.
 *
 * The beam is a separate casualty. /datum/beam/redrawing() qdels itself the instant
 * origin.z != target.z, which is unavoidably true partway through any shuttle move that changes
 * z level, i.e. every single flight. Nothing upstream ever rebuilt it, so the cable's beam
 * vanished on the first undock and left the port holding a reference to a deleted datum. Rebuild
 * it once the move lands.
 */

/datum/component/usb_port
	/// TRUE while a settle-then-decide range re-check is already scheduled.
	var/range_recheck_queued = FALSE

/**
 * Overrides the upstream handler so that an out of range sample never cuts the link on the spot.
 * Deliberately does not call parent: the latched deferral it consults is unreliable (see above)
 * and settle_usb_link() supersedes it.
 */
/datum/component/usb_port/on_moved()
	SIGNAL_HANDLER

	if(isnull(attached_circuit))
		return

	if(IN_GIVEN_RANGE(attached_circuit, parent, USB_CABLE_MAX_RANGE))
		return

	queue_usb_link_recheck()

/datum/component/usb_port/after_parent_shuttle_move()
	SIGNAL_HANDLER

	. = ..()
	// Always re-check after a shuttle move, even if the link never left range: the beam is
	// destroyed by the move regardless and has to be rebuilt.
	queue_usb_link_recheck()

/datum/component/usb_port/after_physical_object_shuttle_move()
	SIGNAL_HANDLER

	. = ..()
	queue_usb_link_recheck()

/// Schedules settle_usb_link() for once the current en-masse move has finished.
/datum/component/usb_port/proc/queue_usb_link_recheck()
	if(range_recheck_queued)
		return
	range_recheck_queued = TRUE
	addtimer(CALLBACK(src, PROC_REF(settle_usb_link)), 0, TIMER_DELETE_ME)

/**
 * Decides what actually happened to the link now that everything has stopped moving.
 * Still in range means both ends travelled together and the link survives (its beam is rebuilt).
 * Out of range means the ends really were separated, so the link snaps as normal.
 */
/datum/component/usb_port/proc/settle_usb_link()
	range_recheck_queued = FALSE

	if(isnull(parent) || isnull(attached_circuit))
		return

	if(!IN_GIVEN_RANGE(attached_circuit, parent, USB_CABLE_MAX_RANGE))
		detach()
		return

	refresh_usb_cable_beam()

/// Rebuilds the connection beam if the move killed it. No-op while the existing beam is alive.
/datum/component/usb_port/proc/refresh_usb_cable_beam()
	if(!QDELETED(usb_cable_beam))
		return
	// Do not qdel: the beam already deleted itself, we are only dropping the stale reference.
	usb_cable_beam = null

	if(QDELETED(physical_object))
		return

	var/atom/atom_parent = parent
	usb_cable_beam = atom_parent.Beam(physical_object, "usb_cable_beam", 'icons/obj/science/circuits.dmi')

/obj/item/usb_cable
	/// TRUE while a settle-then-decide range re-check is already scheduled.
	var/range_recheck_queued = FALSE

/**
 * Overrides the upstream handler. Same reasoning as the port side: the latched deferral cannot
 * be trusted, and nothing here is allowed to detach on a single instantaneous sample.
 */
/obj/item/usb_cable/on_moved()
	SIGNAL_HANDLER

	check_in_range()

/obj/item/usb_cable/check_in_range()
	if(isnull(attached_circuit))
		return FALSE

	if(IN_GIVEN_RANGE(attached_circuit, src, USB_CABLE_MAX_RANGE))
		return TRUE

	queue_usb_cable_recheck()
	return FALSE

/// Schedules settle_usb_cable() for once the current en-masse move has finished.
/obj/item/usb_cable/proc/queue_usb_cable_recheck()
	if(range_recheck_queued)
		return
	range_recheck_queued = TRUE
	addtimer(CALLBACK(src, PROC_REF(settle_usb_cable)), 0, TIMER_DELETE_ME)

/// Drops the circuit only if the cable is still out of reach of it now that everything has landed.
/obj/item/usb_cable/proc/settle_usb_cable()
	range_recheck_queued = FALSE

	if(isnull(attached_circuit))
		return

	if(IN_GIVEN_RANGE(attached_circuit, src, USB_CABLE_MAX_RANGE))
		return

	balloon_alert_to_viewers("detached, too far away")
	attached_circuit = null
