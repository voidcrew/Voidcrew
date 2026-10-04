/**
 * # Supply pod containment
 *
 * What a supply pod (code/modules/cargo/supplypod.dm) refuses to carry, alongside the closet rules
 * in voidcrew/edits/objects/structures/closet_containment.dm. Part of the outpost prison's
 * containment (voidcrew/modules/player_outposts/outpost_prison_containment.dm).
 */

// Supply pods take any living mob on their tile when they leave. Mobs banned from containment
// (outpost prisoners, traders, ambient outpost NPCs, vestige patrons) stay behind, as they do for lockers.
/obj/structure/closet/supplypod/insertion_allowed(atom/to_insert)
	if(HAS_TRAIT(to_insert, TRAIT_NO_CONTAINMENT))
		return FALSE
	return ..()
