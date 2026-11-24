// Artifact effect: sweat.
// Rewritten from Polaris (6cd19fe0dec6) code/modules/xenoarcheaology/effects/sweating_reagents.dm.
// Voidcrew: Polaris could weep any reagent in the game (and blood); this weeps one mild,
// everyday liquid picked from a short list, so it is never a free source of anything worth
// having. It pools into a small puddle that can be mopped or scooped up, and a puddle stops
// growing once it holds a cupful.

/// A puddle stops growing once it holds this many units
#define ARTIFACT_SWEAT_PUDDLE_CAP 30

/datum/artifact_effect/sweat
	label_name = "Weeps fluid"
	log_name = "Sweat"
	tier = ARTIFACT_TIER_COMMON
	minor = TRUE
	possible_kinds = list(ARTIFACT_ENERGY_ORGANIC, ARTIFACT_ENERGY_SYNTHESIS)
	/// What it weeps
	var/datum/reagent/reagent_type = /datum/reagent/water

/datum/artifact_effect/sweat/setup()
	var/static/list/weepings = list(
		/datum/reagent/water,
		/datum/reagent/water/salt,
		/datum/reagent/consumable/sugar,
		/datum/reagent/consumable/nutriment/fat/oil,
		/datum/reagent/consumable/vinegar,
	)
	reagent_type = pick(weepings)

/datum/artifact_effect/sweat/copy_settings_to(datum/artifact_effect/sweat/copy)
	copy.reagent_type = reagent_type

/datum/artifact_effect/sweat/do_effect_touch(mob/living/user)
	var/turf/user_turf = get_turf(user)
	if(prob(25) && weep(user_turf, 6))
		var/atom/source = istype(holder, /obj/machinery/artifact) ? holder : null
		user.visible_message(
			span_warning("[source ? "[source] shudders at [user]'s touch and spits" : "Something spits"] a slick of fluid across [user]'s feet!"),
			span_warning("[source ? "[source] shudders at your touch and spits" : "Something spits"] a slick of fluid across your feet!"),
		)
		playsound(user_turf, 'sound/effects/splat.ogg', 35, TRUE)
		return
	weep(source_turf(), 2)
	to_chat(user, span_notice("A cold, slick film beads on your skin."))

/datum/artifact_effect/sweat/do_effect_aura(seconds_per_tick)
	if(SPT_PROB(25, seconds_per_tick) && weep(source_turf(), 2))
		playsound(source_turf(), 'sound/effects/bubbles/bubbles.ogg', 15, TRUE, SILENCED_SOUND_EXTRARANGE)

/datum/artifact_effect/sweat/do_effect_pulse(power)
	var/turf/center = source_turf()
	if(!center)
		return
	var/spilled = weep(center, clamp(power / 4, 2, 10))
	var/list/neighbours = list()
	for(var/turf/open/spot in orange(1, center))
		neighbours += spot
	for(var/i in 1 to min(3, length(neighbours)))
		spilled = weep(pick_n_take(neighbours), clamp(power / 8, 1, 5)) || spilled
	if(spilled)
		if(istype(holder, /obj/machinery/artifact))
			center.visible_message(span_warning("[holder] shudders and spits fluid across the floor."))
		else
			center.visible_message(span_warning("Fluid spatters across the floor."))
		playsound(center, 'sound/effects/splat.ogg', 40, TRUE)

/// Adds `amount` of its liquid to a puddle on `spot`. Returns TRUE if any went in.
/datum/artifact_effect/sweat/proc/weep(turf/open/spot, amount)
	if(!istype(spot) || amount <= 0 || isspaceturf(spot) || isgroundlessturf(spot) || islava(spot))
		return FALSE
	var/obj/effect/decal/cleanable/artifact_ooze/puddle = locate() in spot
	if(!puddle)
		puddle = new(spot)
		if(QDELETED(puddle))
			return FALSE
	if(!puddle.reagents)
		puddle.create_reagents(ARTIFACT_SWEAT_PUDDLE_CAP)
	var/room = ARTIFACT_SWEAT_PUDDLE_CAP - puddle.reagents.total_volume
	if(room <= 0)
		return FALSE
	puddle.reagents.add_reagent(reagent_type, min(amount, room))
	// Just the hue: water's own colour is nearly clear and the slick would vanish.
	puddle.color = copytext(initial(reagent_type.color), 1, 8)
	return TRUE

/// A puddle of whatever an artifact wept. Scoop it up with a container, or mop it.
/obj/effect/decal/cleanable/artifact_ooze
	name = "slick"
	desc = "A small, faintly warm puddle of something thin."
	icon = 'icons/effects/blood.dmi'
	icon_state = "floor1"
	random_icon_states = list("floor1", "floor2", "floor3", "floor4", "floor5", "floor6", "floor7")
	alpha = 200
	beauty = -25
	mergeable_decal = FALSE

#undef ARTIFACT_SWEAT_PUDDLE_CAP
