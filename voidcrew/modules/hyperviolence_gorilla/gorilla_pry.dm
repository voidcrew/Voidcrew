/**
 * # Gorilla door pry
 *
 * The synced pair's bare-handed pry (Gorilla Arms, and slower from Brawler myomers) is tg's door_pryer (instant on an unpowered door, a slow pry on a
 * powered one, refused through bolts, welds and seals), with two changes:
 * - Trader outpost doors never give: the sanctuary airlocks and any door on an outpost's protected
 *   ground. Trying counts as aggression against the outpost. A combat-mode punch at one is refused the
 *   same way (ware_military_arms.dm on_punch()).
 * - A powered pry strains: every half second the bearer trembles, the door shakes, the seam opens a
 *   little wider and throws sparks.
 */
/datum/element/door_pryer/gorilla

/datum/element/door_pryer/gorilla/on_attack(mob/living/attacker, atom/target, proximity_flag)
	SIGNAL_HANDLER
	if(proximity_flag && istype(target, /obj/machinery/door/airlock) && !attacker.combat_mode)
		var/obj/machinery/door/airlock/airlock_target = target
		if(airlock_target.density && gorilla_pry_refused(airlock_target))
			airlock_target.balloon_alert(attacker, "it won't budge!")
			gorilla_pry_aggression(airlock_target, attacker)
			attacker.log_message("tried to pry open [airlock_target] at a trader outpost, located at [loc_name(airlock_target)].", LOG_GAME)
			return COMPONENT_CANCEL_ATTACK_CHAIN
		// Browned out or EMP'd, the arms are only arms: an ordinary click on the door
		if(airlock_target.density && iscarbon(attacker))
			for(var/obj/item/organ/cyberimp/cyberware/gorilla_arms/arm as anything in gorilla_synced_pair(attacker))
				if(!arm.gorilla_running())
					return NONE
	return ..()

/// Whether a trader outpost keeps this door shut against Gorilla Arms or Brawler myomers, pried or punched.
/proc/gorilla_pry_refused(obj/machinery/door/door)
	return istype(door, /obj/machinery/door/airlock/outpost) || is_trader_outpost_protected(door)

/// Trying to force a trader outpost's door counts against the one who tried.
/proc/gorilla_pry_aggression(obj/machinery/door/door, mob/living/offender)
	var/obj/machinery/door/airlock/outpost/outpost_door = door
	if(istype(outpost_door) && outpost_door.outpost)
		outpost_door.outpost.register_aggression(offender)
		return
	var/obj/structure/overmap/trader_outpost/guarding = get_trader_outpost_for_turf(get_turf(door))
	guarding?.register_aggression(offender)

/datum/element/door_pryer/gorilla/open_door(mob/living/attacker, obj/machinery/door/airlock/airlock_target)
	// Unpowered or opened for them: nothing to strain against.
	if(!airlock_target.hasPower() || airlock_target.allowed(attacker))
		return ..()
	var/datum/gorilla_pry_strain/strain = new(attacker, airlock_target, pry_time)
	. = ..()
	qdel(strain)

/// The strain of a powered pry, beat by beat, while the do_after runs.
/datum/gorilla_pry_strain
	var/mob/living/carbon/bearer
	var/obj/machinery/door/airlock/door
	/// The seam opening over the door
	var/obj/effect/abstract/gorilla_pry_seam/seam
	/// Beats so far
	var/beats = 0
	var/beat_timer
	/// world.time the pry began
	var/started
	/// How long the pry takes
	var/pry_time

