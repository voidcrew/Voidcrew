/**
 * # Spread checkpoint loading
 *
 * The hidden copy of a checkpoint is read and initialized by the ordinary template loader, in
 * the same order as any other shuttle template. The map reader and the atom Initialize pass
 * already pause whenever a tick runs out; the passes after them (late initialization, lighting,
 * power and pipe networks, baseturfs, shuttle links) did not, so a large hull spent them all in
 * one tick. Here each of those passes keeps its order and its place in the sequence but may
 * pause between items. Nothing can reach the copy while it loads, and the job holds the shared
 * shuttle loader (atmos stays paused) for the whole load, so a pause changes when an item runs,
 * never what it sees.
 *
 * Loading in bands of rows was rejected: every band would release its own smoothing and late
 * initialization before the next band's neighbours existed. The reader's own pass over the
 * finished turfs and the reservation are shared with every other map load and are left alone.
 */
/datum/map_template/shuttle/voidcrew/commissioned/checkpoint
	/// Pause between items of the post-read passes. FALSE runs the stock all-at-once passes.
	var/spread_load = TRUE
	/// Phase name -> milliseconds, for the load that just ran.
	var/list/phase_ms
	var/phase_timer
	var/phase_started = 0
	/// What the load is doing now, for tick measurements.
	var/current_phase

/datum/map_template/shuttle/voidcrew/commissioned/checkpoint/proc/start_phases()
	phase_ms = list()
	phase_timer = "checkpoint_load_[REF(src)]"
	rustg_time_reset(phase_timer)
	phase_started = 0
	current_phase = "read"

/// Records the time since the previous mark under this phase name.
/datum/map_template/shuttle/voidcrew/commissioned/checkpoint/proc/mark_phase(phase)
	if(!phase_timer)
		return
	var/now = rustg_time_milliseconds(phase_timer)
	phase_ms[phase] += now - phase_started
	phase_started = now
	current_phase = "after [phase]"

/datum/map_template/shuttle/voidcrew/commissioned/checkpoint/load(turf/T, centered, register = TRUE)
	start_phases()
	return ..()

/// Mirrors /datum/map_template/proc/initTemplateBounds() step for step.
/datum/map_template/shuttle/voidcrew/commissioned/checkpoint/proc/init_bounds_spread(list/bounds)
	if(!bounds)
		stack_trace("[name] template failed to initialize correctly!")
		return
	mark_phase("rooms")
	var/list/obj/machinery/atmospherics/atmos_machines = list()
	var/list/obj/structure/cable/cables = list()
	var/list/atom/movable/movables = list()
	var/list/area/areas = list()
	var/list/turfs = block(
		bounds[MAP_MINX], bounds[MAP_MINY], bounds[MAP_MINZ],
		bounds[MAP_MAXX], bounds[MAP_MAXY], bounds[MAP_MAXZ]
	)
	for(var/turf/current_turf as anything in turfs)
		areas |= current_turf.loc
		if(!SSatoms.initialized)
			continue
		for(var/movable_in_turf in current_turf)
			if(istype(movable_in_turf, /obj/docking_port/mobile))
				continue // initialized by dispatch() once its bounds are known
			movables += movable_in_turf
			if(istype(movable_in_turf, /obj/structure/cable))
				cables += movable_in_turf
				continue
			if(istype(movable_in_turf, /obj/machinery/atmospherics))
				atmos_machines += movable_in_turf
	SSmapping.reg_in_areas_in_z(areas)
	if(!SSatoms.initialized)
		return
	initialize_atoms_spread(areas + turfs + movables)
	for(var/turf/unlit as anything in turfs)
		CHECK_TICK
		if(unlit.space_lit)
			continue
		var/area/loc_area = unlit.loc
		if(!loc_area.static_lighting)
			if(!loc_area.ambient_lighting || unlit.skips_lighting_object())
				continue
		unlit.lighting_build_overlay()
	mark_phase("lighting")
	setup_powernets_spread(cables)
	mark_phase("powernets")
	// Already pauses between machines.
	SSair.setup_template_machinery(atmos_machines)
	mark_phase("pipenets")
	var/list/template_and_bordering_turfs = block(
		bounds[MAP_MINX]-1, bounds[MAP_MINY]-1, bounds[MAP_MINZ],
		bounds[MAP_MAXX]+1, bounds[MAP_MAXY]+1, bounds[MAP_MAXZ]
	)
	for(var/turf/affected_turf as anything in template_and_bordering_turfs)
		CHECK_TICK
		affected_turf.air_update_turf(TRUE, TRUE)
		affected_turf.levelupdate()
	mark_phase("air_update")

