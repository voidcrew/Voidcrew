// Hyperviolence aimed crits (voidcrew/modules/hyperviolence/crits/). Voidcrew defines are not
// visible from here, so nothing below uses them.

/// Every crit has a wound tg knows about, that tg's own wound roll can never pick, on the right limb.
/datum/unit_test/voidcrew_hv_crit_wounds_registered/Run()
	TEST_ASSERT(length(GLOB.hv_crits) >= 6, "Expected six aimed crits, found [length(GLOB.hv_crits)]")
	for(var/datum/hv_crit/crit as anything in GLOB.hv_crits)
		TEST_ASSERT(ispath(crit.wound_type, /datum/wound), "[crit.type] has no wound type")
		var/datum/wound_pregen_data/pregen = GLOB.all_wound_pregen_data[crit.wound_type]
		TEST_ASSERT_NOTNULL(pregen, "[crit.wound_type] has no pregen data")
		TEST_ASSERT(!pregen.can_be_randomly_generated, "[crit.wound_type] can come from tg's random wound roll")
		TEST_ASSERT(crit.limb_zone in pregen.viable_zones, "[crit.wound_type] cannot go on [crit.limb_zone]")
		TEST_ASSERT(ispath(crit.basic_effect, /datum/status_effect), "[crit.type] has nothing for basic mobs")
		for(var/zone in crit.aim_zones)
			TEST_ASSERT_EQUAL(check_zone(zone), crit.limb_zone, "[crit.type] is aimed at [zone], which is not on [crit.limb_zone]")

/// The first eye crit takes one eye; the second tears the organ out and blinds.
/datum/unit_test/voidcrew_hv_crit_eye/Run()
	var/mob/living/carbon/human/victim = allocate(/mob/living/carbon/human/consistent)
	var/mob/living/carbon/human/attacker = allocate(/mob/living/carbon/human/consistent)
	var/obj/item/spear/spear = allocate(/obj/item/spear)
	attacker.put_in_active_hand(spear)
	var/obj/item/bodypart/head = victim.get_bodypart(BODY_ZONE_HEAD)
	var/obj/item/organ/eyes/eyes = victim.get_organ_slot(ORGAN_SLOT_EYES)
	TEST_ASSERT_NOTNULL(eyes, "Test human has no eyes")

	var/datum/hv_crit/crit = victim.hv_try_aimed_crit(head, BODY_ZONE_PRECISE_EYES, WOUND_PIERCE, 20, 0, 0, NORTH, spear, attacker, 500)
	TEST_ASSERT(istype(crit, /datum/hv_crit/eye), "A forced eye crit did not land (got [crit])")
	TEST_ASSERT_NOTNULL(head.get_wound_type(/datum/wound/pierce/bleed/severe/eye/hv_gouged), "No torn-out eye wound")
	TEST_ASSERT_EQUAL(victim.get_organ_slot(ORGAN_SLOT_EYES), eyes, "The first eye crit took the whole organ")
	TEST_ASSERT(eyes.scarring == RIGHT_EYE_SCAR || eyes.scarring == LEFT_EYE_SCAR, "The first eye crit should scar exactly one eye (scarring [eyes.scarring])")
	TEST_ASSERT(!victim.is_blind(), "One eye gone should not blind")

	crit = victim.hv_try_aimed_crit(head, BODY_ZONE_PRECISE_EYES, WOUND_SLASH, 20, 0, 0, NORTH, spear, attacker, 500)
	TEST_ASSERT(istype(crit, /datum/hv_crit/eye), "The second eye crit did not land")
	TEST_ASSERT_NULL(victim.get_organ_slot(ORGAN_SLOT_EYES), "The second eye crit left the eyes in")
	TEST_ASSERT(isturf(eyes.loc), "The torn-out eyes are not on the floor")
	TEST_ASSERT(victim.is_blind(), "No eyes left, but not blind")

