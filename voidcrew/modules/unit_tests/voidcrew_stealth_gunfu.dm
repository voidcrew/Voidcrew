// Gun-fu (step 3c, voidcrew/modules/stealth/stealth_gunfu.dm) and hostages (step 5, stealth_hostage.dm). Unit tests
// compile before voidcrew/_DEFINES, so values are written out: GUNFU_CRIT_BONUS 10, GUNFU_CRIT_HEAD_BONUS 10,
// ORGAN_SLOT_CYBERWARE_COMBAT_CHIP "cyberware_combat_chip", state "alert".

/// `mover` with the gun kata chip and a pistol in the active hand.
/datum/unit_test/proc/gunfu_arm(mob/living/carbon/human/mover)
	var/obj/item/organ/cyberimp/cyberware/gun_kata/chip = allocate(/obj/item/organ/cyberimp/cyberware/gun_kata)
	TEST_ASSERT(chip.Insert(mover, special = TRUE), "The gun kata chip wouldn't go in")
	var/obj/item/gun/ballistic/automatic/pistol/pistol = allocate(/obj/item/gun/ballistic/automatic/pistol)
	pistol.can_misfire = FALSE
	mover.put_in_active_hand(pistol, forced = TRUE)
	return pistol

/// `holder` holds `victim` at `wanted` grab state through tg's own grab.
/datum/unit_test/proc/gunfu_grab(mob/living/carbon/human/holder, mob/living/victim, wanted)
	holder.start_pulling(victim, supress_message = TRUE)
	var/tries = 0
	while(holder.pulling == victim && holder.grab_state < wanted && tries++ < 3)
		victim.grippedby(holder, instant = TRUE)
	TEST_ASSERT_EQUAL(holder.grab_state, wanted, "Test fixture: couldn't get the grab")

/// Only a running chip and a gun in the active hand make a mover; the chip sits in its own head slot.
/datum/unit_test/voidcrew_stealth_gunfu_ready

/datum/unit_test/voidcrew_stealth_gunfu_ready/Run()
	var/datum/turf_reservation/block = stealth_block(6, 4)
	TEST_ASSERT_NOTNULL(block, "No room for the test")
	var/mob/living/carbon/human/mover = stealth_person(block, 2, 2)
	var/obj/item/gun/ballistic/automatic/pistol/pistol = allocate(/obj/item/gun/ballistic/automatic/pistol)
	mover.put_in_active_hand(pistol, forced = TRUE)
	TEST_ASSERT_NULL(mover.gunfu_gun(), "Gun-fu without the chip")
	qdel(pistol)
	gunfu_arm(mover)
	var/obj/item/organ/chip = mover.get_organ_slot("cyberware_combat_chip")
	TEST_ASSERT(istype(chip, /obj/item/organ/cyberimp/cyberware/gun_kata), "The chip isn't in the combat chip slot")
	TEST_ASSERT_EQUAL(chip.zone, BODY_ZONE_HEAD, "The chip isn't in the head")
	TEST_ASSERT_NOTNULL(mover.gunfu_gun(), "A chip and a gun didn't make a mover")
	mover.swap_hand()
	TEST_ASSERT_NULL(mover.gunfu_gun(), "Gun-fu with an empty active hand")
	mover.swap_hand()
	mover.gunfu_next_move = world.time + 10
	TEST_ASSERT_NULL(mover.gunfu_gun(), "Gun-fu during the cooldown")
	mover.gunfu_next_move = 0
	chip.organ_flags |= ORGAN_FAILING
	TEST_ASSERT_NULL(mover.gunfu_gun(), "Gun-fu from a failing chip")
	chip.organ_flags &= ~ORGAN_FAILING
	qdel(block)

/// Throw mode with someone in an aggressive grab throws them, not the gun; a neck grab flips them. Both mark them,
/// and only the mover's shots on a marked body get the bonus.
/datum/unit_test/voidcrew_stealth_gunfu_throws

