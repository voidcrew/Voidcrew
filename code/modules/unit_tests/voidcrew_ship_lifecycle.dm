/**
 * # Ship lifecycle: purchase, assembly, teardown
 *
 * Every round in this fork starts with a hull that a player bought: a template,
 * plus a theme, plus one upgrade module per slot, stitched together by
 * SSshuttle.create_ship() and /obj/modular_map_root/ship_upgrade. Four test
 * files already read the shipped `.dmm` files and reason about that assembly
 * statically (voidcrew_ship_assembly.dm, voidcrew_ship_hulls.dm,
 * voidcrew_ship_modules.dm, voidcrew_map_packing.dm) and one loads a hull for a
 * *preview* and unloads it again - but **no test in this repo has ever
 * assembled a purchased ship and looked at the result**, and none has ever
 * destroyed one.
 *
 * That is the gap this file closes. The breakage classes it guards, each of
 * which is invisible to every static scan and to a preview load:
 *
 *  1. **Upgrade merges break the assembly wiring silently.** The module loader
 *     is asynchronous (`/obj/modular_map_root/Initialize` fires an
 *     INVOKE_ASYNC), the theme rewrites the hull's `suffix`/`mappath` *and*
 *     re-measures it, and the job list is spliced from three sources (theme,
 *     template, every selected module's `job_slots_add`). Any of those can stop
 *     happening without a single `.dmm` changing and without a compile error.
 *     The only way to catch it is to buy a ship and look at what arrived.
 *  2. **Post-load auto-linking dies quietly.** `COMSIG_VOIDCREW_SHIP_LOADED`
 *     exists because `connect_to_shuttle()` fires *inside* the template load,
 *     before `create_ship()` has set `port.current_ship` - so the mapped
 *     consoles have nothing to link to yet and have to be told later. A
 *     consumer that stops receiving the signal keeps working in every static
 *     sense and simply never finds its ship: the bank machine spends the round
 *     pointed at no account.
 *  3. **Teardown leaks, and one of the leaks is a suite-killer.** Tearing a
 *     hull down touches five registries, deletes the crew, hands back a transit
 *     reservation and returns a z-level's worth of turfs to space. Five real
 *     defects lived in that path until this branch; the test half of that fix
 *     is here (see /datum/unit_test/voidcrew_ship_teardown_lifecycle).
 *  4. **The mapless stand-in reaching a purchasable listing.** A template with
 *     no `.dmm` on disk is the one input `create_ship()` cannot survive: it
 *     stack_trace()s, and a single stack_trace() denies `clean_run.lk` for the
 *     entire suite.
 *
 * ## Cost
 *
 * `vc_create_test_ship()` is a real map load: it sleeps three ways and toggles
 * `SSair.can_fire`. This file builds **four** hulls in total - one Goon for the
 * assembly flow, and three of the smallest purchasable hull for the teardown
 * loop - and every test that builds one is `TEST_LONGER`. Assertions are
 * chained onto one ship rather than split across several, and the teardown
 * lifecycle deliberately folds four separate specs into a single three-hull
 * sequence for that reason; the alternative shape needed ten loads.
 *
 * ## The rule this file follows after a hull exists
 *
 * `TEST_ASSERT` expands to `return Fail(...)`, so a failing assert would return
 * from `Run()` **without releasing the hull**, and a leaked hull holds a
 * transit reservation and a ZTRAIT_STATION claim for the rest of the run. So
 * everything after the first successful build is written as
 * `if(!condition) TEST_FAIL(...)` and falls through to the release. Bare
 * `TEST_ASSERT` is used only before anything has been built.
 */

// ---------------------------------------------------------------------------
// Shared helpers
//
// Global procs rather than procs on /datum/unit_test: none of them records a
// failure, so none of them needs the TEST_* macros, and hanging them off the
// abstract base is reserved for the fixture file.
// ---------------------------------------------------------------------------

/**
 * Every turf that belongs to `port`'s own compartments.
 *
 * Scoped the same way /obj/docking_port/mobile/voidcrew/ensure_starter_supplies()
 * scopes itself - the port's projected rectangle AND one of the port's own areas -
 * so a hull parked over a planet or docked at a ruin never reports the ground
 * underneath it as its own. Call it BEFORE any teardown: Destroy() nulls
 * `shuttle_areas` and the port's coordinates go to nullspace.
 */
/proc/vc_lifecycle_hull_turfs(obj/docking_port/mobile/voidcrew/port)
	var/list/tiles = list()
	if(!istype(port) || QDELETED(port) || !length(port.shuttle_areas))
		return tiles
	for(var/turf/tile as anything in port.return_ordered_turfs(port.x, port.y, port.z, port.dir))
		if(isnull(tile))
			continue
		if(!port.shuttle_areas[tile.loc])
			continue
		tiles += tile
	return tiles

/// The first atom of `wanted_type` standing anywhere aboard `port`, or null.
/// Recursive (get_all_contents), so an item inside a rack or a bag counts.
/proc/vc_lifecycle_find_aboard(obj/docking_port/mobile/voidcrew/port, wanted_type)
	for(var/turf/tile as anything in vc_lifecycle_hull_turfs(port))
		for(var/atom/thing as anything in tile.get_all_contents())
			if(istype(thing, wanted_type))
				return thing
	return null

/// Every /obj/effect/landmark currently aboard `port`. Collected before teardown so
/// the same instances can be checked for deletion afterwards - an identity check
/// survives unrelated map loads in a way a global list length does not.
/proc/vc_lifecycle_landmarks_aboard(obj/docking_port/mobile/voidcrew/port)
	var/list/markers = list()
	for(var/turf/tile as anything in vc_lifecycle_hull_turfs(port))
		for(var/obj/effect/landmark/marker in tile.get_all_contents())
			markers |= marker
	return markers

/// TRUE if any live weather site in `registry_list` carries `wanted_id`.
/// Searches by id rather than by reference because a hard-deleted datum nulls
/// every reference to it in place, which would turn a leak into a vacuous pass.
/proc/vc_lifecycle_site_id_present(list/registry_list, wanted_id)
	for(var/datum/weather_site/site as anything in registry_list)
		if(isnull(site))
			continue
		if(site.id == wanted_id)
			return TRUE
	return FALSE

// ---------------------------------------------------------------------------
// A. The full purchase-and-assemble flow
// ---------------------------------------------------------------------------

