/**
 * # The blade rig: the impale and the scissor, drawn around the victim
 *
 * Both moves need parts of the bearer under the victim and parts over it: in the side view the far blade
 * and the bearer's body go under the person skewered and the near arm and blade over them, and the far
 * blade passes under a neck on the floor while the bearer stands over it. Pictures attached to a mob
 * (overlays, underlays, vis_contents) are drawn with the mob, so they can't sit between two mobs. So for
 * these moves the bearer is drawn as separate pictures ("puppets") standing on their tile, each with its
 * own layer next to the victim's, the way the Gorilla Arms finishers draw their arm rig
 * (voidcrew/modules/hyperviolence_gorilla/chrome_puppet_rig.dm):
 *
 * - "body": a copy of the bearer's appearance without the held blades, and without the hands seen from the
 *   front or back, where the blades' forearms take their place.
 * - The arms and blades of each beat, from mantis_gore_reach.dmi: "<model>_<move>_<beat>_<piece>", 96x96 with
 *   the bearer's tile in the middle. Steel inside the victim on the camera's side of them is cut out of its
 *   piece; steel on their far side is drawn under them and left to their outline. Blood on the blades is a coat over
 *   each piece ("<piece>_blood" or "_soak", the held art's two coats) tinted by the blood, read off the held
 *   blades, so a blade already wet stays wet and one drenched in the move turns red as it happens. The impale
 *   also has wet points from the moment they come out of the back, in the victim's blood.
 * - Pieces of the victim's blood: "wound" (where the steel goes in and out) and "drip" (drops off the points),
 *   and "glint", the light on the near blade before the scissor. Sprays, and the crackle of the blades' light
 *   at the points as they punch out, are loose pictures (burst()) that stay where they started and outlive the beat.
 * - The map is SIDE_MAP: rows sort before layers, so every picture is centred with pixel_w/pixel_z and stands on
 *   the row of what it must sort against (sort_y()).
 *
 * mantis_rig_beat() has each beat's stack, back to front, with "T" where the victim goes, and the lean.
 * Puppets are plain objects on the bearer's tile, so nothing touches the real bearer's own picture,
 * offsets or layer; the real bearer is hidden with a colour filter (still clickable over its whole tile)
 * and comes back when the rig is deleted. Its owner deletes it on every way the move ends.
 */

#define MANTIS_RIG_HIDE_FILTER "mantis_rig_hide"
/// The gap between two neighbours in the stack around the victim.
#define MANTIS_RIG_LAYER_STEP 0.001

/**
 * One beat of [move] seen facing [facing], from the approved storyboards (S/mantis-storyboard): list(order,
 * bearer_w, bearer_z, target_w, target_z, tilt, raise). Order is the stack back to front: "T" is the victim,
 * "body" the bearer's flat picture without the held blades, "whole" that picture as the bearer is held (blades
 * and all), anything else a piece. Bearer and target are pixel offsets from their own tiles; tilt turns the
 * victim about the feet (degrees, clockwise); raise is how high the fists ride in the body picture (0 leaves
 * it). West is east mirrored.
 */
