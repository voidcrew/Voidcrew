// Hyperviolence (voidcrew/modules/hyperviolence/corpses/): NPC corpses that keep the fight, the
// gore on NPCs that keep their own body, and executions of downed and stunned NPCs.
// Literals carry the name of the voidcrew define they stand for in a comment.

/// The human corpse a basic mob just left on `spot`, which was not there in `before`. Cleaned up with the test.
/datum/unit_test/proc/hv_new_corpse(turf/spot, list/before)
	for(var/mob/living/carbon/human/body in spot)
		if(body in before)
			continue
		allocated += body
		return body
	return null

/// Everything of type `kind` within a few tiles of `spot` that was not in `before`, cleaned up with the test.
/datum/unit_test/proc/hv_new_things(turf/spot, kind, list/before)
	var/list/found = list()
	for(var/atom/movable/thing in range(7, spot))
		if(istype(thing, kind) && !(thing in before))
			found += thing
			allocated += thing
	return found

/// A pirate with no mind of its own to wander off with during the test.
/datum/unit_test/proc/hv_still_pirate()
	var/mob/living/basic/trooper/pirate/melee/pirate = allocate(/mob/living/basic/trooper/pirate/melee)
	QDEL_NULL(pirate.ai_controller)
	return pirate

/// Damage taken by body zone lands on the matching bodyparts of the corpse, with blood on the clothes over them.
/datum/unit_test/hv_npc_corpse_carries_fight

/datum/unit_test/hv_npc_corpse_carries_fight/Run()
	var/turf/spot = run_loc_floor_bottom_left
	var/mob/living/basic/trooper/pirate/melee/pirate = hv_still_pirate()
	TEST_ASSERT(pirate.hv_leaves_human_corpse, "A pirate trooper was not marked as leaving a human corpse")
	var/npc_health = pirate.maxHealth
	pirate.apply_damage(npc_health * 0.4, BRUTE, BODY_ZONE_HEAD, wound_bonus = CANT_WOUND)
	pirate.apply_damage(npc_health * 0.3, BRUTE, BODY_ZONE_L_ARM, wound_bonus = CANT_WOUND)
	var/list/before = range(7, spot)
	pirate.apply_damage(npc_health * 0.6, BRUTE, BODY_ZONE_CHEST, wound_bonus = CANT_WOUND)
	TEST_ASSERT(QDELETED(pirate), "The pirate did not die")

	var/mob/living/carbon/human/body = hv_new_corpse(spot, before)
	TEST_ASSERT_NOTNULL(body, "The pirate left no human corpse")
	TEST_ASSERT_EQUAL(body.stat, DEAD, "The pirate's corpse is alive")
	var/scale = body.maxHealth / npc_health
	var/obj/item/bodypart/head/head = body.get_bodypart(BODY_ZONE_HEAD)
	var/obj/item/bodypart/arm = body.get_bodypart(BODY_ZONE_L_ARM)
	var/obj/item/bodypart/chest = body.get_bodypart(BODY_ZONE_CHEST)
	var/obj/item/bodypart/leg = body.get_bodypart(BODY_ZONE_R_LEG)
	TEST_ASSERT(abs(head.brute_dam - npc_health * 0.4 * scale) < 1, "The head took [head.brute_dam] brute, not the pirate's [npc_health * 0.4 * scale]")
	TEST_ASSERT(abs(arm.brute_dam - npc_health * 0.3 * scale) < 1, "The left arm took [arm.brute_dam] brute, not the pirate's [npc_health * 0.3 * scale]")
	// The killing blow is struck at its real force, not scaled.
	TEST_ASSERT(abs(chest.brute_dam - npc_health * 0.6) < 1, "The chest took [chest.brute_dam] brute from a [npc_health * 0.6] killing blow")
	TEST_ASSERT_EQUAL(leg.brute_dam, 0, "A leg nobody hit took damage")
	// One heavy hit to the head opened the skull; 40 brute is a light skull wound (HV_SKULL_LIGHT_BRUTE 20, HV_SKULL_MEDIUM_BRUTE 45).
	TEST_ASSERT_EQUAL(head.hv_skull_wound, 1, "A 40-brute head hit left skull wound level [head.hv_skull_wound]")

	var/bloody_clothes = FALSE
	for(var/obj/item/clothing/worn in list(body.w_uniform, body.wear_suit))
		if(GET_ATOM_BLOOD_DNA_LENGTH(worn))
			bloody_clothes = TRUE
	TEST_ASSERT(bloody_clothes, "A corpse beaten in the chest and arm has clean clothes")
	TEST_ASSERT(GET_ATOM_BLOOD_DNA_LENGTH(body.head), "A corpse beaten about the head has a clean hat")

/// A heavy edged killing blow to the head takes the head off the corpse, through tg's dismember roll.
/datum/unit_test/hv_npc_corpse_katana_beheads

