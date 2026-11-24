// Stealth guards: cover (voidcrew/modules/stealth/stealth_cover.dm). Unit tests compile before voidcrew/_DEFINES, so
// values from there are written out: STEALTH_COVER_RANGE 3, STEALTH_COVER_SETTLE 1 s, STEALTH_SUSPICIOUS_AT 1.0,
// notice entry fields (notice, turf, seen at) 1-3, rustle reach 2 walking and 1 crawling, noise kind "rustle".
// The helpers (stealth_block() and friends) are in voidcrew_stealth.dm; the hearing room in voidcrew_stealth_hearing.dm.

/// What counts as cover: jungle bushes do, flowers don't; a potted plant only on the tile the map put it on, and never
/// a dead one.
/datum/unit_test/voidcrew_stealth_cover_types

/datum/unit_test/voidcrew_stealth_cover_types/Run()
	var/datum/turf_reservation/block = stealth_block(6, 1)
	TEST_ASSERT_NOTNULL(block, "No room for the test")
	var/turf/bush_tile = stealth_at(block, 0, 0)
	var/turf/flower_tile = stealth_at(block, 1, 0)
	var/turf/plant_tile = stealth_at(block, 2, 0)
	var/turf/dead_tile = stealth_at(block, 3, 0)
	var/obj/structure/flora/bush/jungle/bush = allocate(/obj/structure/flora/bush/jungle, bush_tile)
	allocate(/obj/structure/flora/bush/flowers_yw, flower_tile)
	TEST_ASSERT_EQUAL(stealth_cover_at(bush_tile), bush, "A jungle bush isn't cover")
	TEST_ASSERT_NULL(stealth_cover_at(flower_tile), "Flowers are cover")
	TEST_ASSERT_NULL(stealth_cover_at(stealth_at(block, 5, 0)), "Bare floor is cover")
	// Made at runtime, as a bought or printed one is: no cover.
	var/obj/item/kirbyplants/plant = allocate(/obj/item/kirbyplants, plant_tile)
	TEST_ASSERT_NULL(stealth_cover_at(plant_tile), "A potted plant made after the map loaded is cover")
	// Where the map put it: cover. Dragged off it: not, and not where it was either.
	plant.stealth_cover_spot = plant_tile
	TEST_ASSERT_EQUAL(stealth_cover_at(plant_tile), plant, "A potted plant on its mapped tile isn't cover")
	plant.forceMove(stealth_at(block, 4, 0))
	TEST_ASSERT_NULL(stealth_cover_at(stealth_at(block, 4, 0)), "A potted plant dragged off its mapped tile is cover")
	TEST_ASSERT_NULL(stealth_cover_at(plant_tile), "A tile kept cover after its potted plant was dragged off")
	var/obj/item/kirbyplants/random/dead/dead = allocate(/obj/item/kirbyplants/random/dead, dead_tile)
	dead.stealth_cover_spot = dead_tile
	TEST_ASSERT_NULL(stealth_cover_at(dead_tile), "A dead potted plant is cover")
	TEST_ASSERT_NOTNULL(stealth_noise_profile("rustle"), "The rustle has no noise profile")
	qdel(block)

/// Sight with the AI off: still in cover 6 tiles in front, never noticed; moving, crawling, at 3 tiles, at 2 tiles and in
/// its beam.
/datum/unit_test/voidcrew_stealth_cover_sight

