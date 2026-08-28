/**
 * # The attackby -> item_interaction migration, and what it took with it
 *
 * The 2026-08 tg merge moved a large amount of "you clicked this with that" handling out of
 * `attackby()` and into `item_interaction()` / the `*_act()` family. Both of those run
 * **inside `base_item_interaction`**, which `melee_attack_chain` calls *before* it ever
 * reaches `pre_attack` and `attackby` (item_attack.dm:32-36). So every fork override that
 * was still sitting in `attackby` stopped being the first thing the click met - upstream's
 * new body got there first, did upstream's thing, and returned a non-zero flag that ended
 * the click before the fork's guard ran.
 *
 * The chain, in the order `base_item_interaction` walks it (atom_tool_acts.dm:8-52), because
 * every test in this file is an argument about position in it:
 *
 *   1. `tool_act()` -> `<tool>_act()` — **only when combat mode is OFF**
 *   2. three signals (atom, then tool, then user)
 *   3. `item_interaction()` — runs in **both** combat modes; the secondary variant defaults
 *      to the primary, so a right click lands in the same proc
 *   4. `tool.interact_with_atom()`
 *   5. storage insertion
 *
 * Any non-zero return ends the click. `ITEM_INTERACT_FAILURE` is `ITEM_INTERACT_BLOCKING`, so
 * "I refused this" and "I handled this" both stop the chain - which is why a *refusal* by
 * upstream's body is just as fatal to a fork guard downstream as a success would be.
 *
 * Six live breaks came out of that, one per test below, plus three residual repairs that
 * belong to the same click-path family. Each test names its incident.
 *
 * ## The rules this file plays by
 *
 * - **Real clicks.** Everything enters at `ClickOn` through the `vc_click_with_item()` /
 *   `vc_click_bare_hand()` fixtures. The bugs are all about *which handler gets the click*,
 *   and a test that calls the handler directly has already assumed the answer.
 * - **Both combat modes where the modes differ.** `base_item_interaction` skips step 1
 *   entirely in combat mode, so a fix that only sits in `<tool>_act` is invisible to a player
 *   holding combat mode, and a fix that only sits in `item_interaction` runs in both. Where
 *   that distinction is the point, both are driven.
 * - **No fork defines.** Unit tests compile at tgstation.dme:6898, ahead of
 *   `voidcrew/_DEFINES/` (7189+). Type paths and vars are global and fine; `#define`s are not.
 * - **Test-only subtypes are marked and minimal.** Two handlers cannot be driven headless -
 *   `RedeemVoucher()` blocks on `show_radial_menu()`, and `build_camera()` sits behind a
 *   material silo and a `do_after` - so each gets one probe subtype that stubs exactly the
 *   blocking call and nothing else. The body under test is the real one in both cases.
 */

// ===========================================================================
// Probe subtypes (test-only; see the header)
// ===========================================================================

/**
 * A marine vendor whose voucher redemption records the voucher instead of opening a radial menu.
 *
 * `RedeemVoucher()` calls `show_radial_menu(..., require_near = TRUE)`, which blocks waiting
 * for a client selection and can never return in a headless test. The proc under test is not
 * that one anyway: it is `item_interaction()`, and the only thing the test needs to know is
 * whether the voucher reached the redemption at all. Everything else about the vendor -
 * products, access, `compartmentLoadAccessCheck()`, the parent's load branch - is untouched.
 */
/obj/machinery/vending/security/marine/vc_voucher_probe
	/// The voucher the last redemption was handed, or null if redemption never ran.
	var/obj/item/gun_voucher/redeemed_voucher

/obj/machinery/vending/security/marine/vc_voucher_probe/RedeemVoucher(obj/item/gun_voucher/voucher, mob/redeemer)
	redeemed_voucher = voucher

/**
 * A ship RCD that pays nothing and waits for nothing.
 *
 * `build_camera()`'s first three statements are a silo material check, a 2-second
 * `build_delay()` and a second material check - none of which is what upstream broke. The
 * break is in the four lines after them, and this probe removes the price of reaching those
 * lines without touching one of them. The overrides are deliberately total: a partial stub
 * (say, a silo with materials in it) would put the test's outcome at the mercy of the
 * economy subsystem.
 */
/obj/item/construction/rcd/internal/ship/vc_camera_probe

/obj/item/construction/rcd/internal/ship/vc_camera_probe/check_materials(list/materials, mob/user)
	return TRUE

/obj/item/construction/rcd/internal/ship/vc_camera_probe/use_materials(list/materials, mob/user)
	return TRUE

/obj/item/construction/rcd/internal/ship/vc_camera_probe/build_delay(mob/user, delay, atom/target)
	return TRUE

// ===========================================================================
// 1. Bank machine — cash on an unlinked machine (voidcrew/modules/cargo/bank_machine.dm)
// ===========================================================================

/**
 * An unlinked bank machine refuses money instead of eating it.
 *
 * Upstream moved the deposit branch into `/obj/machinery/computer/bank_machine/item_interaction`
 * (bank_machine.dm:47-67), and that branch runs `qdel(tool)` **outside** the
 * `if(synced_bank_account)` that decides whether the money is credited anywhere. The fork's
 * guard was still an `attackby()` override, which `base_item_interaction` never reaches once
 * `item_interaction` has returned SUCCESS - so a machine nobody had swiped an ID on destroyed
 * every note and holochip fed into it, silently, and said "credits deposited" to no account.
 *
 * Four clicks, because the machine has to behave the same on all of them: cash with no
 * account, cash with an account, an ID card, and cash with no account **in combat mode**.
 * The last one is not padding - `item_interaction` is not gated on combat mode at all
 * (only `tool_act` is), so if the guard had been put in a `*_act` proc instead it would have
 * covered the ordinary click and left the combat-mode one destroying money.
 *
 * One inherited hole is left alone and recorded here rather than asserted away: a coin or a
 * poker chip is still consumed by an unlinked machine, because the fork's guard only lists
 * spacecash and holochips. That was true before the upgrade too.
 */
/datum/unit_test/voidcrew_bank_machine_cash_guard