/// Eye cover blocks the eye crit, and a hit aimed elsewhere never causes it.
/datum/unit_test/voidcrew_hv_crit_eye_blocked/Run()
	var/mob/living/carbon/human/victim = allocate(/mob/living/carbon/human/consistent)
	var/mob/living/carbon/human/attacker = allocate(/mob/living/carbon/human/consistent)
	var/obj/item/spear/spear = allocate(/obj/item/spear)
	attacker.put_in_active_hand(spear)
	var/obj/item/bodypart/head = victim.get_bodypart(BODY_ZONE_HEAD)

	TEST_ASSERT_NULL(victim.hv_try_aimed_crit(head, BODY_ZONE_CHEST, WOUND_PIERCE, 20, 0, 0, NORTH, spear, attacker, 500), "A chest aim caused a head crit")
	TEST_ASSERT_NULL(victim.hv_try_aimed_crit(head, BODY_ZONE_PRECISE_EYES, WOUND_PIERCE, 5, 0, 0, NORTH, spear, attacker, 500), "A hit below the minimum damage caused an eye crit")

	var/obj/item/clothing/glasses/sunglasses/shades = allocate(/obj/item/clothing/glasses/sunglasses)
	victim.equip_to_slot_if_possible(shades, ITEM_SLOT_EYES)
	TEST_ASSERT(victim.is_eyes_covered(), "Sunglasses did not cover the eyes")
	TEST_ASSERT_NULL(victim.hv_try_aimed_crit(head, BODY_ZONE_PRECISE_EYES, WOUND_PIERCE, 20, 0, 0, NORTH, spear, attacker, 500), "Sunglasses did not stop the eye crit")
	TEST_ASSERT_NULL(head.get_wound_type(/datum/wound/pierce/bleed/severe/eye/hv_gouged), "Blocked eye crit still left a wound")

/// A real attack through apply_damage, aimed at the eyes with a spear, lands the crit; the same
/// attack from a basic mob's shot or with the doll on the chest does not.
/datum/unit_test/voidcrew_hv_crit_through_apply_damage/Run()
	var/mob/living/carbon/human/victim = allocate(/mob/living/carbon/human/consistent)
	var/mob/living/carbon/human/attacker = allocate(/mob/living/carbon/human/consistent)
	var/obj/item/spear/spear = allocate(/obj/item/spear)
	attacker.put_in_active_hand(spear)
	var/obj/item/bodypart/head = victim.get_bodypart(BODY_ZONE_HEAD)

	// 15 damage rolls 1-44; +90 wound bonus keeps the roll above the eye threshold (80) and below
	// tg's outright dismember roll (150), so this is deterministic.
	attacker.zone_selected = BODY_ZONE_CHEST
	victim.apply_damage(15, BRUTE, head, wound_bonus = 90, sharpness = SHARP_POINTY, attacking_item = spear)
	TEST_ASSERT_NULL(head.get_wound_type(/datum/wound/pierce/bleed/severe/eye/hv_gouged), "A chest aim tore an eye out")

	attacker.zone_selected = BODY_ZONE_PRECISE_EYES
	victim.apply_damage(15, BRUTE, head, wound_bonus = 90, sharpness = SHARP_POINTY, attacking_item = spear)
	TEST_ASSERT_NOTNULL(head.get_wound_type(/datum/wound/pierce/bleed/severe/eye/hv_gouged), "An aimed spear hit through apply_damage did not tear an eye out")

	// Thrown or loose weapons have no one aiming them.
	var/mob/living/carbon/human/victim_two = allocate(/mob/living/carbon/human/consistent)
	var/obj/item/bodypart/head_two = victim_two.get_bodypart(BODY_ZONE_HEAD)
	var/obj/item/spear/loose_spear = allocate(/obj/item/spear)
	victim_two.apply_damage(15, BRUTE, head_two, wound_bonus = 90, sharpness = SHARP_POINTY, attacking_item = loose_spear)
	TEST_ASSERT_NULL(head_two.get_wound_type(/datum/wound/pierce/bleed/severe/eye/hv_gouged), "A weapon nobody held tore an eye out")

