#define BIOME_RANDOM_SQUARE_DRIFT 2

/**
 * Spacing, in tiles, of the lattice each noise field is sampled on. Every tile's real
 * value is bilinearly interpolated from the four lattice points around it.
 *
 * rustg_noise_get_at_coordinates() is an FFI call whose arguments are marshalled as text
 * and whose result comes back as text to be parsed, and the old loop made three of them
 * per tile - roughly 49,000 round trips, 49,000 text2num parses and 98,000
 * float-to-string interpolations for a 128x128 planet. At perlin_zoom 65 these fields
 * vary over ~65-tile wavelengths, so a 4-tile lattice reproduces them far inside the
 * width of a single biome band: ~3,500 calls instead of ~49,000, for the same terrain.
 *
 * The per-tile drift is applied to the interpolated coordinate rather than to the lattice
 * sample, so biome borders still dither exactly as they did.
 *
 * Set to 1 to read every tile individually again - the lattice then lands on the integer
 * coordinates themselves and the interpolation degenerates to an exact read - if a biome
 * layout ever looks wrong and you need to rule this out.
 */
#define PLANET_NOISE_STRIDE 4

/**
 * One noise field, sampled once onto a coarse lattice and read back by interpolation -
 * see PLANET_NOISE_STRIDE.
 *
 * Plain data with no outside references: built at the top of a generation pass, read once
 * per tile, and dropped when the pass returns.
 */
/datum/noise_field
	/// Lattice values, row-major and 1-indexed as `1 + gx + grid_w * gy`.
	var/list/values
	/// World coordinates of lattice column 0 / row 0.
	var/min_x = 0
	var/min_y = 0
	/// Lattice dimensions, in lattice points (not tiles).
	var/grid_w = 0
	var/grid_h = 0

/**
 * Bilinear read of this field at world coordinates (x, y). Coordinates outside the
 * sampled block clamp to its edge - which is what the drift margin the builder adds is
 * there to keep from happening.
 */
/datum/noise_field/proc/sample(x, y)
	var/fx = (x - min_x) / PLANET_NOISE_STRIDE
	var/fy = (y - min_y) / PLANET_NOISE_STRIDE
	// Single-argument round() is FLOOR in DM, not round-to-nearest - which is what this
	// wants, so that tx/ty below land in [0,1) and the read interpolates between the
	// lattice cell's own corners. (The same fact is what makes FLOOR() in
	// code/__DEFINES/maths.dm work.) Do not "fix" this to round-to-nearest.
	var/gx = clamp(round(fx), 0, grid_w - 2)
	var/gy = clamp(round(fy), 0, grid_h - 2)
	var/tx = fx - gx
	var/ty = fy - gy
	var/low_index = 1 + gx + grid_w * gy
	var/high_index = low_index + grid_w
	var/low_row = values[low_index] + (values[low_index + 1] - values[low_index]) * tx
	var/high_row = values[high_index] + (values[high_index + 1] - values[high_index]) * tx
	// Clamped because every consumer is a switch() over 0..1 bands, and a value that
	// fell outside them would match no branch, leave the caller's biome level null and
	// runtime on the next list index. A convex blend of four in-range corners cannot
	// leave the range on its own; this is here so an edge tile that extrapolates by a
	// hair still cannot.
	return clamp(low_row + (high_row - low_row) * ty, 0, 1)

/datum/map_generator/planet_generator
	var/name = "Planet Generator"
	/// Whether generation loops share the queued worldgen job's tick budget (see
	/// worldgen_yield()). Planet builds under the worldgen queue leave this TRUE;
	/// spawn_dynamic_encounter() clears it on the instances it drives - by design
	/// rule, a survey must never slow the loading of a ruin or empty space.
	var/throttled = TRUE
	var/mountain_height = 0.85
	var/perlin_zoom = 65
	var/initial_closed_chance = 45
	var/smoothing_iterations = 20
	var/birth_limit = 4
	var/death_limit = 3

/**
 * Samples one noise field across the given lattice: one FFI call per lattice point,
 * where the per-tile loop used to make one per tile. See PLANET_NOISE_STRIDE.
 */
/datum/map_generator/planet_generator/proc/build_noise_field(seed, min_x, min_y, grid_w, grid_h)
	var/datum/noise_field/field = new
	field.min_x = min_x
	field.min_y = min_y
	field.grid_w = grid_w
	field.grid_h = grid_h

	var/list/values = new /list(grid_w * grid_h)
	var/index = 1
	for(var/gy in 0 to grid_h - 1)
		var/sample_y = (min_y + gy * PLANET_NOISE_STRIDE) / perlin_zoom
		for(var/gx in 0 to grid_w - 1)
			var/sample_x = (min_x + gx * PLANET_NOISE_STRIDE) / perlin_zoom
			values[index] = text2num(rustg_noise_get_at_coordinates("[seed]", "[sample_x]", "[sample_y]"))
			index++
		// Once per lattice ROW, not per point: a row is only a few dozen calls.
		SSovermap.worldgen_yield(throttled)

	field.values = values
	return field

