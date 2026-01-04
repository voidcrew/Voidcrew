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
 */

/// How much material per RCD unit when using silo link (1/4 sheet per unit)
#define SHIP_RCD_SILO_USE_AMOUNT (SHEET_MATERIAL_AMOUNT / 4)

// ============================================
// Ship Internal RCD - bypasses account checks
// ============================================

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

// ============================================
// Ship RCD TGUI Interface
// ============================================

/// Always allow UI interaction for remote construction
/obj/item/construction/rcd/internal/ship/ui_state(mob/user)
	return GLOB.always_state

/// Override ui_interact to use our custom ShipRCD interface (extends standard RCD UI)
/obj/item/construction/rcd/internal/ship/ui_interact(mob/user, datum/tgui/ui)
	ui = SStgui.try_update_ui(user, src, ui)
	if(!ui)
		ui = new(user, src, "ShipRCD", name)
		ui.open()

/obj/item/construction/rcd/internal/ship/ui_data(mob/user)
	// Get all standard RCD data from parent
	var/list/data = ..()

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
	silo_mats.use_materials(materials, action = "build", name = "ship construction", user_data = user_data)
	return TRUE

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
	if(!check_wall_materials(user))
		return FALSE

	// Show construction effect
	var/obj/effect/constructing_effect/rcd_effect = new(target, 2 SECONDS, RCD_TURF)

	// Delay for building
	if(!build_delay(user, 2 SECONDS, target))
		qdel(rcd_effect)
		return FALSE

	// Double check materials after delay
	if(!use_wall_materials(user))
		qdel(rcd_effect)
		return FALSE

	// Build the wall
	var/wall_path = get_selected_wall_path()
	target.ChangeTurf(wall_path, flags = CHANGETURF_INHERIT_AIR)
	rcd_effect.end_animation()
	return TRUE

/// Build a floor of the selected type at the target turf
/obj/item/construction/rcd/internal/ship/proc/build_floor(turf/target, mob/user)
	if(!check_floor_materials(user))
		return FALSE

	// Show construction effect
	var/obj/effect/constructing_effect/rcd_effect = new(target, 1 SECONDS, RCD_TURF)

	// Delay for building
	if(!build_delay(user, 1 SECONDS, target))
		qdel(rcd_effect)
		return FALSE

	// Double check materials after delay
	if(!use_floor_materials(user))
		qdel(rcd_effect)
		return FALSE

	// Build the floor
	var/floor_path = get_selected_floor_path()
	target.ChangeTurf(floor_path, flags = CHANGETURF_INHERIT_AIR)
	rcd_effect.end_animation()
	return TRUE

// ============================================
// Ship Internal RTD - bypasses proximity checks
// ============================================

// RTD silo material costs
#define SHIP_RTD_TILE_IRON 100

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

// RPD silo material costs
#define SHIP_RPD_PIPE_IRON 50

/// Ship-specific internal RPD that allows remote UI interaction and uses silo materials
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

/// Check if we have enough iron in the silo for a pipe
/obj/item/pipe_dispenser/internal/proc/check_pipe_materials(mob/user)
	if(!silo_mats?.mat_container || !silo_link)
		if(user)
			drone_alert(user, "no silo linked!")
		return FALSE

	if(!silo_mats.mat_container.has_enough_of_material(/datum/material/iron, SHIP_RPD_PIPE_IRON))
		if(user)
			drone_alert(user, "not enough iron!")
		return FALSE

	return TRUE

/// Use iron from the silo for a pipe
/obj/item/pipe_dispenser/internal/proc/use_pipe_materials(mob/user)
	if(!check_pipe_materials(user))
		return FALSE

	var/list/materials = list(/datum/material/iron = SHIP_RPD_PIPE_IRON)

	// Use SILICON_OVERRIDE to bypass account check
	var/list/user_data = ID_DATA(user)
	user_data[SILICON_OVERRIDE] = SILICON_OVERRIDE
	silo_mats.use_materials(materials, action = "build", name = "ship piping", user_data = user_data)
	return TRUE

// ============================================
// Ship Internal RLD - bypasses proximity checks
// ============================================

