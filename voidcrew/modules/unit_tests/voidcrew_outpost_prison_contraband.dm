/**
 * Contraband, shakedowns and mail call (outpost_prison_contraband.dm, outpost_prison_mail.dm). Owner: XF.
 * The tests of extras-plan.md 4.14 (stashes, searches, pruno, the pat-down, riots and tension) and
 * 4.15 (mail waves by drop pod, delivery by hand and by hatch, opened letters, contraband in the
 * post, expiry and clean-up), plus the admin actions.
 *
 * Voidcrew defines are not visible from test files, so tuning values appear as literals with the
 * define named beside them. Prisons are driven with tick(seconds) (or the package's own tick) with
 * their own processing stopped; fixtures are in voidcrew_outpost_prison_helpers.dm, and awake
 * prisoners (trouble_awake_prisoner()) in voidcrew_outpost_prison_trouble.dm. Rolls are forced
 * with the prison's contraband_force_rolls. The unrotated wing's cell 1 is x 2-4, y 13-15, with its
 * bed at (2,15) and its toilet at (4,15); the first prisoner booked in gets it.
 */

// ===== HELPERS =====

/// Whether `line` is one of the lines for `context`, in whichever dialogue file has it
/datum/unit_test/voidcrew_outpost_management/proc/contraband_line_for(line, context)
	var/list/entry = outpost_prisoner_context_lines(context)
	if(!islist(entry) || !line)
		return FALSE
	for(var/pool_key in entry)
		for(var/candidate in entry[pool_key])
			if(findtext(candidate, "{"))
				// A line with placeholders: compare what is left of it around them.
				var/list/parts = splittext(candidate, regex("\\{\[a-z_\]+\\}"))
				var/all_found = TRUE
				for(var/part in parts)
					if(length(part) && !findtext(line, part))
						all_found = FALSE
						break
				if(all_found)
					return TRUE
			else if(candidate == line)
				return TRUE
	return FALSE

/// The newest line of the prison's log
/datum/unit_test/voidcrew_outpost_management/proc/contraband_last_log(datum/outpost_prison/prison)
	if(!length(prison.entries))
		return ""
	var/list/newest = prison.entries[1]
	return newest["text"]

// ===== FILES =====

/datum/unit_test/voidcrew_outpost_prison_contraband_files

/datum/unit_test/voidcrew_outpost_prison_contraband_files/Run()
	// The file is read the way outpost_prisoner_extra_dialogue() reads it (the strings directory is a define)
	load_strings_file("outpost_prison_contraband.json", "voidcrew/modules/player_outposts/strings")
	var/list/contents = GLOB.string_cache["outpost_prison_contraband.json"]
	TEST_ASSERT(islist(contents), "outpost_prison_contraband.json did not load")
	TEST_ASSERT(islist(contents["lines"]), "outpost_prison_contraband.json has no lines block")
	TEST_ASSERT(islist(contents["letters"]), "outpost_prison_contraband.json has no letters block")
	TEST_ASSERT(islist(contents["senders"]), "outpost_prison_contraband.json has no senders block")
	// Every kind of letter has templates naming the prisoner and the sender
	var/list/letters = contents["letters"]
	for(var/kind in list("good", "kid", "news", "bad", "contraband"))
		var/list/templates = letters[kind]
		TEST_ASSERT(length(templates), "outpost_prison_contraband.json has no [kind] letters")
		for(var/template in templates)
			TEST_ASSERT(findtext(template, "{name}") && findtext(template, "{sender}"), "A [kind] letter does not name its prisoner and sender: [template]")
			TEST_ASSERT_EQUAL(length(template), length_char(template), "A [kind] letter is not plain ASCII: [template]")
	TEST_ASSERT(length(contents["senders"]), "outpost_prison_contraband.json has no senders")
	// Every context the code says is there
	var/list/lines = contents["lines"]
	for(var/context in list("contraband_hide", "contraband_inherit", "drunk", "shakedown_found", "shakedown_empty", "patdown_found", "patdown_empty", "patdown_onlooker", "mail_waiting", "mail_good", "mail_kid", "mail_news", "mail_bad", "mail_opened", "mail_not_mine"))
		TEST_ASSERT(islist(lines[context]), "outpost_prison_contraband.json has no [context] lines")

// ===== SHIVS: MAKING ONE, RIOTS, TENSION =====

/datum/unit_test/voidcrew_outpost_prison_contraband_shivs
	parent_type = /datum/unit_test/voidcrew_outpost_management

