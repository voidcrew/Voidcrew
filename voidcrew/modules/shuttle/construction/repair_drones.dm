/// Robotics-built repair workers consume the sparse journal in repair_damage.dm.
/obj/machinery/computer/camera_advanced/base_construction/ship
	var/list/repair_drones = list()
	var/repair_enabled = FALSE
	var/repair_status = "Standby."
	var/next_repair_drone_id = 1

/// Every destructible ship floor can have its breach sealed, even without a finish recipe.
/obj/machinery/computer/camera_advanced/base_construction/ship/proc/repair_floor_recipe(turf/open/floor/floor)
	for(var/floor_name in list("Plastitanium Floor", "Titanium Floor"))
		var/list/recipe = /obj/item/construction/rcd/internal/ship::floor_types[floor_name]
		if(istype(floor, recipe["path"]))
			return list("path" = floor.type, "materials" = recipe["materials"].Copy())
	if(istype(floor, /turf/open/floor/iron) || istype(floor, /turf/open/floor/plating) || istype(floor, /turf/open/floor/catwalk_floor))
		return list("path" = floor.type, "materials" = list(/datum/material/iron = SHIP_RTD_TILE_IRON))
	if(istype(floor, /turf/open/floor/engine) && floor.floor_tile == /obj/item/stack/rods)
		var/turf/open/floor/engine/reinforced = floor
		var/iron_cost = SHIP_RTD_TILE_IRON + reinforced.floor_tile_amount * HALF_SHEET_MATERIAL_AMOUNT
		return list("path" = floor.type, "materials" = list(/datum/material/iron = iron_cost))
	return list("path" = /turf/open/floor/iron, "materials" = list(/datum/material/iron = SHIP_RTD_TILE_IRON))

/// Unknown wall finishes still receive a standard iron hull patch.
/obj/machinery/computer/camera_advanced/base_construction/ship/proc/repair_wall_recipe(turf/closed/wall/wall)
	for(var/wall_name in list("Plastitanium Wall", "Titanium Wall"))
		var/list/recipe = /obj/item/construction/rcd/internal/ship::wall_types[wall_name]
		if(istype(wall, recipe["path"]))
			return list("path" = wall.type, "materials" = recipe["materials"].Copy())
	if(istype(wall, /turf/closed/wall/r_wall/plastitanium))
		return list("path" = wall.type, "materials" = list(/datum/material/iron = 400, /datum/material/plasma = 400, /datum/material/titanium = 200))
	if(wall.type == /turf/closed/wall/r_wall)
		// Pay for the plasteel that dismantling a restored reinforced wall returns.
		return list("path" = wall.type, "materials" = list(/datum/material/iron = 400, /datum/material/plasma = 200))
	return list("path" = /turf/closed/wall, "materials" = list(/datum/material/iron = 200))

/// Resource recipes are deliberately restricted to reproducible hull and basic fixtures.
/// Unique equipment, contents and machine state are never serialized or fabricated.
/obj/machinery/computer/camera_advanced/base_construction/ship/proc/repair_materials_for(atom/target)
	if(target.resistance_flags & INDESTRUCTIBLE)
		return null
	var/obj/item/construction/rcd/internal/ship/rcd = internal_rcd
	if(iswallturf(target))
		var/list/recipe = repair_wall_recipe(target)
		return recipe["materials"]
	if(isfloorturf(target))
		var/list/recipe = repair_floor_recipe(target)
		return recipe["materials"]
	if(istype(target, /obj/structure/grille))
		return list(/datum/material/iron = 100)
	if(istype(target, /obj/structure/window))
		var/list/hull_recipe = rcd.hull_window_materials[target.type]
		if(hull_recipe)
			return hull_recipe.Copy()
		// Only the ordinary glass families, not clockwork/alien/special windows.
		if(target.type in list(/obj/structure/window, /obj/structure/window/fulltile, /obj/structure/window/reinforced, /obj/structure/window/reinforced/fulltile))
			var/obj/structure/window/window = target
			return list(/datum/material/glass = window.fulltile ? 200 : 100, /datum/material/iron = window.reinf ? 100 : 0)
		return null
	if(istype(target, /obj/machinery/door/airlock))
		// Only doors offered by the construction console's approved design tree.
		var/list/designs = rcd.get_rcd_designs()
		for(var/root in designs)
			for(var/category in designs[root])
				for(var/list/design as anything in designs[root][category])
					if(design["[RCD_DESIGN_PATH]"] == target.type)
						return list(/datum/material/iron = istype(target, /obj/machinery/door/airlock/glass) ? 500 : 400)
	return null