/proc/mantis_rig_beat(move, beat, facing)
	var/view = (facing & (EAST|WEST)) ? "E" : (facing == NORTH ? "N" : "S")
	var/list/spec
	switch("[move]_[beat]_[view]")
		// ---- The impale. "arrive" glides in with the lunging body. "contact" is the slide onto the blades: whole
		// blades, and everything on the far side of the target (the near blade past the fist, "nrest", in the side
		// view) drawn under them, so the target itself covers the steel it has slid onto. Then they are in: "enter".
		if("impale_arrive_E")
			spec = list(list("T", "far", "body", "near"), 2, 0, 0, 0, 0, 2)
		if("impale_contact_E")
			spec = list(list("far", "body", "nrest", "T", "narm", "near"), 7, 0, -17, 0, 0, 1)
		// From the stab to the hold the blades go through the same place on the target: "enter", "lift1" and "lift2"
		// are the hold's blades 4, 2 and 1 px lower, with the target. The steel inside them is cut out of the near
		// blade; the far blade is under them.
		if("impale_enter_E")
			spec = list(list("far", "body", "T", "wound", "narm", "near"), 7, 0, -17, 0, 0, 1)
		if("impale_lift1_E")
			spec = list(list("far", "body", "T", "wound", "narm", "near"), 7, 0, -17, 2, 0, 2)
		if("impale_lift2_E")
			spec = list(list("far", "body", "T", "wound", "narm", "near"), 7, 0, -17, 3, 0, 2)
		if("impale_hold_E")
			spec = list(list("far", "body", "T", "wound", "drip", "narm", "near"), 7, 0, -17, 4, 0, 2)
		// The pull-back in three steps: the bearer leans back, the arms draw back and the target slides off,
		// 3 px of steel out a step. Only what has come out of the front shows.
		if("impale_pull1_E")
			spec = list(list("far", "body", "T", "wound", "narm", "near"), 6, 0, -16, 3, 0, 2)
		if("impale_pull2_E")
			spec = list(list("far", "body", "T", "wound", "narm", "near"), 5, 0, -15, 2, 0, 2)
		if("impale_pull3_E")
			spec = list(list("far", "body", "T", "wound", "narm", "near"), 4, 0, -14, 1, 0, 2)
		if("impale_rip_E")
			spec = list(list("far", "body", "T", "near"), 6, 0, -12, 2, 14, 1)
		if("impale_drop_E")
			spec = list(list("T", "far", "body", "near"), 0, 0, 0, 0, 0, 2)
		// Seen from behind the target is on the row beyond the bearer, facing the camera. The blades go into the
		// chest a torso's width apart: "arms" is the forearms and the fists, which the bearer's back hides; "tips"
		// is the blades, drawn behind the target: what shows of them is the points past the shoulders by the neck.
		if("impale_arrive_N")
			spec = list(list("T", "arms", "body"), 0, 2, 0, 0, 0, 0)
		if("impale_contact_N", "impale_enter_N")
			spec = list(list("tips", "T", "arms", "body"), 0, 24, 0, 0, 0, 0)
		if("impale_lift1_N")
			spec = list(list("tips", "T", "arms", "body"), 0, 24, 0, 2, 0, 0)
		if("impale_lift2_N")
			spec = list(list("tips", "T", "arms", "body"), 0, 24, 0, 3, 0, 0)
		if("impale_hold_N")
			spec = list(list("tips", "T", "arms", "body"), 0, 24, 0, 4, 0, 0)
		if("impale_pull1_N")
			spec = list(list("tips", "T", "arms", "body"), 0, 23, 0, 3, 0, 0)
		if("impale_pull2_N")
			spec = list(list("tips", "T", "arms", "body"), 0, 22, 0, 2, 0, 0)
		if("impale_pull3_N")
			spec = list(list("tips", "T", "arms", "body"), 0, 21, 0, 1, 0, 0)
		if("impale_rip_N")
			spec = list(list("T", "arms", "body"), 0, 15, 0, 0, 0, 0)
		// The drop from the front and the back is the bearer as they are held again ("whole": the guard, blood and
		// all), so nothing changes when the real bearer comes back.
		if("impale_drop_N")
			spec = list(list("T", "whole"), 0, 0, 0, 0, 0, 0)
		// Seen from the front the target is on the row before the bearer, their back to the camera, and covers the
		// bearer's arms and the steel going in. "tips" is the two points out of their back, over them.
		if("impale_arrive_S")
			spec = list(list("body", "arms", "T"), 0, -2, 0, 0, 0, 0)
		if("impale_contact_S")
			spec = list(list("body", "arms", "T"), 0, 0, 0, 24, 0, 0)
		if("impale_enter_S")
			spec = list(list("body", "arms", "T", "wound", "tips"), 0, 0, 0, 24, 0, 0)
		if("impale_lift1_S")
			spec = list(list("body", "arms", "T", "wound", "tips"), 0, 0, 0, 26, 0, 0)
		if("impale_lift2_S")
			spec = list(list("body", "arms", "T", "wound", "tips"), 0, 0, 0, 27, 0, 0)
		if("impale_hold_S")
			spec = list(list("body", "arms", "T", "wound", "tips", "drip"), 0, 0, 0, 28, 0, 0)
		if("impale_pull1_S")
			spec = list(list("body", "arms", "T", "wound", "tips"), 0, 0, 0, 27, 0, 0)
		if("impale_pull2_S")
			spec = list(list("body", "arms", "T", "wound", "tips"), 0, 0, 0, 25, 0, 0)
		if("impale_pull3_S")
			spec = list(list("body", "arms", "T", "wound", "tips"), 0, 0, 0, 23, 0, 0)
		if("impale_rip_S")
			spec = list(list("body", "arms", "T"), 0, -2, 0, 13, 0, 0)
		// They fall in front of the bearer, and are drawn over them all the way down.
		if("impale_drop_S")
			spec = list(list("whole", "T"), 0, 0, 0, 0, 0, 0)
		// ---- The scissor.
		if("scissor_raise_E")
			spec = list(list("T", "far", "body", "near"), 0, 0, 0, 0, 0, 3)
		if("scissor_glint_E")
			spec = list(list("T", "far", "body", "near", "glint"), 0, 0, 0, 0, 0, 3)
		// Half way down from the raise to the close: the swing.
		if("scissor_swing_E")
			spec = list(list("T", "far", "body", "near"), 5, 0, 0, 0, 0, 2)
		if("scissor_close_E", "scissor_cut_E")
			spec = list(list("fblade", "T", "farm", "body", "near"), 10, 0, 0, 0, 0, 1)
		if("scissor_recover_E")
			spec = list(list("T", "far", "body", "near"), 0, 0, 0, 0, 0, 2)
		if("scissor_raise_N", "scissor_recover_N")
			spec = list(list("T", "arms", "body"), 0, 0, 0, 0, 0, 0)
		if("scissor_glint_N")
			spec = list(list("T", "arms", "glint", "body"), 0, 0, 0, 0, 0, 0)
		if("scissor_close_N", "scissor_cut_N")
			spec = list(list("T", "arms", "body"), 0, 10, 0, 0, 0, 0)
		if("scissor_raise_S", "scissor_recover_S")
			spec = list(list("T", "body", "arms"), 0, 0, 0, 0, 0, 0)
		if("scissor_glint_S")
			spec = list(list("T", "body", "arms", "glint"), 0, 0, 0, 0, 0, 0)
		if("scissor_swing_S")
			spec = list(list("T", "body", "arms"), 0, -8, 0, 0, 0, 0)
		if("scissor_close_S", "scissor_cut_S")
			spec = list(list("T", "body", "arms"), 0, -16, 0, 0, 0, 0)
	if(isnull(spec))
		return null
	if(facing & WEST)
		spec[MANTIS_RIG_BEARER_W] = -spec[MANTIS_RIG_BEARER_W]
		spec[MANTIS_RIG_TARGET_W] = -spec[MANTIS_RIG_TARGET_W]
		spec[MANTIS_RIG_TILT] = -spec[MANTIS_RIG_TILT]
	return spec

