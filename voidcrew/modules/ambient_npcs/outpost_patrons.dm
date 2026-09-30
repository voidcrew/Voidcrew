/**
 * # World population: customers and drinkers at the trader outposts (owner items 2 and 3)
 *
 * Built here (spec 3.1, 3.2):
 * - /mob/living/basic/ambient_npc/outpost: the base for everyone PA brings to a trader outpost
 *   (customers, drinkers, the staff in outpost_workers.dm, the angler in outpost_angler.dm). They
 *   keep out of the pond, doorways, the lift's mouth, the kingpin's lounge and the bees.
 * - Customers: to one or two counters, a line for that trader and the trader's answer in the
 *   trader's own voice, off with a paper bag, maybe a seat, then back to the lift. They yield the
 *   counter to players and wait in line. When players come, some are already at a counter and some
 *   are done shopping, part-way through their visit; one who leaves is replaced off the lift.
 * - Drinkers: at the Dregs, the Chowder Pot and Quartermain's crew room. They order from the
 *   barkeep (coffee at the crew room), sit, sip a real glass and get drunker every two sips of
 *   something strong: chatty, loud and singing, slurring and swaying, then asleep on a sofa. The
 *   barkeep cuts them off; the barback (outpost_workers.dm) walks them to the lift, or they wake
 *   and go by themselves. A drink handed to them is drunk. When players come, they are already
 *   in their seats with a glass, some a stage or two in.
 * - The outpost population rules: the /datum/ambient_outpost_role subtypes for both.
 * - The helpers the whole package shares: traders and their counters, a trader's answer, the bar,
 *   mess for the janitor.
 * Lines are in strings/outpost_patrons.json (AMBIENT_STRINGS_PATRONS).
 *
 * Seams (P0, frozen): /mob/living/basic/ambient_npc (speak_context(), reply_to(), talked_to(),
 * react_violence(), react_shootout(), react_convoy(), pick_activity(), `routine`), the activities
 * in ambient_activity.dm (idle, wander, sit, drink, chat, work, leave), /datum/ambient_outpost_role
 * (npc_type, outpost_types, max_count, weight, gap_low/gap_high, wanted(), arrive()),
 * SSambient_npcs.outpost_players(), SSambient_npcs.lift_arrival_turf(),
 * /datum/ambient_place/outpost (get_public_floor(), shootout_refuge), COMSIG_TRADER_OUTPOST_VIOLENCE
 * and COMSIG_TRADER_OUTPOST_CONVOY. Traders answer through their own say(); no shop file is edited.
 */

/// How far a customer may stand from a trader and still be served (TRADER_COUNTER_RANGE in trader_npc.dm)
#define PATRON_COUNTER_RANGE 2
/// Ambient NPCs at one trader's counter at once, so a player can always step up
#define PATRON_COUNTER_CROWD_MAX 2
/// How long a customer stays before heading back to the lift
#define PATRON_VISIT_LOW (4 MINUTES)
#define PATRON_VISIT_HIGH (8 MINUTES)
/// Most counters one customer visits
#define PATRON_STALLS_MAX 2
/// How long a customer waits behind a player before giving up on that counter
#define PATRON_QUEUE_PATIENCE (75 SECONDS)
/// A customer lingers this long at the counter after ordering
#define PATRON_SERVE_LOW (8 SECONDS)
#define PATRON_SERVE_HIGH (15 SECONDS)
/// How far from the bar a drinker looks for a seat
#define PATRON_BAR_RANGE 14
/// Sips of something strong per drunk stage
#define PATRON_SIPS_PER_STAGE 2
/// The stage at which they pass out
#define PATRON_DRUNK_MAX 4
/// A drinker sips this often
#define PATRON_SIP_LOW (20 SECONDS)
#define PATRON_SIP_HIGH (40 SECONDS)
/// Coffee sips at the crew room before something stronger
#define PATRON_COFFEE_SIPS 2
/// How long a drinker sleeps it off before going
#define PATRON_SLEEP_LOW (2 MINUTES)
#define PATRON_SLEEP_HIGH (4 MINUTES)
/// Chance, when a drinker reaches stage 3 or 4, that they are sick on the floor (once)
#define PATRON_VOMIT_CHANCE 20
/// Least time between two drinks handed to one drinker
#define PATRON_HANDED_COOLDOWN (20 SECONDS)
/// The bars, as sections of AMBIENT_STRINGS_PATRONS
#define PATRON_BAR_DREGS "bar_dregs"
#define PATRON_BAR_CHOWDER "bar_chowder"
#define PATRON_BAR_CREW_ROOM "bar_crew_room"
/// Trait on a mess decal that was already there when the outpost's staff first looked: the map's own decor, never cleaned
#define TRAIT_AMBIENT_OUTPOST_DECOR "ambient_outpost_decor"
/// Trait source for PA
#define AMBIENT_OUTPOST_TRAIT "ambient_outpost"
/// Where a customer is in a visit to a counter
#define VISIT_WALKING "walking"
#define VISIT_QUEUE "queue"
#define VISIT_COUNTER "counter"

// =========================================================================
// THE BASE
// =========================================================================

/**
 * Everyone PA brings to a trader outpost. Passive like every outpost NPC, and killable. Their
 * activities never send them into the pond, into or beside a doorway, into the lift's mouth, into
 * the kingpin's lounge or near an apiary.
 */
/mob/living/basic/ambient_npc/outpost
	desc = "Someone off one of the ships."
	dialogue_file = AMBIENT_STRINGS_PATRONS
	dialogue_section = "customer"
	/// Set while they look for a place at a counter they have business at (to buy, order, show a catch): only then may they stand within a counter's reach
	var/counter_business = FALSE

/**
 * P0's standable() for PA's NPCs, with two changes. A railing (any border object) blocks one edge
 * of its tile, not the tile: players queue on railed lanes (the Chowder Pot's counter), and the
 * public floor already holds only tiles someone can walk onto. And they keep off the tiles
 * ambient_outpost_tile_avoided() lists: the pond, doorways, the lift's mouth, the kingpin's lounge,
 * the hives, and a counter's reach unless they have business there and nobody is being served.
 */
/mob/living/basic/ambient_npc/outpost/standable(turf/tile, list/avoid, ignore_floor = FALSE)
	if(!isturf(tile) || LAZYACCESS(avoid, tile))
		return FALSE
	if(!isopenturf(tile) || isspaceturf(tile) || isgroundlessturf(tile) || islava(tile) || ischasm(tile))
		return FALSE
	if(tile != loc && ambient_outpost_tile_blocked(tile, src))
		return FALSE
	if(!leash_ok(tile))
		return FALSE
	if(ignore_floor)
		return TRUE
	if(place && !place.spot_allowed(tile, src))
		return FALSE
	return !ambient_outpost_tile_avoided(tile, place, counter_business)

/mob/living/basic/ambient_npc/outpost/seat_usable(obj/structure/chair/seat, list/avoid)
	. = ..()
	if(!.)
		return
	if(ambient_in_kingpin_lounge(seat, 4))
		return FALSE
	// A counter keeps room for players: never a seat within its reach once it has its share of NPCs
	if(seat.loc != loc && ambient_seat_crowds_counter(seat, place, src))
		return FALSE

/**
 * Starts one of `weights` (activity types with weights), trying them in weighted order until one
 * can be set up, then standing about: P0's pick_activity() with an anchor. The types in
 * `anchored_types` (all of them when null) are made with `anchor`, the rest without.
 */
/mob/living/basic/ambient_npc/outpost/proc/pick_anchored(list/weights, atom/anchor, list/anchored_types)
	var/list/options = weights?.Copy()
	while(length(options))
		var/activity_type = pick_weight(options)
		options -= activity_type
		var/atom/its_anchor = (!anchored_types || (activity_type in anchored_types)) ? anchor : null
		if(start_activity(new activity_type(src, its_anchor)))
			return activity
	return start_activity(new /datum/ambient_activity/idle(src))

/// The trader outpost they are at, if any
/mob/living/basic/ambient_npc/outpost/proc/get_outpost()
	var/datum/ambient_place/outpost/outpost_place = place
	return istype(outpost_place) ? outpost_place.outpost() : null

