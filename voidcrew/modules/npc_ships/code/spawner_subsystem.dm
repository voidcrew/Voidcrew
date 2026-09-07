/**
 * NPC Ships Spawner Subsystem
 *
 * Manages deterministic spawning of NPC pirate ships.
 * Spawns 4 pirates at round start from a unified faction pool, split evenly between the
 * red and yellow bands. Any faction can spawn in any zone - the zone determines behavior:
 * - Yellow zone: scan -> hail -> negotiate -> interdict + siphon (economic threat)
 * - Red zone: hail -> negotiate -> boarding waves -> boss (lethal threat)
 *
 * Pool rotation: a pirate is "resolved" when all its crew aboard are dead, or when its
 * ship key is claimed at a helm / turned in for a bounty (see the ship's
 * notify_spawner_resolved). Every resolve spawns a replacement in the same band. Hull
 * destruction does NOT resolve a pirate - a wreck with live crew aboard holds its slot
 * until someone boards the crash site and finishes the job.
 * Disarming also frees the slot, but starts a 10-minute salvage window for that hull.
 * The derelict sweep then removes it unless claimed or still being boarded.
 *
 * fire() is a low-frequency reconcile that re-derives the population from live state.
 * It exists because the event paths alone provably wedge: in the round-4 audit the
 * event-driven design produced zero replacements across 22 hours. The reconcile catches
 * missed death signals, hard-deleted or spaced crew, and failed spawns, and retries
 * band deficits until the pool is full again.
 */
SUBSYSTEM_DEF(npc_ships)
	name = "NPC Ships"
	init_order = INIT_ORDER_OVERMAP + 2 // After SSovermap and SSovermap_zones
	wait = 30 SECONDS // Slow reconcile tick; the event paths handle the instant cases
	runlevels = RUNLEVEL_GAME
	dependencies = list(
		/datum/controller/subsystem/shuttle,  // Need SSshuttle to load ship templates
		/datum/controller/subsystem/overmap_zones,  // Need zones for spawn locations
	)

	/// List of currently active NPC ships
	var/list/obj/structure/overmap/ship/npc/active_ships = list()

	/// The zone bands the pool is budgeted across; pirate_count_target is distributed
	/// round-robin over this list (4 pirates -> 2 red, 2 yellow)
	var/list/pool_zones = list(ZONE_RED, ZONE_YELLOW)

	/// In-flight spawn claims: list of list("zone" = zone_type, "started" = world.time).
	/// A slot is claimed synchronously before the (sleeping) template load starts, so a
	/// concurrent count can't read a deficit that is already being filled and double-spawn.
	var/list/in_flight_spawns = list()

	/// Text refs of hulls whose missing crew roster the reconcile has already screamed
	/// about (text so the list never blocks a delete)
	var/list/logged_malformed = list()

	/// All available pirate faction types (any can spawn in any zone)
	var/list/all_factions = list(
		/obj/structure/overmap/ship/npc/pirate/skeleton,     // Dutchman
		/obj/structure/overmap/ship/npc/pirate/grey,         // Grey Tide
		/obj/structure/overmap/ship/npc/pirate/medieval,     // Medieval
		/obj/structure/overmap/ship/npc/pirate/lustrous,     // Geode
		/obj/structure/overmap/ship/npc/pirate/silverscale,  // Silverscale
		/obj/structure/overmap/ship/npc/pirate/irs,          // IRS
		/obj/structure/overmap/ship/npc/pirate/interdyne,    // Interdyne
	)

	/// Currently active faction types
	var/list/active_faction_types = list()

	/// Target number of active pirates
	var/pirate_count_target = 4

	/// Whether initial spawning is complete
	var/initialized_pirates = FALSE

/datum/controller/subsystem/npc_ships/Initialize()
	log_world("SSnpc_ships: Initializing with [length(all_factions)] factions, target [pirate_count_target] pirates")
	// SSshuttle is listed as a dependency, so it's guaranteed to be ready
	initialize_pirates()
	return SS_INIT_SUCCESS

/**
 * Spawns the initial set of pirates at round start.
 * Picks random unique factions, distributed evenly across zones.
 * Ensures each zone gets at least one pirate before any zone gets a second.
 */
