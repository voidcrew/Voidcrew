/**
 * World population: tests for faction_recruiters.dm
 * in voidcrew/modules/ambient_npcs/.
 *
 * Owner: PD (faction recruiters). P0 made this file as a stub; only that package edits it.
 *
 * Fork defines are included after the tests, so a test uses the literal value with a comment
 * naming the define. SSambient_npcs does nothing on its own in tests (`ambient_auto`); the core's
 * tests (voidcrew_ambient_core.dm) show how to drive outposts, sites and activities by hand, and
 * give every test ambient_test_outpost() and ambient_test_room_bounds().
 */

/// A Quartermain-shaped test outpost: both recruiter roles apply there
/datum/unit_test/proc/ambient_test_outpost_quartermain()
	var/obj/structure/overmap/trader_outpost/outfitter/outpost = allocate(/obj/structure/overmap/trader_outpost/outfitter)
	outpost.outpost_template = allocate(/datum/map_template/trader_outpost)
	outpost.outpost_template.width = run_loc_floor_top_right.x - run_loc_floor_bottom_left.x + 1
	outpost.outpost_template.height = run_loc_floor_top_right.y - run_loc_floor_bottom_left.y + 1
	outpost.template_bottom_left = run_loc_floor_bottom_left
	outpost.lobby_alcove_turfs = list(run_loc_floor_top_right)
	return outpost

/// Which outpost each side comes to: Nanotrasen at Halcyon and Quartermain, the Syndicate at Quartermain and the Undertow, neither at the other's exclusive outpost
/datum/unit_test/voidcrew_ambient_recruiters_outpost_types

/datum/unit_test/voidcrew_ambient_recruiters_outpost_types/Run()
	var/datum/ambient_outpost_role/recruiter/nanotrasen/nt_role = allocate(/datum/ambient_outpost_role/recruiter/nanotrasen)
	var/datum/ambient_outpost_role/recruiter/syndicate/syn_role = allocate(/datum/ambient_outpost_role/recruiter/syndicate)
	var/obj/structure/overmap/trader_outpost/general/halcyon = allocate(/obj/structure/overmap/trader_outpost/general)
	var/obj/structure/overmap/trader_outpost/outfitter/quartermain = allocate(/obj/structure/overmap/trader_outpost/outfitter)
	var/obj/structure/overmap/trader_outpost/black_market/undertow = allocate(/obj/structure/overmap/trader_outpost/black_market)

	TEST_ASSERT(nt_role.applies_to(halcyon), "Nanotrasen does not recruit at Halcyon")
	TEST_ASSERT(nt_role.applies_to(quartermain), "Nanotrasen does not recruit at Quartermain")
	TEST_ASSERT(!nt_role.applies_to(undertow), "Nanotrasen recruits at the Undertow")

	TEST_ASSERT(syn_role.applies_to(quartermain), "The Syndicate does not recruit at Quartermain")
	TEST_ASSERT(syn_role.applies_to(undertow), "The Syndicate does not recruit at the Undertow")
	TEST_ASSERT(!syn_role.applies_to(halcyon), "The Syndicate recruits at Halcyon")

/// One of each side is already at their post at Quartermain when players come, and never a second of either, with players there or not
/datum/unit_test/voidcrew_ambient_recruiters_arrival

