/**
 * Zone ore scaling: planets in deeper overmap zone bands yield MORE ore per
 * mineral wall (same ore tables; kinds are never zone-gated, only amounts).
 *
 * Called from the one-line VOIDCREW EDIT in the base gets_drilled()
 * (code/game/turfs/closed/minerals.dm), the single payout choke point every
 * mining path funnels through (picks, drills, KA/plasma projectiles, ex_act,
 * blob). Scaling at payout instead of Initialize means spread-vein walls
 * (which keep the default mineralAmt of 3, never touched by
 * scale_ore_to_vent()) and mapper-placed ore walls inside planet ruins get
 * scaled too, and it costs nothing at planet init. Walls created after init
 * are equally covered, and on non-planet z-levels (space ruins,
 * asteroid-field reservations, outposts, transit) the band lookup returns
 * null, so behavior there is byte-identical to upstream.
 *
 * Deliberately NOT scaled:
 * * telecrystal + glacial core veins: the planetary trade goods
 *   (voidcrew/modules/trade/planetary_goods.dm); their supply is
 *   economy-tuned, so a richer red-band spigot would distort the
 *   voucher/credit ladder
 * * gibtonite and "very strong rock": their gets_drilled() overrides never
 *   call the base proc, so they never reach this hook; gibtonite's
 *   mineralAmt is detonation bookkeeping, not an ore payout
 * * gulag boulder walls: they use spawned_boulder, not mineralType, so the
 *   base proc's mineralType guard already skips them
 */
/turf/closed/mineral/proc/zone_scaled_ore_amount(amount)
	if(amount <= 0)
		return amount
	// trade-good veins keep their tuned yields (see block comment)
	if(istype(src, /turf/closed/mineral/telecrystal) || istype(src, /turf/closed/mineral/glacial))
		return amount
	// Resolved live, from THIS wall's turf. SSmapping.get_planet_zone_band_for_z() alone
	// only answers for pre-generated roundstart planets, and every planet this round is
	// dynamic, so it always came back null; planet_zone_type_for_turf() asks the overmap
	// first and falls back to it. Turf-scoped, not z-scoped: a z-level can carry more than
	// one planet and they can sit in different bands, so the wall has to speak for itself.
	// Not cached per z either - dynamic planet z-levels are recycled, so a cached band
	// would follow the z-level onto the next planet to inherit it.
	switch(SSovermap_zones?.planet_zone_type_for_turf(src))
		if(ZONE_YELLOW)
			return round(amount * ZONE_PLANET_ORE_MULT_YELLOW)
		if(ZONE_RED)
			return round(amount * ZONE_PLANET_ORE_MULT_RED)
	return amount

// NOTE (2026-08 upstream merge): the vent-proximity fallback that lived here
// (z_has_ore_vent + proximity_ore_chance/scale_ore_to_vent overrides) is gone, and so is
// the antag-dispersal refresh's per-FOOTPRINT rewrite of it (has_local_ore_vent() /
// local_ore_vent_coords() / a prox_to_vent() that refused to grade a wall against a
// neighbouring tenant's vents). Both overrode procs upstream deleted when it replaced
// vent-proximity ore with the depth/exposure model below.
//
// What replaced them is the build-time roll further down this file. The failure mode the
// old overrides patched - "the ore system runs at a moment a dynamically built planet is
// not alive for, so the planet comes up oreless" - came back in a new shape under the depth
// model, and the per-footprint CONCERN came back with it. Both are answered by
// randomize_site_ore(); see its doc comment.

