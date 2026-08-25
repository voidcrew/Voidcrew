/**
 * # Virtual domain cost/reward ladder
 *
 * Bitrunning is a pricing ladder: a domain costs points to load and pays
 * points on completion, and the whole loop only holds together because the
 * expensive domains pay more than the cheap ones. A one-character edit
 * anywhere in the roster unwinds that with no other symptom, so this pins the
 * shape of the ladder rather than any individual number.
 *
 * `code/__DEFINES/bitrunning.dm` is included at tgstation.dme:60, long before
 * the unit-test block, so the BITRUNNER_* defines ARE usable here, unlike the
 * fork's own `voidcrew/_DEFINES/`, which compile after this file.
 *
 * Lives in its own voidcrew_ file rather than being appended to the upstream
 * `bitrunning.dm` test so it doesn't collide on the next upstream merge.
 * Upstream's `/datum/unit_test/bitrunner_vdom_settings` already covers key,
 * map_name and completion loot; none of that is repeated here.
 */

/datum/unit_test/voidcrew_bitrunning_domain_ladder

/datum/unit_test/voidcrew_bitrunning_domain_ladder/Run()
	/// The boss arenas, pinned to the two top rungs. These are the domains a
	/// crew saves up for; a slip here makes a megafauna fight cheaper than a
	/// puzzle map.
	var/static/list/arena_costs = list(
		/datum/lazy_template/virtual_domain/ash_drake = BITRUNNER_COST_BOSS,
		/datum/lazy_template/virtual_domain/blood_drunk_miner = BITRUNNER_COST_BOSS,
		/datum/lazy_template/virtual_domain/bubblegum = BITRUNNER_COST_APEX_BOSS,
		/datum/lazy_template/virtual_domain/colossus = BITRUNNER_COST_APEX_BOSS,
		/datum/lazy_template/virtual_domain/hierophant = BITRUNNER_COST_APEX_BOSS,
		/datum/lazy_template/virtual_domain/wendigo = BITRUNNER_COST_APEX_BOSS,
	)
	for(var/datum/lazy_template/virtual_domain/arena_type as anything in arena_costs)
		var/cost = initial(arena_type.cost)
		if(cost != arena_costs[arena_type])
			TEST_FAIL("[arena_type] costs [cost]; the boss arenas sit at [BITRUNNER_COST_BOSS] (boss) and [BITRUNNER_COST_APEX_BOSS] (apex boss), and this one has left that ladder")

	var/checked = 0
	for(var/datum/lazy_template/virtual_domain/domain_type as anything in subtypesof(/datum/lazy_template/virtual_domain))
		if(initial(domain_type.domain_flags) & DOMAIN_TEST_ONLY)
			continue
		checked++
		var/cost = initial(domain_type.cost)
		var/reward = initial(domain_type.reward_points)
		if(cost < BITRUNNER_COST_NONE)
			TEST_FAIL("[domain_type] has a negative cost ([cost])")
		if(reward < BITRUNNER_REWARD_MIN)
			TEST_FAIL("[domain_type] pays [reward] points; a completed run must be worth at least [BITRUNNER_REWARD_MIN] or the loop cannot fund itself")
		// A domain that costs almost nothing and pays like a boss outclasses the
		// entire roster: there is never a reason to run anything else.
		if(cost <= BITRUNNER_COST_LOW && reward >= BITRUNNER_REWARD_HIGH)
			TEST_FAIL("[domain_type] costs [cost] and pays [reward]. A net +[reward - cost] off the cheapest rung outclasses every domain above it. Either reprice it or decide deliberately that this one is the exception.")
		// Anything the console will let a crew scan for hints has to have hints.
		if(initial(domain_type.difficulty) >= BITRUNNER_DIFFICULTY_MEDIUM && !length(initial(domain_type.help_text)))
			TEST_FAIL("[domain_type] is difficulty [initial(domain_type.difficulty)] with no help_text. The domain info ability tells a bitrunner nothing about what the objective is")
	TEST_ASSERT(checked >= 15, "only [checked] virtual domains were checked")

	// The Randomize button must never roll a boss arena: get_random_domain_id()'s
	// pool is bounded at BITRUNNER_COST_BOSS (a deliberate fork edit, a boss dive
	// is a purchase, not a slot-machine outcome). Source-scan trap-door so a quiet
	// revert toward BITRUNNER_COST_EXTREME fails loudly here.
	var/util_source = file2text("code/modules/bitrunning/server/util.dm")
	TEST_ASSERT(findtext(util_source, "init_cost < BITRUNNER_COST_BOSS"), "get_random_domain_id()'s pool is no longer bounded at BITRUNNER_COST_BOSS. The Randomize button can roll a boss arena again")


