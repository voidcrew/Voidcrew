/**
 * Interrogation and leads (outpost_prison_leads.dm). Owner: XG.
 *
 * Voidcrew defines are not visible from test files, so tuning values appear as literals with the
 * define named beside them. Prisons are driven with tick(seconds) with their own processing stopped;
 * fixtures are in voidcrew_outpost_prison_helpers.dm. give_lead() and lead_vouch() are called
 * directly with a ship allocated on the overmap, so no test needs the talk menu, a do_after or a
 * crew registration; the talk menu's own refusals come before its do_after.
 */

/datum/unit_test/voidcrew_outpost_prison_leads_files

/datum/unit_test/voidcrew_outpost_prison_leads_files/Run()
	// The file is read the way outpost_prisoner_extra_dialogue() reads it (the strings directory is a define)
	load_strings_file("outpost_prison_leads.json", "voidcrew/modules/player_outposts/strings")
	var/list/contents = GLOB.string_cache["outpost_prison_leads.json"]
	TEST_ASSERT(islist(contents), "outpost_prison_leads.json did not load")
	TEST_ASSERT(islist(contents["lines"]), "outpost_prison_leads.json has no lines block")
	TEST_ASSERT(islist(contents["tells"]), "outpost_prison_leads.json has no tells block")
	TEST_ASSERT(islist(contents["fake_names"]), "outpost_prison_leads.json has no fake_names block")

	// Every context the code says, and every tip names the place and the band
	var/list/lines = contents["lines"]
	for(var/context in list("lead_hint", "lead_none", "lead_no_ship", "lead_refuse", "lead_refuse_hit", "lead_nothing", "lead_tell", "lead_gossip_true", "lead_gossip_lie", "lead_vouch_true", "lead_vouch_lie", "lead_vouch_unsure", "lead_lie_caught"))
		TEST_ASSERT(islist(lines[context]), "outpost_prison_leads.json has no [context] lines")
	var/list/tell_lines = lines["lead_tell"]
	for(var/pool in tell_lines)
		for(var/line in tell_lines[pool])
			TEST_ASSERT(findtext(line, "{place}") && findtext(line, "{band}"), "A lead_tell line does not name {place} and {band}: [line]")

	// Tells are emotes: shared ones and two personalities' or more, short, plain, nothing to fill in
	var/list/personalities = outpost_prisoner_dialogue("personalities")
	var/list/tells = contents["tells"]
	TEST_ASSERT(length(tells["any"]), "There are no shared tells")
	var/own_pools = 0
	for(var/pool in tells)
		TEST_ASSERT(pool == "any" || (pool in personalities), "There are tells for [pool], which is not a personality")
		if(pool != "any")
			own_pools++
		for(var/tell in tells[pool])
			TEST_ASSERT(istext(tell) && length(tell), "An empty tell for [pool]")
			TEST_ASSERT_EQUAL(length(tell), length_char(tell), "A tell is not plain ASCII: [tell]")
			TEST_ASSERT(length(splittext(tell, " ")) <= 10, "A tell is over 10 words: [tell]")
			TEST_ASSERT(!findtext(tell, "{"), "A tell has a placeholder, which emotes never fill: [tell]")
	TEST_ASSERT(own_pools >= 2, "Tells cover [own_pools] personalities, not 2 or more")

	var/list/fake_names = contents["fake_names"]
	TEST_ASSERT(length(fake_names), "There are no fallback ruin names")
	for(var/fake in fake_names)
		TEST_ASSERT(istext(fake) && length(fake) && length(fake) == length_char(fake), "A fallback ruin name is empty or not plain ASCII: [fake]")

// ===== FIXTURES =====

/// A plain ruin's subtype, as the contested cache, lich lair and vestige are: never a lead
/obj/structure/overmap/space_ruin/outpost_lead_test

/// A bare ship record on the overmap at relative coordinates
/datum/unit_test/voidcrew_outpost_management/proc/leads_test_ship(rel_x, rel_y)
	var/obj/structure/overmap/ship/ship = allocate(/obj/structure/overmap/ship)
	ship.forceMove(outpost_lead_overmap_turf(rel_x, rel_y))
	return ship

