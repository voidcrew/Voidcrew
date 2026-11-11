/**
 * # Exploration Mission
 *
 * Fly the ship to marked coordinates, hold station there while the sensors sweep
 * the sector, then come home for the pay. The coordinates come from the zone
 * controller's own turf sets (no private ring math), and pay scales through the
 * shared zone table.
 *
 * The sweep is the arrival beat: half a minute on station, a sonar ping, and
 * sometimes a derelict signal nobody aboard had charted yet, pinned on the helm
 * so the crew can decide whether to go and look. The signal is always one that
 * is already out there; the sweep never makes anything.
 */
/datum/mission/exploration
	name = "Exploration Contract"
	weight = 10
	safe_work = TRUE
	// Green-band pay; apply_zone_scaling() raises it for deeper zones
	value_min = 150
	value_max = 250
	/// The sweep step, for the waypoint label
	var/datum/mission_objective/sector_sweep/sweep

/datum/mission/exploration/Destroy()
	sweep = null
	return ..()

/datum/mission/exploration/setup_target()
	var/datum/mission_target/coords/coords = new(src)
	// Weighted zone selection (more easy missions, fewer hard)
	coords.zone_weights = list(
		"[ZONE_GREEN]" = 50,
		"[ZONE_YELLOW]" = 35,
		"[ZONE_RED]" = 15,
	)
	if(!coords.resolve())
		qdel(coords)
		return FALSE
	target = coords
	return TRUE

/datum/mission/exploration/build_objectives()
	var/datum/mission_objective/goto_coords/approach = new
	// The sweep announces the arrival itself
	approach.arrival_message = null
	add_objective(approach)
	sweep = new
	add_objective(sweep)

/datum/mission/exploration/update_text()
	name = "Exploration Contract: ([target.target_x], [target.target_y])"
	desc = "Chart the sector at ([target.target_x], [target.target_y]) in the [target_zone_name]."

/datum/mission/exploration/waypoint_label()
	return sweep?.completed ? "Charted sector" : "Survey site"

/datum/mission/exploration/get_ui_data()
	var/list/data = ..()
	data["target_x"] = target.target_x
	data["target_y"] = target.target_y
	return data

// =========================================================================
// SECTOR SWEEP: hold station at the site while the sensors work
// =========================================================================

/**
 * The ship holds within hold_range of the mission target for sweep_time. Drifting
 * off pauses the sweep and keeps what it had; coming back resumes it. The possible
 * find (an uncharted ordinary derelict signal near the site) is rolled once, the
 * first time the sweep starts, so breaking off and coming back never rerolls it.
 */
/datum/mission_objective/sector_sweep
	/// How long the ship has to hold station
	var/sweep_time = 30 SECONDS
	/// Overmap tiles from the site the ship may sit and keep sweeping
	var/hold_range = 2
	/// How far from the site a derelict signal can show up on the sweep
	var/find_range = 7
	/// Percent chance the sweep turns up a derelict signal, when one is out there
	var/find_chance = 50
	/// Gap between "broken off" lines, so a ship drifting on the edge doesn't spam the crew
	var/notice_gap = 10 SECONDS
	/// Sweep time banked from earlier runs
	var/banked_time = 0
	/// Whether the ship is on station and the sweep is running
	var/running = FALSE
	/// world.time the current run started
	var/run_started = 0
	/// Whether the sweep has started at least once
	var/started = FALSE
	/// Timer: the sweep finishing
	var/finish_timer
	/// Timer: the faint return halfway through, when there is a find
	var/return_timer
	/// Whether the faint return has been called out
	var/return_reported = FALSE
	/// Whether a "broken off" line went out that still needs its "resumed"
	var/break_reported = FALSE
	/// Whether the find has been rolled for this sweep
	var/find_rolled = FALSE
	/// The derelict signal the sweep picked up, if any
	var/datum/weakref/find_ref
	COOLDOWN_DECLARE(break_notice_cooldown)

/datum/mission_objective/sector_sweep/Destroy()
	find_ref = null
	return ..()

/datum/mission_objective/sector_sweep/activate()
	. = ..()
	var/obj/structure/overmap/ship/ship = get_servant()
	if(!ship)
		return
	RegisterSignal(ship, COMSIG_MOVABLE_MOVED, PROC_REF(on_ship_moved))
	check_station()

