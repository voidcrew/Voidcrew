/**
 * Outpost police tests: the warden (police_units.dm, owner decision 65) and his price (police_bribe.dm, decision 64).
 * Built on the cell tests' fixture (voidcrew_outpost_police_cell.dm). Fork defines are included after the tests: use
 * literal values with a comment naming the define.
 */

/datum/outpost_police/cell_test
	/// What charge_crew() answers: TRUE takes the money
	var/crew_charge_ok = FALSE
	/// Times charge_crew() was asked, and what for
	var/list/crew_charges = list()
	/// Times refund_crew() gave money back
	var/crew_refunds = 0
	/// What stealth_anyone_at_large() answers
	var/pinned_at_large = FALSE

/datum/outpost_police/cell_test/charge_crew(datum/outpost_warrant/warrant, amount, reason)
	crew_charges += amount
	return crew_charge_ok ? list("test account" = amount) : null

/datum/outpost_police/cell_test/refund_crew(list/taken, reason)
	crew_refunds++

/datum/outpost_police/cell_test/stealth_anyone_at_large()
	return pinned_at_large

/// A jailed prisoner in cell "a" at `stars`, and the warden standing outside its door. list(police, cell, prisoner, warden)
/datum/unit_test/proc/police_bribe_fixture(stars = 3, jail_term = TRUE)
	var/datum/outpost_police/cell_test/police = police_cells_fixture()
	police.pinned_stars = stars
	var/datum/outpost_police_cell/cell = police_cell_named(police, "a")
	var/mob/living/carbon/human/prisoner = police_cell_person(cell.tiles[1])
	police_pin_warrant(police, prisoner.mind, 12)
	cell.admit(prisoner, world.time + 3000, jail_term)
	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/sergeant/warden = allocate(/mob/living/carbon/human/npc/ambient_npc/outpost/police/sergeant, cell.outside_turf)
	warden.police = police
	return list(police, cell, prisoner, warden)

/// The cell guard is a warden: his title, card and each zone's outfit
/datum/unit_test/voidcrew_outpost_police_warden_kit

/datum/unit_test/voidcrew_outpost_police_warden_kit/Run()
	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/sergeant/warden = allocate(/mob/living/carbon/human/npc/ambient_npc/outpost/police/sergeant, run_loc_floor_bottom_left)
	TEST_ASSERT_EQUAL(warden.unit_title(), "Warden", "The cell guard is not called a warden")
	TEST_ASSERT(findtext(warden.desc, "Warden"), "The cell guard's description does not say warden: [warden.desc]")
	var/obj/item/card/id/advanced/outpost_sergeant/card = warden.wear_id
	TEST_ASSERT(istype(card), "The warden wears no cell card")
	TEST_ASSERT_EQUAL(card.assignment, "Warden", "The warden's card does not say warden")
	TEST_ASSERT(findtext(card.name, "Warden"), "The warden's card is not named for a warden: [card.name]")
	TEST_ASSERT(!findtext(lowertext(card.name), "sergeant"), "The warden's card still says sergeant: [card.name]")
	var/list/zones = list(
		/datum/outpost_police_profile/halcyon = /obj/item/clothing/under/rank/security/warden/formal,
		/datum/outpost_police_profile/quartermain = /obj/item/clothing/under/rank/security/warden/grey,
		/datum/outpost_police_profile/undertow = /obj/item/clothing/under/syndicate,
	)
	var/turf/spot = locate(run_loc_floor_bottom_left.x + 2, run_loc_floor_bottom_left.y, run_loc_floor_bottom_left.z)
	for(var/profile_type in zones)
		var/datum/outpost_police_profile/profile = new profile_type
		var/outfit_type = profile.outfits["sergeant"] // POLICE_UNIT_SERGEANT
		qdel(profile)
		TEST_ASSERT(ispath(outfit_type, /datum/outfit/outpost_police/sergeant), "[profile_type] dresses its warden in [outfit_type]")
		var/mob/living/carbon/human/dummy = allocate(/mob/living/carbon/human/consistent, spot)
		dummy.equipOutfit(outfit_type)
		TEST_ASSERT(istype(dummy.w_uniform, zones[profile_type]), "[profile_type]'s warden wears [dummy.w_uniform?.type]")
		TEST_ASSERT(istype(dummy.head, /obj/item/clothing/head/hats/warden), "[profile_type]'s warden wears no warden's hat ([dummy.head?.type])")
		var/obj/item/card/id/dummy_card = dummy.wear_id
		TEST_ASSERT(istype(dummy_card, /obj/item/card/id/advanced/outpost_sergeant) && dummy_card.assignment == "Warden", "[profile_type]'s warden has no warden's card")

