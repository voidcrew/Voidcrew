/**
 * Outpost police tests: paying the checkpoint guard to be let back in, and asking him how long is left
 * (voidcrew/modules/outpost_police/police_payoff.dm). Built on the checkpoint tests' fixture
 * (voidcrew_trader_checkpoint.dm) and the wanted tests' people and ships (voidcrew_outpost_police_wanted.dm).
 * Fork defines are included after the tests: use literal values with a comment naming the define.
 */

/**
 * Bans `offender`'s crew at `police`'s outpost at `stars` (4 or 5) as a counted crime does, then leaves them as
 * someone who got away and whose stars faded: none now, the bar of a three star record, the ban still running.
 * Their warrant.
 */
/datum/unit_test/proc/payoff_ban(datum/outpost_police/police, mob/living/carbon/human/offender, stars = 4)
	var/datum/outpost_warrant/warrant = police_pin_warrant(police, offender.mind, stars >= 5 ? 150 : 100)
	police.escalate_incident(warrant, stars)
	warrant.heat = 0
	warrant.peak = 0
	warrant.barred_until = world.time + 15 MINUTES // OUTPOST_POLICE_BAR_TIME
	return warrant

/// Lets the guard answer `who` (or anyone) afresh: nothing on offer, no wait, nothing just said
/datum/unit_test/proc/payoff_fresh(datum/outpost_police/police, mob/living/carbon/human/npc/ambient_npc/outpost/trader/checkpoint_guard/guard)
	police.payoff_offers.Cut()
	police.payoff_wait.Cut()
	guard.speak_cooldown = 0

/// The price out to `who` now, or null
/datum/unit_test/proc/payoff_offered(datum/outpost_police/police, mob/living/who)
	var/list/offer = police.payoff_offers[WEAKREF(who.mind)]
	return offer ? offer[1] : null

// ===== THE WORDS =====

/// Every zone has the guard's lines; an offer always says how long and how much, the plain answer how long, and nothing is too long for the prompt
/datum/unit_test/voidcrew_outpost_police_payoff_lines

/datum/unit_test/voidcrew_outpost_police_payoff_lines/Run()
	// POLICE_LINE_PAYOFF_*: the tokens each kind must carry
	var/list/kinds = list(
		"payoff_offer" = list("%TIME%", "%PRICE%"),
		"payoff_time" = list("%TIME%"),
		"payoff_crew" = list(),
		"payoff_taken" = list(),
		"payoff_short" = list(),
	)
	// The longest thing he can say for each token
	var/list/longest = outpost_police_values(list("time" = "about three quarters of an hour", "price" = "512,000"))
	for(var/section in list("halcyon", "quartermain", "undertow"))
		for(var/kind in kinds)
			var/list/tokens = kinds[kind]
			var/list/lines = ambient_dialogue_lines("outpost_police.json", section, kind) // AMBIENT_STRINGS_POLICE
			TEST_ASSERT(length(lines) >= 4, "[section] has [length(lines)] lines for [kind], not 4 or more")
			for(var/line in lines)
				TEST_ASSERT(istext(line) && length(line), "[section] has an empty line for [kind]")
				TEST_ASSERT(!(copytext(line, 1, 2) in list(".", ":", ";", "#", "*", "%")), "[section] [kind]: '[line]' starts like a radio key")
				TEST_ASSERT(!findtext(line, "<") && !findtext(line, "{"), "[section] [kind]: '[line]' carries markup")
				for(var/token in list("%TIME%", "%PRICE%"))
					if(token in tokens)
						TEST_ASSERT(findtext(line, token), "[section] [kind]: '[line]' lacks [token]")
					else
						TEST_ASSERT(!findtext(line, token), "[section] [kind]: '[line]' carries [token]")
				var/filled = outpost_police_payoff_fill(line, longest)
				TEST_ASSERT(istext(filled) && !findtext(filled, "%"), "[section] [kind]: '[line]' was not filled in: '[filled]'")
				// The prompt shows the line whole: it must fit
				TEST_ASSERT(length(filled) <= 120, "[section] [kind]: '[filled]' is [length(filled)] characters, more than 120")
	TEST_ASSERT_NULL(outpost_police_payoff_fill("Back in %TIME%.", list("price" = "2,000")), "A line was said with no time to give")
	TEST_ASSERT_NULL(outpost_police_payoff_fill("%PRICE% credits, or %TIME%.", list("time" = "half an hour")), "An offer was said with no price")
	TEST_ASSERT_EQUAL(outpost_police_payoff_fill("Back in %TIME%. Or %PRICE% credits.", list("time" = "half an hour", "price" = "2,000")), "Back in half an hour. Or 2,000 credits.", "The time and the price were not filled in")

/// How long is left is said the way a person says it
/datum/unit_test/voidcrew_outpost_police_payoff_wait_text

