/**
 * NPC Boarding Pod - Launches from pirate ships to deposit hostile mobs on player ships
 *
 * Uses the existing supplypod/landing zone system for the dramatic drop-from-above effect.
 * Pod lands, opens to reveal the boarder, then vanishes.
 */

/// Global proc to create a boarding pod drop at a target location
/proc/create_boarding_pod(turf/target_turf, obj/structure/overmap/ship/target_ship, obj/structure/overmap/ship/npc/source_ship, mob_type)
	if(!target_turf || !mob_type)
		return FALSE

	// Create the boarding pod with the mob inside
	var/obj/structure/closet/supplypod/boarding/pod = new()

	// Create the boarder mob and put it in the pod
	var/mob/living/boarder = new mob_type(pod)
	if(!boarder)
		qdel(pod)
		return FALSE

	// Store references for the pod
	pod.target_ship = target_ship
	pod.source_ship = source_ship

	// Create the landing zone - this handles the whole falling animation
	new /obj/effect/pod_landingzone/boarding(target_turf, pod, target_ship, source_ship)

	return TRUE

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

/obj/structure/closet/supplypod/boarding/preOpen()
	. = ..()
	// Play a distinctive sound when the pod lands
	if(target_ship)
		playsound_ship(get_turf(src), 'sound/effects/meteorimpact.ogg', 60, TRUE, 10, target_ship)

/obj/structure/closet/supplypod/boarding/open_pod(atom/movable/holder, broken = FALSE, forced = FALSE)
	. = ..()
	// Announce the boarder emerging
	var/turf/T = get_turf(holder)
	for(var/mob/living/boarder in T)
		boarder.visible_message(span_danger("[boarder] emerges from the boarding pod!"))

	// Signal that boarders have arrived
	if(target_ship && !QDELETED(target_ship))
		SEND_SIGNAL(target_ship, COMSIG_SHIP_BOARDED, src, source_ship)

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
