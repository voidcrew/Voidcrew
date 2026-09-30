/**
 * # Prison guards
 *
 * Owner: XA (extras-plan.md 4.1). NPC guards the wing's managers hire at the warden's console:
 * named people on the payroll who keep a peaceful routine, step in on spats, arguments, fights,
 * threats and hatch climbs, hold the staff doors in a riot, go down instead of dying and come
 * back free. Paid per minute while a member is home. Their routine and activities are in
 * outpost_prison_guard_routine.dm; numbers in voidcrew/_DEFINES/outpost_prison_guards.dm.
 *
 * Each hired guard is a record on the prison (name, rank, personality, when they are back). The
 * guard on the wing is a mob made from the record; when a guard goes down or is called away the
 * mob beams out and the record waits to send them back. A slot's wait belongs to the prison, so
 * dismissing a downed guard and hiring another does not skip it.
 *
 * Guards are security only: they never feed, clothe, treat, clean or light anything, so they
 * cannot raise pay. They never strike players, pets, bots or other NPCs, and they strike a
 * prisoner only for violence under way (fighting, rioting, swinging, climbing out, loose) with a
 * stun baton that does stamina damage and nothing else. The strike never goes through
 * melee_attack(), so no hit is put down to staff.
 *
 * The dispatcher (dispatch_guards()) runs every second from guards_tick() and only for guards whose
 * AI is running, which it is only while a player is on the level. Every response has a proc a test
 * can call with the guard in place: perform_response(), strike(), take_hold_position().
 */

/// Guard lines: context -> {"any": [...], "<guard personality>": [...]}; see outpost_prison_guards.json
#define OUTPOST_GUARD_DIALOGUE_FILE "outpost_prison_guards.json"

/// Placeholders a guard line may use; each is filled from the values the caller passes
GLOBAL_LIST_INIT(outpost_guard_placeholders, list("{boss}", "{count}", "{cause}", "{prisoner}", "{cell}", "{place}", "{other}"))

/// Whether `thing` is one of a prison's NPC guards; with `on_duty`, only one present, arrived and not down
/proc/is_outpost_prison_guard(atom/thing, on_duty = FALSE)
	var/mob/living/basic/outpost_prison_guard/guard = thing
	if(!istype(guard))
		return FALSE
	return !on_duty || guard.on_duty()

/// A top-level entry of the guards' dialogue file, or an empty list
/proc/outpost_guard_dialogue(key)
	return outpost_prisoner_extra_dialogue(OUTPOST_GUARD_DIALOGUE_FILE, key)

// ===== THE GUARD =====

/mob/living/basic/outpost_prison_guard
	name = "guard"
	desc = "A corrections officer on the prison wing's payroll."
	icon = 'icons/mob/simple/simple_human.dmi'
	unique_name = FALSE
	combat_mode = FALSE
	mob_biotypes = MOB_ORGANIC | MOB_HUMANOID
	// No sentience potions, no lazarus.
	sentience_type = SENTIENCE_HUMANOID
	maxHealth = OUTPOST_GUARD_HEALTH
	health = OUTPOST_GUARD_HEALTH
	speed = OUTPOST_GUARD_SPEED_WALK
	// Nobody drags or shoves them about.
	move_resist = MOVE_FORCE_VERY_STRONG
	density = TRUE
	basic_mob_flags = NONE
	mobility_flags = MOBILITY_FLAGS_REST_CAPABLE_DEFAULT
	rotate_on_lying = TRUE
	// No stuns or knockdowns: a guard is up or down (go_down()), nothing between.
	status_flags = NONE
	damage_coeff = list(BRUTE = 1, BURN = 1, TOX = 0, STAMINA = 0, OXY = 0)
	// A breach or a fire in the wing must not kill them.
	unsuitable_atmos_damage = 0
	unsuitable_cold_damage = 0
	unsuitable_heat_damage = 0
	response_help_continuous = "pats"
	response_help_simple = "pat"
	ai_controller = /datum/ai_controller/basic_controller/outpost_prison_guard

	/// The prison that hired them
	var/datum/outpost_prison/prison
	/// Who they are on the payroll: name, rank, personality, when they are back
	var/datum/outpost_guard_record/record
	/// OUTPOST_GUARD_ARRIVING, _PRESENT, _DOWN, _DISMISSED or _LEAVING
	var/phase = OUTPOST_GUARD_ARRIVING
	/// A guard personality from the dialogue file
	var/personality = "by_the_book"
	/// What the dispatcher has them doing about trouble, if anything
	var/datum/outpost_guard_response/response
	/// What they are doing on routine (outpost_prison_guard_routine.dm)
	var/datum/outpost_guard_activity/activity
	/// The type of the last routine activity, so they vary it
	var/last_activity_type
	/// Activity types they gave up on, until world.time
	var/list/activity_cooldowns
	/// Incident keys they could not get to -> world.time they may be sent again
	var/list/response_skips
	/// Whether the stun baton is out in their hand
	var/baton_out = FALSE
	/// The last thing they said, so they don't repeat it at once
	var/last_line
	/// Down: seconds until they are beamed out
	var/down_left = 0
	/// Dismissed: seconds left to walk to the office before they beam out wherever they are
	var/dismiss_left = 0
	/// Dismissed: where they walk to before beaming out
	var/turf/leave_spot
	/// Seconds counted outside the wing, for the leash
	var/outside_seconds = 0
	COOLDOWN_DECLARE(baton_cooldown)
	/// Between their own idle lines
	COOLDOWN_DECLARE(speech_cooldown)
	/// Between "Hey. Don't." lines
	COOLDOWN_DECLARE(warned_cooldown)

/mob/living/basic/outpost_prison_guard/Initialize(mapload)
	gender = pick(MALE, FEMALE)
	. = ..()
	AddElement(/datum/element/footstep, footstep_type = FOOTSTEP_MOB_SHOE)
	AddElement(/datum/element/relay_attackers)
	RegisterSignal(src, COMSIG_ATOM_WAS_ATTACKED, PROC_REF(on_attacked))
	// Nothing moves a guard but their own feet and the prison's beam.
	RegisterSignal(src, COMSIG_MOVABLE_TELEPORTING, PROC_REF(refuse_teleport))
	RegisterSignal(src, COMSIG_LIVING_PRE_WABBAJACKED, PROC_REF(refuse_polymorph))
	RegisterSignal(src, COMSIG_PRE_MOB_CHANGED_TYPE, PROC_REF(refuse_type_change))
	RegisterSignal(src, COMSIG_MOUSEDROP_ONTO, PROC_REF(block_being_dragged))
	RegisterSignal(src, COMSIG_ATOM_CAN_BE_PULLED, PROC_REF(refuse_pull))
	ADD_TRAIT(src, TRAIT_NO_CONTAINMENT, INNATE_TRAIT)
	ADD_TRAIT(src, TRAIT_NO_STORAGE_INSERT, INNATE_TRAIT)
	// Next tick: spawn_guard() calls join() right after new, which sets the record's gender and face.
	addtimer(CALLBACK(src, PROC_REF(guard_build_look)), 1)

/mob/living/basic/outpost_prison_guard/Destroy()
	end_response(cancel_ai = FALSE)
	end_activity(cancel_ai = FALSE)
	if(record?.guard == src)
		record.guard = null
		// Gone some other way than the prison's own beam (an admin delete): back later, like a downed guard.
		if(!record.dismissed && record.away_left <= 0)
			record.away_left = OUTPOST_GUARD_RETURN_TIME / (1 SECONDS)
	record = null
	prison?.guard_mobs -= src
	prison = null
	leave_spot = null
	return ..()

/// Dresses them as their own person in the guard's outfit (outpost_npc_looks.dm): the record's face and gender. Can sleep.
/mob/living/basic/outpost_prison_guard/proc/guard_build_look()
	set_outpost_npc_look(src, /datum/outfit/outpost_prison_guard, gender, record ? record.look_number : 1)
	if(QDELETED(src))
		return
	update_appearance(UPDATE_OVERLAYS)

/// Takes on the name, rank, gender and personality of the guard on the payroll
/mob/living/basic/outpost_prison_guard/proc/join(datum/outpost_prison/owner, datum/outpost_guard_record/hired)
	prison = owner
	record = hired
	hired.guard = src
	owner.guard_mobs |= src
	gender = hired.gender
	personality = hired.personality
	real_name = hired.full_name()
	name = real_name

/// On the wing and on duty: arrived, not down, not dismissed, and not paid by the kingpin to stand back (outpost_prison_boss_moves.dm)
/mob/living/basic/outpost_prison_guard/proc/on_duty()
	return !QDELETED(src) && phase == OUTPOST_GUARD_PRESENT && stat == CONSCIOUS && !boss_bribed()

/// Whether their AI is running, which it is only while someone is on the level to see them (see outpost_prison_ai_running())
/mob/living/basic/outpost_prison_guard/proc/ai_running()
	return outpost_prison_ai_running(src)

/mob/living/basic/outpost_prison_guard/update_overlays()
	. = ..()
	if(!baton_out || phase == OUTPOST_GUARD_DOWN)
		return
	// The lit baton in hand, the way a security officer holds one, turning with them
	var/mutable_appearance/baton = mutable_appearance('icons/mob/inhands/equipment/security_righthand.dmi', "stunbaton_active")
	baton.plane = FLOAT_PLANE
	baton.layer = FLOAT_LAYER
	. += baton

