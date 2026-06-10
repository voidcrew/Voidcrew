/**
 * # Mission GPS Link
 *
 * Voidcrew extension to handheld GPS units: mission objective beacons are
 * uploaded to a SPECIFIC unit (tap the GPS on the mission board console)
 * rather than broadcast to every GPS in the world via GLOB.GPS_list.
 *
 * Uploaded signals render alongside normal signals in the existing GPS UI.
 */
/datum/component/gps/item
	/// Mission beacons uploaded to this specific unit: assoc tag -> weakref of the tracked atom
	var/list/linked_mission_signals

/**
 * Adds (or retargets) a mission beacon on this unit.
 */
/datum/component/gps/item/proc/add_mission_signal(tag, atom/movable/target)
	if(!tag || QDELETED(target))
		return
	LAZYSET(linked_mission_signals, tag, WEAKREF(target))

/**
 * Removes a mission beacon from this unit.
 */
/datum/component/gps/item/proc/remove_mission_signal(tag)
	LAZYREMOVE(linked_mission_signals, tag)

/datum/component/gps/item/ui_data(mob/user)
	. = ..()
	if(!tracking || emped || !LAZYLEN(linked_mission_signals))
		return
	var/turf/curr = get_turf(parent)
	for(var/tag in linked_mission_signals.Copy())
		var/datum/weakref/target_ref = linked_mission_signals[tag]
		var/atom/movable/target = target_ref?.resolve()
		if(QDELETED(target))
			LAZYREMOVE(linked_mission_signals, tag)
			continue
		var/turf/pos = get_turf(target)
		if(!pos || (!global_mode && pos.z != curr.z))
			continue
		var/list/signal = list()
		signal["entrytag"] = tag
		signal["coords"] = "[pos.x], [pos.y], [pos.z]"
		if(pos.z == curr.z)
			signal["dist"] = max(get_dist(curr, pos), 0)
			signal["degrees"] = round(get_angle(curr, pos))
		else
			var/angle = get_linked_z_angle(curr.z, pos.z)
			if(!isnull(angle))
				signal["degrees"] = angle
		.["signals"] += list(signal)
