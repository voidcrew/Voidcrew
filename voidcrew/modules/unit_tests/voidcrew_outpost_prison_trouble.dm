/**
 * Prison trouble: mood, the wing's stages and sparks, threats and swings at staff, fights and
 * spats, justified force and the mercy rule, the beaten state, riots with their wind-up, shivs,
 * clocks, sit-ins and transfers, breakouts, the serving hatch climb, escapes, the loose clock and
 * its fine, recapture, the turret rule, lock-ins and wrecked cells, and talking prisoners down.
 *
 * Voidcrew defines are not visible from test files, so tuning values appear as literals with the
 * define named beside them. Prisons are driven with tick() (or the trouble procs it calls) with
 * their own processing stopped; nobody is on the level, so the AI sleeps and the tests call the
 * blows (confront()) themselves. Threats, fights, spats and wrecks need someone on the level, so
 * those tests use prisoners whose AI counts as running. Other packages' inputs (needs, the wing's
 * state, who is home) are pinned or read through their procs. Fixtures are in
 * voidcrew_outpost_prison_helpers.dm; the trouble tests' own helpers are below.
 */

/// A prisoner whose AI counts as running, as if someone were on the level
/mob/living/basic/outpost_prisoner/awake_for_test

/mob/living/basic/outpost_prisoner/awake_for_test/ai_running()
	return TRUE

/// Like trouble_prisoner(), but awake: threats, fights, spats and wrecks need someone on the level
/datum/unit_test/voidcrew_outpost_management/proc/trouble_awake_prisoner(datum/outpost_prison/prison, turf/spot, personality = "chatty")
	var/mob/living/basic/outpost_prisoner/prisoner = new /mob/living/basic/outpost_prisoner/awake_for_test(spot)
	prison.admit(prisoner)
	prisoner.sentence_left = 3600
	prisoner.set_hunger(100)
	prisoner.set_uniform_grime(0)
	ADD_TRAIT(prisoner, TRAIT_IMMOBILIZED, TRAIT_SOURCE_UNIT_TESTS)
	prisoner.personality = personality
	prisoner.set_mood(70)
	return prisoner

/// Clicks `target` with a switched-on stun baton, not in combat mode: the stun
/datum/unit_test/voidcrew_outpost_management/proc/trouble_baton(mob/living/carbon/human/user, mob/living/target)
	var/obj/item/melee/baton/security/loaded/baton = user.get_active_held_item()
	if(!istype(baton))
		user.drop_all_held_items()
		baton = allocate(/obj/item/melee/baton/security/loaded)
		user.put_in_active_hand(baton)
	if(!baton.active)
		baton.attack_self(user)
	user.set_combat_mode(FALSE)
	click_wrapper(user, target)
	return baton

/// Puts `amount` credits in the claim's treasury, and nothing else
/datum/unit_test/voidcrew_outpost_management/proc/trouble_fund(obj/structure/overmap/dynamic/player_outpost/home, amount)
	home.ensure_home_services()
	var/datum/bank_account/treasury = home.treasury
	treasury.adjust_money(-treasury.account_balance, "Prison test")
	treasury.adjust_money(amount, "Prison test")
	return treasury

/// The mood drift a prisoner should have from the parts it is made of, as mood_drift_per_minute() adds them
/datum/unit_test/voidcrew_outpost_management/proc/trouble_expected_drift(mob/living/basic/outpost_prisoner/prisoner, extra_gain = 0, extra_loss = 0, subdued = FALSE)
	var/list/needs = prisoner.needs_mood_per_minute()
	var/list/wing = prisoner.wing_mood_per_minute()
	var/loss = needs[2] + (subdued ? 0 : wing[2]) + extra_loss
	if(subdued)
		loss *= 0.5
	return needs[1] + wing[1] + extra_gain - loss * prisoner.mood_scale()

// ===== MOOD =====

/datum/unit_test/voidcrew_outpost_prison_mood
	parent_type = /datum/unit_test/voidcrew_outpost_management

/datum/unit_test/voidcrew_outpost_prison_mood/Run()
	var/obj/structure/overmap/dynamic/player_outpost/home = trouble_test_claim("moodowner")
	TEST_ASSERT_NOTNULL(home, "The mood test prison did not load")
	var/datum/outpost_prison/prison = test_prison(home)
	var/mob/living/basic/outpost_prisoner/prisoner = trouble_prisoner(prison, prison_spot(home, 8, 8))
	var/mob/living/basic/outpost_prisoner/buddy = trouble_prisoner(prison, prison_spot(home, 7, 8))
	var/mob/living/basic/outpost_prisoner/fresh_arrival = allocate(/mob/living/basic/outpost_prisoner, prison_spot(home, 12, 8))
	TEST_ASSERT_EQUAL(fresh_arrival.mood, 70, "A prisoner does not start at 70 mood") // PRISONER_MOOD_START
	qdel(fresh_arrival)

	// Per minute, on top of what needs and the wing add (tested in the needs and conditions files).
	var/base = prisoner.mood_drift_per_minute()
	TEST_ASSERT(drift_is(prisoner, trouble_expected_drift(prisoner)), "A well kept prisoner drifts [base], not needs plus wing")
	prisoner.activity = new /datum/prisoner_activity/chat(prisoner)
	TEST_ASSERT(drift_is(prisoner, base + 1), "Chatting drifts [prisoner.mood_drift_per_minute()], not [base + 1]") // PRISONER_MOOD_ACTIVITY
	prisoner.end_activity(cancel_ai = FALSE)
	prisoner.sentence_left = 120
	TEST_ASSERT(drift_is(prisoner, base + 3), "Nearly out drifts [prisoner.mood_drift_per_minute()], not [base + 3]") // PRISONER_MOOD_RELEASE_SOON
	prisoner.sentence_left = 3600
	// Bolted in past two minutes: 6, and one more for each minute after.
	prisoner.locked_in_seconds = 150
	TEST_ASSERT(drift_is(prisoner, base - 6), "Bolted in 2.5 minutes drifts [prisoner.mood_drift_per_minute()], not [base - 6]") // PRISONER_MOOD_LOCKED_IN
	prisoner.locked_in_seconds = 200
	TEST_ASSERT(drift_is(prisoner, base - 7), "Bolted in 3.3 minutes drifts [prisoner.mood_drift_per_minute()], not [base - 7]")
	prisoner.locked_in_seconds = 0

	// Personality scales the losses: grumpy 1.4, nervous 1.2, chatty 1, quiet 0.9, cheerful 0.7.
	prisoner.set_hunger(10)
	var/list/scales = list("grumpy" = 1.4, "nervous" = 1.2, "chatty" = 1, "quiet" = 0.9, "cheerful" = 0.7)
	for(var/personality in scales)
		prisoner.personality = personality
		TEST_ASSERT_EQUAL(prisoner.mood_scale(), scales[personality], "A [personality] prisoner's losses scale by [prisoner.mood_scale()]")
		TEST_ASSERT(drift_is(prisoner, trouble_expected_drift(prisoner)), "A starving [personality] prisoner drifts [prisoner.mood_drift_per_minute()], not [trouble_expected_drift(prisoner)]")
		TEST_ASSERT(prisoner.mood_drift_per_minute() < base, "Starving did not lower a [personality] prisoner's drift")

	// In the quiet after a riot the wing's state costs nothing and the other losses are halved.
	prisoner.personality = "grumpy"
	prisoner.locked_in_seconds = 150
	prison.set_subdued(360) // PRISON_SUBDUED_TIME
	TEST_ASSERT(drift_is(prisoner, trouble_expected_drift(prisoner, extra_loss = 6, subdued = TRUE)), "A subdued starving prisoner drifts [prisoner.mood_drift_per_minute()], not [trouble_expected_drift(prisoner, extra_loss = 6, subdued = TRUE)]")
	prison.set_subdued(0)
	prisoner.locked_in_seconds = 0

	prisoner.set_mood(50)
	prisoner.adjust_mood(-10)
	TEST_ASSERT(abs(prisoner.mood - 36) < 0.01, "A grumpy prisoner's -10 came to [50 - prisoner.mood], not 14")
	prisoner.adjust_mood(10)
	TEST_ASSERT(abs(prisoner.mood - 46) < 0.01, "Personality scaled a gain")
	prisoner.personality = "chatty"
	prisoner.set_hunger(100)
	prisoner.set_mood(5)
	prisoner.adjust_mood(-50)
	TEST_ASSERT_EQUAL(prisoner.mood, 0, "Mood went below 0")
	prisoner.adjust_mood(500)
	TEST_ASSERT_EQUAL(prisoner.mood, 100, "Mood went above 100")

	// A minute of the prison's own clock applies the drift.
	prisoner.set_mood(70)
	prison.tick(60)
	TEST_ASSERT(abs(prisoner.mood - (70 + prisoner.mood_drift_per_minute())) < 0.05, "A minute left mood at [prisoner.mood], not [70 + prisoner.mood_drift_per_minute()]")

	// Arrivals take on 0.3 of the gap between the yard's mean mood and 70 (PRISONER_ARRIVAL_PULL).
	prisoner.served_seconds = 60
	buddy.served_seconds = 60
	set_moods(list(prisoner, buddy), 40)
	TEST_ASSERT(abs(prison.arrival_mood() - 61) < 0.01, "A yard at mood 40 sends arrivals in at [prison.arrival_mood()], not 61")
	set_moods(list(prisoner, buddy), 100)
	TEST_ASSERT(abs(prison.arrival_mood() - 79) < 0.01, "A yard at mood 100 sends arrivals in at [prison.arrival_mood()], not 79")
	buddy.set_mood(0)
	TEST_ASSERT(abs(prison.arrival_mood(buddy) - 79) < 0.01, "The newcomer counted in the yard's mood")
	buddy.served_seconds = 0
	TEST_ASSERT(abs(prison.arrival_mood() - 79) < 0.01, "Someone who had not served a moment counted in the yard's mood")
	prisoner.served_seconds = 0
	TEST_ASSERT_EQUAL(prison.arrival_mood(), 70, "An empty yard does not send arrivals in at 70")
	buddy.set_mood(70)

	// An unprovoked hit by staff -15, and the wing gets tenser.
	prisoner.set_mood(66)
	var/mob/living/carbon/human/warden = make_player(prison_spot(home, 9, 8), "moodowner")
	var/spike_before = prison.tension_spike
	hit_with_toolbox(warden, prisoner)
	TEST_ASSERT(prisoner.health < 100, "The toolbox missed")
	TEST_ASSERT(abs(prisoner.mood - 51) < 0.01, "A hit by staff left mood at [prisoner.mood], not 51") // PRISONER_MOOD_HIT_BY_STAFF
	TEST_ASSERT(prison.tension_spike >= spike_before + 5, "A hit by staff did not raise tension") // PRISON_SPIKE_STAFF_HIT
	// Another prisoner's punch is not staff.
	var/mood_before = prisoner.mood
	buddy.strike(prisoner)
	TEST_ASSERT(abs(prisoner.mood - mood_before) < 0.01, "A punch from another prisoner counted as staff")
	settle_prison_air(home)

// ===== STAGES AND SPARKS =====

/datum/unit_test/voidcrew_outpost_prison_stages
	parent_type = /datum/unit_test/voidcrew_outpost_management

