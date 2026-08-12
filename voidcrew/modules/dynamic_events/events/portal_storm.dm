/**
 * Ship-scoped port of TG's Portal Storm (code/modules/events/portal_storm.dm).
 *
 * Two or three short boarding pulses resolve fresh open floor turfs from the
 * target ship. The total number of mobs is fixed from the crew aboard when the
 * assault starts, and a boss consumes one of those slots only for larger crews.
 */
/datum/round_event_control/voidcrew/portal_storm_syndicate
	name = "Portal Storm: Syndicate Shocktroops"
	typepath = /datum/round_event/voidcrew/portal_storm/syndicate_shocktroop
	weight = 1
	max_occurrences = 2
	min_players = 2
	earliest_start = 30 MINUTES
	category = EVENT_CATEGORY_ENTITIES
	description = "Syndicate troops pour out of portals aboard the target ship."
	event_scope = EVENT_SCOPE_SHIP
	min_crew_aboard = 3
	allowed_zones = list(ZONE_RED)
	requires_flying = TRUE
	/// Boarders are only a fight if there is somewhere to fight them. A Pill-class can hold
	/// the three crew this event asks for and still have nowhere for them to stand.
	min_ship_mass = SHIP_MASS_MEDIUM

/// Requires at least one open floor aboard where a boarding portal can form.
/datum/round_event_control/voidcrew/portal_storm_syndicate/is_valid_target(obj/structure/overmap/ship/ship)
	. = ..()
	if(!.)
		return FALSE
	return !isnull(ship.get_random_open_ship_turf())

/**
 * Station-independent construct variant retained from TG. Its zero weight keeps
 * it out of natural dynamic-event rolls while leaving it available to explicit
 * triggers that select this control.
 */
/datum/round_event_control/voidcrew/portal_storm_narsie
	name = "Portal Storm: Constructs"
	typepath = /datum/round_event/voidcrew/portal_storm/narsie
	weight = 0
	max_occurrences = 2
	min_players = 2
	earliest_start = 30 MINUTES
	category = EVENT_CATEGORY_ENTITIES
	description = "Nar'sie constructs pour out of portals aboard the target ship."
	min_wizard_trigger_potency = 5
	max_wizard_trigger_potency = 7
	event_scope = EVENT_SCOPE_SHIP
	min_crew_aboard = 3
	allowed_zones = list(ZONE_RED)
	requires_flying = TRUE
	min_ship_mass = SHIP_MASS_MEDIUM

/// Applies the same open-floor eligibility requirement as the syndicate storm.
/datum/round_event_control/voidcrew/portal_storm_narsie/is_valid_target(obj/structure/overmap/ship/ship)
	. = ..()
	if(!.)
		return FALSE
	return !isnull(ship.get_random_open_ship_turf())

/// Runs a capped sequence of boarding pulses entirely aboard one moving ship.
/datum/round_event/voidcrew/portal_storm
	announce_when = 1
	start_when = 7
	end_when = 16
	/// Weighted hostile mob types supplied by the concrete variant.
	var/list/hostile_types = list()
	/// Weighted boss mob types supplied by the concrete variant.
	var/list/boss_types = list()
	/// Portal visuals indexed by plane offset plus one.
	var/list/mutable_appearance/storm_appearances = list()
	/// Maximum number of mobs this event may create.
	var/mob_cap = 0
	/// Number of mobs successfully created so far.
	var/spawned_mobs = 0
	/// Spawn attempts left; a missing open turf consumes its attempt safely.
	var/spawn_slots_remaining = 0
	/// Pulses still to process.
	var/pulses_remaining = 0
	/// Event tick on which the next pulse fires.
	var/next_pulse = 0
	/// Whether the final pulse may spend one spawn slot on a boss.
	var/boss_pending = FALSE

/// Builds plane-correct portal appearances without resolving or retaining turfs.
/datum/round_event/voidcrew/portal_storm/setup()
	if(!target_valid())
		kill()
		return

	storm_appearances = list()
	for(var/offset in 0 to SSmapping.max_plane_offset)
		var/mutable_appearance/storm = mutable_appearance('icons/obj/machines/engine/energy_ball.dmi', "energy_ball_fast", FLY_LAYER)
		SET_PLANE_W_SCALAR(storm, ABOVE_GAME_PLANE, offset)
		storm.color = COLOR_VIBRANT_LIME
		storm_appearances += storm

