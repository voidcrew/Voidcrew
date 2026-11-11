// Stealth crits, the head shot, the backstab knife and lootable seclites (step 3a, voidcrew/modules/stealth/stealth_crits.dm,
// stealth_knife.dm, stealth_light.dm). Values from voidcrew/_DEFINES are written out: STEALTH_CRIT_UNAWARE_BONUS 30,
// STEALTH_CRIT_SUSPICIOUS_BONUS 15, STEALTH_CRIT_HEAD_BONUS 35, STEALTH_BACKSTAB_BONUS 40, STEALTH_HEAD_SHOT_BRAIN_DAMAGE 40.

/// The bonus by state: full when unaware, smaller when suspicious, none when searching or alert, more on the head;
/// never on a player or an NPC without the stealth controller.
/datum/unit_test/voidcrew_stealth_crit_bonus

/datum/unit_test/voidcrew_stealth_crit_bonus/Run()
	var/datum/turf_reservation/block = stealth_block(8, 5)
	TEST_ASSERT_NOTNULL(block, "No room for the test")
	var/mob/living/carbon/human/npc/guard = stealth_guard(block, 4, 2)
	var/datum/ai_controller/basic_controller/human_npc/stealth/stealth_ai = stealth_ai(guard)
	var/mob/living/carbon/human/person = stealth_person(block, 5, 2)
	var/obj/item/knife/combat/knife = allocate(/obj/item/knife/combat)
	person.put_in_active_hand(knife)
	var/obj/item/bodypart/head = guard.get_bodypart(BODY_ZONE_HEAD)
	var/obj/item/bodypart/chest = guard.get_bodypart(BODY_ZONE_CHEST)
	TEST_ASSERT_EQUAL(guard.stealth_crit_bonus(person, knife, chest), 30, "Wrong bonus on an unaware guard")
	TEST_ASSERT_EQUAL(guard.stealth_crit_bonus(person, knife, head), 65, "Wrong bonus on an unaware guard's head")
	TEST_ASSERT_EQUAL(guard.hv_crit_situation_bonus(person, knife, head), 65, "The crit roll doesn't get the stealth bonus")
	stealth_ai.stealth_go_suspicious(stealth_at(block, 1, 2))
	TEST_ASSERT_EQUAL(guard.stealth_crit_bonus(person, knife, chest), 30, "A guard that turned suspicious this tick lost the unaware bonus")
	stealth_ai.stealth_rewind(1)
	TEST_ASSERT_EQUAL(guard.stealth_crit_bonus(person, knife, chest), 15, "Wrong bonus on a suspicious guard")
	TEST_ASSERT_EQUAL(guard.stealth_crit_bonus(person, knife, head), 50, "Wrong bonus on a suspicious guard's head")
	// The blow that alerts it still counts as one on a suspicious guard (a bullet's prehit alerts it first).
	stealth_ai.stealth_go_alert(person)
	TEST_ASSERT_EQUAL(guard.stealth_crit_bonus(person, knife, chest), 15, "The blow that alerted a suspicious guard lost its bonus")
	stealth_ai.stealth_rewind(1)
	TEST_ASSERT_EQUAL(guard.stealth_crit_bonus(person, knife, head), 0, "An alert guard gives a stealth bonus")
	stealth_ai.stealth_go_searching(stealth_at(block, 1, 2))
	stealth_ai.stealth_rewind(1)
	TEST_ASSERT_EQUAL(guard.stealth_crit_bonus(person, knife, head), 0, "A searching guard gives a stealth bonus")
	// Unaware, but down or held: the helpless bonus is the one that counts there.
	stealth_ai.stealth_go_unaware()
	stealth_ai.stealth_rewind(1)
	TEST_ASSERT_EQUAL(guard.stealth_crit_bonus(person, knife, chest), 30, "Back to unaware, no bonus")
	var/obj/item/restraints/handcuffs/cuffs = allocate(/obj/item/restraints/handcuffs)
	TEST_ASSERT(guard.equip_to_slot_if_possible(cuffs, ITEM_SLOT_HANDCUFFED), "Test fixture: the guard can't be cuffed")
	TEST_ASSERT_EQUAL(guard.stealth_crit_bonus(person, knife, chest), 0, "A cuffed guard gives a stealth bonus")
	// Never on a player, nor on an NPC without the stealth controller.
	var/mob/living/carbon/human/player = stealth_person(block, 2, 4)
	TEST_ASSERT_EQUAL(player.hv_crit_situation_bonus(person, knife, player.get_bodypart(BODY_ZONE_HEAD)), 0, "A person gets a stealth bonus")
	var/mob/living/carbon/human/npc/plain = allocate(/mob/living/carbon/human/npc/ruin/trooper/syndicate, stealth_at(block, 1, 4))
	TEST_ASSERT_EQUAL(plain.stealth_crit_bonus(person, knife, plain.get_bodypart(BODY_ZONE_HEAD)), 0, "An NPC without stealth gets a stealth bonus")
	qdel(block)