/datum/unit_test/voidcrew_outpost_prison_stages/Run()
	var/obj/structure/overmap/dynamic/player_outpost/home = trouble_test_claim("stageowner")
	TEST_ASSERT_NOTNULL(home, "The stage test prison did not load")
	var/datum/outpost_prison/prison = test_prison(home)
	prison.crew_home_override = TRUE
	var/mob/living/basic/outpost_prisoner/first = trouble_prisoner(prison, prison_spot(home, 7, 8))
	var/mob/living/basic/outpost_prisoner/second = trouble_prisoner(prison, prison_spot(home, 11, 8))
	var/list/both = list(first, second)
	var/mob/living/carbon/human/warden = make_player(prison_spot(home, 7, 7), "stageowner")

	// Tension is 100 minus the mean mood; calm below 40, grumbling from 40, restless from 60.
	first.set_mood(80)
	second.set_mood(60)
	prison.update_stage(1)
	TEST_ASSERT(abs(prison.tension - 30) < 0.01, "Moods 80 and 60 gave tension [prison.tension], not 30")
	TEST_ASSERT_EQUAL(prison.stage, "calm", "Tension 30 is [prison.stage]")
	set_moods(both, 60)
	prison.update_stage(1)
	TEST_ASSERT_EQUAL(prison.stage, "grumbling", "Tension 40 is [prison.stage]") // PRISON_TENSION_GRUMBLING
	set_moods(both, 40)
	prison.update_stage(1)
	TEST_ASSERT_EQUAL(prison.stage, "restless", "Tension 60 is [prison.stage]") // PRISON_TENSION_RESTLESS
	// Turning restless tells the crew, once per 5 minutes (PRISON_RESTLESS_ANNOUNCE_GAP).
	var/list/newest = prison.entries[1]
	TEST_ASSERT(findtext(newest["text"], "restless"), "Turning restless was not logged: [newest["text"]]")
	var/log_length = length(prison.entries)

	// Stages hold until tension falls 5 below their line (PRISON_TENSION_HYSTERESIS).
	set_moods(both, 44)
	prison.update_stage(1)
	TEST_ASSERT_EQUAL(prison.stage, "restless", "Tension 56 dropped a restless wing to [prison.stage]")
	set_moods(both, 46)
	prison.update_stage(1)
	TEST_ASSERT_EQUAL(prison.stage, "grumbling", "Tension 54 left the wing [prison.stage]")
	set_moods(both, 44)
	prison.update_stage(1)
	TEST_ASSERT_EQUAL(prison.stage, "grumbling", "Tension 56 took a grumbling wing to [prison.stage]")
	set_moods(both, 40)
	prison.update_stage(1)
	TEST_ASSERT_EQUAL(prison.stage, "restless", "Tension 60 did not make the wing restless again")
	TEST_ASSERT_EQUAL(length(prison.entries), log_length, "The restless notice came again within 5 minutes")
	set_moods(both, 64)
	prison.update_stage(1)
	TEST_ASSERT_EQUAL(prison.stage, "grumbling", "Tension 36 left the wing [prison.stage]")
	set_moods(both, 66)
	prison.update_stage(1)
	TEST_ASSERT_EQUAL(prison.stage, "calm", "Tension 34 left the wing [prison.stage]")
	set_moods(both, 61)
	prison.update_stage(1)
	TEST_ASSERT_EQUAL(prison.stage, "calm", "Tension 39 took a calm wing to [prison.stage]")

	// Event spikes add to it and decay by 0.25 a second (PRISON_SPIKE_DECAY).
	set_moods(both, 70)
	prison.tension_spike = 25
	prison.update_stage(1)
	TEST_ASSERT(abs(prison.tension - 55) < 0.01, "A 25 spike on tension 30 gave [prison.tension]")
	TEST_ASSERT_EQUAL(prison.stage, "grumbling", "Tension 55 is [prison.stage]")
	prison.trouble_tick(40)
	TEST_ASSERT(abs(prison.tension_spike - 15) < 0.01, "The spike was [prison.tension_spike] after 40 seconds, not 15")
	prison.tension_spike = 0

	// A riot needs tension 75 or more held for 45 seconds (PRISON_TENSION_RIOT, PRISON_RIOT_HOLD).
	// The hold shows: riot imminent on the console, and the crew is told.
	set_moods(both, 26)
	prison.update_stage(1)
	TEST_ASSERT(!prison.riot_imminent && !prison.riot_hold, "Tension 74 started the riot hold")
	set_moods(both, 25)
	prison.update_stage(1)
	TEST_ASSERT(prison.riot_imminent, "Tension 75 did not make a riot imminent")
	TEST_ASSERT_EQUAL(prison.alarm_state()[1], "riot_imminent", "A brewing riot shows the [prison.alarm_state()[1]] alarm")
	TEST_ASSERT(prison.trouble_payload()["riot_imminent"], "The console's trouble block does not show the riot imminent")
	newest = prison.entries[1]
	TEST_ASSERT(findtext(newest["text"], "brewing"), "A brewing riot was not logged: [newest["text"]]")
	prison.update_stage(43)
	TEST_ASSERT(!prison.riot_active, "A riot started before tension held for 45 seconds")
	TEST_ASSERT_EQUAL(prison.stage, "restless", "Tension 75 before the hold is [prison.stage]")
	set_moods(both, 40)
	prison.update_stage(1)
	TEST_ASSERT(!prison.riot_imminent, "Dropping below 75 left the riot imminent")
	set_moods(both, 10)
	prison.update_stage(44)
	TEST_ASSERT(!prison.riot_active, "Dropping below 75 did not reset the hold")
	prison.update_stage(1)
	TEST_ASSERT(prison.riot_active, "Forty-five seconds at tension 90 started no riot")
	TEST_ASSERT_EQUAL(prison.stage, "riot", "A riot's stage is [prison.stage]")
	TEST_ASSERT(!prison.riot_imminent, "A riot on still shows as imminent")
	prison.admin_calm()
	TEST_ASSERT(!prison.riot_active, "Calming the wing left the riot on")
	TEST_ASSERT(prison.subdued_left > 0, "The end of a riot did not subdue the wing")
	prison.set_subdued(0)

	// Sparks start one at once, but only while restless, and never while subdued.
	set_moods(both, 80)
	prison.tension_spike = 0
	prison.update_stage(0)
	TEST_ASSERT(!prison.trouble_event(10, "test spark"), "A spark in a calm wing started a riot")
	TEST_ASSERT(prison.tension_spike >= 10, "A spark did not raise tension")
	prison.tension_spike = 0
	set_moods(both, 35)
	prison.update_stage(0)
	TEST_ASSERT_EQUAL(prison.stage, "restless", "Tension 65 is [prison.stage]")
	prison.set_subdued(100)
	TEST_ASSERT(!prison.trouble_event(10, "test spark"), "A spark in a subdued wing started a riot")
	TEST_ASSERT(!prison.start_riot("test"), "A riot started in a subdued wing")
	prison.set_subdued(0)
	TEST_ASSERT(prison.trouble_event(10, "test spark"), "A spark in a restless wing started no riot")
	prison.admin_calm()
	prison.set_subdued(0)

	// Staff beating a prisoner down while restless: the other one riots. (The calm just now would
	// otherwise make these hits the end of the same subdual.)
	for(var/mob/living/basic/outpost_prisoner/prisoner as anything in both)
		prisoner.trouble_ended_at = 0
	prison.tension_spike = 0
	set_moods(both, 35)
	prison.update_stage(0)
	first.adjustBruteLoss(80)
	hit_with_toolbox(warden, first)
	TEST_ASSERT(first.beaten_left > 0, "A prisoner at 20 health hit with a toolbox did not collapse")
	TEST_ASSERT(first.beaten_by_staff, "The collapse was not put down to staff")
	TEST_ASSERT(prison.riot_active, "A prisoner beaten down by staff in a restless wing started no riot")
	TEST_ASSERT_EQUAL(second.trouble, "riot", "The other prisoner did not riot")
	TEST_ASSERT_NULL(first.trouble, "A beaten prisoner joined the riot")
	prison.admin_calm()
	prison.set_subdued(0)
	first.adjustBruteLoss(-100)
	first.recover()

	// Staff killing one who is down while restless: the same, and no fine.
	var/datum/bank_account/treasury = trouble_fund(home, 5000)
	second.apply_damage(90, BRUTE)
	TEST_ASSERT(second.beaten_left > 0, "A prisoner at 10 health did not collapse")
	TEST_ASSERT(!second.beaten_by_staff, "A collapse with no staff about was put down to staff")
	prison.tension_spike = 0
	set_moods(both, 35)
	prison.update_stage(0)
	TEST_ASSERT(!prison.riot_active, "A collapse with no staff about started a riot")
	warden.forceMove(prison_spot(home, 11, 7))
	hit_with_toolbox(warden, second)
	TEST_ASSERT_EQUAL(second.stat, DEAD, "A downed prisoner at 10 health survived a toolbox")
	TEST_ASSERT(second.death_blamed, "The death was not put down to staff")
	TEST_ASSERT_EQUAL(treasury.account_balance, 5000, "A death in custody was fined [5000 - treasury.account_balance]")
	TEST_ASSERT(prison.riot_active, "Staff killing a prisoner in a restless wing started no riot")
	TEST_ASSERT_EQUAL(first.trouble, "riot", "The surviving prisoner did not riot")
	prison.admin_calm()
	settle_prison_air(home)

// ===== THREATS =====

/datum/unit_test/voidcrew_outpost_prison_threats
	parent_type = /datum/unit_test/voidcrew_outpost_management

/datum/unit_test/voidcrew_outpost_prison_threats/Run()
	var/obj/structure/overmap/dynamic/player_outpost/home = trouble_test_claim("threatowner")
	TEST_ASSERT_NOTNULL(home, "The threat test prison did not load")
	var/datum/outpost_prison/prison = test_prison(home)
	var/mob/living/basic/outpost_prisoner/prisoner = trouble_awake_prisoner(prison, prison_spot(home, 8, 8))
	var/mob/living/basic/outpost_prisoner/dozing = trouble_prisoner(prison, prison_spot(home, 12, 8))
	var/mob/living/carbon/human/warden = make_player(prison_spot(home, 10, 8), "threatowner")

	// 35 or more: never.
	prisoner.set_mood(40)
	for(var/i in 1 to 5)
		prison.tick(1)
	TEST_ASSERT_NULL(prisoner.threat_ref, "A prisoner at mood 40 threatened staff") // PRISONER_THREAT_MOOD

	// Threats need the AI running: with nobody on the level, nobody squares up.
	dozing.set_mood(10)
	warden.forceMove(prison_spot(home, 11, 8))
	prison.tick(1)
	TEST_ASSERT_NULL(dozing.threat_ref, "A prisoner whose AI sleeps threatened staff")
	dozing.set_mood(70)
	warden.forceMove(prison_spot(home, 10, 8))

	// Below 35, staff within two tiles in the cell block get a threat first.
	prisoner.set_mood(25)
	prison.tick(1)
	TEST_ASSERT_EQUAL(prisoner.threat_ref?.resolve(), warden, "A prisoner at mood 25 did not threaten staff two tiles away")
	TEST_ASSERT_EQUAL(prisoner.dir, get_dir(prisoner, warden), "The prisoner did not face who they threatened")
	TEST_ASSERT(is_line_for(prisoner.last_line, "threaten_staff"), "The threat was not a threaten_staff line: [prisoner.last_line]")
	TEST_ASSERT_EQUAL(warden.getBruteLoss(), 0, "The threat itself hurt someone")
	// Staff stepping away ends it.
	warden.forceMove(prison_spot(home, 13, 8))
	prison.tick(1)
	TEST_ASSERT_NULL(prisoner.threat_ref, "The threat went on with staff five tiles away")

	// Staff outside the cell block, even two tiles off through a window, are left alone.
	prisoner.threat_cooldown = 0
	prisoner.forceMove(prison_spot(home, 8, 7))
	warden.forceMove(prison_spot(home, 8, 5))
	prison.tick(1)
	TEST_ASSERT_NULL(prisoner.threat_ref, "A prisoner threatened staff in the office")

	// Nobody squares up to someone who just fed them (PRISONER_HELPED_GRACE), and a threat at them ends.
	prisoner.forceMove(prison_spot(home, 8, 8))
	warden.forceMove(prison_spot(home, 9, 8))
	prisoner.threat_cooldown = 0
	prisoner.set_mood(20)
	prison.tick(1)
	TEST_ASSERT_EQUAL(prisoner.threat_ref?.resolve(), warden, "A prisoner at mood 20 beside staff did not threaten them")
	warden.drop_all_held_items()
	var/obj/item/food/meal = allocate(/obj/item/food/prison_ration)
	warden.put_in_active_hand(meal)
	warden.set_combat_mode(FALSE)
	click_wrapper(warden, prisoner)
	TEST_ASSERT(prisoner.recently_helped_by(warden), "Offering food did not count as help")
	TEST_ASSERT_NULL(prisoner.threat_ref, "A threat went on at someone who offered food")
	warden.drop_all_held_items()
	for(var/i in 1 to 5)
		prisoner.threat_cooldown = 0
		prison.tick(1)
		TEST_ASSERT_NULL(prisoner.threat_ref, "A prisoner threatened someone who helped them seconds ago")
	LAZYSET(prisoner.helped_by, REF(warden), world.time - 21 SECONDS)
	prisoner.threat_cooldown = 0
	prison.tick(1)
	TEST_ASSERT_EQUAL(prisoner.threat_ref?.resolve(), warden, "The helper's grace outlasted 20 seconds")

	// Four seconds on (PRISONER_THREAT_TIME) the threat may become a swing: 5-8 brute when next to them.
	var/swung = FALSE
	for(var/attempt in 1 to 30)
		prisoner.cancel_threat()
		prisoner.threat_cooldown = 0
		prisoner.set_mood(10)
		prison.tick(1)
		TEST_ASSERT_NOTNULL(prisoner.threat_ref, "An angry prisoner beside staff did not threaten them")
		var/before = warden.getBruteLoss()
		prison.tick(4)
		TEST_ASSERT_NULL(prisoner.threat_ref, "The threat did not end after four seconds")
		if(warden.getBruteLoss() > before)
			var/dealt = warden.getBruteLoss() - before
			TEST_ASSERT(dealt >= 5 && dealt <= 8, "A punch did [dealt] brute, not 5-8") // PRISONER_PUNCH_MIN/MAX
			TEST_ASSERT(prisoner.threat_cooldown > 0, "A swing started no cooldown")
			swung = TRUE
			break
	TEST_ASSERT(swung, "An angry prisoner never swung in 30 threats")
	warden.fully_heal()

	// The mood gate holds all the way to the swing.
	prisoner.cancel_threat()
	prisoner.threat_cooldown = 0
	prisoner.set_mood(20)
	prison.tick(1)
	TEST_ASSERT_NOTNULL(prisoner.threat_ref, "A prisoner at mood 20 did not threaten")
	prisoner.set_mood(40)
	var/before_gate = warden.getBruteLoss()
	prison.tick(4)
	TEST_ASSERT_NULL(prisoner.threat_ref, "A threat went on after mood rose to 40")
	TEST_ASSERT_EQUAL(warden.getBruteLoss(), before_gate, "A prisoner at mood 40 swung")
	for(var/i in 1 to 20)
		TEST_ASSERT(!prisoner.decide_swing(warden), "A prisoner at mood 40 decided to swing")

	// Talking them down ends a threat (PRISONER_TALK_TIME).
	prisoner.cancel_threat()
	prisoner.threat_cooldown = 0
	prisoner.set_mood(25)
	prison.tick(1)
	TEST_ASSERT_EQUAL(prisoner.threat_ref?.resolve(), warden, "A prisoner at mood 25 did not threaten before the talk")
	TEST_ASSERT(prisoner.talk_down(warden), "Talking to a threatening prisoner did nothing")
	TEST_ASSERT_NULL(prisoner.threat_ref, "Talking a prisoner down did not end the threat")
	settle_prison_air(home)

// ===== FIGHTS, SPATS AND THE BEATEN STATE =====

/datum/unit_test/voidcrew_outpost_prison_fights
	parent_type = /datum/unit_test/voidcrew_outpost_management

