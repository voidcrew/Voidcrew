/**
 * How much the Cascade slow-mo covers (voidcrew/modules/cyberware/ware_sandy_timestop_cover.dm): its reach, never
 * another crew's player, and mobs that pace themselves on their own clocks (the kingpin's crew).
 *
 * Unit-test files compile before voidcrew/_DEFINES/, so literals stand in for module defines.
 */

/// The field takes what is 11 tiles out, leaves what is 20 out alone, and never holds a player from another crew.
/datum/unit_test/voidcrew_cyberware_timestop/cover_reach

/datum/unit_test/voidcrew_cyberware_timestop/cover_reach/Run()
	var/turf/here = spot(0, 0)
	var/turf/near_spot = locate(here.x + 11, here.y, here.z) || locate(here.x - 11, here.y, here.z)
	var/turf/far_spot = locate(here.x + 20, here.y, here.z) || locate(here.x - 20, here.y, here.z)
	TEST_ASSERT(near_spot && far_spot, "Test fixture: no turfs 11 and 20 tiles from the test room")
	var/mob/living/carbon/human/user = make_user(here, "sandycover[type]")
	set_window(user, 2 SECONDS)
	var/mob/living/carbon/human/near = allocate(/mob/living/carbon/human/consistent, near_spot)
	var/mob/living/carbon/human/far = allocate(/mob/living/carbon/human/consistent, far_spot)
	surge(user)
	TEST_ASSERT(cyberware_time_stopping(user), "The slow-mo didn't start")
	sleep(0.6 SECONDS) // a few field ticks: the room is taken a batch at a time
	TEST_ASSERT(GLOB.cyberware_time_dilated[near], "A body 11 tiles out isn't slowed")
	var/datum/proximity_monitor/advanced/timestop/sandevistan/field
	for(var/datum/proximity_monitor/advanced/timestop/sandevistan/each as anything in GLOB.cyberware_time_fields)
		if(each.host == user)
			field = each
	TEST_ASSERT_NOTNULL(field, "The slow-mo has no field")
	TEST_ASSERT(field.tinted[near_spot], "The ground 11 tiles out isn't taken")
	TEST_ASSERT(!field.tinted[far_spot], "The ground 20 tiles out is taken")
	TEST_ASSERT(!GLOB.cyberware_time_dilated[far], "A body 20 tiles out is slowed")
	TEST_ASSERT(!cyberware_time_has_tint(far_spot), "The ground 20 tiles out is tinted")
	// A player from another crew the field reaches (its room can run past the witness range) is never held. Made after
	// the slow-mo started and handed to the field directly: anywhere near, they would end it as a witness.
	var/turf/away = locate(here.x + 40, here.y, here.z) || locate(1, here.y, here.z)
	var/mob/living/carbon/human/outsider = allocate(/mob/living/carbon/human/consistent, away)
	outsider.key = "sandycoveroutsider[type]" // a player before the field ever sees them
	outsider.forceMove(spot(1, 1))
	TEST_ASSERT(!field.freeze_atom(outsider), "The field took a player from another crew")
	TEST_ASSERT(!GLOB.cyberware_time_dilated[outsider], "A player from another crew is slowed")
	outsider.key = null

/**
 * A kingpin's crew paces its goons on its own clocks. In a slow-mo they shoot and step at the field's pace, not their
 * own: shots and steps over two seconds before and inside the slow-mo, driven a tick at a time as the crew does.
 */
/datum/unit_test/voidcrew_cyberware_timestop/kingpin_crew

