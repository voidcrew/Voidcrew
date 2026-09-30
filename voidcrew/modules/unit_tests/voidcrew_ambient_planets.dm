/**
 * World population: tests for planet_sites.dm, planet_miner.dm, planet_jungle.dm,
 * planet_fishers.dm and planet_peddler.dm
 * in voidcrew/modules/ambient_npcs/.
 *
 * Owner: PB (planet and field NPCs).
 *
 * Fork defines are included after the tests, so a test uses the literal value with a comment
 * naming the define. SSambient_npcs does nothing on its own in tests (`ambient_auto`), and no NPC's
 * AI runs without a client near, so the tests build sites and drive activities and watches by
 * hand, in the 5x5 test room.
 */

/// Base for PB's tests: turfs a test changes are put back to iron floor when it ends
/datum/unit_test/voidcrew_ambient_pb
	abstract_type = /datum/unit_test/voidcrew_ambient_pb
	/// Turfs this test changed
	var/list/turf/changed_turfs = list()

/datum/unit_test/voidcrew_ambient_pb/Destroy()
	for(var/turf/changed as anything in changed_turfs)
		changed.ChangeTurf(/turf/open/floor/iron)
	changed_turfs = null
	return ..()

/// The test room's turf `dx`, `dy` from its bottom left corner
/datum/unit_test/voidcrew_ambient_pb/proc/room_turf(dx, dy)
	return locate(run_loc_floor_bottom_left.x + dx, run_loc_floor_bottom_left.y + dy, run_loc_floor_bottom_left.z)

/// Changes the room's turf at `dx`, `dy` to `new_type` until the test ends. Returns the new turf.
/datum/unit_test/voidcrew_ambient_pb/proc/change_room_turf(dx, dy, new_type)
	var/turf/spot = room_turf(dx, dy)
	changed_turfs |= spot
	return spot.ChangeTurf(new_type)

/// How many things of `thing_type` lie loose in the test room
/datum/unit_test/voidcrew_ambient_pb/proc/count_in_room(thing_type)
	. = 0
	for(var/turf/tile as anything in block(run_loc_floor_bottom_left, run_loc_floor_top_right))
		for(var/atom/movable/thing in tile)
			if(istype(thing, thing_type))
				.++

/// How many things of `thing_type` `holder` has in hand
/proc/pb_test_count_held(mob/living/holder, thing_type)
	. = 0
	for(var/obj/item/held in holder.held_items)
		if(istype(held, thing_type))
			.++

// =========================================================================
// THE TABLE
// =========================================================================

/// Each camp rolls on exactly the planet types and chances of spec 4.1, with the right band sizes, and every PB person talks
/datum/unit_test/voidcrew_ambient_pb/table

/datum/unit_test/voidcrew_ambient_pb/table/Run()
	var/list/planets = list(
		/datum/overmap/planet/jungle,
		/datum/overmap/planet/lava,
		/datum/overmap/planet/beach,
		/datum/overmap/planet/ice,
		/datum/overmap/planet/wasteland,
	)
	var/list/expected = list(
		/datum/ambient_site_kind/planet = list(),
		/datum/ambient_site_kind/planet/miner = list(
			/datum/overmap/planet/jungle = 8,
			/datum/overmap/planet/lava = 12,
			/datum/overmap/planet/beach = 5,
			/datum/overmap/planet/ice = 12,
			/datum/overmap/planet/wasteland = 12,
		),
		/datum/ambient_site_kind/planet/cannibal = list(/datum/overmap/planet/jungle = 8),
		/datum/ambient_site_kind/planet/tribal = list(/datum/overmap/planet/jungle = 12),
		/datum/ambient_site_kind/planet/lava_fisher = list(/datum/overmap/planet/lava = 15),
		/datum/ambient_site_kind/planet/boat_fisher = list(/datum/overmap/planet/beach = 18),
		/datum/ambient_site_kind/planet/peddler = list(
			/datum/overmap/planet/jungle = 6,
			/datum/overmap/planet/lava = 4,
			/datum/overmap/planet/beach = 8,
			/datum/overmap/planet/ice = 6,
			/datum/overmap/planet/wasteland = 6,
		),
	)
	var/datum/ambient_planet/record = allocate(/datum/ambient_planet)
	record.band = 1 // ZONE_GREEN
	for(var/kind_type in expected)
		var/datum/ambient_site_kind/planet/kind = allocate(kind_type)
		var/list/chances = expected[kind_type]
		for(var/planet_type in planets)
			record.planet_type = planet_type
			var/wanted = chances[planet_type] || 0
			TEST_ASSERT_EQUAL(kind.chance_on(record), wanted, "[kind_type] rolls [kind.chance_on(record)]% on [planet_type], not [wanted]%")
		if(kind.npc_type)
			TEST_ASSERT(ispath(kind.npc_type, /mob/living/basic/ambient_npc/planet), "[kind_type] brings out [kind.npc_type], not a planet person")
	var/datum/ambient_site_kind/planet/miner/miner_kind = allocate(/datum/ambient_site_kind/planet/miner)
	TEST_ASSERT_EQUAL(miner_kind.field_chance, 10, "Miners are not on asteroid fields one time in ten")

	// Bigger hunting bands deeper out; a guard with the caravan past green
	var/datum/ambient_site_kind/planet/tribal/tribal = allocate(/datum/ambient_site_kind/planet/tribal)
	TEST_ASSERT_EQUAL(tribal.npc_count(1), 3, "A green band is not three hunters") // ZONE_GREEN
	TEST_ASSERT_EQUAL(tribal.npc_count(2), 4, "A yellow band is not four hunters") // ZONE_YELLOW
	TEST_ASSERT_EQUAL(tribal.npc_count(3), 5, "A red band is not five hunters") // ZONE_RED
	var/datum/ambient_site_kind/planet/peddler/peddler = allocate(/datum/ambient_site_kind/planet/peddler)
	TEST_ASSERT_EQUAL(peddler.npc_count(1), 2, "A green caravan is not a peddler and a pony") // ZONE_GREEN
	TEST_ASSERT_EQUAL(peddler.npc_count(3), 3, "A red caravan has no guard") // ZONE_RED
	TEST_ASSERT_EQUAL(ambient_ambush_size(1), 0, "Caravans are jumped in green") // ZONE_GREEN
	TEST_ASSERT(ambient_ambush_size(3) > ambient_ambush_size(2), "A red ambush is no bigger than a yellow one") // ZONE_RED, ZONE_YELLOW

	// Everyone has lines of their own, and anyone can be hurt
	var/list/people = list(
		/mob/living/basic/ambient_npc/planet/miner,
		/mob/living/basic/ambient_npc/planet/lava_fisher,
		/mob/living/basic/ambient_npc/planet/boat_fisher,
		/mob/living/basic/ambient_npc/planet/cannibal,
		/mob/living/basic/ambient_npc/planet/tribal,
		/mob/living/basic/ambient_npc/planet/peddler,
		/mob/living/basic/ambient_npc/planet/caravan_guard,
	)
	for(var/npc_type in people)
		var/mob/living/basic/ambient_npc/planet/npc = allocate(npc_type)
		TEST_ASSERT_EQUAL(npc.dialogue_file, "planet_npcs.json", "[npc_type] does not talk from the planet file") // AMBIENT_STRINGS_PLANETS
		TEST_ASSERT(length(ambient_dialogue_lines("planet_npcs.json", npc.dialogue_section, "talk")), "[npc_type] has no talk lines of their own") // AMBIENT_LINE_TALK
		TEST_ASSERT(length(npc.get_lines("attacked")), "[npc_type] has nothing to say when attacked") // AMBIENT_LINE_ATTACKED
		TEST_ASSERT(!HAS_TRAIT(npc, TRAIT_GODMODE), "[npc_type] cannot be hurt")

