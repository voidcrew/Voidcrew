/**
 * # What the serum makes of a prisoner
 *
 * The serum (outpost_prison_experiments.dm) works on the subject's own body, with tg's own biology
 * (human NPC migration, phase E2; owner defaults EX-1 to EX-15):
 * - The hulk: tg's hulk gene (it shrugs off stuns and shoves, punches walls down and people about, and
 *   loses it when the body drops into crit) and tg's gigantism for its size. It charges with a roar and a
 *   line on the floor, staggers when it hits a wall, forces doors, smashes furniture in its way and knocks
 *   standing prisoners flat. Beaten into crit it is an ordinary person again, and batons and cuffs work.
 * - The fly person: tg's fly species (a flyswatter does thirty times the damage, and it throws up what it
 *   eats). It darts about the wing, away from anyone close and from whoever just hit it, hits back only
 *   when cornered, and goes for any food it sees. Its sidestep is a Slipwire implant (owner ruling OC-6),
 *   which burns out with it like any NPC's chrome.
 * - The nightmare: tg's nightmare species and organs (it heals and slips shots in the dark, burns in the
 *   light, a flash sears it, its light eater breaks lights and puts out torches). It spends its first
 *   half minute breaking the lights, then hunts prisoners, sinking into the dark and coming out beside one
 *   after a warning ripple.
 *
 * The body stays a body: wounds, blood, crit, cuffs, stamina, sedatives, death and revival are tg's. Its
 * toughness is physiology (npc_damage_taken), never health, and never scaled by who is about. Its hits on
 * people go through armour and wound like anyone's (EX-7). Kessler's team collects it only once it is down
 * (outpost_experiment_down_state()), and pays by the state it finds it in.
 *
 * The form is a component on the prisoner's own body (human NPC phase E1): the serum turns the inmate, who
 * leaves the prison's roster (transform_subject(), outpost_prisoner/proc/stand_down_for_experiment()) but
 * keeps their name, face, wounds and blood.
 */

/// Trait source for what the form puts on a body
#define OUTPOST_EXPERIMENT_FORM_TRAIT "outpost_experiment_form"
/// Blackboard key of the food a fly person is going for
#define BB_OUTPOST_FLY_MEAL "BB_outpost_fly_meal"

// ===== TURNING =====

/// The form component for a serum form, or null
/proc/outpost_experiment_form_type(form)
	switch(form)
		if("hulk")
			return /datum/component/outpost_experiment_form/hulk
		if("fly")
			return /datum/component/outpost_experiment_form/fly
		if("nightmare")
			return /datum/component/outpost_experiment_form/nightmare
	return null

/// What a creature is: a serum form ("hulk", "fly", "nightmare"), the changeling's "horror" or "headslug", or null
/proc/outpost_experiment_form_name(mob/living/creature)
	if(!isliving(creature))
		return null
	var/datum/component/outpost_experiment_form/form = creature.GetComponent(/datum/component/outpost_experiment_form)
	if(form)
		return form.form
	if(istype(creature, /mob/living/basic/outpost_experiment/horror))
		return "horror"
	if(istype(creature, /mob/living/basic/headslug))
		return "headslug"
	return null

/// Whether `creature` is an experiment's creature: a body the serum took, or the changeling's horror
/proc/is_outpost_experiment_creature(mob/living/creature)
	if(!isliving(creature))
		return FALSE
	return istype(creature, /mob/living/basic/outpost_experiment) || !!creature.GetComponent(/datum/component/outpost_experiment_form)

/**
 * Turns `body` into serum `form` for `prison` where it stands. Returns the form, or null if it didn't take.
 * `personality` is the prisoner's, for its lines.
 */
/proc/outpost_experiment_turn(mob/living/carbon/human/body, form, datum/outpost_prison/prison, personality)
	var/form_type = outpost_experiment_form_type(form)
	if(!form_type || !ishuman(body) || QDELETED(body) || body.stat == DEAD)
		return null
	// One form to a body.
	if(body.GetComponent(/datum/component/outpost_experiment_form))
		return null
	var/datum/component/outpost_experiment_form/turned = body.AddComponent(form_type, prison, personality)
	if(!istype(turned))
		return null
	turned.change_body()
	return turned

// ===== THE FORM =====

/**
 * A serum form on a body: its biology, its mind (an AI) and its side, what it says and does now and then,
 * and how it chooses whom to go for. See the file header.
 */
/datum/component/outpost_experiment_form
	dupe_mode = COMPONENT_DUPE_UNIQUE
	/// "hulk", "fly" or "nightmare"
	var/form
	/// What the log calls it: "a hulk"
	var/form_name = "a creature"
	/// Brute and burn damage it takes as a multiple of a person's (physiology, npc_damage_taken)
	var/damage_taken = 1
	/// The AI it thinks with
	var/controller_type = /datum/ai_controller/basic_controller/human_npc/outpost_experiment
	/// Dialogue context it says now and then, and seconds to the next line
	var/line_context
	var/line_left = 10
	/// A tell on examine: something anyone watching it would notice
	var/win_hint
	/// What everyone sees when it goes down alive, after its name
	var/down_message = "collapses, spent."
	/// Emotes it gives now and then lying there alive, waiting for Kessler
	var/list/down_emotes = list("twitches.", "groans.", "stirs weakly.")
	/// The prison it came from
	var/datum/outpost_prison/prison
	/// The prisoner's personality, for its lines
	var/personality
	/// The body has changed (change_body())
	var/changed = FALSE
	/// The target it is chasing now, the closest it has got to it, where it last stood, and when it last got
	/// anywhere: to notice it is stuck (track_reach())
	var/datum/weakref/chase_target_ref
	var/chase_best_distance = 0
	var/turf/chase_last_turf
	var/chase_progress_time = 0
	/// Targets it has given up on reaching -> world.time it may try them again
	var/list/unreachable_until

/datum/component/outpost_experiment_form/Initialize(datum/outpost_prison/owner, personality)
	if(!ishuman(parent))
		return COMPONENT_INCOMPATIBLE
	prison = owner
	src.personality = personality

/datum/component/outpost_experiment_form/RegisterWithParent()
	var/mob/living/carbon/human/body = parent
	body.add_traits(list(TRAIT_OUTPOST_EXPERIMENT, TRAIT_NO_CONTAINMENT, TRAIT_NO_STORAGE_INSERT), OUTPOST_EXPERIMENT_FORM_TRAIT)
	RegisterSignal(body, COMSIG_MOVABLE_TELEPORTING, PROC_REF(refuse_teleport))
	RegisterSignal(body, COMSIG_LIVING_PRE_WABBAJACKED, PROC_REF(refuse_polymorph))
	RegisterSignal(body, COMSIG_PRE_MOB_CHANGED_TYPE, PROC_REF(refuse_type_change))
	RegisterSignal(body, COMSIG_LIVING_LIFE, PROC_REF(on_life))
	RegisterSignal(body, COMSIG_ATOM_EXAMINE, PROC_REF(on_examine))

/datum/component/outpost_experiment_form/UnregisterFromParent()
	var/mob/living/carbon/human/body = parent
	body.remove_traits(list(TRAIT_OUTPOST_EXPERIMENT, TRAIT_NO_CONTAINMENT, TRAIT_NO_STORAGE_INSERT), OUTPOST_EXPERIMENT_FORM_TRAIT)
	UnregisterSignal(body, list(COMSIG_MOVABLE_TELEPORTING, COMSIG_LIVING_PRE_WABBAJACKED, COMSIG_PRE_MOB_CHANGED_TYPE, COMSIG_LIVING_LIFE, COMSIG_ATOM_EXAMINE))

/datum/component/outpost_experiment_form/Destroy(force)
	prison = null
	chase_target_ref = null
	chase_last_turf = null
	unreachable_until = null
	return ..()

