/**
 * Pirate hails on the standard holopad
 *
 * Every holopad doubles as the ship's comms array: pirate hails ring the
 * ship's pads and show up as incoming calls in the stock Holopad TGUI,
 * right alongside regular holo-calls (see the VOIDCREW EDIT hooks in
 * code/game/machinery/hologram.dm ui_data/ui_act). Answering one spawns the
 * pirate captain hologram and starts a /datum/pirate_negotiation.
 *
 * There is deliberately no holopad subtype: the ship the pad belongs to is
 * resolved live via voidcrew_ship_port() (voidcrew/modules/holopads), same
 * lazy-resolution idiom as ship-to-ship holo-calls.
 */
/obj/machinery/holopad
	/// Active pirate negotiation displayed on this pad (if any)
	var/datum/pirate_negotiation/active_negotiation
	/// Whether we're currently ringing from an incoming pirate hail
	var/incoming_hail = FALSE
	/// Timer for the pirate hail ring sound loop
	var/hail_ring_timer_id

/// The overmap ship this pad is aboard, or null. Resolved live, never cached.
/obj/machinery/holopad/proc/voidcrew_comms_ship()
	var/obj/docking_port/mobile/voidcrew/ship_port = voidcrew_ship_port()
	return ship_port?.current_ship

// ===== HAIL RINGING =====

/**
 * Start ringing to indicate an incoming pirate hail. Reuses the upstream
 * `ringing` icon state; the loop timer is ours because process()-driven
 * ringing only runs while holo-calls exist.
 */
/obj/machinery/holopad/proc/start_hail_ringing()
	if(incoming_hail)
		return // Already ringing
	if(active_negotiation)
		return // Already in a negotiation, don't ring

	incoming_hail = TRUE
	ringing = TRUE
	update_appearance(UPDATE_ICON_STATE)

	// Play ring sound immediately, then every 3 seconds
	playsound(src, 'sound/machines/beep/twobeep.ogg', 75, FALSE)
	hail_ring_timer_id = addtimer(CALLBACK(src, PROC_REF(hail_ring_sound)), 3 SECONDS, TIMER_LOOP | TIMER_STOPPABLE)

/**
 * Stop ringing (hail answered, expired, or escalated to combat).
 */
/obj/machinery/holopad/proc/stop_hail_ringing()
	if(hail_ring_timer_id)
		deltimer(hail_ring_timer_id)
		hail_ring_timer_id = null
	if(!incoming_hail)
		return

	incoming_hail = FALSE
	// process() re-raises `ringing` next tick if ordinary holo-calls are still waiting
	ringing = FALSE
	update_appearance(UPDATE_ICON_STATE)

/// Ring sound loop (called by timer).
/obj/machinery/holopad/proc/hail_ring_sound()
	// Stop ringing if no longer appropriate
	if(!incoming_hail || active_negotiation)
		stop_hail_ringing()
		return

	// Nobody left on the other end. The caller that started this ring is supposed to
	// silence it, but the ring is a TIMER_LOOP with no upper bound, so any path that
	// forgets leaves a pad beeping and flashing for the rest of the round with an
	// empty answer list - unanswerable, because answering needs a pirate still in
	// HAILING. Re-checking our own premise each loop makes that unrecoverable state
	// impossible regardless of which caller dropped the ball.
	if(!length(get_hailing_pirates()))
		stop_hail_ringing()
		return

	playsound(src, 'sound/machines/beep/twobeep.ogg', 75, FALSE)

// Ship-wide ring control: the pirate AI rings/silences the whole ship, not one pad.

/// Every holopad aboard this ship.
/obj/structure/overmap/ship/proc/get_comms_holopads()
	. = list()
	if(!shuttle?.shuttle_areas)
		return
	for(var/area/shuttle_area as anything in shuttle.shuttle_areas)
		for(var/obj/machinery/holopad/pad in shuttle_area)
			. += pad

/// Ring every holopad aboard (incoming pirate hail).
/obj/structure/overmap/ship/proc/start_hail_ringing()
	for(var/obj/machinery/holopad/pad as anything in get_comms_holopads())
		pad.start_hail_ringing()

/// Silence every holopad aboard (hail answered, expired, or escalated).
/obj/structure/overmap/ship/proc/stop_hail_ringing()
	for(var/obj/machinery/holopad/pad as anything in get_comms_holopads())
		pad.stop_hail_ringing()

