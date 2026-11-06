/// Backgrounds: owned by P6. See data/backgrounds/spec.md.

/**
 * # The homestead
 *
 * One datum for the one homestead, made when the template is stamped (frontier_before_ruins()) and
 * ticking every BACKGROUND_HOMESTEAD_NEEDS_INTERVAL on SSprocessing from homestead_after_atoms().
 * Each tick:
 * - the needs (this file): fed is food in the house fridge and on the kitchen tables, counted up to
 *   BACKGROUND_HOMESTEAD_FOOD_MIN and no further; safe is no hostile creature within
 *   BACKGROUND_HOMESTEAD_SAFE_RANGE of the house, from the spatial grid, never a turf scan (PERF-2).
 *   A change is said once, out loud, by one of the family;
 * - the family (homestead_family.dm): the leash, greetings, hiding;
 * - the homesteaders (homestead_background.dm): where they are, for the departure rule (MOV-2);
 * - the raids (homestead_raids.dm).
 *
 * Tests make their own homestead over a test room and call these procs directly with `paused` set.
 */

GLOBAL_DATUM(homestead, /datum/homestead)

/datum/homestead
	/// The stamped template: list(low x, low y, high x, high y, z)
	var/list/bounds
	/// The Frontier's two levels
	var/surface_z = 0
	var/cave_z = 0
	/// The middle of the house, where safety is measured from and where raiders head
	var/turf/centre
	/// The family's surname, one per round
	var/surname
	/// Weakrefs to every family member made this round, living or dead
	var/list/datum/weakref/members = list()
	/// Weakrefs to the landmarks a family member was made at
	var/list/datum/weakref/used_landmarks = list()
	/// Food in the house: at least BACKGROUND_HOMESTEAD_FOOD_MIN at the last tick
	var/fed = TRUE
	/// No hostile creature near the house at the last tick
	var/safe = TRUE
	/// world.time it last became safe
	var/safe_since = 0
	/// Tests stop the tick and drive it by hand
	var/paused = FALSE
	/// Night forced on (TRUE) or off (FALSE) for tests; null follows the clock
	var/forced_night
	var/next_tick = 0
	var/next_departure_check = 0
	/// The house fridge and the kitchen tables, found once and found again when lost
	var/datum/weakref/fridge_ref
	var/list/datum/weakref/table_refs = list()
	/// world.time the fridge and tables may be looked for again
	var/next_fixture_search = 0
	/// Fixture kind -> weakrefs to those on the homestead (fixtures_of())
	var/list/fixture_cache
	/// world.time the homestead may be swept for fixtures again
	var/next_fixture_sweep = 0
	/// ckey -> world.time a homesteader was last greeted
	var/list/greeted = list()
	/// ckey -> TRUE while a homesteader is near the family, so a greeting is for coming home
	var/list/near_family = list()
	/// ckeys admins were told killed one of the family
	var/list/alerted_killers = list()
	// Raids (homestead_raids.dm)
	/// world.time the next party may set out
	var/next_raid_at = 0
	/// Where the party is coming from while its dust is on the ridge
	var/turf/raid_spot
	/// world.time the party arrives
	var/raid_arrives_at = 0
	/// Weakrefs to the party's riders
	var/list/datum/weakref/raiders = list()

/datum/homestead/New(list/new_bounds, new_surface_z, new_cave_z)
	. = ..()
	bounds = new_bounds
	surface_z = new_surface_z
	cave_z = new_cave_z
	surname = pick(GLOB.last_names)
	if(length(bounds) >= 5)
		centre = locate(round((bounds[1] + bounds[3]) / 2), round((bounds[2] + bounds[4]) / 2), bounds[5])

/datum/homestead/Destroy(force)
	STOP_PROCESSING(SSprocessing, src)
	if(GLOB.homestead == src)
		GLOB.homestead = null
	for(var/mob/living/basic/ambient_npc/homestead/member as anything in all_members())
		if(member.homestead == src)
			member.homestead = null
	members = null
	used_landmarks = null
	table_refs = null
	raiders = null
	centre = null
	raid_spot = null
	return ..()

/// Starts the tick
/datum/homestead/proc/start()
	START_PROCESSING(SSprocessing, src)

/datum/homestead/process(seconds_per_tick)
	if(paused || world.time < next_tick)
		return
	next_tick = world.time + BACKGROUND_HOMESTEAD_NEEDS_INTERVAL
	tick()

/// One beat of the homestead
/datum/homestead/proc/tick()
	update_needs()
	tend_family()
	tend_homesteaders()
	tend_raids()

/// Whether `thing` is on the stamped homestead
/datum/homestead/proc/contains(atom/thing)
	var/turf/here = get_turf(thing)
	return here && length(bounds) >= 5 && ambient_in_bounds(here, bounds)

