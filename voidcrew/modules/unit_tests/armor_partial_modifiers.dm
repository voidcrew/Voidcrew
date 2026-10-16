/// Changing a subset of ratings must retain every other protection.
/datum/unit_test/armor_partial_modifiers/Run()
	var/datum/armor/base = get_armor_by_type(/datum/armor/none).generate_new_with_specific(list(MELEE = 30, BOMB = 60, FIRE = 100, ACID = 100))
	var/datum/armor/added = base.generate_new_with_modifiers(list(MELEE = 5))
	var/datum/armor/scaled = base.generate_new_with_multipliers(list(MELEE = 2))
	var/list/original = base.get_rating_list()
	for(var/rating in ARMOR_LIST_ALL())
		TEST_ASSERT_EQUAL(added.get_rating(rating), original[rating] + (rating == MELEE ? 5 : 0), "Additive upgrade changed [rating] incorrectly")
		TEST_ASSERT_EQUAL(scaled.get_rating(rating), original[rating] * (rating == MELEE ? 2 : 1), "Multiplicative upgrade changed [rating] incorrectly")
	TEST_ASSERT_EQUAL(base.get_rating(MELEE), 30, "Upgrading armor mutated the original")
	var/datum/armor/second_tier = added.generate_new_with_modifiers(list(MELEE = 5, BOMB = 10))
	TEST_ASSERT_EQUAL(second_tier.get_rating(BOMB), 70, "Second plating tier lost the original blast protection")
	TEST_ASSERT_EQUAL(second_tier.get_rating(FIRE), 100, "Second plating tier lost fire protection")
	qdel(second_tier)
	qdel(scaled)
	qdel(added)
	qdel(base)

/// Landed-hit accounting deliberately permits one fully protected, underfunded final hit.
/datum/unit_test/armor_partial_modifiers/nanites
	abstract_type = /datum/unit_test/armor_partial_modifiers/nanites
	var/mob/living/carbon/human/patient
	var/datum/component/nanites/swarm
	var/datum/nanite_program/hardening/hardening
	var/datum/nanite_program/refractive/refractive
	var/obj/projectile/projectile
	var/test_armor_flag = BULLET

/datum/unit_test/armor_partial_modifiers/nanites/proc/setup(safety = 50)
	patient = allocate(/mob/living/carbon/human/consistent)
	swarm = patient.AddComponent(/datum/component/nanites)
	STOP_PROCESSING(SSnanites, swarm)
	swarm.regen_rate = 0
	swarm.safety_threshold = safety
	hardening = allocate(/datum/nanite_program/hardening)
	refractive = allocate(/datum/nanite_program/refractive)
	TEST_ASSERT_EQUAL(swarm.add_program(null, hardening), 1, "Hardening installation failed") // COMPONENT_PROGRAM_INSTALLED
	TEST_ASSERT_EQUAL(swarm.add_program(null, refractive), 1, "Refractive installation failed")
	hardening.enable_passive_effect()
	refractive.enable_passive_effect()
	TEST_ASSERT(hardening.passive_enabled && refractive.passive_enabled, "Armor fixture did not activate")
	projectile = allocate(/obj/projectile)
	projectile.damage = 20
	projectile.damage_type = BRUTE
	projectile.wound_bonus = CANT_WOUND

/// Keep endurance independent of survival and limb caps, without yielding between hits.
/datum/unit_test/armor_partial_modifiers/nanites/proc/hit(armor_flag = test_armor_flag, penetration = 0, weak = FALSE, cap = 90)
	patient.heal_overall_damage(1000, 1000)
	projectile.armor_flag = armor_flag
	projectile.damage_type = (armor_flag == LASER || armor_flag == ENERGY) ? BURN : BRUTE
	projectile.armour_penetration = penetration
	projectile.weak_against_armour = weak
	var/blocked = min(cap, patient.run_armor_check(BODY_ZONE_CHEST, armor_flag, armour_penetration = penetration, silent = TRUE, weak_against_armour = weak))
	return patient.apply_damage(20, projectile.damage_type, BODY_ZONE_CHEST, blocked, wound_bonus = CANT_WOUND, attacking_item = projectile, wound_clothing = FALSE)

