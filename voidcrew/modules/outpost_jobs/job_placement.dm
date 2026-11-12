/**
 * # Outpost jobs: placement
 *
 * Owner: P2. Where a job's people and things go: the ambient loiter floor of the job's outpost (public concourse
 * floor that is not a passage, a doorway or beside one, the lift's clearance, the checkpoint or a back room), never
 * on top of furniture or a machine, out of every player's view where it can be (spec 4.2). No map landmarks (L17).
 *
 * Kinds:
 * - FIXER_SPOT_WALL: a tile with a wall on at least one side, for a safe, a rack or a machine.
 * - FIXER_SPOT_OPEN: room for three side by side. With `count` 1, a tile whose row of three is free; with a bigger
 *   `count`, that many free tiles in one straight line (the pallet's crates), in order.
 * - FIXER_SPOT_ARRIVE: public floor a few steps from the lift, for a visitor: never the lift itself, a doorway or
 *   a one-tile passage.
 *
 * Nothing waits: a stage() calls this inside the accept. When too few tiles are out of sight the rest are the seen
 * ones farthest from any player.
 */

/// ARRIVE tiles are at most this far from the lift
#define FIXER_ARRIVE_RANGE 4

/**
 * `count` free turfs of `kind` (FIXER_SPOT_WALL, FIXER_SPOT_OPEN or FIXER_SPOT_ARRIVE) on `outpost`'s public floor,
 * nearest `near` first when it is given, unseen by players. An empty list when there are not enough.
 */
/proc/fixer_job_spot(obj/structure/overmap/trader_outpost/outpost, kind, atom/near, count = 1)
	if(QDELETED(outpost) || count < 1)
		return list()
	var/list/candidates = fixer_job_spot_candidates(outpost, kind)
	if(!length(candidates))
		return list()
	var/list/watched = fixer_job_watched_turfs(outpost)
	var/turf/near_turf = get_turf(near)
	// A run of tiles for the pallet; one tile at a time for anything else
	var/list/options = list()
	if(kind == FIXER_SPOT_OPEN && count > 1)
		var/list/open = list()
		for(var/turf/tile as anything in candidates)
			open[tile] = TRUE
		for(var/turf/tile as anything in candidates)
			for(var/direction in list(EAST, NORTH))
				var/list/run = fixer_job_spot_run(tile, direction, count, open)
				if(run)
					options += list(run)
	else
		for(var/turf/tile as anything in candidates)
			options += list(list(tile))
	if(!length(options))
		return list()
	// Out of sight first (nearest `near` first, else in any order), then the seen ones farthest from a player
	var/list/unseen = list()
	var/list/seen = list()
	for(var/list/option as anything in shuffle(options))
		var/hidden = TRUE
		for(var/turf/tile as anything in option)
			if(watched[tile])
				hidden = FALSE
				break
		if(hidden)
			unseen += list(option)
		else
			seen += list(option)
	if(near_turf)
		var/list/near_keys = list()
		for(var/list/option as anything in unseen)
			near_keys += get_dist(option[1], near_turf)
		unseen = fixer_job_sort_options(unseen, near_keys)
	if(length(seen))
		var/list/players = fixer_job_players_near(outpost)
		var/list/far_keys = list()
		for(var/list/option as anything in seen)
			var/nearest = INFINITY
			for(var/mob/player as anything in players)
				nearest = min(nearest, get_dist(option[1], player))
			far_keys += -nearest // farthest first
		seen = fixer_job_sort_options(seen, far_keys)
	var/list/used = list()
	var/list/spots = list()
	for(var/list/option as anything in unseen + seen)
		if(length(spots) >= count)
			break
		var/clash = FALSE
		for(var/turf/tile as anything in option)
			if(used[tile])
				clash = TRUE
				break
		if(clash)
			continue
		for(var/turf/tile as anything in option)
			used[tile] = TRUE
			spots += tile
	if(length(spots) < count)
		return list()
	spots.Cut(count + 1)
	return spots

