// Stealth guards: the radio net, carried bodies and the admin tools (stealth_radio.dm, stealth_disguise.dm,
// stealth_admin_noise.dm, npc_ships admin_verbs.dm). Unit tests compile before voidcrew/_DEFINES, so values from there
// are written out: STEALTH_CALL_ALARM 3.

/// An alarm with no speaker (the admin's "Radio alarm at my turf") still reaches every guard with a working radio.
/datum/unit_test/voidcrew_stealth_fix_radio_no_speaker

/datum/unit_test/voidcrew_stealth_fix_radio_no_speaker/Run()
	var/datum/turf_reservation/block = stealth_block(8, 5)
	TEST_ASSERT_NOTNULL(block, "No room for the test")
	var/obj/effect/landmark/stealth_group/marker = allocate(/obj/effect/landmark/stealth_group, stealth_at(block, 6, 4))
	var/datum/stealth_group/group = marker.group
	var/mob/living/carbon/human/npc/first = allocate(/mob/living/carbon/human/npc/ruin/trooper/scav/lookout, stealth_at(block, 2, 2))
	var/mob/living/carbon/human/npc/second = allocate(/mob/living/carbon/human/npc/ruin/trooper/scav/lookout, stealth_at(block, 5, 2))
	var/datum/ai_controller/basic_controller/human_npc/stealth/first_ai = first.ai_controller
	var/datum/ai_controller/basic_controller/human_npc/stealth/second_ai = second.ai_controller
	first_ai.stealth_setup()
	second_ai.stealth_setup()
	TEST_ASSERT(first_ai.group == group && second_ai.group == group, "Test fixture: the lookouts aren't in the marker's group")
	// No player on the test level turns every AI off, and a guard with its AI off hears nothing.
	first_ai.set_ai_status(AI_STATUS_ON)
	second_ai.set_ai_status(AI_STATUS_ON)
	group.next_radio_alarm = 0
	var/told = group.radio_call(null, 3, stealth_at(block, 1, 1))
	TEST_ASSERT_EQUAL(told, 2, "An alarm with no speaker didn't reach both guards")
	TEST_ASSERT(group.next_radio_alarm > 0, "An alarm with no speaker didn't start the group's cooldown")
	qdel(block)

/// Carrying a fallen guard over the shoulder gives a disguise away, like dragging one.
/datum/unit_test/voidcrew_stealth_fix_radio_carried_body

/datum/unit_test/voidcrew_stealth_fix_radio_carried_body/Run()
	var/datum/turf_reservation/block = stealth_block(16, 5)
	TEST_ASSERT_NOTNULL(block, "No room for the test")
	var/mob/living/carbon/human/npc/guard = stealth_guard(block, 6, 2)
	var/datum/ai_controller/basic_controller/human_npc/stealth/stealth_ai = stealth_ai(guard)
	stealth_ai.stealth_setup()
	var/mob/living/carbon/human/person = stealth_person(block, 12, 2)
	stealth_dress(person)
	// Not carrying anything, the whole set holds.
	stealth_ai.next_body_scan = world.time + 1 MINUTES
	stealth_scans(guard, 1)
	TEST_ASSERT(stealth_ai.stealth_state() != "alert", "Test fixture: the whole set didn't hold with nothing carried")
	var/mob/living/carbon/human/npc/victim = stealth_guard(block, 12, 2)
	var/datum/ai_controller/basic_controller/human_npc/stealth/victim_ai = stealth_ai(victim)
	victim_ai.stealth_setup()
	victim.death()
	person.buckle_mob(victim, TRUE, TRUE, CARRIER_NEEDS_ARM)
	TEST_ASSERT(victim in person.buckled_mobs, "Test fixture: the body couldn't be carried")
	TEST_ASSERT_NULL(person.pulling, "Test fixture: the carrier still pulls the body")
	stealth_ai.next_body_scan = world.time + 1 MINUTES
	stealth_scans(guard, 1)
	TEST_ASSERT_EQUAL(stealth_ai.stealth_state(), "alert", "A guard watched one of its own carried off by someone in the whole set")
	TEST_ASSERT_EQUAL(stealth_ai.blackboard[BB_BASIC_MOB_CURRENT_TARGET], person, "The guard isn't after whoever carries the body")
	person.unbuckle_all_mobs(TRUE)
	qdel(guard)
	qdel(victim)
	qdel(person)
	qdel(block)