// =========================================================================
// FISHING
// =========================================================================

/// The fishing activity: a real float and line on the water, a bite, a reel-in; a catch is a picture that makes nothing and touches no fish counts; finishing takes the line out
/datum/unit_test/voidcrew_ambient_pb/fishing

/datum/unit_test/voidcrew_ambient_pb/fishing/Run()
	var/turf/water = change_room_turf(2, 2, /turf/open/water/beach)
	var/datum/fish_source/source = ambient_fish_source(water)
	TEST_ASSERT_NOTNULL(source, "Beach water has no fish source for an NPC")
	TEST_ASSERT_NULL(ambient_fish_source(room_turf(0, 0)), "A floor has fish in it")

	var/mob/living/basic/ambient_npc/planet/boat_fisher/angler = allocate(/mob/living/basic/ambient_npc/planet/boat_fisher, room_turf(0, 0))
	var/datum/ambient_activity/fish/fishing = angler.start_activity(new /datum/ambient_activity/fish(angler, water))
	TEST_ASSERT_NOTNULL(fishing, "Fishing water two tiles off could not start")
	if(fishing.spot)
		angler.forceMove(fishing.spot)
	TEST_ASSERT_EQUAL(angler.activity_step(1), 0, "Fishing stopped at once") // AMBIENT_STEP_CONTINUE
	TEST_ASSERT_NOTNULL(fishing.float, "No float went into the water")
	TEST_ASSERT_EQUAL(get_turf(fishing.float), water, "The float is not on the water")
	TEST_ASSERT_NOTNULL(fishing.line, "No line was drawn to the float")
	TEST_ASSERT(fishing.reel_at > world.time, "The first reel-in is due at once")

	// A catch: a picture from the water's own table, nothing made, no count touched
	var/list/counts_before = source.fish_counts.Copy()
	var/items_before = count_in_room(/obj/item)
	var/catch_type = fishing.reel_in(TRUE)
	TEST_ASSERT(ispath(catch_type, /obj/item/fish), "A catch from the sea was [catch_type], not a fish")
	TEST_ASSERT_EQUAL(fishing.last_catch, catch_type, "The catch was not remembered")
	TEST_ASSERT_NULL(fishing.float, "The float stayed out after reeling in")
	TEST_ASSERT_EQUAL(count_in_room(/obj/item), items_before, "Reeling in a catch made an item")
	for(var/fish_type in counts_before)
		TEST_ASSERT_EQUAL(source.fish_counts[fish_type], counts_before[fish_type], "A pictured catch took [fish_type] out of the water's fish counts")

	// A miss, then the next cast
	TEST_ASSERT_NULL(fishing.reel_in(FALSE), "A miss landed something")
	TEST_ASSERT_EQUAL(fishing.misses, 1, "A miss was not counted")
	fishing.showing_until = 0
	fishing.recast_at = world.time
	angler.activity_step(1)
	TEST_ASSERT_NOTNULL(fishing.float, "They did not cast again")

	// Done: the line comes out of the water
	var/obj/effect/fishing_float/float = fishing.float
	angler.end_activity()
	TEST_ASSERT(QDELETED(float), "The float stayed in the water after fishing")

	// Lava catches are only ever pictures of fish: never the table's crates, keys or ore
	var/turf/lava = change_room_turf(4, 4, /turf/open/lava/smooth)
	TEST_ASSERT_NOTNULL(ambient_fish_source(lava), "Lava has no fish source for an NPC")
	for(var/i in 1 to 40)
		var/picture = ambient_fish_picture(lava)
		TEST_ASSERT(isnull(picture) || ispath(picture, /obj/item/fish), "A lava catch was pictured as [picture]")

