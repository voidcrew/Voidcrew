/**
 * Pirate Negotiation Datum
 *
 * Manages the state of a negotiation between a player ship and a pirate ship.
 * Pirates demand either credits OR a specific item - no bartering.
 */
/datum/pirate_negotiation
	/// The pirate ship we're negotiating with
	var/obj/structure/overmap/ship/npc/pirate/pirate_ship
	/// The player ship being extorted
	var/obj/structure/overmap/ship/player_ship
	/// The holopad displaying the negotiation
	var/obj/machinery/holopad/holopad
	/// The hologram of the pirate captain
	var/obj/effect/overlay/holo_pad_hologram/pirate/hologram
	/// Mission pads linked for tribute delivery (all pads on player ship)
	var/list/obj/machinery/mission_pad/tribute_pads = list()

	/// Current negotiation state
	var/negotiation_state = NEGOTIATION_PENDING
	/// World.time when negotiation started
	var/time_started
	/// Timer ID for timeout
	var/timeout_timer_id
	/// How long before pirate loses patience (modified by faction)
	var/timeout_duration = NEGOTIATION_DEFAULT_TIMEOUT

	/// Credits demanded by the pirate
	var/demanded_credits = 0

	/// Item demand - the specific item type demanded
	var/demanded_item_type
	/// Item demand - quantity needed
	var/demanded_item_quantity = 0
	/// Item demand - quantity received so far
	var/items_received = 0
	/// Item demand - display name for the item
	var/demanded_item_name = ""

	/// TRUE when the target's accounts came back empty and we hailed them anyway.
	/// Credits are off the table entirely; only cargo settles this.
	var/barter_only = FALSE
	/// How many impatience warnings we've sent, so the barter demand can escalate
	/// once the crew has stalled past the first one.
	var/warnings_sent = 0
	/// Whether the barter demand has already been raised for stalling (once only).
	var/barter_escalated = FALSE

	/// Faction dialog handler for personality
	var/datum/pirate_faction_dialog/dialog

	/// Whether this negotiation prevents the fight from starting (vs stopping mid-fight)
	var/preemptive = FALSE

	/// Cooldown for rejection messages to prevent spam
	COOLDOWN_DECLARE(rejection_message_cooldown)
	/// Cooldown for progress messages to prevent spam
	COOLDOWN_DECLARE(progress_message_cooldown)

	/// Whether the player has already tried to flee once (next attempt = combat)
	var/caught_fleeing = FALSE
	/// Multiplier applied to demand when caught fleeing
	var/flee_penalty_multiplier = 1.5

/datum/pirate_negotiation/New(obj/structure/overmap/ship/npc/pirate/pirate, obj/structure/overmap/ship/player, obj/machinery/holopad/pad)
	. = ..()
	if(!pirate || !player || !pad)
		qdel(src)
		return

	pirate_ship = pirate
	player_ship = player
	holopad = pad

	// The AI flags a hail raised against an empty account - that negotiation is
	// settled in cargo, not credits.
	var/datum/ai_controller/npc_ship/hailing_controller = pirate.ai_controller
	barter_only = !!hailing_controller?.blackboard[BB_NPC_BROKE_BARTER]

	// Get faction dialog type from pirate ship
	var/dialog_type = pirate.negotiation_dialog_type || /datum/pirate_faction_dialog
	dialog = new dialog_type()

	// Apply faction patience modifier to timeout
	timeout_duration = NEGOTIATION_DEFAULT_TIMEOUT * dialog.patience_modifier

	// Register for cleanup signals
	RegisterSignal(pirate_ship, COMSIG_QDELETING, PROC_REF(on_pirate_destroyed))
	RegisterSignal(player_ship, COMSIG_QDELETING, PROC_REF(on_player_destroyed))
	RegisterSignal(holopad, COMSIG_QDELETING, PROC_REF(on_holopad_destroyed))

	// Register for player ship movement - moving during negotiation breaks the deal!
	RegisterSignal(player_ship, COMSIG_VOIDCREW_SHIP_MOVED, PROC_REF(on_player_ship_moved))

