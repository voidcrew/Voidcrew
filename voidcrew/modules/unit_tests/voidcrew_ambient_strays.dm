/**
 * World population: tests for recruit.dm, stranded.dm, stranded_lifeboat.dm and convict.dm
 * in voidcrew/modules/ambient_npcs/.
 *
 * Owner: PC (strays). P0 made this file as a stub; only that package edits it.
 *
 * Fork defines are included after the tests, so a test uses the literal value with a comment
 * naming the define. SSambient_npcs and SSambient_strays do nothing on their own in tests
 * (`ambient_auto`, `strays_auto`); these tests drive sites, strays, convicts and lifeboats by hand.
 * A bare ship has no hull, so its deckhand place here counts the test room as aboard.
 */

/// A ship's deckhand place whose "aboard" is a rectangle: a bare ship has no hull to be aboard
/datum/ambient_place/ship/strays_test
	/// What counts as aboard, list(min x, min y, max x, max y, z)
	var/list/test_bounds

/datum/ambient_place/ship/strays_test/aboard(turf/tile)
	return ambient_in_bounds(get_turf(tile), test_bounds)

/// A convict hideout kind that always has room. No planet types, so the shared instance never rolls.
/datum/ambient_site_kind/convict/strays_test
	name = "strays test hideout"
	planet_types = list()
	chance = 0

/datum/ambient_site_kind/convict/strays_test/has_room()
	return TRUE

/// A bare ship whose deckhand place counts `bounds` as aboard
/datum/unit_test/proc/strays_test_ship(list/bounds)
	var/obj/structure/overmap/ship/ship = allocate(/obj/structure/overmap/ship)
	var/datum/ambient_place/ship/strays_test/deck = new(ship)
	deck.test_bounds = bounds
	GLOB.ambient_ship_places[REF(ship)] = deck
	return ship

/// Closes every bounty posting and stops the board's clock, or starts it again after a test
/datum/unit_test/proc/strays_test_board(stop)
	SScriminal_bounties.can_fire = !stop
	for(var/datum/criminal_bounty/posting as anything in GLOB.criminal_bounties.Copy())
		posting.close("admin") // BOUNTY_CLOSE_ADMIN

/// Deletes what a camp left in the test room: its structures, items and decals
/datum/unit_test/proc/strays_test_clear_room()
	for(var/turf/tile as anything in block(run_loc_floor_bottom_left, run_loc_floor_top_right))
		for(var/obj/thing in tile)
			if(istype(thing, /obj/effect/landmark))
				continue
			qdel(thing)

// =========================================================================
// THE RECRUIT FLOW
// =========================================================================

/// A crew member asks a stray along: they follow, one at a time per ship; aboard they are a deckhand kept aboard; two a round; a lost or deleted follower frees the place; the ship going takes its deckhands
/datum/unit_test/voidcrew_ambient_strays_recruit

