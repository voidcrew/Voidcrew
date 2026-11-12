// Package: W5 plasma burn wounds. Unit tests for voidcrew/modules/plasma_weapons/plasma_wound*.dm.
// The tier subtypes, the surgery and its step are looked up with text2path so this file compiles
// against the W0 seams; a missing type fails the test that needs it.

/// Shared helpers for the plasma burn wound tests.
/datum/unit_test/voidcrew_plasma_wounds
	abstract_type = /datum/unit_test/voidcrew_plasma_wounds

/datum/unit_test/voidcrew_plasma_wounds/proc/turf_at(dx, dy)
	return locate(run_loc_floor_bottom_left.x + dx, run_loc_floor_bottom_left.y + dy, run_loc_floor_bottom_left.z)

/// A bolt sitting on `where` that came from there, ready to be handed to bullet_act().
/datum/unit_test/voidcrew_plasma_wounds/proc/make_bolt(bolt_type, turf/where, zone = BODY_ZONE_CHEST)
	var/obj/projectile/energy/plasma_bolt/bolt = allocate(bolt_type, where)
	bolt.starting = where
	bolt.def_zone = zone
	return bolt

/// The plasma burn type for a tier name ("moderate", "severe", "critical"), or null with a failure.
/datum/unit_test/voidcrew_plasma_wounds/proc/tier_path(tier)
	var/path = text2path("/datum/wound/burn/flesh/plasma/[tier]")
	if(!path)
		TEST_FAIL("/datum/wound/burn/flesh/plasma/[tier] does not exist")
	return path

/// Forces the plasma burn of `tier` onto `limb` and returns it.
/datum/unit_test/voidcrew_plasma_wounds/proc/give_burn(obj/item/bodypart/limb, tier)
	var/path = tier_path(tier)
	if(!path)
		return null
	limb.force_wound_upwards(path)
	var/datum/wound/burn/flesh/plasma/burn = limb.get_wound_type(/datum/wound/burn/flesh/plasma)
	if(!istype(burn, path))
		TEST_FAIL("could not give a [limb.plaintext_zone] a [tier] plasma burn")
		return null
	return burn

/// The burn wounds (tg and plasma) on a limb.
/datum/unit_test/voidcrew_plasma_wounds/proc/burns_on(obj/item/bodypart/limb)
	. = list()
	for(var/datum/wound/burn/flesh/burn in limb.wounds)
		. += burn

/datum/unit_test/voidcrew_plasma_wounds/proc/clean_up(turf/around)
	for(var/obj/item/plasma_slag/bead in range(5, around))
		qdel(bead)
	for(var/obj/effect/decal/cleanable/leftover in range(5, around))
		qdel(leftover)

/// 1. A plasma bolt rolls the plasma tier for its roll; the same roll with no source gives tg's burn.
/datum/unit_test/voidcrew_plasma_wounds/roll_tiers

/datum/unit_test/voidcrew_plasma_wounds/roll_tiers/Run()
	var/obj/projectile/energy/plasma_bolt/bolt = make_bolt(/obj/projectile/energy/plasma_bolt, turf_at(1, 1))
	// Damage 1 makes the base roll 1, so the wound bonus sets the tier: about 50, 100 and 200.
	var/list/tiers = list("moderate" = 49, "severe" = 99, "critical" = 199)
	var/list/tg_tiers = list("moderate" = /datum/wound/burn/flesh/moderate, "severe" = /datum/wound/burn/flesh/severe, "critical" = /datum/wound/burn/flesh/critical)
	var/list/fresh_slag = list("moderate" = PLASMA_WOUND_SLAG_MODERATE, "severe" = PLASMA_WOUND_SLAG_SEVERE, "critical" = PLASMA_WOUND_SLAG_CRITICAL)
	var/list/fresh_heat = list("moderate" = PLASMA_WOUND_HEAT_MODERATE, "severe" = PLASMA_WOUND_HEAT_SEVERE, "critical" = PLASMA_WOUND_HEAT_CRITICAL)
	for(var/tier in tiers)
		var/path = tier_path(tier)
		TEST_ASSERT_NOTNULL(path, "no [tier] plasma burn type")
		var/mob/living/carbon/human/consistent/shot = allocate(/mob/living/carbon/human/consistent, turf_at(2, 1))
		var/obj/item/bodypart/arm = shot.get_bodypart(BODY_ZONE_R_ARM)
		var/datum/wound/rolled = arm.check_wounding(WOUND_BURN, 1, tiers[tier], 0, null, bolt, FALSE)
		TEST_ASSERT_EQUAL(rolled?.type, path, "a plasma bolt's [tier] roll gave [rolled?.type]")
		TEST_ASSERT_EQUAL(length(burns_on(arm)), 1, "a plasma bolt's [tier] roll left more than one burn on the arm")
		var/datum/wound/burn/flesh/plasma/plasma_burn = rolled
		TEST_ASSERT_EQUAL(plasma_burn.slag, fresh_slag[tier], "a fresh [tier] plasma burn holds [plasma_burn.slag] slag")
		TEST_ASSERT_EQUAL(plasma_burn.heat, fresh_heat[tier], "a fresh [tier] plasma burn is hot for [plasma_burn.heat]")

		var/mob/living/carbon/human/consistent/burned = allocate(/mob/living/carbon/human/consistent, turf_at(2, 2))
		var/obj/item/bodypart/other_arm = burned.get_bodypart(BODY_ZONE_R_ARM)
		var/datum/wound/plain = other_arm.check_wounding(WOUND_BURN, 1, tiers[tier], 0, null, null, FALSE)
		TEST_ASSERT_EQUAL(plain?.type, tg_tiers[tier], "the same [tier] roll with no source gave [plain?.type]")

	// The real path: a rifle bolt on a bare arm leaves a plasma burn and no tg burn.
	var/mob/living/carbon/human/consistent/victim = allocate(/mob/living/carbon/human/consistent, turf_at(2, 3))
	victim.bullet_act(make_bolt(/obj/projectile/energy/plasma_bolt/heavy, turf_at(1, 3), BODY_ZONE_R_ARM), BODY_ZONE_R_ARM)
	var/obj/item/bodypart/hit_arm = victim.get_bodypart(BODY_ZONE_R_ARM)
	TEST_ASSERT_NOTNULL(hit_arm, "one rifle bolt melted an unhurt arm")
	var/list/hit_burns = burns_on(hit_arm)
	TEST_ASSERT_EQUAL(length(hit_burns), 1, "a rifle bolt on a bare arm left [length(hit_burns)] burns")
	TEST_ASSERT(istype(hit_burns[1], /datum/wound/burn/flesh/plasma), "a rifle bolt on a bare arm left [hit_burns[1]], not a plasma burn")
	clean_up(turf_at(2, 2))

