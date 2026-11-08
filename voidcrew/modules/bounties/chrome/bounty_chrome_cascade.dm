/**
 * # Bounty chrome: the Cascade lattice
 *
 * Owner: C1. A criminal's Cascade lattice is the player's implant
 * (/obj/item/organ/cyberimp/cyberware/cascade, ware_legend.dm): the surge, its eight seconds of
 * speed, quicker blows, afterimages and dodge on the move, the six second crash, the minute's
 * cooldown, and an EMP in the window crashing it, are all the implant's own. Nothing here changes
 * them. This file is only how an NPC uses it (owner decision 5):
 * - The tell (/datum/bounty_chrome_move/cascade, through C0's bounty_chrome.dm): a violet glow and
 *   a rising whine, standing still, for BOUNTY_CHROME_TELL_MIN; then the lattice's own Cascade Surge,
 *   Trigger()ed as a player's button press. It starts only with its target close and in sight, and
 *   never on a mini-boss whose kit fires the lattice itself (the Ghost's dash, bounty_boss_kits.dm):
 *   one lattice, one driver.
 * - In the window its body has the lattice's speed, and its AI's own movement loop is paced by that
 *   body (the controller's movement_delay follows cached_multiplicative_slowdown), so a fighter who
 *   closes in runs a hunter down with no help from here. A gunman would stand and shoot, and the
 *   lattice only dodges on the move, so it strafes (strafe()): a step across its line to its target,
 *   never sooner than its body's own move delay allows, at most every BOUNTY_CASCADE_STRAFE_GAP,
 *   never while its AI is walking it and never off its leash (bounty_ai_step()). Each step leaves the
 *   lattice's afterimage, so the surge shows on a gunman too.
 */

/// Furthest its target may be for it to surge, in tiles
#define BOUNTY_CASCADE_RANGE 7
/// The glow through the tell
#define BOUNTY_CASCADE_COLOR "#c86bff"
/// How often the window's strafing looks for a step
#define BOUNTY_CASCADE_STRAFE_PULSE (0.1 SECONDS)
/// Shortest time between two strafing steps (its body's move delay may make it longer)
#define BOUNTY_CASCADE_STRAFE_GAP (0.4 SECONDS)

/datum/bounty_chrome_move/cascade
	piece_key = BOUNTY_CHROME_CASCADE
	name = "Cascade surge"
	action_type = /datum/action/cooldown/cyberware/cascade_surge
	tell_time = BOUNTY_CHROME_TELL_MIN
	tell_color = BOUNTY_CASCADE_COLOR
	tell_sound = 'sound/effects/magic/charge.ogg'
	tell_lines = list("Try and keep up.", "Watch this.", "Too slow.")
	max_range = BOUNTY_CASCADE_RANGE
	/// The window's strafing loop, while the lattice's window is open
	var/strafe_timer
	/// world.time its owner last took a step, by any means
	var/last_step_at = 0
	/// world.time its next strafing step may come
	var/next_strafe_at = 0
	/// The way its last strafing step went: the next one goes back the other way when it can, a zig-zag rather than a drift
	var/last_strafe_dir = NONE

/datum/bounty_chrome_move/cascade/Destroy()
	stop_strafing()
	return ..()

/datum/bounty_chrome_move/cascade/detach()
	stop_strafing()
	return ..()

/datum/bounty_chrome_move/cascade/can_start(atom/target)
	if(kit_drives_lattice())
		return FALSE
	return ..()

/datum/bounty_chrome_move/cascade/tell_text(atom/target)
	return "[owner]'s spine lights up with a rising whine."

/datum/bounty_chrome_move/cascade/effect(atom/target)
	. = ..()
	if(.)
		start_strafing()

/datum/bounty_chrome_move/cascade/on_death()
	stop_strafing()

/// Whether its owner is a mini-boss whose kit fires this lattice itself (the Ghost's dash): the AI here never does too
/datum/bounty_chrome_move/cascade/proc/kit_drives_lattice()
	var/mob/living/carbon/human/npc/bounty_criminal/boss/boss = owner
	return istype(boss) && (/obj/item/organ/cyberimp/cyberware/cascade in bounty_chrome_kit_organs(boss.boss_kit))

/// Whether the lattice's window is open on its owner now
/datum/bounty_chrome_move/cascade/proc/surging()
	return !QDELETED(owner) && !!owner.has_status_effect(/datum/status_effect/cyberware_cascade_window)