/// Draws or puts away the baton
/mob/living/basic/outpost_prison_guard/proc/set_baton(out)
	out = !!out
	if(baton_out == out)
		return
	baton_out = out
	update_appearance(UPDATE_OVERLAYS)

// ===== REFUSALS =====

/mob/living/basic/outpost_prison_guard/proc/refuse_teleport(datum/source, atom/destination, channel)
	SIGNAL_HANDLER
	if(isturf(loc))
		visible_message(span_notice("[src] flickers for a moment, but stays where [p_they()] [p_are()]."))
	return TRUE

/mob/living/basic/outpost_prison_guard/proc/refuse_polymorph(datum/source, what_to_randomize)
	SIGNAL_HANDLER
	visible_message(span_notice("[src] shimmers for a moment, then looks the same as before."))
	return STOP_WABBAJACK

/mob/living/basic/outpost_prison_guard/proc/refuse_type_change(datum/source)
	SIGNAL_HANDLER
	return COMPONENT_BLOCK_MOB_CHANGE

/mob/living/basic/outpost_prison_guard/proc/block_being_dragged(atom/over, mob/user)
	SIGNAL_HANDLER
	return COMPONENT_CANCEL_MOUSEDROP_ONTO

/mob/living/basic/outpost_prison_guard/proc/refuse_pull(datum/source, mob/living/puller)
	SIGNAL_HANDLER
	return COMSIG_ATOM_CANT_PULL

// ===== HURT AND DOWN =====

/**
 * Damage never takes a guard below OUTPOST_GUARD_DOWN_AT: at that point they go down instead,
 * and while down nothing hurts them (TRAIT_GODMODE). Forced damage is held to the same floor.
 */
/mob/living/basic/outpost_prison_guard/adjust_health(amount, updating_health = TRUE, forced = FALSE)
	var/floor_loss = maxHealth - OUTPOST_GUARD_DOWN_AT
	if(amount > 0)
		if(phase == OUTPOST_GUARD_DOWN || phase == OUTPOST_GUARD_LEAVING || bruteloss >= floor_loss)
			return 0
		amount = min(amount, floor_loss - bruteloss)
	. = ..()
	if(bruteloss >= floor_loss && prison)
		INVOKE_ASYNC(src, PROC_REF(go_down))

/// Guards never die: whatever would kill one puts them down instead
/mob/living/basic/outpost_prison_guard/death(gibbed)
	if(!gibbed && prison && phase != OUTPOST_GUARD_LEAVING)
		go_down()
		return
	return ..()

/**
 * Down: lying there, nothing more can hurt them, and OUTPOST_GUARD_RECALL_DELAY later they are
 * beamed out, to come back free OUTPOST_GUARD_RETURN_TIME after that (guards_tick()).
 */
/mob/living/basic/outpost_prison_guard/proc/go_down()
	if(QDELETED(src) || phase == OUTPOST_GUARD_DOWN || phase == OUTPOST_GUARD_LEAVING)
		return FALSE
	var/was_leaving = phase == OUTPOST_GUARD_DISMISSED
	phase = OUTPOST_GUARD_DOWN
	end_response()
	end_activity()
	set_baton(FALSE)
	ADD_TRAIT(src, TRAIT_GODMODE, OUTPOST_GUARD_DOWN_TRAIT)
	add_traits(list(TRAIT_FLOORED, TRAIT_IMMOBILIZED, TRAIT_INCAPACITATED), OUTPOST_GUARD_DOWN_TRAIT)
	down_left = was_leaving ? 0 : OUTPOST_GUARD_RECALL_DELAY / (1 SECONDS)
	visible_message(span_danger("[src] goes down!"))
	say_guard("downed")
	prison?.add_log("[real_name] went down.")
	return TRUE

/// Someone took a swing at them. Prisoners are the dispatcher's business; anyone else gets a warning and some room.
/mob/living/basic/outpost_prison_guard/proc/on_attacked(datum/source, atom/attacker, attack_flags)
	SIGNAL_HANDLER
	if(!(attack_flags & (ATTACKER_DAMAGING_ATTACK | ATTACKER_STAMINA_ATTACK | ATTACKER_SHOVING)))
		return
	if(is_outpost_prisoner(attacker) || !on_duty())
		return
	INVOKE_ASYNC(src, PROC_REF(warn_off), attacker)

/// "Hey. Don't." and a step back. Guards never strike players.
/mob/living/basic/outpost_prison_guard/proc/warn_off(atom/attacker)
	if(!on_duty() || QDELETED(attacker))
		return FALSE
	if(!COOLDOWN_FINISHED(src, warned_cooldown))
		return FALSE
	COOLDOWN_START(src, warned_cooldown, 5 SECONDS)
	face_atom(attacker)
	say_guard("attacked_by_player")
	step_away(src, attacker)
	if(ismob(attacker))
		log_combat(attacker, src, "attacked a prison guard")
	return TRUE

/// Healing slowly while nothing is going on
/mob/living/basic/outpost_prison_guard/proc/heal_tick(seconds)
	if(phase != OUTPOST_GUARD_PRESENT || bruteloss <= 0 || prison?.riot_active)
		return
	adjust_health(-OUTPOST_GUARD_HEAL_PER_MINUTE * seconds / 60)

// ===== BEAMING IN AND OUT =====

/**
 * Materialises them where they stand, like a prisoner: they knit together inside the column over
 * the whole beam. They stay OUTPOST_GUARD_ARRIVING (held still, no routine, no responses, no
 * speech) until finish_beam_in() as the beam ends.
 */
/mob/living/basic/outpost_prison_guard/proc/beam_in()
	phase = OUTPOST_GUARD_ARRIVING
	ADD_TRAIT(src, TRAIT_IMMOBILIZED, OUTPOST_GUARD_BEAM_TRAIT)
	var/turf/spot = get_turf(src)
	if(spot)
		playsound(spot, 'sound/effects/magic/teleport_diss.ogg', 40, TRUE)
		new /obj/effect/temp_visual/transporter_beam(spot, OUTPOST_PRISON_BEAM_TIME + 0.5 SECONDS)
	// Hidden under the mask from the first frame; finish_beam_in() takes the effects off.
	transporter_materialise(src, 255, OUTPOST_PRISON_BEAM_TIME, restore = FALSE)
	addtimer(CALLBACK(src, PROC_REF(finish_beam_in)), OUTPOST_PRISON_BEAM_TIME)

/// Fully there as the beam ends: the flash, and only now are they on duty, and say so
/mob/living/basic/outpost_prison_guard/proc/finish_beam_in()
	if(phase != OUTPOST_GUARD_ARRIVING)
		return FALSE
	var/turf/spot = get_turf(src)
	if(spot)
		new /obj/effect/temp_visual/transporter_flash(spot)
		transporter_sparks(spot)
		playsound(spot, 'sound/effects/magic/teleport_app.ogg', 50, TRUE)
	// Whatever is left of the knit, gone: they are solid from here on.
	transporter_restore(src, 255)
	phase = OUTPOST_GUARD_PRESENT
	REMOVE_TRAIT(src, TRAIT_IMMOBILIZED, OUTPOST_GUARD_BEAM_TRAIT)
	if(say_guard("arrival"))
		prison?.note_speech()
	return TRUE

/**
 * Dematerialises them and deletes them at the end of the beam. Their record, if they are still on
 * the payroll, sends them back after `away_seconds` (guards_tick()).
 */
/mob/living/basic/outpost_prison_guard/proc/beam_out(away_seconds = 0)
	if(phase == OUTPOST_GUARD_LEAVING)
		return FALSE
	phase = OUTPOST_GUARD_LEAVING
	end_response()
	end_activity()
	set_baton(FALSE)
	if(record?.guard == src)
		record.guard = null
		if(!record.dismissed)
			record.away_left = max(record.away_left, away_seconds)
	ADD_TRAIT(src, TRAIT_IMMOBILIZED, OUTPOST_GUARD_BEAM_TRAIT)
	var/turf/spot = get_turf(src)
	if(spot)
		playsound(spot, 'sound/effects/magic/teleport_diss.ogg', 40, TRUE)
		new /obj/effect/temp_visual/transporter_beam(spot, OUTPOST_PRISON_BEAM_TIME + 0.5 SECONDS)
	new /obj/effect/abstract/particle_holder(src, /particles/transporter_motes, PARTICLE_ATTACH_MOB)
	transporter_dematerialise(src, OUTPOST_PRISON_BEAM_TIME)
	addtimer(CALLBACK(src, PROC_REF(finish_beam_out)), OUTPOST_PRISON_BEAM_TIME)
	return TRUE

/mob/living/basic/outpost_prison_guard/proc/finish_beam_out()
	var/turf/spot = get_turf(src)
	if(spot)
		new /obj/effect/temp_visual/transporter_flash/departure(spot)
		transporter_sparks(spot)
		playsound(spot, 'sound/effects/magic/teleport_app.ogg', 50, TRUE)
	qdel(src)

/// Called back from somewhere they should not be (off the wing's level, or out of the wing with nobody about)
/mob/living/basic/outpost_prison_guard/proc/recall(away_seconds = OUTPOST_GUARD_OFF_LEVEL_AWAY)
	if(phase != OUTPOST_GUARD_PRESENT)
		return FALSE
	say_guard("recalled")
	prison?.add_log("[real_name] was called back to the wing.")
	return beam_out(away_seconds)

/**
 * Off the payroll: they say `context`, walk back to the office and beam out there, or wherever
 * they are after OUTPOST_GUARD_DISMISS_WALK seconds. Down or arriving, they beam out at once.
 */