/// Repair only known recorded damage locations on our ship or valid adjacent breach space.
/obj/machinery/computer/camera_advanced/base_construction/ship/proc/repair_target_valid(turf/target)
	if(!target || !repair_origin || repair_port?.resolve() != get_docking_port())
		return FALSE
	if(!is_in_shuttle_area(target) && !check_expansion_dimensions(target, get_docking_port()))
		return FALSE
	return can_build_at(target) && !(target.resistance_flags & INDESTRUCTIBLE)

/// Returns just the next repair on this tile. Existing, different construction wins.
/// Re-evaluated after travel and after the work delay, before spending anything.
/obj/machinery/computer/camera_advanced/base_construction/ship/proc/next_record_repair(datum/ship_repair_record/record)
	var/turf/target = repair_record_turf(record)
	if(!repair_target_valid(target) || (locate(/obj/machinery/door/poddoor) in target))
		return null
	var/list/layers = record.layers
	for(var/layer_key in layers.Copy())
		var/list/layer = layers[layer_key]
		var/path = layer["path"]
		var/atom/existing
		if(ispath(path, /turf))
			var/exposed_landing = isopenturf(target) && istype(get_area(target), /area/shuttle) && !isshuttleturf(target)
			if(target.type == path && !exposed_landing)
				existing = target
			else if(isspaceturf(target) || exposed_landing)
				// A breach landing on natural ground still needs its deck. Area-only
				// shuttle movement is not replacement construction by the crew.
				// The same worker restores the supporting deck before raising the wall.
				if(ispath(path, /turf/closed/wall))
					return list("path" = /turf/open/floor/plating, "materials" = list(/datum/material/iron = 100), "supporting_wall" = layer)
				return layer
			else if(ispath(path, /turf/closed/wall) && isfloorturf(target))
				if(!target.is_blocked_turf(exclude_mobs = FALSE))
					return layer
				return null
			else
				// A replacement floor or wall retires the old target.
				layers -= layer_key
				continue
		else
			var/datum/weakref/wreckage_ref = layer["wreckage"]
			var/obj/structure/door_assembly/wreckage = wreckage_ref?.resolve()
			if(wreckage && (get_turf(wreckage) != target || wreckage.state != layer["wreckage_state"] || wreckage.get_integrity() != layer["wreckage_integrity"] || wreckage.anchored != layer["wreckage_anchored"] || wreckage.created_name != layer["name"] || wreckage.dir != turn(layer["dir"], -dir2angle(repair_origin.dir))))
				layers -= layer_key
				continue
			var/datum/weakref/original_ref = layer["original"]
			var/obj/original = original_ref?.resolve()
			if(original && (!original.anchored || get_turf(original) != target))
				layers -= layer_key
				continue
			if(!isfloorturf(target))
				return null
			var/facing = turn(layer["dir"], -dir2angle(repair_origin.dir))
			for(var/obj/fixture in target)
				if(fixture.type == path && (fixture.dir == facing || !istype(fixture, /obj/structure/window)))
					existing = fixture
					break
			if(!existing)
				// Missing fixtures never replace doors/windows/objects of another type.
				for(var/obj/fixture in target)
					if(istype(fixture, /obj/structure/door_assembly) && fixture != wreckage)
						layers -= layer_key
						return null
					if(istype(fixture, /obj/machinery/door))
						layers -= layer_key
						return null
					if(istype(fixture, /obj/structure/window) && !ispath(path, /obj/structure/grille))
						var/obj/structure/window/window = fixture
						var/obj/structure/window/expected_window = path
						if(!ispath(path, /obj/structure/window) || window.fulltile || initial(expected_window.fulltile) || window.dir == facing)
							layers -= layer_key
							return null
				var/list/ignored = list(/obj/structure/grille)
				if(wreckage)
					ignored += /obj/structure/door_assembly
				if(ispath(path, /obj/structure/grille) || ispath(path, /obj/structure/window))
					ignored += /obj/structure/window
				if(target.is_blocked_turf(exclude_mobs = FALSE, ignore_atoms = ignored, type_list = TRUE))
					return null
				return layer
		var/obj/structure/grille/existing_grille = existing
		var/obj/machinery/door/airlock/existing_door = existing
		var/broken_fixture = (istype(existing_grille) && existing_grille.broken) || (istype(existing_door) && (existing_door.machine_stat & BROKEN))
		if(existing?.uses_integrity && (existing.get_integrity() < existing.max_integrity || broken_fixture))
			var/list/repair = layer.Copy()
			repair["existing"] = existing
			var/fraction = 1 - existing.get_integrity() / existing.max_integrity
			if(!fraction && broken_fixture)
				fraction = 1
			var/list/materials = layer["materials"].Copy()
			for(var/material in materials)
				materials[material] = CEILING(materials[material] * fraction, 1)
			repair["materials"] = materials
			return repair
		// Fully repaired or manually rebuilt: release its saved recipe.
		layers -= layer_key
	return null

