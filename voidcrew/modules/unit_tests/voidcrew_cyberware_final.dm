/**
 * # Cyberware: the final pass
 *
 * The fixes and owner-call defaults from the phase 2 code and balance reviews:
 * an armed chrome ability keeps the click it refuses, Ghostskin drops on every
 * kind of hit, the chrome wheel's zoom and stale chips, the deck's busy flag,
 * prison wing and pacifist refusals, its trader outpost strikes and load-weighted
 * Glitch, the full credit trade-in shelf (owner D7), and pirate bosses seeing
 * through camo.
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

/// The deck test's prompt (voidcrew_cyberware_deck.dm) answers room hack menus too.
/datum/action/cooldown/cyberware/deck/unit_test_prompt/choose_room_hack(mob/living/carbon/bearer, list/options)
	return (pick in options) ? pick : null

/// A refused click on an armed chrome ability is the chrome's: it never falls
/// through to the held gun, and the ability stays armed. One that went dark
/// while armed takes that click and disarms.
/datum/unit_test/voidcrew_cyberware_final/click/Run()
	var/mob/living/carbon/human/user = allocate(/mob/living/carbon/human/consistent, run_loc_floor_bottom_left)
	var/obj/item/organ/eyes/robotic/cyberware/nightshade/optics = allocate(/obj/item/organ/eyes/robotic/cyberware/nightshade)
	TEST_ASSERT(optics.Insert(user, special = TRUE), "Nightshade staging insert was refused")
	var/datum/action/cooldown/cyberware/chrome_read/action = locate() in optics.actions
	TEST_ASSERT_NOTNULL(action, "The optics granted no Chrome Read")
	var/obj/item/gun/ballistic/automatic/pistol/gun = allocate(/obj/item/gun/ballistic/automatic/pistol)
	TEST_ASSERT(user.put_in_active_hand(gun), "Test fixture: the reader couldn't hold the pistol")
	var/ammo = gun.get_ammo()
	TEST_ASSERT(ammo > 0, "Test fixture: the pistol spawned empty")
	var/turf/target = get_step(get_step(run_loc_floor_bottom_left, EAST), EAST)

	action.set_click_ability(user)
	TEST_ASSERT_EQUAL(user.click_intercept, action, "Test fixture: Chrome Read did not arm")
	// A floor tile has no chrome to read, so the read refuses it.
	TEST_ASSERT(user.check_click_intercept("left=1", target), "A refused chrome click fell through to an ordinary click")
	user.next_click = 0
	user.next_move = 0
	user.ClickOn(target, "left=1")
	TEST_ASSERT_EQUAL(gun.get_ammo(), ammo, "A refused chrome click fired the held gun")
	TEST_ASSERT_EQUAL(user.click_intercept, action, "A refused chrome click disarmed the ability")

	// Chrome that went dark while armed takes the click once and disarms.
	var/datum/component/cyberware/chrome = optics.GetComponent(/datum/component/cyberware)
	chrome.start_emp_reboot(EMP_HEAVY)
	TEST_ASSERT(!chrome.is_running(), "Test fixture: the optics stayed up through a reboot")
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
	TEST_ASSERT(GLOB.cyberware_camo_piercing_types[/mob/living/basic/trooper/pirate/faction/boss/nt_patrol], "The NT patrol's boss doesn't see through camo")

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

/// The deck: its busy flag can't outlive the deck being pulled or its own
/// timeout; a pacifist won't run a hack that hurts a person; nothing runs in a
/// prison wing, and its turrets don't reboot; Glitch picks by chrome load.
/datum/unit_test/voidcrew_cyberware_final/deck/Run()
	var/turf/location = run_loc_floor_bottom_left
	var/mob/living/carbon/human/user = allocate(/mob/living/carbon/human/consistent, location)
	var/mob/living/carbon/human/victim = allocate(/mob/living/carbon/human/consistent, get_step(location, EAST))
	var/obj/item/organ/cyberimp/cyberware/deck/flagship/deck = allocate(/obj/item/organ/cyberimp/cyberware/deck/flagship)
	TEST_ASSERT(deck.Insert(user, special = TRUE), "Blackbox deck staging insert was refused")
	var/datum/action/cooldown/cyberware/deck/unit_test_prompt/action = allocate(/datum/action/cooldown/cyberware/deck/unit_test_prompt, deck)
	action.Grant(user)
	var/datum/quickhack_kit/kit = deck.kit

	// Busy.
	action.mark_busy()
	TEST_ASSERT(action.is_busy(), "Test fixture: marking the deck busy didn't take")
	action.busy_until = world.time - 1
	TEST_ASSERT(!action.is_busy(), "A stale busy flag still counted")
	action.mark_busy()
	action.Remove(user)
	TEST_ASSERT(!action.is_busy(), "Pulling the deck left it busy")
	action.Grant(user)

	// Pacifism. The victim carries a charged cell, so Feedback Surge would land.
	var/obj/item/stock_parts/power_store/cell/high/cell = allocate(/obj/item/stock_parts/power_store/cell/high)
	victim.put_in_active_hand(cell)
	var/charge = cell.charge
	var/obj/item/organ/cyberimp/cyberware/registry_uplink/organ = allocate(/obj/item/organ/cyberimp/cyberware/registry_uplink)
	TEST_ASSERT(organ.Insert(victim, special = TRUE), "Registry uplink staging insert was refused")
	ADD_TRAIT(user, TRAIT_PACIFISM, TRAIT_SOURCE_UNIT_TESTS)
	for(var/path in list(/datum/machine_quickhack/feedback_surge, /datum/machine_quickhack/cutout, /datum/machine_quickhack/glitch))
		var/datum/machine_quickhack/entry = kit.find_quickhack(path)
		TEST_ASSERT_NOTNULL(entry, "The Blackbox deck doesn't carry [path]")
		TEST_ASSERT(entry.hurts_people, "[path] isn't marked as hurting people")
		TEST_ASSERT(entry.valid_for(victim, user), "Test fixture: [path] wasn't offered on the victim")
		action.pick = entry.name
		TEST_ASSERT_NULL(action.pick_quickhack(user, victim, list(entry)), "A pacifist picked [path] on a person")
		TEST_ASSERT(!action.upload_quickhack(user, victim, entry), "A pacifist ran [path] on a person")
	TEST_ASSERT_EQUAL(cell.charge, charge, "A pacifist's refused hack drained the victim's cell")
	var/datum/component/cyberware/chrome = organ.GetComponent(/datum/component/cyberware)
	TEST_ASSERT(chrome.is_running(), "A pacifist's refused Glitch rebooted the victim's chrome")
	TEST_ASSERT(action.next_use_time <= world.time, "A pacifist's refused hack charged a cooldown")
	var/datum/machine_masshack/spell = kit.find_masshack(/datum/machine_masshack/arc_flash)
	TEST_ASSERT_NOTNULL(spell, "The Blackbox deck doesn't carry Arc Flash")
	TEST_ASSERT(spell.hurts_people, "Arc Flash isn't marked as hurting people")
	action.pick = spell.name
	TEST_ASSERT_NULL(action.pick_room_hack(user, list(spell)), "A pacifist picked Arc Flash")
	// Hacks that touch only machines still run for a pacifist.
	var/datum/machine_quickhack/option = kit.find_quickhack(/datum/machine_quickhack/bolts)
	TEST_ASSERT(!option.hurts_people, "Bolts is marked as hurting people")
	action.pick = option.name
	var/obj/machinery/door/airlock/door = allocate(/obj/machinery/door/airlock, get_step(location, NORTH))
	TEST_ASSERT_EQUAL(action.pick_quickhack(user, door, list(option)), option, "A pacifist couldn't pick Bolts on a door")
	REMOVE_TRAIT(user, TRAIT_PACIFISM, TRAIT_SOURCE_UNIT_TESTS)
	action.pick = spell.name
	TEST_ASSERT_EQUAL(action.pick_room_hack(user, list(spell)), spell, "Arc Flash can't be picked once the pacifism is gone")
	// The same surge lands without the pacifism: the refusal above was the pacifism's.
	option = kit.find_quickhack(/datum/machine_quickhack/feedback_surge)
	TEST_ASSERT(action.upload_quickhack(user, victim, option), "Feedback Surge didn't land once the pacifism was gone")
	TEST_ASSERT(cell.charge < charge, "Feedback Surge landed without draining the cell")
	action.ResetCooldown()

	// Glitch picks by load: load-free chrome is never a target.
	var/datum/machine_quickhack/glitch/effect = kit.find_quickhack(/datum/machine_quickhack/glitch)
	var/mob/living/carbon/human/target = allocate(/mob/living/carbon/human/consistent, get_step(location, NORTHEAST))
	var/obj/item/organ/cyberimp/cyberware/chromatic_dermis/tattoo = allocate(/obj/item/organ/cyberimp/cyberware/chromatic_dermis)
	TEST_ASSERT(tattoo.Insert(target, special = TRUE), "Chromatic Dermis staging insert was refused")
	var/datum/component/cyberware/comp = tattoo.GetComponent(/datum/component/cyberware)
	TEST_ASSERT_EQUAL(comp.chrome_load, 0, "Test fixture: the Chromatic Dermis carries load")
	TEST_ASSERT(!effect.valid_for(target, user), "Glitch was offered on a body whose only chrome carries no load")
	var/obj/item/organ/cyberimp/cyberware/gecko/implant = allocate(/obj/item/organ/cyberimp/cyberware/gecko)
	TEST_ASSERT(implant.Insert(target, special = TRUE), "Gecko Grip staging insert was refused")
	chrome = implant.GetComponent(/datum/component/cyberware)
	var/list/weights = effect.running_chrome(target)
	TEST_ASSERT_EQUAL(length(weights), 1, "Glitch counts load-free chrome as a target")
	TEST_ASSERT_EQUAL(weights[implant], chrome.chrome_load, "Glitch doesn't weight a piece by its load")
	TEST_ASSERT(effect.execute(target, user), "Glitch didn't land on a body with loaded chrome")
	TEST_ASSERT(!chrome.is_running(), "Glitch didn't reboot the only loaded piece")
	TEST_ASSERT(comp.is_running(), "Glitch rebooted load-free chrome")
	// A Governor carries no load but holds the build up: it weighs its capacity.
	var/obj/item/organ/cyberimp/cyberware/governor_delete/street/governor = allocate(/obj/item/organ/cyberimp/cyberware/governor_delete/street)
	TEST_ASSERT(governor.Insert(target, special = TRUE), "Governor Patch staging insert was refused")
	comp = governor.GetComponent(/datum/component/cyberware)
	weights = effect.running_chrome(target)
	TEST_ASSERT_EQUAL(weights[governor], comp.capacity_bonus, "Glitch doesn't weight a Governor by the capacity it adds")

	// Prison wing. The deck stands in one: no room hack at all, and the wing's
	// turret doesn't reboot. Everything is read first and the tile put back
	// before anything is judged, so a failure leaves no stray prison area.
	var/datum/machine_masshack/signal = kit.find_masshack(/datum/machine_masshack/ping)
	var/datum/machine_quickhack/reboot_turret/thing = kit.find_quickhack(/datum/machine_quickhack/reboot_turret)
	var/obj/machinery/porta_turret/turret = allocate(/obj/machinery/porta_turret, get_step(get_step(location, EAST), EAST))
	var/result = thing.valid_for(turret, user)
	var/success = action.deck_allows_room(signal, user)
	var/area/old_area = get_area(location)
	var/area/voidcrew/player_outpost/prison/new_area = new
	location.change_area(old_area, new_area)
	var/obj/machinery/porta_turret/machine = new(location)
	var/value = thing.valid_for(machine, user)
	var/found = action.deck_allows_room(signal, user)
	var/valid = action.deck_allows_room(spell, user)
	var/started = action.start_room_hack(user)
	var/busy = action.is_busy()
	location.change_area(new_area, old_area)
	qdel(machine)
	qdel(new_area)
	TEST_ASSERT(result, "Reboot Turret wasn't offered on an ordinary turret")
	TEST_ASSERT(success, "Ping is refused outside a prison wing")
	TEST_ASSERT(!value, "Reboot Turret was offered on a prison wing turret")
	TEST_ASSERT(!found && !valid, "A room hack is allowed inside a prison wing")
	TEST_ASSERT(!started && !busy, "The deck started a room hack inside a prison wing")

/// At a trader outpost, Silence on a floor tile and Electrify on a docked
/// ship's door are strikes against the hacker, like a punch.
/datum/unit_test/voidcrew_cyberware_final/outpost/Run()
	var/turf/location = run_loc_floor_bottom_left
	var/obj/structure/overmap/trader_outpost/outpost = allocate(/obj/structure/overmap/trader_outpost)
	outpost.outpost_template = allocate(/datum/map_template/trader_outpost)
	outpost.outpost_template.width = 4
	outpost.outpost_template.height = 4
	outpost.template_bottom_left = location
	var/mob/living/carbon/human/user = allocate(/mob/living/carbon/human/consistent, location)
	user.mind_initialize()
	var/mob/living/carbon/human/victim = allocate(/mob/living/carbon/human/consistent, get_step(location, NORTH))
	victim.mind_initialize()
	var/obj/item/organ/cyberimp/cyberware/deck/control/deck = allocate(/obj/item/organ/cyberimp/cyberware/deck/control)
	TEST_ASSERT(deck.Insert(user, special = TRUE), "Facilities deck staging insert was refused")
	var/datum/action/cooldown/cyberware/deck/action = locate() in deck.actions
	TEST_ASSERT_NOTNULL(action, "The Facilities deck granted no button")
	var/turf/target = get_step(location, EAST)
	TEST_ASSERT(is_trader_outpost_protected(target), "Test fixture: the floor tile isn't trader outpost ground")

	var/datum/machine_quickhack/entry = deck.kit.find_quickhack(/datum/machine_quickhack/silence)
	TEST_ASSERT(entry.valid_for(target, user), "Test fixture: Silence wasn't offered with a shopper in view")
	var/result = action.upload_quickhack(user, target, entry)
	// The jam would sit on the test room for 45 s and silence other tests' radios.
	for(var/obj/item/jammer/machine_communion/jammer in target)
		jammer.active = FALSE
		GLOB.active_jammers -= jammer
	TEST_ASSERT(result, "Silence did not land on a floor tile")
	TEST_ASSERT_EQUAL(outpost.aggressor_strikes[user.mind], 1, "Jamming a trader outpost's floor took no strike")
	action.ResetCooldown()
	outpost.aggressor_strike_times.Cut()

	var/obj/machinery/door/airlock/door = allocate(/obj/machinery/door/airlock, get_step(target, NORTH))
	door.machine_stat = NONE
	entry = deck.kit.find_quickhack(/datum/machine_quickhack/electrify)
	TEST_ASSERT(action.upload_quickhack(user, door, entry), "Electrify did not land on a door")
	TEST_ASSERT_EQUAL(outpost.aggressor_strikes[user.mind], 2, "Running a door live at a trader outpost took no strike")
	TEST_ASSERT_NULL(outpost.aggressor_strikes[victim.mind], "A bystander took a strike for someone else's hack")

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