// ---- Build-time ore for mid-round sites ---------------------------------------------
//
// Upstream's depth model does not roll ore in Initialize(). A rock with `exposure_based`
// set - /turf/closed/mineral/random/volcanic and /turf/closed/mineral/random/snow, which is
// to say every wall voidcrew's lava and ice biomes lay down - appends itself to
// SSore_generation.ore_turfs and waits for the calculate_rock_edges() + randomize_ore()
// pass. That pass runs exactly ONCE, at the bottom of SSore_generation.Initialize()
// (code/controllers/subsystem/ore_generation.dm). A roundstart mining map is alive for it.
// A planet built when a ship flies to it, minutes or hours into the round, is not: its rock
// queues into a list nothing will ever read again.
//
// Left alone, an ICE planet generates with exactly zero ore in exactly zero walls -
// /turf/closed/mineral/random/snow is the only closed type its biomes lay down - and a LAVA
// planet keeps about a sixth of its intended ore, from the 1-in-11
// high_chance/volcanic/voidcrew walls that are not exposure-based and so still roll at
// Initialize. Both planetary trade goods go with it: glacial cores to zero, telecrystal
// veins to roughly a twelfth of their intended rate, since both are entries in those same
// deferred tables (voidcrew/modules/trade/planetary_goods.dm).
//
// It fails silently: no runtime, no log line, just barren rock.
//
// So the build path runs the same two passes itself, over its own finished footprint. The
// roll is upstream's own randomize_ore(), CALLED rather than reimplemented, so retunes to
// the depth curve, the vein shapes and every weight table keep applying here.
//
// Scoped to one site's RECTANGLE, not to the z-level. Upstream's calculate_rock_edges()
// walks whole z-levels out of SSmapping.levels_by_trait(ZTRAIT_MINING), and every planet
// z-level carries that trait. Up to four sites share one packed level here, so a z-wide walk
// would grade - and a z-wide drain would roll - a co-tenant's rock, out from under a crew
// that may be standing on it.
//
// The 5-turf cordon gutter between slots (MAP_SLOT_GUTTER, painted by
// /datum/space_level/place_cordon before any terrain is laid) does already make that leak
// impossible on its own: /turf/cordon is neither /turf/open, so it cannot seed a distance-1
// edge, nor a mineral turf, so the BFS cannot step through it. A rock band therefore cannot
// span two footprints. Bounding the walk to the rect makes that a guarantee of this code
// rather than a property of the cordon that a future lattice change could quietly take away
// - and it is also what makes the pass affordable: 15k turfs for our own slot instead of
// 65k for the level.
//
// One thing the rect does NOT bound is spread_vein(), which upstream runs in `range()`
// around a rolled wall. Its widest vein is 4 tiles - narrower than the gutter - so it cannot
// reach a neighbour either. If a future ore raises max_vein_size past MAP_SLOT_GUTTER, that
// becomes reachable, and this is the note that says so.

/**
 * Upstream's calculate_rock_edges(), bounded to one rectangle: grades every mineral wall
 * inside it by its distance to the nearest open turf, BFS outward from the walls that touch
 * open air.
 *
 * Only ever writes to a wall still holding the unset sentinel, exactly as upstream does, so
 * running twice over the same ground is free and a wall already graded by a previous pass
 * (a ruin's own rock, a wall the roundstart pass reached) keeps the depth it had.
 *
 * Returns how many walls it graded.
 */
/proc/calculate_rock_edges_in_rect(low_x, low_y, high_x, high_y, z_value, throttled = TRUE)
	if(!z_value)
		return 0
	low_x = max(low_x, 1)
	low_y = max(low_y, 1)
	high_x = min(high_x, world.maxx)
	high_y = min(high_y, world.maxy)
	if(low_x > high_x || low_y > high_y)
		return 0

	// Same copy upstream takes, for the same reason: this is read once per turf per
	// direction over a 15k-turf block, and iterating the GLOB list directly is not free.
	var/list/cardinals = GLOB.cardinals.Copy()
	// Upstream's DEFAULT_BORDER_DISTANCE, read off the type rather than restated: that
	// define is #undef'd at the bottom of code/game/turfs/closed/minerals.dm, and a copy of
	// the number here would be a second place to keep in step.
	var/ungraded = /turf/closed/mineral::open_turf_distance
	var/graded = 0
	// The frontier doubles as the BFS queue - walked by index rather than popped, so the
	// distances stay in breadth order and nothing is ever revisited.
	var/list/turf/closed/mineral/frontier = list()

	for(var/turf/tile as anything in block(locate(low_x, low_y, z_value), locate(high_x, high_y, z_value)))
		if(!isopenturf(tile))
			continue
		for(var/neighbour_dir in cardinals)
			var/turf/neighbour = get_step(tile, neighbour_dir)
			if(!ismineralturf(neighbour))
				continue
			// The neighbour of an in-rect turf can be out of rect - that is the co-tenant's
			// wall (or the cordon's far side), and grading it is exactly what this bound exists
			// to prevent.
			if(neighbour.x < low_x || neighbour.x > high_x || neighbour.y < low_y || neighbour.y > high_y)
				continue
			var/turf/closed/mineral/rock = neighbour
			if(rock.open_turf_distance != ungraded)
				continue
			rock.open_turf_distance = 1
			frontier += rock
			graded++
		// Throttled yield, not CHECK_TICK - see worldgen_yield() in worldgen_queue.dm
		SSovermap.worldgen_yield(throttled)

	var/index = 1
	while(index <= length(frontier))
		var/turf/closed/mineral/rock = frontier[index]
		index++
		for(var/neighbour_dir in cardinals)
			var/turf/neighbour = get_step(rock, neighbour_dir)
			if(!ismineralturf(neighbour))
				continue
			if(neighbour.x < low_x || neighbour.x > high_x || neighbour.y < low_y || neighbour.y > high_y)
				continue
			var/turf/closed/mineral/rock_neighbour = neighbour
			// No "is this closer" test needed: a BFS fill reaches every wall by its shortest
			// path first, which is upstream's reasoning too.
			if(rock_neighbour.open_turf_distance != ungraded)
				continue
			rock_neighbour.open_turf_distance = rock.open_turf_distance + 1
			frontier += rock_neighbour
			graded++
		SSovermap.worldgen_yield(throttled)

	return graded

