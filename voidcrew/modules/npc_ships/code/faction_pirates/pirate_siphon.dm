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
	siphon_per_tick = 50
	/// Whether this siphon requires weapons lock to function
	var/requires_lock = TRUE

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
	if(active)
		return
	if(!target)
		return

	set_target(target)
	active = TRUE
	START_PROCESSING(SSobj, src)
	update_appearance()

	// Notify the target ship
	var/obj/structure/overmap/ship/owner = get_owner_ship()
	var/owner_name = owner ? owner.name : "Unknown vessel"
	notify_target_ship(target, "WARNING: [owner_name] is siphoning credits from your accounts!")

/// Called when lock is lost or target destroyed
/obj/machinery/shuttle_scrambler/ship_siphon/proc/deactivate_siphon()
	if(!active)
		return

	active = FALSE
	target_ship_ref = null
	STOP_PROCESSING(SSobj, src)
	update_appearance()

/obj/machinery/shuttle_scrambler/ship_siphon/process()
	if(!active)
		return PROCESS_KILL

	var/obj/structure/overmap/ship/owner = get_owner_ship()
	var/obj/structure/overmap/ship/target = get_target_ship()

	// Validate target still exists
	if(!target || QDELETED(target))
		deactivate_siphon()
		return PROCESS_KILL

	// If we require lock, verify we still have it
	if(requires_lock && owner)
		var/obj/structure/overmap/ship/npc/npc_owner = owner
		if(istype(npc_owner) && npc_owner.ai_controller)
			var/datum/ai_controller/npc_ship/controller = npc_owner.ai_controller
			var/current_target = controller.get_target()
			var/has_lock = controller.blackboard[BB_NPC_TARGET_LOCKED]
			if(current_target != target || !has_lock)
				deactivate_siphon()
				return PROCESS_KILL

	// Perform the siphon
	siphon_from_target(target)

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

	// Periodic notification to target (every ~10 seconds worth of siphoning)
	if(prob(20))
		notify_target_ship(target, "Your ship's accounts are being drained! [siphoned] credits stolen. Destroy or board the attacker to stop the siphon!")

/// Sends a message to everyone on the target ship
/obj/machinery/shuttle_scrambler/ship_siphon/proc/notify_target_ship(obj/structure/overmap/ship/target, message)
	if(!target?.shuttle?.shuttle_areas)
		return

	for(var/area/shuttle_area as anything in target.shuttle.shuttle_areas)
		for(var/mob/living/crew in shuttle_area)
			to_chat(crew, span_userdanger("[message]"))

/obj/machinery/shuttle_scrambler/ship_siphon/interact(mob/user)
	if(active)
		// Check if user is on the same ship as the siphon or boarding
		dump_loot(user)
		return

	// Manual activation by players (for stolen siphons)
	if(!active)
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
