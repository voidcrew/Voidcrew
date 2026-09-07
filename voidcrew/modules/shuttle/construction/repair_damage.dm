/**
 * Sparse, round-local damage journal. Intact ships have no per-tile repair data.
 * The existing ship mass listener supplies turf losses before replacement; object
 * damage/deconstruction supplies fixtures. Never scan the hull or copy a layout.
 */
SUBSYSTEM_DEF(ship_repairs)
	name = "Ship repairs"
	flags = SS_BACKGROUND | SS_NO_INIT
	priority = FIRE_PRIORITY_PROCESS
	wait = 0.5 SECONDS
	/// Only areas of consoles with tracking enabled. One lookup on fixture damage.
	var/list/area_controllers = list()
	/// Workers with pending repairs or a recall, never idle fleets.
	var/list/workers = list()
	var/worker_cursor = 1
	var/record_count = 0
	var/steps_left = 0

/datum/controller/subsystem/ship_repairs/fire(resumed = FALSE)
	if(!resumed)
		steps_left = min(SHIP_REPAIR_WORK_BUDGET, length(workers))
	while(steps_left > 0 && length(workers))
		steps_left--
		if(worker_cursor > length(workers))
			worker_cursor = 1
		var/obj/structure/ship_repair_drone/drone = workers[worker_cursor]
		worker_cursor++
		if(QDELETED(drone))
			workers -= drone
		else
			drone.process(wait * 0.1)
		if(MC_TICK_CHECK)
			return

/datum/controller/subsystem/ship_repairs/stat_entry(msg)
	return ..("Workers:[length(workers)] Records:[record_count]/[SHIP_REPAIR_GLOBAL_RECORD_LIMIT]")

/obj/docking_port/mobile
	var/datum/weakref/ship_repair_controller

/// Shared by queued construction and the damage journal. Follows ship rotation.
/obj/effect/ship_repair_origin
	name = "construction coordinate origin"
	invisibility = INVISIBILITY_ABSTRACT
	anchored = TRUE
	resistance_flags = INDESTRUCTIBLE

/datum/ship_repair_record
	var/offset_x
	var/offset_y
	var/list/layers = list()
	var/obj/structure/ship_repair_drone/claimed_by
	var/retry_after = 0
	/// Only the temporary holofan projected for this record, never a crew-placed fan.
	var/obj/structure/holosign/barrier/atmos/emergency_seal

/datum/ship_repair_record/Destroy()
	SSship_repairs.record_count--
	QDEL_NULL(emergency_seal)
	if(claimed_by)
		claimed_by.release_job()
	layers = null
	return ..()

/obj/machinery/computer/camera_advanced/base_construction/ship
	var/list/repair_records = list()
	var/list/repair_areas = list()
	var/obj/effect/ship_repair_origin/repair_origin
	var/datum/weakref/repair_port
	var/repair_tracking = FALSE
	var/repair_applying = FALSE
	var/repair_overflow = 0

/obj/machinery/computer/camera_advanced/base_construction/ship/proc/repair_coordinate_key(turf/target)
	var/list/offset = construction_offset(target, repair_origin)
	return "[offset[1]],[offset[2]]"

/obj/machinery/computer/camera_advanced/base_construction/ship/proc/repair_record_turf(datum/ship_repair_record/record)
	if(QDELETED(repair_origin))
		return null
	var/angle = dir2angle(repair_origin.dir)
	return locate(repair_origin.x + round(record.offset_x * cos(angle) + record.offset_y * sin(angle)), repair_origin.y + round(-record.offset_x * sin(angle) + record.offset_y * cos(angle)), repair_origin.z)