/// A line for `context` from `section` of their file, said now to `other`. TRUE if said.
/mob/living/basic/ambient_npc/outpost/proc/say_from(section, context, atom/other)
	var/list/lines = ambient_dialogue_lines(dialogue_file, section, context)
	if(!length(lines) || stat != CONSCIOUS || fading)
		return FALSE
	var/line = pick(lines)
	if(!istext(line))
		return FALSE
	say_line(fill_line(line, other))
	return TRUE

// =========================================================================
// WHERE THEY KEEP OFF
// =========================================================================

/**
 * Whether something on `tile` stops `mover` standing there: the tile itself, or anything dense on
 * it but `mover` and border objects (a railing blocks one edge of its tile, not the tile)
 */
/proc/ambient_outpost_tile_blocked(turf/tile, atom/movable/mover)
	if(tile.density)
		return TRUE
	for(var/atom/movable/thing as anything in tile.contents)
		if(thing == mover || !thing.density || (thing.flags_1 & ON_BORDER_1))
			continue
		return TRUE
	return FALSE

/**
 * Whether PA's NPCs keep off `tile`: the pond; a door or the tile before an airlock; the lift's
 * mouth (the tiles round its alcove, where people step off); the kingpin's lounge; anywhere an
 * apiary's bees would be round them; a counter's reach, unless they have `counter_business` there
 * and nobody else is being served.
 */
/proc/ambient_outpost_tile_avoided(turf/tile, datum/ambient_place/place, counter_business = FALSE)
	if(!tile || istype(tile, /turf/open/water) || ambient_by_a_door(tile))
		return TRUE
	var/datum/ambient_place/outpost/outpost_place = place
	var/obj/structure/overmap/trader_outpost/outpost = istype(outpost_place) ? outpost_place.outpost() : null
	for(var/turf/alcove as anything in outpost?.lobby_alcove_turfs)
		if(alcove.z == tile.z && get_dist(alcove, tile) <= 1)
			return TRUE
	if(ambient_in_kingpin_lounge(tile, 2))
		return TRUE
	// Halcyon's garden: nobody within two tiles of a hive (the outpost's hives, looked up now and then)
	for(var/obj/structure/beebox/hive as anything in ambient_outpost_find_all(outpost, /obj/structure/beebox))
		if(hive.z == tile.z && get_dist(hive, tile) <= 2)
			return TRUE
	// The counters are for doing business at, and a player at one has the room round it to themselves
	if(outpost)
		for(var/mob/living/basic/outpost_trader/trader in outpost.traders)
			if(trader.z != tile.z || get_dist(trader, tile) > PATRON_COUNTER_RANGE)
				continue
			if(!counter_business || ambient_counter_customer(trader))
				return TRUE
	return FALSE

/// Whether `thing` is within `radius` of the kingpin's seat in his lounge (bounty_kingpin.dm, read only)
/proc/ambient_in_kingpin_lounge(atom/thing, radius)
	var/turf/spot = get_turf(thing)
	if(!spot)
		return FALSE
	for(var/obj/effect/landmark/bounty_kingpin/seat/mark in GLOB.bounty_kingpin_marks)
		var/turf/seat_turf = get_turf(mark)
		if(seat_turf && seat_turf.z == spot.z && get_dist(seat_turf, spot) <= radius)
			return TRUE
	return FALSE

// =========================================================================
// TRADERS AND COUNTERS
// =========================================================================

/// The trader NPCs at `place`'s outpost, at their counters and awake
/proc/ambient_outpost_traders(datum/ambient_place/outpost/place)
	. = list()
	var/obj/structure/overmap/trader_outpost/outpost = istype(place) ? place.outpost() : null
	if(!outpost)
		return
	for(var/mob/living/basic/outpost_trader/trader in outpost.traders)
		if(!QDELETED(trader) && isturf(trader.loc) && trader.stat != DEAD)
			. += trader

/// The trader at `place` who runs `shop_type`, or null
/proc/ambient_outpost_trader_of(datum/ambient_place/outpost/place, shop_type)
	for(var/mob/living/basic/outpost_trader/trader as anything in ambient_outpost_traders(place))
		if(ambient_trader_shop(trader) == shop_type)
			return trader
	return null

/// The shop `trader` runs, as a /datum/outpost_shop type: a stall's own, or the outpost's main shop
/proc/ambient_trader_shop(mob/living/basic/outpost_trader/trader)
	return trader?.shop_type || trader?.shop?.type || trader?.outpost?.shop_type

/// `trader`'s section of AMBIENT_STRINGS_PATRONS (their customers' lines and their answers), or null
/proc/ambient_trader_section(mob/living/basic/outpost_trader/trader)
	var/static/list/sections = list(
		/datum/outpost_shop/general = "barnaby",
		/datum/outpost_shop/outfitter = "sarge",
		/datum/outpost_shop/black_market = "vex",
		/datum/outpost_shop/vendor/diner = "roux",
		/datum/outpost_shop/vendor/potting_shed = "fern",
		/datum/outpost_shop/vendor/bait_shop = "pike",
		/datum/outpost_shop/vendor/skunkworks = "boffin",
		/datum/outpost_shop/vendor/suit_fitter = "wick",
		/datum/outpost_shop/vendor/dregs_bar = "dram",
		/datum/outpost_shop/vendor/patchup_clinic = "sawbones",
		/datum/outpost_shop/vendor/ripperdoc = "splice",
	)
	var/shop_path = ambient_trader_shop(trader)
	return shop_path ? sections[shop_path] : null

/**
 * Whoever is being served at `trader`'s counter: a player, or anyone else who is not one of the
 * outpost's NPCs, within reach of the trader. Null when the counter is free.
 */
/proc/ambient_counter_customer(mob/living/basic/outpost_trader/trader)
	if(!trader)
		return null
	for(var/mob/living/customer in range(PATRON_COUNTER_RANGE, trader))
		if(customer.stat == DEAD || istype(customer, /mob/living/basic/ambient_npc) || istype(customer, /mob/living/basic/outpost_trader))
			continue
		if(customer.client || ishuman(customer))
			return customer
	return null

/// How many ambient NPCs stand or sit within reach of `trader`, not counting `exclude`
/proc/ambient_counter_crowd(mob/living/basic/outpost_trader/trader, mob/living/exclude)
	. = 0
	for(var/mob/living/basic/ambient_npc/npc in range(PATRON_COUNTER_RANGE, trader))
		if(npc != exclude && npc.stat != DEAD && !npc.fading)
			.++

/**
 * The tiles in front of `trader`'s counter where `npc` could stand to be served: within reach, two
 * tiles out with the counter (a table) in between, so never on the trader's own side. A trader with
 * no counter at all is served from anywhere within reach.
 */
/proc/ambient_counter_spots(mob/living/basic/ambient_npc/npc, mob/living/basic/outpost_trader/trader, list/avoid)
	. = list()
	var/turf/center = get_turf(trader)
	if(!center || !npc)
		return
	var/mob/living/basic/ambient_npc/outpost/visitor = npc
	if(istype(visitor))
		visitor.counter_business = TRUE
	var/list/open_spots = list()
	for(var/turf/tile as anything in RANGE_TURFS(PATRON_COUNTER_RANGE, center))
		if(tile == center || !npc.standable(tile, avoid))
			continue
		open_spots += tile
		if(get_dist(tile, center) < 2)
			continue
		var/turf/between = get_step(center, get_dir(center, tile))
		if(locate(/obj/structure/table) in between)
			. += tile
	if(istype(visitor))
		visitor.counter_business = FALSE
	if(!length(.) && !ambient_has_counter(center))
		return open_spots

/// Whether a trader standing on `center` has a counter (a table) right beside them
/proc/ambient_has_counter(turf/center)
	for(var/turf/tile as anything in RANGE_TURFS(1, center))
		if(locate(/obj/structure/table) in tile)
			return TRUE
	return FALSE

/// The nearest of `tiles` to `from`, or null
/proc/ambient_nearest_tile(atom/from, list/tiles)
	var/turf/best
	var/best_distance = INFINITY
	for(var/turf/tile as anything in tiles)
		var/distance = get_dist(from, tile)
		if(distance < best_distance)
			best = tile
			best_distance = distance
	return best