/datum/unit_test/voidcrew_stealth_gunfu_throws/Run()
	var/datum/turf_reservation/block = stealth_block(8, 5)
	TEST_ASSERT_NOTNULL(block, "No room for the test")
	var/mob/living/carbon/human/mover = stealth_person(block, 3, 2)
	var/obj/item/gun/gun = gunfu_arm(mover)
	var/mob/living/carbon/human/victim = stealth_person(block, 4, 2)
	gunfu_grab(mover, victim, GRAB_AGGRESSIVE)
	TEST_ASSERT(mover.throw_item(stealth_at(block, 6, 2)), "The hip throw didn't happen")
	TEST_ASSERT_EQUAL(gun.loc, mover, "The hip throw threw the gun")
	TEST_ASSERT_NULL(mover.pulling, "Still holding them after the hip throw")
	TEST_ASSERT(victim.throwing || get_dist(mover, victim) > 1, "The victim wasn't thrown")
	TEST_ASSERT(mover.gunfu_next_move > world.time, "No cooldown after the hip throw")
	var/obj/projectile/shot = allocate(/obj/projectile/bullet)
	shot.firer = mover
	var/obj/item/bodypart/head = victim.get_bodypart(BODY_ZONE_HEAD)
	var/obj/item/bodypart/chest = victim.get_bodypart(BODY_ZONE_CHEST)
	TEST_ASSERT_EQUAL(victim.gunfu_crit_bonus(mover, shot, chest), 10, "Wrong gun-fu bonus on the chest")
	TEST_ASSERT_EQUAL(victim.gunfu_crit_bonus(mover, shot, head), 20, "Wrong gun-fu bonus on the head")
	TEST_ASSERT_EQUAL(victim.gunfu_crit_bonus(mover, gun, chest), 0, "A gun-fu bonus on a melee blow")
	var/mob/living/carbon/human/other = stealth_person(block, 1, 4)
	TEST_ASSERT_EQUAL(victim.gunfu_crit_bonus(other, shot, chest), 0, "Someone else's shot got the gun-fu bonus")
	victim.gunfu_mark_until = world.time
	TEST_ASSERT_EQUAL(victim.gunfu_crit_bonus(mover, shot, chest), 0, "The gun-fu bonus outlasted its time")
	// Landing: tg's knockdown and real damage.
	victim.throwing?.finalize()
	victim.SetKnockdown(0)
	mover.gunfu_landed(victim, 2 SECONDS, 5)
	TEST_ASSERT(victim.IsKnockdown(), "Landing didn't knock them down")
	TEST_ASSERT(victim.getBruteLoss() > 0, "Landing did no damage")
	// The flip: a neck grab puts them on the mover's tile; they go onto the next tile.
	var/mob/living/carbon/human/flipped = stealth_person(block, 2, 2)
	mover.gunfu_next_move = 0
	gunfu_grab(mover, flipped, GRAB_NECK)
	TEST_ASSERT_EQUAL(flipped.loc, mover.loc, "Test fixture: the neck grab didn't bring them onto the tile")
	TEST_ASSERT(mover.throw_item(stealth_at(block, 3, 4)), "The flip didn't happen")
	TEST_ASSERT_NULL(mover.pulling, "Still holding them after the flip")
	TEST_ASSERT(flipped.throwing || flipped.loc != mover.loc, "The flipped body didn't leave the tile")
	TEST_ASSERT(flipped.gunfu_mark_until > world.time, "The flip didn't mark them")
	flipped.throwing?.finalize()
	// No chip: tg's own throw, the gun goes.
	var/mob/living/carbon/human/plain = stealth_person(block, 6, 4)
	var/obj/item/gun/ballistic/automatic/pistol/plain_gun = allocate(/obj/item/gun/ballistic/automatic/pistol)
	plain.put_in_active_hand(plain_gun, forced = TRUE)
	var/mob/living/carbon/human/held = stealth_person(block, 7, 4)
	gunfu_grab(plain, held, GRAB_AGGRESSIVE)
	plain.throw_item(stealth_at(block, 7, 1))
	TEST_ASSERT(plain_gun.loc != plain, "Without the chip the throw didn't go to tg (the gun stayed in hand)")
	qdel(block)

/// Right-click with the gun: into a wall it's a slam (tg's knockdown, real brute), in the open it knocks the weapon away.
/datum/unit_test/voidcrew_stealth_gunfu_shoves

