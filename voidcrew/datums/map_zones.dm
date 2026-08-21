/datum/map_zone
	var/name = "Map Zone"
	var/id
	/**
	 * Whether ANY slot in this zone is claimed.
	 *
	 * Kept as a derived mirror of the slot register below rather than deleted: it used to
	 * be the whole allocator, it is the thing every "is this zone free?" reader has always
	 * looked at, and leaving it in step means a reader this pass missed still gets a safe
	 * (conservative) answer instead of handing out an occupied level. Do NOT write to it -
	 * go through claim_slot()/release_slot().
	 */
	var/taken = FALSE
	/// List of all z levels this map zone contains
	var/list/z_levels = list()
	/**
	 * Which tenant class this zone is currently dealing slots of, or null when it holds
	 * no tenants at all. A free zone has no class and can be re-dealt as any of them,
	 * which is what stops the recycled-zone pool from splintering per class.
	 */
	var/tenant_class
	/// slot_index -> /datum/map_footprint (or null). Sized to slot_capacity on first claim.
	var/list/slots = list()
	/// How many slots this zone's class deals. 0 while the zone is free.
	var/slot_capacity = 0

/datum/map_zone/New(passed_name)
	if(!isnull(passed_name))
		name = passed_name
	SSovermap.map_zones += src
	id = SSovermap.map_zones.len
	. = ..()

/datum/map_zone/Destroy()
	for(var/datum/map_footprint/footprint as anything in slots)
		if(footprint)
			qdel(footprint)
	slots = null
	SSovermap.map_zones -= src
	return ..()

// ---- Slot register ----------------------------------------------------------------
//
// A map zone used to be all-or-nothing: one `taken` boolean, one tenant, one whole
// z-level. It now deals a fixed lattice of slots (see MAP_SLOT_* in planet_defines.dm),
// each one a /datum/map_footprint rectangle. Nothing here sleeps, deliberately: the claim
// has to land before the caller's first yield or the next caller of find_free_slot() is
// handed the same slot (see the comments in spawn_dynamic_encounter()).
//
// Slots are keyed to z_levels[1]. Every voidcrew map zone is single-z by design (planets
// dropped their cave level; encounters never had one), and a multi-z zone would need the
// register moved onto /datum/space_level.

/// How many slots are currently claimed.
/datum/map_zone/proc/used_slot_count()
	. = 0
	for(var/datum/map_footprint/footprint as anything in slots)
		if(footprint)
			.++

/// Index of the lowest unclaimed slot, or 0 when the zone is full.
/datum/map_zone/proc/first_free_slot_index()
	for(var/index in 1 to slot_capacity)
		if(!slots[index])
			return index
	return 0

/**
 * TRUE when any of this zone's levels has a hole in its cordon band - a hull was standing
 * in the gutter when place_cordon() ran, so the band was skipped there rather than painted
 * over player work (see place_cordon_turf()). The band is painted once per level and never
 * repainted while a co-tenant is live, so the hole lasts until the level is torn down.
 *
 * A zone in that state keeps the tenant it already has and deals no more: a second crew put
 * on the far side of a wall that is not there gets a shared atmos graph, mutual view() and a
 * walkable path to a site they should not be able to reach.
 */
/datum/map_zone/proc/cordon_is_breached()
	for(var/datum/space_level/level as anything in z_levels)
		if(level?.cordon_breached)
			return TRUE
	return FALSE

/// Whether this zone could deal a slot of `wanted_class` right now. A zone with no tenants
/// answers TRUE for every class - it is free to take the caller's class on.
/datum/map_zone/proc/has_free_slot(wanted_class)
	if(cordon_is_breached())
		return FALSE
	if(!used_slot_count())
		return TRUE
	if(tenant_class != wanted_class)
		return FALSE
	return first_free_slot_index() != 0

/**
 * Claims one slot for `new_owner` and returns its footprint, or null if the zone cannot
 * deal one of that class.
 *
 * The footprint is attached to the zone's z-level immediately when there is one. Zones
 * whose level is minted afterwards (add_new_zlevel() sleeps) get attached by
 * add_space_level().
 */
/datum/map_zone/proc/claim_slot(new_tenant_class = MAP_TENANT_CLASS_FLAT, atom/new_owner)
	// Belt to has_free_slot()'s braces - find_free_slot() and claim_free_slot() are separate
	// calls and the band can be reported breached between them.
	if(cordon_is_breached())
		return null
	if(!used_slot_count())
		// Free zone: (re)deal it as the caller's class.
		set_tenant_class(new_tenant_class)
	else if(tenant_class != new_tenant_class)
		return null

	var/index = first_free_slot_index()
	if(!index)
		return null

	var/datum/map_footprint/footprint = new(src, tenant_class, index, new_owner)
	slots[index] = footprint
	taken = TRUE
	if(length(z_levels))
		footprint.attach_level(z_levels[1])
	return footprint

/// Resets the register to a fresh lattice of `new_tenant_class`. Only ever called on a
/// zone with no tenants - re-dealing an occupied zone would orphan its footprints.
/datum/map_zone/proc/set_tenant_class(new_tenant_class)
	tenant_class = new_tenant_class
	slot_capacity = map_slot_capacity_for_class(new_tenant_class)
	slots = new /list(slot_capacity)

/**
 * Hands one slot back. The zone stays claimed while any co-tenant remains; the last
 * tenant out drops the class so the zone can be re-dealt to anything.
 *
 * This does NOT clear the slot's turfs - call clear_reservation()/clear_to_uninitialized_space()
 * with the footprint first, while it still knows where it is.
 */
/datum/map_zone/proc/release_slot(datum/map_footprint/footprint)
	. = FALSE
	if(footprint)
		var/index = footprint.slot_index
		if(index >= 1 && index <= length(slots) && slots[index] == footprint)
			slots[index] = null
			qdel(footprint)
			. = TRUE
		// else: not ours - a double release, or a footprint from a zone already re-dealt.
		// Fall through to the empty check anyway; it is idempotent.
	// A tenant that never held a footprint at all (an allocation that predates the slot
	// register, or a build that failed before attaching) still has to be able to hand the
	// zone back, or it is pinned for the round. Safe: only ever fires when nobody is home.
	if(!used_slot_count())
		tenant_class = null
		slot_capacity = 0
		slots = list()
		taken = FALSE

/// Whether `footprint` is the only tenant left in this zone - i.e. releasing it hands the
/// whole level back, so teardown may sweep the cordon too.
/datum/map_zone/proc/is_last_occupant(datum/map_footprint/footprint)
	if(!footprint)
		return TRUE
	if(used_slot_count() > 1)
		return FALSE
	var/index = footprint.slot_index
	return index >= 1 && index <= length(slots) && slots[index] == footprint

/**
 * Every slot rectangle on this zone's lattice, occupied or not, as list(lx, ly, hx, hy).
 *
 * Occupied slots report their footprint's CURRENT rect (a planet narrows its own with
 * set_bounds()); free slots report the static lattice cell they will be dealt as. Both
 * matter: place_cordon() has to leave a free slot's ground alone, or the tenant that
 * arrives later finds its whole footprint painted indestructible.
 */
/datum/map_zone/proc/get_slot_rects()
	. = list()
	for(var/index in 1 to slot_capacity)
		var/datum/map_footprint/footprint = slots[index]
		if(footprint && !isnull(footprint.low_x))
			. += list(list(footprint.low_x, footprint.low_y, footprint.high_x, footprint.high_y))
		else
			. += list(map_slot_rect(tenant_class, index))

