/*
voidcrew TODO:
	SSovermap originally fired to apply the planet effects but these would be way better off just using signals

Performance Note:
	Ship mass/integrity is now tracked via event-driven delta updates instead of polling.
	See setup_mass_tracking() in ship.dm for details.
*/

#define MAX_OVERMAP_EVENT_CLUSTERS 24
#define MAX_OVERMAP_EVENTS 200
#define MAX_OVERMAP_PLACEMENT_ATTEMPTS 40

/*
 * Event placement patterns, see setup_dangers().
 *
 * "concentric" is the original behaviour: pick a random orbit ring, then fill that whole ring end
 * to end at the event's spread chance. It produced closed annulus walls of hazards, wildly uneven
 * coverage between zones (a ring either got picked or it didn't), and roughly 700-800 events.
 *
 * "zonal" gives each zone its own tile quota and spends it on compact, separated clusters, then
 * checks the finished grid is actually traversable. Far fewer events, spread evenly.
 */
#define OVERMAP_EVENT_PATTERN_CONCENTRIC "concentric"
#define OVERMAP_EVENT_PATTERN_ZONAL "zonal"

/// Fraction of a zone's tiles that may hold an event. Applied per zone, so every zone ends up
/// with the same hazard density regardless of how much area it covers. Primary tuning knob:
/// raise it if the overmap plays too empty, lower it if hazards feel unavoidable.
#define OVERMAP_EVENT_DENSITY 0.08
/// How many clusters each zone is broken into. The zone quota is split between them weighted by
/// each event type's chain_rate. Fewer, larger clusters read as distinct storm systems.
#define OVERMAP_EVENT_CLUSTERS_PER_ZONE 6
/// Tiles a new cluster tries to keep clear of any existing event, so clusters do not merge into
/// one continuous barrier.
#define OVERMAP_EVENT_CLUSTER_SPACING 4
/// Safety valve on how many sealed-off pockets the traversability pass will carve open.
#define MAX_OVERMAP_LANE_CARVES 60

SUBSYSTEM_DEF(overmap)
	name = "Overmap"
	wait = 10 // Fires every 1 second (10 deciseconds)
	init_order = INIT_ORDER_OVERMAP // NOTE: dead - the MC overwrites init_order from the dependency graph (see Master/Initialize)
	flags = NONE
	// LOBBY is in here so the subsystem is already ticking - the worldgen watchdog and
	// ship bookkeeping below - while the lobby is up and roundstart hulls are loading.
	runlevels = RUNLEVEL_LOBBY | RUNLEVEL_SETUP | RUNLEVEL_GAME
	// Init ordering is purely dependency-topological now. With only mapping declared,
	// the MC initialized SSovermap BEFORE SSatoms/SSair/SSlighting, so spawn_initial_ship()
	// (plus the space ruin / trader outpost loads) placed a whole hull whose atoms were
	// still uninitialized, then action_load() immediately shuttle-moved it to transit:
	// ~350 runtimes on every boot (null turf air -> null.copy_from()/remove_ratio(),
	// null atmospherics node lists in lateShuttleMove, doubled lighting objects).
	// These dependencies push our init after the world is actually ready to load ships,
	// making the roundstart hull load identical to the proven mid-round purchase path.
	dependencies = list(
		/datum/controller/subsystem/mapping,
		/datum/controller/subsystem/atoms, // template loads must initialize their atoms (initTemplateBounds no-ops pre-SSatoms)
		/datum/controller/subsystem/air, // hull turfs need real gas mixtures before the transit move copies air around
		/datum/controller/subsystem/lighting, // otherwise SSlighting's whole-map sweep double-builds every hull lighting object
		/datum/controller/subsystem/shuttle, // create_ship()/action_load() run during our Initialize
	)

	/// Centre of the overmap
	var/turf/overmap_centre
	/// Map of tiles at each radius around the sun
	var/list/turf/radius_tiles = list()
	/// List of all events
	var/list/events = list()

	var/size = OVERMAP_SIZE
	/// Which pattern setup_dangers() places events with. Set to OVERMAP_EVENT_PATTERN_CONCENTRIC
	/// to restore the old whole-ring fill.
	var/overmap_event_pattern = OVERMAP_EVENT_PATTERN_ZONAL
	//List of all mapzones
	var/list/map_zones = list()
	///List of all simulated ships
	var/list/simulated_ships = list()
	/// world.time of the next derelict occupancy sweep - see sweep_derelicts()
	var/next_derelict_sweep = 0
	/// List of NPC ships that need mass recalculated (damaged ships)
	/// Used for performance - NPC ships cache mass and only recalc when damaged
	var/list/dirty_npc_ships = list()
	/// Timer ID of the timer used for telling which stage of an endround "jump" the ships are in
	var/jump_timer
	/// Current state of the jump
	var/jump_mode = BS_JUMP_IDLE
	/// Time taken for bluespace jump to begin after it is requested (in deciseconds)
	var/jump_request_time = 6000
	/// Time taken for a bluespace jump to complete after it initiates (in deciseconds)
	var/jump_completion_time = 1200

	/// Ready players each roundstart hull is expected to carry. The fleet scales off
	/// this once turnout is known - see SSticker.create_characters().
	var/roundstart_crew_per_ship = 6
	/// Hard ceiling on roundstart hulls, however big the turnout is.
	var/roundstart_max_ships = 4
	/// The first roundstart ship spawned. Kept for backward compatibility.
	var/obj/structure/overmap/ship/initial_ship
	/// All ships spawned at round start.
	var/list/obj/structure/overmap/ship/initial_ships = list()
	/// Hull types the roundstart fleet has already rolled, so a second hull is a different class
	var/list/spent_roundstart_hulls = list()
	/// DEV SWITCH - set to FALSE to skip planets entirely: no overmap contacts, no terrain
	/// generation, and no lobby hold waiting for it. For local iteration on things that
	/// aren't planets; planet missions simply stop being offered. Turn it back on before
	/// committing. (Preloaded planets are separate - those are the *_planet_count vars in
	/// voidcrew/mapping/_mapping.dm, already 0.)
	var/spawn_planets = TRUE
	/// How many planets of each terrain type the round gets. Every one of them is a charted
	/// contact with no interior until a ship actually goes there, so raising this adds
	/// places to go without adding anything to the round-start wait.
	var/dynamic_planets_per_type = 2

/datum/controller/subsystem/overmap/Initialize(start_timeofday)
	create_map()
	setup_sun()
	setup_dangers()
	setup_planets()
	setup_space_ruins()
	setup_trader_outposts()
	schedule_vestige_ruins()
	schedule_contested_caches()
	schedule_lich_lair()
	spawn_initial_ship()

	return SS_INIT_SUCCESS

/**
 * Called every tick (1 second) - cleanup only
 * Ship integrity is now tracked via event-driven delta updates (see ship.dm setup_mass_tracking)
 * This polling loop has been removed for ~750x performance improvement
 */
/datum/controller/subsystem/overmap/fire(resumed)
	// Clean up deleted ships from the list
	for(var/obj/structure/overmap/ship/ship as anything in simulated_ships)
		if(QDELETED(ship))
			simulated_ships -= ship
			continue
		// A dock, undock or approach whose callback chain was lost leaves the ship pinned in
		// a state that greys out every helm control, with nothing else in the game able to
		// clear it. Polled rather than timer-armed on purpose - see check_manoeuvre_stalled().
		ship.check_manoeuvre_stalled()

	// Derelict lifecycle: crewless hulls abandon, abandoned hulls eventually despawn.
	// Gated on the round actually running - this subsystem also fires through the lobby,
	// and a long lobby must not run the crewless clock against roundstart hulls nobody
	// has been able to board yet.
	if(SSticker.IsRoundInProgress() && world.time >= next_derelict_sweep)
		next_derelict_sweep = world.time + DERELICT_SWEEP_INTERVAL
		sweep_derelicts()

	// A build or teardown that runtimed partway through never released the worldgen
	// queue, and everything waiting on it would sit there for the rest of the round.
	worldgen_watchdog()

/**
 * Once-a-minute derelict bookkeeping over the whole fleet. Occupancy is the only
 * signal: living, connected players physically aboard (get_event_crew()). Three clocks
 * run off it, the first independent of the other two:
 *
 * 0. A hull berthed at a dynamic encounter with nobody alive at the site - not aboard,
 *    not anywhere on the site's own z-levels - is force-undocked after
 *    SHIP_SITE_DEAD_UNDOCK_TIME. It holds a berth flag and sits in the site's contents
 *    for as long as it stays, and a dead crew never undocks, so an encounter's map zone
 *    (often a whole z-level) used to stay pinned until the hull itself despawned an hour
 *    and a half later. The hull is not otherwise touched; the two clocks below carry on
 *    against it in open space.
 *
 * 1. A hull with nobody aboard for SHIP_CREWLESS_ABANDON_TIME is abandoned - the
 *    claimable-derelict state. This is the trigger crew death alone never provided:
 *    a crew that logs off, cryos out or walks away is an abandoned ship too, and
 *    deliberately there are no carve-outs for crews that are planetside, dead or
 *    logged off. Getting the ship back afterwards is one claim at the helm. A hull
 *    that never carried a crew at all (roundstart spares, latejoin free hulls nobody
 *    took) skips the derelict window - there is nothing aboard worth exploring and
 *    no claim to honour.
 * 2. An abandoned hull older than SHIP_DERELICT_DESPAWN_TIME despawns for good via
 *    despawn_derelict(). Anyone physically aboard postpones that; claiming cancels it.
 *
 * At most one hull despawns per sweep: teardown is the expensive part (HardDelete
 * has been measured at 600+ ms per call late in a long round), and the sweep comes
 * back in a minute anyway.
 *
 * Live NPC ships are exempt from clock 1 - their crews are NPCs, so player occupancy
 * says nothing about them and their own crew-death tracking drives abandonment. Once
 * abandoned, claimed by players, or destroyed they are subject to the same rules as any
 * hull, which is what finally stops every killed pirate leaving a permanent wreck.
 */
/datum/controller/subsystem/overmap/proc/sweep_derelicts()
	var/despawned_one = FALSE
	// Copy: despawn_derelict() qdels the hull, whose Destroy() takes it out of
	// simulated_ships, and removing the current entry mid-iteration shifts the list and
	// skips the next ship for this pass.
	for(var/obj/structure/overmap/ship/ship as anything in simulated_ships.Copy())
		if(QDELETED(ship))
			continue
		if(length(ship.get_event_crew()))
			ship.crewless_since = 0
			ship.site_dead_since = 0
			ship.site_dead_undock_refused = FALSE
			continue
		// Clock 0, and the only one that runs on a hull nobody has given up on yet: a
		// crewless hull berthed at a dynamic encounter with nothing alive on the site
		// either is force-undocked back into open space, so the encounter can tear its
		// interior down instead of waiting out the two clocks below. See
		// check_dead_site_undock() - it does its own docked/site-type filtering, and
		// only reaches a player scan for hulls that are actually berthed somewhere.
		ship.check_dead_site_undock()
		if(!ship.crewless_since)
			ship.crewless_since = world.time
			continue
		if(ship.abandoned)
			if(!ship.abandoned_at) // flagged before this clock existed - start it now
				ship.abandoned_at = world.time
				continue
			if(despawned_one || world.time - ship.abandoned_at < SHIP_DERELICT_DESPAWN_TIME)
				continue
			despawned_one = ship.despawn_derelict()
			continue
		var/obj/structure/overmap/ship/npc/npc_ship
		if(istype(ship, /obj/structure/overmap/ship/npc))
			npc_ship = ship
		// A live NPC hull is exempt from the crewless clock: its crew are NPCs, so player
		// occupancy says nothing about it, and its own crew-death tracking drives
		// abandonment. A DESTROYED one is not. Losing its hull docks a pirate into a
		// crash site it mints on the spot (make_crash_site), and that site is a fresh map
		// zone and often a fresh z-level; with the exemption unconditional, any wreck
		// nobody boarded to finish off held both for the rest of the round. Let it take
		// the ordinary clocks instead. Nothing here touches the pirate pool - the slot
		// still resolves on crew wipe, on the key, at abandon_ship(), or from Destroy().
		if(npc_ship && !npc_ship.player_controlled && npc_ship.integrity_state != SHIP_INTEGRITY_DISABLED)
			continue
		if(world.time - ship.crewless_since < SHIP_CREWLESS_ABANDON_TIME)
			continue
		// crew_ever_spawned keeps a wreck out of the never-crewed fast path: an NPC hull
		// carries no manifest and no ship_team, but it is emphatically crewed, and its
		// wreck is loot and a claimable hull. It gets the full derelict window like any
		// other ship that had people on it.
		if(!length(ship.manifest) && !LAZYLEN(ship.ship_team?.members) && !npc_ship?.crew_ever_spawned)
			// Never crewed: straight to despawn, no derelict window
			if(!despawned_one)
				log_shuttle("[ship.name]: never crewed and empty for [(world.time - ship.crewless_since) / 600] minutes - despawning without a derelict window.")
				despawned_one = ship.despawn_derelict()
			continue
		log_shuttle("[ship.name]: no crew aboard for [(world.time - ship.crewless_since) / 600] minutes - abandoning.")
		ship.abandon_ship(crash = TRUE) // only actually crashes a hull that is in flight