/datum/unit_test/voidcrew_bank_machine_cash_guard/Run()
	var/mob/living/carbon/human/consistent/customer = allocate(/mob/living/carbon/human/consistent)
	var/obj/machinery/computer/bank_machine/teller = allocate(/obj/machinery/computer/bank_machine)

	TEST_ASSERT_NULL(teller.synced_bank_account, "the bank machine spawned already linked to an account - its Initialize() is supposed to clear the link, and the refusal below is untestable while it holds")

	// --- unlinked, ordinary click ---
	var/obj/item/holochip/loose_cash = allocate(/obj/item/holochip, null, 500)
	var/machine_integrity = teller.get_integrity()

	if(!vc_click_with_item(customer, teller, loose_cash))
		return

	TEST_ASSERT(!QDELETED(loose_cash), "a holochip fed to a bank machine with no account linked was destroyed. Upstream's item_interaction qdel()s the money outside the if(synced_bank_account) \
		that credits it, so an unswiped machine is a shredder - the fork's refusal has to sit in the same hook, ahead of upstream's body.")
	TEST_ASSERT_EQUAL(teller.get_integrity(), machine_integrity, "refusing a holochip damaged the bank machine - the refusal returned a falsy value and the click carried on into the attack chain")

	// --- unlinked, combat mode: same hook, and item_interaction is not gated on it ---
	// The fixtures put an item in the ACTIVE hand and can_put_in_hand() refuses a full one, so
	// anything the last click left there has to go before the next item can be picked up.
	customer.drop_all_held_items()
	var/obj/item/holochip/combat_cash = allocate(/obj/item/holochip, null, 500)

	if(!vc_click_with_item(customer, teller, combat_cash, combat_mode = TRUE))
		return

	TEST_ASSERT(!QDELETED(combat_cash), "a holochip fed to an unlinked bank machine with combat mode ON was destroyed. base_item_interaction skips tool_act in combat mode but runs item_interaction \
		either way, so a guard that only covers the non-combat click leaves this path shredding money.")

	// --- an ID binds the account, and does not bash the machine ---
	customer.drop_all_held_items()
	var/datum/bank_account/vault = allocate(/datum/bank_account, "Unit Test Vault", null, 1, FALSE)
	var/obj/item/card/id/crew_id = allocate(/obj/item/card/id)
	crew_id.registered_account = vault
	machine_integrity = teller.get_integrity()

	if(!vc_click_with_item(customer, teller, crew_id))
		return

	TEST_ASSERT_EQUAL(teller.synced_bank_account, vault, "swiping an ID card on the bank machine did not bind its account")
	TEST_ASSERT_EQUAL(teller.get_integrity(), machine_integrity, "swiping an ID card on the bank machine damaged it - the ID branch has to consume the click, or the card goes on to bash the console")

	// --- linked: the money is taken, and credited ---
	customer.drop_all_held_items()
	var/obj/item/holochip/deposit = allocate(/obj/item/holochip, null, 500)
	var/starting_balance = vault.account_balance

	if(!vc_click_with_item(customer, teller, deposit))
		return

	TEST_ASSERT(QDELETED(deposit), "a holochip fed to a bank machine with a linked account was not consumed - the fork's refusal is now swallowing deposits that should reach upstream's branch")
	TEST_ASSERT_EQUAL(vault.account_balance, starting_balance + 500, "a 500 credit holochip deposited into a linked bank machine moved the balance from [starting_balance] to [vault.account_balance]")

// ===========================================================================
// 2. The bottomless ration (voidcrew/modules/loot/uniques/plunder.dm)
// ===========================================================================

/**
 * The bottomless ration bottle refills itself on a swig that went down, and only then.
 *
 * The bottle's whole gimmick was an `attack()` override, which chained onto
 * `/obj/item/reagent_containers/cup/attack` - the proc that used to do the drinking.
 * Upstream deleted `cup/attack` and moved the swig into `cup/try_drink()`, reached from
 * `cup/interact_with_atom()` at step 4 of `base_item_interaction`, which returns
 * ITEM_INTERACT_SUCCESS and therefore ends the click before `attackby`/`attack` are reached
 * at all. The bottle kept working as rum and quietly stopped being bottomless, and stopped
 * granting its pain-immunity window, the moment that landed.
 *
 * The refill is asserted through the volume staying put across three swigs rather than
 * through a "was refill called" flag, because the failure players saw was the bottle
 * emptying, not a proc going uncalled.
 *
 * The refused-swig half needs a **part-empty** bottle to be visible at all: `add_reagent()`
 * caps at `maximum_volume`, so a full bottle topping itself up after a blocked swig looks
 * exactly like a full bottle that correctly did nothing. Draining 20u first makes the
 * difference measurable, which is the whole reason the old code's "top up even on a refusal"
 * bug could hide.
 */
/datum/unit_test/voidcrew_bottomless_ration