/**
 * Clears all of what's inside the z levels managed by the mapzone.
 *
 * * throttled - whether the sweep shares the queued worldgen job's tick budget;
 *   pass FALSE from unqueued (flat-encounter) teardowns - see worldgen_yield().
 * * footprint - the departing tenant's slot. Only that rectangle is reset, UNLESS it is
 *   the last tenant on the zone, in which case the whole level (cordon included) is reset
 *   and the zone goes back in the pool clean. Null means "no slots, reset everything",
 *   which is what a zone that predates the slot register wants.
 */
/datum/map_zone/proc/clear_reservation(throttled = TRUE, datum/map_footprint/footprint = null)
	var/whole_level = is_last_occupant(footprint)
	// Teardowns hold the worldgen queue for as long as they run and had no probe of their
	// own, so the only trace they left was other jobs' queue waits - which is a poor way to
	// find out that the biggest job in the system is a teardown.
	var/datum/worldgen_probe/probe = worldgen_begin("teardown", "[name] ([whole_level ? "whole level" : "slot"])")
	for(var/datum/space_level/zlevel as anything in z_levels)
		// Weather is one climate per z. Only the last tenant out may tear it down.
		if(whole_level)
			SSweather.set_z_level_weather_trait(zlevel, null)
		zlevel.clear_reservation(throttled, footprint, whole_level)
		// The wipe above ends every turf as an INITIALIZED /turf/open/space:
		// empty(RESERVED_TURF_TYPE) is a full ChangeTurf, and on a live encounter level
		// each replacement comes back STARLIT - one /datum/light_source and four corners
		// apiece, ~15k of them for a freed ruin or planet slot, standing until the slot's
		// next claim. (The "we don't need to check its starlight" note down in the sweep
		// is inherited from the reserved-z world, where it was true.) Chase the wipe with
		// the flat-encounter sweep so the ground is handed back UNINITIALIZED like every
		// other freed slot: it scrubs the fresh lighting, leaves GLOB.starlight, raw-swaps
		// to space/basic, and repairs the co-tenant atmos ring the IGNORE_AIR wipe never
		// touched. Measured: the churn soak's post-teardown light_sources sat at ~14k per
		// recycled level without this, and ghost run 8 accumulated +330k lighting datums
		// (+130 MB/h) from exactly this state across its pinned sites.
		zlevel.clear_to_uninitialized_space(footprint, whole_level)
	worldgen_end(probe)

/// Clears contents and resets turfs to uninitialized space (for empty space cleanup).
/// Same per-slot contract as clear_reservation() above.
/datum/map_zone/proc/clear_to_uninitialized_space(datum/map_footprint/footprint = null)
	var/whole_level = is_last_occupant(footprint)
	var/datum/worldgen_probe/probe = worldgen_begin("teardown-uninit", "[name] ([whole_level ? "whole level" : "slot"])")
	for(var/datum/space_level/zlevel as anything in z_levels)
		if(whole_level)
			SSweather.set_z_level_weather_trait(zlevel, null)
		zlevel.clear_to_uninitialized_space(footprint, whole_level)
	worldgen_end(probe)

/datum/map_zone/proc/add_space_level(datum/space_level/level)
	z_levels += level
	level.map_zone = src
	// Otherwise only set as a side effect of get_block() (via fill_in()), which
	// skips its loops - and this assignment - when called with no area/turf
	// type to paint. Set eagerly so bounds are never null for callers that
	// read them before (or without) a fill_in() call, e.g. player outposts.
	level.low_x = 1
	level.low_y = 1
	level.high_x = world.maxx
	level.high_y = world.maxy
	// Slots claimed before the level existed (add_new_zlevel() sleeps, so the claim
	// deliberately lands first) only learn where they are here.
	for(var/index in 1 to slot_capacity)
		var/datum/map_footprint/footprint = slots[index]
		if(footprint && !footprint.level)
			footprint.attach_level(level)

/datum/map_zone/proc/get_mind_mobs()
	. = list()
	for(var/datum/space_level/zlevel as anything in z_levels)
		. += zlevel.get_mind_mobs()

/**
 * Living, minded mobs standing inside ONE tenant's footprint.
 *
 * get_mind_mobs() above matches by z, which on a packed level counts the neighbour's crew
 * and fuses the two tenants' lifecycles - neither recycles until both are empty. Every
 * lifecycle guard (can_release_interior() and friends) wants this one instead.
 * A null footprint falls back to the z-wide answer, so a whole-level tenant is unchanged.
 */
/datum/map_zone/proc/get_mind_mobs_in(datum/map_footprint/footprint)
	if(!footprint)
		return get_mind_mobs()
	return footprint.get_mind_mobs()

/datum/space_level
	/**
	 * The level's "primary" rectangle, kept in step with `footprints` by
	 * sync_level_bounds(): the sole tenant's rect when there is exactly one, the whole
	 * level when there are none or several.
	 *
	 * Historically this WAS the tenant, and ~20 call sites are correct only because of
	 * that. Keeping the single-tenant case exact means every one of them behaves as it
	 * always has for planets and outposts, while a packed level answers "the whole z"
	 * (conservative) instead of "whichever tenant claimed it first" (wrong). New code
	 * should read a /datum/map_footprint, not these.
	 */
	var/low_x
	var/low_y
	var/high_x
	var/high_y
	/// Every tenant rectangle currently registered on this level.
	var/list/footprints = list()
	/// The map zone that owns this level, if any. Set by add_space_level().
	var/datum/map_zone/map_zone
	/// Whether the inter-slot cordon band has been painted. Painted ONCE per level, from
	/// the complement of the whole lattice, so a second tenant arriving never repaints
	/// over a live neighbour - see place_cordon().
	var/cordon_placed = FALSE
	/// TRUE when place_cordon() had to skip band turfs because a hull was standing in them,
	/// i.e. the cordon on this level is NOT contiguous. Open shuttle-area turfs bridging the
	/// gutter give two tenants a shared atmos graph, mutual view(), mutual movement and a
	/// walkable path - every containment guard in the design assumes that cannot happen.
	/// place_cordon() is once per level and is never repainted while a co-tenant is live, so
	/// the hole stays until the whole level is torn down. Until then the zone deals no
	/// further slots; see /datum/map_zone/proc/cordon_is_breached().
	var/cordon_breached = FALSE
	/// The exact strips place_cordon() painted, as list(lx, ly, hx, hy), or null if the
	/// band was never painted. Recorded rather than recomputed because the band is NOT a
	/// function of the lattice alone: get_slot_rects() reports an OCCUPIED slot's narrowed
	/// rect and a free slot's full lattice cell, so the complement depends on who was home
	/// at the moment of painting. Recomputing it at teardown, when the occupancy has
	/// changed, would silently miss the turfs a since-departed tenant's narrowing margin
	/// contributed - leaving live cordon inside a slot the zone later deals to somebody.
	var/list/cordon_strips

/datum/space_level/proc/add_footprint(datum/map_footprint/footprint)
	if(footprint in footprints)
		return
	footprints += footprint
	sync_level_bounds()

/datum/space_level/proc/remove_footprint(datum/map_footprint/footprint)
	footprints -= footprint
	sync_level_bounds()

/// Recomputes the legacy low_*/high_* rect from the registered footprints - see the var
/// doc above for why the multi-tenant case widens to the whole level rather than picking.
/datum/space_level/proc/sync_level_bounds()
	if(length(footprints) == 1)
		var/datum/map_footprint/only_tenant = footprints[1]
		if(!isnull(only_tenant.low_x))
			low_x = only_tenant.low_x
			low_y = only_tenant.low_y
			high_x = only_tenant.high_x
			high_y = only_tenant.high_y
			return
	low_x = 1
	low_y = 1
	high_x = world.maxx
	high_y = world.maxy

/datum/space_level/proc/get_mind_mobs()
	. = list()
	for(var/mob/living/living_mob as anything in GLOB.mob_living_list)
		if(!living_mob.mind || living_mob.stat == DEAD)
			continue
		if(living_mob.z == z_value)
			. += living_mob

