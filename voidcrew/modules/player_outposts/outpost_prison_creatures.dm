/**
 * # Experiment creatures
 *
 * What a serum turns a prisoner into, with tg's looks and mechanics where tg has them:
 * - The hulk: a green, swollen prisoner (tg's hulk skin). Punches hard, charges with a 1.5 second
 *   wind-up and a line on the floor, stuns itself on a wall, tears through interior walls (tg's
 *   wall_tearer, limited to the outpost's inside) and forces doors. It knocks prisoners flat but
 *   never kills them. Worn down to a quarter it is exhausted, and a baton or disabler puts it down
 *   alive for a bigger bonus.
 * - The fly person: tg's fly species, flying. It zips about the wing in short random darts, darts
 *   away from anyone close and from whoever just hit it, and jinks out of the way of some shots while
 *   it flies freely. Cornered, it bites. It eats whatever food it finds and throws up every few
 *   seconds. A flyswatter hits it thirty times harder, as it does tg's fly people; a baton knocks it
 *   to the floor for a moment, and stamina weapons slow it down and then put it down alive.
 * - The nightmare: tg's nightmare with its light eater. It spends its first half minute breaking
 *   the lights, then hunts prisoners in the dark. It heals and dodges in the dark and burns in the
 *   light, jaunts beside a target through the dark after a warning ripple, and a flash burns it.
 * Before the change, the dosed prisoner shows the form's tells (outpost_experiment_tell()). Put
 * down, alive or dead, a creature lies on the floor where everyone can see it (show_down()), a
 * subdued one twitching, until Kessler's team beams in for it (kessler_collect()).
 *
 * All of them are basic mobs under /mob/living/basic/outpost_experiment, never megafauna, with no
 * sentience, no need for air, and no way to be boxed, teleported, polymorphed or revived. They
 * only break the outpost's interior (outpost_experiment_can_smash()). Their AI runs only while
 * someone is on the level, like everything else in the wing.
 */

/// The creature a serum form becomes
/proc/outpost_experiment_creature_type(form)
	switch(form)
		if("hulk")
			return /mob/living/basic/outpost_experiment/hulk
		if("fly")
			return /mob/living/basic/outpost_experiment/fly
		if("nightmare")
			return /mob/living/basic/outpost_experiment/nightmare
	return null

/// Living players on level `z` beyond the first, up to OUTPOST_EXPERIMENT_EXTRA_PLAYERS_MAX, for a creature's health
/proc/outpost_experiment_extra_players(z)
	if(!z || z > length(SSmobs.clients_by_zlevel))
		return 0
	var/count = 0
	for(var/mob/living/person as anything in SSmobs.clients_by_zlevel[z])
		if(QDELETED(person) || person.stat == DEAD || !person.client || is_outpost_prisoner(person) || is_outpost_experiment_mob(person))
			continue
		count++
	return clamp(count - 1, 0, OUTPOST_EXPERIMENT_EXTRA_PLAYERS_MAX)

// ===== TELLS =====

/**
 * One tell of what the serum is turning `subject` into, `progress` (0 to 1) through the last
 * OUTPOST_EXPERIMENT_TELLS seconds. Plain to see, so the crew can fetch the right tool.
 */
/proc/outpost_experiment_tell(form, mob/living/basic/outpost_prisoner/subject, progress)
	if(QDELETED(subject) || subject.stat != CONSCIOUS)
		return
	subject.Shake(1, 1, 0.5 SECONDS)
	switch(form)
		if("hulk")
			// Veins go green and they swell, a little more each time.
			var/pale = round(255 - 110 * progress)
			subject.add_atom_colour(rgb(pale, 255, pale), TEMPORARY_COLOUR_PRIORITY)
			var/wanted = 1 + 0.15 * progress
			if(subject.current_size < wanted)
				subject.update_transform(wanted / subject.current_size)
			if(prob(50))
				subject.manual_emote(pick("grunts and punches the wall.", "flexes, and green veins stand out on [subject.p_their()] arms.", "grinds [subject.p_their()] teeth and snarls."))
				playsound(subject, 'sound/items/weapons/punch1.ogg', 40, TRUE)
			else
				subject.say_context("experiment_dose")
		if("fly")
			playsound(subject, 'sound/mobs/non-humanoids/bee/bee.ogg', 35, TRUE)
			if(prob(35) && isturf(subject.loc))
				subject.manual_emote("retches.")
				playsound(subject, pick('sound/mobs/humanoids/human/gag_vomit/gag1.ogg', 'sound/mobs/humanoids/human/gag_vomit/gag2.ogg'), 40, TRUE)
				new /obj/effect/decal/cleanable/vomit(subject.loc)
			else
				subject.manual_emote(pick("buzzes.", "rubs [subject.p_their()] hands together, fast.", "stares with bulging, glittering eyes.", "twitches all over."))
		if("nightmare")
			for(var/obj/machinery/light/fixture in range(4, subject))
				if(fixture.status == LIGHT_OK && prob(60))
					fixture.flicker(rand(3, 6))
			subject.add_filter("outpost_nightmare_tell", 2, list("type" = "outline", "color" = "#000000aa", "size" = progress > 0.5 ? 2 : 1))
			subject.manual_emote(pick("flinches away from the light.", "whispers to nobody.", "shades [subject.p_their()] eyes.", "stands very still in the dark."))
			playsound(subject, pick('sound/effects/hallucinations/i_see_you1.ogg', 'sound/effects/hallucinations/behind_you1.ogg'), 20, TRUE)

/// Takes the tells off a subject the serum never finished with
/proc/outpost_experiment_clear_tells(mob/living/basic/outpost_prisoner/subject)
	if(QDELETED(subject))
		return
	subject.remove_atom_colour(TEMPORARY_COLOUR_PRIORITY)
	subject.remove_filter("outpost_nightmare_tell")
	if(subject.current_size != RESIZE_DEFAULT_SIZE)
		subject.update_transform(RESIZE_DEFAULT_SIZE / subject.current_size)

// ===== THE CREATURE =====

/// What a prisoner turned into. Kept at home and out of players' hands; see the file header.
/mob/living/basic/outpost_experiment
	name = "experiment"
	desc = "What a prisoner turned into."
	icon = 'icons/mob/simple/simple_human.dmi'
	mob_biotypes = MOB_ORGANIC | MOB_HUMANOID
	sentience_type = OUTPOST_EXPERIMENT_NO_SENTIENCE
	faction = list(FACTION_OUTPOST_EXPERIMENT)
	basic_mob_flags = NONE
	status_flags = CANPUSH
	move_resist = MOVE_FORCE_STRONG
	mob_size = MOB_SIZE_HUMAN
	density = TRUE
	combat_mode = TRUE
	blood_volume = BLOOD_VOLUME_NORMAL
	unsuitable_atmos_damage = 0
	unsuitable_cold_damage = 0
	unsuitable_heat_damage = 0
	damage_coeff = list(BRUTE = 1, BURN = 1, TOX = 0, STAMINA = 0, OXY = 0)
	environment_smash = ENVIRONMENT_SMASH_NONE
	ai_controller = /datum/ai_controller/basic_controller/outpost_experiment
	// tg's human deathgasp
	death_message = "seizes up and falls limp, their eyes dead and lifeless..."
	// Knocked down, subdued or dead, it lies on the floor like a person.
	mobility_flags = MOBILITY_FLAGS_REST_CAPABLE_DEFAULT
	rotate_on_lying = TRUE
	/// What the log calls it: "a hulk"
	var/form_name = "a creature"
	/// What everyone sees when it is subdued, after its name
	var/subdued_message = "collapses, spent."
	/// A tell on examine, if any: something anyone watching it would notice
	var/win_hint
	/// Health with one player on the level, and per extra player
	var/base_health = 100
	var/health_per_player = 0
	/// Dialogue context it says now and then, and seconds to the next line
	var/line_context
	var/line_left = 10
	/// The prison it came from
	var/datum/outpost_prison/prison
	/// The prisoner's personality, for its lines
	var/personality
	/// Put down alive
	var/subdued = FALSE
	/// Its footsteps: the footstep element's sound set, volume multiplier and extra range
	var/footstep_kind = FOOTSTEP_MOB_SHOE
	var/footstep_volume = 0.5
	var/footstep_range = -8
	/// The target it is chasing now, the closest it has gotten to it, where it last stood, and when it last
	/// got anywhere: to notice it is stuck (track_reach())
	var/datum/weakref/chase_target_ref
	var/chase_best_distance = 0
	var/turf/chase_last_turf
	var/chase_progress_time = 0
	/// Targets it has given up on reaching -> world.time it may try them again (find_light(), choose_target())
	var/list/unreachable_until