// RLD silo material costs
#define SHIP_RLD_WALL_LIGHT_IRON 25
#define SHIP_RLD_WALL_LIGHT_GLASS 50
#define SHIP_RLD_FLOOR_LIGHT_IRON 50
#define SHIP_RLD_FLOOR_LIGHT_GLASS 25
#define SHIP_RLD_GLOW_STICK_IRON 10
#define SHIP_RLD_GLOW_STICK_GLASS 25

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
	/// Current T-ray scanner mode (off, t-ray, pipe, thermal)
	var/tray_mode = SHIP_TRAY_MODE_OFF
	/// Pipe connection images for T-ray pipe mode
	var/list/tray_connection_images = list()

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
	. = ..()
	// Console ambient sounds
	console_ambience = new(src, get_console_ambience_sounds())
	console_ambience.start()

/obj/machinery/computer/camera_advanced/base_construction/ship/Destroy()
	QDEL_NULL(console_ambience)
	QDEL_NULL(internal_rtd)
	QDEL_NULL(internal_rpd)
	QDEL_NULL(internal_rld)
	tray_connection_images.Cut()
	return ..()

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
			t_ray_scan(current_user, 8, 3)
		if(SHIP_TRAY_MODE_PIPE)
			show_pipe_connections()
		if(SHIP_TRAY_MODE_THERMAL)
			show_thermal_overlay()

/// Show pipe connection overlays around the drone (like pipe connectable goggles)
/obj/machinery/computer/camera_advanced/base_construction/ship/proc/show_pipe_connections()
	if(!current_user?.client || !eyeobj)
		return

	var/range = 3

	// Clean up old images that are out of range
	for(var/obj/machinery/atmospherics/pipe/smart/smart in tray_connection_images)
		if(get_dist(eyeobj, smart) > range)
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
	// Use the global atmos_thermal proc which handles everything
	atmos_thermal(current_user, 5, 10)

/// Close all configuration UIs when exiting camera mode
/obj/machinery/computer/camera_advanced/base_construction/ship/remove_eye_control(mob/living/user)
	// Close any open configuration UIs for internal devices
	if(internal_rcd)
		SStgui.close_uis(internal_rcd)
	if(internal_rtd)
		SStgui.close_uis(internal_rtd)
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
	if(length(console_upgrade_list))
		. += span_notice("Installed console upgrades: [english_list(console_upgrade_list)].")

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
			// Forward to RTD
			if(internal_rtd)
				internal_rtd.construction_upgrades |= RCD_UPGRADE_SILO_LINK
				if(!internal_rtd.silo_mats)
					internal_rtd.silo_mats = internal_rtd.AddComponent(/datum/component/remote_materials, FALSE, FALSE)
			// Forward to RLD
			if(internal_rld)
				internal_rld.construction_upgrades |= RCD_UPGRADE_SILO_LINK
				if(!internal_rld.silo_mats)
					internal_rld.silo_mats = internal_rld.AddComponent(/datum/component/remote_materials, FALSE, FALSE)
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
		if(upgrade_disk.upgrade_flags & console_upgrades)
			balloon_alert(user, "already installed!")
			return ITEM_INTERACT_FAILURE

		// Install the upgrade
		console_upgrades |= upgrade_disk.upgrade_flags

		// Create internal devices as needed
		if((upgrade_disk.upgrade_flags & SHIP_CONSTRUCTION_UPGRADE_RTD) && !internal_rtd)
			internal_rtd = new(src)
			internal_rtd.ship_console = src
			// Enable silo link by default for RTD
			internal_rtd.silo_mats = internal_rtd.AddComponent(/datum/component/remote_materials, FALSE, FALSE)
			internal_rtd.silo_link = TRUE

		if((upgrade_disk.upgrade_flags & SHIP_CONSTRUCTION_UPGRADE_RPD) && !internal_rpd)
			internal_rpd = new(src)
			internal_rpd.ship_console = src
			// Enable silo link by default for RPD
			internal_rpd.silo_mats = internal_rpd.AddComponent(/datum/component/remote_materials, FALSE, FALSE)
			internal_rpd.silo_link = TRUE

		if((upgrade_disk.upgrade_flags & SHIP_CONSTRUCTION_UPGRADE_RLD) && !internal_rld)
			internal_rld = new(src)
			internal_rld.ship_console = src
			// Enable silo link by default for RLD
			internal_rld.construction_upgrades |= RCD_UPGRADE_SILO_LINK
			internal_rld.silo_mats = internal_rld.AddComponent(/datum/component/remote_materials, FALSE, FALSE)
			internal_rld.silo_link = TRUE

		playsound(loc, 'sound/machines/click.ogg', 50, TRUE)
		balloon_alert(user, "upgrade installed")
		qdel(upgrade_disk)

		// Refresh actions to add new upgrade actions
		refresh_actions()
		return ITEM_INTERACT_SUCCESS

	return ..()

