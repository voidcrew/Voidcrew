// Hostages (step 5, voidcrew/modules/stealth/stealth_hostage.dm and stealth_hostage_pose.dm). Unit tests compile
// before voidcrew/_DEFINES, so values are written out: state "alert".

/// `holder` holds `victim` at `wanted` grab state through tg's own grab.
/datum/unit_test/proc/stealth_test_grab(mob/living/carbon/human/holder, mob/living/victim, wanted)
	holder.start_pulling(victim, supress_message = TRUE)
	var/tries = 0
	while(holder.pulling == victim && holder.grab_state < wanted && tries++ < 3)
		victim.grippedby(holder, instant = TRUE)
	TEST_ASSERT_EQUAL(holder.grab_state, wanted, "Test fixture: couldn't get the grab")

/// Hostages: a guard alert on someone holding one of its own holds fire and stands off; demands work once each;
/// hurting the hostage ends the deal; a stranger held up is no reason to hold fire.
/datum/unit_test/voidcrew_stealth_hostage

/datum/unit_test/voidcrew_stealth_hostage/Run()
	var/datum/turf_reservation/block = stealth_block(10, 5)
	TEST_ASSERT_NOTNULL(block, "No room for the test")
	var/mob/living/carbon/human/npc/guard = stealth_guard(block, 8, 2, WEST)
	var/datum/ai_controller/basic_controller/human_npc/stealth/stealth_ai = stealth_ai(guard)
	var/datum/ai_planning_subtree/stealth_hostage/subtree = GLOB.ai_subtrees[/datum/ai_planning_subtree/stealth_hostage]
	var/at = stealth_ai.planning_subtrees.Find(subtree)
	TEST_ASSERT(at, "The hostage subtree isn't in the guard's planning")
	TEST_ASSERT(at < stealth_ai.planning_subtrees.Find(GLOB.ai_subtrees[/datum/ai_planning_subtree/human_npc_shoot]), "The hostage subtree comes after shooting")
	var/mob/living/carbon/human/npc/friend = stealth_guard(block, 3, 2, WEST)
	var/mob/living/carbon/human/holder = stealth_person(block, 2, 2)
	var/obj/item/gun/ballistic/automatic/pistol/pistol = allocate(/obj/item/gun/ballistic/automatic/pistol)
	pistol.can_misfire = FALSE
	holder.put_in_active_hand(pistol, forced = TRUE)
	holder.setDir(EAST)
	stealth_test_grab(holder, friend, GRAB_NECK)
	TEST_ASSERT_EQUAL(stealth_hostage_of(holder), friend, "A neck grab with a gun isn't a hostage")
	stealth_ai.stealth_go_alert(holder)
	TEST_ASSERT_EQUAL(subtree.SelectBehaviors(stealth_ai, 1), SUBTREE_RETURN_FINISH_PLANNING, "The guard didn't hold fire")
	TEST_ASSERT_EQUAL(stealth_ai.standoff_holder?.resolve(), holder, "No standoff")
	// Demands, once each.
	var/obj/item/held_weapon = guard.get_active_held_item() || guard.get_inactive_held_item()
	holder.say("Back off!")
	TEST_ASSERT(stealth_ai.standoff_backed_off, "Told to back off, it didn't")
	holder.say("Drop the gun!")
	TEST_ASSERT(stealth_ai.standoff_dropped, "Told to drop it, it didn't")
	if(held_weapon)
		TEST_ASSERT(!(held_weapon in guard.held_items), "Told to drop it, it kept its weapon")
	// Hurting the hostage ends the deal for good.
	pistol.fire_gun(friend, holder, TRUE, null)
	TEST_ASSERT_NULL(stealth_ai.standoff_holder, "The standoff outlived a shot into the hostage")
	TEST_ASSERT(LAZYFIND(stealth_ai.no_deals, REF(holder)), "No grudge after the hostage was shot")
	TEST_ASSERT(isnull(subtree.SelectBehaviors(stealth_ai, 1)), "Stood off again against someone who shot a hostage")
	// A stranger held up is no reason to hold fire.
	var/mob/living/carbon/human/npc/guard2 = stealth_guard(block, 8, 4, WEST)
	var/datum/ai_controller/basic_controller/human_npc/stealth/stealth_ai2 = stealth_ai(guard2)
	var/mob/living/carbon/human/stranger = stealth_person(block, 3, 4)
	var/mob/living/carbon/human/holder2 = stealth_person(block, 2, 4)
	var/obj/item/gun/ballistic/automatic/pistol/pistol2 = allocate(/obj/item/gun/ballistic/automatic/pistol)
	holder2.put_in_active_hand(pistol2, forced = TRUE)
	stealth_test_grab(holder2, stranger, GRAB_NECK)
	stealth_ai2.stealth_go_alert(holder2)
	TEST_ASSERT(isnull(subtree.SelectBehaviors(stealth_ai2, 1)), "A guard held fire for a stranger")
	qdel(block)

