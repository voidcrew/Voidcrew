/**
 * # Mission Board Console
 *
 * Computer console for viewing and managing ship missions.
 * - View available and active missions
 * - Accept new missions
 * - Turn in completed missions
 * - Captain can adjust crew share percentage
 */
/obj/machinery/computer/mission_board
	name = "mission board"
	desc = "A console for managing ship contracts and missions."
	icon = 'voidcrew/modules/shuttle/icons/computer.dmi'
	icon_screen = "mission"
	icon_keyboard = "rd_key"
	circuit = /obj/item/circuitboard/computer/mission_board
	light_color = COLOR_BRIGHT_ORANGE

	/// Linked mission pad for item turn-in
	var/obj/machinery/mission_pad/linked_pad

/obj/machinery/computer/mission_board/Initialize(mapload)
	. = ..()
	// Try to find a linked pad nearby
	find_linked_pad()

/obj/machinery/computer/mission_board/Destroy()
	if(linked_pad)
		linked_pad.linked_console = null
		linked_pad = null
	return ..()

/**
 * Searches for a mission pad within range and links to it.
 */
/obj/machinery/computer/mission_board/proc/find_linked_pad()
	for(var/obj/machinery/mission_pad/pad in range(3, src))
		if(!pad.linked_console)
			link_to_pad(pad)
			return

/**
 * Links this console to a mission pad.
 * * pad - The pad to link to
 */
/obj/machinery/computer/mission_board/proc/link_to_pad(obj/machinery/mission_pad/pad)
	if(!pad)
		return
	if(linked_pad)
		linked_pad.linked_console = null
	linked_pad = pad
	pad.linked_console = src

/**
 * Gets the ship this console is on.
 */
/obj/machinery/computer/mission_board/proc/get_ship()
	return get_ship_from_atom(src)

/obj/machinery/computer/mission_board/ui_interact(mob/user, datum/tgui/ui)
	. = ..()
	ui = SStgui.try_update_ui(user, src, ui)
	if(!ui)
		ui = new(user, src, "MissionBoard", name)
		ui.open()

/obj/machinery/computer/mission_board/ui_data(mob/user)
	var/list/data = list()

	var/obj/structure/overmap/ship/ship = get_ship()
	data["has_ship"] = !!ship
	if(!ship)
		return data

	data["max_missions"] = ship.max_missions
	data["active_count"] = length(ship.active_missions)
	data["has_pad"] = !!linked_pad

	// Available missions
	data["available_missions"] = list()
	for(var/datum/mission/mission as anything in ship.available_missions)
		if(QDELETED(mission))
			continue
		data["available_missions"] += list(mission.get_ui_data())

	// Active missions
	data["active_missions"] = list()
	for(var/datum/mission/mission as anything in ship.active_missions)
		if(QDELETED(mission))
			continue
		data["active_missions"] += list(mission.get_ui_data())

	// Pad contents (for item turn-in display)
	data["pad_contents"] = list()
	if(linked_pad)
		for(var/obj/item/item in linked_pad.get_items_on_pad())
			data["pad_contents"] += list(list(
				"name" = item.name,
				"ref" = REF(item),
			))

	return data

/obj/machinery/computer/mission_board/ui_act(action, params, datum/tgui/ui)
	. = ..()
	if(.)
		return

	var/obj/structure/overmap/ship/ship = get_ship()
	if(!ship)
		balloon_alert(usr, "console not on a ship!")
		return TRUE

	switch(action)
		if("accept")
			var/datum/mission/mission = locate(params["ref"]) in ship.available_missions
			if(!mission)
				balloon_alert(usr, "mission not found!")
				return TRUE

			var/result = ship.accept_mission(mission)
			if(result != TRUE)
				balloon_alert(usr, result)
				playsound(src, 'sound/machines/buzz/buzz-sigh.ogg', 50, TRUE)
			else
				balloon_alert(usr, "mission accepted!")
				playsound(src, 'sound/machines/ding.ogg', 50, TRUE)
			return TRUE

		if("turn_in")
			var/datum/mission/mission = locate(params["ref"]) in ship.active_missions
			if(!mission)
				balloon_alert(usr, "mission not found!")
				return TRUE

			// Check for item on pad if mission requires it
			var/obj/item/turn_in_item = null
			if(linked_pad && params["item_ref"])
				// Locate the item by ref, then verify it's actually on the pad's turf
				var/obj/item/found_item = locate(params["item_ref"])
				if(found_item && found_item.loc == linked_pad.loc)
					turn_in_item = found_item

			var/result = ship.complete_mission(mission, linked_pad, turn_in_item)
			if(result != TRUE)
				balloon_alert(usr, result)
				playsound(src, 'sound/machines/buzz/buzz-sigh.ogg', 50, TRUE)
			else
				balloon_alert(usr, "mission completed!")
				playsound(src, 'sound/machines/ding.ogg', 50, TRUE)
			return TRUE

		if("abandon")
			var/datum/mission/mission = locate(params["ref"]) in ship.active_missions
			if(!mission)
				balloon_alert(usr, "mission not found!")
				return TRUE

			var/result = ship.abandon_mission(mission)
			if(result != TRUE)
				balloon_alert(usr, result)
			else
				balloon_alert(usr, "mission abandoned")
			return TRUE

		if("refresh")
			// Force refresh available missions
			SSmissions.force_refresh_ship_missions(ship)
			balloon_alert(usr, "missions refreshed!")
			return TRUE

/**
 * Circuit board for the mission board console.
 */
/obj/item/circuitboard/computer/mission_board
	name = "Mission Board"
	greyscale_colors = CIRCUIT_COLOR_SUPPLY
	build_path = /obj/machinery/computer/mission_board
