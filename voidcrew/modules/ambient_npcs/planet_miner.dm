/**
 * # World population: the miner (owner item 1)
 *
 * Owner: PB (planet and field NPCs).
 *
 * "A miner NPC slowly mining ores on a planet or an asteroid. Could kill them for some minor
 * equipment." (spec 4.2)
 *
 * - /datum/ambient_activity/mine: dig one ore wall for real. Shared: the lava fisher
 *   (planet_fishers.dm) digs with it too. See its doc comment for the API.
 * - /mob/living/basic/ambient_npc/planet/miner: a prospector with a small camp (a folding chair, a
 *   lantern, a crate) who swings at a rock face for half a minute or more, digs it out, scoops the
 *   ore into a satchel, and every few walls sits down at camp with a flask. Hand them food or a
 *   drink and they trade a little ore from the satchel. Attacked, they fight with the pickaxe and run
 *   when badly hurt. Killed: the pickaxe, the satchel with what they dug, sometimes a scanner.
 *   On an asteroid field (/void) they wear a suit and come in ones and twos.
 * - The miner's site kind's realize() and spot finder (the kind itself is in planet_sites.dm).
 */

/// Ore walls one site's miners dig in a visit
#define AMBIENT_MINE_WALLS_PER_VISIT 10
/// Trades one miner's camp makes in a visit
#define AMBIENT_MINER_BARTERS_PER_VISIT 3

// =========================================================================
// THE MINING ACTIVITY (API, spec 6.6)
// =========================================================================

/**
 * Digs one ore wall for real.
 *
 * - `new /datum/ambient_activity/mine(npc)` digs the nearest good wall within `search_range` of
 *   the NPC; `new /datum/ambient_activity/mine(npc, wall)` digs that wall if it is a good one.
 * - They walk up beside it, swing at it with a pickaxe (`pick_look`) for `swing_low` to
 *   `swing_high`, then dig it out with the rock's own gets_drilled(): the ore is exactly what a
 *   player gets from that wall, zone ore scaling included. If they carry an ore satchel
 *   (/obj/item/storage/bag/ore in their contents) the ore goes into it; otherwise it stays on the
 *   ground.
 * - A good wall (ambient_ore_wall_ok()): ordinary ore (/obj/item/stack/ore), not gibtonite, not
 *   unbreakable rock, and not in or beside a ruin or a ship. Raw telecrystal and glacial cores are
 *   left for players.
 * - At a site, the site's people dig at most AMBIENT_MINE_WALLS_PER_VISIT walls a visit, counted
 *   in the site's per-visit memory ("walls_dug"); setup() refuses after that.
 * - `walls_dug` on the activity is 1 once it has dug its wall.
 */
/datum/ambient_activity/mine
	name = "mining"
	/// How far from the NPC it looks for a wall
	var/search_range = 8
	/// How long they swing at the wall before it comes out
	var/swing_low = 30 SECONDS
	var/swing_high = 60 SECONDS
	/// What they swing with
	var/pick_look = /obj/item/pickaxe
	/// The wall they are digging
	var/datum/weakref/wall_ref
	/// world.time the wall comes out
	var/swing_until = 0
	/// world.time of the next swing
	var/next_swing = 0
	/// Walls it dug (0 or 1)
	var/walls_dug = 0

/datum/ambient_activity/mine/setup()
	if(!isturf(doer.loc) || walls_left() <= 0)
		return FALSE
	var/turf/closed/mineral/wall = anchor()
	if(!ambient_ore_wall_ok(wall))
		wall = find_wall()
	if(!wall)
		return FALSE
	var/turf/stand = standing_spot(wall)
	if(!stand)
		return FALSE
	wall_ref = WEAKREF(wall)
	go_to(stand)
	next_line = world.time + rand(15 SECONDS, 40 SECONDS)
	return TRUE

/// Walls the doer's site may still dig this visit (plenty away from any site)
/datum/ambient_activity/mine/proc/walls_left()
	var/datum/ambient_place/site/site = doer.place
	if(!istype(site))
		return AMBIENT_MINE_WALLS_PER_VISIT
	var/list/visit = ambient_site_visit(site)
	return AMBIENT_MINE_WALLS_PER_VISIT - (visit["walls_dug"] || 0)