/datum/unit_test/voidcrew_outpost_prison_contraband_shivs/Run()
	var/obj/structure/overmap/dynamic/player_outpost/home = trouble_test_claim("xfshivowner")
	TEST_ASSERT_NOTNULL(home, "The shiv test prison did not load")
	var/datum/outpost_prison/prison = test_prison(home)
	var/mob/living/basic/outpost_prisoner/prisoner = trouble_awake_prisoner(prison, prison_spot(home, 3, 14))
	var/datum/outpost_prison_cell/cell = prisoner.cell
	TEST_ASSERT(cell?.contains(prison_spot(home, 2, 15)), "The first prisoner was not booked into cell 1")
	TEST_ASSERT_NOTNULL(cell.bed(), "Cell 1 has no bed")

	// The sour clock: 300 seconds under mood 40 (OUTPOST_CONTRABAND_SOUR_TIME, _SHIV_MOOD); it holds below 45 and resets at 45 (_SOUR_RESET)
	prisoner.set_mood(39)
	prisoner.contraband_counters(299)
	TEST_ASSERT(!prisoner.contraband_can_make_shiv(), "299 seconds under mood 40 was enough for a shiv")
	prisoner.contraband_counters(1)
	TEST_ASSERT(prisoner.contraband_can_make_shiv(), "300 seconds under mood 40 was not enough for a shiv")
	prisoner.set_mood(42)
	prisoner.contraband_counters(10)
	TEST_ASSERT(prisoner.contraband_can_make_shiv(), "Mood 42 reset the sour clock")
	prisoner.set_mood(46)
	prisoner.contraband_counters(1)
	TEST_ASSERT_EQUAL(prisoner.contraband_shiv_sour, 0, "Mood 46 did not reset the sour clock")

	// Nobody on the level: nobody starts a stash, however sour
	var/mob/living/basic/outpost_prisoner/dozing = trouble_prisoner(prison, prison_spot(home, 12, 8))
	dozing.set_mood(20)
	dozing.contraband_counters(600)
	prison.contraband_force_rolls = TRUE
	TEST_ASSERT_NULL(prison.contraband_try_start(dozing), "A prisoner whose AI sleeps started on a stash")

	// Sour for five minutes and unwatched: 25 seconds on the bed edge (OUTPOST_CONTRABAND_SHIV_TIME), then under the mattress
	prisoner.set_mood(30)
	prisoner.contraband_counters(300)
	var/datum/prisoner_activity/make_shiv/sharpening = prison.contraband_try_start(prisoner)
	TEST_ASSERT(istype(sharpening), "A prisoner sour for five minutes did not start on a shiv with nobody watching")
	TEST_ASSERT_EQUAL(drive_activity(prisoner, sharpening), 1, "Making a shiv never finished")
	TEST_ASSERT(cell.stash_shiv, "Making a shiv hid nothing under the mattress")
	TEST_ASSERT_EQUAL(prisoner.contraband_shiv_sour, 0, "Making a shiv did not start the sour clock over")
	TEST_ASSERT(!prisoner.has_shiv(), "Making a shiv armed the prisoner")

	// One per cell
	prisoner.contraband_counters(300)
	TEST_ASSERT(!prisoner.contraband_can_make_shiv(), "A cell with a shiv let its prisoner make another")
	var/datum/prisoner_activity/second_try = prison.contraband_try_start(prisoner)
	TEST_ASSERT(!istype(second_try, /datum/prisoner_activity/make_shiv), "A second shiv was started in an armed cell")
	prisoner.end_activity()

	// Staff in sight stop it: no shiv, a denial, and the sour clock starts over
	cell.stash_shiv = FALSE
	prisoner.forceMove(prison_spot(home, 3, 14))
	prisoner.contraband_counters(300)
	var/datum/prisoner_activity/make_shiv/caught = new(prisoner)
	TEST_ASSERT(caught.setup(), "A prisoner could not get to their own bed to make a shiv")
	prisoner.start_activity(caught)
	var/mob/living/carbon/human/warden = make_player(prison_spot(home, 3, 13), "xfshivowner")
	drive_activity(prisoner, caught)
	TEST_ASSERT(!cell.stash_shiv, "A shiv was made with staff in the cell")
	TEST_ASSERT_EQUAL(prisoner.contraband_shiv_sour, 0, "Being caught did not start the sour clock over")
	TEST_ASSERT(contraband_line_for(prisoner.last_line, "contraband_hide"), "A prisoner caught at it said: [prisoner.last_line]")
	prisoner.contraband_counters(300)
	TEST_ASSERT_NULL(prison.contraband_try_start(prisoner), "A prisoner started on a stash in sight of staff")

	// The riot line goes up by 10 with a shiv under the mattress (PRISON_RIOT_JOIN_CHATTY 50, OUTPOST_CONTRABAND_RIOT_JOIN_BONUS)
	TEST_ASSERT_EQUAL(prisoner.riot_join_mood(), 50, "A chatty prisoner's riot line was not 50 without a stash")
	cell.stash_shiv = TRUE
	TEST_ASSERT_EQUAL(prisoner.riot_join_mood(), 60, "A shiv stash did not raise the riot line by 10")

	// Decision 8: a stash never arms a threat or a fight
	prisoner.set_mood(20)
	prisoner.threaten(warden)
	TEST_ASSERT(!prisoner.has_shiv(), "A threat drew the stashed shiv")
	prisoner.cancel_threat()
	var/mob/living/basic/outpost_prisoner/rival = trouble_awake_prisoner(prison, prison_spot(home, 3, 10))
	var/datum/outpost_prison_fight/brawl = prison.start_fight(prisoner, rival)
	TEST_ASSERT_NOTNULL(brawl, "The test fight did not start")
	TEST_ASSERT(!prisoner.has_shiv() && !rival.has_shiv(), "A fight drew a shiv")
	prison.end_fight(brawl)
	TEST_ASSERT(cell.stash_shiv, "A threat or a fight spent the stash")

	// A rioter draws the stashed shiv: the stash is spent and it is the only shiv there is
	prisoner.start_rioting(FALSE)
	TEST_ASSERT(prisoner.has_shiv(), "A rioter with a stash drew no shiv")
	TEST_ASSERT(!cell.stash_shiv, "Drawing the stashed shiv did not spend the stash")
	var/shivs = 0
	for(var/obj/item/knife/shiv/blade in prisoner)
		shivs++
	for(var/turf/tile as anything in prison.wing_turfs())
		for(var/obj/item/knife/shiv/blade in tile)
			shivs++
	TEST_ASSERT_EQUAL(shivs, 1, "Drawing the stashed shiv left [shivs] shivs in the wing, not 1")
	prisoner.calm_down()
	// Without a stash a rioter still draws a new one
	rival.start_rioting(FALSE)
	TEST_ASSERT(rival.has_shiv(), "A rioter without a stash drew no shiv")
	rival.calm_down()

	// Tension: 2 for each armed, occupied cell, 4 at most (OUTPOST_CONTRABAND_SHIV_TENSION, _TENSION_MAX)
	set_moods(list(prisoner, dozing, rival), 70)
	for(var/datum/outpost_prison_cell/each as anything in prison.cells)
		each.stash_shiv = FALSE
	var/calm_tension = prison.compute_tension()
	TEST_ASSERT_EQUAL(prison.contraband_tension(), 0, "Tension came from shivs nobody hid")
	TEST_ASSERT_NULL(prison.contraband_cause(), "The restless causes named a shiv nobody hid")
	cell.stash_shiv = TRUE
	TEST_ASSERT_EQUAL(prison.contraband_tension(), 2, "One armed cell did not add 2 tension")
	dozing.cell.stash_shiv = TRUE
	TEST_ASSERT_EQUAL(prison.contraband_tension(), 4, "Two armed cells did not add 4 tension")
	rival.cell.stash_shiv = TRUE
	TEST_ASSERT_EQUAL(prison.contraband_tension(), 4, "Three armed cells added more than 4 tension")
	TEST_ASSERT(abs(prison.compute_tension() - calm_tension - 4) < 0.01, "Hidden shivs did not add to the wing's tension")
	TEST_ASSERT(("word of a shiv" in prison.restless_causes()), "The restless causes leave out the hidden shivs")
	// A shiv in an empty cell is nobody's
	for(var/datum/outpost_prison_cell/each as anything in prison.cells)
		each.stash_shiv = !each.occupant
	TEST_ASSERT_EQUAL(prison.contraband_tension(), 0, "A shiv in an empty cell added tension")
	prison.contraband_force_rolls = null
	settle_prison_air(home)

// ===== SEARCHES, THE PAT-DOWN AND PRUNO =====

/datum/unit_test/voidcrew_outpost_prison_contraband_searches
	parent_type = /datum/unit_test/voidcrew_outpost_management

