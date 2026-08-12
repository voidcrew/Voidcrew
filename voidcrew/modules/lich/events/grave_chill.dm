/**
 * Ritual: The Cold of the Ground, ship-scoped, no upstream original.
 *
 * The hull goes grave-cold for a minute. Put something on.
 *
 * Written rather than ported, to fill the hole left when the item-cursing rites were cut:
 * a rite must be *pressure*, not a lasting nuisance. Everything about this one is
 * temporary. It takes nothing, marks nothing, and leaves nothing behind, body temperature
 * climbs back on its own the moment the rite ends, and a crewmember who was wearing a coat
 * the whole time is barely inconvenienced. That is the intended shape of the whole roster;
 * see The Floor Is Grave-Dirt for the same idea with a different verb.
 *
 * The temperature math is lifted from `/datum/weather/weather_act_mob()`
 * (code/datums/weather/weather.dm:382-393) rather than reinvented: carbons go through
 * `adjust_bodytemperature(use_insulation = TRUE, use_steps = TRUE)`, and anything else gets
 * the divisor-and-clamp path the weather base uses for non-carbons. Copied because the
 * proc it lives on is reached only through SSweather's z-indexed pipeline, which is exactly
 * what a ship-scoped rite cannot use (see grave_dirt.dm's header for the full argument).
 *
 * Deliberately NOT bypassing clothing, unlike the snowstorm it borrows from
 * (`WEATHER_TEMPERATURE_BYPASS_CLOTHING`, snow_storm.dm:31). Insulation counting is the
 * counterplay: a winter coat, a hardsuit, or standing in a room the heaters are still
 * winning in. A rite with no answer is just damage on a timer.
 */

/// How cold the deck gets. Space-cold would kill through a jumpsuit in the minute this
/// runs; this is "the ship's heating lost, badly", which hurts an unprepared crew and is
/// survivable for a prepared one.
#define GRAVE_CHILL_TEMPERATURE (T0C - 55)

/datum/round_event_control/voidcrew/lich/grave_chill
	name = "Ritual: The Cold of the Ground"
	typepath = /datum/round_event/voidcrew/lich/grave_chill
	description = "The deck of the target ship runs grave-cold for about a minute."
	/**
	 * The low band's workhorse, and safe to repeat for the same reasons grave_dirt is: it
	 * self-terminates, the damage is ordinary cold that medical and a warm room both fix,
	 * and the counterplay (dress for it) never stops working.
	 */
	max_occurrences = 12
	event_scope = EVENT_SCOPE_SHIP
	min_wizard_trigger_potency = 0
	max_wizard_trigger_potency = 4

/datum/round_event/voidcrew/lich/grave_chill
	announce_when = 1
	/// Fifteen seconds of warning, matching the other hazard rites.
	start_when = 8
	/// About a minute of cold.
	end_when = 38

/datum/round_event/voidcrew/lich/grave_chill/announce(fake)
	lich_announce_ship(
		"You keep your ship warmer than the ground does. I have never understood why you \
		bother, you will be cold for a great deal longer than you were ever warm. \
		Here is a minute of it, so you know what you are arguing with.",
		"The Cold of the Ground",
		'sound/effects/magic/curse.ogg',
	)
	for(var/mob/living/warned as anything in target_ship.get_all_mobs_aboard())
		to_chat(warned, span_warning("The deck plating starts pulling the heat out of your boots. Your breath is showing."))

/datum/round_event/voidcrew/lich/grave_chill/start()
	if(!target_valid())
		kill()
		return
	build_rite_overlays("light_snow", overlay_alpha = 140, overlay_layer = ABOVE_OPEN_TURF_LAYER, overlay_plane = FLOOR_PLANE)
	refresh_rite_overlays()
	for(var/mob/living/victim as anything in target_ship.get_all_mobs_aboard())
		to_chat(victim, span_userdanger("The cold arrives all at once. Get something on, or get somewhere warm!"))

/datum/round_event/voidcrew/lich/grave_chill/tick()
	if(!target_valid())
		return
	refresh_rite_overlays()
	for(var/mob/living/victim as anything in target_ship.get_all_mobs_aboard())
		if(QDELETED(victim) || !can_chill(victim))
			continue
		chill_mob(victim)

/datum/round_event/voidcrew/lich/grave_chill/end()
	// Runs whether or not the ship survived. The overlays are tracked against the areas.
	remove_rite_overlays()
	if(!target_valid())
		return
	for(var/mob/living/victim as anything in target_ship.get_all_mobs_aboard())
		to_chat(victim, span_notice("The cold lets go of the deck. The heaters start winning again."))

/// Whether the cold reaches this mob at all.
/datum/round_event/voidcrew/lich/grave_chill/proc/can_chill(mob/living/victim)
	if(issilicon(victim))
		return FALSE
	if(HAS_TRAIT(victim, TRAIT_RESISTCOLD) || HAS_TRAIT(victim, TRAIT_WEATHER_IMMUNE))
		return FALSE
	// Never trust position: they may have stepped off the ship since the last tick, and a
	// mob inside a locker, a mech or a sleeper is inside that thing's air, not the deck's.
	if(!isturf(victim.loc))
		return FALSE
	return target_ship.is_aboard(victim.loc)

/**
 * Pulls one mob's body temperature toward the deck's.
 * Same two branches as /datum/weather/weather_act_mob(), insulation left ON.
 */
/datum/round_event/voidcrew/lich/grave_chill/proc/chill_mob(mob/living/victim)
	var/temperature_delta = GRAVE_CHILL_TEMPERATURE - victim.bodytemperature
	if(temperature_delta >= 0)
		return // Already at least as cold as the deck. Nothing to take.
	if(iscarbon(victim))
		var/mob/living/carbon/carbon_victim = victim
		carbon_victim.adjust_bodytemperature(temperature_delta, use_insulation = TRUE, use_steps = TRUE)
		return
	// Non-carbons have no insulation model; step and clamp exactly as the weather base does.
	temperature_delta = max(temperature_delta / BODYTEMP_COLD_DIVISOR, BODYTEMP_COOLING_MAX)
	victim.adjust_bodytemperature(temperature_delta)

#undef GRAVE_CHILL_TEMPERATURE
