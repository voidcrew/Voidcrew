/**
 * # World population: fishers (owner items 9 and 10)
 *
 * Owner: PB (planet and field NPCs).
 *
 * "A fishing miner on a lava planet, fishing over a lava river." (spec 4.5)
 * "A fisher NPC on a boat on an ocean planet ocean biome." (spec 4.6)
 *
 * - /datum/ambient_activity/fish: fishing into one water turf, shared with PA's angler at Pike's
 *   pond (spec 3.3). See its doc comment for the API.
 * - The lava fisher: a miner on a folding chair on a lava bank, fishing the lava by a lantern,
 *   cooking one on a hot rock now and then and digging the nearest ore face with the miner's
 *   routine (/datum/ambient_activity/mine). Talk to them and your crew gets a cooked fillet, once.
 *   Attacked, they fight with the pickaxe and run when badly hurt. Killed: a pickaxe and a plain
 *   fishing rod.
 * - The boat fisher: out in open water in a hide boat (/obj/structure/ambient_boat), fishing,
 *   bailing, shouting at the sharks, and every few minutes rowing somewhere else, clear of any
 *   pirate boats. Talk to them from the water and your crew gets a fish thrown to them, once.
 *   Killed: a fishing rod; the boat stays.
 * - Both site kinds' realize() and spot finders (the kinds themselves are in planet_sites.dm).
 *
 * Catches are pictures, never items: the lava fish table holds jackpots (tendril crates, skeleton
 * keys, runite), and a catch never touches a table's counts.
 */

/// How often the boat fisher rows somewhere else
#define AMBIENT_BOAT_ROW_LOW (4 MINUTES)
#define AMBIENT_BOAT_ROW_HIGH (6 MINUTES)

// =========================================================================
// THE FISHING ACTIVITY (API, spec 6.6)
// =========================================================================

/**
 * Fishing into one water turf (lava counts): `new /datum/ambient_activity/fish(npc, water)`. With
 * no water given, the nearest fishing water within `search_range` of the NPC.
 *
 * Where they fish from: where they stand, if it is within `cast_range` of the water (in a boat, or
 * already on the bank); otherwise a free seat within `cast_range` of the water (the seat is turned
 * to face it and they sit); otherwise a free tile right beside it.
 *
 * A cast is a real float (/obj/effect/fishing_float) on the water and the same line a player's
 * rod draws (/datum/beam/fishing_line), with a rod in hand (`rod_look`). After `wait_low` to
 * `wait_high` the float dips (a bite), then they reel in: `catch_chance` percent of the time a
 * catch, otherwise the one that got away. A catch is a picture only: a fish typepath from the
 * water's own fish table (/obj/item/fish subtypes only), held up for `show_time`. Nothing is made
 * and the table's counts are never touched. Then landed(catch_type) runs (override it: let it go,
 * cook it, take it to Pike) and they cast again, until the session ends (duration_low to
 * duration_high).
 *
 * Lines, from the NPC's dialogue section: "fishing" now and then while waiting, "bite", "catch"
 * and "miss". `last_catch`, `catches` and `misses` say how it went. Tests: reel_in(TRUE) or
 * reel_in(FALSE) forces a catch or a miss at once; ambient_fish_picture() picks a catch.
 */
/datum/ambient_activity/fish
	name = "fishing"
	duration_low = 3 MINUTES
	duration_high = 6 MINUTES
	/// Farthest they fish from: tiles between where they stand and the water
	var/cast_range = 2
	/// How far they look for water when not given any
	var/search_range = 5
	/// Time from a cast to the reel-in
	var/wait_low = 30 SECONDS
	var/wait_high = 90 SECONDS
	/// Percent of reel-ins that land something
	var/catch_chance = 50
	/// How long a catch is held up
	var/show_time = 4 SECONDS
	/// What they fish with
	var/rod_look = /obj/item/fishing_rod
	/// Their chatter while they wait
	var/wait_context = "fishing"
	/// The seat they fish from, if any
	var/datum/weakref/seat_ref
	/// The line and float of the cast in the water, if any
	var/datum/beam/fishing_line/line
	var/obj/effect/fishing_float/float
	/// world.time of the reel-in, and of the bite a moment before it
	var/reel_at = 0
	var/bite_at = 0
	var/bitten = FALSE
	/// world.time they stop holding their catch up
	var/showing_until = 0
	/// world.time of the next cast, between casts
	var/recast_at = 0
	/// The last thing they landed (a typepath), and how many landed and got away
	var/last_catch
	var/catches = 0
	var/misses = 0

