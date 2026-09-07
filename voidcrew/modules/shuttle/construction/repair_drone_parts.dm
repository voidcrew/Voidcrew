/// Print all four purpose-built parts in Robotics after Shuttle Repair Swarm research.
/obj/item/ship_repair_drone_part
	name = "repair drone part"
	icon = 'voidcrew/modules/shuttle/icons/repair_drone.dmi'
	w_class = WEIGHT_CLASS_BULKY
	obj_flags = CAN_BE_HIT
	max_integrity = 50

/obj/item/ship_repair_drone_part/chassis
	name = "ship repair drone chassis"
	desc = "The structural frame of an autonomous ship repair drone. Assemble it with Robotics parts and tools."
	icon_state = "frame"
	max_integrity = 75
	custom_materials = list(/datum/material/iron = SHEET_MATERIAL_AMOUNT * 6, /datum/material/titanium = SHEET_MATERIAL_AMOUNT * 2)

/obj/item/ship_repair_drone_part/chassis/Initialize(mapload)
	. = ..()
	AddComponent(/datum/component/construction/ship_repair_drone)

/obj/item/ship_repair_drone_part/propulsion
	name = "repair drone propulsion unit"
	desc = "A compact vectoring thruster and flight stabilizer for a ship repair drone."
	icon_state = "part_propulsion"
	custom_materials = list(/datum/material/iron = SHEET_MATERIAL_AMOUNT * 6, /datum/material/titanium = SHEET_MATERIAL_AMOUNT * 3)

/obj/item/ship_repair_drone_part/arm
	name = "repair drone fabricator arm"
	desc = "A precision manipulator with a matter assembler, supplied by a construction console's silo."
	icon_state = "part_arm"
	custom_materials = list(/datum/material/iron = SHEET_MATERIAL_AMOUNT * 6, /datum/material/glass = SHEET_MATERIAL_AMOUNT, /datum/material/silver = SHEET_MATERIAL_AMOUNT)

/obj/item/ship_repair_drone_part/controller
	name = "repair drone controller board"
	desc = "A flight computer and swarm coordinator for a ship repair drone."
	icon = 'icons/obj/devices/circuitry_n_data.dmi'
	icon_state = "mcontroller"
	w_class = WEIGHT_CLASS_SMALL
	custom_materials = list(/datum/material/iron = SHEET_MATERIAL_AMOUNT * 2, /datum/material/glass = SHEET_MATERIAL_AMOUNT * 2, /datum/material/gold = SHEET_MATERIAL_AMOUNT * 2)

/// Uses the same reversible construction component as mechs: parts are returned on undo.
/datum/component/construction/ship_repair_drone
	result = /obj/structure/ship_repair_drone
	var/working = FALSE
	steps = list(
		list("key" = /obj/item/ship_repair_drone_part/propulsion, "action" = ITEM_DELETE,
			"desc" = "Fit a <b>repair drone propulsion unit</b> to the chassis.", "icon_state" = "frame"),
		list("key" = TOOL_WRENCH, "back_key" = TOOL_CROWBAR,
			"desc" = "Secure the propulsion unit with a <b>wrench</b>, or remove it with a crowbar.", "icon_state" = "propulsion"),
		list("key" = /obj/item/ship_repair_drone_part/arm, "action" = ITEM_DELETE, "back_key" = TOOL_WRENCH,
			"desc" = "Install a <b>repair drone fabricator arm</b>.", "icon_state" = "propulsion"),
		list("key" = /obj/item/stack/cable_coil, "amount" = 5, "back_key" = TOOL_CROWBAR,
			"desc" = "Add <b>five lengths of cable</b>, or remove the arm with a crowbar.", "icon_state" = "arm"),
		list("key" = /obj/item/ship_repair_drone_part/controller, "action" = ITEM_DELETE, "back_key" = TOOL_WIRECUTTER,
			"desc" = "Insert the <b>repair drone controller board</b>, or cut out the wiring.", "icon_state" = "wired"),
		list("key" = TOOL_SCREWDRIVER, "back_key" = TOOL_CROWBAR,
			"desc" = "Boot and seal the drone with a <b>screwdriver</b>, or remove the board with a crowbar.", "icon_state" = "controller"),
	)

