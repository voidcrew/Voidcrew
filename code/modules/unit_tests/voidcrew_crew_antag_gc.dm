/**
 * # Leaving a crew releases the crew antag datum for garbage collection
 *
 * Round 4 (2026-08-14) hard-deleted 46 of 47 qdel'd /datum/antagonist/crew, every one
 * holding exactly ONE outstanding reference at GC check time - 14 s of world freeze.
 * This probes refcount() directly after both removal paths, so a reintroduced holder
 * fails here instead of surfacing as a hard-delete profile three weeks later.
 */
/datum/unit_test/voidcrew_crew_antag_gc

/datum/unit_test/voidcrew_crew_antag_gc/Run()
	var/mob/living/carbon/human/consistent/veteran = allocate(/mob/living/carbon/human/consistent)
	var/mob/living/carbon/human/consistent/leaver = allocate(/mob/living/carbon/human/consistent)
	veteran.mind_initialize()
	leaver.mind_initialize()

	var/datum/team/voidcrew/ship_team = allocate(/datum/team/voidcrew)
	ship_team.add_member(veteran.mind)
	ship_team.add_member(leaver.mind)

	// Path 1: the team removes the member (kick, ship loss, cryo departure)
	var/datum/antagonist/crew/leaver_antag = leaver.mind.has_antag_datum(/datum/antagonist/crew)
	TEST_ASSERT_NOTNULL(leaver_antag, "joining a voidcrew team did not create a crew antag datum")
	ship_team.remove_member(leaver.mind)
	TEST_ASSERT(QDELETED(leaver_antag), "team removal did not qdel the member's crew antag datum")
	assert_antag_released(leaver_antag, leaver.mind, "team.remove_member()")

	// Path 2: the mind sheds the datum itself
	var/datum/antagonist/crew/veteran_antag = veteran.mind.has_antag_datum(/datum/antagonist/crew)
	TEST_ASSERT_NOTNULL(veteran_antag, "the remaining member has no crew antag datum")
	veteran.mind.remove_antag_datum(/datum/antagonist/crew)
	TEST_ASSERT(QDELETED(veteran_antag), "remove_antag_datum did not qdel the crew antag datum")
	assert_antag_released(veteran_antag, veteran.mind, "mind.remove_antag_datum()")

/// Fails with a diagnosis of who still holds the datum, not just a count.
/// refcount() includes exactly three refs we account for: the caller's local var,
/// this proc's argument slot, and the SSgarbage queue entry a fresh qdel creates
/// (the queue stores the datum itself - see REFS_WE_EXPECT in garbage.dm).
/datum/unit_test/voidcrew_crew_antag_gc/proc/assert_antag_released(datum/antagonist/crew/antag, datum/mind/former_owner, removal_path)
	var/held = refcount(antag) - 3
	if(held <= 0)
		return
	var/list/known_holders = list()
	if(antag in GLOB.antagonists)
		known_holders += "GLOB.antagonists"
	if(antag in former_owner.antag_datums)
		known_holders += "mind.antag_datums"
	if(antag.crew_team)
		known_holders += "crew_team back-ref still set"
	if(antag.owner)
		known_holders += "owner still set"
	TEST_FAIL("[removal_path] left the crew antag datum held by [held] reference(s) - \
		it will hard-delete on a live server. Known holders: [length(known_holders) ? known_holders.Join(", ") : "none of the usual suspects (check signals/timers/UIs)"]")
