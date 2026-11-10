/**
 * # Chrome animations
 *
 * The animations only draw, but they leave things on a body while they play:
 * holders in vis_contents, filters, worn looks and pending frames. These check
 * that each animation puts them on and that they come off again when it is cut
 * short: the blade stowed, the chrome pulled, the field broken, the bearer dead.
 *
 * Unit-test files compile before voidcrew/_DEFINES/ and the module's own
 * defines are local, so looks and filter names are literals here.
 */

/// TRUE if any chrome animation holder is still drawn on [bearer].
/proc/voidcrew_test_has_chrome_anim(atom/movable/bearer)
	return !!(locate(/obj/effect/abstract/cyberware_anim) in bearer.vis_contents)

/// Mantis: the swing rides the bearer, the fold replaces the unfold, and
/// pulling the housing takes the swing and the folded-housing wait with it.
/datum/unit_test/voidcrew_cyberware_anim_blade

/datum/unit_test/voidcrew_cyberware_anim_blade/Run()
	var/mob/living/carbon/human/bearer = allocate(/mob/living/carbon/human/consistent)
	var/obj/item/organ/cyberimp/arm/toolkit/cyberware/mantis/housing = allocate(/obj/item/organ/cyberimp/arm/toolkit/cyberware/mantis)
	TEST_ASSERT(housing.Insert(bearer, special = TRUE), "Test fixture: Mantis housing insert refused")
	var/obj/item/melee/energy/blade/hardlight/cyberware_mantis/blade = housing.contents[1]

	housing.Extend(blade)
	TEST_ASSERT(bearer.is_holding(blade), "Test fixture: the blade never reached a hand")
	var/obj/effect/abstract/cyberware_anim/unfold = housing.blade_anim()
	TEST_ASSERT(unfold && (unfold in bearer.vis_contents), "The blade swing didn't play on the bearer")
	TEST_ASSERT_EQUAL(unfold.icon_state, "mantis_unfold_right", "The right housing played the wrong swing")
	TEST_ASSERT(blade.inhand_hidden_until > world.time, "The held blade draws before the swing has played")

	housing.Retract()
	TEST_ASSERT(QDELETED(unfold), "Stowing the blade left the unfold swing playing")
	var/obj/effect/abstract/cyberware_anim/fold = housing.blade_anim()
	TEST_ASSERT(fold && (fold in bearer.vis_contents), "The blade didn't fold back in")
	TEST_ASSERT_EQUAL(fold.icon_state, "mantis_fold_right", "The right housing folded the wrong swing")
	TEST_ASSERT_EQUAL(housing.cyberware_worn_look(), "fold", "The folded housing draws over the fold swing")
	TEST_ASSERT(findtext(bearer.icon_render_keys[BODY_ZONE_R_ARM], "fold"), "The arm wasn't redrawn for the fold")

	// A blade knocked out of the hand is stowed without a fold.
	housing.Extend(blade)
	bearer.dropItemToGround(blade, force = TRUE)
	housing.Retract()
	TEST_ASSERT(isnull(housing.cyberware_worn_look()), "A blade stowed off the floor hid the housing for a fold")

	housing.Extend(blade)
	var/obj/effect/abstract/cyberware_anim/last_swing = housing.blade_anim()
	TEST_ASSERT(last_swing, "Test fixture: the last swing never played")
	housing.Remove(bearer, special = TRUE)
	TEST_ASSERT(QDELETED(last_swing) && isnull(housing.blade_anim_ref), "Pulling the housing left its swing")
	TEST_ASSERT(!voidcrew_test_has_chrome_anim(bearer), "Pulling the housing left a swing drawn on the body")
	TEST_ASSERT(!housing.fold_hide_until && !housing.fold_timer, "Pulling the housing left the folded housing waiting")
	TEST_ASSERT(!blade.inhand_hidden_until, "A pulled housing's blade stays hidden in its next hand")

/// Mantis: a pose taken while the blade is still unfolding (the charge's crouch) stops the unfold, so its
/// guard never draws over the new pose, and the held blade shows at once in it.
/datum/unit_test/voidcrew_cyberware_anim_unfold_handoff

/datum/unit_test/voidcrew_cyberware_anim_unfold_handoff/Run()
	var/mob/living/carbon/human/bearer = allocate(/mob/living/carbon/human/consistent)
	var/obj/item/organ/cyberimp/arm/toolkit/cyberware/mantis/housing = allocate(/obj/item/organ/cyberimp/arm/toolkit/cyberware/mantis)
	TEST_ASSERT(housing.Insert(bearer, special = TRUE), "Test fixture: Mantis housing insert refused")
	var/obj/item/melee/energy/blade/hardlight/cyberware_mantis/blade = housing.contents[1]
	housing.Extend(blade)
	var/obj/effect/abstract/cyberware_anim/unfold = housing.blade_anim()
	TEST_ASSERT(unfold, "Test fixture: the unfold never played")

	blade.set_mantis_pose("coil")
	TEST_ASSERT(QDELETED(unfold), "The unfold kept drawing its guard over the coiled blade")
	TEST_ASSERT(!blade.inhand_hidden_until, "The coiled blade stayed hidden after the unfold stopped")

