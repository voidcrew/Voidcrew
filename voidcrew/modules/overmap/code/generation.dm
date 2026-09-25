/**
 * A chart layout without spawned atoms. Destinations, hazard budgets and navigation
 * are independent constraints; no routes or orbital shapes are reserved in advance.
 * The same planner is exercised by the layout tests and used to spawn the live chart.
 */
/datum/overmap_layout
	/// Turf -> zone band. Includes the outer corners, excludes looping boundaries.
	var/list/tiles = list()
	var/list/neighbors = list()
	var/list/band_sizes = list()
	/// Permanent obstacles, such as the star. Repair must never remove these.
	var/list/obstacles = list()
	var/list/destinations = list()
	var/list/destination_distances = list()
	/// Planned turf -> event type, instantiated only after navigation is validated.
	var/list/hazards = list()
	var/list/hazard_counts = list()
	var/list/hazard_targets = list()
	var/list/type_counts = list()
	var/repaired_tiles = 0
	/// Empty stretches are allowed; a large region without a destination is not preferred.
	var/max_destination_gap = 10
	var/destination_coverage_radius = 6
	var/min_destination_coverage = 0.95
	var/destination_layout_attempts = 12

/datum/overmap_layout/New(list/chart_turfs)
	. = ..()
	for(var/band in list(ZONE_GREEN, ZONE_YELLOW, ZONE_RED))
		band_sizes["[band]"] = 0
		hazard_counts["[band]"] = 0
		type_counts["[band]"] = list()
	for(var/turf/spot as anything in chart_turfs)
		var/band = SSovermap.get_zone_band_for_turf(spot)
		tiles[spot] = band
		band_sizes["[band]"]++
		destination_distances[spot] = INFINITY
	for(var/turf/spot as anything in tiles)
		var/list/adjacent = list()
		for(var/direction in shuffle(GLOB.cardinals.Copy()))
			var/turf/neighbor = get_step(spot, direction)
			if(tiles[neighbor])
				adjacent += neighbor
		neighbors[spot] = adjacent

/datum/overmap_layout/Destroy()
	tiles.Cut()
	neighbors.Cut()
	obstacles.Cut()
	destinations.Cut()
	destination_distances.Cut()
	hazards.Cut()
	return ..()

/datum/overmap_layout/proc/record_destination(turf/occupied, kind = "destination")
	if(!tiles[occupied])
		return
	destinations[occupied] = kind
	for(var/turf/spot as anything in tiles)
		var/dx = spot.x - occupied.x
		var/dy = spot.y - occupied.y
		destination_distances[spot] = min(destination_distances[spot], dx * dx + dy * dy)

/// Soft separation only: beyond four tiles every candidate has the same weight.
/// Hazards do not count as destinations and cannot attract contacts into their gaps.
/datum/overmap_layout/proc/pick_destination(band = null)
	var/list/weights = list()
	for(var/turf/spot as anything in tiles)
		if(obstacles[spot] || destinations[spot] || hazards[spot])
			continue
		if(!isnull(band) && tiles[spot] != band)
			continue
		if(get_dist(spot, SSovermap.overmap_centre) < 2)
			continue
		weights[spot] = clamp(destination_distances[spot], 1, 16)
	return length(weights) ? pick_weight(weights) : null

/// Sample complete layouts, rather than moving each contact to an exact gap center.
/// Keep the best candidate if a very small contact budget cannot meet normal coverage.
/datum/overmap_layout/proc/plan_destinations(amount, kind = "ruin")
	var/list/original_destinations = destinations.Copy()
	var/list/original_distances = destination_distances.Copy()
	var/list/best_destinations
	var/list/best_distances
	var/list/best_positions = list()
	var/best_penalty = INFINITY
	for(var/attempt in 1 to destination_layout_attempts)
		destinations = original_destinations.Copy()
		destination_distances = original_distances.Copy()
		var/list/positions = list()
		for(var/i in 1 to amount)
			var/turf/spot = pick_destination()
			if(!spot)
				break
			positions += spot
			record_destination(spot, kind)
		var/penalty = destination_coverage_penalty()
		if(!penalty)
			return positions
		if(penalty < best_penalty)
			best_penalty = penalty
			best_positions = positions
			best_destinations = destinations.Copy()
			best_distances = destination_distances.Copy()
		CHECK_TICK
	if(best_destinations)
		destinations = best_destinations
		destination_distances = best_distances
	return best_positions

