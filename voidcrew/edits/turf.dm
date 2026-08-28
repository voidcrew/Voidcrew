/turf
	var/datum/biome/generating_biome

/**
 * Frees every lighting datum this turf still owns or still pins, on a teardown that is
 * about to hand its ground back to the map-zone pool.
 *
 * Three things have to go, and only the first is anybody else's job:
 *
 * 1. `lighting_object` - collectable on its own (the turf points at it, not the other way
 *    round), but qdel'ing it also takes it out of SSlighting.objects_queue.
 * 2. `light` - our own /datum/light_source. ChangeTurf's qdel(src) frees this for us on the
 *    paths that use ChangeTurf; the raw-swap teardown (clear_to_uninitialized_space) has to
 *    do it by hand, and doing it here on both paths costs nothing.
 * 3. ORPHANED sources on our corners. This is the one nothing else can reach. A light
 *    source and the corners it applies to hold each other - `light.effect_str[corner]`
 *    against `corner.affecting` - which under pure refcounting is an uncollectable cycle
 *    unless somebody breaks it explicitly. `/atom/Destroy()` is what normally breaks it,
 *    via QDEL_NULL(light); a turf replaced by a bare `new path(src)` never runs Destroy(),
 *    so its source is left applied to corners with `source_atom` silently retargeted to the
 *    replacement turf - which does not own it and will never free it. From that moment the
 *    only path to the datum is through a corner, which is why this walks them.
 *
 * The orphan test is `owner.light != src`: an atom owns at most one source and always
 * through that var, so a source its own atom does not point back at is unreachable by
 * design. QDELETED sources are skipped - a source mid-Destroy transiently fails the test.
 *
 * Corners are idled out last, once every source that could still be holding them is gone.
 * self_destruct_if_idle() only fires on a corner with no `affecting` at all, and a corner
 * is cheap to regenerate (GENERATE_MISSING_CORNERS rebuilds it the next time any source
 * reaches this vertex), so this is safe even for the corners we share with a live
 * co-tenant on the far side of the cordon.
 */
/turf/proc/scrub_lighting_for_teardown()
	if(lighting_object)
		qdel(lighting_object, force = TRUE)
	if(light)
		QDEL_NULL(light)

	var/datum/lighting_corner/corner_ne = lighting_corner_NE
	var/datum/lighting_corner/corner_se = lighting_corner_SE
	var/datum/lighting_corner/corner_sw = lighting_corner_SW
	var/datum/lighting_corner/corner_nw = lighting_corner_NW

	release_orphan_corner_sources(corner_ne)
	release_orphan_corner_sources(corner_se)
	release_orphan_corner_sources(corner_sw)
	release_orphan_corner_sources(corner_nw)

	// Re-read: qdel'ing a source above can already have idled a corner out from under us,
	// and /datum/lighting_corner/Destroy() nulls exactly these vars.
	lighting_corner_NE?.self_destruct_if_idle()
	lighting_corner_SE?.self_destruct_if_idle()
	lighting_corner_SW?.self_destruct_if_idle()
	lighting_corner_NW?.self_destruct_if_idle()

/**
 * The one thing a RAW turf swap (`new turf_type(existing_turf)`) must do before it drops
 * the old turf on the floor, and the cheapest possible version of it.
 *
 * A raw swap never runs the old turf's Destroy(). Almost everything that costs is
 * recoverable - the replacement rebuilds its own atmos, its own corners, its own
 * smoothing. Exactly one thing is not: `/datum/light_source`. A source and every
 * `/datum/lighting_corner` it applies to hold each other (`source.effect_str[corner]`
 * against `corner.affecting`), BYOND is pure reference counting, and the ONLY thing that
 * ever breaks that cycle is `/atom/Destroy()` -> `QDEL_NULL(light)`. Drop the turf without
 * running it and the source becomes permanently unreachable and permanently applied, and
 * it drags its corners with it. Measured on the 2026-08-19 overnight: 4,750 orphaned
 * sources and 5,800 orphaned corners PER CYCLE, ~107k leaked datums an hour, which was the
 * whole of the run's 140 MB/h.
 *
 * This is deliberately not scrub_lighting_for_teardown(): that one also sweeps the four
 * corners for sources orphaned EARLIER and idles them out, which is right for a teardown
 * running once over a departing tenant and far too expensive for a generator laying down
 * tens of thousands of turfs. Freeing our own source is enough here, because a raw swap
 * orphans a source only through the `light` var this frees - and the corners follow on
 * their own: light_source/Destroy() -> remove_lum() queues every corner it touched, and
 * SSlighting idles out the ones that are left with nothing affecting them.
 *
 * Callers must gate on `SSlighting.initialized`. Before it comes up nothing is lit, there
 * is nothing to free, and the roundstart map loader's fast path should stay exactly as
 * fast as it was.
 */
