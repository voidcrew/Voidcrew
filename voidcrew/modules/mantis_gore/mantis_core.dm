/**
 * # Mantis Blades x hyperviolence
 *
 * The Mantis line (voidcrew/modules/cyberware/ware_military_arms.dm, ware_line_mantis.dm) on top of the
 * gore layer (voidcrew/modules/hyperviolence/). The Mantis is the predator: it wins by bleed-out,
 * pinning and mobility. It never cuts a limb clean off mid-fight; its one dismemberment is the scissor,
 * on someone already dying.
 *
 * - Arterial gashes: cuts on one limb add up and tear its artery (mantis_blade.dm, mantis_wounds.dm).
 * - Impaling lunge: both blades into someone hurt hold them up, or pin them to a wall (mantis_impale.dm).
 * - Scissor: a head swing at someone dying, a #509 finisher (mantis_scissor.dm).
 * - Blood on the blades, dripping after a kill, flicked off on the way in (mantis_blade.dm, mantis_housing.dm).
 * - Lunge trail, afterimages and the arrival (mantis_lunge_fx.dm).
 * - X-slash: every third cut with both blades out (mantis_blade.dm).
 * - Combat stance: the guard pose and the raised fists while the blades are out (mantis_poses.dm).
 * - Charged leap and the kill reset (mantis_charge.dm, and the kill credit below).
 * - Scorch burns and half-seals; the Shiv only bleeds (the model tuning in mantis_blade.dm).
 *
 * Human NPCs only get the gore moves at #509's ranks: aimed crits (hv_can_land_aimed_crits()) for the
 * arteries, the impale, the X-slash and the reset; executions (hv_can_execute()) for the scissor. An
 * ordinary NPC with Mantis blades cuts like a knife.
 *
 * Every number is in voidcrew/_DEFINES/mantis_gore.dm.
 */

// =========================================================================
// PER-BEARER BOOKKEEPING
// =========================================================================

/// What one bearer of the line is in the middle of: the X-slash count and the clocks of the
/// scissor, the kill reset and the crouch. Holds no hard references.
/datum/mantis_bearer
	/// Who the X-slash count is on
	var/datum/weakref/xslash_target
	/// Landed cuts on them so far
	var/xslash_count = 0
	/// world.time of the last of those cuts
	var/xslash_last = 0
	/// world.time the scissor can be tried again
	var/next_scissor = 0
	/// world.time a kill can reset the lunge again
	var/next_kill_reset = 0
	/// world.time the bearer can crouch to charge again
	var/next_charge = 0
	/// The scissor running now, if any
	var/datum/hv_finisher/mantis_scissor/scissor
	/// The blade rig drawing this bearer now, if any (mantis_rig.dm)
	var/datum/mantis_rig/rig

/datum/mantis_bearer/Destroy()
	xslash_target = null
	scissor = null
	rig = null
	return ..()

/mob/living
	/// The Mantis line's bookkeeping for this mob as a bearer (voidcrew/modules/mantis_gore/). Made on first use.
	var/datum/mantis_bearer/mantis_state
	/// world.time this mob, killed, last reset someone's lunge. Outlives death on purpose (revive loops).
	var/mantis_reset_given_at = 0

/mob/living/proc/get_mantis_state()
	RETURN_TYPE(/datum/mantis_bearer)
	if(!mantis_state)
		mantis_state = new
	return mantis_state

// =========================================================================
// HELPERS
// =========================================================================

/// The Mantis-line blades [bearer] has out in a hand, optionally only those that can do [moves] (MANTIS_MOVE_*).
/proc/mantis_held_blades(mob/living/bearer, moves = NONE)
	RETURN_TYPE(/list)
	. = list()
	if(!isliving(bearer))
		return
	for(var/obj/item/melee/energy/blade/hardlight/cyberware_mantis/blade in bearer.held_items)
		if(moves && (blade.gore_moves & moves) != moves)
			continue
		. += blade

