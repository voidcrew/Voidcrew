/**
 * VOIDCREW ADDITION: what happens to somebody who comes off a ship in flight.
 *
 * A voidcrew ship spends its whole overmap flight parked on a transit dock, so its hull is
 * physically standing in a 16-tile hyperspace corridor (SHUTTLE_TRANSIT_BORDER) on the
 * reservation z-level. Step out of an airlock mid-flight and you are in that corridor.
 *
 * Upstream's answer to that was hyperspace drift shoving you to the corridor's edge and
 * dump_in_space() teleporting you to a random CROSSLINKED z-level. In this fork those are
 * the "Ruin Area"/"Empty Area" levels SSmapping mints at boot and nothing else ever uses:
 * uninitialised /turf/open/space/basic from corner to corner, no lighting, no content, and
 * - because setup_map_transitions() is a no-op here - not even working edge transitions.
 * Landing on one is a permanent softlock. There is no gravity and nothing to push off, so
 * Process_Spacemove() returns FALSE forever and the mob cannot take a single step for the
 * rest of the round.
 *
 * Two changes, both of which this file owns:
 *
 * 1. A grace zone. Within HYPERSPACE_HULL_GRACE_RANGE tiles of a hull, hyperspace does not
 *    take hold of you. That is ALL it does: the tiles are still vacuum and you still move
 *    by pushing off the hull like anywhere else in space. It buys you the chance to get
 *    back to the airlock instead of being dragged off the instant you step out. Drift past
 *    it and hyperspace has you, exactly as before.
 *
 * 2. Somewhere real to land. find_overboard_landing() only ever picks a place that is
 *    actually loaded and that somebody could plausibly reach you at: a site with players
 *    standing on it, another ship's hull, or a loaded planet or ruin a ship can fly to.
 *    Space landings are always placed against something solid, so the castaway can push off
 *    and move. Ground landings are a fall from orbit, and break every bone you have.
 */

/// How far outside a hull's rectangle hyperspace still lets you hold on.
#define HYPERSPACE_HULL_GRACE_RANGE 2
/// Turfs sampled inside a candidate site before we give up on it and try the next one.
#define OVERBOARD_SAMPLE_TRIES 256
/// How far out from a hull we will look for a tile to put a castaway on.
#define OVERBOARD_HULL_SEARCH_RANGE 3
/// Pixels above the ground a planetfall's sprite starts its drop from.
#define OVERBOARD_FALL_HEIGHT 480
/// How long that drop takes.
#define OVERBOARD_FALL_TIME (1.2 SECONDS)

/**
 * The ship whose hull `checked` is within `grip_range` tiles of, or null.
 *
 * `require_hyperspace` is what keeps the grace zone honest, and it is load-bearing: only a
 * hyperspace tile counts, so a rider set down beside the same hull once it has DOCKED reads
 * as out of its lee and drops the grip, rather than keeping one alive at a berth forever.
 * The origin lookup in voidcrew_dump_in_space() wants the plain geometric answer and passes
 * FALSE.
 *
 * Walks the mobile ports rather than the stationary ones because there are a couple of
 * dozen of the former and hundreds of the latter, and the z filter throws out all but the
 * handful of ships actually in flight.
 */
/proc/hyperspace_hull_near(turf/checked, grip_range = HYPERSPACE_HULL_GRACE_RANGE, require_hyperspace = TRUE)
	if(!isturf(checked))
		return null
	if(require_hyperspace && !istype(checked, /turf/open/space/transit))
		return null
	var/checked_z = checked.z
	for(var/obj/docking_port/mobile/hull as anything in SSshuttle.mobile_docking_ports)
		if(QDELETED(hull) || hull.z != checked_z)
			continue
		// return_coords() reports the rectangle's corners, but which corner is which
		// depends on the port's facing - so neither pair is guaranteed to be the low one.
		var/list/coords = hull.return_coords()
		if(!ISINRANGE(checked.x, min(coords[1], coords[3]) - grip_range, max(coords[1], coords[3]) + grip_range))
			continue
		if(!ISINRANGE(checked.y, min(coords[2], coords[4]) - grip_range, max(coords[2], coords[4]) + grip_range))
			continue
		return hull
	return null

