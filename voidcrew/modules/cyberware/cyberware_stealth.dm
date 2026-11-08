/**
 * # Cyberware stealth support
 *
 * The Ghostskin Weave (ware_military.dm) fades its bearer to an alpha shimmer,
 * which fools humans but means nothing to NPC AI, basic mobs target by
 * reference, not by pixels. This file is the AI half of the camo: a trait the
 * weave holds while active, one shared question (cyberware_camo_hides()), and
 * the hooks that ask it for everything that hunts the bearer by sight.
 *
 * Everything that grants TRAIT_CYBER_CAMO is hidden from:
 * - basic mobs (the targeting strategy below, which every strategy subtype
 *   inherits through its own `..()` calls),
 * - simple_animal hostiles (hermits, ice demons, polar bears, ...),
 * - every porta_turret subtype: ruin and Syndicate turrets, hull defense
 *   turrets, player-built turrets, trader and player outpost turrets, including
 *   a player an outpost has marked,
 * and, through one-line calls in the files that own them, the scripted target
 * picks that never go through a strategy: the club's mobsters, patrol troopers
 * opening a closet, the lich's thralls and the outpost experiments.
 *
 * What camo does NOT hide from: anything within CYBERWARE_CAMO_SPOT_RANGE
 * tiles, and the mobs in GLOB.cyberware_camo_piercing_types (megafauna,
 * elites and bosses). Ship weapons that target ships, not people, are not
 * covered here. The street Flickerskin never grants the trait at all.
 *
 * The overrides live HERE, in a cyberware-owned file, rather than in the
 * shared AI files: defining the same proc a second time is this fork's blessed
 * way to patch upstream behavior (the later .dme include wraps the earlier
 * definition, and `..()` calls straight into it). That only works for a proc
 * whose first definition is included BEFORE this file, so the hooks for the
 * voidcrew files that include after it (the lich, the patrol, the experiments)
 * are a single call to cyberware_camo_hides() in the proc that picks the target.
 *
 * TRAIT_CYBER_CAMO itself lives in voidcrew/_DEFINES/cyberware.dm, because
 * the chrome read (cyberware_scan.dm) is included ahead of this file and also
 * has to know about camo. The range below is deliberately NOT #undef'd,
 * Ghostskin in ware_military_body.dm is included after this file.
 */

/// Within this range, NPCs spot a camo'd target anyway, walking through a
/// fauna pack point-blank is still a bad idea. The PvP/PvE counterplay floor.
#define CYBERWARE_CAMO_SPOT_RANGE 2

/// Mobs that see straight through optical camo, whatever it is: megafauna,
/// mining elites and the bosses and mini bosses of the ruins, bounties, lairs
/// and outposts. A typecache, so subtypes count.
GLOBAL_LIST_INIT(cyberware_camo_piercing_types, typecacheof(list(
	/mob/living/simple_animal/hostile/megafauna,
	/mob/living/simple_animal/hostile/asteroid/elite,
	/mob/living/basic/boss,
	/mob/living/basic/lich,
	/mob/living/basic/hoarfrost_matriarch,
	/mob/living/basic/bounty_criminal/boss,
	/mob/living/basic/bounty_criminal/kingpin,
	/mob/living/basic/bounty_lair_boss,
	/mob/living/basic/outpost_experiment/horror,
	/mob/living/basic/alien/queen/large/derelict,
	/mob/living/basic/vestige_oracle,
	/mob/living/basic/vestige_mutant,
	/mob/living/basic/vestige_warframe,
)))

/**
 * Whether optical camo hides `target` from `viewer` right now: the target holds
 * TRAIT_CYBER_CAMO, the viewer is further off than CYBERWARE_CAMO_SPOT_RANGE and
 * the viewer is not one of the mobs that sees through it. `viewer` is whatever
 * is doing the looking (a mob, a turret, a creature picking its next victim).
 * Anything that is not a living mob is never hidden.
 */
/proc/cyberware_camo_hides(mob/living/target, atom/viewer)
	if(!isliving(target) || !HAS_TRAIT(target, TRAIT_CYBER_CAMO))
		return FALSE
	if(!viewer)
		return TRUE
	if(get_dist(viewer, target) <= CYBERWARE_CAMO_SPOT_RANGE)
		return FALSE
	if(is_type_in_typecache(viewer, GLOB.cyberware_camo_piercing_types))
		return FALSE
	return TRUE

/**
 * Chained override of the stock basic targeting strategy (base definition:
 * code/datums/ai/basic_mobs/targeting_strategies/basic_targeting_strategy.dm).
 * Runs the stock filter first; on a pass, additionally refuses living targets
 * under optical camo unless they are within spot range. Subtype strategies
 * (`/basic/of_size`, `/basic/not_friends`, ...) inherit this through their own
 * `..()` calls, so the whole basic-mob family honors camo with one hook.
 */
/datum/targeting_strategy/basic/can_attack(mob/living/living_mob, atom/the_target, vision_range)
	. = ..()
	if(!.)
		return
	if(cyberware_camo_hides(the_target, living_mob))
		return FALSE
	return .

/**
 * The same for simple_animal hostiles, whose single gate is CanAttack() (base
 * definition: code/modules/mob/living/simple_animal/hostile/hostile.dm). They
 * ask it when they pick a target and again every tick they chase one, so a
 * camo field that goes up mid-chase makes them lose the target.
 */
/mob/living/simple_animal/hostile/CanAttack(atom/the_target)
	. = ..()
	if(!.)
		return
	if(cyberware_camo_hides(the_target, src))
		return FALSE
	return .

/**
 * Every porta_turret, however it finds its targets (the stock scan, the hull
 * defense turret's, the outpost's), hands the list it wants to shoot at to
 * tryToShootAt(). Anyone camo'd and out of spot range is dropped from it. A
 * turret left with nothing behaves as one that found nothing (the cover goes
 * back down) instead of standing up for a target it cannot see.
 */
/obj/machinery/porta_turret/tryToShootAt(list/atom/movable/targets)
	var/hid_someone = FALSE
	for(var/mob/living/candidate in targets.Copy())
		if(cyberware_camo_hides(candidate, src))
			targets -= candidate
			hid_someone = TRUE
	if(hid_someone && !length(targets))
		if(!always_up)
			popDown()
		return FALSE
	return ..()
