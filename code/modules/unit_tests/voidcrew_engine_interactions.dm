/**
 * # Shuttle propulsion hardware: the tool chain, the panel sprite and the thrust math
 *
 * Everything in this file exists because of one upstream pull: tg #95408 (4eadf5caf74),
 * the "tooltype re-signing" pass. It changed two contracts at once and the fork's four
 * propulsion machines - the thruster, the engine heater, the nebula ram scoop and the
 * plasma sublimation chamber - were written against the old ones:
 *
 *  1. **`default_deconstruction_screwdriver()` stopped painting the sprite.** It used to
 *     be handed the open and closed icon states as arguments and set `icon_state` itself.
 *     Now it only flips `panel_open` and leaves the repaint to the appearance pass, so a
 *     machine with no `update_icon_state()` / `update_icon_nopipes()` override silently
 *     lost its maintenance-panel sprite. The three atmos devices had none. The panel
 *     opened, the machine stopped working, and it looked exactly the same as before.
 *  2. **A falsy `*_act()` return is "unhandled", not "refused".** `/atom/tool_act`
 *     (atom_tool_acts.dm:120-122) reads `if(!act_result) return NONE`, and
 *     `base_item_interaction` then walks on to `item_interaction`, `interact_with_atom`
 *     and finally `attackby` -> `attack_atom`. Every override that ended in a bare
 *     `return`, `return FALSE` or an un-returned `if` therefore converted a *refusal*
 *     into a *swing*: "open panel first!" printed, and then the tool hit the machine.
 *
 * Two more breaks rode along in the same repair pass and are pinned here too:
 *
 *  3. **`default_pry_open()` went live on the heater.** The call was always in
 *     `crowbar_act()`, but on the old arity it runtimed before doing anything, so it was
 *     inert. Fixing the arity armed it: `can_crowbar_pry_open()` is
 *     `!state_open && !panel_open && !is_operational`, which is precisely the state of an
 *     **unpowered** heater with its panel shut - so one crowbar tap on a heater in a
 *     browned-out engine room dumped the fuel tank on the deck and left the heater
 *     permanently non-dense. The fix removes the call outright. That is a judgment call,
 *     so the test asserts the *state* (tank still inside, still dense, never opened)
 *     rather than the absence of a proc call.
 *  4. **`attackby()`'s arity changed to 4** and the heater's tank-insert branch fell off
 *     the end with a bare `return`. A falsy `attackby` return is read as "the attack was
 *     unhandled" by `melee_attack_chain` (item_attack.dm:73-75), so the tank went into
 *     the heater *and then hit it*.
 *
 * ## Why these are click tests and not staged-state tests
 *
 * Every one of the four breaks lives in the *dispatch*, not in the body. `tool_act`
 * choosing to walk on, `base_item_interaction` skipping `tool_act` in combat mode, the
 * appearance pass not being reached - none of it happens if a test calls the handler
 * directly. So the behavioural tests below enter at `ClickOn` through the
 * `vc_click_with_item()` fixture, which is the player's path.
 *
 * The one deliberate exception is `voidcrew_engine_tool_act_returns`, whose entire claim
 * *is* the return value. `tool_act` swallows it, so that one calls the overrides directly
 * and asserts on what they hand back. Both halves are needed: the sentinel catches a
 * refusal that returns FALSE even where the resulting bash does no visible damage, and
 * the click tests catch a return that is technically valid but reaches the wrong body.
 *
 * ## Notes for the next reader
 *
 * - Unit tests compile at `code/modules/unit_tests` (tgstation.dme:6898), which is *ahead*
 *   of `voidcrew/_DEFINES/` (7189+). No fork define is usable in here. `REFERENCE_SHIP_MASS`
 *   is fine - it is declared in `code/game/shuttle_engines.dm` (dme:2365) and never undef'd -
 *   but the tests below still avoid it by letting `burn_engine()` take its own defaults.
 * - The test room is a 5x5 open floor (x..x+4, y..y+4 from `run_loc_floor_bottom_left`),
 *   walled in by indestructible turfs. `bench()` hands out one tile at a time so two dense
 *   machines never share a turf.
 * - `/area/misc/testroom` is `requires_power = FALSE`, so an allocated machine is powered
 *   and `is_operational`. Where a break needed an *unpowered* machine (item 3 above) the
 *   test says so and sets `NOPOWER` through `set_machine_stat()`, which is the only way to
 *   move `is_operational` - the var is maintained by `on_set_machine_stat()`, not derived.
 */

/datum/unit_test/voidcrew_engine_interaction
	abstract_type = /datum/unit_test/voidcrew_engine_interaction
	/// How many tiles of the 5x5 test floor have been handed out by bench().
	var/benches_taken = 0

/**
 * Hands out the next free tile of the test room's 5x5 floor.
 *
 * Two dense machines on one turf is not a hard error, but the heater's
 * `update_adjacent_engines()` and the thruster's `set_heater()` both scan neighbouring
 * tiles, and a test that stacked its fixtures would couple machines that were never meant
 * to see each other. One tile each, allocated left to right and bottom to top.
 */
