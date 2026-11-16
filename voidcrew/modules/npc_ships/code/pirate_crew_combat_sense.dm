/**
 * Combat sense for faction pirates (voidcrew/modules/human_npcs/human_npc_combat_sense.dm): NPC ship crews,
 * boarders, NT customs and the crews squatting in ruins, every faction and rank.
 *
 * What they carry is #509's and unchanged: the rank and file no stimulant; captains a combat stimpack and
 * bosses a stimulant pen, which they inject as their fight starts (pirate_crew_human_self_care). So the
 * stimulant half only ever fires for a pirate still holding an unused stimulant. Under stun fire:
 * - a gunner runs for cover, but only on its crew's battlefield, a captain or helm guard only within
 *   PIRATE_CREW_POST_LEASH of its post, and a pirate with no crew only within PIRATE_CREWLESS_LEASH of
 *   where it was put; never onto open space;
 * - a gunner told to hold its ground against someone off the battlefield (target_hold_ground) stays put
 *   and shoots back, as before;
 * - a melee pirate, or a shotgunner (its gun handling's close_range), charges the shooter.
 */
/datum/npc_combat_sense/pirate_crew

/mob/living/carbon/human/npc/faction_pirate
	npc_combat_sense = /datum/npc_combat_sense/pirate_crew

/datum/npc_combat_sense/pirate_crew/may_move(mob/living/carbon/human/npc, datum/ai_controller/controller)
	var/datum/ai_controller/basic_controller/pirate_crew/pirate_controller = controller
	return !(istype(pirate_controller) && pirate_controller.target_hold_ground)

/datum/npc_combat_sense/pirate_crew/reach(mob/living/carbon/human/npc, datum/ai_controller/controller)
	if(!pirate_crew_human_gunner(npc))
		return 1
	var/obj/item/gun/gun = human_npc_held_gun(npc)
	if(gun)
		var/datum/pirate_gun_handling/handling = pirate_gun_handling_for(gun)
		if(handling?.close_range)
			return handling.close_range
	return controller.blackboard[BB_HUMAN_NPC_FIRE_RANGE] || 7

/datum/npc_combat_sense/pirate_crew/tile_ok(mob/living/carbon/human/npc, datum/ai_controller/controller, turf/tile)
	if(!..() || pirate_turf_is_void(tile))
		return FALSE
	var/datum/ai_controller/basic_controller/pirate_crew/pirate_controller = controller
	var/datum/pirate_crew/crew = istype(pirate_controller) ? pirate_controller.get_crew() : null
	if(crew)
		if(!crew.turf_on_battlefield(tile))
			return FALSE
		if(!crew.holds_post(npc))
			return TRUE
		var/turf/post = crew.post_for(npc)
		return isnull(post) || (post.z == tile.z && get_dist(post, tile) <= PIRATE_CREW_POST_LEASH)
	var/turf/home = controller.blackboard[BB_PIRATE_CREWLESS_HOME]
	return isnull(home) || home.z != tile.z || get_dist(home, tile) <= PIRATE_CREWLESS_LEASH
