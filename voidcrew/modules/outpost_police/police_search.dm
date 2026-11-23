/**
 * # Outpost police: looking for someone
 *
 * Where officers go for a wanted person nobody has eyes on. Everything here starts from where the police last saw
 * them or were told they were, never from where they are (owner decision 52).
 *
 * Why it exists (owner playtest 4): two stars for an emagged gate, the suspect ran to the far wing, and nobody
 * came. Every officer had been sent to the last-seen tile, which was inside the scan chamber no NPC can walk into,
 * so the arresting officer never left its lift and the lift unit searched its own alcove. With a tile they could
 * reach they would still only ever have looked within five tiles of it.
 *
 * - The floor (/datum/outpost_police_floor): what an officer can walk to (outpost_police_flood(), the pathfinder's
 *   own rules), and the places a search stops at to look about, chosen so that every tile a visitor can get to is
 *   in sight of one (outpost_police_cover()). So no place is in a room only the police can enter, unless a visitor
 *   can climb into it. Read for the outpost's own floor, concourse and lobby together, and for each hangar; read
 *   again after POLICE_SEARCH_REREAD, as doors and crates move. Reading a floor walks every tile of it, so it is
 *   done over the next ticks (search_read_all()) and whoever needs a floor not read yet waits the moment it takes
 *   (search_pending()).
 * - The start (search_start()): the last-seen tile, or the nearest tile an officer can stand on when that one
 *   cannot be walked to or stood beside (a locked room, a ship's deck). For a checkpoint's scan chamber it is the
 *   side they can have left by: the concourse with the gate down or forced, the lobby with it working.
 * - The search (/datum/outpost_police_search): one for each wanted person, from their last sighting. Officers are
 *   dealt its places one each: the start first, then whichever is the shortest walk for that officer, the ones
 *   nearer the start before the ones further out. A place looked at is done, and with every place done it starts
 *   over. A new sighting starts a new search.
 * - Who asks: an officer sent to look (police_stealth.dm police_search_for()), the arresting officer of a case
 *   that has not found its suspect (respond_unseen() below), and dispatch, for the sector a wave comes up in
 *   (search_start()) and whether a unit still in its lift is shut in (search_shut_in()).
 */

/// Every tile a visitor can get to is within this many tiles, in a clear line, of a place the search stops at
#define POLICE_SEARCH_SIGHT 6
/// How much a place's distance from where the search starts counts against it, beside the officer's own walk there
#define POLICE_SEARCH_SPREAD 0.5
/// A place this near one just looked at was looked at with it
#define POLICE_SEARCH_NEAR 2
/// A stop of the beat is one of the places when this many tiles are in its sight that no place before it has
#define POLICE_SEARCH_STOP_WORTH 12
/// A floor is read again once it was read this long ago
#define POLICE_SEARCH_REREAD (2 MINUTES)
/// With nothing to stand on this near the last-seen tile, the search starts at the tile itself
#define POLICE_SEARCH_REACH 8
/// A place dealt to an officer who has not asked after it for this long is dealt again
#define POLICE_SEARCH_CLAIM (45 SECONDS)
/// How long the arresting officer of a case looks about at a place
#define POLICE_SEARCH_LOOK (4 SECONDS)
/// The arresting officer gives up a place it gets no nearer to in this long...
#define POLICE_SEARCH_PATIENCE (10 SECONDS)
/// ...or this long, when the way there is through the checkpoint or by a lift
#define POLICE_SEARCH_PATIENCE_FAR (40 SECONDS)
/// What a walk through the checkpoint or round by the exit gate adds to how far off a place counts for an officer
#define POLICE_SEARCH_CROSSING 16
/// The same for a place a lift ride away
#define POLICE_SEARCH_RIDE 60
/// A unit that can walk to fewer tiles than this from where it stands is shut in
#define POLICE_SEARCH_SHUT_IN 30

/// Whether `tile` is inside `box` (list(low x, low y, high x, high y, z))
#define POLICE_SEARCH_IN_BOX(tile, box) (tile.z == box[5] && tile.x >= box[1] && tile.y >= box[2] && tile.x <= box[3] && tile.y <= box[4])

// =========================================================================
// STATE
// =========================================================================

