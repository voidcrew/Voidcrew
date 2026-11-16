// Tutorial checklist hooks. Part B: contract accept, work and turn-in hooks.
// Every override calls the parent with its exact argument list and returns its value.

/// Covers the mission board, trader contracts and the kingpin. Returns TRUE or an error string.
/obj/structure/overmap/ship/accept_mission(datum/mission/mission)
	. = ..()
	if(. == TRUE && ismob(usr))
		tutorial_credit(usr, TUTORIAL_STEP_CONTRACT_TAKE)

/// Crew who join after the contract was taken still get the step from the board.
/obj/machinery/computer/mission_board/ui_interact(mob/user, datum/tgui/ui)
	. = ..()
	var/obj/structure/overmap/ship/ship = get_ship()
	if(length(ship?.active_missions) && user?.mind && (user.mind in ship.ship_team?.members))
		tutorial_credit(user, TUTORIAL_STEP_CONTRACT_TAKE)

/datum/mission/on_objective_completed(datum/mission_objective/objective)
	var/obj/structure/overmap/ship/ship = (active && !failed && !completed) ? servant : null
	. = ..()
	if(ship && !QDELETED(ship))
		tutorial_credit_crew(ship, TUTORIAL_STEP_CONTRACT_WORK)

/// The mission qdels itself during the parent, so the ship is saved first.
/datum/mission/finish_mission(atom/reward_anchor)
	var/obj/structure/overmap/ship/ship = (active && !failed && !completed) ? servant : null
	. = ..()
	if(!ship || QDELETED(ship) || !completed)
		return
	// Deliveries complete at hand-in, so the work step is credited here too.
	tutorial_credit_crew(ship, TUTORIAL_STEP_CONTRACT_WORK)
	tutorial_credit_crew(ship, TUTORIAL_STEP_CONTRACT_TURN_IN)

// ---------------------------------------------------------------------------
// Step pointers and live lines (contract-trade)
// ---------------------------------------------------------------------------

/// The viewer's crew ship's first live contract, or null.
/proc/tutorial_first_contract(mob/user)
	var/obj/structure/overmap/ship/ship = get_crew_ship(user)
	for(var/datum/mission/mission as anything in ship?.active_missions)
		if(!QDELETED(mission))
			return mission
	return null

/// "Name: progress." for the viewer's first live contract, or null.
/proc/tutorial_contract_line(mob/user)
	var/datum/mission/mission = tutorial_first_contract(user)
	if(!mission)
		return null
	var/progress = mission.get_progress_string()
	return progress ? "[mission.name]: [progress]." : "[mission.name]."

/// The main trader also posts contracts; stalls and guards don't.
/datum/vc_tutorial_step/contract_take/highlight_filter(mob/user, atom/candidate)
	if(istype(candidate, /mob/living/basic/outpost_trader))
		var/mob/living/basic/outpost_trader/trader = candidate
		return !isnull(trader.outpost) && trader.outpost.trader == trader
	return TRUE

/// While berthed at an outpost, its main trader (a fixed spot behind a counter).
/datum/vc_tutorial_step/contract_take/extra_targets(mob/user)
	var/obj/structure/overmap/trader_outpost/outpost = get_crew_ship(user)?.docked
	if(!istype(outpost) || QDELETED(outpost.trader))
		return list()
	return list(outpost.trader)

/datum/vc_tutorial_step/contract_work/live_line(mob/user)
	var/line = tutorial_contract_line(user)
	if(!line)
		return null
	if(tutorial_first_contract(user).get_waypoint_info())
		line += " Marked on the helm."
	return line

/// The contract's tracked objective, when it lies loose on the ground. Anything carried is
/// skipped, so a holder's position is never shown.
/datum/vc_tutorial_step/contract_work/extra_targets(mob/user)
	var/datum/mission/mission = tutorial_first_contract(user)
	var/atom/movable/objective = mission?.quest_atom
	if(QDELETED(objective) || !isturf(objective.loc))
		return list()
	if(ismob(objective))
		var/mob/objective_mob = objective
		if(objective_mob.ckey)
			return list()
	return list(objective)

/datum/vc_tutorial_step/contract_turn_in/live_line(mob/user)
	return tutorial_contract_line(user)

/// Only a pad a board reads: an unlinked pad is never checked at Turn In.
/datum/vc_tutorial_step/contract_turn_in/highlight_filter(mob/user, atom/candidate)
	if(istype(candidate, /obj/machinery/mission_pad))
		var/obj/machinery/mission_pad/pad = candidate
		return !isnull(pad.linked_console)
	return TRUE