// =========================================================================
// MINING
// =========================================================================

/// The mining activity digs one ore wall for real, the ore goes into the satchel, and a camp stops at its walls for the visit; the miner barters a little ore for food, a few times a visit; killed, the pickaxe and the satchel drop once
/datum/unit_test/voidcrew_ambient_pb/mining

/datum/unit_test/voidcrew_ambient_pb/mining/Run()
	var/turf/closed/mineral/wall = change_room_turf(2, 2, /turf/closed/mineral/iron)
	TEST_ASSERT(istype(wall, /turf/closed/mineral/iron), "The test wall is not iron ore")
	TEST_ASSERT(ambient_ore_wall_ok(wall), "An iron wall in the open cannot be dug")
	TEST_ASSERT(!ambient_ore_wall_ok(room_turf(0, 0)), "A floor counts as an ore wall")

	var/mob/living/basic/ambient_npc/planet/miner/miner = allocate(/mob/living/basic/ambient_npc/planet/miner, room_turf(1, 2))
	TEST_ASSERT_NOTNULL(miner.ore_bag, "A miner has no satchel")
	var/datum/ambient_activity/mine/mine = miner.start_activity(new /datum/ambient_activity/mine(miner, wall))
	TEST_ASSERT_NOTNULL(mine, "A miner beside an ore wall would not dig it")
	if(mine.spot)
		miner.forceMove(mine.spot)
	TEST_ASSERT_EQUAL(miner.activity_step(1), 0, "Mining stopped at the first swing") // AMBIENT_STEP_CONTINUE
	TEST_ASSERT(mine.swing_until >= world.time + 300, "The wall comes out in under half a minute") // 30 SECONDS
	mine.swing_until = world.time
	TEST_ASSERT_EQUAL(miner.activity_step(1), 2, "Mining did not end once the wall came out") // AMBIENT_STEP_DONE
	miner.end_activity()
	TEST_ASSERT(!istype(room_turf(2, 2), /turf/closed/mineral), "The wall is still standing after it was dug")
	TEST_ASSERT(miner.ore_carried() > 0, "The ore did not go into the satchel")
	TEST_ASSERT_EQUAL(count_in_room(/obj/item/stack/ore), 0, "Dug ore was left lying on the floor")

	// A camp digs only so many walls a visit
	var/datum/ambient_site_kind/planet/miner/kind = allocate(/datum/ambient_site_kind/planet/miner)
	var/datum/ambient_place/site/site = allocate(/datum/ambient_place/site, kind, room_turf(0, 0), null)
	miner.set_place(site)
	var/turf/closed/mineral/second = change_room_turf(2, 3, /turf/closed/mineral/iron)
	var/list/visit = ambient_site_visit(site)
	visit["walls_dug"] = 10 // AMBIENT_MINE_WALLS_PER_VISIT
	TEST_ASSERT_NULL(miner.start_activity(new /datum/ambient_activity/mine(miner, second)), "A camp went on digging past its walls for the visit")
	visit["walls_dug"] = 0
	TEST_ASSERT_NOTNULL(miner.start_activity(new /datum/ambient_activity/mine(miner, second)), "A camp with walls to spare would not dig")
	miner.end_activity()

	// The barter: food for ore, a few times a visit, and never with an empty satchel
	new /obj/item/stack/ore/iron(miner.ore_bag, 20)
	var/mob/living/carbon/human/consistent/customer = allocate(/mob/living/carbon/human/consistent, room_turf(0, 2))
	for(var/trade in 1 to 3) // AMBIENT_MINER_BARTERS_PER_VISIT
		customer.drop_all_held_items()
		var/obj/item/food/rationpack/snack = allocate(/obj/item/food/rationpack)
		customer.put_in_hands(snack)
		TEST_ASSERT_EQUAL(miner.item_interaction(customer, snack, list()), 1, "The miner would not trade for food on trade [trade]") // ITEM_INTERACT_SUCCESS
		TEST_ASSERT(QDELETED(snack), "The miner traded without taking the food")
		TEST_ASSERT(pb_test_count_held(customer, /obj/item/stack/ore), "Trade [trade] paid no ore")
	customer.drop_all_held_items()
	var/obj/item/food/rationpack/one_more = allocate(/obj/item/food/rationpack)
	customer.put_in_hands(one_more)
	miner.item_interaction(customer, one_more, list())
	TEST_ASSERT(!QDELETED(one_more), "The miner traded more than a few times in one visit")
	var/obj/item/stack/ore/not_food = allocate(/obj/item/stack/ore/iron)
	TEST_ASSERT(!ambient_is_refreshment(not_food), "Ore counts as something to eat")

	// Killed: the pickaxe and the satchel with what they dug, once
	var/turf/body_turf = get_turf(miner)
	miner.death()
	TEST_ASSERT_EQUAL(miner.stat, DEAD, "The miner did not die")
	var/obj/item/storage/bag/ore/satchel = locate() in body_turf
	TEST_ASSERT_NOTNULL(satchel, "The miner's satchel did not drop")
	TEST_ASSERT_NOTNULL(locate(/obj/item/stack/ore) in satchel, "The dropped satchel is empty")
	var/pickaxes = 0
	for(var/obj/item/pickaxe/pick in body_turf)
		pickaxes++
	TEST_ASSERT_EQUAL(pickaxes, 1, "The miner dropped [pickaxes] pickaxes")
	miner.revive(ADMIN_HEAL_ALL)
	miner.death()
	pickaxes = 0
	for(var/obj/item/pickaxe/pick in body_turf)
		pickaxes++
	TEST_ASSERT_EQUAL(pickaxes, 1, "A revived miner dropped their loot again")

