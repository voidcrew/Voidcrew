// Causes any affecting light sources to be queued for a visibility update, for example a door got opened.
/turf/proc/reconsider_lights()
	lighting_corner_NE?.vis_update()
	lighting_corner_SE?.vis_update()
	lighting_corner_SW?.vis_update()
	lighting_corner_NW?.vis_update()

/turf/proc/lighting_clear_overlay()
	if (lighting_object)
		qdel(lighting_object, force=TRUE)

// Builds a lighting object for us, but only if our area is dynamic.
/turf/proc/lighting_build_overlay()
	if (lighting_object)
		qdel(lighting_object, force=TRUE) //Shitty fix for lighting objects persisting after death

	new /atom/movable/lighting_object(null, src)

// Used to get a scaled lumcount.
/turf/proc/get_lumcount(minlum = 0, maxlum = 1)
	if (!lighting_object)
		return 1

	var/totallums = 0
	var/datum/lighting_corner/L
	L = lighting_corner_NE
	if (L)
		totallums += L.lum_r + L.lum_b + L.lum_g
	L = lighting_corner_SE
	if (L)
		totallums += L.lum_r + L.lum_b + L.lum_g
	L = lighting_corner_SW
	if (L)
		totallums += L.lum_r + L.lum_b + L.lum_g
	L = lighting_corner_NW
	if (L)
		totallums += L.lum_r + L.lum_b + L.lum_g


	totallums /= 12 // 4 corners, each with 3 channels, get the average.

	totallums = (totallums - minlum) / (maxlum - minlum)

	totallums += dynamic_lumcount

	return CLAMP01(totallums)

// Returns a boolean whether the turf is on soft lighting.
// Soft lighting being the threshold at which point the overlay considers
// itself as too dark to allow sight and see_in_dark becomes useful.
// So basically if this returns true the tile is unlit black.
/turf/proc/is_softly_lit()
	if (!lighting_object)
		return FALSE

	return !(luminosity || dynamic_lumcount)


///Proc to add movable sources of opacity on the turf and let it handle lighting code.
/turf/proc/add_opacity_source(atom/movable/new_source)
	LAZYADD(opacity_sources, new_source)
	if(opacity)
		return
	recalculate_directional_opacity()


///Proc to remove movable sources of opacity on the turf and let it handle lighting code.
/turf/proc/remove_opacity_source(atom/movable/old_source)
	LAZYREMOVE(opacity_sources, old_source)
	if(opacity) //Still opaque, no need to worry on updating.
		return
	recalculate_directional_opacity()


///Calculate on which directions this turfs block view.
/turf/proc/recalculate_directional_opacity()
	. = directional_opacity
	if(opacity)
		directional_opacity = ALL_CARDINALS
		if(. != directional_opacity)
			reconsider_lights()
		return
	directional_opacity = NONE
	if(opacity_sources)
		for(var/atom/movable/opacity_source as anything in opacity_sources)
			if(opacity_source.flags_1 & ON_BORDER_1)
				directional_opacity |= opacity_source.dir
			else //If fulltile and opaque, then the whole tile blocks view, no need to continue checking.
				directional_opacity = ALL_CARDINALS
				break
	else
		for(var/atom/movable/content as anything in contents)
			SEND_SIGNAL(content, COMSIG_TURF_NO_LONGER_BLOCK_LIGHT)
	if(. != directional_opacity && (. == ALL_CARDINALS || directional_opacity == ALL_CARDINALS))
		reconsider_lights() //The lighting system only cares whether the tile is fully concealed from all directions or not.

///Transfer the lighting of one area to another
/turf/proc/transfer_area_lighting(area/old_area, area/new_area)
	if(SSlighting.initialized && !space_lit)
		var/static_lighting_changed = (new_area.static_lighting != old_area.static_lighting)
		// VOIDCREW EDIT: remembered so the ambient bleed block below can tell whether this
		// transfer actually took our lighting object away. See voidcrew/edits/lighting.dm.
		var/had_lighting_object = !!lighting_object
		// END VOIDCREW EDIT
		if (static_lighting_changed)
			if (new_area.static_lighting)
				lighting_build_overlay()
			// VOIDCREW EDIT: a turf that lights itself inside an ambient-lit area - fallout
			// ground, a lava river - keeps its object, or its own light has nothing to render
			// on. Everything else on the dynamic side loses it exactly as upstream.
			else if(!new_area.ambient_lighting || skips_lighting_object())
				lighting_clear_overlay()
			// END VOIDCREW EDIT (was: else lighting_clear_overlay())
		// VOIDCREW EDIT: moving into ambient-lit ground from another DYNAMIC area does not
		// trip static_lighting_changed, but the object still has to go - that ground carries
		// none at all.
		else if(lighting_object && skips_lighting_object())
			lighting_clear_overlay()
		// END VOIDCREW EDIT

		// VOIDCREW EDIT: ambient bleed. Changing area without changing type - a ship
		// landing or taking off, a room being repainted, cave generation claiming a tile -
		// changes both whether we bleed light ourselves and whether we are something worth
		// bleeding onto, and nothing else on this path notices. See
		// voidcrew/edits/lighting.dm.
		if(static_lighting_changed || new_area.ambient_lighting != old_area.ambient_lighting || new_area.base_lighting_alpha != old_area.base_lighting_alpha || new_area.base_lighting_color != old_area.base_lighting_color)
			update_ambient_bleed()
		// Losing our lighting object is the side nothing else covers: it leaves the tiles
		// around us lighting something that no longer reads light sources at all. Gaining one
		// already wakes them through /datum/lighting_object/New().
		if(had_lighting_object && !lighting_object)
			reconsider_ambient_bleed_neighbors()
		// END VOIDCREW EDIT

	// We will only run this logic on turfs off the prime z layer
	// Since on the prime z layer, we use an overlay on the area instead, to save time
	if(z <= length(SSmapping.z_level_to_plane_offset) && SSmapping.z_level_to_plane_offset[z])
		var/index = SSmapping.z_level_to_plane_offset[z] + 1
		//Inherit overlay of new area
		if(old_area.lighting_effects && index <= length(old_area.lighting_effects))
			cut_overlay(old_area.lighting_effects[index])
		if(new_area.lighting_effects && index <= length(new_area.lighting_effects))
			add_overlay(new_area.lighting_effects[index])

	// Manage removing/adding starlight overlays, we'll inherit from the area so we can drop it if the area has it already
	if(space_lit)
		if(!new_area.lighting_effects && old_area.lighting_effects)
			overlays += GLOB.starlight_overlays[GET_TURF_PLANE_OFFSET(src) + 1]
		else if (new_area.lighting_effects && !old_area.lighting_effects)
			overlays -= GLOB.starlight_overlays[GET_TURF_PLANE_OFFSET(src) + 1]