/datum/unit_test/voidcrew_outpost_police_payoff_wait_text/Run()
	// seconds left -> what he says
	var/list/rows = list(
		list(20, "a minute or so"),
		list(90, "a minute or so"),
		list(150, "a couple of minutes"),
		list(5 * 60, "about five minutes"),
		list(7 * 60, "about five minutes"),
		list(8 * 60, "about ten minutes"),
		list(12 * 60, "about ten minutes"),
		list(13 * 60, "a quarter of an hour"),
		list(15 * 60, "a quarter of an hour"),
		list(20 * 60, "about twenty minutes"),
		list(25 * 60, "about twenty-five minutes"),
		list(28 * 60, "half an hour"),
		list(30 * 60, "half an hour"),
		list(45 * 60, "about three quarters of an hour"),
		list(60 * 60, "about an hour"),
		list(120 * 60, "a couple of hours"),
		list(600 * 60, "a good few hours"),
	)
	for(var/list/row as anything in rows)
		TEST_ASSERT_EQUAL(outpost_police_wait_text(row[1] SECONDS), row[2], "[row[1]] seconds left")

// ===== THE PRICE =====

/// 2,000 for a 15 minute ban, 4,000 for a 30 minute one, 1,000 for a bar alone, times the zone; nothing for someone wanted or someone nothing refuses
/datum/unit_test/voidcrew_outpost_police_payoff_price

/datum/unit_test/voidcrew_outpost_police_payoff_price/Run()
	var/obj/structure/overmap/trader_outpost/outpost = wanted_outpost()
	var/datum/outpost_police/police = outpost.police
	var/mob/living/carbon/human/offender = wanted_person(wanted_spot(0, 0))
	var/mob/living/carbon/human/loner = wanted_person(wanted_spot(1, 0))
	var/mob/living/carbon/human/clean = wanted_person(wanted_spot(2, 0))
	var/obj/structure/overmap/ship/ship = wanted_ship(offender)
	TEST_ASSERT_NULL(police.payoff_quote(clean), "Someone nothing refuses was quoted a price")
	TEST_ASSERT_NULL(police.payoff_quote(offender), "A crew with no ban was quoted a price")

	// OUTPOST_POLICE_PAYOFF_BAN, OUTPOST_POLICE_PAYOFF_BAR and each zone's fine multiplier (1, 1.5, 2)
	var/list/expected = list(
		/datum/outpost_police_profile/halcyon = list(2000, 4000, 1000),
		/datum/outpost_police_profile/quartermain = list(3000, 6000, 1500),
		/datum/outpost_police_profile/undertow = list(4000, 8000, 2000),
	)
	var/datum/outpost_warrant/bar = police_pin_warrant(police, loner.mind, 0)
	bar.barred_until = world.time + 6 MINUTES
	var/datum/outpost_warrant/warrant = payoff_ban(police, offender, 4)
	var/datum/outpost_incident/incident = police.incidents[offender.mind.get_reputation_crew()]
	TEST_ASSERT_NOTNULL(incident, "Fixture: four stars made no incident")
	var/datum/outpost_police_profile/old_profile = police.profile
	for(var/profile_type in expected)
		police.profile = new profile_type
		var/list/prices = expected[profile_type]
		incident.stars = 4
		var/list/quote = police.payoff_quote(offender)
		TEST_ASSERT_NOTNULL(quote, "[profile_type]: a banned crew member with no stars was quoted nothing")
		TEST_ASSERT_EQUAL(quote["kind"], "ban", "[profile_type]: a ban was quoted as [quote["kind"]]") // OUTPOST_POLICE_PAYOFF_KIND_BAN
		TEST_ASSERT_EQUAL(quote["price"], prices[1], "[profile_type]: a 15 minute ban")
		TEST_ASSERT_EQUAL(quote["stars"], 4, "[profile_type]: the quote does not say which ban")
		TEST_ASSERT_EQUAL(quote["left"], 15 MINUTES, "[profile_type]: a fresh four star ban does not have 15 minutes left") // OUTPOST_POLICE_EMBARGO
		incident.stars = 5
		quote = police.payoff_quote(offender)
		TEST_ASSERT_EQUAL(quote["price"], prices[2], "[profile_type]: a 30 minute ban")
		quote = police.payoff_quote(loner)
		TEST_ASSERT_NOTNULL(quote, "[profile_type]: a barred person with no stars was quoted nothing")
		TEST_ASSERT_EQUAL(quote["kind"], "bar", "[profile_type]: a bar was quoted as [quote["kind"]]") // OUTPOST_POLICE_PAYOFF_KIND_BAR
		TEST_ASSERT_EQUAL(quote["price"], prices[3], "[profile_type]: a bar alone")
		TEST_ASSERT_EQUAL(quote["left"], 6 MINUTES, "[profile_type]: the bar's time left")
		qdel(police.profile)
	police.profile = old_profile
	incident.stars = 4

	// The later of the bar and the ban is how long they wait
	warrant.barred_until = world.time + 20 MINUTES
	TEST_ASSERT_EQUAL(police.payoff_quote(offender)["left"], 20 MINUTES, "A bar that outlasts the ban was not the time left")
	// Wanted now: arrested, not served
	warrant.heat = 10
	TEST_ASSERT_NULL(police.payoff_quote(offender), "Someone with a star was quoted a price")
	warrant.heat = 0
	// A bar that has run out, and a ban that has: nothing to ask about
	bar.barred_until = world.time
	TEST_ASSERT_NULL(police.payoff_quote(loner), "A bar that ran out was quoted")
	warrant.barred_until = 0
	incident.ends_at = world.time
	outpost.embargoed_ships[ship] = world.time
	TEST_ASSERT_NULL(police.payoff_quote(offender), "A ban that ran out was quoted")
	wanted_cleanup(list(ship))