// =========================================================================
// FIGHTING
// =========================================================================

/// A planet fighter hit by someone fights them with their weapon's real numbers; the leash holds them near their camp
/datum/unit_test/voidcrew_ambient_pb/fighting

/datum/unit_test/voidcrew_ambient_pb/fighting/Run()
	var/mob/living/basic/ambient_npc/planet/miner/miner = allocate(/mob/living/basic/ambient_npc/planet/miner, room_turf(0, 0))
	var/mob/living/carbon/human/consistent/brute = allocate(/mob/living/carbon/human/consistent, room_turf(1, 0))
	var/obj/item/pickaxe/reference = allocate(/obj/item/pickaxe)
	TEST_ASSERT_EQUAL(miner.melee_damage_upper, reference.force, "A miner does not hit like their pickaxe")
	miner.react_attacked(brute)
	var/datum/ambient_activity/fight/fight = miner.activity
	TEST_ASSERT(istype(fight), "A miner who was hit did not fight back")
	TEST_ASSERT_EQUAL(fight.target(), brute, "The miner fights someone other than who hit them")
	var/health_before = brute.health
	fight.next_blow = world.time
	miner.activity_step(1)
	TEST_ASSERT(brute.health < health_before, "The miner's blow did nothing")

	// Someone who is not a fighter runs instead
	var/mob/living/basic/ambient_npc/planet/boat_fisher/meek = allocate(/mob/living/basic/ambient_npc/planet/boat_fisher, room_turf(4, 4))
	meek.react_attacked(brute)
	TEST_ASSERT(!istype(meek.activity, /datum/ambient_activity/fight), "A boat fisher picked a fight")

	// A leash holds a camp's fighters near it
	var/turf/center = room_turf(2, 2)
	var/mob/living/basic/ambient_npc/planet/tribal/hunter = allocate(/mob/living/basic/ambient_npc/planet/tribal, center)
	hunter.leash_bounds = ambient_square_bounds(center, 12)
	TEST_ASSERT(hunter.leash_ok(locate(center.x + 12, center.y, center.z)), "A hunter's leash stops short of five tiles past the ring")
	TEST_ASSERT(!hunter.leash_ok(locate(center.x + 13, center.y, center.z)), "A hunter's leash reaches past five tiles beyond the ring")

// =========================================================================
// THE JUNGLE
// =========================================================================

/// The cannibal's camp: the stake fire with a body on it, the grill with meat; he invites, warns and only then attacks, or attacks anyone who comes right up
/datum/unit_test/voidcrew_ambient_pb/cannibal