/// Where they could stand to dig `wall`: where they are if it is right there, else a free tile beside it
/datum/ambient_activity/mine/proc/standing_spot(turf/closed/mineral/wall)
	var/turf/here = get_turf(doer)
	if(here && get_dist(here, wall) <= 1 && here.Adjacent(wall))
		return here
	return doer.free_tile_beside(wall, 1, failed_spots)

/// The nearest good wall they could get to within `search_range`, or null
/datum/ambient_activity/mine/proc/find_wall()
	var/turf/here = get_turf(doer)
	if(!here)
		return null
	var/list/candidates = list()
	for(var/turf/closed/mineral/rock in RANGE_TURFS(search_range, here))
		if(ambient_ore_wall_ok(rock))
			candidates[rock] = get_dist(here, rock)
	// Nearest first; only the first few are checked for somewhere to stand
	sortTim(candidates, GLOBAL_PROC_REF(cmp_numeric_asc), associative = TRUE)
	var/checked = 0
	for(var/turf/closed/mineral/rock as anything in candidates)
		if(++checked > 6)
			break
		if(standing_spot(rock))
			return rock
	return null

/datum/ambient_activity/mine/arrive()
	var/turf/closed/mineral/wall = wall_ref?.resolve()
	if(wall)
		doer.face_atom(wall)
	doer.set_held(pick_look)
	swing_until = world.time + rand(swing_low, swing_high)
	next_swing = world.time

/datum/ambient_activity/mine/act(seconds)
	var/turf/closed/mineral/wall = wall_ref?.resolve()
	// Somebody else dug it, or it was never ore
	if(!ambient_ore_wall_ok(wall) || get_dist(doer, wall) > 1)
		return AMBIENT_STEP_DONE
	if(world.time < swing_until)
		if(world.time >= next_swing)
			next_swing = world.time + rand(2 SECONDS, 4 SECONDS)
			swing(wall)
		chatter(AMBIENT_LINE_WORK, 30 SECONDS, 60 SECONDS)
		return AMBIENT_STEP_CONTINUE
	dig(wall)
	return AMBIENT_STEP_DONE

/// One swing of the pick at `wall`
/datum/ambient_activity/mine/proc/swing(turf/closed/mineral/wall)
	doer.face_atom(wall)
	doer.do_attack_animation(wall)
	playsound(wall, pick('sound/effects/pickaxe/picaxe1.ogg', 'sound/effects/pickaxe/picaxe2.ogg', 'sound/effects/pickaxe/picaxe3.ogg'), 40, TRUE, -2)

/// Digs `wall` out, as a player's pick would, and scoops up its ore. Returns the ore picked up.
/datum/ambient_activity/mine/proc/dig(turf/closed/mineral/wall)
	var/turf/where = wall
	// No user: nobody gets mining experience or the mined signal; the ore and the zone scaling are the rock's own
	wall.gets_drilled(null, 0)
	walls_dug = 1
	var/datum/ambient_place/site/site = doer.place
	if(istype(site))
		var/list/visit = ambient_site_visit(site)
		visit["walls_dug"] = (visit["walls_dug"] || 0) + 1
	. = list()
	var/obj/item/storage/bag/ore/satchel = locate() in doer
	for(var/obj/item/stack/ore/ore in where)
		. += ore
		if(satchel)
			ore.forceMove(satchel)
	if(length(.))
		doer.manual_emote("scoops the ore up.")

/datum/ambient_activity/mine/finish()
	. = ..()
	if(QDELETED(doer))
		return
	var/mob/living/basic/ambient_npc/planet/planet_npc = doer
	if(istype(planet_npc))
		planet_npc.show_idle_held()
	else
		doer.set_held(null)

/**
 * Whether `wall` is a rock face an NPC may dig: ordinary ore, breakable, not gibtonite, and neither
 * it nor anything beside it part of a ruin or a ship.
 */
/proc/ambient_ore_wall_ok(turf/closed/mineral/wall)
	if(!istype(wall) || istype(wall, /turf/closed/mineral/gibtonite) || istype(wall, /turf/closed/mineral/strong))
		return FALSE
	if(!ispath(wall.mineralType, /obj/item/stack/ore) || wall.mineralAmt <= 0)
		return FALSE
	for(var/turf/near as anything in RANGE_TURFS(1, wall))
		if(ambient_off_limits(near))
			return FALSE
	return TRUE

/// Whether there is a good ore wall within `range` of `center`
/proc/ambient_ore_wall_near(turf/center, range)
	if(!center)
		return FALSE
	for(var/turf/closed/mineral/rock in RANGE_TURFS(range, center))
		if(ambient_ore_wall_ok(rock))
			return TRUE
	return FALSE

