/**
 * # Joining a ship crew wires the friendly marker both ways
 *
 * Every member of a `/datum/team/voidcrew` carries a silent `/datum/antagonist/crew`
 * whose only job is the green FRND marker over their head. The marker is an
 * alternate appearance owned by the joiner, and each crewmate has to be registered
 * as a viewer of every *other* crewmate's marker for the icons to show up.
 *
 * The failure this guards against is one-sided: a player added to a crew sees their
 * own marker appear and nobody else's, because the existing crew's markers were
 * built before that player was in `team.members` and nothing re-offered them.
 */
/datum/unit_test/voidcrew_crew_hud

/datum/unit_test/voidcrew_crew_hud/Run()
	var/mob/living/carbon/human/consistent/veteran = allocate(/mob/living/carbon/human/consistent)
	var/mob/living/carbon/human/consistent/recruit = allocate(/mob/living/carbon/human/consistent)
	veteran.mind_initialize()
	recruit.mind_initialize()

	var/datum/team/voidcrew/ship_team = allocate(/datum/team/voidcrew)

	// The order a real round takes: someone is already aboard, someone joins after.
	ship_team.add_member(veteran.mind)
	ship_team.add_member(recruit.mind)

	var/datum/antagonist/crew/veteran_crew = veteran.mind.has_antag_datum(/datum/antagonist/crew)
	var/datum/antagonist/crew/recruit_crew = recruit.mind.has_antag_datum(/datum/antagonist/crew)
	TEST_ASSERT_NOTNULL(veteran_crew, "the crewmember already aboard never got a crew datum")
	TEST_ASSERT_NOTNULL(recruit_crew, "the crewmember who joined second never got a crew datum")

	var/datum/atom_hud/veteran_marker = veteran_crew.team_hud_ref?.resolve()
	var/datum/atom_hud/recruit_marker = recruit_crew.team_hud_ref?.resolve()
	TEST_ASSERT_NOTNULL(veteran_marker, "the crewmember already aboard has no team HUD to show anyone")
	TEST_ASSERT_NOTNULL(recruit_marker, "the crewmember who joined second has no team HUD to show anyone")

	TEST_ASSERT(recruit_marker.hud_users_all_z_levels[veteran], "the crew already aboard was never shown the new member's marker")
	TEST_ASSERT(veteran_marker.hud_users_all_z_levels[recruit], "the new member was never shown the existing crew's marker")

	// Leaving has to take the marker with it, or a kicked player stays green forever.
	ship_team.remove_member(recruit.mind)
	TEST_ASSERT_NULL(recruit.mind.has_antag_datum(/datum/antagonist/crew), "removing a member left their crew datum, and its marker, behind")
