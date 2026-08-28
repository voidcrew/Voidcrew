/// AIs will attack this as a potential target if they see it
/datum/element/hostile_machine
	element_flags = ELEMENT_DETACH_ON_HOST_DESTROY

/datum/element/hostile_machine/Attach(datum/target)
	. = ..()

	if (!isatom(target))
		return ELEMENT_INCOMPATIBLE

#ifdef UNIT_TESTS
	if(!GLOB.target_interested_atoms[target.type])
		stack_trace("Tried to make a hostile machine without updating ai targeting to include it, they must be synced")
#endif

	if(ismovable(target))
		RegisterSignal(target, COMSIG_MOVABLE_Z_CHANGED, PROC_REF(on_z_change))

	add_to_z(target)

/datum/element/hostile_machine/Detach(datum/source)
	UnregisterSignal(source, COMSIG_MOVABLE_Z_CHANGED)
	remove_from_z(source)

	// Belt and braces. This is the last chance to let go of the target before it is deleted, and
	// remove_from_z() can only strip the bucket for the z it is standing on *now* - anything that
	// ever relocates it without COMSIG_MOVABLE_Z_CHANGED leaves a ref in the bucket it used to be
	// filed under, which turns an ordinary qdel into a hard delete. Cheap: one pass over a
	// handful of z buckets, on a proc that only runs when the machine is going away.
	for(var/z in GLOB.hostile_machines_by_z.Copy())
		var/list/machines_on_z = GLOB.hostile_machines_by_z[z]
		machines_on_z -= source
		if(!length(machines_on_z))
			GLOB.hostile_machines_by_z -= z

	return ..()

/datum/element/hostile_machine/proc/on_z_change(atom/movable/source, turf/old_turf, turf/new_turf, same_z_layer)
	SIGNAL_HANDLER

	// Deliberately ignores same_z_layer. GLOB.hostile_machines_by_z is keyed by z, but
	// same_z_layer compares RENDERING plane offsets (GET_TURF_PLANE_OFFSET), which are 0 for
	// every z that is not part of a stacked multi-z group - so it is TRUE for essentially every
	// ordinary z-to-z move, and the signal only fires when the z genuinely changed in the first
	// place. Bailing on it left the machine indexed under the z it was built on forever.
	//
	// That is not a rounding error on this fork: every hull is loaded on a staging z and then
	// moved to its own, so every mapped ship turret stayed pinned in the staging bucket. It
	// survived its own hull's teardown (a hard delete, since Detach() strips the bucket it is
	// standing on now, not the one it is filed under) and left AI target scans walking a bucket
	// full of dead turrets for anything standing on the staging level.
	if(old_turf)
		remove_from_z(source, old_turf.z)
	add_to_z(source, new_turf?.z)

/datum/element/hostile_machine/proc/add_to_z(atom/target, z)
	if(isnull(z))
		var/turf/target_turf = get_turf(target)
		z = target_turf?.z
	if(!z)
		return
	if(!GLOB.hostile_machines_by_z[z])
		GLOB.hostile_machines_by_z[z] = list()
	GLOB.hostile_machines_by_z[z] |= target

/datum/element/hostile_machine/proc/remove_from_z(atom/target, z)
	if(isnull(z))
		var/turf/target_turf = get_turf(target)
		z = target_turf?.z
	if(!z)
		return
	GLOB.hostile_machines_by_z[z] -= target
	if(!length(GLOB.hostile_machines_by_z[z]))
		GLOB.hostile_machines_by_z -= z