/// Ghostskin: the field flickers in to plain field alpha with nothing else on
/// the bearer, and every way out (run out, switched off, knocked down, pulled,
/// dead) ends at full view, back where the body started, with nothing left on it.
/datum/unit_test/voidcrew_cyberware_anim_cloak

/datum/unit_test/voidcrew_cyberware_anim_cloak/Run()
	var/mob/living/carbon/human/bearer = allocate(/mob/living/carbon/human/consistent)
	var/obj/item/organ/cyberimp/cyberware/ghostskin/weave = allocate(/obj/item/organ/cyberimp/cyberware/ghostskin)
	TEST_ASSERT(weave.Insert(bearer, special = TRUE), "Test fixture: Ghostskin insert refused")
	var/filters_before = length(bearer.filter_data)
	var/rest_w = bearer.pixel_w

	weave.engage_camo(bearer)
	TEST_ASSERT_EQUAL(bearer.alpha, 40, "The flicker doesn't end at the field's alpha")
	TEST_ASSERT_EQUAL(bearer.pixel_w, rest_w, "The flicker's jumps don't add up to nothing")
	TEST_ASSERT(weave.cloak_enter_until > world.time, "Nothing keeps a step from cutting the flicker short")
	TEST_ASSERT_EQUAL(length(bearer.filter_data), filters_before, "The field put a filter on its bearer")
	TEST_ASSERT(!voidcrew_test_has_chrome_anim(bearer), "The field put a drawing on its bearer")
	weave.cloak_enter_until = 0
	weave.on_camo_move(bearer)
	TEST_ASSERT_EQUAL(bearer.alpha, 40, "Moving under the field left the bearer brighter")

	// Run out: the gentle way back.
	weave.on_field_expired()
	TEST_ASSERT(!weave.camo_active, "Test fixture: the field didn't run out")
	TEST_ASSERT_EQUAL(bearer.alpha, 255, "A field that ran out left its bearer faded")
	TEST_ASSERT_EQUAL(bearer.pixel_w, rest_w, "The way back out left the body off to one side")

	// Knocked down: the sharp way back.
	weave.engage_camo(bearer)
	weave.break_camo(bearer, reason = "test")
	TEST_ASSERT_EQUAL(bearer.alpha, 255, "A knocked-down field left its bearer faded")
	TEST_ASSERT_EQUAL(bearer.pixel_w, rest_w, "The knock left the body off to one side")
	TEST_ASSERT_EQUAL(length(bearer.filter_data), filters_before, "A broken field left a filter behind")
	TEST_ASSERT(!voidcrew_test_has_chrome_anim(bearer), "A broken field left a drawing behind")

	// Switched off by hand.
	var/datum/action/cooldown/cyberware/ghostskin_cloak/button = locate() in weave.actions
	weave.engage_camo(bearer)
	button.Activate(bearer)
	TEST_ASSERT(!weave.camo_active, "Test fixture: the button didn't drop the field")
	TEST_ASSERT_EQUAL(bearer.alpha, 255, "A field switched off left its bearer faded")

	// Pulled mid-flicker, and dead mid-field.
	weave.engage_camo(bearer)
	weave.Remove(bearer, special = TRUE)
	TEST_ASSERT_EQUAL(bearer.alpha, 255, "A weave pulled mid-flicker left its bearer faded")
	TEST_ASSERT_EQUAL(bearer.pixel_w, rest_w, "A weave pulled mid-flicker left the body off to one side")
	TEST_ASSERT(!weave.cloak_enter_until, "A pulled weave still holds off the moving flash")

	var/mob/living/carbon/human/doomed = allocate(/mob/living/carbon/human/consistent)
	var/obj/item/organ/cyberimp/cyberware/ghostskin/street/rag = allocate(/obj/item/organ/cyberimp/cyberware/ghostskin/street)
	TEST_ASSERT(rag.Insert(doomed, special = TRUE), "Test fixture: Flickerskin insert refused")
	var/doomed_filters = length(doomed.filter_data)
	rag.engage_camo(doomed)
	TEST_ASSERT_EQUAL(doomed.alpha, 60, "Flickerskin doesn't flicker down to its own alpha")
	doomed.death()
	TEST_ASSERT(!rag.camo_active, "Test fixture: death didn't drop the field")
	TEST_ASSERT_EQUAL(doomed.alpha, 255, "Death left the body faded")
	TEST_ASSERT(length(doomed.filter_data) <= doomed_filters, "Death left a filter on the body")