/datum/ambient_activity/fish/New(mob/living/basic/ambient_npc/new_doer, atom/water)
	. = ..()
	if(!water)
		water = find_water()
		anchor_ref = water ? WEAKREF(water) : null

/datum/ambient_activity/fish/Destroy()
	clear_line()
	return ..()

/// The water they fish, if it is still there
/datum/ambient_activity/fish/proc/water()
	return get_turf(anchor())

/// Fishing water near the NPC: within casting range of where they stand if there is some, else the nearest with a free tile beside it
/datum/ambient_activity/fish/proc/find_water()
	var/turf/here = get_turf(doer)
	if(!here)
		return null
	var/list/near = list()
	var/turf/nearest
	var/nearest_distance = INFINITY
	for(var/turf/tile as anything in RANGE_TURFS(search_range, here))
		if(tile == here || !ambient_fish_source(tile))
			continue
		var/distance = get_dist(here, tile)
		if(distance <= cast_range)
			near += tile
		else if(distance < nearest_distance && doer.free_tile_beside(tile, 1))
			nearest = tile
			nearest_distance = distance
	return length(near) ? pick(near) : nearest

/datum/ambient_activity/fish/setup()
	var/turf/water = water()
	if(!water || !ambient_fish_source(water))
		return FALSE
	var/turf/here = get_turf(doer)
	var/in_range = here && here != water && get_dist(here, water) <= cast_range
	if(doer.buckled && !istype(doer.buckled, /obj/structure/chair))
		// In a boat: from where they sit, or not at all
		if(!in_range)
			return FALSE
		go_to(null)
	else
		// A seat by the water if there is one: the one they are on, or the nearest free one within casting range
		var/obj/structure/chair/seat = locate(/obj/structure/chair) in here
		if(!in_range || !seat || !doer.seat_usable(seat))
			seat = doer.find_seat(water, cast_range, FALSE, failed_spots)
		if(seat)
			seat_ref = WEAKREF(seat)
			go_to(get_turf(seat))
		else if(in_range)
			go_to(null)
		else
			var/turf/stand = doer.free_tile_beside(water, 1, failed_spots)
			if(!stand)
				return FALSE
			go_to(stand)
	set_duration()
	next_line = world.time + rand(20 SECONDS, 40 SECONDS)
	return TRUE

/datum/ambient_activity/fish/arrive()
	var/turf/water = water()
	var/obj/structure/chair/seat = seat_ref?.resolve()
	if(seat && water)
		// Face the water, then sit: the seat turns them with it
		seat.setDir(get_dir(seat, water) || seat.dir)
	if(seat && !doer.sit_on(seat))
		seat_ref = null
	if(water && !doer.buckled)
		doer.face_atom(water)
	cast()

/// Throws the line out: a float on the water, the line from the rod
/datum/ambient_activity/fish/proc/cast()
	var/turf/water = water()
	if(!water)
		return
	clear_line()
	doer.set_held(rod_look)
	float = new(water, water)
	line = new(doer, float, icon_state = "fishing_line", beam_color = "gray", emissive = FALSE)
	INVOKE_ASYNC(line, TYPE_PROC_REF(/datum/beam, Start))
	playsound(water, 'sound/effects/fish_splash.ogg', 15, TRUE, -5)
	reel_at = world.time + rand(wait_low, wait_high)
	bite_at = reel_at - rand(2 SECONDS, 5 SECONDS)
	bitten = FALSE