/turf/proc/release_light_for_raw_swap()
	if(lighting_object)
		qdel(lighting_object, force = TRUE)
	if(light)
		QDEL_NULL(light)

/**
 * Takes a turf out of the atmos simulation before a teardown blanks it, and unlinks it from
 * its neighbours in BOTH directions.
 *
 * atmos_adjacent_turfs is a mutual pairing - A lists B and B lists A - and
 * immediate_calculate_adjacent_turfs() is the only thing that ever writes either half. A
 * teardown does not run it. It blanks a rectangle turf by turf and yields between turfs, so
 * SSair keeps firing against a half-torn block: every turf already blanked is still listed
 * by every neighbour the sweep has not reached yet, while the replacement lists nobody.
 * Both of the ways that goes wrong were showing up in voidcrew_ruin_area_instancing:
 *
 * * A raw swap to /turf/open/space/basic leaves a turf with a NULL air, because basic never
 *   initializes. process_cell() on any neighbour still holding it runs LINDA_CYCLE_ARCHIVE
 *   over that entry - "Cannot execute null.archive()", once per live neighbour per tick.
 * * Even the full ChangeTurf to /turf/open/space that clear_reservation() does leaves the
 *   pairing ONE-SIDED, and one-sided is its own bug. The neighbour skips group handling for
 *   a turf that already ran this cycle (process_cell()'s `continue` on current_cycle) but
 *   still shares 100% with it afterwards through share_end, because space sets run_later.
 *   That reaches LAST_SHARE_CHECK having formed no excited group, with a full tile of moles
 *   just moved - "Cannot execute null.reset_cooldowns()".
 *
 * Unlinking rather than recalculating is deliberate: this ground is on its way out, so the
 * correct adjacency for it is none, and a recalc would cost a CANATMOSPASS per direction on
 * every turf of a ~15k-tile slot. Callers that leave live ground next door rebuild the real
 * adjacency on the surviving ring once, after the sweep.
 *
 * The `excited || excited_group` gate on remove_from_active() is the same test
 * /turf/open/ChangeTurf() uses: `excited` is exactly active_turfs membership, the removal is
 * a full list scan, and it is only worth paying for the turfs that were really processing.
 */
/turf/proc/detach_from_atmos_for_teardown()
	if(isopenturf(src))
		var/turf/open/open_self = src
		if(open_self.excited || open_self.excited_group)
			SSair.remove_from_active(src)

	// VOIDCREW EDIT: and off the SUPERCONDUCTION list, which is a separate list that
	// remove_from_active() has never touched. It holds closed turfs (walls conducting through
	// themselves) as well as open ones, so this sits outside the branch above. The raw swap
	// this proc precedes retargets the entry onto an uninitialized /turf/open/space/basic with
	// a null `air`, and process_super_conductivity() then calls super_conduct() on it every
	// tick forever - archive(), neighbor_conduct_with_src() and finish_superconduction() all
	// dereference the missing mixture. Round 19 logged ~190 of those from one torn-down slot.
	SSair.active_super_conductivity -= src

	// Our half of every pairing we know about.
	var/list/our_adjacency = atmos_adjacent_turfs
	if(our_adjacency)
		for(var/turf/neighbour as anything in our_adjacency)
			if(!neighbour.atmos_adjacent_turfs)
				continue
			neighbour.atmos_adjacent_turfs -= src
			UNSETEMPTY(neighbour.atmos_adjacent_turfs)
		atmos_adjacent_turfs = null

	// And the half we do NOT know about. An earlier turf in this same sweep can already have
	// left us pointing at nobody while a neighbour still points at us, and that entry is the
	// one that runtimes. Only the turfs immediate_calculate_adjacent_turfs() pairs with can
	// be holding us, so this is the complete set.
	for(var/direction in GLOB.cardinals_multiz)
		var/turf/side_turf = get_step_multiz(src, direction)
		if(isnull(side_turf) || !side_turf.atmos_adjacent_turfs)
			continue
		side_turf.atmos_adjacent_turfs -= src
		UNSETEMPTY(side_turf.atmos_adjacent_turfs)