/// The matte knife adds its bonus from behind only, on an alert guard too; a plain knife never does.
/datum/unit_test/voidcrew_stealth_backstab

/datum/unit_test/voidcrew_stealth_backstab/Run()
	var/datum/turf_reservation/block = stealth_block(8, 5)
	TEST_ASSERT_NOTNULL(block, "No room for the test")
	var/mob/living/carbon/human/npc/guard = stealth_guard(block, 4, 2) // facing east
	var/datum/ai_controller/basic_controller/human_npc/stealth/stealth_ai = stealth_ai(guard)
	var/mob/living/carbon/human/person = stealth_person(block, 3, 2) // behind it
	var/obj/item/knife/combat/matte/knife = allocate(/obj/item/knife/combat/matte)
	var/obj/item/knife/combat/blade = allocate(/obj/item/knife/combat)
	person.put_in_active_hand(knife)
	var/obj/item/bodypart/head = guard.get_bodypart(BODY_ZONE_HEAD)
	var/obj/item/bodypart/chest = guard.get_bodypart(BODY_ZONE_CHEST)
	TEST_ASSERT_EQUAL(guard.stealth_crit_bonus(person, knife, head), 105, "Wrong bonus for a backstab to an unaware guard's head")
	stealth_ai.stealth_go_alert(person)
	stealth_ai.stealth_rewind(1)
	guard.setDir(EAST)
	TEST_ASSERT_EQUAL(guard.stealth_crit_bonus(person, knife, chest), 40, "Wrong backstab bonus on an alert guard")
	TEST_ASSERT_EQUAL(guard.stealth_crit_bonus(person, blade, chest), 0, "A plain knife backstabs")
	// From the front and from the side: nothing.
	person.forceMove(stealth_at(block, 5, 2))
	TEST_ASSERT_EQUAL(guard.stealth_crit_bonus(person, knife, chest), 0, "The knife backstabs from the front")
	person.forceMove(stealth_at(block, 4, 3))
	TEST_ASSERT_EQUAL(guard.stealth_crit_bonus(person, knife, chest), 0, "The knife backstabs from the side")
	// A player from behind: a plain knife.
	var/mob/living/carbon/human/player = stealth_person(block, 6, 4)
	player.setDir(EAST)
	person.forceMove(stealth_at(block, 5, 4))
	TEST_ASSERT_EQUAL(player.hv_crit_situation_bonus(person, knife, player.get_bodypart(BODY_ZONE_CHEST)), 0, "The knife backstabs a person")
	qdel(block)

/// Wound armour scales the bonus with the rest of the roll, and a helmet stops the head shot outright.
/datum/unit_test/voidcrew_stealth_crit_armour

