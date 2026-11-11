/**
 * # The Widowline in the hand
 *
 * - Deploying and stowing: the wire swings out of the spool and reels back in (WIRE_HELD_ANIM_ICON), played
 *   on the wielder while the held wire itself is not drawn, like the Mantis unfold.
 * - While the wire is out of the hand as a line (a lash, the garrote's thrown wire and strands) the hanging wire isn't
 *   drawn there, but its spool is (WIRE_SPOOL_ICON): the line comes out of the spool's lit pixel.
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
	/// Until this world.time the wire isn't drawn hanging in the hand: its swing is, or a line of it out to something.
	var/inhand_hidden_until = 0
	/// Until this world.time its spool isn't drawn in the hand either: the swing out of the spool draws its own.
	var/inhand_bare_until = 0

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
		// Off the tip, which hangs to the floor: not wherever tg's drip would land, which can be the wielder's hip.
		var/obj/effect/decal/cleanable/blood/drip/wire_flick/drop = new(below, null, GET_ATOM_BLOOD_DNA(src))
		if(!QDELETED(drop))
			drop.wire_place(holder.pixel_x + wire_tip_x(holder, held_side(holder) || "right") + rand(-2, 2), holder.pixel_y - 13 + rand(-1, 1))
		drips_left--
	drip_timer = addtimer(CALLBACK(src, PROC_REF(drip)), rand(1 SECONDS, 2 SECONDS), TIMER_STOPPABLE)

/// Where the tip of a wire held in the `side` hand ("left" or "right") of `holder` touches the floor, in pixels across
/// from the middle of its tile, as the held wire is drawn (cyberware_lefthand.dmi, cyberware_righthand.dmi).
/proc/wire_tip_x(mob/living/holder, side)
	var/right = side != "left"
	switch(holder.dir)
		if(EAST)
			return right ? 1 : 6
		if(WEST)
			return right ? -7 : -1
		if(NORTH)
			return right ? 9 : -10
	return right ? -10 : 9

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

/**
 * The wire isn't drawn hanging in the hand for `duration`. With `spool` its spool still is: the wire is out of the hand
 * as a line (a lash, the garrote's), which comes out of the spool. Without, nothing of it is: its swing out of the
 * spool is being played, spool and all.
 */
/obj/item/melee/cyberware_monowire/proc/hide_inhand_for(duration, spool = FALSE)
	// A shorter hide (a swing out of the spool) never cuts a longer one (a garrote's) short.
	inhand_hidden_until = max(inhand_hidden_until, world.time + duration)
	if(!spool)
		inhand_bare_until = max(inhand_bare_until, world.time + duration)
	// A hide that runs on past a swing's draws the spool from the end of the swing.
	if(inhand_bare_until > world.time && inhand_bare_until < inhand_hidden_until)
		addtimer(CALLBACK(src, PROC_REF(redraw_inhand)), inhand_bare_until - world.time, TIMER_UNIQUE | TIMER_OVERRIDE | TIMER_NO_HASH_WAIT)
	var/mob/holder = loc
	if(ismob(holder))
		holder.update_held_items()
	addtimer(CALLBACK(src, PROC_REF(show_inhand)), inhand_hidden_until - world.time, TIMER_UNIQUE | TIMER_OVERRIDE | TIMER_NO_HASH_WAIT)

/obj/item/melee/cyberware_monowire/proc/show_inhand()
	if(!inhand_hidden_until)
		return
	inhand_hidden_until = 0
	inhand_bare_until = 0
	redraw_inhand()

/obj/item/melee/cyberware_monowire/proc/redraw_inhand()
	var/mob/holder = loc
	if(ismob(holder))
		holder.update_held_items()

// The wire is in the hand from the first tick; only its drawing waits for the swing, or for the line of it that is out.
/obj/item/melee/cyberware_monowire/build_worn_icon(default_layer = 0, default_icon_file = null, isinhands = FALSE, female_uniform = NO_FEMALE_UNIFORM, override_state = null, override_file = null)
	if(!isinhands || world.time >= inhand_hidden_until)
		return ..()
	// Out of the hand as a line: the spool it comes out of stays.
	var/spool_state = "[inhand_icon_state]_[default_icon_file == lefthand_file ? "left" : "right"]"
	if(world.time >= inhand_bare_until && icon_exists(WIRE_SPOOL_ICON, spool_state))
		return ..(default_layer, default_icon_file, isinhands, female_uniform, spool_state, WIRE_SPOOL_ICON)
	. = ..()
	var/mutable_appearance/standing = .
	standing.alpha = 0