/// A missing door/window can receive a standard holofan while its real repair waits.
/obj/machinery/computer/camera_advanced/base_construction/ship/proc/repair_seal_needed(datum/ship_repair_record/record)
	var/turf/target = repair_record_turf(record)
	if(!repair_target_valid(target) || !isopenturf(target) || (locate(/obj/structure/holosign/barrier/atmos) in target))
		return FALSE
	for(var/obj/fixture in target)
		if(istype(fixture, /obj/structure/window) || istype(fixture, /obj/machinery/door))
			return FALSE
	for(var/key in record.layers)
		var/list/layer = record.layers[key]
		if(ispath(layer["path"], /obj/structure/window) || ispath(layer["path"], /obj/machinery/door/airlock))
			return TRUE
	return FALSE

/obj/machinery/computer/camera_advanced/base_construction/ship/proc/project_repair_seal(datum/ship_repair_record/record)
	if(!(console_upgrades & SHIP_CONSTRUCTION_UPGRADE_REPAIR) || !is_operational || !repair_seal_needed(record))
		return FALSE
	QDEL_NULL(record.emergency_seal)
	var/turf/target = repair_record_turf(record)
	record.emergency_seal = new /obj/structure/holosign/barrier/atmos(target)
	var/obj/effect/constructing_effect/ship_repair/effect = new(target, 0, /obj/structure/holosign/barrier/atmos, SOUTH)
	effect.end_animation()
	playsound(target, 'sound/machines/click.ogg', 40, TRUE, pressure_affected = FALSE)
	return TRUE