/**
 * # A purchased ship arrives as the ship that was purchased
 *
 * Buys a Goon on the non-default **Void Runner** theme with a **non-default
 * module in every one of its five slots**, through the same
 * `SSshuttle.create_ship()` every purchase, every roundstart fleet hull and
 * every admin spawn goes through, and then asserts the ship a crew would board.
 *
 * ## Why this hull and this fitout
 *
 * `vc_create_test_ship()`'s default hull is the smallest purchasable one, which
 * is the 3-tile `pill_black` - a curated `force_purchasable` gag hull with **no
 * upgrade slots, no themes, no bank machine and no mission pad**. Everything
 * this test is about is absent from it, so the hull is passed explicitly. The
 * Goon is the smallest hull that has slots, themes, and the full mapped console
 * set.
 *
 * A **non-default** theme is chosen because the theme is what rewrites
 * `suffix` -> `mappath` and re-measures the map; taking the default proves only
 * that the fallback works. A non-default module in **every** slot is chosen for
 * the same reason, and the test refuses to run if any of the five is ever
 * marked `is_default` - a default selection would make every "the module the
 * player paid for is aboard" assertion below pass for the wrong reason.
 *
 * ## What each assertion guards
 *
 * - **Signature furniture, five positives and one negative.** Each selected
 *   module's `.dmm` places exactly one object type that appears in no sibling
 *   module for that slot and on none of the four Goon hull maps, so finding it
 *   aboard means that module's map really merged. The negative is the mirror:
 *   `/obj/machinery/mineral/ore_redemption` belongs to `mining_prospector`, the
 *   slot **default** that we did not select. Finding it would mean the loader
 *   fell back to the default and quietly ignored the player's choice - a
 *   failure mode that a positive-only test cannot see.
 * - **Theme application.** The Goon's areas are suffixed per theme
 *   (`/bridge/a` on `standard`, `/bridge/b` on `void`), so the compartment
 *   types are a direct readout of which `.dmm` actually loaded.
 * - **Job splicing.** "Captain" comes from the theme, "Chemist" comes from the
 *   selected Chem Lab's `job_slots_add`, and "Master-at-Arms" comes from the
 *   Brig Block we did *not* select. All three are needed: the first two prove
 *   both sources are merged, the third proves the merge is selection-driven
 *   rather than "every module for the slot".
 * - **Auto-linking.** The bank machine is the one consumer of
 *   COMSIG_VOIDCREW_SHIP_LOADED whose linked state is *signal-exclusive*: its
 *   own `connect_to_shuttle()` early-returns mid-load and it has no timer
 *   fallback, so a non-null `synced_bank_account` means the signal fired. The
 *   cargo console covers the second linking mechanism (`connect_to_shuttle()`
 *   scanning the hull for the bank machine), and the mission pad the third.
 *   The mission pad also arms a 1-second timer of its own, so it is asserted as
 *   a wiring outcome and explicitly not as evidence the signal fired.
 * - **Starter supplies.** `ensure_starter_supplies()` is an unconditional
 *   post-condition of `create_ship()`: no hull configuration may launch without
 *   breathing gear. Only container types and loose items are looked for, which
 *   is the same rule the production proc follows (closet contents are lazily
 *   populated and invisible to both).
 */
/datum/unit_test/voidcrew_ship_purchase_assembly
	priority = TEST_LONGER

