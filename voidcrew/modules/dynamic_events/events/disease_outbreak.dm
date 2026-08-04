/// How long an outbreak stays hidden before the ship announces it.
#define VOIDCREW_DISEASE_ANNOUNCE_DELAY 75
/// Advanced-virus lower limit for symptoms.
#define VOIDCREW_ADV_MIN_SYMPTOMS 3
/// Advanced-virus upper limit for symptoms.
#define VOIDCREW_ADV_MAX_SYMPTOMS 4
/// Numerical severity values consumed by TG's event-virus generator.
#define VOIDCREW_ADV_DISEASE_MEDIUM 1
#define VOIDCREW_ADV_DISEASE_HARMFUL 3
#define VOIDCREW_ADV_DISEASE_DANGEROUS 5
/// Percentile cutoffs for advanced-virus severity.
#define VOIDCREW_ADV_RNG_LOW 40
#define VOIDCREW_ADV_RNG_MID 85

/**
 * Ship-scoped port of TG's classic Disease Outbreak
 * (code/modules/events/disease_outbreak.dm).
 *
 * One eligible crewmember aboard the target ship becomes patient zero. The
 * disease subsystem handles every subsequent transmission naturally, including
 * any exposure that may occur after the ship docks elsewhere.
 */
/datum/round_event_control/voidcrew/disease_outbreak
	name = "Disease Outbreak: Classic"
	typepath = /datum/round_event/voidcrew/disease_outbreak
	max_occurrences = 1
	min_players = 2
	weight = 2
	category = EVENT_CATEGORY_HEALTH
	description = "A classic virus will infect one member of the target ship's crew."
	min_wizard_trigger_potency = 2
	max_wizard_trigger_potency = 6
	min_crew_aboard = 3
	allowed_zones = list(ZONE_YELLOW, ZONE_RED)

/// Requires at least one eligible patient zero aboard the proposed ship.
/datum/round_event_control/voidcrew/disease_outbreak/is_valid_target(obj/structure/overmap/ship/ship)
	. = ..()
	if(!.)
		return FALSE
	return length(generate_candidates_aboard(ship)) > 0

/**
 * Returns whether a human can be patient zero for this outbreak.
 *
 * This retains TG's crewmember, life-state, viral-immunity and existing-disease
 * checks. Virus resistance is checked explicitly because Spaceacillin grants
 * that trait. Ship area membership replaces TG's station/mining z-level test.
 */
/datum/round_event_control/voidcrew/disease_outbreak/proc/is_eligible_candidate(obj/structure/overmap/ship/ship, mob/living/carbon/human/candidate)
	if(QDELETED(candidate) || !ship.is_aboard(candidate))
		return FALSE
	if(candidate.stat == DEAD || !candidate.mind)
		return FALSE
	if(!(candidate.mind.assigned_role?.job_flags & JOB_CREW_MEMBER))
		return FALSE
	if(HAS_TRAIT(candidate, TRAIT_VIRUSIMMUNE) || HAS_TRAIT(candidate, TRAIT_VIRUS_RESISTANCE))
		return FALSE
	if(length(candidate.diseases))
		return FALSE
	return TRUE

/** Builds the disease-recipient pool from living, connected crew aboard one ship. */
/datum/round_event_control/voidcrew/disease_outbreak/proc/generate_candidates_aboard(obj/structure/overmap/ship/ship)
	var/list/candidates = list()
	if(!ship || QDELETED(ship) || !ship.shuttle)
		return candidates
	for(var/mob/living/crew_member as anything in ship.get_event_crew())
		if(!ishuman(crew_member))
			continue
		var/mob/living/carbon/human/candidate = crew_member
		if(is_eligible_candidate(ship, candidate))
			candidates += candidate
	return candidates

/** The classic ship outbreak; it seeds exactly one patient zero. */
/datum/round_event/voidcrew/disease_outbreak
	announce_when = VOIDCREW_DISEASE_ANNOUNCE_DELAY
	/// The classic disease type selected for this outbreak.
	var/datum/disease/virus_type
	/// Preset or generated illness name used by the delayed announcement.
	var/illness_type = ""

