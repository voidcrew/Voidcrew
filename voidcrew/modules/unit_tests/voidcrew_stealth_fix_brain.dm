// Stealth guards: fixes to the guard brain (stealth_ai.dm, stealth_perception.dm, stealth_disguise.dm, stealth_turns.dm).
// Unit tests compile before voidcrew/_DEFINES, so values from there are written out: states "unaware", "suspicious",
// "alert", "searching"; STEALTH_GOTO_SEARCH "search"; STEALTH_CALL_NAME 4.

#define FIX_BRAIN_LOOKOUT /mob/living/carbon/human/npc/ruin/trooper/scav/lookout

/// Two guards walking into each other: no pass asked for, no alarm.
/datum/unit_test/voidcrew_stealth_live/fix_brain_friend_bump

/datum/unit_test/voidcrew_stealth_live/fix_brain_friend_bump/Run()
	TEST_ASSERT(make_room(8, 3), "No room for the test")
	var/mob/living/carbon/human/npc/guard = guard_at(1, 1, EAST)
	var/mob/living/carbon/human/npc/friend = guard_at(2, 1, WEST)
	// Someone on the level keeps the AI on, as a player does; far behind it.
	person_at(7, 2)
	var/datum/ai_controller/basic_controller/human_npc/stealth/stealth_ai = wake(guard)
	TEST_ASSERT(!stealth_ai.stealth_fooled(friend), "A guard takes a friend in the den's colours for a disguise")
	SEND_SIGNAL(guard, COMSIG_ATOM_BUMPED, friend)
	TEST_ASSERT_NULL(stealth_ai.challenge, "A guard asked a friend who walked into it for a pass")
	TEST_ASSERT_EQUAL(stealth_ai.stealth_state(), "unaware", "A friend walking into a guard set it off")
	TEST_ASSERT(!LAZYLEN(stealth_ai.made), "A guard marked a friend who walked into it")

/// Out cold, a guard feels nothing: dragged, hit, it doesn't wake up fighting whoever did it, or know their face.
/datum/unit_test/voidcrew_stealth_fix_brain_out_cold

/datum/unit_test/voidcrew_stealth_fix_brain_out_cold/Run()
	var/datum/turf_reservation/block = stealth_block(6, 3)
	TEST_ASSERT_NOTNULL(block, "No room for the test")
	var/mob/living/carbon/human/npc/guard = stealth_guard(block, 2, 1, EAST)
	var/datum/ai_controller/basic_controller/human_npc/stealth/stealth_ai = stealth_ai(guard)
	var/mob/living/carbon/human/person = stealth_person(block, 3, 1)
	guard.Unconscious(20 SECONDS)
	TEST_ASSERT_EQUAL(guard.stat, UNCONSCIOUS, "Test fixture: the guard isn't out cold")
	person.start_pulling(guard)
	SEND_SIGNAL(guard, COMSIG_ATOM_WAS_ATTACKED, person, ATTACKER_DAMAGING_ATTACK)
	TEST_ASSERT_NOTEQUAL(stealth_ai.stealth_state(), "alert", "A guard out cold went alert on whoever handled it")
	TEST_ASSERT_NULL(stealth_ai.blackboard[BB_BASIC_MOB_CURRENT_TARGET], "A guard out cold took a target")
	TEST_ASSERT(!LAZYLEN(stealth_ai.made), "A guard out cold learned the face of whoever handled it")
	qdel(block)

/// A guard hit by someone in a disguise that held, mask and all, knows them for what they are.
/datum/unit_test/voidcrew_stealth_fix_brain_masked_attacker

/datum/unit_test/voidcrew_stealth_fix_brain_masked_attacker/Run()
	var/datum/turf_reservation/block = stealth_block(6, 3)
	TEST_ASSERT_NOTNULL(block, "No room for the test")
	var/mob/living/carbon/human/npc/guard = stealth_guard(block, 1, 1, EAST)
	var/datum/ai_controller/basic_controller/human_npc/stealth/stealth_ai = stealth_ai(guard)
	var/mob/living/carbon/human/person = stealth_person(block, 3, 1)
	stealth_dress(person)
	TEST_ASSERT(stealth_ai.stealth_fooled(person), "Test fixture: the disguise doesn't hold")
	SEND_SIGNAL(guard, COMSIG_ATOM_WAS_ATTACKED, person, ATTACKER_DAMAGING_ATTACK)
	TEST_ASSERT_EQUAL(stealth_ai.stealth_state(), "alert", "A guard hit in plain view didn't go alert")
	TEST_ASSERT(!stealth_ai.stealth_fooled(person), "A guard hit by a masked, disguised attacker is still fooled by them")
	qdel(block)

