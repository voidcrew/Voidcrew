/**
 * # The Widowline in the hand
 *
 * - Deploying and stowing: the wire swings out of the spool and reels back in (WIRE_HELD_ANIM_ICON), played
 *   on the wielder while the held wire itself is not drawn, like the Mantis unfold.
 * - Blood: a cut that draws blood leaves the wire wet (dripping) for WIRE_WET_TIME, then stained until
 *   WIRE_STAINED_TIME, drawn from greyscale states tinted to the blood. Stowing a wet wire cracks a fan of
 *   drops off it that land spread over the floor ahead. Only the picture clears: the blood's DNA stays on the wire until it is washed.
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

/**
 * Where the `side` hand ("left" or "right") of `holder` is drawn, in pixels from the middle of its tile, and
 * whether it is behind the body as the body faces: the far hand in profile, and both hands of a body facing away.
 * list(x, y, behind)
 */
/proc/wire_hand_point(mob/living/holder, side)
	var/right = side != "left"
	switch(holder.dir)
		if(EAST)
			return right ? list(5, -5, FALSE) : list(2, -6, TRUE)
		if(WEST)
			return right ? list(-2, -6, TRUE) : list(-5, -5, FALSE)
		if(NORTH)
			return right ? list(7, -5, TRUE) : list(-7, -5, TRUE)
	return right ? list(-7, -5, FALSE) : list(7, -5, FALSE)

/// The world layer for a line of wire leaving a hand: over the bodies, or under them for a hand behind its body.
/proc/wire_line_layer(behind)
	return behind ? BELOW_MOB_LAYER : ABOVE_ALL_MOB_LAYER

/**
 * A segment of a line of wire drawn with Beam(). tg's segments all sit at ABOVE_ALL_MOB_LAYER whatever layer the beam
 * is given (their picture inherits the segment's layer), so a line that has to pass behind a body takes its beam's.
 */
/obj/effect/ebeam/wire_line

/obj/effect/ebeam/wire_line/Initialize(mapload, beam_owner)
	. = ..()
	// Turned to the bearing without smoothing, so the line stays one pixel wide.
	appearance_flags |= PIXEL_SCALE
	if(owner?.beam_layer)
		layer = owner.beam_layer

/// The overlay layer on its wielder for the wire swinging in a hand: over the hands, or under the whole body for
/// the far hand in profile, so the torso hides what passes behind it.
/proc/wire_swing_layer(mob/living/holder, side)
	if(holder.dir & (EAST | WEST))
		var/list/hand = wire_hand_point(holder, side)
		if(hand[3])
			return -(TOTAL_LAYERS + 0.5)
	return WIRE_SWING_LAYER

/**
 * Where the `zone` part of `body` is drawn, in pixels from the middle of its tile: as it stands and faces, turned
 * with it when it lies, then moved by its offsets. list(x, y)
 */
/proc/wire_zone_point(mob/living/body, zone)
	var/x = 0
	var/y = 2
	// Screen side of the body's right: left facing south, right facing north, the middle in profile.
	var/right_x = 0
	switch(body.dir)
		if(SOUTH)
			right_x = -1
		if(NORTH)
			right_x = 1
	switch(zone)
		if(BODY_ZONE_HEAD)
			y = 10
		if(BODY_ZONE_R_ARM)
			x = right_x * 6
			y = 1
		if(BODY_ZONE_L_ARM)
			x = -right_x * 6
			y = 1
		if(BODY_ZONE_R_LEG)
			x = right_x * 3
			y = -8
		if(BODY_ZONE_L_LEG)
			x = -right_x * 3
			y = -8
	var/matrix/shape = body.transform
	return list(round(shape.a * x + shape.b * y + shape.c) + body.pixel_x, round(shape.d * x + shape.e * y + shape.f) + body.pixel_y)

/**
 * A landed swing: the wire lashes from the hand holding it to the part of `target` it cut (`zone`, else the part the
 * wielder aimed at), one thin line in its own colour that fades out over half a second. A single stretched line, not
 * tg's Beam(): a beam's full-tile segments are drawn over a body facing away whatever layer they are given, and this
 * one must pass behind it from a hidden hand. A body nearer the viewer than the wielder (on a lower row) hides the
 * end of the line, which meets it on the far side.
 */
