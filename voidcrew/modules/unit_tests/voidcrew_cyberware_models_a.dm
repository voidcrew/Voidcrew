/**
 * # Cyberware models, part A
 *
 * The Spring calves and Vaulter pistons (Hopper), Brawler myomers (Gorilla Arms),
 * Tinker's fingers (Fixer's Fingers), Deepcore drill fist (Rockjaw) and Holdout
 * housing (Popup Ronin). Each parent keeps its numbers (the defines became vars
 * with the same values), each model shares the parent's slot, and the shelf and
 * ledger entries pay what the plan says. Unit-test files compile before
 * voidcrew/_DEFINES/, so tiers, slots and zone permissions below are literals:
 * tier 1/2/3 are the CYBERWARE_TIER_* values, zone permission 0/1/2 are
 * public/yellow/advanced.
 */

/// The Hopper line: the parent leaps four tiles on an eight second clock with no
/// traits and no fall handler, the Spring calves leap three on fourteen seconds,
/// the Vaulter five on six and carry the Shock Coils' soft landing and dry footing.
/datum/unit_test/voidcrew_cyberware_models_a_hopper

/datum/unit_test/voidcrew_cyberware_models_a_hopper/Run()
	var/obj/item/organ/cyberimp/cyberware/hopper/parent = allocate(/obj/item/organ/cyberimp/cyberware/hopper)
	var/obj/item/organ/cyberimp/cyberware/hopper/street/street = allocate(/obj/item/organ/cyberimp/cyberware/hopper/street)
	var/obj/item/organ/cyberimp/cyberware/hopper/milspec/milspec = allocate(/obj/item/organ/cyberimp/cyberware/hopper/milspec)
	var/obj/item/organ/cyberimp/cyberware/shock_coils/coils = allocate(/obj/item/organ/cyberimp/cyberware/shock_coils)

	// The parent keeps its numbers.
	TEST_ASSERT_EQUAL(parent.leap_range, 4, "The Hopper's leap range changed")
	TEST_ASSERT_EQUAL(parent.leap_cooldown, 8 SECONDS, "The Hopper's leap cooldown changed")
	TEST_ASSERT_EQUAL(parent.chrome_load, 3, "The Hopper's load changed")
	TEST_ASSERT_EQUAL(parent.tier, 2, "The Hopper's tier changed")
	TEST_ASSERT_NULL(parent.leap_action_desc, "The Hopper's button text is overridden")
	TEST_ASSERT(!length(parent.organ_traits), "The Hopper grew a passive trait")

	// The models.
	TEST_ASSERT_EQUAL(street.leap_range, 3, "Spring calves don't leap three tiles")
	TEST_ASSERT_EQUAL(street.leap_cooldown, 14 SECONDS, "Spring calves' clock isn't fourteen seconds")
	TEST_ASSERT_EQUAL(street.chrome_load, 2, "Spring calves' load isn't 2")
	TEST_ASSERT_EQUAL(street.tier, 1, "Spring calves aren't tier 1")
	TEST_ASSERT(!length(street.organ_traits), "Spring calves got dry footing")
	TEST_ASSERT_EQUAL(milspec.leap_range, 5, "Vaulter pistons don't leap five tiles")
	TEST_ASSERT_EQUAL(milspec.leap_cooldown, 6 SECONDS, "Vaulter pistons' clock isn't six seconds")
	TEST_ASSERT_EQUAL(milspec.chrome_load, 4, "Vaulter pistons' load isn't 4")
	TEST_ASSERT_EQUAL(milspec.tier, 3, "Vaulter pistons aren't tier 3")
	TEST_ASSERT(TRAIT_NO_SLIP_WATER in milspec.organ_traits, "Vaulter pistons don't keep dry footing")
	TEST_ASSERT(street.chrome_load < parent.chrome_load && parent.chrome_load < milspec.chrome_load, "The leg line's loads don't climb")

	// Same slot as the Coils and the parent: the leg ladder evicts itself.
	TEST_ASSERT_EQUAL(street.slot, coils.slot, "Spring calves aren't in the leg slot")
	TEST_ASSERT_EQUAL(milspec.slot, coils.slot, "Vaulter pistons aren't in the leg slot")
	TEST_ASSERT_EQUAL(parent.slot, coils.slot, "The Hopper left the leg slot")

	// Each button takes its cooldown and its text from the pistons it belongs to.
	var/datum/action/cooldown/cyberware/hopper_leap/parent_button = locate() in parent.actions
	var/datum/action/cooldown/cyberware/hopper_leap/street_button = locate() in street.actions
	var/datum/action/cooldown/cyberware/hopper_leap/milspec_button = locate() in milspec.actions
	TEST_ASSERT_NOTNULL(parent_button, "The Hopper lost its leap button")
	TEST_ASSERT_NOTNULL(street_button, "Spring calves have no leap button")
	TEST_ASSERT_NOTNULL(milspec_button, "Vaulter pistons have no leap button")
	TEST_ASSERT_EQUAL(parent_button.cooldown_time, 8 SECONDS, "The Hopper's button changed its clock")
	TEST_ASSERT(findtext(parent_button.desc, "four tiles"), "The Hopper's button changed its text")
	TEST_ASSERT_EQUAL(street_button.cooldown_time, 14 SECONDS, "Spring calves' button kept the wrong clock")
	TEST_ASSERT(findtext(street_button.desc, "three tiles"), "Spring calves' button kept the wrong text")
	TEST_ASSERT_EQUAL(milspec_button.cooldown_time, 6 SECONDS, "Vaulter pistons' button kept the wrong clock")
	TEST_ASSERT(findtext(milspec_button.desc, "five tiles"), "Vaulter pistons' button kept the wrong text")

	// The reach follows the pistons. The arena is five tiles square, so the far
	// corner is four tiles from the near one.
	var/turf/start = run_loc_floor_bottom_left
	var/turf/three_away = locate(start.x + 3, start.y, start.z)
	var/turf/four_away = locate(start.x + 4, start.y, start.z)
	TEST_ASSERT(isfloorturf(three_away) && isfloorturf(four_away), "The test arena is smaller than the leap test needs")

	var/mob/living/carbon/human/hopper_wearer = allocate(/mob/living/carbon/human/consistent, start)
	TEST_ASSERT(parent.Insert(hopper_wearer, special = TRUE), "The Hopper wouldn't go in")
	TEST_ASSERT(parent_button.Activate(four_away), "The Hopper wouldn't leap four tiles")
	TEST_ASSERT_EQUAL(parent_button.next_use_time, world.time + 8 SECONDS, "The Hopper's leap started the wrong clock")

	var/mob/living/carbon/human/spring_wearer = allocate(/mob/living/carbon/human/consistent, start)
	TEST_ASSERT(street.Insert(spring_wearer, special = TRUE), "Spring calves wouldn't go in")
	TEST_ASSERT(!street_button.Activate(four_away), "Spring calves leapt four tiles")
	TEST_ASSERT(street_button.IsAvailable(), "A refused leap started Spring calves' clock")
	TEST_ASSERT(street_button.Activate(three_away), "Spring calves wouldn't leap three tiles")
	TEST_ASSERT_EQUAL(street_button.next_use_time, world.time + 14 SECONDS, "Spring calves' leap started the wrong clock")

	// Dry footing and the soft landing belong to the Vaulter alone.
	var/mob/living/carbon/human/vault_wearer = allocate(/mob/living/carbon/human/consistent, start)
	TEST_ASSERT(milspec.Insert(vault_wearer, special = TRUE), "Vaulter pistons wouldn't go in")
	TEST_ASSERT(HAS_TRAIT(vault_wearer, TRAIT_NO_SLIP_WATER), "Vaulter pistons gave no dry footing")
	var/landing = SEND_SIGNAL(vault_wearer, COMSIG_LIVING_Z_IMPACT, 1, start)
	TEST_ASSERT(landing & ZIMPACT_CANCEL_DAMAGE, "Vaulter pistons didn't soften a fall")
	milspec.organ_flags |= ORGAN_FAILING
	landing = SEND_SIGNAL(vault_wearer, COMSIG_LIVING_Z_IMPACT, 1, start)
	TEST_ASSERT(!(landing & ZIMPACT_CANCEL_DAMAGE), "Browned-out Vaulter pistons still softened a fall")
	milspec.organ_flags &= ~ORGAN_FAILING
	milspec.Remove(vault_wearer, special = TRUE)
	TEST_ASSERT(!HAS_TRAIT(vault_wearer, TRAIT_NO_SLIP_WATER), "Dry footing outlived the Vaulter pistons")
	landing = SEND_SIGNAL(vault_wearer, COMSIG_LIVING_Z_IMPACT, 1, start)
	TEST_ASSERT(!(landing & ZIMPACT_CANCEL_DAMAGE), "A fall was softened with the Vaulter pistons gone")

	// The Hopper and the Spring calves never had either.
	TEST_ASSERT(!HAS_TRAIT(hopper_wearer, TRAIT_NO_SLIP_WATER), "The Hopper got dry footing")
	TEST_ASSERT(!(SEND_SIGNAL(hopper_wearer, COMSIG_LIVING_Z_IMPACT, 1, start) & ZIMPACT_CANCEL_DAMAGE), "The Hopper softened a fall")
	TEST_ASSERT(!HAS_TRAIT(spring_wearer, TRAIT_NO_SLIP_WATER), "Spring calves got dry footing")
	TEST_ASSERT(!(SEND_SIGNAL(spring_wearer, COMSIG_LIVING_Z_IMPACT, 1, start) & ZIMPACT_CANCEL_DAMAGE), "Spring calves softened a fall")

