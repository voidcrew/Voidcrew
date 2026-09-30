/**
 * NPC guards (outpost_prison_guards.dm, outpost_prison_guard_routine.dm). Owner: XA.
 * The dialogue file; hiring, the cap and the fee; wages and walking off unpaid; the baton and who
 * it may touch; the responses to arguments, fights, threats, spats and hatch climbs; the riot hold;
 * going down and coming back; the refusals; and what a guard tells a member.
 *
 * Voidcrew defines are not visible from test files, so tuning values appear as literals with the
 * define named beside them. Prisons are driven with tick(seconds) (or guards_tick()) with their own
 * processing stopped; fixtures are in voidcrew_outpost_prison_helpers.dm. Nobody is on the level,
 * so guards' AI sleeps: tests that need the dispatcher use guards whose AI counts as running, and
 * nothing here waits for a guard to walk anywhere.
 */

/// A guard whose AI counts as running, as if someone were on the level
/mob/living/basic/outpost_prison_guard/awake_for_test

/mob/living/basic/outpost_prison_guard/awake_for_test/ai_running()
	return TRUE

/// An admin's guard (no fee, no wage), beamed in and standing at `spot`, on duty
/datum/unit_test/voidcrew_outpost_management/proc/guard_test_spawn(datum/outpost_prison/prison, turf/spot, awake = TRUE)
	var/datum/outpost_guard_record/record = prison.add_guard_record(TRUE, awake ? /mob/living/basic/outpost_prison_guard/awake_for_test : /mob/living/basic/outpost_prison_guard)
	var/mob/living/basic/outpost_prison_guard/guard = record.guard
	if(!guard)
		return null
	guard.finish_beam_in()
	guard.forceMove(spot)
	return guard

/// Puts `amount` credits in the claim's treasury, and nothing else
/datum/unit_test/voidcrew_outpost_management/proc/guard_test_fund(obj/structure/overmap/dynamic/player_outpost/home, amount)
	home.ensure_home_services()
	var/datum/bank_account/treasury = home.treasury
	treasury.account_debt = 0
	treasury.adjust_money(-treasury.account_balance, "Guard test")
	treasury.adjust_money(amount, "Guard test")
	return treasury

/// Whether `line` is one of the guard lines for `context`, placeholders and all
/proc/guard_test_is_line(line, context)
	var/list/guard_lines = outpost_guard_dialogue("guard_lines")
	var/list/entry = guard_lines[context]
	if(!islist(entry) || !istext(line))
		return FALSE
	for(var/pool in entry)
		for(var/candidate in entry[pool])
			if(candidate == line)
				return TRUE
			if(!findtext(candidate, "{"))
				continue
			var/list/parts = splittext(candidate, regex("\\{\[a-z_\]+\\}"))
			var/all_found = TRUE
			for(var/part in parts)
				if(length(part) && !findtext(line, part))
					all_found = FALSE
					break
			if(all_found)
				return TRUE
	return FALSE

// ===== THE DIALOGUE FILE =====

/datum/unit_test/voidcrew_outpost_prison_guards_files

/datum/unit_test/voidcrew_outpost_prison_guards_files/Run()
	// The file is read the way outpost_prisoner_extra_dialogue() reads it (the strings directory is a define)
	load_strings_file("outpost_prison_guards.json", "voidcrew/modules/player_outposts/strings")
	var/list/contents = GLOB.string_cache["outpost_prison_guards.json"]
	TEST_ASSERT(islist(contents), "outpost_prison_guards.json did not load")
	TEST_ASSERT(islist(contents["lines"]), "outpost_prison_guards.json has no lines block")
	TEST_ASSERT(islist(contents["guard_lines"]), "outpost_prison_guards.json has no guard_lines block")
	TEST_ASSERT(islist(contents["guard_personalities"]), "outpost_prison_guards.json has no guard_personalities block")
	TEST_ASSERT(!is_outpost_prison_guard(null), "Nothing counted as a guard")

	// The prisoners' lines about guards (their rules are X0's dialogue test)
	var/list/prisoner_lines = contents["lines"]
	for(var/context in list("guard_near", "guard_batoned"))
		TEST_ASSERT(islist(prisoner_lines[context]), "The prisoners have no [context] lines")

	// Every guard context the code says, in the shape the prisoners' lines have
	var/list/personalities = contents["guard_personalities"]
	TEST_ASSERT(length(personalities) >= 2, "There are fewer than two guard personalities")
	var/list/guard_lines = contents["guard_lines"]
	var/list/used = list("arrival", "post", "rounds_start", "rounds_clear", "yard_comment", "coffee", "check_on",
		"check_on_hungry", "check_on_dirty", "check_on_hurt", "report_hatch", "report_restless", "report_hurt",
		"report_dark", "report_all_good", "greet_owner", "greet_member", "spat_stop", "argue_stop", "fight_stop",
		"threat_stop", "climb_stop", "riot_call", "riot_hold", "follow_member", "fallback", "loose_call", "loose_nearly",
		"creature_flee", "downed", "recalled", "unpaid", "dismissed", "attacked_by_player")
	for(var/context in used)
		TEST_ASSERT(islist(guard_lines[context]), "The guards have no [context] lines")
	for(var/context in guard_lines)
		var/list/entry = guard_lines[context]
		TEST_ASSERT(islist(entry), "guard_lines: [context] is not a set of line pools")
		TEST_ASSERT(length(entry["any"]), "guard_lines: [context] has no shared (any) lines")
		var/own_pools = 0
		for(var/pool in entry)
			TEST_ASSERT(pool == "any" || (pool in personalities), "guard_lines: [context] has lines for [pool], which is not a guard personality")
			if(pool != "any")
				own_pools++
			for(var/line in entry[pool])
				check_guard_line(line, "guard_lines: [context]/[pool]")
		TEST_ASSERT(own_pools >= 2, "guard_lines: [context] has lines for [own_pools] personalities, not 2 or more")

	// The guards' two-line exchanges
	var/list/conversations = contents["guard_conversations"]
	TEST_ASSERT(length(conversations), "The guards have no conversations")
	for(var/list/conversation as anything in conversations)
		check_guard_line(conversation["opener"], "guard_conversations: opener")
		TEST_ASSERT(length(conversation["replies"]), "A guard conversation has no replies: [conversation["opener"]]")
		for(var/reply in conversation["replies"])
			check_guard_line(reply, "guard_conversations: reply")