/datum/mission_objective/sector_sweep/deactivate()
	var/obj/structure/overmap/ship/ship = get_servant()
	if(ship)
		UnregisterSignal(ship, COMSIG_MOVABLE_MOVED)
	stop_run()
	return ..()

/datum/mission_objective/sector_sweep/reset()
	. = ..()
	banked_time = 0
	running = FALSE
	run_started = 0
	started = FALSE
	return_reported = FALSE
	break_reported = FALSE
	find_rolled = FALSE
	find_ref = null

/datum/mission_objective/sector_sweep/proc/on_ship_moved(datum/source)
	SIGNAL_HANDLER
	check_station()

/// Wrapped overmap distance from relative coordinates to the mission site, or null
/datum/mission_objective/sector_sweep/proc/distance_to_site(list/coords)
	var/datum/mission_target/target = mission?.target
	if(!coords || !target)
		return null
	var/dx = overmap_wrapped_delta(coords[1] - target.target_x, OVERMAP_SIZE - 2)
	var/dy = overmap_wrapped_delta(coords[2] - target.target_y, OVERMAP_SIZE - 2)
	return sqrt(dx * dx + dy * dy)

/// Whether the servant ship is close enough to the site to sweep it
/datum/mission_objective/sector_sweep/proc/is_on_station()
	var/obj/structure/overmap/ship/ship = get_servant()
	if(!ship)
		return FALSE
	var/dist = distance_to_site(ship.get_relative_overmap_coords())
	return !isnull(dist) && dist <= hold_range

/// Starts or pauses the sweep to match where the ship is
/datum/mission_objective/sector_sweep/proc/check_station()
	if(completed || !active)
		return
	var/on_station = is_on_station()
	if(on_station && !running)
		start_run()
	else if(!on_station && running)
		stop_run()
		if(COOLDOWN_FINISHED(src, break_notice_cooldown))
			COOLDOWN_START(src, break_notice_cooldown, notice_gap)
			break_reported = TRUE
			notify_crew("Sweep broken off.", type = SHIP_NOTIFY_WARNING, sound = 'voidcrew/sound/notify2.ogg')

/datum/mission_objective/sector_sweep/proc/start_run()
	running = TRUE
	run_started = world.time
	if(!find_rolled)
		find_rolled = TRUE
		roll_find()
	finish_timer = addtimer(CALLBACK(src, PROC_REF(finish_sweep)), max(sweep_time - banked_time, 1), TIMER_STOPPABLE)
	var/halfway = sweep_time / 2
	if(find_ref && !return_reported && banked_time < halfway)
		return_timer = addtimer(CALLBACK(src, PROC_REF(report_return)), halfway - banked_time, TIMER_STOPPABLE)
	if(!started)
		started = TRUE
		notify_crew("Survey site reached. Sweeping the sector.", sound = 'sound/machines/sonar-ping.ogg')
	else if(break_reported)
		break_reported = FALSE
		notify_crew("Back on station. Sweep resumed.", sound = 'sound/machines/sonar-ping.ogg')

/// Banks the current run and stops its timers (safe to call while already stopped)
/datum/mission_objective/sector_sweep/proc/stop_run()
	if(running)
		banked_time += world.time - run_started
		running = FALSE
	if(finish_timer)
		deltimer(finish_timer)
		finish_timer = null
	if(return_timer)
		deltimer(return_timer)
		return_timer = null

/**
 * Picks what the sweep turns up: the nearest ordinary derelict signal just past the
 * ship's own sight from the site, that this ship has neither seen nor charted. Only
 * plain naturally seeded signals with nobody's claim on them count, so the sweep
 * never points at a rumour site, a contract's site, a bounty lair or a broadcast.
 */