/**
 * Marks a movable as standing in the lee of a hull in hyperspace.
 *
 * Granted by /turf/open/space/transit/initialize_drifting() instead of the shuttle_cling
 * that would otherwise drag the holder off, and dropped again the moment they are no
 * longer beside the hull - at which point hyperspace gets them after all.
 *
 * It grants NOTHING else. The grace zone is vacuum like any other: no gravity, no walking
 * on it, and getting anywhere still means pushing off the hull or having a jetpack. The
 * only thing it takes away is the hyperspace pull. Somebody who shoves off carelessly and
 * ends up drifting in open corridor with nothing in reach is in exactly the spot space has
 * always put them, and their ship arriving is what gets them out of it - see follow_anchor().
 */
/datum/component/hyperspace_hull_grip
	/// The hull we are keeping station with.
	var/obj/docking_port/mobile/anchor
	/// Pending follow_anchor() call, so a deleted grip does not keep a callback alive.
	var/follow_timer

/datum/component/hyperspace_hull_grip/Initialize(obj/docking_port/mobile/holding)
	. = ..()
	if(!ismovable(parent) || QDELETED(holding))
		return COMPONENT_INCOMPATIBLE

	anchor = holding
	// Whatever hyperspace already had hold of us lets go now that we are back in the lee
	// of a hull, and its drift loop stops with it.
	qdel(parent.GetComponent(/datum/component/shuttle_cling))

	RegisterSignal(parent, COMSIG_MOVABLE_MOVED, PROC_REF(on_moved))
	RegisterSignal(anchor, COMSIG_MOVABLE_MOVED, PROC_REF(on_anchor_moved))
	RegisterSignal(anchor, COMSIG_QDELETING, PROC_REF(on_anchor_deleted))

/datum/component/hyperspace_hull_grip/Destroy(force)
	if(follow_timer)
		deltimer(follow_timer)
		follow_timer = null
	if(anchor)
		UnregisterSignal(anchor, list(COMSIG_MOVABLE_MOVED, COMSIG_QDELETING))
		anchor = null
	return ..()

/datum/component/hyperspace_hull_grip/proc/on_moved(datum/source)
	SIGNAL_HANDLER

	var/turf/standing = get_turf(parent)
	if(hyperspace_hull_near(standing) == anchor)
		return
	release_grip(standing)

/**
 * The hull moved out from under us - it dropped out of hyperspace, or was towed.
 *
 * Deferred by a tick because the shuttle move is still running: the deck at the far end is
 * laid down turf by turf and cleanup_runway() has not run yet, so there is nothing worth
 * looking at until it settles.
 */
/datum/component/hyperspace_hull_grip/proc/on_anchor_moved(datum/source)
	SIGNAL_HANDLER
	follow_timer = addtimer(CALLBACK(src, PROC_REF(follow_anchor)), 1 SECONDS, TIMER_UNIQUE|TIMER_OVERRIDE|TIMER_STOPPABLE)

/datum/component/hyperspace_hull_grip/proc/on_anchor_deleted(datum/source)
	SIGNAL_HANDLER
	release_grip(get_turf(parent))

/// Ride the hull out of hyperspace - you were holding on when it arrived, so you arrived.
/datum/component/hyperspace_hull_grip/proc/follow_anchor()
	follow_timer = null
	if(QDELETED(src) || QDELETED(parent))
		return

	var/atom/movable/rider = parent
	var/turf/standing = get_turf(rider)
	if(hyperspace_hull_near(standing) == anchor)
		return // still in its lee, so nothing actually left us behind

	if(QDELETED(anchor) || !anchor.z)
		release_grip(standing)
		return

	var/turf/berth = find_hull_side_turf(anchor, rider)
	if(!berth)
		release_grip(standing)
		return

	to_chat(rider, span_warning("[anchor] drops out of hyperspace, and you are still holding on to it."))
	// The move drops the grip through on_moved(), which is what we want: past the corridor
	// there is a hull wall to push off instead.
	rider.forceMove(berth)

/**
 * Let go. Hyperspace takes over again if we are still standing in it.
 *
 * The transit turf only hands out a cling on Entered, and someone whose ship left from
 * under them has not entered anything - without this they would float in an empty corridor
 * indefinitely.
 */
/datum/component/hyperspace_hull_grip/proc/release_grip(turf/standing)
	var/atom/movable/slipping = parent
	qdel(src)
	if(QDELETED(slipping))
		return
	if(!istype(standing, /turf/open/space/transit) || HAS_TRAIT(slipping, TRAIT_HYPERSPACED))
		return
	if(HAS_TRAIT(standing, TRAIT_HYPERSPACE_STOPPED))
		return
	slipping.AddComponent(/datum/component/shuttle_cling, REVERSE_DIR(standing.dir))

