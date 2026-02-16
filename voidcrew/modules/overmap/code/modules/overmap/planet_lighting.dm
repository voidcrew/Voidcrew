/**
 * ## Stored Lighting State
 *
 * Saves an area's original lighting configuration so it can be restored
 * when a ship undocks from a planet surface.
 */
/datum/component/stored_lighting_state
	var/original_static_lighting
	var/original_base_lighting_alpha
	var/original_base_lighting_color

/datum/component/stored_lighting_state/Initialize(...)
	if(!isarea(parent))
		return COMPONENT_INCOMPATIBLE
	var/area/A = parent
	original_static_lighting = A.static_lighting
	original_base_lighting_alpha = A.base_lighting_alpha
	original_base_lighting_color = A.base_lighting_color

/**
 * Enforces flat ambient lighting on an area for planet surfaces.
 * Converts static_lighting to base_lighting so there are no lighting
 * boundary artifacts between areas on the same z-level.
 *
 * Idempotent - returns early if the area already has static_lighting = FALSE.
 */
/proc/enforce_planet_surface_lighting(area/target_area)
	if(!target_area.static_lighting)
		return
	// Save original state for later restoration
	target_area.AddComponent(/datum/component/stored_lighting_state)
	// Disable static lighting and remove existing lighting objects
	target_area.static_lighting = FALSE
	target_area.remove_area_lighting_objects()
	// Enable flat ambient lighting
	target_area.base_lighting_alpha = 200
	target_area.base_lighting_color = COLOR_WHITE
	target_area.update_base_lighting()

/**
 * Restores an area's original lighting configuration after leaving a planet surface.
 * Only acts if the area has a stored_lighting_state component (i.e., was previously enforced).
 */
/proc/restore_area_lighting(area/target_area)
	var/datum/component/stored_lighting_state/stored = target_area.GetComponent(/datum/component/stored_lighting_state)
	if(!stored)
		return
	// Restore original values
	target_area.static_lighting = stored.original_static_lighting
	target_area.base_lighting_alpha = stored.original_base_lighting_alpha
	target_area.base_lighting_color = stored.original_base_lighting_color
	// Rebuild lighting objects if static lighting was originally enabled
	if(target_area.static_lighting)
		target_area.create_area_lighting_objects()
	target_area.update_base_lighting()
	// Clean up the component
	qdel(stored)