/**
 * How much queued lighting work is still outstanding for `wait_footprint`, or for the
 * whole world when it is null.
 *
 * Two things this counts that the obvious version does not:
 *
 * 1. `SSlighting.current_sources`. Every non-resumed fire moves the WHOLE of
 *    sources_queue into current_sources and leaves sources_queue empty behind it
 *    (see /datum/controller/subsystem/lighting/fire), so a backlog that is actively
 *    being chewed through lives there, not in the queue. Watching only the queue reads
 *    "settled" in the middle of a drain.
 * 2. The footprint. The queues are global. A packed z-level carries up to four tenants,
 *    and the rest of the world - ships under way, a lit mob walking around a trader
 *    outpost, weather - feeds them continuously. Counting all of that made the caller
 *    below wait on the entire server going quiet, which on a live round never happens.
 */
/datum/controller/subsystem/overmap/proc/lighting_backlog_for(datum/map_footprint/wait_footprint)
	if(isnull(wait_footprint) || !wait_footprint.z_value || isnull(wait_footprint.low_x))
		return length(SSlighting.sources_queue) + length(SSlighting.current_sources) + length(SSlighting.corners_queue) + length(SSlighting.objects_queue)

	var/low_x = wait_footprint.low_x
	var/low_y = wait_footprint.low_y
	var/high_x = wait_footprint.high_x
	var/high_y = wait_footprint.high_y
	var/z_value = wait_footprint.z_value
	var/backlog = 0

	for(var/list/source_list as anything in list(SSlighting.sources_queue, SSlighting.current_sources))
		for(var/datum/light_source/source as anything in source_list)
			var/turf/source_turf = source.source_turf
			if(!isturf(source_turf) || source_turf.z != z_value)
				continue
			if(source_turf.x < low_x || source_turf.x > high_x || source_turf.y < low_y || source_turf.y > high_y)
				continue
			backlog++

	// A corner's own x/y are the VERTEX, half a tile up and right of the turf that owns it
	// as its NE, so the rect it can legitimately belong to runs half a tile past both
	// high edges. Compared loosely rather than exactly - one tile of slop on the boundary
	// costs nothing and getting it wrong strands the wait.
	for(var/datum/lighting_corner/corner as anything in SSlighting.corners_queue)
		if(corner.z != z_value)
			continue
		if(corner.x < low_x - 1 || corner.x > high_x + 1 || corner.y < low_y - 1 || corner.y > high_y + 1)
			continue
		backlog++

	for(var/datum/lighting_object/lighting_object as anything in SSlighting.objects_queue)
		var/turf/affected_turf = lighting_object.affected_turf
		if(!isturf(affected_turf) || affected_turf.z != z_value)
			continue
		if(affected_turf.x < low_x || affected_turf.x > high_x || affected_turf.y < low_y || affected_turf.y > high_y)
			continue
		backlog++

	return backlog

/// TRUE when `checked` lies inside `wait_footprint`. A null footprint means the whole
/// world, matching lighting_backlog_for(). Deliberately NOT used by that proc, which
/// inlines the same test - it runs over the whole queue once a second, and this one only
/// ever runs when something has already gone wrong.
/datum/controller/subsystem/overmap/proc/footprint_holds_turf(datum/map_footprint/wait_footprint, turf/checked)
	if(isnull(wait_footprint) || !wait_footprint.z_value || isnull(wait_footprint.low_x))
		return TRUE
	if(!isturf(checked) || checked.z != wait_footprint.z_value)
		return FALSE
	return checked.x >= wait_footprint.low_x && checked.x <= wait_footprint.high_x && checked.y >= wait_footprint.low_y && checked.y <= wait_footprint.high_y

/**
 * Names what is still sitting in the lighting queues for `wait_footprint`, as a one-line
 * "3x /obj/thing @(61,190)" summary.
 *
 * This exists because "the lighting never settles" is not actionable and "the lighting
 * never settles because eight /obj/structure/spawner/ice_moon/demonic_portal keep
 * re-queueing" is. Only ever called off the settle wait's failure paths, so it may be as
 * slow and as allocating as it likes.
 */
/datum/controller/subsystem/overmap/proc/lighting_backlog_report(datum/map_footprint/wait_footprint, max_entries = 8)
	var/list/tally = list()
	var/list/example_coords = list()

	for(var/datum/light_source/source as anything in (SSlighting.sources_queue + SSlighting.current_sources))
		var/turf/source_turf = source.source_turf
		if(!footprint_holds_turf(wait_footprint, source_turf))
			continue
		var/atom/source_atom = source.source_atom
		// The OWNER, not the turf under it: a lantern on a wandering mob and a self-lit
		// lava tile are the same "source on this turf" and completely different problems.
		var/label = "source [source_atom ? source_atom.type : "<none>"]"
		tally[label] = (tally[label] || 0) + 1
		example_coords[label] ||= "([source_turf.x],[source_turf.y])"

	for(var/datum/lighting_corner/corner as anything in SSlighting.corners_queue)
		if(!isnull(wait_footprint) && wait_footprint.z_value)
			if(corner.z != wait_footprint.z_value)
				continue
			if(corner.x < wait_footprint.low_x - 1 || corner.x > wait_footprint.high_x + 1 || corner.y < wait_footprint.low_y - 1 || corner.y > wait_footprint.high_y + 1)
				continue
		var/label = "corner ([LAZYLEN(corner.affecting)] affecting)"
		tally[label] = (tally[label] || 0) + 1
		example_coords[label] ||= "([corner.x],[corner.y])"

	for(var/datum/lighting_object/lighting_object as anything in SSlighting.objects_queue)
		var/turf/affected_turf = lighting_object.affected_turf
		if(!footprint_holds_turf(wait_footprint, affected_turf))
			continue
		var/label = "object [affected_turf ? affected_turf.type : "<none>"]"
		tally[label] = (tally[label] || 0) + 1
		example_coords[label] ||= "([affected_turf.x],[affected_turf.y])"

	if(!length(tally))
		return "nothing pending on the footprint"

	sortTim(tally, GLOBAL_PROC_REF(cmp_numeric_dsc), associative = TRUE)
	var/list/lines = list()
	for(var/label in tally)
		lines += "[tally[label]]x [label] @[example_coords[label]]"
		if(length(lines) >= max_entries)
			break
	return lines.Join(", ")

/**
 * Sleeps until the lighting work for `wait_footprint` has drained, so a crew docking onto
 * a freshly built planet lands on a rendered surface instead of a black one.
 *
 * Returns when EITHER of two things is true:
 *
 * - the footprint's backlog is empty on two consecutive samples (it finished), or
 * - the backlog has failed to reach a new low for LIGHTING_SETTLE_PLATEAU_SAMPLES
 *   samples (it is not finishing).
 *
 * The second exit is the important one and it is not a fudge. "Wait for zero" only
 * terminates if the thing being watched is a finite backlog draining to nothing. A live
 * planet is not: a demonic portal's light, a lit mob wandering the surface, a storm
 * overhead all feed the queues forever, and a wait that insists on zero simply burns its
 * whole cap every time. Measured 2026-08-21: every ice planet in round 1068 sat out the
 * full 90 seconds and then logged sources=3 - three sources, not a backlog. What we
 * actually want to know is "has the initial render stopped making progress", and a
 * backlog that has stopped shrinking answers exactly that.
 *
 * Capped regardless, so a wedged queue can't hold the round hostage.
 */
/datum/controller/subsystem/overmap/proc/wait_for_lighting_settle(cap = 5 MINUTES, datum/map_footprint/wait_footprint)
	var/started = world.time
	var/consecutive_empty = 0
	var/lowest_backlog = INFINITY
	var/samples_without_progress = 0
	while(world.time < started + cap)
		var/backlog = lighting_backlog_for(wait_footprint)
		if(!backlog)
			consecutive_empty++
			if(consecutive_empty >= LIGHTING_SETTLE_EMPTY_SAMPLES)
				return TRUE
		else
			consecutive_empty = 0
			if(backlog < lowest_backlog)
				lowest_backlog = backlog
				samples_without_progress = 0
			else
				samples_without_progress++
				if(samples_without_progress >= LIGHTING_SETTLE_PLATEAU_SAMPLES)
					log_mapping("SSovermap: lighting settle plateaued at [backlog] pending after [(world.time - started) / 10]s, releasing. Pending: [lighting_backlog_report(wait_footprint)]")
					return TRUE
		sleep(LIGHTING_SETTLE_POLL)
	log_mapping("SSovermap: lighting settle wait hit its [cap / 600] minute cap (scoped=[lighting_backlog_for(wait_footprint)] global sources=[length(SSlighting.sources_queue)] current=[length(SSlighting.current_sources)] corners=[length(SSlighting.corners_queue)] objects=[length(SSlighting.objects_queue)]). Pending: [lighting_backlog_report(wait_footprint)]")
	return FALSE

/*
 * Bluespace jump procs
 */

/**
 * ## request_jump
 *
 * Requests a bluespace jump, which, after jump_request_time deciseconds, will initiate a bluespace jump.
 *
 * Arguments:
 * * modifiers - (Optional) Modifies the length of the jump request time (defaults to 1)
 */
/datum/controller/subsystem/overmap/proc/request_jump(modifier = 1)
	jump_mode = BS_JUMP_CALLED
	jump_timer = addtimer(CALLBACK(src, PROC_REF(initiate_jump)), jump_request_time * modifier, TIMER_STOPPABLE)
	priority_announce("Preparing for jump. ETD: [jump_request_time * modifier / 600] minutes.", null, null, "Priority")

/**
 * ##cancel_jump
 *
 * Cancels a currently requested bluespace jump.
 * Can only be done after the jump has been requested, but before the jump has actually begun.
 */
/datum/controller/subsystem/overmap/proc/cancel_jump()
	if(jump_mode != BS_JUMP_CALLED)
		return
	deltimer(jump_timer)
	jump_mode = BS_JUMP_IDLE
	priority_announce("Bluespace jump cancelled.", null, null, "Priority")

/**
 * ##initiate_jump
 *
 * Initiates a bluespace jump, ending the round after a delay of jump_completion_time deciseconds.
 * This cannot be interrupted by conventional means.
 */
/datum/controller/subsystem/overmap/proc/initiate_jump()
	jump_mode = BS_JUMP_INITIATED
	for(var/obj/docking_port/mobile/voidcrew/mobile_port as anything in SSshuttle.mobile_docking_ports)
		mobile_port.hyperspace_sound(HYPERSPACE_WARMUP, mobile_port.shuttle_areas)
		mobile_port.on_emergency_launch()

	priority_announce("Jump initiated. ETA: [jump_completion_time / 600] minutes.", null, null, "Priority")
	jump_timer = addtimer(VARSET_CALLBACK(src, jump_mode, BS_JUMP_COMPLETED), jump_completion_time)

