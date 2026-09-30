/**
 * Who counts as prison staff (outpost_prison_trouble.dm): people, borgs and anything a player
 * drives, but not a monkey nobody plays. Monkeys are humans by type, so a monkey loose in the yard
 * used to be threatened, targeted by rioters, and cost mood and tension with every punch. A borg in
 * sight is staff in view for the prisoners' talk.
 *
 * A cleanbot nobody drives may use the staff doors, or one built in the office would bump them
 * forever trying to reach the yard's mess. Prisoners never may.
 *
 * Fixtures are in voidcrew_outpost_prison_helpers.dm.
 */
/datum/unit_test/voidcrew_outpost_prison_staff
	parent_type = /datum/unit_test/voidcrew_outpost_management

/datum/unit_test/voidcrew_outpost_prison_staff/Run()
	var/obj/structure/overmap/dynamic/player_outpost/home = trouble_test_claim("staffowner")
	TEST_ASSERT_NOTNULL(home, "The staff test prison did not load")
	var/datum/outpost_prison/prison = test_prison(home)
	var/mob/living/basic/outpost_prisoner/prisoner = trouble_prisoner(prison, prison_spot(home, 4, 10))

	// A monkey nobody plays is not staff, its punches cost nothing, and it is nobody to talk at.
	var/mob/living/carbon/human/species/monkey/monkey = allocate(/mob/living/carbon/human/species/monkey, prison_spot(home, 5, 10))
	TEST_ASSERT(!is_outpost_prison_staff(monkey), "A monkey nobody plays counts as prison staff")
	prisoner.set_mood(60)
	prisoner.staff_hit_cooldown = 0
	prisoner.last_staff_hit = 0
	prison.tension_spike = 0
	TEST_ASSERT(!prisoner.hit_by_staff(monkey), "A monkey's hit cost a prisoner mood")
	TEST_ASSERT(abs(prisoner.mood - 60) < 0.01 && !prison.tension_spike, "A monkey's hit cost [60 - prisoner.mood] mood and [prison.tension_spike] tension")
	TEST_ASSERT_EQUAL(prisoner.last_staff_hit, 0, "A monkey's hit was put down to staff")
	TEST_ASSERT(!prisoner.staff_in_view(), "A monkey in the yard counts as staff in view")
	// With a player in it, it is someone.
	monkey.mind_initialize()
	TEST_ASSERT(is_outpost_prison_staff(monkey), "A monkey a player drives does not count as staff")
	qdel(monkey)

	// A borg in sight is staff in view.
	var/mob/living/silicon/robot/borg = allocate(/mob/living/silicon/robot, prison_spot(home, 6, 10))
	TEST_ASSERT(is_outpost_prison_staff(borg), "A borg does not count as prison staff")
	TEST_ASSERT(prisoner.staff_in_view(), "A borg in sight does not count as staff in view")
	qdel(borg)
	TEST_ASSERT(!prisoner.staff_in_view(), "Staff in view with nobody there")

	// Cleanbots and the staff doors.
	var/obj/machinery/door/airlock/security/prison_staff/staff_door = locate() in prison_spot(home, 9, 6)
	TEST_ASSERT_NOTNULL(staff_door, "The staff door is not where the map puts it")
	TEST_ASSERT(!prison.visitors_allowed, "Visitors are let in by default")
	var/mob/living/basic/bot/cleanbot/cleanbot = allocate(/mob/living/basic/bot/cleanbot, prison_spot(home, 9, 5))
	TEST_ASSERT(staff_door.allowed(cleanbot), "A cleanbot may not use the staff door")
	TEST_ASSERT(!staff_door.allowed(prisoner), "A prisoner may use the staff door")
	// One a player drives is whoever drives it.
	cleanbot.mind_initialize()
	TEST_ASSERT(!staff_door.allowed(cleanbot), "A cleanbot a stranger drives may use the staff door")
	settle_prison_air(home)