/// Tongue crit: the tongue comes out and lands on the floor.
/datum/unit_test/voidcrew_hv_crit_tongue/Run()
	var/mob/living/carbon/human/victim = allocate(/mob/living/carbon/human/consistent)
	var/mob/living/carbon/human/attacker = allocate(/mob/living/carbon/human/consistent)
	var/obj/item/knife/combat/knife = allocate(/obj/item/knife/combat)
	attacker.put_in_active_hand(knife)
	var/obj/item/bodypart/head = victim.get_bodypart(BODY_ZONE_HEAD)
	var/obj/item/organ/tongue/tongue = victim.get_organ_slot(ORGAN_SLOT_TONGUE)
	TEST_ASSERT_NOTNULL(tongue, "Test human has no tongue")

	var/obj/item/clothing/mask/gas/mask = allocate(/obj/item/clothing/mask/gas)
	victim.equip_to_slot_if_possible(mask, ITEM_SLOT_MASK)
	TEST_ASSERT_NULL(victim.hv_try_aimed_crit(head, BODY_ZONE_PRECISE_MOUTH, WOUND_SLASH, 20, 0, 0, NORTH, knife, attacker, 500), "A gas mask did not stop the tongue crit")
	qdel(mask)

	var/datum/hv_crit/crit = victim.hv_try_aimed_crit(head, BODY_ZONE_PRECISE_MOUTH, WOUND_SLASH, 20, 0, 0, NORTH, knife, attacker, 500)
	TEST_ASSERT(istype(crit, /datum/hv_crit/tongue), "A forced tongue crit did not land (got [crit])")
	TEST_ASSERT_NULL(victim.get_organ_slot(ORGAN_SLOT_TONGUE), "The tongue is still in")
	TEST_ASSERT(isturf(tongue.loc), "The tongue is not on the floor")
	TEST_ASSERT_NOTNULL(head.get_wound_type(/datum/wound/slash/flesh/moderate/hv_tongue), "No severed tongue wound")

/// Throat crit: a heavy bleed that gargles speech, and a sealed helmet stops it.
/datum/unit_test/voidcrew_hv_crit_throat/Run()
	var/mob/living/carbon/human/victim = allocate(/mob/living/carbon/human/consistent)
	var/mob/living/carbon/human/attacker = allocate(/mob/living/carbon/human/consistent)
	var/obj/item/knife/combat/knife = allocate(/obj/item/knife/combat)
	attacker.put_in_active_hand(knife)
	var/obj/item/bodypart/head = victim.get_bodypart(BODY_ZONE_HEAD)

	var/datum/hv_crit/crit = victim.hv_try_aimed_crit(head, BODY_ZONE_HEAD, WOUND_SLASH, 25, 0, 0, NORTH, knife, attacker, 500)
	TEST_ASSERT(istype(crit, /datum/hv_crit/throat), "A forced throat crit did not land (got [crit])")
	var/datum/wound/slash/flesh/critical/hv_carotid/throat = head.get_wound_type(/datum/wound/slash/flesh/critical/hv_carotid)
	TEST_ASSERT_NOTNULL(throat, "No slit throat wound")
	TEST_ASSERT(throat.blood_flow >= 4, "The slit throat bleeds only [throat.blood_flow]")
	TEST_ASSERT(!throat.clot_rate, "The slit throat clots on its own")

	var/vowels = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
	TEST_ASSERT_NOTEQUAL(hv_crit_gargle(vowels), vowels, "Gargled speech came out unchanged")
	TEST_ASSERT_NULL(victim.hv_try_aimed_crit(head, BODY_ZONE_HEAD, WOUND_SLASH, 25, 0, 0, NORTH, knife, attacker, 500), "The throat crit landed twice")

	var/mob/living/carbon/human/helmeted = allocate(/mob/living/carbon/human/consistent)
	var/obj/item/clothing/head/helmet/space/helmet = allocate(/obj/item/clothing/head/helmet/space)
	helmeted.equip_to_slot_if_possible(helmet, ITEM_SLOT_HEAD)
	TEST_ASSERT(helmeted.is_mouth_covered(ITEM_SLOT_HEAD), "A space helmet does not cover the mouth")
	TEST_ASSERT_NULL(helmeted.hv_try_aimed_crit(helmeted.get_bodypart(BODY_ZONE_HEAD), BODY_ZONE_HEAD, WOUND_SLASH, 25, 0, 0, NORTH, knife, attacker, 500), "A sealed helmet did not stop the throat crit")