/datum/gorilla_pry_strain/New(mob/living/carbon/bearer, obj/machinery/door/airlock/door, pry_time = GORILLA_PRY_TIME)
	. = ..()
	src.bearer = bearer
	src.door = door
	src.pry_time = pry_time
	started = world.time
	seam = new(null)
	seam.stepped = gorilla_door_seam_stepped(door)
	seam.set_width(0)
	door.vis_contents += seam
	RegisterSignal(door, COMSIG_QDELETING, PROC_REF(on_deleted))
	RegisterSignal(door, COMSIG_AIRLOCK_OPEN, PROC_REF(on_opening))
	RegisterSignal(bearer, COMSIG_QDELETING, PROC_REF(on_deleted))
	// The first beat waits a tick. Every beat asks whether the pry is still going, and the pry's do_after only
	// starts once this strain is made: asked here the answer was always no, and no beat ever ran.
	beat_timer = addtimer(CALLBACK(src, PROC_REF(beat)), 1, TIMER_STOPPABLE|TIMER_DELETE_ME)

/datum/gorilla_pry_strain/Destroy()
	if(beat_timer)
		deltimer(beat_timer)
		beat_timer = null
	if(door)
		UnregisterSignal(door, list(COMSIG_QDELETING, COMSIG_AIRLOCK_OPEN))
		door.vis_contents -= seam
	if(bearer)
		UnregisterSignal(bearer, COMSIG_QDELETING)
	QDEL_NULL(seam)
	bearer = null
	door = null
	return ..()

/datum/gorilla_pry_strain/proc/on_deleted(datum/source)
	SIGNAL_HANDLER
	qdel(src)

/// The door gives: from here the gap is the door's own, sliding open. The seam goes before the leaves move.
/datum/gorilla_pry_strain/proc/on_opening(datum/source)
	SIGNAL_HANDLER
	if(door && seam)
		door.vis_contents -= seam

/datum/gorilla_pry_strain/proc/beat()
	beat_timer = null
	if(QDELETED(bearer) || QDELETED(door) || !DOING_INTERACTION_WITH_TARGET(bearer, door))
		return
	beats++
	// A tremble that is over before the next beat: a pixel each way, twice. tg's jitter runs on for more than two
	// seconds, so the bearer would still be shaking long after the door had opened, and it can roll no movement at all.
	var/side = pick(-1, 1)
	animate(bearer, pixel_w = side, time = 0.1 SECONDS, loop = 2, flags = ANIMATION_RELATIVE|ANIMATION_PARALLEL)
	animate(pixel_w = -side, time = 0.1 SECONDS, flags = ANIMATION_RELATIVE)
	door.Shake(1, 0, 0.3 SECONDS)
	seam.set_width((world.time - started) / max(pry_time, 1))
	do_sparks(2, TRUE, door)
	beat_timer = addtimer(CALLBACK(src, PROC_REF(beat)), 0.5 SECONDS, TIMER_STOPPABLE|TIMER_DELETE_ME)

/// The crack forced open down an airlock's middle seam: a dark gap with lit edges.
/obj/effect/abstract/gorilla_pry_seam
	name = "seam"
	icon = GORILLA_GORE_ICON
	icon_state = "pry_seam_1"
	mouse_opacity = MOUSE_OPACITY_TRANSPARENT
	vis_flags = VIS_INHERIT_PLANE | VIS_INHERIT_ID
	layer = ABOVE_OBJ_LAYER
	/// The door's leaves meet on the stepped seam of tg's station airlocks, not a straight one
	var/stepped = FALSE

/// Widens the seam as the pry goes on: three steps, a third of the pry each. [progress] runs 0 to 1.
/obj/effect/abstract/gorilla_pry_seam/proc/set_width(progress)
	icon_state = "pry_seam_[stepped ? "step_" : ""][clamp(1 + round(progress * 3), 1, 3)]"

/**
 * Whether [door]'s two leaves meet on the stepped seam tg's station airlock sprites share (public, command,
 * maintenance and the rest of icons/obj/doors/airlocks/station), so the gap is drawn along it. Any other door
 * gets the straight gap.
 */
/proc/gorilla_door_seam_stepped(obj/machinery/door/airlock/door)
	return !!findtext("[door.icon]", "/airlocks/station/")