/datum/unit_test/voidcrew_outpost_prison_contraband_searches/Run()
	var/obj/structure/overmap/dynamic/player_outpost/home = prison_test_claim("xfsearchowner")
	TEST_ASSERT_NOTNULL(home, "The search test prison did not load")
	var/datum/outpost_prison/prison = test_prison(home)
	var/mob/living/basic/outpost_prisoner/owner = trouble_prisoner(prison, prison_spot(home, 2, 14))
	var/mob/living/basic/outpost_prisoner/neighbour = trouble_prisoner(prison, prison_spot(home, 3, 13))
	var/datum/outpost_prison_cell/cell = owner.cell
	TEST_ASSERT(cell?.contains(prison_spot(home, 2, 15)), "The first prisoner was not booked into cell 1")
	var/obj/structure/bed/bed = cell.bed()
	TEST_ASSERT_NOTNULL(bed, "Cell 1 has no bed")
	var/mob/living/carbon/human/member = make_player(prison_spot(home, 3, 15), "xfsearchowner")
	var/mob/living/carbon/human/visitor = make_player(prison_spot(home, 3, 14), "xfsearchvisitor")

	// The contraband clock hooks the cells' beds: a visitor's right click stops there
	prison.contraband_tick(30) // OUTPOST_CONTRABAND_CLOCK
	TEST_ASSERT_EQUAL(bed.attack_hand_secondary(visitor, list()), SECONDARY_ATTACK_CANCEL_ATTACK_CHAIN, "A visitor's right click on a cell bed went through")

	// Visitors search nothing
	cell.stash_shiv = TRUE
	TEST_ASSERT_NULL(prison.contraband_search_mattress(visitor, bed), "A visitor searched a mattress")
	TEST_ASSERT(cell.stash_shiv, "A visitor's search found the shiv")

	// A member finds it: the shiv in hand, a log line, and the owner denies it and loses 3 (OUTPOST_CONTRABAND_FOUND_MOOD)
	TEST_ASSERT_EQUAL(prison.contraband_search_mattress(member, bed), "found", "A member's search missed the shiv")
	TEST_ASSERT(!cell.stash_shiv, "The found shiv is still under the mattress")
	TEST_ASSERT(member.is_holding_item_of_type(/obj/item/knife/shiv), "The found shiv is not in the searcher's hands")
	TEST_ASSERT(abs(owner.mood - 67) < 0.01, "Finding a shiv cost its owner [70 - owner.mood] mood, not 3")
	TEST_ASSERT(contraband_line_for(owner.last_line, "shakedown_found"), "The owner said [owner.last_line] when a shiv was found")
	TEST_ASSERT(findtext(contraband_last_log(prison), "found a shiv in cell"), "The find was not logged: [contraband_last_log(prison)]")
	member.drop_all_held_items()

	// Within five minutes of that (OUTPOST_CONTRABAND_SEARCH_GAP), searches cost no mood, found or not
	cell.stash_shiv = TRUE
	TEST_ASSERT_EQUAL(prison.contraband_search_mattress(member, bed), "found", "A second search missed the shiv")
	member.drop_all_held_items()
	TEST_ASSERT_EQUAL(prison.contraband_search_mattress(member, bed), "empty", "A search of an empty mattress found something")
	TEST_ASSERT(abs(owner.mood - 67) < 0.01, "Searches within five minutes of the last cost mood")
	TEST_ASSERT(abs(neighbour.mood - 70) < 0.01, "A search within five minutes of the last cost an onlooker mood")

	// After it, an empty search costs the owner 6 and each prisoner watching 1 (OUTPOST_CONTRABAND_EMPTY_MOOD, _ONLOOKER_MOOD)
	cell.searched_at = world.time - 5 MINUTES - 1
	TEST_ASSERT_EQUAL(prison.contraband_search_mattress(member, bed), "empty", "A search of an empty mattress found something")
	TEST_ASSERT(abs(owner.mood - 61) < 0.01, "An empty search cost its owner [67 - owner.mood] mood, not 6")
	TEST_ASSERT(abs(neighbour.mood - 69) < 0.01, "An empty search cost an onlooker [70 - neighbour.mood] mood, not 1")
	TEST_ASSERT(contraband_line_for(owner.last_line, "shakedown_empty"), "The owner said [owner.last_line] after an empty search")

	// The pat-down: members only, from the talk menu
	owner.set_mood(70)
	neighbour.set_mood(70)
	prison.contraband_force_rolls = TRUE
	TEST_ASSERT(("Search" in prison.contraband_talk_choices(owner, member)), "The talk menu offers members no pat-down") // CONTRABAND_PATDOWN_CHOICE
	TEST_ASSERT(!length(prison.contraband_talk_choices(owner, visitor)), "The talk menu offers a visitor a pat-down")
	TEST_ASSERT(!prison.contraband_talk_act(owner, member, "What are you in for?"), "The pat-down took another package's choice") // PRISON_TALK_CRIME
	TEST_ASSERT_NULL(prison.contraband_pat_down(owner, visitor), "A visitor patted a prisoner down")
	// Nothing on them: 3 mood once per five minutes (OUTPOST_CONTRABAND_PATDOWN_MOOD), and someone may speak up for them
	TEST_ASSERT_EQUAL(prison.contraband_pat_down(owner, member), "empty", "A pat-down of a prisoner carrying nothing found something")
	TEST_ASSERT(abs(owner.mood - 67) < 0.01, "An empty pat-down cost [70 - owner.mood] mood, not 3")
	TEST_ASSERT(contraband_line_for(owner.last_line, "patdown_empty"), "The prisoner said [owner.last_line] after an empty pat-down")
	TEST_ASSERT(contraband_line_for(neighbour.last_line, "patdown_onlooker"), "Nobody watching spoke up: [neighbour.last_line]")
	TEST_ASSERT(!owner.talking, "A pat-down left the prisoner held")
	TEST_ASSERT_EQUAL(prison.contraband_pat_down(owner, member), "empty", "A second pat-down found something")
	TEST_ASSERT(abs(owner.mood - 67) < 0.01, "A second pat-down within five minutes cost mood")
	// Carrying something from the mail: a tell on examine, and a pat-down finds it at no cost
	var/obj/item/outpost_prison_contraband/razor_blade/blade = new(get_turf(owner))
	TEST_ASSERT(owner.contraband_carry(blade), "The prisoner could not carry a razor blade")
	TEST_ASSERT(findtext(prison.contraband_examine(owner, member), "pocket"), "Carrying contraband showed no tell on examine")
	TEST_ASSERT_EQUAL(prison.contraband_pat_down(owner, member), "found", "A pat-down missed the razor blade")
	TEST_ASSERT(member.is_holding(blade), "The razor blade did not end up in the searcher's hands")
	TEST_ASSERT_NULL(owner.carried_contraband, "The prisoner still carries what was found")
	TEST_ASSERT(abs(owner.mood - 67) < 0.01, "Finding contraband on a prisoner cost mood")
	TEST_ASSERT(contraband_line_for(owner.last_line, "patdown_found"), "The prisoner said [owner.last_line] when caught")
	member.drop_all_held_items()
	// Someone who won't talk won't put their hands on the wall either (PRISONER_TALK_MIN_MOOD 10)
	owner.set_mood(5)
	TEST_ASSERT_NULL(prison.contraband_pat_down(owner, member), "A prisoner at mood 5 let themselves be patted down")
	// Nor does anyone in the middle of trouble: squaring up, fighting, climbing, lying beaten
	owner.set_mood(70)
	owner.threat_ref = WEAKREF(member)
	TEST_ASSERT_NULL(prison.contraband_pat_down(owner, member), "A prisoner squaring up to staff was patted down")
	owner.threat_ref = null

	// Brewing: six seconds at the tank (OUTPOST_CONTRABAND_BREW_TIME), with nobody watching, puts tg's pruno bag in tg's cistern
	member.forceMove(prison_spot(home, 10, 3))
	visitor.forceMove(prison_spot(home, 11, 3))
	var/obj/structure/toilet/toilet = prison.contraband_cistern(cell)
	TEST_ASSERT_NOTNULL(toilet, "Cell 1 has no toilet")
	var/weight_before = toilet.w_items
	owner.set_mood(50)
	var/datum/prisoner_activity/brew/brewing = new(owner)
	TEST_ASSERT(brewing.setup(), "A prisoner could not get to their own toilet to brew")
	owner.start_activity(brewing)
	TEST_ASSERT_EQUAL(drive_activity(owner, brewing), 1, "Brewing never finished")
	var/obj/item/reagent_containers/cup/glass/bottle/pruno/bag = prison.contraband_pruno(cell)
	TEST_ASSERT(istype(bag), "Brewing left no pruno in the cistern")
	TEST_ASSERT(bag.loc == toilet && (bag in toilet.cistern_items), "The pruno is not in tg's cistern")
	TEST_ASSERT(toilet.w_items > weight_before, "The cistern did not count the pruno's weight")
	var/list/stash_block = prison.contraband_admin_payload()
	var/list/cell_rows = stash_block["cells"]
	var/list/first_row = cell_rows[1]
	TEST_ASSERT_EQUAL(first_row["pruno"], "brewing", "The admin panel does not show the pruno brewing")
	var/datum/prisoner_activity/drink_pruno/thirsty = new(owner)
	TEST_ASSERT_EQUAL(thirsty.get_weight(), 0, "Unfermented pruno was worth a drink")
	qdel(thirsty)
	// tg ferments it by itself in 30 seconds; the test does it now
	bag.do_fermentation()
	TEST_ASSERT(outpost_prison_pruno_ready(bag), "Fermented pruno did not count as ready")
	thirsty = new(owner)
	TEST_ASSERT_EQUAL(thirsty.get_weight(), 6, "Fermented pruno was not worth a drink at mood 50") // OUTPOST_CONTRABAND_DRINK_WEIGHT
	owner.set_mood(70)
	TEST_ASSERT_EQUAL(thirsty.get_weight(), 0, "A content prisoner wanted the pruno") // OUTPOST_CONTRABAND_DRINK_MOOD
	qdel(thirsty)

	// Drinking: 8 mood once, then 120 seconds drunk (OUTPOST_CONTRABAND_PRUNO_MOOD, _DRUNK_TIME)
	owner.set_mood(50)
	TEST_ASSERT(prison.contraband_drink(owner), "The prisoner could not drink their pruno")
	TEST_ASSERT(abs(owner.mood - 58) < 0.01, "Pruno gave [owner.mood - 50] mood, not 8")
	TEST_ASSERT_EQUAL(owner.contraband_drunk_left, 120, "Pruno left the prisoner drunk for [owner.contraband_drunk_left] seconds, not 120")
	TEST_ASSERT(QDELETED(bag), "The drunk bag is still about")
	TEST_ASSERT_NULL(prison.contraband_pruno(cell), "The cell still has pruno after it was drunk")
	TEST_ASSERT_EQUAL(toilet.w_items, weight_before, "The cistern still counts the drunk bag's weight")
	TEST_ASSERT(!prison.contraband_drink(owner), "A prisoner drank from an empty cistern")
	TEST_ASSERT_EQUAL(prison.contraband_fight_mult(owner, neighbour), 1.5, "A drunk did not make a fight likelier") // OUTPOST_CONTRABAND_DRUNK_FIGHT_MULT
	TEST_ASSERT_EQUAL(prison.contraband_fight_mult(neighbour, owner), 1.5, "A drunk on the other side did not make a fight likelier")
	TEST_ASSERT_EQUAL(prison.contraband_spat_mult(), 2, "A drunk did not make spats likelier") // OUTPOST_CONTRABAND_DRUNK_SPAT_MULT
	TEST_ASSERT(findtext(prison.contraband_examine(owner, null), "Sways"), "A drunk showed no tell on examine")
	owner.contraband_counters(120)
	TEST_ASSERT_EQUAL(prison.contraband_fight_mult(owner, neighbour), 1, "The drink outlasted 120 seconds")
	TEST_ASSERT_EQUAL(prison.contraband_spat_mult(), 1, "The wing stayed quarrelsome after the drink wore off")

	// The cistern by hand. With the lid on, a click is tg's own and nothing comes out; a right click flushes.
	bag = prison.contraband_brew_into(cell, toilet)
	TEST_ASSERT_NOTNULL(bag, "No second batch went into the cistern")
	var/weight_with_bag = toilet.w_items
	owner.set_mood(70)
	cell.searched_at = 0
	member.forceMove(prison_spot(home, 3, 15))
	member.drop_all_held_items()
	owner.stand_up()
	toilet.cistern_open = FALSE
	toilet.cover_open = FALSE
	toilet.attack_hand(member, list())
	TEST_ASSERT(!DOING_INTERACTION_WITH_TARGET(member, toilet), "A click on a toilet with its lid on started a search")
	TEST_ASSERT_EQUAL(prison.contraband_pruno(cell), bag, "A click on a toilet with its lid on took the pruno")
	TEST_ASSERT_NULL(prison.contraband_search_cistern(member, toilet), "A cistern with its lid on was searched")
	TEST_ASSERT_EQUAL(toilet.attack_hand_secondary(member, list()), SECONDARY_ATTACK_CANCEL_ATTACK_CHAIN, "A right click on a cell toilet did not flush it")
	TEST_ASSERT(toilet.flushing, "A right click on a cell toilet did not flush it")
	TEST_ASSERT_EQUAL(prison.contraband_pruno(cell), bag, "Flushing took the pruno")
	// With the lid off (tg's crowbar), a visitor's click is refused, "members only", so nobody reaches in round the search's rules
	toilet.cistern_open = TRUE
	TEST_ASSERT(toilet.attack_hand(visitor, list()), "A visitor's click on an open cell cistern went through")
	TEST_ASSERT(!visitor.is_holding(bag) && prison.contraband_pruno(cell) == bag, "A visitor reached into an open cell cistern")
	TEST_ASSERT_NULL(prison.contraband_search_cistern(visitor, toilet), "A visitor searched a cistern")
	// A member's click is the search, not tg's instant grab: four seconds (OUTPOST_CONTRABAND_SEARCH_TIME), the pruno in hand, a find: logged, the owner denies it and loses 3
	TEST_ASSERT(toilet.attack_hand(member, list()), "A member's click on an open cell cistern went on to tg's own")
	TEST_ASSERT(!member.is_holding(bag) && prison.contraband_pruno(cell) == bag, "A member's click on an open cell cistern grabbed the pruno at once")
	TEST_ASSERT(DOING_INTERACTION_WITH_TARGET(member, toilet), "A member's click on an open cell cistern started no search")
	TEST_ASSERT(wait_until(CALLBACK(member, TYPE_PROC_REF(/mob, is_holding), bag), 8 SECONDS), "A member's click on the open cistern never brought out the pruno")
	TEST_ASSERT_NULL(prison.contraband_pruno(cell), "The cell still counts pruno found in the cistern")
	TEST_ASSERT(!(bag in toilet.cistern_items), "The found pruno is still in the cistern")
	TEST_ASSERT_EQUAL(toilet.w_items, weight_with_bag - bag.w_class, "The cistern still counts the found pruno's weight")
	TEST_ASSERT(abs(owner.mood - 67) < 0.01, "Finding pruno in the cistern cost its owner [70 - owner.mood] mood, not 3")
	TEST_ASSERT(contraband_line_for(owner.last_line, "shakedown_found"), "The owner said [owner.last_line] when pruno was found in the cistern")
	TEST_ASSERT(findtext(contraband_last_log(prison), "in the cistern of cell"), "The cistern find was not logged: [contraband_last_log(prison)]")
	member.drop_all_held_items()
	// Nothing in it, after the gap (OUTPOST_CONTRABAND_SEARCH_GAP): an innocent cell, 6 to the owner and 1 to each prisoner watching (_EMPTY_MOOD, _ONLOOKER_MOOD)
	cell.searched_at = world.time - 5 MINUTES - 1
	neighbour.set_mood(70)
	TEST_ASSERT_EQUAL(prison.contraband_search_cistern(member, toilet), "empty", "A search of an empty cistern found something")
	TEST_ASSERT(abs(owner.mood - 61) < 0.01, "An empty cistern search cost its owner [67 - owner.mood] mood, not 6")
	TEST_ASSERT(abs(neighbour.mood - 69) < 0.01, "An empty cistern search cost an onlooker [70 - neighbour.mood] mood, not 1")
	TEST_ASSERT(contraband_line_for(owner.last_line, "shakedown_empty"), "The owner said [owner.last_line] after an empty cistern search")
	// Something that is not contraband is handed over, but the search still counts as empty
	var/obj/item/soap/planted = allocate(/obj/item/soap)
	planted.forceMove(toilet)
	LAZYADD(toilet.cistern_items, planted)
	toilet.w_items += planted.w_class
	TEST_ASSERT_EQUAL(prison.contraband_search_cistern(member, toilet), "empty", "A search that turned up only soap counted as a find")
	TEST_ASSERT(member.is_holding(planted), "The soap in the cistern was not handed over")
	member.drop_all_held_items()
	toilet.cistern_open = FALSE
	prison.contraband_force_rolls = null
	settle_prison_air(home)