/// Takes the line and float out of the water
/datum/ambient_activity/fish/proc/clear_line()
	QDEL_NULL(line)
	QDEL_NULL(float)

/datum/ambient_activity/fish/act(seconds)
	if(!water())
		return AMBIENT_STEP_DONE
	if(showing_until)
		if(world.time < showing_until)
			return AMBIENT_STEP_CONTINUE
		showing_until = 0
		doer.set_held(rod_look)
		landed(last_catch)
		recast_at = world.time + rand(3 SECONDS, 8 SECONDS)
		return AMBIENT_STEP_CONTINUE
	if(!float)
		if(world.time >= recast_at)
			cast()
		return AMBIENT_STEP_CONTINUE
	if(!bitten && world.time >= bite_at)
		bitten = TRUE
		bite()
	if(world.time >= reel_at)
		reel_in(prob(catch_chance))
		return AMBIENT_STEP_CONTINUE
	if(prob(3))
		doer.manual_emote(pick("jiggles the line.", "reels in a little.", "checks the bait."))
	chatter(wait_context, 25 SECONDS, 50 SECONDS)
	return AMBIENT_STEP_CONTINUE

/// Something takes the bait: the float dips
/datum/ambient_activity/fish/proc/bite()
	if(float)
		animate(float, pixel_z = -3, time = 0.2 SECONDS, loop = 3)
		animate(pixel_z = 0, time = 0.2 SECONDS)
	doer.speak_context("bite")

/**
 * Reels in now: with `caught`, a picture of a catch from the water's own table (held up for
 * `show_time`), otherwise it got away. Returns the catch typepath, or null. Makes no item.
 */
/datum/ambient_activity/fish/proc/reel_in(caught)
	var/turf/water = water()
	clear_line()
	playsound(doer, SFX_REEL, 30, FALSE, -3)
	var/catch_type = (caught && water) ? ambient_fish_picture(water) : null
	if(!catch_type)
		misses++
		doer.set_held(rod_look)
		doer.speak_context("miss")
		recast_at = world.time + rand(4 SECONDS, 10 SECONDS)
		return null
	catches++
	last_catch = catch_type
	var/obj/item/fish/fish_type = catch_type
	playsound(water, 'sound/effects/fish_splash.ogg', 30, TRUE, -3)
	doer.set_held(catch_type)
	doer.manual_emote("reels in \a [initial(fish_type.name)].")
	doer.speak_context("catch", null, force = prob(50))
	showing_until = world.time + show_time
	return catch_type

/// What they do with a catch once they have shown it off. Override. The default lets it go.
/datum/ambient_activity/fish/proc/landed(catch_type)
	doer.manual_emote(pick("lets it go.", "drops it back in with a splash."))

/datum/ambient_activity/fish/finish()
	clear_line()
	. = ..()
	if(QDELETED(doer))
		return
	var/mob/living/basic/ambient_npc/planet/planet_npc = doer
	if(istype(planet_npc))
		planet_npc.show_idle_held()
	else
		doer.set_held(null)

/datum/ambient_activity/fish/spot_unreachable()
	. = ..()
	seat_ref = null

// The angler at a trader outpost stands still with the line out while nobody is there
/datum/ambient_activity/fish/shift_times(delay)
	. = ..()
	reel_at = ambient_shifted(reel_at, delay)
	bite_at = ambient_shifted(bite_at, delay)
	showing_until = ambient_shifted(showing_until, delay)
	recast_at = ambient_shifted(recast_at, delay)

/// The fish source of `spot` (lava, a pond, the sea), as tg's own NPC fishing asks for it, or null
/proc/ambient_fish_source(atom/spot)
	if(!spot)
		return null
	// Sized as tg's own NPC fishing sizes it (profound_fisher.dm): the answer is written at index NPC_FISHING_SPOT
	var/list/container[NPC_FISHING_SPOT]
	SEND_SIGNAL(spot, COMSIG_NPC_FISHING, container)
	var/datum/fish_source/source = container[NPC_FISHING_SPOT]
	return istype(source) ? source : null