/datum/unit_test/voidcrew_stealth_crit_armour/Run()
	var/datum/turf_reservation/block = stealth_block(8, 5)
	TEST_ASSERT_NOTNULL(block, "No room for the test")
	var/mob/living/carbon/human/npc/guard = stealth_guard(block, 4, 2)
	var/datum/ai_controller/basic_controller/human_npc/stealth/stealth_ai = stealth_ai(guard)
	var/mob/living/carbon/human/person = stealth_person(block, 6, 2)
	var/obj/item/knife/combat/knife = allocate(/obj/item/knife/combat)
	person.put_in_active_hand(knife)
	var/obj/item/bodypart/head = guard.get_bodypart(BODY_ZONE_HEAD)
	if(guard.head)
		qdel(guard.head)
	// 1 damage makes tg's own roll 1, so the rest of the roll is exact.
	var/bare = head.hv_crit_roll(WOUND_SLASH, 1, 0, 0, person, knife)
	TEST_ASSERT(bare > 55, "An unaware bare head rolled only [bare]")
	var/obj/item/clothing/head/helmet/swat/helmet = new(guard)
	TEST_ASSERT(guard.equip_to_slot_if_possible(helmet, ITEM_SLOT_HEAD, disable_warning = TRUE), "Couldn't put a helmet on the guard")
	var/armoured = head.hv_crit_roll(WOUND_SLASH, 1, 0, 0, person, knife)
	TEST_ASSERT(armoured < bare, "A helmet didn't lower the stealth roll ([armoured] vs [bare])")
	// The head shot: a 9mm through a SWAT helmet is stopped; with the helmet off it isn't.
	var/datum/hv_crit/head_shot/crit = locate() in GLOB.hv_crits
	TEST_ASSERT_NOTNULL(crit, "No head shot crit")
	var/obj/projectile/bullet/c9mm/shot = allocate(/obj/projectile/bullet/c9mm)
	shot.firer = person
	TEST_ASSERT(crit.blocked_on_carbon(guard, head, shot), "A SWAT helmet doesn't stop a 9mm head shot")
	qdel(helmet)
	TEST_ASSERT(!crit.blocked_on_carbon(guard, head, shot), "A bare-headed unaware guard is safe from a head shot")
	// Alert: no stealth hit, so no head shot.
	stealth_ai.stealth_go_alert(person)
	stealth_ai.stealth_rewind(1)
	TEST_ASSERT(crit.blocked_on_carbon(guard, head, shot), "An alert guard can be head shot")
	var/roll = head.hv_crit_roll(WOUND_SLASH, 1, 0, 0, person, knife)
	TEST_ASSERT(roll < 5, "An alert guard's roll still has a bonus ([roll])")
	qdel(block)

/// A head shot lands on an unaware guard and does real harm through tg's wound; never on a person or an alert guard.
/datum/unit_test/voidcrew_stealth_head_shot