/mob/living/basic/outpost_prison_guard/proc/leave(context = "dismissed")
	if(phase == OUTPOST_GUARD_LEAVING || phase == OUTPOST_GUARD_DISMISSED)
		return FALSE
	if(phase != OUTPOST_GUARD_PRESENT || stat != CONSCIOUS)
		return beam_out()
	phase = OUTPOST_GUARD_DISMISSED
	end_response()
	end_activity()
	set_baton(FALSE)
	set_varspeed(OUTPOST_GUARD_SPEED_WALK)
	say_guard(context)
	dismiss_left = OUTPOST_GUARD_DISMISS_WALK
	leave_spot = prison?.guard_office_spot(src)
	return TRUE

// ===== SPEECH =====

/// A line for `context` in their personality (or anyone's), with `values` filled in, or null
/mob/living/basic/outpost_prison_guard/proc/pick_guard_line(context, list/values)
	var/list/guard_lines = outpost_guard_dialogue("guard_lines")
	var/list/by_personality = guard_lines[context]
	if(!islist(by_personality))
		return null
	var/list/own = by_personality[personality]
	var/list/shared = by_personality["any"]
	var/list/first_pool = (length(own) && prob(60)) ? own : shared
	var/list/usable = usable_guard_lines(first_pool, values)
	if(!length(usable))
		usable = usable_guard_lines(first_pool == own ? shared : own, values)
	if(!length(usable))
		return null
	var/line = pick(usable)
	for(var/placeholder in values)
		line = replacetext(line, placeholder, "[values[placeholder]]")
	return line

/// The lines of `pool` that are not the last thing they said and need no placeholder `values` lacks
/mob/living/basic/outpost_prison_guard/proc/usable_guard_lines(list/pool, list/values)
	var/list/usable = list()
	for(var/line in pool)
		if(!istext(line) || line == last_line)
			continue
		var/missing = FALSE
		for(var/placeholder in GLOB.outpost_guard_placeholders)
			if(findtext(line, placeholder) && isnull(LAZYACCESS(values, placeholder)))
				missing = TRUE
				break
		if(!missing)
			usable += line
	return usable

/// Says a line for `context`. Returns TRUE if they said something. Never while beaming in or out, invisible or half there.
/mob/living/basic/outpost_prison_guard/proc/say_guard(context, list/values)
	if(QDELETED(src) || stat == DEAD || phase == OUTPOST_GUARD_ARRIVING || phase == OUTPOST_GUARD_LEAVING)
		return FALSE
	var/line = pick_guard_line(context, values)
	if(!line)
		return FALSE
	last_line = line
	say(line)
	return TRUE

/// An idle line: waits for the wing to be quiet and for their own pause, and counts toward the wing's
/mob/living/basic/outpost_prison_guard/proc/idle_say(context, list/values)
	if(!prison?.wing_can_speak() || !COOLDOWN_FINISHED(src, speech_cooldown))
		return FALSE
	if(!say_guard(context, values))
		return FALSE
	COOLDOWN_START(src, speech_cooldown, rand(OUTPOST_GUARD_SPEECH_GAP_MIN, OUTPOST_GUARD_SPEECH_GAP_MAX) SECONDS)
	prison.note_speech()
	return TRUE

// ===== THE BATON =====

/**
 * Whether they may strike this prisoner now: one of their own wing's, beside them, on their feet,
 * and making violent trouble right now (rioting, breaking out, fighting with blows, swinging at
 * someone or having just struck someone, climbing out, or loose). Never a calm or downed prisoner.
 */
/mob/living/basic/outpost_prison_guard/proc/may_strike(mob/living/basic/outpost_prisoner/prisoner)
	if(!on_duty() || !is_outpost_prisoner(prisoner) || QDELETED(prisoner) || !prison || prisoner.prison != prison)
		return FALSE
	if(prisoner.stat != CONSCIOUS || prisoner.phase != PRISONER_PRESENT || prisoner.can_be_dragged() || !Adjacent(prisoner))
		return FALSE
	// A rioter who gave up at a turret's warning is on their way back to their cell (outpost_prison_security.dm)
	if((prisoner.is_rioting() && !prisoner.surrendered_to_turret()) || prisoner.trouble == PRISONER_TROUBLE_LOOSE || prisoner.climb_ref || prisoner.swing_ref)
		return TRUE
	if(prisoner.trouble == PRISONER_TROUBLE_FIGHT && prisoner.fight?.fighting)
		return TRUE
	return prisoner.guard_struck_recently()

/**
 * One stun baton strike: OUTPOST_GUARD_BATON_STAMINA stamina, their blows stop, and every prisoner
 * who sees it loses a little mood. Not an attack in tg's sense (no relay_attackers, no
 * hit_by_staff()), so it is never held against staff and never hurts. Returns TRUE if it landed.
 */
/mob/living/basic/outpost_prison_guard/proc/strike(mob/living/basic/outpost_prisoner/prisoner)
	if(!COOLDOWN_FINISHED(src, baton_cooldown) || !may_strike(prisoner))
		return FALSE
	COOLDOWN_START(src, baton_cooldown, OUTPOST_GUARD_BATON_COOLDOWN)
	set_baton(TRUE)
	face_atom(prisoner)
	do_attack_animation(prisoner)
	playsound(prisoner, 'sound/items/weapons/egloves.ogg', 50, TRUE)
	prisoner.visible_message(span_danger("[src] strikes [prisoner] with a stun baton!"), span_userdanger("[src] strikes you with a stun baton!"))
	prisoner.apply_damage(OUTPOST_GUARD_BATON_STAMINA, STAMINA)
	prisoner.stop_blows()
	prison.guard_strike_seen(prisoner, src)
	return TRUE

/// Strikes a rioter beside them. Returns TRUE if they struck.
/mob/living/basic/outpost_prison_guard/proc/strike_adjacent_rioter()
	if(!COOLDOWN_FINISHED(src, baton_cooldown))
		return FALSE
	for(var/mob/living/basic/outpost_prisoner/rioter in orange(1, src))
		if(rioter.is_rioting() && strike(rioter))
			return TRUE
	return FALSE

// ===== RESPONSES =====

/// Sends them to deal with something, dropping their routine
/mob/living/basic/outpost_prison_guard/proc/give_response(kind, priority, key, atom/target, turf/spot)
	end_response(cancel_ai = FALSE)
	end_activity(cancel_ai = FALSE)
	response = new(kind, key, priority, target, spot)
	response.expires_at = world.time + OUTPOST_GUARD_RESPONSE_TIMEOUT
	set_varspeed(OUTPOST_GUARD_SPEED_HURRY)
	set_baton(TRUE)
	ai_controller?.CancelActions()
	return response

/// Back to routine
/mob/living/basic/outpost_prison_guard/proc/end_response(cancel_ai = TRUE)
	if(!response)
		return
	QDEL_NULL(response)
	if(!QDELETED(src))
		set_varspeed(OUTPOST_GUARD_SPEED_WALK)
		set_baton(FALSE)
	if(cancel_ai)
		ai_controller?.CancelActions()

/// Whether they gave up on an incident recently
/mob/living/basic/outpost_prison_guard/proc/skipping(key)
	return LAZYACCESS(response_skips, key) > world.time

/**
 * Deals with their response for a second: works out where they need to be (response.goal, which
 * the AI walks them to) and, once there, acts. Called by the dispatcher every second. Returns
 * TRUE while the response goes on.
 */
/mob/living/basic/outpost_prison_guard/proc/perform_response()
	var/datum/outpost_guard_response/job = response
	if(!job)
		return FALSE
	if(!on_duty() || !prison)
		end_response()
		return FALSE
	var/done = FALSE
	switch(job.kind)
		if("fight")
			done = fight_response(job)
		if("threat")
			done = threat_response(job)
		if("climb")
			done = climb_response(job)
		if("riot")
			done = riot_response(job)
		if("shelter")
			done = shelter_response(job)
		if("leash")
			done = leash_response(job)
		else
			done = TRUE
	if(done)
		end_response()
		return FALSE
	if(!job.reached && world.time > job.expires_at)
		// Could not get there: back to routine, and someone else may try.
		LAZYSET(response_skips, job.key, world.time + OUTPOST_GUARD_RESPONSE_TIMEOUT)
		end_response()
		return FALSE
	return TRUE

/// Whether they stand where a response wants them: beside a mob, or on a tile
/mob/living/basic/outpost_prison_guard/proc/at_goal(atom/goal)
	if(!goal)
		return TRUE
	if(isturf(goal))
		return loc == goal
	return Adjacent(goal)

/**
 * An argument or a fight. Beside the fighters: while it is still an argument, one try at talking
 * it down (the prison's guard_talkdown_chance); once blows fly, "Break it up!", then the baton on
 * the first fighter every OUTPOST_GUARD_BATON_COOLDOWN until the fight is over.
 */
/mob/living/basic/outpost_prison_guard/proc/fight_response(datum/outpost_guard_response/job)
	var/mob/living/basic/outpost_prisoner/fighter = job.target()
	var/datum/outpost_prison_fight/brawl = fighter?.fight
	if(QDELETED(brawl))
		return TRUE
	var/mob/living/basic/outpost_prisoner/other = brawl.opponent_of(fighter)
	var/mob/living/basic/outpost_prisoner/beside = Adjacent(fighter) ? fighter : ((other && Adjacent(other)) ? other : null)
	if(!beside)
		job.set_goal(fighter)
		return FALSE
	job.set_goal(null)
	job.reached = TRUE
	face_atom(beside)
	if(!brawl.fighting)
		if(job.talked)
			return FALSE
		job.talked = TRUE
		say_guard("argue_stop")
		if(!prob(prison.guard_talkdown_chance))
			// Not listening: it goes on, and the baton waits for the first blow.
			return FALSE
		prison.end_fight(brawl)
		fighter.say_context("fight_talked_down", other)
		prison.add_log("[real_name] talked down a fight between [fighter.real_name] and [other?.real_name].")
		return TRUE
	if(!job.said)
		job.said = TRUE
		say_guard("fight_stop")
		return FALSE
	if(!strike(fighter) && other)
		strike(other)
	return FALSE