/datum/mission_objective/sector_sweep/proc/roll_find()
	find_ref = null
	if(!prob(find_chance))
		return
	var/obj/structure/overmap/ship/ship = get_servant()
	var/turf/ship_turf = get_turf(ship)
	if(!ship_turf)
		return
	var/obj/structure/overmap/space_ruin/best
	var/best_dist
	for(var/obj/structure/overmap/space_ruin/ruin as anything in GLOB.space_ruin_signals)
		if(!is_ordinary_signal(ruin))
			continue
		var/turf/ruin_turf = get_turf(ruin)
		if(ruin_turf?.z != ship_turf.z)
			continue
		var/ruin_ref = REF(ruin)
		if(ship.get_waypoint(ruin_ref))
			continue
		var/datum/weakref/seen = ship.discovered_contacts[ruin_ref]
		if(seen?.resolve() == ruin)
			continue
		var/dist = distance_to_site(ruin.get_relative_overmap_coords())
		if(isnull(dist) || dist <= SHIP_VIEW_RANGE || dist > find_range)
			continue
		if(isnull(best_dist) || dist < best_dist)
			best = ruin
			best_dist = dist
	if(best)
		find_ref = WEAKREF(best)

/// A plain derelict signal from natural seeding, with no claim, lock, broadcast or rumour on it
/datum/mission_objective/sector_sweep/proc/is_ordinary_signal(obj/structure/overmap/space_ruin/ruin)
	if(QDELETED(ruin) || ruin.type != /obj/structure/overmap/space_ruin || !ruin.sensor_detectable)
		return FALSE
	if(ruin.rare || ruin.no_replacement || ruin.mission_locked || ruin.mission_exclusive || ruin.mission_claims)
		return FALSE
	return !(ruin in GLOB.overmap_fleet_beacons)

/// The find, if it is still out there
/datum/mission_objective/sector_sweep/proc/get_find()
	var/obj/structure/overmap/space_ruin/find = find_ref?.resolve()
	if(QDELETED(find))
		find_ref = null
		return null
	return find

/// " to the northeast" from the ship to `object`, or "" when there is no bearing
/datum/mission_objective/sector_sweep/proc/bearing_to(obj/structure/overmap/object)
	var/static/list/compass_words = list(
		"N" = "north", "NE" = "northeast", "E" = "east", "SE" = "southeast",
		"S" = "south", "SW" = "southwest", "W" = "west", "NW" = "northwest",
	)
	var/obj/structure/overmap/ship/ship = get_servant()
	var/list/from = ship?.get_relative_overmap_coords()
	var/list/to_coords = object?.get_relative_overmap_coords()
	if(!from || !to_coords)
		return ""
	var/dx = overmap_wrapped_delta(to_coords[1] - from[1], OVERMAP_SIZE - 2)
	var/dy = overmap_wrapped_delta(to_coords[2] - from[2], OVERMAP_SIZE - 2)
	var/compass = overmap_delta_to_compass(dx, dy)
	if(!compass)
		return ""
	return " to the [compass_words[compass]]"

/datum/mission_objective/sector_sweep/proc/report_return()
	return_timer = null
	if(!active || completed)
		return
	var/obj/structure/overmap/space_ruin/find = get_find()
	if(!find)
		return
	return_reported = TRUE
	notify_crew("Faint return[bearing_to(find)].", sound = 'sound/machines/sonar-ping.ogg')

/datum/mission_objective/sector_sweep/proc/finish_sweep()
	finish_timer = null
	if(!active || completed)
		return
	running = FALSE
	banked_time = sweep_time
	if(return_timer)
		deltimer(return_timer)
		return_timer = null
	var/static/list/quiet_lines = list(
		"Sector charted. Quiet out here.",
		"Sector charted. Nothing but dust.",
		"Sector charted. Just old drive wakes.",
	)
	var/line = pick(quiet_lines)
	var/obj/structure/overmap/ship/ship = get_servant()
	var/obj/structure/overmap/space_ruin/find = get_find()
	// A scan the crew ran themselves meanwhile may have charted it already: no news then
	if(ship && find && ship.chart_as_waypoint(find))
		line = "Sector charted. Derelict signal logged[bearing_to(find)]."
	notify_crew("[line] Pay's waiting on the board.", sound = 'voidcrew/sound/notify2.ogg')
	var/datum/mission/owner = mission
	complete()
	owner?.push_waypoint()

/datum/mission_objective/sector_sweep/get_progress_string()
	if(completed)
		return "Sector charted"
	if(running)
		return "Sweeping the sector"
	if(started)
		return "Sweep broken off"
	return "Sweep the sector"