/**
 * A tile where `npc` could wait near `center` without being in anyone's way: `low` to `high` tiles
 * from it (out of a counter's reach), in sight of it, a random one of the three nearest to `npc`.
 * With `loiter` (default), only loiter spots count, so a crowded or bad queue gives up the
 * spot instead of stacking. Null if none.
 */
/proc/ambient_waiting_spot(mob/living/basic/ambient_npc/npc, atom/center, low = 3, high = 4, list/avoid, loiter = TRUE)
	var/turf/middle = get_turf(center)
	if(!middle || !npc)
		return null
	var/list/options = list()
	for(var/turf/tile as anything in RANGE_TURFS(high, middle))
		if(get_dist(tile, middle) < low || !npc.standable(tile, avoid))
			continue
		if(!can_see(middle, tile, high + 1))
			continue
		if(loiter && !npc.loiter_spot_ok(tile, avoid))
			continue
		options += tile
	if(!length(options))
		return null
	var/list/nearest = list()
	for(var/i in 1 to min(3, length(options)))
		var/turf/closest
		var/closest_distance = INFINITY
		for(var/turf/tile as anything in options)
			var/distance = get_dist(npc, tile)
			if(distance < closest_distance)
				closest = tile
				closest_distance = distance
		nearest += closest
		options -= closest
	return pick(nearest)

/**
 * `trader` answers `speaker` a moment from now with a line for `context` from `section` of dialogue
 * `file`, in the trader's own voice (their own say(), so their own barks), if both are still there.
 */
/proc/ambient_trader_reply(mob/living/basic/outpost_trader/trader, atom/movable/speaker, file, section, context = "trader_reply", max_distance = 4)
	if(!trader || !speaker)
		return
	addtimer(CALLBACK(GLOBAL_PROC, GLOBAL_PROC_REF(ambient_trader_answer), WEAKREF(trader), WEAKREF(speaker), file, section, context, max_distance), rand(AMBIENT_REPLY_DELAY_LOW, AMBIENT_REPLY_DELAY_HIGH))

/**
 * The answer itself (ambient_trader_reply()). A trader who has just spoken (a sale to a player, the
 * convoy) keeps quiet: the shop's own pause between lines holds (trader_npc.dm speak_line()).
 * TRUE if they spoke.
 */
/proc/ambient_trader_answer(datum/weakref/trader_ref, datum/weakref/speaker_ref, file, section, context, max_distance = 4)
	var/mob/living/basic/outpost_trader/trader = trader_ref?.resolve()
	var/atom/movable/speaker = speaker_ref?.resolve()
	if(QDELETED(trader) || QDELETED(speaker) || trader.stat == DEAD || get_dist(trader, speaker) > max_distance)
		return FALSE
	if(!COOLDOWN_FINISHED(trader, speak_cooldown))
		return FALSE
	var/list/lines = ambient_dialogue_lines(file, section, context)
	if(!length(lines))
		return FALSE
	var/line = pick(lines)
	if(!istext(line))
		return FALSE
	COOLDOWN_START(trader, speak_cooldown, 3 SECONDS)
	if(ismob(speaker))
		var/mob/speaker_mob = speaker
		line = replacetext(line, "{other}", first_name(speaker_mob.real_name || speaker_mob.name))
	INVOKE_ASYNC(trader, TYPE_PROC_REF(/atom/movable, say), line)
	return TRUE

/**
 * What PA remembers about `outpost` (what was found where, whether its decor was marked): an assoc
 * list, made the first time. Keyed by the outpost's weakref, so an outpost made later never inherits
 * a deleted one's notes, whatever ref id it gets. Trader outposts never unload, so it stays small.
 */
/proc/ambient_outpost_notes(obj/structure/overmap/trader_outpost/outpost)
	var/static/list/notes = list()
	var/datum/weakref/key = WEAKREF(outpost)
	var/list/entry = notes[key]
	if(!entry)
		entry = list()
		notes[key] = entry
	return entry

/**
 * The first `find_type` on `outpost`'s concourse (the crew room's coffee machine), remembered. The
 * concourse is only walked when it is not known yet, and a miss is not looked for again for a while.
 */
/proc/ambient_outpost_find(obj/structure/overmap/trader_outpost/outpost, find_type)
	if(!outpost || !find_type)
		return null
	var/list/notes = ambient_outpost_notes(outpost)
	var/found_key = "found [find_type]"
	var/missing_key = "missing [find_type]"
	var/datum/weakref/known = notes[found_key]
	var/atom/thing = known?.resolve()
	if(!QDELETED(thing))
		return thing
	notes -= found_key
	if(notes[missing_key] > world.time)
		return null
	var/list/bounds = bounty_outpost_bounds(outpost)
	if(length(bounds) < 5)
		return null
	for(var/turf/tile as anything in block(locate(bounds[1], bounds[2], bounds[5]), locate(bounds[3], bounds[4], bounds[5])))
		thing = locate(find_type) in tile
		if(thing)
			notes[found_key] = WEAKREF(thing)
			notes -= missing_key
			return thing
	notes[missing_key] = world.time + 5 MINUTES
	return null

// =========================================================================
// THE BARS
// =========================================================================

/**
 * `place`'s bar, as list(where it is, the barkeep or null, its section of AMBIENT_STRINGS_PATRONS):
 * the Dregs (Dram) at the Undertow, the Chowder Pot (Roux) at Halcyon, the crew room's coffee
 * machine at Quartermain. Null when it has none.
 */
/proc/ambient_outpost_bar(datum/ambient_place/outpost/place)
	var/obj/structure/overmap/trader_outpost/outpost = istype(place) ? place.outpost() : null
	if(!outpost)
		return null
	if(istype(outpost, /obj/structure/overmap/trader_outpost/outfitter))
		var/obj/machinery/vending/coffee/machine = ambient_outpost_find(outpost, /obj/machinery/vending/coffee)
		return machine ? list(machine, null, PATRON_BAR_CREW_ROOM) : null
	if(istype(outpost, /obj/structure/overmap/trader_outpost/black_market))
		var/mob/living/basic/outpost_trader/dram = ambient_outpost_trader_of(place, /datum/outpost_shop/vendor/dregs_bar)
		return dram ? list(dram, dram, PATRON_BAR_DREGS) : null
	if(istype(outpost, /obj/structure/overmap/trader_outpost/general))
		var/mob/living/basic/outpost_trader/roux = ambient_outpost_trader_of(place, /datum/outpost_shop/vendor/diner)
		return roux ? list(roux, roux, PATRON_BAR_CHOWDER) : null
	return null

/// Whether `place`'s outpost has a barback to clear glasses; if not, a finished drink is dropped instead of left on a table
/proc/ambient_outpost_has_barback(datum/ambient_place/outpost/place)
	var/obj/structure/overmap/trader_outpost/outpost = istype(place) ? place.outpost() : null
	if(!outpost)
		return FALSE
	for(var/datum/ambient_outpost_role/barback/role in SSambient_npcs.get_outpost_roles())
		if(role.max_count > 0 && role.applies_to(outpost))
			return TRUE
	return FALSE

/// Whether `seat` is within reach of a trader whose counter already has its share of ambient NPCs, `asker` aside
/proc/ambient_seat_crowds_counter(obj/structure/chair/seat, datum/ambient_place/outpost/place, mob/living/asker)
	for(var/mob/living/basic/outpost_trader/trader as anything in ambient_outpost_traders(place))
		if(get_dist(trader, seat) > PATRON_COUNTER_RANGE)
			continue
		if(ambient_counter_crowd(trader, asker) >= PATRON_COUNTER_CROWD_MAX)
			return TRUE
	return FALSE

// =========================================================================
// MESS (the janitor cleans it; drinkers make some)
// =========================================================================

