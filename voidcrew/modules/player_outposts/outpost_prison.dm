/// The prison wing an outpost buys from its upgrades catalog. Each placement
/// loads its own instance (the parent has no UNIQUE_AREA), with its own APC,
/// so a power failure in the wing stays in the wing. It echoes like a big hard
/// room, so the yard's noise (and a brewing riot) carries to the office.
/area/voidcrew/player_outpost/prison
	name = "\improper Prison Wing"
	icon = 'icons/area/areas_station.dmi'
	icon_state = "sec_prison"
	sound_environment = SOUND_AREA_LARGE_ENCLOSED
	/// The prison this wing houses, once placement has finished
	var/datum/outpost_prison/prison

/// The prison whose wing holds this atom, if any
/proc/get_outpost_prison(atom/thing)
	var/area/voidcrew/player_outpost/prison/wing = get_area(thing)
	return istype(wing) ? wing.prison : null

/// Authored with its entrance on the south edge; placement rotates it. One map per outpost style
/// (outpost_styles.dm), all the same wing tile for tile: the prison code and its tests read its layout.
/datum/map_template/outpost_upgrade/prison
	name = "Outpost Prison Wing"

/datum/map_template/outpost_upgrade/prison/rundown
	mappath = "voidcrew/_maps/map_files/outposts/outpost_upgrade_prison_rundown.dmm"
	outpost_style = OUTPOST_STYLE_RUNDOWN

/datum/map_template/outpost_upgrade/prison/clean
	mappath = "voidcrew/_maps/map_files/outposts/outpost_upgrade_prison_clean.dmm"
	outpost_style = OUTPOST_STYLE_CLEAN

/datum/outpost_upgrade/prison
	id = "prison"
	name = "Prison Wing"
	desc = "Four cells, a yard and a warden's office."
	price = OUTPOST_PRISON_COST
	template_type = /datum/map_template/outpost_upgrade/prison
	area_type = /area/voidcrew/player_outpost/prison
	entrance_side = SOUTH
	/// The running prison, created once the wing is placed
	var/datum/outpost_prison/prison
	/// list(min_x, min_y, max_x, max_y, z) of each cell block extension joined to the wing, in the
	/// order they were built (outpost_prison_extension.dm). Kept here, not on the prison, so a prison
	/// an admin starts again still covers them.
	var/list/extension_bounds = list()
	/// The cell block floor each extension added, in the same order: it counts toward the mess
	/// density only as far as the extension's cells are occupied (mess_floor_size_now())
	var/list/extension_floor_sizes = list()

/datum/outpost_upgrade/prison/Destroy()
	QDEL_NULL(prison)
	return ..()

/// The footprint of the wing and of each extension joined to it, the wing's own first
/datum/outpost_upgrade/prison/proc/wing_bounds()
	var/list/all = list()
	if(footprint_bounds)
		all += list(footprint_bounds)
	for(var/list/bounds as anything in extension_bounds)
		all += list(bounds)
	return all

/// Every tile in wing_bounds(), each once (an extension's seam column is in two footprints), the wing's own first
/datum/outpost_upgrade/prison/proc/wing_blocks()
	var/list/seen = list()
	var/list/tiles = list()
	for(var/list/bounds as anything in wing_bounds())
		for(var/turf/tile as anything in block(bounds[1], bounds[2], bounds[5], bounds[3], bounds[4], bounds[5]))
			if(seen[tile])
				continue
			seen[tile] = TRUE
			tiles += tile
	return tiles

/datum/outpost_upgrade/prison/on_installed(mob/user)
	// A prison an admin deleted can be started again.
	if(!QDELETED(prison) || !istype(installed_area, /area/voidcrew/player_outpost/prison))
		return
	prison = new(src)