/datum/controller/subsystem/overmap/proc/create_map()
	// creates the overmap area and sets it up
	var/area/overmap/overmap_area = new
	overmap_area.setup("Overmap")

	// locates the area we want the overmap to be
	var/turf/top_left = locate(OVERMAP_LEFT_SIDE_COORD, OVERMAP_NORTH_SIDE_COORD, OVERMAP_Z_LEVEL)
	var/turf/bottom_right = locate(OVERMAP_RIGHT_SIDE_COORD, OVERMAP_SOUTH_SIDE_COORD, OVERMAP_Z_LEVEL)
	var/list/overmap_turfs = block(top_left, bottom_right)
	for (var/turf/overmap_turf as anything in overmap_turfs)
		if (overmap_turf.x == OVERMAP_LEFT_SIDE_COORD || overmap_turf.x == OVERMAP_RIGHT_SIDE_COORD || overmap_turf.y == OVERMAP_NORTH_SIDE_COORD || overmap_turf.y == OVERMAP_SOUTH_SIDE_COORD)
			overmap_turf.ChangeTurf(/turf/closed/overmap_edge)
		else
			overmap_turf.ChangeTurf(/turf/open/overmap)
		var/area/old_area = get_area(overmap_turf)
		LISTASSERTLEN(old_area.turfs_to_uncontain_by_zlevel, overmap_turf.z, list())
		LISTASSERTLEN(overmap_area.turfs_by_zlevel, overmap_turf.z, list())
		old_area.turfs_to_uncontain_by_zlevel[overmap_turf.z] += overmap_turf
		overmap_area.turfs_by_zlevel[overmap_turf.z] += overmap_turf
		overmap_area.contents += overmap_turf
	overmap_area.reg_in_areas_in_z()
	// not actually the centre but close enough
	overmap_centre = get_turf(locate((OVERMAP_LEFT_SIDE_COORD + ((OVERMAP_SIZE - 1) / 2)) - 1, (OVERMAP_SOUTH_SIDE_COORD + ((OVERMAP_SIZE - 1) / 2)) - 1, OVERMAP_Z_LEVEL))

	relocate_lobby()

/**
 * Moves the pre-round lobby off the live overmap.
 *
 * The tg lobby anchor (the new_player landmark in CentCom.dmm, /area/misc/start) sits
 * in the top-left corner of the centcom z - the exact block create_map() just turned
 * into the live overmap. Left alone, everyone in the lobby is parked ON an overmap
 * tile and can watch real ships and planets drift past the title menu before they
 * have even joined the round, which players were openly using to metagame (scouting
 * planets and ship positions from the lobby).
 *
 * So: strip every lobby spawn point that falls inside the overmap block, park the
 * lobby over an empty corner of the same z far outside it, and sweep any player who
 * already spawned onto the old spot. The lobby keeps its overmap look through a
 * static starfield backdrop on the lobby HUD instead
 * (/atom/movable/screen/lobby/starfield, voidcrew/edits/mobs/new_player.dm).
 */
/datum/controller/subsystem/overmap/proc/relocate_lobby()
	// Far top-right corner of the centcom z: empty space in CentCom.dmm, and nothing
	// is ever runtime-spawned there (ships, hangars and planets all load into
	// reserved z-levels; the overmap block is the only thing built onto this z).
	var/turf/safe_lobby_turf = locate(max(world.maxx - 16, OVERMAP_RIGHT_SIDE_COORD + 10), world.maxy - 16, OVERMAP_Z_LEVEL)
	if(isnull(safe_lobby_turf) || is_turf_in_overmap_block(safe_lobby_turf))
		stack_trace("relocate_lobby() could not find a turf outside the overmap block - lobby players can see the live overmap!")
		return

	var/list/sanitized_starts = list()
	for(var/atom/start_loc as anything in GLOB.newplayer_start)
		var/turf/start_turf = get_turf(start_loc)
		if(start_turf && is_turf_in_overmap_block(start_turf))
			continue
		sanitized_starts += start_loc
	if(!length(sanitized_starts))
		sanitized_starts += safe_lobby_turf
	GLOB.newplayer_start = sanitized_starts

	// Anyone who connected before this ran was spawned onto the old landmark
	for(var/mob/dead/new_player/lobby_player as anything in GLOB.new_player_list)
		var/turf/player_turf = get_turf(lobby_player)
		if(player_turf && is_turf_in_overmap_block(player_turf))
			lobby_player.forceMove(pick(GLOB.newplayer_start))

/// Whether this turf lies inside the overmap's block on the centcom z (edge included).
/datum/controller/subsystem/overmap/proc/is_turf_in_overmap_block(turf/checked_turf)
	if(checked_turf.z != OVERMAP_Z_LEVEL)
		return FALSE
	return checked_turf.x >= OVERMAP_LEFT_SIDE_COORD && checked_turf.x <= OVERMAP_RIGHT_SIDE_COORD && checked_turf.y >= OVERMAP_SOUTH_SIDE_COORD && checked_turf.y <= OVERMAP_NORTH_SIDE_COORD

/datum/controller/subsystem/overmap/proc/setup_sun()
	var/turf/open/overmap/centre_tile = overmap_centre
	if(!istype(centre_tile))
		can_fire = FALSE
		message_admins("Overmap failed to generate the map, this is a critical error.")
		CRASH("Overmap did not generate correctly!")

	// Instantiate the PICKED type - a bare `new` here builds the declared type instead
	// and the binary system could never roll
	var/star_to_spawn_type = pick(/obj/structure/overmap/star/big, /obj/structure/overmap/star/big/binary)
	var/obj/structure/overmap/star/big/star_to_spawn = new star_to_spawn_type
	star_to_spawn.forceMove(centre_tile)

	var/list/unsorted_turfs = get_area_turfs(/area/overmap, target_z = OVERMAP_Z_LEVEL)
	var/max_ring = 0
	for (var/turf/turf as anything in unsorted_turfs)
		if (istype(turf, /turf/closed/overmap_edge))
			continue
		// the overmap is a square, so we can just use the x and y values to determine the actual ring
		// 2 2 2 2 2
		// 2 1 1 1 2
		// 2 1 X 1 2
		// 2 1 1 1 2
		// 2 2 2 2 2
		var/ring_x = turf.x - (overmap_centre.x + 1)
		var/ring_y = turf.y - (overmap_centre.y + 1)
		var/ring = max(abs(ring_x), abs(ring_y))
		if (!ring)
			continue
		if (ring > max_ring)
			for (var/i in 1 to ring - max_ring)
				radius_tiles += list(list())
			max_ring = ring
		LAZYADDASSOC(radius_tiles, ring, turf)

/datum/controller/subsystem/overmap/proc/get_unused_overmap_square(thing_not_to_have = /obj/structure/overmap, tries = MAX_OVERMAP_PLACEMENT_ATTEMPTS, force = FALSE)
	var/turf/turf_to_return
	for (var/_ in 1 to tries)
		turf_to_return = pick(block(locate(OVERMAP_LEFT_SIDE_COORD + 1, OVERMAP_SOUTH_SIDE_COORD + 1, OVERMAP_Z_LEVEL), locate(OVERMAP_RIGHT_SIDE_COORD - 1, OVERMAP_NORTH_SIDE_COORD - 1, OVERMAP_Z_LEVEL))) // todo : see if this is expensive
		if (locate(thing_not_to_have) in turf_to_return)
			continue
		return turf_to_return
	if (!force)
		turf_to_return = null
	return turf_to_return

/**
 * Returns TRUE if the given turf is in the green zone (outer ring)
 * Checks the turf's current_zone if zones are initialized, otherwise calculates from distance
 */
/datum/controller/subsystem/overmap/proc/is_turf_in_green_zone(turf/open/overmap/T)
	if(!T || !overmap_centre)
		return FALSE
	// Use current_zone if zones have been initialized
	if(T.current_zone)
		return T.current_zone.zone_type == ZONE_GREEN
	// Fallback to distance calculation (for spawning before zones init)
	var/max_radius = (OVERMAP_SIZE - 1) / 2
	var/dx = T.x - overmap_centre.x
	var/dy = T.y - overmap_centre.y
	var/distance = sqrt(dx * dx + dy * dy)
	var/normalized = distance / max_radius
	return normalized >= 0.66

/**
 * Gets an unused overmap square specifically in the green zone (outer ring)
 * Ships spawn here to ensure they start in the safe zone
 */
/datum/controller/subsystem/overmap/proc/get_unused_overmap_square_in_green_zone(thing_not_to_have = /obj/structure/overmap, tries = MAX_OVERMAP_PLACEMENT_ATTEMPTS, force = FALSE)
	var/turf/turf_to_return
	for (var/_ in 1 to tries)
		turf_to_return = pick(block(locate(OVERMAP_LEFT_SIDE_COORD + 1, OVERMAP_SOUTH_SIDE_COORD + 1, OVERMAP_Z_LEVEL), locate(OVERMAP_RIGHT_SIDE_COORD - 1, OVERMAP_NORTH_SIDE_COORD - 1, OVERMAP_Z_LEVEL)))
		if (locate(thing_not_to_have) in turf_to_return)
			continue
		if (!is_turf_in_green_zone(turf_to_return))
			continue
		return turf_to_return
	if (!force)
		turf_to_return = null
	return turf_to_return

/datum/controller/subsystem/overmap/proc/get_unused_overmap_square_in_radius(radius, thing_not_to_have = /obj/structure/overmap, tries = MAX_OVERMAP_PLACEMENT_ATTEMPTS, force = FALSE)
	if (!radius)
		radius = rand(2, length(radius_tiles) / 2)

	var/turf/turf_to_return
	for (var/_ in 1 to tries)
		turf_to_return = pick(radius_tiles[radius])
		if (locate(thing_not_to_have) in turf_to_return)
			continue
		return turf_to_return

	if (!force)
		turf_to_return = null
	return turf_to_return


/**
 * Places every roundstart overmap event.
 *
 * See the OVERMAP_EVENT_PATTERN_* defines at the top of this file for what the two patterns do.
 */
/datum/controller/subsystem/overmap/proc/setup_dangers()
	if(overmap_event_pattern == OVERMAP_EVENT_PATTERN_CONCENTRIC)
		setup_dangers_concentric()
		return
	setup_dangers_zonal()

/**
 * Zone-quota event placement.
 *
 * Every zone gets a share of the map's event budget proportional to its size, so the hazard
 * density a crew flies through is the same wherever they are, and no zone can come up empty
 * because one global roll happened to land somewhere else. Each zone's share is then spent on a
 * fixed number of compact clusters - one of each guaranteed family plus weighted picks - rather
 * than smeared across a whole orbit ring.
 *
 * Once everything is down, carve_traversal_lanes() makes sure the result is still flyable, and the
 * MIN_OVERMAP_ASTEROID_FIELDS mining guarantee is topped up exactly as the concentric path does it.
 */