/// Forward multitool interactions to the internal RCD for silo linking
/obj/machinery/computer/camera_advanced/base_construction/ship/multitool_act(mob/living/user, obj/item/multitool/M)
	. = ..()
	if(!internal_rcd?.silo_mats)
		return .

	// Forward the multitool interaction to the internal RCD's remote_materials component
	if(!QDELETED(M.buffer) && istype(M.buffer, /obj/machinery/ore_silo))
		var/obj/machinery/ore_silo/silo = M.buffer
		if(internal_rcd.silo_mats.silo == silo)
			balloon_alert(user, "already linked")
			to_chat(user, span_warning("[src]'s RCD is already connected to [silo]."))
			return ITEM_INTERACT_SUCCESS

		internal_rcd.silo_mats.disconnect()
		silo.connect_receptacle(internal_rcd.silo_mats, internal_rcd)
		internal_rcd.silo_link = TRUE  // Enable silo link mode

		// Also link the RTD to the silo if installed
		if(internal_rtd?.silo_mats)
			internal_rtd.silo_mats.disconnect()
			silo.connect_receptacle(internal_rtd.silo_mats, internal_rtd)
			internal_rtd.silo_link = TRUE

		// Also link the RPD to the silo if installed
		if(internal_rpd?.silo_mats)
			internal_rpd.silo_mats.disconnect()
			silo.connect_receptacle(internal_rpd.silo_mats, internal_rpd)
			internal_rpd.silo_link = TRUE

		// Also link the RLD to the silo if installed
		if(internal_rld?.silo_mats)
			internal_rld.silo_mats.disconnect()
			silo.connect_receptacle(internal_rld.silo_mats, internal_rld)
			internal_rld.silo_link = TRUE

		balloon_alert(user, "linked")
		to_chat(user, span_notice("You connect [src]'s RCD to [silo]."))
		return ITEM_INTERACT_SUCCESS

	return .

/obj/machinery/computer/camera_advanced/base_construction/ship/LateInitialize()
	. = ..()
	attempt_ship_connection()

/obj/machinery/computer/camera_advanced/base_construction/ship/connect_to_shuttle(mapload, obj/docking_port/mobile/voidcrew/port, obj/docking_port/stationary/dock)
	if(!istype(port))
		return
	current_ship = port.current_ship

/obj/machinery/computer/camera_advanced/base_construction/ship/populate_actions_list()
	// Core RCD actions
	actions += new /datum/action/innate/construction/ship/configure_mode(src)
	actions += new /datum/action/innate/construction/ship/build(src)
	actions += new /datum/action/innate/construction/ship/deconstruct(src)
	// RTD actions (added if upgrade is installed)
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

	for(var/check_dir in GLOB.cardinals)
		var/turf/adjacent = get_step(T, check_dir)
		if(get_area(adjacent) in port.shuttle_areas)
			return TRUE

	return FALSE

/**
 * Checks if a turf is a valid area type for expansion building
 * (space or planetoid, not ruin, not other shuttle)
 */
/obj/machinery/computer/camera_advanced/base_construction/ship/proc/is_valid_expansion_area(turf/T)
	var/area/target_area = get_area(T)

	// Must be space or planetoid area
	if(!istype(target_area, /area/space) && !istype(target_area, /area/overmap_encounter/planetoid))
		return FALSE

	// NOT a ruin area
	if(istype(target_area, /area/ruin))
		return FALSE

	// NOT another shuttle
	if(isshuttleturf(T))
		return FALSE

	return TRUE

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

	return TRUE

/**
 * Checks if adding a turf would exceed shuttle dimension limits
 * Returns TRUE if expansion is allowed, FALSE if it would exceed limits
 */