/**
 * The change: the tells come off, the body takes the form's biology (change_biology()), its side, its
 * toughness and its AI, and everyone in sight sees it happen. Once.
 */
/datum/component/outpost_experiment_form/proc/change_body()
	if(changed)
		return
	changed = TRUE
	var/mob/living/carbon/human/body = parent
	outpost_experiment_clear_tells(body)
	var/old_name = body.real_name
	change_biology(body)
	// A species can rename the body (nightmares do); it is still the prisoner.
	if(body.real_name != old_name)
		body.fully_replace_character_name(body.real_name, old_name)
	body.faction = list(FACTION_OUTPOST_EXPERIMENT)
	if(ishumannpc(body))
		var/mob/living/carbon/human/npc/npc = body
		npc.set_npc_toughness(damage_taken)
	QDEL_NULL(body.ai_controller)
	var/datum/ai_controller/brain = new controller_type(body)
	setup_controller(brain)
	announce_change(body)

/// What the form does to the body's biology. Each form's own.
/datum/component/outpost_experiment_form/proc/change_biology(mob/living/carbon/human/body)
	return

/// Readies a new AI for the form: its abilities' blackboard keys
/datum/component/outpost_experiment_form/proc/setup_controller(datum/ai_controller/brain)
	return

/// What everyone in sight sees as the serum takes
/datum/component/outpost_experiment_form/proc/announce_change(mob/living/carbon/human/body)
	return

/datum/component/outpost_experiment_form/proc/refuse_teleport(datum/source, atom/destination, channel)
	SIGNAL_HANDLER
	var/mob/living/body = parent
	if(isturf(body.loc))
		body.visible_message(span_notice("[body] flickers for a moment, but stays where [body.p_they()] [body.p_are()]."))
	return TRUE

/datum/component/outpost_experiment_form/proc/refuse_polymorph(datum/source, what_to_randomize)
	SIGNAL_HANDLER
	var/mob/living/body = parent
	body.visible_message(span_notice("[body] shimmers for a moment, then looks the same as before."))
	return STOP_WABBAJACK

/datum/component/outpost_experiment_form/proc/refuse_type_change(datum/source)
	SIGNAL_HANDLER
	return COMPONENT_BLOCK_MOB_CHANGE

/datum/component/outpost_experiment_form/proc/on_examine(datum/source, mob/user, list/examine_list)
	SIGNAL_HANDLER
	var/mob/living/body = parent
	if(HAS_TRAIT_FROM(body, TRAIT_IMMOBILIZED, OUTPOST_KESSLER_TRAIT))
		examine_list += span_notice("Kessler Biolabs is taking [body.p_them()] away.")
	else if(prison?.experiment_awaiting_pickup(body))
		examine_list += span_notice("[body.p_They()] [body.p_are()] down. Kessler Biolabs will collect [body.p_them()] shortly.")
	else if(win_hint && body.stat == CONSCIOUS)
		examine_list += span_notice(win_hint)

/// Whether its AI runs: only while someone is on the level, like everything else in the wing
/datum/component/outpost_experiment_form/proc/awake()
	var/mob/living/body = parent
	return body.ai_controller?.ai_status == AI_STATUS_ON

/// Each Life() tick while someone is about: its own doings and a line now and then while it is up, a twitch while it lies waiting for Kessler
/datum/component/outpost_experiment_form/proc/on_life(mob/living/carbon/human/body, seconds_per_tick, times_fired)
	SIGNAL_HANDLER
	if(body.stat == DEAD || HAS_TRAIT_FROM(body, TRAIT_IMMOBILIZED, OUTPOST_KESSLER_TRAIT))
		return
	if(prison?.experiment_awaiting_pickup(body))
		if(prob(60))
			down_twitch(body)
		return
	if(body.stat != CONSCIOUS || !awake())
		return
	form_life(body, seconds_per_tick)
	if(!line_context)
		return
	line_left -= seconds_per_tick
	if(line_left > 0)
		return
	line_left = rand(15, 25)
	var/line = outpost_experiment_line(line_context, personality)
	if(line)
		INVOKE_ASYNC(body, TYPE_PROC_REF(/atom/movable, say), line)

/// Each Life() tick while it is up: what it does besides fighting
/datum/component/outpost_experiment_form/proc/form_life(mob/living/carbon/human/body, seconds_per_tick)
	return

/// Lying there alive, waiting for Kessler
/datum/component/outpost_experiment_form/proc/down_twitch(mob/living/carbon/human/body)
	body.Shake(1, 0, 0.4 SECONDS)
	if(prob(30))
		INVOKE_ASYNC(body, TYPE_PROC_REF(/atom, manual_emote), pick(down_emotes))

/// Makes the hand it fights with the active one, before a blow at `target`
/datum/component/outpost_experiment_form/proc/ready_to_hit(atom/target)
	return human_npc_ready_empty_hand(parent)

// ----- whom it goes for -----

/// Whether it goes after `target`. By default only its victims (is_victim()); the fly adds food, the nightmare lights.
/datum/component/outpost_experiment_form/proc/can_target(atom/target)
	return is_victim(target)

/// People, borgs and prisoners, never its own kind or Kessler's staff
/datum/component/outpost_experiment_form/proc/is_victim(atom/target)
	var/mob/living/victim = target
	if(!istype(victim) || victim == parent || victim.stat == DEAD)
		return FALSE
	if(is_outpost_experiment_mob(victim) || HAS_TRAIT(victim, TRAIT_GODMODE))
		return FALSE
	if(is_outpost_prisoner(victim))
		var/mob/living/carbon/human/npc/outpost_prisoner/prisoner = victim
		if(prisoner.phase != PRISONER_PRESENT || !may_hit_prisoner(prisoner))
			return FALSE
		return !blocked_by_cell(prisoner)
	return ishuman(victim) || issilicon(victim) || !isnull(victim.mind)

/// Whether it hits this prisoner
/datum/component/outpost_experiment_form/proc/may_hit_prisoner(mob/living/prisoner)
	return TRUE

/// How much less it wants a target than its distance says; prisoners and people may count differently
/datum/component/outpost_experiment_form/proc/target_penalty(mob/living/target)
	return 0

/**
 * Its target now: whoever hurt it lately, else the nearest it wants in sight. While nobody from the
 * wing is home it fights back but hunts nobody, so a loose creature is never a trap left for visitors.
 */
/datum/component/outpost_experiment_form/proc/choose_target()
	var/mob/living/body = parent
	var/datum/component/experiment_damage_ledger/ledger = body.GetComponent(/datum/component/experiment_damage_ledger)
	var/mob/living/attacker = ledger?.recent_player()
	if(attacker && can_target(attacker) && get_dist(body, attacker) <= 9 && can_see(body, attacker, 9) && !target_unreachable(attacker))
		return attacker
	if(prison && !prison.crew_home())
		return null
	var/mob/living/best
	var/best_score = INFINITY
	for(var/mob/living/candidate in range(7, body))
		if(!can_target(candidate) || !can_see(body, candidate, 7) || target_unreachable(candidate))
			continue
		var/score = get_dist(body, candidate) + target_penalty(candidate)
		if(score < best_score)
			best = candidate
			best_score = score
	return best

/**
 * Its AI's first thought each plan: picks the target and may queue something of its own. Returns
 * SUBTREE_RETURN_FINISH_PLANNING when that is all it does this plan.
 */
/datum/component/outpost_experiment_form/proc/ai_think(datum/ai_controller/controller)
	var/atom/target = choose_target()
	if(target)
		controller.set_blackboard_key(BB_BASIC_MOB_CURRENT_TARGET, target)
	else
		controller.clear_blackboard_key(BB_BASIC_MOB_CURRENT_TARGET)
	return null

// ----- reach -----

/// Whether nothing shut stops it: the hulk goes through walls and doors, so a bolted cell never keeps it out
/datum/component/outpost_experiment_form/proc/smashes_through()
	return FALSE