/mob/living/basic/outpost_experiment/Initialize(mapload, datum/outpost_prison/owner, mob/living/basic/outpost_prisoner/subject)
	if(subject)
		gender = subject.gender
	. = ..()
	prison = owner
	damage_coeff = damage_coeff.Copy()
	if(subject)
		personality = subject.personality
		real_name = subject.real_name
		name = real_name
	ADD_TRAIT(src, TRAIT_NO_CONTAINMENT, INNATE_TRAIT)
	ADD_TRAIT(src, TRAIT_NO_STORAGE_INSERT, INNATE_TRAIT)
	RegisterSignal(src, COMSIG_MOVABLE_TELEPORTING, PROC_REF(refuse_teleport))
	RegisterSignal(src, COMSIG_LIVING_PRE_WABBAJACKED, PROC_REF(refuse_polymorph))
	RegisterSignal(src, COMSIG_PRE_MOB_CHANGED_TYPE, PROC_REF(refuse_type_change))
	AddComponent(/datum/component/experiment_damage_ledger)
	AddElement(/datum/element/footstep, footstep_type = footstep_kind, volume = footstep_volume, e_range = footstep_range)
	var/turf/here = get_turf(src)
	var/full_health = base_health + health_per_player * outpost_experiment_extra_players(here?.z)
	maxHealth = full_health
	health = full_health
	build_look(subject?.outfit_path || /datum/outfit/outpost_prisoner)

/mob/living/basic/outpost_experiment/Destroy()
	prison = null
	chase_target_ref = null
	chase_last_turf = null
	unreachable_until = null
	return ..()

/// Puts on its look, from the prisoner's outfit
/mob/living/basic/outpost_experiment/proc/build_look(outfit_path)
	apply_dynamic_human_appearance(src, outfit_path, /datum/species/human)

/mob/living/basic/outpost_experiment/proc/refuse_teleport(datum/source, atom/destination, channel)
	SIGNAL_HANDLER
	if(isturf(loc))
		visible_message(span_notice("[src] flickers for a moment, but stays where [p_they()] [p_are()]."))
	return TRUE

/mob/living/basic/outpost_experiment/proc/refuse_polymorph(datum/source, what_to_randomize)
	SIGNAL_HANDLER
	visible_message(span_notice("[src] shimmers for a moment, then looks the same as before."))
	return STOP_WABBAJACK

/mob/living/basic/outpost_experiment/proc/refuse_type_change(datum/source)
	SIGNAL_HANDLER
	return COMPONENT_BLOCK_MOB_CHANGE

/// Kessler has already written it off: nothing brings it back
/mob/living/basic/outpost_experiment/can_be_revived()
	return FALSE

/// Down for good, its body can be dragged about until Kessler collects it
/mob/living/basic/outpost_experiment/death(gibbed)
	. = ..()
	move_resist = MOVE_RESIST_DEFAULT
	if(. && !gibbed && !QDELETED(src))
		show_down(FALSE)

/mob/living/basic/outpost_experiment/examine(mob/user)
	. = ..()
	if(HAS_TRAIT_FROM(src, TRAIT_GODMODE, OUTPOST_KESSLER_TRAIT))
		. += span_notice("Kessler Biolabs is taking [p_them()] away.")
	else if(subdued || stat == DEAD)
		. += span_notice("[p_They()] [p_are()] down. Kessler Biolabs will collect [p_them()] shortly.")
	else if(win_hint)
		. += span_notice(win_hint)

/**
 * Put down: everyone in sight is told, with a balloon over it. `subdued` is alive (the death
 * message has already said the rest); it lies there twitching until Kessler collects it (Life()).
 */
/mob/living/basic/outpost_experiment/proc/show_down(subdued)
	if(subdued)
		visible_message(span_danger("[src] [subdued_message]"))
	balloon_alert_to_viewers(subdued ? "subdued" : "dead")

/// Twitches on the floor, subdued, waiting for Kessler
/mob/living/basic/outpost_experiment/proc/down_twitch()
	Shake(1, 0, 0.4 SECONDS)
	if(prob(30))
		manual_emote(pick("twitches.", "groans.", "stirs weakly."))

/// Health it still had, which a gib or dust takes without it counting as damage on its ledger
/mob/living/basic/outpost_experiment/proc/unspent_health()
	return health

/**
 * Interim turret rule (outpost_prison_riot.dm): outpost turrets shoot a creature wherever it is,
 * until it is dead, subdued or in Kessler's hands. Turret damage is not the crew's, so a turret
 * kill pays no containment bonus.
 */
/mob/living/basic/outpost_experiment/proc/turret_target()
	return stat != DEAD && !subdued && !HAS_TRAIT(src, TRAIT_GODMODE)

/proc/is_outpost_experiment_turret_target(mob/living/creature)
	var/mob/living/basic/outpost_experiment/experiment_creature = creature
	return istype(experiment_creature) && experiment_creature.turret_target()

/// Whether its AI runs: only while someone is on the level
/mob/living/basic/outpost_experiment/proc/awake()
	return ai_controller?.ai_status == AI_STATUS_ON

/mob/living/basic/outpost_experiment/Life(seconds_per_tick = SSMOBS_DT, times_fired)
	. = ..()
	if(subdued && stat != DEAD && !HAS_TRAIT_FROM(src, TRAIT_GODMODE, OUTPOST_KESSLER_TRAIT) && !QDELETED(src))
		if(prob(60))
			down_twitch()
		return
	if(stat == DEAD || subdued || HAS_TRAIT(src, TRAIT_GODMODE) || !awake())
		return
	creature_life(seconds_per_tick)
	if(!line_context)
		return
	line_left -= seconds_per_tick
	if(line_left <= 0)
		line_left = rand(15, 25)
		var/line = outpost_experiment_line(line_context, personality)
		if(line)
			INVOKE_ASYNC(src, TYPE_PROC_REF(/atom/movable, say), line)

/// Each second while awake: what it does besides fighting
/mob/living/basic/outpost_experiment/proc/creature_life(seconds_per_tick)
	return

/**
 * Worn out on stamina: down alive on the floor, held there, and the containment bonus for a live
 * one. Kessler's team comes for it OUTPOST_EXPERIMENT_PICKUP seconds later.
 */
/mob/living/basic/outpost_experiment/proc/subdue()
	if(subdued || stat == DEAD)
		return FALSE
	subdued = TRUE
	move_resist = MOVE_RESIST_DEFAULT
	ADD_TRAIT(src, TRAIT_INCAPACITATED, OUTPOST_KESSLER_TRAIT)
	ADD_TRAIT(src, TRAIT_IMMOBILIZED, OUTPOST_KESSLER_TRAIT)
	ADD_TRAIT(src, TRAIT_FLOORED, OUTPOST_KESSLER_TRAIT)
	ai_controller?.CancelActions()
	show_down(TRUE)
	prison?.experiment_creature_down(src, subdued = TRUE)
	return TRUE

/mob/living/basic/outpost_experiment/received_stamina_damage(current_level, amount_actual, amount)
	. = ..()
	if(has_status_effect(/datum/status_effect/incapacitating/stamcrit))
		subdue()

// ----- targets -----

/// Whether it goes after `target`. By default only its victims (is_victim()); the fly adds food, the nightmare lights.
/mob/living/basic/outpost_experiment/proc/can_target(atom/target)
	return is_victim(target)

/// People, borgs and prisoners, never its own kind or Kessler's staff
/mob/living/basic/outpost_experiment/proc/is_victim(atom/target)
	var/mob/living/victim = target
	if(!istype(victim) || victim == src || victim.stat == DEAD)
		return FALSE
	if(is_outpost_experiment_mob(victim) || HAS_TRAIT(victim, TRAIT_GODMODE))
		return FALSE
	if(is_outpost_prisoner(victim))
		var/mob/living/basic/outpost_prisoner/prisoner = victim
		if(prisoner.phase != PRISONER_PRESENT || !may_hit_prisoner(prisoner))
			return FALSE
		return !blocked_by_cell(prisoner)
	return ishuman(victim) || issilicon(victim) || !isnull(victim.mind)

/// Whether it hits this prisoner
/mob/living/basic/outpost_experiment/proc/may_hit_prisoner(mob/living/basic/outpost_prisoner/prisoner)
	return TRUE

/// How much less it wants a target than its distance says; prisoners and people may count differently
/mob/living/basic/outpost_experiment/proc/target_penalty(mob/living/target)
	return 0

/**
 * Its target now: whoever hurt it lately, else the nearest it wants in sight. While nobody from the
 * wing is home it fights back but hunts nobody, as the horror does (crew_about()), so a loose
 * creature is never a trap left for visitors.
 */
/mob/living/basic/outpost_experiment/proc/choose_target()
	var/datum/component/experiment_damage_ledger/ledger = GetComponent(/datum/component/experiment_damage_ledger)
	var/mob/living/attacker = ledger?.recent_player()
	if(attacker && can_target(attacker) && get_dist(src, attacker) <= 9 && can_see(src, attacker, 9) && !target_unreachable(attacker))
		return attacker
	if(prison && !prison.crew_home())
		return null
	var/mob/living/best
	var/best_score = INFINITY
	for(var/mob/living/candidate in range(7, src))
		if(!can_target(candidate) || !can_see(src, candidate, 7) || target_unreachable(candidate))
			continue
		var/score = get_dist(src, candidate) + target_penalty(candidate)
		if(score < best_score)
			best = candidate
			best_score = score
	return best

/**
 * Its AI's first thought each plan: picks the target and may queue something of its own. Returns
 * SUBTREE_RETURN_FINISH_PLANNING when that is all it does this plan.
 */
/mob/living/basic/outpost_experiment/proc/ai_think(datum/ai_controller/controller)
	var/atom/target = choose_target()
	if(target)
		controller.set_blackboard_key(BB_BASIC_MOB_CURRENT_TARGET, target)
	else
		controller.clear_blackboard_key(BB_BASIC_MOB_CURRENT_TARGET)
	return null