// ===== THE CELL KEEPS ITS STASH; ADMIN =====

/datum/unit_test/voidcrew_outpost_prison_contraband_stash_admin
	parent_type = /datum/unit_test/voidcrew_outpost_management

/datum/unit_test/voidcrew_outpost_prison_contraband_stash_admin/Run()
	var/obj/structure/overmap/dynamic/player_outpost/home = prison_test_claim("xfstashowner")
	TEST_ASSERT_NOTNULL(home, "The stash test prison did not load")
	var/datum/outpost_prison/prison = test_prison(home)
	var/mob/living/basic/outpost_prisoner/owner = trouble_prisoner(prison, prison_spot(home, 3, 14))
	var/datum/outpost_prison_cell/cell = owner.cell
	TEST_ASSERT_NOTNULL(cell, "The prisoner has no cell")

	// prison_stash sets and clears, and refuses nonsense
	var/result = prison.contraband_admin_act("prison_stash", list("cell" = "[cell.number]", "kind" = "shiv"), null)
	TEST_ASSERT(istext(result), "prison_stash did not hide a shiv")
	TEST_ASSERT(cell.stash_shiv, "prison_stash hid no shiv")
	result = prison.contraband_admin_act("prison_stash", list("cell" = cell.number, "kind" = "pruno"), null)
	TEST_ASSERT(istext(result), "prison_stash did not brew pruno")
	TEST_ASSERT_NOTNULL(prison.contraband_pruno(cell), "prison_stash put no pruno in the cistern")
	var/list/block = prison.contraband_admin_payload()
	var/list/rows = block["cells"]
	TEST_ASSERT_EQUAL(length(rows), length(prison.cells), "The admin panel does not list every cell")
	var/list/row = rows[1]
	TEST_ASSERT(row["shiv"] && row["pruno"] == "brewing", "The admin panel does not show cell 1's stashes")
	TEST_ASSERT(islist(block["drunk"]) && islist(block["carrying"]), "The admin panel's contraband block is missing its lists")
	result = prison.contraband_admin_act("prison_stash", list("cell" = cell.number, "kind" = "clear"), null)
	TEST_ASSERT(istext(result), "prison_stash did not clear")
	TEST_ASSERT(!cell.stash_shiv && !prison.contraband_pruno(cell), "prison_stash left a stash after clearing")
	TEST_ASSERT(islist(prison.contraband_admin_act("prison_stash", list("cell" = 99, "kind" = "shiv"), null)), "prison_stash took a cell that does not exist")
	TEST_ASSERT(islist(prison.contraband_admin_act("prison_stash", list("cell" = cell.number, "kind" = "bomb"), null)), "prison_stash took an unknown kind")
	TEST_ASSERT(islist(prison.contraband_admin_act("prison_stash", list("cell" = "one", "kind" = "shiv"), null)), "prison_stash took a cell that is not a number")
	TEST_ASSERT_NULL(prison.contraband_admin_act("prison_other", list(), null), "The contraband package took another action")
	TEST_ASSERT(istext(prison.extras_admin_act("prison_stash", list("cell" = cell.number, "kind" = "shiv"), null)), "prison_stash did not come through the extras")

	// The stash stays with the cell when its owner leaves, and the next occupant has it
	prison.forget(owner)
	qdel(owner)
	TEST_ASSERT(cell.stash_shiv, "The stash left with its owner")
	var/mob/living/basic/outpost_prisoner/newcomer = new(prison_spot(home, 3, 14))
	prison.contraband_force_rolls = TRUE
	prison.admit(newcomer, cell)
	TEST_ASSERT_EQUAL(newcomer.cell, cell, "The newcomer was not booked into the armed cell")
	TEST_ASSERT_EQUAL(prison.riot_join_bonus(newcomer), 10, "The newcomer's riot line did not count the stash they inherited") // OUTPOST_CONTRABAND_RIOT_JOIN_BONUS
	TEST_ASSERT(newcomer.contraband_remark_inherited(), "The newcomer said nothing about what they found")
	TEST_ASSERT(contraband_line_for(newcomer.last_line, "contraband_inherit"), "The newcomer said: [newcomer.last_line]")
	prison.contraband_force_rolls = null
	settle_prison_air(home)

