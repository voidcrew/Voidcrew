/**
 * # World population: people who work at the trader outposts (owner item 4)
 *
 * Built here (spec 3.4), on PA's outpost base (outpost_patrons.dm):
 * - the janitor (Quartermain): finds fresh mess (blood, vomit, broken glass, spilled food, food
 *   wrappers), puts a wet floor sign down, mops it up, waits for the floor to dry and takes the sign
 *   back. Never the map's own grime or anything else. Mops round the floor with the mechanics' work
 *   loop when there is nothing to clean.
 * - the gardener (Halcyon): a watering can, filled at a sink, poured on the outpost's own trays
 *   (never a player's), a word to the plants. Keeps clear of the hives.
 * - the barback (the Dregs): collects empty glasses left on tables and the floor,
 *   washes them at a sink (or hands them over the bar), wipes tables with the work loop, and walks a
 *   passed-out drinker to the lift.
 * - the dock worker (Quartermain): hauls boxes along the intake row with the work loop, takes a
 *   coffee break in the crew room, and on the convoy carries crates from the lift to Sarge's
 *   counter for a minute and a half.
 * Staff duck when a fight breaks out and carry on; they do not leave. When players come they are
 * already mid-job (settle_in()). Their lines are in strings/outpost_workers.json
 * (AMBIENT_STRINGS_WORKERS).
 *
 * Halcyon's mechanics are now the ambient mechanic role (outpost_regulars.dm), reusing the
 * mechanic outfits from outpost_amenities.dm and this same work loop.
 * /datum/ambient_activity/work runs the same work loop (outpost_ambient_work.dm): the janitor mops,
 * the barback wipes and the dock worker hauls with it.
 *
 * Seams (P0, frozen): see outpost_patrons.dm, plus react_convoy() for the dock workers.
 */

/// How far round them the janitor looks for mess
#define WORKER_MESS_RANGE 10
/// Most mess tiles checked for a place to stand in one search
#define WORKER_MESS_SPOT_CHECKS 12
/// Wet floor signs a janitor brings in a visit; one a player walks off with is gone
#define WORKER_JANITOR_SIGNS 2
/// How long a mopped tile stays wet (while the sign stands)
#define WORKER_WET_TIME (12 SECONDS)
/// A mess on a tile mopped this recently gets a word
#define WORKER_REMOP_TIME (5 MINUTES)
/// Pours a full watering can holds
#define WORKER_CAN_POURS 4
/// Water one pour gives a tray
#define WORKER_TRAY_WATER 25
/// Trays a gardener remembers watering, so they move on to the others
#define WORKER_TENDED_MEMORY 4
/// How far round the bar the barback looks for glasses
#define WORKER_BAR_RANGE 12
/// Glasses the barback carries before washing them
#define WORKER_TRAY_MAX 4
/// How far from the bar a sink may be for the barback to use it
#define WORKER_SINK_RANGE 25
/// Crates a dock worker carries when the convoy comes in
#define WORKER_CONVOY_TRIPS 3
/// A concourse's list of one kind of fixture is worked out again this often
#define WORKER_FIXTURES_REFRESH (10 MINUTES)

// =========================================================================
// THE STAFF
// =========================================================================

/// Someone who works at the outpost. They duck when a fight starts and then carry on.
/mob/living/basic/ambient_npc/outpost/worker
	desc = "Works here."
	dialogue_file = AMBIENT_STRINGS_WORKERS
	dialogue_section = "janitor"

/mob/living/basic/ambient_npc/outpost/worker/react_violence(mob/living/offender)
	if(stat != CONSCIOUS || fading || istype(activity, /datum/ambient_activity/leave) || !reaction_ready("violence"))
		return
	if(!start_activity(new /datum/ambient_activity/duck(src, offender)))
		return
	if(!buckled)
		face_atom(offender)
	crouch()
	if(prob(50))
		speak_context(AMBIENT_LINE_VIOLENCE, offender, force = TRUE)

/// Staff take a swing with a word and stay at work
/mob/living/basic/ambient_npc/outpost/worker/react_attacked(atom/attacker)
	if(stat != CONSCIOUS || fading || !reaction_ready("attacked"))
		return
	speak_context(AMBIENT_LINE_ATTACKED, attacker, force = TRUE)

/// Down for a few seconds where they stand, until it looks safe
/datum/ambient_activity/duck
	name = "ducking"
	priority = AMBIENT_PRIORITY_REACTION
	duration_low = 4 SECONDS
	duration_high = 8 SECONDS

/datum/ambient_activity/duck/setup()
	set_duration()
	return TRUE

/datum/ambient_activity/duck/arrive()
	var/atom/threat = anchor()
	if(threat && !doer.buckled)
		doer.face_atom(threat)
	doer.crouch()

/**
 * Every `find_type` on `outpost`'s concourse, remembered for a while: the trays, the sinks, the
 * hives. Weakrefs are resolved here, so the list returned holds only what is still there.
 */
/proc/ambient_outpost_find_all(obj/structure/overmap/trader_outpost/outpost, find_type)
	. = list()
	if(!outpost || !find_type)
		return
	var/list/found = ambient_outpost_notes(outpost)
	var/key = "all [find_type]"
	var/list/entry = found[key]
	if(!entry || world.time >= entry[1])
		var/list/bounds = bounty_outpost_bounds(outpost)
		if(length(bounds) < 5)
			return
		// One of a kind per tile is plenty for fixtures (a tray, a sink, a hive)
		var/list/refs = list()
		for(var/turf/tile as anything in block(locate(bounds[1], bounds[2], bounds[5]), locate(bounds[3], bounds[4], bounds[5])))
			var/atom/movable/thing = locate(find_type) in tile
			if(thing)
				refs += WEAKREF(thing)
		entry = list(world.time + WORKER_FIXTURES_REFRESH, refs)
		found[key] = entry
	for(var/datum/weakref/ref as anything in entry[2])
		var/atom/thing = ref.resolve()
		if(!QDELETED(thing))
			. += thing