/datum/pirate_negotiation/Destroy()
	// Clean up hologram
	if(hologram)
		QDEL_NULL(hologram)

	// Unlink from mission pads
	for(var/obj/machinery/mission_pad/pad as anything in tribute_pads)
		pad.tribute_negotiation = null
	tribute_pads.Cut()

	// Unregister signals
	if(pirate_ship)
		UnregisterSignal(pirate_ship, COMSIG_QDELETING)
	if(player_ship)
		UnregisterSignal(player_ship, list(COMSIG_QDELETING, COMSIG_VOIDCREW_SHIP_MOVED))
	if(holopad)
		UnregisterSignal(holopad, COMSIG_QDELETING)
		holopad.active_negotiation = null
		holopad.SetLightsAndPower() // restore baseline lighting (negotiation lit the pad manually)
		holopad.update_appearance(UPDATE_ICON_STATE)

	// Cancel timeout timer
	if(timeout_timer_id)
		deltimer(timeout_timer_id)
		timeout_timer_id = null

	// Clean up dialog
	QDEL_NULL(dialog)

	pirate_ship = null
	player_ship = null
	holopad = null

	return ..()

// ========== SIGNAL HANDLERS ==========

/datum/pirate_negotiation/proc/on_pirate_destroyed(datum/source)
	SIGNAL_HANDLER
	// Pirate destroyed during negotiation - player wins!
	end_negotiation(success = TRUE, reason = "pirate_destroyed")

/datum/pirate_negotiation/proc/on_player_destroyed(datum/source)
	SIGNAL_HANDLER
	// Player destroyed during negotiation - cleanup only
	qdel(src)

/datum/pirate_negotiation/proc/on_holopad_destroyed(datum/source)
	SIGNAL_HANDLER
	// Holopad destroyed - negotiation fails
	end_negotiation(success = FALSE, reason = "holopad_destroyed")

/datum/pirate_negotiation/proc/on_player_ship_moved(datum/source)
	SIGNAL_HANDLER
	// Player ship moved during active negotiation - pirate sees this as betrayal!
	if(negotiation_state != NEGOTIATION_ACTIVE && negotiation_state != NEGOTIATION_PAYING)
		return  // Only fail during active negotiation, not during setup/cleanup

	INVOKE_ASYNC(src, PROC_REF(fail_due_to_movement))

/**
 * Called when the player ship moves during negotiation.
 * First attempt: Interdict + increase demand + warning
 * Second attempt: Open fire, end negotiation
 */
/datum/pirate_negotiation/proc/fail_due_to_movement()
	var/datum/ai_controller/npc_ship/controller = pirate_ship?.ai_controller

	if(!caught_fleeing)
		// First attempt - interdict and increase demand
		caught_fleeing = TRUE

		// Interdict the player immediately
		var/datum/npc_combat_interface/combat = controller?.get_combat_interface()
		if(combat && player_ship)
			combat.start_interdiction(player_ship)

		// Increase the demand as penalty
		var/old_demand = demanded_credits
		demanded_credits = round(demanded_credits * flee_penalty_multiplier, 100)

		// Announce the warning (not full betrayal yet)
		pirate_say(dialog.get_flee_warning_line())

		// Notify player of the penalty
		player_ship?.ship_notify("[pirate_ship?.name] has interdicted your ship! Tribute demand increased from [old_demand] to [demanded_credits] credits!", "NEGOTIATION", SHIP_NOTIFY_DANGER, 'voidcrew/sound/alert3.ogg', 25)
	else
		// Second attempt - they didn't learn, open fire
		pirate_say(dialog.get_movement_betrayal_line(is_siphon_shakedown()))

		// Announce to player ship
		player_ship?.ship_notify("[pirate_ship?.name] is opening fire - you tried to flee twice!", "COMBAT", SHIP_NOTIFY_DANGER, 'voidcrew/sound/alert3.ogg', 25)

		// End negotiation as failure - go to combat
		end_negotiation(success = FALSE, reason = "player_moved")

// ========== NEGOTIATION FLOW ==========