/datum/unit_test/voidcrew_engine_interaction/proc/bench()
	var/turf/origin = run_loc_floor_bottom_left
	var/turf/spot = locate(origin.x + (benches_taken % 5), origin.y + round(benches_taken / 5), origin.z)
	benches_taken++
	if(isnull(spot))
		TEST_FAIL("the test room ran out of floor at bench [benches_taken - 1] - the 5x5 assumption in this file's header is wrong")
	return spot

/**
 * Every propulsion machine that carries a fork tool override, with the icon_state its
 * maintenance panel is supposed to paint.
 *
 * Hand-written rather than derived, on purpose: the point of the table is that a fifth
 * machine added later is *not* silently covered. The count is asserted, so adding one
 * without adding it here fails loudly instead of shipping untested.
 */
/datum/unit_test/voidcrew_engine_interaction/proc/panel_sprite_table()
	return list(
		/obj/machinery/power/shuttle_engine/ship/fueled/plasma = "burst_plasma_open",
		/obj/machinery/atmospherics/components/unary/shuttle/heater = "heater_pipe_open",
		/obj/machinery/atmospherics/components/unary/shuttle/scoop = "scoop_open",
		/obj/machinery/atmospherics/components/unary/shuttle/sublimator = "sublimator_open",
	)

// ===========================================================================
// 1. The maintenance panel sprite (upstream #95408, half one)
// ===========================================================================

/**
 * A screwdriver on a propulsion machine flips the panel **and repaints the sprite**.
 *
 * Only the icon assertion catches the shipped break. `panel_open` flipped correctly the
 * whole time - `default_deconstruction_screwdriver()` still calls `toggle_panel_open()` -
 * so a test that asserted the flag alone passed on a tree where the heater, the scoop and
 * the sublimator all looked shut with their guts hanging out.
 *
 * The atmos three route their appearance through `update_icon_nopipes()`, which
 * `/obj/machinery/atmospherics/components/update_icon()` always calls (components_base.dm:68).
 * An `update_icon_state()` override would have been skipped on the underfloor branch, which
 * is why the fix lives where it does; this test only cares that the state on screen changed.
 */
/datum/unit_test/voidcrew_engine_interaction/panel_sprite

/datum/unit_test/voidcrew_engine_interaction/panel_sprite/Run()
	var/mob/living/carbon/human/consistent/mechanic = allocate(/mob/living/carbon/human/consistent)
	var/obj/item/screwdriver/driver = allocate(/obj/item/screwdriver)

	var/list/expected_states = panel_sprite_table()
	TEST_ASSERT_EQUAL(length(expected_states), 4, "the propulsion panel-sprite table no longer covers four machines - a machine was added or removed without updating this test")

	for(var/machine_type in expected_states)
		var/obj/machinery/machine = allocate(machine_type, bench())
		TEST_ASSERT(!machine.panel_open, "[machine_type] did not start with its maintenance panel shut, so this test would measure the closing swing instead of the opening one")

		var/shut_state = machine.icon_state
		var/open_state = expected_states[machine_type]
		TEST_ASSERT_NOTEQUAL(shut_state, open_state, "[machine_type]'s shut icon_state is already \"[open_state]\", so an open/shut sprite swap would be invisible to this test")

		if(!vc_click_with_item(mechanic, machine, driver))
			return

		TEST_ASSERT(machine.panel_open, "a screwdriver click on [machine_type] did not open its maintenance panel at all - default_deconstruction_screwdriver() was never reached")
		TEST_ASSERT_EQUAL(machine.icon_state, open_state, "[machine_type]'s panel is open but its icon_state is still \"[machine.icon_state]\". Upstream #95408 moved the sprite swap out of \
			default_deconstruction_screwdriver() and into the appearance pass, so a machine with no update_icon_nopipes()/update_icon_state() override opens its panel invisibly.")

		// And back, because the closed half is a separate branch of the same override and
		// a machine that can only ever look open is just as broken.
		if(!vc_click_with_item(mechanic, machine, driver))
			return

		TEST_ASSERT(!machine.panel_open, "a second screwdriver click on [machine_type] did not shut its maintenance panel")
		TEST_ASSERT_EQUAL(machine.icon_state, shut_state, "[machine_type]'s panel is shut again but its icon_state is stuck on \"[machine.icon_state]\" instead of \"[shut_state]\"")

// ===========================================================================
// 2. A crowbar on a shut panel changes nothing (upstream #95408, halves two and three)
// ===========================================================================

