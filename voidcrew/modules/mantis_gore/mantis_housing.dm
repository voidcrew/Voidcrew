// The housing side of the Mantis line's gore: the combat stance while a blade is out (the guard pose,
// the fists raised, a glint now and then), the flick of blood on the way back in, and the stain the
// housing keeps until it is washed. See mantis_core.dm for the overview.

/obj/item/organ/cyberimp/arm/toolkit/cyberware/mantis
	/// Raises the fist on the arm while the blade is out.
	var/datum/bodypart_overlay/mantis_stance/stance_overlay
	/// The arm it is on.
	var/datum/weakref/stance_limb
	/// Timer of the next glint.
	var/glint_timer
	/// Blood flicked off the blade has left the housing stained.
	var/stained = FALSE
	/// Colour of that stain.
	var/stain_color

/obj/item/organ/cyberimp/arm/toolkit/cyberware/mantis/Destroy()
	stance_off()
	stop_glint()
	return ..()

/obj/item/organ/cyberimp/arm/toolkit/cyberware/mantis/on_mob_insert(mob/living/carbon/arm_owner, special = FALSE, movement_flags)
	. = ..()
	RegisterSignal(arm_owner, COMSIG_COMPONENT_CLEAN_ACT, PROC_REF(on_bearer_washed))

/obj/item/organ/cyberimp/arm/toolkit/cyberware/mantis/on_mob_remove(mob/living/carbon/arm_owner, special = FALSE, movement_flags)
	. = ..()
	UnregisterSignal(arm_owner, COMSIG_COMPONENT_CLEAN_ACT)
	stance_off()
	stop_glint()

/obj/item/organ/cyberimp/arm/toolkit/cyberware/mantis/Extend(obj/item/augment)
	. = ..()
	var/obj/item/melee/energy/blade/hardlight/cyberware_mantis/blade = active_item
	if(!istype(blade) || (blade in src) || !owner?.is_holding(blade))
		return
	blade.housing_ref = WEAKREF(src)
	stance_on()
	blade.set_mantis_pose(MANTIS_POSE_GUARD)
	schedule_glint()

/obj/item/organ/cyberimp/arm/toolkit/cyberware/mantis/Retract()
	var/mob/living/carbon/stowing_owner = owner
	var/obj/item/melee/energy/blade/hardlight/cyberware_mantis/stowing = active_item
	var/flick = istype(stowing) && stowing_owner?.is_holding(stowing) && stowing.is_bloody()
	. = ..()
	if(!.)
		return
	stance_off()
	stop_glint()
	if(!istype(stowing))
		return
	stowing.mantis_stowed()
	if(flick && !QDELETED(stowing_owner))
		flick_blood(stowing_owner, stowing)

// A blade forced out of the hand some other way (a cut-off hand, a forced drop) ends the stance too.
/obj/item/organ/cyberimp/arm/toolkit/cyberware/mantis/on_deployed_item_dropped(obj/item/source, mob/user)
	SIGNAL_HANDLER
	stance_off()
	stop_glint()
	return ..()

// ---- The stance ----------------------------------------------------------

/// Raises this arm's fist to the guard.
/obj/item/organ/cyberimp/arm/toolkit/cyberware/mantis/proc/stance_on()
	stance_off()
	var/obj/item/bodypart/arm = owner?.get_bodypart(zone)
	if(isnull(arm))
		return
	stance_overlay = new
	stance_limb = WEAKREF(arm)
	arm.add_bodypart_overlay(stance_overlay)

/// Lowers it again.
/obj/item/organ/cyberimp/arm/toolkit/cyberware/mantis/proc/stance_off()
	if(isnull(stance_overlay))
		return
	var/obj/item/bodypart/arm = stance_limb?.resolve()
	if(arm && (stance_overlay in arm.bodypart_overlays))
		arm.remove_bodypart_overlay(stance_overlay)
	QDEL_NULL(stance_overlay)
	stance_limb = null

