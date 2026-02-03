#define DEFAULT_JOB_SLOT_ADJUSTMENT_COOLDOWN (2 MINUTES)

/**
 * Cryogenic Oversight Console
 *
 * Main console for managing ship job slots and crew awakening.
 *
 * CUSTOM SLOT SWAPPING FEATURE:
 * - Players can swap job slots to use their custom slots from GLOB.custom_slot_manager
 * - Each job gets a dropdown to select from player's owned custom slots
 * - When swapped, the custom slot's access_preset determines spawning player's access
 * - Swaps are stored in custom_slot_swaps: job_ref -> swap_info
 * - Only the player who swapped can revert the slot back to default
 * - Supports per-round equipment purchases for custom slots
 */

//Main cryopod console.

/obj/machinery/computer/cryopod
	name = "cryogenic oversight console"
	desc = "An interface between crew and the cryogenic storage oversight systems."
	icon = 'voidcrew/modules/cryo/icons/cryogenic.dmi'
	icon_state = "cellconsole_1"
	icon_keyboard = null
	icon_screen = null
	density = FALSE
	resistance_flags = INDESTRUCTIBLE|LAVA_PROOF|FIRE_PROOF|UNACIDABLE|ACID_PROOF

	/// The ship object representing the ship that this console is on.
	var/obj/docking_port/mobile/voidcrew/linked_port
	/// Tracks custom slot swaps: job_ref -> list("ckey" = ckey, "slot_index" = index)
	var/list/custom_slot_swaps = list()

/obj/machinery/computer/cryopod/ui_interact(mob/user, datum/tgui/ui)
	. = ..()
	ui = SStgui.try_update_ui(user, src, ui)
	if(!ui)
		ui = new(user, src, "CryoStorageConsole", name)
		ui.open()

/obj/machinery/computer/cryopod/connect_to_shuttle(mapload, obj/docking_port/mobile/voidcrew/port, obj/docking_port/stationary/dock)
	. = ..()
	linked_port = port
	port.cryo_console = src

/obj/machinery/computer/cryopod/ui_data(mob/user)
	var/list/data = ..()

	data["awakening"] = linked_port.current_ship.joining_allowed
	data["cooldown"] = (COOLDOWN_TIMELEFT(linked_port.current_ship, job_slot_adjustment_cooldown) / 10)
	data["memo"] = linked_port.current_ship.memo

	// Add player's current credits (camelCase for TGUI)
	if(user.client?.ckey)
		data["playerCredits"] = GLOB.ship_economy_db.get_credits(user.client.ckey)
	else
		data["playerCredits"] = 0

	return data

/obj/machinery/computer/cryopod/ui_static_data(mob/user)
	var/list/data = ..()
	data["jobs"] = list()

	// Get player's custom slots if they have a client (camelCase for TGUI)
	data["customSlots"] = list()
	if(user.client?.ckey)
		var/list/custom_slots = GLOB.custom_slot_manager.get_player_slots(user.client.ckey)
		for(var/list/slot_data in custom_slots)
			data["customSlots"] += list(list(
				"index" = slot_data["slot_index"],
				"name" = slot_data["slot_name"],
				"accessPreset" = slot_data["access_preset"],
				"unlocked" = slot_data["purchased"],
				"equipmentCost" = 0
			))

	// Build swap options list for jobs (references to customSlots by index)
	var/list/swap_options = list()
	for(var/list/slot in data["customSlots"])
		if(slot["unlocked"])
			swap_options += list(list(
				"index" = slot["index"],
				"name" = slot["name"]
			))

	for(var/datum/job/ship_jobs as anything in linked_port.current_ship.job_slots)
		if(ship_jobs.officer)
			continue
		var/job_ref = REF(ship_jobs)
		var/current_swap = -1
		if(job_ref in custom_slot_swaps)
			current_swap = custom_slot_swaps[job_ref]["slot_index"]

		// Calculate max slots: initial slots * 2, but cap at 6 (matching backend limit)
		var/initial_slots = linked_port.current_ship.initial_job_slots?[ship_jobs] || 1
		var/max_slots = min(initial_slots * 2, 6)

		data["jobs"] += list(list(
			"name" = ship_jobs.title,
			"slots" = linked_port.current_ship.job_slots[ship_jobs],
			"ref" = job_ref,
			"max" = max_slots,
			"swapOptions" = swap_options.Copy(),
			"currentSwap" = current_swap
		))

	return data