/datum/controller/subsystem/npc_ships/proc/initialize_pirates()
	if(initialized_pirates)
		return

	log_world("SSnpc_ships: Spawning initial pirates...")

	// Pick random unique factions
	var/list/available = all_factions.Copy()

	// Build zone assignments: distribute evenly across RED and YELLOW
	var/list/spawn_zones = pool_zones
	var/list/zone_assignments = list()
	for(var/i in 1 to pirate_count_target)
		// Cycle through zones: 1->RED, 2->YELLOW, 3->RED, 4->YELLOW, etc.
		var/zone_index = ((i - 1) % length(spawn_zones)) + 1
		zone_assignments += spawn_zones[zone_index]

	// Shuffle zone assignments so it's not always RED first
	for(var/i in length(zone_assignments) to 2 step -1)
		var/j = rand(1, i)
		var/temp = zone_assignments[i]
		zone_assignments[i] = zone_assignments[j]
		zone_assignments[j] = temp

	for(var/i in 1 to pirate_count_target)
		if(!length(available))
			break
		var/faction_type = pick_n_take(available)
		spawn_pirate(faction_type, zone_assignments[i])

	initialized_pirates = TRUE
	log_world("SSnpc_ships: Initial spawn complete. [length(active_ships)] pirates active.")

/**
 * Called when a pirate is "resolved" (crew wiped, key claimed or turned in, abandoned,
 * deleted). Spawns a replacement in the same zone - off this stack, because callers
 * include Destroy() and signal handlers, neither of which may sleep through the
 * template load inside create_npc_ship().
 * @param resolved_type The type path of the resolved pirate ship
 * @param resolved_zone_type The zone the pirate was budgeted against (null = any)
 */
/datum/controller/subsystem/npc_ships/proc/on_pirate_resolved(resolved_type, resolved_zone_type)
	if(!initialized_pirates)
		return  // Don't replace during initialization

	// Only ships from the pirate faction pool get replacements; one-off ships
	// (mission-dispatched patrols and the like) resolve without a successor
	if(!(resolved_type in all_factions))
		return

	// Remove from active tracking (kept purely as the variety preference for picks)
	active_faction_types -= resolved_type

	// Live capacity check - counts hulls that still hold a slot plus spawns in flight,
	// never the event-driven faction list (which is exactly what wedged the old design)
	if(count_pool_ships() >= pirate_count_target)
		return

	var/list/claim = claim_spawn_slot(resolved_zone_type)
	INVOKE_ASYNC(src, PROC_REF(run_claimed_spawn), claim)

/**
 * Claims an in-flight spawn slot so concurrent capacity counts include it.
 * Must be paired with run_claimed_spawn(), which releases it.
 */
/datum/controller/subsystem/npc_ships/proc/claim_spawn_slot(target_zone_type)
	var/list/claim = list("zone" = target_zone_type, "started" = world.time)
	in_flight_spawns += list(claim)
	return claim

/**
 * Spawns a replacement pirate against a claimed slot, then releases the claim.
 * Prefers factions not currently active. Sleeps through the template load - only ever
 * call it via INVOKE_ASYNC or from fire()-adjacent async context.
 */
/datum/controller/subsystem/npc_ships/proc/run_claimed_spawn(list/claim)
	var/target_zone_type = claim["zone"]

	// Get factions not currently active; if all are active, pick any
	var/list/available = all_factions - active_faction_types
	if(!length(available))
		available = all_factions.Copy()

	var/faction_type = pick(available)
	var/obj/structure/overmap/ship/npc/ship = spawn_pirate(faction_type, target_zone_type)
	in_flight_spawns -= list(claim)
	if(ship)
		log_world("SSnpc_ships: Spawned replacement pirate: [faction_type] in zone [target_zone_type || "any"]")
	// A failed spawn needs no retry logic here - the next reconcile re-reads the
	// deficit and tries again

/**
 * Spawns a pirate of the specified type.
 * @param ship_type_path The ship type to spawn
 * @param target_zone_type The zone type to spawn in (null = any zone)
 * @return The spawned ship or null on failure
 */
/datum/controller/subsystem/npc_ships/proc/spawn_pirate(ship_type_path, target_zone_type)
	var/obj/structure/overmap/ship/npc/ship = spawn_npc_ship(ship_type_path, target_zone_type)
	if(!ship)
		log_world("SSnpc_ships: Failed to spawn pirate of type [ship_type_path]")
		return null

	// Record the band this hull is budgeted against; resolves report it back so the
	// replacement spawns in the same band even if the hull moved (or crashed) since
	ship.pool_zone_type = target_zone_type || SSovermap_zones.get_zone_type(get_turf(ship))

	// Track in active faction list
	active_faction_types += ship_type_path

	// Notify bounty subsystem to create a bounty for this pirate
	SSbounty?.on_pirate_spawned(ship)

	return ship

// ========== POOL RECONCILE ==========

/datum/controller/subsystem/npc_ships/fire(resumed)
	if(!initialized_pirates)
		return
	reconcile_pool()

