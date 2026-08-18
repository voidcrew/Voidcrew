/turf
	var/datum/biome/generating_biome

// Takes almost everything from its Tg parent, adds in lighting pass changes
/turf/ChangeTurf(path, list/new_baseturfs, flags)
	switch(path)
		if(null)
			return
		if(/turf/baseturf_bottom)
			path = SSmapping.level_trait(z, ZTRAIT_BASETURF) || /turf/open/space
			if (!ispath(path))
				path = text2path(path)
				if (!ispath(path))
					warning("Z-level [z] has invalid baseturf '[SSmapping.level_trait(z, ZTRAIT_BASETURF)]'")
					path = /turf/open/space
		if(/turf/open/space/basic)
			// basic doesn't initialize and this will cause issues
			// no warning though because this can happen naturaly as a result of it being built on top of
			path = /turf/open/space

	if(!GLOB.use_preloader && path == type && !(flags & CHANGETURF_FORCEOP) && (baseturfs == new_baseturfs)) // Don't no-op if the map loader requires it to be reconstructed, or if this is a new set of baseturfs
		return src
	if(flags & CHANGETURF_SKIP)
		return new path(src)

	var/old_lighting_object = lighting_object
	var/old_lighting_corner_NE = lighting_corner_NE
	var/old_lighting_corner_SE = lighting_corner_SE
	var/old_lighting_corner_SW = lighting_corner_SW
	var/old_lighting_corner_NW = lighting_corner_NW
	var/old_directional_opacity = directional_opacity
	var/old_dynamic_lumcount = dynamic_lumcount
	var/old_rcd_memory = rcd_memory
	var/old_explosion_throw_details = explosion_throw_details
	var/old_opacity = opacity

	// I'm so sorry brother
	// This is used for a starlight optimization
	var/old_light_range = light_range
	// We get just the bits of explosive_resistance that aren't the turf
	var/old_explosive_resistance = explosive_resistance - get_explosive_block()
	var/old_lattice_underneath = lattice_underneath

	var/old_bp = blueprint_data
	blueprint_data = null

	var/list/old_baseturfs = baseturfs
	var/old_type = type
	var/datum/weakref/old_ref = weak_reference
	weak_reference = null

	var/list/post_change_callbacks = list()
	SEND_SIGNAL(src, COMSIG_TURF_CHANGE, path, new_baseturfs, flags, post_change_callbacks)

	changing_turf = TRUE
	qdel(src) //Just get the side effects and call Destroy
	//We do this here so anything that doesn't want to persist can clear itself
	var/list/old_listen_lookup = _listen_lookup?.Copy()
	var/list/old_signal_procs = _signal_procs?.Copy()
	var/carryover_turf_flags = (RESERVATION_TURF | UNUSED_RESERVATION_TURF) & turf_flags
	var/turf/new_turf = new path(src)
	new_turf.turf_flags |= carryover_turf_flags

	// WARNING WARNING
	// Turfs DO NOT lose their signals when they get replaced, REMEMBER THIS
	// It's possible because turfs are fucked, and if you have one in a list and it's replaced with another one, the list ref points to the new turf
	if(old_listen_lookup)
		LAZYOR(new_turf._listen_lookup, old_listen_lookup)
	if(old_signal_procs)
		LAZYOR(new_turf._signal_procs, old_signal_procs)

	for(var/datum/callback/callback as anything in post_change_callbacks)
		callback.InvokeAsync(new_turf)

	if(new_baseturfs)
		new_turf.baseturfs = baseturfs_string_list(new_baseturfs, new_turf)
	else
		new_turf.baseturfs = baseturfs_string_list(old_baseturfs, new_turf) //Just to be safe

	if(!(flags & CHANGETURF_DEFER_CHANGE))
		new_turf.AfterChange(flags, old_type)

	new_turf.blueprint_data = old_bp
	new_turf.rcd_memory = old_rcd_memory
	new_turf.explosion_throw_details = old_explosion_throw_details
	new_turf.explosive_resistance += old_explosive_resistance

	lighting_corner_NE = old_lighting_corner_NE
	lighting_corner_SE = old_lighting_corner_SE
	lighting_corner_SW = old_lighting_corner_SW
	lighting_corner_NW = old_lighting_corner_NW

	dynamic_lumcount = old_dynamic_lumcount

	lattice_underneath = old_lattice_underneath

	new_turf.weak_reference = old_ref

	if(SSlighting.initialized)
		// Space tiles should never have lighting objects
		if(!space_lit)
			// VOIDCREW EDIT: mirror the area gate that SSlighting.create_all_lighting_objects()
			// and map_template.dm both apply. Without it every mid-round ChangeTurf into a
			// static_lighting = FALSE area (/area/overmap, /area/centcom/asteroid/voidcrew,
			// /area/space, holodecks) accretes a lighting object that roundstart init
			// deliberately skipped, and nothing ever reclaims it. Every non-static area in the
			// tree also sets base_lighting_alpha, so the turf stays lit by the area's overlay;
			// and if the turf's area later becomes static-lit, transfer_area_lighting() builds
			// the object then.
			var/area/lit_area = new_turf.loc
			if(!lit_area || lit_area.static_lighting)
				// A nested ChangeTurf inside new path(src) - e.g. /turf/closed/mineral/random
				// rerolling its ore type during Initialize - can already have built a lighting
				// object for this spot. Blindly building another one here double-assigns and
				// stack-traces ("a lighting object was assigned to a turf that already had a
				// lighting object!") on every mid-round terrain generation pass. Reuse whichever
				// object survives. (This mirrors the same guard in code/game/turfs/change_turf.dm,
				// which never runs: this body is the outermost link of the duplicate-definition
				// chain and does not call ..().)
				if(old_lighting_object && lighting_object && lighting_object != old_lighting_object)
					qdel(lighting_object, force = TRUE) // drop the nested duplicate, keep the original
				// Should have a lighting object if we never had one
				lighting_object = old_lighting_object || lighting_object || new /datum/lighting_object(src)
			else
				// Non-static area: same outcome transfer_area_lighting() reaches via
				// lighting_clear_overlay() when a turf moves into one. Drop a nested duplicate
				// first, since qdel'ing the old object nulls the turf's pointer either way.
				if(lighting_object && lighting_object != old_lighting_object)
					qdel(lighting_object, force = TRUE)
				if(old_lighting_object)
					qdel(old_lighting_object, force = TRUE)
			// END VOIDCREW EDIT
		else if (old_lighting_object)
			qdel(old_lighting_object, force = TRUE)

		directional_opacity = old_directional_opacity
		recalculate_directional_opacity()

		if(lighting_object && !lighting_object.needs_update)
			lighting_object.update()

	// If we're space, then we're either lit, or not, and impacting our neighbors, or not
	if(isspaceturf(src))
		var/turf/open/space/lit_turf = src
		// This also counts as a removal, so we need to do a full rebuild
		if(!ispath(old_type, /turf/open/space))
			lit_turf.update_starlight()
			for(var/turf/open/space/space_tile in RANGE_TURFS(1, src) - src)
				space_tile.update_starlight()
		else if(old_light_range)
			lit_turf.enable_starlight()

	// If we're a cordon we count against a light, but also don't produce any ourselves
	else if (istype(src, /turf/cordon))
		// This counts as removing a source of starlight, so we need to update the space tile to inform it
		if(!ispath(old_type, /turf/open/space))
			for(var/turf/open/space/space_tile in RANGE_TURFS(1, src))
				space_tile.update_starlight()

	// If we're not either, but were formerly a space turf, then we want light
	else if(ispath(old_type, /turf/open/space))
		for(var/turf/open/space/space_tile in RANGE_TURFS(1, src))
			space_tile.enable_starlight()

	if(old_opacity != opacity && SSticker)
		GLOB.cameranet.bareMajorChunkChange(src)

	// We will only run this logic if the tile is not on the prime z layer, since we use area overlays to cover that
	if(z <= length(SSmapping.z_level_to_plane_offset) && SSmapping.z_level_to_plane_offset[z])
		var/area/our_area = new_turf.loc
		if(our_area.lighting_effects)
			var/plane_offset = SSmapping.z_level_to_plane_offset[z]
			if(plane_offset + 1 <= length(our_area.lighting_effects))
				new_turf.add_overlay(our_area.lighting_effects[plane_offset + 1])

	// only queue for smoothing if SSatom initialized us, and we'd be changing smoothing state
	if(flags_1 & INITIALIZED_1)
		QUEUE_SMOOTH_NEIGHBORS(src)
		QUEUE_SMOOTH(src)

	return new_turf