/// Plain ASCII, at most 20 words, and no placeholder a guard cannot fill
/datum/unit_test/voidcrew_outpost_prison_guards_files/proc/check_guard_line(line, where)
	TEST_ASSERT(istext(line) && length(line), "[where] has an empty or non-text line")
	TEST_ASSERT_EQUAL(length(line), length_char(line), "[where] has a line that is not plain ASCII: [line]")
	TEST_ASSERT(length(splittext(line, " ")) <= 20, "[where] has a line over 20 words: [line]")
	var/bare = line
	for(var/placeholder in GLOB.outpost_guard_placeholders)
		bare = replacetext(bare, placeholder, "")
	TEST_ASSERT(!findtext(bare, "{") && !findtext(bare, "}"), "[where] has a line with an unknown placeholder: [line]")

// ===== HIRING =====

/// Managers hire, the fee comes first, two at most, never on credit; staff doors and the staff checks; dismissal and abandonment
/datum/unit_test/voidcrew_outpost_prison_guard_hiring
	parent_type = /datum/unit_test/voidcrew_outpost_management

/datum/unit_test/voidcrew_outpost_prison_guard_hiring/Run()
	var/obj/structure/overmap/dynamic/player_outpost/home = prison_test_claim("guardhireowner")
	TEST_ASSERT_NOTNULL(home, "The guard hiring test prison did not load")
	var/datum/outpost_prison/prison = test_prison(home)
	var/mob/living/carbon/human/owner = make_player(prison_spot(home, 12, 3), "guardhireowner")
	var/mob/living/carbon/human/visitor = make_player(prison_spot(home, 13, 3), "guardhirevisitor")
	var/datum/bank_account/treasury = guard_test_fund(home, 5000)

	// Managers only.
	TEST_ASSERT(prison.guards_act("guard_hire", list(), visitor), "The console did not take a visitor's hire")
	TEST_ASSERT_EQUAL(length(prison.guard_records), 0, "A visitor hired a guard")
	TEST_ASSERT_EQUAL(treasury.account_balance, 5000, "A refused hire charged the treasury")
	var/list/visitor_block = prison.guards_payload(visitor)
	TEST_ASSERT(!visitor_block["can_manage"] && !visitor_block["can_hire"], "A visitor was offered the hire button")

	// The fee comes out, then the guard beams into the office.
	TEST_ASSERT(prison.guards_act("guard_hire", list(), owner), "The console did not take the owner's hire")
	TEST_ASSERT_EQUAL(length(prison.guard_records), 1, "The owner's hire made no guard")
	TEST_ASSERT_EQUAL(treasury.account_balance, 4000, "Hiring a guard cost [5000 - treasury.account_balance], not 1000") // OUTPOST_GUARD_HIRE_COST
	var/datum/outpost_guard_record/first = prison.guard_records[1]
	var/mob/living/basic/outpost_prison_guard/officer = first.guard
	TEST_ASSERT_NOTNULL(officer, "The hired guard did not beam in")
	TEST_ASSERT_EQUAL(first.rank, "Officer", "The first guard is not an officer")
	TEST_ASSERT_EQUAL(officer.real_name, "Officer [first.surname]", "The guard is not named for their rank")
	TEST_ASSERT(prison.staff_ground[get_turf(officer)], "The guard did not beam into the office")
	TEST_ASSERT_EQUAL(officer.phase, "arriving", "The guard skipped the beam") // OUTPOST_GUARD_ARRIVING
	TEST_ASSERT(!is_outpost_prison_staff(officer), "A guard still beaming in counted as staff")
	officer.finish_beam_in()
	TEST_ASSERT(is_outpost_prison_staff(officer), "A guard on duty did not count as staff")
	TEST_ASSERT(is_outpost_prison_guard(officer, on_duty = TRUE), "A guard on duty was not on duty")
	TEST_ASSERT(is_outpost_prison_mob(officer), "A guard is not one of the prison's own mobs")

	// Staff doors let guards through and never prisoners.
	var/obj/machinery/door/airlock/security/prison_staff/door = locate() in prison_spot(home, 9, 6)
	TEST_ASSERT_NOTNULL(door, "No staff door at (9,6)")
	TEST_ASSERT(may_use_outpost_prison_staff_door(door, officer), "A staff door refused a guard")
	TEST_ASSERT(door.allowed(officer), "A staff door would not open for a guard")
	var/mob/living/basic/outpost_prisoner/prisoner = test_prisoner(prison, prison_spot(home, 8, 8))
	TEST_ASSERT(!may_use_outpost_prison_staff_door(door, prisoner), "A staff door let a prisoner through")

	// A runner about to get away: the guard on duty calls it out by name, with no clock, and the log and the crew get their words.
	TEST_ASSERT(prison.call_out_nearly_away(list(prisoner)), "Nobody called out a runner about to get away")
	TEST_ASSERT(guard_test_is_line(officer.last_line, "loose_nearly"), "The guard's call was [officer.last_line]")
	TEST_ASSERT(findtextEx(officer.last_line, prisoner.speech_name()), "The guard's call does not name the runner: [officer.last_line]")
	TEST_ASSERT(findtextEx(officer.last_line, get_area_name(prisoner)), "The guard's call does not say where the runner is: [officer.last_line]")
	var/list/called_line = prison.entries[1]
	TEST_ASSERT(findtext(called_line["text"], officer.last_line), "The guard's call was not logged: [called_line["text"]]")

	// A sergeant next; a third post does not exist, and asking costs nothing.
	prison.guards_act("guard_hire", list(), owner)
	TEST_ASSERT_EQUAL(length(prison.guard_records), 2, "A second guard was refused")
	var/datum/outpost_guard_record/second = prison.guard_records[2]
	TEST_ASSERT_EQUAL(second.rank, "Sergeant", "The second guard is not a sergeant")
	TEST_ASSERT_EQUAL(treasury.account_balance, 3000, "The second guard did not cost 1000")
	prison.guards_act("guard_hire", list(), owner)
	TEST_ASSERT_EQUAL(length(prison.guard_records), 2, "A third guard was hired") // OUTPOST_GUARD_MAX
	TEST_ASSERT_EQUAL(treasury.account_balance, 3000, "A refused third guard charged the treasury")
	var/list/block = prison.guards_payload(owner)
	TEST_ASSERT(block["can_manage"], "The owner cannot manage the guards")
	TEST_ASSERT(!block["can_hire"], "The hire button was offered with both posts filled")
	TEST_ASSERT_EQUAL(length(block["list"]), 2, "The console does not list both guards")
	var/list/row = block["list"][1]
	for(var/key in list("ref", "name", "rank", "status"))
		TEST_ASSERT(key in row, "A guard's console row has no [key]")
	TEST_ASSERT(!("back_in" in row), "A guard's console row still says when they are back")
	TEST_ASSERT(!("unpaid" in block), "The guards block still counts missed wages")

	// Dismissal: managers only, no refund, and the guard walks out.
	var/mob/living/basic/outpost_prison_guard/sergeant = second.guard
	prison.guards_act("guard_dismiss", list("ref" = REF(second)), visitor)
	TEST_ASSERT_EQUAL(length(prison.guard_records), 2, "A visitor dismissed a guard")
	prison.guards_act("guard_dismiss", list("ref" = REF(second)), owner)
	TEST_ASSERT_EQUAL(length(prison.guard_records), 1, "The owner could not dismiss a guard")
	TEST_ASSERT_EQUAL(sergeant.phase, "leaving", "A dismissed guard still beaming in did not beam out") // OUTPOST_GUARD_LEAVING
	TEST_ASSERT_EQUAL(treasury.account_balance, 3000, "Dismissing a guard refunded or charged something")

	// An empty treasury: refused, and no debt.
	guard_test_fund(home, 500)
	prison.guards_act("guard_hire", list(), owner)
	TEST_ASSERT_EQUAL(length(prison.guard_records), 1, "A guard was hired the treasury could not pay for")
	TEST_ASSERT_EQUAL(treasury.account_balance, 500, "A refused hire took money")
	TEST_ASSERT_EQUAL(treasury.account_debt, 0, "A refused hire left debt")

	// Abandonment dismisses everyone, no refund.
	prison.on_outpost_abandoned()
	TEST_ASSERT_EQUAL(length(prison.guard_records), 0, "Guards stayed on the payroll of an abandoned outpost")
	TEST_ASSERT_EQUAL(officer.phase, "leaving", "A guard of an abandoned outpost did not beam out")
	TEST_ASSERT_EQUAL(treasury.account_balance, 500, "Abandonment refunded the guards")
	settle_prison_air(home)