/// A guard net earpiece is never bound to a ship, so its calls stay on the site it is at.
/datum/unit_test/voidcrew_stealth_fix_radio_no_ship_bind

/datum/unit_test/voidcrew_stealth_fix_radio_no_ship_bind/Run()
	var/obj/item/radio/headset/guard_net/scav/earpiece = allocate(/obj/item/radio/headset/guard_net/scav, run_loc_floor_bottom_left)
	var/obj/item/radio/headset/plain = allocate(/obj/item/radio/headset, run_loc_floor_bottom_left)
	// Any datum stands in for the ship: the parent hands back whatever the ref resolves to.
	plain.comms_ship_ref = WEAKREF(plain)
	TEST_ASSERT_NOTNULL(plain.get_bound_comms_ship(), "Test fixture: a plain headset with a ship ref isn't bound")
	earpiece.comms_ship_ref = WEAKREF(plain)
	TEST_ASSERT_NULL(earpiece.get_bound_comms_ship(), "A guard net earpiece is bound to a ship")
	TEST_ASSERT_EQUAL(earpiece.get_comms_net(), earpiece.get_physical_comms_net(), "A guard net earpiece's calls don't go to where it is")
	plain.comms_ship_ref = null
	earpiece.comms_ship_ref = null

/// The admin guard summary says "ok" only for a radio the guard can call on.
/datum/unit_test/voidcrew_stealth_fix_radio_summary

/datum/unit_test/voidcrew_stealth_fix_radio_summary/Run()
	var/mob/living/carbon/human/npc/lookout = allocate(/mob/living/carbon/human/npc/ruin/trooper/scav/lookout, run_loc_floor_bottom_left)
	var/datum/ai_controller/basic_controller/human_npc/stealth/lookout_ai = lookout.ai_controller
	TEST_ASSERT(findtext(stealth_guard_hearing_summary(lookout, lookout_ai), "radio ok"), "A lookout with its own earpiece isn't shown as radio ok")
	lookout.dropItemToGround(lookout.ears)
	var/obj/item/radio/headset/plain = allocate(/obj/item/radio/headset)
	lookout.equip_to_slot_if_possible(plain, ITEM_SLOT_EARS)
	TEST_ASSERT_EQUAL(lookout.ears, plain, "Test fixture: a plain headset didn't go on")
	TEST_ASSERT(!findtext(stealth_guard_hearing_summary(lookout, lookout_ai), "radio ok"), "A plain headset shows as radio ok")

/// A level activator deleted some other way than the verb stops keeping that level's AI awake.
/datum/unit_test/voidcrew_stealth_fix_radio_stale_activator

/datum/unit_test/voidcrew_stealth_fix_radio_stale_activator/Run()
	var/mob/living/carbon/human/npc/lookout = allocate(/mob/living/carbon/human/npc/ruin/trooper/scav/lookout, run_loc_floor_bottom_left)
	var/datum/ai_controller/controller = lookout.ai_controller
	var/key = "[run_loc_floor_bottom_left.z]"
	TEST_ASSERT_NULL(GLOB.z_level_activator_dummies[key], "Test fixture: the test level is already forced active")
	var/mob/living/carbon/human/consistent/dummy = allocate(/mob/living/carbon/human/consistent, run_loc_floor_top_right)
	GLOB.z_level_activator_dummies[key] = dummy
	TEST_ASSERT(!controller.should_idle(), "A forced-active level let its AI idle")
	qdel(dummy)
	controller.should_idle()
	var/left = GLOB.z_level_activator_dummies[key]
	GLOB.z_level_activator_dummies -= key
	TEST_ASSERT_NULL(left, "A deleted level activator is still kept")