/datum/outpost_police
	/// The outpost's own floor as a search knows it, or null until one first asks (search_floor())
	var/datum/outpost_police_floor/search_main
	/// The hangars a search has got as far as
	var/list/datum/outpost_police_floor/search_hangars = list()
	/// The searches going on: mind -> /datum/outpost_police_search
	var/list/searches = list()
	/// Whether the floors are being read now (search_read_all())
	var/search_reading = FALSE
#ifdef UNIT_TESTS
	/// Whether a floor is read on the spot when it is asked for. On in tests, which do not wait; the live search tests turn it off.
	var/search_read_now = TRUE
#else
	/// Whether a floor is read on the spot when it is asked for. On in tests, which do not wait; the live search tests turn it off.
	var/search_read_now = FALSE
#endif

// Chains with police_core.dm's Destroy()
/datum/outpost_police/Destroy()
	QDEL_NULL(search_main)
	QDEL_LIST(search_hangars)
	QDEL_LIST_ASSOC_VAL(searches)
	return ..()

/mob/living/carbon/human/npc/ambient_npc/outpost/police
	/// The place a search has dealt them (/datum/outpost_police_search), or null
	var/turf/search_claim

/datum/outpost_police_case
	/// The place the arresting officer is looking for the suspect at (respond_unseen())
	var/turf/search_at
	/// world.time it is done looking about there, or 0 while it is on its way
	var/search_look_until = 0
	/// The nearest it has been to that place...
	var/search_best = INFINITY
	/// ...and world.time it last got nearer
	var/search_best_at = 0

/// A floor the police search: the outpost's own (concourse and lobby), or a hangar
/datum/outpost_police_floor
	/// Weakref to the hangar's berth; null for the outpost's own floor
	var/datum/weakref/berth_ref
	/// Tiles an officer can walk to: turf -> TRUE
	var/list/walkable = list()
	/// Where a search of it stops to look about
	var/list/turf/places = list()
	/// Where someone coming to it arrives: a tile of its lift alcove, or null
	var/turf/entry
	/// world.time it was read
	var/read_at = 0
	/// The last tile reach() was asked about, and its answer
	var/turf/reach_of
	var/turf/reach_is

/datum/outpost_police_floor/Destroy()
	berth_ref = null
	walkable = null
	places = null
	entry = null
	reach_of = null
	reach_is = null
	return ..()

/**
 * Where a search for someone last seen at `last` starts on this floor: `last` itself when an officer can stand on it
 * or right beside it (the walk ends beside a tile it cannot step on), else the nearest tile one can stand on, in
 * sight of `last` before out of sight of it. Null with none within POLICE_SEARCH_REACH.
 */
/datum/outpost_police_floor/proc/reach(turf/last)
	if(!last)
		return null
	if(walkable[last])
		return last
	if(last == reach_of)
		return reach_is
	reach_of = last
	reach_is = null
	for(var/ring in 1 to POLICE_SEARCH_REACH)
		var/turf/best
		var/best_score = INFINITY
		for(var/turf/near as anything in RANGE_TURFS(ring, last))
			if(get_dist(near, last) != ring || !walkable[near])
				continue
			var/score = (near.x - last.x) ** 2 + (near.y - last.y) ** 2
			if(!stealth_can_see(near, last, ring))
				score += 1000
			if(score < best_score)
				best = near
				best_score = score
		if(best)
			reach_is = ring == 1 ? last : best
			break
	return reach_is

/// The search for one wanted person since they were last seen
/datum/outpost_police_search
	/// The sighting it started from (the warrant's last_seen_at)
	var/stamp = 0
	/// Where it starts (/datum/outpost_police_floor/proc/reach())
	var/turf/start
	/// Places looked at since: turf -> TRUE
	var/list/done = list()
	/// Places dealt and not yet looked at: turf -> list(weakref to the officer, world.time it last asked)
	var/list/claims = list()
	/// Places an officer was dealt and could not get to: turf -> list of weakrefs to those officers. Not theirs again, and not looked at.
	var/list/refused = list()

/datum/outpost_police_search/New(new_stamp, turf/new_start)
	. = ..()
	stamp = new_stamp
	start = new_start

/datum/outpost_police_search/Destroy()
	start = null
	done = null
	claims = null
	refused = null
	return ..()

