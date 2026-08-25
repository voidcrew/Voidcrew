/**
 * Base NPC Ship Behavior
 *
 * Parent class for all NPC ship combat behaviors.
 * These behaviors don't require movement (ships use overmap velocity).
 *
 * VOIDCREW: these all return a bare AI_BEHAVIOR_DELAY, i.e. they report BT_RUNNING
 * forever and re-fire on their own time_between_perform. That is deliberate - it is what
 * lets a parallel of them reproduce the old "queue this set of behaviors every planning
 * tick" model exactly. Do not "fix" one into returning SUCCEEDED without checking what
 * its parent node does with a completed child.
 */
/datum/bt_node/ai_behavior/npc_ship
	/// Fast tick rate for responsive combat
	time_between_perform = 0.5 SECONDS
	/// NPC_ACTION_* constant, set only on the four offensive behaviors that the
	/// npc_combat_action composite picks between. Null on everything else.
	var/combat_action

/**
 * Helper to get the ship from the controller.
 */
/datum/bt_node/ai_behavior/npc_ship/proc/get_ship(datum/ai_controller/npc_ship/controller)
	return controller?.get_ship()

/**
 * Helper to get combat interface.
 */
/datum/bt_node/ai_behavior/npc_ship/proc/get_combat_interface(datum/ai_controller/npc_ship/controller)
	return controller?.get_combat_interface()

/**
 * Check if another pirate is already hailing or negotiating with the target.
 * Only one pirate can hail/negotiate with a ship at a time.
 */
/datum/bt_node/ai_behavior/npc_ship/proc/is_target_being_hailed(obj/structure/overmap/ship/target, obj/structure/overmap/ship/npc/self)
	for(var/obj/structure/overmap/ship/npc/pirate/other_pirate as anything in SSnpc_ships.active_ships)
		if(other_pirate == self)
			continue
		if(!istype(other_pirate))
			continue
		var/datum/ai_controller/npc_ship/other_controller = other_pirate.ai_controller
		if(!other_controller)
			continue
		// Check if this other pirate is hailing or negotiating with our target
		var/other_state = other_controller.get_combat_state()
		if(other_state == NPC_COMBAT_HAILING || other_state == NPC_COMBAT_NEGOTIATING)
			if(other_controller.get_target() == target)
				return TRUE
	return FALSE

// ========== SCAN THREATS ==========

/**
 * Scans for nearby player ships within territory range.
 * If a target is found in IDLE state, transitions to ENGAGING.
 * Only engages in zones where weapons are allowed.
 */
/datum/bt_node/ai_behavior/npc_ship/scan_threats
	time_between_perform = 1 SECONDS

/datum/bt_node/ai_behavior/npc_ship/scan_threats/perform(seconds_per_tick, datum/ai_controller/npc_ship/controller)
	. = ..()

	var/obj/structure/overmap/ship/npc/ship = get_ship(controller)
	if(!ship)
		return AI_BEHAVIOR_DELAY

	// Non-hostile ships don't actively scan for targets
	if(!ship.hostile)
		return AI_BEHAVIOR_DELAY

	// A ship whose weapons have been destroyed is done fighting. Without this gate the
	// disarm loop never ends: check_weapons sends it into RETREATING, the retreat timer
	// or distance check drops it back to IDLE, and the very next scan re-acquires the
	// same victim - hail, demand, engage, notice the guns are gone, flee, repeat.
	// Uses has_intact_weapons(), not has_any_weapons(): the latter reads FALSE while
	// turrets are on cooldown or in a band that forbids firing, which would disarm
	// every healthy ship that ever idled in a yellow zone.
	var/datum/npc_combat_interface/combat = get_combat_interface(controller)
	if(ship.retreat_without_weapons && combat && !combat.has_intact_weapons())
		// Don't clear an existing target here: in ENGAGING/COMBAT that belongs to
		// check_weapons, which needs the target intact to enter RETREATING properly.
		return AI_BEHAVIOR_DELAY

	// Only attack in zones where combat is allowed (weapons OR interdiction)
	var/turf/ship_loc = get_turf(ship)
	var/datum/overmap_zone/zone = SSovermap_zones.get_zone(ship_loc)
	var/can_fight = zone ? (zone.weapons_allowed() || zone.interdiction_allowed()) : TRUE
	if(!can_fight)
		// If we had a target, clear it since we can't fight here
		if(controller.get_target())
			controller.clear_target()
		return AI_BEHAVIOR_DELAY

	// Get our current target (if any)
	var/obj/structure/overmap/ship/current_target = controller.get_target()

	// If we already have a valid target, don't scan for new ones
	if(current_target && !QDELETED(current_target))
		// Verify target is still in range
		var/target_dist = get_dist(ship, current_target)
		if(target_dist <= ship.territory_range)
			return AI_BEHAVIOR_DELAY
		// Target out of range - will be handled by disengage behavior

	// Scan for player ships in territory range
	// Use SSovermap.simulated_ships + get_dist() instead of range() for better performance
	for(var/obj/structure/overmap/ship/potential_target as anything in SSovermap.simulated_ships)
		// Skip ourselves
		if(potential_target == ship)
			continue

		// Skip other NPC ships (for now - no faction wars)
		if(istype(potential_target, /obj/structure/overmap/ship/npc))
			continue

		// Skip ships that aren't flying
		if(potential_target.state != OVERMAP_SHIP_FLYING)
			continue

		// Skip cloaked ships - can't detect them
		if(potential_target.invisibility > INVISIBILITY_NONE)
			continue

		// Skip targets already engaged by another pirate (only one pirate can engage at a time)
		// Exception: disabled pirates don't block other pirates from engaging
		var/obj/structure/overmap/ship/npc/engaging_pirate = potential_target.engaging_pirate_ref?.resolve()
		if(engaging_pirate && engaging_pirate != ship && !QDELETED(engaging_pirate))
			// If the engaging pirate is disabled, they don't block engagement
			if(engaging_pirate.is_disabled)
				// Disabled pirate - we can take over
			else
				// Active pirate has this target - skip it
				continue

		// Skip targets that have recently paid tribute (immunity)
		if(controller.has_tribute_immunity(potential_target))
			continue

		// Check distance (O(1) instead of range()'s O(tiles))
		if(get_dist(ship, potential_target) > ship.territory_range)
			continue

		// Skip targets we can't see (blocked by nebula)
		if(!ship.has_los_to(potential_target))
			continue

		// Skip targets in different zones - pirates only engage within their own zone
		var/turf/target_loc = get_turf(potential_target)
		var/datum/overmap_zone/target_zone = SSovermap_zones.get_zone(target_loc)
		if(target_zone != zone)
			continue

		// Yellow zone: skip recently-scanned ships (scan memory)
		if(zone?.zone_type != ZONE_RED)
			var/list/scanned_ships = controller.blackboard[BB_NPC_SCANNED_SHIPS]
			if(scanned_ships)
				var/scanned_time = scanned_ships[REF(potential_target)]
				if(scanned_time && (world.time - scanned_time) < NPC_SCAN_MEMORY_TIME)
					continue  // Skip - we scanned this ship recently

		// Skip hulls with nobody alive aboard. There's nothing to rob off a ship whose crew
		// is dead or gone, and without this a pirate that had just wiped a crew and broken
		// off would re-acquire the same corpse ship on its next scan and start the whole
		// engagement over, with no one left aboard who could ever end it.
		// count_living_crew() returns -1 for a ship it can't read, which is not an empty one.
		// Left until last on purpose: it's the only check here that walks a list, so every
		// cheap rejection above it - distance, zone, line of sight - has already run.
		if(controller.count_living_crew(potential_target) == 0)
			continue

		// Found a valid target!
		log_shuttle("NPC_SHIP: [ship.name] targeting [potential_target.name] - dist=[get_dist(ship, potential_target)], territory=[ship.territory_range]")
		controller.set_target(potential_target)

		// Zone-based initial state: yellow -> scan wealth first, red -> hail/engage
		if(zone?.zone_type != ZONE_RED)
			// Yellow zone: scan target for wealth before engaging
			controller.set_combat_state(NPC_COMBAT_SCANNING)
			controller.blackboard[BB_NPC_SCAN_START_TIME] = world.time
			controller.blackboard[BB_NPC_SCAN_COMPLETE] = FALSE
			controller.blackboard[BB_NPC_SCAN_ANNOUNCED] = FALSE
		else if(istype(ship, /obj/structure/overmap/ship/npc/pirate))
			// Red zone: hail first (give player chance to respond)
			var/obj/structure/overmap/ship/npc/pirate/pirate_ship = ship
			// Only hail if no other pirate is already hailing/negotiating with this target
			if(pirate_ship.accepts_negotiation && !is_target_being_hailed(potential_target, ship))
				controller.set_combat_state(NPC_COMBAT_HAILING)
				controller.clear_blackboard_key(BB_NPC_HAILING_START)
				controller.clear_blackboard_key(BB_NPC_HAILING_ANNOUNCED)
			else
				controller.set_combat_state(NPC_COMBAT_ENGAGING)
		else
			controller.set_combat_state(NPC_COMBAT_ENGAGING)

		// Notify the target that they're being targeted
		SEND_SIGNAL(potential_target, COMSIG_SHIP_BEING_TARGETED, ship)

		return AI_BEHAVIOR_DELAY

	return AI_BEHAVIOR_DELAY

