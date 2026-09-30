/**
 * The yard's feel (outpost_prison_ambience.dm) and its strings file: heads turning at a member
 * coming in, moods read on examine, sulking and humming, the hush, the chant and the roar. Built
 * turrets are tested in voidcrew_outpost_prison_built_turrets.dm.
 *
 * Voidcrew defines are not visible from test files, so tuning values appear as literals with the
 * define named beside them. Prisons are driven by calling their procs with their own processing
 * stopped; nobody is on the level, so tests that need an AI running use trouble_awake_prisoner()
 * (voidcrew_outpost_prison_trouble.dm). Fixtures are in voidcrew_outpost_prison_helpers.dm; the
 * wing's authored layout has the cell block's south wall on row 6, the yard on rows 7 to 11 and
 * the warden's office on rows 2 to 5.
 */

// ===== THE STRINGS FILE =====

/datum/unit_test/voidcrew_outpost_prison_security_files

/datum/unit_test/voidcrew_outpost_prison_security_files/Run()
	// The file is read the way outpost_prisoner_extra_dialogue() reads it (the strings directory is a define)
	load_strings_file("outpost_prison_security.json", "voidcrew/modules/player_outposts/strings")
	var/list/contents = GLOB.string_cache["outpost_prison_security.json"]
	TEST_ASSERT(islist(contents), "outpost_prison_security.json did not load")
	TEST_ASSERT(islist(contents["lines"]), "outpost_prison_security.json has no lines block")
	TEST_ASSERT(islist(contents["examine"]), "outpost_prison_security.json has no examine block")

	// Every context the yard says, turrets included (the X0 dialogue test holds the lines to the house rules)
	var/list/lines = contents["lines"]
	for(var/context in list("turret_hit", "turret_smash", "greet_staff", "staff_enters_restless", "huddle", "riot_chant", "riot_roar"))
		TEST_ASSERT(islist(lines[context]), "outpost_prison_security.json has no lines for [context]")

	// The examine moods: every band has shared lines and lines for every personality, never a number,
	// and only the pronoun placeholders fill_examine_line() knows
	var/list/personalities = outpost_prisoner_dialogue("personalities")
	var/list/examine = contents["examine"]
	var/regex/digit = regex("\[0-9\]")
	for(var/band in list("mood_0", "mood_20", "mood_35", "mood_50", "mood_75"))
		var/list/entry = examine[band]
		TEST_ASSERT(islist(entry), "The examine block has no [band]")
		if(!islist(entry))
			continue
		for(var/pool in list("any") + personalities)
			TEST_ASSERT(length(entry[pool]), "The examine block's [band] has no lines for [pool]")
		for(var/pool in entry)
			TEST_ASSERT(pool == "any" || (pool in personalities), "The examine block's [band] has lines for [pool], which is not a personality")
			for(var/line in entry[pool])
				TEST_ASSERT(istext(line) && length(line), "The examine block's [band]/[pool] has an empty line")
				if(!istext(line))
					continue
				TEST_ASSERT_EQUAL(length(line), length_char(line), "An examine line is not plain ASCII: [line]")
				TEST_ASSERT(length(splittext(line, " ")) <= 20, "An examine line is over 20 words: [line]")
				TEST_ASSERT(!digit.Find(line), "An examine line has a number in it: [line]")
				var/bare = line
				for(var/placeholder in GLOB.outpost_prisoner_examine_placeholders)
					bare = replacetext(bare, placeholder, "")
				TEST_ASSERT(!findtext(bare, "{") && !findtext(bare, "}"), "An examine line has an unknown placeholder: [line]")

// ===== THE YARD NOTICES YOU, AND MOODS YOU CAN READ =====

/datum/unit_test/voidcrew_outpost_prison_ambience_yard
	parent_type = /datum/unit_test/voidcrew_outpost_management

