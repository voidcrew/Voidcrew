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

	/// Item demand - the specific item type demanded
	var/demanded_item_type
	/// Item demand - quantity needed
	var/demanded_item_quantity = 0
	/// Item demand - quantity received so far
	var/items_received = 0
	/// Item demand - display name for the item
	var/demanded_item_name = ""

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

	// Register for player ship movement - moving during negotiation breaks the deal!
	RegisterSignal(player_ship, COMSIG_VOIDCREW_SHIP_MOVED, PROC_REF(on_player_ship_moved))

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
		UnregisterSignal(player_ship, list(COMSIG_QDELETING, COMSIG_VOIDCREW_SHIP_MOVED))
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

/datum/pirate_negotiation/proc/on_player_ship_moved(datum/source)
	SIGNAL_HANDLER
	// Player ship moved during active negotiation - pirate sees this as betrayal!
	if(negotiation_state != NEGOTIATION_ACTIVE && negotiation_state != NEGOTIATION_PAYING)
		return  // Only fail during active negotiation, not during setup/cleanup

	INVOKE_ASYNC(src, PROC_REF(fail_due_to_movement))

/**
 * Called when the player ship moves during negotiation - this breaks the deal.
 */
/datum/pirate_negotiation/proc/fail_due_to_movement()
	// Announce the betrayal
	pirate_say(dialog.get_movement_betrayal_line())

	// Announce to player ship
	player_ship?.ship_announce(
		"Negotiations with [pirate_ship?.name] have FAILED - they detected your ship movement!",
		"NEGOTIATION FAILED",
		FALSE,
		sound('sound/effects/alert.ogg')
	)

	// End negotiation as failure
	end_negotiation(success = FALSE, reason = "player_moved")

// ========== NEGOTIATION FLOW ==========

/**
 * Calculate the tribute demand based on player wealth, combat state, and faction.
 * Also picks a random item demand as an alternative.
 */
/datum/pirate_negotiation/proc/calculate_demand()
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

	// Pick a random item demand as alternative
	var/list/item_demand = pick_pirate_item_demand()
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

	// Tell the pirate AI to pause
	var/datum/ai_controller/npc_ship/controller = pirate_ship.ai_controller
	if(controller)
		controller.enter_negotiation(src)

	// Create the hologram
	spawn_hologram()

	// Link mission pad for item delivery
	link_nearest_mission_pad()

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
	pirate_say(dialog.get_demand_line(demanded_credits, demanded_item_quantity, demanded_item_name))

	return TRUE

/**
 * Link the nearest mission pad on the player ship.
 */
/datum/pirate_negotiation/proc/link_nearest_mission_pad()
	if(!player_ship?.shuttle?.shuttle_areas)
		return

	// Search through all shuttle areas for a mission pad
	for(var/area/ship_area as anything in player_ship.shuttle.shuttle_areas)
		for(var/obj/machinery/mission_pad/found_pad in ship_area)
			link_mission_pad(found_pad)
			return  // Found one, we're done

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

	// Grant immunity BEFORE telling AI to disengage (prevents immediate re-targeting)
	if(success)
		grant_tribute_immunity()

	// Tell the pirate AI to resume or disengage
	var/datum/ai_controller/npc_ship/controller = pirate_ship?.ai_controller
	if(controller)
		controller.exit_negotiation(success)

	// Final message from pirate
	if(success)
		pirate_say(dialog.get_acceptance_line())
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
/datum/pirate_negotiation/proc/process_credit_payment()
	if(negotiation_state != NEGOTIATION_ACTIVE && negotiation_state != NEGOTIATION_PAYING)
		return FALSE

	// Deduct from player account
	if(!player_ship.ship_account?.has_money(demanded_credits))
		return FALSE

	player_ship.ship_account.adjust_money(-demanded_credits)

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
		pirate_say("That's not what I asked for. I want [demanded_item_name]!")
		return FALSE

	// Get amount (stacks vs single items)
	var/amount = get_item_stack_amount(item)
	items_received += amount

	// Accept the item - teleport it away
	tribute_pad?.do_teleport_effect()
	qdel(item)

	// Check if fully paid
	if(items_received >= demanded_item_quantity)
		pirate_say(dialog.get_acceptance_line())
		end_negotiation(success = TRUE, reason = "payment_complete")
	else
		var/remaining = demanded_item_quantity - items_received
		pirate_say("Good. [remaining] more [demanded_item_name] to go.")

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
