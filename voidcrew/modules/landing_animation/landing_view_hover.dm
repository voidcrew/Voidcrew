/**
 * # The planet below
 *
 * A ship flying over a planet has it under the hull for as long as it stays there: the people aboard see it
 * come up as the ship arrives over it and fall away as it leaves. A landing starts from this picture and a
 * takeoff ends on it, so from open space to the ground and back there is always something outside.
 *
 * Made of the same planet as the landing view, held at one size. A handful of screen objects for everyone
 * aboard: it costs nothing to keep.
 */

/// How long the planet takes to come up under a ship that arrives over it, and to fall away when it leaves
#define HOVER_ARRIVE (2.4 SECONDS)
#define HOVER_LEAVE (2 SECONDS)
/// How often the view checks that the ship and its hull are still where it thinks they are
#define HOVER_CHECK (2 SECONDS)

/// The view of the planet this ship is flying over, if it is over one
/obj/structure/overmap/ship/var/datum/landing_view/hover/hover_view

/datum/landing_view/hover
	var/obj/structure/overmap/ship/ship
	/// The planet below
	var/obj/structure/overmap/planet/site
	/// The planet's size and opacity
	var/datum/landing_track/size
	var/datum/landing_track/opacity
	/// Its pieces: see /datum/landing_view/proc/new_planet()
	var/list/grains
	var/datum/landing_view_piece/shade
	var/datum/landing_view_piece/air
	/// TRUE once the ship has left and the planet is falling away
	var/leaving = FALSE
	/// Where the hull's port stood when this was made: a hull that has moved needs a new view
	var/turf/port_turf
	var/next_check = 0

/**
 * * hull_turfs - the hull's turfs in transit
 * * arriving - FALSE to have the planet there at once, at full size: the end of a climb out
 */
/datum/landing_view/hover/New(obj/docking_port/mobile/shuttle, list/hull_turfs, obj/structure/overmap/planet/site, obj/structure/overmap/ship/ship, arriving = TRUE)
	..(shuttle, hull_turfs, null, 0)
	if(ended)
		return
	src.ship = ship
	src.site = site
	port_turf = get_turf(shuttle)
	palette = landing_view_palette_for(site)
	var/list/planet = new_planet()
	grains = planet[1]
	shade = planet[2]
	var/datum/landing_view_piece/whole = grains[1][1]
	size = whole.scale
	air = new_air(whole)
	if(arriving)
		play(LANDING_HOVER_FAR, LANDING_HOVER_SIZE, 0, 255, HOVER_ARRIVE, LANDING_CURVE_OUT)
	else
		play(LANDING_HOVER_SIZE, LANDING_HOVER_SIZE, 255, 255, 0)
	next_check = world.time + HOVER_CHECK
	sync_viewers()

/datum/landing_view/hover/Destroy(force)
	if(ship?.hover_view == src)
		ship.hover_view = null
	ship = null
	site = null
	grains = null
	shade = null
	air = null
	port_turf = null
	return ..()

/// Moves the planet from one size and opacity to another over [time]
/datum/landing_view/hover/proc/play(from_size, to_size, from_opacity, to_opacity, time, curve = LANDING_CURVE_LINEAR)
	var/now = world.time
	size.times = list()
	size.values = list()
	size.curves = list()
	size.mark(now, from_size)
	opacity = new
	opacity.mark(now, from_opacity)
	air.alpha = new
	air.alpha.mark(now, from_opacity * 0.92)
	if(time)
		size.mark(now + time, to_size, curve)
		// solid all the way but for an instant at its smallest: a planet that fades lets the stars show through it
		if(to_opacity > from_opacity)
			opacity.mark(now + 0.2 SECONDS, to_opacity)
			air.alpha.mark(now + 0.2 SECONDS, to_opacity * 0.92)
		else
			opacity.mark(now + time - 0.2 SECONDS, from_opacity)
			air.alpha.mark(now + time - 0.2 SECONDS, from_opacity * 0.92)
			opacity.mark(now + time, to_opacity)
			air.alpha.mark(now + time, to_opacity * 0.92)
	for(var/list/grain as anything in grains)
		for(var/datum/landing_view_piece/sheet as anything in grain)
			sheet.alpha = new
	chain_detail(grains, size, opacity, LANDING_PLANET_DETAIL)
	shade.alpha = opacity
	show(shade)
	show(air)

