/**
 * Ship Data Siphon - Steals credits from targeted ships
 *
 * Used by NPC pirate ships to drain player ship bank accounts.
 * Players can board the pirate ship and interact with the siphon
 * to recover stolen credits as holochips.
 *
 * Can also be stolen by players and used for piracy.
 */
/obj/machinery/shuttle_scrambler/ship_siphon
	name = "ship data siphon"
	desc = "A sophisticated device that can drain credits from a targeted ship's accounts. The accumulated credits can be retrieved by interacting with it."
	circuit = /obj/item/circuitboard/machine/ship_combat/data_siphon
	active_power_usage = BASE_MACHINE_ACTIVE_CONSUMPTION
	/// Reference to the ship this siphon is installed on
	var/datum/weakref/owner_ship_ref
	/// Reference to the current target ship being siphoned
	var/datum/weakref/target_ship_ref
	/// Reference to linked combat console
	var/datum/weakref/linked_console_ref
	/// Credits siphoned per process tick (every 2 seconds)
	siphon_per_tick = SIPHON_BASE_RATE
	/// Whether this siphon requires weapons lock to function
	var/requires_lock = TRUE

	/// Warmup time before siphon activates (in deciseconds)
	var/warmup_time = SIPHON_BASE_WARMUP_TIME
	/// Whether warmup is in progress
	var/warming_up = FALSE
	/// When warmup started
	var/warmup_start_time = 0

	// ===== STOCK PART MODIFIERS =====
	/// Siphon rate multiplier from capacitors (higher = more credits per tick)
	var/rate_mult = 1
	/// Power efficiency multiplier from micro-lasers (lower = less power draw)
	var/efficiency_mult = 1
	/// Warmup time multiplier from servos (lower = faster warmup)
	var/warmup_mult = 1

	/// Goal amount to steal (0 = no goal, unlimited siphoning)
	var/siphon_goal = 0
	/// Percentage of target's money to steal as goal (0 = use absolute goal)
	var/siphon_goal_percent = 0
	/// Whether goal has been reached this session
	var/goal_reached = FALSE
	/// credits_stored as it was when the current run started. The goal is measured
	/// against what THIS run has taken - without it, loot left in the machine from
	/// the last victim instantly satisfies the goal on the next one, and the second
	/// target gets robbed of nothing while the pirate declares success and retreats.
	var/run_start_credits = 0

/obj/machinery/shuttle_scrambler/ship_siphon/Initialize(mapload)
	. = ..()
	RefreshParts()
	addtimer(CALLBACK(src, PROC_REF(attempt_auto_link)), 2 SECONDS)

/obj/machinery/shuttle_scrambler/ship_siphon/Destroy()
	deactivate_siphon()
	unlink_console()
	owner_ship_ref = null
	target_ship_ref = null
	return ..()

// ========== STOCK PARTS ==========

/obj/machinery/shuttle_scrambler/ship_siphon/RefreshParts()
	. = ..()

	// Reset to base values
	rate_mult = 1
	efficiency_mult = 1
	warmup_mult = 1

	// Apply capacitor bonuses (siphon rate)
	for(var/datum/stock_part/capacitor/cap in component_parts)
		rate_mult += SIPHON_CAPACITOR_RATE_MULT * (cap.tier - 1)

	// Apply micro-laser bonuses (power efficiency)
	for(var/datum/stock_part/micro_laser/laser in component_parts)
		efficiency_mult -= SIPHON_LASER_EFFICIENCY_MULT * (laser.tier - 1)

	// Apply servo bonuses (warmup reduction)
	for(var/datum/stock_part/servo/servo in component_parts)
		warmup_mult -= SIPHON_SERVO_WARMUP_MULT * (servo.tier - 1)

	// Clamp values
	efficiency_mult = max(efficiency_mult, 0.3)
	warmup_mult = max(warmup_mult, 0.3)

	// Apply rate multiplier to siphon_per_tick
	siphon_per_tick = round(SIPHON_BASE_RATE * rate_mult)
	// Apply warmup multiplier
	warmup_time = SIPHON_BASE_WARMUP_TIME * warmup_mult

	update_power_draw()

