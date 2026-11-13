/**
 * Outpost police tests for officers in each other's way (police_movement.dm): two walking officers meeting head-on,
 * an officer paused in a doorway, an escort meeting an officer either way round, a player who stays put, an escort
 * crossing an exit gate from a diagonal, and the cell door shutting with its own sound when an officer is at work.
 */

/// A police officer with its brain off, walking (the pace that never swaps or pushes in tg), at `where`
/datum/unit_test/proc/police_blocking_officer(turf/where)
	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/officer = allocate(/mob/living/carbon/human/npc/ambient_npc/outpost/police/beat, where)
	officer.ai_controller?.set_ai_status(AI_STATUS_OFF)
	officer.set_pace(FALSE)
	return officer

/// A cuffed person at `where`, in `officer`'s hand
/datum/unit_test/proc/police_blocking_prisoner(turf/where, mob/living/officer)
	var/mob/living/carbon/human/prisoner = allocate(/mob/living/carbon/human/consistent, where)
	var/obj/item/restraints/handcuffs/cuffs = allocate(/obj/item/restraints/handcuffs)
	cuffs.apply_cuffs(prisoner, officer, TRUE)
	officer.start_pulling(prisoner)
	return prisoner

/// Two walking officers head-on trade places; an officer paused forming up in a doorway is passed too; one riding the lift is not
/datum/unit_test/voidcrew_outpost_police_blocking_swap

/datum/unit_test/voidcrew_outpost_police_blocking_swap/Run()
	var/x0 = run_loc_floor_bottom_left.x
	var/y0 = run_loc_floor_bottom_left.y
	var/z0 = run_loc_floor_bottom_left.z
	var/turf/west = locate(x0 + 1, y0 + 2, z0)
	var/turf/east = locate(x0 + 2, y0 + 2, z0)
	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/walker = police_blocking_officer(west)
	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/other = police_blocking_officer(east)
	TEST_ASSERT_EQUAL(walker.move_intent, MOVE_INTENT_WALK, "Setup: the officer is not walking")

	// Head-on
	walker.Move(east, EAST)
	TEST_ASSERT_EQUAL(get_turf(walker), east, "A walking officer did not get past another officer head-on")
	TEST_ASSERT_EQUAL(get_turf(other), west, "The officer met head-on did not trade places")

	// Paused in a doorway, forming up for the lift
	other.forceMove(east)
	walker.forceMove(west)
	allocate(/obj/structure/table, locate(x0 + 2, y0 + 1, z0))
	allocate(/obj/structure/table, locate(x0 + 2, y0 + 3, z0))
	ADD_TRAIT(other, TRAIT_AI_PAUSED, "outpost_police_wave")
	COOLDOWN_RESET(walker, police_swap_cooldown)
	walker.Move(east, EAST)
	TEST_ASSERT_EQUAL(get_turf(walker), east, "An officer could not get past an officer paused in a doorway")
	TEST_ASSERT_EQUAL(get_turf(other), west, "The paused officer in the doorway did not trade places")

	// Riding the lift: stays put
	other.forceMove(east)
	walker.forceMove(west)
	other.dispatch_riding = TRUE
	COOLDOWN_RESET(walker, police_swap_cooldown)
	walker.Move(east, EAST)
	TEST_ASSERT_EQUAL(get_turf(other), east, "An officer riding the lift was moved")
	TEST_ASSERT_EQUAL(get_turf(walker), west, "An officer walked through one riding the lift")
	other.dispatch_riding = FALSE
	REMOVE_TRAIT(other, TRAIT_AI_PAUSED, "outpost_police_wave")

/// An escort walking into an officer has them step aside and goes on in hand; an officer walking into an escort steps aside for it
/datum/unit_test/voidcrew_outpost_police_blocking_escort