/// Every Mantis lunge button [bearer] has. Chrome abilities never join mob.actions (chrome_hud.dm).
/proc/mantis_lunge_actions(mob/living/bearer)
	RETURN_TYPE(/list)
	. = list()
	if(!iscarbon(bearer))
		return
	for(var/datum/action/cooldown/cyberware/mantis_lunge/lunge in get_chrome_wheel_actions(bearer))
		. += lunge

/// The held blade of each of [housings], skipping any that isn't out.
/proc/mantis_housing_blades(list/housings)
	RETURN_TYPE(/list)
	. = list()
	for(var/obj/item/organ/cyberimp/arm/toolkit/cyberware/mantis/housing as anything in housings)
		var/obj/item/melee/energy/blade/hardlight/cyberware_mantis/blade = housing.active_item
		if(istype(blade) && housing.blade_extended())
			. += blade

/// Whether [victim] is dying: in crit, or out cold at crit health. Lying down or stunned is not enough.
/proc/mantis_in_crit(mob/living/victim)
	if(!isliving(victim) || victim.stat == DEAD)
		return FALSE
	if(victim.stat == SOFT_CRIT || victim.stat == HARD_CRIT)
		return TRUE
	return victim.stat == UNCONSCIOUS && victim.health <= victim.crit_threshold

// =========================================================================
// KILL CREDIT
// =========================================================================

/**
 * [bearer] has just cut [victim] with the line: a death in the next few seconds is their kill.
 * Called before the damage lands, so the cut that kills counts.
 */
/proc/mantis_note_hit(mob/living/victim, mob/living/bearer)
	if(!isliving(victim) || !isliving(bearer) || victim == bearer || QDELETED(victim) || victim.stat == DEAD)
		return null
	var/datum/status_effect/mantis_cuts/cuts = victim.has_status_effect(/datum/status_effect/mantis_cuts)
	if(cuts)
		cuts.refresh()
	else
		cuts = victim.apply_status_effect(/datum/status_effect/mantis_cuts)
	if(!cuts)
		return null
	cuts.last_bearer = WEAKREF(bearer)
	cuts.last_hit = world.time
	return cuts

/**
 * On someone the line has cut lately. Counts the cuts on each limb (the arterial gashes) and remembers
 * who cut them last, so their death can be credited. Runs out on its own a while after the last cut.
 */
/datum/status_effect/mantis_cuts
	id = "mantis_cuts"
	alert_type = null
	duration = MANTIS_CUT_WINDOW
	tick_interval = STATUS_EFFECT_NO_TICK
	status_type = STATUS_EFFECT_UNIQUE
	/// Body zone -> cuts on it that still add up
	var/list/limb_cuts
	/// Body zone -> world.time of its last cut
	var/list/limb_cut_times
	/// Who cut them last
	var/datum/weakref/last_bearer
	/// world.time of that cut
	var/last_hit = 0

/datum/status_effect/mantis_cuts/on_apply()
	RegisterSignal(owner, COMSIG_LIVING_DEATH, PROC_REF(on_owner_death))
	return TRUE

/datum/status_effect/mantis_cuts/on_remove()
	UnregisterSignal(owner, COMSIG_LIVING_DEATH)

/datum/status_effect/mantis_cuts/Destroy()
	last_bearer = null
	return ..()

/// One more cut on [zone]. Returns how many now add up there.
/datum/status_effect/mantis_cuts/proc/add_cut(zone)
	LAZYINITLIST(limb_cuts)
	LAZYINITLIST(limb_cut_times)
	if(world.time - (limb_cut_times[zone] || 0) > MANTIS_CUT_WINDOW)
		limb_cuts[zone] = 0
	limb_cuts[zone] = (limb_cuts[zone] || 0) + 1
	limb_cut_times[zone] = world.time
	return limb_cuts[zone]

/// The count on [zone] starts over.
/datum/status_effect/mantis_cuts/proc/clear_cuts(zone)
	LAZYREMOVE(limb_cuts, zone)
	LAZYREMOVE(limb_cut_times, zone)