// ========== SCAN WEALTH ==========

/**
 * Scans the target ship for wealth before engaging.
 * Used by yellow zone pirates to check if target is worth robbing.
 * After scan completes, either engages (has money) or ignores (broke).
 */
/datum/bt_node/ai_behavior/npc_ship/scan_wealth
	time_between_perform = 0.5 SECONDS

/datum/bt_node/ai_behavior/npc_ship/scan_wealth/perform(seconds_per_tick, datum/ai_controller/npc_ship/controller)
	. = ..()

	var/obj/structure/overmap/ship/npc/ship = get_ship(controller)
	var/obj/structure/overmap/ship/target = controller.get_target()

	if(!ship || !target || QDELETED(target))
		controller.clear_target()
		return AI_BEHAVIOR_DELAY

	// Check if scan is complete
	var/scan_start = controller.blackboard[BB_NPC_SCAN_START_TIME]
	if(!scan_start)
		// Shouldn't happen, but reset
		controller.blackboard[BB_NPC_SCAN_START_TIME] = world.time
		return AI_BEHAVIOR_DELAY

	// Announce scan start (only once)
	if(!controller.blackboard[BB_NPC_SCAN_ANNOUNCED])
		controller.blackboard[BB_NPC_SCAN_ANNOUNCED] = TRUE
		ship.ship_notify("Initiating financial scan of [target.name]...", "SCANNER", SHIP_NOTIFY_NOTICE, 'voidcrew/sound/notify.ogg', 50)
		target.ship_notify("[ship.name] is scanning our financial systems!", "SECURITY", SHIP_NOTIFY_WARNING, 'voidcrew/sound/warn4.ogg', 25)
		// Start looping scan sound on target ship
		start_scan_sound(target)

	var/elapsed = world.time - scan_start
	if(elapsed < ship.scan_time)
		// Still scanning - just wait
		return AI_BEHAVIOR_DELAY

	// Scan complete! Stop the scan sound
	stop_scan_sound(target)

	// Record this ship as scanned
	controller.blackboard[BB_NPC_SCAN_COMPLETE] = TRUE
	var/list/scanned_ships = controller.blackboard[BB_NPC_SCANNED_SHIPS]
	if(!scanned_ships)
		scanned_ships = list()
		controller.blackboard[BB_NPC_SCANNED_SHIPS] = scanned_ships
	scanned_ships[REF(target)] = world.time

	// Check target's wealth
	var/target_wealth = target.ship_account?.account_balance || 0

	if(target_wealth >= ship.min_target_wealth)
		// Target has money - proceed based on zone
		ship.ship_notify("Scan complete. Target has [target_wealth] credits.", "SCANNER", SHIP_NOTIFY_NOTICE, 'voidcrew/sound/notify.ogg', 50)

		// Every band opens the same way: hail them and let the crew answer on the
		// holopad. What differs is what the hail is backed by once the grace period
		// runs out - red opens fire, yellow drains the accounts with the siphon
		// (see hail_escalates_to_siphon).
		if(istype(ship, /obj/structure/overmap/ship/npc/pirate))
			var/obj/structure/overmap/ship/npc/pirate/pirate_ship = ship
			if(pirate_ship.accepts_negotiation && !is_target_being_hailed(target, ship))
				target.ship_notify("[ship.name] is hailing your vessel!", "SECURITY", SHIP_NOTIFY_WARNING, 'voidcrew/sound/warn2.ogg', 25)
				controller.set_combat_state(NPC_COMBAT_HAILING)
				controller.clear_blackboard_key(BB_NPC_HAILING_START)
				controller.clear_blackboard_key(BB_NPC_HAILING_ANNOUNCED)
				controller.clear_blackboard_key("hailing_reminder_sent")
				return AI_BEHAVIOR_DELAY

		// Won't parley, or another pirate already has them on the line - skip the
		// courtesy. acquire_lock still branches on the band afterwards.
		var/turf/ship_loc = get_turf(ship)
		var/datum/overmap_zone/zone = SSovermap_zones.get_zone(ship_loc)
		if(zone?.zone_type == ZONE_RED)
			target.ship_notify("Hostile vessel has completed scan and is engaging!", "SECURITY", SHIP_NOTIFY_DANGER)
		else
			target.ship_notify("Hostile vessel has completed scan and is locking onto your ship!", "SECURITY", SHIP_NOTIFY_DANGER)
		controller.set_combat_state(NPC_COMBAT_ENGAGING)
	else
		// Target is broke. In yellow that isn't a reprieve - the pirate opens a
		// channel anyway and barters for cargo instead of credits. Refuse or ignore
		// them and a single crew-scaled boarding wave comes aboard (no boss).
		// Zone is read off the TARGET, not us: we sit up to territory_range tiles
		// away and would otherwise call off the raid every time we drifted over a
		// band line mid-scan.
		var/datum/overmap_zone/broke_zone = controller.get_raid_zone(target)
		var/obj/structure/overmap/ship/npc/pirate/pirate_ship = ship

		if(broke_zone?.zone_type == ZONE_YELLOW && istype(pirate_ship) && pirate_ship.uses_boarding_phases)
			if(length(pirate_ship.broke_lines))
				var/line = pick(pirate_ship.broke_lines)
				ship.ship_notify("[line]", "COMMS", SHIP_NOTIFY_NOTICE, 'voidcrew/sound/notify.ogg', 50)
				target.ship_notify("[ship.name]: \"[line]\"", "COMMS", SHIP_NOTIFY_DANGER, 'voidcrew/sound/alert3.ogg', 25)

			// Hail them for a cargo tribute. Answering the holopad opens a normal
			// negotiation that demands goods rather than money; ignoring the hail
			// runs out the grace period and drops boarders, same as red.
			if(pirate_ship.accepts_negotiation && !is_target_being_hailed(target, ship))
				controller.set_blackboard_key(BB_NPC_BROKE_BARTER, TRUE)
				controller.set_combat_state(NPC_COMBAT_HAILING)
				controller.clear_blackboard_key(BB_NPC_HAILING_START)
				controller.clear_blackboard_key(BB_NPC_HAILING_ANNOUNCED)
				controller.clear_blackboard_key("hailing_reminder_sent")
				return AI_BEHAVIOR_DELAY

			// No channel available (won't parley, or someone else has them on the
			// line) - skip the courtesy and board.
			if(controller.start_boarding_phase())
				return AI_BEHAVIOR_DELAY

		// Can't board them, so there's genuinely nothing here worth stopping for.
		ship.ship_notify("Scan complete. Target has insufficient funds ([target_wealth] credits). Disengaging.", "SCANNER", SHIP_NOTIFY_NOTICE, 'voidcrew/sound/notify.ogg', 50)
		target.ship_notify("Hostile scan complete. They found nothing of value and are disengaging.", "BROKEY ALERT", SHIP_NOTIFY_NOTICE, 'voidcrew/sound/notify.ogg', 50)
		controller.clear_target()

	return AI_BEHAVIOR_DELAY

