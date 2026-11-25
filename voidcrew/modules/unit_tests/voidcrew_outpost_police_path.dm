/**
 * Outpost police tests: an officer's step that ends its own walk, and the baton within arm's reach
 * (voidcrew/edits/controllers/subsystem/movement_types.dm, police_baton_reach() in police_force.dm).
 *
 * The room and police of voidcrew_stealth_live/police (voidcrew_outpost_police_stealth.dm). Nothing sleeps: the path
 * loop's step and the force subtree are run by hand. Fork defines are included after the tests, so values are
 * written out: the state "alert"; heat 150 is five stars (OUTPOST_POLICE_STAR_HEAT); the role "stun"
 * (POLICE_ROLE_STUN).
 */

/**
 * An officer walking by its path loop steps onto a tile where it goes alert (as on sighting its suspect, or being
 * shot, on that step): the walk is dropped and the loop deleted inside its own step. The loop must not then ask the
 * pathfinder for a path from nowhere ("Invalid pathfinding start", the soak's path.dm runtime).
 */
/datum/unit_test/voidcrew_stealth_live/police/step_ends_walk
	/// The officer whose walk the trip tile ends
	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/walker
	/// Who it goes alert on there
	var/mob/living/carbon/human/seen

/datum/unit_test/voidcrew_stealth_live/police/step_ends_walk/Destroy()
	walker = null
	seen = null
	return ..()

/datum/unit_test/voidcrew_stealth_live/police/step_ends_walk/proc/on_trip(turf/source, atom/movable/arrived)
	SIGNAL_HANDLER
	if(arrived != walker)
		return
	var/datum/ai_controller/basic_controller/human_npc/stealth/outpost_police/brain = walker.ai_controller
	brain.stealth_go_alert(seen)

/datum/unit_test/voidcrew_stealth_live/police/step_ends_walk/Run()
	TEST_ASSERT(police_room(8, 3), "No room for the test")
	allocate(/obj/effect/landmark/stealth_group, at(0, 2))
	walker = ready_officer(0, 1, EAST)
	seen = visitor_at(7, 2)
	police_pin_warrant(police, seen.mind, 150) // five stars
	var/datum/ai_controller/basic_controller/human_npc/stealth/outpost_police/brain = walker.ai_controller
	var/turf/trip = at(1, 1)
	var/turf/dest = at(5, 1)
	// Its walk, on its pathfinder, as the brain sets one off
	human_npc_set_ai_movement(brain, /datum/ai_movement/jps/stealth)
	brain.goto_dest = dest
	brain.goto_turf = dest
	brain.queue_behavior(/datum/ai_behavior/stealth_goto)
	if(!brain.ai_movement.moving_controllers[brain])
		brain.ai_movement.start_moving_towards(brain, dest, 0)
	var/datum/move_loop/has_target/jps/loop = walker.move_packet?.existing_loops[SSai_movement]
	TEST_ASSERT(istype(loop), "Setup: the officer has no path loop ([loop?.type])")
	loop.movement_path = list(trip, at(2, 1), at(3, 1), at(4, 1), dest)
	RegisterSignal(trip, COMSIG_ATOM_ENTERED, PROC_REF(on_trip))

	// The step: onto the trip tile, where it goes alert
	loop.move()
	UnregisterSignal(trip, COMSIG_ATOM_ENTERED)
	TEST_ASSERT_EQUAL(get_turf(walker), trip, "Setup: the officer did not take its step")
	TEST_ASSERT_EQUAL(brain.stealth_state(), "alert", "Setup: the officer did not go alert on the trip tile")
	TEST_ASSERT(QDELETED(loop), "Setup: going alert on the step did not end the walk's path loop")
	brain.clear_blackboard_key(BB_BASIC_MOB_CURRENT_TARGET)
	brain.stealth_go_unaware()

/**
 * Five stars, a stun officer beside an unarmed suspect on their feet: it takes the baton to them rather than firing
 * its disabler again. One step away, or with a gun in the suspect's hand, it fires as before.
 */
/datum/unit_test/voidcrew_stealth_live/police/baton_within_reach

/datum/unit_test/voidcrew_stealth_live/police/baton_within_reach/Run()
	TEST_ASSERT(police_room(6, 3), "No room for the test")
	allocate(/obj/effect/landmark/stealth_group, at(0, 2))
	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/officer = ready_officer(1, 1, EAST)
	police_arrest_kit(officer)
	officer.police_role = "stun"
	var/mob/living/carbon/human/suspect = visitor_at(2, 1)
	police_pin_warrant(police, suspect.mind, 150) // five stars
	var/datum/ai_controller/basic_controller/human_npc/stealth/outpost_police/brain = officer.ai_controller
	brain.stealth_go_alert(suspect)
	TEST_ASSERT_EQUAL(officer.force_for(suspect), 2, "Setup: a stun officer goes at a five-star suspect with force [officer.force_for(suspect)], not stun") // POLICE_FORCE_STUN
	var/obj/item/gun/energy/sidearm = officer.get_sidearm()
	TEST_ASSERT(sidearm?.can_shoot(), "Setup: the officer has no charged sidearm")
	TEST_ASSERT_NOTNULL(officer.get_baton(), "Setup: the officer has no baton")

	// Beside them, unarmed
	TEST_ASSERT(!police_plans_shot(officer, suspect), "A stun officer beside an unarmed five-star suspect plans another disabler shot")
	TEST_ASSERT(police_plans_melee(officer, suspect), "A stun officer beside an unarmed five-star suspect does not go at them with its baton")
	TEST_ASSERT(officer.is_holding(officer.get_baton()), "A stun officer going at a suspect beside it has no baton in hand")

	// A step away: the disabler
	suspect.forceMove(at(3, 1))
	TEST_ASSERT(police_plans_shot(officer, suspect), "A stun officer two tiles from an unarmed five-star suspect plans no shot")

	// Beside them, armed: the disabler
	suspect.forceMove(at(2, 1))
	var/obj/item/gun/ballistic/automatic/pistol/pistol = allocate(/obj/item/gun/ballistic/automatic/pistol)
	suspect.put_in_hands(pistol)
	TEST_ASSERT(police_plans_shot(officer, suspect), "A stun officer beside an armed five-star suspect plans no shot")
	brain.clear_blackboard_key(BB_BASIC_MOB_CURRENT_TARGET)
	police_pin_warrant(police, suspect.mind, 0)
	brain.stealth_go_unaware()

/// Whether `officer`'s force subtree plans a melee attack on `target` (as police_plans_shot() does for a shot)
/datum/unit_test/proc/police_plans_melee(mob/living/carbon/human/npc/ambient_npc/outpost/police/officer, atom/target)
	var/datum/ai_controller/brain = officer.ai_controller
	var/datum/ai_planning_subtree/outpost_police_force/force_tree = locate() in brain?.planning_subtrees
	if(!force_tree)
		TEST_FAIL("[officer.type]'s brain has no force subtree")
		return FALSE
	brain.set_blackboard_key(BB_BASIC_MOB_CURRENT_TARGET, target)
	brain.planned_behaviors.Cut()
	force_tree.SelectBehaviors(brain, 1)
	. = !!(locate(/datum/ai_behavior/basic_melee_attack/human_npc) in brain.planned_behaviors)
	brain.clear_blackboard_key(BB_BASIC_MOB_CURRENT_TARGET)
	brain.planned_behaviors.Cut()