// ===== PAYING =====

/// A banned crew member asks: the guard says how long and how much; paying takes it from the ship account, lifts the ban on the crew and the payer's own bar, once
/datum/unit_test/voidcrew_trader_checkpoint/payoff_paid/Run()
	TEST_ASSERT(fixture(), "Could not prepare the checkpoint")
	var/datum/outpost_police/police = host.police
	var/mob/living/carbon/human/payer = visitor(get_step(guard, SOUTH))
	var/mob/living/carbon/human/mate = visitor(lobby)
	var/obj/structure/overmap/ship/ship = wanted_ship(payer, 5000)
	ship.ship_team.join_member(mate.mind)
	var/datum/voidcrew_crew_record/crew = payer.mind.get_reputation_crew()
	var/datum/outpost_warrant/warrant = payoff_ban(police, payer, 4)
	TEST_ASSERT(host.is_user_barred(payer) && host.is_user_barred(mate), "Fixture: the crew is not banned")
	var/datum/shop_sku/weapons_permit/permit = locate() in guard.shop.skus
	TEST_ASSERT(!permit.can_trade(payer, guard), "Fixture: the permit desk serves a banned crew")

	// Clicking him: he answers about the ban, where he used to refuse. Nobody at the keys, so the offer lapses.
	guard.open_trader_menu(payer)
	TEST_ASSERT_NOTNULL(guard.payoff_last_line, "The guard said nothing about the ban to a banned customer")
	TEST_ASSERT(findtext(guard.payoff_last_line, "a quarter of an hour"), "The guard did not say how long is left: '[guard.payoff_last_line]'")
	TEST_ASSERT(findtext(guard.payoff_last_line, "2,000"), "The guard did not name 2,000: '[guard.payoff_last_line]'")
	TEST_ASSERT_EQUAL(length(police.payoff_offers), 0, "An offer nobody could answer was left out")
	TEST_ASSERT_EQUAL(ship.ship_account.account_balance, 5000, "Asking took money")
	TEST_ASSERT(host.is_user_barred(payer), "Asking lifted the ban")

	// Asked again at once: he has just said it
	guard.speak_cooldown = 0
	TEST_ASSERT_EQUAL(police.payoff_ask(guard, payer), "", "He answered the same person twice running")
	TEST_ASSERT_EQUAL(length(police.payoff_offers), 0, "A second ask inside the wait made an offer")

	// The offer, and Pay
	payoff_fresh(police, guard)
	var/text = police.payoff_ask(guard, payer)
	TEST_ASSERT(istext(text) && length(text), "The guard made no offer")
	TEST_ASSERT_EQUAL(payoff_offered(police, payer), 2000, "The offer out is not 2,000") // OUTPOST_POLICE_PAYOFF_BAN
	guard.speak_cooldown = 0
	TEST_ASSERT_EQUAL(police.payoff_ask(guard, payer), "", "A second ask while an offer is out made another")
	guard.speak_cooldown = 0
	TEST_ASSERT(police.payoff_answer(guard, payer.mind, TRUE), "Paying the guard did not lift the ban")
	TEST_ASSERT_EQUAL(ship.ship_account.account_balance, 3000, "Paying did not take 2,000 from the ship account")
	TEST_ASSERT(!host.is_ship_embargoed(ship), "The ship is still banned after the pay-off")
	TEST_ASSERT_NULL(police.incidents[crew], "The incident outlived the pay-off")
	TEST_ASSERT_EQUAL(warrant.barred_until, 0, "The payer's own bar outlived the pay-off")
	TEST_ASSERT(!host.is_user_barred(payer) && !host.is_user_barred(mate), "The crew is still refused after the pay-off")
	TEST_ASSERT(permit.can_trade(payer, guard), "The permit desk still refuses a crew that paid")
	TEST_ASSERT(guard.payoff_last_line in ambient_dialogue_lines("outpost_police.json", "halcyon", "payoff_taken"), "The guard did not say he took it: '[guard.payoff_last_line]'") // POLICE_LINE_PAYOFF_TAKEN
	TEST_ASSERT_EQUAL(police.payoff_times(payer.mind), 1, "The pay-off was not counted")
	TEST_ASSERT_NULL(police.payoff_quote(payer), "A crew that paid is still quoted")

	// One offer, one payment; and nothing left to ask about
	TEST_ASSERT(!police.payoff_answer(guard, payer.mind, TRUE), "One offer was paid twice")
	payoff_fresh(police, guard)
	TEST_ASSERT_NULL(police.payoff_ask(guard, payer), "The guard still talks about a ban that was paid off")
	TEST_ASSERT_EQUAL(ship.ship_account.account_balance, 3000, "A second answer took money again")
	// The next tick lays nothing again, and drops the payer's empty record
	police.tick_warrants()
	TEST_ASSERT(!host.is_ship_embargoed(ship) && !length(police.incidents), "The ban came back on the next tick")
	TEST_ASSERT_NULL(police.get_warrant(payer.mind), "The payer's cleared record was kept")
	wanted_cleanup(list(ship))