/// Original construction first, then standard iron and other compatible recipes.
/obj/machinery/computer/camera_advanced/base_construction/ship/proc/repair_recipe_options(list/repair)
	var/list/options = list(repair)
	if(repair["existing"])
		return options
	var/path = repair["path"]
	var/list/alternatives = list()
	if(ispath(path, /turf/open/floor))
		alternatives += list(list("path" = /turf/open/floor/iron, "materials" = list(/datum/material/iron = SHIP_RTD_TILE_IRON)))
		for(var/floor_name in list("Titanium Floor", "Plastitanium Floor"))
			alternatives += list(/obj/item/construction/rcd/internal/ship::floor_types[floor_name])
	else if(ispath(path, /turf/closed/wall))
		for(var/wall_name in list("Iron Wall", "Titanium Wall", "Plastitanium Wall"))
			alternatives += list(/obj/item/construction/rcd/internal/ship::wall_types[wall_name])
	else if(ispath(path, /obj/structure/window))
		var/obj/structure/window/window_type = path
		var/fulltile = initial(window_type.fulltile)
		alternatives += list(list("path" = fulltile ? /obj/structure/window/reinforced/fulltile : /obj/structure/window/reinforced, "materials" = list(/datum/material/glass = fulltile ? 200 : 100, /datum/material/iron = 100)))
		alternatives += list(list("path" = fulltile ? /obj/structure/window/fulltile : /obj/structure/window, "materials" = list(/datum/material/glass = fulltile ? 200 : 100)))
	else if(ispath(path, /obj/machinery/door/airlock))
		alternatives += list(list("path" = /obj/machinery/door/airlock, "materials" = list(/datum/material/iron = 400)))
	for(var/list/recipe as anything in alternatives)
		if(recipe["path"] == path)
			continue
		var/list/option = repair.Copy()
		option["path"] = recipe["path"]
		option["materials"] = recipe["materials"]
		options += list(option)
	return options

/// Other workers leave the materials for an already-started wall available to its owner.
/// These are short-lived claims, not withdrawals; crew use of the silo still takes priority.
/obj/machinery/computer/camera_advanced/base_construction/ship/proc/check_repair_materials(list/materials, obj/structure/ship_repair_drone/owner)
	var/list/required = materials.Copy()
	for(var/obj/structure/ship_repair_drone/other as anything in repair_drones)
		if(other == owner)
			continue
		for(var/material in other.reserved_wall_materials)
			if(materials[material] > 0)
				required[material] += other.reserved_wall_materials[material]
	var/obj/item/construction/rcd/internal/ship/rcd = internal_rcd
	return rcd.check_materials(required, null)

/// Check supplies without spending them. A deck/wall pair shares the available budget.
/obj/machinery/computer/camera_advanced/base_construction/ship/proc/affordable_record_repair(list/repair, datum/ship_repair_record/record)
	if(!repair)
		return null
	var/obj/structure/ship_repair_drone/owner = record?.claimed_by
	var/list/options = repair_recipe_options(repair)
	var/list/supporting_wall = repair["supporting_wall"]
	if(supporting_wall)
		for(var/list/wall_option as anything in repair_recipe_options(supporting_wall))
			for(var/list/floor_option as anything in options)
				var/list/combined = wall_option["materials"].Copy()
				var/list/floor_materials = floor_option["materials"]
				for(var/material in floor_materials)
					combined[material] += floor_materials[material]
				if(check_repair_materials(combined, owner))
					var/list/paired_floor = floor_option.Copy()
					paired_floor["wall_after_floor"] = wall_option
					return paired_floor
	// If only a deck can be afforded, seal the hole and keep the wall queued.
	for(var/list/option as anything in options)
		if(check_repair_materials(option["materials"], owner))
			return option
	return null

