/**
 * Alters the position and orientation of a stationary docking port so any mobile
 * port small enough can dock within its bounds.
 *
 * Shared by planets, space ruins and trader outposts (was copy-pasted per type).
 * Callers are responsible for checking the shuttle actually fits afterwards.
 */
/proc/adjust_reserve_dock_to_shuttle(obj/docking_port/stationary/dock_to_adjust, obj/docking_port/mobile/shuttle)
	// the shuttle's dimensions where "true height" measures distance from the shuttle's fore to its aft
	var/shuttle_true_height = shuttle.height
	var/shuttle_true_width = shuttle.width
	// if the port's location is perpendicular to the shuttle's fore, the "true height" is the port's "width" and vice-versa
	if(EWCOMPONENT(shuttle.port_direction))
		shuttle_true_height = shuttle.width
		shuttle_true_width = shuttle.height
	// the dir the stationary port should be facing (note that it points inwards)
	var/final_facing_dir = angle2dir(dir2angle(shuttle_true_height > shuttle_true_width ? EAST : NORTH)+dir2angle(shuttle.port_direction)+180)
	var/list/old_corners = dock_to_adjust.return_coords() // coords for "bottom left" / "top right" of dock's covered area, rotated by dock's current dir
	var/list/new_dock_location // TBD coords of the new location
	if(final_facing_dir == dock_to_adjust.dir)
		new_dock_location = list(old_corners[1], old_corners[2]) // don't move the corner
	else if(final_facing_dir == angle2dir(dir2angle(dock_to_adjust.dir)+180))
		new_dock_location = list(old_corners[3], old_corners[4]) // flip corner to the opposite
	else
		var/combined_dirs = final_facing_dir | dock_to_adjust.dir
		if(combined_dirs == (NORTH|EAST) || combined_dirs == (SOUTH|WEST))
			new_dock_location = list(old_corners[1], old_corners[4]) // move the corner vertically
		else
			new_dock_location = list(old_corners[3], old_corners[2]) // move the corner horizontally
		// we need to flip the height and width
		var/dock_height_store = dock_to_adjust.height
		dock_to_adjust.height = dock_to_adjust.width
		dock_to_adjust.width = dock_height_store

	dock_to_adjust.dir = final_facing_dir

	// offset for the dock within its area
	var/new_dheight = round((dock_to_adjust.height-shuttle.height)/2) + shuttle.dheight
	var/new_dwidth = round((dock_to_adjust.width-shuttle.width)/2) + shuttle.dwidth

	// use the relative-to-dir offset above to find the absolute position offset for the dock
	switch(final_facing_dir)
		if(NORTH)
			new_dock_location[1] += new_dwidth
			new_dock_location[2] += new_dheight
		if(SOUTH)
			new_dock_location[1] -= new_dwidth
			new_dock_location[2] -= new_dheight
		if(EAST)
			new_dock_location[1] += new_dheight
			new_dock_location[2] -= new_dwidth
		if(WEST)
			new_dock_location[1] -= new_dheight
			new_dock_location[2] += new_dwidth

	dock_to_adjust.forceMove(locate(new_dock_location[1], new_dock_location[2], dock_to_adjust.z))
	dock_to_adjust.dheight = new_dheight
	dock_to_adjust.dwidth = new_dwidth

/**
 * Records where a freshly built reserve berth stands, so it can be put back later.
 *
 * Call once, immediately after creating and sizing the dock. There are three different layouts that
 * produce these berths - spawn_dynamic_encounter() works off z-level bounds for planets, empty space
 * and player outposts, while space ruins and meteor fields place theirs at opposite corners of a turf
 * reservation - and copying any of those formulas into a reset proc means two places to keep in step.
 * Having the dock remember its own origin means the reset needs no layout knowledge at all.
 *
 * Coordinates rather than a turf reference on purpose: these berths sit on turf reservations that get
 * released and recycled, and a held turf ref would outlive the ground it names.
 */
/obj/docking_port/stationary/proc/mark_reserve_home()
	var/turf/here = get_turf(src)
	if(!here)
		return
	reserve_home_x = here.x
	reserve_home_y = here.y
	reserve_home_z = here.z

/**
 * Puts one free reserve berth back to the size, orientation and position it was built with.
 *
 * A berth does not stay where it was built. adjust_reserve_dock_to_shuttle() rotates and offsets it
 * to fit whoever is arriving, the ship-to-ship pairing procs move it flush against another dock, and
 * hull_reseat_port() drags it along when a ship relocates its own docking port while parked on it -
 * which it has to, because get_docked() finds a stationary port by the mobile port's turf. All three
 * leave it somewhere other than home.
 *
 * Only two of them actually move the GROUND it covers, though, and it is worth being precise about
 * which. adjust_reserve_dock_to_shuttle() looks like a walker - it moves the anchor corner and swaps
 * width/height on a perpendicular re-facing - but its projected rectangle is invariant: the
 * new_dwidth/new_dheight it adds to the position are exactly the dwidth/dheight that return_coords()
 * subtracts back out, so a 56x40 berth stays on the same 56x40 ground whoever docks there. (An
 * earlier version of this comment claimed the opposite and blamed repeated visits for walking the
 * berth off its padded strip; that was wrong, and the clamp that would have belonged there does not.)
 *
 * The real displacement comes from hull_reseat_port() and the ship-to-ship pairing, both of which
 * move the dock's tile without recomputing its offsets - see clamp_reserve_dock_to_site() below,
 * which is what keeps that displacement inside the site the berth belongs to.
 *
 * Skips a dock with a shuttle physically parked on it: moving that berth would divorce it from the
 * hull standing on top of it.
 */