/datum/unit_test/hv_npc_corpse_katana_beheads/Run()
	var/turf/spot = run_loc_floor_bottom_left
	var/mob/living/basic/trooper/pirate/melee/pirate = hv_still_pirate()
	var/list/before = range(7, spot)
	// try_dismember() rolls the blow's damage plus half the head's damage share as a percent: 150 always takes it.
	pirate.apply_damage(150, BRUTE, BODY_ZONE_HEAD, sharpness = SHARP_EDGED, attack_direction = NORTH)
	TEST_ASSERT(QDELETED(pirate), "The pirate did not die")
	var/mob/living/carbon/human/body = hv_new_corpse(spot, before)
	TEST_ASSERT_NOTNULL(body, "The pirate left no human corpse")
	TEST_ASSERT_NULL(body.get_bodypart(BODY_ZONE_HEAD), "A katana kill to the head left the head on")
	var/list/heads = hv_new_things(spot, /obj/item/bodypart/head, before)
	TEST_ASSERT(length(heads), "A cut-off head left nothing on the floor")
	TEST_ASSERT("stump_head_blood" in body.hv_gore_states(), "The beheaded corpse has no neck stump")
	hv_new_things(spot, /obj/item/organ, before)

	// The roll is a chance, not a rule: a light cut on a fresh corpse can leave the head on.
	var/mob/living/carbon/human/consistent/dummy = allocate(/mob/living/carbon/human/consistent)
	dummy.death()
	var/obj/item/bodypart/head/dummy_head = dummy.get_bodypart(BODY_ZONE_HEAD)
	var/took_off = 0
	for(var/i in 1 to 20)
		if(QDELETED(dummy_head) || dummy_head.owner != dummy)
			break
		if(dummy.hv_roll_corpse_dismember(dummy_head, WOUND_SLASH, 1, 0, 0, NORTH))
			took_off++
	TEST_ASSERT_EQUAL(took_off, 0, "A 1-damage cut took a head off (tg's floor is 10)")

/// A huge crushing killing blow to the head bursts it (HV_CORPSE_HEAD_BURST_DAMAGE 60), and the brain survives.
/datum/unit_test/hv_npc_corpse_head_burst

/datum/unit_test/hv_npc_corpse_head_burst/Run()
	var/turf/spot = run_loc_floor_bottom_left
	var/mob/living/basic/trooper/pirate/melee/pirate = hv_still_pirate()
	var/list/before = range(7, spot)
	pirate.apply_damage(120, BRUTE, BODY_ZONE_HEAD, attack_direction = NORTH)
	var/mob/living/carbon/human/body = hv_new_corpse(spot, before)
	TEST_ASSERT_NOTNULL(body, "The pirate left no human corpse")
	TEST_ASSERT_NULL(body.get_bodypart(BODY_ZONE_HEAD), "A 120-damage crushing kill to the head left the head on")
	TEST_ASSERT(!length(hv_new_things(spot, /obj/item/bodypart/head, before)), "A burst head came off whole")
	TEST_ASSERT(length(hv_new_things(spot, /obj/item/organ/brain, before)), "Bursting the corpse's head destroyed the brain")
	hv_new_things(spot, /obj/item/organ, before)

/// Crits a pirate took come through on its corpse as the matching wound and missing organ.
/datum/unit_test/hv_npc_corpse_crits

/datum/unit_test/hv_npc_corpse_crits/Run()
	var/turf/spot = run_loc_floor_bottom_left
	var/mob/living/basic/trooper/pirate/melee/pirate = hv_still_pirate()
	pirate.apply_status_effect(/datum/status_effect/hv_crit_basic/tongue, NORTH)
	pirate.apply_status_effect(/datum/status_effect/hv_crit_basic/bleed/throat, NORTH)
	var/list/before = range(7, spot)
	pirate.apply_damage(200, BRUTE, BODY_ZONE_CHEST, wound_bonus = CANT_WOUND)
	var/mob/living/carbon/human/body = hv_new_corpse(spot, before)
	TEST_ASSERT_NOTNULL(body, "The pirate left no human corpse")
	var/obj/item/bodypart/head/head = body.get_bodypart(BODY_ZONE_HEAD)
	TEST_ASSERT_NULL(body.get_organ_slot(ORGAN_SLOT_TONGUE), "A pirate whose tongue was cut out left a corpse with a tongue")
	TEST_ASSERT_NOTNULL(head.get_wound_type(/datum/wound/slash/flesh/moderate/hv_tongue), "The corpse has no severed-tongue wound")
	TEST_ASSERT_NOTNULL(head.get_wound_type(/datum/wound/slash/flesh/critical/hv_carotid), "A pirate with a slit throat left a corpse with an unbroken throat")