/**
 * TRUE when the threat behind this negotiation is the data siphon rather than
 * guns or a boarding party - a yellow-band shakedown.
 *
 * Read live off the AI, the same call it makes when it escalates, so the dialog
 * can never promise a broadside the band forbids the pirate from firing.
 */
/datum/pirate_negotiation/proc/is_siphon_shakedown()
	var/datum/ai_controller/npc_ship/controller = pirate_ship?.ai_controller
	return controller?.hail_escalates_to_siphon()

/**
 * Calculate the tribute demand based on player wealth, combat state, and faction.
 * Also picks a random item demand as an alternative.
 */
/datum/pirate_negotiation/proc/calculate_demand()
	// Barter negotiations skip the credit maths entirely - we already scanned this
	// ship and found nothing worth taking, so quoting them a price would just be a
	// demand they cannot meet.
	if(barter_only)
		demanded_credits = 0
		var/list/barter_demand = length(pirate_ship.fixed_item_demand) ? pirate_ship.fixed_item_demand : pick_pirate_item_demand()
		if(barter_demand && length(barter_demand) >= 3)
			demanded_item_type = barter_demand[1]
			demanded_item_quantity = barter_demand[2]
			demanded_item_name = barter_demand[3]
		return

	var/base_demand = 0

	// Factor 1: Player ship wealth (25% of their balance) - expensive!
	var/player_wealth = player_ship.ship_account?.account_balance || 0
	base_demand = player_wealth * 0.25

	// Factor 2: Combat state modifier
	var/datum/ai_controller/npc_ship/controller = pirate_ship.ai_controller
	if(controller)
		switch(controller.get_combat_state())
			if(NPC_COMBAT_IDLE, NPC_COMBAT_SCANNING)
				base_demand *= 0.8  // Cheaper to pay before combat
				preemptive = TRUE
			if(NPC_COMBAT_HAILING)
				// A yellow-band shakedown is bidding against its own siphon, which
				// takes the same 25% by force if the crew stonewalls it. Undercut
				// that so answering the hail is the cheaper way out.
				if(controller.hail_escalates_to_siphon())
					base_demand *= 0.8
					preemptive = TRUE
			if(NPC_COMBAT_ENGAGING)
				base_demand *= 1.0  // Standard rate
			if(NPC_COMBAT_COMBAT)
				base_demand *= 1.5  // Premium to stop active fight

	// Factor 3: Faction demand multiplier
	if(dialog)
		base_demand *= dialog.demand_multiplier

	// Factor 4: Damaged pirates are more willing to negotiate
	var/health_percent = pirate_ship.get_integrity_percent()
	if(health_percent < 50)
		base_demand *= 0.7

	// Clamp to configured min/max and round to nice numbers
	var/min_demand = pirate_ship.min_negotiation_demand
	var/max_demand = pirate_ship.max_negotiation_demand
	demanded_credits = clamp(round(base_demand, 100), min_demand, max_demand)

	// Ensure minimum demand
	if(demanded_credits < min_demand)
		demanded_credits = min_demand

	// Pick a random item demand as alternative; ships with a fixed demand
	// (customs patrols after specific contraband) always ask for that instead
	var/list/item_demand = length(pirate_ship.fixed_item_demand) ? pirate_ship.fixed_item_demand : pick_pirate_item_demand()
	if(item_demand && length(item_demand) >= 3)
		demanded_item_type = item_demand[1]
		demanded_item_quantity = item_demand[2]
		demanded_item_name = item_demand[3]

/**
 * Start the negotiation - spawn hologram, pause pirate AI, begin timeout.
 */