/// The Gorilla line: the parent keeps every number and the door-pry bonus. The
/// Brawler myomers punch lighter and slower, smash lighter, hurl nobody, and
/// sync into their own bonus, never the Gorilla's: one beside a real Gorilla arm
/// syncs nothing. The case holds a pair.
/datum/unit_test/voidcrew_cyberware_models_a_gorilla

/datum/unit_test/voidcrew_cyberware_models_a_gorilla/Run()
	var/obj/item/organ/cyberimp/cyberware/gorilla_arms/real_right = allocate(/obj/item/organ/cyberimp/cyberware/gorilla_arms)
	var/obj/item/organ/cyberimp/cyberware/gorilla_arms/left/real_left = allocate(/obj/item/organ/cyberimp/cyberware/gorilla_arms/left)
	var/obj/item/organ/cyberimp/cyberware/gorilla_arms/street/brawler_right = allocate(/obj/item/organ/cyberimp/cyberware/gorilla_arms/street)
	var/obj/item/organ/cyberimp/cyberware/gorilla_arms/street/left/brawler_left = allocate(/obj/item/organ/cyberimp/cyberware/gorilla_arms/street/left)

	// The parent keeps its numbers.
	TEST_ASSERT_EQUAL(real_right.punch_damage, 20, "Gorilla punch damage changed")
	TEST_ASSERT_EQUAL(real_right.structure_damage, 40, "Gorilla structure damage changed")
	TEST_ASSERT_EQUAL(real_right.punch_cooldown_time, 4 SECONDS, "Gorilla punch cooldown changed")
	TEST_ASSERT_EQUAL(real_right.smash_cooldown_time, 1 SECONDS, "Gorilla smash cooldown changed")
	TEST_ASSERT_EQUAL(real_right.hurl_range, 4, "Gorilla hurl range changed")
	TEST_ASSERT(real_right.pries_doors, "Gorilla Arms stopped prying doors")
	TEST_ASSERT_EQUAL(real_right.chrome_load, 3, "Gorilla load changed")
	TEST_ASSERT_EQUAL(real_right.tier, 3, "Gorilla tier changed")

	// The model.
	TEST_ASSERT_EQUAL(brawler_right.punch_damage, 14, "Brawler punch isn't 14")
	TEST_ASSERT_EQUAL(brawler_right.structure_damage, 32, "Brawler smash isn't 32") // BRAWLER_STRUCTURE_DAMAGE
	TEST_ASSERT_EQUAL(brawler_right.punch_cooldown_time, 5 SECONDS, "Brawler punch clock isn't five seconds")
	TEST_ASSERT_EQUAL(brawler_right.smash_cooldown_time, 1.5 SECONDS, "Brawler smash clock isn't a second and a half")
	TEST_ASSERT(brawler_right.hurl_range <= 0, "Brawler myomers can hurl a grabbed victim")
	TEST_ASSERT_EQUAL(brawler_right.pair_bonus, /datum/status_effect/organ_set_bonus/cyberware_brawler, "Brawler myomers don't sync into their own bonus")
	TEST_ASSERT(!brawler_right.heavy_moves, "Brawler myomers have the Gorilla's heavy moves")
	TEST_ASSERT_EQUAL(brawler_right.chrome_load, 2, "Brawler load isn't 2 per arm")
	TEST_ASSERT_EQUAL(brawler_right.tier, 2, "Brawler myomers aren't tier 2")
	TEST_ASSERT_EQUAL(brawler_left.chrome_load, 2, "Left Brawler load isn't 2")
	TEST_ASSERT_EQUAL(brawler_right.slot, real_right.slot, "Right Brawler myomers aren't in the right arm slot")
	TEST_ASSERT_EQUAL(brawler_left.slot, real_left.slot, "Left Brawler myomers aren't in the left arm slot")
	TEST_ASSERT_EQUAL(brawler_left.zone, BODY_ZONE_L_ARM, "Left Brawler myomers aren't left-arm chrome")

	// The case holds one of each side.
	var/obj/item/cyberware_pair_case/gorilla_arms/street/brawler_case = allocate(/obj/item/cyberware_pair_case/gorilla_arms/street)
	TEST_ASSERT_EQUAL(length(brawler_case.contents), 2, "The Brawler case isn't a pair")
	TEST_ASSERT(locate(/obj/item/organ/cyberimp/cyberware/gorilla_arms/street) in brawler_case.contents, "The Brawler case has no right arm")
	TEST_ASSERT(locate(/obj/item/organ/cyberimp/cyberware/gorilla_arms/street/left) in brawler_case.contents, "The Brawler case has no left arm")
	var/obj/item/cyberware_pair_case/gorilla_arms/real_case = allocate(/obj/item/cyberware_pair_case/gorilla_arms)
	TEST_ASSERT(locate(/obj/item/organ/cyberimp/cyberware/gorilla_arms/left) in real_case.contents, "The Gorilla case lost its left arm")
	TEST_ASSERT(!(locate(/obj/item/organ/cyberimp/cyberware/gorilla_arms/street) in real_case.contents), "The Gorilla case holds Brawler myomers")

	// A real pair pries doors; a Brawler pair syncs into its own bonus; a mixed pair syncs into neither.
	var/mob/living/carbon/human/real_pair = allocate(/mob/living/carbon/human/consistent, run_loc_floor_bottom_left)
	TEST_ASSERT(real_right.Insert(real_pair, special = TRUE), "The right Gorilla arm wouldn't go in")
	TEST_ASSERT(real_left.Insert(real_pair, special = TRUE), "The left Gorilla arm wouldn't go in")
	var/datum/status_effect/organ_set_bonus/pair_bonus = real_pair.has_status_effect(/datum/status_effect/organ_set_bonus/cyberware_gorilla)
	TEST_ASSERT_NOTNULL(pair_bonus, "A Gorilla pair has no set bonus")
	TEST_ASSERT(pair_bonus.bonus_active, "A Gorilla pair doesn't pry doors")

	var/mob/living/carbon/human/brawler_pair = allocate(/mob/living/carbon/human/consistent, run_loc_floor_bottom_left)
	var/obj/item/organ/cyberimp/cyberware/gorilla_arms/street/pair_right = allocate(/obj/item/organ/cyberimp/cyberware/gorilla_arms/street)
	var/obj/item/organ/cyberimp/cyberware/gorilla_arms/street/left/pair_left = allocate(/obj/item/organ/cyberimp/cyberware/gorilla_arms/street/left)
	TEST_ASSERT(pair_right.Insert(brawler_pair, special = TRUE), "The right Brawler arm wouldn't go in")
	TEST_ASSERT(pair_left.Insert(brawler_pair, special = TRUE), "The left Brawler arm wouldn't go in")
	TEST_ASSERT_NULL(brawler_pair.has_status_effect(/datum/status_effect/organ_set_bonus/cyberware_gorilla), "A Brawler pair got the Gorilla's set bonus")
	var/datum/status_effect/organ_set_bonus/brawler_bonus = brawler_pair.has_status_effect(/datum/status_effect/organ_set_bonus/cyberware_brawler)
	TEST_ASSERT(brawler_bonus?.bonus_active, "A Brawler pair didn't sync")

	var/mob/living/carbon/human/mixed_pair = allocate(/mob/living/carbon/human/consistent, run_loc_floor_bottom_left)
	var/obj/item/organ/cyberimp/cyberware/gorilla_arms/mixed_real = allocate(/obj/item/organ/cyberimp/cyberware/gorilla_arms)
	var/obj/item/organ/cyberimp/cyberware/gorilla_arms/street/left/mixed_street = allocate(/obj/item/organ/cyberimp/cyberware/gorilla_arms/street/left)
	TEST_ASSERT(mixed_real.Insert(mixed_pair, special = TRUE), "The real arm wouldn't go in beside a Brawler arm")
	TEST_ASSERT(mixed_street.Insert(mixed_pair, special = TRUE), "The Brawler arm wouldn't go in beside a real arm")
	var/datum/status_effect/organ_set_bonus/mixed_bonus = mixed_pair.has_status_effect(/datum/status_effect/organ_set_bonus/cyberware_gorilla)
	TEST_ASSERT(!mixed_bonus?.bonus_active, "A real Gorilla arm and a Brawler arm pry doors")
	var/datum/status_effect/organ_set_bonus/mixed_brawler = mixed_pair.has_status_effect(/datum/status_effect/organ_set_bonus/cyberware_brawler)
	TEST_ASSERT(!mixed_brawler?.bonus_active, "A real Gorilla arm and a Brawler arm synced as Brawlers")

	// A punch lands for the model's damage and starts the model's clock.
	var/mob/living/carbon/human/victim = allocate(/mob/living/carbon/human/consistent, run_loc_floor_bottom_left)
	var/mob/living/carbon/human/puncher = allocate(/mob/living/carbon/human/consistent, run_loc_floor_bottom_left)
	var/obj/item/organ/cyberimp/cyberware/gorilla_arms/street/left/punch_arm = allocate(/obj/item/organ/cyberimp/cyberware/gorilla_arms/street/left)
	TEST_ASSERT(punch_arm.Insert(puncher, special = TRUE), "The punching arm wouldn't go in")
	puncher.set_combat_mode(TRUE)
	puncher.swap_hand(1)
	TEST_ASSERT_EQUAL(puncher.get_active_hand()?.body_zone, BODY_ZONE_L_ARM, "The test puncher isn't swinging with the left arm")
	var/hurt_before = victim.getBruteLoss()
	TEST_ASSERT_EQUAL(punch_arm.on_punch(puncher, victim, TRUE, null), COMPONENT_CANCEL_ATTACK_CHAIN, "The Brawler arm didn't take the punch")
	TEST_ASSERT_EQUAL(COOLDOWN_TIMELEFT(punch_arm, slam_cooldown), 5 SECONDS, "A Brawler punch didn't start the five second clock")
	TEST_ASSERT_NOTEQUAL(punch_arm.on_punch(puncher, victim, TRUE, null), COMPONENT_CANCEL_ATTACK_CHAIN, "A Brawler arm punched again on its clock")
	// The blow lands when the fist is there: 0.1 s after the click (GORILLA_THRUST_LANDS)
	sleep(0.3 SECONDS)
	TEST_ASSERT_EQUAL(victim.getBruteLoss() - hurt_before, 14, "A Brawler punch didn't land 14")

