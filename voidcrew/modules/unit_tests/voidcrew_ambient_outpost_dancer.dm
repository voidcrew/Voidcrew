/**
 * World population: tests for outpost_dancer.dm in voidcrew/modules/ambient_npcs/.
 *
 * The pole stands on a platform, as at the Undertow. The dancer settles right on the pole's own
 * tile, mid-dance, raised by the platform with her place against the pole on top; her dance keeps
 * her there and her moves end where they began; knocked off she lets go at once and climbs back;
 * someone else on the pole keeps her off it; and ending the dance (a break, a shootout, death) steps
 * her back down beside it with her offsets reset. A shootout sends her running for cover, any other
 * fight sends her into hiding clear of it, and either way she goes back to her pole once it is over.
 * She is killable like any other ambient outpost NPC. She wears a bikini, no uniform.
 * SSambient_npcs does nothing on its own in tests (`ambient_auto`); see voidcrew_ambient_core.dm for
 * the harness (ambient_test_outpost(), pa_tile()) and voidcrew_ambient_outposts.dm for the same
 * pattern used on PA's other outpost NPCs.
 */

/// A pole on a platform at `where`, as the Undertow's. Returns the pole.
/datum/unit_test/proc/dancer_test_pole(turf/where)
	var/obj/structure/festivus/anchored/pole = allocate(/obj/structure/festivus/anchored, where)
	allocate(/obj/structure/platform, where)
	return pole

/// The dancer settles right on the pole, raised by its platform, and stays there while she dances; knocked off she lets go and climbs back; ending the dance steps her off it
/datum/unit_test/voidcrew_ambient_outpost_dancer_settle