/// 2. A higher plasma roll replaces a tg burn; a higher tg burn over a slagged plasma burn stays plasma.
/datum/unit_test/voidcrew_plasma_wounds/replacement

/datum/unit_test/voidcrew_plasma_wounds/replacement/Run()
	var/obj/projectile/energy/plasma_bolt/bolt = make_bolt(/obj/projectile/energy/plasma_bolt, turf_at(1, 1))
	var/severe_path = tier_path("severe")
	var/critical_path = tier_path("critical")
	TEST_ASSERT(severe_path && critical_path, "plasma burn tiers are missing")

	var/mob/living/carbon/human/consistent/first = allocate(/mob/living/carbon/human/consistent, turf_at(2, 1))
	var/obj/item/bodypart/arm = first.get_bodypart(BODY_ZONE_R_ARM)
	arm.force_wound_upwards(/datum/wound/burn/flesh/moderate)
	TEST_ASSERT_NOTNULL(arm.get_wound_type(/datum/wound/burn/flesh/moderate), "could not give an arm a tg moderate burn")
	// With the moderate's penalties this lands in the severe band.
	var/datum/wound/rolled = arm.check_wounding(WOUND_BURN, 1, 49, 0, null, bolt, FALSE)
	TEST_ASSERT_EQUAL(rolled?.type, severe_path, "a severe plasma roll over a tg moderate burn gave [rolled?.type]")
	var/list/after = burns_on(arm)
	TEST_ASSERT_EQUAL(length(after), 1, "a plasma burn sat beside the tg burn it replaced")
	TEST_ASSERT(istype(after[1], severe_path), "the tg moderate burn was not replaced by a plasma severe")

	var/mob/living/carbon/human/consistent/second = allocate(/mob/living/carbon/human/consistent, turf_at(2, 2))
	var/obj/item/bodypart/other_arm = second.get_bodypart(BODY_ZONE_L_ARM)
	var/datum/wound/burn/flesh/plasma/slagged = give_burn(other_arm, "severe")
	TEST_ASSERT_NOTNULL(slagged, "no severe plasma burn")
	var/old_slag = slagged.slag
	TEST_ASSERT(old_slag > 0, "a fresh severe plasma burn holds no slag")
	// A fire's critical roll, with no plasma source.
	other_arm.check_wounding(WOUND_BURN, 1, 199, 0, null, null, FALSE)
	var/list/fire_after = burns_on(other_arm)
	TEST_ASSERT_EQUAL(length(fire_after), 1, "a fire roll left [length(fire_after)] burns on a slagged arm")
	var/datum/wound/burn/flesh/plasma/upgraded = fire_after[1]
	TEST_ASSERT(istype(upgraded, critical_path), "a tg critical over a slagged plasma burn became [upgraded.type]")
	TEST_ASSERT(upgraded.slag >= old_slag, "a tg burn over a plasma burn burned the slag away ([upgraded.slag] of [old_slag] left)")

/// 3. tg's wound picker never hands out a plasma burn.
/datum/unit_test/voidcrew_plasma_wounds/never_picked

/datum/unit_test/voidcrew_plasma_wounds/never_picked/Run()
	var/mob/living/carbon/human/consistent/victim = allocate(/mob/living/carbon/human/consistent, turf_at(2, 1))
	var/obj/item/bodypart/arm = victim.get_bodypart(BODY_ZONE_R_ARM)
	var/list/severities = list(WOUND_SEVERITY_MODERATE, WOUND_SEVERITY_SEVERE, WOUND_SEVERITY_CRITICAL)
	for(var/i in 1 to 200)
		var/severity = severities[(i % 3) + 1]
		var/datum/wound/given = victim.cause_wound_of_type_and_severity(WOUND_BURN, arm, severity)
		TEST_ASSERT_NOTNULL(given, "cause_wound_of_type_and_severity gave no burn at severity [severity]")
		TEST_ASSERT(!istype(given, /datum/wound/burn/flesh/plasma), "cause_wound_of_type_and_severity gave [given.type] on try [i]")
		qdel(given)

/// 4. Cooking: a severe on a chest takes its burn over its heat and none after; wet stops it; cold cools
/// four times as fast; a burning body doesn't cool.
/datum/unit_test/voidcrew_plasma_wounds/cooking

