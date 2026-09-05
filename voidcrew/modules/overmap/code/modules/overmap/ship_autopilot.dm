/**
 * # Autopilot
 *
 * Plots a course to a tile on the overmap and flies it, steering one tile at a
 * time. The helm engages it by right-clicking the chart; everything else here is
 * the ship flying itself.
 *
 * **It steers, it does not teleport.** The autopilot flies with the same headings
 * and the same `burn_percentage` throttle a player uses, so fuel, mass, interdiction
 * throttling and zone transitions all behave the same as hand-flying. There is no
 * separate autopilot movement path to keep in step with the manual one.
 *
 * The one thing it does that a burn cannot is stop dead: `full_stop()`,
 * `kill_drift()` and `clamp_speed()` write the velocity directly instead of
 * thrusting against it. That is parity with the helm's force stop rather than a
 * cheat, and it is what keeps the steering honest. An autopilot that has to THRUST
 * its way out of a mistake must predict how much room the mistake will take, and
 * every version of that prediction here eventually deadlocked (see the history in)
 * autopilot_imminent_hazard. Being able to stop means the only tile it ever has to
 * be right about is the next one.
 *
 * **It only routes around what this hull has actually seen.** The danger map is
 * built from `discovered_contacts` (ship_sensors.dm), the permanent record of
 * everything the ship has laid eyes on, never from a map-wide list of hazards,
 * which would be the console knowing things the crew was never told.
 *
 * Building it from the LIVE view ring instead was the original design and it was
 * wrong: the course bent around a storm, the storm dropped out of sight four tiles
 * later, and the next re-plan had no record of it and drove straight back in. Any
 * avoidance scheme with a forgetful danger map oscillates, because re-planning is
 * exactly the act of undoing the avoidance.
 *
 * **Steering is per-tile.** `tick_move()` calls in after every tile crossing, and
 * a slow poll timer covers the times the ship isn't moving, sitting out a zone
 * transition, or starting from a standstill. Nothing steers between tiles because
 * there is no sub-tile position in DM to steer with.
 *
 * **Travel & dock.** A course may carry a docking target with it: on arrival the
 * ship comes to rest and hands the target to overmap_object_act(), the same
 * ship_act() docking path the helm's Dock button drives, so berth allocation,
 * access checks and the dock warmup all behave exactly as if the crew had
 * pressed Dock themselves, and the warmup stays as the crew's abort window.
 *
 * Interrupts are deliberately not signal registrations: the ship already listens
 * to COMSIG_SHIP_WEAPONS_LOCKED on itself, and NPC subtypes already listen to
 * COMSIG_SHIP_INTERDICTED, so a second registration from here would collide on
 * any claimed NPC hull. The four interrupt sites call interrupt_autopilot()
 * directly instead, see the call sites in ship.dm, ship_damage.dm, laser_effect.dm
 * and missile_effect.dm.
 */

/**
 * Cost of stepping onto a tile with a storm or asteroid field on it.
 *
 * Has to exceed the longest detour the map can ask for, or A* does the arithmetic
 * and correctly decides that ploughing through is cheaper. At 24, the original
 * value, anything needing more than a 24-tile detour got a route straight through
 * the weather, which is most fields of any size. The grid is 49x49, so no honest
 * detour approaches this; a hazard is now something the planner will go any
 * distance to avoid.
 *
 * Still finite, not impassable: a ship whose destination sits inside a storm, or
 * which is walled in by one, gets a route rather than "no course found", and the
 * steering layer stops and hands back control rather than flying it (see
 * autopilot_imminent_hazard and the boxed-in check in autopilot_steer).
 */
#define AUTOPILOT_HAZARD_COST 1000
/// Cost of skirting the ring of tiles immediately around a hazard. Enough to
/// prefer a wide berth, cheap enough to squeeze past when that's the real choice.
#define AUTOPILOT_HAZARD_HALO_COST 60
/// Cost of the tiles a known hostile vessel sits on, and its immediate reach.
/// Below a hazard: a hostile is a risk, weather is a certainty.
#define AUTOPILOT_HOSTILE_COST 400
/// Cost of the wider standoff band around a known hostile.
#define AUTOPILOT_HOSTILE_HALO_COST 80
/// Chebyshev radius of the "they can shoot us here" core around a hostile.
#define AUTOPILOT_HOSTILE_CORE_RANGE 2
/// Chebyshev radius of the standoff band around a hostile.
#define AUTOPILOT_HOSTILE_HALO_RANGE 4

/**
 * Danger-map cost at or above which a tile will actually hurt the ship, as
 * opposed to being somewhere the planner would simply rather not go.
 *
 * The halo bands sit below this on purpose. They exist to bias A* toward a wide
 * berth, and nothing more. Treating them as real danger makes the ship slam on
 * the brakes for passing NEAR a storm and re-plan every time a route skirts one,
 * which reads as dithering rather than caution. Only the cores trip the brake.
 */
#define AUTOPILOT_HARM_THRESHOLD AUTOPILOT_HOSTILE_COST

/**
 * Cost of a hazard tile the crew's flight policy tolerates (see the
 * autopilot_cross_* vars). A tolerated field is a nuisance rather than a wall:
 * cheap enough to fly through when it's on the way, dear enough that a clean
 * corridor of similar length still wins. Deliberately below
 * AUTOPILOT_HARM_THRESHOLD, which is the whole mechanism: the brake and the
 * committed latch key off that threshold, so pricing a tolerated hazard under
 * it disables braking and committing for that type with no logic of its own.
 * No halo either, a hazard the crew has agreed to cross needs no wide berth.
 */
#define AUTOPILOT_TOLERATED_COST 5
/**
 * Added per unsurveyed tile a course steps onto. This prices ignorance: the
 * danger map is empty where this hull has never looked, so unexplored space
 * reads as FREE to A* and courses detour through the uncharted far side of the
 * map because nothing bad is on record there. Two per tile means a charted,
 * clean corridor beats an unknown one of similar length, while genuinely long
 * detours through charted space still lose to a short unknown hop.
 */
#define AUTOPILOT_UNCHARTED_COST 2
/// Added per A* step that wraps a map edge. Wrapping is how tick_move() flies,
/// so it stays available, but a course should only go the long way round when
/// it is genuinely shorter, not merely equal and first out of the frontier.
#define AUTOPILOT_WRAP_COST 3
/// Surcharge per zone tier hotter than the trip itself needs (see
/// autopilot_zone_caution and the reference-tier logic in plan_overmap_course).
#define AUTOPILOT_ZONE_CAUTION_COST 4

/// Ceiling on A* expansions, so a pathological danger map can't stall the server.
#define AUTOPILOT_MAX_EXPANSIONS 6000
/// Hard stop on the bucket scan, in case a cost ever escapes its expected range.
#define AUTOPILOT_MAX_FRONTIER 100000

