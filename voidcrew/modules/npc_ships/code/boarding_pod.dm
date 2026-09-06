/**
 * NPC Boarding Pod - Launches from pirate ships to deposit hostile mobs on player ships
 *
 * Uses the existing supplypod/landing zone system for the dramatic drop-from-above effect.
 * Pod lands, opens to reveal the boarder, then vanishes.
 */

/// Tracks spawn index for distributing boarders along patrol path
GLOBAL_VAR_INIT(boarding_spawn_index, 0)
GLOBAL_VAR_INIT(boarding_spawn_total, 1)

/// Global proc to create a boarding pod drop at a target location
/// Returns the boarder mob so the caller can register signals (e.g. death tracking)
/proc/create_boarding_pod(turf/target_turf, obj/structure/overmap/ship/target_ship, obj/structure/overmap/ship/npc/source_ship, mob_type)
	if(!target_turf || !mob_type)
		return null
	// Combat volleys call this on a timer; the target may have docked since firing.
	if(QDELETED(target_ship) || QDELETED(source_ship) || target_ship.state != OVERMAP_SHIP_FLYING || source_ship.state != OVERMAP_SHIP_FLYING)
		return null

	// Create the boarding pod with the mob inside
	var/obj/structure/closet/supplypod/boarding/pod = new()

	// Create the boarder mob and put it in the pod
	var/mob/living/boarder = new mob_type(pod)
	if(!boarder)
		qdel(pod)
		return null

	// Boarders are tougher than the same mob type is out in a ruin
	scale_npc_ship_pirate_health(boarder)

	// Store references for the pod
	pod.target_ship = target_ship
	pod.source_ship = source_ship
	pod.boarder_ref = WEAKREF(boarder)
	pod.spawn_index = GLOB.boarding_spawn_index++

	// Create the landing zone - this handles the whole falling animation
	new /obj/effect/pod_landingzone/boarding(target_turf, pod, target_ship, source_ship)

	return boarder

/**
 * Boarding Pod - A supplypod variant for delivering hostile boarders
 *
 * Bluespace-style pod that lands, opens to release the boarder, then vanishes.
 * Uses syndicate styling for that intimidating pirate feel.
 */
/obj/structure/closet/supplypod/boarding
	name = "boarding pod"
	desc = "A crude assault pod used by pirates to deliver boarding parties."
	specialised = TRUE
	style = /datum/pod_style/syndicate
	bluespace = TRUE  // Vanishes after opening
	explosionSize = list(0, 0, 0, 1)  // Small flash, no real damage
	damage = 30  // Minor damage to anyone caught underneath
	delays = list(POD_TRANSIT = 15, POD_FALLING = 4, POD_OPENING = 8, POD_LEAVING = 5)

	/// The ship being boarded
	var/obj/structure/overmap/ship/target_ship
	/// The ship that launched us
	var/obj/structure/overmap/ship/npc/source_ship
	/// Weak reference to the boarder mob inside
	var/datum/weakref/boarder_ref
	/// This boarder's index in the spawn batch (for patrol distribution)
	var/spawn_index = 0
	/// Suppress opening and arrival signals when an inbound drop is cancelled.
	var/landing_cancelled = FALSE

/obj/structure/closet/supplypod/boarding/preOpen()
	. = ..()
	// Play a distinctive sound when the pod lands
	if(target_ship)
		playsound_ship(get_turf(src), 'sound/effects/meteorimpact.ogg', 60, TRUE, 10, target_ship)

/obj/structure/closet/supplypod/boarding/open_pod(atom/movable/holder, broken = FALSE, forced = FALSE)
	if(landing_cancelled)
		return
	. = ..()
	log_shuttle("PATROL: open_pod called, holder=[holder], target_ship=[target_ship], boarder_ref=[boarder_ref]")

	// Announce the boarder emerging
	var/turf/T = get_turf(holder)
	for(var/mob/living/emerged_mob in T)
		emerged_mob.visible_message(span_danger("[emerged_mob] emerges from the boarding pod!"))

	// Assign patrol behavior to the boarder
	var/mob/living/boarder = boarder_ref?.resolve()
	log_shuttle("PATROL: Resolved boarder_ref to: [boarder]")

	if(boarder && target_ship && !QDELETED(target_ship))
		log_shuttle("PATROL: Calling setup_boarder_patrol...")
		setup_boarder_patrol(boarder, target_ship, spawn_index)
	else
		log_shuttle("PATROL: NOT calling setup_boarder_patrol - boarder=[boarder], target_ship=[target_ship], QDELETED=[QDELETED(target_ship)]")

	// Signal that boarders have arrived
	if(target_ship && !QDELETED(target_ship))
		SEND_SIGNAL(target_ship, COMSIG_SHIP_BOARDED, src, source_ship)