/datum/unit_test/voidcrew_ship_purchase_assembly/Run()
	ensure_ship_upgrades_initialized()

	var/hull_type = /datum/map_template/shuttle/voidcrew/goon
	var/theme_id = "void"
	/// The theme's own map suffix; the hull's areas and mappath both key off it.
	var/theme_suffix = "goon_b"

	var/list/hull_modules = GLOB.ship_upgrade_modules[hull_type]
	TEST_ASSERT(length(hull_modules), "no upgrade modules are registered for [hull_type] - ensure_ship_upgrades_initialized() did not run, or the Goon's module file stopped registering")

	var/list/hull_themes = GLOB.ship_themes[hull_type]
	TEST_ASSERT(length(hull_themes), "no themes are registered for [hull_type]")
	var/datum/ship_theme/theme = hull_themes[theme_id]
	TEST_ASSERT_NOTNULL(theme, "[hull_type] has no '[theme_id]' theme registered - this test buys a NON-default theme on purpose, because the default is the only path the fallback in create_ship() covers")
	TEST_ASSERT(!theme.is_default, "'[theme_id]' has become [hull_type]'s default theme. This test exists to prove a chosen theme is honoured; on the default it would pass even if theme selection were deleted outright")
	TEST_ASSERT_EQUAL(theme.template_suffix, theme_suffix, "the '[theme_id]' theme's template_suffix moved to [theme.template_suffix]. Every hull-area assertion below is keyed to [theme_suffix]")

	// slot key -> the module the "player" is buying, and the object type that
	// module's map is the only thing in the fleet to place.
	var/list/wanted = list(
		"goon_port" = "goon_port_chemlab",
		"goon_engineering" = "goon_engineering_rtg",
		"goon_mining" = "goon_mining_freight",
		"goon_lounge" = "goon_lounge_mess",
		"goon_cockpit" = "goon_cockpit_command",
	)
	var/list/signatures = list(
		"goon_port_chemlab" = /obj/machinery/chem_dispenser,
		"goon_engineering_rtg" = /obj/machinery/power/rtg/advanced,
		"goon_mining_freight" = /obj/machinery/conveyor_switch,
		"goon_lounge_mess" = /obj/machinery/griddle,
		"goon_cockpit_command" = /obj/machinery/computer/communications,
	)
	/// The mining slot's DEFAULT module is the only thing in the fleet that maps
	/// this, so it must be absent once a different module is bought for the slot.
	var/unselected_default_signature = /obj/machinery/mineral/ore_redemption
	/// Contributed by the Brig Block, which shares the port slot with the Chem
	/// Lab we are buying and must therefore contribute nothing.
	var/unselected_job_title = "Master-at-Arms"

	// The slot list a themed hull actually offers is the theme's, not the
	// template's - assert the fitout covers all of it, so "a module in every
	// slot" cannot quietly become "a module in the slots this test remembered".
	var/list/slot_ids = theme.upgrade_slot_ids
	TEST_ASSERT(length(slot_ids), "the '[theme_id]' theme offers no upgrade slots at all, so there is no fitout to buy")
	for(var/slot_key in slot_ids)
		TEST_ASSERT(wanted[slot_key], "[hull_type] on '[theme_id]' offers the slot '[slot_key]' and this test buys nothing for it. Every slot has to be filled or the flow under test is not the one a player takes")

	// Resolve the selections through the same proc the upgrade selector offers
	// them with, so a module that is no longer purchasable for this slot and
	// theme fails here rather than loading anyway through a back door.
	var/list/upgrade_selections = list()
	for(var/slot_key in wanted)
		var/module_id = wanted[slot_key]
		var/datum/ship_upgrade_module/chosen = hull_modules[module_id]
		TEST_ASSERT_NOTNULL(chosen, "the module '[module_id]' is no longer registered for [hull_type]")
		TEST_ASSERT(!chosen.is_default, "'[module_id]' has become the default for slot '[slot_key]'. Buying a default would make every furniture assertion below pass without the player's selection being honoured at all")
		var/list/offered = get_modules_for_ship_slot(hull_type, theme_id, slot_key)
		TEST_ASSERT(chosen in offered, "'[module_id]' is not offered for slot '[slot_key]' on theme '[theme_id]', so no player could buy this fitout")
		upgrade_selections[slot_key] = chosen

	// ---- the purchase itself -------------------------------------------------
	// One window across the whole build. It spans the map load's sleeps
	// deliberately: the async module merge, the powernet rebuild and every
	// COMSIG_VOIDCREW_SHIP_LOADED handler all land inside it, and a runtime
	// raised by any of them is exactly what this test is for.
	var/snapshot = vc_runtime_snapshot()
	var/obj/structure/overmap/ship/ship = vc_create_test_ship(hull_type, upgrade_selections, theme)
	if(isnull(ship))
		return
	vc_assert_no_new_runtimes(snapshot, "assembling a purchased [hull_type] on the '[theme_id]' theme with a non-default module in all [length(slot_ids)] slots")

	var/obj/docking_port/mobile/voidcrew/port = ship.shuttle
	if(isnull(port))
		// vc_create_test_ship() already fails and releases on this, so reaching
		// here means the fixture's own contract broke.
		vc_release_test_ship(ship)
		return

	// ---- the two-way link and the port's registration ------------------------
	if(port.current_ship != ship)
		TEST_FAIL("the assembled hull's port does not point back at its ship (current_ship is [port.current_ship || "null"]). Everything that finds a ship from a machine aboard it walks this link")
	if(!(port in SSshuttle.mobile_docking_ports))
		TEST_FAIL("the assembled hull's port never registered in SSshuttle.mobile_docking_ports, so nothing can dock it and SSshuttle will not move it")
	if(!length(port.shuttle_id))
		TEST_FAIL("the assembled hull's port has no shuttle_id, so linkup() cannot wire its machinery and every log line naming it is anonymous")
	if(!(ship in SSovermap.simulated_ships))
		TEST_FAIL("the assembled ship is not in SSovermap.simulated_ships, so it is not a ship as far as the overmap, the derelict sweeper or any other hull is concerned")

	// shuttle_id uniqueness among LIVE ports. A duplicate is not cosmetic:
	// linkup() resolves an id to a port, so a second live holder of an id wires
	// the new hull's machinery to the old hull's port.
	var/list/seen_ids = list()
	for(var/obj/docking_port/mobile/other as anything in SSshuttle.mobile_docking_ports)
		if(isnull(other) || QDELETED(other))
			continue
		if(seen_ids[other.shuttle_id])
			TEST_FAIL("two live mobile docking ports share the shuttle_id '[other.shuttle_id]' - linkup() cannot tell them apart and will wire one hull's machinery to the other's port")
			break
		seen_ids[other.shuttle_id] = TRUE

	// ---- the theme actually selected the themed map --------------------------
	if(ship.theme != theme_id)
		TEST_FAIL("the ship kept theme '[ship.theme || "null"]' after being bought on '[theme_id]'")
	var/datum/map_template/shuttle/voidcrew/built_from = ship.source_template
	if(isnull(built_from))
		TEST_FAIL("the assembled ship has no source_template")
	else
		if(built_from.suffix != theme_suffix)
			TEST_FAIL("the '[theme_id]' theme did not rewrite the template suffix - it is '[built_from.suffix]', expected '[theme_suffix]'. create_ship() derives mappath from suffix, so the wrong map loaded")
		if(!findtext(built_from.mappath, "ship_[theme_suffix].dmm"))
			TEST_FAIL("the assembled hull loaded [built_from.mappath], not the '[theme_id]' theme's ship_[theme_suffix].dmm")
		if(built_from.width <= 0 || built_from.height <= 0)
			TEST_FAIL("the themed template was never re-measured (width [built_from.width] x height [built_from.height]) - preload_size() is what sizes the transit reservation and the docking port bounds")

	// The compartment types are the map's own signature: the Goon suffixes its
	// areas per theme, so finding a /b area and no /a area is a direct readout
	// of which .dmm the loader picked.
	var/found_themed_area = FALSE
	var/found_default_theme_area = FALSE
	for(var/area/compartment as anything in port.shuttle_areas)
		if(istype(compartment, /area/shuttle/voidcrew/goon/bridge/b))
			found_themed_area = TRUE
		if(istype(compartment, /area/shuttle/voidcrew/goon/bridge/a))
			found_default_theme_area = TRUE
	if(!found_themed_area)
		TEST_FAIL("no /area/shuttle/voidcrew/goon/bridge/b compartment was registered on a hull bought on the '[theme_id]' theme")
	if(found_default_theme_area)
		TEST_FAIL("a hull bought on the '[theme_id]' theme came back carrying the default theme's /area/shuttle/voidcrew/goon/bridge/a compartment - theme selection was ignored and the default map loaded")
	if(!length(vc_lifecycle_hull_turfs(port)))
		TEST_FAIL("the assembled hull owns no turfs inside its own compartments - the map did not land where the port thinks it is")

	// ---- the modules the player paid for are physically aboard ---------------
	for(var/slot_key in wanted)
		var/module_id = wanted[slot_key]
		var/signature = signatures[module_id]
		if(isnull(vc_lifecycle_find_aboard(port, signature)))
			TEST_FAIL("slot '[slot_key]' was bought as '[module_id]' but no [signature] is aboard. That object is placed by that module's map and by nothing else in the fleet, so the module's map never merged onto the hull")
	if(!isnull(vc_lifecycle_find_aboard(port, unselected_default_signature)))
		TEST_FAIL("a [unselected_default_signature] is aboard. Only the mining slot's DEFAULT module places one, and this ship was bought with a different module in that slot - the loader fell back to the default and threw the player's selection away")

	// The selections are also kept on the ship itself; the upgrade selector and
	// the preview both read them back.
	if(!islist(ship.upgrade_selections) || !length(ship.upgrade_selections))
		TEST_FAIL("the assembled ship kept no upgrade_selections, so nothing can tell afterwards what fitout it was built with")
	else
		for(var/slot_key in upgrade_selections)
			if(ship.upgrade_selections[slot_key] != upgrade_selections[slot_key])
				TEST_FAIL("the ship's stored selection for slot '[slot_key]' is not the module it was built with")

	// ---- the ship datum's own wiring -----------------------------------------
	if(isnull(ship.ship_team))
		TEST_FAIL("the assembled ship has no ship_team, so no crewman can be enlisted onto it")
	else
		if(ship.ship_team.ship != ship)
			TEST_FAIL("the ship's team does not point back at the ship")
		if(!(ship.ship_team in GLOB.antagonist_teams))
			TEST_FAIL("the ship's team never registered in GLOB.antagonist_teams")
	if(isnull(ship.ship_account))
		TEST_FAIL("the assembled ship has no ship_account - the bank machine, cargo and every payroll tick hang off it")
	else if(ship.ship_account.account_balance != initial(ship.starting_credits))
		TEST_FAIL("the assembled ship's account holds [ship.ship_account.account_balance] credits, not the [initial(ship.starting_credits)] commissioning funds setup_from_template() seeds it with")

	// job_slots is assoc /datum/job -> slot count. manifest is deliberately NOT
	// asserted on: it is empty until a crewman is enlisted, so any assertion on
	// it here would be vacuous.
	if(!length(ship.job_slots))
		TEST_FAIL("the assembled ship has no job slots, so nobody can join it and setup_from_template()'s ship_account seeding ran off job_slots\[1\] by luck")
	else
		var/list/titles = list()
		for(var/datum/job/slot as anything in ship.job_slots)
			if(isnull(slot))
				continue
			titles[slot.title] = TRUE
		if(!titles["Captain"])
			TEST_FAIL("the '[theme_id]' theme's own job slots were not merged - no Captain slot exists, and the ship's account is seeded from the first slot")
		if(!titles["Chemist"])
			TEST_FAIL("the Chem Lab module was bought but contributed no Chemist slot. Module job_slots_add is spliced in setup_from_template(); a fitout that adds crew has stopped adding them")
		if(titles[unselected_job_title])
			TEST_FAIL("the ship carries a [unselected_job_title] slot, which only the Brig Block contributes - and the Brig Block shares its slot with the Chem Lab that was actually bought. Job merging is taking every module for a slot rather than the selected one")

	// ---- post-load auto-linking ----------------------------------------------
	var/obj/machinery/computer/bank_machine/bank = vc_lifecycle_find_aboard(port, /obj/machinery/computer/bank_machine)
	if(isnull(bank))
		TEST_FAIL("no bank machine is aboard the assembled hull. Every purchasable hull is meant to launch with one, and it is the only signal-exclusive witness that COMSIG_VOIDCREW_SHIP_LOADED fired")
	else if(bank.synced_bank_account != ship.ship_account)
		TEST_FAIL("the hull's bank machine is not synced to the ship's account. Its own connect_to_shuttle() early-returns mid-load and it has no timer fallback, so this is COMSIG_VOIDCREW_SHIP_LOADED failing to reach its consumers - the ship spends the round unable to spend its own money")

	var/obj/machinery/computer/voidcrew_cargo/cargo = vc_lifecycle_find_aboard(port, /obj/machinery/computer/voidcrew_cargo)
	if(isnull(cargo))
		TEST_FAIL("no cargo console is aboard the assembled hull")
	else if(!isnull(bank) && cargo.bank_account_holder != bank)
		TEST_FAIL("the cargo console did not link to the hull's bank machine. That link is made by connect_to_shuttle() scanning the port's areas, a different mechanism from the signal above, and without it every order refuses for want of an account")

	var/obj/machinery/mission_pad/pad = vc_lifecycle_find_aboard(port, /obj/machinery/mission_pad)
	if(isnull(pad))
		TEST_FAIL("no mission pad is aboard the assembled hull")
	else
		// The pad also arms a 1-second fallback timer in Initialize(), so this
		// asserts the wiring OUTCOME and is deliberately not treated as
		// evidence that the signal fired - that is the bank machine's job.
		if(pad.linked_ship != ship)
			TEST_FAIL("the hull's mission pad never linked to its ship, so no mission can be turned in aboard it")
		if(!(pad in ship.linked_mission_pads))
			TEST_FAIL("the ship does not list its own mission pad in linked_mission_pads - the link was made one-way")

	// ---- the unconditional starter-supply guarantee --------------------------
	// ensure_starter_supplies() runs on every hull create_ship() builds: no
	// fitout may launch without breathing gear. Container types and loose items
	// only, the same rule the production proc follows.
	var/found_breathing_gear = FALSE
	for(var/turf/tile as anything in vc_lifecycle_hull_turfs(port))
		for(var/atom/movable/thing as anything in tile.contents)
			if(istype(thing, /obj/structure/closet/emcloset) \
				|| istype(thing, /obj/structure/closet/crate/internals) \
				|| istype(thing, /obj/item/storage/box/survival) \
				|| istype(thing, /obj/item/tank/internals/oxygen))
				found_breathing_gear = TRUE
				break
		if(found_breathing_gear)
			break
	if(!found_breathing_gear)
		TEST_FAIL("the assembled hull launched with no breathing gear anywhere aboard. ensure_starter_supplies() is meant to make that impossible for every hull and every fitout")

	// ---- teardown ------------------------------------------------------------
	if(!vc_release_test_ship(ship))
		TEST_FAIL("releasing the assembled hull was not clean - see the fixture's own failures above")