/// How stale a course may get before it is re-planned regardless.
#define AUTOPILOT_REPLAN_INTERVAL (10 SECONDS)
/// Shortest gap between two full re-plans, whatever else is asking for one.
#define AUTOPILOT_REPLAN_FLOOR (2 SECONDS)
/**
 * Tiles a periodic-refresh course must SAVE before it replaces the one being
 * flown. Costs shift a little every rebuild of the danger map, and with no
 * margin the ship swapped between near-equal courses on every refresh, which
 * read on the chart as the autopilot flipping direction mid-flight for
 * nothing. Danger-triggered and lost-course re-plans ignore this: those have
 * no old course worth being loyal to.
 */
#define AUTOPILOT_REPLAN_IMPROVEMENT 3
// autopilot_course_needs_replan() verdicts: nothing to do; the flown course is
// gone or dangerous (adopt whatever the planner returns); or the course is
// still fine and a fresh plan is merely a candidate to be measured against it.
#define AUTOPILOT_REPLAN_NONE 0
#define AUTOPILOT_REPLAN_FORCED 1
#define AUTOPILOT_REPLAN_PERIODIC 2
/// How many steps ahead a newly-spotted hazard forces an immediate re-plan, and
/// how far ahead the route is checked for unsurveyed ground.
#define AUTOPILOT_LOOKAHEAD 6
/// Fraction of full cruise held while flying into tiles this ship has never
/// looked at. Halving speed doubles the seconds between spotting something at the
/// edge of sight and arriving at it, which is what a wide hazard field needs to be
/// worked around rather than crabbed along.
#define AUTOPILOT_UNCHARTED_CRUISE 0.5
/// Drives the autopilot while the ship isn't crossing tiles of its own accord.
#define AUTOPILOT_POLL_INTERVAL (2 SECONDS)
/**
 * Re-check cadence while the engines are actually burning, matched to
 * SSfastprocess so the control loop runs at the same rate as the thrust it is
 * controlling.
 *
 * change_heading() commands a CONTINUOUS burn, it thrusts every process tick
 * until something changes it, whereas steering otherwise only reconsiders once
 * per tile crossing, which at low speed is many seconds apart. Left on the slow
 * cadence a burn meant to add a little speed added a lot (observed: 0.2 against a
 * 0.1 ceiling), because nothing looked again until the ship had already crossed a
 * tile at the speed the burn had built.
 *
 * Coasting stays on the slow poll, so this only costs while manoeuvring.
 */
#define AUTOPILOT_BURN_POLL (0.2 SECONDS)
/// How long the danger map stays warm. It is rebuilt from a couple of hundred
/// remembered contacts, which is too much to redo at the burn cadence.
#define AUTOPILOT_DANGER_LIFETIME (0.5 SECONDS)

// The flyable interior of the overmap, tick_move() wraps a ship that steps onto
// the outermost ring, so these are the tiles a course may actually contain.
#define OVERMAP_PATH_LOW_X (OVERMAP_LEFT_SIDE_COORD + 1)
#define OVERMAP_PATH_HIGH_X (OVERMAP_RIGHT_SIDE_COORD - 1)
#define OVERMAP_PATH_LOW_Y (OVERMAP_SOUTH_SIDE_COORD + 1)
#define OVERMAP_PATH_HIGH_Y (OVERMAP_NORTH_SIDE_COORD - 1)
#define OVERMAP_PATH_SPAN_X (OVERMAP_PATH_HIGH_X - OVERMAP_PATH_LOW_X + 1)
#define OVERMAP_PATH_SPAN_Y (OVERMAP_PATH_HIGH_Y - OVERMAP_PATH_LOW_Y + 1)

/obj/structure/overmap/ship
	/// Whether a course is currently being flown.
	var/autopilot_engaged = FALSE
	/// Destination, in absolute turf coordinates.
	var/autopilot_dest_x
	var/autopilot_dest_y
	/// What the crew asked for, for the helm readout ("Trader Halcyon", "41 / 22").
	var/autopilot_label
	/// Remaining course as a list of list(x, y) in absolute coordinates, next step
	/// first. Nodes are dropped as the ship crosses them.
	var/list/autopilot_path
	/// Repeating steer timer, live only while engaged.
	var/autopilot_poll_timer
	/// world.time of the last full re-plan.
	var/autopilot_last_plan = 0
	/// Danger map, kept warm across the fast burn-cadence polls.
	var/list/autopilot_danger_cache
	var/autopilot_danger_time = 0
	/// TRUE once a re-plan has come back still routing through danger, the way
	/// through is the best on offer, so stop asking. Cleared the moment the
	/// course ahead is clean again.
	var/autopilot_danger_committed = FALSE
	/// Why the last course ended, shown once on the helm. Cleared on the next engage.
	var/autopilot_status
	/// Overmap object to dock with when the course completes, or null for plain
	/// travel. Validated by the helm at engage time, re-checked on arrival.
	var/datum/weakref/autopilot_dock_ref
	/// Who engaged the course, for the arrival dock's feedback messages.
	var/datum/weakref/autopilot_user_ref
	/**
	 * TRUE while the crew has knowingly plotted INTO a hazard: a travel & dock
	 * order (the destination is the field), or plain coordinates with
	 * autopilot_hazard_landing switched on. The danger check and the one-tile
	 * brake skip the destination tile while this is set, which is what lets a
	 * course actually END on an asteroid field instead of stopping one tile
	 * short and disengaging. The destination alone; every tile on the way there
	 * keeps its full protection. Cleared with the course.
	 */
	var/autopilot_dest_consented = FALSE

	// Flight policy, set from the helm (see set_autopilot_pref). Defaults avoid
	// all weather and hazard destinations; known-hostile avoidance is opt-in.
	/// Tolerate asteroid fields rather than routing around them.
	var/autopilot_cross_meteor = FALSE
	/// Tolerate ion storms rather than routing around them.
	var/autopilot_cross_electric = FALSE
	/// Tolerate EMP clouds rather than routing around them.
	var/autopilot_cross_emp = FALSE
	/// Stamp known hostile vessels into the danger map.
	var/autopilot_avoid_hostiles = FALSE
	/// Surcharge tiles in zone bands hotter than the trip itself needs.
	var/autopilot_zone_caution = TRUE
	/// Allow plotted coordinates that sit on a hazard tile (destination consent).
	var/autopilot_hazard_landing = FALSE

// ---------------------------------------------------------------- grid helpers

/// Folds an x coordinate back into the flyable band, the same way tick_move() does.
/proc/overmap_wrap_x(value)
	var/span = OVERMAP_PATH_SPAN_X
	while(value < OVERMAP_PATH_LOW_X)
		value += span
	while(value > OVERMAP_PATH_HIGH_X)
		value -= span
	return value

