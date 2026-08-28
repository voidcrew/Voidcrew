/**
 * # Mission wiring and contract caps
 *
 * Two things: the shape of the 21-type contract table (which will keep
 * growing), and the type cap.
 *
 * `mission_limit` used to be enforced only where offers are *generated*. Boards
 * can hold more copies of a capped contract than the cap allows, the
 * generation roll only counts live missions, so N ships could each accept the
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
 * reaching for an overmap that a CIBUILDING world, which boots MetaStation,
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
	TEST_ASSERT(mission_type_within_limit(/datum/mission/unit_test_capped, first), "the running mission counted against its own cap, accept_mission passes the mission being accepted as `excluding` for exactly this reason")

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
			TEST_FAIL("[mission_type] has no name, the board lists a blank contract")
		if(!length(initial(mission_type.desc)))
			TEST_FAIL("[mission_type] has no desc")
		var/value_min = initial(mission_type.value_min)
		var/value_max = initial(mission_type.value_max)
		if(value_min > value_max)
			TEST_FAIL("[mission_type] has value_min [value_min] above value_max [value_max], so the reward roll is inverted")
		if(value_min < 0)
			TEST_FAIL("[mission_type] has a negative pay floor ([value_min])")
		if(initial(mission_type.duration) <= 0)
			TEST_FAIL("[mission_type] has duration [initial(mission_type.duration)]. The timeout fires the moment it is accepted")
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
			TEST_FAIL("[objective_type] asks for [initial(objective_type.required_amount)] of something. It can never be satisfied by handing anything over")

/**
 * # Ruin contracts never point at an occupied site
 *
 * A recovery-family contract picks a live ruin signal out of
 * GLOB.space_ruin_signals. Nothing used to stop it picking the ruin the
 * accepting crew was docked at that second, and that pick is self-destructing:
 * the field objective arms immediately (the interior is loaded, because they
 * are standing in it), and then undocking runs check_and_respawn(), which frees
 * the interior out from under the contract. From the helm, taking a job and
 * leaving made the job disappear.
 *
 * `loaded` is the tell. A ruin is only ever loaded because somebody is there or
 * has just left. All three tiers of the pick are exercised here, because the two
 * preferences are not interchangeable and the first attempt at this fix folded
 * them into one set: with the boards holding enough offers to keep most of the
 * sector claimed, a combined "cold AND unclaimed" set empties out routinely and
 * falls through to picking anything at all, occupied berth included. Avoiding an
 * occupied site has to outrank avoiding a double-booked one.
 */
/datum/unit_test/voidcrew_mission_ruin_target_picker

