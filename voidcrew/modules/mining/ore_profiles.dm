/// Return copies: neither callers nor the expanded wall cache may mutate the profiles.
/proc/ordinary_ore_weights(zone_type)
	var/static/list/profiles = list(
		list(110, 40, 16, 16, 8, 5, 2, 2, 1),
		list(80, 40, 20, 20, 16, 12, 6, 4, 2),
		list(50, 36, 24, 24, 24, 20, 12, 8, 2),
	)
	var/static/list/ores = list(
		/obj/item/stack/ore/iron,
		/obj/item/stack/ore/plasma,
		/obj/item/stack/ore/silver,
		/obj/item/stack/ore/titanium,
		/obj/item/stack/ore/gold,
		/obj/item/stack/ore/uranium,
		/obj/item/stack/ore/diamond,
		/obj/item/stack/ore/bluespace_crystal,
		/obj/item/stack/ore/bananium,
	)
	var/list/weights = profiles[ordinary_ore_zone(zone_type)]
	var/list/result = list()
	for(var/index in 1 to length(ores))
		result[ores[index]] = weights[index]
	return result

/proc/ordinary_ore_zone(zone_type)
	return (zone_type == ZONE_YELLOW || zone_type == ZONE_RED) ? zone_type : ZONE_GREEN

/proc/is_ordinary_ore(ore_type)
	var/static/list/ores = ordinary_ore_weights(ZONE_GREEN)
	return ore_type in ores

/obj/structure/overmap/planet/proc/ore_zone()
	if(!isnull(zone_band))
		return ordinary_ore_zone(zone_band)
	var/turf/chart = get_turf(src)
	if(!istype(chart, /turf/open/overmap))
		return ZONE_GREEN
	return ordinary_ore_zone(SSovermap_zones?.resolve_zone_for_overmap_turf(chart))

/// Resolve the wall's own site, including during terrain generation. Never cache by z.
/turf/closed/mineral/proc/ore_profile_zone()
	var/obj/structure/overmap/holder = SSovermap_zones?.get_overmap_object_for_turf(src)
	if(istype(holder, /obj/structure/overmap/planet))
		var/obj/structure/overmap/planet/planet = holder
		return planet.ore_zone()
	if(holder)
		var/turf/chart = get_turf(holder)
		return istype(chart, /turf/open/overmap) ? ordinary_ore_zone(SSovermap_zones.resolve_zone_for_overmap_turf(chart)) : ZONE_GREEN
	return ordinary_ore_zone(SSmapping.get_planet_zone_band_for_turf(src))

/turf/closed/mineral/random/proc/ore_roll_chance()
	switch(ore_profile_zone())
		if(ZONE_YELLOW)
			return 12
		if(ZONE_RED)
			return 16
	return 8

/// A supplied percentile lets tests exercise the same boundary used by initialization.
/turf/closed/mineral/random/proc/ore_initial_roll(percentile = rand(1, 100))
	return percentile <= ore_roll_chance()

/turf/closed/mineral/random/proc/ore_spawn_choices()
	var/static/list/choices_by_profile = list()
	var/zone_type = ore_profile_zone()
	var/key = "[zone_type]:[type]"
	if(isnull(choices_by_profile[key]))
		var/list/weights = mineral_chances()
		if(!istype(src, /turf/closed/mineral/random/labormineral))
			// Replace only ordinary ore entries; authored special veins keep their weights.
			var/list/ordinary = ordinary_ore_weights(zone_type)
			for(var/ore in ordinary)
				weights[ore] = ordinary[ore]
		choices_by_profile[key] = expand_weights(weights)
	return choices_by_profile[key]

/// Only ordinary ore uses the new range. Gibtonite and gulag bookkeeping stay separate.
/turf/closed/mineral/proc/ordinary_ore_amount(ore_type)
	if(!is_ordinary_ore(ore_type))
		return mineralAmt
	if(istype(src, /turf/closed/mineral/random/asteroid_field))
		switch(ore_profile_zone())
			if(ZONE_YELLOW)
				return rand(1, 3)
			if(ZONE_RED)
				return rand(2, 3)
		return rand(1, 2)
	return rand(1, 3)

// The generator chooses these types before Initialize(), so there is only one ore roll.
/turf/closed/mineral/random/asteroid_field/ore_roll_chance()
	return 12

/turf/closed/mineral/random/asteroid_field/minor/ore_roll_chance()
	return 10

/turf/closed/mineral/random/asteroid_field/majour/ore_roll_chance()
	return 15

/turf/closed/mineral/random/labormineral/ore_roll_chance()
	return mineralChance