/datum/unit_test/voidcrew_plasma_wounds/cooking/Run()
	var/mob/living/carbon/human/consistent/victim = allocate(/mob/living/carbon/human/consistent, turf_at(2, 1))
	var/obj/item/bodypart/chest = victim.get_bodypart(BODY_ZONE_CHEST)
	var/datum/wound/burn/flesh/plasma/burn = give_burn(chest, "severe")
	TEST_ASSERT_NOTNULL(burn, "no severe plasma burn")
	TEST_ASSERT_EQUAL(burn.heat, PLASMA_WOUND_HEAT_SEVERE, "a fresh severe is hot for [burn.heat]")
	var/multiplier = chest.wound_damage_multiplier
	var/start_burn = chest.burn_dam
	for(var/tick in 1 to PLASMA_WOUND_HEAT_SEVERE + 2)
		burn.handle_process(1, tick)
	TEST_ASSERT(!QDELETED(burn), "a slagged severe closed while cooking")
	TEST_ASSERT(burn.heat <= 0, "a severe was still hot after [PLASMA_WOUND_HEAT_SEVERE + 2] seconds at body heat")
	var/cooked = chest.burn_dam - start_burn
	var/expected = PLASMA_WOUND_HEAT_SEVERE * PLASMA_WOUND_COOK_SEVERE * multiplier
	TEST_ASSERT(abs(cooked - expected) <= PLASMA_WOUND_COOK_SEVERE * multiplier + 0.05, "a severe cooked [cooked] burn over its heat, expected [expected]")
	var/cold_burn = chest.burn_dam
	for(var/tick in 1 to 10)
		burn.handle_process(1, tick)
	TEST_ASSERT_EQUAL(chest.burn_dam, cold_burn, "a cold severe kept cooking")

	// Wet skin quenches it in one tick and nothing cooks that tick.
	var/mob/living/carbon/human/consistent/wet = allocate(/mob/living/carbon/human/consistent, turf_at(2, 2))
	var/obj/item/bodypart/wet_chest = wet.get_bodypart(BODY_ZONE_CHEST)
	var/datum/wound/burn/flesh/plasma/wet_burn = give_burn(wet_chest, "severe")
	TEST_ASSERT_NOTNULL(wet_burn, "no severe plasma burn")
	wet.adjust_wet_stacks(5)
	var/wet_start = wet_chest.burn_dam
	wet_burn.handle_process(1, 1)
	TEST_ASSERT(wet_burn.heat <= 0, "wet skin left a severe hot at [wet_burn.heat]")
	TEST_ASSERT_EQUAL(wet_chest.burn_dam, wet_start, "a severe cooked on the tick it was quenched")
	wet.remove_status_effect(/datum/status_effect/fire_handler/wet_stacks)

	// One tick at body heat, then one in a cold body.
	var/mob/living/carbon/human/consistent/warm = allocate(/mob/living/carbon/human/consistent, turf_at(2, 3))
	var/datum/wound/burn/flesh/plasma/warm_burn = give_burn(warm.get_bodypart(BODY_ZONE_CHEST), "severe")
	TEST_ASSERT_NOTNULL(warm_burn, "no severe plasma burn")
	warm_burn.handle_process(1, 1)
	var/warm_loss = PLASMA_WOUND_HEAT_SEVERE - warm_burn.heat
	TEST_ASSERT(abs(warm_loss - 1) < 0.01, "a severe at body heat lost [warm_loss] heat in a second")

	var/mob/living/carbon/human/consistent/cold = allocate(/mob/living/carbon/human/consistent, turf_at(3, 1))
	var/datum/wound/burn/flesh/plasma/cold_burn_wound = give_burn(cold.get_bodypart(BODY_ZONE_CHEST), "severe")
	TEST_ASSERT_NOTNULL(cold_burn_wound, "no severe plasma burn")
	cold.bodytemperature = BODYTEMP_COLD_DAMAGE_LIMIT - 20
	cold_burn_wound.handle_process(1, 1)
	var/cold_loss = PLASMA_WOUND_HEAT_SEVERE - cold_burn_wound.heat
	TEST_ASSERT(abs(cold_loss - PLASMA_WOUND_COLD_BODY_FACTOR) < 0.01, "a severe in a cold body lost [cold_loss] heat in a second, expected [PLASMA_WOUND_COLD_BODY_FACTOR]")
	cold.bodytemperature = BODYTEMP_NORMAL

	var/mob/living/carbon/human/consistent/burning = allocate(/mob/living/carbon/human/consistent, turf_at(3, 2))
	var/datum/wound/burn/flesh/plasma/fire_burn = give_burn(burning.get_bodypart(BODY_ZONE_CHEST), "severe")
	TEST_ASSERT_NOTNULL(fire_burn, "no severe plasma burn")
	burning.adjust_fire_stacks(5)
	burning.ignite_mob()
	TEST_ASSERT(burning.on_fire, "could not set the test body alight")
	fire_burn.handle_process(1, 1)
	TEST_ASSERT_EQUAL(fire_burn.heat, PLASMA_WOUND_HEAT_SEVERE, "a severe on a burning body cooled")
	burning.extinguish_mob()

/// 5. Cooking never adds or upgrades a wound, and never melts a limb.
/datum/unit_test/voidcrew_plasma_wounds/cooking_is_inert

/datum/unit_test/voidcrew_plasma_wounds/cooking_is_inert/Run()
	var/mob/living/carbon/human/consistent/victim = allocate(/mob/living/carbon/human/consistent, turf_at(2, 1))
	var/obj/item/bodypart/arm = victim.get_bodypart(BODY_ZONE_R_ARM)
	var/datum/wound/burn/flesh/plasma/severe = give_burn(arm, "severe")
	TEST_ASSERT_NOTNULL(severe, "no severe plasma burn")
	var/severe_type = severe.type
	for(var/tick in 1 to PLASMA_WOUND_HEAT_SEVERE + 2)
		severe.handle_process(1, tick)
	TEST_ASSERT_EQUAL(length(arm.wounds), 1, "cooking added a wound to the arm")
	TEST_ASSERT(!QDELETED(severe) && severe.type == severe_type, "cooking replaced or upgraded a severe plasma burn")

	// A critical on a leg already near its limit cooks it to the cap and the leg stays on.
	var/obj/item/bodypart/leg = victim.get_bodypart(BODY_ZONE_L_LEG)
	leg.receive_damage(burn = leg.max_damage - 5, wound_bonus = CANT_WOUND)
	var/datum/wound/burn/flesh/plasma/critical = give_burn(leg, "critical")
	TEST_ASSERT_NOTNULL(critical, "no critical plasma burn")
	for(var/tick in 1 to PLASMA_WOUND_HEAT_CRITICAL + 2)
		critical.handle_process(1, tick)
	TEST_ASSERT_EQUAL(victim.get_bodypart(BODY_ZONE_L_LEG), leg, "cooking melted a leg")
	TEST_ASSERT_EQUAL(length(leg.wounds), 1, "cooking added a wound to the leg")
	TEST_ASSERT(!QDELETED(critical), "cooking removed the critical plasma burn")
	TEST_ASSERT_EQUAL(length(victim.all_wounds), 2, "cooking added a wound somewhere on the body")

