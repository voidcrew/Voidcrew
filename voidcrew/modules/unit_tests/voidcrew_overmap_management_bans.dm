/// The outpost bans view lists every trader restriction, and lifting or adding one changes what the outpost enforces.
/datum/unit_test/voidcrew_overmap_management_bans

/datum/unit_test/voidcrew_overmap_management_bans/Run()
	var/mob/living/basic/operator = allocate(/mob/living/basic)
	var/datum/overmap_management/panel = allocate(/datum/overmap_management, operator)
	var/obj/structure/overmap/trader_outpost/outpost = allocate(/obj/structure/overmap/trader_outpost)
	var/obj/structure/overmap/ship/ship = allocate(/obj/structure/overmap/ship)
	SSovermap.simulated_ships |= ship
	var/mob/living/basic/visitor = allocate(/mob/living/basic, run_loc_floor_bottom_left)
	visitor.mind_initialize()
	var/datum/mind/visitor_mind = visitor.mind
	visitor_mind.key = "outpostbantest"

	outpost.embargo_ship(ship)
	outpost.aggressor_minds[visitor_mind] = world.time + 5 MINUTES
	outpost.trespass_bars[visitor_mind] = world.time + 5 MINUTES
	var/list/kinds = ban_kinds_for(panel, outpost)
	TEST_ASSERT(kinds["embargo:[REF(ship)]"], "An embargoed ship was not listed")
	TEST_ASSERT(kinds["aggressor:[REF(visitor_mind)]"], "A marked aggressor was not listed")
	TEST_ASSERT(kinds["trespass:[REF(visitor_mind)]"], "A refused-service bar was not listed")
	TEST_ASSERT(locate(visitor_mind) in panel.ban_candidate_minds(), "A player with a mind could not be chosen")

	panel.ban_act("ban_lift", list("outpost" = REF(outpost), "kind" = "embargo", "target" = REF(ship)), operator)
	TEST_ASSERT(!outpost.is_ship_embargoed(ship), "Lifting did not end the embargo")
	panel.ban_act("ban_lift", list("outpost" = REF(outpost), "kind" = "aggressor", "target" = REF(visitor_mind)), operator)
	TEST_ASSERT(!outpost.is_marked_aggressor(visitor_mind), "Lifting did not clear the violence mark")
	TEST_ASSERT(outpost.is_user_barred(visitor), "Lifting the mark also lifted a separate refused-service bar")
	panel.ban_act("ban_lift", list("outpost" = REF(outpost), "kind" = "trespass", "target" = REF(visitor_mind)), operator)
	TEST_ASSERT(!outpost.is_user_barred(visitor), "Lifting every ban left the visitor refused")
	TEST_ASSERT(!length(ban_kinds_for(panel, outpost)), "Lifted bans were still listed")

	panel.ban_act("ban_add", list("outpost" = REF(outpost), "kind" = "embargo", "target" = REF(ship), "minutes" = "3"), operator)
	TEST_ASSERT(outpost.is_ship_embargoed(ship), "Adding an embargo did not embargo the ship")
	TEST_ASSERT(outpost.embargoed_ships[ship] <= world.time + 3 MINUTES, "The embargo ignored the chosen length")
	panel.ban_act("ban_add", list("outpost" = REF(outpost), "kind" = "aggressor", "target" = REF(visitor_mind), "minutes" = "3"), operator)
	TEST_ASSERT(outpost.is_marked_aggressor(visitor_mind) && outpost.is_turret_target(visitor), "Adding a mark did not turn the turrets on them")
	panel.ban_act("ban_add", list("outpost" = REF(outpost), "kind" = "trespass", "target" = REF(visitor_mind), "minutes" = "3"), operator)
	TEST_ASSERT(outpost.is_trespass_barred(visitor_mind), "Adding a refused-service bar did nothing")
	TEST_ASSERT(!outpost.is_armed_trespasser(visitor_mind), "A refused-service bar also made the turrets hostile")
	panel.ban_act("ban_add", list("outpost" = REF(outpost), "kind" = "ship_ban", "target" = REF(ship), "minutes" = "3"), operator)
	TEST_ASSERT(panel.error, "A docking ban was accepted for a trader outpost")
	SSovermap.simulated_ships -= ship

/// "kind:target ref" -> TRUE for every listed ban at `outpost`
/datum/unit_test/voidcrew_overmap_management_bans/proc/ban_kinds_for(datum/overmap_management/panel, obj/structure/overmap/trader_outpost/outpost)
	var/list/kinds = list()
	var/list/data = panel.ban_data()
	for(var/list/entry as anything in data["entries"])
		if(entry["outpost_ref"] == REF(outpost))
			kinds["[entry["kind"]]:[entry["target_ref"]]"] = TRUE
	return kinds