/// Starts looping scan sound on the target ship
/datum/bt_node/ai_behavior/npc_ship/scan_wealth/proc/start_scan_sound(obj/structure/overmap/ship/target)
	if(!target?.shuttle?.shuttle_areas)
		return
	var/sound/scan_sound = sound('voidcrew/sound/econ_scan.ogg', repeat = TRUE, channel = CHANNEL_ECON_SCAN)
	for(var/area/shuttle_area as anything in target.shuttle.shuttle_areas)
		for(var/mob/M in shuttle_area)
			if(M.client)
				SEND_SOUND(M, scan_sound)

/// Stops the looping scan sound on the target ship
/datum/bt_node/ai_behavior/npc_ship/scan_wealth/proc/stop_scan_sound(obj/structure/overmap/ship/target)
	if(!target?.shuttle?.shuttle_areas)
		return
	var/sound/stop_sound = sound(null, channel = CHANNEL_ECON_SCAN)
	for(var/area/shuttle_area as anything in target.shuttle.shuttle_areas)
		for(var/mob/M in shuttle_area)
			if(M.client)
				SEND_SOUND(M, stop_sound)

// ========== HAILING ==========

/**
 * Hailing behavior - pirate is demanding tribute, waiting for player response.
 * During this phase:
 * - Pirate follows target but doesn't attack
 * - Player can answer via holopad → NEGOTIATING
 * - Player can escape (moving is OK during hailing)
 * - Player locks weapons → immediate COMBAT
 * - Player fires on pirate → immediate COMBAT
 * - 20 seconds pass without answer → escalation
 *
 * What "escalation" means depends on the hail: red opens fire, a broke target
 * gets boarded, and a yellow-band shakedown gets its accounts drained by the
 * siphon. See escalate_to_combat() and hail_escalates_to_siphon().
 */
/datum/bt_node/ai_behavior/npc_ship/hailing
	time_between_perform = 1 SECONDS

/datum/bt_node/ai_behavior/npc_ship/hailing/perform(seconds_per_tick, datum/ai_controller/npc_ship/controller)
	. = ..()

	var/obj/structure/overmap/ship/npc/pirate/ship = get_ship(controller)
	var/obj/structure/overmap/ship/target = controller.get_target()

	if(!ship || !target || QDELETED(target))
		controller.clear_target()
		return AI_BEHAVIOR_DELAY

	// Check if we've been attacked (player aggression)
	// This is handled by signal, but double-check here
	if(controller.blackboard[BB_NPC_TARGET_LOCKED])
		// We somehow got a lock during hailing - shouldn't happen, but handle it
		escalate_to_combat(controller, ship, target, "aggression")
		return AI_BEHAVIOR_DELAY

	// Send initial hail announcement (only once)
	if(!controller.blackboard[BB_NPC_HAILING_ANNOUNCED])
		controller.set_blackboard_key(BB_NPC_HAILING_ANNOUNCED, TRUE)
		controller.set_blackboard_key(BB_NPC_HAILING_START, world.time)

		// Announce to pirate ship
		ship.ship_notify("Hailing [target.name]. Awaiting response.", "COMMS", SHIP_NOTIFY_NOTICE, 'voidcrew/sound/notify.ogg', 50)

		// Announce to player ship - this is the key notification!
		// What sits on the other end of the timer depends on the hail: a broke
		// target gets a boarding party, a yellow-band shakedown gets the siphon,
		// and red gets a broadside.
		var/grace_seconds = round(NPC_HAILING_GRACE_PERIOD / 10)
		if(controller.blackboard[BB_NPC_BROKE_BARTER])
			target.ship_notify("INCOMING HAIL from [ship.name]! Report to comms array to respond. [grace_seconds] seconds before they board!", "PRIORITY", SHIP_NOTIFY_DANGER, 'voidcrew/sound/warn3.ogg', 25)
		else if(controller.hail_escalates_to_siphon())
			target.ship_notify("INCOMING HAIL from [ship.name]! Report to comms array to respond. [grace_seconds] seconds before they start draining your accounts!", "PRIORITY", SHIP_NOTIFY_DANGER, 'voidcrew/sound/warn3.ogg', 25)
		else
			target.ship_notify("INCOMING HAIL from [ship.name]! Report to comms array to respond. [grace_seconds] seconds before they open fire!", "PRIORITY", SHIP_NOTIFY_DANGER, 'voidcrew/sound/warn3.ogg', 25)

		// Make every holopad on the target ship ring
		target.start_hail_ringing()

	// Check timeout
	var/hail_start = controller.blackboard[BB_NPC_HAILING_START]
	if(!hail_start)
		controller.set_blackboard_key(BB_NPC_HAILING_START, world.time)
		return AI_BEHAVIOR_DELAY

	var/elapsed = world.time - hail_start

	// Send reminder at halfway point
	if(elapsed >= (NPC_HAILING_GRACE_PERIOD / 2) && elapsed < (NPC_HAILING_GRACE_PERIOD / 2) + 2 SECONDS)
		// Only send once (check if we're in the 2-second window after halfway)
		if(!controller.blackboard["hailing_reminder_sent"])
			controller.set_blackboard_key("hailing_reminder_sent", TRUE)
			var/remaining_seconds = round(NPC_HAILING_GRACE_PERIOD / 2 / 10)
			if(controller.blackboard[BB_NPC_BROKE_BARTER])
				target.ship_notify("[ship.name] is losing patience! [remaining_seconds] seconds until they board!", "URGENT", SHIP_NOTIFY_WARNING, 'voidcrew/sound/warn4.ogg', 25)
			else if(controller.hail_escalates_to_siphon())
				target.ship_notify("[ship.name] is losing patience! [remaining_seconds] seconds until they start draining your accounts!", "URGENT", SHIP_NOTIFY_WARNING, 'voidcrew/sound/warn4.ogg', 25)
			else
				target.ship_notify("[ship.name] is losing patience! [remaining_seconds] seconds until they open fire!", "URGENT", SHIP_NOTIFY_WARNING, 'voidcrew/sound/warn4.ogg', 25)

	// Check if grace period expired
	if(elapsed >= NPC_HAILING_GRACE_PERIOD)
		escalate_to_combat(controller, ship, target, "ignored")
		return AI_BEHAVIOR_DELAY

	return AI_BEHAVIOR_DELAY

