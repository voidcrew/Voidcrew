/**
 * Outpost police tests: officers in doorways and behind townsfolk (pass 14 soak, the Undertow and Halcyon).
 * voidcrew/modules/outpost_police/police_arrest.dm cover_off_doorway(), police_movement.dm police_bump_other_leg(),
 * stealth_police/police_stealth.dm police_walk_leg().
 *
 * Fork defines are included after the tests, so values are written out: BB_OUTPOST_POLICE_CASE_GOAL is
 * "outpost_police_case_goal", CASE_COVER_DISTANCE is 2, AMBIENT_PAUSED_TRAIT is "ambient_paused", heat 12 is one star.
 * Map tiles are counted from the loaded outpost's bottom-left corner, as the soak's trace writes them.
 */

/// A tile of `outpost` (dx, dy) from its bottom-left corner
/datum/unit_test/proc/police_outpost_tile(obj/structure/overmap/trader_outpost/outpost, dx, dy)
	var/turf/corner = outpost.template_bottom_left
	return locate(corner.x + dx, corner.y + dy, corner.z)

/**
 * The cover of an arrest in the Undertow's bar, come in by Bar Access, stood in the doorway from then on: its walk ends
 * as soon as it is two tiles from the arresting officer, and that is the doorway. It steps on in off it, to a tile as
 * near that has the suspect in sight.
 */
/datum/unit_test/voidcrew_outpost_police_cover_doorway

/datum/unit_test/voidcrew_outpost_police_cover_doorway/Run()
	var/obj/structure/overmap/trader_outpost/outpost = police_loaded_outpost(/obj/structure/overmap/trader_outpost/black_market)
	if(!outpost)
		return
	var/datum/outpost_police/police = outpost.police
	var/turf/doorway = police_outpost_tile(outpost, 27, 17)
	TEST_ASSERT_NOTNULL(locate(/obj/machinery/door/airlock) in doorway, "Fixture: no airlock at the Undertow's Bar Access (27,17)")
	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/officer = police_officer(outpost, where = police_outpost_tile(outpost, 29, 18))
	police_arrest_kit(officer)
	var/mob/living/carbon/human/suspect = police_arrest_person(police_outpost_tile(outpost, 29, 16))
	var/datum/outpost_police_case/case = police.open_case(police_pin_warrant(police, suspect.mind, 12))
	police.sleep_tick()
	TEST_ASSERT_NOTNULL(case, "Fixture: no arrest opened on the suspect")
	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/cover = police_officer(outpost, where = doorway)
	police_arrest_kit(cover)
	case.staff()
	if(case.arresting() != officer && (officer in case.officers) && (cover in case.officers))
		case.officers.Swap(case.officers.Find(officer), case.officers.Find(cover))
	TEST_ASSERT_EQUAL(case.arresting(), officer, "Fixture: the officer beside the suspect is not the arresting officer")
	TEST_ASSERT_EQUAL(case.cover(), cover, "Fixture: the officer in the doorway is not the cover")
	case.set_step("order")

	var/datum/ai_controller/brain = cover.ai_controller
	brain.planned_behaviors.Cut()
	brain.clear_blackboard_key("outpost_police_case_goal")
	case.plan_for(brain, cover)
	var/turf/goal = get_turf(brain.blackboard["outpost_police_case_goal"])
	var/list/planned = list()
	for(var/datum/ai_behavior/behavior as anything in brain.planned_behaviors)
		planned += "[behavior.type]"
	TEST_ASSERT_NOTNULL(goal, "The cover two tiles from the arresting officer stays in the doorway (planned: [planned.Join(", ")])")
	TEST_ASSERT(!(locate(/obj/machinery/door) in goal), "The cover steps to another doorway at [goal.x - doorway.x],[goal.y - doorway.y] from Bar Access")
	TEST_ASSERT(get_dist(goal, officer) <= 2, "The cover steps [get_dist(goal, officer)] tiles from the officer it covers") // CASE_COVER_DISTANCE
	TEST_ASSERT(get_dist(goal, doorway) == 1, "The cover goes [get_dist(goal, doorway)] tiles off the doorway, not one step")
	TEST_ASSERT(can_see(goal, suspect, 7), "The cover steps off the doorway to a tile out of sight of the suspect")

	// Off the doorway, as near: it stands
	cover.forceMove(goal)
	brain.planned_behaviors.Cut()
	brain.clear_blackboard_key("outpost_police_case_goal")
	case.plan_for(brain, cover)
	TEST_ASSERT_NULL(brain.blackboard["outpost_police_case_goal"], "The cover off the doorway, near enough, walks on")
	brain.planned_behaviors.Cut()
	police.close_case(suspect.mind)