/// 6. With slag in, ointment, mesh, miner's salve, stasis and cryo do not close the wound; stored healing
/// is capped; once the slag is out the wound closes on tg's clock.
/datum/unit_test/voidcrew_plasma_wounds/blocked_healing

/datum/unit_test/voidcrew_plasma_wounds/blocked_healing/Run()
	var/mob/living/carbon/human/consistent/victim = allocate(/mob/living/carbon/human/consistent, turf_at(2, 1))
	var/mob/living/carbon/human/consistent/medic = allocate(/mob/living/carbon/human/consistent, turf_at(1, 1))
	var/obj/item/bodypart/arm = victim.get_bodypart(BODY_ZONE_R_ARM)
	var/datum/wound/burn/flesh/plasma/burn = give_burn(arm, "severe")
	TEST_ASSERT_NOTNULL(burn, "no severe plasma burn")
	burn.quench(TRUE)
	TEST_ASSERT(burn.heat <= 0, "quench left the burn hot")
	var/start_flesh = burn.flesh_damage

	var/obj/item/stack/medical/ointment/ointment = allocate(/obj/item/stack/medical/ointment)
	var/obj/item/stack/medical/mesh/mesh = allocate(/obj/item/stack/medical/mesh)
	mesh.is_open = TRUE
	for(var/i in 1 to 6)
		ointment.heal_carbon(victim, medic, BODY_ZONE_R_ARM)
		mesh.heal_carbon(victim, medic, BODY_ZONE_R_ARM)
		burn.handle_process(1, i)
	victim.reagents.add_reagent(/datum/reagent/medicine/mine_salve, 20)
	for(var/tick in 1 to 60)
		burn.handle_process(1, tick)
	TEST_ASSERT(!QDELETED(burn), "a slagged burn closed under ointment, mesh and salve")
	TEST_ASSERT_EQUAL(burn.flesh_damage, start_flesh, "a slagged burn healed flesh")
	TEST_ASSERT(burn.stored_healing > 0, "treatment given with slag in was not stored")
	TEST_ASSERT(burn.stored_healing <= burn.flesh_damage + 0.01, "stored healing [burn.stored_healing] went past the flesh damage [burn.flesh_damage]")

	ADD_TRAIT(victim, TRAIT_STASIS, "voidcrew_plasma_wounds_test")
	for(var/tick in 1 to 200)
		burn.on_stasis(1, tick)
	REMOVE_TRAIT(victim, TRAIT_STASIS, "voidcrew_plasma_wounds_test")
	TEST_ASSERT(!QDELETED(burn), "stasis closed a slagged burn")
	TEST_ASSERT_EQUAL(burn.flesh_damage, start_flesh, "stasis healed flesh on a slagged burn")

	burn.on_xadone(burn.get_xadone_progress_to_qdel() * 3)
	TEST_ASSERT(!QDELETED(burn), "cryo closed a slagged burn")

	// The last of the slag comes out: stored healing is released and the burn closes as tg's would.
	burn.remove_slag(burn.slag, medic)
	TEST_ASSERT_EQUAL(burn.slag, 0, "removing all the slag left [burn.slag]")
	TEST_ASSERT_EQUAL(burn.stored_healing, 0, "stored healing was kept after the slag came out")
	TEST_ASSERT(burn.flesh_healing > 0, "stored healing was not released when the slag came out")
	for(var/tick in 1 to 120)
		if(QDELETED(burn))
			break
		burn.handle_process(1, tick)
	TEST_ASSERT(QDELETED(burn), "a clean, treated burn did not close in two minutes")
	clean_up(turf_at(2, 1))

/// 7. Field picks with each tool: time, slag removed, brute dealt, one bead for a severe or critical only.
/datum/unit_test/voidcrew_plasma_wounds/pick_slag

/// Picks every bit of slag out of `burn`; returns list(elapsed deciseconds, brute dealt).
/datum/unit_test/voidcrew_plasma_wounds/pick_slag/proc/pick_all(datum/wound/burn/flesh/plasma/burn, mob/living/carbon/human/user, obj/item/tool)
	user.put_in_active_hand(tool, forced = TRUE)
	var/obj/item/bodypart/limb = burn.limb
	var/start_brute = limb.brute_dam
	var/start_time = world.time
	burn.pick_slag(tool, user)
	return list(world.time - start_time, limb.brute_dam - start_brute)

