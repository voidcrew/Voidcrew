/**
 * Bounded construction queue. Jobs capture the requested result, not the state of the
 * tile when the worker eventually reaches it. No resources are reserved or spent until
 * completion. Coordinates are local to the console, so shuttle moves and rotations are
 * safe and relocating the mobile docking port does not move the work.
 */
/datum/ship_construction_job
	var/offset_x
	var/offset_y
	var/build_dir
	var/kind = "rcd"
	var/design_path
	var/build_mode
	var/wall_type
	var/floor_type
	var/list/electronics
	var/datum/weakref/operator
	var/duration
	var/ready_at = 0
	var/label
	var/datum/tile_info/tile_design
	var/list/tile_overlays
	var/list/decal_data

/datum/ship_construction_job/proc/coordinate_key()
	return "[offset_x],[offset_y]"

/// A short-lived worker used only for the synchronous completion of a queued job.
/// It borrows the console's silo component; it never owns a second material reserve.
/obj/item/construction/rcd/internal/ship/queue_worker
	var/build_direction = NORTH
	var/succeeded = FALSE
	var/paid_iron = 0

/obj/item/construction/rcd/internal/ship/queue_worker/get_build_speed_mod()
	return 0

/obj/item/construction/rcd/internal/ship/queue_worker/build_delay(mob/user, delay, atom/target)
	return TRUE

/obj/item/construction/rcd/internal/ship/queue_worker/rcd_build_dir(mob/user)
	return build_direction

/obj/item/construction/rcd/internal/ship/queue_worker/apply_rcd_action(atom/target, mob/user, list/rcd_results)
	succeeded = ..()
	if(!succeeded && paid_iron)
		refund_materials(list(/datum/material/iron = paid_iron), user)
	paid_iron = 0
	return succeeded

/obj/item/construction/rcd/internal/ship/queue_worker/checkResource(amount, mob/user)
	return ship_console?.internal_rcd.checkResource(amount, user)

/obj/item/construction/rcd/internal/ship/queue_worker/useResource(amount, mob/user)
	// A disconnected silo must leave the job waiting, without falling back to RCD matter.
	var/obj/item/construction/rcd/internal/ship/rcd = ship_console?.internal_rcd
	if(!rcd?.can_refund_materials(user))
		return FALSE
	var/datum/component/material_container/materials = rcd.silo_mats.mat_container
	var/before = materials.get_material_amount(/datum/material/iron)
	. = rcd.useResource(amount, user)
	if(.)
		paid_iron += before - materials.get_material_amount(/datum/material/iron)

/obj/machinery/computer/camera_advanced/base_construction/ship
	var/queue_enabled = FALSE
	var/build_size = 1
	/// Auto is available for single tiles only. Area brushes always have an explicit intent.
	var/turf_build_mode = "auto"
	var/list/construction_queue = list()
	var/list/construction_claims = list()
	var/queue_paused = FALSE
	var/queue_timer
	var/queue_status = "Ready"
	var/obj/effect/ship_repair_origin/queue_origin

/// Convert world coordinates to the console's north-facing frame (clockwise angles).
/obj/machinery/computer/camera_advanced/base_construction/ship/proc/construction_offset(turf/target, atom/origin)
	if(!origin)
		origin = src
	var/angle = dir2angle(origin.dir)
	var/dx = target.x - origin.x
	var/dy = target.y - origin.y
	return list(round(dx * cos(angle) - dy * sin(angle)), round(dx * sin(angle) + dy * cos(angle)))

/obj/machinery/computer/camera_advanced/base_construction/ship/proc/construction_turf(dx, dy)
	var/atom/origin = queue_origin || src
	var/angle = dir2angle(origin.dir)
	return locate(origin.x + round(dx * cos(angle) + dy * sin(angle)), origin.y + round(-dx * sin(angle) + dy * cos(angle)), origin.z)

/obj/machinery/computer/camera_advanced/base_construction/ship/proc/construction_direction(relative_dir)
	return turn(relative_dir, -dir2angle(queue_origin?.dir || dir))

