/**
 * # Outpost door access
 *
 * The owner or a steward keys any airlock or windoor on the outpost's own ground (the habitat, the
 * prebuilt rooms, the cargo dock, anything the owner built) from the construction console's Door
 * Access tool. Four settings:
 *
 * * Public: anyone. Every door starts here, and a public door carries nothing.
 * * Members: the owner, residents and the owner's crews (is_outpost_member()).
 * * Staff: the owner, stewards, treasurers and pricers, in their current bodies.
 * * Owner: the owner, in their current body.
 *
 * The playtest visitor and blocked players are never let in, admin ghosts always are, and an
 * ownerless outpost opens every door to everyone. The refusal itself hangs on the door in
 * voidcrew/edits/outpost_door_access.dm.
 *
 * Nobody is ever locked in. A keyed door always opens from its free side, which also lights the
 * door's green floor strip. The first time a door is keyed the free side is picked for it: each side
 * is walked (outpost_door_reach()) through every door a visitor could open that way, and the side
 * that is most closed in is the inside. The tool can turn the free side, but never away from a side
 * that is shut in, or from a big side toward one that leads out: that would be a room people walk
 * into and cannot leave. Walls built later can still shut people in, as walls always could.
 *
 * The setting lives in a component on the door, so a door that is taken apart and rebuilt is public.
 * Prison wing doors answer to the warden (outpost_prison_doors.dm), and the teleporter room's door
 * stays public (its arrival policy is the lever), so the tool refuses both.
 */

/// Every door on an outpost that carries a setting other than public: the fast path in voidcrew/edits/outpost_door_access.dm
GLOBAL_LIST_EMPTY(outpost_access_doors)

/// What a side walk found on a tile (outpost_door_ground())
#define OUTPOST_DOOR_GROUND_INSIDE 1
#define OUTPOST_DOOR_GROUND_OUTSIDE 0
#define OUTPOST_DOOR_GROUND_BLOCKED -1

// ===== THE SETTING ON THE DOOR =====

/datum/component/outpost_door_access
	/// OUTPOST_DOOR_MEMBERS, OUTPOST_DOOR_STAFF or OUTPOST_DOOR_OWNER. Public doors carry no component.
	var/access
	/// The one cardinal side the door always opens from
	var/free_side
	/// The outpost whose people the setting names
	var/datum/weakref/outpost_ref
	/// The door's own unres_sides before the free side took over its floor light, put back on removal
	var/original_unres_sides = NONE

/datum/component/outpost_door_access/Initialize(access, free_side, obj/structure/overmap/dynamic/player_outpost/home)
	if(!istype(parent, /obj/machinery/door/airlock) && !istype(parent, /obj/machinery/door/window))
		return COMPONENT_INCOMPATIBLE
	src.access = access
	outpost_ref = WEAKREF(home)
	var/obj/machinery/door/door = parent
	original_unres_sides = door.unres_sides
	set_free_side(free_side)
	GLOB.outpost_access_doors += src

/datum/component/outpost_door_access/Destroy(force)
	GLOB.outpost_access_doors -= src
	var/obj/machinery/door/door = parent
	if(!QDELETED(door))
		door.unres_sides = original_unres_sides
		door.update_appearance()
	outpost_ref = null
	return ..()

/datum/component/outpost_door_access/RegisterWithParent()
	RegisterSignal(parent, COMSIG_ATOM_EXAMINE, PROC_REF(on_examine))

/datum/component/outpost_door_access/UnregisterFromParent()
	UnregisterSignal(parent, COMSIG_ATOM_EXAMINE)

/datum/component/outpost_door_access/proc/on_examine(datum/source, mob/user, list/examine_list)
	SIGNAL_HANDLER
	examine_list += span_notice("[capitalize(sign_text())].")

/// What the door's sign says
/datum/component/outpost_door_access/proc/sign_text()
	switch(access)
		if(OUTPOST_DOOR_MEMBERS)
			return "members only"
		if(OUTPOST_DOOR_STAFF)
			return "staff only"
		if(OUTPOST_DOOR_OWNER)
			return "owner only"
	return "public"

/// Makes `side` the door's free side, and lights the door's floor strip on it
/datum/component/outpost_door_access/proc/set_free_side(side)
	free_side = side
	var/obj/machinery/door/door = parent
	door.unres_sides = side
	door.update_appearance()

