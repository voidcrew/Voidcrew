/**
 * # Shared behavioural fixtures for the voidcrew test fleet
 *
 * The fork's own test doctrine (voidcrew_helpers.dm's header) says a test world has no
 * ship, no planet and no live SSovermap. Two of those three are wrong: SSovermap
 * initialises ungated on top of MetaStation and spawn_initial_ship() has an
 * `#ifdef UNIT_TESTS` branch that loads every /datum/map_template/shuttle/voidcrew
 * subtype at boot. What is genuinely absent is a **weather site**, because sites are
 * only registered from apply_planet_level_traits(), which is reached only on a real
 * planet build. That gap is fixture 3 below.
 *
 * The other gap is not capability, it is adoption. 66 upstream test files run a real
 * interaction chain; 31 of them reach ClickOn through click_wrapper() at
 * unit_test.dm:200. Of 36 fork test files, exactly one performs any interaction at all
 * (voidcrew_cyberware.dm, via put_in_hands), and **no fork test has ever clicked
 * anything**. Fixture 1 exists to end that.
 *
 * ## Why "the real chain" is the whole point
 *
 * Three shipped outages, all of which a staged-precondition test passes straight
 * through:
 *
 *  - **Ship R&D dead.** Upstream #93967 rewrote /obj/item/doMove so the IN_INVENTORY
 *    branch falls off the end with no `return`. forceMove() now yields **null for a
 *    held item even though the move succeeds**. The fork's sole call site
 *    (research/server.dm) reads that return, decides the disk "won't fit!", and traps
 *    it in contents with no eject path. The bug only reproduces when the disk is
 *    genuinely IN_INVENTORY - setting `disk.loc = user` does not set the flag, and a
 *    test that stages it that way passes on a broken tree.
 *  - **Cyberware Cradle-only.** An upstream surgery rework changed
 *    pre_surgical_insertion()'s second argument from the patient to an
 *    /obj/item/bodypart. Thirteen behavioural tests in voidcrew_cyberware.dm passed
 *    through the outage because every one of them called grant_install_context()
 *    itself instead of entering through the real proc. The single test that went the
 *    long way round is the only one that would have caught it.
 *  - **rdconsole locked.** #94114 gave the circuitboard `locked = TRUE` plus
 *    req_access. Every mapped console answered "Console is locked" to a player. No
 *    structural assertion sees that; a click does.
 *
 * So: enter at the real player entry point, never stage your own preconditions.
 * These helpers are the entry point.
 *
 * ## Shape and conventions
 *
 * Everything here is a proc on /datum/unit_test rather than a global proc, for two
 * reasons. TEST_FAIL/TEST_ASSERT expand to `Fail(reason, __FILE__, __LINE__)` on
 * `src`, so they only compile inside a /datum/unit_test proc; and allocate() and
 * run_loc_floor_bottom_left are instance state. Hanging procs off the abstract base
 * type adds no new test to the run - it is exactly what click_wrapper() already does.
 *
 * Every helper that can fail **records its own TEST_FAIL and then returns a falsy
 * value**. TEST_ASSERT expands to `return Fail(...)`, which returns from the *helper*,
 * not from your Run(). Always branch on the return:
 *
 *     if(!vc_hold_item(user, disk))
 *         return
 *
 * NOTE: unit-test files compile at the `code/modules/unit_tests` include position,
 * which is BEFORE `voidcrew/_DEFINES/`. Fork defines do not exist here. Use literals
 * with a comment naming the define, per the voidcrew_loot.dm convention. Upstream
 * defines (IN_INVENTORY, RIGHT_CLICK, ITEM_INTERACT_*) are fine.
 */

/**
 * Puts `held` into `user`'s active hand through the real inventory path and proves it
 * landed IN_INVENTORY.
 *
 * This is the fixture the R&D outage needed. `put_in_active_hand()` is the player
 * path; it forceMoves the item into the mob, slots it into held_items and calls
 * has_equipped(), and has_equipped() is the **only** thing that sets
 * `item_flags |= IN_INVENTORY`. Assigning `item.loc = user` reaches none of it, and
 * the whole /obj/item/doMove IN_INVENTORY branch - the branch that lost its `return`
 * upstream and killed ship R&D - is unreachable without the flag. A test that stages
 * the loc by hand tests a code path players never take.
 *
 * The return value of put_in_hand() is deliberately NOT trusted here. It ends with
 * `if(!has_equipped(...)) return FALSE`, and has_equipped() returns
 * `item.on_equipped(...)`, which is falsy for plenty of perfectly ordinary items. The
 * item is in the hand and flagged; the proc still says FALSE. State is the ground
 * truth, so this asserts on state.
 *
 * * user - the mob doing the holding. Any /mob/living with hands;
 *   /mob/living/carbon/human/consistent is the suite's standard.
 * * held - the item.
 * * forced - bypasses can_put_in_hand()/put_in_hand_check(). Defaults FALSE so the
 *   helper takes the same path a player does (a standing consistent human passes the
 *   check). Pass TRUE only when the mob is deliberately incapacitated and the pickup
 *   itself is not what you are testing.
 *
 * Returns TRUE on success, FALSE (with a recorded failure) otherwise.
 */
/datum/unit_test/proc/vc_hold_item(mob/living/user, obj/item/held, forced = FALSE)
	if(isnull(user) || isnull(held))
		TEST_FAIL("vc_hold_item() was given a null [isnull(user) ? "user" : "item"]")
		return FALSE
	if(QDELETED(user) || QDELETED(held))
		TEST_FAIL("vc_hold_item() was given a qdeleted [QDELETED(user) ? "user ([user])" : "item ([held])"]")
		return FALSE

	user.put_in_active_hand(held, forced = forced)

	if(user.get_active_held_item() != held)
		TEST_FAIL("[held.type] did not reach [user.type]'s active hand[forced ? "" : " - if the mob is deliberately incapacitated, pass forced = TRUE"]. \
			The active hand holds [user.get_active_held_item() || "nothing"].")
		return FALSE
	if(held.loc != user)
		TEST_FAIL("[held.type] is in [user.type]'s held_items but its loc is [held.loc || "null"], not the mob. The inventory move did not complete.")
		return FALSE
	// The load-bearing assertion. Everything /obj/item/doMove does for a held item -
	// including the branch upstream #93967 left without a return - keys off this flag.
	if(!(held.item_flags & IN_INVENTORY))
		TEST_FAIL("[held.type] is held by [user.type] but does not carry IN_INVENTORY. has_equipped() did not run, so this item is not really in an inventory \
			and every code path that branches on the flag is unreachable.")
		return FALSE
	return TRUE

/**
 * Left-clicks `target` with `held` held in `user`'s active hand, through ClickOn.
 *
 * The genuine player path, in order: ClickOn -> reach/obscured resolution ->
 * melee_attack_chain -> target.base_item_interaction -> tool_act -> <tool>_act, and
 * only past that into pre_attack/attackby. Nothing here calls melee_attack_chain
 * directly, because the half of the chain that ClickOn owns (DirectAccess,
 * IsReachableBy, IsObscured, next_move) is where several of the fork's own traps live -
 * a machine that is unreachable in-game is not "tested" by a direct chain call.
 *
 * combat_mode is forced OFF by default and that is not cosmetic:
 * /atom/base_item_interaction runs `if(!user.combat_mode)` around tool_act, so with
 * combat mode ON a screwdriver bashes the machine instead of opening its panel. Every
 * non-combat interaction test wants FALSE. Pass TRUE only when you are testing a hit.
 *
 * The user is moved onto the target's turf when it is not already adjacent, because
 * ClickOn silently returns for anything out of reach and a test that never noticed
 * would pass vacuously.
 *
 * * user - the clicker.
 * * target - what is being clicked.
 * * held - the item. Put into the active hand for you if it is not already there.
 * * modifiers - click params. Defaults to a plain left click. Pass
 *   `list(RIGHT_CLICK = TRUE, BUTTON = RIGHT_CLICK)` for a right click, or use
 *   vc_right_click_with_item().
 * * combat_mode - see above.
 *
 * Returns TRUE if the click was **delivered**. It says nothing about what the click
 * did; assert that yourself against the target's state.
 */
/datum/unit_test/proc/vc_click_with_item(mob/living/user, atom/target, obj/item/held, list/modifiers = null, combat_mode = FALSE)
	if(isnull(user) || isnull(target) || isnull(held))
		TEST_FAIL("vc_click_with_item() was given a null argument (user [user || "null"], target [target || "null"], item [held || "null"])")
		return FALSE
	if(QDELETED(user) || QDELETED(target) || QDELETED(held))
		TEST_FAIL("vc_click_with_item() was given a qdeleted argument (user [user], target [target], item [held])")
		return FALSE

	if(user.get_active_held_item() != held)
		if(!vc_hold_item(user, held))
			return FALSE

	user.set_combat_mode(combat_mode, silent = TRUE, force = TRUE)

	if(!vc_bring_within_reach(user, target))
		return FALSE

	click_wrapper(user, target, modifiers || list(LEFT_CLICK = TRUE, BUTTON = LEFT_CLICK))
	return TRUE

/**
 * Right-clicks `target` with `held`. Thin wrapper over vc_click_with_item().
 *
 * A right click is a different chain, not a flag on the same one: melee_attack_chain
 * reads RIGHT_CLICK out of the modifiers and routes through pre_attack_secondary and
 * attackby_secondary, and base_item_interaction swaps item_interaction for
 * item_interaction_secondary and interact_with_atom for interact_with_atom_secondary.
 * A fork override of one has no bearing on the other, so it needs its own coverage.
 */
/datum/unit_test/proc/vc_right_click_with_item(mob/living/user, atom/target, obj/item/held, combat_mode = FALSE)
	return vc_click_with_item(user, target, held, list(RIGHT_CLICK = TRUE, BUTTON = RIGHT_CLICK), combat_mode)

/**
 * Bare-hand left-clicks `target` through ClickOn -> UnarmedAttack -> attack_hand.
 *
 * With an empty active hand ClickOn routes to UnarmedAttack() rather than
 * melee_attack_chain(), which is a genuinely separate entry point:
 * /atom/proc/attack_hand and the interaction_flags_atom / _try_interact gating around
 * it. Machines that open a tgui window, buttons, levers and everything with
 * `interaction_flags_machine` are all reached this way and by nothing else.
 *
 * * empty_hands - drops everything the mob is holding first, because a stray item in
 *   the active hand silently converts this into an item attack and the test then
 *   measures the wrong chain. Pass FALSE only if you have already emptied them.
 *
 * Returns TRUE if the click was delivered.
 */