/**
 * Confines this z-level to a centred region of the given size. Everything that walks
 * the level - terrain generation, population, ruin seeding, rivers, cleanup - goes
 * through get_block(), so setting bounds is all it takes to make a small planet on a
 * full-size z-level. Call place_cordon() afterwards to wall off the remainder.
 *
 * Single-tenant only, by construction: it centres, and there is exactly one centre. Its
 * one caller is build_planet(), whose planets still own a whole level each. Packed tenants
 * use set_bounds_at() with their slot's origin.
 */
/datum/space_level/proc/set_bounds(width, height)
	width = clamp(width, PLANET_MIN_SIZE, world.maxx)
	height = clamp(height, PLANET_MIN_SIZE, world.maxy)
	return set_bounds_at(round((world.maxx - width) / 2) + 1, round((world.maxy - height) / 2) + 1, width, height)

/**
 * Confines a region of this z-level to an EXPLICIT origin, rather than centring it.
 *
 * This is what makes more than one tenant per level expressible: "tenant 3 of 4 at
 * (3,131), 123x123" has no centred form. `footprint` names whose rectangle is being set;
 * omitted, it means the level's sole tenant (and, failing that, just the legacy rect,
 * which is what a level with no slot register at all wants).
 *
 * Does NOT clamp to PLANET_MIN_SIZE - the caller has already been dealt a slot of a legal
 * size, and clamping a slot back up would grow it into its neighbour.
 */
/datum/space_level/proc/set_bounds_at(origin_x, origin_y, width, height, datum/map_footprint/footprint = null)
	if(isnull(footprint) && length(footprints) == 1)
		footprint = footprints[1]
	if(footprint)
		footprint.set_rect(origin_x, origin_y, width, height)
		// set_rect() calls back into sync_level_bounds() for us
		return
	low_x = clamp(origin_x, 1, world.maxx)
	low_y = clamp(origin_y, 1, world.maxy)
	high_x = clamp(low_x + width - 1, low_x, world.maxx)
	high_y = clamp(low_y + height - 1, low_y, world.maxy)

/**
 * Sets or clears a single z-level trait, keeping SSmapping's reverse index in step.
 *
 * Map zones are recycled, and the levels in them are NOT re-minted between occupants -
 * a reused level still carries whatever the last one registered. That is harmless for
 * flag traits nothing reads twice, but not for value traits like ZTRAIT_BASETURF, where
 * a leftover would leave a space encounter bottoming out in a previous planet's ground.
 * Pass a null value to remove the trait outright.
 */
/datum/space_level/proc/set_trait(trait, value)
	if(isnull(value))
		traits -= trait
		var/list/old_levels = SSmapping.z_trait_levels[trait]
		if(old_levels)
			old_levels -= z_value
		return
	traits[trait] = value
	var/list/trait_levels = SSmapping.z_trait_levels[trait]
	if(!trait_levels)
		trait_levels = list()
		SSmapping.z_trait_levels[trait] = trait_levels
	trait_levels |= list(z_value)

/// Drops the legacy bounds back to the whole z-level.
///
/// DEPRECATED and no longer called. It used to be how clear_reservation() widened itself
/// to cover the cordon; on a packed level that widening is exactly the bug (one tenant
/// unloading wipes every co-tenant), so teardown now names the block it wants explicitly.
/// Left in place because null bounds are a state get_block() still has to survive.
/datum/space_level/proc/reset_bounds()
	low_x = null
	low_y = null
	high_x = null
	high_y = null

/// The whole z-level, ignoring bounds and footprints entirely. What the last tenant out
/// resets, and what the cordon band is carved from.
/datum/space_level/proc/get_full_block()
	return block(locate(1, 1, z_value), locate(world.maxx, world.maxy, z_value))

/**
 * Every tenant rectangle this level's lattice can ever hand out, as list(lx, ly, hx, hy).
 *
 * Delegates to the owning map zone, which knows the class and therefore the capacity.
 * A level with no zone (nothing in voidcrew builds one, but the loader and admin verbs
 * can) falls back to its legacy rect, so place_cordon() keeps its old single-rect
 * behaviour there.
 */
/datum/space_level/proc/get_slot_rects()
	if(map_zone && map_zone.slot_capacity)
		return map_zone.get_slot_rects()
	if(isnull(low_x))
		return list()
	return list(list(low_x, low_y, high_x, high_y))

/**
 * The one-tile border of turfs immediately OUTSIDE the given rectangle, clamped to the level.
 *
 * Every teardown and the cordon paint replace turfs with a raw `new` rather than ChangeTurf, and
 * a raw swap recalculates nobody's atmos adjacency while BYOND silently retargets every existing
 * reference onto the replacement. The turfs INSIDE the rectangle were all replaced, and a fresh
 * turf datum starts with a null atmos_adjacent_turfs, so the interior heals itself - the stale
 * entries only ever survive on this ring, which is why the repair walks a few hundred turfs
 * instead of the ~65k in the block. Corners come along; a diagonal is not an atmos neighbour, but
 * four extra turfs is cheaper than a special case.
 */
/proc/map_boundary_ring(low_x, low_y, high_x, high_y, z_value)
	. = list()
	// A footprint that never got bounds attached has null coordinates, and nothing was replaced
	// inside it either - see /datum/map_footprint/get_block().
	if(isnull(low_x) || isnull(low_y) || !z_value)
		return
	var/ring_low_x = max(low_x - 1, 1)
	var/ring_high_x = min(high_x + 1, world.maxx)
	for(var/scan_x in ring_low_x to ring_high_x)
		if(low_y > 1)
			. += locate(scan_x, low_y - 1, z_value)
		if(high_y < world.maxy)
			. += locate(scan_x, high_y + 1, z_value)
	for(var/scan_y in low_y to high_y)
		if(low_x > 1)
			. += locate(low_x - 1, scan_y, z_value)
		if(high_x < world.maxx)
			. += locate(high_x + 1, scan_y, z_value)

/**
 * Fills the band between the slots of this level's lattice with cordon turfs.
 *
 * Computed ONCE per z-level from the complement of EVERY slot rectangle - occupied or
 * not - rather than per tenant from one rectangle. Two properties follow, and packing
 * needs both:
 *
 * - A second tenant arriving cannot cordon over the first one's live surface. The band is
 *   the same set of turfs no matter who is home, so the call is idempotent and `cordon_placed`
 *   makes the repeat free.
 * - A slot nobody has claimed yet is NOT painted. Painting it would hand the next tenant a
 *   footprint made of indestructible turf.
 *
 * The complement is emitted as solid strips rather than a 65,025-turf membership scan: the
 * lattice is a grid, so the column and row gaps give it directly. A single whole-level
 * tenant (an outpost) produces no strips at all; a single centred tenant (a planet)
 * produces the same four strips this proc has always painted.
 *
 * The cordon is flagged NO_RUINS: try_to_place() samples ruin spots across the whole
 * 255x255 level, so on a 123x123 planet ~3/4 of candidates are centered off the
 * footprint. The flag check breaks out on the first flagged turf it scans, where the
 * area-whitelist rejection only fires after walking the full footprint - this turns
 * most wasted samples from a ~thousand-turf scan into a nearly free one. Set here
 * rather than on /turf/cordon itself to keep the upstream type untouched; no staleness
 * risk on recycled zones, since the last-tenant-out teardown resets the whole level
 * through ChangeTurf, which drops the flag with the turf.
 *
 * `throttled` = whether the paint shares the queued worldgen job's tick budget. The
 * planet build leaves it TRUE; unqueued flat-encounter builds pass FALSE, which is the
 * design rule in worldgen_queue.dm - a routine empty-space dock may never crawl behind
 * somebody else's minute-long survey.
 */
