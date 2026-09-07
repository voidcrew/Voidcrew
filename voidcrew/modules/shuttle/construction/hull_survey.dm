/**
 * Hull Survey
 *
 * Tool-free, in-person hull claiming. A player seals a room out of whatever is to
 * hand - rock, plating, plastitanium, it makes no difference - stands inside it, and
 * uses the Survey Hull action. If the enclosure adjoins a ship, it is integrated into
 * that hull. If it does not adjoin one but contains a helm console, it is commissioned
 * as a new vessel.
 *
 * Both outcomes run the same survey and the same validation; only the commit differs.
 * The shared validators here are also what the ship construction console calls, so the
 * drone and the action can never disagree about what is legal.
 *
 * Airtightness is the only structural requirement, and it is measured strictly as "can air
 * get out": walls, full-tile windows, thin directional windows and closed airlocks all seal
 * equally. That is what lets a crew build a ship out of a sealed cave, and what lets a room
 * hang off an existing hull's wall rather than having to be a free-standing box beside it.
 */

/// Largest enclosure a single survey will claim, in tiles.
#define HULL_SURVEY_MAX_TILES 300
/// How long the survey takes, in-person, before it commits.
#define HULL_SURVEY_DURATION (6 SECONDS)

// ============================================
// Sizing
// ============================================

/**
 * The reserve-dock fit rule, in one place.
 *
 * Encounter berths are allocated as RESERVE_DOCK_MAX_SIZE_LONG x RESERVE_DOCK_MAX_SIZE_SHORT
 * rectangles (see outpost_hangar.dm), and adjust_reserve_dock_to_shuttle() rotates the berth
 * to align its long side with the hull's long side before docking. So the test is symmetric:
 * the hull's longer axis has to fit the berth's long side and its shorter axis the short side.
 *
 * This is the same comparison the dock-time gates make against shuttle.width/height
 * (player_outpost.dm, outpost.dm, colosseum_site.dm). A hull that fails it can still fly,
 * but can never be given a dock at a planet, ruin or outpost - which is a soft-lock, not an
 * inconvenience. Anything that grows a hull must check this BEFORE it commits, because
 * neither create_shuttle() nor expand_shuttle() can be rolled back.
 */
/proc/hull_dimensions_fit(x_extent, y_extent)
	if(max(x_extent, y_extent) > RESERVE_DOCK_MAX_SIZE_LONG)
		return FALSE
	if(min(x_extent, y_extent) > RESERVE_DOCK_MAX_SIZE_SHORT)
		return FALSE
	return TRUE

/**
 * Map-axis extents of a claim: the bounding box of `turfs`, unioned with `port`'s current
 * footprint when we are expanding an existing hull.
 *
 * Works in absolute map x/y rather than the port's local width/height. That is safe here
 * *only* because hull_dimensions_fit() is symmetric - calculate_docking_port_information()
 * swaps width and height for an EAST/WEST facing port, so {width, height} and
 * {x_extent, y_extent} are the same pair of numbers in some order, and max/min don't care
 * about the order. Do not reuse this for any asymmetric test.
 *
 * Returns list(x_extent, y_extent).
 */
/proc/hull_claim_bounds(list/turfs, obj/docking_port/mobile/port)
	var/min_x = INFINITY
	var/min_y = INFINITY
	var/max_x = 0
	var/max_y = 0

	if(port)
		// return_coords() corner order depends on the port's dir, so normalise it.
		var/list/bounds = port.return_coords()
		min_x = min(bounds[1], bounds[3])
		min_y = min(bounds[2], bounds[4])
		max_x = max(bounds[1], bounds[3])
		max_y = max(bounds[2], bounds[4])

	for(var/turf/claimed as anything in turfs)
		min_x = min(min_x, claimed.x)
		min_y = min(min_y, claimed.y)
		max_x = max(max_x, claimed.x)
		max_y = max(max_y, claimed.y)

	return list((max_x - min_x) + 1, (max_y - min_y) + 1)

/// Human-readable reason a claim busts the berth limits, or null if it fits.
/proc/hull_size_refusal(list/turfs, obj/docking_port/mobile/port)
	var/list/extents = hull_claim_bounds(turfs, port)
	if(hull_dimensions_fit(extents[1], extents[2]))
		return null
	return "Survey rejects the enclosure: the resulting hull would measure \
		[max(extents[1], extents[2])] by [min(extents[1], extents[2])] metres. No berth \
		exceeds [RESERVE_DOCK_MAX_SIZE_LONG] by [RESERVE_DOCK_MAX_SIZE_SHORT]. A hull this \
		size could never dock again."

// ============================================
// Docking port geometry
// ============================================

/**
 * TRUE if `shuttle_area` is in `port`.shuttle_areas but belongs to a different, live ship.
 *
 * Ship-to-ship docking absorbs the guest's areas into the host's shuttle_areas (see
 * reconcile_hull_before_move() in voidcrew/mapping/docking_port/_docking_port.dm). Anything
 * measuring "our own hull" has to skip them, or a host with a guest parked in its bay reads
 * the guest's plating as its own and reports an overhang that does not exist.
 */
/proc/hull_area_is_guest(area/shuttle_area, obj/docking_port/mobile/port)
	var/area/shuttle/voidcrew/voidcrew_area = shuttle_area
	if(!istype(voidcrew_area))
		return FALSE
	return voidcrew_area.shuttle_port && voidcrew_area.shuttle_port != port

/**
 * How far `candidate` lies OUTWARD of the docking port's facing plane, in tiles.
 *
 * A mobile port's dir points INTO the ship, so the hull's outer face - the side that
 * meets a berth - is one step in REVERSE_DIR(port.dir). Positive means the tile is past
 * that face; zero means level with it; negative means safely inboard.
 */
/proc/hull_port_offset(turf/candidate, turf/port_turf, outward_dir)
	if(!candidate || !port_turf)
		return 0
	switch(outward_dir)
		if(NORTH)
			return candidate.y - port_turf.y
		if(SOUTH)
			return port_turf.y - candidate.y
		if(EAST)
			return candidate.x - port_turf.x
		if(WEST)
			return port_turf.x - candidate.x
	return 0

/**
 * The worst overhang anywhere on the hull's docking face.
 *
 * Returns list(offset, turf/worst_tile). An offset of 0 or less is the healthy state:
 * nothing of the hull stands proud of the docking port.
 *
 * Why the whole face and not just the tile in front of the port: docking transplants the
 * hull by planting the mobile port's origin on the berth tile (initiate_docking() ->
 * return_ordered_turfs(new_dock.x, new_dock.y, ...)), and the exit-to-exit berths are laid
 * exactly one tile off the anchor - position_dock_across_from() for ship-to-ship,
 * position_cargo_dock_next_to_ship() for cargo. So ANY hull tile past the port's plane, at
 * any lateral offset, lands inside whatever we are docking to and overwrites it. An L-shaped
 * room bolted onto one quarter of the bow leaves the tile directly ahead of the port clear
 * while still driving its far corner straight through the other ship.
 *
 * canDock() cannot catch this: both berth-placement procs derive the stationary port's
 * dwidth/dheight from the mobile port's own, so its bounds checks compare a number against
 * itself and always pass.
 *
 * Scanning real turfs rather than reading port.dheight is deliberate. Until a hull is first
 * expanded, dheight is measured against the .dmm's whole rectangle, so a hull mapped with a
 * blank row behind its port (scarab, geode) reports dheight 1 while its actual plating is
 * flush. Those blank tiles are not shuttle turfs, never move, and harm nothing.
 *
 * `extra_turfs` are tiles not yet in the hull's areas - a survey claim being checked before
 * it commits.
 */
/proc/hull_port_overhang(obj/docking_port/mobile/port, list/extra_turfs)
	var/turf/port_turf = get_turf(port)
	if(!port_turf)
		return list(0, null)

	var/outward_dir = REVERSE_DIR(port.dir)
	var/worst = 0
	var/turf/worst_turf

	for(var/area/shuttle_area as anything in port.shuttle_areas)
		if(hull_area_is_guest(shuttle_area, port))
			continue
		for(var/turf/hull_turf as anything in shuttle_area.get_turfs_by_zlevel(port_turf.z))
			var/offset = hull_port_offset(hull_turf, port_turf, outward_dir)
			if(offset > worst)
				worst = offset
				worst_turf = hull_turf

	for(var/turf/claimed as anything in extra_turfs)
		if(claimed.z != port_turf.z)
			continue
		var/offset = hull_port_offset(claimed, port_turf, outward_dir)
		if(offset > worst)
			worst = offset
			worst_turf = claimed

	return list(worst, worst_turf)

