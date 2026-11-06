/// Backgrounds: owned by P2.

/**
 * # Crimes
 *
 * tg's prisoner crimes, each given a convict goal and a warrant tier. The Crime dropdown shows the
 * setting's five plus Random; Random is resolved by the prisoner job over every crime, so every
 * crime carries a goal. Brawling is not one of them (BUG-2).
 */

/datum/prisoner_crime
	/// The convict goal this crime gives (CONVICT_GOAL_*)
	var/background_goal = CONVICT_GOAL_CLEAN_SLATE
	/// Warrant tier, 1 (petty) to 3 (most wanted)
	var/background_tier = 1

/datum/preference/choiced/prisoner_crime/init_possible_values()
	return list("Grand Theft", "Mutiny", "Counterfeiting", "Smuggling", "Murder", "Random")

/datum/prisoner_crime/smuggling
	name = "Smuggling"
	desc = "Ran contraband through customs lanes."
	tattoos = 1
	background_goal = CONVICT_GOAL_STASH
	background_tier = 2

// Haul
/datum/prisoner_crime/grand_theft
	background_goal = CONVICT_GOAL_HAUL
	background_tier = 2

/datum/prisoner_crime/espionage
	background_goal = CONVICT_GOAL_HAUL
	background_tier = 2

/datum/prisoner_crime/ai_tampering
	background_goal = CONVICT_GOAL_HAUL
	background_tier = 2

// Captain
/datum/prisoner_crime/mutiny
	background_goal = CONVICT_GOAL_CAPTAIN
	background_tier = 2

/datum/prisoner_crime/classified
	background_goal = CONVICT_GOAL_CAPTAIN
	background_tier = 2

/datum/prisoner_crime/enemy_of_the_corp
	background_goal = CONVICT_GOAL_CAPTAIN
	background_tier = 2

/datum/prisoner_crime/grand_sabo
	background_goal = CONVICT_GOAL_CAPTAIN
	background_tier = 2

// Clean slate
/datum/prisoner_crime/counterfeiting
	background_goal = CONVICT_GOAL_CLEAN_SLATE
	background_tier = 1

/datum/prisoner_crime/tax_evasion
	background_goal = CONVICT_GOAL_CLEAN_SLATE
	background_tier = 1

/datum/prisoner_crime/identity_theft
	background_goal = CONVICT_GOAL_CLEAN_SLATE
	background_tier = 1

/datum/prisoner_crime/negligence
	background_goal = CONVICT_GOAL_CLEAN_SLATE
	background_tier = 1

/datum/prisoner_crime/cloning
	background_goal = CONVICT_GOAL_CLEAN_SLATE
	background_tier = 1

/datum/prisoner_crime/malpractice
	background_goal = CONVICT_GOAL_CLEAN_SLATE
	background_tier = 1

/datum/prisoner_crime/jaywalker
	background_goal = CONVICT_GOAL_CLEAN_SLATE
	background_tier = 1

/datum/prisoner_crime/other
	background_goal = CONVICT_GOAL_CLEAN_SLATE
	background_tier = 1

/datum/prisoner_crime/cultist
	background_goal = CONVICT_GOAL_CLEAN_SLATE
	background_tier = 1

// Witness
/datum/prisoner_crime/murder
	background_goal = CONVICT_GOAL_WITNESS
	background_tier = 3

/datum/prisoner_crime/mass_murder
	background_goal = CONVICT_GOAL_WITNESS
	background_tier = 3

/datum/prisoner_crime/bio_terrorism
	background_goal = CONVICT_GOAL_WITNESS
	background_tier = 3

/datum/prisoner_crime/attempted_murder
	background_goal = CONVICT_GOAL_WITNESS
	background_tier = 2

/datum/prisoner_crime/kidnapping
	background_goal = CONVICT_GOAL_WITNESS
	background_tier = 2

/**
 * The crime a convict's mind is in for: the last one the prisoner job wrote on their crew record,
 * else their Crime preference, Random picked over every crime.
 */
/proc/convict_resolve_crime(datum/mind/mind)
	var/mob/living/body = mind?.current
	var/datum/record/crew/crew_record = body ? find_record(body.real_name) : null
	if(length(crew_record?.crimes))
		for(var/i in length(crew_record.crimes) to 1 step -1)
			var/datum/crime/past = crew_record.crimes[i]
			var/datum/prisoner_crime/listed = istype(past) ? GLOB.prisoner_crimes[past.name] : null
			if(listed)
				return listed
	var/crime_name = body?.client?.prefs?.read_preference(/datum/preference/choiced/prisoner_crime)
	var/datum/prisoner_crime/chosen = crime_name ? GLOB.prisoner_crimes[crime_name] : null
	if(chosen)
		return chosen
	return GLOB.prisoner_crimes[pick(assoc_to_keys(GLOB.prisoner_crimes))]