/datum/controller/subsystem/overmap/proc/setup_dangers_zonal()
	var/list/all_turfs = get_area_turfs(/area/overmap, target_z = OVERMAP_Z_LEVEL)
	// Indexed by zone type. ZONE_GREEN/YELLOW/RED are 1/2/3, so a plain three-slot list works and
	// sidesteps DM's number-key-vs-index ambiguity on associative lists.
	var/list/zone_pools = list(list(), list(), list())
	// turf -> zone type, kept around for the traversability pass.
	var/list/zone_of = list()
	var/list/navigable = list()

	for(var/turf/open/overmap/tile as anything in all_turfs)
		if(!istype(tile))
			continue
		// SSovermap_zones has not initialized yet, so this is the band formula, same as
		// everything else placed from here (planets, outposts, nebula gas tables).
		var/zone_type = get_zone_band_for_turf(tile)
		zone_of[tile] = zone_type
		navigable += tile
		// The sun (and anything else already placed) is not up for grabs.
		if(locate(/obj/structure/overmap) in tile)
			continue
		var/list/pool = zone_pools[zone_type]
		pool[tile] = TRUE

	if(!length(navigable))
		return

	var/total_spawned = 0
	for(var/zone_type in list(ZONE_GREEN, ZONE_YELLOW, ZONE_RED))
		var/list/zone_pool = zone_pools[zone_type]
		if(!length(zone_pool))
			continue
		var/quota = min(round(length(zone_pool) * OVERMAP_EVENT_DENSITY), MAX_OVERMAP_EVENTS - total_spawned)
		if(quota <= 0)
			continue
		total_spawned += populate_zone_with_events(zone_pool, quota)

	// Placement is random, so it can still seal a pocket shut. Carve it back open, relocating what
	// we pull out where we can. The second pass has relocation off, so it is guaranteed to finish
	// with a connected map even if a relocated event landed somewhere awkward.
	var/carved = carve_traversal_lanes(navigable, zone_of, relocate = TRUE)
	carved += carve_traversal_lanes(navigable, zone_of, relocate = FALSE)

	// Same mining guarantee the concentric path carries: every meteor tile is a landable asteroid
	// field, and space mining has to be a dependable loop rather than a lucky roll. Every zone is
	// guaranteed a meteor cluster above, so this only ever fires if the map had no room for them.
	var/meteor_count = length(GLOB.meteor_fields)
	while (meteor_count < MIN_OVERMAP_ASTEROID_FIELDS)
		var/turf/turf_for_field = get_unused_overmap_square()
		if (!turf_for_field)
			break
		new /obj/structure/overmap/event/meteor(turf_for_field)
		meteor_count++
		log_mapping("SSovermap: Spawned guaranteed asteroid field event")

	log_mapping("SSovermap: Placed [total_spawned] overmap events across 3 zones ([meteor_count] asteroid fields, [carved] cleared to keep the map traversable)")

/**
 * Fills one zone's tile quota with event clusters.
 *
 * Arguments:
 * * zone_pool - associative list of free turfs in this zone. Filled turfs are removed from it.
 * * quota - how many tiles of this zone may be covered.
 *
 * Returns how many event tiles were actually placed.
 */
/datum/controller/subsystem/overmap/proc/populate_zone_with_events(list/zone_pool, quota)
	var/list/cluster_types = list()
	// One cluster of each family per zone. That is what makes the zones equivalent: every band
	// gets its own asteroid field to mine, its own storms to route around, and its own nebula -
	// which matters more than it looks, since a nebula rolls its gas from its band's table.
	for(var/list/family as anything in GLOB.overmap_event_guaranteed_families)
		cluster_types += pick(family)
	while(length(cluster_types) < OVERMAP_EVENT_CLUSTERS_PER_ZONE)
		cluster_types += pick_weight(GLOB.overmap_event_pick_list)

	// Split the quota between the clusters in proportion to how big each event wants to be.
	var/total_weight = 0
	for(var/obj/structure/overmap/event/event_type as anything in cluster_types)
		total_weight += 1 + initial(event_type.chain_rate)
	if(total_weight <= 0)
		return 0

	var/spawned = 0
	for(var/obj/structure/overmap/event/event_type as anything in cluster_types)
		if(spawned >= quota)
			break
		var/target_size = clamp(round(quota * (1 + initial(event_type.chain_rate)) / total_weight), 1, quota - spawned)
		spawned += grow_event_cluster(zone_pool, event_type, target_size)
	return spawned

/**
 * Grows a single compact cluster of one event type out of a random anchor tile.
 *
 * The blob spreads to neighbouring tiles at the event's spread_chance, so a nebula comes out as a
 * dense round cloud while a majour electrical storm comes out ragged and scattered. It never
 * leaves the zone pool it was handed, which is what keeps the per-zone quotas honest.
 *
 * Returns how many tiles were filled - possibly fewer than asked for, if the blob ran out of room.
 */
/datum/controller/subsystem/overmap/proc/grow_event_cluster(list/zone_pool, obj/structure/overmap/event/event_type, target_size)
	if(target_size <= 0)
		return 0
	var/turf/anchor = pick_cluster_anchor(zone_pool)
	if(isnull(anchor))
		return 0

	// Events that barely spread would otherwise never be more than a single tile.
	var/spread_chance = max(initial(event_type.spread_chance), 25)

	var/list/frontier = list(anchor)
	var/list/considered = list()
	considered[anchor] = TRUE
	var/placed = 0
	// The frontier can grow as it is consumed, so bound the walk.
	var/iterations_left = target_size * 24

	while(placed < target_size && length(frontier) && iterations_left > 0)
		iterations_left--
		var/index = rand(1, length(frontier))
		var/turf/tile = frontier[index]
		frontier.Cut(index, index + 1)
		if(!zone_pool[tile] || (locate(/obj/structure/overmap) in tile))
			continue
		new event_type(tile)
		zone_pool -= tile
		placed++
		for(var/direction in GLOB.alldirs)
			var/turf/neighbour = get_step(tile, direction)
			if(isnull(neighbour) || considered[neighbour] || !zone_pool[neighbour])
				continue
			if(!prob(spread_chance))
				continue
			considered[neighbour] = TRUE
			frontier += neighbour

	return placed

/**
 * Picks somewhere to start a cluster, preferring tiles that are not already crowded by another
 * cluster. Keeping anchors apart is what stops separate clusters from fusing into a barrier.
 */
/datum/controller/subsystem/overmap/proc/pick_cluster_anchor(list/zone_pool)
	if(!length(zone_pool))
		return null
	for(var/_ in 1 to 20)
		var/turf/candidate = pick(zone_pool)
		if(!has_event_within(candidate, OVERMAP_EVENT_CLUSTER_SPACING))
			return candidate
	return pick(zone_pool)

/// Returns TRUE if any overmap event sits within `radius` tiles of `centre`.
/datum/controller/subsystem/overmap/proc/has_event_within(turf/centre, radius)
	for(var/turf/tile as anything in RANGE_TURFS(radius, centre))
		if(locate(/obj/structure/overmap/event) in tile)
			return TRUE
	return FALSE

/**
 * Returns the event that stops travel through this tile, if any.
 *
 * Deliberately matches overmap_turf_blocked(): nebulas are scenery to hide in, not an obstacle,
 * so they do not count as a wall here either.
 */
/datum/controller/subsystem/overmap/proc/get_blocking_event(turf/tile)
	for(var/obj/structure/overmap/event/found in tile)
		if(istype(found, /obj/structure/overmap/event/nebula))
			continue
		return found
	return null

/**
 * Traversability pass - makes sure no run of hazards walls part of the map off.
 *
 * Labels every connected region of hazard-free space, takes the largest one as "the map", and for
 * each region cut off from it digs the shortest possible run of hazard tiles to reconnect it. The
 * search is a 0-1 BFS: crossing open space is free, crossing a hazard costs one, so the lane it
 * finds is the thinnest part of the wall rather than an arbitrary hole.
 *
 * Arguments:
 * * navigable_turfs - every overmap tile a ship could occupy.
 * * zone_of - turf -> zone type, used to keep relocated events in their own zone.
 * * relocate - whether displaced events get a new home instead of being deleted.
 *
 * Returns how many hazard tiles had to be cleared.
 */
/datum/controller/subsystem/overmap/proc/carve_traversal_lanes(list/navigable_turfs, list/zone_of, relocate = TRUE)
	var/list/blocked = list()
	var/list/open = list()
	for(var/turf/tile as anything in navigable_turfs)
		var/obj/structure/overmap/event/blocker = get_blocking_event(tile)
		if(blocker)
			blocked[tile] = blocker
		else
			open[tile] = TRUE

	if(!length(open))
		return 0

	// Flood fill open space into regions.
	var/list/region_of = list()
	var/list/regions = list()
	for(var/turf/seed as anything in open)
		if(region_of[seed])
			continue
		var/region_id = length(regions) + 1
		var/list/region = list(seed)
		region_of[seed] = region_id
		var/cursor = 1
		while(cursor <= length(region))
			var/turf/current = region[cursor++]
			for(var/direction in GLOB.cardinals)
				var/turf/neighbour = get_step(current, direction)
				if(isnull(neighbour) || !open[neighbour] || region_of[neighbour])
					continue
				region_of[neighbour] = region_id
				region += neighbour
		regions += list(region)

	if(length(regions) <= 1)
		return 0

	// The largest region is the open space everyone is actually flying around in.
	var/main_id = 1
	for(var/i in 2 to length(regions))
		var/list/region = regions[i]
		var/list/biggest = regions[main_id]
		if(length(region) > length(biggest))
			main_id = i

	var/cleared = 0
	var/carves = 0
	for(var/i in 1 to length(regions))
		if(i == main_id)
			continue
		if(carves++ >= MAX_OVERMAP_LANE_CARVES)
			break
		var/list/lane = find_cheapest_lane(regions[i], region_of, main_id, open, blocked)
		if(!length(lane))
			continue
		for(var/turf/tile as anything in lane)
			var/obj/structure/overmap/event/displaced = blocked[tile]
			blocked -= tile
			open[tile] = TRUE
			region_of[tile] = main_id
			cleared++
			if(relocate && relocate_event(displaced, open, blocked, zone_of, lane))
				continue
			qdel(displaced)
		// The pocket now hangs off the main region, so later searches can terminate on it.
		for(var/turf/tile as anything in regions[i])
			region_of[tile] = main_id

	return cleared

/**
 * 0-1 BFS from a cut-off region to the main region. Open tiles are free to cross, hazard tiles
 * cost one each, so the first route found crosses the fewest hazards possible.
 *
 * Returns the list of hazard turfs along that route, or an empty list if there is no way through.
 */
/datum/controller/subsystem/overmap/proc/find_cheapest_lane(list/source_region, list/region_of, main_id, list/open, list/blocked)
	var/list/came_from = list()
	var/list/seen = list()
	var/list/current = list()
	for(var/turf/tile as anything in source_region)
		seen[tile] = TRUE
		current += tile

	var/list/next_layer = list()
	while(length(current))
		var/cursor = 1
		while(cursor <= length(current))
			var/turf/tile = current[cursor++]
			for(var/direction in GLOB.cardinals)
				var/turf/neighbour = get_step(tile, direction)
				if(isnull(neighbour) || seen[neighbour])
					continue
				if(open[neighbour])
					seen[neighbour] = TRUE
					came_from[neighbour] = tile
					if(region_of[neighbour] == main_id)
						return build_lane(neighbour, came_from, blocked)
					// Free move - stays in this layer.
					current += neighbour
					continue
				if(!blocked[neighbour])
					continue // Map edge, or something we have no business digging through.
				seen[neighbour] = TRUE
				came_from[neighbour] = tile
				next_layer += neighbour
		current = next_layer
		next_layer = list()

	return list()

/// Walks a find_cheapest_lane() route back to its start, collecting the hazard tiles on it.
/datum/controller/subsystem/overmap/proc/build_lane(turf/endpoint, list/came_from, list/blocked)
	var/list/lane = list()
	var/turf/cursor = endpoint
	while(cursor)
		if(blocked[cursor])
			lane += cursor
		cursor = came_from[cursor]
	return lane

/**
 * Finds a new home for an event pulled out of a travel lane, so opening a lane costs the map
 * atmosphere rather than content.
 *
 * The replacement tile has to be in the same zone (quotas stay honest), well clear of the lane we
 * just cut, and have at least three open neighbours - a tile that open can't be the chokepoint of
 * a one-wide corridor, so relocating cannot obviously seal something new.
 *
 * Returns TRUE if the event was moved, FALSE if the caller should just delete it.
 */