// =========================================================================
// THE MINER
// =========================================================================

/datum/outfit/ambient_miner
	name = "Ambient NPC: prospector"
	uniform = /obj/item/clothing/under/rank/cargo/miner/lavaland
	shoes = /obj/item/clothing/shoes/workboots/mining
	gloves = /obj/item/clothing/gloves/color/black
	head = /obj/item/clothing/head/utility/hardhat/orange

/datum/outfit/ambient_miner/winter
	name = "Ambient NPC: prospector in a coat"
	suit = /obj/item/clothing/suit/hooded/wintercoat/miner

/datum/outfit/ambient_miner/void
	name = "Ambient NPC: asteroid miner"
	suit = /obj/item/clothing/suit/space/eva
	head = /obj/item/clothing/head/helmet/space/eva

/mob/living/basic/ambient_npc/planet/miner
	name = "miner"
	desc = "A prospector in dusty overalls, working the rock by hand."
	outfit_choices = list(/datum/outfit/ambient_miner, /datum/outfit/ambient_miner/winter)
	dialogue_section = "miner"
	speech_pace = 1.2
	fights_back = TRUE
	weapon_type = /obj/item/pickaxe
	flee_below = 0.35
	death_loot = list(/obj/item/pickaxe)
	routine = list(
		/datum/ambient_activity/mine = 6,
		/datum/ambient_activity/camp_chore/miner_rest = 2,
		/datum/ambient_activity/camp_chore/miner_flask = 1,
		/datum/ambient_activity/idle = 1,
		/datum/ambient_activity/wander = 1,
	)
	/// The satchel the ore goes into; dropped with them
	var/obj/item/storage/bag/ore/ore_bag

/mob/living/basic/ambient_npc/planet/miner/Initialize(mapload)
	. = ..()
	ore_bag = new(src)
	if(prob(50))
		death_loot = death_loot + /obj/item/mining_scanner

/mob/living/basic/ambient_npc/planet/miner/Destroy()
	QDEL_NULL(ore_bag)
	return ..()

// The satchel with what they dug goes down with them, once
/mob/living/basic/ambient_npc/planet/miner/drop_loot()
	var/first_time = !loot_dropped
	. = ..()
	if(!first_time || QDELETED(ore_bag))
		return
	var/turf/drop_turf = drop_location()
	if(drop_turf)
		ore_bag.forceMove(drop_turf)
		ore_bag = null

/// Units of ore in their satchel
/mob/living/basic/ambient_npc/planet/miner/proc/ore_carried()
	. = 0
	for(var/obj/item/stack/ore/ore in ore_bag)
		. += ore.amount

/**
 * The barter: a bite to eat or something to drink for a little ore from the satchel. Only what they
 * dug on this rock, and only a few trades a visit for the whole camp.
 */
/mob/living/basic/ambient_npc/planet/miner/item_interaction(mob/living/user, obj/item/tool, list/modifiers)
	if(user.combat_mode || !can_act() || !ambient_is_refreshment(tool))
		return ..()
	barter(user, tool)
	return ITEM_INTERACT_SUCCESS

/// Trades `refreshment` from `user` for one to three ore. TRUE if the trade was made.
/mob/living/basic/ambient_npc/planet/miner/proc/barter(mob/living/user, obj/item/refreshment)
	if(!buckled)
		face_atom(user)
	var/datum/ambient_place/site/site = place
	var/list/visit = ambient_site_visit(site)
	if((visit["barters"] || 0) >= AMBIENT_MINER_BARTERS_PER_VISIT)
		speak_context("barter_done", user, force = TRUE)
		return FALSE
	var/list/stacks = list()
	for(var/obj/item/stack/ore/ore in ore_bag)
		stacks += ore
	if(!length(stacks))
		speak_context("barter_none", user, force = TRUE)
		return FALSE
	var/refreshment_name = refreshment.name
	if(!user.temporarilyRemoveItemFromInventory(refreshment))
		return FALSE
	qdel(refreshment)
	visit["barters"] = (visit["barters"] || 0) + 1
	manual_emote("takes the [refreshment_name] and tucks in.")
	var/obj/item/stack/ore/stack = pick(stacks)
	var/obj/item/stack/ore/payment = stack.split_stack(min(rand(1, 3), stack.amount))
	if(payment)
		payment.forceMove(drop_location())
		user.put_in_hands(payment)
	speak_context("barter", user, force = TRUE)
	return TRUE

