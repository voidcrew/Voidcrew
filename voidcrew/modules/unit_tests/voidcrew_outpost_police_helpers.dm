/**
 * Outpost police (voidcrew/modules/outpost_police/): helpers every police test uses, and P0's smoke test.
 * Owner: P0 seams, frozen. Package tests live in voidcrew_outpost_police_<package>.dm.
 *
 * Fork defines are included after the tests, so a test uses the literal value with a comment naming the
 * define. Tests pin other packages' outputs (warrant.heat, officer.force, cell.prisoners) directly and
 * call a proc with the mobs already in place; no test waits for an AI walk.
 */

/// A trader outpost of `outpost_type` with its interior loaded (null, and the test failed, if it did not load)
/datum/unit_test/proc/police_loaded_outpost(outpost_type = /obj/structure/overmap/trader_outpost/general)
	var/obj/structure/overmap/trader_outpost/outpost = allocate(outpost_type)
	if(!outpost.load_level())
		TEST_FAIL("[outpost_type]'s interior failed to load")
		return null
	return outpost

/// A free public floor tile on `outpost`'s concourse
/datum/unit_test/proc/police_floor(obj/structure/overmap/trader_outpost/outpost)
	var/datum/ambient_place/outpost/place = SSambient_npcs.outpost_place(outpost)
	return place?.settle_turf()

/// An officer of `officer_type` at `where`, in `outpost`'s ambient place and on its police roster
/datum/unit_test/proc/police_officer(obj/structure/overmap/trader_outpost/outpost, officer_type = /mob/living/carbon/human/npc/ambient_npc/outpost/police/beat, turf/where)
	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/officer = allocate(officer_type, where || police_floor(outpost))
	officer.set_place(SSambient_npcs.outpost_place(outpost))
	outpost.police.add_officer(officer)
	return officer

/// `mind`'s warrant at `police`, made if missing, with its heat pinned to `heat`
/datum/unit_test/proc/police_pin_warrant(datum/outpost_police/police, datum/mind/mind, heat = 0)
	var/datum/outpost_warrant/warrant = police.warrants[mind]
	if(!warrant)
		warrant = new
		warrant.mind = mind
		police.warrants[mind] = warrant
	warrant.heat = heat
	warrant.peak = max(warrant.peak, heat)
	return warrant

/**
 * Whether `officer`'s force subtree plans a shot at `target` now, with `target` as its target. A one-star suspect is
 * a target (spec-stealth 1.3: the officer keeps them in view) that the subtree only watches; this tells the two apart.
 */
/datum/unit_test/proc/police_plans_shot(mob/living/carbon/human/npc/ambient_npc/outpost/police/officer, atom/target)
	var/datum/ai_controller/brain = officer.ai_controller
	var/datum/ai_planning_subtree/outpost_police_force/force_tree = locate() in brain?.planning_subtrees
	if(!force_tree)
		TEST_FAIL("[officer.type]'s brain has no force subtree")
		return FALSE
	brain.set_blackboard_key(BB_BASIC_MOB_CURRENT_TARGET, target)
	brain.planned_behaviors.Cut()
	force_tree.SelectBehaviors(brain, 1)
	. = !!(locate(/datum/ai_behavior/human_npc_shoot) in brain.planned_behaviors)
	brain.clear_blackboard_key(BB_BASIC_MOB_CURRENT_TARGET)
	brain.planned_behaviors.Cut()

/// For a failure message: why `npc` may or may not stand on each tile beside `thing` ("dx,dy why")
/datum/unit_test/proc/police_spot_report(mob/living/carbon/human/npc/ambient_npc/outpost/npc, atom/thing)
	var/turf/center = get_turf(thing)
	var/list/out = list()
	for(var/turf/tile as anything in RANGE_TURFS(1, center))
		if(tile == center)
			continue
		var/why = "ok"
		if(!isopenturf(tile))
			why = "closed"
		else if(tile != npc.loc && ambient_outpost_tile_blocked(tile, npc))
			why = "blocked"
		else if(!npc.leash_ok(tile))
			why = "leash"
		else if(npc.place && !npc.place.spot_allowed(tile, npc))
			why = "not public floor"
		else if(ambient_outpost_tile_avoided(tile, npc.place, npc.counter_business))
			why = "avoided"
		else if(!tile.Adjacent(thing))
			why = "not adjacent"
		out += "[tile.x - center.x],[tile.y - center.y] [why]"
	return "place [npc.place ? "yes" : "none"]: [out.Join("; ")]"

/// A loaded trader outpost has police; a beat officer built there joins the roster, plans once without a runtime and holds still with nobody about
/datum/unit_test/voidcrew_outpost_police_smoke

/datum/unit_test/voidcrew_outpost_police_smoke/Run()
	var/obj/structure/overmap/trader_outpost/outpost = police_loaded_outpost()
	if(!outpost)
		return
	var/datum/outpost_police/police = outpost.police
	TEST_ASSERT_NOTNULL(police, "A loaded trader outpost has no police")
	TEST_ASSERT_EQUAL(police.outpost, outpost, "The police do not know their outpost")
	TEST_ASSERT_NOTNULL(police.perception, "The police have no witness test")
	TEST_ASSERT_NOTNULL(police.profile, "The police have no profile")
	var/turf/where = police_floor(outpost)
	TEST_ASSERT_NOTNULL(where, "No free floor on the concourse for an officer")

	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/officer = police_officer(outpost, /mob/living/carbon/human/npc/ambient_npc/outpost/police/beat, where)
	TEST_ASSERT(officer.flags_1 & INITIALIZED_1, "A beat officer did not initialise")
	TEST_ASSERT(officer in police.officers, "A beat officer is not on the roster")
	TEST_ASSERT_EQUAL(officer.police, police, "A beat officer does not know their police")
	TEST_ASSERT(istype(officer.ai_controller, /datum/ai_controller/basic_controller/human_npc/stealth/outpost_police), "A beat officer has [officer.ai_controller?.type], not the police brain")
	officer.ai_controller.SelectBehaviors(1)
	TEST_ASSERT(HAS_TRAIT(officer, TRAIT_AI_PAUSED), "A beat officer at an outpost with nobody on it is not holding still")

	qdel(officer)
	TEST_ASSERT(!(officer in police.officers), "A deleted officer is still on the roster")
