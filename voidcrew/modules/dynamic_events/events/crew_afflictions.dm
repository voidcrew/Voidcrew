/**
 * Ship-scoped ports of TG's crew affliction events:
 * - Random Heart Attack (code/modules/events/heart_attack.dm)
 * - Spontaneous Brain Trauma (code/modules/events/brain_trauma.dm)
 * - Fake Virus (code/modules/events/fake_virus.dm)
 * - Mass Hallucination (code/modules/events/mass_hallucination.dm)
 *
 * All four target individual crew rather than locations, so the porting work is
 * entirely in the victim pools: TG's station-wide GLOB scans become the target
 * ship's crew (target_ship.get_event_crew() / get_all_mobs_aboard()), with each
 * original's own eligibility filters kept intact. None of the originals make an
 * announcement, so none of these do either.
 */

/**
 * Random Heart Attack
 *
 * Lethal for a lone pilot with no one to do CPR, so it requires at least three
 * crew aboard (replacing the original's min_players = 40 lowpop protection) and
 * stays out of the safe green zone.
 */
/datum/round_event_control/voidcrew/heart_attack
	name = "Random Heart Attack"
	typepath = /datum/round_event/voidcrew/heart_attack
	// Admin-only. This event has no announcement, no telegraph and no way to avoid it:
	// a crewmember simply starts dying, and a ship without a defib and someone trained
	// to use it has no answer at all. Kept for admin use; never rolled naturally.
	weight = 0
	max_occurrences = 0
	category = EVENT_CATEGORY_HEALTH
	description = "A random crewmember's heart gives out."
	min_wizard_trigger_potency = 6
	max_wizard_trigger_potency = 7
	min_crew_aboard = 3
	allowed_zones = list(ZONE_YELLOW, ZONE_RED)

/datum/round_event_control/voidcrew/heart_attack/is_valid_target(obj/structure/overmap/ship/ship)
	. = ..()
	if(!.)
		return FALSE
	// Don't waste the roll on a ship where nobody's heart can give out.
	return length(generate_candidates_aboard(ship)) > 0

/**
 * Builds the weighted list of heart-attack-eligible humans aboard the given ship.
 *
 * Ship-scoped version of the original's generate_candidates(): the crew of the
 * target ship replaces the station-wide player_list scan. Dead and clientless
 * mobs are already excluded by get_event_crew(); everything else (critical
 * condition, no working heart, already having a heart attack, junk food
 * weighting) is kept from the original.
 */
/datum/round_event_control/voidcrew/heart_attack/proc/generate_candidates_aboard(obj/structure/overmap/ship/ship)
	var/list/candidates = list()
	for(var/mob/living/crew_member as anything in ship.get_event_crew())
		if(!ishuman(crew_member))
			continue
		var/mob/living/carbon/human/candidate = crew_member
		if(IS_UNCONSCIOUS_OR_CRIT(candidate) || !candidate.can_heartattack() || candidate.has_status_effect(/datum/status_effect/heart_attack) || candidate.undergoing_cardiac_arrest())
			continue
		if(!(candidate.mind?.assigned_role.job_flags & JOB_CREW_MEMBER)) // only crewmembers can get one, a bit unfair for some ghost roles and it wastes the event
			continue
		if(candidate.satiety <= -60 && !candidate.has_status_effect(/datum/status_effect/exercised)) // Multiple junk food items recently // No foodmaxxing for the achievement
			candidates[candidate] = 3
		else
			candidates[candidate] = 1
	return candidates

/datum/round_event/voidcrew/heart_attack
	// No announcement anywhere in this chain, so a faked one is silent, it would
	// spend a False Alarm occurrence and produce nothing.
	fakeable = FALSE
	/// A list of prime candidates for heart attacking, assoc victim = weight.
	var/list/victims = list()
	/// Number of heart attacks to distribute.
	var/quantity = 1

/datum/round_event/voidcrew/heart_attack/start()
	if(!target_valid())
		return
	var/datum/round_event_control/voidcrew/heart_attack/heart_control = control
	victims = heart_control.generate_candidates_aboard(target_ship)
	while(quantity > 0 && length(victims))
		if(attack_heart())
			quantity--

/**
 * Picks a victim from the list and attempts to give them a heart attack.
 *
 * Copied from the original: the exercised status blocks the attack instead of
 * merely denying eligibility. Returns TRUE if a heart attack is successfully
 * given, and FALSE if something blocks it.
 */