/**
 * SSatoms.InitializeAtoms(), except that late initialization pauses between atoms. It still
 * starts only after every atom of the copy has run Initialize(), and deferred smoothing is still
 * released once, after all of them.
 */
/datum/map_template/shuttle/voidcrew/commissioned/checkpoint/proc/initialize_atoms_spread(list/atoms)
	if(SSatoms.initialized == INITIALIZATION_INSSATOMS)
		return
	var/source = "checkpoint load [REF(src)]"
	SSatoms.set_tracked_initalized(INITIALIZATION_INNEW_MAPLOAD, source)
	// Pauses on its own whenever the tick runs out.
	SSatoms.CreateAtoms(atoms, null, source)
	SSatoms.clear_tracked_initalize(source)
	SSicon_smooth.free_deferred(source)
	mark_phase("initialize")
	while(length(SSatoms.late_loaders))
		var/list/current_late_loaders = SSatoms.late_loaders
		SSatoms.late_loaders = list()
		for(var/atom/late as anything in current_late_loaders)
			CHECK_TICK
			if(QDELETED(late))
				continue
			late.LateInitialize()
	for(var/queued_deletion in SSatoms.queued_deletions)
		qdel(queued_deletion)
	SSatoms.queued_deletions.Cut()
	mark_phase("late_initialize")

/// SSmachines.setup_template_powernets(), pausing between networks.
/datum/map_template/shuttle/voidcrew/commissioned/checkpoint/proc/setup_powernets_spread(list/obj/structure/cable/cables)
	for(var/obj/structure/cable/cable as anything in cables)
		CHECK_TICK
		if(QDELETED(cable) || cable.powernet)
			continue
		var/datum/powernet/network = new()
		network.add_cable(cable)
		propagate_network(cable, cable.powernet)

/// Mirrors /datum/map_template/shuttle/proc/dispatch() and the voidcrew powernet rebuild.
/datum/map_template/shuttle/voidcrew/commissioned/checkpoint/dispatch(list/turfs, register = TRUE)
	if(!spread_load)
		. = ..()
		mark_phase("dispatch")
		return
	// A checkpoint never saves modular map roots, but wait them out like any shuttle would.
	while(TRUE)
		var/found = FALSE
		for(var/turf/current_turf in turfs)
			if(is_type_on_turf(current_turf, /obj/modular_map_root))
				found = TRUE
		if(found)
			sleep(5 DECISECONDS)
		else
			break
	for(var/i in 1 to turfs.len)
		CHECK_TICK
		var/turf/place = turfs[i]
		for(var/obj/docking_port/mobile/port in place)
			port.calculate_docking_port_information(src)
			SSatoms.InitializeAtoms(list(port))
			if(register)
				port.register()
		if(isspaceturf(place))
			continue
		if(place.count_baseturfs() < 2)
			continue
		place.insert_baseturf(3, /turf/baseturf_skipover/shuttle)
	mark_phase("baseturfs")
	var/list/cables = list()
	for(var/turf/place as anything in turfs)
		for(var/obj/structure/cable/cable in place)
			cables += cable
	if(length(cables))
		for(var/obj/structure/cable/cable as anything in cables)
			if(cable.powernet)
				qdel(cable.powernet)
		setup_powernets_spread(cables)
	mark_phase("dispatch")

/// Mirrors /datum/map_template/shuttle/post_load() and /obj/docking_port/mobile/proc/linkup().
/datum/map_template/shuttle/voidcrew/commissioned/checkpoint/post_load(obj/docking_port/mobile/M)
	if(!spread_load)
		. = ..()
		mark_phase("linkup")
		return
	if(movement_force)
		M.movement_force = movement_force.Copy()
	for(var/area/place as anything in M.shuttle_areas)
		place.connect_to_shuttle(TRUE, M, null)
		for(var/atom/individual_atoms in place)
			CHECK_TICK
			individual_atoms.connect_to_shuttle(TRUE, M, null)
	mark_phase("linkup")
