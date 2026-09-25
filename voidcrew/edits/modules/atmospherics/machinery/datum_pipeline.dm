// Voidcrew extensions to code/modules/atmospherics/machinery/datum_pipeline.dm.

/**
 * VOIDCREW ADDITION: TRUE if anything real is still attached to this pipeline.
 *
 * Not the same question as `length(members)`. When a machine is hard deleted its entries
 * in these lists are nulled in place rather than removed, so a pipeline that has lost
 * everything still reads as length 1 with a null inside. `as anything` is deliberate for
 * exactly that reason - a typed loop would silently filter the nulls out and hide the
 * distinction we are trying to measure.
 */
/datum/pipeline/proc/has_live_members()
	for(var/obj/machinery/atmospherics/member as anything in members)
		if(!isnull(member) && !QDELETED(member))
			return TRUE
	for(var/obj/machinery/atmospherics/machine as anything in other_atmos_machines)
		if(!isnull(machine) && !QDELETED(machine))
			return TRUE
	return FALSE

/datum/pipeline
	/// VOIDCREW ADDITION: consecutive orphan sweeps this pipeline has been found with no
	/// live members on. Reset the moment it has any. See SSair.reap_orphan_pipelines().
	var/orphan_strikes = 0