/// Where `npc` stands to use `thing`: on its tile if they can stand there (a wall-hung sink), beside it otherwise
/proc/ambient_use_spot(mob/living/basic/ambient_npc/npc, atom/thing, list/avoid)
	var/turf/tile = get_turf(thing)
	if(!tile)
		return null
	if(npc.standable(tile, avoid))
		return tile
	return npc.free_tile_beside(thing, 1, avoid)

// =========================================================================
// THE JANITOR
// =========================================================================

/// A mop, a bucket's worth of patience and two wet floor signs
/datum/outfit/ambient_janitor
	name = "Outpost janitor"
	uniform = /obj/item/clothing/under/rank/civilian/janitor
	gloves = /obj/item/clothing/gloves/color/purple
	head = /obj/item/clothing/head/soft/purple
	shoes = /obj/item/clothing/shoes/galoshes

/// Overalls and a beanie, galoshes for the wet bits
/datum/outfit/ambient_janitor/overalls
	name = "Outpost janitor (overalls)"
	uniform = /obj/item/clothing/under/misc/overalls
	suit = /obj/item/clothing/suit/apron/overalls
	head = /obj/item/clothing/head/beanie

/mob/living/basic/ambient_npc/outpost/worker/janitor
	desc = "Keeps the floors clean, more or less."
	dialogue_section = "janitor"
	outfit_choices = list(
		/datum/outfit/ambient_janitor,
		/datum/outfit/ambient_janitor/overalls,
	)
	routine = list(
		/datum/ambient_activity/mop_mess = 6,
		/datum/ambient_activity/work/janitor = 2,
		/datum/ambient_activity/wander = 2,
		/datum/ambient_activity/idle = 1,
	)
	/// Wet floor signs still with them
	var/signs_left = WORKER_JANITOR_SIGNS
	/// Tiles mopped lately: turf -> world.time
	var/list/mopped
	/// Mess they could not get to: turf -> world.time they may try again
	var/list/unreachable

/mob/living/basic/ambient_npc/outpost/worker/janitor/Initialize(mapload)
	. = ..()
	set_held(/obj/item/mop)

/mob/living/basic/ambient_npc/outpost/worker/janitor/Destroy()
	mopped = null
	unreachable = null
	return ..()

/// They could not get to the mess on `tile`: it is left alone for a few minutes
/mob/living/basic/ambient_npc/outpost/worker/janitor/proc/give_up_on(turf/tile)
	if(!tile)
		return
	LAZYSET(unreachable, tile, world.time + WORKER_REMOP_TIME)
	if(length(unreachable) > 12)
		unreachable.Cut(1, 2)

/mob/living/basic/ambient_npc/outpost/worker/janitor/pick_activity()
	// What was on the floor before anyone looked is the map's, not a mess
	ambient_outpost_mark_decor(place)
	return ..()

/// Found mid-job: mopping somewhere on the floor
/mob/living/basic/ambient_npc/outpost/worker/janitor/settle_in()
	ambient_outpost_mark_decor(place)
	if(settle_at(/datum/ambient_activity/work/janitor))
		return TRUE
	return ..()

/// Whether `tile` is a doorway or the tile before an airlock
/proc/ambient_by_a_door(turf/tile)
	if(locate(/obj/machinery/door) in tile)
		return TRUE
	for(var/direction in GLOB.cardinals)
		if(locate(/obj/machinery/door/airlock) in get_step(tile, direction))
			return TRUE
	return FALSE

/// Whatever the janitor would clean on `tile`: fresh mess decals and dropped food wrappers
/proc/ambient_outpost_mess_on(turf/tile)
	. = list()
	if(!tile)
		return
	for(var/obj/effect/decal/cleanable/decal in tile)
		if(ambient_is_mess(decal))
			. += decal
	for(var/obj/item/trash/junk in tile)
		if(!junk.anchored)
			. += junk

/// Where to stand to mop `tile`: beside it, or on it
/mob/living/basic/ambient_npc/outpost/worker/janitor/proc/mop_spot(turf/tile, list/avoid)
	if(!tile || !leash_ok(tile) || LAZYACCESS(unreachable, tile) > world.time)
		return null
	var/turf/stand = free_tile_beside(tile, 1, avoid)
	if(!stand && standable(tile, avoid))
		stand = tile
	return stand

/**
 * The nearest tile with mess on it they could get to, or null. However much mess is about, no more
 * than WORKER_MESS_SPOT_CHECKS tiles are checked for a place to stand, nearest first.
 */
/mob/living/basic/ambient_npc/outpost/worker/janitor/proc/find_mess()
	var/turf/here = get_turf(src)
	if(!here)
		return null
	// Mess tiles by distance: list index is distance + 1
	var/list/by_distance = new /list(WORKER_MESS_RANGE + 1)
	for(var/obj/effect/decal/cleanable/decal in range(WORKER_MESS_RANGE, here))
		if(ambient_is_mess(decal))
			ambient_add_by_distance(by_distance, here, get_turf(decal))
	for(var/obj/item/trash/junk in range(WORKER_MESS_RANGE, here))
		if(isturf(junk.loc) && !junk.anchored)
			ambient_add_by_distance(by_distance, here, junk.loc)
	var/checks = 0
	for(var/list/ring as anything in by_distance)
		for(var/turf/tile as anything in ring)
			if(mop_spot(tile))
				return tile
			if(++checks >= WORKER_MESS_SPOT_CHECKS)
				return null
	return null

/// Adds `tile` to `by_distance` (a list of lists, index distance + 1 from `from`), once
/proc/ambient_add_by_distance(list/by_distance, turf/from, turf/tile)
	var/index = get_dist(from, tile) + 1
	if(!tile || index > length(by_distance))
		return
	var/list/ring = by_distance[index]
	if(!ring)
		ring = list()
		by_distance[index] = ring
	ring |= tile