/**
 * Escalate from HAILING to COMBAT - player ignored or aggressed.
 * If the ship uses boarding phases, starts phased boarding instead of ship combat.
 */
/datum/bt_node/ai_behavior/npc_ship/hailing/proc/escalate_to_combat(datum/ai_controller/npc_ship/controller, obj/structure/overmap/ship/npc/ship, obj/structure/overmap/ship/target, reason)
	// Clear hailing state
	controller.clear_blackboard_key(BB_NPC_HAILING_START)
	controller.clear_blackboard_key(BB_NPC_HAILING_ANNOUNCED)
	controller.clear_blackboard_key("hailing_reminder_sent")

	// Stop the holopads ringing
	target.stop_hail_ringing()

	// Announce escalation
	var/barter_hail = controller.blackboard[BB_NPC_BROKE_BARTER]
	var/siphon_hail = controller.hail_escalates_to_siphon()
	if(reason == "ignored" && barter_hail)
		ship.ship_notify("No response from target. Send the boarding party.", "COMMS", SHIP_NOTIFY_WARNING, 'voidcrew/sound/notify.ogg', 50)
		target.ship_notify("[ship.name] got no answer and is moving to board!", "COMBAT", SHIP_NOTIFY_DANGER)
	else if(reason == "ignored" && siphon_hail)
		ship.ship_notify("No response from target. Take it out of their accounts.", "COMMS", SHIP_NOTIFY_WARNING, 'voidcrew/sound/notify.ogg', 50)
		target.ship_notify("[ship.name] got no answer and is moving to drain your accounts!", "FINANCE", SHIP_NOTIFY_DANGER)
	else if(reason == "ignored")
		ship.ship_notify("No response from target. Engaging.", "COMMS", SHIP_NOTIFY_WARNING, 'voidcrew/sound/notify.ogg', 50)
		target.ship_notify("[ship.name] has received no response and is engaging!", "COMBAT", SHIP_NOTIFY_DANGER)
	else if(reason == "aggression")
		ship.ship_notify("Hostile action detected! Engaging!", "COMBAT", SHIP_NOTIFY_WARNING, 'voidcrew/sound/notify.ogg', 50)
		target.ship_notify("[ship.name] is retaliating to hostile action!", "COMBAT", SHIP_NOTIFY_DANGER)
	else if(reason == "negotiation_failed")
		ship.ship_notify("Negotiations failed. Engaging target.", "COMMS", SHIP_NOTIFY_WARNING, 'voidcrew/sound/notify.ogg', 50)
		target.ship_notify("Negotiations with [ship.name] have failed! Brace for combat!", "COMBAT", SHIP_NOTIFY_DANGER)

	// Yellow-band shakedown: no guns, no boarders, they just take it. Lock up and
	// acquire_lock hands off to SIPHONING.
	if(siphon_hail)
		controller.set_combat_state(NPC_COMBAT_ENGAGING)
		return

	// Check if we should use phased boarding (only for ignored/negotiation_failed, not aggression)
	if(reason != "aggression")
		var/obj/structure/overmap/ship/npc/pirate/pirate_ship = ship
		if(istype(pirate_ship) && pirate_ship.uses_boarding_phases)
			if(controller.start_boarding_phase())
				return  // Successfully started boarding phase

	// Fallback: Transition to ENGAGING (will acquire lock then fight)
	controller.set_combat_state(NPC_COMBAT_ENGAGING)

// ========== ACQUIRE LOCK ==========

/**
 * Works on acquiring a weapon lock on the target.
 * After NPC_SHIP_LOCK_TIME seconds, transitions to COMBAT state.
 */
/datum/bt_node/ai_behavior/npc_ship/acquire_lock
	time_between_perform = 0.5 SECONDS

/datum/bt_node/ai_behavior/npc_ship/acquire_lock/perform(seconds_per_tick, datum/ai_controller/npc_ship/controller)
	. = ..()

	var/obj/structure/overmap/ship/npc/ship = get_ship(controller)
	var/obj/structure/overmap/ship/target = controller.get_target()

	if(!ship || !target || QDELETED(target))
		controller.clear_target()
		return AI_BEHAVIOR_DELAY

	// Check if target escaped somewhere we can't shoot them - abort lock.
	// Their band, not ours: we sit up to territory_range tiles off and would
	// otherwise drop the lock every time the two of us straddle a boundary.
	if(controller.target_reached_sanctuary(target))
		controller.clear_target()
		return AI_BEHAVIOR_DELAY

	// Check if already locked
	if(controller.blackboard[BB_NPC_TARGET_LOCKED])
		return AI_BEHAVIOR_DELAY

	// Check if we've started the lock
	var/lock_start = controller.blackboard[BB_NPC_LOCK_START_TIME]
	if(!lock_start)
		// Start the lock - alert the target ship (like combat console does)
		target.ship_notify("Hostile ship acquiring weapons lock!", "WARNING", SHIP_NOTIFY_WARNING, 'voidcrew/sound/alert2.ogg', 25)
		controller.set_blackboard_key(BB_NPC_LOCK_START_TIME, world.time)
		return AI_BEHAVIOR_DELAY

	// Check if lock is complete (uses per-ship lock time)
	if(world.time >= lock_start + ship.lock_time)
		// Lock acquired!
		controller.set_blackboard_key(BB_NPC_TARGET_LOCKED, TRUE)

		// Branch based on the target's band: yellow -> siphon, red -> full combat.
		// A ship with no siphon goal (customs assesses fines instead) has nothing
		// to do in SIPHONING, so don't park it there - COMBAT still leaves it the
		// interdictor, which is all the band allows anyway.
		if(!controller.is_red_zone_raid() && ship.siphon_goal_percent > 0)
			controller.set_combat_state(NPC_COMBAT_SIPHONING)
		else
			controller.set_combat_state(NPC_COMBAT_COMBAT)

		// Notify the target via signal (for cloak device etc)
		SEND_SIGNAL(target, COMSIG_SHIP_WEAPONS_LOCKED, ship)

		// Announce lock complete to target ship
		target.ship_notify("Hostile weapons lock completed!", "THREAT", SHIP_NOTIFY_DANGER)

	return AI_BEHAVIOR_DELAY

// ========== FIRE WEAPONS ==========

/**
 * Handles weapon firing logic.
 * - If target has shields: use lasers (effective vs shields)
 * - If target shields are down: use missiles (effective vs hull)
 */
/datum/bt_node/ai_behavior/npc_ship/fire_weapons
	time_between_perform = 2 SECONDS  // Increased from 1s for balance
	combat_action = NPC_ACTION_FIRE_WEAPONS

/datum/bt_node/ai_behavior/npc_ship/fire_weapons/perform(seconds_per_tick, datum/ai_controller/npc_ship/controller)
	. = ..()

	var/obj/structure/overmap/ship/npc/ship = get_ship(controller)
	var/datum/npc_combat_interface/combat = get_combat_interface(controller)
	var/obj/structure/overmap/ship/target = controller.get_target()

	if(!ship || !combat || !target || QDELETED(target))
		return AI_BEHAVIOR_DELAY

	// Check if weapons are allowed in this zone
	if(!SSovermap_zones.weapons_allowed_at(ship))
		return AI_BEHAVIOR_DELAY

	// Determine weapon choice based on target shield status
	var/target_has_shields = target.shields_active && target.shield_health > 0

	if(target_has_shields)
		// Target has shields - use lasers (effective vs shields)
		// Fall back to missiles if we have no working lasers
		if(!try_fire_lasers(ship, combat, target))
			try_fire_missiles(ship, combat, target, skip_laser_fallback = TRUE)
	else
		// Target shields down - use missiles (effective vs hull)
		try_fire_missiles(ship, combat, target)

	return AI_BEHAVIOR_DELAY

