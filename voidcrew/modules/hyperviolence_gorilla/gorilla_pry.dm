/**
 * # Gorilla door pry
 *
 * The synced pair's bare-handed pry is tg's door_pryer (instant on an unpowered door, a slow pry on a
 * powered one, refused through bolts, welds and seals), with two changes:
 * - Trader outpost doors never give: the sanctuary airlocks and any door on an outpost's protected
 *   ground. Trying counts as aggression against the outpost.
 * - A powered pry strains: every half second the pistons pump and steam, the arms heat and tremble, the
 *   door shakes, the seam opens a little wider and throws sparks.
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
	return ..()

/// Whether a trader outpost keeps this door shut against the Gorilla.
/proc/gorilla_pry_refused(obj/machinery/door/airlock/door)
	return istype(door, /obj/machinery/door/airlock/outpost) || is_trader_outpost_protected(door)

/// Trying to force a trader outpost's door counts against the one who tried.
/proc/gorilla_pry_aggression(obj/machinery/door/airlock/door, mob/living/offender)
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
	var/datum/gorilla_pry_strain/strain = new(attacker, airlock_target)
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

/datum/gorilla_pry_strain/New(mob/living/carbon/bearer, obj/machinery/door/airlock/door)
	. = ..()
	src.bearer = bearer
	src.door = door
	seam = new(null)
	door.vis_contents += seam
	RegisterSignal(door, COMSIG_QDELETING, PROC_REF(on_deleted))
	RegisterSignal(bearer, COMSIG_QDELETING, PROC_REF(on_deleted))
	beat()

/datum/gorilla_pry_strain/Destroy()
	if(beat_timer)
		deltimer(beat_timer)
		beat_timer = null
	if(door)
		UnregisterSignal(door, COMSIG_QDELETING)
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

/datum/gorilla_pry_strain/proc/beat()
	beat_timer = null
	if(QDELETED(bearer) || QDELETED(door) || !DOING_INTERACTION_WITH_TARGET(bearer, door))
		return
	beats++
	for(var/obj/item/organ/cyberimp/cyberware/gorilla_arms/arm as anything in gorilla_heavy_arms(bearer))
		arm.play_pump()
		if(beats == 1)
			arm.play_heat(4 SECONDS, 4.5 SECONDS)
	cyberware_anim_particles(bearer, /particles/smoke/steam/gorilla_puff, GORILLA_ANIM_TOP_LAYER, 0.2 SECONDS, 1 SECONDS)
	bearer.do_jitter_animation(20)
	door.Shake(1, 0, 0.3 SECONDS)
	seam.set_width(beats)
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

/// Widens the seam with the strain: three steps.
/obj/effect/abstract/gorilla_pry_seam/proc/set_width(beats)
	icon_state = "pry_seam_[clamp(round((beats + 1) / 3), 1, 3)]"