/**
 * A prisoner squaring up to someone. Beside them: "Back off", and the threat is over. One who has
 * decided to swing, or struck someone in the last OUTPOST_GUARD_STRUCK_RECENT, gets the baton
 * after the warning instead, until they stop.
 */
/mob/living/basic/outpost_prison_guard/proc/threat_response(datum/outpost_guard_response/job)
	var/mob/living/basic/outpost_prisoner/prisoner = job.target()
	if(!prisoner || prisoner.stat != CONSCIOUS || prisoner.phase != PRISONER_PRESENT || prisoner.can_be_dragged() || prisoner.trouble)
		return TRUE
	var/violent = prisoner.swing_ref || prisoner.guard_struck_recently()
	if(!violent && !prisoner.threat_ref)
		return TRUE
	if(!Adjacent(prisoner))
		job.set_goal(prisoner)
		return FALSE
	job.set_goal(null)
	job.reached = TRUE
	face_atom(prisoner)
	if(!job.said)
		job.said = TRUE
		say_guard("threat_stop")
		if(!violent)
			prisoner.cancel_threat()
			return TRUE
		return FALSE
	if(!violent)
		prisoner.cancel_threat()
		return TRUE
	strike(prisoner)
	return FALSE

/// A prisoner climbing over a serving hatch: to the hatch's office side, "Get down off that!", and down they slide
/mob/living/basic/outpost_prison_guard/proc/climb_response(datum/outpost_guard_response/job)
	var/mob/living/basic/outpost_prisoner/climber = job.target()
	var/obj/structure/table/reinforced/prison_hatch/hatch = climber?.climb_ref?.resolve()
	if(!hatch)
		return TRUE
	var/turf/stand = job.spot || hatch.staff_side_turf()
	if(!stand)
		return TRUE
	// Any office tile beside the counter will do; the one past it is where they head for.
	if(loc != stand && !(get_dist(src, hatch) <= 1 && prison.staff_ground?[loc]))
		job.set_goal(stand)
		return FALSE
	job.set_goal(null)
	job.reached = TRUE
	face_atom(hatch)
	say_guard("climb_stop")
	climber.stop_climb(fell = TRUE)
	return TRUE

/**
 * A riot. Below OUTPOST_GUARD_FALLBACK_BELOW health they fall back to the far corner of the
 * office. While a member of the wing is in the cell block, they stay within
 * OUTPOST_GUARD_FOLLOW_RANGE of them and go for any rioter at them. Otherwise they hold the staff
 * door from the office. They baton any rioter beside them whatever they are doing.
 */
/mob/living/basic/outpost_prison_guard/proc/riot_response(datum/outpost_guard_response/job)
	if(!prison.riot_active)
		return TRUE
	job.reached = TRUE
	if(health < OUTPOST_GUARD_FALLBACK_BELOW)
		if(job.mode != "fallback")
			job.mode = "fallback"
			job.spot = prison.guard_fallback_spot(src)
			say_guard("fallback")
		job.set_goal((job.spot && loc != job.spot) ? job.spot : null)
		strike_adjacent_rioter()
		return FALSE
	var/mob/living/member = prison.guard_member_in_cell_block()
	if(member)
		if(job.mode != "follow")
			job.mode = "follow"
			job.spot = null
			say_guard("follow_member", list("{boss}" = prison.guard_boss_name(member)))
		var/mob/living/basic/outpost_prisoner/attacker = prison.rioter_beside(member)
		if(attacker && !Adjacent(attacker))
			job.set_goal(attacker)
		else if(get_dist(src, member) > OUTPOST_GUARD_FOLLOW_RANGE)
			job.set_goal(member)
		else
			job.set_goal(null)
		strike_adjacent_rioter()
		return FALSE
	if(job.mode != "hold")
		job.mode = "hold"
		job.spot = null
		take_hold_position()
		prison.announce_riot_hold(src)
	if(!job.spot)
		take_hold_position()
	job.set_goal((job.spot && loc != job.spot) ? job.spot : null)
	strike_adjacent_rioter()
	return FALSE

/**
 * Picks where they hold the staff door in a riot: a free office tile beside a staff door into the
 * cell block that the other guard is not holding, the tiles to its sides first so the doorway
 * itself stays clear for the crew. Sets it as their response's spot. Returns it, or null.
 */
/mob/living/basic/outpost_prison_guard/proc/take_hold_position()
	if(!prison)
		return null
	for(var/turf/spot as anything in prison.guard_hold_spots())
		if(prison.guard_spot_taken(spot, src))
			continue
		response?.spot = spot
		return spot
	return null

/**
 * A creature is out (creature_out(), outpost_prison_panic.dm): into the office and stay there until
 * it is dead, taken or shut in. They never strike the creatures. The rest of an experiment (the dose,
 * the incubation, the slug in the vents) is no reason to leave the yard to itself.
 */
/mob/living/basic/outpost_prison_guard/proc/shelter_response(datum/outpost_guard_response/job)
	if(!prison.creature_out())
		return TRUE
	job.reached = TRUE
	if(!job.spot)
		job.spot = prison.guard_office_spot(src)
	job.set_goal((job.spot && loc != job.spot) ? job.spot : null)
	return FALSE

/// Wandered out of the wing: back to the office
/mob/living/basic/outpost_prison_guard/proc/leash_response(datum/outpost_guard_response/job)
	if(get_area(src) == prison.wing)
		outside_seconds = 0
		return TRUE
	if(!job.spot)
		job.spot = prison.guard_office_spot(src)
	if(!job.spot)
		return TRUE
	job.set_goal(loc != job.spot ? job.spot : null)
	return FALSE

// ===== THE PRISONER'S SIDE =====

/mob/living/basic/outpost_prisoner
	/// world.time a guard last checked on them, or they last said hello to a guard
	var/guard_noticed_at = 0
	/// world.time they last lost mood seeing a guard's baton
	var/guard_onlooker_at = 0

/// Whether they struck someone (not another prisoner) in the last OUTPOST_GUARD_STRUCK_RECENT
/mob/living/basic/outpost_prisoner/proc/guard_struck_recently()
	return struck_at && world.time - struck_at <= OUTPOST_GUARD_STRUCK_RECENT && !isnull(struck_ref?.resolve())

// ===== THE PAYROLL =====

/// One guard on the payroll: who they are, and when they are back if they are away
/datum/outpost_guard_record
	var/datum/outpost_prison/prison
	/// The guard on the wing now, if any
	var/mob/living/basic/outpost_prison_guard/guard
	/// "Officer" or "Sergeant"
	var/rank = "Officer"
	var/surname = "Hale"
	var/gender = MALE
	var/personality = "by_the_book"
	/// Which face they have (set_outpost_npc_look())
	var/look_number = 1
	/// An admin's guard: no fee, no wage, not counted against guard_max()
	var/free = FALSE
	var/dismissed = FALSE
	/// Seconds until they are sent back while away (down, recalled); they come only while a member is home
	var/away_left = 0
	/// What the guard is made as (tests use a subtype)
	var/guard_type = /mob/living/basic/outpost_prison_guard

/datum/outpost_guard_record/New(datum/outpost_prison/owner, rank, free = FALSE, guard_type)
	. = ..()
	prison = owner
	src.rank = rank
	src.free = free
	if(ispath(guard_type, /mob/living/basic/outpost_prison_guard))
		src.guard_type = guard_type
	gender = pick(MALE, FEMALE)
	if(length(GLOB.last_names))
		surname = pick(GLOB.last_names)
	var/list/personalities = outpost_guard_dialogue("guard_personalities")
	if(length(personalities))
		personality = pick(personalities)
	look_number = random_outpost_npc_look_number()

/datum/outpost_guard_record/Destroy()
	if(guard?.record == src)
		guard.record = null
	guard = null
	prison = null
	return ..()

/// "Officer Hale"
/datum/outpost_guard_record/proc/full_name()
	return "[rank] [surname]"

/// Seconds before this slot could have a guard on the wing again: the down time and the return, or the time still away
/datum/outpost_guard_record/proc/pending_wait()
	if(guard)
		return guard.phase == OUTPOST_GUARD_DOWN ? guard.down_left + OUTPOST_GUARD_RETURN_TIME / (1 SECONDS) : 0
	return max(0, away_left)

/// What the console calls them: arriving, post, rounds, routine, responding, riot, down or away
/datum/outpost_guard_record/proc/status()
	if(!guard || guard.phase == OUTPOST_GUARD_LEAVING || guard.phase == OUTPOST_GUARD_DISMISSED)
		return "away"
	switch(guard.phase)
		if(OUTPOST_GUARD_ARRIVING)
			return "arriving"
		if(OUTPOST_GUARD_DOWN)
			return "down"
	if(guard.response)
		return guard.response.kind == "riot" ? "riot" : "responding"
	return guard.activity?.status || "routine"