/datum/unit_test/voidcrew_ambient_strays_recruit/Run()
	var/list/room = ambient_test_room_bounds()
	var/turf/corner = run_loc_floor_bottom_left
	var/obj/structure/overmap/ship/ship = strays_test_ship(room)
	var/ship_key = REF(ship)
	var/datum/ambient_place/ship/deck = ambient_ship_place(ship, create = FALSE)
	TEST_ASSERT(istype(deck, /datum/ambient_place/ship/strays_test), "The test ship has no deckhand place")
	var/mob/living/carbon/human/consistent/leader = allocate(__IMPLIED_TYPE__, run_loc_floor_top_right)
	var/mob/living/basic/ambient_npc/stray/stranded/stray = allocate(/mob/living/basic/ambient_npc/stray/stranded, corner)

	// Only strays can be asked along
	TEST_ASSERT(ambient_offer_recruit(stray), "A stray could not be opened to offers")
	var/mob/living/basic/ambient_npc/plain = allocate(/mob/living/basic/ambient_npc, corner)
	TEST_ASSERT(!ambient_offer_recruit(plain), "An ordinary ambient NPC was opened to offers")
	TEST_ASSERT(stray.is_wild(), "A new stray is not wild")
	TEST_ASSERT(!HAS_TRAIT(stray, TRAIT_GODMODE), "A stray can't be hurt")
	TEST_ASSERT(!length(stray.death_loot), "A stray drops something when killed")
	TEST_ASSERT(!stray.death_cash_high, "A stray drops cash when killed")

	// The crew a player belongs to
	TEST_ASSERT_NULL(ambient_crew_ship(leader), "A player with no crew has a ship")
	var/datum/team/voidcrew/crew = allocate(/datum/team/voidcrew)
	crew.ship = ship
	leader.mind_initialize()
	LAZYADD(leader.mind.ship_teams, crew)
	TEST_ASSERT_EQUAL(ambient_crew_ship(leader), ship, "A crew member's ship was not found")
	ship.abandoned = TRUE
	TEST_ASSERT_NULL(ambient_crew_ship(leader), "An abandoned ship still counts as a player's")
	ship.abandoned = FALSE
	LAZYREMOVE(leader.mind.ship_teams, crew)

	// Asked along: following the leader, the ship's one place on the way taken
	TEST_ASSERT(ambient_ship_can_take(ship), "A ship with nobody aboard could not take a stray")
	TEST_ASSERT(stray.accept_offer(leader, ship), "A stray refused a ship with room")
	TEST_ASSERT(stray.is_following(), "A stray who agreed is not following")
	TEST_ASSERT(istype(stray.activity, /datum/ambient_activity/stray_follow), "A stray who agreed is not following anyone")
	TEST_ASSERT_EQUAL(stray.get_leader(), leader, "A stray follows someone else")
	TEST_ASSERT_EQUAL(deck.pending(), stray, "The ship does not know who is on the way")
	TEST_ASSERT(HAS_TRAIT(stray, TRAIT_SPACEWALK), "A follower can't cross open space to the ship")
	TEST_ASSERT_NULL(stray.start_activity(new /datum/ambient_activity/shelter(stray, null, 100)), "A storm stopped a stray following")
	TEST_ASSERT(!stray.accept_offer(leader, ship), "A follower agreed a second time")
	TEST_ASSERT(!ambient_ship_can_take(ship), "A ship took a second stray while one was on the way") // AMBIENT_RECRUITS_PENDING_PER_SHIP
	var/mob/living/basic/ambient_npc/stray/stranded/second = allocate(/mob/living/basic/ambient_npc/stray/stranded, corner)
	TEST_ASSERT(!second.accept_offer(leader, ship), "Two strays were on their way to one ship at once")

	// Aboard: a deckhand, kept aboard, living by the deckhand routine
	TEST_ASSERT(stray.board(ship), "A stray did not come aboard")
	TEST_ASSERT(stray.is_deckhand(), "A stray aboard is not a deckhand")
	TEST_ASSERT_EQUAL(stray.place, deck, "A deckhand does not belong to their ship")
	TEST_ASSERT_EQUAL(deck.taken, 1, "The ship did not count the stray it took")
	TEST_ASSERT_NULL(deck.pending(), "A deckhand is still on the way")
	TEST_ASSERT(!istype(stray.activity, /datum/ambient_activity/stray_follow), "A deckhand kept following after coming aboard")
	TEST_ASSERT(stray.routine[/datum/ambient_activity/stray_wash], "A deckhand does not use the sink")
	TEST_ASSERT(stray.routine[/datum/ambient_activity/stray_rest], "A deckhand does not use a bunk")
	TEST_ASSERT(stray.leash_ok(corner), "A deckhand may not stand aboard")
	var/turf/outside = locate(room[3] + 1, room[2], room[5])
	TEST_ASSERT(!stray.leash_ok(outside), "A deckhand may walk off their ship")
	TEST_ASSERT(!stray.accept_offer(leader, ship), "A deckhand agreed to join again")

	// A second stray, then the round's limit
	TEST_ASSERT(second.accept_offer(leader, ship), "A ship with one deckhand could not take a second stray")
	TEST_ASSERT(second.board(ship), "The second stray did not come aboard")
	TEST_ASSERT_EQUAL(deck.taken, 2, "The ship did not count its second stray")
	TEST_ASSERT(!ambient_ship_can_take(ship), "A ship took more than two strays in a round") // AMBIENT_RECRUITS_PER_SHIP_ROUND
	var/mob/living/basic/ambient_npc/stray/stranded/third = allocate(/mob/living/basic/ambient_npc/stray/stranded, corner)
	TEST_ASSERT(!third.accept_offer(leader, ship), "A third stray joined a ship in one round")

	// A follower deleted on the way (the planet's sweep) frees their ship's place
	var/obj/structure/overmap/ship/other_ship = strays_test_ship(room)
	var/mob/living/basic/ambient_npc/stray/stranded/runaway = allocate(/mob/living/basic/ambient_npc/stray/stranded, corner)
	TEST_ASSERT(runaway.accept_offer(leader, other_ship), "A stray refused a second ship")
	qdel(runaway)
	TEST_ASSERT(ambient_ship_can_take(other_ship), "A deleted follower kept their ship's place")

	// One whose leader is gone goes back to being wild and frees the place
	var/mob/living/basic/ambient_npc/stray/stranded/lost = allocate(/mob/living/basic/ambient_npc/stray/stranded, corner)
	TEST_ASSERT(lost.accept_offer(leader, other_ship), "A stray refused a ship with room")
	lost.lose_leader()
	TEST_ASSERT(lost.is_wild(), "A stray who lost their leader is not wild again")
	TEST_ASSERT(ambient_ship_can_take(other_ship), "A lost follower kept their ship's place")
	TEST_ASSERT(!HAS_TRAIT(lost, TRAIT_SPACEWALK), "A lost follower can still cross open space")

	// One killed on the way frees it too, and drops nothing
	var/mob/living/basic/ambient_npc/stray/stranded/doomed = allocate(/mob/living/basic/ambient_npc/stray/stranded, corner)
	TEST_ASSERT(doomed.accept_offer(leader, other_ship), "A stray refused a ship with room")
	var/objects_before = length(corner.contents)
	doomed.death()
	TEST_ASSERT(ambient_ship_can_take(other_ship), "A dead follower kept their ship's place")
	TEST_ASSERT(length(corner.contents) <= objects_before, "A dead stray dropped something")

	// The ship goes: its deckhands go with it, and so does its place
	qdel(ship)
	TEST_ASSERT(QDELETED(stray), "A deckhand stayed when their ship was deleted")
	TEST_ASSERT_NULL(GLOB.ambient_ship_places[ship_key], "A deleted ship kept its deckhand place")

