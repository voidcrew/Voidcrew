/**
 * # Outpost recovery: the janitors
 *
 * Owner: R4 (spec-rehydrate.md 3.2 and 3.3, M33, M34). Real cleaning after a massacre, with the real tools, by
 * the same clicks a player makes:
 * - Blood, gibs, vomit, glass, ash: a mop wetted at a sink or mop bucket (a right click, as for a player), then a
 *   click on the tile. tg's cleaner component does the stroke (a do_after, a unit of water) and washes the tile
 *   with CLEAN_SCRUB, which takes every mopable cleanable decal on it with it. Nothing here deletes a decal. (The
 *   Quartermain janitor in ambient_npcs/outpost_workers.dm still does: clean_tile() qdels.)
 * - Spent casings, empty magazines, empty bottles, wrappers: a trash bag set to take one thing at a click, a fixed
 *   type list (recovery_is_litter()), nothing else ever: never a gun, a tool, a full magazine or anything with a
 *   use. The bag also refuses by type (set_holdable()), so a bag toggled to take everything still takes litter only.
 * - A full bag goes out by the lift. Mop and bag are locked gear (human_npc_gear.dm): nobody can take them, and
 *   they go with the janitor.
 * No janitorial cart: a dense cart pulled through a door by the ambient walker can be left in a corridor, and it
 * carries a mop, a bag and signs that a player could roll away. Bucket and bag only.
 * Nothing structural is repaired (decision 18). The janitors' stops are the police beat routes' stops
 * (group.routes), read here: recovery.work_stops(), stop_dirty(), mark_clean(), clean_share().
 *
 * Checkpoint: ambient NPCs never path through a checkpoint chamber (trade/outpost_checkpoint.dm CanAStarPass()), so
 * the closet (lobby side) is not reachable on foot from the concourse. A janitor uses the sinks and buckets on its own
 * side of the checkpoint: the closet's when it stands in the lobby, the concourse's otherwise.
 *
 * Frozen by R0: the type and the proc names and signatures of the recovery datum below.
 */

/// What a tile holds for a crew: mess to wash, litter for the bag
#define RECOVERY_WORK_MESS (1<<0)
#define RECOVERY_WORK_LITTER (1<<1)
/// What the janitor's current activity is doing
#define RECOVERY_TASK_WET 1
#define RECOVERY_TASK_MOP 2
#define RECOVERY_TASK_PICK 3
#define RECOVERY_TASK_HAUL 4
/// A mop with less water than this does not wash (tg's cleaner needs a whole unit of a cleaning reagent)
#define RECOVERY_MOP_DRY 1.5
/// How far round itself a janitor looks for mess when no patrol stop has any
#define RECOVERY_STRAY_RANGE 12
/// Tiles tried for a place to stand in one search, nearest first
#define RECOVERY_SPOT_CHECKS 12
/// Mess or a sink they could not get to is left alone this long
#define RECOVERY_GIVE_UP_TIME (3 MINUTES)
/// At most this many tiles and sinks are left alone at once (the oldest is let back in past it)
#define RECOVERY_GIVE_UP_MAX 64
/// A patrol stop's clean state is looked at again after this long
#define RECOVERY_STOP_RECHECK (3 SECONDS)
/// With nothing left to do they take the lift out after this long
#define RECOVERY_IDLE_LEAVE (45 SECONDS)
/// Strokes at one tile before it is given up
#define RECOVERY_STROKES_MAX 3
/// A word to someone walking the wet floor, no more often than this
#define RECOVERY_FLOOR_WARNING (20 SECONDS)
/// The lift takes the bag out in this long
#define RECOVERY_HAUL_TIME (4 SECONDS)
/// Patrol stops are looked for again this often while the outpost has none
#define RECOVERY_STOPS_RETRY (30 SECONDS)
/// Tags of the stops inside the police station, where a crew has no business
#define RECOVERY_STATION_STOPS list("cells", "desk")

// =========================================================================
// WHAT IS MESS, WHAT IS LITTER
// =========================================================================

/**
 * Whether `decal` is what a fight leaves for a crew to wash: blood, gibs, vomit, glass, ash, molten junk. Not the
 * map's own grime (dirt, dust, cobwebs, the `/old` decals the maps place for looks), and not anything the ambient
 * janitors marked as the map's decor.
 */