/datum/unit_test/voidcrew_outpost_police_blocking_escort/Run()
	var/x0 = run_loc_floor_bottom_left.x
	var/y0 = run_loc_floor_bottom_left.y
	var/z0 = run_loc_floor_bottom_left.z
	var/turf/start = locate(x0 + 1, y0 + 2, z0)
	var/turf/ahead = locate(x0 + 2, y0 + 2, z0)
	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/escort = police_blocking_officer(start)
	var/mob/living/carbon/human/prisoner = police_blocking_prisoner(locate(x0, y0 + 2, z0), escort)
	TEST_ASSERT_EQUAL(escort.pulling, prisoner, "Setup: the escort is not holding the prisoner")
	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/other = police_blocking_officer(ahead)

	escort.Move(ahead, EAST)
	TEST_ASSERT(get_turf(other) != ahead && get_turf(other) != start, "An officer in an escort's way did not step aside (at [AREACOORD(other)])")
	escort.Move(ahead, EAST)
	TEST_ASSERT_EQUAL(get_turf(escort), ahead, "The escort did not walk on once the way was clear")
	TEST_ASSERT_EQUAL(escort.pulling, prisoner, "The escort lost the prisoner getting past")
	TEST_ASSERT_EQUAL(get_turf(prisoner), start, "The prisoner did not follow the escort")

	// The other way round: an officer walking into the escort steps aside, and the escort does not move
	var/turf/behind_escort = locate(x0 + 3, y0 + 2, z0)
	other.forceMove(behind_escort)
	COOLDOWN_RESET(other, police_swap_cooldown)
	other.Move(ahead, WEST)
	TEST_ASSERT_EQUAL(get_turf(escort), ahead, "An escort was moved by an officer walking into it")
	TEST_ASSERT(get_turf(other) != behind_escort && get_turf(other) != ahead, "An officer walking into an escort did not step aside")
	var/turf/aside = get_turf(other)
	TEST_ASSERT(aside.x >= behind_escort.x, "The officer stepped aside toward the escort")

/// A player in the way is never moved; walking into them for a while plans the officer's path around their tile
/datum/unit_test/voidcrew_outpost_police_blocking_repath

/datum/unit_test/voidcrew_outpost_police_blocking_repath/Run()
	var/x0 = run_loc_floor_bottom_left.x
	var/y0 = run_loc_floor_bottom_left.y
	var/z0 = run_loc_floor_bottom_left.z
	var/turf/start = locate(x0 + 1, y0 + 2, z0)
	var/turf/blocked = locate(x0 + 2, y0 + 2, z0)
	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/walker = police_blocking_officer(start)
	var/mob/living/carbon/human/player_like = allocate(/mob/living/carbon/human/consistent, blocked)

	var/datum/move_loop/has_target/jps/loop = GLOB.move_manager.jps_move(walker, locate(x0 + 4, y0 + 2, z0), 10, repath_delay = 0.5 SECONDS, subsystem = SSai_movement, extra_info = walker.ai_controller)
	TEST_ASSERT_NOTNULL(loop, "Setup: no path loop started")
	TEST_ASSERT_EQUAL(GLOB.move_manager.processing_on(walker, SSai_movement), loop, "Setup: the path loop is not the officer's running loop")

	walker.Move(blocked, EAST)
	TEST_ASSERT_EQUAL(get_turf(player_like), blocked, "An officer moved a player out of the way")
	TEST_ASSERT_EQUAL(get_turf(walker), start, "An officer walked through a player")
	TEST_ASSERT_NULL(loop.avoid, "The path was planned around a player at the first bump")

	walker.bump_blocked_since = world.time - 5 SECONDS
	walker.Move(blocked, EAST)
	TEST_ASSERT_EQUAL(loop.avoid, blocked, "After walking into a player for a while the officer did not plan around them")
	TEST_ASSERT_NULL(loop.movement_path, "The officer kept the old path after deciding to go around")
	GLOB.move_manager.stop_looping(walker, SSai_movement)

/// An escort meeting an exit gate on a diagonal squares up in front of it and goes straight through, prisoner still in hand
/datum/unit_test/voidcrew_outpost_police_blocking_gate_diagonal

