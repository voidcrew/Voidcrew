/**
 * # Prison guards
 *
 * The wing's NPC guards: named people on its roster who keep a peaceful routine, step in on spats,
 * arguments, fights, threats and hatch climbs, and hold the staff doors in a riot. Nobody hires or
 * pays them: the roster is always OUTPOST_GUARD_MAX (keep_guard_roster()). Their routine and
 * activities are in outpost_prison_guard_routine.dm; numbers in voidcrew/_DEFINES/outpost_prison_guards.dm.
 *
 * A guard is a real human body (voidcrew/modules/human_npcs/, owner ruling OC-2): stuns, stamina,
 * batons, bleeding, crit and death work on them as on anyone, and nothing tops their health up. Hurt,
 * they patch themselves up with the office first-aid kit (outpost_prison_guard_routine.dm). Down in
 * crit they stay where they fell, a body like anyone's: nobody takes them away. One who dies, or is
 * carried out of the wing for a minute, is off the roster, and OUTPOST_GUARD_RETURN_TIME later
 * someone new comes on shift in their place, whether or not anyone is at the outpost. A dead guard's
 * body is cleared once no client has been able to see it for OUTPOST_PRISON_BODY_UNSEEN. Their kit
 * is locked to them (D3): it never becomes loot.
 *
 * Each guard is a record on the prison (name, rank, personality, face, when they are back). The
 * guard on the wing is a mob made from the record. Guards come and go through the staff closet in
 * the office, a small room behind a door: a new one is made inside it with the door shut and walks
 * out, and one going off shift walks in and is gone once the door has shut behind them. A wing with
 * no staff closet mapped (the unit tests' wing) uses the office floor.
 *
 * Guards are security only: they never feed, clothe, treat, clean or light anything. They never
 * strike players, pets, bots or other NPCs, and they strike a
 * prisoner only for violence under way (fighting, rioting, swinging, climbing out, loose) with the
 * real stun baton off their belt, through their own hands: tg's stamina, knockdown and cell charge.
 * A prisoner never holds a guard's blow against staff (hit_by_staff()).
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
	var/mob/living/carbon/human/npc/outpost_prison_guard/guard = thing
	if(!istype(guard))
		return FALSE
	return !on_duty || guard.on_duty()

/// Whether `thing` is an AI-driven prison guard (nobody playing them)
/proc/is_ai_outpost_prison_guard(atom/thing)
	var/mob/living/carbon/human/npc/outpost_prison_guard/guard = thing
	return istype(guard) && isnull(guard.mind) && isnull(guard.client)

/// A top-level entry of the guards' dialogue file, or an empty list
/proc/outpost_guard_dialogue(key)
	return outpost_prisoner_extra_dialogue(OUTPOST_GUARD_DIALOGUE_FILE, key)

// ===== THE GUARD =====

/mob/living/carbon/human/npc/outpost_prison_guard
	name = "guard"
	desc = "A corrections officer. Works the lockup."
	combat_mode = FALSE
	faction = list(FACTION_NEUTRAL)
	ai_controller = /datum/ai_controller/basic_controller/outpost_prison_guard
	npc_outfit = /datum/outfit/outpost_prison_guard
	// They stop once a prisoner is down (defaults 1.13), and only ever go for prisoners.
	npc_target_stat = HUMAN_NPC_SPARES_DOWNED
	// The wing clears its own dead (guard_down_tick()); the base never cleans the body up.
	npc_corpse_lifetime = 0

	/// The prison they work
	var/datum/outpost_prison/prison
	/// Who they are on the payroll: name, rank, personality, when they are back
	var/datum/outpost_guard_record/record
	/// OUTPOST_GUARD_ARRIVING, _PRESENT, _DOWN or _DISMISSED
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
	/// world.time they went down (crit) or died
	var/down_since = 0
	/// The last thing they said, so they don't repeat it at once
	var/last_line
	/// Killed rather than downed
	var/died_on_duty = FALSE
	/// Off shift: seconds left to walk to the staff closet before they may go from wherever they are
	var/dismiss_left = 0
	/// Off shift: where they walk to, a tile of the staff closet
	var/turf/leave_spot
	/// Just come on shift: they say so once they are out of the staff closet
	var/fresh_on_shift = FALSE
	/// Seconds their body has lain, or they have stood off shift, with no client able to see them
	var/unseen_seconds = 0
	/// Seconds counted outside the wing, for the leash
	var/outside_seconds = 0
	COOLDOWN_DECLARE(baton_cooldown)
	/// Between their own idle lines
	COOLDOWN_DECLARE(speech_cooldown)
	/// Between "Hey. Don't." lines
	COOLDOWN_DECLARE(warned_cooldown)

/mob/living/carbon/human/npc/outpost_prison_guard/Initialize(mapload)
	. = ..(mapload)
	AddElement(/datum/element/relay_attackers)
	RegisterSignal(src, COMSIG_ATOM_WAS_ATTACKED, PROC_REF(on_attacked))
	// Nothing moves a guard but their own feet.
	RegisterSignal(src, COMSIG_MOVABLE_TELEPORTING, PROC_REF(refuse_teleport))
	RegisterSignal(src, COMSIG_LIVING_PRE_WABBAJACKED, PROC_REF(refuse_polymorph))
	RegisterSignal(src, COMSIG_PRE_MOB_CHANGED_TYPE, PROC_REF(refuse_type_change))
	RegisterSignal(src, COMSIG_MOUSEDROP_ONTO, PROC_REF(block_being_dragged))
	// On their feet nobody boxes or bags them; down or dead they are a body like anyone's (set_guard_upright()).
	// Anyone can drag a guard who is down. A guard on their feet shakes off anyone but the wing's members (guards_tick()).
	set_guard_upright(TRUE)
	set_prison_pace(hurry = FALSE)

/mob/living/carbon/human/npc/outpost_prison_guard/Destroy()
	end_response(cancel_ai = FALSE)
	end_activity(cancel_ai = FALSE)
	if(record?.guard == src)
		record.guard = null
		// Gone some other way than off shift (an admin delete): someone is back later.
		if(!record.dismissed && record.away_left <= 0)
			record.away_left = OUTPOST_GUARD_RETURN_TIME / (1 SECONDS)
	record = null
	prison?.guard_mobs -= src
	prison = null
	leave_spot = null
	return ..()

/// Takes on the name, rank, face and personality of the guard on the payroll. The first one sent sets the record's face.
/mob/living/carbon/human/npc/outpost_prison_guard/proc/join(datum/outpost_prison/owner, datum/outpost_guard_record/hired)
	prison = owner
	record = hired
	hired.guard = src
	owner.guard_mobs |= src
	ai_controller?.reset_ai_status()
	if(length(hired.look))
		outpost_prison_apply_look(src, hired.look)
	else
		hired.look = outpost_prison_save_look(src)
		hired.gender = gender
	personality = hired.personality
	fully_replace_character_name(real_name, hired.full_name())

/// On the wing and on duty: arrived, not down, cuffed or stunned, not dismissed, and not paid by the kingpin to stand back (outpost_prison_boss_moves.dm)
/mob/living/carbon/human/npc/outpost_prison_guard/proc/on_duty()
	return !QDELETED(src) && phase == OUTPOST_GUARD_PRESENT && stat == CONSCIOUS && !human_npc_out_of_fight(src) && !boss_bribed()

/// Whether their AI is running, which it is only while someone is on the level to see them (see outpost_prison_ai_running())
/mob/living/carbon/human/npc/outpost_prison_guard/proc/ai_running()
	return outpost_prison_ai_running(src)

/// Their stun baton, wherever on them it is
/mob/living/carbon/human/npc/outpost_prison_guard/proc/get_baton()
	return locate(/obj/item/melee/baton/security) in get_all_contents()

/// Draws the baton off the belt into a hand and switches it on, or puts it away again, as an officer does
/mob/living/carbon/human/npc/outpost_prison_guard/proc/set_baton(out)
	out = !!out
	var/obj/item/melee/baton/security/baton = get_baton()
	if(!baton)
		baton_out = FALSE
		return
	if(out)
		if(!is_holding(baton) && !human_npc_take_in_hand(src, baton))
			return
		if(!baton.active && baton.cell?.charge >= baton.cell_hit_cost)
			baton.attack_self(src)
		baton_out = TRUE
		return
	baton_out = FALSE
	if(!is_holding(baton))
		return
	if(baton.active)
		baton.attack_self(src)
	if(!equip_to_slot_if_possible(baton, ITEM_SLOT_BELT, disable_warning = TRUE))
		baton.equip_to_best_slot(src)

// ===== REFUSALS =====

/mob/living/carbon/human/npc/outpost_prison_guard/proc/refuse_teleport(datum/source, atom/destination, channel)
	SIGNAL_HANDLER
	if(isturf(loc))
		visible_message(span_notice("[src] flickers for a moment, but stays where [p_they()] [p_are()]."))
	return TRUE

/mob/living/carbon/human/npc/outpost_prison_guard/proc/refuse_polymorph(datum/source, what_to_randomize)
	SIGNAL_HANDLER
	visible_message(span_notice("[src] shimmers for a moment, then looks the same as before."))
	return STOP_WABBAJACK

/mob/living/carbon/human/npc/outpost_prison_guard/proc/refuse_type_change(datum/source)
	SIGNAL_HANDLER
	return COMPONENT_BLOCK_MOB_CHANGE

/// On their feet they refuse lockers and bags; down or dead, a body can be bagged like anyone's
/mob/living/carbon/human/npc/outpost_prison_guard/proc/set_guard_upright(upright)
	if(upright)
		add_traits(list(TRAIT_NO_CONTAINMENT, TRAIT_NO_STORAGE_INSERT), OUTPOST_GUARD_UPRIGHT_TRAIT)
	else
		remove_traits(list(TRAIT_NO_CONTAINMENT, TRAIT_NO_STORAGE_INSERT), OUTPOST_GUARD_UPRIGHT_TRAIT)

/// Not dragged onto things while on their feet
/mob/living/carbon/human/npc/outpost_prison_guard/proc/block_being_dragged(atom/over, mob/user)
	SIGNAL_HANDLER
	return stat == CONSCIOUS && phase == OUTPOST_GUARD_PRESENT ? COMPONENT_CANCEL_MOUSEDROP_ONTO : NONE

/// On their feet, a guard won't be led about by anyone but the wing's own staff: they resist it, as anyone resists a pull
/mob/living/carbon/human/npc/outpost_prison_guard/proc/shake_off_pull()
	if(!pulledby || !on_duty() || world.time < next_move)
		return
	if(isliving(pulledby) && prison?.is_staff(pulledby))
		return
	execute_resist()

// ===== HURT, DOWN AND DEAD =====

/**
 * Into crit: they go down and stay down, a real body on the floor. Nobody comes for them: treated or
 * back out of crit on their own they are on duty again; they can as well bleed out, or be finished off.
 */