/**
 * TRUE when any of `port`'s hull stands proud of the port's own plane.
 *
 * The same question ship_port_clear_to_berth() answers, minus the log line: that proc is
 * called where a berth is actually being placed, and one line per refusal is exactly what
 * you want there. This one is for callers asking on a player action - the cargo console
 * refusing an order - where logging a line per click buries the shuttle log.
 *
 * Not cheap either way: the scan walks every turf of every hull area. Ask it on an action,
 * never on a UI refresh.
 */
/proc/hull_overhangs_port(obj/docking_port/mobile/port)
	if(!port)
		return FALSE
	var/list/overhang = hull_port_overhang(port, null)
	return overhang[1] > 0

/**
 * The door on `candidate`, if it is one the docking port may sit on.
 *
 * Airlocks and firelocks both qualify: either is a walk-through opening in the hull skin,
 * and either can carry the tiny fan that holds the ship's air in while the door cycles (see
 * reset_fans()). Blast doors are excluded - they are bulkheads, not gangways, and a crew
 * transferring between two docked ships cannot be asked to cut through one.
 */
/proc/is_hull_port_door(obj/machinery/door/candidate)
	if(!istype(candidate))
		return FALSE
	if(istype(candidate, /obj/machinery/door/poddoor))
		return FALSE
	return istype(candidate, /obj/machinery/door/airlock) || istype(candidate, /obj/machinery/door/firedoor)

/// The first door on `candidate` the port may sit on, or null.
/proc/hull_port_door(turf/candidate)
	if(!candidate)
		return null
	for(var/obj/machinery/door/found in candidate)
		if(is_hull_port_door(found))
			return found
	return null

/**
 * Every turf of `port`'s own hull on the port's z, flattened into one list.
 *
 * The face search below measures four faces; without this it would walk the hull's areas
 * four times over. `extra_turfs` are tiles not yet in the hull's areas - a survey claim being
 * checked before it commits - and guest areas are skipped for the same reason
 * hull_port_overhang() skips them: another ship parked inside our area list is not our hull.
 */
/proc/hull_port_turfs(obj/docking_port/mobile/port, list/extra_turfs, hull_z)
	var/list/hull_turfs = list()
	for(var/area/shuttle_area as anything in port.shuttle_areas)
		if(hull_area_is_guest(shuttle_area, port))
			continue
		hull_turfs += shuttle_area.get_turfs_by_zlevel(hull_z)
	for(var/turf/claimed as anything in extra_turfs)
		if(claimed.z == hull_z)
			hull_turfs += claimed
	return hull_turfs

/**
 * The door standing on the outermost line of one face of the hull, or null.
 *
 * "Outermost" is the whole rule. Seating the port on a tile that still has hull in front of
 * it leaves that hull to be driven through whatever the ship berths against - see
 * hull_port_overhang() - so a candidate has to hold the extreme coordinate for `outward_dir`
 * across the entire hull, and carry a door a crew can actually walk through.
 *
 * Ties within a face go to the door closest to the port's current lateral position, so a bow
 * with doors at both ends keeps the port roughly where the crew expect it.
 */
/proc/hull_face_port_seat(list/hull_turfs, outward_dir, turf/port_turf)
	if(!length(hull_turfs) || !port_turf)
		return null

	// TRUE when the face is an east or west one, so the coordinate that decides "outermost"
	// is x and the lateral axis the ties are measured along is y.
	var/across = EWCOMPONENT(outward_dir)
	var/extreme
	for(var/turf/hull_turf as anything in hull_turfs)
		var/coordinate = across ? hull_turf.x : hull_turf.y
		if(isnull(extreme))
			extreme = coordinate
		else if(outward_dir & (NORTH|EAST))
			extreme = max(extreme, coordinate)
		else
			extreme = min(extreme, coordinate)

	var/turf/best
	var/best_distance = INFINITY
	for(var/turf/candidate as anything in hull_turfs)
		if((across ? candidate.x : candidate.y) != extreme)
			continue
		if(!hull_port_door(candidate))
			continue
		// Lateral only - every candidate is on the same plane, so the outward component
		// is identical and get_dist() would just add the same constant to all of them.
		var/distance = across ? abs(candidate.y - port_turf.y) : abs(candidate.x - port_turf.x)
		if(distance < best_distance)
			best_distance = distance
			best = candidate

	return best

/**
 * Where the docking port should move to, and which way it should then face, so that the hull
 * stops standing proud of it.
 *
 * Returns list(turf/seat, outward_dir), or null. `outward_dir` is the direction the seat's
 * door opens onto; the port's own dir is the reverse of it, because a mobile port faces INTO
 * its ship.
 *
 * The face the port already uses is tried first and wins outright when it has a door on its
 * outermost line: a hull that can keep berthing through its bow should keep berthing through
 * its bow. Only when that face offers nothing does the search widen, and a door on another
 * face then qualifies on exactly the same terms - it has to stand on the true outermost line
 * of ITS face, so nothing of the hull is left in front of the port once it has turned.
 * Between faces the smaller turn wins (a beam before the stern); between two equal turns, the
 * nearer door.
 *
 * Widening it is what issue #130 actually needed. A crew that grew a hull out past its bow
 * while leaving a perfectly good airlock amidships on the port beam was refused outright,
 * even though berthing through that beam door is clean - the geometry only cares that nothing
 * of the hull stands in front of the port, not which compass point the port happens to face.
 *
 * `allow_face_change = FALSE` restores the old same-face-only answer, which is what
 * hull_port_reseat_target() hands its callers.
 */
/proc/hull_port_reseat_plan(obj/docking_port/mobile/port, list/extra_turfs, allow_face_change = TRUE)
	var/turf/port_turf = get_turf(port)
	if(!port_turf)
		return null

	var/list/overhang = hull_port_overhang(port, extra_turfs)
	if(overhang[1] <= 0)
		return null

	var/list/hull_turfs = hull_port_turfs(port, extra_turfs, port_turf.z)
	var/current_outward = REVERSE_DIR(port.dir)

	var/turf/same_face = hull_face_port_seat(hull_turfs, current_outward, port_turf)
	if(same_face)
		return list(same_face, current_outward)
	if(!allow_face_change)
		return null

	var/turf/best
	var/best_outward
	var/best_turn = INFINITY
	var/best_distance = INFINITY
	for(var/outward_dir in GLOB.cardinals)
		if(outward_dir == current_outward)
			continue
		var/turf/candidate = hull_face_port_seat(hull_turfs, outward_dir, port_turf)
		if(!candidate)
			continue
		// 90 for either beam, 180 for the stern. Signed difference folded onto [-180, 180]
		// and then taken absolute, so a turn left and a turn right cost the same.
		var/turn_cost = abs(SIMPLIFY_DEGREES(dir2angle(outward_dir) - dir2angle(current_outward) + 180) - 180)
		// Manhattan rather than get_dist(): the seat is on a different face, so both legs are
		// real distance and a Chebyshev measure would silently drop the smaller one.
		var/distance = abs(candidate.x - port_turf.x) + abs(candidate.y - port_turf.y)
		if(turn_cost > best_turn || (turn_cost == best_turn && distance >= best_distance))
			continue
		best_turn = turn_cost
		best_distance = distance
		best_outward = outward_dir
		best = candidate

	return best ? list(best, best_outward) : null

/**
 * The dir and port_direction a port needs once its door opens onto `outward_dir`.
 *
 * Returns list(new_dir, new_port_direction). One copy of the arithmetic, shared by the
 * construction console's manual relocation and by the survey and drone reseats, because
 * getting it wrong makes a ship turn 90 degrees on every dock and undock for the rest of the
 * round - the failure voidcrew_hull_dock_rotation exists to police on mapped hulls.
 *
 * dir is simply the reverse of the way out. port_direction is ship-relative and cannot be
 * read off world dirs, because a docked ship may be sitting rotated away from its
 * preferred_direction. What IS the same in both frames is how far the port just turned, so
 * rotate the existing port_direction by that delta. (Assuming the ship faced
 * preferred_direction here baked the dock rotation into port_direction, which made the
 * regenerated transit berth match the docked orientation, so the ship never turned back to
 * its original heading on undock.)
 *
 * A seat on the face the port already uses comes back as a no-op: the delta is zero, so both
 * values are returned unchanged.
 */
/proc/hull_port_facing(obj/docking_port/mobile/port, outward_dir)
	var/new_dir = REVERSE_DIR(outward_dir)
	var/angle_diff = SIMPLIFY_DEGREES(dir2angle(new_dir) - dir2angle(port.dir) + dir2angle(port.port_direction))
	return list(new_dir, angle2dir(angle_diff))

/**
 * The tile the docking port should move to WITHOUT turning it.
 *
 * The same-face half of hull_port_reseat_plan(), kept as its own proc for the callers that
 * only ever slide the port along its own face: /obj/structure/overmap/ship/can_undock() calls
 * hull_reseat_port() with no new facing, so handing it a seat on another face would leave the
 * port pointing the wrong way with the hull still standing in front of it. Callers that can
 * turn the port ask for the plan instead.
 *
 * Returns null when the hull does not overhang (nothing to do) or when no door stands on the
 * port's own outermost line.
 */
