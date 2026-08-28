/**
 * # Mission / contract flows
 *
 * The fork's main content loop, driven end to end: a contract is generated,
 * accepted through the board console the way a player accepts one, its
 * objectives advance in order, and turn-in pays what the type advertised.
 *
 * ## The breakage class this file exists for
 *
 * **Mission tests self-silenced on CI worlds.** `voidcrew_missions.dm` shipped
 * two tests that opened with
 *
 *     if(length(live_ruins) < 2)
 *         return // no overmap worth testing against in this world
 *
 * A bare `return` out of `Run()` is a **PASS**. Both tests therefore reported
 * green on any world whose ruin pool came up short while asserting nothing at
 * all - strictly worse than having no test, because the coverage matrix counted
 * them. Those two are repaired in place (they now top the pool up from
 * `vc_mint_test_ruin_signals()` below and fail loudly if even that cannot
 * deliver), and nothing in this file is allowed to repeat the shape: every
 * precondition here is an assertion, never a quiet exit.
 *
 * ## What the test world actually has
 *
 * The `voidcrew_helpers.dm` header claims the test world has no ship, no planet
 * and no live SSovermap. All three are false, and the 2026-08-27 CI run proves
 * it: `SSovermap.Initialize()` runs `create_map()` (which paints the overmap
 * block onto the centcom z, independent of whichever station map booted),
 * `setup_planets()`, `setup_space_ruins()` and `setup_trader_outposts()` on
 * every world, and that run's `data/logs/ci/debug.log` holds 23 "Spawned space
 * ruin" lines, 10 "Spawned dynamic planet" lines and three trader outposts. So
 * contracts that need an overmap target *can* generate here, and a target that
 * fails to resolve is a real failure rather than an absent world.
 *
 * What the test world does NOT have is a *loaded* site interior: ruins and
 * planets sit unloaded until a ship docks. Every `field` objective
 * (`/datum/mission_objective/field` and its eleven subtypes) waits on the
 * interior-loaded signal before it places anything, so the contract families
 * built on them - recovery, rescue, big game, live capture, poacher bust,
 * containment, prospect stake - cannot be driven to completion without a real
 * `spawn_dynamic_encounter()` map load per contract. See "Coverage boundaries"
 * at the bottom of this file for what that leaves uncovered and why the
 * end-to-end picks are the ones they are.
 */

// =========================================================================
// RUIN-SIGNAL FIXTURE
// =========================================================================

/**
 * Mints `count` bare space-ruin signals on free overmap tiles and hands them back.
 *
 * The recovery-family target picker (`/datum/mission_target/space_ruin/resolve()`)
 * asks four things of a candidate and nothing else: not QDELETED, not
 * `mission_locked`, not `mission_exclusive`, and standing on a
 * `/turf/open/overmap`. It never touches the interior. So a *signal* - an
 * `/obj/structure/overmap/space_ruin` with no template and no map zone - is a
 * complete, legal target as far as every mission-target code path is concerned,
 * and it costs one `new` instead of a map load.
 *
 * That is the whole reason this exists rather than `spawn_dynamic_encounter()`:
 * the two repaired tests in `voidcrew_missions.dm` need a *pool of candidates*
 * for the picker to choose between, not a pool of interiors. `Initialize()` adds
 * the signal to `GLOB.space_ruin_signals` itself, which is the list the picker
 * walks, so a minted signal is indistinguishable from a seeded one at that layer.
 *
 * Minted signals are `sensor_detectable` like any other, so they are briefly
 * visible to live ship sensors. Keep the window short and always release.
 *
 * Returns the list (possibly shorter than asked for, and possibly empty, if the
 * overmap had no free tile); the caller asserts on the length it needs. ALWAYS
 * pair with vc_release_test_ruin_signals() on every exit path.
 */
/datum/unit_test/proc/vc_mint_test_ruin_signals(count = 1)
	var/list/obj/structure/overmap/space_ruin/minted = list()
	if(count <= 0)
		return minted
	if(isnull(SSovermap.overmap_centre))
		TEST_FAIL("vc_mint_test_ruin_signals() found no overmap: SSovermap.overmap_centre is null, so SSovermap.create_map() never painted the overmap block. \
			Every mission target that points at a site is untestable on this world.")
		return minted
	for(var/_ in 1 to count)
		// /obj/structure/overmap so the tile is one no other overmap object stands on.
		var/turf/free_tile = SSovermap.get_unused_overmap_square()
		if(!istype(free_tile, /turf/open/overmap))
			break
		var/obj/structure/overmap/space_ruin/signal = new(free_tile)
		signal.name = "unit test signal"
		minted += signal
	return minted

/// Deletes signals minted by vc_mint_test_ruin_signals() and verifies they left
/// GLOB.space_ruin_signals behind them. Returns TRUE when the teardown was clean.
/datum/unit_test/proc/vc_release_test_ruin_signals(list/obj/structure/overmap/space_ruin/minted)
	. = TRUE
	for(var/obj/structure/overmap/space_ruin/signal as anything in minted)
		if(QDELETED(signal))
			continue
		// Never hand a signal back to the round still flagged: a leaked exclusive
		// lock takes that tile out of every contract's candidate set for the round.
		signal.mission_exclusive = FALSE
		signal.mission_locked = FALSE
		signal.mission_claims = 0
		// Cleared so /obj/structure/overmap/space_ruin/Destroy() takes the quiet path
		// rather than logging a leaked-slot warning about a slot we never claimed.
		signal.footprint = null
		signal.mapzone = null
		qdel(signal)
		if(!QDELETED(signal))
			TEST_FAIL("a minted ruin signal refused deletion and is still standing on the overmap")
			. = FALSE
		if(signal in GLOB.space_ruin_signals)
			TEST_FAIL("a deleted ruin signal survived in GLOB.space_ruin_signals - every later contract's target roll can still pick it")
			. = FALSE
	return .

/**
 * # The ruin-signal fixture answers for itself
 *
 * Breakage class: **mission tests self-silenced on CI worlds.** The repair for
 * that in `voidcrew_missions.dm` leans entirely on the fixture above, so the
 * fixture has to be the thing that is checked rather than the thing that is
 * assumed. If minting ever stops producing picker-visible candidates, the two
 * repaired tests would quietly go back to asserting less than they claim - the
 * exact failure they were repaired for - and this test is what goes red first.
 */
/datum/unit_test/voidcrew_mission_ruin_signal_fixture

/datum/unit_test/voidcrew_mission_ruin_signal_fixture/Run()
	var/starting_pool = length(GLOB.space_ruin_signals)
	var/list/obj/structure/overmap/space_ruin/minted = vc_mint_test_ruin_signals(3)

	if(length(minted) != 3)
		TEST_FAIL("vc_mint_test_ruin_signals(3) returned [length(minted)] signal\s. \
			The overmap has no free tiles to mint onto, so the repaired ruin-picker tests cannot top their pool up and will fail loudly rather than pass silently.")
		vc_release_test_ruin_signals(minted)
		return

	if(length(GLOB.space_ruin_signals) != starting_pool + 3)
		TEST_FAIL("minting 3 signals moved GLOB.space_ruin_signals from [starting_pool] to [length(GLOB.space_ruin_signals)]. \
			/obj/structure/overmap/space_ruin/Initialize() is what registers a signal there, and that list is the only thing the target picker walks.")

	for(var/obj/structure/overmap/space_ruin/signal as anything in minted)
		if(!istype(get_turf(signal), /turf/open/overmap))
			TEST_FAIL("a minted signal stands on [get_turf(signal) || "nothing"], not a /turf/open/overmap. resolve() rejects it out of hand and the pool never grows.")
		if(signal.loaded)
			TEST_FAIL("a minted signal came up already loaded - the picker treats a loaded ruin as occupied and refuses it")
		if(signal.mission_claims != 0)
			TEST_FAIL("a minted signal came up with [signal.mission_claims] mission claims, so it is not in the cold-and-unclaimed tier the picker prefers")
		if(signal.mission_exclusive || signal.mission_locked)
			TEST_FAIL("a minted signal came up flagged exclusive/locked, which the picker skips entirely")

	// The point of the fixture, asserted at the layer that consumes it: a target
	// resolved against a world holding only these three lands on one of them.
	var/datum/mission_target/space_ruin/probe = new(null)
	for(var/obj/structure/overmap/space_ruin/other as anything in GLOB.space_ruin_signals)
		if(other in minted)
			continue
		other.mission_locked = TRUE // temporarily hidden from the picker
	var/resolved = probe.resolve()
	for(var/obj/structure/overmap/space_ruin/other as anything in GLOB.space_ruin_signals)
		if(other in minted)
			continue
		other.mission_locked = FALSE
	if(!resolved)
		TEST_FAIL("a space_ruin target resolved against a pool of 3 freshly minted signals and found nothing. The fixture does not actually produce targets.")
	else if(!(probe.ruin in minted))
		TEST_FAIL("the target picked [probe.ruin] which is not one of the minted signals, even though every other ruin was hidden from it")
	qdel(probe)

	vc_release_test_ruin_signals(minted)
	if(length(GLOB.space_ruin_signals) != starting_pool)
		TEST_FAIL("the ruin pool finished at [length(GLOB.space_ruin_signals)], not the [starting_pool] it started at - the fixture leaks signals into the rest of the run")

// =========================================================================
// CONTRACT TABLE CENSUS AND REWARD CONFIGURATION
// =========================================================================

/**
 * # Every contract type's reward configuration, and a census that fails on a new one
 *
 * Breakage class: **mission tests self-silenced on CI worlds** - the census half.
 * A sweep with no census is the same failure in a different costume: it walks
 * whatever it finds, and a type that stops being found (renamed, moved behind an
 * `#ifdef`, or never registered) takes its coverage with it without turning
 * anything red. So the count is pinned. A 27th contract type is a deliberate
 * red: add it to the tally here and confirm it satisfies the rules below.
 *
 * This sweep deliberately does NOT repeat `/datum/unit_test/voidcrew_mission_wiring`,
 * which already covers name/desc, the value band's ordering, duration, weight,
 * mission_limit, voucher_count, quest_lost_policy and the singular
 * `mission_reward`. What it adds is the reward *bundle* - the channel wiring
 * never looks at - and the two economy rules the mission defines write down but
 * nothing enforced.
 */
/datum/unit_test/voidcrew_mission_contract_census

/// Contract types in the tree, excluding /datum/mission/unit_test_capped (the
/// fixture defined by voidcrew_missions.dm). Bump this when you add a type.
#define VC_EXPECTED_MISSION_TYPES 26
/// Types SSmissions.Initialize() collects into its generation pool, i.e. weight > 0.
#define VC_EXPECTED_ROLLABLE_MISSION_TYPES 18