/obj/machinery/computer/camera_advanced/base_construction/ship/proc/perform_record_repair(datum/ship_repair_record/record)
	if(!(console_upgrades & SHIP_CONSTRUCTION_UPGRADE_REPAIR))
		return FALSE
	var/list/repair = affordable_record_repair(next_record_repair(record), record)
	if(!repair)
		return FALSE
	var/turf/target = repair_record_turf(record)
	var/obj/item/construction/rcd/internal/ship/rcd = internal_rcd
	if(!rcd.use_materials(repair["materials"], null))
		return FALSE
	var/list/wall_after_floor = repair["wall_after_floor"]
	if(wall_after_floor && record.claimed_by)
		record.claimed_by.reserved_wall_materials = wall_after_floor["materials"].Copy()
	repair_applying = TRUE
	var/atom/existing = repair["existing"]
	if(existing)
		if(istype(existing, /obj/structure/grille))
			var/obj/structure/grille/grille = existing
			if(grille.broken)
				grille.repair_grille()
		existing.repair_damage(existing.max_integrity - existing.get_integrity())
		if(istype(existing, /obj/machinery/door/airlock))
			var/obj/machinery/door/airlock/door = existing
			door.set_machine_stat(door.machine_stat & ~BROKEN)
			door.update_appearance()
	else
		var/path = repair["path"]
		var/facing = turn(repair["dir"] || SOUTH, -dir2angle(repair_origin.dir))
		if(ispath(path, /turf))
			var/was_hull = is_in_shuttle_area(target)
			var/turf/built
			if(ispath(path, /turf/closed/wall) || (!isspaceturf(target) && !isshuttleturf(target)))
				built = target.place_on_top(path, flags = CHANGETURF_INHERIT_AIR)
			else
				built = target.ChangeTurf(path, flags = CHANGETURF_INHERIT_AIR)
			built.setDir(facing)
			rcd.restamp_hull_marker(built)
			if(!was_hull)
				expand_shuttle_to_turf(built, null)
		else
			var/datum/weakref/wreckage_ref = repair["wreckage"]
			var/obj/wreckage = wreckage_ref?.resolve()
			if(wreckage)
				qdel(wreckage)
			var/obj/fixture = new path(target)
			fixture.setDir(facing)
			fixture.set_anchored(TRUE)
			if(istype(fixture, /obj/machinery/door/airlock))
				var/obj/machinery/door/airlock/door = fixture
				door.req_access = repair["access"]?.Copy() || list()
				door.req_one_access = repair["one_access"]?.Copy() || list()
				door.name = repair["name"]
				door.unres_sides = turn(repair["unres_sides"], -dir2angle(repair_origin.dir))
				door.closeOtherId = repair["cycle"]
				if(door.closeOtherId)
					door.update_other_id()
	repair_applying = FALSE
	playsound(target, 'sound/machines/click.ogg', 40, TRUE, pressure_affected = FALSE)
	return TRUE

/// Show the chosen material fallback without creating a real, functional fixture.
/obj/effect/constructing_effect/ship_repair
	var/atom/design_path

/obj/effect/constructing_effect/ship_repair/Initialize(mapload, repair_delay, atom/design, facing)
	design_path = design
	. = ..(mapload, repair_delay, RCD_STRUCTURE, NONE)
	var/mutable_appearance/preview = mutable_appearance(initial(design.icon), initial(design.icon_state), alpha = 110)
	preview.color = "#80dfff"
	underlays += make_mutable_appearance_directional(preview, facing)

/obj/effect/constructing_effect/ship_repair/update_name(updates)
	. = ..()
	if(design_path)
		name = "constructing [initial(design_path.name)]"

/obj/effect/constructing_effect/ship_repair/end_animation()
	underlays.Cut()
	return ..()

/// A physical, destructible unit that flies directly to its claimed damage record.
/obj/structure/ship_repair_drone
	name = "ship repair drone"
	desc = "A small autonomous hull repair drone. Link an unassigned unit to a construction console with a multitool."
	icon = 'voidcrew/modules/shuttle/icons/repair_drone.dmi'
	icon_state = "complete"
	max_integrity = 100
	density = FALSE
	anchored = FALSE
	movement_type = FLYING
	pass_flags = PASSTABLE | PASSMOB
	layer = ABOVE_ALL_MOB_LAYER
	var/obj/machinery/computer/camera_advanced/base_construction/ship/console
	var/datum/ship_repair_record/job
	/// Retain a partly rebuilt location so its wall follows its supporting deck.
	var/repair_started = FALSE
	var/list/reserved_wall_materials
	var/work_finishes = 0
	var/obj/effect/constructing_effect/ship_repair/work_effect
	var/datum/beam/work_beam
	var/enabled = TRUE
	var/recalling = FALSE
	var/status = "Unlinked"
	var/repaired = 0
	var/next_step = 0

