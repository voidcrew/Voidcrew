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
	/// Reference to the ship this siphon is installed on
	var/datum/weakref/owner_ship_ref
	/// Reference to the current target ship being siphoned
	var/datum/weakref/target_ship_ref
	/// Credits siphoned per process tick (every 2 seconds)
	siphon_per_tick = 200
	/// Whether this siphon requires weapons lock to function
	var/requires_lock = TRUE

	/// Warmup time before siphon activates (in deciseconds)
	var/warmup_time = 5 SECONDS
	/// Whether warmup is in progress
	var/warming_up = FALSE
	/// When warmup started
	var/warmup_start_time = 0

	/// Goal amount to steal (0 = no goal, unlimited siphoning)
	var/siphon_goal = 0
	/// Percentage of target's money to steal as goal (0 = use absolute goal)
	var/siphon_goal_percent = 0
	/// Whether goal has been reached this session
	var/goal_reached = FALSE

/obj/machinery/shuttle_scrambler/ship_siphon/Initialize(mapload)
	. = ..()

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

/// Sets the target ship to siphon from
/obj/machinery/shuttle_scrambler/ship_siphon/proc/set_target(obj/structure/overmap/ship/target)
	if(target)
		target_ship_ref = WEAKREF(target)
	else
		target_ship_ref = null

/// Called by NPC ship AI when it has weapons lock
/obj/machinery/shuttle_scrambler/ship_siphon/proc/activate_siphon(obj/structure/overmap/ship/target)
	if(active || warming_up)
		return
	if(!target)
		return

	set_target(target)

	// Calculate siphon goal based on target's current money
	goal_reached = FALSE
	if(siphon_goal_percent > 0 && target.ship_account)
		var/target_balance = target.ship_account.account_balance
		// If target is broke (less than 50 credits), don't bother siphoning
		if(target_balance < 50)
			var/obj/structure/overmap/ship/owner = get_owner_ship()
			owner?.ship_notify("Target vessel has insufficient funds. Aborting siphon.", "SIPHON", SHIP_NOTIFY_NOTICE, 'voidcrew/sound/notify2.ogg')
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

	// Announce warmup to owner ship only (target notified when siphon activates)
	var/obj/structure/overmap/ship/owner = get_owner_ship()
	owner?.ship_notify("Data siphon calibrating. Target: [target.name]. ETA: [warmup_time / 10] seconds.", "SIPHON", SHIP_NOTIFY_NOTICE, 'voidcrew/sound/notify.ogg')

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
		target.ship_notify("Data siphon connection severed. Total credits lost: [credits_stored].", "FINANCE", SHIP_NOTIFY_WARNING, 'voidcrew/sound/notify2.ogg')
		owner?.ship_notify("Siphon link lost. Total credits acquired: [credits_stored].", "SIPHON", SHIP_NOTIFY_NOTICE, 'voidcrew/sound/notify2.ogg')

	target_ship_ref = null
	STOP_PROCESSING(SSobj, src)
	update_appearance()

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

	// Check if we've reached our siphon goal
	if(siphon_goal > 0 && credits_stored >= siphon_goal && !goal_reached)
		goal_reached = TRUE
		on_goal_reached(target)