/obj/item/melee/cyberware_monowire/proc/wire_lash_at(mob/living/user, atom/target, zone)
	var/turf/from = get_turf(user)
	var/turf/hit = get_turf(target)
	if(!from || !hit || from == hit || from.z != hit.z)
		return
	var/list/hand = wire_hand_point(user, held_side(user) || "right")
	var/hand_x = user.pixel_x + hand[1]
	var/hand_y = user.pixel_y + hand[2]
	var/end_x = target.pixel_x
	var/end_y = target.pixel_y
	if(isliving(target))
		var/list/part = wire_zone_point(target, zone || check_zone(user.zone_selected))
		end_x = part[1]
		end_y = part[2]
	var/span_x = (hit.x - from.x) * ICON_SIZE_X + end_x - hand_x
	var/span_y = (hit.y - from.y) * ICON_SIZE_Y + end_y - hand_y
	var/obj/effect/abstract/wire_reach/lash = new(from)
	lash.icon_state = lash_state()
	lash.layer = hit.y < from.y ? BELOW_MOB_LAYER : wire_line_layer(hand[3])
	lash.add_overlay(emissive_appearance(lash.icon, lash.icon_state, lash))
	lash.pixel_x = hand_x
	lash.pixel_y = hand_y
	lash.transform = wire_reach_shape(span_x, span_y)
	animate(lash, alpha = 0, time = 0.5 SECONDS, easing = QUAD_EASING | EASE_IN)
	QDEL_IN(lash, 0.5 SECONDS)

/obj/item/melee/cyberware_monowire/proc/lash_state()
	return "wire_reach"

/obj/item/melee/cyberware_monowire/live/lash_state()
	return "wire_reach_live"

/// The light at the spool while the wire runs out or snaps back: the wire's own colour.
/obj/item/melee/cyberware_monowire/proc/spool_light_color()
	return "#f86cfa"

/obj/item/melee/cyberware_monowire/live/spool_light_color()
	return "#7fe0ff"

/// The wire swings out of the spool into the hand.
/obj/item/melee/cyberware_monowire/proc/play_deploy(mob/living/user)
	var/side = held_side(user)
	if(!side)
		return
	cyberware_anim_play(user, WIRE_HELD_ANIM_ICON, "[icon_state]_deploy_[side]", wire_swing_layer(user, side), WIRE_SWING_TIME)
	hide_inhand_for(WIRE_SWING_TIME)
	user.mob_light(1.5, 0.6, spool_light_color(), 0.3 SECONDS)

/// The wire reels back into the spool from the `side` hand. A wet wire cracks its blood off first.
/obj/item/melee/cyberware_monowire/proc/play_retract(mob/living/user, side, stage)
	if(QDELETED(user) || !side)
		return
	var/swing_layer = wire_swing_layer(user, side)
	cyberware_anim_play(user, WIRE_HELD_ANIM_ICON, "[icon_state]_retract_[side]", swing_layer, WIRE_SWING_TIME)
	user.mob_light(1.5, 0.6, spool_light_color(), 0.3 SECONDS)
	if(stage)
		var/obj/effect/abstract/cyberware_anim/blood = cyberware_anim_play(user, WIRE_HELD_ANIM_ICON, "monowire_retract_blood[stage]_[side]", swing_layer + 0.05, WIRE_SWING_TIME)
		if(blood)
			blood.appearance_flags |= RESET_COLOR
			blood.color = get_blood_dna_color() || BLOOD_COLOR_RED
	if(stage >= 2)
		flick_blood(user, side)
	clear_blood_look()

/**
 * The fan a wet wire throws as it cracks back into the spool: WIRE_FLICK_DROPS drops leave its tip, fly an arc
 * and land spread over the floor ahead and to the sides, each as a drip. Drawn on temporary visuals; only the
 * drips stay.
 */
/obj/item/melee/cyberware_monowire/proc/flick_blood(mob/living/user, side)
	var/list/blood_dna = GET_ATOM_BLOOD_DNA(src)
	var/turf/feet = get_turf(user)
	if(!length(blood_dna) || !feet || !feet.has_gravity())
		return
	var/blood_color = get_blood_dna_color() || BLOOD_COLOR_RED
	for(var/list/drop as anything in wire_fan_plan(user.dir, side))
		new /obj/effect/temp_visual/wire_blood_drop(feet, drop, blood_color, blood_dna)

