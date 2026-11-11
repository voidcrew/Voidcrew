// Hyperviolence visuals: the animation pass over the gore. Bodies flinch, snap, lurch and limp when
// hit, fall away from the killing blow and twitch after, severed parts and brains tumble through
// the air, blood paints in, drips, spreads and floats, guts slither, and executions and
// boss finishers get their beats.
//
// Rules every animation here keeps:
// - Code animation only, on the sprites the body already has: animate(), transforms, pixel offsets,
//   one short colour filter. Nothing runs on a timer loop over mobs; everything is started by an
//   event that already happens (a hit, a death, a lost limb, a throw, a move, a stage of a finisher).
// - Each animation is a named sequence (_visuals_defines.dm) that ends exactly where it began. The
//   server-side transform and pixel offsets are never left changed, so tg's lying turn, offsets,
//   height filters and mob scaling stay right, and anything that later rebuilds the transform from
//   the current one (update_transform) builds on the true value.
// - Poses a corpse keeps (a slide, a curl) are held by the animation itself and ended by
//   /datum/component/hv_motion_hold when the body moves, stands up or is revived.
// - Purely visual: nothing here stuns, roots or delays anyone. A hit-stop freezes the pictures only.
// - Offsets stay small (under a third of a tile) so nobody is drawn over someone else's tile.
// - Screen shake only for viewers near a boss finisher's kill, small, and never for players who set
//   the screen shake preference (/datum/preference/toggle/screen_shake_darken).

/mob/living
	/// The tick of the hit being resolved, noted before its damage lands so a fall or death it
	/// causes can go its way.
	var/hv_vis_hit_time = -1
	/// The way that hit travelled, from the attacker toward this mob.
	var/hv_vis_hit_dir = 0
	/// The body zone it landed on.
	var/hv_vis_hit_zone
	/// Its damage type.
	var/hv_vis_hit_type
	/// All the damage this mob took in hits this tick, so a shotgun's pellets flinch as one blow.
	var/hv_vis_hit_damage = 0
	/// Weak reference to whoever landed it, for the hit-stop.
	var/datum/weakref/hv_vis_hit_by
	/// Whether it was a shot, which rocks a shooter back, rather than a blow, which they lean into.
	var/hv_vis_hit_ranged = FALSE
	/// How many hits are being resolved on this mob right now, and the tick that count is for.
	var/hv_vis_resolving = 0
	var/hv_vis_resolving_time = -1
	/// The tick a sever, burst or crit asked for a hit-stop.
	var/hv_vis_big_hit_time = -1
	/// The tick the last hit-stop played, so one blow plays it once.
	var/hv_vis_hitstop_time = -1
	/// The tick this mob went from standing to lying.
	var/hv_vis_fell_time = -1
	/// The tick this mob died.
	var/hv_vis_died_time = -1
	/// The tick an execution round was fired into this mob.
	var/hv_vis_execution_time = -1

/mob/living/Initialize(mapload)
	. = ..()
	AddElement(/datum/element/hv_motion_hooks)

/// Starts the animations on a mob from what happens to it. An element, not the mob registering on
/// itself: a mob holds one handler per signal per listener, so self-registrations collide with the
/// mob's own handlers (see /datum/element/hv_blood_hooks).
/datum/element/hv_motion_hooks

/datum/element/hv_motion_hooks/Attach(datum/target)
	. = ..()
	if(!isliving(target))
		return ELEMENT_INCOMPATIBLE
	RegisterSignal(target, COMSIG_MOB_APPLY_DAMAGE, PROC_REF(on_hit))
	RegisterSignal(target, COMSIG_MOB_AFTER_APPLY_DAMAGE, PROC_REF(after_hit))
	RegisterSignal(target, COMSIG_LIVING_DEATH, PROC_REF(on_death))
	RegisterSignal(target, COMSIG_MOB_STATCHANGE, PROC_REF(on_stat_change))
	RegisterSignal(target, COMSIG_MOB_EMOTED("surrender"), PROC_REF(on_surrender))
	if(iscarbon(target))
		RegisterSignal(target, COMSIG_CARBON_REMOVE_LIMB, PROC_REF(on_limb_lost))