/mob/living/carbon/human/npc/outpost_prison_guard/npc_on_downed()
	. = ..()
	go_down()

/// Back out of crit: on their feet and on duty again
/mob/living/carbon/human/npc/outpost_prison_guard/npc_on_recovered()
	. = ..()
	if(phase != OUTPOST_GUARD_DOWN || died_on_duty || stat == DEAD || HAS_TRAIT(src, TRAIT_CRITICAL_CONDITION))
		return
	phase = OUTPOST_GUARD_PRESENT
	down_since = 0
	set_guard_upright(TRUE)
	prison?.add_log("[real_name] is back on [p_their()] feet.")

/// The prison's guards speak from their own file (say_guard()); a few of tg's changes map onto their lines.
/mob/living/carbon/human/npc/outpost_prison_guard/npc_bark(kind, force = FALSE)
	switch(kind)
		if(HUMAN_NPC_BARK_DOWNED)
			return say_guard("downed")
	return FALSE

/mob/living/carbon/human/npc/outpost_prison_guard/death(gibbed)
	var/was_alive = stat != DEAD
	. = ..()
	if(!was_alive || stat != DEAD)
		return
	died_on_duty = TRUE
	set_guard_upright(FALSE)
	if(!prison)
		return
	end_response()
	end_activity()
	baton_out = FALSE
	phase = OUTPOST_GUARD_DOWN
	down_since = world.time
	unseen_seconds = 0
	prison.guard_killed(src)

/**
 * Down in crit: lying there, off duty until they are back on their feet (npc_on_recovered()). Nothing
 * protects them meanwhile: they can bleed out, or be finished off.
 */
/mob/living/carbon/human/npc/outpost_prison_guard/proc/go_down()
	if(QDELETED(src) || phase == OUTPOST_GUARD_DOWN)
		return FALSE
	phase = OUTPOST_GUARD_DOWN
	end_response()
	end_activity()
	baton_out = FALSE
	set_guard_upright(FALSE)
	down_since = world.time
	visible_message(span_danger("[src] goes down!"))
	prison?.add_log("[real_name] went down.")
	return TRUE

/// Someone took a swing at them. Prisoners are the dispatcher's business; anyone else gets a warning and some room.
/mob/living/carbon/human/npc/outpost_prison_guard/proc/on_attacked(datum/source, atom/attacker, attack_flags)
	SIGNAL_HANDLER
	if(!(attack_flags & (ATTACKER_DAMAGING_ATTACK | ATTACKER_STAMINA_ATTACK | ATTACKER_SHOVING)))
		return
	if(is_outpost_prisoner(attacker) || !on_duty())
		return
	INVOKE_ASYNC(src, PROC_REF(warn_off), attacker)

/// "Hey. Don't." and a step back. Guards never strike players.
/mob/living/carbon/human/npc/outpost_prison_guard/proc/warn_off(atom/attacker)
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

// ===== ON AND OFF SHIFT =====

/**
 * On shift. They are made in the staff closet with its door shut (spawn_guard()) and are on duty at once:
 * their routine walks them out by the door, which opens for them like any staff door. They say so once
 * they are out of the closet (announce_arrival(), from guards_tick()).
 */
/mob/living/carbon/human/npc/outpost_prison_guard/proc/arrive()
	phase = OUTPOST_GUARD_PRESENT
	fresh_on_shift = TRUE
	unseen_seconds = 0
	return TRUE

/// Out of the staff closet and on the floor: they say so, once
/mob/living/carbon/human/npc/outpost_prison_guard/proc/announce_arrival()
	if(!fresh_on_shift || phase != OUTPOST_GUARD_PRESENT)
		return FALSE
	fresh_on_shift = FALSE
	if(say_guard("arrival"))
		prison?.note_speech()
	return TRUE

/**
 * Off shift: their place on the roster is free for whoever comes on after `away_seconds`, and they walk
 * to the staff closet. They are gone once its door has shut behind them, or from wherever they stand once
 * the walk is given up and no client can see them (/datum/outpost_prison/proc/guard_gone_off()). Until
 * then they are a body like anyone's.
 */
/mob/living/carbon/human/npc/outpost_prison_guard/proc/go_off(away_seconds = 0)
	if(phase == OUTPOST_GUARD_DISMISSED)
		return FALSE
	phase = OUTPOST_GUARD_DISMISSED
	end_response()
	end_activity()
	set_baton(FALSE)
	set_prison_pace(hurry = FALSE)
	if(record?.guard == src)
		record.guard = null
		if(!record.dismissed)
			record.away_left = max(record.away_left, away_seconds)
	dismiss_left = OUTPOST_GUARD_DISMISS_WALK
	leave_spot = prison?.guard_leave_spot(src)
	unseen_seconds = 0
	return TRUE