/datum/unit_test/voidcrew_outpost_prison_fights/Run()
	var/obj/structure/overmap/dynamic/player_outpost/home = trouble_test_claim("fightowner")
	TEST_ASSERT_NOTNULL(home, "The fight test prison did not load")
	var/datum/outpost_prison/prison = test_prison(home)
	var/mob/living/basic/outpost_prisoner/first = trouble_awake_prisoner(prison, prison_spot(home, 8, 8))
	var/mob/living/basic/outpost_prisoner/second = trouble_awake_prisoner(prison, prison_spot(home, 10, 8))
	var/mob/living/basic/outpost_prisoner/third = trouble_awake_prisoner(prison, prison_spot(home, 3, 10))
	var/mob/living/basic/outpost_prisoner/fourth = trouble_awake_prisoner(prison, prison_spot(home, 4, 10))
	var/mob/living/carbon/human/warden = make_player(prison_spot(home, 8, 4), "fightowner")
	var/list/everyone = list(first, second, third, fourth)

	// Two prisoners below 40 within three tiles may start one; content ones never do.
	set_moods(everyone, 50)
	for(var/i in 1 to 20)
		TEST_ASSERT_NULL(prison.try_start_fight(), "Prisoners at mood 50 started a fight") // PRISONER_FIGHT_MOOD
	// Nor do angry ones whose AI sleeps: nobody on the level, nobody moves.
	var/mob/living/basic/outpost_prisoner/dozing = trouble_prisoner(prison, prison_spot(home, 14, 8))
	var/mob/living/basic/outpost_prisoner/dozing_too = trouble_prisoner(prison, prison_spot(home, 15, 8))
	set_moods(list(dozing, dozing_too), 20)
	for(var/i in 1 to 30)
		TEST_ASSERT_NULL(prison.try_start_fight(), "Two prisoners whose AI sleeps started a fight")
	qdel(dozing)
	qdel(dozing_too)

	first.set_mood(30)
	second.set_mood(30)
	var/datum/outpost_prison_fight/brawl
	for(var/i in 1 to 150)
		brawl = prison.try_start_fight()
		if(brawl)
			break
	TEST_ASSERT_NOTNULL(brawl, "Two prisoners at mood 30 two tiles apart never started a fight") // PRISONER_FIGHT_CHANCE
	TEST_ASSERT(first.fight == brawl && second.fight == brawl, "The fighters do not know their fight")
	TEST_ASSERT(first.trouble == "fight" && second.trouble == "fight", "The fighters are not in fight trouble")
	TEST_ASSERT_EQUAL(brawl.cause, "none", "Two fed prisoners fought over [brawl.cause]")
	TEST_ASSERT(prison.tension_spike >= 10, "A fight did not raise tension") // PRISON_SPIKE_FIGHT
	TEST_ASSERT_EQUAL(prison.prisoner_pay_rate(first), 0, "A fighter earned a stipend")
	TEST_ASSERT(abs(third.mood - 45) < 0.01, "Seeing a fight left an onlooker at [third.mood], not 45") // PRISONER_MOOD_SAW_FIGHT

	// One fight at a time.
	set_moods(list(third, fourth), 20)
	for(var/i in 1 to 50)
		TEST_ASSERT_NULL(prison.try_start_fight(), "A second fight started while one was on")

	// They argue for ten seconds (PRISONER_ARGUE_TIME) before anyone swings.
	second.forceMove(prison_spot(home, 9, 8))
	var/grime_before = first.uniform_grime
	TEST_ASSERT(!first.confront(second), "A blow landed during the argument")
	TEST_ASSERT_EQUAL(second.health, 100, "The argument hurt someone")
	prison.tick(9)
	TEST_ASSERT(!brawl.fighting, "Nine seconds of arguing turned into a fight")
	prison.tick(1)
	TEST_ASSERT(brawl.fighting, "Ten seconds of arguing did not turn into a fight")
	TEST_ASSERT(is_line_for(first.last_line, "fight_argue_none") || is_line_for(second.last_line, "fight_argue_none") || is_line_for(first.last_line, "fight_argue") || is_line_for(second.last_line, "fight_argue"), "Nobody said a fight_argue line")
	TEST_ASSERT(first.uniform_grime >= grime_before + 20 - 0.5, "The scuffle did not dirty a uniform ([grime_before] to [first.uniform_grime])") // PRISONER_FIGHT_GRIME

	// Blows of 3-6 (PRISONER_FIGHT_HIT) until one yields at 40% or less (PRISONER_FIGHT_YIELD).
	for(var/i in 1 to 40)
		if(second.beaten_left > 0)
			break
		var/health_before = second.health
		TEST_ASSERT(first.confront(second), "A fighter could not land a blow")
		var/dealt = health_before - second.health
		TEST_ASSERT(dealt >= 3 && dealt <= 6, "A fighter's blow did [dealt], not 3-6")
		TEST_ASSERT(second.stat != DEAD, "A prisoner's blows killed another")
	TEST_ASSERT(second.beaten_left > 0, "A fight never ended with someone yielding")
	TEST_ASSERT(second.health_factor() <= 40 && second.health_factor() > 30, "The loser yielded at [second.health_factor()]%, not just under 40%")
	TEST_ASSERT_EQUAL(second.beaten_left, 20, "The loser is down for [second.beaten_left] s, not 20") // PRISONER_FIGHT_YIELD_TIME
	TEST_ASSERT(second.can_be_dragged(), "A prisoner who yielded is standing")
	TEST_ASSERT(!second.routine_allowed(), "A prisoner who yielded kept up their routine")
	TEST_ASSERT_NULL(first.fight, "The fight went on after one yielded")
	TEST_ASSERT(!(brawl in prison.fights), "The finished fight stayed on the list")
	TEST_ASSERT(isnull(first.trouble) && isnull(second.trouble), "The fighters are still in fight trouble")
	TEST_ASSERT_EQUAL(first.fight_cooldown, 300, "A finished fight left a [first.fight_cooldown] s cooldown, not 300") // PRISONER_FIGHT_COOLDOWN
	TEST_ASSERT_EQUAL(prison.fight_gap_left, 180, "A finished fight left a [prison.fight_gap_left] s gap, not 180") // PRISON_FIGHT_GAP
	// Nobody puts the boot in on a prisoner who is down.
	var/health_down = second.health
	TEST_ASSERT(!first.strike(second), "A prisoner hit another who was down")
	TEST_ASSERT_EQUAL(second.health, health_down, "A downed prisoner took a prisoner's blow")

	// No other pair may start one for three minutes.
	for(var/i in 1 to 50)
		TEST_ASSERT_NULL(prison.try_start_fight(), "A fight started inside the gap after the last")
	// The loser gets up after 20 seconds.
	prison.tick(19)
	TEST_ASSERT(second.beaten_left > 0, "The loser got up early")
	prison.tick(1)
	TEST_ASSERT_EQUAL(second.beaten_left, 0, "The loser was still down after 20 seconds")
	TEST_ASSERT(!second.can_be_dragged(), "The loser got up but is still down")

	// After the gap, two hungry prisoners fight over the food.
	prison.fight_gap_left = 0
	third.set_hunger(20)
	fourth.set_hunger(20)
	set_moods(list(third, fourth), 20)
	var/datum/outpost_prison_fight/food_fight
	for(var/i in 1 to 150)
		food_fight = prison.try_start_fight()
		if(food_fight)
			break
	TEST_ASSERT_NOTNULL(food_fight, "Two hungry prisoners never started a fight after the gap")
	TEST_ASSERT_EQUAL(food_fight.cause, "food", "Two hungry prisoners fought over [food_fight.cause]")
	// Staff stunning one ends a fight.
	prison.tick(10)
	TEST_ASSERT(food_fight.fighting, "The food fight never got past arguing")
	fourth.adjustStaminaLoss(200)
	TEST_ASSERT_NULL(third.fight, "A fight went on after staff stunned one fighter")
	TEST_ASSERT(isnull(third.trouble) && isnull(fourth.trouble), "Fight trouble outlasted the stun")
	fourth.setStaminaLoss(0)

	// Even a standing prisoner at 3 health is left alive by a punch, and collapses.
	third.adjustBruteLoss(97)
	third.forceMove(prison_spot(home, 7, 8))
	first.strike(third)
	TEST_ASSERT(third.stat != DEAD && third.health >= 1, "A punch killed a prisoner at 3 health")
	TEST_ASSERT(third.beaten_left > 0, "A prisoner at 1-3 health did not collapse")
	// Treated above 40% they get up; untreated, after two minutes (PRISONER_BEATEN_TIME).
	third.adjustBruteLoss(-(third.getBruteLoss() - 50))
	prison.tick(1)
	TEST_ASSERT_EQUAL(third.beaten_left, 0, "Treatment to 50% did not get a beaten prisoner up")
	TEST_ASSERT(is_line_for(third.last_line, "recovered"), "The recovered prisoner said no recovered line: [third.last_line]")
	// Only staff can kill a prisoner who is down.
	third.adjustBruteLoss(-third.getBruteLoss())
	third.apply_damage(95, BRUTE)
	TEST_ASSERT(third.beaten_left > 0, "A prisoner at 5 health did not collapse")
	TEST_ASSERT(is_line_for(third.last_line, "beaten"), "The beaten prisoner said no beaten line: [third.last_line]")
	warden.forceMove(prison_spot(home, 7, 7))
	for(var/i in 1 to 5)
		if(third.stat == DEAD)
			break
		hit_with_toolbox(warden, third)
	TEST_ASSERT_EQUAL(third.stat, DEAD, "Staff could not finish off a downed prisoner")
	prison.admin_calm()
	prison.set_subdued(0)

	// Spats: two prisoners under 75 near each other trade two or three lines, no blows, no mood;
	// one per four minutes in the wing (PRISONER_SPAT_MOOD, PRISON_SPAT_GAP).
	first.fight_cooldown = 300
	second.forceMove(prison_spot(home, 10, 8))
	set_moods(list(first, second), 80)
	prison.spat_lines_left = 0
	prison.spat_gap_left = 0
	for(var/i in 1 to 100)
		TEST_ASSERT(!prison.try_start_spat(), "Two content prisoners started a spat")
	set_moods(list(first, second), 70)
	var/spat = FALSE
	for(var/i in 1 to 400)
		if(prison.try_start_spat())
			spat = TRUE
			break
	TEST_ASSERT(spat, "Two prisoners at mood 70 never argued")
	TEST_ASSERT(prison.spat_lines_left >= 1 && prison.spat_lines_left <= 2, "A spat has [prison.spat_lines_left] lines left after the first")
	TEST_ASSERT_EQUAL(prison.spat_lines_said, 1, "A spat opened with [prison.spat_lines_said] lines")
	TEST_ASSERT_EQUAL(prison.spat_gap_left, 240, "A spat left a [prison.spat_gap_left] s gap, not 240")
	prison.fights_tick(3)
	prison.fights_tick(3)
	TEST_ASSERT_EQUAL(prison.spat_lines_left, 0, "A spat went on past three lines")
	TEST_ASSERT(isnull(first.trouble) && isnull(second.trouble) && !length(prison.fights), "A spat turned into a fight")
	TEST_ASSERT(abs(first.mood - 70) < 0.01 && abs(second.mood - 70) < 0.01, "A spat changed moods")
	for(var/i in 1 to 100)
		TEST_ASSERT(!prison.try_start_spat(), "A second spat started inside four minutes")
	settle_prison_air(home)

// ===== JUSTIFIED FORCE AND THE MERCY RULE =====

/datum/unit_test/voidcrew_outpost_prison_force
	parent_type = /datum/unit_test/voidcrew_outpost_management

/datum/unit_test/voidcrew_outpost_prison_force/Run()
	var/obj/structure/overmap/dynamic/player_outpost/home = trouble_test_claim("forceowner")
	TEST_ASSERT_NOTNULL(home, "The force test prison did not load")
	var/datum/outpost_prison/prison = test_prison(home)
	var/mob/living/basic/outpost_prisoner/rioter = trouble_prisoner(prison, prison_spot(home, 8, 8))
	var/mob/living/basic/outpost_prisoner/fighter = trouble_prisoner(prison, prison_spot(home, 10, 8))
	var/mob/living/basic/outpost_prisoner/rival = trouble_prisoner(prison, prison_spot(home, 11, 8))
	var/mob/living/basic/outpost_prisoner/plain = trouble_prisoner(prison, prison_spot(home, 4, 10))
	var/mob/living/carbon/human/warden = make_player(prison_spot(home, 9, 8), "forceowner")

	// A rioter hit by staff loses no mood and adds no tension.
	rioter.set_mood(45)
	rioter.start_rioting()
	prison.tension_spike = 0
	TEST_ASSERT(!rioter.hit_by_staff(warden), "Hitting a rioter cost mood")
	TEST_ASSERT(abs(rioter.mood - 45) < 0.01 && !prison.tension_spike, "Hitting a rioter cost [45 - rioter.mood] mood and [prison.tension_spike] tension")
	TEST_ASSERT(rioter.last_hit_justified, "Hitting a rioter was not justified")
	// A baton stops a rioter's blows at once: the shiv drops and they pause (PRISONER_BATON_STOP).
	trouble_baton(warden, rioter)
	TEST_ASSERT(!rioter.has_shiv(), "A batoned rioter kept the shiv")
	TEST_ASSERT_NOTNULL(locate(/obj/item/knife/shiv) in rioter.loc, "A batoned rioter dropped no shiv")
	TEST_ASSERT(rioter.baton_stop_until > world.time, "A baton hit did not stop the rioter's blows")
	TEST_ASSERT(!rioter.confront(warden), "A batoned rioter struck at once")
	TEST_ASSERT(rioter.mood >= 45 - 0.01, "Batoning a rioter cost [45 - rioter.mood] mood")
	// Finishing a subdual a moment after the riot left them is the same subdual.
	rioter.calm_down()
	rioter.staff_hit_cooldown = 0
	var/calm_mood = rioter.mood
	TEST_ASSERT(!rioter.hit_by_staff(warden), "Hitting a rioter a moment after they calmed cost mood")
	TEST_ASSERT(abs(rioter.mood - calm_mood) < 0.01, "Hitting a rioter a moment after they calmed cost [calm_mood - rioter.mood]")

	// A fighter, even while still arguing.
	fighter.set_mood(30)
	TEST_ASSERT_NOTNULL(prison.start_fight(fighter, rival), "The test fight did not start")
	TEST_ASSERT(!fighter.hit_by_staff(warden), "Hitting a fighter cost mood")
	TEST_ASSERT(abs(fighter.mood - 30) < 0.01, "Hitting a fighter cost [30 - fighter.mood] mood")
	prison.end_fight(fighter.fight)

	// Someone who just punched you (PRISONER_PROVOKED_TIME).
	plain.set_mood(60)
	warden.forceMove(prison_spot(home, 5, 10))
	plain.strike(warden)
	TEST_ASSERT(!plain.hit_by_staff(warden), "Hitting back at a prisoner who just punched you cost mood")
	TEST_ASSERT(abs(plain.mood - 60) < 0.01, "Hitting back cost [60 - plain.mood] mood")
	// Unprovoked, from someone else: 15, once per 10 seconds (PRISONER_STAFF_HIT_COOLDOWN).
	var/mob/living/carbon/human/bystander = make_player(prison_spot(home, 4, 11), "forcebystander")
	plain.staff_hit_cooldown = 0
	prison.tension_spike = 0
	TEST_ASSERT(plain.hit_by_staff(bystander), "An unprovoked hit cost no mood")
	TEST_ASSERT(abs(plain.mood - 45) < 0.01, "An unprovoked hit left mood at [plain.mood], not 45")
	TEST_ASSERT(prison.tension_spike >= 5, "An unprovoked hit did not raise tension")
	TEST_ASSERT(!plain.hit_by_staff(bystander), "A second hit inside 10 seconds cost mood again")
	TEST_ASSERT(abs(plain.mood - 45) < 0.01, "A second hit inside 10 seconds left mood at [plain.mood]")
	plain.staff_hit_cooldown = 0
	TEST_ASSERT(plain.hit_by_staff(bystander), "An unprovoked hit after the cooldown cost no mood")
	TEST_ASSERT(abs(plain.mood - 30) < 0.01, "The next unprovoked hit left mood at [plain.mood], not 30")
	// Creatures and NPCs are not staff; machines (turrets) take the blame for a death but cost no mood.
	var/mob/living/basic/carp/fish = allocate(/mob/living/basic/carp, prison_spot(home, 4, 9))
	plain.staff_hit_cooldown = 0
	plain.last_staff_hit = 0
	TEST_ASSERT(!plain.hit_by_staff(fish), "A carp counted as staff")
	TEST_ASSERT_EQUAL(plain.last_staff_hit, 0, "A carp's bite was put down to staff")
	var/obj/machinery/button/machine = allocate(/obj/machinery/button, prison_spot(home, 4, 9))
	TEST_ASSERT(!plain.hit_by_staff(machine), "A machine's hit cost mood")
	TEST_ASSERT_EQUAL(plain.last_staff_hit, world.time, "A machine's hit was not put down to staff")
	TEST_ASSERT(abs(plain.mood - 30) < 0.01, "A machine's hit changed mood")

	// No single blow kills a standing prisoner: 150 damage leaves 1 health, collapsed.
	var/datum/bank_account/treasury = trouble_fund(home, 5000)
	plain.last_staff_hit = 0
	plain.apply_damage(150, BRUTE)
	TEST_ASSERT_EQUAL(plain.stat, CONSCIOUS, "150 damage killed a standing prisoner")
	TEST_ASSERT_EQUAL(plain.health, 1, "150 damage left a standing prisoner at [plain.health] health, not 1")
	TEST_ASSERT(plain.beaten_left > 0 && plain.can_be_dragged(), "A prisoner spared a killing blow did not collapse")
	TEST_ASSERT_EQUAL(treasury.account_balance, 5000, "A blow nobody was blamed for cost the treasury")
	// A hit on the downed one kills, and staff get the blame, but no fine.
	warden.forceMove(prison_spot(home, 5, 10))
	hit_with_toolbox(warden, plain)
	TEST_ASSERT_EQUAL(plain.stat, DEAD, "A hit on a downed prisoner at 1 health did not kill")
	TEST_ASSERT(plain.death_blamed, "The death was not put down to staff")
	TEST_ASSERT_EQUAL(treasury.account_balance, 5000, "A death in custody was fined [5000 - treasury.account_balance]")
	var/list/newest = prison.entries[1]
	TEST_ASSERT(findtext(newest["text"], "The yard blames staff for [plain.real_name]'s death"), "The staff's blame was not logged: [newest["text"]]")
	// An experiment's subject dies on the experiment's account, not staff's.
	rival.forceMove(prison_spot(home, 6, 10))
	rival.experiment_subject = TRUE
	rival.apply_damage(150, BRUTE)
	TEST_ASSERT_EQUAL(rival.health, 1, "The subject was not spared the killing blow")
	for(var/i in 1 to 3)
		if(rival.stat == DEAD)
			break
		hit_with_toolbox(warden, rival)
	TEST_ASSERT_EQUAL(rival.stat, DEAD, "Staff could not finish off the downed subject")
	TEST_ASSERT_EQUAL(treasury.account_balance, 5000, "An experiment subject's death was fined")
	// Forced damage (admin tools) is not spared.
	fighter.adjustBruteLoss(200, forced = TRUE)
	TEST_ASSERT_EQUAL(fighter.stat, DEAD, "Forced damage was spared")
	settle_prison_air(home)