/// Aorta crit from a projectile fired by a carbon, and heavy chest armour stops it.
/datum/unit_test/voidcrew_hv_crit_aorta/Run()
	var/mob/living/carbon/human/victim = allocate(/mob/living/carbon/human/consistent)
	var/mob/living/carbon/human/attacker = allocate(/mob/living/carbon/human/consistent)
	var/obj/projectile/bullet/shot = allocate(/obj/projectile/bullet)
	shot.firer = attacker
	var/obj/item/bodypart/chest = victim.get_bodypart(BODY_ZONE_CHEST)

	TEST_ASSERT_NULL(victim.hv_try_aimed_crit(chest, BODY_ZONE_CHEST, WOUND_PIERCE, 20, 0, 0, NORTH, shot, attacker, 500), "A shot below the aorta's minimum damage tore it")
	var/datum/hv_crit/crit = victim.hv_try_aimed_crit(chest, BODY_ZONE_CHEST, WOUND_PIERCE, 30, 0, 0, NORTH, shot, attacker, 500)
	TEST_ASSERT(istype(crit, /datum/hv_crit/aorta), "A forced aorta crit did not land (got [crit])")
	var/datum/wound/pierce/bleed/critical/hv_aorta/aorta = chest.get_wound_type(/datum/wound/pierce/bleed/critical/hv_aorta)
	TEST_ASSERT_NOTNULL(aorta, "No torn aorta wound")
	TEST_ASSERT(aorta.blood_flow > 0, "The torn aorta does not bleed")

	var/mob/living/carbon/human/armoured = allocate(/mob/living/carbon/human/consistent)
	var/obj/item/clothing/suit/armor/bulletproof/vest = allocate(/obj/item/clothing/suit/armor/bulletproof)
	armoured.equip_to_slot_if_possible(vest, ITEM_SLOT_OCLOTHING)
	TEST_ASSERT_NULL(armoured.hv_try_aimed_crit(armoured.get_bodypart(BODY_ZONE_CHEST), BODY_ZONE_CHEST, WOUND_PIERCE, 30, 0, 0, NORTH, shot, attacker, 500), "A bulletproof vest did not stop the aorta crit")

/// Skull crit caves in and hurts the brain; a helmet stops it; on a victim in crit the head bursts.
/datum/unit_test/voidcrew_hv_crit_skull/Run()
	var/mob/living/carbon/human/victim = allocate(/mob/living/carbon/human/consistent)
	var/mob/living/carbon/human/attacker = allocate(/mob/living/carbon/human/consistent)
	var/obj/item/storage/toolbox/toolbox = allocate(/obj/item/storage/toolbox)
	attacker.put_in_active_hand(toolbox)
	var/obj/item/bodypart/head = victim.get_bodypart(BODY_ZONE_HEAD)

	var/mob/living/carbon/human/helmeted = allocate(/mob/living/carbon/human/consistent)
	var/obj/item/clothing/head/helmet/helmet = allocate(/obj/item/clothing/head/helmet)
	helmeted.equip_to_slot_if_possible(helmet, ITEM_SLOT_HEAD)
	TEST_ASSERT_NULL(helmeted.hv_try_aimed_crit(helmeted.get_bodypart(BODY_ZONE_HEAD), BODY_ZONE_HEAD, WOUND_BLUNT, 25, 0, 0, NORTH, toolbox, attacker, 500), "A helmet did not stop the skull crit")

	var/brain_before = victim.get_organ_loss(ORGAN_SLOT_BRAIN)
	var/datum/hv_crit/crit = victim.hv_try_aimed_crit(head, BODY_ZONE_HEAD, WOUND_BLUNT, 25, 0, 0, NORTH, toolbox, attacker, 500)
	TEST_ASSERT(istype(crit, /datum/hv_crit/skull), "A forced skull crit did not land (got [crit])")
	TEST_ASSERT_NOTNULL(head.get_wound_type(/datum/wound/blunt/bone/critical/hv_skull), "No caved-in skull wound")
	TEST_ASSERT(victim.get_organ_loss(ORGAN_SLOT_BRAIN) > brain_before, "The skull caved in without hurting the brain")

	var/mob/living/carbon/human/dying = allocate(/mob/living/carbon/human/consistent)
	dying.set_stat(HARD_CRIT)
	crit = dying.hv_try_aimed_crit(dying.get_bodypart(BODY_ZONE_HEAD), BODY_ZONE_HEAD, WOUND_BLUNT, 25, 0, 0, NORTH, toolbox, attacker, 500)
	TEST_ASSERT(istype(crit, /datum/hv_crit/skull), "A skull crit on a victim in crit did not land")
	TEST_ASSERT_NULL(dying.get_bodypart(BODY_ZONE_HEAD), "A skull crit on a victim in crit did not burst the head")

