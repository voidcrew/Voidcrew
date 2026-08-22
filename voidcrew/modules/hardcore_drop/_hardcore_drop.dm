/**
 * # Hardcore drop
 *
 * A way into the round that does not involve a ship: you arrive alone, in a pod, on a
 * planet surface, with one crate of supplies and no way home that somebody else is not
 * flying. Everything a normal spawn hands you - a hull, a crew, a helm, a mission board,
 * a paycheque - you do not get.
 *
 * Ships off DARK. `HARDCORE_DROP` in config/voidcrew/voidcrew_config.txt is commented out,
 * so on an unmodified server the join menu never mentions this and none of the code below
 * runs. See voidcrew/GUIDES/HARDCORE_SPAWN_DESIGN.md for the full design, the open
 * questions, and the reasoning behind each limit here.
 *
 * ## The shape of the thing
 *
 * The join menu (voidcrew/edits/mobs/ship_join_menu.dm) gains one button. Pressing it
 * runs /mob/dead/new_player/proc/attempt_hardcore_drop(), which picks an eligible planet
 * and hands it to a /datum/hardcore_drop. That datum is a small state machine over the
 * one genuinely asynchronous step in the flow: planets in this fork have NO interior
 * until somebody visits them (SSmapping's *_planet_count are all 0 - see
 * voidcrew/mapping/_mapping.dm), so a drop onto an unvisited world has to trigger a
 * terrain build, wait out the worldgen queue, and only then put a body anywhere. It
 * waits on COMSIG_VOIDCREW_SITE_LOAD_FINISHED exactly the way a ship holding a docking
 * approach does (/obj/structure/overmap/ship/proc/request_site_load).
 *
 * ## Two rules that are easy to break
 *
 * 1. **Never create the body before the planet reports loaded.** A planet's z-level is
 *    half-generated for most of a minute, and /datum/space_level/clear_reservation()
 *    qdels every atom on a slot with no exemption for mobs holding a client.
 *
 * 2. **Arm the release.** A planet's despawn countdown is only ever started by a SHIP
 *    undocking (/obj/structure/overmap/planet/Entered -> on_ship_undocked ->
 *    check_start_despawn). A world generated for a castaway that no hull ever berths at
 *    would therefore hold its map slot - a quarter of a z-level, against a hard
 *    world.maxz ceiling - until roundend. land() calls check_start_despawn() once for
 *    exactly this reason; see the comment there before removing it.
 */

/// Whether the hardcore drop join option exists at all this round.
/datum/config_entry/flag/hardcore_drop
	default = FALSE

/**
 * How many castaways may be living on planets at once.
 *
 * Each drop onto an unvisited world costs a map slot (a quarter of a z-level) for as long
 * as the castaway is alive on it, and world.maxz has a hard config ceiling that the rest
 * of the galaxy is already budgeted against - see /datum/config_entry/number/max_z_levels.
 * A drop that lands on a world some crew already surveyed costs nothing extra, and
 * pick_hardcore_drop_planet() prefers those, but the cap has to assume the expensive case.
 */
/datum/config_entry/number/hardcore_drop_max_active
	default = 2
	integer = TRUE
	min_val = 0

/// Minutes a ckey must wait between hardcore drops. Stops one player cycling drops and
/// minting a fresh planet every time they die. 0 disables the cooldown.
/datum/config_entry/number/hardcore_drop_cooldown_minutes
	default = 30
	integer = TRUE
	min_val = 0

/**
 * Planet types a castaway can survive on in shirtsleeves.
 *
 * Jungle, beach and wasteland surfaces are OPENTURF_DEFAULT_ATMOS - breathable air at
 * room temperature - so the difficulty is fauna, weather and isolation rather than a
 * countdown on an oxygen tank. Ice is breathable at 180 K and would kill an unprotected
 * arrival on the cold alone; lava is LAVALAND_ATMOS, which is 30-49 kPa of mostly
 * nitrogen and sometimes plasma. Both are deliberately out until the crate carries
 * matching protection and the design says they should be in.
 */
GLOBAL_LIST_INIT(hardcore_drop_planet_types, list(
	/datum/overmap/planet/jungle,
	/datum/overmap/planet/beach,
	/datum/overmap/planet/wasteland,
))