/datum/unit_test/voidcrew_stealth_head_shot/Run()
	var/datum/turf_reservation/block = stealth_block(8, 5)
	TEST_ASSERT_NOTNULL(block, "No room for the test")
	var/mob/living/carbon/human/npc/guard = stealth_guard(block, 4, 2)
	var/mob/living/carbon/human/person = stealth_person(block, 1, 2)
	var/obj/projectile/bullet/c9mm/shot = allocate(/obj/projectile/bullet/c9mm)
	shot.firer = person
	if(guard.head)
		qdel(guard.head)
	var/obj/item/bodypart/head = guard.get_bodypart(BODY_ZONE_HEAD)
	var/datum/hv_crit/crit = guard.hv_try_aimed_crit(head, BODY_ZONE_HEAD, WOUND_PIERCE, 30, 0, 0, EAST, shot, person, 500)
	TEST_ASSERT(istype(crit, /datum/hv_crit/head_shot), "A forced head shot on an unaware guard didn't land (got [crit])")
	TEST_ASSERT_NOTNULL(head.get_wound_type(/datum/wound/pierce/bleed/critical/hv_head_shot), "No head shot wound")
	TEST_ASSERT(guard.get_organ_loss(ORGAN_SLOT_BRAIN) >= 40, "The head shot did no brain damage")
	TEST_ASSERT(guard.IsKnockdown(), "The head shot didn't knock the guard down")
	// Not from a knife.
	var/mob/living/carbon/human/npc/second = stealth_guard(block, 6, 3)
	if(second.head)
		qdel(second.head)
	var/obj/item/knife/combat/knife = allocate(/obj/item/knife/combat)
	crit = second.hv_try_aimed_crit(second.get_bodypart(BODY_ZONE_HEAD), BODY_ZONE_HEAD, WOUND_PIERCE, 30, 0, 0, EAST, knife, person, 500)
	TEST_ASSERT(!istype(crit, /datum/hv_crit/head_shot), "A knife caused a head shot")
	// Never on a person.
	var/mob/living/carbon/human/player = stealth_person(block, 2, 4)
	crit = player.hv_try_aimed_crit(player.get_bodypart(BODY_ZONE_HEAD), BODY_ZONE_HEAD, WOUND_PIERCE, 30, 0, 0, EAST, shot, person, 500)
	TEST_ASSERT_NULL(crit, "A person took a head shot crit")
	// Never on an alert guard.
	var/mob/living/carbon/human/npc/third = stealth_guard(block, 1, 4)
	if(third.head)
		qdel(third.head)
	var/datum/ai_controller/basic_controller/human_npc/stealth/third_ai = stealth_ai(third)
	third_ai.stealth_go_alert(person)
	third_ai.stealth_rewind(1)
	crit = third.hv_try_aimed_crit(third.get_bodypart(BODY_ZONE_HEAD), BODY_ZONE_HEAD, WOUND_PIERCE, 30, 0, 0, EAST, shot, person, 500)
	TEST_ASSERT_NULL(crit, "An alert guard took a head shot crit")
	qdel(block)

/// Decision 34: the seclite strips and drops like anyone's; the rest of the kit stays locked; the guard carries on without it.
/datum/unit_test/voidcrew_stealth_seclite_loot

/datum/unit_test/voidcrew_stealth_seclite_loot/Run()
	var/datum/turf_reservation/block = stealth_block(8, 5)
	TEST_ASSERT_NOTNULL(block, "No room for the test")
	var/mob/living/carbon/human/npc/guard = stealth_guard(block, 4, 2)
	var/datum/ai_controller/basic_controller/human_npc/stealth/stealth_ai = stealth_ai(guard)
	var/obj/item/flashlight/light = stealth_ai.stealth_light()
	TEST_ASSERT_NOTNULL(light, "A scav guard has no flashlight")
	TEST_ASSERT(!HAS_TRAIT(light, TRAIT_NO_STRIP), "The seclite can't be stripped")
	TEST_ASSERT(!human_npc_gear_locked(light), "The seclite is locked gear")
	TEST_ASSERT(human_npc_gear_locked(guard.w_uniform), "The rest of the guard's kit isn't locked any more")
	TEST_ASSERT(light in GLOB.stealth_guard_lights, "The seclite isn't on the guard light list")
	var/mob/living/carbon/human/person = stealth_person(block, 3, 2)
	TEST_ASSERT(guard.dropItemToGround(light), "The seclite can't be taken off")
	TEST_ASSERT(person.put_in_hands(light), "The seclite can't be picked up")
	TEST_ASSERT(!QDELETED(light), "The looted seclite was deleted")
	TEST_ASSERT(!(light in GLOB.stealth_guard_lights), "A looted seclite still counts as a guard's")
	// The guard goes without: no light to switch, and it still scans and sees.
	TEST_ASSERT_NULL(stealth_ai.stealth_light(), "The guard still counts the light it lost")
	GLOB.stealth_test_dark_turfs[get_turf(guard)] = TRUE
	stealth_ai.stealth_update_light()
	TEST_ASSERT(!light.light_on, "The guard switched on a light a player holds")
	GLOB.stealth_test_dark_turfs[get_turf(guard)] = FALSE
	person.forceMove(stealth_at(block, 5, 2))
	stealth_scans(guard, 1)
	TEST_ASSERT_EQUAL(stealth_ai.stealth_state(), "alert", "A guard without its light didn't see someone in front of it")
	qdel(block)
