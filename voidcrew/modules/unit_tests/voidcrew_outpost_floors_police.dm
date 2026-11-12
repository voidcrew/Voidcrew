/**
 * Outpost floors (voidcrew/modules/trade_floors/): tests of package P5, the police on floors (police_floors.dm).
 * Owner: P5. Subtype /datum/unit_test/voidcrew_outpost_floors and use the helpers in
 * voidcrew_outpost_floors_helpers.dm (P0, frozen). Fork defines are included after the tests: write the literal
 * value with a comment naming the define. Pin other packages' outputs directly and never wait for an AI walk.
 *
 * Settings: "crew", "invited", "open" (OUTPOST_FLOOR_ENTRY_*). Heat for each star (OUTPOST_POLICE_STAR_HEAT): 10, 25,
 * 50, 90, 140. Ticks are driven by hand (police.tick_floors(), police.tick_warrant()).
 */

/// A person with a mind on `where`
/datum/unit_test/voidcrew_outpost_floors/proc/police_test_person(turf/where)
	var/mob/living/carbon/human/consistent/person = test_person(where)
	person.mind_initialize()
	return person

/// `floor` gets an owner, and `members` (people with minds) become its residents: the floor's own people
/datum/unit_test/voidcrew_outpost_floors/proc/police_test_owned(datum/outpost_floor/floor, list/mob/living/members)
	floor.host.founder_ckey = "floorpolicetestowner"
	for(var/mob/living/member as anything in members)
		floor.host.residents |= member.mind

/// The heat `who` has with `police`, 0 with no warrant
/datum/unit_test/voidcrew_outpost_floors/proc/police_test_heat(datum/outpost_police/police, mob/living/who)
	var/datum/outpost_warrant/warrant = police.warrants[who.mind]
	return warrant ? warrant.heat : 0

/// An officer of `outpost`'s police at `where`
/datum/unit_test/voidcrew_outpost_floors/proc/police_test_officer(obj/structure/overmap/trader_outpost/outpost, turf/where)
	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/officer = allocate(/mob/living/carbon/human/npc/ambient_npc/outpost/police/beat, where)
	outpost.police.add_officer(officer)
	return officer

/// An attack on a visitor on an Open floor reaches the police through the victim and through the panel; on an Invited floor it does not (A55, L8)
/datum/unit_test/voidcrew_outpost_floors/police_open_attack