/// Whether it is between moves by design (mid-jaunt), and should not be judged on progress
/datum/component/outpost_experiment_form/proc/chasing_paused()
	return FALSE

/// Whether a bolted cell keeps `prisoner` away from it: shut and locked, and it is not inside with them
/datum/component/outpost_experiment_form/proc/blocked_by_cell(mob/living/prisoner)
	if(smashes_through())
		return FALSE
	var/datum/outpost_prison_cell/holding = prison?.cell_at(get_turf(prisoner))
	return holding && holding.is_bolted() && !holding.contains(parent)

/**
 * Notes whether it is getting anywhere with `controller`'s current target: closer, beside it, or at least
 * on the move. OUTPOST_EXPERIMENT_STUCK_TIME standing still and apart writes the target off as unreachable
 * for OUTPOST_EXPERIMENT_UNREACHABLE_TIME. Distance and Adjacent() only: no pathfinding call.
 */
/datum/component/outpost_experiment_form/proc/track_reach(datum/ai_controller/controller)
	if(smashes_through() || chasing_paused())
		return
	var/mob/living/body = parent
	var/atom/movable/target = controller.blackboard[BB_BASIC_MOB_CURRENT_TARGET]
	if(QDELETED(target))
		chase_target_ref = null
		return
	if(chase_target_ref?.resolve() != target)
		chase_target_ref = WEAKREF(target)
		chase_best_distance = get_dist(body, target)
		chase_last_turf = body.loc
		chase_progress_time = world.time
		return
	if(body.Adjacent(target) || body.loc != chase_last_turf)
		chase_last_turf = body.loc
		chase_progress_time = world.time
		return
	var/distance = get_dist(body, target)
	if(distance < chase_best_distance)
		chase_best_distance = distance
		chase_progress_time = world.time
		return
	if(world.time - chase_progress_time < OUTPOST_EXPERIMENT_STUCK_TIME)
		return
	mark_unreachable(target)
	chase_target_ref = null

/// Whether it gave up on reaching `target` recently
/datum/component/outpost_experiment_form/proc/target_unreachable(atom/target)
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

/// Writes `target` off for OUTPOST_EXPERIMENT_UNREACHABLE_TIME
/datum/component/outpost_experiment_form/proc/mark_unreachable(atom/target)
	LAZYSET(unreachable_until, WEAKREF(target), world.time + OUTPOST_EXPERIMENT_UNREACHABLE_TIME)
	for(var/datum/weakref/ref as anything in unreachable_until.Copy())
		if(unreachable_until[ref] <= world.time)
			unreachable_until -= ref
	while(length(unreachable_until) > OUTPOST_EXPERIMENT_UNREACHABLE_MAX)
		unreachable_until.Cut(1, 2)

// ----- breaking things -----

/// Whether it may break `thing` out of its way. Only the hulk does.
/datum/component/outpost_experiment_form/proc/can_break(atom/thing)
	return FALSE

/// Breaks `thing` out of its way. Returns TRUE if it set about it.
/datum/component/outpost_experiment_form/proc/break_obstacle(atom/thing, datum/ai_controller/controller)
	return FALSE

// ===== HULK =====

/datum/component/outpost_experiment_form/hulk
	form = "hulk"
	form_name = "a hulk"
	damage_taken = OUTPOST_HULK_DAMAGE_TAKEN
	line_context = "hulk"
	/// Its charge
	var/datum/action/cooldown/mob_cooldown/charge/basic_charge/outpost_hulk/charge

/datum/component/outpost_experiment_form/hulk/Destroy(force)
	QDEL_NULL(charge)
	return ..()

/datum/component/outpost_experiment_form/hulk/UnregisterFromParent()
	UnregisterSignal(parent, list(COMSIG_LIVING_EARLY_UNARMED_ATTACK, SIGNAL_REMOVETRAIT(TRAIT_HULK)))
	return ..()

/datum/component/outpost_experiment_form/hulk/change_biology(mob/living/carbon/human/body)
	// tg's hulk gene takes only on a human body: the serum makes one of whatever it finds.
	if(body.dna.species.id != SPECIES_HUMAN)
		body.set_species(/datum/species/human)
	// Before the gene: handlers of one signal run in the order they were registered, and on_punch() must
	// see the target's health before the gene's own handler lands the blow.
	RegisterSignal(body, COMSIG_LIVING_EARLY_UNARMED_ATTACK, PROC_REF(on_punch))
	body.dna.add_mutation(/datum/mutation/hulk, MUTATION_SOURCE_MUTATOR)
	body.dna.add_mutation(/datum/mutation/gigantism, MUTATION_SOURCE_MUTATOR)
	charge = new(body)
	charge.Grant(body)
	RegisterSignal(body, SIGNAL_REMOVETRAIT(TRAIT_HULK), PROC_REF(on_hulk_lost))

/datum/component/outpost_experiment_form/hulk/setup_controller(datum/ai_controller/brain)
	brain.set_blackboard_key(BB_TARGETED_ACTION, charge)

/datum/component/outpost_experiment_form/hulk/announce_change(mob/living/carbon/human/body)
	playsound(body, 'sound/mobs/non-humanoids/gorilla/gorilla.ogg', 80, TRUE)
	body.visible_message(span_danger("[body] swells until [body.p_their()] jumpsuit strains at the seams, and roars!"))

/// Players first, then prisoners still on their feet
/datum/component/outpost_experiment_form/hulk/target_penalty(mob/living/target)
	return is_outpost_prisoner(target) ? 3 : 0

/// Only prisoners still standing: it knocks them flat and leaves them
/datum/component/outpost_experiment_form/hulk/may_hit_prisoner(mob/living/prisoner)
	return prisoner.stat == CONSCIOUS && prisoner.body_position == STANDING_UP

/// While it is a hulk it goes through walls and forces doors, so a bolted cell never stops it
/datum/component/outpost_experiment_form/hulk/smashes_through()
	return HAS_TRAIT(parent, TRAIT_HULK)

/datum/component/outpost_experiment_form/hulk/ai_think(datum/ai_controller/controller)
	. = ..()
	var/mob/living/body = parent
	var/mob/living/target = controller.blackboard[BB_BASIC_MOB_CURRENT_TARGET]
	if(!HAS_TRAIT(body, TRAIT_HULK) || !isliving(target) || !charge?.IsAvailable())
		return
	var/distance = get_dist(body, target)
	if(distance < 2 || distance > OUTPOST_HULK_CHARGE_RANGE || !can_see(body, target, OUTPOST_HULK_CHARGE_RANGE))
		return
	controller.queue_behavior(/datum/ai_behavior/targeted_mob_ability, BB_TARGETED_ACTION, BB_BASIC_MOB_CURRENT_TARGET)
	return SUBTREE_RETURN_FINISH_PLANNING

/// A hulk punch is tg's (the gene answers this signal too); what it did to the target shows a tick later
/datum/component/outpost_experiment_form/hulk/proc/on_punch(mob/living/carbon/human/source, atom/target, proximity, list/modifiers)
	SIGNAL_HANDLER
	if(!source.combat_mode || !proximity || !isliving(target) || target == source || !HAS_TRAIT(source, TRAIT_HULK))
		return NONE
	var/mob/living/victim = target
	addtimer(CALLBACK(src, PROC_REF(after_punch), WEAKREF(victim), victim.health), 0, TIMER_DELETE_ME)
	return NONE