// ===== HAIL DISCOVERY / ANSWERING =====

/**
 * Pirate ships actively hailing this pad's ship (in HAILING state and
 * targeting us), waiting for a crew member to answer.
 */
/obj/machinery/holopad/proc/get_hailing_pirates()
	var/list/hailing = list()

	var/obj/structure/overmap/ship/our_ship = voidcrew_comms_ship()
	if(!our_ship)
		return hailing

	for(var/obj/structure/overmap/ship/npc/pirate/pirate as anything in SSnpc_ships.active_ships)
		if(!istype(pirate))
			continue

		var/datum/ai_controller/npc_ship/controller = pirate.ai_controller
		if(!controller)
			continue

		// Must be in HAILING state and targeting us
		if(controller.get_combat_state() != NPC_COMBAT_HAILING)
			continue
		if(controller.get_target() != our_ship)
			continue

		hailing += pirate

	return hailing

/**
 * Incoming pirate hails shaped like holo-call entries for the Holopad TGUI's
 * "holo_calls" list (spliced in by the VOIDCREW EDIT in ui_data). The ref is
 * the pirate ship's, which ui_act("connectcall") hands back to
 * voidcrew_try_answer_hail().
 */
/obj/machinery/holopad/proc/voidcrew_hail_call_data()
	var/list/entries = list()
	for(var/obj/structure/overmap/ship/npc/pirate/pirate as anything in get_hailing_pirates())
		entries += list(list(
			"caller" = "[pirate.name] (hostile vessel)",
			"connected" = FALSE,
			"ref" = REF(pirate),
		))
	return entries

/**
 * ui_act("connectcall") hook: if the ref belongs to a hailing pirate, answer
 * it and return TRUE; FALSE falls through to the normal holo-call path.
 */
/obj/machinery/holopad/proc/voidcrew_try_answer_hail(pirate_ref, mob/user)
	if(!pirate_ref)
		return FALSE
	var/obj/structure/overmap/ship/npc/pirate/pirate = locate(pirate_ref) in SSnpc_ships.active_ships
	if(!istype(pirate))
		return FALSE
	answer_hail(pirate, user)
	return TRUE // ref was a pirate: consume the action even if answering failed (user got feedback)

/**
 * Answer a hail from a pirate ship that is already trying to contact us.
 * Transitions pirate from HAILING to NEGOTIATING state.
 */
/obj/machinery/holopad/proc/answer_hail(obj/structure/overmap/ship/npc/pirate/pirate, mob/user)
	var/obj/structure/overmap/ship/our_ship = voidcrew_comms_ship()
	if(!pirate || !our_ship)
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

	if(controller.get_target() != our_ship)
		to_chat(user, span_warning("[pirate.name] is not hailing us."))
		return FALSE

	// Create negotiation
	var/datum/pirate_negotiation/negotiation = new(pirate, our_ship, src)
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
	our_ship.stop_hail_ringing()

	to_chat(user, span_notice("Connection established with [pirate.name]."))
	return TRUE

// ===== HELPERS =====

/**
 * Called when a negotiation hologram is placed on this pad. The hologram is
 * managed by the negotiation datum; we just light up.
 */
/obj/machinery/holopad/proc/on_negotiation_hologram_set(obj/effect/overlay/holo_pad_hologram/holo)
	if(!holo)
		return
	SetLightsAndPower()
	if(active_negotiation)
		set_light(2) // negotiation hologram isn't in masters, light the pad ourselves
	update_appearance()

/// Extra examine lines for hail/negotiation state (hooked from holopad examine()).
/obj/machinery/holopad/proc/voidcrew_comms_examine()
	. = list()
	if(active_negotiation)
		. += span_notice("Currently in negotiation with [active_negotiation.pirate_ship?.name].")
		. += span_notice("Click the hologram to interact.")
		return

	var/list/hailing = get_hailing_pirates()
	if(!length(hailing))
		return
	. += span_boldwarning("INCOMING HAIL from [length(hailing)] vessel(s)!")
	for(var/obj/structure/overmap/ship/npc/pirate/pirate as anything in hailing)
		. += span_warning("- [pirate.name] is hailing!")
	. += span_notice("Answer via the holopad interface.")