/obj/machinery/computer/camera_advanced/base_construction/ship/proc/capture_construction_job(turf/target, mob/user, intent, tool_kind = "rcd")
	var/obj/item/construction/rcd/internal/ship/rcd = internal_rcd
	var/datum/ship_construction_job/job = new
	var/anchor_direction = queue_origin?.dir || dir
	var/list/offset = construction_offset(target, queue_origin)
	job.offset_x = offset[1]
	job.offset_y = offset[2]
	job.build_dir = turn(rcd.rcd_build_dir(user), dir2angle(anchor_direction))
	job.design_path = rcd.rcd_design_path
	job.build_mode = rcd.construction_mode
	job.wall_type = rcd.selected_wall_type
	job.floor_type = rcd.selected_floor_type
	job.operator = WEAKREF(user)
	if(tool_kind == "decal_remove")
		job.kind = "decal_remove"
		job.label = "Remove floor decals"
		job.duration = 0.5 SECONDS
		return job
	if(tool_kind == "tile")
		job.kind = "tile"
		job.tile_design = internal_rtd.selected_design
		job.design_path = job.tile_design.turf_type
		job.label = job.tile_design.name
		job.build_dir = turn(internal_rtd.selected_direction, dir2angle(anchor_direction))
		job.duration = 1 SECONDS
		job.tile_overlays = list()
		for(var/datum/overlay_info/overlay as anything in internal_rtd.design_overlays)
			job.tile_overlays += list(list("icon" = overlay.icon, "state" = overlay.icon_state, "dir" = turn(overlay.direction, dir2angle(anchor_direction)), "alpha" = overlay.alpha, "color" = overlay.color))
		return job
	if(tool_kind == "decal")
		job.kind = "decal"
		job.label = "Floor decal"
		job.decal_data = internal_painter.get_decal_data().Copy()
		job.build_dir = turn(job.decal_data[DECAL_INFO_DIR], dir2angle(anchor_direction))
		job.duration = 0.5 SECONDS
		return job
	job.label = rcd.design_title
	var/obj/item/electronics/airlock/electronics = rcd.airlock_electronics
	job.electronics = list(
		"accesses" = electronics.accesses.Copy(),
		"one_access" = electronics.one_access,
		"unres_sides" = turn(electronics.unres_sides, dir2angle(anchor_direction)),
		"passed_name" = electronics.passed_name,
		"passed_cycle_id" = electronics.passed_cycle_id,
		"shell" = electronics.shell,
	)
	if(job.build_mode == RCD_TURF && job.design_path == /turf/open/floor/plating/rcd)
		job.kind = intent == "auto" ? (rcd.can_build_floor(target) ? "floor" : "wall") : intent
		job.label = job.kind == "floor" ? job.floor_type : job.wall_type
		job.duration = job.kind == "floor" ? SHIP_RCD_FLOOR_BUILD_DELAY : SHIP_RCD_WALL_BUILD_DELAY
	else if(rcd.is_hull_window(job.design_path))
		job.kind = "hull_window"
		job.duration = SHIP_RCD_WINDOW_BUILD_DELAY
	else
		var/list/values = target.rcd_vals(user, rcd)
		job.duration = values ? values["delay"] : (2 SECONDS)
	return job

/// Existing floors are already a completed floor job, regardless of their finish.
/// Never let overlapping area strokes turn these floors into walls or replace fixtures.
/obj/machinery/computer/camera_advanced/base_construction/ship/proc/construction_job_needed(datum/ship_construction_job/job, turf/target)
	if(!target)
		return FALSE
	if(locate(/obj/machinery/door/poddoor) in target)
		return FALSE
	if(job.kind == "floor")
		var/obj/item/construction/rcd/internal/ship/rcd = internal_rcd
		return rcd.can_build_floor(target)
	if(target.resistance_flags & INDESTRUCTIBLE)
		return FALSE
	if(job.kind == "tile")
		return istype(target, /turf/open/floor/plating)
	if(job.kind == "decal")
		return isfloorturf(target) && !construction_has_decal(target, job.decal_data, construction_direction(job.build_dir))
	if(job.kind == "decal_remove")
		return isfloorturf(target) && length(construction_floor_decals(target)) > 0
	if(job.kind == "wall")
		return isfloorturf(target)
	if(job.build_mode == RCD_AIRLOCK && (locate(/obj/machinery/door) in target))
		return FALSE
	if(job.build_mode == RCD_WINDOWGRILLE)
		for(var/obj/structure/window/window in target)
			var/obj/structure/window/window_type = job.design_path
			if(window.fulltile || initial(window_type.fulltile) || window.dir == construction_direction(job.build_dir))
				return FALSE
	else if(ispath(job.design_path, /obj) && (locate(job.design_path) in target))
		return FALSE
	return TRUE