// ----- reach -----

/// Whether nothing shut stops it: the hulk smashes through walls and doors, so a bolted cell or a target it can't get to never is out of its reach
/mob/living/basic/outpost_experiment/proc/smashes_through()
	return FALSE

/// Whether it is mid-jaunt or otherwise between motives right now, and should not be judged on progress
/mob/living/basic/outpost_experiment/proc/chasing_paused()
	return FALSE

/// Whether a bolted cell keeps `prisoner` away from it: shut and locked, and it is not inside with them
/mob/living/basic/outpost_experiment/proc/blocked_by_cell(mob/living/basic/outpost_prisoner/prisoner)
	if(smashes_through())
		return FALSE
	var/datum/outpost_prison_cell/holding = prison?.cell_at(get_turf(prisoner))
	return holding && holding.is_bolted() && !holding.contains(src)

/**
 * Notes whether it is getting anywhere with `controller`'s current target: closer, beside it (Adjacent(),
 * which a shut window or door fails even at a tile's distance), or at least on the move, so a target
 * that runs is chased rather than given up on. OUTPOST_EXPERIMENT_STUCK_TIME standing still and apart
 * writes the target off as unreachable for OUTPOST_EXPERIMENT_UNREACHABLE_TIME; find_light() and
 * choose_target() skip anything on that list. Distance and Adjacent() only: no pathfinding call.
 */
/mob/living/basic/outpost_experiment/proc/track_reach(datum/ai_controller/controller)
	if(smashes_through() || chasing_paused())
		return
	var/atom/movable/target = controller.blackboard[BB_BASIC_MOB_CURRENT_TARGET]
	if(QDELETED(target))
		chase_target_ref = null
		return
	if(chase_target_ref?.resolve() != target)
		chase_target_ref = WEAKREF(target)
		chase_best_distance = get_dist(src, target)
		chase_last_turf = loc
		chase_progress_time = world.time
		return
	if(Adjacent(target) || loc != chase_last_turf)
		chase_last_turf = loc
		chase_progress_time = world.time
		return
	var/distance = get_dist(src, target)
	if(distance < chase_best_distance)
		chase_best_distance = distance
		chase_progress_time = world.time
		return
	if(world.time - chase_progress_time < OUTPOST_EXPERIMENT_STUCK_TIME)
		return
	mark_unreachable(target)
	chase_target_ref = null

/// Whether it gave up on reaching `target` recently
/mob/living/basic/outpost_experiment/proc/target_unreachable(atom/target)
	if(!length(unreachable_until))
		return FALSE
	var/datum/weakref/ref = WEAKREF(target)
	var/until = unreachable_until[ref]
	if(!until)
		return FALSE
	if(until > world.time)
		return TRUE
	unreachable_until -= ref
	return FALSE

/// Writes `target` off for OUTPOST_EXPERIMENT_UNREACHABLE_TIME: something is stopping it getting there
/mob/living/basic/outpost_experiment/proc/mark_unreachable(atom/target)
	LAZYSET(unreachable_until, WEAKREF(target), world.time + OUTPOST_EXPERIMENT_UNREACHABLE_TIME)
	prune_unreachable()

/// Drops expired entries, then the oldest ones if it somehow grew past OUTPOST_EXPERIMENT_UNREACHABLE_MAX
/mob/living/basic/outpost_experiment/proc/prune_unreachable()
	for(var/datum/weakref/ref as anything in unreachable_until.Copy())
		if(unreachable_until[ref] <= world.time)
			unreachable_until -= ref
	while(length(unreachable_until) > OUTPOST_EXPERIMENT_UNREACHABLE_MAX)
		var/datum/weakref/oldest
		for(var/datum/weakref/ref as anything in unreachable_until)
			oldest = ref
			break
		unreachable_until -= oldest

// ----- breaking things -----

/// Whether it may break `thing` out of its way. Only the hulk does.
/mob/living/basic/outpost_experiment/proc/can_break(atom/thing)
	return FALSE

/// Breaks `thing` out of its way
/mob/living/basic/outpost_experiment/proc/break_obstacle(atom/thing)
	return FALSE

// ===== HULK =====

/mob/living/basic/outpost_experiment/hulk
	desc = "A prisoner swollen into a green giant, still in the rags of a jumpsuit."
	form_name = "a hulk"
	mob_size = MOB_SIZE_LARGE
	footstep_kind = FOOTSTEP_MOB_HEAVY
	footstep_volume = 1
	footstep_range = -4
	status_flags = NONE
	base_health = OUTPOST_HULK_HEALTH
	health_per_player = OUTPOST_HULK_HEALTH_PER_PLAYER
	speed = OUTPOST_HULK_SPEED
	melee_damage_lower = OUTPOST_HULK_PUNCH_MIN
	melee_damage_upper = OUTPOST_HULK_PUNCH_MAX
	melee_attack_cooldown = OUTPOST_HULK_PUNCH_COOLDOWN
	obj_damage = 60
	environment_smash = ENVIRONMENT_SMASH_STRUCTURES
	attack_verb_continuous = "smashes"
	attack_verb_simple = "smash"
	attack_sound = 'sound/effects/meteorimpact.ogg'
	attack_vis_effect = ATTACK_EFFECT_SMASH
	max_stamina = OUTPOST_HULK_STAMINA
	line_context = "hulk"
	/// Worn down: slower, no charge, and batons work
	var/exhausted = FALSE
	/// Its charge
	var/datum/action/cooldown/mob_cooldown/charge/basic_charge/outpost_hulk/charge

/mob/living/basic/outpost_experiment/hulk/Initialize(mapload, datum/outpost_prison/owner, mob/living/basic/outpost_prisoner/subject)
	. = ..()
	update_transform(1.25)
	charge = new(src)
	charge.Grant(src)
	ai_controller?.set_blackboard_key(BB_TARGETED_ACTION, charge)
	AddElement(/datum/element/wall_tearer/outpost_interior, allow_reinforced = FALSE, tear_time = OUTPOST_HULK_TEAR_TIME)
	RegisterSignal(src, COMSIG_LIVING_HEALTH_UPDATE, PROC_REF(check_exhausted))
	playsound(src, 'sound/mobs/non-humanoids/gorilla/gorilla.ogg', 80, TRUE)
	visible_message(span_danger("[src] swells, splits [p_their()] jumpsuit and roars!"))

/mob/living/basic/outpost_experiment/hulk/Destroy()
	QDEL_NULL(charge)
	return ..()

/mob/living/basic/outpost_experiment/hulk/build_look(outfit_path)
	INVOKE_ASYNC(GLOBAL_PROC, GLOBAL_PROC_REF(outpost_hulk_look), src, outfit_path)

/// Players first, then prisoners still on their feet
/mob/living/basic/outpost_experiment/hulk/target_penalty(mob/living/target)
	return is_outpost_prisoner(target) ? 3 : 0

/// Only prisoners still standing: it knocks them flat and leaves them
/mob/living/basic/outpost_experiment/hulk/may_hit_prisoner(mob/living/basic/outpost_prisoner/prisoner)
	return !prisoner.can_be_dragged() && prisoner.beaten_left <= 0

/// It tears through walls and forces doors, so a bolted cell and a blocked path never stop it
/mob/living/basic/outpost_experiment/hulk/smashes_through()
	return TRUE

/mob/living/basic/outpost_experiment/hulk/ai_think(datum/ai_controller/controller)
	. = ..()
	var/mob/living/target = controller.blackboard[BB_BASIC_MOB_CURRENT_TARGET]
	if(exhausted || !isliving(target) || !charge?.IsAvailable())
		return
	var/distance = get_dist(src, target)
	if(distance < 2 || distance > OUTPOST_HULK_CHARGE_RANGE || !can_see(src, target, OUTPOST_HULK_CHARGE_RANGE))
		return
	controller.queue_behavior(/datum/ai_behavior/targeted_mob_ability, BB_TARGETED_ACTION, BB_BASIC_MOB_CURRENT_TARGET)
	return SUBTREE_RETURN_FINISH_PLANNING

/// A punch; a prisoner is knocked flat instead, and a person may go flying
/mob/living/basic/outpost_experiment/hulk/melee_attack(atom/target, list/modifiers, ignore_cooldown = FALSE)
	if(is_outpost_prisoner(target))
		if(!early_melee_attack(target, modifiers, ignore_cooldown))
			return FALSE
		do_attack_animation(target, ATTACK_EFFECT_SMASH)
		playsound(target, 'sound/items/weapons/punch1.ogg', 60, TRUE)
		knock_down_prisoner(target)
		return TRUE
	. = ..()
	if(!. || !isliving(target) || !prob(OUTPOST_HULK_THROW_CHANCE))
		return
	var/mob/living/victim = target
	if(victim.stat == DEAD || victim.anchored || victim.move_resist >= MOVE_FORCE_OVERPOWERING)
		return
	victim.visible_message(span_danger("[src] sends [victim] flying!"))
	victim.throw_at(get_ranged_target_turf(victim, get_dir(src, victim), OUTPOST_HULK_THROW_RANGE), OUTPOST_HULK_THROW_RANGE, 1, src)