/**
 * # Virtual domain containment
 *
 * Nothing physical is supposed to leave a domain. The byteforge spawns a *new* crate on
 * the ship; the cache and everything in it is deleted, and `scrub_vdom()` wipes the
 * reservation. A player who gets a real object across that boundary has skipped the
 * entire reward economy.
 *
 * Containment is enforced two ways and this pins both:
 *
 * 1. Area flags on every area a domain map paints. LOCAL_TELEPORT stops a quantum pad
 *    beaming loot to a pad on the ship; `allow_shuttle_docking = FALSE` stops a custom
 *    shuttle being framed up inside VR and flown home. Three of the domain areas subtype
 *    off space/lavaland/icemoon, which all whitelist docking, so the second one has to
 *    be set explicitly or it inherits TRUE.
 *
 * 2. `SSbitrunning.is_domain_turf()`, because (1) can only ever cover tiles a template
 *    painted an area onto. The rest of a reservation - `/area/template_noop` tiles and
 *    everything outside the template footprint - stays in the global /area/space
 *    instance, which has no LOCAL_TELEPORT and does whitelist docking.
 */
/datum/unit_test/voidcrew_bitrunning_containment

/datum/unit_test/voidcrew_bitrunning_containment/Run()
	// (1) Area flags. Walk the maps rather than the type tree: a domain map is free to
	// paint any area at all, and the ones that leak are exactly the ones nobody thought
	// of as "a bitrunning area".
	var/list/checked_areas = list()
	var/maps_read = 0
	for(var/map_path in flist("_maps/virtual_domains/"))
		if(!findtext(map_path, ".dmm"))
			continue
		maps_read++
		// TGM writes each key's area as the last member of the definition, alone on its
		// line and closed by the paren that ends the key: "/area/virtual_domain)". An
		// area carrying var edits opens a brace on that line instead.
		for(var/line in splittext(file2text("_maps/virtual_domains/[map_path]"), "\n"))
			if(copytext(line, 1, 7) != "/area/")
				continue
			var/terminator = findtext(line, ")") || findtext(line, "{")
			var/area_type = terminator && text2path(copytext(line, 1, terminator))
			if(!ispath(area_type, /area) || checked_areas[area_type])
				continue
			checked_areas[area_type] = map_path

	TEST_ASSERT(maps_read >= 20, "only [maps_read] virtual domain maps were read; the scan is looking in the wrong place")
	TEST_ASSERT(length(checked_areas) >= 5, "only [length(checked_areas)] areas were parsed out of the domain maps; the TGM area regex has stopped matching")

	for(var/area/area_type as anything in checked_areas)
		// /area/template_noop leaves the tile in the reservation floor's area, which is
		// the global /area/space and can never carry these flags. That case is what
		// is_domain_turf() exists for, so it's checked below instead.
		if(area_type == /area/template_noop)
			continue

		var/source_map = checked_areas[area_type]
		if(!(initial(area_type.area_flags) & LOCAL_TELEPORT))
			TEST_FAIL("[area_type] (used by [source_map]) has no LOCAL_TELEPORT, a quantum pad built on it teleports loot straight out of the domain")
		if(initial(area_type.allow_shuttle_docking))
			TEST_FAIL("[area_type] (used by [source_map]) allows shuttle docking. A custom shuttle can be framed up inside the domain and flown out with the loot")

	// (2) The reservation-level guard, which is what actually covers the noop tiles and
	// any map added after this test was written. Source-scanned rather than simulated: a
	// live domain needs a server, a byteforge and a reservation, and all three call sites
	// are inside procs that are awkward to reach from a unit test.
	var/list/guarded = list(
		"code/datums/helper_datums/teleport.dm" = "check_teleport_valid() no longer refuses teleports across the VR boundary. Quantum pads work out of a domain again",
		"code/__HELPERS/shuttle.dm" = "shuttle_area_check() no longer refuses frames inside a domain. Custom shuttles can be built in VR again",
		"code/modules/shuttle/shuttle_consoles/navigation_computer.dm" = "checkLandingTurf() no longer refuses landing spots inside a domain. A shuttle can be flown into VR to ferry gear in",
	)
	for(var/guarded_file in guarded)
		TEST_ASSERT(findtext(file2text(guarded_file), "is_domain_turf"), guarded[guarded_file])