/datum/pirate_negotiation/proc/start_negotiation()
	if(negotiation_state != NEGOTIATION_PENDING)
		return FALSE

	// Calculate what we're demanding
	calculate_demand()

	// A barter negotiation with nothing to ask for has no way to succeed, so don't
	// open one - let the caller fall through to the boarding path instead.
	if(barter_only && !demanded_item_type)
		return FALSE

	// Tell the pirate AI to pause
	var/datum/ai_controller/npc_ship/controller = pirate_ship.ai_controller
	if(controller)
		controller.enter_negotiation(src)

	// Create the hologram
	spawn_hologram()

	// Link all mission pads for item delivery
	link_ship_mission_pads()

	// Start the timeout timer
	time_started = world.time
	timeout_timer_id = addtimer(CALLBACK(src, PROC_REF(on_timeout)), timeout_duration, TIMER_STOPPABLE)

	// Schedule warning messages
	for(var/warning_time in NEGOTIATION_WARNING_TIMES)
		var/delay = timeout_duration - (warning_time SECONDS)
		if(delay > 0)
			addtimer(CALLBACK(src, PROC_REF(send_timeout_warning), warning_time), delay)

	negotiation_state = NEGOTIATION_ACTIVE

	// Send signals
	SEND_SIGNAL(pirate_ship, COMSIG_NEGOTIATION_STARTED, src)
	SEND_SIGNAL(player_ship, COMSIG_SHIP_HAILED, src)

	// Pirate announces their demands
	if(barter_only)
		pirate_say(dialog.get_barter_demand_line(demanded_item_quantity, demanded_item_name))
	else
		pirate_say(dialog.get_demand_line(demanded_credits, demanded_item_quantity, demanded_item_name))

	// After a brief pause, warn about escape attempts
	addtimer(CALLBACK(src, PROC_REF(say_escape_warning)), 3 SECONDS)

	return TRUE

/**
 * Link all mission pads on the player ship.
 */
/datum/pirate_negotiation/proc/link_ship_mission_pads()
	if(!player_ship)
		return

	// Use the ship's registered mission pads
	if(length(player_ship.linked_mission_pads))
		for(var/obj/machinery/mission_pad/pad as anything in player_ship.linked_mission_pads)
			link_mission_pad(pad)
		return

	// Fallback: search through shuttle areas (in case pads haven't registered yet)
	if(player_ship.shuttle?.shuttle_areas)
		for(var/area/ship_area as anything in player_ship.shuttle.shuttle_areas)
			for(var/obj/machinery/mission_pad/found_pad in ship_area)
				link_mission_pad(found_pad)

/**
 * Spawn the pirate hologram on the holopad.
 */
/datum/pirate_negotiation/proc/spawn_hologram()
	if(!holopad)
		return

	// Create pirate hologram
	hologram = new /obj/effect/overlay/holo_pad_hologram/pirate(get_turf(holopad))
	hologram.negotiation = src
	hologram.set_faction_appearance(pirate_ship.pirate_faction)

	// Link hologram to holopad for visual effects
	holopad.on_negotiation_hologram_set(hologram)

	// Play hologram activation sound
	playsound(holopad, 'voidcrew/sound/hologram_on.ogg', 80, FALSE)

/**
 * End the negotiation with success or failure.
 */
/datum/pirate_negotiation/proc/end_negotiation(success = FALSE, reason = "unknown")
	if(negotiation_state == NEGOTIATION_ACCEPTED || negotiation_state == NEGOTIATION_REJECTED)
		return  // Already ended

	// Cancel timeout
	if(timeout_timer_id)
		deltimer(timeout_timer_id)
		timeout_timer_id = null

	// Update state
	negotiation_state = success ? NEGOTIATION_ACCEPTED : NEGOTIATION_REJECTED

	// Grant immunity BEFORE telling AI to disengage (prevents immediate re-targeting)
	if(success)
		grant_tribute_immunity()
	else
		// Mark this ship as having failed negotiation - no second chances
		mark_negotiation_failed()

	// Tell the pirate AI to resume or disengage
	var/datum/ai_controller/npc_ship/controller = pirate_ship?.ai_controller
	if(controller)
		controller.exit_negotiation(success, reason)

	// Final message from pirate
	if(success)
		pirate_say(dialog.get_acceptance_line())
		// Notify player ship crew that pirates have disengaged
		player_ship?.ship_notify("[pirate_ship.name] has accepted tribute and is disengaging.", "COMMS", SHIP_NOTIFY_NOTICE, 'voidcrew/sound/notify.ogg', 50)
	else
		if(reason == "timeout")
			pirate_say(dialog.get_timeout_line(is_siphon_shakedown()))
		else if(reason == "refused")
			pirate_say(dialog.get_rejection_line(is_siphon_shakedown()))
		// else silent failure (destroyed, etc.)

	// Send signal
	SEND_SIGNAL(pirate_ship, COMSIG_NEGOTIATION_ENDED, src, success)

	// Cleanup after a short delay so player can see final message
	QDEL_IN(src, 3 SECONDS)

