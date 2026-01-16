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

	// Bounties - global competitive pirate bounties
	data["bounties"] = SSbounty?.get_bounty_ui_data(ship) || list()
	data["has_active_bounty"] = SSbounty?.ship_has_active_bounty(ship) || FALSE

	// Player bounties
	data["player_bounties"] = SSbounty?.get_player_bounty_ui_data(ship) || list()
	data["has_created_bounty"] = SSbounty?.ship_has_active_player_bounty(ship) || FALSE
	data["has_claimed_player_bounty"] = SSbounty?.ship_has_claimed_player_bounty(ship) || FALSE
	data["ship_balance"] = ship.ship_account?.account_balance || 0

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

		// ========== BOUNTY ACTIONS ==========

		if("accept_bounty")
			var/datum/pirate_bounty/bounty = locate(params["ref"])
			if(!bounty || !bounty.is_valid())
				balloon_alert(usr, "bounty not available!")
				return TRUE

			// Check specific failure reasons for better feedback
			if(bounty.has_abandoned(ship))
				balloon_alert(usr, "you abandoned this bounty!")
				return TRUE

			if(SSbounty?.ship_has_active_bounty(ship))
				balloon_alert(usr, "already hunting a bounty!")
				return TRUE

			if(bounty.add_claimant(ship))
				balloon_alert(usr, "bounty accepted!")
				playsound(src, 'sound/machines/ding.ogg', 50, TRUE)
				ship.ship_announce("BOUNTY ACCEPTED: [bounty.name] - [bounty.reward] credit reward", "MISSION CONTROL")
			else
				balloon_alert(usr, "cannot accept bounty!")
			return TRUE

		if("cancel_bounty")
			var/datum/pirate_bounty/bounty = locate(params["ref"])
			if(!bounty)
				balloon_alert(usr, "bounty not found!")
				return TRUE

			if(bounty.remove_claimant(ship))
				balloon_alert(usr, "bounty cancelled")
				ship.ship_announce("BOUNTY CANCELLED: [bounty.name]", "MISSION CONTROL")
			else
				balloon_alert(usr, "not hunting this bounty!")
			return TRUE

		if("enable_tracking")
			var/datum/pirate_bounty/bounty = locate(params["ref"])
			if(!bounty || !bounty.is_valid())
				balloon_alert(usr, "bounty not available!")
				return TRUE

			if(!bounty.is_claimant(ship))
				balloon_alert(usr, "not hunting this bounty!")
				return TRUE

			if(bounty.has_tracking(ship))
				balloon_alert(usr, "already tracking!")
				return TRUE

			if(bounty.enable_tracking(ship))
				var/tracking_cost = bounty.get_tracking_cost()
				balloon_alert(usr, "tracking enabled! -[tracking_cost] cr")
				playsound(src, 'sound/machines/ding.ogg', 50, TRUE)
				ship.ship_announce("TRACKING ENABLED: [bounty.name] - Reward reduced by [tracking_cost] credits", "MISSION CONTROL")
			else
				balloon_alert(usr, "cannot enable tracking!")
			return TRUE

		if("turn_in_bounty")
			// Find ship key on pad
			if(!linked_pad)
				balloon_alert(usr, "no mission pad linked!")
				return TRUE

			var/obj/item/ship_key/key = locate() in linked_pad.get_items_on_pad()
			if(!key)
				balloon_alert(usr, "place captain's key on pad!")
				return TRUE

			// Find what bounty this ship is hunting (ships can only have one)
			var/list/hunting = SSbounty?.get_bounties_for_claimant(ship)
			if(!length(hunting))
				balloon_alert(usr, "you have no active bounty!")
				return TRUE

			var/datum/pirate_bounty/bounty = hunting[1]

			// Verify the key matches the bounty we're hunting
			if(key != bounty.get_target_key())
				balloon_alert(usr, "wrong key! need [bounty.name]'s key")
				return TRUE

			if(!bounty.is_valid())
				balloon_alert(usr, "bounty no longer valid!")
				return TRUE

			// Complete the bounty!
			var/reward = bounty.complete(ship, linked_pad)
			if(reward > 0)
				balloon_alert(usr, "[reward] credits awarded!")
				playsound(src, 'sound/effects/cashregister.ogg', 50, TRUE)
				// Mark key for bounty destruction and delete it
				key.mark_destruction_reason(KEY_DESTROYED_BOUNTY)
				qdel(key)
			else
				balloon_alert(usr, "bounty completion failed!")
			return TRUE

		// ========== PLAYER BOUNTY ACTIONS ==========

		if("create_preset_bounty")
			// Open radial menu for item selection
			if(SSbounty?.ship_has_active_player_bounty(ship))
				balloon_alert(usr, "already have active bounty!")
				return TRUE

			var/reward_amount = text2num(params["reward"])
			if(!reward_amount || reward_amount < 100)
				balloon_alert(usr, "minimum reward is 100 cr!")
				return TRUE

			if(ship.ship_account?.account_balance < reward_amount)
				balloon_alert(usr, "insufficient funds!")
				return TRUE

			var/item_amount = text2num(params["amount"]) || 1
			item_amount = clamp(item_amount, 1, 100)

			// Show radial menu for item selection
			var/selected_type = show_preset_item_radial(usr)
			if(!selected_type)
				return TRUE // User cancelled

			// Create the bounty
			var/datum/player_bounty/new_bounty = SSbounty?.create_player_bounty(ship, linked_pad, reward_amount)
			if(!new_bounty)
				balloon_alert(usr, "failed to create bounty!")
				return TRUE

			if(!new_bounty.setup_preset(selected_type, item_amount))
				new_bounty.cancel()
				balloon_alert(usr, "invalid item selected!")
				return TRUE

			balloon_alert(usr, "bounty created!")
			playsound(src, 'sound/machines/ding.ogg', 50, TRUE)
			ship.ship_announce("BOUNTY POSTED: [new_bounty.name] - [reward_amount] credit reward", "MISSION CONTROL")
			return TRUE

		if("create_custom_bounty")
			if(SSbounty?.ship_has_active_player_bounty(ship))
				balloon_alert(usr, "already have active bounty!")
				return TRUE

			var/reward_amount = text2num(params["reward"])
			if(!reward_amount || reward_amount < 100)
				balloon_alert(usr, "minimum reward is 100 cr!")
				return TRUE

			if(ship.ship_account?.account_balance < reward_amount)
				balloon_alert(usr, "insufficient funds!")
				return TRUE

			var/bounty_name = params["name"]
			var/bounty_desc = params["desc"]

			if(!bounty_name || length(bounty_name) < 3)
				balloon_alert(usr, "name too short!")
				return TRUE

			if(!bounty_desc || length(bounty_desc) < 5)
				balloon_alert(usr, "description too short!")
				return TRUE

			// Sanitize inputs
			bounty_name = copytext(sanitize(bounty_name), 1, 64)
			bounty_desc = copytext(sanitize(bounty_desc), 1, 256)

			// Create the bounty
			var/datum/player_bounty/new_bounty = SSbounty?.create_player_bounty(ship, linked_pad, reward_amount)
			if(!new_bounty)
				balloon_alert(usr, "failed to create bounty!")
				return TRUE

			if(!new_bounty.setup_custom(bounty_name, bounty_desc))
				new_bounty.cancel()
				balloon_alert(usr, "failed to setup bounty!")
				return TRUE

			balloon_alert(usr, "bounty created!")
			playsound(src, 'sound/machines/ding.ogg', 50, TRUE)
			ship.ship_announce("BOUNTY POSTED: [new_bounty.name] - [reward_amount] credit reward", "MISSION CONTROL")
			return TRUE

		if("claim_player_bounty")
			var/datum/player_bounty/bounty = locate(params["ref"])
			if(!bounty || !bounty.is_valid())
				balloon_alert(usr, "bounty not available!")
				return TRUE

			var/result = bounty.claim(ship)
			if(result != TRUE)
				balloon_alert(usr, result)
				return TRUE

			balloon_alert(usr, "bounty accepted!")
			playsound(src, 'sound/machines/ding.ogg', 50, TRUE)
			ship.ship_announce("PLAYER BOUNTY ACCEPTED: [bounty.name] - [bounty.reward] credit reward", "MISSION CONTROL")
			return TRUE

		if("abandon_player_bounty")
			var/datum/player_bounty/bounty = locate(params["ref"])
			if(!bounty)
				balloon_alert(usr, "bounty not found!")
				return TRUE

			if(bounty.abandon(ship))
				balloon_alert(usr, "bounty abandoned")
				ship.ship_announce("PLAYER BOUNTY ABANDONED: [bounty.name]", "MISSION CONTROL")
			else
				balloon_alert(usr, "not your bounty!")
			return TRUE

		if("cancel_player_bounty")
			var/datum/player_bounty/bounty = SSbounty?.get_ship_created_bounty(ship)
			if(!bounty)
				balloon_alert(usr, "no bounty to cancel!")
				return TRUE

			bounty.cancel()
			balloon_alert(usr, "bounty cancelled, funds refunded")
			return TRUE

		if("turn_in_player_bounty")
			if(!linked_pad)
				balloon_alert(usr, "no mission pad linked!")
				return TRUE

			var/datum/player_bounty/bounty = SSbounty?.get_ship_claimed_bounty(ship)
			if(!bounty)
				balloon_alert(usr, "no claimed bounty!")
				return TRUE

			if(bounty.is_custom)
				balloon_alert(usr, "custom bounties need creator approval!")
				return TRUE

			// For stacks, count total across all matching stacks on pad
			var/list/matching_items = list()
			var/total_amount = 0

			for(var/obj/item/item in linked_pad.get_items_on_pad())
				if(istype(item, bounty.target_item_type))
					if(isstack(item))
						var/obj/item/stack/S = item
						total_amount += S.amount
						matching_items += item
					else
						// Non-stack item found
						matching_items += item
						total_amount = 1
						break

			if(!length(matching_items))
				balloon_alert(usr, "place [bounty.target_item_name] on pad!")
				return TRUE

			if(total_amount < bounty.target_amount)
				balloon_alert(usr, "need [bounty.target_amount], only have [total_amount]!")
				return TRUE

			if(bounty.complete_preset(ship, linked_pad, matching_items))
				balloon_alert(usr, "[bounty.reward] credits awarded!")
				playsound(src, 'sound/effects/cashregister.ogg', 50, TRUE)
			else
				balloon_alert(usr, "turn-in failed!")
			return TRUE

		if("complete_custom_bounty")
			// Creator manually completes a custom bounty for a specific claimant
			var/datum/player_bounty/bounty = SSbounty?.get_ship_created_bounty(ship)
			if(!bounty)
				balloon_alert(usr, "no bounty to complete!")
				return TRUE

			if(!bounty.is_custom)
				balloon_alert(usr, "preset bounties auto-complete!")
				return TRUE

			if(bounty.get_hunter_count() == 0)
				balloon_alert(usr, "no one hunting this bounty!")
				return TRUE

			// Find the claimant to pay
			var/obj/structure/overmap/ship/winner = locate(params["claimant_ref"])
			if(!winner || !bounty.is_claimant(winner))
				balloon_alert(usr, "invalid claimant!")
				return TRUE

			if(bounty.complete_custom(winner))
				balloon_alert(usr, "bounty completed!")
				playsound(src, 'sound/machines/ding.ogg', 50, TRUE)
			else
				balloon_alert(usr, "completion failed!")
			return TRUE

		if("send_custom_bounty_item")
			// Claimer sends an item to the creator's pad for custom bounties
			if(!linked_pad)
				balloon_alert(usr, "no mission pad linked!")
				return TRUE

			var/datum/player_bounty/bounty = SSbounty?.get_ship_claimed_bounty(ship)
			if(!bounty)
				balloon_alert(usr, "no claimed bounty!")
				return TRUE

			if(!bounty.is_custom)
				balloon_alert(usr, "use turn-in for item bounties!")
				return TRUE

			// Get items on pad
			var/list/items_on_pad = linked_pad.get_items_on_pad()
			if(!length(items_on_pad))
				balloon_alert(usr, "place item on pad first!")
				return TRUE

			// Send items to creator's pad
			var/sent_count = bounty.send_items_to_creator(items_on_pad, linked_pad, ship)
			if(sent_count > 0)
				balloon_alert(usr, "sent [sent_count] item(s)!")
				playsound(src, 'sound/effects/magic/teleport_diss.ogg', 50, TRUE)
			else
				balloon_alert(usr, "failed to send items!")
			return TRUE

/**
 * Shows a radial menu for selecting preset bounty items.
 * @param user The mob selecting
 * @return The selected item type path, or null if cancelled
 */
/obj/machinery/computer/mission_board/proc/show_preset_item_radial(mob/user)
	var/list/choices = list()

	for(var/item_type in GLOB.preset_bounty_items)
		var/list/item_data = GLOB.preset_bounty_items[item_type]
		var/item_name = item_data[1]
		var/icon_state = item_data[2]
		var/icon_file = item_data[3]

		var/image/item_image = image(icon = icon_file, icon_state = icon_state)
		choices[item_name] = item_image

	var/selection = show_radial_menu(user, src, choices, tooltips = TRUE)
	if(!selection)
		return null

	// Find the type that matches the selection name
	for(var/item_type in GLOB.preset_bounty_items)
		var/list/item_data = GLOB.preset_bounty_items[item_type]
		if(item_data[1] == selection)
			return item_type

	return null

/**
 * Circuit board for the mission board console.
 */
/obj/item/circuitboard/computer/mission_board
	name = "Mission Board"
	greyscale_colors = CIRCUIT_COLOR_SUPPLY
	build_path = /obj/machinery/computer/mission_board