/proc/hull_port_reseat_target(obj/docking_port/mobile/port, list/extra_turfs)
	var/list/plan = hull_port_reseat_plan(port, extra_turfs, allow_face_change = FALSE)
	return plan ? plan[1] : null

/**
 * Plain-language instructions for the door a reseat is waiting on.
 *
 * The refusal used to say "fit an airlock or a firelock on that face", and "that face" is
 * the one thing a player standing inside a half-built room cannot work out: the ship already
 * has an outer airlock, it is just no longer the outermost thing on that side, so the advice
 * reads as a lie (issue #130). Name the compass face, give the exact plane the door has to
 * stand on, and hand over one set of coordinates that is definitely on it.
 *
 * `worst` is the tile from hull_port_overhang() that stands furthest out - by definition it
 * is on the plane the door has to be on, which is why it is the tile we quote.
 */
/proc/hull_port_door_instruction(obj/docking_port/mobile/port, turf/worst)
	var/facing = dir2text(REVERSE_DIR(port.dir))
	if(isnull(worst))
		return "Build an airlock or a firelock into the outermost [facing] wall."
	var/axis = EWCOMPONENT(REVERSE_DIR(port.dir)) ? "x = [worst.x]" : "y = [worst.y]"
	return "Build an airlock or a firelock on the [facing] face at ([worst.x], [worst.y]). \
		Any tile on the [axis] line will do - that is the outermost plating, and the port has \
		to end up standing on it."

/**
 * Stops a hull that has just grown from silently burying its own docking port.
 *
 * Returns null when there is nothing to say. Otherwise list(turf/reseated_to, text): a null
 * `reseated_to` means the port could not move and the caller should warn rather than report.
 *
 * Growing out past the port cannot be refused at build time. The first tile of a new bow
 * already overhangs, so a build-time refusal would make the outer door that legalises the
 * expansion impossible to build - which is why the hard stop lives on undock instead (see
 * /obj/structure/overmap/ship/can_undock()). What a build *can* do is the bookkeeping the
 * crew would otherwise have to know to do by hand on the construction console's port
 * relocator: if the hull now stands proud of the port and a door is standing on the new
 * outermost plating, move the port onto it. Otherwise say so, in the same words the survey
 * uses, and let the build stand. Before this the drone did neither, so a crew that built out
 * with the console - the one tool that can cure it - was left with a ship cargo refused to
 * deliver to and no hint as to why (issue #130).
 *
 * The port's own face is preferred, but it is not the only one on offer: when nothing stands
 * on the outermost line of the face the port already uses, hull_port_reseat_plan() will take
 * a door on another face provided nothing of the hull stands past it there, and the port is
 * turned to match through the same arithmetic the console's manual relocation uses.
 *
 * Not cheap - hull_port_overhang() walks every turf of every hull area. Callers gate it on
 * the O(1) hull_port_offset() test for the tile they just touched.
 */
/proc/hull_reseat_after_growth(obj/docking_port/mobile/port)
	if(!port)
		return null

	var/list/overhang = hull_port_overhang(port, null)
	if(overhang[1] <= 0)
		return null

	var/old_outward = REVERSE_DIR(port.dir)
	var/facing = dir2text(old_outward)
	var/list/plan = hull_port_reseat_plan(port, null)
	if(!plan)
		return list(null, "Hull warning: the ship now stands [overhang[1]] metre\s out past its \
			docking port on the [facing] side, and there is no door on that outermost plating for \
			the port to move to - nor one standing clear on the outermost line of any other face. \
			[hull_port_door_instruction(port, overhang[2])] Until the port is out there the ship \
			cannot undock and cargo will refuse to deliver, because the overhanging section would \
			be driven through whatever it berths against.")

	var/turf/reseat_to = plan[1]
	var/new_outward = plan[2]
	var/list/new_facing = hull_port_facing(port, new_outward)
	hull_reseat_port(port, reseat_to, new_facing[1], new_facing[2])
	var/obj/machinery/door/reseated_door = hull_port_door(reseat_to)
	log_shuttle("[port] reseated its docking port to ([reseat_to.x], [reseat_to.y]) facing [dir2text(new_outward)] after a construction expansion, clearing a [overhang[1]] tile overhang.")
	var/berth_line = "that door on the [facing] face is now where other ships and the cargo shuttle berth."
	if(new_outward != old_outward)
		// The crew asked for a room, not a new berthing side, so say where to undo it. The
		// port only turns when the face it was on has no clear door left; once it is out here
		// the hull is flush again and nothing will move it back on its own.
		berth_line = "the ship now berths through its [dir2text(new_outward)] face instead of its \
			[facing] one - that is where other ships and the cargo shuttle will come alongside. \
			Fit a door on the outermost [facing] plating and use this console's docking port \
			panel if you want it back on the [facing] face."
	return list(reseat_to, "The hull now stands out past the old docking port. Port reseated to \
		[reseated_door ? "the [reseated_door.name]" : "the outer hull"] at ([reseat_to.x], \
		[reseat_to.y]) - [berth_line]")

/**
 * A bearing the player can actually walk, plus the coordinates to sanity-check it against.
 *
 * get_dist() is a Chebyshev distance and get_dir() is one of eight compass points, so a tile
 * six north and three east came out as "6 metres northeast" - the number was the larger leg
 * and the direction quietly dropped the smaller one. Report both legs instead. (issue #130)
 */
/proc/hull_survey_bearing(turf/standing_on, turf/problem)
	if(isnull(standing_on) || isnull(problem))
		return ""
	if(standing_on.z != problem.z)
		return " The problem is at ([problem.x], [problem.y]), on another level."
	var/north_south = problem.y - standing_on.y
	var/east_west = problem.x - standing_on.x
	if(!north_south && !east_west)
		return " The problem is the tile you are standing on, ([problem.x], [problem.y])."

	var/list/legs = list()
	if(north_south)
		legs += "[abs(north_south)] metre\s [north_south > 0 ? "north" : "south"]"
	if(east_west)
		legs += "[abs(east_west)] metre\s [east_west > 0 ? "east" : "west"]"
	return " The problem is [english_list(legs)] of you, at ([problem.x], [problem.y])."

/**
 * Where a brand-new hull's docking port should be seated, before any port exists.
 *
 * Returns list(turf/seat, outward_dir), or null if the enclosure has no door that can carry
 * a port. `outward_dir` is the direction the finished ship's exit will face.
 *
 * A door qualifies when it stands on the outermost plane of the claim for the direction it
 * faces, so that seating the port there leaves nothing of the hull past it. A door set back
 * in a recess does not qualify: the walls of the recess would still be driven through
 * whatever the ship berths against.
 *
 * The door picks the facing rather than the other way round. The obvious alternative -
 * deriving the facing from the room's aspect ratio and then demanding a door on that
 * particular wall - tells a player their airlock is on the wrong side of the room for
 * reasons nothing in the game explains. Nothing forces the choice anyway: commission_vessel()
 * sets preferred_direction to match whatever facing comes back (see hull_aspect_guess()), so
 * any wall is as good as any other.
 */
/proc/hull_claim_port_seat(list/turfs)
	if(!length(turfs))
		return null

	var/min_x = INFINITY
	var/min_y = INFINITY
	var/max_x = 0
	var/max_y = 0
	for(var/turf/claimed as anything in turfs)
		min_x = min(min_x, claimed.x)
		min_y = min(min_y, claimed.y)
		max_x = max(max_x, claimed.x)
		max_y = max(max_y, claimed.y)

	for(var/outward_dir in GLOB.cardinals)
		// The coordinate a tile must hold to be on this face, and the axis we centre along.
		var/extreme
		var/centre
		switch(outward_dir)
			if(NORTH)
				extreme = max_y
				centre = (min_x + max_x) / 2
			if(SOUTH)
				extreme = min_y
				centre = (min_x + max_x) / 2
			if(EAST)
				extreme = max_x
				centre = (min_y + max_y) / 2
			if(WEST)
				extreme = min_x
				centre = (min_y + max_y) / 2

		var/turf/best
		var/best_distance = INFINITY
		for(var/turf/claimed as anything in turfs)
			// The port tile has to be real deck - dispatch() skips space turfs when it stamps
			// the shuttle skipover, and a port on one never moves with its ship.
			if(isspaceturf(claimed))
				continue
			var/on_face = EWCOMPONENT(outward_dir) ? (claimed.x == extreme) : (claimed.y == extreme)
			if(!on_face)
				continue
			if(!hull_port_door(claimed))
				continue
			var/distance = abs((EWCOMPONENT(outward_dir) ? claimed.y : claimed.x) - centre)
			if(distance < best_distance)
				best_distance = distance
				best = claimed

		if(best)
			return list(best, outward_dir)

	return null