/// What the janitor cleans: fresh mess, never the map's own grime (dirt, oil, rust, cobwebs, its decor)
/proc/ambient_is_mess(obj/effect/decal/cleanable/decal)
	var/static/list/mess_types = typecacheof(list(
		/obj/effect/decal/cleanable/blood,
		/obj/effect/decal/cleanable/vomit,
		/obj/effect/decal/cleanable/glass,
		/obj/effect/decal/cleanable/food,
	))
	return istype(decal) && !QDELETED(decal) && is_type_in_typecache(decal, mess_types) && !HAS_TRAIT(decal, TRAIT_AMBIENT_OUTPOST_DECOR)

/**
 * Marks every mess decal already on `place`'s public floor as the map's own decor, once per outpost:
 * the first time anyone looks for mess there. Mess made after that is the janitor's to clean.
 */
/proc/ambient_outpost_mark_decor(datum/ambient_place/outpost/place)
	var/obj/structure/overmap/trader_outpost/outpost = istype(place) ? place.outpost() : null
	if(!outpost)
		return
	var/list/notes = ambient_outpost_notes(outpost)
	if(notes["decor marked"])
		return
	notes["decor marked"] = TRUE
	var/list/floor = place.get_public_floor()
	for(var/turf/tile as anything in floor)
		for(var/obj/effect/decal/cleanable/decal in tile)
			ADD_TRAIT(decal, TRAIT_AMBIENT_OUTPOST_DECOR, AMBIENT_OUTPOST_TRAIT)

/// Somebody made a mess at `place` (`mess`, a decal): a janitor there comes over, if one is free
/proc/ambient_outpost_report_mess(datum/ambient_place/outpost/place, obj/effect/decal/cleanable/mess)
	if(!istype(place) || !ambient_is_mess(mess))
		return
	for(var/mob/living/basic/ambient_npc/outpost/worker/janitor/janitor in place.living_npcs())
		if(janitor.notice_mess(mess))
			return

// =========================================================================
// OUTFITS: who comes through a trader outpost
// =========================================================================

/// A deckhand off a freighter: work overalls, a puffer vest and a cap
/datum/outfit/ambient_customer
	name = "Outpost customer (deckhand)"
	uniform = /obj/item/clothing/under/misc/overalls
	suit = /obj/item/clothing/suit/jacket/puffer/vest
	head = /obj/item/clothing/head/soft/black
	shoes = /obj/item/clothing/shoes/workboots

/// A pilot in a tan suit and an old field jacket
/datum/outfit/ambient_customer/pilot
	name = "Outpost customer (pilot)"
	uniform = /obj/item/clothing/under/suit/tan
	suit = /obj/item/clothing/suit/jacket/miljacket
	head = null
	shoes = /obj/item/clothing/shoes/jackboots

/// A ship's engineer in a sweater over the jumpsuit
/datum/outfit/ambient_customer/engineer
	name = "Outpost customer (engineer)"
	uniform = /obj/item/clothing/under/rank/engineering/engineer
	suit = /obj/item/clothing/suit/toggle/jacket/sweater
	head = /obj/item/clothing/head/beanie
	shoes = /obj/item/clothing/shoes/workboots

/// A ship's medic in scrubs and a lab coat
/datum/outfit/ambient_customer/medic
	name = "Outpost customer (medic)"
	uniform = /obj/item/clothing/under/rank/medical/scrubs/blue
	suit = /obj/item/clothing/suit/toggle/labcoat
	head = null
	glasses = /obj/item/clothing/glasses/regular
	shoes = /obj/item/clothing/shoes/sneakers/white

/// A prospector in an explorer suit, gloves still dusty
/datum/outfit/ambient_customer/prospector
	name = "Outpost customer (prospector)"
	uniform = /obj/item/clothing/under/rank/cargo/miner
	suit = /obj/item/clothing/suit/hooded/explorer
	head = null
	gloves = /obj/item/clothing/gloves/color/black
	shoes = /obj/item/clothing/shoes/workboots

/// A ship's scientist, here for parts
/datum/outfit/ambient_customer/scientist
	name = "Outpost customer (scientist)"
	uniform = /obj/item/clothing/under/rank/rnd/scientist
	suit = /obj/item/clothing/suit/toggle/labcoat/science
	head = null
	shoes = /obj/item/clothing/shoes/sneakers/white

/// Off duty, in camo trousers and a letterman jacket
/datum/outfit/ambient_customer/casual
	name = "Outpost customer (off duty)"
	uniform = /obj/item/clothing/under/pants/camo
	suit = /obj/item/clothing/suit/jacket/letterman
	head = /obj/item/clothing/head/soft/red
	shoes = /obj/item/clothing/shoes/jackboots

/// A quartermaster in a brown dress shirt, here about the paperwork
/datum/outfit/ambient_customer/quartermaster
	name = "Outpost customer (quartermaster)"
	uniform = /obj/item/clothing/under/rank/cargo/qm
	suit = /obj/item/clothing/suit/jacket
	head = null
	shoes = /obj/item/clothing/shoes/laceup

// =========================================================================
// CUSTOMERS (owner item 3)
// =========================================================================

/// Someone off one of the berthed ships, doing their shopping
/mob/living/basic/ambient_npc/outpost/customer
	desc = "Someone off one of the ships, doing their shopping."
	dialogue_section = "customer"
	outfit_choices = list(
		/datum/outfit/ambient_customer,
		/datum/outfit/ambient_customer/pilot,
		/datum/outfit/ambient_customer/engineer,
		/datum/outfit/ambient_customer/medic,
		/datum/outfit/ambient_customer/prospector,
		/datum/outfit/ambient_customer/scientist,
		/datum/outfit/ambient_customer/casual,
		/datum/outfit/ambient_customer/quartermaster,
	)
	routine = list(
		/datum/ambient_activity/idle = 1,
		/datum/ambient_activity/wander = 3,
		/datum/ambient_activity/sit = 2,
		/datum/ambient_activity/chat = 2,
	)
	/// world.time they head back to the lift
	var/leave_at = 0
	/// Counters left to visit
	var/stalls_left = 1
	/// Weakrefs to the traders they already bought from
	var/list/visited

/mob/living/basic/ambient_npc/outpost/customer/Initialize(mapload)
	. = ..()
	leave_at = world.time + rand(PATRON_VISIT_LOW, PATRON_VISIT_HIGH)
	stalls_left = rand(1, PATRON_STALLS_MAX)

/mob/living/basic/ambient_npc/outpost/customer/Destroy()
	visited = null
	return ..()

/mob/living/basic/ambient_npc/outpost/customer/pick_activity()
	if(world.time >= leave_at)
		if(prob(30))
			speak_context(AMBIENT_LINE_LEAVE)
		return start_activity(new /datum/ambient_activity/leave(src))
	if(stalls_left > 0)
		stalls_left--
		var/datum/ambient_activity/visit = start_activity(new /datum/ambient_activity/shop_visit(src))
		if(visit)
			return visit
	return ..()

/// Here a while already: part-way through their visit, at a counter, or done there with a bag in hand
/mob/living/basic/ambient_npc/outpost/customer/settle_in()
	leave_at = ambient_part_way(leave_at)
	if(prob(40))
		stalls_left--
		set_held(/obj/item/storage/box/papersack)
	return ..()

/mob/living/basic/ambient_npc/outpost/customer/shift_times(delay)
	. = ..()
	leave_at = ambient_shifted(leave_at, delay)

/// Whether they already bought from `trader` this visit
/mob/living/basic/ambient_npc/outpost/customer/proc/has_visited(mob/living/basic/outpost_trader/trader)
	for(var/datum/weakref/ref as anything in visited)
		if(ref.resolve() == trader)
			return TRUE
	return FALSE

/// The convoy came in: now and then a word about it
/mob/living/basic/ambient_npc/outpost/customer/react_convoy(obj/structure/overmap/trader_outpost/outpost)
	if(stat == CONSCIOUS && !fading && prob(30) && reaction_ready("convoy", 1 MINUTES))
		speak_context("convoy")

/**
 * A visit to one trader's counter: walk up (or wait behind a player), say what they want, get the
 * trader's answer, and walk off with a paper bag. The bag is part of the look: nothing is bought,
 * and the shop's stock is never touched.
 */