// ===== WAGES =====

/// 2 cr a minute each, only while a member is home; two skipped wages and they walk off, never debt
/datum/unit_test/voidcrew_outpost_prison_guard_wages
	parent_type = /datum/unit_test/voidcrew_outpost_management

/datum/unit_test/voidcrew_outpost_prison_guard_wages/Run()
	var/obj/structure/overmap/dynamic/player_outpost/home = prison_test_claim("guardwageowner")
	TEST_ASSERT_NOTNULL(home, "The guard wage test prison did not load")
	var/datum/outpost_prison/prison = test_prison(home)
	var/mob/living/carbon/human/owner = make_player(prison_spot(home, 12, 3), "guardwageowner")
	var/datum/bank_account/treasury = guard_test_fund(home, 5000)
	prison.guards_act("guard_hire", list(), owner)
	prison.guards_act("guard_hire", list(), owner)
	TEST_ASSERT_EQUAL(length(prison.guard_records), 2, "Two guards were not hired")
	TEST_ASSERT_EQUAL(treasury.account_balance, 3000, "Two guards did not cost 2000")

	// Five minutes with a member home: 2 guards x 2 cr/min x 5 min.
	prison.guard_wage_clock = 0
	prison.crew_home_override = TRUE
	prison.tick(300) // OUTPOST_PRISON_DEPOSIT_INTERVAL
	TEST_ASSERT_EQUAL(treasury.account_balance, 2980, "Five minutes of two guards cost [3000 - treasury.account_balance], not 20") // OUTPOST_GUARD_WAGE
	TEST_ASSERT_EQUAL(prison.guard_unpaid, 0, "A paid wage counted as skipped")

	// Nobody home: nothing.
	prison.crew_home_override = FALSE
	prison.tick(300)
	TEST_ASSERT_EQUAL(treasury.account_balance, 2980, "Guards were paid while nobody was home")

	// An empty treasury: the wage is skipped, not owed, and after two in a row they walk off.
	guard_test_fund(home, 0)
	prison.crew_home_override = TRUE
	prison.tick(300)
	TEST_ASSERT_EQUAL(prison.guard_unpaid, 1, "A wage the treasury could not cover was not counted as skipped")
	TEST_ASSERT_EQUAL(length(prison.guard_records), 2, "The guards left after one skipped wage")
	TEST_ASSERT_EQUAL(treasury.account_debt, 0, "A skipped wage became debt")
	prison.tick(300)
	TEST_ASSERT_EQUAL(length(prison.guard_records), 0, "The guards stayed after two skipped wages") // OUTPOST_GUARD_UNPAID_LEAVE
	TEST_ASSERT_EQUAL(treasury.account_debt, 0, "Unpaid guards left debt")
	TEST_ASSERT_EQUAL(treasury.account_balance, 0, "Unpaid guards took money on the way out")
	TEST_ASSERT_EQUAL(prison.guard_unpaid, 0, "The skipped wages were not cleared once the guards left")
	settle_prison_air(home)

