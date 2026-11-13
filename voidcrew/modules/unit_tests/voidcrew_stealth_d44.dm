// Stealth guards, owner decision 44 (playtest 2: disguises and tracking). voidcrew/modules/stealth/stealth_disguise.dm,
// stealth_hearing.dm, stealth_noise.dm, stealth_radio.dm, stealth_ai.dm and stealth_closet.dm. Values from voidcrew/_DEFINES
// are written out: STEALTH_LOSE_TARGET_TIME 4 s, STEALTH_RADIO_CALL_TIME 3 s; a yellow guard's dark sight is 4 tiles, its
// close range 2, its challenge range for the whole set 2. Pieces: clothing 2, pass 4. States and the blackboard key
// BB_HUMAN_NPC_NEXT_SHOT ("human_npc_next_shot") are written as text.
// The tests down to voidcrew_stealth_d44_alert_dark call the scan directly; the voidcrew_stealth_live ones run the real AI.

#define STEALTH_TEST_GUNNER /mob/living/carbon/human/npc/ruin/trooper/scav/gunner
#define STEALTH_TEST_LOOKOUT /mob/living/carbon/human/npc/ruin/trooper/scav/lookout

/// Running in the whole set behind a guard is only footsteps: it turns, stops them, and running while stopped gives
/// them away.
/datum/unit_test/voidcrew_stealth_d44_run_disguised

/datum/unit_test/voidcrew_stealth_d44_run_disguised/Run()
	var/datum/turf_reservation/block = stealth_block(20, 5)
	TEST_ASSERT_NOTNULL(block, "No room for the test")
	var/mob/living/carbon/human/npc/guard = stealth_guard(block, 6, 2, WEST)
	var/datum/ai_controller/basic_controller/human_npc/stealth/guard_ai = stealth_ai(guard)
	var/mob/living/carbon/human/person = stealth_person(block, 10, 2)
	stealth_dress(person)
	person.equip_to_slot_or_del(new /obj/item/clothing/shoes/jackboots(person), ITEM_SLOT_FEET)
	stealth_scans(guard, 1)
	person.toggle_move_intent()
	person.forceMove(stealth_at(block, 8, 2))
	stealth_scans(guard, 1)
	TEST_ASSERT_EQUAL(guard_ai.last_heard?[1], "footsteps", "The guard didn't hear someone run up two tiles behind it")
	TEST_ASSERT(guard_ai.stealth_fooled(person), "Running behind a guard gave the disguise away by ear")
	TEST_ASSERT(!length(guard_ai.made), "The guard marked someone it only heard")
	TEST_ASSERT_EQUAL(guard_ai.stealth_state(), "suspicious", "Running two tiles behind a guard drew no look")
	TEST_ASSERT_EQUAL(guard.dir, EAST, "The guard didn't turn to the steps")
	TEST_ASSERT_NULL(guard_ai.blackboard[BB_BASIC_MOB_CURRENT_TARGET], "The guard went for someone it only heard")
	// The moment after the turn has passed: it sees them in its colours and stops them.
	guard_ai.turned_at = 0
	stealth_scans(guard, 1)
	TEST_ASSERT_EQUAL(guard_ai.challenge?.resolve(), person, "The guard didn't stop someone in its colours two tiles in front of it")
	TEST_ASSERT_NULL(guard_ai.blackboard[BB_BASIC_MOB_CURRENT_TARGET], "The guard went for someone it stopped")
	// Running off while stopped.
	person.forceMove(stealth_at(block, 9, 2))
	stealth_scans(guard, 1)
	TEST_ASSERT(!guard_ai.stealth_fooled(person), "Running off while stopped didn't give the disguise away")
	TEST_ASSERT(guard_ai.made?[REF(person)] > world.time, "The guard doesn't remember who ran off")
	TEST_ASSERT_EQUAL(guard_ai.stealth_state(), "alert", "The guard let someone run off from a stop")
	qdel(block)

/// Stripping a guard that is out cold is no touch: it learns nothing. A friend who sees it done still sees through
/// the disguise; one looking away doesn't. An awake guard being stripped turns on them.
/datum/unit_test/voidcrew_stealth_d44_strip