/datum/ambient_activity/shop_visit
	name = "shopping"
	/// The trader
	var/datum/weakref/trader_ref
	/// VISIT_*
	var/stage = VISIT_WALKING
	/// world.time they give up waiting in line
	var/queue_until = 0
	/// world.time they say what they want, once at the counter
	var/order_at = 0
	/// world.time they are done at the counter
	var/done_at = 0
	/// They said what they want
	var/ordered = FALSE
	/// Nowhere left to stand: the visit is off
	var/given_up = FALSE

/datum/ambient_activity/shop_visit/Destroy()
	trader_ref = null
	return ..()

/datum/ambient_activity/shop_visit/setup()
	var/mob/living/basic/outpost_trader/trader = anchor()
	if(!istype(trader))
		trader = pick_trader()
	if(!trader || !ambient_trader_section(trader))
		return FALSE
	trader_ref = WEAKREF(trader)
	return approach(trader)

/// A trader at their place to visit: one they have not bought from, whose counter is not crowded with NPCs
/datum/ambient_activity/shop_visit/proc/pick_trader()
	var/mob/living/basic/ambient_npc/outpost/customer/shopper = doer
	var/list/options = list()
	for(var/mob/living/basic/outpost_trader/trader as anything in ambient_outpost_traders(doer.place))
		if(!ambient_trader_section(trader))
			continue
		if(istype(shopper) && shopper.has_visited(trader))
			continue
		if(ambient_counter_crowd(trader, doer) >= PATRON_COUNTER_CROWD_MAX)
			continue
		options += trader
	return length(options) ? pick(options) : null

/// The trader, if still there
/datum/ambient_activity/shop_visit/proc/trader()
	var/mob/living/basic/outpost_trader/trader = trader_ref?.resolve()
	return QDELETED(trader) ? null : trader

/// Heads for the counter, or for a place to wait if someone is being served. FALSE when there is nowhere.
/datum/ambient_activity/shop_visit/proc/approach(mob/living/basic/outpost_trader/trader)
	if(ambient_counter_customer(trader))
		return wait_in_line(trader)
	var/turf/spot = ambient_nearest_tile(doer, ambient_counter_spots(doer, trader, failed_spots))
	if(!spot)
		return FALSE
	stage = VISIT_WALKING
	go_to(spot)
	return TRUE

/// Steps back out of the counter's reach to wait for whoever is being served. FALSE when there is nowhere.
/datum/ambient_activity/shop_visit/proc/wait_in_line(mob/living/basic/outpost_trader/trader)
	var/turf/spot = ambient_waiting_spot(doer, trader, PATRON_COUNTER_RANGE + 1, PATRON_COUNTER_RANGE + 3, failed_spots)
	if(!spot)
		return FALSE
	if(stage != VISIT_QUEUE)
		queue_until = world.time + PATRON_QUEUE_PATIENCE
	stage = VISIT_QUEUE
	go_to(spot)
	return TRUE

/datum/ambient_activity/shop_visit/arrive()
	var/mob/living/basic/outpost_trader/trader = trader()
	if(trader && !doer.buckled)
		doer.face_atom(trader)
	if(stage == VISIT_WALKING)
		stage = VISIT_COUNTER
		order_at = world.time + rand(1 SECONDS, 3 SECONDS)

/datum/ambient_activity/shop_visit/act(seconds)
	var/mob/living/basic/outpost_trader/trader = trader()
	if(!trader || given_up)
		return AMBIENT_STEP_DONE
	var/mob/living/customer = ambient_counter_customer(trader)
	switch(stage)
		if(VISIT_QUEUE)
			if(!customer)
				return approach(trader) ? AMBIENT_STEP_MOVE : AMBIENT_STEP_DONE
			if(world.time >= queue_until)
				if(prob(50))
					doer.speak_context("queue_give_up", trader)
				return AMBIENT_STEP_DONE
			if(prob(5) && !doer.buckled)
				doer.face_atom(trader)
			return AMBIENT_STEP_CONTINUE
		if(VISIT_COUNTER)
			// A player stepped up: make room for them
			if(customer)
				if(prob(60))
					doer.speak_context("yield", customer, force = TRUE)
				return wait_in_line(trader) ? AMBIENT_STEP_MOVE : AMBIENT_STEP_DONE
			if(!ordered)
				if(world.time >= order_at)
					order(trader)
				return AMBIENT_STEP_CONTINUE
			if(world.time >= done_at)
				served(trader)
				return AMBIENT_STEP_DONE
	return AMBIENT_STEP_CONTINUE

/// Says what they came for; the trader answers
/datum/ambient_activity/shop_visit/proc/order(mob/living/basic/outpost_trader/trader)
	ordered = TRUE
	done_at = world.time + rand(PATRON_SERVE_LOW, PATRON_SERVE_HIGH)
	var/section = ambient_trader_section(trader)
	var/list/lines = ambient_dialogue_lines(AMBIENT_STRINGS_PATRONS, section, "order")
	if(!length(lines))
		return
	doer.say_line(doer.fill_line(pick(lines), trader))
	ambient_trader_reply(trader, doer, AMBIENT_STRINGS_PATRONS, section)

/// Served: off with a paper bag
/datum/ambient_activity/shop_visit/proc/served(mob/living/basic/outpost_trader/trader)
	doer.set_held(/obj/item/storage/box/papersack)
	var/mob/living/basic/ambient_npc/outpost/customer/shopper = doer
	if(istype(shopper))
		LAZYADD(shopper.visited, WEAKREF(trader))

/datum/ambient_activity/shop_visit/spot_unreachable()
	. = ..()
	var/mob/living/basic/outpost_trader/trader = trader()
	if(!trader || !approach(trader))
		given_up = TRUE

/datum/ambient_activity/shop_visit/shift_times(delay)
	. = ..()
	queue_until = ambient_shifted(queue_until, delay)
	order_at = ambient_shifted(order_at, delay)
	done_at = ambient_shifted(done_at, delay)

// =========================================================================
// DRINKERS (owner item 2)
// =========================================================================

/// Off duty and at the bar, and it shows more with every drink
/mob/living/basic/ambient_npc/outpost/drinker
	desc = "Someone off one of the ships, off duty."
	dialogue_section = "drinker"
	outfit_choices = list(
		/datum/outfit/ambient_customer,
		/datum/outfit/ambient_customer/pilot,
		/datum/outfit/ambient_customer/engineer,
		/datum/outfit/ambient_customer/prospector,
		/datum/outfit/ambient_customer/casual,
		/datum/outfit/ambient_customer/quartermaster,
	)
	routine = list(/datum/ambient_activity/idle = 1)
	/// The bar: the barkeep, or the crew room's coffee machine
	var/datum/weakref/bar_ref
	/// The barkeep who serves them, if any
	var/datum/weakref/barkeep_ref
	/// Their bar's section of AMBIENT_STRINGS_PATRONS (PATRON_BAR_*)
	var/bar_section
	/// 0 sober to PATRON_DRUNK_MAX passed out
	var/drunk = 0
	/// Sips of something strong since the last stage
	var/strong_sips = 0
	/// Sips of coffee (the crew room starts with coffee)
	var/coffee_sips = 0
	/// They ordered at the bar
	var/ordered = FALSE
	/// The barkeep cut them off
	var/cut_off = FALSE
	/// They were sick on the floor (once)
	var/vomited = FALSE
	/// They slept it off: next stop, the lift
	var/slept = FALSE
	/// Lying down and snoring
	var/asleep = FALSE
	/// Their transform before they lay down
	var/matrix/standing_transform

/mob/living/basic/ambient_npc/outpost/drinker/Destroy()
	bar_ref = null
	barkeep_ref = null
	standing_transform = null
	return ..()

/// Finds their outpost's bar. FALSE when it has none.
/mob/living/basic/ambient_npc/outpost/drinker/proc/find_bar()
	var/list/bar = ambient_outpost_bar(place)
	if(!length(bar))
		return FALSE
	set_bar(bar[1], bar[2], bar[3])
	return TRUE

/// Sets their bar: `where` it is, its `barkeep` (or null), its `section` (PATRON_BAR_*)
/mob/living/basic/ambient_npc/outpost/drinker/proc/set_bar(atom/where, mob/living/basic/outpost_trader/barkeep, section)
	bar_ref = where ? WEAKREF(where) : null
	barkeep_ref = barkeep ? WEAKREF(barkeep) : null
	bar_section = section