/**
 * randomize_ore() ends on
 * `SSore_generation.ore_spread_probabilities[type]["[open_turf_distance]"]["count"] += 1`,
 * and SSore_generation.Initialize() rewrites that whole structure the moment its own roll
 * pass finishes: calculate_ore_spread() replaces it with a SUMMARY keyed by ore type, with
 * every depth key gone. Upstream never notices, because upstream never rolls a rock after
 * that point. We do, and the first mid-round roll of any (rock type, depth) pair that had
 * also rolled at roundstart indexes a null and runtimes - mid-build, inside the worldgen
 * queue, with the rest of the site's rock unrolled behind it.
 *
 * So the bucket the increment is about to land in is made to exist first. If randomize_ore()
 * turns out to be computing this depth for the first time it LAZYSETs the real structure
 * over the top of this stub, which is the same end state upstream reaches.
 *
 * The structure is debug bookkeeping - nothing in the codebase reads
 * ore_spread_probabilities outside calculate_ore_spread() itself - so a mid-round depth key
 * sitting alongside the roundstart summary costs nothing but a slightly mixed debug dump.
 */
/proc/ensure_ore_spread_bucket(turf/closed/mineral/random/rock)
	var/list/type_spread = SSore_generation.ore_spread_probabilities[rock.type]
	if(!islist(type_spread))
		type_spread = list()
		SSore_generation.ore_spread_probabilities[rock.type] = type_spread
	var/depth_key = "[rock.open_turf_distance]"
	if(!islist(type_spread[depth_key]))
		type_spread[depth_key] = list("count" = 0)

/**
 * Grades and rolls every ore-pending wall inside one rectangle. See the block comment above.
 *
 * "Pending" is read off SSore_generation.ore_turfs rather than off the ground, which is what
 * keeps this from double-rolling: a wall is in that list if and only if its Initialize()
 * declined to roll (exposure_based) and nothing has rolled it since. Walls that DID roll at
 * Initialize - the non-exposure vein types, and anything a mapper placed - are not in it and
 * are left exactly as they are.
 *
 * Returns how many walls were rolled.
 */
