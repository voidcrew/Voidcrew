/**
 * Ship-scoped port of TG's Grey Tide (code/modules/events/grey_tide.dm).
 *
 * The Gr3y.T1d3 virus bolts open airlocks across part of the target ship. TG
 * picks victim areas by station department typepath (/area/station/...) and
 * reaches them through global signals; ships have no department types and share
 * z-levels with bystanders, so this port picks 1-2 of the ship's own shuttle
 * areas (only ones that actually contain airlocks) and calls prison_open(),
 * the same proc TG's airlock signal handler invokes, directly on each airlock
 * in them. All effects stay inside target_ship's shuttle areas.
 */
/datum/round_event_control/voidcrew/grey_tide
	name = "Ship Grey Tide"
	typepath = /datum/round_event/voidcrew/grey_tide
	weight = 4
	max_occurrences = 2
	min_players = 2
	category = EVENT_CATEGORY_ENGINEERING
	description = "Bolts open all airlocks in one or two of the target ship's areas."
	allowed_zones = list(ZONE_YELLOW, ZONE_RED)
	min_wizard_trigger_potency = 0
	max_wizard_trigger_potency = 7

/datum/round_event_control/voidcrew/grey_tide/is_valid_target(obj/structure/overmap/ship/ship)
	. = ..()
	if(!.)
		return FALSE
	// Pointless on a ship with no airlocks to pry open
	return length(ship.get_ship_machines(/obj/machinery/door/airlock)) > 0

/datum/round_event/voidcrew/grey_tide
	announce_when = 50
	end_when = 20
	fakeable = FALSE
	/// The number of areas to be hit by the event: 1 (light) or 2 (severe).
	var/severity = 1
	/// The ship areas hit by the event, area instances, not typepaths like TG.
	var/list/area/grey_tide_areas = list()

/datum/round_event/voidcrew/grey_tide/setup()
	announce_when = rand(50, 60)
	end_when = rand(20, 30)
	if(!target_valid())
		return
	// TG's department typepaths guarantee doors; a random ship room may not, so
	// only offer up areas that actually have an airlock in them.
	var/list/area/candidate_areas = list()
	for(var/obj/machinery/door/airlock/airlock as anything in target_ship.get_ship_machines(/obj/machinery/door/airlock))
		var/area/airlock_area = get_area(airlock)
		if(airlock_area && !(airlock_area in candidate_areas))
			candidate_areas += airlock_area
	severity = min(rand(1, 2), length(candidate_areas))
	for(var/i in 1 to severity)
		grey_tide_areas += pick_n_take(candidate_areas)

/datum/round_event/voidcrew/grey_tide/announce(fake)
	if(!target_valid())
		return
	target_ship.ship_event_announce("Gr3y.T1d3 virus detected in [target_ship.display_name || target_ship.name] airlock control subroutines. Severity level of [severity]. All hands: inspect and re-secure affected airlocks.", "Security Alert")

/datum/round_event/voidcrew/grey_tide/start()
	if(!target_valid())
		return
	if(!length(grey_tide_areas))
		kill() // Nothing aboard worth hitting, fizzle quietly.

/**
 * Mirrors TG's periodic COMSIG_GLOB_GREY_TIDE_LIGHT pulse (which only lights
 * register for): lights in the victim areas flicker while the virus runs, a
 * tell before the doors let go at end(). flicker() is already non-blocking.
 */
/datum/round_event/voidcrew/grey_tide/tick()
	if(!target_valid())
		return
	if(!ISMULTIPLE(activeFor, 12))
		return
	for(var/obj/machinery/light/ship_light as anything in target_ship.get_ship_machines(/obj/machinery/light))
		if(QDELETED(ship_light) || !(get_area(ship_light) in grey_tide_areas))
			continue
		ship_light.flicker()

/**
 * Mirrors TG's COMSIG_GLOB_GREY_TIDE, per handler: airlocks (skipping
 * critical_machine ones) get prison_open(), secure lockers unlock, and APCs cut
 * their lighting channel, all scoped to the victim areas aboard the ship.
 */
/datum/round_event/voidcrew/grey_tide/end()
	if(!target_valid())
		return
	for(var/obj/machinery/door/airlock/airlock as anything in target_ship.get_ship_machines(/obj/machinery/door/airlock))
		if(QDELETED(airlock) || airlock.critical_machine)
			continue
		if(!(get_area(airlock) in grey_tide_areas))
			continue
		INVOKE_ASYNC(airlock, TYPE_PROC_REF(/obj/machinery/door/airlock, prison_open)) // open() sleeps, same reason TG's handler invokes async
	for(var/area/victim_area as anything in grey_tide_areas)
		for(var/obj/structure/closet/secure_closet/locker in victim_area)
			locker.locked = FALSE
			locker.update_appearance(UPDATE_ICON)
	for(var/obj/machinery/power/apc/breached_apc as anything in target_ship.get_ship_machines(/obj/machinery/power/apc))
		if(QDELETED(breached_apc) || !(get_area(breached_apc) in grey_tide_areas))
			continue
		breached_apc.lighting = APC_CHANNEL_OFF // escape (or sneak in) under the cover of darkness
		breached_apc.update_appearance(UPDATE_ICON)
		breached_apc.update()