/datum/unit_test/voidcrew_stealth_gunfu_shoves/Run()
	var/datum/turf_reservation/block = stealth_block(8, 5)
	TEST_ASSERT_NOTNULL(block, "No room for the test")
	var/turf/wall = stealth_at(block, 5, 2)
	wall.ChangeTurf(/turf/closed/wall)
	var/mob/living/carbon/human/mover = stealth_person(block, 3, 2)
	var/obj/item/gun/gun = gunfu_arm(mover)
	mover.set_combat_mode(TRUE)
	var/mob/living/carbon/human/victim = stealth_person(block, 4, 2)
	TEST_ASSERT(mover.gunfu_shove(victim, gun), "No wall slam")
	TEST_ASSERT(victim.IsKnockdown() || victim.body_position == LYING_DOWN, "The wall slam didn't put them down")
	TEST_ASSERT(victim.getBruteLoss() > 0, "The wall slam did no damage")
	// The disarm, in the open.
	var/mob/living/carbon/human/armed = stealth_person(block, 3, 3)
	var/obj/item/knife/combat/knife = allocate(/obj/item/knife/combat)
	armed.put_in_active_hand(knife, forced = TRUE)
	var/mob/living/carbon/human/second = stealth_person(block, 2, 3)
	var/obj/item/gun/second_gun = gunfu_arm(second)
	second.set_combat_mode(TRUE)
	TEST_ASSERT(second.gunfu_shove(armed, second_gun), "No disarm")
	TEST_ASSERT(!(knife in armed.held_items), "The disarm left the knife in their hand")
	TEST_ASSERT(armed.gunfu_mark_until > world.time, "The disarm didn't mark them")
	// Empty-handed, in the open: nothing to do, tg's own gun bash happens instead.
	second.gunfu_next_move = 0
	TEST_ASSERT(!second.gunfu_shove(armed, second_gun), "A disarm on someone with nothing in hand")
	qdel(block)

/// A neck grab with the gun out holds them up in front: shots from the front hit them, from behind the holder.
/datum/unit_test/voidcrew_stealth_gunfu_shield

/datum/unit_test/voidcrew_stealth_gunfu_shield/Run()
	var/datum/turf_reservation/block = stealth_block(9, 5)
	TEST_ASSERT_NOTNULL(block, "No room for the test")
	var/mob/living/carbon/human/holder = stealth_person(block, 4, 2)
	gunfu_arm(holder)
	var/mob/living/carbon/human/hostage = stealth_person(block, 5, 2)
	holder.setDir(EAST)
	gunfu_grab(holder, hostage, GRAB_NECK)
	holder.setDir(EAST)
	TEST_ASSERT_EQUAL(holder.gunfu_shield_body(), hostage, "No human shield")
	TEST_ASSERT_EQUAL(hostage.dir, EAST, "The shield doesn't face the holder's way")
	var/mob/living/carbon/human/front = stealth_person(block, 5, 2)
	var/obj/item/gun/front_gun = d45_arm(front, /obj/item/gun/ballistic/automatic/pistol)
	front.zone_selected = BODY_ZONE_CHEST
	front_gun.fire_gun(holder, front, TRUE, null)
	TEST_ASSERT_EQUAL(holder.getBruteLoss(), 0, "A shot from the front hit the holder")
	TEST_ASSERT(hostage.getBruteLoss() > 0, "A shot from the front missed the shield")
	var/hostage_before = hostage.getBruteLoss()
	var/mob/living/carbon/human/back = stealth_person(block, 3, 2)
	var/obj/item/gun/back_gun = d45_arm(back, /obj/item/gun/ballistic/automatic/pistol)
	back.zone_selected = BODY_ZONE_CHEST
	back_gun.fire_gun(holder, back, TRUE, null)
	TEST_ASSERT(holder.getBruteLoss() > 0, "A shot from behind missed the holder")
	TEST_ASSERT_EQUAL(hostage.getBruteLoss(), hostage_before, "A shot from behind hit the shield")
	holder.stop_pulling()
	TEST_ASSERT_NULL(holder.gunfu_shield_body(), "Still a shield after letting go")
	qdel(block)

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
	gunfu_grab(holder, friend, GRAB_NECK)
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
	gunfu_grab(holder2, stranger, GRAB_NECK)
	stealth_ai2.stealth_go_alert(holder2)
	TEST_ASSERT(isnull(subtree.SelectBehaviors(stealth_ai2, 1)), "A guard held fire for a stranger")
	qdel(block)
