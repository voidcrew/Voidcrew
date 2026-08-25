/**
 * Ship-scoped port of TG's Ventilation Clog event
 * (code/modules/events/vent_clog.dm).
 *
 * A single eligible vent aboard the target ship produces pests and cleanable
 * filth until the event expires or a crewmember clears it with a plunger.
 */
/datum/round_event_control/voidcrew/vent_clog
	name = "Ventilation Clog: Minor"
	typepath = /datum/round_event/voidcrew/vent_clog
	weight = 25
	max_occurrences = 20
	earliest_start = 5 MINUTES
	category = EVENT_CATEGORY_JANITORIAL
	description = "Harmless mobs climb out of a vent aboard the target ship."
	event_scope = EVENT_SCOPE_SHIP

/// Only ships with an unwelded, unobstructed air vent may be selected.
/datum/round_event_control/voidcrew/vent_clog/is_valid_target(obj/structure/overmap/ship/ship)
	. = ..()
	if(!.)
		return FALSE
	return length(get_eligible_vents(ship)) > 0

/// Returns all unwelded vents on passable turfs aboard the supplied ship.
/datum/round_event_control/voidcrew/vent_clog/proc/get_eligible_vents(obj/structure/overmap/ship/ship)
	var/list/eligible_vents = list()
	if(QDELETED(ship) || !ship.shuttle)
		return eligible_vents

	var/list/ship_vents = ship.get_ship_machines(/obj/machinery/atmospherics/components/unary/vent_pump)
	for(var/obj/machinery/atmospherics/components/unary/vent_pump/candidate as anything in ship_vents)
		if(QDELETED(candidate) || candidate.welded || !ship.is_aboard(candidate))
			continue
		var/turf/vent_turf = get_turf(candidate)
		if(!vent_turf || vent_turf.is_blocked_turf_ignore_climbable())
			continue
		eligible_vents += candidate
	return eligible_vents

/// A more dangerous clog, kept out of the safe outer ring and scaled down for ships.
/datum/round_event_control/voidcrew/vent_clog/major
	name = "Ventilation Clog: Major"
	typepath = /datum/round_event/voidcrew/vent_clog/major
	weight = 5
	max_occurrences = 5
	earliest_start = 10 MINUTES
	description = "Dangerous pests climb out of a vent aboard the target ship."
	allowed_zones = list(ZONE_YELLOW, ZONE_RED)
	/// Hostile pests on a hull with one room are hostile pests in that room, with the crew.
	min_ship_mass = SHIP_MASS_SMALL

/**
 * Produces one selected mob type from one vent, tracking living products so a
 * small crew is never overwhelmed by concurrent event spawns.
 */
/datum/round_event/voidcrew/vent_clog
	announce_when = 10
	announce_chance = 90
	end_when = 600
	fakeable = FALSE

	/// Vent selected for this event.
	var/obj/machinery/atmospherics/components/unary/vent_pump/vent
	/// Mob type produced by the selected vent.
	var/mob/living/spawned_mob = /mob/living/basic/cockroach
	/// Variant-specific ceiling, further capped against current ship crew when spawning.
	var/maximum_spawns = 3
	/// Interval between attempted mob spawns.
	var/spawn_delay = 10
	/// Weak references to living mobs produced by this event.
	var/list/living_mobs = list()
	/// Cleanable decals produced alongside mobs.
	var/list/filth_spawn_types = list()
	/// Whether this datum currently has signals registered on vent.
	var/signals_registered = FALSE

/datum/round_event/voidcrew/vent_clog/setup()
	if(!target_valid())
		finish_event()
		return

	vent = get_vent()
	if(QDELETED(vent) || !target_ship.is_aboard(vent))
		finish_event()
		return

	spawned_mob = get_mob()
	end_when = rand(300, 600)
	maximum_spawns = min(rand(3, 10), length(target_ship.get_event_crew()) + 1)
	spawn_delay = rand(10, 15)
	filth_spawn_types = list(
		/obj/effect/decal/cleanable/vomit,
		/obj/effect/decal/cleanable/insectguts,
		/obj/effect/decal/cleanable/blood/oil,
	)

/datum/round_event/voidcrew/vent_clog/start()
	if(!target_valid())
		finish_event()
		return
	if(QDELETED(vent) || !target_ship.is_aboard(vent))
		finish_event()
		return
	if(!clog_vent())
		finish_event()

/datum/round_event/voidcrew/vent_clog/announce(fake)
	if(!target_valid())
		finish_event()
		return
	if(QDELETED(vent) || !target_ship.is_aboard(vent))
		finish_event()
		return

	var/area/event_area = get_area(vent)
	if(!event_area)
		finish_event()
		return
	target_ship.ship_event_announce(
		"Minor biological obstruction detected in the vessel's ventilation network. The blockage is believed to be in [event_area.name].",
		"Custodial Notification",
	)