/datum/unit_test/voidcrew_bottomless_ration/Run()
	var/mob/living/carbon/human/consistent/drinker = allocate(/mob/living/carbon/human/consistent)
	var/obj/item/reagent_containers/cup/glass/bottle/bottomless_ration/bottle = allocate(/obj/item/reagent_containers/cup/glass/bottle/bottomless_ration)

	TEST_ASSERT_NOTNULL(bottle.reagents, "the bottomless ration has no reagent holder")
	var/full_volume = bottle.reagents.total_volume
	TEST_ASSERT(full_volume > 0, "the bottomless ration spawned empty, so there is nothing to swig and nothing to top back up")

	drinker.take_bodypart_damage(20)
	var/brute_before = drinker.get_brute_loss()
	TEST_ASSERT(brute_before > 0, "the test drinker took no damage, so the bottle's healing cannot be measured")

	// Clicking yourself with a drink is the drink action: ClickOn -> DirectAccess (self) ->
	// melee_attack_chain -> cup/interact_with_atom -> isliving -> try_drink.
	if(!vc_click_with_item(drinker, drinker, bottle))
		return

	TEST_ASSERT_EQUAL(bottle.reagents.total_volume, full_volume, "the bottomless ration went from [full_volume]u to [bottle.reagents.total_volume]u after one swig. Upstream moved the drink out of \
		cup/attack and into cup/try_drink(); an attack() override never runs any more, because cup/interact_with_atom ends the click at step 4 of base_item_interaction.")
	TEST_ASSERT(HAS_TRAIT(drinker, TRAIT_ANALGESIA), "a swig from the bottomless ration did not grant TRAIT_ANALGESIA - grant_liquid_courage() was not reached")
	TEST_ASSERT(drinker.get_brute_loss() < brute_before, "a swig from the bottomless ration healed no brute damage ([brute_before] before, [drinker.get_brute_loss()] after)")

	// Twice more, because "never runs dry" is a claim about repetition.
	for(var/swig in 1 to 2)
		if(!vc_click_with_item(drinker, drinker, bottle))
			return
		TEST_ASSERT_EQUAL(bottle.reagents.total_volume, full_volume, "the bottomless ration held [bottle.reagents.total_volume]u instead of [full_volume]u after swig [swig + 1]")

	// --- a swig that never went down must not top the bottle up ---
	var/mob/living/carbon/human/consistent/masked_drinker = allocate(/mob/living/carbon/human/consistent)
	var/obj/item/clothing/mask/gas/muzzle = allocate(/obj/item/clothing/mask/gas)
	masked_drinker.equip_to_slot_if_possible(muzzle, ITEM_SLOT_MASK, disable_warning = TRUE)
	TEST_ASSERT_EQUAL(masked_drinker.wear_mask, muzzle, "the gas mask did not go onto the test drinker's face, so canconsume() would not refuse and this half of the test is vacuous")

	var/obj/item/reagent_containers/cup/glass/bottle/bottomless_ration/part_bottle = allocate(/obj/item/reagent_containers/cup/glass/bottle/bottomless_ration)
	part_bottle.reagents.remove_reagent(/datum/reagent/consumable/ethanol/rum, 20)
	var/part_volume = part_bottle.reagents.total_volume
	TEST_ASSERT(part_volume > 0 && part_volume < full_volume, "draining the second bottle left [part_volume]u, which is not a part-full bottle - an overfill after a refused swig would be invisible")

	if(!vc_click_with_item(masked_drinker, masked_drinker, part_bottle))
		return

	TEST_ASSERT_EQUAL(part_bottle.reagents.total_volume, part_volume, "a swig blocked by a covered mouth still topped the bottle up, from [part_volume]u to [part_bottle.reagents.total_volume]u. \
		try_drink() answers a refusal with ITEM_INTERACT_BLOCKING; the refill has to check for ITEM_INTERACT_SUCCESS before it adds anything back.")
	TEST_ASSERT(!HAS_TRAIT(masked_drinker, TRAIT_ANALGESIA), "a swig blocked by a covered mouth still granted the bottle's pain-immunity window")

// ===========================================================================
// 3. The drop pod's three tools (voidcrew/modules/drop_pod/drop_pod.dm)
// ===========================================================================

/**
 * A drop pod answers its own crowbar, wrench and multitool in both combat modes.
 *
 * Upstream migrated the whole closet family off `attackby`: the tools now land in
 * `/obj/structure/closet/{crowbar,screwdriver,welder}_act` and in
 * `/obj/structure/closet/item_interaction`, and every one of those opens with
 * `if(user in contents) return ITEM_INTERACT_BLOCKING`. Two things broke at once.
 *
 *  - **An open pod ate the tool.** The closet parent's `item_interaction` drops any held
 *    item into an opened closet and returns SUCCESS, so the pod's `attackby` never ran and
 *    the crowbar you were using went into the pod.
 *  - **A sealed rider was entombed.** The inside-guard fires before anything the pod could
 *    say, so somebody who had ridden a one-shot pod down could no longer pry the hatch open
 *    from inside it.
 *
 * The fix answers all three tools ahead of every parent guard, which takes both hooks -
 * `crowbar_act`/`wrench_act`/`multitool_act` for the combat-mode-off click, and
 * `item_interaction` for the combat-mode-on click, where `tool_act` never runs. Both are
 * driven below, and the rider case is driven in both modes for the same reason.
 */
/datum/unit_test/voidcrew_drop_pod_tools
	/// How many extra tiles of the test floor bench_tile() has handed out.
	var/tiles_taken = 0

/**
 * A tile of the test room's 5x5 floor that is **not** the default allocate() spot, so pods,
 * pads and their riders never stack up on one turf. Starts at offset 1 for exactly that reason.
 */
/datum/unit_test/voidcrew_drop_pod_tools/proc/bench_tile()
	var/turf/origin = run_loc_floor_bottom_left
	tiles_taken++
	var/turf/spot = locate(origin.x + (tiles_taken % 5), origin.y + round(tiles_taken / 5), origin.z)
	if(isnull(spot))
		TEST_FAIL("the test room ran out of floor at tile [tiles_taken]")
	return spot

