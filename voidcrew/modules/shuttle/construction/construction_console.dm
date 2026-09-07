/**
 * Ship Construction Console
 *
 * A console for managing ship construction and modifications.
 * Inherits from the base construction console to provide RCD-based building
 * within shuttle areas and one tile adjacent (for expansion).
 *
 * Features:
 * - Remote construction drone control
 * - RCD building within shuttle and adjacent tiles
 * - Automatic shuttle expansion when building adjacent
 * - Automatic shuttle shrinking when deconstructing
 * - Docking port relocation
 * - Ore silo resource link
 * - Camera placement bound to the ship's camera network
 */

/// How much material per RCD unit when using silo link (1/4 sheet per unit)
#define SHIP_RCD_SILO_USE_AMOUNT (SHEET_MATERIAL_AMOUNT / 4)

// ============================================
// Ship Internal RCD - bypasses account checks
// ============================================

/**
 * Hull-grade windows only the construction drone can lay.
 *
 * Kept out of GLOB.rcd_designs on purpose: these are ship hull plating in window form, and
 * a pocket RCD printing 1200-integrity plastitanium out of generic matter would be a very
 * different thing from a drone spending the silo's titanium and plasma on it. The console's
 * RCD merges this tree into the stock one in get_rcd_designs(); the spritesheet asset
 * (code/modules/asset_cache/assets/rcd.dm) reads it so these get design icons like any other.
 *
 * Full tile only. Hulls are built out of full tiles, and the directional plasma windows
 * share initial(name) with their full tile counterparts - the design list keys both the
 * selection highlight and the sprite class off that name, so they would collide.
 */
GLOBAL_LIST_INIT(ship_rcd_hull_designs, list(
	"Construction" = list(
		"Hull Windows" = list(
			list(RCD_DESIGN_MODE = RCD_WINDOWGRILLE, RCD_DESIGN_PATH = /obj/structure/window/plasma/fulltile),
			list(RCD_DESIGN_MODE = RCD_WINDOWGRILLE, RCD_DESIGN_PATH = /obj/structure/window/reinforced/plasma/fulltile),
			list(RCD_DESIGN_MODE = RCD_WINDOWGRILLE, RCD_DESIGN_PATH = /obj/structure/window/reinforced/shuttle),
			list(RCD_DESIGN_MODE = RCD_WINDOWGRILLE, RCD_DESIGN_PATH = /obj/structure/window/reinforced/plasma/plastitanium),
		),
	),
))

/// Ship-specific internal RCD that bypasses ore silo account checks
/// This is needed because remote construction doesn't have a user with an ID card
/obj/item/construction/rcd/internal/ship
	name = "ship internal RCD"
	/// Reference to the ship construction console for drone tracking
	var/obj/machinery/computer/camera_advanced/base_construction/ship/ship_console
	/// Currently selected wall type name
	var/selected_wall_type = "Iron Wall"
	/// Currently selected floor type name
	var/selected_floor_type = "Plating"

	/// Static list of available wall types with their paths and material costs
	/// Note: Plastitanium is an alloy (titanium + plasma), so we require the component materials
	var/static/list/wall_types = list(
		"Iron Wall" = list(
			"path" = /turf/closed/wall,
			"materials" = list(/datum/material/iron = 200)
		),
		"Titanium Wall" = list(
			"path" = /turf/closed/wall/mineral/titanium,
			"materials" = list(/datum/material/titanium = 200)
		),
		"Plastitanium Wall" = list(
			"path" = /turf/closed/wall/mineral/plastitanium,
			"materials" = list(/datum/material/titanium = 100, /datum/material/plasma = 100)
		),
	)

	/// Static list of available floor types with their paths and material costs
	/// Note: Plastitanium is an alloy (titanium + plasma), so we require the component materials
	var/static/list/floor_types = list(
		"Plating" = list(
			"path" = /turf/open/floor/plating,
			"materials" = list(/datum/material/iron = 100)
		),
		"Titanium Floor" = list(
			"path" = /turf/open/floor/mineral/titanium,
			"materials" = list(/datum/material/titanium = 50)
		),
		"Plastitanium Floor" = list(
			"path" = /turf/open/floor/mineral/plastitanium,
			"materials" = list(/datum/material/titanium = 25, /datum/material/plasma = 25)
		),
	)

	/// Silo recipe for each hull window in GLOB.ship_rcd_hull_designs, keyed by window path.
	/// Two glass sheets a tile like any full tile window, plus the alloy's own components the
	/// way the wall and floor recipes above take theirs, plus a sheet of iron for the rod
	/// matrix in the reinforced ones (the same premium upstream charges reinforced windows).
	var/static/list/hull_window_materials = list(
		/obj/structure/window/plasma/fulltile = list(
			/datum/material/glass = 200,
			/datum/material/plasma = 100,
		),
		/obj/structure/window/reinforced/plasma/fulltile = list(
			/datum/material/glass = 200,
			/datum/material/plasma = 100,
			/datum/material/iron = 100,
		),
		/obj/structure/window/reinforced/shuttle = list(
			/datum/material/glass = 200,
			/datum/material/titanium = 100,
			/datum/material/iron = 100,
		),
		/obj/structure/window/reinforced/plasma/plastitanium = list(
			/datum/material/glass = 200,
			/datum/material/titanium = 100,
			/datum/material/plasma = 100,
			/datum/material/iron = 100,
		),
	)

/// The stock RCD design tree with the hull windows folded in under Construction.
/obj/item/construction/rcd/internal/ship/get_rcd_designs()
	var/static/list/ship_designs
	if(isnull(ship_designs))
		ship_designs = GLOB.rcd_designs.Copy()
		for(var/root_category in GLOB.ship_rcd_hull_designs)
			var/list/extra_categories = GLOB.ship_rcd_hull_designs[root_category]
			//copy before writing: the stock tree is shared with every other RCD in the round
			var/list/merged_categories = ship_designs[root_category]
			merged_categories = isnull(merged_categories) ? list() : merged_categories.Copy()
			for(var/category in extra_categories)
				merged_categories[category] = extra_categories[category]
			ship_designs[root_category] = merged_categories
	return ship_designs

/// Whether design_path is one of the hull windows this console lays in a single action.
/obj/item/construction/rcd/internal/ship/proc/is_hull_window(design_path)
	return !isnull(hull_window_materials[design_path])

/// The console owns us and we point back at it; drop that back-reference on the way
/// out, or console and RCD keep each other alive and both hard delete.
/obj/item/construction/rcd/internal/ship/Destroy()
	ship_console = null
	return ..()

/**
 * Directional builds face the way the DRONE faces, not the operator's body.
 *
 * The operator is sat at a console with their remote_control set, so every direction key they
 * press is relayed straight to the eye (/client/Move -> remote_control.relaymove) and their
 * body never turns - it keeps whatever facing it had when they sat down. The drone does turn:
 * /mob/eye/camera/remote/base_construction/relaymove() assigns `dir = direction` on every
 * step, precisely because it is a visible drone.
 *
 * So the operator's dir is not merely the wrong one, it is a frozen one. Every directional
 * window, windoor, chair, table, rack and bed the drone built came out facing wherever they
 * happened to be pointing when they took the console, with no way to aim it short of standing
 * up and turning round (issue #224). The RLD's wall lights already read the drone's dir; this
 * is the RCD half of the same rule.
 */
/obj/item/construction/rcd/internal/ship/rcd_build_dir(mob/user)
	var/mob/eye/camera/remote/drone = ship_console?.eyeobj
	return drone ? drone.dir : ..()

/// Multiplier applied to our own build delays, from the console's fabrication servo upgrades.
/// Returns 1 when the console has no speed upgrade installed (or we've been unlinked).
/obj/item/construction/rcd/internal/ship/proc/get_build_speed_mod()
	return ship_console ? ship_console.get_build_speed_mod() : 1

/// Override build_delay to cancel if the drone moves
/obj/item/construction/rcd/internal/ship/build_delay(mob/user, delay, atom/target)
	if(delay <= 0)
		return TRUE

	// Get the drone's current location to track movement
	var/mob/eye/camera/remote/drone = ship_console?.eyeobj
	if(!drone)
		return ..()

	var/turf/drone_start_turf = get_turf(drone)

	// Create a callback that checks if the drone moved
	var/datum/callback/drone_check = CALLBACK(src, PROC_REF(check_drone_stationary), drone, drone_start_turf)

	return do_after(user, delay, target, extra_checks = drone_check)

/// Callback to check if drone is still on the same turf
/obj/item/construction/rcd/internal/ship/proc/check_drone_stationary(mob/eye/camera/remote/drone, turf/start_turf)
	if(QDELETED(drone))
		return FALSE
	return get_turf(drone) == start_turf

/// Show a balloon alert at the drone location (or fallback to user)
/obj/item/construction/rcd/internal/ship/proc/drone_alert(mob/user, message)
	var/mob/eye/camera/remote/drone = ship_console?.eyeobj
	if(drone)
		drone.balloon_alert(user, message)
	else if(user)
		balloon_alert(user, message)

/// Override to bypass account check when using silo - ships use SILICON_OVERRIDE
/obj/item/construction/rcd/internal/ship/useResource(amount, mob/user)
	if(!silo_mats || !silo_link)
		return ..()

	if(!silo_mats.mat_container)
		if(user)
			drone_alert(user, "no silo detected!")
		return FALSE

	if(!silo_mats.mat_container.has_enough_of_material(/datum/material/iron, amount * SHIP_RCD_SILO_USE_AMOUNT))
		if(user)
			drone_alert(user, "not enough silo material!")
		return FALSE

	// Use SILICON_OVERRIDE to bypass account check for ship construction
	var/list/user_data = ID_DATA(user)
	user_data[SILICON_OVERRIDE] = SILICON_OVERRIDE
	silo_mats.use_materials(list(/datum/material/iron = SHIP_RCD_SILO_USE_AMOUNT), multiplier = amount, action = "build", name = "ship construction", user_data = user_data)
	return TRUE

/// Override to bypass account check when checking resources
/obj/item/construction/rcd/internal/ship/checkResource(amount, mob/user)
	if(!silo_mats || !silo_mats.mat_container || !silo_link)
		return ..()

	// Use SILICON_OVERRIDE to bypass account check for ship construction
	var/list/user_data = ID_DATA(user)
	user_data[SILICON_OVERRIDE] = SILICON_OVERRIDE
	if(!silo_mats.can_use_resource(user_data = user_data))
		return FALSE
	. = silo_mats.mat_container.has_enough_of_material(/datum/material/iron, amount * SHIP_RCD_SILO_USE_AMOUNT)
	if(!. && user)
		drone_alert(user, "low ammo!")
		if(has_ammobar)
			flick("[icon_state]_empty", src)
	return .

/// Use the action's saved mode so changing blueprints during a delay cannot change its charge.
/obj/item/construction/rcd/internal/ship/check_rcd_resources(list/rcd_results, mob/user)
	if(rcd_results["[RCD_DESIGN_MODE]"] == RCD_DECONSTRUCT)
		return can_refund_materials(user)
	return ..()

/obj/item/construction/rcd/internal/ship/use_rcd_resources(list/rcd_results, mob/user)
	if(rcd_results["[RCD_DESIGN_MODE]"] == RCD_DECONSTRUCT)
		return TRUE
	return ..()

/// Demolition needs somewhere to put the recovered materials, but works with an empty silo.
/obj/item/construction/rcd/internal/ship/proc/can_refund_materials(mob/user)
	if(!silo_link || QDELETED(silo_mats?.mat_container))
		drone_alert(user, "no silo linked!")
		return FALSE
	return TRUE

