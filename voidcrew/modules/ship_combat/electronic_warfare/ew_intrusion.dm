/**
 * Ship EW Intrusion - target-side tracker for active electronic warfare
 *
 * Attached to the TARGET overmap ship by the first payload that lands
 * (via LoadComponent in /datum/ew_payload/New). Tracks every active payload,
 * warns the crew as payloads stack up, and lets the crew purge the intrusion
 * from their own weapons console - ending all payloads early and hardening
 * the ship's firewalls against reconnection for EW_PURGE_HARDENED_TIME.
 *
 * NPC crews purge on their own after EW_NPC_AUTOPURGE_TIME, and hostile
 * NPC hulls treat the intrusion as player aggression.
 *
 * The component deletes itself once no payloads are active and the hardened
 * window has passed (deferred via timer, never mid-iteration).
 */
/datum/component/ship_ew_intrusion
	/// Active payload instances on this ship (hard refs; payloads deregister in expire())
	var/list/active_payloads = list()
	/// world.time until which this ship refuses new payload connections
	var/hardened_until = 0
	/// Timer id for the NPC crew's scheduled self-purge
	var/autopurge_timer_id
	/// Timer id for the deferred self-cleanup check
	var/cleanup_timer_id

/datum/component/ship_ew_intrusion/Initialize()
	if(!istype(parent, /obj/structure/overmap/ship))
		return COMPONENT_INCOMPATIBLE

/datum/component/ship_ew_intrusion/Destroy(force)
	if(autopurge_timer_id)
		deltimer(autopurge_timer_id)
		autopurge_timer_id = null
	if(cleanup_timer_id)
		deltimer(cleanup_timer_id)
		cleanup_timer_id = null
	// End anything still running - payload expire() restores target state
	for(var/datum/ew_payload/payload as anything in active_payloads.Copy())
		payload.expire()
	active_payloads.Cut()
	return ..()

// ========== PAYLOAD TRACKING ==========

/**
 * Registers a newly-landed payload and warns the crew.
 * First payload gets a WARNING notice; further payloads escalate to DANGER.
 */
/datum/component/ship_ew_intrusion/proc/add_payload(datum/ew_payload/instance)
	if(!instance || (instance in active_payloads))
		return
	var/first_payload = !length(active_payloads)
	active_payloads += instance

	var/obj/structure/overmap/ship/ship = parent
	if(first_payload)
		ship.ship_notify("Hostile intrusion detected in [instance.subsystem_name]!", "INTRUSION", SHIP_NOTIFY_WARNING, 'voidcrew/sound/warn.ogg', 25)
	else
		ship.ship_notify("Additional hostile intrusion detected in [instance.subsystem_name]!", "INTRUSION", SHIP_NOTIFY_DANGER, 'voidcrew/sound/alert2.ogg', 25)

	// NPC crews respond on their own
	if(first_payload && istype(ship, /obj/structure/overmap/ship/npc))
		if(!autopurge_timer_id)
			autopurge_timer_id = addtimer(CALLBACK(src, PROC_REF(npc_autopurge)), EW_NPC_AUTOPURGE_TIME, TIMER_STOPPABLE)
		npc_react_to_intrusion(instance.get_attacker())

/**
 * Deregisters an ended payload. Called by /datum/ew_payload/expire().
 * Schedules the deferred self-cleanup check once nothing is active.
 */
/datum/component/ship_ew_intrusion/proc/remove_payload(datum/ew_payload/instance)
	active_payloads -= instance
	if(!length(active_payloads))
		schedule_cleanup()

// ========== PURGE & HARDENING ==========

/**
 * Purges the intrusion: ends every active payload early and hardens the
 * ship's firewalls for EW_PURGE_HARDENED_TIME. `user` is the crew member
 * who triggered it from the weapons console (null for NPC self-purges).
 */