// ========== POWER MANAGEMENT ==========

/// Updates machine power usage based on current state
/obj/machinery/shuttle_scrambler/ship_siphon/proc/update_power_draw()
	if(active || warming_up)
		var/power_needed = SIPHON_BASE_POWER_COST * efficiency_mult
		update_mode_power_usage(ACTIVE_POWER_USE, power_needed)
		update_use_power(ACTIVE_POWER_USE)
	else
		update_mode_power_usage(ACTIVE_POWER_USE, 0)
		update_use_power(IDLE_POWER_USE)

// ========== CONSOLE LINKING ==========

/// Links this siphon to a combat console
/obj/machinery/shuttle_scrambler/ship_siphon/proc/link_console(obj/machinery/computer/camera_advanced/ship_combat/console)
	if(!console)
		return FALSE
	unlink_console()
	linked_console_ref = WEAKREF(console)
	RegisterSignal(console, COMSIG_QDELETING, PROC_REF(on_console_deleted))
	return TRUE

/// Unlinks from the current console
/obj/machinery/shuttle_scrambler/ship_siphon/proc/unlink_console()
	var/obj/machinery/computer/camera_advanced/ship_combat/console = linked_console_ref?.resolve()
	if(console)
		UnregisterSignal(console, COMSIG_QDELETING)
		if(console.linked_siphon_ref?.resolve() == src)
			console.linked_siphon_ref = null
	linked_console_ref = null

/// Attempts to auto-link to a combat console on the same ship
/obj/machinery/shuttle_scrambler/ship_siphon/proc/attempt_auto_link()
	// Already linked
	if(linked_console_ref?.resolve())
		return

	var/obj/structure/overmap/ship/our_ship = find_owner_ship()
	if(!our_ship)
		return

	// Find a combat console on this ship that doesn't have a siphon linked
	for(var/area/ship_area in our_ship.shuttle.shuttle_areas)
		for(var/obj/machinery/computer/camera_advanced/ship_combat/console in ship_area)
			if(console.linked_siphon_ref?.resolve())
				continue
			// Found one - link to it
			if(link_console(console))
				console.linked_siphon_ref = WEAKREF(src)
				return

/// Returns status data for the combat console UI
/obj/machinery/shuttle_scrambler/ship_siphon/proc/get_status()
	var/list/status = list()
	status["active"] = active
	status["warming_up"] = warming_up
	status["credits_stored"] = credits_stored

	// Warmup progress
	if(warming_up && warmup_start_time > 0)
		var/elapsed = world.time - warmup_start_time
		status["warmup_progress"] = clamp((elapsed / warmup_time) * 100, 0, 100)
	else
		status["warmup_progress"] = 0

	// Goal progress
	if(siphon_goal > 0)
		status["siphon_goal"] = siphon_goal
		status["goal_progress"] = clamp((get_run_take() / siphon_goal) * 100, 0, 100)
	else
		status["siphon_goal"] = 0
		status["goal_progress"] = 0

	// Target info
	var/obj/structure/overmap/ship/target = get_target_ship()
	if(target)
		status["target_name"] = target.name
	else
		status["target_name"] = null

	// Upgrade stats
	status["siphon_rate"] = siphon_per_tick
	status["rate_mult"] = rate_mult
	status["efficiency_mult"] = efficiency_mult
	status["warmup_mult"] = warmup_mult
	status["warmup_time"] = warmup_time
	status["power_draw"] = (active || warming_up) ? round(SIPHON_BASE_POWER_COST * efficiency_mult) : 0

	return status

