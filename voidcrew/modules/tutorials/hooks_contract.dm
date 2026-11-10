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