/**
 * Attempts to fire lasers at the target.
 */
/datum/bt_node/ai_behavior/npc_ship/fire_weapons/proc/try_fire_lasers(obj/structure/overmap/ship/npc/ship, datum/npc_combat_interface/combat, obj/structure/overmap/ship/target)
	// Check global cooldown first - prevents spam across all weapon types
	if(!COOLDOWN_FINISHED(ship, global_weapon_cooldown))
		return FALSE

	// Check laser-specific cooldown
	if(!COOLDOWN_FINISHED(ship, laser_cooldown))
		return FALSE

	var/working_lasers = combat.get_working_laser_count()
	if(working_lasers < 1)
		return FALSE

	// Decide whether to fire all or single
	var/fire_all = FALSE
	if(working_lasers >= 2)
		// 20% chance to fire all, 80% chance to fire single (reduced for balance)
		fire_all = prob(20)

	// Fire! (uses per-ship laser cooldown)
	if(combat.fire_lasers(target, fire_all))
		COOLDOWN_START(ship, laser_cooldown, ship.laser_cooldown_time)
		COOLDOWN_START(ship, global_weapon_cooldown, ship.global_weapon_cooldown_time)
		return TRUE

	return FALSE

/**
 * Attempts to fire missiles at the target.
 */
/datum/bt_node/ai_behavior/npc_ship/fire_weapons/proc/try_fire_missiles(obj/structure/overmap/ship/npc/ship, datum/npc_combat_interface/combat, obj/structure/overmap/ship/target, skip_laser_fallback = FALSE)
	// Check global cooldown first - prevents spam across all weapon types
	if(!COOLDOWN_FINISHED(ship, global_weapon_cooldown))
		return FALSE

	// Check missile-specific cooldown
	if(!COOLDOWN_FINISHED(ship, missile_cooldown))
		// Fallback to lasers if available
		if(!skip_laser_fallback)
			try_fire_lasers(ship, combat, target)
		return FALSE

	var/launcher_count = combat.get_working_launcher_count()
	if(launcher_count < 1)
		// No launchers, try lasers instead
		if(!skip_laser_fallback)
			try_fire_lasers(ship, combat, target)
		return FALSE

	// Fire missile (uses per-ship missile cooldown)
	if(combat.fire_missile(target))
		COOLDOWN_START(ship, missile_cooldown, ship.missile_cooldown_time)
		COOLDOWN_START(ship, global_weapon_cooldown, ship.global_weapon_cooldown_time)
		return TRUE

	return FALSE

// ========== FIRE BOARDING PODS ==========

/**
 * Fires boarding pods at the target ship when shields are down.
 * Pods deliver hostile mobs directly onto the target ship.
 * Used as an alternative to missiles to add lethality without relying solely on ordnance.
 */
/datum/bt_node/ai_behavior/npc_ship/fire_boarding_pods
	time_between_perform = 3 SECONDS
	combat_action = NPC_ACTION_FIRE_BOARDING_PODS

/datum/bt_node/ai_behavior/npc_ship/fire_boarding_pods/perform(seconds_per_tick, datum/ai_controller/npc_ship/controller)
	. = ..()

	var/obj/structure/overmap/ship/npc/pirate/ship = get_ship(controller)
	var/datum/npc_combat_interface/combat = get_combat_interface(controller)
	var/obj/structure/overmap/ship/target = controller.get_target()

	if(!ship || !combat || !target || QDELETED(target))
		return AI_BEHAVIOR_DELAY

	// Only pirate ships can launch boarding pods
	if(!istype(ship))
		return AI_BEHAVIOR_DELAY

	// Check if boarding pods are enabled for this ship
	if(!ship.boarding_pods_enabled)
		return AI_BEHAVIOR_DELAY

	// Check global cooldown first - prevents spam across all weapon types
	if(!COOLDOWN_FINISHED(ship, global_weapon_cooldown))
		return AI_BEHAVIOR_DELAY

	// Check cooldown - use the ship combat pod cooldown (15 seconds)
	if(!COOLDOWN_FINISHED(ship, boarding_pod_cooldown))
		return AI_BEHAVIOR_DELAY

	// Check if weapons are allowed in this zone
	if(!SSovermap_zones.weapons_allowed_at(ship))
		return AI_BEHAVIOR_DELAY

	// IMPORTANT: Only fire pods when target shields are DOWN
	// Shields would destroy the pods before they could deliver boarders
	var/target_has_shields = target.shields_active && target.shield_health > 0
	if(target_has_shields)
		return AI_BEHAVIOR_DELAY

	// Check if we've hit the max boarder cap (10 mobs max during ship combat)
	var/current_boarders = count_hostile_mobs_on_ship(target)
	if(current_boarders >= NPC_SHIP_COMBAT_MAX_BOARDERS)
		return AI_BEHAVIOR_DELAY

	// Calculate number of pods to launch (don't exceed the cap)
	var/pod_count = rand(ship.boarding_pods_min, ship.boarding_pods_max)
	pod_count = min(pod_count, NPC_SHIP_COMBAT_MAX_BOARDERS - current_boarders)
	if(pod_count <= 0)
		return AI_BEHAVIOR_DELAY

	// Fire the boarding pods!
	if(combat.fire_boarding_pods(target, pod_count))
		COOLDOWN_START(ship, boarding_pod_cooldown, NPC_SHIP_COMBAT_POD_COOLDOWN)
		COOLDOWN_START(ship, global_weapon_cooldown, ship.global_weapon_cooldown_time)
		// Announce the boarding action
		target.ship_notify("Multiple boarding pods inbound! Prepare to repel boarders!", "SECURITY", SHIP_NOTIFY_DANGER, 'voidcrew/sound/warn3.ogg', 25)

	return AI_BEHAVIOR_DELAY

/**
 * Count hostile mobs (pirate troopers) currently on a target ship.
 * Used to enforce the max boarder cap during ship combat.
 */
/datum/bt_node/ai_behavior/npc_ship/fire_boarding_pods/proc/count_hostile_mobs_on_ship(obj/structure/overmap/ship/target)
	if(!target?.shuttle?.shuttle_areas)
		return 0

	var/count = 0
	for(var/area/shuttle_area as anything in target.shuttle.shuttle_areas)
		for(var/mob/living/basic/trooper/pirate/boarder in shuttle_area)
			if(boarder.stat != DEAD)
				count++
	return count

// ========== USE INTERDICTOR ==========

/**
 * Attempts to use the interdictor on the target.
 * NPCs will aggressively interdict to prevent escape.
 */
/datum/bt_node/ai_behavior/npc_ship/use_interdictor
	time_between_perform = 3 SECONDS  // Increased from 2s for balance
	combat_action = NPC_ACTION_USE_INTERDICTOR