// =========================================================================
// DECKHANDS
// =========================================================================

/// A deckhand washes at the sink, lies down in a bunk and gets up again, and looks out of a window, all aboard
/datum/unit_test/voidcrew_ambient_strays_deckhand

/datum/unit_test/voidcrew_ambient_strays_deckhand/Run()
	var/list/room = ambient_test_room_bounds()
	var/turf/corner = run_loc_floor_bottom_left
	var/obj/structure/overmap/ship/ship = strays_test_ship(room)
	var/mob/living/carbon/human/consistent/leader = allocate(__IMPLIED_TYPE__, run_loc_floor_top_right)
	var/mob/living/basic/ambient_npc/stray/stranded/deckhand = allocate(/mob/living/basic/ambient_npc/stray/stranded, corner)
	deckhand.ai_controller?.set_ai_status(AI_STATUS_OFF)
	TEST_ASSERT(deckhand.accept_offer(leader, ship) && deckhand.board(ship), "The stray did not come aboard")

	// The sink
	var/obj/structure/sink/sink = allocate(/obj/structure/sink, locate(corner.x + 2, corner.y, corner.z))
	var/datum/ambient_activity/stray_wash/wash = deckhand.start_activity(new /datum/ambient_activity/stray_wash(deckhand))
	TEST_ASSERT_NOTNULL(wash, "A deckhand would not wash up at a sink aboard")
	TEST_ASSERT(get_dist(wash.spot, sink) <= 1, "A deckhand went to wash up away from the sink")
	deckhand.end_activity()

	// A bunk: lying in it, then up again
	var/obj/structure/bed/bed = allocate(/obj/structure/bed, locate(corner.x + 1, corner.y + 3, corner.z))
	var/datum/ambient_activity/stray_rest/rest = deckhand.start_activity(new /datum/ambient_activity/stray_rest(deckhand))
	TEST_ASSERT_NOTNULL(rest, "A deckhand would not lie down in a free bunk aboard")
	TEST_ASSERT_EQUAL(rest.spot, get_turf(bed), "A deckhand went to rest somewhere other than the bunk")
	deckhand.forceMove(get_turf(bed))
	deckhand.activity_step(1)
	TEST_ASSERT_EQUAL(deckhand.buckled, bed, "A deckhand did not lie down in the bunk")
	deckhand.end_activity()
	TEST_ASSERT_NULL(deckhand.buckled, "A deckhand stayed in the bunk after resting")

	// Someone in the bunk: nobody lies on top of them
	var/mob/living/carbon/human/consistent/sleeper = allocate(__IMPLIED_TYPE__, get_turf(bed))
	bed.buckle_mob(sleeper, force = TRUE)
	TEST_ASSERT_NULL(deckhand.start_activity(new /datum/ambient_activity/stray_rest(deckhand)), "A deckhand went to lie in an occupied bunk")
	bed.unbuckle_mob(sleeper, force = TRUE)

	// A window
	var/obj/structure/window/fulltile/window = allocate(/obj/structure/window/fulltile, locate(corner.x + 4, corner.y + 4, corner.z))
	deckhand.forceMove(corner)
	var/datum/ambient_activity/stray_window/look = deckhand.start_activity(new /datum/ambient_activity/stray_window(deckhand))
	TEST_ASSERT_NOTNULL(look, "A deckhand would not look out of a window aboard")
	TEST_ASSERT(look.spot && look.spot.Adjacent(window), "A deckhand went to look out of a window from a tile not beside it")
	deckhand.end_activity()