/datum/unit_test/voidcrew_ambient_outpost_dancer_settle/Run()
	var/obj/structure/overmap/trader_outpost/outpost = ambient_test_outpost()
	var/obj/structure/festivus/anchored/pole = dancer_test_pole(pa_tile(2, 2))
	var/turf/pole_turf = get_turf(pole)
	var/datum/ambient_place/outpost/place = pa_place(outpost)
	var/mob/living/basic/ambient_npc/outpost/dancer/dancer = pa_npc(/mob/living/basic/ambient_npc/outpost/dancer, pa_tile(0, 0), place)
	var/base_w = dancer.base_pixel_w
	var/base_z = dancer.base_pixel_z

	TEST_ASSERT_EQUAL(dancer.gender, FEMALE, "The dancer is not a woman")
	TEST_ASSERT(dancer.settle_in(), "The dancer could not be found already at the pole")
	var/datum/ambient_activity/dance_pole/dance = dancer.activity
	TEST_ASSERT(istype(dance), "The dancer found at the outpost is [dancer.activity?.name || "doing nothing"], not dancing")
	TEST_ASSERT_EQUAL(get_turf(dancer), pole_turf, "The dancer was not found right on the pole")
	TEST_ASSERT(dance.on_pole, "The dancer settled at the pole without taking hold of it")
	TEST_ASSERT(HAS_TRAIT(dancer, TRAIT_AI_PAUSED), "The dancer at an empty outpost is not holding still")
	check_on_pole(dancer, dance, base_w, base_z, "settled")

	// The dance keeps her right there, never behind the pole, and her place against it follows her side of it
	for(var/step in 1 to 30)
		dance.next_move = world.time
		dancer.activity_step(1)
		TEST_ASSERT_EQUAL(get_turf(dancer), pole_turf, "A dance step moved the dancer off the pole")
		TEST_ASSERT(dance.side in list(WEST, SOUTH, EAST), "The dancer went round behind the pole, where she hides it")
		check_on_pole(dancer, dance, base_w, base_z, "after a dance step", sway_ok = TRUE)
	// Hops, spins and leans end where they started: she never drifts up off the floor, or stays tilted
	var/matrix/rest = matrix(dancer.transform)
	for(var/step in 1 to 40)
		dance.dance_step()
	var/matrix/after = matrix(dancer.transform)
	TEST_ASSERT(after.a == rest.a && after.b == rest.b && after.c == rest.c && after.d == rest.d && after.e == rest.e && after.f == rest.f, "The dance left the dancer's transform off where it started ([after.f - rest.f] pixels higher)")

	// Knocked off it (a shove): she lets go at once, then climbs back up once she is beside it
	var/turf/beside = pa_tile(1, 2)
	dancer.forceMove(beside)
	TEST_ASSERT(!dance.on_pole, "The dancer knocked off the pole still thinks she is on it")
	TEST_ASSERT(dancer.pixel_w == base_w && dancer.pixel_z == base_z, "The dancer knocked off the pole kept her place against it in the air")
	dance.climb_at = world.time
	dancer.activity_step(1)
	TEST_ASSERT_EQUAL(get_turf(dancer), pole_turf, "The dancer did not climb back onto the pole")
	check_on_pole(dancer, dance, base_w, base_z, "climbed back", sway_ok = TRUE)
	// A mob swap that fails half way puts her back up: she takes hold again straight away
	dancer.forceMove(beside)
	dancer.forceMove(pole_turf)
	TEST_ASSERT(dance.on_pole, "The dancer put back on the pole did not take hold of it")
	check_on_pole(dancer, dance, base_w, base_z, "put back")

	// Ending the dance steps her back down, beside the pole, with her offsets reset
	dancer.end_activity()
	TEST_ASSERT(get_turf(dancer) != pole_turf, "The dancer stayed on the pole once her dance ended")
	TEST_ASSERT_EQUAL(get_dist(dancer, pole), 1, "The dancer did not step down to a tile beside the pole")
	TEST_ASSERT(dancer.pixel_w == base_w && dancer.pixel_z == base_z, "The dancer kept her pole offsets after stepping off it")
	TEST_ASSERT(!HAS_TRAIT(dancer, TRAIT_MOB_ELEVATED), "The dancer stepped off the platform still raised by it")

	// Someone else up on the pole: she does not start a dance there, and gives one up that is waiting to climb
	var/mob/living/carbon/human/consistent/climber = allocate(/mob/living/carbon/human/consistent, pole_turf)
	TEST_ASSERT(!dancer.start_activity(new /datum/ambient_activity/dance_pole(dancer)), "The dancer started a dance on a pole someone else is standing on")
	climber.forceMove(pa_tile(4, 0))
	dance = dancer.start_activity(new /datum/ambient_activity/dance_pole(dancer))
	TEST_ASSERT_NOTNULL(dance, "The dancer would not dance on a free pole")
	dancer.activity_step(1)
	climber.forceMove(pole_turf)
	for(var/attempt in 1 to 10)
		if(dancer.activity != dance)
			break
		dance.climb_at = world.time
		if(dancer.activity_step(1) == 2) // AMBIENT_STEP_DONE
			dancer.end_activity()
	TEST_ASSERT(dancer.activity != dance, "The dancer waited on forever for someone else to get off the pole")
	TEST_ASSERT(get_turf(dancer) != pole_turf, "The dancer climbed onto a pole someone else is standing on")

	// No pole in reach: she does not pretend to dance
	var/obj/structure/overmap/trader_outpost/empty_outpost = allocate(/obj/structure/overmap/trader_outpost)
	var/datum/ambient_place/outpost/empty_place = pa_place(empty_outpost)
	var/mob/living/basic/ambient_npc/outpost/dancer/stray = pa_npc(/mob/living/basic/ambient_npc/outpost/dancer, pa_tile(4, 4), empty_place)
	TEST_ASSERT(!stray.start_activity(new /datum/ambient_activity/dance_pole(stray)), "The dancer found a pole that is not there")

/// The dancer is up on the pole, raised by its platform, with her place against it on top (a sway of a pixel or two along it if `sway_ok`)
/datum/unit_test/voidcrew_ambient_outpost_dancer_settle/proc/check_on_pole(mob/living/basic/ambient_npc/outpost/dancer/dancer, datum/ambient_activity/dance_pole/dance, base_w, base_z, when, sway_ok = FALSE)
	var/list/against = dance.side_offset(dance.side)
	TEST_ASSERT(HAS_TRAIT(dancer, TRAIT_MOB_ELEVATED), "The dancer [when] on the pole is not raised by its platform")
	var/w_off = dancer.pixel_w - base_w - against[1]
	TEST_ASSERT(w_off == 0 || (sway_ok && abs(w_off) <= 2), "The dancer [when] on the pole is [w_off] pixels off her place against it")
	var/raised = dancer.pixel_z - base_z - against[2]
	TEST_ASSERT(raised > 0, "The dancer [when] on the pole lost the platform's lift ([raised]): her offsets overwrote it")

/// The kingpin's shootout sends her off the pole for cover and she comes back once it is calm; a fight by his seat sends her out by the lift
/datum/unit_test/voidcrew_ambient_outpost_dancer_shootout