/datum/unit_test/voidcrew_outpost_floors/police_open_attack/Run()
	var/obj/structure/overmap/trader_outpost/outpost = test_outpost()
	var/datum/outpost_police/police = outpost.police
	var/datum/outpost_floor/floor = test_floor(outpost, 1, 30, 12, with_host = TRUE)
	if(!floor)
		return
	police_test_owned(floor, list())
	floor.entry_policy = "open" // OUTPOST_FLOOR_ENTRY_OPEN
	police.tick_floors()
	TEST_ASSERT(floor.public_ground, "An Open floor is not public ground after a tick")
	TEST_ASSERT_EQUAL(get_trader_outpost_for_turf(deck_tile(floor, 4)), outpost, "An Open floor is not the outpost's ground")
	TEST_ASSERT_EQUAL(police.sector_of(deck_tile(floor, 4)), floor, "An Open floor is not a police sector")

	// The victim sees it
	var/mob/living/carbon/human/victim = police_test_person(deck_tile(floor, 4))
	var/mob/living/carbon/human/attacker = police_test_person(deck_tile(floor, 5))
	GLOB.outpost_pvp_enforcement.register_pvp_aggression(victim, attacker, "unarmed") // OUTPOST_CRIME_ASSAULT_UNARMED
	TEST_ASSERT(police_test_heat(police, attacker) > 0, "An attack on a visitor in sight of them on an Open floor did not reach the police")

	// The panel sees it: the victim is too far off to see who did it
	var/obj/machinery/outpost_elevator/panel = allocate(/obj/machinery/outpost_elevator, floor_tile(floor, 22, 2))
	floor.panel = panel
	TEST_ASSERT(panel in police.floor_cameras(), "A public floor's panel is not a witness")
	var/mob/living/carbon/human/far_victim = police_test_person(deck_tile(floor, 2))
	var/mob/living/carbon/human/far_attacker = police_test_person(floor_tile(floor, 22, 4))
	GLOB.outpost_pvp_enforcement.register_pvp_aggression(far_victim, far_attacker, "unarmed") // OUTPOST_CRIME_ASSAULT_UNARMED
	TEST_ASSERT(police_test_heat(police, far_attacker) > 0, "An attack seen by a public floor's panel did not reach the police")

	// An Invited floor that was never Open is private
	var/datum/outpost_floor/invited = test_floor(outpost, 2, with_host = TRUE)
	if(!invited)
		return
	police_test_owned(invited, list())
	invited.entry_policy = "invited" // OUTPOST_FLOOR_ENTRY_INVITED
	invited.panel = allocate(/obj/machinery/outpost_elevator, floor_tile(invited, 6, 2))
	police.tick_floors()
	TEST_ASSERT(!invited.public_ground, "An Invited floor is public ground")
	TEST_ASSERT(!(invited.panel in police.floor_cameras()), "A private floor's panel is a witness")
	var/mob/living/carbon/human/guest = police_test_person(deck_tile(invited, 4))
	var/mob/living/carbon/human/host_hand = police_test_person(deck_tile(invited, 5))
	GLOB.outpost_pvp_enforcement.register_pvp_aggression(guest, host_hand, "unarmed") // OUTPOST_CRIME_ASSAULT_UNARMED
	TEST_ASSERT_EQUAL(police_test_heat(police, host_hand), 0, "An attack on an Invited floor reached the police")

/// Narrowing an Open floor: a visitor, a guest, a hand or a body upstairs keeps it public, and so does one of its people wanted here (A56, A78, L38)
/datum/unit_test/voidcrew_outpost_floors/police_narrowing

/datum/unit_test/voidcrew_outpost_floors/police_narrowing/Run()
	var/obj/structure/overmap/trader_outpost/outpost = test_outpost()
	var/datum/outpost_police/police = outpost.police
	var/datum/outpost_floor/floor = test_floor(outpost, 1, with_host = TRUE)
	if(!floor)
		return
	var/mob/living/carbon/human/member = police_test_person(deck_tile(floor, 2))
	police_test_owned(floor, list(member))
	TEST_ASSERT(floor.is_member(member), "A resident is not one of the floor's own people")
	floor.entry_policy = "open" // OUTPOST_FLOOR_ENTRY_OPEN
	police.tick_floors()
	TEST_ASSERT(floor.public_ground, "An Open floor is not public ground")
	TEST_ASSERT(police.floors_have_work(), "An Open floor gives the police nothing to do")

	floor.entry_policy = "crew" // OUTPOST_FLOOR_ENTRY_CREW
	police.tick_floors()
	TEST_ASSERT(floor.public_ground, "A floor went private the moment it was narrowed")
	var/long_ago = world.time - (2 MINUTES) - 1 // OUTPOST_FLOOR_CLOSING_TIME

	for(var/kind in list("a visitor", "a guest", "a hired hand", "a dead visitor"))
		var/mob/living/carbon/human/stranger = police_test_person(deck_tile(floor, 6))
		switch(kind)
			if("a guest")
				floor.guests += stranger.mind
			if("a hired hand")
				floor.hands += stranger.mind
			if("a dead visitor")
				stranger.death()
		TEST_ASSERT(stranger in floor.visitors_upstairs(), "[kind] upstairs is not a visitor")
		floor.police_narrowed_at = long_ago
		police.tick_floors()
		TEST_ASSERT(floor.public_ground, "A narrowed floor went private with [kind] still upstairs")
		floor.guests -= stranger.mind
		floor.hands -= stranger.mind
		qdel(stranger)

	TEST_ASSERT(!(member in floor.visitors_upstairs()), "One of the floor's own people is counted as a visitor")
	var/datum/outpost_warrant/warrant = police_pin_warrant(police, member.mind, 10) // one star
	floor.police_narrowed_at = long_ago
	police.tick_floors()
	TEST_ASSERT(floor.public_ground, "A narrowed floor went private while one of its people is wanted here")

	warrant.heat = 0
	floor.police_narrowed_at = long_ago
	police.tick_floors()
	TEST_ASSERT(!floor.public_ground, "A narrowed, empty floor did not go private after the closing time")
	TEST_ASSERT_NULL(get_trader_outpost_for_turf(deck_tile(floor, 4)), "A private floor is still the outpost's ground")

	floor.entry_policy = "open" // OUTPOST_FLOOR_ENTRY_OPEN
	police.tick_floors()
	TEST_ASSERT(floor.public_ground, "Opening a floor is not at once")