/// Whether someone standing on `from` is on the door's free side. A windoor's own tile is its back side.
/datum/component/outpost_door_access/proc/on_free_side(turf/from)
	var/obj/machinery/door/door = parent
	var/turf/door_turf = get_turf(door)
	if(!from || !door_turf)
		return FALSE
	if(from == door_turf)
		return istype(door, /obj/machinery/door/window) && (REVERSE_DIR(door.dir) & free_side)
	return !!(get_dir(door_turf, from) & free_side)

/**
 * Whether the door opens for `user` coming at it from `from`. `user` may be null (telekinesis, an
 * item nobody threw, a side walk judging for a visitor): then only the free side opens it.
 */
/datum/component/outpost_door_access/proc/admits(mob/user, turf/from)
	var/obj/structure/overmap/dynamic/player_outpost/home = outpost_ref?.resolve()
	if(QDELETED(home) || !home.founder_ckey)
		return TRUE
	if(on_free_side(from))
		return TRUE
	if(!user)
		return FALSE
	if(isAdminGhostAI(user))
		return TRUE
	if(home.door_access_admits(user, access))
		return TRUE
	// A renter or a pass holder always reaches what they paid for (outpost_service_doors.dm)
	var/obj/machinery/door/airlock/outpost/service/service_door = parent
	return istype(service_door) && service_door.admits_paying_visitor(user)

/// A door's setting: its component's, or OUTPOST_DOOR_PUBLIC
/proc/outpost_door_access_of(obj/machinery/door/door)
	var/datum/component/outpost_door_access/lock = door?.GetComponent(/datum/component/outpost_door_access)
	return lock ? lock.access : OUTPOST_DOOR_PUBLIC

// ===== WHO GETS THROUGH =====

/// Whether `user` gets through a door keyed to `access` here by who they are, wherever they stand
/obj/structure/overmap/dynamic/player_outpost/proc/door_access_admits(mob/user, access)
	if(!user)
		return FALSE
	if(playtest_visitor_ckey && user.ckey == playtest_visitor_ckey)
		return FALSE
	// Blocking strips a player's roles too, but a door never takes the chance
	if(user.ckey && (user.ckey in blocked_residents) && !is_owner(user))
		return FALSE
	switch(access)
		if(OUTPOST_DOOR_PUBLIC)
			return TRUE
		if(OUTPOST_DOOR_MEMBERS)
			return is_outpost_member(user)
		if(OUTPOST_DOOR_STAFF)
			return is_current_management_user(user) || is_current_treasury_user(user) || is_current_pricing_user(user)
		if(OUTPOST_DOOR_OWNER)
			return is_owner(user) && is_current_management_user(user)
	return FALSE

// ===== SETTING A DOOR =====

/// Whether `user` may key this outpost's doors: the owner and stewards in their current bodies, and admin ghosts
/obj/structure/overmap/dynamic/player_outpost/proc/may_set_door_access(mob/user)
	if(!user)
		return FALSE
	return isAdminGhostAI(user) || is_current_management_user(user)

/// Why `user` cannot key `door` here, or null
/obj/structure/overmap/dynamic/player_outpost/proc/door_access_denial(mob/user, obj/machinery/door/door)
	if(!may_set_door_access(user))
		return "Not authorised."
	return door_access_fixed(door)

/// Why `door` takes no setting here whoever asks, or null
/obj/structure/overmap/dynamic/player_outpost/proc/door_access_fixed(obj/machinery/door/door)
	if(QDELETED(door) || !(istype(door, /obj/machinery/door/airlock) || istype(door, /obj/machinery/door/window)))
		return "Not a door."
	var/turf/spot = door.loc
	// Outpost ground only: never a docked ship (get_outpost_from_atom() gives them up), never the cargo ferry
	if(!isturf(spot) || !is_turf_buildable(spot) || cargo_ferry_covers(spot) || get_outpost_from_atom(spot) != src)
		return "Not an outpost door."
	if(is_outpost_prison_door(door))
		return "Prison door."
	// Its circuit decides who it opens for (wiremod/shell/airlock.dm)
	if(istype(door, /obj/machinery/door/airlock/shell))
		return "Circuit door."
	var/datum/outpost_upgrade/upgrade = upgrade_at_turf(spot)
	if(upgrade && !upgrade.installed)
		return "Not built yet."
	var/datum/outpost_upgrade/service/room = upgrade
	if(istype(room) && room.doors_stay_public)
		return "Stays public."
	return null