/datum/overmap_layout/proc/destination_coverage_penalty()
	var/largest_gap = 0
	var/uncovered = 0
	for(var/turf/spot as anything in tiles)
		var/distance = destination_distances[spot]
		largest_gap = max(largest_gap, distance)
		if(distance > destination_coverage_radius * destination_coverage_radius)
			uncovered++
	return max(0, largest_gap - max_destination_gap * max_destination_gap) + max(0, uncovered - length(tiles) * (1 - min_destination_coverage))

/datum/overmap_layout/proc/can_place_hazard(turf/spot)
	if(!tiles[spot] || obstacles[spot] || destinations[spot] || hazards[spot])
		return FALSE
	if(get_dist(spot, SSovermap.overmap_centre) < 2)
		return FALSE
	var/key = "[tiles[spot]]"
	return hazard_counts[key] < hazard_targets[key]

/datum/overmap_layout/proc/add_hazard(turf/spot, event_type)
	hazards[spot] = event_type
	var/key = "[tiles[spot]]"
	hazard_counts[key]++
	var/list/tally = type_counts[key]
	tally[event_type]++

/datum/overmap_layout/proc/remove_hazard(turf/spot)
	var/event_type = hazards[spot]
	if(!event_type)
		return
	hazards -= spot
	var/key = "[tiles[spot]]"
	hazard_counts[key]--
	var/list/tally = type_counts[key]
	tally[event_type]--
	repaired_tiles++

/// Grow a small irregular patch. Shuffling directions prevents a compass-order bias.
/datum/overmap_layout/proc/grow_cluster(turf/seed, obj/structure/overmap/event/event_type)
	if(!can_place_hazard(seed))
		return
	add_hazard(seed, event_type)
	var/remaining = initial(event_type.max_cluster_size) - 1
	var/list/frontier = list(seed)
	var/list/depths = list()
	depths[seed] = 0
	var/list/considered = list()
	considered[seed] = TRUE
	while(length(frontier) && remaining > 0)
		var/turf/current = pick_n_take(frontier)
		var/depth = depths[current]
		if(depth >= 3)
			continue
		for(var/direction in shuffle(GLOB.alldirs.Copy()))
			var/turf/candidate = get_step(current, direction)
			if(!candidate || considered[candidate])
				continue
			considered[candidate] = TRUE
			var/dx = candidate.x - seed.x
			var/dy = candidate.y - seed.y
			if(dx * dx + dy * dy > 9 || !can_place_hazard(candidate))
				continue
			if(!prob(initial(event_type.spread_chance) * (0.6 ** depth)))
				continue
			add_hazard(candidate, event_type)
			frontier += candidate
			depths[candidate] = depth + 1
			remaining--
			if(remaining <= 0)
				break