/// Someone up on a public floor is at the outpost by law, but on a floor, which the two "is a player here" tests leave out (A71)
/datum/unit_test/voidcrew_outpost_floors/police_shopkeeper_upstairs

/datum/unit_test/voidcrew_outpost_floors/police_shopkeeper_upstairs/Run()
	var/obj/structure/overmap/trader_outpost/outpost = test_outpost()
	var/datum/outpost_police/police = outpost.police
	var/datum/outpost_floor/floor = test_floor(outpost, 1, with_host = TRUE)
	if(!floor)
		return
	var/mob/living/carbon/human/shopkeeper = police_test_person(deck_tile(floor, 3))
	police_test_owned(floor, list(shopkeeper))
	floor.entry_policy = "open" // OUTPOST_FLOOR_ENTRY_OPEN
	police.tick_floors()
	TEST_ASSERT(police.dispatch_at_outpost(shopkeeper), "Someone on a public floor is not at the outpost by law")
	TEST_ASSERT_NOTNULL(get_outpost_floor_for_turf(get_turf(shopkeeper)), "The shopkeeper's tile is not on a floor")
	// Both loops below also need a real client, which a test cannot give: they pass here on the floor check or the client check
	TEST_ASSERT(!(shopkeeper in police.dispatch_players_at_outpost()), "A shopkeeper upstairs keeps the squad at the outpost")
	TEST_ASSERT(!outpost.recovery || !outpost.recovery.player_at_outpost(), "A shopkeeper upstairs holds up the unseen cleanup")

/// Riding up is not leaving: five stars keep their heat on a private floor and two stars fade by the hiding clock (A19, L10)
/datum/unit_test/voidcrew_outpost_floors/police_heat_upstairs

/datum/unit_test/voidcrew_outpost_floors/police_heat_upstairs/Run()
	var/obj/structure/overmap/trader_outpost/outpost = test_outpost()
	var/datum/outpost_police/police = outpost.police
	var/datum/outpost_floor/floor = test_floor(outpost, 1, with_host = TRUE)
	if(!floor)
		return
	police_test_owned(floor, list())
	var/mob/living/carbon/human/killer = police_test_person(deck_tile(floor, 2))
	var/mob/living/carbon/human/brawler = police_test_person(deck_tile(floor, 8))
	var/datum/outpost_warrant/hot = police_pin_warrant(police, killer.mind, 140) // five stars
	var/datum/outpost_warrant/mild = police_pin_warrant(police, brawler.mind, 30) // two stars
	var/long_ago = world.time - (45 SECONDS) - 1 // OUTPOST_POLICE_HIDE_2
	hot.unseen_since = long_ago
	mild.unseen_since = long_ago
	for(var/i in 1 to 3)
		police.tick_warrant(hot)
		police.tick_warrant(mild)
	TEST_ASSERT_EQUAL(hot.away_since, 0, "A suspect on a floor of the outpost is away")
	TEST_ASSERT_EQUAL(hot.heat, 140, "A five-star suspect who rode up lost heat")
	TEST_ASSERT_EQUAL(mild.away_since, 0, "A two-star suspect on a floor of the outpost is away")
	TEST_ASSERT(mild.heat < 30, "A two-star suspect hidden on a private floor did not fade")