/// `options` reordered by `keys` (a number per option), smallest first; equal keys keep their order
/proc/fixer_job_sort_options(list/options, list/keys)
	var/list/sorted = list()
	var/list/sorted_keys = list()
	for(var/index in 1 to length(options))
		var/key = keys[index]
		var/at = length(sorted) + 1
		for(var/other in 1 to length(sorted_keys))
			if(key < sorted_keys[other])
				at = other
				break
		sorted.Insert(at, null)
		sorted[at] = options[index]
		sorted_keys.Insert(at, key)
	return sorted

/// `count` tiles from `tile` stepping `direction`, every one in `open`, or null
/proc/fixer_job_spot_run(turf/tile, direction, count, list/open)
	var/list/run = list(tile)
	var/turf/current = tile
	while(length(run) < count)
		current = get_step(current, direction)
		if(!current || !open[current])
			return null
		run += current
	return run

/// Every tile of `kind` at `outpost` free for a job's thing now, ignoring who can see it. Tests read it directly.
/proc/fixer_job_spot_candidates(obj/structure/overmap/trader_outpost/outpost, kind)
	. = list()
	var/datum/ambient_place/outpost/place = SSambient_npcs.outpost_place(outpost)
	if(!place)
		return
	switch(kind)
		if(FIXER_SPOT_WALL)
			for(var/turf/tile as anything in place.get_loiter_floor())
				if(!fixer_job_spot_free(tile, outpost))
					continue
				for(var/direction in GLOB.cardinals)
					var/turf/next = get_step(tile, direction)
					if(isclosedturf(next))
						. += tile
						break
		if(FIXER_SPOT_OPEN)
			var/list/loiter = place.get_loiter_floor()
			for(var/turf/tile as anything in loiter)
				if(!fixer_job_spot_free(tile, outpost))
					continue
				for(var/list/pair in list(list(EAST, WEST), list(NORTH, SOUTH)))
					var/turf/one = get_step(tile, pair[1])
					var/turf/two = get_step(tile, pair[2])
					if(one && two && loiter[one] && loiter[two] && fixer_job_spot_free(one, outpost) && fixer_job_spot_free(two, outpost))
						. += tile
						break
		if(FIXER_SPOT_ARRIVE)
			var/list/floor = place.get_public_floor()
			for(var/turf/tile as anything in floor)
				if(!fixer_job_spot_free(tile, outpost))
					continue
				var/by_lift = FALSE
				for(var/turf/alcove as anything in outpost.lobby_alcove_turfs)
					if(alcove.z == tile.z && get_dist(alcove, tile) <= FIXER_ARRIVE_RANGE)
						by_lift = TRUE
						break
				if(!by_lift || ambient_open_span(tile, floor) <= 1)
					continue
				var/by_door = FALSE
				for(var/direction in GLOB.cardinals)
					var/turf/next = get_step(tile, direction)
					if(next && (locate(/obj/machinery/door) in next))
						by_door = TRUE
						break
				if(!by_door)
					. += tile

/// Whether a job's thing may go on `tile`: open floor, nothing on it, no door, no furniture or machine, not the lift
/proc/fixer_job_spot_free(turf/tile, obj/structure/overmap/trader_outpost/outpost)
	if(!isopenturf(tile) || isspaceturf(tile) || tile.is_blocked_turf(exclude_mobs = FALSE))
		return FALSE
	if(tile in outpost.lobby_alcove_turfs)
		return FALSE
	if(istype(tile.loc, /area/voidcrew/trader_outpost/checkpoint))
		return FALSE
	if(locate(/obj/structure) in tile)
		return FALSE
	if(locate(/obj/machinery) in tile)
		return FALSE
	return TRUE

/// The players on `outpost`'s level
/proc/fixer_job_players_near(obj/structure/overmap/trader_outpost/outpost)
	. = list()
	var/turf/corner = outpost?.template_bottom_left
	if(!corner)
		return
	for(var/mob/player as anything in GLOB.player_list)
		var/turf/where = get_turf(player)
		if(where?.z == corner.z)
			. += player

/// Every turf a player on `outpost`'s level can see now (turf = TRUE)
/proc/fixer_job_watched_turfs(obj/structure/overmap/trader_outpost/outpost)
	. = list()
	for(var/mob/player as anything in fixer_job_players_near(outpost))
		for(var/turf/seen in view(world.view, player))
			.[seen] = TRUE

#undef FIXER_ARRIVE_RANGE