/datum/unit_test/voidcrew_plasma_wounds/pick_slag/Run()
	// Moderate, scalpel, someone else: one pick, no bead.
	var/mob/living/carbon/human/consistent/first = allocate(/mob/living/carbon/human/consistent, turf_at(2, 1))
	var/mob/living/carbon/human/consistent/medic = allocate(/mob/living/carbon/human/consistent, turf_at(1, 1))
	var/obj/item/bodypart/arm = first.get_bodypart(BODY_ZONE_R_ARM)
	var/datum/wound/burn/flesh/plasma/moderate = give_burn(arm, "moderate")
	TEST_ASSERT_NOTNULL(moderate, "no moderate plasma burn")
	var/multiplier = arm.wound_damage_multiplier
	var/list/result = pick_all(moderate, medic, allocate(/obj/item/scalpel))
	var/expected_time = PLASMA_WOUND_PICK_TIME * PLASMA_WOUND_IMPROVISED_TIME
	TEST_ASSERT_EQUAL(moderate.slag, 0, "one scalpel pick left [moderate.slag] slag in a moderate")
	TEST_ASSERT(result[1] >= expected_time - 1 && result[1] <= expected_time + 5, "one scalpel pick took [result[1]], expected [expected_time]")
	TEST_ASSERT(abs(result[2] - PLASMA_WOUND_PICK_BRUTE_IMPROVISED * multiplier) < 0.1, "one scalpel pick dealt [result[2]] brute")
	TEST_ASSERT_NULL(locate(/obj/item/plasma_slag) in get_turf(first), "a moderate dropped a slag bead")

	// Severe, wirecutters, someone else: two picks, one bead.
	var/mob/living/carbon/human/consistent/second = allocate(/mob/living/carbon/human/consistent, turf_at(2, 2))
	var/mob/living/carbon/human/consistent/engineer = allocate(/mob/living/carbon/human/consistent, turf_at(1, 2))
	var/obj/item/bodypart/leg = second.get_bodypart(BODY_ZONE_L_LEG)
	var/datum/wound/burn/flesh/plasma/severe = give_burn(leg, "severe")
	TEST_ASSERT_NOTNULL(severe, "no severe plasma burn")
	multiplier = leg.wound_damage_multiplier
	result = pick_all(severe, engineer, allocate(/obj/item/wirecutters))
	var/picks = CEILING(PLASMA_WOUND_SLAG_SEVERE / PLASMA_WOUND_PICK_SLAG, 1)
	expected_time = picks * PLASMA_WOUND_PICK_TIME * PLASMA_WOUND_IMPROVISED_TIME
	TEST_ASSERT_EQUAL(severe.slag, 0, "wirecutters left [severe.slag] slag in a severe")
	TEST_ASSERT(result[1] >= expected_time - 1 && result[1] <= expected_time + picks * 5, "[picks] wirecutter picks took [result[1]], expected [expected_time]")
	TEST_ASSERT(abs(result[2] - picks * PLASMA_WOUND_PICK_BRUTE_IMPROVISED * multiplier) < 0.1, "[picks] wirecutter picks dealt [result[2]] brute")
	var/beads = 0
	for(var/obj/item/plasma_slag/bead in get_turf(second))
		beads++
	TEST_ASSERT_EQUAL(beads, 1, "a picked severe dropped [beads] beads")

	// Critical on your own chest, hemostat, scanned: four picks at x1.5 x0.5, one bead.
	var/mob/living/carbon/human/consistent/third = allocate(/mob/living/carbon/human/consistent, turf_at(2, 3))
	var/obj/item/bodypart/chest = third.get_bodypart(BODY_ZONE_CHEST)
	var/datum/wound/burn/flesh/plasma/critical = give_burn(chest, "critical")
	TEST_ASSERT_NOTNULL(critical, "no critical plasma burn")
	ADD_TRAIT(critical, TRAIT_WOUND_SCANNED, ANALYZER_TRAIT)
	multiplier = chest.wound_damage_multiplier
	result = pick_all(critical, third, allocate(/obj/item/hemostat))
	picks = CEILING(PLASMA_WOUND_SLAG_CRITICAL / PLASMA_WOUND_PICK_SLAG, 1)
	expected_time = picks * PLASMA_WOUND_PICK_TIME * 1.5 * 0.5
	TEST_ASSERT_EQUAL(critical.slag, 0, "a hemostat left [critical.slag] slag in a critical")
	TEST_ASSERT(result[1] >= expected_time - 1 && result[1] <= expected_time + picks * 5, "[picks] scanned self picks took [result[1]], expected [expected_time]")
	TEST_ASSERT(abs(result[2] - picks * PLASMA_WOUND_PICK_BRUTE * multiplier) < 0.1, "[picks] hemostat picks dealt [result[2]] brute")
	beads = 0
	for(var/obj/item/plasma_slag/bead in get_turf(third))
		beads++
	TEST_ASSERT_EQUAL(beads, 1, "a picked critical dropped [beads] beads")

	// A moderate left alone sheds its flecks once cool, and drops nothing.
	var/mob/living/carbon/human/consistent/fourth = allocate(/mob/living/carbon/human/consistent, turf_at(3, 1))
	var/datum/wound/burn/flesh/plasma/shedding = give_burn(fourth.get_bodypart(BODY_ZONE_L_ARM), "moderate")
	TEST_ASSERT_NOTNULL(shedding, "no moderate plasma burn")
	var/shed_ticks = PLASMA_WOUND_HEAT_MODERATE + CEILING(PLASMA_WOUND_SLAG_MODERATE / PLASMA_WOUND_SHED_RATE, 1) + 5
	for(var/tick in 1 to shed_ticks)
		if(QDELETED(shedding) || shedding.slag <= 0)
			break
		shedding.handle_process(1, tick)
	TEST_ASSERT(QDELETED(shedding) || shedding.slag <= 0, "a moderate still held [shedding.slag] slag after [shed_ticks] seconds")
	TEST_ASSERT_NULL(locate(/obj/item/plasma_slag) in get_turf(fourth), "a moderate that shed its slag dropped a bead")
	clean_up(turf_at(2, 2))

/// 8. The surgery starts only with slag, takes it out without damage and ends in tg's dressing step.
/datum/unit_test/voidcrew_plasma_wounds/surgery