/// A clean crewmate pays for the crew (the offender's own bar stays); the money comes from the crew's ships together; saying no costs nothing
/datum/unit_test/voidcrew_trader_checkpoint/payoff_crewmate/Run()
	TEST_ASSERT(fixture(), "Could not prepare the checkpoint")
	var/datum/outpost_police/police = host.police
	var/mob/living/carbon/human/payer = visitor(get_step(guard, SOUTH))
	var/mob/living/carbon/human/offender = visitor(lobby)
	var/obj/structure/overmap/ship/first = wanted_ship(payer, 1500)
	first.ship_team.join_member(offender.mind)
	var/datum/voidcrew_crew_record/crew = payer.mind.get_reputation_crew()
	var/obj/structure/overmap/ship/second = wanted_ship(null, 3000, crew)
	var/datum/outpost_warrant/warrant = payoff_ban(police, offender, 5)
	TEST_ASSERT(host.is_ship_embargoed(first) && host.is_ship_embargoed(second), "Fixture: five stars did not ban both ships")
	TEST_ASSERT_NULL(police.get_warrant(payer.mind), "Fixture: the clean crewmate has a record")

	// No: nothing taken, still banned
	var/text = police.payoff_ask(guard, payer)
	TEST_ASSERT(findtext(text, "half an hour") && findtext(text, "4,000"), "A 30 minute ban was not offered at 4,000 with half an hour left: '[text]'")
	TEST_ASSERT(!police.payoff_answer(guard, payer.mind, FALSE), "Saying no lifted the ban")
	TEST_ASSERT_EQUAL(first.ship_account.account_balance + second.ship_account.account_balance, 4500, "Saying no took money")
	TEST_ASSERT(host.is_ship_embargoed(first), "Saying no lifted the ban")
	TEST_ASSERT_EQUAL(police.payoff_times(payer.mind), 0, "Saying no was counted as a pay-off")

	// Pay: 4,000 from the two ships together
	payoff_fresh(police, guard)
	police.payoff_ask(guard, payer)
	guard.speak_cooldown = 0
	TEST_ASSERT(police.payoff_answer(guard, payer.mind, TRUE), "A clean crewmate could not pay the crew's ban off")
	TEST_ASSERT_EQUAL(first.ship_account.account_balance + second.ship_account.account_balance, 500, "4,000 did not leave the crew's ship accounts")
	TEST_ASSERT(!host.is_ship_embargoed(first) && !host.is_ship_embargoed(second), "A ship of the crew is still banned")
	TEST_ASSERT_NULL(police.get_warrant(payer.mind), "Paying left a record on a clean crewmate")
	TEST_ASSERT(!host.is_user_barred(payer), "The payer is still refused")
	// The offender's own bar is theirs to wait out or pay
	TEST_ASSERT(warrant.barred_until > world.time, "A crewmate's payment lifted the offender's own bar")
	TEST_ASSERT(host.is_user_barred(offender), "The offender's own bar was lifted by a crewmate's payment")
	wanted_cleanup(list(first, second))

// ===== THE REFUSALS =====

