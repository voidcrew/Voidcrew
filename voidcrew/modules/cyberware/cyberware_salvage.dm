/**
 * # Chrome salvage
 *
 * Cyberware outlives the body it was wired into.
 *
 * Chrome is the most expensive thing a player owns, vouchers, a trip to the
 * parlor, and a Chrome Cradle is the only thing that takes it back out again.
 * Every body-destroying death in the game, meanwhile, deletes organs outright:
 * tg's gib() only spills organs when the caller passes DROP_ORGANS and most
 * callers pass nothing at all, dust() qdels the whole mob, and a severed limb
 * qdels its own contents when it burns. A bad enough death silently erased a
 * build and left whoever earned the kill nothing to pick up.
 *
 * Three chokepoints, each of them ahead of the deletion:
 * - gib(), through its spill_organs() step, before the drop flags get a say
 * - dust(), before the body is queued for deletion
 * - a severed limb being destroyed with chrome still inside it
 *
 * Only chrome is rescued. Meat organs keep tg's rules exactly, so gibbing
 * still looks and loots the way it always did apart from the hardware.
 */

/**
 * Pulls every piece of chrome out of a body and leaves it on the floor.
 *
 * Safe to call on a mob that is mid-death or about to be deleted: removal is
 * special, so nothing tries to update a body that won't be there, and a body
 * in nullspace has nowhere to drop and is left alone.
 *
 * Returns how many pieces it dropped.
 */
/proc/cyberware_eject_all(mob/living/carbon/body, scatter = TRUE)
	if(!iscarbon(body))
		return 0
	var/turf/drop_turf = get_turf(body)
	if(!drop_turf)
		return 0

	// Snapshot the list. Remove() cuts entries out of organs as we go, and a
	// live loop would skip every other piece. Typed rather than `as anything`
	// for the hard-delete nulls documented in cyberware_component.dm.
	var/dropped = 0
	for(var/obj/item/organ/ware in body.organs.Copy())
		if(!ware.GetComponent(/datum/component/cyberware))
			continue
		// special = TRUE: the body is on its way out, so skip the cosmetic
		// body and HUD updates, and never let a vital slot re-trigger death().
		ware.Remove(body, special = TRUE)
		ware.forceMove(drop_turf)
		if(scatter)
			ware.throw_at(get_edge_target_turf(body, pick(GLOB.alldirs)), rand(1, 3), 5)
		dropped++

	if(!dropped)
		return 0
	do_sparks(min(dropped, 3), TRUE, drop_turf)
	drop_turf.visible_message(span_warning("Chrome hardware clatters loose across the floor."))
	return dropped

/**
 * Gibbing. The parent qdels every organ the drop flags don't cover, so the
 * chrome comes out first and the flags only ever see meat.
 */
/mob/living/carbon/spill_organs(drop_bitflags = NONE)
	cyberware_eject_all(src)
	return ..()

/**
 * Dusting. The parent queues the body for deletion on a timer, which takes
 * the organs with it, so the chrome comes out before that starts. No scatter
 * here: nothing exploded, the body just stopped being there.
 */
/mob/living/carbon/dust(just_ash, drop_items, force)
	cyberware_eject_all(src, scatter = FALSE)
	return ..()

/**
 * A severed limb with chrome in it. tg's bodypart Destroy() qdels its whole
 * contents, so an arm that burns up takes the blades in it along too.
 *
 * Ownerless limbs only. A limb still attached to a body is the two mob-level
 * paths' problem, they run well before anything gets around to deleting
 * bodyparts, and gating on that keeps this out of ordinary mob cleanup.
 */
/obj/item/bodypart/Destroy()
	var/turf/drop_turf = owner ? null : get_turf(src)
	if(drop_turf)
		for(var/obj/item/organ/ware in contents.Copy())
			if(!ware.GetComponent(/datum/component/cyberware))
				continue
			if(ware.bodypart_remove(src))
				ware.forceMove(drop_turf)
	return ..()
