/**
 * NPC Boarding Pod - Launches from pirate ships to deposit hostile mobs on player ships
 *
 * Uses the existing supplypod/landing zone system for the dramatic drop-from-above effect.
 * Pod lands, opens to reveal the boarder, then vanishes.
 *
 * Human NPC boarders (the NPC ship crews, faction_pirate_humans.dm) are built through the spawn queue
 * (spawn_human_npc(), a body at a time) aboard the pirate's own hull, dressed from their faction's
 * boarding table (a sealed suit and air), and only then put in their pod and launched
 * (boarding_pod_launch()). A basic-mob boarder is built straight into its pod as before. Either way the
 * caller hears about the boarder through `on_boarder`, called with it once it is in its pod.
 */

/// Tracks spawn index for distributing boarders along patrol path
GLOBAL_VAR_INIT(boarding_spawn_index, 0)
GLOBAL_VAR_INIT(boarding_spawn_total, 1)

/**
 * Launches a boarding pod at `target_turf` carrying a `mob_type`. Returns the boarder (a basic mob, built
 * now), the /datum/human_npc_order of a human boarder still in the spawn queue, or null if nothing was
 * sent. `on_boarder` is called with the boarder once it is in its pod.
 */
/proc/create_boarding_pod(turf/target_turf, obj/structure/overmap/ship/target_ship, obj/structure/overmap/ship/npc/source_ship, mob_type, datum/npc_spawn_context/encounter, budget_reserved = FALSE, datum/callback/on_boarder)
	if(!target_turf || !mob_type)
		return null
	// Combat volleys call this on a timer; the target may have docked since firing.
	if(QDELETED(target_ship) || QDELETED(source_ship) || target_ship.state != OVERMAP_SHIP_FLYING || source_ship.state != OVERMAP_SHIP_FLYING)
		return null

	var/datum/ai_controller/npc_ship/controller = source_ship.ai_controller
	if(!istype(controller) || controller.get_target() != target_ship)
		return null
	controller.capture_boarding_encounter(target_ship)
	if(encounter && encounter != controller.boarding_context)
		return null
	if(!budget_reserved && !controller.reserve_boarders(target_ship, 1))
		return null
	var/datum/npc_spawn_context/context = new(target_ship, controller.boarding_context.zone_type, "ordinary", source_turf = controller.boarding_context.source_turf)

	if(ispath(mob_type, /mob/living/carbon/human/npc))
		var/datum/callback/launch = CALLBACK(GLOBAL_PROC, GLOBAL_PROC_REF(boarding_pod_launch), /obj/structure/closet/supplypod/boarding, target_turf, target_ship, source_ship, on_boarder)
		var/datum/human_npc_order/order = spawn_human_npc(mob_type, boarding_pod_build_turf(source_ship, target_turf), launch, outfit = boarding_outfit_for(mob_type), context = context)
		controller.track_boarding_order(order)
		return order

	// Create the boarding pod with the mob inside
	var/obj/structure/closet/supplypod/boarding/pod = new()

	// Create the boarder mob and put it in the pod
	var/mob/living/boarder = spawn_npc_in_zone(mob_type, pod, context)
	if(!boarder)
		qdel(pod)
		return null

	boarding_pod_send(pod, boarder, target_turf, target_ship, source_ship)
	on_boarder?.Invoke(boarder)
	return boarder

/// Where a human boarder is built before it goes in its pod: aboard the pirate's own hull, where it
/// climbs into the pod, else (a hull with no dock) the landing spot itself. It is in its pod the same tick.
/proc/boarding_pod_build_turf(obj/structure/overmap/ship/npc/source_ship, turf/target_turf)
	return get_turf(source_ship?.shuttle) || target_turf

/// The boarding outfit table for a human ship crewman (its faction's table sealed for vacuum), or null
/// for anything else.
/proc/boarding_outfit_for(mob_type)
	if(!ispath(mob_type, /mob/living/carbon/human/npc/faction_pirate))
		return null
	var/mob/living/carbon/human/npc/faction_pirate/crew_type = mob_type
	return initial(crew_type.boarding_outfit_table)

/**
 * A human boarder is built (the spawn queue's callback): if the raid it was sent on still stands, it goes
 * in its pod and the pod launches; if the target docked or the raid ended meanwhile, the delivery is
 * cancelled and the boarder deleted before anyone saw it. A boss learns which hull it boarded for.
 */