// ===== THE BATON =====

/// Three strikes put a prisoner in stamina crit with no brute and no mood of their own; onlookers lose 2 once; calm, downed and players are never struck
/datum/unit_test/voidcrew_outpost_prison_guard_baton
	parent_type = /datum/unit_test/voidcrew_outpost_management

/datum/unit_test/voidcrew_outpost_prison_guard_baton/Run()
	var/obj/structure/overmap/dynamic/player_outpost/home = trouble_test_claim("guardbatonowner")
	TEST_ASSERT_NOTNULL(home, "The baton test prison did not load")
	var/datum/outpost_prison/prison = test_prison(home)
	var/mob/living/basic/outpost_prisoner/first = trouble_awake_prisoner(prison, prison_spot(home, 8, 8))
	var/mob/living/basic/outpost_prisoner/second = trouble_awake_prisoner(prison, prison_spot(home, 9, 8))
	var/mob/living/basic/outpost_prisoner/calm = trouble_awake_prisoner(prison, prison_spot(home, 8, 9))
	var/mob/living/basic/outpost_prisoner/onlooker = trouble_awake_prisoner(prison, prison_spot(home, 12, 8))
	var/mob/living/basic/outpost_prison_guard/guard = guard_test_spawn(prison, prison_spot(home, 7, 8))
	TEST_ASSERT_NOTNULL(guard, "The test guard did not beam in")

	// A calm prisoner beside the guard is never struck.
	TEST_ASSERT(!guard.strike(calm), "A guard struck a calm prisoner")
	TEST_ASSERT_EQUAL(calm.getStaminaLoss(), 0, "A calm prisoner took baton damage")

	// A fight with blows: three strikes.
	first.set_mood(30)
	second.set_mood(30)
	var/datum/outpost_prison_fight/brawl = prison.start_fight(first, second)
	TEST_ASSERT_NOTNULL(brawl, "The test fight did not start")
	brawl.fighting = TRUE
	onlooker.set_mood(70)
	calm.set_mood(70)
	for(var/i in 1 to 3)
		guard.baton_cooldown = 0
		TEST_ASSERT(guard.strike(first), "Baton strike [i] on a fighter did not land")
	TEST_ASSERT(first.has_status_effect(/datum/status_effect/incapacitating/stamcrit), "Three baton strikes did not put a prisoner in stamina crit") // OUTPOST_GUARD_BATON_STAMINA
	TEST_ASSERT_EQUAL(first.getBruteLoss(), 0, "The baton did brute damage")
	TEST_ASSERT(abs(first.mood - 30) < 0.01, "The struck prisoner's mood moved to [first.mood]: the baton counted as staff's")
	TEST_ASSERT(QDELETED(brawl), "Stamina crit did not end the fight")
	TEST_ASSERT(abs(onlooker.mood - 68) < 0.01, "An onlooker ended at [onlooker.mood], not 68: seeing it costs 2, once a minute") // OUTPOST_GUARD_ONLOOKER_MOOD
	TEST_ASSERT(abs(calm.mood - 68) < 0.01, "A prisoner beside it ended at [calm.mood], not 68")

	// Down, never again.
	guard.baton_cooldown = 0
	var/stamina = first.getStaminaLoss()
	TEST_ASSERT(!guard.strike(first), "A guard struck a prisoner in stamina crit")
	TEST_ASSERT_EQUAL(first.getStaminaLoss(), stamina, "A downed prisoner took baton damage")

	// A person is never struck, whatever they do.
	var/mob/living/carbon/human/owner = make_player(prison_spot(home, 6, 8), "guardbatonowner")
	TEST_ASSERT(!guard.strike(owner), "A guard struck a person")
	TEST_ASSERT_EQUAL(owner.getStaminaLoss(), 0, "A person took baton damage")
	settle_prison_air(home)

// ===== RESPONSES =====

/// With their AI asleep guards do nothing; awake, they talk down arguments, baton fights, stop threats and spats, and pull climbers off the hatch
/datum/unit_test/voidcrew_outpost_prison_guard_responses
	parent_type = /datum/unit_test/voidcrew_outpost_management