/proc/reset_reserve_dock_to_home(obj/docking_port/stationary/dock)
	if(QDELETED(dock) || !dock.reserve_home_z)
		return
	if(dock.get_docked())
		return
	var/turf/home = locate(dock.reserve_home_x, dock.reserve_home_y, dock.reserve_home_z)
	if(!home)
		return
	dock.dir = NORTH
	dock.width = RESERVE_DOCK_MAX_SIZE_LONG
	dock.height = RESERVE_DOCK_MAX_SIZE_SHORT
	dock.dwidth = 0
	dock.dheight = 0
	dock.forceMove(home)

/**
 * Slides a docking port's PROJECTED rectangle by (shift_x, shift_y) without moving the port's
 * own tile.
 *
 * return_coords() derives the rectangle from the port's position minus its dwidth/dheight,
 * rotated by dir, so the offsets are the only lever that moves the ground a berth claims while
 * leaving the port where it stands - which it has to, since get_docked() resolves a berth by the
 * mobile port's turf and any real move would divorce the two. Both corners carry the same
 * -dwidth*cos / -dheight*cos terms, so the rectangle translates rigidly; nothing is resized.
 *
 * The per-dir signs are read straight off return_coords() (shuttle.dm): NORTH cos=1 sin=0,
 * SOUTH cos=-1, WEST cos=0 sin=1, EAST cos=0 sin=-1. Any non-cardinal dir is treated as NORTH,
 * which is what return_coords() itself does.
 */
/proc/offset_docking_port_rect(obj/docking_port/port, shift_x, shift_y)
	if(QDELETED(port) || (!shift_x && !shift_y))
		return
	switch(port.dir)
		if(SOUTH)
			port.dwidth += shift_x
			port.dheight += shift_y
		if(WEST)
			port.dwidth -= shift_y
			port.dheight += shift_x
		if(EAST)
			port.dwidth += shift_y
			port.dheight -= shift_x
		else
			port.dwidth -= shift_x
			port.dheight -= shift_y

/**
 * Pulls a reserve berth's projected rectangle back inside the site that owns it.
 *
 * hull_reseat_port() drags the stationary berth onto an arbitrary hull turf so the ship stays
 * "docked" at it, and does not recompute dwidth/dheight - so the whole 56x40 rectangle translates
 * by that delta, up to the hull's own extent (~55 tiles) against three tiles of padding. That was
 * survivable while an encounter owned a z-level to itself: the berth landed in empty reservation
 * padding and reset_reserve_dock_to_home() put it back before the next arrival. On a packed level
 * the same 55 tiles cross the gutter, and a rectangle sitting on a neighbour's ground is what
 * SSshuttle.get_dock_overlap(), the teardown hull-overlap guards and the next
 * adjust_reserve_dock_to_shuttle() all then reason about.
 *
 * The site is resolved from where the berth was BUILT (mark_reserve_home()), not from where it has
 * been dragged to: a berth already pulled across the gutter would otherwise be "clamped" to the
 * neighbour it just landed in. Same shape as the fit test in position_dock_across_from().
 *
 * Returns TRUE if it had to move anything.
 */
/proc/clamp_reserve_dock_to_site(obj/docking_port/stationary/dock)
	if(QDELETED(dock))
		return FALSE
	var/turf/here = get_turf(dock)
	if(!here)
		return FALSE
	var/datum/site
	if(dock.reserve_home_z)
		site = map_region_for_turf(locate(dock.reserve_home_x, dock.reserve_home_y, dock.reserve_home_z))
	if(isnull(site))
		site = map_region_for_turf(here)
	// No region at all - a mapped berth, a roundstart level - means there is nothing to be
	// outside of, and the berth keeps the behaviour it had before packing.
	var/list/site_rect = map_region_rect(site, here.z)
	if(!site_rect)
		return FALSE

	var/list/coords = dock.return_coords()
	var/rect_low_x = min(coords[1], coords[3])
	var/rect_high_x = max(coords[1], coords[3])
	var/rect_low_y = min(coords[2], coords[4])
	var/rect_high_y = max(coords[2], coords[4])

	var/shift_x = 0
	var/shift_y = 0
	if(rect_low_x < site_rect[1])
		shift_x = site_rect[1] - rect_low_x
	else if(rect_high_x > site_rect[3])
		shift_x = site_rect[3] - rect_high_x
	if(rect_low_y < site_rect[2])
		shift_y = site_rect[2] - rect_low_y
	else if(rect_high_y > site_rect[4])
		shift_y = site_rect[4] - rect_high_y
	if(!shift_x && !shift_y)
		return FALSE

	offset_docking_port_rect(dock, shift_x, shift_y)
	log_shuttle("[dock]: berth rectangle ([rect_low_x],[rect_low_y])-([rect_high_x],[rect_high_y]) on z=[here.z] escaped its site \
		([site_rect[1]],[site_rect[2]])-([site_rect[3]],[site_rect[4]]) - pulled back by ([shift_x],[shift_y])")
	return TRUE

/**
 * Restores both of an encounter's reserve berths, skipping any that is claimed or occupied.
 *
 * Call this before choosing a berth for an arriving ship, so the placement is computed from known
 * geometry rather than from whatever the last visitor left behind.
 *
 * Taking the docks and the claim flags as arguments rather than reading them off a type is
 * deliberate: /obj/structure/overmap/planet, /event, /space_ruin and /dynamic are siblings that each
 * redeclare their own reserve_dock/first_dock_taken pair, so there is no shared parent to hang this
 * on and no way to write it once except as a free proc.
 */
/proc/reset_free_reserve_docks_for(obj/docking_port/stationary/primary, obj/docking_port/stationary/secondary, primary_taken = FALSE, secondary_taken = FALSE)
	if(!primary_taken)
		reset_reserve_dock_to_home(primary)
	if(!secondary_taken)
		reset_reserve_dock_to_home(secondary)