/// The hold at gunpoint is drawn: the hostage is posed in front of the holder, on its feet, facing his way, and goes
/// back to tg's own grab when the gun is put away and to nothing once let go.
/datum/unit_test/voidcrew_stealth_hostage_pose

/datum/unit_test/voidcrew_stealth_hostage_pose/Run()
	var/datum/turf_reservation/block = stealth_block(9, 5)
	TEST_ASSERT_NOTNULL(block, "No room for the test")
	var/mob/living/carbon/human/holder = stealth_person(block, 4, 2)
	var/mob/living/carbon/human/hostage = stealth_person(block, 5, 2)
	var/obj/item/gun/ballistic/automatic/pistol/pistol = allocate(/obj/item/gun/ballistic/automatic/pistol)
	holder.put_in_active_hand(pistol, forced = TRUE)
	holder.setDir(EAST)
	stealth_test_grab(holder, hostage, GRAB_NECK)
	holder.setDir(EAST)
	TEST_ASSERT_EQUAL(stealth_hostage_of(holder), hostage, "A neck grab with a gun isn't a hostage")
	TEST_ASSERT_EQUAL(hostage.hostage_pose_dir, EAST, "The hostage isn't posed for the holder's facing")
	TEST_ASSERT_EQUAL(hostage.dir, EAST, "The hostage doesn't face the holder's way")
	TEST_ASSERT_EQUAL(hostage.body_position, STANDING_UP, "The hostage isn't held on its feet")
	holder.setDir(NORTH)
	TEST_ASSERT_EQUAL(hostage.hostage_pose_dir, NORTH, "The pose didn't follow the holder's turn")
	// The gun put away: tg's own grab again.
	holder.dropItemToGround(pistol, force = TRUE)
	TEST_ASSERT_NULL(stealth_hostage_of(holder), "Still a hostage with no gun out")
	TEST_ASSERT_EQUAL(hostage.hostage_pose_dir, 0, "Still posed with no gun out")
	holder.put_in_active_hand(pistol, forced = TRUE)
	TEST_ASSERT_EQUAL(hostage.hostage_pose_dir, holder.dir, "Not posed again when the gun came back out")
	holder.stop_pulling()
	TEST_ASSERT_EQUAL(hostage.hostage_pose_dir, 0, "Still posed after being let go")
	qdel(block)

/// Shooting your own hostage in the head or mouth (a player holding a player, tg's neck grab with a gun): the execution,
/// with its wind-up, the same in combat mode and out of it.
/datum/unit_test/voidcrew_stealth_hostage_execution