/datum/unit_test/voidcrew_mission_contract_census/Run()
	var/census = 0
	var/rollable_census = 0

	for(var/datum/mission/mission_type as anything in subtypesof(/datum/mission))
		if(mission_type == /datum/mission/unit_test_capped)
			continue
		census++

		var/weight = initial(mission_type.weight)
		if(weight > 0)
			rollable_census++

		// ---- the pay band -------------------------------------------------
		// A rollable type is one SSmissions puts on a real board, and a board
		// offer that pays nothing is a contract the crew loses time on for free.
		// The zero-band types are all shop-authored (outpost_supply and friends,
		// outpost_courier): they carry weight 0 precisely because their entire
		// settlement comes from the posting shop's roll_contract_reward(), which
		// runs at generation time and cannot be seen from initial().
		if(weight > 0 && initial(mission_type.value_min) <= 0)
			TEST_FAIL("[mission_type] has weight [weight], so SSmissions rolls it onto real boards, but its pay floor is [initial(mission_type.value_min)]. \
				A rollable contract must carry its own green-zone band; only shop-authored types (weight 0) may settle at 0 and take their pay from the shop's reward roll.")

		// contract_pay_mult multiplies a difficulty band; a zero or negative one
		// silently zeroes the outpost-board settlement for that archetype.
		var/pay_mult = initial(mission_type.contract_pay_mult)
		if(pay_mult <= 0)
			TEST_FAIL("[mission_type] has contract_pay_mult [pay_mult]. It multiplies the difficulty pay band for outpost-board contracts, so anything at or below zero pays nothing however hard the job is.")

		var/difficulty = initial(mission_type.difficulty)
		// Literals 1/2/3 = MISSION_DIFFICULTY_EASY/MEDIUM/HARD (voidcrew/_DEFINES/missions.dm).
		// Unit-test files compile before voidcrew/_DEFINES, so the fork defines are
		// not available here - the voidcrew_loot.dm convention.
		if(!(difficulty in list(1, 2, 3)))
			TEST_FAIL("[mission_type] has difficulty [difficulty]; the only values are 1/2/3 (EASY/MEDIUM/HARD). get_difficulty_name() answers \"Unknown\" and get_difficulty_color() answers \"label\" for anything else.")

		// ---- research pay -------------------------------------------------
		// "Never hand-write a number here - the bands are what keeps the board in
		// line with the rest of the point economy" (MISSION_RESEARCH_PAY_* doc).
		// Literals 150/300/500 = MISSION_RESEARCH_PAY_LOW/MEDIUM/HIGH.
		var/research_reward = initial(mission_type.research_reward)
		if(research_reward < 0)
			TEST_FAIL("[mission_type] pays [research_reward] research points")
		if(research_reward > 0)
			if(!(research_reward in list(150, 300, 500)))
				TEST_FAIL("[mission_type] hand-writes research_reward [research_reward]. The only compile-time values are the shared bands 150/300/500 \
					(MISSION_RESEARCH_PAY_LOW/MEDIUM/HIGH); apply_zone_scaling() is what moves a band off those numbers at runtime.")
			if(!length(initial(mission_type.research_origin)))
				TEST_FAIL("[mission_type] pays research points with no research_origin, so the dossier it hands over is printed with a blank field of study")

		// ---- the reward bundle --------------------------------------------
		// wiring checks the singular mission_reward. Nothing checks the list.
		var/list/bundle = initial(mission_type.mission_rewards)
		for(var/reward_type in bundle)
			if(!ispath(reward_type, /atom/movable))
				TEST_FAIL("[mission_type].mission_rewards holds [reward_type], which is not a spawnable movable. distribute_rewards() does a bare `new reward_type(reward_turf)` on every entry.")

		// A rare accent naming something the contract never pays is dead UI: the
		// board reads `reward_type in rare_reward_types` over get_reward_types().
		var/list/rare = initial(mission_type.rare_reward_types)
		if(length(rare))
			var/list/paid = list()
			if(initial(mission_type.mission_reward))
				paid += initial(mission_type.mission_reward)
			paid += bundle
			for(var/rare_type in rare)
				if(!(rare_type in paid))
					TEST_FAIL("[mission_type].rare_reward_types names [rare_type], which is not in this type's compile-time reward set. \
						get_ui_data() accents rewards by membership in that list, so this entry can never match anything and the accent never shows.")

		// ---- stack bundling ------------------------------------------------
		// reward_amounts is written at runtime by /datum/outpost_shop/roll_contract_reward()
		// and by nothing else today. A type that starts declaring one at compile
		// time is fine - it just has to obey the same rule distribute_rewards()
		// applies: the entry only does anything for an /obj/item/stack, and a
		// count below 1 spawns a stack of nothing.
		var/list/amounts = initial(mission_type.reward_amounts)
		for(var/amount_type in amounts)
			if(!ispath(amount_type, /obj/item/stack))
				TEST_FAIL("[mission_type].reward_amounts is keyed on [amount_type], which is not an /obj/item/stack. \
					distribute_rewards() only honours the count for a stack path (`stack_amount > 1 && ispath(reward_type, /obj/item/stack)`), so this entry is silently ignored.")
			if(amounts[amount_type] < 1)
				TEST_FAIL("[mission_type].reward_amounts pays [amounts[amount_type]] of [amount_type]")

	TEST_ASSERT_EQUAL(census, VC_EXPECTED_MISSION_TYPES, "the contract table holds [census] types, not the [VC_EXPECTED_MISSION_TYPES] this test is pinned to. \
		A new contract type is not a failure - confirm it satisfies the rules in this sweep and in /datum/unit_test/voidcrew_mission_wiring, then bump VC_EXPECTED_MISSION_TYPES. \
		A type going MISSING is the failure this pin exists for: a sweep with no census silently stops covering whatever stopped being found.")

	// SSmissions.Initialize() collects exactly the weight > 0 types (missions.dm:21-24).
	// Pinned separately because the two numbers drift for opposite reasons: a new
	// board contract raises both, while forgetting a weight on one raises only the
	// first and the type never appears on a board at all.
	TEST_ASSERT_EQUAL(rollable_census, VC_EXPECTED_ROLLABLE_MISSION_TYPES, "[rollable_census] contract types carry weight > 0, not the [VC_EXPECTED_ROLLABLE_MISSION_TYPES] this test is pinned to")
	TEST_ASSERT_EQUAL(length(SSmissions.mission_types), rollable_census, "SSmissions.mission_types holds [length(SSmissions.mission_types)] entries but [rollable_census] contract types carry weight > 0. \
		Initialize() collects the pool once at boot; a type that missed it never rolls onto any board for the whole round.")
	for(var/mission_type in SSmissions.mission_types)
		var/datum/mission/pooled = mission_type
		if(initial(pooled.weight) <= 0)
			TEST_FAIL("SSmissions.mission_types holds [mission_type], whose weight is [initial(pooled.weight)]. pick_weight() over a zero weight is not a selection anybody asked for.")

#undef VC_EXPECTED_MISSION_TYPES
#undef VC_EXPECTED_ROLLABLE_MISSION_TYPES

// =========================================================================
// REWARD BUNDLING AND ZONE SCALING
// =========================================================================

/**
 * # A bundled stack is worth its units, everywhere it is named
 *
 * Breakage class: **a stack reward without a `reward_amounts` entry pays one
 * sheet.** A shop SKU sells "plasteel (10 sheets)" for 750cr; a contract that
 * pays that SKU and forgets the count spawns a stack bare, and a bare stack is
 * the stack's own default of one. That shipped once. The rule now lives in
 * three places that must agree - `get_reward_summary()` (the ship notification),
 * `get_ui_data()` (the board card) and `distribute_rewards()` (the actual
 * spawn) - and a fix to one of them that misses the others is the obvious way
 * to half-fix it again.
 *
 * This test owns the two text halves. The spawn half is asserted for real
 * against a mission pad in /datum/unit_test/voidcrew_mission_contract_lifecycle,
 * because distribute_rewards() returns early without a servant ship.
 *
 * The zone-scaling table is here for the same reason: it is the fork's whole
 * value-targeted pay model, it is one static table, and nothing asserted its
 * arithmetic.
 */
/datum/unit_test/voidcrew_mission_reward_bundling