/// Knocks a prisoner into the beaten state: hurt, flat on the floor, never killed
/mob/living/basic/outpost_experiment/hulk/proc/knock_down_prisoner(mob/living/basic/outpost_prisoner/prisoner)
	if(QDELETED(prisoner) || prisoner.stat == DEAD)
		return FALSE
	var/damage = min(rand(OUTPOST_HULK_PUNCH_MIN, OUTPOST_HULK_PUNCH_MAX), max(0, prisoner.health - 1))
	if(damage > 0)
		prisoner.apply_damage(damage, BRUTE)
	prisoner.visible_message(span_danger("[src] knocks [prisoner] flat!"))
	if(prisoner.stat == CONSCIOUS && prisoner.beaten_left <= 0)
		prisoner.collapse()
	return TRUE

/// Worn down to OUTPOST_HULK_EXHAUSTED_AT percent: slower, no more charging, and stamina weapons work
/mob/living/basic/outpost_experiment/hulk/proc/check_exhausted(datum/source)
	SIGNAL_HANDLER
	if(exhausted || stat == DEAD || health > maxHealth * OUTPOST_HULK_EXHAUSTED_AT / 100)
		return
	exhausted = TRUE
	set_varspeed(OUTPOST_HULK_EXHAUSTED_SPEED)
	damage_coeff[STAMINA] = 1
	status_flags |= CANSTUN | CANKNOCKDOWN
	charge?.disable()
	visible_message(span_warning("[src] staggers, heaving for breath. [p_They()] look[p_s()] spent."))

/// Charged into a wall: stunned, and hit harder for a moment
/mob/living/basic/outpost_experiment/hulk/proc/stagger_on_wall()
	Stun(OUTPOST_HULK_WALL_STUN, ignore_canstun = TRUE)
	damage_coeff[BRUTE] = OUTPOST_HULK_WALL_VULNERABLE
	damage_coeff[BURN] = OUTPOST_HULK_WALL_VULNERABLE
	addtimer(CALLBACK(src, PROC_REF(recover_from_wall)), OUTPOST_HULK_WALL_STUN, TIMER_UNIQUE | TIMER_OVERRIDE | TIMER_DELETE_ME)

/mob/living/basic/outpost_experiment/hulk/proc/recover_from_wall()
	damage_coeff[BRUTE] = 1
	damage_coeff[BURN] = 1

/// Interior walls, windows, grilles, tables, chairs and doors, never the hatch counters or anything protected
/mob/living/basic/outpost_experiment/hulk/can_break(atom/thing)
	if(QDELETED(thing) || !outpost_experiment_can_smash(thing, prison))
		return FALSE
	if(isturf(thing))
		return iswallturf(thing) && !istype(thing, /turf/closed/wall/r_wall) && !isindestructiblewall(thing)
	var/obj/object = thing
	if(!istype(object) || (object.resistance_flags & INDESTRUCTIBLE) || HAS_TRAIT(object, TRAIT_OUTPOST_PROPERTY))
		return FALSE
	if(istype(object, /obj/structure/table/reinforced/prison_hatch))
		return FALSE
	return istype(object, /obj/structure/window) || istype(object, /obj/structure/grille) || istype(object, /obj/structure/table) \
		|| istype(object, /obj/structure/chair) || istype(object, /obj/machinery/door)

/mob/living/basic/outpost_experiment/hulk/break_obstacle(atom/thing)
	if(!can_break(thing))
		return FALSE
	if(isturf(thing))
		// The wall tearer takes it from here, in three pulls.
		melee_attack(thing)
		return TRUE
	if(istype(thing, /obj/machinery/door/airlock))
		INVOKE_ASYNC(src, PROC_REF(force_door), thing)
		return TRUE
	smash(thing)
	return TRUE

/// Batters a door until it gives: bolts sheared, weld broken, forced open
/mob/living/basic/outpost_experiment/hulk/proc/force_door(obj/machinery/door/airlock/door)
	if(DOING_INTERACTION_WITH_TARGET(src, door) || !door.density)
		return FALSE
	visible_message(span_danger("[src] batters at [door]!"))
	playsound(door, 'sound/effects/bang.ogg', 70, TRUE)
	door.Shake(2, 2, 0.5 SECONDS)
	if(!do_after(src, OUTPOST_HULK_DOOR_TIME, target = door) || QDELETED(door) || !can_break(door))
		return FALSE
	if(door.locked)
		door.unbolt()
	if(door.welded)
		door.welded = FALSE
		door.update_appearance()
	door.visible_message(span_danger("[src] forces [door] open!"))
	playsound(door, 'sound/machines/airlock/airlock_alien_prying.ogg', 80, TRUE)
	INVOKE_ASYNC(door, TYPE_PROC_REF(/obj/machinery/door, open), BYPASS_DOOR_CHECKS)
	prison?.refresh_reach()
	return TRUE

/// Puts something through: windows shatter, tables fold, chairs splinter, window doors break
/mob/living/basic/outpost_experiment/hulk/proc/smash(obj/thing)
	if(QDELETED(thing))
		return FALSE
	do_attack_animation(thing, ATTACK_EFFECT_SMASH)
	visible_message(span_danger("[src] smashes [thing]!"))
	playsound(thing, istype(thing, /obj/structure/window) ? 'sound/effects/glass/glassbr1.ogg' : 'sound/effects/woodhit.ogg', 70, TRUE)
	thing.take_damage(thing.get_integrity(), BRUTE, MELEE, FALSE, get_dir(thing, src))
	return TRUE

/// tg's hulk skin on the prisoner's own clothes, cached per outfit
/proc/outpost_hulk_look(mob/living/basic/outpost_experiment/hulk/hulk, outfit_path)
	var/static/list/looks = list()
	var/key = "[outfit_path]"
	var/mutable_appearance/look = looks[key]
	if(!look)
		var/mob/living/carbon/human/dummy/consistent/dummy = new()
		dummy.set_species(/datum/species/human)
		dummy.stat = DEAD
		dummy.underwear = "Nude"
		dummy.undershirt = "Nude"
		dummy.socks = "Nude"
		if(outfit_path)
			dummy.equipOutfit(outfit_path, visuals_only = TRUE)
		for(var/obj/item/bodypart/part as anything in dummy.bodyparts)
			part.add_color_override(COLOR_DARK_LIME, LIMB_COLOR_HULK)
		dummy.update_body_parts()
		look = new(dummy.appearance)
		looks[key] = look
		qdel(dummy)
	if(QDELETED(hulk))
		return
	hulk.icon = 'icons/mob/human/human.dmi'
	hulk.icon_state = ""
	hulk.appearance_flags |= KEEP_TOGETHER
	hulk.copy_overlays(look, cut_old = TRUE)

/// The hulk's charge: a roar, a stamp and a line on the floor, then six tiles of it
/datum/action/cooldown/mob_cooldown/charge/basic_charge/outpost_hulk
	name = "Charge"
	desc = "Put your head down and run through whatever is in the way."
	cooldown_time = OUTPOST_HULK_CHARGE_COOLDOWN
	charge_delay = OUTPOST_HULK_CHARGE_WINDUP
	charge_distance = OUTPOST_HULK_CHARGE_RANGE
	charge_past = 1
	charge_damage = OUTPOST_HULK_CHARGE_DAMAGE
	destroy_objects = FALSE
	shake_duration = OUTPOST_HULK_CHARGE_WINDUP
	recoil_duration = OUTPOST_HULK_WALL_STUN
	knockdown_duration = OUTPOST_HULK_CHARGE_KNOCKDOWN

/datum/action/cooldown/mob_cooldown/charge/basic_charge/outpost_hulk/do_charge_indicator(atom/charger, atom/charge_target)
	. = ..()
	playsound(charger, 'sound/mobs/non-humanoids/gorilla/gorilla.ogg', 80, TRUE)
	charger.visible_message(span_danger("[charger] roars and stamps, lowering [charger.p_their()] head!"))
	var/direction = get_dir(charger, charge_target)
	var/turf/step_turf = get_turf(charger)
	for(var/i in 1 to charge_distance)
		step_turf = get_step(step_turf, direction)
		if(!step_turf || isclosedturf(step_turf))
			break
		new /obj/effect/temp_visual/telegraphing/outpost_hulk_charge(step_turf)

/datum/action/cooldown/mob_cooldown/charge/basic_charge/outpost_hulk/on_bump(atom/movable/source, atom/target)
	var/mob/living/basic/outpost_experiment/hulk/hulk = source
	if(istype(hulk) && isobj(target) && target.density && !istype(target, /obj/machinery/door/airlock) && hulk.can_break(target))
		INVOKE_ASYNC(hulk, TYPE_PROC_REF(/mob/living/basic/outpost_experiment/hulk, smash), target)
		return
	return ..()

/datum/action/cooldown/mob_cooldown/charge/basic_charge/outpost_hulk/on_moved(atom/source)
	. = ..()
	var/mob/living/basic/outpost_experiment/hulk/hulk = source
	if(!istype(hulk))
		return
	for(var/obj/structure/chair/chair in get_turf(hulk))
		if(hulk.can_break(chair))
			INVOKE_ASYNC(hulk, TYPE_PROC_REF(/mob/living/basic/outpost_experiment/hulk, smash), chair)