/// A blow that landed: a standing prisoner goes down, and anyone else may go flying
/datum/component/outpost_experiment_form/hulk/proc/after_punch(datum/weakref/victim_ref, health_before)
	var/mob/living/carbon/human/body = parent
	var/mob/living/victim = victim_ref?.resolve()
	if(QDELETED(victim) || QDELETED(body) || victim.stat == DEAD || victim.health >= health_before)
		return
	if(is_outpost_prisoner(victim))
		if(victim.body_position != STANDING_UP)
			return
		victim.visible_message(span_danger("[body] knocks [victim] flat!"))
		playsound(victim, 'sound/items/weapons/punch1.ogg', 60, TRUE)
		victim.Knockdown(OUTPOST_HULK_KNOCKDOWN)
		return
	if(!prob(OUTPOST_HULK_THROW_CHANCE) || victim.anchored || victim.buckled || victim.move_resist >= MOVE_FORCE_OVERPOWERING)
		return
	victim.visible_message(span_danger("[body] sends [victim] flying!"))
	victim.throw_at(get_ranged_target_turf(victim, get_dir(body, victim), OUTPOST_HULK_THROW_RANGE), OUTPOST_HULK_THROW_RANGE, 1, body)

/// Down into crit, the gene let go of it (tg's hulk): it is an ordinary person again
/datum/component/outpost_experiment_form/hulk/proc/on_hulk_lost(mob/living/carbon/human/source)
	SIGNAL_HANDLER
	if(source.stat == DEAD)
		return
	source.visible_message(span_warning("[source] staggers, heaving for breath. [source.p_They()] look[source.p_s()] spent."))

/// Charged into a wall with nobody caught: stunned a moment, the way any charger is
/datum/component/outpost_experiment_form/hulk/proc/stagger_on_wall()
	var/mob/living/body = parent
	body.Stun(OUTPOST_HULK_WALL_STUN, ignore_canstun = TRUE)

/// Interior walls, windows, grilles, tables, chairs and doors, never the hatch counters or anything protected
/datum/component/outpost_experiment_form/hulk/can_break(atom/thing)
	if(!HAS_TRAIT(parent, TRAIT_HULK) || QDELETED(thing) || !outpost_experiment_can_smash(thing, prison))
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

/datum/component/outpost_experiment_form/hulk/break_obstacle(atom/thing, datum/ai_controller/controller)
	if(!can_break(thing))
		return FALSE
	if(istype(thing, /obj/machinery/door/airlock))
		INVOKE_ASYNC(src, PROC_REF(force_door), thing)
		return TRUE
	if(isturf(thing))
		// tg's hulk smash: a few blows bring an interior wall down, and hurt the arm doing it.
		if(!human_npc_ready_empty_hand(parent))
			return FALSE
		controller.ai_interact(target = thing, combat_mode = TRUE)
		return TRUE
	smash(thing)
	return TRUE

/// Batters a door until it gives: bolts sheared, weld broken, forced open
/datum/component/outpost_experiment_form/hulk/proc/force_door(obj/machinery/door/airlock/door)
	var/mob/living/body = parent
	if(DOING_INTERACTION_WITH_TARGET(body, door) || !door.density)
		return FALSE
	body.visible_message(span_danger("[body] batters at [door]!"))
	playsound(door, 'sound/effects/bang.ogg', 70, TRUE)
	door.Shake(2, 2, 0.5 SECONDS)
	if(!do_after(body, OUTPOST_HULK_DOOR_TIME, target = door) || QDELETED(door) || !can_break(door))
		return FALSE
	if(door.locked)
		door.unbolt()
	if(door.welded)
		door.welded = FALSE
		door.update_appearance()
	door.visible_message(span_danger("[body] forces [door] open!"))
	playsound(door, 'sound/machines/airlock/airlock_alien_prying.ogg', 80, TRUE)
	INVOKE_ASYNC(door, TYPE_PROC_REF(/obj/machinery/door, open), BYPASS_DOOR_CHECKS)
	prison?.refresh_reach()
	return TRUE

/// Puts something through: windows shatter, tables fold, chairs splinter, window doors break
/datum/component/outpost_experiment_form/hulk/proc/smash(obj/thing)
	if(QDELETED(thing))
		return FALSE
	var/mob/living/body = parent
	body.do_attack_animation(thing, ATTACK_EFFECT_SMASH)
	body.visible_message(span_danger("[body] smashes [thing]!"))
	playsound(thing, istype(thing, /obj/structure/window) ? 'sound/effects/glass/glassbr1.ogg' : 'sound/effects/woodhit.ogg', 70, TRUE)
	thing.take_damage(thing.get_integrity(), BRUTE, MELEE, FALSE, get_dir(thing, body))
	return TRUE

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

/// The hulk's form, if `charger` is a hulk
/datum/action/cooldown/mob_cooldown/charge/basic_charge/outpost_hulk/proc/hulk_form(atom/movable/charger)
	return charger.GetComponent(/datum/component/outpost_experiment_form/hulk)

/datum/action/cooldown/mob_cooldown/charge/basic_charge/outpost_hulk/on_bump(atom/movable/source, atom/target)
	var/datum/component/outpost_experiment_form/hulk/hulk = hulk_form(source)
	if(hulk && isobj(target) && target.density && !istype(target, /obj/machinery/door/airlock) && hulk.can_break(target))
		INVOKE_ASYNC(hulk, TYPE_PROC_REF(/datum/component/outpost_experiment_form/hulk, smash), target)
		return
	return ..()

/datum/action/cooldown/mob_cooldown/charge/basic_charge/outpost_hulk/on_moved(atom/source)
	. = ..()
	var/datum/component/outpost_experiment_form/hulk/hulk = hulk_form(source)
	if(!hulk)
		return
	for(var/obj/structure/chair/chair in get_turf(source))
		if(hulk.can_break(chair))
			INVOKE_ASYNC(hulk, TYPE_PROC_REF(/datum/component/outpost_experiment_form/hulk, smash), chair)

/datum/action/cooldown/mob_cooldown/charge/basic_charge/outpost_hulk/hit_target(atom/movable/source, atom/target, damage_dealt)
	var/datum/component/outpost_experiment_form/hulk/hulk = hulk_form(source)
	if(isliving(target))
		var/mob/living/victim = target
		// A prisoner is bowled over; anyone else takes the full charge, through their armour (EX-7).
		if(!is_outpost_prisoner(victim))
			outpost_experiment_ability_hit(victim, damage_dealt, attacker = source)
			playsound(get_turf(victim), 'sound/effects/meteorimpact.ogg', 80, TRUE)
		return ..()
	source.visible_message(span_danger("[source] slams into [target] and reels!"))
	playsound(get_turf(source), 'sound/effects/bang.ogg', 80, TRUE)
	hulk?.stagger_on_wall()

/// The floor in the charge's path, for the length of the wind-up
/obj/effect/temp_visual/telegraphing/outpost_hulk_charge
	duration = OUTPOST_HULK_CHARGE_WINDUP
	color = "#9ae05a"

// ===== FLY PERSON =====

/datum/component/outpost_experiment_form/fly
	form = "fly"
	form_name = "a fly person"
	damage_taken = OUTPOST_FLY_DAMAGE_TAKEN
	line_context = "fly"
	controller_type = /datum/ai_controller/basic_controller/human_npc/outpost_experiment/fly
	win_hint = "It never stays still for long."
	down_message = "drops to the floor, stunned."
	down_emotes = list("buzzes weakly.", "twitches.", "trembles.")
	/// world.time of its next random dart, and by when the dart under way must be over
	var/next_dart = 0
	var/dart_until = 0
	/// Whoever hit it last, whom it keeps away from until flit_until
	var/datum/weakref/flit_from_ref
	var/flit_until = 0
	/// REF() of prisoners who watched it throw up -> world.time they may be put off again
	var/list/disgusted

/datum/component/outpost_experiment_form/fly/down_twitch(mob/living/carbon/human/body)
	. = ..()
	playsound(body, 'sound/mobs/non-humanoids/bee/bee.ogg', 15, TRUE)

/datum/component/outpost_experiment_form/fly/Destroy(force)
	flit_from_ref = null
	disgusted = null
	return ..()