/**
 * Where each drop of the fan starts and lands, in pixels from the middle of the wielder's tile:
 * list(start x, start y, land x, land y, arc height, flight time). It leaves the wire's tip, which hangs by the
 * `side` hand ("left" or "right"), and lands up to a tile and a bit ahead of `facing`, spread to both sides.
 */
/proc/wire_fan_plan(facing, side)
	. = list()
	var/forward_x = (facing & EAST) ? 1 : ((facing & WEST) ? -1 : 0)
	var/forward_y = (facing & NORTH) ? 1 : ((facing & SOUTH) ? -1 : 0)
	if(!forward_x && !forward_y)
		forward_y = -1
	// The tip hangs by the hand: screen left or right of the body facing north or south, in front of it in profile.
	var/start_x = forward_x * 3
	if(!forward_x)
		var/screen_left = (side == "right") == (facing != NORTH)
		start_x = screen_left ? -6 : 6
	var/start_y = -13
	for(var/i in 1 to WIRE_FLICK_DROPS)
		var/spread = (i - (WIRE_FLICK_DROPS + 1) / 2) * 7
		var/reach = 14 + ((i * 5) % WIRE_FLICK_DROPS) * 5
		var/land_x = start_x + forward_x * reach + (forward_x ? (i % 3 - 1) * 3 : spread)
		var/land_y = start_y + forward_y * reach + (forward_x ? (i % 2 ? -2 : 3) : (i % 3 - 1) * 2)
		var/height = 6 + (i % 3) * 3
		var/flight = round(2 + reach / 12, 0.5)
		. += list(list(start_x, start_y, land_x, land_y, height, flight))

/// One drop of the fan in flight. It lands as a drip, unless where it lands has no floor to hold it.
/obj/effect/temp_visual/wire_blood_drop
	name = "blood"
	icon = WIRE_GORE_ICON
	icon_state = "wire_drop"
	layer = ABOVE_MOB_LAYER
	randomdir = FALSE
	duration = 0.6 SECONDS

/obj/effect/temp_visual/wire_blood_drop/Initialize(mapload, list/drop, blood_color, list/blood_dna)
	var/start_x = drop[1]
	var/start_y = drop[2]
	var/land_x = drop[3]
	var/land_y = drop[4]
	var/height = drop[5]
	var/flight = drop[6]
	// Held back a beat (a 7th entry, else the flick's): the flick's drops leave on the crack, the retract's second frame.
	var/crack = length(drop) >= 7 ? drop[7] : 0.5
	duration = crack + flight
	. = ..()
	color = blood_color
	pixel_x = start_x
	pixel_y = start_y
	alpha = 0
	if(crack)
		animate(src, alpha = 0, time = crack)
		animate(alpha = 255, pixel_x = (start_x + land_x) / 2, pixel_y = max(start_y, land_y) + height, time = flight / 2, easing = SINE_EASING | EASE_OUT)
	else
		alpha = 255
		animate(src, pixel_x = (start_x + land_x) / 2, pixel_y = max(start_y, land_y) + height, time = flight / 2, easing = SINE_EASING | EASE_OUT)
	animate(pixel_x = land_x, pixel_y = land_y, time = flight / 2, easing = SINE_EASING | EASE_IN)
	addtimer(CALLBACK(GLOBAL_PROC, GLOBAL_PROC_REF(wire_drop_land), get_turf(src), land_x, land_y, blood_dna), duration - 0.1)

/// A drop of the fan comes down at (`land_x`, `land_y`) pixels from the middle of `origin`.
/proc/wire_drop_land(turf/origin, land_x, land_y, list/blood_dna)
	if(!origin)
		return
	var/tile_x = floor((land_x + 16) / 32)
	var/tile_y = floor((land_y + 16) / 32)
	var/turf/landing = locate(origin.x + tile_x, origin.y + tile_y, origin.z)
	if(!landing || isgroundlessturf(landing) || !landing.has_gravity() || (landing != origin && hv_blood_spray_blocked(landing)))
		return
	var/obj/effect/decal/cleanable/blood/drip/wire_flick/drop = new(landing, null, blood_dna)
	if(QDELETED(drop))
		return
	drop.pixel_x = land_x - tile_x * 32
	drop.pixel_y = land_y - tile_y * 32

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

/// A drop of the fan. Each stays where it fell instead of pooling with the others on its tile; a fan is a handful.
/obj/effect/decal/cleanable/blood/drip/wire_flick
	mergeable_decal = FALSE
