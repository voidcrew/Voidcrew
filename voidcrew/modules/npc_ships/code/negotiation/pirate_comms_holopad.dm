/**
 * Ship Communications Holopad
 *
 * A specialized holopad for ship-to-ship communications.
 * Allows players to hail hostile pirate ships for negotiation.
 */
/obj/machinery/holopad/ship_comms
	name = "ship communications array"
	desc = "A holographic communication system for contacting nearby vessels. Can be used to negotiate with hostile ships."
	icon_state = "holopad0"
	/// The ship this holopad is installed on
	var/obj/structure/overmap/ship/linked_ship
	/// Active negotiation (if any)
	var/datum/pirate_negotiation/active_negotiation
	/// Whether we're currently ringing from an incoming hail
	var/incoming_hail = FALSE
	/// Timer for the ring sound loop
	var/ring_timer_id

/obj/machinery/holopad/ship_comms/Initialize(mapload)
	. = ..()
	// Try to find our ship on init
	find_linked_ship()

/obj/machinery/holopad/ship_comms/Destroy()
	stop_ringing()
	if(active_negotiation)
		active_negotiation.holopad = null
		active_negotiation = null
	linked_ship = null
	return ..()

/**
 * Start ringing to indicate an incoming pirate hail.
 */
/obj/machinery/holopad/ship_comms/proc/start_ringing()
	if(incoming_hail)
		return  // Already ringing

	incoming_hail = TRUE
	update_appearance(UPDATE_ICON_STATE)

	// Play ring sound immediately
	playsound(src, 'sound/machines/beep/twobeep.ogg', 75, FALSE)

	// Set up repeating ring sound every 3 seconds
	ring_timer_id = addtimer(CALLBACK(src, PROC_REF(ring_sound)), 3 SECONDS, TIMER_LOOP | TIMER_STOPPABLE)

/**
 * Stop ringing (hail answered or expired).
 */
/obj/machinery/holopad/ship_comms/proc/stop_ringing()
	if(!incoming_hail)
		return

	incoming_hail = FALSE
	update_appearance(UPDATE_ICON_STATE)

	if(ring_timer_id)
		deltimer(ring_timer_id)
		ring_timer_id = null

/**
 * Play ring sound (called by timer).
 */
/obj/machinery/holopad/ship_comms/proc/ring_sound()
	if(!incoming_hail)
		stop_ringing()
		return
	playsound(src, 'sound/machines/beep/twobeep.ogg', 75, FALSE)

/obj/machinery/holopad/ship_comms/update_icon_state()
	// Don't call parent - it would overwrite our icon_state
	if(incoming_hail)
		icon_state = "holopad_ringing"
		return
	if(active_negotiation)
		icon_state = "holopad1"
		return
	icon_state = "holopad0"

/**
 * Find the ship this holopad is installed on.
 */
/obj/machinery/holopad/ship_comms/proc/find_linked_ship()
	if(linked_ship)
		return linked_ship

	// Find ship by checking if we're in a shuttle area
	var/area/our_area = get_area(src)
	if(!our_area)
		return null

	// Search for simulated ships - check if our area is in the shuttle's areas
	for(var/obj/structure/overmap/ship/ship as anything in SSovermap.simulated_ships)
		if(!ship.shuttle?.shuttle_areas)
			continue
		if(our_area in ship.shuttle.shuttle_areas)
			linked_ship = ship
			return ship

	return null

/**
 * Get list of pirate ships that are actively hailing us (waiting for us to answer).
 * These are pirates in HAILING state targeting our ship.
 */
/obj/machinery/holopad/ship_comms/proc/get_hailing_pirates()
	var/list/hailing = list()

	if(!linked_ship)
		find_linked_ship()
	if(!linked_ship)
		return hailing

	for(var/obj/structure/overmap/ship/npc/pirate/pirate as anything in SSnpc_ships.active_ships)
		if(!istype(pirate))
			continue

		var/datum/ai_controller/npc_ship/controller = pirate.ai_controller
		if(!controller)
			continue

		// Must be in HAILING state and targeting us
		var/combat_state = controller.get_combat_state()
		if(combat_state != NPC_COMBAT_HAILING)
			continue

		if(controller.get_target() != linked_ship)
			continue

		hailing += pirate

	return hailing

/**
 * Get list of pirate ships that can be hailed.
 * Only pirates targeting us or about to target us are hailable.
 * Excludes pirates already hailing us (use answer_hail for those).
 */