/obj/machinery/computer/camera_advanced/base_construction/ship/proc/queue_construction(turf/center, mob/user, tool_kind = "rcd")
	if(!(console_upgrades & SHIP_CONSTRUCTION_UPGRADE_QUEUE) || !can_operate() || !is_crew_member(user) || !center)
		return FALSE
	if((tool_kind == "tile" && !internal_rtd) || ((tool_kind == "decal" || tool_kind == "decal_remove") && !internal_painter))
		return FALSE
	if(!queue_origin)
		queue_origin = new(get_turf(src))
		queue_origin.setDir(dir)
	var/size = (console_upgrades & SHIP_CONSTRUCTION_UPGRADE_AREA) ? build_size : 1
	var/intent = turf_build_mode
	if(size > 1 && intent == "auto")
		intent = "floor"
	var/obj/item/construction/rcd/internal/ship/rcd = internal_rcd
	var/added = 0
	var/low = size == 3 ? -1 : 0
	// Center first, then the surrounding ring: expansion proceeds out from existing hull.
	var/list/targets = list(center)
	for(var/distance in 1 to 2)
		for(var/dx in low to low + size - 1)
			for(var/dy in low to low + size - 1)
				if(abs(dx) + abs(dy) != distance)
					continue
				var/turf/target = locate(center.x + dx, center.y + dy, center.z)
				if(target)
					targets += target
	for(var/turf/target as anything in targets)
		if(length(construction_queue) >= SHIP_CONSTRUCTION_QUEUE_LIMIT)
			break
		// Adjacency is rechecked on completion, after earlier tiles have expanded the hull.
		if(!is_in_shuttle_area(target) && (!is_valid_expansion_area(target) || !rcd.can_build_floor(target)))
			continue
		var/datum/ship_construction_job/job = capture_construction_job(target, user, intent, tool_kind)
		if(construction_claims[job.coordinate_key()] || !construction_job_needed(job, target))
			qdel(job)
			continue
		construction_queue += job
		construction_claims[job.coordinate_key()] = job
		added++
	queue_status = added ? "Queued [added] tile[added == 1 ? "" : "s"]." : "No new tiles to queue (or queue full)."
	if(!length(construction_queue))
		QDEL_NULL(queue_origin)
	start_construction_queue()
	return added > 0

/obj/machinery/computer/camera_advanced/base_construction/ship/proc/start_construction_queue()
	if(queue_timer || queue_paused || !length(construction_queue))
		return
	queue_timer = addtimer(CALLBACK(src, PROC_REF(process_construction_queue)), world.tick_lag, TIMER_STOPPABLE)

/obj/machinery/computer/camera_advanced/base_construction/ship/proc/clear_construction_queue()
	if(queue_timer)
		deltimer(queue_timer)
		queue_timer = null
	QDEL_LIST(construction_queue)
	construction_queue = list()
	construction_claims.Cut()
	QDEL_NULL(queue_origin)
	queue_status = "Queue cleared."

/obj/machinery/computer/camera_advanced/base_construction/ship/proc/process_construction_queue()
	queue_timer = null
	if(queue_paused || !length(construction_queue))
		return
	if(!can_operate() || !is_operational || !anchored)
		queue_status = "Waiting for an operational, docked console."
		for(var/datum/ship_construction_job/job as anything in construction_queue)
			job.ready_at = 0
		start_construction_queue()
		return
	if(QDELETED(queue_origin) || !is_in_shuttle_area(get_turf(queue_origin)))
		clear_construction_queue()
		queue_status = "Queue origin lost; queue cleared without spending materials."
		return
	// Even instant fabrication has a per-tick budget; it cannot monopolize the server.
	for(var/count in 1 to 9)
		if(!length(construction_queue))
			break
		var/datum/ship_construction_job/job = construction_queue[1]
		var/turf/target = construction_turf(job.offset_x, job.offset_y)
		var/mob/user = job.operator?.resolve()
		if(!user || !is_crew_member(user) || !can_build_at(target) || !construction_job_needed(job, target))
			finish_construction_job(job)
			continue
		if(!is_in_shuttle_area(target) && !check_expansion_dimensions(target, get_docking_port()))
			finish_construction_job(job)
			continue
		if(!job.ready_at)
			job.ready_at = world.time + job.duration * get_build_speed_mod()
		if(world.time < job.ready_at)
			break
		if(!complete_construction_job(job, target, user))
			queue_status = "Waiting for materials or a clear tile: [job.label]."
			// Retain unpaid jobs for a later retry; avoid polling the silo every tick.
			job.ready_at = world.time + (2 SECONDS)
			break
		queue_status = "Completed [job.label]."
		finish_construction_job(job)
	start_construction_queue()

/obj/machinery/computer/camera_advanced/base_construction/ship/proc/finish_construction_job(datum/ship_construction_job/job)
	construction_queue -= job
	construction_claims -= job.coordinate_key()
	qdel(job)
	if(!length(construction_queue))
		QDEL_NULL(queue_origin)