/datum/round_event/voidcrew/disease_outbreak/announce(fake)
	if(!target_valid())
		return
	if(!illness_type)
		var/list/virus_candidates = list(
			/datum/disease/anxiety,
			/datum/disease/beesease,
			/datum/disease/brainrot,
			/datum/disease/cold9,
			/datum/disease/flu,
			/datum/disease/fluspanish,
			/datum/disease/magnitis,
			/datum/disease/weightlessness,
			// These cannot roll during a real outbreak, but preserve TG's false-alarm flavor.
			/datum/disease/death_sandwich_poisoning,
			/datum/disease/dna_retrovirus,
			/datum/disease/gbs,
			/datum/disease/rhumba_beat,
		)
		if(!length(virus_candidates))
			return
		var/datum/disease/fake_virus = pick(virus_candidates)
		if(!fake_virus)
			return
		illness_type = initial(fake_virus.name)
	target_ship.ship_event_announce("Biological contaminant detected in the ship's air supply. All personnel must contain the outbreak.", "[illness_type] Alert", ANNOUNCER_OUTBREAK7)

/datum/round_event/voidcrew/disease_outbreak/start()
	if(!target_valid())
		return
	var/datum/round_event_control/voidcrew/disease_outbreak/disease_control = control
	if(!istype(disease_control))
		kill()
		return
	var/list/afflicted = disease_control.generate_candidates_aboard(target_ship)
	if(!length(afflicted))
		message_admins("Event Disease Outbreak: Classic found no eligible patient zero aboard its target ship.")
		log_game("Event Disease Outbreak: Classic found no eligible patient zero aboard its target ship.")
		kill()
		return

	if(!virus_type)
		// Mild diseases carry two thirds of the total weight for small, doctorless crews.
		var/list/virus_candidates = list(
			/datum/disease/flu = 6,
			/datum/disease/cold9 = 6,
			/datum/disease/beesease = 1,
			/datum/disease/brainrot = 1,
			/datum/disease/fluspanish = 1,
			/datum/disease/magnitis = 1,
			/datum/disease/anxiety = 1,
			/datum/disease/weightlessness = 1,
		)
		if(!length(virus_candidates))
			kill()
			return
		virus_type = pick_weight(virus_candidates)
	if(!virus_type)
		kill()
		return

	var/datum/disease/new_disease = new virus_type()
	if(!new_disease)
		kill()
		return
	new_disease.carrier = TRUE
	illness_type = new_disease.name

	while(length(afflicted))
		if(!target_valid())
			qdel(new_disease)
			return
		var/mob/living/carbon/human/victim = pick_n_take(afflicted)
		if(!disease_control.is_eligible_candidate(target_ship, victim))
			CHECK_TICK
			continue
		if(victim.ForceContractDisease(new_disease, FALSE))
			message_admins("Event triggered: Disease Outbreak - [new_disease.name] starting with patient zero [ADMIN_LOOKUPFLW(victim)] aboard [target_ship.display_name || target_ship.name]!")
			log_game("Event triggered: Disease Outbreak - [new_disease.name] starting with patient zero [key_name(victim)] aboard [target_ship.display_name || target_ship.name].")
			announce_to_ghosts(victim)
			return
		CHECK_TICK

	message_admins("Event Disease Outbreak: Classic failed to infect an eligible patient zero aboard its target ship.")
	log_game("Event Disease Outbreak: Classic failed to infect an eligible patient zero aboard its target ship.")
	qdel(new_disease)
	kill()

/**
 * Rare red-zone version of TG's advanced Disease Outbreak.
 *
 * The existing TG event-virus datum generates the disease itself; this control
 * only chooses a ship and the event below seeds patient zero.
 */
/datum/round_event_control/voidcrew/disease_outbreak/advanced
	name = "Disease Outbreak: Advanced"
	typepath = /datum/round_event/voidcrew/disease_outbreak/advanced
	category = EVENT_CATEGORY_HEALTH
	weight = 1
	earliest_start = 15 MINUTES
	description = "An advanced disease will infect one member of the target ship's crew."
	allowed_zones = list(ZONE_RED)