/datum/round_event/voidcrew/vent_clog/tick()
	if(!target_valid())
		finish_event()
		return
	if(QDELETED(vent) || !target_ship.is_aboard(vent))
		finish_event()
		return
	if(spawn_delay <= 0 || activeFor % spawn_delay != 0)
		return

	life_check()
	var/crew_scaled_cap = length(target_ship.get_event_crew()) + 1
	if(length(living_mobs) < min(maximum_spawns, crew_scaled_cap))
		produce_mob()

// No end announcement. A welded vent stays quiet until the crew chooses to reopen it.
/datum/round_event/voidcrew/vent_clog/end()
	if(!target_valid())
		finish_event()
		return
	finish_event()

/**
 * Selects the harmless pest produced by a minor clog.
 *
 * The original minor spawn table is preserved.
 */
/datum/round_event/voidcrew/vent_clog/proc/get_mob()
	var/static/list/mob_list = list(
		/mob/living/basic/butterfly,
		/mob/living/basic/cockroach,
		/mob/living/basic/cockroach/bloodroach,
		/mob/living/basic/spider/maintenance,
		/mob/living/basic/mouse,
		/mob/living/basic/snail,
	)
	return pick(mob_list)

/// Picks an eligible vent belonging to target_ship, or null if the candidate vanished.
/datum/round_event/voidcrew/vent_clog/proc/get_vent()
	if(!target_valid())
		return null
	var/datum/round_event_control/voidcrew/vent_clog/vent_control = control
	if(!istype(vent_control))
		return null
	var/list/eligible_vents = vent_control.get_eligible_vents(target_ship)
	return length(eligible_vents) ? pick(eligible_vents) : null

/// Removes dead or deleted products from the concurrent spawn count.
/datum/round_event/voidcrew/vent_clog/proc/life_check()
	for(var/datum/weakref/mob_ref as anything in living_mobs)
		var/mob/living/real_mob = mob_ref.resolve()
		if(QDELETED(real_mob) || real_mob.stat == DEAD)
			living_mobs -= mob_ref

/**
 * Produces a mob and accompanying filth from the selected vent.
 *
 * Welding and turf obstruction are intentionally checked here rather than
 * reimplemented; those states remain owned by the vent and turf machinery.
 */
/datum/round_event/voidcrew/vent_clog/proc/produce_mob()
	if(!target_valid())
		finish_event()
		return
	if(QDELETED(vent) || !target_ship.is_aboard(vent))
		finish_event()
		return

	var/turf/vent_loc = get_turf(vent)
	if(!vent_loc)
		finish_event()
		return
	if(vent.welded || vent_loc.is_blocked_turf_ignore_climbable())
		return
	if(!ispath(spawned_mob, /mob/living))
		finish_event()
		return

	var/crew_scaled_cap = length(target_ship.get_event_crew()) + 1
	if(length(living_mobs) >= min(maximum_spawns, crew_scaled_cap))
		return

	var/mob/living/new_mob = new spawned_mob(vent_loc)
	living_mobs += WEAKREF(new_mob)
	vent.visible_message(span_warning("[new_mob] crawls out of [vent]!"))

	var/list/potential_locations = list(vent_loc)
	for(var/turf/nearby_turf in oview(1, vent_loc))
		if(target_ship.is_aboard(nearby_turf) && !nearby_turf.is_blocked_turf(source_atom = new_mob))
			potential_locations += nearby_turf

	var/turf/spawn_location = pick(potential_locations)
	new_mob.Move(spawn_location)
	if(length(filth_spawn_types))
		var/filth_to_spawn = pick(filth_spawn_types)
		if(ispath(filth_to_spawn, /obj/effect/decal/cleanable))
			new filth_to_spawn(spawn_location)
	playsound(spawn_location, 'sound/effects/splat.ogg', 30, TRUE)

/// Signal catcher for plunger_act() while this vent is clogged.
/datum/round_event/voidcrew/vent_clog/proc/plunger_unclog(datum/source, obj/item/plunger/attacking_plunger, mob/user, reinforced)
	SIGNAL_HANDLER
	if(!target_valid() || source != vent || QDELETED(vent) || !target_ship.is_aboard(vent))
		finish_event()
		return COMPONENT_NO_AFTERATTACK
	INVOKE_ASYNC(src, PROC_REF(attempt_unclog), user)
	return COMPONENT_NO_AFTERATTACK

