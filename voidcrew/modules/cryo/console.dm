#define DEFAULT_JOB_SLOT_ADJUSTMENT_COOLDOWN (2 MINUTES)

/**
 * Cryogenic Oversight Console
 *
 * Main console for managing ship job slots and crew awakening.
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
	// The console had no board at all, so a screwdriver had nothing to take apart and
	// nothing could ever put one back. It builds and deconstructs like any other
	// computer now; the ship's last one is held back by screwdriver_act() below.
	circuit = /obj/item/circuitboard/computer/cryopod

	/// The ship object representing the ship that this console is on.
	var/obj/docking_port/mobile/voidcrew/linked_port

/obj/machinery/computer/cryopod/atom_break(damage_flag)
	SHOULD_CALL_PARENT(FALSE)
	// EMPs bypass INDESTRUCTIBLE by calling atom_break() directly. Keep crew management available.
	return FALSE

/obj/machinery/computer/cryopod/ui_interact(mob/user, datum/tgui/ui)
	. = ..()
	ui = SStgui.try_update_ui(user, src, ui)
	if(!ui)
		ui = new(user, src, "CryoStorageConsole", name)
		ui.open()

/obj/machinery/computer/cryopod/examine(mob/user)
	. = ..()
	if(anchored)
		. += span_notice("It is <b>bolted</b> to the floor.")
	else
		. += span_notice("It is <i>unbolted</i> from the floor and can be dragged elsewhere.")
	if(count_ship_consoles() == 1)
		. += span_warning("It is the ship's only cryogenic oversight console, so it cannot be taken apart.")
	else
		. += span_notice("It can be taken apart with a <b>screwdriver</b>.")

/obj/machinery/computer/cryopod/connect_to_shuttle(mapload, obj/docking_port/mobile/voidcrew/port, obj/docking_port/stationary/dock)
	. = ..()
	link_to_port(port)

/// Adopts a mobile port as this console's ship, keeping the port's back-reference in step.
/obj/machinery/computer/cryopod/proc/link_to_port(obj/docking_port/mobile/voidcrew/port)
	if(!istype(port))
		return FALSE
	linked_port = port
	port.cryo_console = src
	return TRUE

/**
 * Resolves the ship this console manages.
 *
 * connect_to_shuttle() is the only thing that sets linked_port, and it only fires for
 * consoles that were on the hull's map when it loaded. A console built in-round - now
 * possible, the board exists - has to re-derive its port from where it is standing.
 * Unwrenching and re-wrenching an existing console keeps the ref it already has.
 */
/obj/machinery/computer/cryopod/proc/get_linked_ship()
	if(linked_port?.current_ship)
		return linked_port.current_ship
	var/obj/docking_port/mobile/voidcrew/port = SSshuttle.get_containing_shuttle(src)
	if(!istype(port) || !port.current_ship)
		return null
	link_to_port(port)
	return port.current_ship

/**
 * Counts every cryogenic oversight console aboard the same ship as this one.
 * Returns 0 when this console is not aboard a ship at all, which is the only case
 * where there is no ship join point to protect.
 */
/obj/machinery/computer/cryopod/proc/count_ship_consoles()
	var/obj/docking_port/mobile/port = linked_port || SSshuttle.get_containing_shuttle(src)
	if(!port)
		return 0
	var/count = 0
	for(var/area/shuttle_area as anything in port.shuttle_areas)
		for(var/obj/machinery/computer/cryopod/console in shuttle_area)
			count++
	return count

/obj/machinery/computer/cryopod/wrench_act(mob/living/user, obj/item/tool)
	. = ..()
	if(.)
		return .
	if(default_unfasten_wrench(user, tool, time = 4 SECONDS) == SUCCESSFUL_UNFASTEN)
		return ITEM_INTERACT_SUCCESS
	return ITEM_INTERACT_BLOCKING

/obj/machinery/computer/cryopod/screwdriver_act(mob/living/user, obj/item/tool)
	// The console is where a ship opens and closes joining and sets its job slots, and
	// it is the only place that can. A crew that took the last one apart would have no
	// way back in, so the last one moves but does not come apart.
	if(count_ship_consoles() == 1)
		balloon_alert(user, "ship's only console!")
		to_chat(user, span_warning("This is the ship's only cryogenic oversight console."))
		return ITEM_INTERACT_BLOCKING
	return ..()

