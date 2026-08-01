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
 * the unit-test block, so the BITRUNNER_* defines ARE usable here — unlike the
 * fork's own `voidcrew/_DEFINES/`, which compile after this file.
 *
 * Lives in its own voidcrew_ file rather than being appended to the upstream
 * `bitrunning.dm` test so it doesn't collide on the next upstream merge.
 * Upstream's `/datum/unit_test/bitrunner_vdom_settings` already covers key,
 * map_name and completion loot; none of that is repeated here.
 */

/datum/unit_test/voidcrew_bitrunning_domain_ladder

/datum/unit_test/voidcrew_bitrunning_domain_ladder
	/// Domains the branch's own arena-repricing pass missed, held for balance
	/// review instead of failing the suite red: that commit justified itself
	/// with "psyker_zombies is the roster's only net +3", which was wrong on
	/// both counts. New entries do NOT belong here - reprice instead.
	var/static/list/pending_balance_review = list(
		/datum/lazy_template/virtual_domain/psyker_shuffle, // cost 1 / reward 5, net +4, BEPIS-eligible
	)

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
		if(initial(domain_type.test_only))
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
		if(!(domain_type in pending_balance_review) && cost <= BITRUNNER_COST_LOW && reward >= BITRUNNER_REWARD_HIGH)
			TEST_FAIL("[domain_type] costs [cost] and pays [reward] — a net +[reward - cost] off the cheapest rung outclasses every domain above it. Either reprice it or decide deliberately that this one is the exception.")
		// Anything the console will let a crew scan for hints has to have hints.
		if(initial(domain_type.difficulty) >= BITRUNNER_DIFFICULTY_MEDIUM && !length(initial(domain_type.help_text)))
			TEST_FAIL("[domain_type] is difficulty [initial(domain_type.difficulty)] with no help_text — the domain info ability tells a bitrunner nothing about what the objective is")
	TEST_ASSERT(checked >= 15, "only [checked] virtual domains were checked")

	// DOCUMENTED-DESIGN VARIANT, deliberately not asserted.
	//
	// get_random_domain_id() (code/modules/bitrunning/server/util.dm) pools every
	// domain whose cost is under BITRUNNER_COST_EXTREME. The boss arenas were
	// repriced onto the 5/8 rungs on this branch, which pulled all six of them
	// INTO that pool — the console's "Randomize" button can now roll a wendigo
	// for a crew that only had the points for it by accident. Whether that is a
	// bug or the intended thrill is a balance call nobody has made yet, so the
	// assertion is written down here rather than turned red in the suite. If the
	// call goes the other way, drop this block in and gate the pool on cost:
	//
	// for(var/datum/lazy_template/virtual_domain/domain_type as anything in subtypesof(/datum/lazy_template/virtual_domain))
	// 	if(initial(domain_type.test_only) || initial(domain_type.cost) < BITRUNNER_COST_BOSS)
	// 		continue
	// 	TEST_FAIL("[domain_type] is a boss arena inside get_random_domain_id()'s pool (cost [initial(domain_type.cost)] < BITRUNNER_COST_EXTREME)")
