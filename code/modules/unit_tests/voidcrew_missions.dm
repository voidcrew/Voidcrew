/**
 * # Mission wiring and contract caps
 *
 * Two things: the shape of the 21-type contract table (which will keep
 * growing), and the type cap.
 *
 * `mission_limit` used to be enforced only where offers are *generated*. Boards
 * can hold more copies of a capped contract than the cap allows — the
 * generation roll only counts live missions — so N ships could each accept the
 * same "limit 1" job and all run it at once. The cap has to hold at accept
 * time too, which is what mission_type_within_limit(type, excluding) exists
 * for; `excluding` is how an offer being accepted avoids counting against its
 * own cap.
 */

/**
 * Test-only capped contract.
 *
 * weight 0 keeps it out of SSmissions' generation pool (Initialize only
 * collects types with weight > 0), and the generation override keeps it from
 * reaching for an overmap that a CIBUILDING world — which boots MetaStation —
 * does not have.
 */
/datum/mission/unit_test_capped
	name = "Unit Test Capped Contract"
	desc = "Exists only for /datum/unit_test/voidcrew_mission_type_limit."
	weight = 0
	mission_limit = 1

/datum/mission/unit_test_capped/generate_mission_details()
	return

/datum/unit_test/voidcrew_mission_type_limit

/datum/unit_test/voidcrew_mission_type_limit/Run()
	var/list/saved_active = SSmissions.all_active_missions.Copy()
	SSmissions.all_active_missions.Cut()

	var/datum/mission/first = new /datum/mission/unit_test_capped()
	var/datum/mission/second = new /datum/mission/unit_test_capped()

	TEST_ASSERT(mission_type_within_limit(/datum/mission/unit_test_capped, first), "a limit-1 contract was refused with nothing of its type running")

	SSmissions.all_active_missions += first
	TEST_ASSERT(!mission_type_within_limit(/datum/mission/unit_test_capped, second), "a limit-1 contract was still 'within limit' with one already running, so a second ship can accept the same capped job. Boards hold more copies than the cap allows, so the cap has to hold at accept time (see /obj/structure/overmap/ship/proc/accept_mission).")
	TEST_ASSERT(mission_type_within_limit(/datum/mission/unit_test_capped, first), "the running mission counted against its own cap — accept_mission passes the mission being accepted as `excluding` for exactly this reason")

	SSmissions.all_active_missions -= first
	TEST_ASSERT(mission_type_within_limit(/datum/mission/unit_test_capped, second), "the cap did not free up after the running mission ended")

	// mission_limit 0 means uncapped, not "capped at zero"
	TEST_ASSERT(mission_type_within_limit(/datum/mission), "an uncapped mission type (mission_limit 0) was refused")

	qdel(first)
	qdel(second)
	SSmissions.all_active_missions.Cut()
	SSmissions.all_active_missions += saved_active

/datum/unit_test/voidcrew_mission_wiring

/datum/unit_test/voidcrew_mission_wiring/Run()
	var/checked = 0
	for(var/datum/mission/mission_type as anything in subtypesof(/datum/mission))
		if(mission_type == /datum/mission/unit_test_capped)
			continue // the fixture above
		checked++
		if(!length(initial(mission_type.name)))
			TEST_FAIL("[mission_type] has no name — the board lists a blank contract")
		if(!length(initial(mission_type.desc)))
			TEST_FAIL("[mission_type] has no desc")
		var/value_min = initial(mission_type.value_min)
		var/value_max = initial(mission_type.value_max)
		if(value_min > value_max)
			TEST_FAIL("[mission_type] has value_min [value_min] above value_max [value_max], so the reward roll is inverted")
		if(value_min < 0)
			TEST_FAIL("[mission_type] has a negative pay floor ([value_min])")
		if(initial(mission_type.duration) <= 0)
			TEST_FAIL("[mission_type] has duration [initial(mission_type.duration)] — the timeout fires the moment it is accepted")
		if(initial(mission_type.weight) < 0)
			TEST_FAIL("[mission_type] has a negative weight")
		if(initial(mission_type.mission_limit) < 0)
			TEST_FAIL("[mission_type] has a negative mission_limit; 0 means uncapped")
		if(initial(mission_type.voucher_count) < 0)
			TEST_FAIL("[mission_type] pays a negative number of vouchers")
		// Literals 0/1 = MISSION_QUEST_LOST_FAIL / MISSION_QUEST_LOST_RETARGET
		// (voidcrew/_DEFINES/missions.dm). Unit-test files compile before
		// voidcrew/_DEFINES, so the fork defines are not available here.
		var/policy = initial(mission_type.quest_lost_policy)
		if(policy != 0 && policy != 1)
			TEST_FAIL("[mission_type] has quest_lost_policy [policy]; the only values are 0 (fail the contract) and 1 (retarget it)")
		var/reward = initial(mission_type.mission_reward)
		if(reward && !ispath(reward, /atom/movable))
			TEST_FAIL("[mission_type].mission_reward [reward] is not a spawnable movable, so turn-in pays out nothing")
	TEST_ASSERT(checked >= 15, "only [checked] mission types were checked")

	for(var/datum/mission_objective/deliver/objective_type as anything in subtypesof(/datum/mission_objective/deliver))
		var/required = initial(objective_type.required_type)
		// null is legitimate: several deliver objectives pick their ask at generation
		if(required && !ispath(required, /obj/item))
			TEST_FAIL("[objective_type].required_type [required] is not an item path, so can_turn_in() can never match anything")
		if(initial(objective_type.required_amount) < 1)
			TEST_FAIL("[objective_type] asks for [initial(objective_type.required_amount)] of something — it can never be satisfied by handing anything over")