/// Folds a y coordinate back into the flyable band, the same way tick_move() does.
/proc/overmap_wrap_y(value)
	var/span = OVERMAP_PATH_SPAN_Y
	while(value < OVERMAP_PATH_LOW_Y)
		value += span
	while(value > OVERMAP_PATH_HIGH_Y)
		value -= span
	return value

/**
 * The shorter of the two ways round for a coordinate delta. The overmap wraps, so
 * a ship at x=3 is four tiles from x=48, not forty-five, routing and steering both
 * have to agree with the wraparound tick_move() actually performs.
 */
/proc/overmap_wrapped_delta(delta, span)
	if(delta > span * 0.5)
		return delta - span
	if(delta < -span * 0.5)
		return delta + span
	return delta

/// Tiles between two overmap positions when diagonal steps are free, which they
/// are: a diagonal burn crosses one tile on each axis per tick.
/proc/overmap_course_heuristic(from_x, from_y, to_x, to_y)
	var/step_x = abs(overmap_wrapped_delta(to_x - from_x, OVERMAP_PATH_SPAN_X))
	var/step_y = abs(overmap_wrapped_delta(to_y - from_y, OVERMAP_PATH_SPAN_Y))
	return max(step_x, step_y)

/**
 * How hot the zone band under an overmap tile is, as an explicit 0/1/2 ladder:
 * green 0, yellow 1, red 2. Written out rather than derived from the ZONE_*
 * define values, those happen to be ordered integers today, but the ordering
 * is not part of their contract and arithmetic on them would break silently if
 * a band were ever added or renumbered. Tiles with no zone read as green.
 */
/proc/autopilot_zone_tier(tile_x, tile_y)
	var/turf/open/overmap/tile = locate(overmap_wrap_x(tile_x), overmap_wrap_y(tile_y), OVERMAP_Z_LEVEL)
	if(!istype(tile) || !tile.current_zone)
		return 0
	switch(tile.current_zone.zone_type)
		if(ZONE_GREEN)
			return 0
		if(ZONE_YELLOW)
			return 1
		if(ZONE_RED)
			return 2
	return 0

/**
 * Stamps a danger disc onto the cost map. Costs are taken as a maximum rather than
 * summed, so a tile caught by two overlapping hazards reads as the worse of the
 * two instead of an inflated total that would distort the route around it.
 */
/proc/stamp_autopilot_danger(list/danger, centre_x, centre_y, core_range, core_cost, halo_range, halo_cost)
	for(var/offset_x in -halo_range to halo_range)
		for(var/offset_y in -halo_range to halo_range)
			var/distance = max(abs(offset_x), abs(offset_y))
			var/cost = distance <= core_range ? core_cost : halo_cost
			var/key = "[overmap_wrap_x(centre_x + offset_x)],[overmap_wrap_y(centre_y + offset_y)]"
			danger[key] = max(danger[key] || 0, cost)

// ---------------------------------------------------------------- course planning

/**
 * A* across the overmap grid, honouring edge wraparound and the danger costs in
 * `danger` (a "x,y" -> extra cost map; see stamp_autopilot_danger).
 *
 * The open set is a bucket queue keyed on f rather than a sorted list: step costs
 * are small integers and the Chebyshev heuristic is consistent, so f never
 * decreases and the frontier only ever scans forward. That keeps a re-plan cheap
 * enough to run on every tile crossing.
 *
 * Every step costs 1 whatever its direction (diagonals are how tick_move()
 * actually flies), so any two tiles are joined by many equal-cost courses and
 * the expansion order is the tie-break that decides which of them gets flown.
 * Neighbours are pushed worst-to-best against the destination bearing, the
 * bucket pops its tail, so the step aimed straight at the destination is the
 * first one explored, and every tie resolves into the line a pilot would draw.
 * With a fixed push order here instead, the tail pop amounted to an absolute
 * compass preference (NE, then E, then SE...) and every course in open space
 * bowed north-east: a hop due east was plotted as a four-tile-tall arc.
 *
 * `pilot`, when given, prices in what that ship KNOWS: unsurveyed tiles carry
 * AUTOPILOT_UNCHARTED_COST (the danger map is silent about space the hull has
 * never looked at, so without this, ignorance reads as safety and courses bend
 * through the uncharted far side of the map), and with autopilot_zone_caution
 * set, tiles in a hotter zone band than the trip itself needs carry a
 * surcharge, measured against the hotter of the origin and destination bands,
 * so a green-to-green run won't cut through yellow to save two tiles while a
 * run INTO red doesn't fight its own destination.
 *
 * Returns the course as a list of list(x, y), destination last and the starting
 * tile omitted. Returns an empty list when already there, or null if no route
 * exists inside the expansion budget.
 */
