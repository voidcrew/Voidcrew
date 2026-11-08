/**
 * # Gorilla Arms looks
 *
 * Pictures on top of moves that already happened; nothing here changes a number.
 * - The piston pump: the punching arm's pistons compress, fire and return.
 * - Heat: the pistons whiten and glow as an arm winds up or strains.
 * - The deploy flex: as the pair syncs, after an EMP reboot, or on the Arm chrome key when the Gorilla
 *   has nothing to deploy. A squat, both pumps in turn with steam, the knuckles flash, and it settles.
 * - Snapped bones: a compound fracture on an arm, a leg or the chest shows bone through the skin and
 *   blood, whatever broke it. Drawn like #509's stumps (bone plus greyscale blood tinted to the body's
 *   blood), on its own overlay list beside them.
 *
 * Plates under a suit that covers the arms don't show, so their pump and heat don't either.
 */

/// Whether this arm's worn plate is on show (no suit over the arms).
/obj/item/organ/cyberimp/cyberware/gorilla_arms/proc/plate_shows()
	var/mob/living/carbon/human/bearer = owner
	if(!ishuman(bearer))
		return FALSE
	return !(bearer.wear_suit?.body_parts_covered & ARMS)

/// The pistons on this arm pump once: compress, fire, return. Returns the holder or null.
/obj/item/organ/cyberimp/cyberware/gorilla_arms/proc/play_pump()
	if(!owner || !plate_shows())
		return null
	var/state = "pump_[aug_overlay]"
	if(!icon_exists(GORILLA_GORE_ICON, state))
		return null
	var/obj/effect/abstract/cyberware_anim/pump = cyberware_anim_play(owner, GORILLA_GORE_ICON, state, GORILLA_ANIM_PLATE_LAYER, 0.3 SECONDS)
	if(pump && icon_exists(GORILLA_GORE_ICON, "[state]_e"))
		pump.add_overlay(emissive_appearance(GORILLA_GORE_ICON, "[state]_e", owner))
	return pump

/**
 * The pistons heat over [rise_time] and stay hot until [lifetime], then the glow goes. Returns the
 * holder, which the caller may delete sooner.
 */
/obj/item/organ/cyberimp/cyberware/gorilla_arms/proc/play_heat(rise_time, lifetime)
	if(!owner || !plate_shows())
		return null
	var/state = "hot_[aug_overlay]"
	if(!icon_exists(GORILLA_GORE_ICON, state))
		return null
	var/obj/effect/abstract/cyberware_anim/heat = cyberware_anim_play(owner, GORILLA_GORE_ICON, state, GORILLA_ANIM_PLATE_LAYER, lifetime)
	if(!heat)
		return null
	heat.add_overlay(emissive_appearance(GORILLA_GORE_ICON, state, owner))
	heat.alpha = 0
	animate(heat, alpha = 255, time = rise_time, easing = SINE_EASING | EASE_IN)
	return heat

// =========================================================================
// THE DEPLOY FLEX
// =========================================================================

/// The flex, at most once per GORILLA_FLEX_COOLDOWN. Every step is relative and ends where it began.
/proc/gorilla_flex(mob/living/carbon/human/bearer)
	if(!ishuman(bearer) || bearer.stat != CONSCIOUS || bearer.body_position == LYING_DOWN || !isturf(bearer.loc))
		return FALSE
	var/list/arms = gorilla_heavy_arms(bearer)
	if(!length(arms) || !TIMER_COOLDOWN_FINISHED(bearer, COOLDOWN_GORILLA_FLEX))
		return FALSE
	gorilla_cooldown(bearer, COOLDOWN_GORILLA_FLEX, GORILLA_FLEX_COOLDOWN)
	// The squat, about the feet, and back up
	var/matrix/squat = matrix(1.05, 0, 0, 0, 0.93, -1)
	var/matrix/rise = matrix(squat)
	rise.Invert()
	animate(bearer, transform = squat, time = 0.15 SECONDS, easing = SINE_EASING | EASE_OUT, flags = ANIMATION_RELATIVE | ANIMATION_PARALLEL)
	animate(transform = matrix(), time = 0.5 SECONDS, flags = ANIMATION_RELATIVE)
	animate(transform = rise, time = 0.25 SECONDS, easing = SINE_EASING | EASE_IN | EASE_OUT, flags = ANIMATION_RELATIVE)
	var/delay = 0.15 SECONDS
	for(var/obj/item/organ/cyberimp/cyberware/gorilla_arms/arm as anything in arms)
		addtimer(CALLBACK(arm, TYPE_PROC_REF(/obj/item/organ/cyberimp/cyberware/gorilla_arms, flex_beat)), delay)
		delay += 0.15 SECONDS
	playsound(bearer, 'sound/machines/hiss.ogg', 30, TRUE, frequency = 0.8)
	return TRUE