/// Whether `place` is free for `officer`: not looked at, and nobody else on their way to it
/datum/outpost_police_search/proc/open_to(turf/place, mob/living/carbon/human/npc/ambient_npc/outpost/police/officer)
	if(done[place])
		return FALSE
	var/list/gave_up = refused[place]
	if(gave_up && (WEAKREF(officer) in gave_up))
		return FALSE
	var/list/claim = claims[place]
	if(!claim)
		return TRUE
	var/datum/weakref/holder_ref = claim[1]
	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/holder = holder_ref?.resolve()
	if(holder == officer)
		return TRUE
	if(QDELETED(holder) || holder.stat != CONSCIOUS || holder.search_claim != place || world.time - claim[2] >= POLICE_SEARCH_CLAIM)
		claims -= place
		return TRUE
	return FALSE

/// `officer` has `place` from now
/datum/outpost_police_search/proc/take(turf/place, mob/living/carbon/human/npc/ambient_npc/outpost/police/officer)
	var/turf/old = officer.search_claim
	if(old && old != place)
		var/list/old_claim = claims[old]
		var/datum/weakref/old_ref = old_claim?[1]
		if(old_ref?.resolve() == officer)
			claims -= old
	officer.search_claim = place
	claims[place] = list(WEAKREF(officer), world.time)
	return place

/**
 * The place `officer` looks at next: the one it has, until it has looked there; else the start, then the places
 * of the floor the search started on, the shortest walk for it first and those nearer the start before those
 * further out; then the other floors (a hangar only for a response unit or an officer on an arrest, who are all
 * that ride to one). With every place it could be given looked at, the search starts over. Null when there is
 * nowhere to send it at all.
 */
/datum/outpost_police_search/proc/deal(datum/outpost_police/police, mob/living/carbon/human/npc/ambient_npc/outpost/police/officer)
	var/turf/mine = officer.search_claim
	if(mine && !done[mine])
		var/list/claim = claims[mine]
		var/datum/weakref/holder_ref = claim?[1]
		if(holder_ref?.resolve() == officer)
			claim[2] = world.time
			return mine
	for(var/pass in 1 to 2)
		var/turf/found = pick_place(police, officer)
		if(found)
			return take(found, officer)
		// Nothing left but places it could not get to (it is shut in somewhere): they are its own to try again, and
		// what the others have looked at stays looked at
		var/datum/weakref/own_ref = WEAKREF(officer)
		var/gave_up_any = FALSE
		for(var/turf/place as anything in refused)
			var/list/gave_up = refused[place]
			if(own_ref in gave_up)
				gave_up -= own_ref
				gave_up_any = TRUE
		if(gave_up_any)
			break
		// Everywhere it could go has been looked at: again from the start
		if(!length(done))
			break
		done.Cut()
		refused.Cut()
	return null

/// One pass of deal() over the floors, in the order a search takes them
/datum/outpost_police_search/proc/pick_place(datum/outpost_police/police, mob/living/carbon/human/npc/ambient_npc/outpost/police/officer)
	var/turf/here = get_turf(officer)
	if(!here || !start)
		return null
	// Who is taken to a hangar: a response unit (police_stealth.dm stealth_walk()), and anyone on an arrest, whose
	// walk rides the lift whatever they are (police_arrest.dm route_to())
	var/rides = police.dispatch_is_response_unit(officer) || !isnull(officer.case)
	var/datum/outpost_police_floor/first = police.search_floor(start, officer)
	var/datum/outpost_police_floor/own = police.search_floor(here, officer)
	var/here_sector = police.sector_of(here)
	var/start_sector = police.sector_of(start)
	for(var/entry in police.search_floors(first, officer, rides))
		// A hangar is read when the search gets as far as it, and no sooner
		var/datum/outpost_berth/unread = entry
		var/datum/outpost_police_floor/floor = istype(unread) ? police.search_floor(unread.get_bottom_left(), officer) : entry
		if(!floor)
			continue
		// A hangar is for an officer that rides to one, or one that stands in it already
		if(floor.berth_ref && !rides && floor != own)
			continue
		// Nobody has looked where they were last seen yet: that comes first
		if(floor == first && open_to(start, officer))
			return start
		var/turf/anchor = floor == first ? start : floor.entry
		var/anchor_sector = floor == first ? start_sector : (anchor ? police.sector_of(anchor) : null)
		var/turf/best
		var/best_score = INFINITY
		for(var/turf/place as anything in floor.places)
			if(!open_to(place, officer))
				continue
			var/place_sector = floor.berth_ref ? null : police.sector_of(place)
			// The walk there for this officer...
			var/score
			if(floor != own)
				score = POLICE_SEARCH_RIDE + (floor.entry ? get_dist(floor.entry, place) : 0)
			else
				score = get_dist(here, place)
				if(!floor.berth_ref && place_sector != here_sector)
					score += POLICE_SEARCH_CROSSING
			// ...and, at half weight, how far the search has spread to get there: outward from the start, on foot, so
			// the lobby is a long way from the concourse
			if(anchor)
				var/spread = get_dist(anchor, place)
				if(!floor.berth_ref && place_sector != anchor_sector)
					spread += POLICE_SEARCH_CROSSING
				score += spread * POLICE_SEARCH_SPREAD
			if(score < best_score)
				best = place
				best_score = score
		if(best)
			return best
	return null