/**
 * Someone made `mess` near them: they come and mop it, unless they are busy with something that
 * matters more or it is too far. TRUE if they are on their way.
 */
/mob/living/basic/ambient_npc/outpost/worker/janitor/proc/notice_mess(obj/effect/decal/cleanable/mess)
	if(!can_act() || QDELETED(mess) || get_dist(src, mess) > WORKER_MESS_RANGE * 2)
		return FALSE
	if(istype(activity, /datum/ambient_activity/mop_mess) || activity?.priority > AMBIENT_PRIORITY_ROUTINE)
		return FALSE
	return !!start_activity(new /datum/ambient_activity/mop_mess(src, mess))

/// Cleans `tile`: its fresh mess and wrappers go, nothing else is touched
/mob/living/basic/ambient_npc/outpost/worker/janitor/proc/clean_tile(turf/tile)
	for(var/atom/movable/mess as anything in ambient_outpost_mess_on(tile))
		qdel(mess)
	LAZYSET(mopped, tile, world.time)
	if(length(mopped) > 12)
		mopped.Cut(1, 2)

/// Whether they mopped `tile` a little while ago
/mob/living/basic/ambient_npc/outpost/worker/janitor/proc/mopped_recently(turf/tile)
	return LAZYACCESS(mopped, tile) && world.time - mopped[tile] < WORKER_REMOP_TIME

/**
 * Mopping up one mess: over to it, a wet floor sign down on it (while they still have one), a few
 * strokes of the mop, and the mess is gone. The floor stays wet while the sign stands; then they
 * take the sign back. With no sign left they mop it dry.
 */
/datum/ambient_activity/mop_mess
	name = "mopping up"
	/// The tile being mopped
	var/turf/mess_tile
	/// The sign they put down
	var/datum/weakref/sign_ref
	/// world.time the mopping is done
	var/mop_until = 0
	/// world.time the floor is dry again
	var/dry_until = 0
	/// The mess is gone
	var/mopped = FALSE
	/// They left the floor wet (and dry it when the sign comes up)
	var/wetted = FALSE

/datum/ambient_activity/mop_mess/setup()
	var/mob/living/basic/ambient_npc/outpost/worker/janitor/janitor = doer
	if(!istype(janitor))
		return FALSE
	var/turf/tile = get_turf(anchor())
	if(!tile || !length(ambient_outpost_mess_on(tile)))
		tile = janitor.find_mess()
	if(!tile)
		return FALSE
	var/turf/stand = janitor.mop_spot(tile, failed_spots)
	if(!stand)
		return FALSE
	mess_tile = tile
	go_to(stand)
	return TRUE

/datum/ambient_activity/mop_mess/Destroy()
	mess_tile = null
	sign_ref = null
	return ..()

/datum/ambient_activity/mop_mess/arrive()
	var/mob/living/basic/ambient_npc/outpost/worker/janitor/janitor = doer
	if(!mess_tile)
		return
	if(mess_tile != get_turf(doer) && !doer.buckled)
		doer.face_atom(mess_tile)
	if(janitor.mopped_recently(mess_tile))
		doer.speak_context("remop", null, force = TRUE)
	else if(prob(40))
		doer.speak_context("mess")
	put_sign()
	mop_until = world.time + rand(6 SECONDS, 10 SECONDS)

/// A wet floor sign on the mess, if they have one left
/datum/ambient_activity/mop_mess/proc/put_sign()
	var/mob/living/basic/ambient_npc/outpost/worker/janitor/janitor = doer
	if(janitor.signs_left <= 0 || !isopenturf(mess_tile) || mess_tile.is_blocked_turf(exclude_mobs = TRUE))
		return
	janitor.signs_left--
	var/obj/item/clothing/suit/caution/sign = new(mess_tile)
	sign_ref = WEAKREF(sign)
	if(prob(50))
		doer.speak_context("sign")

/datum/ambient_activity/mop_mess/act(seconds)
	if(!mess_tile)
		return AMBIENT_STEP_DONE
	if(!mopped)
		if(world.time < mop_until)
			if(prob(60))
				playsound(doer, 'sound/effects/slosh.ogg', 20, TRUE, -4)
			if(!doer.buckled)
				doer.setDir(turn(get_dir(doer, mess_tile) || doer.dir, pick(90, -90)))
			return AMBIENT_STEP_CONTINUE
		mopped = TRUE
		var/mob/living/basic/ambient_npc/outpost/worker/janitor/janitor = doer
		janitor.clean_tile(mess_tile)
		// Wet only under their own sign, and never in or at a doorway
		var/obj/item/clothing/suit/caution/sign = sign_ref?.resolve()
		if(sign && sign.loc == mess_tile && isopenturf(mess_tile) && !ambient_by_a_door(mess_tile))
			var/turf/open/floor = mess_tile
			floor.MakeSlippery(TURF_WET_WATER, min_wet_time = WORKER_WET_TIME, wet_time_to_add = 0, max_wet_time = WORKER_WET_TIME)
			wetted = TRUE
			dry_until = world.time + WORKER_WET_TIME
		return AMBIENT_STEP_CONTINUE
	if(world.time < dry_until)
		chatter(AMBIENT_LINE_WORK, 20 SECONDS, 40 SECONDS)
		return AMBIENT_STEP_CONTINUE
	take_sign()
	return AMBIENT_STEP_DONE

/// Back under their arm goes the sign (and the floor is dry). A sign someone walked off with gets a word.
/datum/ambient_activity/mop_mess/proc/take_sign()
	if(!sign_ref)
		return
	var/obj/item/clothing/suit/caution/sign = sign_ref.resolve()
	sign_ref = null
	if(wetted && isopenturf(mess_tile))
		wetted = FALSE
		var/turf/open/floor = mess_tile
		floor.MakeDry(TURF_WET_WATER, TRUE)
	var/mob/living/basic/ambient_npc/outpost/worker/janitor/janitor = doer
	if(!QDELETED(sign) && isturf(sign.loc) && get_dist(sign, doer) <= 2)
		qdel(sign)
		if(istype(janitor))
			janitor.signs_left++
		return
	// Picked up, carried off, or anywhere but where they left it
	if(!QDELETED(doer))
		doer.speak_context("sign_taken", null, force = TRUE)