/datum/element/hv_motion_hooks/Detach(datum/source)
	UnregisterSignal(source, list(
		COMSIG_MOB_APPLY_DAMAGE,
		COMSIG_MOB_AFTER_APPLY_DAMAGE,
		COMSIG_LIVING_DEATH,
		COMSIG_MOB_STATCHANGE,
		COMSIG_MOB_EMOTED("surrender"),
		COMSIG_CARBON_REMOVE_LIMB,
	))
	return ..()

/datum/element/hv_motion_hooks/proc/on_hit(mob/living/source, damage, damagetype, def_zone, blocked, wound_bonus, exposed_wound_bonus, sharpness, attack_direction, attacking_item)
	SIGNAL_HANDLER
	source.hv_vis_note_hit(damage, damagetype, def_zone, attack_direction, attacking_item)

/datum/element/hv_motion_hooks/proc/after_hit(mob/living/source, damage_dealt, damagetype, def_zone, blocked, wound_bonus, exposed_wound_bonus, sharpness, attack_direction, attacking_item)
	SIGNAL_HANDLER
	source.hv_vis_after_hit(damagetype, attack_direction)

/datum/element/hv_motion_hooks/proc/on_death(mob/living/source, gibbed)
	SIGNAL_HANDLER
	source.hv_vis_on_death(gibbed)

/datum/element/hv_motion_hooks/proc/on_stat_change(mob/living/source, new_stat, old_stat)
	SIGNAL_HANDLER
	source.hv_vis_on_stat_change(new_stat, old_stat)

/datum/element/hv_motion_hooks/proc/on_surrender(mob/living/source)
	SIGNAL_HANDLER
	source.hv_vis_surrender()

/datum/element/hv_motion_hooks/proc/on_limb_lost(mob/living/carbon/source, obj/item/bodypart/lost_limb, special, dismembered)
	SIGNAL_HANDLER
	source.hv_vis_on_limb_lost(lost_limb, special, dismembered)

// ---- What hit us ----

/// Notes a hit before its damage lands: which way it went, where, how hard, and who landed it.
/mob/living/proc/hv_vis_note_hit(damage, damagetype, def_zone, attack_direction, atom/attacking_item)
	if(hv_vis_resolving_time != world.time)
		hv_vis_resolving_time = world.time
		hv_vis_resolving = 0
	hv_vis_resolving++
	if(damagetype != BRUTE && damagetype != BURN && damagetype != STAMINA)
		return
	if(hv_vis_hit_time != world.time)
		hv_vis_hit_time = world.time
		hv_vis_hit_damage = 0
		hv_vis_hit_dir = 0
		hv_vis_hit_by = null
		hv_vis_hit_ranged = FALSE
	if(isprojectile(attacking_item))
		hv_vis_hit_ranged = TRUE
	// A baton or disabler hit makes a body jerk, but less than a bullet.
	hv_vis_hit_damage += damagetype == STAMINA ? damage * 0.5 : damage
	if(attack_direction)
		hv_vis_hit_dir = attack_direction
	hv_vis_hit_type = damagetype
	hv_vis_hit_zone = hv_vis_zone_of(def_zone)
	var/mob/living/attacker = hv_vis_attacker_of(attacking_item)
	if(attacker && attacker != src)
		hv_vis_hit_by = WEAKREF(attacker)

/// After a hit has landed: the flinch, held for a hit-stop if the hit took a limb, burst a head or
/// landed a crit. A hit that killed is shown by the death instead.
/mob/living/proc/hv_vis_after_hit(damagetype, attack_direction)
	if(hv_vis_resolving_time == world.time && hv_vis_resolving > 0)
		hv_vis_resolving--
	if(damagetype != BRUTE && damagetype != BURN && damagetype != STAMINA)
		return
	if(hv_vis_hit_time != world.time || hv_vis_died_time == world.time)
		return
	var/hit_dir = hv_vis_hit_dir || attack_direction
	if(!hit_dir || !isturf(loc))
		return
	// A body that lives through a hit only moves for a gore moment (a sever, burst or crit gets its
	// hit-stop). Killing blows are shown by the death (death_falls.dm); other hits don't move the body.
	if(hv_vis_big_hit_time != world.time)
		return
	var/headshot = hv_vis_hit_zone == BODY_ZONE_HEAD && damagetype != STAMINA && hv_vis_hit_damage >= HV_VIS_HEADSHOT_MIN
	hv_vis_flinch(hv_vis_hit_damage, hit_dir, headshot, HV_VIS_HITSTOP_TIME)
	hv_vis_hitstop_extras(hit_dir)