/obj/structure/ship_repair_drone/Initialize(mapload)
	// Transit can grab newly initialized objects before their parent Initialize returns.
	ADD_TRAIT(src, TRAIT_FREE_HYPERSPACE_MOVEMENT, INNATE_TRAIT)
	ADD_TRAIT(src, TRAIT_FREE_HYPERSPACE_SOFTCORDON_MOVEMENT, INNATE_TRAIT)
	. = ..()
	// Visual hover only: idle drones do not need scheduler ticks to keep floating.
	animate(src, pixel_z = base_pixel_z + 2, time = 2 SECONDS, loop = -1, easing = SINE_EASING, flags = ANIMATION_PARALLEL)
	animate(pixel_z = base_pixel_z, time = 2 SECONDS, easing = SINE_EASING)

/obj/structure/ship_repair_drone/hypotheticalShuttleMove(rotation, move_mode, obj/docking_port/mobile/moving_dock)
	. = ..()
	if(. & MOVE_AREA)
		. |= MOVE_CONTENTS

/obj/structure/ship_repair_drone/beforeShuttleMove(turf/newT, rotation, move_mode, obj/docking_port/mobile/moving_dock)
	. = ..()
	// A drone hovering over a breached deck must travel with that ship's area.
	if(. & MOVE_AREA)
		. |= MOVE_CONTENTS

/obj/structure/ship_repair_drone/afterShuttleMove(turf/oldT, list/movement_force, shuttle_dir, shuttle_preferred_direction, move_dir, rotation)
	. = ..()
	// Preflight walks live turf contents; only delete construction effects after transfer.
	stop_work()

/obj/structure/ship_repair_drone/lateShuttleMove(turf/oldT, list/movement_force, move_dir)
	// Its thrusters also compensate for the ship's acceleration and braking.
	return

/obj/structure/ship_repair_drone/Moved(atom/old_loc, movement_dir, forced, list/old_locs, momentum_change = TRUE)
	. = ..()
	if(momentum_change)
		stop_work()

/obj/structure/ship_repair_drone/Destroy()
	unlink_console()
	return ..()

/obj/structure/ship_repair_drone/proc/release_job()
	if(job?.claimed_by == src)
		job.claimed_by = null
	job = null
	repair_started = FALSE
	reserved_wall_materials = null
	stop_work()

/obj/structure/ship_repair_drone/proc/stop_work()
	QDEL_NULL(work_beam)
	QDEL_NULL(work_effect)
	work_finishes = 0

/obj/structure/ship_repair_drone/proc/unlink_console()
	SSship_repairs.workers -= src
	release_job()
	console?.repair_drones.Remove(src)
	console = null
	status = "Unlinked"

/obj/structure/ship_repair_drone/multitool_act(mob/living/user, obj/item/multitool/tool)
	if(console)
		balloon_alert(user, "already linked")
		return ITEM_INTERACT_SUCCESS
	if(!istype(tool.buffer, /obj/machinery/computer/camera_advanced/base_construction/ship) || QDELETED(tool.buffer))
		balloon_alert(user, "save a construction console first")
		return ITEM_INTERACT_SUCCESS
	var/obj/machinery/computer/camera_advanced/base_construction/ship/builder = tool.buffer
	if(!builder.is_crew_member(user))
		balloon_alert(user, "crew access required")
		return ITEM_INTERACT_SUCCESS
	if(!builder.is_in_shuttle_area(get_turf(src)))
		balloon_alert(user, "bring drone aboard the ship")
		return ITEM_INTERACT_SUCCESS
	if(length(builder.repair_drones) >= SHIP_REPAIR_DRONE_LIMIT)
		balloon_alert(user, "drone limit reached")
		return ITEM_INTERACT_SUCCESS
	console = builder
	name = "ship repair drone #[builder.next_repair_drone_id++]"
	builder.repair_drones += src
	// Pairing is independent of whether this console can currently run the swarm.
	builder.set_repair_tracking(TRUE)
	builder.wake_repair_drones()
	status = "Standby"
	balloon_alert(user, "drone linked")
	return ITEM_INTERACT_SUCCESS