/// Hit by someone it never got a look at, a guard's alarm names nobody; hit by someone it sees, it names them.
/datum/unit_test/voidcrew_stealth_fix_brain_unseen_name

/datum/unit_test/voidcrew_stealth_fix_brain_unseen_name/Run()
	var/datum/turf_reservation/block = stealth_block(10, 5)
	TEST_ASSERT_NOTNULL(block, "No room for the test")
	// Three tiles behind it, outside its close radius.
	var/mob/living/carbon/human/npc/lookout = allocate(FIX_BRAIN_LOOKOUT, stealth_at(block, 4, 1))
	lookout.setDir(EAST)
	var/datum/ai_controller/basic_controller/human_npc/stealth/lookout_ai = lookout.ai_controller
	lookout_ai.stealth_ready = TRUE
	var/mob/living/carbon/human/behind = stealth_person(block, 1, 1)
	SEND_SIGNAL(lookout, COMSIG_ATOM_WAS_ATTACKED, behind, ATTACKER_DAMAGING_ATTACK)
	TEST_ASSERT_EQUAL(lookout_ai.stealth_state(), "alert", "A lookout hit from behind didn't fight back")
	TEST_ASSERT_NOTNULL(lookout_ai.pending_call, "A lookout hit from behind didn't call it in")
	TEST_ASSERT_NULL(lookout_ai.pending_call[4], "A lookout named someone it never saw ([lookout_ai.pending_call[4]])")
	// In front of it, in the light.
	var/mob/living/carbon/human/npc/other = allocate(FIX_BRAIN_LOOKOUT, stealth_at(block, 4, 3))
	other.setDir(EAST)
	var/datum/ai_controller/basic_controller/human_npc/stealth/other_ai = other.ai_controller
	other_ai.stealth_ready = TRUE
	var/mob/living/carbon/human/seen = stealth_person(block, 7, 3)
	SEND_SIGNAL(other, COMSIG_ATOM_WAS_ATTACKED, seen, ATTACKER_DAMAGING_ATTACK)
	TEST_ASSERT_NOTNULL(other_ai.pending_call, "A lookout hit in plain view didn't call it in")
	TEST_ASSERT_EQUAL(other_ai.pending_call[4], seen.get_visible_name(add_id_name = FALSE), "A lookout didn't name someone it saw hit it")
	qdel(block)

/// Mice and other small animals are nobody a guard notices, by sight or by ear. A person still is.
/datum/unit_test/voidcrew_stealth_fix_brain_critters

/datum/unit_test/voidcrew_stealth_fix_brain_critters/Run()
	var/datum/turf_reservation/block = stealth_block(8, 3)
	TEST_ASSERT_NOTNULL(block, "No room for the test")
	var/mob/living/carbon/human/npc/guard = stealth_guard(block, 1, 1, EAST)
	var/datum/ai_controller/basic_controller/human_npc/stealth/stealth_ai = stealth_ai(guard)
	var/mob/living/basic/mouse/mouse = allocate(/mob/living/basic/mouse, stealth_at(block, 3, 1))
	TEST_ASSERT(stealth_is_critter(mouse), "A mouse isn't a critter")
	TEST_ASSERT(!(mouse in stealth_candidates(guard, 4)), "A mouse is someone a guard might notice")
	stealth_scans(guard, 5)
	TEST_ASSERT_EQUAL(stealth_ai.stealth_state(), "unaware", "A mouse in front of a guard set it off")
	TEST_ASSERT_NULL(stealth_ai.notice_map[REF(mouse)], "A guard noticed a mouse")
	var/mob/living/carbon/human/person = stealth_person(block, 5, 1)
	TEST_ASSERT(!stealth_is_critter(person), "A person is a critter")
	TEST_ASSERT(person in stealth_candidates(guard, 4), "A person isn't someone a guard might notice")
	qdel(block)

/// A friend on the floor from its own slip isn't a body; on the floor for any other reason it is.
/datum/unit_test/voidcrew_stealth_fix_brain_slipped_friend