// ---------------------------------------------------------------------------
// B. Teardown
// ---------------------------------------------------------------------------

/**
 * # A hull can be torn down without leaking, ghosting the crew on the way out
 *
 * Four teardown specs on one three-hull sequence. They are folded together
 * because `vc_create_test_ship()` is a real map load and the naive shape - one
 * ship per spec, plus a three-cycle loop, plus three hulls for the id check -
 * needs ten loads to assert what three assert here. The hull is
 * `vc_create_test_ship()`'s default, i.e. the smallest purchasable one, for the
 * same reason.
 *
 * The specs, and the defect each guards:
 *
 * 1. **All three teardown mouths are runtime-free.** The fork drives hull
 *    teardown from three places - `despawn_derelict()` (the derelict sweeper),
 *    `destroy_ship(force = TRUE)` (the bluespace jump) and a bare `qdel()` of
 *    the overmap ship (an NPC hull killed in combat, an admin delete, a failed
 *    spawn) - and all three now funnel through
 *    `/obj/structure/overmap/ship/release_hull()`. Before that funnel existed,
 *    every one of them reached `/obj/docking_port/mobile/voidcrew/Destroy()`
 *    with `current_ship` still set, where a `stack_trace()` stands as the alarm
 *    for a port deleted out from under a live ship. `stack_trace()` is
 *    `CRASH()` with the proc kept alive, so it increments
 *    `GLOB.total_runtimes`, and `world.dm` refuses to write `clean_run.lk` with
 *    a non-zero count: **one despawned ship anywhere in the suite failed the
 *    entire run**, and in a live round it fired on every 30-minute derelict
 *    sweep. Each teardown here is wrapped in its own tight runtime window so a
 *    regression names the mouth that broke.
 * 2. **Landmarks do not survive their hull.** `/turf/proc/empty()` typecaches
 *    `/obj/effect/landmark` into `ignored_atoms` beside `/obj/docking_port`, so
 *    the per-turf sweep in `jumpToNullSpace()` - the only thing that ever
 *    touches a dying hull's turfs - deletes everything except the landmarks.
 *    `create_ship()` leaves an `observer_start` aboard every hull it builds,
 *    and each hull `.dmm` may map job spawns of its own on top of that, so
 *    every create-and-destroy cycle used to grow `GLOB.landmarks_list` (and
 *    `start_landmarks_list`, and `jobspawn_overrides`) permanently, leaving
 *    abandoned markers standing on ground handed to the next tenant. Checked by
 *    identity - the exact markers that were aboard - rather than by global list
 *    length, so an unrelated map load elsewhere in the world cannot mask it and
 *    cannot fake it.
 *
 *    Note "an observer_start", not "two landmarks": `create_ship()` does spawn
 *    a `blobstart` beside it, but that subtype records `GLOB.blobstart += loc`
 *    and returns `INITIALIZE_HINT_QDEL` from its own `Initialize()`, so it is
 *    gone before anything can observe it. The hull used here maps no job spawns
 *    at all, which makes the `observer_start` the entire census - and the thing
 *    the vacuity guard names.
 * 3. **A crewman taken out with the hull is ghostized first.** The bluespace
 *    jump is the one teardown path with players aboard, and it used to hand the
 *    crew straight to `/turf/proc/empty()`, which qdels them where they stand.
 *    `/mob/Destroy()` `stack_trace()`s on any mob still holding a client - or
 *    merely a ckey, after its player logged off - so a jump cost one runtime
 *    per crewman and dropped the player out of the round with no observer to
 *    come back as.
 * 4. **Shuttle-id suffixes are never recycled.** `SSshuttle.assoc_mobile` is
 *    not reference counting and `unregister()` is right not to decrement it:
 *    the suffix it hands out has to be unique among the ships that are ALIVE,
 *    not among the ships that have ever existed. Decrementing on teardown
 *    re-mints a live hull's id onto a new hull, and `linkup()` resolves an id
 *    to a port - so the new hull's machinery gets wired to the old hull's port.
 *    That is what the create/destroy/create ordering below is for: the third
 *    hull is built *after* the first is destroyed, and must not collide with
 *    the second, which is still flying.
 *
 * Every teardown here uses the production path. The fixture's own
 * `vc_release_test_ship()` breaks the ship<->port link and sweeps landmarks by
 * hand, so a test that tore down through the fixture would prove nothing about
 * the game's teardown; it is called at the end only to catch anything the
 * production path left standing.
 */