/obj/machinery/holopad/ship_comms/proc/get_hailable_pirates()
	var/list/hailable = list()

	if(!linked_ship)
		find_linked_ship()
	if(!linked_ship)
		return hailable

	// Check all NPC pirate ships (use SSnpc_ships.active_ships, more reliable)
	for(var/obj/structure/overmap/ship/npc/pirate/pirate as anything in SSnpc_ships.active_ships)
		if(!istype(pirate))
			continue

		// Must accept negotiation
		if(!pirate.accepts_negotiation)
			continue

		var/datum/ai_controller/npc_ship/controller = pirate.ai_controller
		if(!controller)
			continue

		// Skip pirates already hailing us (they're in the hailing list, not here)
		var/combat_state = controller.get_combat_state()
		if(combat_state == NPC_COMBAT_HAILING)
			continue

		// Must be targeting us OR be in range and hostile
		var/is_targeting_us = (controller.get_target() == linked_ship)
		var/in_range = (get_dist(pirate, linked_ship) <= pirate.territory_range + 2)
		var/is_hostile = pirate.hostile

		if(!is_targeting_us && !(in_range && is_hostile))
			continue

		// Don't allow hailing if already in negotiation with this pirate
		if(controller.blackboard[BB_NPC_NEGOTIATION])
			continue

		// Don't allow re-hailing if we already failed/refused negotiation with this pirate
		var/list/failed_ships = controller.blackboard[BB_NPC_FAILED_NEGOTIATION_SHIPS]
		if(failed_ships && failed_ships[REF(linked_ship)])
			continue

		hailable += pirate

	return hailable

/**
 * Answer a hail from a pirate ship that is already trying to contact us.
 * Transitions pirate from HAILING to NEGOTIATING state.
 */
/obj/machinery/holopad/ship_comms/proc/answer_hail(obj/structure/overmap/ship/npc/pirate/pirate, mob/user)
	if(!pirate || !linked_ship)
		return FALSE

	if(active_negotiation)
		to_chat(user, span_warning("Already in an active negotiation!"))
		return FALSE

	var/datum/ai_controller/npc_ship/controller = pirate.ai_controller
	if(!controller)
		to_chat(user, span_warning("Failed to establish connection - no response."))
		return FALSE

	// Verify pirate is actually hailing us
	if(controller.get_combat_state() != NPC_COMBAT_HAILING)
		to_chat(user, span_warning("[pirate.name] is no longer hailing."))
		return FALSE

	if(controller.get_target() != linked_ship)
		to_chat(user, span_warning("[pirate.name] is not hailing us."))
		return FALSE

	// Create negotiation
	var/datum/pirate_negotiation/negotiation = new(pirate, linked_ship, src)
	if(QDELETED(negotiation))
		to_chat(user, span_warning("Failed to establish connection."))
		return FALSE

	active_negotiation = negotiation

	// Start the negotiation - this will tell the pirate AI to enter NEGOTIATING state
	if(!negotiation.start_negotiation())
		to_chat(user, span_warning("Failed to start negotiation."))
		QDEL_NULL(active_negotiation)
		return FALSE

	// Clear hailing state on pirate
	controller.clear_blackboard_key(BB_NPC_HAILING_START)
	controller.clear_blackboard_key(BB_NPC_HAILING_ANNOUNCED)
	controller.clear_blackboard_key("hailing_reminder_sent")

	// Stop the ringing - call has been answered
	stop_ringing()

	to_chat(user, span_notice("Connection established with [pirate.name]."))
	return TRUE

/**
 * Initiate hailing a pirate ship (player-initiated contact).
 * Used when pirate is NOT already hailing us.
 */
/obj/machinery/holopad/ship_comms/proc/hail_pirate(obj/structure/overmap/ship/npc/pirate/pirate, mob/user)
	if(!pirate || !linked_ship)
		return FALSE

	if(active_negotiation)
		to_chat(user, span_warning("Already in an active negotiation!"))
		return FALSE

	if(!pirate.accepts_negotiation)
		to_chat(user, span_warning("[pirate.name] is not responding to hails."))
		return FALSE

	// Create negotiation
	var/datum/pirate_negotiation/negotiation = new(pirate, linked_ship, src)
	if(QDELETED(negotiation))
		to_chat(user, span_warning("Failed to establish connection."))
		return FALSE

	active_negotiation = negotiation

	// Start the negotiation
	if(!negotiation.start_negotiation())
		to_chat(user, span_warning("Failed to start negotiation."))
		QDEL_NULL(active_negotiation)
		return FALSE

	to_chat(user, span_notice("Hailing [pirate.name]... Connection established."))
	return TRUE

/**
 * End the current communication.
 */
/obj/machinery/holopad/ship_comms/proc/end_communication()
	if(!active_negotiation)
		return

	// Don't directly end - let negotiation handle its own cleanup
	active_negotiation = null

// ========== UI INTERACTIONS ==========

/obj/machinery/holopad/ship_comms/ui_interact(mob/user, datum/tgui/ui)
	// Use custom TGUI for ship comms
	ui = SStgui.try_update_ui(user, src, ui)
	if(!ui)
		ui = new(user, src, "ShipComms")
		ui.open()