/datum/unit_test/voidcrew_plasma_wounds/surgery/Run()
	var/surgery_type = text2path("/datum/surgery/excise_slag")
	var/step_type = text2path("/datum/surgery_step/excise_slag")
	TEST_ASSERT_NOTNULL(surgery_type, "/datum/surgery/excise_slag does not exist")
	TEST_ASSERT_NOTNULL(step_type, "/datum/surgery_step/excise_slag does not exist")

	var/mob/living/carbon/human/consistent/patient = allocate(/mob/living/carbon/human/consistent, turf_at(2, 1))
	var/mob/living/carbon/human/consistent/surgeon = allocate(/mob/living/carbon/human/consistent, turf_at(1, 1))
	surgeon.zone_selected = BODY_ZONE_R_ARM
	var/obj/item/bodypart/arm = patient.get_bodypart(BODY_ZONE_R_ARM)
	var/datum/wound/burn/flesh/plasma/burn = give_burn(arm, "critical")
	TEST_ASSERT_NOTNULL(burn, "no critical plasma burn")

	var/datum/surgery/surgery = new surgery_type(patient, BODY_ZONE_R_ARM, arm)
	TEST_ASSERT(surgery.can_start(surgeon, patient), "the slag surgery could not start on a slagged burn")
	TEST_ASSERT_EQUAL(surgery.operated_wound, burn, "the slag surgery is not working on the plasma burn")
	TEST_ASSERT_EQUAL(surgery.steps[1], step_type, "the slag surgery does not start with its own step")
	TEST_ASSERT_EQUAL(surgery.steps[length(surgery.steps)], /datum/surgery_step/dress, "the slag surgery does not end in tg's dressing step")

	var/datum/surgery_step/excise = new step_type
	TEST_ASSERT(excise.repeatable, "the slag step can't be repeated")
	var/obj/item/hemostat/hemostat = allocate(/obj/item/hemostat)
	var/start_slag = burn.slag
	var/start_brute = arm.brute_dam
	excise.success(surgeon, patient, BODY_ZONE_R_ARM, hemostat, surgery)
	TEST_ASSERT_EQUAL(burn.slag, start_slag - PLASMA_WOUND_SURGERY_SLAG, "a slag step took out [start_slag - burn.slag] slag")
	TEST_ASSERT_EQUAL(arm.brute_dam, start_brute, "a successful slag step did brute damage")
	excise.failure(surgeon, patient, BODY_ZONE_R_ARM, hemostat, surgery)
	TEST_ASSERT(arm.brute_dam > start_brute, "a failed slag step did no damage")
	var/steps_left = CEILING(burn.slag / PLASMA_WOUND_SURGERY_SLAG, 1) + 1
	while(burn.slag > 0 && steps_left-- > 0)
		excise.success(surgeon, patient, BODY_ZONE_R_ARM, hemostat, surgery)
	TEST_ASSERT_EQUAL(burn.slag, 0, "the slag step did not take the last of the slag out")
	TEST_ASSERT(!QDELETED(burn), "taking the slag out by surgery deleted the burn before dressing")
	qdel(excise)
	qdel(surgery)

	// No slag, no surgery.
	var/datum/surgery/check = new surgery_type
	TEST_ASSERT(!check.can_start(surgeon, patient), "the slag surgery could start on a burn with no slag")
	qdel(check)
	clean_up(turf_at(2, 1))

/// 9. A fresh critical tops blood plasma up to its dose, and a second adds nothing while it's there.
/datum/unit_test/voidcrew_plasma_wounds/blood_plasma

/datum/unit_test/voidcrew_plasma_wounds/blood_plasma/Run()
	var/mob/living/carbon/human/consistent/victim = allocate(/mob/living/carbon/human/consistent, turf_at(2, 1))
	TEST_ASSERT_NOTNULL(give_burn(victim.get_bodypart(BODY_ZONE_R_ARM), "critical"), "no critical plasma burn")
	var/dose = victim.reagents.get_reagent_amount(/datum/reagent/toxin/plasma)
	TEST_ASSERT(abs(dose - PLASMA_WOUND_BLOOD_PLASMA) < 0.05, "a fresh critical left [dose]u of plasma in the blood")
	TEST_ASSERT_NOTNULL(give_burn(victim.get_bodypart(BODY_ZONE_L_LEG), "critical"), "no second critical plasma burn")
	dose = victim.reagents.get_reagent_amount(/datum/reagent/toxin/plasma)
	TEST_ASSERT(abs(dose - PLASMA_WOUND_BLOOD_PLASMA) < 0.05, "a second critical took the blood to [dose]u of plasma")

	var/mob/living/carbon/human/consistent/dosed = allocate(/mob/living/carbon/human/consistent, turf_at(2, 2))
	dosed.reagents.add_reagent(/datum/reagent/toxin/plasma, 1)
	TEST_ASSERT_NOTNULL(give_burn(dosed.get_bodypart(BODY_ZONE_R_ARM), "critical"), "no critical plasma burn")
	dose = dosed.reagents.get_reagent_amount(/datum/reagent/toxin/plasma)
	TEST_ASSERT(abs(dose - PLASMA_WOUND_BLOOD_PLASMA) < 0.05, "a critical on 1u of plasma left [dose]u, not a top-up")

	var/mob/living/carbon/human/consistent/severe = allocate(/mob/living/carbon/human/consistent, turf_at(2, 3))
	TEST_ASSERT_NOTNULL(give_burn(severe.get_bodypart(BODY_ZONE_R_ARM), "severe"), "no severe plasma burn")
	TEST_ASSERT_EQUAL(severe.reagents.get_reagent_amount(/datum/reagent/toxin/plasma), 0, "a severe put plasma in the blood")

/// 10. The rifle melts a limb with a slagged critical in one bolt, and not once the slag is out; a tg
/// critical no longer sets it up; the worn-through rule is unchanged.
/datum/unit_test/voidcrew_plasma_wounds/burn_through_melt