/proc/plan_overmap_course(start_x, start_y, dest_x, dest_y, list/danger, obj/structure/overmap/ship/pilot)
	start_x = overmap_wrap_x(start_x)
	start_y = overmap_wrap_y(start_y)
	dest_x = overmap_wrap_x(dest_x)
	dest_y = overmap_wrap_y(dest_y)

	var/start_key = "[start_x],[start_y]"
	var/dest_key = "[dest_x],[dest_y]"
	if(start_key == dest_key)
		return list()

	if(!danger)
		danger = list()
	var/list/came_from = list()
	var/list/cost_so_far = list()
	var/list/buckets = list()

	// The band the trip itself already commits to: the hotter of where it starts
	// and where it ends. Computed once, the surcharge below is relative to it.
	var/zone_caution = pilot?.autopilot_zone_caution
	var/reference_tier = 0
	if(zone_caution)
		reference_tier = max(autopilot_zone_tier(start_x, start_y), autopilot_zone_tier(dest_x, dest_y))
	// Zone tiers are read per neighbour via locate(), which is cheap but not
	// free at thousands of expansions; each tile's tier is asked for once.
	var/list/zone_tier_cache = list()

	cost_so_far[start_key] = 0
	var/frontier = overmap_course_heuristic(start_x, start_y, dest_x, dest_y)
	buckets["[frontier]"] = list(start_key)
	var/queued = 1
	var/expansions = 0
	var/found = FALSE

	while(queued > 0)
		var/list/bucket = buckets["[frontier]"]
		if(!length(bucket))
			frontier++
			if(frontier > AUTOPILOT_MAX_FRONTIER)
				break
			continue

		var/current = bucket[length(bucket)]
		bucket.len--
		queued--

		if(current == dest_key)
			found = TRUE
			break

		var/current_cost = cost_so_far[current]
		if(isnull(current_cost))
			continue

		var/list/parts = splittext(current, ",")
		var/current_x = text2num(parts[1])
		var/current_y = text2num(parts[2])

		// A cheaper route to this tile was found after this entry was queued, so
		// this copy sits in a bucket above its real f and has already been beaten.
		if(current_cost + overmap_course_heuristic(current_x, current_y, dest_x, dest_y) < frontier)
			continue

		expansions++
		if(expansions > AUTOPILOT_MAX_EXPANSIONS)
			break

		// The tie-breaking order (see the doc comment): each axis runs worst-to-
		// best against the bearing so the bearing-matching step is pushed last and
		// popped first. An already-aligned axis (bearing 0) puts its straight step
		// last for the same reason.
		var/bearing_x = SIGN(overmap_wrapped_delta(dest_x - current_x, OVERMAP_PATH_SPAN_X))
		var/bearing_y = SIGN(overmap_wrapped_delta(dest_y - current_y, OVERMAP_PATH_SPAN_Y))
		var/list/steps_x = bearing_x ? list(-bearing_x, 0, bearing_x) : list(-1, 1, 0)
		var/list/steps_y = bearing_y ? list(-bearing_y, 0, bearing_y) : list(-1, 1, 0)
		for(var/step_x in steps_x)
			for(var/step_y in steps_y)
				if(!step_x && !step_y)
					continue
				var/next_x = overmap_wrap_x(current_x + step_x)
				var/next_y = overmap_wrap_y(current_y + step_y)
				var/next_key = "[next_x],[next_y]"
				var/new_cost = current_cost + 1 + (danger[next_key] || 0)
				// The step crossed a map edge if the wrap moved it. Legal, but it
				// should only win when the long way round is genuinely shorter.
				if(next_x != current_x + step_x || next_y != current_y + step_y)
					new_cost += AUTOPILOT_WRAP_COST
				if(pilot)
					// The danger map cannot indict a tile nobody has looked at, so
					// ignorance is priced instead (see AUTOPILOT_UNCHARTED_COST).
					if(!pilot.is_tile_surveyed(next_x - OVERMAP_LEFT_SIDE_COORD + 1, next_y - OVERMAP_SOUTH_SIDE_COORD + 1))
						new_cost += AUTOPILOT_UNCHARTED_COST
					if(zone_caution)
						var/tier = zone_tier_cache[next_key]
						if(isnull(tier))
							tier = autopilot_zone_tier(next_x, next_y)
							zone_tier_cache[next_key] = tier
						new_cost += max(0, tier - reference_tier) * AUTOPILOT_ZONE_CAUTION_COST
				var/existing = cost_so_far[next_key]
				if(!isnull(existing) && existing <= new_cost)
					continue
				cost_so_far[next_key] = new_cost
				came_from[next_key] = current
				var/priority = new_cost + overmap_course_heuristic(next_x, next_y, dest_x, dest_y)
				var/list/target_bucket = buckets["[priority]"]
				if(!target_bucket)
					target_bucket = list()
					buckets["[priority]"] = target_bucket
				target_bucket += next_key
				queued++

	if(!found)
		return null

	// Walked destination-first off came_from, then flipped, rather than inserting
	// at the head each step: the course is short but the insert is not free.
	var/list/reversed = list()
	var/cursor = dest_key
	// A consistent heuristic can't produce a cycle in came_from, but an unbounded
	// while() walking a parent chain hangs the whole server if that ever stops
	// being true. The grid is the ceiling on any honest path length.
	var/steps_left = OVERMAP_PATH_SPAN_X * OVERMAP_PATH_SPAN_Y
	while(cursor != start_key)
		var/list/parts = splittext(cursor, ",")
		reversed += list(list(text2num(parts[1]), text2num(parts[2])))
		cursor = came_from[cursor]
		if(!cursor)
			return null
		steps_left--
		if(steps_left <= 0)
			CRASH("plan_overmap_course walked a cycle reconstructing a path to [dest_key]")

	var/list/course = list()
	for(var/index in length(reversed) to 1 step -1)
		course += list(reversed[index])
	return course

/**
 * The cost map the next course will be planned against, built from what this ship
 * can see right now.
 *
 * Storms and asteroid fields inside the view ring are hard detours; nebulas are
 * deliberately absent, being a resource and a hiding place rather than a threat.
 * Known-hostile vessels get a standoff band, but only ones this ship has actually
 * identified, an unscanned contact is not known to be dangerous, and routing
 * around it would leak identity the crew hasn't earned.
 */
/obj/structure/overmap/ship/proc/build_autopilot_danger_map()
	if(autopilot_danger_cache && (world.time - autopilot_danger_time) < AUTOPILOT_DANGER_LIFETIME)
		return autopilot_danger_cache

	var/list/danger = list()
	var/turf/our_turf = get_turf(src)
	if(!our_turf)
		return danger

	// Everything this hull has ever seen, not just what is in front of it now.
	// Building this from the live view ring alone was a loop: the course bent
	// around a storm, the storm fell out of sight four tiles later, the next
	// re-plan had no record of it and drove straight back in.
	//
	// get_contact_snapshot() is what records discoveries, and it is cached for a
	// second, so this is how the autopilot keeps seeing new hazards while flying
	// with no helm open, without it, nothing would observe the view ring.
	get_contact_snapshot()
	for(var/contact_ref in discovered_contacts)
		var/datum/weakref/remembered = discovered_contacts[contact_ref]
		var/obj/structure/overmap/event/hazard = remembered?.resolve()
		if(!istype(hazard) || istype(hazard, /obj/structure/overmap/event/nebula))
			continue
		if(autopilot_hazard_tolerated(hazard))
			// The crew's flight policy accepts this weather. Priced as a
			// nuisance rather than a wall, below AUTOPILOT_HARM_THRESHOLD so
			// the brake and the committed latch ignore it, and with no halo,
			// a hazard you're willing to fly through needs no wide berth.
			stamp_autopilot_danger(danger, hazard.x, hazard.y, 0, AUTOPILOT_TOLERATED_COST, 0, AUTOPILOT_TOLERATED_COST)
			continue
		stamp_autopilot_danger(danger, hazard.x, hazard.y, 0, AUTOPILOT_HAZARD_COST, 1, AUTOPILOT_HAZARD_HALO_COST)

	if(autopilot_avoid_hostiles)
		var/tracking = can_scan_ships()
		for(var/obj/structure/overmap/ship/npc/other in SSovermap.simulated_ships)
			if(other == src || other.hidden_in_nebula || !other.hostile)
				continue
			if(!tracking && !identified_ships[REF(other)])
				continue
			stamp_autopilot_danger(danger, other.x, other.y, AUTOPILOT_HOSTILE_CORE_RANGE, AUTOPILOT_HOSTILE_COST, AUTOPILOT_HOSTILE_HALO_RANGE, AUTOPILOT_HOSTILE_HALO_COST)

	autopilot_danger_cache = danger
	autopilot_danger_time = world.time
	return danger

/// Whether the crew's flight policy tolerates crossing this hazard's type.
/// Anything unrecognised is not tolerated, new weather is dangerous until a
/// toggle for it is deliberately added here and on the helm.
/obj/structure/overmap/ship/proc/autopilot_hazard_tolerated(obj/structure/overmap/event/hazard)
	if(istype(hazard, /obj/structure/overmap/event/meteor))
		return autopilot_cross_meteor
	if(istype(hazard, /obj/structure/overmap/event/electric))
		return autopilot_cross_electric
	if(istype(hazard, /obj/structure/overmap/event/emp))
		return autopilot_cross_emp
	return FALSE

