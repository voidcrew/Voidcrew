/// Everything you do, your body acts out: see limb_rig.dm. Roundstart species are rigged anyway
/// (species_shapes.dm); this is for anyone else human-shaped.
/datum/quirk/overanimated
	name = "Overanimated"
	desc = "Your whole body acts out everything you do: walking, running, working with tools, every emote. \
		Far too much. Purely cosmetic."
	icon = FA_ICON_PERSON_RUNNING
	value = 0
	gain_text = span_notice("You feel extremely expressive.")
	lose_text = span_notice("You feel stiff.")
	medical_record_text = "Patient cannot stop gesticulating."

/datum/quirk/overanimated/add(client/client_source)
	var/mob/living/carbon/carbon_holder = quirk_holder
	if(istype(carbon_holder))
		carbon_holder.update_limb_rig()

/datum/quirk/overanimated/remove()
	var/mob/living/carbon/carbon_holder = quirk_holder
	if(!istype(carbon_holder) || QDELETED(carbon_holder))
		return
	carbon_holder.update_limb_rig()