/// Performs the timed plunger cure and stops further production on success.
/datum/round_event/voidcrew/vent_clog/proc/attempt_unclog(mob/user)
	if(!target_valid())
		finish_event()
		return
	if(QDELETED(user) || QDELETED(vent) || !target_ship.is_aboard(vent))
		finish_event()
		return
	if(vent.welded)
		to_chat(user, span_notice("You cannot pump [vent] if it's welded shut!"))
		return

	user.balloon_alert_to_viewers("plunging vent...", "plunging clogged vent...")
	if(!do_after(user, 6 SECONDS, target = vent))
		return
	if(!target_valid())
		finish_event()
		return
	if(QDELETED(vent) || !target_ship.is_aboard(vent))
		finish_event()
		return
	if(vent.welded)
		to_chat(user, span_notice("You cannot finish pumping [vent] while it's welded shut!"))
		return

	user.balloon_alert_to_viewers("finished plunging")
	finish_event()

/// Registers the clog's cure/deletion signals, dirties the area, and produces its first mob.
/datum/round_event/voidcrew/vent_clog/proc/clog_vent()
	if(!target_valid() || QDELETED(vent) || !target_ship.is_aboard(vent))
		return FALSE
	var/turf/vent_turf = get_turf(vent)
	if(!vent_turf)
		return FALSE

	RegisterSignal(vent, COMSIG_QDELETING, PROC_REF(vent_deleted))
	RegisterSignal(vent, COMSIG_PLUNGER_ACT, PROC_REF(plunger_unclog))
	signals_registered = TRUE

	for(var/turf/nearby_turf in view(2, vent_turf))
		if(!target_ship.is_aboard(nearby_turf))
			continue
		if(isopenturf(nearby_turf) && prob(85))
			new /obj/effect/decal/cleanable/dirt(nearby_turf)

	produce_mob()
	return TRUE

/// Ends the event immediately if its selected vent is deleted; no replacement can escape ship scope.
/datum/round_event/voidcrew/vent_clog/proc/vent_deleted(datum/source)
	SIGNAL_HANDLER
	if(source != vent)
		return
	signals_registered = FALSE
	vent = null
	finish_event()

/// Clears signals registered by this event without touching machinery-owned vent state.
/datum/round_event/voidcrew/vent_clog/proc/clear_signals()
	if(signals_registered && !QDELETED(vent))
		UnregisterSignal(vent, list(COMSIG_QDELETING, COMSIG_PLUNGER_ACT))
	signals_registered = FALSE

/// Releases event tracking and stops processing; spawned mobs and filth remain normally.
/datum/round_event/voidcrew/vent_clog/proc/finish_event()
	clear_signals()
	vent = null
	if(living_mobs)
		living_mobs.Cut()
	kill()

/datum/round_event/voidcrew/vent_clog/major/setup()
	. = ..()
	if(!target_valid() || QDELETED(vent) || !target_ship.is_aboard(vent))
		return
	maximum_spawns = min(rand(1, 3), length(target_ship.get_event_crew()) + 1)
	spawn_delay = rand(15, 20)
	filth_spawn_types = list(
		/obj/effect/decal/cleanable/blood,
		/obj/effect/decal/cleanable/insectguts,
		/obj/effect/decal/cleanable/fuel_pool,
		/obj/effect/decal/cleanable/blood/oil,
	)

/// Selects the original major clog's moderate-danger pest table.
/datum/round_event/voidcrew/vent_clog/major/get_mob()
	var/static/list/mob_list = list(
		/mob/living/basic/bee,
		/mob/living/basic/cockroach/hauberoach,
		/mob/living/basic/spider/giant,
		/mob/living/basic/mouse/rat,
	)
	return pick(mob_list)

/datum/round_event/voidcrew/vent_clog/major/announce(fake)
	if(!target_valid())
		finish_event()
		return
	if(QDELETED(vent) || !target_ship.is_aboard(vent))
		finish_event()
		return

	var/area/event_area = get_area(vent)
	if(!event_area)
		finish_event()
		return
	target_ship.ship_event_announce(
		"Major biological obstruction detected aboard the vessel. The infestation is believed to be emerging from ventilation in [event_area.name].",
		"Infestation Alert",
	)

/**
 * Genuinely dangerous pests: toxin bees, carp, glockroaches. Deep bands only, and it
 * wants a hull big enough that "back out of the compartment and weld the vent" is a
 * plan rather than a description of the whole ship.
 */
