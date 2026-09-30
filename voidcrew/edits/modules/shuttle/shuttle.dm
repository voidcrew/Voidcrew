// Voidcrew extensions to code/modules/shuttle/shuttle.dm.

/// The bounding box + z test alone. Subtypes layer extra membership checks onto
/// is_in_shuttle_bounds() (the mobile port also tests shuttle_areas); callers that
/// need to know whether something is PHYSICALLY within the footprint regardless of
/// area bookkeeping (voidcrew refresh_engines()) must use this directly.
/obj/docking_port/proc/is_in_shuttle_bounds_geometric(atom/A)
	var/turf/T = get_turf(A)
	if(!T || T.z != z)
		return FALSE
	var/list/bounds = return_coords()
	var/x0 = bounds[1]
	var/y0 = bounds[2]
	var/x1 = bounds[3]
	var/y1 = bounds[4]
	if(!ISINRANGE(T.x, min(x0, x1), max(x0, x1)))
		return FALSE
	if(!ISINRANGE(T.y, min(y0, y1), max(y0, y1)))
		return FALSE
	return TRUE