/proc/recovery_is_mess(obj/effect/decal/cleanable/decal)
	if(!istype(decal) || QDELETED(decal) || !isturf(decal.loc))
		return FALSE
	var/static/list/mess_types = typecacheof(list(
		/obj/effect/decal/cleanable/blood,
		/obj/effect/decal/cleanable/vomit,
		/obj/effect/decal/cleanable/glass,
		/obj/effect/decal/cleanable/ash,
		/obj/effect/decal/cleanable/molten_object,
	))
	if(!is_type_in_typecache(decal, mess_types))
		return FALSE
	// The `old` decals are how the maps spell "was here a while": decor
	var/static/list/decor_types
	if(!decor_types)
		decor_types = list()
		for(var/decal_path in typesof(/obj/effect/decal/cleanable))
			if(findtext("[decal_path]", "/old"))
				decor_types[decal_path] = TRUE
	if(decor_types[decal.type])
		return FALSE
	// ambient_outpost_mark_decor() (outpost_patrons.dm, TRAIT_AMBIENT_OUTPOST_DECOR): written out, the define is not kept
	return !HAS_TRAIT(decal, "ambient_outpost_decor")

/**
 * Whether `thing` is litter the crew's bag may take (M34): a fixed list of types, and only in the state that makes
 * it litter. A spent casing, a magazine with nothing live in it, an empty bottle, a wrapper. Never a gun, a tool,
 * a loaded magazine, a full bottle or anything else.
 */
/proc/recovery_is_litter(obj/item/thing)
	if(!istype(thing) || QDELETED(thing) || !isturf(thing.loc) || thing.anchored)
		return FALSE
	var/static/list/litter_types = typecacheof(list(
		/obj/item/trash,
		/obj/item/ammo_casing,
		/obj/item/ammo_box/magazine,
		/obj/item/reagent_containers/cup/glass/bottle,
	))
	if(!is_type_in_typecache(thing, litter_types))
		return FALSE
	// Small enough for the bag (the crew's takes a bottle, which tg's own does not), and nothing marked as property or fixed to the world
	if(thing.w_class > WEIGHT_CLASS_NORMAL || (thing.resistance_flags & INDESTRUCTIBLE) || HAS_TRAIT(thing, TRAIT_NODROP))
		return FALSE
	// The map's own litter (recovery.mark_decor(), TRAIT_AMBIENT_OUTPOST_DECOR written out)
	if(HAS_TRAIT(thing, "ambient_outpost_decor"))
		return FALSE
	if(istype(thing, /obj/item/ammo_casing))
		var/obj/item/ammo_casing/casing = thing
		return !casing.loaded_projectile
	if(istype(thing, /obj/item/ammo_box/magazine))
		var/obj/item/ammo_box/magazine/magazine = thing
		return magazine.ammo_count(FALSE) <= 0
	if(istype(thing, /obj/item/reagent_containers/cup/glass/bottle))
		return !thing.reagents?.total_volume && !length(thing.contents)
	return TRUE

/// Every bit of mess on `tile`
/proc/recovery_mess_on(turf/tile)
	. = list()
	if(!tile)
		return
	for(var/obj/effect/decal/cleanable/decal in tile)
		if(recovery_is_mess(decal))
			. += decal

/// Every bit of litter on `tile`
/proc/recovery_litter_on(turf/tile)
	. = list()
	if(!tile)
		return
	for(var/obj/item/thing in tile)
		if(recovery_is_litter(thing))
			. += thing

// =========================================================================
// THE PATROL STOPS (the recovery datum's)
// =========================================================================

/datum/outpost_recovery
	/// Patrol stop turf -> world.time stop_dirty() last looked at it
	var/list/stop_looked = list()
	/// The turfs of the police beat routes' stops that a crew works, once found
	var/list/turf/work_stop_list
	/// world.time the stops were last looked for
	var/work_stops_checked_at = 0

/**
 * The turfs of the stops on the police beat routes (the stealth group's routes, stealth_patrol.dm), minus the ones
 * inside the police station. Worked out once; an outpost whose map has no routes has none (a janitor then works
 * what it finds round itself, and every stop counts as clean).
 */
/datum/outpost_recovery/proc/work_stops()
	if(work_stop_list)
		return work_stop_list
	if(work_stops_checked_at && world.time - work_stops_checked_at < RECOVERY_STOPS_RETRY)
		return list()
	work_stops_checked_at = max(world.time, 1)
	var/datum/outpost_police/police = outpost?.police
	var/datum/stealth_group/group = police?.patrol_group()
	if(!group)
		return list()
	var/list/found = list()
	for(var/route in group.routes)
		for(var/datum/stealth_stop/stop as anything in group.routes[route])
			if(!stop?.spot || (police.stop_tag(stop.spot) in RECOVERY_STATION_STOPS))
				continue
			found |= stop.spot
	work_stop_list = found
	return work_stop_list

/**
 * Whether anything within OUTPOST_RECOVERY_STOP_RANGE of `stop` that can be seen from it is a body, a mess or
 * litter: what a worker standing there would find. Looks again at most every RECOVERY_STOP_RECHECK.
 */