/datum/unit_test/voidcrew_outpost_police_blocking_gate_diagonal/Run()
	var/x0 = run_loc_floor_bottom_left.x
	var/y0 = run_loc_floor_bottom_left.y
	var/z0 = run_loc_floor_bottom_left.z
	// A gate north through a gap between two tables
	var/turf/gate_turf = locate(x0 + 2, y0 + 2, z0)
	var/turf/front = locate(x0 + 2, y0 + 1, z0)
	var/obj/structure/outpost_exit_gate/gate = allocate(/obj/structure/outpost_exit_gate, gate_turf)
	gate.setDir(NORTH)
	allocate(/obj/structure/table, locate(x0 + 1, y0 + 2, z0))
	allocate(/obj/structure/table, locate(x0 + 3, y0 + 2, z0))
	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/escort = police_blocking_officer(locate(x0 + 3, y0, z0))
	var/mob/living/carbon/human/prisoner = police_blocking_prisoner(locate(x0 + 4, y0, z0), escort)

	// Diagonal to the gate: the walk goes to the tile in front of it first
	var/turf/goal = outpost_police_gate_lineup(escort, gate)
	TEST_ASSERT_EQUAL(goal, front, "An escort on a diagonal to the gate was not sent to the tile in front of it")
	escort.Move(get_step_towards(escort, goal), get_dir(escort, goal))
	TEST_ASSERT_EQUAL(get_turf(escort), front, "Setup: the escort did not reach the tile in front of the gate")
	TEST_ASSERT_EQUAL(escort.pulling, prisoner, "The escort lost the prisoner squaring up to the gate")

	// Straight on through
	goal = outpost_police_gate_lineup(escort, gate)
	TEST_ASSERT_EQUAL(get_turf(escort), gate_turf, "The escort did not step straight onto the gate")
	TEST_ASSERT_EQUAL(goal, gate_turf, "The line-up did not report the gate tile")
	TEST_ASSERT_EQUAL(escort.pulling, prisoner, "The escort lost the prisoner stepping onto the gate")
	gate.carry_through(escort)
	TEST_ASSERT(escort.y > gate_turf.y, "The gate did not carry the escort through")
	TEST_ASSERT_EQUAL(escort.pulling, prisoner, "The pull broke as the gate carried the escort through")
	TEST_ASSERT_EQUAL(get_turf(prisoner), gate_turf, "The prisoner did not follow onto the gate")
	// The escort walks on; the prisoner comes off the gate behind them
	escort.Move(get_step(escort, NORTH), NORTH)
	TEST_ASSERT_EQUAL(escort.pulling, prisoner, "The escort lost the prisoner past the gate")
	TEST_ASSERT(prisoner.y > gate_turf.y, "The prisoner was left on the near side of the gate")

/// An officer at work shuts the cell door the ordinary way, with the door's own sound, not the forced (pried) one
/datum/unit_test/voidcrew_outpost_police_blocking_cell_door_sound
	var/close_forced = null

/datum/unit_test/voidcrew_outpost_police_blocking_cell_door_sound/Run()
	var/datum/outpost_police/cell_test/police = police_cells_fixture()
	var/datum/outpost_police_cell/cell = police_cell_named(police, "a")
	TEST_ASSERT(cell.pass_door(), "Setup: the cell door did not open")
	sleep(2 SECONDS)
	TEST_ASSERT(!cell.door.density, "Setup: the cell door is not open")
	cell.open_until = 0
	cell.override_until = world.time + 1 MINUTES
	RegisterSignal(cell.door, COMSIG_AIRLOCK_CLOSE, PROC_REF(note_close))
	cell.close_check()
	UnregisterSignal(cell.door, COMSIG_AIRLOCK_CLOSE)
	TEST_ASSERT(cell.door.density, "The cell door did not shut")
	TEST_ASSERT_NOTNULL(close_forced, "The cell door shut without a close")
	TEST_ASSERT_NOTEQUAL(close_forced, BYPASS_DOOR_CHECKS, "The cell door was forced shut, with the pried-door sound")

/datum/unit_test/voidcrew_outpost_police_blocking_cell_door_sound/proc/note_close(datum/source, forced)
	SIGNAL_HANDLER
	close_forced = forced