/datum/controller/subsystem/overmap/proc/relocate_event(obj/structure/overmap/event/displaced, list/open, list/blocked, list/zone_of, list/lane)
	if(QDELETED(displaced))
		return FALSE
	var/wanted_zone = zone_of[get_turf(displaced)]
	if(isnull(wanted_zone))
		return FALSE

	for(var/_ in 1 to MAX_OVERMAP_PLACEMENT_ATTEMPTS)
		var/turf/candidate = pick(open)
		if(!open[candidate] || blocked[candidate] || zone_of[candidate] != wanted_zone)
			continue
		if(locate(/obj/structure/overmap) in candidate)
			continue

		var/too_close = FALSE
		for(var/turf/lane_tile as anything in lane)
			if(get_dist(candidate, lane_tile) <= OVERMAP_EVENT_CLUSTER_SPACING)
				too_close = TRUE
				break
		if(too_close)
			continue

		var/open_neighbours = 0
		for(var/direction in GLOB.cardinals)
			var/turf/neighbour = get_step(candidate, direction)
			if(!isnull(neighbour) && open[neighbour])
				open_neighbours++
		if(open_neighbours < 3)
			continue

		displaced.forceMove(candidate)
		open -= candidate
		blocked[candidate] = displaced
		return TRUE

	return FALSE

/**
 * Legacy concentric event placement: pick a random orbit ring and fill the whole ring at the
 * event's spread chance. Kept behind overmap_event_pattern for comparison and rollback.
 */
/datum/controller/subsystem/overmap/proc/setup_dangers_concentric()
	var/list/orbits = list()
	for (var/i in 2 to LAZYLEN(radius_tiles))
		orbits += "[i]"

	// Tracks landable meteor storm / asteroid field events spawned below (main +
	// spread copies), so we can top up to MIN_OVERMAP_ASTEROID_FIELDS afterward.
	// This is the mining-content guarantee that used to target space ruin asteroid
	// signals (MIN_OVERMAP_ASTEROID_SIGNALS) before that category was retired.
	var/meteor_count = 0

	// Phase 1: Spawn guaranteed event types first to ensure map diversity
	var/list/guaranteed_events = GLOB.overmap_event_guaranteed_list.Copy()
	for (var/event_type in guaranteed_events)
		if (MAX_OVERMAP_EVENTS <= LAZYLEN(events))
			break
		if (LAZYLEN(orbits) == 0 || !orbits)
			break
		var/selected_orbit = text2num(pick(orbits))

		var/turf/turf_for_event = get_unused_overmap_square_in_radius(selected_orbit)
		if (!turf_for_event || !istype(turf_for_event))
			orbits -= "[selected_orbit]"
			continue
		var/obj/structure/overmap/event/event_to_spawn = new event_type(turf_for_event)
		if (istype(event_to_spawn, /obj/structure/overmap/event/meteor))
			meteor_count++
		for (var/turf/turf_to_spawn as anything in radius_tiles[selected_orbit])
			if (locate(/obj/structure/overmap) in turf_to_spawn)
				continue
			if (!prob(event_to_spawn.spread_chance))
				continue
			var/obj/structure/overmap/event/spread_event = new event_type(turf_to_spawn)
			if (istype(spread_event, /obj/structure/overmap/event/meteor))
				meteor_count++

	// Phase 2: Fill remaining clusters with weighted random picks
	var/clusters_spawned = length(GLOB.overmap_event_guaranteed_list)
	for (var/_ in clusters_spawned to MAX_OVERMAP_EVENT_CLUSTERS)
		if (MAX_OVERMAP_EVENTS <= LAZYLEN(events))
			return
		if (LAZYLEN(orbits) == 0 || !orbits)
			break // can't fit anymore in
		var/selected_orbit = text2num(pick(orbits))

		var/turf/turf_for_event = get_unused_overmap_square_in_radius(selected_orbit)
		if (!turf_for_event || !istype(turf_for_event))
			orbits -= "[selected_orbit]" // this one is full
			continue
		var/event_type = pick_weight(GLOB.overmap_event_pick_list)
		var/obj/structure/overmap/event/event_to_spawn = new event_type(turf_for_event)
		if (istype(event_to_spawn, /obj/structure/overmap/event/meteor))
			meteor_count++
		for (var/turf/turf_to_spawn as anything in radius_tiles[selected_orbit])
			if (locate(/obj/structure/overmap) in turf_to_spawn)
				continue
			if (!prob(event_to_spawn.spread_chance))
				continue
			var/obj/structure/overmap/event/spread_event = new event_type(turf_to_spawn)
			if (istype(spread_event, /obj/structure/overmap/event/meteor))
				meteor_count++

	// Guarantee a minimum number of landable asteroid field events per round, so space
	// mining is a dependable resource loop rather than a lucky roll of the weighted picker
	while (meteor_count < MIN_OVERMAP_ASTEROID_FIELDS)
		var/turf/turf_for_field = get_unused_overmap_square()
		if (!turf_for_field)
			break
		new /obj/structure/overmap/event/meteor(turf_for_field)
		meteor_count++
		log_mapping("SSovermap: Spawned guaranteed asteroid field event")

/**
 * Places the round's planets on the overmap.
 *
 * Two supply models feed this. Anything SSmapping preloaded (the *_planet_count knobs
 * in _mapping.dm) already owns a generated z-level pair at boot and only needs a marker
 * wired to it. Every other planet type spawns as DYNAMIC markers: overmap contacts
 * with no interior at all - no map zone, no z-level, no docks - whose surface is
 * generated the first time a ship docks or a survey shuttle maps it
 * (planet/load_level() -> spawn_dynamic_encounter()).
 *
 * An unvisited dynamic planet costs nothing but its overmap tile, which is why the
 * preloaded counts are all zero: each of those is a full 255x255 z-pair sitting in
 * memory whether or not anyone ever goes there. It is also why the round's planet count
 * (dynamic_planets_per_type, one set of every type per pass) is free to be larger than
 * anything a round will actually visit - none of it is generated until somebody flies there.
 */
/datum/controller/subsystem/overmap/proc/setup_planets()
	if(!spawn_planets)
		log_mapping("SSovermap: planets disabled (spawn_planets = FALSE) - no planet contacts this round")
		return

	// Init planets
	var/list/planets = SSmapping.planets
	if(!planets)
		return

	var/list/orbits = list()
	for (var/i in 2 to LAZYLEN(radius_tiles))
		orbits += "[i]"

	for (var/planet in planets)
		var/turf/turf_for_planet
		// Roundstart planets pre-rolled a zone band before their terrain generated
		// (SSmapping.next_planet_zone_band()), place them inside that band so the
		// zone-scaled mobs/weather they were built with match their overmap tile
		var/wanted_band = planets[planet]["zone_band"]
		if(wanted_band)
			turf_for_planet = get_unused_overmap_square_in_zone_band(wanted_band, tries = 80) // red band is ~9% of tiles, needs generous sampling
			if(!turf_for_planet)
				log_mapping("SSovermap: Failed to place planet '[planet]' in its assigned zone band [wanted_band], falling back to any orbit")
		if(!turf_for_planet) // fallback: legacy random-orbit placement
			if (LAZYLEN(orbits) == 0 || !orbits)
				break // can't fit anymore in
			var/selected_orbit = text2num(pick(orbits))
			turf_for_planet = get_unused_overmap_square_in_radius(selected_orbit)
			if (!turf_for_planet || !istype(turf_for_planet))
				orbits -= "[selected_orbit]" // this one is full
				continue
		var/datum/overmap/planet/planet_type = planets[planet]["type"]
		var/obj/structure/overmap/planet/planet_to_spawn = new
		planet_to_spawn.planet = planet_type
		// Roundstart planets are static: their z-pair was generated once during SSmapping
		// init and can never be rebuilt, so no unload path may ever clear it
		planet_to_spawn.preserve_level = TRUE
		planet_to_spawn.forceMove(turf_for_planet)

		// Transfer all of the data from the planet datum onto the planet object
		planet_to_spawn.apply_planet_identity()

		// Roundstart planets own a whole level each and MUST NOT be packed: their z-level was
		// generated at boot by SSmapping's own loadWorld() pass, at full 255x255 size, and
		// nothing here narrows it or could re-lay it inside a lattice cell. A biome class
		// would deal them a 123x123 slot rectangle over ground that was generated for the
		// whole level, and - worse - hand the SECOND same-biome roundstart planet slot 2 of
		// the FIRST one's z-level while its own pre-generated level went unregistered.
		// MAP_TENANT_CLASS_SOLO is a whole-level, capacity-1 slot: byte-for-byte the
		// allocation these have always had. They still go through the register so the zone
		// pool stays one pool.
		var/datum/map_footprint/footprint = claim_free_slot(MAP_TENANT_CLASS_SOLO, planet_to_spawn, zone_name = "Dynamic Overmap Encounter")
		if(isnull(footprint))
			log_mapping("SSovermap: could not claim a slot for roundstart planet '[planet]' - skipped")
			continue
		var/datum/map_zone/mapzone = footprint.zone
		var/datum/space_level/zlevel
		// length() guard - indexing an empty z_levels list runtimes (see
		// spawn_dynamic_encounter for the round-killing version of this mistake)
		if(length(mapzone.z_levels))
			zlevel = mapzone.z_levels[1]
		else
			zlevel = SSmapping.get_level(planets[planet]["z"])
			mapzone.add_space_level(zlevel)
		footprint.enable_planetary_faction()
		footprint.attach_level(zlevel)
		// These mobs were initialized while SSmapping loaded the roundstart surface, before
		// its overmap marker and footprint existed. Adopt them now, preserving role factions.
		footprint.add_planetary_faction_to_existing_mobs()

		planet_to_spawn.mapzone = mapzone
		planet_to_spawn.footprint = footprint
		planet_to_spawn.loaded = TRUE

	// Dynamic planets: dynamic_planets_per_type markers of every planet type SSmapping did
	// not preload. They are full overmap contacts - named, charted, scannable - with no
	// interior at all until someone visits. Bands come from the same shuffled pool the
	// preloaded planets draw from, so the first three cover green, yellow and red instead
	// of every planet piling into the safe outer ring.
	var/list/preloaded_types = list()
	for(var/planet_key in planets)
		preloaded_types |= planets[planet_key]["type"]

	var/list/dynamic_planet_markers = list(
		/obj/structure/overmap/planet/lava,
		/obj/structure/overmap/planet/ice,
		/obj/structure/overmap/planet/jungle,
		/obj/structure/overmap/planet/beach,
		/obj/structure/overmap/planet/wasteland,
	)
	for(var/obj/structure/overmap/planet/marker_type as anything in dynamic_planet_markers.Copy())
		if(initial(marker_type.planet) in preloaded_types)
			dynamic_planet_markers -= marker_type

	// One full set of types per pass, rather than all the lava planets and then all the
	// ice ones. The first pass is what the lobby pre-build generates, so it has to be the
	// pass that covers every type, and dealing bands in this order keeps each type's
	// planets spread across green/yellow/red instead of clustered in one ring.
	for(var/pass in 1 to max(dynamic_planets_per_type, 1))
		for(var/obj/structure/overmap/planet/marker_type as anything in dynamic_planet_markers)
			spawn_dynamic_planet(marker_type, pass)

/**
 * Places one unloaded planet contact on the overmap.
 *
 * * marker_type - the /obj/structure/overmap/planet subtype to place.
 * * pass - which round of one-per-type this is. Pass 1 is generated during the lobby;
 *   later passes are numbered in the contact's name and build on first visit.
 */