/datum/unit_test/armor_partial_modifiers/nanites/endurance/Run()
	setup()
	var/start_tick = world.time
	for(var/shot in 1 to 8)
		TEST_ASSERT(abs(hit() - 14) < 0.01, "Funded bullet [shot] did not deal 14 damage")
		TEST_ASSERT(abs(swarm.nanite_volume - (100 - 6 * shot)) < 0.01, "Bullet [shot] did not cost 6 nanites")
	TEST_ASSERT(abs(hit() - 14) < 0.01, "Underfunded ninth bullet lost its accepted full protection")
	TEST_ASSERT_EQUAL(swarm.nanite_volume, 50, "Ninth bullet crossed the safety threshold")
	TEST_ASSERT(!hardening.passive_enabled && !refractive.passive_enabled, "Depletion did not immediately remove both armor contributions")
	TEST_ASSERT_EQUAL(patient.getarmor(BODY_ZONE_CHEST, BULLET), 0, "Depleted Hardening retained armor")
	TEST_ASSERT_EQUAL(patient.getarmor(BODY_ZONE_CHEST, LASER), 0, "Depleted Refractive retained armor")
	TEST_ASSERT(abs(hit() - 20) < 0.01, "A second underfunded hit received free armor")
	TEST_ASSERT_EQUAL(swarm.nanite_volume, 50, "Unarmored hit spent reserved nanites")
	TEST_ASSERT_EQUAL(world.time, start_tick, "Endurance fixture yielded between hits")

/datum/unit_test/armor_partial_modifiers/nanites/endurance/refractive
	test_armor_flag = LASER

/datum/unit_test/armor_partial_modifiers/nanites/safety_zero/Run()
	setup(0)
	for(var/shot in 1 to 16)
		TEST_ASSERT(abs(hit() - 14) < 0.01, "Zero-safety bullet [shot] did not receive full armor")
		TEST_ASSERT(abs(swarm.nanite_volume - (100 - 6 * shot)) < 0.01, "Zero-safety bullet [shot] had the wrong cost")
	TEST_ASSERT(abs(hit() - 14) < 0.01, "Underfunded seventeenth bullet lost full protection")
	TEST_ASSERT_NULL(patient.GetComponent(/datum/component/nanites), "An empty zero-safety swarm was not removed")
	TEST_ASSERT_EQUAL(patient.getarmor(BODY_ZONE_CHEST, BULLET), 0, "Deleting the empty swarm retained armor")
	TEST_ASSERT(abs(hit() - 20) < 0.01, "A hit after zero-safety depletion received armor")

/datum/unit_test/armor_partial_modifiers/nanites/safety_zero/refractive
	test_armor_flag = LASER

/datum/unit_test/armor_partial_modifiers/nanites/channels/Run()
	setup()
	for(var/armor_flag in list(MELEE, BULLET, LASER, ENERGY))
		var/before = swarm.nanite_volume
		TEST_ASSERT(abs(hit(armor_flag) - 14) < 0.01, "[armor_flag] did not receive the existing +30 armor")
		TEST_ASSERT(abs(before - swarm.nanite_volume - 6) < 0.01, "[armor_flag] was billed to both programs or to neither")
	var/before = swarm.nanite_volume
	for(var/armor_flag in list(BOMB, FIRE, ACID))
		hit(armor_flag)
	TEST_ASSERT_EQUAL(swarm.nanite_volume, before, "Unprotected armor categories spent nanites")
	patient.apply_damage(5, TOX, blocked = 30)
	patient.apply_damage(20, BRUTE, BODY_ZONE_CHEST, 0, TRUE, wound_bonus = CANT_WOUND)
	patient.apply_damage(0, BRUTE, BODY_ZONE_CHEST, 30)
	patient.apply_damage(-20, BRUTE, BODY_ZONE_CHEST, 30)
	var/obj/item/bodypart/chest = patient.get_bodypart(BODY_ZONE_CHEST)
	chest.receive_damage(20, blocked = 30, wound_bonus = CANT_WOUND)
	TEST_ASSERT_EQUAL(swarm.nanite_volume, before, "Forced, nonphysical, zero, healing or direct limb damage spent nanites")