/// The window just opened: a fighter with a gun or bottles strafes until the window closes (a brawler or a mini-boss just closes in)
/datum/bounty_chrome_move/cascade/proc/start_strafing()
	stop_strafing()
	var/datum/bounty_style/style = bounty_ai_style(owner)
	if(!style?.ranged || !surging())
		return
	RegisterSignal(owner, COMSIG_MOVABLE_MOVED, PROC_REF(on_owner_moved))
	last_step_at = world.time
	next_strafe_at = world.time + BOUNTY_CASCADE_STRAFE_GAP
	strafe_timer = addtimer(CALLBACK(src, PROC_REF(strafe_pulse)), BOUNTY_CASCADE_STRAFE_PULSE, TIMER_STOPPABLE | TIMER_DELETE_ME | TIMER_LOOP)

/// Stops the strafing loop. Safe at any time.
/datum/bounty_chrome_move/cascade/proc/stop_strafing()
	if(strafe_timer)
		deltimer(strafe_timer)
		strafe_timer = null
	if(owner)
		UnregisterSignal(owner, COMSIG_MOVABLE_MOVED)

/// One beat of the loop: a strafing step if one is due, and the loop ends with the window
/datum/bounty_chrome_move/cascade/proc/strafe_pulse()
	if(!surging())
		stop_strafing()
		return
	strafe()

/datum/bounty_chrome_move/cascade/proc/on_owner_moved(atom/movable/source, atom/old_loc, dir, forced)
	SIGNAL_HANDLER
	last_step_at = world.time

/**
 * A gunman in the lattice's window takes a step across its line to its target, keeping its distance and its
 * sight of them, the way a player with a lattice keeps moving to keep the dodge: never sooner than its
 * body's move delay after its last step, at most every BOUNTY_CASCADE_STRAFE_GAP, never while its AI
 * is walking it, held still or not able to fight, and only on its leash (bounty_ai_step()). A fighter
 * without a gun ready in hand closes in through its AI instead. Returns TRUE if it stepped.
 */
/datum/bounty_chrome_move/cascade/proc/strafe()
	if(QDELETED(owner) || world.time < next_strafe_at || world.time < last_step_at + owner.cached_multiplicative_slowdown)
		return FALSE
	if(!surging() || !bounty_chrome_can_act(owner) || !bounty_chrome_in_fight(owner) || !bounty_ai_fighting(owner))
		return FALSE
	if(owner.buckled || owner.pulledby || HAS_TRAIT(owner, TRAIT_IMMOBILIZED) || !(owner.mobility_flags & MOBILITY_MOVE))
		return FALSE
	var/datum/ai_controller/controller = owner.ai_controller
	if(QDELETED(controller) || controller.ai_movement?.moving_controllers[controller])
		return FALSE
	var/datum/bounty_style/style = bounty_ai_style(owner)
	if(!style?.ranged || !style.ready_in_hand(owner))
		return FALSE
	var/atom/target = bounty_chrome_target(owner)
	var/turf/here = get_turf(owner)
	var/turf/aim = get_turf(target)
	if(!here || !aim || aim.z != here.z)
		return FALSE
	var/distance = get_dist(here, aim)
	if(distance < 2 || distance > BOUNTY_FIGHT_VISION)
		return FALSE
	var/list/sides = shuffle(strafe_dirs(here, aim))
	var/back = REVERSE_DIR(last_strafe_dir)
	if(back in sides)
		sides -= back
		sides.Insert(1, back)
	for(var/side in sides)
		var/turf/spot = get_step(here, side)
		if(!spot || isspaceturf(spot) || isopenspaceturf(spot) || get_dist(spot, aim) > distance || !can_see(spot, aim, BOUNTY_FIGHT_VISION))
			continue
		// The glide its body's own pace gives a step, as its movement loop sets it
		owner.set_glide_size(DELAY_TO_GLIDE_SIZE(owner.cached_multiplicative_slowdown))
		if(!bounty_ai_step(owner, spot))
			continue
		next_strafe_at = world.time + BOUNTY_CASCADE_STRAFE_GAP
		last_strafe_dir = side
		owner.face_atom(target)
		return TRUE
	return FALSE

/// The two cardinal steps across the line from `here` to `aim`: north and south of a target mostly east or west, east and west of one mostly north or south
/datum/bounty_chrome_move/cascade/proc/strafe_dirs(turf/here, turf/aim)
	if(abs(aim.x - here.x) >= abs(aim.y - here.y))
		return list(NORTH, SOUTH)
	return list(EAST, WEST)

#undef BOUNTY_CASCADE_RANGE
#undef BOUNTY_CASCADE_COLOR
#undef BOUNTY_CASCADE_STRAFE_PULSE
#undef BOUNTY_CASCADE_STRAFE_GAP