/datum/controller/subsystem/overmap/proc/spawn_dynamic_planet(obj/structure/overmap/planet/marker_type, pass = 1)
	var/wanted_band = SSmapping.next_planet_zone_band()
	var/turf/turf_for_planet = get_unused_overmap_square_in_zone_band(wanted_band, tries = 80) // red band is ~9% of tiles, needs generous sampling
	if(!turf_for_planet)
		log_mapping("SSovermap: Failed to place dynamic planet [marker_type] in zone band [wanted_band], falling back to any free square")
		turf_for_planet = get_unused_overmap_square()
	if(!turf_for_planet)
		log_mapping("SSovermap: Failed to place dynamic planet [marker_type] - no free overmap square")
		return
	var/obj/structure/overmap/planet/planet_to_spawn = new marker_type(turf_for_planet)
	// Remembered rather than re-derived, so the planet keeps its difficulty when it
	// relocates after being abandoned
	planet_to_spawn.zone_band = wanted_band
	// Several planets of a type in one round would otherwise be several identical
	// contacts on the chart, with no way to say which one a mission or a helm order
	// meant. Set before the identity copy, which is what stamps it onto the name.
	if(dynamic_planets_per_type > 1)
		planet_to_spawn.designation = planet_designation(pass)

	// Copy the planet datum's identity onto the marker now, rather than waiting on
	// Initialize(), so the contact is never briefly a nameless "weak energy signature".
	// Redundant since SSovermap gained its SSatoms dependency (Initialize() runs on the
	// spot now), but kept because it is what makes the designation suffix survive - see
	// apply_planet_identity().
	planet_to_spawn.apply_planet_identity()

	log_mapping("SSovermap: Spawned dynamic planet '[planet_to_spawn.name]' (unloaded) in zone band [wanted_band] at ([turf_for_planet.x], [turf_for_planet.y])")

/// Roman numeral for a planet's place in its type, so the chart reads "Lava Planet II"
/// rather than a second "Lava Planet".
/datum/controller/subsystem/overmap/proc/planet_designation(index)
	var/static/list/numerals = list("I", "II", "III", "IV", "V", "VI", "VII", "VIII", "IX", "X")
	return (index >= 1 && index <= length(numerals)) ? numerals[index] : "[index]"

// TODO - MULTI-Z VLEVELS
/datum/controller/subsystem/overmap/proc/calculate_turf_above(turf/T)
	return

// TODO - MULTI-Z VLEVELS
/datum/controller/subsystem/overmap/proc/calculate_turf_below(turf/T)
	return

/**
 * Sets up space ruins on the overmap as mysterious signals
 * Randomly selects from available space ruin templates and places them in various orbits
 */
/datum/controller/subsystem/overmap/proc/setup_space_ruins()
	// Get available space ruin templates
	var/list/available_ruins = SSmapping.space_ruins_templates
	if(!available_ruins || !length(available_ruins))
		log_mapping("SSovermap: No space ruins available to spawn")
		return

	// Build list of orbits to use
	var/list/orbits = list()
	for(var/i in 2 to LAZYLEN(radius_tiles))
		orbits += "[i]"

	// Determine how many ruins to spawn
	var/ruins_to_spawn = rand(MIN_OVERMAP_SPACE_RUINS, MAX_OVERMAP_SPACE_RUINS)

	// Convert template list to a pickable list
	var/list/ruin_pool = list()
	for(var/ruin_id in available_ruins)
		var/datum/map_template/ruin/space/ruin = available_ruins[ruin_id]
		if(istype(ruin) && !ruin.unpickable)
			ruin_pool += ruin

	if(!length(ruin_pool))
		log_mapping("SSovermap: No pickable space ruins in pool")
		return

	var/list/used_ruins = list() // Track which ruins we've already spawned (for allow_duplicates check)

	// Ruins used to take one global random orbit each, which regularly dealt a run of them into
	// the same band and left another with nothing worth flying to. Deal bands in rotation
	// instead, the same way planets and trader outposts already do. Counts are unchanged - this
	// only decides where a ruin lands, never how many there are.
	var/zone_cursor = ZONE_GREEN

	for(var/i in 1 to ruins_to_spawn)
		var/turf/turf_for_ruin = get_unused_overmap_square_in_zone_band(zone_cursor, tries = 80) // red band is ~9% of tiles, needs generous sampling
		if(turf_for_ruin)
			zone_cursor = (zone_cursor % 3) + 1
		else // fallback: legacy random-orbit placement
			if(!length(orbits))
				break // No more space in orbits
			var/selected_orbit = text2num(pick(orbits))
			turf_for_ruin = get_unused_overmap_square_in_radius(selected_orbit)
			if(!turf_for_ruin || !istype(turf_for_ruin))
				orbits -= "[selected_orbit]" // This orbit is full
				continue

		// Pick a ruin template (respecting allow_duplicates)
		var/datum/map_template/ruin/space/selected_ruin
		var/list/pickable_ruins = ruin_pool.Copy()

		// Remove already-used ruins that don't allow duplicates
		for(var/datum/map_template/ruin/space/ruin in pickable_ruins)
			if(!ruin.allow_duplicates && (ruin in used_ruins))
				pickable_ruins -= ruin

		if(!length(pickable_ruins))
			break // No more ruins to pick from

		// Use weighted selection based on placement_weight if available
		var/list/weighted_ruins = list()
		for(var/datum/map_template/ruin/space/ruin in pickable_ruins)
			weighted_ruins[ruin] = ruin.placement_weight || 1
		selected_ruin = pick_weight(weighted_ruins)

		if(!selected_ruin)
			continue

		// Create the space ruin overmap object and set its template
		var/obj/structure/overmap/space_ruin/new_ruin = new(turf_for_ruin)
		new_ruin.set_ruin_template(selected_ruin)

		// Track that we've used this ruin
		used_ruins += selected_ruin

		log_mapping("SSovermap: Spawned space ruin '[selected_ruin.name]' in zone band [get_zone_band_for_turf(turf_for_ruin)] at ([turf_for_ruin.x], [turf_for_ruin.y])")

	// Asteroid mining no longer has a guarantee here - space ruin signals retired the
	// "asteroid" category entirely. The equivalent guarantee (MIN_OVERMAP_ASTEROID_FIELDS)
	// now targets landable meteor storm field events instead; see setup_dangers().
	log_mapping("SSovermap: Finished spawning [length(used_ruins)] space ruins")

/**
 * Returns the zone band (ZONE_RED/YELLOW/GREEN) a turf falls in, computed from
 * distance to the sun. Mirrors SSovermap_zones.calculate_zone_for_turf(), which
 * can't be used here because SSovermap_zones initializes after SSovermap.
 * Zones are static concentric rings, so the distance math is the ground truth.
 */
/datum/controller/subsystem/overmap/proc/get_zone_band_for_turf(turf/T)
	if(!T || !overmap_centre)
		return ZONE_GREEN
	var/max_radius = (OVERMAP_SIZE - 1) / 2
	var/dx = T.x - overmap_centre.x
	var/dy = T.y - overmap_centre.y
	var/normalized = sqrt(dx * dx + dy * dy) / max_radius
	if(normalized < ZONE_INNER_RING_RATIO)
		return ZONE_RED
	if(normalized < ZONE_MIDDLE_RING_RATIO)
		return ZONE_YELLOW
	return ZONE_GREEN

/**
 * Places one trader outpost per zone band (black market deep, outfitter mid,
 * general store in the safe outer ring). Outposts are permanent and never move.
 */
/datum/controller/subsystem/overmap/proc/setup_trader_outposts()
	var/list/wanted = list(
		"[ZONE_RED]" = /obj/structure/overmap/trader_outpost/black_market,
		"[ZONE_YELLOW]" = /obj/structure/overmap/trader_outpost/outfitter,
		"[ZONE_GREEN]" = /obj/structure/overmap/trader_outpost/general,
	)

	for(var/_ in 1 to MAX_OUTPOST_PLACEMENT_ATTEMPTS)
		if(!length(wanted))
			break
		var/turf/candidate = get_unused_overmap_square()
		if(!candidate)
			continue
		var/band = "[get_zone_band_for_turf(candidate)]"
		var/outpost_type = wanted[band]
		if(!outpost_type)
			continue
		var/obj/structure/overmap/trader_outpost/outpost = new outpost_type(candidate)
		outpost.load_level() // pre-load interior at init instead of on first dock
		wanted -= band
		log_mapping("SSovermap: Spawned trader outpost '[outpost.name]' in zone band [band] at ([candidate.x], [candidate.y])")

	for(var/band in wanted)
		log_mapping("SSovermap: WARNING - failed to place a trader outpost in zone band [band]")

/**
 * Spawns the ship the round is anchored on.
 *
 * Only one hull spawns here. Fleet size follows turnout, and nobody has readied up
 * yet at SSovermap init - the rest of the fleet is spawned by scale_roundstart_fleet()
 * once SSticker knows how many players it has. This one still has to exist now, since
 * it carries the observer_start landmark pre-round ghosts spawn on.
 */
/datum/controller/subsystem/overmap/proc/spawn_initial_ship()
#ifdef UNIT_TESTS
	var/list/remaining_templates = subtypesof(/datum/map_template/shuttle/voidcrew)
	for(var/templates in remaining_templates)
		var/obj/structure/overmap/ship/loaded_ship = SSshuttle.create_ship(templates)
		if(!initial_ship && loaded_ship)
			initial_ship = loaded_ship
		if(loaded_ship)
			initial_ships += loaded_ship
			RegisterSignal(loaded_ship, COMSIG_QDELETING, PROC_REF(handle_initial_ship_deletion))
		else
			log_mapping("[src] failed to load ship [templates].")
#else
	if(!spawn_roundstart_hull())
		CRASH("Failed to spawn any roundstart ships.")
#endif

/**
 * Rolls and spawns one free hull: a random modular hull, a random theme on it,
 * and a random module in every one of its upgrade slots.
 *
 * Costs are ignored throughout - nobody is paying for these. Hull classes are drawn
 * without replacement while the pool lasts, so a three-ship round is three different
 * classes rather than three Scarabs.
 *
 * Arguments:
 * * track_as_initial - TRUE for the roundstart fleet, which SSticker deals crews into
 * and which reports its own losses to admins. FALSE for hulls requisitioned mid-round
 * from the join menu: those are ordinary player ships from the moment they exist, and
 * counting them as roundstart hulls would make the fleet look like it never shrank.
 *
 * Returns the spawned ship, or null on failure.
 */
/datum/controller/subsystem/overmap/proc/spawn_free_hull(track_as_initial = TRUE)
	var/list/pool = get_roundstart_hull_templates()
	if(!length(pool))
		CRASH("No modular hulls are eligible to spawn for free.")

	var/list/unused = pool - spent_roundstart_hulls
	var/datum/map_template/shuttle/voidcrew/hull = pick(length(unused) ? unused : pool)

	var/datum/ship_theme/theme = roll_random_ship_theme(hull.type)
	var/list/selections = roll_random_upgrade_selections(hull, theme)

	// Pass the type path, not the catalog instance: create_ship rewrites suffix and
	// mappath on whatever template object it's handed
	var/obj/structure/overmap/ship/spawned = SSshuttle.create_ship(hull.type, selections, theme)
	if(!spawned)
		stack_trace("Failed to spawn free hull: [hull.type]")
		return null

	spent_roundstart_hulls += hull
	if(track_as_initial)
		initial_ships += spawned
		if(!initial_ship)
			initial_ship = spawned
		RegisterSignal(spawned, COMSIG_QDELETING, PROC_REF(handle_initial_ship_deletion))

	var/list/rolled = list()
	for(var/slot_key in selections)
		var/datum/ship_upgrade_module/module = selections[slot_key]
		rolled += "[slot_key]=[module.id]"
	log_mapping("SSovermap: free hull [hull.name] spawned as '[spawned.name]' \
		(theme: [theme?.id || "none"], modules: [length(rolled) ? rolled.Join(", ") : "defaults"], \
		[track_as_initial ? "roundstart fleet" : "requisitioned"])")

	return spawned

/// One hull for the roundstart fleet. See spawn_free_hull().
/datum/controller/subsystem/overmap/proc/spawn_roundstart_hull()
	return spawn_free_hull(track_as_initial = TRUE)

