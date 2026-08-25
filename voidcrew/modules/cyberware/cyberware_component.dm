/**
 * # Cyberware component
 *
 * The one datum that makes an organ count as chrome. Both organ bases
 * (/obj/item/organ/cyberimp/cyberware and /obj/item/organ/eyes/robotic/cyberware,
 * single inheritance forces the split) attach one of these, and everything
 * that has to treat "all cyberware" uniformly. Load sums, capacity, the
 * brownout monitor, install contexts, EMP downtime. Reads and writes it
 * through GetComponent rather than caring which base a ware hangs off.
 *
 * Chrome load is never stored as a counter on the mob: it is recomputed live
 * from the installed organs every time someone asks, so there is no counter
 * to desync when organs move through surgery, autosurgeons, admin fiat or
 * deletion.
 *
 * The brownout monitor self-wires: COMSIG_ORGAN_IMPLANTED / _REMOVED are sent
 * on the organ itself, so the component hears its own installs without either
 * organ base carrying any monitor code. While a body's total load exceeds its
 * capacity, EVERY installed piece of chrome gains ORGAN_FAILING, legible,
 * all-or-nothing, and recovers the moment the load drops back under.
 * Removal is never blocked; pulling ware out IS the fix.
 */
/datum/component/cyberware
	/// Neural load this ware puts on its bearer while installed.
	var/chrome_load = 0
	/// CYBERWARE_TIER_*, drives accent colours and Splice's bedside manner.
	var/tier = CYBERWARE_TIER_1
	/// Chrome capacity this ware ADDS to its bearer while installed, the
	/// Overclock Governor hook. Load 0 + bonus 6 is a Governor.
	var/capacity_bonus = 0
	/// TRUE while the bearer is over capacity and this ware is browned out.
	var/browned_out = FALSE
	/// TRUE while rebooting from an EMP hit.
	var/emp_down = FALSE
	/// TRUE while the ware's failing-gated passive layer (organ_traits,
	/// physiology armor/mods) is applied to a bearer. The edge latch behind
	/// chrome_passives_on/off, so those hooks fire exactly once per flip.
	var/passives_online = FALSE
	/// Timer for the pending EMP reboot.
	var/emp_timer
	/// Who this ware currently has an install window open for. Weakref so a
	/// deleted patient can't be held onto for the window's whole lifetime.
	var/datum/weakref/install_context_ref
	/// world.time at which the install window closes.
	var/install_context_until = 0
	/// TRUE when the open window was granted by admin fiat. A forced window
	/// waives the capacity ceiling as well as the context check, the ware goes
	/// in over budget and the brownout monitor takes it from there.
	var/install_context_forced = FALSE

/datum/component/cyberware/Initialize(chrome_load = 0, tier = CYBERWARE_TIER_1, capacity_bonus = 0)
	if(!isorgan(parent))
		return COMPONENT_INCOMPATIBLE
	src.chrome_load = chrome_load
	src.tier = tier
	src.capacity_bonus = capacity_bonus

/datum/component/cyberware/RegisterWithParent()
	RegisterSignal(parent, COMSIG_ORGAN_IMPLANTED, PROC_REF(on_implanted))
	RegisterSignal(parent, COMSIG_ORGAN_REMOVED, PROC_REF(on_removed))

/datum/component/cyberware/UnregisterFromParent()
	UnregisterSignal(parent, list(COMSIG_ORGAN_IMPLANTED, COMSIG_ORGAN_REMOVED))

/datum/component/cyberware/Destroy()
	if(emp_timer)
		deltimer(emp_timer)
		emp_timer = null
	install_context_ref = null
	install_context_forced = FALSE
	return ..()

// ---- Brownout monitor --------------------------------------------------

/// Signal proc for [COMSIG_ORGAN_IMPLANTED]: watch the new bearer's organ
/// churn and settle our brownout state against their fresh totals.
/datum/component/cyberware/proc/on_implanted(datum/source, mob/living/carbon/new_owner)
	SIGNAL_HANDLER
	RegisterSignals(new_owner, list(COMSIG_CARBON_GAIN_ORGAN, COMSIG_CARBON_LOSE_ORGAN), PROC_REF(on_owner_organs_changed))
	// Per-tick settle: catches ORGAN_FAILING flips that never pass through
	// this component (tg's apply_organ_damage() sets/clears the flag directly
	// at the damage ceiling). Two comparisons a tick; Dead Channel precedent.
	RegisterSignal(new_owner, COMSIG_LIVING_LIFE, PROC_REF(on_owner_life))
	cyberware_reevaluate_brownout(new_owner)
	settle_passives(new_owner)
	if(!passives_online)
		// Inserted while still failing (EMP reboot ticking outside the body,
		// or straight into a brownout): tg's on_mob_insert just granted the
		// organ_traits unconditionally, so take the passive layer back off.
		var/obj/item/organ/ware = parent
		ware.chrome_passives_off(new_owner)