/**
 * A fish typepath from `water`'s own fish table, weighted as the table is, or null. Only
 * /obj/item/fish subtypes: never the table's crates, keys or ore. A picture: nothing is made and
 * the table's counts are not touched.
 */
/proc/ambient_fish_picture(turf/water)
	var/datum/fish_source/source = ambient_fish_source(water)
	if(!source)
		return null
	var/list/table = source.get_fish_table(water)
	var/list/fish = list()
	for(var/result in table)
		if(ispath(result, /obj/item/fish))
			fish[result] = max(1, table[result])
	return length(fish) ? pick_weight(fish) : null

// =========================================================================
// THE LAVA FISHER
// =========================================================================

/datum/outfit/ambient_lava_fisher
	name = "Ambient NPC: lava fisher"
	uniform = /obj/item/clothing/under/rank/cargo/miner/lavaland
	suit = /obj/item/clothing/suit/hooded/explorer
	shoes = /obj/item/clothing/shoes/workboots/mining
	gloves = /obj/item/clothing/gloves/color/black
	glasses = /obj/item/clothing/glasses/meson

/mob/living/basic/ambient_npc/planet/lava_fisher
	name = "lava fisher"
	desc = "A miner in a scorched coat, fishing the lava on a long steel line."
	outfit = /datum/outfit/ambient_lava_fisher
	dialogue_section = "lava_fisher"
	speech_pace = 1.2
	fights_back = TRUE
	weapon_type = /obj/item/pickaxe
	flee_below = 0.35
	death_loot = list(/obj/item/pickaxe, /obj/item/fishing_rod)
	routine = list(
		/datum/ambient_activity/fish/lava = 6,
		/datum/ambient_activity/camp_chore/cook_catch = 1,
		/datum/ambient_activity/mine = 1,
		/datum/ambient_activity/idle = 1,
	)

// Once per crew: a fillet off the hot rock
/mob/living/basic/ambient_npc/planet/lava_fisher/talked_to(mob/living/user)
	if(!talk_ready(user))
		return
	if(!buckled)
		face_atom(user)
	if(!first_for_crew(user, "fillet"))
		speak_context(AMBIENT_LINE_TALK, user, force = TRUE)
		return
	speak_context("gift", user, force = TRUE)
	var/obj/item/food/fishmeat/fillet = new(drop_location())
	user.put_in_hands(fillet)

/// On the lava, from the bank: a catch is dropped in the bucket for later or tossed back
/datum/ambient_activity/fish/lava
	cast_range = 1

// The lava beside their own chair first
/datum/ambient_activity/fish/lava/find_water()
	var/datum/ambient_place/site/site = doer.place
	var/obj/structure/chair/chair = istype(site) ? site.get_prop(/obj/structure/chair) : null
	var/turf/lava = chair ? ambient_lava_beside(get_turf(chair)) : null
	return lava || ..()

/datum/ambient_activity/fish/lava/landed(catch_type)
	doer.manual_emote(pick("drops it in a bucket.", "tosses it back in. It sizzles."))

/// Cooking a catch on a hot rock by the lantern
/datum/ambient_activity/camp_chore/cook_catch
	name = "cooking"
	prop_type = /obj/effect/ambient_camp_prop/lamp
	crouches = TRUE
	duration_low = 30 SECONDS
	duration_high = 60 SECONDS
	held_look = /obj/item/fish/lavaloop
	emotes = list("holds a lavaloop over a hot rock.", "turns the fish over.", "blows on a bit of fish and eats it.")
	line_context = "cooking"

