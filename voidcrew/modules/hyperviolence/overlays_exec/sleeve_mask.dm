// Hyperviolence: no empty sleeves on a stump.
//
// tg masks the gloves over a missing hand (update_worn_gloves() in human_update_icons.dm, a render_target
// alpha mask) but draws the jumpsuit and suit over a missing arm or leg, so every stump sat on an empty
// sleeve or trouser leg. This masks both the same way, for any lost arm or leg however it was lost. The
// masks (icons/sleeve_masks.dmi) are tg's human limb sprites less every other body part, a pixel wider,
// so the torso keeps its own cloth. Bodies of another shape get no mask: theirs would not line up.
//
// Sorts after gore_overlays.dm on purpose: it chains hv_update_gore_overlays(), which runs whenever a
// limb comes off or goes back on.

#define HV_SLEEVE_MASK_ICON 'voidcrew/modules/hyperviolence/overlays_exec/icons/sleeve_masks.dmi'
/// Filter on a masked uniform or suit overlay.
#define HV_SLEEVE_MASK_FILTER "hv_sleeve_mask"

/mob/living/carbon/human
	/// The lost limbs the uniform and suit were last drawn for, so they are redrawn only when that changes.
	var/hv_sleeve_key = ""

/mob/living/carbon/human/update_worn_undersuit(update_obscured = TRUE)
	. = ..()
	hv_mask_sleeves(UNIFORM_LAYER)

/mob/living/carbon/human/update_worn_oversuit(update_obscured = TRUE)
	. = ..()
	hv_mask_sleeves(SUIT_LAYER)

/mob/living/carbon/human/hv_update_gore_overlays()
	. = ..()
	var/key = jointext(hv_sleeve_mask_zones(), ",")
	if(key == hv_sleeve_key)
		return
	hv_sleeve_key = key
	update_worn_undersuit()
	update_worn_oversuit()

/// The arms and legs this body has lost, if its clothes are drawn on a human shape. Empty otherwise.
/mob/living/carbon/human/proc/hv_sleeve_mask_zones()
	. = list()
	if(!(bodyshape & BODYSHAPE_HUMANOID) || (bodyshape & (BODYSHAPE_MONKEY | BODYSHAPE_DIGITIGRADE)))
		return
	for(var/zone in list(BODY_ZONE_L_ARM, BODY_ZONE_R_ARM, BODY_ZONE_L_LEG, BODY_ZONE_R_LEG))
		if(!get_bodypart(zone))
			. += zone

/// Cuts the lost limbs out of the worn overlay at `cache_index` (the uniform or the suit).
/mob/living/carbon/human/proc/hv_mask_sleeves(cache_index)
	var/mutable_appearance/worn = overlays_standing[cache_index]
	if(!istype(worn))
		return
	var/list/missing = hv_sleeve_mask_zones()
	if(!length(missing))
		return
	cut_overlay(worn)
	var/mutable_appearance/mask = mutable_appearance(HV_SLEEVE_MASK_ICON, "missing_[missing[1]]")
	for(var/i in 2 to length(missing))
		mask.overlays += mutable_appearance(HV_SLEEVE_MASK_ICON, "missing_[missing[i]]")
	mask.render_target = "*hv_sleeves [cache_index] [REF(src)]"
	worn.overlays += mask
	// Before the height filters (priority 1), so the mask cuts the sprite it was drawn for.
	worn.add_filter(HV_SLEEVE_MASK_FILTER, 0, alpha_mask_filter(render_source = mask.render_target, flags = MASK_INVERSE))
	add_overlay(worn)

#undef HV_SLEEVE_MASK_FILTER