/datum/component/ship_ew_intrusion/proc/purge(mob/user)
	for(var/datum/ew_payload/payload as anything in active_payloads.Copy())
		payload.expire()
	active_payloads.Cut()

	hardened_until = world.time + EW_PURGE_HARDENED_TIME
	if(autopurge_timer_id)
		deltimer(autopurge_timer_id)
		autopurge_timer_id = null

	var/obj/structure/overmap/ship/ship = parent
	ship.ship_notify("Intrusion purged. Firewalls hardened.", "INTRUSION", SHIP_NOTIFY_NOTICE, 'voidcrew/sound/notify.ogg', 50)
	SEND_SIGNAL(parent, COMSIG_SHIP_EW_PURGED)

	schedule_cleanup()
	return TRUE

/// TRUE while this ship refuses new payload connections
/datum/component/ship_ew_intrusion/proc/is_hardened()
	return world.time < hardened_until

// ========== NPC BEHAVIOR ==========

/// NPC crew self-purge. Timer callback - revalidates state, never trusts the schedule.
/datum/component/ship_ew_intrusion/proc/npc_autopurge()
	autopurge_timer_id = null
	if(QDELETED(src) || !length(active_payloads))
		return
	purge(null)

/**
 * Hostile-capable NPC hulls treat an intrusion as player aggression.
 * Mirrors on_weapons_locked_by_player in npc_ship_controller.dm - by the time
 * a payload lands the attacker already holds a weapons lock, so this mostly
 * covers the negotiation/siphon states where the lock handler defers.
 */
/datum/component/ship_ew_intrusion/proc/npc_react_to_intrusion(obj/structure/overmap/ship/attacker)
	if(!attacker || QDELETED(attacker))
		return
	var/obj/structure/overmap/ship/npc/npc_ship = parent
	if(!istype(npc_ship) || !npc_ship.hostile || npc_ship.is_disabled || npc_ship.player_controlled)
		return
	var/datum/ai_controller/npc_ship/controller = npc_ship.ai_controller
	if(!istype(controller))
		return

	var/combat_state = controller.get_combat_state()
	var/obj/structure/overmap/ship/current_target = controller.get_target()

	// Mid-negotiation intrusion from our counterpart = open hostility
	if(current_target && attacker == current_target)
		if(combat_state == NPC_COMBAT_HAILING || combat_state == NPC_COMBAT_NEGOTIATING || combat_state == NPC_COMBAT_SIPHONING)
			INVOKE_ASYNC(controller, TYPE_PROC_REF(/datum/ai_controller/npc_ship, handle_player_aggression), attacker, "ew_intrusion")
		return

	// Idle with no target - the attacker becomes our target and we engage
	if(combat_state == NPC_COMBAT_IDLE && !current_target)
		controller.set_target(attacker)
		controller.set_combat_state(NPC_COMBAT_ENGAGING)

// ========== STATUS & CLEANUP ==========

/// Returns the target-side intrusion panel data - keys match the EW UI contract
/datum/component/ship_ew_intrusion/proc/get_status()
	var/list/status = list()
	var/list/payloads = list()
	for(var/datum/ew_payload/payload as anything in active_payloads)
		payloads += list(list(
			"name" = payload.name,
			"subsystem" = payload.subsystem_name,
			"remaining" = round(payload.remaining_time() / 10),
		))
	status["payloads"] = payloads
	status["hardened"] = is_hardened()
	status["hardened_remaining"] = is_hardened() ? round((hardened_until - world.time) / 10) : 0
	return status

/// Defers a self-cleanup check - never qdel mid-iteration
/datum/component/ship_ew_intrusion/proc/schedule_cleanup()
	if(cleanup_timer_id || QDELETED(src))
		return
	cleanup_timer_id = addtimer(CALLBACK(src, PROC_REF(try_cleanup)), 1 SECONDS, TIMER_STOPPABLE)

/// Deletes the component once nothing is active and the hardened window passed
/datum/component/ship_ew_intrusion/proc/try_cleanup()
	cleanup_timer_id = null
	if(QDELETED(src) || length(active_payloads))
		return
	if(is_hardened())
		// Check again once the hardened window lapses
		cleanup_timer_id = addtimer(CALLBACK(src, PROC_REF(try_cleanup)), (hardened_until - world.time) + 1 SECONDS, TIMER_STOPPABLE)
		return
	qdel(src)