/datum/action/cooldown/mob_cooldown/charge/basic_charge/outpost_hulk/hit_target(atom/movable/source, atom/target, damage_dealt)
	var/mob/living/basic/outpost_experiment/hulk/hulk = source
	if(is_outpost_prisoner(target))
		hulk?.knock_down_prisoner(target)
		return
	if(isliving(target))
		var/mob/living/victim = target
		victim.apply_damage(damage_dealt, BRUTE, wound_bonus = CANT_WOUND)
		playsound(get_turf(victim), 'sound/effects/meteorimpact.ogg', 80, TRUE)
		return ..()
	hulk?.visible_message(span_danger("[hulk] slams into [target] and reels!"))
	playsound(get_turf(source), 'sound/effects/bang.ogg', 80, TRUE)
	hulk?.stagger_on_wall()

/// The floor in the charge's path, for the length of the wind-up
/obj/effect/temp_visual/telegraphing/outpost_hulk_charge
	duration = OUTPOST_HULK_CHARGE_WINDUP
	color = "#9ae05a"

/// tg's wall tearer, for walls inside the outpost only
/datum/element/wall_tearer/outpost_interior

/datum/element/wall_tearer/outpost_interior/validate_target(atom/target, mob/living/tearer)
	. = ..()
	if(. != TRUE)
		return
	var/mob/living/basic/outpost_experiment/hulk/hulk = tearer
	if(!istype(hulk) || !hulk.can_break(target))
		target.balloon_alert(tearer, "it won't give!")
		return -1

// ===== FLY PERSON =====

/mob/living/basic/outpost_experiment/fly
	desc = "A prisoner turned into something like a fly: bulging eyes, a proboscis, and a buzz you can hear across the room."
	form_name = "a fly person"
	base_health = OUTPOST_FLY_HEALTH
	speed = OUTPOST_FLY_SPEED
	melee_damage_lower = OUTPOST_FLY_BITE
	melee_damage_upper = OUTPOST_FLY_BITE
	melee_attack_cooldown = 1.5 SECONDS
	attack_verb_continuous = "bites"
	attack_verb_simple = "bite"
	attack_sound = 'sound/items/weapons/bite.ogg'
	attack_vis_effect = ATTACK_EFFECT_BITE
	damage_coeff = list(BRUTE = 1, BURN = 1, TOX = 0, STAMINA = 1, OXY = 0)
	status_flags = CANPUSH | CANSTUN | CANKNOCKDOWN
	max_stamina = OUTPOST_FLY_STAMINA
	line_context = "fly"
	ai_controller = /datum/ai_controller/basic_controller/outpost_experiment/fly
	death_message = "drops out of the air and goes still."
	subdued_message = "drops out of the air, stunned."
	win_hint = "It never lands for long."
	/// Seconds to its next heave
	var/vomit_left = OUTPOST_FLY_VOMIT_MIN
	/// REF() of prisoners who watched it throw up -> world.time
	var/list/disgusted = list()
	/// world.time of its next random dart, and by when the dart under way must be over
	var/next_dart = 0
	var/dart_until = 0
	/// Whoever hit it last, whom it keeps away from until flit_until
	var/datum/weakref/flit_from_ref
	var/flit_until = 0

/mob/living/basic/outpost_experiment/fly/Initialize(mapload, datum/outpost_prison/owner, mob/living/basic/outpost_prisoner/subject)
	. = ..()
	RegisterSignal(src, COMSIG_MOB_APPLY_DAMAGE_MODIFIERS, PROC_REF(swatter_weakness))
	RegisterSignal(src, COMSIG_PROJECTILE_PREHIT, PROC_REF(dodge))
	RegisterSignal(src, COMSIG_ATOM_WAS_ATTACKED, PROC_REF(on_attacked))
	ADD_TRAIT(src, TRAIT_MOVE_FLYING, OUTPOST_FLY_TRAIT)
	playsound(src, 'sound/mobs/non-humanoids/bee/bee_swarm.ogg', 60, TRUE)
	visible_message(span_danger("[src] folds up, splits open and unfolds as something with wings!"))

/mob/living/basic/outpost_experiment/fly/Destroy()
	flit_from_ref = null
	return ..()

/mob/living/basic/outpost_experiment/fly/build_look(outfit_path)
	apply_dynamic_human_appearance(src, outfit_path, /datum/species/fly)

/// On the floor (knocked down, subdued or dead) it is not flying
/mob/living/basic/outpost_experiment/fly/on_lying_down(new_lying_angle)
	. = ..()
	REMOVE_TRAIT(src, TRAIT_MOVE_FLYING, OUTPOST_FLY_TRAIT)

/// Back up, it takes off again
/mob/living/basic/outpost_experiment/fly/on_standing_up()
	. = ..()
	if(stat == CONSCIOUS && !subdued)
		ADD_TRAIT(src, TRAIT_MOVE_FLYING, OUTPOST_FLY_TRAIT)

/mob/living/basic/outpost_experiment/fly/down_twitch()
	Shake(1, 0, 0.4 SECONDS)
	playsound(src, 'sound/mobs/non-humanoids/bee/bee.ogg', 15, TRUE)
	if(prob(40))
		manual_emote(pick("buzzes weakly.", "twitches [p_their()] wings.", "twitches."))

/// tg's fly people take thirty times the damage from a flyswatter
/mob/living/basic/outpost_experiment/fly/proc/swatter_weakness(datum/source, list/damage_mods, damage_amount, damagetype, def_zone, sharpness, attack_direction, obj/item/attacking_item)
	SIGNAL_HANDLER
	if(istype(attacking_item, /obj/item/melee/flyswatter))
		damage_mods += OUTPOST_FLY_SWATTER_MULT

/// In the air and free to move: not knocked down, stunned, held, pulled, subdued or being taken away
/mob/living/basic/outpost_experiment/fly/proc/flying_freely()
	if(stat != CONSCIOUS || subdued || !isturf(loc) || pulledby || buckled || body_position != STANDING_UP)
		return FALSE
	return !HAS_TRAIT(src, TRAIT_IMMOBILIZED) && !HAS_TRAIT(src, TRAIT_INCAPACITATED) && !HAS_TRAIT(src, TRAIT_GODMODE)

/// Jinks out of the way of some shots while it flies freely
/mob/living/basic/outpost_experiment/fly/proc/dodge(datum/source, obj/projectile/shot)
	SIGNAL_HANDLER
	if(!flying_freely() || !prob(OUTPOST_FLY_DODGE))
		return NONE
	visible_message(span_warning("[src] jinks out of the way of [shot]!"))
	playsound(src, 'sound/mobs/non-humanoids/bee/bee.ogg', 30, TRUE)
	return PROJECTILE_INTERRUPT_HIT_PHASE

/// Hit while flying: it flits away from whoever did it, and keeps away from them for a few seconds
/mob/living/basic/outpost_experiment/fly/proc/on_attacked(datum/source, atom/attacker, attack_flags)
	SIGNAL_HANDLER
	if(!attacker || attacker == src || !flying_freely())
		return
	flit_from_ref = WEAKREF(attacker)
	flit_until = world.time + OUTPOST_FLY_FLIT_TIME
	// Once the blow is over, not in the middle of it.
	addtimer(CALLBACK(src, PROC_REF(flit)), 1, TIMER_UNIQUE | TIMER_OVERRIDE | TIMER_DELETE_ME)

/// Whoever hit it within OUTPOST_FLY_FLIT_TIME, if still near enough to keep away from
/mob/living/basic/outpost_experiment/fly/proc/flit_threat()
	if(world.time > flit_until)
		return null
	var/atom/movable/attacker = flit_from_ref?.resolve()
	if(QDELETED(attacker) || attacker.z != z || get_dist(src, attacker) > OUTPOST_FLY_DART_MAX + OUTPOST_FLY_FLEE_RANGE)
		return null
	return attacker

/// Darts away from whoever just hit it, at once rather than at its next thought. Returns TRUE if it went.
/mob/living/basic/outpost_experiment/fly/proc/flit()
	var/atom/attacker = flit_threat()
	if(!attacker || !flying_freely() || !ai_controller || !awake())
		return FALSE
	var/turf/spot = dart_spot(attacker)
	if(!spot)
		return FALSE
	ai_controller.CancelActions()
	ai_controller.queue_behavior(/datum/ai_behavior/outpost_fly_dart/away, spot)
	return TRUE

/// It goes for food and bites only when cornered: its "targets" are meals, and people it cannot get away from
/mob/living/basic/outpost_experiment/fly/can_target(atom/target)
	if(istype(target, /obj/item/food))
		return isturf(target.loc)
	return ..()

/// Whoever is closest within OUTPOST_FLY_FLEE_RANGE, to keep away from
/mob/living/basic/outpost_experiment/fly/proc/nearest_threat()
	var/mob/living/nearest
	var/nearest_distance = INFINITY
	for(var/mob/living/person in range(OUTPOST_FLY_FLEE_RANGE, src))
		if(person == src || !is_victim(person))
			continue
		var/distance = get_dist(src, person)
		if(distance < nearest_distance)
			nearest = person
			nearest_distance = distance
	return nearest