/datum/unit_test/voidcrew_stealth_d44_strip/Run()
	var/datum/turf_reservation/block = stealth_block(20, 5)
	TEST_ASSERT_NOTNULL(block, "No room for the test")
	var/mob/living/carbon/human/npc/watcher = stealth_guard(block, 6, 2)
	var/datum/ai_controller/basic_controller/human_npc/stealth/watcher_ai = stealth_ai(watcher)
	watcher_ai.stealth_setup()
	var/mob/living/carbon/human/npc/away = stealth_guard(block, 2, 2, WEST)
	var/datum/ai_controller/basic_controller/human_npc/stealth/away_ai = stealth_ai(away)
	away_ai.stealth_setup()
	var/mob/living/carbon/human/npc/victim = stealth_guard(block, 11, 2)
	var/datum/ai_controller/basic_controller/human_npc/stealth/victim_ai = stealth_ai(victim)
	victim_ai.stealth_setup()
	TEST_ASSERT_EQUAL(victim_ai.group, watcher_ai.group, "The guards aren't one group")
	var/mob/living/carbon/human/person = stealth_person(block, 10, 2)
	stealth_dress(person)
	victim.Unconscious(100 SECONDS)
	TEST_ASSERT(victim.stat != CONSCIOUS || HAS_TRAIT(victim, TRAIT_INCAPACITATED), "The guard isn't out cold")
	SEND_SIGNAL(victim, COMSIG_BEING_STRIPPED, person, victim.wear_id)
	TEST_ASSERT(!length(victim_ai.made), "A guard out cold learned who stripped it")
	TEST_ASSERT_NULL(victim_ai.blackboard[BB_BASIC_MOB_CURRENT_TARGET], "A guard out cold took a target")
	TEST_ASSERT_EQUAL(watcher_ai.stealth_state(), "alert", "A guard watched a friend being stripped and did nothing")
	TEST_ASSERT_EQUAL(watcher_ai.blackboard[BB_BASIC_MOB_CURRENT_TARGET], person, "The watching guard isn't after the one stripping")
	TEST_ASSERT(away_ai.stealth_fooled(person), "A guard looking away saw the stripping")
	qdel(watcher)
	qdel(victim)
	// Awake, it is a touch.
	var/mob/living/carbon/human/npc/awake = stealth_guard(block, 11, 3)
	var/datum/ai_controller/basic_controller/human_npc/stealth/awake_ai = stealth_ai(awake)
	awake_ai.stealth_setup()
	SEND_SIGNAL(awake, COMSIG_BEING_STRIPPED, person, awake.wear_id)
	TEST_ASSERT_EQUAL(awake_ai.stealth_state(), "alert", "An awake guard being stripped didn't turn on them")
	qdel(block)

/// The pass counts where a door would read it: in a hand, in a wallet or a PDA, on the belt. Not in a bag.
/datum/unit_test/voidcrew_stealth_d44_pass_places

/datum/unit_test/voidcrew_stealth_d44_pass_places/Run()
	var/datum/turf_reservation/block = stealth_block(3, 3)
	TEST_ASSERT_NOTNULL(block, "No room for the test")
	var/mob/living/carbon/human/person = stealth_person(block, 1, 1)
	stealth_dress(person, TRUE, FALSE, FALSE)
	TEST_ASSERT_EQUAL(stealth_disguise_of(person), 2, "The fatigues alone aren't the clothing piece")
	var/obj/item/card/id/advanced/black/scav/pass = new(person)
	TEST_ASSERT(person.put_in_hands(pass), "The pass wouldn't go in a hand")
	TEST_ASSERT_EQUAL(stealth_disguise_of(person), 6, "A pass held in a hand doesn't count")
	TEST_ASSERT(person.dropItemToGround(pass), "The pass wouldn't drop")
	TEST_ASSERT_EQUAL(stealth_disguise_of(person), 2, "A pass on the floor still counts")
	// In a wallet in the ID slot.
	var/obj/item/storage/wallet/wallet = new(person)
	pass.forceMove(wallet)
	TEST_ASSERT(person.equip_to_slot_if_possible(wallet, ITEM_SLOT_ID), "The wallet wouldn't go on")
	TEST_ASSERT_EQUAL(stealth_disguise_of(person), 6, "A pass in a wallet in the ID slot doesn't count")
	TEST_ASSERT(person.dropItemToGround(wallet), "The wallet wouldn't come off")
	// In a PDA on the belt.
	var/obj/item/modular_computer/pda/pda = new(person)
	pass.forceMove(person)
	pda.InsertID(pass, null)
	TEST_ASSERT_EQUAL(pda.computer_id_slot, pass, "The pass didn't go in the PDA")
	TEST_ASSERT(person.equip_to_slot_if_possible(pda, ITEM_SLOT_BELT), "The PDA wouldn't go on the belt")
	TEST_ASSERT_EQUAL(stealth_disguise_of(person), 6, "A pass in a PDA on the belt doesn't count")
	// Deep in a bag.
	var/obj/item/storage/backpack/bag = new(person)
	TEST_ASSERT(person.equip_to_slot_if_possible(bag, ITEM_SLOT_BACK), "The bag wouldn't go on")
	new /obj/item/card/id/advanced/black/scav(bag)
	TEST_ASSERT(person.dropItemToGround(pda), "The PDA wouldn't come off")
	TEST_ASSERT_EQUAL(stealth_disguise_of(person), 2, "A pass in a bag counts")
	qdel(block)