/// Their bar, if it is still there
/mob/living/basic/ambient_npc/outpost/drinker/proc/get_bar()
	var/atom/bar = bar_ref?.resolve()
	return QDELETED(bar) ? null : bar

/// Their barkeep, if still at the bar
/mob/living/basic/ambient_npc/outpost/drinker/proc/get_barkeep()
	var/mob/living/basic/outpost_trader/barkeep = barkeep_ref?.resolve()
	return QDELETED(barkeep) ? null : barkeep

/// What is poured for them at their bar
/mob/living/basic/ambient_npc/outpost/drinker/proc/bar_drink()
	switch(bar_section)
		if(PATRON_BAR_CREW_ROOM)
			return /datum/reagent/consumable/coffee
		if(PATRON_BAR_DREGS)
			return pick(/datum/reagent/consumable/ethanol/whiskey, /datum/reagent/consumable/ethanol/rum, /datum/reagent/consumable/ethanol/beer)
	return /datum/reagent/consumable/ethanol/beer

/mob/living/basic/ambient_npc/outpost/drinker/pick_activity()
	if(slept)
		return start_activity(new /datum/ambient_activity/leave(src))
	if(drunk >= PATRON_DRUNK_MAX)
		return start_activity(new /datum/ambient_activity/sleep_it_off(src))
	if(!get_bar() && !find_bar())
		// Nowhere to drink here: a look round, and off again
		slept = TRUE
		return start_activity(new /datum/ambient_activity/wander(src))
	if(!ordered)
		ordered = TRUE
		var/datum/ambient_activity/order = start_activity(new /datum/ambient_activity/bar_order(src, get_bar()))
		if(order)
			return order
	return start_activity(new /datum/ambient_activity/drink/bar(src, get_bar()))

/**
 * Here a while already: in a seat near the bar (or at a table) with a glass in hand, having ordered
 * long ago, and some of them a stage or two in. With no seat or table to be had, their routine
 * starts when someone comes.
 */
/mob/living/basic/ambient_npc/outpost/drinker/settle_in()
	if(!get_bar() && !find_bar())
		return ..()
	ordered = TRUE
	if(!start_activity(new /datum/ambient_activity/drink/bar(src, get_bar())) || !settle_here())
		end_activity()
		return ..()
	var/stages = pick(0, 1, 1, 2)
	if(stages && bar_section == PATRON_BAR_CREW_ROOM)
		// Off the coffee and onto something stronger already
		var/obj/item/reagent_containers/cup/glass/drinkingglass/glass = held_item
		if(istype(glass))
			glass.reagents.clear_reagents()
			glass.reagents.add_reagent(/datum/reagent/consumable/ethanol/beer, 25)
			set_held(glass)
		coffee_sips = -INFINITY
	if(stages)
		get_drunker(stages)
	strong_sips = rand(0, PATRON_SIPS_PER_STAGE - 1)
	return TRUE

// Slurring would wear off by itself while they sit still
/mob/living/basic/ambient_npc/outpost/drinker/pause_routine()
	. = ..()
	remove_status_effect(/datum/status_effect/speech/slurring/generic)

/mob/living/basic/ambient_npc/outpost/drinker/resume_routine()
	. = ..()
	if(drunk >= 3)
		set_slurring_if_lower(10 MINUTES)

/// Their lines for being talked to depend on how far gone they are
/mob/living/basic/ambient_npc/outpost/drinker/get_lines(context)
	if(context == AMBIENT_LINE_TALK)
		var/list/staged = ambient_dialogue_lines(dialogue_file, dialogue_section, asleep ? "talk_asleep" : "talk_[drunk]")
		if(length(staged))
			return staged
	return ..()

/**
 * One stage drunker (or `amount`; negative sobers them). Stage 1 is chatty, stage 2 loud, stage 3
 * slurring and swaying, stage 4 done: the barkeep cuts them off and they go and lie down.
 */
/mob/living/basic/ambient_npc/outpost/drinker/proc/get_drunker(amount = 1)
	var/old_stage = drunk
	drunk = clamp(drunk + amount, 0, PATRON_DRUNK_MAX)
	if(drunk == old_stage)
		return
	strong_sips = 0
	switch(drunk)
		if(0)
			speech_pace = 1
		if(1)
			speech_pace = 0.8
		if(2)
			speech_pace = 0.6
		else
			speech_pace = 0.7
	if(drunk >= 3)
		set_slurring_if_lower(10 MINUTES)
	else
		remove_status_effect(/datum/status_effect/speech/slurring/generic)
	if(drunk >= 3 && !vomited && prob(PATRON_VOMIT_CHANCE))
		be_sick()
	if(drunk >= PATRON_DRUNK_MAX)
		cut_off()

/// The barkeep has seen enough (once)
/mob/living/basic/ambient_npc/outpost/drinker/proc/cut_off()
	if(cut_off)
		return
	cut_off = TRUE
	var/mob/living/basic/outpost_trader/barkeep = get_barkeep()
	if(barkeep)
		ambient_trader_reply(barkeep, src, AMBIENT_STRINGS_PATRONS, bar_section, "cutoff", 10)

/// Sick on the floor beside them, once. The janitor hears about it.
/mob/living/basic/ambient_npc/outpost/drinker/proc/be_sick()
	vomited = TRUE
	var/turf/spot = free_tile_beside(src, 1) || get_turf(src)
	if(!spot)
		return
	var/obj/effect/decal/cleanable/vomit/mess = new(spot)
	playsound(src, 'sound/effects/splat.ogg', 30, TRUE, -3)
	INVOKE_ASYNC(src, TYPE_PROC_REF(/atom, manual_emote), "throws up.")
	if(!QDELETED(mess))
		ambient_outpost_report_mess(place, mess)

/**
 * A sip was had from their glass: it counts towards the next stage when it was something strong.
 * At the crew room the first sips are coffee, then something stronger.
 */
/mob/living/basic/ambient_npc/outpost/drinker/proc/on_sip(strong)
	if(!strong)
		coffee_sips++
		if(bar_section == PATRON_BAR_CREW_ROOM && coffee_sips >= PATRON_COFFEE_SIPS)
			switch_to_strong()
		return
	if(++strong_sips >= PATRON_SIPS_PER_STAGE)
		get_drunker(1)

/// Coffee's done; something stronger in the same glass
/mob/living/basic/ambient_npc/outpost/drinker/proc/switch_to_strong()
	var/obj/item/reagent_containers/cup/glass/drinkingglass/glass = held_item
	if(!istype(glass))
		return
	glass.reagents.clear_reagents()
	glass.reagents.add_reagent(/datum/reagent/consumable/ethanol/beer, 25)
	set_held(glass)
	coffee_sips = -INFINITY
	say_from(bar_section, "stronger")

/// Whether their glass holds something strong right now
/mob/living/basic/ambient_npc/outpost/drinker/proc/glass_is_strong()
	var/obj/item/reagent_containers/cup/glass/drinkingglass/glass = held_item
	return istype(glass) && glass.reagents?.has_reagent(/datum/reagent/consumable/ethanol, check_subtypes = TRUE)

/// A word for the stage they are at: the bar's own lines early on, songs at stage 2, a pair talk with another drinker
/mob/living/basic/ambient_npc/outpost/drinker/proc/drunk_chatter()
	if(world.time < next_line_at || (place && world.time < place.next_line_at))
		return
	if(drunk >= 1 && prob(35) && pair_talk())
		return
	if(drunk <= 2 && prob(30) && say_from(bar_section, "local"))
		return
	if(drunk == 2 && prob(30) && say_from(dialogue_section, "sing"))
		return
	speak_context("stage_[drunk]")