/datum/unit_test/voidcrew_plasma_wounds/burn_through_melt/Run()
	var/turf/open/from = turf_at(1, 1)
	var/mob/living/carbon/human/consistent/medic = allocate(/mob/living/carbon/human/consistent, turf_at(1, 2))

	var/mob/living/carbon/human/consistent/slagged = allocate(/mob/living/carbon/human/consistent, turf_at(2, 1))
	var/obj/item/bodypart/leg = slagged.get_bodypart(BODY_ZONE_R_LEG)
	TEST_ASSERT_NOTNULL(give_burn(leg, "critical"), "no critical plasma burn")
	leg.heal_damage(brute = 200, burn = 200)
	TEST_ASSERT(plasma_burn_through_ready(leg), "a slagged critical is not ready to burn through")
	var/obj/projectile/energy/plasma_bolt/bolt = make_bolt(/obj/projectile/energy/plasma_bolt/heavy, from, BODY_ZONE_R_LEG)
	bolt.damage = 5
	slagged.bullet_act(bolt, BODY_ZONE_R_LEG)
	TEST_ASSERT_NULL(slagged.get_bodypart(BODY_ZONE_R_LEG), "a rifle bolt left a leg with a slagged critical attached")

	var/mob/living/carbon/human/consistent/cleaned = allocate(/mob/living/carbon/human/consistent, turf_at(2, 2))
	var/obj/item/bodypart/clean_leg = cleaned.get_bodypart(BODY_ZONE_R_LEG)
	var/datum/wound/burn/flesh/plasma/critical = give_burn(clean_leg, "critical")
	TEST_ASSERT_NOTNULL(critical, "no critical plasma burn")
	critical.remove_slag(critical.slag, medic)
	clean_leg.heal_damage(brute = 200, burn = 200)
	TEST_ASSERT(!plasma_burn_through_ready(clean_leg), "a critical with its slag out is still ready to burn through")
	TEST_ASSERT(plasma_limb_burned_through(clean_leg), "a critical with its slag out no longer counts as burned through for the burst")
	bolt = make_bolt(/obj/projectile/energy/plasma_bolt/heavy, from, BODY_ZONE_R_LEG)
	bolt.damage = 5
	cleaned.bullet_act(bolt, BODY_ZONE_R_LEG)
	TEST_ASSERT_NOTNULL(cleaned.get_bodypart(BODY_ZONE_R_LEG), "a rifle bolt melted a leg whose slag was cut out")

	var/mob/living/carbon/human/consistent/fire_burned = allocate(/mob/living/carbon/human/consistent, turf_at(2, 3))
	var/obj/item/bodypart/fire_leg = fire_burned.get_bodypart(BODY_ZONE_R_LEG)
	fire_leg.force_wound_upwards(/datum/wound/burn/flesh/critical)
	fire_leg.heal_damage(brute = 200, burn = 200)
	TEST_ASSERT_NOTNULL(fire_leg.get_wound_type(/datum/wound/burn/flesh/critical), "could not give a leg a tg critical burn")
	TEST_ASSERT(!plasma_burn_through_ready(fire_leg), "a tg critical burn is ready for the rifle's burn-through")
	bolt = make_bolt(/obj/projectile/energy/plasma_bolt/heavy, from, BODY_ZONE_R_LEG)
	bolt.damage = 5
	fire_burned.bullet_act(bolt, BODY_ZONE_R_LEG)
	TEST_ASSERT_NOTNULL(fire_burned.get_bodypart(BODY_ZONE_R_LEG), "a rifle bolt melted a leg with only a tg critical burn")

	// Worn through: 15 before + 32 = 47 of 50, inside the pistol's margin.
	var/mob/living/carbon/human/consistent/hurt = allocate(/mob/living/carbon/human/consistent, turf_at(3, 1))
	var/obj/item/bodypart/hurt_arm = hurt.get_bodypart(BODY_ZONE_L_ARM)
	hurt_arm.receive_damage(brute = 15, wound_bonus = CANT_WOUND)
	hurt.bullet_act(make_bolt(/obj/projectile/energy/plasma_bolt, from, BODY_ZONE_L_ARM), BODY_ZONE_L_ARM)
	TEST_ASSERT_NULL(hurt.get_bodypart(BODY_ZONE_L_ARM), "a pistol bolt left a hurt arm at 47/50 attached")
	clean_up(from)

/// 11. A bolt sears the cuts on the limb it hits: a moderate cut closes, a critical drops to severe.
/datum/unit_test/voidcrew_plasma_wounds/sear_cuts

/datum/unit_test/voidcrew_plasma_wounds/sear_cuts/Run()
	var/turf/open/from = turf_at(1, 1)
	var/mob/living/carbon/human/consistent/victim = allocate(/mob/living/carbon/human/consistent, turf_at(2, 1))
	var/obj/item/bodypart/arm = victim.get_bodypart(BODY_ZONE_R_ARM)
	arm.force_wound_upwards(/datum/wound/slash/flesh/moderate)
	TEST_ASSERT_NOTNULL(arm.get_wound_type(/datum/wound/slash/flesh/moderate), "could not give an arm a moderate cut")
	var/obj/projectile/energy/plasma_bolt/bolt = make_bolt(/obj/projectile/energy/plasma_bolt, from, BODY_ZONE_R_ARM)
	bolt.damage = 5
	victim.bullet_act(bolt, BODY_ZONE_R_ARM)
	TEST_ASSERT_NULL(arm.get_wound_type(/datum/wound/slash), "a plasma bolt did not close a moderate cut on the arm it hit")

	var/obj/item/bodypart/leg = victim.get_bodypart(BODY_ZONE_L_LEG)
	leg.force_wound_upwards(/datum/wound/slash/flesh/critical)
	TEST_ASSERT_NOTNULL(leg.get_wound_type(/datum/wound/slash/flesh/critical), "could not give a leg a critical cut")
	bolt = make_bolt(/obj/projectile/energy/plasma_bolt, from, BODY_ZONE_L_LEG)
	bolt.damage = 5
	victim.bullet_act(bolt, BODY_ZONE_L_LEG)
	var/datum/wound/slash/flesh/seared = leg.get_wound_type(/datum/wound/slash)
	TEST_ASSERT_EQUAL(seared?.type, /datum/wound/slash/flesh/severe, "a plasma bolt on a critical cut left [seared?.type]")
	clean_up(from)

/// 12. Robotic, skeleton and plasmaman limbs get no plasma burn.
/datum/unit_test/voidcrew_plasma_wounds/no_flesh