/obj/machinery/holopad/ship_comms/ui_data(mob/user)
	var/list/data = list()

	// Ship info
	data["linked_ship"] = linked_ship?.name
	data["has_negotiation"] = !!active_negotiation

	// Negotiation info
	if(active_negotiation)
		data["negotiation"] = list(
			"pirate_name" = active_negotiation.pirate_ship?.name,
			"faction" = active_negotiation.dialog?.faction_name,
			"demanded_credits" = active_negotiation.demanded_credits,
			"demanded_item" = active_negotiation.demanded_item_name,
			"demanded_quantity" = active_negotiation.demanded_item_quantity,
			"items_received" = active_negotiation.items_received,
			"state" = active_negotiation.negotiation_state,
		)

	// Pirates actively hailing us (incoming calls - answer these!)
	var/list/hailing_data = list()
	var/list/hailing = get_hailing_pirates()
	for(var/obj/structure/overmap/ship/npc/pirate/pirate in hailing)
		hailing_data += list(list(
			"ref" = REF(pirate),
			"name" = pirate.name,
			"faction" = pirate.pirate_faction,
			"distance" = linked_ship ? get_dist(pirate, linked_ship) : 0,
		))
	data["hailing_pirates"] = hailing_data

	// Hailable pirates - these are NOT currently hailing us, but we could hail them
	var/list/pirates_data = list()
	var/list/hailable = get_hailable_pirates()
	for(var/obj/structure/overmap/ship/npc/pirate/pirate in hailable)
		var/datum/ai_controller/npc_ship/controller = pirate.ai_controller
		var/is_targeting = (controller?.get_target() == linked_ship)
		pirates_data += list(list(
			"ref" = REF(pirate),
			"name" = pirate.name,
			"faction" = pirate.pirate_faction,
			"targeting" = is_targeting,
			"distance" = linked_ship ? get_dist(pirate, linked_ship) : 0,
		))
	data["hailable_pirates"] = pirates_data

	return data

/obj/machinery/holopad/ship_comms/ui_act(action, list/params, datum/tgui/ui, datum/ui_state/state)
	. = ..()
	if(.)
		return

	switch(action)
		if("answer")
			// Answer an incoming hail from a pirate
			var/pirate_ref = params["ref"]
			var/obj/structure/overmap/ship/npc/pirate/pirate = locate(pirate_ref) in SSnpc_ships.active_ships
			if(pirate)
				answer_hail(pirate, usr)
			return TRUE

		if("hail")
			// Initiate contact with a pirate (player-initiated)
			var/pirate_ref = params["ref"]
			var/obj/structure/overmap/ship/npc/pirate/pirate = locate(pirate_ref) in SSnpc_ships.active_ships
			if(pirate)
				hail_pirate(pirate, usr)
			return TRUE

		if("end_comms")
			if(active_negotiation)
				active_negotiation.end_negotiation(success = FALSE, reason = "disconnected")
			return TRUE

// ========== CLICK INTERACTIONS ==========

/obj/machinery/holopad/ship_comms/attack_hand(mob/living/user, list/modifiers)
	// If there's an active negotiation hologram, clicking the pad also opens the menu
	if(active_negotiation?.hologram)
		active_negotiation.hologram.attack_hand(user, modifiers)
		return

	// Otherwise open the UI to hail
	. = ..()

/obj/machinery/holopad/ship_comms/examine(mob/user)
	. = ..()
	// Debug info
	. += span_notice("DEBUG: Linked ship: [linked_ship?.name || "NONE"]")
	. += span_notice("DEBUG: Active pirates: [length(SSnpc_ships.active_ships)]")

	if(active_negotiation)
		. += span_notice("Currently in negotiation with [active_negotiation.pirate_ship?.name].")
		. += span_notice("Click the hologram or the pad to interact.")
	else
		var/list/hailable = get_hailable_pirates()
		if(length(hailable))
			. += span_notice("There are [length(hailable)] hostile ship(s) that can be hailed.")
			. += span_notice("Click to open communications interface.")
		else
			. += span_notice("No hostile ships in range to hail.")
			// More debug
			for(var/obj/structure/overmap/ship/npc/pirate/pirate in SSnpc_ships.active_ships)
				var/datum/ai_controller/npc_ship/controller = pirate.ai_controller
				var/obj/structure/overmap/ship/target = controller?.get_target()
				var/is_targeting_us = (target == linked_ship)
				var/dist = linked_ship ? get_dist(pirate, linked_ship) : -1
				. += span_notice("DEBUG: [pirate.name] - targeting_us=[is_targeting_us], dist=[dist], accepts_neg=[pirate.accepts_negotiation]")

// ========== HELPER PROCS ==========

/**
 * Called when a negotiation hologram is placed on this pad.
 */
/obj/machinery/holopad/ship_comms/proc/on_negotiation_hologram_set(obj/effect/overlay/holo_pad_hologram/holo)
	// For ship comms, we just track that there's a hologram
	// The actual hologram is managed by the negotiation datum
	if(holo)
		SetLightsAndPower()
		update_appearance()