/datum/ambient_site_kind/planet/lava_fisher/realize(datum/ambient_place/site/site)
	var/missing = site.npcs_missing()
	if(!missing)
		return FALSE
	new_visit(site)
	if(!site.data["camp_built"])
		site.data["camp_built"] = TRUE
		var/obj/structure/chair/plastic/chair = make_prop(site, /obj/structure/chair/plastic, site.center)
		var/turf/lava = ambient_lava_beside(site.center)
		if(chair && lava)
			chair.setDir(get_dir(site.center, lava))
	ensure_prop(site, /obj/effect/ambient_camp_prop/lamp, ambient_free_turf_near(site.center, 1))
	for(var/i in 1 to missing)
		var/mob/living/basic/ambient_npc/planet/lava_fisher/fisher = site.spawn_npc(npc_type, ambient_free_turf_near(site.center, 1) || site.center)
		if(fisher)
			fisher.leash_bounds = ambient_square_bounds(site.center, 8)
	return TRUE

// A bank: open ground with fishable lava right beside it (a cardinal step away)
/datum/ambient_site_kind/planet/lava_fisher/find_spot(datum/ambient_planet/record, list/taken)
	var/list/rect = spot_rect(record)
	if(!rect)
		return null
	for(var/attempt in 1 to AMBIENT_SITE_SPOT_TRIES)
		var/turf/sample = ambient_random_turf_in(rect)
		if(!sample)
			continue
		for(var/turf/tile as anything in RANGE_TURFS(4, sample))
			if(!ambient_in_bounds(tile, rect) || !spot_ok(tile) || !ambient_lava_beside(tile))
				continue
			if(!ambient_free_turf_near(tile, 1) || ambient_too_close(tile, taken, AMBIENT_SITE_SPACING))
				continue
			return tile
	return null

// The bank tile itself; the lava beside it is not ground
/datum/ambient_site_kind/planet/lava_fisher/spot_ok(turf/tile)
	return ambient_ground_ok(tile) && istype(get_area(tile), /area/overmap_encounter)

/// A lava turf with fish in it a cardinal step from `tile`, or null
/proc/ambient_lava_beside(turf/tile)
	if(!tile)
		return null
	for(var/direction in GLOB.cardinals)
		var/turf/next = get_step(tile, direction)
		if(islava(next) && ambient_fish_source(next))
			return next
	return null

// =========================================================================
// THE BOAT FISHER
// =========================================================================

/datum/outfit/ambient_boat_fisher
	name = "Ambient NPC: boat fisher"
	uniform = /obj/item/clothing/under/color/blue
	suit = /obj/item/clothing/suit/jacket/puffer/vest
	head = /obj/item/clothing/head/soft/fishing_hat
	shoes = /obj/item/clothing/shoes/workboots

/**
 * A hide boat out on the water: scenery with a seat. The fisher sits in it; it floats (nothing in
 * it is drawn under the water) and rows with them in it. Nobody can pull the fisher out or wreck it.
 */
/obj/structure/ambient_boat
	name = "fishing boat"
	desc = "A small boat of hide stretched over a bone frame. It smells of fish."
	icon = 'icons/obj/mining_zones/dragonboat.dmi'
	icon_state = "goliath_boat"
	anchored = TRUE
	density = FALSE
	can_buckle = TRUE
	buckle_lying = 0
	movement_type = FLOATING
	resistance_flags = INDESTRUCTIBLE | LAVA_PROOF | FIRE_PROOF | ACID_PROOF | UNACIDABLE
	layer = BELOW_MOB_LAYER

// The fisher stays in their boat while they live
/obj/structure/ambient_boat/user_unbuckle_mob(mob/living/buckled_mob, mob/user)
	if(istype(buckled_mob, /mob/living/basic/ambient_npc) && buckled_mob.stat != DEAD)
		return null
	return ..()

/mob/living/basic/ambient_npc/planet/boat_fisher
	name = "fisher"
	desc = "A weathered fisher in a hide boat, line in the water."
	outfit = /datum/outfit/ambient_boat_fisher
	dialogue_section = "boat_fisher"
	speech_pace = 1.2
	watches = TRUE
	death_loot = list(/obj/item/fishing_rod)
	routine = list(
		/datum/ambient_activity/fish/boat = 6,
		/datum/ambient_activity/camp_chore/bail = 1,
		/datum/ambient_activity/idle = 1,
	)
	/// world.time they next row somewhere else
	var/next_row_at = 0

