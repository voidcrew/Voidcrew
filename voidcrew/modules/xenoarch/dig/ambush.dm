/**
 * # Dig ambush
 *
 * Freeing a large find in a yellow or red site can wake whatever lives in the rock nearby
 * (XENOARCH_AMBUSH_CHANCE). The ground rumbles first, then a pack crawls out a few tiles off,
 * never on top of the crew. Reuses the field-expedition wave: a zone mob marker with a 1 to 2
 * count, wildlife or spiders, scaled by the site's own zone.
 */

/// How long the rumble lasts before something comes out.
#define DIG_AMBUSH_WARNING (3 SECONDS)

/// Rolls for an ambush at a freed find. Returns TRUE if one is coming.
/proc/xenoarch_dig_ambush(turf/site, band, mob/digger)
	if(!isturf(site))
		return FALSE
	var/list/chances = XENOARCH_AMBUSH_CHANCE
	if(!prob(chances[XENOARCH_BAND_INDEX(band)]))
		return FALSE
	var/turf/lair = xenoarch_ambush_lair(site)
	if(!lair)
		return FALSE
	playsound(lair, pick(
		'sound/ambience/earth_rumble/earth_rumble_distant1.ogg',
		'sound/ambience/earth_rumble/earth_rumble_distant2.ogg',
		'sound/ambience/earth_rumble/earth_rumble_distant3.ogg',
	), 70, FALSE, 4)
	site.visible_message(span_warning("The ground shudders. Something answers the noise from deeper in the rock."))
	new /obj/effect/temp_visual/xenoarch_dust(lair, "#8f8a83", FALSE)
	var/theme = pick_weight(list(
		/obj/effect/zone_mobs/wildlife = 6,
		/obj/effect/zone_mobs/bug = 4,
	))
	addtimer(CALLBACK(GLOBAL_PROC, GLOBAL_PROC_REF(xenoarch_spring_ambush), lair, theme), DIG_AMBUSH_WARNING)
	if(digger)
		log_game("[key_name(digger)] woke a dig-site ambush at [AREACOORD(lair)].")
	return TRUE

/// Open ground 4 to 7 tiles from the find, preferably against the rock, for the pack to come from.
/proc/xenoarch_ambush_lair(turf/site)
	var/list/by_rock = list()
	var/list/open = list()
	for(var/turf/open/tile in RANGE_TURFS(7, site))
		if(get_dist(tile, site) < 4 || isgroundlessturf(tile) || tile.is_blocked_turf(exclude_mobs = TRUE))
			continue
		if(istype(tile, /turf/open/water) || istype(tile, /turf/open/lava))
			continue
		if(!istype(tile.loc, /area/overmap_encounter/planetoid))
			continue
		open += tile
		for(var/direction in GLOB.cardinals)
			if(ismineralturf(get_step(tile, direction)))
				by_rock += tile
				break
	if(length(by_rock))
		return pick(by_rock)
	return length(open) ? pick(open) : null

/// The pack comes out, unless the planet went away in the meantime.
/proc/xenoarch_spring_ambush(turf/lair, theme)
	if(!isopenturf(lair) || !istype(lair.loc, /area/overmap_encounter/planetoid))
		return
	playsound(lair, 'sound/effects/break_stone.ogg', 60, TRUE)
	new /obj/effect/temp_visual/xenoarch_dust(lair, "#8f8a83", FALSE)
	new theme(lair, list(1, 2))

#undef DIG_AMBUSH_WARNING