/datum/component/outpost_experiment_form/fly/UnregisterFromParent()
	UnregisterSignal(parent, list(COMSIG_ATOM_WAS_ATTACKED, COMSIG_CARBON_VOMITED))
	return ..()

/datum/component/outpost_experiment_form/fly/change_biology(mob/living/carbon/human/body)
	body.set_species(/datum/species/fly)
	// Its quickness is real chrome (owner ruling OC-6), which an EMP scrambles and death burns out.
	if(ishumannpc(body))
		var/mob/living/carbon/human/npc/npc = body
		npc.npc_install_cyberware(/obj/item/organ/cyberimp/cyberware/slipwire)
	RegisterSignal(body, COMSIG_ATOM_WAS_ATTACKED, PROC_REF(on_attacked))
	RegisterSignal(body, COMSIG_CARBON_VOMITED, PROC_REF(on_vomited))

/datum/component/outpost_experiment_form/fly/announce_change(mob/living/carbon/human/body)
	playsound(body, 'sound/mobs/non-humanoids/bee/bee_swarm.ogg', 60, TRUE)
	body.visible_message(span_danger("[body] folds up, splits open and unfolds into something with bulging eyes and a proboscis!"))

/// On its feet and free to move: not down, held, cuffed, pulled, buckled or being taken away
/datum/component/outpost_experiment_form/fly/proc/free_to_dart()
	var/mob/living/body = parent
	if(body.stat != CONSCIOUS || !isturf(body.loc) || body.pulledby || body.buckled || body.body_position != STANDING_UP)
		return FALSE
	return !HAS_TRAIT(body, TRAIT_IMMOBILIZED) && !HAS_TRAIT(body, TRAIT_INCAPACITATED) && !HAS_TRAIT(body, TRAIT_RESTRAINED)

/// Hit while it is free to move: it flits away from whoever did it, and keeps away from them for a few seconds
/datum/component/outpost_experiment_form/fly/proc/on_attacked(datum/source, atom/attacker, attack_flags)
	SIGNAL_HANDLER
	if(!attacker || attacker == parent || !free_to_dart())
		return
	flit_from_ref = WEAKREF(attacker)
	flit_until = world.time + OUTPOST_FLY_FLIT_TIME
	// Once the blow is over, not in the middle of it.
	addtimer(CALLBACK(src, PROC_REF(flit)), 1, TIMER_UNIQUE | TIMER_OVERRIDE | TIMER_DELETE_ME)

/// Whoever hit it within OUTPOST_FLY_FLIT_TIME, if still near enough to keep away from
/datum/component/outpost_experiment_form/fly/proc/flit_threat()
	if(world.time > flit_until)
		return null
	var/mob/living/body = parent
	var/atom/movable/attacker = flit_from_ref?.resolve()
	if(QDELETED(attacker) || attacker.z != body.z || get_dist(body, attacker) > OUTPOST_FLY_DART_MAX + OUTPOST_FLY_FLEE_RANGE)
		return null
	return attacker

/// Darts away from whoever just hit it, at once rather than at its next thought. Returns TRUE if it went.
/datum/component/outpost_experiment_form/fly/proc/flit()
	var/mob/living/body = parent
	var/atom/attacker = flit_threat()
	if(!attacker || !free_to_dart() || !body.ai_controller || !awake())
		return FALSE
	var/turf/spot = dart_spot(attacker)
	if(!spot)
		return FALSE
	body.ai_controller.CancelActions()
	body.ai_controller.queue_behavior(/datum/ai_behavior/outpost_fly_dart/away, spot)
	return TRUE

/// It goes for food and hits only when cornered: its "targets" are meals, and people it cannot get away from
/datum/component/outpost_experiment_form/fly/can_target(atom/target)
	if(istype(target, /obj/item/food))
		return isturf(target.loc)
	return ..()

/// Whoever is closest within OUTPOST_FLY_FLEE_RANGE, to keep away from
/datum/component/outpost_experiment_form/fly/proc/nearest_threat()
	var/mob/living/body = parent
	var/mob/living/nearest
	var/nearest_distance = INFINITY
	for(var/mob/living/person in range(OUTPOST_FLY_FLEE_RANGE, body))
		if(person == body || !is_victim(person))
			continue
		var/distance = get_dist(body, person)
		if(distance < nearest_distance)
			nearest = person
			nearest_distance = distance
	return nearest

/**
 * Somewhere to dart to: an open tile OUTPOST_FLY_DART_MIN to OUTPOST_FLY_DART_MAX tiles off, in a clear
 * line, on ground it keeps to (may_dart_to()). Away from `threat`, only somewhere farther from it than it
 * is now, and out of its OUTPOST_FLY_FLEE_RANGE if it can. Null if there is nowhere: cornered.
 */
/datum/component/outpost_experiment_form/fly/proc/dart_spot(atom/threat)
	var/turf/here = get_turf(parent)
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
 * Whether it keeps to `tile`: free and safe, and in the wing (its cell block, while it is in there).
 * Got out of the wing, it darts about the room it is in.
 */
/datum/component/outpost_experiment_form/fly/proc/may_dart_to(turf/tile)
	var/mob/living/body = parent
	if(isspaceturf(tile) || isopenspaceturf(tile) || tile.is_blocked_turf(FALSE, body) || !tile.can_cross_safely(body))
		return FALSE
	var/turf/here = get_turf(body)
	if(prison?.wing && here.loc == prison.wing)
		return tile.loc == prison.wing && (!prison.in_cell_block(here) || prison.in_cell_block(tile))
	return tile.loc == here.loc

/// Whether it can go straight from `start` to `finish`: nothing solid or opaque in the way
/datum/component/outpost_experiment_form/fly/proc/clear_line(turf/start, turf/finish)
	for(var/turf/step as anything in get_line(start, finish))
		if(step == start)
			continue
		if(step.opacity || step.is_blocked_turf(TRUE, parent))
			return FALSE
	return TRUE

/**
 * Keeps moving: darts away from anyone close or who just hit it, and hits only when cornered with
 * someone at it. Otherwise it goes for food in sight, or darts about at random with short pauses. It
 * hovers (outpost_fly_hover) rather than planning nothing, so it notices people at once.
 */
/datum/component/outpost_experiment_form/fly/ai_think(datum/ai_controller/controller)
	var/mob/living/body = parent
	if(!free_to_dart())
		controller.clear_blackboard_key(BB_BASIC_MOB_CURRENT_TARGET)
		return null
	var/atom/threat = flit_threat() || nearest_threat()
	if(threat)
		var/turf/away = dart_spot(threat)
		if(away)
			controller.clear_blackboard_key(BB_BASIC_MOB_CURRENT_TARGET)
			controller.queue_behavior(/datum/ai_behavior/outpost_fly_dart/away, away)
			return SUBTREE_RETURN_FINISH_PLANNING
		// Nowhere farther to go: it hits whoever is at it.
		var/mob/living/at_it = threat
		if(istype(at_it) && body.Adjacent(at_it) && can_target(at_it))
			controller.set_blackboard_key(BB_BASIC_MOB_CURRENT_TARGET, at_it)
			return null
		controller.clear_blackboard_key(BB_BASIC_MOB_CURRENT_TARGET)
		controller.queue_behavior(/datum/ai_behavior/outpost_fly_hover)
		return SUBTREE_RETURN_FINISH_PLANNING
	controller.clear_blackboard_key(BB_BASIC_MOB_CURRENT_TARGET)
	var/obj/item/food/meal = held_meal() || find_meal()
	if(meal)
		controller.set_blackboard_key(BB_OUTPOST_FLY_MEAL, meal)
		controller.queue_behavior(/datum/ai_behavior/outpost_fly_eat, BB_OUTPOST_FLY_MEAL)
		return SUBTREE_RETURN_FINISH_PLANNING
	var/turf/spot = world.time >= next_dart ? dart_spot() : null
	if(spot)
		controller.queue_behavior(/datum/ai_behavior/outpost_fly_dart, spot)
		return SUBTREE_RETURN_FINISH_PLANNING
	if(world.time >= next_dart)
		next_dart = world.time + rand(OUTPOST_FLY_DART_GAP_MIN, OUTPOST_FLY_DART_GAP_MAX)
	controller.queue_behavior(/datum/ai_behavior/outpost_fly_hover)
	return SUBTREE_RETURN_FINISH_PLANNING