/datum/unit_test/voidcrew_cyberware_timestop/kingpin_crew/Run()
	var/turf/seat = spot(2, 0)
	var/obj/structure/chair/sofa/corp/sofa = allocate(/obj/structure/chair/sofa/corp, seat)
	sofa.setDir(NORTH)
	var/list/posts = list(list(spot(4, 0), "pistol"), list(spot(0, 4), "shotgun")) // BOUNTY_GOON_WEAPON_*
	var/mob/living/carbon/human/npc/bounty_criminal/kingpin/kingpin = bounty_kingpin_setup(seat, posts, bounty_kingpin_make_record(), TRUE)
	TEST_ASSERT_NOTNULL(kingpin, "Test fixture: no kingpin")
	var/datum/bounty_kingpin_crew/crew = kingpin.kingpin_crew
	var/list/goons = crew.goons()
	TEST_ASSERT_EQUAL(length(goons), 2, "Test fixture: the lounge doesn't have its two goons")
	var/mob/living/carbon/human/npc/bounty_kingpin_goon/shooter = goons[1]
	var/mob/living/carbon/human/npc/bounty_kingpin_goon/walker = goons[2]
	var/mob/living/carbon/human/user = make_user(spot(2, 3), "sandykingpin[type]")
	ADD_TRAIT(user, TRAIT_GODMODE, TRAIT_SOURCE_UNIT_TESTS)
	set_window(user, 6 SECONDS)
	TEST_ASSERT(crew.start_shootout(user, TRUE), "Test fixture: the shootout didn't start")
	crew.crew_draw_ends_at = world.time
	crew.process(0.2)
	STOP_PROCESSING(SSfastprocess, crew) // the test drives the goons a tick at a time
	for(var/mob/living/carbon/human/npc/goon as anything in goons + kingpin)
		goon.ai_controller?.set_ai_status(AI_STATUS_OFF)

	var/list/normal = kingpin_rates(crew, shooter, walker, user)
	surge(user)
	TEST_ASSERT(cyberware_time_stopping(user), "The slow-mo didn't start")
	TEST_ASSERT(GLOB.cyberware_time_dilated[shooter] && GLOB.cyberware_time_dilated[walker], "The field didn't take the goons")
	var/scale = cyberware_time_scale(shooter)
	var/list/slowed = kingpin_rates(crew, shooter, walker, user)
	TEST_NOTICE(src, "kingpin goons over 2 s: normal [normal[1]] shots, [normal[2]] steps; in the slow-mo at [scale]: [slowed[1]] shots, [slowed[2]] steps")
	log_world("SANDY COVER kingpin goons over 2 s: normal [normal[1]] shots, [normal[2]] steps; in the slow-mo at [scale]: [slowed[1]] shots, [slowed[2]] steps")
	TEST_ASSERT(normal[1] >= 3 && normal[2] >= 3, "Test fixture: the goons barely shot or stepped at full speed ([normal[1]] shots, [normal[2]] steps)")
	TEST_ASSERT(slowed[1] <= max(1, normal[1] / 2), "A goon in the slow-mo still shoots near full rate ([slowed[1]] against [normal[1]])")
	TEST_ASSERT(slowed[2] <= max(1, normal[2] / 2), "A goon in the slow-mo still steps near full rate ([slowed[2]] against [normal[2]])")
	// the pushed clock itself
	shooter.goon_next_fire_at = world.time + 10
	var/was = shooter.goon_next_fire_at
	sleep(0.6 SECONDS)
	TEST_ASSERT(shooter.goon_next_fire_at > was, "The field didn't push the goon's trigger clock")

	for(var/datum/bounty_kingpin_crew/each as anything in GLOB.bounty_kingpin_crews.Copy())
		for(var/mob/living/carbon/human/npc/bounty_kingpin_goon/goon as anything in each.goons())
			qdel(goon)
		var/mob/living/carbon/human/npc/bounty_criminal/kingpin/boss = each.kingpin()
		if(boss)
			qdel(boss)
		else
			qdel(each)

/// Two seconds of the crew's turns for `shooter` (a pistol at `target`) and `walker` (back and forth on its row):
/// list(shots, steps).
/datum/unit_test/voidcrew_cyberware_timestop/kingpin_crew/proc/kingpin_rates(datum/bounty_kingpin_crew/crew, mob/living/carbon/human/npc/bounty_kingpin_goon/shooter, mob/living/carbon/human/npc/bounty_kingpin_goon/walker, mob/living/target)
	var/shots = 0
	var/steps = 0
	var/list/ends = list(spot(0, 4), spot(1, 4))
	var/until = world.time + 2 SECONDS
	while(world.time < until)
		var/obj/item/gun/ballistic/pistol = human_npc_held_gun(shooter)
		if(istype(pistol) && pistol.magazine)
			pistol.magazine.top_off()
			if(!pistol.chambered)
				pistol.chamber_round()
		shooter.next_click = 0
		shooter.next_move = 0
		if(crew.goon_try_attack(shooter, target))
			shots++
		var/turf/goal = get_turf(walker) == ends[1] ? ends[2] : ends[1]
		if(crew.goon_step_toward(walker, goal))
			steps++
		sleep(world.tick_lag)
	return list(shots, steps)