/datum/unit_test/voidcrew_stealth_hostage_execution/Run()
	var/datum/turf_reservation/block = stealth_block(6, 9)
	TEST_ASSERT_NOTNULL(block, "No room for the test")
	var/row = 1
	for(var/combat in list(FALSE, TRUE))
		for(var/zone in list(BODY_ZONE_HEAD, BODY_ZONE_PRECISE_MOUTH))
			var/mob/living/carbon/human/holder = stealth_person(block, 2, row)
			var/mob/living/carbon/human/hostage = stealth_person(block, 3, row)
			row += 2
			ADD_TRAIT(hostage, TRAIT_PIERCEIMMUNE, INNATE_TRAIT) // no stray shrapnel
			var/obj/item/gun/ballistic/automatic/pistol/pistol = allocate(/obj/item/gun/ballistic/automatic/pistol)
			pistol.can_misfire = FALSE
			pistol.chambered.loaded_projectile.damage = 20 // doubled at the muzzle: 40, under the burst line
			holder.put_in_active_hand(pistol, forced = TRUE)
			holder.set_combat_mode(combat)
			holder.setDir(EAST)
			stealth_test_grab(holder, hostage, GRAB_NECK)
			TEST_ASSERT_EQUAL(stealth_held_in_front(holder), hostage, "Test fixture: the hostage isn't held in front")
			TEST_ASSERT(pistol.hv_execution_possible(holder, hostage), "Your own hostage can't be executed (combat mode [combat])")
			holder.zone_selected = zone
			var/obj/item/bodypart/head/head = hostage.get_bodypart(BODY_ZONE_HEAD)
			var/started = world.time
			TEST_ASSERT(pistol.melee_attack_chain(holder, hostage, list()), "The click on your own hostage didn't end the attack chain ([zone], combat mode [combat])")
			TEST_ASSERT(world.time - started >= 1 SECONDS, "Your own hostage was shot with no wind-up ([zone], combat mode [combat])")
			TEST_ASSERT(world.time - started < 10 SECONDS, "Your own hostage got tg's slow mouth shot ([zone], combat mode [combat])")
			TEST_ASSERT(head.brute_dam > 0, "The execution of your own hostage didn't fire ([zone], combat mode [combat])")
			holder.stop_pulling()
	qdel(block)

/// The hostage's voice: under the hand he mumbles (garbled, heard close by) and stops once let go; held at gunpoint in an
/// ordinary neck grab he says a scared line now and then, and no guard's awareness changes for it.
/datum/unit_test/voidcrew_stealth_hostage_voice