/// Plating under the skin (cyberware dermal armour, which lives in the body's own armour) counts with worn armour the
/// way tg stacks them: a vest and Slabskin stop the aorta crit that neither stops alone, and the lightest helmet and
/// Slabskin stop the skull crit.
/datum/unit_test/voidcrew_hv_crit_plating

/// A human with Slabskin's armour mixed into their own, as the implant does.
/datum/unit_test/voidcrew_hv_crit_plating/proc/plated_human()
	var/mob/living/carbon/human/plated = allocate(/mob/living/carbon/human/consistent)
	plated.physiology.armor = plated.physiology.armor.add_other_armor(/datum/armor/cyberware_slabskin)
	return plated

/datum/unit_test/voidcrew_hv_crit_plating/Run()
	var/mob/living/carbon/human/attacker = allocate(/mob/living/carbon/human/consistent)

	// the aorta, shot at the chest: heavy chest armour is 40 or better after penetration
	var/obj/projectile/bullet/shot = allocate(/obj/projectile/bullet)
	shot.firer = attacker
	var/mob/living/carbon/human/vest_only = allocate(/mob/living/carbon/human/consistent)
	vest_only.equip_to_slot_if_possible(allocate(/obj/item/clothing/suit/armor/vest), ITEM_SLOT_OCLOTHING)
	var/mob/living/carbon/human/plate_only = plated_human()
	var/mob/living/carbon/human/both = plated_human()
	both.equip_to_slot_if_possible(allocate(/obj/item/clothing/suit/armor/vest), ITEM_SLOT_OCLOTHING)
	var/chest_rating = hv_crit_cover_rating(vest_only, vest_only.get_bodypart(BODY_ZONE_CHEST), BULLET)
	TEST_ASSERT(hv_crit_cover_rating(plate_only, plate_only.get_bodypart(BODY_ZONE_CHEST), BULLET) > 0, "Plating under the skin counted for nothing")
	TEST_ASSERT(hv_crit_cover_rating(both, both.get_bodypart(BODY_ZONE_CHEST), BULLET) > chest_rating, "Plating did not add to the vest")
	TEST_ASSERT(hv_crit_cover_rating(both, both.get_bodypart(BODY_ZONE_CHEST), BULLET, 20) < hv_crit_cover_rating(both, both.get_bodypart(BODY_ZONE_CHEST), BULLET), "Armour penetration did not cut the rating")
	TEST_ASSERT(istype(vest_only.hv_try_aimed_crit(vest_only.get_bodypart(BODY_ZONE_CHEST), BODY_ZONE_CHEST, WOUND_PIERCE, 30, 0, 0, NORTH, shot, attacker, 500), /datum/hv_crit/aorta), "A plain vest stopped the aorta crit")
	TEST_ASSERT(istype(plate_only.hv_try_aimed_crit(plate_only.get_bodypart(BODY_ZONE_CHEST), BODY_ZONE_CHEST, WOUND_PIERCE, 30, 0, 0, NORTH, shot, attacker, 500), /datum/hv_crit/aorta), "Plating alone stopped the aorta crit")
	TEST_ASSERT_NULL(both.hv_try_aimed_crit(both.get_bodypart(BODY_ZONE_CHEST), BODY_ZONE_CHEST, WOUND_PIERCE, 30, 0, 0, NORTH, shot, attacker, 500), "A vest over Slabskin did not stop the aorta crit")

	// the skull, with a toolbox: a cap worth 10 melee and Slabskin's 25 each fall short of the 30 that stops it, together they pass
	var/obj/item/storage/toolbox/toolbox = allocate(/obj/item/storage/toolbox)
	attacker.put_in_active_hand(toolbox)
	var/obj/item/clothing/head/soft/black/cap = allocate(/obj/item/clothing/head/soft/black)
	cap.set_armor_rating(MELEE, 10)
	var/obj/item/clothing/head/soft/black/other_cap = allocate(/obj/item/clothing/head/soft/black)
	other_cap.set_armor_rating(MELEE, 10)
	var/mob/living/carbon/human/cap_only = allocate(/mob/living/carbon/human/consistent)
	cap_only.equip_to_slot_if_possible(cap, ITEM_SLOT_HEAD)
	var/mob/living/carbon/human/plate_and_cap = plated_human()
	plate_and_cap.equip_to_slot_if_possible(other_cap, ITEM_SLOT_HEAD)
	var/mob/living/carbon/human/bare_plated = plated_human()
	TEST_ASSERT(istype(cap_only.hv_try_aimed_crit(cap_only.get_bodypart(BODY_ZONE_HEAD), BODY_ZONE_HEAD, WOUND_BLUNT, 25, 0, 0, NORTH, toolbox, attacker, 500), /datum/hv_crit/skull), "A thin cap stopped the skull crit")
	TEST_ASSERT(istype(bare_plated.hv_try_aimed_crit(bare_plated.get_bodypart(BODY_ZONE_HEAD), BODY_ZONE_HEAD, WOUND_BLUNT, 25, 0, 0, NORTH, toolbox, attacker, 500), /datum/hv_crit/skull), "Plating alone stopped the skull crit")
	TEST_ASSERT_NULL(plate_and_cap.hv_try_aimed_crit(plate_and_cap.get_bodypart(BODY_ZONE_HEAD), BODY_ZONE_HEAD, WOUND_BLUNT, 25, 0, 0, NORTH, toolbox, attacker, 500), "A cap over Slabskin did not stop the skull crit")