/datum/unit_test/voidcrew_ambient_pb/cannibal/Run()
	var/turf/center = room_turf(2, 2)
	var/datum/ambient_site_kind/planet/cannibal/kind = allocate(/datum/ambient_site_kind/planet/cannibal)
	var/datum/ambient_place/site/site = allocate(/datum/ambient_place/site, kind, center, null)
	site.band = 1 // ZONE_GREEN
	site.npc_total = 1
	TEST_ASSERT(kind.realize(site), "The cannibal's camp did not come out")
	var/obj/structure/bonfire/dense/ambient_camp/stake/stake = site.get_prop(/obj/structure/bonfire/dense/ambient_camp/stake)
	TEST_ASSERT_NOTNULL(stake, "The camp has no stake fire")
	TEST_ASSERT_EQUAL(get_turf(stake), center, "The stake fire is not in the middle of the camp")
	TEST_ASSERT(stake.density, "Someone could walk into the camp's fire")
	TEST_ASSERT_NOTNULL(site.get_prop(/obj/structure/bonfire/dense/ambient_camp/grill), "The camp has no grill")
	TEST_ASSERT(count_in_room(/obj/item/food/meat/slab/human), "Nothing is cooking on the grill")

	// The body goes up async (dressing a body can sleep)
	var/mob/living/carbon/human/body
	for(var/wait in 1 to 50)
		body = site.get_prop(/mob/living/carbon/human)
		if(body)
			break
		sleep(1)
	TEST_ASSERT_NOTNULL(body, "No body was put on the stake")
	TEST_ASSERT_EQUAL(body.stat, DEAD, "The body on the stake is alive")
	TEST_ASSERT_EQUAL(body.buckled, stake, "The body is not tied to the stake")

	var/mob/living/basic/ambient_npc/planet/cannibal/cannibal = locate() in site.living_npcs()
	TEST_ASSERT_NOTNULL(cannibal, "The cannibal did not come out")
	cannibal.forceMove(room_turf(0, 0))
	var/mob/living/carbon/human/consistent/guest = allocate(/mob/living/carbon/human/consistent, room_turf(4, 4))

	// First sight: an invitation, no blows; lingering: a warning, still no blows
	cannibal.watch(list(guest))
	TEST_ASSERT(!istype(cannibal.activity, /datum/ambient_activity/fight), "The cannibal attacked someone on sight")
	cannibal.watch(list(guest))
	TEST_ASSERT(!istype(cannibal.activity, /datum/ambient_activity/fight), "The cannibal attacked before the warning")
	cannibal.seen[REF(guest)] = world.time - 151 // AMBIENT_CANNIBAL_WARNING
	cannibal.watch(list(guest))
	TEST_ASSERT(cannibal.warned[REF(guest)], "No warning after lingering")
	TEST_ASSERT(!istype(cannibal.activity, /datum/ambient_activity/fight), "The warning came with a blow")
	// Half a minute in sight: attacked
	cannibal.seen[REF(guest)] = world.time - 301 // AMBIENT_CANNIBAL_PATIENCE
	cannibal.watch(list(guest))
	var/datum/ambient_activity/fight/fight = cannibal.activity
	TEST_ASSERT(istype(fight) && fight.target() == guest, "The cannibal let someone linger in sight")

	// Right up close: attacked after the invitation
	cannibal.end_activity()
	cannibal.seen.Cut()
	cannibal.invited.Cut()
	cannibal.warned.Cut()
	guest.forceMove(room_turf(1, 1))
	cannibal.watch(list(guest))
	TEST_ASSERT(!istype(cannibal.activity, /datum/ambient_activity/fight), "The cannibal skipped the invitation")
	cannibal.watch(list(guest))
	TEST_ASSERT(istype(cannibal.activity, /datum/ambient_activity/fight), "Someone walked right up to the cannibal unharmed")

	// Killed: the cleaver, and the site is spent
	cannibal.death()
	TEST_ASSERT(count_in_room(/obj/item/knife/butcher), "The cannibal dropped no cleaver")
	TEST_ASSERT_EQUAL(site.state, "spent", "The cannibal's camp is not spent once he is dead") // AMBIENT_SITE_SPENT

/// The hunters' camp: a warning first, a trade offer for the empty-handed, the whole camp on the armed; spears thrown one at a time and never at their own; a bone spear once per crew
/datum/unit_test/voidcrew_ambient_pb/tribal