/obj/machinery/computer/cryopod/ui_act(action, list/params)
	. = ..()
	if(.)
		return TRUE

	switch(action)
		if("toggleAwakening")
			linked_port.current_ship.joining_allowed = !linked_port.current_ship.joining_allowed

		if("setMemo")
			if(!("newName" in params) || params["newName"] == linked_port.current_ship.memo)
				return
			linked_port.current_ship.memo = params["newName"]

		if("adjustJobSlot")
			if(!("toAdjust" in params) || !("delta" in params) || !COOLDOWN_FINISHED(linked_port.current_ship, job_slot_adjustment_cooldown))
				return
			var/datum/job/target_job = locate(params["toAdjust"])
			if(!target_job)
				return
			if(linked_port.current_ship.job_slots[target_job] + params["delta"] < 0 || linked_port.current_ship.job_slots[target_job] + params["delta"] > 6)
				return
			linked_port.current_ship.job_slots[target_job] += params["delta"]
			COOLDOWN_START(linked_port.current_ship, job_slot_adjustment_cooldown, DEFAULT_JOB_SLOT_ADJUSTMENT_COOLDOWN)
			update_static_data(usr)

		if("swapCustomSlot")
			if(!usr.client?.ckey)
				return FALSE
			if(!("jobRef" in params) || !("slotIndex" in params))
				return FALSE

			var/job_ref = params["jobRef"]
			var/slot_index = text2num(params["slotIndex"])

			// Verify the job exists
			var/datum/job/target_job = locate(job_ref)
			if(!target_job)
				to_chat(usr, span_warning("Invalid job reference."))
				return FALSE

			// If slot_index is -1, revert to default
			if(slot_index == -1)
				if(job_ref in custom_slot_swaps)
					custom_slot_swaps -= job_ref
					to_chat(usr, span_notice("Job slot '[target_job.title]' reverted to default."))
					update_static_data(usr)
				return TRUE

			// Verify the player owns this custom slot
			if(!GLOB.custom_slot_manager.is_slot_owned(usr.client.ckey, slot_index))
				to_chat(usr, span_warning("You don't own this custom slot!"))
				return FALSE

			// Get the slot details
			var/list/player_slots = GLOB.custom_slot_manager.get_player_slots(usr.client.ckey)
			var/list/selected_slot = null
			for(var/list/slot in player_slots)
				if(slot["slot_index"] == slot_index)
					selected_slot = slot
					break

			if(!selected_slot)
				to_chat(usr, span_warning("Failed to load custom slot data."))
				return FALSE

			// Store the swap configuration
			custom_slot_swaps[job_ref] = list(
				"ckey" = usr.client.ckey,
				"slot_index" = slot_index,
				"slot_name" = selected_slot["slot_name"],
				"access_preset" = selected_slot["access_preset"]
			)

			to_chat(usr, span_notice("Job slot '[target_job.title]' will now use your custom slot '[selected_slot["slot_name"]]'."))
			log_game("CRYO_CONSOLE: [usr.client.ckey] swapped job [target_job.title] ([job_ref]) to custom slot [slot_index] on [linked_port.current_ship.name]")
			update_static_data(usr)
			return TRUE

		if("revertToDefault")
			if(!usr.client?.ckey)
				return FALSE
			if(!("job_ref" in params))
				return FALSE

			var/job_ref = params["job_ref"]

			// Verify the job exists
			var/datum/job/target_job = locate(job_ref)
			if(!target_job)
				to_chat(usr, span_warning("Invalid job reference."))
				return FALSE

			// Check if this job is currently swapped
			if(!(job_ref in custom_slot_swaps))
				to_chat(usr, span_warning("This job is already using the default configuration."))
				return FALSE

			// Only allow the player who made the swap to revert it
			var/list/swap_info = custom_slot_swaps[job_ref]
			if(swap_info["ckey"] != usr.client.ckey)
				to_chat(usr, span_warning("Only the player who swapped this slot can revert it."))
				return FALSE

			// Remove the swap
			custom_slot_swaps -= job_ref

			to_chat(usr, span_notice("Job slot '[target_job.title]' has been reverted to default."))
			log_game("CRYO_CONSOLE: [usr.client.ckey] reverted job [target_job.title] ([job_ref]) to default on [linked_port.current_ship.name]")
			return TRUE

		if("purchaseEquipment")
			if(!usr.client?.ckey)
				return FALSE
			if(!("slot_index" in params) || !("item_path" in params) || !("cost" in params))
				return FALSE

			var/slot_index = text2num(params["slot_index"])
			var/item_path = params["item_path"]
			var/cost = text2num(params["cost"])

			// Attempt the purchase through the custom slot manager
			if(GLOB.custom_slot_manager.purchase_equipment(usr.client.ckey, slot_index, item_path, cost))
				to_chat(usr, span_notice("Successfully purchased equipment for custom slot [slot_index]!"))
				return TRUE
			else
				to_chat(usr, span_warning("Failed to purchase equipment. Check if you have enough credits and own the slot."))
				return FALSE

/**
 * Get custom slot configuration for a job if it's been swapped
 *
 * @param job - The job datum or job reference
 * @return List with swap info (ckey, slot_index, slot_name, access_preset) or null if not swapped
 */
/obj/machinery/computer/cryopod/proc/get_custom_slot_for_job(datum/job/job)
	if(!job)
		return null

	var/job_ref = REF(job)
	if(!(job_ref in custom_slot_swaps))
		return null

	return custom_slot_swaps[job_ref]

/**
 * Check if a job slot is currently swapped to a custom slot
 *
 * @param job - The job datum or job reference
 * @return TRUE if swapped, FALSE otherwise
 */
/obj/machinery/computer/cryopod/proc/is_job_swapped(datum/job/job)
	if(!job)
		return FALSE

	var/job_ref = REF(job)
	return (job_ref in custom_slot_swaps)

/**
 * Get the access preset for a job (returns custom slot preset if swapped, null otherwise)
 *
 * @param job - The job datum
 * @return Access preset string (engineer/medical/security/captain/assistant) or null
 */
/obj/machinery/computer/cryopod/proc/get_job_access_preset(datum/job/job)
	var/list/swap_info = get_custom_slot_for_job(job)
	if(!swap_info)
		return null

	return swap_info["access_preset"]

/**
 * Clear all custom slot swaps (useful for round restart or admin commands)
 */
/obj/machinery/computer/cryopod/proc/clear_all_swaps()
	custom_slot_swaps.Cut()
	log_game("CRYO_CONSOLE: All custom slot swaps cleared on [linked_port?.current_ship?.name]")

#undef DEFAULT_JOB_SLOT_ADJUSTMENT_COOLDOWN