/datum/ambient_activity/mop_mess/finish()
	take_sign()
	return ..()

/datum/ambient_activity/mop_mess/spot_unreachable()
	. = ..()
	var/mob/living/basic/ambient_npc/outpost/worker/janitor/janitor = doer
	if(istype(janitor))
		janitor.give_up_on(mess_tile)
	mess_tile = null

/datum/ambient_activity/mop_mess/shift_times(delay)
	. = ..()
	mop_until = ambient_shifted(mop_until, delay)
	dry_until = ambient_shifted(dry_until, delay)

/// Mopping round the floor with the mechanics' work loop when nothing needs cleaning
/datum/ambient_activity/work/janitor
	name = "mopping"
	work_weights = list(/datum/outpost_ambient_work/mop = 1)

// =========================================================================
// THE GARDENER
// =========================================================================

/// Botanist's jumpsuit and apron, leather gloves, a green cap
/datum/outfit/ambient_gardener
	name = "Outpost gardener"
	uniform = /obj/item/clothing/under/rank/civilian/hydroponics
	suit = /obj/item/clothing/suit/apron
	gloves = /obj/item/clothing/gloves/botanic_leather
	head = /obj/item/clothing/head/soft/green
	shoes = /obj/item/clothing/shoes/workboots

/// Overalls, a flat cap and galoshes for the wet soil
/datum/outfit/ambient_gardener/overalls
	name = "Outpost gardener (overalls)"
	uniform = /obj/item/clothing/under/misc/overalls
	suit = /obj/item/clothing/suit/apron/overalls
	head = /obj/item/clothing/head/flatcap
	shoes = /obj/item/clothing/shoes/galoshes

/mob/living/basic/ambient_npc/outpost/worker/gardener
	desc = "Looks after the outpost's plants."
	dialogue_section = "gardener"
	outfit_choices = list(
		/datum/outfit/ambient_gardener,
		/datum/outfit/ambient_gardener/overalls,
	)
	routine = list(
		/datum/ambient_activity/tend_plants = 6,
		/datum/ambient_activity/wander = 1,
		/datum/ambient_activity/idle = 1,
		/datum/ambient_activity/chat = 1,
	)
	/// Pours left in the watering can
	var/can_water = WORKER_CAN_POURS
	/// Weakrefs to the trays they watered last
	var/list/tended

/mob/living/basic/ambient_npc/outpost/worker/gardener/Initialize(mapload)
	. = ..()
	can_water = rand(1, WORKER_CAN_POURS)
	set_held(/obj/item/reagent_containers/cup/watering_can)

/mob/living/basic/ambient_npc/outpost/worker/gardener/Destroy()
	tended = null
	return ..()

/// Found mid-job: at one of the outpost's trays with the watering can
/mob/living/basic/ambient_npc/outpost/worker/gardener/settle_in()
	if(settle_at(/datum/ambient_activity/tend_plants, null, 1))
		return TRUE
	return ..()

/// Whether they watered `tray` lately
/mob/living/basic/ambient_npc/outpost/worker/gardener/proc/tended_lately(obj/machinery/hydroponics/tray)
	for(var/datum/weakref/ref as anything in tended)
		if(ref.resolve() == tray)
			return TRUE
	return FALSE

/// Remembers watering `tray`
/mob/living/basic/ambient_npc/outpost/worker/gardener/proc/remember_tray(obj/machinery/hydroponics/tray)
	LAZYADD(tended, WEAKREF(tray))
	if(length(tended) > WORKER_TENDED_MEMORY)
		tended.Cut(1, 2)

/**
 * The next of the outpost's own trays to water: the driest one they did not just water, and could
 * stand beside (never near a hive). Trays a player brought or built are left alone.
 */
/mob/living/basic/ambient_npc/outpost/worker/gardener/proc/find_tray(list/avoid)
	var/obj/structure/overmap/trader_outpost/outpost = get_outpost()
	var/obj/machinery/hydroponics/best
	var/best_score = INFINITY
	for(var/obj/machinery/hydroponics/tray as anything in ambient_outpost_find_all(outpost, /obj/machinery/hydroponics))
		if(!HAS_TRAIT(tray, TRAIT_OUTPOST_PROPERTY) || tended_lately(tray) || !leash_ok(get_turf(tray)))
			continue
		if(tray.waterlevel >= tray.maxwater)
			continue
		var/score = tray.waterlevel + get_dist(src, tray) * 2
		if(score < best_score && free_tile_beside(tray, 1, avoid))
			best = tray
			best_score = score
	return best

/// The nearest sink they could fill the can at, or null
/mob/living/basic/ambient_npc/outpost/worker/gardener/proc/find_sink(list/avoid)
	var/obj/structure/sink/best
	var/best_distance = INFINITY
	for(var/obj/structure/sink/sink as anything in ambient_outpost_find_all(get_outpost(), /obj/structure/sink))
		var/distance = get_dist(src, sink)
		if(distance < best_distance && ambient_use_spot(src, sink, avoid))
			best = sink
			best_distance = distance
	return best

/**
 * Tending the plants: the next dry tray gets a pour from the watering can and a word; an empty can
 * is filled at the nearest sink first.
 */
/datum/ambient_activity/tend_plants
	name = "watering the plants"
	/// What they are at: the tray, or the sink
	var/datum/weakref/target_ref
	/// Filling the can rather than watering
	var/refilling = FALSE
	/// world.time they are done here
	var/done_at = 0

