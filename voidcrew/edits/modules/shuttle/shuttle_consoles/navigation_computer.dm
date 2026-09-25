// Voidcrew extensions to code/modules/shuttle/shuttle_consoles/navigation_computer.dm.

/**
 * Whether this console's camera eye may be moved onto `destination`.
 *
 * A hook rather than a blanket restriction on the eye type: every shuttle-docker console in
 * the game shares /mob/eye/camera/remote/shuttle_docker, and upstream navigation, syndicate,
 * whiteship and caravan consoles are all supposed to be able to scroll wherever their z_lock
 * allows. Only the voidcrew survey console has co-tenants to be kept out of.
 *
 * Counterpart of /mob/eye/camera/remote/transporter/setLoc(), which does the same job for the
 * transporter's targeting scanner (voidcrew/modules/transporter/transporter_console.dm).
 */
/obj/machinery/computer/camera_advanced/shuttle_docker/proc/eye_may_enter(turf/destination)
	return TRUE