/datum/unit_test/voidcrew_mission_reward_bundling/Run()
	// A bare shell: setup_target() returns TRUE, generate_details() and
	// build_objectives() are no-ops, so this generates cleanly with no target,
	// no objectives and no world state of any kind behind it.
	var/datum/mission/bundle_probe = new()
	TEST_ASSERT(!bundle_probe.generation_failed, "a bare /datum/mission failed its own generation - the base hooks are supposed to be no-ops")

	// One stack SKU, bundled ten to the unit, exactly as the shop rolls it.
	bundle_probe.mission_rewards = list(/obj/item/stack/sheet/plasteel)
	bundle_probe.reward_amounts = list(/obj/item/stack/sheet/plasteel = 10)
	var/bundled_summary = bundle_probe.get_reward_summary()
	TEST_ASSERT(findtext(bundled_summary, "10×") || findtext(bundled_summary, "10x"), "get_reward_summary() said \"[bundled_summary]\" for a reward of 10 plasteel sheets. \
		The crew is told what the contract paid off this string; without the count it reads as a single sheet, which is what the bug this guards actually delivered.")

	var/list/bundled_ui = bundle_probe.get_ui_data()
	var/list/bundled_items = bundled_ui["reward_items"]
	TEST_ASSERT_EQUAL(length(bundled_items), 1, "get_ui_data() listed [length(bundled_items)] reward cards for a one-entry bundle")
	var/list/bundled_card = bundled_items[1]
	TEST_ASSERT(findtext(bundled_card["name"], "10"), "the board's reward card reads \"[bundled_card["name"]]\" for a bundle of 10. \
		get_ui_data() reads the same reward_amounts entry get_reward_summary() does; a fix applied to one and not the other leaves the board advertising a single sheet.")

	// The negative half. Same reward, no count: one sheet is the CORRECT answer
	// here - that is what a bare stack spawn produces - so the text must say so
	// rather than inventing a bundle.
	bundle_probe.reward_amounts = null
	var/unbundled_summary = bundle_probe.get_reward_summary()
	TEST_ASSERT(!findtext(unbundled_summary, "10"), "with no reward_amounts entry get_reward_summary() still said \"[unbundled_summary]\". \
		Without the entry distribute_rewards() spawns the stack's own default of one, so advertising ten is a promise the payout does not keep.")

	// Duplicates in the bundle are separate items and must be counted, not collapsed.
	bundle_probe.mission_rewards = list(/obj/item/stack/sheet/plasteel, /obj/item/stack/sheet/plasteel)
	var/duplicate_summary = bundle_probe.get_reward_summary()
	TEST_ASSERT(findtext(duplicate_summary, "2×") || findtext(duplicate_summary, "2x"), "a bundle holding the same reward twice summarised as \"[duplicate_summary]\"")

	// ...and duplicates multiply THROUGH the bundle size: two stacks of ten is twenty.
	bundle_probe.reward_amounts = list(/obj/item/stack/sheet/plasteel = 10)
	var/both_summary = bundle_probe.get_reward_summary()
	TEST_ASSERT(findtext(both_summary, "20"), "two bundled stacks of 10 summarised as \"[both_summary]\", not 20 units")

	// Nothing at all still has to read as something.
	bundle_probe.mission_rewards = null
	bundle_probe.mission_reward = null
	bundle_probe.reward_amounts = null
	TEST_ASSERT_EQUAL(bundle_probe.get_reward_summary(), "goods", "a contract with no item rewards summarised as something other than \"goods\"")
	qdel(bundle_probe)

	// ---- the zone table ---------------------------------------------------
	// Literals 1/2/3 = ZONE_GREEN/YELLOW/RED (voidcrew/_DEFINES/overmap_zones.dm),
	// their names "Neutral Zone"/"Contested Zone"/"Lawless Zone" from the same file.
	// Fork defines are not available in unit-test files.
	var/datum/mission/red_probe = new()
	red_probe.value_min = 1000
	red_probe.value_max = 2000
	red_probe.research_reward = 300
	red_probe.voucher_count = 1
	red_probe.apply_zone_scaling(3)
	TEST_ASSERT_EQUAL(red_probe.value_min, 2600, "the Lawless band scaled a 1000 credit floor to [red_probe.value_min]; the table's value_mult is 2.6, rounded to 10")
	TEST_ASSERT_EQUAL(red_probe.value_max, 5200, "the Lawless band scaled a 2000 credit ceiling to [red_probe.value_max]")
	TEST_ASSERT_EQUAL(red_probe.research_reward, 540, "the Lawless band scaled 300 research points to [red_probe.research_reward]; research_mult is 1.8 and is deliberately flatter than the credit one - \
		riding the 2.6x credit multiplier once put one Lawless contract ahead of every other point faucet in the game combined")
	TEST_ASSERT_EQUAL(red_probe.voucher_count, 2, "the Lawless band's voucher_bonus did not reach a contract that already paid 1 voucher")
	TEST_ASSERT_EQUAL(red_probe.difficulty, 3, "the Lawless band left difficulty at [red_probe.difficulty] instead of HARD (3)")
	TEST_ASSERT_EQUAL(red_probe.target_zone_name, "Lawless Zone", "the Lawless band named itself [red_probe.target_zone_name]")
	qdel(red_probe)

	// A contract that pays no vouchers stays paying no vouchers: the red bonus is
	// a top-up on an existing voucher payout, not a new channel.
	var/datum/mission/voucherless_probe = new()
	voucherless_probe.voucher_count = 0
	voucherless_probe.apply_zone_scaling(3)
	TEST_ASSERT_EQUAL(voucherless_probe.voucher_count, 0, "the Lawless voucher bonus invented [voucherless_probe.voucher_count] voucher\s on a contract that pays none")
	qdel(voucherless_probe)

	var/datum/mission/green_probe = new()
	green_probe.value_min = 1000
	green_probe.value_max = 2000
	green_probe.research_reward = 300
	green_probe.apply_zone_scaling(1)
	TEST_ASSERT_EQUAL(green_probe.value_min, 1000, "the Neutral band moved a green-zone floor; types set their band AS the green value, so the green multiplier has to be exactly 1")
	TEST_ASSERT_EQUAL(green_probe.research_reward, 300, "the Neutral band moved a green-zone research payout")
	TEST_ASSERT_EQUAL(green_probe.difficulty, 1, "the Neutral band left difficulty at [green_probe.difficulty] instead of EASY (1)")
	qdel(green_probe)

	// An unrecognised band must fall through to green rather than to a null row:
	// `zone_scaling["[zone_type]"] || zone_scaling["[ZONE_GREEN]"]`.
	var/datum/mission/unknown_probe = new()
	unknown_probe.value_min = 1000
	unknown_probe.value_max = 2000
	unknown_probe.apply_zone_scaling(99)
	TEST_ASSERT_EQUAL(unknown_probe.value_min, 1000, "an unrecognised zone band scaled the pay floor to [unknown_probe.value_min] instead of falling back to the green row")
	TEST_ASSERT_EQUAL(unknown_probe.target_zone_name, "Neutral Zone", "an unrecognised zone band named itself [unknown_probe.target_zone_name]")
	qdel(unknown_probe)

// =========================================================================
// OBJECTIVE SEQUENCING
// =========================================================================

/**
 * # One step at a time, in order, and the shell closes only when all of them are done
 *
 * Breakage class: **mission tests self-silenced on CI worlds.** Objective
 * sequencing is the part of the content loop that needs no world at all - a
 * shell and three objectives - and it had no test, while the two tests that did
 * exist were the ones that needed an overmap and quietly gave up when they
 * thought they had none.
 *
 * Three rules, all of them load-bearing:
 *
 *  - exactly one objective is live at a time, and it is `objectives[1]` first;
 *  - completing a step that is not current does NOT advance the chain
 *    (`on_objective_completed()` refuses anything that is not
 *    `current_objective()`), so a step that finishes early cannot skip the ones
 *    before it;
 *  - ...but it is not lost either. The chain steps over an already-completed
 *    step when it reaches it, which is what keeps a cook who wrapped while the
 *    gather step was still current from wedging the contract on a step that
 *    will never fire again.
 *
 * Bare `/datum/mission_objective` instances are the subject on purpose: the base
 * class is concrete, so this asserts the shell's own sequencing rather than any
 * one objective family's signal wiring.
 */
/datum/unit_test/voidcrew_mission_objective_sequencing

/datum/unit_test/voidcrew_mission_objective_sequencing/Run()
	var/datum/mission/chain = new()
	TEST_ASSERT(!chain.generation_failed, "a bare /datum/mission failed generation")

	var/datum/mission_objective/first = chain.add_objective(new /datum/mission_objective())
	var/datum/mission_objective/second = chain.add_objective(new /datum/mission_objective())
	var/datum/mission_objective/third = chain.add_objective(new /datum/mission_objective())
	TEST_ASSERT_NOTNULL(first, "add_objective() refused a bare objective; generate() returns TRUE on the base class and no subtype overrides it")
	TEST_ASSERT_NOTNULL(second, "add_objective() refused the second objective")
	TEST_ASSERT_NOTNULL(third, "add_objective() refused the third objective")
	TEST_ASSERT_EQUAL(length(chain.objectives), 3, "the shell holds [length(chain.objectives)] objectives after three add_objective() calls")
	TEST_ASSERT_EQUAL(chain.objective_index, 1, "a fresh mission's objective_index is [chain.objective_index], not 1")
	TEST_ASSERT_EQUAL(chain.current_objective(), first, "current_objective() on a fresh mission is not objectives\[1\]")

	// Nothing is live until the mission activates its current step.
	TEST_ASSERT(!first.active, "objectives\[1\] was already active before the mission activated anything")
	chain.activate_current_objective()
	TEST_ASSERT(first.active, "activate_current_objective() left objectives\[1\] inactive, so the step never registers its signals and can never fire")
	TEST_ASSERT(!second.active, "objectives\[2\] activated alongside objectives\[1\]. Exactly one objective is live at a time; two live steps means two sets of signal hooks in the world at once.")
	TEST_ASSERT(!third.active, "objectives\[3\] activated alongside objectives\[1\]")

	// ---- out of order is refused ------------------------------------------
	third.complete()
	TEST_ASSERT_EQUAL(chain.objective_index, 1, "completing objectives\[3\] while objectives\[1\] was current advanced the chain to index [chain.objective_index]. \
		on_objective_completed() refuses anything that is not current_objective() precisely so a late step cannot skip the ones before it.")
	TEST_ASSERT_EQUAL(chain.current_objective(), first, "the current objective moved when a non-current step completed")
	TEST_ASSERT(!chain.all_objectives_satisfied(), "the shell reported every objective satisfied with two of three still outstanding")
	TEST_ASSERT(!chain.can_complete(), "the shell was completable with two of three objectives outstanding. can_complete() is what the board's turn-in gates on.")
	TEST_ASSERT(!second.active, "objectives\[2\] armed itself when objectives\[3\] completed out of order")

	// ---- in order advances -------------------------------------------------
	first.complete()
	TEST_ASSERT_EQUAL(chain.objective_index, 2, "completing the current objective left the chain at index [chain.objective_index]")
	TEST_ASSERT_EQUAL(chain.current_objective(), second, "the chain did not advance to objectives\[2\]")
	TEST_ASSERT(second.active, "objectives\[2\] became current without being activated, so its signal hooks are never registered and it can never complete")
	TEST_ASSERT(!first.active, "the completed objective is still active; complete() deactivates before advancing")
	TEST_ASSERT(!chain.can_complete(), "the shell was completable with objectives\[2\] still outstanding")

	// ...and steps over the step that finished early rather than wedging on it
	second.complete()
	TEST_ASSERT_NULL(chain.current_objective(), "with all three objectives done current_objective() still answered [chain.current_objective()]. \
		The chain must step over objectives\[3\], which completed out of order and will never fire again - stopping on it wedges the contract forever.")
	TEST_ASSERT(chain.all_objectives_satisfied(), "all three objectives report completed but the shell does not agree")
	TEST_ASSERT(chain.can_complete(), "every objective is satisfied and the shell still refuses to complete")
	TEST_ASSERT_EQUAL(chain.get_progress_string(), "Ready to turn in", "a finished chain's progress line reads \"[chain.get_progress_string()]\"")
	qdel(chain)

	// ---- a counted hand-over is a step that advances itself ----------------
	// The other half of sequencing: one objective that wants N loose items
	// reports PROGRESS until the last one, and only then completes and hands the
	// chain on. /obj/item/mission_recovery is a plain (non-stack) item, so this
	// exercises the counted branch rather than the stack branch.
	var/datum/mission/counted = new()
	var/datum/mission_objective/deliver/ask = new
	ask.required_type = /obj/item/mission_recovery
	ask.required_name = "salvage"
	ask.required_amount = 2
	counted.add_objective(ask)
	counted.requires_item = ask.requires_item

	var/obj/item/mission_recovery/first_half = allocate(/obj/item/mission_recovery)
	var/obj/item/mission_recovery/second_half = allocate(/obj/item/mission_recovery)
	TEST_ASSERT(ask.can_turn_in(first_half), "the deliver objective refused an item of exactly the type it asked for")
	TEST_ASSERT_EQUAL(ask.accept_item(first_half, null), 1, "the first of two loose hand-overs did not answer MISSION_ITEM_PROGRESS (literal 1, voidcrew/_DEFINES/missions.dm)")
	TEST_ASSERT_EQUAL(ask.delivered_count, 1, "a counted deliver objective banked [ask.delivered_count] of its first hand-over")
	TEST_ASSERT(!ask.completed, "a counted deliver objective completed on the first of two hand-overs")
	TEST_ASSERT(!counted.can_turn_in(null), "the shell accepted a null item as a turn-in")

	TEST_ASSERT_EQUAL(ask.accept_item(second_half, null), 2, "the last of two loose hand-overs did not answer MISSION_ITEM_COMPLETE (literal 2)")
	TEST_ASSERT(ask.completed, "the deliver objective did not complete once its full count was handed over")
	TEST_ASSERT(counted.all_objectives_satisfied(), "the shell does not consider a completed single-objective contract satisfied")

	// reset() has to put a counted objective back to pristine, not just clear the
	// completed flag - a retarget re-runs the whole chain against a fresh site.
	ask.reset()
	TEST_ASSERT(!ask.completed, "reset() left the objective completed")
	TEST_ASSERT_EQUAL(ask.delivered_count, 0, "reset() left [ask.delivered_count] hand-over\s banked, so a retargeted contract starts part-paid")
	qdel(counted)

