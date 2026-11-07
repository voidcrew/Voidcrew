/obj/item/research_notes
	desc = "Valuable scientific data."

/obj/item/research_notes/attackby(obj/item/attacking_item, mob/living/user, list/modifiers, list/attack_modifiers)
	if(istype(attacking_item, /obj/item/research_notes))
		merge(attacking_item)
		return
	return ..()

/// Combining papers conserves their value, regardless of their origin or merge order.
/obj/item/research_notes/merge(obj/item/research_notes/new_paper)
	if(QDELETED(new_paper) || new_paper == src)
		return FALSE
	value += new_paper.value
	change_vol()
	qdel(new_paper)
	return TRUE

// Research notes for ruins. Priced against the node ladder in code/__DEFINES/research.dm,
// where a node runs 40 (tier 1) to 200 (tier 5): a tiny note is worth about two cheap nodes
// and a genius note clears five of the most expensive ones.
/obj/item/research_notes/loot
	origin_type = "exotic particle physics"

/obj/item/research_notes/loot/tiny
	value = 100

/obj/item/research_notes/loot/small
	value = 250

/obj/item/research_notes/loot/medium
	value = 500

/obj/item/research_notes/loot/big
	value = 750

/obj/item/research_notes/loot/genius//have a very good reason to give this one out
	value = 1000

/obj/item/research_notes/loot/custom
	value = 0