/datum/map_generator/planet_generator/generate_terrain(list/turf/turfs, datum/planet/planet_type, is_cave, init_planet)
	. = ..()
	if(!planet_type)
		log_world("[name] planet generation failed!")
		return
	var/start_time = REALTIMEOFDAY

	var/height_seed = rand(0, 50000)
	var/humidity_seed = rand(0, 50000)
	var/heat_seed = rand(0, 50000)

	var/string_gen = rustg_cnoise_generate("[initial_closed_chance]", "[smoothing_iterations]", "[birth_limit]", "[death_limit]", "[world.maxx]", "[world.maxy]") //Generate the raw CA data

	var/area/overmap_encounter/planetoid/cave/cave_area
	var/caves = FALSE
	var/overworld = FALSE
	// Whether this call created cave_area, or borrowed the invoking cave area. Decides
	// registration (a borrowed one is already in areas_in_z - re-registering appends a
	// duplicate, reg_in_areas_in_z() does not dedup) and cleanup on the early returns.
	var/minted_cave_area = FALSE

	if (planet_type.cave_biomes && length(planet_type.cave_biomes) > 0)
		caves = TRUE
		// Reuse, never mint, when this IS the cave pass. RunTerrainGeneration() on a cave
		// area hands us that area's own turfs; minting a fresh instance here made
		// generate_cave()'s change_area() migrate every tile out of the invoking instance
		// into the new one, leaving the old cave area empty but still registered - one
		// leaked /area per planet per build (churn soak: encounter_areas +8/cycle, half of
		// it this). An empty area has no z, so no teardown reap can ever see one - the fix
		// has to be here at the mint.
		if(is_cave && length(turfs))
			var/area/invoking_area = get_area(turfs[1])
			if(istype(invoking_area, /area/overmap_encounter/planetoid/cave))
				cave_area = invoking_area
		if(isnull(cave_area))
			cave_area = new
			minted_cave_area = TRUE
		cave_area.map_generator = src
	// This is needed because planet surfaces start as /area/overmap_encounter/planetoid/planet_type
	// If we're starting with an /area/overmap_encounter/planetoid/cave, we want to ignore overworld_biomes
	if(!is_cave)
		if (planet_type.overworld_biomes && length(planet_type.overworld_biomes) > 0)
			overworld = TRUE

	if (!caves && !overworld)
		return

	// Extent of the block we were handed, for the noise lattice below. Pure arithmetic
	// over the turf list - no FFI and no allocation - so it batches its yields hard
	// rather than offering one per tile.
	var/min_x = INFINITY
	var/min_y = INFINITY
	var/max_x = 0
	var/max_y = 0
	for(var/turf/bounds_turf as anything in turfs)
		if(bounds_turf.x < min_x)
			min_x = bounds_turf.x
		if(bounds_turf.x > max_x)
			max_x = bounds_turf.x
		if(bounds_turf.y < min_y)
			min_y = bounds_turf.y
		if(bounds_turf.y > max_y)
			max_y = bounds_turf.y
		SSovermap.worldgen_yield(throttled)
	if(min_x > max_x)
		// A freshly-minted cave area that will never hold a turf is unreachable by every
		// reap (an empty area has no z) - take it with us on the way out.
		if(minted_cave_area)
			qdel(cave_area)
		return

	// One lattice geometry, three fields sampled on it. The drift margin is built into
	// the origin and the width so a tile jittered off the edge of the block still lands
	// inside the lattice instead of clamping to it.
	var/noise_min_x = min_x - BIOME_RANDOM_SQUARE_DRIFT
	var/noise_min_y = min_y - BIOME_RANDOM_SQUARE_DRIFT
	var/grid_w = round(((max_x + BIOME_RANDOM_SQUARE_DRIFT) - noise_min_x) / PLANET_NOISE_STRIDE) + 2
	var/grid_h = round(((max_y + BIOME_RANDOM_SQUARE_DRIFT) - noise_min_y) / PLANET_NOISE_STRIDE) + 2

	var/datum/noise_field/heat_field = build_noise_field(heat_seed, noise_min_x, noise_min_y, grid_w, grid_h)
	var/datum/noise_field/humidity_field = build_noise_field(humidity_seed, noise_min_x, noise_min_y, grid_w, grid_h)
	var/datum/noise_field/height_field = build_noise_field(height_seed, noise_min_x, noise_min_y, grid_w, grid_h)

	for(var/t in turfs)
		var/turf/gen_turf = t
		var/drift_x = gen_turf.x + rand(-BIOME_RANDOM_SQUARE_DRIFT, BIOME_RANDOM_SQUARE_DRIFT)
		var/drift_y = gen_turf.y + rand(-BIOME_RANDOM_SQUARE_DRIFT, BIOME_RANDOM_SQUARE_DRIFT)

		var/heat = heat_field.sample(drift_x, drift_y)
		// VOIDCREW EDIT: height is sampled UNDRIFTED, unlike heat and humidity. Height's
		// only consumer is the cave-vs-surface decision below, and that decision now also
		// picks the turf's AREA - dark static cave against bright ambient surface. Sampling
		// it at the drifted coordinates dithered that boundary tile-by-tile: invisible when
		// every turf was /lit and light was corner-continuous, a hard bright/dark
		// checkerboard under area lighting. Undrifted, the lighting boundary is the raw
		// noise curve and ambient bleed shades across it; heat and humidity keep the drift
		// so biome FLAVOR still dithers naturally on both sides.
		var/height = height_field.sample(gen_turf.x, gen_turf.y)
		// END VOIDCREW EDIT (was: sampled at drift_x/drift_y)
		var/humidity = humidity_field.sample(drift_x, drift_y)
		var/humidity_level

		if(caves)
			var/area/A = gen_turf.loc
			if(!(A.area_flags & CAVES_ALLOWED))
				continue

		switch(humidity)
			if(0 to 0.20)
				humidity_level = BIOME_LOWEST_HUMIDITY
			if(0.20 to 0.40)
				humidity_level = BIOME_LOW_HUMIDITY
			if(0.40 to 0.60)
				humidity_level = BIOME_MEDIUM_HUMIDITY
			if(0.60 to 0.80)
				humidity_level = BIOME_HIGH_HUMIDITY
			if(0.80 to 1)
				humidity_level = BIOME_HIGHEST_HUMIDITY

		if(height <= mountain_height)
			if(overworld)
				generate_overworld(heat, humidity_level, gen_turf, planet_type)
			else
				generate_cave(heat, humidity_level, string_gen, gen_turf, cave_area, planet_type)
		else
			if(caves)
				generate_cave(heat, humidity_level, string_gen, gen_turf, cave_area, planet_type)
			else
				generate_overworld(heat, humidity_level, gen_turf, planet_type)
		// Not CHECK_TICK: that yields only once the tick is nearly full, which still
		// leaves this loop taking ~70% of every tick for its whole run. See
		// worldgen_yield() in worldgen_queue.dm.
		SSovermap.worldgen_yield(throttled)
	// Register cave areas - only ones this call minted; a borrowed cave area is already
	// registered, and reg_in_areas_in_z() appends without dedup.
	if(caves && minted_cave_area)
		cave_area.reg_in_areas_in_z()

	// Logged, not announced: planets regenerate mid-round, and a world-wide bold
	// line every time one builds is a debug leftover from bring-up.
	log_world("[name] planet generation finished in [(REALTIMEOFDAY - start_time)/10]s!")

