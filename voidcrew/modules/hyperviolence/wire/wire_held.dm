/**
 * # The Widowline in the hand
 *
 * - Deploying and stowing: the wire swings out of the spool and reels back in (WIRE_HELD_ANIM_ICON), played
 *   on the wielder while the held wire itself is not drawn, like the Mantis unfold.
 * - Blood: a cut that draws blood leaves the wire wet (dripping) for WIRE_WET_TIME, then stained until
 *   WIRE_STAINED_TIME, drawn from greyscale states tinted to the blood. Stowing a wet wire flicks a few drops
 *   onto the floor in front. Only the picture clears: the blood's DNA stays on the wire until it is washed.
 *   tg's generic item stain is not drawn on the wire, which draws its own.
 * - The Arc's charged wire burns its blood off: it never shows any.
 */

/obj/item/melee/cyberware_monowire
	/// Blood on the wire: wet and dripping until this world.time, stained until this one.
	var/wet_until = 0
	var/stained_until = 0
	/// The blood look drawn now: 0 clean, 1 stained, 2 wet.
	var/shown_blood_stage = 0
	/// Drips this wet spell still has in it.
	var/drips_left = 0
	/// Timer of the next drip, and of the next change of look.
	var/drip_timer
	var/dry_timer
	/// Until this world.time the wire isn't drawn in the hand: its swing is.
	var/inhand_hidden_until = 0

/obj/item/melee/cyberware_monowire/Initialize(mapload)
	. = ..()
	RegisterSignal(src, COMSIG_COMPONENT_CLEAN_ACT, PROC_REF(on_wash))

/obj/item/melee/cyberware_monowire/Destroy()
	if(garrote_running)
		QDEL_NULL(garrote_running)
	if(drip_timer)
		deltimer(drip_timer)
		drip_timer = null
	if(dry_timer)
		deltimer(dry_timer)
		dry_timer = null
	return ..()

// ---- Blood on the wire ----

/// Whether this wire never shows blood.
/obj/item/melee/cyberware_monowire/proc/wire_stays_clean()
	return FALSE

/obj/item/melee/cyberware_monowire/live/wire_stays_clean()
	return TRUE

/// 2 while the wire is wet, 1 while it is stained, else 0.
/obj/item/melee/cyberware_monowire/proc/blood_stage()
	if(world.time < wet_until)
		return 2
	if(world.time < stained_until)
		return 1
	return 0

/// A landed cut on `victim` at `def_zone`: if it drew blood, the wire is wet with it.
/obj/item/melee/cyberware_monowire/proc/wire_bloody(mob/living/victim, def_zone)
	if(wire_stays_clean() || QDELETED(victim))
		return
	if(isbodypart(def_zone))
		var/obj/item/bodypart/limb = def_zone
		if(!limb.can_bleed())
			return
	if(victim.can_bleed(BLOOD_COVER_ITEMS) != BLEED_SPLATTER)
		return
	add_mob_blood(victim)
	wet_until = world.time + WIRE_WET_TIME
	stained_until = world.time + WIRE_STAINED_TIME
	drips_left = WIRE_MAX_DRIPS
	if(!drip_timer)
		drip_timer = addtimer(CALLBACK(src, PROC_REF(drip)), rand(1 SECONDS, 2 SECONDS), TIMER_STOPPABLE)
	update_blood_look()

/// Redraws the blood if its look changed, and waits for the next change.
/obj/item/melee/cyberware_monowire/proc/update_blood_look()
	if(dry_timer)
		deltimer(dry_timer)
		dry_timer = null
	var/stage = blood_stage()
	if(stage != shown_blood_stage)
		shown_blood_stage = stage
		update_appearance(UPDATE_OVERLAYS)
		var/mob/holder = loc
		if(ismob(holder))
			holder.update_held_items()
	// Wet dries to a stain, a stain to clean: wait for whichever comes next.
	if(stage)
		dry_timer = addtimer(CALLBACK(src, PROC_REF(update_blood_look)), (stage == 2 ? wet_until : stained_until) - world.time + 1, TIMER_STOPPABLE)

/// A drop off the tip while the wire is out and wet.
/obj/item/melee/cyberware_monowire/proc/drip()
	drip_timer = null
	if(blood_stage() < 2 || drips_left <= 0)
		return
	var/mob/living/holder = loc
	if(!isliving(holder))
		return
	var/turf/below = holder.loc
	if(isturf(below) && !isgroundlessturf(below) && below.has_gravity() && length(GET_ATOM_BLOOD_DNA(src)))
		new /obj/effect/decal/cleanable/blood/drip(below, null, GET_ATOM_BLOOD_DNA(src))
		drips_left--
	drip_timer = addtimer(CALLBACK(src, PROC_REF(drip)), rand(1 SECONDS, 2 SECONDS), TIMER_STOPPABLE)

/// A wash takes the blood off, look and all.
/obj/item/melee/cyberware_monowire/proc/on_wash(datum/source, clean_types)
	SIGNAL_HANDLER
	if(!(clean_types & CLEAN_TYPE_BLOOD) || !(wet_until || stained_until))
		return NONE
	clear_blood_look()
	return COMPONENT_CLEANED

/// The blood stops showing. Its DNA stays.
/obj/item/melee/cyberware_monowire/proc/clear_blood_look()
	wet_until = 0
	stained_until = 0
	drips_left = 0
	if(drip_timer)
		deltimer(drip_timer)
		drip_timer = null
	update_blood_look()