/**
 * Called when negotiation times out.
 */
/datum/pirate_negotiation/proc/on_timeout()
	timeout_timer_id = null
	negotiation_state = NEGOTIATION_TIMEOUT
	end_negotiation(success = FALSE, reason = "timeout")

/**
 * Send a warning that timeout is approaching.
 */
/datum/pirate_negotiation/proc/send_timeout_warning(seconds_remaining)
	if(negotiation_state != NEGOTIATION_ACTIVE && negotiation_state != NEGOTIATION_PAYING)
		return

	warnings_sent++

	// Stalling a barter costs you. Once you've let a warning go by without putting
	// anything on the pad, the price of walking away goes up by a unit.
	if(try_escalate_barter_demand())
		return

	pirate_say(dialog.get_impatience_line(seconds_remaining))

/**
 * Raise a barter demand when the crew stalls past the first impatience warning
 * without handing anything over. Happens at most once per negotiation.
 * Returns TRUE if the demand was escalated (and announced).
 */
/datum/pirate_negotiation/proc/try_escalate_barter_demand()
	if(!barter_only || barter_escalated)
		return FALSE
	if(warnings_sent < NEGOTIATION_BARTER_ESCALATE_WARNING)
		return FALSE
	// Handing over part of the demand counts as cooperating - don't punish that.
	if(items_received > 0)
		return FALSE

	barter_escalated = TRUE
	demanded_item_quantity += NEGOTIATION_BARTER_ESCALATE_AMOUNT

	pirate_say(dialog.get_barter_escalation_line(get_remaining_items(), demanded_item_name))
	player_ship?.ship_notify("[pirate_ship.name] has raised their demand to [demanded_item_quantity] [demanded_item_name].", "COMMS", SHIP_NOTIFY_WARNING, 'voidcrew/sound/warn4.ogg', 25)
	return TRUE

// ========== PAYMENT HANDLING ==========

/**
 * Process a credit payment from the player.
 * Returns TRUE if payment was accepted.
 */
/datum/pirate_negotiation/proc/process_credit_payment()
	if(negotiation_state != NEGOTIATION_ACTIVE && negotiation_state != NEGOTIATION_PAYING)
		return FALSE

	// We scanned their accounts and came up empty - this one is settled in cargo.
	if(barter_only)
		if(COOLDOWN_FINISHED(src, rejection_message_cooldown))
			pirate_say("Keep your pocket change. I want [get_remaining_items()] [demanded_item_name].")
			COOLDOWN_START(src, rejection_message_cooldown, 2 SECONDS)
		return FALSE

	// Deduct from player account
	if(!player_ship.ship_account?.has_money(demanded_credits))
		return FALSE

	player_ship.ship_account.adjust_money(-demanded_credits)
	// The tribute goes into the pirate's hold rather than out of the economy, so a
	// crew that pays up and then wins the rematch can siphon its own money back
	pirate_ship?.ship_account?.adjust_money(demanded_credits, "Hold: tribute from [player_ship.name]")

	// Payment complete!
	end_negotiation(success = TRUE, reason = "payment_complete")
	return TRUE

/**
 * Process an item as payment.
 * Returns TRUE if item was accepted, FALSE otherwise.
 */
