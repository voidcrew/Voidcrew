// Voidcrew extensions to code/controllers/subsystem/movement/movement_types.dm.

/**
 * A path loop stopped from inside its own step asks for no new path. Stepping onto a tile can end the walk there and
 * then: an outpost police officer who comes into sight of its suspect, or is shot, on that step goes alert, which
 * drops its walk (stealth_set_state() in voidcrew/modules/stealth/stealth_ai.dm) and deletes this loop while move()
 * is still inside moving.Move(). move() then finds itself off its next tile and asks for a path with moving
 * already null, which runtimes in the pathfinder ("Invalid pathfinding start"). Nothing is lost by not asking:
 * the loop is gone.
 */
/datum/move_loop/has_target/jps/recalculate_path()
	if(QDELETED(src) || isnull(moving))
		return
	return ..()