/// A skull crit on a victim in crit bursts the head, except on a body that cannot be dismembered (an Atlas frame).
/datum/unit_test/voidcrew_hv_crit_skull_nodismember/Run()
	var/mob/living/carbon/human/attacker = allocate(/mob/living/carbon/human/consistent)
	var/obj/item/storage/toolbox/toolbox = allocate(/obj/item/storage/toolbox)
	attacker.put_in_active_hand(toolbox)
	var/mob/living/carbon/human/dying = allocate(/mob/living/carbon/human/consistent)
	ADD_TRAIT(dying, TRAIT_NODISMEMBER, TRAIT_SOURCE_UNIT_TESTS)
	dying.set_stat(HARD_CRIT)
	var/obj/item/bodypart/head = dying.get_bodypart(BODY_ZONE_HEAD)
	dying.hv_try_aimed_crit(head, BODY_ZONE_HEAD, WOUND_BLUNT, 40, 0, 0, NORTH, toolbox, attacker, 500)
	TEST_ASSERT_EQUAL(dying.get_bodypart(BODY_ZONE_HEAD), head, "A skull crit burst the head of a body that cannot be dismembered")
	REMOVE_TRAIT(dying, TRAIT_NODISMEMBER, TRAIT_SOURCE_UNIT_TESTS)