/datum/pirate_negotiation/proc/process_item_payment(obj/item/item)
	if(negotiation_state != NEGOTIATION_ACTIVE && negotiation_state != NEGOTIATION_PAYING)
		return FALSE

	if(!demanded_item_type)
		return FALSE

	// Check if item matches demanded type
	if(!istype(item, demanded_item_type))
		// Debounce rejection messages to prevent spam when stacks are dropped
		if(COOLDOWN_FINISHED(src, rejection_message_cooldown))
			pirate_say("That's not what I asked for. I want [demanded_item_name]!")
			COOLDOWN_START(src, rejection_message_cooldown, 2 SECONDS)
		return FALSE

	// Get amount (stacks vs single items)
	var/amount = get_item_stack_amount(item)
	items_received += amount

	// Accept the item - teleport it away (use first available pad for effect)
	var/obj/machinery/mission_pad/effect_pad = length(tribute_pads) ? tribute_pads[1] : null
	effect_pad?.do_teleport_effect()
	qdel(item)

	// Check if fully paid
	if(items_received >= demanded_item_quantity)
		// end_negotiation handles the acceptance message
		end_negotiation(success = TRUE, reason = "payment_complete")
	else if(COOLDOWN_FINISHED(src, progress_message_cooldown))
		// Debounce progress messages to prevent spam when stacks are dropped
		var/remaining = demanded_item_quantity - items_received
		pirate_say("Good. [remaining] more [demanded_item_name] to go.")
		COOLDOWN_START(src, progress_message_cooldown, 1 SECONDS)

	return TRUE

/**
 * Get remaining items needed.
 */
/datum/pirate_negotiation/proc/get_remaining_items()
	return max(0, demanded_item_quantity - items_received)

// ========== TRIBUTE IMMUNITY ==========

/**
 * Grant the player ship immunity from this pirate for a period.
 */
/datum/pirate_negotiation/proc/grant_tribute_immunity()
	var/datum/ai_controller/npc_ship/controller = pirate_ship?.ai_controller
	if(!controller)
		return

	// Add to paid ships list
	var/list/paid_ships = controller.blackboard[BB_NPC_PAID_TRIBUTE_SHIPS]
	if(!paid_ships)
		paid_ships = list()
		controller.set_blackboard_key(BB_NPC_PAID_TRIBUTE_SHIPS, paid_ships)

	paid_ships[REF(player_ship)] = world.time + NEGOTIATION_IMMUNITY_DURATION

/**
 * Mark the player ship as having failed negotiation - no second chances.
 */
/datum/pirate_negotiation/proc/mark_negotiation_failed()
	var/datum/ai_controller/npc_ship/controller = pirate_ship?.ai_controller
	if(!controller)
		return

	// Add to failed negotiation ships list - permanent for this encounter
	var/list/failed_ships = controller.blackboard[BB_NPC_FAILED_NEGOTIATION_SHIPS]
	if(!failed_ships)
		failed_ships = list()
		controller.set_blackboard_key(BB_NPC_FAILED_NEGOTIATION_SHIPS, failed_ships)

	failed_ships[REF(player_ship)] = TRUE

// ========== HOLOGRAM SPEECH ==========

/**
 * Make the pirate hologram speak via runechat bubble.
 * The dialogue appears above the hologram, not in ship chat.
 */
/datum/pirate_negotiation/proc/pirate_say(message)
	if(!message)
		return
	if(hologram)
		hologram.pirate_say(message)

/**
 * Say the escape warning (called after demand with a delay).
 */
/datum/pirate_negotiation/proc/say_escape_warning()
	if(negotiation_state != NEGOTIATION_ACTIVE)
		return  // Negotiation ended before warning
	if(!dialog)
		return
	pirate_say(dialog.get_escape_warning_line(is_siphon_shakedown()))

// ========== MISSION PAD LINKING ==========

/**
 * Link a mission pad for tribute delivery.
 */
/datum/pirate_negotiation/proc/link_mission_pad(obj/machinery/mission_pad/pad)
	if(!pad || (pad in tribute_pads))
		return
	tribute_pads += pad
	pad.tribute_negotiation = src

/**
 * Unlink a specific mission pad.
 */
/datum/pirate_negotiation/proc/unlink_mission_pad(obj/machinery/mission_pad/pad)
	if(!pad || !(pad in tribute_pads))
		return
	pad.tribute_negotiation = null
	tribute_pads -= pad

/**
 * Unlink all mission pads.
 */
/datum/pirate_negotiation/proc/unlink_all_mission_pads()
	for(var/obj/machinery/mission_pad/pad as anything in tribute_pads)
		pad.tribute_negotiation = null
	tribute_pads.Cut()