/// Area budgets do not impose a pattern on individual rows, orbits, or bearings.
/datum/overmap_layout/proc/generate_hazards()
	var/list/bands = list(ZONE_GREEN, ZONE_YELLOW, ZONE_RED)
	var/list/pools = list()
	for(var/band in bands)
		var/key = "[band]"
		hazard_targets[key] = round(band_sizes[key] * (band == ZONE_GREEN ? 0.15 : 0.30))
		pools[key] = list()
	for(var/turf/spot as anything in tiles)
		var/list/pool = pools["[tiles[spot]]"]
		pool += spot
	var/list/guaranteed = shuffle(GLOB.overmap_event_guaranteed_list.Copy())
	var/list/open_bands = bands.Copy()
	while(length(open_bands))
		var/band = SSovermap.least_dense_band(open_bands, hazard_counts, hazard_targets)
		if(isnull(band))
			break
		var/key = "[band]"
		var/list/pool = pools[key]
		var/turf/seed
		while(length(pool))
			var/turf/candidate = pick_n_take(pool)
			if(can_place_hazard(candidate))
				seed = candidate
				break
		if(!seed)
			open_bands -= band
			continue
		var/event_type
		if(length(guaranteed))
			event_type = pick_n_take(guaranteed)
		else
			var/list/weights = GLOB.overmap_event_pick_list.Copy()
			var/list/tally = type_counts[key]
			for(var/path in weights)
				if(!tally[path])
					weights[path] *= 2
			event_type = pick_weight(weights)
		grow_cluster(seed, event_type)
		CHECK_TICK

	// Resource fields also need a clear adjacent tile from which to approach them.
	// Treat even nebulae as hazards here; safe navigation requires no event crossings.
	for(var/turf/spot as anything in shuffle(hazards.Copy()))
		if(!hazards[spot])
			continue
		var/has_approach = FALSE
		var/list/removable = list()
		for(var/turf/adjacent as anything in neighbors[spot])
			if(obstacles[adjacent])
				continue
			if(!hazards[adjacent])
				has_approach = TRUE
				break
			removable += adjacent
		if(!has_approach && length(removable))
			remove_hazard(pick(removable))

	if(!connect_clear_space())
		return FALSE
	return ensure_event_supply()

/// Repairs only remove hazards, so this converges. A cross-zone opening can expose
/// another pocket inside one band; recheck until both guarantees hold together.
/datum/overmap_layout/proc/connect_clear_space()
	while(TRUE)
		for(var/band in list(ZONE_GREEN, ZONE_YELLOW, ZONE_RED))
			if(band_sizes["[band]"] && !ensure_connected(band))
				return FALSE
		var/before = length(hazards)
		if(!ensure_connected())
			return FALSE
		if(length(hazards) == before)
			return TRUE

/datum/overmap_layout/proc/event_counts()
	var/list/counts = list()
	for(var/turf/spot as anything in hazards)
		counts[hazards[spot]]++
	return counts

/// Repairs may remove a rare type. Retype surplus tiles, without closing any routes.
/datum/overmap_layout/proc/ensure_event_supply()
	var/list/counts = event_counts()
	var/list/needed = list()
	for(var/path in GLOB.overmap_event_guaranteed_list)
		if(!counts[path])
			needed += path
	var/meteors = 0
	for(var/path in counts)
		if(ispath(path, /obj/structure/overmap/event/meteor))
			meteors += counts[path]
	while(length(needed) || meteors < MIN_OVERMAP_ASTEROID_FIELDS)
		var/replacement = length(needed) ? pick_n_take(needed) : /obj/structure/overmap/event/meteor
		var/turf/chosen
		for(var/turf/spot as anything in shuffle(hazards))
			var/old_type = hazards[spot]
			if(counts[old_type] <= 1)
				continue
			if(ispath(old_type, /obj/structure/overmap/event/meteor) && meteors <= MIN_OVERMAP_ASTEROID_FIELDS)
				continue
			chosen = spot
			break
		if(!chosen)
			return FALSE
		var/old_type = hazards[chosen]
		if(ispath(old_type, /obj/structure/overmap/event/meteor))
			meteors--
		if(ispath(replacement, /obj/structure/overmap/event/meteor))
			meteors++
		counts[old_type]--
		counts[replacement]++
		var/list/tally = type_counts["[tiles[chosen]]"]
		tally[old_type]--
		tally[replacement]++
		hazards[chosen] = replacement
	return TRUE

/datum/overmap_layout/proc/free_tiles(band = null)
	var/list/result = list()
	for(var/turf/spot as anything in tiles)
		if(!obstacles[spot] && !hazards[spot] && (isnull(band) || tiles[spot] == band))
			result += spot
	return result