/// An unsurveyed ruin signal on the overmap at relative coordinates, with a name to tell
/datum/unit_test/voidcrew_outpost_management/proc/leads_test_ruin(rel_x, rel_y, ruin_name, ruin_type = /obj/structure/overmap/space_ruin)
	var/obj/structure/overmap/space_ruin/ruin = allocate(ruin_type, outpost_lead_overmap_turf(rel_x, rel_y))
	ruin.true_name = ruin_name
	return ruin

/// Four plain ruins well away from a ship at (10, 10), so a truth always has something to name
/datum/unit_test/voidcrew_outpost_management/proc/leads_test_field()
	return list(
		leads_test_ruin(30, 30, "Lead Test Hulk"),
		leads_test_ruin(36, 30, "Lead Test Tug"),
		leads_test_ruin(30, 36, "Lead Test Relay"),
		leads_test_ruin(36, 36, "Lead Test Barge"),
	)

/// Whether `prisoner` last said one of `context`'s lines, filled with `values`
/datum/unit_test/voidcrew_outpost_management/proc/leads_said(mob/living/basic/outpost_prisoner/prisoner, context, list/values)
	var/list/entry = outpost_prisoner_context_lines(context)
	if(!islist(entry) || !prisoner.last_line)
		return FALSE
	for(var/pool in entry)
		for(var/line in entry[pool])
			var/filled = prisoner.fill_line(line, null)
			for(var/placeholder in values)
				filled = replacetext(filled, placeholder, "[values[placeholder]]")
			if(filled == prisoner.last_line)
				return TRUE
	return FALSE

/// The prison's newest open lead
/datum/unit_test/voidcrew_outpost_management/proc/leads_newest(datum/outpost_prison/prison)
	return length(prison.open_leads) ? prison.open_leads[length(prison.open_leads)] : null

// ===== CARRIERS =====

/// About 30% of arrivals carry a lead (OUTPOST_PRISON_LEAD_CHANCE)
/datum/unit_test/voidcrew_outpost_prison_leads_carriers
	parent_type = /datum/unit_test/voidcrew_outpost_management

/datum/unit_test/voidcrew_outpost_prison_leads_carriers/Run()
	var/obj/structure/overmap/dynamic/player_outpost/home = prison_test_claim("leadsowner")
	TEST_ASSERT_NOTNULL(home, "The leads test prison did not load")
	var/datum/outpost_prison/prison = test_prison(home)
	var/mob/living/basic/outpost_prisoner/prisoner = test_prisoner(prison, prison_spot(home, 8, 8))
	var/carriers = 0
	for(var/i in 1 to 200)
		prisoner.carries_lead = FALSE
		prison.leads_prisoner_admitted(prisoner)
		if(prisoner.carries_lead)
			carriers++
	TEST_ASSERT(carriers >= 40 && carriers <= 80, "[carriers] of 200 arrivals carried a lead, not 20-40%")
	// Leaving drops it, and the admin action gives one back with the wing ready
	prison.lead_ready_at = world.time + 10 MINUTES
	prison.leads_prisoner_leaving(prisoner)
	TEST_ASSERT(!prisoner.carries_lead, "A prisoner leaving the wing kept their lead")
	TEST_ASSERT(istext(prison.leads_admin_act("prison_lead", list("ref" = REF(prisoner)), null)), "The admin could not give a lead")
	TEST_ASSERT(prisoner.carries_lead && prison.lead_ready(), "The admin's lead did not ready the wing")
	var/list/refused = prison.leads_admin_act("prison_lead", list("ref" = "not a ref"), null)
	TEST_ASSERT(islist(refused) && refused["error"], "The admin gave a lead to nobody")
	TEST_ASSERT_NULL(prison.leads_admin_act("prison_mail", list(), null), "The leads took another package's admin action")
	var/list/payload = prison.leads_admin_payload()
	TEST_ASSERT(REF(prisoner) in payload["carriers"], "The admin block does not list the carrier")
	TEST_ASSERT(("ready_in" in payload) && islist(payload["open"]), "The admin block is missing its keys")
	settle_prison_air(home)