/// Seconds until a down or away guard is back, or null
/datum/outpost_guard_record/proc/back_in()
	var/wait = pending_wait()
	return wait > 0 ? round(wait) : null

// ===== THE PRISON =====

/datum/outpost_prison
	/// Every guard on the payroll
	var/list/datum/outpost_guard_record/guard_records = list()
	/// Every guard mob of this prison, on the wing or leaving it
	var/list/mob/living/basic/outpost_prison_guard/guard_mobs = list()
	/// Seconds each slot still waits for a dismissed guard's return, passed on to the next hire
	var/list/guard_slot_waits = list()
	/// Wages earned and not yet charged, in credits, and the seconds into the charging interval
	var/guard_wage_owed = 0
	var/guard_wage_clock = 0
	/// Wages skipped in a row because the treasury could not cover them
	var/guard_unpaid = 0
	/// Seconds since the last greeting, leash and chatter check
	var/guard_check_clock = 0
	/// Seconds to the next rounds of the cell block, or null before the first guard arrives
	var/guard_rounds_left
	/// Percent chance a guard talks down an argument; tests set it
	var/guard_talkdown_chance = OUTPOST_GUARD_TALKDOWN_CHANCE
	/// Member key -> world.time a guard last greeted them, and last reported to them
	var/list/guard_greeted = list()
	var/list/guard_reported = list()
	/// REF() of loose prisoners a guard has called out
	var/list/guard_loose_called = list()
	/// Whether the guards' riot hold was called out this riot, and their creature line while a creature is out
	var/guard_riot_announced = FALSE
	var/guard_shelter_called = FALSE

/// Guards the wing may hire: OUTPOST_GUARD_MAX, and one more for each cell block extension
/datum/outpost_prison/proc/guard_max()
	return OUTPOST_GUARD_MAX + extension_count()

/// Guards on the payroll who are not an admin's: the ones guard_max() counts
/datum/outpost_prison/proc/hired_guard_count()
	var/count = 0
	for(var/datum/outpost_guard_record/record as anything in guard_records)
		if(!record.free && !record.dismissed)
			count++
	return count

/// Guards drawing a wage right now: hired (not an admin's) and on the wing
/datum/outpost_prison/proc/guard_payroll()
	var/count = 0
	for(var/datum/outpost_guard_record/record as anything in guard_records)
		if(record.free || record.dismissed || QDELETED(record.guard))
			continue
		if(record.guard.phase == OUTPOST_GUARD_ARRIVING || record.guard.phase == OUTPOST_GUARD_PRESENT)
			count++
	return count

/// "Officer" for the first on the payroll, "Sergeant" for the next
/datum/outpost_prison/proc/next_guard_rank()
	for(var/datum/outpost_guard_record/record as anything in guard_records)
		if(record.rank == "Officer")
			return "Sergeant"
	return "Officer"

/**
 * Hires a guard for `user`: managers only, a free post, and OUTPOST_GUARD_HIRE_COST in the
 * treasury, charged before anyone beams in. Never debt. Returns null when hired, else why not.
 */
/datum/outpost_prison/proc/hire_guard(mob/user)
	if(QDELETED(outpost) || !outpost.can_manage(user))
		return "managers only"
	if(hired_guard_count() >= guard_max())
		return "no free post"
	// Nowhere in the office to beam into: refused before anything is charged.
	if(!guard_office_spot())
		return "no room in the office"
	outpost.ensure_home_services()
	var/datum/bank_account/treasury = outpost.treasury
	if(!treasury || treasury.account_balance < OUTPOST_GUARD_HIRE_COST || !treasury.adjust_money(-OUTPOST_GUARD_HIRE_COST, "Prison guard hired"))
		return "treasury short"
	var/datum/outpost_guard_record/hired = add_guard_record()
	add_log("[hired.full_name()] was hired for [OUTPOST_GUARD_HIRE_COST] cr.")
	log_game("PLAYER OUTPOST PRISON: [key_name(user)] hired [hired.full_name()] at '[outpost?.name]' for [OUTPOST_GUARD_HIRE_COST] cr")
	return null

/**
 * A new guard on the payroll, beamed into the office at once unless their slot is still waiting
 * out a dismissed guard's return. `free` is an admin's guard. Returns the record.
 */
/datum/outpost_prison/proc/add_guard_record(free = FALSE, guard_type)
	var/datum/outpost_guard_record/record = new(src, next_guard_rank(), free, guard_type)
	guard_records += record
	if(!free && length(guard_slot_waits))
		record.away_left = guard_slot_waits[1]
		guard_slot_waits.Cut(1, 2)
	if(record.away_left <= 0)
		spawn_guard(record)
	return record

/// Beams a record's guard into the office. Returns the guard, or null if there is nowhere to stand.
/datum/outpost_prison/proc/spawn_guard(datum/outpost_guard_record/record)
	if(!record || record.dismissed || record.guard)
		return null
	var/turf/spot = guard_office_spot()
	if(!spot)
		return null
	var/mob/living/basic/outpost_prison_guard/guard = new record.guard_type(spot)
	guard.join(src, record)
	record.away_left = 0
	guard.beam_in()
	if(isnull(guard_rounds_left))
		guard_rounds_left = rand(OUTPOST_GUARD_ROUNDS_GAP_MIN, OUTPOST_GUARD_ROUNDS_GAP_MAX) / (1 SECONDS)
	return guard

/**
 * Takes a guard off the payroll, no refund: they say `context` and walk out. A slot still waiting
 * for them to come back keeps that wait for the next hire. `forget_wait` (abandonment, an admin)
 * drops it.
 */
/datum/outpost_prison/proc/dismiss_guard(datum/outpost_guard_record/record, context = "dismissed", forget_wait = FALSE)
	if(!record || record.dismissed)
		return FALSE
	var/wait = record.pending_wait()
	if(wait > 0 && !record.free && !forget_wait)
		guard_slot_waits += wait
	record.dismissed = TRUE
	guard_records -= record
	var/mob/living/basic/outpost_prison_guard/guard = record.guard
	record.guard = null
	if(guard)
		guard.record = null
		guard.leave(context)
	qdel(record)
	return TRUE

// ===== TIME =====

/**
 * Advances the guards by `seconds`: wages (charged every OUTPOST_PRISON_DEPOSIT_INTERVAL), returns,
 * the downed and the dismissed, healing, the rounds clock, and every
 * OUTPOST_GUARD_CHECK_SECONDS the leash, greetings and reports, and the yard saying hello; then the
 * response dispatcher.
 */
/datum/outpost_prison/proc/guards_tick(seconds)
	if(!length(guard_records) && !length(guard_mobs) && !length(guard_slot_waits))
		guard_wage_clock = 0
		guard_wage_owed = 0
		return
	guard_wages_tick(seconds)
	for(var/i in length(guard_slot_waits) to 1 step -1)
		guard_slot_waits[i] -= seconds
		if(guard_slot_waits[i] <= 0)
			guard_slot_waits.Cut(i, i + 1)
	// Returns before the downed beam out, so a wait starts counting on the next tick
	var/home = crew_home()
	for(var/datum/outpost_guard_record/record as anything in guard_records.Copy())
		if(record.guard)
			continue
		record.away_left = max(0, record.away_left - seconds)
		if(record.away_left <= 0 && home)
			spawn_guard(record)
	for(var/mob/living/basic/outpost_prison_guard/guard in guard_mobs.Copy())
		if(QDELETED(guard))
			continue
		switch(guard.phase)
			if(OUTPOST_GUARD_DOWN)
				guard.down_left -= seconds
				if(guard.down_left <= 0)
					guard.beam_out(OUTPOST_GUARD_RETURN_TIME / (1 SECONDS))
			if(OUTPOST_GUARD_DISMISSED)
				guard.dismiss_left -= seconds
				if(guard.dismiss_left <= 0 || (guard.leave_spot && guard.loc == guard.leave_spot) || !guard.ai_running())
					guard.beam_out()
			if(OUTPOST_GUARD_PRESENT)
				guard.heal_tick(seconds)
	guard_rounds_tick(seconds)
	guard_check_clock += seconds
	if(guard_check_clock >= OUTPOST_GUARD_CHECK_SECONDS)
		guard_check_clock = 0
		guard_leash_check()
		guard_greet_check()
		guard_yard_chatter()
	dispatch_guards()

/**
 * Wages: OUTPOST_GUARD_WAGE a minute for each hired guard on the wing, only while a member is
 * home, charged every OUTPOST_PRISON_DEPOSIT_INTERVAL.
 */
/datum/outpost_prison/proc/guard_wages_tick(seconds)
	if(crew_home())
		guard_wage_owed += OUTPOST_GUARD_WAGE * guard_payroll() * seconds / 60
	guard_wage_clock += seconds
	while(guard_wage_clock >= OUTPOST_PRISON_DEPOSIT_INTERVAL)
		guard_wage_clock -= OUTPOST_PRISON_DEPOSIT_INTERVAL
		pay_guard_wages()

/**
 * Charges the whole credits owed in wages. One the treasury cannot cover is skipped, never debt
 * (debt would shut intake over wages); OUTPOST_GUARD_UNPAID_LEAVE skipped in a row and the hired
 * guards walk off. Returns what was charged.
 */
