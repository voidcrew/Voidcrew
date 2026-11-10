/**
 * Combat sense for bounty fighters (voidcrew/modules/human_npcs/human_npc_combat_sense.dm): normal
 * criminals and their companions. Meek criminals (they run), decoys (patrons) and bosses (their own
 * stimulant and fallback, bounty_boss.dm) don't have it.
 *
 * What they carry: a Wanted normal criminal also packs a stimpack (bounty_ai_normal.dm,
 * bounty_build_outfit(); every Most Wanted is a mini-boss with its own pens), used when it tires in a fight, when its style leaves a
 * pocket free (brawler, club, bottle, shotgun; not pistol or knife). Petty criminals and companions carry
 * none. Under stun fire a criminal whose style shoots or throws from range runs for
 * cover; a brawler, knife, club or shotgun style charges the shooter. Cover stays on the criminal's leash
 * (leash_ok(); a companion keeps to its criminal's), and the movement is the bounty AI's own leash pathing.
 */
/datum/npc_combat_sense/bounty

/mob/living/carbon/human/npc/bounty_criminal/normal
	npc_combat_sense = /datum/npc_combat_sense/bounty

/mob/living/carbon/human/npc/bounty_companion
	npc_combat_sense = /datum/npc_combat_sense/bounty

/datum/npc_combat_sense/bounty/can_act(mob/living/carbon/human/npc, datum/ai_controller/controller)
	if(!..())
		return FALSE
	if(istype(npc, /mob/living/carbon/human/npc/bounty_criminal))
		var/mob/living/carbon/human/npc/bounty_criminal/criminal = npc
		return criminal.ai_can_act() && !criminal.hidden && !criminal.blended
	if(istype(npc, /mob/living/carbon/human/npc/bounty_companion))
		var/mob/living/carbon/human/npc/bounty_companion/companion = npc
		return companion.ai_can_fight()
	return TRUE

// A criminal shares the players' faction until its placement says otherwise: its gang is its side.
/datum/npc_combat_sense/bounty/allied(mob/living/carbon/human/npc, atom/shooter)
	return bounty_ai_same_gang(npc, shooter)

/datum/npc_combat_sense/bounty/in_fight(mob/living/carbon/human/npc, datum/ai_controller/controller, datum/component/npc_combat_sense/sense)
	return bounty_ai_fighting(npc) || sense.under_fire()

/// Its style's distance: a gun style's shooting range, 1 for the melee styles
/datum/npc_combat_sense/bounty/reach(mob/living/carbon/human/npc, datum/ai_controller/controller)
	var/datum/bounty_style/style = bounty_ai_style(npc)
	if(!style?.ranged)
		return 1
	var/datum/ai_behavior/shoot = GET_AI_BEHAVIOR(style.ranged_behavior)
	return shoot?.required_distance || BOUNTY_PISTOL_RANGE

/datum/npc_combat_sense/bounty/tile_ok(mob/living/carbon/human/npc, datum/ai_controller/controller, turf/tile)
	if(!..())
		return FALSE
	var/mob/living/carbon/human/npc/bounty_criminal/side = bounty_ai_side_of(npc)
	return isnull(side) || side.leash_ok(tile)