// ===== THE TRUTH =====

/**
 * Content prisoners never lie: at mood 70 or more (OUTPOST_PRISON_LEAD_TRUE_MOOD) every tip is a
 * Rumors waypoint tracked to a real plain ruin, the tip names the place and band out loud, and the
 * wing's gap (OUTPOST_PRISON_LEAD_GAP) then blocks the next one through an intake toggle.
 */
/datum/unit_test/voidcrew_outpost_prison_leads_truth
	parent_type = /datum/unit_test/voidcrew_outpost_management

/datum/unit_test/voidcrew_outpost_prison_leads_truth/Run()
	var/obj/structure/overmap/dynamic/player_outpost/home = prison_test_claim("leadsowner")
	TEST_ASSERT_NOTNULL(home, "The leads test prison did not load")
	TEST_ASSERT(istype(outpost_lead_overmap_turf(30, 30), /turf/open/overmap), "The test world has no overmap to point at")
	var/datum/outpost_prison/prison = test_prison(home)
	var/mob/living/basic/outpost_prisoner/teller = test_prisoner(prison, prison_spot(home, 8, 8))
	var/mob/living/basic/outpost_prisoner/second = test_prisoner(prison, prison_spot(home, 11, 8))
	var/mob/living/carbon/human/asker = make_player(prison_spot(home, 9, 8), "leadsowner")
	var/obj/structure/overmap/ship/ship = leads_test_ship(10, 10)
	leads_test_field()

	for(var/personality in outpost_prisoner_dialogue("personalities"))
		teller.personality = personality
		for(var/mood in list(70, 80, 100)) // OUTPOST_PRISON_LEAD_TRUE_MOOD and above
			teller.set_mood(mood)
			TEST_ASSERT_EQUAL(prison.lead_lie_chance(teller, asker), 0, "A [personality] prisoner at mood [mood] might lie")

	teller.set_mood(80)
	for(var/i in 1 to 3)
		teller.carries_lead = TRUE
		prison.lead_ready_at = 0
		TEST_ASSERT_EQUAL(prison.give_lead(teller, ship, asker), "truth", "A content carrier did not tell the truth")
		var/datum/outpost_prison_lead/lead = leads_newest(prison)
		TEST_ASSERT(lead && !lead.lie, "The truth was not tracked as one")
		var/datum/ship_waypoint/waypoint = ship.get_waypoint(lead.waypoint_key)
		TEST_ASSERT_NOTNULL(waypoint, "The truth left no mark on the helm")
		TEST_ASSERT_EQUAL(waypoint.category, "Rumors", "The tip is not in the helm's Rumors")
		var/obj/structure/overmap/space_ruin/ruin = waypoint.tracked_target?.resolve()
		TEST_ASSERT(istype(ruin), "The truth is not tracked to a ruin")
		TEST_ASSERT(ruin.type == /obj/structure/overmap/space_ruin && !ruin.rare && !ruin.mission_locked, "The truth named a ruin that is not a plain one")
		var/list/coords = ruin.get_relative_overmap_coords()
		TEST_ASSERT(waypoint.target_x == coords[1] && waypoint.target_y == coords[2], "The truth's mark is not on its ruin")
		// lead_tell filled {place} and {band}
		TEST_ASSERT(findtext(teller.last_line, lead.place) && findtext(teller.last_line, lead.band_name), "The tip did not name its place and band: [teller.last_line]")
		TEST_ASSERT(!findtext(teller.last_line, "{"), "The tip left a placeholder unfilled: [teller.last_line]")
		TEST_ASSERT(!teller.carries_lead, "The teller still carries the lead they gave")
		TEST_ASSERT(!prison.lead_ready(), "Giving a lead did not start the wing's gap")
		TEST_ASSERT(findtext(prison.entries[1]["text"], "gave"), "The tip was not logged")
	TEST_ASSERT(length(prison.open_leads) == 3, "The wing is not tracking its three tips")

	// The gap blocks another carrier with the same line as a prisoner who knows nothing, and an intake toggle keeps it
	second.set_mood(80)
	second.carries_lead = TRUE
	var/ready_at = prison.lead_ready_at
	TEST_ASSERT_EQUAL(prison.give_lead(second, ship, asker), "none", "A second tip came inside the wing's gap")
	TEST_ASSERT(leads_said(second, "lead_none"), "A carrier held back by the gap did not say lead_none")
	TEST_ASSERT(second.carries_lead, "The gap cost a carrier their lead")
	prison.set_intake(TRUE)
	prison.set_intake(FALSE)
	prison.leads_prisoner_admitted(second)
	TEST_ASSERT_EQUAL(prison.lead_ready_at, ready_at, "Intake or an admission moved the wing's lead gap")
	second.carries_lead = TRUE
	TEST_ASSERT_EQUAL(prison.give_lead(second, ship, asker), "none", "An intake toggle opened the wing's gap")
	settle_prison_air(home)