/obj/machinery/computer/camera_advanced/base_construction/ship/proc/set_repair_tracking(enabled)
	if(!enabled)
		repair_tracking = FALSE
		return TRUE
	var/obj/docking_port/mobile/port = get_docking_port()
	if(!(console_upgrades & SHIP_CONSTRUCTION_UPGRADE_REPAIR) || !port)
		return FALSE
	var/obj/machinery/computer/camera_advanced/base_construction/ship/other = port.ship_repair_controller?.resolve()
	if(other && other != src)
		repair_status = "Another console controls this ship's repairs."
		return FALSE
	if(repair_port && repair_port.resolve() != port)
		clear_repair_journal(TRUE)
	if(!repair_origin)
		repair_origin = new(get_turf(src))
		repair_origin.setDir(dir)
	repair_port = WEAKREF(port)
	port.ship_repair_controller = WEAKREF(src)
	repair_tracking = TRUE
	refresh_repair_areas()
	repair_status = "Monitoring hull damage."
	return TRUE

/obj/machinery/computer/camera_advanced/base_construction/ship/proc/refresh_repair_areas()
	if(!repair_tracking)
		return
	var/obj/docking_port/mobile/port = repair_port?.resolve()
	for(var/area/ship_area as anything in repair_areas.Copy())
		if(port?.shuttle_areas[ship_area] && !hull_area_is_guest(ship_area, port))
			continue
		if(SSship_repairs.area_controllers[ship_area] == src)
			SSship_repairs.area_controllers -= ship_area
		repair_areas -= ship_area
	for(var/area/ship_area as anything in port?.shuttle_areas)
		if(hull_area_is_guest(ship_area, port))
			continue
		SSship_repairs.area_controllers[ship_area] = src
		repair_areas |= ship_area

/obj/machinery/computer/camera_advanced/base_construction/ship/proc/clear_repair_journal(disconnect = FALSE)
	for(var/key in repair_records.Copy())
		forget_repair_record(key)
	repair_overflow = 0
	if(!disconnect)
		return
	set_repair_tracking(FALSE)
	for(var/area/ship_area as anything in repair_areas)
		if(SSship_repairs.area_controllers[ship_area] == src)
			SSship_repairs.area_controllers -= ship_area
	repair_areas.Cut()
	var/obj/docking_port/mobile/port = repair_port?.resolve()
	if(port?.ship_repair_controller?.resolve() == src)
		port.ship_repair_controller = null
	repair_port = null
	QDEL_NULL(repair_origin)

/obj/machinery/computer/camera_advanced/base_construction/ship/proc/forget_repair_record(key)
	var/datum/ship_repair_record/record = repair_records[key]
	if(!record)
		return
	repair_records -= key
	qdel(record)

/// Docked changes are remodeling, including changes made with hand tools.
/// Transit/docking tile transfers must neither create nor cancel damage records.
/obj/machinery/computer/camera_advanced/base_construction/ship/proc/on_repair_turf_change(turf/old_turf, new_path)
	if(repair_applying || !repair_origin || old_turf.z != repair_origin.z)
		return
	if(current_ship?.state == OVERMAP_SHIP_IDLE)
		forget_repair_record(repair_coordinate_key(old_turf))
	else if(get_turf_mass_weight(new_path) < get_turf_mass_weight_instance(old_turf))
		capture_repair_damage(old_turf)

/obj/machinery/computer/camera_advanced/base_construction/ship/proc/can_record_repair_damage()
	return (console_upgrades & SHIP_CONSTRUCTION_UPGRADE_REPAIR) && repair_tracking && !repair_applying && current_ship?.state == OVERMAP_SHIP_FLYING && repair_port?.resolve() == get_docking_port() && !QDELETED(repair_origin)