/**
 * Whether a castaway can be set down on this turf at all.
 *
 * `need_gravity` is the ground-landing test: a turf that pulls you down is somewhere you
 * can stand up and walk, which is the whole reason a planet counts as a survivable place
 * to end up.
 */
/proc/overboard_turf_is_safe(turf/candidate, atom/movable/castaway, need_gravity = FALSE)
	if(!isturf(candidate) || isclosedturf(candidate))
		return FALSE
	// Reservation stock that has not been dealt to anybody. It is real ground right up
	// until the next site claims the block and paints over whoever is standing on it.
	if(candidate.turf_flags & UNUSED_RESERVATION_TURF)
		return FALSE
	var/area/spot = get_area(candidate)
	if(isnull(spot) || (spot.area_flags & NOTELEPORT))
		return FALSE
	// Never inside somebody's hull. The hyperspace corridor is the one shuttle area that
	// is fair game, because that is where a hull's own castaways belong.
	if(istype(spot, /area/shuttle) && !istype(spot, /area/shuttle/transit))
		return FALSE
	// ...and only for a living castaway, who gets the hull grace zone out of
	// initialize_drifting() and a chance to get back to an airlock. Nothing else does: loose
	// cargo set down on a hyperspace tile picks up a /datum/component/shuttle_cling on the
	// next Entered, gets thrown to the edge of the corridor, and the transit turf's Exited()
	// dumps it again the moment it leaves - so it ping-pongs between hulls for the rest of
	// the round. Debris falls through to upstream's random CROSSLINKED throw instead, which
	// is a fine place for an object even though it is a softlock for a person.
	if(!isliving(castaway) && istype(candidate, /turf/open/space/transit))
		return FALSE
	if(candidate.is_blocked_turf(exclude_mobs = TRUE, source_atom = castaway))
		return FALSE
	if(need_gravity && !candidate.has_gravity())
		return FALSE
	return TRUE

/**
 * Whether somebody left floating here could actually move.
 *
 * Mirrors what /mob/get_spacemove_backup() will accept as something to push off: a closed
 * turf, a lattice, or an anchored dense object. Landing anyone in open vacuum without one
 * of those in reach is the exact softlock this file exists to end.
 */
/proc/overboard_turf_has_handhold(turf/candidate)
	for(var/atom/handhold as anything in range(1, candidate))
		if(isclosedturf(handhold))
			return TRUE
		if(!isobj(handhold))
			continue
		var/obj/object = handhold
		if(istype(object, /obj/structure/lattice))
			return TRUE
		if(object.anchored && object.density)
			return TRUE
	return FALSE

/// A free tile just outside a hull's rectangle, with the hull itself to hold on to.
/proc/find_hull_side_turf(obj/docking_port/mobile/hull, atom/movable/castaway)
	if(QDELETED(hull) || !hull.z)
		return null
	var/list/coords = hull.return_coords()
	var/low_x = min(coords[1], coords[3])
	var/high_x = max(coords[1], coords[3])
	var/low_y = min(coords[2], coords[4])
	var/high_y = max(coords[2], coords[4])
	var/hull_z = hull.z

	// Outward ring by ring, so a castaway ends up as close to the hull as the wreckage
	// around it allows.
	for(var/depth in 1 to OVERBOARD_HULL_SEARCH_RANGE)
		var/list/turf/ring = list()
		for(var/scan_x in (low_x - depth) to (high_x + depth))
			var/turf/below = locate(scan_x, low_y - depth, hull_z)
			var/turf/above = locate(scan_x, high_y + depth, hull_z)
			if(below)
				ring += below
			if(above)
				ring += above
		for(var/scan_y in (low_y - depth + 1) to (high_y + depth - 1))
			var/turf/west = locate(low_x - depth, scan_y, hull_z)
			var/turf/east = locate(high_x + depth, scan_y, hull_z)
			if(west)
				ring += west
			if(east)
				ring += east

		for(var/turf/candidate as anything in shuffle(ring))
			if(!overboard_turf_is_safe(candidate, castaway))
				continue
			if(!candidate.has_gravity() && !overboard_turf_has_handhold(candidate))
				continue
			return candidate
	return null