/// A warrant starts with a 3+ star suspect on a private floor, makes it the outpost's ground and a sector, and always ends (L12, A51)
/datum/unit_test/voidcrew_outpost_floors/police_warrant

/datum/unit_test/voidcrew_outpost_floors/police_warrant/Run()
	var/obj/structure/overmap/trader_outpost/outpost = test_outpost()
	var/datum/outpost_police/police = outpost.police
	var/datum/outpost_floor/floor = test_floor(outpost, 1, with_host = TRUE)
	var/datum/turf_reservation/elsewhere = test_ground()
	if(!floor || !elsewhere)
		return
	police_test_owned(floor, list())
	var/turf/away = elsewhere.bottom_left_turfs[1]
	var/turf/deck = deck_tile(floor, 4)
	floor.panel = allocate(/obj/machinery/outpost_elevator, floor_tile(floor, 3, 2))
	var/mob/living/carbon/human/suspect = police_test_person(deck)
	var/datum/outpost_warrant/warrant = police_pin_warrant(police, suspect.mind, 25) // two stars
	police.tick_floors()
	TEST_ASSERT(!floor.warrant_in_force, "Two stars put a warrant on a floor")

	warrant.heat = 50 // three stars
	police.tick_floors()
	TEST_ASSERT(floor.warrant_in_force, "A three-star suspect on a private floor put no warrant there")
	TEST_ASSERT_EQUAL(get_trader_outpost_for_turf(deck), outpost, "A floor under warrant is not the outpost's ground")
	TEST_ASSERT_EQUAL(police.sector_of(deck), floor, "A floor under warrant is not a police sector")
	TEST_ASSERT_EQUAL(length(police.dispatch_lift_tiles(floor)), length(floor.alcove_turfs), "A floor sector's lift tiles are not its alcove")
	TEST_ASSERT(police.dispatch_is_lift_tile(floor.alcove_turfs[1]), "A floor's alcove is no lift tile under warrant")
	TEST_ASSERT(floor.panel in police.floor_cameras(), "A floor's panel is no witness under warrant")
	TEST_ASSERT(floor.contains_turf(warrant.last_seen_turf), "The police do not know which floor the suspect went to")
	TEST_ASSERT(police.floors_have_work(), "A warrant on a floor gives the police nothing to do")
	TEST_ASSERT(!floor.public_ground, "A warrant made a private floor public ground")

	// The suspect leaves: the warrant holds for the tail, then ends with nobody up there
	suspect.forceMove(away)
	police.tick_floors()
	TEST_ASSERT(floor.warrant_in_force, "A warrant ended the moment the suspect left")
	floor.police_suspect_at = world.time - (60 SECONDS) - 1 // POLICE_FLOOR_WARRANT_TAIL
	police.tick_floors()
	TEST_ASSERT(!floor.warrant_in_force, "A warrant outlived its tail with nobody up there")
	TEST_ASSERT_NULL(get_trader_outpost_for_turf(deck), "A private floor is still the outpost's ground after its warrant")
	TEST_ASSERT_EQUAL(police.sector_of(deck), "outside", "A private floor is still a sector after its warrant") // POLICE_SECTOR_OUTSIDE

	// An officer still up there holds it, five minutes at most
	suspect.forceMove(deck)
	police.tick_floors()
	TEST_ASSERT(floor.warrant_in_force, "A warrant did not start again")
	police_test_officer(outpost, deck_tile(floor, 8))
	suspect.forceMove(away)
	floor.police_suspect_at = world.time - (60 SECONDS) - 1 // POLICE_FLOOR_WARRANT_TAIL
	police.tick_floors()
	TEST_ASSERT(floor.police_stood_down_at > 0, "The squad was not stood down after the tail")
	TEST_ASSERT(floor.warrant_in_force, "A warrant ended with an officer still up there")
	floor.police_stood_down_at = world.time - (5 MINUTES) - 1 // POLICE_FLOOR_WARRANT_MAX_TAIL
	police.tick_floors()
	TEST_ASSERT(!floor.warrant_in_force, "A warrant outlived five minutes after the squad stood down")

	// A floor that loses its ground under warrant loses the warrant
	suspect.forceMove(deck)
	police.tick_floors()
	TEST_ASSERT(floor.warrant_in_force, "A warrant did not start a third time")
	suspect.forceMove(away)
	floor.leave_ground()
	TEST_ASSERT(!floor.warrant_in_force && !floor.public_ground, "A floor that lost its ground kept its police flags")
	police.tick_floors()
	TEST_ASSERT(!floor.warrant_in_force, "A floor with no ground has a warrant after a tick")