/// Signal proc for [COMSIG_ORGAN_REMOVED]: chrome outside a body is just a
/// part again, drop the brownout (EMP downtime keeps ticking) and let the
/// old bearer's remaining chrome re-settle without our load.
/datum/component/cyberware/proc/on_removed(datum/source, mob/living/carbon/old_owner)
	SIGNAL_HANDLER
	UnregisterSignal(old_owner, list(COMSIG_CARBON_GAIN_ORGAN, COMSIG_CARBON_LOSE_ORGAN, COMSIG_LIVING_LIFE))
	// Owner is already null by the time this signal fires, so this settles the
	// passive layer OFF while we still hold a real bearer to take it off of.
	settle_passives(old_owner)
	set_browned_out(FALSE)
	cyberware_reevaluate_brownout(old_owner)

/// Signal proc for [COMSIG_CARBON_GAIN_ORGAN] and [COMSIG_CARBON_LOSE_ORGAN]
/// on the bearer. Every installed ware listens with its own component, so a
/// change re-evaluates N times. The evaluation is idempotent and only the
/// first caller does the flipping.
/datum/component/cyberware/proc/on_owner_organs_changed(mob/living/carbon/source, obj/item/organ/changed, special)
	SIGNAL_HANDLER
	cyberware_reevaluate_brownout(source)

/// Flips the brownout state. Returns TRUE only when the state actually changed.
/datum/component/cyberware/proc/set_browned_out(new_state)
	new_state = !!new_state
	if(browned_out == new_state)
		return FALSE
	browned_out = new_state
	update_failing()
	return TRUE

// ---- EMP downtime ------------------------------------------------------

/// Standard chrome EMP response: fail now, reboot after downtime scaled by
/// severity (EMP_HEAVY = 1 eats the full downtime, EMP_LIGHT = 2 half).
/datum/component/cyberware/proc/start_emp_reboot(severity = EMP_HEAVY)
	if(emp_down)
		return
	emp_down = TRUE
	update_failing()
	if(emp_timer)
		deltimer(emp_timer)
	emp_timer = addtimer(CALLBACK(src, PROC_REF(finish_emp_reboot)), CYBERWARE_EMP_DOWNTIME / max(severity, 1), TIMER_STOPPABLE)

/datum/component/cyberware/proc/finish_emp_reboot()
	emp_timer = null
	if(!emp_down)
		return
	emp_down = FALSE
	update_failing()
	var/obj/item/organ/ware = parent
	if(ware.owner && !(ware.organ_flags & ORGAN_FAILING))
		ware.owner.balloon_alert(ware.owner, "[ware.name] back online")

/// Cradle tune-up: cancels any pending EMP reboot and repairs the organ
/// outright. Cannot fix a brownout, that is a load problem, not damage.
/datum/component/cyberware/proc/tune_up()
	if(emp_timer)
		deltimer(emp_timer)
		emp_timer = null
	emp_down = FALSE
	var/obj/item/organ/ware = parent
	ware.set_organ_damage(0)
	update_failing()

/// Settles ORGAN_FAILING from our two failure sources. Careful not to clear
/// a failure earned through organ damage: only lift the flag while the organ
/// is below its damage ceiling.
/datum/component/cyberware/proc/update_failing()
	var/obj/item/organ/ware = parent
	if(browned_out || emp_down)
		ware.organ_flags |= ORGAN_FAILING
	else if(ware.damage < ware.maxHealth)
		ware.organ_flags &= ~ORGAN_FAILING
	// Removal settles through on_removed() with the old bearer instead; owner
	// is already null on that path and the passive layer needs a real mob.
	if(ware.owner)
		settle_passives(ware.owner)

/**
 * Edge-settles the ware's failing-gated passive layer (BAL-4).
 *
 * Passives are ON exactly while the ware is installed in `bearer` and not
 * ORGAN_FAILING; everything else, EMP reboot, brownout, damage failure,
 * removal, is OFF. The passives_online latch makes each flip fire the
 * matching chrome_passives_on/off hook exactly once, which is what lets the
 * hooks carry non-idempotent physiology work.
 *
 * Our own two failure sources are read directly as well as through the flag.
 * ORGAN_FAILING is a shared bit that anything may write: tg's
 * apply_organ_damage() clears it unconditionally the moment damage drops
 * below the ceiling, so a single point of organ healing landing on a bearer
 * mid-EMP would otherwise hand the whole passive layer back before the
 * reboot timer had run. Reading browned_out/emp_down too can only ever hold
 * passives down longer, never bring them up early.
 */
/datum/component/cyberware/proc/settle_passives(mob/living/carbon/bearer)
	var/obj/item/organ/ware = parent
	var/installed_here = !QDELETED(ware) && bearer && ware.owner == bearer
	var/ware_running = !browned_out && !emp_down && !(ware.organ_flags & ORGAN_FAILING)
	var/should_be_online = installed_here && ware_running
	if(passives_online == !!should_be_online)
		return
	passives_online = !!should_be_online
	if(passives_online)
		ware.chrome_passives_on(bearer)
	else
		ware.chrome_passives_off(bearer)