/// Keys `door` to `access` for `user`. Null when set (or already so), else a short refusal.
/obj/structure/overmap/dynamic/player_outpost/proc/set_door_access(mob/user, obj/machinery/door/door, access)
	if(!istext(access) || !(access in list(OUTPOST_DOOR_PUBLIC, OUTPOST_DOOR_MEMBERS, OUTPOST_DOOR_STAFF, OUTPOST_DOOR_OWNER)))
		return "Unknown setting."
	var/denial = door_access_denial(user, door)
	if(denial)
		return denial
	var/old_access = outpost_door_access_of(door)
	if(old_access == access)
		return null
	// A prebuilt room's door already knows its inside: its map points the free side there
	var/free_side_hint = istype(door, /obj/machinery/door/airlock/outpost/service) ? outpost_door_first_side(door.unres_sides) : null
	apply_door_access(door, access, free_side_hint)
	log_game("PLAYER OUTPOST: [key_name(user)] set the [door.name] at [AREACOORD(door)] from [old_access] to [access] at '[name]'")
	return null

/**
 * Keys `door` to `access` with no permission check (room defaults, abandonment, tests). A door keyed
 * for the first time gets `free_side`, or the side outpost_door_pick_free_side() picks.
 */
/obj/structure/overmap/dynamic/player_outpost/proc/apply_door_access(obj/machinery/door/door, access, free_side)
	var/datum/component/outpost_door_access/lock = door.GetComponent(/datum/component/outpost_door_access)
	if(access == OUTPOST_DOOR_PUBLIC)
		if(lock)
			qdel(lock)
		return
	if(lock)
		lock.access = access
		lock.outpost_ref = WEAKREF(src)
		return
	free_side ||= outpost_door_pick_free_side(src, door)
	// The side walk may yield: the door can be gone, or keyed by someone else, by now
	if(QDELETED(door))
		return
	lock = door.GetComponent(/datum/component/outpost_door_access)
	if(lock)
		lock.access = access
		return
	door.AddComponent(/datum/component/outpost_door_access, access, free_side, src)

/**
 * Turns `door`'s free side to its next open side. Null when turned, else a short refusal. Refuses
 * a turn that would leave a closed-in side refused while the free side leads out.
 */
/obj/structure/overmap/dynamic/player_outpost/proc/turn_door_free_side(mob/user, obj/machinery/door/door)
	var/denial = door_access_denial(user, door)
	if(denial)
		return denial
	var/datum/component/outpost_door_access/lock = door.GetComponent(/datum/component/outpost_door_access)
	if(!lock)
		return "Door is public."
	var/list/reaches = list()
	for(var/side in outpost_door_sides(door))
		var/list/reach = outpost_door_side_reach(src, door, side)
		if(reach)
			reaches["[side]"] = reach
	var/next_side
	if(istype(door, /obj/machinery/door/window))
		var/other = lock.free_side == door.dir ? REVERSE_DIR(door.dir) : door.dir
		if(reaches["[other]"])
			next_side = other
	else
		for(var/angle in list(-90, 180, 90))
			var/candidate = turn(lock.free_side, angle)
			if(reaches["[candidate]"])
				next_side = candidate
				break
	if(!next_side)
		return "No other side."
	// Anyone on a refused side needs another way out: never a shut-in side, never a big side that may
	// be shut in while the free side leads out. A turn between two open sides, or two big ones, is fine.
	var/list/free_reach = reaches["[next_side]"]
	for(var/side_key in reaches)
		if(side_key == "[next_side]")
			continue
		var/list/refused_reach = reaches[side_key]
		if(refused_reach[1] == OUTPOST_DOOR_REACH_CLOSED || (refused_reach[1] == OUTPOST_DOOR_REACH_CAPPED && free_reach[1] == OUTPOST_DOOR_REACH_OPEN))
			return "Would lock people in."
	if(QDELETED(lock))
		return "Door is public."
	lock.set_free_side(next_side)
	log_game("PLAYER OUTPOST: [key_name(user)] turned the free side of the [door.name] at [AREACOORD(door)] to [dir2text(next_side)] at '[name]'")
	return null

/// Every door here back to its default: public, and the prebuilt rooms' staff doors staff (abandonment)
/obj/structure/overmap/dynamic/player_outpost/proc/reset_door_access()
	for(var/datum/component/outpost_door_access/lock in GLOB.outpost_access_doors.Copy())
		if(lock.outpost_ref?.resolve() == src)
			qdel(lock)
	for(var/datum/outpost_upgrade/service/room as anything in installed_service_rooms())
		room.apply_door_defaults()