/// Cascade: the window lights the spine, the crash kills it, the crash ending
/// puts the plain lattice back, and a lattice pulled mid-window leaves no frames.
/datum/unit_test/voidcrew_cyberware_anim_cascade

/datum/unit_test/voidcrew_cyberware_anim_cascade/Run()
	var/mob/living/carbon/human/bearer = allocate(/mob/living/carbon/human/consistent)
	var/obj/item/organ/cyberimp/cyberware/cascade/lattice = allocate(/obj/item/organ/cyberimp/cyberware/cascade)
	TEST_ASSERT(lattice.Insert(bearer, special = TRUE), "Test fixture: Cascade insert refused")

	bearer.apply_status_effect(/datum/status_effect/cyberware_cascade_window, lattice)
	TEST_ASSERT_EQUAL(lattice.node_look, "boot1", "The spine didn't start lighting when the window opened")
	TEST_ASSERT(lattice.node_timer, "The spine lit one node and stopped")
	TEST_ASSERT(lattice.ring_timer, "No ring is coming")
	TEST_ASSERT(findtext(bearer.icon_render_keys[BODY_ZONE_CHEST], "boot1"), "The chest wasn't redrawn for the node frame")
	var/list/images = lattice.bodypart_aug.get_overlay(EXTERNAL_ADJACENT, bearer.get_bodypart(BODY_ZONE_CHEST))
	var/found_nodes = FALSE
	for(var/image/part as anything in images)
		if(part.icon_state == "cascade_boot1")
			found_nodes = TRUE
			// CYBERWARE_SPINE_SHINE_LAYER; the chrome itself sits at CYBERWARE_WORN_LAYER, 27.6. Both are defined after the tests.
			TEST_ASSERT_EQUAL(part.layer, -13.7, "Lit nodes don't shine through what is worn on the back")
	TEST_ASSERT(found_nodes, "The node frame isn't drawn over the lattice")
	// A dying frame is split: what still glows shines through, the dead nodes stay under the clothes.
	lattice.node_look = "crash3"
	var/found_lit = FALSE
	var/found_dark = FALSE
	for(var/image/part as anything in lattice.bodypart_aug.get_overlay(EXTERNAL_ADJACENT, bearer.get_bodypart(BODY_ZONE_CHEST)))
		if(part.icon_state == "cascade_crash3_lit" && part.layer == -13.7)
			found_lit = TRUE
		if(part.icon_state == "cascade_crash3_dark" && part.layer == -27.6)
			found_dark = TRUE
	TEST_ASSERT(found_lit, "The nodes still lit in a dying frame don't shine through")
	TEST_ASSERT(found_dark, "The dead nodes of a dying frame aren't under the clothes")
	lattice.node_look = "dead"
	for(var/image/part as anything in lattice.bodypart_aug.get_overlay(EXTERNAL_ADJACENT, bearer.get_bodypart(BODY_ZONE_CHEST)))
		TEST_ASSERT(part.layer != -13.7, "A dead spine still draws over what is worn on the back")
	lattice.node_look = "boot1"

	bearer.remove_status_effect(/datum/status_effect/cyberware_cascade_window)
	TEST_ASSERT(bearer.has_status_effect(/datum/status_effect/cyberware_cascade_crash), "Test fixture: no crash after the window")
	TEST_ASSERT_EQUAL(lattice.node_look, "crash1", "The spine didn't start dying with the crash")
	TEST_ASSERT(!lattice.ring_timer, "The ring rolls out after the window closed")

	bearer.remove_status_effect(/datum/status_effect/cyberware_cascade_crash)
	TEST_ASSERT_NULL(lattice.node_look, "The crash ended on a node frame")
	TEST_ASSERT(!lattice.node_timer, "Node frames keep playing after the crash")

	bearer.apply_status_effect(/datum/status_effect/cyberware_cascade_window, lattice)
	lattice.Remove(bearer, special = TRUE)
	TEST_ASSERT_NULL(lattice.node_look, "A lattice pulled mid-window kept its node frame")
	TEST_ASSERT(!lattice.node_timer && !lattice.ring_timer, "A lattice pulled mid-window kept playing")

/// EMP: every worn piece gets the static look and joins one show; the show
/// ends with its bearer, and the reboot and a tune-up both clear the look.
/datum/unit_test/voidcrew_cyberware_anim_emp

