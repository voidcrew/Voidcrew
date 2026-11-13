/**
 * # Stealth guards: readable turns (decision 39, playtest fixes)
 *
 * A guard that turns on its own (a look aside at a stop, a sentry's glance, the look round when suspicious or
 * searching, back to the way it faces) leans a few pixels towards the new side for STEALTH_TURN_TELL first, then
 * turns. A player watching it sees which way it is about to look and has a moment to move.
 *
 * After any turn made where it stands (its own, or one to a noise or a door), nothing is plain to it at a glance for
 * its skill's turn_grace: no instant point-blank alert (decision 32), and no alert by sight at all until the moment
 * passes. Its notice still fills as usual (it can go "?"), so someone who stays in front of it is seen on the first
 * look after. A turn made by stepping is a walk, not a look round, and gives nothing.
 *
 * Its flashlight pool (stealth_light.dm) follows every turn and step from here.
 */

/datum/ai_controller/basic_controller/human_npc/stealth
	/// world.time of its last turn made standing still, or 0
	var/turned_at = 0
	/// The turf it stood on for that turn
	var/turf/turned_from
	/// The way it is about to turn while its tell shows, or 0
	var/turn_pending = 0
	/// world.time that turn was planned (tells an old timer from the current one)
	var/turn_planned_at = 0
	/// Where it stood when it planned that turn
	var/turf/turn_planned_from
	/// The lean its tell put on the body (list(pixel_w, pixel_z)), to take back, or null
	var/list/turn_lean
	/// +1 or -1: the side its next look aside goes (turn() takes positive as anticlockwise)
	var/look_side = -1

/datum/ai_controller/basic_controller/human_npc/stealth/proc/on_pawn_turned(atom/source, old_dir, new_dir)
	SIGNAL_HANDLER
	if(old_dir == new_dir)
		return
	// Not before it has set up: a mapper's facing or a test's setDir is not a turn.
	if(stealth_ready)
		turned_at = world.time
		turned_from = get_turf(source)
	stealth_light_follow()

/datum/ai_controller/basic_controller/human_npc/stealth/update_grid(datum/source, datum/spatial_grid_cell/new_cell)
	. = ..()
	stealth_light_follow()

/// Its hands or its freedom changed: its light may have to go out or may come back.
/datum/ai_controller/basic_controller/human_npc/stealth/proc/on_light_cue(datum/source)
	SIGNAL_HANDLER
	stealth_update_light()

/// Whether it turned where it stands within its skill's turn_grace: nothing is plain to it at a glance yet.
/datum/ai_controller/basic_controller/human_npc/stealth/proc/stealth_turn_grace()
	if(!turned_at || world.time >= turned_at + stealth_skill().turn_grace)
		return FALSE
	return get_turf(pawn) == turned_from

/// The side of its next look aside: they alternate, so a player can count on the next one.
/datum/ai_controller/basic_controller/human_npc/stealth/proc/stealth_next_side()
	look_side = -look_side
	return look_side

/// Turns to `new_dir` on its own: leans that way for STEALTH_TURN_TELL, then turns.
/datum/ai_controller/basic_controller/human_npc/stealth/proc/stealth_turn_to(new_dir)
	var/mob/living/guard = pawn
	if(QDELETED(guard) || !new_dir)
		return
	if(turn_pending)
		if(turn_pending == new_dir)
			return
		stealth_drop_turn()
	if(guard.dir == new_dir)
		return
	turn_pending = new_dir
	turn_planned_at = world.time
	turn_planned_from = get_turf(guard)
	var/lean_w = (new_dir & EAST) ? STEALTH_TURN_LEAN : ((new_dir & WEST) ? -STEALTH_TURN_LEAN : 0)
	var/lean_z = (new_dir & NORTH) ? STEALTH_TURN_LEAN : ((new_dir & SOUTH) ? -STEALTH_TURN_LEAN : 0)
	turn_lean = list(lean_w, lean_z)
	animate(guard, pixel_w = lean_w, pixel_z = lean_z, time = STEALTH_TURN_LEAN_TIME, flags = ANIMATION_RELATIVE | ANIMATION_PARALLEL)
	addtimer(CALLBACK(src, PROC_REF(stealth_finish_turn), new_dir, turn_planned_at), STEALTH_TURN_TELL)

/// The tell is over: it turns, unless the moment has passed (it moved, went down, changed state, or a player took it).
/datum/ai_controller/basic_controller/human_npc/stealth/proc/stealth_finish_turn(new_dir, planned_at)
	if(turn_pending != new_dir || turn_planned_at != planned_at)
		return
	var/mob/living/guard = pawn
	var/turf/planned_from = turn_planned_from
	stealth_drop_turn()
	if(QDELETED(guard) || guard.stat != CONSCIOUS || stealth_driven() || get_turf(guard) != planned_from)
		return
	guard.setDir(new_dir)

/// Drops a turn it was about to make and takes its lean back.
/datum/ai_controller/basic_controller/human_npc/stealth/proc/stealth_drop_turn()
	turn_pending = 0
	turn_planned_from = null
	if(isnull(turn_lean))
		return
	var/mob/living/guard = pawn
	if(!QDELETED(guard))
		animate(guard, pixel_w = -turn_lean[1], pixel_z = -turn_lean[2], time = STEALTH_TURN_LEAN_TIME, flags = ANIMATION_RELATIVE | ANIMATION_PARALLEL)
	turn_lean = null