/datum/space_level/proc/place_cordon(throttled = TRUE)
	if(cordon_placed)
		return

	var/list/rects = get_slot_rects()
	if(!length(rects))
		return

	// Distinct column and row intervals of the lattice. For the 2x2 lattice that is two
	// of each; for a lone centred tenant, one of each. The assoc lists are dedupe keys
	// only - the interval lists themselves stay flat, since map_interval_complement()
	// iterates values, and iterating an assoc list yields its keys.
	var/list/column_keys = list()
	var/list/row_keys = list()
	var/list/columns = list()
	var/list/rows = list()
	for(var/list/rect as anything in rects)
		var/column_key = "[rect[1]]-[rect[3]]"
		if(!column_keys[column_key])
			column_keys[column_key] = TRUE
			columns += list(list(rect[1], rect[3]))
		var/row_key = "[rect[2]]-[rect[4]]"
		if(!row_keys[row_key])
			row_keys[row_key] = TRUE
			rows += list(list(rect[2], rect[4]))

	var/list/column_gaps = map_interval_complement(columns, 1, world.maxx)
	var/list/row_gaps = map_interval_complement(rows, 1, world.maxy)
	if(!length(column_gaps) && !length(row_gaps))
		// The lattice covers the level - a whole-level tenant. Nothing to wall off.
		return

	cordon_placed = TRUE

	var/list/strips = list()
	// Full-width bands above, below and between the slot rows
	for(var/list/gap as anything in row_gaps)
		strips += list(list(1, gap[1], world.maxx, gap[2]))
	// Within each slot row, the columns nobody occupies
	for(var/list/row as anything in rows)
		for(var/list/gap as anything in column_gaps)
			strips += list(list(gap[1], row[1], gap[2], row[2]))

	// Kept so the last-tenant-out teardown can sweep exactly what we painted instead of
	// falling back to the whole z-level - see cordon_strips and get_cordon_band_block().
	cordon_strips = strips

	var/skipped_ship_turfs = 0
	for(var/list/strip as anything in strips)
		for(var/turf/cordon_turf as anything in block(locate(strip[1], strip[2], z_value), locate(strip[3], strip[4], z_value)))
			skipped_ship_turfs += place_cordon_turf(cordon_turf)
			// Throttled yield, not CHECK_TICK - see worldgen_yield() in worldgen_queue.dm
			SSovermap.worldgen_yield(throttled)

	// The strips went down as raw turf swaps (see place_cordon_turf), so nothing recalculated
	// atmos adjacency and a live tenant's atmos_adjacent_turfs entries were retargeted onto turfs
	// that are not even /turf/open. process_cell() walks that list `as anything`, so the missing
	// air var reads as null and it archives null every tick for the rest of the round.
	//
	// This has to run from the CORDON side. immediate_calculate_adjacent_turfs() skips a non-open
	// neighbour outright, so asking the live ground to recalculate would never reach the entry -
	// it is the closed turf's own recalc that strips itself out of everyone's list (canpass is
	// FALSE for /turf/cordon, so every direction takes the removal branch). Only band tiles
	// hugging a slot border can have a live neighbour; the rest of the band is fresh cordon
	// against fresh cordon, whose lists are null already. A couple of thousand recalcs, not 48k.
	for(var/list/rect as anything in rects)
		for(var/turf/edge_turf as anything in map_boundary_ring(rect[1], rect[2], rect[3], rect[4], z_value))
			if(!istype(edge_turf, /turf/cordon))
				continue
			// remove = TRUE as well: the swap can have retargeted an ACTIVE turf's slot in
			// SSair.active_turfs onto this cordon, and a cordon has no air to process.
			edge_turf.air_update_turf(TRUE, TRUE)
			// Throttled yield, not CHECK_TICK - see worldgen_yield() in worldgen_queue.dm
			SSovermap.worldgen_yield(throttled)

	if(skipped_ship_turfs)
		// The band has a hole in it. Give the alarm teeth: the zone stops dealing slots on
		// this level, so whatever tenant is already here keeps its ground but no second crew
		// is put on the other side of a wall that is not there. Cleared with cordon_placed
		// by the last-tenant-out teardown.
		cordon_breached = TRUE
		var/seal_warning = "place_cordon: a shuttle occupies [skipped_ship_turfs] turf(s) inside the cordon band on z[z_value]. Its turfs were left alone, but a hull should never be out here - planet lifecycle bug likely, and the ship is probably sealed in. Admin recovery needed. No further slots will be dealt on this level until it is fully torn down."
		log_mapping(seal_warning)
		message_admins(seal_warning)

/**
 * Replaces a single out-of-bounds turf with cordon, unless a landed shuttle owns it.
 *
 * Ship turfs are never overwritten: a hull that has ended up in the cordon band got
 * there through a lifecycle bug (round 4: the derelict auto-crash placed a 10-hour
 * player hull in the band and the cordon sealed it in), and painting cordon over it
 * turns that bug into deleted player work. place_cordon() counts the skips and
 * raises the alarm once, after the sweep.
 *
 * Returns 1 when the turf was skipped for that reason, else 0.
 */
/datum/space_level/proc/place_cordon_turf(turf/cordon_turf)
	if(istype(cordon_turf.loc, /area/shuttle))
		return 1
	// The `new` below is a raw turf swap that never runs the old turf's Destroy(), so its
	// lighting datums would be dropped rather than freed - see scrub_lighting_for_teardown().
	// The band is normally painted over bare space, but a recycled level's is painted over
	// whatever the previous occupant left, so do not assume it is dark.
	cordon_turf.scrub_lighting_for_teardown()
	// Same raw-swap reason, second casualty: /turf/open/space/Destroy() is what takes a lit space
	// turf back out of GLOB.starlight, and that never runs here either. The list entry is not
	// merely stale - BYOND retargets it onto the cordon, set_starlight() then walks it
	// `as anything` and relights a cordon tile, and if that spot ever becomes lit space again
	// enable_starlight() does `GLOB.starlight += src` on a turf already in the list, so a churning
	// zone grows a duplicate per cycle. `light_on` is exactly the membership test the space turf
	// keeps in step, so this costs one var read on everything else in the band.
	if(isspaceturf(cordon_turf) && cordon_turf.light_on)
		GLOB.starlight -= cordon_turf
	// NO_RUINS: see the doc comment on place_cordon() above
	var/turf/placed = new /turf/cordon(cordon_turf)
	placed.turf_flags |= NO_RUINS
	return 0

/datum/space_level/proc/get_block()
	if(isnull(low_x))
		low_x = 1
		low_y = 1
		high_x = world.maxx
		high_y = world.maxy
	return block(locate(low_x,low_y,z_value), locate(high_x,high_y,z_value))

/**
 * The turfs of the cordon band this level actually painted, or an empty list if it
 * never painted one. See cordon_strips for why this is replayed rather than recomputed.
 */
/datum/space_level/proc/get_cordon_band_block()
	var/list/turf/band = list()
	for(var/list/strip as anything in cordon_strips)
		band += block(locate(strip[1], strip[2], z_value), locate(strip[3], strip[4], z_value))
	return band

/**
 * Which turfs a teardown sweeps for CONTENTS (the pass that cannot yield, so it has to be
 * as small as it can safely be).
 *
 * * A departing co-tenant sweeps its own rectangle - the neighbours' contents are theirs.
 * * The last tenant out of a PACKED level sweeps its own rectangle PLUS the cordon band.
 *   It used to sweep the whole z, on the grounds that the gutter and any never-claimed
 *   slot had never been swept by anybody. The gutter is right and is why the band is
 *   included; the never-claimed slots are not. A slot is only ever dirtied by a tenant,
 *   and a tenant sweeps its own rectangle on the way out, so every slot that is not ours
 *   is either pristine since the level was minted or was cleaned when its own occupant
 *   left. Sweeping them again is 45,000 turfs of re-proving that - in a pass that
 *   deliberately CANNOT yield, so it lands as one uninterrupted stall, and again in the
 *   turf pass that follows.
 *
 *   The assumption that buys that back is written down here on purpose: nothing may come
 *   to rest on this level outside a slot or the band. The band being impassable is what
 *   enforces it, which is also why a BREACHED cordon (a hull parked in the gutter, see
 *   cordon_breached) falls back to the old whole-level sweep below.
 * * Everything else sweeps the legacy bounds, which for a single whole-level tenant (a
 *   planet, an outpost) is the tenant - unchanged, and 15k turfs rather than 65k.
 */