/datum/unit_test/voidcrew_drop_pod_tools/Run()
	var/mob/living/carbon/human/consistent/rigger = allocate(/mob/living/carbon/human/consistent)
	var/obj/item/crowbar/pry_bar = allocate(/obj/item/crowbar)

	// --- a shut pod opens, and an open one shuts, without the crowbar going in ---
	var/obj/structure/closet/supplypod/drop_pod/pod = allocate(/obj/structure/closet/supplypod/drop_pod)
	TEST_ASSERT(!pod.opened, "the drop pod spawned already open")

	if(!vc_click_with_item(rigger, pod, pry_bar))
		return

	TEST_ASSERT(pod.opened, "a crowbar on a shut drop pod did not open it")
	TEST_ASSERT_EQUAL(pry_bar.loc, rigger, "the crowbar left the rigger's hands while opening the pod (it is now on [pry_bar.loc || "nothing"])")

	if(!vc_click_with_item(rigger, pod, pry_bar))
		return

	TEST_ASSERT(!pod.opened, "a crowbar on an OPEN drop pod did not shut it")
	TEST_ASSERT_EQUAL(pry_bar.loc, rigger, "the drop pod ate the crowbar. The closet parent's item_interaction drops any held item into an opened closet and returns SUCCESS, which is why the pod \
		has to claim its own tools ahead of the parent rather than in attackby.")

	// --- a rider sealed inside can still pry the hatch, in either combat mode ---
	for(var/combat in list(FALSE, TRUE))
		var/obj/structure/closet/supplypod/drop_pod/coffin = allocate(/obj/structure/closet/supplypod/drop_pod, bench_tile())
		var/mob/living/carbon/human/consistent/passenger = allocate(/mob/living/carbon/human/consistent, get_turf(coffin))
		var/obj/item/crowbar/inside_bar = allocate(/obj/item/crowbar, get_turf(coffin))
		passenger.forceMove(coffin)
		TEST_ASSERT_EQUAL(passenger.loc, coffin, "the test passenger is not inside the pod, so the sealed-rider guard is not being exercised")
		TEST_ASSERT(!coffin.opened, "the pod the passenger is sealed in is already open")

		if(!vc_click_with_item(passenger, coffin, inside_bar, combat_mode = combat))
			return

		TEST_ASSERT(coffin.opened, "a rider sealed inside a drop pod could not crowbar the hatch open with combat mode [combat ? "ON" : "off"]. Every migrated closet tool hook opens with \
			`if(user in contents) return ITEM_INTERACT_BLOCKING`, so the pod has to answer first - a one-shot pod you cannot open from inside is a coffin.")

	// --- wrench flips the bolts ---
	rigger.drop_all_held_items() // the crowbar is still in the active hand, which has to be free
	var/obj/item/wrench/spanner = allocate(/obj/item/wrench)
	var/was_anchored = pod.anchored

	if(!vc_click_with_item(rigger, pod, spanner))
		return

	TEST_ASSERT_EQUAL(pod.anchored, !was_anchored, "a wrench on the drop pod did not flip its bolts (still [pod.anchored ? "anchored" : "unanchored"])")

	// --- multitool carrying a quantum pad links it ---
	rigger.drop_all_held_items()
	var/obj/machinery/quantumpad/pad = allocate(/obj/machinery/quantumpad, bench_tile())
	var/obj/item/multitool/linker = allocate(/obj/item/multitool)
	linker.set_buffer(pad)
	TEST_ASSERT_EQUAL(linker.buffer, pad, "the multitool did not take the quantum pad into its buffer, so the link below cannot be tested")
	TEST_ASSERT_NULL(pod.linked_pad, "the drop pod spawned already linked to a quantum pad")

	if(!vc_click_with_item(rigger, pod, linker))
		return

	TEST_ASSERT_EQUAL(pod.linked_pad, pad, "a multitool holding a quantum pad in its buffer did not link the drop pod to it")

// ===========================================================================
// 4. Hull defense turret — the ID swipe (voidcrew/machinery/ship_defense_turret.dm)
// ===========================================================================

/**
 * Swiping an ID on a hull defense turret refuses, and says so, in every click shape.
 *
 * The stock portable turret's ID branch flips `locked`, which gates the stock TGUI panel.
 * The fork's turret has no panel - `ui_interact()` returns nothing and `allowed_operator()`
 * decides who may work the controls - so the flip changes nothing while printing
 * "Controls are now locked.", which is the worst possible answer: a crew reads it as having
 * secured the gun. Worse, `req_access` is null on this turret, so `allowed()` is
 * unconditionally TRUE and *every* swipe printed the lie.
 *
 * The fork's refusal used to be an `attackby()` override. Upstream split the ID branch out
 * into `/obj/machinery/porta_turret/item_interaction` (portable_turret.dm:381-391), which
 * runs at step 3 - ahead of `attackby` - so the parent claimed the swipe and the refusal
 * became unreachable. The check moved into the same hook.
 *
 * Driven left click, right click and combat mode, because `item_interaction` is gated on
 * none of them: `item_interaction_secondary` defaults to `item_interaction`, and only
 * `tool_act` cares about combat mode. An ID card has no `tool_behaviour`, so step 1 is a
 * no-op on every one of those paths and this proc is the first thing the swipe meets.
 *
 * The last case is the residual repair: the refusal now covers a **BROKEN** turret too,
 * because the parent's lock-flip is just as much of a lie on a wrecked gun. That change had
 * to not cost the crowbar salvage that a broken turret exists for, so the salvage is driven
 * here as well - it lives in `crowbar_act`, at step 1, which runs *ahead* of this proc, and
 * a crowbar does not answer `GetID()`.
 */
/datum/unit_test/voidcrew_turret_id_swipe

/**
 * Swipes `card` on `turret` in one click shape and asserts the turret neither locked nor took
 * damage. Returns TRUE when the click was delivered and both assertions held.
 *
 * `what` names the shape in the failure text, because "the turret locked" is not a useful
 * report when three shapes are being driven and only one of them is broken.
 */
/datum/unit_test/voidcrew_turret_id_swipe/proc/assert_swipe_refused(mob/living/user, obj/machinery/porta_turret/ship_defense/turret, obj/item/card, what, right_click = FALSE, combat_mode = FALSE)
	var/integrity_before = turret.get_integrity()
	var/delivered = right_click \
		? vc_right_click_with_item(user, turret, card, combat_mode) \
		: vc_click_with_item(user, turret, card, combat_mode = combat_mode)
	if(!delivered)
		return FALSE

	if(turret.locked)
		TEST_FAIL("[what] with an ID card on a hull defense turret flipped `locked`. Upstream's /obj/machinery/porta_turret/item_interaction claims the swipe at step 3, ahead of attackby, and \
			prints \"Controls are now locked.\" while changing nothing a player can see - the fork's refusal has to sit in the same hook.")
		return FALSE
	if(turret.get_integrity() != integrity_before)
		TEST_FAIL("[what] with an ID card damaged the turret ([integrity_before] -> [turret.get_integrity()]) - the refusal returned a falsy value and the card went on to bash the gun")
		return FALSE
	return TRUE