/// Whether `door` belongs to a prison wing, whose doors answer to the warden (outpost_prison_doors.dm)
/proc/is_outpost_prison_door(obj/machinery/door/door)
	if(istype(door, /obj/machinery/door/airlock/security/glass/outpost_prison_cell) || istype(door, /obj/machinery/door/airlock/security/prison_staff))
		return TRUE
	if(istype(door, /obj/machinery/door/window/brigdoor/outpost_prison_staff) || istype(door, /obj/machinery/door/window/outpost_prison_yard))
		return TRUE
	var/area/door_area = get_area(door)
	return istype(door_area, /area/voidcrew/player_outpost/prison) || istype(door_area, /area/voidcrew/player_outpost/prison_extension)

// ===== THE FREE SIDE =====

/// The sides of a door someone can stand on: a windoor's front and back, an airlock's four
/proc/outpost_door_sides(obj/machinery/door/door)
	if(istype(door, /obj/machinery/door/window))
		return list(door.dir, REVERSE_DIR(door.dir))
	return list(NORTH, SOUTH, EAST, WEST)

/**
 * The side of `door` that is most closed in: the inside, where a keyed door always opens from. A side
 * that walks out to open ground is outside; of two closed sides the smaller is inside; of two sides
 * that both lead out, the one that starts indoors and goes deeper before it gets out is inside.
 */
/proc/outpost_door_pick_free_side(obj/structure/overmap/dynamic/player_outpost/home, obj/machinery/door/door)
	var/best_side
	var/list/best
	var/list/sides = outpost_door_sides(door)
	for(var/side in sides)
		var/list/reach = outpost_door_side_reach(home, door, side)
		if(!reach)
			continue
		if(!best || outpost_door_reach_more_inside(reach, best))
			best = reach
			best_side = side
	return best_side || sides[1]

/// Orders side walks: closed before capped before open
/proc/outpost_door_reach_rank(list/reach)
	switch(reach[1])
		if(OUTPOST_DOOR_REACH_CLOSED)
			return 1
		if(OUTPOST_DOOR_REACH_CAPPED)
			return 2
	return 3

/// Whether side walk `first` is more of an inside than `second` (outpost_door_pick_free_side())
/proc/outpost_door_reach_more_inside(list/first, list/second)
	var/first_rank = outpost_door_reach_rank(first)
	var/second_rank = outpost_door_reach_rank(second)
	if(first_rank != second_rank)
		return first_rank < second_rank
	switch(first[1])
		if(OUTPOST_DOOR_REACH_CLOSED)
			return first[2] < second[2]
		if(OUTPOST_DOOR_REACH_OPEN)
			if(first[3] != second[3])
				return !first[3]
			return first[2] > second[2]
	return FALSE

/**
 * Walks one side of `door` as `user` would (null: as a visitor), the door itself shut. Returns
 * list(what it found, tiles walked, whether the side starts off the outpost), or null when nobody
 * can stand on that side at all (a wall, a fixed machine, the docked cargo ferry).
 */
/proc/outpost_door_side_reach(obj/structure/overmap/dynamic/player_outpost/home, obj/machinery/door/door, side, mob/user, limit = OUTPOST_DOOR_FLOOD_LIMIT)
	var/turf/door_turf = get_turf(door)
	if(!door_turf)
		return null
	var/turf/start
	if(istype(door, /obj/machinery/door/window) && side == REVERSE_DIR(door.dir))
		start = door_turf
	else
		start = get_step(door_turf, side)
		if(!start || !outpost_door_step_ok(door_turf, start, door, user, skip_ignored_edge = TRUE))
			return null
	switch(outpost_door_ground(home, start))
		if(OUTPOST_DOOR_GROUND_BLOCKED)
			return null
		if(OUTPOST_DOOR_GROUND_OUTSIDE)
			return list(OUTPOST_DOOR_REACH_OPEN, 0, TRUE)
	var/list/reach = outpost_door_reach(home, start, door, user, limit)
	reach += FALSE
	return reach

/// Outpost ground, ground off the outpost (space, a docked ship, anything not the outpost's area), or the docked cargo ferry, which nobody walks out through
/proc/outpost_door_ground(obj/structure/overmap/dynamic/player_outpost/home, turf/tile)
	if(isspaceturf(tile))
		return OUTPOST_DOOR_GROUND_OUTSIDE
	if(istype(tile.loc, /area/voidcrew/player_outpost))
		return OUTPOST_DOOR_GROUND_INSIDE
	if(home?.cargo_ferry_covers(tile))
		return OUTPOST_DOOR_GROUND_BLOCKED
	return OUTPOST_DOOR_GROUND_OUTSIDE