/// Nothing for the wanted, a stranger, an empty account, a crew with a member still at four stars, an admin's embargo, or with the guard down, away or played
/datum/unit_test/voidcrew_trader_checkpoint/payoff_refused/Run()
	TEST_ASSERT(fixture(), "Could not prepare the checkpoint")
	var/datum/outpost_police/police = host.police
	var/turf/desk = get_turf(guard)
	var/mob/living/carbon/human/payer = visitor(get_step(guard, SOUTH))
	var/mob/living/carbon/human/offender = visitor(lobby)
	var/mob/living/carbon/human/stranger = visitor(get_step(guard, WEST))
	var/obj/structure/overmap/ship/ship = wanted_ship(payer, 500)
	ship.ship_team.join_member(offender.mind)
	var/obj/structure/overmap/ship/other_ship = wanted_ship(stranger, 9000)
	var/datum/voidcrew_crew_record/crew = payer.mind.get_reputation_crew()
	var/datum/outpost_warrant/warrant = payoff_ban(police, offender, 4)
	var/list/short_lines = ambient_dialogue_lines("outpost_police.json", "halcyon", "payoff_short") // POLICE_LINE_PAYOFF_SHORT
	var/list/crew_lines = ambient_dialogue_lines("outpost_police.json", "halcyon", "payoff_crew") // POLICE_LINE_PAYOFF_CREW

	// Someone from another crew: nothing to ask about, and their money buys the banned crew nothing
	TEST_ASSERT_NULL(police.payoff_ask(guard, stranger), "A stranger was told about another crew's ban")
	TEST_ASSERT_NULL(guard.payoff_last_line, "The guard spoke of a ban to a stranger")
	TEST_ASSERT(!police.payoff_take(guard, stranger, 2000, "ban"), "A stranger paid another crew's ban off") // OUTPOST_POLICE_PAYOFF_KIND_BAN
	TEST_ASSERT_EQUAL(other_ship.ship_account.account_balance, 9000, "A stranger was charged for another crew's ban")
	TEST_ASSERT(host.is_ship_embargoed(ship), "A stranger lifted another crew's ban")

	// Not enough in the account: nothing taken, still banned, not counted
	var/text = police.payoff_ask(guard, payer)
	TEST_ASSERT(istext(text) && length(text), "The guard made no offer to a banned crew member with no stars")
	guard.speak_cooldown = 0
	TEST_ASSERT(!police.payoff_answer(guard, payer.mind, TRUE), "A short payment lifted the ban")
	TEST_ASSERT_EQUAL(ship.ship_account.account_balance, 500, "A short payment took what was there")
	TEST_ASSERT(host.is_ship_embargoed(ship) && police.incidents[crew], "A short payment lifted the ban")
	TEST_ASSERT(guard.payoff_last_line in short_lines, "The guard did not say the payment failed: '[guard.payoff_last_line]'")
	TEST_ASSERT_EQUAL(police.payoff_times(payer.mind), 0, "A failed payment was counted")
	ship.ship_account.account_balance = 9000

	// The wanted are refused as before: he says nothing of the ban and takes nothing
	payoff_fresh(police, guard)
	guard.payoff_last_line = null
	var/datum/outpost_warrant/own = police_pin_warrant(police, payer.mind, 10)
	TEST_ASSERT_NULL(police.payoff_ask(guard, payer), "Someone with a star was told about the ban")
	guard.open_trader_menu(payer)
	TEST_ASSERT_NULL(guard.payoff_last_line, "The guard spoke of the ban to someone with a star")
	TEST_ASSERT(!police.payoff_take(guard, payer, 2000, "ban"), "Someone with a star paid the ban off")
	police.remove_warrant(own)

	// A star earned while the price was on the table: no deal
	payoff_fresh(police, guard)
	TEST_ASSERT(police.payoff_ask(guard, payer), "The guard made no offer")
	police_pin_warrant(police, payer.mind, 10)
	TEST_ASSERT(!police.payoff_answer(guard, payer.mind, TRUE), "Someone who earned a star while deciding paid the ban off")
	police.remove_warrant(police.get_warrant(payer.mind))

	// A crewmate still at four stars here would have the ban laid again at once: no price, and no money taken
	payoff_fresh(police, guard)
	warrant.heat = 100
	TEST_ASSERT_EQUAL(police.payoff_ask(guard, payer), "", "A price was named with a crewmate still at four stars")
	TEST_ASSERT(guard.payoff_last_line in crew_lines, "The guard did not say a crewmate is still wanted: '[guard.payoff_last_line]'")
	TEST_ASSERT_EQUAL(length(police.payoff_offers), 0, "An offer was made with a crewmate still at four stars")
	TEST_ASSERT(!police.payoff_take(guard, payer, 2000, "ban"), "The ban was paid off with a crewmate still at four stars")
	warrant.heat = 0

	// The guard out cold, away from his desk, or with a player in his body: nobody to pay
	payoff_fresh(police, guard)
	TEST_ASSERT(police.payoff_ask(guard, payer), "The guard made no offer")
	guard.stat = UNCONSCIOUS
	TEST_ASSERT(!police.payoff_answer(guard, payer.mind, TRUE), "A guard who is out cold took the money")
	payoff_fresh(police, guard)
	TEST_ASSERT_NULL(police.payoff_ask(guard, payer), "A guard who is out cold named a price")
	guard.stat = CONSCIOUS
	TEST_ASSERT(police.payoff_ask(guard, payer), "The guard, awake again, made no offer")
	guard.forceMove(lobby)
	TEST_ASSERT(!police.payoff_answer(guard, payer.mind, TRUE), "A guard away from his desk took the money")
	payoff_fresh(police, guard)
	payer.forceMove(get_step(lobby, SOUTH))
	TEST_ASSERT_NULL(police.payoff_ask(guard, payer), "A guard away from his desk named a price")
	guard.forceMove(desk)
	payer.forceMove(get_step(guard, SOUTH))
	TEST_ASSERT(police.payoff_ask(guard, payer), "The guard, back at his desk, made no offer")
	guard.mind_initialize()
	allocated += guard.mind
	TEST_ASSERT(!police.payoff_answer(guard, payer.mind, TRUE), "A guard with a player in his body took the money")
	payoff_fresh(police, guard)
	TEST_ASSERT_NULL(police.payoff_ask(guard, payer), "A guard with a player in his body named a price")
	TEST_ASSERT_EQUAL(ship.ship_account.account_balance, 9000, "Money was taken with nobody to pay")
	TEST_ASSERT(host.is_ship_embargoed(ship), "The ban was lifted with nobody to pay")
	wanted_cleanup(list(ship, other_ship))