// ---------------------------------------------------------------- engage / end

/**
 * Plots and begins flying a course to an absolute overmap coordinate. Returns a
 * message for the console to say, whether or not it took. Pass `dock_target` to
 * end the course in a docking approach, see complete_autopilot().
 */
/obj/structure/overmap/ship/proc/engage_autopilot(dest_x, dest_y, label, mob/user, obj/structure/overmap/dock_target = null)
	if(state != OVERMAP_SHIP_FLYING)
		return "ERROR: Autopilot requires the ship to be under way."
	if(hidden_in_nebula)
		return "ERROR: Cannot plot a course while concealed."
	if(is_interdicted)
		return "ERROR: Interdiction field is holding us. Autopilot unavailable."
	if(!can_thrust())
		return "ERROR: No engine power. Autopilot unavailable."

	dest_x = overmap_wrap_x(dest_x)
	dest_y = overmap_wrap_y(dest_y)
	if(dest_x == x && dest_y == y)
		return "Autopilot: already at those coordinates."

	var/list/danger = build_autopilot_danger_map()
	var/list/course = plan_overmap_course(x, y, dest_x, dest_y, danger, src)
	if(isnull(course))
		return "ERROR: Unable to plot a course to those coordinates."

	autopilot_engaged = TRUE
	autopilot_dest_x = dest_x
	autopilot_dest_y = dest_y
	autopilot_label = label
	autopilot_path = course
	autopilot_last_plan = world.time
	autopilot_status = null
	autopilot_dock_ref = dock_target ? WEAKREF(dock_target) : null
	autopilot_user_ref = user ? WEAKREF(user) : null
	// Destination consent: a travel & dock order names the hazard itself as the
	// destination, and the hazard-landing policy extends the same consent to
	// bare coordinates. Either way the crew chose that tile on purpose, so the
	// danger checks stop protecting them from it (and only it, see the var).
	autopilot_dest_consented = !!dock_target || autopilot_hazard_landing
	// The autopilot owns the ship now; the commanded course (and the rose it
	// lights on the helm) stands down with the rest of manual control.
	commanded_course = BURN_NONE

	if(user)
		log_shuttle("[key_name(user)] engaged autopilot on [name] to ([dest_x], [dest_y])")

	schedule_autopilot_poll()
	autopilot_steer()
	push_helm_frame()

	// Say up front when the plotted line runs through weather the flight policy
	// tolerates, so "cross asteroid fields" never reads as the autopilot
	// quietly deciding that for the crew.
	var/tolerated_crossings = 0
	for(var/list/node as anything in course)
		if(danger["[node[1]],[node[2]]"] == AUTOPILOT_TOLERATED_COST)
			tolerated_crossings++
	var/crossing_note = tolerated_crossings ? ", crosses [tolerated_crossings] hazard[tolerated_crossings > 1 ? "s" : ""] under current flight policy" : ""
	if(dock_target)
		return "Autopilot engaged. Course plotted to [label || "([dest_x], [dest_y])"], [length(course)] tiles, ending in a docking approach[crossing_note]."
	return "Autopilot engaged. Course plotted to [label || "([dest_x], [dest_y])"], [length(course)] tiles[crossing_note]."

/**
 * Ends the current course. `reason` is shown to the crew and left on the helm;
 * pass null for a silent stand-down (the crew took the controls back themselves).
 *
 * The ship is left coasting rather than braked. An autopilot that slams on the
 * brakes the instant someone locks weapons on you hands back a stationary target;
 * keeping the velocity means the crew inherits a ship that is still going
 * somewhere and can decide what to do with it.
 */
/obj/structure/overmap/ship/proc/disengage_autopilot(reason, notify = TRUE)
	if(!autopilot_engaged)
		return
	autopilot_engaged = FALSE
	autopilot_path = null
	autopilot_danger_cache = null
	autopilot_status = reason
	autopilot_dock_ref = null
	autopilot_user_ref = null
	autopilot_dest_consented = FALSE
	if(autopilot_poll_timer)
		deltimer(autopilot_poll_timer)
		autopilot_poll_timer = null
	if(burn_direction != BURN_NONE)
		change_heading(BURN_NONE)
	if(notify && reason && ship_team)
		ship_notify("Autopilot disengaged: [reason]. Manual control restored.", "AUTOPILOT", SHIP_NOTIFY_WARNING, 'voidcrew/sound/warn.ogg', 25)
	push_helm_frame()

/// Interrupt hook for the events that should break a course. Safe from a
/// SIGNAL_HANDLER: nothing below it sleeps.
/obj/structure/overmap/ship/proc/interrupt_autopilot(reason)
	if(!autopilot_engaged)
		return
	disengage_autopilot(reason)

/// Course flown. Unlike an interrupt this does bring the ship to rest, arriving
/// is the one case where stopping is the whole point. A course carrying a dock
/// target then hands it straight to the ship_act() docking path (see the header).
/obj/structure/overmap/ship/proc/complete_autopilot()
	autopilot_engaged = FALSE
	autopilot_path = null
	autopilot_status = "arrived"
	if(autopilot_poll_timer)
		deltimer(autopilot_poll_timer)
		autopilot_poll_timer = null
	full_stop()

	// Compared against the target's LIVE position rather than close_overmap_objects,
	// which is maintained by enter/exit signals and need not have caught up with the
	// forceMove that just landed us here. The target validated at engage time can
	// also be gone or moved by now. Then this is just an arrival like any other.
	var/obj/structure/overmap/dock_target = autopilot_dock_ref?.resolve()
	var/mob/pilot = autopilot_user_ref?.resolve()
	autopilot_dock_ref = null
	autopilot_user_ref = null
	autopilot_dest_consented = FALSE
	if(dock_target && !QDELETED(dock_target) && dock_target.x == x && dock_target.y == y)
		if(ship_team)
			ship_notify("Autopilot: arrived at [autopilot_label || "the plotted position"], commencing docking approach.", "AUTOPILOT", SHIP_NOTIFY_NOTICE, 'voidcrew/sound/notify.ogg', 50)
		// We just stopped, so overmap_object_act()'s stillness gate passes; it
		// INVOKE_ASYNCs ship_act, and this runs from a timer, so nothing sleeps here.
		overmap_object_act(pilot, dock_target)
	else if(ship_team)
		ship_notify("Autopilot: arrived at [autopilot_label || "the plotted position"]. Holding station.", "AUTOPILOT", SHIP_NOTIFY_NOTICE, 'voidcrew/sound/notify.ogg', 50)
	push_helm_frame()

// ---------------------------------------------------------------- steering