/// Cardinal routes are valid even when diagonal corner-cutting is unavailable.
/// The values are path lengths plus one, so the origin is also truthy.
/datum/overmap_layout/proc/flood(turf/start, band = null)
	var/list/reached = list()
	if(!tiles[start] || obstacles[start] || hazards[start] || (!isnull(band) && tiles[start] != band))
		return reached
	reached[start] = 1
	var/head = 1
	while(head <= length(reached))
		var/turf/current = reached[head++]
		for(var/turf/adjacent as anything in neighbors[current])
			if(reached[adjacent] || obstacles[adjacent] || hazards[adjacent])
				continue
			if(!isnull(band) && tiles[adjacent] != band)
				continue
			reached[adjacent] = reached[current] + 1
	return reached

/**
 * Join disconnected clear regions by opening the thinnest intervening patch.
 * A multi-source search starts at EVERY reachable tile, not at the star. Thus a
 * repair opens a local passage rather than carving a radial road to a destination.
 */
/datum/overmap_layout/proc/ensure_connected(band = null)
	var/list/clear = free_tiles(band)
	if(!length(clear))
		return FALSE
	var/turf/start = pick(clear)
	while(TRUE)
		var/list/reached = flood(start, band)
		if(length(reached) == length(free_tiles(band)))
			return TRUE
		var/list/queue = shuffle(reached.Copy())
		var/list/visited = reached.Copy()
		var/list/parents = list()
		var/turf/connection
		var/head = 1
		while(head <= length(queue) && !connection)
			var/turf/current = queue[head++]
			for(var/turf/adjacent as anything in neighbors[current])
				if(visited[adjacent] || obstacles[adjacent])
					continue
				if(!isnull(band) && tiles[adjacent] != band)
					continue
				visited[adjacent] = TRUE
				parents[adjacent] = current
				if(!hazards[adjacent])
					connection = adjacent
					break
				queue += adjacent
		if(!connection)
			return FALSE // A permanent obstacle cannot be repaired by deleting hazards.
		while(!reached[connection])
			remove_hazard(connection)
			connection = parents[connection]
		CHECK_TICK

/datum/controller/subsystem/overmap/proc/get_overmap_layout(read_objects = TRUE)
	var/list/chart_turfs = list()
	for(var/turf/open/overmap/spot in block(locate(OVERMAP_LEFT_SIDE_COORD + 1, OVERMAP_SOUTH_SIDE_COORD + 1, OVERMAP_Z_LEVEL), locate(OVERMAP_RIGHT_SIDE_COORD - 1, OVERMAP_NORTH_SIDE_COORD - 1, OVERMAP_Z_LEVEL)))
		chart_turfs += spot
	var/datum/overmap_layout/layout = new(chart_turfs)
	layout.obstacles[overmap_centre] = TRUE
	if(read_objects)
		for(var/turf/spot as anything in layout.tiles)
			for(var/obj/structure/overmap/contact in spot)
				if(istype(contact, /obj/structure/overmap/star))
					layout.obstacles[spot] = TRUE
				else if(istype(contact, /obj/structure/overmap/event))
					layout.add_hazard(spot, contact.type)
				else if(!istype(contact, /obj/structure/overmap/ship))
					layout.record_destination(spot, "[contact.type]")
	return layout

/// Prefer the least occupied fraction, so the larger outer band receives its share.
/datum/controller/subsystem/overmap/proc/least_dense_band(list/bands, list/counts, list/sizes)
	var/lowest_density = INFINITY
	var/list/choices = list()
	for(var/band in bands)
		var/size = sizes["[band]"]
		if(size <= 0)
			continue
		var/density = counts["[band]"] / size
		if(density < lowest_density)
			lowest_density = density
			choices = list(band)
		else if(density == lowest_density)
			choices += band
	return length(choices) ? pick(choices) : null
