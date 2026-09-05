/// Abandonment follows the crew's characters, including ghosts, across account reuse.
/datum/unit_test/voidcrew_ship_abandonment_recipients

/datum/unit_test/voidcrew_ship_abandonment_recipients/Run()
	var/obj/structure/overmap/ship/ship = allocate(/obj/structure/overmap/ship)
	var/datum/client_interface/player = allocate(/datum/client_interface)
	var/mob/living/carbon/human/consistent/crewmember = allocate(/mob/living/carbon/human/consistent)
	crewmember.mind_initialize()
	crewmember.mind.key = player.key
	var/list/former_members = list(crewmember.mind)

	player.persistent_client.set_mob(crewmember)
	var/list/recipients = ship.get_abandonment_recipients(former_members)
	TEST_ASSERT_EQUAL(length(recipients), 1, "a character still on the former roster should receive the notice")
	TEST_ASSERT(crewmember in recipients, "the notice did not reach the crewmember's current body")

	// Observers reference the body's mind without becoming mind.current.
	var/mob/dead/observer/ghost = allocate(/mob/dead/observer, crewmember)
	player.persistent_client.set_mob(ghost)
	recipients = ship.get_abandonment_recipients(former_members)
	TEST_ASSERT_EQUAL(length(recipients), 1, "a ghosting crewmember should receive the notice")
	TEST_ASSERT(ghost in recipients, "the notice reached the corpse instead of its ghost")

	// A second life on another crew uses the same account but a different mind.
	var/mob/living/carbon/human/consistent/respawned = allocate(/mob/living/carbon/human/consistent)
	respawned.mind_initialize()
	respawned.mind.key = player.key
	player.persistent_client.set_mob(respawned)
	recipients = ship.get_abandonment_recipients(former_members)
	TEST_ASSERT_EQUAL(length(recipients), 0, "the old ship notified a new character on the same account")

	// Multiple old lives on the roster must not cause duplicate notices.
	var/datum/mind/older_life = allocate(/datum/mind, player.key)
	former_members += older_life
	recipients = ship.get_abandonment_recipients(former_members)
	TEST_ASSERT_EQUAL(length(recipients), 0, "multiple old lives notified an unrelated character")
	former_members += respawned.mind
	recipients = ship.get_abandonment_recipients(former_members)
	TEST_ASSERT_EQUAL(length(recipients), 1, "a player who rejoins the same crew should receive exactly one notice")
	TEST_ASSERT(respawned in recipients, "a returning crew member did not receive the notice")

	ghost.mind = respawned.mind
	player.persistent_client.set_mob(ghost)
	recipients = ship.get_abandonment_recipients(list(crewmember.mind, older_life))
	TEST_ASSERT_EQUAL(length(recipients), 0, "the old ship notified the ghost of a different character")
	ghost.mind = null
	player.persistent_client.set_mob(null)
	recipients = ship.get_abandonment_recipients(list(null, allocate(/datum/mind)))
	TEST_ASSERT_EQUAL(length(recipients), 0, "missing or unkeyed minds should not receive notices")