/datum/unit_test/voidcrew_outpost_prison_guard_responses/Run()
	var/obj/structure/overmap/dynamic/player_outpost/home = trouble_test_claim("guardresponseowner")
	TEST_ASSERT_NOTNULL(home, "The response test prison did not load")
	var/datum/outpost_prison/prison = test_prison(home)
	var/mob/living/carbon/human/warden = make_player(prison_spot(home, 14, 3), "guardresponseowner")

	// Nobody on the level: the guard's AI sleeps and the dispatcher leaves them be.
	var/mob/living/basic/outpost_prison_guard/sleepy = guard_test_spawn(prison, prison_spot(home, 12, 8), awake = FALSE)
	var/mob/living/basic/outpost_prisoner/sulky = trouble_awake_prisoner(prison, prison_spot(home, 13, 8))
	sulky.threat_ref = WEAKREF(warden)
	prison.guards_tick(1)
	TEST_ASSERT_NULL(sleepy.response, "A guard whose AI sleeps was given a response")
	TEST_ASSERT_NOTNULL(sulky.threat_ref, "A guard whose AI sleeps stopped a threat")
	sulky.cancel_threat()
	prison.forget(sulky)
	qdel(sulky)
	prison.dismiss_guard(sleepy.record, "dismissed", TRUE)

	var/mob/living/basic/outpost_prisoner/first = trouble_awake_prisoner(prison, prison_spot(home, 8, 8))
	var/mob/living/basic/outpost_prisoner/second = trouble_awake_prisoner(prison, prison_spot(home, 9, 8))
	var/mob/living/basic/outpost_prison_guard/guard = guard_test_spawn(prison, prison_spot(home, 7, 8))
	TEST_ASSERT_NOTNULL(guard, "The test guard did not beam in")

	// An argument, the talk-down forced (OUTPOST_GUARD_TALKDOWN_CHANCE is 60).
	prison.guard_talkdown_chance = 100
	var/datum/outpost_prison_fight/brawl = prison.start_fight(first, second)
	TEST_ASSERT_NOTNULL(brawl, "The test argument did not start")
	prison.guards_tick(1)
	TEST_ASSERT(QDELETED(brawl), "A guard beside an argument did not talk it down")
	TEST_ASSERT(guard_test_is_line(guard.last_line, "argue_stop"), "The guard did not warn them first: [guard.last_line]")
	TEST_ASSERT_NULL(guard.response, "The guard kept a response for a finished argument")

	// Blows: a warning, then the baton until it is over.
	brawl = prison.start_fight(first, second)
	TEST_ASSERT_NOTNULL(brawl, "The test fight did not start")
	brawl.fighting = TRUE
	for(var/i in 1 to 8)
		if(QDELETED(brawl))
			break
		guard.baton_cooldown = 0
		prison.guards_tick(1)
	TEST_ASSERT(QDELETED(brawl), "A fight went on with a guard beside it")
	TEST_ASSERT(first.has_status_effect(/datum/status_effect/incapacitating/stamcrit) || second.has_status_effect(/datum/status_effect/incapacitating/stamcrit), "The fight did not end by the baton")
	TEST_ASSERT_EQUAL(first.getBruteLoss() + second.getBruteLoss(), 0, "The baton did brute damage")
	guard.end_response()

	// A threat: a word, and it is over. No baton for squaring up.
	var/mob/living/basic/outpost_prisoner/third = trouble_awake_prisoner(prison, prison_spot(home, 8, 7))
	third.threat_ref = WEAKREF(warden)
	third.threat_left = 4
	prison.guards_tick(1)
	TEST_ASSERT_NULL(third.threat_ref, "A guard beside a threatening prisoner did not stop the threat")
	TEST_ASSERT(guard_test_is_line(guard.last_line, "threat_stop"), "The guard did not say a threat_stop line: [guard.last_line]")
	TEST_ASSERT_EQUAL(third.getStaminaLoss(), 0, "A prisoner who only squared up was struck")

	// One who struck someone in the last ten seconds gets the baton after the warning.
	third.threat_ref = WEAKREF(warden)
	third.struck_ref = WEAKREF(warden)
	third.struck_at = world.time
	guard.baton_cooldown = 0
	prison.guards_tick(1)
	TEST_ASSERT_EQUAL(third.getStaminaLoss(), 0, "A guard struck before the warning")
	prison.guards_tick(1)
	TEST_ASSERT(third.getStaminaLoss() >= 35, "A prisoner who just struck someone was not batoned") // OUTPOST_GUARD_BATON_STAMINA
	third.struck_at = 0
	third.cancel_threat()
	prison.guards_tick(1)
	TEST_ASSERT_NULL(guard.response, "The guard kept a response once the threat was over")

	// A spat in sight: stopped from where the guard stands.
	prison.spat_first_ref = WEAKREF(first)
	prison.spat_second_ref = WEAKREF(second)
	prison.spat_lines_left = 2
	prison.guards_tick(1)
	TEST_ASSERT_EQUAL(prison.spat_lines_left, 0, "A guard in sight of a spat let it go on")
	TEST_ASSERT(guard_test_is_line(guard.last_line, "spat_stop"), "The guard did not say a spat_stop line: [guard.last_line]")

	// A hatch climb: from the office side of the hatch, down they slide.
	var/obj/structure/table/reinforced/prison_hatch/hatch = locate() in prison_spot(home, 5, 6)
	TEST_ASSERT_NOTNULL(hatch, "No serving hatch at (5,6)")
	var/mob/living/basic/outpost_prisoner/climber = trouble_awake_prisoner(prison, hatch.yard_side_turf())
	climber.climb_ref = WEAKREF(hatch)
	climber.climb_left = 3
	guard.forceMove(hatch.staff_side_turf())
	prison.guards_tick(1)
	TEST_ASSERT_NULL(climber.climb_ref, "A guard at the hatch did not stop the climb")
	TEST_ASSERT_EQUAL(climber.loc, hatch.yard_side_turf(), "The climber got over the hatch")
	TEST_ASSERT(guard_test_is_line(guard.last_line, "climb_stop"), "The guard did not say a climb_stop line: [guard.last_line]")

	// A loose prisoner: called out, and batoned when they come beside a guard. No chase.
	var/mob/living/basic/outpost_prisoner/runner = trouble_awake_prisoner(prison, prison_spot(home, 5, 4))
	runner.trouble = "loose" // PRISONER_TROUBLE_LOOSE
	guard.baton_cooldown = 0
	prison.guards_tick(1)
	TEST_ASSERT(guard_test_is_line(guard.last_line, "loose_call"), "The guard did not call out the loose prisoner: [guard.last_line]")
	// Said aloud and logged; nothing goes out over the outpost.
	var/list/call_entry = prison.entries[1]
	TEST_ASSERT_EQUAL(call_entry["text"], "[guard.real_name]: \"[guard.last_line]\"", "The loose call was not logged: [call_entry["text"]]")
	TEST_ASSERT(runner.getStaminaLoss() >= 35, "A loose prisoner beside a guard was not batoned") // OUTPOST_GUARD_BATON_STAMINA
	runner.trouble = null
	settle_prison_air(home)