/// An embargo the police did not lay is told, never sold; a barred person with no crew is quoted and cannot pay; a barred one with a crew can
/datum/unit_test/voidcrew_trader_checkpoint/payoff_bar_and_admin/Run()
	TEST_ASSERT(fixture(), "Could not prepare the checkpoint")
	var/datum/outpost_police/police = host.police
	var/mob/living/carbon/human/embargoed = visitor(get_step(guard, SOUTH))
	var/mob/living/carbon/human/loner = visitor(get_step(guard, WEST))
	var/obj/structure/overmap/ship/ship = wanted_ship(embargoed, 9000)
	var/list/time_lines = ambient_dialogue_lines("outpost_police.json", "halcyon", "payoff_time") // POLICE_LINE_PAYOFF_TIME

	// An admin's embargo: how long, and no price
	host.embargo_ship(ship, 10 MINUTES)
	var/list/quote = police.payoff_quote(embargoed)
	TEST_ASSERT_EQUAL(quote?["why"], "not_ours", "An admin's embargo is for sale") // OUTPOST_POLICE_PAYOFF_NOT_OURS
	TEST_ASSERT_EQUAL(police.payoff_ask(guard, embargoed), "", "A price was named for an admin's embargo")
	TEST_ASSERT_EQUAL(length(police.payoff_offers), 0, "An offer was made for an admin's embargo")
	var/said = FALSE
	for(var/line in time_lines)
		if(guard.payoff_last_line == replacetext(line, "%TIME%", "about ten minutes"))
			said = TRUE
	TEST_ASSERT(said, "The guard did not say how long an admin's embargo has left: '[guard.payoff_last_line]'")
	TEST_ASSERT(!police.payoff_take(guard, embargoed, 2000, "ban"), "An admin's embargo was paid off") // OUTPOST_POLICE_PAYOFF_KIND_BAN
	TEST_ASSERT(host.is_ship_embargoed(ship), "An admin's embargo was lifted")
	// One an admin made longer than the ban behind it is not the police's to sell either
	host.embargoed_ships -= ship
	payoff_ban(police, embargoed, 4)
	police.remove_warrant(police.get_warrant(embargoed.mind))
	TEST_ASSERT_EQUAL(police.payoff_quote(embargoed)?["price"], 2000, "Fixture: the crew's own ban is not for sale")
	host.embargo_ship(ship, 2 HOURS)
	TEST_ASSERT_EQUAL(police.payoff_quote(embargoed)?["why"], "not_ours", "An embargo an admin made longer is for sale")
	host.embargoed_ships -= ship

	// A bar alone, nobody's crew: a price is named, and there is no account to pay it from
	payoff_fresh(police, guard)
	var/datum/outpost_warrant/bar = police_pin_warrant(police, loner.mind, 0)
	bar.barred_until = world.time + 5 MINUTES
	var/text = police.payoff_ask(guard, loner)
	TEST_ASSERT(findtext(text, "about five minutes") && findtext(text, "1,000"), "A bar alone was not offered at 1,000 with about five minutes left: '[text]'")
	guard.speak_cooldown = 0
	TEST_ASSERT(!police.payoff_answer(guard, loner.mind, TRUE), "Someone with no crew paid a bar off")
	TEST_ASSERT(bar.barred_until > world.time, "A bar was lifted for nothing")

	// A bar alone, with a crew: 1,000 and it is gone, the crew's incident (none) untouched
	payoff_fresh(police, guard)
	var/datum/outpost_warrant/own = police_pin_warrant(police, embargoed.mind, 0)
	own.barred_until = world.time + 12 MINUTES
	text = police.payoff_ask(guard, embargoed)
	TEST_ASSERT(findtext(text, "about ten minutes") && findtext(text, "1,000"), "A bar was not offered at 1,000 with about ten minutes left: '[text]'")
	guard.speak_cooldown = 0
	TEST_ASSERT(police.payoff_answer(guard, embargoed.mind, TRUE), "A barred crew member could not pay the bar off")
	TEST_ASSERT_EQUAL(ship.ship_account.account_balance, 8000, "A bar alone did not cost 1,000") // OUTPOST_POLICE_PAYOFF_BAR
	TEST_ASSERT_EQUAL(own.barred_until, 0, "The bar outlived the pay-off")
	TEST_ASSERT(!host.is_user_barred(embargoed), "A barred person who paid is still refused")
	wanted_cleanup(list(ship))

// ===== AGAIN AND AGAIN =====