// ===== MAIL: WAVES BY DROP POD =====

/datum/unit_test/voidcrew_outpost_prison_mail_arrivals
	parent_type = /datum/unit_test/voidcrew_outpost_management

/datum/unit_test/voidcrew_outpost_prison_mail_arrivals/Run()
	var/obj/structure/overmap/dynamic/player_outpost/home = prison_test_claim("xfmailowner")
	TEST_ASSERT_NOTNULL(home, "The mail test prison did not load")
	var/datum/outpost_prison/prison = test_prison(home)
	var/mob/living/basic/outpost_prisoner/first = trouble_prisoner(prison, prison_spot(home, 7, 8))
	var/mob/living/basic/outpost_prisoner/second = trouble_prisoner(prison, prison_spot(home, 9, 8))

	// The share: a third to a half of those present (OUTPOST_MAIL_WAVE_SHARE_MIN, _MAX), rounded, at
	// least one and never all of them. Two present: always exactly one.
	for(var/i in 1 to 20)
		TEST_ASSERT_EQUAL(length(prison.mail_wave_recipients()), 1, "A wave for two prisoners was not for exactly one")
	var/mob/living/basic/outpost_prisoner/third = trouble_prisoner(prison, prison_spot(home, 11, 8))
	var/mob/living/basic/outpost_prisoner/fourth = trouble_prisoner(prison, prison_spot(home, 13, 8))
	var/list/everyone = list(first, second, third, fourth)
	var/list/sizes = list()
	for(var/i in 1 to 40)
		var/list/picked = prison.mail_wave_recipients()
		TEST_ASSERT(length(picked) >= 1 && length(picked) <= 2, "A wave for four prisoners was for [length(picked)], not 1 or 2")
		sizes["[length(picked)]"] = TRUE
		for(var/mob/living/basic/outpost_prisoner/picked_one as anything in picked)
			TEST_ASSERT(picked_one in everyone, "A wave picked someone who is not a prisoner here")
	TEST_ASSERT(sizes["1"] && sizes["2"], "Waves for four prisoners were always the same size")
	// Only prisoners due a letter: none who had one this stay, none with under 180 seconds left
	// (OUTPOST_MAIL_MIN_SENTENCE). The others still count as present, so the share stays of four.
	first.mail_had_letter = TRUE
	second.sentence_left = 179
	for(var/i in 1 to 20)
		var/list/picked = prison.mail_wave_recipients()
		TEST_ASSERT(length(picked) >= 1 && !(first in picked) && !(second in picked), "A wave picked a prisoner not due a letter")
	third.mail_had_letter = TRUE
	fourth.mail_had_letter = TRUE
	TEST_ASSERT_EQUAL(length(prison.mail_wave_recipients()), 0, "A wave picked someone with nobody due a letter")
	TEST_ASSERT_EQUAL(prison.mail_wave(), 0, "A mail pod came with nobody due a letter")
	TEST_ASSERT_NULL(find_landing_zone(prison), "A mail pod is coming with nobody due a letter")
	for(var/mob/living/basic/outpost_prisoner/prisoner as anything in everyone)
		prisoner.mail_had_letter = FALSE
		prisoner.sentence_left = 3600

	// Mail is aimed at the office side of a serving hatch, and a crate is never put where it would
	// cut something off: in front of hatch 1's office side (5,5), which the dispenser and the table
	// hem in, it would seal that hatch from the office.
	var/list/hatch_sides = list()
	for(var/turf/tile as anything in prison.wing_turfs())
		var/obj/structure/table/reinforced/prison_hatch/hatch = locate() in tile
		if(hatch)
			hatch_sides += hatch.staff_side_turf()
	TEST_ASSERT_EQUAL(length(hatch_sides), 2, "The wing should have two serving hatches")
	TEST_ASSERT(prison.mail_office_spot() in hatch_sides, "Mail is not aimed at a serving hatch's office side")
	TEST_ASSERT(!prison.mail_office_stays_open(prison.mail_office_walkable(), prison_spot(home, 5, 4)), "A crate at (5,4) would not cut off hatch 1's office side")

	// The landing spot: a free floor tile of the office, off the cell block, with nothing on it, no
	// door beside it, and leaving the office in one piece.
	var/turf/landing = prison.mail_pod_landing_turf()
	TEST_ASSERT_NOTNULL(landing, "The mail pod has nowhere to land in the office")
	TEST_ASSERT(get_dist(landing, prison.mail_office_spot()) <= 2, "The mail pod lands [get_dist(landing, prison.mail_office_spot())] tiles from the hatch")
	check_landing(prison, landing)
	TEST_ASSERT_EQUAL(landing.loc, prison.wing, "The mail pod lands outside the wing with the office free")
	// Never on a mob or anything dense
	var/mob/living/carbon/human/in_the_way = make_player(landing, "xfmailinway")
	TEST_ASSERT(prison.mail_pod_landing_turf() != landing, "The mail pod would land on someone")
	in_the_way.forceMove(run_loc_floor_bottom_left)
	var/obj/structure/closet/crate/crate = allocate(/obj/structure/closet/crate, landing)
	TEST_ASSERT(prison.mail_pod_landing_turf() != landing, "The mail pod would land on a crate")
	qdel(crate)

	// The clock: nobody home, it waits
	prison.crew_home_override = FALSE
	prison.mail_next_in = 1
	prison.mail_tick(10)
	TEST_ASSERT_EQUAL(prison.mail_next_in, 1, "The mail clock ran with nobody home")
	TEST_ASSERT_NULL(find_landing_zone(prison), "A mail pod came with nobody home")

	// Home: the clock runs out, a pod comes down, and the next is 15 to 25 minutes off
	// (OUTPOST_MAIL_WAVE_GAP_MIN, _MAX). Its letters only count as waiting once the crate lands.
	prison.crew_home_override = TRUE
	prison.mail_tick(1)
	TEST_ASSERT(prison.mail_next_in >= 900 && prison.mail_next_in <= 1500, "The next mail pod is [prison.mail_next_in] seconds off")
	var/obj/effect/pod_landingzone/zone = find_landing_zone(prison)
	TEST_ASSERT_NOTNULL(zone, "No mail pod came when the clock ran out")
	var/turf/pod_turf = get_turf(zone)
	check_landing(prison, pod_turf, ignore_zone = TRUE)
	TEST_ASSERT_EQUAL(length(prison.mail_waiting_letters()), 0, "Letters counted as waiting before the pod landed")
	// Someone standing beside the landing comes to no harm
	var/turf/beside_pod
	for(var/turf/open/floor in orange(1, pod_turf))
		if(!floor.is_blocked_turf(exclude_mobs = FALSE) && floor.loc == prison.wing && !prison.in_cell_block(floor))
			beside_pod = floor
			break
	TEST_ASSERT_NOTNULL(beside_pod, "No floor beside the landing for a bystander")
	var/mob/living/carbon/human/bystander = make_player(beside_pod, "xfmailbystander")
	TEST_ASSERT(wait_until(CALLBACK(src, PROC_REF(crate_on), pod_turf), 12 SECONDS), "The mail pod never dropped its crate")
	// tg's mail crate, shut, holding this wave's prison letters and nothing else
	var/obj/structure/closet/crate/mail/mail_crate = locate() in pod_turf
	TEST_ASSERT_EQUAL(mail_crate.type, /obj/structure/closet/crate/mail, "The mail pod dropped [mail_crate.type], not tg's mail crate")
	TEST_ASSERT(!mail_crate.opened && mail_crate.icon_state == "mailsealed", "The mail crate did not land shut")
	var/letters_in_crate = 0
	for(var/atom/movable/inside as anything in mail_crate.contents)
		TEST_ASSERT(istype(inside, /obj/item/mail/envelope/outpost_prison), "The mail crate holds [inside.type]")
		letters_in_crate++
	TEST_ASSERT(letters_in_crate >= 1 && letters_in_crate <= 2, "The crate holds [letters_in_crate] letters for four prisoners")
	TEST_ASSERT_EQUAL(length(prison.mail_waiting_letters()), letters_in_crate, "The crate's letters do not all count as waiting")
	TEST_ASSERT(findtext(contraband_last_log(prison), "Mail call: a pod dropped [letters_in_crate] letter"), "The mail call was not logged: [contraband_last_log(prison)]")
	var/lettered = 0
	for(var/mob/living/basic/outpost_prisoner/prisoner as anything in everyone)
		if(prisoner.mail_had_letter)
			lettered++
	TEST_ASSERT(lettered < length(everyone), "Every prisoner had a letter")
	TEST_ASSERT(wait_until(CALLBACK(src, PROC_REF(pod_gone), pod_turf), 8 SECONDS), "The mail pod never left")
	TEST_ASSERT_EQUAL(bystander.get_total_damage(), 0, "The mail pod hurt someone beside it")
	TEST_ASSERT(bystander.body_position == STANDING_UP && !bystander.IsKnockdown() && !bystander.IsStun() && !bystander.IsParalyzed(), "The mail pod knocked down or stunned someone beside it")
	TEST_ASSERT(!QDELETED(mail_crate) && mail_crate.loc == pod_turf, "The mail crate left with the pod")
	check_office_open(prison)
	// Opened, it lets the letters out onto the floor, still waiting, and stays behind as an empty crate
	TEST_ASSERT(mail_crate.open(null, TRUE), "The mail crate would not open")
	var/letters_out = 0
	for(var/obj/item/mail/envelope/outpost_prison/envelope in pod_turf)
		letters_out++
	TEST_ASSERT_EQUAL(letters_out, letters_in_crate, "Opening the crate let out [letters_out] of [letters_in_crate] letters")
	TEST_ASSERT_EQUAL(length(prison.mail_waiting_letters()), letters_in_crate, "Opening the crate changed the letters waiting")
	TEST_ASSERT_EQUAL(mail_crate.icon_state, "mailopen", "The emptied mail crate does not look empty")

	// prison_mail_wave calls a pod now, for those still due a letter, and starts the clock over.
	// It comes down somewhere other than the first crate.
	prison.mail_next_in = 5
	var/waiting_before = length(prison.mail_waiting_letters())
	TEST_ASSERT(istext(prison.mail_admin_act("prison_mail_wave", list(), null)), "prison_mail_wave called no pod")
	TEST_ASSERT(prison.mail_next_in >= 900 && prison.mail_next_in <= 1500, "prison_mail_wave did not start the mail clock over")
	var/obj/effect/pod_landingzone/admin_zone = find_landing_zone(prison)
	TEST_ASSERT_NOTNULL(admin_zone, "prison_mail_wave called no pod")
	var/turf/admin_turf = get_turf(admin_zone)
	TEST_ASSERT(admin_turf != pod_turf, "The admin's mail pod came down on the first crate")
	TEST_ASSERT(wait_until(CALLBACK(src, PROC_REF(crate_on), admin_turf), 12 SECONDS), "The admin's mail pod never dropped its crate")
	TEST_ASSERT(length(prison.mail_waiting_letters()) > waiting_before, "The admin's mail pod brought no letters")
	TEST_ASSERT(wait_until(CALLBACK(src, PROC_REF(pod_gone), admin_turf), 8 SECONDS), "The admin's mail pod never left")
	check_office_open(prison)
	// With the office full, it comes down on the ground just outside the entrance, off the wing
	var/turf/front = prison.mail_entrance_front()
	TEST_ASSERT_NOTNULL(front, "The wing has no ground outside its entrance")
	for(var/turf/ground in range(2, front))
		if(!prison.upgrade.contains_turf(ground) && (isspaceturf(ground) || isgroundlessturf(ground)))
			ground.ChangeTurf(/turf/open/floor/plating)
	for(var/turf/tile as anything in prison.wing_turfs())
		if(!prison.in_cell_block(tile) && prison.mail_pod_can_land(tile))
			allocate(/obj/structure/closet/crate, tile)
	var/turf/outside = prison.mail_pod_landing_turf()
	TEST_ASSERT_NOTNULL(outside, "With the office full the mail pod has nowhere to land")
	TEST_ASSERT(!prison.upgrade.contains_turf(outside) && outside.loc != prison.wing, "With the office full the mail pod lands in the wing")
	TEST_ASSERT(get_dist(outside, front) <= 2, "With the office full the mail pod lands [get_dist(outside, front)] tiles from the entrance")
	check_landing(prison, outside)
	prison.crew_home_override = null
	settle_prison_air(home)