/datum/bt_node/ai_behavior/npc_ship/use_interdictor/perform(seconds_per_tick, datum/ai_controller/npc_ship/controller)
	. = ..()

	var/obj/structure/overmap/ship/npc/ship = get_ship(controller)
	var/datum/npc_combat_interface/combat = get_combat_interface(controller)
	var/obj/structure/overmap/ship/target = controller.get_target()

	if(!ship || !combat || !target || QDELETED(target))
		return AI_BEHAVIOR_DELAY

	// Check if we have a working interdictor
	if(!combat.has_working_interdictor())
		return AI_BEHAVIOR_DELAY

	// Check if target is already interdicted
	if(target.is_interdicted)
		// Clear commitment since interdiction is complete
		controller.clear_blackboard_key(BB_NPC_INTERDICTOR_START_TIME)
		return AI_BEHAVIOR_DELAY

	// Try to interdict! (aggressively - don't wait for target to start moving)
	if(combat.start_interdiction(target))
		// Record commitment start time - other actions delayed while committed
		controller.set_blackboard_key(BB_NPC_INTERDICTOR_START_TIME, world.time)

	return AI_BEHAVIOR_DELAY

// ========== CHECK CREW WIPE ==========

/**
 * Breaks the engagement off once there's nobody left alive on the target.
 *
 * Runs in every state where we're actually doing something to a crew - ship weapons,
 * boarding waves, the boss phase - because all of them can finish a crew off and none of
 * them noticed. Pods fired from normal ship combat (fire_boarding_pods) never registered
 * anything at all, so a pirate that wiped a hull that way would go on shelling the corpse
 * and holding the interdiction indefinitely.
 *
 * The controller owns the actual "is anyone left" judgement and its grace window; this
 * just polls it. See check_crew_eliminated().
 */
/datum/bt_node/ai_behavior/npc_ship/check_crew_wipe
	time_between_perform = 5 SECONDS

/datum/bt_node/ai_behavior/npc_ship/check_crew_wipe/perform(seconds_per_tick, datum/ai_controller/npc_ship/controller)
	. = ..()

	var/obj/structure/overmap/ship/target = controller.get_target()
	if(!target || QDELETED(target))
		return AI_BEHAVIOR_DELAY

	controller.check_crew_eliminated(target)

	return AI_BEHAVIOR_DELAY

// ========== CHECK DISENGAGE ==========

/**
 * Checks if the target has moved out of territory range, left our zone, or crashed.
 * If so, clears the target and returns to IDLE state.
 */
/datum/bt_node/ai_behavior/npc_ship/check_disengage
	time_between_perform = 1 SECONDS

/datum/bt_node/ai_behavior/npc_ship/check_disengage/perform(seconds_per_tick, datum/ai_controller/npc_ship/controller)
	. = ..()

	var/obj/structure/overmap/ship/npc/ship = get_ship(controller)
	var/obj/structure/overmap/ship/target = controller.get_target()

	// No target means nothing to disengage from
	if(!target || QDELETED(target))
		if(controller.get_combat_state() != NPC_COMBAT_IDLE)
			controller.clear_target()
		return AI_BEHAVIOR_DELAY

	if(!ship)
		return AI_BEHAVIOR_DELAY

	// Check if target cloaked - lose tracking
	if(target.invisibility > INVISIBILITY_NONE)
		SEND_SIGNAL(target, COMSIG_SHIP_TARGETING_STOPPED, ship)
		controller.clear_target()
		return AI_BEHAVIOR_DELAY

	// Check if line of sight is blocked (e.g., by a nebula) - lose tracking
	if(!ship.has_los_to(target))
		SEND_SIGNAL(target, COMSIG_SHIP_TARGETING_STOPPED, ship)
		controller.clear_target()
		return AI_BEHAVIOR_DELAY

	// Check if target has crashed (no longer flying) - don't attack crashed ships
	if(target.state != OVERMAP_SHIP_FLYING)
		SEND_SIGNAL(target, COMSIG_SHIP_TARGETING_STOPPED, ship)
		controller.clear_target()
		return AI_BEHAVIOR_DELAY

	// Check if target escaped to a different zone - lose target entirely.
	// Unconfined hunters chase across zone lines instead.
	if(ship.zone_confined)
		var/turf/ship_turf = get_turf(ship)
		var/turf/target_turf = get_turf(target)
		if(ship_turf && target_turf)
			var/datum/overmap_zone/ship_zone = SSovermap_zones.get_zone(ship_turf)
			var/datum/overmap_zone/target_zone = SSovermap_zones.get_zone(target_turf)
			if(ship_zone != target_zone)
				SEND_SIGNAL(target, COMSIG_SHIP_TARGETING_STOPPED, ship)
				controller.clear_target()
				return AI_BEHAVIOR_DELAY

	// Check if another (active, non-disabled) pirate is engaging this target - yield to them
	// Exception: don't yield if we're actively boarding - we have priority
	var/combat_state = controller.get_combat_state()
	var/is_boarding = (combat_state == NPC_COMBAT_BOARDING || combat_state == NPC_COMBAT_BOARDING_COOLDOWN || combat_state == NPC_COMBAT_BOSS_PHASE)
	var/obj/structure/overmap/ship/npc/engaging_pirate = target.engaging_pirate_ref?.resolve()
	if(engaging_pirate && engaging_pirate != ship && !QDELETED(engaging_pirate) && !engaging_pirate.is_disabled && !is_boarding)
		SEND_SIGNAL(target, COMSIG_SHIP_TARGETING_STOPPED, ship)
		controller.clear_target()
		return AI_BEHAVIOR_DELAY

	// Check distance to target
	var/target_dist = get_dist(ship, target)

	// If target is out of range, disengage
	if(target_dist > ship.territory_range)
		// Notify target that we stopped targeting them
		SEND_SIGNAL(target, COMSIG_SHIP_TARGETING_STOPPED, ship)
		controller.clear_target()

	return AI_BEHAVIOR_DELAY

// ========== RETREAT ESCAPE ==========

/**
 * Escape behavior for retreating ships.
 * Checks every escape condition FIRST, then handles interdiction/cloaking.
 * If interdicted: tries to shield burst to break free.
 * If not interdicted (or just broke free): tries to cloak.
 */
/datum/bt_node/ai_behavior/npc_ship/retreat_escape
	time_between_perform = 1 SECONDS