/// Live /datum/hardcore_drop records, pruned by hardcore_drops_active().
GLOBAL_LIST_EMPTY(hardcore_drops)

/// ckey -> world.time their last hardcore drop landed. Keyed by ckey rather than mind so
/// dying, ghosting and coming back through the lobby cannot reset the cooldown.
GLOBAL_LIST_EMPTY(hardcore_drop_last_use)

/**
 * How many castaways are currently alive on a planet. Prunes finished records as it goes.
 *
 * Copy() because qdel'ing a record takes it out of GLOB.hardcore_drops from inside
 * /datum/hardcore_drop/Destroy(), and removing the current entry mid-iteration shifts the
 * list and skips the next one.
 */
/proc/hardcore_drops_active()
	var/count = 0
	for(var/datum/hardcore_drop/drop as anything in GLOB.hardcore_drops.Copy())
		if(!drop.is_live())
			// qdel rather than a bare list removal: the record holds a hard reference to
			// its planet, and Destroy() is what drops it.
			qdel(drop)
			continue
		count++
	return count

/**
 * Why this player cannot take a hardcore drop right now, or null if they can.
 *
 * The string is shown to the player, so it says what is actually wrong. Asked twice - by
 * the join menu to label the button, and again by attempt_hardcore_drop() before anything
 * is committed, because the answer can change while somebody reads the menu.
 */
/proc/hardcore_drop_refusal(mob/user)
	if(!CONFIG_GET(flag/hardcore_drop))
		return "Hardcore drops are not enabled on this server."
	if(!SSticker?.IsRoundInProgress())
		return "The round is either not ready, or has already finished."
	if(SSlag_switch.measures[DISABLE_NON_OBSJOBS])
		return "An administrator has disabled late join spawning."

	var/cap = CONFIG_GET(number/hardcore_drop_max_active)
	if(cap && hardcore_drops_active() >= cap)
		return "Every surveyable world is already carrying a castaway. Try again later, or join a crew."

	var/cooldown = CONFIG_GET(number/hardcore_drop_cooldown_minutes)
	if(cooldown && user?.ckey)
		var/last = GLOB.hardcore_drop_last_use[user.ckey]
		if(last && world.time < last + (cooldown MINUTES))
			var/wait = round((last + (cooldown MINUTES) - world.time) / 600, 1)
			return "You dropped recently. Another drop opens up in about [max(wait, 1)] minute[wait == 1 ? "" : "s"]."

	// Cheap last, and only the "is there anything at all" half of the question - the real
	// pick happens after the player commits, since it can sleep behind the worldgen queue.
	if(!length(hardcore_drop_planet_candidates()))
		return "No charted world is habitable enough to drop onto right now."

	return null

/**
 * Every planet contact a castaway could be dropped onto.
 *
 * Habitable type, still on the overmap grid, not mid-teardown, and not already carrying a
 * castaway. Zone band is NOT filtered here - see pick_hardcore_drop_planet(), which sorts
 * on it rather than excluding, so a round whose only jungle sits in a red band still has
 * somewhere to send people.
 */
/proc/hardcore_drop_planet_candidates()
	var/list/obj/structure/overmap/planet/candidates = list()
	var/list/taken = list()
	for(var/datum/hardcore_drop/drop as anything in GLOB.hardcore_drops)
		if(drop.is_live() && drop.planet)
			taken += drop.planet

	for(var/obj/structure/overmap/planet/candidate as anything in GLOB.overmap_planets)
		if(QDELETED(candidate) || (candidate in taken))
			continue
		if(!(candidate.planet in GLOB.hardcore_drop_planet_types))
			continue
		// Off the grid means docked-into or mid-relocation; either way it is not a place
		// to aim a pod at.
		if(!istype(get_turf(candidate), /turf/open/overmap))
			continue
		if(candidate.unloading || candidate.concerned)
			continue
		candidates += candidate
	return candidates