// =========================================================================
// STRANDED ON A PLANET
// =========================================================================

/// A crashed pod rolls on its planets only, builds its camp once, brings the same person back after a sweep, and is spent once they are taken aboard
/datum/unit_test/voidcrew_ambient_strays_stranded

/datum/unit_test/voidcrew_ambient_strays_stranded/Run()
	var/datum/ambient_site_kind/stranded/kind = SSambient_npcs.get_site_kind(/datum/ambient_site_kind/stranded)
	TEST_ASSERT_NOTNULL(kind, "The crashed pod site kind is not registered")
	var/datum/ambient_planet/record = allocate(/datum/ambient_planet)
	record.band = 1 // ZONE_GREEN
	record.planet_type = /datum/overmap/planet/beach
	TEST_ASSERT_EQUAL(kind.chance_on(record), 7, "A crashed pod's chance on an oceanic planet is wrong")
	record.planet_type = /datum/overmap/planet/jungle
	TEST_ASSERT_EQUAL(kind.chance_on(record), 5, "A crashed pod's chance on a jungle planet is wrong")
	record.planet_type = /datum/overmap/planet/asteroid
	TEST_ASSERT_EQUAL(kind.chance_on(record), 0, "A crashed pod can roll on an asteroid")
	record.planet_type = /datum/overmap/planet/jungle
	record.bounds = ambient_test_room_bounds()

	var/turf/corner = run_loc_floor_bottom_left
	var/turf/middle = locate(corner.x + 2, corner.y + 2, corner.z)
	var/datum/ambient_place/site/site = new(kind, middle, record)
	record.sites += site

	// The camp and its one person
	TEST_ASSERT(kind.realize(site), "A crashed pod brought nobody out")
	var/list/people = site.living_npcs()
	TEST_ASSERT_EQUAL(length(people), 1, "A crashed pod brought out [length(people)] people")
	var/mob/living/basic/ambient_npc/stray/stranded/survivor = people[1]
	TEST_ASSERT(istype(survivor), "A crashed pod's person is not a stranded survivor")
	TEST_ASSERT(survivor.is_wild() && survivor.recruit_open, "A stranded survivor can't be asked along")
	TEST_ASSERT(site.get_prop(/obj/structure/bonfire) || site.get_prop(/obj/structure/bounty_camp_lamp), "A crashed pod has no fire or lantern")
	TEST_ASSERT_NOTNULL(site.get_prop(/obj/structure/chair/comfy/shuttle), "A crashed pod has no seat")
	TEST_ASSERT_NOTNULL(site.get_prop(/obj/structure/closet/crate/internals), "A crashed pod has no emergency crate")
	var/obj/structure/closet/crate/internals/crate = site.get_prop(/obj/structure/closet/crate/internals)
	TEST_ASSERT(!length(crate?.contents), "A crashed pod's crate has something in it")
	TEST_ASSERT(!kind.realize(site), "A crashed pod brought a second person out")

	// Swept alive: the same person comes back, and the camp is not built again
	var/survivor_name = survivor.real_name
	var/seats = 0
	for(var/obj/structure/chair/comfy/shuttle/seat in range(3, middle))
		seats++
	qdel(survivor)
	TEST_ASSERT(kind.realize(site), "A swept survivor did not come back")
	people = site.living_npcs()
	var/mob/living/basic/ambient_npc/stray/stranded/again = length(people) ? people[1] : null
	TEST_ASSERT_EQUAL(again?.real_name, survivor_name, "A different person came back to the pod")
	var/seats_after = 0
	for(var/obj/structure/chair/comfy/shuttle/seat in range(3, middle))
		seats_after++
	TEST_ASSERT_EQUAL(seats_after, seats, "The pod's camp was built twice")

	// Taken aboard: the site is spent, and nobody comes back
	var/obj/structure/overmap/ship/ship = strays_test_ship(ambient_test_room_bounds())
	var/mob/living/carbon/human/consistent/leader = allocate(__IMPLIED_TYPE__, run_loc_floor_top_right)
	TEST_ASSERT(again?.accept_offer(leader, ship), "A stranded survivor refused a ship with room")
	TEST_ASSERT(again?.board(ship), "A stranded survivor did not come aboard")
	TEST_ASSERT_EQUAL(site.state, "spent", "A site whose survivor was taken aboard is not spent") // AMBIENT_SITE_SPENT
	TEST_ASSERT(!kind.realize(site), "A pod whose survivor was taken aboard brought someone out")
	allocated += again

	for(var/datum/weakref/ref as anything in site.props)
		qdel(ref?.resolve())
	strays_test_clear_room()