/// One arm's part of the flex: the pump, a puff of steam, and the knuckles flashing.
/obj/item/organ/cyberimp/cyberware/gorilla_arms/proc/flex_beat()
	if(!owner)
		return
	play_pump()
	play_heat(0.1 SECONDS, 0.35 SECONDS)
	cyberware_anim_particles(owner, /particles/smoke/steam/gorilla_puff, GORILLA_ANIM_TOP_LAYER, 0.15 SECONDS, 0.9 SECONDS)
	var/obj/effect/abstract/cyberware_anim/spark = cyberware_anim_play(owner, GORILLA_GORE_ICON, "impact_brawler", GORILLA_ANIM_TOP_LAYER, 0.4 SECONDS)
	if(spark)
		spark.appearance_flags |= RESET_TRANSFORM
		var/side = (zone == BODY_ZONE_R_ARM) ? -1 : 1
		if(owner.dir == NORTH)
			side = -side
		spark.pixel_w = (owner.dir & (EAST|WEST)) ? 0 : side * 7
		spark.pixel_z = -5
		spark.transform = matrix().Scale(0.5)

// The pair comes back from an EMP: once it is back in sync, the arms flex.
/datum/component/cyberware/finish_emp_reboot()
	var/was_down = emp_down
	. = ..()
	var/obj/item/organ/cyberimp/cyberware/gorilla_arms/arm = parent
	if(!was_down || emp_down || !istype(arm) || !arm.heavy_moves || !arm.owner)
		return
	if(gorilla_synced(arm.owner))
		addtimer(CALLBACK(GLOBAL_PROC, GLOBAL_PROC_REF(gorilla_flex), arm.owner), 0.6 SECONDS)

// The Arm chrome key with nothing to deploy but a synced pair of Gorilla Arms: they flex.
/datum/component/chrome_wheel/use_arms()
	var/mob/living/carbon/bearer = parent
	if((!arm_action || arm_action.owner != bearer) && gorilla_synced(bearer))
		gorilla_flex(bearer)
		return TRUE
	return ..()

// =========================================================================
// SNAPPED BONES
// =========================================================================

/mob/living/carbon
	/// Snapped-bone images drawn on us now (hyperviolence_gorilla).
	var/list/gorilla_snap_overlays
	/// What gorilla_snap_overlays was built from.
	var/gorilla_snap_key

/mob/living/carbon/update_damage_overlays()
	. = ..()
	gorilla_update_snap_overlays()

/mob/living/carbon/regenerate_icons()
	gorilla_snap_key = null
	return ..()

/// The zones showing a snapped bone: an arm, a leg or the chest with a compound fracture (not the skull).
/mob/living/carbon/proc/gorilla_snapped_zones()
	var/static/list/snap_zones = list(BODY_ZONE_CHEST, BODY_ZONE_L_ARM, BODY_ZONE_R_ARM, BODY_ZONE_L_LEG, BODY_ZONE_R_LEG)
	. = list()
	if(!ishuman(src))
		return
	for(var/zone in snap_zones)
		var/obj/item/bodypart/part = get_bodypart(zone)
		if(isnull(part) || !part.hv_shows_gore())
			continue
		for(var/datum/wound/blunt/bone/critical/fracture in part.wounds)
			. += zone
			break

/// Rebuilds the snapped-bone overlays if what they show changed.
/mob/living/carbon/proc/gorilla_update_snap_overlays()
	var/list/zones = gorilla_snapped_zones()
	var/new_key
	var/blood_color
	if(length(zones))
		if(can_bleed())
			blood_color = get_bloodtype()?.get_damage_color(src) || BLOOD_COLOR_RED
		var/height = HUMAN_HEIGHT_MEDIUM
		if(ishuman(src))
			var/mob/living/carbon/human/as_human = src
			height = as_human.mob_height
		new_key = "[jointext(zones, ",")]|[islist(blood_color) ? jointext(blood_color, ",") : blood_color]|[height]"
	if(new_key == gorilla_snap_key && (new_key || !gorilla_snap_overlays))
		return
	gorilla_snap_key = new_key
	if(gorilla_snap_overlays)
		cut_overlay(gorilla_snap_overlays)
		gorilla_snap_overlays = null
	if(isnull(new_key))
		return
	var/list/images = list()
	for(var/zone in zones)
		if(blood_color)
			var/image/blood = image(GORILLA_GORE_ICON, "snap_[zone]_blood", -HV_STUMP_FRESH_LAYER)
			blood.appearance_flags = RESET_COLOR
			blood.color = blood_color
			images += blood
		images += image(GORILLA_GORE_ICON, "snap_[zone]_bone", -HV_STUMP_FRESH_LAYER)
	if(ishuman(src))
		var/mob/living/carbon/human/as_human = src
		if(as_human.mob_height != HUMAN_HEIGHT_MEDIUM)
			for(var/image/snap_image as anything in images)
				as_human.apply_height_filters(snap_image)
	gorilla_snap_overlays = images
	add_overlay(gorilla_snap_overlays)

// A compound fracture comes and goes: the snapped bone with it.
/datum/wound/blunt/bone/critical/apply_wound(obj/item/bodypart/L, silent = FALSE, datum/wound/old_wound = null, smited = FALSE, attack_direction = null, wound_source = "Unknown", replacing = FALSE)
	. = ..()
	if(. && iscarbon(victim))
		victim.gorilla_update_snap_overlays()

/datum/wound/blunt/bone/critical/remove_wound(ignore_limb, replaced)
	var/mob/living/carbon/was_on = victim
	. = ..()
	if(iscarbon(was_on) && !QDELETED(was_on))
		was_on.gorilla_update_snap_overlays()