/// Called when linked combat console is deleted
/obj/machinery/shuttle_scrambler/ship_siphon/proc/on_console_deleted(datum/source)
	SIGNAL_HANDLER
	UnregisterSignal(source, COMSIG_QDELETING)
	linked_console_ref = null
	if(active || warming_up)
		INVOKE_ASYNC(src, PROC_REF(deactivate_siphon))

// ========== TOOL INTERACTIONS ==========

/obj/machinery/shuttle_scrambler/ship_siphon/wrench_act(mob/living/user, obj/item/tool)
	. = ITEM_INTERACT_BLOCKING
	if(active || warming_up)
		to_chat(user, span_warning("Cannot unwrench while siphon is active!"))
		return ITEM_INTERACT_BLOCKING
	default_unfasten_wrench(user, tool)
	return ITEM_INTERACT_SUCCESS

/obj/machinery/shuttle_scrambler/ship_siphon/attackby(obj/item/W, mob/user, list/modifiers)
	if(istype(W, /obj/item/multitool))
		var/obj/item/multitool/tool = W
		tool.buffer = src
		balloon_alert(user, "siphon buffered")
		to_chat(user, span_notice("You buffer [src] to the multitool. Use on a weapons system to link."))
		return TRUE

	if(default_deconstruction_screwdriver(user, icon_state, icon_state, W))
		return
	if(default_deconstruction_crowbar(W))
		return
	return ..()

// ========== SHIP FINDING ==========

/// Attempts to find the ship this siphon belongs to (lazy initialization)
/obj/machinery/shuttle_scrambler/ship_siphon/proc/find_owner_ship()
	// Already found
	if(owner_ship_ref?.resolve())
		return owner_ship_ref.resolve()

	var/area/our_area = get_area(src)
	if(!our_area)
		return null

	for(var/obj/structure/overmap/ship/ship as anything in SSovermap.simulated_ships)
		if(!ship.shuttle?.shuttle_areas)
			continue
		if(our_area in ship.shuttle.shuttle_areas)
			owner_ship_ref = WEAKREF(ship)
			return ship

	return null

/// Gets the owner ship (finds it lazily if not cached)
/obj/machinery/shuttle_scrambler/ship_siphon/proc/get_owner_ship()
	var/obj/structure/overmap/ship/owner = owner_ship_ref?.resolve()
	if(!owner)
		owner = find_owner_ship()
	return owner

/// Gets the target ship from weakref
/obj/machinery/shuttle_scrambler/ship_siphon/proc/get_target_ship()
	return target_ship_ref?.resolve()

/// Credits taken off the current target since this run started
/obj/machinery/shuttle_scrambler/ship_siphon/proc/get_run_take()
	return max(credits_stored - run_start_credits, 0)

/// Sets the target ship to siphon from
/obj/machinery/shuttle_scrambler/ship_siphon/proc/set_target(obj/structure/overmap/ship/target)
	if(target)
		target_ship_ref = WEAKREF(target)
	else
		target_ship_ref = null

// ========== SIPHON ACTIVATION ==========

/// Called by NPC ship AI when it has weapons lock
/obj/machinery/shuttle_scrambler/ship_siphon/proc/activate_siphon(obj/structure/overmap/ship/target)
	if(active || warming_up)
		return
	if(!target)
		return

	set_target(target)

	// Calculate siphon goal based on target's current money
	goal_reached = FALSE
	run_start_credits = credits_stored
	if(siphon_goal_percent > 0 && target.ship_account)
		var/target_balance = target.ship_account.account_balance
		// If target is broke, don't bother siphoning
		if(target_balance < SIPHON_MINIMUM_TARGET_BALANCE)
			var/obj/structure/overmap/ship/owner = get_owner_ship()
			owner?.ship_notify("Target vessel has insufficient funds. Aborting siphon.", "SIPHON", SHIP_NOTIFY_NOTICE, 'voidcrew/sound/notify2.ogg', 50)
			// Trigger retreat if we have a goal-based behavior
			on_goal_reached(target)
			return
		siphon_goal = round(target_balance * (siphon_goal_percent / 100))
		// Ensure minimum goal of 100 credits
		siphon_goal = max(siphon_goal, 100)

	// Start warmup phase
	warming_up = TRUE
	warmup_start_time = world.time
	START_PROCESSING(SSobj, src)
	update_appearance()
	update_power_draw()

	// Announce warmup to owner ship only (target notified when siphon activates)
	var/obj/structure/overmap/ship/owner = get_owner_ship()
	owner?.ship_notify("Data siphon calibrating. Target: [target.name]. ETA: [warmup_time / 10] seconds.", "SIPHON", SHIP_NOTIFY_NOTICE, 'voidcrew/sound/notify.ogg', 25)