// =========================================================================
// QUEST-LOSS POLICY
// =========================================================================

/**
 * # Losing the objective fails the contract, or moves it, per the type's policy
 *
 * Breakage class: **mission tests self-silenced on CI worlds.** This is the
 * other half of what the two repaired tests were reaching for. They asserted
 * which ruin a contract picks; nothing asserted what happens when the thing the
 * contract is tracking is destroyed, which is the branch that decides whether a
 * crew loses a job or is sent somewhere else.
 *
 * Uses minted ruin signals rather than the live pool so the retarget has a
 * candidate it can be asserted against: resolve() deliberately excludes the
 * previous pick, so "it moved" means "it moved to one of these".
 */
/datum/unit_test/voidcrew_mission_quest_loss_policy

/datum/unit_test/voidcrew_mission_quest_loss_policy/Run()
	var/list/obj/structure/overmap/space_ruin/minted = vc_mint_test_ruin_signals(3)
	if(length(minted) < 3)
		TEST_FAIL("could not mint the 3 ruin signals this test needs (got [length(minted)]); a retarget has to have somewhere to go")
		vc_release_test_ruin_signals(minted)
		return

	// Everything else on the overmap is hidden for the duration so the picks are
	// answerable. Restored on every exit path below.
	var/list/obj/structure/overmap/space_ruin/hidden = list()
	for(var/obj/structure/overmap/space_ruin/other as anything in GLOB.space_ruin_signals)
		if((other in minted) || other.mission_locked)
			continue
		other.mission_locked = TRUE
		hidden += other

	// ---- FAIL policy -------------------------------------------------------
	// Literal 0 = MISSION_QUEST_LOST_FAIL (voidcrew/_DEFINES/missions.dm).
	var/datum/mission/failing = new()
	failing.quest_lost_policy = 0
	var/datum/mission_target/space_ruin/failing_target = new(failing)
	failing.target = failing_target
	if(!failing_target.resolve())
		TEST_FAIL("a space_ruin target found nothing with 3 minted signals standing cold and unclaimed on the overmap")
	else
		var/obj/item/mission_recovery/failing_atom = allocate(/obj/item/mission_recovery)
		failing.register_quest_atom(failing_atom)
		TEST_ASSERT_EQUAL(failing.quest_atom, failing_atom, "register_quest_atom() did not take")
		qdel(failing_atom)
		TEST_ASSERT(failing.failed, "the contract's quest atom was destroyed under the FAIL policy and the contract did not fail. \
			handle_quest_loss() is the only thing standing between a destroyed objective and a job that can never be finished but never ends either.")
		TEST_ASSERT(QDELETED(failing), "a failed mission was not deleted; fail() ends in qdel(src)")

	// ---- RETARGET policy ---------------------------------------------------
	// Literal 1 = MISSION_QUEST_LOST_RETARGET.
	var/datum/mission/moving = new()
	moving.quest_lost_policy = 1
	var/datum/mission_target/space_ruin/moving_target = new(moving)
	moving.target = moving_target
	var/datum/mission_objective/step_one = moving.add_objective(new /datum/mission_objective())
	moving.add_objective(new /datum/mission_objective())
	if(!moving_target.resolve())
		TEST_FAIL("a space_ruin target found nothing for the retargeting contract")
	else
		var/obj/structure/overmap/space_ruin/original_site = moving_target.ruin
		var/original_serial = moving.binding_serial
		// The chain is mid-run: step one done, step two current.
		moving.activate_current_objective()
		step_one.complete()
		TEST_ASSERT_EQUAL(moving.objective_index, 2, "the setup for the retarget check did not advance the chain")

		var/obj/item/mission_recovery/moving_atom = allocate(/obj/item/mission_recovery)
		moving.register_quest_atom(moving_atom)
		qdel(moving_atom)

		TEST_ASSERT(!moving.failed, "the RETARGET policy failed the contract instead of re-picking a site")
		TEST_ASSERT(!QDELETED(moving), "the RETARGET policy deleted the contract")
		TEST_ASSERT_NOTEQUAL(moving_target.ruin, original_site, "the contract retargeted onto the same ruin it just lost. resolve() excludes the previous pick for exactly this reason.")
		TEST_ASSERT(moving_target.ruin in minted, "the retarget landed on [moving_target.ruin], which is not one of the minted signals even though every other ruin was hidden")
		TEST_ASSERT_EQUAL(moving.objective_index, 1, "a retarget left the chain on step [moving.objective_index]. The fresh site has none of the old site's setup in it, so the chain restarts from step one.")
		TEST_ASSERT(!step_one.completed, "a retarget left step one completed, so the crew is never asked to do it at the new site")
		TEST_ASSERT_NOTEQUAL(moving.binding_serial, original_serial, "the binding serial did not move on a retarget. \
			Items bound before the retarget would still satisfy the contract, so a crew could turn in salvage recovered from the site the contract no longer points at.")
		TEST_ASSERT_NULL(moving.quest_atom, "the destroyed quest atom is still tracked after the retarget")

	// ---- the retarget budget ----------------------------------------------
	// An active contract pays for each move. Out of retargets, the loss fails it.
	var/datum/mission/broke = new()
	broke.quest_lost_policy = 1
	var/datum/mission_target/space_ruin/broke_target = new(broke)
	broke.target = broke_target
	if(!broke_target.resolve())
		TEST_FAIL("a space_ruin target found nothing for the retarget-budget check")
	else
		// active without a servant: fail() and retarget() both null-guard the ship,
		// and the budget branch is gated on `active` alone.
		broke.active = TRUE
		broke.retargets_left = 0
		var/obj/item/mission_recovery/broke_atom = allocate(/obj/item/mission_recovery)
		broke.register_quest_atom(broke_atom)
		qdel(broke_atom)
		TEST_ASSERT(broke.failed, "a live contract out of retargets kept re-picking. retargets_left is the whole budget; without it a contract whose target keeps dying moves forever.")
		TEST_ASSERT(QDELETED(broke), "the out-of-budget contract was not deleted")

	if(!QDELETED(moving))
		qdel(moving)
	for(var/obj/structure/overmap/space_ruin/other as anything in hidden)
		if(!QDELETED(other))
			other.mission_locked = FALSE
	vc_release_test_ruin_signals(minted)

// =========================================================================
// FIELD SPAWN BOUNDS
// =========================================================================

/**
 * A map template with nothing behind it, so a synthetic site can carry a rect.
 *
 * `get_random_interior_turf()` refuses to sample without `ruin_template.width`
 * and `.height`, and every real template is a preloaded .dmm whose size is
 * whatever that file is. Subclassing `/datum/map_template/ruin/space` is not an
 * option: `/datum/map_template/ruin/New()` builds `mappath` from prefix+suffix
 * and preloads it, and a ruin subtype with an `id` is registered into
 * `SSmapping.space_ruins_templates` at boot and can then be SEEDED onto the
 * live overmap. A direct `/datum/map_template` subtype with no `mappath` is
 * inert: `New()` skips `preload_size()`, and nothing in the tree sweeps
 * `/datum/map_template` subtypes except the two `/datum/map_template/ruin`
 * preloaders, which this is not one of.
 */
/datum/map_template/vc_mission_site_fixture
	name = "unit test mission site"

/**
 * # A field objective spawns inside its own site, never on the neighbour's ground
 *
 * Breakage class: **mission tests self-silenced on CI worlds.** `get_spawn_turf()`
 * is where every field objective puts its physical objective - the named
 * target, the survivor, the quest item, the pylons - and until now the only
 * thing that would have caught a bad sample was a player flying out to an empty
 * site.
 *
 * Two rules, both of them consequences of packing several tenants onto one
 * z-level:
 *
 *  - the sample comes from the SITE's rectangle, not the level's. On a packed
 *    level the level rect spans every co-tenant, so sampling it puts objectives
 *    on a neighbouring world behind an indestructible cordon the crew cannot
 *    cross - the objective is simply unreachable, and nothing errors.
 *  - the sample is random over the whole site, deliberately. Field objectives
 *    that place several things call it repeatedly and must not be handed the
 *    same tile twice in a row by construction.
 *
 * The site is synthetic: a signal-only ruin holding a template rect
 * deliberately LARGER than its footprint, which is the "a template that grew
 * past its preloaded size" case `get_random_interior_turf()` names in its own
 * comment. No encounter is loaded and none is needed - the sampler reads
 * `ruin_bottom_left`, the template's width/height and the footprint, and the
 * unit-test room supplies a real rectangle of open, non-space, non-shuttle floor
 * for it to find.
 */
/datum/unit_test/voidcrew_mission_field_spawn_bounds