/datum/ambient_activity/tend_plants/setup()
	var/mob/living/basic/ambient_npc/outpost/worker/gardener/gardener = doer
	if(!istype(gardener))
		return FALSE
	var/atom/target
	var/turf/stand
	if(gardener.can_water <= 0)
		var/obj/structure/sink/sink = gardener.find_sink(failed_spots)
		if(sink)
			refilling = TRUE
			target = sink
			stand = ambient_use_spot(gardener, sink, failed_spots)
		else
			// Nowhere to fill it: a watering can that is never empty is better than a gardener who stops
			gardener.can_water = WORKER_CAN_POURS
	if(!target)
		var/obj/machinery/hydroponics/tray = gardener.find_tray(failed_spots)
		if(!tray)
			return FALSE
		target = tray
		stand = gardener.free_tile_beside(tray, 1, failed_spots)
	if(!stand)
		return FALSE
	target_ref = WEAKREF(target)
	go_to(stand)
	return TRUE

/datum/ambient_activity/tend_plants/Destroy()
	target_ref = null
	return ..()

/datum/ambient_activity/tend_plants/arrive()
	var/atom/target = target_ref?.resolve()
	if(target && get_turf(target) != get_turf(doer) && !doer.buckled)
		doer.face_atom(target)
	done_at = world.time + rand(4 SECONDS, 7 SECONDS)
	if(!refilling && prob(40))
		doer.speak_context("water")

/datum/ambient_activity/tend_plants/act(seconds)
	var/mob/living/basic/ambient_npc/outpost/worker/gardener/gardener = doer
	var/atom/target = target_ref?.resolve()
	if(QDELETED(target) || !istype(gardener))
		return AMBIENT_STEP_DONE
	if(world.time < done_at)
		if(prob(40))
			playsound(doer, refilling ? 'sound/machines/sink-faucet.ogg' : 'sound/effects/slosh.ogg', 20, TRUE, -4)
		return AMBIENT_STEP_CONTINUE
	if(refilling)
		gardener.can_water = WORKER_CAN_POURS
		return AMBIENT_STEP_DONE
	var/obj/machinery/hydroponics/tray = target
	if(istype(tray) && HAS_TRAIT(tray, TRAIT_OUTPOST_PROPERTY))
		tray.adjust_waterlevel(WORKER_TRAY_WATER)
		tray.update_appearance()
		gardener.can_water--
		gardener.remember_tray(tray)
	return AMBIENT_STEP_DONE

/**
 * Could not get there: nothing is watered from across the room. They move on to another tray next
 * time, and a sink they cannot reach is given up on (the can is filled somewhere else).
 */
/datum/ambient_activity/tend_plants/spot_unreachable()
	. = ..()
	var/mob/living/basic/ambient_npc/outpost/worker/gardener/gardener = doer
	var/obj/machinery/hydroponics/tray = target_ref?.resolve()
	target_ref = null
	if(!istype(gardener))
		return
	if(refilling)
		gardener.can_water = WORKER_CAN_POURS
	else if(istype(tray))
		gardener.remember_tray(tray)

/datum/ambient_activity/tend_plants/shift_times(delay)
	. = ..()
	done_at = ambient_shifted(done_at, delay)

// =========================================================================
// THE BARBACK
// =========================================================================

/// White shirt, black trousers, a clean apron
/datum/outfit/ambient_barback
	name = "Outpost barback"
	uniform = /obj/item/clothing/under/costume/buttondown/slacks/service
	suit = /obj/item/clothing/suit/apron/chef
	shoes = /obj/item/clothing/shoes/laceup

/// A grey jumpsuit under the apron and a beanie
/datum/outfit/ambient_barback/beanie
	name = "Outpost barback (beanie)"
	uniform = /obj/item/clothing/under/color/grey
	head = /obj/item/clothing/head/beanie

/mob/living/basic/ambient_npc/outpost/worker/barback
	desc = "Clears the glasses, wipes the tables and walks out whoever can't walk."
	dialogue_section = "barback"
	outfit_choices = list(
		/datum/outfit/ambient_barback,
		/datum/outfit/ambient_barback/beanie,
	)
	routine = list(
		/datum/ambient_activity/collect_glasses = 5,
		/datum/ambient_activity/work/barback = 2,
		/datum/ambient_activity/wander = 2,
		/datum/ambient_activity/idle = 1,
		/datum/ambient_activity/chat = 1,
	)
	/// Empty glasses on their tray
	var/glasses = 0

/mob/living/basic/ambient_npc/outpost/worker/barback/pick_activity()
	var/list/bar = ambient_outpost_bar(place)
	var/atom/bar_spot = length(bar) ? bar[1] : null
	if(glasses >= WORKER_TRAY_MAX || (glasses > 0 && prob(30)))
		var/datum/ambient_activity/wash = start_activity(new /datum/ambient_activity/wash_glasses(src, bar_spot))
		if(wash)
			return wash
	// Glasses are looked for, and strolls taken, round the bar
	return pick_anchored(routine, bar_spot, list(/datum/ambient_activity/collect_glasses, /datum/ambient_activity/wander))

/// Found mid-job: wiping down tables round the bar
/mob/living/basic/ambient_npc/outpost/worker/barback/settle_in()
	var/list/bar = ambient_outpost_bar(place)
	var/atom/bar_spot = length(bar) ? bar[1] : null
	if(bar_spot && settle_at(/datum/ambient_activity/work/barback, null, AMBIENT_SETTLE_TRIES, bar_spot))
		return TRUE
	return ..()

/// An empty drinking glass left on a table or the floor near `center` that they could reach, or null
/mob/living/basic/ambient_npc/outpost/worker/barback/proc/find_glass(atom/center, list/avoid)
	var/turf/middle = get_turf(center) || get_turf(src)
	if(!middle)
		return null
	var/obj/item/reagent_containers/cup/glass/drinkingglass/best
	var/best_distance = INFINITY
	for(var/obj/item/reagent_containers/cup/glass/drinkingglass/glass in range(WORKER_BAR_RANGE, middle))
		if(!ambient_glass_is_empty(glass) || !leash_ok(glass.loc))
			continue
		var/distance = get_dist(src, glass)
		if(distance < best_distance && ambient_use_spot(src, glass, avoid))
			best = glass
			best_distance = distance
	return best