/// Jaw crit: a broken jaw that mumbles speech and gives no brain traumas.
/datum/unit_test/voidcrew_hv_crit_jaw/Run()
	var/mob/living/carbon/human/victim = allocate(/mob/living/carbon/human/consistent)
	var/mob/living/carbon/human/attacker = allocate(/mob/living/carbon/human/consistent)
	var/obj/item/storage/toolbox/toolbox = allocate(/obj/item/storage/toolbox)
	attacker.put_in_active_hand(toolbox)
	var/obj/item/bodypart/head = victim.get_bodypart(BODY_ZONE_HEAD)

	var/datum/hv_crit/crit = victim.hv_try_aimed_crit(head, BODY_ZONE_PRECISE_MOUTH, WOUND_BLUNT, 20, 0, 0, NORTH, toolbox, attacker, 500)
	TEST_ASSERT(istype(crit, /datum/hv_crit/jaw), "A forced jaw crit did not land (got [crit])")
	var/datum/wound/blunt/bone/severe/hv_jaw/jaw = head.get_wound_type(/datum/wound/blunt/bone/severe/hv_jaw)
	TEST_ASSERT_NOTNULL(jaw, "No shattered jaw wound")
	TEST_ASSERT_NULL(jaw.active_trauma, "A broken jaw gave a brain trauma")
	var/sounds = "tttttttttttttttttttttttttttttttttttttttttttttttttttttttttttttt"
	TEST_ASSERT_NOTEQUAL(hv_crit_mumble(sounds), sounds, "Mumbled speech came out unchanged")

/// Humanoid basic mobs take crits as status effects, once each.
/datum/unit_test/voidcrew_hv_crit_basic_mob/Run()
	var/mob/living/basic/trooper/pirate/melee/pirate = allocate(/mob/living/basic/trooper/pirate/melee)
	var/mob/living/carbon/human/attacker = allocate(/mob/living/carbon/human/consistent)
	var/obj/item/knife/combat/knife = allocate(/obj/item/knife/combat)
	attacker.put_in_active_hand(knife)
	var/health_before = pirate.health

	var/datum/hv_crit/crit = pirate.hv_try_basic_crit(BODY_ZONE_HEAD, BODY_ZONE_HEAD, WOUND_SLASH, 25, 0, NORTH, knife, attacker, 500)
	TEST_ASSERT(istype(crit, /datum/hv_crit/throat), "A forced throat crit on a pirate did not land (got [crit])")
	TEST_ASSERT_NOTNULL(pirate.has_status_effect(/datum/status_effect/hv_crit_basic/bleed/throat), "The pirate is not bleeding from the throat")
	TEST_ASSERT(pirate.health < health_before, "The throat crit did not hurt the pirate")
	TEST_ASSERT_NULL(pirate.hv_try_basic_crit(BODY_ZONE_HEAD, BODY_ZONE_HEAD, WOUND_SLASH, 25, 0, NORTH, knife, attacker, 500), "The throat crit landed twice on the pirate")

	crit = pirate.hv_try_basic_crit(BODY_ZONE_HEAD, BODY_ZONE_PRECISE_MOUTH, WOUND_SLASH, 25, 0, NORTH, knife, attacker, 500)
	TEST_ASSERT(istype(crit, /datum/hv_crit/tongue), "A forced tongue crit on a pirate did not land (got [crit])")
	TEST_ASSERT(HAS_TRAIT(pirate, TRAIT_MUTE), "A pirate without a tongue can still talk")

/// A boss-sized humanoid takes capped crit damage and is not stunned by it.
/datum/unit_test/voidcrew_hv_crit_basic_boss_capped/Run()
	var/mob/living/basic/trooper/pirate/melee/boss = allocate(/mob/living/basic/trooper/pirate/melee)
	var/mob/living/carbon/human/attacker = allocate(/mob/living/carbon/human/consistent)
	var/obj/item/storage/toolbox/toolbox = allocate(/obj/item/storage/toolbox)
	attacker.put_in_active_hand(toolbox)
	boss.maxHealth = 2000
	boss.health = 2000

	var/datum/hv_crit/crit = boss.hv_try_basic_crit(BODY_ZONE_HEAD, BODY_ZONE_HEAD, WOUND_BLUNT, 25, 0, NORTH, toolbox, attacker, 500)
	TEST_ASSERT(istype(crit, /datum/hv_crit/skull), "A forced skull crit on a boss did not land (got [crit])")
	// 0.3 of the 200 health cap (HV_BASIC_CRIT_HEALTH_CAP), not of 2000
	TEST_ASSERT(boss.health >= 2000 - 61, "A skull crit took [2000 - boss.health] health from a boss")
	TEST_ASSERT(!boss.IsStun(), "A skull crit stunned a boss")