/obj/machinery/computer/camera_advanced/base_construction/ship/proc/complete_construction_job(datum/ship_construction_job/job, turf/target, mob/user)
	if(!construction_job_needed(job, target))
		return FALSE
	if(job.kind == "tile" || job.kind == "decal" || job.kind == "decal_remove")
		return complete_decoration_job(job, target, user)
	var/obj/item/construction/rcd/internal/ship/queue_worker/worker = new(src)
	worker.ship_console = src
	worker.silo_mats = internal_rcd.silo_mats
	worker.silo_link = internal_rcd.silo_link
	worker.construction_upgrades = internal_rcd.construction_upgrades
	worker.mode = job.build_mode
	worker.construction_mode = job.build_mode
	worker.rcd_design_path = job.design_path
	worker.selected_wall_type = job.wall_type
	worker.selected_floor_type = job.floor_type
	worker.delay_mod = 0
	worker.build_direction = construction_direction(job.build_dir)
	for(var/field in job.electronics)
		worker.airlock_electronics.vars[field] = job.electronics[field]
	worker.airlock_electronics.unres_sides = construction_direction(job.electronics["unres_sides"])
	var/was_in_shuttle = is_in_shuttle_area(target)
	var/success = FALSE
	switch(job.kind)
		if("floor")
			success = worker.build_floor(target, user)
		if("wall")
			success = worker.build_wall(target, user)
		if("hull_window")
			success = worker.build_hull_window(target, user)
		else
			var/atom/rcd_target = target
			for(var/obj/object in target)
				if(length(object.rcd_vals(user, worker)))
					rcd_target = object
			worker.rcd_create(rcd_target, user)
			success = worker.succeeded
	qdel(worker)
	if(!success)
		return FALSE
	var/turf/built = construction_turf(job.offset_x, job.offset_y)
	if(!was_in_shuttle && !isspaceturf(built))
		expand_shuttle_to_turf(built, user)
	else if(job.build_mode == RCD_AIRLOCK)
		check_port_after_build(built, user, door_built = TRUE)
	playsound(built, 'sound/items/deconstruct.ogg', 60, TRUE)
	return TRUE

/// Shared controls for the main console and the remote RCD configuration window.
/obj/machinery/computer/camera_advanced/base_construction/ship/proc/construction_controls_data()
	var/list/jobs = list()
	for(var/datum/ship_construction_job/job as anything in construction_queue)
		jobs += list(list("ref" = REF(job), "name" = job.label, "x" = job.offset_x, "y" = job.offset_y))
	return list(
		"queueUnlocked" = !!(console_upgrades & SHIP_CONSTRUCTION_UPGRADE_QUEUE),
		"areaUnlocked" = !!(console_upgrades & SHIP_CONSTRUCTION_UPGRADE_AREA),
		"queueEnabled" = queue_enabled,
		"queuePaused" = queue_paused,
		"queueStatus" = queue_status,
		"buildSize" = build_size,
		"turfBuildMode" = turf_build_mode,
		"buildTimePercent" = round(get_build_speed_mod() * 100),
		"jobs" = jobs,
	)

/obj/machinery/computer/camera_advanced/base_construction/ship/proc/construction_control_act(action, list/params, mob/user)
	if(!is_crew_member(user))
		return FALSE
	switch(action)
		if("queue_toggle")
			if(console_upgrades & SHIP_CONSTRUCTION_UPGRADE_QUEUE)
				queue_enabled = !queue_enabled
			return TRUE
		if("build_size")
			var/size = text2num(params["size"])
			if((size in list(1, 2, 3)) && (size == 1 || (console_upgrades & SHIP_CONSTRUCTION_UPGRADE_AREA)))
				build_size = size
				if(size > 1)
					queue_enabled = TRUE
					if(turf_build_mode == "auto")
						turf_build_mode = "floor"
			return TRUE
		if("turf_build_mode")
			if(params["mode"] in list("auto", "floor", "wall"))
				if(params["mode"] != "auto" || build_size == 1)
					turf_build_mode = params["mode"]
			return TRUE
		if("queue_pause")
			queue_paused = !queue_paused
			// Pausing restarts the current job's delay, so time paused is never free work.
			for(var/datum/ship_construction_job/job as anything in construction_queue)
				job.ready_at = 0
			start_construction_queue()
			return TRUE
		if("queue_clear")
			clear_construction_queue()
			return TRUE
		if("queue_remove")
			for(var/datum/ship_construction_job/job as anything in construction_queue)
				if(REF(job) == params["ref"])
					finish_construction_job(job)
					break
			return TRUE
	return FALSE