/// Called when lock is lost or target destroyed
/obj/machinery/shuttle_scrambler/ship_siphon/proc/deactivate_siphon()
	if(!active && !warming_up)
		return

	var/was_active = active
	active = FALSE
	warming_up = FALSE
	warmup_start_time = 0

	var/obj/structure/overmap/ship/owner = get_owner_ship()
	var/obj/structure/overmap/ship/target = get_target_ship()

	if(was_active && target)
		var/run_take = get_run_take()
		target.ship_notify("Data siphon connection severed. Total credits lost: [run_take].", "FINANCE", SHIP_NOTIFY_WARNING, 'voidcrew/sound/notify2.ogg', 25)
		owner?.ship_notify("Siphon link lost. Total credits acquired: [run_take].", "SIPHON", SHIP_NOTIFY_NOTICE, 'voidcrew/sound/notify2.ogg', 25)

	target_ship_ref = null
	STOP_PROCESSING(SSobj, src)
	update_appearance()
	update_power_draw()

/// Steals credits from the target ship's bank account
/obj/machinery/shuttle_scrambler/ship_siphon/proc/siphon_from_target(obj/structure/overmap/ship/target)
	if(!target?.ship_account)
		return

	var/datum/bank_account/target_account = target.ship_account
	var/siphoned = min(target_account.account_balance, siphon_per_tick)

	if(siphoned <= 0)
		return

	target_account.adjust_money(-siphoned)
	credits_stored += siphoned

	// Check if we've reached our siphon goal - measured against this run's take,
	// not the machine's lifetime total
	if(siphon_goal > 0 && get_run_take() >= siphon_goal && !goal_reached)
		goal_reached = TRUE
		on_goal_reached(target)

/// Called when siphon goal is reached - triggers retreat behavior
/obj/machinery/shuttle_scrambler/ship_siphon/proc/on_goal_reached(obj/structure/overmap/ship/target)
	var/obj/structure/overmap/ship/owner = get_owner_ship()

	// Announce goal reached
	owner?.ship_notify("Siphon goal reached! [get_run_take()] credits acquired. Disengaging from target.", "SIPHON", SHIP_NOTIFY_NOTICE, 'voidcrew/sound/notify.ogg', 50)
	target?.ship_notify("The attacker has finished siphoning and is disengaging.", "SECURITY", SHIP_NOTIFY_WARNING, 'voidcrew/sound/warn4.ogg', 25)

	// Deactivate the siphon
	deactivate_siphon()

	// Tell the owner ship's AI to retreat
	var/obj/structure/overmap/ship/npc/npc_owner = owner
	if(istype(npc_owner) && npc_owner.ai_controller)
		var/datum/ai_controller/npc_ship/controller = npc_owner.ai_controller
		controller.blackboard[BB_NPC_RETREAT_REASON] = "siphon_goal"
		// set_combat_state stores BB_NPC_LAST_TARGET automatically when entering retreat
		controller.set_combat_state(NPC_COMBAT_RETREATING)
		controller.set_blackboard_key(BB_NPC_MOVEMENT_MODE, NPC_MOVEMENT_RETREAT)

// ========== INTERACTION ==========

/obj/machinery/shuttle_scrambler/ship_siphon/interact(mob/user)
	dump_loot(user)

