/turf/open/overmap
	icon = 'voidcrew/modules/overmap/icons/turf/overmap.dmi'
	icon_state = "overmap"
	initial_gas_mix = AIRLESS_ATMOS
	space_lit = TRUE
	/// The current zone this turf belongs to
	var/datum/overmap_zone/current_zone

/turf/open/overmap/Initialize(mapload)
	. = ..()
	RegisterSignal(src, COMSIG_TURF_ZONE_CHANGED, PROC_REF(on_zone_changed))

/// Called when this turf's zone changes
/turf/open/overmap/proc/on_zone_changed(datum/source, old_zone_type, new_zone_type)
	SIGNAL_HANDLER
	update_zone_color()

/// Updates the turf color based on current zone
/turf/open/overmap/proc/update_zone_color()
	if(!current_zone)
		color = null
		return
	// Apply a subtle tint based on zone type
	switch(current_zone.zone_type)
		if(ZONE_GREEN)
			color = "#88ff88" // Light green tint
		if(ZONE_YELLOW)
			color = "#ffff88" // Light yellow tint
		if(ZONE_RED)
			color = "#ff8888" // Light red tint
		else
			color = null