/**
 * Set up patrol behavior for a boarder mob.
 * Swaps their AI controller to a patrolling variant and assigns the ship's patrol path.
 */
/obj/structure/closet/supplypod/boarding/proc/setup_boarder_patrol(mob/living/boarder, obj/structure/overmap/ship/target_ship, spawn_index)
	log_shuttle("PATROL: setup_boarder_patrol called: boarder=[boarder], target_ship=[target_ship], spawn_index=[spawn_index]")

	if(!boarder)
		log_shuttle("PATROL: FAILED - boarder is null")
		return

	log_shuttle("PATROL: Boarder current AI controller: [boarder.ai_controller] ([boarder.ai_controller?.type])")

	// Determine the patrolling AI controller type based on current controller
	var/new_controller_type
	if(istype(boarder.ai_controller, /datum/ai_controller/basic_controller/trooper/ranged))
		new_controller_type = /datum/ai_controller/basic_controller/trooper/ranged/patrolling
		log_shuttle("PATROL: Detected ranged trooper, will swap to ranged/patrolling")
	else if(istype(boarder.ai_controller, /datum/ai_controller/basic_controller/trooper))
		new_controller_type = /datum/ai_controller/basic_controller/trooper/patrolling
		log_shuttle("PATROL: Detected melee trooper, will swap to patrolling")
	else
		log_shuttle("PATROL: Unknown AI controller type, no swap will occur")

	// Swap to patrolling controller if we found a valid type
	// PossessPawn automatically handles cleanup of the old controller
	if(new_controller_type)
		log_shuttle("PATROL: Creating new controller of type [new_controller_type]")
		new new_controller_type(boarder)

		// Issue 1: Verify controller was properly assigned
		var/datum/ai_controller/new_ctrl = boarder.ai_controller
		if(!new_ctrl || !istype(new_ctrl, new_controller_type))
			log_shuttle("PATROL: ERROR - Controller swap failed! Expected [new_controller_type], got [new_ctrl?.type]")
			return

		log_shuttle("PATROL: New AI controller: [new_ctrl] ([new_ctrl?.type])")
		log_shuttle("PATROL: Controller details - ai_movement=[new_ctrl.ai_movement?.type], able_to_run=[new_ctrl.able_to_run], movement_delay=[new_ctrl.movement_delay], ai_status=[new_ctrl.ai_status]")

		// Issue 2: Force AI activation immediately instead of waiting for subsystem tick
		new_ctrl.reset_ai_status()
		log_shuttle("PATROL: Force-activated AI, new ai_status=[new_ctrl.ai_status]")

		var/turf/boarder_turf = get_turf(boarder)
		var/clients_on_z = boarder_turf ? length(SSmobs.clients_by_zlevel[boarder_turf.z]) : 0
		log_shuttle("PATROL: Pawn details - loc=[boarder.loc], on_turf=[isturf(boarder.loc)], z=[boarder_turf?.z], clients_on_z=[clients_on_z], mobility_flags=[boarder.mobility_flags], MOBILITY_MOVE=[(boarder.mobility_flags & MOBILITY_MOVE) ? "YES" : "NO"]")

	// Assign patrol path (works even if controller wasn't swapped)
	var/result = assign_mob_to_patrol(boarder, target_ship, spawn_index, GLOB.boarding_spawn_total)
	log_shuttle("PATROL: assign_mob_to_patrol returned: [result]")

/**
 * Boarding Pod Landing Zone - Handles the falling animation and notifications
 */
/obj/effect/pod_landingzone/boarding
	/// The ship being boarded
	var/obj/structure/overmap/ship/target_ship
	/// The ship that launched the pod
	var/obj/structure/overmap/ship/npc/source_ship

/obj/effect/pod_landingzone/boarding/Initialize(mapload, podParam, obj/structure/overmap/ship/target, obj/structure/overmap/ship/npc/source)
	target_ship = target
	source_ship = source
	// Explicitly pass only mapload and podParam - do NOT pass target/source as they would be
	// interpreted as single_order by the parent and forceMoved into the pod
	. = ..(mapload, podParam)

/obj/effect/pod_landingzone/boarding/playFallingSound()
	// Use ship-limited sound so it only plays on the target ship
	if(target_ship)
		playsound_ship(get_turf(src), pod.fallingSound, pod.soundVolume, TRUE, 6, target_ship)
	else
		. = ..()