/**
 * Crowbarring a propulsion machine whose panel is shut leaves it exactly as it was.
 *
 * This is the shape of the worst of the four breaks. `default_pry_open()` was inert on the
 * old arity and became live when the arity was fixed, and its gate -
 * `!state_open && !panel_open && !is_operational` (_machinery.dm:853-855) - describes an
 * unpowered heater with its panel shut. Prying one open ran `open_machine(density_to_set = FALSE)`:
 * the fuel tank was dumped on the floor and the heater was left permanently non-dense, with
 * no state_open sprite and no way back to closed. A ship whose engine room browned out lost
 * its thrust to a single crowbar tap and nobody could see why.
 *
 * The heater is therefore driven **unpowered**, because a powered one never reproduces:
 * `can_crowbar_pry_open()` is false while `is_operational` holds, and the test room's area
 * is `requires_power = FALSE`.
 *
 * The thruster is in the same test for the *other* half - its `crowbar_act()` returned bare
 * `FALSE` on a shut panel, which `tool_act` reads as "unhandled" and walks past into the
 * attack chain. Note that the thruster's own integrity assertion is weak on that point and
 * deliberately kept anyway: `/datum/armor/power_shuttle_engine` is `melee = 100`, so the
 * fall-through bash it used to take did zero damage. `voidcrew_engine_tool_act_returns`
 * below is what actually pins the thruster's return value; this assertion is here so that
 * the day somebody lowers that armour, the fall-through is caught by behaviour too.
 */
/datum/unit_test/voidcrew_engine_interaction/closed_panel_crowbar

/datum/unit_test/voidcrew_engine_interaction/closed_panel_crowbar/Run()
	var/mob/living/carbon/human/consistent/mechanic = allocate(/mob/living/carbon/human/consistent)
	var/obj/item/crowbar/pry_bar = allocate(/obj/item/crowbar)

	// --- the heater, with a fuel tank in it and no power, which is the shipped incident ---
	var/obj/machinery/atmospherics/components/unary/shuttle/heater/heater = allocate(/obj/machinery/atmospherics/components/unary/shuttle/heater, bench())
	var/obj/item/tank/internals/plasma/full/fuel = allocate(/obj/item/tank/internals/plasma/full, get_turf(heater))
	fuel.forceMove(heater)
	heater.fuel_tank = fuel

	// The break needs an unpowered machine. machine_stat has to be set through
	// set_machine_stat(): is_operational is a plain var kept in step by on_set_machine_stat(),
	// so poking machine_stat directly would leave the machine "operational" and the gate shut.
	heater.set_machine_stat(heater.machine_stat | NOPOWER)
	TEST_ASSERT(!heater.is_operational, "the heater is still operational after NOPOWER was set, so can_crowbar_pry_open() cannot open and this test would pass vacuously")
	TEST_ASSERT(!heater.panel_open, "the heater's panel is open, so the crowbar would deconstruct it instead of exercising the pry-open branch")

	var/heater_integrity = heater.get_integrity()
	if(!vc_click_with_item(mechanic, heater, pry_bar))
		return

	TEST_ASSERT(!QDELETED(heater), "a crowbar on a shut, unpowered heater destroyed it")
	TEST_ASSERT_EQUAL(heater.fuel_tank, fuel, "a crowbar on a shut, unpowered heater lost its fuel tank (fuel_tank is now [heater.fuel_tank || "null"]). default_pry_open() -> open_machine() dumps the tank on the deck; \
		the heater has no state_open sprite and no way back, so this is how a ship's thrust got bricked by one crowbar tap.")
	TEST_ASSERT_EQUAL(fuel.loc, heater, "the heater's fuel tank was dumped out of it by a crowbar and is now sitting on [fuel.loc || "nothing"]")
	TEST_ASSERT(heater.density, "a crowbar on a shut, unpowered heater left it non-dense - open_machine(density_to_set = FALSE) ran, and nothing in the heater's code can ever close it again")
	TEST_ASSERT(!heater.state_open, "a crowbar on a shut, unpowered heater put it into state_open, which this machine has no sprite for and no way out of")
	TEST_ASSERT_EQUAL(heater.get_integrity(), heater_integrity, "a crowbar on a shut heater damaged it - the refusal returned a falsy value, tool_act read that as \"unhandled\" and the swing carried on into the attack chain")

	// --- the scoop and the sublimator, same family, same removed default_pry_open ---
	for(var/machine_type in list(/obj/machinery/atmospherics/components/unary/shuttle/scoop, /obj/machinery/atmospherics/components/unary/shuttle/sublimator))
		var/obj/machinery/machine = allocate(machine_type, bench())
		machine.set_machine_stat(machine.machine_stat | NOPOWER)
		var/starting_integrity = machine.get_integrity()

		if(!vc_click_with_item(mechanic, machine, pry_bar))
			return

		TEST_ASSERT(!QDELETED(machine), "a crowbar on a shut, unpowered [machine_type] destroyed it")
		TEST_ASSERT(machine.density, "a crowbar on a shut, unpowered [machine_type] left it non-dense via open_machine()")
		TEST_ASSERT(!machine.state_open, "a crowbar on a shut, unpowered [machine_type] put it into state_open, which it has no sprite for")
		TEST_ASSERT_EQUAL(machine.get_integrity(), starting_integrity, "a crowbar on a shut [machine_type] damaged it - the refusal fell through tool_act into the attack chain")

	// --- the thruster: refusal must not become a swing ---
	var/obj/machinery/power/shuttle_engine/ship/fueled/plasma/thruster = allocate(/obj/machinery/power/shuttle_engine/ship/fueled/plasma, bench())
	var/thruster_integrity = thruster.get_integrity()

	if(!vc_click_with_item(mechanic, thruster, pry_bar))
		return

	TEST_ASSERT(!QDELETED(thruster), "a crowbar on a shut-panel thruster destroyed it")
	TEST_ASSERT(!thruster.panel_open, "a crowbar opened the thruster's maintenance panel, which is the screwdriver's job")
	TEST_ASSERT_EQUAL(thruster.get_integrity(), thruster_integrity, "a crowbar on a shut-panel thruster damaged it. See this test's doc comment: /datum/armor/power_shuttle_engine is melee = 100, \
		so this assertion only bites if that armour is ever lowered - voidcrew_engine_tool_act_returns is what pins the return value itself.")

