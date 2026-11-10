/**
 * Combat sense for a prison's NPC guards (voidcrew/modules/human_npcs/human_npc_combat_sense.dm).
 *
 * Guards never strike players and carry no stimulant, so theirs is the cover half only: on duty and shot
 * with stun rounds by anyone but a fellow guard, a guard gets out of the line of fire, inside the wing,
 * keeps down a moment, then goes back to whatever it was doing (its routine plans again). It never
 * charges anyone (close_in_reach 0). The prison's own turrets aren't a threat it reacts to: only people
 * and mechs are.
 */
/datum/npc_combat_sense/prison_guard
	use_stims = FALSE
	close_in_reach = 0

/mob/living/carbon/human/npc/outpost_prison_guard
	npc_combat_sense = /datum/npc_combat_sense/prison_guard

/datum/npc_combat_sense/prison_guard/can_act(mob/living/carbon/human/npc, datum/ai_controller/controller)
	var/mob/living/carbon/human/npc/outpost_prison_guard/guard = npc
	return istype(guard) && guard.on_duty() && ..()

// Players share the guards' faction: only another guard's shot is friendly fire.
/datum/npc_combat_sense/prison_guard/allied(mob/living/carbon/human/npc, atom/shooter)
	return is_outpost_prison_guard(shooter)

/datum/npc_combat_sense/prison_guard/tile_ok(mob/living/carbon/human/npc, datum/ai_controller/controller, turf/tile)
	if(!..())
		return FALSE
	var/mob/living/carbon/human/npc/outpost_prison_guard/guard = npc
	var/area/wing = istype(guard) ? guard.prison?.wing : null
	return isnull(wing) || get_area(tile) == wing