/**
 * Returns a vacated open-space turf to uninitialized /turf/open/space/basic, freeing the
 * lighting it accumulated while it was somebody's neighbour.
 *
 * Every hull departure ScrapeAway()s its rect down to the level's space - a full ChangeTurf,
 * so what is left is an INITIALIZED /turf/open/space carrying a starlight/bleed
 * /datum/light_source and four corners wherever it borders anything lit. Encounter slots
 * get swept back to basic by clear_to_uninitialized_space() when the site tears down, but
 * the open space of a ship level has no teardown - so every dock, undock and hull death
 * left its rect permanently lit. Measured on the 2026-08-21 six-hour ghost round: +212k
 * lit space turfs and +330k lighting datums, ~40% of the post-fill memory slope; the churn
 * soak reproduces it as ~14k retained light sources per seven hull cycles.
 *
 * The four steps are the zone sweep's, in its order (see clear_to_uninitialized_space()):
 * scrub the turf's own lighting and orphaned corner sources, detach from the atmos
 * simulation (the replacement has null air, so anything still listing it as an atmos
 * neighbour archives null every tick - see detach_from_atmos_for_teardown()), leave
 * GLOB.starlight (Destroy() never runs on a raw swap, and a stale entry both relights and
 * duplicates later), then the raw swap itself.
 *
 * WHERE this may run is the caller's job: only on space turfs standing OUTSIDE every live
 * map region (map_region_for_turf() null) - a berth inside a site's footprint becomes the
 * site's ground and is the site teardown's to sweep, and transit space belongs to its
 * reservation.
 */
/turf/proc/return_to_uninitialized_space()
	scrub_lighting_for_teardown()
	detach_from_atmos_for_teardown()
	if(isspaceturf(src) && light_on)
		GLOB.starlight -= src
	new /turf/open/space/basic(src)

/**
 * The other half of release_light_for_raw_swap(): puts back the lighting state a raw swap
 * drops. Call it on the REPLACEMENT turf, with the four corner refs and the lumcount read
 * off the old turf immediately BEFORE `new path(old_turf)`.
 *
 * A /datum/lighting_corner is shared by the four turfs meeting at its vertex, and each of
 * them reaches it through one of lighting_corner_NE/SE/SW/NW. /turf/ChangeTurf saves those
 * four refs across its own qdel()/new() pair and writes them back afterwards (the block
 * just under AfterChange() below). A raw `new turf_type(old_turf)` gets the TYPE DEFAULTS
 * instead, so the replacement comes up with four null corner refs while the three
 * neighbours at each of its vertices still point at the originals.
 *
 * That state is not self-healing, it is self-corrupting. The next light source whose
 * impacted_corners() reaches the tile runs GENERATE_MISSING_CORNERS on it, which mints
 * four BRAND NEW corners for vertices that already have perfectly good ones - and
 * /datum/lighting_corner/New() writes itself into all four adjacent turfs unconditionally
 * (code/modules/lighting/lighting_corner.dm). So a finished neighbour on the far side of
 * that vertex - a cave tile that owns a /datum/lighting_object and has real accumulated
 * lum - silently has its corner pointer swapped for a fresh one reading zero, and the
 * sources that had already applied to the original never re-apply, because they recorded
 * it as source.effect_str[old_corner] and nothing queues them again.
 *
 * What that looks like in game is a cave mouth lit on one side and razor black on the
 * other, decided purely by the order the generator happened to lay the two sides down in.
 * Carry the corners and a raw swap is lighting-identical to a ChangeTurf.
 *
 * Dynamic (overlay-light) lum used to ride along here as a fifth argument, for the same
 * reason ChangeTurf carried it. It does not any more: upstream #97186 deleted
 * /turf/var/dynamic_lumcount outright. Overlay lights now register themselves on the
 * SSspatial_grid cells covering their range, and /turf/proc/get_dynamic_lumcount() derives
 * the value on demand from the cell covering these COORDINATES
 * (code/modules/lighting/lighting_turf.dm). Coordinates survive a raw swap for free, so
 * there is no longer any dynamic-lighting state on the turf instance for a swap to drop -
 * upstream's own /turf/ChangeTurf dropped its old_dynamic_lumcount save/restore pair in the
 * same commit. The corners are still hand-carried, because those ARE per-instance refs.
 *
 * Callers gate on `SSlighting.initialized` exactly like release_light_for_raw_swap() -
 * before it comes up there are no corners to carry and the mapload fast path must stay as
 * fast as it was.
 */
