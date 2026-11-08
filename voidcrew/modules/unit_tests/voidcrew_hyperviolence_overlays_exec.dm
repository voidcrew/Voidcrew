// Hyperviolence (voidcrew/modules/hyperviolence/overlays_exec/): stump and skull-wound overlays,
// gun executions. Voidcrew defines are not visible here; literals carry the define name in a comment.

/// Every icon state the gore overlays can ask for exists in the sheet.
/datum/unit_test/hv_gore_icon_states

/datum/unit_test/hv_gore_icon_states/Run()
	var/gore_icon = 'voidcrew/modules/hyperviolence/overlays_exec/icons/gore_overlays.dmi' // HV_GORE_ICON
	var/list/prefixes = list()
	for(var/zone in list(BODY_ZONE_HEAD, BODY_ZONE_L_ARM, BODY_ZONE_R_ARM, BODY_ZONE_L_LEG, BODY_ZONE_R_LEG))
		prefixes += "stump_[zone]"
	for(var/level in 1 to 3)
		prefixes += hv_skull_wound_state(level)
	for(var/prefix in prefixes)
		for(var/part in list("blood", "bone"))
			TEST_ASSERT(icon_exists(gore_icon, "[prefix]_[part]"), "Gore sheet is missing [prefix]_[part]")

/// A torn-off limb leaves a wet stump, a clean removal a healed one, and a limb put back clears it.
/datum/unit_test/hv_stump_overlays

/datum/unit_test/hv_stump_overlays/Run()
	var/mob/living/carbon/human/consistent/dummy = allocate(/mob/living/carbon/human/consistent)

	var/obj/item/bodypart/arm = dummy.get_bodypart(BODY_ZONE_L_ARM)
	TEST_ASSERT(arm.dismember(), "The left arm would not come off")
	TEST_ASSERT(dummy.hv_stump_is_fresh(BODY_ZONE_L_ARM), "A torn-off arm did not leave a wet stump")
	var/list/states = dummy.hv_gore_states()
	TEST_ASSERT("stump_l_arm_blood" in states, "A torn-off arm drew no bloody stump: [english_list(states)]")
	TEST_ASSERT("stump_l_arm_bone" in states, "A torn-off arm drew no bone in its stump")

	var/obj/item/bodypart/arm/left/new_arm = allocate(/obj/item/bodypart/arm/left)
	TEST_ASSERT(new_arm.try_attach_limb(dummy), "Could not attach a new left arm")
	TEST_ASSERT(!("stump_l_arm_blood" in dummy.hv_gore_states()), "The stump stayed after a new arm went on")
	TEST_ASSERT(isnull(LAZYACCESS(dummy.hv_stump_torn_at, BODY_ZONE_L_ARM)), "The torn-off time stayed after a new arm went on")

	// A clean removal (surgery, not dismemberment) shows a healed stump straight away.
	var/obj/item/bodypart/leg = dummy.get_bodypart(BODY_ZONE_R_LEG)
	leg.drop_limb()
	TEST_ASSERT(!dummy.hv_stump_is_fresh(BODY_ZONE_R_LEG), "A clean removal counted as a torn-off limb")
	var/image/leg_blood
	for(var/image/gore_image as anything in dummy.hv_gore_overlays)
		if(gore_image.icon_state == "stump_r_leg_blood")
			leg_blood = gore_image
	TEST_ASSERT_NOTNULL(leg_blood, "A removed leg drew no stump")
	TEST_ASSERT_EQUAL(leg_blood.alpha, 140, "A healed stump was drawn wet") // HV_STUMP_OLD_ALPHA

	var/obj/item/bodypart/head = dummy.get_bodypart(BODY_ZONE_HEAD)
	TEST_ASSERT(head.dismember(), "The head would not come off")
	TEST_ASSERT("stump_head_blood" in dummy.hv_gore_states(), "Decapitation drew no neck stump")

/// One heavy hit opens a skull wound, more damage widens it, healing closes it; small hits never open one.
/datum/unit_test/hv_skull_wound