/**
 * Somewhere to dart to: an open tile OUTPOST_FLY_DART_MIN to OUTPOST_FLY_DART_MAX tiles off, in a
 * clear line, on ground it keeps to (may_dart_to()). Away from `threat`, only somewhere farther
 * from it than it is now, and out of its OUTPOST_FLY_FLEE_RANGE if it can. Null if there is
 * nowhere: cornered.
 */
/mob/living/basic/outpost_experiment/fly/proc/dart_spot(atom/threat)
	var/turf/here = get_turf(src)
	if(!here)
		return null
	var/threat_distance = threat ? get_dist(here, threat) : 0
	var/list/spots = list()
	var/list/clear_spots = list()
	for(var/turf/open/tile in RANGE_TURFS(OUTPOST_FLY_DART_MAX, here))
		if(get_dist(here, tile) < OUTPOST_FLY_DART_MIN)
			continue
		var/from_threat = threat ? get_dist(tile, threat) : INFINITY
		if(from_threat <= threat_distance || !may_dart_to(tile) || !clear_line(here, tile))
			continue
		spots += tile
		if(from_threat > OUTPOST_FLY_FLEE_RANGE)
			clear_spots += tile
	if(length(clear_spots))
		return pick(clear_spots)
	return length(spots) ? pick(spots) : null

/**
 * Whether it keeps to `tile`: free and safe, and in the wing (its cell block, while it is in
 * there) like the other creatures. Got out of the wing, it darts about the room it is in.
 */
/mob/living/basic/outpost_experiment/fly/proc/may_dart_to(turf/tile)
	if(isspaceturf(tile) || isopenspaceturf(tile) || tile.is_blocked_turf(FALSE, src) || !tile.can_cross_safely(src))
		return FALSE
	var/turf/here = get_turf(src)
	if(prison?.wing && here.loc == prison.wing)
		return tile.loc == prison.wing && (!prison.in_cell_block(here) || prison.in_cell_block(tile))
	return tile.loc == here.loc

/// Whether it can fly straight from `start` to `finish`: nothing solid or opaque in the way
/mob/living/basic/outpost_experiment/fly/proc/clear_line(turf/start, turf/finish)
	for(var/turf/step as anything in get_line(start, finish))
		if(step == start)
			continue
		if(step.opacity || step.is_blocked_turf(TRUE, src))
			return FALSE
	return TRUE

/**
 * Keeps moving: darts away from anyone close or who just hit it, and bites only when cornered
 * with someone at it. Otherwise it goes for food in sight, or darts about at random with short
 * pauses. It hovers (outpost_fly_hover) rather than planning nothing, so it notices people at once.
 */
/mob/living/basic/outpost_experiment/fly/ai_think(datum/ai_controller/controller)
	if(!flying_freely())
		controller.clear_blackboard_key(BB_BASIC_MOB_CURRENT_TARGET)
		controller.queue_behavior(/datum/ai_behavior/outpost_fly_hover)
		return SUBTREE_RETURN_FINISH_PLANNING
	var/atom/threat = flit_threat() || nearest_threat()
	if(threat)
		var/turf/away = dart_spot(threat)
		if(away)
			controller.clear_blackboard_key(BB_BASIC_MOB_CURRENT_TARGET)
			controller.queue_behavior(/datum/ai_behavior/outpost_fly_dart/away, away)
			return SUBTREE_RETURN_FINISH_PLANNING
		// Nowhere farther to go: it bites whoever is at it.
		var/mob/living/at_it = threat
		if(istype(at_it) && Adjacent(at_it) && can_target(at_it))
			controller.set_blackboard_key(BB_BASIC_MOB_CURRENT_TARGET, at_it)
			return null
		controller.clear_blackboard_key(BB_BASIC_MOB_CURRENT_TARGET)
		controller.queue_behavior(/datum/ai_behavior/outpost_fly_hover)
		return SUBTREE_RETURN_FINISH_PLANNING
	var/obj/item/food/meal = find_meal()
	if(meal)
		controller.set_blackboard_key(BB_BASIC_MOB_CURRENT_TARGET, meal)
		return null
	controller.clear_blackboard_key(BB_BASIC_MOB_CURRENT_TARGET)
	var/turf/spot = world.time >= next_dart ? dart_spot() : null
	if(spot)
		controller.queue_behavior(/datum/ai_behavior/outpost_fly_dart, spot)
		return SUBTREE_RETURN_FINISH_PLANNING
	if(world.time >= next_dart)
		next_dart = world.time + rand(OUTPOST_FLY_DART_GAP_MIN, OUTPOST_FLY_DART_GAP_MAX)
	controller.queue_behavior(/datum/ai_behavior/outpost_fly_hover)
	return SUBTREE_RETURN_FINISH_PLANNING

/// The nearest food in sight: a serving hatch, a table or the floor
/mob/living/basic/outpost_experiment/fly/proc/find_meal()
	var/obj/item/food/best
	var/best_distance = INFINITY
	for(var/obj/item/food/meal in range(5, src))
		if(!isturf(meal.loc) || !can_see(src, meal, 5))
			continue
		var/distance = get_dist(src, meal)
		if(distance < best_distance)
			best = meal
			best_distance = distance
	return best

/mob/living/basic/outpost_experiment/fly/melee_attack(atom/target, list/modifiers, ignore_cooldown = FALSE)
	var/obj/item/food/meal = target
	if(istype(meal))
		if(!early_melee_attack(target, modifiers, ignore_cooldown))
			return FALSE
		visible_message(span_warning("[src] slurps up [meal]."))
		playsound(src, 'sound/items/eatfood.ogg', 40, TRUE)
		if(isturf(meal.loc))
			new /obj/effect/decal/cleanable/food/crumbs(meal.loc)
		qdel(meal)
		return TRUE
	return ..()

/// It throws up every few seconds, now and then over someone beside it; prisoners who see it lose a little mood
/mob/living/basic/outpost_experiment/fly/creature_life(seconds_per_tick)
	vomit_left -= seconds_per_tick
	if(vomit_left > 0 || !isturf(loc))
		return
	vomit_left = rand(OUTPOST_FLY_VOMIT_MIN, OUTPOST_FLY_VOMIT_MAX)
	throw_up()

/mob/living/basic/outpost_experiment/fly/proc/throw_up()
	var/turf/spot = loc
	var/list/beside = list()
	for(var/mob/living/person in orange(1, src))
		if(is_victim(person))
			beside += person
	if(length(beside) && prob(OUTPOST_FLY_VOMIT_ON_CHANCE))
		var/mob/living/unlucky = pick(beside)
		spot = get_turf(unlucky)
		visible_message(span_danger("[src] throws up all over [unlucky]!"))
	else
		visible_message(span_warning("[src] throws up."))
	playsound(src, 'sound/mobs/humanoids/human/gag_vomit/crack_vomit.ogg', 50, TRUE)
	if(isopenturf(spot))
		new /obj/effect/decal/cleanable/vomit(spot)
	for(var/mob/living/basic/outpost_prisoner/watcher in viewers(5, src))
		if(watcher.stat != CONSCIOUS || LAZYACCESS(disgusted, REF(watcher)) > world.time)
			continue
		LAZYSET(disgusted, REF(watcher), world.time + OUTPOST_EXPERIMENT_FLY_DISGUST_GAP)
		watcher.adjust_mood(-OUTPOST_EXPERIMENT_FLY_DISGUST_MOOD)
	return spot

// ===== NIGHTMARE =====

/mob/living/basic/outpost_experiment/nightmare
	desc = "A shape like a person cut out of the dark, with a long blade where one arm should be."
	form_name = "a nightmare"
	footstep_kind = FOOTSTEP_MOB_BAREFOOT
	footstep_volume = 0.3
	base_health = OUTPOST_NIGHTMARE_HEALTH
	health_per_player = OUTPOST_NIGHTMARE_HEALTH_PER_PLAYER
	speed = OUTPOST_NIGHTMARE_DARK_SPEED
	melee_damage_lower = OUTPOST_NIGHTMARE_DAMAGE
	melee_damage_upper = OUTPOST_NIGHTMARE_DAMAGE
	melee_attack_cooldown = OUTPOST_NIGHTMARE_ATTACK_COOLDOWN
	armour_penetration = OUTPOST_NIGHTMARE_ARMOUR_PENETRATION
	attack_verb_continuous = "slashes"
	attack_verb_simple = "slash"
	attack_sound = 'sound/items/weapons/bladeslice.ogg'
	attack_vis_effect = ATTACK_EFFECT_SLASH
	sharpness = SHARP_EDGED
	lighting_cutoff = LIGHTING_CUTOFF_HIGH
	/// Seconds left of breaking the lights before it hunts
	var/opening_left = OUTPOST_NIGHTMARE_OPENING_MIN
	/// Mid jaunt: gone into the dark, about to come out beside someone
	var/jaunting = FALSE
	/// Where it will come out, and at whom
	var/turf/jaunt_spot
	var/datum/weakref/jaunt_target_ref
	/// Its last light reading was dark
	var/in_shadow = TRUE
	COOLDOWN_DECLARE(jaunt_cooldown)