/datum/unit_test/voidcrew_ambient_pb/tribal/Run()
	var/turf/center = room_turf(2, 2)
	var/datum/ambient_site_kind/planet/tribal/kind = allocate(/datum/ambient_site_kind/planet/tribal)
	var/datum/ambient_place/site/site = allocate(/datum/ambient_place/site, kind, center, null)
	site.band = 1 // ZONE_GREEN
	site.npc_total = kind.npc_count(1) // ZONE_GREEN
	TEST_ASSERT(kind.realize(site), "The hunters' camp did not come out")
	var/list/hunters = site.living_npcs()
	TEST_ASSERT_EQUAL(length(hunters), 3, "A green camp came out with [length(hunters)] hunters")
	var/obj/structure/bonfire/fire = site.get_prop(/obj/structure/bonfire)
	TEST_ASSERT_NOTNULL(fire, "The hunters' camp has no fire")
	TEST_ASSERT(count_in_room(/obj/effect/ambient_camp_prop/mat) >= 3, "Not every hunter has a sleeping mat")
	for(var/mob/living/basic/ambient_npc/planet/tribal/hunter as anything in hunters)
		TEST_ASSERT(hunter.has_spear, "A hunter came out without a spear")
		TEST_ASSERT_NOTNULL(hunter.leash_bounds, "A hunter is not leashed to the camp")
	var/mob/living/basic/ambient_npc/planet/tribal/first = hunters[1]
	var/mob/living/basic/ambient_npc/planet/tribal/lookout = first.camp_lookout()
	TEST_ASSERT_NOTNULL(lookout, "Nobody keeps watch")

	// Across the ring: a warning, nothing more
	var/mob/living/carbon/human/consistent/visitor = allocate(/mob/living/carbon/human/consistent, room_turf(4, 4))
	lookout.watch(list(visitor))
	for(var/mob/living/basic/ambient_npc/planet/tribal/hunter as anything in hunters)
		TEST_ASSERT(!istype(hunter.activity, /datum/ambient_activity/fight), "A hunter attacked without a warning")
	// Empty-handed: someone comes over to trade
	lookout.watch(list(visitor))
	var/offered = FALSE
	for(var/mob/living/basic/ambient_npc/planet/tribal/hunter as anything in hunters)
		if(istype(hunter.activity, /datum/ambient_activity/tribal_offer))
			offered = TRUE
		TEST_ASSERT(!istype(hunter.activity, /datum/ambient_activity/fight), "A hunter attacked an empty-handed visitor")
	TEST_ASSERT(offered, "Nobody came over to trade with an empty-handed visitor")

	// Armed and staying: the whole camp
	var/obj/item/spear/bamboospear/spear_in_hand = allocate(/obj/item/spear/bamboospear)
	visitor.put_in_hands(spear_in_hand)
	TEST_ASSERT(ambient_holds_weapon(visitor), "A spear in hand is not a weapon")
	var/list/visit = ambient_site_visit(site)
	var/list/entered = visit["entered"]
	entered[REF(visitor)] = world.time - 101 // AMBIENT_TRIBAL_ARMED_GRACE
	lookout.watch(list(visitor))
	for(var/mob/living/basic/ambient_npc/planet/tribal/hunter as anything in hunters)
		var/datum/ambient_activity/fight/fight = hunter.activity
		TEST_ASSERT(istype(fight) && fight.target() == visitor, "A hunter stayed out of the camp's fight")
		hunter.end_activity()

	// Armed by the fire: at once
	entered[REF(visitor)] = world.time
	visitor.forceMove(room_turf(3, 3))
	lookout.watch(list(visitor))
	TEST_ASSERT(istype(lookout.activity, /datum/ambient_activity/fight), "Someone armed stood by the fire unharmed")
	for(var/mob/living/basic/ambient_npc/planet/tribal/hunter as anything in hunters)
		hunter.end_activity()

	// A thrown spear: a wind-up first, one throw at a time for the camp, never at their own
	var/mob/living/basic/ambient_npc/planet/tribal/thrower = first
	var/mob/living/basic/ambient_npc/planet/tribal/mate = hunters[2]
	thrower.forceMove(room_turf(0, 0))
	visitor.forceMove(room_turf(4, 4))
	visit["next_throw"] = 0
	TEST_ASSERT(thrower.try_ranged(visitor), "No throw at four tiles")
	TEST_ASSERT(thrower.has_spear, "A spear flew without a wind-up")
	TEST_ASSERT(!mate.try_ranged(visitor), "Two hunters wound up a throw at once")
	thrower.throw_windup_until = world.time
	thrower.try_ranged(visitor)
	TEST_ASSERT(!thrower.has_spear, "The spear was never thrown")
	TEST_ASSERT_EQUAL(thrower.throw_reach(), 0, "A hunter throws a spear they no longer have")
	var/obj/projectile/ambient_spear/test_spear = allocate(/obj/projectile/ambient_spear, room_turf(1, 1))
	test_spear.firer = thrower
	TEST_ASSERT(!test_spear.can_hit_target(mate, FALSE, TRUE), "A thrown spear can hit the thrower's own camp")
	thrower.rearm()
	TEST_ASSERT(thrower.has_spear, "A hunter could not take up a spear again")

	// A hide for a bone spear, once per crew
	visitor.drop_all_held_items()
	var/obj/item/stack/sheet/animalhide/goliath_hide/hide = allocate(/obj/item/stack/sheet/animalhide/goliath_hide)
	visitor.put_in_hands(hide)
	TEST_ASSERT_EQUAL(mate.item_interaction(visitor, hide, list()), 1, "A hunter would not trade for a hide") // ITEM_INTERACT_SUCCESS
	TEST_ASSERT_EQUAL(pb_test_count_held(visitor, /obj/item/spear/bonespear), 1, "The trade paid no bone spear")
	var/obj/item/stack/sheet/animalhide/goliath_hide/second_hide = allocate(/obj/item/stack/sheet/animalhide/goliath_hide)
	visitor.drop_all_held_items()
	visitor.put_in_hands(second_hide)
	mate.item_interaction(visitor, second_hide, list())
	TEST_ASSERT(!QDELETED(second_hide) && second_hide.amount == 1, "A crew traded for a second bone spear")

	// All killed: a spear each, and the camp is spent
	for(var/mob/living/basic/ambient_npc/planet/tribal/hunter as anything in site.living_npcs())
		hunter.forceMove(room_turf(0, 4))
		hunter.death()
	TEST_ASSERT(count_in_room(/obj/item/spear/bamboospear) >= 3, "Dead hunters dropped no spears")
	TEST_ASSERT_EQUAL(site.state, "spent", "A camp whose hunters were all killed is not spent") // AMBIENT_SITE_SPENT

// =========================================================================
// THE FISHERS
// =========================================================================

/// The boat fisher sits in their boat and nobody can pull them out; the lava fisher fishes the lava from their chair; each gives a crew one fish, once
/datum/unit_test/voidcrew_ambient_pb/fishers