/// Deposit only recovered materials, and record the positive transaction in the silo log.
/obj/item/construction/rcd/internal/ship/proc/refund_materials(list/materials, mob/user)
	if(!length(materials) || !can_refund_materials(user))
		return FALSE
	var/list/returned_materials = list()
	for(var/material in materials)
		var/amount = silo_mats.mat_container.insert_amount_mat(materials[material], material)
		if(amount > 0)
			returned_materials[material] = amount
	if(!length(returned_materials))
		return FALSE
	silo_mats.silo?.silo_log(ship_console || src, "recycle", 1, "ship construction", returned_materials, ID_DATA(user))
	drone_alert(user, "materials returned")
	return TRUE

/// Hull materials follow the material picker, not the currently selected blueprint.
/// Standard RCD salvage is capped at the cheapest rebuild, including RCD memory discounts.
/obj/item/construction/rcd/internal/ship/proc/get_deconstruction_materials(atom/target)
	if(iswallturf(target))
		// Check the specific mineral types before the base iron wall.
		for(var/wall_name in list("Plastitanium Wall", "Titanium Wall", "Iron Wall"))
			var/list/wall_info = wall_types[wall_name]
			if(istype(target, wall_info["path"]))
				return wall_info["materials"].Copy()
	if(isfloorturf(target))
		for(var/floor_name in list("Plastitanium Floor", "Titanium Floor"))
			var/list/floor_info = floor_types[floor_name]
			if(istype(target, floor_info["path"]))
				return floor_info["materials"].Copy()
		// Plating can also be built with one RCD unit over a lattice.
		if(istype(target, /turf/open/floor/plating))
			return list(/datum/material/iron = SHIP_RCD_SILO_USE_AMOUNT)
		return list(/datum/material/iron = SHIP_RTD_TILE_IRON)
	if(istype(target, /obj/machinery/camera))
		return list(/datum/material/iron = SHIP_CAMERA_IRON_COST, /datum/material/glass = SHIP_CAMERA_GLASS_COST)
	if(istype(target, /obj/machinery/light/floor))
		return list(/datum/material/iron = SHIP_RLD_FLOOR_LIGHT_IRON, /datum/material/glass = SHIP_RLD_FLOOR_LIGHT_GLASS)
	if(istype(target, /obj/machinery/light))
		return list(/datum/material/iron = SHIP_RLD_WALL_LIGHT_IRON, /datum/material/glass = SHIP_RLD_WALL_LIGHT_GLASS)

	// Hull windows were paid for by recipe, so they come back as one - the generic salvage
	// below would hand back a few units of iron for a tile of plastitanium.
	var/list/hull_window_recipe = hull_window_materials[target.type]
	if(hull_window_recipe)
		return hull_window_recipe.Copy()

	var/units = 0
	if(istype(target, /obj/structure/window))
		var/obj/structure/window/window = target
		units = (window.reinf ? 6 : 4) * (window.fulltile ? 2 : 1) / RCD_MEMORY_COST_BUFF
	else if(istype(target, /obj/structure/grille))
		units = 4 / RCD_MEMORY_COST_BUFF
	else if(istype(target, /obj/machinery/door/airlock))
		units = istype(target, /obj/machinery/door/airlock/glass) ? 20 : 16
	else if(istype(target, /obj/machinery/door/window))
		units = 16
	else if(istype(target, /obj/structure/table) || istype(target, /obj/structure/girder))
		units = 8
	else if(istype(target, /obj/structure/lattice/catwalk))
		units = 2
	else if(istype(target, /obj/structure/door_assembly) || istype(target, /obj/structure/firelock_frame))
		units = 4
	return units ? list(/datum/material/iron = OPTIMAL_COST(units * SHIP_RCD_SILO_USE_AMOUNT)) : null

/// The RCD's outer return value also reports handled failures, so refund at the actual success point.
/obj/item/construction/rcd/internal/ship/apply_rcd_action(atom/target, mob/user, list/rcd_results)
	if(rcd_results["[RCD_DESIGN_MODE]"] != RCD_DECONSTRUCT)
		return ..()
	if(QDELETED(target) || !can_refund_materials(user))
		return FALSE
	var/list/materials = get_deconstruction_materials(target)
	var/turf/target_turf = isturf(target) ? target : null
	var/original_turf_type = target_turf?.type
	var/original_layers = target_turf?.count_baseturfs()
	if(!..())
		return FALSE
	// ScrapeAway can report success at the bottom of a turf stack without removing anything.
	if(target_turf)
		var/turf/remaining_turf = locate(target_turf.x, target_turf.y, target_turf.z)
		if(remaining_turf.type == original_turf_type && remaining_turf.count_baseturfs() >= original_layers)
			return FALSE
	refund_materials(materials, user)
	return TRUE

// ============================================
// Ship RCD TGUI Interface
// ============================================

/// Always allow UI interaction for remote construction
/obj/item/construction/rcd/internal/ship/ui_state(mob/user)
	return GLOB.always_state

/obj/item/construction/rcd/internal/ship/ui_status(mob/user, datum/ui_state/state)
	if(ship_console && (ship_console.current_user != user || user.remote_control != ship_console.eyeobj))
		return UI_CLOSE
	return ..()

/// Override ui_interact to use our custom ShipRCD interface (extends standard RCD UI)
/obj/item/construction/rcd/internal/ship/ui_interact(mob/user, datum/tgui/ui)
	ui = SStgui.try_update_ui(user, src, ui)
	if(!ui)
		ui = new(user, src, "ShipRCD", name)
		ui.open()

/obj/item/construction/rcd/internal/ship/ui_data(mob/user)
	// Get all standard RCD data from parent
	var/list/data = ..()
	if(ship_console)
		data += ship_console.construction_controls_data()

	// Add ship-specific wall/floor type data
	data["selectedWallType"] = selected_wall_type
	data["selectedFloorType"] = selected_floor_type

	// Wall types with material info
	var/list/wall_type_data = list()
	for(var/wall_name in wall_types)
		var/list/wall_info = wall_types[wall_name]
		var/list/materials_data = list()
		for(var/mat_path in wall_info["materials"])
			var/datum/material/mat = GET_MATERIAL_REF(mat_path)
			materials_data += list(list(
				"name" = mat ? mat.name : "Unknown",
				"amount" = wall_info["materials"][mat_path]
			))
		wall_type_data += list(list(
			"name" = wall_name,
			"materials" = materials_data
		))
	data["wallTypes"] = wall_type_data

	// Floor types with material info
	var/list/floor_type_data = list()
	for(var/floor_name in floor_types)
		var/list/floor_info = floor_types[floor_name]
		var/list/materials_data = list()
		for(var/mat_path in floor_info["materials"])
			var/datum/material/mat = GET_MATERIAL_REF(mat_path)
			materials_data += list(list(
				"name" = mat ? mat.name : "Unknown",
				"amount" = floor_info["materials"][mat_path]
			))
		floor_type_data += list(list(
			"name" = floor_name,
			"materials" = materials_data
		))
	data["floorTypes"] = floor_type_data

	// Silo materials for display
	data["usingSilo"] = silo_link && silo_mats?.mat_container
	var/list/silo_materials = list()
	if(silo_link && silo_mats?.mat_container)
		for(var/datum/material/mat as anything in silo_mats.mat_container.materials)
			var/amount = silo_mats.mat_container.materials[mat]
			if(amount > 0)
				silo_materials[mat.name] = amount
	data["siloMaterials"] = silo_materials

	return data

/obj/item/construction/rcd/internal/ship/handle_ui_act(action, list/params, datum/tgui/ui, datum/ui_state/state)
	if(ship_console?.construction_control_act(action, params, usr))
		return TRUE
	// Handle our custom actions first
	switch(action)
		if("select_wall_type")
			var/new_type = params["type"]
			if(new_type in wall_types)
				selected_wall_type = new_type
				playsound(src, SFX_TOOL_SWITCH, 20, TRUE)
				return TRUE
		if("select_floor_type")
			var/new_type = params["type"]
			if(new_type in floor_types)
				selected_floor_type = new_type
				playsound(src, SFX_TOOL_SWITCH, 20, TRUE)
				return TRUE

	// Pass to parent for standard RCD actions
	return ..()

/// Get the turf path for the currently selected wall type
/obj/item/construction/rcd/internal/ship/proc/get_selected_wall_path()
	var/list/wall_info = wall_types[selected_wall_type]
	if(!wall_info)
		return /turf/closed/wall
	return wall_info["path"]

/// Get the turf path for the currently selected floor type
/obj/item/construction/rcd/internal/ship/proc/get_selected_floor_path()
	var/list/floor_info = floor_types[selected_floor_type]
	if(!floor_info)
		return /turf/open/floor/plating
	return floor_info["path"]

/// Get the materials list for the currently selected wall type
/obj/item/construction/rcd/internal/ship/proc/get_selected_wall_materials()
	var/list/wall_info = wall_types[selected_wall_type]
	if(!wall_info)
		return list(/datum/material/iron = 200)
	return wall_info["materials"]

/// Get the materials list for the currently selected floor type
/obj/item/construction/rcd/internal/ship/proc/get_selected_floor_materials()
	var/list/floor_info = floor_types[selected_floor_type]
	if(!floor_info)
		return list(/datum/material/iron = 100)
	return floor_info["materials"]

/// Check if we have enough materials in the silo for the given materials list
/obj/item/construction/rcd/internal/ship/proc/check_materials(list/materials, mob/user)
	if(!silo_mats?.mat_container || !silo_link)
		if(user)
			drone_alert(user, "no silo linked!")
		return FALSE
	var/list/user_data = ID_DATA(user)
	user_data[SILICON_OVERRIDE] = SILICON_OVERRIDE
	if(!silo_mats.can_use_resource(user_data = user_data))
		return FALSE

	for(var/mat_path in materials)
		var/required = materials[mat_path]
		if(!silo_mats.mat_container.has_enough_of_material(mat_path, required))
			if(user)
				var/datum/material/mat = GET_MATERIAL_REF(mat_path)
				drone_alert(user, "not enough [mat?.name || "material"]!")
			return FALSE

	return TRUE

/// Use materials from the silo for the given materials list
/obj/item/construction/rcd/internal/ship/proc/use_materials(list/materials, mob/user)
	if(!silo_mats?.mat_container || !silo_link)
		return FALSE

	// Double check we have enough before using
	if(!check_materials(materials, user))
		return FALSE

	// Use SILICON_OVERRIDE to bypass account check for ship construction
	var/list/user_data = ID_DATA(user)
	user_data[SILICON_OVERRIDE] = SILICON_OVERRIDE
	return silo_mats.use_materials(materials, action = "build", name = "ship construction", user_data = user_data) > 0

/// Check if we have enough materials for the selected wall type
/obj/item/construction/rcd/internal/ship/proc/check_wall_materials(mob/user)
	return check_materials(get_selected_wall_materials(), user)

/// Check if we have enough materials for the selected floor type
/obj/item/construction/rcd/internal/ship/proc/check_floor_materials(mob/user)
	return check_materials(get_selected_floor_materials(), user)

/// Use materials for the selected wall type
/obj/item/construction/rcd/internal/ship/proc/use_wall_materials(mob/user)
	return use_materials(get_selected_wall_materials(), user)

/// Use materials for the selected floor type
/obj/item/construction/rcd/internal/ship/proc/use_floor_materials(mob/user)
	return use_materials(get_selected_floor_materials(), user)