/// Each pay-off doubles the crew's next one here, whoever pays and whatever for; leaving and rejoining keeps the count, and so does moving to another crew; it stops doubling in the end
/datum/unit_test/voidcrew_trader_checkpoint/payoff_doubles/Run()
	TEST_ASSERT(fixture(), "Could not prepare the checkpoint")
	var/datum/outpost_police/police = host.police
	var/mob/living/carbon/human/payer = visitor(get_step(guard, SOUTH))
	var/mob/living/carbon/human/mate = visitor(get_step(guard, WEST))
	payer.mind.key = "payoffpayer"
	var/obj/structure/overmap/ship/ship = wanted_ship(payer, 100000)
	ship.ship_team.join_member(mate.mind)
	var/datum/voidcrew_crew_record/crew = payer.mind.get_reputation_crew()
	TEST_ASSERT_NOTNULL(crew, "Fixture: the payer has no crew")

	// First: 2,000
	payoff_ban(police, payer, 4)
	TEST_ASSERT(police.payoff_ask(guard, payer), "The guard made no first offer")
	guard.speak_cooldown = 0
	TEST_ASSERT(police.payoff_answer(guard, payer.mind, TRUE), "The first pay-off failed")
	TEST_ASSERT_EQUAL(ship.ship_account.account_balance, 98000, "The first pay-off was not 2,000")

	// Banned again; out of the crew and back in: the second is 4,000, whoever asks
	payoff_ban(police, payer, 4)
	payer.mind.leave_reputation_crew()
	TEST_ASSERT(ship.ship_team.join_member(payer.mind), "Fixture: the payer could not rejoin")
	TEST_ASSERT_EQUAL(payer.mind.get_reputation_crew(), crew, "Fixture: rejoining made another crew")
	TEST_ASSERT_EQUAL(police.payoff_quote(payer)?["price"], 4000, "Leaving the crew and rejoining reset the price")
	TEST_ASSERT_EQUAL(police.payoff_quote(mate)?["price"], 4000, "A crewmate who has not paid before is quoted the first price")
	payoff_fresh(police, guard)
	var/text = police.payoff_ask(guard, mate)
	TEST_ASSERT(findtext(text, "4,000"), "The second offer does not name 4,000: '[text]'")
	guard.speak_cooldown = 0
	TEST_ASSERT(police.payoff_answer(guard, mate.mind, TRUE), "The second pay-off failed")
	TEST_ASSERT_EQUAL(ship.ship_account.account_balance, 94000, "The second pay-off was not 4,000")
	TEST_ASSERT_EQUAL(police.payoff_times(payer.mind), 2, "Two pay-offs were not counted as two")

	// The payer's own bar is still on them: it has doubled twice too
	TEST_ASSERT_EQUAL(police.payoff_quote(payer)?["price"], 4000, "A bar after two pay-offs is not 4,000") // OUTPOST_POLICE_PAYOFF_BAR * 4
	// A 30 minute ban after two pay-offs: 16,000
	payoff_ban(police, payer, 5)
	TEST_ASSERT_EQUAL(police.payoff_quote(payer)?["price"], 16000, "A 30 minute ban after two pay-offs is not 16,000")
	// Another outpost keeps its own count
	var/obj/structure/overmap/trader_outpost/elsewhere = wanted_outpost()
	TEST_ASSERT_EQUAL(elsewhere.police.payoff_times(payer.mind), 0, "A pay-off was counted at another outpost")

	// It stops doubling: OUTPOST_POLICE_PAYOFF_DOUBLINGS (6), and the number still reads as one
	police.payoff_paid["crew [crew.crew_id]"] = 40
	var/capped = police.payoff_quote(payer)?["price"]
	TEST_ASSERT_EQUAL(capped, 256000, "The price went on doubling past its limit")
	TEST_ASSERT_EQUAL(outpost_police_price_text(capped), "256,000", "The highest price does not read as a number")
	TEST_ASSERT_EQUAL(outpost_police_price_text(512000), "512,000", "The highest price of all does not read as a number") // the Undertow's 8,000 * 64
	police.payoff_paid["crew [crew.crew_id]"] = 2

	// Off to a crew of their own with a new ship: the count goes with the player
	var/obj/structure/overmap/ship/new_ship = wanted_ship(payer, 0)
	var/datum/voidcrew_crew_record/new_crew = payer.mind.get_reputation_crew()
	TEST_ASSERT(new_crew && new_crew != crew, "Fixture: the payer did not move to a new crew")
	payoff_ban(police, payer, 4)
	TEST_ASSERT(host.is_ship_embargoed(new_ship), "Fixture: the new crew is not banned")
	TEST_ASSERT_EQUAL(police.payoff_quote(payer)?["price"], 8000, "Moving to a new crew reset the price")
	wanted_cleanup(list(ship, new_ship))