/datum/outpost_recovery/proc/stop_dirty(turf/stop)
	if(!isturf(stop))
		return FALSE
	var/looked = stop_looked[stop]
	if(!isnull(looked) && world.time - looked < RECOVERY_STOP_RECHECK)
		return !!dirty_stops[stop]
	stop_looked[stop] = world.time
	if(stop_has_work(stop))
		dirty_stops[stop] = TRUE
		return TRUE
	dirty_stops -= stop
	return FALSE

/// The look itself: a body of a human on the floor, a mess, or litter, in sight within the stop range
/datum/outpost_recovery/proc/stop_has_work(turf/stop)
	var/range_limit = OUTPOST_RECOVERY_STOP_RANGE
	for(var/mob/living/carbon/human/body in range(range_limit, stop))
		if(body.stat == DEAD && isturf(body.loc) && can_see(stop, body, range_limit))
			return TRUE
	for(var/obj/effect/decal/cleanable/decal in range(range_limit, stop))
		if(recovery_is_mess(decal) && can_see(stop, decal, range_limit))
			return TRUE
	for(var/obj/item/thing in range(range_limit, stop))
		if(recovery_is_litter(thing) && can_see(stop, thing, range_limit))
			return TRUE
	return FALSE

/// A worker on `stop` found it clean
/datum/outpost_recovery/proc/mark_clean(turf/stop)
	if(!isturf(stop))
		return
	dirty_stops -= stop
	stop_looked[stop] = world.time

/// The share of patrol stops that are clean, 0 to 1. 1 where there are no stops.
/datum/outpost_recovery/proc/clean_share()
	var/list/stops = work_stops()
	if(!length(stops))
		return 1
	var/clean = 0
	for(var/turf/stop as anything in stops)
		if(!stop_dirty(stop))
			clean++
	return clean / length(stops)

// =========================================================================
// THE JANITOR
// =========================================================================

/// Mops up and bags the litter
/mob/living/carbon/human/npc/ambient_npc/outpost/recovery/janitor
	name = "outpost janitor"
	desc = "Outpost cleaning staff."
	outfit_choices = list(
		/datum/outfit/recovery_janitor,
		/datum/outfit/recovery_janitor/overalls,
	)
	// On the station's radio net: the headset in their ears is theirs to call on (stealth_radio.dm)
	stealth_radio = TRUE
	/// Between jobs they stand about or stroll; the jobs themselves are pick_activity()'s
	routine = list(
		/datum/ambient_activity/idle = 1,
		/datum/ambient_activity/wander = 1,
	)
	/// The mop in their hand (their kit, locked)
	var/obj/item/mop/crew_mop
	/// The trash bag in their other hand (their kit, locked)
	var/obj/item/storage/bag/trash/crew_bag
	/// Tile or sink they could not get to -> world.time they may try again
	var/list/cleaning_gave_up
	/// world.time since when they have had nothing to do, or 0
	var/idle_since = 0
	/// world.time they last warned someone off the floor
	var/floor_warned_at = 0
	/// The lift is no use to them (it could not be reached) until this world.time
	var/haul_blocked_until = 0

/mob/living/carbon/human/npc/ambient_npc/outpost/recovery/janitor/Initialize(mapload)
	. = ..()
	for(var/obj/item/held in held_items)
		if(istype(held, /obj/item/mop))
			crew_mop = held
		else if(istype(held, /obj/item/storage/bag/trash))
			crew_bag = held
	if(crew_bag?.atom_storage)
		// One thing at a click, and litter by type: a bag that can only take what it is shown. Room for a bottle, as a
		// player's would not have.
		crew_bag.atom_storage.collection_mode = COLLECT_ONE
		crew_bag.atom_storage.max_specific_storage = WEIGHT_CLASS_NORMAL
		crew_bag.atom_storage.set_holdable(list(
			/obj/item/trash,
			/obj/item/ammo_casing,
			/obj/item/ammo_box/magazine,
			/obj/item/reagent_containers/cup/glass/bottle,
		))
	// Tuned to the police frequency, as the officers' are
	var/obj/item/radio/headset = ears
	if(istype(headset))
		headset.set_frequency(OUTPOST_POLICE_RADIO_FREQ)

/mob/living/carbon/human/npc/ambient_npc/outpost/recovery/janitor/Destroy()
	crew_mop = null
	crew_bag = null
	cleaning_gave_up = null
	return ..()

// Stood still with nobody on the concourse: the give-ups and the idle clock count only time they could work
/mob/living/carbon/human/npc/ambient_npc/outpost/recovery/janitor/shift_times(delay)
	. = ..()
	idle_since = ambient_shifted(idle_since, delay)
	for(var/atom/old as anything in cleaning_gave_up)
		cleaning_gave_up[old] = ambient_shifted(cleaning_gave_up[old], delay)