/// Alert, it keeps its target all round, in the light it can see by: lit, out to its sight; dark, within its dark
/// sight. Lost in the dark long enough, it searches where it last saw them.
/datum/unit_test/voidcrew_stealth_d44_alert_dark

/datum/unit_test/voidcrew_stealth_d44_alert_dark/Run()
	var/datum/turf_reservation/block = stealth_block(20, 5)
	TEST_ASSERT_NOTNULL(block, "No room for the test")
	var/mob/living/carbon/human/npc/guard = stealth_guard(block, 6, 2)
	var/datum/ai_controller/basic_controller/human_npc/stealth/guard_ai = stealth_ai(guard)
	var/mob/living/carbon/human/person = stealth_person(block, 9, 2)
	for(var/dx in 0 to 19)
		GLOB.stealth_test_dark_turfs[stealth_at(block, dx, 2)] = TRUE
	guard_ai.stealth_go_alert(person)
	// Three tiles off in the dark: within its dark sight.
	guard_ai.stealth_keep_target()
	TEST_ASSERT(!guard_ai.lost_since, "An alert guard lost someone three tiles off in the dark")
	// Three tiles behind it in the dark: all round.
	person.forceMove(stealth_at(block, 3, 2))
	guard_ai.stealth_keep_target()
	TEST_ASSERT(!guard_ai.lost_since, "An alert guard lost someone three tiles behind it")
	// Six tiles off in the dark: out of view.
	person.forceMove(stealth_at(block, 12, 2))
	TEST_ASSERT(!guard_ai.stealth_has_in_view(person), "An alert guard has someone six tiles off in the dark in view")
	guard_ai.stealth_keep_target()
	TEST_ASSERT(guard_ai.lost_since, "An alert guard kept someone six tiles off in the dark")
	// Lit there: back in view.
	GLOB.stealth_test_dark_turfs[stealth_at(block, 12, 2)] = FALSE
	guard_ai.stealth_keep_target()
	TEST_ASSERT(!guard_ai.lost_since, "An alert guard didn't see someone lit six tiles off")
	TEST_ASSERT_EQUAL(guard_ai.last_seen_turf, stealth_at(block, 12, 2), "The guard didn't note where it saw them")
	// Into the dark further on, and long enough: it searches where it last saw them, not where they are.
	person.forceMove(stealth_at(block, 14, 2))
	guard_ai.stealth_keep_target()
	TEST_ASSERT(guard_ai.lost_since, "An alert guard kept someone eight tiles off in the dark")
	guard_ai.stealth_rewind(5 SECONDS)
	guard_ai.stealth_keep_target()
	TEST_ASSERT_EQUAL(guard_ai.stealth_state(), "searching", "A guard that lost someone in the dark isn't searching")
	TEST_ASSERT_EQUAL(guard_ai.last_seen_turf, stealth_at(block, 12, 2), "The guard searches somewhere it never saw them")
	TEST_ASSERT_NULL(guard_ai.blackboard[BB_BASIC_MOB_CURRENT_TARGET], "The guard kept a target it lost")
	qdel(block)

/// A gunner, a lookout or a plain guard at (dx, dy) of the room, as guard_at() places one.
/datum/unit_test/voidcrew_stealth_live/proc/npc_at(npc_type, dx, dy, facing = EAST)
	var/mob/living/carbon/human/npc/guard = allocate(npc_type, at(dx, dy))
	guard.setDir(facing)
	guard.AddElement(/datum/element/forced_gravity, 1)
	return guard