/datum/unit_test/proc/vc_click_bare_hand(mob/living/user, atom/target, list/modifiers = null, empty_hands = TRUE, combat_mode = FALSE)
	if(isnull(user) || isnull(target))
		TEST_FAIL("vc_click_bare_hand() was given a null [isnull(user) ? "user" : "target"]")
		return FALSE
	if(QDELETED(user) || QDELETED(target))
		TEST_FAIL("vc_click_bare_hand() was given a qdeleted [QDELETED(user) ? "user ([user])" : "target ([target])"]")
		return FALSE

	if(empty_hands)
		user.drop_all_held_items()
	if(user.get_active_held_item())
		TEST_FAIL("[user.type] still holds [user.get_active_held_item()] in its active hand, so this would be an item attack, not a bare-hand click")
		return FALSE

	user.set_combat_mode(combat_mode, silent = TRUE, force = TRUE)

	if(!vc_bring_within_reach(user, target))
		return FALSE

	click_wrapper(user, target, modifiers || list(LEFT_CLICK = TRUE, BUTTON = LEFT_CLICK))
	return TRUE

/**
 * Puts `user` where ClickOn will accept a click on `target`.
 *
 * ClickOn resolves reach through `A in DirectAccess()` (self, loc and contents) and
 * then `A.IsReachableBy(src, W?.reach)`, and **returns silently** when neither holds.
 * A test whose clicker was never adjacent therefore passes without asserting
 * anything - the exact vacuous shape this fixture set exists to stamp out - so an
 * unreachable target is a hard failure here rather than a quiet no-op.
 *
 * Moving onto the target's own turf rather than beside it keeps this working for
 * dense machines and for targets sitting inside another atom's contents.
 */
/datum/unit_test/proc/vc_bring_within_reach(mob/living/user, atom/target)
	if(user.Adjacent(target))
		return TRUE
	var/turf/destination = get_turf(target)
	if(isnull(destination))
		TEST_FAIL("[target.type] is not on a turf ([target.loc || "null"] loc), so no click can reach it")
		return FALSE
	user.forceMove(destination)
	if(!user.Adjacent(target))
		TEST_FAIL("[user.type] stands on [target.type]'s own turf and still does not read as adjacent to it - ClickOn would return silently and this test would assert nothing")
		return FALSE
	return TRUE

/**
 * # Assembled-ship fixture
 *
 * Loads a real hull the way a player buys one: SSshuttle.create_ship() with an optional
 * theme and upgrade selections, which is the single path every purchased ship, every
 * roundstart fleet hull and every admin spawn goes through. The four existing hull tests
 * only ever load a template for *preview* (SSshuttle.load_template() + unload_preview(),
 * voidcrew_ship_hulls.dm:306 and :372) and never assemble one, so nothing today asserts
 * that the modules a player paid for are the modules that end up in the hull.
 *
 * ## What you get back
 *
 * An /obj/structure/overmap/ship (this fork has no /datum/overmap/ship - the overmap
 * object *is* the ship). From there:
 *
 *     ship.shuttle                 -> /obj/docking_port/mobile/voidcrew
 *     ship.shuttle.shuttle_areas   -> assoc area -> TRUE, every compartment
 *     ship.shuttle.return_turfs()  -> every hull tile
 *     ship.source_template         -> the template it was built from
 *     ship.job_slots / ship.manifest / ship.ship_account
 *
 * ## Cost
 *
 * This is a real map load. It sleeps three ways - UNTIL(!shuttle_loading), the template
 * load itself, and initiate_docking()'s CHECK_TICK yields - and it toggles SSair.can_fire
 * around the load. Default hull is the smallest purchasable one by footprint for that
 * reason. Set `priority = TEST_LONGER` on any test that builds one, and build one per
 * test rather than one per assertion.
 *
 * * hull_type - a /datum/map_template/shuttle/voidcrew TYPE PATH. Defaults to the
 *   smallest purchasable hull. Pass `.type`, never a catalog instance: create_ship()
 *   rewrites suffix/theme/mappath on whatever instance it is handed, so passing the
 *   shared catalog object corrupts it for every later caller (see overmap.dm:1030).
 * * upgrade_selections - assoc slot_key -> /datum/ship_upgrade_module, the format
 *   create_ship() expects. Null lets modular_map_root fall back to each slot's default
 *   module. Build a non-default set with get_modules_for_ship_slot(hull_type, theme_id,
 *   slot_key), or pass randomize = TRUE.
 * * theme - a /datum/ship_theme. Null makes create_ship() pick the hull's default theme
 *   if it is themed, which is what a player who never touched the theme picker gets.
 * * randomize - rolls a random theme and a random module into every slot via
 *   roll_random_ship_theme() / roll_random_upgrade_selections(), the same procs the
 *   roundstart fleet uses. Off by default: a fixture that varies between runs turns a
 *   real regression into an intermittent one.
 *
 * Returns the ship, or null with a recorded failure. ALWAYS pair with
 * vc_release_test_ship() in the same Run(), including on your failure paths - a leaked
 * hull holds a transit reservation and a ZTRAIT_STATION claim for the rest of the run.
 */
/datum/unit_test/proc/vc_create_test_ship(hull_type = null, list/upgrade_selections = null, datum/ship_theme/theme = null, randomize = FALSE)
	ensure_ship_upgrades_initialized()

	if(isnull(hull_type))
		hull_type = vc_smallest_purchasable_hull_type()
	if(isnull(hull_type))
		TEST_FAIL("vc_create_test_ship() found no purchasable hull template to build - get_purchasable_ship_templates() came back empty")
		return null
	if(!ispath(hull_type, /datum/map_template/shuttle/voidcrew))
		TEST_FAIL("vc_create_test_ship() wants a /datum/map_template/shuttle/voidcrew type path, got [hull_type]")
		return null

	if(randomize)
		theme ||= roll_random_ship_theme(hull_type)
		if(isnull(upgrade_selections))
			var/list/hulls = vc_test_voidcrew_hull_templates()
			var/datum/map_template/shuttle/voidcrew/catalog_entry = hulls[hull_type]
			if(catalog_entry)
				upgrade_selections = roll_random_upgrade_selections(catalog_entry, theme)

	var/obj/structure/overmap/ship/ship = SSshuttle.create_ship(hull_type, upgrade_selections, theme)

	// create_ship() returns FALSE, not null, on all five of its failure paths, and a
	// refusal for want of transit map volume is a capacity condition rather than a code
	// fault - name it so a full test world does not read as a broken hull.
	if(!ship || !istype(ship))
		TEST_FAIL("SSshuttle.create_ship([hull_type]) returned [ship || "FALSE"][SSmapping.at_z_level_ceiling() ? " - world.maxz is at its ceiling, so this is transit capacity, not the hull" : ""]")
		return null
	if(isnull(ship.shuttle))
		TEST_FAIL("[hull_type] built an overmap ship with no mobile docking port - the map load did not complete")
		vc_release_test_ship(ship)
		return null
	if(!islist(ship.shuttle.shuttle_areas) || !length(ship.shuttle.shuttle_areas))
		TEST_FAIL("[hull_type] built with an empty shuttle_areas - the hull has no registered compartments and every move would leave it behind")
		vc_release_test_ship(ship)
		return null

	return ship

/// The purchasable hull with the smallest footprint, as a type path. Picked by area
/// rather than by price because this is a speed choice, not an economy one - the
/// catalog's own sort is cheapest-first and cost does not track map size.
/datum/unit_test/proc/vc_smallest_purchasable_hull_type()
	var/datum/map_template/shuttle/voidcrew/smallest
	for(var/datum/map_template/shuttle/voidcrew/candidate as anything in get_purchasable_ship_templates())
		if(!candidate.width || !candidate.height)
			continue
		if(isnull(smallest) || (candidate.width * candidate.height) < (smallest.width * smallest.height))
			smallest = candidate
	return smallest?.type

/**
 * Tears down a ship built by vc_create_test_ship(), leak-free and runtime-free.
 *
 * ## Why this does not simply call despawn_derelict()
 *
 * It would fail the suite. The fork's own teardown - despawn_derelict() at ship.dm:1349
 * and destroy_ship(force = TRUE) at ship.dm:1324 - calls shuttle.intoTheSunset() while
 * `port.current_ship` is still set. intoTheSunset() ends in jumpToNullSpace(), which ends
 * in qdel(port, force = TRUE), and /obj/docking_port/mobile/voidcrew/Destroy() answers a
 * still-set current_ship with a stack_trace(). stack_trace() is CRASH() with the proc kept
 * alive, so it increments GLOB.total_runtimes - and world.dm:317 refuses to write
 * clean_run.lk with a non-zero runtime count. One despawned fixture ship would fail the
 * whole run regardless of what any test asserted. (This is a live fork defect, not a test
 * artefact: every ship despawn in a real round emits that runtime too. Reported, not
 * fixed here.)
 *
 * So the link is broken by hand first, which is the pattern voidcrew_ship_access.dm:57-58
 * already uses on a stub port. Nulling current_ship early is safe for deregistration:
 * unlink_from_z_level(), release_station_level_link() and set_site_occupancy() read
 * shuttle_areas, linked_z_levels and occupied_site_key, never current_ship.
 *
 * ## The order, and why each step is where it is
 *
 *  1. **Delete the mobs aboard.** intoTheSunset() only ghostizes and nullspaces them, so
 *     every mob aboard survives in GLOB.mob_list for the rest of the run. Correct for the
 *     round-end escape shuttle it was written for; a straight leak here. This mirrors
 *     despawn_derelict()'s own sweep, which exists for the same reason.
 *  2. **Break the two-way link.** `port.current_ship = null` so the port destructor does
 *     not stack_trace; `ship.shuttle = null` so /obj/structure/overmap/ship/Destroy() does
 *     not then call intoTheSunset() a second time on an already-deleted port. In
 *     production the *only* thing that nulls ship.shuttle during teardown is the inside of
 *     that stack_trace branch, so skipping the branch means doing it ourselves.
 *  3. **The port, forced.** intoTheSunset() -> jumpToNullSpace() returns every hull turf
 *     to uninitialised space, ScrapeAways the shuttle skipover baseturf and finishes with
 *     qdel(port, force = TRUE). `force = TRUE` is not optional anywhere:
 *     /obj/docking_port/Destroy() returns QDEL_HINT_LETMELIVE unless forced, so a bare
 *     qdel() is a NO-OP that still runs /obj/docking_port/mobile/Destroy() first - which
 *     nulls shuttle_areas. What survives is a live, non-QDELETED port with a null
 *     shuttle_areas standing on that ground, and /turf/proc/empty() never removes docking
 *     ports. The next SSshuttle.load_template() scans its fresh block, finds that leftover
 *     port FIRST, hands it back as preview_shuttle and qdels the real hull's port as a
 *     duplicate. That is how a botched teardown once killed a different test entirely
 *     (voidcrew_hull_survey.dm:280-288).
 *  4. **The transit reservation, via the port.** The mobile port destructor force-qdels
 *     assigned_transit, and /obj/docking_port/stationary/transit/Destroy() only frees
 *     reserved_area and drops itself from SSshuttle.transit_docking_ports `if(force)`.
 *     Ports before ground, always.
 *  5. **The ship datum last**, so Destroy() finds a null shuttle and just unwinds its own
 *     registrations: SSovermap.simulated_ships, ship_account, ship_team
 *     (GLOB.antagonist_teams), combat_alarm, missions, waypoints.
 *
 * Returns TRUE when everything verified clean.
 */