/**
 * Grows the roundstart fleet to match how many players actually readied up.
 *
 * Called from SSticker.create_characters() before anyone is assigned a job, so the
 * hulls exist by the time crews are dealt out. Never shrinks the fleet.
 *
 * Returns the number of hulls in the fleet.
 */
/datum/controller/subsystem/overmap/proc/scale_roundstart_fleet(ready_count)
	var/wanted = clamp(CEILING(ready_count / roundstart_crew_per_ship, 1), 1, roundstart_max_ships)
	while(length(initial_ships) < wanted)
		if(!spawn_roundstart_hull())
			break
	log_mapping("SSovermap: roundstart fleet scaled to [length(initial_ships)] hull(s) for [ready_count] ready player(s) (wanted [wanted]).")
	return length(initial_ships)

/datum/controller/subsystem/overmap/proc/handle_initial_ship_deletion(datum/source)
	SIGNAL_HANDLER

	initial_ships -= source
	if(source == initial_ship)
		initial_ship = length(initial_ships) ? initial_ships[1] : null
	message_admins("A roundstart ship was deleted. [length(initial_ships)] roundstart ship(s) remaining.")



	/**
  * Reserves a square dynamic encounter area, and spawns a ruin in it if one is supplied.
  * * on_planet - If the encounter should be on a generated planet. Required, as it will be otherwise inaccessible.
  * * target - The ruin to spawn, if any
  * * ruin_type - The ruin to spawn. Don't pass this argument if you want it to randomly select based on planet type.
  */

  /**
 * ##get_ruin_list
 *
 * Returns the SSmapping list of ruins, according to the given desired ruin type
 *
 * Arguments:
 * * ruin_type - a string, depicting the desired ruin type
 */
/datum/controller/subsystem/overmap/proc/get_ruin_list(ruin_type)
	switch(ruin_type) // temporary because SSmapping needs a refactor to make this any better
		if (ZTRAIT_LAVA_RUINS)
			return SSmapping.lava_ruins_templates
		if (ZTRAIT_ICE_RUINS)
			return SSmapping.ice_ruins_templates
		if (ZTRAIT_JUNGLE_RUINS)
			return SSmapping.jungle_ruins_templates
		if (ZTRAIT_REEBE_RUINS)
			return SSmapping.yellow_ruins_templates
		if (ZTRAIT_SPACE_RUINS)
			return SSmapping.space_ruins_templates
		if (ZTRAIT_BEACH_RUINS)
			return SSmapping.beach_ruins_templates
		if (ZTRAIT_WASTELAND_RUINS)
			return SSmapping.wasteland_ruins_templates

/**
 * Builds a single-z dynamic encounter level: map zone, area fill, optional ruin,
 * optional mapgen terrain, docking ports. Arguments beyond the historical ones:
 * * zone_band - overmap difficulty band the terrain scales to, if any.
 * * throttled - TRUE when the caller already holds the worldgen queue (the large
 *   asteroid's cave level): the build shares that job's tick budget. FALSE (default)
 *   for unqueued flat encounters, which run at plain CHECK_TICK speed and never wait
 *   behind a queued job - see worldgen_queue.dm.
 * * tenant_class - which slot class to claim. Null lets the encounter pick for itself:
 *   MAP_TENANT_CLASS_FLAT (four to a level) when it is genuinely flat, MAP_TENANT_CLASS_SOLO
 *   when it needs a whole level - it carries a map generator, publishes a ZTRAIT_BASETURF,
 *   or its ruin template is too big for a 123x123 slot. Player outposts pass OUTPOST.
 * * tenant_owner - the overmap object the footprint belongs to, if the caller has it.
 *
 * Returns list(mapzone, primary_dock, secondary_dock, footprint, ruin_bottom_left).
 * Callers MUST hold onto the footprint: it is what their teardown hands back, and what
 * every "is this turf mine" question is answered from. The fifth entry is where the ruin
 * template was stamped (null when there was no ruin, or it did not fit).
 */
/datum/controller/subsystem/overmap/proc/spawn_dynamic_encounter(datum/overmap/planet/planet_type, ruin = TRUE, ignore_cooldown = FALSE, datum/map_template/ruin/ruin_type, zone_band, throttled = FALSE, tenant_class = null, atom/tenant_owner = null)
	log_shuttle("SSOVERMAP: SPAWNING DYNAMIC ENCOUNTER STARTED")
	var/list/ruin_list
	var/datum/map_generator/mapgen
	var/area/target_area
	var/weather_trait
	var/turf/ground_baseturf
	var/datum/planet/planet_template
	/// TRUE only for actual planetary surfaces. Crashed ships and space ruins deliberately
	/// keep their normal faction conflicts even when they also occupy a footprint.
	var/has_planetary_surface = FALSE
	/// Where the ruin template was actually stamped, handed back to the caller as the
	/// fifth return value - space ruins scope their mission spawns and interior sweeps
	/// off it and would otherwise have to guess at the placer's arithmetic.
	var/turf/ruin_bottom_left
	if(!isnull(planet_type))
		planet_type = new planet_type
		ruin_list = get_ruin_list(planet_type.ruin_type)
		if(!isnull(planet_type.mapgen))
			mapgen = new planet_type.mapgen
			// Unqueued callers (empty space, weak signals) must never crawl behind a
			// queued planet job's tick budget - see worldgen_yield() in
			// worldgen_queue.dm. Callers that already hold the queue (throttled = TRUE)
			// keep the generator's budget instead.
			if(!throttled && istype(mapgen, /datum/map_generator/planet_generator))
				var/datum/map_generator/planet_generator/unqueued_gen = mapgen
				unqueued_gen.throttled = FALSE
		target_area = planet_type.target_area
		weather_trait = planet_type.weather_trait
		ground_baseturf = planet_type.baseturf
		has_planetary_surface = !isnull(planet_type.surface_area)
		if(!(isnull(planet_type.planet_template)))
			planet_template = new planet_type.planet_template
		qdel(planet_type)

	if(ruin && ruin_list && !ruin_type)
		ruin_type = ruin_list[pick(ruin_list)]
		if(ispath(ruin_type))
			ruin_type = new ruin_type

	var/encounter_name = "Dynamic Overmap Encounter"
	var/datum/space_level/zlevel
	// ZTRAIT_LINKAGE = UNAFFECTED disables space transitions so construction is allowed
	var/list/zlevel_traits = list(ZTRAIT_MINING = TRUE, ZTRAIT_LINKAGE = UNAFFECTED)
	if(weather_trait)
		zlevel_traits[weather_trait] = TRUE
	// Only ground encounters set this. Left null the level bottoms out in space, which is
	// what empty space, crashed ships and player outposts want. See
	// /datum/overmap/planet/baseturf.
	if(ground_baseturf)
		zlevel_traits[ZTRAIT_BASETURF] = ground_baseturf

	// Which lattice this encounter belongs on. Anything that needs a one-per-z service -
	// its own ground (ZTRAIT_BASETURF), weather, a map generator - or that simply will not
	// fit inside a MAP_SLOT_SIDE square takes a whole level to itself, exactly as it did
	// before packing. Everything else (empty space, crashed ships, ruinless weak signals)
	// is genuinely flat and packs four to a level.
	if(isnull(tenant_class))
		tenant_class = MAP_TENANT_CLASS_FLAT
		if(ground_baseturf || weather_trait || !isnull(mapgen))
			tenant_class = MAP_TENANT_CLASS_SOLO
		else if(ruin_type && !ruin_fits_in_slot(ruin_type))
			tenant_class = MAP_TENANT_CLASS_SOLO

	// Claimed before anything below can sleep, not after the level is minted -
	// add_new_zlevel() blocks on its own spinlock, and a slot left unclaimed across that
	// sleep gets handed to the next caller of find_free_slot() as well. Two encounters
	// then share one footprint, and the first to be abandoned clears the other's ground.
	var/datum/map_footprint/footprint = claim_free_slot(tenant_class, tenant_owner, zone_name = encounter_name)
	if(isnull(footprint))
		log_mapping("SSovermap: dynamic encounter could not claim a '[tenant_class]' slot - encounter aborted")
		return null
	if(has_planetary_surface)
		footprint.enable_planetary_faction()
	// Null for every genuinely flat encounter (that is what makes them flat), non-null only
	// for the SOLO ground encounters selected above. Stamped anyway so the footprint is the
	// single authority every /turf/baseturf_bottom resolution goes through - the level trait
	// below stays as the fallback and is still what an unpacked level answers with.
	footprint.baseturf = ground_baseturf
	var/datum/map_zone/mapzone = footprint.zone

	// length() guard, not [1]: a fresh zone from create_map_zone() has an EMPTY z_levels
	// list, and indexing it runtimes. That runtime aborted every encounter spawn once the
	// free-zone pool ran dry AND leaked the zone with taken = TRUE, so the pool never
	// recovered - round 811 lost all dynamic encounters from 18:03 onward this way.
	if(length(mapzone.z_levels))
		zlevel = mapzone.z_levels[1]
		// A recycled level still holds the last occupant's traits. Reconcile the one that
		// carries a value: left stale, a space encounter reusing a planet's level would
		// bottom its turfs out in that planet's ground instead of space.
		// Only ever the first tenant on the level: on a packed level a co-tenant already
		// built against this trait, and every packed class leaves it null anyway.
		if(mapzone.used_slot_count() <= 1)
			zlevel.set_trait(ZTRAIT_BASETURF, ground_baseturf)
	else if(SSmapping.at_z_level_ceiling())
		// claim_free_slot() refuses to MINT a zone at the ceiling, but a zone can also be
		// dealt from the recycled pool and turn out to have no level yet (a build that
		// failed before add_new_zlevel, an admin-made zone). Refuse here too, and hand the
		// slot straight back rather than leaving it claimed against nothing.
		log_mapping("SSovermap: dynamic encounter refused - world.maxz is at its configured ceiling and [footprint.describe()]'s zone has no level yet")
		mapzone.release_slot(footprint)
		return null
	else
		zlevel = SSmapping.add_new_zlevel(encounter_name, zlevel_traits)
		mapzone.add_space_level(zlevel)

	// add_space_level() attaches slots claimed before the level existed; this covers the
	// recycled-level branch above, where the level was already there.
	footprint.attach_level(zlevel)

	// Dynamic levels appear after SSweather.Initialize and map zones are recycled.
	// Replace any prior encounter's trait, active storm, and cooldown before registering
	// the new planet's weather. One climate per z, so only the first tenant may set it.
	if(mapzone.used_slot_count() <= 1)
		SSweather.set_z_level_weather_trait(zlevel, weather_trait)

	// throttled stays FALSE for unqueued encounter builds (empty space, weak signals):
	// they must never wait behind a queued planet job - see worldgen_yield() in
	// worldgen_queue.dm. Queued callers (the large asteroid's cave level) pass TRUE
	// and share the budget they already hold.
	var/area/filled_area = zlevel.fill_in(area_override = target_area, throttled = throttled, footprint = footprint)

	// Wall the unclaimed slots (and the world edge) off. Once per level, from the whole
	// lattice - a second tenant arriving finds this already done and never repaints over
	// the first one's ground. A whole-level tenant produces no cordon at all, which is
	// what flat encounters have always had.
	zlevel.place_cordon(throttled)

	if(ruin_type)
		// Bounds are the FOOTPRINT's, not the level's: on a packed level the level rect is
		// the whole z, and a ruin placed from it lands in the gutter or on the neighbour.
		// And the region is the slot MINUS its two reserve berths - measuring the ruin down
		// from footprint.high_y stamps any template 73 rows or taller straight over both of
		// them, which is a ship materialising inside ruin walls. See slot_build_region().
		var/list/region = slot_build_region(footprint)
		var/ruin_min_x = region[1]
		var/ruin_min_y = region[2]
		var/ruin_max_x = region[3] - ruin_type.width + 1
		var/ruin_max_y = region[4] - ruin_type.height + 1
		var/turf/ruin_turf = (ruin_min_x <= ruin_max_x && ruin_min_y <= ruin_max_y) \
			? locate(rand(ruin_min_x, ruin_max_x), rand(ruin_min_y, ruin_max_y), footprint.z_value) \
			: null
		if(ruin_turf)
			// /area/ruin carries UNIQUE_AREA, so the map loader hands every load of the same
			// template the SAME area instance. On a packed level two co-tenants rolling one
			// template would share an area straddling both footprints, and every area-scoped
			// system - teardown, lighting, ambience, power, get_area_turfs() - would conflate
			// the two sites. Instanced per load for the duration of OUR stamp, on OUR z only.
			planet_ruin_area_instancing_begin(footprint.z_value)
			// No try/catch, deliberately: wrapping template.load() swallows a partial stamp
			// and leaves a dead half-loaded map standing.
			var/load_result = ruin_type.load(ruin_turf)
			planet_ruin_area_instancing_end(footprint.z_value)
			// Only report a corner the template actually reached. Callers that need an
			// interior (space ruins) read a null here as "no site" and hand the slot back;
			// the ones that do not (empty space, weak signals) simply carry on ruinless.
			if(load_result)
				ruin_bottom_left = ruin_turf
			else
				log_mapping("SSovermap: dynamic encounter ruin '[ruin_type.name]' failed to load at ([ruin_turf.x],[ruin_turf.y],[ruin_turf.z])")
		else
			// A template too large for the footprint. Passing null into load()
			// would runtime and, through the callers' loading flags, brick the tile
			// for the round - a ruinless encounter is the lesser failure.
			log_mapping("SSovermap: dynamic encounter ruin '[ruin_type.name]' ([ruin_type.width]x[ruin_type.height]) \
				does not fit the [MAP_SLOT_RUIN_REGION_WIDTH]x[MAP_SLOT_RUIN_REGION_HEIGHT] ruin region of [footprint.describe()] \
				- encounter spawned without its ruin")

	if (!isnull(mapgen) && (istype(mapgen, /datum/map_generator/planet_generator)) && !isnull(planet_template))
		mapgen.generate_terrain(footprint.get_block(), planet_template, FALSE, FALSE)
		// Terrain generation only lays turfs down and tags each one with the biome it
		// came from - every scrap of flora, fauna and ground feature comes from the
		// population pass, which historically only SSmapping's roundstart init ever
		// ran. Without this a dynamically generated planet is bare landscape. The turf
		// list is rebuilt because generation replaced every turf in the footprint.
		mapgen.populate_terrain(footprint.get_block(), filled_area, zone_band)
	else
		if (!isnull(mapgen))
			mapgen.generate_terrain(footprint.get_block(), planet_template)

	if(filled_area)
		filled_area.reg_in_areas_in_z()

	// Anything mapgen/ruins didn't touch is still uninitialized /turf/open/space/basic,
	// which players can't interact with (no throwing, no construction). Scoped to the
	// footprint: an unclaimed slot must stay uninitialized until it is dealt, and this
	// used to sweep all 65,025 turfs of the level for two 56x40 berths.
	zlevel.initialize_space_turfs(footprint)

	// locates the first dock in the bottom left of the FOOTPRINT, accounting for padding
	// and the border. Anchored off the level instead, two tenants stack their berths on
	// the same tiles - the arrival path, so this is not optional.
	var/turf/primary_docking_turf = locate(
		footprint.low_x+RESERVE_DOCK_DEFAULT_PADDING+1,
		footprint.low_y+RESERVE_DOCK_DEFAULT_PADDING+1,
		footprint.z_value
		)
	if(!primary_docking_turf)
		// Deranged footprint (a recycled zone gone wrong). A runtime here would
		// unwind the caller mid-load and wedge its loading flag for the round, so
		// fail loudly and cleanly instead. The slot is leaked as claimed on purpose:
		// its state is unknown and handing it to the next caller would be worse.
		log_mapping("SSovermap: dynamic encounter build found no dock turf in [footprint.describe()] - encounter aborted")
		return null
	// now we need to offset to account for the first dock
	var/turf/secondary_docking_turf = locate(
		primary_docking_turf.x+RESERVE_DOCK_MAX_SIZE_LONG+RESERVE_DOCK_DEFAULT_PADDING,
		primary_docking_turf.y,
		primary_docking_turf.z
		)

	//This check exists because docking ports don't like to be deleted.
	var/obj/docking_port/stationary/primary_dock = new(primary_docking_turf)
	primary_dock.dir = NORTH
	primary_dock.name = "\improper Uncharted Space"
	primary_dock.height = RESERVE_DOCK_MAX_SIZE_SHORT
	primary_dock.width = RESERVE_DOCK_MAX_SIZE_LONG
	primary_dock.dheight = 0
	primary_dock.dwidth = 0

	var/obj/docking_port/stationary/secondary_dock = new(secondary_docking_turf)
	secondary_dock.dir = NORTH
	secondary_dock.name = "\improper Uncharted Space"
	secondary_dock.height = RESERVE_DOCK_MAX_SIZE_SHORT
	secondary_dock.width = RESERVE_DOCK_MAX_SIZE_LONG
	secondary_dock.dheight = 0
	secondary_dock.dwidth = 0

	// Both berths get moved and resized to fit every ship that visits; record where they started
	// so the next arrival is placed from this layout rather than the last visitor's offset.
	primary_dock.mark_reserve_home()
	secondary_dock.mark_reserve_home()

	if(has_planetary_surface)
		footprint.add_planetary_faction_to_existing_mobs()

	return list(mapzone, primary_dock, secondary_dock, footprint, ruin_bottom_left)