/turf/proc/adopt_lighting_from_raw_swap(datum/lighting_corner/corner_ne, datum/lighting_corner/corner_se, datum/lighting_corner/corner_sw, datum/lighting_corner/corner_nw)
	lighting_corner_NE = corner_ne
	lighting_corner_SE = corner_se
	lighting_corner_SW = corner_sw
	lighting_corner_NW = corner_nw

/// Deletes any light source applied to `corner` that its own atom no longer owns - see
/// scrub_lighting_for_teardown(). Iterates a copy: qdel -> Destroy -> remove_lum() prunes
/// the very list being walked.
/turf/proc/release_orphan_corner_sources(datum/lighting_corner/corner)
	if(isnull(corner) || !LAZYLEN(corner.affecting))
		return
	for(var/datum/light_source/applied as anything in corner.affecting.Copy())
		if(QDELETED(applied))
			continue
		var/atom/owner = applied.source_atom
		if(!isnull(owner) && owner.light == applied)
			continue
		qdel(applied)

// Takes almost everything from its Tg parent, adds in lighting pass changes
/turf/ChangeTurf(path, list/new_baseturfs, flags)
	switch(path)
		if(null)
			return
		if(/turf/baseturf_bottom)
			// VOIDCREW EDIT: ask the map FOOTPRINT under this turf before the z-level.
			// ZTRAIT_BASETURF is one value per level, and a level now holds up to four
			// planets of DIFFERENT biomes; the level trait can only ever be right for one of
			// them, so on the others a dug-up patch of dirt, a blown-out ruin floor or a
			// scraped-away wall would bottom out in the neighbour's ground. The footprint is
			// per tenant and knows its own. Null (no footprint, an outpost, a flat encounter,
			// lavaland, the station) falls through to exactly the old behaviour.
			// Kept in lockstep with the dead copy in code/game/turfs/change_turf.dm and with
			// the same lookup in code/datums/elements/turf_transparency.dm.
			var/footprint_ground = footprint_baseturf_for_turf(src)
			path = footprint_ground || SSmapping.level_trait(z, ZTRAIT_BASETURF) || /turf/open/space
			if (!ispath(path))
				path = text2path(path)
				if (!ispath(path))
					warning("Z-level [z] has invalid baseturf '[footprint_ground || SSmapping.level_trait(z, ZTRAIT_BASETURF)]'")
					path = /turf/open/space
			// END VOIDCREW EDIT
		if(/turf/open/space/basic)
			// basic doesn't initialize and this will cause issues
			// no warning though because this can happen naturaly as a result of it being built on top of
			path = /turf/open/space

	if(!GLOB.use_preloader && path == type && !(flags & CHANGETURF_FORCEOP) && (baseturfs == new_baseturfs)) // Don't no-op if the map loader requires it to be reconstructed, or if this is a new set of baseturfs
		return src
	if(flags & CHANGETURF_SKIP)
		// VOIDCREW EDIT: CHANGETURF_SKIP is documented "used for uninitialized turfs NOTHING
		// ELSE", and on an uninitialized turf the call below costs two null checks. It is not
		// free to trust that, though - river.dm passes this flag over live ground - and the
		// raw swap on the next line would drop a live light source into an uncollectable
		// cycle. See /turf/proc/release_light_for_raw_swap().
		if(SSlighting.initialized)
			release_light_for_raw_swap()
		return new path(src)

	var/old_lighting_object = lighting_object
	var/old_lighting_corner_NE = lighting_corner_NE
	var/old_lighting_corner_SE = lighting_corner_SE
	var/old_lighting_corner_SW = lighting_corner_SW
	var/old_lighting_corner_NW = lighting_corner_NW
	var/old_directional_opacity = directional_opacity
	var/old_rcd_memory = rcd_memory
	var/old_explosion_throw_details = explosion_throw_details
	var/old_opacity = opacity

	// I'm so sorry brother
	// This is used for a starlight optimization
	var/old_light_range = light_range
	// We get just the bits of explosive_resistance that aren't the turf
	var/old_explosive_resistance = explosive_resistance - get_explosive_block()
	var/old_lattice_underneath = lattice_underneath

	var/old_bp = blueprint_data
	blueprint_data = null

	var/list/old_baseturfs = baseturfs
	var/old_type = type
	var/datum/weakref/old_ref = weak_reference
	weak_reference = null

	var/list/post_change_callbacks = list()
	SEND_SIGNAL(src, COMSIG_TURF_CHANGE, path, new_baseturfs, flags, post_change_callbacks)

	changing_turf = TRUE
	qdel(src) //Just get the side effects and call Destroy
	//We do this here so anything that doesn't want to persist can clear itself
	var/list/old_listen_lookup = _listen_lookup?.Copy()
	var/list/old_signal_procs = _signal_procs?.Copy()
	var/carryover_turf_flags = (RESERVATION_TURF | UNUSED_RESERVATION_TURF) & turf_flags
	var/turf/new_turf = new path(src)
	new_turf.turf_flags |= carryover_turf_flags

	// VOIDCREW EDIT ADDITION START - a turf's registrations on ITSELF must not survive a type
	// change. The carryover below exists so components watching the TILE keep working across a
	// replacement; a self-registration is a different animal, because the proc name it stored
	// belongs to the OLD type. /turf/closed/wall registers COMSIG_ATOM_REQUESTING_CONTEXT_FROM_ITEM
	// -> "add_context" on itself, and a shuttle takeoff turns that wall into
	// /turf/open/space/transit, which has no such proc.
	//
	// It gets worse than a wrong proc name, because LAZYOR (|=) only fills in MISSING keys. The
	// fresh transit turf's own Initialize() has already built _signal_procs[new_turf], so the wall's
	// whole per-target proc list is thrown away on the key collision - while _listen_lookup keeps
	// the signal NAME (a key the new turf did not have). What is left is a listener with no proc
	// name, and _SendSignal() calls it as call(turf, null): "undefined proc or verb
	// /turf/open/space/transit/east/()", once per mouse-over, for the life of the tile.
	//
	// Both types register whatever they actually want from their own Initialize(), which has
	// already run on new_turf by this point, so dropping the old self-entries loses nothing.
	if(old_signal_procs)
		old_signal_procs -= new_turf
		if(!length(old_signal_procs))
			old_signal_procs = null
	if(old_listen_lookup)
		for(var/signal_name in old_listen_lookup.Copy())
			var/list/listeners = old_listen_lookup[signal_name]
			if(!islist(listeners))
				if(listeners == new_turf)
					old_listen_lookup -= signal_name
				continue
			if(!(new_turf in listeners))
				continue
			listeners -= new_turf
			switch(length(listeners))
				if(0)
					old_listen_lookup -= signal_name
				if(1)
					// A lone listener is stored bare, never as a one-element list - UnregisterSignal()
					// stack_traces on that shape ("somehow has single length list inside _listen_lookup").
					old_listen_lookup[signal_name] = listeners[1]
		if(!length(old_listen_lookup))
			old_listen_lookup = null
	// VOIDCREW EDIT ADDITION END

	// WARNING WARNING
	// Turfs DO NOT lose their signals when they get replaced, REMEMBER THIS
	// It's possible because turfs are fucked, and if you have one in a list and it's replaced with another one, the list ref points to the new turf
	if(old_listen_lookup)
		LAZYOR(new_turf._listen_lookup, old_listen_lookup)
	if(old_signal_procs)
		LAZYOR(new_turf._signal_procs, old_signal_procs)

	for(var/datum/callback/callback as anything in post_change_callbacks)
		callback.InvokeAsync(new_turf)

	if(new_baseturfs)
		new_turf.baseturfs = baseturfs_string_list(new_baseturfs, new_turf)
	else
		new_turf.baseturfs = baseturfs_string_list(old_baseturfs, new_turf) //Just to be safe

	if(!(flags & CHANGETURF_DEFER_CHANGE))
		new_turf.AfterChange(flags, old_type)

	// RE-DERIVED FROM UPSTREAM (code/game/turfs/change_turf.dm, the shuttle-ceiling block just
	// under AfterChange()). This body is a duplicate definition that never calls ..(), so
	// anything upstream adds to ITS body is dead here until it is copied across. The flag is
	// still handed out by /area/shuttle/place_on_top_react() (code/game/area/areas/shuttles.dm),
	// so without this a hull tile built inside a shuttle area gets no ceiling above it and the
	// deck above stays open space. Kept byte-for-byte with upstream, at the same point in the
	// sequence, so the next merge diffs cleanly.
	if(flags & CHANGETURF_GENERATE_SHUTTLE_CEILING)
		var/turf/above = get_step_multiz(src, UP)
		if(above)
			if(!(istype(above, /turf/open/floor/engine/hull/ceiling) || above.depth_to_find_baseturf(/turf/open/floor/engine/hull/ceiling)))
				if(istype(above, /turf/open/openspace) || istype(above, /turf/open/space/openspace))
					above.place_on_top(/turf/open/floor/engine/hull/ceiling)
				else
					above.stack_ontop_of_baseturf(/turf/open/openspace, /turf/open/floor/engine/hull/ceiling)
					above.stack_ontop_of_baseturf(/turf/open/space/openspace, /turf/open/floor/engine/hull/ceiling)

	new_turf.blueprint_data = old_bp
	new_turf.rcd_memory = old_rcd_memory
	new_turf.explosion_throw_details = old_explosion_throw_details
	new_turf.explosive_resistance += old_explosive_resistance

	lighting_corner_NE = old_lighting_corner_NE
	lighting_corner_SE = old_lighting_corner_SE
	lighting_corner_SW = old_lighting_corner_SW
	lighting_corner_NW = old_lighting_corner_NW

	lattice_underneath = old_lattice_underneath

	new_turf.weak_reference = old_ref

	if(SSlighting.initialized)
		// Space tiles should never have lighting objects
		if(!space_lit)
			// VOIDCREW EDIT: upstream turned /datum/lighting_object into /atom/movable/lighting_object.
			// It is constructed with a null loc and the turf as the second arg (a turf loc trips a
			// stack_trace in its Initialize), it assigns turf.lighting_object itself and adds itself
			// to vis_contents - so the reuse branch has to do that part by hand.
			//
			// Two rules composed here:
			// 1. The AREA gate that SSlighting.create_all_lighting_objects() and map_template.dm
			//    both apply. Without it every mid-round ChangeTurf into a static_lighting = FALSE
			//    area (/area/overmap, /area/centcom/asteroid/voidcrew, /area/space, holodecks)
			//    accretes a lighting object that roundstart init deliberately skipped and nothing
			//    ever reclaims.
			// 2. Ambient-lit ground (a planet surface: static_lighting FALSE + ambient_lighting
			//    TRUE) is a special case of that gate with ONE exception - a turf that lights
			//    ITSELF, like the fallout zone's hazard green or a lava river, keeps an object or
			//    its own light has nothing to render on. That is what preserves the nuclear biome's
			//    telegraph. See /turf/proc/skips_lighting_object() in voidcrew/edits/lighting.dm.
			// Ordered so the ambient test costs one var read on every non-planet turf in the game
			// and the proc call only ever runs on planet ground.
			//
			// The block also has to be idempotent. AfterChange() above can run an area transfer
			// (transfer_area_lighting -> lighting_build_overlay), and a nested ChangeTurf inside
			// new path(src) - e.g. /turf/closed/mineral/random rerolling its ore type during
			// Initialize - can already have built an object for this spot. Building another one
			// blindly double-assigns and stack-traces ("a lighting object was assigned to a turf
			// that already had a lighting object!"). Reconcile instead, with force = TRUE, since a
			// plain qdel on a lighting object returns QDEL_HINT_LETMELIVE and would leave it
			// orphaned in vis_contents.
			var/area/lit_area = new_turf.loc
			var/wants_lighting_object = (!lit_area || lit_area.static_lighting)
			if(!wants_lighting_object && lit_area.ambient_lighting && !skips_lighting_object())
				wants_lighting_object = TRUE
			if(wants_lighting_object)
				if(old_lighting_object && lighting_object && lighting_object != old_lighting_object)
					qdel(lighting_object, force = TRUE) // drop the nested duplicate, keep the original
				if(old_lighting_object)
					lighting_object = old_lighting_object
					vis_contents += lighting_object
				// Should have a lighting object if we never had one
				else if(!lighting_object)
					new /atom/movable/lighting_object(null, src)
			else
				// Same outcome transfer_area_lighting() reaches via lighting_clear_overlay() when a
				// turf moves into one. Drop a nested duplicate first, since qdel'ing the old object
				// nulls the turf's pointer either way.
				if(lighting_object && lighting_object != old_lighting_object)
					qdel(lighting_object, force = TRUE)
				if(old_lighting_object)
					qdel(old_lighting_object, force = TRUE)
			// END VOIDCREW EDIT
		else if (old_lighting_object)
			qdel(old_lighting_object, force = TRUE)

		directional_opacity = old_directional_opacity
		recalculate_directional_opacity()

		if(lighting_object && !lighting_object.needs_update)
			lighting_object.update()

	// If we're space, then we're either lit, or not, and impacting our neighbors, or not
	if(isspaceturf(src))
		var/turf/open/space/lit_turf = src
		// This also counts as a removal, so we need to do a full rebuild
		if(!ispath(old_type, /turf/open/space))
			lit_turf.update_starlight()
			for(var/turf/open/space/space_tile in RANGE_TURFS(1, src) - src)
				space_tile.update_starlight()
		else if(old_light_range)
			lit_turf.enable_starlight()

	// If we're a cordon we count against a light, but also don't produce any ourselves
	else if (istype(src, /turf/cordon))
		// This counts as removing a source of starlight, so we need to update the space tile to inform it
		if(!ispath(old_type, /turf/open/space))
			for(var/turf/open/space/space_tile in RANGE_TURFS(1, src))
				space_tile.update_starlight()

	// If we're not either, but were formerly a space turf, then we want light
	else if(ispath(old_type, /turf/open/space))
		for(var/turf/open/space/space_tile in RANGE_TURFS(1, src))
			space_tile.enable_starlight()

	// VOIDCREW EDIT: ambient bleed, the same three cases the starlight branches above
	// handle, generalised from "space turf" to "turf in an area that lights it wholesale".
	// Our own capability can have flipped (we became or stopped being a cordon or a space
	// tile), and we can have started or stopped being something for the base-lit ground
	// around us to bleed onto. Kept as one call so the dead copy of this proc in
	// code/game/turfs/change_turf.dm stays in lockstep. See voidcrew/edits/lighting.dm.
	if(SSlighting.initialized)
		update_ambient_bleed_after_change(old_type, old_lighting_object)
	// END VOIDCREW EDIT

	if(old_opacity != opacity && SSticker)
		SScameras.bare_major_chunk_change(src)

	// We will only run this logic if the tile is not on the prime z layer, since we use area overlays to cover that
	if(z <= length(SSmapping.z_level_to_plane_offset) && SSmapping.z_level_to_plane_offset[z])
		var/area/our_area = new_turf.loc
		if(our_area.lighting_effects)
			var/plane_offset = SSmapping.z_level_to_plane_offset[z]
			if(plane_offset + 1 <= length(our_area.lighting_effects))
				new_turf.add_overlay(our_area.lighting_effects[plane_offset + 1])

	// only queue for smoothing if SSatom initialized us, and we'd be changing smoothing state
	if(flags_1 & INITIALIZED_1)
		QUEUE_SMOOTH_NEIGHBORS(src)
		QUEUE_SMOOTH(src)

	// RE-DERIVED FROM UPSTREAM (the tail of code/game/turfs/change_turf.dm's ChangeTurf).
	// A turf gaining or losing gravity has to tell the mobs standing on it, or a crewman keeps
	// whatever gravity state he had when the floor under him was replaced - which on this fork
	// happens constantly (hull construction, breaches, planet ground swaps, ScrapeAway on
	// undock). Same position as upstream: last thing before the return.
	for(var/mob/living/target in new_turf.contents)
		target.refresh_gravity()

	return new_turf