/// Called back from somewhere they should not be (off the wing's level, or out of the wing and unable to walk back)
/mob/living/carbon/human/npc/outpost_prison_guard/proc/recall(away_seconds = OUTPOST_GUARD_OFF_LEVEL_AWAY)
	if(phase != OUTPOST_GUARD_PRESENT)
		return FALSE
	say_guard("recalled")
	prison?.add_log("[real_name] was called back to the wing.")
	return go_off(away_seconds)

/// Off the roster: they say `context` if they can, and go off shift for good
/mob/living/carbon/human/npc/outpost_prison_guard/proc/leave(context = "dismissed")
	if(phase == OUTPOST_GUARD_DISMISSED)
		return FALSE
	if(phase == OUTPOST_GUARD_PRESENT && stat == CONSCIOUS)
		say_guard(context)
	return go_off()

// ===== SPEECH =====

/// A line for `context` in their personality (or anyone's), with `values` filled in, or null
/mob/living/carbon/human/npc/outpost_prison_guard/proc/pick_guard_line(context, list/values)
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
/mob/living/carbon/human/npc/outpost_prison_guard/proc/usable_guard_lines(list/pool, list/values)
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

/// Says a line for `context`. Returns TRUE if they said something. Never before they are on shift.
/mob/living/carbon/human/npc/outpost_prison_guard/proc/say_guard(context, list/values)
	if(QDELETED(src) || stat == DEAD || phase == OUTPOST_GUARD_ARRIVING)
		return FALSE
	var/line = pick_guard_line(context, values)
	if(!line)
		return FALSE
	last_line = line
	say(line)
	return TRUE

/// An idle line: waits for the wing to be quiet and for their own pause, and counts toward the wing's
/mob/living/carbon/human/npc/outpost_prison_guard/proc/idle_say(context, list/values)
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
/mob/living/carbon/human/npc/outpost_prison_guard/proc/may_strike(mob/living/carbon/human/npc/outpost_prisoner/prisoner)
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
 * One strike with the real stun baton off their belt, through their own hands: tg's baton does its
 * stamina damage and knockdown, against the prisoner's armour, off the cell's charge. Their blows stop,
 * and every prisoner who sees it loses a little mood. A prisoner never holds a guard's blow against staff
 * (hit_by_staff()). Returns TRUE if they swung.
 */
/mob/living/carbon/human/npc/outpost_prison_guard/proc/strike(mob/living/carbon/human/npc/outpost_prisoner/prisoner)
	if(!COOLDOWN_FINISHED(src, baton_cooldown) || !may_strike(prisoner))
		return FALSE
	var/obj/item/melee/baton/security/baton = get_baton()
	// A flat cell would make it a club, and guards never hurt anyone: they go to change it (baton_flat()).
	if(!baton || !baton.cell || baton.cell.charge < baton.cell_hit_cost)
		baton_flat()
		return FALSE
	set_baton(TRUE)
	// The baton recharges between stuns, as anyone's does.
	if(!is_holding(baton) || !baton.active || !COOLDOWN_FINISHED(baton, cooldown_check))
		return FALSE
	COOLDOWN_START(src, baton_cooldown, OUTPOST_GUARD_BATON_COOLDOWN)
	if(!outpost_prison_npc_hit(src, prisoner, baton))
		return FALSE
	prisoner.stop_blows()
	prison.guard_strike_seen(prisoner, src)
	return TRUE

/**
 * Their baton's cell is flat. The office recharger can't take a baton that is locked to its guard
 * (human_npc_gear.dm), so they swap shifts: they say so and go off by the staff closet, and the
 * record sends them back with a charged baton after OUTPOST_GUARD_SHIFT_SWAP_TIME.
 */
/mob/living/carbon/human/npc/outpost_prison_guard/proc/baton_flat()
	if(phase != OUTPOST_GUARD_PRESENT || !prison)
		return FALSE
	say_guard("recalled")
	prison.add_log("[real_name]'s baton went flat. [p_They()] went to swap shifts.")
	return go_off(OUTPOST_GUARD_SHIFT_SWAP_TIME / (1 SECONDS))

/// Strikes a rioter beside them. Returns TRUE if they struck.
/mob/living/carbon/human/npc/outpost_prison_guard/proc/strike_adjacent_rioter()
	if(!COOLDOWN_FINISHED(src, baton_cooldown))
		return FALSE
	for(var/mob/living/carbon/human/npc/outpost_prisoner/rioter in orange(1, src))
		if(rioter.is_rioting() && strike(rioter))
			return TRUE
	return FALSE

// ===== RESPONSES =====

/// Sends them to deal with something, dropping their routine
/mob/living/carbon/human/npc/outpost_prison_guard/proc/give_response(kind, priority, key, atom/target, turf/spot)
	end_response(cancel_ai = FALSE)
	end_activity(cancel_ai = FALSE)
	response = new(kind, key, priority, target, spot)
	response.expires_at = world.time + OUTPOST_GUARD_RESPONSE_TIMEOUT
	set_prison_pace(hurry = TRUE)
	set_baton(TRUE)
	ai_controller?.CancelActions()
	return response

/// Back to routine
/mob/living/carbon/human/npc/outpost_prison_guard/proc/end_response(cancel_ai = TRUE)
	if(!response)
		return
	QDEL_NULL(response)
	if(!QDELETED(src))
		set_prison_pace(hurry = FALSE)
		set_baton(FALSE)
	if(cancel_ai)
		ai_controller?.CancelActions()

/// Whether they gave up on an incident recently
/mob/living/carbon/human/npc/outpost_prison_guard/proc/skipping(key)
	return LAZYACCESS(response_skips, key) > world.time

/**
 * Deals with their response for a second: works out where they need to be (response.goal, which
 * the AI walks them to) and, once there, acts. Called by the dispatcher every second. Returns
 * TRUE while the response goes on.
 */
/mob/living/carbon/human/npc/outpost_prison_guard/proc/perform_response()
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
/mob/living/carbon/human/npc/outpost_prison_guard/proc/at_goal(atom/goal)
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
/mob/living/carbon/human/npc/outpost_prison_guard/proc/fight_response(datum/outpost_guard_response/job)
	var/mob/living/carbon/human/npc/outpost_prisoner/fighter = job.target()
	var/datum/outpost_prison_fight/brawl = fighter?.fight
	if(QDELETED(brawl))
		return TRUE
	var/mob/living/carbon/human/npc/outpost_prisoner/other = brawl.opponent_of(fighter)
	var/mob/living/carbon/human/npc/outpost_prisoner/beside = Adjacent(fighter) ? fighter : ((other && Adjacent(other)) ? other : null)
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
/mob/living/carbon/human/npc/outpost_prison_guard/proc/threat_response(datum/outpost_guard_response/job)
	var/mob/living/carbon/human/npc/outpost_prisoner/prisoner = job.target()
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
/mob/living/carbon/human/npc/outpost_prison_guard/proc/climb_response(datum/outpost_guard_response/job)
	var/mob/living/carbon/human/npc/outpost_prisoner/climber = job.target()
	var/obj/structure/table/reinforced/prison_hatch/hatch = climber?.climb_ref?.resolve()
	if(!hatch)
		return TRUE
	var/turf/stand = job.spot || hatch.staff_side_turf()
	if(!stand)
		return TRUE
	// Any office tile beside the counter will do; the one past it is where they head for.
	if(loc != stand && !(get_dist(src, hatch) <= 1 && prison.office_ground()[loc]))
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
/mob/living/carbon/human/npc/outpost_prison_guard/proc/riot_response(datum/outpost_guard_response/job)
	if(!prison.riot_active)
		return TRUE
	job.reached = TRUE
	if(health < OUTPOST_GUARD_FALLBACK_BELOW)
		if(job.mode != "fallback")
			job.mode = "fallback"
			job.spot = prison.guard_fallback_spot(src)
			say_guard("fallback")
		job.set_goal((job.spot && loc != job.spot) ? job.spot : null)
		if(!strike_adjacent_rioter() && (!job.spot || loc == job.spot))
			// Back in the corner, they patch themselves up from the office's first-aid kit (outpost_prison_guard_routine.dm).
			INVOKE_ASYNC(src, PROC_REF(treat_self))
		return FALSE
	var/mob/living/member = prison.guard_member_in_cell_block()
	if(member)
		if(job.mode != "follow")
			job.mode = "follow"
			job.spot = null
			say_guard("follow_member", list("{boss}" = prison.guard_boss_name(member)))
		var/mob/living/carbon/human/npc/outpost_prisoner/attacker = prison.rioter_beside(member)
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
/mob/living/carbon/human/npc/outpost_prison_guard/proc/take_hold_position()
	if(!prison)
		return null
	for(var/turf/spot as anything in prison.guard_hold_spots())
		if(prison.guard_spot_taken(spot, src))
			continue
		response?.spot = spot
		return spot
	return null