/datum/unit_test/voidcrew_ambient_pb/fishers/Run()
	var/mob/living/carbon/human/consistent/visitor = allocate(/mob/living/carbon/human/consistent, room_turf(1, 1))

	// The boat
	var/turf/sea = change_room_turf(2, 2, /turf/open/water/beach)
	var/datum/ambient_site_kind/planet/boat_fisher/boat_kind = allocate(/datum/ambient_site_kind/planet/boat_fisher)
	var/datum/ambient_place/site/boat_site = allocate(/datum/ambient_place/site, boat_kind, sea, null)
	TEST_ASSERT(boat_kind.realize(boat_site), "The fishing boat did not come out")
	var/obj/structure/ambient_boat/boat = boat_site.get_prop(/obj/structure/ambient_boat)
	TEST_ASSERT_NOTNULL(boat, "There is no boat")
	TEST_ASSERT_EQUAL(get_turf(boat), sea, "The boat is not on the water")
	var/mob/living/basic/ambient_npc/planet/boat_fisher/fisher = locate() in boat_site.living_npcs()
	TEST_ASSERT_NOTNULL(fisher, "Nobody is in the boat")
	TEST_ASSERT_EQUAL(fisher.buckled, boat, "The fisher is not sitting in the boat")
	boat.user_unbuckle_mob(fisher, visitor)
	TEST_ASSERT_EQUAL(fisher.buckled, boat, "A player pulled the fisher out of the boat")
	fisher.talked_to(visitor)
	var/fish_given = count_in_room(/obj/item/food/fishmeat) + pb_test_count_held(visitor, /obj/item/food/fishmeat)
	TEST_ASSERT_EQUAL(fish_given, 1, "The boat fisher gave [fish_given] fish, not one")
	fisher.talk_cooldowns = null
	fisher.talked_to(visitor)
	fish_given = count_in_room(/obj/item/food/fishmeat) + pb_test_count_held(visitor, /obj/item/food/fishmeat)
	TEST_ASSERT_EQUAL(fish_given, 1, "The boat fisher gave the same crew a second fish")
	for(var/turf/tile as anything in block(run_loc_floor_bottom_left, run_loc_floor_top_right))
		for(var/obj/item/food/fishmeat/fish in tile)
			qdel(fish)

	// The lava bank
	var/turf/lava = change_room_turf(4, 2, /turf/open/lava/smooth)
	var/turf/bank = room_turf(3, 2)
	TEST_ASSERT_EQUAL(ambient_lava_beside(bank), lava, "The bank has no lava beside it")
	var/datum/ambient_site_kind/planet/lava_fisher/lava_kind = allocate(/datum/ambient_site_kind/planet/lava_fisher)
	var/datum/ambient_place/site/bank_site = allocate(/datum/ambient_place/site, lava_kind, bank, null)
	TEST_ASSERT(lava_kind.realize(bank_site), "The lava fisher's camp did not come out")
	var/obj/structure/chair/plastic/chair = bank_site.get_prop(/obj/structure/chair/plastic)
	TEST_ASSERT_NOTNULL(chair, "The lava fisher has no chair")
	TEST_ASSERT_EQUAL(get_turf(chair), bank, "The chair is not on the bank")
	TEST_ASSERT_EQUAL(chair.dir, EAST, "The chair does not face the lava")
	var/mob/living/basic/ambient_npc/planet/lava_fisher/lava_man = locate() in bank_site.living_npcs()
	TEST_ASSERT_NOTNULL(lava_man, "The lava fisher did not come out")
	var/datum/ambient_activity/fish/lava/lava_fishing = new(lava_man)
	TEST_ASSERT_EQUAL(lava_fishing.water(), lava, "The lava fisher does not fish the lava by their chair")
	TEST_ASSERT(lava_man.start_activity(lava_fishing), "The lava fisher could not start fishing")
	if(lava_fishing.spot)
		lava_man.forceMove(lava_fishing.spot)
	lava_man.activity_step(1)
	TEST_ASSERT_EQUAL(lava_man.buckled, chair, "The lava fisher did not sit down to fish")
	var/items_before = count_in_room(/obj/item)
	lava_fishing.reel_in(TRUE)
	TEST_ASSERT_EQUAL(count_in_room(/obj/item), items_before, "A lava catch became an item")
	lava_man.end_activity()
	TEST_ASSERT_NULL(lava_man.buckled, "The lava fisher stayed in the chair after fishing")

	// A fillet in hand, once per crew
	visitor.drop_all_held_items()
	lava_man.talked_to(visitor)
	TEST_ASSERT_EQUAL(pb_test_count_held(visitor, /obj/item/food/fishmeat), 1, "The lava fisher gave no fillet")
	lava_man.talk_cooldowns = null
	lava_man.talked_to(visitor)
	TEST_ASSERT_EQUAL(pb_test_count_held(visitor, /obj/item/food/fishmeat) + count_in_room(/obj/item/food/fishmeat), 1, "The lava fisher gave the same crew a second fillet")

// =========================================================================
// THE PEDDLER
// =========================================================================

/// The caravan: a peddler, a pony and a guard, all killable; a credits-only shop that buys for less than an outpost; a dead pony closes the shop and stays dead; a camp that is packed up, and a walk off the planet that spends the site; a killed peddler drops a trader's cash once, and the shop dies with them
/datum/unit_test/voidcrew_ambient_pb/peddler