/datum/unit_test/voidcrew_mission_field_spawn_bounds/Run()
	var/turf/room_corner = run_loc_floor_bottom_left
	var/turf/room_far_corner = run_loc_floor_top_right
	TEST_ASSERT_NOTNULL(room_corner, "the unit test room has no bottom-left landmark, so there is no rectangle to sample")
	TEST_ASSERT_NOTNULL(room_far_corner, "the unit test room has no top-right landmark")
	TEST_ASSERT_EQUAL(room_corner.z, room_far_corner.z, "the unit test room's two corners are on different z-levels")

	var/room_width = room_far_corner.x - room_corner.x + 1
	var/room_height = room_far_corner.y - room_corner.y + 1
	TEST_ASSERT(room_width >= 2 && room_height >= 2, "the unit test room is [room_width]x[room_height]; this test needs a rectangle it can miss")

	var/list/obj/structure/overmap/space_ruin/minted = vc_mint_test_ruin_signals(1)
	if(!length(minted))
		TEST_FAIL("could not mint the ruin signal this test hangs its synthetic site on")
		return
	var/obj/structure/overmap/space_ruin/site = minted[1]

	// The template rect overshoots the footprint on both axes on purpose: those
	// extra tiles are the "neighbour's ground" the footprint clamp must reject.
	var/overshoot = 6
	var/datum/map_template/vc_mission_site_fixture/template = new()
	template.width = min(room_width + overshoot, world.maxx - room_corner.x + 1)
	template.height = min(room_height + overshoot, world.maxy - room_corner.y + 1)
	if(template.width <= room_width || template.height <= room_height)
		TEST_FAIL("the unit test room sits too close to the map edge for the template rect to overshoot its footprint ([template.width]x[template.height] against a [room_width]x[room_height] room). \
			The footprint clamp is the branch under test and would not be exercised.")

	var/datum/map_footprint/footprint = new(null, null, 1, site)
	footprint.set_rect(room_corner.x, room_corner.y, room_width, room_height)
	footprint.z_value = room_corner.z

	site.ruin_template = template
	site.ruin_bottom_left = room_corner
	site.footprint = footprint
	site.loaded = TRUE

	// The target is pointed at the site by hand rather than through resolve() so
	// this test never consumes a claim on a real ruin somebody else's contract
	// may be holding.
	var/datum/mission_target/space_ruin/aim = new(null)
	aim.ruin = site

	// The bounds the mission caches for its stranding check must be the site's
	// rect, not the level's - the level rect would condemn a quest atom sitting
	// on a co-tenant's ground as "stranded in the dead site" and destroy it.
	var/list/bounds = aim.get_interior_bounds()
	TEST_ASSERT_EQUAL(length(bounds), 5, "get_interior_bounds() returned [length(bounds)] values, not list(min_x, min_y, max_x, max_y, z)")
	TEST_ASSERT_EQUAL(bounds[1], room_corner.x, "the cached interior bounds start at x [bounds[1]], not the site's own low edge")
	TEST_ASSERT_EQUAL(bounds[3], room_far_corner.x, "the cached interior bounds end at x [bounds[3]], not the site's own high edge")
	TEST_ASSERT_EQUAL(bounds[5], room_corner.z, "the cached interior bounds name z [bounds[5]]")

	// What the sampler is allowed to return, computed here the way it computes it.
	var/list/turf/legal = list()
	for(var/turf/tile as anything in block(room_corner, room_far_corner))
		if(tile.density || isspaceturf(tile))
			continue
		if(istype(get_area(tile), /area/shuttle))
			continue
		legal += tile
	TEST_ASSERT(length(legal) >= 2, "the unit test room offered [length(legal)] samplable tile\s; this test needs at least two to tell a random pick from a fixed one")

	var/list/turf/seen = list()
	for(var/_ in 1 to 40)
		var/turf/landed = aim.get_spawn_turf()
		if(isnull(landed))
			TEST_FAIL("get_spawn_turf() came back empty at a loaded site holding [length(legal)] clear tiles. \
				A field objective reads that as a site that cannot take its spawn, retries MISSION_FIELD_SPAWN_TRIES times and then voids the contract.")
			break
		if(!footprint.contains_turf(landed))
			TEST_FAIL("get_spawn_turf() landed on ([landed.x],[landed.y],[landed.z]), outside the site's own footprint ([room_corner.x],[room_corner.y])-([room_far_corner.x],[room_far_corner.y]). \
				On a packed z-level that tile belongs to a co-tenant, behind an indestructible cordon: the objective is unreachable and nothing reports an error.")
			break
		if(!(landed in legal))
			TEST_FAIL("get_spawn_turf() landed on ([landed.x],[landed.y],[landed.z]), which is inside the footprint but is dense, space, or shuttle floor")
			break
		seen |= landed

	var/expected_distinct = min(3, length(legal))
	TEST_ASSERT(length(seen) >= expected_distinct, "40 samples of get_spawn_turf() returned only [length(seen)] distinct tile\s out of [length(legal)] available. \
		The sample is random over the WHOLE site by design - objectives that place several things call it repeatedly, and a sampler that keeps handing back the same tile stacks them all in one spot.")

	// The documented fallback: an unloaded site still answers with its own corner
	// rather than null, so a caller never mistakes "not loaded yet" for "no room".
	site.loaded = FALSE
	TEST_ASSERT_EQUAL(aim.get_spawn_turf(), room_corner, "an unloaded site answered [aim.get_spawn_turf() || "null"] instead of falling back to its bottom-left corner")

	// contains_turf() is the "is the crew at the site" primitive the pylon scatter
	// and the hunting lure both gate on. A tile one step outside the rect is not.
	var/turf/outside = locate(room_far_corner.x + 1, room_far_corner.y, room_far_corner.z)
	if(outside)
		TEST_ASSERT(!aim.contains_turf(outside), "a tile one step outside the site's rect reads as inside it. A bare z match was correct only while a site owned its whole level.")
	TEST_ASSERT(aim.contains_turf(room_corner), "the site's own bottom-left corner does not read as inside the site")

	qdel(aim)
	site.footprint = null
	qdel(footprint)
	qdel(template)
	vc_release_test_ruin_signals(minted)

// =========================================================================
// FULL CONTRACT LIFECYCLE ON A REAL HULL
// =========================================================================

/**
 * # Accept, work, turn in, get paid - through the console a player uses
 *
 * Breakage class: **mission tests self-silenced on CI worlds.** Everything above
 * this point is the loop's parts. This is the loop: a real assembled hull, a
 * real mission board console wired to a real mission pad, and every contract
 * driven in through `ui_act` the way a player drives it, with the payout
 * asserted on the ship's account and on the tiles of the pad.
 *
 * ## Which contracts are driven end to end, and why those
 *
 * Four of the twenty-six, chosen because their objectives are satisfiable in a
 * world where no site interior is loaded:
 *
 *  - **`/datum/mission/delivery`** - the item turn-in family. No overmap target;
 *    its `deliver` objective wants N of a stack, which is one `new` to satisfy.
 *    This is the only end-to-end path through `can_turn_in()` ->
 *    `accept_item()` -> stack consumption -> credit payout.
 *  - **`/datum/mission/research/telemetry`** - the NON-item completion path
 *    (`can_complete()` rather than `can_turn_in()`) and the research payout,
 *    which is physical: a dossier atom spawned at the turn-in point, not points
 *    banked into a techweb. Its `scan_celestial` objective completes off a
 *    signal on the servant ship, which needs no world state at all.
 *  - **`/datum/mission/exploration`** - the overmap-target family. Its `coords`
 *    target resolves against the live zone controller (so this also asserts the
 *    test world HAS one), and its `goto_coords` objective completes off the
 *    ship-moved signal, measured against the target's cached coordinates.
 *  - **a bare `/datum/mission`** carrying a hand-built reward bundle - the
 *    spawn half of the `reward_amounts` sentinel, which needs a servant ship and
 *    a turn-in anchor and therefore cannot live in the shipless test above.
 *
 * The other twenty-two all end in a `field` objective, which places nothing
 * until its site's interior loads. Driving one honestly costs a real
 * `spawn_dynamic_encounter()` map load *per contract*, on top of the hull this
 * test already builds. See "Coverage boundaries" at the bottom of the file.
 *
 * ## The hull
 *
 * One hull for the whole file, per the fixture's own cost note, and NOT the
 * fixture's default one - see pick_buildable_hull_type() below for why the two
 * smallest hulls in the catalog cannot host this test at all.
 *
 * The hull that gets picked ships a mission board and pad of its own, and this
 * test still builds its own pair on a tile it has verified is empty. That is
 * deliberate: the payout checks identify what a contract paid by looking for it
 * on the pad's turf, so the contents of that turf have to be known going in -
 * and a reward stack landing on a tile that already held one of the same type
 * would silently MERGE into it rather than answer as itself.
 */
/datum/unit_test/voidcrew_mission_contract_lifecycle
	priority = TEST_LONGER

/**
 * The smallest purchasable hull that actually has floor to build on, as a type path.
 *
 * `vc_create_test_ship()`'s default is the smallest purchasable hull by footprint,
 * and that is the Blackpill: three tiles wall to wall, every one of them holding a
 * bunk, an ore bag or the self-destruct charge, and **zero** bare floor. The first
 * run of this test died on exactly that. Its sibling the Pill-class - the smallest
 * hull with upgrade slots, so the obvious "pick a modular one instead" fix - is four
 * tiles and also has zero bare floor, so the honest selector is neither "smallest"
 * nor "modular" but "big enough to stand a console, a pad, an item and a crewman on".
 *
 * The curated novelty hulls separate from every real one by an order of magnitude
 * (Pill 4 tiles of bounding box, Blackpill 3; the next hull up is 209 with 62 bare
 * floor tiles), so a floor of 50 splits them with room to spare and still picks the
 * cheapest real hull - this is a real map load and the smallest honest one is wanted.
 */
/datum/unit_test/voidcrew_mission_contract_lifecycle/proc/pick_buildable_hull_type()
	var/datum/map_template/shuttle/voidcrew/smallest
	for(var/datum/map_template/shuttle/voidcrew/candidate as anything in get_purchasable_ship_templates())
		if(!candidate.width || !candidate.height)
			continue
		if(candidate.width * candidate.height < 50)
			continue
		if(isnull(smallest) || (candidate.width * candidate.height) < (smallest.width * smallest.height))
			smallest = candidate
	// .type, never the catalog instance: create_ship() rewrites suffix/theme/mappath
	// on whatever it is handed, so passing the shared catalog object corrupts it for
	// every later caller (overmap.dm:1030).
	return smallest?.type