/**
 * `officer` is finished with the place it was dealt, having looked about from `center` (null: it never got anywhere).
 * From the place or right by it, the place is done, and so is any other that near `center`. From further off (no way
 * there), the place is not done: it goes to another officer.
 */
/datum/outpost_police_search/proc/looked(datum/outpost_police/police, mob/living/carbon/human/npc/ambient_npc/outpost/police/officer, turf/center)
	var/turf/mine = officer?.search_claim
	if(mine)
		var/list/claim = claims[mine]
		var/datum/weakref/holder_ref = claim?[1]
		if(holder_ref?.resolve() == officer)
			claims -= mine
			if(center && center.z == mine.z && get_dist(center, mine) <= POLICE_SEARCH_NEAR)
				done[mine] = TRUE
			else
				var/list/gave_up = refused[mine]
				if(!gave_up)
					gave_up = list()
					refused[mine] = gave_up
				gave_up |= WEAKREF(officer)
		officer.search_claim = null
	if(!center)
		return
	var/list/turf/known = list(start)
	if(police.search_main)
		known += police.search_main.places
	for(var/datum/outpost_police_floor/hangar as anything in police.search_hangars)
		known += hangar.places
	for(var/turf/place as anything in known)
		if(place && place.z == center.z && get_dist(place, center) <= POLICE_SEARCH_NEAR)
			done[place] = TRUE

// =========================================================================
// READING A FLOOR
// =========================================================================

/**
 * Every tile that can be walked to from `seeds` without leaving `box`, by the pathfinder's own rules for `walker`
 * carrying `access`. A null walker is a visitor: someone with no keys who works the checkpoint's doors as a
 * player does and climbs over a counter. `skip` (turf -> TRUE) is never entered.
 * Returns turf -> TRUE in the order found, `limit` tiles at most. `yields`: it gives way when the tick is used up
 * (only from a proc that may sleep), and returns null if `walker` is gone by the time it is back.
 */
/proc/outpost_police_flood(list/turf/seeds, list/box, mob/living/walker, list/access, list/skip, limit = INFINITY, yields = FALSE)
	var/list/found = list()
	if(length(box) < 5)
		return found
	var/datum/can_pass_info/pass = new(walker, access || list())
	if(isnull(walker))
		pass.pass_flags |= PASSTABLE
	var/list/turf/frontier = list()
	for(var/turf/seed as anything in seeds)
		if(!isopenturf(seed) || found[seed] || skip?[seed] || !POLICE_SEARCH_IN_BOX(seed, box))
			continue
		found[seed] = TRUE
		frontier += seed
	var/at = 1
	while(at <= length(frontier) && length(frontier) < limit)
		if(yields)
			CHECK_TICK
			// The checkpoint's doors tell an NPC by the walker itself: without it the rest would be a visitor's floor
			if(walker && QDELETED(walker))
				return null
		var/turf/here = frontier[at]
		at++
		for(var/direction in GLOB.cardinals)
			var/turf/next = get_step(here, direction)
			if(!next || found[next] || skip?[next] || !POLICE_SEARCH_IN_BOX(next, box))
				continue
			if(!CAN_STEP(here, next, TRUE, pass, null))
				continue
			found[next] = TRUE
			frontier += next
	return found

/// The tiles of `public` (turf -> TRUE) within POLICE_SEARCH_SIGHT of `from`, in a clear line, that `covered` does not have yet
/proc/outpost_police_in_sight(turf/from, list/public, list/covered)
	. = list()
	for(var/turf/tile as anything in RANGE_TURFS(POLICE_SEARCH_SIGHT, from))
		if(public[tile] && !covered[tile] && stealth_can_see(from, tile, POLICE_SEARCH_SIGHT))
			. += tile