/// Whether a hit on this mob is being resolved right now, between its two damage signals.
/mob/living/proc/hv_vis_inside_hit()
	return hv_vis_resolving_time == world.time && hv_vis_resolving > 0

/// A limb came off, a head burst or a crit landed: this blow gets a hit-stop. Inside a hit, the flinch
/// at its end holds; anything else (an execution's burst, a finisher's kill) plays it now.
/mob/living/proc/hv_vis_big_hit(hit_dir, mob/living/attacker)
	hv_vis_big_hit_time = world.time
	if(attacker && attacker != src)
		hv_vis_hit_by = WEAKREF(attacker)
	if(hv_vis_inside_hit() || !isturf(loc))
		return
	if(!hit_dir)
		hit_dir = hv_vis_hit_dir || dir
	if(hv_vis_died_time != world.time)
		var/damage = hv_vis_hit_time == world.time ? hv_vis_hit_damage : 0
		hv_vis_flinch(max(damage, HV_VIS_STAGGER_DAMAGE), hit_dir, FALSE, HV_VIS_HITSTOP_TIME)
	hv_vis_hitstop_extras(hit_dir)

/// The zone a hit landed on, whether given as a bodypart or a zone name.
/proc/hv_vis_zone_of(def_zone)
	if(isbodypart(def_zone))
		var/obj/item/bodypart/limb = def_zone
		return limb.body_zone
	if(istext(def_zone))
		return check_zone(def_zone)
	return null

/// Who is behind a hit: the firer of a projectile, the holder of a weapon, or a mob itself.
/proc/hv_vis_attacker_of(atom/attacking_item)
	if(isprojectile(attacking_item))
		var/obj/projectile/shot = attacking_item
		return isliving(shot.firer) ? shot.firer : null
	if(isitem(attacking_item))
		var/obj/item/weapon = attacking_item
		return isliving(weapon.loc) ? weapon.loc : null
	if(isliving(attacking_item))
		return attacking_item
	return null

// ---- Playing animations ----

/**
 * Plays a named sequence of steps on this atom. Each step is list(pixel_w, pixel_z, transform, time,
 * easing), absolute values; the last step must be where the atom stands now, so the sequence ends
 * where it began. A named sequence only adds its own change to whatever else is animating.
 */
/atom/proc/hv_vis_play(tag, list/steps, loop = 1)
	if(!length(steps))
		return
	// In a Sandevistan field (cyberware/ware_sandy_timestop.dm) it plays at the field's pace.
	var/list/times = list()
	for(var/list/step as anything in steps)
		times += step[4]
	var/list/real = cyberware_dilated_steps(src, times, loop, tag)
	var/started = FALSE
	for(var/i in 1 to length(steps))
		var/list/step = steps[i]
		var/time = real ? real[i] : step[4]
		if(!started)
			animate(src, pixel_w = step[1], pixel_z = step[2], transform = step[3], time = time, easing = step[5], loop = loop, tag = tag)
			started = TRUE
		else
			animate(pixel_w = step[1], pixel_z = step[2], transform = step[3], time = time, easing = step[5])

/**
 * Plays steps that take over this atom's whole animation: each step is list(pixel_y, transform, time,
 * easing). Used only where tg's own lying turn has to wait (a body held up for a beat before it
 * falls). The last step must be the atom's real pixel_y and transform. Never on a floating mob: it
 * would stop the floating bob.
 */
/atom/proc/hv_vis_play_over(list/steps)
	if(!length(steps))
		return
	// Slowed like hv_vis_play() in a Sandevistan field.
	var/list/times = list()
	for(var/list/step as anything in steps)
		times += step[3]
	var/list/real = cyberware_dilated_steps(src, times)
	var/started = FALSE
	for(var/i in 1 to length(steps))
		var/list/step = steps[i]
		var/time = real ? real[i] : step[3]
		if(!started)
			animate(src, pixel_y = step[1], transform = step[2], time = time, easing = step[4])
			started = TRUE
		else
			animate(pixel_y = step[1], transform = step[2], time = time, easing = step[4])

/// Eases a named sequence back to where the atom really is over `time`, from wherever it has got to.
/atom/proc/hv_vis_release(tag, time = 2)
	time = cyberware_dilated_time(src, time)
	animate(src, pixel_w = pixel_w, pixel_z = pixel_z, transform = transform, time = time, easing = SINE_EASING, tag = tag)