/obj/machinery/computer/camera_advanced/base_construction/ship/proc/check_expansion_dimensions(turf/new_turf, obj/docking_port/mobile/port)
	if(!port)
		return FALSE

	// Get current shuttle bounds (normalize since return_coords order depends on direction)
	var/list/bounds = port.return_coords()
	var/x0 = min(bounds[1], bounds[3])
	var/y0 = min(bounds[2], bounds[4])
	var/x1 = max(bounds[1], bounds[3])
	var/y1 = max(bounds[2], bounds[4])

	// Calculate new bounds if we add this turf
	var/new_x0 = min(x0, new_turf.x)
	var/new_y0 = min(y0, new_turf.y)
	var/new_x1 = max(x1, new_turf.x)
	var/new_y1 = max(y1, new_turf.y)

	// Calculate new dimensions
	var/new_width = new_x1 - new_x0 + 1
	var/new_height = new_y1 - new_y0 + 1

	// Check against voidcrew dimension limits
	// Neither dimension can exceed RESERVE_DOCK_MAX_SIZE_LONG (56)
	if(new_width > RESERVE_DOCK_MAX_SIZE_LONG || new_height > RESERVE_DOCK_MAX_SIZE_LONG)
		return FALSE

	// Only one dimension can exceed RESERVE_DOCK_MAX_SIZE_SHORT (40)
	if(new_width > RESERVE_DOCK_MAX_SIZE_SHORT && new_height > RESERVE_DOCK_MAX_SIZE_SHORT)
		return FALSE

	return TRUE

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
 * Checks if an airlock is on the edge of the shuttle (has adjacent non-shuttle turf)
 */
/obj/machinery/computer/camera_advanced/base_construction/ship/proc/is_edge_airlock(obj/machinery/door/airlock/airlock, obj/docking_port/mobile/port)
	var/turf/airlock_turf = get_turf(airlock)
	if(!airlock_turf)
		return FALSE

	// Check cardinal directions for non-shuttle areas
	for(var/check_dir in GLOB.cardinals)
		var/turf/adjacent = get_step(airlock_turf, check_dir)
		if(!adjacent)
			continue
		var/area/adj_area = get_area(adjacent)
		if(!(adj_area in port.shuttle_areas))
			return TRUE // This airlock is on the edge

	return FALSE

/**
 * Checks if the docking port is on the edge of the shuttle
 * The docking port must have non-shuttle area in the direction it faces for docking to work
 */
/obj/machinery/computer/camera_advanced/base_construction/ship/proc/is_docking_port_on_edge()
	var/obj/docking_port/mobile/port = get_docking_port()
	if(!port)
		return FALSE

	var/turf/port_turf = get_turf(port)
	if(!port_turf)
		return FALSE

	// The docking port's dir points INTO the ship
	// So the docking entrance is in the REVERSE direction
	var/docking_dir = REVERSE_DIR(port.dir)

	// Check if the tile in the docking direction is outside the shuttle
	var/turf/dock_facing_turf = get_step(port_turf, docking_dir)
	if(!dock_facing_turf)
		return TRUE // Edge of map, technically on edge

	var/area/facing_area = get_area(dock_facing_turf)
	return !(facing_area in port.shuttle_areas)

/**
 * Gets a list of all valid edge airlocks on this ship
 */
/obj/machinery/computer/camera_advanced/base_construction/ship/proc/get_valid_airlocks()
	var/list/valid_airlocks = list()

	var/obj/docking_port/mobile/port = get_docking_port()
	if(!port)
		return valid_airlocks

	// Iterate through shuttle areas to find airlocks
	for(var/area/shuttle_area as anything in port.shuttle_areas)
		for(var/obj/machinery/door/airlock/airlock in shuttle_area)
			// Check if airlock is on the edge (has adjacent non-shuttle turf)
			if(is_edge_airlock(airlock, port))
				valid_airlocks += airlock

	return valid_airlocks

/**
 * Resets tiny fans - removes all existing fans and adds new ones to all edge airlocks
 */
/obj/machinery/computer/camera_advanced/base_construction/ship/proc/reset_fans()
	if(!can_operate())
		last_operation_message = "Cannot modify ship while in flight."
		last_operation_success = FALSE
		return FALSE

	var/obj/docking_port/mobile/port = get_docking_port()
	if(!port)
		last_operation_message = "No shuttle detected."
		last_operation_success = FALSE
		return FALSE

	var/fans_removed = 0
	var/fans_added = 0
	var/fans_preserved = 0

	// Remove all existing tiny fans in shuttle areas (except those on blast doors)
	for(var/area/shuttle_area as anything in port.shuttle_areas)
		for(var/obj/structure/fans/tiny/fan in shuttle_area)
			var/turf/fan_turf = get_turf(fan)
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

	// Add new tiny fans to all edge airlocks
	for(var/obj/machinery/door/airlock/airlock in get_valid_airlocks())
		var/turf/airlock_turf = get_turf(airlock)
		if(!airlock_turf)
			continue
		// Check if there's already a fan here (shouldn't be after removal, but safety check)
		var/has_fan = FALSE
		for(var/obj/structure/fans/tiny/existing in airlock_turf)
			has_fan = TRUE
			break
		if(!has_fan)
			new /obj/structure/fans/tiny(airlock_turf)
			fans_added++

	var/preserved_msg = fans_preserved ? ", [fans_preserved] preserved on blast doors" : ""
	last_operation_message = "Fans reset: [fans_removed] removed, [fans_added] added to edge airlocks[preserved_msg]."
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
 * Relocates the docking port to a new airlock
 */