/mob/living/basic/ambient_npc/planet/boat_fisher/Initialize(mapload)
	. = ..()
	next_row_at = world.time + rand(AMBIENT_BOAT_ROW_LOW, AMBIENT_BOAT_ROW_HIGH)

/// The boat they sit in, if any
/mob/living/basic/ambient_npc/planet/boat_fisher/proc/boat()
	var/obj/structure/ambient_boat/boat = buckled
	return istype(boat) ? boat : null

// Every few minutes, a new spot
/mob/living/basic/ambient_npc/planet/boat_fisher/pick_activity()
	if(world.time >= next_row_at && boat())
		next_row_at = world.time + rand(AMBIENT_BOAT_ROW_LOW, AMBIENT_BOAT_ROW_HIGH)
		if(start_activity(new /datum/ambient_activity/row(src)))
			return activity
	return ..()

// Stuck in a boat: a shout, and they row away
/mob/living/basic/ambient_npc/planet/boat_fisher/react_attacked(atom/attacker)
	if(stat != CONSCIOUS || fading)
		return
	if(reaction_ready("attacked", 4 SECONDS))
		speak_context(AMBIENT_LINE_ATTACKED, attacker, force = TRUE)
	if(boat() && !istype(activity, /datum/ambient_activity/row))
		start_activity(new /datum/ambient_activity/row(src, attacker))

// Sharks near the boat get shouted at
/mob/living/basic/ambient_npc/planet/boat_fisher/watch(list/players)
	if(!reaction_ready("sharks", 90 SECONDS))
		return
	for(var/mob/living/basic/carp/shark in range(6, src))
		if(shark.stat == DEAD)
			continue
		face_atom(shark)
		manual_emote("slaps the water with an oar.")
		speak_context("sharks", shark, force = TRUE)
		return
	// Nothing out there: ask again soon
	LAZYSET(reaction_cooldowns, "sharks", world.time + 10 SECONDS)

// Once per crew: a fish thrown over to them
/mob/living/basic/ambient_npc/planet/boat_fisher/talked_to(mob/living/user)
	if(!talk_ready(user))
		return
	if(!first_for_crew(user, "fish_thrown"))
		speak_context(AMBIENT_LINE_TALK, user, force = TRUE)
		return
	speak_context("gift", user, force = TRUE)
	var/obj/item/food/fishmeat/fish = new(drop_location())
	fish.throw_at(user, 4, 1, src)

/// From the boat
/datum/ambient_activity/fish/boat
	cast_range = 2

/datum/ambient_activity/fish/boat/landed(catch_type)
	doer.manual_emote(pick("drops it in the bottom of the boat.", "lets it go.", "puts it in a bucket."))

/// Bailing water out of the boat
/datum/ambient_activity/camp_chore/bail
	name = "bailing"
	duration_low = 20 SECONDS
	duration_high = 40 SECONDS
	held_look = /obj/item/reagent_containers/cup/bucket/wooden
	emotes = list("bails water over the side.", "tips a bucket of water over the side.")
	sounds = list('sound/effects/splash.ogg')

/**
 * Rowing the boat 3 to 6 tiles to open water, a tile a second, the fisher in it. Away from
 * `threat` when given; never near a pirate boat or out of reach of their site.
 */
/datum/ambient_activity/row
	name = "rowing"
	/// What they row away from, if anything
	var/datum/weakref/threat_ref
	/// Where the boat is going
	var/turf/destination

/datum/ambient_activity/row/New(mob/living/basic/ambient_npc/new_doer, atom/threat)
	. = ..()
	threat_ref = threat ? WEAKREF(threat) : null

/datum/ambient_activity/row/Destroy()
	destination = null
	return ..()

/// The boat being rowed
/datum/ambient_activity/row/proc/boat()
	var/obj/structure/ambient_boat/boat = doer.buckled
	return istype(boat) ? boat : null