/datum/unit_test/voidcrew_stealth_cover_sight/Run()
	var/datum/turf_reservation/block = stealth_block(12, 3)
	TEST_ASSERT_NOTNULL(block, "No room for the test")
	var/turf/far = stealth_at(block, 8, 1)
	var/turf/near = stealth_at(block, 5, 1)
	var/turf/point_blank = stealth_at(block, 4, 1)
	for(var/turf/spot as anything in list(far, near, point_blank))
		allocate(/obj/structure/flora/bush/jungle, spot)
	var/mob/living/carbon/human/person = stealth_person(block, 8, 1)
	// Still, in light, 6 tiles in front.
	var/mob/living/carbon/human/npc/guard = stealth_guard(block, 2, 1)
	var/datum/ai_controller/basic_controller/human_npc/stealth/stealth_ai = stealth_ai(guard)
	person.stealth_moved_at = world.time - 10 SECONDS
	TEST_ASSERT(stealth_in_cover(person, far), "Someone keeping still on a jungle bush isn't in cover")
	stealth_scans(guard, 10)
	TEST_ASSERT_EQUAL(stealth_ai.stealth_state(), "unaware", "A guard noticed someone keeping still in cover 6 tiles off")
	TEST_ASSERT_NULL(stealth_ai.notice_map[REF(person)], "A guard gained notice on someone keeping still in cover 6 tiles off")
	qdel(guard)
	// Moving: the cover doesn't hide them (world.time doesn't move between these scans, so they stay "just moved").
	guard = stealth_guard(block, 2, 1)
	stealth_ai = stealth_ai(guard)
	person.stealth_moved_at = world.time
	stealth_scans(guard, 10)
	TEST_ASSERT(stealth_ai.stealth_state() != "unaware", "A guard never noticed someone moving through cover 6 tiles in front in the light")
	qdel(guard)
	// Crawling counts as keeping still.
	guard = stealth_guard(block, 2, 1)
	stealth_ai = stealth_ai(guard)
	person.set_body_position(LYING_DOWN)
	stealth_scans(guard, 10)
	TEST_ASSERT_EQUAL(stealth_ai.stealth_state(), "unaware", "A guard noticed someone crawling in cover 6 tiles off")
	person.set_body_position(STANDING_UP)
	qdel(guard)
	// In its own beam: seen as on open ground.
	guard = stealth_guard(block, 2, 1)
	stealth_ai = stealth_ai(guard)
	person.stealth_moved_at = world.time - 10 SECONDS
	GLOB.stealth_test_beam_turfs[far] = TRUE
	stealth_scans(guard, 10)
	GLOB.stealth_test_beam_turfs -= far
	TEST_ASSERT(stealth_ai.stealth_state() != "unaware", "A guard never noticed someone in cover in its own beam")
	qdel(guard)
	// 3 tiles: cover stops hiding them.
	guard = stealth_guard(block, 2, 1)
	stealth_ai = stealth_ai(guard)
	person.forceMove(near)
	person.stealth_moved_at = world.time - 10 SECONDS
	TEST_ASSERT(stealth_in_cover(person, near), "Someone keeping still on the near bush isn't in cover")
	stealth_scans(guard, 5)
	TEST_ASSERT(stealth_ai.stealth_state() != "unaware", "Cover hid someone 3 tiles in front of a guard")
	qdel(guard)
	// 2 tiles in front: an alert on the first look, cover or not.
	guard = stealth_guard(block, 2, 1)
	stealth_ai = stealth_ai(guard)
	person.forceMove(point_blank)
	person.stealth_moved_at = world.time - 10 SECONDS
	stealth_scans(guard, 1)
	TEST_ASSERT_EQUAL(stealth_ai.stealth_state(), "alert", "Cover stopped a point-blank alert")
	qdel(guard)
	qdel(block)

/// Seen getting in: a guard suspicious of someone it saw a moment ago goes to look at the cover they went still in.
/// One it had barely noticed doesn't.
/datum/unit_test/voidcrew_stealth_cover_glimpsed