// ===== LIES =====

/**
 * An unhappy prisoner forced to lie marks an untracked spot with nothing on it and no ruin, planet
 * or outpost in sight of it, under a name no ruin on the overmap has; flying within sight of it
 * (SHIP_VIEW_RANGE, 4) renames the mark and logs the lie.
 */
/datum/unit_test/voidcrew_outpost_prison_leads_lie
	parent_type = /datum/unit_test/voidcrew_outpost_management

/datum/unit_test/voidcrew_outpost_prison_leads_lie/Run()
	var/obj/structure/overmap/dynamic/player_outpost/home = prison_test_claim("leadsowner")
	TEST_ASSERT_NOTNULL(home, "The leads test prison did not load")
	TEST_ASSERT(istype(outpost_lead_overmap_turf(30, 30), /turf/open/overmap), "The test world has no overmap to point at")
	var/datum/outpost_prison/prison = test_prison(home)
	var/mob/living/basic/outpost_prisoner/teller = test_prisoner(prison, prison_spot(home, 8, 8))
	var/mob/living/carbon/human/asker = make_player(prison_spot(home, 9, 8), "leadsowner")
	var/obj/structure/overmap/ship/ship = leads_test_ship(10, 10)
	leads_test_field()

	// The chances by mood band and personality, for a stranger (XC's label stub)
	teller.personality = "chatty"
	teller.set_mood(30)
	TEST_ASSERT_EQUAL(prison.lead_lie_chance(teller, asker), 50, "Mood 30 is not a coin toss (OUTPOST_PRISON_LEAD_LIE_HOSTILE)")
	teller.set_mood(50)
	TEST_ASSERT_EQUAL(prison.lead_lie_chance(teller, asker), 15, "Mood 50 is not OUTPOST_PRISON_LEAD_LIE_UNEASY")
	teller.personality = "grumpy"
	teller.set_mood(30)
	TEST_ASSERT(abs(prison.lead_lie_chance(teller, asker) - 65) < 0.01, "A grumpy prisoner's chance is not x1.3")
	teller.personality = "nervous"
	TEST_ASSERT(abs(prison.lead_lie_chance(teller, asker) - 35) < 0.01, "A nervous prisoner's chance is not x0.7")

	// A lie needs a clear tile in some candidate's band; a crowded test overmap may have none
	var/list/spots_by_band = prison.lead_lie_spots(outpost_lead_ship_position(ship))
	var/can_lie = FALSE
	for(var/obj/structure/overmap/space_ruin/ruin as anything in prison.lead_candidates(ship))
		if(length(spots_by_band["[outpost_lead_band(get_turf(ruin))]"]))
			can_lie = TRUE
			break
	teller.carries_lead = TRUE
	prison.lead_test_roll = FALSE
	if(!can_lie)
		// With nowhere fair to point, a would-be liar tells the truth
		TEST_ASSERT_EQUAL(prison.give_lead(teller, ship, asker, TRUE), "truth", "A lie with no clear tile was told anyway")
		TEST_NOTICE(src, "The test overmap has no tile clear enough for a lie; the lie checks were skipped")
		settle_prison_air(home)
		return

	TEST_ASSERT_EQUAL(prison.give_lead(teller, ship, asker, TRUE), "lie", "A forced lie was not told")
	var/datum/outpost_prison_lead/lead = leads_newest(prison)
	TEST_ASSERT(lead?.lie, "The lie was not tracked as one")
	var/datum/ship_waypoint/waypoint = ship.get_waypoint(lead.waypoint_key)
	TEST_ASSERT_NOTNULL(waypoint, "The lie left no mark on the helm")
	TEST_ASSERT_EQUAL(waypoint.category, "Rumors", "The lie is not in the helm's Rumors")
	TEST_ASSERT_NULL(waypoint.tracked_target, "The lie's mark is tracked to something")
	var/turf/spot = outpost_lead_overmap_turf(lead.target_x, lead.target_y)
	TEST_ASSERT(istype(spot, /turf/open/overmap), "The lie points off the overmap")
	var/obj/structure/overmap/occupant = locate(/obj/structure/overmap) in spot
	TEST_ASSERT_NULL(occupant, "The lie points at a tile with something on it")
	for(var/obj/structure/overmap/nearby in overmap_sensor_range(4, spot)) // SHIP_VIEW_RANGE
		TEST_ASSERT(!nearby.sensor_detectable, "The lie points within sight of [nearby]")
	for(var/obj/structure/overmap/space_ruin/ruin in GLOB.space_ruin_signals)
		TEST_ASSERT(ruin.true_name != lead.place, "The lie named [lead.place], a ruin on the overmap")
	TEST_ASSERT(findtext(teller.last_line, lead.place), "The lie was not told like a tip: [teller.last_line]")

	// Flying within sight of it
	prison.leads_tick(10) // OUTPOST_PRISON_LEAD_CHECK_INTERVAL, the ship still far off
	TEST_ASSERT(!lead.exposed, "The lie was exposed from across the overmap")
	ship.forceMove(spot)
	prison.leads_tick(10)
	TEST_ASSERT(lead.exposed, "Flying to the lie did not expose it")
	TEST_ASSERT(findtext(waypoint.name, "nothing there"), "The lie's mark was not renamed: [waypoint.name]")
	TEST_ASSERT(findtext(prison.entries[1]["text"], "was a lie"), "The exposed lie was not logged")
	settle_prison_air(home)