/datum/unit_test/voidcrew_ship_teardown_lifecycle
	priority = TEST_LONGER

/datum/unit_test/voidcrew_ship_teardown_lifecycle/Run()
	var/list/assoc_before = SSshuttle.assoc_mobile.Copy()
	var/landmarks_before = length(GLOB.landmarks_list)
	var/start_landmarks_before = length(GLOB.start_landmarks_list)

	// Hulls are tracked from the moment they exist so the release sweep at the
	// bottom runs for every one of them on every exit path.
	var/list/built = list()

	var/obj/structure/overmap/ship/alpha = vc_create_test_ship()
	if(isnull(alpha))
		return
	built += alpha

	// Which assoc_mobile bucket this hull's suffix comes out of. Derived rather
	// than hardcoded: no voidcrew hull sets shuttle_id, so in practice every
	// one of them lands in the single "shuttle" bucket, but that is an emergent
	// property of the port subtypes and not a contract.
	var/base_id
	for(var/key in SSshuttle.assoc_mobile)
		if(assoc_before[key] != SSshuttle.assoc_mobile[key])
			base_id = key
			break
	if(isnull(base_id))
		TEST_FAIL("registering a freshly built hull did not touch SSshuttle.assoc_mobile at all, so no suffix was minted for it and nothing below can tell whether suffixes are being recycled")
	var/counter_after_alpha = isnull(base_id) ? 0 : SSshuttle.assoc_mobile[base_id]

	var/obj/structure/overmap/ship/bravo = vc_create_test_ship()
	if(isnull(bravo))
		vc_release_test_ship(alpha)
		return
	built += bravo

	var/counter_after_bravo = isnull(base_id) ? 0 : SSshuttle.assoc_mobile[base_id]
	if(!isnull(base_id) && counter_after_bravo <= counter_after_alpha)
		TEST_FAIL("a second hull registered without advancing SSshuttle.assoc_mobile\[\"[base_id]\"\] ([counter_after_alpha] -> [counter_after_bravo]), so both hulls were minted the same suffix")

	var/alpha_id = alpha.shuttle?.shuttle_id
	var/bravo_id = bravo.shuttle?.shuttle_id
	if(alpha_id == bravo_id)
		TEST_FAIL("two hulls flying at the same time share the shuttle_id '[alpha_id]'. linkup() resolves an id to a port, so one hull's machinery is now wired to the other hull's port")
	vc_lifecycle_assert_unique_live_ids("with two fixture hulls flying")

	// ---- spec 1 + 2: the derelict sweeper's path -----------------------------
	var/obj/docking_port/mobile/voidcrew/alpha_port = alpha.shuttle
	var/list/alpha_markers = vc_lifecycle_landmarks_aboard(alpha_port)
	// Vacuity guard for all three teardowns below - they use the same hull, so
	// this census is theirs too. It names the type rather than counting, because
	// the count is a trap: create_ship() spawns TWO landmarks on every hull, but
	// only ONE of them is still alive a tick later.
	// /obj/effect/landmark/blobstart/Initialize() (landmarks.dm:376) records
	// GLOB.blobstart += loc and then returns INITIALIZE_HINT_QDEL, deleting
	// itself - it is a coordinate donor, not a marker that persists. The
	// observer_start beside it is the one that stays, and on a hull whose .dmm
	// maps no job spawns of its own (both pill hulls map none at all) it is the
	// only landmark aboard. Asserting the type is strictly stronger than
	// asserting a count: it pins the exact instance the sweep has to remove.
	var/found_observer_start = FALSE
	for(var/obj/effect/landmark/marker as anything in alpha_markers)
		if(istype(marker, /obj/effect/landmark/observer_start))
			found_observer_start = TRUE
			break
	if(!found_observer_start)
		TEST_FAIL("no /obj/effect/landmark/observer_start was found in the [length(alpha_markers)] landmark(s) aboard a freshly built hull. create_ship() spawns one aboard every hull it builds, so without it the landmark-leak assertions below have nothing to prove and would pass vacuously")

	var/snapshot = vc_runtime_snapshot()
	var/despawned = alpha.despawn_derelict()
	if(!despawned)
		TEST_FAIL("despawn_derelict() refused to tear down a crewless fixture hull, so the sweeper would keep visiting it every minute for the rest of the round")
	vc_assert_no_new_runtimes(snapshot, "despawn_derelict() on a crewless fixture hull - the derelict sweeper's own path, which runs on every 30-minute despawn in a live round")
	vc_lifecycle_assert_hull_gone(alpha, alpha_port, "despawn_derelict()")
	vc_lifecycle_assert_markers_gone(alpha_markers, "despawn_derelict()")

	if(!isnull(base_id) && SSshuttle.assoc_mobile[base_id] < counter_after_bravo)
		TEST_FAIL("tearing a hull down dropped SSshuttle.assoc_mobile\[\"[base_id]\"\] from [counter_after_bravo] to [SSshuttle.assoc_mobile[base_id]]. That counter is a high-water mark for name and id suffixes, not a reference count: decrementing it re-mints a suffix that a hull still flying is using")

	// ---- spec 1 + 3: the bluespace jump's path, with a keyed crewman aboard ---
	// Baseline taken here rather than at the top so the window excludes the map
	// loads above, each of which sleeps and can let unrelated mobs come and go.
	var/living_baseline = length(GLOB.mob_living_list)
	var/test_key = "VcShipLifecycleCrew"
	var/expected_ckey = ckey(test_key)

	var/mob/living/carbon/human/crewman = allocate(/mob/living/carbon/human/consistent)
	if(isnull(crewman))
		TEST_FAIL("could not allocate a crewman for the ghostize check")
	else
		// A key with no client is exactly the disconnected-player case, and it is
		// what /mob/Destroy() stack_trace()s on. The same trick is used by
		// code/modules/unit_tests/emoting.dm.
		crewman.key = test_key
		var/list/bravo_turfs = vc_lifecycle_hull_turfs(bravo.shuttle)
		if(!length(bravo_turfs))
			TEST_FAIL("the second fixture hull owns no turfs, so the crewman cannot be put aboard it")
		else
			crewman.forceMove(bravo_turfs[1])
			if(!bravo.shuttle.shuttle_areas[get_area(crewman)])
				TEST_FAIL("the crewman did not land in one of the hull's own compartments, so release_hull()'s sweep would never find them and this check would pass vacuously")

	var/obj/docking_port/mobile/voidcrew/bravo_port = bravo.shuttle
	var/list/bravo_markers = vc_lifecycle_landmarks_aboard(bravo_port)

	snapshot = vc_runtime_snapshot()
	var/destroyed = bravo.destroy_ship(TRUE, ignore_crew = TRUE)
	if(!destroyed)
		TEST_FAIL("destroy_ship(TRUE, ignore_crew = TRUE) refused a hull with a crewman aboard. ignore_crew exists for the bluespace jump, which is meant to take the crew with it")
	vc_assert_no_new_runtimes(snapshot, "destroy_ship(force = TRUE, ignore_crew = TRUE) on a hull with a keyed crewman aboard - the bluespace jump's path")
	vc_lifecycle_assert_hull_gone(bravo, bravo_port, "destroy_ship(force = TRUE)")
	vc_lifecycle_assert_markers_gone(bravo_markers, "destroy_ship(force = TRUE)")

	if(!isnull(crewman))
		if(!QDELETED(crewman))
			TEST_FAIL("the crewman survived the hull being destroyed out from under them, in nullspace, for the rest of the round")
		if(length(GLOB.mob_living_list) != living_baseline)
			TEST_FAIL("GLOB.mob_living_list moved from [living_baseline] to [length(GLOB.mob_living_list)] across a hull teardown - intoTheSunset() only nullspaces the mobs aboard, so a hull that is not swept leaks its whole crew")
		var/mob/dead/observer/rescued
		for(var/mob/dead/observer/candidate as anything in GLOB.dead_mob_list)
			if(isnull(candidate))
				continue
			if(candidate.ckey == expected_ckey)
				rescued = candidate
				break
		if(isnull(rescued))
			TEST_FAIL("the crewman's key did not end up on an observer. destroy_ship() deleted the body without ghostizing it, which costs a runtime per crewman in /mob/Destroy() and drops the player out of the round with nothing to come back as")
		else
			// Hand the key back before deleting the observer - a mob deleted while
			// it still holds a ckey is the very runtime this spec is about.
			rescued.key = null
			qdel(rescued)

		// Belt and braces, and it is not optional: on any failure path above the
		// key may still be sitting on a live mob, and /datum/unit_test/Destroy()
		// will qdel the allocated crewman after Run() returns. A mob deleted
		// holding a ckey stack_trace()s, and a runtime raised after Run() has
		// returned fails the RUN (world.dm) while failing no TEST - the single
		// most confusing way for this suite to go red. Strip the key from
		// whatever still holds it before leaving.
		for(var/mob/holder as anything in GLOB.mob_list)
			if(isnull(holder) || QDELETED(holder))
				continue
			if(holder.ckey == expected_ckey)
				holder.key = null

	// ---- spec 4: a suffix freed by a teardown must not be re-minted -----------
	var/obj/structure/overmap/ship/charlie = vc_create_test_ship()
	if(isnull(charlie))
		vc_lifecycle_release_all(built)
		return
	built += charlie

	var/charlie_id = charlie.shuttle?.shuttle_id
	if(charlie_id == bravo_id)
		TEST_FAIL("a hull built after two teardowns was minted the shuttle_id '[charlie_id]', which a previously built hull already used. Suffixes are being recycled")
	if(charlie_id == alpha_id)
		TEST_FAIL("a hull built after two teardowns was minted the shuttle_id '[charlie_id]', which a previously built hull already used. Suffixes are being recycled")
	if(!isnull(base_id) && SSshuttle.assoc_mobile[base_id] < counter_after_bravo)
		TEST_FAIL("SSshuttle.assoc_mobile\[\"[base_id]\"\] is below its own high-water mark after a create/destroy/create cycle")
	vc_lifecycle_assert_unique_live_ids("after a create, destroy and create cycle")

	// ---- spec 1: the third mouth of the funnel, a bare qdel of the ship -------
	var/obj/docking_port/mobile/voidcrew/charlie_port = charlie.shuttle
	var/list/charlie_markers = vc_lifecycle_landmarks_aboard(charlie_port)

	snapshot = vc_runtime_snapshot()
	qdel(charlie)
	vc_assert_no_new_runtimes(snapshot, "a bare qdel() of an overmap ship - the path every NPC hull killed in combat and every admin delete takes")
	vc_lifecycle_assert_hull_gone(charlie, charlie_port, "qdel() of the overmap ship")
	vc_lifecycle_assert_markers_gone(charlie_markers, "qdel() of the overmap ship")

	// Aggregate leak check. Compared with <= rather than == on purpose: the
	// window spans three map loads, and a world that SHRANK its landmark list
	// is never the leak being hunted. The identity checks above are the strict
	// half - they fail on a single surviving marker.
	if(length(GLOB.landmarks_list) > landmarks_before)
		TEST_FAIL("GLOB.landmarks_list grew from [landmarks_before] to [length(GLOB.landmarks_list)] across three create-and-destroy cycles")
	if(length(GLOB.start_landmarks_list) > start_landmarks_before)
		TEST_FAIL("GLOB.start_landmarks_list grew from [start_landmarks_before] to [length(GLOB.start_landmarks_list)] across three create-and-destroy cycles - every despawned hull is leaving its job spawn points standing")

	vc_lifecycle_release_all(built)