// =========================================================================
// THE ESCAPED CONVICT
// =========================================================================

/// The cap follows the crews; a convict is a meek petty criminal in orange; seen, they get one private offer on their own record, within the two-offer limit; talked down, the offer is withdrawn unpaid and a stray with their name follows the crew; an offer that ends leaves a free convict where they are
/datum/unit_test/voidcrew_ambient_strays_convict

/datum/unit_test/voidcrew_ambient_strays_convict/Run()
	TEST_ASSERT_EQUAL(ambient_convict_cap(0), 0, "Convicts turn up with no crews playing")
	TEST_ASSERT_EQUAL(ambient_convict_cap(1), 1, "One crew gets no convict")
	TEST_ASSERT_EQUAL(ambient_convict_cap(3), 1, "Three crews get more than one convict") // AMBIENT_CONVICT_SHIPS_PER
	TEST_ASSERT_EQUAL(ambient_convict_cap(4), 2, "Four crews don't get a second convict")
	TEST_ASSERT_EQUAL(ambient_convict_cap(30), 3, "The convict cap is not three") // AMBIENT_CONVICTS_MAX

	strays_test_board(TRUE)
	var/list/room = ambient_test_room_bounds()
	var/turf/corner = run_loc_floor_bottom_left
	var/obj/structure/overmap/space_ruin/ruin = allocate(/obj/structure/overmap/space_ruin)
	var/mob/living/basic/bounty_criminal/meek/convict/convict = ambient_spawn_convict(corner, ruin, "ruin") // BOUNTY_PLACEMENT_RUIN
	TEST_ASSERT_NOTNULL(convict, "No convict was made")
	allocated += convict
	convict.ai_controller?.set_ai_status(AI_STATUS_OFF)
	TEST_ASSERT(WEAKREF(convict) in GLOB.ambient_convicts, "A convict is not on the list")
	TEST_ASSERT_EQUAL(convict.record?.tier, 1, "A convict is not a petty criminal") // BOUNTY_TIER_PETTY
	TEST_ASSERT_EQUAL(convict.record?.archetype, "meek", "A convict is not meek") // BOUNTY_ARCHETYPE_MEEK
	TEST_ASSERT_EQUAL(convict.bounty_outfit(), /datum/outfit/prisoner, "A convict is not in prison orange")
	TEST_ASSERT_NULL(convict.posting(), "A convict nobody has seen is wanted")
	TEST_ASSERT(convict.convict_can_talk(), "A calm convict won't talk")
	convict.hidden = TRUE
	TEST_ASSERT(!convict.convict_can_talk(), "A hidden convict talks")
	convict.hidden = FALSE

	// Seen: one private petty offer, to that crew, on the convict's own record
	var/obj/structure/overmap/ship/ship = strays_test_ship(room)
	var/datum/criminal_bounty/posting = convict.convict_post_bounty(ship)
	TEST_ASSERT_NOTNULL(posting, "Seeing a convict posted no bounty")
	TEST_ASSERT_EQUAL(posting?.record, convict.record, "The bounty shows someone other than the convict")
	TEST_ASSERT_EQUAL(posting?.offered_to(), ship, "The bounty was not offered to the crew who saw the convict")
	TEST_ASSERT_EQUAL(posting?.criminal(), convict, "The bounty is not on the convict who was seen")
	TEST_ASSERT_EQUAL(posting?.record?.tier, 1, "The convict's bounty is not petty") // BOUNTY_TIER_PETTY
	TEST_ASSERT(posting?.value > 0, "The convict's bounty pays nothing")
	TEST_ASSERT(HAS_TRAIT(convict, "mission_field_mob"), "A wanted convict can be swept off their planet") // TRAIT_MISSION_FIELD_MOB
	TEST_ASSERT_NULL(convict.convict_post_bounty(ship), "A convict was posted twice")

	// A crew with both private offers taken gets none
	var/obj/structure/overmap/ship/busy = strays_test_ship(room)
	SScriminal_bounties.board_post(1, null, ruin, busy, TRUE) // BOUNTY_TIER_PETTY
	SScriminal_bounties.board_post(1, null, ruin, busy, TRUE)
	var/mob/living/basic/bounty_criminal/meek/convict/other = ambient_spawn_convict(run_loc_floor_top_right, ruin, "ruin")
	allocated += other
	other.ai_controller?.set_ai_status(AI_STATUS_OFF)
	TEST_ASSERT_NULL(other.convict_post_bounty(busy), "A convict's bounty went past the two private offers") // BOUNTY_PRIVATE_MAX

	// Talked down: the bounty is withdrawn unpaid, and a stray with their name follows the crew
	var/mob/living/carbon/human/consistent/leader = allocate(__IMPLIED_TYPE__, locate(corner.x + 1, corner.y, corner.z))
	var/convict_name = convict.real_name
	var/datum/bounty_record/convict_record = convict.record
	var/mob/living/basic/ambient_npc/stray/convict/stray = convict.convict_join(leader, ship)
	TEST_ASSERT_NOTNULL(stray, "A talked-down convict did not join the crew")
	allocated += stray
	TEST_ASSERT(QDELETED(convict), "The convict's body stayed after they joined a crew")
	TEST_ASSERT(!(posting in GLOB.criminal_bounties), "Recruiting the convict left their bounty open")
	TEST_ASSERT_EQUAL(convict_record.status, "closed", "The recruited convict's record is still wanted") // BOUNTY_RECORD_CLOSED
	TEST_ASSERT_EQUAL(stray?.real_name, convict_name, "The convict came back as someone else")
	TEST_ASSERT_EQUAL(stray?.bounty_record, convict_record, "The recruited convict lost their face")
	TEST_ASSERT(stray?.is_following(), "The recruited convict is not following the crew")
	TEST_ASSERT_NULL(locate(/obj/item/bounty_proof) in get_turf(stray), "Recruiting the convict left proof of death")

	// The crew's last offer just ended: none during the board's gap after it
	TEST_ASSERT_NULL(other.convict_post_bounty(ship), "A convict was offered during the gap after the crew's last private offer ended") // BOUNTY_PRIVATE_GAP
	SScriminal_bounties.board_private_next -= WEAKREF(ship)

	// An offer that ends while the convict is free leaves them where they are, off the board
	var/datum/criminal_bounty/second_posting = other.convict_post_bounty(ship)
	TEST_ASSERT_NOTNULL(second_posting, "A second convict was not posted to a crew with room")
	second_posting?.close("expired") // BOUNTY_CLOSE_EXPIRED
	TEST_ASSERT(!QDELETED(other), "A free convict was taken away when their offer ran out")
	TEST_ASSERT_NULL(other.posting(), "A convict is still wanted after their offer ran out")
	TEST_ASSERT(!HAS_TRAIT(other, "mission_field_mob"), "A convict off the board is still kept from the sweep") // TRAIT_MISSION_FIELD_MOB

	strays_test_board(FALSE)
	strays_test_clear_room()