/datum/unit_test/proc/vc_release_test_ship(obj/structure/overmap/ship/ship)
	if(isnull(ship))
		return TRUE
	if(QDELETED(ship))
		return TRUE

	var/obj/docking_port/mobile/voidcrew/port = ship.shuttle

	if(port)
		// 1. Mobs and landmarks aboard, before anything moves them somewhere we cannot
		//    find them. Both leak, for different reasons:
		//
		//    - Mobs: intoTheSunset() only ghostizes and NULLSPACES them, so they survive in
		//      GLOB.mob_list for the rest of the run. despawn_derelict() sweeps them by hand
		//      for exactly this reason and documents it at ship.dm:1397-1410.
		//    - Landmarks: /turf/proc/empty() (change_turf.dm:9) typecaches
		//      /obj/effect/landmark into `ignored_atoms` right alongside /obj/docking_port
		//      and never deletes them, and jumpToNullSpace() is the only thing that touches
		//      these turfs. create_ship() spawns a blobstart and an observer_start aboard
		//      every hull, and the hull's own .dmm maps its job spawn points, so every
		//      create-and-destroy cycle leaves them all behind in GLOB.landmarks_list.
		//      Nothing in the teardown path removes them, so the fixture does.
		for(var/turf/hull_turf as anything in port.return_turfs())
			if(!hull_turf)
				continue
			for(var/mob/living/aboard in hull_turf.get_all_contents())
				if(QDELETED(aboard))
					continue
				aboard.ghostize(FALSE) // a disconnected player's body still holds their key
				qdel(aboard)
			for(var/obj/effect/landmark/marker in hull_turf.get_all_contents())
				if(QDELETED(marker))
					continue
				qdel(marker)

		// 2. Break the link both ways before the port destructor runs.
		port.current_ship = null
		ship.shuttle = null

		// 3+4. Ground back to space, transit reservation freed, port force-qdeleted.
		port.intoTheSunset()

	// 5. The ship datum.
	qdel(ship)

	. = TRUE
	if(!QDELETED(ship))
		TEST_FAIL("the fixture ship refused deletion and is still live on the overmap")
		. = FALSE
	if(ship in SSovermap.simulated_ships)
		TEST_FAIL("the fixture ship survived teardown in SSovermap.simulated_ships - the derelict sweeper will keep visiting it")
		. = FALSE
	if(port)
		if(!QDELETED(port))
			TEST_FAIL("the fixture hull's docking port survived teardown - a bare qdel() on a docking port is a no-op, this needed force = TRUE")
			. = FALSE
		if(port in SSshuttle.mobile_docking_ports)
			TEST_FAIL("the fixture hull's port survived teardown in SSshuttle.mobile_docking_ports")
			. = FALSE
		if(!isnull(port.assigned_transit))
			TEST_FAIL("the fixture hull still holds a transit docking port after teardown - its turf reservation is leaked for the rest of the run")
			. = FALSE
		if(!isnull(port.occupied_site_key))
			TEST_FAIL("the fixture hull still holds an entry in GLOB.ship_site_occupancy after teardown")
			. = FALSE
		if(length(port.linked_z_levels))
			TEST_FAIL("the fixture hull still claims [length(port.linked_z_levels)] z-level\s ([port.linked_z_levels.Join(", ")]) - those levels stay flagged ZTRAIT_STATION for the rest of the run")
			. = FALSE
	return .

/**
 * # Weather-site fixture
 *
 * The one genuine environmental gap in the test world. /datum/weather_site instances
 * are built in apply_planet_level_traits() (planet.dm), which is reached only when a
 * ship visits a planet marker and the interior actually builds - so a CI world holds
 * zero sites, and voidcrew_weather_sites.dm hand-rolls its own. Both of its fixture
 * sites carry exactly one weather type at weight 100, which means SSweather's
 * pick_weight() **selection roll is never exercised**; a multi-entry weight table is
 * the whole reason this fixture takes a list.
 *
 * ## Which registry
 *
 * `registry` defaults to a fresh isolated /datum/controller/subsystem/weather/unit_test
 * (its New() returns immediately, so it never joins the MC), and that default is
 * deliberate. SSweather.fire() rolls storms out of `eligible_sites`, and
 * register_weather_site() adds any site with a non-empty weather_types to it. Register
 * on the live SSweather and the real subsystem will, on some later tick, run an actual
 * storm on the unit-test z-level - painting overlays and firing WEATHER_MOBS effects
 * into whatever test happens to be running at the time. Pass `SSweather` explicitly
 * when you specifically mean to test live registration, and tear down in the same Run().
 *
 * * weather_types - assoc typepath -> weight, fed straight to pick_weight(). Give it
 *   at least two entries if the selection roll is anywhere near what you are testing.
 * * z_value - defaults to the test room's own z.
 * * footprint_rect - list(low_x, low_y, high_x, high_y). Null leaves the site
 *   rect-less, which is what makes it the z-level fallback site in
 *   get_weather_site_for_coords(). Defaults to the run_loc box.
 * * owned_areas - area INSTANCES the storm may paint. Null means the site falls back
 *   to a z-wide get_areas(area_type) sweep in setup_weather_areas().
 * * area_scoped - TRUE forbids that fallback outright, which is how a planet site is
 *   built. A scoped site with no live areas is `awaiting_owned_areas()` and will not
 *   roll.
 *
 * Returns the registered site, or null with a recorded failure. Always pair with
 * vc_release_test_weather_site(), passing the same registry.
 */
/datum/unit_test/proc/vc_create_test_weather_site(
	list/weather_types,
	z_value = null,
	list/footprint_rect = null,
	list/owned_areas = null,
	area_scoped = FALSE,
	datum/controller/subsystem/weather/registry = null,
	id = null,
)
	if(isnull(registry))
		registry = allocate(/datum/controller/subsystem/weather/unit_test)
	if(isnull(registry))
		TEST_FAIL("vc_create_test_weather_site() could not stand up an isolated weather scheduler")
		return null

	if(isnull(z_value))
		z_value = run_loc_floor_bottom_left?.z
	if(isnull(z_value))
		TEST_FAIL("vc_create_test_weather_site() has no z-level to build on - the test room turf is missing")
		return null

	if(isnull(footprint_rect) && run_loc_floor_bottom_left && run_loc_floor_top_right)
		footprint_rect = list(
			run_loc_floor_bottom_left.x,
			run_loc_floor_bottom_left.y,
			run_loc_floor_top_right.x,
			run_loc_floor_top_right.y,
		)
	if(!isnull(footprint_rect) && length(footprint_rect) != 4)
		TEST_FAIL("vc_create_test_weather_site() wants footprint_rect as list(low_x, low_y, high_x, high_y), got [length(footprint_rect)] entr\s")
		return null

	// New(id, z_value, weather_types, downtime_multiplier). weather_types is Copy()d by
	// the constructor, so a literal passed in here is not aliased into the site.
	var/datum/weather_site/site = new(id || "vc-fixture-[REF(src)]", z_value, weather_types)
	if(!isnull(footprint_rect))
		site.add_footprint_rect(footprint_rect[1], footprint_rect[2], footprint_rect[3], footprint_rect[4])
	if(length(owned_areas))
		site.set_owned_areas(owned_areas)
	if(area_scoped)
		site.set_area_scoped()

	registry.register_weather_site(site)

	if(!(site in registry.weather_sites))
		TEST_FAIL("[registry.type].register_weather_site() did not add the fixture site to weather_sites")
		return null
	if(length(weather_types) && !(site in registry.eligible_sites))
		TEST_FAIL("a fixture site with [length(weather_types)] weather type\s did not become eligible to roll - the scheduler will never select from it")
		return null
	var/list/on_z = registry.weather_sites_by_zlevel["[z_value]"]
	if(!(site in on_z))
		TEST_FAIL("the fixture site is not indexed under z[z_value] - get_weather_site_for_coords() will never resolve it")
		return null

	return site

/**
 * Deregisters and destroys a site built by vc_create_test_weather_site(), and proves
 * nothing is left pointing at it.
 *
 * Order matters. /datum/weather_site/Destroy() calls clear_next_hit() and
 * end_active_weather() but **does not remove the site from any of SSweather's three
 * registries** - weather_sites, weather_sites_by_zlevel and eligible_sites. A bare
 * qdel(site) therefore leaves three dangling entries behind, and on the live SSweather
 * a site that stays in eligible_sites keeps arming storm timers for the rest of the
 * round. unregister_weather_site() is the deregistration path and it does the timer
 * and storm cleanup too, so it goes first.
 *
 * The active storm is captured before the unregister, because end_active_weather()
 * nulls site.active_weather on its way past. end() leaves the storm to a deferred
 * QDEL_IN(src, 0); the explicit qdel here forces it now rather than letting a
 * half-dead /datum/weather sit in the GC queue holding impacted_areas references into
 * the next test. This mirrors what voidcrew_weather_sites.dm does by hand.
 *
 * Returns TRUE when the site is gone from all three registries.
 */
/datum/unit_test/proc/vc_release_test_weather_site(datum/weather_site/site, datum/controller/subsystem/weather/registry)
	if(isnull(site))
		return TRUE
	if(isnull(registry))
		TEST_FAIL("vc_release_test_weather_site() needs the same registry the site was registered with - a site left registered keeps arming storm timers")
		return FALSE

	var/z_value = site.z_value
	var/datum/weather/storm = site.active_weather

	registry.unregister_weather_site(site)
	if(!isnull(storm))
		qdel(storm)

	. = TRUE
	if(site in registry.weather_sites)
		TEST_FAIL("[site.id] survived unregister_weather_site() in weather_sites")
		. = FALSE
	if(site in registry.eligible_sites)
		TEST_FAIL("[site.id] survived unregister_weather_site() in eligible_sites - it will keep rolling storms")
		. = FALSE
	var/list/on_z = registry.weather_sites_by_zlevel["[z_value]"]
	if(site in on_z)
		TEST_FAIL("[site.id] survived unregister_weather_site() in weather_sites_by_zlevel\[\"[z_value]\"\]")
		. = FALSE
	if(!isnull(site.next_hit_timer))
		TEST_FAIL("[site.id] still holds an armed next_hit_timer after teardown")
		. = FALSE

	qdel(site)
	return .

