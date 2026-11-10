/**
 * # Artifact effect
 *
 * Ported from NovaSector (5ce2bd2215c0) modular_nova/modules/xenoarchartifacts/artifacts/effect.dm,
 * reworked for Voidcrew:
 * - Tiers, band-weighted rolls, a label name and harvest flag drive the catalogue.
 * - Charge is per second. Auras spend faster than the store refills, so they rest about two
 *   thirds of the time; a pulse fires when the store is full. The store refills while asleep,
 *   so a freshly woken artifact acts at once.
 * - A stimulus wakes an effect for a while instead of toggling it; level triggers (air and
 *   proximity) hold it awake while their condition lasts.
 * - Harmful effects log like a weapon. Helpful effects never burst when smashed.
 *
 * Whatever holds an effect (an artifact, or a battery once harvested) calls tick() every
 * process and touch() when touched. Subtypes implement do_effect_touch/aura/pulse.
 *
 * A rollable effect is any subtype that sets label_name. Parents that only share code leave it
 * null and never roll. Adding an effect is adding a subtype: nothing else to register.
 */
/datum/artifact_effect
	/// The plain words a labeler offers for it, such as "Heals". Null on abstract parents.
	var/label_name
	/// Name for logs and admins
	var/log_name = "unknown"
	/// ARTIFACT_TIER_*
	var/tier = ARTIFACT_TIER_COMMON
	/// A harvester can drain it into a battery
	var/harvestable = TRUE
	/// Can roll as an artifact's second effect (common and uncommon effects only)
	var/minor = FALSE
	/// Relative weight against other effects of its tier
	var/weight = 10
	/// Weight multipliers by stamped band
	var/green_weight = 1
	var/yellow_weight = 1
	var/red_weight = 1
	/// Logged as a weapon when it lands on someone
	var/harmful = FALSE
	/// Never fires a last burst when its artifact is smashed
	var/helpful = FALSE

	/// ARTIFACT_ENERGY_* kinds it can present as; one is picked
	var/list/possible_kinds = list(ARTIFACT_ENERGY_CONCENTRATED)
	/// ARTIFACT_ENERGY_*: what the analyser reads off it, and how its artifact looks
	var/energy_kind = ARTIFACT_ENERGY_CONCENTRATED
	/// ARTIFACT_RELEASE_* it can roll
	var/list/allowed_release_methods = list(ARTIFACT_RELEASE_TOUCH, ARTIFACT_RELEASE_AURA, ARTIFACT_RELEASE_PULSE)
	/// ARTIFACT_RELEASE_*
	var/release_method = ARTIFACT_RELEASE_TOUCH
	/// ARTIFACT_TRIGGER_* it can roll; null for any
	var/list/allowed_triggers
	/// The trigger that wakes it (one ARTIFACT_TRIGGER_* flag)
	var/trigger = ARTIFACT_TRIGGER_TOUCH

	/// ARTIFACT_STRENGTH_*
	var/strength = ARTIFACT_STRENGTH_SMALL
	/// Tiles its aura and pulses reach
	var/range = 3
	/// Size of its charge store; a pulse spends all of it
	var/maximum_charges = 10
	/// Charge in store
	var/current_charge = 0
	/// Charge one touch spends
	var/touch_cost = ARTIFACT_TOUCH_COST

	/// Awake and releasing
	var/activated = FALSE
	/// An aura that ran its store dry and is resting until full
	var/exhausted = FALSE
	/// world.time it falls asleep unless woken again
	var/awake_until = 0

	/// Whatever holds it: an artifact, or a battery once harvested
	var/atom/holder
	/// Who answers for it when it hurts someone, if not its artifact's last disturber
	var/datum/weakref/responsible_ref
	/// REF(victim) -> world.time last logged, so an aura logs each person twice a minute at most
	var/list/last_logged

/datum/artifact_effect/New(atom/location, band)
	. = ..()
	holder = location
	roll_traits(band)
	setup()
	current_charge = maximum_charges

/datum/artifact_effect/Destroy(force)
	if(activated)
		activated = FALSE
		on_deactivate()
	holder = null
	responsible_ref = null
	last_logged = null
	return ..()

