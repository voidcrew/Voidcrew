/**
 * Ambient bleed - starlight, generalised to any area that lights its turfs wholesale.
 *
 * An area with static_lighting FALSE and a base_lighting_alpha paints its light as one
 * BLEND_ADD overlay on the area itself. Its turfs carry no lighting objects and emit
 * nothing, so a statically lit tile sitting against one - a ruin's outer wall, the hull
 * of a landed ship, the mouth of a cave - receives no light at all from the bright
 * ground beside it and renders as a razor-hard black edge.
 *
 * tg already solves exactly this problem at the space/station boundary. Starlight is not
 * an area effect: it is a real light source placed on space turfs, but only on the ones
 * that actually touch something lit statically, switched on and off lazily as the
 * boundary moves (see /turf/open/space/proc/update_starlight). This is the same
 * mechanism with the trigger widened from "is a space turf" to "is in an area that
 * lights it wholesale", so ruins, landed ships and cave mouths on a base-lit planet get
 * the same soft edge the station gets against space.
 *
 * The capability test is derived from the AREA, never from a list of turf types. Turfs
 * change areas constantly here - a ship landing moves its hull into its own areas, cave
 * generation repaints tiles into cave areas, players repaint rooms - and a type list
 * would be stale the first time any of that happened.
 *
 * Brightness is derived too, never hardcoded. An edge light emits the area's own
 * base_lighting_color at the area's own base_lighting_alpha, divided down by the number
 * of edge sources that overlap a corner on a straight boundary. That is what keeps the
 * lit side of the boundary level with the ambient instead of ringing it in a halo
 * brighter than the daylight it is bleeding from.
 *
 * Four hooks keep the boundary current, all of them mirrors of the starlight ones:
 * - /datum/lighting_object/New(), when a static tile appears next to base-lit ground
 * - /turf/ChangeTurf() (the live copy is in voidcrew/edits/turf.dm), when a tile's own
 *   type changes underneath it
 * - /turf/proc/transfer_area_lighting(), when a tile changes area without changing type
 * - and nothing else: a freshly generated planet gets its edges from the first two as
 *   the terrain and the cave areas are laid down.
 */

/**
 * Marks an area whose light IS the area: one BLEND_ADD overlay on the area itself
 * (base_lighting_color at base_lighting_alpha), and NOTHING on its turfs. Two things
 * follow from setting it, and both are the point:
 *
 * 1. Its turfs are denied lighting objects entirely - see /turf/proc/skips_lighting_object()
 *    and the gate in both copies of /turf/ChangeTurf. A generated planet surface is
 *    ~14,000 turfs, and a lighting object apiece (with the four corners each one pulls
 *    into existence) is the single largest block of memory a planet holds. Measured at
 *    roughly 1 GB across a live fleet's worth of planets.
 * 2. Its turfs bleed light onto statically lit tiles at its boundary, so ruin walls,
 *    cave mouths and landed hulls are not razor-hard black edges against bright ground.
 *
 * This is deliberately an explicit opt-in flag rather than "any dynamic area with
 * base_lighting_alpha". Several areas match that description and must NOT be caught:
 * /area/space above all, where a player-built floor genuinely does want a lighting object
 * so starlight renders a gradient across it, and likewise the holodeck, /area/shuttle/transit,
 * bitrunning domains and the away missions. Only planet surfaces are ambient-lit ground.
 *
 * An area setting this must also set static_lighting = FALSE and a non-zero
 * base_lighting_alpha; every gate checks all three, so a half-configured area is inert
 * rather than dark.
 */
/area/var/ambient_lighting = FALSE