/datum/unit_test/voidcrew_outpost_prison_ambience_yard/Run()
	var/obj/structure/overmap/dynamic/player_outpost/home = prison_test_claim("xbyardowner")
	TEST_ASSERT_NOTNULL(home, "The yard test prison did not load")
	var/datum/outpost_prison/prison = test_prison(home)
	var/mob/living/carbon/human/member = make_player(prison_spot(home, 9, 8), "xbyardowner")
	var/mob/living/carbon/human/stranger = make_player(prison_spot(home, 10, 8), "xbyardstranger")
	var/mob/living/basic/outpost_prisoner/content = trouble_awake_prisoner(prison, prison_spot(home, 8, 10), "cheerful")
	var/mob/living/basic/outpost_prisoner/sour = trouble_awake_prisoner(prison, prison_spot(home, 10, 10), "grumpy")

	// A member walks in: the content one looks over, the sour one stares and goes quiet
	content.set_mood(60)
	sour.set_mood(30)
	content.setDir(NORTH)
	sour.setDir(NORTH)
	sour.speech_cooldown = 0
	TEST_ASSERT_EQUAL(prison.note_people_inside(list(member)), 2, "Both prisoners did not react to a member coming in")
	TEST_ASSERT_EQUAL(content.dir, SOUTH, "The content prisoner did not look at the member")
	TEST_ASSERT_EQUAL(sour.dir, SOUTH, "The sour prisoner did not look at the member")
	TEST_ASSERT(sour.speech_cooldown > world.time + 15 SECONDS, "The sour prisoner did not go quiet while staring") // OUTPOST_PRISONER_NOTICE_STARE_HUSH 20 s

	// Out and in again within a minute: nothing, even with the prisoners' own cooldowns cleared
	TEST_ASSERT_EQUAL(prison.note_people_inside(list()), 0, "Leaving the cell block turned heads")
	content.ambience_notice_cooldown = 0
	sour.ambience_notice_cooldown = 0
	TEST_ASSERT_EQUAL(prison.note_people_inside(list(member)), 0, "Coming back in within a minute turned heads again") // OUTPOST_PRISON_NOTICE_GAP 60 s

	// A stranger coming in turns no heads
	prison.ambience_notice_cooldown = 0
	prison.note_people_inside(list())
	TEST_ASSERT_EQUAL(prison.note_people_inside(list(stranger)), 0, "A stranger coming in turned heads")
	TEST_ASSERT(prison.note_people_inside(list(member)) > 0, "A member coming in once the cooldowns ran out turned no heads")

	// Examine: one mood line by band and personality, filled in, never a number
	var/regex/digit = regex("\[0-9\]")
	var/list/bands = list("10" = "mood_0", "25" = "mood_20", "40" = "mood_35", "60" = "mood_50", "80" = "mood_75")
	for(var/personality in outpost_prisoner_dialogue("personalities"))
		content.personality = personality
		for(var/mood_text in bands)
			content.set_mood(text2num(mood_text))
			TEST_ASSERT_EQUAL(content.mood_examine_band(), bands[mood_text], "Mood [mood_text] reads as the wrong band")
			var/line = content.mood_examine_line()
			TEST_ASSERT(istext(line) && length(line), "A [personality] prisoner at mood [mood_text] has no examine line")
			if(!istext(line))
				continue
			TEST_ASSERT(!findtext(line, "{") && !findtext(line, "}"), "An examine line was left unfilled: [line]")
			TEST_ASSERT(!digit.Find(line), "An examine line has a number in it: [line]")
	var/list/examined = content.examine(member)
	TEST_ASSERT(findtext(jointext(examined, " "), content.mood_examine_line()), "Examining a prisoner does not show their mood")

	// A closer look: the crime and roughly the time left, rounded to five minutes
	var/list/closer = content.examine_more(member)
	TEST_ASSERT(findtext(jointext(closer, " "), "In for"), "A closer look does not show the crime")
	content.sentence_left = 100
	TEST_ASSERT_EQUAL(content.sentence_examine_text(), "a few minutes", "A short sentence does not read as a few minutes")
	content.sentence_left = 1500
	TEST_ASSERT_EQUAL(content.sentence_examine_text(), "about 25 minutes", "Twenty-five minutes did not round to 25")

	// Sulking is for sour prisoners only (OUTPOST_PRISONER_SULK_MOOD 45)
	var/datum/prisoner_activity/sulk/sulk = new(sour)
	sour.set_mood(45)
	TEST_ASSERT_EQUAL(sulk.get_weight(), 0, "A prisoner at mood 45 wants to sulk")
	sour.set_mood(30)
	TEST_ASSERT(sulk.get_weight() > 0, "A sour prisoner never sulks")
	qdel(sulk)

	// Humming: content cheerful, chatty or quiet prisoners, once per cooldown (OUTPOST_PRISONER_HUM_COOLDOWN 3 min)
	content.personality = "cheerful"
	content.set_mood(80)
	sour.set_mood(80)
	TEST_ASSERT(prison.try_hum(content), "A content cheerful prisoner did not hum")
	TEST_ASSERT(!prison.try_hum(content), "A prisoner hummed again inside the cooldown")
	TEST_ASSERT(!prison.try_hum(sour), "A grumpy prisoner hummed")
	settle_prison_air(home)

