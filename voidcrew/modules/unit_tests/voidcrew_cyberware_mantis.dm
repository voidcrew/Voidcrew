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

	// Item Initialize() turns actions_types into granted actions and nulls the list.
	TEST_ASSERT(!(locate(/datum/action/cooldown/cyberware/mantis_lunge) in (street.actions || list())), "Shiv Blades got a lunge")
	TEST_ASSERT(locate(/datum/action/cooldown/cyberware/mantis_lunge) in (scorch.actions || list()), "Scorch Blades lost the lunge")
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

/// The worn housing sprite shows the blade folded in, so each arm's housing
/// hides while that arm's blade is out and comes back when the blade is stowed,
/// knocked out of the hand, the chrome is EMP'd, or the housing is pulled.
/datum/unit_test/voidcrew_cyberware_mantis_stowed_overlay

/datum/unit_test/voidcrew_cyberware_mantis_stowed_overlay/Run()
	var/mob/living/carbon/human/bearer = allocate(/mob/living/carbon/human/consistent)
	var/obj/item/organ/cyberimp/arm/toolkit/cyberware/mantis/right = allocate(/obj/item/organ/cyberimp/arm/toolkit/cyberware/mantis)
	var/obj/item/organ/cyberimp/arm/toolkit/cyberware/mantis/left/left = allocate(/obj/item/organ/cyberimp/arm/toolkit/cyberware/mantis/left)
	TEST_ASSERT(right.Insert(bearer, special = TRUE), "Test fixture: right housing insert refused")
	TEST_ASSERT(left.Insert(bearer, special = TRUE), "Test fixture: left housing insert refused")
	var/obj/item/bodypart/right_arm = bearer.get_bodypart(BODY_ZONE_R_ARM)
	var/obj/item/bodypart/left_arm = bearer.get_bodypart(BODY_ZONE_L_ARM)
	var/obj/item/blade = right.contents[1]
	TEST_ASSERT(right.bodypart_aug in right_arm.bodypart_overlays, "Test fixture: the right housing has no worn overlay on the arm")
	TEST_ASSERT(stowed_drawn(bearer, right_arm, right), "A stowed housing isn't drawn")

	right.Extend(blade)
	TEST_ASSERT(bearer.is_holding(blade), "Test fixture: the blade never reached a hand")
	TEST_ASSERT(!stowed_drawn(bearer, right_arm, right), "The folded housing still draws with its blade out")
	TEST_ASSERT(stowed_drawn(bearer, left_arm, left), "Deploying the right blade hid the left housing")

	right.Retract()
	TEST_ASSERT(stowed_drawn(bearer, right_arm, right), "The housing didn't come back when the blade was stowed")

	right.Extend(blade)
	bearer.dropItemToGround(blade, force = TRUE)
	TEST_ASSERT(stowed_drawn(bearer, right_arm, right), "The housing stayed hidden after the blade left the hand")
	right.Retract()
	TEST_ASSERT(blade.loc == right, "Test fixture: the dropped blade never went back into the housing")

	var/datum/component/cyberware/chrome = right.GetComponent(/datum/component/cyberware)
	right.Extend(blade)
	chrome.start_emp_reboot()
	TEST_ASSERT(blade.loc == right, "Test fixture: the EMP didn't stow the blade")
	TEST_ASSERT(stowed_drawn(bearer, right_arm, right), "The housing stayed hidden after an EMP stowed the blade")
	chrome.tune_up()

	right.Extend(blade)
	right.Remove(bearer, special = TRUE)
	TEST_ASSERT(!(right.bodypart_aug in right_arm.bodypart_overlays), "A pulled housing left its overlay on the arm")
	// A fresh body: tg's arm implants never drop their bearer signals on removal,
	// so going back into the same body trips a double-registration warning.
	var/mob/living/carbon/human/next_bearer = allocate(/mob/living/carbon/human/consistent)
	TEST_ASSERT(right.Insert(next_bearer, special = TRUE), "Test fixture: installing the pulled housing was refused")
	TEST_ASSERT(stowed_drawn(next_bearer, next_bearer.get_bodypart(BODY_ZONE_R_ARM), right), "A housing pulled with its blade out doesn't draw in its next body")

/// TRUE when the housing's worn overlay is both allowed to draw and present in the
/// arm's last render key, so a missed redraw fails as well as a wrong check.
/datum/unit_test/voidcrew_cyberware_mantis_stowed_overlay/proc/stowed_drawn(mob/living/carbon/human/bearer, obj/item/bodypart/arm, obj/item/organ/cyberimp/arm/toolkit/cyberware/mantis/housing)
	var/drawable = housing.bodypart_aug.can_draw_on_bodypart(arm)
	var/in_key = !!findtext(bearer.icon_render_keys[arm.body_zone], housing.get_overlay_state())
	TEST_ASSERT_EQUAL(drawable, in_key, "[housing] can_draw_on_bodypart() and the arm's render key disagree, the arm was not redrawn")
	return drawable

/// Worn chrome with a glow (Cascade, Redline) must not black the glow out with
/// its own emissive blocker: the glow comes after every blocker the overlay makes.
/datum/unit_test/voidcrew_cyberware_worn_glow

/datum/unit_test/voidcrew_cyberware_worn_glow/Run()
	var/mob/living/carbon/human/bearer = allocate(/mob/living/carbon/human/consistent)
	var/obj/item/organ/cyberimp/cyberware/cascade/lattice = allocate(/obj/item/organ/cyberimp/cyberware/cascade)
	TEST_ASSERT(lattice.Insert(bearer, special = TRUE), "Test fixture: Cascade insert refused")
	var/obj/item/bodypart/chest = bearer.get_bodypart(BODY_ZONE_CHEST)
	var/list/images = lattice.bodypart_aug.get_overlay(EXTERNAL_ADJACENT, chest)
	var/glow_at = 0
	var/last_blocker_at = 0
	for(var/i in 1 to length(images))
		var/mutable_appearance/part = images[i]
		if(PLANE_TO_TRUE(part.plane) != EMISSIVE_PLANE)
			continue
		// The emissive matrix puts its glow in the constant row; a blocker's constant row is all zero.
		var/list/matrix = part.color
		if(islist(matrix) && length(matrix) >= 20 && (matrix[17] || matrix[18] || matrix[19]))
			glow_at = i
		else
			last_blocker_at = i
	TEST_ASSERT(glow_at, "The Cascade worn overlay has no glow")
	TEST_ASSERT(last_blocker_at, "The Cascade worn overlay has no emissive blocker")
	TEST_ASSERT(glow_at > last_blocker_at, "An emissive blocker sits on top of the Cascade glow")
