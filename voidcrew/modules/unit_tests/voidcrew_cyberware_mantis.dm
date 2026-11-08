/**
 * # Mantis Blades line (Shiv and Scorch models)
 *
 * The street model has no lunge, the fire model keeps the parent's lunge and
 * adds fire, a cut lights the target and never the wielder, and the pair
 * cases quote prices through the cradle's index. Unit-test files compile before
 * voidcrew/_DEFINES/, so the numbers below are literals.
 */
/datum/unit_test/voidcrew_cyberware_mantis_line

/datum/unit_test/voidcrew_cyberware_mantis_line/Run()
	var/obj/item/organ/cyberimp/arm/toolkit/cyberware/mantis/parent = allocate(/obj/item/organ/cyberimp/arm/toolkit/cyberware/mantis)
	var/obj/item/organ/cyberimp/arm/toolkit/cyberware/mantis/street/street = allocate(/obj/item/organ/cyberimp/arm/toolkit/cyberware/mantis/street)
	var/obj/item/organ/cyberimp/arm/toolkit/cyberware/mantis/scorch/scorch = allocate(/obj/item/organ/cyberimp/arm/toolkit/cyberware/mantis/scorch)

	// The parent keeps its numbers: the defines became vars with the same values.
	TEST_ASSERT_EQUAL(parent.lunge_range, 5, "Mantis lunge range changed")
	TEST_ASSERT_EQUAL(parent.lunge_bonus, 10, "Mantis lunge bonus changed")
	TEST_ASSERT_EQUAL(parent.lunge_fire_stacks, 0, "The plain Mantis lunge sets people on fire")

	TEST_ASSERT(!(/datum/action/cooldown/cyberware/mantis_lunge in street.actions_types), "Shiv Blades got a lunge")
	TEST_ASSERT(/datum/action/cooldown/cyberware/mantis_lunge in scorch.actions_types, "Scorch Blades lost the lunge")
	TEST_ASSERT_EQUAL(scorch.lunge_fire_stacks, 4, "Scorch lunge fire is not 4 stacks")

	// Same slot as the parent, so the line evicts itself.
	TEST_ASSERT_EQUAL(street.slot, parent.slot, "Shiv housing is not in the Mantis arm slot")
	TEST_ASSERT_EQUAL(scorch.slot, parent.slot, "Scorch housing is not in the Mantis arm slot")
	var/obj/item/organ/cyberimp/arm/toolkit/cyberware/mantis/street/left/street_left = allocate(/obj/item/organ/cyberimp/arm/toolkit/cyberware/mantis/street/left)
	var/obj/item/organ/cyberimp/arm/toolkit/cyberware/mantis/scorch/left/scorch_left = allocate(/obj/item/organ/cyberimp/arm/toolkit/cyberware/mantis/scorch/left)
	TEST_ASSERT_EQUAL(street_left.slot, ORGAN_SLOT_LEFT_ARM_AUG, "Left Shiv housing is not in the left arm slot")
	TEST_ASSERT_EQUAL(scorch_left.slot, ORGAN_SLOT_LEFT_ARM_AUG, "Left Scorch housing is not in the left arm slot")

	// The weaker blade.
	var/obj/item/melee/energy/blade/hardlight/cyberware_mantis/street/street_blade = allocate(/obj/item/melee/energy/blade/hardlight/cyberware_mantis/street)
	TEST_ASSERT_EQUAL(street_blade.force, 14, "Shiv blade force is not 14")

	// Cases carry a matched pair of the right model.
	var/obj/item/cyberware_pair_case/mantis_street/street_case = allocate(/obj/item/cyberware_pair_case/mantis_street)
	var/obj/item/cyberware_pair_case/mantis_scorch/scorch_case = allocate(/obj/item/cyberware_pair_case/mantis_scorch)
	TEST_ASSERT_EQUAL(length(street_case.contents), 2, "Shiv case isn't a pair")
	TEST_ASSERT_EQUAL(length(scorch_case.contents), 2, "Scorch case isn't a pair")
	TEST_ASSERT(locate(/obj/item/organ/cyberimp/arm/toolkit/cyberware/mantis/street/left) in street_case.contents, "Shiv case has no left housing")
	TEST_ASSERT(locate(/obj/item/organ/cyberimp/arm/toolkit/cyberware/mantis/scorch/left) in scorch_case.contents, "Scorch case has no left housing")

	// Both halves of each case quote the case's price at the cradle.
	build_cyberware_price_index()
	var/list/street_price = get_cyberware_price(street)
	var/list/scorch_price = get_cyberware_price(scorch_left)
	TEST_ASSERT(street_price && street_price["credits"] > 0 && street_price["paired"], "Shiv Blades quote no credit price as a pair")
	TEST_ASSERT(scorch_price && scorch_price["vouchers"] > 0 && scorch_price["paired"], "Scorch Blades quote no voucher price as a pair")

/// A cut with the Scorch blade lights the target and never the one holding it,
/// and a corpse is left alone.
/datum/unit_test/voidcrew_cyberware_mantis_scorch

/datum/unit_test/voidcrew_cyberware_mantis_scorch/Run()
	var/mob/living/carbon/human/wielder = allocate(/mob/living/carbon/human/consistent)
	var/mob/living/carbon/human/victim = allocate(/mob/living/carbon/human/consistent)
	var/obj/item/melee/energy/blade/hardlight/cyberware_mantis/scorch/blade = allocate(/obj/item/melee/energy/blade/hardlight/cyberware_mantis/scorch)
	wielder.put_in_active_hand(blade)
	blade.attack(victim, wielder, list(), list())
	TEST_ASSERT(victim.fire_stacks >= 2, "A scorch cut left no fire stacks on the target")
	TEST_ASSERT(victim.on_fire, "A scorch cut didn't light the target")
	TEST_ASSERT(!wielder.on_fire && wielder.fire_stacks <= 0, "A scorch cut put fire on the wielder")

	var/mob/living/carbon/human/corpse = allocate(/mob/living/carbon/human/consistent)
	corpse.stat = DEAD
	TEST_ASSERT(!cyberware_scorch_target(corpse, 4), "A corpse was set alight")
	TEST_ASSERT(!corpse.on_fire, "A corpse is burning")