/datum/unit_test/voidcrew_ambient_outpost_dancer_shootout/Run()
	var/obj/structure/overmap/trader_outpost/outpost = ambient_test_outpost()
	var/obj/structure/festivus/anchored/pole = dancer_test_pole(pa_tile(2, 2))
	var/datum/ambient_place/outpost/place = pa_place(outpost)
	var/mob/living/basic/ambient_npc/outpost/dancer/dancer = pa_npc(/mob/living/basic/ambient_npc/outpost/dancer, pa_tile(2, 3), place)
	var/base_w = dancer.base_pixel_w
	var/base_z = dancer.base_pixel_z
	var/datum/ambient_activity/dance_pole/dance = dancer.start_activity(new /datum/ambient_activity/dance_pole(dancer))
	TEST_ASSERT_NOTNULL(dance, "The dancer found no pole to dance at")
	dancer.activity_step(1)
	dance.climb_at = world.time
	dancer.activity_step(1)
	TEST_ASSERT(dance.on_pole, "The dancer did not climb onto the pole")
	TEST_ASSERT_EQUAL(get_turf(dancer), get_turf(pole), "The dancer climbed on without getting onto the pole's tile")

	var/turf/refuge = pa_tile(4, 0)
	dancer.react_shootout(refuge)
	var/datum/ambient_activity/take_cover/cover = dancer.activity
	TEST_ASSERT(istype(cover), "A shootout did not send the dancer running for cover")
	TEST_ASSERT(get_dist(cover.spot, pole) > 1, "A shootout sent the dancer for cover without leaving the pole")
	TEST_ASSERT(get_turf(dancer) != get_turf(pole), "The shootout left the dancer standing on the pole")
	TEST_ASSERT(dancer.pixel_w == base_w && dancer.pixel_z == base_z, "The shootout left the dancer's pole offsets on her")
	dancer.forceMove(refuge)
	dancer.activity_step(1)
	TEST_ASSERT(dancer.crouching, "The dancer taking cover from a shootout is not down")

	// It's over: straight back up on her pole
	dancer.shootout_over()
	TEST_ASSERT(!istype(dancer.activity, /datum/ambient_activity/take_cover), "The dancer stayed in cover once the shootout was over")
	dancer.next_activity()
	TEST_ASSERT(istype(dancer.activity, /datum/ambient_activity/dance_pole), "The dancer did not go back to her pole after the shootout")
	// Out of the way of the next dancer
	dancer.end_activity()
	dancer.forceMove(pa_tile(4, 1))

	// A fight right by the kingpin's seat, no shootout: she gets clear of it and stays at the outpost
	allocate(/obj/effect/landmark/bounty_kingpin/seat, pa_tile(0, 0))
	var/mob/living/carbon/human/consistent/brawler = allocate(/mob/living/carbon/human/consistent, pa_tile(2, 1))
	var/mob/living/basic/ambient_npc/outpost/dancer/second = pa_npc(/mob/living/basic/ambient_npc/outpost/dancer, pa_tile(1, 1), place)
	second.react_violence(brawler)
	var/datum/ambient_activity/dancer_hide/hiding = second.activity
	TEST_ASSERT(istype(hiding), "A fight by the kingpin's seat did not send the dancer into hiding")
	TEST_ASSERT(!hiding.spot || get_dist(hiding.spot, brawler) > get_dist(pa_tile(1, 1), brawler), "The dancer hid closer to the fight than she was")
	if(hiding.spot)
		second.forceMove(hiding.spot)
	second.activity_step(1)
	TEST_ASSERT(second.crouching, "The hiding dancer is not keeping her head down")

	// More fighting keeps her down; once it has been quiet a while she goes back to her pole
	hiding.calm_at = world.time - 1
	second.react_violence(brawler)
	TEST_ASSERT(hiding.calm_at > world.time, "More fighting did not keep the dancer hidden")
	TEST_ASSERT_EQUAL(second.activity_step(1), 0, "The dancer came out while it was still going on") // AMBIENT_STEP_CONTINUE
	hiding.calm_at = world.time
	TEST_ASSERT_EQUAL(second.activity_step(1), 2, "The dancer stayed hidden once it was quiet") // AMBIENT_STEP_DONE
	second.end_activity()
	second.next_activity()
	TEST_ASSERT(istype(second.activity, /datum/ambient_activity/dance_pole), "The dancer did not go back to her pole once it was quiet")
	second.end_activity()
	second.forceMove(pa_tile(4, 2))

	// Hit herself, well clear of the kingpin: she hides too, and never leaves
	var/mob/living/basic/ambient_npc/outpost/dancer/third = pa_npc(/mob/living/basic/ambient_npc/outpost/dancer, pa_tile(3, 4), place)
	var/mob/living/carbon/human/consistent/other_brawler = allocate(/mob/living/carbon/human/consistent, pa_tile(4, 4))
	third.react_attacked(other_brawler)
	TEST_ASSERT(istype(third.activity, /datum/ambient_activity/dancer_hide), "A hit did not send the dancer into hiding")

