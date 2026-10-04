// Voidcrew extensions to code/datums/components/gps.dm.

// VOIDCREW EDIT ADDITION: overridable hook so voidcrew can filter cross-z
// signals by overmap locality (voidcrew/edits/gps.dm). Default: upstream behavior.
/// Whether a signal at pos should be listed for a unit located at curr.
/datum/component/gps/item/proc/is_signal_visible(turf/curr, turf/pos)
	if(global_mode)
		return TRUE
	return pos.z == curr.z