/// The real AI: a lookout sees through a disguise. The friend in earshot of its shout is told, the friend on the radio
/// is told when the call goes out, and a wary friend neither reached knows nothing.
/datum/unit_test/voidcrew_stealth_live/d44_word

/datum/unit_test/voidcrew_stealth_live/d44_word/Run()
	TEST_ASSERT(make_room(30, 5), "No room for the test")
	allocate(/obj/effect/landmark/stealth_group, at(0, 4))
	for(var/dy in 0 to 4)
		var/turf/wall_spot = at(14, dy)
		wall_spot.ChangeTurf(/turf/closed/wall)
	var/mob/living/carbon/human/person = person_at(9, 2)
	stealth_dress(person)
	var/mob/living/carbon/human/npc/lookout = npc_at(STEALTH_TEST_LOOKOUT, 6, 2, EAST)
	var/mob/living/carbon/human/npc/near = guard_at(2, 2, WEST)
	var/mob/living/carbon/human/npc/far_radio = npc_at(STEALTH_TEST_LOOKOUT, 22, 2, EAST)
	var/mob/living/carbon/human/npc/far_plain = guard_at(26, 2, EAST)
	TEST_ASSERT(istype(lookout.ears, /obj/item/radio) && istype(far_radio.ears, /obj/item/radio), "A lookout has no earpiece")
	var/datum/ai_controller/basic_controller/human_npc/stealth/lookout_ai = wake(lookout)
	var/datum/ai_controller/basic_controller/human_npc/stealth/near_ai = wake(near)
	var/datum/ai_controller/basic_controller/human_npc/stealth/far_radio_ai = wake(far_radio)
	var/datum/ai_controller/basic_controller/human_npc/stealth/far_plain_ai = wake(far_plain)
	sleep(2 SECONDS)
	TEST_ASSERT(lookout_ai.group && lookout_ai.group == near_ai.group && lookout_ai.group == far_radio_ai.group && lookout_ai.group == far_plain_ai.group, "The four guards aren't one group")
	TEST_ASSERT(lookout_ai.stealth_fooled(person), "The lookout saw through the whole set before anything happened")
	far_radio_ai.stealth_set_wary()
	far_plain_ai.stealth_set_wary()
	var/key = REF(person)
	// A gun in hand gives it away.
	person.put_in_hands(new /obj/item/gun/ballistic/automatic/pistol(person))
	var/deadline = world.time + 10 SECONDS
	while(world.time < deadline && lookout_ai.stealth_state() != "alert")
		sleep(1)
	TEST_ASSERT_EQUAL(lookout_ai.stealth_state(), "alert", "The lookout never saw through someone in its colours holding a gun")
	TEST_ASSERT(lookout_ai.made?[key] > world.time, "The lookout doesn't remember who it saw through")
	TEST_ASSERT(near_ai.made?[key] > world.time, "The guard in earshot of the shout wasn't told who it was")
	TEST_ASSERT(!far_radio_ai.made?[key], "The guard on the radio knew before the call went out")
	TEST_ASSERT(!far_plain_ai.stealth_knows(person), "A wary guard nobody told knew the disguise")
	deadline = world.time + 10 SECONDS
	while(world.time < deadline && !far_radio_ai.made?[key])
		sleep(1)
	TEST_ASSERT(far_radio_ai.made?[key] > world.time, "The radio call didn't tell the guard on the radio who it was")
	TEST_ASSERT(!far_plain_ai.made?[key], "A wary guard neither the shout nor the radio reached knew the disguise")

/// The real AI: an alert gunner loses someone round a corner. It goes to where it last saw them, never toward where
/// they are now, and drops to a search there.
/datum/unit_test/voidcrew_stealth_live/d44_lost_corner