/// An exchange with another drinker at their bar within a few tiles. TRUE if one started.
/mob/living/basic/ambient_npc/outpost/drinker/proc/pair_talk()
	var/list/conversation = pick_conversation()
	if(length(conversation) < 2)
		return FALSE
	for(var/mob/living/basic/ambient_npc/outpost/drinker/other in range(3, src))
		if(other == src || other.asleep || !other.can_act() || other.bar_section != bar_section)
			continue
		if(!istype(other.activity, /datum/ambient_activity/drink/bar))
			continue
		say_line(fill_line(conversation[1], other))
		other.reply_to(src, AMBIENT_LINE_REPLY, conversation[2])
		return TRUE
	return FALSE

/// Down on the sofa (or the floor), out cold
/mob/living/basic/ambient_npc/outpost/drinker/proc/lie_down()
	if(asleep)
		return
	asleep = TRUE
	standing_transform = matrix(transform)
	var/matrix/lying = matrix(transform)
	lying.Turn(90)
	animate(src, transform = lying, time = 0.4 SECONDS)

/// Up again
/mob/living/basic/ambient_npc/outpost/drinker/proc/wake_up()
	if(!asleep)
		return
	asleep = FALSE
	// Killed where they slept: a body stays down
	if(stat != DEAD)
		animate(src, transform = standing_transform || matrix(), time = 0.4 SECONDS)
	standing_transform = null

/**
 * A drink handed to them: they drink from it. Something strong takes them a stage further,
 * anything else sobers them a little; poison they will not touch. The drink stays in the giver's hand.
 */
/mob/living/basic/ambient_npc/outpost/drinker/item_interaction(mob/living/user, obj/item/tool, list/modifiers)
	. = ..()
	if(. || user.combat_mode)
		return
	if(!istype(tool, /obj/item/reagent_containers/cup/glass) && !istype(tool, /obj/item/reagent_containers/cup/soda_cans))
		return
	accept_drink(user, tool)
	return ITEM_INTERACT_SUCCESS

/// `user` hands them `drink`. TRUE if they drank from it.
/mob/living/basic/ambient_npc/outpost/drinker/proc/accept_drink(mob/living/user, obj/item/reagent_containers/drink)
	if(stat != CONSCIOUS || fading)
		return FALSE
	if(asleep)
		INVOKE_ASYNC(src, TYPE_PROC_REF(/atom, manual_emote), "snores on.")
		return FALSE
	if(!reaction_ready("handed", PATRON_HANDED_COOLDOWN))
		return FALSE
	if(!buckled)
		face_atom(user)
	if(!drink.reagents?.total_volume || !drink.is_drainable())
		speak_context("handed_empty", user, force = TRUE)
		return FALSE
	if(drink.reagents.has_reagent(/datum/reagent/toxin, check_subtypes = TRUE))
		speak_context("handed_refuse", user, force = TRUE)
		return FALSE
	var/strong = drink.reagents.has_reagent(/datum/reagent/consumable/ethanol, check_subtypes = TRUE)
	drink.reagents.remove_all(20)
	playsound(src, 'sound/items/drink.ogg', 30, TRUE, -4)
	if(strong)
		get_drunker(1)
		speak_context(prob(30) ? "handed_gossip" : "handed", user, force = TRUE)
	else
		get_drunker(-1)
		speak_context("handed_sober", user, force = TRUE)
	return TRUE

/// Ordering at the bar: up to the barkeep's counter ("the usual"), or a cup from the crew room's coffee machine
/datum/ambient_activity/bar_order
	name = "ordering"
	duration_low = 30 SECONDS
	duration_high = 30 SECONDS
	/// They said it
	var/ordered = FALSE
	/// world.time they are done here
	var/done_at = 0

/datum/ambient_activity/bar_order/setup()
	var/mob/living/basic/ambient_npc/outpost/drinker/drinker = doer
	var/atom/bar = anchor()
	if(!istype(drinker) || !bar)
		return FALSE
	var/turf/spot
	var/mob/living/basic/outpost_trader/barkeep = bar
	if(istype(barkeep))
		// Someone's being served: they skip the counter and sit down
		if(ambient_counter_customer(barkeep) || ambient_counter_crowd(barkeep, doer) >= PATRON_COUNTER_CROWD_MAX)
			return FALSE
		spot = ambient_nearest_tile(doer, ambient_counter_spots(doer, barkeep, failed_spots))
	else
		spot = doer.free_tile_beside(bar, 1, failed_spots)
	if(!spot)
		return FALSE
	go_to(spot)
	set_duration()
	return TRUE

/datum/ambient_activity/bar_order/arrive()
	var/atom/bar = anchor()
	if(bar && !doer.buckled)
		doer.face_atom(bar)
	done_at = world.time + rand(4 SECONDS, 7 SECONDS)

/datum/ambient_activity/bar_order/act(seconds)
	var/mob/living/basic/ambient_npc/outpost/drinker/drinker = doer
	var/atom/bar = anchor()
	if(!bar || !istype(drinker))
		return AMBIENT_STEP_DONE
	if(!ordered)
		ordered = TRUE
		drinker.say_from(drinker.bar_section, "order", bar)
		var/mob/living/basic/outpost_trader/barkeep = bar
		if(istype(barkeep))
			ambient_trader_reply(barkeep, doer, AMBIENT_STRINGS_PATRONS, drinker.bar_section, "barkeep_reply")
		else
			playsound(bar, 'sound/machines/machine_vend.ogg', 30, TRUE, -3)
	if(world.time >= done_at)
		return AMBIENT_STEP_DONE
	return AMBIENT_STEP_CONTINUE

/datum/ambient_activity/bar_order/spot_unreachable()
	. = ..()
	ends_at = world.time

/datum/ambient_activity/bar_order/shift_times(delay)
	. = ..()
	done_at = ambient_shifted(done_at, delay)

/**
 * A night at the bar: a seat near it (a bar stool if one is free, then a sofa, then a table), a real
 * glass of what the bar pours, a sip every 20 to 40 seconds, and a stage drunker every two sips of
 * something strong. Lasts until they are done for.
 */
/datum/ambient_activity/drink/bar
	name = "drinking at the bar"
	accepts_company = FALSE
	duration_low = 30 MINUTES
	duration_high = 30 MINUTES
	/// world.time of their next stumble, from stage 3
	var/next_sway = 0

/datum/ambient_activity/drink/bar/setup()
	var/mob/living/basic/ambient_npc/outpost/drinker/drinker = doer
	if(!istype(drinker))
		return FALSE
	reagent_type = drinker.bar_drink()
	// A stool at the bar counter is theirs to take, while the counter keeps room for players (seat_usable())
	drinker.counter_business = TRUE
	var/obj/structure/chair/seat = find_bar_seat(anchor() || doer)
	if(seat)
		anchor_ref = WEAKREF(seat)
	. = ..()
	drinker.counter_business = FALSE
	if(.)
		next_line = world.time + rand(15 SECONDS, 30 SECONDS)

/**
 * The seat a drinker takes near `bar`: a free bar stool first, then a sofa, then anything with a
 * table beside it, nearer the bar the better. Never one that crowds a trader's counter.
 */
/datum/ambient_activity/drink/bar/proc/find_bar_seat(atom/bar)
	var/turf/center = get_turf(bar)
	if(!center)
		return null
	var/obj/structure/chair/best
	var/best_score = -INFINITY
	for(var/obj/structure/chair/seat in range(PATRON_BAR_RANGE, center))
		// seat_usable() also keeps them off a counter that already has its share of NPCs
		if(!doer.seat_usable(seat, failed_spots))
			continue
		var/score = rand(0, 20) / 10 - get_dist(center, seat) / 2
		if(istype(seat, /obj/structure/chair/stool/bar))
			score += 3
		else if(istype(seat, /obj/structure/chair/sofa))
			score += 2
		if(doer.table_beside(seat))
			score += 2
		if(score > best_score)
			best = seat
			best_score = score
	return best

/datum/ambient_activity/drink/bar/arrive()
	. = ..()
	next_sip = world.time + rand(8 SECONDS, 15 SECONDS)

