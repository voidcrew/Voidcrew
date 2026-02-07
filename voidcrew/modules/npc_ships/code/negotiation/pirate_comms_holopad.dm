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
	if(active_negotiation)
		return  // Already in a negotiation, don't ring

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
	// Stop ringing if no longer appropriate
	if(!incoming_hail || active_negotiation)
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

	// Stop the ringing on ALL holopads on this ship - call has been answered
	stop_all_holopads_ringing()

	to_chat(user, span_notice("Connection established with [pirate.name]."))
	return TRUE

/**
 * Stop ringing on all ship_comms holopads on our ship.
 */
/obj/machinery/holopad/ship_comms/proc/stop_all_holopads_ringing()
	if(!linked_ship?.shuttle?.shuttle_areas)
		stop_ringing()  // At least stop this one
		return

	for(var/area/shuttle_area as anything in linked_ship.shuttle.shuttle_areas)
		for(var/obj/machinery/holopad/ship_comms/pad in shuttle_area)
			pad.stop_ringing()

/**
 * End the current communication.
 */
/obj/machinery/holopad/ship_comms/proc/end_communication()
	if(!active_negotiation)
		return

	// Don't directly end - let negotiation handle its own cleanup
	active_negotiation = null
	update_appearance(UPDATE_ICON_STATE)

// ========== CLICK INTERACTIONS ==========

/obj/machinery/holopad/ship_comms/attack_hand(mob/living/user, list/modifiers)
	// If there's an active negotiation hologram, clicking the pad redirects to hologram
	if(active_negotiation?.hologram)
		active_negotiation.hologram.attack_hand(user, modifiers)
		return

	// Otherwise show radial menu for hailing
	show_comms_radial(user)

/**
 * Show the communications radial menu.
 * Displays options to answer incoming hails from pirates.
 */
/obj/machinery/holopad/ship_comms/proc/show_comms_radial(mob/user)
	if(!linked_ship)
		find_linked_ship()
	if(!linked_ship)
		to_chat(user, span_warning("Communications array not linked to ship systems."))
		return

	var/list/choices = list()
	var/list/choice_data = list()  // Maps choice text to pirate ref

	// Pirates actively hailing us (incoming calls)
	var/list/hailing = get_hailing_pirates()
	for(var/obj/structure/overmap/ship/npc/pirate/pirate in hailing)
		var/choice_text = "Answer: [pirate.name]"
		choices[choice_text] = image(icon = 'icons/hud/radial.dmi', icon_state = "radial_yes")
		choice_data[choice_text] = list("ref" = REF(pirate))

	// No incoming hails
	if(!length(choices))
		to_chat(user, span_notice("No incoming transmissions."))
		return

	// Show radial menu
	var/choice = show_radial_menu(user, src, choices, tooltips = TRUE, require_near = TRUE)

	if(!choice || !choice_data[choice])
		return

	var/list/data = choice_data[choice]
	var/obj/structure/overmap/ship/npc/pirate/pirate = locate(data["ref"]) in SSnpc_ships.active_ships
	if(!pirate)
		to_chat(user, span_warning("Lost contact with vessel."))
		return

	answer_hail(pirate, user)

/obj/machinery/holopad/ship_comms/examine(mob/user)
	. = ..()

	if(active_negotiation)
		. += span_notice("Currently in negotiation with [active_negotiation.pirate_ship?.name].")
		. += span_notice("Click the hologram or this pad to interact.")
		return

	// Check for incoming hails
	var/list/hailing = get_hailing_pirates()
	if(length(hailing))
		. += span_boldwarning("INCOMING HAIL from [length(hailing)] vessel(s)!")
		for(var/obj/structure/overmap/ship/npc/pirate/pirate in hailing)
			. += span_warning("- [pirate.name] is hailing!")
		. += span_notice("Click to answer.")
	else
		. += span_notice("No incoming transmissions.")

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
