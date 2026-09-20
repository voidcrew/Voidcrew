/**
 * We early return this to prevent station traits from rolling
 * This is because it adds inconsistencies we don't want, or at worst it breaks things (such as overflow).
 */
/datum/controller/subsystem/processing/station/SetupTraits()
	return

/**
 * Station goals that must never be dealt out in this fork.
 *
 * The Bluespace Artillery is a station superweapon with no notion of the overmap. Its
 * targeting list is every tracking GPS in the world on every z-level, so a cannon parked
 * in the neutral zone can gib a crew docked at an outpost three zones away, and the bore
 * sweep flags every turf from the cannon to the map edge on the cannon's own z - which
 * on this fork is a lane shared with other ships. None of the zone gates that cover ship
 * weapons (ZONE_WEAPONS_ALLOWED, weapons_allowed_at) are consulted anywhere in it.
 *
 * The parts crate is only purchasable once this goal's on_report() flips
 * special_enabled, so keeping the goal out of the roll is the whole fix. Round 91
 * (2026-09-20) is the reference incident: one crew bought the crate, another crew's
 * keycard device unlocked it (that authorisation is global too), and five strikes
 * gibbed players in green and yellow space.
 */
GLOBAL_LIST_INIT(voidcrew_disabled_station_goals, list(
	/datum/station_goal/bluespace_cannon,
))

/**
 * Deliberately no ..(): this replaces the upstream body rather than wrapping it. It is
 * upstream's proc with the exclusion applied to the candidate list, which also covers
 * the greenshift `INFINITY` budget branch in send_roundstart_report() that would
 * otherwise generate every goal in the game.
 */
/datum/controller/subsystem/processing/station/generate_station_goals(goal_budget)
	var/list/possible = subtypesof(/datum/station_goal) - GLOB.voidcrew_disabled_station_goals

	var/goal_weights = 0
	var/chosen_goals = list()
	var/is_planetary = SSmapping.is_planetary()
	while(possible.len && goal_weights < goal_budget)
		var/datum/station_goal/picked = pick_n_take(possible)
		if(picked::requires_space && is_planetary)
			continue

		goal_weights += initial(picked.weight)
		chosen_goals += picked

	for(var/chosen in chosen_goals)
		new chosen()

/**
 * Belt and braces for the above: SSshuttle only registers packs with a non-null
 * `contains`, so this drops the BSA crate out of the catalogue altogether. The parts
 * have no research designs, no techweb node, no loot-table or shop entry, so with the
 * crate gone there is no in-game route to a cannon.
 */
/datum/supply_pack/engineering/bsa
	contains = null