/datum/unit_test/voidcrew_stealth_cover_glimpsed/Run()
	var/datum/turf_reservation/block = stealth_block(12, 3)
	TEST_ASSERT_NOTNULL(block, "No room for the test")
	var/turf/hide = stealth_at(block, 8, 1)
	allocate(/obj/structure/flora/bush/jungle, hide)
	var/mob/living/carbon/human/person = stealth_person(block, 8, 1)
	person.stealth_moved_at = world.time - 10 SECONDS
	// Barely noticed on the next tile a moment ago: it loses them.
	var/mob/living/carbon/human/npc/guard = stealth_guard(block, 2, 1)
	var/datum/ai_controller/basic_controller/human_npc/stealth/stealth_ai = stealth_ai(guard)
	stealth_ai.notice_map[REF(person)] = list(0.3, stealth_at(block, 7, 1), world.time)
	stealth_scans(guard, 1)
	TEST_ASSERT_EQUAL(stealth_ai.stealth_state(), "unaware", "A guard that had barely noticed someone went to their cover")
	qdel(guard)
	// Suspicious of them, seen on the next tile a moment ago: it goes to look at the bush.
	guard = stealth_guard(block, 2, 1)
	stealth_ai = stealth_ai(guard)
	stealth_ai.stealth_go_suspicious(stealth_at(block, 6, 2))
	stealth_ai.notice_map[REF(person)] = list(1.5, stealth_at(block, 7, 1), world.time)
	stealth_scans(guard, 1)
	TEST_ASSERT_EQUAL(stealth_ai.stealth_state(), "suspicious", "A guard that saw someone get into cover stopped being suspicious")
	TEST_ASSERT_EQUAL(stealth_ai.last_seen_turf, hide, "A guard that saw someone get into cover isn't looking at it")
	TEST_ASSERT_EQUAL(stealth_ai.investigate_turf, hide, "A guard that saw someone get into cover isn't going to it")
	qdel(guard)
	// Unaware with them at suspicious notice (the look that would have made it suspicious): it goes to look.
	guard = stealth_guard(block, 2, 1)
	stealth_ai = stealth_ai(guard)
	stealth_ai.notice_map[REF(person)] = list(1.2, hide, world.time)
	stealth_scans(guard, 1)
	TEST_ASSERT_EQUAL(stealth_ai.stealth_state(), "suspicious", "An unaware guard that saw someone get into cover didn't go suspicious")
	TEST_ASSERT_EQUAL(stealth_ai.investigate_turf, hide, "An unaware guard that saw someone get into cover isn't going to it")
	qdel(guard)
	qdel(block)

/// A guard gets no cover from a bush.
/datum/unit_test/voidcrew_stealth_cover_guards

/datum/unit_test/voidcrew_stealth_cover_guards/Run()
	var/datum/turf_reservation/block = stealth_block(3, 1)
	TEST_ASSERT_NOTNULL(block, "No room for the test")
	var/turf/hide = stealth_at(block, 1, 0)
	allocate(/obj/structure/flora/bush/jungle, hide)
	var/mob/living/carbon/human/npc/guard = stealth_guard(block, 1, 0)
	guard.stealth_moved_at = world.time - 10 SECONDS
	TEST_ASSERT(!stealth_in_cover(guard, hide), "A stealth guard hides in cover")
	qdel(block)

/// The rustle: how far it carries walking, crawling and off cover, and a guard 2 tiles off hears it, one 4 off doesn't.
/datum/unit_test/voidcrew_stealth_live/hear/cover_rustle

/datum/unit_test/voidcrew_stealth_live/hear/cover_rustle/Run()
	TEST_ASSERT(hear_room(16, 3), "No room for the test")
	var/turf/hide = at(4, 1)
	allocate(/obj/structure/flora/bush/jungle, hide)
	var/mob/living/carbon/human/walker = person_at(4, 1, listed = FALSE)
	TEST_ASSERT_EQUAL(stealth_rustle_reach(walker), 2, "A walk through cover carries the wrong distance")
	walker.set_body_position(LYING_DOWN)
	TEST_ASSERT_EQUAL(stealth_rustle_reach(walker), 1, "A crawl through cover carries the wrong distance")
	walker.set_body_position(STANDING_UP)
	walker.forceMove(at(5, 1))
	TEST_ASSERT_EQUAL(stealth_rustle_reach(walker), 0, "A step off cover rustles")
	walker.forceMove(hide)
	// 4 tiles off: unheard.
	var/mob/living/carbon/human/npc/far_guard = sentry(8, 1, WEST)
	TEST_ASSERT_EQUAL(stealth_rustle(walker), 0, "A rustle was heard 4 tiles off")
	qdel(far_guard)
	// 2 tiles off: heard, and it goes to look.
	var/mob/living/carbon/human/npc/guard = sentry(2, 1, EAST)
	TEST_ASSERT_EQUAL(stealth_rustle(walker), 1, "A rustle 2 tiles off wasn't heard")
	TEST_ASSERT_EQUAL(state_of(guard), "suspicious", "A guard that heard a rustle didn't go to look")
	no_targets(list(guard))