/datum/unit_test/voidcrew_ambient_recruiters_arrival/Run()
	var/obj/structure/overmap/trader_outpost/outpost = ambient_test_outpost_quartermain()
	var/datum/ambient_place/outpost/place = SSambient_npcs.outpost_place(outpost)
	var/datum/ambient_outpost_role/recruiter/nanotrasen/nt_role = allocate(/datum/ambient_outpost_role/recruiter/nanotrasen)
	var/datum/ambient_outpost_role/recruiter/syndicate/syn_role = allocate(/datum/ambient_outpost_role/recruiter/syndicate)
	var/list/roles = list(nt_role, syn_role)

	// Nobody there: both are made at their posts, not on the lift, and hold still
	for(var/i in 1 to 5)
		SSambient_npcs.update_outpost(place, 0, roles, 2)
	TEST_ASSERT_EQUAL(place.count_role(/datum/ambient_outpost_role/recruiter/nanotrasen), 1, "An empty Quartermain has [place.count_role(/datum/ambient_outpost_role/recruiter/nanotrasen)] Nanotrasen recruiters, not one")
	TEST_ASSERT_EQUAL(place.count_role(/datum/ambient_outpost_role/recruiter/syndicate), 1, "An empty Quartermain has [place.count_role(/datum/ambient_outpost_role/recruiter/syndicate)] Syndicate recruiters, not one")
	for(var/mob/living/basic/ambient_npc/recruiter/recruiter in place.npcs)
		TEST_ASSERT(get_dist(recruiter, run_loc_floor_top_right) > 1, "[recruiter] was made on or beside the lift, not at their post")
		TEST_ASSERT(recruiter.activity?.arrived, "[recruiter] was made at the outpost with nothing to do")
		TEST_ASSERT(HAS_TRAIT(recruiter, TRAIT_AI_PAUSED), "[recruiter] at an empty outpost is not holding still")

	// A player comes: nobody more steps off the lift
	for(var/i in 1 to 10)
		place.arrivals_at = world.time
		SSambient_npcs.update_outpost(place, 1, roles)
		for(var/mob/living/basic/ambient_npc/recruiter/newcomer in run_loc_floor_top_right)
			newcomer.forceMove(run_loc_floor_bottom_left)

	var/nt_count = place.count_role(/datum/ambient_outpost_role/recruiter/nanotrasen)
	var/syn_count = place.count_role(/datum/ambient_outpost_role/recruiter/syndicate)
	TEST_ASSERT_EQUAL(nt_count, 1, "Quartermain has [nt_count] Nanotrasen recruiters, not one")
	TEST_ASSERT_EQUAL(syn_count, 1, "Quartermain has [syn_count] Syndicate recruiters, not one")

	var/mob/living/basic/ambient_npc/recruiter/nanotrasen/nt_npc = locate() in place.npcs
	TEST_ASSERT(istype(nt_npc), "No Nanotrasen recruiter came")
	TEST_ASSERT_EQUAL(nt_npc.rival_type, /mob/living/basic/ambient_npc/recruiter/syndicate, "A Nanotrasen recruiter does not know their rival")
	TEST_ASSERT(!HAS_TRAIT(nt_npc, TRAIT_AI_PAUSED), "A recruiter still holds still with a player on the concourse")

/// Talking to a recruiter gets a pitch line and, once per ten minutes, a pamphlet with nothing recorded about the player (D2)
/datum/unit_test/voidcrew_ambient_recruiters_pamphlet

/datum/unit_test/voidcrew_ambient_recruiters_pamphlet/Run()
	var/mob/living/basic/ambient_npc/recruiter/nanotrasen/recruiter = allocate(/mob/living/basic/ambient_npc/recruiter/nanotrasen, run_loc_floor_bottom_left)
	var/mob/living/carbon/human/player = allocate(/mob/living/carbon/human/consistent, run_loc_floor_bottom_left)

	TEST_ASSERT(length(recruiter.get_lines("talk")), "A Nanotrasen recruiter has no talk line") // AMBIENT_LINE_TALK
	TEST_ASSERT(length(recruiter.get_lines("pamphlet")), "A Nanotrasen recruiter has no pamphlet line")

	TEST_ASSERT(recruiter.pamphlet_ready(player), "A player could not have a first pamphlet")
	TEST_ASSERT(!recruiter.pamphlet_ready(player), "A player could have a second pamphlet inside ten minutes")

	var/obj/item/paper/held_before = locate(/obj/item/paper/pamphlet/nanotrasen) in player.held_items
	TEST_ASSERT_NULL(held_before, "A player already has a pamphlet")
	recruiter.offer_pamphlet(WEAKREF(player))
	var/obj/item/paper/pamphlet/nanotrasen/leaflet = locate() in player.held_items
	TEST_ASSERT(istype(leaflet), "A recruiter did not hand over a pamphlet")

	// D2: nothing was recorded about the player beyond the ten-minute cooldown itself
	TEST_ASSERT_EQUAL(length(recruiter.pamphlet_cooldowns), 1, "More than the one cooldown entry was kept")