/// "left" or "right": the hand `user` holds this wire in, or null.
/obj/item/melee/cyberware_monowire/proc/held_side(mob/living/user)
	var/index = user?.get_held_index_of_item(src)
	if(!index)
		return null
	return IS_LEFT_INDEX(index) ? "left" : "right"

/**
 * The pixel the wire leaves the `side` hand ("left" or "right") of `holder` from: the one the held wire's spool lights,
 * where the wire comes out of it, for each facing (the bright pixel in the spool of the "monowire" states in
 * cyberware_lefthand.dmi and cyberware_righthand.dmi; the far hand in profile shows no spool, only the hand's edge).
 * By its lower left corner, in pixels from the middle of the tile: a line of wire is drawn from the middle of this
 * pixel. Also whether that hand is behind the body as the body faces: the far hand in profile, and both hands of a body
 * facing away. The hands hang at the hips; in profile the near hand is at the middle of the body and the far one just
 * shows at its front edge. The garrote's wire leaves the same pixels. list(x, y, behind)
 */
/proc/wire_hand_point(mob/living/holder, side)
	var/right = side != "left"
	switch(holder.dir)
		if(EAST)
			return right ? list(-2, -3, FALSE) : list(4, -3, TRUE)
		if(WEST)
			return right ? list(-5, -3, TRUE) : list(1, -3, FALSE)
		if(NORTH)
			return right ? list(7, -3, TRUE) : list(-8, -3, TRUE)
	return right ? list(-8, -3, FALSE) : list(7, -3, FALSE)

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
 * The pixel the `zone` part of `body` is drawn on, by its lower left corner in pixels from the middle of its tile: as
 * it stands and faces (wire_part_offset()), turned with it when it lies, then moved by its offsets. list(x, y)
 */
/proc/wire_zone_point(mob/living/body, zone)
	var/list/at = wire_part_offset(zone, body.dir)
	var/matrix/shape = body.transform
	// The pixel its middle lands in.
	var/middle_x = at[1] + 0.5
	var/middle_y = at[2] + 0.5
	return list(floor(shape.a * middle_x + shape.b * middle_y + shape.c) + body.pixel_x, floor(shape.d * middle_x + shape.e * middle_y + shape.f) + body.pixel_y)

/**
 * The pixel of the `zone` part of a standing human body facing `facing` that a line of wire lands on, by its lower left
 * corner in pixels from the middle of its tile. An arm or leg: the pixel in the middle of the cut across its shoulder
 * or hip, the middle of the "wire_cut_<zone>" seam's line, where the limb comes away. The body's right is the screen's
 * left facing south and its right facing north. Side on, the far arm and leg (wire_limb_far()) are hidden behind the
 * near ones, the leg drawn a pixel ahead of it; the chest is the middle of the torso. list(x, y)
 */
/proc/wire_part_offset(zone, facing)
	switch(zone)
		if(BODY_ZONE_HEAD)
			return list(-1, 9)
		if(BODY_ZONE_R_ARM, BODY_ZONE_L_ARM)
			switch(facing)
				if(EAST)
					return list(-3, 3)
				if(WEST)
					return list(2, 3)
			// Facing north the body's right is on the screen's right.
			var/screen_right = (zone == BODY_ZONE_R_ARM) == (facing == NORTH)
			return list(screen_right ? 5 : -7, 1)
		if(BODY_ZONE_R_LEG, BODY_ZONE_L_LEG)
			switch(facing)
				if(EAST)
					return list(zone == BODY_ZONE_R_LEG ? 0 : 1, -9)
				if(WEST)
					return list(zone == BODY_ZONE_L_LEG ? 0 : -1, -9)
			var/screen_right = (zone == BODY_ZONE_R_LEG) == (facing == NORTH)
			return list(screen_right ? 2 : -4, -7)
	return list(facing == WEST ? 0 : -1, -1)