/datum/outpost_prison/proc/pay_guard_wages()
	var/whole = round(guard_wage_owed + 0.001)
	if(whole < 1 || QDELETED(outpost))
		return 0
	outpost.ensure_home_services()
	var/datum/bank_account/treasury = outpost.treasury
	if(treasury && treasury.account_balance >= whole && treasury.adjust_money(-whole, "Prison guard wages"))
		guard_wage_owed = max(0, guard_wage_owed - whole)
		guard_unpaid = 0
		return whole
	guard_wage_owed = 0
	guard_unpaid++
	add_log("The treasury could not cover the guards' wages ([whole] cr).")
	if(guard_unpaid >= OUTPOST_GUARD_UNPAID_LEAVE)
		guards_quit_unpaid()
	else
		announce("Prison wing: the treasury could not cover the guards' wages ([whole] cr).", SHIP_NOTIFY_WARNING)
	return 0

/// Not paid again: every hired guard says so and leaves, no refund
/datum/outpost_prison/proc/guards_quit_unpaid()
	guard_unpaid = 0
	var/quit = 0
	for(var/datum/outpost_guard_record/record as anything in guard_records.Copy())
		if(record.free)
			continue
		dismiss_guard(record, "unpaid")
		quit++
	if(quit)
		add_log("The guards walked off over unpaid wages.")
		announce("Prison wing: the guards walked off over unpaid wages.", SHIP_NOTIFY_WARNING)
	return quit

/**
 * The rounds clock: every OUTPOST_GUARD_ROUNDS_GAP_MIN to _MAX one free guard walks the cell
 * block, pausing at each cell door. Only while their AI runs.
 */
/datum/outpost_prison/proc/guard_rounds_tick(seconds)
	if(isnull(guard_rounds_left))
		return
	guard_rounds_left -= seconds
	if(guard_rounds_left > 0)
		return
	for(var/mob/living/basic/outpost_prison_guard/guard in shuffle(guard_mobs))
		if(!guard.on_duty() || !guard.ai_running() || guard.response)
			continue
		if(guard.activity && (!guard.activity.interruptible || istype(guard.activity, /datum/outpost_guard_activity/rounds)))
			continue
		var/datum/outpost_guard_activity/rounds/walk = new(guard)
		if(walk.setup())
			guard.start_activity(walk)
			break
		qdel(walk)
	guard_rounds_left = rand(OUTPOST_GUARD_ROUNDS_GAP_MIN, OUTPOST_GUARD_ROUNDS_GAP_MAX) / (1 SECONDS)

/**
 * The leash: a guard off the wing's level is recalled at once; one out of the wing for
 * OUTPOST_GUARD_LEASH_SECONDS walks back, or with nobody about to see it (or still out after
 * twice that), is recalled.
 */
/datum/outpost_prison/proc/guard_leash_check()
	var/z = wing_z()
	for(var/mob/living/basic/outpost_prison_guard/guard in guard_mobs)
		if(guard.phase != OUTPOST_GUARD_PRESENT)
			continue
		var/turf/here = get_turf(guard)
		if(!here)
			continue
		if(z && here.z != z)
			guard.recall()
			continue
		if(get_area(guard) == wing)
			guard.outside_seconds = 0
			continue
		guard.outside_seconds += OUTPOST_GUARD_CHECK_SECONDS
		if(guard.outside_seconds < OUTPOST_GUARD_LEASH_SECONDS)
			continue
		// Nobody about to watch them walk back, or they could not find the way: called back.
		if(!guard.ai_running() || guard.outside_seconds >= OUTPOST_GUARD_LEASH_SECONDS * 2)
			guard.recall()
		else if(guard.response?.kind != "leash")
			guard.give_response("leash", OUTPOST_GUARD_PRIORITY_LEASH, "leash", null, guard_office_spot(guard))

// ===== THE DISPATCHER =====

/**
 * Hands out responses and runs them, once a second, for guards whose AI runs. A creature out sends
 * everyone to the office; a riot gives everyone the riot doctrine; otherwise each incident (a
 * hatch climb, a fight, an argument, a threat), most urgent first, goes to the nearest free guard,
 * one guard each. Spats are stopped from where the guard stands, and loose prisoners are called
 * out and batoned if they come close. Then every guard deals with their response.
 */
/datum/outpost_prison/proc/dispatch_guards()
	var/list/on_duty = list()
	for(var/mob/living/basic/outpost_prison_guard/guard in guard_mobs)
		if(guard.on_duty() && guard.ai_running())
			on_duty += guard
	if(!riot_active)
		guard_riot_announced = FALSE
	var/creature_about = creature_out()
	if(!creature_about)
		guard_shelter_called = FALSE
	if(!length(on_duty))
		return
	if(creature_about)
		for(var/mob/living/basic/outpost_prison_guard/guard as anything in on_duty)
			if(guard.response?.kind == "shelter")
				continue
			guard.give_response("shelter", OUTPOST_GUARD_PRIORITY_SHELTER, "shelter", null, guard_office_spot(guard))
			if(!guard_shelter_called)
				guard_shelter_called = TRUE
				guard.say_guard("creature_flee")
	else if(riot_active)
		for(var/mob/living/basic/outpost_prison_guard/guard as anything in on_duty)
			if(guard.response?.kind == "riot")
				continue
			guard.give_response("riot", OUTPOST_GUARD_PRIORITY_RIOT, "riot", null, null)
			guard.say_guard("riot_call")
	else
		assign_guard_incidents(on_duty)
		guard_stop_spat(on_duty)
	guard_watch_loose(on_duty)
	for(var/mob/living/basic/outpost_prison_guard/guard as anything in on_duty)
		guard.perform_response()

/**
 * The wing's incidents that want a guard, most urgent first: list(key, kind, priority, prisoner).
 * Hatch climbs, fights with blows, arguments, then prisoners squaring up to someone, swinging, or
 * who just struck someone.
 */
/datum/outpost_prison/proc/guard_incidents()
	var/list/found = list()
	for(var/mob/living/basic/outpost_prisoner/prisoner in prisoners)
		if(prisoner.phase != PRISONER_PRESENT || prisoner.stat != CONSCIOUS || prisoner.can_be_dragged())
			continue
		if(prisoner.climb_ref)
			found += list(list("climb:[REF(prisoner)]", "climb", OUTPOST_GUARD_PRIORITY_CLIMB, prisoner))
		else if(!prisoner.trouble && (prisoner.threat_ref || prisoner.swing_ref || prisoner.guard_struck_recently()))
			found += list(list("threat:[REF(prisoner)]", "threat", OUTPOST_GUARD_PRIORITY_THREAT, prisoner))
	for(var/datum/outpost_prison_fight/brawl as anything in fights)
		if(QDELETED(brawl) || QDELETED(brawl.first))
			continue
		found += list(list("fight:[REF(brawl)]", "fight", brawl.fighting ? OUTPOST_GUARD_PRIORITY_FIGHT : OUTPOST_GUARD_PRIORITY_ARGUE, brawl.first))
	// Most urgent first
	var/list/sorted = list()
	while(length(found))
		var/list/top = found[1]
		for(var/list/incident as anything in found)
			if(incident[3] > top[3])
				top = incident
		found -= list(top)
		sorted += list(top)
	return sorted

/// Gives each incident nobody is on to the nearest guard who is free, or busy with something less urgent
/datum/outpost_prison/proc/assign_guard_incidents(list/on_duty)
	for(var/list/incident as anything in guard_incidents())
		var/key = incident[1]
		var/handled = FALSE
		for(var/mob/living/basic/outpost_prison_guard/guard as anything in on_duty)
			if(guard.response?.key == key)
				handled = TRUE
				// A fight's priority rises once blows fly.
				guard.response.priority = max(guard.response.priority, incident[3])
				break
		if(handled)
			continue
		var/mob/living/basic/outpost_prisoner/prisoner = incident[4]
		var/atom/where = prisoner
		var/turf/spot
		if(incident[2] == "climb")
			var/obj/structure/table/reinforced/prison_hatch/hatch = prisoner.climb_ref?.resolve()
			spot = hatch?.staff_side_turf()
			where = spot || prisoner
		var/mob/living/basic/outpost_prison_guard/best
		for(var/mob/living/basic/outpost_prison_guard/guard as anything in on_duty)
			if(guard.response && guard.response.priority >= incident[3])
				continue
			if(guard.skipping(key))
				continue
			if(!best || get_dist(guard, where) < get_dist(best, where))
				best = guard
		best?.give_response(incident[2], incident[3], key, prisoner, spot)

/// A spat in sight of a free guard: "Knock it off, you two", and it is over
/datum/outpost_prison/proc/guard_stop_spat(list/on_duty)
	if(spat_lines_left <= 0)
		return FALSE
	var/mob/living/basic/outpost_prisoner/one = spat_first_ref?.resolve()
	var/mob/living/basic/outpost_prisoner/two = spat_second_ref?.resolve()
	for(var/mob/living/basic/outpost_prison_guard/guard as anything in on_duty)
		if(guard.response)
			continue
		var/list/seen = view(OUTPOST_GUARD_SPAT_VIEW, guard)
		var/mob/living/basic/outpost_prisoner/speaker = (one && (one in seen)) ? one : ((two && (two in seen)) ? two : null)
		if(!speaker)
			continue
		guard.face_atom(speaker)
		guard.say_guard("spat_stop")
		spat_lines_left = 0
		return TRUE
	return FALSE