/obj/structure/overmap/ship/proc/schedule_autopilot_poll(delay = AUTOPILOT_POLL_INTERVAL)
	if(autopilot_poll_timer)
		deltimer(autopilot_poll_timer)
	autopilot_poll_timer = addtimer(CALLBACK(src, PROC_REF(autopilot_poll)), delay, TIMER_STOPPABLE)

/obj/structure/overmap/ship/proc/autopilot_poll()
	autopilot_poll_timer = null
	if(!autopilot_engaged || QDELETED(src))
		return
	autopilot_steer()
	if(autopilot_engaged)
		schedule_autopilot_poll()

/// The direction to burn to reach an adjacent course node, ignoring velocity.
/obj/structure/overmap/ship/proc/autopilot_step_dir(node_x, node_y)
	var/step_x = overmap_wrapped_delta(node_x - x, OVERMAP_PATH_SPAN_X)
	var/step_y = overmap_wrapped_delta(node_y - y, OVERMAP_PATH_SPAN_Y)
	var/step_dir = NONE
	if(step_x > 0)
		step_dir |= EAST
	else if(step_x < 0)
		step_dir |= WEST
	if(step_y > 0)
		step_dir |= NORTH
	else if(step_y < 0)
		step_dir |= SOUTH
	return step_dir

/**
 * Points the velocity at the next course node, and returns the burn still needed
 * to get there (NONE when the drift already does the job).
 *
 * This is the part that makes course-following work at speed. `tick_move()` steps
 * the ship by `SIGN(speed[1])` and `SIGN(speed[2])`, so the direction of travel is
 * decided purely by the SIGNS of the velocity vector. Magnitude only sets how
 * often a tile is crossed. A hair of leftover speed on the wrong axis therefore
 * doesn't nudge the ship slightly off course, it sends it diagonally, every tick,
 * until it's cancelled.
 *
 * A turn is therefore two different jobs, and they are done two different ways:
 *
 * - An axis moving the WRONG way is zeroed outright with kill_drift(). Burning
 *   against it was the old approach and it relied on accelerate() clamping the
 *   burn to the speed left on that axis, which it does, right up until the axis
 *   reaches zero, at which point the clamp stops applying and the same burn drives
 *   it out the other side. Writing the zero is the thing that was being simulated.
 * - An axis that needs speed ADDED is a burn like any other, with no clamp to
 *   fight, so it is left to the engines.
 *
 * The axis already carrying the ship the right way is never touched by either.
 */
/obj/structure/overmap/ship/proc/autopilot_aim_drift(want_x, want_y)
	var/drift_x = SIGN(speed[1])
	var/drift_y = SIGN(speed[2])
	kill_drift(drift_x && drift_x != want_x, drift_y && drift_y != want_y)

	var/burn = NONE
	if(want_x && SIGN(speed[1]) != want_x)
		burn |= (want_x > 0) ? EAST : WEST
	if(want_y && SIGN(speed[2]) != want_y)
		burn |= (want_y > 0) ? NORTH : SOUTH
	return burn

/**
 * One steering decision. Called after every tile the ship crosses, and on the poll
 * timer whenever it isn't crossing any.
 */
/obj/structure/overmap/ship/proc/autopilot_steer()
	if(!autopilot_engaged || QDELETED(src))
		return
	if(state != OVERMAP_SHIP_FLYING)
		disengage_autopilot("ship is no longer under way")
		return
	if(hidden_in_nebula)
		disengage_autopilot("concealment engaged")
		return
	// A zone crossing cuts the engines for its duration and clears the burn. Sit
	// through it, the poll timer picks the course back up on the far side, which
	// is the whole reason the poll runs independently of tile crossings.
	if(zone_transitioning)
		return
	if(!can_thrust())
		disengage_autopilot("no engine power")
		return

	// On the destination tile. Nothing to wind down, complete_autopilot() stops the
	// ship where it stands, which is why there is no braking approach further down.
	if(x == autopilot_dest_x && y == autopilot_dest_y)
		complete_autopilot()
		return

	// Drop the nodes we've already flown through.
	while(length(autopilot_path))
		var/list/node = autopilot_path[1]
		if(node[1] == x && node[2] == y)
			autopilot_path.Cut(1, 2)
		else
			break

	// In uncharted space the caches are the wrong side of the ledger: the
	// contact snapshot holds for a second and the danger map for half of one,
	// which together can be older than a tile crossing, so the one-tile brake
	// below could clear a step on a picture taken before a storm entered sensor
	// range. Force both fresh whenever the tile under us or the one the course
	// steps to next is unsurveyed; charted space keeps the cheap caches, its
	// danger map already knows everything there is to know.
	if(!is_tile_surveyed(x - OVERMAP_LEFT_SIDE_COORD + 1, y - OVERMAP_SOUTH_SIDE_COORD + 1))
		contact_snapshot = null
		autopilot_danger_cache = null
	else if(length(autopilot_path))
		var/list/peek = autopilot_path[1]
		if(!is_tile_surveyed(peek[1] - OVERMAP_LEFT_SIDE_COORD + 1, peek[2] - OVERMAP_SOUTH_SIDE_COORD + 1))
			contact_snapshot = null
			autopilot_danger_cache = null

	var/list/danger = build_autopilot_danger_map()

	// Before anything clever: are we about to cross onto something that will hurt?
	// Stopping is free and instant, so it outranks routing, cruising and everything
	// else. From rest the ship re-plans able to pick any direction, instead of having
	// to fight its own drift.
	if(autopilot_imminent_hazard(danger))
		full_stop()
		schedule_autopilot_poll(AUTOPILOT_BURN_POLL)
		return

	var/replan = autopilot_course_needs_replan(danger)
	if(replan != AUTOPILOT_REPLAN_NONE)
		var/list/course = plan_overmap_course(x, y, autopilot_dest_x, autopilot_dest_y, danger, src)
		if(isnull(course))
			// A periodic refresh blowing its expansion budget is not an
			// emergency: the course being flown is, by the verdict above, still
			// valid and danger-free. Keep flying it and ask again later.
			if(replan == AUTOPILOT_REPLAN_PERIODIC)
				autopilot_last_plan = world.time
			else
				disengage_autopilot("no safe course to the destination")
				return
		else if(replan == AUTOPILOT_REPLAN_PERIODIC && length(course) + AUTOPILOT_REPLAN_IMPROVEMENT > length(autopilot_path))
			// Stickiness: a refresh only replaces a healthy course when it is
			// meaningfully shorter. Costs wobble a little between danger-map
			// rebuilds, and swapping between near-equal courses read on the
			// chart as the ship flipping direction mid-flight for nothing.
			autopilot_last_plan = world.time
		else
			autopilot_path = course
			autopilot_last_plan = world.time
			// If the fresh course STILL runs through something, that is the best route
			// available, commit to it rather than re-planning every tile for the
			// length of the trip.
			autopilot_danger_committed = autopilot_course_has_danger(danger)

	// Stopped, and the best route out of here still runs through a hazard. Flying
	// into a storm is not a decision the autopilot gets to make on the crew's
	// behalf, hand the ship back where it is, safely at rest.
	if(autopilot_danger_committed && is_still())
		disengage_autopilot("hazard blocking the only route")
		return

	if(!length(autopilot_path))
		full_stop()
		return

	var/list/next_node = autopilot_path[1]
	var/step_dir = autopilot_step_dir(next_node[1], next_node[2])
	if(!step_dir)
		return

	// Trimmed rather than braked down to. Crossing into unsurveyed space halves the
	// ceiling mid-flight, and shedding the excess by burning meant re-checking every
	// process tick and sawtoothing around the ceiling on the way; scaling the vector
	// lands on it exactly, in one call, without touching the heading.
	var/cruise = autopilot_cruise_speed()
	clamp_speed(cruise)

	// Where the velocity has to point for the next tick to land us on the next node.
	var/want_x = ((step_dir & EAST) ? 1 : 0) - ((step_dir & WEST) ? 1 : 0)
	var/want_y = ((step_dir & NORTH) ? 1 : 0) - ((step_dir & SOUTH) ? 1 : 0)
	var/burn = autopilot_aim_drift(want_x, want_y)
	if(burn)
		if(burn_direction != burn)
			change_heading(burn)
		// A burn keeps thrusting until something stops it, and nothing else looks
		// again until the next tile crossing, which at low speed is many seconds
		// away, long enough to blow well past the ceiling. Look again next thrust tick.
		schedule_autopilot_poll(AUTOPILOT_BURN_POLL)
		return

	// Drifting the right way: hold what we have once we're up to speed. Coasting
	// costs nothing to leave running, so this is the one case that goes back to
	// the slow poll.
	if(MAGNITUDE(speed[1], speed[2]) >= cruise)
		if(burn_direction != BURN_NONE)
			change_heading(BURN_NONE)
		return

	if(burn_direction != step_dir)
		change_heading(step_dir)
	schedule_autopilot_poll(AUTOPILOT_BURN_POLL)