/// Override dump_loot to handle ship context
/obj/machinery/shuttle_scrambler/ship_siphon/dump_loot(mob/user)
	if(credits_stored <= 0)
		to_chat(user, span_notice("The siphon's storage is empty."))
		return

	var/obj/item/holochip/chip = new(drop_location(), credits_stored)
	user.put_in_hands(chip)
	to_chat(user, span_notice("You retrieve [credits_stored] credits from the siphon!"))
	playsound(src, 'sound/machines/terminal/terminal_button01.ogg', 50, TRUE)

	// Log the recovery
	var/obj/structure/overmap/ship/owner = get_owner_ship()
	log_game("[key_name(user)] recovered [credits_stored] siphoned credits from [owner ? owner.name : "unknown ship"]'s data siphon.")

	credits_stored = 0
	run_start_credits = 0

/obj/machinery/shuttle_scrambler/ship_siphon/examine(mob/user)
	. = ..()
	if(warming_up)
		var/remaining = max(0, (warmup_start_time + warmup_time - world.time) / 10)
		. += span_warning("Calibrating... [round(remaining, 0.1)] seconds remaining.")
	else if(active)
		. += span_warning("ACTIVE - Siphoning credits from target.")
		. += span_notice("Credits stored: [credits_stored]")
	else
		. += span_notice("Inactive. Requires weapons lock on target to activate.")
	if(credits_stored > 0)
		. += span_notice("Credits stored: [credits_stored]")
	. += span_notice("Siphon Rate: [siphon_per_tick] credits/tick ([round(rate_mult * 100)]%)")
	. += span_notice("Power Efficiency: [round((1 - efficiency_mult) * 100)]% reduction")
	. += span_notice("Warmup Time: [round(warmup_time / 10, 0.1)]s ([round((1 - warmup_mult) * 100)]% reduction)")
	var/obj/machinery/computer/camera_advanced/ship_combat/console = linked_console_ref?.resolve()
	if(console)
		. += span_notice("Linked to: [console]")
	else
		. += span_warning("Not linked to a weapons system. Use a multitool to link.")

// Don't do the station-specific stuff from parent
/obj/machinery/shuttle_scrambler/ship_siphon/toggle_on(mob/user)
	return

/obj/machinery/shuttle_scrambler/ship_siphon/send_notification()
	return

/obj/machinery/shuttle_scrambler/ship_siphon/interrupt_research()
	return

// ========== PLAYER ACTIVATION (from combat console) ==========

/// Player-initiated siphon activation (from combat console UI)
/obj/machinery/shuttle_scrambler/ship_siphon/proc/player_activate_siphon(mob/user, obj/structure/overmap/ship/target_override)
	if(active || warming_up)
		to_chat(user, span_warning("The siphon is already active!"))
		return FALSE

	var/obj/machinery/computer/camera_advanced/ship_combat/console = linked_console_ref?.resolve()
	if(!console)
		to_chat(user, span_warning("Siphon is not linked to a combat console."))
		return FALSE

	var/obj/structure/overmap/ship/target = target_override || console.target_ship
	if(!target)
		to_chat(user, span_warning("No target locked on combat console. Acquire a weapons lock first."))
		return FALSE

	// Set the target
	set_target(target)

	goal_reached = FALSE
	run_start_credits = credits_stored
	if(target.ship_account)
		var/target_balance = target.ship_account.account_balance
		if(target_balance < SIPHON_MINIMUM_TARGET_BALANCE)
			to_chat(user, span_warning("Target vessel has insufficient funds to siphon."))
			target_ship_ref = null
			return FALSE
		// A crewed ship only gets skimmed - a quarter of the balance per run, so no
		// single robbery strips another crew bare. A pirate hull has no such
		// protection: take the whole hold if you can hold the lock long enough.
		var/goal_fraction = istype(target, /obj/structure/overmap/ship/npc) ? 1 : 0.25
		siphon_goal = round(target_balance * goal_fraction)
		siphon_goal = max(siphon_goal, 100)

	// Start warmup
	warming_up = TRUE
	warmup_start_time = world.time
	START_PROCESSING(SSobj, src)
	update_appearance()
	update_power_draw()

	to_chat(user, span_notice("Siphon calibrating. Target: [target.name]."))
	var/obj/structure/overmap/ship/owner = get_owner_ship()
	owner?.ship_notify("Data siphon calibrating. Target: [target.name]. ETA: [warmup_time / 10] seconds.", "SIPHON SYSTEM", SHIP_NOTIFY_NOTICE, 'voidcrew/sound/notify.ogg', 50)

	return TRUE