/// Whether `glass` is an empty glass left lying about: on a turf, nothing in it
/proc/ambient_glass_is_empty(obj/item/reagent_containers/cup/glass/drinkingglass/glass)
	return istype(glass) && !QDELETED(glass) && isturf(glass.loc) && !glass.reagents?.total_volume

/// Collecting empties: over to one, and every empty glass on that spot goes on the tray
/datum/ambient_activity/collect_glasses
	name = "collecting glasses"
	var/datum/weakref/glass_ref
	/// world.time they pick them up
	var/pick_at = 0

/datum/ambient_activity/collect_glasses/setup()
	var/mob/living/basic/ambient_npc/outpost/worker/barback/barback = doer
	if(!istype(barback) || barback.glasses >= WORKER_TRAY_MAX)
		return FALSE
	var/obj/item/reagent_containers/cup/glass/drinkingglass/glass = barback.find_glass(anchor(), failed_spots)
	if(!glass)
		return FALSE
	glass_ref = WEAKREF(glass)
	go_to(ambient_use_spot(barback, glass, failed_spots))
	return TRUE

/datum/ambient_activity/collect_glasses/Destroy()
	glass_ref = null
	return ..()

/datum/ambient_activity/collect_glasses/arrive()
	var/obj/item/glass = glass_ref?.resolve()
	if(glass && glass.loc != doer.loc && !doer.buckled)
		doer.face_atom(glass)
	pick_at = world.time + rand(1 SECONDS, 2 SECONDS)

/datum/ambient_activity/collect_glasses/act(seconds)
	var/mob/living/basic/ambient_npc/outpost/worker/barback/barback = doer
	var/obj/item/reagent_containers/cup/glass/drinkingglass/glass = glass_ref?.resolve()
	if(!ambient_glass_is_empty(glass) || !istype(barback))
		return AMBIENT_STEP_DONE
	if(world.time < pick_at)
		return AMBIENT_STEP_CONTINUE
	var/turf/spot = glass.loc
	var/on_floor = !(locate(/obj/structure/table) in spot)
	for(var/obj/item/reagent_containers/cup/glass/drinkingglass/empty in spot.contents.Copy())
		if(barback.glasses >= WORKER_TRAY_MAX)
			break
		if(!ambient_glass_is_empty(empty))
			continue
		qdel(empty)
		barback.glasses++
	playsound(barback, 'sound/items/handling/drinkglass_pickup.ogg', 30, TRUE, -4)
	barback.set_held(/obj/item/storage/bag/tray)
	if(prob(40))
		barback.speak_context(on_floor ? "floor_glass" : "glasses")
	return AMBIENT_STEP_DONE

/// Could not get there: that glass is not picked up from across the room
/datum/ambient_activity/collect_glasses/spot_unreachable()
	. = ..()
	glass_ref = null

/datum/ambient_activity/collect_glasses/shift_times(delay)
	. = ..()
	pick_at = ambient_shifted(pick_at, delay)

/**
 * Washing up: the tray of empties to the nearest sink near the bar (or back over the bar to the
 * barkeep), and they are gone.
 */
/datum/ambient_activity/wash_glasses
	name = "washing glasses"
	var/datum/weakref/target_ref
	var/done_at = 0

/datum/ambient_activity/wash_glasses/setup()
	var/mob/living/basic/ambient_npc/outpost/worker/barback/barback = doer
	if(!istype(barback) || barback.glasses <= 0)
		return FALSE
	var/atom/bar = anchor()
	var/turf/center = get_turf(bar) || get_turf(doer)
	var/atom/target
	var/turf/stand
	var/best_distance = INFINITY
	for(var/obj/structure/sink/sink as anything in ambient_outpost_find_all(barback.get_outpost(), /obj/structure/sink))
		var/distance = get_dist(center, sink)
		if(distance > WORKER_SINK_RANGE || distance >= best_distance)
			continue
		var/turf/spot = ambient_use_spot(barback, sink, failed_spots)
		if(spot)
			target = sink
			stand = spot
			best_distance = distance
	var/mob/living/basic/outpost_trader/barkeep = bar
	if(!target && istype(barkeep) && !ambient_counter_customer(barkeep))
		stand = ambient_nearest_tile(doer, ambient_counter_spots(doer, barkeep, failed_spots))
		target = stand ? barkeep : null
	if(!target)
		// Nowhere to take them: they go out the back with the rest
		barback.glasses = 0
		barback.set_held(null)
		return FALSE
	target_ref = WEAKREF(target)
	go_to(stand)
	return TRUE

/datum/ambient_activity/wash_glasses/Destroy()
	target_ref = null
	return ..()

/datum/ambient_activity/wash_glasses/arrive()
	var/atom/target = target_ref?.resolve()
	if(target && get_turf(target) != get_turf(doer) && !doer.buckled)
		doer.face_atom(target)
	done_at = world.time + rand(4 SECONDS, 7 SECONDS)

/datum/ambient_activity/wash_glasses/act(seconds)
	var/mob/living/basic/ambient_npc/outpost/worker/barback/barback = doer
	var/atom/target = target_ref?.resolve()
	if(QDELETED(target) || !istype(barback))
		return AMBIENT_STEP_DONE
	if(world.time < done_at)
		if(prob(50))
			playsound(barback, istype(target, /obj/structure/sink) ? 'sound/machines/sink-faucet.ogg' : 'sound/items/handling/drinkglass_drop.ogg', 20, TRUE, -4)
		return AMBIENT_STEP_CONTINUE
	barback.glasses = 0
	barback.set_held(null)
	return AMBIENT_STEP_DONE

/// Could not get to the sink: the tray goes out the back instead of trying the same sink again
/datum/ambient_activity/wash_glasses/spot_unreachable()
	. = ..()
	target_ref = null
	var/mob/living/basic/ambient_npc/outpost/worker/barback/barback = doer
	if(istype(barback))
		barback.glasses = 0
		barback.set_held(null)