/datum/space_level/proc/get_teardown_contents_block(datum/map_footprint/footprint, whole_level = FALSE)
	if(!whole_level)
		if(footprint)
			return footprint.get_block() || list()
		return get_block()
	if(can_sweep_by_slot(footprint))
		var/list/turf/turfs = footprint.get_block() || list()
		turfs += get_cordon_band_block()
		return turfs
	if(map_zone && map_zone.slot_capacity > 1)
		return get_full_block()
	return get_block()

/**
 * Whether a last-tenant-out teardown may sweep `footprint` plus the band instead of the
 * whole z-level. Everything here is a reason the narrow sweep would not be equivalent:
 * no slot register to reason about, a footprint that never got a rectangle, a band we
 * did not paint and therefore cannot bound, or a band with a hole in it that something
 * could have walked through.
 */
/datum/space_level/proc/can_sweep_by_slot(datum/map_footprint/footprint)
	if(isnull(footprint) || isnull(footprint.low_x))
		return FALSE
	if(isnull(cordon_strips) || !cordon_placed)
		return FALSE
	if(cordon_breached)
		return FALSE
	return TRUE

/**
 * Wipes a tenant's ground back to bare reserved turf in the level's own space area.
 *
 * * footprint - the departing tenant's slot, when co-tenants remain. Only that rectangle
 *   is touched, and in particular the cordon band is left standing: it is what is holding
 *   the neighbours apart, and repainting it later would have to run over live ground.
 * * whole_level - TRUE when this is the last tenant out, so the cordon band comes down
 *   with the tenant's own rectangle and the level goes back in the pool clean. The
 *   footprint is still passed in that case (it says which rectangle is ours); only a
 *   level with no slot register at all arrives here with a null one.
 */
/datum/space_level/proc/clear_reservation(throttled = TRUE, datum/map_footprint/footprint = null, whole_level = FALSE)
	var/area/space_area = GLOB.areas_by_type[world.area]

	// Contents only ever exist inside the bounded region - the cordon around a small
	// planet is bare turf with nothing on it. The sweep below deliberately never yields,
	// so it stays scoped to the bounds instead of grinding through ~48k empty cordon
	// tiles that cannot possibly hold anything.
	var/list/turf/contents_turfs = get_teardown_contents_block(footprint, whole_level)
	for(var/turf/turf as anything in contents_turfs)
		// don't waste time trying to qdelete the lighting object
		for(var/datum/thing in (turf.contents - turf.lighting_object))
			qdel(thing)
			// DO NOT CHECK_TICK HERE. IT CAN CAUSE ITEMS TO GET LEFT BEHIND
			// THIS IS REALLY IMPORTANT FOR CONSISTENCY. SORRY ABOUT THE LAG SPIKE

	// Turfs and areas: the whole level for the last tenant out (the cordon has to go back
	// to space or the recycled zone hands its next occupant a level walled in half), the
	// tenant's own rectangle when anyone else is still home.
	var/list/turf/block_turfs
	var/edge_low_x
	var/edge_low_y
	var/edge_high_x
	var/edge_high_y
	if(!whole_level && footprint)
		block_turfs = footprint.get_block()
		edge_low_x = footprint.low_x
		edge_low_y = footprint.low_y
		edge_high_x = footprint.high_x
		edge_high_y = footprint.high_y
	else
		// Last tenant out: our rectangle plus the band we painted, or the whole level when
		// the band cannot be bounded - see get_teardown_contents_block().
		if(can_sweep_by_slot(footprint))
			block_turfs = footprint.get_block()
			block_turfs += get_cordon_band_block()
		else
			block_turfs = get_full_block()
		// The level border either way: the band reaches it, and these bounds only decide
		// which turfs are worth re-smoothing afterwards.
		edge_low_x = 1
		edge_low_y = 1
		edge_high_x = world.maxx
		edge_high_y = world.maxy
		cordon_placed = FALSE
		cordon_breached = FALSE
		cordon_strips = null

	// Every area instance we take turfs away from, so the emptied ones can be reaped after
	// the sweep - see reap_emptied_areas().
	var/list/area/vacated_areas = list()

	for(var/turf/turf as anything in block_turfs)
		// VOIDCREW EDIT: free the lighting datums before the turf goes. ChangeTurf inside
		// empty() handles this turf's OWN light, but not a source orphaned onto it by an
		// earlier raw turf swap (river carving, a ruin's map load) - that one is reachable
		// only through the corners, and only from here. See scrub_lighting_for_teardown().
		turf.scrub_lighting_for_teardown()
		// Reset turf
		turf.empty(RESERVED_TURF_TYPE, RESERVED_TURF_TYPE, null, CHANGETURF_IGNORE_AIR|CHANGETURF_DEFER_CHANGE)
		// Reset area
		var/area/old_area = get_area(turf)
		if(old_area && old_area != space_area)
			vacated_areas[old_area] = TRUE
		turf.change_area(old_area, space_area)
		// Throttled yield, not CHECK_TICK - see worldgen_yield() in worldgen_queue.dm
		SSovermap.worldgen_yield(throttled)

	reap_emptied_areas(vacated_areas)

	for(var/turf/turf as anything in block_turfs)
		turf.AfterChange(CHANGETURF_IGNORE_AIR)

		// we don't need to smooth anything in the reserve, because it's empty, nor do we need to check its starlight.
		// only the sides need to do that. this saved ~4-5% of reservation clear times in testing
		if(turf.x != edge_low_x && turf.x != edge_high_x && turf.y != edge_low_y && turf.y != edge_high_y)
			continue

		QUEUE_SMOOTH(turf)
		QUEUE_SMOOTH_NEIGHBORS(turf)
		// Throttled yield, not CHECK_TICK - see worldgen_yield() in worldgen_queue.dm
		SSovermap.worldgen_yield(throttled)

