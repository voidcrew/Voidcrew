/**
 * Ship-scoped port of TG's Wormholes (code/modules/events/wormholes.dm).
 *
 * Wormholes spawn and shift only across the target ship's open floor turfs.
 * Their teleport pool is event-local so simultaneous events on ships sharing a
 * transit z-level can never send crew or objects between vessels.
 */
/datum/round_event_control/voidcrew/wormholes
	name = "Wormholes"
	typepath = /datum/round_event/voidcrew/wormholes
	max_occurrences = 3
	weight = 1
	min_players = 2
	category = EVENT_CATEGORY_SPACE
	description = "Space-time anomalies appear aboard the target ship, randomly teleporting anything that enters them."
	min_wizard_trigger_potency = 3
	max_wizard_trigger_potency = 7
	event_scope = EVENT_SCOPE_SHIP
	allowed_zones = list(ZONE_YELLOW, ZONE_RED)
	requires_flying = TRUE

/// Needs at least two open floor turfs aboard so the wormholes have somewhere to lead.
/datum/round_event_control/voidcrew/wormholes/is_valid_target(obj/structure/overmap/ship/ship)
	. = ..()
	if(!.)
		return FALSE
	var/floor_turfs = 0
	for(var/area/ship_area as anything in ship.shuttle.shuttle_areas)
		for(var/turf/ship_turf as anything in ship_area)
			if(!istype(ship_turf, /turf/open/floor))
				continue
			floor_turfs++
			if(floor_turfs >= 2)
				return TRUE
	return FALSE

/// Creates a small, shifting network of wormholes confined to one ship.
/datum/round_event/voidcrew/wormholes
	announce_when = 10
	end_when = 60
	/// Open floor turfs belonging to the target ship.
	var/list/turf/open/floor/pick_turfs = list()
	/// Wormholes created by this event; also serves as their private destination pool.
	var/list/obj/effect/portal/wormhole/voidcrew_event/wormholes = list()
	/// How often the wormholes move to new ship turfs.
	var/shift_frequency = 3

/datum/round_event/voidcrew/wormholes/setup()
	if(!target_valid())
		return
	announce_when = rand(0, 20)
	end_when = rand(40, 80)

/datum/round_event/voidcrew/wormholes/start()
	if(!target_valid())
		return

	pick_turfs = list()
	wormholes = list()
	for(var/area/ship_area as anything in target_ship.shuttle.shuttle_areas)
		for(var/turf/ship_turf as anything in ship_area)
			if(istype(ship_turf, /turf/open/floor))
				pick_turfs += ship_turf

	if(length(pick_turfs) < 2)
		kill()
		return

	var/number_of_wormholes = clamp(round(length(pick_turfs) / 40), 2, 6)
	for(var/i in 1 to number_of_wormholes)
		var/turf/open/floor/spawn_turf = pick(pick_turfs)
		if(!spawn_turf || !target_ship.is_aboard(spawn_turf))
			continue
		var/obj/effect/portal/wormhole/voidcrew_event/new_wormhole = new(spawn_turf, 0, null, FALSE)
		if(QDELETED(new_wormhole))
			continue
		new_wormhole.owning_event = src
		wormholes += new_wormhole
		playsound(spawn_turf, SFX_PORTAL_CREATED, 20, TRUE, SILENCED_SOUND_EXTRARANGE)

/datum/round_event/voidcrew/wormholes/announce(fake)
	if(!target_valid())
		return
	target_ship.ship_event_announce(
		"Space-time anomalies detected aboard the vessel. There is no additional data.",
		"Anomaly Alert",
		ANNOUNCER_SPANOMALIES,
	)

/datum/round_event/voidcrew/wormholes/tick()
	if(!target_valid())
		return
	if(!shift_frequency || activeFor % shift_frequency || !length(pick_turfs) || !length(wormholes))
		return

	for(var/obj/effect/portal/wormhole/voidcrew_event/wormhole as anything in wormholes)
		if(QDELETED(wormhole))
			continue
		var/turf/open/floor/destination = pick(pick_turfs)
		if(!destination || !target_ship.is_aboard(destination))
			continue
		wormhole.forceMove(destination)
		playsound(destination, SFX_PORTAL_CREATED, 20, TRUE, SILENCED_SOUND_EXTRARANGE)

// No target_valid() guard: the portals must be cleaned up even if the ship
// died mid-event, or they linger on the wreck forever.
/datum/round_event/voidcrew/wormholes/end()
	QDEL_LIST(wormholes)
	wormholes = null
	pick_turfs = null

/**
 * Picks an actual arrival turf within one tile of a random event wormhole.
 * Filtering the scatter radius back through the ship's floor list preserves
 * TG's imprecision without permitting arrivals in space or on a neighbor.
 */
/datum/round_event/voidcrew/wormholes/proc/get_ship_wormhole_destination()
	if(!target_valid() || !length(pick_turfs) || !length(wormholes))
		return

	var/list/obj/effect/portal/wormhole/voidcrew_event/valid_wormholes = list()
	for(var/obj/effect/portal/wormhole/voidcrew_event/wormhole as anything in wormholes)
		if(QDELETED(wormhole))
			continue
		var/turf/wormhole_turf = get_turf(wormhole)
		if(!(wormhole_turf in pick_turfs) || !target_ship.is_aboard(wormhole_turf))
			continue
		valid_wormholes += wormhole
	if(!length(valid_wormholes))
		return

	var/obj/effect/portal/wormhole/voidcrew_event/destination_wormhole = pick(valid_wormholes)
	var/turf/destination_center = get_turf(destination_wormhole)
	var/list/turf/open/floor/arrival_turfs = list()
	for(var/turf/candidate as anything in RANGE_TURFS(1, destination_center))
		if(!(candidate in pick_turfs) || !target_ship.is_aboard(candidate))
			continue
		arrival_turfs += candidate
	if(length(arrival_turfs))
		return pick(arrival_turfs)

/**
 * A TG wormhole with an event-local destination source. TG wormholes normally
 * choose from GLOB.all_wormholes, which is unsafe for ships on shared z-levels.
 */
/obj/effect/portal/wormhole/voidcrew_event
	/// Event instance providing this wormhole's ship-owned destination pool.
	var/datum/round_event/voidcrew/wormholes/owning_event

/// Removes this subtype from TG's global wormhole destination pool.
/obj/effect/portal/wormhole/voidcrew_event/Initialize(mapload, _creator, _lifespan = 0, obj/effect/portal/_linked, automatic_link = FALSE, turf/hard_target_override)
	. = ..()
	GLOB.all_wormholes -= src

/// Teleports movable atoms between aboard-only endpoints in this event's wormhole network.
/obj/effect/portal/wormhole/voidcrew_event/teleport(atom/movable/moving, force = FALSE)
	if(iseffect(moving))
		return
	if(moving.anchored)
		if(!(ismecha(moving) && mech_sized))
			return
	if(!ismovable(moving) || !owning_event || QDELETED(owning_event))
		return
	if(!owning_event.target_valid() || !owning_event.target_ship.is_aboard(moving))
		return

	hard_target = owning_event.get_ship_wormhole_destination()
	if(!hard_target)
		return
	var/turf/start_turf = get_turf(moving)
	if(!start_turf)
		return
	if(do_teleport(moving, hard_target, 0, null, null, channel = TELEPORT_CHANNEL_WORMHOLE))
		playsound(start_turf, SFX_PORTAL_ENTER, 50, TRUE, SHORT_RANGE_SOUND_EXTRARANGE)
		playsound(hard_target, SFX_PORTAL_ENTER, 50, TRUE, SHORT_RANGE_SOUND_EXTRARANGE)