/// Weather types that exist only as weight-table keys for the fixture self-check.
/// probability stays 0 so SSweather/Initialize() never registers them against a real
/// z-level, and the names are distinct so run_weather()'s name lookup cannot collide
/// with a shipped storm. Nothing ever instantiates them: the self-check registers its
/// site on an isolated scheduler it never fires, which is the whole point of the
/// multi-entry table - the SELECTION is what needs to be assertable, not the storm.
/datum/weather/vc_fixture_selfcheck
	name = "fixture self-check drizzle"
	probability = 0

/datum/weather/vc_fixture_selfcheck/alternate
	name = "fixture self-check squall"

/**
 * # The fixtures in this file still work
 *
 * Exercises every fixture once. Fixtures rot silently: a helper that quietly stops
 * reaching the code path it claims to reach turns every test built on it into a vacuous
 * pass, which is strictly worse than no test at all - that is exactly how
 * voidcrew_missions.dm ended up with two tests that assert nothing and report green.
 *
 * The assertions here are deliberately about the *fixture's* contract, not about the
 * machine, the hull or the weather it happens to touch:
 *
 *  - a held item genuinely carries IN_INVENTORY (the R&D outage's precondition),
 *  - a click with that item reaches tool_act and changes the target (so the chain is
 *    real, not a call into a stub),
 *  - a bare-hand click enters attack_hand instead (a different entry point, not a flag),
 *  - a ship builds with registered compartments and tears down leaving no ship, no port,
 *    no transit reservation and no net growth in the registries it touched,
 *  - a weather site registers, resolves from coordinates, and deregisters from all three
 *    of SSweather's lists.
 *
 * TEST_LONGER because vc_create_test_ship() is a real map load.
 */
/datum/unit_test/voidcrew_fixture_selfcheck
	priority = TEST_LONGER

/datum/unit_test/voidcrew_fixture_selfcheck/Run()
	check_interaction_fixtures()
	check_weather_site_fixture()
	check_ship_fixture()

/datum/unit_test/voidcrew_fixture_selfcheck/proc/check_interaction_fixtures()
	var/mob/living/carbon/human/user = allocate(/mob/living/carbon/human/consistent)
	var/obj/item/screwdriver/driver = allocate(/obj/item/screwdriver)
	var/obj/machinery/cell_charger/charger = allocate(/obj/machinery/cell_charger)

	if(!vc_hold_item(user, driver))
		return
	// Restated rather than left to the helper: this is the exact precondition the ship-R&D
	// outage needed, and if the helper ever stops establishing it, every test built on it
	// silently starts testing a path players never take.
	TEST_ASSERT(driver.item_flags & IN_INVENTORY, "vc_hold_item() reported success without leaving the item IN_INVENTORY")

	// A screwdriver on an idle cell charger runs default_deconstruction_screwdriver(), which
	// toggles the maintenance hatch and nothing else. If the hatch does not move, the click
	// never reached tool_act - either combat_mode was left on (base_item_interaction wraps
	// tool_act in `if(!user.combat_mode)`) or ClickOn refused the click for reach.
	var/hatch_before = charger.panel_open
	if(!vc_click_with_item(user, charger, driver))
		return
	TEST_ASSERT_NOTEQUAL(charger.panel_open, hatch_before, "a held screwdriver clicked on a cell charger did not toggle its maintenance hatch - the click never reached tool_act, so nothing built on vc_click_with_item() is testing a real interaction")

	// The secondary chain is a separate route (pre_attack_secondary / attackby_secondary,
	// item_interaction_secondary / interact_with_atom_secondary), so it gets its own
	// delivery check. What it does to a cell charger is the charger's business.
	TEST_ASSERT(vc_right_click_with_item(user, charger, driver), "vc_right_click_with_item() failed to deliver a right click")

	// Bare hand enters UnarmedAttack -> attack_hand instead of melee_attack_chain, and
	// /obj/item/attack_hand picks the item up. Both halves of the fixture are under test
	// here: the hands really are emptied, and the attack_hand chain really is entered.
	var/obj/item/screwdriver/loose = allocate(/obj/item/screwdriver)
	if(!vc_click_bare_hand(user, loose))
		return
	TEST_ASSERT_EQUAL(user.get_active_held_item(), loose, "a bare-hand click on an item lying on the floor did not pick it up - the attack_hand chain was not entered")
	TEST_ASSERT(loose.item_flags & IN_INVENTORY, "an item picked up by a bare-hand click did not end up IN_INVENTORY")

/datum/unit_test/voidcrew_fixture_selfcheck/proc/check_weather_site_fixture()
	var/datum/controller/subsystem/weather/registry = allocate(/datum/controller/subsystem/weather/unit_test)
	TEST_ASSERT_NOTNULL(registry, "could not stand up an isolated weather scheduler for the fixture self-check")

	// Two entries at different weights on purpose. Both sites in voidcrew_weather_sites.dm
	// carry exactly one type at weight 100, which is why pick_weight() - the scheduler's
	// selection roll - has never been exercised by any test in this fork.
	var/list/weights = list(
		/datum/weather/vc_fixture_selfcheck = 60,
		/datum/weather/vc_fixture_selfcheck/alternate = 40,
	)
	var/datum/weather_site/site = vc_create_test_weather_site(weights, registry = registry)
	if(isnull(site))
		return

	TEST_ASSERT(site.has_footprint(), "the fixture site was built without a footprint rect, so it would act as the whole z-level's fallback site instead of a scoped one")
	TEST_ASSERT_EQUAL(length(site.weather_types), 2, "the fixture site did not keep its multi-entry weight table - the scheduler's selection roll cannot be tested through it")

	// The fixture is worthless if the site cannot be found the way the game finds one.
	var/turf/probe = run_loc_floor_bottom_left
	TEST_ASSERT_EQUAL(registry.get_weather_site_for_coords(probe.x, probe.y, probe.z), site, "get_weather_site_for_coords() did not resolve the fixture site from inside its own footprint")

	vc_release_test_weather_site(site, registry)

/datum/unit_test/voidcrew_fixture_selfcheck/proc/check_ship_fixture()
	// Baselines for the leak check. Compared with <= rather than ==: SSovermap's own
	// derelict sweeper may despawn an unrelated hull between these two reads, and a
	// SHRINKING registry is never the leak we are hunting.
	var/ships_before = length(SSovermap.simulated_ships)
	var/ports_before = length(SSshuttle.mobile_docking_ports)
	var/landmarks_before = length(GLOB.landmarks_list)

	var/obj/structure/overmap/ship/ship = vc_create_test_ship()
	if(isnull(ship))
		return

	TEST_ASSERT_NOTNULL(ship.shuttle, "the fixture ship came back with no mobile docking port")
	TEST_ASSERT(length(ship.shuttle.shuttle_areas) > 0, "the fixture ship came back with no registered compartments")
	TEST_ASSERT(length(ship.shuttle.return_turfs()) > 0, "the fixture ship came back with no hull turfs - the map never loaded")
	TEST_ASSERT(ship in SSovermap.simulated_ships, "the fixture ship did not register itself in SSovermap.simulated_ships, so it is not a real ship as far as the rest of the game is concerned")

	if(!vc_release_test_ship(ship))
		return

	TEST_ASSERT(length(SSovermap.simulated_ships) <= ships_before, "tearing down the fixture ship left SSovermap.simulated_ships larger than it started")
	TEST_ASSERT(length(SSshuttle.mobile_docking_ports) <= ports_before, "tearing down the fixture ship leaked a mobile docking port into SSshuttle.mobile_docking_ports")
	// create_ship() spawns a blobstart and an observer_start landmark aboard every hull, and
	// the game's own teardown never removes them: /turf/proc/empty() explicitly ignores
	// /obj/effect/landmark. vc_release_test_ship() sweeps them itself, and this is what
	// proves that sweep still runs - without it every fixture ship grows GLOB.landmarks_list
	// by at least two entries that live until the round ends.
	TEST_ASSERT(length(GLOB.landmarks_list) <= landmarks_before, "tearing down the fixture ship left its landmarks in GLOB.landmarks_list - the fixture's landmark sweep did not run, and /turf/proc/empty() will not do it for you")