/// How high the fist rides, for the blade's pose.
/obj/item/organ/cyberimp/arm/toolkit/cyberware/mantis/proc/set_stance_raise(raise)
	if(isnull(stance_overlay) || stance_overlay.raise == raise)
		return
	stance_overlay.raise = raise
	owner?.update_body_parts()

/**
 * The fist on an arm whose Mantis blade is out, raised to the guard. Draws nothing of its own: it moves
 * the arm's hand up a few pixels, and is part of the arm's render key so it redraws when it changes.
 */
/datum/bodypart_overlay/mantis_stance
	layers = NONE
	blocks_emissive = EMISSIVE_BLOCK_NONE
	/// Pixels the hand rides up.
	var/raise = 2

/datum/bodypart_overlay/mantis_stance/generate_icon_cache()
	return list("mantis_stance_[raise]")

/datum/bodypart_overlay/mantis_stance/modify_bodypart_appearance(datum/appearance)
	// Images and mutable appearances both: the hand and its emissive blocker move together.
	var/image/part = appearance
	if(isnull(part) || !findtext("[part.icon_state]", "_hand"))
		return
	part.pixel_y += raise

// ---- The glint -----------------------------------------------------------

/// The next glint along the edge, 8 to 12 seconds out. One-shot timers only.
/obj/item/organ/cyberimp/arm/toolkit/cyberware/mantis/proc/schedule_glint()
	stop_glint()
	glint_timer = addtimer(CALLBACK(src, PROC_REF(stance_glint)), rand(8 SECONDS, 12 SECONDS), TIMER_STOPPABLE|TIMER_DELETE_ME)

/obj/item/organ/cyberimp/arm/toolkit/cyberware/mantis/proc/stop_glint()
	if(glint_timer)
		deltimer(glint_timer)
		glint_timer = null

/obj/item/organ/cyberimp/arm/toolkit/cyberware/mantis/proc/stance_glint()
	glint_timer = null
	var/obj/item/melee/energy/blade/hardlight/cyberware_mantis/blade = active_item
	if(!istype(blade) || !owner?.is_holding(blade))
		return
	if(blade.mantis_pose == MANTIS_POSE_GUARD)
		blade.play_glint()
	schedule_glint()

// ---- Blood -----------------------------------------------------------------

/// How long flicked blood is in the air: the flick's three frames.
#define MANTIS_FLICK_FLIGHT (0.3 SECONDS)

/**
 * What a flicked blade leaves on the tile ahead: a thin line of spatter from where the blade pointed, bending a
 * little and breaking into drops toward its far end ("flick_spatter_[hand]", drawn for the tile ahead in each
 * facing). One per hand, so two blades lay a line each. Its own kind of blood, not one of the sprays: a tile's
 * spray is neither turned by a flick nor kept off the tile by one.
 */
/obj/effect/decal/cleanable/blood/mantis_flick
	name = "blood spatter"
	icon = MANTIS_GORE_ICON
	icon_state = "flick_spatter_right"
	random_icon_states = null
	mergeable_decal = FALSE
	// Thin enough that walking through it does not leave footprints.
	bloodiness = 15
	drying_time = 3 MINUTES
	beauty = -20
	base_name = null
	base_suffix = "spatter"
	/// The hand that flicked it: "left" or "right".
	var/hand = "right"

// Too thin to dive into.
/obj/effect/decal/cleanable/blood/mantis_flick/can_bloodcrawl_in()
	return FALSE