/**
 * TRUE when this turf must carry no lighting object at all, because its area paints it
 * wholesale and it contributes nothing of its own for an object to render.
 *
 * The exception is a turf that lights ITSELF - the fallout zone's hazard green
 * (/turf/open/misc/asteroid/sand/lit/nuclear), a lava river on a volcanic planet. Its
 * light source needs somewhere to land, and the only lighting object in reach is its own,
 * so those keep one. That is what preserves the nuclear biome's telegraph: a contaminated
 * blob still renders green against the neutral ambient around it, exactly as before,
 * because every tile in the blob draws its own light.
 *
 * Our own edge lights are not "lighting itself": AMBIENT_BLEED_RANGE is the marker for
 * those (see enable_ambient_bleed), and a boundary tile that picked one up must not start
 * demanding a lighting object on the next ChangeTurf over it.
 */
/turf/proc/skips_lighting_object()
	var/area/our_area = loc
	if(!our_area || !our_area.ambient_lighting || our_area.static_lighting || !our_area.base_lighting_alpha)
		return FALSE
	if(light_range && light_range != AMBIENT_BLEED_RANGE)
		return FALSE
	return TRUE

/// Returns the area that lights this turf wholesale, or null when this turf is not a
/// candidate to bleed light onto its neighbours. Space turfs are excluded because
/// starlight already covers them, and cordons because they are map-edge filler that
/// should neither emit nor receive.
/turf/proc/ambient_bleed_area()
	if(isspaceturf(src) || istype(src, /turf/cordon))
		return null
	var/area/our_area = loc
	if(!our_area || !our_area.ambient_lighting || our_area.static_lighting || !our_area.base_lighting_alpha)
		return null
	return our_area

/// Turns this turf's ambient bleed light on, or refreshes it if the area has been
/// retuned since. Pass our_area when the caller already has it.
///
/// A turf that lights itself - lava, a chasm, a light floor - is left completely alone.
/// Its own light is already reaching the tile across the boundary, and overwriting it
/// with a dimmer edge light would be a visible downgrade. AMBIENT_BLEED_RANGE is below
/// every light range any turf type in the codebase declares, so it doubles as the marker
/// for "this light is one of ours and safe to touch".
/turf/proc/enable_ambient_bleed(area/our_area)
	if(light_range && light_range != AMBIENT_BLEED_RANGE)
		return
	// Checked here and not only in ambient_bleed_area(), because callers that already
	// hold the area skip that proc entirely - and /area/space and the voidcrew asteroid
	// field are both base-lit dynamic areas full of space turfs. Starlight owns those.
	if(isspaceturf(src) || istype(src, /turf/cordon))
		return
	our_area ||= ambient_bleed_area()
	if(!our_area)
		return
	var/bleed_power = (our_area.base_lighting_alpha / 255) / AMBIENT_BLEED_OVERLAP_FACTOR
	var/bleed_color = our_area.base_lighting_color
	// Same sentinel /area/proc/add_base_lighting() honours: an area painted in
	// COLOR_STARLIGHT actually renders in the live, nebula-tinted GLOB.starlight_color,
	// so the edge has to follow it or the seam it exists to hide comes back in a
	// different hue.
	if(bleed_color == COLOR_STARLIGHT)
		bleed_color = GLOB.starlight_color
	// Already emitting exactly this. Comparing is several var reads cheaper than the
	// light source rebuild set_light() would do, and this runs off a neighbour scan.
	if(light_on && light_power == bleed_power && light_color == bleed_color)
		return
	set_light(l_range = AMBIENT_BLEED_RANGE, l_power = bleed_power, l_color = bleed_color, l_on = TRUE)

/// Turns our bleed light back off, leaving any light the turf provides itself alone.
/turf/proc/disable_ambient_bleed()
	if(light_on && light_range == AMBIENT_BLEED_RANGE)
		set_light(l_on = FALSE)