/datum/map_generator/planet_generator/proc/generate_overworld(heat, humidity_level, turf/gen_turf, datum/planet/planet_type)
	var/heat_level
	var/datum/biome/selected_biome

	switch(heat)
		if(0 to 0.20)
			heat_level = planet_type.overworld_biomes[BIOME_COLDEST]
		if(0.20 to 0.40)
			heat_level = planet_type.overworld_biomes[BIOME_COLD]
		if(0.40 to 0.60)
			heat_level = planet_type.overworld_biomes[BIOME_WARM]
		if(0.60 to 0.65)
			heat_level = planet_type.overworld_biomes[BIOME_TEMPERATE]
		if(0.65 to 0.80)
			heat_level = planet_type.overworld_biomes[BIOME_HOT]
		if(0.80 to 1)
			heat_level = planet_type.overworld_biomes[BIOME_HOTTEST]
	selected_biome = heat_level[humidity_level]
	selected_biome = SSmapping.biomes[selected_biome]
	var/turf/picked_turf = pickweight(selected_biome.open_turf_types)
	picked_turf = place_biome_turf(gen_turf, picked_turf)
	picked_turf.generating_biome = selected_biome

/**
 * Lays one generated turf down over gen_turf.
 *
 * Raw `new turf_type(gen_turf)` is the fast path the roundstart map loader uses, but it
 * bypasses ChangeTurf - and with it the lighting update. That is invisible when terrain
 * generates before SSlighting comes up, and produces a black, unlit planet when it does
 * not. Planets that generate on first visit are always in the second case.
 *
 * So the raw swap is taken only where there is no lighting update to miss. Ambient-lit
 * ground - a planet surface: static_lighting FALSE, ambient_lighting TRUE, a non-zero
 * base_lighting_alpha - carries NO lighting object at all, because the area paints it
 * wholesale (see /turf/proc/skips_lighting_object()). For those tiles ChangeTurf's entire
 * lighting branch resolves to "delete the object you were never going to have", and what
 * it charges to get there is a COMSIG_TURF_CHANGE signal and its callback list, a
 * qdel()/Destroy() of the old tile, two signal-lookup list copies, a baseturfs rebuild, an
 * atmos AfterChange, directional-opacity recalculation and a starlight neighbour sweep -
 * on every one of a planet's ~16,000 tiles, to reach the same end state as a raw `new`.
 *
 * Four things keep the fast path honest:
 *
 * 1. `destined_for_cave`, rather than asking gen_turf what area it is in. Cave tiles are
 *    laid down while still inside the SURFACE area and only moved into the cave area
 *    afterwards (see generate_cave), so the tile's own answer is "ambient ground" for a
 *    tile that is about to become a statically lit cave and genuinely needs an object.
 *    Caves keep ChangeTurf.
 * 2. A turf that lights ITSELF - a lava river, the fallout zone's hazard green - needs an
 *    object for its own light to land on, which is exactly the exception
 *    skips_lighting_object() carves out. Any type declaring a light_range takes the slow
 *    path.
 * 3. release_light_for_raw_swap() first. A raw swap DROPS the old tile's light source
 *    rather than freeing it, and a dropped source is uncollectable rather than merely
 *    garbage - it and the lighting corners it applied to hold each other under pure
 *    refcounting. This is the same guard the cave generators carry for the same reason
 *    (code/datums/mapgen/CaveGenerator.dm).
 * 4. adopt_lighting_from_raw_swap() after. ChangeTurf carries the old turf's four
 *    /datum/lighting_corner refs across its own qdel()/new() pair; a raw swap gets the
 *    type defaults instead, and a turf with null corner refs standing on vertices that
 *    already have corners MINTS NEW ONES and steals them from the neighbours it shares
 *    them with. That is what a cave mouth lit on one side and black on the other is.
 *

 * The fast path only ever lays OPEN turfs, because generate_overworld only ever picks from
 * open_turf_types. That matters for atmos: an open turf queues its own adjacency rebuild
 * through requires_activation in /turf/Initialize, where a closed one never does and would
 * have to be handed to CALCULATE_ADJACENT_TURFS by hand.
 */