/// Wandered out of the wing: back to the office
/mob/living/carbon/human/npc/outpost_prison_guard/proc/leash_response(datum/outpost_guard_response/job)
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

/mob/living/carbon/human/npc/outpost_prisoner
	/// world.time a guard last checked on them, or they last said hello to a guard
	var/guard_noticed_at = 0
	/// world.time they last lost mood seeing a guard's baton
	var/guard_onlooker_at = 0

/// Whether they struck someone (not another prisoner) in the last OUTPOST_GUARD_STRUCK_RECENT
/mob/living/carbon/human/npc/outpost_prisoner/proc/guard_struck_recently()
	return struck_at && world.time - struck_at <= OUTPOST_GUARD_STRUCK_RECENT && !isnull(struck_ref?.resolve())

// ===== THE PAYROLL =====

/// One guard on the payroll: who they are, and when they are back if they are away
/datum/outpost_guard_record
	var/datum/outpost_prison/prison
	/// The guard on the wing now, if any
	var/mob/living/carbon/human/npc/outpost_prison_guard/guard
	/// "Officer" or "Sergeant"
	var/rank = "Officer"
	var/surname = "Hale"
	var/gender = MALE
	var/personality = "by_the_book"
	/// Their face, saved from the first body sent (outpost_prison_save_look()), so the same person comes back
	var/list/look
	/// An admin's guard: not counted against guard_max()
	var/free = FALSE
	var/dismissed = FALSE
	/// Seconds until someone comes on shift in this slot while it is empty (a death, a recall), audience or none
	var/away_left = 0
	/// What the guard is made as (tests use a subtype)
	var/guard_type = /mob/living/carbon/human/npc/outpost_prison_guard

/datum/outpost_guard_record/New(datum/outpost_prison/owner, rank, free = FALSE, guard_type)
	. = ..()
	prison = owner
	src.rank = rank
	src.free = free
	if(ispath(guard_type, /mob/living/carbon/human/npc/outpost_prison_guard))
		src.guard_type = guard_type
	gender = pick(MALE, FEMALE)
	if(length(GLOB.last_names))
		surname = pick(GLOB.last_names)
	var/list/personalities = outpost_guard_dialogue("guard_personalities")
	if(length(personalities))
		personality = pick(personalities)

/datum/outpost_guard_record/Destroy()
	if(guard?.record == src)
		guard.record = null
	guard = null
	prison = null
	return ..()

/// "Officer Hale"
/datum/outpost_guard_record/proc/full_name()
	return "[rank] [surname]"

/// Seconds before this slot has a guard on the wing again, 0 while it has one
/datum/outpost_guard_record/proc/pending_wait()
	return guard ? 0 : max(0, away_left)

/// What the console calls them: arriving, post, rounds, routine, responding, riot, down or away
/datum/outpost_guard_record/proc/status()
	if(!guard || guard.phase == OUTPOST_GUARD_DISMISSED)
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
	/// Every guard on the roster
	var/list/datum/outpost_guard_record/guard_records = list()
	/// Every guard mob of this prison, on the wing or leaving it
	var/list/mob/living/carbon/human/npc/outpost_prison_guard/guard_mobs = list()
	/// Seconds since the last greeting, leash and chatter check
	var/guard_check_clock = 0
	/// Seconds to the next rounds of the cell block, or null before the first guard arrives
	var/guard_rounds_left
	/// Percent chance a guard talks down an argument; tests set it
	var/guard_talkdown_chance = OUTPOST_GUARD_TALKDOWN_CHANCE
	/// Key of someone a guard answers to -> world.time a guard last greeted them, and last reported to them
	var/list/guard_greeted = list()
	var/list/guard_reported = list()
	/// REF() of loose prisoners a guard has called out
	var/list/guard_loose_called = list()
	/// Whether the guards' riot hold was called out this riot
	var/guard_riot_announced = FALSE
	/// Whether the wing keeps its own roster full (keep_guard_roster()); the unit tests' wing does not
	var/roster_kept = TRUE
	/// Whether the wing clears its own dead once nobody can see them (guard_down_tick(), body_tick()); the unit tests' wing does not
	var/bodies_cleared = TRUE
	/// Whether the wing keeps a cleanbot (keep_cleanbot()); the unit tests' wing does not
	var/bot_kept = TRUE
	/// The wing's cleanbot
	var/datum/weakref/cleanbot_ref
	/// Seconds since the cleanbot was last pointed at a mess
	var/cleanbot_clock = 0
	/// The office: staff_ground a guard can walk to from the yard's staff doors without passing another door (office_ground())
	var/list/office_cache

/// Guards on the wing's roster
/datum/outpost_prison/proc/guard_max()
	return OUTPOST_GUARD_MAX

/// "Officer" for the first on the roster, "Sergeant" for the next
/datum/outpost_prison/proc/next_guard_rank()
	for(var/datum/outpost_guard_record/record as anything in guard_records)
		if(record.rank == "Officer")
			return "Sergeant"
	return "Officer"

/// A new guard on the roster, on shift at once if the staff closet is free. `free` is an admin's guard. Returns the record.
/datum/outpost_prison/proc/add_guard_record(free = FALSE, guard_type)
	var/datum/outpost_guard_record/record = new(src, next_guard_rank(), free, guard_type)
	guard_records += record
	spawn_guard(record)
	return record

/**
 * Brings a record's guard on shift: made in the staff closet with its door shut, to walk out by it. Returns
 * the guard, or null while the closet is not free (its door open, or someone standing in it).
 */
/datum/outpost_prison/proc/spawn_guard(datum/outpost_guard_record/record)
	if(!record || record.dismissed || record.guard)
		return null
	var/turf/spot = guard_arrival_spot()
	if(!spot)
		return null
	// Nobody is sent into a wing with air nobody can breathe; the slot waits for it to be fixed.
	if(outpost_prison_unsafe_air(spot.return_air()))
		return null
	var/datum/npc_spawn_context/context = new(outpost, role = "exempt")
	// One at a time, as they are added or sent back: no need for the human NPC spawn queue.
	var/mob/living/carbon/human/npc/outpost_prison_guard/guard = spawn_npc_in_zone(record.guard_type, spot, context, FALSE)
	guard.join(src, record)
	context.finalize()
	record.away_left = 0
	guard.arrive()
	// A cleanbot lost since the last change of shift comes in with this one
	keep_cleanbot(spot)
	if(isnull(guard_rounds_left))
		guard_rounds_left = rand(OUTPOST_GUARD_ROUNDS_GAP_MIN, OUTPOST_GUARD_ROUNDS_GAP_MAX) / (1 SECONDS)
	return guard