/// Build a wall of the selected type at the target turf
/obj/item/construction/rcd/internal/ship/proc/build_wall(turf/target, mob/user)
	var/wall_path = get_selected_wall_path()
	var/list/materials = get_selected_wall_materials()
	if(!isfloorturf(target) || target.is_blocked_turf(exclude_mobs = FALSE) || !check_materials(materials, user))
		return FALSE

	var/build_time = SHIP_RCD_WALL_BUILD_DELAY * get_build_speed_mod()

	// Show construction effect
	var/obj/effect/constructing_effect/rcd_effect = new(target, build_time, RCD_TURF)

	// Delay for building
	if(!build_delay(user, build_time, target))
		qdel(rcd_effect)
		return FALSE

	// Double check materials after delay
	if(!isfloorturf(target) || target.is_blocked_turf(exclude_mobs = FALSE) || !use_materials(materials, user))
		qdel(rcd_effect)
		return FALSE

	// Build the wall.
	// place_on_top() rather than ChangeTurf() so the floor we are building over is pushed
	// onto the wall's baseturf stack. ChangeTurf() copies the *old* turf's baseturfs onto
	// the new wall (voidcrew/edits/turf.dm), which throws the floor away and leaves the
	// wall sitting straight on space - deconstructing it then drops you into vacuum
	// instead of leaving plating behind, and the scraped tile stops being a shuttle turf
	// so clear_empty_shuttle_turfs() drops it out of the hull entirely. This is the same
	// marker-less-chain problem restamp_hull_marker() below papers over for breach
	// repairs; stacking properly fixes it at the source for walls. Matches how hand-built
	// walls (girders) and the standard RCD (/turf/open/floor/rcd_act) raise walls.
	var/turf/new_wall = target.place_on_top(wall_path, flags = CHANGETURF_INHERIT_AIR)
	restamp_hull_marker(new_wall)
	rcd_effect.end_animation()
	return TRUE

/// Build a floor of the selected type at the target turf
/obj/item/construction/rcd/internal/ship/proc/build_floor(turf/target, mob/user)
	var/floor_path = get_selected_floor_path()
	var/list/materials = get_selected_floor_materials()
	if(!isspaceturf(target) || !check_materials(materials, user))
		return FALSE

	var/build_time = SHIP_RCD_FLOOR_BUILD_DELAY * get_build_speed_mod()

	// Show construction effect
	var/obj/effect/constructing_effect/rcd_effect = new(target, build_time, RCD_TURF)

	// Delay for building
	if(!build_delay(user, build_time, target))
		qdel(rcd_effect)
		return FALSE

	// Double check materials after delay
	if(!isspaceturf(target) || !use_materials(materials, user))
		qdel(rcd_effect)
		return FALSE

	// Build the floor
	var/turf/new_floor = target.ChangeTurf(floor_path, flags = CHANGETURF_INHERIT_AIR)
	restamp_hull_marker(new_floor)
	rcd_effect.end_animation()
	return TRUE

/**
 * Build the selected hull window, grille and all, on the target turf.
 *
 * The stock RCD lays a full tile window in two clicks - a grille on the floor, then the
 * window on the grille - because a handheld RCD pays for both out of one pool of matter.
 * These are paid for by recipe out of the silo instead, so the drone does the whole tile in
 * one action and one charge, the same way build_wall() and build_floor() do.
 */
/obj/item/construction/rcd/internal/ship/proc/build_hull_window(turf/target, mob/user)
	var/obj/structure/window/window_path = rcd_design_path
	var/list/window_materials = hull_window_materials[window_path]
	if(!window_materials)
		return FALSE
	if(!isfloorturf(target))
		drone_alert(user, "needs a floor!")
		return FALSE
	//a full tile window fills the tile, so nothing may be standing on it - except a grille,
	//which is part of the window we are about to build
	if(!can_place_hull_window(target))
		drone_alert(user, "something is on the tile!")
		return FALSE
	var/list/materials = window_materials.Copy()
	if(!(locate(/obj/structure/grille) in target))
		materials[/datum/material/iron] += SHEET_MATERIAL_AMOUNT
	if(!check_materials(materials, user))
		return FALSE

	var/build_time = SHIP_RCD_WINDOW_BUILD_DELAY * get_build_speed_mod()
	var/obj/effect/constructing_effect/rcd_effect = new(target, build_time, RCD_WINDOWGRILLE)

	if(!build_delay(user, build_time, target))
		qdel(rcd_effect)
		return FALSE
	//recheck after the delay: someone else may have filled the tile while we worked
	materials = window_materials.Copy()
	if(!(locate(/obj/structure/grille) in target))
		materials[/datum/material/iron] += SHEET_MATERIAL_AMOUNT
	if(!can_place_hull_window(target) || !use_materials(materials, user))
		qdel(rcd_effect)
		return FALSE

	var/obj/structure/grille/grille = locate() in target
	if(isnull(grille))
		grille = new(target)
	grille.set_anchored(TRUE)
	var/obj/structure/window/new_window = new window_path(target)
	new_window.set_anchored(TRUE)
	rcd_effect.end_animation()
	return TRUE

/// Whether a full tile hull window still fits on this turf. Grilles are ours to reuse.
/obj/item/construction/rcd/internal/ship/proc/can_place_hull_window(turf/target)
	return !target.is_blocked_turf(exclude_mobs = FALSE, source_atom = null, ignore_atoms = list(/obj/structure/grille), type_list = TRUE)

/**
 * A breach's ScrapeAway() walks past /turf/baseturf_skipover/shuttle and deletes it
 * (baseturfs.dm), and ChangeTurf() carries the marker-less chain onto the rebuilt tile.
 * The repair then fails isshuttleturf(), fromShuttleMove() never grants it MOVE_TURF,
 * and the tile is left behind at the berth on the next move - "I repaired my ship with
 * the drone console and when I undock the repairs went with it".
 *
 * reconcile_hull_before_move() deliberately cannot restamp these: by move time it has
 * no way to tell a repaired deck tile from site ground adopted through the breach. At
 * rebuild time we still can - a console build inside a hull area is explicit deck
 * repair - so restore the marker here, the same way build_with_floor_tiles() does for
 * manual tile repairs (see /turf/open/build_with_floor_tiles in _open.dm).
 */
/obj/item/construction/rcd/internal/ship/proc/restamp_hull_marker(turf/built)
	if(isnull(built) || !istype(built.loc, /area/shuttle) || isshuttleturf(built))
		return
	built.insert_baseturf(turf_type = /turf/baseturf_skipover/shuttle)

/// Build a finished security camera on the target turf, hung on the wall in wall_dir.
/// Returns the new camera so the caller can finish setup (network binding), or null on failure.
/obj/item/construction/rcd/internal/ship/proc/build_camera(turf/target, wall_dir, mob/user)
	var/list/camera_materials = list(
		/datum/material/iron = SHIP_CAMERA_IRON_COST,
		/datum/material/glass = SHIP_CAMERA_GLASS_COST,
	)
	if(!check_materials(camera_materials, user))
		return null

	var/build_time = SHIP_CAMERA_BUILD_DELAY * get_build_speed_mod()

	// Show construction effect
	var/obj/effect/constructing_effect/rcd_effect = new(target, build_time, RCD_STRUCTURE)

	// Delay for building
	if(!build_delay(user, build_time, target))
		qdel(rcd_effect)
		return null

	// Double check materials after delay
	if(!use_materials(camera_materials, user))
		qdel(rcd_effect)
		return null

	// Mount the camera like a handheld wallframe would: on the open turf, facing its wall
	var/obj/machinery/camera/new_camera = new(target, wall_dir, TRUE)
	rcd_effect.end_animation()
	return new_camera

// ============================================
// Ship Internal RTD - bypasses proximity checks
// ============================================


/// Ship-specific internal RTD that allows remote UI interaction and uses silo materials
/obj/item/construction/rtd/internal
	name = "ship internal RTD"
	/// Reference to the ship construction console for drone tracking
	var/obj/machinery/computer/camera_advanced/base_construction/ship/ship_console

/// Always allow UI interaction for remote construction
/obj/item/construction/rtd/internal/ui_state(mob/user)
	return GLOB.always_state

/// Show a balloon alert at the drone location (or fallback to user)
/obj/item/construction/rtd/internal/proc/drone_alert(mob/user, message)
	var/mob/eye/camera/remote/drone = ship_console?.eyeobj
	if(drone)
		drone.balloon_alert(user, message)
	else if(user)
		balloon_alert(user, message)

/// Check if we have enough iron in the silo for a tile
/obj/item/construction/rtd/internal/proc/check_tile_materials(mob/user)
	if(!silo_mats?.mat_container || !silo_link)
		if(user)
			drone_alert(user, "no silo linked!")
		return FALSE

	if(!silo_mats.mat_container.has_enough_of_material(/datum/material/iron, SHIP_RTD_TILE_IRON))
		if(user)
			drone_alert(user, "not enough iron!")
		return FALSE

	return TRUE

/// Use iron from the silo for a tile
/obj/item/construction/rtd/internal/proc/use_tile_materials(mob/user)
	if(!check_tile_materials(user))
		return FALSE

	var/list/materials = list(/datum/material/iron = SHIP_RTD_TILE_IRON)

	// Use SILICON_OVERRIDE to bypass account check
	var/list/user_data = ID_DATA(user)
	user_data[SILICON_OVERRIDE] = SILICON_OVERRIDE
	silo_mats.use_materials(materials, action = "build", name = "ship tiling", user_data = user_data)
	return TRUE

// ============================================
// Ship Internal RPD - bypasses proximity checks
// ============================================


/// Ship-specific internal RPD that allows remote UI interaction and free pipe placement
/obj/item/pipe_dispenser/internal
	name = "ship internal RPD"
	/// Reference to the ship construction console for drone tracking
	var/obj/machinery/computer/camera_advanced/base_construction/ship/ship_console
	/// Reference to silo materials component
	var/datum/component/remote_materials/silo_mats
	/// Whether silo link is enabled
	var/silo_link = FALSE

/// Always allow UI interaction for remote construction
/obj/item/pipe_dispenser/internal/ui_state(mob/user)
	return GLOB.always_state

/// Show a balloon alert at the drone location (or fallback to user)
/obj/item/pipe_dispenser/internal/proc/drone_alert(mob/user, message)
	var/mob/eye/camera/remote/drone = ship_console?.eyeobj
	if(drone)
		drone.balloon_alert(user, message)
	else if(user)
		balloon_alert(user, message)

/**
 * A pressure blast is a location effect, so it hits whoever is standing at the pipe - not
 * whoever pressed the button.
 *
 * wrench_act() hands this proc whoever swung the tool, and everywhere else that is the same
 * person as "whoever is next to the pipe". It is not for the construction console: the drone
 * does the unwrenching several rooms away while the operator is sat at a keyboard, and the
 * stock proc threw the operator across the bridge every time a pressurised pipe came loose
 * (issue #224).
 *
 * So a remote unwrench keeps the blast, and moves it to where the blast actually is: every
 * living mob standing on the pipe's own tile gets the stock throw, at the stock range and
 * speed. An engineer holding a wrench over that pipe and an engineer who walked over it while
 * the drone worked are in the same place and take the same hit; the only thing that changed
 * is that the person at the console is no longer the one flying.
 *
 * Deliberately written as a general range test rather than a construction-console special
 * case: any remote unwrench has the same geometry, and a person who really is standing next
 * to the pipe still gets launched by the stock proc, exactly as before.
 */