/datum/unit_test/voidcrew_mission_ruin_target_picker/Run()
	var/list/obj/structure/overmap/space_ruin/live_ruins = list()
	for(var/obj/structure/overmap/space_ruin/ruin as anything in GLOB.space_ruin_signals)
		if(QDELETED(ruin) || ruin.mission_locked || ruin.mission_exclusive)
			continue
		if(!istype(get_turf(ruin), /turf/open/overmap))
			continue
		live_ruins += ruin

	// REPAIRED: this used to be `if(length(live_ruins) < 2) return`, and a bare
	// return out of Run() is a PASS. On any world whose pool came up short this
	// test asserted NOTHING and reported green - worse than not existing, because
	// the coverage matrix counted it.
	//
	// The premise was wrong as well as the shape. A CI world DOES have an
	// overmap: SSovermap.Initialize() paints the overmap block onto the centcom z
	// and runs setup_space_ruins() whatever station map booted, seeding
	// MIN..MAX_OVERMAP_SPACE_RUINS signals (23 of them in the 2026-08-27 CI run's
	// data/logs/ci/debug.log). Where the pool still comes up short it is topped
	// up from vc_mint_test_ruin_signals() (voidcrew_mission_flows.dm) - the picker
	// asks a candidate for nothing but "alive, unlocked, unclaimed, on an overmap
	// tile", so a signal with no interior is a complete target to it. If even that
	// cannot deliver, the test says so and fails.
	var/list/obj/structure/overmap/space_ruin/minted = list()
	if(length(live_ruins) < 2)
		minted = vc_mint_test_ruin_signals(2 - length(live_ruins))
		live_ruins += minted
	if(length(live_ruins) < 2)
		TEST_FAIL("only [length(live_ruins)] ruin signal\s are visible to the target picker and no more could be minted onto the overmap, \
			so none of the three tiers below is exercised. This is the precondition failing loudly; it used to return quietly and report PASS.")
		vc_release_test_ruin_signals(minted)
		return

	// Remember what we are about to lie about, so the round gets it back
	var/list/saved_loaded = list()
	var/list/saved_claims = list()
	for(var/obj/structure/overmap/space_ruin/ruin as anything in live_ruins)
		saved_loaded[ruin] = ruin.loaded
		saved_claims[ruin] = ruin.mission_claims

	var/obj/structure/overmap/space_ruin/occupied = live_ruins[1]
	occupied.loaded = TRUE
	for(var/i in 2 to length(live_ruins))
		var/obj/structure/overmap/space_ruin/cold = live_ruins[i]
		cold.loaded = FALSE
		cold.mission_claims = 0

	var/datum/mission_target/space_ruin/target = new(null)

	// Tier 1: cold and unclaimed sites exist, so one of those is the pick
	for(var/_ in 1 to 40)
		if(!target.resolve())
			TEST_FAIL("space_ruin target resolve() found nothing with [length(live_ruins)] ruins on the overmap")
			break
		if(target.ruin == occupied)
			TEST_FAIL("a ruin contract targeted a loaded (occupied) ruin while [length(live_ruins) - 1] cold, unclaimed ruins were available")
			break

	// Tier 2: every cold site is already spoken for. Double-booking one of them
	// is still correct - the loaded ruin is the one pick that voids itself.
	for(var/i in 2 to length(live_ruins))
		var/obj/structure/overmap/space_ruin/cold = live_ruins[i]
		cold.mission_claims = 1
	for(var/_ in 1 to 40)
		if(!target.resolve())
			TEST_FAIL("space_ruin target resolve() found nothing once every cold ruin was claimed")
			break
		if(target.ruin == occupied)
			TEST_FAIL("with every cold ruin already claimed, the picker fell back to a loaded (occupied) ruin instead of double-booking a cold one. Accepting that contract while docked there arms the objective inside the site the crew is standing in, and undocking recycles the site out from under it (see check_and_respawn). Avoiding an occupied site outranks avoiding a double-booking.")
			break

	// Tier 3: nowhere cold left. The picker must still hand something back rather
	// than fail generation and drop the contract off the board entirely.
	for(var/obj/structure/overmap/space_ruin/ruin as anything in live_ruins)
		ruin.loaded = TRUE
	// Recorded rather than asserted with TEST_ASSERT: the macro returns out of
	// Run(), which would now leave the round's ruins lying about their loaded
	// state and leak any minted signal onto the overmap for the rest of the run.
	// Same condition, same message, no early exit.
	if(!target.resolve())
		TEST_FAIL("with every ruin loaded, the picker refused to pick any of them instead of falling back. Recovery contracts stop generating entirely")

	qdel(target)
	for(var/obj/structure/overmap/space_ruin/ruin as anything in live_ruins)
		ruin.loaded = saved_loaded[ruin]
		ruin.mission_claims = saved_claims[ruin]
	vc_release_test_ruin_signals(minted)

/**
 * A contract that marks itself exclusive_site must get a wreck to itself.
 *
 * Double-booking a ruin is cosmetic for salvage and fatal for a rescue. A bounty
 * contract spawns its named target plus a paid entourage at a random interior
 * turf; a rescue spawns a 60 HP survivor who never fights back at another random
 * interior turf in the same small template. Playtesting turned that up the
 * obvious way - the crew flew out to a rescue, found the survivor dead, and left
 * with the identification tag of somebody else's bounty target instead.
 *
 * So: an exclusive pick only ever comes out of the cold-and-unclaimed tier, it
 * flags the site so nothing else can aim there, it refuses to generate rather
 * than share, and it gives the flag back when the contract lets go.
 */
/datum/unit_test/voidcrew_mission_exclusive_site