/// Stops named sequences at once.
/atom/proc/hv_vis_stop(list/tags)
	for(var/tag in tags)
		animate(src, tag = tag)

/// A copy of `base` turned `angle` degrees clockwise about a point `pivot_y` pixels above (or below)
/// and `pivot_x` pixels right (or left) of the middle of the icon, as drawn.
/proc/hv_vis_turned(matrix/base, angle, pivot_y = 0, pivot_x = 0)
	var/matrix/turned = matrix(base)
	if(!angle)
		return turned
	turned.Translate(-pivot_x, -pivot_y)
	turned.Turn(angle)
	turned.Translate(pivot_x, pivot_y)
	return turned

/// `base` with a change made in the body's own frame first: scaled, then moved, then turned, before
/// `base` lays it down. On a lying body this shortens the body along its own length.
/proc/hv_vis_local(matrix/base, scale_x = 1, scale_y = 1, angle = 0, move_x = 0, move_y = 0)
	var/matrix/local = matrix()
	local.Scale(scale_x, scale_y)
	if(move_x || move_y)
		local.Translate(move_x, move_y)
	if(angle)
		local.Turn(angle)
	return local * matrix(base)

/// Where a lean of this mob pivots, from the middle of its icon: the feet of a standing body.
/mob/living/proc/hv_vis_pivot()
	if(!iscarbon(src) || body_position == LYING_DOWN)
		return 0
	return HV_VIS_FEET_Y * current_size

/// Whether this mob is so big that blows barely move it.
/mob/living/proc/hv_vis_is_huge()
	return mob_size >= MOB_SIZE_LARGE || maxHealth >= 400

// ---- Hit-stop ----

/// The hit-stop on top of the held flinch, once per blow: the body flashes pale and whoever landed it
/// holds their pose for the same frames.
/mob/living/proc/hv_vis_hitstop_extras(hit_dir, mob/living/attacker)
	if(hv_vis_hitstop_time == world.time)
		return
	hv_vis_hitstop_time = world.time
	hv_vis_flash()
	if(!attacker)
		attacker = hv_vis_hit_by?.resolve()
	if(!attacker || attacker == src || QDELETED(attacker) || attacker.z != z || get_dist(attacker, src) > 9)
		return
	attacker.hv_vis_hold_blow(src, hv_vis_hit_time == world.time && hv_vis_hit_ranged)

/// A pale flash over the body for the frames of a hit-stop. A colour filter, gone again half a second later.
/mob/living/proc/hv_vis_flash()
	if(!get_filter(HV_VIS_FLASH_FILTER))
		add_filter(HV_VIS_FLASH_FILTER, 10, color_matrix_filter(list(1,0,0, 0,1,0, 0,0,1, 0,0,0)))
	var/flash = get_filter(HV_VIS_FLASH_FILTER)
	if(!flash)
		return
	var/list/real = cyberware_dilated_steps(src, list(0.5, HV_VIS_HITSTOP_TIME, 1)) || list(0.5, HV_VIS_HITSTOP_TIME, 1)
	animate(flash, color = list(0.6,0,0, 0,0.6,0, 0,0,0.6, 0.4,0.4,0.4), time = real[1], easing = LINEAR_EASING)
	animate(color = list(0.6,0,0, 0,0.6,0, 0,0,0.6, 0.4,0.4,0.4), time = real[2], easing = LINEAR_EASING)
	animate(color = list(1,0,0, 0,1,0, 0,0,1, 0,0,0), time = real[3], easing = LINEAR_EASING)
	addtimer(CALLBACK(src, TYPE_PROC_REF(/datum, remove_filter), HV_VIS_FLASH_FILTER), cyberware_dilated_time(src, 0.5 SECONDS), TIMER_UNIQUE|TIMER_OVERRIDE|TIMER_DELETE_ME)