/// Food it has in hand already
/datum/component/outpost_experiment_form/fly/proc/held_meal()
	var/mob/living/carbon/human/body = parent
	for(var/obj/item/food/meal in body.held_items)
		return meal
	return null

/// The nearest food in sight: a serving hatch, a table or the floor
/datum/component/outpost_experiment_form/fly/proc/find_meal()
	var/mob/living/body = parent
	var/obj/item/food/best
	var/best_distance = INFINITY
	for(var/obj/item/food/meal in range(5, body))
		if(!isturf(meal.loc) || !can_see(body, meal, 5) || target_unreachable(meal))
			continue
		var/distance = get_dist(body, meal)
		if(distance < best_distance)
			best = meal
			best_distance = distance
	return best

/**
 * tg's fly stomach throws up what it eats (and the fly is a messy eater). Whoever it gets it on hears
 * about it, and prisoners who see it lose a little mood, each at most once in a while.
 */
/datum/component/outpost_experiment_form/fly/proc/on_vomited(mob/living/carbon/source, distance, force)
	SIGNAL_HANDLER
	var/turf/ahead = get_step(source, source.dir)
	var/mob/living/unlucky = ahead ? locate(/mob/living) in ahead : null
	if(unlucky && unlucky != source)
		source.visible_message(span_danger("[source] throws up all over [unlucky]!"))
	for(var/mob/living/carbon/human/npc/outpost_prisoner/watcher in viewers(5, source))
		if(watcher.stat != CONSCIOUS || LAZYACCESS(disgusted, REF(watcher)) > world.time)
			continue
		LAZYSET(disgusted, REF(watcher), world.time + OUTPOST_EXPERIMENT_FLY_DISGUST_GAP)
		watcher.adjust_mood(-OUTPOST_EXPERIMENT_FLY_DISGUST_MOOD)

// ===== NIGHTMARE =====

/datum/component/outpost_experiment_form/nightmare
	form = "nightmare"
	form_name = "a nightmare"
	damage_taken = OUTPOST_NIGHTMARE_DAMAGE_TAKEN
	/// Seconds left of breaking the lights before it hunts
	var/opening_left = OUTPOST_NIGHTMARE_OPENING_MIN
	/// Mid jaunt: gone into the dark, about to come out beside someone
	var/jaunting = FALSE
	/// Where it will come out, and at whom
	var/turf/jaunt_spot
	var/datum/weakref/jaunt_target_ref
	COOLDOWN_DECLARE(jaunt_cooldown)

/datum/component/outpost_experiment_form/nightmare/Destroy(force)
	jaunt_spot = null
	jaunt_target_ref = null
	return ..()

/datum/component/outpost_experiment_form/nightmare/UnregisterFromParent()
	if(jaunting)
		end_jaunt()
	UnregisterSignal(parent, COMSIG_MOB_FLASH_OVERRIDE_CHECK)
	return ..()

/datum/component/outpost_experiment_form/nightmare/change_biology(mob/living/carbon/human/body)
	// tg's nightmare: its brain heals it and slips shots in the dark, its heart grows the light eater, and
	// its shadow flesh burns in the light. It can wear nothing but a hat, so the jumpsuit falls off.
	body.set_species(/datum/species/shadow/nightmare)
	opening_left = rand(OUTPOST_NIGHTMARE_OPENING_MIN, OUTPOST_NIGHTMARE_OPENING_MAX)
	RegisterSignal(body, COMSIG_MOB_FLASH_OVERRIDE_CHECK, PROC_REF(on_flashed))

/datum/component/outpost_experiment_form/nightmare/announce_change(mob/living/carbon/human/body)
	playsound(body, 'sound/effects/hallucinations/wail.ogg', 60, TRUE)
	body.visible_message(span_danger("The light seems to drain out of [body], and something else stands where [body.p_they()] stood."))

/// Whether `tile` (where it stands, by default) is dark
/datum/component/outpost_experiment_form/nightmare/proc/in_dark(turf/tile = get_turf(parent))
	return tile && tile.get_lumcount() < SHADOW_SPECIES_LIGHT_THRESHOLD

/// The opening runs down; in the light a jaunt is cut short, and now and then it is seen to suffer
/datum/component/outpost_experiment_form/nightmare/form_life(mob/living/carbon/human/body, seconds_per_tick)
	if(opening_left > 0)
		opening_left -= seconds_per_tick
	if(in_dark())
		return
	if(jaunting)
		cancel_jaunt()
	if(prob(20))
		body.visible_message(span_warning("[body] smokes and shrinks from the light."))

/// Whether it is still breaking the lights: for its first half minute, until it is hurt, or until there are none
/datum/component/outpost_experiment_form/nightmare/proc/in_opening()
	if(opening_left <= 0)
		return FALSE
	var/mob/living/body = parent
	var/datum/component/experiment_damage_ledger/ledger = body.GetComponent(/datum/component/experiment_damage_ledger)
	if(ledger && (ledger.player_damage + ledger.other_damage + ledger.pending) > 0)
		opening_left = 0
		return FALSE
	return TRUE

/// Prisoners first, standing or down; it finishes what it starts
/datum/component/outpost_experiment_form/nightmare/target_penalty(mob/living/target)
	return is_outpost_prisoner(target) ? -3 : 0

/datum/component/outpost_experiment_form/nightmare/chasing_paused()
	return jaunting

/// Lights, during the opening
/datum/component/outpost_experiment_form/nightmare/can_target(atom/target)
	if(istype(target, /obj/machinery/light))
		var/obj/machinery/light/fixture = target
		return fixture.status != LIGHT_BROKEN && fixture.status != LIGHT_EMPTY
	return ..()

/// It fights with tg's light eater, which breaks lights and puts out torches as it cuts
/datum/component/outpost_experiment_form/nightmare/ready_to_hit(atom/target)
	var/mob/living/carbon/human/body = parent
	for(var/obj/item/light_eater/blade in body.held_items)
		return human_npc_ready_item(body, blade)
	return ..()

/// The nearest working light in sight
/datum/component/outpost_experiment_form/nightmare/proc/find_light()
	var/mob/living/body = parent
	var/obj/machinery/light/best
	var/best_distance = INFINITY
	for(var/obj/machinery/light/fixture in range(9, body))
		if(!can_target(fixture) || !can_see(body, fixture, 9) || target_unreachable(fixture))
			continue
		var/distance = get_dist(body, fixture)
		if(distance < best_distance)
			best = fixture
			best_distance = distance
	return best

/datum/component/outpost_experiment_form/nightmare/ai_think(datum/ai_controller/controller)
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
	if(!isliving(target) || get_dist(parent, target) <= 1)
		return
	var/turf/spot = jaunt_spot_near(target)
	if(!spot)
		return
	start_jaunt(target, spot)
	return SUBTREE_RETURN_FINISH_PLANNING

/// A flash sears it (tg's shadow flesh) and throws it out of a jaunt
/datum/component/outpost_experiment_form/nightmare/proc/on_flashed(datum/source, mob/living/carbon/flashed, flash, deviation)
	SIGNAL_HANDLER
	if(jaunting)
		cancel_jaunt()
	return NONE