/// Called when siphon goal is reached - triggers retreat behavior
/obj/machinery/shuttle_scrambler/ship_siphon/proc/on_goal_reached(obj/structure/overmap/ship/target)
	var/obj/structure/overmap/ship/owner = get_owner_ship()

	// Announce goal reached
	owner?.ship_notify("Siphon goal reached! [credits_stored] credits acquired. Disengaging from target.", "SIPHON", SHIP_NOTIFY_NOTICE, 'voidcrew/sound/notify.ogg')
	target?.ship_notify("The attacker has finished siphoning and is disengaging.", "SECURITY", SHIP_NOTIFY_WARNING, 'voidcrew/sound/warn4.ogg')

	// Deactivate the siphon
	deactivate_siphon()

	// Tell the owner ship's AI to retreat
	var/obj/structure/overmap/ship/npc/npc_owner = owner
	if(istype(npc_owner) && npc_owner.ai_controller)
		var/datum/ai_controller/npc_ship/controller = npc_owner.ai_controller
		// Store the target before we lose it
		controller.blackboard[BB_NPC_LAST_TARGET] = WEAKREF(target)
		controller.blackboard[BB_NPC_RETREAT_REASON] = "siphon_goal"
		controller.set_combat_state(NPC_COMBAT_RETREATING)
		controller.set_blackboard_key(BB_NPC_MOVEMENT_MODE, NPC_MOVEMENT_RETREAT)

/obj/machinery/shuttle_scrambler/ship_siphon/interact(mob/user)
	if(active || warming_up)
		// Check if user is on the same ship as the siphon or boarding
		dump_loot(user)
		return

	// Manual activation by players (for stolen siphons)
	attempt_manual_activation(user)

/// Allows players to manually activate a stolen siphon
/obj/machinery/shuttle_scrambler/ship_siphon/proc/attempt_manual_activation(mob/user)
	var/obj/structure/overmap/ship/owner = get_owner_ship()
	if(!owner)
		to_chat(user, span_warning("The siphon isn't connected to any ship systems."))
		return

	// Check if owner ship has a target locked
	if(istype(owner, /obj/structure/overmap/ship/npc))
		to_chat(user, span_notice("This siphon is controlled by the ship's AI."))
		return

	// For player ships, check if they have weapons lock on something
	// This would integrate with player ship targeting systems
	to_chat(user, span_notice("The siphon requires a weapons lock on a target to function."))
	// TODO: Integrate with player ship weapons lock system

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

/obj/machinery/shuttle_scrambler/ship_siphon/Destroy()
	deactivate_siphon()
	owner_ship_ref = null
	target_ship_ref = null
	return ..()

// Don't do the station-specific stuff from parent
/obj/machinery/shuttle_scrambler/ship_siphon/toggle_on(mob/user)
	return

/obj/machinery/shuttle_scrambler/ship_siphon/send_notification()
	return

/obj/machinery/shuttle_scrambler/ship_siphon/interrupt_research()
	return

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
		data["goal_progress"] = clamp((credits_stored / siphon_goal) * 100, 0, 100)
	else
		data["siphon_goal"] = 0
		data["goal_progress"] = 0

	// Target info
	var/obj/structure/overmap/ship/target = get_target_ship()
	if(target)
		data["has_target"] = TRUE
		data["target_name"] = target.name
		data["target_credits"] = target.ship_account?.account_balance || 0
	else
		// Check if we can get a target from combat console (for player ships)
		var/obj/machinery/computer/camera_advanced/ship_combat/console = find_combat_console()
		if(console?.target_ship)
			data["has_target"] = TRUE
			data["target_name"] = console.target_ship.name
			data["target_credits"] = console.target_ship.ship_account?.account_balance || 0
			data["can_activate"] = TRUE
			data["no_lock_reason"] = null
		else
			data["has_target"] = FALSE
			data["target_name"] = null
			data["target_credits"] = 0
			data["can_activate"] = FALSE
			data["no_lock_reason"] = console ? "No target locked on combat console." : "No combat console found on this ship."

	return data

/obj/machinery/shuttle_scrambler/ship_siphon/ui_act(action, params)
	. = ..()
	if(.)
		return

	switch(action)
		if("activate")
			return player_activate_siphon(usr)
		if("deactivate")
			deactivate_siphon()
			return TRUE
		if("withdraw")
			if(credits_stored > 0 && !active && !warming_up)
				dump_loot(usr)
				return TRUE
			return FALSE

