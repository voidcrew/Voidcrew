/**
 * Pirate Negotiation Datum
 *
 * Manages the state of a negotiation between a player ship and a pirate ship.
 * Handles demand calculation, payment processing, timeouts, and cleanup.
 */
/datum/pirate_negotiation
	/// The pirate ship we're negotiating with
	var/obj/structure/overmap/ship/npc/pirate/pirate_ship
	/// The player ship being extorted
	var/obj/structure/overmap/ship/player_ship
	/// The holopad displaying the negotiation
	var/obj/machinery/holopad/ship_comms/holopad
	/// The hologram of the pirate captain
	var/obj/effect/overlay/holo_pad_hologram/pirate/hologram
	/// The mission pad linked for tribute delivery
	var/obj/machinery/mission_pad/tribute_pad

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
	/// Credits received so far
	var/credits_received = 0
	/// Cargo value received so far
	var/cargo_value_received = 0

	/// Faction dialog handler for personality
	var/datum/pirate_faction_dialog/dialog

	/// Whether this negotiation prevents the fight from starting (vs stopping mid-fight)
	var/preemptive = FALSE

/datum/pirate_negotiation/New(obj/structure/overmap/ship/npc/pirate/pirate, obj/structure/overmap/ship/player, obj/machinery/holopad/ship_comms/pad)
	. = ..()
	if(!pirate || !player || !pad)
		qdel(src)
		return

	pirate_ship = pirate
	player_ship = player
	holopad = pad

	// Get faction dialog type from pirate ship
	var/dialog_type = pirate.negotiation_dialog_type || /datum/pirate_faction_dialog
	dialog = new dialog_type()

	// Apply faction patience modifier to timeout
	timeout_duration = NEGOTIATION_DEFAULT_TIMEOUT * dialog.patience_modifier

	// Register for cleanup signals
	RegisterSignal(pirate_ship, COMSIG_QDELETING, PROC_REF(on_pirate_destroyed))
	RegisterSignal(player_ship, COMSIG_QDELETING, PROC_REF(on_player_destroyed))
	RegisterSignal(holopad, COMSIG_QDELETING, PROC_REF(on_holopad_destroyed))

/datum/pirate_negotiation/Destroy()
	// Clean up hologram
	if(hologram)
		QDEL_NULL(hologram)

	// Unlink from mission pad
	if(tribute_pad)
		tribute_pad.tribute_negotiation = null
		tribute_pad = null

	// Unregister signals
	if(pirate_ship)
		UnregisterSignal(pirate_ship, COMSIG_QDELETING)
	if(player_ship)
		UnregisterSignal(player_ship, COMSIG_QDELETING)
	if(holopad)
		UnregisterSignal(holopad, COMSIG_QDELETING)
		holopad.active_negotiation = null

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

// ========== NEGOTIATION FLOW ==========

/**
 * Calculate the tribute demand based on player wealth, combat state, and faction.
 */
/datum/pirate_negotiation/proc/calculate_demand()
	var/base_demand = 0

	// Factor 1: Player ship wealth (15% of their balance)
	var/player_wealth = player_ship.ship_account?.account_balance || 0
	base_demand = player_wealth * 0.15

	// Factor 2: Combat state modifier
	var/datum/ai_controller/npc_ship/controller = pirate_ship.ai_controller
	if(controller)
		switch(controller.get_combat_state())
			if(NPC_COMBAT_IDLE, NPC_COMBAT_SCANNING)
				base_demand *= 0.8  // Cheaper to pay before combat
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

/**
 * Start the negotiation - spawn hologram, pause pirate AI, begin timeout.
 */
/datum/pirate_negotiation/proc/start_negotiation()
	if(negotiation_state != NEGOTIATION_PENDING)
		return FALSE

	// Calculate what we're demanding
	calculate_demand()

	// Tell the pirate AI to pause
	var/datum/ai_controller/npc_ship/controller = pirate_ship.ai_controller
	if(controller)
		controller.enter_negotiation(src)

	// Create the hologram
	spawn_hologram()

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

	// Pirate announces their demand
	pirate_say(dialog.get_demand_line(demanded_credits))

	return TRUE

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

	// Tell the pirate AI to resume or disengage
	var/datum/ai_controller/npc_ship/controller = pirate_ship?.ai_controller
	if(controller)
		controller.exit_negotiation(success)

	// Final message from pirate
	if(success)
		pirate_say(dialog.get_acceptance_line())
		// Grant immunity
		grant_tribute_immunity()
	else
		if(reason == "timeout")
			pirate_say(dialog.get_timeout_line())
		else if(reason == "refused")
			pirate_say(dialog.get_rejection_line())
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
	pirate_say(dialog.get_impatience_line(seconds_remaining))

// ========== PAYMENT HANDLING ==========

/**
 * Process a credit payment from the player.
 * Returns TRUE if payment was accepted.
 */