/datum/bt_node/ai_behavior/npc_ship/retreat_escape/perform(seconds_per_tick, datum/ai_controller/npc_ship/controller)
	. = ..()

	var/obj/structure/overmap/ship/npc/ship = get_ship(controller)
	var/datum/npc_combat_interface/combat = get_combat_interface(controller)

	if(!ship || !combat)
		return AI_BEHAVIOR_DELAY

	// ===== Escape conditions, all evaluated BEFORE the interdiction branch. The old
	// shape early-returned every tick while interdicted and never read its own exit
	// conditions, and its only exit needed 15+ tiles of separation - which a
	// zone-confined ship fleeing a chaser that stays put can never open. Round 4 left
	// two pirates wedged here for 21 hours. =====

	var/datum/weakref/last_target_ref = controller.blackboard[BB_NPC_LAST_TARGET]
	var/obj/structure/overmap/ship/last_target = last_target_ref?.resolve()

	// Nothing left worth fleeing: chaser gone, docked/crashed, or nobody alive aboard.
	// count_living_crew() returns -1 for a ship it can't read - that is not an empty one.
	if(!last_target || QDELETED(last_target) || last_target.state != OVERMAP_SHIP_FLYING || controller.count_living_crew(last_target) == 0)
		return_to_patrol(controller)
		return AI_BEHAVIOR_DELAY

	// Clean escape - far enough away
	var/turf/our_loc = get_turf(ship)
	var/turf/target_loc = get_turf(last_target)
	var/distance = (our_loc && target_loc) ? get_dist(our_loc, target_loc) : null
	if(!isnull(distance) && distance >= 15)
		return_to_patrol(controller)
		return AI_BEHAVIOR_DELAY

	// Timed out - the chaser is still around but the encounter is over. Write it off
	// and go back to hunting rather than shuffling along a band boundary forever.
	var/retreat_start = controller.blackboard[BB_NPC_RETREAT_START]
	if(!retreat_start)
		retreat_start = world.time
		controller.set_blackboard_key(BB_NPC_RETREAT_START, retreat_start)
	if(world.time - retreat_start > NPC_RETREAT_TIME_LIMIT)
		log_shuttle("NPC_SHIP: [ship.name] retreat timed out at [isnull(distance) ? "?" : distance]/15 tiles from [last_target.name] - returning to patrol")
		return_to_patrol(controller)
		return AI_BEHAVIOR_DELAY

	// ===== Still fleeing =====

	// If interdicted, try to break free with shield burst
	if(ship.is_interdicted)
		if(ship.can_burst_shields())
			ship.burst_shields_break_interdiction()
			// After bursting, immediately try to cloak
			if(combat.has_working_cloak())
				combat.activate_cloak()
		return AI_BEHAVIOR_DELAY

	// Not interdicted - try to cloak if we haven't already
	if(ship.invisibility <= INVISIBILITY_NONE && combat.has_working_cloak())
		combat.activate_cloak()

	return AI_BEHAVIOR_DELAY

/// Helper proc to transition retreating ship back to patrol
/datum/bt_node/ai_behavior/npc_ship/retreat_escape/proc/return_to_patrol(datum/ai_controller/npc_ship/controller)
	// Read who we were fleeing before clearing it - a disarmed ship's victim gets told
	// the hunt is over for good.
	var/datum/weakref/last_target_ref = controller.blackboard[BB_NPC_LAST_TARGET]
	var/obj/structure/overmap/ship/last_target = last_target_ref?.resolve()
	// Clear retreat state
	controller.blackboard[BB_NPC_RETREAT_REASON] = null
	controller.blackboard[BB_NPC_LAST_TARGET] = null
	controller.clear_blackboard_key(BB_NPC_RETREAT_START)
	// Return to idle/patrol
	controller.clear_target()
	controller.set_blackboard_key(BB_NPC_MOVEMENT_MODE, NPC_MOVEMENT_PATROL)

	// Disarmed ships are out of the fight for good: scan_threats refuses to acquire
	// for a hull with no intact weapons, so free its pool slot for a replacement
	// instead of leaving a toothless hulk holding a spawn budget forever. Keyed on
	// physical disarmament rather than the retreat reason - guns blown off mid-siphon
	// end the career just the same. The hull itself stays in the world: crew aboard,
	// hold full, boardable.
	var/obj/structure/overmap/ship/npc/ship = get_ship(controller)
	var/datum/npc_combat_interface/combat = get_combat_interface(controller)
	if(!ship || !combat || combat.has_intact_weapons())
		return

	ship.notify_spawner_resolved("disarmed")
	last_target?.ship_notify("[ship.name] is disarmed and has broken off for good.", "COMBAT", SHIP_NOTIFY_NOTICE, 'voidcrew/sound/notify.ogg', 25)

// ========== ACTIVATE SIPHON ==========

/**
 * Activates the ship's data siphon when weapons lock is achieved.
 * Pirates use this to steal credits from locked targets.
 */
/datum/bt_node/ai_behavior/npc_ship/activate_siphon
	time_between_perform = 3 SECONDS  // Increased from 2s for balance
	combat_action = NPC_ACTION_ACTIVATE_SIPHON

/datum/bt_node/ai_behavior/npc_ship/activate_siphon/perform(seconds_per_tick, datum/ai_controller/npc_ship/controller)
	. = ..()

	var/obj/structure/overmap/ship/npc/ship = get_ship(controller)
	var/obj/structure/overmap/ship/target = controller.get_target()

	if(!ship || !target || QDELETED(target))
		return AI_BEHAVIOR_DELAY

	// Only siphon if we have lock
	if(!controller.blackboard[BB_NPC_TARGET_LOCKED])
		return AI_BEHAVIOR_DELAY

	// Find our data siphon and activate it
	var/obj/machinery/shuttle_scrambler/ship_siphon/siphon
	for(var/area/shuttle_area as anything in ship.shuttle?.shuttle_areas)
		siphon = locate(/obj/machinery/shuttle_scrambler/ship_siphon) in shuttle_area
		if(siphon)
			break

	if(siphon && !siphon.active && !siphon.warming_up)
		// Copy the ship's siphon goal percentage to the siphon
		siphon.siphon_goal_percent = ship.siphon_goal_percent
		if(siphon.activate_siphon(target))
			// Record commitment start time - other actions delayed while committed
			controller.set_blackboard_key(BB_NPC_SIPHON_START_TIME, world.time)

	return AI_BEHAVIOR_DELAY

// ========== CHECK WEAPONS ==========

/**
 * Checks if the ship still has functional weapons.
 * If all weapons are destroyed, transitions to RETREATING state.
 */
/datum/bt_node/ai_behavior/npc_ship/check_weapons
	time_between_perform = 2 SECONDS

/datum/bt_node/ai_behavior/npc_ship/check_weapons/perform(seconds_per_tick, datum/ai_controller/npc_ship/controller)
	. = ..()

	var/obj/structure/overmap/ship/npc/ship = get_ship(controller)
	var/datum/npc_combat_interface/combat = get_combat_interface(controller)

	if(!ship || !combat)
		return AI_BEHAVIOR_DELAY

	// If we have no weapons and ship type retreats without weapons, enter retreat mode
	if(!combat.has_any_weapons() && ship.retreat_without_weapons)
		controller.blackboard[BB_NPC_RETREAT_REASON] = "no_weapons"
		// set_combat_state stores BB_NPC_LAST_TARGET automatically when entering retreat
		controller.set_combat_state(NPC_COMBAT_RETREATING)
		controller.set_blackboard_key(BB_NPC_MOVEMENT_MODE, NPC_MOVEMENT_RETREAT)
		ship.ship_notify("All weapons systems offline! Initiating emergency retreat!", "CRITICAL", SHIP_NOTIFY_DANGER, 'voidcrew/sound/warn3.ogg', 25)

	return AI_BEHAVIOR_DELAY

// ========== BOARDING PHASE BEHAVIORS ==========

/**
 * Monitors the active boarding wave.
 * This behavior runs during NPC_COMBAT_BOARDING state.
 * Checks for escalation conditions: time limit, movement, player aggression.
 */
/datum/bt_node/ai_behavior/npc_ship/boarding_wave_monitor
	time_between_perform = 2 SECONDS

