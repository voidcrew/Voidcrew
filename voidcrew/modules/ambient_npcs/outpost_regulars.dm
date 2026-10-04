/**
 * # World population: the outposts' regulars
 *
 * Replaces the old mapped loiterers with two ambient roles: Halcyon's mechanic (one, reusing the mechanic outfits and work loop)
 * and the Undertow's off-duty pirate (a drinker flavour at the Dregs, with the old pirate lines).
 * Lines are in strings/outpost_patrons.json and strings/outpost_workers.json.
 *
 * Seams: see outpost_patrons.dm.
 */

// =========================================================================
// MECHANIC (Halcyon)
// =========================================================================

/// Reuses the mechanic outfits and work loop; always mid-job at a rack, pipe or panel
/mob/living/basic/ambient_npc/outpost/worker/mechanic
	desc = "Permanently mid-job. Nobody has ever seen the job finished."
	dialogue_section = "mechanic"
	outfit_choices = list(
		/datum/outfit/outpost_mechanic,
		/datum/outfit/outpost_mechanic/overalls,
		/datum/outfit/outpost_mechanic/hivis,
		/datum/outfit/outpost_mechanic/coveralls,
		/datum/outfit/outpost_mechanic/atmos,
	)
	work_weights = list(
		/datum/outpost_ambient_work/weld = 3,
		/datum/outpost_ambient_work/wrench = 2,
		/datum/outpost_ambient_work/panel = 2,
		/datum/outpost_ambient_work/pipe = 2,
	)
	routine = list(
		/datum/ambient_activity/work = 6,
		/datum/ambient_activity/wander = 1,
		/datum/ambient_activity/idle = 1,
		/datum/ambient_activity/chat = 1,
	)

/// Found mid-job: at work on something
/mob/living/basic/ambient_npc/outpost/worker/mechanic/settle_in()
	if(settle_at(/datum/ambient_activity/work))
		return TRUE
	return ..()

/// One mechanic at Halcyon
/datum/ambient_outpost_role/mechanic
	name = "mechanic"
	npc_type = /mob/living/basic/ambient_npc/outpost/worker/mechanic
	outpost_types = list(/obj/structure/overmap/trader_outpost/general)
	max_count = 1
	weight = 3
	gap_low = 1 MINUTES
	gap_high = 2 MINUTES

// =========================================================================
// OFF-DUTY PIRATE (the Undertow's Dregs)
// =========================================================================

/// The old off-duty pirate's outfit, without the bounty-companion hand: the cutlass rides the back
/datum/outfit/outpost_off_duty_pirate/ambient
	name = "Off-duty pirate (Undertow regular)"
	r_hand = null
	back = /obj/item/claymore/cutlass

/// A drinker flavour: their own lines while sober, the drinker's staged lines once they've had a few
/mob/living/basic/ambient_npc/outpost/drinker/off_duty_pirate
	desc = "Off duty, and about as relaxed as a pirate gets. The cutlass is mostly decorative."
	outfit_choices = list(/datum/outfit/outpost_off_duty_pirate/ambient)
	/// Their own lines, tried before the drinker's
	var/flavour_section = "off_duty_pirate"

/mob/living/basic/ambient_npc/outpost/drinker/off_duty_pirate/get_lines(context)
	if(context == AMBIENT_LINE_IDLE || context == AMBIENT_LINE_ATTACKED || (context == AMBIENT_LINE_TALK && drunk == 0))
		var/list/lines = ambient_dialogue_lines(dialogue_file, flavour_section, context)
		if(length(lines))
			return lines
	return ..()

/// One off-duty pirate at the Undertow, inheriting the drinker's wanted() and arrive()
/datum/ambient_outpost_role/drinker/off_duty_pirate
	name = "off-duty pirate"
	npc_type = /mob/living/basic/ambient_npc/outpost/drinker/off_duty_pirate
	outpost_types = list(/obj/structure/overmap/trader_outpost/black_market)
	max_count = 1
	weight = 2
