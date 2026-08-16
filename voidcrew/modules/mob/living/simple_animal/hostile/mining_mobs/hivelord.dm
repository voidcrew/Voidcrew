/**
 * Legions close and fight instead of running away forever.
 *
 * Upstream hands a legion exactly two combat subtrees: the skull launcher, and a
 * flee subtree. The launcher ends planning on the tick it fires, so on every tick
 * in between - the launcher sits on a four second cooldown - the only thing left
 * to plan is running away. The parent legion therefore never closes with anything
 * and every point of damage in the fight comes from the brood it spits out.
 *
 * On lavaland that reads as a set piece you push through. On voidcrew planets
 * legions are ordinary biome spawns - they are in the snow, wasteland and lava
 * tables and in both cave generators - and a common mob that retreats forever is
 * a fight that never resolves. Rounds 14/15 reported it as "legions only run away
 * now", which is not a bug in anything the fork wrote, just upstream's design
 * landing badly at the frequency we spawn them.
 *
 * The launcher is untouched, so a legion still opens with a skull and still keeps
 * one arriving every four seconds. What changes is the other ticks - it walks in
 * and bites. The only retreat it keeps is upstream's escape_captivity, which is
 * about getting out of a closet or a grab rather than about combat.
 */
/datum/ai_controller/basic_controller/legion
	planning_subtrees = list(
		/datum/ai_planning_subtree/escape_captivity,
		/datum/ai_planning_subtree/random_speech/legion,
		/datum/ai_planning_subtree/simple_find_target,
		/datum/ai_planning_subtree/targeted_mob_ability,
		/datum/ai_planning_subtree/basic_melee_attack_subtree/legion,
	)

/**
 * A legion's targeting strategy deliberately picks up wounded friendlies as well
 * as enemies, because a skull that lands on an ally heals it instead of biting it.
 * Melee has to honour that exception or a legion would beat its own wounded to
 * death; upstream's flee subtree carried the same check for the same reason.
 */
/datum/ai_planning_subtree/basic_melee_attack_subtree/legion

/datum/ai_planning_subtree/basic_melee_attack_subtree/legion/SelectBehaviors(datum/ai_controller/controller, seconds_per_tick)
	var/mob/living/target = controller.blackboard[BB_BASIC_MOB_CURRENT_TARGET]
	if (QDELETED(target) || target.faction_check_atom(controller.pawn))
		return // Only swing at a hostile target; friendlies are getting healed, not hit.
	return ..()

/mob/living/basic/mining/legion/wasteland
	faction = list(FACTION_WASTELAND)

/mob/living/basic/mining/legion/large/wasteland
	faction = list(FACTION_WASTELAND)

// Reebe's corrupted legion, ported from Voidcrew-LRP's "disfigured legion".
/mob/living/basic/mining/legion/crystal
	name = "disfigured legion"
	desc = "Disfigured, contorted, and corrupted. This thing was once part of the legion, now it has a different vile and twisted allegiance."
	icon = 'voidcrew/icons/mob/lavaland_monsters.dmi'
	icon_state = "disfigured_legion"
	icon_living = "disfigured_legion"
	icon_dead = "disfigured_legion"
	icon_gib = null
	maxHealth = 90
	health = 90
	brood_type = /mob/living/basic/legion_brood/crystal

/mob/living/basic/mining/legion/crystal/wasteland
	faction = list(FACTION_WASTELAND)

/mob/living/basic/legion_brood/crystal
	name = "disfigured legion"
	desc = "One of none."
	icon = 'voidcrew/icons/mob/lavaland_monsters.dmi'
	icon_state = "disfigured_legion_head"
	icon_living = "disfigured_legion_head"

// Crystal broods burst into shards when destroyed.
/mob/living/basic/legion_brood/crystal/death(gibbed)
	var/turf/origin = get_turf(src)
	for(var/i in 0 to 4)
		var/obj/projectile/shard = new /obj/projectile/bullet/shrapnel/short_range(origin)
		shard.aim_projectile(get_step(src, pick(GLOB.alldirs)), origin)
		shard.firer = src
		shard.fire(i * (360 / 5))
	return ..()

/mob/living/basic/mining/hivelord/beach
	name = "crystal hivelord"
	icon = 'voidcrew/icons/mob/beach/beach_hivelord.dmi'
	icon_state = "hivelord"
	icon_living = "hivelord"
	icon_dead = "hivelord_dead"
	icon_gib = null
	faction = list(FACTION_BEACH, FACTION_CRYSTAL)
	death_spawn_type = /mob/living/basic/hivelord_brood/beach

/mob/living/basic/hivelord_brood/beach
	icon = 'voidcrew/icons/mob/beach/beach_hivelord.dmi'
	icon_state = "hivelord_tentacle"
	icon_living = "hivelord_tentacle"
	icon_dead = "hivelord_tentacle"
	icon_gib = null
	pixel_x = 6
	color = COLOR_BRIGHT_BLUE
	faction = list(FACTION_BEACH, FACTION_CRYSTAL)
