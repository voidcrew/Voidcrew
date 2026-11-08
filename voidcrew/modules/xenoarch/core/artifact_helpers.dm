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