/// Fails the test unless `tile` is somewhere a mail pod may land
/**
 * Fails the test unless the office's free floor is in one piece and reaches both serving hatches'
 * office sides, with whatever mail crates have landed on it
 */
/datum/unit_test/voidcrew_outpost_prison_mail_arrivals/proc/check_office_open(datum/outpost_prison/prison)
	var/list/floor = list()
	for(var/turf/tile as anything in prison.wing_turfs())
		if(isopenturf(tile) && !prison.in_cell_block(tile) && !tile.is_blocked_turf(exclude_mobs = TRUE))
			floor[tile] = TRUE
	var/turf/start = floor[1]
	var/list/reached = list()
	reached[start] = TRUE
	var/list/queue = list(start)
	var/index = 1
	while(index <= length(queue))
		var/turf/current = queue[index++]
		for(var/direction in GLOB.cardinals)
			var/turf/next = get_step(current, direction)
			if(next && floor[next] && !reached[next])
				reached[next] = TRUE
				queue += next
	TEST_ASSERT_EQUAL(length(reached), length(floor), "A mail crate split the office floor")
	for(var/turf/tile as anything in prison.wing_turfs())
		var/obj/structure/table/reinforced/prison_hatch/hatch = locate() in tile
		if(hatch)
			TEST_ASSERT(reached[hatch.staff_side_turf()], "A mail crate cut off a serving hatch from the office")