// ===== RIOTS =====

/// In a riot both guards take hold positions beside the staff door; a rioter beside them is batoned; rioters can go for a guard in the yard
/datum/unit_test/voidcrew_outpost_prison_guard_riot
	parent_type = /datum/unit_test/voidcrew_outpost_management

/datum/unit_test/voidcrew_outpost_prison_guard_riot/Run()
	var/obj/structure/overmap/dynamic/player_outpost/home = trouble_test_claim("guardriotowner")
	TEST_ASSERT_NOTNULL(home, "The guard riot test prison did not load")
	var/datum/outpost_prison/prison = test_prison(home)
	var/list/rioters = list(
		trouble_awake_prisoner(prison, prison_spot(home, 8, 8)),
		trouble_awake_prisoner(prison, prison_spot(home, 10, 8)),
		trouble_awake_prisoner(prison, prison_spot(home, 12, 8)),
	)
	set_moods(rioters, 10)
	var/mob/living/basic/outpost_prison_guard/guard_one = guard_test_spawn(prison, prison_spot(home, 12, 4))
	var/mob/living/basic/outpost_prison_guard/guard_two = guard_test_spawn(prison, prison_spot(home, 13, 4))
	TEST_ASSERT(guard_one && guard_two, "The test guards did not beam in")
	TEST_ASSERT(prison.start_riot("guard test", everyone = TRUE), "The test riot did not start")

	prison.guards_tick(1)
	TEST_ASSERT_EQUAL(guard_one.response?.kind, "riot", "The first guard did not answer the riot")
	TEST_ASSERT_EQUAL(guard_two.response?.kind, "riot", "The second guard did not answer the riot")
	var/turf/door = prison_spot(home, 9, 6)
	var/turf/one_spot = guard_one.response.spot
	var/turf/two_spot = guard_two.response.spot
	TEST_ASSERT(one_spot && two_spot, "A guard has no hold position")
	TEST_ASSERT(one_spot != two_spot, "Both guards took the same hold position")
	for(var/turf/spot as anything in list(one_spot, two_spot))
		TEST_ASSERT_EQUAL(get_dist(spot, door), 1, "A hold position is not beside the staff door")
		TEST_ASSERT(prison.staff_ground[spot], "A hold position is not in the office")
	TEST_ASSERT(prison.guard_riot_announced, "The guards' hold was never called out")
	// Said aloud and logged as "Name: \"line\"", once; nothing goes out over the outpost.
	var/holds_logged = 0
	for(var/list/entry as anything in prison.entries)
		for(var/mob/living/basic/outpost_prison_guard/holder as anything in list(guard_one, guard_two))
			var/prefix = "[holder.real_name]: \""
			var/text = entry["text"]
			if(findtext(text, prefix) == 1 && guard_test_is_line(copytext(text, length(prefix) + 1, -1), "riot_hold"))
				holds_logged++
	TEST_ASSERT_EQUAL(holds_logged, 1, "The guards' hold was logged [holds_logged] times, not once")

	// A rioter who comes up beside a guard holding the door gets the baton.
	guard_one.forceMove(one_spot)
	var/mob/living/basic/outpost_prisoner/through = rioters[1]
	var/turf/beside = null
	for(var/direction in GLOB.cardinals)
		var/turf/tile = get_step(one_spot, direction)
		if(prison.guard_office_tile(tile) && tile != two_spot)
			beside = tile
			break
	TEST_ASSERT_NOTNULL(beside, "No office tile beside the hold position")
	through.forceMove(beside)
	prison.riot_windup_left = 0
	guard_one.baton_cooldown = 0
	prison.guards_tick(1)
	TEST_ASSERT(through.getStaminaLoss() >= 35, "A holding guard did not baton the rioter beside them") // OUTPOST_GUARD_BATON_STAMINA

	// A guard in the yard is staff a rioter can go for.
	var/mob/living/basic/outpost_prisoner/rioter = rioters[2]
	guard_two.forceMove(prison_spot(home, 11, 8))
	prison.refresh_prisoner_reach(rioter)
	TEST_ASSERT_EQUAL(rioter.staff_in_reach(), guard_two, "A rioter could not go for a guard in the yard")
	prison.admin_calm()
	settle_prison_air(home)