/// Clears contents and resets turfs to uninitialized /turf/open/space/basic
/// This bypasses ChangeTurf so turfs remain uninitialized and unbuildable
///
/// * footprint - as clear_reservation(): the departing tenant's slot when co-tenants
///   remain, null for the last tenant out (which is what may sweep the cordon).
/datum/space_level/proc/clear_to_uninitialized_space(datum/map_footprint/footprint = null, whole_level = FALSE)
	var/area/space_area = GLOB.areas_by_type[world.area]

	// Contents live inside the bounds; the cordon outside them is bare turf. Same reason
	// as clear_reservation() - this sweep doesn't yield, so don't widen it.
	var/static/list/ignored_atoms = typecacheof(list(/mob/dead, /obj/effect/landmark, /obj/docking_port))
	var/list/turf/contents_turfs = get_teardown_contents_block(footprint, whole_level)
	for(var/turf/T as anything in contents_turfs)
		// Iterate a COPY. /atom/movable/Destroy() nullspaces the atom, which removes it from
		// the turf's contents mid-iteration, and BYOND's `for(x in list)` walks by index -
		// every removal skips the following entry. Half of a ruin's floor decals, cult turfs
		// and effects were surviving this sweep and riding the recycled z-level onwards.
		// clear_reservation()'s own sweep is safe by accident: `contents - lighting_object`
		// already builds a new list.
		for(var/atom/movable/AM as anything in T.contents.Copy())
			if(QDELETED(AM))
				continue
			if(AM == T.lighting_object)
				continue
			if(ignored_atoms[AM.type])
				continue
			qdel(AM)

	// Whole level (cordon included) only for the last tenant out - see clear_reservation()
	var/list/turf/block_turfs
	if(!whole_level && footprint)
		block_turfs = footprint.get_block()
	else
		// Last tenant out - see clear_reservation() for why this is our rectangle plus the
		// band rather than the whole z.
		if(can_sweep_by_slot(footprint))
			block_turfs = footprint.get_block()
			block_turfs += get_cordon_band_block()
		else
			block_turfs = get_full_block()
		cordon_placed = FALSE
		cordon_breached = FALSE
		cordon_strips = null

	// Every area instance we take turfs away from - see reap_emptied_areas() below.
	var/list/area/vacated_areas = list()

	// Replace turfs with uninitialized space - bypass ChangeTurf entirely
	for(var/turf/T as anything in block_turfs)
		// Reset area first
		var/area/old_area = get_area(T)
		if(old_area != space_area)
			if(old_area)
				vacated_areas[old_area] = TRUE
			T.change_area(old_area, space_area)
		// VOIDCREW EDIT: hand-run the lighting teardown ChangeTurf would have done.
		// Replacing the turf in place is a raw BYOND turf swap: the replacement starts with
		// null lighting vars and every ref to the old turf silently retargets to it, so the
		// old turf's lighting datums are simply dropped instead of freed - and a dropped
		// /datum/light_source is uncollectable, because it and its lighting corners hold
		// each other. scrub_lighting_for_teardown() frees this turf's own lighting object
		// and source, and sweeps its corners for sources orphaned the same way earlier in
		// the site's life. See its doc comment in voidcrew/edits/turf.dm.
		// On a planet, T.light has three possible owners and this frees all of them: a
		// self-lit ground turf (the fallout zone's hazard green, a lava river), a /lit tile a
		// ruin .dmm placed directly, and - since planet surfaces went ambient-lit - an AMBIENT
		// BLEED edge light (voidcrew/edits/lighting.dm), which is a real /datum/light_source
		// cross-linked with the static side's corners in exactly the cycle described above.
		// Ordinary surface ground carries none of the three and costs a few null checks here.
		// The change_area() above has usually already switched a bleed light off through
		// transfer_area_lighting() -> update_ambient_bleed() -> disable_ambient_bleed(); this
		// is belt to that braces, and the only cover on the corner-orphan path.
		T.scrub_lighting_for_teardown()
		// END VOIDCREW EDIT
		// The same raw swap orphans two more registrations that Destroy() would have cleared.
		//
		// SSair.active_turfs: the entry retargets onto the replacement, which is an
		// UNINITIALIZED /turf/open/space/basic with a null `air` - process_cell() would archive
		// null on it every tick. `excited` is exactly active_turfs membership (add_to_active and
		// remove_from_active keep the two in step), so the O(n) list removal only ever runs for
		// the handful of turfs that were genuinely processing.
		//
		// GLOB.starlight: /turf/open/space/Destroy() is what takes a lit space turf out, and the
		// retargeted entry is worse than stale - if this spot lights up again later,
		// enable_starlight() does `GLOB.starlight += src` on a turf already in the list, so a
		// churning zone accretes a duplicate per cycle. `light_on` is the membership test the
		// space turf itself keeps in step.
		var/turf/open/open_turf = T
		if(isopenturf(T) && open_turf.excited)
			SSair.remove_from_active(T)
		if(isspaceturf(T) && T.light_on)
			GLOB.starlight -= T
		// Create uninitialized space turf directly (bypasses ChangeTurf which would init it)
		new /turf/open/space/basic(T)
		// Every caller is an unqueued flat-encounter/outpost teardown: never wait
		// behind a queued planet job - see worldgen_yield() in worldgen_queue.dm
		SSovermap.worldgen_yield(throttled = FALSE)

	// Nothing above recalculated atmos adjacency, so a co-tenant that is still LIVE next door is
	// holding blanked turfs in its atmos_adjacent_turfs - and process_cell() archives every entry
	// it finds there, which is "Cannot execute null.archive()" every tick for the rest of the
	// round. This is packing-specific: before slots, a teardown took the whole z-level at once and
	// there was never a live neighbour to hold the reference.
	//
	// Only the RING outside the rectangle needs repairing - see map_boundary_ring() for why the
	// interior heals itself. The whole-level case (no footprint) has no ring at all: everything on
	// the z went, so there is nobody left holding anything.
	if(footprint && !isnull(footprint.low_x))
		for(var/turf/edge_turf as anything in map_boundary_ring(footprint.low_x, footprint.low_y, footprint.high_x, footprint.high_y, z_value))
			// update = rebuild adjacency, which now strips the null-air pairing from BOTH sides
			// (see immediate_calculate_adjacent_turfs); remove = drop the edge out of SSair,
			// because its neighbour set just changed under it and its excited group is a lie.
			edge_turf.air_update_turf(TRUE, TRUE)
			// Unqueued teardown, same as the sweep above - never wait behind a planet job.
			SSovermap.worldgen_yield(throttled = FALSE)

	// Third member of the raw-swap scrub family, alongside SSair.active_turfs and
	// GLOB.starlight above: /turf/closed/wall, /turf/open/floor and /turf/open/misc/grass
	// self-register in GLOB.station_turfs, and the swap above runs no Destroy() to take them
	// back out. Their Initialize() now refuses allocator-dealt ground outright, so nothing
	// stamped into a slot ever gets in - this catches the ordering holes (ground registered
	// before the level had a footprint, a build-out into the gutter) and compacts any
	// duplicates an earlier cycle accreted.
	//
	// One pass over the register rather than a removal per swapped turf: `list -= turf` is a
	// full scan, and a median ruin is ~780 turfs. The entries have been RETARGETED onto the
	// replacement turfs by the swap (BYOND resolves turf refs by coordinate), so they still
	// answer for the ground we just blanked.
	if(length(GLOB.station_turfs))
		var/list/kept_station_turfs = list()
		for(var/turf/registered as anything in GLOB.station_turfs)
			if(registered && registered.z == z_value && (!footprint || footprint.contains_turf(registered)))
				continue
			kept_station_turfs += registered
		GLOB.station_turfs = kept_station_turfs

	reap_emptied_areas(vacated_areas)

/**
 * Deletes the per-load area instances a torn-down tenant has just been emptied of.
 *
 * Areas are minted per build, not per round, on a packed level: fill_in() `new`s one
 * /area/overmap_encounter subtype per tenant, the planet generator `new`s a cave area, and
 * every ruin template load brings its own /area/ruin instances. Teardown reparents their
 * turfs to space but nothing ever deleted the emptied shells, so a churning zone accreted
 * ~21 permanently-live area datums per build/teardown cycle - each one still holding its
 * map_generator, planet_type datum, alarm manager and per-z registration.
 *
 * Guards, in order:
 *
 * * UNIQUE_AREA is the singleton flag (`GLOB.areas_by_type[type] == src`). Deleting one
 *   would leave every future lookup of that type null - /area/space above all, which is
 *   the very area teardown hands its turfs TO.
 * * /area/shuttle instances legitimately outlive their turfs: a hull's areas persist
 *   between the docking-port moves that carry their turfs from place to place.
 * * has_resident_turfs() is the real safety: a co-tenant, a ruin that straddled the
 *   gutter or a shuttle parked in the band can all still be standing in the area, and
 *   /area/Destroy() would then reparent live ground out from under them. It is used in
 *   preference to has_contained_turfs(), whose length arithmetic reports a permanent
 *   phantom occupant for any area a map template ever stole turfs from - which is every
 *   planet surface area that got a ruin, and was why they still accumulated.
 *
 * Takes an assoc list keyed by area (the sweeps build it that way to dedupe ~15k turfs
 * down to a handful of areas); a plain list works too, since iterating either yields areas.
 */