/datum/round_event_control/voidcrew/vent_clog/critical
	name = "Ventilation Clog: Critical"
	typepath = /datum/round_event/voidcrew/vent_clog/critical
	weight = 3
	max_occurrences = 3
	earliest_start = 25 MINUTES
	description = "Really dangerous pests climb out of a vent aboard the target ship."
	allowed_zones = list(ZONE_YELLOW, ZONE_RED)
	min_crew_aboard = 2
	min_ship_mass = SHIP_MASS_MEDIUM
	min_wizard_trigger_potency = 3
	max_wizard_trigger_potency = 6

/datum/round_event/voidcrew/vent_clog/critical/setup()
	. = ..()
	if(!target_valid() || QDELETED(vent) || !target_ship.is_aboard(vent))
		return
	spawn_delay = rand(15, 25)
	maximum_spawns = min(rand(1, 3), length(target_ship.get_event_crew()) + 1)
	filth_spawn_types = list(
		/obj/effect/decal/cleanable/blood,
		/obj/effect/decal/cleanable/blood/splatter,
	)

/datum/round_event/voidcrew/vent_clog/critical/get_mob()
	var/static/list/mob_list = list(
		/mob/living/basic/bee/toxin,
		/mob/living/basic/carp,
		/mob/living/basic/cockroach/glockroach,
	)
	return pick(mob_list)

/datum/round_event/voidcrew/vent_clog/critical/announce(fake)
	if(!target_valid())
		finish_event()
		return
	if(QDELETED(vent) || !target_ship.is_aboard(vent))
		finish_event()
		return

	var/area/event_area = get_area(vent)
	if(!event_area)
		finish_event()
		return
	target_ship.ship_event_announce(
		"Hazardous lifesigns in the ventilation network around [event_area.name]. Arm yourselves before opening that compartment.",
		"Security Alert",
	)

/**
 * The grab bag. Anything from a lightgeist to a bear, so the crew have no idea what they
 * are dealing with until it is already out of the vent, which is the entire joke.
 *
 * It keeps its lack of a size gate, because most of this table is harmless and the
 * surprise is the point: it is the one clog that can still catch out a crew who have
 * learned what the other three mean.
 *
 * It does NOT keep its lack of a zone gate. Two entries in the table are a bear and a
 * viscerator, and "surprise, fight a bear" is a fine joke on a crew who have a weapon
 * locker and know where it is. In the green band it lands on people who are still working
 * out the airlocks, and the outer ring is supposed to be the one place nothing hurts them.
 */
/datum/round_event_control/voidcrew/vent_clog/strange
	name = "Ventilation Clog: Strange"
	typepath = /datum/round_event/voidcrew/vent_clog/strange
	weight = 3
	max_occurrences = 2
	earliest_start = 15 MINUTES
	description = "Strange creatures climb out of a vent aboard the target ship. Harmfulness varies."
	allowed_zones = list(ZONE_YELLOW, ZONE_RED)
	min_ship_mass = SHIP_MASS_SMALL
	min_wizard_trigger_potency = 0
	max_wizard_trigger_potency = 7

/datum/round_event/voidcrew/vent_clog/strange/setup()
	. = ..()
	if(!target_valid() || QDELETED(vent) || !target_ship.is_aboard(vent))
		return
	end_when = rand(600, 900)
	spawn_delay = rand(6, 25)
	// TG allows up to 10. A ship gets the crew-scaled cap the base port already applies.
	maximum_spawns = min(rand(2, 5), length(target_ship.get_event_crew()) + 1)
	filth_spawn_types = list(
		/obj/effect/decal/cleanable/blood/xeno,
		/obj/effect/decal/cleanable/fuel_pool,
		/obj/effect/decal/cleanable/greenglow,
		/obj/effect/decal/cleanable/vomit,
	)

/datum/round_event/voidcrew/vent_clog/strange/get_mob()
	var/static/list/mob_list = list(
		/mob/living/basic/bear,
		/mob/living/basic/cockroach/glockroach/mobroach,
		/mob/living/basic/goose,
		/mob/living/basic/lightgeist,
		/mob/living/basic/mothroach,
		/mob/living/basic/mushroom,
		/mob/living/basic/viscerator,
		/mob/living/basic/pet/gondola,
	)
	return pick(mob_list)

/datum/round_event/voidcrew/vent_clog/strange/announce(fake)
	if(!target_valid())
		finish_event()
		return
	if(QDELETED(vent) || !target_ship.is_aboard(vent))
		finish_event()
		return

	var/area/event_area = get_area(vent)
	if(!event_area)
		finish_event()
		return
	target_ship.ship_event_announce(
		"Unusual lifesign readings in the ventilation network around [event_area.name]. We have no match for the profile.",
		"Lifesign Alert",
		ANNOUNCER_ALIENS,
	)