// ===== DOWN AND BACK =====

/// At 30 health a guard goes down, takes no more, beams out ten seconds later and is back ten minutes after, free; the slot's wait survives a rehire
/datum/unit_test/voidcrew_outpost_prison_guard_down
	parent_type = /datum/unit_test/voidcrew_outpost_management

/datum/unit_test/voidcrew_outpost_prison_guard_down/Run()
	var/obj/structure/overmap/dynamic/player_outpost/home = prison_test_claim("guarddownowner")
	TEST_ASSERT_NOTNULL(home, "The guard down test prison did not load")
	var/datum/outpost_prison/prison = test_prison(home)
	var/mob/living/carbon/human/owner = make_player(prison_spot(home, 12, 3), "guarddownowner")
	var/datum/bank_account/treasury = guard_test_fund(home, 5000)
	prison.guards_act("guard_hire", list(), owner)
	var/datum/outpost_guard_record/record = prison.guard_records[1]
	var/mob/living/basic/outpost_prison_guard/guard = record.guard
	var/guard_name = guard.real_name
	guard.finish_beam_in()

	// Damage stops at 30: down, and nothing more hurts them.
	guard.adjustBruteLoss(100)
	TEST_ASSERT_EQUAL(guard.health, 30, "A guard's health went to [guard.health], not 30") // OUTPOST_GUARD_DOWN_AT
	TEST_ASSERT_EQUAL(guard.phase, "down", "A guard at 30 health did not go down") // OUTPOST_GUARD_DOWN
	TEST_ASSERT(HAS_TRAIT(guard, TRAIT_GODMODE), "A downed guard can still be hurt")
	TEST_ASSERT(!is_outpost_prison_staff(guard), "A downed guard still counted as staff")
	guard.adjustBruteLoss(50)
	guard.adjustFireLoss(50)
	TEST_ASSERT_EQUAL(guard.health, 30, "A downed guard took more damage")
	guard.death()
	TEST_ASSERT(guard.stat != DEAD, "A guard died")

	// Ten seconds later they beam out, and they are back ten minutes after that, at no charge.
	prison.tick(9)
	TEST_ASSERT_EQUAL(guard.phase, "down", "A downed guard left early")
	prison.tick(1) // OUTPOST_GUARD_RECALL_DELAY
	TEST_ASSERT_EQUAL(guard.phase, "leaving", "A downed guard was not beamed out after ten seconds")
	TEST_ASSERT_NULL(record.guard, "The payroll still points at the guard beaming out")
	TEST_ASSERT_EQUAL(record.away_left, 600, "A downed guard is away for [record.away_left] s, not 600") // OUTPOST_GUARD_RETURN_TIME
	TEST_ASSERT_EQUAL(record.status(), "away", "The console does not show the guard as away")
	prison.crew_home_override = TRUE
	prison.tick(599)
	TEST_ASSERT_NULL(record.guard, "A downed guard came back early")
	prison.tick(1)
	TEST_ASSERT_NOTNULL(record.guard, "A downed guard did not come back after ten minutes")
	TEST_ASSERT_EQUAL(record.guard.real_name, guard_name, "A different guard came back")
	TEST_ASSERT_EQUAL(treasury.account_balance, 4000, "The return cost [4000 - treasury.account_balance] cr")

	// Down again and dismissed: the next hire waits out the same slot.
	var/mob/living/basic/outpost_prison_guard/back = record.guard
	back.finish_beam_in()
	var/downed = prison.guards_admin_act("prison_guard_down", list("ref" = REF(record)), null)
	TEST_ASSERT(istext(downed), "The admin could not put a guard down")
	TEST_ASSERT_EQUAL(back.phase, "down", "The admin's down did not put the guard down")
	prison.guards_act("guard_dismiss", list("ref" = REF(record)), owner)
	TEST_ASSERT_EQUAL(length(prison.guard_records), 0, "The downed guard was not dismissed")
	prison.guards_act("guard_hire", list(), owner)
	TEST_ASSERT_EQUAL(length(prison.guard_records), 1, "The rehire was refused")
	var/datum/outpost_guard_record/rehired = prison.guard_records[1]
	TEST_ASSERT_NULL(rehired.guard, "Dismissing a downed guard and hiring another skipped the wait")
	TEST_ASSERT(rehired.away_left > 600, "The rehire waits [rehired.away_left] s, not the downed guard's wait")
	settle_prison_air(home)

// ===== REFUSALS =====

/// No teleports, polymorph, containers, pulling or dragging; a player's punch gets a warning, never the baton; guards are not the crew
/datum/unit_test/voidcrew_outpost_prison_guard_refusals
	parent_type = /datum/unit_test/voidcrew_outpost_management