// ===========================================================================
// 3. The return-value sentinel (upstream #95408, half two, stated as a contract)
// ===========================================================================

/**
 * Every fork tool override on the propulsion machines returns a real ITEM_INTERACT flag.
 *
 * `tool_act` throws the value away (`if(!act_result) return NONE`), so no behavioural test
 * can see the difference between "refused" and "returned FALSE" on a machine that happens
 * to shrug off the resulting bash - which is exactly the thruster's situation, with
 * `melee = 100` armour. This test calls the overrides directly and asserts the contract:
 * the answer is always inside `ITEM_INTERACT_ANY_BLOCKER`, never `FALSE`, `0` or `null`.
 *
 * Every call below is made with the maintenance panel **shut**, which is the non-destructive
 * state for all four tools:
 *   - screwdriver: always handled; called twice so the panel ends as it started.
 *   - crowbar: `can_crowbar_deconstruct()` is `panel_open`, so nothing is deconstructed.
 *   - wrench / wrench-secondary: every override refuses with "open panel first!" before it
 *     can unbolt or rotate anything.
 *
 * One honest mismatch, flagged rather than papered over: the three atmos machines answer a
 * shut-panel crowbar with ITEM_INTERACT_SUCCESS rather than BLOCKING, because
 * `default_deconstruction_crowbar()` returns ITEM_INTERACT_BLOCKING (2) on refusal and the
 * override tests it with a bare `if()`, which 2 passes. It is a pre-existing wart on the
 * *flavour* of the answer, not on the contract this test is about - the click is still
 * consumed and nothing is bashed - so the assertion is on the contract and this comment is
 * the record. Tightening the `if()` to `& ITEM_INTERACT_SUCCESS` would be the fix.
 */
/datum/unit_test/voidcrew_engine_interaction/tool_act_returns

/// Asserts one `*_act()` return is a real handled-flag. Returns TRUE when it is.
/datum/unit_test/voidcrew_engine_interaction/tool_act_returns/proc/assert_handled(result, what)
	if(result & ITEM_INTERACT_ANY_BLOCKER)
		return TRUE
	TEST_FAIL("[what] returned [isnull(result) ? "null" : result], which tool_act reads as \"unhandled\" (atom_tool_acts.dm:120-122). base_item_interaction then walks on to item_interaction, \
		interact_with_atom and finally attackby, so the refusal becomes a swing at the machine. It must return ITEM_INTERACT_SUCCESS or ITEM_INTERACT_BLOCKING.")
	return FALSE