/// Rolls energy kind, release method, trigger and strength.
/datum/artifact_effect/proc/roll_traits(band)
	energy_kind = pick(possible_kinds)
	release_method = pick(allowed_release_methods)
	trigger = roll_trigger()
	roll_strength(band)

/datum/artifact_effect/proc/roll_trigger()
	var/list/candidates = allowed_triggers || ARTIFACT_ALL_TRIGGERS
	var/list/weights = list()
	for(var/candidate in candidates)
		weights += artifact_trigger_weight(candidate)
	var/index = xenoarch_pick_weighted_index(weights)
	return index ? candidates[index] : ARTIFACT_TRIGGER_TOUCH

/// Picks small, medium or large by band (green leans small, red leans large).
/datum/artifact_effect/proc/roll_strength(band)
	var/list/odds
	switch(XENOARCH_BAND_INDEX(band))
		if(ZONE_RED)
			odds = ARTIFACT_STRENGTH_ODDS_RED
		if(ZONE_YELLOW)
			odds = ARTIFACT_STRENGTH_ODDS_YELLOW
		else
			odds = ARTIFACT_STRENGTH_ODDS_GREEN
	switch(xenoarch_pick_weighted_index(odds))
		if(3)
			set_strength(ARTIFACT_STRENGTH_LARGE)
		if(2)
			set_strength(ARTIFACT_STRENGTH_MEDIUM)
		else
			set_strength(ARTIFACT_STRENGTH_SMALL)

/// Nova's charge and range bands for each strength, range capped at 8.
/datum/artifact_effect/proc/set_strength(new_strength)
	strength = new_strength
	switch(strength)
		if(ARTIFACT_STRENGTH_LARGE)
			maximum_charges = rand(20, 50)
			range = rand(6, 8)
		if(ARTIFACT_STRENGTH_MEDIUM)
			maximum_charges = rand(15, 30)
			range = rand(4, 6)
		else
			maximum_charges = rand(5, 20)
			range = rand(2, 4)
	current_charge = min(current_charge, maximum_charges)

/// Subtype setup after the roll: fix a release method, pick a gas, and so on.
/datum/artifact_effect/proc/setup()
	return

// ===== Waking and sleeping =====

/// Keeps it awake for at least `duration` more, waking it if it slept.
/datum/artifact_effect/proc/wake(duration)
	awake_until = max(awake_until, world.time + duration)
	if(!activated)
		activate()

/datum/artifact_effect/proc/activate()
	if(activated)
		return
	activated = TRUE
	exhausted = FALSE
	on_activate()
	var/obj/machinery/artifact/artifact = holder
	if(istype(artifact))
		artifact.effect_woke(src)

/// Puts it to sleep. `quiet` skips its artifact's sleep moment (used when it is crated or deleted).
/datum/artifact_effect/proc/deactivate(quiet = FALSE)
	if(!activated)
		return
	activated = FALSE
	exhausted = FALSE
	awake_until = 0
	on_deactivate()
	var/obj/machinery/artifact/artifact = holder
	if(istype(artifact))
		artifact.effect_slept(src, quiet)

/// Hook: it just woke.
/datum/artifact_effect/proc/on_activate()
	return

/// Hook: it just went to sleep.
/datum/artifact_effect/proc/on_deactivate()
	return

/// The light it gives off while awake as list(range, power, colour), or null to leave the
/// artifact's own glow alone. Light and darkness effects override this.
/datum/artifact_effect/proc/light_override()
	return null

// ===== Releasing =====

/// Refills the store. Called every process, awake or not.
/datum/artifact_effect/proc/recharge(seconds_per_tick)
	current_charge = min(maximum_charges, current_charge + ARTIFACT_RECHARGE_PER_SECOND * seconds_per_tick)

/// Called by the holder every process: lets an expired wake lapse, then releases an aura or pulse.
/datum/artifact_effect/proc/tick(seconds_per_tick)
	if(!activated)
		return
	if(world.time >= awake_until)
		deactivate()
		return
	switch(release_method)
		if(ARTIFACT_RELEASE_AURA)
			release_aura(seconds_per_tick)
		if(ARTIFACT_RELEASE_PULSE)
			release_pulse()