/**
 * # tgui action fixtures
 *
 * Everything above this line drives the *click* half of a player's interaction. This half
 * drives the other one: the tgui window a click opens, and the actions a player fires out of
 * it. Every machine in the fork with a screen is reached this way and by nothing else.
 *
 * ## Why "just call ui_act()" does not work
 *
 * A test that calls `machine.ui_act("power", list())` with no `ui` argument is not testing
 * anything, and on most machines it is worse than that:
 *
 *  - **The parent bails and reports success.** /datum/proc/ui_act (external.dm:99) opens with
 *    `if(!ui || ui.status != UI_INTERACTIVE) return TRUE` (external.dm:103-104). The near
 *    universal handler shape is `. = ..()` then `if(.) return`, so a null `ui` makes the
 *    parent hand back TRUE and the handler returns before it ever reaches its switch. The
 *    action is silently discarded and the caller cannot tell. Confirmed in the fork on
 *    /obj/machinery/computer/helm/ui_act (voidcrew/modules/shuttle/helm/_helm.dm:810-813) and
 *    /datum/outpost_trader_ui/shop/ui_act (voidcrew/modules/trade/trader_npc.dm:471-474).
 *  - **On machinery it is a runtime, not a bail.** /obj/machinery/ui_act
 *    (code/game/machinery/_machinery.dm:711) reads `var/mob/user = ui.user` on its FIRST line
 *    (:712), before any ..(), and /obj/machinery/computer/ui_act does the same with
 *    `issilicon(ui.user)` (code/game/machinery/computer/_computer.dm:175). A null ui throws
 *    there, and under UNIT_TESTS world/Error fails the current test
 *    (code/modules/error_handler/error_handler.dm:250-252).
 *  - **`usr` is not null in production.** tgui routes an action through
 *    DEFAULT_QUEUE_OR_CALL_VERB(VERB_CALLBACK(...)) (tgui.dm:356). The callback records `usr`
 *    at construction (code/datums/callback.dm:68-69), and it is constructed inside
 *    /datum/tgui/on_message, which runs off /client/Topic where `usr` is the player. Invoke
 *    then pushes that mob back into `usr` (callback.dm:95-102). So inside a real ui_act,
 *    `usr` IS the tgui user - and plenty of handlers read it and nothing else:
 *    /obj/machinery/computer/rdconsole/ui_act opens with `var/mob/living/user = usr`
 *    (voidcrew/modules/research/edits/_rd_consoles.dm:63-64), and the helm's whole crew gate
 *    is `is_crew_member(usr)` (_helm.dm:816). A test that leaves `usr` null tests a machine
 *    no player can reach.
 *
 * So the driver builds a real /datum/tgui, resolves its status through the real gate, and
 * sets `usr` for the duration of the call. It does NOT call /datum/tgui/proc/open(), which
 * returns FALSE immediately without a client (tgui.dm:85-87) and would need a window, a
 * window pool and an asset flush - none of which any handler reads.
 *
 * ## The one gate that gets neutralised, and why it has to be
 *
 * /mob/proc/shared_ui_interaction (code/modules/tgui/states.dm:62) opens with
 * `if(!client && !HAS_TRAIT(src, TRAIT_PRESERVE_UI_WITHOUT_CLIENT)) return UI_CLOSE` (:64). A
 * test mob has no client and cannot be given one (see the fake-presence fixture below), so
 * without the trait EVERY action would be refused and the driver would be useless.
 * TRAIT_PRESERVE_UI_WITHOUT_CLIENT is the shipped escape hatch for exactly this and is what
 * upstream's own tests use (strippable.dm:7, mafia.dm:30), always with TRAIT_SOURCE_UNIT_TESTS.
 *
 * That is the ONLY thing suppressed. Everything else in the gate still runs for real and
 * still refuses for real: the distance and view ladder in
 * /mob/living/proc/shared_living_ui_distance (states.dm:103-121), the MOBILITY_UI check
 * (states.dm:74-77), IS_UNCONSCIOUS_OR_CRIT and `incapacitated` (states.dm:65-69), the
 * ISADVANCEDTOOLUSER demotion in /mob/living/default_can_use_topic
 * (code/modules/tgui/states/default.dm:21-26), and any ui_status the src_object overrides
 * itself (the fork has three: chrome_cradle.dm:458, ware_military_body.dm:817,
 * console_ui.dm:45).
 */

/// The raw return value of the last handler ui_act() driven by vc_ui_act().
///
/// This is NOT a success flag and must never be asserted on as one. /datum/tgui/on_act_message
/// (tgui.dm:396) feeds it straight into `if(...) SStgui.update_uis(src_object)`, so its only
/// meaning is "the window should refresh". Handlers return TRUE for a refused purchase, a
/// denied access check and an out-of-stock SKU alike - see the four `return TRUE` refusal
/// branches in /datum/outpost_trader_ui/shop/ui_act (voidcrew/modules/trade/trader_npc.dm:485-498).
/// Assert on the machine's state instead. This exists for the rare test whose subject genuinely
/// is the refresh contract.
/datum/unit_test/var/vc_last_ui_act_return

/// Mob -> what vc_fake_client_presence() faked for it, so vc_clear_fake_client_presence() can
/// undo exactly that and nothing else. See the fake-presence fixture below.
/datum/unit_test/var/list/vc_faked_presence

/// Trait source for the tgui fixture's TRAIT_PRESERVE_UI_WITHOUT_CLIENT grant.
///
/// Deliberately NOT TRAIT_SOURCE_UNIT_TESTS. strippable.dm:7 and mafia.dm:30 grant the same
/// trait under that source, and ADD_TRAIT/REMOVE_TRAIT are source-scoped: sharing the string
/// would let vc_close_test_ui() strip a grant a test made for its own reasons, silently
/// changing that test's subject. A private source makes the grant and its removal symmetric no
/// matter who else is holding the trait.
#define VC_TGUI_FIXTURE_TRAIT_SOURCE "vc_tgui_fixture"

/**
 * Reads the tgui status a mob would get on a src_object, without touching anything.
 *
 * The gate, unmodified: `machine.ui_status(user, machine.ui_state(user))`, which is the same
 * pair /datum/tgui/proc/process_status() runs (tgui.dm:338-341) and the same shape
 * strippable.dm:13 asserts on. Nothing is granted, nothing is moved, the mob is left exactly
 * as it was found.
 *
 * Use this for the negative case - proving a machine REFUSES someone. vc_ui_act() grants
 * TRAIT_PRESERVE_UI_WITHOUT_CLIENT for the length of its call, so a refusal test written
 * through the driver would be measuring the fixture rather than the machine.
 *
 * Returns one of UI_INTERACTIVE / UI_UPDATE / UI_DISABLED / UI_CLOSE (2 / 1 / 0 / -1,
 * code/__DEFINES/tgui.dm:2-8), or null with a recorded failure on bad input. Note that a
 * clientless mob reads UI_CLOSE on essentially everything, by states.dm:64 - that is the
 * baseline, not a bug.
 */
/datum/unit_test/proc/vc_ui_status(mob/user, atom/machine)
	if(isnull(user) || isnull(machine))
		TEST_FAIL("vc_ui_status() was given a null [isnull(user) ? "user" : "src_object"]")
		return null
	if(QDELETED(user) || QDELETED(machine))
		TEST_FAIL("vc_ui_status() was given a qdeleted [QDELETED(user) ? "user ([user])" : "src_object ([machine])"]")
		return null
	var/datum/ui_state/state = machine.ui_state(user)
	if(isnull(state))
		TEST_FAIL("[machine.type].ui_state() returned null, so ui_status() can only ever answer UI_CLOSE (states.dm:22-23)")
		return null
	return machine.ui_status(user, state)

/**
 * Stands up a real, interactive /datum/tgui for `user` on `machine`, or fails loudly.
 *
 * Use vc_ui_act() unless you need the window itself - to drive several actions through one
 * datum, or to assert on ui.status. Pair with vc_close_test_ui(), always, including on your
 * failure paths: the trait this grants stays on the mob until that call.
 *
 * What it does, in order:
 *
 *  1. **Moves the user into reach.** The src_object's ui_host(user) (external.dm:135) is the
 *     physical anchor - for a machine that is the machine, for a /datum ui it is whatever the
 *     datum hangs off. Reuses vc_bring_within_reach() so an out-of-range user is a hard
 *     failure rather than a silent UI_CLOSE. Skipped when the host already shares the user's
 *     turf (which covers a host held in the user's own inventory) and when it is not an atom
 *     at all; in both cases the status gate below has the final word anyway.
 *  2. **Grants TRAIT_PRESERVE_UI_WITHOUT_CLIENT** if and only if the mob has no client. See
 *     the header above for why this one gate and no others.
 *  3. **Builds the datum.** /datum/tgui/New (tgui.dm:58-71) logs, stores user and src_object,
 *     and resolves `state` from src_object.ui_state(user) (:68). It does not register with
 *     SStgui or with user.tgui_open_uis - that is SStgui.on_open(), reached only from open()
 *     (tgui.dm:110) - so nothing here leaks into a registry.
 *  4. **Resolves the status for real.** `status` is declared UI_INTERACTIVE (tgui.dm:33), so a
 *     freshly constructed datum lies about the gate. process_status() (tgui.dm:338-341)
 *     overwrites it with src_object.ui_status(user, state), which is the number a player would
 *     actually get.
 *  5. **Fails loudly if that is not UI_INTERACTIVE.** A refused action is the vacuous-pass
 *     shape this whole file exists to stamp out: /datum/ui_act returns TRUE for a
 *     non-interactive ui (external.dm:103-104), the handler bails, the test asserts nothing
 *     and reports green.
 *
 * Returns the ui, or null with a recorded failure.
 */
/datum/unit_test/proc/vc_open_test_ui(mob/user, atom/machine, interface = "vc-fixture")
	if(isnull(user) || isnull(machine))
		TEST_FAIL("vc_open_test_ui() was given a null [isnull(user) ? "user" : "src_object"]")
		return null
	if(QDELETED(user) || QDELETED(machine))
		TEST_FAIL("vc_open_test_ui() was given a qdeleted [QDELETED(user) ? "user ([user])" : "src_object ([machine])"]")
		return null

	// 1. Reach. ui_host() rather than the src_object itself, because a /datum ui's physical
	//    anchor is not the datum.
	var/datum/host = machine.ui_host(user)
	if(isatom(host))
		var/atom/physical_host = host
		var/turf/host_turf = get_turf(physical_host)
		if(host_turf && host_turf != get_turf(user))
			if(!vc_bring_within_reach(user, physical_host))
				return null

	// 2. The clientless gate, and nothing else. ADD_TRAIT is idempotent per source, so repeated
	//    opens on the same mob do not stack.
	if(!user.client)
		ADD_TRAIT(user, TRAIT_PRESERVE_UI_WITHOUT_CLIENT, VC_TGUI_FIXTURE_TRAIT_SOURCE)

	// 3. The datum.
	var/datum/tgui/window = new(user, machine, interface)
	if(isnull(window.state))
		TEST_FAIL("[machine.type].ui_state() returned null, so this window can never be interactive (states.dm:22-23)")
		qdel(window)
		return null

	// 4+5. The real gate, and a loud refusal.
	window.process_status()
	if(window.status != UI_INTERACTIVE)
		TEST_FAIL("[machine.type] refused [user.type] at the tgui status gate: ui_status() answered [vc_ui_status_name(window.status)], not UI_INTERACTIVE. \
			Nothing driven through this window would reach a handler - /datum/ui_act returns TRUE for a non-interactive ui (external.dm:103-104) and every \
			`. = ..()` handler bails on it. Check distance and view (states.dm:103-121), MOBILITY_UI, stat, and any ui_status the machine overrides itself.")
		qdel(window)
		return null

	return window

/// Tears down a window from vc_open_test_ui() and hands the mob back exactly as it was found.
///
/// REMOVE_TRAIT is source-scoped and the source here is this fixture's own, so a mob that
/// already carried TRAIT_PRESERVE_UI_WITHOUT_CLIENT for its own reasons keeps it - including
/// when it was granted under TRAIT_SOURCE_UNIT_TESTS, the way strippable.dm:7 and mafia.dm:30
/// do it. See VC_TGUI_FIXTURE_TRAIT_SOURCE above.
///
/// qdel rather than /datum/tgui/proc/close(): close() (tgui.dm:133-152) is written for a window
/// that open() actually built and walks release_lock / window.close / SStgui.on_close on the way
/// past, none of which exists here. Destroy() (tgui.dm:73-76) just nulls the two refs.
/datum/unit_test/proc/vc_close_test_ui(mob/user, datum/tgui/window)
	if(!isnull(window))
		qdel(window)
	if(!isnull(user) && !QDELETED(user))
		REMOVE_TRAIT(user, TRAIT_PRESERVE_UI_WITHOUT_CLIENT, VC_TGUI_FIXTURE_TRAIT_SOURCE)
	return TRUE