/// Whether `thing` is on either of the Frontier's levels
/datum/homestead/proc/on_frontier(atom/thing)
	var/turf/here = get_turf(thing)
	return here && (here.z == surface_z || here.z == cave_z)

// =========================================================================
// DAY AND NIGHT
// =========================================================================

/// Night: the last BACKGROUND_HOMESTEAD_NIGHT_LENGTH of every BACKGROUND_HOMESTEAD_DAY_LENGTH of world.time
/datum/homestead/proc/is_night()
	if(!isnull(forced_night))
		return forced_night
	return (world.time % BACKGROUND_HOMESTEAD_DAY_LENGTH) >= (BACKGROUND_HOMESTEAD_DAY_LENGTH - BACKGROUND_HOMESTEAD_NIGHT_LENGTH)

/// Which day of the round it is, counting from 0
/datum/homestead/proc/day_number()
	return round(world.time / BACKGROUND_HOMESTEAD_DAY_LENGTH)

/// world.time of the next sunrise
/datum/homestead/proc/next_dawn()
	return (day_number() + 1) * BACKGROUND_HOMESTEAD_DAY_LENGTH

// =========================================================================
// NEEDS
// =========================================================================

/// Works out fed and safe, and has one of the family say so when either changes
/datum/homestead/proc/update_needs()
	var/now_fed = count_food(BACKGROUND_HOMESTEAD_FOOD_MIN) >= BACKGROUND_HOMESTEAD_FOOD_MIN
	if(now_fed != fed)
		fed = now_fed
		var/mob/living/basic/ambient_npc/homestead/cook = family_speaker(/mob/living/basic/ambient_npc/homestead/spouse)
		cook?.speak_context(fed ? "fed" : "hungry", null, TRUE)
	var/now_safe = isnull(find_threat())
	if(now_safe != safe)
		safe = now_safe
		var/mob/living/basic/ambient_npc/homestead/lookout = family_speaker(/mob/living/basic/ambient_npc/homestead/child)
		lookout?.speak_context(safe ? "safe" : "unsafe", null, TRUE)
		if(safe)
			safe_since = world.time
		else
			for(var/mob/living/basic/ambient_npc/homestead/member as anything in living_members())
				member.take_shelter()

/**
 * Food in the house: what is in the fridge, then what is on the kitchen tables, counted up to
 * `limit` and no further.
 */
/datum/homestead/proc/count_food(limit = BACKGROUND_HOMESTEAD_FOOD_MIN)
	. = 0
	refresh_fixtures()
	var/obj/machinery/smartfridge/fridge = fridge_ref?.resolve()
	if(!QDELETED(fridge))
		for(var/obj/item/food/meal in fridge.contents)
			if(++. >= limit)
				return
	for(var/datum/weakref/table_ref as anything in table_refs)
		var/obj/structure/table/table = table_ref.resolve()
		if(QDELETED(table))
			continue
		for(var/obj/item/food/meal in table.loc)
			if(++. >= limit)
				return

/// One food item from the kitchen tables, else the fridge, or null
/datum/homestead/proc/find_food()
	refresh_fixtures()
	for(var/datum/weakref/table_ref as anything in table_refs)
		var/obj/structure/table/table = table_ref.resolve()
		if(QDELETED(table))
			continue
		var/obj/item/food/meal = locate() in table.loc
		if(meal)
			return meal
	var/obj/machinery/smartfridge/fridge = fridge_ref?.resolve()
	if(!QDELETED(fridge))
		return locate(/obj/item/food) in fridge.contents
	return null

/// The nearest living hostile creature within BACKGROUND_HOMESTEAD_SAFE_RANGE of the house, or null
/datum/homestead/proc/find_threat()
	if(!centre)
		return null
	for(var/mob/living/creature in SSspatial_grid.orthogonal_range_search(centre, SPATIAL_GRID_CONTENTS_TYPE_HEARING, BACKGROUND_HOMESTEAD_SAFE_RANGE))
		if(creature.stat == DEAD || HAS_TRAIT(creature, TRAIT_HOMESTEAD_RESIDENT))
			continue
		if(is_hostile_creature(creature))
			return creature
	return null

// =========================================================================
// FIXTURES
// =========================================================================

/// Finds the fridge and kitchen tables again if either went missing, at most once a minute
/datum/homestead/proc/refresh_fixtures()
	var/obj/machinery/smartfridge/fridge = fridge_ref?.resolve()
	if(!QDELETED(fridge) && length(table_refs))
		return
	if(world.time < next_fixture_search)
		return
	next_fixture_search = world.time + 1 MINUTES
	if(QDELETED(fridge))
		fridge = null
		fridge_ref = null
		var/best_distance = INFINITY
		for(var/obj/machinery/smartfridge/candidate as anything in SSmachines.get_machines_by_type_and_subtypes(/obj/machinery/smartfridge))
			if(!contains(candidate) || !istype(get_area(candidate), /area/voidcrew/homestead/house))
				continue
			var/distance = centre ? get_dist(candidate, centre) : 0
			if(distance < best_distance)
				fridge = candidate
				best_distance = distance
		if(fridge)
			fridge_ref = WEAKREF(fridge)
	table_refs = list()
	var/atom/kitchen = fridge || find_fixture(/obj/machinery/oven/range)
	if(!kitchen)
		return
	for(var/obj/structure/table/table in range(5, kitchen))
		if(istype(get_area(table), /area/voidcrew/homestead/house))
			table_refs += WEAKREF(table)