/// Snapshots the crew-scaled mob cap and schedules two or three boarding pulses.
/datum/round_event/voidcrew/portal_storm/start()
	if(!target_valid())
		return
	if(target_ship.state != OVERMAP_SHIP_FLYING || target_ship.docked)
		kill()
		return

	var/crew_aboard = length(target_ship.get_event_crew())
	mob_cap = crew_aboard + 2
	spawn_slots_remaining = mob_cap
	pulses_remaining = rand(2, 3)
	next_pulse = activeFor + 1
	boss_pending = crew_aboard >= 5 && length(boss_types)

/// Warns only the target ship's crew of the inbound boarding action.
/datum/round_event/voidcrew/portal_storm/announce(fake)
	if(!target_valid())
		return
	target_ship.ship_event_announce(
		"Massive bluespace anomaly on intercept course, brace for boarders.",
		"Bluespace Anomaly Alert",
		'sound/effects/magic/lightning_chargeup.ogg',
	)

/// Fires each pulse from newly resolved ship turfs and stops if the ship docks.
/datum/round_event/voidcrew/portal_storm/tick()
	if(!target_valid())
		return
	if(target_ship.state != OVERMAP_SHIP_FLYING || target_ship.docked)
		end_when = activeFor
		return
	if(!pulses_remaining || activeFor < next_pulse)
		return

	spawn_pulse()
	pulses_remaining--
	if(!pulses_remaining || !spawn_slots_remaining)
		end_when = activeFor
		return
	next_pulse += 2

/// Releases event-local appearances once the final pulse has completed.
/datum/round_event/voidcrew/portal_storm/end()
	if(!target_valid())
		return
	storm_appearances = null

/**
 * Spends this pulse's share of the remaining mob slots. Every attempt asks the
 * target ship for a current open turf, so movement between z-levels cannot leave
 * a stale spawn location behind.
 */
/datum/round_event/voidcrew/portal_storm/proc/spawn_pulse()
	if(!target_valid() || !pulses_remaining || !spawn_slots_remaining)
		return

	var/pulse_size = CEILING(spawn_slots_remaining / pulses_remaining, 1)
	for(var/i in 1 to pulse_size)
		if(!spawn_slots_remaining || spawned_mobs >= mob_cap)
			break
		spawn_slots_remaining--

		var/mob_type
		if(boss_pending && pulses_remaining == 1)
			boss_pending = FALSE
			if(length(target_ship.get_event_crew()) >= 5)
				mob_type = pick_weight(boss_types)
		else
			mob_type = pick_weight(hostile_types)
		if(!mob_type)
			continue

		var/turf/open/floor/spawn_turf = target_ship.get_random_open_ship_turf()
		if(!spawn_turf || !target_ship.is_aboard(spawn_turf))
			continue
		var/mob/living/new_hostile = new mob_type(spawn_turf)
		if(QDELETED(new_hostile))
			continue
		spawned_mobs++
		spawn_effects(spawn_turf)

/// Plays TG's portal flash and sound without allowing the shifted visual off-ship.
/datum/round_event/voidcrew/portal_storm/proc/spawn_effects(turf/spawn_turf)
	if(!target_valid() || !spawn_turf || !target_ship.is_aboard(spawn_turf))
		return

	var/turf/effect_turf = get_step(spawn_turf, SOUTHWEST)
	if(!target_ship.is_aboard(effect_turf))
		effect_turf = spawn_turf
	var/appearance_index = GET_TURF_PLANE_OFFSET(effect_turf) + 1
	if(appearance_index <= length(storm_appearances))
		effect_turf.flick_overlay_static(storm_appearances[appearance_index], 15)
	playsound(effect_turf, 'sound/effects/magic/lightningbolt.ogg', rand(80, 100), TRUE)

/// Syndicate commandos, with a stormtrooper occupying the optional boss slot.
/datum/round_event/voidcrew/portal_storm/syndicate_shocktroop
	boss_types = list(/mob/living/basic/trooper/syndicate/melee/space/stormtrooper = 2)
	hostile_types = list(
		/mob/living/basic/trooper/syndicate/melee/space = 8,
		/mob/living/basic/trooper/syndicate/ranged/space = 2,
	)

/// Hostile cult constructs using the same pulse and population limits.
/datum/round_event/voidcrew/portal_storm/narsie
	boss_types = list(/mob/living/basic/construct/artificer/hostile = 6)
	hostile_types = list(
		/mob/living/basic/construct/juggernaut/hostile = 8,
		/mob/living/basic/construct/wraith/hostile = 6,
	)