/// TRUE if `candidate` has any cardinal neighbour outside `port`'s areas - i.e. it is on the
/// hull's skin rather than buried inside it.
/proc/hull_turf_on_edge(turf/candidate, obj/docking_port/mobile/port)
	if(!candidate || !port)
		return FALSE
	for(var/check_dir in GLOB.cardinals)
		var/turf/neighbour = get_step(candidate, check_dir)
		if(!neighbour)
			continue
		if(!port.shuttle_areas[get_area(neighbour)])
			return TRUE
	return FALSE

/**
 * Makes sure the tile the docking port sits on has a tiny fan.
 *
 * The port tile is where the ship's air meets vacuum: it is the door a berthed ship opens,
 * and the one that faces empty space the rest of the time. Without a fan there the hull
 * vents the moment it is opened. reset_fans() would put one there, but that is a button
 * somebody has to know to press, and a freshly commissioned ship has no fans at all.
 *
 * `previous` is the tile the port just left. If it has a fan and is no longer on the hull's
 * skin, that fan is moved rather than a second one being made - an interior door left with a
 * fan on it permanently walls the atmos of the two rooms it joins, which is why reset_fans()
 * strips them from anything that is not an edge door.
 *
 * The move is a delete and a rebuild on purpose. /obj/structure/fans only updates its turf's
 * air blockage from Initialize() and Destroy(), so a forceMove()d fan would leave the tile it
 * left still sealed and the tile it arrived on still open - the fan would be decorative, and
 * an interior door would silently keep dividing the ship's atmos.
 *
 * A newly supplied safety fan has no salvage: automatic port seating has no material
 * payment, and must not become a second way to farm iron by rebuilding fans. Moving an
 * existing fan preserves its salvage, including the lack of salvage on a safety fan.
 */
/proc/hull_seat_port_fan(obj/docking_port/mobile/port, turf/destination, turf/previous)
	if(!destination)
		return null

	var/obj/structure/fans/tiny/already_here = locate() in destination
	if(already_here)
		return already_here

	if(previous && previous != destination && !hull_turf_on_edge(previous, port))
		var/obj/structure/fans/tiny/redundant = locate() in previous
		if(redundant)
			var/obj/structure/fans/tiny/moved = new redundant.type(destination)
			moved.buildstacktype = redundant.buildstacktype
			moved.buildstackamount = redundant.buildstackamount
			qdel(redundant)
			return moved

	return new /obj/structure/fans/tiny/port_safety(destination)

/// Supplied automatically when seating a port, without consuming construction materials.
/obj/structure/fans/tiny/port_safety
	desc = "A tiny fan keeping the docking port airtight. This automatic safety fan has no recoverable metal."
	buildstacktype = null

/**
 * The berth orientation adjust_reserve_dock_to_shuttle() will guess for this port.
 *
 * preferred_direction has to equal this or the hull turns 90 degrees on every dock and every
 * undock, forever - the failure the voidcrew_hull_dock_rotation unit test exists to catch on
 * mapped hulls. Mapped hulls hardcode preferred_direction and are checked against this guess;
 * a commissioned hull has no mapper to get it right, so it reads the guess and adopts it.
 *
 * Kept in step with the arithmetic at the top of adjust_reserve_dock_to_shuttle().
 */
/proc/hull_aspect_guess(obj/docking_port/mobile/port)
	var/true_height = port.height
	var/true_width = port.width
	if(EWCOMPONENT(port.port_direction))
		true_height = port.width
		true_width = port.height
	return (true_height > true_width) ? EAST : NORTH

/**
 * Moves a mobile port to `destination`, keeping its facing.
 *
 * Shared by the survey's automatic reseat and the construction console's manual relocation.
 * Facing is deliberately preserved: the port's dir and its ship-relative port_direction have
 * to stay consistent with each other, and holding dir fixed means port_direction needs no
 * adjustment at all. Callers that genuinely turn the port (the console, moving it to a
 * different face of the hull) do that arithmetic themselves before calling here.
 *
 * The stationary port the ship is currently sitting on is dragged along, or the ship would
 * be recorded as docked at a berth its own port no longer stands on.
 *
 * The tiny fan follows the port - see hull_seat_port_fan(). It is done here rather than left
 * to each caller because the fan is not decoration: the port tile is the one that opens onto
 * vacuum, and a reseat that forgets it moves the ship's only unsealed door without sealing it.
 */
/proc/hull_reseat_port(obj/docking_port/mobile/port, turf/destination, new_dir, new_port_direction)
	if(!port || !destination)
		return FALSE

	var/obj/docking_port/stationary/current_dock = port.get_docked()
	var/turf/previous = get_turf(port)

	port.forceMove(destination)
	if(!isnull(new_dir))
		port.dir = new_dir
	if(!isnull(new_port_direction))
		port.port_direction = new_port_direction

	if(current_dock)
		current_dock.forceMove(destination)
		// The drag moves the berth's TILE without touching its dwidth/dheight, so its whole
		// projected rectangle translates with it - as far as the hull's own extent, which is
		// tens of tiles against three tiles of berth padding. Put it back inside the site the
		// berth belongs to before anything reads it.
		clamp_reserve_dock_to_site(current_dock)

	port.calculate_docking_port_information()

	// After calculate_docking_port_information(), so hull_turf_on_edge() reads the footprint
	// the port actually ended up with.
	hull_seat_port_fan(port, destination, previous)

	// The cached transit berth was cut to the old footprint and offsets; regenerate it.
	release_assigned_transit(port)
	return TRUE

// ============================================
// Survey
// ============================================

/**
 * The result of one survey.
 *
 * A datum rather than a bare turf list because the fill learns three things at once - what
 * the claim would take, which hulls it meets, and where it gave up - and every caller needs
 * all three to say anything useful to the player.
 */
/datum/hull_claim
	/// Assoc turf -> TRUE. The air inside the enclosure, plus the barrier turfs holding it in.
	var/list/turfs = list()
	/// Assoc port -> TRUE for hulls the enclosure is atmos-open to (a doorway, an open gap).
	var/list/open_ports = list()
	/// Assoc port -> TRUE for hulls it only meets through a barrier (a shared or abutting wall).
	var/list/touched_ports = list()
	/// Set when the fill gave up. Player-facing text.
	var/refusal
	/// Where it gave up, so the refusal can point at it.
	var/turf/refusal_turf

/// The hull this claim should join, preferring one it is actually open to. Null to commission.
/datum/hull_claim/proc/adjoining_port()
	for(var/obj/docking_port/mobile/port as anything in open_ports)
		return port
	for(var/obj/docking_port/mobile/port as anything in touched_ports)
		return port
	return null

/**
 * Brings one turf's cached atmos adjacency up to date before trusting it as a seal.
 *
 * Outside DEBUG builds CALCULATE_ADJACENT_TURFS only queues the recalculation, so a survey
 * run in the same breath as the last wall going up reads the hole that wall just filled and
 * refuses a room the player is looking straight at. We leave the turf on SSair's queue - the
 * queued entry also carries an excited-group goal that is not ours to drop - and only make
 * sure the cache we are about to read is current. An empty cache also needs rebuilding:
 * raw terrain swaps can leave open ground with no adjacency and no queued rebuild. That
 * is missing data, not proof of an airtight barrier. immediate_calculate_adjacent_turfs()
 * updates both sides of every edge it touches, so doing this per turf covers its neighbours.
 */
/proc/refresh_atmos_adjacency(turf/target)
	if(!TURF_SHARES(target) || (target in SSair.adjacent_rebuild))
		target.immediate_calculate_adjacent_turfs()

/// TRUE if this turf is itself an airtight barrier, and so is part of the hull's skin.
/// Walls, tiles carrying a full-tile window, tiles with a closed airlock on them.
/proc/hull_barrier_turf(turf/candidate)
	return candidate.blocks_air || candidate.density || !TURF_SHARES(candidate)

/**
 * Flood-fills the sealed volume around `origin` and reports what claiming it would mean.
 *
 * Two rules here differ from detect_room(), and between them they were most of why expanding
 * a ship used to mean building a free-standing box alongside it:
 *
 *  - A tile only leaks if air can actually leave it. detect_room() tests its break list
 *    against every neighbour before it tests atmos adjacency, so a room whose skin is thin
 *    directional windows - the tile is inside the room, the window stands on its outward
 *    edge - reads as open to space even though nothing can breathe through it. Here the
 *    barrier test comes first, so anything that stops air seals a hull: walls, full-tile
 *    windows, closed airlocks and thin windows alike.
 *
 *  - A hull turf is a boundary, not a refusal. Air stops at the ship's wall and that wall is
 *    already owned, so we note which ship we met and stop there. That is what lets a new room
 *    use the ship's existing wall, or hang off an open airlock, instead of needing four walls
 *    of its own with a dead gap behind one of them.
 *
 * Always returns a claim; check .refusal.
 */