/datum/unit_test/voidcrew_plasma_wounds/no_flesh/Run()
	var/obj/projectile/energy/plasma_bolt/bolt = make_bolt(/obj/projectile/energy/plasma_bolt, turf_at(1, 1))

	var/mob/living/carbon/human/consistent/cyborg_arm = allocate(/mob/living/carbon/human/consistent, turf_at(2, 1))
	var/obj/item/bodypart/arm/right/robot/robot_arm = new
	robot_arm.replace_limb(cyborg_arm, TRUE)
	var/obj/item/bodypart/fitted = cyborg_arm.get_bodypart(BODY_ZONE_R_ARM)
	TEST_ASSERT_EQUAL(fitted, robot_arm, "could not fit a robot arm")
	fitted.check_wounding(WOUND_BURN, 1, 199, 0, null, bolt, FALSE)
	TEST_ASSERT_NULL(fitted.get_wound_type(/datum/wound/burn/flesh/plasma), "a robot arm got a plasma burn")

	for(var/species_type in list(/datum/species/skeleton, /datum/species/plasmaman))
		var/mob/living/carbon/human/consistent/bony = allocate(/mob/living/carbon/human/consistent, turf_at(2, 2))
		bony.set_species(species_type)
		for(var/zone in list(BODY_ZONE_R_ARM, BODY_ZONE_CHEST))
			var/obj/item/bodypart/part = bony.get_bodypart(zone)
			TEST_ASSERT_NOTNULL(part, "a [species_type] has no [zone]")
			part.check_wounding(WOUND_BURN, 1, 199, 0, null, bolt, FALSE)
			TEST_ASSERT_NULL(part.get_wound_type(/datum/wound/burn/flesh/plasma), "a [species_type] [zone] got a plasma burn")

/// 13. The burn-through burst plays on the hit that gives the limb a critical, and not on the next hit.
/// The existing burst test in voidcrew_plasma_effects.dm covers the killing hit.
/datum/unit_test/voidcrew_plasma_wounds/burst_on_critical

/datum/unit_test/voidcrew_plasma_wounds/burst_on_critical/Run()
	var/turf/open/from = turf_at(1, 1)
	var/mob/living/carbon/human/consistent/victim = allocate(/mob/living/carbon/human/consistent, turf_at(2, 1))
	var/obj/item/bodypart/chest = victim.get_bodypart(BODY_ZONE_CHEST)
	TEST_ASSERT(!plasma_limb_burned_through(chest), "an unhurt chest counts as burned through")
	var/obj/projectile/energy/plasma_bolt/heavy/bolt = make_bolt(/obj/projectile/energy/plasma_bolt/heavy, from, BODY_ZONE_CHEST)
	bolt.damage = 10
	bolt.wound_bonus = 400
	victim.bullet_act(bolt, BODY_ZONE_CHEST)
	TEST_ASSERT(victim.stat != DEAD, "the test hit killed the body")
	var/datum/wound/burn/flesh/plasma/critical = chest.get_wound_type(/datum/wound/burn/flesh/plasma)
	TEST_ASSERT(critical?.severity == WOUND_SEVERITY_CRITICAL, "a huge-bonus rifle bolt left no plasma critical on the chest")
	TEST_ASSERT(plasma_limb_burned_through(chest), "a chest with a plasma critical does not count as burned through")
	var/obj/effect/temp_visual/plasma_burst/first = locate() in get_turf(victim)
	TEST_ASSERT_EQUAL(first?.look, "C", "the hit that gave a critical did not play the burn-through")

	var/obj/projectile/energy/plasma_bolt/heavy/again = make_bolt(/obj/projectile/energy/plasma_bolt/heavy, from, BODY_ZONE_CHEST)
	again.damage = 10
	victim.bullet_act(again, BODY_ZONE_CHEST)
	var/obj/effect/temp_visual/plasma_burst/second
	for(var/obj/effect/temp_visual/plasma_burst/burst in get_turf(victim))
		if(burst != first)
			second = burst
	TEST_ASSERT_NOTNULL(second, "the second hit made no burst")
	if(victim.stat != DEAD)
		TEST_ASSERT_NOTEQUAL(second.look, "C", "a hit on a chest already critical played the burn-through again")
	clean_up(from)

/// 14. Healing each tier leaves a scar whose text comes from the plasma scar file.
/datum/unit_test/voidcrew_plasma_wounds/scars

/datum/unit_test/voidcrew_plasma_wounds/scars/Run()
	var/list/scar_lines = json_decode(file2text("strings/[PLASMA_SCAR_FILE]"))
	TEST_ASSERT(islist(scar_lines), "the plasma scar file could not be read")
	var/mob/living/carbon/human/consistent/medic = allocate(/mob/living/carbon/human/consistent, turf_at(1, 1))
	for(var/tier in list("moderate", "severe", "critical"))
		var/keyword = "plasma[tier]"
		var/list/lines = scar_lines[keyword]
		TEST_ASSERT(length(lines), "the plasma scar file has no [keyword] lines")
		var/mob/living/carbon/human/consistent/victim = allocate(/mob/living/carbon/human/consistent, turf_at(2, 1))
		var/obj/item/bodypart/arm = victim.get_bodypart(BODY_ZONE_R_ARM)
		var/datum/wound/burn/flesh/plasma/burn = give_burn(arm, tier)
		TEST_ASSERT_NOTNULL(burn, "no [tier] plasma burn")
		TEST_ASSERT_EQUAL(burn.scar_keyword, keyword, "a [tier] plasma burn uses scar keyword [burn.scar_keyword]")
		burn.remove_slag(burn.slag, medic)
		var/scars_before = LAZYLEN(arm.scars)
		qdel(burn)
		TEST_ASSERT_EQUAL(LAZYLEN(arm.scars), scars_before + 1, "a healed [tier] plasma burn left no scar")
		var/datum/scar/scar = arm.scars[LAZYLEN(arm.scars)]
		TEST_ASSERT(scar.description in lines, "a healed [tier] plasma burn left the scar \"[scar.description]\", not one from the plasma file")
	clean_up(turf_at(2, 1))