/// Takes a guard off the roster (the admin panel's hook): they say `context` and go off shift
/datum/outpost_prison/proc/dismiss_guard(datum/outpost_guard_record/record, context = "dismissed")
	if(!record || record.dismissed)
		return FALSE
	record.dismissed = TRUE
	guard_records -= record
	var/mob/living/carbon/human/npc/outpost_prison_guard/guard = record.guard
	record.guard = null
	if(guard)
		guard.record = null
		guard.leave(context)
	qdel(record)
	return TRUE

// ===== TIME =====

/**
 * Advances the guards by `seconds`: the roster, whoever is due on shift, the downed and the dead, those
 * going off shift, the rounds clock, and every OUTPOST_GUARD_CHECK_SECONDS the leash, greetings and
 * reports, and the yard saying hello; then the cleanbot and the response dispatcher.
 */
/datum/outpost_prison/proc/guards_tick(seconds)
	keep_guard_roster()
	if(!length(guard_records) && !length(guard_mobs))
		return
	// Whoever is due comes on shift, with or without anyone there to see it
	for(var/datum/outpost_guard_record/record as anything in guard_records.Copy())
		if(record.guard)
			continue
		record.away_left = max(0, record.away_left - seconds)
		if(record.away_left <= 0)
			spawn_guard(record)
	for(var/mob/living/carbon/human/npc/outpost_prison_guard/guard in guard_mobs.Copy())
		if(QDELETED(guard))
			continue
		switch(guard.phase)
			if(OUTPOST_GUARD_DOWN)
				guard_down_tick(guard, seconds)
			if(OUTPOST_GUARD_DISMISSED)
				guard.dismiss_left -= seconds
				if(guard_gone_off(guard, seconds))
					qdel(guard)
			if(OUTPOST_GUARD_PRESENT)
				guard.shake_off_pull()
				if(guard.fresh_on_shift && !(get_turf(guard) in staff_closet_turfs))
					guard.announce_arrival()
				// Bad air in the wing (a breach, a fire): guards carry no air of their own, so they go off shift
				// until the wing is fit to stand in again (spawn_guard()).
				if(guard.stat == CONSCIOUS && outpost_prison_unsafe_air(guard.loc?.return_air()))
					guard.say_guard("recalled")
					add_log("[guard.real_name] was called off the wing: bad air.")
					guard.go_off(OUTPOST_GUARD_SHIFT_SWAP_TIME / (1 SECONDS))
	guard_rounds_tick(seconds)
	guard_check_clock += seconds
	if(guard_check_clock >= OUTPOST_GUARD_CHECK_SECONDS)
		guard_check_clock = 0
		guard_leash_check()
		guard_greet_check()
		guard_yard_chatter()
	cleanbot_tick(seconds)
	dispatch_guards()

/// The wing is never short a guard on its books: OUTPOST_GUARD_MAX of them, with nobody hiring them
/datum/outpost_prison/proc/keep_guard_roster()
	if(!roster_kept)
		return
	var/on_books = 0
	for(var/datum/outpost_guard_record/record as anything in guard_records)
		if(!record.free && !record.dismissed)
			on_books++
	while(on_books < guard_max())
		add_guard_record()
		on_books++

/// Whether a body is in someone's hands or shut in something: dragged, carried, buckled, bagged
/proc/outpost_prison_body_held(mob/living/body)
	return !isturf(body.loc) || !!body.pulledby || !!body.buckled

/**
 * A guard who is down stays a real body: nobody takes them away. Alive, they lie there until they are
 * treated, get up on their own or die. Dead, the body is cleared once no client has been able to see it
 * for OUTPOST_PRISON_BODY_UNSEEN: never a body a player is or was in, and never one being dragged or
 * carried. Out of the wing for OUTPOST_GUARD_BODY_COLLECT_DELAY, alive or dead, they are off the roster
 * and no longer the wing's business (guard_carried_off()).
 */
/datum/outpost_prison/proc/guard_down_tick(mob/living/carbon/human/npc/outpost_prison_guard/guard, seconds)
	if(get_area(guard) != wing)
		guard.outside_seconds += seconds
		if(guard.outside_seconds >= OUTPOST_GUARD_BODY_COLLECT_DELAY / (1 SECONDS))
			guard_carried_off(guard)
		return
	guard.outside_seconds = 0
	if(guard.stat != DEAD || !bodies_cleared)
		return
	if(outpost_prison_body_held(guard) || seen_by_client(guard))
		guard.unseen_seconds = 0
		return
	guard.unseen_seconds += seconds
	if(guard.unseen_seconds < OUTPOST_PRISON_BODY_UNSEEN || guard.npc_ever_played())
		return
	add_log("[guard.real_name]'s body was taken away.")
	qdel(guard)

/**
 * A guard, down or dead, has been out of the wing for a minute: carried off. Their place on the roster goes to
 * someone new, and the body is whoever's has it: left alone, it is cleared like any human NPC's once nobody is
 * near (outpost_prison_clear_unseen()).
 */
/datum/outpost_prison/proc/guard_carried_off(mob/living/carbon/human/npc/outpost_prison_guard/guard)
	if(QDELETED(guard) || guard.prison != src)
		return FALSE
	add_log("[guard.real_name] was carried out of the wing.")
	guard_slot_vacated(guard)
	guard_mobs -= guard
	guard.prison = null
	guard.end_response(cancel_ai = FALSE)
	guard.end_activity(cancel_ai = FALSE)
	outpost_prison_clear_unseen(guard)
	return TRUE

/**
 * The slot of a guard who died or was carried off: after OUTPOST_GUARD_RETURN_TIME someone new comes on shift in
 * it, with their own name and face. An admin's extra guard is not replaced.
 */
/datum/outpost_prison/proc/guard_slot_vacated(mob/living/carbon/human/npc/outpost_prison_guard/guard)
	var/datum/outpost_guard_record/old = guard.record
	guard.record = null
	if(!old || old.guard != guard)
		return null
	old.guard = null
	if(old.dismissed)
		return null
	guard_records -= old
	var/datum/outpost_guard_record/next_up
	if(!old.free)
		next_up = new(src, old.rank, FALSE, old.guard_type)
		next_up.away_left = OUTPOST_GUARD_RETURN_TIME / (1 SECONDS)
		guard_records += next_up
	qdel(old)
	return next_up

/**
 * Whether a guard who is off shift is gone: standing in the staff closet with its door shut behind them, or,
 * the walk there given up (or nobody at the outpost for their legs to carry them), out of every client's sight.
 * In a wing with no staff closet they go from the office tile they walked to. Never a body a player is or was in.
 */
/datum/outpost_prison/proc/guard_gone_off(mob/living/carbon/human/npc/outpost_prison_guard/guard, seconds)
	if(guard.npc_ever_played() || outpost_prison_body_held(guard))
		return FALSE
	if(get_turf(guard) in staff_closet_turfs)
		if(staff_closet_player_inside() || seen_by_client(guard))
			return FALSE
		var/obj/machinery/door/airlock/door = staff_closet_door()
		if(!door || (door.density && !door.operating))
			return TRUE
		processing_work_door(door, FALSE)
		return FALSE
	if(!length(staff_closet_turfs) && guard.leave_spot && guard.loc == guard.leave_spot)
		return TRUE
	if(guard.dismiss_left > 0 && guard.stat == CONSCIOUS && guard.ai_running())
		return FALSE
	return !seen_by_client(guard)

/**
 * A guard was killed on duty. Logged with whoever last hurt them (the wing's log and the game log). The body
 * stays where it fell (guard_down_tick()), and someone new takes the slot after OUTPOST_GUARD_RETURN_TIME.
 */