/**
 * An officer whose way on is a diagonal step past a seated patron on one leg and a townsperson on the other, someone
 * standing on the diagonal tile itself. Only the patron, who cannot get up for it, was ever taken up straight, and the
 * officer stood there for good (pass 14 soak, Undertow hangar_wait, by the tables at 24,7). It gets past the one who
 * can make way.
 */
/datum/unit_test/voidcrew_stealth_live/police/crowd/diagonal_seated

/datum/unit_test/voidcrew_stealth_live/police/crowd/diagonal_seated/Run()
	TEST_ASSERT(police_room(8, 6), "No room for the test")
	open_place()
	allocate(/obj/effect/landmark/stealth_group, at(7, 5))
	police_stop(4, 3, "a", 1, 1 SECONDS, null)
	police_stop(0, 0, "a", 2, 30 SECONDS, null)
	// Someone on the list of players keeps the level awake
	suspect = person_at(7, 5, TRUE)
	var/obj/structure/chair/seat = allocate(/obj/structure/chair, at(4, 2))
	var/mob/living/carbon/human/npc/ambient_npc/outpost/seated = local_at(4, 2)
	seat.buckle_mob(seated, TRUE)
	TEST_ASSERT_EQUAL(seated.buckled, seat, "Fixture: the patron is not seated")
	var/list/townsfolk = list(seated, local_at(3, 3), local_at(3, 2))
	for(var/mob/living/local as anything in townsfolk)
		ADD_TRAIT(local, TRAIT_AI_PAUSED, "ambient_paused")
	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/officer = squad_officer(4, 3, WEST)
	var/turf/start = get_turf(officer)
	watch(25, CALLBACK(src, PROC_REF(walked_to), officer, at(0, 0)))
	TEST_ASSERT(get_dist(officer, at(0, 0)) <= 1, "The officer never got past the townsfolk on its diagonal to its stop (it is at [officer.x - at(0, 0).x],[officer.y - at(0, 0).y], [get_turf(officer) == start ? "where it started" : "off its start"])")
	for(var/mob/living/local as anything in townsfolk)
		REMOVE_TRAIT(local, TRAIT_AI_PAUSED, "ambient_paused")

/// Whether `officer` is within a tile of `spot`
/datum/unit_test/voidcrew_stealth_live/police/crowd/proc/walked_to(mob/living/officer, turf/spot)
	return get_dist(officer, spot) <= 1

/**
 * A long walk across Halcyon, from the east half to the park in the west, goes in legs. Stealth's leg is a point on the
 * straight line, which there lies in the open space between the two halves: the pathfinder found no way to it, the
 * next was no better, and the officer stood at its post for the rest of the search (pass 14 soak, Halcyon hostage).
 * An officer's leg is a tile of the outpost's own floor, on the way there.
 */
/datum/unit_test/voidcrew_outpost_police_walk_leg

/datum/unit_test/voidcrew_outpost_police_walk_leg/Run()
	var/obj/structure/overmap/trader_outpost/outpost = police_loaded_outpost(/obj/structure/overmap/trader_outpost/general)
	if(!outpost)
		return
	var/datum/outpost_police/police = outpost.police
	var/turf/start = police_outpost_tile(outpost, 54, 32)
	var/turf/park = police_outpost_tile(outpost, 11, 24)
	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/officer = police_officer(outpost, where = start)
	var/datum/ai_controller/basic_controller/human_npc/stealth/outpost_police/brain = officer.ai_controller
	var/datum/outpost_police_floor/floor = police.search_floor(start, officer)
	TEST_ASSERT_NOTNULL(floor, "Fixture: Halcyon's floor was not read")
	TEST_ASSERT(floor.walkable[start], "Fixture: the officer's post at 54,32 is not on Halcyon's floor")
	TEST_ASSERT(floor.walkable[park], "Fixture: the park at 11,24 is not on Halcyon's floor")
	var/turf/at = start
	var/list/legs = list()
	for(var/leg_count in 1 to 6)
		if(get_dist(at, park) <= 40) // STEALTH_WALK_LEG
			break
		officer.forceMove(at)
		var/turf/leg = brain.stealth_next_leg(park)
		TEST_ASSERT_NOTNULL(leg, "No leg on the way from [at.x - start.x + 54],[at.y - start.y + 32]")
		var/where = "[leg.x - start.x + 54],[leg.y - start.y + 32]"
		legs += where
		TEST_ASSERT(floor.walkable[leg], "A leg of the walk to the park is at [where], off Halcyon's floor ([leg.type]); legs [legs.Join(" ")]")
		TEST_ASSERT(leg != at, "A leg of the walk to the park goes nowhere from [where]")
		at = leg
	TEST_ASSERT(get_dist(at, park) <= 40, "Six legs did not bring the walk within a leg of the park; legs [legs.Join(" ")]") // STEALTH_WALK_LEG