/// The way the rig draws a move from [user] to [victim]: the side view for anything off to the side.
/proc/mantis_rig_facing(atom/user, atom/victim)
	var/toward = get_dir(user, victim) || user.dir
	if(toward & EAST)
		return EAST
	if(toward & WEST)
		return WEST
	return toward & NORTH ? NORTH : SOUTH

/// One picture of the rig on the bearer's tile.
/obj/effect/abstract/mantis_puppet
	name = "body"
	mouse_opacity = MOUSE_OPACITY_TRANSPARENT
	anchored = TRUE
	appearance_flags = PIXEL_SCALE | TILE_BOUND | LONG_GLIDE
	animate_movement = NO_STEPS
	plane = GAME_PLANE
	layer = MOB_LAYER
	vis_flags = NONE
	/// Pixels it is drawn off the bearer's lean (pixel_w, pixel_z): a 96x96 piece is centred on the tile, and
	/// one standing on another row (mantis_rig/proc/set_row()) is drawn back where it belongs.
	var/shift_w = 0
	var/shift_z = 0

/// A spray of the victim's blood drawn by the rig: it stays where it started and goes on its own.
/obj/effect/abstract/mantis_rig_fx
	name = "blood"
	icon = MANTIS_GORE_REACH_ICON
	mouse_opacity = MOUSE_OPACITY_TRANSPARENT
	anchored = TRUE
	appearance_flags = PIXEL_SCALE | TILE_BOUND | LONG_GLIDE
	animate_movement = NO_STEPS
	plane = GAME_PLANE
	layer = MOB_LAYER
	vis_flags = NONE