/// Capture only the affected location, before it disappears. Repeated hits merge.
/obj/machinery/computer/camera_advanced/base_construction/ship/proc/capture_repair_damage(atom/target)
	if(!can_record_repair_damage() || !repair_materials_for(target))
		return FALSE
	var/turf/location = get_turf(target)
	if(!location || location.z != repair_origin.z || !is_in_shuttle_area(location))
		return FALSE
	var/key = repair_coordinate_key(location)
	var/datum/ship_repair_record/record = repair_records[key]
	if(!record)
		if(length(repair_records) >= SHIP_REPAIR_JOURNAL_LIMIT || SSship_repairs.record_count >= SHIP_REPAIR_GLOBAL_RECORD_LIMIT)
			repair_overflow++
			repair_status = "Repair backlog full. Additional damage requires manual repair."
			return FALSE
		record = new
		SSship_repairs.record_count++
		var/list/offset = construction_offset(location, repair_origin)
		record.offset_x = offset[1]
		record.offset_y = offset[2]
		repair_records[key] = record
	// Retain the first supporting turf, even if a later hit takes wall -> floor -> space.
	if(!record.layers["turf"])
		var/list/floor_layer = capture_repair_layer(location)
		if(floor_layer)
			record.layers["turf"] = floor_layer
	if(isobj(target))
		var/list/layer = capture_repair_layer(target)
		var/layer_key = "[target.type]:[layer["dir"]]"
		if(!record.layers[layer_key])
			if(length(record.layers) >= SHIP_REPAIR_LAYER_LIMIT)
				repair_overflow++
				return FALSE
			record.layers[layer_key] = layer
	wake_repair_drones()
	return TRUE

/obj/machinery/computer/camera_advanced/base_construction/ship/proc/capture_repair_layer(atom/target)
	var/list/materials = repair_materials_for(target)
	if(!materials)
		return null
	var/list/layer = list("path" = target.type, "dir" = turn(target.dir, dir2angle(repair_origin.dir)), "materials" = materials)
	if(isfloorturf(target))
		var/list/recipe = repair_floor_recipe(target)
		layer["path"] = recipe["path"]
	else if(iswallturf(target))
		var/list/recipe = repair_wall_recipe(target)
		layer["path"] = recipe["path"]
	if(isobj(target))
		layer["original"] = WEAKREF(target)
	if(istype(target, /obj/machinery/door/airlock))
		var/obj/machinery/door/airlock/door = target
		layer["access"] = door.req_access?.Copy()
		layer["one_access"] = door.req_one_access?.Copy()
		layer["name"] = door.name
		layer["unres_sides"] = turn(door.unres_sides, dir2angle(repair_origin.dir))
		layer["cycle"] = door.closeOtherId
	return layer

/// Cheap global entry: no scans, new components, or listeners on intact objects.
/proc/record_ship_fixture_damage(atom/target, disassembled = FALSE)
	if(!istype(target, /obj/structure/window) && !istype(target, /obj/structure/grille) && !istype(target, /obj/machinery/door/airlock))
		return
	var/obj/machinery/computer/camera_advanced/base_construction/ship/controller = SSship_repairs.area_controllers[get_area(target)]
	var/obj/fixture = target
	if(!controller || controller.repair_applying)
		return
	if(disassembled)
		controller.forget_repair_record(controller.repair_coordinate_key(get_turf(target)))
	else if(fixture.anchored)
		controller.capture_repair_damage(target)

/obj/machinery/computer/camera_advanced/base_construction/ship/proc/wake_repair_drones()
	if(!(console_upgrades & SHIP_CONSTRUCTION_UPGRADE_REPAIR))
		return
	for(var/obj/structure/ship_repair_drone/drone as anything in repair_drones)
		if(drone.recalling || (repair_enabled && drone.enabled && (length(repair_records) || !drone.is_home())))
			SSship_repairs.workers |= drone

/// A destroyed airlock leaves a dense frame. Reuse only that unmodified wreckage;
/// a frame built, moved, or worked on by the crew is deliberate construction.
/proc/record_ship_repair_wreckage(obj/machinery/door/airlock/door, obj/structure/door_assembly/frame)
	var/obj/machinery/computer/camera_advanced/base_construction/ship/controller = SSship_repairs.area_controllers[get_area(door)]
	if(!frame || !controller?.can_record_repair_damage())
		return
	var/datum/ship_repair_record/record = controller.repair_records[controller.repair_coordinate_key(get_turf(door))]
	var/facing = turn(door.dir, dir2angle(controller.repair_origin.dir))
	var/list/layer = record?.layers["[door.type]:[facing]"]
	if(layer)
		layer["wreckage"] = WEAKREF(frame)
		layer["wreckage_state"] = frame.state
		layer["wreckage_integrity"] = frame.get_integrity()
		layer["wreckage_anchored"] = frame.anchored