/obj/machinery/atmospherics/unsafe_pressure_release(mob/user, pressures = null)
	if(!user || in_range(user, src))
		return ..()

	// Same fallback the stock proc uses when wrench_act() did not pass a figure. wrench_act()
	// always does, so this only matters to a caller that does not.
	if(!pressures)
		var/datum/gas_mixture/int_air = return_air()
		var/datum/gas_mixture/env_air = loc?.return_air()
		pressures = (int_air ? int_air.return_pressure() : 0) - (env_air ? env_air.return_pressure() : 0)

	visible_message(span_danger("[src] vents a hard gust of pressure as it comes loose!"))

	var/list/thrown = list()
	// A negative figure means the environment was the higher pressure, and there is nothing to
	// throw anyone with. wrench_act() only reaches here on unsafe_wrenching, so this is a
	// guard on the fallback above rather than a case play produces.
	if(pressures > 0)
		for(var/mob/living/victim in get_turf(src))
			thrown += victim
			victim.visible_message(span_danger("[victim] is sent flying by pressure!"), span_userdanger("The pressure sends you flying!"))
			// Stock range (pressures / 250) and speed (pressures / 1250). A mob on the pipe's
			// own tile has no direction from it, which is the case get_edge_target_turf()'s
			// random cardinal fallback exists for - the same one the stock proc hits when the
			// wrencher is standing on top of the pipe.
			victim.throw_at(get_edge_target_turf(victim, get_dir(src, victim) || pick(GLOB.cardinals)), pressures / 250, pressures / 1250)

	if(!length(thrown))
		to_chat(user, span_warning("[src] vents its pressure the moment it comes free. Nothing over there is bolted down any more."))
		return

	to_chat(user, span_warning("[src] vents its pressure the moment it comes free, and sends [english_list(thrown)] flying."))

// ============================================
// Ship Internal RLD - bypasses proximity checks
// ============================================


/// Ship-specific internal RLD that allows remote UI interaction and uses silo materials
/obj/item/construction/rld/internal
	name = "ship internal RLD"
	/// Reference to the ship construction console for drone tracking
	var/obj/machinery/computer/camera_advanced/base_construction/ship/ship_console

/// Show a balloon alert at the drone location (or fallback to user)
/obj/item/construction/rld/internal/proc/drone_alert(mob/user, message)
	var/mob/eye/camera/remote/drone = ship_console?.eyeobj
	if(drone)
		drone.balloon_alert(user, message)
	else if(user)
		balloon_alert(user, message)

/// Check if we have enough materials in the silo for a light type
/obj/item/construction/rld/internal/proc/check_silo_materials(iron_cost, glass_cost, mob/user)
	if(!silo_mats?.mat_container || !silo_link)
		if(user)
			drone_alert(user, "no silo linked!")
		return FALSE

	if(!silo_mats.mat_container.has_enough_of_material(/datum/material/iron, iron_cost))
		if(user)
			drone_alert(user, "not enough iron!")
		return FALSE

	if(!silo_mats.mat_container.has_enough_of_material(/datum/material/glass, glass_cost))
		if(user)
			drone_alert(user, "not enough glass!")
		return FALSE

	return TRUE

/// Use materials from the silo for a light
/obj/item/construction/rld/internal/proc/use_silo_materials(iron_cost, glass_cost, mob/user)
	if(!check_silo_materials(iron_cost, glass_cost, user))
		return FALSE

	var/list/materials = list(
		/datum/material/iron = iron_cost,
		/datum/material/glass = glass_cost
	)

	// Use SILICON_OVERRIDE to bypass account check
	var/list/user_data = ID_DATA(user)
	user_data[SILICON_OVERRIDE] = SILICON_OVERRIDE
	silo_mats.use_materials(materials, action = "build", name = "ship lighting", user_data = user_data)
	return TRUE

/// Check materials for wall light
/obj/item/construction/rld/internal/proc/check_wall_light_materials(mob/user)
	return check_silo_materials(SHIP_RLD_WALL_LIGHT_IRON, SHIP_RLD_WALL_LIGHT_GLASS, user)

/// Check materials for floor light
/obj/item/construction/rld/internal/proc/check_floor_light_materials(mob/user)
	return check_silo_materials(SHIP_RLD_FLOOR_LIGHT_IRON, SHIP_RLD_FLOOR_LIGHT_GLASS, user)

/// Check materials for glow stick
/obj/item/construction/rld/internal/proc/check_glow_stick_materials(mob/user)
	return check_silo_materials(SHIP_RLD_GLOW_STICK_IRON, SHIP_RLD_GLOW_STICK_GLASS, user)

/// Use materials for wall light
/obj/item/construction/rld/internal/proc/use_wall_light_materials(mob/user)
	return use_silo_materials(SHIP_RLD_WALL_LIGHT_IRON, SHIP_RLD_WALL_LIGHT_GLASS, user)

/// Use materials for floor light
/obj/item/construction/rld/internal/proc/use_floor_light_materials(mob/user)
	return use_silo_materials(SHIP_RLD_FLOOR_LIGHT_IRON, SHIP_RLD_FLOOR_LIGHT_GLASS, user)

/// Use materials for glow stick
/obj/item/construction/rld/internal/proc/use_glow_stick_materials(mob/user)
	return use_silo_materials(SHIP_RLD_GLOW_STICK_IRON, SHIP_RLD_GLOW_STICK_GLASS, user)

/// Override attack_self to show radial menu on the drone location (without Deconstruct option)
/obj/item/construction/rld/internal/attack_self(mob/user)
	// Play the parent sound effects
	playsound(loc, 'sound/effects/pop.ogg', 50, FALSE)
	if(prob(20))
		spark_system.start()

	// Build filtered options (exclude Deconstruct - we have a separate action for that)
	var/list/ship_options = list()
	for(var/option in display_options)
		if(option == "Deconstruct")
			continue
		ship_options[option] = display_options[option]

	if((construction_upgrades & RCD_UPGRADE_SILO_LINK) && ship_options["Silo Link"] == null)
		ship_options["Silo Link"] = icon(icon = 'icons/obj/machines/ore_silo.dmi', icon_state = "silo")

	// Show radial menu on the drone location with no proximity requirement
	var/mob/eye/camera/remote/drone = ship_console?.eyeobj
	var/atom/menu_anchor = drone ? drone : src
	var/choice = show_radial_menu(user, menu_anchor, ship_options, custom_check = CALLBACK(src, PROC_REF(check_menu), user), require_near = FALSE, tooltips = TRUE)
	if(!check_menu(user))
		return
	if(!choice)
		return

	// RLD mode values: 1 = GLOW_MODE, 2 = LIGHT_MODE
	switch(choice)
		if("Light Fixture")
			mode = 2 // LIGHT_MODE
			to_chat(user, span_notice("You change RLD's mode to 'Permanent Light Construction'."))
		if("Glow Stick")
			mode = 1 // GLOW_MODE
			to_chat(user, span_notice("You change RLD's mode to 'Light Launcher'."))
		if("Color Pick")
			var/new_choice = input(user,"","Choose Color",color_choice) as color
			if(new_choice == null)
				return

			var/list/new_rgb = rgb2num(new_choice)
			for(var/option in original_options)
				if(option == "Color Pick" || option == "Deconstruct" || option == "Silo Link")
					continue
				var/icon/the_icon = icon(original_options[option])
				the_icon.SetIntensity(new_rgb[1]/255, new_rgb[2]/255, new_rgb[3]/255)
				display_options[option] = the_icon

			color_choice = new_choice
		else
			toggle_silo(user)

/obj/machinery/computer/camera_advanced/base_construction/ship
	name = "ship construction console"
	desc = "A console for managing ship construction and modifications. Control a remote drone to build and modify your ship."
	icon = 'voidcrew/modules/shuttle/icons/computer.dmi'
	icon_screen = "construction"
	icon_keyboard = "power_key"
	circuit = /obj/item/circuitboard/computer/ship_construction
	light_color = LIGHT_COLOR_CYAN
	// Ships don't use camera networks - the drone doesn't need visibility checks
	networks = list()

	/// The ship we are connected to
	var/obj/structure/overmap/ship/current_ship
	/// Status message for last operation
	var/last_operation_message = ""
	/// Whether the last operation succeeded
	var/last_operation_success = TRUE
	/// Console ambient sounds
	var/datum/console_ambience/console_ambience
	/// UI theme preference
	var/theme
	/// Bitflags for console upgrades (RTD, RPD, RLD, etc.)
	var/console_upgrades = NONE
	/// Internal RTD for tiling (created when upgrade installed)
	var/obj/item/construction/rtd/internal/internal_rtd
	/// Internal RPD for piping (created when upgrade installed)
	var/obj/item/pipe_dispenser/internal/internal_rpd
	/// Internal RLD for lighting (created when upgrade installed)
	var/obj/item/construction/rld/internal/internal_rld
	var/obj/item/airlock_painter/decal/ship/internal_painter
	/// Current T-ray scanner mode (off, t-ray, pipe, thermal)
	var/tray_mode = SHIP_TRAY_MODE_OFF
	/// Pipe connection images for T-ray pipe mode
	var/list/tray_connection_images = list()
	/// Rate limit on the "new sections have no air" warning - a room is many tiles,
	/// and the builder only needs telling once per build session, not per tile
	COOLDOWN_DECLARE(airless_warning_cooldown)
	/// Rate limit on the "the hull now buries the docking port" warning. Same reason: every
	/// tile of a new bow overhangs, and one line per tile buries the instruction it carries.
	/// The reseat *notice* is not rate limited - that one reports a real state change.
	COOLDOWN_DECLARE(port_overhang_warning_cooldown)

// ============================================
// Initialization
// ============================================

/obj/machinery/computer/camera_advanced/base_construction/ship/Initialize(mapload)
	// Create ship-specific internal RCD with silo link capability
	// Uses /ship subtype to bypass ore silo account checks
	var/obj/item/construction/rcd/internal/ship/ship_rcd = new(src)
	ship_rcd.ship_console = src
	internal_rcd = ship_rcd
	internal_rcd.construction_upgrades |= RCD_UPGRADE_SILO_LINK
	// Add the remote materials component to the RCD so it can link to a silo
	// The silo_mats needs to be added after setting the upgrade flag
	internal_rcd.silo_mats = internal_rcd.AddComponent(/datum/component/remote_materials, mapload, FALSE)
	update_build_speed()
	. = ..()
	// Console ambient sounds
	console_ambience = new(src, get_console_ambience_sounds())
	console_ambience.start()

/obj/machinery/computer/camera_advanced/base_construction/ship/Destroy()
	clear_construction_queue()
	clear_repair_journal(TRUE)
	for(var/obj/structure/ship_repair_drone/drone as anything in repair_drones.Copy())
		drone.unlink_console()
	QDEL_NULL(console_ambience)
	// The parent qdels the RCD but leaves the var pointing at it; null it here so the
	// two don't hold each other up.
	QDEL_NULL(internal_rcd)
	QDEL_NULL(internal_rtd)
	QDEL_NULL(internal_rpd)
	QDEL_NULL(internal_rld)
	QDEL_NULL(internal_painter)
	tray_connection_images.Cut()
	return ..()

// ============================================
// Build Speed Upgrades
// ============================================

/**
 * Multiplier applied to every construction delay the drone incurs.
 * 1 with no upgrade, 0.75 with fabrication servos, 0.5 with the mk2 package.
 */
/obj/machinery/computer/camera_advanced/base_construction/ship/proc/get_build_speed_mod()
	if(console_upgrades & SHIP_CONSTRUCTION_UPGRADE_SERVO_MK4)
		return SHIP_CONSTRUCTION_SERVO_MK4_SPEED_MOD
	if(console_upgrades & SHIP_CONSTRUCTION_UPGRADE_SERVO_MK3)
		return SHIP_CONSTRUCTION_SERVO_MK3_SPEED_MOD
	if(console_upgrades & SHIP_CONSTRUCTION_UPGRADE_SERVO_MK2)
		return SHIP_CONSTRUCTION_SERVO_MK2_SPEED_MOD
	if(console_upgrades & SHIP_CONSTRUCTION_UPGRADE_SERVO)
		return SHIP_CONSTRUCTION_SERVO_SPEED_MOD
	return 1