/**
 * Every live fixture of `fixture_type` (a kind sweep_fixtures() looks for, or a subtype) on the
 * homestead. Routines ask when they start (MOD-3): a fixture that was taken away is gone from the
 * answer, and when none is left the homestead is swept again, at most once a minute.
 */
/datum/homestead/proc/fixtures_of(fixture_type)
	. = list()
	if(!fixture_cache || !live_fixtures(fixture_type, .))
		if(fixture_cache && world.time < next_fixture_sweep)
			return
		sweep_fixtures()
		live_fixtures(fixture_type, .)

/// Adds the cached live fixtures of `fixture_type` to `found`; TRUE if there were any
/datum/homestead/proc/live_fixtures(fixture_type, list/found)
	for(var/cached_type in fixture_cache)
		if(!ispath(cached_type, fixture_type) && !ispath(fixture_type, cached_type))
			continue
		for(var/datum/weakref/fixture_ref as anything in fixture_cache[cached_type])
			var/atom/fixture = fixture_ref.resolve()
			if(QDELETED(fixture) || !istype(fixture, fixture_type) || !contains(fixture))
				continue
			found |= fixture
	return length(found) > 0

/// Finds every fixture on the homestead again
/datum/homestead/proc/sweep_fixtures()
	next_fixture_sweep = world.time + 1 MINUTES
	fixture_cache = list()
	if(length(bounds) < 5)
		return
	// What the routines look for
	var/static/list/kinds = list(
		/obj/machinery/oven/range,
		/obj/machinery/hydroponics,
		/obj/structure/water_source/homestead_well,
		/obj/structure/homestead_coop,
		/obj/structure/ore_container/food_trough,
		/obj/structure/bed,
		/obj/structure/closet,
		/obj/structure/chair,
		/obj/structure/table,
	)
	for(var/turf/tile as anything in block(locate(bounds[1], bounds[2], bounds[5]), locate(bounds[3], bounds[4], bounds[5])))
		for(var/obj/thing in tile)
			for(var/kind in kinds)
				if(istype(thing, kind))
					LAZYADD(fixture_cache[kind], WEAKREF(thing))
					break

/// The nearest fixture of `fixture_type` to `near` (the house centre by default), or null
/datum/homestead/proc/find_fixture(fixture_type, atom/near)
	near = near || centre
	var/atom/best
	var/best_distance = INFINITY
	for(var/atom/candidate as anything in fixtures_of(fixture_type))
		var/distance = near ? get_dist(candidate, near) : 0
		if(distance < best_distance)
			best = candidate
			best_distance = distance
	return best

/// Puts the middle of the house at the middle of its rooms, rather than of the whole yard
/datum/homestead/proc/find_house_centre()
	if(length(bounds) < 5)
		return
	var/sum_x = 0
	var/sum_y = 0
	var/count = 0
	for(var/turf/tile as anything in block(locate(bounds[1], bounds[2], bounds[5]), locate(bounds[3], bounds[4], bounds[5])))
		if(istype(tile.loc, /area/voidcrew/homestead/house))
			sum_x += tile.x
			sum_y += tile.y
			count++
	if(count)
		centre = locate(round(sum_x / count), round(sum_y / count), bounds[5])

/// The larder's first stock: a few vegetables in the fridge, so the round does not open hungry
/datum/homestead/proc/stock_larder()
	refresh_fixtures()
	var/obj/machinery/smartfridge/fridge = fridge_ref?.resolve()
	if(QDELETED(fridge))
		return
	var/static/list/stock = list(
		/obj/item/food/grown/potato,
		/obj/item/food/grown/potato,
		/obj/item/food/grown/carrot,
		/obj/item/food/grown/corn,
		/obj/item/food/grown/corn,
	)
	for(var/produce_type in stock)
		fridge.load(new produce_type(fridge))
	fridge.update_appearance()

// =========================================================================
// SPEAKERS
// =========================================================================

/// A conscious family member to say something: one of `preferred_type` if there is one, anyone otherwise
/datum/homestead/proc/family_speaker(preferred_type)
	var/mob/living/basic/ambient_npc/homestead/fallback
	for(var/mob/living/basic/ambient_npc/homestead/member as anything in living_members())
		if(!member.can_act())
			continue
		if(!preferred_type || istype(member, preferred_type))
			return member
		fallback = fallback || member
	return fallback
