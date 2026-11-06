/// Backgrounds: owned by P2. See data/backgrounds/spec.md.

/// The round's Penitentiary, once placed
GLOBAL_DATUM(penitentiary, /obj/structure/overmap/penitentiary)

/// Meridian Penitentiary on the overmap. A sibling of the trader outposts, never one of them.
/obj/structure/overmap/penitentiary
	name = "Meridian Penitentiary"
	/// The turf reservation the site's map is loaded into
	var/datum/turf_reservation/reservation

/datum/map_template/penitentiary
	name = "Meridian Penitentiary"
	mappath = "voidcrew/_maps/map_files/outposts/penitentiary.dmm"

/// Places and loads the Penitentiary during SSovermap init
/datum/controller/subsystem/overmap/proc/setup_penitentiary()
	return

/// Whether a thing stands inside the Penitentiary's reservation
/proc/is_penitentiary_turf(atom/thing)
	return FALSE