/**
 * A landed swing: the wire lashes from the hand holding it to the part of `target` it cut (`zone`, else the part the
 * wielder aimed at), ending on the shoulder or hip of a limb it takes off (wire_zone_point()): one straight thin line in
 * its own colour that fades out over half a second. It is the wire: the one hanging in the hand isn't drawn until the
 * line fades (wire_lash_hide()). A stretched line, not tg's Beam(): a beam's segments are drawn over every body
 * whatever layer they are given, and this one must pass behind some. `cross`: this wire's half of a crossing cut,
 * which runs on through the middle of the chest so that it crosses the other hand's there (also set for the next lash
 * by wire_cross_lash()). The line starts where the hand rests and doesn't follow it through tg's lunge
 * (do_attack_animation()): a client plays that lean already under way when it sees it, and plays the new line from its
 * start, so a line moved along with the lean ran ahead of the hand and stopped short of it.
 *
 * The map draws whatever stands lower on the screen (its tile plus pixel_y) over what stands higher, whatever the
 * layer, and orders things level with each other by layer. The line is drawn in two pieces that meet where it leaves
 * the wielder's tile, each sorted against its own body, a few pixels in front of it or behind it:
 * - The hand's piece, on the wielder's tile: over him from a hand in front of his body, under him from one behind it
 *   (the far hand side on, both hands facing away).
 * - The target's piece, on the target's tile: under the target where the line meets it behind its body
 *   (wire_lash_behind()), else over it. Up a row from the wielder, a piece over a leg goes at once, as the line snaps
 *   through it: left on, it runs along the leg and paints it.
 * From a wielder facing the viewer, a line that would slant across his own legs lands out to the hand's side on the
 * limb it cuts, if it can clear them there (wire_lash_clear_legs()).
 *
 * The line runs from the middle of the pixel the wire leaves the hand from (wire_hand_point()) to the middle of the
 * pixel it lands on (wire_zone_point()), and covers both, whichever way it runs. Both pieces are cut from that one
 * line (wire_lash_shape()), so they meet without a step; only the target's piece carries the wire's bright end.
 *
 * A swing that carried on into someone standing right behind its target draws wire_lash_through() instead.
 */
/// How fast the piece of a lash that runs along a leg beyond the wielder goes.
#define WIRE_LASH_SNAP_FADE (0.25 SECONDS)
/// How far past the middle of the chest each line of a crossing cut runs, in pixels.
#define WIRE_CROSS_PAST 6
/// tg's lunge moves the wielder up to 8 pixels along pixel_y, which moves him in the map's front-to-back order: the
/// hand's piece sorts this far in front of him (or behind), so a lean toward or away from the viewer never crosses it.
#define WIRE_LASH_ROW_HAND 9
/// The target's piece sorts this far in front of the target (or behind): a body lying down is drawn a few pixels lower
/// (tg's lying offset), and so in front of anything placed level with its tile.
#define WIRE_LASH_ROW_TARGET 4
/// The line starts this far before the middle of the pixel it leaves the hand from, so that pixel is always drawn.
#define WIRE_LASH_BACK 0.5

/obj/item/melee/cyberware_monowire/proc/wire_lash_at(mob/living/user, atom/target, zone, cross = FALSE)
	var/turf/from = get_turf(user)
	var/turf/hit = get_turf(target)
	cross = cross || lash_crossing
	lash_crossing = FALSE
	var/mob/living/through = lash_through?.resolve()
	lash_through = null
	if(!from || !hit || from == hit || from.z != hit.z)
		return
	// The swing carried on into someone right behind its target: the one line runs on to them, past a limb it took off
	// or the middle of a crossing cut, so they see what cut them. The other wire of a crossing cut still crosses.
	if(through && isliving(target) && wire_lash_through(user, target, through))
		return
	zone = zone || check_zone(user.zone_selected)
	var/list/hand = wire_hand_point(user, held_side(user) || "right")
	// The pixel the line leaves and the pixel it lands on, by their lower left corners: the first from the middle of the
	// wielder's tile, the second from the middle of the target's.
	var/hand_x = user.pixel_x + hand[1]
	var/hand_y = user.pixel_y + hand[2]
	var/tile_x = (hit.x - from.x) * ICON_SIZE_X
	var/tile_y = (hit.y - from.y) * ICON_SIZE_Y
	var/end_x = target.pixel_x
	var/end_y = target.pixel_y
	var/behind = FALSE
	if(isliving(target))
		var/list/part = wire_zone_point(target, cross ? BODY_ZONE_CHEST : zone)
		end_x = part[1]
		end_y = part[2]
		behind = wire_lash_behind(user, target, zone, hand[3], cross)
	if(cross)
		var/run_x = tile_x + end_x - hand_x
		var/run_y = tile_y + end_y - hand_y
		var/run = max(sqrt(run_x ** 2 + run_y ** 2), 1)
		end_x += round(run_x * WIRE_CROSS_PAST / run)
		end_y += round(run_y * WIRE_CROSS_PAST / run)
	else if(hit.y < from.y && user.dir == SOUTH && user.body_position != LYING_DOWN)
		end_x = wire_lash_clear_legs(user, hand_x, hand_y + 0.5, tile_x + end_x, tile_y + end_y + 0.5) - tile_x
	wire_lash_hide(user)
	// From the middle of the one pixel to the middle of the other.
	var/span_x = tile_x + end_x - hand_x
	var/span_y = tile_y + end_y - hand_y
	var/length = sqrt(span_x ** 2 + span_y ** 2)
	if(length < 1)
		return
	// How far along it leaves the wielder's tile: by its side beside him, else by its foot or head.
	var/along = 1
	if(hit.y == from.y)
		if(span_x)
			along = (SIGN(tile_x) * ICON_SIZE_X / 2 - (hand_x + 0.5)) / span_x
	else if(span_y)
		along = (SIGN(tile_y) * ICON_SIZE_Y / 2 - (hand_y + 0.5)) / span_y
	along = clamp(along, 0, 1)
	// The hand's piece: from just before the middle of the hand's pixel, so that pixel is always drawn, to the edge.
	var/hand_row = user.pixel_y + (hand[3] ? WIRE_LASH_ROW_HAND : -WIRE_LASH_ROW_HAND)
	if(along * length >= 0.5)
		wire_line_piece(from, hand_x, hand_y, wire_lash_shape(span_x, span_y, -WIRE_LASH_BACK, along * length, 0.5, 0.5), lash_run_state(), wire_line_layer(hand[3]), hand_row)
	// The target's piece: on from the edge, to just past the middle of the pixel it lands on. It is placed on the pixel
	// the edge point falls in, and the rest of the way to that point is in its shape, so the two pieces are one line.
	var/edge_x = hand_x + 0.5 + span_x * along - tile_x
	var/edge_y = hand_y + 0.5 + span_y * along - tile_y
	var/base_x = floor(edge_x)
	var/base_y = floor(edge_y)
	var/snap = hit.y > from.y && !behind && !cross && (zone == BODY_ZONE_L_LEG || zone == BODY_ZONE_R_LEG)
	var/target_row = target.pixel_y + (behind ? WIRE_LASH_ROW_TARGET : -WIRE_LASH_ROW_TARGET)
	wire_line_piece(hit, base_x, base_y, wire_lash_shape(span_x, span_y, 0, (1 - along) * length + 0.5, edge_x - base_x, edge_y - base_y), lash_state(), behind ? BELOW_MOB_LAYER : ABOVE_MOB_LAYER, target_row, fade = snap ? WIRE_LASH_SNAP_FADE : WIRE_LASH_FADE)