// ===== RIOTS =====

/datum/unit_test/voidcrew_outpost_prison_riot
	parent_type = /datum/unit_test/voidcrew_outpost_management

/datum/unit_test/voidcrew_outpost_prison_riot/Run()
	var/obj/structure/overmap/dynamic/player_outpost/home = trouble_test_claim("riotowner")
	TEST_ASSERT_NOTNULL(home, "The riot test prison did not load")
	var/datum/outpost_prison/prison = test_prison(home)
	prison.crew_home_override = TRUE
	var/obj/machinery/computer/outpost_prison_warden/console = locate() in prison_spot(home, 7, 5)
	var/mob/living/basic/outpost_prisoner/first = trouble_prisoner(prison, prison_spot(home, 8, 8), "chatty")
	var/mob/living/basic/outpost_prisoner/second = trouble_prisoner(prison, prison_spot(home, 10, 8), "grumpy")
	var/mob/living/basic/outpost_prisoner/third = trouble_prisoner(prison, prison_spot(home, 12, 7), "cheerful")
	var/mob/living/basic/outpost_prisoner/nervous = trouble_prisoner(prison, prison_spot(home, 6, 8), "nervous")
	var/list/everyone = list(first, second, third, nervous)
	var/mob/living/carbon/human/warden = make_player(prison_spot(home, 8, 4), "riotowner")
	var/list/calm_data = console.ui_data(warden)
	TEST_ASSERT(("alarm" in calm_data) && ("alarm_text" in calm_data), "The warden console sends no alarm keys")
	TEST_ASSERT_NULL(calm_data["alarm"], "A calm wing has an alarm")
	// The console shows the yard's mood in a word; the admin panel's block keeps the numbers and clocks.
	TEST_ASSERT_EQUAL(calm_data["trouble"]?["stage"], prison.stage, "The console's trouble block shows the stage as [calm_data["trouble"]?["stage"]]")
	var/list/calm_trouble = prison.trouble_payload()
	for(var/key in list("stage", "tension", "subdued_left", "riot_imminent", "breakout_in", "loose"))
		TEST_ASSERT(key in calm_trouble, "The trouble block has no [key]")

	// Who joins goes by personality (PRISON_RIOT_JOIN_*): chatty under 50, grumpy under 55,
	// cheerful under 40, nervous under 30. The rest go back to their cells and sit it out.
	first.set_mood(45)
	second.set_mood(50)
	third.set_mood(45)
	nervous.set_mood(35)
	TEST_ASSERT(prison.start_riot("test"), "The riot did not start")
	TEST_ASSERT_EQUAL(first.trouble, "riot", "A chatty prisoner at 45 did not join")
	TEST_ASSERT_EQUAL(second.trouble, "riot", "A grumpy prisoner at 50 did not join")
	TEST_ASSERT_NULL(third.trouble, "A cheerful prisoner at 45 joined")
	TEST_ASSERT_NULL(nervous.trouble, "A nervous prisoner at 35 joined")
	for(var/mob/living/basic/outpost_prisoner/bystander as anything in list(third, nervous))
		TEST_ASSERT(istype(bystander.activity, /datum/prisoner_activity/hide), "[bystander] did not go to sit the riot out ([bystander.activity?.type])")
		TEST_ASSERT(bystander.cell?.turf_set[bystander.activity?.spot], "[bystander] is sitting the riot out outside their cell")
	for(var/mob/living/basic/outpost_prisoner/rioter as anything in list(first, second))
		TEST_ASSERT(istype(rioter.held_item, /obj/item/knife/shiv), "[rioter] has no shiv out")
		TEST_ASSERT_EQUAL(rioter.bubble, "riot", "[rioter] shows the [rioter.bubble] bubble, not the shiv")
		TEST_ASSERT_EQUAL(rioter.melee_damage_lower, 10, "A shiv does not hit harder") // PRISONER_SHIV_MIN
		TEST_ASSERT_EQUAL(prison.prisoner_pay_rate(rioter), 0, "A rioter earned a stipend")
	var/list/riot_data = console.ui_data(warden)
	TEST_ASSERT_EQUAL(riot_data["alarm"], "riot", "The console alarm is [riot_data["alarm"]]")
	TEST_ASSERT_EQUAL(riot_data["alarm_text"], "Riot in the yard", "The console alarm reads [riot_data["alarm_text"]]")
	TEST_ASSERT_EQUAL(prison.trouble_payload()["breakout_in"], 180, "The breakout is due in [prison.trouble_payload()["breakout_in"]] s, not 180") // PRISON_RIOT_BREAKOUT_TIME
	TEST_ASSERT(prison.incident_open, "A riot opened no incident")

	// Five seconds of shivs out and shouting before the first blow (PRISON_RIOT_WINDUP).
	warden.forceMove(prison_spot(home, 8, 10))
	var/obj/structure/table/table = locate() in prison_spot(home, 4, 9)
	TEST_ASSERT_NOTNULL(table, "The mess table is not where the map puts it")
	TEST_ASSERT_NULL(first.riot_target(), "A rioter went for something during the wind-up")
	first.forceMove(prison_spot(home, 4, 8))
	TEST_ASSERT(!first.confront(table), "A rioter struck during the wind-up")
	first.forceMove(prison_spot(home, 8, 8))
	prison.tick(4)
	TEST_ASSERT(prison.riot_windup_left > 0, "The wind-up ended early")
	prison.tick(1)
	TEST_ASSERT_EQUAL(prison.riot_windup_left, 0, "The wind-up did not end after five seconds")

	// The riot lights come on (how they strobe is tested with the wing's conditions); the fire alarm is left alone.
	TEST_ASSERT(prison.riot_lights_on, "The riot lights did not come on")
	TEST_ASSERT(!prison.wing.fire, "The riot set off the fire alarm")

	// Rioters go for staff they can reach first, but no more than two on one person (PRISON_RIOT_MAX_ATTACKERS).
	third.start_rioting(FALSE)
	TEST_ASSERT_EQUAL(first.riot_target(), warden, "A rioter ignored staff in the yard")
	TEST_ASSERT_EQUAL(second.riot_target(), warden, "A second rioter ignored staff in the yard")
	var/atom/third_target = third.riot_target()
	TEST_ASSERT(third_target != warden, "A third rioter went for someone two rioters were already on")
	TEST_ASSERT_NOTNULL(third_target, "The third rioter found nothing else to smash")
	// With staff out of reach: a way out of the cell block from the start (the rest is in
	// voidcrew_outpost_prison_breakout.dm), and now and then a fixture on the way; never a cell door
	// or a window in the outer wall.
	warden.forceMove(prison_spot(home, 8, 4))
	for(var/i in 1 to 40)
		first.riot_target_ref = null
		var/atom/target = first.riot_target()
		TEST_ASSERT_NOTNULL(target, "A rioter found nothing to smash")
		TEST_ASSERT(first.reachable[get_turf(target)], "A rioter went for [target] out of reach")
		TEST_ASSERT(prison.is_exit_blocker(target) || prison.is_riot_fixture(target, get_turf(target)), "A rioter went for [target], neither a way out nor a fixture")
		TEST_ASSERT(!istype(target, /obj/machinery/door) || !prison.is_cell_door(target), "A rioter went for a cell door")
		if(istype(target, /obj/structure/window) || istype(target, /obj/structure/grille))
			TEST_ASSERT(!prison.on_wing_edge(get_turf(target)), "A rioter went for a window in the outer wall")
	// From the first blow, with the crew home, the staff door takes real damage.
	var/obj/machinery/door/airlock/security/prison_staff/staff_door = locate() in prison_spot(home, 9, 6)
	TEST_ASSERT_NOTNULL(staff_door, "The staff door is not where the map puts it")
	var/door_before = staff_door.get_integrity()
	first.forceMove(prison_spot(home, 9, 7))
	first.baton_stop_until = 0
	TEST_ASSERT(first.confront(staff_door), "A rioter could not hit the staff door")
	TEST_ASSERT_EQUAL(staff_door.get_integrity(), door_before - 10, "A rioter's blow did [door_before - staff_door.get_integrity()] to the staff door, not 10") // PRISON_RIOT_DOOR_DAMAGE
	staff_door.repair_damage(staff_door.max_integrity)
	// Smashing: a light breaks, a table takes damage, staff get the shiv (10-15).
	var/obj/machinery/light/yard_light = locate() in prison_spot(home, 5, 11)
	TEST_ASSERT_NOTNULL(yard_light, "The yard light is not where the map puts it")
	first.forceMove(prison_spot(home, 5, 10))
	TEST_ASSERT(first.confront(yard_light), "A rioter could not hit a light")
	TEST_ASSERT_EQUAL(yard_light.status, LIGHT_BROKEN, "A rioter's blow did not break the light")
	var/table_before = table.get_integrity()
	first.forceMove(prison_spot(home, 4, 8))
	first.confront(table)
	TEST_ASSERT_EQUAL(table_before - table.get_integrity(), 10, "A rioter's blow did [table_before - table.get_integrity()] to a table, not 10") // PRISON_SMASH_DAMAGE
	warden.forceMove(prison_spot(home, 5, 8))
	var/brute_before = warden.getBruteLoss()
	first.confront(warden)
	var/stabbed = warden.getBruteLoss() - brute_before
	TEST_ASSERT(stabbed >= 10 && stabbed <= 15, "A shiv did [stabbed] brute, not 10-15") // PRISONER_SHIV_MIN/MAX
	warden.forceMove(prison_spot(home, 8, 4))
	warden.fully_heal()

	// Stunned or beaten, a rioter drops a real shiv but stays a rioter, their mood as it was, until
	// the riot is over (voidcrew_outpost_prison_capture.dm has the rest of capture).
	var/first_mood = first.mood
	first.adjustStaminaLoss(200)
	TEST_ASSERT_EQUAL(first.trouble, "riot", "A stunned rioter stopped rioting")
	TEST_ASSERT(!istype(first.held_item, /obj/item/knife/shiv), "A stunned rioter kept the shiv")
	TEST_ASSERT_NOTNULL(locate(/obj/item/knife/shiv) in first.loc, "A stunned rioter dropped no shiv")
	TEST_ASSERT(abs(first.mood - first_mood) < 0.01, "Stunning a rioter moved their mood to [first.mood]")
	second.apply_damage(90, BRUTE)
	TEST_ASSERT(second.beaten_left > 0, "A rioter at 10 health did not collapse")
	TEST_ASSERT_EQUAL(second.trouble, "riot", "A beaten rioter stopped rioting")
	TEST_ASSERT_NOTNULL(locate(/obj/item/knife/shiv) in second.loc, "A beaten rioter dropped no shiv")

	// Down, a rioter is held where they lie, but the riot goes on while another is free.
	prison.tick(1)
	TEST_ASSERT(prison.riot_active, "The riot ended with a rioter free in the yard")
	// Shut in a cell, a rioter stays a rioter until the riot is over, and goes for nothing in there:
	// not even the window beside the cell door.
	var/list/cell_doors = list()
	for(var/list/pair as anything in list(list(first, prison.cells[1], prison_spot(home, 3, 14)), list(second, prison.cells[2], prison_spot(home, 7, 14))))
		var/mob/living/basic/outpost_prisoner/downed = pair[1]
		var/datum/outpost_prison_cell/downed_cell = pair[2]
		var/obj/machinery/door/airlock/downed_door = downed_cell.door()
		downed.forceMove(pair[3])
		if(!downed_door.density)
			downed_door.close()
		downed_door.bolt()
		cell_doors += downed_door
	prison.refresh_reach()
	prison.tick(1)
	TEST_ASSERT(prison.riot_active, "The riot ended with a rioter free in the yard")
	TEST_ASSERT_EQUAL(first.trouble, "riot", "A rioter bolted in a cell stopped rioting before the riot was over")
	TEST_ASSERT_NULL(first.riot_target(), "A rioter bolted in a cell went for [first.riot_target()]")
	// The last one shut in: the riot is over.
	var/datum/outpost_prison_cell/cell_three = prison.cells[3]
	var/obj/machinery/door/airlock/cell_door = cell_three.door()
	third.forceMove(prison_spot(home, 11, 14))
	if(!cell_door.density)
		cell_door.close()
	cell_door.bolt()
	cell_doors += cell_door
	prison.refresh_reach()
	prison.tension_spike = 40
	prison.tick(1)
	TEST_ASSERT(!prison.riot_active, "The riot went on with every rioter bolted in a cell")
	for(var/mob/living/basic/outpost_prisoner/rioter as anything in list(first, second, third))
		TEST_ASSERT(isnull(rioter.trouble), "[rioter] kept rioting after the riot")
		TEST_ASSERT(abs(rioter.mood - 50) < 1, "[rioter] calmed to [rioter.mood], not 50")
		TEST_ASSERT(rioter.lockdown_left > 0, "[rioter] was shut in a cell and owes no lockdown")
	TEST_ASSERT_EQUAL(prison.tension_spike, 0, "The end of the riot left a [prison.tension_spike] spike")
	TEST_ASSERT_EQUAL(prison.subdued_left, 360, "The end of the riot subdued the wing for [prison.subdued_left] s, not 360") // PRISON_SUBDUED_TIME
	TEST_ASSERT_EQUAL(prison.trouble_payload()["subdued_left"], 360, "The console does not show the subdued time")
	TEST_ASSERT(!prison.incident_open, "The incident outlived the riot")
	TEST_ASSERT(!prison.riot_lights_on, "The riot lights stayed on")
	TEST_ASSERT_NULL(console.ui_data(warden)["alarm"], "The alarm outlasted the riot")
	// Their lockdown is the capture test's; out they come, clear of it.
	for(var/obj/machinery/door/airlock/bolted as anything in cell_doors)
		bolted.unbolt()
	for(var/mob/living/basic/outpost_prisoner/rioter as anything in list(first, second, third))
		rioter.lockdown_left = 0
	first.forceMove(prison_spot(home, 8, 8))
	second.forceMove(prison_spot(home, 10, 8))
	prison.refresh_reach()
	third.forceMove(prison_spot(home, 12, 7))

	// No new riot, fight or spark riot for six minutes, however bad it gets.
	first.setStaminaLoss(0)
	second.adjustBruteLoss(-100)
	second.recover()
	set_moods(everyone, 10)
	prison.tick(300)
	TEST_ASSERT(!prison.riot_active, "A riot started inside the quiet after the last")
	TEST_ASSERT(!prison.trouble_event(30, "test spark"), "A spark started a riot inside the quiet after the last")
	TEST_ASSERT_NULL(prison.try_start_fight(), "A fight started inside the quiet after a riot")
	set_moods(everyone, 10)
	prison.tick(59)
	TEST_ASSERT(!prison.riot_active, "A riot started inside the quiet after the last")
	set_moods(everyone, 10)
	prison.tick(1)
	TEST_ASSERT_EQUAL(prison.subdued_left, 0, "The quiet lasted past six minutes")
	TEST_ASSERT(prison.riot_imminent, "Tension held high after the quiet did not bring a riot on")
	prison.tick(43)
	TEST_ASSERT(!prison.riot_active, "The next riot skipped its hold")
	prison.tick(1)
	TEST_ASSERT(prison.riot_active, "Tension held high after the quiet started no riot")
	prison.admin_calm()
	prison.set_subdued(0)

	// Left three minutes with the crew home, a riot becomes a breakout: every rioter goes for the
	// ways out, with five minutes on their clocks (OUTPOST_PRISON_LOOSE_TIME).
	first.baton_stop_until = 0
	TEST_ASSERT(prison.start_riot("test", everyone = TRUE), "The second riot did not start")
	prison.tick(119)
	TEST_ASSERT(!prison.riot_warned, "The crew heard the rioters were at the doors early")
	prison.tick(1)
	TEST_ASSERT(prison.riot_warned, "Two minutes of riot did not tell the crew the rioters are at the doors") // PRISON_RIOT_BREAKOUT_WARNING
	prison.tick(59)
	TEST_ASSERT(!prison.breaking_out, "The riot broke out early")
	TEST_ASSERT_EQUAL(prison.trouble_payload()["breakout_in"], 1, "The breakout countdown is off")
	prison.tick(1)
	TEST_ASSERT(prison.breaking_out, "Three minutes of riot did not become a breakout")
	TEST_ASSERT_NULL(prison.trouble_payload()["breakout_in"], "The breakout countdown outlived the breakout")
	var/list/breakout_data = console.ui_data(warden)
	TEST_ASSERT_EQUAL(breakout_data["alarm"], "breakout", "The breakout alarm is [breakout_data["alarm"]]")
	for(var/mob/living/basic/outpost_prisoner/rioter as anything in everyone)
		TEST_ASSERT_EQUAL(rioter.trouble, "breakout", "[rioter] is [rioter.trouble] in the breakout")
		TEST_ASSERT_EQUAL(rioter.loose_left, 300, "[rioter] has [rioter.loose_left] s on their breakout clock")
	TEST_ASSERT_EQUAL(length(prison.trouble_payload()["loose"]), 4, "The console lists [length(prison.trouble_payload()["loose"])] prisoners on the clock")
	// Breaking out, every rioter goes for a way out, never a fixture on the way.
	prison.riot_detour_chance = 100
	for(var/mob/living/basic/outpost_prisoner/rioter as anything in everyone)
		var/atom/exit = rioter.riot_target()
		TEST_ASSERT_NOTNULL(exit, "[rioter] breaking out found no way out to hit")
		TEST_ASSERT(prison.is_exit_blocker(exit), "[rioter] breaking out went for [exit] at [exit.x],[exit.y], which is no way out")
	prison.riot_detour_chance = 15 // PRISON_RIOT_DETOUR_CHANCE
	door_before = staff_door.get_integrity()
	first.forceMove(prison_spot(home, 9, 7))
	first.confront(staff_door)
	TEST_ASSERT(staff_door.get_integrity() < door_before, "A rioter breaking out did no damage to the staff door")
	staff_door.repair_damage(staff_door.max_integrity)

	// A serving hatch's office side gives after thirty blows (300 integrity, PRISON_RIOT_WINDOOR_DAMAGE 10)
	// and the hatch is then climbed.
	var/obj/structure/table/reinforced/prison_hatch/hatch = locate() in prison_spot(home, 5, 6)
	first.forceMove(prison_spot(home, 5, 7))
	for(var/i in 1 to 29)
		TEST_ASSERT(first.confront(hatch), "A rioter could not work at the hatch")
	TEST_ASSERT(!hatch.both_sides_open(), "The hatch gave early")
	first.confront(hatch)
	TEST_ASSERT(wait_until(CALLBACK(hatch, TYPE_PROC_REF(/obj/structure/table/reinforced/prison_hatch, both_sides_open)), 5 SECONDS), "Thirty blows did not force the hatch open")
	TEST_ASSERT_EQUAL(first.riot_target(), hatch, "A rioter did not go for the forced hatch")
	TEST_ASSERT(first.confront(hatch), "A rioter did not start over the forced hatch")
	prison.tick(3)
	TEST_ASSERT_EQUAL(first.loc, prison_spot(home, 5, 5), "The rioter did not come down in the office")
	TEST_ASSERT_EQUAL(first.trouble, "loose", "A rioter out of the cell block is not loose")
	TEST_ASSERT(first.loose_left > 290 && first.loose_left <= 297, "Getting out restarted the breakout clock ([first.loose_left] s)")
	TEST_ASSERT(prison.broke_out, "A rioter getting out did not count as a breakout")
	TEST_ASSERT_EQUAL(console.ui_data(warden)["alarm_text"], "Loose: [first.real_name] ([get_area_name(first)])", "The console reads [console.ui_data(warden)["alarm_text"]]")
	TEST_ASSERT(prison.riot_lights_on, "The lights stopped strobing with a rioter loose")
	prison.admin_calm()
	settle_prison_air(home)