/datum/unit_test/voidcrew_stealth_hostage_voice/Run()
	var/datum/turf_reservation/block = stealth_block(9, 5)
	TEST_ASSERT_NOTNULL(block, "No room for the test")
	var/muffled = stealth_muffle_words("Help me!")
	var/regex/shape = regex(@"^Mm*f m+f!$")
	TEST_ASSERT(shape.Find(muffled), "A muffled line came out as \"[muffled]\"")

	// Under the hand.
	var/mob/living/carbon/human/npc/guard = d45_bare_guard(block, 4, 1)
	var/mob/living/carbon/human/person = stealth_person(block, 3, 1)
	var/datum/stealth_grip/grip = grip_clamp(person, guard)
	TEST_ASSERT_NOTNULL(guard.stealth_hostage_voice_timer, "A guard with a hand over his mouth has no voice beat")
	TEST_ASSERT_EQUAL(guard.stealth_hostage_sound(person), "mumble", "A guard with a hand over his mouth made no mumble")
	TEST_ASSERT(HAS_TRAIT_FROM(guard, TRAIT_MUTE, "stealth_grip"), "The mumble took the mute off")
	var/obj/item/gun/ballistic/automatic/pistol/pistol = allocate(/obj/item/gun/ballistic/automatic/pistol)
	person.put_in_inactive_hand(pistol, forced = TRUE)
	TEST_ASSERT_EQUAL(guard.stealth_hostage_sound(person), "mumble", "Under the hand with a gun on him, he didn't mumble (or he spoke)")
	person.stop_pulling()
	TEST_ASSERT(QDELETED(grip), "Test fixture: letting go didn't end the hold")
	TEST_ASSERT_NULL(guard.stealth_hostage_sound(person), "Let go, he still mumbles")
	if(guard.stealth_hostage_voice_timer)
		deltimer(guard.stealth_hostage_voice_timer)
		guard.stealth_hostage_voice_timer = null
	guard.stealth_hostage_voice_tick()
	TEST_ASSERT_NULL(guard.stealth_hostage_voice_timer, "Let go, his voice beat kept going")

	// At gunpoint, an ordinary neck grab: a scared line, once in a while; the guards' awareness doesn't move for it.
	var/mob/living/carbon/human/npc/hostage = stealth_guard(block, 3, 3, WEST)
	var/mob/living/carbon/human/npc/watcher = stealth_guard(block, 7, 3, WEST)
	var/datum/ai_controller/basic_controller/human_npc/stealth/watcher_ai = stealth_ai(watcher)
	var/datum/ai_controller/basic_controller/human_npc/stealth/hostage_ai = stealth_ai(hostage)
	var/mob/living/carbon/human/holder = stealth_person(block, 2, 3)
	var/obj/item/gun/ballistic/automatic/pistol/second = allocate(/obj/item/gun/ballistic/automatic/pistol)
	holder.put_in_active_hand(second, forced = TRUE)
	holder.setDir(EAST)
	stealth_test_grab(holder, hostage, GRAB_NECK)
	TEST_ASSERT_EQUAL(stealth_hostage_of(holder), hostage, "Test fixture: no hostage")
	TEST_ASSERT(!stealth_grip_holds(holder, hostage), "Test fixture: an ordinary neck grab is a hand over the mouth")
	var/watcher_state = watcher_ai.stealth_state()
	var/hostage_state = hostage_ai.stealth_state()
	TEST_ASSERT_EQUAL(hostage.stealth_hostage_sound(holder), "plea", "A hostage at gunpoint said nothing")
	TEST_ASSERT_NULL(hostage.stealth_hostage_sound(holder), "A hostage at gunpoint pleaded twice in a row")
	TEST_ASSERT_EQUAL(watcher_ai.stealth_state(), watcher_state, "A hostage's scared line changed a guard's awareness")
	TEST_ASSERT_EQUAL(hostage_ai.stealth_state(), hostage_state, "His own scared line changed the hostage's awareness")
	TEST_ASSERT_NULL(watcher_ai.pending_call, "A hostage's scared line started a radio call")
	// Can't talk: nothing.
	hostage.stealth_hostage_next_plea = 0
	ADD_TRAIT(hostage, TRAIT_MUTE, TRAIT_SOURCE_UNIT_TESTS)
	TEST_ASSERT_NULL(hostage.stealth_hostage_sound(holder), "A hostage who can't talk pleaded")
	REMOVE_TRAIT(hostage, TRAIT_MUTE, TRAIT_SOURCE_UNIT_TESTS)
	holder.stop_pulling()
	TEST_ASSERT_NULL(hostage.stealth_hostage_sound(holder), "Let go, he still pleads")
	qdel(block)