/datum/mantis_rig
	/// Who is drawn
	var/mob/living/carbon/bearer
	/// Whom the stack is built around
	var/mob/living/victim
	/// The way the pictures face
	var/facing
	/// The blades' model, for the pieces
	var/model
	/// "impale" or "scissor"
	var/move
	/// Key -> /obj/effect/abstract/mantis_puppet
	var/list/puppets = list()
	/// The beat drawn now
	var/beat
	/// How high the fists ride in the body picture now
	var/raise = 0
	/// The bearer's own offsets when the rig went up, under every lean
	var/base_w = 0
	var/base_z = 0
	/// The lean drawn now, from base_w and base_z
	var/lean_w = 0
	var/lean_z = 0
	/// TRUE while the real bearer is hidden
	var/hidden = FALSE
	var/old_mouse_opacity
	/// The victim's layer when the beat drawn now went up
	var/victim_layer = MOB_LAYER
	/// The colour of the victim's blood, or null if they don't bleed
	var/victim_color
	/// TRUE once the points have been through the victim: wet with their blood even before a drench
	var/wet = FALSE
	/// The blood on the blades drawn now: null, "blood" or "soak" (the held art's coats), and its colour
	var/coat
	var/coat_color
	/// TRUE while the pictures fade out and the real bearer fades back in (hand_back())
	var/handing_back = FALSE
	/// TRUE while the body picture is the bearer as they are held, blades and all ("whole")
	var/whole = FALSE

/datum/mantis_rig/New(mob/living/carbon/bearer, mob/living/victim, facing, model, move)
	. = ..()
	src.bearer = bearer
	src.victim = victim
	src.facing = facing
	src.model = model
	src.move = move
	RegisterSignal(bearer, COMSIG_QDELETING, PROC_REF(on_bearer_deleted))
	// A kill while the rig draws the blades only stains them: the rig draws the blood it leaves (mantis_kill_credit()).
	bearer.get_mantis_state().rig = src
	if(victim)
		RegisterSignal(victim, COMSIG_QDELETING, PROC_REF(on_victim_deleted))
		if(victim.can_bleed(BLOOD_COVER_TURFS) == BLEED_SPLATTER)
			var/datum/blood_type/blood = victim.get_bloodtype()
			victim_color = blood?.get_color()

/datum/mantis_rig/Destroy()
	reveal()
	for(var/key in puppets)
		qdel(puppets[key])
	puppets = null
	if(bearer)
		UnregisterSignal(bearer, COMSIG_QDELETING)
		if(bearer.mantis_state?.rig == src)
			bearer.mantis_state.rig = null
		for(var/obj/item/melee/energy/blade/hardlight/cyberware_mantis/blade as anything in mantis_held_blades(bearer))
			blade.show_inhand()
	if(victim)
		UnregisterSignal(victim, COMSIG_QDELETING)
	bearer = null
	victim = null
	return ..()

/datum/mantis_rig/proc/on_bearer_deleted(datum/source)
	SIGNAL_HANDLER
	qdel(src)

/datum/mantis_rig/proc/on_victim_deleted(datum/source)
	SIGNAL_HANDLER
	UnregisterSignal(victim, COMSIG_QDELETING)
	victim = null

/**
 * Puts the rig up: hides the held blades and the real bearer and stands the body picture in its place.
 * FALSE if the bearer can't be drawn this way (not on a turf); the move goes on without the poses.
 */
/datum/mantis_rig/proc/start()
	if(QDELETED(bearer) || !isturf(bearer.loc))
		return FALSE
	base_w = bearer.pixel_w - bearer.has_offset(HV_FINISHER_OFFSET, PIXEL_W_OFFSET)
	base_z = bearer.pixel_z - bearer.has_offset(HV_FINISHER_OFFSET, PIXEL_Z_OFFSET)
	snapshot()
	conceal()
	return TRUE

/**
 * Draws the body puppet as the bearer looks now, without the held blades: a copy of the bearer's own
 * appearance, so the client already has every icon in it and it never blinks while one downloads. Seen from
 * the front or back the hands and gloves are left off: the forearms of the blades start at the elbows.
 * [as_held]: the bearer exactly as they are held, blades, hands and all, for a beat that ends on the held art.
 */