// ===== RIOT CLOCKS: THE CREW AWAY, SIT-INS AND WALLED-IN BREAKOUTS =====

/datum/unit_test/voidcrew_outpost_prison_riot_clocks
	parent_type = /datum/unit_test/voidcrew_outpost_management

/datum/unit_test/voidcrew_outpost_prison_riot_clocks/proc/all_gone(list/prisoners)
	for(var/mob/living/basic/outpost_prisoner/prisoner as anything in prisoners)
		if(!QDELETED(prisoner))
			return FALSE
	return TRUE

/datum/unit_test/voidcrew_outpost_prison_riot_clocks/Run()
	var/obj/structure/overmap/dynamic/player_outpost/home = trouble_test_claim("clockowner")
	TEST_ASSERT_NOTNULL(home, "The riot clock test prison did not load")
	var/datum/outpost_prison/prison = test_prison(home)
	var/datum/bank_account/treasury = trouble_fund(home, 10000)
	var/list/sitters = list(
		trouble_prisoner(prison, prison_spot(home, 8, 8)),
		trouble_prisoner(prison, prison_spot(home, 10, 8)),
		trouble_prisoner(prison, prison_spot(home, 12, 8)),
	)

	// With nobody home the riot is a sit-in: its breakout clock waits (PRISON_RIOT_BREAKOUT_TIME).
	prison.crew_home_override = FALSE
	TEST_ASSERT(!prison.crew_home(), "The crew override did not send the crew away")
	TEST_ASSERT(prison.start_riot("test", everyone = TRUE), "The sit-in did not start")
	prison.tick(300)
	TEST_ASSERT(prison.riot_active, "A sit-in ended on its own")
	TEST_ASSERT_EQUAL(prison.riot_elapsed, 0, "The breakout clock ran with nobody home")
	TEST_ASSERT(!prison.breaking_out, "A sit-in broke out with nobody home")
	TEST_ASSERT_EQUAL(prison.trouble_payload()["breakout_in"], 180, "The breakout countdown moved with nobody home")
	TEST_ASSERT_EQUAL(prison.riot_absent, 300, "The sit-in clock counted [prison.riot_absent] s, not 300")
	// A member home for a moment runs the breakout clock, not the sit-in clock.
	prison.crew_home_override = TRUE
	prison.tick(10)
	TEST_ASSERT_EQUAL(prison.riot_elapsed, 10, "The breakout clock did not run with the crew home")
	TEST_ASSERT_EQUAL(prison.riot_absent, 300, "The sit-in clock ran with the crew home")
	// Ten minutes of sit-in in all (PRISON_RIOT_TRANSFER_TIME): the rioters are transferred out,
	// 750 cr each as one incident (OUTPOST_PRISON_TRANSFER_FEE, capped per incident in the economy).
	prison.crew_home_override = FALSE
	prison.tick(299)
	TEST_ASSERT(prison.riot_active, "The rioters were transferred early")
	prison.tick(1)
	TEST_ASSERT(!prison.riot_active, "Ten minutes of sit-in did not end the riot")
	for(var/mob/living/basic/outpost_prisoner/sitter as anything in sitters)
		TEST_ASSERT_EQUAL(sitter.phase, "leaving", "[sitter] was not transferred out")
	TEST_ASSERT_EQUAL(treasury.account_balance, 10000 - 2250, "Three transfers took [10000 - treasury.account_balance], not 2250")
	TEST_ASSERT(10000 - treasury.account_balance <= 2500, "One sit-in cost more than the incident cap") // OUTPOST_PRISON_INCIDENT_FINE_CAP
	TEST_ASSERT_EQUAL(prison.paid_total, 0, "A transfer paid a release bonus")
	TEST_ASSERT(!prison.incident_open, "The incident outlived the transfer")
	TEST_ASSERT(wait_until(CALLBACK(src, PROC_REF(all_gone), sitters), 8 SECONDS), "The transferred rioters never beamed out")
	prison.set_subdued(0)

	// A breakout walled in: nobody gets out, and five minutes on the clock later they are gone
	// for good anyway (OUTPOST_PRISON_LOOSE_TIME). A rioter put down stays a rioter while others
	// are free, but their clock waits while they are down.
	prison.crew_home_override = TRUE
	treasury = trouble_fund(home, 10000)
	var/mob/living/basic/outpost_prisoner/runner = trouble_prisoner(prison, prison_spot(home, 8, 8))
	var/mob/living/basic/outpost_prisoner/stayer = trouble_prisoner(prison, prison_spot(home, 10, 8))
	var/mob/living/basic/outpost_prisoner/downed = trouble_prisoner(prison, prison_spot(home, 12, 8))
	TEST_ASSERT(prison.start_riot("test", everyone = TRUE), "The breakout riot did not start")
	prison.tick(180)
	TEST_ASSERT(prison.breaking_out, "Three minutes of riot with the crew home did not break out")
	downed.adjustStaminaLoss(200)
	TEST_ASSERT_EQUAL(downed.trouble, "breakout", "A breakout rioter put down stopped rioting")
	var/downed_clock = downed.loose_left
	// The clock runs whatever the crew does. (The calm prisoner's stipend goes in meanwhile.)
	prison.crew_home_override = FALSE
	var/paid_before = prison.paid_total
	prison.tick(299)
	TEST_ASSERT_EQUAL(runner.phase, "present", "A walled-in breakout rioter left early")
	TEST_ASSERT(abs(runner.loose_left - 1) < 0.01, "The breakout clock stood at [runner.loose_left] s, not 1")
	TEST_ASSERT(prison.riot_active, "The riot ended with two rioters free")
	TEST_ASSERT_EQUAL(downed.loose_left, downed_clock, "The clock of a breakout rioter who was down ran ([downed_clock] s to [downed.loose_left] s)")
	// The other two gone for good, the last rioter lies down in the yard: the riot is over. Held
	// down, not shut in a cell, they owe no lockdown.
	prison.tick(1)
	TEST_ASSERT_EQUAL(runner.phase, "leaving", "A walled-in breakout rioter was not gone after five minutes")
	TEST_ASSERT_EQUAL(stayer.phase, "leaving", "The second walled-in rioter was not gone after five minutes")
	TEST_ASSERT_EQUAL(downed.phase, "present", "The rioter put down in time was taken anyway")
	TEST_ASSERT(!prison.riot_active, "The riot went on with its last rioter down in the yard")
	TEST_ASSERT_NULL(downed.trouble, "The last rioter kept breaking out after the riot")
	TEST_ASSERT_EQUAL(downed.loose_left, 0, "The last rioter's clock outlived the riot")
	TEST_ASSERT_EQUAL(downed.lockdown_left, 0, "A rioter held down in the yard owes lockdown")
	TEST_ASSERT(!prison.incident_open, "The incident outlived the breakout")
	var/stipends = prison.paid_total - paid_before
	TEST_ASSERT_EQUAL(treasury.account_balance, 10000 - 2000 + stipends, "Two escapes took [10000 + stipends - treasury.account_balance], not 2000")
	downed.setStaminaLoss(0)
	settle_prison_air(home)