/proc/reap_emptied_areas(list/area/vacated_areas)
	if(!length(vacated_areas))
		return
	for(var/area/vacated as anything in vacated_areas)
		if(QDELETED(vacated))
			continue
		if(vacated.area_flags & UNIQUE_AREA)
			continue
		if(istype(vacated, /area/shuttle))
			continue
		if(vacated.has_resident_turfs())
			continue
		qdel(vacated)

/**
 * Force-initializes any uninitialized turfs in a block (i.e. /turf/open/space/basic,
 * whose New() skips initialization as a map-loader optimization). Players can't
 * interact with uninitialized turfs - no throwing, building, etc. - so any space
 * handed to players must pass through here.
 */
/proc/initialize_uninitialized_block_turfs(turf/bottom_left, turf/top_right)
	if(!bottom_left || !top_right)
		return
	if(!SSatoms.initialized) // roundstart init will sweep every atom in world anyway
		return
	var/list/to_init = list()
	for(var/turf/tile as anything in block(bottom_left, top_right))
		if(!(tile.flags_1 & INITIALIZED_1))
			to_init += tile
	if(length(to_init))
		SSatoms.InitializeAtoms(to_init)

/// Initializes every uninitialized turf in one tenant's footprint, or in the level's
/// legacy bounds when none is given - see initialize_uninitialized_block_turfs.
///
/// Driving this per footprint is most of what packing buys back up front: a flat encounter
/// used to sweep all 65,025 turfs of its level for what is functionally two 56x40 berths,
/// and an unclaimed slot must stay uninitialized until someone is dealt it.
/datum/space_level/proc/initialize_space_turfs(datum/map_footprint/footprint = null)
	if(footprint)
		if(isnull(footprint.low_x))
			return
		initialize_uninitialized_block_turfs(locate(footprint.low_x, footprint.low_y, footprint.z_value), locate(footprint.high_x, footprint.high_y, footprint.z_value))
		return
	initialize_uninitialized_block_turfs(locate(low_x, low_y, z_value), locate(high_x, high_y, z_value))

/**
 * Whether any client-having player is standing within a turf reservation's bounds.
 * Reservations share their z-level with other reservations (space ruins, landable
 * meteor fields, player outposts, ...), so a level-wide clients_by_zlevel check would
 * false-positive whenever a neighbouring reservation has visitors - this scopes
 * strictly to the given reservation's own footprint. Shared by space_ruin.dm and
 * events.dm's landable field cleanup guards.
 */
/proc/turf_reservation_has_players(datum/turf_reservation/reservation)
	if(!reservation)
		return FALSE

	var/turf/bottom_left = reservation.bottom_left_turfs[1]
	if(!bottom_left)
		return FALSE

	var/min_x = bottom_left.x
	var/min_y = bottom_left.y
	var/max_x = min_x + reservation.width - 1
	var/max_y = min_y + reservation.height - 1
	var/res_z = bottom_left.z

	for(var/mob/player in SSmobs.clients_by_zlevel[res_z])
		var/turf/player_turf = get_turf(player)
		if(!player_turf)
			continue
		if(player_turf.x >= min_x && player_turf.x <= max_x && player_turf.y >= min_y && player_turf.y <= max_y)
			return TRUE

	return FALSE

/**
 * The footprint counterpart of turf_reservation_has_players() above - same question, same
 * answer set (any client-having mob, living or not: an observer watching a teardown is as
 * good a reason to hold off as a crewman standing in it), with the rectangle taken from a
 * map slot instead of a reservation block.
 *
 * A packed level carries up to four tenants, so a clients_by_zlevel sweep on its own reads
 * a neighbour's visitors as ours and fuses the two sites' lifecycles: neither recycles
 * until both are empty. The z is still the cheap pre-filter, exactly as before.
 */
/proc/turf_footprint_has_players(datum/map_footprint/footprint)
	if(!footprint || isnull(footprint.low_x) || !footprint.z_value)
		return FALSE

	for(var/mob/player in SSmobs.clients_by_zlevel[footprint.z_value])
		var/turf/player_turf = get_turf(player)
		if(!player_turf)
			continue
		if(footprint.contains_turf(player_turf))
			return TRUE

	return FALSE

/**
 * Why a tenant may not tear its slot down yet, as a log-worthy string, or null when the
 * ground is genuinely clear of hulls.
 *
 * Three ways a ship is still standing in a site after the obvious checks (docked-ship
 * contents, claimed berths, players inside) have all come back clean:
 *
 *  * its docking port's rectangle overlaps ours - the overmap token leaves a full second
 *    before the interior physically moves, and undock recycling fires half a second after
 *    the token leaves, so both of those checks are blind to a hull mid-departure;
 *  * a registered shuttle area still holds a turf inside our rectangle - a bad move
 *    strands tiles, and the teardown sweep would delete them (round 803: Delta's four
 *    thrusters died to exactly this);
 *  * a connected thruster is standing in our rectangle, whose tile may sit in an orphaned
 *    area the sweep above cannot see.
 *
 * Only a VISITING hull may veto (is_encounter_visiting_hull). A ruin template's own
 * shuttle - a Cyborg Mothership, a pirate cutter - is stamped inside the site by
 * SSshuttle.action_load() and overlaps by construction; counting it made every such site
 * refuse its own teardown forever.
 *
 * Shared by every footprint tenant. The asteroid field used to have no hull guard at all,
 * which meant its teardown could empty part of a departing hull outright.
 */
/proc/footprint_blocking_hull_reason(datum/map_footprint/footprint)
	if(!footprint || isnull(footprint.low_x) || !footprint.z_value)
		return null

	var/site_z = footprint.z_value
	for(var/obj/docking_port/mobile/port as anything in SSshuttle.mobile_docking_ports)
		if(QDELETED(port))
			continue
		if(!is_encounter_visiting_hull(port))
			continue
		if(port.z == site_z)
			var/list/port_rect = port.return_coords()
			if(max(port_rect[1], port_rect[3]) >= footprint.low_x \
				&& min(port_rect[1], port_rect[3]) <= footprint.high_x \
				&& max(port_rect[2], port_rect[4]) >= footprint.low_y \
				&& min(port_rect[2], port_rect[4]) <= footprint.high_y)
				return "[port.name] still overlaps [footprint.describe()] (parked or mid-departure)"
		// Stranded hull: a registered ship area still holding turfs inside our block
		for(var/area/ship_area as anything in port.shuttle_areas)
			for(var/turf/held_turf as anything in ship_area.get_turfs_by_zlevel(site_z))
				if(footprint.contains_turf(held_turf))
					return "[port.name]'s [ship_area.type] still holds [held_turf] at [AREACOORD(held_turf)]"
		// Stranded engines: connected thrusters standing in our block (their tile may
		// sit in an orphaned area the sweep above can't see)
		for(var/obj/machinery/power/shuttle_engine/engine as anything in port.engine_list)
			var/turf/engine_turf = get_turf(engine)
			if(engine_turf?.z != site_z)
				continue
			if(footprint.contains_turf(engine_turf))
				return "[port.name]'s [engine] is standing at [AREACOORD(engine_turf)]"

	return null