/datum/outpost_prison/proc/guard_killed(mob/living/carbon/human/npc/outpost_prison_guard/guard)
	var/mob/killer = guard.lastattacker ? get_mob_by_ckey(guard.lastattackerckey) : null
	add_log("[guard.real_name] was killed on duty.")
	log_game("OUTPOST LOCKUP: '[outpost_log_name()]': guard [guard.real_name] was killed[killer ? " (last hit by [key_name(killer)])" : ""]")
	guard_slot_vacated(guard)

// ===== THE CLEANBOT =====

/// The lockup's cleanbot: tg's, with nobody able to unlock, arm or call it away, and no radio to answer a call on
/mob/living/basic/bot/cleanbot/outpost_lockup
	bot_mode_flags = BOT_MODE_ON
	radio_key = null
	radio_channel = null

/mob/living/basic/bot/cleanbot/outpost_lockup/allowed(mob/living/user)
	return isAdminGhostAI(user)

/mob/living/basic/bot/cleanbot/outpost_lockup/emag_act(mob/user, obj/item/card/emag/emag_card)
	return FALSE

/mob/living/basic/bot/cleanbot/outpost_lockup/on_attack_by(datum/source, obj/item/used_item, mob/living/user)
	SIGNAL_HANDLER
	return

/// Sends the bot to `target` without announcing "Responding." aloud on every dispatch
/mob/living/basic/bot/cleanbot/outpost_lockup/proc/send_to_mess(turf/target)
	if(!target)
		return FALSE
	bot_reset()
	ai_controller?.set_blackboard_key(BB_BOT_SUMMON_TARGET, target)
	access_card?.set_access(initial_access)
	update_bot_mode(new_mode = BOT_SUMMON)
	return TRUE

/// The wing's cleanbot, if it has one that still works
/datum/outpost_prison/proc/cleanbot()
	var/mob/living/basic/bot/cleanbot/bot = cleanbot_ref?.resolve()
	if(QDELETED(bot) || bot.stat == DEAD)
		return null
	return bot

/**
 * The wing keeps one cleanbot: tg's own, mopping the yard. It comes in with a guard coming on shift (`spot`, the
 * staff closet tile they were made on), so one that is lost is replaced at the next change of guard.
 */
/datum/outpost_prison/proc/keep_cleanbot(turf/spot)
	if(!bot_kept || !spot || cleanbot())
		return null
	var/mob/living/basic/bot/cleanbot/outpost_lockup/bot = new(spot)
	cleanbot_ref = WEAKREF(bot)
	return bot

/// Every so often an idle cleanbot is sent to the nearest reachable mess in the cell block that it cannot already see close by
/datum/outpost_prison/proc/cleanbot_tick(seconds)
	cleanbot_clock += seconds
	if(cleanbot_clock < OUTPOST_PRISON_BOT_CALL_GAP)
		return
	cleanbot_clock = 0
	var/mob/living/basic/bot/cleanbot/bot = cleanbot()
	if(!bot)
		return
	// Taken out of the lockup: it is whoever took it's now, and the next change of guard brings another
	if(wing && get_area(bot) != wing)
		cleanbot_ref = null
		return
	if(!(bot.bot_mode_flags & BOT_MODE_ON))
		bot.turn_on()
	if(bot.mode != BOT_IDLE || bot.client || !has_audience())
		return
	var/turf/nearest
	var/nearest_distance = INFINITY
	for(var/turf/tile as anything in cell_block)
		if(isclosedturf(tile) || !cell_block_passable(tile))
			continue
		var/datum/outpost_prison_cell/cell = cell_at(tile)
		var/obj/machinery/door/airlock/cell_door = cell?.door()
		if(cell_door && cell_door.density && (cell_door.locked || cell_door.welded || !cell_door.hasPower()))
			continue
		var/obj/effect/decal/cleanable/mess = locate() in tile
		if(!mess || istype(mess, /obj/effect/decal/cleanable/crayon) || istype(mess, /obj/effect/decal/cleanable/cobweb))
			continue
		var/distance = get_dist(bot, tile)
		if(distance < nearest_distance)
			nearest = tile
			nearest_distance = distance
	// Close by and in sight, it finds the mess with its own eyes
	if(!nearest || (nearest in view(3, bot)))
		return
	var/mob/living/basic/bot/cleanbot/outpost_lockup/lockup_bot = bot
	if(istype(lockup_bot))
		lockup_bot.send_to_mess(nearest)
	else
		bot.summon_bot(bot, nearest)

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
	for(var/mob/living/carbon/human/npc/outpost_prison_guard/guard in shuffle(guard_mobs))
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
 * The leash: a guard on their feet off the wing's level is recalled at once; one out of the wing for
 * OUTPOST_GUARD_LEASH_SECONDS walks back, or with nobody about to see it (or still out after
 * twice that), is recalled: off shift, and back after OUTPOST_GUARD_OFF_LEVEL_AWAY.
 */
/datum/outpost_prison/proc/guard_leash_check()
	var/z = wing_z()
	for(var/mob/living/carbon/human/npc/outpost_prison_guard/guard in guard_mobs)
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
 * Hands out responses and runs them, once a second, for guards whose AI runs. A riot gives
 * everyone the riot doctrine; otherwise each incident (a
 * hatch climb, a fight, an argument, a threat), most urgent first, goes to the nearest free guard,
 * one guard each. Spats are stopped from where the guard stands, and loose prisoners are called
 * out and batoned if they come close. Then every guard deals with their response.
 */
/datum/outpost_prison/proc/dispatch_guards()
	var/list/on_duty = list()
	for(var/mob/living/carbon/human/npc/outpost_prison_guard/guard in guard_mobs)
		if(guard.on_duty() && guard.ai_running())
			on_duty += guard
	if(!riot_active)
		guard_riot_announced = FALSE
	if(!length(on_duty))
		return
	if(riot_active)
		for(var/mob/living/carbon/human/npc/outpost_prison_guard/guard as anything in on_duty)
			if(guard.response?.kind == "riot")
				continue
			guard.give_response("riot", OUTPOST_GUARD_PRIORITY_RIOT, "riot", null, null)
			guard.say_guard("riot_call")
	else
		assign_guard_incidents(on_duty)
		guard_stop_spat(on_duty)
	guard_watch_loose(on_duty)
	for(var/mob/living/carbon/human/npc/outpost_prison_guard/guard as anything in on_duty)
		guard.perform_response()

/**
 * The wing's incidents that want a guard, most urgent first: list(key, kind, priority, prisoner).
 * Hatch climbs, fights with blows, arguments, then prisoners squaring up to someone, swinging, or
 * who just struck someone.
 */