/datum/ambient_activity/drink/bar/act(seconds)
	var/mob/living/basic/ambient_npc/outpost/drinker/drinker = doer
	// Done for (a drink handed over can do it between sips)
	if(!istype(drinker) || drinker.drunk >= PATRON_DRUNK_MAX)
		return AMBIENT_STEP_DONE
	if(world.time >= next_sip)
		next_sip = world.time + rand(PATRON_SIP_LOW, PATRON_SIP_HIGH)
		var/strong = drinker.glass_is_strong()
		if(!drinker.sip())
			return AMBIENT_STEP_DONE
		drinker.on_sip(strong)
		if(drinker.drunk >= PATRON_DRUNK_MAX)
			return AMBIENT_STEP_DONE
	if(drinker.drunk >= 3 && world.time >= next_sway)
		next_sway = world.time + rand(30 SECONDS, 60 SECONDS)
		drinker.Shake(2, 0, 0.6 SECONDS)
		drinker.manual_emote(pick("sways.", "hiccups.", "grabs the edge of the table.", "nearly slides off the seat."))
	if(world.time >= next_line)
		next_line = world.time + rand(25 SECONDS, 50 SECONDS)
		drinker.drunk_chatter()
	return AMBIENT_STEP_CONTINUE

/// The glass is finished before it goes down, so the barback can take it
/datum/ambient_activity/drink/bar/finish()
	var/obj/item/reagent_containers/cup/glass/drinkingglass/glass = doer?.held_item
	if(istype(glass))
		glass.reagents?.clear_reagents()
	if(!QDELETED(doer) && !ambient_outpost_has_barback(doer.place))
		table_ref = null
	return ..()

/datum/ambient_activity/drink/bar/shift_times(delay)
	. = ..()
	next_sway = ambient_shifted(next_sway, delay)

/**
 * Sleeping it off: over to a sofa if there is one near (the floor if not), down, and snoring for a
 * few minutes. Then they wake and go, unless the barback walks them out first.
 */
/datum/ambient_activity/sleep_it_off
	name = "sleeping it off"
	duration_low = PATRON_SLEEP_LOW
	duration_high = PATRON_SLEEP_HIGH
	var/datum/weakref/sofa_ref
	/// world.time of the next snore
	var/next_snore = 0
	/// world.time the barback is asked to come
	var/escort_at = 0

/datum/ambient_activity/sleep_it_off/setup()
	var/obj/structure/chair/sofa/sofa = find_sofa()
	if(sofa)
		sofa_ref = WEAKREF(sofa)
		go_to(get_turf(sofa))
	else
		go_to(null)
	set_duration()
	return TRUE

/// The nearest sofa they could lie on
/datum/ambient_activity/sleep_it_off/proc/find_sofa()
	var/obj/structure/chair/sofa/best
	var/best_distance = INFINITY
	for(var/obj/structure/chair/sofa/sofa in range(8, doer))
		if(!doer.seat_usable(sofa, failed_spots))
			continue
		var/distance = get_dist(doer, sofa)
		if(distance < best_distance)
			best = sofa
			best_distance = distance
	return best

/datum/ambient_activity/sleep_it_off/arrive()
	var/mob/living/basic/ambient_npc/outpost/drinker/drinker = doer
	var/obj/structure/chair/sofa/sofa = sofa_ref?.resolve()
	if(sofa)
		doer.sit_on(sofa)
	if(istype(drinker))
		drinker.lie_down()
	next_snore = world.time + rand(5 SECONDS, 15 SECONDS)
	escort_at = world.time + rand(30 SECONDS, 60 SECONDS)

/datum/ambient_activity/sleep_it_off/act(seconds)
	if(world.time >= next_snore)
		next_snore = world.time + rand(15 SECONDS, 30 SECONDS)
		doer.manual_emote(pick("snores.", "snores loudly.", "mumbles in their sleep.", "snores, and turns over."))
	if(escort_at && world.time >= escort_at)
		escort_at = 0
		ambient_outpost_call_escort(doer.place, doer)
	return AMBIENT_STEP_CONTINUE

/datum/ambient_activity/sleep_it_off/finish()
	var/mob/living/basic/ambient_npc/outpost/drinker/drinker = doer
	if(istype(drinker) && !QDELETED(drinker))
		drinker.wake_up()
		drinker.slept = TRUE
		if(!drinker.fading && prob(50))
			drinker.speak_context("wake", null, force = TRUE)
	return ..()

/datum/ambient_activity/sleep_it_off/spot_unreachable()
	. = ..()
	sofa_ref = null

/datum/ambient_activity/sleep_it_off/shift_times(delay)
	. = ..()
	next_snore = ambient_shifted(next_snore, delay)
	escort_at = ambient_shifted(escort_at, delay)

/// Someone at `place` could walk `drunk` to the lift: a free barback there, half the time
/proc/ambient_outpost_call_escort(datum/ambient_place/outpost/place, mob/living/basic/ambient_npc/drunk)
	if(!istype(place) || QDELETED(drunk) || !prob(50))
		return FALSE
	for(var/mob/living/basic/ambient_npc/outpost/worker/barback/barback in place.living_npcs())
		if(barback.activity?.priority > AMBIENT_PRIORITY_ROUTINE)
			continue
		if(barback.start_activity(new /datum/ambient_activity/escort(barback, drunk)))
			return TRUE
	return FALSE

// =========================================================================
// WHO COMES, AND HOW MANY (the outpost population rules)
// =========================================================================

/// Customers at every trader outpost: two at a time (one at the Undertow), one every minute or so
/datum/ambient_outpost_role/customer
	name = "customer"
	npc_type = /mob/living/basic/ambient_npc/outpost/customer
	outpost_types = list(
		/obj/structure/overmap/trader_outpost/general,
		/obj/structure/overmap/trader_outpost/outfitter,
		/obj/structure/overmap/trader_outpost/black_market,
	)
	max_count = 2
	weight = 4
	gap_low = 40 SECONDS
	gap_high = 100 SECONDS

/datum/ambient_outpost_role/customer/wanted(datum/ambient_place/outpost/place)
	if(!length(ambient_outpost_traders(place)))
		return 0
	var/obj/structure/overmap/trader_outpost/outpost = place.outpost()
	if(istype(outpost, /obj/structure/overmap/trader_outpost/black_market))
		return 1
	return max_count

/// One drinker at each outpost's bar
/datum/ambient_outpost_role/drinker
	name = "drinker"
	npc_type = /mob/living/basic/ambient_npc/outpost/drinker
	outpost_types = list(
		/obj/structure/overmap/trader_outpost/general,
		/obj/structure/overmap/trader_outpost/outfitter,
		/obj/structure/overmap/trader_outpost/black_market,
	)
	max_count = 1
	weight = 2
	gap_low = 60 SECONDS
	gap_high = 150 SECONDS

/datum/ambient_outpost_role/drinker/wanted(datum/ambient_place/outpost/place)
	return length(ambient_outpost_bar(place)) ? max_count : 0

/datum/ambient_outpost_role/drinker/arrive(datum/ambient_place/outpost/place, turf/where)
	. = ..()
	var/mob/living/basic/ambient_npc/outpost/drinker/drinker = .
	if(istype(drinker))
		drinker.find_bar()

#undef PATRON_COUNTER_RANGE
#undef PATRON_COUNTER_CROWD_MAX
#undef PATRON_VISIT_LOW
#undef PATRON_VISIT_HIGH
#undef PATRON_STALLS_MAX
#undef PATRON_QUEUE_PATIENCE
#undef PATRON_SERVE_LOW
#undef PATRON_SERVE_HIGH
#undef PATRON_BAR_RANGE
#undef PATRON_SIPS_PER_STAGE
#undef PATRON_DRUNK_MAX
#undef PATRON_SIP_LOW
#undef PATRON_SIP_HIGH
#undef PATRON_COFFEE_SIPS
#undef PATRON_SLEEP_LOW
#undef PATRON_SLEEP_HIGH
#undef PATRON_VOMIT_CHANCE
#undef PATRON_HANDED_COOLDOWN
#undef PATRON_BAR_DREGS
#undef PATRON_BAR_CHOWDER
#undef PATRON_BAR_CREW_ROOM
#undef TRAIT_AMBIENT_OUTPOST_DECOR
#undef AMBIENT_OUTPOST_TRAIT
#undef VISIT_WALKING
#undef VISIT_QUEUE
#undef VISIT_COUNTER