/// A ship can dock while the pod is in transit or playing its falling animation.
/obj/effect/pod_landingzone/boarding/proc/cancel_if_target_docked()
	if(!QDELETED(target_ship) && target_ship.state == OVERMAP_SHIP_FLYING)
		return FALSE

	// Supplypod destruction opens it, so remove its passengers first.
	var/obj/structure/closet/supplypod/boarding/boarding_pod = pod
	boarding_pod.landing_cancelled = TRUE
	for(var/mob/living/boarder in pod)
		qdel(boarder)
	QDEL_NULL(pod)
	QDEL_NULL(helper)
	for(var/obj/effect/supplypod_smoke/smoke_part as anything in smoke_effects)
		qdel(smoke_part)
	qdel(src)
	return TRUE

/obj/effect/pod_landingzone/boarding/beginLaunch(effectCircle)
	if(cancel_if_target_docked())
		return
	return ..()

/obj/effect/pod_landingzone/boarding/endLaunch()
	if(cancel_if_target_docked())
		return
	return ..()

// ========== BOSS BOARDING POD ==========

/// Global proc to create a boss boarding pod drop at a target location
/// Returns the boss mob so the caller can register signals and track it
/proc/create_boss_boarding_pod(turf/target_turf, obj/structure/overmap/ship/target_ship, obj/structure/overmap/ship/npc/source_ship, mob_type)
	if(!target_turf || !mob_type)
		return null
	if(QDELETED(target_ship) || QDELETED(source_ship) || target_ship.state != OVERMAP_SHIP_FLYING || source_ship.state != OVERMAP_SHIP_FLYING)
		return null

	// Create the boss boarding pod
	var/obj/structure/closet/supplypod/boarding/boss/pod = new()

	// Create the boss mob and put it in the pod
	var/mob/living/basic/trooper/pirate/faction/boss/boss = new mob_type(pod)
	if(!boss)
		qdel(pod)
		return null

	// Scaled after Initialize() so bosses that set their health there (silverscale)
	// are multiplied off their real pool, not the var default
	scale_npc_ship_pirate_health(boss, NPC_PIRATE_BOSS_HEALTH_MULT)

	// Set up boss-specific properties
	boss.parent_ship = source_ship

	// Store references for the pod
	pod.target_ship = target_ship
	pod.source_ship = source_ship
	pod.boarder_ref = WEAKREF(boss)

	// Create the landing zone - this handles the whole falling animation
	new /obj/effect/pod_landingzone/boarding(target_turf, pod, target_ship, source_ship)

	return boss

/**
 * Boss Boarding Pod - A heavier variant for boss delivery
 *
 * More dramatic entrance with bigger explosion and slower approach.
 */
/obj/structure/closet/supplypod/boarding/boss
	name = "heavy boarding pod"
	desc = "A reinforced assault pod. Something dangerous is inside."
	explosionSize = list(0, 0, 1, 2)  // Bigger impact
	damage = 50  // More damage to anyone caught underneath
	delays = list(POD_TRANSIT = 20, POD_FALLING = 5, POD_OPENING = 10, POD_LEAVING = 8)

/obj/structure/closet/supplypod/boarding/boss/preOpen()
	. = ..()
	// Extra dramatic sound for boss arrival
	if(target_ship)
		playsound_ship(get_turf(src), 'sound/effects/explosion/explosion1.ogg', 80, TRUE, 10, target_ship)

/obj/structure/closet/supplypod/boarding/boss/setup_boarder_patrol(mob/living/boarder, obj/structure/overmap/ship/target_ship, spawn_index)
	log_shuttle("PATROL: Boss setup_boarder_patrol called: boarder=[boarder], target_ship=[target_ship]")

	if(!boarder)
		log_shuttle("PATROL: FAILED - boarder is null")
		return

	// Determine the boss-specific patrolling AI controller type
	var/new_controller_type
	if(istype(boarder.ai_controller, /datum/ai_controller/basic_controller/trooper/ranged))
		new_controller_type = /datum/ai_controller/basic_controller/trooper/ranged/patrolling/boss
		log_shuttle("PATROL: Detected ranged boss, will swap to ranged/patrolling/boss")
	else
		new_controller_type = /datum/ai_controller/basic_controller/trooper/patrolling/boss
		log_shuttle("PATROL: Detected melee boss, will swap to patrolling/boss")

	// Swap to boss patrolling controller
	if(new_controller_type)
		log_shuttle("PATROL: Creating new boss controller of type [new_controller_type]")
		boarder.ai_controller.set_ai_status(AI_STATUS_OFF)
		qdel(boarder.ai_controller)
		boarder.ai_controller = new new_controller_type(boarder)
		boarder.ai_controller.set_ai_status(AI_STATUS_ON)

	// Assign patrol path
	var/result = assign_mob_to_patrol(boarder, target_ship)
	log_shuttle("PATROL: Boss assign_mob_to_patrol returned: [result]")