/// `held` is still held up in front of `holder` (`label` says after what): on his tile, tg's neck grab, drawn in front
/// for his facing; with `guard_ai`, still a hostage the guard stands off for. TRUE if so.
/datum/unit_test/proc/stealth_test_check_held(mob/living/carbon/human/holder, mob/living/held, datum/ai_controller/basic_controller/human_npc/stealth/guard_ai, label)
	TEST_ASSERT_EQUAL(holder.pulling, held, "[label]: no longer held")
	TEST_ASSERT(holder.grab_state == GRAB_NECK, "[label]: the grab isn't tg's neck grab (state [holder.grab_state])")
	TEST_ASSERT_EQUAL(held.loc, holder.loc, "[label]: the held body isn't on the holder's tile (at [held.x],[held.y], holder at [holder.x],[holder.y])")
	TEST_ASSERT_EQUAL(stealth_held_in_front(holder), held, "[label]: not held in front")
	TEST_ASSERT_EQUAL(held.hostage_pose_dir, holder.dir, "[label]: not posed for the holder's facing ([dir2text(holder.dir)])")
	var/list/want = hostage_pose_offset(holder.dir, holder.hostage_pose_hand())
	var/list/got = held.hostage_pose_real(GRABBING_TRAIT)
	TEST_ASSERT(got[1] == want[1] && got[2] == want[2] && got[3] == want[3], "[label]: drawn at [got.Join(",")], not in front at [want.Join(",")]")
	if(guard_ai)
		var/datum/ai_planning_subtree/stealth_hostage/subtree = GLOB.ai_subtrees[/datum/ai_planning_subtree/stealth_hostage]
		TEST_ASSERT_EQUAL(stealth_hostage_of(holder), held, "[label]: no longer a hostage")
		TEST_ASSERT_EQUAL(subtree.SelectBehaviors(guard_ai, 1), SUBTREE_RETURN_FINISH_PLANNING, "[label]: the guard stopped standing off")
	return TRUE

/// Walks `holder` (on block tile (sx, sy)) round a square, two steps each way (north, east, south, west, so he turns
/// every leg), past crates on the tiles diagonal to where each leg starts, then once diagonally past a crate on one
/// leg of that step. After every step `held` is still held up in front (stealth_test_check_held()).
/datum/unit_test/proc/stealth_test_walk_held(datum/turf_reservation/block, sx, sy, mob/living/carbon/human/holder, mob/living/held, datum/ai_controller/basic_controller/human_npc/stealth/guard_ai)
	var/list/crates = list()
	for(var/list/spot in list(list(1, 1), list(-1, 1), list(1, 3), list(3, 1), list(1, -1), list(0, -1)))
		crates += allocate(/obj/structure/closet/crate, stealth_at(block, sx + spot[1], sy + spot[2]))
	var/list/steps = list(NORTH, NORTH, EAST, EAST, SOUTH, SOUTH, WEST, WEST, SOUTHWEST)
	for(var/i in 1 to length(steps))
		var/step_dir = steps[i]
		var/turf/from = holder.loc
		holder.Move(get_step(holder, step_dir), step_dir)
		var/label = "step [i] ([dir2text(step_dir)]) from [from.x],[from.y] to [holder.x],[holder.y]"
		TEST_ASSERT(holder.loc != from, "Test fixture: [label]: the holder didn't move")
		if(!stealth_test_check_held(holder, held, guard_ai, label))
			return FALSE
	QDEL_LIST(crates)
	return TRUE

/// Where the walk ended, the crates gone: a click on each tile round the holder (tg's Move_Pulled(), as a click on a
/// turf calls it), then the body pushed onto the next tile (its own Move(), as a shove moves it) and the holder stepping
/// on, sideways and then away from it. After each, `held` is still held up in front (stealth_test_check_held()).
/datum/unit_test/proc/stealth_test_shove_held(mob/living/carbon/human/holder, mob/living/held, datum/ai_controller/basic_controller/human_npc/stealth/guard_ai)
	// the test block has no gravity, and tg's Move_Pulled() only pushes with a foothold (Process_Spacemove())
	ADD_TRAIT(holder, TRAIT_SPACEWALK, TRAIT_SOURCE_UNIT_TESTS)
	TEST_ASSERT(holder.Process_Spacemove(NORTH), "Test fixture: no foothold to push the body from")
	for(var/click_dir in GLOB.alldirs)
		holder.Move_Pulled(get_step(holder, click_dir))
		if(!stealth_test_check_held(holder, held, guard_ai, "clicked the tile [dir2text(click_dir)]"))
			REMOVE_TRAIT(holder, TRAIT_SPACEWALK, TRAIT_SOURCE_UNIT_TESTS)
			return FALSE
	REMOVE_TRAIT(holder, TRAIT_SPACEWALK, TRAIT_SOURCE_UNIT_TESTS)
	// pushed one tile west, the holder steps north: back onto his tile from the diagonal
	held.Move(get_step(holder, WEST), WEST)
	TEST_ASSERT(held.loc != holder.loc, "Test fixture: the push west didn't move the body")
	holder.Move(get_step(holder, NORTH), NORTH)
	if(!stealth_test_check_held(holder, held, guard_ai, "pushed west, then a step north"))
		return FALSE
	// pushed one tile south, the holder steps north, away: tg drags it a tile, then back onto his
	held.Move(get_step(holder, SOUTH), SOUTH)
	TEST_ASSERT(held.loc != holder.loc, "Test fixture: the push south didn't move the body")
	holder.Move(get_step(holder, NORTH), NORTH)
	if(!stealth_test_check_held(holder, held, guard_ai, "pushed south, then a step north"))
		return FALSE
	return TRUE