/mob/living/basic/outpost_experiment/nightmare/Initialize(mapload, datum/outpost_prison/owner, mob/living/basic/outpost_prisoner/subject)
	. = ..()
	opening_left = rand(OUTPOST_NIGHTMARE_OPENING_MIN, OUTPOST_NIGHTMARE_OPENING_MAX)
	RegisterSignal(src, COMSIG_PROJECTILE_PREHIT, PROC_REF(dodge))
	RegisterSignal(src, COMSIG_ATOM_ATTACKBY, PROC_REF(on_attackby))
	playsound(src, 'sound/effects/hallucinations/wail.ogg', 60, TRUE)
	visible_message(span_danger("The light seems to drain out of [src], and something else stands where [p_they()] stood."))

/mob/living/basic/outpost_experiment/nightmare/Destroy()
	jaunt_spot = null
	return ..()

/mob/living/basic/outpost_experiment/nightmare/build_look(outfit_path)
	apply_dynamic_human_appearance(src, /datum/outfit/outpost_experiment_nightmare, /datum/species/shadow/nightmare)

/// Whether the tile it stands on is dark
/mob/living/basic/outpost_experiment/nightmare/proc/in_dark(turf/tile = get_turf(src))
	return tile && tile.get_lumcount() < OUTPOST_NIGHTMARE_DARK

/// Each second: heal in the dark and move fast, burn in the light and move slow; the opening runs down
/mob/living/basic/outpost_experiment/nightmare/creature_life(seconds_per_tick)
	if(opening_left > 0)
		opening_left -= seconds_per_tick
	in_shadow = in_dark()
	set_varspeed(in_shadow ? OUTPOST_NIGHTMARE_DARK_SPEED : OUTPOST_NIGHTMARE_LIGHT_SPEED)
	if(in_shadow)
		if(health < maxHealth)
			adjustBruteLoss(-OUTPOST_NIGHTMARE_REGEN * seconds_per_tick)
		return
	if(jaunting)
		cancel_jaunt()
	var/burn = OUTPOST_NIGHTMARE_BURN * seconds_per_tick
	adjustFireLoss(burn)
	// The crew's lights are their weapon.
	var/datum/component/experiment_damage_ledger/ledger = GetComponent(/datum/component/experiment_damage_ledger)
	ledger?.add_damage(burn, TRUE)
	if(prob(20))
		visible_message(span_warning("[src] smokes and shrinks from the light."))

/// Whether it is still breaking the lights: for its first half minute, until it is hurt, or until there are none
/mob/living/basic/outpost_experiment/nightmare/proc/in_opening()
	if(opening_left <= 0)
		return FALSE
	var/datum/component/experiment_damage_ledger/ledger = GetComponent(/datum/component/experiment_damage_ledger)
	if(ledger && (ledger.player_damage + ledger.other_damage + ledger.pending) > 0)
		opening_left = 0
		return FALSE
	return TRUE

/// Prisoners first, standing or down; it finishes what it starts
/mob/living/basic/outpost_experiment/nightmare/target_penalty(mob/living/target)
	return is_outpost_prisoner(target) ? -3 : 0

/// Mid-jaunt it is immobile by design, not stuck
/mob/living/basic/outpost_experiment/nightmare/chasing_paused()
	return jaunting

/// Lights, during the opening
/mob/living/basic/outpost_experiment/nightmare/can_target(atom/target)
	if(istype(target, /obj/machinery/light))
		var/obj/machinery/light/fixture = target
		return fixture.status != LIGHT_BROKEN && fixture.status != LIGHT_EMPTY
	return ..()

/// The nearest working light in sight
/mob/living/basic/outpost_experiment/nightmare/proc/find_light()
	var/obj/machinery/light/best
	var/best_distance = INFINITY
	for(var/obj/machinery/light/fixture in range(9, src))
		if(!can_target(fixture) || !can_see(src, fixture, 9) || target_unreachable(fixture))
			continue
		var/distance = get_dist(src, fixture)
		if(distance < best_distance)
			best = fixture
			best_distance = distance
	return best

/mob/living/basic/outpost_experiment/nightmare/ai_think(datum/ai_controller/controller)
	if(jaunting)
		controller.clear_blackboard_key(BB_BASIC_MOB_CURRENT_TARGET)
		return SUBTREE_RETURN_FINISH_PLANNING
	if(in_opening())
		var/obj/machinery/light/fixture = find_light()
		if(fixture)
			controller.set_blackboard_key(BB_BASIC_MOB_CURRENT_TARGET, fixture)
			return null
		opening_left = 0
	. = ..()
	var/mob/living/target = controller.blackboard[BB_BASIC_MOB_CURRENT_TARGET]
	if(!isliving(target) || get_dist(src, target) <= 1)
		return
	var/turf/spot = jaunt_spot_near(target)
	if(!spot)
		return
	start_jaunt(target, spot)
	return SUBTREE_RETURN_FINISH_PLANNING

/// A light eater hit; a light is simply put out, and a flashlight in the victim's hands may burn out for good
/mob/living/basic/outpost_experiment/nightmare/melee_attack(atom/target, list/modifiers, ignore_cooldown = FALSE)
	var/obj/machinery/light/fixture = target
	if(istype(fixture))
		if(!early_melee_attack(target, modifiers, ignore_cooldown))
			return FALSE
		do_attack_animation(fixture, ATTACK_EFFECT_SLASH)
		if(fixture.status == LIGHT_OK || fixture.status == LIGHT_BURNED)
			fixture.visible_message(span_danger("[src] cuts through [fixture], and it goes dark."))
			fixture.break_light_tube()
		return TRUE
	. = ..()
	if(. && isliving(target))
		eat_held_light(target)

/// OUTPOST_NIGHTMARE_BURNOUT_CHANCE to put out a flashlight `victim` holds for good; never a flare or glowstick
/mob/living/basic/outpost_experiment/nightmare/proc/eat_held_light(mob/living/victim)
	if(!prob(OUTPOST_NIGHTMARE_BURNOUT_CHANCE))
		return null
	for(var/obj/item/flashlight/light in victim.held_items)
		if(istype(light, /obj/item/flashlight/flare) || istype(light, /obj/item/flashlight/glowstick) || !light.light_on)
			continue
		if(SEND_SIGNAL(light, COMSIG_LIGHT_EATER_ACT, src) & COMPONENT_BLOCK_LIGHT_EATER)
			continue
		light.AddElement(/datum/element/light_eaten)
		victim.visible_message(span_danger("[src]'s blade passes through [light], and it dies in [victim]'s hand."))
		return light
	return null

/// Sidesteps most shots in the dark
/mob/living/basic/outpost_experiment/nightmare/proc/dodge(datum/source, obj/projectile/shot)
	SIGNAL_HANDLER
	if(stat != CONSCIOUS || !in_dark() || !prob(OUTPOST_NIGHTMARE_DODGE))
		return NONE
	visible_message(span_warning("[src] melts aside from [shot]!"))
	return PROJECTILE_INTERRUPT_HIT_PHASE

/// A handheld flash burns it, staggers it and throws it out of a jaunt
/mob/living/basic/outpost_experiment/nightmare/proc/on_attackby(datum/source, obj/item/attacking_item, mob/living/user, list/modifiers, list/attack_modifiers)
	SIGNAL_HANDLER
	var/obj/item/assembly/flash/flash = attacking_item
	if(!istype(flash) || stat == DEAD || flash.burnt_out || world.time < flash.last_trigger + flash.cooldown)
		return NONE
	INVOKE_ASYNC(flash, TYPE_PROC_REF(/obj/item/assembly/flash, try_use_flash), user)
	INVOKE_ASYNC(src, PROC_REF(flashed), user)
	return COMPONENT_NO_AFTERATTACK

/mob/living/basic/outpost_experiment/nightmare/proc/flashed(mob/living/user)
	var/datum/component/experiment_damage_ledger/ledger = GetComponent(/datum/component/experiment_damage_ledger)
	ledger?.note_attacker(user)
	cancel_jaunt()
	visible_message(span_danger("[src] shrieks and recoils from the flash!"))
	apply_damage(OUTPOST_NIGHTMARE_FLASH_DAMAGE, BURN)
	Stun(OUTPOST_NIGHTMARE_FLASH_STAGGER, ignore_canstun = TRUE)

/// A dark tile beside `target` it could jaunt to, if the jaunt is ready and it stands in the dark
/mob/living/basic/outpost_experiment/nightmare/proc/jaunt_spot_near(mob/living/target)
	if(jaunting || !COOLDOWN_FINISHED(src, jaunt_cooldown) || !in_dark())
		return null
	var/list/spots = list()
	for(var/turf/open/tile in orange(1, target))
		if(tile.is_blocked_turf(TRUE) || !in_dark(tile) || !prison?.outpost_holds(tile))
			continue
		spots += tile
	return length(spots) ? pick(spots) : null

/// Fades into the dark; a ripple and a whisper warn where it will come out, OUTPOST_NIGHTMARE_JAUNT_RIPPLE later
/mob/living/basic/outpost_experiment/nightmare/proc/start_jaunt(mob/living/target, turf/spot)
	jaunting = TRUE
	jaunt_spot = spot
	jaunt_target_ref = WEAKREF(target)
	COOLDOWN_START(src, jaunt_cooldown, OUTPOST_NIGHTMARE_JAUNT_COOLDOWN)
	ADD_TRAIT(src, TRAIT_IMMOBILIZED, REF(src))
	ai_controller?.CancelActions()
	animate(src, alpha = 0, time = 0.3 SECONDS)
	new /obj/effect/temp_visual/telegraphing/outpost_shadow_ripple(spot)
	playsound(spot, pick('sound/effects/hallucinations/behind_you1.ogg', 'sound/effects/hallucinations/behind_you2.ogg', 'sound/effects/hallucinations/i_see_you2.ogg'), 35, TRUE)
	addtimer(CALLBACK(src, PROC_REF(finish_jaunt)), OUTPOST_NIGHTMARE_JAUNT_RIPPLE, TIMER_DELETE_ME)