/datum/unit_test/voidcrew_stealth_fix_brain_slipped_friend/Run()
	var/datum/turf_reservation/block = stealth_block(12, 5)
	TEST_ASSERT_NOTNULL(block, "No room for the test")
	allocate(/obj/effect/landmark/stealth_group, stealth_at(block, 6, 4))
	var/mob/living/carbon/human/npc/guard = stealth_guard(block, 2, 2)
	var/mob/living/carbon/human/npc/friend = stealth_guard(block, 5, 2)
	var/datum/ai_controller/basic_controller/human_npc/stealth/stealth_ai = stealth_ai(guard)
	var/datum/ai_controller/basic_controller/human_npc/stealth/friend_ai = stealth_ai(friend)
	stealth_ai.stealth_setup()
	friend_ai.stealth_setup()
	friend_ai.slip_down_until = world.time + 5 SECONDS
	friend.set_body_position(LYING_DOWN)
	stealth_scans(guard, 1)
	TEST_ASSERT_EQUAL(stealth_ai.stealth_state(), "unaware", "A guard took a friend down from a slip for a body")
	friend_ai.slip_down_until = 0
	stealth_ai.next_body_scan = 0
	stealth_scans(guard, 1)
	TEST_ASSERT_EQUAL(stealth_ai.stealth_state(), "suspicious", "A guard didn't react to a friend on the floor")
	qdel(block)

/// Health slipping away with nobody to blame sends a guard looking, but it shouts and radios nothing; a blow it feels does.
/datum/unit_test/voidcrew_stealth_fix_brain_bleeding_quiet

/datum/unit_test/voidcrew_stealth_fix_brain_bleeding_quiet/Run()
	var/datum/turf_reservation/block = stealth_block(5, 3)
	TEST_ASSERT_NOTNULL(block, "No room for the test")
	var/mob/living/carbon/human/npc/lookout = allocate(FIX_BRAIN_LOOKOUT, stealth_at(block, 2, 1))
	var/datum/ai_controller/basic_controller/human_npc/stealth/lookout_ai = lookout.ai_controller
	lookout_ai.stealth_ready = TRUE
	lookout_ai.stealth_check_health()
	lookout.adjustBruteLoss(15)
	lookout_ai.stealth_check_health()
	TEST_ASSERT(lookout_ai.harm_pending, "Test fixture: lost health wasn't noted")
	lookout_ai.stealth_judge_harm()
	TEST_ASSERT_EQUAL(lookout_ai.stealth_state(), "searching", "Health lost with nobody to blame didn't send a guard looking")
	TEST_ASSERT_NULL(lookout_ai.pending_call, "Health slipping away made a guard radio an alarm")
	// A blow it felt land, nobody named: that it calls in.
	lookout_ai.next_harm_at = 0
	lookout_ai.stealth_note_harm()
	lookout_ai.stealth_judge_harm()
	TEST_ASSERT_NOTNULL(lookout_ai.pending_call, "A blow from nowhere didn't make a guard radio an alarm")
	qdel(block)

/// The lean before a turn goes through tg's offsets: anything else moving the body during the tell can't leave it off.
/datum/unit_test/voidcrew_stealth_fix_brain_lean_offsets

/datum/unit_test/voidcrew_stealth_fix_brain_lean_offsets/Run()
	var/datum/turf_reservation/block = stealth_block(5, 5)
	TEST_ASSERT_NOTNULL(block, "No room for the test")
	var/mob/living/carbon/human/npc/guard = stealth_guard(block, 2, 2, EAST)
	var/datum/ai_controller/basic_controller/human_npc/stealth/stealth_ai = stealth_ai(guard)
	stealth_ai.stealth_setup()
	var/start_w = guard.pixel_w
	var/start_z = guard.pixel_z
	stealth_ai.stealth_turn_to(NORTH)
	TEST_ASSERT_EQUAL(guard.pixel_z, start_z + 3, "The tell shows no lean")
	// A grab's offsets, say, landing during the tell.
	guard.add_offsets("fix_brain_test", w_add = 0, animate = FALSE)
	TEST_ASSERT_EQUAL(guard.pixel_z, start_z + 3, "Another offset wiped the lean")
	stealth_ai.stealth_drop_turn()
	TEST_ASSERT_EQUAL(guard.pixel_w, start_w, "The lean left the body off to the side")
	TEST_ASSERT_EQUAL(guard.pixel_z, start_z, "The lean left the body off its spot")
	guard.remove_offsets("fix_brain_test", animate = FALSE)
	qdel(block)

/// Alert and walking to where it lost them, a guard pathfinds; when the walk ends it chases as before.
/datum/unit_test/voidcrew_stealth_fix_brain_chase_path

