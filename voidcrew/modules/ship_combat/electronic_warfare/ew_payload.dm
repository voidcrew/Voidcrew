/**
 * Electronic Warfare Payload - base class
 *
 * One INSTANCE exists per application: the EW suite constructs
 * `new payload_type(target, attacker, mode)` when warmup completes, and the
 * instance immediately applies itself to the target ship, registers with the
 * target's intrusion component, and schedules its own expiry.
 *
 * Payload subtypes (in ew_payloads_utility.dm / ew_payloads_heavy.dm) override
 * can_apply(), on_apply() and on_expire(). on_expire() MUST fully restore the
 * target's state, must be idempotent, and must null-check everything - it can
 * run from the expiry timer, a crew purge, or mid-deletion of the target ship.
 *
 * Store references to target-ship atoms as weakrefs or lists you clear in
 * on_expire()/Destroy() - a payload must never hard-ref-leak door/machine objs.
 */

// ========== PROTOTYPE REGISTRY ==========

/// Cached metadata/validation instances, one per payload typepath.
/// Prototypes are constructed with no target and never apply anything.
GLOBAL_LIST_EMPTY(ew_payload_prototypes)

/// Returns the cached prototype instance for a payload typepath (or null for a bad path).
/// Use this to read name/desc/tier/modes and to call can_apply() before instantiating.
/proc/get_ew_payload_prototype(payload_type)
	if(!ispath(payload_type, /datum/ew_payload))
		return null
	var/datum/ew_payload/proto = GLOB.ew_payload_prototypes[payload_type]
	if(!proto)
		proto = new payload_type()
		GLOB.ew_payload_prototypes[payload_type] = proto
	return proto

// ========== PAYLOAD BASE ==========

/datum/ew_payload
	/// Unique string id, e.g. "lights_out"
	var/id = "base"
	/// Player-facing exploit name, e.g. "Blackout"
	var/name = "Unnamed Exploit"
	/// One sentence effect description, shown in shop/examine/UI
	var/desc = "Does nothing."
	/// Target subsystem name used in target-side warnings, e.g. "lighting control"
	var/subsystem_name = "ship systems"
	/// Tier 1..4 - drives shop pricing and chip icon choice
	var/tier = 1
	/// Warmup before the payload lands (deciseconds)
	var/warmup = 5 SECONDS
	/// How long the payload stays active on the target (deciseconds)
	var/duration = 30 SECONDS
	/// Per-suite per-type cooldown between executions (deciseconds)
	var/cooldown = 60 SECONDS
	/// Signature added to the executing suite per application
	var/signature_cost = 25
	/// Null, or a list of mode strings - the console UI renders one button per mode
	var/list/modes = null
	/// FALSE hides/blocks this payload against NPC ship targets
	var/works_on_npc = TRUE

	// ===== RUNTIME STATE (live instances only, null on prototypes) =====
	/// Weakref to the target ship
	var/datum/weakref/target_ref
	/// Weakref to the attacking ship
	var/datum/weakref/attacker_ref
	/// The mode string this instance was executed with (null if the payload has no modes)
	var/mode
	/// world.time when this payload landed
	var/applied_at = 0
	/// Timer id for the scheduled expire() call
	var/expire_timer_id
	/// Set once expire() has run - guards against double-expiry
	var/expired = FALSE

/**
 * Applies this payload to a target ship.
 *
 * Called with no arguments to build a metadata prototype - prototype instances
 * store no refs and apply nothing.
 */
/datum/ew_payload/New(obj/structure/overmap/ship/target, obj/structure/overmap/ship/attacker, mode)
	..()
	if(!target)
		return // Prototype instance - metadata and can_apply() only

	src.mode = mode
	target_ref = WEAKREF(target)
	attacker_ref = WEAKREF(attacker)
	applied_at = world.time

	// Register with the target's intrusion component - this also fires the
	// target-side intrusion warning and the NPC autopurge/aggro behavior
	var/datum/component/ship_ew_intrusion/intrusion = target.LoadComponent(/datum/component/ship_ew_intrusion)
	intrusion.add_payload(src)

	on_apply(mode)

	// Timers only fire the attempt - expire() revalidates its own state
	expire_timer_id = addtimer(CALLBACK(src, PROC_REF(expire)), duration, TIMER_STOPPABLE)

	SEND_SIGNAL(target, COMSIG_SHIP_EW_PAYLOAD_STARTED, src, attacker)

/datum/ew_payload/Destroy(force)
	// Last-chance restore if something qdels us without going through expire()
	if(!expired)
		expired = TRUE
		if(expire_timer_id)
			deltimer(expire_timer_id)
			expire_timer_id = null
		on_expire()
	target_ref = null
	attacker_ref = null
	return ..()

// ========== LIFECYCLE ==========

/**
 * Ends this payload: restores target state, deregisters from the intrusion
 * component, announces the end, and deletes the instance.
 *
 * Safe to call from the expiry timer, a crew purge, or target/attacker
 * deletion - idempotent via the `expired` guard.
 */
/datum/ew_payload/proc/expire()
	if(expired)
		return
	expired = TRUE
	if(expire_timer_id)
		deltimer(expire_timer_id)
		expire_timer_id = null

	on_expire()

	var/obj/structure/overmap/ship/target = target_ref?.resolve()
	if(target && !QDELETED(target))
		var/datum/component/ship_ew_intrusion/intrusion = target.GetComponent(/datum/component/ship_ew_intrusion)
		intrusion?.remove_payload(src)
		SEND_SIGNAL(target, COMSIG_SHIP_EW_PAYLOAD_ENDED, src)

	qdel(src)

// ========== OVERRIDABLES ==========

/**
 * Pre-execution validation, called on the PROTOTYPE before an instance exists.
 *
 * Return TRUE to allow execution, or a user-facing error string to block it.
 * The suite re-runs this in the warmup completion callback, so it must be
 * cheap and side-effect free.
 */
/datum/ew_payload/proc/can_apply(obj/structure/overmap/ship/target, obj/structure/overmap/ship/attacker)
	return TRUE

/**
 * Applies the payload effect to the target ship. Called once from New().
 * Subtypes should produce target-visible feedback here (flicker, sound,
 * announcement) and stash whatever restore data on_expire() needs - as
 * weakrefs or lists cleared on expiry, never bare hard refs.
 */
/datum/ew_payload/proc/on_apply(mode)
	return

/**
 * Restores the target's state. MUST be idempotent and safe when the target
 * ship or its interior is mid-deletion - null-check everything.
 */
/datum/ew_payload/proc/on_expire()
	return

// ========== HELPERS ==========

/// Resolves the target ship, or null if it is gone
/datum/ew_payload/proc/get_target()
	return target_ref?.resolve()

/// Resolves the attacking ship, or null if it is gone
/datum/ew_payload/proc/get_attacker()
	return attacker_ref?.resolve()

/// Deciseconds until this payload expires (0 once expired)
/datum/ew_payload/proc/remaining_time()
	if(expired || !applied_at)
		return 0
	return max(0, (applied_at + duration) - world.time)