/**
 * Pushes the current speed multiplier onto the internal RCD's delay_mod.
 * That covers everything routed through rcd_create() (windows, girders, generic
 * deconstruction); the paths that charge and time themselves by hand instead -
 * build_wall(), build_floor(), build_camera(), and the airlock/camera deconstruct
 * actions - read get_build_speed_mod() directly. Applied once per path, never twice.
 */
/obj/machinery/computer/camera_advanced/base_construction/ship/proc/update_build_speed()
	if(!internal_rcd)
		return
	internal_rcd.delay_mod = initial(internal_rcd.delay_mod) * get_build_speed_mod()

/// Process T-ray scanner modes while viewing
/obj/machinery/computer/camera_advanced/base_construction/ship/process()
	. = ..()
	if(. == PROCESS_KILL)
		return

	// Process T-ray scanner if upgrade installed and mode is active
	if(!(console_upgrades & SHIP_CONSTRUCTION_UPGRADE_TRAY))
		return
	if(!current_user?.client || !eyeobj)
		return

	switch(tray_mode)
		if(SHIP_TRAY_MODE_TRAY)
			// The operator is the one who has to SEE it; the drone is where it happens.
			// Passing the operator as both swept the tiles around the console instead of
			// the tiles around the camera the operator is looking through (issue #224).
			t_ray_scan(current_user, 8, 3, eyeobj)
		if(SHIP_TRAY_MODE_PIPE)
			show_pipe_connections()
		if(SHIP_TRAY_MODE_THERMAL)
			show_thermal_overlay()

/// Show pipe connection overlays around the drone (like pipe connectable goggles)
/obj/machinery/computer/camera_advanced/base_construction/ship/proc/show_pipe_connections()
	if(!current_user?.client || !eyeobj)
		return

	var/range = 3

	// Clean up old images that are out of range. Iterate a copy (removing the current
	// entry mid-walk skips the next), and drop deleted pipes explicitly - the assoc
	// KEY is a hard ref, and get_dist() on a nullspaced pipe is not reliably > range,
	// so a pipe deleted while a console sat in pipe mode was pinned forever
	for(var/obj/machinery/atmospherics/pipe/smart/smart in tray_connection_images.Copy())
		if(QDELETED(smart) || get_dist(eyeobj, smart) > range)
			tray_connection_images -= smart

	// Show connection arrows on smart pipes
	for(var/obj/machinery/atmospherics/pipe/smart/smart in orange(range, eyeobj))
		if(!tray_connection_images[smart])
			tray_connection_images[smart] = list()
		for(var/direction in GLOB.cardinals)
			if(!(smart.get_init_directions() & direction))
				continue
			if(!tray_connection_images[smart][dir2text(direction)])
				var/image/arrow = new('icons/obj/pipes_n_cables/simple.dmi', get_turf(smart), "connection_overlay")
				arrow.dir = direction
				arrow.layer = smart.layer
				arrow.color = smart.pipe_color
				PIPING_LAYER_DOUBLE_SHIFT(arrow, smart.piping_layer)
				tray_connection_images[smart][dir2text(direction)] = arrow
			if(tray_connection_images.len)
				flick_overlay_global(tray_connection_images[smart][dir2text(direction)], list(current_user.client), 1.5 SECONDS)

/// Show thermal overlay around the drone (like atmos thermal goggles)
/obj/machinery/computer/camera_advanced/base_construction/ship/proc/show_thermal_overlay()
	if(!current_user?.client || !eyeobj)
		return
	// Use the global atmos_thermal proc which handles everything. Same split as the T-ray
	// sweep above: shown to the operator, centred on the drone.
	atmos_thermal(current_user, 5, 10, eyeobj)

/// Close all configuration UIs when exiting camera mode
/obj/machinery/computer/camera_advanced/base_construction/ship/remove_eye_control(mob/living/user)
	// Close any open configuration UIs for internal devices
	if(internal_rcd)
		SStgui.close_uis(internal_rcd)
	if(internal_rtd)
		SStgui.close_uis(internal_rtd)
	if(internal_painter)
		SStgui.close_uis(internal_painter)
	if(internal_rpd)
		SStgui.close_uis(internal_rpd)
	if(internal_rld)
		SStgui.close_uis(internal_rld)
	// Clear T-ray connection images
	tray_connection_images.Cut()
	return ..()

/// Show installed upgrades when examining
/obj/machinery/computer/camera_advanced/base_construction/ship/examine(mob/user)
	. = ..()
	if(!internal_rcd)
		return
	var/list/upgrades = list()
	if(internal_rcd.construction_upgrades & RCD_UPGRADE_SILO_LINK)
		upgrades += "silo link"
	if(internal_rcd.construction_upgrades & RCD_UPGRADE_FRAMES)
		upgrades += "frames"
	if(internal_rcd.construction_upgrades & RCD_UPGRADE_SIMPLE_CIRCUITS)
		upgrades += "simple circuits"
	if(internal_rcd.construction_upgrades & RCD_UPGRADE_FURNISHING)
		upgrades += "furnishing"
	if(internal_rcd.construction_upgrades & RCD_UPGRADE_ANTI_INTERRUPT)
		upgrades += "anti-interrupt"
	if(internal_rcd.construction_upgrades & RCD_UPGRADE_NO_FREQUENT_USE_COOLDOWN)
		upgrades += "enhanced cooling"
	if(length(upgrades))
		. += span_notice("Installed RCD upgrades: [english_list(upgrades)].")

	// Show console upgrades (RTD, RPD, RLD)
	var/list/console_upgrade_list = list()
	if(console_upgrades & SHIP_CONSTRUCTION_UPGRADE_RTD)
		console_upgrade_list += "rapid tiling"
	if(console_upgrades & SHIP_CONSTRUCTION_UPGRADE_RPD)
		console_upgrade_list += "rapid piping"
	if(console_upgrades & SHIP_CONSTRUCTION_UPGRADE_RLD)
		console_upgrade_list += "rapid lighting"
	if(console_upgrades & SHIP_CONSTRUCTION_UPGRADE_QUEUE)
		console_upgrade_list += "job queue"
	if(console_upgrades & SHIP_CONSTRUCTION_UPGRADE_AREA)
		console_upgrade_list += "area construction"
	if(console_upgrades & SHIP_CONSTRUCTION_UPGRADE_REPAIR)
		console_upgrade_list += "repair swarm"
	if(console_upgrades & SHIP_CONSTRUCTION_UPGRADE_DECAL)
		console_upgrade_list += "decal painter"
	if(console_upgrades & SHIP_CONSTRUCTION_UPGRADE_SERVO_MK4)
		console_upgrade_list += "instant fabrication"
	else if(console_upgrades & SHIP_CONSTRUCTION_UPGRADE_SERVO_MK3)
		console_upgrade_list += "fabrication servos mk3"
	else if(console_upgrades & SHIP_CONSTRUCTION_UPGRADE_SERVO_MK2)
		console_upgrade_list += "fabrication servos mk2"
	else if(console_upgrades & SHIP_CONSTRUCTION_UPGRADE_SERVO)
		console_upgrade_list += "fabrication servos"
	if(length(console_upgrade_list))
		. += span_notice("Installed console upgrades: [english_list(console_upgrade_list)].")

	var/speed_mod = get_build_speed_mod()
	if(speed_mod < 1)
		. += span_notice("Drone construction time is reduced by [round((1 - speed_mod) * 100)]%.")

	. += span_notice("You can insert RCD upgrade disks or ship construction upgrade disks to add more capabilities.")

/// Accept RCD upgrade disks - forward to internal RCD
/obj/machinery/computer/camera_advanced/base_construction/ship/item_interaction(mob/living/user, obj/item/tool, list/modifiers)
	// Handle RCD upgrades - also forward silo link to RTD and RLD if installed
	if(istype(tool, /obj/item/rcd_upgrade))
		if(!internal_rcd)
			balloon_alert(user, "no internal RCD!")
			return ITEM_INTERACT_FAILURE
		var/obj/item/rcd_upgrade/rcd_disk = tool
		// If it's a silo link upgrade, install it on RTD and RLD too
		if(rcd_disk.upgrade & RCD_UPGRADE_SILO_LINK)
			var/obj/machinery/ore_silo/linked_silo = get_linked_silo()
			// Forward to RTD
			if(internal_rtd)
				internal_rtd.construction_upgrades |= RCD_UPGRADE_SILO_LINK
				if(!internal_rtd.silo_mats)
					internal_rtd.silo_mats = internal_rtd.AddComponent(/datum/component/remote_materials, FALSE, FALSE)
				link_internal_device(internal_rtd, internal_rtd.silo_mats, linked_silo)
			// Forward to RLD
			if(internal_rld)
				internal_rld.construction_upgrades |= RCD_UPGRADE_SILO_LINK
				if(!internal_rld.silo_mats)
					internal_rld.silo_mats = internal_rld.AddComponent(/datum/component/remote_materials, FALSE, FALSE)
				link_internal_device(internal_rld, internal_rld.silo_mats, linked_silo)
		if(internal_rcd.install_upgrade(tool, user))
			balloon_alert(user, "upgrade installed")
		return ITEM_INTERACT_SUCCESS

	// Handle RPD upgrades - forward to internal RPD
	if(istype(tool, /obj/item/rpd_upgrade))
		if(!internal_rpd)
			balloon_alert(user, "no RPD installed!")
			return ITEM_INTERACT_FAILURE
		// Use the RPD's own upgrade handling
		return internal_rpd.interact_with_atom(tool, user)

	// Handle ship construction console upgrades (RTD, RPD, RLD)
	if(istype(tool, /obj/item/ship_construction_upgrade))
		var/obj/item/ship_construction_upgrade/upgrade_disk = tool
		// Bundled upgrades can add capabilities even when part of the disk is installed.
		if((upgrade_disk.upgrade_flags & console_upgrades) == upgrade_disk.upgrade_flags)
			balloon_alert(user, "already installed!")
			return ITEM_INTERACT_FAILURE

		// Install the upgrade
		console_upgrades |= upgrade_disk.upgrade_flags

		// Push any fabrication servo upgrade onto the internal RCD's delay_mod
		update_build_speed()
		if((upgrade_disk.upgrade_flags & SHIP_CONSTRUCTION_UPGRADE_REPAIR) && length(repair_drones))
			set_repair_tracking(TRUE)
			wake_repair_drones()

		// Inherit whatever silo the console is already linked to - the multitool linkup usually
		// happened rounds' worth of construction ago and nothing else will relink these devices.
		var/obj/machinery/ore_silo/linked_silo = get_linked_silo()

		// Create internal devices as needed
		if((upgrade_disk.upgrade_flags & SHIP_CONSTRUCTION_UPGRADE_DECAL) && !internal_painter)
			internal_painter = new(src)
			internal_painter.ship_console = src
		if((upgrade_disk.upgrade_flags & SHIP_CONSTRUCTION_UPGRADE_RTD) && !internal_rtd)
			internal_rtd = new(src)
			internal_rtd.ship_console = src
			// Enable silo link by default for RTD
			internal_rtd.silo_mats = internal_rtd.AddComponent(/datum/component/remote_materials, FALSE, FALSE)
			internal_rtd.silo_link = TRUE
			link_internal_device(internal_rtd, internal_rtd.silo_mats, linked_silo)

		if((upgrade_disk.upgrade_flags & SHIP_CONSTRUCTION_UPGRADE_RPD) && !internal_rpd)
			internal_rpd = new(src)
			internal_rpd.ship_console = src
			// Enable silo link by default for RPD
			internal_rpd.silo_mats = internal_rpd.AddComponent(/datum/component/remote_materials, FALSE, FALSE)
			internal_rpd.silo_link = TRUE
			link_internal_device(internal_rpd, internal_rpd.silo_mats, linked_silo)

		if((upgrade_disk.upgrade_flags & SHIP_CONSTRUCTION_UPGRADE_RLD) && !internal_rld)
			internal_rld = new(src)
			internal_rld.ship_console = src
			// Enable silo link by default for RLD
			internal_rld.construction_upgrades |= RCD_UPGRADE_SILO_LINK
			internal_rld.silo_mats = internal_rld.AddComponent(/datum/component/remote_materials, FALSE, FALSE)
			internal_rld.silo_link = TRUE
			link_internal_device(internal_rld, internal_rld.silo_mats, linked_silo)

		playsound(loc, 'sound/machines/click.ogg', 50, TRUE)
		balloon_alert(user, "upgrade installed")
		qdel(upgrade_disk)

		// Refresh actions to add new upgrade actions
		refresh_actions()
		return ITEM_INTERACT_SUCCESS

	return ..()