// ===== A RIOT YOU HEAR COMING =====

/datum/unit_test/voidcrew_outpost_prison_ambience_riot
	parent_type = /datum/unit_test/voidcrew_outpost_management

/datum/unit_test/voidcrew_outpost_prison_ambience_riot/Run()
	var/obj/structure/overmap/dynamic/player_outpost/home = prison_test_claim("xbriotowner")
	TEST_ASSERT_NOTNULL(home, "The riot sounds test prison did not load")
	var/datum/outpost_prison/prison = test_prison(home)
	TEST_ASSERT_EQUAL(prison.wing.sound_environment, SOUND_AREA_LARGE_ENCLOSED, "The prison wing does not echo like a large hard room")

	// Beside the mess table on row 9, gathered in the yard
	var/mob/living/basic/outpost_prisoner/gathered = trouble_awake_prisoner(prison, prison_spot(home, 4, 8))
	var/datum/prisoner_activity/gather/huddle = new(gathered)
	huddle.started = TRUE
	gathered.start_activity(huddle)

	// The hush: small talk and chat go quiet in a restless wing, complaints do not
	prison.stage = "restless" // PRISON_STAGE_RESTLESS
	TEST_ASSERT(prison.speech_hushed(gathered, "idle"), "Small talk was not hushed in a restless wing")
	TEST_ASSERT(prison.speech_hushed(gathered, "conversation"), "Conversation was not hushed in a restless wing")
	TEST_ASSERT(!prison.speech_hushed(gathered, "restless"), "Restless complaints were hushed")
	TEST_ASSERT(prison.try_huddle(gathered), "A gathered prisoner did not whisper in a restless wing")
	TEST_ASSERT(!prison.try_huddle(gathered), "A gathered prisoner whispered again inside the gap") // OUTPOST_PRISONER_HUDDLE_GAP 20 s
	prison.stage = "calm" // PRISON_STAGE_CALM
	TEST_ASSERT(!prison.speech_hushed(gathered, "idle"), "Small talk was hushed in a calm wing")

	// The chant: only while a riot brews, every 2 s, every second near the end of the hold, and never after
	prison.stage = "restless" // PRISON_STAGE_RESTLESS
	TEST_ASSERT(!prison.chant_tick(1), "The yard chanted with no riot brewing")
	prison.riot_imminent = TRUE
	prison.riot_hold = 0
	TEST_ASSERT(!prison.chant_tick(1), "The chant beat after one second") // OUTPOST_PRISON_CHANT_GAP 2
	TEST_ASSERT(prison.chant_tick(1), "The chant did not beat after two seconds")
	prison.riot_hold = 40 // past PRISON_RIOT_HOLD 45 - OUTPOST_PRISON_CHANT_LATE_WINDOW 10
	TEST_ASSERT(prison.chant_tick(1), "The chant did not beat every second near the end of the hold")
	var/list/slammers = prison.chant_beat()
	TEST_ASSERT(gathered in slammers, "A gathered prisoner beside a mess table did not slam it")
	prison.riot_imminent = FALSE
	TEST_ASSERT(!prison.chant_tick(1), "The chant carried on once the riot stopped brewing")
	TEST_ASSERT_EQUAL(prison.ambience_chant_clock, 0, "The chant's clock did not reset once the riot stopped brewing")

	// The roar: every rioter on their feet, once per riot
	gathered.end_activity(cancel_ai = FALSE)
	var/mob/living/basic/outpost_prisoner/rioter = trouble_awake_prisoner(prison, prison_spot(home, 8, 8))
	rioter.trouble = "riot" // PRISONER_TROUBLE_RIOT
	prison.riot_active = TRUE
	TEST_ASSERT_EQUAL(prison.roar_tick(), 1, "The rioter did not roar as the riot started")
	TEST_ASSERT_EQUAL(prison.roar_tick(), 0, "The rioters roared twice in one riot")
	prison.riot_active = FALSE
	TEST_ASSERT_EQUAL(prison.roar_tick(), 0, "Somebody roared with no riot on")
	prison.riot_active = TRUE
	TEST_ASSERT_EQUAL(prison.roar_tick(), 1, "The rioter did not roar at the next riot")
	prison.riot_active = FALSE
	rioter.trouble = null
	prison.stage = "calm" // PRISON_STAGE_CALM
	settle_prison_air(home)