/datum/bt_node/ai_behavior/npc_ship/boarding_wave_monitor/perform(seconds_per_tick, datum/ai_controller/npc_ship/controller)
	. = ..()

	// Verify we're still in boarding state
	if(controller.get_combat_state() != NPC_COMBAT_BOARDING)
		return AI_BEHAVIOR_DELAY

	var/obj/structure/overmap/ship/npc/ship = controller.get_ship()
	var/obj/structure/overmap/ship/target = controller.get_target()

	if(!ship || !target || QDELETED(target))
		return AI_BEHAVIOR_DELAY

	// Check 0: Target escaped somewhere we can't follow - fully disengage.
	// Judged on the target's own band, not on ship-vs-target equality: the two
	// straddle a boundary constantly at these engagement ranges, and aborting on
	// that killed raids seconds after they started.
	if(controller.target_reached_sanctuary(target))
		ship.ship_notify("Target has escaped to a patrolled sector. Aborting boarding operation.", "COMBAT", SHIP_NOTIFY_NOTICE)
		controller.abort_boarding()
		return AI_BEHAVIOR_DELAY

	// Check 1: Wave time limit exceeded (cheesing by walling off boarders)
	// Instead of escalating to combat, advance to the next wave
	// Only escalate to ship combat if ALL waves time out (none defeated)
	var/wave_start = controller.blackboard[BB_NPC_BOARDING_WAVE_START_TIME]
	if(wave_start && world.time >= wave_start + NPC_BOARDING_WAVE_TIME_LIMIT)
		controller.handle_wave_timeout()
		return AI_BEHAVIOR_DELAY

	// Check 2: Periodically check if boarders fell into space
	var/last_space_check = controller.blackboard[BB_NPC_BOARDING_LAST_SPACE_CHECK] || 0
	if(world.time >= last_space_check + NPC_BOARDING_SPACE_CHECK_INTERVAL)
		controller.set_blackboard_key(BB_NPC_BOARDING_LAST_SPACE_CHECK, world.time)
		controller.check_boarders_in_space()

	// Check 3: Target has moved within same zone (trying to escape but still in range)
	var/list/initial_pos = controller.blackboard[BB_NPC_BOARDING_TARGET_POS]
	if(initial_pos && length(initial_pos) >= 2)
		if(target.x != initial_pos[1] || target.y != initial_pos[2])
			ship.ship_notify("Target is trying to escape! Weapons free!", "COMBAT", SHIP_NOTIFY_WARNING, 'voidcrew/sound/alert2.ogg', 25)
			target.ship_notify("[ship.name]: \"Running won't save you! All guns, fire!\"", "COMMS", SHIP_NOTIFY_DANGER, 'voidcrew/sound/alert3.ogg', 25)
			controller.escalate_boarding_to_combat("movement")
			return AI_BEHAVIOR_DELAY

	// Note: Player weapons lock is handled via COMSIG_SHIP_WEAPONS_LOCKED signal in controller

	return AI_BEHAVIOR_DELAY

/**
 * Monitors the cooldown between waves.
 * During cooldown, the pirate ship waits for the timer to expire.
 */
/datum/bt_node/ai_behavior/npc_ship/boarding_cooldown_monitor
	time_between_perform = 1 SECONDS

/datum/bt_node/ai_behavior/npc_ship/boarding_cooldown_monitor/perform(seconds_per_tick, datum/ai_controller/npc_ship/controller)
	. = ..()

	// Verify we're in cooldown state
	if(controller.get_combat_state() != NPC_COMBAT_BOARDING_COOLDOWN)
		return AI_BEHAVIOR_DELAY

	var/obj/structure/overmap/ship/npc/ship = controller.get_ship()
	var/obj/structure/overmap/ship/target = controller.get_target()

	if(!ship || !target || QDELETED(target))
		return AI_BEHAVIOR_DELAY

	// Check if target escaped somewhere we can't follow - fully disengage.
	// Their band, not ship-vs-target equality (see boarding_wave_monitor).
	if(controller.target_reached_sanctuary(target))
		ship.ship_notify("Target has escaped to a patrolled sector. Aborting boarding operation.", "COMBAT", SHIP_NOTIFY_NOTICE)
		controller.abort_boarding()
		return AI_BEHAVIOR_DELAY

	// Check if cooldown has expired (timer handles the actual transition)
	var/cooldown_end = controller.blackboard[BB_NPC_BOARDING_COOLDOWN_END]
	if(cooldown_end && world.time >= cooldown_end)
		// Timer should have fired, but just in case
		return AI_BEHAVIOR_DELAY

	return AI_BEHAVIOR_DELAY

/**
 * Monitors the boss phase.
 * During boss phase, we wait for the boss to be killed.
 */
/datum/bt_node/ai_behavior/npc_ship/boss_phase_monitor
	time_between_perform = 2 SECONDS

/datum/bt_node/ai_behavior/npc_ship/boss_phase_monitor/perform(seconds_per_tick, datum/ai_controller/npc_ship/controller)
	. = ..()

	// Verify we're in boss phase
	if(controller.get_combat_state() != NPC_COMBAT_BOSS_PHASE)
		return AI_BEHAVIOR_DELAY

	var/obj/structure/overmap/ship/npc/ship = controller.get_ship()
	var/obj/structure/overmap/ship/target = controller.get_target()

	if(!ship || !target || QDELETED(target))
		return AI_BEHAVIOR_DELAY

	// Check if target escaped somewhere we can't follow - fully disengage.
	// Their band, not ship-vs-target equality (see boarding_wave_monitor).
	if(controller.target_reached_sanctuary(target))
		ship.ship_notify("Target has escaped to a patrolled sector. Aborting boarding operation.", "COMBAT", SHIP_NOTIFY_NOTICE)
		controller.abort_boarding()
		return AI_BEHAVIOR_DELAY

	// Check if boss still exists
	var/mob/living/boss = controller.blackboard[BB_NPC_BOARDING_BOSS]
	if(!boss || QDELETED(boss) || boss.stat == DEAD)
		// Boss is dead - controller should handle this via signal
		return AI_BEHAVIOR_DELAY

	return AI_BEHAVIOR_DELAY

/**
 * Handles the disengaging state after pirates win.
 * The pirate ship leaves the area.
 */
/datum/bt_node/ai_behavior/npc_ship/disengage
	time_between_perform = 1 SECONDS

/datum/bt_node/ai_behavior/npc_ship/disengage/perform(seconds_per_tick, datum/ai_controller/npc_ship/controller)
	. = ..()

	// Verify we're in disengage state
	if(controller.get_combat_state() != NPC_COMBAT_DISENGAGING)
		return AI_BEHAVIOR_DELAY

	// The controller handles the actual disengage timer
	// This behavior just ensures we don't do anything else

	return AI_BEHAVIOR_DELAY

/**
 * Handles the disabled state.
 * Ship is dead in the water, waiting to be boarded.
 */
/datum/bt_node/ai_behavior/npc_ship/disabled
	time_between_perform = 5 SECONDS

/datum/bt_node/ai_behavior/npc_ship/disabled/perform(seconds_per_tick, datum/ai_controller/npc_ship/controller)
	. = ..()

	// Verify we're in disabled state
	if(controller.get_combat_state() != NPC_COMBAT_DISABLED)
		return AI_BEHAVIOR_DELAY

	// Ship is disabled - nothing to do
	// Players can now board and claim it

	return AI_BEHAVIOR_DELAY

/**
 * Handles the negotiating state.
 * Negotiating ships do no combat at all - the negotiation datum owns the timeout and
 * resolution, and this behavior just holds the tick so nothing else runs.
 *
 * VOIDCREW: the old subtree expressed this as a bare `return` with nothing queued. In a
 * behavior tree an empty branch has to still consume the tick (return BT_RUNNING), because
 * a branch that FAILED would let the selector fall through to a lower-priority state.
 */
/datum/bt_node/ai_behavior/npc_ship/negotiation_hold
	time_between_perform = 1 SECONDS

/datum/bt_node/ai_behavior/npc_ship/negotiation_hold/perform(seconds_per_tick, datum/ai_controller/npc_ship/controller)
	return AI_BEHAVIOR_DELAY