/datum/unit_test/voidcrew_ambient_pb/peddler/Run()
	var/datum/ambient_site_kind/planet/peddler/kind = allocate(/datum/ambient_site_kind/planet/peddler)
	var/datum/ambient_place/site/site = allocate(/datum/ambient_place/site, kind, room_turf(2, 2), null)
	site.band = 2 // ZONE_YELLOW
	site.npc_total = kind.npc_count(2) // ZONE_YELLOW
	TEST_ASSERT(kind.realize(site), "The caravan did not come out")
	TEST_ASSERT_EQUAL(length(site.living_npcs()), 3, "A yellow caravan came out with [length(site.living_npcs())] people")
	var/mob/living/basic/ambient_npc/planet/peddler/peddler = locate() in site.living_npcs()
	var/mob/living/basic/ambient_npc/planet/pack_pony/pony = locate() in site.living_npcs()
	var/mob/living/basic/ambient_npc/planet/caravan_guard/guard = locate() in site.living_npcs()
	TEST_ASSERT_NOTNULL(peddler, "The caravan has no peddler")
	TEST_ASSERT_NOTNULL(pony, "The caravan has no pony")
	TEST_ASSERT_NOTNULL(guard, "A yellow caravan has no guard")
	TEST_ASSERT(!HAS_TRAIT(peddler, TRAIT_GODMODE), "The peddler cannot be hurt")
	TEST_ASSERT(!HAS_TRAIT(pony, TRAIT_GODMODE), "The pony cannot be hurt")

	// Credits only, and less than an outpost pays
	TEST_ASSERT_NOTNULL(peddler.shop, "The peddler has no shop")
	TEST_ASSERT(length(peddler.shop.skus), "The peddler sells nothing")
	for(var/datum/shop_sku/sku as anything in peddler.shop.skus)
		TEST_ASSERT(!sku.price_vouchers, "The peddler sells [sku.name] for vouchers")
		TEST_ASSERT(sku.price_credits > 0, "The peddler gives [sku.name] away")
		TEST_ASSERT(sku.category in peddler.shop.categories, "[sku.name] is in a category the shop does not list")
	for(var/datum/shop_buyback/buyback as anything in peddler.shop.buybacks)
		var/datum/shop_buyback/outpost_entry = new buyback.type
		TEST_ASSERT(!buyback.pay_vouchers, "The peddler pays vouchers for [buyback.name]")
		TEST_ASSERT(buyback.pay_credits > 0 && buyback.pay_credits < outpost_entry.pay_credits, "The peddler pays [buyback.pay_credits] for [buyback.name]; an outpost pays [outpost_entry.pay_credits]")
		qdel(outpost_entry)
	// Sold out of one good: it stays sold out when the caravan comes back next visit
	TEST_ASSERT(length(peddler.shop.buybacks), "The peddler buys nothing")
	var/datum/shop_buyback/sold_out = peddler.shop.buybacks[1]
	var/sold_out_type = sold_out.type
	sold_out.demand = 0
	// The trader's own shop window, hosted by the peddler
	var/mob/living/carbon/human/consistent/customer = allocate(/mob/living/carbon/human/consistent, room_turf(1, 2))
	TEST_ASSERT_EQUAL(peddler.shop_ui.ui_host(customer), peddler, "The shop window is not hosted by the peddler")
	var/list/static_data = peddler.shop_ui.ui_static_data(customer)
	TEST_ASSERT(length(static_data["catalog"]), "The shop window shows no stock")
	var/list/live_data = peddler.shop_ui.ui_data(customer)
	TEST_ASSERT(!live_data["barred"], "A customer is barred from the peddler")

	// The pony dies: the shop closes; the next visit, the pony stays dead and the shop shut
	pony.death()
	TEST_ASSERT(peddler.shop_closed, "The shop stayed open with the pony dead")
	for(var/mob/living/basic/ambient_npc/member as anything in site.npcs.Copy())
		qdel(member)
	TEST_ASSERT(kind.realize(site), "The caravan did not come back for the next visit")
	TEST_ASSERT_EQUAL(length(site.living_npcs()), 2, "[length(site.living_npcs())] came back, not the peddler and the guard")
	TEST_ASSERT_NULL(locate(/mob/living/basic/ambient_npc/planet/pack_pony) in site.living_npcs(), "A killed pony came back")
	peddler = locate() in site.living_npcs()
	TEST_ASSERT(peddler?.shop_closed, "The shop opened again with no pony")
	for(var/datum/shop_buyback/buyback as anything in peddler.shop.buybacks)
		if(buyback.type == sold_out_type)
			TEST_ASSERT_EQUAL(buyback.demand, 0, "A new visit made a fresh market for [buyback.name]")

	// The road: a camp, packed up after; then off the planet, and the site is spent
	peddler.pick_activity()
	TEST_ASSERT(istype(peddler.activity, /datum/ambient_activity/caravan_camp), "The peddler did not make camp at the camp stop")
	peddler.activity_step(1)
	TEST_ASSERT_EQUAL(count_in_room(/obj/effect/ambient_camp_prop/rug), 1, "No rug was spread at the camp")
	peddler.end_activity()
	TEST_ASSERT_EQUAL(count_in_room(/obj/effect/ambient_camp_prop/rug), 0, "The camp was not packed up")
	peddler.pick_activity()
	TEST_ASSERT_EQUAL(site.state, "spent", "The caravan left and the site was not spent") // AMBIENT_SITE_SPENT
	TEST_ASSERT(peddler.fading, "The peddler did not walk off")
	TEST_ASSERT(!kind.realize(site), "A caravan that walked off came back")

	// A killed peddler: a trader's cash, once, and the shop goes with them
	var/turf/body_turf = room_turf(1, 1)
	var/mob/living/basic/ambient_npc/planet/peddler/victim = allocate(/mob/living/basic/ambient_npc/planet/peddler, body_turf)
	victim.apply_damage(victim.maxHealth * 2, BRUTE)
	TEST_ASSERT_EQUAL(victim.stat, DEAD, "The peddler did not die of their wounds")
	TEST_ASSERT(victim.shop_closed, "The shop stayed open with the peddler dead")
	var/cash = ambient_test_cash_on(body_turf)
	TEST_ASSERT(cash >= 30 && cash <= 80, "A killed peddler dropped [cash] cr, not a trader's 30 to 80")
	victim.revive(ADMIN_HEAL_ALL)
	victim.death()
	TEST_ASSERT_EQUAL(ambient_test_cash_on(body_turf), cash, "A revived peddler dropped cash again")