/datum/ambient_activity/wash_glasses/shift_times(delay)
	. = ..()
	done_at = ambient_shifted(done_at, delay)

/// Wiping down tables with the mechanics' work loop
/datum/ambient_activity/work/barback
	name = "wiping tables"
	work_weights = list(/datum/outpost_ambient_work/wipe = 1)

/**
 * Walking a passed-out drinker to the lift: over to them, a word to wake them, and beside them all
 * the way while they leave.
 */
/datum/ambient_activity/escort
	name = "walking someone out"
	duration_low = 2 MINUTES
	duration_high = 2 MINUTES
	/// They woke the drunk and set them off
	var/woke = FALSE

/datum/ambient_activity/escort/setup()
	var/mob/living/basic/ambient_npc/drunk = anchor()
	if(!istype(drunk) || drunk.stat != CONSCIOUS || drunk.fading)
		return FALSE
	go_to(get_turf(drunk), 1)
	set_duration()
	return TRUE

/datum/ambient_activity/escort/arrive()
	var/mob/living/basic/ambient_npc/drunk = anchor()
	if(!drunk || woke)
		return
	woke = TRUE
	if(!doer.buckled)
		doer.face_atom(drunk)
	doer.speak_context("escort", drunk, force = TRUE)
	drunk.start_activity(new /datum/ambient_activity/leave(drunk))

/datum/ambient_activity/escort/act(seconds)
	var/mob/living/basic/ambient_npc/drunk = anchor()
	if(!drunk || drunk.fading || drunk.stat != CONSCIOUS || !istype(drunk.activity, /datum/ambient_activity/leave))
		return AMBIENT_STEP_DONE
	// They can manage the last few steps to the lift; the barback stays off it
	var/mob/living/basic/ambient_npc/outpost/barback = doer
	var/obj/structure/overmap/trader_outpost/outpost = istype(barback) ? barback.get_outpost() : null
	for(var/turf/alcove as anything in outpost?.lobby_alcove_turfs)
		if(alcove.z == drunk.z && get_dist(alcove, drunk) <= 2)
			return AMBIENT_STEP_DONE
	if(get_dist(doer, drunk) > 1)
		go_to(get_turf(drunk), 1)
		return AMBIENT_STEP_MOVE
	if(!doer.buckled)
		doer.face_atom(drunk)
	return AMBIENT_STEP_CONTINUE

// =========================================================================
// THE DOCK WORKER
// =========================================================================

/// Cargo jumpsuit, hi-vis, hauling gauntlets and an orange hard hat
/datum/outfit/ambient_dock_worker
	name = "Depot dock worker"
	uniform = /obj/item/clothing/under/rank/cargo/tech
	suit = /obj/item/clothing/suit/hazardvest
	gloves = /obj/item/clothing/gloves/cargo_gauntlet
	head = /obj/item/clothing/head/utility/hardhat/orange
	shoes = /obj/item/clothing/shoes/workboots

/// Overalls under the hi-vis and a yellow hard hat
/datum/outfit/ambient_dock_worker/overalls
	name = "Depot dock worker (overalls)"
	uniform = /obj/item/clothing/under/misc/overalls
	head = /obj/item/clothing/head/utility/hardhat

/mob/living/basic/ambient_npc/outpost/worker/dock
	desc = "Moves the depot's freight, one crate at a time."
	dialogue_section = "dock_worker"
	outfit_choices = list(
		/datum/outfit/ambient_dock_worker,
		/datum/outfit/ambient_dock_worker/overalls,
	)
	routine = list(
		/datum/ambient_activity/work/dock = 4,
		/datum/ambient_activity/drink/coffee = 1,
		/datum/ambient_activity/wander = 1,
		/datum/ambient_activity/idle = 1,
		/datum/ambient_activity/chat = 1,
	)

/mob/living/basic/ambient_npc/outpost/worker/dock/pick_activity()
	// The coffee break is taken by the crew room's machine
	return pick_anchored(routine, ambient_outpost_find(get_outpost(), /obj/machinery/vending/coffee), list(/datum/ambient_activity/drink/coffee))

/// Found mid-job hauling freight, or else on a coffee break by the crew room's machine
/mob/living/basic/ambient_npc/outpost/worker/dock/settle_in()
	if(settle_at(/datum/ambient_activity/work/dock))
		return TRUE
	var/obj/machinery/vending/coffee/machine = ambient_outpost_find(get_outpost(), /obj/machinery/vending/coffee)
	if(machine && settle_at(/datum/ambient_activity/drink/coffee, machine, 1))
		return TRUE
	return ..()

/// The convoy is in: everything down, and the crates come off the lift
/mob/living/basic/ambient_npc/outpost/worker/dock/react_convoy(obj/structure/overmap/trader_outpost/outpost)
	if(stat != CONSCIOUS || fading || istype(activity, /datum/ambient_activity/convoy_unload))
		return
	start_activity(new /datum/ambient_activity/convoy_unload(src))

/// Hauling boxes along the intake row with the mechanics' work loop
/datum/ambient_activity/work/dock
	name = "stacking freight"
	work_weights = list(/datum/outpost_ambient_work/haul = 1)

/// A coffee from the crew room's machine, sat down somewhere near it
/datum/ambient_activity/drink/coffee
	name = "on a coffee break"
	reagent_type = /datum/reagent/consumable/coffee
	duration_low = 1 MINUTES
	duration_high = 2 MINUTES

/datum/ambient_activity/drink/coffee/setup()
	if(!anchor())
		return FALSE
	return ..()

/datum/ambient_activity/drink/coffee/finish()
	var/obj/item/reagent_containers/cup/glass/drinkingglass/glass = doer?.held_item
	if(istype(glass))
		glass.reagents?.clear_reagents()
	if(!QDELETED(doer) && !ambient_outpost_has_barback(doer.place))
		table_ref = null
	return ..()