/datum/unit_test/voidcrew_engine_interaction/tool_act_returns/Run()
	var/mob/living/carbon/human/consistent/mechanic = allocate(/mob/living/carbon/human/consistent)
	var/obj/item/screwdriver/driver = allocate(/obj/item/screwdriver)
	var/obj/item/crowbar/pry_bar = allocate(/obj/item/crowbar)
	var/obj/item/wrench/spanner = allocate(/obj/item/wrench)

	// --- thruster: screwdriver_act and crowbar_act (shuttle_engine.dm:202-220) ---
	var/obj/machinery/power/shuttle_engine/ship/fueled/plasma/thruster = allocate(/obj/machinery/power/shuttle_engine/ship/fueled/plasma, bench())
	if(!assert_handled(thruster.screwdriver_act(mechanic, driver), "the thruster's screwdriver_act()"))
		return
	if(!assert_handled(thruster.screwdriver_act(mechanic, driver), "the thruster's screwdriver_act() closing the panel again"))
		return
	TEST_ASSERT(!thruster.panel_open, "the thruster's panel did not return to shut after two screwdriver_act() calls, so the crowbar call below would deconstruct it")
	if(!assert_handled(thruster.crowbar_act(mechanic, pry_bar), "the thruster's crowbar_act() on a shut panel"))
		return

	// --- heater: screwdriver, wrench, wrench-secondary, crowbar (shuttle_heater.dm:208-240) ---
	var/obj/machinery/atmospherics/components/unary/shuttle/heater/heater = allocate(/obj/machinery/atmospherics/components/unary/shuttle/heater, bench())
	if(!assert_handled(heater.screwdriver_act(mechanic, driver), "the heater's screwdriver_act()"))
		return
	if(!assert_handled(heater.screwdriver_act(mechanic, driver), "the heater's screwdriver_act() closing the panel again"))
		return
	TEST_ASSERT(!heater.panel_open, "the heater's panel did not return to shut after two screwdriver_act() calls")
	if(!assert_handled(heater.wrench_act(mechanic, spanner), "the heater's wrench_act() on a shut panel"))
		return
	if(!assert_handled(heater.wrench_act_secondary(mechanic, spanner), "the heater's wrench_act_secondary() on a shut panel"))
		return
	if(!assert_handled(heater.crowbar_act(mechanic, pry_bar), "the heater's crowbar_act() on a shut panel"))
		return
	TEST_ASSERT(heater.anchored, "a shut-panel wrench unbolted the heater - the \"open panel first!\" refusal is supposed to run before default_unfasten_wrench()")

	// --- scoop and sublimator: screwdriver, wrench, crowbar (gas_harvest.dm) ---
	for(var/machine_type in list(/obj/machinery/atmospherics/components/unary/shuttle/scoop, /obj/machinery/atmospherics/components/unary/shuttle/sublimator))
		var/obj/machinery/atmospherics/components/unary/shuttle/machine = allocate(machine_type, bench())
		if(!assert_handled(machine.screwdriver_act(mechanic, driver), "[machine_type]'s screwdriver_act()"))
			return
		if(!assert_handled(machine.screwdriver_act(mechanic, driver), "[machine_type]'s screwdriver_act() closing the panel again"))
			return
		TEST_ASSERT(!machine.panel_open, "[machine_type]'s panel did not return to shut after two screwdriver_act() calls")
		if(!assert_handled(machine.wrench_act(mechanic, spanner), "[machine_type]'s wrench_act() on a shut panel"))
			return
		if(!assert_handled(machine.wrench_act_secondary(mechanic, spanner), "[machine_type]'s wrench_act_secondary() on a shut panel (the shared /shuttle override)"))
			return
		if(!assert_handled(machine.crowbar_act(mechanic, pry_bar), "[machine_type]'s crowbar_act() on a shut panel"))
			return
		TEST_ASSERT(machine.anchored, "a shut-panel wrench unbolted [machine_type]")

// ===========================================================================
// 4. Thrust math end to end
// ===========================================================================

/**
 * A fuelled thruster produces its rated thrust; an unfuelled one produces nothing and says why.
 *
 * `burn_engine()` is the whole propulsion contract in nine lines (fuel.dm:24-38): resolve the
 * heater, scale the fuel draw by burn percentage, ship mass and burn seconds, ask the heater
 * to give up that many moles, and return `(burned / wanted) * engine_power`. Nothing else in
 * the fork tests any of it, and the tooltype repair pass sat directly on top of the two
 * machines it runs through.
 *
 * Driven with `burn_engine()`'s own defaults - 100% of the burn, `REFERENCE_SHIP_MASS`,
 * one second - so `get_mass_fuel_multiplier()` is exactly 1 and the arithmetic is
 * `fuel_use` moles in, `engine_power` thrust out, with no floating point slack. The
 * assertions read the machines' own vars rather than the literals 20 and 25 so a retune of
 * the plasma thruster does not turn into a red test.
 *
 * The fuel goes straight into the heater's `airs[1]` (pipe mode, the heater's default), which
 * is the same mixture `consume_fuel()` reads. No atmos tick is involved and nothing is
 * waited on: `process_atmos()` in pipe mode only calls `update_parents()`, and the burn does
 * not go through it.
 */
/datum/unit_test/voidcrew_engine_interaction/burn_thrust