/datum/unit_test/voidcrew_stealth_fix_brain_chase_path/Run()
	var/datum/turf_reservation/block = stealth_block(8, 3)
	TEST_ASSERT_NOTNULL(block, "No room for the test")
	var/mob/living/carbon/human/npc/guard = stealth_guard(block, 1, 1, EAST)
	var/datum/ai_controller/basic_controller/human_npc/stealth/stealth_ai = stealth_ai(guard)
	var/mob/living/carbon/human/person = stealth_person(block, 3, 1)
	stealth_ai.stealth_go_alert(person)
	TEST_ASSERT(istype(stealth_ai.ai_movement, /datum/ai_movement/basic_avoidance), "Test fixture: an alert guard doesn't chase straight")
	stealth_ai.stealth_walk(stealth_at(block, 6, 1), "search")
	TEST_ASSERT(istype(stealth_ai.ai_movement, /datum/ai_movement/jps), "An alert guard walking to where it lost them doesn't pathfind")
	stealth_ai.stealth_drop_walk()
	TEST_ASSERT(istype(stealth_ai.ai_movement, /datum/ai_movement/basic_avoidance), "An alert guard kept pathfinding after its walk")
	qdel(block)

/// Elbow to elbow on a diagonal: seen past one wall corner, not through a crack where two walls touch.
/datum/unit_test/voidcrew_stealth_fix_brain_diagonal_sight

/datum/unit_test/voidcrew_stealth_fix_brain_diagonal_sight/Run()
	var/datum/turf_reservation/block = stealth_block(4, 4)
	TEST_ASSERT_NOTNULL(block, "No room for the test")
	var/turf/from = stealth_at(block, 1, 1)
	var/turf/dest = stealth_at(block, 2, 2)
	var/turf/side_a = stealth_at(block, 2, 1)
	var/turf/side_b = stealth_at(block, 1, 2)
	TEST_ASSERT(stealth_can_see(from, dest, 7), "An open diagonal neighbour is out of sight")
	side_a.ChangeTurf(/turf/closed/wall)
	TEST_ASSERT(stealth_can_see(from, dest, 7), "A diagonal neighbour past one wall corner is out of sight")
	side_b.ChangeTurf(/turf/closed/wall)
	TEST_ASSERT(!stealth_can_see(from, dest, 7), "A diagonal neighbour is seen through a crack where two walls touch")
	TEST_ASSERT(!stealth_can_see(dest, from, 7), "Sight through a crack isn't the same both ways")
	TEST_ASSERT(stealth_can_see(from, side_a, 7), "A wall beside it is out of sight")
	qdel(block)

/// Someone holding one of its own up in front of them, in the light: an alert at once out to its alert range, not past it.
/datum/unit_test/voidcrew_stealth_fix_brain_hostage_sight

/datum/unit_test/voidcrew_stealth_fix_brain_hostage_sight/Run()
	var/datum/turf_reservation/block = stealth_block(10, 3)
	TEST_ASSERT_NOTNULL(block, "No room for the test")
	var/mob/living/carbon/human/npc/guard = stealth_guard(block, 1, 1, EAST)
	var/datum/ai_controller/basic_controller/human_npc/stealth/stealth_ai = stealth_ai(guard)
	var/mob/living/carbon/human/npc/friend = stealth_guard(block, 5, 1, EAST)
	var/mob/living/carbon/human/holder = stealth_person(block, 6, 1)
	var/obj/item/gun/ballistic/automatic/pistol/pistol = allocate(/obj/item/gun/ballistic/automatic/pistol)
	holder.put_in_active_hand(pistol, forced = TRUE)
	holder.setDir(WEST)
	stealth_test_grab(holder, friend, GRAB_NECK)
	TEST_ASSERT_EQUAL(stealth_hostage_of(holder), friend, "Test fixture: no hostage")
	stealth_scans(guard, 1)
	TEST_ASSERT_EQUAL(stealth_ai.stealth_state(), "alert", "A guard didn't go alert at once on someone holding a friend up in the light")
	qdel(block)
	// Past its alert range: noticed, not an alert.
	block = stealth_block(14, 3)
	TEST_ASSERT_NOTNULL(block, "No room for the test")
	var/mob/living/carbon/human/npc/far_guard = stealth_guard(block, 1, 1, EAST)
	var/datum/ai_controller/basic_controller/human_npc/stealth/far_ai = stealth_ai(far_guard)
	var/mob/living/carbon/human/npc/far_friend = stealth_guard(block, 8, 1, EAST)
	var/mob/living/carbon/human/far_holder = stealth_person(block, 9, 1)
	var/obj/item/gun/ballistic/automatic/pistol/far_pistol = allocate(/obj/item/gun/ballistic/automatic/pistol)
	far_holder.put_in_active_hand(far_pistol, forced = TRUE)
	far_holder.setDir(WEST)
	stealth_test_grab(far_holder, far_friend, GRAB_NECK)
	stealth_scans(far_guard, 1)
	TEST_ASSERT_NOTEQUAL(far_ai.stealth_state(), "alert", "A guard went alert on a hostage past its alert range")
	qdel(block)

#undef FIX_BRAIN_LOOKOUT