/**
 * The lash of a swing that carried on through `target` into `behind`, standing right behind it (wire_cleave()): the one
 * line runs on, straight from the hand to the middle of `behind`'s chest, the last part it cut, through `target` on the
 * way. No light of its own and no line of blood: it is the wire. Cut from one line like any lash (wire_lash_shape()),
 * in four pieces, each sorted against its own body:
 * - The hand's piece, on the wielder's tile, as in any lash.
 * - On `target`'s tile, up to where the line passes its chest: over it, or under one standing nearer the viewer than
 *   the wielder, met on its far side (wire_lash_behind()).
 * - On from there to the edge of `behind`'s tile the wire has gone through `target` and out of its other side: under
 *   it where it went in over it, over it where it went in under it. Inside a body or behind one, it isn't seen. Over
 *   a body lying on the floor all the way.
 * - On `behind`'s tile, to its chest, with the wire's bright end: over it or under it by the same rule.
 * Returns FALSE, with nothing drawn, if the three don't stand so that a line can run through them in that order.
 */
/obj/item/melee/cyberware_monowire/proc/wire_lash_through(mob/living/user, mob/living/target, mob/living/behind)
	var/list/line = wire_through_line(user, target, behind)
	if(!line)
		return FALSE
	var/turf/from = get_turf(user)
	var/turf/first = get_turf(target)
	var/turf/last = get_turf(behind)
	var/list/hand = wire_hand_point(user, held_side(user) || "right")
	var/start_x = line[1]
	var/start_y = line[2]
	var/span_x = line[3]
	var/span_y = line[4]
	var/length = line[5]
	var/leaves = line[6]
	var/passes = line[7]
	var/enters = line[8]
	// The hand's pixel, by its lower left corner.
	var/hand_x = start_x - 0.5
	var/hand_y = start_y - 0.5
	wire_lash_hide(user)
	if(leaves >= 0.5)
		wire_line_piece(from, hand_x, hand_y, wire_lash_shape(span_x, span_y, -WIRE_LASH_BACK, leaves, 0.5, 0.5), lash_run_state(), wire_line_layer(hand[3]), user.pixel_y + (hand[3] ? WIRE_LASH_ROW_HAND : -WIRE_LASH_ROW_HAND))
	var/under = wire_lash_behind(user, target, BODY_ZONE_CHEST, hand[3], FALSE)
	var/under_after = target.body_position == LYING_DOWN ? under : !under
	wire_lash_stretch(first, from, start_x, start_y, span_x, span_y, length, leaves, passes, lash_run_state(), under, target.pixel_y)
	wire_lash_stretch(first, from, start_x, start_y, span_x, span_y, length, passes, enters, lash_run_state(), under_after, target.pixel_y)
	wire_lash_stretch(last, from, start_x, start_y, span_x, span_y, length, enters, length + 0.5, lash_state(), wire_lash_behind(user, behind, BODY_ZONE_CHEST, hand[3], FALSE), behind.pixel_y)
	return TRUE