/datum/unit_test/voidcrew_engine_interaction/burn_thrust/Run()
	// bench() hands out the 5x5 floor left to right, so these two are cardinally adjacent -
	// which is what set_heater() needs. Both tiles are reserved so nothing else lands on them.
	var/turf/heater_tile = bench()
	var/turf/thruster_tile = bench()
	TEST_ASSERT_EQUAL(get_dist(heater_tile, thruster_tile), 1, "the two benched tiles are not adjacent, so set_heater() could never find the heater from the thruster")

	var/obj/machinery/atmospherics/components/unary/shuttle/heater/heater = allocate(/obj/machinery/atmospherics/components/unary/shuttle/heater, heater_tile)
	// set_heater() wants the heater on an adjacent cardinal tile, facing the same way as the
	// thruster, bolted down, panel shut. Both spawn facing SOUTH, so only the tile matters.
	var/obj/machinery/power/shuttle_engine/ship/fueled/plasma/thruster = allocate(/obj/machinery/power/shuttle_engine/ship/fueled/plasma, thruster_tile)

	TEST_ASSERT(heater.anchored, "the engine heater is not anchored, and set_heater() skips unanchored heaters - the thruster would never latch onto it")
	TEST_ASSERT(!heater.panel_open, "the engine heater's panel is open, and set_heater() skips open heaters")
	TEST_ASSERT_EQUAL(heater.dir, thruster.dir, "the heater and the thruster are not facing the same way, and set_heater() requires it")
	TEST_ASSERT(!heater.use_tank, "the heater is in tank mode, but this test loads the pipe-side mixture - consume_fuel() would read the tank instead")

	// A never-burned thruster has not gone looking for its heater yet; update_engine() is the
	// proc the helm and the burn both go through to do that.
	thruster.update_engine()
	TEST_ASSERT_NOTNULL(thruster.attached_heater?.resolve(), "the thruster did not latch onto the adjacent heater. set_heater() (fuel.dm:100-112) walks the four cardinals for a heater \
		facing the same way, anchored, with its panel shut - one of those is not true here.")

	var/datum/gas_mixture/fuel_side = heater.airs[1]
	TEST_ASSERT_NOTNULL(fuel_side, "the heater has no airs\[1\] gas mixture, so there is nowhere to put fuel")

	// --- unfuelled first, so the "no fuel" branch is not measured against a stale latch ---
	TEST_ASSERT_EQUAL(heater.return_gas(/datum/gas/plasma), 0, "the heater started with plasma already in its pipe-side mixture, so the unfuelled case is not testable")
	TEST_ASSERT_EQUAL(thruster.burn_engine(), 0, "an unfuelled thruster returned thrust. consume_fuel() had nothing to give, and burn_engine() must return 0 rather than a share of engine_power.")

	var/refusal = thruster.thrust_refusal_reason()
	TEST_ASSERT_NOTNULL(refusal, "an unfuelled thruster gave no thrust_refusal_reason(), so the helm has nothing to tell the crew")
	TEST_ASSERT(findtext(refusal, "fuel"), "an unfuelled thruster's refusal reason does not mention fuel: \"[refusal]\"")

	// --- fuelled ---
	var/wanted = thruster.fuel_use
	var/loaded = wanted * 5
	fuel_side.assert_gas(/datum/gas/plasma)
	fuel_side.moles[/datum/gas/plasma] = loaded
	TEST_ASSERT_EQUAL(heater.return_gas(/datum/gas/plasma), loaded, "the heater's gas dial does not read the plasma that was just loaded into airs\[1\]")

	var/thrust = thruster.burn_engine()
	TEST_ASSERT_EQUAL(thrust, thruster.engine_power, "a fully fuelled thruster returned [thrust] thrust instead of its rated engine_power ([thruster.engine_power]). \
		burn_engine() scales engine_power by (moles actually burned / moles wanted), and with [loaded] moles in the heater and [wanted] wanted, that ratio has to be exactly 1.")
	TEST_ASSERT_EQUAL(heater.return_gas(/datum/gas/plasma), loaded - wanted, "a full burn drew [loaded - heater.return_gas(/datum/gas/plasma)] moles of plasma out of the heater instead of [wanted]")
	TEST_ASSERT_NULL(thruster.thrust_refusal_reason(), "a fuelled, latched thruster still names a reason it cannot produce thrust: \"[thruster.thrust_refusal_reason()]\"")

	// --- and with the heater gone entirely ---
	var/obj/machinery/power/shuttle_engine/ship/fueled/plasma/orphan = allocate(/obj/machinery/power/shuttle_engine/ship/fueled/plasma, bench())
	TEST_ASSERT_EQUAL(orphan.burn_engine(), 0, "a thruster with no heater at all returned thrust")
	TEST_ASSERT_NOTNULL(orphan.thrust_refusal_reason(), "a thruster with no heater gave no reason for producing nothing")

// ===========================================================================
// 5. The heater's fuel tank, both combat modes (upstream #95408, half four)
// ===========================================================================

/**
 * Feeding the heater a gas tank works in **both** combat modes, and does not hit it.
 *
 * Two things are being pinned. First, the hook: `attackby()`'s signature changed to
 * `(tool, user, list/modifiers, list/attack_modifiers)`, and the atmos family grew an
 * `item_interaction` of its own that could have claimed the click first. It does not - it
 * declines anything that is not a pipe - and a gas tank has no `interact_with_atom`, so the
 * insert still lands in `attackby` on both the combat-mode-off path (via a no-op `tool_act`,
 * since a tank has no `tool_behaviour`) and the combat-mode-on path, where `tool_act` is
 * skipped entirely. Both are driven here because they are genuinely different routes through
 * `base_item_interaction`.
 *
 * Second, the return: the insert branch used to end in a bare `return`.
 * `melee_attack_chain` reads a falsy `attackby` as "unhandled" (item_attack.dm:73-75) and
 * carries on into `attack_atom`, so the tank went in *and then clubbed the heater with itself*.
 * The heater carries no melee armour, so the integrity assertion below is the one that bites.
 *
 * The shut-panel wrench refusal rides along because it is the same family of override and
 * the destructive parent behind it is real: `/obj/machinery/atmospherics/wrench_act`
 * unanchors and unwelds. The heater's own override refuses first.
 */