/// Every zone has the warden's lines; the offer always names the price and nothing else carries a token
/datum/unit_test/voidcrew_outpost_police_bribe_lines

/datum/unit_test/voidcrew_outpost_police_bribe_lines/Run()
	for(var/section in list("halcyon", "quartermain", "undertow"))
		for(var/kind in list("bribe_coming", "bribe_offer", "bribe_taken", "bribe_short", "bribe_no_card", "bribe_door")) // POLICE_LINE_BRIBE_*
			var/list/lines = ambient_dialogue_lines("outpost_police.json", section, kind) // AMBIENT_STRINGS_POLICE
			TEST_ASSERT(length(lines) >= 4, "[section] has [length(lines)] lines for [kind], not 4 or more")
			for(var/line in lines)
				TEST_ASSERT(!(copytext(line, 1, 2) in list(".", ":", ";", "#", "*", "%")), "[section] [kind]: '[line]' starts like a radio key")
				if(kind == "bribe_offer")
					TEST_ASSERT(findtext(line, "%PRICE%"), "[section]: the offer '[line]' names no price")
				else
					TEST_ASSERT(!findtext(line, "%"), "[section] [kind]: '[line]' carries a token")
	TEST_ASSERT_EQUAL(outpost_police_fill_line("%PRICE% credits.", list("price" = "1,500")), "1,500 credits.", "The price was not filled in")
	TEST_ASSERT_NULL(outpost_police_fill_line("%PRICE% credits.", list()), "An offer was said with no price")
	TEST_ASSERT_EQUAL(outpost_police_price_text(1500), "1,500", "1500 is not written 1,500")
	TEST_ASSERT_EQUAL(outpost_police_price_text(750), "750", "750 is not written 750")

/// The price: 500 cr a star times the zone, never under 1,500
/datum/unit_test/voidcrew_outpost_police_bribe_price

/datum/unit_test/voidcrew_outpost_police_bribe_price/Run()
	var/datum/outpost_police/cell_test/police = police_cells_fixture()
	var/mob/living/carbon/human/person = police_cell_person(run_loc_floor_bottom_left)
	var/datum/mind/mind = person.mind
	police_pin_warrant(police, mind, 12)
	var/list/expected = list(
		/datum/outpost_police_profile/halcyon = list(1500, 1500, 1500, 2000, 2500),
		/datum/outpost_police_profile/quartermain = list(1500, 1500, 2250, 3000, 3750),
		/datum/outpost_police_profile/undertow = list(1500, 2000, 3000, 4000, 5000),
	)
	var/datum/outpost_police_profile/old_profile = police.profile
	for(var/profile_type in expected)
		police.profile = new profile_type
		var/list/prices = expected[profile_type]
		for(var/stars in 1 to 5)
			police.pinned_stars = stars
			TEST_ASSERT_EQUAL(police.bribe_price(mind), prices[stars], "[profile_type] at [stars] stars")
		qdel(police.profile)
	police.profile = old_profile

/// A knock from a jailed prisoner brings the warden over and makes one offer at the price; paying with money lets them out once
/datum/unit_test/voidcrew_outpost_police_bribe_paid