/datum/component/construction/ship_repair_drone/Initialize()
	. = ..()
	// Handle assembly before combat fallback. Signals must return before timed tool use.
	UnregisterSignal(parent, COMSIG_ATOM_ATTACKBY)
	RegisterSignal(parent, COMSIG_ATOM_ITEM_INTERACTION, PROC_REF(on_assembly_interaction))

/datum/component/construction/ship_repair_drone/proc/on_assembly_interaction(datum/source, mob/living/user, obj/item/item, list/modifiers)
	SIGNAL_HANDLER
	if(user.combat_mode)
		return NONE
	if(!is_right_key(item))
		if(item.tool_behaviour in list(TOOL_WRENCH, TOOL_CROWBAR, TOOL_SCREWDRIVER, TOOL_WIRECUTTER))
			to_chat(user, span_notice(desc))
			return ITEM_INTERACT_SUCCESS
		return NONE
	INVOKE_ASYNC(src, PROC_REF(check_step), item, user)
	return ITEM_INTERACT_SUCCESS

/datum/component/construction/ship_repair_drone/check_step(obj/item/item, mob/living/user)
	if(working)
		return FALSE
	working = TRUE
	. = ..()
	working = FALSE

/datum/component/construction/ship_repair_drone/proc/step_is_current(expected_index)
	return !QDELETED(src) && !QDELETED(parent) && index == expected_index

/datum/component/construction/ship_repair_drone/custom_action(obj/item/item, mob/living/user, diff)
	if(!item.tool_behaviour)
		return ..()
	var/expected_index = index
	if(!item.use_tool(parent, user, 2 SECONDS, volume = 50, extra_checks = CALLBACK(src, PROC_REF(step_is_current), expected_index)))
		return FALSE
	if(!step_is_current(expected_index))
		return FALSE
	if(diff == BACKWARD)
		var/list/previous_step = steps[index - 1]
		var/part_path = previous_step["key"]
		if(!previous_step["no_refund"] && ispath(part_path, /obj/item))
			if(ispath(part_path, /obj/item/stack))
				new part_path(drop_location(), previous_step["amount"])
			else
				new part_path(drop_location())
	return TRUE

/datum/component/construction/ship_repair_drone/spawn_result()
	var/obj/item/ship_repair_drone_part/chassis/chassis = parent
	var/obj/structure/ship_repair_drone/drone = new result(drop_location())
	drone.setDir(chassis.dir)
	qdel(chassis)

/datum/design/ship_repair_drone_chassis
	name = "Repair Drone Chassis"
	id = "ship_repair_drone_chassis"
	build_type = MECHFAB
	build_path = /obj/item/ship_repair_drone_part/chassis
	materials = list(/datum/material/iron = SHEET_MATERIAL_AMOUNT * 6, /datum/material/titanium = SHEET_MATERIAL_AMOUNT * 2)
	construction_time = 15 SECONDS
	category = list("/Repair Drones/Parts")

/datum/design/ship_repair_drone_propulsion
	name = "Repair Drone Propulsion Unit"
	id = "ship_repair_drone_propulsion"
	build_type = MECHFAB
	build_path = /obj/item/ship_repair_drone_part/propulsion
	materials = list(/datum/material/iron = SHEET_MATERIAL_AMOUNT * 6, /datum/material/titanium = SHEET_MATERIAL_AMOUNT * 3)
	construction_time = 15 SECONDS
	category = list("/Repair Drones/Parts")

/datum/design/ship_repair_drone_arm
	name = "Repair Drone Fabricator Arm"
	id = "ship_repair_drone_arm"
	build_type = MECHFAB
	build_path = /obj/item/ship_repair_drone_part/arm
	materials = list(/datum/material/iron = SHEET_MATERIAL_AMOUNT * 6, /datum/material/glass = SHEET_MATERIAL_AMOUNT, /datum/material/silver = SHEET_MATERIAL_AMOUNT)
	construction_time = 15 SECONDS
	category = list("/Repair Drones/Parts")

/datum/design/ship_repair_drone_controller
	name = "Repair Drone Controller Board"
	id = "ship_repair_drone_controller"
	build_type = MECHFAB
	build_path = /obj/item/ship_repair_drone_part/controller
	materials = list(/datum/material/iron = SHEET_MATERIAL_AMOUNT * 2, /datum/material/glass = SHEET_MATERIAL_AMOUNT * 2, /datum/material/gold = SHEET_MATERIAL_AMOUNT * 2)
	construction_time = 10 SECONDS
	category = list("/Repair Drones/Parts")
