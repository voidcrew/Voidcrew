/**
 * Ritual: The Floor Is Grave-Dirt. Ship-scoped port of TG's The Floor Is LAVA!
 * (code/modules/events/wizard/lava.dm).
 *
 * The deck of one ship turns into turned earth. Standing on it burns. Get on top of something.
 *
 * "Ship-scoped" is about plumbing, not blast radius: when the ritual clock fires this rite it
 * runs one instance per crewed hull via fire_ritual_on_every_ship() (lich_site.dm), so in
 * actual play every crew that is flying with people aboard gets it at the same time. The
 * per-ship instance is what keeps one crew's rite from touching another's, separate
 * lifecycle, separate tracked overlays, separate end(). The single-ship path you get from the
 * "Events: Force Dynamic Event" admin verb is the testing path, not the live one.
 *
 * TG's event is one line: `SSweather.run_weather(/datum/weather/floor_is_lava)`. That is not
 * reusable here and the reason is worth spelling out, because "just run the weather datum"
 * is the obvious wrong answer:
 *
 * - `/datum/weather/floor_is_lava` has `area_type = /area` and `target_trait = ZTRAIT_STATION`.
 *   In this fork ZTRAIT_STATION is applied to whatever z-levels currently hold a ship
 *   (voidcrew/mapping/docking_port/_docking_port.dm:108), so running it with the default trait
 *   would set fire to the floor of every crewed hull in the galaxy at once, plus any planet
 *   surface, ruin or trader outpost sharing those levels.
 * - Scoping it by z instead does not help. A flying ship shares its transit level with every
 *   other flying ship, and a docked ship shares its level with whatever it docked at.
 * - SSweather's own machinery is z-indexed end to end: it collects candidate mobs per
 *   z-level (weather.dm fire()), `can_weather_act_mob()` rejects anything off
 *   `impacted_z_levels`, and `send_alert()` broadcasts to `SSmobs.clients_by_zlevel`. Bending
 *   all of that into area scoping means overriding four procs on a subsystem the port spec
 *   explicitly tells ports to stay out of, and leaves a weather datum whose
 *   `impacted_z_levels` goes stale the moment the ship docks.
 *
 * So this port reimplements the effect directly on the event, which is a couple of dozen lines
 * and has no z in it anywhere.
 *
 * Kept faithful to /datum/weather/floor_is_lava:
 * - 3 fire damage per application, the telegraph/main/end three-stage structure, and the
 *   `lava` overlay from icons/effects/weather_effects.dmi drawn at ABOVE_OPEN_TURF_LAYER on
 *   FLOOR_PLANE so it covers floors and not walls.
 * - The full eligibility rule set from `can_weather_act_mob()`: silicons are exempt, anyone
 *   buckled to a bed is exempt, dense turfs and turfs with a dense structure on them are not
 *   floors, and anything flying or floating is not touching the ground. TRAIT_LAVA_IMMUNE and
 *   TRAIT_WEATHER_IMMUNE are honoured.
 *
 * Deliberately different:
 * - The overlay is recolored green. It is grave-dirt, not lava.
 * - Damage lands on every living mob aboard, not only ones with minds. The fork's weather
 *   patch excludes ordinary fauna for performance across whole planets; a ship holds a
 *   handful of mobs and "the floor burns everything standing on it" is the legible rule.
 * - The paint is re-asserted every tick rather than applied once at start(), and the area list
 *   is re-read from the shuttle every tick rather than cached. That machinery now lives on the
 *   base event as build/refresh/remove_rite_overlays() (lich_events.dm), shared with the other
 *   hazard rites, and the argument for it is written up there.
 */