/// Point one internal device's material component at `silo`. A device is created when its upgrade
/// disk goes in, which is normally long after the console was multitooled to the silo, and its
/// fresh remote_materials component connects to nothing - so the device reports "no silo linked!"
/// forever even though the console next to it is drawing from the silo fine. Anything that creates
/// or relinks a device goes through here.
/obj/machinery/computer/camera_advanced/base_construction/ship/proc/link_internal_device(obj/item/device, datum/component/remote_materials/mats, obj/machinery/ore_silo/silo)
	if(isnull(device) || isnull(mats) || QDELETED(silo) || !same_service_site(src, silo))
		return FALSE
	if(mats.silo == silo)
		return TRUE
	mats.disconnect()
	silo.connect_receptacle(mats, device)
	return TRUE

/// The silo the console's RCD is currently drawing from, if any.
/obj/machinery/computer/camera_advanced/base_construction/ship/proc/get_linked_silo()
	return internal_rcd?.silo_mats?.silo

/// Link a buffered silo, then save this console for repair-drone linking.
/obj/machinery/computer/camera_advanced/base_construction/ship/multitool_act(mob/living/user, obj/item/multitool/M)
	. = ..()

	// Forward the multitool interaction to the internal RCD's remote_materials component
	if(!QDELETED(M.buffer) && istype(M.buffer, /obj/machinery/ore_silo))
		if(!internal_rcd?.silo_mats)
			balloon_alert(user, "silo link unavailable")
			return ITEM_INTERACT_SUCCESS
		var/obj/machinery/ore_silo/silo = M.buffer
		if(!same_service_site(src, silo))
			balloon_alert(user, "silo belongs to another site")
			return TRUE
		// Don't bail out when the RCD is already on this silo - relinking is how a player repairs
		// an RTD/RPD/RLD that was installed after the console was linked, and each call below is
		// a no-op for anything already connected.
		var/already_linked = internal_rcd.silo_mats.silo == silo

		link_internal_device(internal_rcd, internal_rcd.silo_mats, silo)
		internal_rcd.silo_link = TRUE  // Enable silo link mode

		// Also link the RTD to the silo if installed
		if(link_internal_device(internal_rtd, internal_rtd?.silo_mats, silo))
			internal_rtd.silo_link = TRUE

		// Also link the RPD to the silo if installed
		if(link_internal_device(internal_rpd, internal_rpd?.silo_mats, silo))
			internal_rpd.silo_link = TRUE

		// Also link the RLD to the silo if installed
		if(link_internal_device(internal_rld, internal_rld?.silo_mats, silo))
			internal_rld.silo_link = TRUE

		balloon_alert(user, already_linked ? "relinked" : "linked")
		to_chat(user, span_notice("You connect [src]'s tools to [silo]."))

	// Copying a reference grants no control. Drone linking checks crew access;
	// repair capability is unlocked on the console separately.
	M.set_buffer(src)
	balloon_alert(user, "console saved")
	return ITEM_INTERACT_SUCCESS

/obj/machinery/computer/camera_advanced/base_construction/ship/LateInitialize()
	. = ..()
	attempt_ship_connection()

/obj/machinery/computer/camera_advanced/base_construction/ship/connect_to_shuttle(mapload, obj/docking_port/mobile/voidcrew/port, obj/docking_port/stationary/dock)
	if(!istype(port))
		return
	current_ship = port.current_ship

/// Bind a freshly placed camera to this console's ship network. Done by the console rather
/// than relying on the camera's own ship detection so it works even on freshly claimed
/// turfs that no shuttle linkup will ever touch. Outpost consoles have no docking port, so
/// their cameras keep the upstream default network - which is what the default security
/// consoles and non-ship AIs there can actually see.
/obj/machinery/computer/camera_advanced/base_construction/ship/proc/setup_placed_camera(obj/machinery/camera/placed_camera)
	var/obj/docking_port/mobile/port = get_docking_port()
	if(port)
		placed_camera.network = list(voidcrew_ship_camera_net(port))
	// post_machine_initialize() already area-names cameras; this is just a backstop
	if(!placed_camera.c_tag)
		var/area/camera_area = get_area(placed_camera)
		placed_camera.c_tag = "[format_text(camera_area?.name || "Unknown")] Camera"

/obj/machinery/computer/camera_advanced/base_construction/ship/populate_actions_list()
	// Core RCD actions
	actions += new /datum/action/innate/construction/ship/configure_mode(src)
	actions += new /datum/action/innate/construction/ship/build(src)
	actions += new /datum/action/innate/construction/ship/deconstruct(src)
	actions += new /datum/action/innate/construction/ship/camera_build(src)
	// RTD actions (added if upgrade is installed)
	if(console_upgrades & SHIP_CONSTRUCTION_UPGRADE_DECAL)
		actions += new /datum/action/innate/construction/ship/decal_configure(src)
		actions += new /datum/action/innate/construction/ship/decal_paint(src)
	if(console_upgrades & SHIP_CONSTRUCTION_UPGRADE_RTD)
		actions += new /datum/action/innate/construction/ship/rtd_configure(src)
		actions += new /datum/action/innate/construction/ship/rtd_build(src)
		actions += new /datum/action/innate/construction/ship/rtd_deconstruct(src)
	// RPD actions (added if upgrade is installed)
	if(console_upgrades & SHIP_CONSTRUCTION_UPGRADE_RPD)
		actions += new /datum/action/innate/construction/ship/rpd_configure(src)
		actions += new /datum/action/innate/construction/ship/rpd_build(src)
		actions += new /datum/action/innate/construction/ship/rpd_destroy(src)
	// RLD actions (added if upgrade is installed)
	if(console_upgrades & SHIP_CONSTRUCTION_UPGRADE_RLD)
		actions += new /datum/action/innate/construction/ship/rld_color(src)
		actions += new /datum/action/innate/construction/ship/rld_build(src)
		actions += new /datum/action/innate/construction/ship/rld_remove(src)
	// T-ray scanner action (added if upgrade is installed)
	if(console_upgrades & SHIP_CONSTRUCTION_UPGRADE_TRAY)
		actions += new /datum/action/innate/construction/ship/tray_toggle(src)

/// Refreshes the actions list (called when upgrades are installed)
/obj/machinery/computer/camera_advanced/base_construction/ship/proc/refresh_actions()
	// Remove old construction actions from the current user if any (but not the off_action)
	if(current_user)
		for(var/datum/action/innate/construction/action in actions)
			action.Remove(current_user)

	// Preserve the off_action (camera exit button)
	var/datum/action/innate/camera_off/preserved_off_action
	for(var/datum/action/innate/camera_off/off_act in actions)
		preserved_off_action = off_act
		actions -= off_act
		break

	// Clear construction actions and repopulate
	QDEL_LIST(actions)
	populate_actions_list()

	// Re-add the off_action at the beginning
	if(preserved_off_action)
		actions.Insert(1, preserved_off_action)

	// Re-grant actions to current user if in construction mode
	if(current_user)
		GrantActions(current_user)

/// Override to show UI instead of immediately entering construction mode
/// We skip the camera_advanced parent's attack_hand which would enter camera mode
/obj/machinery/computer/camera_advanced/base_construction/ship/attack_hand(mob/user, list/modifiers)
	// Do basic machinery interaction check (skip camera_advanced parent)
	if(machine_stat & (NOPOWER|BROKEN))
		return
	// Open the UI instead of entering camera mode
	ui_interact(user)

/// Actually enter construction mode - called from UI button
/obj/machinery/computer/camera_advanced/base_construction/ship/proc/enter_construction_mode(mob/user)
	if(!can_use(user))
		return FALSE
	if(isnull(user.client))
		return FALSE
	if(!QDELETED(current_user))
		to_chat(user, span_warning("The console is already in use!"))
		return FALSE

	var/turf/spawn_spot = find_spawn_spot()
	if(!spawn_spot)
		to_chat(user, span_warning("Unable to find a valid location to deploy the construction drone."))
		return FALSE

	if(!CreateEye())
		return FALSE

	give_eye_control(user)
	eyeobj.setLoc(spawn_spot, TRUE)
	return TRUE

/obj/machinery/computer/camera_advanced/base_construction/ship/restock_materials()
	if(internal_rcd)
		internal_rcd.matter = internal_rcd.max_matter

/obj/machinery/computer/camera_advanced/base_construction/ship/find_spawn_spot()
	var/obj/docking_port/mobile/port = get_docking_port()
	if(!port)
		return get_turf(src)

	// Find a valid turf within the shuttle to spawn the drone
	for(var/area/shuttle_area as anything in port.shuttle_areas)
		for(var/turf/T in shuttle_area)
			if(!T.density && !T.is_blocked_turf())
				return T

	return get_turf(src)

/obj/machinery/computer/camera_advanced/base_construction/ship/CreateEye()
	// Reuse the existing drone if it's still around. The parent camera_advanced only ever
	// creates one eye per console; without this check, every entry into construction mode
	// orphaned the previous drone mob, which lingered in the world and showed up in the
	// ghost orbit menu.
	if(eyeobj && !QDELETED(eyeobj))
		return TRUE
	var/turf/spawn_spot = find_spawn_spot()
	if(!spawn_spot)
		return FALSE
	eyeobj = new /mob/eye/camera/remote/base_construction/ship(spawn_spot, src)
	return TRUE

/obj/machinery/computer/camera_advanced/base_construction/ship/can_use(mob/living/user)
	. = ..()
	if(!.)
		return FALSE

	// Must be connected to a ship
	if(!current_ship && !attempt_ship_connection())
		to_chat(user, span_warning("No ship connection established."))
		return FALSE

	// Must be a crew member
	if(!is_crew_member(user))
		to_chat(user, span_warning("Access denied. Crew authorization required."))
		return FALSE

	// Must be docked to use construction features
	if(!can_operate())
		to_chat(user, span_warning("[get_operate_error()]"))
		return FALSE

	return TRUE

// ============================================
// Ship Connection
// ============================================

/**
 * Attempts to connect this console to its containing ship
 */
/obj/machinery/computer/camera_advanced/base_construction/ship/proc/attempt_ship_connection()
	if(current_ship)
		return TRUE

	current_ship = get_ship_from_atom(src)
	return !!current_ship

/**
 * Checks if the given user is a member of this ship's crew
 */
/obj/machinery/computer/camera_advanced/base_construction/ship/proc/is_crew_member(mob/user)
	if(!ismob(user))
		return FALSE
	// Allow admin ghosts with AI interaction enabled
	if(isAdminGhostAI(user))
		return TRUE
	var/mob/living/living_user = user
	if(!istype(living_user) || !living_user.mind)
		return FALSE
	if(!current_ship || !current_ship.ship_team)
		return TRUE // No ship team set up, allow access
	return (living_user.mind in current_ship.ship_team.members)

