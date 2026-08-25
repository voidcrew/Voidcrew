/**
 * Plasmamen spawn with a spare plasma tank in their bag.
 *
 * A plasmaman starts holding exactly one belt tank and nothing else. Out here that tank is the
 * whole life support budget for the round: there is no station atmospherics to refill from, the
 * only other source is a suit vendor on a trader outpost, and a ship that undocks before its
 * plasmaman thinks to buy one has stranded them. One spare in the backpack buys enough time to
 * get somewhere that sells more.
 *
 * Runs after the parent, because the job outfit is what supplies the backpack - at
 * [/datum/species/plasmaman/pre_equip_species_outfit] time there is nothing to put the tank in.
 */
/mob/living/carbon/human/dress_up_as_job(datum/job/equipping, visual_only = FALSE, client/player_client, consistent = FALSE)
	. = ..()
	if(visual_only || !isplasmaman(src))
		return

	var/obj/item/tank/internals/plasmaman/belt/full/spare = new(src)
	// Backpack first, then a belt or satchel-ish alternative, then a pocket for the bagless jobs.
	if(equip_to_storage(spare, ITEM_SLOT_BACK, indirect_action = TRUE))
		return
	if(equip_to_storage(spare, ITEM_SLOT_BELT, indirect_action = TRUE))
		return
	if(!equip_to_slot_if_possible(spare, ITEM_SLOT_LPOCKET, disable_warning = TRUE) && !equip_to_slot_if_possible(spare, ITEM_SLOT_RPOCKET, disable_warning = TRUE))
		qdel(spare)
