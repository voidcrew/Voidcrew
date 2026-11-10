/**
 * # Cyberware: the final pass
 *
 * The fixes and owner-call defaults from the phase 2 code and balance reviews:
 * an armed chrome ability takes the click it refuses and drops its aim, Ghostskin drops on every
 * kind of hit, the chrome wheel's zoom and stale chips, the full credit trade-in
 * shelf (owner D7), and pirate bosses seeing through camo.
 *
 * NOTE: the CI build (CIBUILDING) sits at a DM compiler limit on unique
 * identifiers. A new local or type name anywhere can fail the compile with
 * "<name>: invalid variable" on a var/static in some unrelated file. So these
 * tests reuse names the codebase already has, and live under one parent.
 *
 * Unit-test files compile before voidcrew/_DEFINES/, so fork defines are
 * literals here: "cyber_camo" is TRAIT_CYBER_CAMO.
 */
/datum/unit_test/voidcrew_cyberware_final
	abstract_type = /datum/unit_test/voidcrew_cyberware_final

/// A click on an armed chrome ability is the chrome's: a refused one never falls
/// through to the held gun, and it drops the aim with the cooldown untouched. A
/// right-click, a stun, or waiting too long drops it too, and so does chrome that
/// went dark while armed. Chrome has no button to click it off, so nothing may
/// leave it armed and eating clicks.
/datum/unit_test/voidcrew_cyberware_final/click/Run()
	var/mob/living/carbon/human/user = allocate(/mob/living/carbon/human/consistent, run_loc_floor_bottom_left)
	var/obj/item/organ/cyberimp/arm/toolkit/cyberware/icepick/optics = allocate(/obj/item/organ/cyberimp/arm/toolkit/cyberware/icepick)
	TEST_ASSERT(optics.Insert(user, special = TRUE), "Icepick staging insert was refused")
	var/datum/action/cooldown/cyberware/icepick/suppress/action = locate() in optics.actions
	TEST_ASSERT_NOTNULL(action, "The Icepick granted no Suppress")
	TEST_ASSERT(action.IsAvailable(), "Test fixture: Suppress can't be used")
	var/obj/item/gun/ballistic/automatic/pistol/gun = allocate(/obj/item/gun/ballistic/automatic/pistol)
	TEST_ASSERT(user.put_in_active_hand(gun), "Test fixture: the user couldn't hold the pistol")
	var/ammo = gun.get_ammo()
	TEST_ASSERT(ammo > 0, "Test fixture: the pistol spawned empty")
	var/turf/target = get_step(get_step(run_loc_floor_bottom_left, EAST), EAST)

	// A floor tile has no port for the spike.
	action.set_click_ability(user)
	TEST_ASSERT_EQUAL(user.click_intercept, action, "Test fixture: Suppress did not arm")
	user.next_click = 0
	user.next_move = 0
	user.ClickOn(target, "left=1")
	TEST_ASSERT_EQUAL(gun.get_ammo(), ammo, "A refused chrome click fired the held gun")
	TEST_ASSERT(user.click_intercept != action, "A click on a floor tile left the Icepick armed")
	TEST_ASSERT(action.next_use_time <= world.time, "A refused spike started the cooldown")
	TEST_ASSERT(!user.check_click_intercept("left=1", target), "A disarmed ability still took a click")

	// Right-click drops the aim without trying.
	action.set_click_ability(user)
	TEST_ASSERT(user.check_click_intercept("right=1", target), "A right-click on an armed ability fell through")
	TEST_ASSERT(user.click_intercept != action, "A right-click left the Icepick armed")

	// Armed and left waiting.
	action.set_click_ability(user)
	action.on_timeout()
	TEST_ASSERT(user.click_intercept != action, "An aim left waiting never dropped")

	// Stunned while armed.
	action.set_click_ability(user)
	user.Stun(2 SECONDS)
	TEST_ASSERT(user.click_intercept != action, "A stun left the Icepick armed")
	user.SetStun(0)
	TEST_ASSERT(action.IsAvailable(), "Test fixture: Suppress stayed down after the stun")

	// Chrome that went dark while armed takes the click once and disarms.
	action.set_click_ability(user)
	var/datum/component/cyberware/chrome = optics.GetComponent(/datum/component/cyberware)
	chrome.start_emp_reboot(EMP_HEAVY)
	TEST_ASSERT(!chrome.is_running(), "Test fixture: the Icepick stayed up through a reboot")
	TEST_ASSERT(user.check_click_intercept("left=1", target), "An armed ability that went dark let the click through")
	TEST_ASSERT(user.click_intercept != action, "An armed ability that went dark stayed armed")
	TEST_ASSERT(!user.check_click_intercept("left=1", target), "A disarmed ability still took a click")

