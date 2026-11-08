/**
 * # Xenoarchaeology helpers
 *
 * Small shared procs: bands, serials, the trigger vocabulary and weighted picks.
 */

/// The ZONE_* a turf belongs to, for stamping a find. Falls back to green, the lowest price,
/// so a failed lookup can never inflate a payout.
/proc/xenoarch_band_for_turf(turf/location)
	location = get_turf(location)
	if(!location)
		return ZONE_GREEN
	var/zone_type = SSovermap_zones.get_zone_type_anywhere(location)
	if(zone_type == ZONE_YELLOW || zone_type == ZONE_RED)
		return zone_type
	return ZONE_GREEN

/// "green", "yellow" or "red", for metrics and logs.
/proc/xenoarch_band_name(band)
	switch(band)
		if(ZONE_YELLOW)
			return "yellow"
		if(ZONE_RED)
			return "red"
	return "green"

/// Every serial handed out this round, so no two finds share one.
GLOBAL_LIST_EMPTY(artifact_serials_used)

/// A catalogue number such as "Kappa-4412". Unique for the round.
/proc/xenoarch_new_serial()
	var/static/list/letters = list(
		"Alpha", "Beta", "Gamma", "Delta", "Epsilon", "Zeta", "Eta", "Theta",
		"Iota", "Kappa", "Lambda", "Mu", "Nu", "Xi", "Omicron", "Pi",
		"Rho", "Sigma", "Tau", "Upsilon", "Phi", "Chi", "Psi", "Omega",
	)
	for(var/attempt in 1 to 50)
		var/serial = "[pick(letters)]-[rand(1000, 9999)]"
		if(!GLOB.artifact_serials_used[serial])
			GLOB.artifact_serials_used[serial] = TRUE
			return serial
	// 24 letters x 9000 numbers; fifty misses means the round has dug an absurd amount.
	var/fallback = "Omega-[length(GLOB.artifact_serials_used) + 10000]"
	GLOB.artifact_serials_used[fallback] = TRUE
	return fallback

/// The plain word for a trigger, as the labeler lists it and a label records it.
/proc/artifact_trigger_name(trigger)
	switch(trigger)
		if(ARTIFACT_TRIGGER_TOUCH)
			return "Touch"
		if(ARTIFACT_TRIGGER_WATER)
			return "Water"
		if(ARTIFACT_TRIGGER_ACID)
			return "Acid"
		if(ARTIFACT_TRIGGER_VOLATILE)
			return "Volatile chemicals"
		if(ARTIFACT_TRIGGER_TOXIN)
			return "Toxins"
		if(ARTIFACT_TRIGGER_IMPACT)
			return "Impact"
		if(ARTIFACT_TRIGGER_ENERGY)
			return "Electricity"
		if(ARTIFACT_TRIGGER_HEAT)
			return "Heat"
		if(ARTIFACT_TRIGGER_COLD)
			return "Cold"
		if(ARTIFACT_TRIGGER_PLASMA)
			return "Plasma"
		if(ARTIFACT_TRIGGER_CO2)
			return "Carbon dioxide"
		if(ARTIFACT_TRIGGER_PROXIMITY)
			return "Proximity"
	return "Unknown"

/// Every trigger word, in the labeler's order.
/proc/artifact_trigger_label_names()
	var/static/list/names
	if(!names)
		names = list()
		for(var/trigger in ARTIFACT_ALL_TRIGGERS)
			names += artifact_trigger_name(trigger)
	return names.Copy()

/// Which family the analyser reports a trigger under.
/proc/artifact_trigger_family(trigger)
	if(trigger & (ARTIFACT_TRIGGER_TOUCH | ARTIFACT_TRIGGER_WATER | ARTIFACT_TRIGGER_ACID | ARTIFACT_TRIGGER_VOLATILE | ARTIFACT_TRIGGER_TOXIN))
		return ARTIFACT_FAMILY_CONTACT
	if(trigger & (ARTIFACT_TRIGGER_IMPACT | ARTIFACT_TRIGGER_ENERGY | ARTIFACT_TRIGGER_HEAT | ARTIFACT_TRIGGER_COLD))
		return ARTIFACT_FAMILY_ENERGY
	return ARTIFACT_FAMILY_AIR

/// How often an effect rolls this trigger, relative to the others.
/proc/artifact_trigger_weight(trigger)
	switch(trigger)
		if(ARTIFACT_TRIGGER_PROXIMITY)
			return 4
		if(ARTIFACT_TRIGGER_PLASMA, ARTIFACT_TRIGGER_CO2)
			return 8
	return 10

/// Picks an index from a positional list of weights. Returns 0 if every weight is 0.
/proc/xenoarch_pick_weighted_index(list/weights)
	var/total = 0
	for(var/weight in weights)
		total += max(weight, 0)
	if(total <= 0)
		return 0
	var/roll = rand() * total
	for(var/index in 1 to length(weights))
		roll -= max(weights[index], 0)
		if(roll < 0)
			return index
	return length(weights)

/**
 * How exposed a mob is to an artifact, from 0 (fully protected) to 1 (bare).
 * Biosuits do most of it; latex gloves and science goggles help a little. Ported from Nova's
 * get_anomaly_protection(), reading bio armor with getarmor() instead of Nova's helper.
 */