// ===== REFUSALS =====

/**
 * Under mood 25 (OUTPOST_PRISON_LEAD_REFUSE_MOOD) they refuse and keep the lead; a prisoner the
 * asker hit unprovoked refuses; visitors get no questions; a member with no ship gets lead_no_ship.
 */
/datum/unit_test/voidcrew_outpost_prison_leads_refusals
	parent_type = /datum/unit_test/voidcrew_outpost_management

/datum/unit_test/voidcrew_outpost_prison_leads_refusals/Run()
	var/obj/structure/overmap/dynamic/player_outpost/home = prison_test_claim("leadsowner")
	TEST_ASSERT_NOTNULL(home, "The leads test prison did not load")
	var/datum/outpost_prison/prison = test_prison(home)
	var/mob/living/basic/outpost_prisoner/sour = test_prisoner(prison, prison_spot(home, 8, 8))
	var/mob/living/basic/outpost_prisoner/struck = test_prisoner(prison, prison_spot(home, 11, 8))
	var/mob/living/basic/outpost_prisoner/asked = test_prisoner(prison, prison_spot(home, 13, 8))
	var/mob/living/carbon/human/member = make_player(prison_spot(home, 9, 8), "leadsowner")
	var/mob/living/carbon/human/visitor = make_player(prison_spot(home, 12, 8), "leadsvisitor")
	var/obj/structure/overmap/ship/ship = leads_test_ship(10, 10)
	leads_test_field()

	sour.set_mood(20)
	sour.carries_lead = TRUE
	TEST_ASSERT_EQUAL(prison.give_lead(sour, ship, member), "refuse", "A prisoner at mood 20 did not refuse")
	TEST_ASSERT(leads_said(sour, "lead_refuse"), "The refusal was not lead_refuse")
	TEST_ASSERT(sour.carries_lead, "Refusing cost the prisoner their lead")
	TEST_ASSERT(prison.lead_ready() && !length(prison.open_leads) && !length(ship.waypoints), "A refusal gave something away")

	struck.set_mood(80)
	struck.carries_lead = TRUE
	TEST_ASSERT(struck.hit_by_staff(member), "The unprovoked hit did not count")
	struck.set_mood(80)
	TEST_ASSERT_EQUAL(prison.give_lead(struck, ship, member), "refuse_hit", "A prisoner the asker hit did not refuse")
	TEST_ASSERT(struck.carries_lead, "A prisoner who refused after a hit lost their lead")
	TEST_ASSERT(!length(prison.open_leads), "A lead was given after a hit")

	asked.set_mood(80)
	asked.carries_lead = TRUE
	TEST_ASSERT(!length(prison.leads_talk_choices(asked, visitor)), "A visitor was offered a question")
	TEST_ASSERT(prison.leads_talk_act(asked, visitor, "Heard anything?"), "The question was not recognised") // LEAD_ASK_CHOICE
	TEST_ASSERT(asked.carries_lead && !length(prison.open_leads), "A visitor got the wing's lead")
	TEST_ASSERT(length(prison.leads_talk_choices(asked, member)), "A member was not offered the question")
	TEST_ASSERT(("Heard anything?" in prison.leads_talk_choices(asked, member)), "The member's menu does not ask if they've heard anything") // LEAD_ASK_CHOICE
	TEST_ASSERT(!("About that tip" in prison.leads_talk_choices(asked, member)), "A prisoner who saw no tip could be asked about one") // LEAD_TIP_CHOICE, offered below
	TEST_ASSERT(prison.leads_talk_act(asked, member, "Heard anything?"), "The member's question was not recognised")
	TEST_ASSERT(leads_said(asked, "lead_no_ship"), "A member with no ship did not hear lead_no_ship")
	TEST_ASSERT(asked.carries_lead && !length(prison.open_leads), "A member with no ship got the wing's lead")
	TEST_ASSERT(!prison.leads_talk_act(asked, member, "Something else"), "The leads took another package's choice")
	settle_prison_air(home)