// ===== THE HATCH, ESCAPES, THE LOOSE CLOCK AND TURRETS =====

/datum/unit_test/voidcrew_outpost_prison_escape
	parent_type = /datum/unit_test/voidcrew_outpost_management

/datum/unit_test/voidcrew_outpost_prison_escape/Run()
	var/obj/structure/overmap/dynamic/player_outpost/home = trouble_test_claim("escapeowner")
	TEST_ASSERT_NOTNULL(home, "The escape test prison did not load")
	var/datum/outpost_prison/prison = test_prison(home)
	var/obj/structure/table/reinforced/prison_hatch/hatch = locate() in prison_spot(home, 5, 6)
	var/obj/machinery/door/window/yard_door = hatch.yard_windoor()
	var/obj/machinery/door/window/staff_door = hatch.staff_windoor()
	var/mob/living/basic/outpost_prisoner/runner = trouble_prisoner(prison, prison_spot(home, 5, 7))
	runner.set_mood(30)

	// The climb needs both window doors open (PRISONER_CLIMB_MOOD 50 and below 50 mood).
	var/datum/prisoner_activity/climb_hatch/climb = new(runner)
	TEST_ASSERT(!climb.setup(), "A prisoner set out to climb a shut hatch")
	TEST_ASSERT(!runner.start_climb(hatch), "A prisoner climbed a shut hatch")
	staff_door.open()
	TEST_ASSERT(!climb.setup(), "A prisoner set out to climb a hatch open on the staff side only")
	TEST_ASSERT(!runner.start_climb(hatch), "A prisoner climbed a hatch open on one side")
	yard_door.open()
	TEST_ASSERT(hatch.both_sides_open(), "Both window doors open did not read as open")
	runner.set_mood(60)
	TEST_ASSERT(!climb.setup(), "A prisoner at mood 60 set out to climb")
	runner.set_mood(30)
	TEST_ASSERT(climb.setup(), "An unhappy prisoner did not go for an open hatch")
	TEST_ASSERT_EQUAL(climb.spot, prison_spot(home, 5, 7), "The climb does not start in front of the hatch")
	qdel(climb)
	// Shutting a side mid-climb brings them back down.
	TEST_ASSERT(runner.start_climb(hatch), "An unhappy prisoner did not start over an open hatch")
	TEST_ASSERT(runner.in_trouble() && !runner.routine_allowed(), "A climbing prisoner kept up their routine")
	yard_door.close()
	prison.tick(1)
	TEST_ASSERT_NULL(runner.climb_ref, "The climb went on after a window door shut")
	TEST_ASSERT_EQUAL(runner.loc, prison_spot(home, 5, 7), "The prisoner went over a shut hatch")
	// Three seconds (PRISONER_CLIMB_TIME) over an open one: up on the counter halfway, then down in the
	// office and out of the cell block.
	yard_door.open()
	TEST_ASSERT(runner.start_climb(hatch), "The prisoner did not start over the reopened hatch")
	prison.tick(1)
	TEST_ASSERT_EQUAL(runner.loc, prison_spot(home, 5, 7), "The climber was on the counter before halfway")
	prison.tick(1)
	TEST_ASSERT_EQUAL(runner.loc, prison_spot(home, 5, 6), "The climber did not get up onto the counter halfway")
	TEST_ASSERT(isnull(runner.trouble), "The climber counted as loose while up on the counter")
	prison.tick(1)
	TEST_ASSERT_EQUAL(runner.loc, prison_spot(home, 5, 5), "The climb did not end in the office")
	yard_door.close()
	staff_door.close()

	// Escaped: loose on the outpost patrol AI, five minutes on the clock (OUTPOST_PRISON_LOOSE_TIME).
	TEST_ASSERT(!prison.in_cell_block(runner), "The office counts as the cell block")
	TEST_ASSERT_EQUAL(runner.trouble, "loose", "An escaped prisoner is not loose")
	TEST_ASSERT(istype(runner.ai_controller, /datum/ai_controller/basic_controller/outpost_breakout), "A loose prisoner is not on the patrol AI ([runner.ai_controller?.type])")
	TEST_ASSERT_EQUAL(runner.bubble, "riot", "A loose prisoner shows the [runner.bubble] bubble")
	TEST_ASSERT(is_line_for(runner.last_line, "escape"), "The escaped prisoner said no escape line: [runner.last_line]")
	var/list/alarm = prison.alarm_state()
	TEST_ASSERT_EQUAL(alarm[1], "escape", "A single escape shows the [alarm[1]] alarm")
	TEST_ASSERT_EQUAL(alarm[2], "Loose: [runner.real_name] ([get_area_name(runner)])", "The escape alarm reads [alarm[2]]")
	TEST_ASSERT(!prison.riot_lights_on, "A lone escape set the riot lights off")
	TEST_ASSERT(prison.incident_open, "An escape opened no incident")
	TEST_ASSERT(prison.protective_custody(), "Bolting prisoners in with one loose is not protective custody")
	TEST_ASSERT_EQUAL(runner.loose_seconds_shown(), 300, "The loose clock shows [runner.loose_seconds_shown()]")
	var/list/loose_rows = prison.trouble_payload()["loose"]
	TEST_ASSERT_EQUAL(length(loose_rows), 1, "The console lists [length(loose_rows)] loose prisoners")
	var/list/loose_row = loose_rows[1]
	TEST_ASSERT(loose_row["name"] == runner.real_name && loose_row["time_left"] == 300 && istext(loose_row["area"]), "The console's loose row is wrong: [json_encode(loose_row)]")
	TEST_ASSERT_EQUAL(prison.prisoner_pay_rate(runner), 0, "A loose prisoner earned a stipend")
	var/sentence_before = runner.sentence_left
	prison.tick(100)
	TEST_ASSERT_EQUAL(runner.loose_left, 200, "100 seconds out left [runner.loose_left] on the clock")
	TEST_ASSERT_EQUAL(runner.sentence_left, sentence_before, "A loose prisoner's sentence ran")
	// Back in the cell block on their feet they are still loose, and the clock keeps running.
	runner.forceMove(prison_spot(home, 8, 8))
	prison.tick(50)
	TEST_ASSERT_EQUAL(runner.loose_left, 150, "The loose clock stopped inside the cell block ([runner.loose_left] s)")
	TEST_ASSERT_EQUAL(runner.trouble, "loose", "Walking back in on their own was a recapture")

	// Recaptured: down inside the cell block. Back on the prisoner AI, in a foul mood (35).
	runner.forceMove(prison_spot(home, 8, 4))
	runner.adjustStaminaLoss(200)
	runner.forceMove(prison_spot(home, 8, 8))
	prison.tick(1)
	TEST_ASSERT(isnull(runner.trouble), "A downed prisoner dragged back was not recaptured")
	TEST_ASSERT(abs(runner.mood - 35) < 0.1, "A recaptured prisoner is at mood [runner.mood], not 35") // PRISONER_RECAPTURED_MOOD
	TEST_ASSERT(istype(runner.ai_controller, /datum/ai_controller/basic_controller/outpost_prisoner), "A recaptured prisoner is not back on the prisoner AI")
	TEST_ASSERT_NULL(prison.alarm_state()[1], "The alarm outlasted the recapture")
	TEST_ASSERT(!prison.incident_open, "The incident outlasted the recapture")
	runner.setStaminaLoss(0)

	// Dragged out of the cell block while down is not an escape; waking up out there is.
	runner.adjustStaminaLoss(200)
	runner.forceMove(prison_spot(home, 8, 4))
	prison.tick(1)
	TEST_ASSERT(isnull(runner.trouble), "A downed prisoner dragged into the office counted as escaped")
	runner.setStaminaLoss(0)
	prison.tick(1)
	TEST_ASSERT_EQUAL(runner.trouble, "loose", "A prisoner on their feet in the office did not escape")

	// Five minutes out: gone for good, no bonus, and a 1000 cr fine (OUTPOST_PRISON_ESCAPE_FINE).
	// Nobody else is earning, so nothing else is paid in.
	prison.pay_owed = 0
	var/datum/bank_account/treasury = trouble_fund(home, 5000)
	var/paid_before = prison.paid_total
	var/runner_name = runner.real_name
	prison.tick(299)
	TEST_ASSERT_EQUAL(runner.phase, "present", "A loose prisoner left early")
	prison.tick(1)
	TEST_ASSERT_EQUAL(runner.phase, "leaving", "A prisoner loose five minutes was not beamed away")
	TEST_ASSERT_EQUAL(treasury.account_balance, 4000, "An escape took [5000 - treasury.account_balance], not 1000")
	TEST_ASSERT_EQUAL(prison.paid_total, paid_before, "An escape paid a bonus")
	var/list/newest = prison.entries[1]
	TEST_ASSERT(findtext(newest["text"], runner_name) && findtext(newest["text"], "1000"), "The escape was not logged with its fine: [newest["text"]]")

	// Out of the wing is out, however they got there: carried or dragged, down or not.
	var/list/bounds = prison.upgrade.footprint_bounds
	var/turf/outside = locate(bounds[1] + 8, bounds[2] - 2, bounds[5])
	TEST_ASSERT(get_area(outside) != prison.wing, "The spot outside the wing is in the wing")
	var/mob/living/basic/outpost_prisoner/carried = trouble_prisoner(prison, prison_spot(home, 10, 8))
	carried.adjustStaminaLoss(200)
	carried.forceMove(outside)
	prison.tick(1)
	TEST_ASSERT_EQUAL(carried.trouble, "loose", "A prisoner carried out of the wing while down did not count as escaped")
	TEST_ASSERT(carried.loose_left > 0, "A prisoner carried out of the wing has no clock running")
	// A turret leaves a runner who is down alone, so they are stopped, not killed.
	TEST_ASSERT(!is_hostile_creature(carried), "A turret would shoot a loose prisoner who is down")
	carried.setStaminaLoss(0)
	TEST_ASSERT(is_hostile_creature(carried), "A turret would not shoot a loose prisoner on their feet outside the wing")
	// Brought back down into the cell block, they are recaptured.
	carried.adjustStaminaLoss(200)
	carried.forceMove(prison_spot(home, 10, 8))
	prison.tick(1)
	TEST_ASSERT(isnull(carried.trouble), "A prisoner brought back down into the cell block was not recaptured")
	carried.setStaminaLoss(0)

	// Turrets (interim rule): prisoners in the wing are left alone, rioting or loose; outside it, fair game.
	var/mob/living/basic/outpost_prisoner/target = trouble_prisoner(prison, prison_spot(home, 12, 8))
	TEST_ASSERT(!is_hostile_creature(target), "A turret would shoot a prisoner in the yard")
	target.start_rioting()
	TEST_ASSERT(!is_hostile_creature(target), "A turret would shoot a rioter in the wing")
	target.calm_down()
	target.forceMove(prison_spot(home, 10, 4))
	prison.tick(1)
	TEST_ASSERT_EQUAL(target.trouble, "loose", "The turret target did not escape")
	TEST_ASSERT(!is_hostile_creature(target), "A turret would shoot a loose prisoner still inside the wing")
	target.forceMove(outside)
	TEST_ASSERT(is_hostile_creature(target), "A turret would not shoot a loose prisoner outside the wing")
	TEST_ASSERT(is_loose_outpost_prisoner(target), "A loose prisoner outside the wing is not a turret target")
	target.forceMove(prison_spot(home, 10, 4))
	settle_prison_air(home)

// ===== LOCK-INS AND WRECKED CELLS =====

/datum/unit_test/voidcrew_outpost_prison_lockin
	parent_type = /datum/unit_test/voidcrew_outpost_management