/datum/unit_test/hv_skull_wound/Run()
	var/mob/living/carbon/human/consistent/dummy = allocate(/mob/living/carbon/human/consistent)
	var/obj/item/bodypart/head/head = dummy.get_bodypart(BODY_ZONE_HEAD)

	for(var/i in 1 to 3)
		dummy.apply_damage(10, BRUTE, BODY_ZONE_HEAD, wound_bonus = CANT_WOUND)
	TEST_ASSERT_EQUAL(head.hv_skull_wound, 0, "Small hits opened a skull wound")

	dummy.apply_damage(25, BRUTE, BODY_ZONE_HEAD, wound_bonus = CANT_WOUND) // 55 brute: medium (HV_SKULL_MEDIUM_BRUTE 45)
	TEST_ASSERT_EQUAL(head.hv_skull_wound, 2, "A heavy hit on a hurt head did not open a medium skull wound")
	TEST_ASSERT("medium_headshot_blood" in dummy.hv_gore_states(), "The medium skull wound was not drawn")

	dummy.apply_damage(30, BRUTE, BODY_ZONE_HEAD, wound_bonus = CANT_WOUND) // 85 brute: heavy (HV_SKULL_HEAVY_BRUTE 80)
	TEST_ASSERT_EQUAL(head.hv_skull_wound, 3, "More damage did not widen the skull wound")
	TEST_ASSERT("heavy_headshot_blood" in dummy.hv_gore_states(), "The heavy skull wound was not drawn")

	dummy.heal_overall_damage(brute = 70) // 15 brute: under HV_SKULL_LIGHT_BRUTE 20
	TEST_ASSERT_EQUAL(head.hv_skull_wound, 0, "Healing did not close the skull wound")
	TEST_ASSERT(!head.hv_skull_open, "A healed skull stayed open")
	for(var/state in dummy.hv_gore_states())
		TEST_ASSERT(!findtext(state, "headshot"), "A healed head still draws [state]")

/// Only a downed, cuffed or held humanoid can be executed. The round is the gun's own, doubled at the
/// muzzle and dealt through tg's damage: it kills someone in crit, and a healthy target survives it.
/datum/unit_test/hv_gun_execution

/datum/unit_test/hv_gun_execution/Run()
	var/mob/living/carbon/human/consistent/gunner = allocate(/mob/living/carbon/human/consistent)
	var/mob/living/carbon/human/consistent/victim = allocate(/mob/living/carbon/human/consistent)
	ADD_TRAIT(victim, TRAIT_PIERCEIMMUNE, INNATE_TRAIT) // no stray shrapnel
	var/obj/item/gun/ballistic/automatic/pistol/gun = allocate(/obj/item/gun/ballistic/automatic/pistol)
	gun.can_misfire = FALSE
	gunner.put_in_active_hand(gun, forced = TRUE)
	gunner.zone_selected = BODY_ZONE_PRECISE_MOUTH

	TEST_ASSERT(!gun.hv_execution_possible(gunner, victim), "A standing, free target could be executed")
	TEST_ASSERT(!gun.hv_execution_possible(gunner, gunner), "The shooter could execute themselves")
	victim.Knockdown(30 SECONDS)
	TEST_ASSERT(gun.hv_execution_possible(gunner, victim), "A downed target could not be executed")

	// The real click path: a point-blank, mouth-aimed shot, the wind-up, then the shot.
	gun.chambered.loaded_projectile.damage = 20 // doubled at the muzzle: 40, under the burst line
	var/round_damage = gun.chambered.loaded_projectile.damage * gun.projectile_damage_multiplier
	var/obj/item/bodypart/head/head = victim.get_bodypart(BODY_ZONE_HEAD)
	gun.fire_gun(victim, gunner, TRUE, null)
	TEST_ASSERT_EQUAL(victim.get_bodypart(BODY_ZONE_HEAD), head, "A light execution took the head off")
	TEST_ASSERT(head.brute_dam >= round_damage * 1.5, "The execution round was not boosted at the muzzle ([head.brute_dam] head damage from a [round_damage] round)")
	TEST_ASSERT_NOTEQUAL(victim.stat, DEAD, "A light execution killed a healthy target with more than its round's damage")
	TEST_ASSERT(head.hv_skull_wound >= 2, "A light execution left no skull wound for its damage")
	TEST_ASSERT_NOTNULL(victim.get_organ_slot(ORGAN_SLOT_BRAIN), "A light execution destroyed the brain")
	TEST_ASSERT_EQUAL(gun.projectile_damage_multiplier, initial(gun.projectile_damage_multiplier), "The point-blank boost stayed on the gun")

	// Someone in hard crit dies of the same round's real damage.
	var/mob/living/carbon/human/consistent/dying = allocate(/mob/living/carbon/human/consistent)
	ADD_TRAIT(dying, TRAIT_PIERCEIMMUNE, INNATE_TRAIT)
	dying.apply_damage(150, BRUTE, BODY_ZONE_CHEST, wound_bonus = CANT_WOUND)
	TEST_ASSERT(dying.stat >= SOFT_CRIT, "Test fixture: 150 brute did not put the target in crit")
	gun.fire_cd = FALSE
	TEST_ASSERT(gun.hv_fire_execution(gunner, dying, null), "The execution shot did not fire")
	TEST_ASSERT_EQUAL(dying.stat, DEAD, "A light execution of someone in hard crit did not kill them")