/**
 * Unloading the convoy: sealed crates from beside the lift to the loading area in front of the
 * depot's counter, a few trips over about a minute and a half. The crates are part of the look:
 * they go when they are set down, and the shelves are the convoy's business, not theirs.
 */
/datum/ambient_activity/convoy_unload
	name = "unloading the convoy"
	priority = AMBIENT_PRIORITY_REACTION
	/// Crates still to carry
	var/trips_left = WORKER_CONVOY_TRIPS
	/// A crate in their arms
	var/carrying = FALSE
	/// Beside the lift
	var/turf/pickup
	/// In front of the counter, out of the customers' way
	var/turf/dropoff
	/// The trader whose counter it goes to
	var/datum/weakref/trader_ref
	/// world.time they are done lifting or setting down
	var/wait_until = 0

/datum/ambient_activity/convoy_unload/setup()
	var/mob/living/basic/ambient_npc/outpost/worker/dock/worker = doer
	var/obj/structure/overmap/trader_outpost/outpost = istype(worker) ? worker.get_outpost() : null
	if(!outpost)
		return FALSE
	var/mob/living/basic/outpost_trader/trader = outpost.trader
	if(QDELETED(trader))
		var/list/traders = ambient_outpost_traders(doer.place)
		trader = length(traders) ? traders[1] : null
	if(!trader)
		return FALSE
	var/list/lift_spots = list()
	for(var/turf/alcove as anything in outpost.lobby_alcove_turfs)
		var/turf/spot = ambient_waiting_spot(doer, alcove, 2, 3, failed_spots, loiter = FALSE)
		if(spot)
			lift_spots += spot
	pickup = ambient_nearest_tile(doer, lift_spots)
	dropoff = ambient_waiting_spot(doer, trader, 3, 4, failed_spots, loiter = FALSE)
	if(!pickup || !dropoff)
		return FALSE
	trader_ref = WEAKREF(trader)
	go_to(pickup)
	if(prob(60))
		doer.speak_context("convoy", null, force = TRUE)
	return TRUE

/datum/ambient_activity/convoy_unload/Destroy()
	pickup = null
	dropoff = null
	trader_ref = null
	return ..()

/datum/ambient_activity/convoy_unload/arrive()
	wait_until = world.time + rand(2 SECONDS, 4 SECONDS)

/datum/ambient_activity/convoy_unload/act(seconds)
	if(world.time < wait_until)
		return AMBIENT_STEP_CONTINUE
	if(!carrying)
		carrying = TRUE
		doer.set_held(/obj/structure/closet/crate)
		playsound(doer, 'sound/items/handling/cardboard_box/cardboardbox_pickup.ogg', 30, TRUE, -4)
		chatter("crate", 20 SECONDS, 40 SECONDS)
		go_to(dropoff)
		return AMBIENT_STEP_MOVE
	carrying = FALSE
	doer.set_held(null)
	playsound(doer, 'sound/items/handling/cardboard_box/cardboardbox_drop.ogg', 30, TRUE, -4)
	if(--trips_left <= 0)
		var/mob/living/basic/outpost_trader/trader = trader_ref?.resolve()
		if(trader && prob(50))
			ambient_trader_reply(trader, doer, AMBIENT_STRINGS_WORKERS, "sarge_convoy", "trader_reply", 6)
		return AMBIENT_STEP_DONE
	go_to(pickup)
	return AMBIENT_STEP_MOVE

/datum/ambient_activity/convoy_unload/finish()
	if(carrying && !QDELETED(doer))
		doer.set_held(null)
	carrying = FALSE
	return ..()

/datum/ambient_activity/convoy_unload/spot_unreachable()
	. = ..()
	trips_left = 0
	ends_at = world.time

/datum/ambient_activity/convoy_unload/shift_times(delay)
	. = ..()
	wait_until = ambient_shifted(wait_until, delay)

// =========================================================================
// WHO WORKS WHERE
// =========================================================================

/// A janitor at Quartermain
/datum/ambient_outpost_role/janitor
	name = "janitor"
	npc_type = /mob/living/basic/ambient_npc/outpost/worker/janitor
	outpost_types = list(/obj/structure/overmap/trader_outpost/outfitter)
	max_count = 1
	weight = 3
	gap_low = 1 MINUTES
	gap_high = 2 MINUTES

/// A gardener for Halcyon's conservatory and dome
/datum/ambient_outpost_role/gardener
	name = "gardener"
	npc_type = /mob/living/basic/ambient_npc/outpost/worker/gardener
	outpost_types = list(/obj/structure/overmap/trader_outpost/general)
	max_count = 1
	weight = 3
	gap_low = 1 MINUTES
	gap_high = 2 MINUTES

/// A barback at the Dregs
/datum/ambient_outpost_role/barback
	name = "barback"
	npc_type = /mob/living/basic/ambient_npc/outpost/worker/barback
	outpost_types = list(/obj/structure/overmap/trader_outpost/black_market)
	max_count = 1
	weight = 3
	gap_low = 1 MINUTES
	gap_high = 2 MINUTES

/// A dock worker at Quartermain
/datum/ambient_outpost_role/dock_worker
	name = "dock worker"
	npc_type = /mob/living/basic/ambient_npc/outpost/worker/dock
	outpost_types = list(/obj/structure/overmap/trader_outpost/outfitter)
	max_count = 1
	weight = 3
	gap_low = 1 MINUTES
	gap_high = 3 MINUTES

#undef WORKER_MESS_RANGE
#undef WORKER_MESS_SPOT_CHECKS
#undef WORKER_JANITOR_SIGNS
#undef WORKER_WET_TIME
#undef WORKER_REMOP_TIME
#undef WORKER_CAN_POURS
#undef WORKER_TRAY_WATER
#undef WORKER_TENDED_MEMORY
#undef WORKER_BAR_RANGE
#undef WORKER_TRAY_MAX
#undef WORKER_SINK_RANGE
#undef WORKER_CONVOY_TRIPS
#undef WORKER_FIXTURES_REFRESH