/proc/survey_enclosure(turf/origin, max_tiles = HULL_SURVEY_MAX_TILES)
	var/datum/hull_claim/claim = new

	if(!origin)
		claim.refusal = "Survey inconclusive: there is nothing here to survey."
		return claim
	if(isshuttleturf(origin))
		claim.refusal = "Survey inconclusive: you are already standing inside a hull. Stand \
			in the space you want to add to it."
		return claim

	var/list/pending = list(origin)
	var/list/interior = list()
	interior[origin] = TRUE

	while(length(pending))
		var/turf/here = pending[1]
		pending.Cut(1, 2)
		claim.turfs[here] = TRUE
		refresh_atmos_adjacency(here)

		// Counted against the whole claim, barriers included, because that is what
		// validate_hull_claim() measures and what the hull actually ends up carrying.
		if(length(claim.turfs) > max_tiles)
			claim.refusal = "Survey rejects the enclosure: it is larger than the \
				[max_tiles] tile limit for a single survey."
			return claim

		// Barriers are collected in all eight directions because a corner wall is only ever
		// diagonal to the room it closes off - miss it and the hull launches without its
		// corners. Leaks and spread stay cardinal: air does not move diagonally, and
		// TURFS_CAN_SHARE calls a diagonal connected whenever the two tiles between it are
		// open, which is a connection the fill always reaches the long way round anyway.
		for(var/check_dir in GLOB.alldirs)
			var/turf/there = get_step(here, check_dir)
			if(!there)
				claim.refusal = "Survey rejects the enclosure: it runs off the edge of the world."
				claim.refusal_turf = here
				return claim

			refresh_atmos_adjacency(there)
			var/air_flows = TURFS_CAN_SHARE(here, there)

			if(isshuttleturf(there))
				var/obj/docking_port/mobile/met = SSshuttle.get_containing_shuttle(there)
				if(met)
					if(air_flows)
						claim.open_ports[met] = TRUE
					else
						claim.touched_ports[met] = TRUE
				continue

			if(!air_flows)
				// Something seals this edge. If the seal is a thin window standing on `here`
				// then `there` is just the outside, and taking it would drag open space into
				// the hull - only claim it when the tile itself is the barrier.
				if(isspaceturf(there) || !hull_barrier_turf(there))
					continue
				if(!hull_claim_area_valid(there))
					claim.refusal = "Survey rejects the enclosure: it seals against ground \
						that cannot be claimed."
					claim.refusal_turf = there
					return claim
				claim.turfs[there] = TRUE
				continue

			if(!(check_dir in GLOB.cardinals))
				continue

			if(isspaceturf(there))
				claim.refusal = "Survey inconclusive: this space is not airtight."
				claim.refusal_turf = there
				return claim
			if(!hull_claim_area_valid(there))
				claim.refusal = "Survey rejects the enclosure: it opens onto ground that \
					cannot be claimed."
				claim.refusal_turf = there
				return claim

			if(interior[there])
				continue
			interior[there] = TRUE
			pending += there

	// The fill only ever looks outward from turfs it walks, and it never walks a barrier, so
	// a room built as its own sealed box standing wall-to-wall with a ship would finish here
	// with no hull recorded at all - the ship is two tiles from the nearest interior turf,
	// with the room's own wall in between. Sweep the finished claim for that case.
	for(var/turf/claimed as anything in claim.turfs)
		for(var/check_dir in GLOB.cardinals)
			var/turf/neighbour = get_step(claimed, check_dir)
			if(!neighbour || !isshuttleturf(neighbour))
				continue
			var/obj/docking_port/mobile/met = SSshuttle.get_containing_shuttle(neighbour)
			if(met && !claim.open_ports[met])
				claim.touched_ports[met] = TRUE

	return claim

/**
 * Is this turf's area one we're allowed to absorb?
 * Space and planetoid exteriors only - never a ruin, never someone else's hull.
 */
/proc/hull_claim_area_valid(turf/candidate)
	var/area/candidate_area = get_area(candidate)
	if(isnull(candidate_area))
		return FALSE
	if(istype(candidate_area, /area/ruin))
		return FALSE
	if(isshuttleturf(candidate))
		return FALSE
	return istype(candidate_area, /area/space) || istype(candidate_area, /area/overmap_encounter/planetoid)

/// TRUE if `candidate` cardinally touches any area belonging to `port`.
/proc/hull_claim_touches_port(turf/candidate, obj/docking_port/mobile/port)
	for(var/check_dir in GLOB.cardinals)
		var/turf/neighbour = get_step(candidate, check_dir)
		if(!neighbour)
			continue
		if(port.shuttle_areas[get_area(neighbour)])
			return TRUE
	return FALSE

/**
 * Full legality check for a claim. Returns a refusal string, or null if the claim is good.
 *
 * `port` is the hull being expanded, or null when commissioning a new vessel.
 */
/proc/validate_hull_claim(datum/hull_claim/claim, obj/docking_port/mobile/port)
	if(isnull(claim))
		return "Survey inconclusive: this space is not airtight."
	if(claim.refusal)
		return claim.refusal
	if(!length(claim.turfs))
		return "Survey inconclusive: this space is not airtight."
	if(length(claim.turfs) > HULL_SURVEY_MAX_TILES)
		return "Survey rejects the enclosure: [length(claim.turfs)] tiles exceeds the \
			[HULL_SURVEY_MAX_TILES] tile limit for a single survey."

	// Open to two hulls at once means both would have to fly with it. Merely abutting two is
	// harmless, so only the atmos-open ones count.
	if(length(claim.open_ports) > 1)
		return "Survey rejects the enclosure: it is open to more than one hull. Seal it off \
			from all but the one it should join."

	var/size_refusal = hull_size_refusal(claim.turfs, port)
	if(size_refusal)
		return size_refusal

	// Growing out past the docking port's outer face is allowed, but only if the finished
	// hull gives the port somewhere to move to. Everything standing proud of the port lands
	// inside whatever the ship berths against - see hull_port_overhang() - so a hull that
	// cannot reseat its port would be committed to wrecking the next ship it docked with,
	// and expand_shuttle() cannot be rolled back once it starts.
	if(port)
		var/list/overhang = hull_port_overhang(port, claim.turfs)
		if(overhang[1] > 0 && !hull_port_reseat_plan(port, claim.turfs))
			claim.refusal_turf = overhang[2]
			var/facing = dir2text(REVERSE_DIR(port.dir))
			return "Survey rejects the enclosure: the finished hull would stand [overhang[1]] \
				metre\s out past the docking port on its [facing] side, and there is no door \
				standing on that outermost line for the port to move to. \
				[hull_port_door_instruction(port, overhang[2])] A door standing clear on the \
				outermost line of any other face would do just as well - the port can turn - \
				but a door set back behind the plating is no good on any face, because whatever \
				the ship berths against gets driven through everything in front of the port."
	else
		// Commissioning. The port is seated when the hull is created and never afterwards, so
		// a hull with nowhere to put it would be launched permanently unable to berth against
		// another ship - and a big enough one is a battering ram, since a docking move
		// overwrites every tile it lands on. Refuse it at the survey instead.
		if(!hull_claim_port_seat(claim.turfs))
			return "Survey rejects the enclosure: a vessel needs a door on its outer hull to \
				serve as the docking port. Fit an airlock or a firelock into an outside wall - \
				any wall will do, as long as no part of the hull stands further out than it does."

	var/list/apcs_found = list()

	for(var/turf/claimed as anything in claim.turfs)
		// The fill stops at hull turfs, so this is a defensive assert rather than a rule.
		if(isshuttleturf(claimed))
			return "Survey rejects the enclosure: part of it already belongs to a hull."
		if(!hull_claim_area_valid(claimed))
			return "Survey rejects the enclosure: it overlaps ground that cannot be claimed."

		var/area/claimed_area = get_area(claimed)
		if(claimed_area.apc)
			apcs_found |= claimed_area.apc
			if(length(apcs_found) > 1)
				return "Survey rejects the enclosure: it spans more than one power controller."

	if(port && !claim.open_ports[port] && !claim.touched_ports[port])
		return "Survey rejects the enclosure: it does not adjoin the hull."

	return null

// ============================================
// Turf preparation
// ============================================

/**
 * Marks the boundary between what travels with the hull and what stays behind.
 *
 * create_shuttle() and expand_shuttle() both do:
 *     turf.stack_below_baseturf(/turf/open/floor/plating, /turf/baseturf_skipover/shuttle)
 * and stack_below_baseturf() matches typepaths EXACTLY - baseturfs.Find() is not istype().
 * A planet-native floor (dirt, sand, snow, rock) has no literal /turf/open/floor/plating
 * anywhere in its chain and is not itself that exact type, so that call silently no-ops.
 * The turf then never gains a skipover, isshuttleturf() stays FALSE, and the hull leaves
 * the floor behind on its first launch with no runtime and no warning.
 *
 * So: if the stock call is going to find its plating, leave it alone and let it work. If it
 * isn't, append the skipover ourselves. Appending to the top of the chain is the same idiom
 * the shuttle-rod lattice path uses (see /turf/open/proc/build_with_rods), and it is what
 * onShuttleMove()/afterShuttleMove() expect: everything above the skipover is copied to the
 * new location, everything below it is what the old tile scrapes back down to. For a cave
 * floor that means the floor itself sails and the planet keeps its ground.
 */
