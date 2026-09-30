/datum/component/spawner
	// Voidcrew: cached map-tenant footprint for the presence gate in
	// try_spawn_mob(). Resolved lazily on the first tick that has anyone on our z-level and
	// re-resolved if the parent ever moves (structures do not, but components ride mobs and
	// items too). Null means "this level is not shared", which is the common case and the
	// one that keeps the plain z-level gate.
	var/datum/map_footprint/cached_footprint
	/// The turf cached_footprint was resolved from, so a moved parent invalidates it.
	var/turf/cached_footprint_turf

// Voidcrew: break the parent <-> spawn_callback reference cycle.
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