/// The attacker's side of a hit-stop: the blow sticks for a few frames. A melee attacker stays leaned
/// into the victim; a shooter stays rocked back, even with the barrel against them (`shot`).
/mob/living/proc/hv_vis_hold_blow(atom/victim, shot = FALSE)
	if(!isturf(loc))
		return
	var/toward = get_dir(src, victim)
	var/lean = (shot || get_dist(src, victim) > 1) ? -2 : 3
	var/dx = HV_VIS_DX(toward) * lean
	var/dy = HV_VIS_DY(toward) * lean
	var/matrix/base = matrix(transform)
	hv_vis_play(HV_VIS_TAG_HITSTOP, list(
		list(pixel_w + dx, pixel_z + dy, base, 0.5, QUAD_EASING|EASE_OUT),
		list(pixel_w + dx, pixel_z + dy, base, HV_VIS_HITSTOP_TIME, LINEAR_EASING),
		list(pixel_w, pixel_z, base, 2, SINE_EASING),
	))

/// Shakes the screens of players near `center` who can see it, unless they asked for less shake.
/proc/hv_vis_shake_viewers(atom/center, range, duration, strength)
	for(var/mob/viewer in viewers(range, center))
		if(!viewer.client || isobserver(viewer))
			continue
		if(viewer.client.prefs?.read_preference(/datum/preference/toggle/screen_shake_darken))
			continue
		shake_camera(viewer, duration, strength)

// ---- Held poses ----

/**
 * Ends held animations on a mob when something happens to it: it is moved, stands up, lies down,
 * is revived or dies. Removes itself when the hold runs out on its own. One per hold; a mob can
 * have several.
 */
/datum/component/hv_motion_hold
	dupe_mode = COMPONENT_DUPE_ALLOWED
	/// The named sequences it stops.
	var/list/tags
	/// HV_VIS_END_* flags: what ends the hold.
	var/end_flags = NONE

/datum/component/hv_motion_hold/Initialize(list/tags, end_flags, duration)
	if(!isliving(parent))
		return COMPONENT_INCOMPATIBLE
	src.tags = tags
	src.end_flags = end_flags
	if(duration > 0)
		addtimer(CALLBACK(src, PROC_REF(expire)), duration, TIMER_DELETE_ME)

/datum/component/hv_motion_hold/RegisterWithParent()
	if(end_flags & HV_VIS_END_MOVE)
		RegisterSignal(parent, COMSIG_MOVABLE_MOVED, PROC_REF(on_end))
	if(end_flags & (HV_VIS_END_STAND|HV_VIS_END_LIE))
		RegisterSignal(parent, COMSIG_LIVING_SET_BODY_POSITION, PROC_REF(on_body_position))
	if(end_flags & HV_VIS_END_REVIVE)
		RegisterSignal(parent, COMSIG_LIVING_REVIVE, PROC_REF(on_end))
	if(end_flags & HV_VIS_END_DEATH)
		RegisterSignal(parent, COMSIG_LIVING_DEATH, PROC_REF(on_end))

/datum/component/hv_motion_hold/UnregisterFromParent()
	UnregisterSignal(parent, list(COMSIG_MOVABLE_MOVED, COMSIG_LIVING_SET_BODY_POSITION, COMSIG_LIVING_REVIVE, COMSIG_LIVING_DEATH))

/datum/component/hv_motion_hold/Destroy(force)
	tags = null
	return ..()

/datum/component/hv_motion_hold/proc/on_end(datum/source)
	SIGNAL_HANDLER
	release()

/datum/component/hv_motion_hold/proc/on_body_position(datum/source, new_position, old_position)
	SIGNAL_HANDLER
	if(new_position == STANDING_UP && (end_flags & HV_VIS_END_STAND))
		release()
	else if(new_position == LYING_DOWN && (end_flags & HV_VIS_END_LIE))
		release()

/// Lets the held sequences go and leaves. Each eases back to where the body really is from wherever it
/// has got to: a corpse that slid a few pixels as it died, or curled up, does not jump back when it is
/// dragged off.
/datum/component/hv_motion_hold/proc/release()
	var/atom/holder = parent
	if(!QDELETED(holder))
		for(var/tag in tags)
			holder.hv_vis_release(tag, HV_VIS_POSE_RELEASE)
	qdel(src)

/// The hold ran its course: the sequences already ended themselves.
/datum/component/hv_motion_hold/proc/expire()
	qdel(src)

/// Holds this mob's named sequences until one of `end_flags` happens or `duration` passes.
/mob/living/proc/hv_vis_hold(list/tags, end_flags, duration)
	AddComponent(/datum/component/hv_motion_hold, tags, end_flags, duration)