/proc/prepare_claimed_turf(turf/claimed)
	if(!islist(claimed.baseturfs))
		claimed.baseturfs = list(claimed.baseturfs)
	if(claimed.depth_to_find_baseturf(/turf/baseturf_skipover/shuttle))
		return FALSE // already marked
	if(claimed.baseturfs.Find(/turf/open/floor/plating) || claimed.type == /turf/open/floor/plating)
		return FALSE // the stock stack_below_baseturf() call will place it correctly
	claimed.insert_baseturf(turf_type = /turf/baseturf_skipover/shuttle)
	return TRUE

/// Runs prepare_claimed_turf() over a whole claim.
/proc/prepare_claimed_turfs(list/turfs)
	for(var/turf/claimed as anything in turfs)
		prepare_claimed_turf(claimed)

// ============================================
// Ship areas
// ============================================

/**
 * The areas of `port` that a survey may put a new room into.
 *
 * Its own only: ship-to-ship docking folds a guest's areas into the host's shuttle_areas, and
 * offering the crew their visitor's engine room as somewhere to put a new corridor would hand
 * the two ships a shared area that tears in half the moment either one undocks.
 */
/proc/hull_owned_areas(obj/docking_port/mobile/port)
	var/list/owned = list()
	for(var/area/ship_area as anything in port.shuttle_areas)
		if(hull_area_is_guest(ship_area, port))
			continue
		owned += ship_area
	return owned

/**
 * Makes a new area belonging to `port`, of the hull's own area type.
 *
 * Registering it in shuttle_areas is what makes it part of the ship rather than a patch of
 * floor sitting where the ship happens to be: beforeShuttleMove() grants a tile passage by
 * area membership, so an unregistered area is left behind - with everything standing on it -
 * the first time the hull moves.
 *
 * The turfs are not placed here. Lighting objects and the power state can only be built once
 * the area has its turfs, so assign_hull_area() does both in the order create_shuttle() uses.
 */
/proc/create_hull_area(obj/docking_port/mobile/port, area_name)
	var/area/new_area = new port.area_type()
	new_area.setup(area_name)
	port.shuttle_areas[new_area] = TRUE
	// Voidcrew areas learn their owning port here, which is what tells hull_area_is_guest()
	// and the pre-move hull audit that these tiles are ours.
	new_area.connect_to_shuttle(FALSE, port, port.get_docked())
	return new_area

/**
 * Moves a freshly claimed set of turfs out of the hull's default area and into `destination`.
 *
 * expand_shuttle() has no way to be told where a claim should land - it puts everything in
 * shuttle_areas[1] - so this runs after it and re-homes them. Doing it in that order rather
 * than reaching into expand_shuttle() keeps one code path for growing a hull, and the turfs
 * are only ever in the default area for the space between the two calls.
 *
 * `fresh_area` builds the lighting objects a newly created area has none of. The sequence
 * (turfs, then registration, then lighting, then power) is the one create_shuttle() and
 * convert_areas_to_shuttle_areas() both use; lighting and power both read the area's turfs,
 * so neither can run before the turfs are in it.
 */
/proc/assign_hull_area(obj/docking_port/mobile/port, list/turfs, area/destination, fresh_area = FALSE)
	if(!destination || !length(turfs))
		return FALSE

	var/list/affected_areas = list()
	set_turfs_to_area(turfs, destination, affected_areas)

	destination.reg_in_areas_in_z()
	if(fresh_area && destination.static_lighting)
		destination.create_area_lighting_objects()
	destination.power_change()

	// A firelock only knows which two areas it joins by asking, and the answer just changed
	// on both sides of every door on the new boundary.
	for(var/obj/machinery/door/firedoor/firelock as anything in destination.firedoors)
		firelock.CalculateAffectingAreas()
	for(var/area_name in affected_areas)
		var/area/touched = affected_areas[area_name]
		for(var/obj/machinery/door/firedoor/firelock as anything in touched.firedoors)
			firelock.CalculateAffectingAreas()
		// Areas the ship still owns are kept even when empty - shuttle_areas[1] in
		// particular is the hull's default and clear_empty_shuttle_turfs() relies on it
		// existing. Only strays left behind by the move get cleaned up.
		if(!port.shuttle_areas[touched] && !touched.has_contained_turfs())
			qdel(touched)

	return TRUE

// ============================================
// Commissioning a new vessel
// ============================================

/**
 * Stand-in template for a hull that was never loaded from a .dmm.
 *
 * setup_from_template() hard-returns FALSE without a template, and it is what supplies
 * ship_team, job_slots, ship_account and display_name. None of that needs a map, so this
 * exists purely to satisfy it.
 */
/datum/map_template/shuttle/voidcrew/commissioned
	name = "Commissioned Vessel"
	short_name = "Commissioned"
	catalog_desc = "A hull built by hand, out of whatever was to hand."
	player_hidden = TRUE
	job_slots = list(
		list(
			name = "Shipwright",
			officer = TRUE,
			outfit = /datum/outfit/job/assistant,
			category = JOB_CAT_ASSISTANT,
			slots = 1,
		),
	)

/datum/map_template/shuttle/voidcrew/commissioned/New()
	// Deliberately does NOT call ..(). The parent chain measures [prefix][port_id]_[suffix].dmm
	// via preload_size(), and this template has no map on disk. Everything the parent New()
	// actually does for us is the part_requirements fill below.
	for(var/part_class in GLOB.ship_part_classes)
		if(!(part_class in part_requirements))
			part_requirements[part_class] = 0

/**
 * Turns a sealed enclosure into a flying vessel.
 *
 * Mirrors SSshuttle.create_ship()'s post-load wiring, minus the map load: create the port,
 * create the overmap object, point them at each other, and park the overmap token inside
 * whatever encounter the builders are standing in.
 *
 * Returns the new overmap ship, or null on failure.
 */
/proc/commission_vessel(mob/user, turf/origin, list/turfs, vessel_name)
	prepare_claimed_turfs(turfs)

	// create_shuttle() seats the mobile port on whatever turf it is handed as the origin, and
	// nothing moves it afterwards. Handing it `origin` - the turf the builder happened to be
	// standing on, which for a room surveyed from the inside is somewhere in the middle of it -
	// left every tile between there and the outer wall standing proud of the port. That ship
	// could never take an exit-to-exit berth, and a large one docking with a small one would
	// simply overwrite it, since a docking move claims every tile it lands on. Seat the port on
	// a door in the outer skin instead. validate_hull_claim() has already refused any enclosure
	// that has nowhere to put it.
	var/list/seat = hull_claim_port_seat(turfs)
	if(!seat)
		return null
	var/turf/seat_turf = seat[1]
	// The port's dir points INTO the ship, away from the exit.
	var/port_dir = REVERSE_DIR(seat[2])

	var/obj/docking_port/mobile/voidcrew/port = create_shuttle(
		user,
		seat_turf,
		turfs,
		list(),
		shuttle_dir = REVERSE_DIR(port_dir),
		port_dir = port_dir,
		area_type = /area/shuttle/voidcrew,
		docking_port_type = /obj/docking_port/mobile/voidcrew,
		name = vessel_name,
		id = "commissioned_[rand(1000, 9999)]_[world.time]",
	)
	if(!istype(port))
		return null

	// Mapped hulls hardcode preferred_direction and are held to this by the
	// voidcrew_hull_dock_rotation unit test; a commissioned hull has no mapper, so it adopts
	// the guess directly. Left at the type default, a room taller than it is wide turned 90
	// degrees on every dock and every undock for the rest of the round.
	port.preferred_direction = hull_aspect_guess(port)

	// A scratch-built hull has no fans anywhere, and this door is the one that opens onto
	// vacuum. Seated at creation rather than through hull_reseat_port(), so it needs its own
	// call. No previous tile: there is nothing to move a fan from.
	hull_seat_port_fan(port, seat_turf, null)

	var/obj/structure/overmap/ship/vessel = new(SSovermap.get_unused_overmap_square())
	if(!vessel.setup_from_template(new /datum/map_template/shuttle/voidcrew/commissioned()))
		qdel(vessel)
		return null

	port.current_ship = vessel
	vessel.shuttle = port
	vessel.name = vessel_name
	vessel.display_name = vessel_name
	vessel.calculate_mass()

	// Stationloving and observer spawns both need a landmark somewhere inside the hull.
	new /obj/effect/landmark/blobstart(origin)
	new /obj/effect/landmark/observer_start(origin)

	// The hull is sitting inside an encounter, so the overmap token belongs there, docked -
	// the same state check_loc() would force it into on the next tick anyway.
	var/obj/structure/overmap/host = SSovermap_zones.get_overmap_object_for_turf(origin)
	if(host)
		vessel.forceMove(host)
		vessel.docked = host
		vessel.state = OVERMAP_SHIP_IDLE

	vessel.update_flight_parallax()
	SEND_SIGNAL(port, COMSIG_VOIDCREW_SHIP_LOADED)

	// The builders own what they built. setup_from_template() creates the crew roster
	// but nothing used to put anyone ON it, so a commissioned hull launched with a crew
	// of nobody: every roster-gated console refused the people who welded it together,
	// there was no captain to invite anyone aboard, and the only way out was an admin
	// hand-editing team membership (round 6, 2026-08-15, ticket #1). Enlist the surveyor
	// as commanding officer and everyone standing inside the enclosure as crew.
	// enlist_crewmember() also clears each ckey through the join password, per the
	// crew-adding rules in ship.dm.
	vessel.ship_team.name = vessel_name // not the template's "Commissioned Vessel" placeholder
	for(var/turf/claimed as anything in turfs)
		for(var/mob/living/builder in claimed)
			if(builder == user || !builder.mind || !builder.client || builder.stat == DEAD)
				continue
			if(vessel.enlist_crewmember(builder))
				to_chat(builder, span_notice("You are registered as crew of [vessel_name]."))
	if(vessel.enlist_crewmember(user))
		vessel.claimed_captain = user.mind
		grant_captain_management(user, vessel)
		to_chat(user, span_notice("You are registered as the commanding officer of [vessel_name]. \
			Use the Ship Management button to invite crew, set a memo, or set a join password."))

	message_admins("[key_name(user)] commissioned a scratch-built vessel, [vessel_name], at [ADMIN_VERBOSEJMP(origin)].")
	log_shuttle("[key_name(user)] commissioned scratch-built vessel [vessel_name] at [get_area(origin)].")
	return vessel

