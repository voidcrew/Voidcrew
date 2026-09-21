// Voidcrew extensions to code/modules/power/turbine/turbine.dm.

// Upstream tears the machine down on any Moved() because a single relocated turbine
// leaves its partners behind. A shuttle move relocates all three parts together with
// their relative positions (and any rotation) preserved, so that teardown just
// unscrewed and unlinked every ship turbine on every dock, undock and transit.
/obj/machinery/power/turbine/onShuttleMove(turf/newT, turf/oldT, list/movement_force, move_dir, obj/docking_port/stationary/old_dock, obj/docking_port/mobile/moving_dock)
	shuttle_moving = TRUE
	. = ..()
	shuttle_moving = FALSE

/obj/machinery/power/turbine/inlet_compressor/afterShuttleMove(turf/oldT, list/movement_force, shuttle_dir, shuttle_preferred_direction, move_dir, rotation)
	. = ..()
	input_turf = null //stale ref to the old site; compress_gases() lazily reacquires from the new location

/obj/machinery/power/turbine/turbine_outlet/afterShuttleMove(turf/oldT, list/movement_force, shuttle_dir, shuttle_preferred_direction, move_dir, rotation)
	. = ..()
	output_turf = null //stale ref to the old site; expel_gases() lazily reacquires from the new location

/obj/machinery/power/turbine/core_rotor/lateShuttleMove(turf/oldT, list/movement_force, move_dir)
	. = ..()
	if(!all_parts_connected)
		return
	//the cable under us can end up on a rebuilt powernet after the move (rotated docks
	//repropagate in /obj/structure/cable/lateShuttleMove); rebind to whatever is there now
	disconnect_from_network()
	connect_to_network()
// VOIDCREW EDIT ADDITION END

/obj/machinery/power/turbine
	///TRUE while a shuttle move is relocating us; Moved() skips its teardown so the assembly arrives intact (VOIDCREW EDIT ADDITION)
	var/shuttle_moving = FALSE