/obj/structure/ship_repair_drone/process(seconds_per_tick)
	if(world.time < next_step)
		return
	next_step = world.time + (0.4 SECONDS)
	if(!console || !isturf(loc))
		stop_work()
		return
	if(!(console.console_upgrades & SHIP_CONSTRUCTION_UPGRADE_REPAIR))
		release_job()
		status = "Console upgrade required"
		SSship_repairs.workers -= src
		return
	if(console.repair_port && (console.repair_port.resolve() != console.get_docking_port() || QDELETED(console.repair_origin)))
		console.clear_repair_journal(TRUE)
		console.repair_status = "Ship connection lost."
	if(!recalling && (!enabled || !console.repair_enabled || !console.repair_origin))
		release_job()
		status = !enabled || !console.repair_enabled ? "Paused" : "Standby"
		SSship_repairs.workers -= src
		return
	var/returning_home = recalling || !length(console.repair_records)
	if(returning_home)
		release_job()
		// Parked fleets leave the budget even when their console has lost power.
		if(is_home())
			status = recalling ? "Recalled" : "Standby"
			recalling = FALSE
			SSship_repairs.workers -= src
			return
	if(!console.is_operational)
		release_job()
		if(console.machine_stat & NOPOWER)
			status = "Console unpowered"
		else if(console.machine_stat & BROKEN)
			status = "Console damaged"
		else
			status = "Console disabled"
		return
	if(!console.current_ship)
		release_job()
		status = "Ship connection lost"
		return
	// Flight repairs are independent of the dock-only manual construction controls.
	// Wait only while the hull's map tiles are being transferred between locations.
	if(console.current_ship.zone_transitioning || (console.current_ship.state != OVERMAP_SHIP_FLYING && console.current_ship.state != OVERMAP_SHIP_IDLE))
		release_job()
		status = "Ship repositioning"
		return
	if(returning_home)
		move_to_repair(get_turf(console))
		return
	if(!job)
		// Rotate through records fairly; inspect only one candidate per worker step.
		var/key = console.repair_records[1]
		var/datum/ship_repair_record/candidate = console.repair_records[key]
		console.repair_records -= key
		console.repair_records[key] = candidate
		if(candidate.claimed_by || world.time < candidate.retry_after)
			return
		job = candidate
		job.claimed_by = src
	var/turf/destination = console.repair_record_turf(job)
	var/list/repair = console.next_record_repair(job)
	if(!repair)
		if(!length(job.layers))
			console.forget_repair_record(console.repair_coordinate_key(destination))
		else
			job.retry_after = world.time + (3 SECONDS)
		release_job()
		return
	repair = console.affordable_record_repair(repair, job)
	if(!repair)
		stop_work()
		status = "Waiting for materials"
		if(console.repair_seal_needed(job))
			if(get_dist(src, destination) > 1 || z != destination.z)
				move_to_repair(destination)
				if(job)
					status = "Travelling to seal"
				return
			if(console.project_repair_seal(job))
				status = "Sealed; waiting for materials"
		next_step = world.time + (2 SECONDS)
		// Other affordable locations can proceed, but finish a started deck/wall pair.
		if(!repair_started)
			job.retry_after = next_step
			release_job()
		return
	if(get_dist(src, destination) > 1 || z != destination.z)
		stop_work()
		move_to_repair(destination)
		return
	if(work_finishes && (QDELETED(work_effect) || work_effect.loc != destination || work_effect.design_path != repair["path"]))
		stop_work()
		job.retry_after = world.time + (2 SECONDS)
		next_step = job.retry_after
		status = "Repair interrupted"
		return
	if(!work_finishes)
		var/delay = (3 SECONDS) * console.get_build_speed_mod()
		work_finishes = world.time + delay
		var/facing = turn(repair["dir"] || SOUTH, -dir2angle(console.repair_origin.dir))
		work_effect = new(destination, delay, repair["path"], facing)
		if(delay)
			work_beam = Beam(work_effect, icon_state = "rped_upgrade", maxdistance = 2)
		playsound(src, 'sound/items/tools/welder.ogg', 35, TRUE, pressure_affected = FALSE)
		status = "Repairing"
	if(world.time < work_finishes)
		return
	if(console.perform_record_repair(job))
		work_effect.end_animation()
		work_effect = null
		stop_work()
		repaired++
		repair_started = TRUE
		status = "Repair complete"
		if(!console.next_record_repair(job))
			if(!length(job.layers))
				console.forget_repair_record(console.repair_coordinate_key(destination))
			else
				job.retry_after = world.time + (3 SECONDS)
				release_job()
		return
	else
		status = "Waiting for materials / clear tile"
		job.retry_after = world.time + (2 SECONDS)
		next_step = job.retry_after
	release_job()

