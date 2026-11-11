/**
 * # Outpost police: life and voice
 *
 * Owner: P3. The officers' routines (beat, coffee, chat, the sergeant's desk), the ambient roles that bring
 * them, what they say and the radio. Spec 11. Lines come from AMBIENT_STRINGS_POLICE by profile section.
 */

// ===== ROLES (no npc_type until P3 fills them, so nobody comes) =====

/datum/ambient_outpost_role/police_beat
	name = "police beat"

/datum/ambient_outpost_role/police_sergeant
	name = "police sergeant"

// ===== VOICE =====

/// Says one line of kind `line` (POLICE_LINE_*); `values` fill %PLACE% and %LOOK%; on the radio if `radio`
/mob/living/carbon/human/npc/ambient_npc/outpost/police/proc/police_say(line, list/values, radio = FALSE)
	return

/// The sergeant (or the nearest officer) says `line` on the radio
/datum/outpost_police/proc/say_dispatch(line, list/values)
	return

/// Once a second (police_core.dm tick()): dispatch chatter, officer-down calls, the all-clear
/datum/outpost_police/proc/tick_life()
	return