/// Whether `thing` is something to eat, or a drink with something in it
/proc/ambient_is_refreshment(obj/item/thing)
	if(istype(thing, /obj/item/food))
		return TRUE
	if(istype(thing, /obj/item/reagent_containers/cup/glass) || istype(thing, /obj/item/reagent_containers/cup/soda_cans))
		return thing.reagents?.total_volume > 0
	return FALSE

/// Out on an asteroid, in a suit
/mob/living/basic/ambient_npc/planet/miner/void
	desc = "A prospector in a patched suit, chipping at the asteroid."
	outfit_choices = null
	outfit = /datum/outfit/ambient_miner/void

// ----- chores -----

/// A rest at camp, turning a chunk of ore over
/datum/ambient_activity/camp_chore/miner_rest
	name = "resting"
	prop_type = /obj/structure/chair/plastic
	sits = TRUE
	held_look = /obj/item/stack/ore/iron
	emotes = list("turns a chunk of ore over in their hands.", "squints at a rock.", "stretches their back.")

/// A pull from the flask, sitting down
/datum/ambient_activity/camp_chore/miner_flask
	name = "drinking"
	prop_type = /obj/structure/chair/plastic
	sits = TRUE
	duration_low = 30 SECONDS
	duration_high = 60 SECONDS
	held_look = /obj/item/reagent_containers/cup/glass/flask
	emotes = list("takes a pull from a flask.", "wipes their mouth.")
	sounds = list('sound/items/drink.ogg')

// =========================================================================
// THE CAMP
// =========================================================================

/datum/ambient_site_kind/planet/miner/realize(datum/ambient_place/site/site)
	// An asteroid field is worked by one or two
	if(site.field_ref && !site.data["sized"])
		site.data["sized"] = TRUE
		site.npc_total = rand(1, 2)
	var/missing = site.npcs_missing()
	if(!missing)
		return FALSE
	new_visit(site)
	build_camp(site)
	var/miner_type = site.field_ref ? /mob/living/basic/ambient_npc/planet/miner/void : npc_type
	for(var/i in 1 to missing)
		var/turf/where = ambient_free_turf_near(site.center, 2) || site.center
		var/mob/living/basic/ambient_npc/planet/miner/miner = site.spawn_npc(miner_type, where)
		if(miner)
			miner.leash_bounds = ambient_square_bounds(site.center, 12)
	return TRUE

/// The chair and the crate once; the lantern whenever it is missing (it is scenery)
/datum/ambient_site_kind/planet/miner/proc/build_camp(datum/ambient_place/site/site)
	if(!site.data["camp_built"])
		site.data["camp_built"] = TRUE
		var/obj/structure/chair/plastic/chair = make_prop(site, /obj/structure/chair/plastic, site.center)
		chair?.setDir(pick(GLOB.cardinals))
		make_prop(site, /obj/structure/closet/crate/wooden, ambient_free_turf_near(site.center, 1))
	ensure_prop(site, /obj/effect/ambient_camp_prop/lamp, ambient_free_turf_near(site.center, 1))

// Open ground with an ore face near it
/datum/ambient_site_kind/planet/miner/find_spot(datum/ambient_planet/record, list/taken)
	var/list/rect = spot_rect(record)
	if(!rect)
		return null
	for(var/attempt in 1 to AMBIENT_SITE_SPOT_TRIES)
		var/turf/tile = ambient_random_turf_in(rect)
		if(!spot_ok(tile) || ambient_too_close(tile, taken, AMBIENT_SITE_SPACING) || !ambient_ore_wall_near(tile, 6))
			continue
		return tile
	return null

/datum/ambient_site_kind/planet/miner/find_field_spot(list/open_turfs, list/taken)
	for(var/attempt in 1 to min(AMBIENT_SITE_SPOT_TRIES, length(open_turfs)))
		var/turf/tile = pick(open_turfs)
		if(!ambient_ground_ok(tile) || ambient_too_close(tile, taken, AMBIENT_SITE_SPACING) || !ambient_ore_wall_near(tile, 6))
			continue
		return tile
	return null

#undef AMBIENT_MINE_WALLS_PER_VISIT
#undef AMBIENT_MINER_BARTERS_PER_VISIT