/datum/unit_test/voidcrew_engine_interaction/heater_tank_swap

/datum/unit_test/voidcrew_engine_interaction/heater_tank_swap/Run()
	var/mob/living/carbon/human/consistent/engineer = allocate(/mob/living/carbon/human/consistent)
	var/obj/machinery/atmospherics/components/unary/shuttle/heater/heater = allocate(/obj/machinery/atmospherics/components/unary/shuttle/heater, bench())

	TEST_ASSERT_NULL(heater.fuel_tank, "the plain engine heater spawned with a fuel tank already in it - that is the /tank subtype's job, and this test needs an empty one")

	// --- combat mode OFF: the ordinary path a player takes ---
	var/obj/item/tank/internals/plasma/full/first = allocate(/obj/item/tank/internals/plasma/full)
	var/integrity_before = heater.get_integrity()

	if(!vc_click_with_item(engineer, heater, first, combat_mode = FALSE))
		return

	TEST_ASSERT_EQUAL(heater.fuel_tank, first, "a gas tank clicked onto the heater with combat mode off did not become its fuel tank (fuel_tank is [heater.fuel_tank || "null"])")
	TEST_ASSERT_EQUAL(first.loc, heater, "the heater claims the tank as its fuel_tank but the tank's loc is [first.loc || "null"] - transferItemToLoc() did not complete")
	TEST_ASSERT_EQUAL(heater.get_integrity(), integrity_before, "inserting a fuel tank damaged the heater. attackby()'s insert branch returned a falsy value, so melee_attack_chain read the click as \
		unhandled (item_attack.dm:73-75) and swung the tank at the machine after loading it.")

	// --- combat mode ON: tool_act is skipped entirely, so this is a different route ---
	var/obj/item/tank/internals/plasma/full/second = allocate(/obj/item/tank/internals/plasma/full)
	integrity_before = heater.get_integrity()

	if(!vc_click_with_item(engineer, heater, second, combat_mode = TRUE))
		return

	TEST_ASSERT_EQUAL(heater.fuel_tank, second, "a gas tank clicked onto the heater with combat mode ON did not become its fuel tank. base_item_interaction skips tool_act in combat mode, so this \
		click reaches attackby by a different route than the one above and needs its own coverage.")
	TEST_ASSERT_EQUAL(second.loc, heater, "the swapped-in tank's loc is [second.loc || "null"], not the heater")
	TEST_ASSERT_EQUAL(heater.get_integrity(), integrity_before, "swapping a fuel tank in combat mode damaged the heater")

	// The old tank is handed back rather than dropped or eaten - try_put_in_hand() in the
	// swap branch. This is the half that Exited() also has to agree with: the heater nulls
	// fuel_tank on any exit path, and a swap that left the pointer on the old tank would
	// strand it.
	TEST_ASSERT_NOTEQUAL(first.loc, heater, "the first fuel tank is still inside the heater after a second was inserted - the swap did not eject it")
	TEST_ASSERT(!QDELETED(first), "the heater destroyed the fuel tank it swapped out")

	// --- a wrench on a shut panel refuses instead of unbolting ---
	// The swap handed the old tank back into a hand; the fixtures fill the ACTIVE hand and
	// can_put_in_hand() refuses a full one, so the hands are cleared before the next tool.
	engineer.drop_all_held_items()
	var/obj/item/wrench/spanner = allocate(/obj/item/wrench)
	TEST_ASSERT(heater.anchored, "the heater is not anchored, so the shut-panel wrench refusal below is untestable")

	if(!vc_click_with_item(engineer, heater, spanner))
		return

	TEST_ASSERT(heater.anchored, "a wrench on a heater with its maintenance panel shut unbolted it. The heater's wrench_act() is supposed to refuse with \"open panel first!\" before reaching \
		default_unfasten_wrench(); the atmospherics parent's own wrench_act unanchors AND unwelds the pipe connection.")
	TEST_ASSERT_EQUAL(heater.fuel_tank, second, "wrenching the heater lost its fuel tank")

// ===========================================================================
// 6. The sublimator hopper (upstream #95408, halves two and four, plus click_alt)
// ===========================================================================