/datum/unit_test/voidcrew_mission_exclusive_site/Run()
	var/list/obj/structure/overmap/space_ruin/live_ruins = list()
	for(var/obj/structure/overmap/space_ruin/ruin as anything in GLOB.space_ruin_signals)
		if(QDELETED(ruin) || ruin.mission_locked || ruin.mission_exclusive)
			continue
		if(!istype(get_turf(ruin), /turf/open/overmap))
			continue
		live_ruins += ruin

	// REPAIRED: this used to be `if(length(live_ruins) < 3) return`, the same
	// silent PASS as its sibling above - see the note there for why the "no
	// overmap worth testing against" premise was false as well. Three is the real
	// number here: the exclusive claim takes one, the sharing contract needs
	// somewhere else to land, and the starvation tier needs a third to claim.
	var/list/obj/structure/overmap/space_ruin/minted = list()
	if(length(live_ruins) < 3)
		minted = vc_mint_test_ruin_signals(3 - length(live_ruins))
		live_ruins += minted
	if(length(live_ruins) < 3)
		TEST_FAIL("only [length(live_ruins)] ruin signal\s are visible to the target picker and no more could be minted onto the overmap, \
			so the exclusive claim, the lockout and the refuse-rather-than-share tier are all unexercised. This used to return quietly and report PASS.")
		vc_release_test_ruin_signals(minted)
		return

	var/list/saved_loaded = list()
	var/list/saved_claims = list()
	for(var/obj/structure/overmap/space_ruin/ruin as anything in live_ruins)
		saved_loaded[ruin] = ruin.loaded
		saved_claims[ruin] = ruin.mission_claims
		ruin.loaded = FALSE
		ruin.mission_claims = 0

	var/datum/mission/exclusive_mission = new()
	exclusive_mission.exclusive_site = TRUE
	var/datum/mission/sharing_mission = new()

	var/datum/mission_target/space_ruin/exclusive_target = new(exclusive_mission)
	var/datum/mission_target/space_ruin/sharing_target = new(sharing_mission)

	if(!exclusive_target.resolve())
		TEST_FAIL("an exclusive contract found no site with [length(live_ruins)] cold, unclaimed ruins on the overmap")
	else
		var/obj/structure/overmap/space_ruin/taken = exclusive_target.ruin
		// Recorded rather than asserted with TEST_ASSERT throughout this branch:
		// the macro returns out of Run(), which would now strand the round's ruins
		// with edited claims, leave an exclusive flag set on a live site for the
		// rest of the round, and leak any minted signal onto the overmap. Same
		// conditions, same messages, no early exit.
		if(!taken.mission_exclusive)
			TEST_FAIL("an exclusive contract claimed a ruin without flagging it exclusive, so the next contract can still aim into it")

		// Nobody else may land on it, however many rolls they get. Released between
		// rolls so the "never re-pick the previous site" rule doesn't starve the
		// candidate set on a small overmap and read as a failure.
		for(var/_ in 1 to 40)
			sharing_target.unhook()
			if(!sharing_target.resolve())
				TEST_FAIL("a normal contract found no site at all while [length(live_ruins) - 1] unclaimed ruins were free")
				break
			if(sharing_target.ruin == taken)
				TEST_FAIL("a normal contract targeted a ruin an exclusive contract is holding - this is the bounty-in-the-rescue's-wreck case that kills the survivor before the crew arrives")
				break

		// Nothing cold and unclaimed left: refuse rather than share
		sharing_target.unhook() // its claim would otherwise come back off below
		for(var/obj/structure/overmap/space_ruin/ruin as anything in live_ruins)
			if(ruin != taken)
				ruin.mission_claims = 1
		var/datum/mission_target/space_ruin/starved_target = new(exclusive_mission)
		if(starved_target.resolve())
			TEST_FAIL("an exclusive contract double-booked a site once every other ruin was claimed; it should fail generation and let the board roll something else")
		qdel(starved_target)

		// ...and the flag comes back off when the contract lets go
		qdel(exclusive_target)
		exclusive_target = null
		if(taken.mission_exclusive)
			TEST_FAIL("a released exclusive claim left the ruin flagged, so no contract can ever target that site again this round")
			taken.mission_exclusive = FALSE // do not hand the round a permanently locked site on the way out

	if(exclusive_target)
		qdel(exclusive_target)
	qdel(sharing_target)
	qdel(exclusive_mission)
	qdel(sharing_mission)
	for(var/obj/structure/overmap/space_ruin/ruin as anything in live_ruins)
		ruin.loaded = saved_loaded[ruin]
		ruin.mission_claims = saved_claims[ruin]
	vc_release_test_ruin_signals(minted)