/datum/unit_test/voidcrew_turret_id_swipe/Run()
	var/mob/living/carbon/human/consistent/boarder = allocate(/mob/living/carbon/human/consistent)
	var/obj/machinery/porta_turret/ship_defense/turret = allocate(/obj/machinery/porta_turret/ship_defense)
	var/obj/item/card/id/swipe_card = allocate(/obj/item/card/id)

	TEST_ASSERT(!turret.locked, "the hull defense turret spawned with locked controls - the fork sets locked = FALSE, and a swipe that flipped it would be indistinguishable from one that did not")
	TEST_ASSERT_NULL(turret.req_access, "the hull defense turret has req_access set, so allowed() is no longer unconditionally TRUE and this test is measuring a different refusal than the shipped one")

	// Left click, right click, and a combat-mode left click: three routes into one hook.
	// Written out rather than looped so each call is the real fixture for that click shape.
	if(!assert_swipe_refused(boarder, turret, swipe_card, "a left click"))
		return
	if(!assert_swipe_refused(boarder, turret, swipe_card, "a right click", right_click = TRUE))
		return
	if(!assert_swipe_refused(boarder, turret, swipe_card, "a combat-mode left click", combat_mode = TRUE))
		return

	// --- the residual: a wrecked turret refuses the swipe too, but still salvages ---
	turret.atom_break()
	TEST_ASSERT(turret.machine_stat & BROKEN, "atom_break() did not break the turret, so the BROKEN half of the refusal is untestable")

	if(!vc_click_with_item(boarder, turret, swipe_card))
		return

	TEST_ASSERT(!turret.locked, "an ID swipe on a BROKEN hull defense turret flipped `locked`. The old guard was `if(!(machine_stat & BROKEN) && GetID())`, which let a wrecked gun fall through to the \
		parent's lock-flip - the same lie, on a turret that is not even shooting.")

	boarder.drop_all_held_items() // the ID card is still in the active hand
	var/obj/item/crowbar/pry_bar = allocate(/obj/item/crowbar)
	if(!vc_click_with_item(boarder, turret, pry_bar))
		return

	TEST_ASSERT(QDELETED(turret), "a crowbar on a BROKEN hull defense turret did not salvage it. crowbar_act() sits in tool_act at step 1, ahead of item_interaction, and a crowbar does not answer \
		GetID() - so widening the ID refusal to cover BROKEN turrets must not have cost the salvage.")

	// --- and the bolts still come loose, once the gun is switched off ---
	var/obj/machinery/porta_turret/ship_defense/second_turret = allocate(/obj/machinery/porta_turret/ship_defense, run_loc_floor_top_right)
	second_turret.toggle_on(FALSE)
	TEST_ASSERT(!second_turret.on, "the second turret would not switch off, and /obj/machinery/porta_turret/wrench_act refuses to touch a live turret")
	TEST_ASSERT(second_turret.anchored, "the second turret is not bolted down, so the unbolt below is untestable")

	boarder.drop_all_held_items()
	var/obj/item/wrench/spanner = allocate(/obj/item/wrench)
	if(!vc_click_with_item(boarder, second_turret, spanner))
		return

	TEST_ASSERT(!second_turret.anchored, "a wrench on a switched-off hull defense turret did not unbolt it")

// ===========================================================================
// 5. Marine vendor voucher (voidcrew/modules/vending/security.dm)
// ===========================================================================

/**
 * A weapon voucher reaches the vendor's redemption instead of being refused as cargo.
 *
 * Upstream moved the vendor's insert/restock handling out of `/obj/machinery/vending/attackby`
 * and into `/obj/machinery/vending/item_interaction` (vendor/interaction.dm:98-140). Its last
 * branch fires for anyone who passes `compartmentLoadAccessCheck()` with combat mode off -
 * which is exactly the marine holding the voucher - and returns
 * `loadingAttempt(...) ? SUCCESS : FAILURE`. A voucher is in no product list, so
 * `canLoadItem()` refuses it and the answer is ITEM_INTERACT_FAILURE, which *is*
 * ITEM_INTERACT_BLOCKING: the click ends there and the fork's `attackby` never ran. The
 * redemption menu could not open.
 *
 * Latent in the tree today - nothing spawns `/obj/item/gun_voucher`, the vendors are mapped
 * and the vouchers are not - and pinned anyway, because "latent" is a property of the loot
 * tables, not of the code.
 *
 * Two setup notes, both deliberate:
 *  - `req_access` is cleared on the allocated vendor so `compartmentLoadAccessCheck()` passes.
 *    That is the state that reproduces the bug: the marine who owns the voucher has the
 *    access. A test human with no ID would fail the check, upstream's branch would never
 *    fire, and the test would pass on a broken tree.
 *  - the handcuffs' stock is decremented by one before the restock click, because
 *    `loadingAttempt()` refuses anything already at `max_amount` and the vendor spawns full.
 */
/datum/unit_test/voidcrew_marine_voucher

/datum/unit_test/voidcrew_marine_voucher/Run()
	var/mob/living/carbon/human/consistent/marine = allocate(/mob/living/carbon/human/consistent)
	var/obj/machinery/vending/security/marine/vc_voucher_probe/vendor = allocate(/obj/machinery/vending/security/marine/vc_voucher_probe)
	vendor.req_access = null

	var/obj/item/gun_voucher/voucher = allocate(/obj/item/gun_voucher)
	TEST_ASSERT_NULL(vendor.redeemed_voucher, "the probe vendor started with a redeemed voucher recorded")

	if(!vc_click_with_item(marine, vendor, voucher))
		return

	TEST_ASSERT_EQUAL(vendor.redeemed_voucher, voucher, "clicking a marine vendor with a weapon voucher did not reach RedeemVoucher(). Upstream's vending item_interaction claims the click at step 3 \
		and answers a non-product with ITEM_INTERACT_FAILURE, which is BLOCKING - so the voucher check has to sit in the same hook, ahead of the parent.")

	// --- and an actual product still loads through the parent ---
	// The probe records the voucher rather than consuming it (the real RedeemVoucher qdel()s it
	// after the radial menu), so both the hand and the record are cleared by hand here.
	marine.drop_all_held_items()
	vendor.redeemed_voucher = null
	var/obj/item/restraints/handcuffs/cuffs = allocate(/obj/item/restraints/handcuffs)
	var/datum/data/vending_product/cuff_record
	for(var/datum/data/vending_product/record as anything in vendor.product_records)
		if(record.product_path == /obj/item/restraints/handcuffs)
			cuff_record = record
			break

	TEST_ASSERT_NOTNULL(cuff_record, "the marine vendor has no handcuffs product record, so the restock half of this test cannot run")
	cuff_record.amount--
	var/stock_before = cuff_record.amount

	if(!vc_click_with_item(marine, vendor, cuffs))
		return

	TEST_ASSERT_EQUAL(cuff_record.amount, stock_before + 1, "loading handcuffs into the marine vendor did not restock it ([stock_before] before, [cuff_record.amount] after) - the voucher branch is \
		swallowing clicks that belong to the parent")
	TEST_ASSERT_EQUAL(cuffs.loc, vendor, "the restocked handcuffs are on [cuffs.loc || "nothing"] rather than inside the vendor")
	TEST_ASSERT_NULL(vendor.redeemed_voucher, "loading an ordinary product into the vendor ran the voucher redemption")