/** Advanced outbreak parameters, normally randomized as in the TG event. */
/datum/round_event/voidcrew/disease_outbreak/advanced
	/// Requested minimum symptom severity; null selects one randomly.
	var/requested_severity
	/// Requested transmission profile; null lets the TG generator choose.
	var/requested_transmissibility
	/// Maximum number of ordinary symptoms; null selects three or four.
	var/max_symptoms

/datum/round_event/voidcrew/disease_outbreak/advanced/start()
	if(!target_valid())
		return
	var/datum/round_event_control/voidcrew/disease_outbreak/disease_control = control
	if(!istype(disease_control))
		kill()
		return
	var/list/afflicted = disease_control.generate_candidates_aboard(target_ship)
	if(!length(afflicted))
		message_admins("Event Disease Outbreak: Advanced found no eligible patient zero aboard its target ship.")
		log_game("Event Disease Outbreak: Advanced found no eligible patient zero aboard its target ship.")
		kill()
		return

	if(isnull(max_symptoms))
		max_symptoms = rand(VOIDCREW_ADV_MIN_SYMPTOMS, VOIDCREW_ADV_MAX_SYMPTOMS)

	if(isnull(requested_severity))
		var/rng_severity = rand(1, 100)
		if(rng_severity < VOIDCREW_ADV_RNG_LOW)
			requested_severity = VOIDCREW_ADV_DISEASE_MEDIUM
		else if(rng_severity < VOIDCREW_ADV_RNG_MID)
			requested_severity = VOIDCREW_ADV_DISEASE_HARMFUL
		else
			requested_severity = VOIDCREW_ADV_DISEASE_DANGEROUS

	var/datum/disease/advance/advanced_disease = new /datum/disease/advance/random/event(max_symptoms, requested_severity, requested_transmissibility)
	if(!advanced_disease || !length(advanced_disease.symptoms))
		qdel(advanced_disease)
		message_admins("Event Disease Outbreak: Advanced failed to generate a viable disease.")
		log_game("Event Disease Outbreak: Advanced failed to generate a viable disease.")
		kill()
		return
	illness_type = advanced_disease.name

	while(length(afflicted))
		if(!target_valid())
			qdel(advanced_disease)
			return
		var/mob/living/carbon/human/victim = pick_n_take(afflicted)
		if(!disease_control.is_eligible_candidate(target_ship, victim))
			CHECK_TICK
			continue
		if(victim.ForceContractDisease(advanced_disease, FALSE))
			message_admins("Event triggered: Disease Outbreak: Advanced - starting with patient zero [ADMIN_LOOKUPFLW(victim)] aboard [target_ship.display_name || target_ship.name]! Details: [advanced_disease.admin_details()] sp:[advanced_disease.spread_flags] ([advanced_disease.spread_text])")
			log_game("Event triggered: Disease Outbreak: Advanced - starting with patient zero [key_name(victim)] aboard [target_ship.display_name || target_ship.name]. Details: [advanced_disease.admin_details()] sp:[advanced_disease.spread_flags] ([advanced_disease.spread_text])")
			log_virus("Disease Outbreak: Advanced has triggered a custom virus outbreak of [advanced_disease.admin_details()] in [victim] aboard [target_ship.display_name || target_ship.name]!")
			announce_to_ghosts(victim)
			return
		CHECK_TICK

	message_admins("Event Disease Outbreak: Advanced failed to infect an eligible patient zero aboard its target ship.")
	log_game("Event Disease Outbreak: Advanced failed to infect an eligible patient zero aboard its target ship.")
	qdel(advanced_disease)
	kill()

#undef VOIDCREW_DISEASE_ANNOUNCE_DELAY
#undef VOIDCREW_ADV_MIN_SYMPTOMS
#undef VOIDCREW_ADV_MAX_SYMPTOMS
#undef VOIDCREW_ADV_DISEASE_MEDIUM
#undef VOIDCREW_ADV_DISEASE_HARMFUL
#undef VOIDCREW_ADV_DISEASE_DANGEROUS
#undef VOIDCREW_ADV_RNG_LOW
#undef VOIDCREW_ADV_RNG_MID