/// A grab click (ctrl-click) on the body held up in front, a gun in the grabbing hand: nothing changes.
/datum/unit_test/proc/stealth_test_regrab_held(mob/living/carbon/human/holder, mob/living/held, datum/ai_controller/basic_controller/human_npc/stealth/guard_ai)
	TEST_ASSERT(isgun(holder.get_active_held_item()), "Test fixture: no gun in the grabbing hand")
	holder.grab(held)
	return stealth_test_check_held(holder, held, guard_ai, "a grab click with the gun in hand")

/// Walking with a hostage at gunpoint: he stays on the holder's tile, held in front and drawn there, and the guard
/// keeps standing off, every step, turning and passing crates on the diagonals; the same after clicking tiles, being
/// pushed off the tile, and a grab click with the gun in hand.
/datum/unit_test/voidcrew_stealth_hostage_walk

/datum/unit_test/voidcrew_stealth_hostage_walk/Run()
	var/datum/turf_reservation/block = stealth_block(11, 11)
	TEST_ASSERT_NOTNULL(block, "No room for the test")
	var/mob/living/carbon/human/npc/guard = stealth_guard(block, 9, 9, WEST)
	var/datum/ai_controller/basic_controller/human_npc/stealth/guard_ai = stealth_ai(guard)
	var/mob/living/carbon/human/npc/friend = stealth_guard(block, 4, 3, WEST)
	var/mob/living/carbon/human/holder = stealth_person(block, 3, 3)
	var/obj/item/gun/ballistic/automatic/pistol/pistol = allocate(/obj/item/gun/ballistic/automatic/pistol)
	pistol.can_misfire = FALSE
	holder.put_in_active_hand(pistol, forced = TRUE)
	holder.setDir(EAST)
	stealth_test_grab(holder, friend, GRAB_NECK)
	TEST_ASSERT_EQUAL(stealth_hostage_of(holder), friend, "Test fixture: a neck grab with a gun isn't a hostage")
	guard_ai.stealth_go_alert(holder)
	var/datum/ai_planning_subtree/stealth_hostage/subtree = GLOB.ai_subtrees[/datum/ai_planning_subtree/stealth_hostage]
	TEST_ASSERT_EQUAL(subtree.SelectBehaviors(guard_ai, 1), SUBTREE_RETURN_FINISH_PLANNING, "Test fixture: the guard didn't stand off")
	stealth_test_walk_held(block, 3, 3, holder, friend, guard_ai)
	stealth_test_shove_held(holder, friend, guard_ai)
	stealth_test_regrab_held(holder, friend, guard_ai)
	qdel(block)

/// The same with a hand over a guard's mouth, and the grab click once a gun is out in that hand.
/datum/unit_test/voidcrew_stealth_grip_walk