/datum/outpost_prison/proc/guard_incidents()
	var/list/found = list()
	for(var/mob/living/carbon/human/npc/outpost_prisoner/prisoner in prisoners)
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
		for(var/mob/living/carbon/human/npc/outpost_prison_guard/guard as anything in on_duty)
			if(guard.response?.key == key)
				handled = TRUE
				// A fight's priority rises once blows fly.
				guard.response.priority = max(guard.response.priority, incident[3])
				break
		if(handled)
			continue
		var/mob/living/carbon/human/npc/outpost_prisoner/prisoner = incident[4]
		var/atom/where = prisoner
		var/turf/spot
		if(incident[2] == "climb")
			var/obj/structure/table/reinforced/prison_hatch/hatch = prisoner.climb_ref?.resolve()
			spot = hatch?.staff_side_turf()
			where = spot || prisoner
		var/mob/living/carbon/human/npc/outpost_prison_guard/best
		for(var/mob/living/carbon/human/npc/outpost_prison_guard/guard as anything in on_duty)
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
	var/mob/living/carbon/human/npc/outpost_prisoner/one = spat_first_ref?.resolve()
	var/mob/living/carbon/human/npc/outpost_prisoner/two = spat_second_ref?.resolve()
	for(var/mob/living/carbon/human/npc/outpost_prison_guard/guard as anything in on_duty)
		if(guard.response)
			continue
		var/list/seen = view(OUTPOST_GUARD_SPAT_VIEW, guard)
		var/mob/living/carbon/human/npc/outpost_prisoner/speaker = (one && (one in seen)) ? one : ((two && (two in seen)) ? two : null)
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
	for(var/mob/living/carbon/human/npc/outpost_prisoner/prisoner in prisoners)
		if(prisoner.trouble != PRISONER_TROUBLE_LOOSE || prisoner.phase != PRISONER_PRESENT || prisoner.stat != CONSCIOUS)
			continue
		var/key = REF(prisoner)
		called[key] = TRUE
		if(!guard_loose_called[key])
			// Said aloud, and noted in the warden's log
			var/mob/living/carbon/human/npc/outpost_prison_guard/crier = pick(on_duty)
			if(crier.say_guard("loose_call", list("{place}" = get_area_name(prisoner))))
				add_log("[crier.real_name]: \"[crier.last_line]\"")
		if(prisoner.can_be_dragged())
			continue
		for(var/mob/living/carbon/human/npc/outpost_prison_guard/guard as anything in on_duty)
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
	for(var/mob/living/carbon/human/npc/outpost_prisoner/runner as anything in runners)
		first_names += runner.speech_name()
		full_names += runner.real_name
		places |= get_area_name(runner)
	// Every line says where they were last seen
	var/list/values = list("{prisoner}" = english_list(first_names), "{place}" = english_list(places))
	var/list/on_duty = list()
	for(var/mob/living/carbon/human/npc/outpost_prison_guard/guard in guard_mobs)
		if(guard.on_duty())
			on_duty += guard
	if(length(on_duty))
		var/mob/living/carbon/human/npc/outpost_prison_guard/crier = pick(on_duty)
		if(crier.say_guard("loose_nearly", values))
			add_log("[crier.real_name]: \"[crier.last_line]\"")
			announce("[crier.real_name]: \"[crier.last_line]\"", SHIP_NOTIFY_DANGER)
			return TRUE
	announce("Prison wing: [english_list(full_names)] [length(runners) == 1 ? "is" : "are"] about to get away.", SHIP_NOTIFY_DANGER)
	return TRUE

/// The riot hold is called out once a riot: said aloud, and noted in the warden's log
/datum/outpost_prison/proc/announce_riot_hold(mob/living/carbon/human/npc/outpost_prison_guard/guard)
	if(guard_riot_announced)
		return FALSE
	guard_riot_announced = TRUE
	if(!guard.say_guard("riot_hold"))
		return FALSE
	add_log("[guard.real_name]: \"[guard.last_line]\"")
	return TRUE

/// Every prisoner who sees a baton strike loses OUTPOST_GUARD_ONLOOKER_MOOD, at most once per OUTPOST_GUARD_ONLOOKER_GAP each; one may say so
/datum/outpost_prison/proc/guard_strike_seen(mob/living/carbon/human/npc/outpost_prisoner/struck, mob/living/carbon/human/npc/outpost_prison_guard/guard)
	var/list/watchers = list()
	for(var/mob/living/carbon/human/npc/outpost_prisoner/onlooker in view(OUTPOST_GUARD_ONLOOKER_RANGE, struck))
		if(onlooker == struck || onlooker.prison != src || onlooker.stat != CONSCIOUS || onlooker.phase != PRISONER_PRESENT)
			continue
		if(onlooker.guard_onlooker_at && world.time - onlooker.guard_onlooker_at < OUTPOST_GUARD_ONLOOKER_GAP)
			continue
		onlooker.guard_onlooker_at = world.time
		onlooker.adjust_mood(-OUTPOST_GUARD_ONLOOKER_MOOD)
		watchers += onlooker
	if(length(watchers) && prob(50))
		var/mob/living/carbon/human/npc/outpost_prisoner/speaker = pick(watchers)
		INVOKE_ASYNC(speaker, TYPE_PROC_REF(/mob/living/carbon/human/npc/outpost_prisoner, say_context_with), "guard_batoned", list("{staff}" = guard.real_name))
	return watchers

// ===== STAFF, GREETINGS AND REPORTS =====

/// The wing's staff (is_staff()) awake and playing at the outpost: the people a guard answers to
/datum/outpost_prison/proc/guard_members_about()
	var/list/members = list()
	for(var/mob/living/person in wing_clients())
		if(QDELETED(person) || !person.client || person.stat != CONSCIOUS || is_outpost_prisoner(person))
			continue
		if(is_staff(person))
			members += person
	return members

/// One of the wing's staff in the cell block, for the riot doctrine
/datum/outpost_prison/proc/guard_member_in_cell_block()
	for(var/mob/living/member as anything in guard_members_about())
		if(in_cell_block(member))
			return member
	return null

/// A rioter on their feet beside `member`, if any
/datum/outpost_prison/proc/rioter_beside(mob/living/member)
	for(var/mob/living/carbon/human/npc/outpost_prisoner/rioter in orange(1, member))
		if(rioter.prison == src && rioter.is_rioting() && rioter.stat == CONSCIOUS && !rioter.can_be_dragged())
			return rioter
	return null

/// What a guard calls someone they answer to: their first name, "boss" when masked
/datum/outpost_prison/proc/guard_boss_name(mob/living/member)
	if(!member)
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
	for(var/mob/living/carbon/human/npc/outpost_prisoner/prisoner in prisoners)
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
		for(var/mob/living/carbon/human/npc/outpost_prison_guard/guard in guard_mobs)
			if(!guard.on_duty() || guard.response || get_dist(guard, member) > OUTPOST_GUARD_REPORT_RANGE || !(member in view(OUTPOST_GUARD_REPORT_RANGE, guard)))
				continue
			if(guard.greet_member(member))
				break

/**
 * Greets `member` if it is time, else reports to them if it is time. Returns TRUE if they said
 * something.
 */
/mob/living/carbon/human/npc/outpost_prison_guard/proc/greet_member(mob/living/member)
	if(!prison || !on_duty())
		return FALSE
	var/key = member.ckey || REF(member)
	var/boss = prison.guard_boss_name(member)
	var/greeted_at = prison.guard_greeted[key]
	if(!greeted_at || world.time - greeted_at >= OUTPOST_GUARD_GREET_GAP)
		prison.guard_greeted[key] = world.time
		face_atom(member)
		if(say_guard("greet_member", list("{boss}" = boss)))
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
	for(var/mob/living/carbon/human/npc/outpost_prison_guard/guard in shuffle(guard_mobs))
		if(!guard.on_duty() || !guard.ai_running())
			continue
		for(var/mob/living/carbon/human/npc/outpost_prisoner/prisoner in view(OUTPOST_GUARD_NOTICE_RANGE, guard))
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

/// Staff doors that open onto the cell block: the ones the guards hold in a riot and stand post beside. Not Processing's.
/datum/outpost_prison/proc/guard_yard_doors()
	var/list/doors = list()
	for(var/turf/tile as anything in staff_door_turfs)
		if(cell_block[tile] && !(locate(/obj/machinery/door/airlock/security/prison_staff/processing) in tile))
			doors += tile
	return doors

/**
 * The office: the staff side's open ground a guard can walk to from the yard's staff doors without passing
 * another door. A mapped lockup's staff side also holds the front room, Processing and the staff closet, which
 * are no place for a guard's post. Found once, and again when the wing's layout changes.
 */
/datum/outpost_prison/proc/office_ground()
	if(office_cache)
		return office_cache
	var/list/found = list()
	var/list/queue = list()
	for(var/turf/door_tile as anything in guard_yard_doors())
		for(var/direction in GLOB.cardinals)
			var/turf/beside = get_step(door_tile, direction)
			if(beside && staff_ground?[beside] && !found[beside] && !(locate(/obj/machinery/door) in beside))
				found[beside] = TRUE
				queue += beside
	var/index = 1
	while(index <= length(queue))
		var/turf/current = queue[index++]
		for(var/direction in GLOB.cardinals)
			var/turf/next = get_step(current, direction)
			if(!next || found[next] || !staff_ground?[next] || (locate(/obj/machinery/door) in next))
				continue
			found[next] = TRUE
			queue += next
	// A wing with no staff door onto the cell block: the whole staff side
	if(!length(found))
		if(!length(staff_ground))
			return found
		found = staff_ground.Copy()
	office_cache = found
	return office_cache