/**
 * Post-commit bookkeeping for a hull that just grew. Must run after expand_shuttle().
 *
 * expand_shuttle() moves the new turfs into the ship's area BEFORE it stamps them with
 * /turf/baseturf_skipover/shuttle. The ship's hull tracker listens on the area
 * (COMSIG_AREA_TURF_ADDED -> on_area_turf_added -> get_turf_mass_weight_instance), and that
 * weight function returns 0 for anything isshuttleturf() does not yet recognise as hull. So
 * every tile of an expansion is credited as weighing nothing - the room adds no mass and
 * raises no integrity ceiling.
 *
 * Those tiles are still registered for COMSIG_TURF_CHANGE, though, so the first time one of
 * them breaks it debits the hull for a wall it was never paid for. An expanded ship bleeds
 * integrity against a ceiling that never accounted for the room, drops into
 * SHIP_INTEGRITY_DISABLED, and the helm greys out undock, dock, cloak and bluespace
 * together - which is the "the ship is bricked after I add a room" report.
 *
 * A full recount is exact and self-correcting: by now every turf carries its skipover, and
 * calculate_mass()'s resync branch routes the difference through apply_mass_delta(), the same
 * path the incremental handlers use. It also cannot double-count turfs that prepare_claimed_turf()
 * happened to mark early and that the signal therefore already credited.
 */
/proc/recount_hull_after_expansion(obj/docking_port/mobile/port)
	var/obj/docking_port/mobile/voidcrew/voidcrew_port = port
	if(!istype(voidcrew_port))
		return
	voidcrew_port.current_ship?.calculate_mass()

/**
 * Folds a validated enclosure into an existing hull.
 *
 * Returns the turf the docking port was reseated onto, or null if it did not need to move.
 * validate_hull_claim() has already refused any claim that would overhang the port with no
 * door to move it to, so by here a reseat either is unnecessary or is guaranteed a target.
 */
/proc/integrate_into_hull(mob/user, obj/docking_port/mobile/port, list/turfs, area/destination, fresh_area = FALSE)
	prepare_claimed_turfs(turfs)
	expand_shuttle(user, port, turfs, list())

	// Before the mass recount, so it measures the areas the room actually ends up in.
	if(destination && destination != port.shuttle_areas[1])
		assign_hull_area(port, turfs, destination, fresh_area)

	recount_hull_after_expansion(port)

	// Measured after the commit, so it reads the finished hull rather than a prediction.
	var/list/plan = hull_port_reseat_plan(port, null)
	if(!plan)
		var/list/overhang = hull_port_overhang(port, null)
		if(overhang[1] > 0)
			// Only reachable if the door validate_hull_claim() found was destroyed inside the
			// same tick. Leave the hull as it is - the dock-time guards refuse the berth
			// rather than letting it ram - but this should never be routine.
			stack_trace("[port] overhangs its docking port by [overhang[1]] after expansion with no door to reseat onto")
		return null

	var/turf/reseat_to = plan[1]
	// A seat on the face the port already uses returns its current dir and port_direction
	// unchanged, so this one call covers both the slide and the turn.
	var/list/new_facing = hull_port_facing(port, plan[2])
	hull_reseat_port(port, reseat_to, new_facing[1], new_facing[2])
	return reseat_to

// ============================================
// The player-facing action
// ============================================

/**
 * Runs a survey where the user is standing and acts on the result.
 *
 * One entry point for both outcomes: if the enclosure adjoins a hull we expand that hull,
 * otherwise we look for a helm console and commission a new one.
 */
/mob/living/proc/perform_hull_survey()
	var/turf/origin = get_turf(src)
	if(!origin)
		return

	if(!can_perform_action(src, NEED_LITERACY|ALLOW_RESTING))
		return

	var/datum/hull_claim/claim = survey_enclosure(origin)
	var/obj/docking_port/mobile/adjoining_port = claim.adjoining_port()

	var/refusal = validate_hull_claim(claim, adjoining_port)
	if(refusal)
		report_survey_refusal(claim, refusal)
		return

	if(adjoining_port)
		survey_expand(origin, claim, adjoining_port)
	else
		survey_commission(origin, claim)

/**
 * A refusal is close to useless without a bearing: from inside the room, a leak on the far
 * wall looks exactly like a sealed room, and the player is left rebuilding walls at random.
 */
/mob/living/proc/report_survey_refusal(datum/hull_claim/claim, refusal)
	var/turf/spot = claim?.refusal_turf
	var/turf/here = get_turf(src)
	if(spot && here)
		refusal += hull_survey_bearing(here, spot)
	to_chat(src, span_warning(refusal))

/**
 * Asks which of the ship's compartments the new room should belong to.
 *
 * Returns list(area/existing_or_null, new_name_or_null), or null if the player backed out.
 * The area is deliberately not created here: the prompt comes before the survey's do_after,
 * and a cancelled or failed survey must not leave an empty compartment registered on the hull.
 *
 * This exists because every surveyed room used to land in shuttle_areas[1], so a ship grown by
 * hand was one enormous compartment on one APC - lose that APC and the whole vessel goes dark
 * at once, and there is no way to give an engine room its own power, its own air alarm or its
 * own fire response.
 */
/mob/living/proc/choose_hull_area(obj/docking_port/mobile/port)
	var/list/choices = list()
	var/new_area_label = "New compartment..."
	choices[new_area_label] = port.area_type

	for(var/area/ship_area as anything in hull_owned_areas(port))
		// Ships routinely carry two areas of the same name (two "Engineering" instances on a
		// hull built from modules), and an assoc list would silently drop all but the last.
		var/label = ship_area.name
		var/collision = 2
		while(choices[label])
			label = "[ship_area.name] ([collision++])"
		choices[label] = ship_area

	var/picked = tgui_input_list(src, "Which compartment should this room be part of?", "Hull Survey", choices)
	if(isnull(picked))
		return null

	var/area/chosen = choices[picked]
	if(isarea(chosen))
		return list(chosen, null)

	// Deliberately not run through reject_bad_name(): that is a person-name filter, and it
	// mangles perfectly good compartment names. tgui_input_text already sanitises and caps
	// the length, which is all create_area() asks of a station area name either.
	var/area_name = trim(tgui_input_text(src, "Name the new compartment:", "Hull Survey", max_length = MAX_NAME_LEN))
	if(!length(area_name))
		return null

	return list(null, area_name)