// ===========================================================================
// 6. RCD-built camera (voidcrew/modules/shuttle/construction/construction_console.dm)
// ===========================================================================

/**
 * An RCD-built camera faces its wall, is mounted on it, and is switched on.
 *
 * `/obj/machinery/camera/Initialize()` used to be `(mapload, ndir, building)`: `building`
 * made the camera `setDir(ndir)` and hang itself on a wall from inside Initialize. Upstream
 * cut it down to `(mapload)` and moved both jobs to the caller, the way
 * `/obj/item/wallframe/interact_with_atom` does it - `new` -> `setDir` -> `find_and_mount_on_atom`.
 * The fork's ship RCD still called `new(target, wall_dir, TRUE)`, and the extra arguments did
 * not vanish quietly: **`wall_dir` bound to `mapload`**. Three things fell out of that:
 *
 *  - the camera's dir was never set, so `get_turfs_to_mount_on()` (which is
 *    `list(get_step(src, dir))`) looked at the wrong tile and the mount failed;
 *  - the failed mount set `MOUNT_ON_LATE_INITIALIZE`, and `LateInitialize` never comes for an
 *    atom built mid-round, so the camera stayed permanently unmounted;
 *  - a truthy `mapload` also opened the `prob(3)` self-toggle in Initialize, so roughly one
 *    RCD camera in thirty spawned switched OFF - on a ship, where every z is a station level.
 *
 * **On the 3% roll specifically.** It cannot fire in this test room: the unit-test z-level is
 * minted with `ZTRAITS_AWAY` (map_template.dm:113), so `is_station_level(z)` is false and the
 * branch is unreachable here whatever `mapload` says. What the loop below *can* prove is the
 * gate in front of it: `MOUNT_ON_LATE_INITIALIZE` is only ever set from inside Initialize's
 * `if(mapload)` block, so a camera that comes back without that flag is a camera Initialize
 * did not believe was map-loaded - which is exactly the condition the `prob(3)` roll needs.
 * The loop is therefore 20 rather than the 100 a real probability sample would want; with
 * `mapload` false the outcome does not vary, and 20 is enough to catch a state that leaks
 * between builds.
 *
 * **Not asserted, and why.** "Still mounted after a shuttle move" is not drivable here.
 * `find_and_mount_on_atom()` only registers COMSIG_ATOM_AFTER_SHUTTLE_MOVE
 * `if(is_area_shuttle(location))` (atom_mounted.dm:197-198), and the test room is
 * `/area/misc/testroom`, so the registration this fix restored does not even happen in this
 * environment. Proving it needs an assembled hull - `vc_create_test_ship()` territory, and a
 * different test's cost profile.
 */
/datum/unit_test/voidcrew_rcd_camera_mount

/datum/unit_test/voidcrew_rcd_camera_mount/Run()
	var/mob/living/carbon/human/consistent/builder = allocate(/mob/living/carbon/human/consistent)
	var/obj/item/construction/rcd/internal/ship/vc_camera_probe/rcd = allocate(/obj/item/construction/rcd/internal/ship/vc_camera_probe)

	var/turf/mount_site = run_loc_floor_bottom_left
	var/turf/wall_site = get_step(mount_site, NORTH)
	TEST_ASSERT_NOTNULL(wall_site, "there is no tile north of the test room's bottom-left floor to build a wall on")

	// The camera mounts on a closed turf, and the test room is all open floor, so one gets
	// built and put back exactly as it was found.
	var/wall_was = wall_site.type
	var/list/wall_baseturfs = wall_site.baseturfs
	wall_site.ChangeTurf(/turf/closed/wall)
	TEST_ASSERT(isclosedturf(wall_site), "the tile north of the build site did not become a closed turf, so is_mountable_turf() will refuse it and no camera can mount")

	var/built_off = 0
	var/checked = 0
	for(var/attempt in 1 to 20)
		var/obj/machinery/camera/built = rcd.build_camera(mount_site, NORTH, builder)
		if(isnull(built))
			TEST_FAIL("build_camera() returned null on attempt [attempt] - the probe RCD's material and delay stubs did not take")
			break

		checked++
		TEST_ASSERT_EQUAL(built.dir, NORTH, "an RCD-built camera faces [dir2text(built.dir)] instead of NORTH. The old call passed the wall direction into the `mapload` slot, so setDir() never ran and \
			get_turfs_to_mount_on() (list(get_step(src, dir))) looked at the wrong tile.")
		TEST_ASSERT_NOTNULL(built.GetComponent(/datum/component/atom_mounted), "an RCD-built camera never mounted on its wall - it has no /datum/component/atom_mounted")
		TEST_ASSERT(!(built.obj_flags & MOUNT_ON_LATE_INITIALIZE), "an RCD-built camera came back flagged MOUNT_ON_LATE_INITIALIZE. That flag is only ever set from inside Initialize's if(mapload) \
			branch, so it is proof the camera believed it was map-loaded - the same truthiness that feeds the prob(3) self-toggle a few lines above it.")
		TEST_ASSERT(built.camera_enabled, "an RCD-built camera spawned switched off")
		TEST_ASSERT(built in SScameras.cameras, "an RCD-built camera is not registered with SScameras")

		if(!built.camera_enabled)
			built_off++
		qdel(built)

	TEST_ASSERT_EQUAL(checked, 20, "only [checked] of 20 camera builds completed")
	TEST_ASSERT_EQUAL(built_off, 0, "[built_off] of 20 RCD-built cameras spawned switched off")

	// Put the room back the way it was found - the unit test harness only clears turf
	// CONTENTS between tests, never turf types.
	wall_site.ChangeTurf(wall_was, wall_baseturfs)
	TEST_ASSERT(!isclosedturf(wall_site), "the wall this test built was not cleaned up, and the next test to use the bottom-left corner will run into it")