/// A planet hideout brings one convict out, the same person after a sweep, and none once they are killed
/datum/unit_test/voidcrew_ambient_strays_convict_site

/datum/unit_test/voidcrew_ambient_strays_convict_site/Run()
	var/datum/ambient_site_kind/convict/strays_test/kind = allocate(/datum/ambient_site_kind/convict/strays_test)
	kind.planet_types = list(/datum/overmap/planet/lava, /datum/overmap/planet/wasteland, /datum/overmap/planet/jungle)
	kind.chance = 15
	var/datum/ambient_planet/record = allocate(/datum/ambient_planet)
	record.band = 2 // ZONE_YELLOW
	record.planet_type = /datum/overmap/planet/lava
	TEST_ASSERT_EQUAL(kind.chance_on(record), 4, "A convict's chance on a lava planet is wrong")
	record.planet_type = /datum/overmap/planet/wasteland
	TEST_ASSERT_EQUAL(kind.chance_on(record), 7, "A convict's chance on a wasteland is wrong")
	record.planet_type = /datum/overmap/planet/jungle
	TEST_ASSERT_EQUAL(kind.chance_on(record), 15, "A convict's chance on a jungle planet is wrong")
	record.band = 1 // ZONE_GREEN
	TEST_ASSERT_EQUAL(kind.chance_on(record), 0, "A convict can turn up in green space")
	record.band = 2 // ZONE_YELLOW
	record.bounds = ambient_test_room_bounds()

	var/datum/ambient_place/site/site = new(kind, run_loc_floor_bottom_left, record)
	record.sites += site
	TEST_ASSERT(kind.realize(site), "A hideout brought no convict out")
	var/datum/weakref/convict_ref = site.data["convict"]
	var/mob/living/basic/bounty_criminal/meek/convict/convict = convict_ref?.resolve()
	TEST_ASSERT(istype(convict), "A hideout's convict is not a convict")
	allocated += convict
	convict.ai_controller?.set_ai_status(AI_STATUS_OFF)
	TEST_ASSERT(!kind.realize(site), "A hideout brought out a second convict")

	// Swept alive: the same person on the next visit
	var/datum/bounty_record/who = convict.record
	qdel(convict)
	TEST_ASSERT(kind.realize(site), "A swept convict did not come back")
	convict_ref = site.data["convict"]
	convict = convict_ref?.resolve()
	allocated += convict
	convict?.ai_controller?.set_ai_status(AI_STATUS_OFF)
	TEST_ASSERT_EQUAL(convict?.record, who, "A different convict came back")

	// Killed: the hideout is spent
	convict?.death()
	TEST_ASSERT_EQUAL(site.state, "spent", "A hideout whose convict was killed is not spent") // AMBIENT_SITE_SPENT
	TEST_ASSERT(!kind.realize(site), "A spent hideout brought a convict out")
	strays_test_clear_room()