/// Expansion branch: confirm, re-validate, then integrate.
/mob/living/proc/survey_expand(turf/origin, datum/hull_claim/claim, obj/docking_port/mobile/port)
	// current_ship is declared on the voidcrew port subtype, not the base mobile port.
	var/obj/docking_port/mobile/voidcrew/voidcrew_port = port
	var/obj/structure/overmap/ship/vessel = istype(voidcrew_port) ? voidcrew_port.current_ship : null
	if(!vessel)
		to_chat(src, span_warning("The adjoining hull has no registered vessel."))
		return

	// expand_shuttle() finishes with a forced self-redock to commit the new bounds, which
	// must not happen to a ship that is under way.
	if(vessel.state != OVERMAP_SHIP_IDLE)
		to_chat(src, span_warning("[vessel.name] is under way. The hull can only be altered while docked."))
		return
	if(!COOLDOWN_FINISHED(vessel, interdiction_undock_lockout))
		to_chat(src, span_warning("Docking clamps are engaged. The hull cannot be altered right now."))
		return

	// Asked before the wait, not after it, so nobody stands through the survey only to be
	// handed a question. A null return is a cancelled prompt.
	var/list/choice = choose_hull_area(port)
	if(!choice)
		return
	var/area/destination = choice[1]
	var/new_area_name = choice[2]

	to_chat(src, span_notice("You begin surveying the enclosure - [length(claim.turfs)] tiles, adjoining [vessel.name]."))
	if(!do_after(src, HULL_SURVEY_DURATION, origin))
		return

	// The world can change during the do_after, and neither expand_shuttle() nor
	// create_shuttle() can be rolled back once they start. Re-survey and re-validate.
	var/datum/hull_claim/fresh = survey_enclosure(origin)
	var/refusal = validate_hull_claim(fresh, port)
	if(refusal)
		report_survey_refusal(fresh, refusal)
		return
	if(vessel.state != OVERMAP_SHIP_IDLE)
		to_chat(src, span_warning("[vessel.name] got under way mid-survey."))
		return

	// The area could have been dismantled while we surveyed - a room deconstructed down to
	// nothing takes its area with it (clear_empty_shuttle_turfs). Fall back to asking again
	// rather than silently dumping the room somewhere the player did not choose.
	var/fresh_area = isnull(destination)
	if(!fresh_area && (QDELETED(destination) || !port.shuttle_areas[destination]))
		to_chat(src, span_warning("The area you chose is no longer part of [vessel.name]."))
		return
	if(fresh_area)
		destination = create_hull_area(port, new_area_name)

	// Read before the commit: integrate_into_hull() may turn the port onto another face, and
	// the crew need telling when their ship changes the side it berths through.
	var/old_outward = REVERSE_DIR(port.dir)
	var/turf/reseated_to = integrate_into_hull(src, port, fresh.turfs, destination, fresh_area)
	to_chat(src, span_notice("Survey complete. [length(fresh.turfs)] tiles integrated into \
		[vessel.name], as part of [destination.name]."))
	if(fresh_area)
		to_chat(src, span_notice("[destination.name] is a new compartment with no power of its \
			own. Build an APC in it to light it and run its machines."))
	if(reseated_to)
		var/obj/machinery/door/new_port_door = hull_port_door(reseated_to)
		var/new_outward = REVERSE_DIR(port.dir)
		var/turned = ""
		if(new_outward != old_outward)
			turned = " The ship now berths through its [dir2text(new_outward)] face instead of \
				its [dir2text(old_outward)] one."
		to_chat(src, span_notice("The enclosure now stands proud of the old docking port, so the \
			port has been moved out to [new_port_door ? "the [new_port_door.name]" : "the new outer hull"] \
			at ([reseated_to.x], [reseated_to.y]). That door is where other ships will berth.[turned]"))

/// Commissioning branch: needs a helm console in the enclosure and a name.
/mob/living/proc/survey_commission(turf/origin, datum/hull_claim/claim)
	var/obj/machinery/computer/helm/found_helm
	for(var/turf/claimed as anything in claim.turfs)
		found_helm = locate(/obj/machinery/computer/helm) in claimed
		if(found_helm)
			break

	if(!found_helm)
		to_chat(src, span_warning("Survey complete, but this enclosure has no helm console. \
			Without one there is nothing to fly it."))
		return

	var/vessel_name = tgui_input_text(src, "Designate the vessel:", "Commission Vessel", max_length = MAX_NAME_LEN)
	if(!vessel_name)
		return
	vessel_name = reject_bad_name(vessel_name, allow_numbers = TRUE)
	if(!vessel_name)
		to_chat(src, span_warning("That name will not do."))
		return

	to_chat(src, span_notice("You begin surveying the enclosure - [length(claim.turfs)] tiles."))
	if(!do_after(src, HULL_SURVEY_DURATION, origin))
		return

	var/datum/hull_claim/fresh = survey_enclosure(origin)
	var/refusal = validate_hull_claim(fresh, null)
	if(refusal)
		report_survey_refusal(fresh, refusal)
		return
	if(QDELETED(found_helm) || !(get_turf(found_helm) in fresh.turfs))
		to_chat(src, span_warning("The helm console is no longer inside the enclosure."))
		return

	var/obj/structure/overmap/ship/vessel = commission_vessel(src, origin, fresh.turfs, vessel_name)
	if(!vessel)
		to_chat(src, span_warning("The survey failed to resolve into a hull."))
		return

	found_helm.attempt_ship_connection(last_resort = TRUE)
	to_chat(src, span_notice("Survey complete. [vessel_name] is registered as a vessel."))

	var/turf/port_turf = get_turf(vessel.shuttle)
	var/obj/machinery/door/port_door = hull_port_door(port_turf)
	if(port_door)
		to_chat(src, span_notice("The [port_door.name] at ([port_turf.x], [port_turf.y]) is the \
			ship's docking port. That is where other ships will berth against it."))

	// validate_hull_claim() refuses any enclosure with nowhere to seat the port, so this is an
	// assert rather than a rule. It is worth keeping: a hull that reaches the round overhanging
	// its own port is one that overwrites whatever it docks with.
	var/list/overhang = hull_port_overhang(vessel.shuttle, null)
	if(overhang[1] > 0)
		stack_trace("commissioned vessel [vessel_name] launched overhanging its docking port by [overhang[1]] tiles")

/**
 * The survey button, as a persistent HUD screen object.
 *
 * Sits in the lower-right cluster alongside rest/pull/throw rather than in the action
 * button palette, so it is always on screen and never competes with granted abilities.
 */
/atom/movable/screen/hull_survey
	name = "Survey Hull"
	desc = "Adds the room you are standing in to a ship.<br><br>\
		Seal a room off - walls, windows, a closed airlock, anything air cannot get \
		through - then stand inside it and press this. If the room touches a docked ship \
		it is welded on and becomes part of that hull. If it touches nothing but contains \
		a helm console, it is registered as a ship of its own.<br><br>\
		The room may share a wall with the ship, or open straight into it through a door. \
		The ship has to be docked and stationary."
	// icon is assigned from the hud's ui_style at construction, like every other button
	// here, so it follows the player's chosen HUD skin instead of hardcoding one.
	// act_survey exists in all nine sheets in GLOB.available_ui_styles.
	icon = 'icons/hud/screen_midnight.dmi'
	icon_state = "act_survey"
	base_icon_state = "act_survey"
	plane = HUD_PLANE
	mouse_over_pointer = MOUSE_HAND_POINTER

/atom/movable/screen/hull_survey/Click()
	if(!isliving(usr))
		return
	var/mob/living/living_user = usr
	living_user.perform_hull_survey()

// The button is always on screen and never explains itself otherwise - there is no action
// entry to examine and no item to read. Same hover tooltip the action buttons use.
/atom/movable/screen/hull_survey/MouseEntered(location, control, params)
	. = ..()
	if(!QDELETED(src))
		// Empty theme lets openToolTip() fall back to the player's HUD skin, as action
		// buttons do with their own default-empty actiontooltipstyle.
		openToolTip(usr, src, params, title = name, content = desc)

/atom/movable/screen/hull_survey/MouseExited(location, control, params)
	closeToolTip(usr)
	return ..()

/**
 * Everyone gets the button. Anyone who can seal a room can claim it, including someone
 * building a first ship from scratch who is not yet crew of anything.
 *
 * Defined as a second /datum/hud/human/New() rather than being folded into the one in
 * code/_onclick/hud/human.dm - DM chains same-type overrides across files in include
 * order and ..() walks back up the chain, which is the pattern voice_barks and intents
 * already use for their own init/login hooks.
 */
/datum/hud/human/New(mob/living/carbon/human/owner)
	. = ..()
	// Free up the tile first - stock tg puts the pull icon here, invisible while idle but
	// still clickable, so leaving it would stack two controls on one slot.
	pull_icon?.screen_loc = ui_pull_displaced

	var/atom/movable/screen/hull_survey/survey_button = new(null, src)
	survey_button.icon = ui_style
	survey_button.screen_loc = ui_hull_survey
	static_inventory += survey_button

#undef HULL_SURVEY_MAX_TILES
#undef HULL_SURVEY_DURATION