/datum/unit_test/voidcrew_outpost_prison_guard_refusals/Run()
	var/obj/structure/overmap/dynamic/player_outpost/home = prison_test_claim("guardrefuseowner")
	TEST_ASSERT_NOTNULL(home, "The guard refusal test prison did not load")
	var/datum/outpost_prison/prison = test_prison(home)
	var/mob/living/basic/outpost_prison_guard/guard = guard_test_spawn(prison, prison_spot(home, 12, 4))
	TEST_ASSERT_NOTNULL(guard, "The test guard did not beam in")
	var/turf/start = guard.loc

	TEST_ASSERT(!do_teleport(guard, prison_spot(home, 13, 3), no_effects = TRUE, channel = TELEPORT_CHANNEL_QUANTUM, forced = TRUE), "A forced teleport reported moving a guard")
	TEST_ASSERT_EQUAL(guard.loc, start, "A forced teleport moved a guard")
	guard.wabbajack()
	TEST_ASSERT(!QDELETED(guard), "A polymorph bolt deleted a guard")
	TEST_ASSERT_NULL(guard.change_mob_type(/mob/living/basic/mouse, delete_old_mob = TRUE), "A guard was turned into another mob")
	TEST_ASSERT(HAS_TRAIT(guard, "no_containment"), "A guard can be shut in a locker") // TRAIT_NO_CONTAINMENT
	TEST_ASSERT(HAS_TRAIT(guard, TRAIT_NO_STORAGE_INSERT), "A guard can be put in a bag")
	TEST_ASSERT_EQUAL(guard.sentience_type, SENTIENCE_HUMANOID, "A sentience potion would work on a guard")

	var/mob/living/carbon/human/owner = make_player(prison_spot(home, 11, 4), "guardrefuseowner")
	owner.start_pulling(guard)
	TEST_ASSERT(owner.pulling != guard, "Someone pulled a guard")
	TEST_ASSERT(SEND_SIGNAL(guard, COMSIG_MOUSEDROP_ONTO, owner, owner) & COMPONENT_CANCEL_MOUSEDROP_ONTO, "A guard could be dragged onto something")

	// A punch: a word and a step back, never the baton.
	owner.set_combat_mode(TRUE)
	click_wrapper(owner, guard)
	owner.set_combat_mode(FALSE)
	TEST_ASSERT(guard_test_is_line(guard.last_line, "attacked_by_player"), "A punched guard said [guard.last_line]")
	TEST_ASSERT(!guard.strike(owner), "A guard struck a person")
	prison.guards_tick(1)
	TEST_ASSERT_EQUAL(owner.getStaminaLoss(), 0, "A guard hit back at a person")
	TEST_ASSERT_EQUAL(owner.getBruteLoss(), 0, "A guard hurt a person")

	// Guards on the level never count as a member being home.
	prison.crew_home_override = null
	prison.presence_tick(1)
	TEST_ASSERT(!prison.crew_home(), "Guards counted as the crew being home")

	// The leash: out of the wing for 30 seconds with nobody about to see them walk back, and they
	// are called back for a minute (OUTPOST_GUARD_LEASH_SECONDS, OUTPOST_GUARD_OFF_LEVEL_AWAY).
	var/turf/outside = get_step(prison_spot(home, 9, 1), SOUTH)
	TEST_ASSERT(outside && get_area(outside) != prison.wing, "No tile outside the wing's entrance")
	var/mob/living/basic/outpost_prison_guard/wanderer = guard_test_spawn(prison, outside, awake = FALSE)
	var/datum/outpost_guard_record/wanderer_record = wanderer.record
	for(var/i in 1 to 10)
		prison.guards_tick(5)
		if(wanderer.phase == "leaving")
			break
	TEST_ASSERT_EQUAL(wanderer.phase, "leaving", "A guard out of the wing was not called back")
	TEST_ASSERT_EQUAL(wanderer_record.away_left, 60, "A called-back guard is away for [wanderer_record.away_left] s, not 60")
	settle_prison_air(home)

// ===== WHAT A GUARD TELLS YOU =====

/// A guard greets a member, then reports the wing's most pressing problem, and not again for three minutes
/datum/unit_test/voidcrew_outpost_prison_guard_reports
	parent_type = /datum/unit_test/voidcrew_outpost_management

/datum/unit_test/voidcrew_outpost_prison_guard_reports/Run()
	var/obj/structure/overmap/dynamic/player_outpost/home = prison_test_claim("guardreportowner")
	TEST_ASSERT_NOTNULL(home, "The guard report test prison did not load")
	var/datum/outpost_prison/prison = test_prison(home)
	var/mob/living/basic/outpost_prisoner/prisoner = test_prisoner(prison, prison_spot(home, 8, 8))

	// An empty hatch with someone waiting comes first.
	prison.waiting_for_food = 2
	var/list/report = prison.guard_report()
	TEST_ASSERT_EQUAL(report[1], "report_hatch", "An empty hatch with two waiting was not the first report")
	TEST_ASSERT_EQUAL(report[2]["{count}"], "2", "The hatch report does not say how many are waiting")
	prison.waiting_for_food = 0

	// Then what the yard is unhappy about.
	prisoner.set_hunger(10)
	report = prison.guard_report()
	TEST_ASSERT_EQUAL(report[1], "report_restless", "A hungry prisoner was not reported")
	TEST_ASSERT(findtext(report[2]["{cause}"], "hungry"), "The report's cause is [report[2]["{cause}"]], not hunger")

	// Greeted, then told, then left alone.
	var/mob/living/carbon/human/owner = make_player(prison_spot(home, 12, 4), "guardreportowner")
	var/mob/living/basic/outpost_prison_guard/guard = guard_test_spawn(prison, prison_spot(home, 12, 3))
	TEST_ASSERT(guard.greet_member(owner), "A guard did not greet the owner")
	TEST_ASSERT(guard_test_is_line(guard.last_line, "greet_owner"), "The guard's greeting was [guard.last_line]")
	TEST_ASSERT(guard.greet_member(owner), "A guard did not report to the owner")
	TEST_ASSERT(guard_test_is_line(guard.last_line, "report_restless"), "The guard's report was [guard.last_line]")
	TEST_ASSERT(!guard.greet_member(owner), "A guard reported twice within three minutes") // OUTPOST_GUARD_REPORT_GAP
	settle_prison_air(home)