/obj/item/melee/cyberware_monowire/update_overlays()
	. = ..()
	var/stage = blood_stage()
	if(!stage)
		return
	var/mutable_appearance/blood = mutable_appearance(icon, "monowire_blood[stage]", appearance_flags = RESET_COLOR)
	blood.color = get_blood_dna_color() || BLOOD_COLOR_RED
	. += blood

/obj/item/melee/cyberware_monowire/worn_overlays(mutable_appearance/standing, isinhands = FALSE, icon_file)
	. = ..()
	if(!isinhands || world.time < inhand_hidden_until)
		return
	var/stage = blood_stage()
	if(!stage || !icon_exists(icon_file, "monowire_blood[stage]"))
		return
	var/mutable_appearance/blood = mutable_appearance(icon_file, "monowire_blood[stage]", appearance_flags = RESET_COLOR)
	blood.color = get_blood_dna_color() || BLOOD_COLOR_RED
	. += blood

// tg's stain over the whole item would sit on the spool long after the wire has dried; the wire draws its own.
/datum/forensics/check_blood()
	if(istype(parent, /obj/item/melee/cyberware_monowire))
		return
	return ..()

// ---- Out of the spool and back ----

/obj/item/melee/cyberware_monowire/proc/hide_inhand_for(duration)
	inhand_hidden_until = world.time + duration
	var/mob/holder = loc
	if(ismob(holder))
		holder.update_held_items()
	addtimer(CALLBACK(src, PROC_REF(show_inhand)), duration, TIMER_UNIQUE | TIMER_OVERRIDE)

/obj/item/melee/cyberware_monowire/proc/show_inhand()
	if(!inhand_hidden_until)
		return
	inhand_hidden_until = 0
	var/mob/holder = loc
	if(ismob(holder))
		holder.update_held_items()

// The wire is in the hand from the first tick; only its drawing waits for the swing.
/obj/item/melee/cyberware_monowire/build_worn_icon(default_layer = 0, default_icon_file = null, isinhands = FALSE, female_uniform = NO_FEMALE_UNIFORM, override_state = null, override_file = null)
	. = ..()
	if(isinhands && world.time < inhand_hidden_until)
		var/mutable_appearance/standing = .
		standing.alpha = 0

/// "left" or "right": the hand `user` holds this wire in, or null.
/obj/item/melee/cyberware_monowire/proc/held_side(mob/living/user)
	var/index = user?.get_held_index_of_item(src)
	if(!index)
		return null
	return IS_LEFT_INDEX(index) ? "left" : "right"

/// The wire swings out of the spool into the hand.
/obj/item/melee/cyberware_monowire/proc/play_deploy(mob/living/user)
	var/side = held_side(user)
	if(!side)
		return
	cyberware_anim_play(user, WIRE_HELD_ANIM_ICON, "[icon_state]_deploy_[side]", WIRE_SWING_LAYER, WIRE_SWING_TIME)
	hide_inhand_for(WIRE_SWING_TIME)

/// The wire reels back into the spool from the `side` hand. A wet wire flicks its blood off first.
/obj/item/melee/cyberware_monowire/proc/play_retract(mob/living/user, side, stage)
	if(QDELETED(user) || !side)
		return
	cyberware_anim_play(user, WIRE_HELD_ANIM_ICON, "[icon_state]_retract_[side]", WIRE_SWING_LAYER, WIRE_SWING_TIME)
	if(stage)
		var/obj/effect/abstract/cyberware_anim/blood = cyberware_anim_play(user, WIRE_HELD_ANIM_ICON, "monowire_retract_blood[stage]_[side]", WIRE_SWING_LAYER + 0.05, WIRE_SWING_TIME)
		if(blood)
			blood.appearance_flags |= RESET_COLOR
			blood.color = get_blood_dna_color() || BLOOD_COLOR_RED
	if(stage >= 2)
		flick_blood(user)
	clear_blood_look()

/// A few drops thrown onto the floor in front of `user`, and one at their feet.
/obj/item/melee/cyberware_monowire/proc/flick_blood(mob/living/user)
	var/list/blood_dna = GET_ATOM_BLOOD_DNA(src)
	var/turf/feet = get_turf(user)
	if(!length(blood_dna) || !feet || !feet.has_gravity())
		return
	if(!isgroundlessturf(feet))
		new /obj/effect/decal/cleanable/blood/drip(feet, null, blood_dna)
	var/turf/ahead = get_step(feet, user.dir)
	if(ahead && !hv_blood_spray_blocked(ahead) && !isgroundlessturf(ahead))
		new /obj/effect/decal/cleanable/blood/drip(ahead, null, blood_dna)
		new /obj/effect/decal/cleanable/blood/drip(ahead, null, blood_dna)

/obj/item/organ/cyberimp/arm/toolkit/cyberware/monowire/Extend(obj/item/augment)
	. = ..()
	var/obj/item/melee/cyberware_monowire/wire = active_item
	if(istype(wire) && owner?.is_holding(wire))
		wire.play_deploy(owner)

/obj/item/organ/cyberimp/arm/toolkit/cyberware/monowire/Retract()
	var/mob/living/carbon/stowing_owner = owner
	var/obj/item/melee/cyberware_monowire/wire = active_item
	var/side
	var/stage = 0
	if(istype(wire) && stowing_owner?.is_holding(wire))
		side = wire.held_side(stowing_owner)
		stage = wire.blood_stage()
	. = ..()
	if(. && side && !QDELETED(wire))
		wire.play_retract(stowing_owner, side, stage)
