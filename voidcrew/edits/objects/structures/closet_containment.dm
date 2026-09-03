/**
 * VOIDCREW EDIT: some NPCs cannot be put in a box.
 *
 * Outpost traders, outpost loiterers and vestige patrons are fixtures of the place they
 * stand in. They already cancel COMSIG_MOUSEDROP_ONTO (so nothing can be drag-dropped
 * onto a closet, a disposal unit or a bed) and carry move_resist = INFINITY (so nothing
 * shoves or pulls them off their tile), but neither of those sits on the path a container
 * actually uses to take a mob aboard: close() calls take_contents(), which sweeps every
 * movable standing on the closet's own tile through insert(). A body bag is
 * density = FALSE, so it can be pulled onto an occupied tile and simply zipped shut.
 * That is issue #131 - an outpost's entire staff carried off in a bluespace body bag.
 *
 * insertion_allowed() is the single gate every container path runs through: lockers,
 * crates, secure closets, body bags, environmental bags and roller beds all reach it, and
 * the bluespace bag's fold-up can only pack what is already inside the bag. So the rule
 * lives here, once, instead of in each of them.
 */
/obj/structure/closet/insertion_allowed(atom/movable/inserting)
	if(HAS_TRAIT(inserting, TRAIT_NO_CONTAINMENT))
		return FALSE
	return ..()

/**
 * Says why, to whoever just tried it.
 *
 * insertion_allowed() has no user to talk to and take_contents() drops the refusal on the
 * floor, so without this the bag just closes empty and the player is left guessing. The
 * close itself still goes ahead - everything else on the tile packs normally, the NPC
 * simply is not in there.
 */
/obj/structure/closet/before_close(mob/living/user)
	. = ..()
	if(!. || !user)
		return
	for(var/mob/living/bystander in drop_location())
		if(!HAS_TRAIT(bystander, TRAIT_NO_CONTAINMENT))
			continue
		to_chat(user, span_warning("[bystander] steps out of [src] before you can shut it. \
			[bystander.p_They()] [bystander.p_are()] not going anywhere with you."))
		break

/**
 * One call that makes a mob un-baggable, for the types that should never end up in
 * someone's backpack.
 *
 * Three separate paths can put a mob in a container and they do not share a gate:
 * - a closet/body bag sweeping its own tile on close()  -> TRAIT_NO_CONTAINMENT, above
 * - a storage datum (backpacks, satchels, the folded    -> TRAIT_NO_STORAGE_INSERT,
 *   bluespace bag's own contents)                          code/datums/storage/storage.dm
 * - a drag-drop onto a crate, bed or disposal unit      -> COMSIG_MOUSEDROP_ONTO
 *
 * The outpost traders, loiterers and vestige patrons wire all three up by hand in their
 * own Initialize; this is the same three lines for callers that only need the ban and
 * nothing else around it. override = TRUE so a subtype that re-runs it is not a runtime.
 */
/mob/living/proc/ban_from_containment()
	ADD_TRAIT(src, TRAIT_NO_CONTAINMENT, INNATE_TRAIT)
	ADD_TRAIT(src, TRAIT_NO_STORAGE_INSERT, INNATE_TRAIT)
	RegisterSignal(src, COMSIG_MOUSEDROP_ONTO, PROC_REF(block_containment_mousedrop), override = TRUE)

/// Cancels any attempt to drag-drop this mob onto something (beds, crates, disposals, ...).
/// Deliberately not named block_being_dragged: three subtypes already declare a proc by that
/// name, and re-declaring it on /mob/living would be a duplicate definition.
/mob/living/proc/block_containment_mousedrop(atom/over, mob/user)
	SIGNAL_HANDLER
	return COMPONENT_CANCEL_MOUSEDROP_ONTO