/**
 * A free tile inside one site's rectangle.
 *
 * A planet is ground: anywhere you can stand up on will do, and the caller turns that into
 * a fall from orbit. Everything else - space ruins, outposts, asteroid fields - only offers
 * the vacuum AROUND it, so the tile has to be open space with the structure in arm's reach.
 * Deliberately never the inside of one: a sealed ruin's interior is somewhere a crew is
 * meant to cut their way into, not somewhere hyperspace posts people.
 */
/proc/find_site_landing(datum/map_footprint/footprint, atom/movable/castaway)
	if(isnull(footprint?.low_x) || !footprint.z_value)
		return null
	var/ground_site = (footprint.tenant_class == MAP_TENANT_CLASS_PLANET)
	for(var/attempt in 1 to OVERBOARD_SAMPLE_TRIES)
		var/turf/candidate = locate(rand(footprint.low_x, footprint.high_x), rand(footprint.low_y, footprint.high_y), footprint.z_value)
		if(!overboard_turf_is_safe(candidate, castaway, need_gravity = ground_site))
			continue
		if(!ground_site && (!isspaceturf(candidate) || !overboard_turf_has_handhold(candidate)))
			continue
		return candidate
	return null

/// Whether anyone alive and playing is aboard this hull.
/proc/hull_has_living_players(obj/docking_port/mobile/hull)
	for(var/mob/player as anything in GLOB.player_list)
		if(!isliving(player))
			continue
		var/mob/living/living_player = player
		if(living_player.stat == DEAD)
			continue
		if(hull.is_in_shuttle_bounds(get_turf(living_player)))
			return TRUE
	return FALSE

/**
 * Where somebody hyperspace has thrown out actually ends up.
 *
 * Only places that are loaded and that somebody could reach them at, in descending order
 * of how likely that is to happen: a site with crew standing on it, another ship in the
 * sector, then the loaded planets and ruins any ship can fly to. Never the ship they just
 * came off - the point of falling out is that you are no longer aboard.
 */
/proc/find_overboard_landing(atom/movable/castaway, obj/docking_port/mobile/origin)
	var/list/crewed_hulls = list()
	var/list/quiet_hulls = list()
	for(var/obj/structure/overmap/ship/ship as anything in SSovermap.simulated_ships)
		var/obj/docking_port/mobile/hull = ship.shuttle
		if(QDELETED(hull) || !hull.z || hull == origin)
			continue
		// NPC hulls are not a rescue. Nobody aboard one is going to open an airlock for a
		// castaway, and it flies off with them still stuck to the outside of it.
		if(istype(ship, /obj/structure/overmap/ship/npc))
			continue
		if(hull_has_living_players(hull))
			crewed_hulls += hull
		else
			quiet_hulls += hull

	var/list/crewed_sites = list()
	var/list/quiet_sites = list()
	for(var/datum/map_zone/zone as anything in SSovermap.map_zones)
		for(var/datum/map_footprint/footprint as anything in zone.slots)
			if(isnull(footprint) || isnull(footprint.low_x) || !footprint.z_value)
				continue
			if(QDELETED(footprint.owner))
				continue
			if(footprint.has_living_players())
				crewed_sites += footprint
			else
				quiet_sites += footprint

	// Last resort is the hull they just came off. A one-ship sector with nothing loaded in
	// it has nowhere else at all, and being thrown back against your own hull is a far
	// better outcome than the alternative this whole file exists to stop.
	var/list/last_resort = origin ? list(origin) : list()

	for(var/list/tier as anything in list(crewed_sites, crewed_hulls, quiet_sites, quiet_hulls, last_resort))
		for(var/candidate as anything in shuffle(tier))
			var/turf/landing
			if(istype(candidate, /obj/docking_port/mobile))
				landing = find_hull_side_turf(candidate, castaway)
			else
				landing = find_site_landing(candidate, castaway)
			if(landing)
				return landing
	return null

/**
 * A fall from orbit. You live, and nothing you have is where it should be any more.
 *
 * The mob is already standing on the impact tile - what is animated is the sprite, lifted
 * to OVERBOARD_FALL_HEIGHT and dropped onto it on an accelerating curve, the same trick
 * supplypod uses for a podfall. That way the landing reads as a landing to everyone
 * watching (and to the faller, whose eye is on the tile they are coming down onto) instead
 * of somebody blinking into existence already broken.
 */
