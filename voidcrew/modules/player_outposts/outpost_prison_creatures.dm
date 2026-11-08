/**
 * # Experiment creatures: the tells, and the changeling's horror's base
 *
 * The serum's forms (the hulk, the fly person and the nightmare) are the subject's own body changed by
 * tg's biology: outpost_prison_experiment_forms.dm. This file keeps what the serum shows before it takes
 * (outpost_experiment_tell()), the forms' ability hit, and the basic mob the
 * changeling's horror is filed under (outpost_prison_horror.dm), which stays a monster (owner ruling OC-4):
 * a basic mob, never megafauna, with no sentience, no need for air, and no way to be boxed, teleported or
 * polymorphed. It only breaks the outpost's interior (outpost_experiment_can_smash()).
 */

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

/**
 * One of a creature's ability hits on `victim` (the hulk's charge, the nightmare's lunge out of the dark):
 * at a body zone, through the armour on it, and able to wound like any other blow of its kind. A blunt hit
 * when `sharpness` is NONE. Returns the damage dealt.
 */
/proc/outpost_experiment_ability_hit(mob/living/victim, damage, sharpness = NONE, armour_penetration = 0, zone, atom/attacker)
	if(QDELETED(victim))
		return 0
	zone ||= victim.get_random_valid_zone(BODY_ZONE_CHEST)
	var/blocked = victim.run_armor_check(zone, MELEE, armour_penetration = armour_penetration)
	return victim.apply_damage(damage, BRUTE, zone, blocked, sharpness = sharpness, attack_direction = attacker ? get_dir(attacker, victim) : null)

/// Takes the tells off a subject the serum never finished with
/proc/outpost_experiment_clear_tells(mob/living/basic/outpost_prisoner/subject)
	if(QDELETED(subject))
		return
	subject.remove_atom_colour(TEMPORARY_COLOUR_PRIORITY)
	subject.remove_filter("outpost_nightmare_tell")
	if(subject.current_size != RESIZE_DEFAULT_SIZE)
		subject.update_transform(RESIZE_DEFAULT_SIZE / subject.current_size)

// ===== THE HORROR'S BASE =====

/// What the changeling's specimen grows into is filed under this: kept at home and out of players' hands.
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
	// tg's human deathgasp
	death_message = "seizes up and falls limp, their eyes dead and lifeless..."
	// Knocked down or dead, it lies on the floor like a person.
	mobility_flags = MOBILITY_FLAGS_REST_CAPABLE_DEFAULT
	rotate_on_lying = TRUE
	/// What the log calls it
	var/form_name = "a creature"
	/// A tell on examine, if any: something anyone watching it would notice
	var/win_hint
	/// Dialogue context it says now and then, and seconds to the next line
	var/line_context
	var/line_left = 10
	/// The prison it came from
	var/datum/outpost_prison/prison
	/// The prisoner's personality, for its lines
	var/personality
	/// Its footsteps: the footstep element's sound set, volume multiplier and extra range
	var/footstep_kind = FOOTSTEP_MOB_SHOE
	var/footstep_volume = 0.5
	var/footstep_range = -8

/mob/living/basic/outpost_experiment/Initialize(mapload, datum/outpost_prison/owner)
	. = ..()
	prison = owner
	damage_coeff = damage_coeff.Copy()
	ADD_TRAIT(src, TRAIT_NO_CONTAINMENT, INNATE_TRAIT)
	ADD_TRAIT(src, TRAIT_NO_STORAGE_INSERT, INNATE_TRAIT)
	RegisterSignal(src, COMSIG_MOVABLE_TELEPORTING, PROC_REF(refuse_teleport))
	RegisterSignal(src, COMSIG_LIVING_PRE_WABBAJACKED, PROC_REF(refuse_polymorph))
	RegisterSignal(src, COMSIG_PRE_MOB_CHANGED_TYPE, PROC_REF(refuse_type_change))
	AddComponent(/datum/component/experiment_damage_ledger)
	AddElement(/datum/element/footstep, footstep_type = footstep_kind, volume = footstep_volume, e_range = footstep_range)
	build_look()

/mob/living/basic/outpost_experiment/Destroy()
	prison = null
	return ..()

/// Puts on its look
/mob/living/basic/outpost_experiment/proc/build_look(outfit_path)
	return

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

/// Down for good, its body can be dragged about until Kessler collects it
/mob/living/basic/outpost_experiment/death(gibbed)
	. = ..()
	move_resist = MOVE_RESIST_DEFAULT
	if(. && !gibbed && !QDELETED(src))
		balloon_alert_to_viewers("dead")

/mob/living/basic/outpost_experiment/examine(mob/user)
	. = ..()
	if(HAS_TRAIT_FROM(src, TRAIT_IMMOBILIZED, OUTPOST_KESSLER_TRAIT))
		. += span_notice("Kessler Biolabs is taking [p_them()] away.")
	else if(stat == DEAD)
		. += span_notice("[p_They()] [p_are()] down. Kessler Biolabs will collect [p_them()] shortly.")
	else if(win_hint)
		. += span_notice(win_hint)

/// Health it still had, which a gib or dust takes without it counting as damage on its ledger
/mob/living/basic/outpost_experiment/proc/unspent_health()
	return health

/**
 * Interim turret rule (outpost_prison_riot.dm): outpost turrets shoot a creature wherever it is,
 * until it is dead or Kessler's beam has it. Turret damage is not the crew's, so a turret kill pays
 * no containment bonus.
 */
/mob/living/basic/outpost_experiment/proc/turret_target()
	return stat != DEAD && !HAS_TRAIT_FROM(src, TRAIT_IMMOBILIZED, OUTPOST_KESSLER_TRAIT)

/**
 * Whether outpost turrets shoot `creature`, an experiment's creature: the horror by its own rule; a body the
 * serum took while it is up and fighting (not down for Kessler, not being beamed away).
 */
/proc/is_outpost_experiment_turret_target(mob/living/creature)
	var/mob/living/basic/outpost_experiment/experiment_creature = creature
	if(istype(experiment_creature))
		return experiment_creature.turret_target()
	if(!creature?.GetComponent(/datum/component/outpost_experiment_form))
		return FALSE
	return !outpost_experiment_down_state(creature) && !HAS_TRAIT_FROM(creature, TRAIT_IMMOBILIZED, OUTPOST_KESSLER_TRAIT)

/// Whether its AI runs: only while someone is on the level
/mob/living/basic/outpost_experiment/proc/awake()
	return ai_controller?.ai_status == AI_STATUS_ON

/mob/living/basic/outpost_experiment/Life(seconds_per_tick = SSMOBS_DT, times_fired)
	. = ..()
	if(stat == DEAD || HAS_TRAIT_FROM(src, TRAIT_IMMOBILIZED, OUTPOST_KESSLER_TRAIT) || !awake())
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