/**
 * Walks outpost ground from `start` as `user` would (null: as a visitor), through every door that
 * opens for them from the way they come, never through `ignored`. Stops at the first tile off the
 * outpost. Returns list(OUTPOST_DOOR_REACH_*, tiles walked).
 */
/proc/outpost_door_reach(obj/structure/overmap/dynamic/player_outpost/home, turf/start, obj/machinery/door/ignored, mob/user, limit = OUTPOST_DOOR_FLOOD_LIMIT)
	var/list/seen = list()
	seen[start] = TRUE
	var/list/queue = list(start)
	var/index = 0
	while(index < length(queue))
		index++
		CHECK_TICK
		var/turf/current = queue[index]
		for(var/direction in GLOB.cardinals)
			var/turf/next = get_step(current, direction)
			if(!next || seen[next])
				continue
			if(!outpost_door_step_ok(current, next, ignored, user))
				continue
			var/ground = outpost_door_ground(home, next)
			if(ground == OUTPOST_DOOR_GROUND_BLOCKED)
				continue
			seen[next] = TRUE
			if(ground == OUTPOST_DOOR_GROUND_OUTSIDE)
				return list(OUTPOST_DOOR_REACH_OPEN, length(queue))
			queue += next
			if(length(queue) >= limit)
				return list(OUTPOST_DOOR_REACH_CAPPED, length(queue))
	return list(OUTPOST_DOOR_REACH_CLOSED, length(queue))

/**
 * Whether `user` (null: a visitor) can step from `source` onto its neighbour `target`: no wall, no
 * fixed dense thing, no door that stays shut for them from this side, and no window or shut windoor
 * on the edge between. `ignored` never opens; `skip_ignored_edge` lets the step leave its own edge.
 */
/proc/outpost_door_step_ok(turf/source, turf/target, obj/machinery/door/ignored, mob/user, skip_ignored_edge = FALSE)
	if(isclosedturf(target))
		return FALSE
	var/direction = get_dir(source, target)
	for(var/obj/border in source)
		if((border.flags_1 & ON_BORDER_1) && border.dir == direction && !outpost_door_edge_ok(border, ignored, user, source, skip_ignored_edge))
			return FALSE
	var/reverse = REVERSE_DIR(direction)
	for(var/obj/thing in target)
		if(thing.flags_1 & ON_BORDER_1)
			if(thing.dir == reverse && !outpost_door_edge_ok(thing, ignored, user, source, skip_ignored_edge))
				return FALSE
			continue
		if(istype(thing, /obj/machinery/door))
			if(thing == ignored || !outpost_door_passable(thing, user, source))
				return FALSE
			continue
		if(thing.density && thing.anchored && !HAS_TRAIT(thing, TRAIT_CLIMBABLE))
			return FALSE
	return TRUE

/// Whether a border object on the edge being crossed lets `user` across, coming from `from`
/proc/outpost_door_edge_ok(obj/border, obj/machinery/door/ignored, mob/user, turf/from, skip_ignored_edge)
	if(border == ignored)
		return skip_ignored_edge
	if(istype(border, /obj/machinery/door))
		return outpost_door_passable(border, user, from)
	return !border.density

/**
 * Whether a door opens for `user` (null: a visitor) coming at it from `from`, by its setting.
 * A bolted or welded airlock is a wall. Firedoors open by hand; blast doors and shutters only when open.
 */
/proc/outpost_door_passable(obj/machinery/door/door, mob/user, turf/from)
	if(istype(door, /obj/machinery/door/firedoor))
		return TRUE
	if(istype(door, /obj/machinery/door/airlock))
		var/obj/machinery/door/airlock/airlock = door
		if(airlock.density && (airlock.locked || airlock.welded))
			return FALSE
	else if(!istype(door, /obj/machinery/door/window))
		return !door.density
	var/datum/component/outpost_door_access/lock = door.GetComponent(/datum/component/outpost_door_access)
	return !lock || lock.admits(user, from)

// ===== THE PREBUILT ROOMS =====

/datum/outpost_upgrade/service
	/// TRUE keeps the room's doors public: the door tool refuses them (the teleporter room)
	var/doors_stay_public = FALSE