/// Comes out beside the target, if the spot is still dark, and strikes
/mob/living/basic/outpost_experiment/nightmare/proc/finish_jaunt()
	if(!jaunting)
		return FALSE
	var/turf/spot = jaunt_spot
	var/mob/living/target = jaunt_target_ref?.resolve()
	end_jaunt()
	if(stat == DEAD || !spot || !in_dark(spot) || spot.is_blocked_turf(TRUE))
		return FALSE
	forceMove(spot)
	if(!target || !Adjacent(target) || !can_target(target))
		return TRUE
	face_atom(target)
	do_attack_animation(target, ATTACK_EFFECT_SLASH)
	playsound(target, 'sound/items/weapons/bladeslice.ogg', 60, TRUE)
	target.visible_message(span_danger("[src] lunges out of the dark at [target]!"), span_userdanger("[src] lunges out of the dark at you!"))
	target.apply_damage(OUTPOST_NIGHTMARE_JAUNT_DAMAGE, BRUTE, wound_bonus = CANT_WOUND)
	target.Knockdown(OUTPOST_NIGHTMARE_JAUNT_KNOCKDOWN)
	return TRUE

/// Thrown out of a jaunt (light, a flash): back where it went in
/mob/living/basic/outpost_experiment/nightmare/proc/cancel_jaunt()
	if(!jaunting)
		return
	end_jaunt()
	visible_message(span_warning("[src] is forced out of the shadows!"))

/mob/living/basic/outpost_experiment/nightmare/proc/end_jaunt()
	jaunting = FALSE
	jaunt_spot = null
	jaunt_target_ref = null
	REMOVE_TRAIT(src, TRAIT_IMMOBILIZED, REF(src))
	animate(src, alpha = 255, time = 0.2 SECONDS)

/// Where the nightmare will come out of the dark
/obj/effect/temp_visual/telegraphing/outpost_shadow_ripple
	icon = 'icons/mob/telegraphing/telegraph.dmi'
	icon_state = "target_circle"
	color = "#2a0a3a"
	light_range = 0
	duration = OUTPOST_NIGHTMARE_JAUNT_RIPPLE

/// The nightmare's look: tg's light eater in hand
/datum/outfit/outpost_experiment_nightmare
	name = "Prison experiment nightmare"
	r_hand = /obj/item/light_eater

// ===== AI =====

/// Chases what the creature's own ai_think() picks, breaks what it may out of the way, and fights
/datum/ai_controller/basic_controller/outpost_experiment
	blackboard = list(
		BB_TARGETING_STRATEGY = /datum/targeting_strategy/outpost_experiment,
		BB_TARGET_MINIMUM_STAT = HARD_CRIT,
	)
	ai_movement = /datum/ai_movement/jps
	idle_behavior = /datum/idle_behavior/idle_random_walk
	planning_subtrees = list(
		/datum/ai_planning_subtree/outpost_experiment_think,
		/datum/ai_planning_subtree/attack_obstacle_in_path/outpost_experiment,
		/datum/ai_planning_subtree/basic_melee_attack_subtree,
	)

/// The fly person moves only in its own darts: no aimless steps, which would also crawl it about while knocked down
/datum/ai_controller/basic_controller/outpost_experiment/fly
	idle_behavior = null

/// The fly person's darts: straight hops that start at once
/datum/ai_movement/basic_avoidance/outpost_fly
	move_flags = MOVEMENT_LOOP_START_FAST

/**
 * A fly person's dart to the turf it picked (dart_spot()): done when it gets there, given up after
 * OUTPOST_FLY_DART_TIMEOUT. Planning goes on meanwhile, so a dart away from someone can cut a
 * random one short. A random dart is followed by a short pause.
 */
/datum/ai_behavior/outpost_fly_dart
	required_distance = 0
	action_cooldown = 0
	behavior_flags = AI_BEHAVIOR_REQUIRE_MOVEMENT | AI_BEHAVIOR_MOVE_AND_PERFORM | AI_BEHAVIOR_CAN_PLAN_DURING_EXECUTION

/datum/ai_behavior/outpost_fly_dart/setup(datum/ai_controller/controller, turf/destination)
	var/mob/living/basic/outpost_experiment/fly/fly = controller.pawn
	if(!istype(fly) || !isturf(destination) || destination.z != fly.z)
		return FALSE
	fly.dart_until = world.time + OUTPOST_FLY_DART_TIMEOUT
	set_movement_target(controller, destination, /datum/ai_movement/basic_avoidance/outpost_fly)
	return ..()

/datum/ai_behavior/outpost_fly_dart/perform(seconds_per_tick, datum/ai_controller/controller, turf/destination)
	var/mob/living/basic/outpost_experiment/fly/fly = controller.pawn
	if(!istype(fly) || world.time >= fly.dart_until)
		return AI_BEHAVIOR_DELAY | AI_BEHAVIOR_FAILED
	if(get_turf(fly) == destination)
		return AI_BEHAVIOR_DELAY | AI_BEHAVIOR_SUCCEEDED
	return AI_BEHAVIOR_DELAY

/datum/ai_behavior/outpost_fly_dart/finish_action(datum/ai_controller/controller, succeeded, turf/destination)
	// A dart that took over from this one has set its own movement; leave that be.
	var/moving_for_us = controller.movement_target_source == type
	. = ..()
	if(moving_for_us)
		controller.change_ai_movement_type(initial(controller.ai_movement))
	var/mob/living/basic/outpost_experiment/fly/fly = controller.pawn
	if(istype(fly))
		fly.next_dart = world.time + pause_after()

/// How long it hangs in the air after this dart before the next random one
/datum/ai_behavior/outpost_fly_dart/proc/pause_after()
	return rand(OUTPOST_FLY_DART_GAP_MIN, OUTPOST_FLY_DART_GAP_MAX)

/// Away from someone: no pause after it
/datum/ai_behavior/outpost_fly_dart/away

/datum/ai_behavior/outpost_fly_dart/away/pause_after()
	return 0

/// The fly person hanging in the air between darts. Planning goes on, so it notices anyone coming at once.
/datum/ai_behavior/outpost_fly_hover
	action_cooldown = 0
	behavior_flags = AI_BEHAVIOR_CAN_PLAN_DURING_EXECUTION

/datum/ai_behavior/outpost_fly_hover/perform(seconds_per_tick, datum/ai_controller/controller)
	var/mob/living/basic/outpost_experiment/fly/fly = controller.pawn
	if(!istype(fly) || world.time >= fly.next_dart)
		return AI_BEHAVIOR_DELAY | AI_BEHAVIOR_SUCCEEDED
	return AI_BEHAVIOR_DELAY

/// The creature decides what it is after
/datum/ai_planning_subtree/outpost_experiment_think

/datum/ai_planning_subtree/outpost_experiment_think/SelectBehaviors(datum/ai_controller/controller, seconds_per_tick)
	var/mob/living/basic/outpost_experiment/creature = controller.pawn
	if(!istype(creature) || creature.subdued)
		return SUBTREE_RETURN_FINISH_PLANNING
	creature.track_reach(controller)
	return creature.ai_think(controller)

/// Only what the creature may break
/datum/ai_planning_subtree/attack_obstacle_in_path/outpost_experiment
	attack_behaviour = /datum/ai_behavior/attack_obstructions/outpost_experiment

/datum/ai_behavior/attack_obstructions/outpost_experiment

/datum/ai_behavior/attack_obstructions/outpost_experiment/attack_in_direction(datum/ai_controller/controller, mob/living/basic/basic_mob, direction)
	var/mob/living/basic/outpost_experiment/creature = basic_mob
	if(!istype(creature))
		return FALSE
	var/turf/next_step = get_step(basic_mob, direction)
	if(!next_step?.is_blocked_turf(exclude_mobs = TRUE, source_atom = basic_mob))
		return FALSE
	for(var/obj/object in next_step)
		if(!object.density || object.IsObscured() || !creature.can_break(object))
			continue
		return creature.break_obstacle(object)
	if(isclosedturf(next_step) && creature.can_break(next_step))
		return creature.break_obstacle(next_step)
	return FALSE

/// A creature's targets are whatever its can_target() says, in reach on its level
/datum/targeting_strategy/outpost_experiment

/datum/targeting_strategy/outpost_experiment/can_attack(mob/living/living_mob, atom/target, vision_range)
	var/mob/living/basic/outpost_experiment/creature = living_mob
	if(!istype(creature) || QDELETED(target) || !isturf(creature.loc))
		return FALSE
	var/turf/target_turf = get_turf(target)
	if(!target_turf || target_turf.z != creature.z)
		return FALSE
	if(vision_range && get_dist(creature, target) > vision_range)
		return FALSE
	return creature.can_target(target)