/proc/overboard_planetfall(mob/living/castaway, turf/impact)
	castaway.visible_message(
		span_boldwarning("[castaway] comes down out of the sky!"),
		span_userdanger("The ground comes up at you."),
	)
	// Nothing to do about it on the way down, and nothing that lets them walk out of the
	// landing they are in the middle of.
	castaway.Immobilize(OVERBOARD_FALL_TIME, ignore_canstun = TRUE)
	playsound(impact, 'sound/items/weapons/mortar_whistle.ogg', 60, TRUE)

	// Above the scenery for the descent, so a tall structure on the landing tile does not
	// swallow the sprite halfway down. Captured rather than assumed: a mob lying down or
	// riding something is not on its initial() layer.
	var/old_layer = castaway.layer
	castaway.layer = FLY_LAYER
	castaway.pixel_z = OVERBOARD_FALL_HEIGHT
	animate(castaway, pixel_z = castaway.base_pixel_z, time = OVERBOARD_FALL_TIME, easing = QUAD_EASING|EASE_IN)
	addtimer(CALLBACK(GLOBAL_PROC_REF(overboard_planetfall_impact), castaway, impact, old_layer), OVERBOARD_FALL_TIME)

/// The landing itself, once the sprite has actually reached the ground.
/proc/overboard_planetfall_impact(mob/living/castaway, turf/impact, old_layer)
	if(QDELETED(castaway))
		return
	castaway.layer = old_layer
	castaway.pixel_z = castaway.base_pixel_z

	castaway.visible_message(
		span_boldwarning("[castaway] hits the ground hard enough to hear."),
		span_userdanger("You hit the ground. You feel bones break all over your body."),
	)
	new /obj/effect/temp_visual/mook_dust(get_turf(castaway))
	playsound(impact, 'sound/effects/wounds/crack1.ogg', 100, TRUE)
	if(iscarbon(castaway))
		var/mob/living/carbon/broken = castaway
		// force_wound_upwards() filters out limbs a compound fracture cannot apply to, so
		// this is safe to run across everything they have.
		for(var/obj/item/bodypart/part as anything in broken.bodyparts)
			part.force_wound_upwards(/datum/wound/blunt/bone/critical, wound_source = "a fall from orbit")
	castaway.Knockdown(20 SECONDS)
	castaway.emote("scream")

/**
 * VOIDCREW ADDITION: the fork's dump_in_space(), called from it before upstream's body.
 *
 * Returns TRUE once the castaway has been placed, FALSE to let upstream's random
 * CROSSLINKED-level throw run - which now only happens when the round genuinely has
 * nowhere else, i.e. no loaded site and no other ship anywhere in the sector.
 */
/proc/voidcrew_dump_in_space(atom/movable/dumpee)
	if(QDELETED(dumpee))
		return FALSE

	// Which ship's hyperspace corridor this came out of, if any. Doubles as the test for
	// whether this IS an overboard at all: dump_in_space() is also how a bluespace anomaly
	// flings people about and how an away-mission cordon throws trespassers back, and
	// neither of those is a fall from orbit.
	var/obj/docking_port/mobile/origin = hyperspace_hull_near(get_turf(dumpee), SHUTTLE_TRANSIT_BORDER, require_hyperspace = FALSE)

	var/turf/destination = find_overboard_landing(dumpee, origin)
	if(!destination)
		return FALSE

	dumpee.pulledby?.stop_pulling()
	dumpee.stop_pulling()
	dumpee.forceMove(destination)

	if(!isliving(dumpee))
		return TRUE

	var/mob/living/castaway = dumpee
	if(origin && destination.has_gravity())
		overboard_planetfall(castaway, destination)
	else if(origin)
		to_chat(castaway, span_userdanger("Hyperspace throws you out somewhere else entirely."))
	log_shuttle("[key_name(castaway)] was dumped out of [origin ? "[origin]'s hyperspace corridor" : "space"] and landed at [AREACOORD(destination)].")
	return TRUE

#undef HYPERSPACE_HULL_GRACE_RANGE
#undef OVERBOARD_SAMPLE_TRIES
#undef OVERBOARD_HULL_SEARCH_RANGE
#undef OVERBOARD_FALL_HEIGHT
#undef OVERBOARD_FALL_TIME
