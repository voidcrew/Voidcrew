/// Re-entering a corpse and ghosting again must not restart the respawn delay; a new death must.
/datum/unit_test/voidcrew_respawn_timer_reenter

/datum/unit_test/voidcrew_respawn_timer_reenter/Run()
	var/datum/client_interface/player = allocate(/datum/client_interface)
	var/datum/persistent_client/persistent = player.persistent_client
	var/mob/living/carbon/human/consistent/body = allocate(/mob/living/carbon/human/consistent)
	body.mind_initialize()
	body.mind.key = player.key

	possess(player, body)
	body.death()
	TEST_ASSERT_EQUAL(body.stat, DEAD, "the test body did not die")
	var/death_time = body.respawn_death_time
	TEST_ASSERT_EQUAL(death_time, world.time, "dying did not record the time of death")
	TEST_ASSERT_EQUAL(persistent.time_of_death, death_time, "dying did not start the respawn delay")
	persistent.death_zone_type = 1 // ZONE_GREEN, defined after the unit-test includes.
	TEST_ASSERT(persistent.died_in_green_zone(), "a Neutral Zone death did not waive the respawn delay")

	// A stasis bed moves timeofdeath forward while it holds the corpse.
	body.timeofdeath += 5 MINUTES
	var/mob/dead/observer/ghost = ghost_out(player, body, can_reenter_corpse = TRUE)
	TEST_ASSERT_EQUAL(persistent.time_of_death, death_time, "ghosting out of a corpse moved the respawn delay")
	TEST_ASSERT(persistent.died_in_green_zone(), "ghosting out of a corpse dropped the Neutral Zone waiver")

	// Re-enter the corpse, wait some more, and ghost again.
	body.timeofdeath += 5 MINUTES
	possess(player, body, ghost)
	ghost = ghost_out(player, body, can_reenter_corpse = TRUE)
	TEST_ASSERT_EQUAL(persistent.time_of_death, death_time, "re-entering the corpse and ghosting again restarted the respawn delay")
	TEST_ASSERT(persistent.died_in_green_zone(), "re-entering the corpse and ghosting again dropped the Neutral Zone waiver")

	// Leaving the corpse for good still counts from the same death.
	possess(player, body, ghost)
	ghost = ghost_out(player, body, can_reenter_corpse = FALSE)
	TEST_ASSERT_EQUAL(persistent.time_of_death, death_time, "leaving the corpse for good restarted the respawn delay")

	// Revived and killed again: that is a new death with a new delay.
	possess(player, body, ghost)
	body.revive(ADMIN_HEAL_ALL)
	TEST_ASSERT_NOTEQUAL(body.stat, DEAD, "the test body was not revived")
	body.respawn_death_time = world.time - 10 MINUTES
	persistent.time_of_death = world.time - 10 MINUTES
	body.death()
	TEST_ASSERT_EQUAL(body.respawn_death_time, world.time, "a second death did not record a new time of death")
	TEST_ASSERT_EQUAL(persistent.time_of_death, world.time, "a second death did not restart the respawn delay")
	ghost = ghost_out(player, body, can_reenter_corpse = TRUE)
	TEST_ASSERT_EQUAL(persistent.time_of_death, world.time, "ghosting after a second death used the first death's time")

	// Ghosting out of a living body keeps upstream's handling.
	possess(player, body, ghost)
	body.revive(ADMIN_HEAL_ALL)
	body.respawn_death_time = world.time - 10 MINUTES
	ghost = ghost_out(player, body, can_reenter_corpse = FALSE)
	TEST_ASSERT_EQUAL(persistent.time_of_death, world.time, "ghosting out of a living body used an old death's time")

	possess(player, null, ghost)

/**
 * Puts the mock player into a mob the way a login would. No real client means no Login(),
 * so the persistent client is linked by hand.
 */
/datum/unit_test/voidcrew_respawn_timer_reenter/proc/possess(datum/client_interface/player, mob/new_mob, mob/dead/observer/old_ghost)
	if(old_ghost)
		old_ghost.key = null
		qdel(old_ghost)
	if(new_mob)
		new_mob.key = player.key
	player.persistent_client.set_mob(new_mob)

/**
 * Ghosts the mock player out of a body. Without a client the ghost never logs in, so upstream
 * ghostize() cannot write its own time of death. This seeds the value it would have written (the
 * body's timeofdeath, which stasis moves, or world.time once the mind is let go) so the test
 * sees what a real player would.
 */
/datum/unit_test/voidcrew_respawn_timer_reenter/proc/ghost_out(datum/client_interface/player, mob/living/body, can_reenter_corpse)
	player.persistent_client.time_of_death = can_reenter_corpse ? body.timeofdeath : world.time
	var/mob/dead/observer/ghost = body.ghostize(can_reenter_corpse)
	TEST_ASSERT(ghost, "the body could not be ghosted")
	player.persistent_client.set_mob(ghost)
	return ghost