/// Signal proc for [COMSIG_LIVING_LIFE] on the bearer: the per-tick catch-all
/// settle (see the registration comment in on_implanted()).
/datum/component/cyberware/proc/on_owner_life(mob/living/carbon/source, seconds_per_tick, times_fired)
	SIGNAL_HANDLER
	settle_passives(source)

// ---- Install context ---------------------------------------------------
// Cyberware refuses Insert() outside a legit context: organ-manipulation
// surgery opens a window in pre_surgical_insertion, the Chrome Cradle opens
// one right before it inserts, the "Cyberware: Install Chrome" admin verb
// opens a forced one, and special = TRUE (init) bypasses the gate entirely.
// Bare autosurgeons never open one, that is the point. VV-inserting an organ
// onto a mob goes through the same live Insert(), so it hits the same wall;
// the admin verb is the supported way in.

/datum/component/cyberware/proc/grant_install_context(mob/living/carbon/target, duration = CYBERWARE_INSTALL_CONTEXT_WINDOW, forced = FALSE)
	install_context_ref = WEAKREF(target)
	install_context_until = world.time + duration
	install_context_forced = forced

/datum/component/cyberware/proc/has_install_context(mob/living/carbon/target)
	return target && install_context_ref?.resolve() == target && world.time <= install_context_until

/datum/component/cyberware/proc/clear_install_context()
	install_context_ref = null
	install_context_until = 0
	install_context_forced = FALSE

// ---- Global helpers ----------------------------------------------------

/// Every installed organ on the target that carries chrome.
///
/// The loops in this file are typed rather than `as anything` on purpose:
/// a hard-deleted organ (SSgarbage hard-deleting a ref it could not collect)
/// becomes a null in place inside `organs`, and `as anything` skips the
/// istype filter that would otherwise drop it. These helpers run from ui_data
/// and from brownout checks, so a runtime here is a per-tick one.
/proc/get_installed_cyberware(mob/living/carbon/target)
	RETURN_TYPE(/list)
	. = list()
	if(!iscarbon(target))
		return
	for(var/obj/item/organ/organ in target.organs)
		if(organ.GetComponent(/datum/component/cyberware))
			. += organ

/// Chrome load of a single organ; 0 for anything that isn't chrome.
/proc/get_organ_chrome_load(obj/item/organ/ware)
	var/datum/component/cyberware/chrome = ware?.GetComponent(/datum/component/cyberware)
	return chrome ? chrome.chrome_load : 0

/// The target's total neural load, summed live off the installed organs.
/proc/get_chrome_load(mob/living/carbon/target)
	. = 0
	if(!iscarbon(target))
		return
	for(var/obj/item/organ/organ in target.organs)
		var/datum/component/cyberware/chrome = organ.GetComponent(/datum/component/cyberware)
		if(chrome)
			. += chrome.chrome_load

/// The target's chrome capacity: the body's baseline plus every installed
/// ware's capacity bonus (the Governor hook).
/proc/get_chrome_capacity(mob/living/carbon/target)
	. = CYBERWARE_BASE_CAPACITY
	if(!iscarbon(target))
		return
	for(var/obj/item/organ/organ in target.organs)
		var/datum/component/cyberware/chrome = organ.GetComponent(/datum/component/cyberware)
		if(chrome)
			. += chrome.capacity_bonus

/// Accent colour for a tier, for BIOS lines and UI chrome.
/proc/cyberware_tier_color(tier)
	switch(tier)
		if(CYBERWARE_TIER_2)
			return CYBERWARE_COLOR_TIER_2
		if(CYBERWARE_TIER_3)
			return CYBERWARE_COLOR_TIER_3
		if(CYBERWARE_TIER_4)
			return CYBERWARE_COLOR_TIER_4
	return CYBERWARE_COLOR_TIER_1

/**
 * Re-settles the brownout state of every piece of chrome on the target.
 *
 * Called from the per-ware organ-churn listeners, so it runs several times
 * per change; only the call that actually flips states produces feedback.
 * All-or-nothing by design: over capacity means ALL chrome browns out.
 */
/proc/cyberware_reevaluate_brownout(mob/living/carbon/target)
	if(!iscarbon(target) || QDELETED(target))
		return
	var/list/installed = get_installed_cyberware(target)
	if(!length(installed))
		return
	var/over = get_chrome_load(target) > get_chrome_capacity(target)
	var/newly_tripped = FALSE
	var/any_recovered = FALSE
	for(var/obj/item/organ/ware as anything in installed)
		var/datum/component/cyberware/chrome = ware.GetComponent(/datum/component/cyberware)
		if(!chrome.set_browned_out(over))
			continue
		if(over)
			newly_tripped = TRUE
		else
			any_recovered = TRUE
	if(newly_tripped)
		target.balloon_alert(target, "chrome brownout!")
		to_chat(target, span_boldwarning("Your chrome browns out. Too much load on the wetware. Shed some ware to bring it back."))
		do_sparks(2, TRUE, target)
	else if(any_recovered)
		target.balloon_alert(target, "chrome back online")