/datum/unit_test/voidcrew_outpost_police_bribe_paid/Run()
	var/list/fixture = police_bribe_fixture(4)
	var/datum/outpost_police/cell_test/police = fixture[1]
	var/datum/outpost_police_cell/cell = fixture[2]
	var/mob/living/carbon/human/prisoner = fixture[3]
	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/sergeant/warden = fixture[4]
	TEST_ASSERT(cell.door.density, "Setup: the cell door is open")
	TEST_ASSERT(warden.bribe_heard(prisoner), "The warden did not answer a jailed prisoner's call")
	var/datum/ambient_activity/warden_bribe/visit = warden.activity
	TEST_ASSERT(istype(visit), "The warden is not going to the cell door")
	if(visit.spot != cell.outside_turf)
		TEST_FAIL("The warden is going to [visit.spot] ([visit.spot?.x], [visit.spot?.y]), not the cell door ([cell.outside_turf.x], [cell.outside_turf.y])")
	visit.arrived = TRUE
	visit.arrive()
	TEST_ASSERT_EQUAL(police.bribe_offers[prisoner.mind], 2000, "The warden did not name 2,000 at four stars") // OUTPOST_POLICE_BRIBE_PER_STAR * 4
	TEST_ASSERT(police.bribe_wait[prisoner.mind] > world.time + 50 SECONDS, "An offer set no wait before the next") // OUTPOST_POLICE_BRIBE_WAIT
	TEST_ASSERT(warden.bribe_heard(prisoner) && warden.activity == visit, "A second call while he stands there started another visit")
	TEST_ASSERT_EQUAL(length(police.bribe_offers), 1, "A second call made a second offer")

	police.crew_charge_ok = TRUE
	TEST_ASSERT(police.bribe_answer(warden, prisoner, cell, TRUE), "Paying the warden did not let the prisoner out")
	TEST_ASSERT_EQUAL(length(police.crew_charges), 1, "Paying charged [length(police.crew_charges)] times, not once")
	TEST_ASSERT_EQUAL(police.crew_charges[1], 2000, "Paying charged [police.crew_charges[1]], not the price named")
	TEST_ASSERT_EQUAL(police.crew_refunds, 0, "A good payment was refunded")
	TEST_ASSERT(!(prisoner.mind in cell.prisoners), "A prisoner who paid is still held")
	TEST_ASSERT(!police.in_custody(prisoner), "A prisoner who paid is still in custody")
	TEST_ASSERT_EQUAL(length(police.closed), 1, "Paying did not close the warrant once")
	TEST_ASSERT(police.closed[1][2], "Paying closed the warrant as not served")
	TEST_ASSERT(prisoner in police.released, "Paying sent no release signal (the property locker stays theirs)")
	TEST_ASSERT("bribe_taken" in police.lines, "The warden did not say he took it") // POLICE_LINE_BRIBE_TAKEN
	TEST_ASSERT(!cell.door.density, "The door did not open for a prisoner who paid")
	TEST_ASSERT(!istype(warden.activity, /datum/ambient_activity/warden_bribe), "The warden did not go back after the deal")
	TEST_ASSERT_EQUAL(length(police.crimes), 0, "Paying the warden reported a crime")
	TEST_ASSERT(!police.bribe_answer(warden, prisoner, cell, TRUE), "One offer was paid twice")
	TEST_ASSERT_EQUAL(length(police.crew_charges), 1, "A second answer charged again")

/// Pay with too little: nothing taken, still held, and he won't come straight back; No: the same
/datum/unit_test/voidcrew_outpost_police_bribe_short

/datum/unit_test/voidcrew_outpost_police_bribe_short/Run()
	var/list/fixture = police_bribe_fixture(3)
	var/datum/outpost_police/cell_test/police = fixture[1]
	var/datum/outpost_police_cell/cell = fixture[2]
	var/mob/living/carbon/human/prisoner = fixture[3]
	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/sergeant/warden = fixture[4]
	TEST_ASSERT(warden.bribe_heard(prisoner), "The warden did not answer a jailed prisoner's call")
	var/datum/ambient_activity/warden_bribe/visit = warden.activity
	visit.arrived = TRUE
	visit.arrive()
	TEST_ASSERT_EQUAL(police.bribe_offers[prisoner.mind], 1500, "The warden did not name 1,500 at three stars") // OUTPOST_POLICE_BRIBE_MIN
	police.crew_charge_ok = FALSE
	TEST_ASSERT(!police.bribe_answer(warden, prisoner, cell, TRUE), "A short payment let the prisoner out")
	TEST_ASSERT_EQUAL(length(police.crew_charges), 1, "A short payment was not tried once")
	TEST_ASSERT(prisoner.mind in cell.prisoners, "A prisoner who could not pay was let out")
	TEST_ASSERT(cell.jailed[prisoner.mind], "A prisoner who could not pay lost their term")
	TEST_ASSERT_EQUAL(length(police.closed), 0, "A short payment closed the warrant")
	TEST_ASSERT(cell.door.density, "The door opened on a short payment")
	TEST_ASSERT(!istype(warden.activity, /datum/ambient_activity/warden_bribe), "The warden did not go back after a short payment")

	// He won't come again for a minute, then will
	TEST_ASSERT(!warden.bribe_heard(prisoner), "The warden came straight back after a failed payment")
	TEST_ASSERT(!istype(warden.activity, /datum/ambient_activity/warden_bribe), "The warden set off again inside the wait")
	police.bribe_wait[prisoner.mind] = world.time
	TEST_ASSERT(warden.bribe_heard(prisoner), "The warden never came again after the wait")
	visit = warden.activity
	visit.arrived = TRUE
	visit.arrive()
	TEST_ASSERT(!police.bribe_answer(warden, prisoner, cell, FALSE), "Saying no let the prisoner out")
	TEST_ASSERT_EQUAL(length(police.crew_charges), 1, "Saying no charged the crew")
	TEST_ASSERT(prisoner.mind in cell.prisoners, "Saying no let the prisoner out")
	TEST_ASSERT(!warden.bribe_heard(prisoner), "The warden came straight back after a refusal")

