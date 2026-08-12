/**
 * # Cyberware stealth support
 *
 * The Ghostskin Weave (ware_military.dm) fades its bearer to an alpha shimmer,
 * which fools humans but means nothing to NPC AI, basic mobs target by
 * reference, not by pixels. This file is the AI half of the camo: a trait the
 * weave holds while active, and a chained override of the basic-mob targeting
 * strategy that refuses camo'd targets beyond point-blank range.
 *
 * The override lives HERE, in a cyberware-owned file, rather than in the
 * shared AI files: defining the same proc a second time is this fork's blessed
 * way to patch upstream behavior (the later .dme include wraps the earlier
 * definition, and `..()` calls straight into it). Nothing outside this module
 * changes on disk.
 *
 * TRAIT_CYBER_CAMO itself lives in voidcrew/_DEFINES/cyberware.dm, because
 * the chrome read (cyberware_scan.dm) is included ahead of this file and also
 * has to know about camo. The range below is deliberately NOT #undef'd,
 * Ghostskin in ware_military_body.dm is included after this file.
 */

/// Within this range, NPCs spot a camo'd target anyway, walking through a
/// fauna pack point-blank is still a bad idea. The PvP/PvE counterplay floor.
#define CYBERWARE_CAMO_SPOT_RANGE 2

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
	if(!isliving(the_target))
		return .
	if(!HAS_TRAIT(the_target, TRAIT_CYBER_CAMO))
		return .
	if(get_dist(living_mob, the_target) <= CYBERWARE_CAMO_SPOT_RANGE)
		return .
	return FALSE