/obj/structure/ship_repair_drone/proc/is_home()
	return console && z == console.z && get_dist(src, console) <= 1

/obj/structure/ship_repair_drone/proc/move_to_repair(turf/destination)
	var/turf/next = destination?.z == z ? get_step_towards(src, destination) : null
	if(!next || !console.can_move_to(next))
		if(job)
			job.retry_after = world.time + (5 SECONDS)
		release_job()
		status = "Outside ship range"
		next_step = world.time + (3 SECONDS)
		return
	// Hover over obstacles without opening doors, searching paths, or caching turfs.
	setDir(get_dir(src, next))
	forceMove(next)
	status = recalling || !length(console.repair_records) ? "Returning" : "Travelling to repair"

/obj/machinery/computer/camera_advanced/base_construction/ship/proc/repair_controls_data()
	var/list/drones = list()
	for(var/obj/structure/ship_repair_drone/drone as anything in repair_drones)
		drones += list(list("ref" = REF(drone), "name" = drone.name, "status" = drone.status, "enabled" = drone.enabled, "repaired" = drone.repaired))
	return list(
		"repairUnlocked" = !!(console_upgrades & SHIP_CONSTRUCTION_UPGRADE_REPAIR),
		"repairEnabled" = repair_enabled,
		"repairTracking" = repair_tracking,
		"repairStatus" = repair_status,
		"repairRecords" = length(repair_records),
		"repairRecordLimit" = SHIP_REPAIR_JOURNAL_LIMIT,
		"repairOverflow" = repair_overflow,
		"repairDroneLimit" = SHIP_REPAIR_DRONE_LIMIT,
		"repairDrones" = drones,
	)

/obj/machinery/computer/camera_advanced/base_construction/ship/proc/repair_control_act(action, list/params, mob/user)
	if(!is_crew_member(user) || !(console_upgrades & SHIP_CONSTRUCTION_UPGRADE_REPAIR))
		return FALSE
	switch(action)
		if("repair_tracking")
			set_repair_tracking(!repair_tracking)
			return TRUE
		if("repair_clear")
			clear_repair_journal()
			repair_status = "Repair backlog cleared."
			return TRUE
		if("repair_toggle")
			repair_enabled = !repair_enabled
			wake_repair_drones()
			return TRUE
		if("repair_drone_toggle", "repair_drone_recall", "repair_recall_all")
			for(var/obj/structure/ship_repair_drone/drone as anything in repair_drones)
				if(action != "repair_recall_all" && REF(drone) != params["ref"])
					continue
				drone.release_job()
				if(action == "repair_drone_toggle")
					drone.enabled = !drone.enabled
					drone.recalling = FALSE
				else
					drone.enabled = FALSE
					drone.recalling = TRUE
			wake_repair_drones()
			return TRUE
	return FALSE