/proc/randomize_ore_in_rect(low_x, low_y, high_x, high_y, z_value, throttled = TRUE)
	// Nothing anywhere is waiting for a roll. The normal answer for every flat encounter
	// build, and it costs one list length read.
	if(!length(SSore_generation.ore_turfs))
		return 0
	if(!z_value)
		return 0
	low_x = max(low_x, 1)
	low_y = max(low_y, 1)
	high_x = min(high_x, world.maxx)
	high_y = min(high_y, world.maxy)
	if(low_x > high_x || low_y > high_y)
		return 0

	// Take the queue away in ONE uninterruptible step. Everything below yields, and a site
	// build appends to this list from every rock's Initialize() while it does - filtering the
	// list and writing the survivors back would silently drop whatever arrived in between.
	// Anything queued from here on lands in the fresh list and is nobody's business but its
	// own owner's.
	var/list/queued = SSore_generation.ore_turfs
	SSore_generation.ore_turfs = list()

	var/list/turf/closed/mineral/random/pending = list()
	var/list/turf/closed/mineral/random/not_ours = list()
	for(var/turf/closed/mineral/random/rock as anything in queued)
		// Typecheck for the same reason upstream's own pass has one: a queued wall can have
		// been mined, scraped or ChangeTurf'd into something else since it asked.
		if(!istype(rock))
			continue
		if(rock.z != z_value || rock.x < low_x || rock.x > high_x || rock.y < low_y || rock.y > high_y)
			not_ours += rock
			continue
		pending += rock
		// Throttled yield, not CHECK_TICK - see worldgen_yield() in worldgen_queue.dm
		SSovermap.worldgen_yield(throttled)

	// A co-tenant's rock, or a site mid-build on another level, goes straight back in the
	// queue for whoever owns it. Appended to the live list rather than assigned over it, so
	// anything that queued while we were partitioning survives.
	if(length(not_ours))
		SSore_generation.ore_turfs += not_ours
	if(!length(pending))
		return 0

	calculate_rock_edges_in_rect(low_x, low_y, high_x, high_y, z_value, throttled)

	var/rolled = 0
	for(var/turf/closed/mineral/random/rock as anything in pending)
		// This loop yields, so a wall can be mined, blown up or otherwise replaced between one
		// iteration and the next.
		//
		// What is NOT guarded against, deliberately: an earlier wall's spread_vein() reaching
		// this one and handing it ore, which randomize_ore() may then overwrite with its own
		// roll. Upstream's pass has exactly that property - vein spread is meant to be able to
		// paint over walls that have not had their turn yet - so do not "fix" it by rolling
		// everything before spreading anything. That would be a different ore distribution to
		// the one the tables are tuned against.
		if(!istype(rock))
			continue
		ensure_ore_spread_bucket(rock)
		rock.randomize_ore()
		rolled++
		SSovermap.worldgen_yield(throttled)

	return rolled

/**
 * Build-time ore roll for one site, taking its rectangle from the footprint it was dealt.
 *
 * This is the call site-builders want: /obj/structure/overmap/planet/build_planet() runs it
 * as its last generation stage, and spawn_dynamic_encounter() runs it for encounter
 * interiors. The z-level is only a fallback for a site with no footprint - on a packed level
 * the level's own rect is every tenant on it.
 *
 * Returns how many walls were rolled.
 */
/proc/randomize_site_ore(datum/map_footprint/footprint, datum/space_level/level, throttled = TRUE)
	var/low_x = footprint?.low_x
	var/low_y = footprint?.low_y
	var/high_x = footprint?.high_x
	var/high_y = footprint?.high_y
	var/z_value = footprint?.z_value
	if(isnull(low_x) || isnull(low_y) || !z_value)
		low_x = level?.low_x || 1
		low_y = level?.low_y || 1
		high_x = level?.high_x || world.maxx
		high_y = level?.high_y || world.maxy
		z_value = level?.z_value
	if(!z_value)
		return 0
	return randomize_ore_in_rect(low_x, low_y, high_x, high_y, z_value, throttled)

/turf/closed/mineral/random/high_chance/wasteland
	baseturfs = /turf/open/misc/dust

/turf/closed/mineral/random/high_chance/mineral_chances()
	return list(
		/obj/item/stack/ore/uranium = 35,
		/obj/item/stack/ore/diamond = 30,
		/obj/item/stack/ore/gold = 45,
		/obj/item/stack/ore/titanium = 45,
		/obj/item/stack/ore/iron = 55,
		/obj/item/stack/ore/silver = 50,
		/obj/item/stack/ore/plasma = 50,
		/obj/item/stack/ore/bluespace_crystal = 20,
		/turf/closed/mineral/gibtonite/wasteland = 4,
		/turf/closed/mineral/telecrystal/wasteland = 6,
	)

/turf/closed/mineral/gibtonite/wasteland
	baseturfs = /turf/open/misc/dust

/turf/closed/mineral/random/beach
	baseturfs = /turf/open/misc/asteroid/sand/beach/dense

/turf/closed/wall/mineral/titanium/interior/blue
	color = "#9CE9F6"
	smoothing_flags = SMOOTH_BITMASK

/turf/closed/wall/mineral/titanium/interior/blue/Initialize()
	. = ..()
	add_atom_colour("#9CE9F6", FIXED_COLOUR_PRIORITY) // fuck you