/datum/map_generator/planet_generator/proc/place_biome_turf(turf/gen_turf, turf/turf_type, destined_for_cave = FALSE)
	if(!SSlighting.initialized)
		return new turf_type(gen_turf)

	if(!destined_for_cave && !initial(turf_type.light_range))
		var/area/ground_area = gen_turf.loc
		if(ground_area?.ambient_lighting && !ground_area.static_lighting && ground_area.base_lighting_alpha)
			// The two flags ChangeTurf carries across a swap; nothing else on a turf's
			// flags is meant to survive one.
			var/carryover_flags = (RESERVATION_TURF | UNUSED_RESERVATION_TURF) & gen_turf.turf_flags
			// Captured before the swap, for the bleed maintenance below - which is the ONE
			// thing ChangeTurf does on this path that is not lighting bookkeeping we are
			// deliberately skipping. See the call at the bottom of this branch.
			var/old_type = gen_turf.type
			var/datum/lighting_object/old_lighting_object = gen_turf.lighting_object
			// Second casualty of skipping ChangeTurf's qdel(src): /turf/open/space/Destroy()
			// is what takes a lit space turf back out of GLOB.starlight, and it never runs on a
			// raw swap. The entry is not merely stale - BYOND retargets it onto the ground turf
			// we just laid, set_starlight() then walks the list `as anything` and relights it,
			// and if that spot is ever lit space again enable_starlight() appends a turf that is
			// already a member, so a churning zone grows a duplicate per cycle. Same guard
			// place_cordon_turf() carries, for the same reason (voidcrew/datums/map_zones.dm).
			if(isspaceturf(gen_turf) && gen_turf.light_on)
				GLOB.starlight -= gen_turf
			gen_turf.release_light_for_raw_swap()
			// Third casualty, and the one that shows: the four lighting corners. A planet
			// block is filled with LIT SPACE before we touch it (that is what the
			// GLOB.starlight guard above exists for), so every tile already carries four
			// corner datums shared with its neighbours - and a raw `new` drops all four
			// refs where ChangeTurf would have carried them. The tile then mints
			// replacements for vertices that already have them and steals the finished
			// cave tile next door's corner out from under its lighting object. Read AFTER
			// release_light_for_raw_swap(), which can idle a corner out from under us.
			// See /turf/proc/adopt_lighting_from_raw_swap() in voidcrew/edits/turf.dm.
			var/datum/lighting_corner/corner_ne = gen_turf.lighting_corner_NE
			var/datum/lighting_corner/corner_se = gen_turf.lighting_corner_SE
			var/datum/lighting_corner/corner_sw = gen_turf.lighting_corner_SW
			var/datum/lighting_corner/corner_nw = gen_turf.lighting_corner_NW
			var/old_dynamic_lumcount = gen_turf.dynamic_lumcount
			var/turf/fast_turf = new turf_type(gen_turf)
			fast_turf.adopt_lighting_from_raw_swap(corner_ne, corner_se, corner_sw, corner_nw, old_dynamic_lumcount)
			fast_turf.turf_flags |= carryover_flags
			fast_turf.assemble_baseturfs(initial(fast_turf.baseturfs) || fast_turf.type)
			// NOT optional, and the reason the first cut of this shipped razor-hard edges.
			// Ambient-lit ground carries no lighting object, so the only thing softening the
			// boundary between it and a statically lit tile - a cave mouth, a ruin wall, the
			// planet's own edge - is the bleed light this gives the tile. /turf/ChangeTurf
			// calls it for every tile it lays (voidcrew/edits/turf.dm), so a raw swap that
			// skips ChangeTurf has to call it itself or every such boundary becomes a
			// one-tile step from full daylight to black.
			fast_turf.update_ambient_bleed_after_change(old_type, old_lighting_object)
			return fast_turf

	var/turf/new_turf = gen_turf.ChangeTurf(turf_type, flags = CHANGETURF_IGNORE_AIR)
	// ChangeTurf inherits the previous occupant's baseturfs - here that's the bare space
	// the z-level was filled with, so anything that later removes a tile (a ruin's
	// clear_below, an explosion, lava eating the ground) opens a hole into literal
	// space. Rebuild the stack from the turf type's own definition, exactly like the
	// raw-new boot path always produced. Every planet turf defines baseturfs as a
	// single path, so initial() is safe; the type itself is the never-space fallback.
	new_turf.assemble_baseturfs(initial(new_turf.baseturfs) || new_turf.type)
	return new_turf