/**
 * The places a search stops at so that every tile of `public` is in sight of one, each of them a tile of
 * `walkable`: the beat's own `stops` where they show enough that is new (the mappers already have officers stand
 * there), then one for every tile still out of sight, on the tile itself or, where no officer can stand on it (a
 * shop's far side of the counter), the nearest tile that sees it.
 */
/proc/outpost_police_cover(list/public, list/walkable, list/turf/stops, yields = FALSE)
	var/list/turf/places = list()
	var/list/covered = list()
	for(var/turf/stop as anything in stops)
		if(yields)
			CHECK_TICK
		if(!walkable[stop])
			continue
		var/list/turf/shown = outpost_police_in_sight(stop, public, covered)
		if(length(shown) < POLICE_SEARCH_STOP_WORTH)
			continue
		places += stop
		for(var/turf/tile as anything in shown)
			covered[tile] = TRUE
	for(var/turf/tile as anything in public)
		if(covered[tile])
			continue
		if(yields)
			CHECK_TICK
		covered[tile] = TRUE
		var/turf/stand = walkable[tile] ? tile : null
		if(!stand)
			for(var/ring in 1 to POLICE_SEARCH_SIGHT)
				for(var/turf/near as anything in RANGE_TURFS(ring, tile))
					if(get_dist(near, tile) == ring && walkable[near] && stealth_can_see(near, tile, POLICE_SEARCH_SIGHT))
						stand = near
						break
				if(stand)
					break
		// Nowhere an officer can stand sees it: nothing to send anyone to
		if(!stand)
			continue
		places |= stand
		for(var/turf/shown as anything in outpost_police_in_sight(stand, public, covered))
			covered[shown] = TRUE
	return places

/// The corners of the outpost's own floor, or of `berth`'s hangar, as list(low x, low y, high x, high y, z); null if it has no ground
/datum/outpost_police/proc/search_box(datum/outpost_berth/berth)
	var/turf/low
	var/turf/high
	if(berth)
		low = berth.get_bottom_left()
		high = berth.get_top_right()
	else if(outpost?.template_bottom_left && outpost.outpost_template)
		low = outpost.template_bottom_left
		high = locate(min(world.maxx, low.x + outpost.outpost_template.width - 1), min(world.maxy, low.y + outpost.outpost_template.height - 1), low.z)
	if(!low || !high)
		return null
	return list(low.x, low.y, high.x, high.y, low.z)

/// An officer whose legs a floor is read for: `officer` if it is one of ours on its feet, else any that is; null with none
/datum/outpost_police/proc/search_walker(mob/living/officer)
	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/asked = officer
	if(istype(asked) && !QDELETED(asked) && asked.stat != DEAD && !asked.client && !asked.mind)
		return asked
	for(var/mob/living/carbon/human/npc/ambient_npc/outpost/police/other in officers)
		if(other.stat != DEAD && !other.client && !other.mind)
			return other
	return null

/// The floor `berth`'s hangar was last read as, or null
/datum/outpost_police/proc/search_hangar(datum/outpost_berth/berth)
	for(var/datum/outpost_police_floor/floor as anything in search_hangars.Copy())
		var/datum/outpost_berth/its = floor.berth_ref?.resolve()
		if(QDELETED(its) || !(its in outpost?.berths))
			search_hangars -= floor
			qdel(floor)
			continue
		if(its == berth)
			return floor
	return null

/**
 * The floor `where` is on, read now if it never was or was read long ago: the outpost's own for anywhere in its box,
 * a hangar for anywhere on a berth's ground. Null anywhere else, and before any officer exists to read it for.
 */
/datum/outpost_police/proc/search_floor(turf/where, mob/living/officer)
	var/turf/spot = get_turf(where)
	if(!spot || !outpost)
		return null
	var/datum/outpost_berth/berth
	if(!dispatch_in_box(spot))
		berth = sector_of(spot)
		if(!istype(berth))
			return null
	var/datum/outpost_police_floor/floor = berth ? search_hangar(berth) : search_main
	if(floor && world.time - floor.read_at < POLICE_SEARCH_REREAD)
		return floor
	var/mob/living/walker = search_walker(officer)
	if(!walker)
		return floor
	if(search_read_now)
		var/datum/outpost_police_floor/fresh = search_read(berth, walker)
		if(fresh)
			search_keep(berth, fresh)
		return fresh || floor
	// Over the next ticks: the one read before serves meanwhile, and with none yet the asker waits (search_pending())
	if(!search_reading)
		search_reading = TRUE
		INVOKE_ASYNC(src, PROC_REF(search_read_all), walker)
	// With time to spare in this tick it is read already
	return berth ? search_hangar(berth) : search_main