/**
 * The speed the autopilot will hold, which depends on whether it is flying into
 * territory this ship has actually looked at.
 *
 * Sight is four tiles and a hazard is only ever discovered at that edge, so the
 * entire warning a storm gives is the time it takes to cross four tiles, about
 * four seconds at full cruise. That is enough to sidestep a single tile, but not
 * to work around the face of a wide field, which is discovered a few tiles at a
 * time: each new tile of it arrives too late to be planned around and the ship
 * ends up stopping for one after another instead of going round.
 *
 * Stopping dead is instant, so this is not about braking room. It is about giving
 * the PLANNER enough tiles of warning to draw a detour, which is the difference
 * between flying around a storm and stop-starting along its face. So the autopilot
 * slows down where it cannot see what is coming, and runs flat out through space
 * this hull has already charted, where the danger map is already complete and there
 * is nothing left to be surprised by.
 */
/obj/structure/overmap/ship/proc/autopilot_cruise_speed()
	for(var/index in 1 to min(AUTOPILOT_LOOKAHEAD, length(autopilot_path)))
		var/list/node = autopilot_path[index]
		if(!is_tile_surveyed(node[1] - OVERMAP_LEFT_SIDE_COORD + 1, node[2] - OVERMAP_SOUTH_SIDE_COORD + 1))
			return max_speed * AUTOPILOT_UNCHARTED_CRUISE
	return max_speed

/**
 * Whether the current course still deserves to be flown, as a three-way
 * verdict: NONE (fly on), FORCED (the course is gone, abandoned, or newly
 * dangerous, adopt whatever the planner returns), or PERIODIC (the course is
 * healthy and a fresh plan is merely a candidate, to be adopted only if it
 * beats the one in hand by AUTOPILOT_REPLAN_IMPROVEMENT, see autopilot_steer).
 * The split exists because treating a routine refresh as authoritative made
 * the ship swap between near-equal courses and flip direction mid-flight.
 */
/obj/structure/overmap/ship/proc/autopilot_course_needs_replan(list/danger)
	// No course at all, or we drifted off the plotted line (a wraparound, a shove,
	// an overshoot on a tight corner). Either way there is nothing to fly, so these
	// two re-plan immediately whatever the throttle below says.
	if(!length(autopilot_path))
		return AUTOPILOT_REPLAN_FORCED
	var/list/next_node = autopilot_path[1]
	if(abs(overmap_wrapped_delta(next_node[1] - x, OVERMAP_PATH_SPAN_X)) > 1)
		return AUTOPILOT_REPLAN_FORCED
	if(abs(overmap_wrapped_delta(next_node[2] - y, OVERMAP_PATH_SPAN_Y)) > 1)
		return AUTOPILOT_REPLAN_FORCED

	// Something dangerous on the next few steps re-plans NOW, ahead of any
	// throttle. The view ring is four tiles and the ship crosses one a second at
	// cruise, so the entire warning a storm ever gives is about four seconds,
	// and cancelling the existing drift eats one of them. This check used to sit
	// BELOW a two-second floor, which silently spent half that budget and flew
	// the ship into the storm.
	if(autopilot_course_has_danger(danger))
		// Unless we already re-planned against this exact danger and the way
		// through was still the best route on offer. Asking again every tile
		// cannot produce a different answer, and A* over the whole grid is not
		// something to run per tile.
		return autopilot_danger_committed ? AUTOPILOT_REPLAN_NONE : AUTOPILOT_REPLAN_FORCED
	autopilot_danger_committed = FALSE

	// Periodic refresh, for everything that isn't an emergency.
	if((world.time - autopilot_last_plan) < AUTOPILOT_REPLAN_FLOOR)
		return AUTOPILOT_REPLAN_NONE
	if((world.time - autopilot_last_plan) > AUTOPILOT_REPLAN_INTERVAL)
		return AUTOPILOT_REPLAN_PERIODIC
	return AUTOPILOT_REPLAN_NONE

/**
 * Whether the tile the ship is about to cross onto will hurt it.
 *
 * Exactly one tile, and that is the whole check. Steering runs on every tile
 * crossing and stopping is instant, so the next tile is the only one the current
 * drift has actually committed the ship to. Everything past it can still be
 * steered or stopped out of, and avoiding it is the planner's job (see
 * autopilot_course_has_danger, which looks a full six ahead).
 *
 * Taken from the velocity rather than from the plotted course. The plan is where we
 * mean to go; `SIGN(speed)` is where we are actually going, and when those disagree
 * is exactly when a collision happens.
 *
 * **This used to look further and it deadlocked the autopilot outright.** The probe
 * ran `max(2, stopping_distance + 2)` tiles along the velocity ray, which
 * straightened a course that curved around a storm into a line that ran through it:
 * the ship braked for the storm its own route was avoiding, came to rest, which
 * CLEARS this check, re-planned the same curve, burned off along it and tripped
 * the ray again a fifth of a second later, forever. Any lookahead longer than the
 * committed tile reintroduces that, because setting off down a detour always begins
 * by pointing at the thing being detoured around.
 */