// =========================================================================
// THE LIFEBOAT
// =========================================================================

/// The lifeboat's ruin is registered, never seeded, fits a slot and has its survivor's spot; it sets out charted and calling; its survivor is the same person on every load; taken in, the beacon stops; left alone, the beacon goes quiet and it goes
/datum/unit_test/voidcrew_ambient_strays_lifeboat
	/// Lifeboats this test sent out, deleted after it
	var/list/lifeboats = list()

/datum/unit_test/voidcrew_ambient_strays_lifeboat/Destroy()
	for(var/obj/structure/overmap/space_ruin/ambient_lifeboat/lifeboat as anything in lifeboats)
		if(!QDELETED(lifeboat))
			qdel(lifeboat)
	lifeboats = null
	return ..()

/datum/unit_test/voidcrew_ambient_strays_lifeboat/Run()
	var/datum/map_template/ruin/space/template = ambient_lifeboat_template()
	TEST_ASSERT_NOTNULL(template, "The lifeboat ruin template is not registered")
	TEST_ASSERT(template.unpickable, "The lifeboat could be seeded as an ordinary ruin")
	TEST_ASSERT(SSovermap.ruin_fits_in_slot(template), "The lifeboat does not fit a ruin slot")
	var/map_text = file2text("[template.prefix][template.suffix]")
	TEST_ASSERT(findtext(map_text, "/obj/effect/landmark/ambient_lifeboat_survivor"), "The lifeboat map has no spot for its survivor")
	TEST_ASSERT(findtext(map_text, "/area/ruin/space/has_grav/powered/ambient_lifeboat"), "The lifeboat map is not in its own ruin area")

	// Sent out: on the overmap, charted on every helm, its beacon on a clock
	var/obj/structure/overmap/space_ruin/ambient_lifeboat/lifeboat = SSambient_strays.launch_lifeboat(2) // ZONE_YELLOW
	TEST_ASSERT_NOTNULL(lifeboat, "No lifeboat could be sent out")
	lifeboats += lifeboat
	TEST_ASSERT_EQUAL(lifeboat.ruin_template, template, "The lifeboat has another ruin")
	TEST_ASSERT(lifeboat.surveyed, "The lifeboat is an unknown signal")
	TEST_ASSERT(lifeboat in GLOB.overmap_fleet_beacons, "The lifeboat is not charted on the helms")
	TEST_ASSERT(lifeboat.quiet_timer, "The lifeboat's beacon never goes quiet")
	TEST_ASSERT(lifeboat.mission_exclusive, "Contracts may aim at the lifeboat")
	TEST_ASSERT_EQUAL(length(SSambient_strays.live_lifeboats()), 1, "More than one lifeboat is out")

	// Its survivor: open to offers, in their softsuit, and the same person on the next load
	var/mob/living/basic/ambient_npc/stray/lifeboat/survivor = lifeboat.spawn_survivor(run_loc_floor_bottom_left)
	allocated += survivor
	survivor.ai_controller?.set_ai_status(AI_STATUS_OFF)
	TEST_ASSERT(survivor.is_wild() && survivor.recruit_open, "The lifeboat's survivor can't be asked along")
	TEST_ASSERT(HAS_TRAIT(survivor, TRAIT_SPACEWALK), "The lifeboat's survivor can't cross open space")
	var/survivor_name = survivor.real_name
	qdel(survivor)
	var/mob/living/basic/ambient_npc/stray/lifeboat/again = lifeboat.spawn_survivor(run_loc_floor_bottom_left)
	allocated += again
	again.ai_controller?.set_ai_status(AI_STATUS_OFF)
	TEST_ASSERT_EQUAL(again.real_name, survivor_name, "Someone else was aboard the lifeboat on the next load")

	// Taken in: the beacon stops
	var/obj/structure/overmap/ship/ship = strays_test_ship(ambient_test_room_bounds())
	var/mob/living/carbon/human/consistent/leader = allocate(__IMPLIED_TYPE__, run_loc_floor_top_right)
	TEST_ASSERT(again.accept_offer(leader, ship), "The lifeboat's survivor refused a ship with room")
	TEST_ASSERT(lifeboat.rescued, "The lifeboat does not know its survivor was taken in")
	TEST_ASSERT(!(lifeboat in GLOB.overmap_fleet_beacons), "The lifeboat is still charted after its survivor was taken in")
	TEST_ASSERT_NULL(lifeboat.quiet_timer, "The lifeboat's beacon still has a clock after its survivor was taken in")

	// One whose survivor was killed: nobody on the next load, and the beacon stops
	var/obj/structure/overmap/space_ruin/ambient_lifeboat/grim = allocate(/obj/structure/overmap/space_ruin/ambient_lifeboat)
	grim.set_ruin_template(template)
	grim.start_beacon()
	var/mob/living/basic/ambient_npc/stray/lifeboat/victim = grim.spawn_survivor(run_loc_floor_bottom_left)
	allocated += victim
	victim.ai_controller?.set_ai_status(AI_STATUS_OFF)
	victim.death()
	TEST_ASSERT(grim.ended, "A lifeboat whose survivor was killed kept calling")
	TEST_ASSERT(!(grim in GLOB.overmap_fleet_beacons), "A lifeboat whose survivor was killed is still charted")
	TEST_ASSERT_NULL(grim.quiet_timer, "A lifeboat whose survivor was killed still has a clock")

	// Nobody came for this one: its beacon goes quiet and, never loaded, it is gone at once
	var/obj/structure/overmap/space_ruin/ambient_lifeboat/lonely = allocate(/obj/structure/overmap/space_ruin/ambient_lifeboat)
	lonely.set_ruin_template(template)
	lonely.start_beacon()
	lonely.go_quiet()
	TEST_ASSERT(lonely.ended, "A lifeboat nobody came for kept calling")
	TEST_ASSERT(QDELETED(lonely), "A lifeboat whose beacon went quiet was not removed")
	TEST_ASSERT(!(lonely in GLOB.overmap_fleet_beacons), "A quiet lifeboat is still charted")

