/// The outpost bans view lists every trader restriction (embargoes and warrants), and lifting or adding one changes what the outpost enforces.
/datum/unit_test/voidcrew_overmap_management_bans

/datum/unit_test/voidcrew_overmap_management_bans/Run()
	var/mob/living/basic/operator = allocate(/mob/living/basic)
	var/datum/overmap_management/panel = allocate(/datum/overmap_management, operator)
	var/obj/structure/overmap/trader_outpost/outpost = allocate(/obj/structure/overmap/trader_outpost)
	var/datum/outpost_police/police = outpost.police
	TEST_ASSERT_NOTNULL(police, "A trader outpost has no police")
	var/obj/structure/overmap/ship/ship = allocate(/obj/structure/overmap/ship)
	SSovermap.simulated_ships |= ship
	var/datum/mind/wanted_mind = ban_test_mind("outpostbanwanted")
	var/datum/mind/barred_mind = ban_test_mind("outpostbanbarred")
	var/datum/mind/prisoner_mind = ban_test_mind("outpostbanprisoner")
	var/datum/mind/fresh_mind = ban_test_mind("outpostbanfresh")

	outpost.embargo_ship(ship)
	// 60 heat is three stars (OUTPOST_POLICE_STAR_HEAT: 10, 25, 50, 90, 140)
	police_pin_warrant(police, wanted_mind, 60)
	var/datum/outpost_warrant/barred_warrant = police_pin_warrant(police, barred_mind, 0)
	barred_warrant.barred_until = world.time + 5 MINUTES
	barred_warrant.prior = 30
	police_pin_warrant(police, prisoner_mind, 30)
	var/datum/outpost_police_cell/cell = new
	police.cells += cell
	cell.prisoners[prisoner_mind] = world.time + 4 MINUTES
	cell.jailed[prisoner_mind] = TRUE

	var/list/rows = ban_rows_for(panel, outpost)
	TEST_ASSERT(rows["embargo:[REF(ship)]"], "An embargoed ship was not listed")
	TEST_ASSERT(rows["wanted:[REF(wanted_mind)]"], "A wanted person was not listed")
	TEST_ASSERT(rows["wanted:[REF(barred_mind)]"], "A barred person was not listed")
	TEST_ASSERT(rows["wanted:[REF(prisoner_mind)]"], "A prisoner was not listed")
	var/list/wanted_row = rows["wanted:[REF(wanted_mind)]"]
	TEST_ASSERT_EQUAL(wanted_row["label"], "3 stars", "A three-star warrant had the wrong label")
	TEST_ASSERT_NULL(wanted_row["seconds"], "A warrant with no bar and no cell had a time left")
	var/list/barred_row = rows["wanted:[REF(barred_mind)]"]
	TEST_ASSERT_EQUAL(barred_row["label"], "barred", "A bar with no stars had the wrong label")
	var/barred_seconds = barred_row["seconds"]
	TEST_ASSERT(barred_seconds > 0 && barred_seconds <= 300, "A bar did not show the five minutes it has left")
	var/list/prisoner_row = rows["wanted:[REF(prisoner_mind)]"]
	var/prisoner_seconds = prisoner_row["seconds"]
	TEST_ASSERT(prisoner_seconds > 0 && prisoner_seconds <= 240, "A prisoner did not show the term left in the cell")
	TEST_ASSERT(locate(wanted_mind) in panel.ban_candidate_minds(), "A player with a mind could not be chosen")

	panel.ban_act("ban_lift", list("outpost" = REF(outpost), "kind" = "embargo", "target" = REF(ship)), operator)
	TEST_ASSERT(!outpost.is_ship_embargoed(ship), "Lifting did not end the embargo")
	panel.ban_act("ban_lift", list("outpost" = REF(outpost), "kind" = "wanted", "target" = REF(wanted_mind)), operator)
	TEST_ASSERT_EQUAL(police.get_stars(wanted_mind), 0, "Lifting a warrant left the person wanted")
	panel.ban_act("ban_lift", list("outpost" = REF(outpost), "kind" = "wanted", "target" = REF(barred_mind)), operator)
	TEST_ASSERT(!police.is_barred(barred_mind.current), "Lifting a bar left the person refused service")
	TEST_ASSERT_NULL(police.get_warrant(barred_mind), "Lifting a bar left the bar or the prior on the record")
	// The cell lets out a prisoner whose warrant is gone on its next tick (police_cell.dm tick_cell())
	panel.ban_act("ban_lift", list("outpost" = REF(outpost), "kind" = "wanted", "target" = REF(prisoner_mind)), operator)
	TEST_ASSERT_NULL(police.get_warrant(prisoner_mind), "Lifting a prisoner's warrant left the warrant their cell holds them on")
	TEST_ASSERT_EQUAL(police.get_stars(prisoner_mind), 0, "Lifting a prisoner's warrant left them wanted")
	TEST_ASSERT(!length(ban_rows_for(panel, outpost)), "Lifted restrictions were still listed")

	panel.ban_act("ban_add", list("outpost" = REF(outpost), "kind" = "embargo", "target" = REF(ship), "minutes" = "3"), operator)
	TEST_ASSERT(outpost.is_ship_embargoed(ship), "Adding an embargo did not embargo the ship")
	TEST_ASSERT(outpost.embargoed_ships[ship] <= world.time + 3 MINUTES, "The embargo ignored the chosen length")
	panel.ban_act("ban_add", list("outpost" = REF(outpost), "kind" = "wanted", "target" = REF(fresh_mind), "stars" = "4", "minutes" = "3"), operator)
	TEST_ASSERT_EQUAL(police.get_stars(fresh_mind), 4, "Adding a four-star warrant did not give four stars")
	var/datum/outpost_warrant/fresh_warrant = police.warrants[fresh_mind]
	TEST_ASSERT_NOTNULL(fresh_warrant, "Adding a warrant made no warrant")
	TEST_ASSERT_EQUAL(fresh_warrant.heat, 90, "A four-star warrant did not start at the heat that earns four stars") // OUTPOST_POLICE_STAR_HEAT[4]
	panel.ban_act("ban_add", list("outpost" = REF(outpost), "kind" = "wanted", "target" = REF(wanted_mind)), operator)
	TEST_ASSERT_EQUAL(police.get_stars(wanted_mind), 3, "A warrant added with no stars given did not default to three")
	panel.ban_act("ban_add", list("outpost" = REF(outpost), "kind" = "wanted", "target" = REF(wanted_mind), "stars" = "9"), operator)
	TEST_ASSERT_EQUAL(police.get_stars(wanted_mind), 5, "A warrant of nine stars was not held to five")
	TEST_ASSERT(police.tick_timer, "Adding a warrant did not wake the police")

	panel.error = null
	panel.ban_act("ban_add", list("outpost" = REF(outpost), "kind" = "wanted", "target" = REF(operator), "stars" = "2"), operator)
	TEST_ASSERT(panel.error, "A warrant was accepted for someone with no mind to choose")
	panel.error = null
	panel.ban_act("ban_add", list("outpost" = REF(outpost), "kind" = "ship_ban", "target" = REF(ship), "minutes" = "3"), operator)
	TEST_ASSERT(panel.error, "A docking ban was accepted for a trader outpost")
	panel.error = null
	panel.ban_act("ban_add", list("outpost" = REF(outpost), "kind" = "aggressor", "target" = REF(wanted_mind), "minutes" = "3"), operator)
	TEST_ASSERT(panel.error, "The removed violence mark was accepted")
	SSovermap.simulated_ships -= ship

/// A player-keyed mind on a body in the world, so the panel can offer it
/datum/unit_test/voidcrew_overmap_management_bans/proc/ban_test_mind(ban_key)
	var/mob/living/basic/body = allocate(/mob/living/basic, run_loc_floor_bottom_left)
	body.mind_initialize()
	var/datum/mind/body_mind = body.mind
	body_mind.key = ban_key
	return body_mind

/// "kind:target ref" -> that row, for every listed restriction at `outpost`
/datum/unit_test/voidcrew_overmap_management_bans/proc/ban_rows_for(datum/overmap_management/panel, obj/structure/overmap/trader_outpost/outpost)
	var/list/rows = list()
	var/list/data = panel.ban_data()
	for(var/list/entry as anything in data["entries"])
		if(entry["outpost_ref"] == REF(outpost))
			rows["[entry["kind"]]:[entry["target_ref"]]"] = entry
	return rows