/// The room's doors to their defaults: the entrance public, staff doors staff. Their free side is the room's inside.
/datum/outpost_upgrade/service/proc/apply_door_defaults()
	if(QDELETED(outpost))
		return
	for(var/datum/weakref/door_ref as anything in doors)
		var/obj/machinery/door/airlock/outpost/service/door = door_ref.resolve()
		if(QDELETED(door))
			continue
		var/access = (!doors_stay_public && door.door_policy == OUTPOST_DOOR_STAFF) ? OUTPOST_DOOR_STAFF : OUTPOST_DOOR_PUBLIC
		outpost.apply_door_access(door, access, outpost_door_first_side(door.unres_sides))

/// The first cardinal in a direction mask, or null
/proc/outpost_door_first_side(sides)
	for(var/side in GLOB.cardinals)
		if(sides & side)
			return side
	return null

// ===== THE DOOR ACCESS TOOL =====

/obj/machinery/computer/camera_advanced/base_construction/ship/outpost
	/// Who sees every outpost door's setting, while the Door Access tool is selected
	var/mob/living/door_access_viewer
	/// The client those images went to
	var/client/door_access_client
	/// Door -> the images shown for it
	var/list/door_access_images
	/// Door -> the setting and free side its images show
	var/list/door_access_looks

/obj/machinery/computer/camera_advanced/base_construction/ship/outpost/Destroy()
	stop_door_access_view()
	return ..()

/obj/machinery/computer/camera_advanced/base_construction/ship/outpost/populate_actions_list()
	..()
	actions += new /datum/action/innate/construction/ship/door_access(src)

/obj/machinery/computer/camera_advanced/base_construction/ship/outpost/remove_eye_control(mob/living/user)
	stop_door_access_view()
	return ..()

/// Managers may sit at the console for the Door Access tool even if they may not build
/obj/machinery/computer/camera_advanced/base_construction/ship/outpost/is_crew_member(mob/user)
	if(..())
		return TRUE
	return attempt_ship_connection() && outpost.may_set_door_access(user)

/// Builders get the build tools, managers get Door Access
/obj/machinery/computer/camera_advanced/base_construction/ship/outpost/GrantActions(mob/living/user)
	. = ..()
	sort_door_access_actions(user)

/obj/machinery/computer/camera_advanced/base_construction/ship/outpost/process()
	. = ..()
	if(!current_user)
		return
	// Roles change while someone sits at the console
	sort_door_access_actions(current_user)
	if(door_access_viewer)
		refresh_door_access_view()

/// Takes the build tools from a user who may not build, and Door Access from one who may not key doors
/obj/machinery/computer/camera_advanced/base_construction/ship/outpost/proc/sort_door_access_actions(mob/living/user)
	if(!user)
		return
	var/builder = isAdminGhostAI(user) || !!outpost?.can_build(user)
	var/manager = !!outpost?.may_set_door_access(user)
	for(var/datum/action/innate/construction/action in actions)
		var/allowed = istype(action, /datum/action/innate/construction/ship/door_access) ? manager : builder
		if(!allowed && action.owner == user)
			action.Remove(user)

/// The door a Door Access click means: the door clicked, or the airlock or windoor on the tile clicked
/obj/machinery/computer/camera_advanced/base_construction/ship/outpost/proc/door_access_target(atom/clicked)
	if(istype(clicked, /obj/machinery/door/airlock) || istype(clicked, /obj/machinery/door/window))
		return clicked
	var/turf/tile = isturf(clicked) ? clicked : null
	if(!tile)
		return null
	return (locate(/obj/machinery/door/airlock) in tile) || (locate(/obj/machinery/door/window) in tile)

