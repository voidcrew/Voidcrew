/**
 * Ship Construction Drone
 *
 * A construction drone for ship building that is restricted to:
 * 1. Turfs within the shuttle's areas
 * 2. Turfs adjacent to the shuttle (for expansion building)
 */

/mob/eye/camera/remote/base_construction/ship
	name = "ship construction drone"
	// Disable camera network visibility - ships don't have station camera networks
	use_visibility = FALSE

/mob/eye/camera/remote/base_construction/ship/setLoc(turf/destination, force_update = FALSE)
	var/obj/machinery/computer/camera_advanced/base_construction/ship/ship_console = linked_console

	if(!ship_console)
		return ..()

	// Check if we can move to this destination
	if(!ship_console.can_move_to(destination))
		return

	return ..()