/**
 * Loading and emptying the sublimation chamber's hopper.
 *
 * Three overrides meet here, all of them re-signed by the same upstream pull:
 *
 *  - `attackby()` at the new four-argument arity, whose sheet-loading branch used to end in
 *    bare `return`s. Same failure as the heater's tank: the sheets went in and then the
 *    stack hit the chamber.
 *  - `click_alt()`, which is `SHOULD_CALL_PARENT(FALSE)` and must answer with a
 *    `CLICK_ACTION_*` flag. It used to call `..()` and fall off the end, so `base_click_alt`
 *    read the empty return as "unhandled" (it tests against `CLICK_ACTION_ANY`) and popped
 *    the generic alt-click panel over the hopper instead of emptying it.
 *  - the removed `default_pry_open()`, covered by `closed_panel_crowbar` above.
 *
 * `click_alt()` is reached the way a player reaches it, through `ClickOn` with the ALT_CLICK
 * modifier, because the modifier routing in `ClickOn` (click.dm:101-106) is part of what is
 * being asserted - a direct `click_alt()` call would skip `base_click_alt` and therefore skip
 * the exact test that read the old return as unhandled.
 */
/datum/unit_test/voidcrew_engine_interaction/sublimator_hopper

/datum/unit_test/voidcrew_engine_interaction/sublimator_hopper/Run()
	var/mob/living/carbon/human/consistent/loader = allocate(/mob/living/carbon/human/consistent)
	var/obj/machinery/atmospherics/components/unary/shuttle/sublimator/chamber = allocate(/obj/machinery/atmospherics/components/unary/shuttle/sublimator, bench())

	TEST_ASSERT_EQUAL(chamber.stored_sheets, 0, "the sublimation chamber spawned with sheets already in its hopper")

	// Spawned away from the chamber's own turf so the "what came back out" locate() at the
	// bottom cannot pick up the stack that went in, and so stack merging never joins them.
	var/obj/item/stack/sheet/mineral/plasma/sheets = allocate(/obj/item/stack/sheet/mineral/plasma, run_loc_floor_top_right, 5)
	TEST_ASSERT_EQUAL(sheets.amount, 5, "the test plasma stack came out holding [sheets.amount] sheets instead of 5")
	var/integrity_before = chamber.get_integrity()

	if(!vc_click_with_item(loader, chamber, sheets))
		return

	TEST_ASSERT_EQUAL(chamber.stored_sheets, 5, "clicking 5 plasma sheets onto the sublimation chamber loaded [chamber.stored_sheets] of them")
	TEST_ASSERT_EQUAL(chamber.get_integrity(), integrity_before, "loading plasma sheets damaged the sublimation chamber - attackby()'s load branch returned a falsy value and the swing carried \
		on into the attack chain after the sheets were taken")

	// Alt-click empties the hopper back out as one stack.
	if(!vc_click_bare_hand(loader, chamber, list(ALT_CLICK = TRUE, BUTTON = LEFT_CLICK)))
		return

	TEST_ASSERT_EQUAL(chamber.stored_sheets, 0, "alt-clicking the sublimation chamber did not empty its hopper. click_alt() is SHOULD_CALL_PARENT(FALSE) and has to answer with a CLICK_ACTION_* flag; \
		a bare return reads as unhandled to base_click_alt() and opens the generic alt-click panel instead.")

	var/obj/item/stack/sheet/mineral/plasma/dumped = locate() in get_turf(chamber)
	TEST_ASSERT_NOTNULL(dumped, "the sublimation chamber emptied its hopper but no plasma stack appeared on its turf")
	TEST_ASSERT_EQUAL(dumped.amount, 5, "the sublimation chamber gave back [dumped.amount] plasma sheets instead of the 5 it was fed")

	// --- and the click_alt CONTRACT, which the click above cannot see ---
	//
	// The old body emptied the hopper correctly and *still* returned nothing, because it ended
	// with `. = ..()` and then fell off the end. base_click_alt() tests the answer against
	// CLICK_ACTION_ANY, so a bare return reads as "unhandled" and /mob/living/base_click_alt
	// walks on to try_open_loot_panel_on() - the loot panel over the hopper players reported.
	// That difference is invisible to a headless click (the panel needs a client) and visible
	// in the return value, so these two go through click_alt() directly. Both states are
	// covered because they are separate branches with separate flags.
	var/empty_answer = chamber.click_alt(loader)
	TEST_ASSERT(empty_answer & CLICK_ACTION_BLOCKING, "alt-clicking an EMPTY sublimation chamber answered [isnull(empty_answer) ? "null" : empty_answer] instead of CLICK_ACTION_BLOCKING. \
		click_alt() is SHOULD_CALL_PARENT(FALSE) and its return is tested against CLICK_ACTION_ANY - anything falsy hands the click on to the generic alt-click handling.")

	// Staged rather than clicked: this assertion is purely about the flag the success branch
	// returns, and re-loading the hopper through another click would only re-test the loader.
	chamber.stored_sheets = 3
	var/full_answer = chamber.click_alt(loader)
	TEST_ASSERT(full_answer & CLICK_ACTION_SUCCESS, "alt-clicking a LOADED sublimation chamber answered [isnull(full_answer) ? "null" : full_answer] instead of CLICK_ACTION_SUCCESS")
	TEST_ASSERT_EQUAL(chamber.stored_sheets, 0, "the success branch of click_alt() answered SUCCESS without emptying the hopper")