/**
 * Whether this hull currently occupies one of the pool's slots.
 * A slot is held by a live, unclaimed, unresolved pool-faction hull with living crew
 * aboard. A hull whose crew spawn failed also holds its slot (and gets screamed about
 * by the reconcile) - auto-resolving it would churn the pool in a loop.
 */
/datum/controller/subsystem/npc_ships/proc/ship_holds_pool_slot(obj/structure/overmap/ship/npc/ship)
	if(QDELETED(ship))
		return FALSE
	if(!(ship.type in all_factions))
		return FALSE // one-off dispatch ships never hold pool slots
	if(ship.player_controlled || ship.abandoned || ship.spawner_resolved)
		return FALSE
	if(!ship.crew_ever_spawned)
		return TRUE
	return ship.count_live_crew_aboard() > 0

/**
 * Live pool population: hulls still holding a slot, plus spawns already in flight.
 */
/datum/controller/subsystem/npc_ships/proc/count_pool_ships()
	var/count = length(in_flight_spawns)
	for(var/obj/structure/overmap/ship/npc/ship as anything in active_ships)
		if(ship_holds_pool_slot(ship))
			count++
	return count

/**
 * The authority on pool population. The event paths (crew death signals, key
 * destruction) are fast paths that usually get there first; this sweep re-derives
 * everything from live state on a slow tick, so no missed signal, hard delete, spaced
 * survivor or failed spawn can wedge the pool the way the old event-only design did.
 */
/datum/controller/subsystem/npc_ships/proc/reconcile_pool()
	// Expire in-flight claims whose spawn died mid-load; a leaked claim would otherwise
	// block its band forever
	for(var/list/claim as anything in in_flight_spawns.Copy())
		if(world.time - claim["started"] > 3 MINUTES)
			in_flight_spawns -= list(claim)
			log_world("SSnpc_ships: Expired a stalled spawn claim for zone [claim["zone"]]")

	// Sweep the roster: drop dead references, release claimed hulls, resolve crew wipes
	// the signal path missed
	for(var/obj/structure/overmap/ship/npc/ship as anything in active_ships.Copy())
		if(QDELETED(ship))
			active_ships -= ship
			continue
		if(!(ship.type in all_factions))
			continue // one-off dispatch ships manage their own lifecycle
		if(ship.player_controlled)
			// Claimed hulls leave the pool; the key's destruction already resolved them
			// (the latch makes this a no-op in that case)
			ship.notify_spawner_resolved("claimed")
			active_ships -= ship
			continue
		if(ship.spawner_resolved || ship.abandoned)
			continue
		if(!ship.crew_ever_spawned)
			if(!(REF(ship) in logged_malformed))
				logged_malformed += REF(ship)
				log_world("SSnpc_ships: [ship.name] has no crew roster (spawn_crew failed?) - it holds its pool slot and will never auto-resolve")
			continue
		// Put spaced survivors out of their misery before the census reads them
		ship.sweep_spaced_crew()
		if(ship.count_live_crew_aboard() <= 0)
			ship.notify_spawner_resolved("crew wiped (reconcile)")
			continue
		// Also catch disarmament outside an engagement. Retire the hull with the same
		// salvage deadline as the retreat path, even while NPC crew survive aboard.
		ship.resolve_disarmed("disarmed (reconcile)")

	// Top up each band to its share of the target
	var/list/deficit_by_zone = list()
	for(var/i in 1 to pirate_count_target)
		var/zone_type = pool_zones[((i - 1) % length(pool_zones)) + 1]
		deficit_by_zone["[zone_type]"] += 1
	for(var/obj/structure/overmap/ship/npc/ship as anything in active_ships)
		if(!ship_holds_pool_slot(ship))
			continue
		deficit_by_zone["[ship.pool_zone_type]"] -= 1
	for(var/list/claim as anything in in_flight_spawns)
		deficit_by_zone["[claim["zone"]]"] -= 1

	for(var/zone_type in pool_zones)
		var/deficit = deficit_by_zone["[zone_type]"]
		if(deficit <= 0)
			continue
		log_world("SSnpc_ships: Reconcile topping up [deficit] pirate(s) in zone [zone_type]")
		for(var/i in 1 to deficit)
			var/list/claim = claim_spawn_slot(zone_type)
			INVOKE_ASYNC(src, PROC_REF(run_claimed_spawn), claim)

/**
 * Removes a ship from tracking (called when ship is deleted).
 */
/datum/controller/subsystem/npc_ships/proc/untrack_ship(obj/structure/overmap/ship/npc/ship)
	active_ships -= ship