/obj/machinery/computer/camera_advanced/base_construction/ship/proc/relocate_docking_port(obj/machinery/door/airlock/new_airlock)
	if(!can_operate())
		last_operation_message = "Cannot modify ship while in flight."
		last_operation_success = FALSE
		return FALSE

	var/obj/docking_port/mobile/port = get_docking_port()
	if(!port)
		last_operation_message = "No ship connection."
		last_operation_success = FALSE
		return FALSE

	// Validate the airlock is in our shuttle
	var/area/airlock_area = get_area(new_airlock)
	if(!(airlock_area in port.shuttle_areas))
		last_operation_message = "Airlock is not part of this ship."
		last_operation_success = FALSE
		return FALSE

	// Validate it's an edge airlock
	if(!is_edge_airlock(new_airlock, port))
		last_operation_message = "Airlock must be on the edge of the ship."
		last_operation_success = FALSE
		return FALSE

	// Calculate new direction based on adjacent tiles
	var/turf/airlock_turf = get_turf(new_airlock)
	var/outside_dir

	for(var/check_dir in GLOB.cardinals)
		var/turf/adjacent = get_step(airlock_turf, check_dir)
		var/area/adj_area = get_area(adjacent)
		if(!(adj_area in port.shuttle_areas))
			outside_dir = check_dir
			break

	if(!outside_dir)
		last_operation_message = "Could not determine docking direction."
		last_operation_success = FALSE
		return FALSE

	// Calculate new dir (points INTO the ship, away from docking entrance)
	var/new_dir = REVERSE_DIR(outside_dir)

	// Calculate new port_direction (ship-relative direction)
	var/world_port_facing = REVERSE_DIR(new_dir)
	var/angle_diff = SIMPLIFY_DEGREES(dir2angle(world_port_facing) - dir2angle(port.preferred_direction))
	var/new_port_direction = angle2dir(angle_diff)

	// Move the port and update variables
	port.forceMove(airlock_turf)
	port.dir = new_dir
	port.port_direction = new_port_direction

	// Recalculate dimensions
	port.calculate_docking_port_information()

	// Clear cached transit dock so it regenerates with new orientation
	if(!QDELETED(port.assigned_transit))
		qdel(port.assigned_transit, force = TRUE)
		port.assigned_transit = null

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

	// Current docking port info
	data["currentPort"] = get_current_docking_port_info()
	data["dockingPortOnEdge"] = is_docking_port_on_edge()

	// Get the current port turf for comparison
	var/turf/current_port_turf = get_turf(port)

	// Available airlocks
	var/list/airlock_data = list()
	for(var/obj/machinery/door/airlock/airlock in get_valid_airlocks())
		var/turf/T = get_turf(airlock)
		var/is_current = (T == current_port_turf)
		var/area/airlock_area = get_area(airlock)
		airlock_data += list(list(
			"name" = airlock.name,
			"ref" = REF(airlock),
			"x" = T ? T.x : 0,
			"y" = T ? T.y : 0,
			"isCurrent" = is_current,
			"areaName" = airlock_area ? airlock_area.name : "Unknown"
		))
	data["airlocks"] = airlock_data

	// Check if user is in construction mode (controlling drone)
	data["isInConstructionMode"] = (eyeobj && user.remote_control == eyeobj)

	// Theme preference
	data["theme"] = theme

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

	switch(action)
		if("relocate_port")
			var/obj/machinery/door/airlock/target = locate(params["airlock_ref"])
			if(!target)
				last_operation_message = "Invalid airlock selected."
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
			reset_fans()
			return TRUE
		if("setTheme")
			theme = params["theme"]
			return TRUE

	return FALSE