/datum/map_generator/planet_generator/proc/generate_cave(heat, humidity_level, string_gen, turf/gen_turf, cave_area, datum/planet/planet_type)
	var/datum/biome/cave/selected_cave_biome
	var/heat_level

	switch(heat)
		if(0 to 0.25)
			heat_level = planet_type.cave_biomes[BIOME_COLDEST_CAVE]
		if(0.25 to 0.5)
			heat_level = planet_type.cave_biomes[BIOME_COLD_CAVE]
		if(0.5 to 0.75)
			heat_level = planet_type.cave_biomes[BIOME_WARM_CAVE]
		if(0.75 to 1)
			heat_level = planet_type.cave_biomes[BIOME_HOT_CAVE]
	selected_cave_biome = heat_level[humidity_level]
	selected_cave_biome = SSmapping.biomes[selected_cave_biome]
	var/closed = text2num(string_gen[world.maxx * (gen_turf.y - 1) + gen_turf.x])
	var/turf/picked_turf = pickweight(closed ? selected_cave_biome.closed_turf_types : selected_cave_biome.open_turf_types)
	// Caves are statically lit and need a real lighting object, and this tile is still in
	// the SURFACE area right now - see place_biome_turf().
	picked_turf = place_biome_turf(gen_turf, picked_turf, destined_for_cave = TRUE)
	if(gen_turf.turf_flags & NO_RUINS)
		picked_turf.turf_flags |= NO_RUINS
	var/turf_area = get_area(picked_turf)
	if(turf_area != cave_area)
		picked_turf.change_area(turf_area, cave_area)
	picked_turf.generating_biome = selected_cave_biome