/// Exercise the real forced spread hit with a nonzero armor check, without relying on RNG.
/datum/action/cooldown/cyberware/piledriver_leap/nanite_accounting_test/should_spread_crush_damage()
	return TRUE

/datum/unit_test/armor_partial_modifiers/nanites/forced_piledriver/Run()
	setup()
	var/mob/living/carbon/human/jumper = allocate(/mob/living/carbon/human/consistent)
	var/obj/item/organ/cyberimp/cyberware/piledriver/frame = allocate(/obj/item/organ/cyberimp/cyberware/piledriver)
	var/datum/action/cooldown/cyberware/piledriver_leap/nanite_accounting_test/leap = allocate(/datum/action/cooldown/cyberware/piledriver_leap/nanite_accounting_test, frame)
	TEST_ASSERT_EQUAL(patient.run_armor_check(attack_flag = MELEE, silent = TRUE), 30, "Forced-hit fixture has no armor to bypass")
	var/before = swarm.nanite_volume
	leap.crush_victim(jumper, patient)
	TEST_ASSERT(abs(patient.getBruteLoss() - 60) <= DAMAGE_PRECISION, "Forced Piledriver spread damage was reduced by armor") // CYBERWARE_PILEDRIVER_CRUSH_DAMAGE
	TEST_ASSERT_EQUAL(swarm.nanite_volume, before, "Forced Piledriver damage spent nanites on bypassed armor")
	TEST_ASSERT(hardening.passive_enabled && refractive.passive_enabled, "Forced damage disabled funded nanite armor")

/datum/armor/nanite_accounting_test
	melee = 75
	bullet = 75
	laser = 75
	energy = 75

/obj/item/clothing/suit/nanite_accounting_test
	body_parts_covered = CHEST
	armor_type = /datum/armor/nanite_accounting_test

/datum/unit_test/armor_partial_modifiers/nanites/clothing_chrome/Run()
	setup()
	var/obj/item/clothing/suit/nanite_accounting_test/suit = allocate(/obj/item/clothing/suit/nanite_accounting_test)
	TEST_ASSERT(patient.equip_to_slot_if_possible(suit, ITEM_SLOT_OCLOTHING), "Could not equip armor fixture")
	TEST_ASSERT(abs(hit() - 3.5) < 0.01, "75 bullet clothing did not combine multiplicatively")
	TEST_ASSERT(abs(swarm.nanite_volume - 98.5) < 0.01, "Nanites were charged for clothing's protection")
	var/obj/item/organ/cyberimp/cyberware/dermal_mesh/mesh = allocate(/obj/item/organ/cyberimp/cyberware/dermal_mesh)
	mesh.Insert(patient, TRUE)
	TEST_ASSERT_EQUAL(patient.physiology.armor.get_rating(BULLET), 45, "Chrome fixture did not stack with Hardening")
	TEST_ASSERT(abs(hit() - 2.75) < 0.06, "Clothing/chrome/nanite armor stack changed damage")
	TEST_ASSERT(abs(swarm.nanite_volume - 97) < 0.01, "Nanites paid for chrome's armor contribution")
	TEST_ASSERT(abs(hit(BULLET, 20) - 3.4375) < 0.06, "Penetration changed the clothing/chrome stack incorrectly")
	TEST_ASSERT(abs(swarm.nanite_volume - 95.125) < 0.01, "Penetration billed clothing/chrome to nanites")
	hardening.disable_passive_effect()
	TEST_ASSERT_EQUAL(patient.physiology.armor.get_rating(BULLET), 15, "Disabling nanites removed chrome armor")
	mesh.Remove(patient, TRUE)
	TEST_ASSERT_EQUAL(patient.physiology.armor.get_rating(BULLET), 0, "Removing chrome left phantom armor")