/datum/unit_test/voidcrew_mission_contract_lifecycle/Run()
	var/hull_type = pick_buildable_hull_type()
	if(isnull(hull_type))
		TEST_FAIL("no purchasable hull is big enough to build a mission board on - every one of them is under 50 tiles of bounding box. \
			The contract loop cannot be driven end to end without somewhere to stand a console, a pad and a crewman.")
		return

	var/obj/structure/overmap/ship/ship = vc_create_test_ship(hull_type)
	if(isnull(ship))
		return // vc_create_test_ship() has already recorded why

	if(isnull(ship.ship_account))
		TEST_FAIL("the fixture hull has no ship_account, so no credit payout can be asserted against it")
		vc_release_test_ship(ship)
		return

	// A deck tile to stand the turn-in point on. Walked through shuttle_areas, NOT
	// through shuttle.return_turfs().
	//
	// return_turfs() is block(return_coords()) - the whole bounding RECTANGLE, not
	// the hull. On a modular hull the difference is not cosmetic: the Goon's
	// rectangle is 209 tiles of which only 176 are in a /area/shuttle area, and the
	// other 33 are /turf/template_noop in /area/template_noop - the modular
	// merge-sim passthrough, which loads nothing and leaves whatever ground the
	// berth already had. At runtime that is space, and space is an OPEN turf that is
	// not dense, not blocked and holds no items, so a filter written against
	// return_turfs() happily selects one. block() walks from the bottom-left corner,
	// which on this hull is template_noop, so it is selected FIRST.
	//
	// A machine standing there is not on the ship: get_ship_from_atom() resolves
	// through /obj/docking_port/mobile/is_in_shuttle_bounds(), which is the geometric
	// box AND shuttle_areas[get_area(A)]. The area is what decides it, so the area is
	// what this walks. (voidcrew_ship_lifecycle.dm does the same, at :85 and :304.)
	//
	// The tile must also start with no loose items on it: the payout checks below
	// identify what a contract paid by looking for it on the pad's own turf, and a
	// stack already lying there would both answer that locate() and MERGE with a
	// spawned stack of the same type.
	var/turf/deck
	var/open_tiles = 0
	for(var/area/compartment as anything in ship.shuttle.shuttle_areas)
		if(deck)
			break
		for(var/turf/candidate in compartment)
			if(!isopenturf(candidate) || isspaceturf(candidate) || candidate.density)
				continue
			open_tiles++
			if(candidate.is_blocked_turf(exclude_mobs = TRUE))
				continue
			if(locate(/obj/item) in candidate)
				continue
			deck = candidate
			break
	if(isnull(deck))
		TEST_FAIL("[hull_type] offered no clear open tile to build a mission board on: [open_tiles] open floor tile\s, every one of them blocked or holding an item. \
			pick_buildable_hull_type() is supposed to have ruled the floorless novelty hulls out already - if this hull is a real one, its default modules now furnish every tile it owns.")
		vc_release_test_ship(ship)
		return

	// The precondition every ui_act below rests on, asserted before a single machine
	// is built on this tile rather than discovered as a mystery further down.
	if(!ship.shuttle.shuttle_areas[get_area(deck)])
		TEST_FAIL("the chosen deck tile is in [get_area(deck) || "no area"], which is not one of the hull's registered compartments. \
			get_ship_from_atom() resolves through shuttle_areas\[get_area(A)\], so nothing built here would resolve to a ship and every board action would be refused.")
		vc_release_test_ship(ship)
		return

	// Pad first: the console links to whatever pad is already within 3 tiles when
	// it initialises (find_linked_pad()), and the board's turn-in reads items off
	// linked_pad.loc. Both on one tile keeps the item, the pad and the payout
	// anchor on the same turf.
	var/obj/machinery/mission_pad/pad = new(deck)
	var/obj/machinery/computer/mission_board/console = new(deck)

	// The hull is freshly assembled and its power state is not what this test is
	// about; a NOPOWER machine is refused at the tgui status gate and every
	// ui_act below would be delivered to nothing. Forced, then asserted.
	if(!console.is_operational)
		console.set_machine_stat(console.machine_stat & ~NOPOWER)
	if(!pad.is_operational)
		pad.set_machine_stat(pad.machine_stat & ~NOPOWER)

	var/mob/living/carbon/human/crew = allocate(/mob/living/carbon/human/consistent)

	if(!console.is_operational)
		TEST_FAIL("the mission board console is still not operational after NOPOWER was cleared; every ui_act would be refused at the status gate")
	else if(console.linked_pad != pad)
		TEST_FAIL("the console linked to [console.linked_pad || "no pad"] instead of the pad standing on its own tile. \
			Without the link the board cannot see items offered for turn-in and every item contract refuses.")
	else if(console.get_ship() != ship)
		TEST_FAIL("the console on the fixture hull resolves to [console.get_ship() || "no ship"]. get_ship_from_atom() walks the containing shuttle, so this is the hull's area registration, not the console.")
	else
		check_delivery_contract(ship, console, pad, crew)
		check_research_contract(ship, console, pad, crew)
		check_exploration_contract(ship, console, crew)
		check_bundled_stack_payout(ship, console, pad, crew)
		check_type_limit_through_accept(ship, console, crew)
		check_ssmissions_tick(ship, console, crew)

	// Off the hull before it is torn down: vc_release_test_ship() deletes every
	// mob standing on a hull tile, and allocate()'s own cleanup would then be
	// working on a corpse.
	if(!QDELETED(crew))
		crew.forceMove(run_loc_floor_bottom_left)
	qdel(console)
	qdel(pad)
	vc_release_test_ship(ship)

/// Everything this ship is holding that this test put there, gone, in whatever
/// state the check under it left things.
/datum/unit_test/voidcrew_mission_contract_lifecycle/proc/drop_contract(obj/structure/overmap/ship/ship, datum/mission/mission)
	if(QDELETED(mission))
		return
	ship.available_missions -= mission
	ship.active_missions -= mission
	qdel(mission)

/// Puts an offer on the ship's board and accepts it through the console, the way
/// a player does. Returns TRUE when the ship reports it active.
/datum/unit_test/voidcrew_mission_contract_lifecycle/proc/accept_through_console(obj/structure/overmap/ship/ship, obj/machinery/computer/mission_board/console, mob/crew, datum/mission/mission)
	ship.available_missions |= mission
	if(!vc_ui_act(crew, console, "accept", list("ref" = REF(mission))))
		return FALSE
	if(!mission.active)
		TEST_FAIL("[mission.type] was accepted through the board and did not go active. accept_mission() refuses for a named reason (board membership, the [ship.max_missions]-contract cap, the per-type limit); \
			the console swallows that reason into a balloon alert, so assert here on the state instead.")
		return FALSE
	if(!(mission in ship.active_missions))
		TEST_FAIL("[mission.type] went active without landing in the ship's active_missions, so the board will never list it and it can never be turned in")
		return FALSE
	if(mission in ship.available_missions)
		TEST_FAIL("[mission.type] is still on the ship's available board after being accepted, so it can be accepted a second time")
		return FALSE
	if(!(mission in SSmissions.all_active_missions))
		TEST_FAIL("[mission.type] went active without being tracked by SSmissions, so its type cap counts one fewer than is really running")
		return FALSE
	if(!mission.timeout_timer)
		TEST_FAIL("[mission.type] went active with no timeout timer; nothing ever ends it")
		return FALSE
	return TRUE

/**
 * Delivery: hand a stack over at the pad, get paid, and have the goods consumed.
 */
/datum/unit_test/voidcrew_mission_contract_lifecycle/proc/check_delivery_contract(obj/structure/overmap/ship/ship, obj/machinery/computer/mission_board/console, obj/machinery/mission_pad/pad, mob/crew)
	var/datum/mission/delivery/job = new()
	if(job.generation_failed)
		TEST_FAIL("/datum/mission/delivery failed generation. It rolls off a static ask table and needs no world state whatsoever, so this is the type itself.")
		qdel(job)
		return

	TEST_ASSERT(job.requires_item, "a delivery contract does not report requires_item, so the board offers no item turn-in for it at all")
	TEST_ASSERT(ispath(job.required_type, /obj/item/stack), "the delivery ask rolled [job.required_type], which is not a stack; this check hands over a stack")
	var/asked_for = job.required_amount
	var/promised = job.value
	TEST_ASSERT(promised > 0, "a delivery contract rolled a payout of [promised] credits")

	if(!accept_through_console(ship, console, crew, job))
		drop_contract(ship, job)
		return

	// Short of the ask first: the refusal has to name the real shortfall, and
	// nothing must be consumed.
	if(asked_for > 1)
		var/obj/item/stack/short = new job.required_type(get_turf(pad), asked_for - 1)
		TEST_ASSERT(!job.can_turn_in(short), "the contract accepted [asked_for - 1] of an ask for [asked_for]")
		var/reason = job.get_failure_reason(short)
		TEST_ASSERT(findtext(reason, "[asked_for]"), "a short hand-over was refused with \"[reason]\", which does not name the [asked_for] the contract wants. \
			The near-miss path exists so a refusal names the shortfall instead of telling somebody holding the goods to go hold the goods.")
		vc_ui_act(crew, console, "turn_in", list("ref" = REF(job), "item_ref" = REF(short)))
		TEST_ASSERT(!QDELETED(job), "a short hand-over completed the contract")
		TEST_ASSERT(!QDELETED(short), "a refused hand-over consumed the goods anyway")
		qdel(short)

	var/obj/item/stack/goods = new job.required_type(get_turf(pad), asked_for)
	TEST_ASSERT(job.can_turn_in(goods), "the contract refused exactly the [asked_for] [job.required_name] it asked for")

	var/balance_before = ship.ship_account.account_balance
	if(!vc_ui_act(crew, console, "turn_in", list("ref" = REF(job), "item_ref" = REF(goods))))
		drop_contract(ship, job)
		return

	TEST_ASSERT(QDELETED(job), "the delivery contract survived a satisfying turn-in; finish_mission() ends in qdel(src)")
	TEST_ASSERT(QDELETED(goods), "the delivered stack survived the turn-in. accept_item() calls stack.use(required_amount), which deletes a stack it empties.")
	TEST_ASSERT_EQUAL(ship.ship_account.account_balance, balance_before + promised, "turning in a [promised] credit contract moved the ship's balance by [ship.ship_account.account_balance - balance_before]")
	TEST_ASSERT(!(job in ship.active_missions), "a completed contract is still listed on the ship")
	TEST_ASSERT(!(job in SSmissions.all_active_missions), "a completed contract is still tracked by SSmissions, so its type cap stays spent for the round")

/**
 * Telemetry: a contract that completes without an item, and pays in a physical
 * research dossier rather than into a techweb.
 */