/datum/round_event/voidcrew/heart_attack/proc/attack_heart()
	var/mob/living/carbon/human/winner = pick_weight(victims)
	if(winner.has_status_effect(/datum/status_effect/exercised)) // Stuff that should "block" a heart attack rather than just deny eligibility for one goes here.
		winner.visible_message(span_warning("[winner] grunts and clutches their chest for a moment, catching [winner.p_their()] breath."), span_medal("Your chest lurches in pain for a brief moment, which quickly fades. \
								You feel like you've just avoided a serious health disaster."), span_hear("You hear someone's breathing sharpen for a moment, followed by a sigh of relief."), 4)
		winner.playsound_local(get_turf(winner), 'sound/effects/health/slowbeat.ogg', 40, 0, channel = CHANNEL_HEARTBEAT, use_reverb = FALSE)
		winner.Stun(3 SECONDS)
		if(winner.client)
			winner.client.give_award(/datum/award/achievement/misc/healthy, winner)
		message_admins("[winner] has just survived a random heart attack!") // time to spawn them a trophy :)
		victims -= winner
	else
		winner.apply_status_effect(/datum/status_effect/heart_attack)
		announce_to_ghosts(winner)
		victims -= winner
		return TRUE
	return FALSE

/**
 * Spontaneous Brain Trauma
 *
 * Two crew minimum so there's at least a chance someone aboard can help the
 * victim; the trauma selection itself is unchanged from the original.
 */
/datum/round_event_control/voidcrew/brain_trauma
	name = "Spontaneous Brain Trauma"
	typepath = /datum/round_event/voidcrew/brain_trauma
	// Admin-only. Fires silently and the trauma outlives the event. The victim is stuck
	// with it until someone finds mannitol or cuts their skull open. Nothing about that is
	// a thing the crew can play against, so it does not belong in the ambient roster.
	weight = 0
	max_occurrences = 0
	category = EVENT_CATEGORY_HEALTH
	description = "A crewmember gains a random trauma."
	min_wizard_trigger_potency = 2
	max_wizard_trigger_potency = 6
	min_crew_aboard = 2

/datum/round_event_control/voidcrew/brain_trauma/is_valid_target(obj/structure/overmap/ship/ship)
	. = ..()
	if(!.)
		return FALSE
	// Pointless on a ship with no eligible brains to rattle.
	for(var/mob/living/crew_member as anything in ship.get_event_crew())
		if(!ishuman(crew_member))
			continue
		if(crew_member.get_organ_by_type(/obj/item/organ/brain))
			return TRUE
	return FALSE

/datum/round_event/voidcrew/brain_trauma
	fakeable = FALSE

/datum/round_event/voidcrew/brain_trauma/start()
	if(!target_valid())
		return
	for(var/mob/living/crew_member as anything in shuffle(target_ship.get_event_crew()))
		if(!ishuman(crew_member))
			continue
		var/mob/living/carbon/human/victim = crew_member
		if(!victim.get_organ_by_type(/obj/item/organ/brain)) // If only I had a brain
			continue
		if(!(victim.mind?.assigned_role.job_flags & JOB_CREW_MEMBER)) // please stop giving my centcom admin gimmicks full body paralysis
			continue
		traumatize(victim)
		announce_to_ghosts(victim)
		break

/// Gives the victim one random trauma, with the original's resilience and severity rolls.
/datum/round_event/voidcrew/brain_trauma/proc/traumatize(mob/living/carbon/human/victim)
	var/resistance = pick(
		50;TRAUMA_RESILIENCE_BASIC,
		30;TRAUMA_RESILIENCE_SURGERY,
		15;TRAUMA_RESILIENCE_LOBOTOMY,
		5;TRAUMA_RESILIENCE_MAGIC)

	var/trauma_type = pick_weight(list(
		BRAIN_TRAUMA_MILD = 60,
		BRAIN_TRAUMA_SEVERE = 30,
		BRAIN_TRAUMA_SPECIAL = 10
	))

	victim.gain_trauma_type(trauma_type, resistance)

/**
 * Fake Virus
 *
 * Harmless hypochondria: any zone, any crew count. The original's min() clamps
 * already scale the victim counts to however many candidates the ship has.
 */
/datum/round_event_control/voidcrew/fake_virus
	name = "Fake Virus"
	typepath = /datum/round_event/voidcrew/fake_virus
	weight = 20
	category = EVENT_CATEGORY_HEALTH
	description = "Some crewmembers suffer from temporary hypochondria."
	min_crew_aboard = 1

/datum/round_event/voidcrew/fake_virus
	// Same as the heart attack: nothing in this chain announces, so faking it is
	// a silent False Alarm.
	fakeable = FALSE