/// Releases anything the production teardowns above left standing. Every entry is
/// expected to be gone already; vc_release_test_ship() returns TRUE for a deleted
/// ship, so a failure here means a production path did not finish its own job.
/datum/unit_test/voidcrew_ship_teardown_lifecycle/proc/vc_lifecycle_release_all(list/built)
	for(var/obj/structure/overmap/ship/leftover as anything in built)
		if(isnull(leftover))
			continue
		if(!vc_release_test_ship(leftover))
			TEST_FAIL("a fixture hull needed the test fixture to finish tearing it down after the production path had already run")

/// The registrations a torn-down hull must leave clear. Mirrors what
/// vc_release_test_ship() verifies, asserted here against the game's own paths.
/datum/unit_test/voidcrew_ship_teardown_lifecycle/proc/vc_lifecycle_assert_hull_gone(obj/structure/overmap/ship/ship, obj/docking_port/mobile/voidcrew/port, path_name)
	if(!QDELETED(ship))
		TEST_FAIL("[path_name] left the overmap ship alive")
	if(ship in SSovermap.simulated_ships)
		TEST_FAIL("[path_name] left the ship in SSovermap.simulated_ships - the derelict sweeper will keep visiting it")
	if(isnull(port))
		TEST_FAIL("[path_name] was asked to tear down a hull with no docking port")
		return
	if(!QDELETED(port))
		TEST_FAIL("[path_name] left the hull's docking port alive. A bare qdel() on a docking port is a no-op that still nulls shuttle_areas, and the leftover port is found FIRST by the next load_template() scan of that block")
	if(port in SSshuttle.mobile_docking_ports)
		TEST_FAIL("[path_name] left the hull's port in SSshuttle.mobile_docking_ports")
	if(!isnull(port.assigned_transit))
		TEST_FAIL("[path_name] left the hull holding a transit docking port - its turf reservation is leaked for the rest of the round")
	if(!isnull(port.occupied_site_key))
		TEST_FAIL("[path_name] left an entry in GLOB.ship_site_occupancy, so that berth can never be released")
	if(length(port.linked_z_levels))
		TEST_FAIL("[path_name] left the hull claiming [length(port.linked_z_levels)] z-level(s) - they stay flagged ZTRAIT_STATION for the rest of the round")