/// `fresh` is the floor of `berth`'s hangar (null: the outpost's own) from now
/datum/outpost_police/proc/search_keep(datum/outpost_berth/berth, datum/outpost_police_floor/fresh)
	var/datum/outpost_police_floor/old = berth ? search_hangar(berth) : search_main
	if(berth)
		if(old)
			search_hangars -= old
		search_hangars += fresh
	else
		search_main = fresh
	if(old && old != fresh)
		qdel(old)

/**
 * Reads every floor that is due, the outpost's own first and then each hangar with ground under it, giving way
 * between tiles so no tick pays for it. Hangars are read with the rest so that one is ready by the time a search
 * has worked through the concourse to it. Sleeps.
 */
/datum/outpost_police/proc/search_read_all(mob/living/walker)
	var/list/berths = list(null)
	for(var/datum/outpost_berth/berth as anything in outpost?.berths)
		if(berth?.get_bottom_left() && length(berth.alcove_turfs))
			berths += berth
	for(var/datum/outpost_berth/berth as anything in berths)
		if(QDELETED(walker))
			break
		if(berth && (QDELETED(berth) || !(berth in outpost?.berths)))
			continue
		var/datum/outpost_police_floor/old = berth ? search_hangar(berth) : search_main
		if(old && world.time - old.read_at < POLICE_SEARCH_REREAD)
			continue
		var/datum/outpost_police_floor/fresh = search_read(berth, walker, TRUE)
		if(QDELETED(src))
			if(fresh)
				qdel(fresh)
			return
		if(fresh)
			search_keep(berth, fresh)
	search_reading = FALSE

/**
 * Whether the floor `where` is on has never been read and is being read now: whoever needs it waits the moment that
 * takes. Asking starts the reading.
 */
/datum/outpost_police/proc/search_pending(turf/where, mob/living/officer)
	if(!where || search_floor(where, officer))
		return FALSE
	return search_reading

/**
 * The floors a search goes through, in order: `first` (the one it started on), the outpost's own floor, then, for
 * a `rider` (an officer who is taken to hangars), each hangar with ground under it. A hangar is given as its berth:
 * whoever gets that far down the list reads it then (search_floor()), so a search of the concourse reads none.
 */
/datum/outpost_police/proc/search_floors(datum/outpost_police_floor/first, mob/living/walker, rider = FALSE)
	. = list()
	if(first)
		. += first
	var/datum/outpost_police_floor/main = outpost?.template_bottom_left ? search_floor(outpost.template_bottom_left, walker) : null
	if(main)
		. |= main
	if(!rider)
		return
	var/datum/outpost_berth/first_berth = first?.berth_ref?.resolve()
	for(var/datum/outpost_berth/berth as anything in outpost?.berths)
		if(!berth || berth == first_berth || !berth.get_bottom_left() || !length(berth.alcove_turfs))
			continue
		. += berth

