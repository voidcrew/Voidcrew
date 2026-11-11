/**
 * # Outpost police: cells
 *
 * Owner: P6. The holding cells (/datum/outpost_police_cell), booking, processing, jail terms, bail and
 * release, and the police doors and cell doors (types in police_core.dm). Spec 6.2-6.4 and the cell half of 7.
 */

/// Builds one cell per cell_id from the interior's landmarks, doors and signs (called by link_interior())
/datum/outpost_police/proc/build_cells(list/cell_landmarks, list/cell_doors, list/cell_signs)
	return

/// Whether `who` is in police custody: from the cuffs going on to release
/datum/outpost_police/proc/in_custody(mob/living/who)
	return FALSE

/// Books `suspect`, brought to a cell by `officer`: the fine, then processing or jail. Sleeps. TRUE once the door is shut.
/datum/outpost_police/proc/book(mob/living/carbon/suspect, mob/living/officer)
	return FALSE

/// The lobby tile outside a cell door, or null
/datum/outpost_police/proc/cell_door_turf()
	return null

/// Once a second (police_core.dm tick()): signs, bail, releases, containment
/datum/outpost_police/proc/tick_cells()
	return
