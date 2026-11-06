/// Backgrounds: owned by P4. See data/backgrounds/spec.md.

/obj/structure/overmap/ship
	/// Flagged as a pirate hull: kept out of green, refused at green and yellow outposts and by freight lines
	var/pirate_crew = FALSE

/// Whether a pirate_crew hull rides in this carrier's contents
/proc/background_rider_flagged(obj/structure/overmap/ship/carrier)
	return FALSE
