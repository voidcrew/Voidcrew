// Voidcrew extensions to code/modules/shuttle/mobile_port/shuttle_move_callbacks.dm.

/obj/structure/cable/shuttleRotate(rotation, params)
	. = ..()
	// linked_dirs is direction data like any dir, so a rotated landing must rotate it
	// too. afterShuttleMove()'s powernet rebuild walks the grid through EVERY cable's
	// linked_dirs (get_cable_connections()), not just the cable being reconnected, so
	// one cable still carrying pre-rotation bits stalls the walk there and strands
	// everything beyond it on a separate, sourceless powernet - wired but dead.
	if(!linked_dirs)
		return
	var/rotated_dirs = 0
	for(var/check_dir in GLOB.cardinals)
		if(linked_dirs & check_dir)
			rotated_dirs |= angle2dir(rotation + dir2angle(check_dir))
	linked_dirs = rotated_dirs

/obj/structure/cable/lateShuttleMove(turf/oldT, list/movement_force, move_dir)
	. = ..()
	// Deliberately NOT in afterShuttleMove(): the powernet walk trusts every walked
	// cable's linked_dirs, and those are only per-cable correct as each cable's
	// afterShuttleMove() runs. Propagating from the first landed cable while later
	// cables still carry stale bits splits one physical grid into several nets, and
	// propagate_if_no_network() never revisits a cable that has one. By the late
	// pass every cable has relinked, so the first propagate covers the whole grid.
	propagate_if_no_network()