/datum/status_effect/mantis_cuts/proc/on_owner_death(datum/source, gibbed)
	SIGNAL_HANDLER
	var/mob/living/bearer = last_bearer?.resolve()
	if(isnull(bearer) || world.time - last_hit > MANTIS_KILL_CREDIT_WINDOW)
		return
	mantis_kill_credit(bearer, owner)

/// [bearer] killed [victim]: the blades are drenched, and the lunge may come back early. A kill in the impale
/// or the scissor only stains them: the blade rig draws the blood they leave on the steel, and the held art
/// keeps that coat after.
/proc/mantis_kill_credit(mob/living/bearer, mob/living/victim)
	if(QDELETED(bearer) || bearer.stat == DEAD)
		return FALSE
	var/light = !isnull(bearer.mantis_state?.rig)
	for(var/obj/item/melee/energy/blade/hardlight/cyberware_mantis/blade as anything in mantis_held_blades(bearer))
		blade.drench(victim, light)
	return mantis_try_kill_reset(bearer, victim)

/// Whether killing [victim] can reset a lunge at all: a person (not a monkey), or something big.
/proc/mantis_kill_reset_counts(mob/living/victim)
	if(ishuman(victim))
		return !ismonkey(victim)
	return victim.maxHealth >= MANTIS_KILL_RESET_MIN_HEALTH

/**
 * The kill reset. [bearer]'s lunge cooldown comes down to MANTIS_KILL_RESET_FLOOR, never lower, at most
 * once per MANTIS_KILL_RESET_COOLDOWN per bearer, and a body that gave one gives no other for
 * MANTIS_KILL_RESET_VICTIM_LOCKOUT. Prisoners (cuffed or strapped down at death) and small animals never
 * count. Returns TRUE if it reset.
 */
/proc/mantis_try_kill_reset(mob/living/bearer, mob/living/victim)
	if(!isliving(victim) || !iscarbon(bearer) || !bearer.hv_can_land_aimed_crits())
		return FALSE
	if(!mantis_kill_reset_counts(victim))
		return FALSE
	if(HAS_TRAIT(victim, TRAIT_RESTRAINED) || victim.buckled)
		return FALSE
	if(victim.mantis_reset_given_at && world.time < victim.mantis_reset_given_at + MANTIS_KILL_RESET_VICTIM_LOCKOUT)
		return FALSE
	var/datum/mantis_bearer/state = bearer.get_mantis_state()
	if(world.time < state.next_kill_reset)
		return FALSE
	var/reset = FALSE
	for(var/datum/action/cooldown/cyberware/mantis_lunge/lunge as anything in mantis_lunge_actions(bearer))
		if(lunge.next_use_time > world.time + MANTIS_KILL_RESET_FLOOR)
			lunge.StartCooldown(MANTIS_KILL_RESET_FLOOR)
			reset = TRUE
	if(!reset)
		return FALSE
	state.next_kill_reset = world.time + MANTIS_KILL_RESET_COOLDOWN
	victim.mantis_reset_given_at = world.time
	mantis_reset_tell(bearer)
	log_combat(bearer, victim, "had the mantis lunge come back early from killing")
	return TRUE

/// The only sign of a reset: both blades flare once, with a soft ring of steel.
/proc/mantis_reset_tell(mob/living/bearer)
	for(var/obj/item/melee/energy/blade/hardlight/cyberware_mantis/blade as anything in mantis_held_blades(bearer))
		blade.play_glint(MANTIS_POSE_GUARD)
		var/obj/item/organ/cyberimp/arm/toolkit/cyberware/mantis/housing = blade.housing_ref?.resolve()
		housing?.blade_flash(1, 0.3 SECONDS)
	playsound(bearer, 'sound/items/unsheath.ogg', 25, TRUE, SILENCED_SOUND_EXTRARANGE)
