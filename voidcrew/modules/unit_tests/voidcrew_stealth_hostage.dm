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