/datum/unit_test/armor_partial_modifiers/nanites/penetration_caps_modifiers/Run()
	setup()
	TEST_ASSERT(abs(hit(BULLET, 20) - 17.5) < 0.01, "Penetration did not reduce nanite armor")
	TEST_ASSERT(abs(swarm.nanite_volume - 97.5) < 0.01, "Penetrating bullet had the wrong drain")
	TEST_ASSERT(abs(hit(BULLET, 100) - 20) < 0.01, "Full penetration retained nanite protection")
	TEST_ASSERT(abs(swarm.nanite_volume - 97.5) < 0.01, "Full penetration spent nanites")
	TEST_ASSERT(abs(hit(BULLET, 0, TRUE) - 8) < 0.01, "Armor weakness modifier was lost")
	TEST_ASSERT(abs(swarm.nanite_volume - 85.5) < 0.01, "Armor weakness had the wrong drain")
	patient.physiology.brute_mod = 0.5
	TEST_ASSERT(abs(hit() - 7) < 0.01, "Physiology damage modifier was lost")
	TEST_ASSERT(abs(swarm.nanite_volume - 82.5) < 0.01, "Damage modifier was not reflected in armor cost")
	patient.physiology.brute_mod = 1
	patient.physiology.armor = patient.physiology.armor.generate_new_with_modifiers(list(BULLET = 80))
	TEST_ASSERT(abs(hit() - 2) < 0.01, "Projectile armor cap changed")
	TEST_ASSERT(abs(swarm.nanite_volume - 80.5) < 0.01, "Nanites paid for protection above the armor cap")
	patient.physiology.armor = patient.physiology.armor.generate_new_with_modifiers(list(BULLET = 15))
	hit()
	TEST_ASSERT(abs(swarm.nanite_volume - 80.5) < 0.01, "Already capped non-nanite armor was billed to the swarm")

/datum/unit_test/armor_partial_modifiers/nanites/upkeep_lifecycle/Run()
	setup()
	swarm.nanite_volume = 52
	hardening.on_process()
	TEST_ASSERT_EQUAL(swarm.nanite_volume, 51, "Hardening upkeep changed")
	TEST_ASSERT(hardening.passive_enabled && refractive.passive_enabled, "Funded armor was disabled early")
	refractive.on_process()
	TEST_ASSERT_EQUAL(swarm.nanite_volume, 50, "Refractive upkeep changed")
	TEST_ASSERT(!hardening.passive_enabled && !refractive.passive_enabled, "Upkeep reaching safety retained armor")
	hardening.on_process()
	TEST_ASSERT_EQUAL(swarm.nanite_volume, 50, "Unfunded upkeep crossed safety")
	swarm.nanite_volume = 50.5
	hardening.on_process()
	TEST_ASSERT_EQUAL(swarm.nanite_volume, 50.5, "Partial upkeep was consumed")
	TEST_ASSERT(!hardening.passive_enabled, "Partial upkeep enabled armor")
	swarm.nanite_volume = 51
	hardening.on_process()
	TEST_ASSERT_EQUAL(swarm.nanite_volume, 50, "Exact upkeep was not consumed")
	TEST_ASSERT(!hardening.passive_enabled, "Upkeep leaving no hit reserve enabled armor")
	swarm.nanite_volume = 51.25
	hardening.on_process()
	TEST_ASSERT(hardening.passive_enabled, "Regenerated armor failed to resume through upkeep")
	TEST_ASSERT_EQUAL(swarm.nanite_volume, 50.25, "Resuming skipped upkeep")
	TEST_ASSERT(abs(hit() - 14) < 0.01, "Fractionally funded hit lost full protection")
	TEST_ASSERT_EQUAL(swarm.nanite_volume, 50, "Fractionally funded hit crossed safety")
	TEST_ASSERT(!hardening.passive_enabled, "Fractionally funded armor remained enabled")
	swarm.nanite_volume = 100
	hardening.enable_passive_effect()
	hardening.enable_passive_effect()
	TEST_ASSERT_EQUAL(patient.getarmor(BODY_ZONE_CHEST, BULLET), 30, "Repeated activation stacked armor")
	hardening.disable_passive_effect()
	hardening.disable_passive_effect()
	TEST_ASSERT_EQUAL(patient.getarmor(BODY_ZONE_CHEST, BULLET), 0, "Repeated deactivation subtracted other armor")
	hardening.enable_passive_effect()
	refractive.enable_passive_effect()
	qdel(swarm)
	TEST_ASSERT_EQUAL(patient.getarmor(BODY_ZONE_CHEST, BULLET), 0, "Swarm removal retained Hardening")
	TEST_ASSERT_EQUAL(patient.getarmor(BODY_ZONE_CHEST, LASER), 0, "Swarm removal retained Refractive")