/// Tinker's fingers: the Fixer's three tools and a weaker servo speed-up under
/// its own key, so it never replaces the Fixer's.
/datum/unit_test/voidcrew_cyberware_models_a_fixers

/datum/unit_test/voidcrew_cyberware_models_a_fixers/Run()
	var/obj/item/organ/cyberimp/arm/toolkit/cyberware/fixers/parent = allocate(/obj/item/organ/cyberimp/arm/toolkit/cyberware/fixers)
	var/obj/item/organ/cyberimp/arm/toolkit/cyberware/fixers/street/street = allocate(/obj/item/organ/cyberimp/arm/toolkit/cyberware/fixers/street)

	TEST_ASSERT_EQUAL(parent.speed_modifier, /datum/actionspeed_modifier/cyberware_fixers, "The Fixer's speed-up changed")
	TEST_ASSERT_EQUAL(get_cached_actionspeed_modifier(parent.speed_modifier).multiplicative_slowdown, -0.25, "The Fixer's speed-up isn't a quarter")
	TEST_ASSERT_EQUAL(parent.chrome_load, 2, "The Fixer's load changed")
	TEST_ASSERT_EQUAL(parent.tier, 1, "The Fixer's tier changed")

	TEST_ASSERT_EQUAL(street.speed_modifier, /datum/actionspeed_modifier/cyberware_fixers/street, "Tinker's fingers use the wrong speed-up")
	TEST_ASSERT_EQUAL(get_cached_actionspeed_modifier(street.speed_modifier).multiplicative_slowdown, -0.1, "Tinker's speed-up isn't a tenth")
	TEST_ASSERT_EQUAL(street.chrome_load, 1, "Tinker's load isn't 1")
	TEST_ASSERT_EQUAL(street.tier, 1, "Tinker's fingers aren't tier 1")
	TEST_ASSERT_EQUAL(street.slot, parent.slot, "Tinker's fingers aren't in the Fixer's arm slot")
	TEST_ASSERT(street.speed_modifier != parent.speed_modifier, "Tinker's fingers would replace the Fixer's speed-up")
	TEST_ASSERT_EQUAL(length(street.items_to_create), length(parent.items_to_create), "Tinker's fingers carry a different number of tools")
	for(var/tool_path in parent.items_to_create)
		TEST_ASSERT(tool_path in street.items_to_create, "Tinker's fingers lost [tool_path]")

	// The speed-up rides the running ware: on with the fingers in, off with them out.
	var/mob/living/carbon/human/tinker = allocate(/mob/living/carbon/human/consistent, run_loc_floor_bottom_left)
	TEST_ASSERT(street.Insert(tinker, special = TRUE), "Tinker's fingers wouldn't go in")
	TEST_ASSERT(tinker.has_actionspeed_modifier(street.speed_modifier), "Tinker's fingers gave no speed-up")
	TEST_ASSERT(!tinker.has_actionspeed_modifier(parent.speed_modifier), "Tinker's fingers gave the Fixer's speed-up")
	street.Remove(tinker, special = TRUE)
	TEST_ASSERT(!tinker.has_actionspeed_modifier(street.speed_modifier), "The speed-up outlived Tinker's fingers")

	var/mob/living/carbon/human/fixer = allocate(/mob/living/carbon/human/consistent, run_loc_floor_bottom_left)
	TEST_ASSERT(parent.Insert(fixer, special = TRUE), "The Fixer's Fingers wouldn't go in")
	TEST_ASSERT(fixer.has_actionspeed_modifier(parent.speed_modifier), "The Fixer's Fingers gave no speed-up")
	TEST_ASSERT(!fixer.has_actionspeed_modifier(street.speed_modifier), "The Fixer's Fingers gave Tinker's speed-up")