/// A dark tile beside `target` it could come out on, if the jaunt is ready and it stands in the dark
/datum/component/outpost_experiment_form/nightmare/proc/jaunt_spot_near(mob/living/target)
	if(jaunting || !COOLDOWN_FINISHED(src, jaunt_cooldown) || !in_dark())
		return null
	var/list/spots = list()
	for(var/turf/open/tile in orange(1, target))
		if(tile.is_blocked_turf(TRUE) || !in_dark(tile) || !prison?.outpost_holds(tile))
			continue
		spots += tile
	return length(spots) ? pick(spots) : null

/// Sinks into the dark; a ripple and a whisper warn where it will come out, OUTPOST_NIGHTMARE_JAUNT_RIPPLE later
/datum/component/outpost_experiment_form/nightmare/proc/start_jaunt(mob/living/target, turf/spot)
	var/mob/living/body = parent
	jaunting = TRUE
	jaunt_spot = spot
	jaunt_target_ref = WEAKREF(target)
	COOLDOWN_START(src, jaunt_cooldown, OUTPOST_NIGHTMARE_JAUNT_COOLDOWN)
	ADD_TRAIT(body, TRAIT_IMMOBILIZED, OUTPOST_EXPERIMENT_FORM_TRAIT)
	body.ai_controller?.CancelActions()
	animate(body, alpha = 0, time = 0.3 SECONDS)
	new /obj/effect/temp_visual/telegraphing/outpost_shadow_ripple(spot)
	playsound(spot, pick('sound/effects/hallucinations/behind_you1.ogg', 'sound/effects/hallucinations/behind_you2.ogg', 'sound/effects/hallucinations/i_see_you2.ogg'), 35, TRUE)
	addtimer(CALLBACK(src, PROC_REF(finish_jaunt)), OUTPOST_NIGHTMARE_JAUNT_RIPPLE, TIMER_DELETE_ME)

/// Comes out beside the target, if the spot is still dark, and lunges: a blade through the armour on them (EX-7)
/datum/component/outpost_experiment_form/nightmare/proc/finish_jaunt()
	if(!jaunting)
		return FALSE
	var/mob/living/body = parent
	var/turf/spot = jaunt_spot
	var/mob/living/target = jaunt_target_ref?.resolve()
	end_jaunt()
	if(body.stat != CONSCIOUS || !spot || !in_dark(spot) || spot.is_blocked_turf(TRUE))
		return FALSE
	body.forceMove(spot)
	if(!target || !body.Adjacent(target) || !can_target(target))
		return TRUE
	body.face_atom(target)
	body.do_attack_animation(target, ATTACK_EFFECT_SLASH)
	playsound(target, 'sound/items/weapons/bladeslice.ogg', 60, TRUE)
	target.visible_message(span_danger("[body] lunges out of the dark at [target]!"), span_userdanger("[body] lunges out of the dark at you!"))
	outpost_experiment_ability_hit(target, OUTPOST_NIGHTMARE_JAUNT_DAMAGE, SHARP_EDGED, OUTPOST_NIGHTMARE_ARMOUR_PENETRATION, attacker = body)
	target.Knockdown(OUTPOST_NIGHTMARE_JAUNT_KNOCKDOWN)
	return TRUE

/// Thrown out of a jaunt (light, a flash): back where it went in
/datum/component/outpost_experiment_form/nightmare/proc/cancel_jaunt()
	if(!jaunting)
		return
	end_jaunt()
	var/mob/living/body = parent
	body.visible_message(span_warning("[body] is forced out of the shadows!"))

/datum/component/outpost_experiment_form/nightmare/proc/end_jaunt()
	var/mob/living/body = parent
	jaunting = FALSE
	jaunt_spot = null
	jaunt_target_ref = null
	REMOVE_TRAIT(body, TRAIT_IMMOBILIZED, OUTPOST_EXPERIMENT_FORM_TRAIT)
	animate(body, alpha = 255, time = 0.2 SECONDS)

/// Where the nightmare will come out of the dark
/obj/effect/temp_visual/telegraphing/outpost_shadow_ripple
	icon = 'icons/mob/telegraphing/telegraph.dmi'
	icon_state = "target_circle"
	color = "#2a0a3a"
	light_range = 0
	duration = OUTPOST_NIGHTMARE_JAUNT_RIPPLE

// ===== AI =====

/**
 * A creature's mind: tg's human NPC controller (soft crit, working at cuffs and grabs), then what its form
 * wants (ai_think()), breaking what it may out of its way, and real blows with its hands or its blade.
 */
/datum/ai_controller/basic_controller/human_npc/outpost_experiment
	blackboard = list(
		BB_TARGETING_STRATEGY = /datum/targeting_strategy/outpost_experiment_form,
		BB_TARGET_MINIMUM_STAT = HARD_CRIT,
	)
	ai_movement = /datum/ai_movement/jps
	idle_behavior = /datum/idle_behavior/idle_random_walk
	planning_subtrees = list(
		/datum/ai_planning_subtree/human_npc_soft_crit,
		/datum/ai_planning_subtree/escape_captivity,
		/datum/ai_planning_subtree/outpost_experiment_form_think,
		/datum/ai_planning_subtree/attack_obstacle_in_path/outpost_experiment_form,
		/datum/ai_planning_subtree/outpost_experiment_form_melee,
	)

/// The fly person moves only in its own darts: no aimless steps
/datum/ai_controller/basic_controller/human_npc/outpost_experiment/fly
	idle_behavior = null

/// The creature's form decides what it is after
/datum/ai_planning_subtree/outpost_experiment_form_think

/datum/ai_planning_subtree/outpost_experiment_form_think/SelectBehaviors(datum/ai_controller/controller, seconds_per_tick)
	var/mob/living/body = controller.pawn
	var/datum/component/outpost_experiment_form/form = body.GetComponent(/datum/component/outpost_experiment_form)
	if(!form || body.stat != CONSCIOUS)
		return
	form.track_reach(controller)
	return form.ai_think(controller)

/// Only what the form may break
/datum/ai_planning_subtree/attack_obstacle_in_path/outpost_experiment_form
	attack_behaviour = /datum/ai_behavior/attack_obstructions/outpost_experiment_form

/datum/ai_behavior/attack_obstructions/outpost_experiment_form

/datum/ai_behavior/attack_obstructions/outpost_experiment_form/attack_in_direction(datum/ai_controller/controller, mob/living/basic/basic_mob, direction)
	var/mob/living/body = controller.pawn
	var/datum/component/outpost_experiment_form/form = body.GetComponent(/datum/component/outpost_experiment_form)
	if(!form)
		return FALSE
	var/turf/next_step = get_step(body, direction)
	if(!next_step?.is_blocked_turf(exclude_mobs = TRUE, source_atom = body))
		return FALSE
	for(var/obj/object in next_step)
		if(!object.density || object.IsObscured() || !form.can_break(object))
			continue
		return form.break_obstacle(object, controller)
	if(isclosedturf(next_step) && form.can_break(next_step))
		return form.break_obstacle(next_step, controller)
	return FALSE

/// With a target: walks up and hits it, with the hand or blade the form fights with
/datum/ai_planning_subtree/outpost_experiment_form_melee

/datum/ai_planning_subtree/outpost_experiment_form_melee/SelectBehaviors(datum/ai_controller/controller, seconds_per_tick)
	if(!controller.blackboard_key_exists(BB_BASIC_MOB_CURRENT_TARGET))
		return
	controller.queue_behavior(/datum/ai_behavior/basic_melee_attack/outpost_experiment_form, BB_BASIC_MOB_CURRENT_TARGET, BB_TARGETING_STRATEGY, BB_BASIC_MOB_CURRENT_TARGET_HIDING_LOCATION)
	return SUBTREE_RETURN_FINISH_PLANNING

// tg's basic melee attack already clicks the target through ai_interact(); this readies the hand or blade first.
/datum/ai_behavior/basic_melee_attack/outpost_experiment_form