/// Two crewmates with the same price on the table: the first pays, the second pays nothing
/datum/unit_test/voidcrew_trader_checkpoint/payoff_two_at_once/Run()
	TEST_ASSERT(fixture(), "Could not prepare the checkpoint")
	var/datum/outpost_police/police = host.police
	var/mob/living/carbon/human/first = visitor(get_step(guard, SOUTH))
	var/mob/living/carbon/human/second = visitor(get_step(guard, WEST))
	var/obj/structure/overmap/ship/ship = wanted_ship(first, 20000)
	ship.ship_team.join_member(second.mind)
	// The second is the one who did it: they carry their own bar too
	payoff_ban(police, second, 4)
	TEST_ASSERT(police.payoff_ask(guard, first), "The guard made the first crewmate no offer")
	guard.speak_cooldown = 0
	TEST_ASSERT(police.payoff_ask(guard, second), "The guard made the second crewmate no offer")
	TEST_ASSERT_EQUAL(length(police.payoff_offers), 2, "Two crewmates do not each have an offer")
	guard.speak_cooldown = 0
	TEST_ASSERT(police.payoff_answer(guard, first.mind, TRUE), "The first crewmate could not pay")
	guard.speak_cooldown = 0
	// The second's offer was for the ban, which is gone; what is left on them is their own bar, a different deal
	TEST_ASSERT(!police.payoff_answer(guard, second.mind, TRUE), "The second crewmate paid for a ban already lifted")
	TEST_ASSERT_EQUAL(ship.ship_account.account_balance, 18000, "The crew was charged more than once")
	TEST_ASSERT_EQUAL(police.payoff_times(first.mind), 1, "Two pay-offs were counted for one")
	// Asked again, he tells the second how it stands now: their bar, at the doubled price
	guard.speak_cooldown = 0
	var/text = police.payoff_ask(guard, second)
	TEST_ASSERT(findtext(text, "2,000"), "The second crewmate was not told the new price for their own bar: '[text]'") // OUTPOST_POLICE_PAYOFF_BAR * 2
	TEST_ASSERT_EQUAL(police.payoff_offers[WEAKREF(second.mind)]?[2], "bar", "The new offer is not for the bar") // OUTPOST_POLICE_PAYOFF_KIND_BAR
	wanted_cleanup(list(ship))

// ===== AFTERWARDS =====

/// A ban that starts over is told afresh; after a pay-off a crime is a crime like any other, and four stars bans the crew again at the doubled price
/datum/unit_test/voidcrew_trader_checkpoint/payoff_crime_after/Run()
	TEST_ASSERT(fixture(), "Could not prepare the checkpoint")
	var/datum/outpost_police/police = host.police
	var/mob/living/carbon/human/payer = visitor(get_step(guard, SOUTH))
	var/mob/living/carbon/human/offender = visitor(lobby)
	var/obj/structure/overmap/ship/ship = wanted_ship(payer, 20000)
	ship.ship_team.join_member(offender.mind)
	var/datum/voidcrew_crew_record/crew = payer.mind.get_reputation_crew()
	payoff_ban(police, offender, 4)
	var/datum/outpost_incident/incident = police.incidents[crew]

	// Five minutes left; a crewmate's crime starts it over; asked again, he says the new time
	incident.ends_at = world.time + 5 MINUTES
	host.embargoed_ships[ship] = incident.ends_at
	var/text = police.payoff_ask(guard, payer)
	TEST_ASSERT(findtext(text, "about five minutes"), "The guard did not say about five minutes: '[text]'")
	TEST_ASSERT(!police.payoff_answer(guard, payer.mind, FALSE), "Saying no paid")
	police.count_crime(offender, "unarmed") // OUTPOST_CRIME_ASSAULT_UNARMED: 6 heat, no star
	TEST_ASSERT_EQUAL(incident.ends_at, world.time + 15 MINUTES, "Fixture: a crewmate's crime did not start the ban over")
	payoff_fresh(police, guard)
	text = police.payoff_ask(guard, payer)
	TEST_ASSERT(findtext(text, "a quarter of an hour"), "The guard did not say the ban had started over: '[text]'")
	TEST_ASSERT(findtext(text, "2,000"), "A ban that started over changed its price: '[text]'")

	// Paid off
	guard.speak_cooldown = 0
	TEST_ASSERT(police.payoff_answer(guard, payer.mind, TRUE), "The pay-off failed")
	TEST_ASSERT(!host.is_ship_embargoed(ship) && !length(police.incidents), "The ban outlived the pay-off")

	// A small crime afterwards restarts nothing: there is no ban to restart
	police.count_crime(offender, "unarmed")
	TEST_ASSERT(!host.is_ship_embargoed(ship) && !length(police.incidents), "A small crime after the pay-off brought the ban back")
	// Keeping it up to four stars bans the crew again, for the whole time
	for(var/blow in 1 to 12)
		if(police.count_crime(offender, "officer_kill") >= 4) // OUTPOST_CRIME_KILL_OFFICER
			break
	TEST_ASSERT_EQUAL(police.get_stars(offender.mind), 4, "Fixture: the offender did not reach four stars")
	TEST_ASSERT(host.is_ship_embargoed(ship), "Four stars after a pay-off did not ban the crew again")
	incident = police.incidents[crew]
	TEST_ASSERT_NOTNULL(incident, "Four stars after a pay-off made no incident")
	TEST_ASSERT_EQUAL(incident.ends_at, world.time + 15 MINUTES, "The new ban is not the full 15 minutes") // OUTPOST_POLICE_EMBARGO
	TEST_ASSERT(host.is_user_barred(payer), "The crew is not refused under the new ban")
	// While the offender is still at four stars nobody buys it off
	TEST_ASSERT_EQUAL(police.payoff_quote(payer)?["why"], "crew_wanted", "The new ban is for sale with the offender still at four stars") // OUTPOST_POLICE_PAYOFF_CREW_WANTED
	// Once they are not: the second pay-off costs double
	var/datum/outpost_warrant/warrant = police.get_warrant(offender.mind)
	warrant.heat = 0
	TEST_ASSERT_EQUAL(police.payoff_quote(payer)?["price"], 4000, "The second pay-off is not double the first")
	wanted_cleanup(list(ship))