/// Being mauled by an animal, a mob, a mech or a xeno drops the Ghostskin field,
/// and so does a real shock. A hallucinated or fully insulated one doesn't. And
/// every faction's pirate boss sees through camo, the NT patrol's included.
/datum/unit_test/voidcrew_cyberware_final/camo/Run()
	var/mob/living/carbon/human/user = allocate(/mob/living/carbon/human/consistent, run_loc_floor_bottom_left)
	var/obj/item/organ/cyberimp/cyberware/ghostskin/weave = allocate(/obj/item/organ/cyberimp/cyberware/ghostskin)
	TEST_ASSERT(weave.Insert(user, special = TRUE), "Ghostskin staging insert was refused")
	var/mob/living/basic/mouse/mouse = allocate(/mob/living/basic/mouse, get_step(run_loc_floor_bottom_left, EAST))

	for(var/signal in list(COMSIG_ATOM_ATTACK_ANIMAL, COMSIG_ATOM_ATTACK_BASIC_MOB, COMSIG_ATOM_ATTACK_MECH, COMSIG_MOB_ATTACK_ALIEN))
		weave.engage_camo(user)
		TEST_ASSERT(weave.camo_active, "Test fixture: the field did not come up before [signal]")
		SEND_SIGNAL(user, signal, mouse)
		TEST_ASSERT(!weave.camo_active, "[signal] left the Ghostskin field up")
		TEST_ASSERT(!HAS_TRAIT(user, "cyber_camo"), "[signal] dropped the field but left the camo trait")

	weave.engage_camo(user)
	user.electrocute_act(10, mouse, 1, SHOCK_ILLUSION)
	TEST_ASSERT(weave.camo_active, "A hallucinated shock dropped the field")
	user.electrocute_act(10, mouse, 0)
	TEST_ASSERT(weave.camo_active, "A shock the gloves fully insulated dropped the field")
	user.electrocute_act(10, mouse, 1)
	TEST_ASSERT(!weave.camo_active, "A real shock left the field up")

	TEST_ASSERT(GLOB.cyberware_camo_piercing_types[/mob/living/basic/trooper/pirate/faction/boss], "A pirate boss doesn't see through camo")
	// The NT patrol's boss is a person now: it sees through camo by rank (HUMAN_NPC_RANK_BOSS is 2).
	var/mob/living/carbon/human/npc/director_type = /mob/living/carbon/human/npc/faction_pirate/nt_customs/director
	TEST_ASSERT_EQUAL(initial(director_type.npc_rank), 2, "The NT patrol's boss doesn't see through camo")