/**
 * Drives one tgui action on `machine` as `user`, the way a real client does.
 *
 * The whole point of this file, applied to screens: enter at the player's entry point and let
 * every gate on the way refuse for real. See the section header above for what a hand-rolled
 * `machine.ui_act(action, params)` gets wrong.
 *
 * * user - the mob at the console. /mob/living/carbon/human/consistent is the suite's standard.
 * * machine - the src_object the UI belongs to. A machine, or a /datum ui (the parameter is
 *   typed /atom for the common case; DM does not enforce it, and ui_host() resolves the
 *   physical anchor either way).
 * * action - the action string the .tsx sends, exactly. This is the commonest thing to get
 *   wrong and the driver cannot check it for you: an unrecognised action falls off the end of
 *   the handler's switch and looks identical to one that ran and did nothing. Assert on state.
 * * params - the payload. Defaults to an empty list rather than null, because handlers index it
 *   unguarded. Values arrive at a real handler through json_decode (external.dm:213-218), so
 *   numbers are numbers, not text; a `ref` is the REF() string the UI was given.
 * * window - an existing window from vc_open_test_ui(), for multi-action flows. Null builds one
 *   for this call and tears it down again.
 *
 * Returns TRUE if the action was DELIVERED to the handler through an interactive window, FALSE
 * with a recorded failure otherwise - the same contract as vc_click_with_item(). It says
 * nothing about what the action did; assert that against the machine. The handler's own return
 * value lands in vc_last_ui_act_return, which is a refresh flag, not a success flag.
 */
/datum/unit_test/proc/vc_ui_act(mob/user, atom/machine, action, list/params = null, datum/tgui/window = null)
	vc_last_ui_act_return = null

	if(isnull(action) || action == "")
		TEST_FAIL("vc_ui_act() was given an empty action")
		return FALSE
	if(isnull(user) || isnull(machine))
		TEST_FAIL("vc_ui_act(\"[action]\") was given a null [isnull(user) ? "user" : "src_object"]")
		return FALSE
	if(QDELETED(user) || QDELETED(machine))
		TEST_FAIL("vc_ui_act(\"[action]\") was given a qdeleted [QDELETED(user) ? "user ([user])" : "src_object ([machine])"]")
		return FALSE

	var/own_the_window = FALSE
	if(isnull(window))
		window = vc_open_test_ui(user, machine)
		if(isnull(window))
			return FALSE
		own_the_window = TRUE
	else
		// A borrowed window has to actually belong to this machine: handlers read ui.src_object
		// and ui.user, and a mismatched pair produces behaviour no player can reproduce.
		if(window.src_object != machine)
			TEST_FAIL("vc_ui_act(\"[action]\") was handed a window whose src_object is [window.src_object || "null"], not [machine.type]")
			return FALSE
		if(window.user != user)
			TEST_FAIL("vc_ui_act(\"[action]\") was handed a window belonging to [window.user || "nobody"], not [user.type]")
			return FALSE
		if(window.status != UI_INTERACTIVE)
			TEST_FAIL("vc_ui_act(\"[action]\") was handed a [vc_ui_status_name(window.status)] window - the action would be discarded by /datum/ui_act (external.dm:103-104)")
			return FALSE

	// usr is the tgui user inside a real ui_act (see the header). Saved and restored around the
	// call, the pattern alerts.dm:9-18, buckle.dm:9-17 and voidcrew_ship_research.dm:433-436 use.
	var/mob/restore_usr = usr
	usr = user
	vc_last_ui_act_return = machine.ui_act(action, params || list(), window, window.state)
	usr = restore_usr

	if(own_the_window)
		vc_close_test_ui(user, window)
	return TRUE

/// UI_* number -> its name, for failure messages. The numbers are meaningless in a test log.
/// code/__DEFINES/tgui.dm:2-8.
/datum/unit_test/proc/vc_ui_status_name(status)
	switch(status)
		if(UI_INTERACTIVE)
			return "UI_INTERACTIVE"
		if(UI_UPDATE)
			return "UI_UPDATE (visible, but every action is refused)"
		if(UI_DISABLED)
			return "UI_DISABLED"
		if(UI_CLOSE)
			return "UI_CLOSE (the window would not even stay open)"
	return "an unrecognised status ([status])"

/**
 * # Runtime-window fixtures
 *
 * GLOB.total_runtimes (code/modules/error_handler/error_handler.dm:1) is the counter, and it
 * is the right one: world/Error increments it on its first line (:44), before any filtering,
 * and /world/proc/FinishTestRun refuses to write clean_run.lk while it is non-zero
 * (code/game/world.dm:317-318). Neither the per-site silencer (which only bumps
 * total_runtimes_skipped, :161) nor the fork's flood breaker (compiled out entirely under
 * UNIT_TESTS, :102-104) can hide a runtime from it.
 *
 * ## What this adds over "a runtime already fails the test"
 *
 * Under UNIT_TESTS world/Error calls GLOB.current_test.Fail() (error_handler.dm:250-252), so a
 * runtime raised synchronously inside your Run() does already fail your test. Two things this
 * pair gives you that that does not:
 *
 *  - **Attribution.** The suite failure names the runtime's file and line, not the interaction
 *    that caused it. `vc_assert_no_new_runtimes(snap, "helm autopilot toggle")` turns "something
 *    in this 300-line test runtimed" into one sentence.
 *  - **The gap between tests.** GLOB.current_test only points at a test while one is running. A
 *    runtime raised from a `set waitfor = FALSE` proc, a timer or a subsystem tick that lands
 *    after your Run() returns fails the RUN (world.dm:317) while failing no TEST, which is the
 *    single most confusing way for this suite to go red. Snapshot before, wait for whatever you
 *    armed, assert after, and it has a name.
 *
 * ## The one rule
 *
 * The window is process-global. Everything in the world that runtimes between the snapshot and
 * the assert lands in it, including work no part of your test started. Keep the window tight
 * and do not span a sleep unless waiting is the point - if it is, say so in the context message
 * so the next reader knows the blast radius was deliberate.
 */

/// GLOB.total_runtimes right now. Pair with vc_assert_no_new_runtimes().
/datum/unit_test/proc/vc_runtime_snapshot()
	return GLOB.total_runtimes

/// How many runtimes the world has emitted since `snapshot`. Records nothing and fails nothing;
/// this is the readable half, so a test can assert on the count itself.
/datum/unit_test/proc/vc_runtimes_since(snapshot)
	if(isnull(snapshot))
		return 0
	return GLOB.total_runtimes - snapshot

/// Asserts the world has emitted no runtime since `snapshot`.
///
/// * snapshot - the return of vc_runtime_snapshot(), taken before the block under test.
/// * context_msg - what the window covered, in the reader's words. Not optional in practice:
///   the whole value of this helper over the automatic failure is that it names the block.
///
/// Returns TRUE when clean, FALSE with a recorded failure otherwise.
/datum/unit_test/proc/vc_assert_no_new_runtimes(snapshot, context_msg)
	if(isnull(snapshot))
		TEST_FAIL("vc_assert_no_new_runtimes() was given a null snapshot - call vc_runtime_snapshot() BEFORE the block you are covering")
		return FALSE
	var/emitted = vc_runtimes_since(snapshot)
	if(emitted <= 0)
		return TRUE
	TEST_FAIL("[context_msg || "the block under test"] emitted [emitted] runtime\s. The runtime itself is in the log above with its own file and line; \
		this window is what ties it to that block. A non-zero GLOB.total_runtimes fails the whole run at world.dm:317 whether or not any test went red.")
	return FALSE