/// Under warrant a floor's doors open for an outpost officer, never for a card in a player's hand (A42)
/datum/unit_test/voidcrew_outpost_floors/police_doors

/datum/unit_test/voidcrew_outpost_floors/police_doors/Run()
	var/obj/structure/overmap/trader_outpost/outpost = test_outpost()
	var/datum/outpost_police/police = outpost.police
	var/datum/outpost_floor/floor = test_floor(outpost, 1, with_host = TRUE)
	if(!floor)
		return
	police_test_owned(floor, list())
	var/obj/machinery/door/airlock/door = allocate(/obj/machinery/door/airlock, deck_tile(floor, 6))
	door.req_access = list(ACCESS_CENT_GENERAL)
	var/mob/living/carbon/human/suspect = police_test_person(deck_tile(floor, 2))
	police_pin_warrant(police, suspect.mind, 90) // four stars
	police.tick_floors()
	TEST_ASSERT(floor.warrant_in_force, "No warrant on the floor")

	var/mob/living/carbon/human/raider = police_test_person(deck_tile(floor, 5))
	var/obj/item/card/id/advanced/silver/card = allocate(/obj/item/card/id/advanced/silver)
	card.access = list(ACCESS_SECURITY, ACCESS_BRIG, ACCESS_ARMORY)
	raider.put_in_hands(card)
	TEST_ASSERT(!police_floor_door_override(door, raider), "A security card in a player's hand passes the officers' door rule")
	TEST_ASSERT(!door.allowed(raider), "A security card in a player's hand opened a door on a floor under warrant")

	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/officer = police_test_officer(outpost, deck_tile(floor, 7))
	TEST_ASSERT(police_floor_door_override(door, officer), "An officer does not pass a door on a floor under warrant")
	TEST_ASSERT(door.allowed(officer), "A door on a floor under warrant refused an officer")
	floor.warrant_in_force = FALSE
	TEST_ASSERT(!police_floor_door_override(door, officer), "An officer passes a floor's doors with no warrant")

/// Carrying someone up who had no say, or forcing the panel, is seen where the car left from when that is the outpost's ground (A17, L13)
/datum/unit_test/voidcrew_outpost_floors/police_lift_crimes