/// Reads the outpost's own floor (`berth` null) or `berth`'s hangar for `walker`. Null if it has no ground, or (`yields`: it gives way between tiles, and sleeps) if the walker or the police went meanwhile.
/datum/outpost_police/proc/search_read(datum/outpost_berth/berth, mob/living/walker, yields = FALSE)
	var/list/box = search_box(berth)
	if(!box || !walker)
		return null
	var/list/turf/seeds = list()
	var/list/turf/stops = list()
	var/list/skip
	if(berth)
		seeds += berth.alcove_turfs
		// Never a docked ship's own decks: officers hold its airlock, they do not go aboard (dispatch_update_holds())
		var/list/turf/hull = berth.ship?.shuttle?.return_turfs()
		if(length(hull))
			skip = list()
			for(var/turf/deck as anything in hull)
				skip[deck] = TRUE
	else
		for(var/turf/stop as anything in stop_activities)
			stops += stop
		seeds += stops
		if(length(outpost.lobby_alcove_turfs))
			seeds += outpost.lobby_alcove_turfs
	// A floor with no stops and no lift (a test's room): wherever the officer stands
	if(!length(seeds))
		seeds += get_turf(walker)
	var/datum/outpost_police_floor/floor = new
	floor.berth_ref = berth ? WEAKREF(berth) : null
	floor.read_at = world.time
	floor.walkable = outpost_police_flood(seeds, box, walker, walker.get_access(), skip, INFINITY, yields)
	var/list/public = floor.walkable ? outpost_police_flood(seeds, box, null, null, skip, INFINITY, yields) : null
	if(!public || QDELETED(src) || QDELETED(walker) || !outpost || (berth && QDELETED(berth)))
		qdel(floor)
		return null
	var/list/turf/alcove = berth ? berth.alcove_turfs : outpost.lobby_alcove_turfs
	for(var/turf/tile as anything in alcove)
		if(floor.walkable[tile])
			floor.entry = tile
			break
	// Whoever stands in a scan chamber is seen by its scanner (police_perception.dm scanned())
	for(var/checkpoint_id in outpost.checkpoints)
		var/datum/outpost_checkpoint/post = outpost.checkpoints[checkpoint_id]
		if(QDELETED(post))
			continue
		for(var/turf/tile as anything in post.chamber_turfs)
			public -= tile
		public -= get_turf(post.inner_door)
		public -= get_turf(post.outer_door)
	floor.places = outpost_police_cover(public, floor.walkable, stops, yields)
	if(QDELETED(src))
		qdel(floor)
		return null
	return floor

// =========================================================================
// THE API
// =========================================================================

/**
 * Where a search for someone last seen at `last` starts: `last`, or the nearest tile an officer can stand on
 * (/datum/outpost_police_floor/proc/reach()). In a checkpoint's scan chamber or one of its doorways, which no NPC
 * walks into, it is the side they can have left by: with the gate down or forced that is the concourse, where a
 * gate-crasher is headed; with it working the inner door never opened for someone wanted, so it is the lobby.
 * `last` itself where the floor is not known.
 */
/datum/outpost_police/proc/search_start(turf/last, mob/living/officer)
	if(!last)
		return null
	var/datum/outpost_police_floor/floor = search_floor(last, officer)
	if(!floor)
		return last
	if(!floor.berth_ref && !floor.walkable[last])
		for(var/checkpoint_id in outpost?.checkpoints)
			var/datum/outpost_checkpoint/post = outpost.checkpoints[checkpoint_id]
			if(QDELETED(post) || QDELETED(post.inner_door) || QDELETED(post.outer_door))
				continue
			if(!(last in post.chamber_turfs) && last != get_turf(post.inner_door) && last != get_turf(post.outer_door))
				continue
			var/through = post.is_disabled() || post.state == CHECKPOINT_FORCED || !post.inner_door.density
			for(var/turf/side as anything in (through ? list(post.secured_turf, post.lobby_turf) : list(post.lobby_turf, post.secured_turf)))
				if(side && floor.walkable[side])
					return side
			break
	return floor.reach(last) || last

/**
 * Where `officer` goes to look for `warrant`'s holder now. With someone's eyes on them this moment (an officer, a
 * scan): where they are seen. Else the next place of the search since they were last seen. Null with no sighting
 * to start from: nobody is sent to look for someone nobody has seen (owner decision 52).
 */
/datum/outpost_police/proc/search_place(datum/outpost_warrant/warrant, mob/living/carbon/human/npc/ambient_npc/outpost/police/officer)
	var/turf/last = warrant?.last_seen_turf
	if(!last)
		return null
	// Off every floor the police know (carried away aboard a ship): the tile itself
	if(!search_floor(last, officer))
		return last
	var/turf/start = search_start(last, officer)
	// Someone has eyes on them now: straight to where they are seen
	if(!warrant.unseen_since || !istype(officer) || !warrant.mind)
		return start
	var/datum/outpost_police_search/search = searches[warrant.mind]
	if(!search || search.stamp != warrant.last_seen_at || search.start != start)
		search_prune()
		if(search)
			searches -= warrant.mind
			qdel(search)
		search = new(warrant.last_seen_at, start)
		searches[warrant.mind] = search
	return search.deal(src, officer) || start