/**
 * # Fake player presence
 *
 * ## The hard limit, first
 *
 * **A /client cannot be faked.** It is engine-owned: instances exist because a connection
 * exists, /client/New (code/modules/client/client_procs.dm:255) is an override BYOND calls
 * rather than a constructor game code invokes, and there is not one `new /client` anywhere in
 * code/, voidcrew/ or tools/. So `mob.client` stays null, and every check that reads it stays
 * unfooled - permanently, not pending better fixtures.
 *
 * The tree's stand-in, /datum/client_interface (code/datums/mocking/client.dm:2) hung off
 * `mob.mock_client` (code/modules/mob/mob_defines.dm:211), does not help here either. It is
 * read only through GET_CLIENT() (code/__HELPERS/mobs.dm:447) and IS_CLIENT_OR_MOCK(), and
 * **not one of the presence registries below consults either macro** - they all read bare
 * `.client`. mock_client makes a mob look like a player to say(), prefs and the status bar. It
 * does not make it PRESENT.
 *
 * What is fakeable is the three derived registries that production maintains *from* a client,
 * and those are what almost everything actually reads.
 *
 * ## The three legs
 *
 *  1. **SSmobs.clients_by_zlevel** (code/controllers/subsystem/mobs.dm:10) - a list indexed by
 *     z holding /mob/living instances. Production's sole writer is /mob/living/proc/update_z
 *     (code/modules/mob/living/living.dm:1983), which cannot be used here: it bails at
 *     `if(isnull(client))` (:1988) before ever reaching the `+= src` (:2005). So the fixture
 *     writes the list directly, exactly as voidcrew_simple_mob_ai.dm:29 already does by hand.
 *  2. **GLOB.player_list** (code/_globalvars/lists/mobs.dm:25) - "all mobs with clients
 *     attached". Written directly, NOT through /mob/proc/add_to_player_list
 *     (code/modules/mob/mob_lists.dm:47): that proc routes a dead mob into
 *     add_to_current_dead_players(), which derefs `client.holder` unguarded (mob_lists.dm:74).
 *  3. **Spatial-grid client membership** - what modern basic-mob AI reads.
 *     /datum/ai_controller/proc/has_nearby_client (code/datums/ai/_ai_controller.dm:374-380)
 *     scans `grid.client_contents`, never clients_by_zlevel. Done through the production procs
 *     /mob/proc/enable_client_mobs_in_contents (code/game/atoms_movable.dm:1105) and
 *     /mob/proc/clear_important_client_contents (:1119), which have no client requirement of
 *     their own - Login is simply the only thing that normally calls them
 *     (code/modules/mob/login.dm:75).
 *
 * ## What this DOES fool
 *
 * Via clients_by_zlevel: SSidle_npc_wakeup's client pools
 * (voidcrew/controllers/subsystem/idle_npc_wakeup.dm:147), SSplanet_mobs' fauna budget
 * (voidcrew/controllers/subsystem/planet_mobs.dm:237-253), the reservation and footprint
 * teardown guards (voidcrew/datums/map_zones.dm:1028 and :1051,
 * voidcrew/datums/map_footprint.dm:487-495), planet survey player counts
 * (voidcrew/modules/shuttle/survey/_survey_datum.dm:116-129), hostile fauna target acquisition
 * (code/modules/mob/living/simple_animal/hostile/hostile.dm:618-628), spawner/nest gating
 * (code/datums/components/spawner.dm:180-193) and weather alerts
 * (code/datums/weather/weather.dm:504-511).
 *
 * Via GLOB.player_list: get_event_crew() (voidcrew/modules/dynamic_events/ship_event_helpers.dm:16),
 * site_has_living_players() (voidcrew/modules/overmap/code/modules/overmap/ship.dm:1557) and
 * /datum/map_footprint/has_living_players() (voidcrew/datums/map_footprint.dm:262) - none of
 * which derefs .client. Note the consequence for the derelict sweeper: SSovermap's
 * sweep_derelicts() decides "crewed" through has_active_crew()
 * (voidcrew/modules/overmap/code/modules/overmap/ship.dm:1516), whose FIRST clause is
 * get_event_crew(). So a faked mob standing in a shuttle area DOES hold a hull off the
 * crewless clock.
 *
 * Via the grid: basic-mob AI wakeup, i.e. has_nearby_client() and everything
 * /datum/ai_controller/proc/get_active_ai_status (_ai_controller.dm:481-491) hangs off it.
 *
 * ## What this does NOT fool - do not write a test that needs these
 *
 *  - **`mob.client` anywhere.** Including has_active_crew()'s second clause, which derefs
 *    `body.client` (ship.dm:1535); /obj/machinery/.../has_players_aboard()'s `occupant.client`
 *    (voidcrew/modules/npc_ships/code/faction_pirates/nt_patrol.dm:178); and the ~60 other bare
 *    `.client` gates in voidcrew/.
 *  - **GLOB.clients** (code/_globalvars/lists/mobs.dm:1). Written only by /client/New
 *    (client_procs.dm:262) and /client/Del (:623). Out of reach, by construction.
 *  - **get_active_player_list() / get_active_player_count()** (code/__HELPERS/game.dm:151-172).
 *    Requires `player_mob?.client` (:154) and then calls `client.is_afk()` (:158). A faked mob
 *    is skipped silently, so SSdynamic_events' population read is unaffected.
 *  - **GLOB.alive_player_list / dead_player_list.** Maintained behind the same client gate
 *    (mob_lists.dm:14, :54) and deliberately not touched here.
 *  - **A real Login.** No COMSIG_GLOB_PLAYER_LOGIN, no prefs, no HUD, no keyloop.
 *
 * ## Two live hazards
 *
 *  - **kill_achievement derefs the client.** /datum/element/kill_achievement's death handler
 *    walks SSmobs.clients_by_zlevel and calls `player.client.give_award(...)` with no null
 *    guard (code/datums/elements/kill_achievement.dm:54 and :60). A faked mob inside
 *    achievement_range of a dying megafauna WILL runtime there. Do not fake presence in a test
 *    that kills one. (This also contradicts the in-tree claim at tools/instance_census/
 *    ghost_round.dm:523-526 that no consumer derefs .client - it is stale.)
 *  - **The Life() janitor.** /mob/living/Life logs and calls update_z(null) for any mob holding
 *    a `registered_z` without a client, every SSmobs tick (code/modules/mob/living/life.dm:37-39).
 *    This fixture deliberately never sets registered_z, so the entry survives and the log stays
 *    quiet. Do not set it yourself.
 *
 * Nothing here is self-cleaning: /mob/Destroy removes a clientless mob from neither
 * clients_by_zlevel nor GLOB.player_list (remove_from_player_list is a Logout path,
 * mob_lists.dm:59). ALWAYS pair with vc_clear_fake_client_presence(), including on failure
 * paths. The grid leg alone would survive a qdel, via
 * SSspatial_grid.force_remove_from_grid() at code/game/atoms_movable.dm:251.
 *
 * * faker - the mob to make present. Must be /mob/living: clients_by_zlevel holds nothing else
 *   (mobs.dm:9-10, living.dm:2005) and the fork's consumers filter on isliving().
 * * z_registry / in_player_list / in_spatial_grid - turn individual legs off when a test wants
 *   to prove which registry a consumer actually reads. All on by default.
 *
 * Returns TRUE on success, FALSE with a recorded failure otherwise.
 */
/datum/unit_test/proc/vc_fake_client_presence(mob/living/faker, z_registry = TRUE, in_player_list = TRUE, in_spatial_grid = TRUE)
	if(isnull(faker))
		TEST_FAIL("vc_fake_client_presence() was given a null mob")
		return FALSE
	if(QDELETED(faker))
		TEST_FAIL("vc_fake_client_presence() was given a qdeleted mob ([faker])")
		return FALSE
	if(!isliving(faker))
		TEST_FAIL("vc_fake_client_presence() wants a /mob/living, got [faker.type] - SSmobs.clients_by_zlevel holds living mobs only (mobs.dm:9-10) and every fork consumer filters on isliving()")
		return FALSE
	if(faker.client)
		TEST_FAIL("[faker.type] already has a real client, so faking presence would double-register it in every list the real Login path already wrote")
		return FALSE
	if(!isnull(faker.registered_z))
		TEST_FAIL("[faker.type] already holds registered_z = [faker.registered_z]. Something registered it through the real update_z() path; faking on top of that would leave a duplicate behind")
		return FALSE

	var/turf/standing_on = get_turf(faker)
	if(isnull(standing_on))
		TEST_FAIL("[faker.type] is in nullspace, so there is no z-level to be present on")
		return FALSE

	LAZYINITLIST(vc_faked_presence)
	if(vc_faked_presence[faker])
		TEST_FAIL("[faker.type] already has faked presence from this test - clear it before faking again")
		return FALSE

	// Recorded rather than recomputed, because the mob may move before teardown and because a
	// test that turned a leg off must not have that leg undone underneath it.
	var/list/record = list("z" = 0, "player_list" = FALSE, "grid" = FALSE)

	if(z_registry)
		// Dynamically created z-levels can outrun SSmobs.MaxZChanged()'s resize (mobs.dm:19-27),
		// which is why the fork's own consumers bounds-check before indexing
		// (planet_mobs.dm:239, idle_npc_wakeup.dm:147).
		if(!islist(SSmobs.clients_by_zlevel))
			TEST_FAIL("SSmobs.clients_by_zlevel is not a list yet - MaxZChanged() has never run")
			return FALSE
		if(length(SSmobs.clients_by_zlevel) < standing_on.z)
			TEST_FAIL("SSmobs.clients_by_zlevel holds [length(SSmobs.clients_by_zlevel)] level\s but the mob stands on z[standing_on.z] - the list has not caught up with world.maxz")
			return FALSE
		var/list/on_z = SSmobs.clients_by_zlevel[standing_on.z]
		if(!(faker in on_z))
			// `+= faker` on the indexed element, matching production at living.dm:2005 and the
			// hand-rolled version at voidcrew_simple_mob_ai.dm:29.
			SSmobs.clients_by_zlevel[standing_on.z] += faker
		record["z"] = standing_on.z

	if(in_player_list)
		GLOB.player_list |= faker
		record["player_list"] = TRUE

	if(in_spatial_grid)
		faker.enable_client_mobs_in_contents()
		record["grid"] = TRUE

	vc_faked_presence[faker] = record
	return TRUE

/**
 * Undoes exactly what vc_fake_client_presence() faked, and proves nothing is left behind.
 *
 * The z sweep is deliberately over every level rather than just the recorded one: the mob may
 * have moved since, and unlike a real client nothing re-registered it on the way. A leftover
 * entry is not inert - it keeps that z-level's AI awake, holds turf reservations and map
 * footprints off the teardown path (voidcrew/datums/map_zones.dm:1028, :1051) and keeps fauna
 * spawning (voidcrew/controllers/subsystem/planet_mobs.dm:237) for the rest of the run.
 *
 * Returns TRUE when every faked registry is clean.
 */
/datum/unit_test/proc/vc_clear_fake_client_presence(mob/living/faker)
	if(isnull(faker))
		return TRUE
	var/list/record = LAZYACCESS(vc_faked_presence, faker)
	if(isnull(record))
		TEST_FAIL("vc_clear_fake_client_presence() was given [faker.type], which this test never faked presence for")
		return FALSE

	. = TRUE

	if(record["z"])
		for(var/z_index in 1 to length(SSmobs.clients_by_zlevel))
			var/list/on_z = SSmobs.clients_by_zlevel[z_index]
			if(faker in on_z)
				SSmobs.clients_by_zlevel[z_index] -= faker
	if(record["player_list"])
		GLOB.player_list -= faker
	if(record["grid"] && !QDELETED(faker))
		faker.clear_important_client_contents()

	vc_faked_presence -= faker

	if(record["z"])
		for(var/z_index in 1 to length(SSmobs.clients_by_zlevel))
			var/list/on_z = SSmobs.clients_by_zlevel[z_index]
			if(faker in on_z)
				TEST_FAIL("[faker.type] survived fake-presence teardown in SSmobs.clients_by_zlevel\[[z_index]\] - that z-level's AI stays awake and its footprints stay un-reapable for the rest of the run")
				. = FALSE
	if(record["player_list"] && (faker in GLOB.player_list))
		TEST_FAIL("[faker.type] survived fake-presence teardown in GLOB.player_list - every ship it stands on reads as crewed for the rest of the run")
		. = FALSE
	if(record["grid"] && !QDELETED(faker))
		var/datum/spatial_grid_cell/cell = SSspatial_grid.get_cell_of(faker)
		if(cell && (faker in cell.client_contents))
			TEST_FAIL("[faker.type] survived fake-presence teardown in its spatial grid cell's client_contents - nearby AI controllers stay awake")
			. = FALSE

	return .

/**
 * # The tgui, runtime and presence fixtures still work
 *
 * A sibling of voidcrew_fixture_selfcheck rather than three more procs inside it, for two
 * reasons: that test is TEST_LONGER because vc_create_test_ship() is a real map load, and none
 * of what is checked here needs to wait for that bucket; and appending to its Run() would mean
 * editing code this file's other author owns. Same doctrine, though - a fixture that quietly
 * stops reaching the path it claims to reach turns every test built on it into a vacuous pass.
 */