/datum/unit_test/voidcrew_outpost_prison_lockin/Run()
	var/obj/structure/overmap/dynamic/player_outpost/home = trouble_test_claim("lockinowner")
	TEST_ASSERT_NOTNULL(home, "The lock-in test prison did not load")
	var/datum/outpost_prison/prison = test_prison(home)
	prison.crew_home_override = TRUE
	var/mob/living/basic/outpost_prisoner/inmate = trouble_awake_prisoner(prison, prison_spot(home, 3, 14))
	var/mob/living/basic/outpost_prisoner/yardbird = trouble_prisoner(prison, prison_spot(home, 8, 8))
	var/datum/outpost_prison_cell/cell_one = prison.cells[1]
	TEST_ASSERT_EQUAL(inmate.cell, cell_one, "The inmate is not in cell 1")
	var/obj/machinery/door/airlock/cell_door = cell_one.door()
	cell_door.bolt()
	prison.refresh_reach()
	TEST_ASSERT(inmate.is_confined(), "A prisoner bolted in their cell is not confined")

	// The confinement clock counts up while shut in, and falls two seconds a second out of the cell
	// (PRISONER_LOCKED_IN_RECOVERY), so unbolting for a moment every 110 s does not reset it.
	inmate.set_mood(70)
	prison.update_locked_in(inmate, 150)
	TEST_ASSERT_EQUAL(inmate.locked_in_seconds, 150, "150 s bolted in counted [inmate.locked_in_seconds]")
	cell_door.unbolt()
	prison.refresh_reach()
	prison.update_locked_in(inmate, 5)
	TEST_ASSERT_EQUAL(inmate.locked_in_seconds, 140, "5 s out after 150 in left [inmate.locked_in_seconds], not 140")
	// Let out after two minutes or more: some relief (PRISONER_MOOD_UNBOLTED).
	TEST_ASSERT(abs(inmate.mood - 73) < 0.01, "Being let out left mood at [inmate.mood], not 73")
	cell_door.bolt()
	prison.refresh_reach()
	prison.update_locked_in(inmate, 110)
	cell_door.unbolt()
	prison.refresh_reach()
	prison.update_locked_in(inmate, 5)
	TEST_ASSERT_EQUAL(inmate.locked_in_seconds, 240, "The 110 s toggle left the clock at [inmate.locked_in_seconds], not 240")
	prison.update_locked_in(inmate, 120)
	TEST_ASSERT_EQUAL(inmate.locked_in_seconds, 0, "Two minutes out did not run the clock down")
	TEST_ASSERT(abs(inmate.mood - 76) < 0.01, "The relief came more than once per release (mood [inmate.mood])")
	// Shut in for their own safety (a riot on) costs nothing.
	cell_door.bolt()
	prison.refresh_reach()
	yardbird.set_mood(10)
	TEST_ASSERT(prison.start_riot("test"), "The yard riot did not start")
	TEST_ASSERT_NULL(inmate.trouble, "A prisoner bolted in joined the riot")
	TEST_ASSERT(prison.protective_custody(), "A riot is not protective custody")
	prison.update_locked_in(inmate, 60)
	TEST_ASSERT_EQUAL(inmate.locked_in_seconds, 0, "Being shut in during a riot counted [inmate.locked_in_seconds] s")
	prison.admin_calm()
	prison.set_subdued(0)
	yardbird.set_mood(70)

	// Bolted in six minutes at mood 10 or less (PRISONER_WRECK_AFTER, PRISONER_WRECK_MOOD): the cell
	// gets wrecked. The light breaks, the floor floods, and there is no pay.
	var/obj/machinery/light/cell_light = locate() in prison_spot(home, 2, 15)
	TEST_ASSERT(cell_light?.status == LIGHT_OK, "Cell 1's light is not where the map puts it, or is broken")
	inmate.locked_in_seconds = 359
	inmate.set_mood(5)
	prison.tick(1)
	TEST_ASSERT_EQUAL(inmate.trouble, "wreck", "Six minutes bolted in at mood 5 did not start a wreck")
	TEST_ASSERT_EQUAL(cell_light.status, LIGHT_BROKEN, "The wreck did not break the cell's light")
	var/turf/open/cell_floor = get_turf(inmate)
	TEST_ASSERT_NOTNULL(cell_floor.GetComponent(/datum/component/wet_floor), "The wreck did not flood the cell floor")
	TEST_ASSERT_NOTNULL(locate(/obj/effect/decal/cleanable/dirt) in cell_floor, "The wreck left no dirt")
	TEST_ASSERT_EQUAL(prison.prisoner_pay_rate(inmate), 0, "A prisoner wrecking their cell earned a stipend")
	var/list/newest = prison.entries[1]
	TEST_ASSERT(findtext(newest["text"], "wrecking"), "The wreck was not logged: [newest["text"]]")
	// Three minutes later the bolts shear (PRISONER_WRECK_TIME) and out they come, rioting.
	prison.tick(179)
	TEST_ASSERT(cell_door.locked, "The bolts sheared early")
	TEST_ASSERT_EQUAL(inmate.trouble, "wreck", "The wreck stopped on its own")
	prison.tick(1)
	TEST_ASSERT(!cell_door.locked, "Three minutes of wrecking did not shear the bolts")
	TEST_ASSERT(prison.riot_active, "Sheared bolts started no riot")
	TEST_ASSERT_EQUAL(inmate.trouble, "riot", "The prisoner who sheared the bolts did not riot")
	prison.admin_calm()

	// In the quiet after a riot the bolts still shear, but nobody riots.
	cell_light.fix()
	inmate.forceMove(prison_spot(home, 3, 14))
	cell_door.bolt()
	prison.refresh_reach()
	inmate.locked_in_seconds = 360
	inmate.set_mood(5)
	prison.tick(1)
	TEST_ASSERT_EQUAL(inmate.trouble, "wreck", "A wreck did not start in the quiet after a riot")
	prison.tick(180)
	TEST_ASSERT(!cell_door.locked, "The bolts did not shear in the quiet after a riot")
	TEST_ASSERT(!prison.riot_active, "Sheared bolts started a riot in the quiet after the last")
	TEST_ASSERT_NULL(inmate.trouble, "The prisoner kept wrecking after the bolts sheared")
	prison.set_subdued(0)

	// Let out mid-wreck, the wreck is over.
	inmate.forceMove(prison_spot(home, 3, 14))
	cell_door.bolt()
	prison.refresh_reach()
	inmate.locked_in_seconds = 360
	inmate.set_mood(5)
	TEST_ASSERT(prison.start_wreck(inmate), "The admin wreck hook did not start a wreck")
	cell_door.unbolt()
	prison.refresh_reach()
	prison.tick(1)
	TEST_ASSERT_NULL(inmate.trouble, "A prisoner let out kept wrecking their cell")
	TEST_ASSERT(!prison.riot_active, "Letting a wrecker out started a riot")
	// Dry the cell before the claim is torn down: a wet floor keeps its wetness when turned to space.
	for(var/turf/open/tile in cell_one.turfs)
		tile.MakeDry(ALL, TRUE)
	settle_prison_air(home)

// ===== TALKING THEM DOWN =====

/datum/unit_test/voidcrew_outpost_prison_talk
	parent_type = /datum/unit_test/voidcrew_outpost_management

/datum/unit_test/voidcrew_outpost_prison_talk/Run()
	var/obj/structure/overmap/dynamic/player_outpost/home = trouble_test_claim("talkowner")
	TEST_ASSERT_NOTNULL(home, "The talk test prison did not load")
	var/datum/outpost_prison/prison = test_prison(home)
	var/mob/living/basic/outpost_prisoner/prisoner = trouble_prisoner(prison, prison_spot(home, 8, 8))
	var/mob/living/basic/outpost_prisoner/first = trouble_awake_prisoner(prison, prison_spot(home, 12, 8))
	var/mob/living/basic/outpost_prisoner/second = trouble_awake_prisoner(prison, prison_spot(home, 13, 8))
	var/mob/living/carbon/human/warden = make_player(prison_spot(home, 9, 8), "talkowner")
	warden.drop_all_held_items()
	warden.set_combat_mode(FALSE)

	// "Calm down" on the talk menu (an empty hand, not in combat mode): a few seconds of talk, +8 (PRISONER_MOOD_TALK).
	prisoner.set_mood(30)
	TEST_ASSERT(prisoner.talk_menu_act(warden, "Calm down"), "Picking the talk-down from the talk menu did nothing") // PRISON_TALK_CALM
	TEST_ASSERT(abs(prisoner.mood - 38) < 0.01, "Talking to a prisoner left mood at [prisoner.mood], not 38")
	TEST_ASSERT(!prisoner.talking, "The talk never finished")
	// Once per three minutes each (PRISONER_TALK_COOLDOWN).
	TEST_ASSERT(!prisoner.talk_down(warden), "A second talk inside three minutes did something")
	TEST_ASSERT(abs(prisoner.mood - 38) < 0.01, "A second talk inside three minutes changed mood")
	// Nobody listens below mood 10 (PRISONER_TALK_MIN_MOOD) or while rioting.
	prisoner.talk_cooldown = 0
	prisoner.set_mood(5)
	TEST_ASSERT(!prisoner.talk_down(warden), "A prisoner at mood 5 listened")
	TEST_ASSERT(abs(prisoner.mood - 5) < 0.01, "Talking to a prisoner at mood 5 changed mood")
	prisoner.set_mood(40)
	prisoner.start_rioting(FALSE)
	TEST_ASSERT(!prisoner.talk_down(warden), "A rioter listened")
	TEST_ASSERT(abs(prisoner.mood - 40) < 0.01, "Talking to a rioter changed mood")
	prisoner.calm_down()

	// During a fight's argument, talking to either fighter ends the fight.
	warden.forceMove(prison_spot(home, 12, 9))
	set_moods(list(first, second), 30)
	var/datum/outpost_prison_fight/brawl = prison.start_fight(first, second)
	TEST_ASSERT_NOTNULL(brawl, "The test fight did not start")
	TEST_ASSERT(first.talk_down(warden), "Talking to a fighter during the argument did nothing")
	TEST_ASSERT(isnull(first.fight) && isnull(second.fight), "Talking a fighter down did not end the fight")
	TEST_ASSERT(isnull(first.trouble) && isnull(second.trouble), "The fighters stayed in fight trouble after the talk")
	TEST_ASSERT(abs(first.mood - 38) < 0.01, "The talked-down fighter is at mood [first.mood], not 38")
	// Once the blows start, talk won't stop it.
	second.talk_cooldown = 0
	prison.fight_gap_left = 0
	first.fight_cooldown = 0
	second.fight_cooldown = 0
	brawl = prison.start_fight(first, second)
	TEST_ASSERT_NOTNULL(brawl, "The second test fight did not start")
	prison.tick(10)
	TEST_ASSERT(brawl.fighting, "The second fight never got past arguing")
	TEST_ASSERT(!second.talk_down(warden), "Talk stopped a fight with blows flying")
	TEST_ASSERT(first.fight == brawl, "Talk ended a fight with blows flying")
	settle_prison_air(home)

// ===== HITTING BACK =====

/datum/unit_test/voidcrew_outpost_prison_retaliation
	parent_type = /datum/unit_test/voidcrew_outpost_management

/datum/unit_test/voidcrew_outpost_prison_retaliation/proc/is_down(mob/living/basic/outpost_prisoner/prisoner)
	return prisoner.can_be_dragged()

/datum/unit_test/voidcrew_outpost_prison_retaliation/proc/is_up(mob/living/basic/outpost_prisoner/prisoner)
	return !prisoner.can_be_dragged()

