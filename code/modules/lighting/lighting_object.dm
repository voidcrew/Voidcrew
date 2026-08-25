/atom/movable/lighting_object
	name = ""
	anchored = TRUE
	plane = LIGHTING_PLANE
	icon = LIGHTING_ICON
	icon_state = null
	color = null //we manually set color in init instead
	appearance_flags = RESET_COLOR | RESET_ALPHA | RESET_TRANSFORM
	mouse_opacity = MOUSE_OPACITY_TRANSPARENT
	invisibility = INVISIBILITY_LIGHTING
	move_resist = INFINITY
	///whether we are already in the SSlighting.objects_queue list
	var/needs_update = FALSE

	///the turf that our light is applied to
	var/turf/affected_turf

/atom/movable/lighting_object/Initialize(mapload, turf/affected_turf)
	if(!isnull(loc))
		if(isturf(loc))
			affected_turf = loc
			moveToNullspace()
			stack_trace("a lighting object was improperly initialized - they should have a null loc, with the affected turf being the second argument")
		else
			qdel(src, force = TRUE)
			CRASH("a lighting object tried to be spawned for a non-turf!")
	if(!isturf(affected_turf))
		qdel(src, force = TRUE)
		CRASH("a lighting object was assigned to [affected_turf], a non turf!")

	. = ..()

	verbs.Cut()

	src.affected_turf = affected_turf
	layer = affected_turf.z * 0.01
	if(SSmapping.max_plane_offset)
		// generates the offset lighting plane to use. NOTE: this assumes the turf lighting
		// plane is ALWAYS offsettable which is technically dependent on a plane master var.
		// checking for that is slower and this is hot enough that this is a worthwhile risk to take
		plane = LIGHTING_PLANE - (PLANE_RANGE * GET_Z_PLANE_OFFSET(affected_turf.z))
	if (affected_turf.lighting_object)
		qdel(affected_turf.lighting_object, force = TRUE)
		stack_trace("a lighting object was assigned to a turf that already had a lighting object!")

	affected_turf.lighting_object = src
	affected_turf.vis_contents += src
	// Default to fullbright, so things can "see" if they use view() before we update
	affected_turf.luminosity = 1

	// This path is really hot. this is faster
	// Really this should be a global var or something, but lets not think about that yes?
	for(var/turf/open/space/space_tile in RANGE_TURFS(1, affected_turf))
		space_tile.enable_starlight()

	// VOIDCREW EDIT: ambient bleed, the same wake-up the loop above does for starlight,
	// generalised to any area that paints its light on the area instead of on its turfs
	// (ambient_lighting - planet surfaces). Those turfs carry no lighting objects and emit
	// nothing, so this brand new statically lit tile would render as a hard black edge
	// against bright ground unless the ground around it lights up for it. Only a tile that
	// is actually a dark edge is worth waking anything for - a tile whose own area paints it
	// has nothing to gain - and the area reads are inlined ahead of any proc call, because
	// this path is really hot. See voidcrew/edits/lighting.dm.
	var/area/lit_area = affected_turf.loc
	if(!lit_area.ambient_lighting && !istype(affected_turf, /turf/cordon))
		for(var/turf/bleed_tile as anything in RANGE_TURFS(1, affected_turf))
			var/area/bleed_area = bleed_tile.loc
			if(!bleed_area.ambient_lighting || bleed_area.static_lighting || !bleed_area.base_lighting_alpha)
				continue
			bleed_tile.enable_ambient_bleed(bleed_area)
	// END VOIDCREW EDIT

	needs_update = TRUE
	SSlighting.objects_queue += src

/atom/movable/lighting_object/Destroy(force)
	if (!force)
		return QDEL_HINT_LETMELIVE
	SSlighting.objects_queue -= src
	if (isturf(affected_turf))
		affected_turf.vis_contents -= src
		affected_turf.lighting_object = null
		affected_turf.luminosity = 1
	affected_turf = null
	return ..()

/atom/movable/lighting_object/proc/update()
	var/turf/affected_turf = src.affected_turf

	// To the future coder who sees this and thinks
	// "Why didn't he just use a loop?"
	// Well my man, it's because the loop performed like shit.
	// And there's no way to improve it because
	// without a loop you can make the list all at once which is the fastest you're gonna get.
	// Oh it's also shorter line wise.
	// Including with these comments.

	var/static/datum/lighting_corner/dummy/dummy_lighting_corner = new