/datum/round_event/voidcrew/fake_virus/start()
	if(!target_valid())
		return
	var/list/fake_virus_victims = list()
	for(var/mob/living/crew_member as anything in target_ship.get_event_crew())
		if(!ishuman(crew_member))
			continue
		var/mob/living/carbon/human/victim = crew_member
		if(victim.stat != STABLE || HAS_TRAIT(victim, TRAIT_VIRUSIMMUNE))
			continue
		if(!(victim.mind?.assigned_role.job_flags & JOB_CREW_MEMBER))
			continue
		fake_virus_victims += victim

	// first we do hard status effect victims
	var/defacto_min = min(3, length(fake_virus_victims))
	if(defacto_min <= 0) // event will hit 1-3 people by default, but will do 1-2 or just 1 if only those many candidates are available
		return
	for(var/i in 1 to rand(1, defacto_min))
		var/mob/living/carbon/human/hypochondriac = pick_n_take(fake_virus_victims)
		hypochondriac.apply_status_effect(/datum/status_effect/fake_virus)
		announce_to_ghosts(hypochondriac)

	// then we do light one-message victims who simply cough or whatever once (have to repeat the process since the last operation modified our candidates list)
	defacto_min = min(5, length(fake_virus_victims))
	if(defacto_min <= 0)
		return
	for(var/i in 1 to rand(1, defacto_min))
		var/mob/living/carbon/human/onecoughman = pick_n_take(fake_virus_victims)
		if(prob(25)) // 1/4 odds to get a spooky message instead of coughing out loud
			addtimer(CALLBACK(GLOBAL_PROC, GLOBAL_PROC_REF(to_chat), onecoughman, span_warning("[pick("Your head hurts.", "Your head pounds.")]")), rand(3 SECONDS, 15 SECONDS))
		else
			addtimer(CALLBACK(onecoughman, TYPE_PROC_REF(/mob, emote), pick("cough", "sniff")), rand(3 SECONDS, 15 SECONDS)) // deliver the message with a slightly randomized time interval so there arent multiple people coughing at the exact same time

/**
 * Mass Hallucination
 *
 * Harmless: any zone, any crew count. Everyone aboard the target ship (and
 * only them) hallucinates the same thing; the original's centcom/station-z
 * checks are subsumed by the ship scoping. Dead mobs are skipped by
 * get_all_mobs_aboard(); clientless carbons aboard still hallucinate, matching
 * the original's on-station behavior.
 */
/datum/round_event_control/voidcrew/mass_hallucination
	name = "Mass Hallucination"
	description = "All crewmembers start to hallucinate the same thing."
	typepath = /datum/round_event/voidcrew/mass_hallucination
	weight = 10
	max_occurrences = 2
	category = EVENT_CATEGORY_HEALTH
	min_wizard_trigger_potency = 0
	max_wizard_trigger_potency = 2
	min_crew_aboard = 1

/datum/round_event/voidcrew/mass_hallucination
	fakeable = FALSE

/datum/round_event/voidcrew/mass_hallucination/start()
	if(!target_valid())
		return

	var/hallucination_type
	var/list/extra_args
	var/category_to_pick_from = rand(1, 10)
	switch(category_to_pick_from)
		if(1)
			// Send the same sound to everyone
			hallucination_type = get_random_valid_hallucination_subtype(/datum/hallucination/fake_sound/normal)

		if(2)
			// Send the same sound to everyone, but weird
			hallucination_type = get_random_valid_hallucination_subtype(/datum/hallucination/fake_sound/weird)

		if(3)
			// Send the same message to everyone
			hallucination_type = get_random_valid_hallucination_subtype(/datum/hallucination/station_message)

		if(4)
			// Send the same delusion to everyone, but...
			hallucination_type = get_random_valid_hallucination_subtype(/datum/hallucination/delusion/preset)
			// The delusion will affect everyone BUT the hallucinator.
			extra_args = list(
				duration = 30 SECONDS,
				skip_nearby = FALSE,
				affects_us = FALSE,
				affects_others = TRUE,
				play_wabbajack = FALSE,
			)

		if(5)
			// Send the same delusion to everyone, but...
			hallucination_type = get_random_valid_hallucination_subtype(/datum/hallucination/delusion/preset)
			// The delusion will affect only the hallucinator.
			extra_args = list(
				duration = 45 SECONDS,
				skip_nearby = FALSE,
				affects_us = TRUE,
				affects_others = FALSE,
				play_wabbajack = TRUE,
			)

		if(6 to 10)
			// Send the same generic hallucination type to everyone
			var/static/list/generic_hallucinations = list(
				/datum/hallucination/bolts,
				/datum/hallucination/chat,
				/datum/hallucination/death,
				/datum/hallucination/fake_flood,
				/datum/hallucination/fire,
				/datum/hallucination/message,
				/datum/hallucination/oh_yeah,
				/datum/hallucination/xeno_attack,
			)

			hallucination_type = pick(generic_hallucinations)

	if(!hallucination_type)
		CRASH("[type] couldn't find a hallucination to play. (Got: [hallucination_type], Picked category: [category_to_pick_from])")

	var/list/hallucination_args = list(hallucination_type, "mass hallucination")
	if(islist(extra_args))
		hallucination_args += extra_args

	// We'll only hallucinate for carbons now, even though livings can hallucinate just fine in most cases.
	for(var/mob/living/aboard_mob as anything in target_ship.get_all_mobs_aboard())
		if(!iscarbon(aboard_mob))
			continue
		var/mob/living/carbon/hallucinating = aboard_mob
		// Not using the wrapper here because we already have a list / arglist
		hallucinating._cause_hallucination(hallucination_args)