/// A humanoid NPC is helpless in tg's states (stunned, cuffed, held), never because of its health.
/datum/unit_test/hv_npc_executable_states

/datum/unit_test/hv_npc_executable_states/Run()
	var/mob/living/basic/trooper/pirate/melee/pirate = hv_still_pirate()
	TEST_ASSERT(!pirate.hv_can_be_executed(), "A pirate at full health could be executed")
	pirate.adjustBruteLoss(pirate.maxHealth * 0.85)
	TEST_ASSERT(!pirate.hv_can_be_executed(), "A pirate on its feet at 15% health could be executed")
	pirate.Paralyze(30 SECONDS)
	TEST_ASSERT(pirate.hv_can_be_executed(), "A paralysed pirate could not be executed")

/// A point-blank click with the head selected executes someone down, and is a plain shot at someone standing.
/datum/unit_test/hv_head_aimed_execution

/datum/unit_test/hv_head_aimed_execution/Run()
	var/mob/living/carbon/human/consistent/gunner = allocate(/mob/living/carbon/human/consistent)
	var/mob/living/carbon/human/consistent/victim = allocate(/mob/living/carbon/human/consistent)
	ADD_TRAIT(victim, TRAIT_PIERCEIMMUNE, INNATE_TRAIT) // no stray shrapnel
	var/obj/item/gun/ballistic/automatic/pistol/gun = allocate(/obj/item/gun/ballistic/automatic/pistol)
	gun.can_misfire = FALSE
	gunner.put_in_active_hand(gun, forced = TRUE)
	gunner.zone_selected = BODY_ZONE_HEAD

	// Standing and free: tg's own point-blank shot, which a 9mm survives.
	gun.fire_gun(victim, gunner, TRUE, null)
	TEST_ASSERT_NOTEQUAL(victim.stat, DEAD, "A head-aimed shot at a standing target was an execution")

	victim.fully_heal(HEAL_ALL)
	victim.Knockdown(30 SECONDS)
	gun.fire_cd = FALSE // the standing shot above just fired; skip its cooldown
	gun.chambered.loaded_projectile.damage = 20 // doubled at the muzzle: 40, under the burst line
	var/round_damage = gun.chambered.loaded_projectile.damage * gun.projectile_damage_multiplier
	var/obj/item/bodypart/head/head = victim.get_bodypart(BODY_ZONE_HEAD)
	gun.fire_gun(victim, gunner, TRUE, null)
	TEST_ASSERT(head.brute_dam >= round_damage * 1.5, "A head-aimed point-blank shot at a downed target was not an execution ([head.brute_dam] head damage from a [round_damage] round)")
	TEST_ASSERT(head.hv_skull_wound >= 2, "A head-aimed light execution left no skull wound for its damage")

/// Executing a badly hurt, paralysed pirate carries the outcome to its corpse: a light round the skull, a heavy one the head.
/datum/unit_test/hv_npc_execution_corpse

/datum/unit_test/hv_npc_execution_corpse/Run()
	var/turf/spot = run_loc_floor_bottom_left
	var/mob/living/carbon/human/consistent/gunner = allocate(/mob/living/carbon/human/consistent)
	var/obj/item/gun/ballistic/automatic/pistol/gun = allocate(/obj/item/gun/ballistic/automatic/pistol)
	gun.can_misfire = FALSE
	gunner.put_in_active_hand(gun, forced = TRUE)
	gunner.zone_selected = BODY_ZONE_HEAD

	var/mob/living/basic/trooper/pirate/melee/pirate = hv_still_pirate()
	pirate.adjustBruteLoss(pirate.maxHealth * 0.85)
	pirate.Paralyze(30 SECONDS)
	TEST_ASSERT(gun.hv_execution_possible(gunner, pirate), "A paralysed pirate could not be executed")
	gun.chambered.loaded_projectile.damage = 20 // doubled at the muzzle: 40, under HV_EXECUTION_BURST_DAMAGE 50
	var/list/before = range(7, spot)
	TEST_ASSERT(gun.hv_fire_execution(gunner, pirate, null), "The execution shot did not fire")
	TEST_ASSERT(QDELETED(pirate), "The executed pirate did not die")
	var/mob/living/carbon/human/body = hv_new_corpse(spot, before)
	TEST_ASSERT_NOTNULL(body, "The executed pirate left no human corpse")
	var/obj/item/bodypart/head/head = body.get_bodypart(BODY_ZONE_HEAD)
	TEST_ASSERT_NOTNULL(head, "A light execution round took the corpse's head")
	TEST_ASSERT_EQUAL(head.hv_skull_wound, 3, "A light execution left the corpse no heavy skull wound")

	var/mob/living/basic/trooper/pirate/melee/second = hv_still_pirate()
	second.adjustBruteLoss(second.maxHealth * 0.85)
	second.Paralyze(30 SECONDS)
	gun.chambered.loaded_projectile.damage = 60 // doubled: 120
	gun.fire_cd = FALSE // the first execution just fired; skip its cooldown
	before = range(7, spot)
	TEST_ASSERT(gun.hv_fire_execution(gunner, second, null), "The heavy execution shot did not fire")
	body = hv_new_corpse(spot, before)
	TEST_ASSERT_NOTNULL(body, "The second executed pirate left no human corpse")
	TEST_ASSERT_NULL(body.get_bodypart(BODY_ZONE_HEAD), "A heavy execution round left the corpse's head on")
	hv_new_things(spot, /obj/item/organ, before)