/datum/mantis_rig/proc/snapshot(as_held = FALSE)
	whole = as_held
	for(var/obj/item/melee/energy/blade/hardlight/cyberware_mantis/blade as anything in mantis_held_blades(bearer))
		if(as_held)
			blade.show_inhand()
		else
			blade.hide_inhand_for(10 SECONDS)
	var/mutable_appearance/look = new(bearer.appearance)
	look.filters = null
	if(!as_held && (facing & (NORTH|SOUTH)))
		for(var/image/part as anything in look.overlays.Copy())
			if(part.layer == -GLOVES_LAYER || findtext("[part.icon_state]", "_hand"))
				look.overlays -= part
	var/obj/effect/abstract/mantis_puppet/body = puppet("body")
	var/body_layer = body.layer
	var/body_row = body.pixel_y
	body.appearance = look
	body.dir = facing
	body.layer = body_layer
	body.mouse_opacity = MOUSE_OPACITY_TRANSPARENT
	body.pixel_x = own_x()
	body.pixel_y = body_row
	body.pixel_w = base_w + lean_w + body.shift_w
	body.pixel_z = base_z + lean_z + body.shift_z

/**
 * The bearer's pixel_x and pixel_y under the rig's own lean: without a #509 finisher's lean (pose_user()), which
 * the rig draws itself. pixel_y is also the row the pictures sort on.
 */
/datum/mantis_rig/proc/own_x()
	return bearer.pixel_x - bearer.has_offset(HV_FINISHER_OFFSET, PIXEL_X_OFFSET)

/datum/mantis_rig/proc/own_y()
	return bearer.pixel_y - bearer.has_offset(HV_FINISHER_OFFSET, PIXEL_Y_OFFSET)

/// The fists ride [new_raise] pixels high in the body picture (mantis_stance_raise()).
/datum/mantis_rig/proc/set_raise(new_raise)
	if(!new_raise || new_raise == raise || QDELETED(bearer))
		return
	raise = new_raise
	for(var/obj/item/melee/energy/blade/hardlight/cyberware_mantis/blade as anything in mantis_held_blades(bearer))
		var/obj/item/organ/cyberimp/arm/toolkit/cyberware/mantis/housing = blade.housing_ref?.resolve()
		housing?.set_stance_raise(new_raise)
	if(puppets["body"])
		snapshot(whole)

/// The puppet under [key], made on the bearer's tile at the lean drawn now if there isn't one.
/datum/mantis_rig/proc/puppet(key)
	var/obj/effect/abstract/mantis_puppet/picture = puppets[key]
	if(picture)
		return picture
	picture = new(get_turf(bearer))
	picture.name = bearer.name
	picture.pixel_x = own_x()
	picture.pixel_y = own_y()
	// Centred with pixel_w and pixel_z only: pixel_y picks the row it sorts on (set_row()).
	if(key != "body")
		picture.icon = MANTIS_GORE_REACH_ICON
		picture.shift_w = -ICON_SIZE_X
		picture.shift_z = -ICON_SIZE_Y
	picture.pixel_w = base_w + lean_w + picture.shift_w
	picture.pixel_z = base_z + lean_z + picture.shift_z
	puppets[key] = picture
	return picture

/**
 * The pixel_y, from the bearer's tile, of the row a picture drawn [behind] the victim (or in front of them)
 * sorts on. The map is SIDE_MAP: BYOND sorts by row (a tile's y plus pixel_y) before layer, so a picture
 * only sorts against the victim by its layer on the victim's own row. One the bearer's row already puts on
 * the right side of the victim stays on the bearer's row, under or over everything else there as before.
 */
/datum/mantis_rig/proc/sort_y(behind)
	var/own = own_y()
	if(!victim || QDELETED(victim) || victim.z != bearer.z || !isturf(victim.loc))
		return own
	var/theirs = (victim.y - bearer.y) * ICON_SIZE_Y + victim.pixel_y
	if(behind ? own > theirs : own < theirs)
		return own
	return theirs

/// Stands [picture] on the row [row_y], still drawn where it was.
/datum/mantis_rig/proc/set_row(obj/effect/abstract/mantis_puppet/picture, row_y)
	var/change = row_y - picture.pixel_y
	if(!change)
		return
	picture.pixel_y = row_y
	picture.shift_z -= change
	picture.pixel_z -= change