// ===== WHAT A LEAD CAN POINT AT =====

/**
 * Only plain, unclaimed ruins the ship does not know: never rare, mission-held or subtyped ones,
 * nothing on its helm, seen, flown past or in sight; and a lie's name is never on the overmap.
 */
/datum/unit_test/voidcrew_outpost_prison_leads_candidates
	parent_type = /datum/unit_test/voidcrew_outpost_management

/datum/unit_test/voidcrew_outpost_prison_leads_candidates/Run()
	var/obj/structure/overmap/dynamic/player_outpost/home = prison_test_claim("leadsowner")
	TEST_ASSERT_NOTNULL(home, "The leads test prison did not load")
	TEST_ASSERT(istype(outpost_lead_overmap_turf(30, 30), /turf/open/overmap), "The test world has no overmap to point at")
	var/datum/outpost_prison/prison = test_prison(home)
	var/obj/structure/overmap/ship/ship = leads_test_ship(10, 10)

	var/obj/structure/overmap/space_ruin/plain = leads_test_ruin(30, 30, "Lead Test Plain")
	var/obj/structure/overmap/space_ruin/rare = leads_test_ruin(33, 30, "Lead Test Rare")
	rare.rare = TRUE
	var/obj/structure/overmap/space_ruin/locked = leads_test_ruin(36, 30, "Lead Test Locked")
	locked.mission_locked = TRUE
	var/obj/structure/overmap/space_ruin/exclusive = leads_test_ruin(39, 30, "Lead Test Exclusive")
	exclusive.mission_exclusive = TRUE
	var/obj/structure/overmap/space_ruin/subtyped = leads_test_ruin(42, 30, "Lead Test Subtype", /obj/structure/overmap/space_ruin/outpost_lead_test)
	var/obj/structure/overmap/space_ruin/tipped = leads_test_ruin(30, 36, "Lead Test Tipped")
	ship.add_waypoint("rumor_[REF(tipped)]", "A bought tip", 30, 36, "Rumors")
	var/obj/structure/overmap/space_ruin/scanned = leads_test_ruin(33, 36, "Lead Test Scanned")
	ship.add_waypoint(REF(scanned), "Scanned", 33, 36, "Ruins", scanned)
	var/obj/structure/overmap/space_ruin/seen = leads_test_ruin(36, 36, "Lead Test Seen")
	ship.discovered_contacts[REF(seen)] = WEAKREF(seen)
	var/obj/structure/overmap/space_ruin/flown_past = leads_test_ruin(45, 44, "Lead Test Surveyed")
	ship.mark_surveyed(list(45, 44))
	var/obj/structure/overmap/space_ruin/in_sight = leads_test_ruin(12, 10, "Lead Test Close")

	var/list/candidates = prison.lead_candidates(ship)
	TEST_ASSERT(plain in candidates, "A plain uncharted ruin was not a candidate")
	TEST_ASSERT(!(rare in candidates), "A rare ruin could be a lead")
	TEST_ASSERT(!(locked in candidates), "A mission's ruin could be a lead")
	TEST_ASSERT(!(exclusive in candidates), "A contract's exclusive ruin could be a lead")
	TEST_ASSERT(!(subtyped in candidates), "A ruin subtype could be a lead")
	TEST_ASSERT(!(tipped in candidates), "A ruin the ship bought a tip on could be a lead")
	TEST_ASSERT(!(scanned in candidates), "A ruin on the ship's helm could be a lead")
	TEST_ASSERT(!(seen in candidates), "A ruin the ship has seen could be a lead")
	TEST_ASSERT(!(flown_past in candidates), "A ruin on a tile the ship flew past could be a lead")
	TEST_ASSERT(!(in_sight in candidates), "A ruin in the ship's sight could be a lead")
	for(var/obj/structure/overmap/space_ruin/ruin as anything in candidates)
		TEST_ASSERT(ruin.type == /obj/structure/overmap/space_ruin && !ruin.rare && !ruin.mission_locked, "[ruin] ([ruin.type]) was a candidate")

	// A name on the overmap is never a lie's, even one that ruins turn up under naturally
	for(var/template_name in SSmapping.space_ruins_templates)
		var/datum/map_template/ruin/space/template = SSmapping.space_ruins_templates[template_name]
		if(istype(template) && !template.unpickable)
			leads_test_ruin(20, 40, template.name)
			break
	var/list/on_map = list()
	for(var/obj/structure/overmap/space_ruin/ruin in GLOB.space_ruin_signals)
		if(ruin.true_name)
			on_map[ruin.true_name] = TRUE
	for(var/i in 1 to 30)
		var/fake = prison.lead_fake_name()
		TEST_ASSERT(istext(fake) && length(fake), "A lie had no name")
		TEST_ASSERT(!on_map[fake], "A lie was named [fake], which is on the overmap")
	settle_prison_air(home)