/**
 * Gets all active ships of a specific faction type.
 * @param faction_type The faction type path to filter by
 * @return List of matching ships
 */
/datum/controller/subsystem/npc_ships/proc/get_ships_by_faction(faction_type)
	var/list/result = list()
	for(var/obj/structure/overmap/ship/npc/ship in active_ships)
		if(istype(ship, faction_type))
			result += ship
	return result

/**
 * Gets the spawn zones for a ship type.
 * Any faction can spawn in any zone - zone determines behavior.
 */
/datum/controller/subsystem/npc_ships/proc/get_spawn_zones_for_type(ship_type_path)
	return list(ZONE_YELLOW, ZONE_RED)

/**
 * Finds a valid spawn turf for an NPC ship.
 * @param spawn_zones List of zone types to spawn in
 */
/datum/controller/subsystem/npc_ships/proc/get_spawn_turf(list/spawn_zones)
	var/list/valid_turfs = list()

	for(var/zone_type in spawn_zones)
		var/datum/overmap_zone/zone = SSovermap_zones.get_zone_datum(zone_type)
		if(zone?.turfs)
			valid_turfs += zone.turfs

	if(!length(valid_turfs))
		return null

	// Filter out turfs near player ships (5 tile buffer)
	var/list/safe_turfs = list()
	for(var/turf/T as anything in valid_turfs)
		var/too_close = FALSE
		for(var/obj/structure/overmap/ship/ship in range(5, T))
			if(istype(ship, /obj/structure/overmap/ship/npc))
				continue
			too_close = TRUE
			break

		if(locate(/obj/structure/overmap) in T)
			continue

		if(!too_close)
			safe_turfs += T

	if(!length(safe_turfs))
		return null

	return pick(safe_turfs)

/**
 * Spawns a new NPC ship in a valid zone.
 * @param ship_type_path The ship type to spawn
 * @param target_zone_type Specific zone type to spawn in (null = use get_spawn_zones_for_type)
 * @return The spawned ship or null on failure
 */
/datum/controller/subsystem/npc_ships/proc/spawn_npc_ship(ship_type_path, target_zone_type)
	var/template_path = initial(ship_type_path:shuttle_template)
	if(!template_path)
		log_world("SSnpc_ships: No shuttle_template defined for [ship_type_path]")
		return null

	var/list/spawn_zones
	if(target_zone_type)
		spawn_zones = list(target_zone_type)
	else
		spawn_zones = get_spawn_zones_for_type(ship_type_path)
	if(!length(spawn_zones))
		return null

	var/turf/spawn_turf = get_spawn_turf(spawn_zones)
	if(!spawn_turf)
		log_world("SSnpc_ships: No valid spawn turf found for [ship_type_path]")
		return null

	var/obj/structure/overmap/ship/npc/ship = create_npc_ship(template_path, spawn_turf, ship_type_path)
	if(!ship)
		return null

	active_ships += ship
	log_world("SSnpc_ships: Spawned [ship.name] at ([spawn_turf.x], [spawn_turf.y])")

	return ship

/**
 * Creates an NPC ship from a template at the specified location.
 * @param template_path The shuttle template to use
 * @param spawn_turf Where to spawn the ship
 * @param ship_type_path The ship type path
 */
/datum/controller/subsystem/npc_ships/proc/create_npc_ship(template_path, turf/spawn_turf, ship_type_path)
	return SSshuttle.run_template_load(CALLBACK(src, PROC_REF(create_npc_ship_impl), template_path, spawn_turf, ship_type_path))

/datum/controller/subsystem/npc_ships/proc/create_npc_ship_impl(template_path, turf/spawn_turf, ship_type_path, datum/shuttle_template_load/load_owner)

	var/datum/map_template/shuttle/voidcrew/template_instance
	if(istype(template_path, /datum/map_template/shuttle/voidcrew))
		template_instance = template_path
	else if(ispath(template_path, /datum/map_template/shuttle/voidcrew))
		template_instance = new template_path()
	else
		stack_trace("create_npc_ship called with invalid template: [template_path]")
		return null

	if(!template_instance)
		return null

	var/datum/worldgen_probe/probe = worldgen_begin("ship-npc", "[template_instance.name]")

	var/obj/structure/overmap/ship/npc/ship = new ship_type_path(spawn_turf)

	if(!ship || QDELETED(ship))
		worldgen_end(probe, "spawn-failed")
		return null

	if(!ship.setup_from_template(template_instance))
		stack_trace("NPC ship failed to setup from template [template_path]")
		qdel(ship)
		worldgen_end(probe, "setup-failed")
		return null

	SSair.can_fire = FALSE
	var/obj/docking_port/mobile/voidcrew/loaded = SSshuttle.action_load(ship.source_template, load_owner = load_owner)
	SSair.can_fire = load_owner.previous_air_can_fire

	if(!loaded)
		stack_trace("Failed to load shuttle for NPC ship [template_path]")
		qdel(ship)
		worldgen_end(probe, "load-failed")
		return null

	loaded.current_ship = ship
	ship.shuttle = loaded

	SEND_SIGNAL(loaded, COMSIG_VOIDCREW_SHIP_LOADED)

	ship.calculate_mass()
	ship.initialize_ai()

	worldgen_end(probe)
	return ship

