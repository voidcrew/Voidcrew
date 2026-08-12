/**
 * The wild gorilla: the only gorilla that spawns from a biome table (jungle/dense
 * and the jungle dangerous tier, see datums/mapgen/biomes/jungle_biomes.dm).
 *
 * Upstream tunes /mob/living/basic/gorilla as a rare station-event ape that a whole
 * shift's worth of players converges on. As ambient planet fauna those numbers are
 * unfair rather than hard, so the wild one is retuned here. The overrides live on
 * this subtype and not on the parent so upstream's gorilla stays untouched.
 *
 * What was actually oppressive, in order:
 *
 * - Dismemberment with surgery_time = 0. Past SOFT_CRIT every hit tore off a limb
 *   with no do_after and, because amputate() only prints its warning when
 *   surgery_time > 0, no message either. Re-added below with a real cast time, so
 *   it is telegraphed and a crewmate can interrupt it.
 * - paralyze_chance 20 at CLICK_CD_MELEE with a 2 second Paralyze: a stunlock that
 *   fed the dismemberment. Zeroed, as upstream's own /genetics and /hostile do,
 *   which routes every hit into the parent's throw_at instead. The knockback is the
 *   gorilla's identity here and it gives the target ground to break away over.
 * - speed -0.1 against RUN_DELAY 1.5 meant it outran an unencumbered human, so
 *   there was no disengage at all. Now slower than a running crewman but still on
 *   top of anyone in a suit or hauling.
 */
/mob/living/basic/gorilla/beach
	faction = list("jungle", "beach")
	maxHealth = 160
	health = 160
	speed = 0.3
	melee_damage_lower = 16
	melee_damage_upper = 22
	obj_damage = 25
	paralyze_chance = 0

/mob/living/basic/gorilla/beach/Initialize(mapload)
	. = ..()
	// Swap the parent's instant, silent amputation for a telegraphed one.
	qdel(GetComponent(/datum/component/amputating_limbs))
	AddComponent(
		/datum/component/amputating_limbs, \
		surgery_time = 4 SECONDS, \
		surgery_verb = "punches", \
		minimum_stat = UNCONSCIOUS, \
		snip_chance = 50, \
	)