/// The Deepcore: a heavier drill on the Rockjaw's hopper and buttons.
/datum/unit_test/voidcrew_cyberware_models_a_deepcore

/datum/unit_test/voidcrew_cyberware_models_a_deepcore/Run()
	var/obj/item/organ/cyberimp/arm/toolkit/cyberware/rockjaw/parent = allocate(/obj/item/organ/cyberimp/arm/toolkit/cyberware/rockjaw)
	var/obj/item/organ/cyberimp/arm/toolkit/cyberware/rockjaw/deepcore/deepcore = allocate(/obj/item/organ/cyberimp/arm/toolkit/cyberware/rockjaw/deepcore)
	TEST_ASSERT_EQUAL(parent.chrome_load, 2, "The Rockjaw's load changed")
	TEST_ASSERT_EQUAL(parent.tier, 1, "The Rockjaw's tier changed")
	TEST_ASSERT_EQUAL(deepcore.chrome_load, 3, "The Deepcore's load isn't 3")
	TEST_ASSERT_EQUAL(deepcore.tier, 2, "The Deepcore isn't tier 2")
	TEST_ASSERT_EQUAL(deepcore.slot, parent.slot, "The Deepcore isn't in the Rockjaw's arm slot")

	var/obj/item/pickaxe/drill/cyberware/rockjaw_drill = locate(/obj/item/pickaxe/drill/cyberware) in parent
	var/obj/item/pickaxe/drill/cyberware/deepcore/deepcore_drill = locate(/obj/item/pickaxe/drill/cyberware/deepcore) in deepcore
	TEST_ASSERT_NOTNULL(rockjaw_drill, "The Rockjaw has no drill")
	TEST_ASSERT_EQUAL(rockjaw_drill.type, /obj/item/pickaxe/drill/cyberware, "The Rockjaw carries a different drill")
	TEST_ASSERT_EQUAL(rockjaw_drill.toolspeed, 0.5, "The Rockjaw's drill changed speed")
	TEST_ASSERT_NOTNULL(deepcore_drill, "The Deepcore has no Deepcore drill")
	TEST_ASSERT_EQUAL(deepcore_drill.toolspeed, 0.3, "The Deepcore drill isn't 0.3")
	var/obj/item/pickaxe/drill/diamonddrill/diamond = allocate(/obj/item/pickaxe/drill/diamonddrill)
	TEST_ASSERT(deepcore_drill.toolspeed > diamond.toolspeed, "The Deepcore drill is faster than a diamond drill")
	TEST_ASSERT(deepcore_drill.toolspeed < rockjaw_drill.toolspeed, "The Deepcore drill isn't faster than the Rockjaw's")

	// The hopper button comes along.
	TEST_ASSERT(locate(/datum/action/item_action/organ_action/rockjaw_hopper) in deepcore.actions, "The Deepcore lost the ore hopper button")