/// A rival's poster is torn down on sight, and their own posters stop going up past the cap
/datum/unit_test/voidcrew_ambient_recruiters_posters

/datum/unit_test/voidcrew_ambient_recruiters_posters/Run()
	var/mob/living/basic/ambient_npc/recruiter/nanotrasen/recruiter = allocate(/mob/living/basic/ambient_npc/recruiter/nanotrasen, run_loc_floor_bottom_left)
	var/turf/nearby = locate(run_loc_floor_bottom_left.x + 1, run_loc_floor_bottom_left.y, run_loc_floor_bottom_left.z)

	// A rival poster nearby is torn down, not put up over
	var/obj/structure/sign/poster/contraband/syndicate_recruitment/rival_poster = allocate(/obj/structure/sign/poster/contraband/syndicate_recruitment, nearby)
	var/datum/ambient_activity/recruit_poster/tear = new(recruiter)
	TEST_ASSERT(tear.setup(), "A recruiter found no rival poster to tear down")
	TEST_ASSERT(tear.tearing, "A recruiter put up a poster instead of tearing the rival's down")
	tear.arrived = TRUE
	tear.arrive()
	TEST_ASSERT(QDELETED(rival_poster), "A torn rival poster is still standing")
	qdel(tear)

	// Their own posters stop going up once two are already near them
	new /obj/structure/sign/poster/official/nanotrasen_logo(run_loc_floor_bottom_left)
	new /obj/structure/sign/poster/official/enlist(nearby)
	TEST_ASSERT_EQUAL(recruiter.count_own_posters(), 2, "The recruiter's own posters were miscounted")
	var/datum/ambient_activity/recruit_poster/capped = new(recruiter)
	TEST_ASSERT(!capped.setup(), "A recruiter put up a third poster past the cap of two") // RECRUITER_POSTER_CAP
	qdel(capped)

/// Barbs: the opener is this side's own line, and the rival speaks the paired reply
/datum/unit_test/voidcrew_ambient_recruiters_barbs

/datum/unit_test/voidcrew_ambient_recruiters_barbs/Run()
	var/mob/living/basic/ambient_npc/recruiter/nanotrasen/nt_npc = allocate(/mob/living/basic/ambient_npc/recruiter/nanotrasen, run_loc_floor_bottom_left)
	var/turf/beside = locate(run_loc_floor_bottom_left.x + 1, run_loc_floor_bottom_left.y, run_loc_floor_bottom_left.z)
	var/mob/living/basic/ambient_npc/recruiter/syndicate/syn_npc = allocate(/mob/living/basic/ambient_npc/recruiter/syndicate, beside)

	var/list/barb = nt_npc.pick_barb()
	TEST_ASSERT(islist(barb) && length(barb) == 2 && istext(barb[1]), "Nanotrasen has no usable barb")
	var/filled = nt_npc.fill_line(barb[1], syn_npc)
	TEST_ASSERT(!findtext(filled, "{"), "A barb opener kept a placeholder: [filled]")

	var/datum/ambient_activity/recruit_barb/exchange = new(nt_npc)
	TEST_ASSERT(exchange.setup(), "A recruiter found no nearby rival to bait")
	TEST_ASSERT_EQUAL(exchange.find_rival(nt_npc), syn_npc, "A recruiter baited the wrong rival")
	qdel(exchange)