/// `officer` has looked about at `center` for `warrant`'s holder and not found them
/datum/outpost_police/proc/search_looked(datum/outpost_warrant/warrant, mob/living/carbon/human/npc/ambient_npc/outpost/police/officer, turf/center)
	var/datum/outpost_police_search/search = warrant?.mind ? searches[warrant.mind] : null
	if(search)
		search.looked(src, officer, center)
	else if(officer)
		officer.search_claim = null

/// Drops the searches for people no longer wanted here
/datum/outpost_police/proc/search_prune()
	for(var/datum/mind/mind as anything in searches.Copy())
		if(mind && get_stars(mind) >= 1)
			continue
		var/datum/outpost_police_search/search = searches[mind]
		searches -= mind
		qdel(search)

/**
 * Whether `officer` cannot walk more than a few tiles from where it stands, with its own keys: something is across
 * its lift's door (abuse M2). A unit that has not moved because it has nowhere to go is not shut in.
 */
/datum/outpost_police/proc/search_shut_in(mob/living/officer)
	var/turf/here = get_turf(officer)
	if(!here)
		return FALSE
	var/datum/outpost_berth/berth
	if(!dispatch_in_box(here))
		berth = sector_of(here)
		if(!istype(berth))
			return FALSE
	var/list/box = search_box(berth)
	if(!box)
		return FALSE
	return length(outpost_police_flood(list(here), box, officer, officer.get_access(), null, POLICE_SEARCH_SHUT_IN)) < POLICE_SEARCH_SHUT_IN

// =========================================================================
// THE ARREST THAT HAS NOT FOUND ITS SUSPECT
// =========================================================================

/**
 * Respond (police_arrest.dm step_respond()) with the suspect out of the arresting officer's sight. Seen by someone
 * else: to where they are seen. Seen by nobody: to the place the search deals it, a look about there, then the
 * next one. It used to walk to the last-seen tile and wait there for the step to time out.
 */
/datum/outpost_police_case/proc/respond_unseen(mob/living/carbon/human/npc/ambient_npc/outpost/police/officer, mob/living/carbon/suspect)
	// The floor is still being read (the first second of the first hunt): a moment
	if(police.search_pending(warrant.last_seen_turf, officer))
		set_goal(null)
		return
	var/turf/place = police.search_place(warrant, officer)
	if(!place)
		// No sighting to start from (an accomplice nobody saw): as it was
		search_at = null
		route_to(officer, warrant.last_seen_turf || get_turf(suspect), 1)
		return
	if(!warrant.unseen_since)
		search_at = null
		route_to(officer, place, 1)
		return
	var/turf/here = get_turf(officer)
	if(place != search_at)
		search_at = place
		search_look_until = 0
		search_best = INFINITY
		search_best_at = world.time
	if(search_look_until)
		if(world.time < search_look_until)
			var/datum/ai_controller/basic_controller/human_npc/stealth/brain = officer.ai_controller
			if(istype(brain))
				brain.stealth_turn_to(turn(stealth_facing(officer), 90))
			return
		// Not here: the next place, dealt at the next step
		police.search_looked(warrant, officer, here)
		search_at = null
		return
	if(route_to(officer, place, 1))
		search_look_until = world.time + POLICE_SEARCH_LOOK
		return
	// No nearer for a while (a crate across the way, a door that will not open): the next place
	var/dist = (here && here.z == place.z) ? get_dist(here, place) : INFINITY
	if(dist < search_best)
		search_best = dist
		search_best_at = world.time
		return
	var/far = !here || here.z != place.z || police.sector_of(here) != police.sector_of(place)
	if(world.time - search_best_at >= (far ? POLICE_SEARCH_PATIENCE_FAR : POLICE_SEARCH_PATIENCE))
		police.search_looked(warrant, officer, null)
		search_at = null

#undef POLICE_SEARCH_SIGHT
#undef POLICE_SEARCH_SPREAD
#undef POLICE_SEARCH_NEAR
#undef POLICE_SEARCH_STOP_WORTH
#undef POLICE_SEARCH_REREAD
#undef POLICE_SEARCH_REACH
#undef POLICE_SEARCH_CLAIM
#undef POLICE_SEARCH_LOOK
#undef POLICE_SEARCH_PATIENCE
#undef POLICE_SEARCH_PATIENCE_FAR
#undef POLICE_SEARCH_CROSSING
#undef POLICE_SEARCH_RIDE
#undef POLICE_SEARCH_SHUT_IN
#undef POLICE_SEARCH_IN_BOX