// ========== PROCESSING ==========

/// Override process to check player ship lock status
/obj/machinery/shuttle_scrambler/ship_siphon/process()
	// Check for power loss or damage
	if(machine_stat & (BROKEN|NOPOWER))
		if(active || warming_up)
			var/obj/structure/overmap/ship/powner = get_owner_ship()
			deactivate_siphon()
			powner?.ship_notify("Data siphon offline - power failure!", "SIPHON SYSTEM", SHIP_NOTIFY_WARNING, 'voidcrew/sound/warn.ogg', 25)
		return PROCESS_KILL

	var/obj/structure/overmap/ship/owner = get_owner_ship()
	var/obj/structure/overmap/ship/target = get_target_ship()

	// Validate target still exists
	if(!target || QDELETED(target))
		deactivate_siphon()
		return PROCESS_KILL

	// For player ships, check if combat console still has lock
	if(!istype(owner, /obj/structure/overmap/ship/npc))
		var/obj/machinery/computer/camera_advanced/ship_combat/console = linked_console_ref?.resolve()
		if(!console || console.target_ship != target)
			var/obj/structure/overmap/ship/old_target = target
			deactivate_siphon()
			owner?.ship_notify("Siphon deactivated - weapons lock on [old_target.name] lost.", "SIPHON SYSTEM", SHIP_NOTIFY_WARNING, 'voidcrew/sound/warn.ogg', 25)
			return PROCESS_KILL

	// If we require lock and this is an NPC ship, verify we still have it
	if(requires_lock && owner)
		var/obj/structure/overmap/ship/npc/npc_owner = owner
		if(istype(npc_owner) && npc_owner.ai_controller)
			var/datum/ai_controller/npc_ship/controller = npc_owner.ai_controller
			var/current_target = controller.get_target()
			var/has_lock = controller.blackboard[BB_NPC_TARGET_LOCKED]
			if(current_target != target || !has_lock)
				deactivate_siphon()
				return PROCESS_KILL

	// Handle warmup phase
	if(warming_up)
		if(world.time >= warmup_start_time + warmup_time)
			// Warmup complete - activate siphon
			warming_up = FALSE
			active = TRUE
			owner?.ship_notify("Data siphon active. Draining target accounts.", "SIPHON SYSTEM", SHIP_NOTIFY_NOTICE, 'voidcrew/sound/notify.ogg', 50)
			target.ship_notify("CRITICAL: CREDIT SIPHONING OCCURRING!", "FINANCE ALERT", SHIP_NOTIFY_DANGER, 'voidcrew/sound/alert2.ogg', 20)
		return

	// If not active (shouldn't happen but safety check)
	if(!active)
		return PROCESS_KILL

	// Perform the siphon
	siphon_from_target(target)

// ========== TGUI INTERFACE ==========

/obj/machinery/shuttle_scrambler/ship_siphon/ui_interact(mob/user, datum/tgui/ui)
	ui = SStgui.try_update_ui(user, src, ui)
	if(!ui)
		ui = new(user, src, "ShipSiphon")
		ui.open()

