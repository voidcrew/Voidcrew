// Ported from NovaSector (5ce2bd2215c0) modular_nova/modules/xenoarchartifacts/effects/feelings.dm.
// Voidcrew: trimmed message lists, plain spans instead of font tags, dizziness only from dread.

/datum/artifact_effect/feelings
	tier = ARTIFACT_TIER_COMMON
	minor = TRUE
	possible_kinds = list(ARTIFACT_ENERGY_PSIONIC)
	/// Strong feelings
	var/list/major_messages
	/// Passing feelings
	var/list/minor_messages
	var/major_mood_type
	var/minor_mood_type
	/// Span proc for messages
	var/good = TRUE

/datum/artifact_effect/feelings/do_effect_touch(mob/living/user)
	feel(user, 50, 100)

/datum/artifact_effect/feelings/do_effect_aura(seconds_per_tick)
	for(var/mob/living/carbon/human/target in living_in_range())
		if(SPT_PROB(2.5, seconds_per_tick))
			feel(target, 100, 0)
		else if(SPT_PROB(5, seconds_per_tick))
			feel(target, 0, 100)

/datum/artifact_effect/feelings/do_effect_pulse(power)
	for(var/mob/living/carbon/human/target in living_in_range())
		feel(target, 80, 100)

/// Gives `target` a strong feeling with `major_chance`, else a passing one with `minor_chance`.
/datum/artifact_effect/feelings/proc/feel(mob/living/target, major_chance, minor_chance)
	if(!ishuman(target) || prob(100 * (1 - artifact_exposure(target))))
		return
	if(prob(major_chance))
		to_chat(target, good ? span_nicegreen("<b>[pick(major_messages)]</b>") : span_boldwarning(pick(major_messages)))
		target.add_mood_event("artifact_feeling_major", major_mood_type)
		if(!good)
			target.adjust_dizzy_up_to(4 SECONDS, 20 SECONDS)
	else if(prob(minor_chance))
		to_chat(target, good ? span_nicegreen(pick(minor_messages)) : span_warning(pick(minor_messages)))
		target.add_mood_event("artifact_feeling_minor", minor_mood_type)

/datum/artifact_effect/feelings/good
	label_name = "Good mood"
	log_name = "Good feeling"
	good = TRUE
	major_mood_type = /datum/mood_event/artifact_good_major
	minor_mood_type = /datum/mood_event/artifact_good_minor
	major_messages = list(
		"You want to hug everyone you meet!",
		"Everything is going so well!",
		"You feel giddy.",
		"You could dance.",
	)
	minor_messages = list(
		"You feel good.",
		"You've got a good feeling about this.",
		"Something smells good.",
		"You fight the urge to smile.",
		"The colours around you seem a bit brighter.",
		"Your worries seem very far away.",
	)

/datum/artifact_effect/feelings/bad
	label_name = "Dread"
	log_name = "Bad feeling"
	good = FALSE
	major_mood_type = /datum/mood_event/artifact_bad_major
	minor_mood_type = /datum/mood_event/artifact_bad_minor
	major_messages = list(
		"You've got to get out of here!",
		"Someone's trying to kill you!",
		"There's something out there!",
		"What's happening to you?",
	)
	minor_messages = list(
		"You feel worried.",
		"Something doesn't feel right.",
		"You get a strange feeling in your gut.",
		"You've got a bad feeling about this.",
		"Your scalp prickles.",
		"The shadows seem longer than they were.",
		"The walls feel closer.",
	)

/datum/mood_event/artifact_good_major
	description = "Everything's going great and I don't even know why."
	mood_change = 6
	timeout = 5 MINUTES

/datum/mood_event/artifact_good_minor
	description = "I feel strangely relaxed."
	mood_change = 3
	timeout = 3 MINUTES

/datum/mood_event/artifact_bad_major
	description = "Something is very, very wrong around here."
	mood_change = -6
	timeout = 5 MINUTES

/datum/mood_event/artifact_bad_minor
	description = "I feel uneasy and I can't say why."
	mood_change = -3
	timeout = 3 MINUTES
