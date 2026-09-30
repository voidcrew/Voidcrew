/**
 * The prison extras' seams (outpost_prison_extras.dm). Owner: X0; frozen once the packages start.
 * Every package's lines land in its own dialogue file, so the first test holds all of them to the
 * main file's rules and to each other; the second checks the blocks and hooks every package fills
 * are there and keep their shape.
 *
 * Voidcrew defines are not visible from test files, so tuning values appear as literals with the
 * define named beside them. Prisons are driven with tick(seconds) with their own processing stopped.
 */

// ===== EXTRA DIALOGUE FILES =====

/datum/unit_test/voidcrew_outpost_prison_extras_dialogue

/datum/unit_test/voidcrew_outpost_prison_extras_dialogue/Run()
	var/list/personalities = outpost_prisoner_dialogue("personalities")
	var/list/main_lines = outpost_prisoner_dialogue("lines")
	TEST_ASSERT(length(personalities), "The main dialogue file has no personalities")
	var/list/placeholders = list("{name}", "{other}", "{crime}", "{time_left}") + GLOB.outpost_prisoner_extra_placeholders
	var/list/seen = list()
	for(var/file in GLOB.outpost_prisoner_extra_dialogue)
		var/list/lines = outpost_prisoner_extra_dialogue(file, "lines")
		TEST_ASSERT(islist(lines), "[file] has no lines block")
		for(var/context in lines)
			// A context in two files would be shadowed: the first file wins and the second is never said.
			TEST_ASSERT(!(context in main_lines), "[file] has [context], which outpost_prisoners.json already has")
			TEST_ASSERT(!seen[context], "[file] has [context], which [seen[context]] already has")
			seen[context] = file
			var/list/entry = lines[context]
			TEST_ASSERT(islist(entry), "[file]: [context] is not a set of line pools")
			TEST_ASSERT(length(entry["any"]), "[file]: [context] has no shared (any) lines")
			var/own_pools = 0
			for(var/pool in entry)
				TEST_ASSERT(pool == "any" || (pool in personalities), "[file]: [context] has lines for [pool], which is not a personality")
				if(pool != "any")
					own_pools++
				for(var/line in entry[pool])
					check_line(line, "[file]: [context]/[pool]", placeholders)
			TEST_ASSERT(own_pools >= 2, "[file]: [context] has lines for [own_pools] personalities, not 2 or more")

/// Plain ASCII, at most 20 words, and no placeholder the prisoners cannot fill
/datum/unit_test/voidcrew_outpost_prison_extras_dialogue/proc/check_line(line, where, list/placeholders)
	TEST_ASSERT(istext(line) && length(line), "[where] has an empty or non-text line")
	TEST_ASSERT_EQUAL(length(line), length_char(line), "[where] has a line that is not plain ASCII: [line]")
	TEST_ASSERT(length(splittext(line, " ")) <= 20, "[where] has a line over 20 words: [line]")
	var/bare = line
	for(var/placeholder in placeholders)
		bare = replacetext(bare, placeholder, "")
	TEST_ASSERT(!findtext(bare, "{") && !findtext(bare, "}"), "[where] has a line with an unknown placeholder: [line]")

// ===== SEAMS =====

/datum/unit_test/voidcrew_outpost_prison_extras_seams
	parent_type = /datum/unit_test/voidcrew_outpost_management

/datum/unit_test/voidcrew_outpost_prison_extras_seams/Run()
	var/obj/structure/overmap/dynamic/player_outpost/home = prison_test_claim("extrasowner")
	TEST_ASSERT_NOTNULL(home, "The extras test prison did not load")
	var/datum/outpost_prison/prison = test_prison(home)
	var/mob/living/basic/outpost_prisoner/prisoner = test_prisoner(prison, prison_spot(home, 8, 8))

	// The warden console's extras block, whatever the packages put in it (build plan section 8)
	var/list/extras = prison.ui_payload(null)["extras"]
	TEST_ASSERT(islist(extras), "The warden console sends no extras block")
	var/list/guards = extras["guards"]
	TEST_ASSERT(islist(guards), "The extras block has no guards")
	for(var/key in list("max", "hire_cost", "wage", "can_manage", "can_hire", "list"))
		TEST_ASSERT(key in guards, "The guards block has no [key]")
	TEST_ASSERT(!("unpaid" in guards), "The guards block still counts missed wages")
	// The console's stun turret is gone (built turrets follow the prison's rules), and its security block with it.
	TEST_ASSERT(!("security" in extras), "The extras block still sends the removed security block")
	// Letters lie on the office floor and the log calls the mail; the console counts none.
	TEST_ASSERT(!("mail" in extras), "The extras block still sends a mail count")

	// The admin panel's extras block, and an action no package knows
	var/list/admin_extras = prison.admin_payload()["extras"]
	TEST_ASSERT(islist(admin_extras), "The admin panel gets no extras block")
	for(var/key in list("guards", "social", "life", "contraband", "mail", "leads"))
		TEST_ASSERT(islist(admin_extras[key]), "The admin extras block has no [key] list")
	TEST_ASSERT_NULL(prison.extras_admin_act("prison_no_such_thing", list(), null), "An unknown admin action was taken by a package")
	TEST_ASSERT(!prison.extras_act("no_such_thing", list(), null), "An unknown console action was taken by a package")

	// The fan-outs return their shapes
	TEST_ASSERT(islist(prison.examine_extra_lines(prisoner, null)), "examine_extra_lines() did not return a list")
	TEST_ASSERT(islist(prison.talk_menu_extra_choices(prisoner, null)), "talk_menu_extra_choices() did not return a list")
	var/mult = prison.extras_fight_mult(prisoner, prisoner)
	TEST_ASSERT(isnum(mult) && mult > 0, "extras_fight_mult() returned [mult]")
	TEST_ASSERT_NULL(prison.staff_greeting_name(null), "Nobody got a greeting name")

	// Extra placeholders: filled when given, and a line naming one is never said without it
	prisoner.extra_line_values = list("{staff}" = "Isaac")
	TEST_ASSERT_EQUAL(prisoner.fill_line("Evening, {staff}.", null), "Evening, Isaac.", "{staff} did not fill")
	TEST_ASSERT_EQUAL(length(prisoner.usable_lines(list("Evening, {staff}.", "Evening."), null)), 2, "A line with a {staff} value was left out")
	prisoner.extra_line_values = null
	var/list/usable = prisoner.usable_lines(list("Evening, {staff}.", "Evening."), null)
	TEST_ASSERT(length(usable) == 1 && usable[1] == "Evening.", "A {staff} line was usable with no name for it")
	prisoner.say_context_with("no_such_context", list("{place}" = "the Meridian"))
	TEST_ASSERT_NULL(prisoner.extra_line_values, "say_context_with() left its values behind")

	// Every package's tick runs in one go without trouble
	prison.extras_tick(5)
	TEST_ASSERT(prisoner in prison.prisoners, "The extras' tick lost a prisoner")
	settle_prison_air(home)