// The lost-crew ladder (4.2) counts a janitor who dies at work
/mob/living/carbon/human/npc/ambient_npc/outpost/recovery/janitor/death(gibbed)
	var/was_alive = stat != DEAD
	. = ..()
	if(was_alive && stat == DEAD)
		my_recovery()?.crew_lost(src)

/// The outpost recovery they work for: the one that sent them, or their outpost's
/mob/living/carbon/human/npc/ambient_npc/outpost/recovery/janitor/proc/my_recovery()
	return outpost_recovery || get_outpost()?.recovery

// Their voice is their outpost's: the police profile's section, as the officers' lines are
/mob/living/carbon/human/npc/ambient_npc/outpost/recovery/janitor/get_lines(context)
	var/obj/structure/overmap/trader_outpost/outpost = get_outpost()
	var/section = outpost?.police?.profile?.voice_section
	if(section)
		dialogue_section = section
	return ..()

/**
 * Where they may stand: any open floor they could be on, whatever the outpost keeps its other people off (a
 * doorway, the lobby, the reach of a counter), since the mess is where it is. Never a lift.
 */
/mob/living/carbon/human/npc/ambient_npc/outpost/recovery/janitor/standable(turf/tile, list/avoid, ignore_floor = FALSE)
	if(!isturf(tile) || LAZYACCESS(avoid, tile))
		return FALSE
	if(!ambient_ground_ok(tile) || !leash_ok(tile))
		return FALSE
	var/obj/structure/overmap/trader_outpost/outpost = get_outpost()
	if(outpost && ((tile in outpost.lobby_alcove_turfs) || (outpost.police && (tile in outpost.police.lift_turfs))))
		return FALSE
	return TRUE

/**
 * Says a line for `context`: aloud, or over the headset (the officers hear it) if `radio`. Their own and their
 * place's pauses between lines are kept unless `force`. TRUE if they spoke.
 */
/mob/living/carbon/human/npc/ambient_npc/outpost/recovery/janitor/proc/crew_say(context, radio = FALSE, atom/other, force = FALSE)
	if(stat != CONSCIOUS || fading || paused_at)
		return FALSE
	if(!force && (world.time < next_line_at || (place && world.time < place.next_line_at)))
		return FALSE
	var/list/lines = get_lines(context)
	if(!length(lines))
		return FALSE
	var/line = pick(lines)
	if(!istext(line))
		return FALSE
	line = fill_line(line, other)
	if(!radio || !istype(ears, /obj/item/radio))
		say_line(line)
		return TRUE
	next_line_at = world.time + rand(AMBIENT_SPEECH_COOLDOWN_LOW, AMBIENT_SPEECH_COOLDOWN_HIGH) * speech_pace
	INVOKE_ASYNC(src, TYPE_PROC_REF(/atom/movable, say), ";[line]")
	return TRUE

// ----- the kit -----

/// Whether the mop washes: enough water in it
/mob/living/carbon/human/npc/ambient_npc/outpost/recovery/janitor/proc/mop_wet()
	return !QDELETED(crew_mop) && crew_mop.reagents.total_volume >= RECOVERY_MOP_DRY

/// Whether the mop holds all the water it can
/mob/living/carbon/human/npc/ambient_npc/outpost/recovery/janitor/proc/mop_full()
	return !QDELETED(crew_mop) && crew_mop.reagents.total_volume >= crew_mop.reagents.maximum_volume - 0.1

/// Whether the bag has no room for another bottle, the biggest thing it takes
/mob/living/carbon/human/npc/ambient_npc/outpost/recovery/janitor/proc/bag_full()
	var/datum/storage/storage = crew_bag?.atom_storage
	if(QDELETED(crew_bag) || !storage)
		return FALSE
	return storage.get_total_weight() + WEIGHT_CLASS_NORMAL > storage.max_total_storage || length(crew_bag.contents) >= storage.max_slots

/// They left a sink, a bucket or a tile alone for a while
/mob/living/carbon/human/npc/ambient_npc/outpost/recovery/janitor/proc/give_up_on(atom/thing)
	if(!thing)
		return
	// Waited-out entries go first, so a big patch they can't reach is never let back in early and walked at again
	for(var/atom/old as anything in cleaning_gave_up?.Copy())
		if(cleaning_gave_up[old] <= world.time)
			cleaning_gave_up -= old
	LAZYSET(cleaning_gave_up, thing, world.time + RECOVERY_GIVE_UP_TIME)
	if(length(cleaning_gave_up) > RECOVERY_GIVE_UP_MAX)
		cleaning_gave_up.Cut(1, 2)

/**
 * The lift they take a full bag to, or null: the police lift on the concourse side, the public one in the lobby.
 * Null too for a while after one could not be reached.
 */
