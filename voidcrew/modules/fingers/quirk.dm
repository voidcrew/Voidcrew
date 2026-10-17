/**
 * Fingers, drawn one by one on each hand, that can be lost, cut off and put back (fingers.dm).
 *
 * A hand only has them while the arm is marked as fingered. The quirk marks its holder's arms,
 * and any arm attached later. An arm keeps its fingers once it comes off, so a severed hand
 * still shows what it had.
 */
/datum/quirk/fingers
	name = "Fingers"
	desc = "Your hands have individual fingers. Wiggly, squiggly, ugly little things. \
		They can be lost to wounds or knives, and a hand missing some fumbles what it holds."
	icon = FA_ICON_HAND_SPARKLES
	value = 0
	gain_text = span_notice("You become very aware of your fingers.")
	lose_text = span_notice("Your fingers blur back into your hands.")
	medical_record_text = "Patient has fingers. All of them, for now."

/datum/quirk/fingers/add(client/client_source)
	var/mob/living/carbon/carbon_holder = quirk_holder
	if(!istype(carbon_holder))
		return
	RegisterSignal(carbon_holder, COMSIG_CARBON_POST_ATTACH_LIMB, PROC_REF(on_limb_attached))
	for(var/obj/item/bodypart/arm/hand in carbon_holder.bodyparts)
		hand.fingered = TRUE
	// Grips aren't tracked on hands without fingers, so catch up on whatever is held now.
	carbon_holder.update_finger_grips()
	carbon_holder.update_body_parts()

/datum/quirk/fingers/remove()
	var/mob/living/carbon/carbon_holder = quirk_holder
	if(!istype(carbon_holder))
		return
	UnregisterSignal(carbon_holder, COMSIG_CARBON_POST_ATTACH_LIMB)
	if(QDELETED(carbon_holder))
		return
	for(var/obj/item/bodypart/arm/hand in carbon_holder.bodyparts)
		hand.fingered = FALSE
	carbon_holder.update_body_parts()

/datum/quirk/fingers/proc/on_limb_attached(mob/living/carbon/source, obj/item/bodypart/new_limb, special)
	SIGNAL_HANDLER
	var/obj/item/bodypart/arm/hand = new_limb
	if(istype(hand) && !hand.fingered)
		hand.fingered = TRUE
		source.update_finger_grips()
		source.update_body_parts()