/// The wheel shows the zoom as on while zoomed, and a chip whose chrome was
/// cut out while the wheel was held open can't be picked.
/datum/unit_test/voidcrew_cyberware_final/wheel/Run()
	var/mob/living/carbon/human/user = allocate(/mob/living/carbon/human/consistent)
	var/obj/item/organ/eyes/robotic/cyberware/spyglass/optics = allocate(/obj/item/organ/eyes/robotic/cyberware/spyglass)
	TEST_ASSERT(optics.Insert(user, special = TRUE), "Spyglass staging insert was refused")
	var/datum/action/cooldown/cyberware/optics_zoom/zoom = locate() in optics.actions
	TEST_ASSERT_NOTNULL(zoom, "The optics granted no zoom")
	TEST_ASSERT(!chrome_wheel_ability_active(zoom, user), "The wheel shows an idle zoom as on")
	optics.engage_zoom(user)
	TEST_ASSERT(optics.is_zoomed(), "Test fixture: the zoom didn't engage")
	TEST_ASSERT(chrome_wheel_ability_active(zoom, user), "The wheel doesn't show the zoom as on while zoomed")
	optics.stop_zoom(user)
	TEST_ASSERT(!chrome_wheel_ability_active(zoom, user), "The wheel still shows the zoom as on after it ended")

	var/obj/item/organ/cyberimp/cyberware/hopper/pistons = allocate(/obj/item/organ/cyberimp/cyberware/hopper)
	TEST_ASSERT(pistons.Insert(user, special = TRUE), "Hopper staging insert was refused")
	var/datum/action/cooldown/cyberware/hopper_leap/action = locate() in pistons.actions
	TEST_ASSERT_NOTNULL(action, "The Hopper granted no leap")
	var/datum/component/chrome_wheel/wheel = get_chrome_wheel(user)
	TEST_ASSERT_NOTNULL(wheel, "A chromed body got no wheel")
	wheel.build_wheel(get_chrome_wheel_actions(user))
	var/atom/movable/screen/chrome_wheel/chip/found
	for(var/atom/movable/screen/chrome_wheel/chip/chip as anything in wheel.chips)
		if(chip.ability_ref?.resolve() == action)
			found = chip
	TEST_ASSERT_NOTNULL(found, "The built wheel has no chip for the leap")
	pistons.Remove(user, special = TRUE)
	TEST_ASSERT(!wheel.select_chip(found, quiet = TRUE), "A chip was picked after its chrome came out")
	TEST_ASSERT_NULL(wheel.get_selected_ability(), "The wheel kept a pick for chrome that came out")
	wheel.close_wheel()

/// Owner D7: every piece a ripperdoc sells for credits comes back at half list,
/// credits only, at both ripperdocs, even where Ratchet doesn't sell it.
/datum/unit_test/voidcrew_cyberware_final/ledger/Run()
	var/datum/outpost_shop/vendor/ripperdoc/splice = allocate(/datum/outpost_shop/vendor/ripperdoc)
	var/datum/outpost_shop/vendor/street_doc/ratchet = allocate(/datum/outpost_shop/vendor/street_doc)
	// Each credit-only piece on Splice's shelf: what one piece of it costs.
	var/list/prices = list()
	for(var/datum/shop_sku/sku_type as anything in splice.sku_types)
		if(initial(sku_type.price_credits) <= 0 || initial(sku_type.price_vouchers) > 0)
			continue
		var/item_path = initial(sku_type.item_path)
		var/list/pieces = list()
		if(ispath(item_path, /obj/item/organ))
			pieces += item_path
		else if(ispath(item_path, /obj/item/cyberware_pair_case) || ispath(item_path, /obj/item/storage/case/cyberware))
			var/obj/item/sample = new item_path(null)
			for(var/obj/item/organ/held in sample.contents)
				pieces += held.type
			for(var/atom/movable/packed as anything in sample.contents.Copy())
				qdel(packed)
			qdel(sample)
		for(var/piece in pieces)
			prices[piece] = initial(sku_type.price_credits) / length(pieces)
	TEST_ASSERT(length(prices) >= 40, "Splice's credit shelf looks empty ([length(prices)] pieces)")

	for(var/datum/outpost_shop/shop as anything in list(splice, ratchet))
		for(var/piece in prices)
			var/datum/shop_buyback/found
			for(var/datum/shop_buyback/buyback_type as anything in shop.buyback_types)
				var/path = initial(buyback_type.item_path)
				if(initial(buyback_type.match_subtypes) ? ispath(piece, path) : piece == path)
					found = buyback_type
					break
			if(!found)
				TEST_FAIL("[shop.type] has no trade-in for [piece], which Splice sells for credits")
				continue
			if(initial(found.pay_credits) * 2 != prices[piece])
				TEST_FAIL("[found] pays [initial(found.pay_credits)] cr for [piece], not half its [prices[piece]] cr list")
			if(initial(found.pay_vouchers))
				TEST_FAIL("[found] pays vouchers")
