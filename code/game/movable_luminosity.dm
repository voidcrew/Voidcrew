///Keeps track of the sources of dynamic luminosity and updates our visibility with the highest.
/atom/movable/proc/update_dynamic_luminosity()
	var/highest = 0
	for(var/i in affected_dynamic_lights)
		if(affected_dynamic_lights[i] <= highest)
			continue
		highest = affected_dynamic_lights[i]
	if(highest == affecting_dynamic_lumi)
		return
	luminosity -= affecting_dynamic_lumi
	affecting_dynamic_lumi = highest
	luminosity += affecting_dynamic_lumi


///Helper to change several lighting overlay settings.
/atom/movable/proc/set_light_range_power_color(range, power, color)
	set_light_range(range)
	set_light_power(power)
	set_light_color(color)


/**
 * Makes every overlay light we're carrying work out where it is again.
 *
 * Overlay lights only re-resolve their holder when they personally move, so gear that
 * was in someone's hands or pockets while they sat inside a machine never learns that
 * they climbed out of it, and stays dark until it is dropped and picked back up.
 * Call this after moving a mob out of something it was inside of.
 */
/atom/movable/proc/recheck_contained_lights()
	for(var/atom/movable/carried as anything in get_all_contents())
		var/datum/component/overlay_lighting/light = carried.GetComponent(/datum/component/overlay_lighting)
		light?.recheck_holder()