/datum/unit_test/voidcrew_outpost_floors/police_lift_crimes/Run()
	var/obj/structure/overmap/trader_outpost/outpost = test_outpost()
	var/datum/outpost_police/police = outpost.police
	var/datum/outpost_floor/open_floor = test_floor(outpost, 1, with_host = TRUE)
	var/datum/outpost_floor/crew_floor = test_floor(outpost, 2, with_host = TRUE)
	if(!open_floor || !crew_floor)
		return
	police_test_owned(open_floor, list())
	police_test_owned(crew_floor, list())
	open_floor.entry_policy = "open" // OUTPOST_FLOOR_ENTRY_OPEN
	open_floor.panel = allocate(/obj/machinery/outpost_elevator, floor_tile(open_floor, 4, 2))
	crew_floor.panel = allocate(/obj/machinery/outpost_elevator, floor_tile(crew_floor, 4, 2))
	police.tick_floors()
	TEST_ASSERT(open_floor.public_ground && !crew_floor.public_ground, "The two floors are not public and private")
	var/turf/left_public = open_floor.alcove_turfs[2]
	var/turf/left_private = crew_floor.alcove_turfs[2]
	var/mob/living/carbon/human/victim = police_test_person(deck_tile(crew_floor, 4))

	// Seen: the car left public ground in sight of its panel. The offender is upstairs on a private floor by now.
	var/mob/living/carbon/human/kidnapper = police_test_person(deck_tile(crew_floor, 3))
	police.floor_lift_report(kidnapper, "abduction", left_public, victim) // OUTPOST_CRIME_ABDUCTION
	TEST_ASSERT(police.get_stars(kidnapper.mind) >= 3, "An abduction seen at a public alcove is not three stars")
	var/mob/living/carbon/human/tamperer = police_test_person(deck_tile(crew_floor, 6))
	police.floor_lift_report(tamperer, "lift_tamper", get_turf(open_floor.panel), null) // OUTPOST_CRIME_LIFT_TAMPER
	TEST_ASSERT(police.get_stars(tamperer.mind) >= 2, "Forcing a public floor's panel in its sight is not two stars")

	// Unseen: private ground, panel or not
	var/mob/living/carbon/human/private_kidnapper = police_test_person(deck_tile(crew_floor, 8))
	police.floor_lift_report(private_kidnapper, "abduction", left_private, victim) // OUTPOST_CRIME_ABDUCTION
	TEST_ASSERT_EQUAL(police_test_heat(police, private_kidnapper), 0, "An abduction from a private floor counted")
	var/mob/living/carbon/human/private_tamperer = police_test_person(deck_tile(crew_floor, 9))
	police.floor_lift_report(private_tamperer, "lift_tamper", get_turf(crew_floor.panel), null) // OUTPOST_CRIME_LIFT_TAMPER
	TEST_ASSERT_EQUAL(police_test_heat(police, private_tamperer), 0, "Forcing a private floor's panel counted")

	// Unseen: public ground with no witness
	qdel(open_floor.panel)
	open_floor.panel = null
	var/mob/living/carbon/human/quiet_kidnapper = police_test_person(deck_tile(crew_floor, 10))
	police.floor_lift_report(quiet_kidnapper, "abduction", left_public, victim) // OUTPOST_CRIME_ABDUCTION
	TEST_ASSERT_EQUAL(police_test_heat(police, quiet_kidnapper), 0, "An abduction nobody saw counted")

/// Hitting a floor's fitting is vandalism on public ground by a stranger, and nothing for the floor's own people or on a private floor (L39)
/datum/unit_test/voidcrew_outpost_floors/police_fitting_hit

/datum/unit_test/voidcrew_outpost_floors/police_fitting_hit/Run()
	var/obj/structure/overmap/trader_outpost/outpost = test_outpost()
	var/datum/outpost_police/police = outpost.police
	var/datum/outpost_floor/floor = test_floor(outpost, 1, with_host = TRUE)
	if(!floor)
		return
	var/mob/living/carbon/human/member = police_test_person(deck_tile(floor, 3))
	police_test_owned(floor, list(member))
	floor.entry_policy = "open" // OUTPOST_FLOOR_ENTRY_OPEN
	floor.panel = allocate(/obj/machinery/outpost_elevator, floor_tile(floor, 4, 2))
	police.tick_floors()
	var/obj/structure/table/fitting = allocate(/obj/structure/table, deck_tile(floor, 5))
	var/mob/living/carbon/human/stranger = police_test_person(deck_tile(floor, 6))
	police.floor_fitting_hit(member, fitting, null)
	TEST_ASSERT_EQUAL(police_test_heat(police, member), 0, "One of the floor's own people hitting its fitting is a crime")
	police.floor_fitting_hit(stranger, fitting, null)
	TEST_ASSERT(police_test_heat(police, stranger) > 0, "A stranger hitting a fitting on public ground in sight of the panel is no crime")

	floor.entry_policy = "crew" // OUTPOST_FLOOR_ENTRY_CREW
	floor.public_ground = FALSE
	var/mob/living/carbon/human/private_stranger = police_test_person(deck_tile(floor, 8))
	police.floor_fitting_hit(private_stranger, fitting, null)
	TEST_ASSERT_EQUAL(police_test_heat(police, private_stranger), 0, "Hitting a fitting on a private floor is a crime")