/datum/unit_test/voidcrew_stealth_live/d44_lost_corner/Run()
	TEST_ASSERT(make_room(16, 9), "No room for the test")
	// A wall up from the corner tile's west side, and one across the east part of the room: the far corner is
	// reached only round the gap at the east end, and seen from neither the guard's side nor the corner.
	for(var/dy in 2 to 8)
		var/turf/wall_spot = at(8, dy)
		wall_spot.ChangeTurf(/turf/closed/wall)
	for(var/dx in 9 to 13)
		var/turf/wall_spot = at(dx, 4)
		wall_spot.ChangeTurf(/turf/closed/wall)
	var/turf/corner = at(9, 1)
	var/mob/living/carbon/human/person = person_at(9, 1)
	var/mob/living/carbon/human/npc/guard = npc_at(STEALTH_TEST_GUNNER, 4, 1, EAST)
	var/datum/ai_controller/basic_controller/human_npc/stealth/guard_ai = wake(guard)
	guard_ai.stealth_go_alert(person)
	sleep(2 SECONDS)
	TEST_ASSERT_EQUAL(guard_ai.stealth_state(), "alert", "The guard isn't alert on someone in plain sight")
	TEST_ASSERT_EQUAL(guard_ai.last_seen_turf, corner, "The guard didn't note where it saw them")
	// Round the corner and away.
	person.forceMove(at(10, 7))
	TEST_ASSERT(!can_see(guard, person, 9), "The test's walls don't hide the far corner from the guard")
	var/chased = FALSE
	var/strayed = FALSE
	var/reached = FALSE
	// One plan to catch up: a walk at them from the moment before they moved isn't a chase.
	var/settled_at = world.time + 1 SECONDS
	var/deadline = world.time + 10 SECONDS
	while(world.time < deadline && guard_ai.stealth_state() == "alert")
		if(world.time >= settled_at && guard_ai.current_movement_target == person)
			chased = TRUE
		if(guard.x > corner.x + 2 || guard.y > corner.y + 2)
			strayed = TRUE
		if(get_dist(guard, corner) <= 1)
			reached = TRUE
		sleep(1)
	TEST_ASSERT(!chased, "A guard that lost someone round a corner walked at where they are now")
	TEST_ASSERT(!strayed, "A guard that lost someone round a corner went past where it last saw them")
	TEST_ASSERT(reached, "A guard that lost someone round a corner didn't go to where it last saw them (it is [get_dist(guard, corner)] tiles off)")
	TEST_ASSERT_EQUAL(guard_ai.stealth_state(), "searching", "A guard that lost someone round a corner isn't searching")
	TEST_ASSERT_EQUAL(guard_ai.last_seen_turf, corner, "The guard searches somewhere it never saw them")

/// The real AI: an alert gunner behind glass can't shoot someone unlit six tiles off, and loses them. Lit, it shoots.
/datum/unit_test/voidcrew_stealth_live/d44_dark_shot

/datum/unit_test/voidcrew_stealth_live/d44_dark_shot/Run()
	TEST_ASSERT(make_room(14, 5), "No room for the test")
	// A glass wall beside it: in sight, out of reach, so the guard can't walk up into its dark sight.
	for(var/dy in 0 to 4)
		allocate(/obj/structure/window/reinforced/fulltile, at(2, dy))
	var/list/dark_spots = list()
	for(var/dx in 3 to 13)
		for(var/dy in 0 to 4)
			var/turf/spot = at(dx, dy)
			GLOB.stealth_test_dark_turfs[spot] = TRUE
			dark_spots += spot
	var/mob/living/carbon/human/person = person_at(6, 2)
	var/mob/living/carbon/human/npc/guard = npc_at(STEALTH_TEST_GUNNER, 0, 2, EAST)
	var/datum/ai_controller/basic_controller/human_npc/stealth/guard_ai = wake(guard)
	guard_ai.stealth_go_alert(person)
	TEST_ASSERT_EQUAL(guard_ai.stealth_state(), "alert", "The guard didn't go alert")
	var/shot_in_dark = FALSE
	var/deadline = world.time + 7 SECONDS
	while(world.time < deadline)
		if(guard_ai.blackboard["human_npc_next_shot"])
			shot_in_dark = TRUE
		sleep(1)
	TEST_ASSERT(!shot_in_dark, "An alert guard shot at someone unlit six tiles off")
	TEST_ASSERT_EQUAL(guard_ai.stealth_state(), "searching", "An alert guard didn't lose someone unlit six tiles off")
	// The lights come on: it sees them and shoots.
	for(var/turf/spot as anything in dark_spots)
		GLOB.stealth_test_dark_turfs[spot] = FALSE
	deadline = world.time + 20 SECONDS
	while(world.time < deadline && !guard_ai.blackboard["human_npc_next_shot"])
		sleep(2)
	TEST_ASSERT(guard_ai.blackboard["human_npc_next_shot"], "The guard never shot at someone lit six tiles off (state [guard_ai.stealth_state()]): the test can't tell the dark from a guard that doesn't shoot")

#undef STEALTH_TEST_GUNNER
#undef STEALTH_TEST_LOOKOUT