/datum/unit_test/voidcrew_cyberware_anim_emp/Run()
	var/mob/living/carbon/human/bearer = allocate(/mob/living/carbon/human/consistent)
	var/obj/item/organ/cyberimp/cyberware/gorilla_arms/arm = allocate(/obj/item/organ/cyberimp/cyberware/gorilla_arms)
	var/obj/item/organ/cyberimp/cyberware/cascade/lattice = allocate(/obj/item/organ/cyberimp/cyberware/cascade)
	TEST_ASSERT(arm.Insert(bearer, special = TRUE), "Test fixture: Gorilla Arms insert refused")
	TEST_ASSERT(lattice.Insert(bearer, special = TRUE), "Test fixture: Cascade insert refused")
	var/datum/component/cyberware/arm_chrome = arm.GetComponent(/datum/component/cyberware)
	var/datum/component/cyberware/spine_chrome = lattice.GetComponent(/datum/component/cyberware)

	arm_chrome.start_emp_reboot()
	spine_chrome.start_emp_reboot()
	var/datum/component/chrome_emp_show/show = bearer.GetComponent(/datum/component/chrome_emp_show)
	TEST_ASSERT(show, "An EMP on worn chrome put on no show")
	TEST_ASSERT_EQUAL(length(show.crackling), 2, "Two pieces hit on one tick aren't one burst")
	TEST_ASSERT_EQUAL(arm.cyberware_worn_look(), "static", "An EMP'd piece doesn't fill with static")
	var/list/images = arm.bodypart_aug.get_overlay(EXTERNAL_ADJACENT, bearer.get_bodypart(BODY_ZONE_R_ARM))
	var/image/plate = images[1]
	TEST_ASSERT(plate.appearance_flags & KEEP_TOGETHER, "The static isn't clipped to the piece")

	bearer.death()
	TEST_ASSERT(QDELETED(show), "The EMP show outlived its bearer")
	TEST_ASSERT(!voidcrew_test_has_chrome_anim(bearer), "Arcs or sparks stayed on a dead bearer")
	TEST_ASSERT_EQUAL(arm.cyberware_worn_look(), "dark", "Dead, the EMP'd chrome isn't drawn dark")
	images = arm.bodypart_aug.get_overlay(EXTERNAL_ADJACENT, bearer.get_bodypart(BODY_ZONE_R_ARM))
	plate = images[1]
	TEST_ASSERT(islist(plate.color), "A dark piece isn't drawn dark")

	arm_chrome.finish_emp_reboot()
	TEST_ASSERT_NULL(arm.cyberware_worn_look(), "A rebooted piece kept a look")
	spine_chrome.tune_up()
	TEST_ASSERT_NULL(lattice.cyberware_worn_look(), "A tuned-up piece kept a look")

	// Pulled while crackling: the piece drops its look, the show carries on without it.
	var/mob/living/carbon/human/next_bearer = allocate(/mob/living/carbon/human/consistent)
	var/obj/item/organ/cyberimp/cyberware/gorilla_arms/left/left_arm = allocate(/obj/item/organ/cyberimp/cyberware/gorilla_arms/left)
	TEST_ASSERT(left_arm.Insert(next_bearer, special = TRUE), "Test fixture: left Gorilla Arms insert refused")
	var/datum/component/cyberware/left_chrome = left_arm.GetComponent(/datum/component/cyberware)
	left_chrome.start_emp_reboot()
	TEST_ASSERT(next_bearer.GetComponent(/datum/component/chrome_emp_show), "Test fixture: no show on the second bearer")
	left_arm.Remove(next_bearer, special = TRUE)
	TEST_ASSERT_NULL(left_chrome.emp_look, "A piece pulled mid-EMP kept its static")

/// Skin plating is skin: it draws under the clothes with stock augments, while the rest of the chrome stays over
/// the jumpsuit.
/datum/unit_test/voidcrew_cyberware_anim_skin_plating

/datum/unit_test/voidcrew_cyberware_anim_skin_plating/Run()
	for(var/plating_type in list(/obj/item/organ/cyberimp/cyberware/slabskin, /obj/item/organ/cyberimp/cyberware/dermal_mesh, /obj/item/organ/cyberimp/cyberware/dermal_mesh/hardweave))
		var/obj/item/organ/cyberimp/cyberware/plating = allocate(plating_type)
		TEST_ASSERT_EQUAL(plating.bodypart_aug.bitflag_to_layer(EXTERNAL_ADJACENT), -BODY_ADJ_LAYER, "[plating_type] draws over clothes")
	// CYBERWARE_WORN_LAYER, which is defined after the tests.
	var/obj/item/organ/cyberimp/cyberware/cascade/lattice = allocate(/obj/item/organ/cyberimp/cyberware/cascade)
	TEST_ASSERT_EQUAL(lattice.bodypart_aug.bitflag_to_layer(EXTERNAL_ADJACENT), -27.6, "The spine rig dropped under the jumpsuit")