/**
 * The line a through-cut's lash runs along (wire_lash_through()): straight from the middle of the pixel the wire leaves
 * `user`'s hand from to the middle of the pixel in the middle of `behind`'s chest, through `target` on the way. Null if
 * the three don't stand so that a line can run through them in that order. list(start_x, start_y, span_x, span_y,
 * length, leaves, passes, enters): where it starts and how far it runs, in pixels from the middle of the wielder's
 * tile, its length, and how far along it, in pixels, it leaves the wielder's tile, passes the first body's chest and
 * enters the second's tile. The wire's through-cut picks who it carries into by this same line (wire_through_target()).
 */
/obj/item/melee/cyberware_monowire/proc/wire_through_line(mob/living/user, mob/living/target, mob/living/behind)
	var/turf/from = get_turf(user)
	var/turf/first = get_turf(target)
	var/turf/last = get_turf(behind)
	if(QDELETED(behind) || !from || !first || !last || from.z != first.z || from.z != last.z || from == first || first == last || from == last)
		return null
	// The second body stands straight on along the swing: the step from the first body to it runs the same way as the
	// way from the wielder to the first body. A swing at a knight's move has no body straight behind its target.
	var/reach_x = first.x - from.x
	var/reach_y = first.y - from.y
	var/past_x = last.x - first.x
	var/past_y = last.y - first.y
	if(reach_x * past_y != reach_y * past_x || reach_x * past_x + reach_y * past_y <= 0)
		return null
	var/list/hand = wire_hand_point(user, held_side(user) || "right")
	var/hand_x = user.pixel_x + hand[1]
	var/hand_y = user.pixel_y + hand[2]
	// The pixel it passes on the first body and the pixel it lands on, by their lower left corners from the middle of
	// each body's own tile; the tiles, from the middle of the wielder's.
	var/list/chest = wire_zone_point(target, BODY_ZONE_CHEST)
	var/list/end = wire_zone_point(behind, BODY_ZONE_CHEST)
	var/first_x = (first.x - from.x) * ICON_SIZE_X
	var/first_y = (first.y - from.y) * ICON_SIZE_Y
	var/last_x = (last.x - from.x) * ICON_SIZE_X
	var/last_y = (last.y - from.y) * ICON_SIZE_Y
	// From the middle of the hand's pixel to the middle of the one it lands on.
	var/start_x = hand_x + 0.5
	var/start_y = hand_y + 0.5
	var/span_x = last_x + end[1] - hand_x
	var/span_y = last_y + end[2] - hand_y
	var/length = sqrt(span_x ** 2 + span_y ** 2)
	if(length < 1)
		return null
	var/leaves = length * wire_line_crosses(start_x, start_y, span_x, span_y, first.y == from.y, SIGN(first_x) * ICON_SIZE_X / 2, SIGN(first_y) * ICON_SIZE_Y / 2)
	var/enters = length * wire_line_crosses(start_x, start_y, span_x, span_y, last.y == first.y, last_x - SIGN(last_x - first_x) * ICON_SIZE_X / 2, last_y - SIGN(last_y - first_y) * ICON_SIZE_Y / 2)
	if(enters < leaves)
		return null
	var/passes = clamp(((first_x + chest[1] - hand_x) * span_x + (first_y + chest[2] - hand_y) * span_y) / length, leaves, enters)
	return list(start_x, start_y, span_x, span_y, length, leaves, passes, enters)

/**
 * Where a through-cut's line (wire_through_line()) cuts the two bodies: the pixel it passes on `target`, level with the
 * middle of its chest, and the pixel it ends on in the middle of `behind`'s chest, each by its lower left corner from
 * the middle of that body's own tile. Their blood leaves from there (wire_through_fx()). list(list(x, y), list(x, y)),
 * or null if no line runs through the three.
 */
/obj/item/melee/cyberware_monowire/proc/wire_through_cuts(mob/living/user, mob/living/target, mob/living/behind)
	var/list/line = wire_through_line(user, target, behind)
	if(!line)
		return null
	var/turf/from = get_turf(user)
	var/turf/first = get_turf(target)
	var/along = line[7] / line[5]
	var/pass_x = line[1] + line[3] * along - (first.x - from.x) * ICON_SIZE_X
	var/pass_y = line[2] + line[4] * along - (first.y - from.y) * ICON_SIZE_Y
	return list(list(floor(pass_x), floor(pass_y)), wire_zone_point(behind, BODY_ZONE_CHEST))