/datum/unit_test/voidcrew_outpost_prison_mail_arrivals/proc/check_landing(datum/outpost_prison/prison, turf/tile, ignore_zone = FALSE)
	TEST_ASSERT(isopenturf(tile) && !isspaceturf(tile), "The mail pod lands on [tile]")
	TEST_ASSERT(!prison.in_cell_block(tile), "The mail pod lands in the cell block")
	TEST_ASSERT_NULL(locate(/mob/living) in tile, "The mail pod lands on someone")
	for(var/obj/thing in tile)
		if(ignore_zone && istype(thing, /obj/effect/pod_landingzone))
			continue
		TEST_ASSERT(!thing.density, "The mail pod lands on [thing]")
	for(var/direction in GLOB.cardinals)
		TEST_ASSERT_NULL(locate(/obj/machinery/door) in get_step(tile, direction), "The mail pod lands beside a door")

/// The mail pod on its way to the wing, found by its landing marker in or just outside the wing
/datum/unit_test/voidcrew_outpost_prison_mail_arrivals/proc/find_landing_zone(datum/outpost_prison/prison)
	var/list/bounds = prison.upgrade.footprint_bounds
	for(var/turf/tile as anything in block(bounds[1] - 3, bounds[2] - 3, bounds[5], bounds[3] + 3, bounds[4] + 3, bounds[5]))
		var/obj/effect/pod_landingzone/zone = locate() in tile
		if(zone)
			return zone
	return null

/// Whether a mail crate has come to rest on `tile`
/datum/unit_test/voidcrew_outpost_prison_mail_arrivals/proc/crate_on(turf/tile)
	return !!(locate(/obj/structure/closet/crate/mail) in tile)

/// Whether the mail pod has gone from `tile`
/datum/unit_test/voidcrew_outpost_prison_mail_arrivals/proc/pod_gone(turf/tile)
	return !(locate(/obj/structure/closet/supplypod) in tile)

// ===== MAIL: DELIVERY, OPENED LETTERS, CONTRABAND IN THE POST =====

/datum/unit_test/voidcrew_outpost_prison_mail_delivery
	parent_type = /datum/unit_test/voidcrew_outpost_management

/datum/unit_test/voidcrew_outpost_prison_mail_delivery/Run()
	var/obj/structure/overmap/dynamic/player_outpost/home = prison_test_claim("xfpostowner")
	TEST_ASSERT_NOTNULL(home, "The delivery test prison did not load")
	var/datum/outpost_prison/prison = test_prison(home)
	var/mob/living/basic/outpost_prisoner/reader = trouble_prisoner(prison, prison_spot(home, 8, 8))
	var/mob/living/basic/outpost_prisoner/bystander = trouble_prisoner(prison, prison_spot(home, 10, 8))
	var/mob/living/carbon/human/member = make_player(prison_spot(home, 9, 8), "xfpostowner")
	member.set_combat_mode(FALSE)
	prison.contraband_force_rolls = TRUE

	// A good letter: examined, asked after, refused by the wrong prisoner, read by the right one. A
	// single letter lands on an office table, never a serving hatch or the cell block.
	var/obj/item/paper/outpost_prison_letter/letter = prison.mail_send(reader, "good")
	TEST_ASSERT_NOTNULL(letter, "No letter could be sent")
	var/turf/letter_turf = get_turf(letter)
	var/obj/structure/table/letter_table = locate() in letter_turf
	TEST_ASSERT(letter_table && !istype(letter_table, /obj/structure/table/reinforced/prison_hatch), "A single letter did not land on an office table")
	TEST_ASSERT(!prison.in_cell_block(letter_turf) && letter_turf.loc == prison.wing, "A single letter landed off the office")
	var/obj/item/mail/envelope/outpost_prison/envelope = letter.loc
	TEST_ASSERT(istype(envelope), "The letter came without its envelope")
	TEST_ASSERT(islist(envelope.examine_more(member)), "Examining the envelope closely failed")
	TEST_ASSERT(!findtext(jointext(envelope.examine(member), " "), "small and hard"), "A good letter felt as if something hard was inside")
	var/list/ask = prison.mail_extra_speech(reader)
	TEST_ASSERT(islist(ask) && ask[1] == "mail_waiting", "The addressee did not ask after their letter with a member in sight")
	TEST_ASSERT_NULL(prison.mail_extra_speech(bystander), "A prisoner with no letter asked after one")
	var/datum/weakref/envelope_ref = WEAKREF(envelope)
	member.put_in_active_hand(envelope)
	click_wrapper(member, bystander)
	TEST_ASSERT_EQUAL(envelope.loc, member, "The wrong prisoner took someone else's letter")
	TEST_ASSERT(contraband_line_for(bystander.last_line, "mail_not_mine"), "The wrong prisoner said: [bystander.last_line]")
	click_wrapper(member, reader)
	TEST_ASSERT(wait_until(CALLBACK(GLOBAL_PROC, GLOBAL_PROC_REF(is_qdeleted_ref), envelope_ref), 8 SECONDS), "The prisoner never read the letter handed to them")
	TEST_ASSERT(abs(reader.mood - 78) < 0.01, "A good letter by hand gave [reader.mood - 70] mood, not 8") // OUTPOST_MAIL_MOOD_GOOD
	TEST_ASSERT(contraband_line_for(reader.last_line, "mail_good"), "The reader said: [reader.last_line]")
	TEST_ASSERT(!reader.talking, "Reading left the prisoner held")
	TEST_ASSERT_EQUAL(length(prison.mail_waiting_letters()), 0, "A read letter still counts as waiting")

	// Opened first: the kind's mood, 6 less (OUTPOST_MAIL_OPENED_MOOD), and "Who opened this?"
	letter = prison.mail_send(bystander, "news")
	envelope = letter.loc
	member.put_in_active_hand(envelope)
	// What follows tg's 1.5 second unwrap
	envelope.after_unwrap(member)
	TEST_ASSERT(letter.letter_opened, "Opening the envelope did not mark the letter opened")
	TEST_ASSERT(QDELETED(envelope), "The opened envelope is still about")
	TEST_ASSERT(member.is_holding(letter), "The opened letter did not end up in the opener's hands")
	TEST_ASSERT(findtext(contraband_last_log(prison), "opened"), "Opening someone's mail was not logged: [contraband_last_log(prison)]")
	TEST_ASSERT_EQUAL(prison.mail_read(bystander, letter, TRUE), "news", "The opened letter was not read")
	TEST_ASSERT(abs(bystander.mood - 68) < 0.01, "An opened news letter left mood at [bystander.mood], not 68") // OUTPOST_MAIL_MOOD_NEWS 4
	TEST_ASSERT(contraband_line_for(bystander.last_line, "mail_opened"), "The reader of an opened letter said: [bystander.last_line]")
	TEST_ASSERT(QDELETED(letter), "The read letter is still about")

	// On a serving hatch with nobody on the level: read where they stand, the hatch in their reach
	var/obj/structure/table/reinforced/prison_hatch/hatch = locate() in prison_spot(home, 5, 6)
	TEST_ASSERT_NOTNULL(hatch, "No serving hatch at (5,6)")
	reader.forceMove(hatch.yard_side_turf())
	prison.refresh_prisoner_reach(reader)
	letter = prison.mail_send(reader, "kid")
	envelope = letter.loc
	envelope.forceMove(hatch.loc)
	var/mood_before = reader.mood
	prison.mail_check_clock = 0
	prison.mail_tick(5) // OUTPOST_MAIL_CHECK
	TEST_ASSERT(QDELETED(envelope), "A letter on a hatch in reach was not read")
	TEST_ASSERT(abs(reader.mood - mood_before - 10) < 0.01, "A kid's drawing gave [reader.mood - mood_before] mood, not 10") // OUTPOST_MAIL_MOOD_KID
	TEST_ASSERT(contraband_line_for(reader.last_line, "mail_kid"), "The reader of a kid's drawing said: [reader.last_line]")

	// Contraband left sealed: kept hidden, then stashed; a razor blade becomes a shiv
	letter = prison.mail_send(reader, "contraband", /obj/item/outpost_prison_contraband/razor_blade)
	envelope = letter.loc
	TEST_ASSERT(findtext(jointext(envelope.examine(member), " "), "small and hard"), "A contraband letter rolled to feel hard gave no tell") // OUTPOST_MAIL_HARD_TELL
	mood_before = reader.mood
	TEST_ASSERT_EQUAL(prison.mail_read(reader, envelope, TRUE), "contraband", "The contraband letter was not read")
	TEST_ASSERT(abs(reader.mood - mood_before - 4) < 0.01, "A contraband letter did not read as news")
	TEST_ASSERT(istype(reader.carried_contraband, /obj/item/outpost_prison_contraband/razor_blade), "The razor blade was not kept hidden")
	TEST_ASSERT(!reader.cell.stash_shiv, "The razor blade was stashed before the prisoner could get to it")
	// With nobody on the level it is stashed on the contraband clock
	prison.contraband_tick(30) // OUTPOST_CONTRABAND_CLOCK
	TEST_ASSERT(reader.cell.stash_shiv, "A razor blade from the mail did not become a shiv stash")
	TEST_ASSERT_NULL(reader.carried_contraband, "The prisoner still carries the stashed razor blade")
	// Yeast becomes pruno in the cistern
	letter = prison.mail_send(bystander, "contraband", /obj/item/outpost_prison_contraband/yeast)
	TEST_ASSERT_EQUAL(prison.mail_read(bystander, letter.loc, TRUE), "contraband", "The yeast letter was not read")
	TEST_ASSERT(istype(bystander.carried_contraband, /obj/item/outpost_prison_contraband/yeast), "The yeast was not kept hidden")
	prison.contraband_tick(30)
	TEST_ASSERT_NOTNULL(prison.contraband_pruno(bystander.cell), "Yeast from the mail did not become pruno")
	TEST_ASSERT_NULL(bystander.carried_contraband, "The prisoner still carries the stashed yeast")

	// Opened first, whatever was inside goes to the opener and nothing is stashed
	member.drop_all_held_items()
	bystander.cell.stash_shiv = FALSE
	letter = prison.mail_send(bystander, "contraband", /obj/item/outpost_prison_contraband/razor_blade)
	envelope = letter.loc
	member.put_in_active_hand(envelope)
	envelope.after_unwrap(member)
	TEST_ASSERT(member.is_holding_item_of_type(/obj/item/outpost_prison_contraband/razor_blade), "The razor blade did not end up with the opener")
	prison.mail_read(bystander, letter, TRUE)
	TEST_ASSERT_NULL(bystander.carried_contraband, "The prisoner got a razor blade the opener kept")
	prison.contraband_tick(30)
	TEST_ASSERT(!bystander.cell.stash_shiv, "An opened letter's razor blade still reached the cell")
	prison.contraband_force_rolls = null
	settle_prison_air(home)