/datum/unit_test/armor_partial_modifiers/nanites/proc/block_hit()
	SIGNAL_HANDLER
	return SUCCESSFUL_BLOCK

/datum/unit_test/armor_partial_modifiers/nanites/queries_misses_blocks/Run()
	setup()
	for(var/query in 1 to 20)
		patient.getarmor(BODY_ZONE_CHEST, BULLET)
		patient.run_armor_check(BODY_ZONE_CHEST, MELEE, silent = TRUE)
		patient.get_incoming_damage_modifier(14, BRUTE, BODY_ZONE_CHEST)
	TEST_ASSERT_EQUAL(swarm.nanite_volume, 100, "Pure armor/modifier queries spent nanites")
	var/mob/living/carbon/human/attacker = allocate(/mob/living/carbon/human/consistent)
	attacker.set_combat_mode(TRUE)
	ADD_TRAIT(attacker, TRAIT_PERFECT_ATTACKER, TRAIT_SOURCE_UNIT_TESTS)
	// A zero lower bound selects the guaranteed miss branch, even with a nonzero upper bound.
	for(var/obj/item/bodypart/arm in attacker.hand_bodyparts)
		arm.unarmed_damage_low = 0
		arm.unarmed_damage_high = 20
	patient.attack_hand(attacker, list(RIGHT_CLICK = FALSE))
	TEST_ASSERT_EQUAL(patient.getBruteLoss(), 0, "Miss fixture landed a hit")
	TEST_ASSERT_EQUAL(swarm.nanite_volume, 100, "Missed punch spent nanites")
	RegisterSignal(patient, COMSIG_LIVING_CHECK_BLOCK, PROC_REF(block_hit))
	var/obj/item/storage/toolbox/weapon = allocate(/obj/item/storage/toolbox)
	weapon.force = 20
	weapon.throwforce = 20
	patient.attacked_by(weapon, attacker)
	patient.hitby(weapon)
	projectile.armor_flag = BULLET
	patient.bullet_act(projectile, BODY_ZONE_CHEST)
	TEST_ASSERT_EQUAL(patient.getBruteLoss(), 0, "Shield-block fixture allowed damage")
	TEST_ASSERT_EQUAL(swarm.nanite_volume, 100, "Shield-blocked melee, thrown or projectile attack spent nanites")
	UnregisterSignal(patient, COMSIG_LIVING_CHECK_BLOCK)
	patient.attacked_by(weapon, attacker)
	TEST_ASSERT(abs(swarm.nanite_volume - 94) < 0.01, "Landed item attack was not charged once")
	patient.heal_overall_damage(1000, 1000)
	patient.hitby(weapon, hitpush = FALSE)
	TEST_ASSERT(abs(swarm.nanite_volume - 88) < 0.01, "Landed thrown attack was not charged once")
	for(var/obj/item/bodypart/arm in attacker.hand_bodyparts)
		arm.unarmed_damage_low = 20
		arm.unarmed_damage_high = 20
	patient.heal_overall_damage(1000, 1000)
	patient.attack_hand(attacker, list(RIGHT_CLICK = FALSE))
	TEST_ASSERT(abs(swarm.nanite_volume - 82) < 0.01, "Landed unarmed attack was not charged once")
	patient.heal_overall_damage(1000, 1000)
	patient.apply_projectile_effects(projectile, BODY_ZONE_CHEST, patient.check_projectile_armor(BODY_ZONE_CHEST, projectile, TRUE))
	TEST_ASSERT(abs(swarm.nanite_volume - 76) < 0.01, "Landed projectile effects were not charged once")