/mob/living/carbon/human/npc/ambient_npc/outpost/recovery/janitor/proc/haul_spot()
	if(world.time < haul_blocked_until)
		return null
	var/obj/structure/overmap/trader_outpost/outpost = get_outpost()
	var/turf/here = get_turf(src)
	if(!outpost || !here)
		return null
	var/list/lifts = (outpost.police && outpost.is_secured_turf(here)) ? outpost.police.lift_turfs : outpost.lobby_alcove_turfs
	var/turf/best
	var/best_distance = INFINITY
	for(var/turf/lift as anything in lifts)
		if(lift.z != here.z)
			continue
		var/distance = get_dist(here, lift)
		if(distance < best_distance)
			best = lift
			best_distance = distance
	return best

/// Whether litter can be picked up now: the bag has room, or the lift is there to empty it
/mob/living/carbon/human/npc/ambient_npc/outpost/recovery/janitor/proc/litter_ok()
	return !bag_full() || !!haul_spot()

/// Hands what the bag holds to the lift. The bag stays with them, empty.
/mob/living/carbon/human/npc/ambient_npc/outpost/recovery/janitor/proc/empty_bag()
	if(QDELETED(crew_bag))
		return
	for(var/obj/item/litter in crew_bag.contents.Copy())
		qdel(litter)
	crew_bag.update_appearance()

/// Tops the mop up where there is no sink or bucket to dip it in (a map without one on their side)
/mob/living/carbon/human/npc/ambient_npc/outpost/recovery/janitor/proc/fill_mop()
	if(QDELETED(crew_mop))
		return
	crew_mop.reagents.add_reagent(/datum/reagent/water, crew_mop.reagents.maximum_volume - crew_mop.reagents.total_volume)
	playsound(src, 'sound/effects/slosh.ogg', 25, TRUE, -4)

// ----- finding work -----

/**
 * The nearest sink or mop bucket with water in it that they could dip the mop in, on their side of the
 * checkpoint, or null: list(source, tile to stand on).
 */
/mob/living/carbon/human/npc/ambient_npc/outpost/recovery/janitor/proc/find_water(list/avoid)
	var/obj/structure/overmap/trader_outpost/outpost = get_outpost()
	var/turf/here = get_turf(src)
	if(!outpost || !here)
		return null
	// Past a checkpoint they cannot walk, so they keep to their own side of it
	var/same_side_only = length(outpost.checkpoints) > 0
	var/here_secured = outpost.is_secured_turf(here)
	var/list/sources = ambient_outpost_find_all(outpost, /obj/structure/sink) + ambient_outpost_find_all(outpost, /obj/structure/mop_bucket)
	var/atom/best
	var/turf/best_stand
	var/best_distance = INFINITY
	for(var/obj/source as anything in sources)
		if(QDELETED(source) || !source.reagents || source.reagents.total_volume < 5 || LAZYACCESS(cleaning_gave_up, source) > world.time)
			continue
		var/turf/source_turf = get_turf(source)
		if(!source_turf || source_turf.z != here.z || (same_side_only && outpost.is_secured_turf(source_turf) != here_secured))
			continue
		var/distance = get_dist(here, source_turf)
		if(distance >= best_distance)
			continue
		var/turf/stand = ambient_use_spot(src, source, avoid)
		if(!stand)
			continue
		best = source
		best_stand = stand
		best_distance = distance
	return best ? list(best, best_stand) : null

/// Where to stand to work `tile`: where they are if that is beside it, a free tile beside it, or the tile itself
/mob/living/carbon/human/npc/ambient_npc/outpost/recovery/janitor/proc/work_spot(turf/tile)
	if(!tile || LAZYACCESS(cleaning_gave_up, tile) > world.time)
		return null
	var/turf/stand = free_tile_beside(tile, 1)
	if(!stand && standable(tile))
		stand = tile
	return stand

/// Whether the other janitor is going for `tile`
/mob/living/carbon/human/npc/ambient_npc/outpost/recovery/janitor/proc/tile_claimed(turf/tile)
	for(var/mob/living/carbon/human/npc/ambient_npc/outpost/recovery/janitor/other in place?.npcs)
		if(other == src || other.stat == DEAD)
			continue
		var/datum/ambient_activity/recovery_clean/theirs = other.activity
		if(istype(theirs) && theirs.work_tile == tile)
			return TRUE
	return FALSE

/**
 * What there is to do within `range` of `center` (in sight of it if `sight`): tile -> RECOVERY_WORK_* flags.
 * Litter only counts while the bag can take it.
 */