/datum/ambient_activity/row/setup()
	var/obj/structure/ambient_boat/boat = boat()
	if(!boat)
		return FALSE
	destination = pick_destination(boat)
	if(!destination)
		return FALSE
	go_to(null)
	ends_at = world.time + 20 SECONDS
	doer.manual_emote("picks up the oars.")
	return TRUE

/// Open water 3 to 6 tiles off, away from any threat, clear of pirates, near the site. Null if none.
/datum/ambient_activity/row/proc/pick_destination(obj/structure/ambient_boat/boat)
	var/atom/threat = threat_ref?.resolve()
	var/datum/ambient_place/site/site = doer.place
	var/turf/here = get_turf(boat)
	for(var/attempt in 1 to 10)
		var/heading = (threat && attempt <= 5) ? get_dir(threat, boat) : pick(GLOB.alldirs)
		if(!heading)
			heading = pick(GLOB.alldirs)
		var/turf/target = get_ranged_target_turf(here, heading, rand(3, 6))
		if(!ambient_open_water(target, 1) || !doer.leash_ok(target))
			continue
		if(istype(site) && site.center && get_dist(target, site.center) > 12)
			continue
		if(locate(/mob/living/basic/trooper/pirate) in range(5, target))
			continue
		return target
	return null

/datum/ambient_activity/row/act(seconds)
	var/obj/structure/ambient_boat/boat = boat()
	if(!boat || !destination || get_turf(boat) == destination)
		return AMBIENT_STEP_DONE
	var/turf/next = get_step_towards(boat, destination)
	if(!ambient_open_water(next, 0) || !doer.leash_ok(next))
		return AMBIENT_STEP_DONE
	var/turf/before = get_turf(boat)
	boat.Move(next, get_dir(boat, next))
	if(get_turf(boat) == before)
		return AMBIENT_STEP_DONE
	// Belt and braces: the fisher goes where the boat goes
	if(doer.loc != boat.loc)
		doer.forceMove(boat.loc)
		boat.buckle_mob(doer, force = TRUE)
	if(prob(40))
		playsound(boat, 'sound/effects/splash.ogg', 15, TRUE, -5)
	return AMBIENT_STEP_CONTINUE

/datum/ambient_activity/row/finish()
	. = ..()
	if(!QDELETED(doer))
		doer.manual_emote("ships the oars.")

/// Whether `tile` is water with nothing in the way, and water all around it for `margin` tiles
/proc/ambient_open_water(turf/tile, margin = 1)
	if(!istype(tile, /turf/open/water) || tile.is_blocked_turf(exclude_mobs = TRUE))
		return FALSE
	if(margin <= 0)
		return TRUE
	for(var/turf/around as anything in RANGE_TURFS(margin, tile))
		if(!istype(around, /turf/open/water))
			return FALSE
	return TRUE

/datum/ambient_site_kind/planet/boat_fisher/realize(datum/ambient_place/site/site)
	var/missing = site.npcs_missing()
	if(!missing)
		return FALSE
	new_visit(site)
	// The boat stays where it was last rowed to
	var/obj/structure/ambient_boat/boat = site.get_prop(/obj/structure/ambient_boat)
	if(!boat)
		boat = make_prop(site, /obj/structure/ambient_boat, site.center)
	var/turf/where = get_turf(boat) || site.center
	for(var/i in 1 to missing)
		var/mob/living/basic/ambient_npc/planet/boat_fisher/fisher = site.spawn_npc(npc_type, where)
		if(fisher && boat && !boat.has_buckled_mobs())
			boat.buckle_mob(fisher, force = TRUE)
	return TRUE

// Open sea: fishing water at least three tiles from any shore or rock
/datum/ambient_site_kind/planet/boat_fisher/spot_ok(turf/tile)
	if(!istype(get_area(tile), /area/overmap_encounter) || !ambient_fish_source(tile))
		return FALSE
	return ambient_open_water(tile, 3)

#undef AMBIENT_BOAT_ROW_LOW
#undef AMBIENT_BOAT_ROW_HIGH