/obj/machinery/shuttle_scrambler/ship_siphon/ui_data(mob/user)
	var/list/data = list()

	data["active"] = active
	data["warming_up"] = warming_up
	data["credits_stored"] = credits_stored

	// Warmup progress
	if(warming_up && warmup_start_time > 0)
		var/elapsed = world.time - warmup_start_time
		data["warmup_progress"] = clamp((elapsed / warmup_time) * 100, 0, 100)
	else
		data["warmup_progress"] = 0

	// Goal progress
	if(siphon_goal > 0)
		data["siphon_goal"] = siphon_goal
		data["goal_progress"] = clamp((get_run_take() / siphon_goal) * 100, 0, 100)
	else
		data["siphon_goal"] = 0
		data["goal_progress"] = 0

	// Target info
	var/obj/machinery/computer/camera_advanced/ship_combat/console = linked_console_ref?.resolve()
	var/obj/structure/overmap/ship/target = get_target_ship()
	if(target)
		data["has_target"] = TRUE
		data["target_name"] = target.name
		data["target_credits"] = target.ship_account?.account_balance || 0
	else if(console?.target_ship)
		data["has_target"] = TRUE
		data["target_name"] = console.target_ship.name
		// Console targets can also be player outposts, which hold no ship account
		var/obj/structure/overmap/ship/console_target = console.target_ship
		data["target_credits"] = istype(console_target) ? (console_target.ship_account?.account_balance || 0) : 0
	else
		data["has_target"] = FALSE
		data["target_name"] = null
		data["target_credits"] = 0

	// What a run off this target would take: a quarter off a crewed ship, the lot
	// off a pirate hull. Mirrors the split in player_activate_siphon().
	var/obj/structure/overmap/ship/preview_target = target || console?.target_ship
	data["goal_fraction"] = istype(preview_target, /obj/structure/overmap/ship/npc) ? 1 : 0.25

	// Can activate check. A target with nothing in its accounts is rejected here
	// rather than at activation, so the button never looks live on a broke hull.
	var/target_has_funds = data["target_credits"] >= SIPHON_MINIMUM_TARGET_BALANCE
	data["can_activate"] = !active && !warming_up && !!console?.target_ship && target_has_funds && !(machine_stat & (BROKEN|NOPOWER)) && anchored
	if(!console)
		data["no_lock_reason"] = "Not linked to a weapons system."
	else if(!console.target_ship)
		data["no_lock_reason"] = "No target locked on combat console."
	else if(!target_has_funds)
		data["no_lock_reason"] = "Target's accounts are empty."
	else if(machine_stat & NOPOWER)
		data["no_lock_reason"] = "No power."
	else if(machine_stat & BROKEN)
		data["no_lock_reason"] = "Machine is broken."
	else if(!anchored)
		data["no_lock_reason"] = "Must be anchored."
	else
		data["no_lock_reason"] = null

	// System stats
	data["siphon_rate"] = siphon_per_tick
	data["rate_mult"] = rate_mult
	data["efficiency_mult"] = efficiency_mult
	data["warmup_mult"] = warmup_mult
	data["warmup_time"] = warmup_time / 10  // Convert to seconds for UI
	data["power_draw"] = (active || warming_up) ? round(SIPHON_BASE_POWER_COST * efficiency_mult) : 0

	return data

/obj/machinery/shuttle_scrambler/ship_siphon/ui_act(action, list/params, datum/tgui/ui)
	. = ..()
	if(.)
		return

	switch(action)
		if("activate")
			player_activate_siphon(ui.user)
			return TRUE
		if("deactivate")
			deactivate_siphon()
			return TRUE
		if("withdraw")
			dump_loot(ui.user)
			return TRUE

	return FALSE

// ========== CIRCUIT BOARD ==========

/obj/item/circuitboard/machine/ship_combat/data_siphon
	name = "Data Siphon"
	greyscale_colors = CIRCUIT_COLOR_COMMAND
	build_path = /obj/machinery/shuttle_scrambler/ship_siphon
	req_components = list(
		/datum/stock_part/capacitor = 2,
		/datum/stock_part/micro_laser = 1,
		/datum/stock_part/servo = 1,
	)