/mob/living/carbon/human/npc/ambient_npc/outpost/recovery/janitor/proc/tiles_with_work(turf/center, range, sight = TRUE, take_litter = TRUE)
	var/list/found = list()
	for(var/obj/effect/decal/cleanable/decal in range(range, center))
		if(!recovery_is_mess(decal))
			continue
		var/turf/tile = decal.loc
		if(sight && !can_see(center, tile, range))
			continue
		found[tile] |= RECOVERY_WORK_MESS
	if(take_litter)
		for(var/obj/item/thing in range(range, center))
			if(!recovery_is_litter(thing))
				continue
			var/turf/tile = thing.loc
			if(sight && !can_see(center, tile, range))
				continue
			found[tile] |= RECOVERY_WORK_LITTER
	return found

/// The nearest of `found` (tile -> flags) they could work: list(tile, flags), or null
/mob/living/carbon/human/npc/ambient_npc/outpost/recovery/janitor/proc/nearest_work(list/found)
	var/list/distances = list()
	for(var/turf/tile as anything in found)
		// Tiles given up on are left out here, so a dozen of them nearest never hide mess they can reach
		if(LAZYACCESS(cleaning_gave_up, tile) > world.time)
			continue
		distances[tile] = get_dist(src, tile)
	if(!length(distances))
		return null
	var/checks = 0
	for(var/turf/tile as anything in sortTim(distances, GLOBAL_PROC_REF(cmp_numeric_asc), associative = TRUE))
		if(!tile_claimed(tile) && work_spot(tile))
			return list(tile, found[tile])
		if(++checks >= RECOVERY_SPOT_CHECKS)
			break
	return null

/**
 * The next thing to do: list(tile, patrol stop or null, RECOVERY_WORK_* flags), or null. The patrol stops with work
 * left come first, nearest first, and each is worked out to its edge before the next; mess outside every stop's
 * reach is what they find round themselves.
 */
/mob/living/carbon/human/npc/ambient_npc/outpost/recovery/janitor/proc/find_job()
	var/turf/here = get_turf(src)
	if(!here)
		return null
	var/take_litter = litter_ok()
	var/datum/outpost_recovery/recovery = my_recovery()
	if(recovery)
		var/list/dirty = list()
		for(var/turf/stop as anything in recovery.work_stops())
			if(stop.z == here.z && recovery.stop_dirty(stop))
				dirty[stop] = get_dist(here, stop)
		if(length(dirty))
			for(var/turf/stop as anything in sortTim(dirty, GLOBAL_PROC_REF(cmp_numeric_asc), associative = TRUE))
				var/list/job = nearest_work(tiles_with_work(stop, OUTPOST_RECOVERY_STOP_RANGE, TRUE, take_litter))
				if(job)
					return list(job[1], stop, job[2])
	var/list/stray = nearest_work(tiles_with_work(here, RECOVERY_STRAY_RANGE, FALSE, take_litter))
	if(stray)
		return list(stray[1], null, stray[2])
	return null

// ----- what they do -----

/mob/living/carbon/human/npc/ambient_npc/outpost/recovery/janitor/pick_activity()
	var/datum/ambient_activity/job = start_activity(new /datum/ambient_activity/recovery_clean(src))
	if(job)
		idle_since = 0
		return job
	if(!idle_since)
		idle_since = max(world.time, 1)
	// Nothing left but what the morgue crew has yet to take: they wait; clean, they take the lift out
	var/datum/outpost_recovery/recovery = my_recovery()
	if(world.time - idle_since >= RECOVERY_IDLE_LEAVE && (!recovery || recovery.clean_share() >= 1))
		crew_say(RECOVERY_LINE_LIFT, TRUE, force = TRUE)
		return start_activity(new /datum/ambient_activity/leave(src))
	return start_activity(new /datum/ambient_activity/idle(src))

/**
 * One piece of work: dip the mop, wash a tile, bag the litter on a tile, or hand the full bag to the lift. Picks
 * its own job in setup() and ends when it is done; pick_activity() starts the next.
 */
/datum/ambient_activity/recovery_clean
	name = "cleaning up"
	/// RECOVERY_TASK_*
	var/task
	/// The tile washed or picked clean
	var/turf/work_tile
	/// The patrol stop it belongs to, if any
	var/turf/work_stop
	/// The sink or bucket the mop is dipped in
	var/datum/weakref/source_ref
	/// The stroke, click or wait has started
	var/started = FALSE
	/// Strokes made at this tile
	var/strokes = 0
	/// Dips or pickups tried, and the level they were at
	var/clicks = 0
	var/last_level = 0
	/// world.time the wait at the lift ends
	var/wait_until = 0
	/// Its spot could not be reached: nothing more is done
	var/abandoned = FALSE

/datum/ambient_activity/recovery_clean/Destroy()
	work_tile = null
	work_stop = null
	source_ref = null
	return ..()

