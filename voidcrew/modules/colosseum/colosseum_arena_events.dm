/**
 * # Colosseum dynamic arena events
 *
 * A per-match hazard scheduler the mode opts into (var/arena_events on
 * /datum/colosseum_game). While the match is LIVE it periodically rolls one of:
 *
 * * Weapon crate drop: a supply pod delivers a crate of arena weapons onto a
 *   telegraphed tile (the pod's own landing zone marker is the telegraph).
 * * Hazard eruption: a telegraphed plus-shaped patch of the sand turns to
 *   lava for COLOSSEUM_HAZARD_DURATION, then the sand is restored.
 * * Pop-up cover: telegraphed destructible barricades rise from the sand.
 *
 * Placement prefers the mapped /obj/effect/landmark/colosseum/arena_event
 * spots and falls back to random clear sand, so map edits can't starve it.
 * Everything spawned or changed here lives in the arena area, which the
 * end-of-match snapshot reset restores wholesale.
 */

/// Telegraph marker: flashes on the target tile before an event lands.
/obj/effect/temp_visual/colosseum_warning
	name = "warning beacon"
	icon = 'icons/obj/supplypods_32x32.dmi'
	icon_state = "LZ"
	duration = COLOSSEUM_EVENT_TELEGRAPH
	layer = ABOVE_OPEN_TURF_LAYER

/datum/colosseum_arena_scheduler
	/// The match controller that owns us
	var/datum/colosseum_controller/controller
	/// Pending roll timer (TIMER_STOPPABLE)
	var/roll_timer
	/// Hazard patches awaiting restoration: list of list(turf, original_type)
	var/list/pending_restores = list()
	/// Bounds between event rolls
	var/roll_lower = 45 SECONDS
	var/roll_upper = 90 SECONDS

/datum/colosseum_arena_scheduler/New(datum/colosseum_controller/controller)
	src.controller = controller
	schedule()

/datum/colosseum_arena_scheduler/Destroy()
	if(roll_timer)
		deltimer(roll_timer)
		roll_timer = null
	restore_hazards() // never leave lava behind when the match ends early
	controller = null
	return ..()

/datum/colosseum_arena_scheduler/proc/schedule()
	roll_timer = addtimer(CALLBACK(src, PROC_REF(fire)), rand(roll_lower, roll_upper), TIMER_STOPPABLE)

/datum/colosseum_arena_scheduler/proc/fire()
	roll_timer = null
	if(QDELETED(src) || !controller || controller.state != COLOSSEUM_STATE_LIVE)
		return
	switch(pick_weight(list("crate" = 40, "hazard" = 30, "cover" = 30)))
		if("crate")
			drop_weapon_crate()
		if("hazard")
			erupt_hazard()
		if("cover")
			raise_cover()
	schedule()

/// A clear event tile (mapped spot or clear sand), delegated to the controller
/// so match modifiers can use the same placement rules without a scheduler.
/datum/colosseum_arena_scheduler/proc/get_event_turf()
	return controller.arena_event_turf()

// ===== WEAPON CRATE =====

/datum/colosseum_arena_scheduler/proc/drop_weapon_crate()
	controller.drop_weapon_crate()

// ===== HAZARD ERUPTION =====

/datum/colosseum_arena_scheduler/proc/erupt_hazard()
	var/turf/center = get_event_turf()
	if(!center)
		return
	var/list/turf/patch = list(center)
	for(var/direction in GLOB.cardinals)
		var/turf/edge = get_step(center, direction)
		if(edge && istype(edge.loc, /area/voidcrew/colosseum/arena))
			patch += edge
	for(var/turf/hazard_turf as anything in patch)
		new /obj/effect/temp_visual/colosseum_warning(hazard_turf)
	playsound(center, 'sound/machines/warning-buzzer.ogg', 70, TRUE)
	controller.site.venue_message(span_boldannounce("The sand glows, the floor is about to open!"))
	addtimer(CALLBACK(src, PROC_REF(hazard_go), patch), COLOSSEUM_EVENT_TELEGRAPH, TIMER_STOPPABLE)

/datum/colosseum_arena_scheduler/proc/hazard_go(list/turf/patch)
	if(QDELETED(src) || !controller || controller.state != COLOSSEUM_STATE_LIVE)
		return
	for(var/turf/hazard_turf as anything in patch)
		if(QDELETED(hazard_turf) || istype(hazard_turf, /turf/open/indestructible) || istype(hazard_turf, /turf/closed))
			continue // never melt the dais/plinths or a wall
		pending_restores += list(list(hazard_turf, hazard_turf.type))
		hazard_turf.ChangeTurf(/turf/open/lava/smooth, flags = CHANGETURF_IGNORE_AIR)
	addtimer(CALLBACK(src, PROC_REF(restore_hazards)), COLOSSEUM_HAZARD_DURATION, TIMER_STOPPABLE)

/// Puts the sand back. Also called on Destroy so early match ends can't leak lava.
/datum/colosseum_arena_scheduler/proc/restore_hazards()
	for(var/list/entry as anything in pending_restores)
		var/turf/hazard_turf = entry[1]
		if(QDELETED(hazard_turf) || !islava(hazard_turf))
			continue
		hazard_turf.ChangeTurf(entry[2], flags = CHANGETURF_IGNORE_AIR)
	pending_restores.Cut()

// ===== POP-UP COVER =====

/datum/colosseum_arena_scheduler/proc/raise_cover()
	var/list/turf/spots = list()
	for(var/i in 1 to 3)
		var/turf/spot = get_event_turf()
		if(spot && !(spot in spots))
			spots += spot
	if(!length(spots))
		return
	for(var/turf/cover_turf as anything in spots)
		new /obj/effect/temp_visual/colosseum_warning(cover_turf)
	controller.site.venue_message(span_boldannounce("Fresh cover rises from the arena floor!"))
	addtimer(CALLBACK(src, PROC_REF(cover_go), spots), COLOSSEUM_EVENT_TELEGRAPH, TIMER_STOPPABLE)

/datum/colosseum_arena_scheduler/proc/cover_go(list/turf/spots)
	if(QDELETED(src) || !controller || controller.state != COLOSSEUM_STATE_LIVE)
		return
	for(var/turf/cover_turf as anything in spots)
		if(QDELETED(cover_turf) || cover_turf.is_blocked_turf())
			continue
		var/cover_type = pick(/obj/structure/barricade/sandbags, /obj/structure/barricade/wooden)
		new cover_type(cover_turf)