/// The ship has left the planet behind: it falls away, and then the view deletes itself
/datum/landing_view/hover/proc/leave()
	if(leaving || ended)
		return
	leaving = TRUE
	play(size.at(world.time), LANDING_HOVER_FAR, opacity.at(world.time), 0, HOVER_LEAVE, LANDING_CURVE_IN)
	// a hard reference: the ship may let go of us before then
	addtimer(CALLBACK(GLOBAL_PROC, GLOBAL_PROC_REF(qdel), src), HOVER_LEAVE)

/datum/landing_view/hover/sync_viewers()
	. = ..()
	if(ended || leaving || world.time < next_check)
		return
	next_check = world.time + HOVER_CHECK
	var/obj/structure/overmap/ship/our_ship = ship
	if(QDELETED(our_ship) || QDELETED(shuttle))
		qdel(src)
	else if(get_turf(shuttle) != port_turf)
		// the hull stands somewhere else now: the same planet, around where it is
		qdel(src)
		our_ship.update_hover_view(FALSE)
	else
		our_ship.update_hover_view()

/// The turfs of [shuttle]'s hull where it stands now
/proc/landing_hull_turfs(obj/docking_port/mobile/shuttle)
	. = list()
	for(var/turf/hull_turf as anything in shuttle.return_turfs())
		if(istype(hull_turf.loc, shuttle.area_type) && !istype(hull_turf.loc, /area/shuttle/transit))
			. += hull_turf

/// The planet this ship is flying over and should see under it: none while it is landed, landing or climbing out
/obj/structure/overmap/ship/proc/hover_site()
	if(QDELETED(shuttle) || landing_animation || launch_view)
		return null
	// waiting above a planet for its ground to be made ready
	if(state == OVERMAP_SHIP_DOCKING && docked && landing_animation_wanted(docked))
		return docked
	if(docked || (state != OVERMAP_SHIP_FLYING && state != OVERMAP_SHIP_ACTING))
		return null
	var/turf/tile = loc
	if(!istype(tile))
		return null
	for(var/obj/structure/overmap/planet/planet in tile)
		if(landing_animation_wanted(planet))
			return planet
	return null

/**
 * Brings the view of the planet below up to date with where the ship is: made when it comes over a planet,
 * sent away when it leaves.
 * * arriving - FALSE if a new view should be there at once and not come up from afar
 */
/obj/structure/overmap/ship/proc/update_hover_view(arriving = TRUE)
	var/obj/structure/overmap/planet/over = hover_site()
	if(!QDELETED(hover_view))
		if(!hover_view.leaving && hover_view.site == over)
			return
		if(!over)
			hover_view.leave()
			return
		// straight on to another: the old one goes at once, so the two never share the hull
		QDEL_NULL(hover_view)
	hover_view = null
	if(!over || !istype(shuttle.get_docked(), /obj/docking_port/stationary/transit))
		return
	var/list/hull = landing_hull_turfs(shuttle)
	if(!length(hull))
		return
	hover_view = new(shuttle, hull, over, src, arriving)
	if(hover_view.ended)
		QDEL_NULL(hover_view)

/**
 * A descent is starting: the view of the planet below is over, and the descent carries on from the size the
 * planet had in it. Null if there was none.
 */
/obj/structure/overmap/ship/proc/take_hover()
	if(QDELETED(hover_view))
		hover_view = null
		return null
	if(!hover_view.leaving)
		. = hover_view.size.at(world.time)
	QDEL_NULL(hover_view)

/obj/structure/overmap/ship/Moved(atom/old_loc, movement_dir, forced, list/old_locs, momentum_change = TRUE)
	. = ..()
	update_hover_view()

#undef HOVER_ARRIVE
#undef HOVER_LEAVE
#undef HOVER_CHECK