/// The [hand] blade's flicked blood lands on [ahead], thrown the way [flick_dir]. Wet spatter that hand already
/// left there is only freshened. Returns the spatter.
/proc/mantis_flick_land(turf/ahead, flick_dir, hand, list/blood_dna)
	if(!isturf(ahead) || !length(blood_dna))
		return null
	for(var/obj/effect/decal/cleanable/blood/mantis_flick/wet in ahead)
		if(wet.hand != hand || wet.dir != flick_dir || wet.dried || QDELETED(wet))
			continue
		wet.add_blood_DNA(blood_dna)
		return wet
	var/obj/effect/decal/cleanable/blood/mantis_flick/spatter = new(ahead, null, blood_dna)
	if(QDELETED(spatter))
		return null
	spatter.hand = hand
	spatter.icon_state = "flick_spatter_[hand]"
	spatter.setDir(flick_dir)
	var/full_alpha = spatter.alpha
	spatter.alpha = 0
	animate(spatter, alpha = full_alpha, time = 0.1 SECONDS)
	return spatter

/// The blade snaps back in bloody: the blood flies off ahead and lands as a line of spatter, and some stays on
/// the housing.
/obj/item/organ/cyberimp/arm/toolkit/cyberware/mantis/proc/flick_blood(mob/living/carbon/bearer, obj/item/melee/energy/blade/hardlight/cyberware_mantis/blade)
	var/blood_color = blade.get_blood_dna_color()
	var/list/blood_dna = blade.blood_dna_copy()
	var/obj/effect/abstract/cyberware_anim/fling = cyberware_anim_play(bearer, MANTIS_GORE_LARGE_ICON, "mantis_flick_[zone == BODY_ZONE_L_ARM ? "left" : "right"]", MANTIS_ANIM_BLADE_LAYER, 0.3 SECONDS)
	if(fling)
		fling.pixel_x = -16
		fling.pixel_y = -16
		fling.color = blood_color
	var/turf/ahead = get_step(bearer, bearer.dir)
	if(isturf(bearer.loc) && ahead && length(blood_dna) && !hv_blood_spray_blocked(ahead) && !isgroundlessturf(ahead) && ahead.has_gravity())
		// It lands once the flick has crossed to it, not as the blade starts back in.
		addtimer(CALLBACK(GLOBAL_PROC, GLOBAL_PROC_REF(mantis_flick_land), ahead, bearer.dir, zone == BODY_ZONE_L_ARM ? "left" : "right", blood_dna), MANTIS_FLICK_FLIGHT)
	blade.wash(CLEAN_TYPE_BLOOD)
	stained = TRUE
	stain_color = blood_color
	bearer.update_body_parts()

/obj/item/organ/cyberimp/arm/toolkit/cyberware/mantis/proc/on_bearer_washed(datum/source, clean_types)
	SIGNAL_HANDLER
	if(!(clean_types & CLEAN_TYPE_BLOOD))
		return
	var/obj/item/melee/energy/blade/hardlight/cyberware_mantis/blade = active_item
	if(istype(blade) && blade.is_bloody())
		blade.wash(CLEAN_TYPE_BLOOD)
		blade.stop_dripping()
		blade.refresh_held()
	if(!stained)
		return
	stained = FALSE
	stain_color = null
	owner?.update_body_parts()

/obj/item/organ/cyberimp/arm/toolkit/cyberware/mantis/cyberware_worn_key()
	return "[..()][stained ? "-blood[stain_color]" : ""]"

// The stain is drawn over the housing's own pixels, only in its plain look (an EMP's dark, a brownout or the
// fold hide it with the rest of the housing).
/obj/item/organ/cyberimp/arm/toolkit/cyberware/mantis/cyberware_dress_worn(list/imageset, image_layer, obj/item/bodypart/limb)
	. = ..()
	if(!stained || cyberware_worn_look())
		return
	var/stain_state = "[aug_overlay]_[zone == BODY_ZONE_L_ARM ? "left" : "right"]_stain"
	if(!icon_exists(MANTIS_GORE_ICON, stain_state))
		return
	var/image/stain = image(icon = MANTIS_GORE_ICON, icon_state = stain_state, layer = image_layer)
	stain.appearance_flags |= RESET_COLOR
	stain.color = stain_color
	. += stain

#undef MANTIS_FLICK_FLIGHT