/datum/round_event_control/voidcrew/lich/grave_dirt
	name = "Ritual: The Floor Is Grave-Dirt"
	typepath = /datum/round_event/voidcrew/lich/grave_dirt
	description = "The deck of the target ship becomes burning grave-dirt for about a minute."
	/**
	 * Effectively uncapped (20 is upstream's default ceiling), because this is the top of
	 * the ramp's workhorse. See the cap policy note in lich_events.dm.
	 *
	 * Safe to repeat: it is ship-scoped, it self-terminates after about a minute, the only
	 * lasting cost is burn damage that heals with ordinary medical care, and the counterplay
	 * (stand on something) never stops working.
	 */
	max_occurrences = 20
	event_scope = EVENT_SCOPE_SHIP
	min_wizard_trigger_potency = 5
	max_wizard_trigger_potency = 7

/datum/round_event/voidcrew/lich/grave_dirt
	/// Telegraph fires almost immediately.
	announce_when = 1
	/// Roughly fifteen seconds of warning before the deck turns, matching the weather datum's telegraph_duration.
	start_when = 8
	/// About a minute of burning after that.
	end_when = 38
	/// Fire damage per application. The weather datum's figure.
	var/burn_per_tick = 3

/datum/round_event/voidcrew/lich/grave_dirt/announce(fake)
	if(!target_valid())
		return
	lich_announce_ship(
		"There is soil under your deck plating. There is soil under everybody's deck plating; you \
		have just been walking on the lid. I am lifting the lid now. \
		Get your feet off my ground.",
		"The Floor Is Grave-Dirt",
		'sound/effects/magic/curse.ogg',
	)
	for(var/mob/living/warned as anything in target_ship.get_all_mobs_aboard())
		to_chat(warned, span_warning("The deck under you softens and starts to steam. The air above it wavers with heat."))

/datum/round_event/voidcrew/lich/grave_dirt/start()
	if(!target_valid())
		kill()
		return
	build_rite_overlays("lava", COLOR_VIBRANT_LIME, overlay_layer = ABOVE_OPEN_TURF_LAYER, overlay_plane = FLOOR_PLANE)
	refresh_rite_overlays()
	for(var/mob/living/victim as anything in target_ship.get_all_mobs_aboard())
		to_chat(victim, span_userdanger("The floor is grave-dirt! Get on top of something!"))

/datum/round_event/voidcrew/lich/grave_dirt/tick()
	if(!target_valid())
		return
	refresh_rite_overlays()
	for(var/mob/living/victim as anything in target_ship.get_all_mobs_aboard())
		if(QDELETED(victim) || !can_burn(victim))
			continue
		victim.adjustFireLoss(burn_per_tick)

/datum/round_event/voidcrew/lich/grave_dirt/end()
	// Runs whether or not the ship survived. The overlays are tracked against the areas.
	remove_rite_overlays()
	if(!target_valid())
		return
	for(var/mob/living/victim as anything in target_ship.get_all_mobs_aboard())
		to_chat(victim, span_danger("The ground cools and hardens back into deck plating."))

/**
 * Whether this mob is standing on burning ground right now.
 * Mirrors /datum/weather/floor_is_lava/can_weather_act_mob() plus the base class's
 * recursive protection check, minus everything z-shaped.
 */
/datum/round_event/voidcrew/lich/grave_dirt/proc/can_burn(mob/living/victim)
	if(issilicon(victim))
		return FALSE
	if(istype(victim.buckled, /obj/structure/bed))
		return FALSE
	if(victim.movement_type & MOVETYPES_NOT_TOUCHING_GROUND)
		return FALSE
	if(HAS_TRAIT(victim, TRAIT_WEATHER_IMMUNE) || HAS_TRAIT(victim, TRAIT_LAVA_IMMUNE))
		return FALSE
	// Anything holding the mob (a locker, a mech, an enviro bag) protects it, as the
	// weather base class's recursive check does.
	var/atom/holder = victim.loc
	if(!isturf(holder))
		return FALSE
	var/turf/victim_turf = holder
	if(!target_ship.is_aboard(victim_turf))
		return FALSE // Never trust position: they may have stepped off the ship this tick.
	if(victim_turf.density)
		return FALSE // Walls are not floors.
	for(var/obj/structure/blocker in victim_turf)
		if(blocker.density)
			return FALSE // They got on top of something. That is the counterplay.
	return TRUE