/datum/map_generator/planet_generator/populate_terrain(list/turfs, area/generate_in, zone_band)

	var/start_time = REALTIMEOFDAY

	// Zone danger scaling: planets in dangerous overmap zones spawn denser and
	// meaner fauna. Preloaded planets populate during SSmapping init (before
	// SSovermap places them), so their zone comes from the band SSmapping dealt the
	// planet pair up front, placement honors it later (setup_planets). Dynamic
	// planets populate at load time instead, and pass their marker's live band in.
	// Decided once here so it costs nothing at runtime. Loot is never scaled.
	var/mob_chance_mult = 1
	var/mob_upgrade_prob = 0
	var/spawner_budget = ZONE_PLANET_SPAWNER_BUDGET_GREEN
	var/anomaly_budget = ZONE_PLANET_ANOMALY_BUDGET_GREEN
	// Megafauna are apex content and stay out of the shallow end entirely - a green-zone
	// planet is where a crew takes its first landing.
	var/megafauna_allowed = FALSE
	if(isnull(zone_band))
		// The area is the per-planet carrier: build_planet() stamps it before population
		// runs, and every planet gets its own area instances even when it shares a level.
		// Only roundstart planets, whose areas are never stamped, fall through to the
		// SSmapping registry - and that is asked with a turf, so it can consult the turf's
		// area before assuming the whole z-level belongs to one planet.
		var/area/overmap_encounter/planetoid/planetoid_area = generate_in
		if(istype(planetoid_area))
			zone_band = planetoid_area.zone_band
		if(isnull(zone_band) && length(turfs))
			var/turf/zone_sample = turfs[1]
			zone_band = SSmapping.get_planet_zone_band_for_turf(zone_sample)
	switch(zone_band)
		if(ZONE_YELLOW)
			mob_chance_mult = ZONE_PLANET_MOB_CHANCE_MULT_YELLOW
			mob_upgrade_prob = ZONE_PLANET_MOB_UPGRADE_PROB_YELLOW
			spawner_budget = ZONE_PLANET_SPAWNER_BUDGET_YELLOW
			anomaly_budget = ZONE_PLANET_ANOMALY_BUDGET_YELLOW
			megafauna_allowed = TRUE
		if(ZONE_RED)
			mob_chance_mult = ZONE_PLANET_MOB_CHANCE_MULT_RED
			mob_upgrade_prob = ZONE_PLANET_MOB_UPGRADE_PROB_RED
			spawner_budget = ZONE_PLANET_SPAWNER_BUDGET_RED
			anomaly_budget = ZONE_PLANET_ANOMALY_BUDGET_RED
			megafauna_allowed = TRUE

	// Structure spawners and megafauna are placed after the pass, not during it. Both are
	// permanent terrain outside SSplanet_mobs' cap, so both need a budget - and picking
	// them as we go would bunch them into the low corner of the map, because get_block()
	// hands us turfs in row-major order. Gather candidates, then choose from the whole set.
	var/list/spawner_candidates = list()
	var/list/megafauna_candidates = list()

	for(var/turf/target_turf as anything in turfs)

		if(!target_turf.generating_biome)
			continue

		var/datum/biome/selected_biome = target_turf.generating_biome
		// Reserved ground: the planet's landing strip (reserve_dock_strip() flags the berth
		// band plus PLANET_DOCK_HOSTILE_CLEARANCE) and any turf a ruin has claimed. Nothing
		// permanent and hostile may be banked here - a hivebot portal or an ash drake next to
		// a berth camps every crew that lands for the rest of the round, and neither is
		// managed by SSplanet_mobs, so neither ever despawns. Flora, ground features and
		// ordinary fauna are untouched; the fauna a crew meets on landing is kept off their
		// airlock by SSplanet_mobs instead, which knows where the hull actually is.
		var/hostile_spawns_reserved = (target_turf.turf_flags & NO_RUINS) ? TRUE : FALSE
		var/flora_allowed = selected_biome.flora_spawn_chance > 0 && length(selected_biome.flora_spawn_list) > 0 ? TRUE : FALSE
		var/fauna_allowed = selected_biome.mob_spawn_chance > 0 && length(selected_biome.mob_spawn_list) > 0 ? TRUE : FALSE
		var/feature_allowed = selected_biome.feature_spawn_chance > 0 && length(selected_biome.feature_spawn_list) > 0 ? TRUE : FALSE

		if(!(target_turf.type in selected_biome.open_turf_types)) //only put stuff on open turfs we generated, so closed walls and rivers and stuff are skipped
			continue

		// If we've spawned something yet
		var/spawned_something = FALSE

		if(!(target_turf.turf_flags & TURF_BLOCKS_POPULATE_TERRAIN_FLORAFEATURES))
			//FLORA SPAWNING HERE
			if(flora_allowed && prob(selected_biome.flora_spawn_chance))
				var/flora_type = pickweight(selected_biome.flora_spawn_list)
				new flora_type(target_turf)
				spawned_something = TRUE

			//FEATURE SPAWNING HERE
			//we may have generated something from the flora list on the target turf, so let's not place
			//a feature here if that's the case (because it would look stupid)
			if(feature_allowed && !spawned_something && prob(selected_biome.feature_spawn_chance))
				var/can_spawn = TRUE

				var/atom/picked_feature = pickweight(selected_biome.feature_spawn_list)

				// Don't place duplicate features
				for(var/obj/structure/existing_feature in range(7, target_turf))
					if(istype(existing_feature, picked_feature))
						can_spawn = FALSE
						break

				// Planets are a single z-level, so a cave ladder has nothing to link to
				// and would drop whoever used it into nowhere.
				if(ispath(picked_feature, /obj/structure/ladder))
					can_spawn = FALSE

				// Some biomes seed nests through the feature list rather than the mob list
				// (snow's demonic portals, wasteland's hivebot portals). They are the same
				// permanent, uncapped fauna source, so they share the same budget.
				if(can_spawn && ispath(picked_feature, /obj/structure/spawner))
					if(hostile_spawns_reserved)
						continue // not in the landing strip - see hostile_spawns_reserved
					spawner_candidates[target_turf] = picked_feature
					continue

				if(can_spawn)
					new picked_feature(target_turf)
					spawned_something = TRUE

		//MOB SPAWNING HERE
		if(fauna_allowed && !spawned_something && prob(selected_biome.mob_spawn_chance * mob_chance_mult))
			var/atom/picked_mob = pickweight(selected_biome.mob_spawn_list)
			if(!picked_mob)
				continue

			if(picked_mob == SPAWN_MEGAFAUNA)
				// Banked as a candidate rather than placed - see megafauna_candidates.
				// Green zones bank nothing, so the roll falls through to ordinary fauna.
				if(megafauna_allowed && !hostile_spawns_reserved && length(selected_biome.megafauna_spawn_list))
					megafauna_candidates[target_turf] = pickweight(selected_biome.megafauna_spawn_list)
					continue
				// Re-roll off the sentinel. Bounded: a table that is nothing but
				// SPAWN_MEGAFAUNA would spin here forever otherwise.
				for(var/attempt in 1 to 10)
					picked_mob = pickweight(selected_biome.mob_spawn_list)
					if(picked_mob != SPAWN_MEGAFAUNA)
						break
				if(picked_mob == SPAWN_MEGAFAUNA)
					continue

			// Zone danger scaling: some rolls upgrade to the biome's meaner tier. Megafauna
			// never reach this - they were banked above - so apex content stays untouched.
			if(mob_upgrade_prob && length(selected_biome.dangerous_mob_spawn_list) && prob(mob_upgrade_prob))
				picked_mob = pickweight(selected_biome.dangerous_mob_spawn_list)

			// Structure spawners are permanent terrain and are budgeted, so they are only
			// banked here. Everything else is ordinary fauna: the turf is registered as a
			// candidate and SSplanet_mobs populates it when players actually arrive, then
			// clears it again after they leave. On a z-level SSplanet_mobs isn't tracking,
			// register_spawn_turf() declines and the mob spawns here as it always did.
			// (This used to be istype(), which is always FALSE on a type path - so the
			// spawner branch never ran and tendrils placed themselves unbudgeted.)
			if(ispath(picked_mob, /obj/structure/spawner))
				if(hostile_spawns_reserved)
					continue // not in the landing strip - see hostile_spawns_reserved
				spawner_candidates[target_turf] = picked_mob
				continue

			// On a tracked z-level the turf is only registered, and SSplanet_mobs populates
			// it when players actually arrive. Otherwise (asteroid fields take this path)
			// the mob is placed here and now, and can clump - so that case, and only that
			// case, pays for the anti-clump scan. Nothing is standing on a planet
			// mid-build for it to find anyway, and range() over 450 turfs per roll is the
			// most expensive thing in this loop.
			if(SSplanet_mobs.register_spawn_turf(target_turf, picked_mob))
				spawned_something = TRUE
			else
				var/can_spawn = TRUE
				for(var/mob/living/mob_blocker in range(12, target_turf))
					can_spawn = FALSE
					break

				if(can_spawn)
					new picked_mob(target_turf)
					spawned_something = TRUE
		// The expensive half of a planet build - every iteration runs several range()
		// scans - and the one that most needs to stop hogging the tick. See
		// worldgen_yield() in worldgen_queue.dm. This loop's single iteration is the most
		// expensive of any worldgen sweep - several range() scans - so it takes a lower
		// forward-progress floor than the default, to keep its tick overshoot in line.
		SSovermap.worldgen_yield(throttled, min_iterations = 8)

	var/spawners_placed = place_budgeted_spawners(spawner_candidates, spawner_budget)
	var/megafauna_placed = place_planet_megafauna(megafauna_candidates)
	var/anomalies_placed = place_budgeted_anomalies(turfs, anomaly_budget)

	log_world("[name] terrain population finished in [(REALTIMEOFDAY - start_time)/10]s! \
		spawners [spawners_placed]/[length(spawner_candidates)] (budget [spawner_budget]), \
		megafauna [megafauna_placed]/[length(megafauna_candidates)], \
		anomalies [anomalies_placed] (budget [anomaly_budget])")