/datum/unit_test/voidcrew_outpost_prison_retaliation/Run()
	// The odds: 70 to 30 at mood 50 (PRISONER_HIT_FIGHT_WEIGHT, _COWER_WEIGHT), half a point a mood point
	// (PRISONER_HIT_REACTION_PER_MOOD), doubled for grumpy fighting and nervous backing off, never under 5.
	var/list/weights = outpost_prisoner_hit_reaction_weights(50, "chatty")
	TEST_ASSERT_EQUAL(weights["fight"], 70, "A chatty prisoner at 50 hits back with weight [weights["fight"]], not 70") // PRISONER_HIT_FIGHT
	TEST_ASSERT_EQUAL(weights["cower"], 30, "A chatty prisoner at 50 backs off with weight [weights["cower"]], not 30") // PRISONER_HIT_COWER
	weights = outpost_prisoner_hit_reaction_weights(10, "grumpy")
	TEST_ASSERT_EQUAL(weights["fight"], 180, "A grumpy prisoner at 10 hits back with weight [weights["fight"]], not 180")
	TEST_ASSERT_EQUAL(weights["cower"], 10, "A grumpy prisoner at 10 backs off with weight [weights["cower"]], not 10")
	weights = outpost_prisoner_hit_reaction_weights(90, "nervous")
	TEST_ASSERT(weights["cower"] > weights["fight"], "A nervous prisoner at 90 is likelier to hit back than back off")
	weights = outpost_prisoner_hit_reaction_weights(0, "grumpy")
	TEST_ASSERT_EQUAL(weights["cower"], 5, "Backing off fell to weight [weights["cower"]], not the floor of 5") // PRISONER_HIT_REACTION_MIN_WEIGHT

	var/obj/structure/overmap/dynamic/player_outpost/home = trouble_test_claim("hitbackowner")
	TEST_ASSERT_NOTNULL(home, "The hitting back test prison did not load")
	var/datum/outpost_prison/prison = test_prison(home)
	var/mob/living/basic/outpost_prisoner/prisoner = trouble_awake_prisoner(prison, prison_spot(home, 8, 8))
	var/mob/living/carbon/human/warden = make_player(prison_spot(home, 9, 8), "hitbackowner")

	// A calm prisoner hit by a player hits back (the roll forced): at the attacker, with a line.
	prison.forced_hit_reaction = "fight" // PRISONER_HIT_FIGHT
	hit_with_toolbox(warden, prisoner)
	TEST_ASSERT(prisoner.health < 100, "The toolbox missed")
	TEST_ASSERT(prisoner.retaliating(), "A calm prisoner hit by a player did not hit back")
	TEST_ASSERT_EQUAL(prisoner.swing_ref?.resolve(), warden, "The prisoner is not going for the player who hit them")
	TEST_ASSERT_EQUAL(prisoner.trouble_target(), warden, "The prisoner's target is not the player who hit them")
	TEST_ASSERT(is_line_for(prisoner.last_line, "retaliate"), "Hitting back, the prisoner said [prisoner.last_line]")
	TEST_ASSERT(prisoner.in_trouble() && !prisoner.routine_allowed(), "Hitting back left the routine running")
	TEST_ASSERT(!prisoner.pull_allowed(), "A prisoner hitting back may be pulled")
	// The blow itself keeps its penalty: unprovoked, -15 (PRISONER_MOOD_HIT_BY_STAFF).
	TEST_ASSERT(abs(prisoner.mood - 55) < 0.01, "The blow left mood at [prisoner.mood], not 55")
	// The player who started it gets no self-defence out of it: their blows stay unprovoked.
	COOLDOWN_RESET(prisoner, staff_hit_cooldown)
	TEST_ASSERT(prisoner.hit_by_staff(warden), "The player who started it hit a prisoner hitting back for free")
	TEST_ASSERT(!prisoner.last_hit_justified, "The player who started it was let off as self-defence")
	// Anyone else stepping in is defending staff.
	var/mob/living/carbon/human/deputy = make_player(prison_spot(home, 7, 8), "hitbackdeputy")
	TEST_ASSERT(prisoner.hit_justified(deputy), "Someone else stepping in on a prisoner hitting back was unprovoked")
	deputy.key = null // a test key on a deleted mob is a runtime; the fixture only clears keys at the end
	qdel(deputy)
	// One blow does not end it.
	var/brute_before = warden.getBruteLoss()
	TEST_ASSERT(prisoner.confront(warden), "The prisoner hitting back could not land a blow")
	TEST_ASSERT(warden.getBruteLoss() > brute_before, "The prisoner's blow did no harm")
	TEST_ASSERT(prisoner.retaliating(), "One blow ended the prisoner hitting back")
	// Turrets answer it as a swing at staff.
	var/obj/machinery/porta_turret/prison_test_probe/probe = allocate(/obj/machinery/porta_turret/prison_test_probe, prison_spot(home, 11, 10))
	TEST_ASSERT(prisoner.turret_trouble(), "A turret does not count hitting back as trouble")
	TEST_ASSERT_EQUAL(outpost_prison_turret_verdict(prisoner, probe), 2, "A turret's verdict spares a prisoner hitting back") // OUTPOST_PRISON_TURRET_SHOOT
	// The trouble tick keeps it going while the player is in reach.
	prison.tick(1)
	TEST_ASSERT(prisoner.retaliating(), "The prisoner stopped hitting back with the player beside them")

	// Out of the cell block, the player is out of reach: they wait, and after 10 seconds (PRISONER_RETALIATE_LOST_TIME) let it drop.
	var/list/bounds = prison.upgrade.footprint_bounds
	var/turf/outside = locate(bounds[1] + 8, bounds[2] - 2, bounds[5])
	TEST_ASSERT(!prison.in_cell_block(outside), "The spot outside the wing is in the cell block")
	warden.forceMove(outside)
	TEST_ASSERT_NULL(prisoner.trouble_target(), "The prisoner went after a player out of the cell block")
	prison.tick(5)
	TEST_ASSERT(prisoner.retaliating(), "The prisoner let it drop before 10 seconds")
	prison.tick(5)
	TEST_ASSERT(!prisoner.retaliating() && isnull(prisoner.swing_ref) && isnull(prisoner.retaliate_ref), "The prisoner went on hitting back 10 seconds after losing the player")

	// It ends on its own after 30 seconds (PRISONER_RETALIATE_TIME), the player beside them or not.
	warden.forceMove(prison_spot(home, 9, 8))
	COOLDOWN_RESET(prisoner, hit_reaction_cooldown)
	prisoner.set_mood(70)
	hit_with_toolbox(warden, prisoner)
	TEST_ASSERT(prisoner.retaliating(), "The second blow did not make them hit back")
	prison.tick(28)
	TEST_ASSERT(prisoner.retaliating(), "Hitting back ended before 30 seconds")
	prison.tick(3)
	prison.tick(1)
	TEST_ASSERT(!prisoner.retaliating() && isnull(prisoner.retaliate_ref), "Hitting back went on past 30 seconds")

	// Put down, they stop.
	COOLDOWN_RESET(prisoner, hit_reaction_cooldown)
	hit_with_toolbox(warden, prisoner)
	TEST_ASSERT(prisoner.retaliating(), "The third blow did not make them hit back")
	prisoner.adjustStaminaLoss(200)
	TEST_ASSERT(prisoner.can_be_dragged(), "A prisoner in stamina crit can't be dragged")
	prison.tick(1)
	TEST_ASSERT(!prisoner.retaliating() && isnull(prisoner.retaliate_ref), "A prisoner put down went on hitting back")
	prisoner.setStaminaLoss(0)
	TEST_ASSERT(wait_until(CALLBACK(src, PROC_REF(is_up), prisoner), 8 SECONDS), "The prisoner never got up")

	// A baton that puts them down gets no reaction.
	COOLDOWN_RESET(prisoner, hit_reaction_cooldown)
	var/batoned_at = world.time
	trouble_baton(warden, prisoner)
	TEST_ASSERT(wait_until(CALLBACK(src, PROC_REF(is_down), prisoner), 4 SECONDS), "The baton did not put the prisoner down")
	// Past the 2.5 seconds a stamina hit waits (PRISONER_STAMINA_REACT_DELAY)
	sleep(max(0, batoned_at + 3 SECONDS - world.time))
	TEST_ASSERT(!prisoner.retaliating(), "A baton that put them down made them hit back")
	TEST_ASSERT(!istype(prisoner.activity, /datum/prisoner_activity/cower), "A baton that put them down made them back off")
	warden.drop_all_held_items()
	prisoner.setStaminaLoss(0)
	prisoner.SetKnockdown(0)
	TEST_ASSERT(wait_until(CALLBACK(src, PROC_REF(is_up), prisoner), 8 SECONDS), "The prisoner never got up after the baton")
	// A stamina hit that leaves them standing: they react once the wait is over.
	COOLDOWN_RESET(prisoner, hit_reaction_cooldown)
	SEND_SIGNAL(prisoner, COMSIG_ATOM_WAS_ATTACKED, warden, ATTACKER_STAMINA_ATTACK)
	TEST_ASSERT(!prisoner.retaliating(), "A stamina hit made them hit back before the wait")
	sleep(3 SECONDS)
	TEST_ASSERT(prisoner.retaliating(), "A stamina hit that left them standing got no reaction")
	prisoner.end_retaliation()

	// Backing off, the roll forced: a few tiles away from the player, with a line, and no swing.
	prison.forced_hit_reaction = "cower" // PRISONER_HIT_COWER
	COOLDOWN_RESET(prisoner, hit_reaction_cooldown)
	prisoner.set_mood(70)
	hit_with_toolbox(warden, prisoner)
	TEST_ASSERT(!prisoner.retaliating(), "A prisoner backing off hit back")
	var/datum/prisoner_activity/cower/backing = prisoner.activity
	TEST_ASSERT(istype(backing), "A prisoner backing off is doing [prisoner.activity?.name || "nothing"]")
	TEST_ASSERT(!backing.interruptible && !backing.leisure, "Backing off is leisure or can be interrupted")
	TEST_ASSERT(!backing.spot || (get_dist(backing.spot, warden) > get_dist(prisoner, warden) && get_dist(prisoner, backing.spot) <= 3), "Backing off heads for [backing.spot], not up to 3 tiles further from the player") // PRISONER_COWER_STEP
	TEST_ASSERT(is_line_for(prisoner.last_line, "cower_hit"), "Backing off, the prisoner said [prisoner.last_line]")
	prisoner.end_activity()

	// Already in trouble, they turn on whoever hit them, without a roll.
	var/mob/living/carbon/human/bystander = make_player(prison_spot(home, 7, 9), "hitbackbystander")
	var/mob/living/basic/outpost_prisoner/rioter = trouble_awake_prisoner(prison, prison_spot(home, 7, 8))
	rioter.start_rioting(FALSE)
	hit_with_toolbox(bystander, rioter)
	TEST_ASSERT_EQUAL(rioter.swing_ref?.resolve(), bystander, "A rioter did not turn on the player who hit them")
	TEST_ASSERT_EQUAL(rioter.trouble, "riot", "Turning on the player ended the riot for them") // PRISONER_TROUBLE_RIOT
	prison.tick(1)
	TEST_ASSERT(rioter.retaliating(), "The trouble tick called off a rioter turning on the player who hit them")
	rioter.calm_down()
	rioter.end_retaliation()

	// A guard's blow is not a player's.
	var/mob/living/basic/outpost_prison_guard/guard = guard_test_spawn(prison, prison_spot(home, 10, 9), awake = FALSE)
	TEST_ASSERT_NOTNULL(guard, "The guard did not arrive")
	TEST_ASSERT(!prisoner.may_react_to_hit(guard), "A guard's blow gets a reaction")
	prison.forced_hit_reaction = null
	settle_prison_air(home)

// ===== SHIV BLOWS =====

/**
 * A shiv at a person: 10-15 brute, each blow a stab or a slash with the shiv's wound bonus, so it
 * can leave a puncture or a cut that bleeds. Fists stay blunt and never wound. A guard takes five
 * blows and is still on duty; a stab at another prisoner stays at 7-10.
 */
/datum/unit_test/voidcrew_outpost_prison_shiv_blows
	parent_type = /datum/unit_test/voidcrew_outpost_management
	/// What the last blow on the test player handed apply_damage()
	var/list/last_blow

/datum/unit_test/voidcrew_outpost_prison_shiv_blows/proc/note_blow(datum/source, damage, damagetype, def_zone, blocked, wound_bonus, exposed_wound_bonus, sharpness)
	SIGNAL_HANDLER
	last_blow = list("damage" = damage, "type" = damagetype, "wound_bonus" = wound_bonus, "exposed" = exposed_wound_bonus, "sharpness" = sharpness)

/// One blow from `prisoner` at a freshly healed `warden`; returns the brute it did
/datum/unit_test/voidcrew_outpost_prison_shiv_blows/proc/blow(mob/living/basic/outpost_prisoner/prisoner, mob/living/carbon/human/warden)
	warden.fully_heal()
	last_blow = null
	prisoner.strike(warden)
	return warden.getBruteLoss()

/datum/unit_test/voidcrew_outpost_prison_shiv_blows/Run()
	var/obj/structure/overmap/dynamic/player_outpost/home = trouble_test_claim("shivowner")
	TEST_ASSERT_NOTNULL(home, "The shiv test prison did not load")
	var/datum/outpost_prison/prison = test_prison(home)
	var/mob/living/basic/outpost_prisoner/prisoner = trouble_prisoner(prison, prison_spot(home, 8, 8), "grumpy")
	var/mob/living/carbon/human/warden = make_player(prison_spot(home, 9, 8), "shivowner")
	RegisterSignal(warden, COMSIG_MOB_APPLY_DAMAGE, PROC_REF(note_blow))
	// A body that takes any wound a blow is able to give, so whether it can wound is not left to the
	// dice. Every part: tg picks where a basic mob's blow lands (attack_zone_randomiser), mostly the chest.
	var/list/resistances = list()
	for(var/obj/item/bodypart/part as anything in warden.bodyparts)
		resistances[part] = part.wound_resistance
		part.wound_resistance = -1000

	// A punch: 5-8 brute (PRISONER_PUNCH_MIN/MAX), blunt, and it never wounds.
	var/dealt = blow(prisoner, warden)
	TEST_ASSERT_NOTNULL(last_blow, "The punch never reached apply_damage()")
	TEST_ASSERT(dealt >= 5 && dealt <= 8, "A punch did [dealt] brute, not 5-8")
	TEST_ASSERT_EQUAL(last_blow["type"], BRUTE, "A punch did [last_blow["type"]] damage")
	TEST_ASSERT_EQUAL(last_blow["sharpness"], NONE, "A punch was sharp")
	TEST_ASSERT_EQUAL(last_blow["wound_bonus"], CANT_WOUND, "A punch could wound")
	TEST_ASSERT(!length(warden.all_wounds), "A punch wounded")

	// A shiv: 10-15 brute (PRISONER_SHIV_MIN/MAX), a stab (a puncture) or a slash (a cut), with the
	// glass shiv's wound bonus of 5 and 15 on bare skin (PRISONER_SHIV_WOUND_BONUS, _EXPOSED_WOUND_BONUS).
	prisoner.draw_shiv()
	TEST_ASSERT(prisoner.has_shiv(), "The prisoner did not draw a shiv")
	var/stabs = 0
	var/slashes = 0
	for(var/i in 1 to 20)
		dealt = blow(prisoner, warden)
		TEST_ASSERT_NOTNULL(last_blow, "A shiv blow never reached apply_damage()")
		TEST_ASSERT(dealt >= 10 && dealt <= 15, "A shiv did [dealt] brute, not 10-15")
		TEST_ASSERT_EQUAL(last_blow["type"], BRUTE, "A shiv did [last_blow["type"]] damage")
		TEST_ASSERT_EQUAL(last_blow["wound_bonus"], 5, "A shiv's wound bonus was [last_blow["wound_bonus"]], not 5")
		TEST_ASSERT_EQUAL(last_blow["exposed"], 15, "A shiv's bare skin wound bonus was [last_blow["exposed"]], not 15")
		var/datum/wound/wound = length(warden.all_wounds) ? warden.all_wounds[1] : null
		switch(last_blow["sharpness"])
			if(SHARP_POINTY)
				stabs++
				TEST_ASSERT_EQUAL(prisoner.attack_verb_continuous, "stabs", "A stab read as [prisoner.attack_verb_continuous]")
				TEST_ASSERT(istype(wound, /datum/wound/pierce), "A stab left [wound ? wound.type : "no wound"], not a puncture")
			if(SHARP_EDGED)
				slashes++
				TEST_ASSERT_EQUAL(prisoner.attack_verb_continuous, "slashes", "A slash read as [prisoner.attack_verb_continuous]")
				TEST_ASSERT(istype(wound, /datum/wound/slash), "A slash left [wound ? wound.type : "no wound"], not a cut")
			else
				TEST_FAIL("A shiv blow had sharpness [last_blow["sharpness"]], neither a stab nor a slash")
		TEST_ASSERT(warden.is_bleeding(), "A shiv wound does not bleed")
	TEST_ASSERT(stabs && slashes, "Twenty shiv blows were [stabs] stabs and [slashes] slashes")

	// A guard takes the same blows and is still on duty after five of them (down at 30 of 120 health).
	warden.fully_heal()
	warden.forceMove(prison_spot(home, 12, 4))
	var/mob/living/basic/outpost_prison_guard/guard = guard_test_spawn(prison, prison_spot(home, 9, 8), awake = FALSE)
	TEST_ASSERT_NOTNULL(guard, "The guard did not arrive")
	for(var/i in 1 to 5)
		TEST_ASSERT(prisoner.strike(guard), "The prisoner could not strike the guard")
	TEST_ASSERT(guard.health >= 45 && guard.health <= 70, "Five shiv blows left a guard at [guard.health] health, not 45-70")
	TEST_ASSERT_EQUAL(guard.phase, "present", "Five shiv blows put a guard [guard.phase]") // OUTPOST_GUARD_PRESENT

	// At another prisoner a stab stays at 7-10 (PRISONER_STAB_MIN/MAX); the mercy rule is tested with fights.
	guard.forceMove(prison_spot(home, 13, 4))
	var/mob/living/basic/outpost_prisoner/other = trouble_prisoner(prison, prison_spot(home, 9, 8))
	var/health_before = other.health
	TEST_ASSERT(prisoner.strike(other), "The prisoner could not stab another prisoner")
	TEST_ASSERT(health_before - other.health >= 7 && health_before - other.health <= 10, "A stab at a prisoner did [health_before - other.health], not 7-10")
	other.forceMove(prison_spot(home, 13, 8))

	// The shiv put away, fists are blunt again and never wound.
	prisoner.drop_shiv()
	TEST_ASSERT(!prisoner.has_shiv(), "The prisoner kept the shiv")
	warden.forceMove(prison_spot(home, 9, 8))
	dealt = blow(prisoner, warden)
	TEST_ASSERT(dealt >= 5 && dealt <= 8, "A punch after the shiv did [dealt] brute, not 5-8")
	TEST_ASSERT_EQUAL(last_blow["sharpness"], NONE, "A punch after the shiv was sharp")
	TEST_ASSERT_EQUAL(last_blow["wound_bonus"], CANT_WOUND, "A punch after the shiv could wound")
	TEST_ASSERT(!length(warden.all_wounds), "A punch after the shiv wounded")

	for(var/obj/item/bodypart/part as anything in resistances)
		part.wound_resistance = resistances[part]
	UnregisterSignal(warden, COMSIG_MOB_APPLY_DAMAGE)
	settle_prison_air(home)