/// The exact landmarks that were aboard are gone, by identity.
/datum/unit_test/voidcrew_ship_teardown_lifecycle/proc/vc_lifecycle_assert_markers_gone(list/markers, path_name)
	var/survivors = 0
	for(var/obj/effect/landmark/marker as anything in markers)
		if(isnull(marker))
			continue
		if(!QDELETED(marker))
			survivors++
			continue
		if(marker in GLOB.landmarks_list)
			survivors++
	if(survivors)
		TEST_FAIL("[survivors] of [length(markers)] landmark(s) aboard the hull survived [path_name]. /turf/proc/empty() spares landmarks on purpose, so jumpToNullSpace() has to sweep them itself - without that, every hull that ever dies leaves its spawn points standing on ground handed to the next tenant")

/// No two LIVE mobile ports share a shuttle_id.
/datum/unit_test/voidcrew_ship_teardown_lifecycle/proc/vc_lifecycle_assert_unique_live_ids(context)
	var/list/seen = list()
	for(var/obj/docking_port/mobile/port as anything in SSshuttle.mobile_docking_ports)
		if(isnull(port) || QDELETED(port))
			continue
		if(seen[port.shuttle_id])
			TEST_FAIL("two live mobile docking ports share the shuttle_id '[port.shuttle_id]' [context]. linkup() resolves an id to a port, so the newer hull's machinery is wired to the older hull's port")
			return
		seen[port.shuttle_id] = TRUE

// ---------------------------------------------------------------------------
// C. Weather sites deregister when they are deleted
// ---------------------------------------------------------------------------

/**
 * # qdel(site) leaves nothing behind in SSweather
 *
 * `SSweather` holds a site in three places at once - `weather_sites`,
 * `weather_sites_by_zlevel["z"]` and `eligible_sites` - and
 * `/datum/weather_site/Destroy()` used to clear none of them. Production always
 * called `unregister_weather_site()` first, so it was latent rather than live,
 * but a site left in `eligible_sites` keeps arming storm timers forever and
 * `fire()` keeps rolling storms onto a deleted datum. Anyone reaching for a
 * plain `qdel(site)` - and the ship, planet and ruin teardown paths all delete
 * datums that own sites - armed it.
 *
 * Registered on the **live** `SSweather` on purpose: `Destroy()` deregisters
 * from the real subsystem and nothing else, so an isolated scheduler would make
 * this test pass no matter what the destructor did. That is a live hazard - a
 * site in the real `eligible_sites` can have a storm rolled onto the unit-test
 * z-level - so the window between registration and deletion contains **no
 * sleep**, which is what keeps the MC from firing inside it. The weather types
 * are the fixture's own zero-probability stand-ins, which
 * `SSweather/Initialize()` never registers against a real z-level.
 *
 * Membership is checked by site id rather than by reference: a hard delete
 * nulls every reference to the datum in place, which would turn a genuine leak
 * into a vacuous pass.
 */