/// Finds the combat console on the owner ship
/obj/machinery/shuttle_scrambler/ship_siphon/proc/find_combat_console()
	var/obj/structure/overmap/ship/owner = get_owner_ship()
	if(!owner?.shuttle?.shuttle_areas)
		return null

	for(var/area/ship_area in owner.shuttle.shuttle_areas)
		for(var/obj/machinery/computer/camera_advanced/ship_combat/console in ship_area)
			return console

	return null

/// Player-initiated siphon activation (from UI)
/obj/machinery/shuttle_scrambler/ship_siphon/proc/player_activate_siphon(mob/user)
	if(active || warming_up)
		to_chat(user, span_warning("The siphon is already active!"))
		return FALSE

	var/obj/machinery/computer/camera_advanced/ship_combat/console = find_combat_console()
	if(!console)
		to_chat(user, span_warning("No combat console found on this ship."))
		return FALSE

	if(!console.target_ship)
		to_chat(user, span_warning("No target locked on combat console. Acquire a weapons lock first."))
		return FALSE

	var/obj/structure/overmap/ship/target = console.target_ship

	// Set the target
	set_target(target)

	// Calculate 25% goal for player usage
	goal_reached = FALSE
	if(target.ship_account)
		var/target_balance = target.ship_account.account_balance
		if(target_balance < 50)
			to_chat(user, span_warning("Target vessel has insufficient funds to siphon."))
			target_ship_ref = null
			return FALSE
		siphon_goal = round(target_balance * 0.25)
		siphon_goal = max(siphon_goal, 100)

	// Register for lock lost signal
	RegisterSignal(console, COMSIG_QDELETING, PROC_REF(on_console_deleted))

	// Start warmup
	warming_up = TRUE
	warmup_start_time = world.time
	START_PROCESSING(SSobj, src)
	update_appearance()

	to_chat(user, span_notice("Siphon calibrating. Target: [target.name]."))
	var/obj/structure/overmap/ship/owner = get_owner_ship()
	owner?.ship_notify("Data siphon calibrating. Target: [target.name]. ETA: [warmup_time / 10] seconds.", "SIPHON SYSTEM", SHIP_NOTIFY_NOTICE, 'voidcrew/sound/notify.ogg')

	return TRUE

/// Called when linked combat console is deleted
/obj/machinery/shuttle_scrambler/ship_siphon/proc/on_console_deleted(datum/source)
	SIGNAL_HANDLER
	UnregisterSignal(source, COMSIG_QDELETING)
	if(active || warming_up)
		deactivate_siphon()

/// Override process to check player ship lock status
/obj/machinery/shuttle_scrambler/ship_siphon/process()
	var/obj/structure/overmap/ship/owner = get_owner_ship()
	var/obj/structure/overmap/ship/target = get_target_ship()

	// Validate target still exists
	if(!target || QDELETED(target))
		deactivate_siphon()
		return PROCESS_KILL

	// For player ships, check if combat console still has lock
	if(!istype(owner, /obj/structure/overmap/ship/npc))
		var/obj/machinery/computer/camera_advanced/ship_combat/console = find_combat_console()
		if(!console || console.target_ship != target)
			var/obj/structure/overmap/ship/old_target = target
			deactivate_siphon()
			owner?.ship_notify("Siphon deactivated - weapons lock on [old_target.name] lost.", "SIPHON SYSTEM", SHIP_NOTIFY_WARNING, 'voidcrew/sound/warn.ogg')
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
			owner?.ship_notify("Data siphon active. Draining target accounts.", "SIPHON SYSTEM", SHIP_NOTIFY_NOTICE, 'voidcrew/sound/notify.ogg')
			target.ship_notify("CRITICAL: CREDIT SIPHONING OCCURRING!", "FINANCE ALERT", SHIP_NOTIFY_DANGER, 'voidcrew/sound/alert2.ogg')
		return

	// If not active (shouldn't happen but safety check)
	if(!active)
		return PROCESS_KILL

	// Perform the siphon
	siphon_from_target(target)