/datum/ambient_activity/recovery_clean/setup()
	var/mob/living/carbon/human/npc/ambient_npc/outpost/recovery/janitor/janitor = doer
	if(!istype(janitor) || QDELETED(janitor.crew_mop) || QDELETED(janitor.crew_bag))
		return FALSE
	// A full bag goes out first
	if(janitor.bag_full())
		var/turf/lift = janitor.haul_spot()
		if(lift)
			task = RECOVERY_TASK_HAUL
			go_to(lift)
			return TRUE
	var/list/job = janitor.find_job()
	if(!job)
		return FALSE
	work_tile = job[1]
	work_stop = job[2]
	var/kind = job[3]
	// Litter first where there is some; the mop for what is left on the tile
	task = ((kind & RECOVERY_WORK_LITTER) && janitor.litter_ok()) ? RECOVERY_TASK_PICK : RECOVERY_TASK_MOP
	// A dry mop is dipped before it is used
	if(task == RECOVERY_TASK_MOP && !janitor.mop_wet())
		var/list/water = janitor.find_water(failed_spots)
		if(water)
			task = RECOVERY_TASK_WET
			source_ref = WEAKREF(water[1])
			go_to(water[2])
			return TRUE
		// No sink or bucket on their side: the mop is wetted where they stand
		janitor.fill_mop()
	var/turf/stand = janitor.work_spot(work_tile)
	if(!stand)
		janitor.give_up_on(work_tile)
		return FALSE
	go_to(stand)
	return TRUE

/datum/ambient_activity/recovery_clean/arrive()
	started = FALSE
	var/atom/facing = task == RECOVERY_TASK_WET ? source_ref?.resolve() : work_tile
	if(facing && get_turf(facing) != get_turf(doer) && !doer.buckled)
		doer.face_atom(facing)

/datum/ambient_activity/recovery_clean/act(seconds)
	var/mob/living/carbon/human/npc/ambient_npc/outpost/recovery/janitor/janitor = doer
	if(abandoned || !istype(janitor) || QDELETED(janitor.crew_mop) || QDELETED(janitor.crew_bag))
		return AMBIENT_STEP_DONE
	switch(task)
		if(RECOVERY_TASK_WET)
			return wet_step(janitor)
		if(RECOVERY_TASK_MOP)
			return mop_step(janitor)
		if(RECOVERY_TASK_PICK)
			return pick_step(janitor)
		if(RECOVERY_TASK_HAUL)
			return haul_step(janitor)
	return AMBIENT_STEP_DONE

/// One dip a second until the mop is full: a right click with the mop on the sink or bucket, as a player wets one
/datum/ambient_activity/recovery_clean/proc/wet_step(mob/living/carbon/human/npc/ambient_npc/outpost/recovery/janitor/janitor)
	var/atom/source = source_ref?.resolve()
	if(QDELETED(source) || janitor.mop_full())
		return AMBIENT_STEP_DONE
	var/level = janitor.crew_mop.reagents.total_volume
	// Two dips that put no water in: nothing comes out of it
	if(clicks >= 2 && level <= last_level)
		janitor.give_up_on(source)
		return AMBIENT_STEP_DONE
	last_level = level
	if(++clicks > 6 || !human_npc_ready_item(janitor, janitor.crew_mop))
		return AMBIENT_STEP_DONE
	janitor.ai_controller?.ai_interact(target = source, combat_mode = FALSE, modifiers = list(RIGHT_CLICK = TRUE))
	return AMBIENT_STEP_CONTINUE

/// One stroke of the mop on the tile: a left click, tg's cleaner does the rest; again if it is not clean yet
/datum/ambient_activity/recovery_clean/proc/mop_step(mob/living/carbon/human/npc/ambient_npc/outpost/recovery/janitor/janitor)
	if(!work_tile)
		return AMBIENT_STEP_DONE
	if(!started)
		if(!length(recovery_mess_on(work_tile)))
			return finish_tile(janitor)
		if(!janitor.mop_wet() || ++strokes > RECOVERY_STROKES_MAX)
			// Dry: the next job dips it first. Too many strokes and still mess: it is left.
			if(strokes > RECOVERY_STROKES_MAX)
				janitor.give_up_on(work_tile)
			return AMBIENT_STEP_DONE
		if(!human_npc_ready_item(janitor, janitor.crew_mop))
			return AMBIENT_STEP_DONE
		started = TRUE
		janitor.ai_controller?.ai_interact(target = work_tile, combat_mode = FALSE)
		chatter(RECOVERY_LINE_MESS, 25 SECONDS, 50 SECONDS)
		warn_walkers(janitor)
		return AMBIENT_STEP_CONTINUE
	// Mid-stroke
	if(LAZYLEN(janitor.do_afters))
		return AMBIENT_STEP_CONTINUE
	started = FALSE
	if(length(recovery_mess_on(work_tile)))
		return AMBIENT_STEP_CONTINUE
	return finish_tile(janitor)