/// The dancer is killable like any other ambient outpost NPC and drops a little cash once; killed on the pole she falls off it; she wears a bikini
/datum/unit_test/voidcrew_ambient_outpost_dancer_death

/datum/unit_test/voidcrew_ambient_outpost_dancer_death/Run()
	var/obj/structure/overmap/trader_outpost/outpost = ambient_test_outpost()
	var/datum/ambient_place/outpost/place = pa_place(outpost)
	var/turf/spot = pa_tile(1, 1)
	var/cash_before = ambient_test_cash_on(spot)
	var/mob/living/basic/ambient_npc/outpost/dancer/dancer = pa_npc(/mob/living/basic/ambient_npc/outpost/dancer, spot, place)
	TEST_ASSERT(!HAS_TRAIT(dancer, TRAIT_GODMODE), "The dancer cannot be hurt")

	dancer.apply_damage(dancer.maxHealth * 2, BRUTE)
	TEST_ASSERT_EQUAL(dancer.stat, DEAD, "The dancer did not die of her wounds")
	var/dropped = ambient_test_cash_on(spot) - cash_before
	TEST_ASSERT(dropped >= 5 && dropped <= 30, "The dancer dropped [dropped] cr, not 5 to 30") // AMBIENT_DEATH_CASH_LOW/HIGH

	dancer.revive(ADMIN_HEAL_ALL)
	dancer.death()
	TEST_ASSERT_EQUAL(ambient_test_cash_on(spot) - cash_before, dropped, "The dancer dropped cash again after a revive")

	// Killed up on the pole: her body falls off it, beside the pole, with her offsets gone
	var/obj/structure/festivus/anchored/pole = dancer_test_pole(pa_tile(2, 3))
	var/mob/living/basic/ambient_npc/outpost/dancer/performer = pa_npc(/mob/living/basic/ambient_npc/outpost/dancer, pa_tile(2, 2), place)
	var/base_w = performer.base_pixel_w
	var/base_z = performer.base_pixel_z
	var/datum/ambient_activity/dance_pole/dance = performer.start_activity(new /datum/ambient_activity/dance_pole(performer))
	TEST_ASSERT_NOTNULL(dance, "The dancer found no pole to dance at")
	performer.activity_step(1)
	dance.climb_at = world.time
	performer.activity_step(1)
	TEST_ASSERT(dance.on_pole, "The dancer did not climb onto the pole")
	performer.apply_damage(performer.maxHealth * 2, BRUTE)
	TEST_ASSERT_EQUAL(performer.stat, DEAD, "The dancer on the pole did not die of her wounds")
	TEST_ASSERT(get_turf(performer) != get_turf(pole), "The dancer's body stayed up on the pole")
	TEST_ASSERT_EQUAL(get_dist(performer, pole), 1, "The dancer's body did not fall beside the pole")
	TEST_ASSERT(performer.pixel_w == base_w && performer.pixel_z == base_z, "The dancer's body kept her pole offsets")
	TEST_ASSERT(isnull(performer.activity), "The dancer's body is still [performer.activity?.name]")

	// She dances in a bikini, no uniform: underwear on the body her look is built on
	for(var/outfit_type in list(/datum/outfit/ambient_dancer))
		var/mob/living/carbon/human/consistent/model = allocate(/mob/living/carbon/human/consistent, pa_tile(0, 4))
		model.physique = FEMALE
		model.equipOutfit(outfit_type, visuals_only = TRUE)
		var/datum/sprite_accessory/underwear/bikini = SSaccessories.underwear_list[model.underwear]
		TEST_ASSERT(istype(bikini) && bikini.icon_state, "[outfit_type] leaves the dancer without a bikini (underwear [model.underwear])")
		TEST_ASSERT_NULL(model.w_uniform, "[outfit_type] puts the dancer in a uniform over her bikini")