/**
 * Places up to `budget` structure spawners from the candidate turfs the terrain pass
 * banked, keeping them ZONE_PLANET_SPAWNER_SPACING apart.
 *
 * Candidates are drawn at random rather than in order: get_block() hands out turfs
 * row-major, so taking the first N would put every tendril on the planet in the same
 * corner. Returns how many were placed.
 */
/datum/map_generator/planet_generator/proc/place_budgeted_spawners(list/candidates, budget)
	if(!length(candidates) || budget <= 0)
		return 0

	var/list/available = candidates.Copy()
	var/list/placed_at = list()
	var/placed = 0

	while(placed < budget && length(available))
		var/turf/candidate = pick_n_take(available)
		if(!isturf(candidate) || candidate.density)
			continue

		var/too_close = FALSE
		for(var/turf/taken as anything in placed_at)
			if(get_dist(candidate, taken) < ZONE_PLANET_SPAWNER_SPACING)
				too_close = TRUE
				break
		if(too_close)
			continue

		var/spawner_type = candidates[candidate]
		new spawner_type(candidate)
		placed_at += candidate
		placed++
		CHECK_TICK

	return placed

/**
 * Seeds up to `budget` anomalies on the planet's open ground, keeping them
 * ZONE_PLANET_ANOMALY_SPACING apart. Returns how many were placed.
 *
 * Unlike spawners and megafauna this banks no candidates during the terrain pass. It
 * needs no biome table - any open ground will do - and that loop is already the expensive
 * half of a planet build, so it gets no extra work per turf. Turfs are drawn at random
 * instead: pick() is O(1), where walking the list in order would put every anomaly in the
 * low corner of the map, get_block() handing out turfs row-major.
 *
 * The draw is attempt-bounded rather than exhaustive. A planet whose open ground is
 * nearly all spoken for seeds fewer anomalies than its budget, which is the right way to
 * fail: this is optional scenery, not something worth stalling a build over.
 *
 * The landing strip is off limits, the same as it is to spawners and megafauna. A rejected
 * draw costs one of PLANET_ANOMALY_PLACEMENT_ATTEMPTS attempts and the budget is re-spent
 * on the next roll, so this moves anomalies off the berths rather than losing any. The
 * strip is the bottom 54 rows of a 123-row planet, so a bit under half the draws land in it
 * - against 400 attempts for a budget of at most three, which is not close to tight.
 */