/// Someone on the wet floor, a word about it
/datum/ambient_activity/recovery_clean/proc/warn_walkers(mob/living/carbon/human/npc/ambient_npc/outpost/recovery/janitor/janitor)
	if(world.time < janitor.floor_warned_at + RECOVERY_FLOOR_WARNING)
		return
	for(var/mob/living/carbon/human/walker in range(2, work_tile))
		if(walker == janitor || !walker.client || walker.stat != CONSCIOUS)
			continue
		janitor.floor_warned_at = world.time
		janitor.crew_say(RECOVERY_LINE_MIND_FLOOR, FALSE, walker, TRUE)
		return

/// Bags one thing a second from the tile: a click with the bag on a piece of litter, as a player picks one up
/datum/ambient_activity/recovery_clean/proc/pick_step(mob/living/carbon/human/npc/ambient_npc/outpost/recovery/janitor/janitor)
	if(!work_tile)
		return AMBIENT_STEP_DONE
	var/list/litter = recovery_litter_on(work_tile)
	if(!length(litter) || janitor.bag_full())
		if(janitor.bag_full())
			return AMBIENT_STEP_DONE
		return finish_tile(janitor)
	// Nothing went in the last time: the tile is left
	var/held = length(janitor.crew_bag.contents)
	if(clicks && held <= last_level)
		janitor.give_up_on(work_tile)
		return AMBIENT_STEP_DONE
	last_level = held
	clicks++
	if(!human_npc_ready_item(janitor, janitor.crew_bag))
		return AMBIENT_STEP_DONE
	janitor.ai_controller?.ai_interact(target = litter[1], combat_mode = FALSE)
	return AMBIENT_STEP_CONTINUE

/// The full bag to the lift: a wait there, and what it held is gone with the lift
/datum/ambient_activity/recovery_clean/proc/haul_step(mob/living/carbon/human/npc/ambient_npc/outpost/recovery/janitor/janitor)
	if(!started)
		started = TRUE
		wait_until = world.time + RECOVERY_HAUL_TIME
		playsound(doer, 'sound/machines/chime.ogg', 50, TRUE)
		janitor.crew_say(RECOVERY_LINE_LIFT, TRUE, force = TRUE)
		return AMBIENT_STEP_CONTINUE
	if(world.time < wait_until)
		return AMBIENT_STEP_CONTINUE
	janitor.empty_bag()
	playsound(doer, 'sound/machines/ding.ogg', 50, TRUE)
	return AMBIENT_STEP_DONE

/// The tile is done: its patrol stop is looked at, and marked clean if nothing is left in reach of it
/datum/ambient_activity/recovery_clean/proc/finish_tile(mob/living/carbon/human/npc/ambient_npc/outpost/recovery/janitor/janitor)
	var/datum/outpost_recovery/recovery = janitor.my_recovery()
	if(recovery && work_stop)
		recovery.stop_looked -= work_stop
		if(!recovery.stop_dirty(work_stop))
			recovery.mark_clean(work_stop)
	return AMBIENT_STEP_DONE

/// Could not get there: the tile, sink or lift is left alone for a while
/datum/ambient_activity/recovery_clean/spot_unreachable()
	abandoned = TRUE
	var/mob/living/carbon/human/npc/ambient_npc/outpost/recovery/janitor/janitor = doer
	if(istype(janitor))
		switch(task)
			if(RECOVERY_TASK_WET)
				janitor.give_up_on(source_ref?.resolve())
			if(RECOVERY_TASK_HAUL)
				janitor.haul_blocked_until = world.time + RECOVERY_GIVE_UP_TIME
			else
				janitor.give_up_on(work_tile)
	return ..()

/datum/ambient_activity/recovery_clean/shift_times(delay)
	. = ..()
	wait_until = ambient_shifted(wait_until, delay)

#undef RECOVERY_WORK_MESS
#undef RECOVERY_WORK_LITTER
#undef RECOVERY_TASK_WET
#undef RECOVERY_TASK_MOP
#undef RECOVERY_TASK_PICK
#undef RECOVERY_TASK_HAUL
#undef RECOVERY_MOP_DRY
#undef RECOVERY_STRAY_RANGE
#undef RECOVERY_SPOT_CHECKS
#undef RECOVERY_GIVE_UP_TIME
#undef RECOVERY_GIVE_UP_MAX
#undef RECOVERY_STOP_RECHECK
#undef RECOVERY_IDLE_LEAVE
#undef RECOVERY_STROKES_MAX
#undef RECOVERY_FLOOR_WARNING
#undef RECOVERY_HAUL_TIME
#undef RECOVERY_STOPS_RETRY
#undef RECOVERY_STATION_STOPS