/**
 * One stretch of a lash's line beyond the wielder's tile, from `from_length` to `to_length` pixels along it, on the
 * tile `where` of the body it is sorted against: `under` it or over it, `row` being that body's pixel_y. The line
 * starts (`start_x`, `start_y`) from the middle of the wielder's tile `from` and runs (`span_x`, `span_y`), `length`
 * long. The piece is placed on the pixel its first point falls in, and the rest of the way to that point is in its
 * shape, so that consecutive stretches are one line (wire_lash_shape()).
 */
/obj/item/melee/cyberware_monowire/proc/wire_lash_stretch(turf/where, turf/from, start_x, start_y, span_x, span_y, length, from_length, to_length, state, under, row)
	if(to_length - from_length < 0.5)
		return
	var/at_x = start_x + span_x * from_length / length - (where.x - from.x) * ICON_SIZE_X
	var/at_y = start_y + span_y * from_length / length - (where.y - from.y) * ICON_SIZE_Y
	var/base_x = floor(at_x)
	var/base_y = floor(at_y)
	wire_line_piece(where, base_x, base_y, wire_lash_shape(span_x, span_y, 0, to_length - from_length, at_x - base_x, at_y - base_y), state, under ? BELOW_MOB_LAYER : ABOVE_MOB_LAYER, row + (under ? WIRE_LASH_ROW_TARGET : -WIRE_LASH_ROW_TARGET))

/// How far along a line from (`start_x`, `start_y`) running (`span_x`, `span_y`) it crosses the edge between two tiles:
/// the upright edge at `edge_x` for tiles side by side (`level`), else the level one at `edge_y`. From 0 to 1.
/proc/wire_line_crosses(start_x, start_y, span_x, span_y, level, edge_x, edge_y)
	if(level)
		return span_x ? clamp((edge_x - start_x) / span_x, 0, 1) : 1
	return span_y ? clamp((edge_y - start_y) / span_y, 0, 1) : 1

#undef WIRE_LASH_SNAP_FADE
#undef WIRE_CROSS_PAST
#undef WIRE_LASH_ROW_HAND
#undef WIRE_LASH_ROW_TARGET
#undef WIRE_LASH_BACK

/**
 * A stretch of a lash's line, as a transform for one of its pieces (the "wire_lash" states of WIRE_GORE_ICON: half a
 * tile of line running up from the middle of the icon, a half pixel left of it). The whole line runs from a point
 * toward one (`span_x`, `span_y`) away; this piece is the stretch from `from_length` to `to_length` pixels along it,
 * the point itself being (`at_x`, `at_y`) from the lower left corner of the pixel the piece is placed on: (0.5, 0.5)
 * for the middle of that pixel. Two pieces of one line given the same bearing and consecutive stretches meet exactly.
 */
/proc/wire_lash_shape(span_x, span_y, from_length, to_length, at_x, at_y)
	var/matrix/shape = matrix()
	shape.Translate(0.5, 0)
	shape.Scale(1, max(to_length - from_length, 0.5) / 16)
	shape.Translate(0, from_length)
	shape.Turn(arctan(span_y, span_x))
	shape.Translate(at_x, at_y)
	return shape

/**
 * Whether a lash from `user` meets `body` behind it, so its end is drawn under the body:
 * - A body standing nearer the viewer than the wielder (a row down the screen) is met on its far side, whatever way it
 *   faces: the line runs down from the hand to its outline and on behind it, its head, back and other leg, to the part
 *   it cuts. A crossing cut's two wires cross behind it too.
 * - Side on, an arm or leg on the far side of a standing body (wire_limb_far()), behind the near limbs and the torso.
 *   In a crossing cut, the wire from the wielder's far hand side on (`hand_behind`) runs through behind the near
 *   hand's, under both bodies.
 * - A body further off than the wielder is met on the side facing the viewer: over it. So is one lying on the floor.
 */
/proc/wire_lash_behind(mob/living/user, mob/living/body, zone, hand_behind, cross)
	var/turf/body_turf = get_turf(body)
	var/turf/user_turf = get_turf(user)
	if(body.body_position != LYING_DOWN && body_turf && user_turf && body_turf.y < user_turf.y)
		return TRUE
	if(cross)
		return hand_behind && (user.dir & (EAST | WEST))
	return body.body_position != LYING_DOWN && wire_limb_far(zone, body.dir)