/**
 * Checks if the console can perform operations (ship must be docked and not force-docked from interdiction)
 */
/obj/machinery/computer/camera_advanced/base_construction/ship/proc/can_operate()
	if(!current_ship)
		return FALSE
	if(current_ship.state != OVERMAP_SHIP_IDLE)
		return FALSE
	// Cannot operate while force-docked from interdiction
	if(!COOLDOWN_FINISHED(current_ship, interdiction_undock_lockout))
		return FALSE
	return TRUE

/**
 * Returns an error message explaining why can_operate() failed
 */
/obj/machinery/computer/camera_advanced/base_construction/ship/proc/get_operate_error()
	if(!current_ship)
		return "No ship connection established."
	if(current_ship.state != OVERMAP_SHIP_IDLE)
		return "Ship must be docked to use construction features."
	if(!COOLDOWN_FINISHED(current_ship, interdiction_undock_lockout))
		return "Construction disabled while docked with another ship."
	return "Unknown error."

/**
 * Gets the docking port for the current ship
 */
/obj/machinery/computer/camera_advanced/base_construction/ship/proc/get_docking_port()
	if(!current_ship)
		return null
	return current_ship.shuttle

// ============================================
// Location Validation
// ============================================

/**
 * Checks if a turf is within the shuttle's areas
 */
/obj/machinery/computer/camera_advanced/base_construction/ship/proc/is_in_shuttle_area(turf/T)
	var/obj/docking_port/mobile/port = get_docking_port()
	if(!port)
		return FALSE

	var/area/target_area = get_area(T)
	return (target_area in port.shuttle_areas)

/**
 * Checks if a turf is adjacent to the shuttle (cardinally)
 */
/obj/machinery/computer/camera_advanced/base_construction/ship/proc/is_adjacent_to_shuttle(turf/T)
	var/obj/docking_port/mobile/port = get_docking_port()
	if(!port)
		return FALSE
	// Kept as a method so the player outpost subtype can still override it (see
	// outpost_construction.dm); the rule itself lives in hull_survey.dm.
	return hull_claim_touches_port(T, port)

/**
 * Checks if a turf is a valid area type for expansion building
 * (space or planetoid, not ruin, not other shuttle)
 */
/obj/machinery/computer/camera_advanced/base_construction/ship/proc/is_valid_expansion_area(turf/T)
	return hull_claim_area_valid(T)

/**
 * Checks if the drone can move to a destination turf
 */
/obj/machinery/computer/camera_advanced/base_construction/ship/proc/can_move_to(turf/T)
	if(!T)
		return FALSE

	// Always allow movement within shuttle
	if(is_in_shuttle_area(T))
		return TRUE

	// Allow movement to adjacent tiles if they're valid expansion areas
	if(is_adjacent_to_shuttle(T) && is_valid_expansion_area(T))
		return TRUE

	return FALSE

/**
 * Checks if building is allowed at a specific turf
 */
/obj/machinery/computer/camera_advanced/base_construction/ship/proc/can_build_at(turf/T)
	if(!T)
		return FALSE

	var/obj/docking_port/mobile/port = get_docking_port()
	if(!port)
		return FALSE

	// Always allow building within shuttle
	if(is_in_shuttle_area(T))
		return TRUE

	// For adjacent tiles, additional checks apply
	if(!is_adjacent_to_shuttle(T))
		return FALSE

	// Must not be a dense turf (wall)
	if(T.density)
		return FALSE

	// Must be a valid expansion area
	if(!is_valid_expansion_area(T))
		return FALSE

	return TRUE

// ============================================
// Shuttle Expansion
// ============================================

/**
 * Expands the shuttle to include a new turf
 */
/obj/machinery/computer/camera_advanced/base_construction/ship/proc/expand_shuttle_to_turf(turf/T, mob/user)
	var/obj/docking_port/mobile/port = get_docking_port()
	if(!port)
		return FALSE

	// Don't expand if already in shuttle
	if(is_in_shuttle_area(T))
		return FALSE

	// Check if adding this turf would exceed max dimensions
	if(!check_expansion_dimensions(T, port, user))
		return FALSE

	// Use the existing expand_shuttle helper
	var/list/turfs = list()
	turfs[T] = TRUE
	expand_shuttle(user, port, turfs, list())
	// Every drone-built tile is credited as weightless without this - see
	// recount_hull_after_expansion() in hull_survey.dm for why.
	recount_hull_after_expansion(port)

	// New deck tiles start with no atmosphere - round 2 sent two engineers into a
	// fresh room without saying so. Once per minute, not per tile.
	if(user && COOLDOWN_FINISHED(src, airless_warning_cooldown))
		COOLDOWN_START(src, airless_warning_cooldown, 1 MINUTES)
		to_chat(user, span_warning("Note: newly built sections have no air. Extend atmospherics piping and a vent into the new room, or open it to the rest of the ship, before anyone works there unprotected."))

	// A tile built past the port's outer face buries the port. The survey path handles that
	// itself (validate_hull_claim() -> integrate_into_hull()); the drone did not, so a crew
	// building out with the console got no warning and no reseat, and found out when cargo
	// refused to deliver. See hull_reseat_after_growth(). (issue #130)
	check_port_after_build(T, user)

	return TRUE

/**
 * Reseats the docking port onto the new outer face, or tells the operator why it could not.
 *
 * `built` is the tile the drone just touched. The offset test is O(1) and skips the real scan
 * - which walks every turf of every hull area - for every build that is not out past the
 * port's plane, which is nearly all of them. Nothing behind that plane can raise the overhang,
 * and no plating or wall build can produce a door.
 *
 * `door_built` is the exception, and it is why the gate is not unconditional. Now that the
 * port may turn onto another face (hull_port_reseat_plan()), an airlock fitted anywhere on the
 * hull's skin can be the seat an existing overhang has been waiting for - including one
 * amidships on a beam, which is nowhere near the port's own plane. A door build is rare enough
 * to pay for the full scan. (issue #130)
 *
 * Never blocks anything: the caller has already built. Growing out is legal, leaving with the
 * port still buried is not, and that reckoning stays on undock (can_undock()).
 *
 * Gated on can_operate() like every other hull mutation the console performs. Entering
 * construction mode already required it, but a crew can undock with the drone still out, and
 * a reseat in transit would forceMove the transit berth onto a hull turf and then release the
 * assigned transit out from under a ship that is riding it.
 */
/obj/machinery/computer/camera_advanced/base_construction/ship/proc/check_port_after_build(turf/built, mob/user, door_built = FALSE)
	if(!can_operate())
		return
	var/obj/docking_port/mobile/port = get_docking_port()
	var/turf/port_turf = get_turf(port)
	if(!port_turf || !built || built.z != port_turf.z)
		return
	if(!door_built && hull_port_offset(built, port_turf, REVERSE_DIR(port.dir)) <= 0)
		return

	var/list/result = hull_reseat_after_growth(port)
	if(!result || !user)
		return

	if(result[1])
		// A real state change, and a rare one - always report it.
		to_chat(user, span_notice(result[2]))
		return
	if(!COOLDOWN_FINISHED(src, port_overhang_warning_cooldown))
		return
	COOLDOWN_START(src, port_overhang_warning_cooldown, 1 MINUTES)
	to_chat(user, span_warning(result[2]))

/**
 * Checks if adding a turf would exceed shuttle dimension limits
 * Returns TRUE if expansion is allowed, FALSE if it would exceed limits
 */
/obj/machinery/computer/camera_advanced/base_construction/ship/proc/check_expansion_dimensions(turf/new_turf, obj/docking_port/mobile/port)
	if(!port)
		return FALSE
	// The berth-fit rule lives in hull_survey.dm so the drone and the in-person survey
	// can't drift apart. Same result as the old inline pair of comparisons: "neither axis
	// over LONG, and not both over SHORT" is exactly "max <= LONG and min <= SHORT".
	var/list/extents = hull_claim_bounds(list(new_turf), port)
	return hull_dimensions_fit(extents[1], extents[2])

/**
 * Cleans up empty shuttle turfs after deconstruction
 */
/obj/machinery/computer/camera_advanced/base_construction/ship/proc/cleanup_deconstructed_turfs()
	var/obj/docking_port/mobile/port = get_docking_port()
	if(!port)
		return

	clear_empty_shuttle_turfs(port)

// ============================================
// Mobile Port Relocation
// ============================================

/**
 * Checks if a door is on the edge of the shuttle (has adjacent non-shuttle turf)
 */
/obj/machinery/computer/camera_advanced/base_construction/ship/proc/is_edge_airlock(obj/machinery/door/door, obj/docking_port/mobile/port)
	// Shared with the fan bookkeeping in hull_survey.dm, which has to make the same
	// edge-or-interior call about the tile a relocated port just left.
	return hull_turf_on_edge(get_turf(door), port)

/**
 * Checks that no part of the hull stands proud of the docking port.
 *
 * This is the whole docking face, not just the tile ahead of the port: hull_port_overhang()
 * in hull_survey.dm explains why any tile past the port's plane - at any lateral offset -
 * lands inside whatever the ship berths against. The old single-tile test passed happily
 * on an L-shaped extension bolted to one corner of the bow while the far corner was already
 * set up to drive through the other ship.
 */
/obj/machinery/computer/camera_advanced/base_construction/ship/proc/is_docking_port_on_edge()
	return get_port_overhang() <= 0

/// Tiles of hull standing out past the docking port. 0 is the healthy state.
/obj/machinery/computer/camera_advanced/base_construction/ship/proc/get_port_overhang()
	var/obj/docking_port/mobile/port = get_docking_port()
	if(!port)
		return 0
	var/list/overhang = hull_port_overhang(port, null)
	return overhang[1]

/**
 * Gets a list of all doors on the edge of the hull that the docking port could sit on.
 *
 * Airlocks and firelocks both count - see hull_port_door() for why, and for why blast doors
 * do not.
 */
/obj/machinery/computer/camera_advanced/base_construction/ship/proc/get_valid_port_doors()
	var/list/valid_doors = list()

	var/obj/docking_port/mobile/port = get_docking_port()
	if(!port)
		return valid_doors

	// Iterate through shuttle areas to find doors
	for(var/area/shuttle_area as anything in port.shuttle_areas)
		for(var/obj/machinery/door/door in shuttle_area)
			if(!is_hull_port_door(door))
				continue
			// Check if the door is on the edge (has adjacent non-shuttle turf)
			if(is_edge_airlock(door, port))
				valid_doors += door

	return valid_doors

/**
 * Every turf a tiny fan belongs on: the edge doors, plus the docking port's own tile.
 *
 * The port tile is included whatever door is standing on it. A hull that grew past its old
 * airlock has its port reseated onto whichever door the crew put on the new outer face (see
 * hull_port_reseat_target()), and that tile is exactly where the ship's air meets vacuum
 * when it berths - so it needs a fan even when the door is a firelock rather than an airlock.
 */
/obj/machinery/computer/camera_advanced/base_construction/ship/proc/get_fan_turfs()
	var/list/fan_turfs = list()

	for(var/obj/machinery/door/door as anything in get_valid_port_doors())
		var/turf/door_turf = get_turf(door)
		if(door_turf)
			fan_turfs |= door_turf

	var/obj/docking_port/mobile/port = get_docking_port()
	var/turf/port_turf = get_turf(port)
	if(port_turf && hull_port_door(port_turf))
		fan_turfs |= port_turf

	return fan_turfs

