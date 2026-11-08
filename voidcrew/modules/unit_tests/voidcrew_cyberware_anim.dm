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

/// Ghostskin: the sweep filters come up with the field, give way to the
/// shimmer, and every filter is off the bearer once the field breaks and the
/// weave is pulled. The alpha var itself is unchanged by the sweep.
/datum/unit_test/voidcrew_cyberware_anim_cloak

/datum/unit_test/voidcrew_cyberware_anim_cloak/Run()
	var/static/list/field_filters = list("cyberware_cloak_mask", "cyberware_cloak_band", "cyberware_cloak_rim", "cyberware_cloak_wave", "cyberware_cloak_ripple")
	var/mob/living/carbon/human/bearer = allocate(/mob/living/carbon/human/consistent)
	var/obj/item/organ/cyberimp/cyberware/ghostskin/weave = allocate(/obj/item/organ/cyberimp/cyberware/ghostskin)
	TEST_ASSERT(weave.Insert(bearer, special = TRUE), "Test fixture: Ghostskin insert refused")

	weave.engage_camo(bearer)
	TEST_ASSERT_EQUAL(bearer.alpha, 40, "The sweep changed the field's alpha")
	TEST_ASSERT(bearer.get_filter("cyberware_cloak_mask"), "The field came up without its sweep")
	TEST_ASSERT(bearer.get_filter("cyberware_cloak_band"), "The sweep has no refraction band")
	TEST_ASSERT(weave.cloak_settle_timer, "Nothing ends the sweep")
	var/obj/effect/abstract/cyberware_anim/edge = weave.cloak_edge_ref?.resolve()
	TEST_ASSERT(edge && (edge in bearer.vis_contents), "The sweep has no refraction line")

	weave.cloak_settle()
	qdel(edge) // Its own lifetime is the sweep's.
	TEST_ASSERT(!bearer.get_filter("cyberware_cloak_mask"), "The sweep mask stayed on after the sweep")
	TEST_ASSERT(bearer.get_filter("cyberware_cloak_wave"), "The held field doesn't shimmer")
	TEST_ASSERT(bearer.get_filter("cyberware_cloak_rim"), "The held field has no rim")

	weave.break_camo(bearer, reason = "test")
	for(var/filter_name in field_filters - "cyberware_cloak_ripple")
		TEST_ASSERT(!bearer.get_filter(filter_name), "A broken field left [filter_name] on its bearer")
	TEST_ASSERT(bearer.get_filter("cyberware_cloak_ripple"), "The field broke without collapsing")
	TEST_ASSERT(weave.cloak_crackle_timer, "The field broke without a crackle")
	weave.cloak_crackle(WEAKREF(bearer))
	TEST_ASSERT(voidcrew_test_has_chrome_anim(bearer), "The crackle didn't play on the bearer")

	weave.Remove(bearer, special = TRUE)
	TEST_ASSERT(!bearer.get_filter("cyberware_cloak_ripple"), "Pulling the weave left the collapse on its old bearer")

	// Pulled mid-sweep, and dead mid-field: nothing stays behind either way.
	var/mob/living/carbon/human/next_bearer = allocate(/mob/living/carbon/human/consistent)
	TEST_ASSERT(weave.Insert(next_bearer, special = TRUE), "Test fixture: Ghostskin reinsert refused")
	weave.engage_camo(next_bearer)
	weave.Remove(next_bearer, special = TRUE)
	for(var/filter_name in field_filters)
		TEST_ASSERT(!next_bearer.get_filter(filter_name), "A weave pulled mid-sweep left [filter_name] behind")
	TEST_ASSERT(!voidcrew_test_has_chrome_anim(next_bearer), "A weave pulled mid-sweep left its refraction line")
	TEST_ASSERT(!weave.cloak_crackle_timer && !weave.cloak_settle_timer, "A pulled weave kept animating")

	var/mob/living/carbon/human/doomed = allocate(/mob/living/carbon/human/consistent)
	TEST_ASSERT(weave.Insert(doomed, special = TRUE), "Test fixture: Ghostskin third insert refused")
	weave.engage_camo(doomed)
	doomed.death()
	TEST_ASSERT(!weave.camo_active, "Test fixture: death didn't drop the field")
	for(var/filter_name in field_filters - "cyberware_cloak_ripple")
		TEST_ASSERT(!doomed.get_filter(filter_name), "Death left [filter_name] on the body")

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
	TEST_ASSERT(found_nodes, "The node frame isn't drawn over the lattice")

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