/**
 * While its lash shows, the wire hanging in the hand isn't drawn, whichever way `user` faces: the line out of the grip
 * is the wire, out to the target. It is back as the line fades, never both at once and never neither. Its spool stays
 * in the hand: the line comes out of it. Every lash goes through here (wire_lash_at()): an ordinary swing, the aimed
 * sever, the Arc's, and both halves of a crossing cut, each wire for its own hand. A longer hide already running (the
 * swing out of the spool, the garrote) is left as it is.
 */
/obj/item/melee/cyberware_monowire/proc/wire_lash_hide(mob/living/user)
	if(inhand_hidden_until >= world.time + WIRE_LASH_HIDE)
		return
	hide_inhand_for(WIRE_LASH_HIDE, spool = TRUE)

/// The middle of a body facing the viewer, in pixels from the middle of its tile as a lash's line is placed: tg draws
/// bodies a pixel left of the tile's middle.
#define WIRE_BODY_MIDDLE -1
/// A lash's line keeps at least this far off that middle down the trouser legs (rows 6 to 13 below the tile's middle)...
#define WIRE_CLEAR_TROUSERS 5.75
/// ...and this far down the shoes (rows 14 to 16), which stand wider. Either way its soft edge stays off them.
#define WIRE_CLEAR_SHOES 6.7
/// A lash's end moves no further than this to clear the legs: it still lands on the shoulder or hip it cuts.
#define WIRE_CLEAR_REACH 3

/**
 * Where across a lash from a hand at (`hand_x`, `hand_y`) to a body a row down lands, given that it would land at
 * (`end_x`, `end_y`) (all in pixels off the middle of the wielder's tile), so that it runs down beside the legs of a
 * wielder facing the viewer, not across them: moved out to the hand's side as far as it has to go and no further. One
 * that can't clear them without landing more than WIRE_CLEAR_REACH off the limb's joint, a limb across the body from
 * the hand, is left where it was: the line goes to the limb that comes off.
 */
/proc/wire_lash_clear_legs(mob/living/user, hand_x, hand_y, end_x, end_y)
	var/span_y = end_y - hand_y
	if(span_y >= 0)
		return end_x
	var/middle = user.pixel_x + WIRE_BODY_MIDDLE
	var/side = hand_x < middle ? -1 : 1
	var/span_x = end_x - hand_x
	// Each band's top and bottom rows (a straight line is furthest in at one of them), and how far off the middle it keeps.
	var/static/list/bands = list(list(-6, -13, WIRE_CLEAR_TROUSERS), list(-14, -16, WIRE_CLEAR_SHOES))
	for(var/list/band as anything in bands)
		for(var/row in list(band[1], band[2]))
			// How far along the line that row's middle is.
			var/along = (user.pixel_y + row + 0.5 - hand_y) / span_y
			if(along <= 0 || along > 1)
				continue
			var/most = (middle + side * band[3] - hand_x) / along
			span_x = side < 0 ? min(span_x, most) : max(span_x, most)
	var/cleared = hand_x + span_x
	if(abs(cleared - end_x) > WIRE_CLEAR_REACH)
		return end_x
	return cleared

#undef WIRE_BODY_MIDDLE
#undef WIRE_CLEAR_TROUSERS
#undef WIRE_CLEAR_SHOES
#undef WIRE_CLEAR_REACH

/**
 * One straight piece of a lash on `where`: placed on the pixel (`base_x`, `base_y`) off the middle of that tile (its
 * lower left corner), drawn as `shape` (wire_lash_shape()) in `state`, at world `line_layer`; it fades out over `fade`.
 * Over the usual WIRE_LASH_FADE it is down to a trace as the wire comes back into the hand (wire_lash_hide()) and
 * holds that until it goes: both are the server's timers, so a server running behind keeps the line in the hand until
 * the wire is drawn. It is placed with pixel_w and pixel_z, which only move the picture; `row` (pixel_y) is where it
 * sorts among the things on its tile's row, which the map orders front to back before it looks at layers
 * (wire_lash_at()).
 */
/obj/item/melee/cyberware_monowire/proc/wire_line_piece(turf/where, base_x, base_y, matrix/shape, state, line_layer, row = 0, fade = WIRE_LASH_FADE)
	if(!where || !shape)
		return
	var/obj/effect/abstract/wire_reach/lash = new(where)
	lash.icon_state = state
	lash.layer = line_layer
	lash.add_overlay(emissive_appearance(lash.icon, lash.icon_state, lash))
	lash.pixel_y = row
	lash.pixel_w = base_x
	lash.pixel_z = base_y - row
	lash.transform = shape
	if(fade == WIRE_LASH_FADE)
		animate(lash, alpha = WIRE_LASH_TRACE, time = WIRE_LASH_HIDE, easing = QUAD_EASING | EASE_IN)
	else
		animate(lash, alpha = 0, time = fade, easing = QUAD_EASING | EASE_IN)
	QDEL_IN(lash, fade)