/**
 * Keeps fans on hull doors and blast doors, removes misplaced fans, and builds missing fans.
 * New fans cost the same iron they return when disassembled. Pay before removing anything
 * so an empty or unavailable silo cannot leave the ship unsealed.
 *
 * Refuses outright when there is nowhere to put a fan. The removal pass used to run first
 * unconditionally, so a hull with no edge door left - which is exactly the state an
 * expansion over the old airlock produces - was stripped of every fan it had and told the
 * operation succeeded.
 */
/obj/machinery/computer/camera_advanced/base_construction/ship/proc/reset_fans(mob/user)
	if(!can_operate())
		last_operation_message = "Cannot modify ship while in flight."
		last_operation_success = FALSE
		return FALSE

	var/obj/docking_port/mobile/port = get_docking_port()
	if(!port)
		last_operation_message = "No shuttle detected."
		last_operation_success = FALSE
		return FALSE

	var/list/fan_turfs = get_fan_turfs()
	if(!length(fan_turfs))
		last_operation_message = "No hull doors to fan. Fit an airlock or firelock on the outer \
			hull before resetting - clearing the fans without replacing them would leave the ship \
			venting through every opening."
		last_operation_success = FALSE
		return FALSE

	var/list/missing_fan_turfs = list()
	for(var/turf/fan_turf as anything in fan_turfs)
		if(!(locate(/obj/structure/fans/tiny) in fan_turf))
			missing_fan_turfs += fan_turf
	if(length(missing_fan_turfs))
		var/obj/structure/fans/tiny/fan_type = /obj/structure/fans/tiny
		var/iron_sheets = length(missing_fan_turfs) * initial(fan_type.buildstackamount)
		var/list/materials = list(/datum/material/iron = iron_sheets * SHEET_MATERIAL_AMOUNT)
		var/obj/item/construction/rcd/internal/ship/rcd = internal_rcd
		if(!rcd?.use_materials(materials, user))
			last_operation_message = "Fan reset requires [iron_sheets] iron sheets from an available linked silo ([initial(fan_type.buildstackamount)] per missing fan)."
			last_operation_success = FALSE
			return FALSE

	var/fans_removed = 0
	var/fans_added = 0
	var/fans_preserved = 0

	// Keep fans already in the right place so resetting does not charge for them again.
	for(var/area/shuttle_area as anything in port.shuttle_areas)
		for(var/obj/structure/fans/tiny/fan in shuttle_area)
			var/turf/fan_turf = get_turf(fan)
			if(fan_turf in fan_turfs)
				fans_preserved++
				continue
			// Preserve fans on blast doors (poddoors)
			var/on_blast_door = FALSE
			for(var/obj/machinery/door/poddoor/door in fan_turf)
				on_blast_door = TRUE
				break
			if(on_blast_door)
				fans_preserved++
				continue
			qdel(fan)
			fans_removed++

	for(var/turf/fan_turf as anything in missing_fan_turfs)
		new /obj/structure/fans/tiny(fan_turf)
		fans_added++

	var/preserved_msg = fans_preserved ? ", [fans_preserved] preserved" : ""
	last_operation_message = "Fans reset: [fans_removed] removed, [fans_added] added to hull doors[preserved_msg]."
	last_operation_success = TRUE
	return TRUE

/**
 * Gets information about the current docking port location
 */
/obj/machinery/computer/camera_advanced/base_construction/ship/proc/get_current_docking_port_info()
	var/obj/docking_port/mobile/port = get_docking_port()
	if(!port)
		return null

	var/turf/port_turf = get_turf(port)

	return list(
		"x" = port_turf ? port_turf.x : 0,
		"y" = port_turf ? port_turf.y : 0,
		"dir" = dir2text(port.dir),
		"port_direction" = dir2text(port.port_direction)
	)

/**
 * Relocates the docking port to a new hull door
 */
/obj/machinery/computer/camera_advanced/base_construction/ship/proc/relocate_docking_port(obj/machinery/door/new_door)
	if(!can_operate())
		last_operation_message = "Cannot modify ship while in flight."
		last_operation_success = FALSE
		return FALSE

	var/obj/docking_port/mobile/port = get_docking_port()
	if(!port)
		last_operation_message = "No ship connection."
		last_operation_success = FALSE
		return FALSE

	if(!is_hull_port_door(new_door))
		last_operation_message = "The docking port can only sit on an airlock or a firelock."
		last_operation_success = FALSE
		return FALSE

	// Validate the door is in our shuttle
	var/area/door_area = get_area(new_door)
	if(!(door_area in port.shuttle_areas))
		last_operation_message = "That door is not part of this ship."
		last_operation_success = FALSE
		return FALSE

	// Validate it's an edge door
	if(!is_edge_airlock(new_door, port))
		last_operation_message = "The door must be on the edge of the ship."
		last_operation_success = FALSE
		return FALSE

	// Calculate new direction based on adjacent tiles
	var/turf/door_turf = get_turf(new_door)
	var/outside_dir

	for(var/check_dir in GLOB.cardinals)
		var/turf/adjacent = get_step(door_turf, check_dir)
		var/area/adj_area = get_area(adjacent)
		if(!(adj_area in port.shuttle_areas))
			outside_dir = check_dir
			break

	if(!outside_dir)
		last_operation_message = "Could not determine docking direction."
		last_operation_success = FALSE
		return FALSE

	// The new dir (points INTO the ship, away from the docking entrance) and the ship-relative
	// port_direction that has to keep step with it. Shared with the survey and drone reseats
	// so there is exactly one copy of the rotation arithmetic - see hull_port_facing().
	var/list/new_facing = hull_port_facing(port, outside_dir)

	// Moves the port, drags the stationary dock we are sitting on with it, recalculates
	// dimensions and drops the stale transit berth. Shared with the survey's reseat.
	hull_reseat_port(port, door_turf, new_facing[1], new_facing[2])

	var/overhang = get_port_overhang()
	if(overhang > 0)
		last_operation_message = "Docking port relocated, but [overhang] metre\s of hull still \
			stands out past it. Move the port to a door on the outermost plating, or the ship \
			will drive that section through anything it berths against."
		last_operation_success = FALSE
		return TRUE

	last_operation_message = "Docking port relocated successfully. Changes will take effect on next dock."
	last_operation_success = TRUE
	return TRUE

// ============================================
// TGUI Integration
// ============================================

/obj/machinery/computer/camera_advanced/base_construction/ship/ui_interact(mob/user, datum/tgui/ui)
	if(!current_ship && !attempt_ship_connection())
		to_chat(user, span_warning("No ship connection."))
		return FALSE

	ui = SStgui.try_update_ui(user, src, ui)
	if(!ui)
		ui = new(user, src, "ShipConstructionConsole", name)
		ui.open()
		ui.set_autoupdate(TRUE)

/obj/machinery/computer/camera_advanced/base_construction/ship/ui_data(mob/user)
	var/list/data = list()

	data["canOperate"] = can_operate()
	data["shipState"] = current_ship ? current_ship.state : null
	data["isNotCrew"] = !is_crew_member(user)
	data["lastMessage"] = last_operation_message
	data["lastSuccess"] = last_operation_success

	// RCD info - show silo materials when using silo link, otherwise internal matter
	if(internal_rcd)
		if(internal_rcd.silo_link && internal_rcd.silo_mats?.mat_container)
			// Show silo iron as RCD-equivalent units
			data["rcdMatter"] = internal_rcd.get_silo_iron()
			data["rcdMaxMatter"] = 0  // Silo has no max, hide the max display
			data["usingSilo"] = TRUE
		else
			data["rcdMatter"] = internal_rcd.matter
			data["rcdMaxMatter"] = internal_rcd.max_matter
			data["usingSilo"] = FALSE
	else
		data["rcdMatter"] = 0
		data["rcdMaxMatter"] = 0
		data["usingSilo"] = FALSE

	// Ship dimensions
	var/obj/docking_port/mobile/port = get_docking_port()
	if(port)
		var/list/bounds = port.return_coords()
		var/x0 = min(bounds[1], bounds[3])
		var/y0 = min(bounds[2], bounds[4])
		var/x1 = max(bounds[1], bounds[3])
		var/y1 = max(bounds[2], bounds[4])
		data["shipWidth"] = x1 - x0 + 1
		data["shipHeight"] = y1 - y0 + 1
	else
		data["shipWidth"] = 0
		data["shipHeight"] = 0
	data["maxDimensionLong"] = RESERVE_DOCK_MAX_SIZE_LONG
	data["maxDimensionShort"] = RESERVE_DOCK_MAX_SIZE_SHORT

	// Ship mass info
	if(current_ship)
		data["shipMass"] = current_ship.mass || 0
		data["maxIntegrity"] = current_ship.max_integrity || 0
		data["integrity"] = current_ship.get_integrity_percent()
		data["overhealth"] = current_ship.get_overhealth_percent()
	else
		data["shipMass"] = 0
		data["maxIntegrity"] = 0
		data["integrity"] = 100
		data["overhealth"] = 0

	// Current docking port info. The overhang scan walks every hull turf, and this runs on
	// autoupdate, so measure once and derive the rest from it.
	var/overhang = get_port_overhang()
	data["currentPort"] = get_current_docking_port_info()
	data["portOverhang"] = overhang
	data["dockingPortOnEdge"] = (overhang <= 0)

	// Get the current port turf for comparison
	var/turf/current_port_turf = get_turf(port)
	var/outward_dir = port ? REVERSE_DIR(port.dir) : 0

	// Available hull doors the port can be moved to
	var/list/door_data = list()
	for(var/obj/machinery/door/door as anything in get_valid_port_doors())
		var/turf/T = get_turf(door)
		var/is_current = (T == current_port_turf)
		var/area/door_area = get_area(door)
		// A door clears the overhang only if it stands on the outermost plane - moving the
		// port anywhere short of that leaves everything beyond it still sticking out.
		var/clears_overhang = overhang > 0 && T && hull_port_offset(T, current_port_turf, outward_dir) == overhang
		door_data += list(list(
			"name" = door.name,
			"ref" = REF(door),
			"x" = T ? T.x : 0,
			"y" = T ? T.y : 0,
			"isCurrent" = is_current,
			"clearsOverhang" = clears_overhang,
			"areaName" = door_area ? door_area.name : "Unknown"
		))
	data["portDoors"] = door_data

	// Check if user is in construction mode (controlling drone)
	data["isInConstructionMode"] = (eyeobj && user.remote_control == eyeobj)

	// Theme preference
	data["theme"] = theme
	data += construction_controls_data()
	data += repair_controls_data()

	return data

/obj/machinery/computer/camera_advanced/base_construction/ship/ui_static_data(mob/user)
	var/list/data = list()

	data["shipName"] = current_ship ? current_ship.display_name : null

	return data

/obj/machinery/computer/camera_advanced/base_construction/ship/ui_act(action, list/params, datum/tgui/ui, datum/ui_state/state)
	. = ..()
	if(.)
		return

	// Server-side crew check
	if(!is_crew_member(usr))
		say("ERROR: Access denied. Crew authorization required.")
		return
	if(construction_control_act(action, params, usr) || repair_control_act(action, params, usr))
		return TRUE

	switch(action)
		if("relocate_port")
			var/obj/machinery/door/target = locate(params["door_ref"])
			if(!target)
				last_operation_message = "Invalid door selected."
				last_operation_success = FALSE
				return TRUE
			relocate_docking_port(target)
			return TRUE
		if("clear_message")
			last_operation_message = ""
			return TRUE
		if("enter_construction_mode")
			if(!can_operate())
				to_chat(usr, span_warning("[get_operate_error()]"))
				return TRUE
			enter_construction_mode(usr)
			return TRUE
		if("reset_fans")
			reset_fans(usr)
			return TRUE
		if("setTheme")
			theme = params["theme"]
			return TRUE

	return FALSE