/// An NPC that keeps its own body gives the deathgasp and shows a burst head on it, and coming back clears it.
/datum/unit_test/hv_npc_own_body_gore

/datum/unit_test/hv_npc_own_body_gore/Run()
	var/mob/living/basic/mission_survivor/survivor = allocate(/mob/living/basic/mission_survivor)
	QDEL_NULL(survivor.ai_controller)
	TEST_ASSERT(survivor.hv_gory_own_body, "A survivor (no DEL_ON_DEATH) did not get the body gore")
	survivor.icon = 'icons/mob/human/human.dmi' // its look is put on in the background
	var/datum/emote/living/deathgasp/gasp = /datum/emote/living/deathgasp
	survivor.apply_damage(survivor.maxHealth * 0.5, BRUTE, BODY_ZONE_HEAD)
	survivor.apply_damage(100, BRUTE, BODY_ZONE_HEAD, attack_direction = SOUTH)
	TEST_ASSERT_EQUAL(survivor.stat, DEAD, "The survivor did not die")
	TEST_ASSERT(!QDELETED(survivor), "The survivor's own body was deleted")
	TEST_ASSERT_EQUAL(survivor.death_message, initial(gasp.message), "The survivor did not give the player's deathgasp")
	TEST_ASSERT(survivor.hv_body_headless, "A 100-damage crushing kill to the head did not burst it")
	TEST_ASSERT_NOTNULL(survivor.get_filter("hv_headless"), "The burst head is still drawn")

	survivor.revive(ADMIN_HEAL_ALL)
	TEST_ASSERT(!survivor.hv_body_headless, "Coming back to life left the head off")
	TEST_ASSERT_NULL(survivor.get_filter("hv_headless"), "Coming back to life left the head cut out of the sprite")

/// The NPC takes its corpse's sex before its deathgasp, so the line and the body agree.
/datum/unit_test/hv_npc_deathgasp_matches_corpse

/datum/unit_test/hv_npc_deathgasp_matches_corpse/Run()
	var/mob/living/basic/trooper/pirate/melee/pirate = hv_still_pirate()
	var/mob/living/carbon/human/consistent/body = allocate(/mob/living/carbon/human/consistent)
	body.gender = pirate.gender == MALE ? FEMALE : MALE
	pirate.hv_npc_deathgasp(body, FALSE)
	TEST_ASSERT_EQUAL(pirate.gender, body.gender, "The pirate's deathgasp would not match its corpse's sex")
	var/datum/emote/living/deathgasp/gasp = /datum/emote/living/deathgasp
	TEST_ASSERT_EQUAL(pirate.death_message, initial(gasp.message), "The pirate's death line is not the player's deathgasp")

/// A wasteland hermit (a legacy simple mob with its corpse in its loot) hands its fight over too.
/datum/unit_test/hv_hermit_corpse

/datum/unit_test/hv_hermit_corpse/Run()
	var/turf/spot = run_loc_floor_bottom_left
	var/mob/living/simple_animal/hostile/asteroid/hermit/survivor/hermit = allocate(/mob/living/simple_animal/hostile/asteroid/hermit/survivor)
	hermit.toggle_ai(AI_OFF)
	TEST_ASSERT(hermit.hv_leaves_human_corpse, "A hermit was not marked as leaving a human corpse")
	var/list/before = range(7, spot)
	hermit.apply_damage(hermit.maxHealth * 0.4, BRUTE, BODY_ZONE_L_LEG, wound_bonus = CANT_WOUND)
	hermit.apply_damage(hermit.maxHealth, BRUTE, BODY_ZONE_CHEST, wound_bonus = CANT_WOUND)
	TEST_ASSERT(QDELETED(hermit), "The hermit did not die")
	var/mob/living/carbon/human/body = hv_new_corpse(spot, before)
	TEST_ASSERT_NOTNULL(body, "The hermit left no human corpse")
	var/obj/item/bodypart/leg = body.get_bodypart(BODY_ZONE_L_LEG)
	TEST_ASSERT(leg.brute_dam > 10, "The hermit's corpse lost the beating its leg took")