/// The Holdout: six rounds of ordinary .38 in a folding arm revolver, thumbed in
/// by hand a round at a time, and the housing shows when someone looks at the arm.
/datum/unit_test/voidcrew_cyberware_models_a_holdout

/datum/unit_test/voidcrew_cyberware_models_a_holdout/Run()
	var/obj/item/organ/cyberimp/arm/toolkit/cyberware/ronin/ronin = allocate(/obj/item/organ/cyberimp/arm/toolkit/cyberware/ronin)
	var/obj/item/organ/cyberimp/arm/toolkit/cyberware/ronin/holdout/holdout = allocate(/obj/item/organ/cyberimp/arm/toolkit/cyberware/ronin/holdout)

	// The parent is untouched.
	TEST_ASSERT_EQUAL(ronin.chrome_load, 5, "The Ronin's load changed")
	TEST_ASSERT_EQUAL(ronin.tier, 3, "The Ronin's tier changed")
	TEST_ASSERT(/obj/item/gun/ballistic/automatic/cyberware_ronin in ronin.items_to_create, "The Ronin lost its machine pistol")

	TEST_ASSERT_EQUAL(holdout.chrome_load, 3, "The Holdout's load isn't 3")
	TEST_ASSERT_EQUAL(holdout.tier, 2, "The Holdout isn't tier 2")
	TEST_ASSERT_EQUAL(holdout.slot, ronin.slot, "The Holdout isn't in the Ronin's arm slot")
	TEST_ASSERT_EQUAL(holdout.zone, ronin.zone, "The Holdout isn't in the Ronin's arm zone")
	TEST_ASSERT_EQUAL(length(holdout.items_to_create), 1, "The Holdout carries more than the one revolver")
	TEST_ASSERT(!(/obj/item/gun/ballistic/automatic/cyberware_ronin in holdout.items_to_create), "The Holdout carries the Ronin's machine pistol")

	// A loaded six-shot .38 with a slow trigger.
	var/obj/item/gun/ballistic/revolver/cyberware_holdout/gun = locate() in holdout
	TEST_ASSERT_NOTNULL(gun, "The Holdout housing holds no revolver")
	TEST_ASSERT_EQUAL(gun.magazine.max_ammo, 6, "The Holdout's cylinder isn't six chambers")
	TEST_ASSERT_EQUAL(gun.magazine.caliber, CALIBER_38, "The Holdout doesn't take .38")
	TEST_ASSERT_EQUAL(gun.get_ammo(FALSE, FALSE), 6, "The Holdout doesn't leave the shop loaded")
	TEST_ASSERT_EQUAL(gun.fire_delay, 0.4 SECONDS, "The Holdout's trigger isn't 0.4 seconds")
	TEST_ASSERT(!gun.magazine.multiload, "The Holdout's cylinder loads a speedloader at once")

	// The cylinder takes a speedloader a round at a time. An ordinary revolver
	// cylinder takes all it has room for.
	var/mob/living/carbon/human/loader = allocate(/mob/living/carbon/human/consistent, run_loc_floor_bottom_left)
	var/obj/item/ammo_box/magazine/internal/cylinder/rev38/cyberware_holdout/cylinder = allocate(/obj/item/ammo_box/magazine/internal/cylinder/rev38/cyberware_holdout)
	var/obj/item/ammo_box/magazine/internal/cylinder/rev38/detective_cylinder = allocate(/obj/item/ammo_box/magazine/internal/cylinder/rev38)
	for(var/obj/item/ammo_box/magazine/internal/cylinder/rev38/emptied as anything in list(cylinder, detective_cylinder))
		// ammo_list() spawns the cylinder's lazy rounds, so there is something to remove.
		for(var/obj/item/ammo_casing/round in emptied.ammo_list())
			qdel(round)
		TEST_ASSERT_EQUAL(emptied.ammo_count(FALSE), 0, "A test cylinder didn't empty")
	var/obj/item/ammo_box/c38/speedloader = allocate(/obj/item/ammo_box/c38)
	var/obj/item/ammo_box/c38/second_speedloader = allocate(/obj/item/ammo_box/c38)
	TEST_ASSERT_EQUAL(cylinder.attackby(speedloader, loader, null, TRUE), 1, "The Holdout cylinder took more than a round from a speedloader")
	TEST_ASSERT_EQUAL(detective_cylinder.attackby(second_speedloader, loader, null, TRUE), 6, "An ordinary .38 cylinder stopped taking a whole speedloader")

	// A full cylinder has no room, a spent chamber or an empty one has.
	TEST_ASSERT(!gun.cylinder_has_room(), "A full Holdout cylinder claims room")
	var/list/rounds = gun.magazine.ammo_list()
	var/obj/item/ammo_casing/first_round = rounds[1]
	QDEL_NULL(first_round.loaded_projectile)
	TEST_ASSERT(gun.cylinder_has_room(), "A spent chamber doesn't count as room")
	// A full cylinder is refused outright, with no wait.
	var/obj/item/gun/ballistic/revolver/cyberware_holdout/full_gun = allocate(/obj/item/gun/ballistic/revolver/cyberware_holdout)
	TEST_ASSERT(!full_gun.load_gun(speedloader, loader), "A full Holdout cylinder took another round")
	TEST_ASSERT_EQUAL(full_gun.get_ammo(FALSE, FALSE), 6, "Refusing a round cost the Holdout one")

	// The housing shows when someone looks at the bearer, and stops when it is gone.
	var/mob/living/carbon/human/bearer = allocate(/mob/living/carbon/human/consistent, run_loc_floor_bottom_left)
	var/mob/living/carbon/human/onlooker = allocate(/mob/living/carbon/human/consistent, run_loc_floor_bottom_left)
	var/list/before_lines = list()
	SEND_SIGNAL(bearer, COMSIG_ATOM_EXAMINE, onlooker, before_lines)
	TEST_ASSERT(!findtext(jointext(before_lines, " "), "revolver housing"), "A body with no Holdout shows a revolver housing")
	TEST_ASSERT(holdout.Insert(bearer, special = TRUE), "The Holdout housing wouldn't go in")
	var/list/lines = list()
	SEND_SIGNAL(bearer, COMSIG_ATOM_EXAMINE, onlooker, lines)
	TEST_ASSERT(findtext(jointext(lines, " "), "revolver housing"), "Looking at the bearer doesn't show the Holdout housing")
	holdout.Remove(bearer, special = TRUE)
	var/list/after_lines = list()
	SEND_SIGNAL(bearer, COMSIG_ATOM_EXAMINE, onlooker, after_lines)
	TEST_ASSERT(!findtext(jointext(after_lines, " "), "revolver housing"), "The housing still shows after it was pulled")