// ===== MAIL: EXPIRY, CLEAN-UP, ADMIN =====

/datum/unit_test/voidcrew_outpost_prison_mail_cleanup
	parent_type = /datum/unit_test/voidcrew_outpost_management

/datum/unit_test/voidcrew_outpost_prison_mail_cleanup/Run()
	var/obj/structure/overmap/dynamic/player_outpost/home = prison_test_claim("xfreturnowner")
	TEST_ASSERT_NOTNULL(home, "The mail clean-up test prison did not load")
	var/datum/outpost_prison/prison = test_prison(home)
	var/mob/living/basic/outpost_prisoner/waiting = trouble_prisoner(prison, prison_spot(home, 8, 8))
	var/mob/living/basic/outpost_prisoner/leaving = trouble_prisoner(prison, prison_spot(home, 10, 8))
	prison.crew_home_override = TRUE
	prison.mail_next_in = 100000

	// Fifteen minutes waiting with the crew home (OUTPOST_MAIL_EXPIRY): sent back, and 3 mood lost (OUTPOST_MAIL_EXPIRED_MOOD)
	var/obj/item/paper/outpost_prison_letter/letter = prison.mail_send(waiting, "good")
	TEST_ASSERT_NOTNULL(letter, "No letter could be sent")
	letter.letter_waited = 898
	prison.mail_tick(1)
	TEST_ASSERT(!QDELETED(letter), "A letter was sent back before fifteen minutes")
	prison.mail_tick(1)
	TEST_ASSERT(QDELETED(letter), "A letter waiting fifteen minutes was not sent back")
	TEST_ASSERT(abs(waiting.mood - 67) < 0.01, "A letter sent back cost [70 - waiting.mood] mood, not 3")

	// Taken off the wing's level: thrown away
	letter = prison.mail_send(waiting, "news")
	var/obj/item/mail/envelope/outpost_prison/envelope = letter.loc
	envelope.forceMove(run_loc_floor_bottom_left)
	prison.mail_check_clock = 0
	prison.mail_tick(5) // OUTPOST_MAIL_CHECK
	TEST_ASSERT(QDELETED(envelope) && QDELETED(letter), "A letter taken off the wing's level was not thrown away")

	// Its prisoner leaving: the letter goes, wherever it is
	letter = prison.mail_send(leaving, "bad")
	prison.forget(leaving)
	TEST_ASSERT(QDELETED(letter), "A letter outlived its prisoner leaving")
	qdel(leaving)

	// prison_mail sends the kind asked for, and refuses nonsense
	TEST_ASSERT(islist(prison.mail_admin_act("prison_mail", list("ref" = REF(waiting), "kind" = "parcel"), null)), "prison_mail took an unknown kind")
	TEST_ASSERT(islist(prison.mail_admin_act("prison_mail", list("ref" = "nobody", "kind" = "good"), null)), "prison_mail took a prisoner who is not there")
	TEST_ASSERT_NULL(prison.mail_admin_act("prison_other", list(), null), "The mail package took another action")
	// prison_mail_wave refuses with nobody due a letter (the only prisoner left has had theirs)
	TEST_ASSERT(islist(prison.mail_admin_act("prison_mail_wave", list(), null)), "prison_mail_wave called a pod with nobody due a letter")
	TEST_ASSERT(istext(prison.mail_admin_act("prison_mail", list("ref" = REF(waiting), "kind" = "kid"), null)), "prison_mail sent nothing")
	var/list/block = prison.mail_admin_payload()
	var/list/rows = block["letters"]
	TEST_ASSERT_EQUAL(length(rows), 1, "The admin panel lists [length(rows)] letters, not 1")
	var/list/row = rows[1]
	TEST_ASSERT_EQUAL(row["kind"], "kid", "prison_mail sent the wrong kind of letter")
	TEST_ASSERT_EQUAL(row["to_ref"], REF(waiting), "prison_mail sent the letter to the wrong prisoner")
	for(var/key in list("ref", "to_name", "opened", "contraband", "age"))
		TEST_ASSERT((key in row), "The admin panel's letter has no [key]")
	TEST_ASSERT(("next_in" in block), "The admin panel's mail block has no next_in")

	// The prison going deletes its letters
	var/list/still_waiting = prison.mail_waiting_letters()
	letter = still_waiting[1]
	prison.mail_destroy()
	TEST_ASSERT(QDELETED(letter), "A letter outlived the prison's clean-up")
	TEST_ASSERT_EQUAL(length(prison.mail_letters), 0, "The prison still tracks letters after its clean-up")
	prison.crew_home_override = null
	settle_prison_air(home)