/datum/unit_test/voidcrew_fixture_selfcheck_ui

/datum/unit_test/voidcrew_fixture_selfcheck_ui/Run()
	check_ui_act_driver()
	check_runtime_window()
	check_fake_presence()

/datum/unit_test/voidcrew_fixture_selfcheck_ui/proc/check_ui_act_driver()
	var/mob/living/carbon/human/user = allocate(/mob/living/carbon/human/consistent)
	// A space heater is the simplest real tgui machine in the tree: ui_act("power") calls
	// toggle_power() and flips one bool (code/game/machinery/spaceheater.dm:279-287), it needs
	// no techweb, no powernet and no ship, and its handler is the canonical `. = ..()` /
	// `if(.) return` shape - the exact shape a null `ui` silently defeats.
	var/obj/machinery/space_heater/heater = allocate(/obj/machinery/space_heater)

	if(!vc_bring_within_reach(user, heater))
		return

	// The gate is real, and this is the proof. Standing on the machine's own turf, a clientless
	// mob is still refused, because /mob/proc/shared_ui_interaction returns UI_CLOSE for one
	// (states.dm:64). If this ever reads UI_INTERACTIVE, the driver below has stopped
	// neutralising anything and its "fails loudly when refused" contract is untestable.
	TEST_ASSERT_EQUAL(vc_ui_status(user, heater), UI_CLOSE, "a clientless mob standing on a space heater's own turf was not refused by the tgui status gate - vc_ui_act() would then be granting a trait that changes nothing, and no test could tell a real refusal from a fixture bug")

	TEST_ASSERT(!heater.on, "the fixture self-check's space heater is already on before anything drove it")

	// The load-bearing call. If the driver ever stops building a real interactive window, this
	// is where it shows: /datum/ui_act hands TRUE back for a null or non-interactive ui
	// (external.dm:103-104), space_heater's `if(.) return` bails on it, and `on` never moves.
	if(!vc_ui_act(user, heater, "power"))
		return
	TEST_ASSERT(heater.on, "ui_act(\"power\") driven through vc_ui_act() did not turn the space heater on - the action never reached the handler's switch, so nothing built on this driver is testing a real tgui interaction")

	// The handler's return value rides back out. Asserted as the refresh flag it is, not as
	// success: space_heater sets `. = TRUE` on every branch it recognises (spaceheater.dm:287).
	TEST_ASSERT(vc_last_ui_act_return, "vc_last_ui_act_return did not pick up the handler's return value")

	// params ride through intact. "cool" is HEATER_MODE_COOL, a define local to
	// code/game/machinery/spaceheater.dm and #undef'd at :541, so the literal is the only option
	// here - the voidcrew_loot.dm convention.
	if(!vc_ui_act(user, heater, "mode", list("mode" = "cool")))
		return
	TEST_ASSERT_EQUAL(heater.set_mode, "cool", "ui_act(\"mode\") did not carry its params to the handler - a driver that drops the payload makes every parameterised action untestable")

	// One window, several actions - the multi-step flow a real player produces. Also restores
	// the heater: process_atmos() returns PROCESS_KILL while off (spaceheater.dm:133-137), which
	// is what takes it back out of SSair's machine queue.
	var/datum/tgui/window = vc_open_test_ui(user, heater)
	if(isnull(window))
		return

	// Same discipline as check_fake_presence(): read into locals, tear down, then assert. An
	// assertion firing between open and close would leave the window's
	// TRAIT_PRESERVE_UI_WITHOUT_CLIENT grant on the mob, and the last assertion in this proc is
	// specifically about that trait being handed back.
	var/opened_interactive = (window.status == UI_INTERACTIVE)
	var/second_act_delivered = vc_ui_act(user, heater, "power", window = window)
	var/heater_off_again = !heater.on
	vc_close_test_ui(user, window)
	var/trait_handed_back = !HAS_TRAIT(user, TRAIT_PRESERVE_UI_WITHOUT_CLIENT)

	TEST_ASSERT(opened_interactive, "vc_open_test_ui() returned a window that is not interactive, which it is supposed to refuse to do")
	TEST_ASSERT(second_act_delivered, "a second ui_act(\"power\") through a borrowed window was not delivered - the driver is not reusable")
	TEST_ASSERT(heater_off_again, "a second ui_act(\"power\") through a borrowed window did not turn the heater back off")
	TEST_ASSERT(trait_handed_back, "vc_close_test_ui() left TRAIT_PRESERVE_UI_WITHOUT_CLIENT on the mob - the fixture is supposed to hand it back exactly as it found it")

/datum/unit_test/voidcrew_fixture_selfcheck_ui/proc/check_runtime_window()
	var/snapshot = vc_runtime_snapshot()
	TEST_ASSERT_NOTNULL(snapshot, "vc_runtime_snapshot() returned null - GLOB.total_runtimes is not readable")
	TEST_ASSERT_EQUAL(snapshot, GLOB.total_runtimes, "vc_runtime_snapshot() did not read GLOB.total_runtimes, which is the counter world.dm:317 gates clean_run.lk on")

	// The arithmetic, proven without generating a runtime. A real one cannot be used: world/Error
	// calls GLOB.current_test.Fail() under UNIT_TESTS (error_handler.dm:250-252), so a test that
	// raised one to check the counter would fail itself. Feeding a shifted snapshot to the
	// non-failing half exercises exactly the comparison vc_assert_no_new_runtimes() makes.
	TEST_ASSERT_EQUAL(vc_runtimes_since(snapshot), 0, "vc_runtimes_since() reported drift across two adjacent reads")
	TEST_ASSERT_EQUAL(vc_runtimes_since(snapshot - 3), 3, "vc_runtimes_since() did not measure the gap between the snapshot and the current count - vc_assert_no_new_runtimes() would then pass over real runtimes")

	// A block that genuinely does not runtime, through the assert a test would actually write.
	var/obj/machinery/space_heater/quiet = allocate(/obj/machinery/space_heater)
	quiet.update_appearance()
	TEST_ASSERT(vc_assert_no_new_runtimes(snapshot, "the fixture self-check's quiet block"), "vc_assert_no_new_runtimes() reported runtimes across a block that emitted none")

/datum/unit_test/voidcrew_fixture_selfcheck_ui/proc/check_fake_presence()
	var/mob/living/carbon/human/faker = allocate(/mob/living/carbon/human/consistent)
	var/turf/standing_on = get_turf(faker)
	TEST_ASSERT_NOTNULL(standing_on, "the fixture self-check's presence mob is in nullspace")

	// Bounds first: SSmobs.MaxZChanged() (mobs.dm:19-27) can lag behind a dynamically created
	// z-level, and indexing past the end is a runtime, not a failed assertion.
	TEST_ASSERT(islist(SSmobs.clients_by_zlevel) && length(SSmobs.clients_by_zlevel) >= standing_on.z, "SSmobs.clients_by_zlevel does not cover z[standing_on.z], so nothing below can be checked")

	// Membership, never length: a live server's test z-level may legitimately hold a real client.
	TEST_ASSERT(!(faker in SSmobs.clients_by_zlevel[standing_on.z]), "a freshly allocated clientless mob is already registered in SSmobs.clients_by_zlevel, so the round-trip below would prove nothing")
	TEST_ASSERT(!(faker in GLOB.player_list), "a freshly allocated clientless mob is already in GLOB.player_list")

	if(!vc_fake_client_presence(faker))
		return

	// Everything is READ into locals and the teardown runs before a single assertion fires.
	// TEST_ASSERT expands to `return Fail(...)`, so an assertion between fake and clear would
	// leave a clientless mob registered in SSmobs.clients_by_zlevel and GLOB.player_list for the
	// rest of the run - which is precisely the leak this fixture's teardown exists to prevent,
	// and precisely the state that would make every later test's presence reads lie.
	var/registered_on_z = (faker in SSmobs.clients_by_zlevel[standing_on.z])
	var/registered_in_player_list = (faker in GLOB.player_list)
	// The grid leg, read the way /datum/ai_controller/proc/has_nearby_client reads it
	// (_ai_controller.dm:374-380): the cell's client_contents, not important_recursive_contents.
	var/datum/spatial_grid_cell/cell = SSspatial_grid.get_cell_of(faker)
	var/registered_in_grid = !isnull(cell) && (faker in cell.client_contents)
	var/minted_a_client = !isnull(faker.client)
	var/set_registered_z = !isnull(faker.registered_z)

	var/torn_down = vc_clear_fake_client_presence(faker)
	var/left_on_z = (faker in SSmobs.clients_by_zlevel[standing_on.z])
	var/left_in_player_list = (faker in GLOB.player_list)

	TEST_ASSERT(registered_on_z, "vc_fake_client_presence() did not register the mob in SSmobs.clients_by_zlevel - the fauna, spawner, weather and footprint consumers all read that list and none of them would see it")
	TEST_ASSERT(registered_in_player_list, "vc_fake_client_presence() did not add the mob to GLOB.player_list - get_event_crew() and site_has_living_players() would not see it")
	TEST_ASSERT_NOTNULL(cell, "the fixture self-check's presence mob is not in any spatial grid cell")
	TEST_ASSERT(registered_in_grid, "vc_fake_client_presence() did not put the mob into its spatial grid cell's client_contents - basic-mob AI reads that and nothing else, so no NPC would wake for it")

	// The limit, asserted rather than only documented. If this ever fails, someone has found a
	// way to mint a /client and the whole "what this does not fool" section above is wrong.
	TEST_ASSERT(!minted_a_client, "a fake-presence mob somehow has a real /client - every .client gate in the tree, including has_active_crew() at ship.dm:1535, is documented as unfoolable and would now need re-checking")

	// registered_z must stay null or /mob/living/Life strips the registration within one SSmobs
	// tick and spams Z-TRACKING into the game log (life.dm:37-39).
	TEST_ASSERT(!set_registered_z, "vc_fake_client_presence() set registered_z, which the Life() janitor will undo within 2 seconds while logging about it")

	TEST_ASSERT(torn_down, "vc_clear_fake_client_presence() reported that it could not undo the presence it faked")
	TEST_ASSERT(!left_on_z, "fake presence survived teardown in SSmobs.clients_by_zlevel")
	TEST_ASSERT(!left_in_player_list, "fake presence survived teardown in GLOB.player_list")

#undef VC_TGUI_FIXTURE_TRAIT_SOURCE