/// Called whenever we are unsure whether this turf should be bleeding. Lights up if any
/// of the nine tiles around us reads light sources of its own, goes dark otherwise.
/// Returns TRUE if we ended up lit. Mirrors /turf/open/space/proc/update_starlight.
/turf/proc/update_ambient_bleed(area/our_area)
	our_area ||= ambient_bleed_area()
	if(!our_area)
		disable_ambient_bleed()
		return FALSE
	for(var/turf/neighbor as anything in RANGE_TURFS(1, src))
		// No lighting object means nothing on that tile reads light sources at all, so
		// there is nothing for us to add to.
		if(!neighbor.lighting_object)
			continue
		var/area/neighbor_area = neighbor.loc
		// Its own area already paints it, so it is not a dark edge and there is nothing to
		// add to. Ambient-lit ground has no lighting objects at all any more, so the test
		// above usually catches it first - but a tile that lights ITSELF inside such an
		// area does keep an object (fallout ground, a lava river; see
		// skips_lighting_object()), and without this clause every surface tile around a
		// contaminated blob would decide it had a dark neighbour and light itself.
		if(neighbor_area.ambient_lighting && !neighbor_area.static_lighting && neighbor_area.base_lighting_alpha)
			continue
		if(istype(neighbor, /turf/cordon))
			continue
		enable_ambient_bleed(our_area)
		return TRUE
	disable_ambient_bleed()
	return FALSE

/// Have the base-lit tiles around us work out again whether they should be bleeding onto
/// us. Called when we start or stop being something worth bleeding onto.
/turf/proc/reconsider_ambient_bleed_neighbors()
	for(var/turf/neighbor as anything in RANGE_TURFS(1, src))
		if(neighbor == src)
			continue
		// Inline capability test, so a neighbourhood with no ambient-lit area in it costs
		// one var read per tile and no proc call at all.
		var/area/neighbor_area = neighbor.loc
		if(!neighbor_area.ambient_lighting || neighbor_area.static_lighting || !neighbor_area.base_lighting_alpha)
			continue
		// Deliberately not passing neighbor_area: the area is only half the test, and
		// letting update_ambient_bleed() re-derive it keeps the space and cordon
		// exclusions in one place.
		neighbor.update_ambient_bleed()

/**
 * Post-ChangeTurf ambient bleed maintenance, called from both copies of
 * /turf/ChangeTurf directly after the starlight branches it mirrors.
 *
 * A ChangeTurf never moves a turf between areas, so area-derived capability is constant
 * across the change and only the turf's own type can have flipped it - by becoming, or
 * ceasing to be, a space turf or a cordon. Area moves (a ship landing or taking off, a
 * room being repainted) arrive through transfer_area_lighting instead.
 *
 * The new turf datum starts with the type's own light vars, so any bleed light we had is
 * already gone by the time we get here - same reason the starlight branch above has to
 * re-enable off old_light_range. That is what re-lights a ship's landing site when the
 * ship takes off and its hull tiles revert to planet baseturfs: the tiles come back as
 * ordinary surface ground in the surface area, is_ambient is TRUE, and the scan finds
 * whatever static tiles are still standing next to them.
 */
/turf/proc/update_ambient_bleed_after_change(old_type, datum/lighting_object/old_lighting_object)
	var/area/our_area = loc
	var/area_bleeds = (our_area.ambient_lighting && !our_area.static_lighting && our_area.base_lighting_alpha)

	var/was_ambient = area_bleeds && !ispath(old_type, /turf/open/space) && !ispath(old_type, /turf/cordon)
	var/is_ambient = area_bleeds && !isspaceturf(src) && !istype(src, /turf/cordon)
	if(is_ambient)
		update_ambient_bleed(our_area)
	else if(was_ambient)
		disable_ambient_bleed()

	// A tile is worth bleeding onto when it carries a lighting object of its own and its
	// area is not already painting it. Only a change in that answer can change what the
	// tiles around us should be doing.
	var/was_target = old_lighting_object && !was_ambient && !ispath(old_type, /turf/open/space) && !ispath(old_type, /turf/cordon)
	var/is_target = lighting_object && !is_ambient && !isspaceturf(src) && !istype(src, /turf/cordon)
	if(was_target != is_target)
		reconsider_ambient_bleed_neighbors()