/datum/unit_test/voidcrew_stealth_grip_walk/Run()
	var/datum/turf_reservation/block = stealth_block(11, 11)
	TEST_ASSERT_NOTNULL(block, "No room for the test")
	var/mob/living/carbon/human/npc/guard = d45_bare_guard(block, 4, 3)
	var/mob/living/carbon/human/holder = stealth_person(block, 3, 3)
	holder.setDir(EAST)
	grip_clamp(holder, guard)
	TEST_ASSERT_EQUAL(guard.loc, holder.loc, "Test fixture: the held guard isn't on the holder's tile")
	stealth_test_walk_held(block, 3, 3, holder, guard)
	stealth_test_shove_held(holder, guard)
	var/obj/item/gun/ballistic/automatic/pistol/pistol = allocate(/obj/item/gun/ballistic/automatic/pistol)
	holder.put_in_active_hand(pistol, forced = TRUE)
	stealth_test_regrab_held(holder, guard)
	qdel(block)

/// A standoff with `guard` against `holder` holding `hostage` at gunpoint (pistol in the active hand), started.
/datum/unit_test/proc/stealth_test_standoff(mob/living/carbon/human/npc/guard, mob/living/carbon/human/holder, mob/living/carbon/human/hostage)
	var/datum/ai_controller/basic_controller/human_npc/stealth/guard_ai = stealth_ai(guard)
	var/obj/item/gun/ballistic/automatic/pistol/pistol = allocate(/obj/item/gun/ballistic/automatic/pistol)
	pistol.can_misfire = FALSE
	holder.put_in_active_hand(pistol, forced = TRUE)
	holder.setDir(EAST)
	stealth_test_grab(holder, hostage, GRAB_NECK)
	TEST_ASSERT_EQUAL(stealth_hostage_of(holder), hostage, "Test fixture: a neck grab with a gun isn't a hostage")
	guard_ai.stealth_go_alert(holder)
	var/datum/ai_planning_subtree/stealth_hostage/subtree = GLOB.ai_subtrees[/datum/ai_planning_subtree/stealth_hostage]
	TEST_ASSERT_EQUAL(subtree.SelectBehaviors(guard_ai, 1), SUBTREE_RETURN_FINISH_PLANNING, "Test fixture: the guard didn't stand off")
	return guard_ai

/// `holder` swings a punch at `victim` with his empty other hand, in combat mode (tg's unarmed attack; it may miss,
/// and a swing is an attack either way).
/datum/unit_test/proc/stealth_test_punch(mob/living/carbon/human/holder, mob/living/victim)
	holder.swap_hand()
	holder.set_combat_mode(TRUE)
	holder.UnarmedAttack(victim, TRUE, list())
	holder.set_combat_mode(FALSE)
	holder.swap_hand()

/// A standoff ends for good, and the guard fights, when the holder attacks: one of the guard's people he can see,
/// the guard himself, the hostage with a bare fist, or strangles the hostage. Loose words aren't a demand to back off.
/datum/unit_test/voidcrew_stealth_hostage_fight_back