/**
 * The rectangle inside `footprint` a ruin template may be stamped into, as
 * list(min_x, min_y, max_x, max_y) in absolute coordinates.
 *
 * A slot's bottom rows belong to its two reserve berths (see the placement in
 * spawn_dynamic_encounter): x offsets 4..118, y offsets 4..43. This region is what is
 * left once those and their PLANET_DOCK_RUIN_CLEARANCE collar are taken out, inset by
 * MAP_SLOT_RUIN_MARGIN from the slot edge so a template never sits flush against cordon.
 *
 * A whole-level footprint (SOLO, outposts) has no lattice geometry to respect but DOES
 * still carry the same two berths at its own origin, so the same offsets apply - it just
 * has far more room above them.
 */
/datum/controller/subsystem/overmap/proc/slot_build_region(datum/map_footprint/footprint)
	var/min_x = footprint.low_x + MAP_SLOT_RUIN_MARGIN
	var/min_y = footprint.low_y + MAP_SLOT_RUIN_MIN_Y_OFFSET
	var/max_x = footprint.high_x - MAP_SLOT_RUIN_MARGIN
	var/max_y = footprint.high_y - MAP_SLOT_RUIN_MARGIN
	return list(min_x, min_y, max_x, max_y)

/**
 * Whether a ruin template fits the region a lattice slot actually has free for it.
 *
 * NOT a square test against MAP_SLOT_SIDE. The berth band eats the bottom 47 rows of every
 * slot, so the honest gate is MAP_SLOT_RUIN_REGION_WIDTH x MAP_SLOT_RUIN_REGION_HEIGHT
 * (119 x 74) - the old `+ 12 <= 123` form accepted templates up to 111 tall and handed
 * them to a placer that stamped them over both docking berths.
 *
 * Templates that fail take MAP_TENANT_CLASS_SOLO, a whole level, which costs exactly what
 * they cost before packing. Measured 2026-08-20 against the live template list: 112 of 113
 * pass, the outlier being russian_derelict (83x111).
 */
/datum/controller/subsystem/overmap/proc/ruin_fits_in_slot(datum/map_template/ruin/ruin_type)
	if(!ruin_type)
		return TRUE
	return ruin_type.width <= MAP_SLOT_RUIN_REGION_WIDTH && ruin_type.height <= MAP_SLOT_RUIN_REGION_HEIGHT

/**
 * Whether a ruin template fits even a WHOLE z-level's build region - the same berth band
 * taken out of a 255x255 footprint rather than a 123x123 one.
 *
 * A template failing this cannot be placed anywhere, so the site has to refuse before
 * claiming a slot: a claimed slot handed back after a failed stamp is a quarter of a
 * z-level lost, and the caller's loading flag bricks the overmap tile for the round.
 * Nothing in the current pool comes close (the largest is oldstation at 112x64), but the
 * old reservation path had exactly this guard and losing it would be a regression.
 */
/datum/controller/subsystem/overmap/proc/ruin_fits_in_level(datum/map_template/ruin/ruin_type)
	if(!ruin_type)
		return TRUE
	return ruin_type.width <= (world.maxx - (MAP_SLOT_RUIN_MARGIN * 2)) \
		&& ruin_type.height <= (world.maxy - MAP_SLOT_RUIN_MARGIN - MAP_SLOT_RUIN_MIN_Y_OFFSET)


/datum/controller/subsystem/overmap/proc/create_map_zone(new_name)
	return new /datum/map_zone(new_name)

/**
 * Finds a map zone that can deal a slot of `tenant_class`, as list(zone, slot_index).
 *
 * Replaces find_free_mapzone(), which handed out whole zones on a single boolean. Prefers
 * a PARTIALLY FILLED zone of the same class over an empty one - that preference is the
 * whole point of packing, since spreading tenants across empty levels one apiece is
 * exactly the behaviour being removed. Only when no same-class level has room does it
 * fall back to a level with no tenants at all (which is free to take any class on).
 *
 * Returns null when every zone is full or of the wrong class; the caller mints one.
 * Nothing here sleeps - see claim_free_slot().
 */
/datum/controller/subsystem/overmap/proc/find_free_slot(tenant_class)
	var/datum/map_zone/empty_zone = null
	for(var/datum/map_zone/mapzone as anything in map_zones)
		var/occupants = mapzone.used_slot_count()
		if(occupants)
			if(mapzone.tenant_class == tenant_class && mapzone.has_free_slot(tenant_class))
				return list(mapzone, mapzone.first_free_slot_index())
			continue
		if(isnull(empty_zone))
			empty_zone = mapzone
	if(empty_zone)
		return list(empty_zone, 1)
	return null

/**
 * Finds AND claims a slot in one go, returning the /datum/map_footprint.
 *
 * Atomic on purpose. find_free_slot() is a check-then-act over a global list, and every
 * historical bug in this area (round 811 lost every dynamic encounter to one) came from a
 * claim landing after something was allowed to sleep - add_new_zlevel() blocks on its own
 * spinlock, so an unclaimed zone held across it is handed straight to the next caller.
 * Nothing in this path or in claim_slot() sleeps.
 *
 * * tenant_class - one of the MAP_TENANT_CLASS_* keys.
 * * new_owner - the overmap object that will hold the footprint, for logging and for the
 *   footprint's own owner watch. May be null and set later.
 * * create_zone - mint a fresh map zone when the pool has nothing. FALSE is for callers
 *   that want to know the pool is dry rather than grow it.
 *
 * Also returns null when world.maxz is at its configured ceiling. A fresh zone has no
 * z-level, so dealing a slot out of one always means minting one, and BYOND never frees a
 * z-level. Callers must read a null the way they already read a dry pool - "not right
 * now", retry later - never as a hard failure. This is a SLOT-AVAILABILITY wait and is
 * deliberately outside the worldgen queue: a ruin or an empty-space dock may never end up
 * waiting behind a planet build (the design rule in worldgen_queue.dm), and nothing in
 * this path sleeps.
 */
/datum/controller/subsystem/overmap/proc/claim_free_slot(tenant_class, atom/new_owner, create_zone = TRUE, zone_name = "Dynamic Overmap Encounter")
	var/list/found = find_free_slot(tenant_class)
	var/datum/map_zone/mapzone = length(found) ? found[1] : null
	if(isnull(mapzone))
		if(!create_zone)
			return null
		if(SSmapping.at_z_level_ceiling())
			return null
		mapzone = create_map_zone(zone_name)
	return mapzone.claim_slot(tenant_class, new_owner)