/// The morgue crew takes a visitor's body from a floor whoever of the floor stands by, but not one of the floor's own beside a crewmate
/datum/unit_test/voidcrew_outpost_floors/police_floor_bodies

/datum/unit_test/voidcrew_outpost_floors/police_floor_bodies/Run()
	var/obj/structure/overmap/trader_outpost/outpost = test_outpost()
	var/datum/outpost_recovery/recovery = outpost.ensure_recovery()
	var/datum/outpost_floor/floor = test_floor(outpost, 1, with_host = TRUE)
	if(!floor || !recovery)
		return
	var/mob/living/carbon/human/member = police_test_person(deck_tile(floor, 3))
	var/mob/living/carbon/human/dead_member = police_test_person(deck_tile(floor, 4))
	var/mob/living/carbon/human/dead_visitor = police_test_person(floor_tile(floor, 4, 6))
	police_test_owned(floor, list(member, dead_member))
	member.mock_client = allocate(/datum/client_interface)
	dead_member.death()
	dead_visitor.death()
	TEST_ASSERT(recovery.floor_body_free(dead_visitor, get_turf(dead_visitor)), "The floor's crew standing by kept a visitor's body from the morgue crew")
	TEST_ASSERT(!recovery.floor_body_free(dead_member, get_turf(dead_member)), "The morgue crew took one of the floor's own from beside a crewmate")
	member.forceMove(floor_tile(floor, 12, 9))
	TEST_ASSERT(recovery.floor_body_free(dead_member, get_turf(dead_member)), "One of the floor's own with nobody beside them was not free to take")
	member.mock_client = null

/// A blast on public ground breaks a crew-built wall and is an attack on whoever it catches (A75, L28)
/datum/unit_test/voidcrew_outpost_floors/police_public_blast

/datum/unit_test/voidcrew_outpost_floors/police_public_blast/Run()
	var/obj/structure/overmap/trader_outpost/outpost = test_outpost()
	var/datum/outpost_police/police = outpost.police
	var/datum/outpost_floor/floor = test_floor(outpost, 1, with_host = TRUE)
	if(!floor)
		return
	police_test_owned(floor, list())
	floor.entry_policy = "open" // OUTPOST_FLOOR_ENTRY_OPEN
	police.tick_floors()
	floor.lay_ground(/turf/open/floor/plating/outpost_deck)
	// The blast is set on the wall, as a breaching charge is: devastation 1 reaches its own tile only
	var/turf/crew_wall = floor_tile(floor, 6, 6)
	var/turf/epicenter = crew_wall
	crew_wall.place_on_top(/turf/closed/wall)
	var/mob/living/carbon/human/caught = police_test_person(floor_tile(floor, 6, 7))
	TEST_ASSERT(!is_trader_outpost_protected(crew_wall), "A public floor is blast-protected")
	TEST_ASSERT(caught in note_outpost_blast_victims(get_turf(caught), null), "Someone caught by a blast on public ground is not its victim")
	hold_blasts()
	// The size of a breaching charge: devastation 1, heavy 0, light 2
	explosion(epicenter, devastation_range = 1, heavy_impact_range = 0, light_impact_range = 2, flame_range = 0, flash_range = 0, adminlog = FALSE, ignorecap = TRUE, silent = TRUE)
	apply_blast()
	TEST_ASSERT(!istype(crew_wall, /turf/closed/wall), "A blast on a public floor left a crew-built wall standing")