/datum/unit_test/voidcrew_weather_site_qdel_deregistration

/datum/unit_test/voidcrew_weather_site_qdel_deregistration/Run()
	var/site_id = "vc-lifecycle-qdel-[REF(src)]"
	var/snapshot = vc_runtime_snapshot()

	var/datum/weather_site/site = vc_create_test_weather_site(
		list(
			/datum/weather/vc_fixture_selfcheck = 60,
			/datum/weather/vc_fixture_selfcheck/alternate = 40,
		),
		registry = SSweather,
		id = site_id,
	)
	if(isnull(site))
		return
	var/z_value = site.z_value

	// No sleep from here to the qdel - see the header.
	qdel(site)

	if(vc_lifecycle_site_id_present(SSweather.weather_sites, site_id))
		TEST_FAIL("a qdel'd weather site is still in SSweather.weather_sites, so get_weather_sites_on_z() and every consumer of it keep being handed a deleted datum")
	if(vc_lifecycle_site_id_present(SSweather.eligible_sites, site_id))
		TEST_FAIL("a qdel'd weather site is still in SSweather.eligible_sites, so fire() keeps rolling storms out of it and arming timers on a deleted datum for the rest of the round")
	var/list/on_z = SSweather.weather_sites_by_zlevel["[z_value]"]
	if(vc_lifecycle_site_id_present(on_z, site_id))
		TEST_FAIL("a qdel'd weather site is still indexed under z[z_value], so get_weather_site_for_coords() keeps resolving to it")

	// Deregistration has to stay idempotent: the production order is
	// unregister-then-qdel, so the destructor's own call is the second one on
	// every real path. This is also the cleanup for anything left above.
	SSweather.unregister_weather_site(site)
	vc_assert_no_new_runtimes(snapshot, "registering a weather site on the live SSweather, deleting it, and unregistering it a second time")

// ---------------------------------------------------------------------------
// D. The mapless stand-in never reaches a listing that feeds create_ship()
// ---------------------------------------------------------------------------

/**
 * # Every listed hull can actually be built
 *
 * `/datum/map_template/shuttle/voidcrew/commissioned` is a stand-in for a hull
 * that was never loaded from a `.dmm`: `setup_from_template()` is what supplies
 * `ship_team`, `job_slots` and `ship_account`, none of which needs a map, so
 * the scratch-built-vessel path hands it this template to satisfy that proc.
 * Its `New()` deliberately does not call `..()`, so it has no `shuttle_id`, no
 * `mappath` and no measured size.
 *
 * Handed to `create_ship()` it `stack_trace()`s - and a single `stack_trace()`
 * denies `clean_run.lk` for the whole suite, which is exactly what happened
 * until `SSovermap.spawn_initial_ship()`'s UNIT_TESTS branch learned to skip
 * it. That branch builds one ship for **every**
 * `/datum/map_template/shuttle/voidcrew` subtype at boot and skips only this
 * one, so the invariant it rests on is asserted directly here: a subtype either
 * declares a `suffix` - which is what `preloadShuttleTemplates()` gates
 * registration on, and what makes `mappath` resolve - or it is the commissioned
 * stand-in.
 *
 * Deliberately not duplicated from /datum/unit_test/voidcrew_ship_catalog_rules
 * (voidcrew_ship_hulls.dm), which already covers pricing shape, `catalog_desc`,
 * `player_hidden`, theme/module defaults and roundstart eligibility, or from
 * voidcrew_hull_dock_rotation, which already reads every purchasable hull's
 * `mappath` off disk.
 */
/datum/unit_test/voidcrew_ship_catalog_mapless_standin

/datum/unit_test/voidcrew_ship_catalog_mapless_standin/Run()
	ensure_ship_catalog_initialized()
	ensure_ship_upgrades_initialized()

	var/datum/map_template/shuttle/voidcrew/commissioned/standin = /datum/map_template/shuttle/voidcrew/commissioned
	TEST_ASSERT(isnull(initial(standin.suffix)), "the commissioned stand-in has been given a suffix. That is the one thing keeping it out of SSmapping.shuttle_templates, and from there out of the ship catalog - preloadShuttleTemplates() skips a shuttle template with no suffix and registers every other one. With a suffix it reaches the catalog, and create_ship() stack_traces on it because it has no .dmm on disk")

	for(var/datum/map_template/shuttle/voidcrew/template as anything in GLOB.ship_catalog_templates)
		if(istype(template, /datum/map_template/shuttle/voidcrew/commissioned))
			TEST_FAIL("the mapless commissioned stand-in is in GLOB.ship_catalog_templates")
	for(var/datum/map_template/shuttle/voidcrew/template as anything in get_purchasable_ship_templates())
		if(istype(template, /datum/map_template/shuttle/voidcrew/commissioned))
			TEST_FAIL("the mapless commissioned stand-in is on the purchasable hull shelf. A player buying it gets a stack_trace and no ship")
	for(var/datum/map_template/shuttle/voidcrew/template as anything in get_roundstart_hull_templates())
		if(istype(template, /datum/map_template/shuttle/voidcrew/commissioned))
			TEST_FAIL("the mapless commissioned stand-in is in the roundstart hull pool, so the fleet roll can deal a hull that cannot be built")

	// The invariant SSovermap.spawn_initial_ship()'s UNIT_TESTS branch rests on.
	for(var/datum/map_template/shuttle/voidcrew/hull_type as anything in subtypesof(/datum/map_template/shuttle/voidcrew))
		if(initial(hull_type.suffix))
			continue
		if(ispath(hull_type, /datum/map_template/shuttle/voidcrew/commissioned))
			continue
		TEST_FAIL("[hull_type] declares no suffix, so its mappath resolves to a file that does not exist. Under UNIT_TESTS, SSovermap.spawn_initial_ship() calls create_ship() on every /datum/map_template/shuttle/voidcrew subtype and skips only the commissioned stand-in, so this template stack_traces at boot and denies clean_run.lk for the entire suite")

	// A hull with no measured size cannot be built either: load_template() sizes
	// the transit reservation from width/height and
	// calculate_docking_port_information() takes the port bounds from them.
	var/checked = 0
	for(var/datum/map_template/shuttle/voidcrew/template as anything in get_purchasable_ship_templates())
		checked++
		if(template.width <= 0 || template.height <= 0)
			TEST_FAIL("[template.type] is on the shelf measuring [template.width]x[template.height]. preload_size() never read its map, so create_ship() cannot reserve transit volume for it or work out its docking port bounds")
	TEST_ASSERT(checked >= 5, "only [checked] purchasable hulls were checked - the shelf has collapsed")