/**
 * Whether a docking port belongs to a hull that arrives and departs under its own power -
 * a ship an encounter must never pull the ground out from under, and must never delete.
 *
 * Every overmap hull, player or NPC, is an /obj/docking_port/mobile/voidcrew. Everything
 * else standing inside an encounter's reservation came in with the encounter's own
 * TEMPLATE: several space ruins map an /obj/docking_port/stationary carrying a
 * roundstart_template, which LateInitialize()s into SSshuttle.action_load() and stamps a
 * whole derelict shuttle - hull, areas and its own mobile port - inside the reservation
 * (the Cyborg Mothership, the pirate cutter, the syndicate dropship...). Those are
 * scenery: part of the interior being torn down, not a visitor blocking the teardown.
 *
 * Deliberately typed on the port rather than on `current_ship`. current_ship is assigned
 * AFTER the port's Initialize (see /obj/docking_port/mobile/voidcrew), so a hull caught
 * mid-spawn would read as scenery - and the callers of this either refuse to release a
 * reservation or delete a port outright. Being wrong in that direction is unacceptable;
 * being wrong the other way costs one refused teardown that retries in 30 seconds.
 *
 * The two game-critical upstream shuttles are exempted by name for the same reason: they
 * are not overmap hulls, they should never be standing in an encounter reservation, and
 * if one somehow is, deleting it ends the round.
 */
/proc/is_encounter_visiting_hull(obj/docking_port/port)
	if(!istype(port, /obj/docking_port/mobile))
		return FALSE
	if(istype(port, /obj/docking_port/mobile/voidcrew))
		return TRUE
	if(port == SSshuttle.supply || port == SSshuttle.emergency || port == SSshuttle.backup_shuttle || port == SSshuttle.arrivals)
		return TRUE
	return FALSE

/**
 * Force-deletes every docking port left standing inside a reservation that does not
 * belong to a visiting hull. Called immediately before the reservation itself is freed.
 *
 * Nothing else does it, and nothing else can. /turf/proc/empty() - the sweep that clears
 * a reservation turf by turf - explicitly excludes /obj/docking_port from the atoms it
 * qdels, and /obj/docking_port/Destroy() answers a non-forced qdel with
 * QDEL_HINT_LETMELIVE, so a port is only ever deleted by an owner that force-qdels it by
 * name. An encounter's own two berths are (remove_docks); the ports its TEMPLATE brought
 * with it are not. Those outlive the reservation, stay registered in SSshuttle, and go on
 * standing at coordinates the next reservation reuses.
 *
 * That is not only a leak. space_ruin.dm's can_release_interior() walks
 * SSshuttle.mobile_docking_ports looking for a hull overlapping the block it is about to
 * recycle, so one leaked port makes every later reservation allocated over those
 * coordinates refuse its own teardown - permanently, since the port will never move.
 * Measured on the 2026-08-19 soak: a single Cyborg Mothership ruin torn down on cycle 1
 * pinned eleven of the next twenty ruin reservations, each retrying every 30 seconds for
 * the rest of the run.
 *
 * Returns how many ports were reaped.
 */
/proc/reap_reservation_docking_ports(datum/turf_reservation/reservation)
	if(!reservation)
		return 0

	var/turf/bottom_left = reservation.bottom_left_turfs[1]
	if(!bottom_left)
		return 0

	var/min_x = bottom_left.x
	var/min_y = bottom_left.y
	var/max_x = min_x + reservation.width - 1
	var/max_y = min_y + reservation.height - 1
	var/res_z = bottom_left.z

	// One flat copy: force-qdel'ing a port unregisters it, which edits the very
	// SSshuttle lists this walks.
	var/list/obj/docking_port/candidates = SSshuttle.mobile_docking_ports + SSshuttle.stationary_docking_ports
	var/reaped = 0
	for(var/obj/docking_port/port as anything in candidates)
		if(QDELETED(port) || port.z != res_z)
			continue
		if(port.x < min_x || port.x > max_x || port.y < min_y || port.y > max_y)
			continue
		if(is_encounter_visiting_hull(port))
			continue
		reaped++
		qdel(port, force = TRUE)

	if(reaped)
		log_mapping("SSmapping: reaped [reaped] template docking port\s standing in a reservation at ([min_x],[min_y],[res_z]) before freeing it")
	return reaped

/**
 * reap_reservation_docking_ports() for a map-zone slot. Same job, same filter, same
 * force-qdel; the rectangle comes from a footprint instead of a reservation block.
 *
 * Required the moment space ruins take lattice slots. Neither lattice teardown deletes a
 * docking port on its own: clear_to_uninitialized_space() type-excludes /obj/docking_port
 * outright, and clear_reservation() goes through /turf/proc/empty(), which excludes it too
 * - and a non-forced qdel on a port answers QDEL_HINT_LETMELIVE. A site's OWN two berths
 * are taken by name in remove_docks(); the ports its TEMPLATE brought with it (the Cyborg
 * Mothership's, the pirate cutter's, the syndicate dropship's) are not, so they outlive the
 * slot, stay registered in SSshuttle and go on standing at coordinates the next tenant is
 * dealt.
 *
 * That is not merely a leak. footprint_blocking_hull_reason() walks the same port list
 * looking for a hull overlapping the slot it is about to recycle, so one leaked port makes
 * every later tenant of those coordinates refuse its own teardown - permanently, since the
 * port will never move. Measured on the 2026-08-19 soak: one Cyborg Mothership torn down on
 * cycle 1 pinned eleven of the next twenty ruin reservations.
 *
 * Call it BEFORE the ground sweep, while the footprint still knows where it is.
 *
 * Returns how many ports were reaped.
 */
/proc/reap_footprint_docking_ports(datum/map_footprint/footprint)
	if(!footprint || isnull(footprint.low_x) || !footprint.z_value)
		return 0

	// One flat copy: force-qdel'ing a port unregisters it, which edits the very
	// SSshuttle lists this walks.
	var/list/obj/docking_port/candidates = SSshuttle.mobile_docking_ports + SSshuttle.stationary_docking_ports
	var/reaped = 0
	for(var/obj/docking_port/port as anything in candidates)
		if(QDELETED(port) || port.z != footprint.z_value)
			continue
		if(!footprint.contains_coords(port.x, port.y, port.z))
			continue
		if(is_encounter_visiting_hull(port))
			continue
		reaped++
		qdel(port, force = TRUE)

	if(reaped)
		log_mapping("SSmapping: reaped [reaped] template docking port\s standing in [footprint.describe()] before freeing it")
	return reaped

/// `throttled` = whether the fill shares the queued worldgen job's tick budget; the
/// queued planet build leaves it TRUE, unqueued encounter builds (empty space, ruin
/// signals via spawn_dynamic_encounter) pass FALSE - see worldgen_yield().
///
/// `footprint` scopes the fill to one tenant's rectangle. Without it the paint covers the
/// level's legacy bounds, which on a packed level is the WHOLE z - i.e. the co-tenant's
/// area instance repainted out from under it. Every packed caller passes one.
/datum/space_level/proc/fill_in(turf/turf_type, area/area_override, throttled = TRUE, datum/map_footprint/footprint = null)
	var/area/area_to_use = null
	if(area_override)
		if(ispath(area_override))
			area_to_use = new area_override
		else
			area_to_use = area_override

	var/list/turf/fill_turfs = (footprint ? footprint.get_block() : get_block()) || list()

	if(area_to_use)
		for(var/turf/iterated_turf as anything in fill_turfs)
			var/area/old_area = get_area(iterated_turf)
			iterated_turf.change_area(old_area, area_to_use)
			// Throttled yield, not CHECK_TICK - see worldgen_yield() in worldgen_queue.dm
			SSovermap.worldgen_yield(throttled)
			if(QDELETED(src))
				return
		area_to_use.reg_in_areas_in_z()

	if(turf_type)
		for(var/turf/iterated_turf as anything in fill_turfs)
			iterated_turf.ChangeTurf(turf_type, turf_type)
			// Throttled yield, not CHECK_TICK - see worldgen_yield() in worldgen_queue.dm
			SSovermap.worldgen_yield(throttled)
			if(QDELETED(src))
				return

	return area_to_use