/datum/ai_behavior/basic_melee_attack/outpost_experiment_form/perform(seconds_per_tick, datum/ai_controller/controller, target_key, targeting_strategy_key, hiding_location_key)
	var/mob/living/carbon/body = controller.pawn
	var/datum/component/outpost_experiment_form/form = body.GetComponent(/datum/component/outpost_experiment_form)
	form?.ready_to_hit(controller.blackboard[target_key])
	body.zone_selected = human_npc_pick_aim_zone()
	return ..()

/// A creature's targets are whatever its form's can_target() says, in reach on its level
/datum/targeting_strategy/outpost_experiment_form

/datum/targeting_strategy/outpost_experiment_form/can_attack(mob/living/living_mob, atom/target, vision_range)
	var/datum/component/outpost_experiment_form/form = living_mob.GetComponent(/datum/component/outpost_experiment_form)
	if(!form || QDELETED(target) || !isturf(living_mob.loc))
		return FALSE
	var/turf/target_turf = get_turf(target)
	if(!target_turf || target_turf.z != living_mob.z)
		return FALSE
	if(vision_range && get_dist(living_mob, target) > vision_range)
		return FALSE
	return form.can_target(target)

/// The fly person's darts: straight runs that start at once
/datum/ai_movement/basic_avoidance/outpost_fly
	move_flags = MOVEMENT_LOOP_START_FAST

/**
 * A fly person's dart to the turf it picked (dart_spot()): done when it gets there, given up after
 * OUTPOST_FLY_DART_TIMEOUT. Planning goes on meanwhile, so a dart away from someone can cut a random one
 * short. A random dart is followed by a short pause.
 */
/datum/ai_behavior/outpost_fly_dart
	required_distance = 0
	action_cooldown = 0
	behavior_flags = AI_BEHAVIOR_REQUIRE_MOVEMENT | AI_BEHAVIOR_MOVE_AND_PERFORM | AI_BEHAVIOR_CAN_PLAN_DURING_EXECUTION

/datum/ai_behavior/outpost_fly_dart/setup(datum/ai_controller/controller, turf/destination)
	var/mob/living/body = controller.pawn
	var/datum/component/outpost_experiment_form/fly/fly = body.GetComponent(/datum/component/outpost_experiment_form/fly)
	if(!fly || !isturf(destination) || destination.z != body.z)
		return FALSE
	fly.dart_until = world.time + OUTPOST_FLY_DART_TIMEOUT
	set_movement_target(controller, destination, /datum/ai_movement/basic_avoidance/outpost_fly)
	return ..()

/datum/ai_behavior/outpost_fly_dart/perform(seconds_per_tick, datum/ai_controller/controller, turf/destination)
	var/mob/living/body = controller.pawn
	var/datum/component/outpost_experiment_form/fly/fly = body.GetComponent(/datum/component/outpost_experiment_form/fly)
	if(!fly || world.time >= fly.dart_until)
		return AI_BEHAVIOR_DELAY | AI_BEHAVIOR_FAILED
	if(get_turf(body) == destination)
		return AI_BEHAVIOR_DELAY | AI_BEHAVIOR_SUCCEEDED
	return AI_BEHAVIOR_DELAY

/datum/ai_behavior/outpost_fly_dart/finish_action(datum/ai_controller/controller, succeeded, turf/destination)
	// A dart that took over from this one has set its own movement; leave that be.
	var/moving_for_us = controller.movement_target_source == type
	. = ..()
	if(moving_for_us)
		controller.change_ai_movement_type(initial(controller.ai_movement))
	var/mob/living/body = controller.pawn
	var/datum/component/outpost_experiment_form/fly/fly = body?.GetComponent(/datum/component/outpost_experiment_form/fly)
	if(fly)
		fly.next_dart = world.time + pause_after()

/// How long it waits after this dart before the next random one
/datum/ai_behavior/outpost_fly_dart/proc/pause_after()
	return rand(OUTPOST_FLY_DART_GAP_MIN, OUTPOST_FLY_DART_GAP_MAX)

/// Away from someone: no pause after it
/datum/ai_behavior/outpost_fly_dart/away

/datum/ai_behavior/outpost_fly_dart/away/pause_after()
	return 0

/// The fly person waiting between darts. Planning goes on, so it notices anyone coming at once.
/datum/ai_behavior/outpost_fly_hover
	action_cooldown = 0
	behavior_flags = AI_BEHAVIOR_CAN_PLAN_DURING_EXECUTION

/datum/ai_behavior/outpost_fly_hover/perform(seconds_per_tick, datum/ai_controller/controller)
	var/mob/living/body = controller.pawn
	var/datum/component/outpost_experiment_form/fly/fly = body.GetComponent(/datum/component/outpost_experiment_form/fly)
	if(!fly || world.time >= fly.next_dart)
		return AI_BEHAVIOR_DELAY | AI_BEHAVIOR_SUCCEEDED
	return AI_BEHAVIOR_DELAY

/**
 * The fly person eats: walks to the food, picks it up and eats it the way anyone does (tg's edible, with
 * its do_after per bite); its fly stomach does the rest. Planning goes on, so a threat cuts it short.
 */
/datum/ai_behavior/outpost_fly_eat
	action_cooldown = 1 SECONDS
	required_distance = 1
	behavior_flags = AI_BEHAVIOR_REQUIRE_MOVEMENT | AI_BEHAVIOR_MOVE_AND_PERFORM | AI_BEHAVIOR_CAN_PLAN_DURING_EXECUTION

/datum/ai_behavior/outpost_fly_eat/setup(datum/ai_controller/controller, meal_key)
	var/obj/item/food/meal = controller.blackboard[meal_key]
	if(QDELETED(meal))
		return FALSE
	set_movement_target(controller, meal)
	return ..()

/datum/ai_behavior/outpost_fly_eat/perform(seconds_per_tick, datum/ai_controller/controller, meal_key)
	var/mob/living/carbon/human/body = controller.pawn
	var/obj/item/food/meal = controller.blackboard[meal_key]
	if(QDELETED(meal))
		return AI_BEHAVIOR_DELAY | AI_BEHAVIOR_SUCCEEDED
	if(LAZYLEN(body.do_afters))
		return AI_BEHAVIOR_DELAY
	if(body.is_holding(meal))
		if(!human_npc_ready_item(body, meal))
			return AI_BEHAVIOR_DELAY | AI_BEHAVIOR_FAILED
		// A bite: the food used on itself, out of combat mode, as a player eats.
		controller.ai_interact(target = body, combat_mode = FALSE)
		return AI_BEHAVIOR_DELAY
	if(!isturf(meal.loc))
		return AI_BEHAVIOR_DELAY | AI_BEHAVIOR_FAILED
	if(!body.Adjacent(meal))
		return AI_BEHAVIOR_DELAY
	if(!human_npc_ready_empty_hand(body))
		return AI_BEHAVIOR_DELAY | AI_BEHAVIOR_FAILED
	controller.ai_interact(target = meal, combat_mode = FALSE)
	return AI_BEHAVIOR_DELAY

/datum/ai_behavior/outpost_fly_eat/finish_action(datum/ai_controller/controller, succeeded, meal_key)
	var/obj/item/food/meal = controller.blackboard[meal_key]
	. = ..()
	controller.clear_blackboard_key(meal_key)
	if(succeeded || QDELETED(meal))
		return
	// Couldn't get at it: written off a while, like a target it can't reach.
	var/mob/living/body = controller.pawn
	var/datum/component/outpost_experiment_form/fly/fly = body?.GetComponent(/datum/component/outpost_experiment_form/fly)
	fly?.mark_unreachable(meal)

#undef OUTPOST_EXPERIMENT_FORM_TRAIT
#undef BB_OUTPOST_FLY_MEAL
