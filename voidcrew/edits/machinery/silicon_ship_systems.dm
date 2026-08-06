/*
 * # Silicons aboard ships
 *
 * Two upstream assumptions break on a codebase where the crew lives on a ship.
 *
 * ## 1. AIs were locked out of every console that matters
 *
 * The weapons console, the orbital survey console and the hull construction console
 * are all /obj/machinery/computer/camera_advanced subtypes, and upstream stubs out
 * attack_ai() across that whole tree ("AIs would need to disable their own camera
 * procs to use the console safely"). The helm is a plain /obj/machinery/computer, so
 * an AI could fly the ship and do nothing else with it.
 *
 * That stub is more conservative than the rest of the type: camera_advanced already
 * carries INTERACT_MACHINE_ALLOW_SILICON, and attack_robot() already routes straight
 * to attack_hand(), so cyborgs were never blocked - only AIs, and only because an AI
 * owns a second camera eye that fights the console's one. That fight is what gets
 * settled below, after which the three ship consoles let AIs in.
 *
 * ## 2. AI sight ignores camera networks entirely
 *
 * Every camera and security console aboard a ship is bound to a per-ship network
 * (voidcrew/edits/machinery/camera.dm), but GLOB.cameranet is purely spatial:
 * checkTurfVis() asks "is any camera looking at this turf", never "is it one of
 * ours". Two hulls docked together share a z-level, so an AI could walk its eye out
 * through the airlock and watch the whole of someone else's ship - observed in a
 * live round, reported by the AI itself as "their entire ship".
 *
 * The network var only ever filtered the camera LIST, so scoping has to be enforced
 * on the eye, and against the hull rather than against `network` - otherwise the
 * Jump To Network verb re-opens the hole by hand.
 *
 * ### What is still visible
 *
 * Camera chunks are global and shared between every eye standing in them, so the
 * static overlay cannot be filtered per-viewer without rebuilding tg's freelook
 * around per-network chunks. An AI parked at its own docking airlock therefore still
 * renders whatever the neighbouring ship's own cameras light up within its view
 * radius. That is a corridor at the seam, not a ship, and it needs the eye to be
 * sitting on the AI's own hull to see it.
 */

/// How long a resolved hull scope stays warm. The eye checks it on every step and a
/// step is a full scan of every docking port in the sector, so this is the difference
/// between one lookup per keypress-burst and one per tile.
#define AI_CAMERA_SCOPE_LIFETIME (2 SECONDS)

/mob/living/silicon/ai
	/// Ship this AI's camera vision is confined to, or null when it isn't aboard one.
	VAR_PRIVATE/datum/weakref/camera_scope_ship_ref
	/// world.time of the last scope resolve, for AI_CAMERA_SCOPE_LIFETIME.
	VAR_PRIVATE/camera_scope_checked = 0

/**
 * The ship this AI is physically aboard, which is the only hull its eye may enter.
 *
 * Resolved live rather than bound once: an AI card carried onto another ship is an AI
 * someone installed there, and a ship that gets destroyed under a carded AI should
 * stop scoping it rather than strand it looking at nothing.
 *
 * Returns null when the AI isn't on a ship at all (an outpost core, a ruin, an admin
 * spawn). Those keep upstream behaviour - there is no hull to scope them to, and
 * inventing one would break the colosseum and every non-ship silicon.
 */
/mob/living/silicon/ai/proc/get_camera_scope_ship()
	if(camera_scope_checked && (world.time - camera_scope_checked) < AI_CAMERA_SCOPE_LIFETIME)
		return camera_scope_ship_ref?.resolve()

	camera_scope_checked = world.time
	var/obj/docking_port/mobile/voidcrew/ship_port = voidcrew_get_camera_ship_port(src)
	camera_scope_ship_ref = ship_port ? WEAKREF(ship_port) : null
	// Point the camera-list UIs (Jump To Camera, Jump To Network) at the same hull the
	// hard gates below enforce, so the list can't advertise somewhere the eye refuses
	// to go. The gates deliberately do not read `network` - it is player-writable via
	// Jump To Network, and a scope you can retune yourself is not a scope.
	if(ship_port)
		network = list(voidcrew_ship_camera_net(ship_port))
	return ship_port

/**
 * Stands the AI's own eye down while its owner is driving a console eye, and keeps it
 * on the hull the AI is aboard the rest of the time.
 *
 * The first guard is what the upstream attack_ai() stub was really protecting against:
 * this proc ends in client.set_eye(src), so any AI eye movement while the AI is on a
 * console - a camera jump, a track, the camera light refreshing - snaps the view off
 * the console with the console still believing it holds the user.
 */
/mob/eye/camera/ai/setLoc(destination, force_update = FALSE)
	if(!ai)
		return ..()

	if(ai.remote_control && ai.remote_control != src)
		return

	var/obj/docking_port/mobile/voidcrew/scope = ai.get_camera_scope_ship()
	if(scope)
		var/turf/target = get_turf(destination)
		if(!target || !scope.is_in_shuttle_bounds(target))
			return

	return ..()

/**
 * Same hull scope applied to interaction, not just to sight.
 *
 * can_see() backs can_perform_action(), so without this an AI that cannot fly its eye
 * onto a docked neighbour could still reach through a shared camera chunk and work
 * their airlocks from across the seam.
 */
/mob/living/silicon/ai/can_see(atom/target)
	. = ..()
	if(!.)
		return .
	var/obj/docking_port/mobile/voidcrew/scope = get_camera_scope_ship()
	if(!scope)
		return .
	return scope.is_in_shuttle_bounds(get_turf(target))

/**
 * Restores sight when the AI hands a console eye back.
 *
 * Upstream's AI override of this proc is SHOULD_CALL_PARENT(FALSE) and never calls
 * update_sight(), which was harmless while AIs could not reach a camera console and a
 * trap the moment they can: the combat console's give_eye_control() sets its user to
 * SEE_TURFS|SEE_OBJS|BLIND and the survey console add_sight()s SEE_OBJS/SEE_MOBS, and
 * both rely on the perspective reset to undo it. Humans get that from
 * /mob/living/reset_perspective; the AI has to be told.
 */
/mob/living/silicon/ai/reset_perspective(atom/new_eye)
	. = ..()
	update_sight()

// ---------------------------------------------------------------- ship consoles
//
// attack_robot() on the parent already routes to attack_hand(), so these only bring
// AIs up to where cyborgs always were. All three open a TGUI panel rather than
// handing out the eye directly - the eye comes later, from a button on the panel -
// so this grants a readout, not an ambush.

/obj/machinery/computer/camera_advanced/ship_combat/attack_ai(mob/user)
	return attack_hand(user)

/obj/machinery/computer/camera_advanced/shuttle_docker/survey/attack_ai(mob/user)
	return attack_hand(user)

/obj/machinery/computer/camera_advanced/base_construction/ship/attack_ai(mob/user)
	return attack_hand(user)

#undef AI_CAMERA_SCOPE_LIFETIME