/datum/map_generator/planet_generator/proc/place_budgeted_anomalies(list/turfs, budget)
	if(!length(turfs) || budget <= 0)
		return 0

	var/list/placed_at = list()
	var/placed = 0

	for(var/attempt in 1 to PLANET_ANOMALY_PLACEMENT_ATTEMPTS)
		if(placed >= budget)
			break

		var/turf/candidate = pick(turfs)
		if(!isturf(candidate) || candidate.density)
			continue

		// Reserved ground: the planet's landing strip (reserve_dock_strip() flags the berth
		// band plus PLANET_DOCK_HOSTILE_CLEARANCE) and any turf a ruin has claimed. An
		// anomaly is permanent, hostile and unmanaged by SSplanet_mobs, so one sitting on a
		// berth greets every crew that lands for the rest of the round - the same reason
		// populate_terrain() refuses to bank a spawner or a megafauna here.
		if(candidate.turf_flags & NO_RUINS)
			continue

		// The same rule the terrain pass uses for flora, features and fauna: only ground
		// this generator actually laid down. Keeps anomalies off rivers, lava and walls.
		var/datum/biome/candidate_biome = candidate.generating_biome
		if(!candidate_biome || !(candidate.type in candidate_biome.open_turf_types))
			continue

		// Don't bury one under a rock, a tendril or anything else the pass already placed.
		if((locate(/obj/structure) in candidate) || (locate(/mob/living) in candidate))
			continue

		var/too_close = FALSE
		for(var/turf/taken as anything in placed_at)
			if(get_dist(candidate, taken) < ZONE_PLANET_ANOMALY_SPACING)
				too_close = TRUE
				break
		if(too_close)
			continue

		var/anomaly_type = pickweight(GLOB.voidcrew_planet_anomalies)
		new anomaly_type(candidate)
		placed_at += candidate
		placed++
		CHECK_TICK

	return placed

/// Places a single megafauna from the banked candidates. One per planet, and only where
/// the zone band allows them at all - see megafauna_allowed in populate_terrain().
/datum/map_generator/planet_generator/proc/place_planet_megafauna(list/candidates)
	if(!length(candidates))
		return 0

	var/list/available = candidates.Copy()
	while(length(available))
		var/turf/candidate = pick_n_take(available)
		if(!isturf(candidate) || candidate.density)
			continue
		var/megafauna_type = candidates[candidate]
		new megafauna_type(candidate)
		return 1

	return 0