/datum/artifact_effect/proc/release_aura(seconds_per_tick)
	var/cost = ARTIFACT_AURA_COST_PER_SECOND * seconds_per_tick
	if(exhausted)
		if(current_charge < maximum_charges)
			return
		set_exhausted(FALSE)
	if(current_charge < cost)
		set_exhausted(TRUE)
		return
	current_charge -= cost
	do_effect_aura(seconds_per_tick)

/datum/artifact_effect/proc/release_pulse()
	if(current_charge < maximum_charges)
		return
	current_charge = 0
	var/obj/machinery/artifact/artifact = holder
	if(istype(artifact))
		artifact.effect_pulsed(src)
	do_effect_pulse(maximum_charges)

/datum/artifact_effect/proc/set_exhausted(new_value)
	if(exhausted == new_value)
		return
	exhausted = new_value
	var/obj/machinery/artifact/artifact = holder
	if(istype(artifact))
		artifact.update_activity_visuals()

/// Someone touched its holder. Returns TRUE if it acted on them.
/datum/artifact_effect/proc/touch(mob/living/user)
	if(!activated || release_method != ARTIFACT_RELEASE_TOUCH || !isliving(user))
		return FALSE
	if(current_charge < touch_cost)
		return FALSE
	current_charge -= touch_cost
	do_effect_touch(user)
	return TRUE

/// Hook: acts on one person touching it.
/datum/artifact_effect/proc/do_effect_touch(mob/living/user)
	return

/// Hook: acts on everything in range, once per process while the aura runs.
/datum/artifact_effect/proc/do_effect_aura(seconds_per_tick)
	return

/// Hook: one burst. `power` is the charge spent, from 5 to 50.
/datum/artifact_effect/proc/do_effect_pulse(power)
	return

/// Hook: its artifact was smashed. Harmful effects let off one last burst; helpful ones nothing.
/datum/artifact_effect/proc/do_effect_destroy()
	if(helpful)
		return
	do_effect_pulse(maximum_charges)

// ===== Helpers for subtypes =====

/// The turf it acts from.
/datum/artifact_effect/proc/source_turf()
	return get_turf(holder)

/// Living mobs within its range (plus `extra_range`).
/datum/artifact_effect/proc/living_in_range(extra_range = 0)
	. = list()
	var/turf/center = source_turf()
	if(!center)
		return
	for(var/mob/living/target in range(range + extra_range, center))
		. += target

/// Who answers for harm it does: whoever set it going on a battery, else whoever last woke or
/// moved its artifact.
/datum/artifact_effect/proc/get_responsible()
	var/mob/responsible = responsible_ref?.resolve()
	if(responsible)
		return responsible
	var/obj/machinery/artifact/artifact = holder
	if(istype(artifact))
		return artifact.last_disturbed_by?.resolve()
	return null

/datum/artifact_effect/proc/set_responsible(mob/user)
	responsible_ref = user ? WEAKREF(user) : null

/// Logs harm to `victim` like a weapon hit, at most twice a minute per victim.
/datum/artifact_effect/proc/log_harm(mob/living/victim)
	if(!harmful || !istype(victim) || QDELETED(holder))
		return
	var/key = REF(victim)
	if(LAZYACCESS(last_logged, key) > world.time - 30 SECONDS)
		return
	LAZYSET(last_logged, key, world.time)
	var/mob/responsible = get_responsible()
	log_combat(responsible || holder, victim, "exposed", holder, "to [log_name]")

/// Hook: it had a limited number of uses (lives, a gas reserve) and has none left. A spent
/// effect does nothing more and sells as common (pricing_tier()).
/datum/artifact_effect/proc/is_spent()
	return FALSE

/// The tier buyers price it at: its own, or common once it is spent.
/datum/artifact_effect/proc/pricing_tier()
	return is_spent() ? ARTIFACT_TIER_COMMON : tier

/// What the analyser can read off it: list("kind", "release", "family"), in report words.
/datum/artifact_effect/proc/report_parts()
	var/datum/artifact_energy_kind/kind = artifact_energy_kind(energy_kind)
	var/release_text
	switch(release_method)
		if(ARTIFACT_RELEASE_AURA)
			release_text = "released as a field"
		if(ARTIFACT_RELEASE_PULSE)
			release_text = "released in bursts"
		else
			release_text = "released on contact"
	var/family_text
	switch(artifact_trigger_family(trigger))
		if(ARTIFACT_FAMILY_CONTACT)
			family_text = "Reacts to physical contact."
		if(ARTIFACT_FAMILY_ENERGY)
			family_text = "Reacts to energetic contact."
		else
			family_text = "Reacts to its surroundings."
	return list("kind" = kind.report_name, "release" = release_text, "family" = family_text)

