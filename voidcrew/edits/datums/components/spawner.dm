// Voidcrew extensions to code/datums/components/spawner.dm.

// VOIDCREW EDIT: break the parent <-> spawn_callback reference cycle.
// /obj/structure/spawner passes spawn_callback = CALLBACK(src, PROC_REF(on_mob_spawn)),
// and the callback datum's obj var keeps the parent alive: parent -> components ->
// this component -> spawn_callback -> parent never soft-GCs, so every component-based
// spawner hard-deletes - a multi-minute reference search each under REFERENCE_TRACKING.
/datum/component/spawner/Destroy()
	spawn_callback = null
	spawned_things = null
	cached_footprint = null
	cached_footprint_turf = null
	return ..()

/datum/component/spawner
	var/datum/map_footprint/cached_footprint
	/// The turf cached_footprint was resolved from, so a moved parent invalidates it.
	var/turf/cached_footprint_turf