// =========================================================================
// LINES
// =========================================================================

/// Every stray has what they need to say through the recruit flow, and the lifeboat has its mayday
/datum/unit_test/voidcrew_ambient_strays_lines

/datum/unit_test/voidcrew_ambient_strays_lines/Run()
	for(var/section in list("stranded", "lifeboat", "convict"))
		for(var/context in list("talk", "accepted", "aboard", "lost"))
			TEST_ASSERT(length(ambient_dialogue_lines("strays.json", section, context)), "Strays: [section] has no [context] lines") // AMBIENT_STRINGS_STRAYS
	for(var/section in list("stranded", "lifeboat"))
		for(var/context in list("greet", "refused"))
			TEST_ASSERT(length(ambient_dialogue_lines("strays.json", section, context)), "Strays: [section] has no [context] lines")
	for(var/context in list("sighted", "plea", "refused", "camp", "cornered", "cuffed"))
		TEST_ASSERT(length(ambient_dialogue_lines("strays.json", "convict", context)), "Strays: the convict has no [context] lines")
	for(var/context in list("idle", "talk", "crew", "follow", "wait", "dismissed"))
		TEST_ASSERT(length(ambient_dialogue_lines("strays.json", "deckhand", context)), "Strays: deckhands have no [context] lines")
	TEST_ASSERT(length(ambient_dialogue_lines("strays.json", "lifeboat", "mayday")), "The lifeboat has no mayday")