/// The radial menu on a clicked door, and what was picked
/obj/machinery/computer/camera_advanced/base_construction/ship/outpost/proc/door_access_menu(mob/living/user, obj/machinery/door/door)
	if(!outpost || user != current_user)
		return
	var/denial = outpost.door_access_denial(user, door)
	if(denial)
		door.balloon_alert(user, LOWER_TEXT(copytext(denial, 1, -1)))
		return
	var/static/list/choices = list(
		"Public" = image(icon = 'icons/hud/radial.dmi', icon_state = "green"),
		"Members" = image(icon = 'icons/hud/radial.dmi', icon_state = "blue"),
		"Staff" = image(icon = 'icons/hud/radial.dmi', icon_state = "yellow"),
		"Owner" = image(icon = 'icons/hud/radial.dmi', icon_state = "red"),
		"Turn free side" = image(icon = 'icons/hud/radial.dmi', icon_state = "radial_rotate"),
	)
	var/choice = show_radial_menu(user, door, choices, custom_check = CALLBACK(src, PROC_REF(door_access_menu_open), user, door), require_near = FALSE, tooltips = TRUE)
	if(!choice || !door_access_menu_open(user, door))
		return
	var/refusal
	var/done
	if(choice == "Turn free side")
		refusal = outpost.turn_door_free_side(user, door)
		var/datum/component/outpost_door_access/lock = door.GetComponent(/datum/component/outpost_door_access)
		done = lock ? "free side [dir2text(lock.free_side)]" : "public"
	else
		refusal = outpost.set_door_access(user, door, LOWER_TEXT(choice))
		var/datum/component/outpost_door_access/lock = door.GetComponent(/datum/component/outpost_door_access)
		done = lock ? lock.sign_text() : "public"
	door.balloon_alert(user, refusal ? LOWER_TEXT(copytext(refusal, 1, -1)) : done)
	refresh_door_access_view()

/// Whether the radial menu on `door` is still good for `user`
/obj/machinery/computer/camera_advanced/base_construction/ship/outpost/proc/door_access_menu_open(mob/living/user, obj/machinery/door/door)
	return !QDELETED(door) && user == current_user && user == door_access_viewer && !isnull(user.client) && !outpost?.door_access_denial(user, door)

/// Starts showing `user` every outpost door's setting
/obj/machinery/computer/camera_advanced/base_construction/ship/outpost/proc/start_door_access_view(mob/living/user)
	if(door_access_viewer == user)
		refresh_door_access_view()
		return
	stop_door_access_view()
	if(!user?.client)
		return
	door_access_viewer = user
	door_access_client = user.client
	door_access_images = list()
	door_access_looks = list()
	RegisterSignals(user, list(COMSIG_MOB_LOGOUT, COMSIG_QDELETING), PROC_REF(on_door_access_viewer_gone))
	refresh_door_access_view()

/// Takes every door image off the viewer
/obj/machinery/computer/camera_advanced/base_construction/ship/outpost/proc/stop_door_access_view()
	if(door_access_viewer)
		UnregisterSignal(door_access_viewer, list(COMSIG_MOB_LOGOUT, COMSIG_QDELETING))
	if(door_access_client)
		for(var/door in door_access_images)
			door_access_client.images -= door_access_images[door]
	door_access_images = null
	door_access_looks = null
	door_access_viewer = null
	door_access_client = null

/// The viewer logged out or was deleted: the tool is deselected and the images go
/obj/machinery/computer/camera_advanced/base_construction/ship/outpost/proc/on_door_access_viewer_gone(mob/source)
	SIGNAL_HANDLER
	var/datum/action/innate/construction/ship/door_access/tool = locate() in actions
	if(tool && source.click_intercept == tool)
		source.click_intercept = null
	stop_door_access_view()

/// Brings the viewer's door images up to date: new doors, changed settings, doors that are gone
/obj/machinery/computer/camera_advanced/base_construction/ship/outpost/proc/refresh_door_access_view()
	if(!door_access_viewer)
		return
	if(QDELETED(outpost) || door_access_viewer != current_user || door_access_viewer.client != door_access_client || !door_access_client)
		stop_door_access_view()
		return
	var/list/present = list()
	for(var/obj/machinery/door/door as anything in outpost.door_access_doors())
		present[door] = TRUE
		var/datum/component/outpost_door_access/lock = door.GetComponent(/datum/component/outpost_door_access)
		var/access = lock ? lock.access : OUTPOST_DOOR_PUBLIC
		var/free_side = lock?.free_side
		var/look = "[access]-[free_side]"
		if(door_access_looks[door] == look)
			continue
		if(door_access_images[door])
			door_access_client.images -= door_access_images[door]
		var/list/new_images = door_access_images_for(door, access, free_side)
		door_access_images[door] = new_images
		door_access_looks[door] = look
		door_access_client.images += new_images
	for(var/door in door_access_images.Copy())
		if(present[door])
			continue
		door_access_client.images -= door_access_images[door]
		door_access_images -= door
		door_access_looks -= door