/obj/machinery/computer/cryopod/Destroy()
	// The mobile port outlives its console and its cryo_console back-ref is otherwise
	// only dropped when the port itself dies
	if(linked_port?.cryo_console == src)
		linked_port.cryo_console = null
	linked_port = null
	return ..()

/obj/machinery/computer/cryopod/ui_data(mob/user)
	var/list/data = ..()

	// A console standing somewhere that is not a ship (built on a derelict, say) has no
	// ship to report on. Send the keys anyway so the interface renders its off state
	// rather than reading undefined.
	var/obj/structure/overmap/ship/ship = get_linked_ship()
	if(!ship)
		data["awakening"] = FALSE
		data["cooldown"] = 0
		data["memo"] = ""
		data["election_running"] = FALSE
		data["election_cooldown"] = 0
		data["has_captain"] = FALSE
		data["is_crew"] = FALSE
		data["can_call_election"] = FALSE
		return data

	data["awakening"] = ship.joining_allowed
	data["cooldown"] = (COOLDOWN_TIMELEFT(ship, job_slot_adjustment_cooldown) / 10)
	data["memo"] = ship.memo

	// Command elections. The console is where a crew without a captain comes to fix
	// that: it is already linked to the ship, already open to every crewmember, and
	// mapped onto every playable hull. See voidcrew/modules/captain_management.
	data["election_running"] = ship.election_in_progress
	data["election_cooldown"] = round(COOLDOWN_TIMELEFT(ship, election_cooldown) / 10)
	data["has_captain"] = ship.has_available_captain()
	data["is_crew"] = !!(user?.mind && (user.mind in ship.ship_team?.members))
	data["can_call_election"] = ship.can_call_election(user)

	return data

/obj/machinery/computer/cryopod/ui_static_data(mob/user)
	var/list/data = ..()
	data["jobs"] = list()

	var/obj/structure/overmap/ship/ship = get_linked_ship()
	if(!ship)
		return data

	for(var/datum/job/ship_jobs as anything in ship.job_slots)
		if(ship_jobs.officer)
			continue

		// Calculate max slots: initial slots * 2, but cap at 6 (matching backend limit)
		var/initial_slots = ship.initial_job_slots?[ship_jobs] || 1
		var/max_slots = min(initial_slots * 2, 6)

		data["jobs"] += list(list(
			"name" = ship_jobs.title,
			"slots" = ship.job_slots[ship_jobs],
			"ref" = REF(ship_jobs),
			"max" = max_slots
		))

	return data

/obj/machinery/computer/cryopod/ui_act(action, list/params)
	. = ..()
	if(.)
		return TRUE

	var/obj/structure/overmap/ship/ship = get_linked_ship()
	if(!ship)
		return

	switch(action)
		if("toggleAwakening")
			ship.joining_allowed = !ship.joining_allowed

		if("callElection")
			// call_election re-checks everything and says why it refused
			ship.call_election(usr)

		if("setMemo")
			if(!("newName" in params) || params["newName"] == ship.memo)
				return
			ship.memo = params["newName"]

		if("adjustJobSlot")
			if(!("toAdjust" in params) || !("delta" in params) || !COOLDOWN_FINISHED(ship, job_slot_adjustment_cooldown))
				return
			var/datum/job/target_job = locate(params["toAdjust"])
			if(!target_job)
				return
			if(ship.job_slots[target_job] + params["delta"] < 0 || ship.job_slots[target_job] + params["delta"] > 6)
				return
			ship.job_slots[target_job] += params["delta"]
			COOLDOWN_START(ship, job_slot_adjustment_cooldown, DEFAULT_JOB_SLOT_ADJUSTMENT_COOLDOWN)
			update_static_data(usr)

/**
 * Circuit board
 */
/obj/item/circuitboard/computer/cryopod
	name = "Cryogenic Oversight Console"
	greyscale_colors = CIRCUIT_COLOR_COMMAND
	build_path = /obj/machinery/computer/cryopod

#undef DEFAULT_JOB_SLOT_ADJUSTMENT_COOLDOWN