/**
 * The planet to drop this player onto, or null if there is nothing suitable.
 *
 * Prefers, in order:
 *
 * 1. A world that is ALREADY generated. It costs no map slot, no worldgen queue time and
 *    no minute of waiting, and - the point of the whole ordering - it is a world some
 *    crew has been to, which is where a castaway has the best chance of being found.
 * 2. Failing that, an ungenerated one in the safest zone band available, because a fresh
 *    build is the expensive case and a green-band world is the one whose fauna and
 *    weather a person with a toolbox can actually survive.
 *
 * Loaded planets are shuffled rather than sorted so two drops in the same minute do not
 * both pile onto whichever world happens to be first in GLOB.overmap_planets.
 */
/proc/pick_hardcore_drop_planet()
	var/list/obj/structure/overmap/planet/candidates = hardcore_drop_planet_candidates()
	if(!length(candidates))
		return null

	var/list/obj/structure/overmap/planet/loaded = list()
	for(var/obj/structure/overmap/planet/candidate as anything in candidates)
		if(candidate.is_loaded() && candidate.mapzone)
			loaded += candidate
	if(length(loaded))
		return pick(loaded)

	// Nothing charted yet: rank the rest by how dangerous their neighbourhood is. A null
	// zone type (zones not assigned yet, or a planet somewhere odd) sorts as the worst
	// option rather than the best, so it is only ever the fallback.
	var/obj/structure/overmap/planet/best
	var/best_zone = INFINITY
	for(var/obj/structure/overmap/planet/candidate as anything in shuffle(candidates))
		var/zone = SSovermap_zones?.get_zone_type(get_turf(candidate)) || ZONE_RED
		if(zone < best_zone)
			best_zone = zone
			best = candidate
	return best

/**
 * A clear open turf on this planet's surface to put a pod down on.
 *
 * Deliberately parallel to /datum/mission_target/planet/get_spawn_turf() rather than
 * shared with it, and it keeps that proc's two hard-won exclusions:
 *
 * * **The southern dock strip is off limits.** Both reserve berths sit along the bottom
 *   of the footprint, and a hull setting down copies its deck over every turf it lands
 *   on. Living things are now shoved clear rather than crushed (see
 *   evict_landing_stowaways(), code/modules/shuttle/mobile_port/shuttle_move.dm), but
 *   anything a castaway BUILT there is still flattened, and being teleported out from
 *   under an arriving ship is a poor first impression of the round.
 * * **Shuttle areas are off limits.** A hull parked on the surface has open, undense,
 *   perfectly samplable floor, and a castaway who materialises inside somebody's ship is
 *   carried off the world the moment it lifts.
 *
 * Sampled from the FOOTPRINT, not the z-level: up to four planets share a level, and the
 * level's bounds span all of them.
 */
/obj/structure/overmap/planet/proc/get_hardcore_landing_turf()
	if(!mapzone || !length(mapzone.z_levels))
		return null
	var/datum/space_level/level = mapzone.z_levels[1]
	if(!level)
		return null

	var/has_footprint = footprint && !isnull(footprint.low_x) && footprint.z_value
	var/site_z = has_footprint ? footprint.z_value : level.z_value
	var/margin = 12
	var/min_x = (has_footprint ? footprint.low_x : level.low_x) + margin
	var/max_x = (has_footprint ? footprint.high_x : level.high_x) - margin
	var/min_y = (has_footprint ? footprint.low_y : level.low_y) + margin
	var/max_y = (has_footprint ? footprint.high_y : level.high_y) - margin

	// get_dock_strip_top_y() is an ABSOLUTE y measured from the site's own low edge, the
	// same corner create_docking_ports() anchors the berths on, so it is used as-is.
	var/dock_strip_top = get_dock_strip_top_y(level)
	if(!isnull(dock_strip_top) && (dock_strip_top + 1) < max_y)
		min_y = max(min_y, dock_strip_top + 1)
	if(min_x > max_x || min_y > max_y)
		return null

	for(var/attempt in 1 to 60)
		var/turf/candidate = locate(rand(min_x, max_x), rand(min_y, max_y), site_z)
		if(!candidate || !isopenturf(candidate) || isspaceturf(candidate))
			continue
		// Groundless turfs are the planet's water and chasms - a pod dropped on one puts
		// its occupant straight through the floor.
		if(isgroundlessturf(candidate))
			continue
		if(istype(get_area(candidate), /area/shuttle))
			continue
		if(candidate.is_blocked_turf(exclude_mobs = TRUE))
			continue
		return candidate
	return null