// ========== ADMIN VERBS ==========

/**
 * Admin verb to force spawn an NPC pirate ship.
 */
/client/proc/spawn_npc_ship()
	set name = "Spawn NPC Ship"
	set category = "Overmap.NPC"

	if(!check_rights(R_ADMIN))
		return

	var/list/faction_options = list(
		"Silverscale (Lizards)" = /obj/structure/overmap/ship/npc/pirate/silverscale,
		"Grey Tide (Assistants)" = /obj/structure/overmap/ship/npc/pirate/grey,
		"Lustrous (Ethereals)" = /obj/structure/overmap/ship/npc/pirate/lustrous,
		"Skeleton (Dutchman)" = /obj/structure/overmap/ship/npc/pirate/skeleton,
		"Interdyne (Pharma)" = /obj/structure/overmap/ship/npc/pirate/interdyne,
		"IRS (Tax Collectors)" = /obj/structure/overmap/ship/npc/pirate/irs,
		"Medieval (Knights)" = /obj/structure/overmap/ship/npc/pirate/medieval,
	)

	var/choice = tgui_input_list(usr, "Select pirate faction to spawn:", "Spawn NPC Ship", faction_options)
	if(!choice)
		return

	var/ship_type = faction_options[choice]
	var/obj/structure/overmap/ship/npc/ship = SSnpc_ships.spawn_pirate(ship_type)
	if(ship)
		to_chat(usr, span_notice("Spawned NPC ship: [ship.name]"))
		mob.client?.admin_follow(ship.shuttle)
	else
		to_chat(usr, span_warning("Failed to spawn NPC ship. Check spawn zone availability."))

/**
 * Admin verb to view NPC ship status.
 */
/client/proc/npc_ship_status()
	set name = "NPC Ship Status"
	set category = "Overmap.NPC"

	if(!check_rights(R_ADMIN))
		return

	var/list/lines = list()
	lines += "=== NPC Ship Status ==="
	lines += "Pool slots held: [SSnpc_ships.count_pool_ships()]/[SSnpc_ships.pirate_count_target] ([length(SSnpc_ships.in_flight_spawns)] spawning)"
	lines += "Tracked ship objects: [length(SSnpc_ships.active_ships)] (includes resolved wrecks and one-off dispatches)"
	lines += ""
	lines += "Active Factions:"
	for(var/faction in SSnpc_ships.active_faction_types)
		lines += "  - [faction]"
	lines += ""
	lines += "All Active Ships:"
	for(var/obj/structure/overmap/ship/npc/ship in SSnpc_ships.active_ships)
		var/datum/ai_controller/npc_ship/controller = ship.ai_controller
		var/obj/structure/overmap/ship/target = controller?.get_target()
		var/combat_state = controller?.blackboard[BB_NPC_COMBAT_STATE] || "none"
		var/turf/ship_turf = get_turf(ship)
		var/datum/overmap_zone/ship_zone = SSovermap_zones.get_zone(ship_turf)
		var/zone_name = ship_zone?.zone_type || "unknown"
		lines += "  - [ship.name] at ([ship.x], [ship.y], z=[ship.z]) [zone_name] zone"
		lines += "      State: [combat_state], Target: [target?.name || "none"]"
		lines += "      Territory: [ship.territory_range] tiles"

	// Also show player ships for distance comparison
	lines += ""
	lines += "Player Ships:"
	for(var/obj/structure/overmap/ship/player_ship in SSovermap.simulated_ships)
		if(istype(player_ship, /obj/structure/overmap/ship/npc))
			continue
		lines += "  - [player_ship.name] at ([player_ship.x], [player_ship.y], z=[player_ship.z])"
		// Show distance to each pirate
		for(var/obj/structure/overmap/ship/npc/pirate in SSnpc_ships.active_ships)
			var/dist = get_dist(pirate, player_ship)
			lines += "      -> [pirate.name]: [dist] tiles away"

	to_chat(usr, lines.Join("\n"))