/// No offer while anyone wanted is at large, to a prisoner in crit, from a warden without his card, or on a paid hold
/datum/unit_test/voidcrew_outpost_police_bribe_refused

/datum/unit_test/voidcrew_outpost_police_bribe_refused/Run()
	var/list/fixture = police_bribe_fixture(3)
	var/datum/outpost_police/cell_test/police = fixture[1]
	var/datum/outpost_police_cell/cell = fixture[2]
	var/mob/living/carbon/human/prisoner = fixture[3]
	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/sergeant/warden = fixture[4]

	police.pinned_at_large = TRUE
	TEST_ASSERT(!warden.bribe_heard(prisoner), "The warden came over while someone wanted was at large")
	TEST_ASSERT(!istype(warden.activity, /datum/ambient_activity/warden_bribe), "The warden set off while someone wanted was at large")
	police.pinned_at_large = FALSE

	var/obj/item/card/id/card = warden.wear_id
	TEST_ASSERT(warden.temporarilyRemoveItemFromInventory(card), "Setup: the warden's card would not come off")
	card.forceMove(cell.outside_turf)
	TEST_ASSERT(warden.bribe_heard(prisoner), "A warden without his card did not answer")
	TEST_ASSERT(!istype(warden.activity, /datum/ambient_activity/warden_bribe), "A warden without his card came over")
	TEST_ASSERT_EQUAL(length(police.bribe_offers), 0, "A warden without his card made an offer")
	TEST_ASSERT(police.bribe_wait[prisoner.mind] > world.time, "A warden without his card will be asked again at once")
	police.bribe_wait -= prisoner.mind
	warden.equip_to_slot_if_possible(card, ITEM_SLOT_ID, disable_warning = TRUE)

	// A paid hold is no jail term
	var/datum/outpost_police_cell/other = police_cell_named(police, "b")
	var/mob/living/carbon/human/held = police_cell_person(other.tiles[1])
	police_pin_warrant(police, held.mind, 12)
	other.admit(held, world.time + 300) // OUTPOST_POLICE_HOLDS, 30 SECONDS
	TEST_ASSERT_NULL(police.bribe_cell_for(held), "A prisoner on a paid hold could be bought out")
	TEST_ASSERT(!warden.bribe_heard(held), "The warden came over to a prisoner on a paid hold")

	// The jailed one still can
	TEST_ASSERT_EQUAL(police.bribe_cell_for(prisoner), cell, "Setup: the jailed prisoner could not be bought out")

	// In crit: no deal
	ADD_TRAIT(prisoner, TRAIT_CRITICAL_CONDITION, TRAIT_SOURCE_UNIT_TESTS)
	TEST_ASSERT_NULL(police.bribe_cell_for(prisoner), "A prisoner in crit could be bought out")
	TEST_ASSERT(!warden.bribe_heard(prisoner), "The warden came over to a prisoner in crit")
	REMOVE_TRAIT(prisoner, TRAIT_CRITICAL_CONDITION, TRAIT_SOURCE_UNIT_TESTS)