/// The staff closet's door, or null
/datum/outpost_prison/proc/staff_closet_door()
	for(var/turf/tile as anything in staff_closet_turfs)
		for(var/direction in GLOB.cardinals)
			var/turf/beside = get_step(tile, direction)
			if(!beside || (beside in staff_closet_turfs))
				continue
			var/obj/machinery/door/airlock/door = locate() in beside
			if(door)
				return door
	return null

/// Everyone in the staff closet, including anyone shut in a crate, locker or mech
/datum/outpost_prison/proc/staff_closet_occupants()
	. = list()
	for(var/turf/tile as anything in staff_closet_turfs)
		. |= tile.get_all_contents_type(/mob/living)

/// Whether a player is in the staff closet: nobody is made or taken away around one
/datum/outpost_prison/proc/staff_closet_player_inside()
	for(var/mob/living/person as anything in staff_closet_occupants())
		if(person.client || person.mind)
			return TRUE
	return FALSE

/**
 * Where a guard coming on shift is made: a tile of the staff closet with nobody on it, no player inside and no
 * client able to see it, and only while the closet's door is shut (an open one is asked to close first). A wing
 * with no staff closet: the office.
 */
/datum/outpost_prison/proc/guard_arrival_spot()
	if(!length(staff_closet_turfs))
		return guard_office_spot()
	var/obj/machinery/door/airlock/door = staff_closet_door()
	if(door && !(door.density && !door.operating))
		processing_work_door(door, FALSE)
		return null
	if(staff_closet_player_inside())
		return null
	for(var/turf/tile as anything in staff_closet_turfs)
		if(tile.is_blocked_turf(TRUE) || seen_by_client(tile))
			continue
		if(!length(tile.get_all_contents_type(/mob/living/carbon)))
			return tile
	return null

/// Where a guard going off shift walks to: a tile of the staff closet, or the office in a wing with none
/datum/outpost_prison/proc/guard_leave_spot(mob/living/except)
	for(var/turf/tile as anything in staff_closet_turfs)
		if(tile.is_blocked_turf(TRUE))
			continue
		var/taken = FALSE
		for(var/mob/living/carbon/person as anything in tile.get_all_contents_type(/mob/living/carbon))
			if(person != except)
				taken = TRUE
				break
		if(!taken)
			return tile
	return guard_office_spot(except)

/// Whether a guard could stand on an office tile: open, nothing solid on it, no door
/datum/outpost_prison/proc/guard_office_tile(turf/tile)
	return isopenturf(tile) && tile.loc == wing && office_ground()[tile] && !tile.is_blocked_turf(TRUE) && !(locate(/obj/machinery/door) in tile)

/// Whether a guard could stand on a tile of the yard: in the cell block, not in a cell, open, nothing solid, no door
/datum/outpost_prison/proc/guard_yard_tile(turf/tile)
	return isopenturf(tile) && tile.loc == wing && cell_block[tile] && !cell_at(tile) && !tile.is_blocked_turf(TRUE) && !(locate(/obj/machinery/door) in tile)

/// Whether someone other than `except` stands on a tile, or another guard means to
/datum/outpost_prison/proc/guard_spot_taken(turf/tile, mob/living/except)
	for(var/mob/living/other in tile)
		if(other != except && other.density)
			return TRUE
	for(var/mob/living/carbon/human/npc/outpost_prison_guard/guard in guard_mobs)
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

/// A free office tile near the staff door: where guards go when told to keep clear
/datum/outpost_prison/proc/guard_office_spot(mob/living/except)
	var/atom/anchor
	var/list/doors = guard_yard_doors()
	if(length(doors))
		anchor = doors[1]
	var/turf/best
	var/best_distance = INFINITY
	for(var/turf/tile as anything in office_ground())
		if(!guard_office_tile(tile) || guard_spot_taken(tile, except))
			continue
		var/distance = anchor ? get_dist(anchor, tile) : 0
		if(distance < best_distance)
			best = tile
			best_distance = distance
	return best


/// The office tile farthest from the staff doors into the cell block, for a hurt guard to fall back to
/datum/outpost_prison/proc/guard_fallback_spot(mob/living/except)
	var/list/doors = guard_yard_doors()
	var/turf/best
	var/best_distance = -1
	for(var/turf/tile as anything in office_ground())
		if(!guard_office_tile(tile) || guard_spot_taken(tile, except))
			continue
		var/nearest_door = INFINITY
		for(var/turf/door as anything in doors)
			nearest_door = min(nearest_door, get_dist(door, tile))
		if(nearest_door > best_distance)
			best = tile
			best_distance = nearest_door
	return best

// ===== THE ADMIN PANEL =====

/// The admin panel's guards: list of {ref, name, health, status, activity, response}
/datum/outpost_prison/proc/guards_admin_payload()
	var/list/rows = list()
	for(var/datum/outpost_guard_record/record as anything in guard_records)
		var/mob/living/carbon/human/npc/outpost_prison_guard/guard = record.guard
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
				dismiss_guard(record, "dismissed")
				return "remove prison guard [guard_name]"
			var/mob/living/carbon/human/npc/outpost_prison_guard/guard = record.guard
			if(!guard?.on_duty())
				return list("error" = "That guard is not on duty.")
			// Real damage over their limbs, enough to put them in crit; tg's crit does the rest.
			guard.take_overall_damage(brute = max(0, guard.health) + 5)
			if(guard.phase != OUTPOST_GUARD_DOWN)
				guard.go_down()
			return "put prison guard [guard_name] down"
	return null

// ===== LIFE AND DEATH OF THE PRISON =====

/datum/outpost_prison/proc/guards_destroy()
	for(var/mob/living/carbon/human/npc/outpost_prison_guard/guard in guard_mobs.Copy())
		if(QDELETED(guard))
			continue
		guard.prison = null
		guard.record = null
		qdel(guard)
	guard_mobs.Cut()
	for(var/datum/outpost_guard_record/record as anything in guard_records)
		record.guard = null
	QDEL_LIST(guard_records)
	guard_greeted.Cut()
	guard_reported.Cut()
	guard_loose_called.Cut()
	var/mob/living/basic/bot/cleanbot/bot = cleanbot_ref?.resolve()
	cleanbot_ref = null
	if(!QDELETED(bot))
		qdel(bot)
	office_cache = null

// ===== LOOK =====

/**
 * A corrections officer: pale blue shirt and tie over navy trousers, a blue-trimmed vest and helmet,
 * black gloves and combat boots, and an earpiece. No red, no orange (that's the inmates). The stun
 * baton rides on the belt and is drawn only when they use it (set_baton()); a bruise pack in a pocket
 * for their own scrapes. Locked to them (D3): none of it is ever loot.
 */
/datum/outfit/outpost_prison_guard
	name = "Outpost prison guard"
	uniform = /obj/item/clothing/under/rank/security/officer/blueshirt
	suit = /obj/item/clothing/suit/armor/vest/blueshirt
	head = /obj/item/clothing/head/helmet/blueshirt
	gloves = /obj/item/clothing/gloves/color/black
	shoes = /obj/item/clothing/shoes/jackboots
	ears = /obj/item/radio/headset
	belt = /obj/item/melee/baton/security/loaded
	r_pocket = /obj/item/stack/medical/bruise_pack

#undef OUTPOST_GUARD_DIALOGUE_FILE
