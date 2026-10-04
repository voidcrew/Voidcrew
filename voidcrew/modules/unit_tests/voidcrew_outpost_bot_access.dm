/**
 * Bots on a player outpost answer to its members the way its machines do. A resident or the
 * owner unlocks one without a robotics or department ID; a visitor without one cannot.
 */
/datum/unit_test/voidcrew_outpost_bot_access
	parent_type = /datum/unit_test/voidcrew_outpost_management

/datum/unit_test/voidcrew_outpost_bot_access/Run()
	var/obj/structure/overmap/dynamic/player_outpost/home = upgrade_test_claim("botowner")
	TEST_ASSERT_NOTNULL(home, "The bot test outpost did not load")
	var/turf/floor = get_turf(home.management_console)
	TEST_ASSERT_EQUAL(get_outpost_from_atom(floor), home, "The test bot's tile is not on the claim")
	var/mob/living/carbon/human/owner = make_player(floor, "botowner")
	var/mob/living/carbon/human/visitor = make_player(floor, "botvisitor")
	var/mob/living/carbon/human/resident = make_player(floor, "botresident")
	home.residents |= resident.mind

	// A basic bot: the medbot.
	var/mob/living/basic/bot/medbot/medbot = allocate(/mob/living/basic/bot/medbot, floor)
	TEST_ASSERT(medbot.bot_access_flags & BOT_COVER_LOCKED, "The test medbot did not start locked")
	TEST_ASSERT(!medbot.allowed(visitor), "A visitor with no ID may work an outpost's medbot")
	medbot.unlock_with_id(visitor)
	TEST_ASSERT(medbot.bot_access_flags & BOT_COVER_LOCKED, "A visitor with no ID unlocked an outpost's medbot")
	TEST_ASSERT(medbot.allowed(owner), "The owner may not work their outpost's medbot")
	medbot.unlock_with_id(resident)
	TEST_ASSERT(!(medbot.bot_access_flags & BOT_COVER_LOCKED), "A resident could not unlock the outpost's medbot")

	// An older simple_animal bot: the MULE.
	var/mob/living/simple_animal/bot/mulebot/mule = allocate(/mob/living/simple_animal/bot/mulebot, floor)
	TEST_ASSERT(!mule.allowed(visitor), "A visitor with no ID may work an outpost's MULE")
	TEST_ASSERT(mule.allowed(resident), "A resident may not work the outpost's MULE")