/// What the shelf asks and what the ledger pays, per the plan. Every ledger
/// entry is half the shelf price of the piece, credits only, and takes both
/// ripperdocs' wording. The Vaulter is voucher chrome and has no entry.
/datum/unit_test/voidcrew_cyberware_models_a_shelf

/datum/unit_test/voidcrew_cyberware_models_a_shelf/Run()
	// SKU, what it sells, credits, vouchers, zone permission (0 public, 1 yellow, 2 advanced), pieces per sale
	var/list/shelf = list(
		list(/datum/shop_sku/ripperdoc/hopper_street, /obj/item/organ/cyberimp/cyberware/hopper/street, 1800, 0, 1, 1),
		list(/datum/shop_sku/ripperdoc/hopper_milspec, /obj/item/organ/cyberimp/cyberware/hopper/milspec, 0, 3, 2, 1),
		list(/datum/shop_sku/ripperdoc/gorilla_street, /obj/item/cyberware_pair_case/gorilla_arms/street, 2000, 0, 1, 2),
		list(/datum/shop_sku/ripperdoc/fixers_street, /obj/item/organ/cyberimp/arm/toolkit/cyberware/fixers/street, 700, 0, 0, 1),
		list(/datum/shop_sku/ripperdoc/rockjaw_deepcore, /obj/item/organ/cyberimp/arm/toolkit/cyberware/rockjaw/deepcore, 2400, 0, 0, 1),
		list(/datum/shop_sku/ripperdoc/ronin_holdout, /obj/item/organ/cyberimp/arm/toolkit/cyberware/ronin/holdout, 2400, 0, 1, 1),
	)
	build_cyberware_price_index()
	for(var/list/row as anything in shelf)
		var/datum/shop_sku/sku = allocate(row[1])
		TEST_ASSERT_EQUAL(sku.item_path, row[2], "[row[1]] sells the wrong item")
		TEST_ASSERT_EQUAL(sku.price_credits, row[3], "[row[1]] asks the wrong credits")
		TEST_ASSERT_EQUAL(sku.price_vouchers, row[4], "[row[1]] asks the wrong vouchers")
		TEST_ASSERT_EQUAL(sku.zone_permission, row[5], "[row[1]] sits at the wrong reputation")
		TEST_ASSERT(sku.price_credits <= 0 || sku.category == "Street Chrome", "[row[1]] is credit chrome off the street shelf")
		TEST_ASSERT(sku.price_vouchers <= 0 || sku.category == "Military Chrome", "[row[1]] is voucher chrome off the military shelf")
		if(row[1] == /datum/shop_sku/ripperdoc/ronin_holdout || row[1] == /datum/shop_sku/ripperdoc/gorilla_street)
			TEST_ASSERT(sku.fixed_price && !sku.contract_reward, "[row[1]] can be discounted or handed out as a contract reward")

	// What the cradle quotes for the pieces. A pair quotes the whole case on each half.
	var/list/quote = GLOB.cyberware_price_index[/obj/item/organ/cyberimp/cyberware/hopper/street]
	TEST_ASSERT(quote && quote["credits"] == 1800 && !quote["vouchers"], "Spring calves quote the wrong price")
	quote = GLOB.cyberware_price_index[/obj/item/organ/cyberimp/cyberware/hopper/milspec]
	TEST_ASSERT(quote && quote["vouchers"] == 3 && !quote["credits"], "Vaulter pistons quote the wrong price")
	for(var/pair_half in list(/obj/item/organ/cyberimp/cyberware/gorilla_arms/street, /obj/item/organ/cyberimp/cyberware/gorilla_arms/street/left))
		quote = GLOB.cyberware_price_index[pair_half]
		TEST_ASSERT(quote && quote["credits"] == 2000 && quote["paired"], "[pair_half] doesn't quote the pair's price")
	quote = GLOB.cyberware_price_index[/obj/item/organ/cyberimp/arm/toolkit/cyberware/ronin/holdout]
	TEST_ASSERT(quote && quote["credits"] == 2400, "The Holdout quotes the wrong price")

	// Ledger: half the shelf price of one piece, credits only, either side of a pair.
	var/list/ledgers = list(
		list(/datum/shop_buyback/ripperdoc/hopper_street, /datum/shop_buyback/ripperdoc/hopper_street/street_doc, /obj/item/organ/cyberimp/cyberware/hopper/street, 900),
		list(/datum/shop_buyback/ripperdoc/gorilla_street, /datum/shop_buyback/ripperdoc/gorilla_street/street_doc, /obj/item/organ/cyberimp/cyberware/gorilla_arms/street, 500),
		list(/datum/shop_buyback/ripperdoc/fixers_street, /datum/shop_buyback/ripperdoc/fixers_street/street_doc, /obj/item/organ/cyberimp/arm/toolkit/cyberware/fixers/street, 350),
		list(/datum/shop_buyback/ripperdoc/ronin_holdout, /datum/shop_buyback/ripperdoc/ronin_holdout/street_doc, /obj/item/organ/cyberimp/arm/toolkit/cyberware/ronin/holdout, 1200),
		list(/datum/shop_buyback/ripperdoc/rockjaw_deepcore, /datum/shop_buyback/ripperdoc/rockjaw_deepcore/street_doc, /obj/item/organ/cyberimp/arm/toolkit/cyberware/rockjaw/deepcore, 1200),
	)
	for(var/list/row as anything in ledgers)
		for(var/ledger_index in 1 to 2)
			var/datum/shop_buyback/ledger = allocate(row[ledger_index])
			TEST_ASSERT_EQUAL(ledger.item_path, row[3], "[row[ledger_index]] buys the wrong piece")
			TEST_ASSERT_EQUAL(ledger.pay_credits, row[4], "[row[ledger_index]] pays the wrong credits")
			TEST_ASSERT(!ledger.pay_vouchers, "[row[ledger_index]] pays vouchers")
			TEST_ASSERT(ledger.takes_shop_stock(), "[row[ledger_index]] refuses chrome bought at a counter")

	// Either side of a Brawler pair is taken, and nothing else of the Gorilla line.
	var/datum/shop_buyback/brawler_ledger = allocate(/datum/shop_buyback/ripperdoc/gorilla_street)
	TEST_ASSERT(brawler_ledger.matches(allocate(/obj/item/organ/cyberimp/cyberware/gorilla_arms/street)), "The ledger won't take a right Brawler arm")
	TEST_ASSERT(brawler_ledger.matches(allocate(/obj/item/organ/cyberimp/cyberware/gorilla_arms/street/left)), "The ledger won't take a left Brawler arm")
	TEST_ASSERT(!brawler_ledger.matches(allocate(/obj/item/organ/cyberimp/cyberware/gorilla_arms)), "The Brawler ledger takes a real Gorilla arm")
	var/datum/shop_buyback/spring_ledger = allocate(/datum/shop_buyback/ripperdoc/hopper_street)
	TEST_ASSERT(!spring_ledger.matches(allocate(/obj/item/organ/cyberimp/cyberware/hopper)), "The Spring calves ledger takes a Hopper")
	TEST_ASSERT(!spring_ledger.matches(allocate(/obj/item/organ/cyberimp/cyberware/hopper/milspec)), "The Spring calves ledger takes Vaulter pistons")
	var/datum/shop_buyback/tinker_ledger = allocate(/datum/shop_buyback/ripperdoc/fixers_street)
	TEST_ASSERT(!tinker_ledger.matches(allocate(/obj/item/organ/cyberimp/arm/toolkit/cyberware/fixers)), "The Tinker's ledger takes the Fixer's Fingers")
	var/datum/shop_buyback/deepcore_ledger = allocate(/datum/shop_buyback/ripperdoc/rockjaw_deepcore)
	TEST_ASSERT(!deepcore_ledger.matches(allocate(/obj/item/organ/cyberimp/arm/toolkit/cyberware/rockjaw)), "The Deepcore ledger takes a plain Rockjaw")
