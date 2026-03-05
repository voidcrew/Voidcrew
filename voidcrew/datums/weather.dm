/// Override planet weather types to scope area_type to planet areas only.
/// Without this, weather uses area_type = /area which matches ALL areas,
/// causing weather overlays to appear on space tiles outside planet bounds.

/datum/weather/ash_storm
	area_type = /area/overmap_encounter/planetoid

/datum/weather/snow_storm
	area_type = /area/overmap_encounter/planetoid

/datum/weather/rain_storm
	area_type = /area/overmap_encounter/planetoid

/datum/weather/sand_storm
	area_type = /area/overmap_encounter/planetoid

/// Skip the explosion on water turfs so lightning doesn't dredge up fish via explosive_fishing.
/datum/weather/thunder_act_turf(turf/open/weather_turf)
	if(iswaterturf(weather_turf))
		var/obj/effect/temp_visual/thunderbolt/thunder = new(weather_turf)
		thunder.flash_lighting_fx(6, 2, duration = thunder.duration)
		if(thunder_color)
			thunder.color = thunder_color
		for(var/mob/living/hit_mob in weather_turf)
			to_chat(hit_mob, span_userdanger("You've been struck by lightning!"))
			hit_mob.electrocute_act(50, "thunder", flags = SHOCK_TESLA|SHOCK_NOGLOVES)
		for(var/obj/hit_thing in weather_turf)
			if(QDELETED(hit_thing))
				continue
			if(!hit_thing.uses_integrity)
				continue
			if(hit_thing.invisibility != INVISIBILITY_NONE)
				continue
			if(HAS_TRAIT(hit_thing, TRAIT_UNDERFLOOR))
				continue
			hit_thing.take_damage(20, BURN, ENERGY, FALSE)
		playsound(weather_turf, 'sound/effects/magic/lightningbolt.ogg', 100, extrarange = 10, falloff_distance = 10)
		weather_turf.visible_message(span_danger("A thunderbolt strikes [weather_turf]!"))
		return
	return ..()