/// A heavy enough round bursts the head, and the brain survives it.
/datum/unit_test/hv_gun_execution_burst

/datum/unit_test/hv_gun_execution_burst/Run()
	var/mob/living/carbon/human/consistent/gunner = allocate(/mob/living/carbon/human/consistent)
	var/mob/living/carbon/human/consistent/victim = allocate(/mob/living/carbon/human/consistent)
	ADD_TRAIT(victim, TRAIT_PIERCEIMMUNE, INNATE_TRAIT)
	var/obj/item/gun/ballistic/automatic/pistol/gun = allocate(/obj/item/gun/ballistic/automatic/pistol)
	gun.can_misfire = FALSE
	gunner.put_in_active_hand(gun, forced = TRUE)
	gunner.zone_selected = BODY_ZONE_PRECISE_MOUTH
	gun.chambered.loaded_projectile.damage = 60 // doubled at the muzzle: over HV_EXECUTION_BURST_DAMAGE 50
	ADD_TRAIT(victim, TRAIT_RESTRAINED, TRAIT_SOURCE_UNIT_TESTS)
	TEST_ASSERT(gun.hv_execution_possible(gunner, victim), "A restrained target could not be executed")

	TEST_ASSERT(gun.hv_fire_execution(gunner, victim, null), "The execution shot did not fire")
	TEST_ASSERT_NULL(victim.get_bodypart(BODY_ZONE_HEAD), "A heavy round did not burst the head")
	TEST_ASSERT_EQUAL(victim.stat, DEAD, "The executed target survived")
	var/found_brain = FALSE
	for(var/obj/item/organ/brain/brain in range(7, victim))
		found_brain = TRUE
	TEST_ASSERT(found_brain, "Bursting the head destroyed the brain")

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

/// A human NPC is helpless only in tg's states (stunned, cuffed, held, down), never because of its health.
/datum/unit_test/hv_npc_executable_states

/datum/unit_test/hv_npc_executable_states/Run()
	var/mob/living/carbon/human/npc/npc = allocate(/mob/living/carbon/human/npc)
	QDEL_NULL(npc.ai_controller)
	TEST_ASSERT(!npc.hv_can_be_executed(), "An NPC at full health could be executed")
	npc.apply_damage(85, BRUTE, BODY_ZONE_CHEST, wound_bonus = CANT_WOUND)
	TEST_ASSERT(npc.stat == CONSCIOUS, "The test NPC fell over at 15 health")
	TEST_ASSERT(!npc.hv_can_be_executed(), "An NPC on its feet at 15 health could be executed")
	npc.Paralyze(30 SECONDS)
	TEST_ASSERT(npc.hv_can_be_executed(), "A paralysed NPC could not be executed")

/// The death throes, given by every human NPC that dies (human_npc_barks.dm), end where they began: the
/// body's real transform and offsets are untouched, so tg's lying pose stays right.
/datum/unit_test/hv_death_throes_end_where_they_began

/datum/unit_test/hv_death_throes_end_where_they_began/Run()
	var/mob/living/carbon/human/consistent/body = allocate(/mob/living/carbon/human/consistent)
	body.death()
	var/matrix/lying = matrix(body.transform)
	var/pixel_before = body.pixel_w
	body.hv_death_throes(rise = TRUE)
	TEST_ASSERT_EQUAL(body.pixel_w, pixel_before, "The death throes left the body [body.pixel_w - pixel_before] pixels aside")
	var/matrix/after = body.transform
	TEST_ASSERT(abs(after.a - lying.a) < 0.01 && abs(after.b - lying.b) < 0.01 && abs(after.d - lying.d) < 0.01 && abs(after.e - lying.e) < 0.01, "The death throes left the body turned differently from how tg laid it down")