/**
 * Draws [new_beat]: each piece of its stack is swapped in at its layer next to the victim's, pieces it
 * doesn't use go, and the whole bearer leans to the beat's lean, plus [extra_w] and [extra_z], over [time].
 * With [from_w] or [from_z] every picture starts that far off and glides into place over [time] instead, the
 * way the lunging body glides in (mantis_lunge_dash_fx()): one animation, so the client sees the start.
 * [ride_z] lifts everything but the bearer's body that far: the arms and the blades riding with someone who
 * sags on them, so the steel in them stays where it is in them. [body_z] lifts only the bearer's body that far.
 */
/datum/mantis_rig/proc/show(new_beat, extra_w = 0, extra_z = 0, time = 0.1 SECONDS, from_w = 0, from_z = 0, easing = SINE_EASING, ride_z = 0, body_z = 0)
	if(QDELETED(bearer))
		return
	var/list/spec = mantis_rig_beat(move, new_beat, facing)
	if(!spec)
		return
	beat = new_beat
	set_raise(spec[MANTIS_RIG_RAISE])
	var/list/order = spec[MANTIS_RIG_ORDER]
	var/victim_at = order.Find("T")
	victim_layer = (victim && !QDELETED(victim)) ? victim.layer : bearer.layer
	var/list/used = list()
	for(var/i in 1 to length(order))
		var/key = order[i]
		if(key == "T")
			continue
		// The victim's own blood: nothing to draw on someone who doesn't bleed.
		var/bloody = (key == "wound" || key == "drip")
		if(bloody && !victim_color)
			continue
		// The body picture, with or without the held blades.
		if(key == "whole" || key == "body")
			if((key == "whole") != whole)
				snapshot(key == "whole")
			key = "body"
		var/obj/effect/abstract/mantis_puppet/picture = puppet(key)
		if(key != "body")
			var/state = "[model]_[move]_[beat]_[key]"
			// A looping picture (the drops) would start over if it were set again.
			if(picture.icon_state != state)
				picture.icon_state = state
			picture.dir = facing
			if(bloody)
				picture.color = victim_color
		picture.layer = victim_layer + (i - victim_at) * MANTIS_RIG_LAYER_STEP
		set_row(picture, sort_y(i < victim_at))
		used[key] = TRUE
	for(var/key in puppets.Copy())
		if(!used[key])
			qdel(puppets[key])
			puppets -= key
	dress()
	lean_w = spec[MANTIS_RIG_BEARER_W] + extra_w
	lean_z = spec[MANTIS_RIG_BEARER_Z] + extra_z
	for(var/key in puppets)
		var/obj/effect/abstract/mantis_puppet/picture = puppets[key]
		var/to_w = base_w + lean_w + picture.shift_w
		var/to_z = base_z + lean_z + picture.shift_z + (key == "body" ? body_z : ride_z)
		if(from_w || from_z)
			picture.pixel_w = to_w + from_w
			picture.pixel_z = to_z + from_z
		// At once, ending whatever was still moving it.
		if(!time)
			animate(picture, pixel_w = to_w, pixel_z = to_z, time = 0)
			continue
		animate(picture, pixel_w = to_w, pixel_z = to_z, time = time, easing = easing)

/**
 * Blood on the blades as the held blades have it now: the heavier coat while one is drenched, the light one
 * while one is only stained, and at least the light one in the victim's blood once the points have been
 * through them. A blade that keeps itself clean (the Scorch) shows none.
 */
/datum/mantis_rig/proc/read_coat()
	coat = null
	coat_color = null
	if(QDELETED(bearer))
		return
	for(var/obj/item/melee/energy/blade/hardlight/cyberware_mantis/blade as anything in mantis_held_blades(bearer))
		if(blade.item_flags & NO_BLOOD_ON_ITEM)
			coat = null
			return
		if(!blade.is_bloody() || coat == "soak")
			continue
		coat = world.time < blade.soaked_until ? "soak" : "blood"
		coat_color = blade.get_blood_dna_color()
	if(!coat && wet && victim_color)
		coat = "blood"
		coat_color = victim_color