/// The line of a lash that ends on what it hit: the wire's bright end at its far end.
/obj/item/melee/cyberware_monowire/proc/lash_state()
	return "wire_lash"

/obj/item/melee/cyberware_monowire/live/lash_state()
	return "wire_lash_live"

/// The line of a lash that runs on into another piece: no bright end.
/obj/item/melee/cyberware_monowire/proc/lash_run_state()
	return "wire_lash_run"

/obj/item/melee/cyberware_monowire/live/lash_run_state()
	return "wire_lash_run_live"

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
	var/bearing = forward_x ? (forward_x > 0 ? 90 : 270) : (forward_y > 0 ? 0 : 180)
	// Spread evenly over a cone ahead and over the reach, each with some give, and dealt out at random so that no two
	// neighbours in the cone are also neighbours in reach: the drops land as a scatter, never a row or a line.
	var/list/reaches = list()
	for(var/i in 1 to WIRE_FLICK_DROPS)
		reaches += 12 + round(24 * i / WIRE_FLICK_DROPS)
	shuffle_inplace(reaches)
	var/slice = 90 / WIRE_FLICK_DROPS
	for(var/i in 1 to WIRE_FLICK_DROPS)
		var/angle = bearing - 45 + slice * (i - 0.5) + rand(-slice, slice) / 2
		var/reach = reaches[i] + rand(-3, 3)
		var/land_x = start_x + round(sin(angle) * reach) + rand(-3, 3)
		var/land_y = start_y + round(cos(angle) * reach) + rand(-3, 3)
		// Facing away, every drop lands past the head, ahead of him: on the floor beside it, it reads as blood by his ear.
		if(forward_y > 0)
			land_y = max(land_y, (abs(land_x) < 10 ? 26 : 22) + rand(0, 6))
		var/height = 5 + rand(0, 6)
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

/obj/effect/temp_visual/wire_blood_drop/Initialize(mapload, list/drop, blood_color, list/blood_dna, list/viruses)
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
	// Thrown away from the viewer, it flies behind whoever it leaves, not over their head. An 8th entry says so outright,
	// for drops that leave from above the floor; else it is read from where it lands.
	if(length(drop) >= 8 ? drop[8] : (land_y > start_y + 2))
		layer = BELOW_MOB_LAYER
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
	addtimer(CALLBACK(GLOBAL_PROC, GLOBAL_PROC_REF(wire_drop_land), get_turf(src), land_x, land_y, blood_dna, viruses), duration - 0.1)

/// A drop of the fan comes down at (`land_x`, `land_y`) pixels from the middle of `origin`.
/proc/wire_drop_land(turf/origin, land_x, land_y, list/blood_dna, list/viruses)
	if(!origin)
		return
	var/tile_x = floor((land_x + 16) / 32)
	var/tile_y = floor((land_y + 16) / 32)
	var/turf/landing = locate(origin.x + tile_x, origin.y + tile_y, origin.z)
	if(!landing || isgroundlessturf(landing) || !landing.has_gravity() || (landing != origin && hv_blood_spray_blocked(landing)))
		return
	var/obj/effect/decal/cleanable/blood/drip/wire_flick/drop = new(landing, viruses, blood_dna)
	if(QDELETED(drop))
		return
	drop.wire_place(land_x - tile_x * 32, land_y - tile_y * 32)

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

/// Puts the drop's blood, not its picture, at (`x`, `y`) pixels off the middle of its tile: each of tg's drop
/// pictures sits off the middle its own way, by up to eight pixels.
/obj/effect/decal/cleanable/blood/drip/wire_flick/proc/wire_place(x, y)
	var/static/list/offsets = list("drip1" = list(-2, 0), "drip2" = list(4, -1), "drip3" = list(6, -5), "drip4" = list(1, -8), "drip5" = list(-6, -6))
	var/list/offset = offsets[icon_state] || list(0, 0)
	pixel_x = x - offset[1]
	pixel_y = y - offset[2]
	// tg's five drops are all one size of blob. These land smaller or larger, turned and flipped, about their own middle.
	var/size = pick(0.5, 0.75, 1, 1, 1.25)
	var/matrix/shape = matrix()
	shape.Translate(-offset[1], -offset[2])
	shape.Scale(size * pick(-1, 1), size)
	shape.Turn(pick(0, 90, 180, 270))
	shape.Translate(offset[1], offset[2])
	transform = shape
	appearance_flags |= PIXEL_SCALE