/proc/artifact_exposure(mob/living/target)
	if(!ishuman(target))
		return 1
	var/mob/living/carbon/human/person = target
	var/protection = 0
	if(person.getarmor(BODY_ZONE_CHEST, BIO) >= 85)
		protection += 0.5
	if(person.getarmor(BODY_ZONE_HEAD, BIO) >= 85)
		protection += 0.3
	if(istype(person.gloves, /obj/item/clothing/gloves/latex))
		protection += 0.1
	if(istype(person.glasses, /obj/item/clothing/glasses/science))
		protection += 0.1
	return clamp(1 - protection, 0, 1)

/// Whether a mob's touch counts as touching the artifact's surface: a bare hand, or any gloves
/// that are not latex. Things without hands always count.
/proc/artifact_touch_counts(mob/living/toucher)
	if(!iscarbon(toucher))
		return TRUE
	var/mob/living/carbon/carbon_toucher = toucher
	var/obj/item/clothing/gloves/worn = carbon_toucher.get_item_by_slot(ITEM_SLOT_GLOVES)
	return !istype(worn, /obj/item/clothing/gloves/latex)

// ===== Healing cap =====
// Heal and robo-heal effects share one budget per person across every artifact and utilizer:
// ARTIFACT_HEAL_CAP brute plus burn per ARTIFACT_HEAL_WINDOW.

#define ARTIFACT_HEAL_CAP 30
#define ARTIFACT_HEAL_WINDOW (5 MINUTES)

/// REF(mob) -> list(window ends at, amount healed in the window). Holds no hard references.
GLOBAL_LIST_EMPTY(artifact_heal_ledger)

/// How much artifact healing this mob may still take in its current window.
/proc/artifact_heal_allowance(mob/living/target)
	var/list/entry = GLOB.artifact_heal_ledger[REF(target)]
	if(!entry || world.time >= entry[1])
		return ARTIFACT_HEAL_CAP
	return max(ARTIFACT_HEAL_CAP - entry[2], 0)

/// Records artifact healing against this mob's window.
/proc/artifact_record_heal(mob/living/target, amount)
	if(amount <= 0)
		return
	var/key = REF(target)
	var/list/entry = GLOB.artifact_heal_ledger[key]
	if(!entry || world.time >= entry[1])
		entry = list(world.time + ARTIFACT_HEAL_WINDOW, 0)
		GLOB.artifact_heal_ledger[key] = entry
		// Lazy sweep of stale windows so the ledger never grows past the people healed recently.
		if(length(GLOB.artifact_heal_ledger) > 50)
			for(var/old_key in GLOB.artifact_heal_ledger)
				var/list/old = GLOB.artifact_heal_ledger[old_key]
				if(world.time >= old[1])
					GLOB.artifact_heal_ledger -= old_key
	entry[2] += amount

/**
 * Heals brute and burn on `target`, never past what the shared cap allows.
 * Returns the amount actually healed.
 *
 * * required_bodytype - limit to robotic or organic limbs on carbons (heal_overall_damage's arg)
 */
/proc/artifact_capped_heal(mob/living/target, amount, required_bodytype)
	var/allowed = min(amount, artifact_heal_allowance(target))
	if(allowed <= 0)
		return 0
	var/before = target.getBruteLoss() + target.getFireLoss()
	target.heal_overall_damage(allowed / 2, allowed / 2, required_bodytype = required_bodytype)
	var/healed = max(before - (target.getBruteLoss() + target.getFireLoss()), 0)
	artifact_record_heal(target, healed)
	return healed

#undef ARTIFACT_HEAL_CAP
#undef ARTIFACT_HEAL_WINDOW

// ===== Reagent triggers =====

/// Reagents that count as volatile (Nova's GLOB.volatile_reagents).
GLOBAL_LIST_INIT(artifact_volatile_reagents, typecacheof(list(
	/datum/reagent/thermite,
	/datum/reagent/toxin/plasma,
	/datum/reagent/nitroglycerin,
	/datum/reagent/clf3,
	/datum/reagent/sorium,
	/datum/reagent/liquid_dark_matter,
	/datum/reagent/gunpowder,
	/datum/reagent/rdx,
	/datum/reagent/tatp,
	/datum/reagent/flash_powder,
	/datum/reagent/phlogiston,
	/datum/reagent/napalm,
	/datum/reagent/pyrosium,
	/datum/reagent/teslium,
)))

/// The trigger one reagent type counts as, or NONE.
/proc/artifact_reagent_trigger(reagent_type)
	if(!ispath(reagent_type, /datum/reagent))
		return NONE
	if(ispath(reagent_type, /datum/reagent/water) || ispath(reagent_type, /datum/reagent/hydrogen))
		return ARTIFACT_TRIGGER_WATER
	if(ispath(reagent_type, /datum/reagent/toxin/acid))
		return ARTIFACT_TRIGGER_ACID
	if(GLOB.artifact_volatile_reagents[reagent_type])
		return ARTIFACT_TRIGGER_VOLATILE
	if(ispath(reagent_type, /datum/reagent/toxin) || ispath(reagent_type, /datum/reagent/consumable/ethanol/neurotoxin))
		return ARTIFACT_TRIGGER_TOXIN
	return NONE

/// Every trigger a list of reagents counts as (datums or types), as one bitfield.
/proc/artifact_reagent_triggers(list/reagents)
	. = NONE
	for(var/reagent in reagents)
		var/reagent_type = reagent
		if(istype(reagent, /datum/reagent))
			var/datum/reagent/reagent_datum = reagent
			reagent_type = reagent_datum.type
		. |= artifact_reagent_trigger(reagent_type)