/datum/unit_test/voidcrew_stealth_hostage_fight_back/Run()
	var/datum/turf_reservation/block = stealth_block(10, 9)
	TEST_ASSERT_NOTNULL(block, "No room for the test")
	// A friend of his, hit in front of him.
	var/mob/living/carbon/human/npc/guard = stealth_guard(block, 8, 1, WEST)
	var/mob/living/carbon/human/npc/hostage = stealth_guard(block, 3, 1, WEST)
	var/mob/living/carbon/human/npc/friend = stealth_guard(block, 2, 2, WEST)
	var/mob/living/carbon/human/holder = stealth_person(block, 2, 1)
	var/datum/ai_controller/basic_controller/human_npc/stealth/guard_ai = stealth_test_standoff(guard, holder, hostage)
	if(!guard_ai)
		return
	holder.say("Don't move! Let's go!")
	TEST_ASSERT(!guard_ai.standoff_backed_off, "Loose words made the guard back off")
	stealth_test_punch(holder, friend)
	TEST_ASSERT_NULL(guard_ai.standoff_holder, "The standoff outlived the holder hitting a friend in view")
	TEST_ASSERT(LAZYFIND(guard_ai.no_deals, REF(holder)), "No grudge after the holder hit a friend")
	// The guard himself.
	var/mob/living/carbon/human/npc/guard2 = stealth_guard(block, 3, 4, WEST)
	var/mob/living/carbon/human/npc/hostage2 = stealth_guard(block, 3, 3, WEST)
	var/mob/living/carbon/human/holder2 = stealth_person(block, 2, 3)
	var/datum/ai_controller/basic_controller/human_npc/stealth/guard2_ai = stealth_test_standoff(guard2, holder2, hostage2)
	if(!guard2_ai)
		return
	stealth_test_punch(holder2, guard2)
	TEST_ASSERT_NULL(guard2_ai.standoff_holder, "The standoff outlived the holder hitting the guard")
	// The hostage, a bare fist.
	var/mob/living/carbon/human/npc/guard3 = stealth_guard(block, 8, 5, WEST)
	var/mob/living/carbon/human/npc/hostage3 = stealth_guard(block, 3, 5, WEST)
	var/mob/living/carbon/human/holder3 = stealth_person(block, 2, 5)
	var/datum/ai_controller/basic_controller/human_npc/stealth/guard3_ai = stealth_test_standoff(guard3, holder3, hostage3)
	if(!guard3_ai)
		return
	stealth_test_punch(holder3, hostage3)
	TEST_ASSERT_NULL(guard3_ai.standoff_holder, "The standoff outlived the holder punching the hostage")
	// The hostage strangled (tg's GRAB_KILL).
	var/mob/living/carbon/human/npc/guard4 = stealth_guard(block, 8, 7, WEST)
	var/mob/living/carbon/human/npc/hostage4 = stealth_guard(block, 3, 7, WEST)
	var/mob/living/carbon/human/holder4 = stealth_person(block, 2, 7)
	var/datum/ai_controller/basic_controller/human_npc/stealth/guard4_ai = stealth_test_standoff(guard4, holder4, hostage4)
	if(!guard4_ai)
		return
	hostage4.grippedby(holder4, instant = TRUE)
	TEST_ASSERT_EQUAL(holder4.grab_state, GRAB_KILL, "Test fixture: no strangle")
	TEST_ASSERT_NULL(guard4_ai.standoff_holder, "The standoff outlived the holder strangling the hostage")
	TEST_ASSERT(LAZYFIND(guard4_ai.no_deals, REF(holder4)), "No grudge after the hostage was strangled")
	qdel(block)

/// A hostage deleted while held up on his feet isn't left a let-go spot that holds on to him.
/datum/unit_test/voidcrew_stealth_hostage_deleted

/datum/unit_test/voidcrew_stealth_hostage_deleted/Run()
	var/datum/turf_reservation/block = stealth_block(6, 3)
	TEST_ASSERT_NOTNULL(block, "No room for the test")
	var/mob/living/carbon/human/holder = stealth_person(block, 2, 1)
	var/mob/living/carbon/human/hostage = stealth_person(block, 3, 1)
	var/obj/item/gun/ballistic/automatic/pistol/pistol = allocate(/obj/item/gun/ballistic/automatic/pistol)
	holder.put_in_active_hand(pistol, forced = TRUE)
	stealth_test_grab(holder, hostage, GRAB_NECK)
	TEST_ASSERT_EQUAL(stealth_hostage_of(holder), hostage, "Test fixture: no hostage")
	TEST_ASSERT_EQUAL(hostage.body_position, STANDING_UP, "Test fixture: the hostage isn't held on his feet")
	qdel(hostage)
	TEST_ASSERT_NULL(hostage.hostage_pose_freed, "A deleted hostage got a let-go spot that keeps him")
	qdel(block)