/// Loose prisoners: one guard calls each one out, once, and any guard they come beside batons them. No chase.
/datum/outpost_prison/proc/guard_watch_loose(list/on_duty)
	var/list/called = list()
	for(var/mob/living/basic/outpost_prisoner/prisoner in prisoners)
		if(prisoner.trouble != PRISONER_TROUBLE_LOOSE || prisoner.phase != PRISONER_PRESENT || prisoner.stat != CONSCIOUS)
			continue
		var/key = REF(prisoner)
		called[key] = TRUE
		if(!guard_loose_called[key])
			// Said aloud, and noted in the warden's log
			var/mob/living/basic/outpost_prison_guard/crier = pick(on_duty)
			if(crier.say_guard("loose_call", list("{place}" = get_area_name(prisoner))))
				add_log("[crier.real_name]: \"[crier.last_line]\"")
		if(prisoner.can_be_dragged())
			continue
		for(var/mob/living/basic/outpost_prison_guard/guard as anything in on_duty)
			if(guard.strike(prisoner))
				break
	guard_loose_called = called

/**
 * Runners about to get away for good (loose_tick() in outpost_prison_riot.dm). A guard on duty calls
 * it out, noted in the warden's log and put out to the crew in their words; with nobody on duty the
 * wing's announcement says it. Never how long is left.
 */
/datum/outpost_prison/proc/call_out_nearly_away(list/runners)
	if(!length(runners))
		return FALSE
	var/list/first_names = list()
	var/list/full_names = list()
	var/list/places = list()
	for(var/mob/living/basic/outpost_prisoner/runner as anything in runners)
		first_names += runner.speech_name()
		full_names += runner.real_name
		places |= get_area_name(runner)
	// Every line says where they were last seen
	var/list/values = list("{prisoner}" = english_list(first_names), "{place}" = english_list(places))
	var/list/on_duty = list()
	for(var/mob/living/basic/outpost_prison_guard/guard in guard_mobs)
		if(guard.on_duty())
			on_duty += guard
	if(length(on_duty))
		var/mob/living/basic/outpost_prison_guard/crier = pick(on_duty)
		if(crier.say_guard("loose_nearly", values))
			add_log("[crier.real_name]: \"[crier.last_line]\"")
			announce("[crier.real_name]: \"[crier.last_line]\"", SHIP_NOTIFY_DANGER)
			return TRUE
	announce("Prison wing: [english_list(full_names)] [length(runners) == 1 ? "is" : "are"] about to get away.", SHIP_NOTIFY_DANGER)
	return TRUE

/// The riot hold is called out once a riot: said aloud, and noted in the warden's log
/datum/outpost_prison/proc/announce_riot_hold(mob/living/basic/outpost_prison_guard/guard)
	if(guard_riot_announced)
		return FALSE
	guard_riot_announced = TRUE
	if(!guard.say_guard("riot_hold"))
		return FALSE
	add_log("[guard.real_name]: \"[guard.last_line]\"")
	return TRUE

/// Every prisoner who sees a baton strike loses OUTPOST_GUARD_ONLOOKER_MOOD, at most once per OUTPOST_GUARD_ONLOOKER_GAP each; one may say so
/datum/outpost_prison/proc/guard_strike_seen(mob/living/basic/outpost_prisoner/struck, mob/living/basic/outpost_prison_guard/guard)
	var/list/watchers = list()
	for(var/mob/living/basic/outpost_prisoner/onlooker in view(OUTPOST_GUARD_ONLOOKER_RANGE, struck))
		if(onlooker == struck || onlooker.prison != src || onlooker.stat != CONSCIOUS || onlooker.phase != PRISONER_PRESENT)
			continue
		if(onlooker.guard_onlooker_at && world.time - onlooker.guard_onlooker_at < OUTPOST_GUARD_ONLOOKER_GAP)
			continue
		onlooker.guard_onlooker_at = world.time
		onlooker.adjust_mood(-OUTPOST_GUARD_ONLOOKER_MOOD)
		watchers += onlooker
	if(length(watchers) && prob(50))
		var/mob/living/basic/outpost_prisoner/speaker = pick(watchers)
		INVOKE_ASYNC(speaker, TYPE_PROC_REF(/mob/living/basic/outpost_prisoner, say_context_with), "guard_batoned", list("{staff}" = guard.real_name))
	return watchers

// ===== MEMBERS, GREETINGS AND REPORTS =====

/// Members of the wing awake and playing on the wing's level
/datum/outpost_prison/proc/guard_members_about()
	var/list/members = list()
	var/z = wing_z()
	if(!z || z > length(SSmobs.clients_by_zlevel))
		return members
	for(var/mob/living/person as anything in SSmobs.clients_by_zlevel[z])
		if(QDELETED(person) || !person.client || person.stat != CONSCIOUS || is_outpost_prisoner(person))
			continue
		if(is_member(person))
			members += person
	return members

/// A member of the wing in the cell block, for the riot doctrine
/datum/outpost_prison/proc/guard_member_in_cell_block()
	for(var/mob/living/member as anything in guard_members_about())
		if(in_cell_block(member))
			return member
	return null

/// A rioter on their feet beside `member`, if any
/datum/outpost_prison/proc/rioter_beside(mob/living/member)
	for(var/mob/living/basic/outpost_prisoner/rioter in orange(1, member))
		if(rioter.prison == src && rioter.is_rioting() && rioter.stat == CONSCIOUS && !rioter.can_be_dragged())
			return rioter
	return null

/// What a guard calls a member: "boss" for the owner, else their first name, "boss" when masked
/datum/outpost_prison/proc/guard_boss_name(mob/living/member)
	if(!member || (outpost?.founder_ckey && member.ckey == outpost.founder_ckey))
		return "boss"
	var/seen = member.get_visible_name()
	if(!seen || seen == "Unknown")
		return "boss"
	return first_name(seen)

/**
 * What a guard tells a member about the wing, most pressing first: an empty hatch with prisoners
 * waiting, the first thing the yard is unhappy about, a hurt prisoner, a dark cell, else all quiet.
 * Returns list(context, values).
 */
/datum/outpost_prison/proc/guard_report()
	if(hatch_shortage())
		return list("report_hatch", list("{count}" = "[max(waiting_for_food, waiting_for_suits)]"))
	var/list/causes = restless_causes()
	if(length(causes))
		return list("report_restless", list("{cause}" = causes[1]))
	for(var/mob/living/basic/outpost_prisoner/prisoner in prisoners)
		if(counts_for_tension(prisoner) && ("hurt" in prisoner.bubble_needs()))
			return list("report_hurt", list("{prisoner}" = prisoner.speech_name()))
	var/list/dark = conditions_payload()["dark_cells"]
	if(length(dark))
		return list("report_dark", list("{cell}" = "[dark[1]]"))
	return list("report_all_good", list())

/// Every few seconds: a guard near a member greets them (every OUTPOST_GUARD_GREET_GAP) or tells them how the wing is (every OUTPOST_GUARD_REPORT_GAP)
/datum/outpost_prison/proc/guard_greet_check()
	var/list/members = guard_members_about()
	if(!length(members))
		return
	for(var/mob/living/member as anything in members)
		for(var/mob/living/basic/outpost_prison_guard/guard in guard_mobs)
			if(!guard.on_duty() || guard.response || get_dist(guard, member) > OUTPOST_GUARD_REPORT_RANGE || !(member in view(OUTPOST_GUARD_REPORT_RANGE, guard)))
				continue
			if(guard.greet_member(member))
				break

/**
 * Greets `member` if it is time, else reports to them if it is time. Returns TRUE if they said
 * something.
 */
/mob/living/basic/outpost_prison_guard/proc/greet_member(mob/living/member)
	if(!prison || !on_duty())
		return FALSE
	var/key = member.ckey || REF(member)
	var/boss = prison.guard_boss_name(member)
	var/greeted_at = prison.guard_greeted[key]
	if(!greeted_at || world.time - greeted_at >= OUTPOST_GUARD_GREET_GAP)
		prison.guard_greeted[key] = world.time
		face_atom(member)
		var/is_owner = prison.outpost?.founder_ckey && member.ckey == prison.outpost.founder_ckey
		if(say_guard(is_owner ? "greet_owner" : "greet_member", list("{boss}" = boss)))
			prison.note_speech()
			return TRUE
		return FALSE
	var/reported_at = prison.guard_reported[key]
	if(reported_at && world.time - reported_at < OUTPOST_GUARD_REPORT_GAP)
		return FALSE
	prison.guard_reported[key] = world.time
	var/list/report = prison.guard_report()
	var/list/values = report[2]
	values["{boss}"] = boss
	face_atom(member)
	if(say_guard(report[1], values))
		prison.note_speech()
		return TRUE
	return FALSE

/// Now and then a prisoner near an on-duty guard says hello, once per OUTPOST_GUARD_CHECK_ON_GAP each
/datum/outpost_prison/proc/guard_yard_chatter()
	if(!wing_can_speak() || !prob(OUTPOST_GUARD_NOTICE_CHANCE))
		return FALSE
	for(var/mob/living/basic/outpost_prison_guard/guard in shuffle(guard_mobs))
		if(!guard.on_duty() || !guard.ai_running())
			continue
		for(var/mob/living/basic/outpost_prisoner/prisoner in view(OUTPOST_GUARD_NOTICE_RANGE, guard))
			if(prisoner.prison != src || !prisoner.ai_running() || !prisoner.routine_allowed() || prisoner.activity?.sleeping)
				continue
			if(prisoner.guard_noticed_at && world.time - prisoner.guard_noticed_at < OUTPOST_GUARD_CHECK_ON_GAP)
				continue
			// A restless yard goes quiet (outpost_prison_ambience.dm).
			if(speech_hushed(prisoner, "guard_near"))
				continue
			prisoner.guard_noticed_at = world.time
			prisoner.face_atom(guard)
			if(prisoner.say_context_with("guard_near", list("{staff}" = guard.real_name)))
				note_speech()
				return TRUE
	return FALSE