/obj/structure/overmap/ship/proc/autopilot_imminent_hazard(list/danger)
	if(is_still())
		return FALSE
	var/step_x = SIGN(speed[1])
	var/step_y = SIGN(speed[2])
	if(!step_x && !step_y)
		return FALSE
	// Already inside one. Stopping doesn't help and every way out crosses more of
	// it, so let the route carry us clear instead of pinning us in place.
	if(danger["[x],[y]"] >= AUTOPILOT_HARM_THRESHOLD)
		return FALSE

	var/next_x = overmap_wrap_x(x + step_x)
	var/next_y = overmap_wrap_y(y + step_y)
	// Stepping onto the destination the crew consented to (a travel & dock
	// order onto the field, or the hazard-landing policy). Braking here is the
	// bug: it left the ship one tile short of the field it was sent to.
	if(autopilot_dest_consented && next_x == autopilot_dest_x && next_y == autopilot_dest_y)
		return FALSE
	return danger["[next_x],[next_y]"] >= AUTOPILOT_HARM_THRESHOLD

/// Whether the next few steps of the plotted course run through anything on the
/// danger map. The destination tile itself is exempt while the crew has
/// consented to it (see autopilot_dest_consented), or a course ENDING on a
/// hazard could never read as clean and the ship would disengage a tile short.
/obj/structure/overmap/ship/proc/autopilot_course_has_danger(list/danger)
	for(var/index in 1 to min(AUTOPILOT_LOOKAHEAD, length(autopilot_path)))
		var/list/node = autopilot_path[index]
		if(autopilot_dest_consented && node[1] == autopilot_dest_x && node[2] == autopilot_dest_y)
			continue
		if(danger["[node[1]],[node[2]]"] >= AUTOPILOT_HARM_THRESHOLD)
			return TRUE
	return FALSE

// ---------------------------------------------------------------- helm readout

/**
 * Applies one flight-policy toggle from the helm. The key is client text, so
 * it maps through an explicit whitelist, never an indirect var write. Returns
 * FALSE for anything unrecognised.
 *
 * A change takes effect immediately: the danger map is dropped (its stamps
 * embody the old policy), and a course in flight is re-planned on the spot
 * rather than flown out under rules the crew has just rejected.
 */
/obj/structure/overmap/ship/proc/set_autopilot_pref(key, value)
	value = value ? TRUE : FALSE
	switch(key)
		if("crossMeteor")
			autopilot_cross_meteor = value
		if("crossElectric")
			autopilot_cross_electric = value
		if("crossEmp")
			autopilot_cross_emp = value
		if("avoidHostiles")
			autopilot_avoid_hostiles = value
		if("zoneCaution")
			autopilot_zone_caution = value
		if("hazardLanding")
			autopilot_hazard_landing = value
		else
			return FALSE
	autopilot_danger_cache = null
	if(autopilot_engaged)
		// Consent is normally settled at engage time; re-derive it so flipping
		// hazard landing mid-course honestly applies to the course being flown.
		autopilot_dest_consented = !!autopilot_dock_ref || autopilot_hazard_landing
		// No course means autopilot_course_needs_replan() answers FORCED, so the
		// next steer adopts a fresh plan under the new policy unconditionally.
		autopilot_path = null
		autopilot_steer()
	return TRUE

/// The autopilot block the helm draws: state, destination, and the remaining
/// course so the chart can trace the plotted line in relative coordinates.
/obj/structure/overmap/ship/proc/get_autopilot_data()
	var/list/data = list(
		"engaged" = autopilot_engaged,
		"label" = autopilot_label,
		"status" = autopilot_status,
		"dockOnArrival" = !!autopilot_dock_ref,
		"path" = list(),
		// Flight policy, present engaged or idle - the settings panel has to
		// work while nothing is being flown. Keys mirror set_autopilot_pref().
		"prefs" = list(
			"crossMeteor" = autopilot_cross_meteor,
			"crossElectric" = autopilot_cross_electric,
			"crossEmp" = autopilot_cross_emp,
			"avoidHostiles" = autopilot_avoid_hostiles,
			"zoneCaution" = autopilot_zone_caution,
			"hazardLanding" = autopilot_hazard_landing,
		),
		// For the asteroid-field hint: shields soak meteor impacts, so the
		// panel can say crossing is currently covered.
		"shieldsActive" = shields_active,
	)
	if(!autopilot_engaged)
		return data

	data["destX"] = autopilot_dest_x - OVERMAP_LEFT_SIDE_COORD + 1
	data["destY"] = autopilot_dest_y - OVERMAP_SOUTH_SIDE_COORD + 1
	data["remaining"] = length(autopilot_path)
	for(var/list/node as anything in autopilot_path)
		data["path"] += list(list(
			node[1] - OVERMAP_LEFT_SIDE_COORD + 1,
			node[2] - OVERMAP_SOUTH_SIDE_COORD + 1,
		))
	return data

#undef AUTOPILOT_HAZARD_COST
#undef AUTOPILOT_HAZARD_HALO_COST
#undef AUTOPILOT_HOSTILE_COST
#undef AUTOPILOT_HOSTILE_HALO_COST
#undef AUTOPILOT_HOSTILE_CORE_RANGE
#undef AUTOPILOT_HOSTILE_HALO_RANGE
#undef AUTOPILOT_HARM_THRESHOLD
#undef AUTOPILOT_TOLERATED_COST
#undef AUTOPILOT_UNCHARTED_COST
#undef AUTOPILOT_WRAP_COST
#undef AUTOPILOT_ZONE_CAUTION_COST
#undef AUTOPILOT_MAX_EXPANSIONS
#undef AUTOPILOT_MAX_FRONTIER
#undef AUTOPILOT_REPLAN_INTERVAL
#undef AUTOPILOT_REPLAN_FLOOR
#undef AUTOPILOT_REPLAN_IMPROVEMENT
#undef AUTOPILOT_REPLAN_NONE
#undef AUTOPILOT_REPLAN_FORCED
#undef AUTOPILOT_REPLAN_PERIODIC
#undef AUTOPILOT_LOOKAHEAD
#undef AUTOPILOT_UNCHARTED_CRUISE
#undef AUTOPILOT_POLL_INTERVAL
#undef AUTOPILOT_BURN_POLL
#undef AUTOPILOT_DANGER_LIFETIME
#undef OVERMAP_PATH_LOW_X
#undef OVERMAP_PATH_HIGH_X
#undef OVERMAP_PATH_LOW_Y
#undef OVERMAP_PATH_HIGH_Y
#undef OVERMAP_PATH_SPAN_X
#undef OVERMAP_PATH_SPAN_Y