#ifdef VISUALIZE_LIGHT_UPDATES
	affected_turf.add_atom_colour(COLOR_BLUE_LIGHT, ADMIN_COLOUR_PRIORITY)
	animate(affected_turf, 10, color = null)
	addtimer(CALLBACK(affected_turf, TYPE_PROC_REF(/atom, remove_atom_colour), ADMIN_COLOUR_PRIORITY, COLOR_BLUE_LIGHT), 10, TIMER_UNIQUE|TIMER_OVERRIDE)
#endif

	var/datum/lighting_corner/red_corner = affected_turf.lighting_corner_SW || dummy_lighting_corner
	var/datum/lighting_corner/green_corner = affected_turf.lighting_corner_SE || dummy_lighting_corner
	var/datum/lighting_corner/blue_corner = affected_turf.lighting_corner_NW || dummy_lighting_corner
	var/datum/lighting_corner/alpha_corner = affected_turf.lighting_corner_NE || dummy_lighting_corner

	var/max = max(red_corner.largest_color_luminosity, green_corner.largest_color_luminosity, blue_corner.largest_color_luminosity, alpha_corner.largest_color_luminosity)


	#if LIGHTING_SOFT_THRESHOLD != 0
	var/set_luminosity = max > LIGHTING_SOFT_THRESHOLD
	#else
	// Because of floating points™?, it won't even be a flat 0.
	// This number is mostly arbitrary.
	var/set_luminosity = max > 1e-6
	#endif

	if(!set_luminosity)
		icon_state = "lighting_dark"
		color = null
	else
		icon_state = null
		color = list(
			red_corner.cache_r, red_corner.cache_g, red_corner.cache_b, 00,
			green_corner.cache_r, green_corner.cache_g, green_corner.cache_b, 00,
			blue_corner.cache_r, blue_corner.cache_g, blue_corner.cache_b, 00,
			alpha_corner.cache_r, alpha_corner.cache_g, alpha_corner.cache_b, 00,
			00, 00, 00, 01
		)

	// VOIDCREW EDIT: an area with active base lighting is lit by a BLEND_ADD overlay on
	// the area, not by light sources on its turfs, so every corner here reads dark and
	// set_luminosity comes out 0. BYOND culls a luminosity 0 lighting object's tile out of
	// clients' view, which on a base-lit planet surface would leave the ground looking
	// bright while every mob and item standing on it went invisible. Floor those tiles at
	// luminosity 1. One var deref, no proc call - this proc is the hot one.
	// (Upstream moved this var off the turf and onto the lighting object itself; the turf
	// is held at 1 by Initialize()/Destroy() now.)
	var/area/turf_area = affected_turf.loc
	luminosity = set_luminosity || turf_area.area_has_base_lighting
	// END VOIDCREW EDIT (was: luminosity = set_luminosity)

// Variety of overrides so the overlays don't get affected by weird things.

/atom/movable/lighting_object/ex_act(severity)
	return FALSE

/atom/movable/lighting_object/singularity_act()
	return

/atom/movable/lighting_object/singularity_pull()
	return

/atom/movable/lighting_object/blob_act()
	return

/atom/movable/lighting_object/on_changed_z_level(turf/old_turf, turf/new_turf, same_z_layer, notify_contents = TRUE)
	SHOULD_CALL_PARENT(FALSE)
	return

/atom/movable/lighting_object/wash(clean_types)
	SHOULD_CALL_PARENT(FALSE) // lighting objects are dirty, confirmed
	return

// Override here to prevent things accidentally moving around overlays.
/atom/movable/lighting_object/forceMove(atom/destination, no_tp = FALSE, harderforce = FALSE)
	if(harderforce)
		return ..()

/atom/movable/lighting_object/ref_search_details()
	return "[text_ref(src)] (turf: [affected_turf ? "[affected_turf.type] @ [AREACOORD(affected_turf)]" : "null"] needs_update: [needs_update ? "true" : "false"])"