// ===========================================================================
// 7. Multitool buffers release their machine (residual: raw `tool.buffer = src`)
// ===========================================================================

/**
 * Every machine that buffers itself to a multitool lets go when it is deleted.
 *
 * `/obj/item/multitool/proc/set_buffer()` is the API, and the reason it exists is one line:
 * `RegisterSignal(buffer, COMSIG_QDELETING, PROC_REF(remove_buffer))` (multitool.dm:137).
 * Nine fork machines assigned `tool.buffer = src` raw instead, which skips that registration
 * entirely - so a multitool that had touched one of them held a hard reference to it for the
 * rest of the round. The machine could be blown up, deconstructed or taken apart with its
 * ship and it would still never be collected, which is exactly the shape the hard-delete
 * initiative has been chasing.
 *
 * Driven as a table so the ninth machine is not the one nobody covered. The count is
 * asserted: a tenth site added later fails here rather than shipping untested.
 *
 * Two hooks are represented on purpose. The bank machine answers in `multitool_act()` (step 1,
 * so combat mode off is required, which is the fixture default); the other eight answer in
 * `attackby()` at the end of the chain, reached because none of them defines a
 * `multitool_act` for `tool_act` to stop at. Both routes have to end with the same registration.
 */
/datum/unit_test/voidcrew_multitool_buffer_release

/datum/unit_test/voidcrew_multitool_buffer_release/Run()
	var/mob/living/carbon/human/consistent/engineer = allocate(/mob/living/carbon/human/consistent)
	var/obj/item/multitool/tool = allocate(/obj/item/multitool)

	var/list/buffering_machines = list(
		/obj/machinery/computer/bank_machine,
		/obj/machinery/shuttle_scrambler/ship_siphon,
		/obj/machinery/ship_combat/pod_launcher,
		/obj/machinery/ship_combat/cloak_device,
		/obj/machinery/ship_combat/ew_suite,
		/obj/machinery/ship_combat/interdictor,
		/obj/machinery/ship_combat/laser_turret,
		/obj/machinery/ship_combat/missile_launcher,
		/obj/machinery/ship_combat/shield_generator,
	)
	TEST_ASSERT_EQUAL(length(buffering_machines), 9, "the multitool-buffer table no longer lists nine machines - a tenth site was added without covering it, or one was removed")

	var/turf/origin = run_loc_floor_bottom_left
	var/placed = 0
	for(var/machine_type in buffering_machines)
		var/turf/spot = locate(origin.x + (placed % 5), origin.y + round(placed / 5), origin.z)
		placed++
		TEST_ASSERT_NOTNULL(spot, "the test room ran out of floor placing [machine_type]")

		var/obj/machinery/machine = allocate(machine_type, spot)
		tool.set_buffer(null)

		if(!vc_click_with_item(engineer, machine, tool))
			return

		TEST_ASSERT_EQUAL(tool.buffer, machine, "clicking [machine_type] with a multitool did not put it in the buffer (the buffer holds [tool.buffer || "nothing"])")

		qdel(machine)
		TEST_ASSERT_NULL(tool.buffer, "the multitool still holds [machine_type] after it was deleted. `tool.buffer = src` skips set_buffer()'s COMSIG_QDELETING registration, so the buffer keeps a \
			hard reference to a destroyed machine for the rest of the round and it can never be garbage collected.")

// ===========================================================================
// 8. The crew transfer vote (voidcrew/datums/votes/transfer_vote.dm)
// ===========================================================================

/**
 * The crew transfer vote can be started, and admins can toggle it without a runtime.
 *
 * Both halves of this datum were written against an older SSvote and both were dead:
 *
 *  - `can_be_initiated()` takes `(forced)` and must return `VOTE_AVAILABLE` or a *string*
 *    explaining the refusal, which SSvote shows in the vote panel. The fork's override took a
 *    leading `(mob/by_who)`, so `forced` always bound to the mob and the answer was TRUE or
 *    FALSE - neither of which is `VOTE_AVAILABLE`. `initiate_vote()` compares against that
 *    constant exactly (vote.dm:210), so the transfer vote **could never be started at all**.
 *  - `toggle_votable()` takes no arguments; SSvote already gates the "toggleVote" ui_act on
 *    `check_rights_for(R_ADMIN)`. The fork's `(mob/toggler)` override received null and hit
 *    its own `CRASH()` on every admin toggle.
 *
 * The vote really is started here, through `SSvote.initiate_vote()` with `forced = TRUE`, and
 * then torn down immediately with `SSvote.reset()`. That teardown is not tidiness: a transfer
 * vote left running counts down in `SSvote.fire()` and, if TRANSFER wins,
 * `finalize_vote()` calls `SSovermap.request_jump()`. Leaving it armed would let a unit test
 * end the round.
 */
/datum/unit_test/voidcrew_transfer_vote_contract