/datum/pirate_negotiation/proc/process_credit_payment(amount)
	if(negotiation_state != NEGOTIATION_ACTIVE && negotiation_state != NEGOTIATION_PAYING)
		return FALSE

	if(amount <= 0)
		return FALSE

	// Deduct from player account
	if(!player_ship.ship_account?.has_money(amount))
		return FALSE

	player_ship.ship_account.adjust_money(-amount)
	credits_received += amount

	// Notify
	SEND_SIGNAL(src, COMSIG_NEGOTIATION_PAYMENT, amount, FALSE)

	// Check if fully paid
	check_payment_complete()
	return TRUE

/**
 * Process a cargo item as payment.
 * Returns the value credited, or 0 if item not accepted.
 */
/datum/pirate_negotiation/proc/process_cargo_payment(obj/item/item)
	if(negotiation_state != NEGOTIATION_ACTIVE && negotiation_state != NEGOTIATION_PAYING)
		return 0

	if(!dialog.accepts_cargo)
		pirate_say(dialog.get_cargo_rejection_line())
		return 0

	var/value = evaluate_cargo_value(item)
	if(value <= 0)
		return 0

	// Accept the cargo - teleport it away
	cargo_value_received += value
	tribute_pad?.do_teleport_effect()
	qdel(item)

	// Acknowledge receipt
	pirate_say(dialog.get_payment_received_line(value))

	// Notify
	SEND_SIGNAL(src, COMSIG_NEGOTIATION_PAYMENT, value, TRUE)

	// Check if fully paid
	check_payment_complete()
	return value

/**
 * Evaluate the tribute value of a cargo item.
 * Uses the global get_pirate_tribute_value helper.
 */
/datum/pirate_negotiation/proc/evaluate_cargo_value(obj/item/item)
	return get_pirate_tribute_value(item)

/**
 * Check if total payment meets demand.
 */
/datum/pirate_negotiation/proc/check_payment_complete()
	var/total_paid = credits_received + cargo_value_received
	if(total_paid >= demanded_credits)
		negotiation_state = NEGOTIATION_ACCEPTED
		end_negotiation(success = TRUE, reason = "payment_complete")

/**
 * Get the remaining amount needed.
 */
/datum/pirate_negotiation/proc/get_remaining_demand()
	var/total_paid = credits_received + cargo_value_received
	return max(0, demanded_credits - total_paid)

/**
 * Get payment progress as a percentage (0-100).
 */
/datum/pirate_negotiation/proc/get_payment_progress()
	if(demanded_credits <= 0)
		return 100
	var/total_paid = credits_received + cargo_value_received
	return clamp((total_paid / demanded_credits) * 100, 0, 100)

// ========== COUNTER-OFFERS ==========

/**
 * Player makes a counter-offer. Returns TRUE if accepted.
 */
/datum/pirate_negotiation/proc/accept_counter_offer(offered_amount)
	if(negotiation_state != NEGOTIATION_ACTIVE)
		return FALSE

	if(!dialog.accepts_counter_offer)
		pirate_say(dialog.get_counter_rejection_line())
		return FALSE

	// Accept if offer is at least 60% of demand
	var/minimum_acceptable = demanded_credits * 0.6
	if(offered_amount >= minimum_acceptable)
		demanded_credits = offered_amount
		pirate_say(dialog.get_counter_acceptance_line(offered_amount))
		// Reset timeout since they're engaging
		reset_timeout()
		return TRUE
	else
		// Reject but give them a final offer
		var/final_offer = round(demanded_credits * 0.8, 100)
		demanded_credits = final_offer
		pirate_say(dialog.get_counter_final_offer_line(final_offer))
		return FALSE

/**
 * Reset the timeout timer (called when player is actively engaging).
 */
/datum/pirate_negotiation/proc/reset_timeout()
	if(timeout_timer_id)
		deltimer(timeout_timer_id)
	timeout_timer_id = addtimer(CALLBACK(src, PROC_REF(on_timeout)), timeout_duration, TIMER_STOPPABLE)

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

// ========== HOLOGRAM SPEECH ==========

/**
 * Make the pirate hologram speak.
 */
/datum/pirate_negotiation/proc/pirate_say(message)
	if(!message)
		return
	if(hologram)
		hologram.pirate_say(message)
	// Also announce on ship comms
	player_ship?.ship_announce("[pirate_ship.name]: [message]", "Incoming Transmission")

// ========== MISSION PAD LINKING ==========

/**
 * Link a mission pad for tribute delivery.
 */
/datum/pirate_negotiation/proc/link_mission_pad(obj/machinery/mission_pad/pad)
	if(tribute_pad)
		tribute_pad.tribute_negotiation = null
	tribute_pad = pad
	if(pad)
		pad.tribute_negotiation = src

/**
 * Unlink the mission pad.
 */
/datum/pirate_negotiation/proc/unlink_mission_pad()
	if(tribute_pad)
		tribute_pad.tribute_negotiation = null
		tribute_pad = null