/datum/unit_test/voidcrew_mission_contract_lifecycle/proc/check_research_contract(obj/structure/overmap/ship/ship, obj/machinery/computer/mission_board/console, obj/machinery/mission_pad/pad, mob/crew)
	var/datum/mission/research/telemetry/job = new()
	if(job.generation_failed)
		TEST_FAIL("/datum/mission/research/telemetry failed generation; it rolls off a static ask table and has no overmap target")
		qdel(job)
		return

	TEST_ASSERT(!job.requires_item, "a telemetry contract reports requires_item, so the board would demand an item it never asks for")
	TEST_ASSERT_NOTNULL(job.scan, "the telemetry contract built no scan objective")
	var/quota = job.scan.required_amount
	var/promised = job.value
	var/points = job.research_reward
	var/origin = job.research_origin
	TEST_ASSERT(points > 0, "a telemetry contract pays [points] research points; the points ARE the contract")

	if(!accept_through_console(ship, console, crew, job))
		drop_contract(ship, job)
		return

	TEST_ASSERT(job.scan.active, "the scan objective did not arm on accept, so no survey will ever count towards it")
	TEST_ASSERT(!job.can_complete(), "the contract was completable before a single scan was logged")

	// "voidcrew_survey_completed" is COMSIG_VOIDCREW_SURVEY_COMPLETED
	// (voidcrew/_DEFINES/ship_defines.dm). Fork defines are unavailable in
	// unit-test files, so the literal carries the name in this comment.
	for(var/i in 1 to quota)
		SEND_SIGNAL(ship, "voidcrew_survey_completed", job.target_type)

	TEST_ASSERT_EQUAL(job.scan.current_amount, quota, "[quota] qualifying surveys banked [job.scan.current_amount] towards the quota")
	TEST_ASSERT(job.scan.completed, "the scan objective did not complete on its full quota")
	TEST_ASSERT(job.can_complete(), "every objective is satisfied and the contract still refuses to complete")

	// A survey of the wrong kind after the quota is met must not double-count.
	SEND_SIGNAL(ship, "voidcrew_survey_completed", job.target_type)
	TEST_ASSERT_EQUAL(job.scan.current_amount, quota, "a survey logged after the quota was met pushed the count to [job.scan.current_amount]")

	var/turf/payout_turf = get_turf(pad)
	var/balance_before = ship.ship_account.account_balance
	if(!vc_ui_act(crew, console, "turn_in", list("ref" = REF(job))))
		drop_contract(ship, job)
		return

	TEST_ASSERT(QDELETED(job), "the telemetry contract survived its turn-in")
	TEST_ASSERT_EQUAL(ship.ship_account.account_balance, balance_before + promised, "the telemetry contract's credit stipend moved the balance by [ship.ship_account.account_balance - balance_before], not [promised]")

	var/obj/item/research_notes/dossier = locate() in payout_turf
	TEST_ASSERT_NOTNULL(dossier, "a research contract paid [points] points and left no dossier on the turn-in point. \
		The payout is deliberately physical - a ship keeps its techweb on a server disk that may not be installed, so an atom the crew carries to an R&D console is the only channel that works for every crew.")
	if(dossier)
		TEST_ASSERT_EQUAL(dossier.value, points, "the dossier is worth [dossier.value] points, not the [points] the contract advertised")
		TEST_ASSERT_EQUAL(dossier.origin_type, origin, "the dossier's field of study is \"[dossier.origin_type]\", not the contract's \"[origin]\"")
		qdel(dossier)

/**
 * Exploration: the overmap-target family. Also the assertion that this world has
 * a live zone controller at all - a `coords` target cannot resolve without one.
 */
/datum/unit_test/voidcrew_mission_contract_lifecycle/proc/check_exploration_contract(obj/structure/overmap/ship/ship, obj/machinery/computer/mission_board/console, mob/crew)
	var/datum/mission/exploration/job = new()
	if(job.generation_failed)
		TEST_FAIL("/datum/mission/exploration failed generation. Its coords target resolves against SSovermap_zones' own turf sets, so this says the test world has no live zone controller - \
			which would also mean every zone-scaled payout and every banded target in the contract table is untested here. It is not a reason to skip: SSovermap.Initialize() builds the overmap on every map.")
		qdel(job)
		return

	var/datum/mission_objective/goto_coords/leg = job.objectives[1]
	TEST_ASSERT_NOTNULL(leg, "the exploration contract built no travel objective")
	TEST_ASSERT_NOTNULL(job.target, "the exploration contract generated with no target")

	// The hull's overmap token has to actually be ON the overmap for any of this to
	// mean anything. Asserted rather than assumed: if a fixture ship ever came back
	// with its token in nullspace, every distance below would be measured from (0,0)
	// and would still 'pass', and this line is what would name it instead.
	TEST_ASSERT(ship.x > 0 && ship.y > 0, "the fixture hull's overmap token is at ([ship.x],[ship.y]) - it is not standing on the overmap, \
		so a travel contract has no position to measure against and this check would assert nothing.")

	// Park the marker away from the hull BEFORE accepting, so "not there yet" is a
	// fact rather than a coin flip on where the coords rolled.
	//
	// Read off the overmap token directly, NOT through leg.get_ship_coords(): that
	// helper resolves the ship as mission.servant, and start_mission() does not set
	// servant until the contract is ACCEPTED (_missions.dm:311). Asking the objective
	// here answers null - which is exactly what it did on run 6. The objective is the
	// right layer to ask AFTER the accept, and the wrong one before it.
	//
	// Only x is needed. Relative x IS absolute x on the overmap
	// (OVERMAP_LEFT_SIDE_COORD is 1); only the y axis carries an offset, and parking
	// far on one axis is far: sqrt(dx**2 + dy**2) >= |dx|, and dx here is 20+.
	// Literals 3 and 49 are MISSION_OVERMAP_MIN_COORD and MISSION_OVERMAP_MAX_COORD
	// (3 and OVERMAP_SIZE - 2, with OVERMAP_SIZE 51) from voidcrew/_DEFINES; 26 is
	// the midpoint, so whichever side the hull sits on, the marker goes to the other.
	job.target.target_x = (ship.x > 26) ? 3 : 49
	job.target.target_y = 26

	if(!accept_through_console(ship, console, crew, job))
		drop_contract(ship, job)
		return

	TEST_ASSERT(leg.active, "the travel objective did not arm on accept, so no ship movement will ever be measured against it")
	TEST_ASSERT(!leg.completed, "the travel objective completed at a marker parked [leg.get_distance_to_target()] tiles away")
	TEST_ASSERT(!job.can_complete(), "the contract was completable before the ship reached the coordinates")

	// Accepted, so the objective can answer for itself now.
	var/list/here = leg.get_ship_coords()
	if(isnull(here))
		TEST_FAIL("the travel objective could not read the ship's overmap coordinates even with the contract accepted. \
			get_ship_coords() resolves the hull as mission.servant, which start_mission() sets on accept, so a null here means the accept did not wire the servant.")
		drop_contract(ship, job)
		return

	// Arrive. Moving the marker onto the hull is the same measurement the helm
	// makes when the hull moves onto the marker - check_position() reads the gap
	// between the two - and it does not disturb a live overmap position.
	job.target.target_x = here[1]
	job.target.target_y = here[2]
	// "voidcrew_ship_moved" is COMSIG_VOIDCREW_SHIP_MOVED (voidcrew/_DEFINES/ship_defines.dm).
	SEND_SIGNAL(ship, "voidcrew_ship_moved")

	TEST_ASSERT(leg.completed, "the ship stands on the marked coordinates and the travel objective did not complete. \
		It listens on COMSIG_VOIDCREW_SHIP_MOVED and measures with get_distance_to_target(); a contract that never notices arrival ends only in its own timeout.")
	TEST_ASSERT(job.can_complete(), "the travel objective completed and the contract still refuses to complete")

	var/promised = job.value
	var/balance_before = ship.ship_account.account_balance
	if(!vc_ui_act(crew, console, "turn_in", list("ref" = REF(job))))
		drop_contract(ship, job)
		return
	TEST_ASSERT(QDELETED(job), "the exploration contract survived its turn-in")
	TEST_ASSERT_EQUAL(ship.ship_account.account_balance, balance_before + promised, "the exploration payout moved the balance by [ship.ship_account.account_balance - balance_before], not [promised]")

/**
 * The spawn half of the reward_amounts sentinel, plus the voucher channel.
 *
 * A shop SKU sells "plasteel (10 sheets)"; a contract paying that SKU without a
 * reward_amounts entry spawns the stack bare, and a bare stack is one sheet.
 * Both directions are asserted, because one sheet is the CORRECT answer when
 * there is no entry - the bug is the mismatch between what was advertised and
 * what landed on the pad, not the number itself.
 */
/datum/unit_test/voidcrew_mission_contract_lifecycle/proc/check_bundled_stack_payout(obj/structure/overmap/ship/ship, obj/machinery/computer/mission_board/console, obj/machinery/mission_pad/pad, mob/crew)
	var/turf/payout_turf = get_turf(pad)

	// A bare shell completes the moment it is accepted (no objectives to satisfy
	// and requires_item FALSE), which is exactly the harness this needs: the
	// subject is distribute_rewards(), not the objective chain.
	var/datum/mission/bundled = new()
	bundled.mission_rewards = list(/obj/item/stack/sheet/plasteel)
	bundled.reward_amounts = list(/obj/item/stack/sheet/plasteel = 10)
	bundled.voucher_count = 2
	if(!accept_through_console(ship, console, crew, bundled))
		drop_contract(ship, bundled)
		return
	TEST_ASSERT(bundled.can_complete(), "a shell with no objectives is not completable, so the payout path cannot be reached")
	if(!vc_ui_act(crew, console, "turn_in", list("ref" = REF(bundled))))
		drop_contract(ship, bundled)
		return

	var/obj/item/stack/sheet/plasteel/paid_bundle = locate() in payout_turf
	TEST_ASSERT_NOTNULL(paid_bundle, "a contract paying a bundled stack left nothing on the turn-in point")
	if(paid_bundle)
		TEST_ASSERT_EQUAL(paid_bundle.amount, 10, "a contract that advertised 10 sheets paid [paid_bundle.amount]. \
			Spawning a stack bare gets you the stack's own default of one; the reward_amounts entry is the only thing that carries the bundle size into distribute_rewards().")
		qdel(paid_bundle)

	var/obj/item/stack/trade_voucher/paid_vouchers = locate() in payout_turf
	TEST_ASSERT_NOTNULL(paid_vouchers, "a contract paying 2 trade vouchers left none on the turn-in point")
	if(paid_vouchers)
		TEST_ASSERT_EQUAL(paid_vouchers.amount, 2, "a 2-voucher contract paid [paid_vouchers.amount] voucher\s")
		qdel(paid_vouchers)

	// The other direction: no entry, one sheet, and no invented bundle.
	var/datum/mission/unbundled = new()
	unbundled.mission_rewards = list(/obj/item/stack/sheet/plasteel)
	if(!accept_through_console(ship, console, crew, unbundled))
		drop_contract(ship, unbundled)
		return
	if(!vc_ui_act(crew, console, "turn_in", list("ref" = REF(unbundled))))
		drop_contract(ship, unbundled)
		return

	var/obj/item/stack/sheet/plasteel/paid_single = locate() in payout_turf
	TEST_ASSERT_NOTNULL(paid_single, "a contract paying an unbundled stack left nothing on the turn-in point")
	if(paid_single)
		TEST_ASSERT_EQUAL(paid_single.amount, 1, "a stack reward with no reward_amounts entry paid [paid_single.amount] sheets. \
			Without the entry distribute_rewards() must spawn the stack's own default; inventing a bundle here would make the payout disagree with what get_reward_summary() told the crew.")
		qdel(paid_single)