// ===== THE YARD'S WORD =====

/**
 * Another prisoner who saw a tip can be asked about it once: at mood 50 and up
 * (OUTPOST_PRISON_LEAD_GOSSIP_MOOD) they tell the truth about it, between 25 and 50 they aren't
 * sure, under 25 they refuse and can be asked again.
 */
/datum/unit_test/voidcrew_outpost_prison_leads_vouch
	parent_type = /datum/unit_test/voidcrew_outpost_management

/datum/unit_test/voidcrew_outpost_prison_leads_vouch/Run()
	var/obj/structure/overmap/dynamic/player_outpost/home = prison_test_claim("leadsowner")
	TEST_ASSERT_NOTNULL(home, "The leads test prison did not load")
	var/datum/outpost_prison/prison = test_prison(home)
	var/mob/living/basic/outpost_prisoner/teller = test_prisoner(prison, prison_spot(home, 8, 8))
	var/mob/living/basic/outpost_prisoner/voucher = test_prisoner(prison, prison_spot(home, 11, 8))
	var/mob/living/basic/outpost_prisoner/unsure = test_prisoner(prison, prison_spot(home, 12, 8))
	var/mob/living/basic/outpost_prisoner/newcomer = test_prisoner(prison, prison_spot(home, 13, 8))
	var/mob/living/carbon/human/member = make_player(prison_spot(home, 9, 8), "leadsowner")

	var/datum/outpost_prison_lead/lie = new
	lie.lie = TRUE
	lie.teller_ref = WEAKREF(teller)
	lie.teller_name = teller.real_name
	lie.teller_first_name = teller.speech_name()
	lie.given_at = world.time
	lie.witnesses += WEAKREF(voucher)
	lie.witnesses += WEAKREF(unsure)
	prison.open_leads += lie
	var/choice = "About that tip" // LEAD_TIP_CHOICE
	var/list/values = list("{teller}" = teller.speech_name())

	TEST_ASSERT(choice in prison.leads_talk_choices(voucher, member), "A witness could not be asked about the tip")
	TEST_ASSERT_EQUAL(prison.lead_newest_vouchable(voucher), lie, "Tip on the witness's menu is not about the tip they saw")
	TEST_ASSERT(!(choice in prison.leads_talk_choices(teller, member)), "The teller could be asked about their own tip")
	TEST_ASSERT(!(choice in prison.leads_talk_choices(newcomer, member)), "A prisoner who did not see the tip could be asked about it")

	voucher.set_mood(20)
	TEST_ASSERT_EQUAL(prison.lead_vouch(voucher, lie, member), "refuse", "A sour witness did not refuse")
	TEST_ASSERT(choice in prison.leads_talk_choices(voucher, member), "A refusal used up the question")
	voucher.set_mood(60)
	TEST_ASSERT_EQUAL(prison.lead_vouch(voucher, lie, member), "lie", "A content witness did not say the lie was one")
	TEST_ASSERT(leads_said(voucher, "lead_vouch_lie", values), "The witness did not say a lead_vouch_lie line")
	TEST_ASSERT(!(choice in prison.leads_talk_choices(voucher, member)), "A witness could be asked twice")

	unsure.set_mood(30)
	TEST_ASSERT_EQUAL(prison.lead_vouch(unsure, lie, member), "unsure", "A middling witness was sure")
	TEST_ASSERT(leads_said(unsure, "lead_vouch_unsure", values), "The middling witness did not say a lead_vouch_unsure line")

	var/datum/outpost_prison_lead/truth = new
	truth.teller_ref = WEAKREF(teller)
	truth.teller_name = teller.real_name
	truth.teller_first_name = teller.speech_name()
	truth.given_at = world.time
	truth.witnesses += WEAKREF(newcomer)
	prison.open_leads += truth
	newcomer.set_mood(90)
	TEST_ASSERT_EQUAL(prison.lead_vouch(newcomer, truth, member), "true", "A content witness did not back the truth")
	TEST_ASSERT(leads_said(newcomer, "lead_vouch_true", values), "The witness did not say a lead_vouch_true line")

	// Past OUTPOST_PRISON_LEAD_VOUCH_TIME (20 minutes) nobody is asked
	lie.given_at = world.time - 21 MINUTES
	lie.vouched.Cut()
	TEST_ASSERT(!(choice in prison.leads_talk_choices(voucher, member)), "A witness could be asked about an old tip")
	settle_prison_air(home)