/// One report line, such as "Electromagnetic energy, released in bursts. Reacts to energetic contact."
/datum/artifact_effect/proc/report_line()
	var/list/parts = report_parts()
	return "[parts["kind"]], [parts["release"]]. [parts["family"]]"

/**
 * A copy of this effect for a battery (harvesting). Same kind, release, trigger, strength and
 * subtype settings, with an empty store. The copy's holder is `new_holder`.
 */
/datum/artifact_effect/proc/make_harvest_copy(atom/new_holder)
	var/datum/artifact_effect/copy = new type(new_holder, null)
	copy.energy_kind = energy_kind
	copy.release_method = release_method
	copy.trigger = trigger
	copy.strength = strength
	copy.range = range
	copy.maximum_charges = maximum_charges
	copy.touch_cost = touch_cost
	copy.current_charge = 0
	copy_settings_to(copy)
	return copy

/// Hook: copy subtype settings (target temperature, gas, and so on) onto a harvest copy.
/datum/artifact_effect/proc/copy_settings_to(datum/artifact_effect/copy)
	return

// ===== Catalogue =====

/// Every rollable effect type (has a label_name), built once.
/proc/artifact_effect_types()
	var/static/list/types
	if(!types)
		types = list()
		for(var/datum/artifact_effect/effect_type as anything in subtypesof(/datum/artifact_effect))
			if(initial(effect_type.label_name))
				types += effect_type
	return types

/// The labeler's "what it does" words: every rollable effect's label_name, sorted, no repeats.
/proc/artifact_effect_label_names()
	var/static/list/names
	if(!names)
		names = list()
		for(var/datum/artifact_effect/effect_type as anything in artifact_effect_types())
			names |= initial(effect_type.label_name)
		sortTim(names, GLOBAL_PROC_REF(cmp_text_asc))
	return names.Copy()

/// Rolls a main-effect tier for a large find from its band.
/proc/xenoarch_roll_tier(band)
	var/list/odds
	switch(XENOARCH_BAND_INDEX(band))
		if(ZONE_RED)
			odds = ARTIFACT_TIER_ODDS_RED
		if(ZONE_YELLOW)
			odds = ARTIFACT_TIER_ODDS_YELLOW
		else
			odds = ARTIFACT_TIER_ODDS_GREEN
	return max(xenoarch_pick_weighted_index(odds), ARTIFACT_TIER_COMMON)

/**
 * Picks an effect type.
 *
 * * tier - ARTIFACT_TIER_* to pick from, or null for any tier (minor picks)
 * * band - stamped band, for band weights
 * * minor_only - only effects that may be a second effect
 * * exclude - a type not to pick (the main effect, when picking the second)
 *
 * Falls back to lower tiers if a tier has nothing to offer.
 */
/proc/xenoarch_pick_effect_type(tier, band, minor_only = FALSE, exclude)
	var/band_index = XENOARCH_BAND_INDEX(band)
	for(var/try_tier = tier || ARTIFACT_TIER_EXTREME; try_tier >= ARTIFACT_TIER_COMMON; try_tier--)
		var/list/candidates = list()
		var/list/weights = list()
		for(var/datum/artifact_effect/effect_type as anything in artifact_effect_types())
			if(effect_type == exclude)
				continue
			if(minor_only && !initial(effect_type.minor))
				continue
			if(tier && initial(effect_type.tier) != try_tier)
				continue
			var/band_mult = initial(effect_type.green_weight)
			if(band_index == ZONE_YELLOW)
				band_mult = initial(effect_type.yellow_weight)
			else if(band_index == ZONE_RED)
				band_mult = initial(effect_type.red_weight)
			var/effect_weight = initial(effect_type.weight) * band_mult
			if(effect_weight <= 0)
				continue
			candidates += effect_type
			weights += effect_weight
		var/index = xenoarch_pick_weighted_index(weights)
		if(index)
			return candidates[index]
		if(!tier)
			break
	return null