/**
 * The per-type cap holds at accept time, not only where offers are generated -
 * and abandoning gives it back.
 *
 * The generation roll only counts LIVE missions, so a board can hold more copies
 * of a capped contract than the cap allows and N ships can each accept the same
 * "limit 1" job. /datum/unit_test/voidcrew_mission_type_limit asserts the helper;
 * this asserts the path a player actually takes through it.
 */
/datum/unit_test/voidcrew_mission_contract_lifecycle/proc/check_type_limit_through_accept(obj/structure/overmap/ship/ship, obj/machinery/computer/mission_board/console, mob/crew)
	// The mission_limit = 1 fixture defined by voidcrew_missions.dm. weight 0
	// keeps it out of SSmissions' pool, so nothing else in the round can be
	// holding its single slot.
	var/datum/mission/unit_test_capped/held = new()
	var/datum/mission/unit_test_capped/refused = new()

	if(!accept_through_console(ship, console, crew, held))
		drop_contract(ship, held)
		drop_contract(ship, refused)
		return

	ship.available_missions |= refused
	TEST_ASSERT_EQUAL(ship.accept_mission(refused), "Contract limit reached for this type.", "accept_mission() let a second copy of a limit-1 contract through, or refused it for a different reason. \
		The board can hold more copies than the cap allows, so this is the gate that decides whether two crews can run the same capped job at once.")

	vc_ui_act(crew, console, "accept", list("ref" = REF(refused)))
	TEST_ASSERT(!refused.active, "the console accepted a second copy of a limit-1 contract")
	TEST_ASSERT(refused in ship.available_missions, "a refused contract was taken off the board anyway, so the offer is lost without ever being run")
	TEST_ASSERT(held in ship.active_missions, "the contract that was accepted is not among the ship's active contracts")
	TEST_ASSERT(!(refused in ship.active_missions), "the refused second copy of a limit-1 contract is running on the ship anyway")

	// Abandoning hands the slot back. give_up() is the no-penalty exit: the
	// contract is dropped, not failed.
	if(!vc_ui_act(crew, console, "abandon", list("ref" = REF(held))))
		drop_contract(ship, held)
		drop_contract(ship, refused)
		return
	TEST_ASSERT(QDELETED(held), "an abandoned contract survived; give_up() ends in qdel(src)")
	TEST_ASSERT(!(held in ship.active_missions), "an abandoned contract is still listed on the ship")
	TEST_ASSERT(!(held in SSmissions.all_active_missions), "an abandoned contract is still tracked by SSmissions, so its cap stays spent for the rest of the round")

	TEST_ASSERT(accept_through_console(ship, console, crew, refused), "the capped slot did not free up after the contract holding it was abandoned")
	vc_ui_act(crew, console, "abandon", list("ref" = REF(refused)))
	drop_contract(ship, refused)

/**
 * One subsystem tick over a ship holding a live contract: no runtimes, the
 * backstop sweep collects what Destroy() could not, and the timeout clock is
 * still counting down afterwards.
 *
 * The sweep walks its list BACKWARDS on purpose. Removing from a list
 * mid-iteration shifts every later element down one, so the forward form
 * silently skipped the entry after each removal - which is why the two dead
 * entries this plants are ADJACENT.
 */
/datum/unit_test/voidcrew_mission_contract_lifecycle/proc/check_ssmissions_tick(obj/structure/overmap/ship/ship, obj/machinery/computer/mission_board/console, mob/crew)
	var/datum/mission/delivery/live = new()
	if(live.generation_failed)
		TEST_FAIL("could not generate the live contract this check ticks over")
		qdel(live)
		return
	if(!accept_through_console(ship, console, crew, live))
		drop_contract(ship, live)
		return

	var/remaining_before = live.get_time_remaining()
	TEST_ASSERT(remaining_before > 0, "a freshly accepted contract reports [remaining_before] deciseconds left")
	TEST_ASSERT(remaining_before <= live.duration, "a freshly accepted contract reports [remaining_before] deciseconds left against a duration of [live.duration]")

	// Empty the board so "the fire refilled it" is an observation, not a guess
	// about what the background subsystem already did.
	for(var/datum/mission/offer as anything in ship.available_missions)
		if(!QDELETED(offer))
			qdel(offer)
	ship.available_missions.Cut()

	// Two adjacent entries that Destroy() never got to take out of the list. This
	// is the exact leak the sweep is a backstop for: anything deleted OUTSIDE
	// Destroy() leaves a hard reference to a dead datum behind.
	var/datum/mission/dead_one = new()
	var/datum/mission/dead_two = new()
	qdel(dead_one)
	qdel(dead_two)
	SSmissions.all_active_missions += dead_one
	SSmissions.all_active_missions += dead_two
	// The window spans a whole fire(), which visits EVERY ship in
	// SSovermap.simulated_ships and refreshes its board - deliberately, because
	// that is the tick this is asserting, but it does mean an unrelated hull's
	// mission generation runtiming lands here too. Named so the next reader knows.
	var/snapshot = vc_runtime_snapshot()
	SSmissions.fire()
	vc_assert_no_new_runtimes(snapshot, "one SSmissions.fire() with two dead entries planted in its tracking list - the sweep plus a board refresh for every simulated ship in the world")

	TEST_ASSERT(!(dead_one in SSmissions.all_active_missions), "the backstop sweep left a deleted mission in SSmissions.all_active_missions")
	TEST_ASSERT(!(dead_two in SSmissions.all_active_missions), "the backstop sweep collected the first of two ADJACENT dead entries and left the second. \
		That is the forward-iteration bug the backwards walk exists for: each removal shifts every later element down one, so the entry after a removal is skipped.")
	TEST_ASSERT(live in SSmissions.all_active_missions, "the backstop sweep collected a LIVE contract")
	// The sweep's whole contract, stated directly. An exact length would be a
	// flake: fire() yields on CHECK_TICK, so an unrelated contract's 30-minute
	// timeout can land inside the window and legitimately take itself out.
	for(var/i in 1 to length(SSmissions.all_active_missions))
		if(QDELETED(SSmissions.all_active_missions[i]))
			TEST_FAIL("the backstop sweep finished with a deleted mission still at index [i] of [length(SSmissions.all_active_missions)]. \
				Those entries hold a hard reference to a dead datum, and this sweep is the only thing in the game that collects them.")
			break

	// Literal 5 = DEFAULT_AVAILABLE_MISSIONS (voidcrew/_DEFINES/missions.dm).
	TEST_ASSERT(length(ship.available_missions) > 0, "one SSmissions fire over a ship with an empty board generated no offers at all. \
		Several rollable types (delivery, survey, suppression, telemetry) roll off static tables and cannot fail generation, so an empty board means the fill itself did not run.")
	TEST_ASSERT(length(ship.available_missions) <= 5, "the board refilled to [length(ship.available_missions)] offers, over the DEFAULT_AVAILABLE_MISSIONS ceiling of 5")
	for(var/datum/mission/offer as anything in ship.available_missions)
		if(QDELETED(offer))
			TEST_FAIL("the refilled board holds a deleted offer")

	var/remaining_after = live.get_time_remaining()
	TEST_ASSERT(remaining_after > 0, "the live contract's timeout ran out across one subsystem tick")
	TEST_ASSERT(remaining_after <= remaining_before, "the live contract's timeout went UP across a tick, from [remaining_before] to [remaining_after]")
	TEST_ASSERT(!live.failed && !live.completed, "one SSmissions tick failed or completed a live contract by itself")

	vc_ui_act(crew, console, "abandon", list("ref" = REF(live)))
	drop_contract(ship, live)

/**
 * # Coverage boundaries
 *
 * What this file does NOT assert, so the next reader does not mistake green for
 * covered:
 *
 *  - **Field objectives place nothing here.** Twenty-two of the twenty-six
 *    contract types end in a `/datum/mission_objective/field` step, which waits
 *    on its target's interior-loaded signal. No site interior is loaded in the
 *    test world, so those contracts are covered structurally (generation, the
 *    reward-configuration sweep, the shell's sequencing) and never driven to
 *    completion. Doing it honestly needs `spawn_dynamic_encounter()` per
 *    contract - a real map load each, on top of the hull this file already
 *    builds. `/datum/unit_test/voidcrew_mission_field_spawn_bounds` covers the
 *    one piece of that machinery that can be reached without a load: where the
 *    spawn would land.
 *  - **Shop-authored contracts** (`outpost_supply` and its two subtypes,
 *    `recovery/outpost`, `recovery/kill/outpost`, `outpost_courier`) take their
 *    entire settlement from `/datum/outpost_shop/roll_contract_reward()`, which
 *    is also the only writer of `reward_amounts` in the tree. That roll belongs
 *    to the trade module and is asserted from neither side today.
 *  - **`/datum/mission/drug_run`** needs three distinct planet biomes present
 *    and a pinned ingredient site per ingredient; it is swept structurally and
 *    nothing more.
 *  - **The GPS beacon channel** (`link_gps_unit()`, `add_gps_beacon()`, the
 *    `/datum/component/gps/item` re-open) is untested. A beacon only points at
 *    something once a field objective has placed its mark, which is the same
 *    wall as the first item.
 *  - **Mission pad wiring to the hull** (`connect_to_shuttle`, the roundstart
 *    `COMSIG_VOIDCREW_SHIP_LOADED` link) is covered by the ship-lifecycle tests;
 *    the pad here is built by hand on a deck tile and is a turn-in anchor, not
 *    the subject.
 *  - **Timeout expiry** is asserted only as "the clock is still counting".
 *    Driving `on_timeout()` for real means waiting out a 30-minute timer or
 *    calling the handler directly, which asserts nothing the `fail()` path in
 *    `/datum/unit_test/voidcrew_mission_quest_loss_policy` does not already
 *    assert.
 */