/proc/boarding_pod_launch(pod_type, turf/target_turf, obj/structure/overmap/ship/target_ship, obj/structure/overmap/ship/npc/source_ship, datum/callback/on_boarder, mob/living/boarder)
	if(QDELETED(boarder))
		return
	var/datum/ai_controller/npc_ship/controller = source_ship?.ai_controller
	if(QDELETED(target_ship) || QDELETED(source_ship) || target_ship.state != OVERMAP_SHIP_FLYING || source_ship.state != OVERMAP_SHIP_FLYING || !istype(controller) || controller.get_target() != target_ship)
		qdel(boarder)
		return
	var/obj/structure/closet/supplypod/boarding/pod = new pod_type()
	boarder.forceMove(pod)
	var/mob/living/carbon/human/npc/faction_pirate/crewman = boarder
	if(istype(crewman) && ispath(pod_type, /obj/structure/closet/supplypod/boarding/boss))
		crewman.parent_ship = source_ship
	boarding_pod_send(pod, boarder, target_turf, target_ship, source_ship)
	on_boarder?.Invoke(boarder)

/// Sends `pod`, with `boarder` already inside, falling onto `target_turf`.
/proc/boarding_pod_send(obj/structure/closet/supplypod/boarding/pod, mob/living/boarder, turf/target_turf, obj/structure/overmap/ship/target_ship, obj/structure/overmap/ship/npc/source_ship)
	pod.target_ship = target_ship
	pod.source_ship = source_ship
	pod.boarder_ref = WEAKREF(boarder)
	pod.spawn_index = GLOB.boarding_spawn_index++
	// Create the landing zone - this handles the whole falling animation
	new /obj/effect/pod_landingzone/boarding(target_turf, pod, target_ship, source_ship)

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

	// Announce the boarder emerging
	var/turf/T = get_turf(holder)
	for(var/mob/living/emerged_mob in T)
		emerged_mob.visible_message(span_danger("[emerged_mob] emerges from the boarding pod!"))

	// Send the boarder after the crew
	var/mob/living/boarder = boarder_ref?.resolve()
	if(boarder && target_ship && !QDELETED(target_ship))
		setup_boarder_patrol(boarder, target_ship, spawn_index)

	// Signal that boarders have arrived
	if(target_ship && !QDELETED(target_ship))
		SEND_SIGNAL(target_ship, COMSIG_SHIP_BOARDED, src, source_ship)

/**
 * Puts a boarder in the raid on the ship it landed on (pirate_crew.dm): every boarder of every
 * wave, from any pirate, hunts that ship's crew together.
 */
/obj/structure/closet/supplypod/boarding/proc/setup_boarder_patrol(mob/living/boarder, obj/structure/overmap/ship/target_ship, spawn_index)
	if(QDELETED(boarder))
		return
	if(!pirate_crew_enlist_raider(boarder, target_ship))
		log_shuttle("PIRATE_CREW: boarder [boarder] ([boarder.type]) could not join the raid on [target_ship]")

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

/**
 * Launches the boss's heavy boarding pod at `target_turf`. Returns the boss (a basic mob), the order of a
 * human boss still in the spawn queue, or null. `on_boss` is called with the boss once it is in its pod.
 * A human boss keeps its own look (it is dressed from its faction's ordinary table, with a mask and air).
 */
/proc/create_boss_boarding_pod(turf/target_turf, obj/structure/overmap/ship/target_ship, obj/structure/overmap/ship/npc/source_ship, mob_type, datum/callback/on_boss)
	if(!target_turf || !mob_type)
		return null
	if(QDELETED(target_ship) || QDELETED(source_ship) || target_ship.state != OVERMAP_SHIP_FLYING || source_ship.state != OVERMAP_SHIP_FLYING)
		return null

	var/datum/ai_controller/npc_ship/controller = source_ship.ai_controller
	if(!istype(controller) || controller.get_target() != target_ship)
		return null
	controller.capture_boarding_encounter(target_ship)
	if(!controller.is_red_zone_raid() || controller.boarding_boss_sent)
		return null
	controller.boarding_boss_sent = TRUE
	var/datum/npc_spawn_context/context = new(target_ship, controller.boarding_context.zone_type, "boss", source_turf = controller.boarding_context.source_turf)

	if(ispath(mob_type, /mob/living/carbon/human/npc))
		var/datum/callback/launch = CALLBACK(GLOBAL_PROC, GLOBAL_PROC_REF(boarding_pod_launch), /obj/structure/closet/supplypod/boarding/boss, target_turf, target_ship, source_ship, on_boss)
		var/datum/human_npc_order/order = spawn_human_npc(mob_type, boarding_pod_build_turf(source_ship, target_turf), launch, context = context)
		controller.track_boarding_order(order)
		return order

	// Create the boss boarding pod
	var/obj/structure/closet/supplypod/boarding/boss/pod = new()

	// Create the boss mob and put it in the pod
	var/mob/living/basic/trooper/pirate/faction/boss/boss = spawn_npc_in_zone(mob_type, pod, context, FALSE)
	if(!boss)
		qdel(pod)
		return null

	// Set up boss-specific properties
	boss.parent_ship = source_ship
	context.finalize()

	boarding_pod_send(pod, boss, target_turf, target_ship, source_ship)
	on_boss?.Invoke(boss)
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