// ===== PLACES =====

/// Staff doors that open onto the cell block: the ones the guards hold in a riot and stand post beside
/datum/outpost_prison/proc/guard_yard_doors()
	var/list/doors = list()
	for(var/turf/tile as anything in staff_door_turfs)
		if(cell_block[tile])
			doors += tile
	return doors

/// Whether a guard could stand on an office tile: open, nothing solid on it, no door
/datum/outpost_prison/proc/guard_office_tile(turf/tile)
	return isopenturf(tile) && tile.loc == wing && staff_ground?[tile] && !tile.is_blocked_turf(TRUE) && !(locate(/obj/machinery/door) in tile)

/// Whether a guard could stand on a tile of the yard: in the cell block, not in a cell, open, nothing solid, no door
/datum/outpost_prison/proc/guard_yard_tile(turf/tile)
	return isopenturf(tile) && tile.loc == wing && cell_block[tile] && !cell_at(tile) && !tile.is_blocked_turf(TRUE) && !(locate(/obj/machinery/door) in tile)

/// Whether someone other than `except` stands on a tile, or another guard means to
/datum/outpost_prison/proc/guard_spot_taken(turf/tile, mob/living/except)
	for(var/mob/living/other in tile)
		if(other != except && other.density)
			return TRUE
	for(var/mob/living/basic/outpost_prison_guard/guard in guard_mobs)
		if(guard == except)
			continue
		if(guard.response?.spot == tile || guard.activity?.goal_turf() == tile)
			return TRUE
	return FALSE

/**
 * The office tiles beside the staff doors into the cell block, the ones to the doors' sides first
 * so a guard standing there leaves the doorway clear
 */
/datum/outpost_prison/proc/guard_hold_spots()
	var/list/sides = list()
	var/list/fronts = list()
	for(var/turf/door as anything in guard_yard_doors())
		for(var/direction in GLOB.alldirs)
			var/turf/tile = get_step(door, direction)
			if(!guard_office_tile(tile))
				continue
			if(direction in GLOB.cardinals)
				fronts |= tile
			else
				sides |= tile
	return sides + fronts

/// A free office tile near the warden's console: where guards beam in and go when told to keep clear
/datum/outpost_prison/proc/guard_office_spot(mob/living/except)
	var/atom/anchor = guard_warden_console()
	var/list/doors = guard_yard_doors()
	if(!anchor && length(doors))
		anchor = doors[1]
	var/turf/best
	var/best_distance = INFINITY
	for(var/turf/tile as anything in staff_ground)
		if(!guard_office_tile(tile) || guard_spot_taken(tile, except))
			continue
		var/distance = anchor ? get_dist(anchor, tile) : 0
		if(distance < best_distance)
			best = tile
			best_distance = distance
	return best

/// The warden's console, if it stands on the office side
/datum/outpost_prison/proc/guard_warden_console()
	for(var/turf/tile as anything in staff_ground)
		var/obj/machinery/computer/outpost_prison_warden/console = locate() in tile
		if(console)
			return console
	return null

/// The office tile farthest from the staff doors into the cell block, for a hurt guard to fall back to
/datum/outpost_prison/proc/guard_fallback_spot(mob/living/except)
	var/list/doors = guard_yard_doors()
	var/turf/best
	var/best_distance = -1
	for(var/turf/tile as anything in staff_ground)
		if(!guard_office_tile(tile) || guard_spot_taken(tile, except))
			continue
		var/nearest_door = INFINITY
		for(var/turf/door as anything in doors)
			nearest_door = min(nearest_door, get_dist(door, tile))
		if(nearest_door > best_distance)
			best = tile
			best_distance = nearest_door
	return best

// ===== CONSOLES =====

/// The warden console's "guards" block: who is on the books and what they are doing, the posts, the price and the wage
/datum/outpost_prison/proc/guards_payload(mob/user)
	var/can_manage = !!outpost?.can_manage(user)
	var/list/rows = list()
	for(var/datum/outpost_guard_record/record as anything in guard_records)
		rows += list(list(
			"ref" = REF(record),
			"name" = record.full_name(),
			"rank" = record.rank,
			"status" = record.status(),
		))
	var/balance = outpost?.treasury?.account_balance || 0
	return list(
		"max" = guard_max(),
		"hire_cost" = OUTPOST_GUARD_HIRE_COST,
		"wage" = OUTPOST_GUARD_WAGE,
		"can_manage" = can_manage,
		"can_hire" = can_manage && hired_guard_count() < guard_max() && balance >= OUTPOST_GUARD_HIRE_COST,
		"list" = rows,
	)

/// guard_hire {} and guard_dismiss {ref}; TRUE if handled
/datum/outpost_prison/proc/guards_act(action, list/params, mob/user)
	switch(action)
		if("guard_hire")
			var/refusal = hire_guard(user)
			if(refusal)
				user?.balloon_alert(user, refusal)
			return TRUE
		if("guard_dismiss")
			if(!outpost?.can_manage(user))
				user?.balloon_alert(user, "managers only")
				return TRUE
			var/datum/outpost_guard_record/record = locate(params?["ref"]) in guard_records
			if(!record)
				user?.balloon_alert(user, "no such guard")
				return TRUE
			var/dismissed_name = record.full_name()
			dismiss_guard(record)
			add_log("[dismissed_name] was dismissed.")
			log_game("PLAYER OUTPOST PRISON: [key_name(user)] dismissed [dismissed_name] at '[outpost?.name]'")
			return TRUE
	return FALSE

/// The admin panel's guards: list of {ref, name, health, status, activity, response}
/datum/outpost_prison/proc/guards_admin_payload()
	var/list/rows = list()
	for(var/datum/outpost_guard_record/record as anything in guard_records)
		var/mob/living/basic/outpost_prison_guard/guard = record.guard
		var/status = record.status()
		if(status == "away" || status == "down")
			var/back = record.back_in()
			if(back)
				status += " ([back] s)"
		rows += list(list(
			"ref" = REF(record),
			"name" = record.full_name() + (record.free ? " (admin)" : ""),
			"health" = guard ? round(guard.health) : 0,
			"status" = status,
			"activity" = guard?.activity?.name || "-",
			"response" = guard?.response ? guard.response.kind : "-",
		))
	return rows

/// prison_guard_spawn, prison_guard_remove {ref}, prison_guard_down {ref}: a log line, list("error" = text), or null
/datum/outpost_prison/proc/guards_admin_act(action, list/params, mob/user)
	switch(action)
		if("prison_guard_spawn")
			var/datum/outpost_guard_record/record = add_guard_record(TRUE)
			if(!record.guard)
				guard_records -= record
				qdel(record)
				return list("error" = "There is nowhere in the office for a guard to stand.")
			return "spawn prison guard [record.full_name()]"
		if("prison_guard_remove", "prison_guard_down")
			var/datum/outpost_guard_record/record = locate(params?["ref"]) in guard_records
			if(!record)
				return list("error" = "That guard is gone.")
			var/guard_name = record.full_name()
			if(action == "prison_guard_remove")
				dismiss_guard(record, "dismissed", forget_wait = TRUE)
				return "remove prison guard [guard_name]"
			var/mob/living/basic/outpost_prison_guard/guard = record.guard
			if(!guard?.on_duty())
				return list("error" = "That guard is not on duty.")
			guard.adjust_health(guard.health - OUTPOST_GUARD_DOWN_AT)
			if(guard.phase != OUTPOST_GUARD_DOWN)
				guard.go_down()
			return "put prison guard [guard_name] down"
	return null

// ===== LIFE AND DEATH OF THE PRISON =====

/datum/outpost_prison/proc/guards_destroy()
	for(var/mob/living/basic/outpost_prison_guard/guard in guard_mobs.Copy())
		if(QDELETED(guard))
			continue
		guard.prison = null
		guard.record = null
		qdel(guard)
	guard_mobs.Cut()
	for(var/datum/outpost_guard_record/record as anything in guard_records)
		record.guard = null
	QDEL_LIST(guard_records)
	guard_slot_waits.Cut()
	guard_greeted.Cut()
	guard_reported.Cut()
	guard_loose_called.Cut()

/// The outpost was abandoned: every guard is dismissed, no refund, and beams out
/datum/outpost_prison/proc/guards_abandon()
	for(var/datum/outpost_guard_record/record as anything in guard_records.Copy())
		var/mob/living/basic/outpost_prison_guard/guard = record.guard
		dismiss_guard(record, "dismissed", forget_wait = TRUE)
		guard?.beam_out()
	guard_slot_waits.Cut()
	guard_unpaid = 0
	guard_wage_owed = 0

// ===== LOOK =====

/**
 * A corrections officer: pale blue shirt and tie over navy trousers, a navy peaked police cap,
 * black gloves and combat boots, and an earpiece. No red, no orange (that's the inmates), no
 * armour; the stun baton is drawn in hand only when they use it (update_overlays()).
 */
/datum/outfit/outpost_prison_guard
	name = "Outpost prison guard"
	uniform = /obj/item/clothing/under/rank/security/officer/blueshirt
	head = /obj/item/clothing/head/hats/warden/police
	gloves = /obj/item/clothing/gloves/color/black
	shoes = /obj/item/clothing/shoes/jackboots
	ears = /obj/item/radio/headset

#undef OUTPOST_GUARD_DIALOGUE_FILE