/// A tint over the door in its setting's colour, and a small arrow on its free side
/obj/machinery/computer/camera_advanced/base_construction/ship/outpost/proc/door_access_images_for(obj/machinery/door/door, access, free_side)
	var/tint_color = outpost_door_tint(access)
	var/image/tint = image(icon = 'icons/effects/alphacolors.dmi', loc = door, icon_state = "white")
	tint.color = tint_color
	tint.alpha = 110
	tint.layer = NAVIGATION_EYE_LAYER
	SET_PLANE_EXPLICIT(tint, ABOVE_GAME_PLANE, door)
	tint.mouse_opacity = MOUSE_OPACITY_TRANSPARENT
	. = list(tint)
	if(!free_side)
		return
	var/image/arrow = image(icon = 'icons/turf/decals.dmi', loc = door, icon_state = "arrows_white", dir = REVERSE_DIR(free_side))
	arrow.color = tint_color
	var/matrix/small = matrix()
	small.Scale(0.5)
	arrow.transform = small
	if(free_side & NORTH)
		arrow.pixel_y = 12
	else if(free_side & SOUTH)
		arrow.pixel_y = -12
	if(free_side & EAST)
		arrow.pixel_x = 12
	else if(free_side & WEST)
		arrow.pixel_x = -12
	arrow.layer = NAVIGATION_EYE_LAYER
	SET_PLANE_EXPLICIT(arrow, ABOVE_GAME_PLANE, door)
	arrow.mouse_opacity = MOUSE_OPACITY_TRANSPARENT
	. += arrow

/// The tint for a setting
/proc/outpost_door_tint(access)
	switch(access)
		if(OUTPOST_DOOR_MEMBERS)
			return OUTPOST_DOOR_TINT_MEMBERS
		if(OUTPOST_DOOR_STAFF)
			return OUTPOST_DOOR_TINT_STAFF
		if(OUTPOST_DOOR_OWNER)
			return OUTPOST_DOOR_TINT_OWNER
	return OUTPOST_DOOR_TINT_PUBLIC

/// Every airlock and windoor on this outpost's main level that the Door Access view shows
/obj/structure/overmap/dynamic/player_outpost/proc/door_access_doors()
	. = list()
	var/list/doors = SSmachines.get_machines_by_type_and_subtypes(/obj/machinery/door/airlock) + SSmachines.get_machines_by_type_and_subtypes(/obj/machinery/door/window)
	for(var/obj/machinery/door/door as anything in doors)
		var/turf/spot = door.loc
		if(!isturf(spot) || !is_turf_buildable(spot) || istype(spot.loc, /area/shuttle) || is_outpost_prison_door(door))
			continue
		. += door

/// Door Access: select it, then pick a door in the camera view
/datum/action/innate/construction/ship/door_access
	name = "Door Access"
	button_icon = 'icons/hud/radial.dmi'
	button_icon_state = "access"
	click_action = TRUE

/datum/action/innate/construction/ship/door_access/set_ranged_ability(mob/living/on_who, text_to_show)
	. = ..()
	var/obj/machinery/computer/camera_advanced/base_construction/ship/outpost/console = target
	if(istype(console))
		console.start_door_access_view(on_who)

/datum/action/innate/construction/ship/door_access/unset_ranged_ability(mob/living/on_who, text_to_show)
	. = ..()
	var/obj/machinery/computer/camera_advanced/base_construction/ship/outpost/console = target
	if(istype(console) && console.door_access_viewer == on_who)
		console.stop_door_access_view()

/datum/action/innate/construction/ship/door_access/InterceptClickOn(mob/living/clicker, params, atom/clicked_on)
	// Examining still works while the tool is selected
	if(LAZYACCESS(params2list(params), SHIFT_CLICK))
		return FALSE
	return ..()

/datum/action/innate/construction/ship/door_access/do_ability(mob/living/clicker, atom/clicked_on)
	var/obj/machinery/computer/camera_advanced/base_construction/ship/outpost/console = target
	if(!istype(console))
		return FALSE
	var/obj/machinery/door/door = console.door_access_target(clicked_on)
	if(!door)
		return FALSE
	// A relog drops the view but can leave the tool selected: bring the view back first
	if(console.door_access_viewer != clicker)
		console.start_door_access_view(clicker)
	INVOKE_ASYNC(console, TYPE_PROC_REF(/obj/machinery/computer/camera_advanced/base_construction/ship/outpost, door_access_menu), clicker, door)
	return TRUE

#undef OUTPOST_DOOR_GROUND_INSIDE
#undef OUTPOST_DOOR_GROUND_OUTSIDE
#undef OUTPOST_DOOR_GROUND_BLOCKED