/datum/unit_test/voidcrew_transfer_vote_contract/Run()
	var/datum/vote/transfer_vote/transfer = SSvote.possible_votes[/datum/vote/transfer_vote::name]
	TEST_ASSERT_NOTNULL(transfer, "SSvote has no \"[/datum/vote/transfer_vote::name]\" entry in possible_votes - is_accessible_vote() rejected the transfer vote, and nothing below can run")
	TEST_ASSERT(istype(transfer), "SSvote's transfer entry is a [transfer.type], not a /datum/vote/transfer_vote")

	var/config_was = CONFIG_GET(flag/allow_vote_transfer)
	var/vote_time_was = SSvote.last_vote_time
	var/had_vote_running = !isnull(SSvote.current_vote)
	TEST_ASSERT(!had_vote_running, "a vote was already running when this test started ([SSvote.current_vote.type]), so initiating one here would trample it")

	// --- the admin toggle: zero arguments, flips the config, does not CRASH ---
	var/snapshot = vc_runtime_snapshot()
	transfer.toggle_votable()
	if(!vc_assert_no_new_runtimes(snapshot, "the transfer vote's toggle_votable()"))
		return
	TEST_ASSERT_EQUAL(CONFIG_GET(flag/allow_vote_transfer), !config_was, "toggle_votable() did not flip allow_vote_transfer. Upstream calls it with no arguments; the old (mob/toggler) override \
		received null and CRASHed before it reached the CONFIG_SET.")

	transfer.toggle_votable()
	TEST_ASSERT_EQUAL(CONFIG_GET(flag/allow_vote_transfer), config_was, "toggle_votable() is not symmetric - the config did not come back to where it started")

	// --- the refusal string, which is what the vote panel displays ---
	CONFIG_SET(flag/allow_vote_transfer, FALSE)
	var/refusal = transfer.can_be_initiated(forced = FALSE)
	TEST_ASSERT_NOTEQUAL(refusal, VOTE_AVAILABLE, "the transfer vote says it is available while allow_vote_transfer is off")
	TEST_ASSERT(istext(refusal), "the transfer vote refused with [isnull(refusal) ? "null" : refusal] instead of a string. SSvote shows this value to the admin as the reason, and TRUE/FALSE renders \
		as nothing useful - this is the half that made the vote unstartable, because initiate_vote() tests the answer against VOTE_AVAILABLE exactly.")

	TEST_ASSERT_EQUAL(transfer.can_be_initiated(forced = TRUE), VOTE_AVAILABLE, "a forced transfer vote is still refused ([transfer.can_be_initiated(forced = TRUE)]) even though `forced` is supposed \
		to bypass the config check")

	// --- and it actually starts ---
	snapshot = vc_runtime_snapshot()
	var/started = SSvote.initiate_vote(/datum/vote/transfer_vote, "unit test", null, forced = TRUE)
	TEST_ASSERT(started, "SSvote.initiate_vote() refused to start a forced transfer vote. can_be_initiated() has to answer with VOTE_AVAILABLE for the vote to exist at all (vote.dm:210).")
	TEST_ASSERT_EQUAL(SSvote.current_vote, transfer, "a forced transfer vote started but SSvote.current_vote is [SSvote.current_vote || "null"]")
	if(!vc_assert_no_new_runtimes(snapshot, "starting a forced crew transfer vote"))
		SSvote.reset()
		SSvote.last_vote_time = vote_time_was
		CONFIG_SET(flag/allow_vote_transfer, config_was)
		return

	// Tear it down before SSvote can count it out and act on the result.
	SSvote.reset()
	SSvote.last_vote_time = vote_time_was
	CONFIG_SET(flag/allow_vote_transfer, config_was)

	TEST_ASSERT_NULL(SSvote.current_vote, "the test's transfer vote survived SSvote.reset() and is still running")
	TEST_ASSERT_EQUAL(CONFIG_GET(flag/allow_vote_transfer), config_was, "this test left allow_vote_transfer flipped")

// ===========================================================================
// 9. Ship combat console targeting reticle (residual: screen hud_owner slot)
// ===========================================================================

/**
 * The weapons console's targeting reticle does not adopt the console as its HUD.
 *
 * Slot 2 of `/atom/movable/screen/Initialize` is `datum/hud/hud_owner`, and a non-null value
 * there goes straight into `set_new_hud()`. The reticle declared that slot as the owning
 * console and `console_parent.dm` built it with `new(null, src)` - so a screen object's `hud`
 * pointed at an `/obj/machinery`. Two things then read a machine as a hud: `get_mob()`
 * (`hud?.mymob`) and `/atom/movable/screen/Destroy` (`hud.screen_objects -= hud_key`), and
 * neither var exists on a machine. The console `QDEL_NULL`s its reticle from `Destroy()`, so
 * every weapons console that was ever taken apart runtimed on the way out.
 *
 * `hud` is `VAR_PRIVATE` (screen_objects.dm:22) and cannot be read from a test, so this
 * asserts on the two procs that read it instead - which is the better assertion anyway, since
 * those are what actually broke. Both are wrapped in runtime windows: on a poisoned reticle
 * the failure is a runtime, not a wrong return value.
 */
/datum/unit_test/voidcrew_combat_console_reticle

/datum/unit_test/voidcrew_combat_console_reticle/Run()
	var/obj/machinery/computer/camera_advanced/ship_combat/console = allocate(/obj/machinery/computer/camera_advanced/ship_combat)
	var/atom/movable/screen/ship_combat/targeting_reticle/reticle = console.reticle

	TEST_ASSERT_NOTNULL(reticle, "the weapons console built no targeting reticle")

	// get_mob() is `hud?.mymob`. With a machine in the hud slot that is a read of an
	// undefined var on an /obj/machinery, which is a runtime, not a null.
	var/snapshot = vc_runtime_snapshot()
	var/mob/viewer = reticle.get_mob()
	if(!vc_assert_no_new_runtimes(snapshot, "reading the targeting reticle's get_mob()"))
		return
	TEST_ASSERT_NULL(viewer, "the targeting reticle reports a viewing mob ([viewer]) despite belonging to no hud - the console's `reticle` var is its only owner, and the reticle is added straight \
		to user.client.screen rather than to any hud's screen_objects")

	// The console QDEL_NULLs the reticle from its own Destroy(), which is where a machine in
	// the hud slot blew up: /atom/movable/screen/Destroy does `hud.screen_objects -= hud_key`.
	snapshot = vc_runtime_snapshot()
	qdel(console)
	if(!vc_assert_no_new_runtimes(snapshot, "deleting a ship combat console with its targeting reticle attached"))
		return

	TEST_ASSERT(QDELETED(reticle), "the weapons console was deleted but its targeting reticle survived - console_parent.dm's QDEL_NULL(reticle) did not run, and the screen object is orphaned")