/// Puts the blood on every blade piece drawn now (read_coat()).
/datum/mantis_rig/proc/dress()
	read_coat()
	for(var/key in puppets)
		if(key == "body" || key == "wound" || key == "drip" || key == "glint")
			continue
		var/obj/effect/abstract/mantis_puppet/picture = puppets[key]
		picture.cut_overlays()
		if(!coat)
			continue
		var/state = "[picture.icon_state]_[coat]"
		if(!icon_exists(MANTIS_GORE_REACH_ICON, state))
			continue
		var/mutable_appearance/blood = mutable_appearance(MANTIS_GORE_REACH_ICON, state)
		blood.color = coat_color
		picture.add_overlay(blood)

/**
 * A spray of the victim's blood, "<model>_<move>_<name>", drawn where the beat drawn now puts it and left
 * there for [lifetime]: just over (or, with [under], just under) the piece [key], or the victim for "T".
 * Not [blood]: a flash of the blades' own light, drawn in its own colours.
 */
/datum/mantis_rig/proc/burst(name, lifetime, key = "T", under = FALSE, blood = TRUE)
	if(QDELETED(bearer) || (blood && !victim_color))
		return null
	var/state = "[model]_[move]_[name]"
	if(!icon_exists(MANTIS_GORE_REACH_ICON, state))
		return null
	var/obj/effect/abstract/mantis_rig_fx/spray = new(get_turf(bearer))
	spray.icon_state = state
	spray.dir = facing
	if(blood)
		spray.color = victim_color
	else
		spray.name = "light"
	var/obj/effect/abstract/mantis_puppet/beside = puppets[key]
	var/beside_layer = beside ? beside.layer : victim_layer
	spray.layer = beside_layer + (under ? -0.5 : 0.5) * MANTIS_RIG_LAYER_STEP
	// On the row of what it sorts against, centred with pixel_w and pixel_z (set_row()).
	spray.pixel_x = own_x()
	spray.pixel_y = beside ? beside.pixel_y : sort_y(under)
	spray.pixel_w = base_w + lean_w - ICON_SIZE_X
	spray.pixel_z = base_z + lean_z - ICON_SIZE_Y + own_y() - spray.pixel_y
	QDEL_IN(spray, lifetime)
	return spray

/**
 * The move is over: the real bearer, held blades and all, is drawn again at once, and the pictures, lifted
 * over it in the same order, fade out over [time]. A pose that differs from the held art eases into it
 * instead of jumping, and nothing is ever see-through: the real bearer underneath is whole. Then the rig goes.
 */
/datum/mantis_rig/proc/hand_back(time = MANTIS_RIG_HANDBACK)
	if(handing_back || QDELETED(src))
		return
	handing_back = TRUE
	if(QDELETED(bearer) || !time)
		qdel(src)
		return
	for(var/obj/item/melee/energy/blade/hardlight/cyberware_mantis/blade as anything in mantis_held_blades(bearer))
		blade.show_inhand()
	reveal()
	var/lowest
	for(var/key in puppets)
		var/obj/effect/abstract/mantis_puppet/picture = puppets[key]
		lowest = isnull(lowest) ? picture.layer : min(lowest, picture.layer)
	var/lift = isnull(lowest) ? 0 : max(0, bearer.layer - lowest + MANTIS_RIG_LAYER_STEP)
	for(var/key in puppets)
		var/obj/effect/abstract/mantis_puppet/picture = puppets[key]
		picture.layer += lift
		animate(picture, alpha = 0, time = time, flags = ANIMATION_PARALLEL)
	QDEL_IN(src, time)

/// Hides the real bearer. Its whole tile still takes clicks.
/datum/mantis_rig/proc/conceal()
	if(hidden || QDELETED(bearer))
		return
	hidden = TRUE
	old_mouse_opacity = bearer.mouse_opacity
	bearer.mouse_opacity = MOUSE_OPACITY_OPAQUE
	bearer.add_filter(MANTIS_RIG_HIDE_FILTER, 1, color_matrix_filter(list(1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0)))

/// Shows the real bearer again.
/datum/mantis_rig/proc/reveal()
	if(!hidden)
		return
	hidden = FALSE
	if(QDELETED(bearer))
		return
	bearer.mouse_opacity = old_mouse_opacity
	bearer.remove_filter(MANTIS_RIG_HIDE_FILTER)

#undef MANTIS_RIG_HIDE_FILTER
#undef MANTIS_RIG_LAYER_STEP
