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
 *   the bearer's tile in the middle, already cut where a body hides them.
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
 * "body" the bearer's flat picture, anything else a piece. Bearer and target are pixel offsets from their own
 * tiles; tilt turns the victim about the feet (degrees, clockwise); raise is how high the fists ride in the
 * body picture (0 leaves it). West is east mirrored.
 */
/proc/mantis_rig_beat(move, beat, facing)
	var/view = (facing & (EAST|WEST)) ? "E" : (facing == NORTH ? "N" : "S")
	var/list/spec
	switch("[move]_[beat]_[view]")
		// ---- The impale. The lunge arrival is the bearer's own lunge pose.
		if("impale_enter_E")
			spec = list(list("far", "body", "nrest", "T", "narm", "ntop"), 7, 0, -17, 0, 0, 2)
		if("impale_hold_E")
			spec = list(list("far", "body", "nrest", "T", "narm", "ntop"), 7, 0, -17, 4, 0, 2)
		if("impale_pull_E")
			spec = list(list("far", "body", "nrest", "T", "narm", "ntop"), 4, 0, -19, 1, 0, 1)
		if("impale_rip_E")
			spec = list(list("far", "body", "T", "near"), 6, 0, -12, 2, 14, 1)
		if("impale_drop_E")
			spec = list(list("T", "far", "body", "near"), 0, 0, 0, 0, 0, 2)
		if("impale_enter_N")
			spec = list(list("tips", "T", "arms", "body"), 0, 24, 0, 0, 0, 0)
		if("impale_hold_N")
			spec = list(list("tips", "T", "arms", "body"), 0, 24, 0, 4, 0, 0)
		if("impale_pull_N")
			spec = list(list("tips", "T", "arms", "body"), 0, 23, 0, 0, 0, 0)
		if("impale_rip_N")
			spec = list(list("T", "arms", "body"), 0, 15, 0, 0, 0, 0)
		if("impale_drop_N")
			spec = list(list("T", "arms", "body"), 0, 0, 0, 0, 0, 0)
		if("impale_enter_S")
			spec = list(list("body", "arms", "T", "tips"), 0, 0, 0, 24, 0, 0)
		if("impale_hold_S")
			spec = list(list("body", "arms", "T", "tips"), 0, 0, 0, 28, 0, 0)
		if("impale_pull_S")
			spec = list(list("body", "arms", "T", "tips"), 0, 0, 0, 23, 0, 0)
		if("impale_rip_S")
			spec = list(list("body", "arms", "T"), 0, -2, 0, 13, 0, 0)
		if("impale_drop_S")
			spec = list(list("T", "body", "arms"), 0, 0, 0, 0, 0, 0)
		// ---- The scissor.
		if("scissor_raise_E", "scissor_glint_E")
			spec = list(list("T", "far", "body", "near"), 0, 0, 0, 0, 0, 3)
		if("scissor_close_E", "scissor_cut_E")
			spec = list(list("fblade", "T", "farm", "body", "near"), 10, 0, 0, 0, 0, 1)
		if("scissor_recover_E")
			spec = list(list("T", "far", "body", "near"), 0, 0, 0, 0, 0, 2)
		if("scissor_raise_N", "scissor_glint_N", "scissor_recover_N")
			spec = list(list("T", "arms", "body"), 0, 0, 0, 0, 0, 0)
		if("scissor_close_N", "scissor_cut_N")
			spec = list(list("T", "arms", "body"), 0, 10, 0, 0, 0, 0)
		if("scissor_raise_S", "scissor_glint_S", "scissor_recover_S")
			spec = list(list("T", "body", "arms"), 0, 0, 0, 0, 0, 0)
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

/datum/mantis_rig/New(mob/living/carbon/bearer, mob/living/victim, facing, model, move)
	. = ..()
	src.bearer = bearer
	src.victim = victim
	src.facing = facing
	src.model = model
	src.move = move
	RegisterSignal(bearer, COMSIG_QDELETING, PROC_REF(on_bearer_deleted))
	if(victim)
		RegisterSignal(victim, COMSIG_QDELETING, PROC_REF(on_victim_deleted))

/datum/mantis_rig/Destroy()
	reveal()
	for(var/key in puppets)
		qdel(puppets[key])
	puppets = null
	if(bearer)
		UnregisterSignal(bearer, COMSIG_QDELETING)
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
 */
/datum/mantis_rig/proc/snapshot()
	for(var/obj/item/melee/energy/blade/hardlight/cyberware_mantis/blade as anything in mantis_held_blades(bearer))
		blade.hide_inhand_for(10 SECONDS)
	var/mutable_appearance/look = new(bearer.appearance)
	look.filters = null
	if(facing & (NORTH|SOUTH))
		for(var/image/part as anything in look.overlays.Copy())
			if(part.layer == -GLOVES_LAYER || findtext("[part.icon_state]", "_hand"))
				look.overlays -= part
	var/obj/effect/abstract/mantis_puppet/body = puppet("body")
	var/body_layer = body.layer
	body.appearance = look
	body.dir = facing
	body.layer = body_layer
	body.mouse_opacity = MOUSE_OPACITY_TRANSPARENT
	body.pixel_x = bearer.pixel_x
	body.pixel_y = bearer.pixel_y
	body.pixel_w = base_w + lean_w
	body.pixel_z = base_z + lean_z

/// The fists ride [new_raise] pixels high in the body picture (mantis_stance_raise()).
/datum/mantis_rig/proc/set_raise(new_raise)
	if(!new_raise || new_raise == raise || QDELETED(bearer))
		return
	raise = new_raise
	for(var/obj/item/melee/energy/blade/hardlight/cyberware_mantis/blade as anything in mantis_held_blades(bearer))
		var/obj/item/organ/cyberimp/arm/toolkit/cyberware/mantis/housing = blade.housing_ref?.resolve()
		housing?.set_stance_raise(new_raise)
	if(puppets["body"])
		snapshot()

/// The puppet under [key], made on the bearer's tile at the lean drawn now if there isn't one.
/datum/mantis_rig/proc/puppet(key)
	var/obj/effect/abstract/mantis_puppet/picture = puppets[key]
	if(picture)
		return picture
	picture = new(get_turf(bearer))
	picture.name = bearer.name
	picture.pixel_x = bearer.pixel_x
	picture.pixel_y = bearer.pixel_y
	picture.pixel_w = base_w + lean_w
	picture.pixel_z = base_z + lean_z
	if(key != "body")
		picture.icon = MANTIS_GORE_REACH_ICON
		picture.pixel_x -= ICON_SIZE_X
		picture.pixel_y -= ICON_SIZE_Y
	puppets[key] = picture
	return picture

/**
 * Draws [new_beat]: each piece of its stack is swapped in at its layer next to the victim's, pieces it
 * doesn't use go, and the whole bearer leans to the beat's lean, plus [extra_w] and [extra_z], over [time].
 */
/datum/mantis_rig/proc/show(new_beat, extra_w = 0, extra_z = 0, time = 0.1 SECONDS)
	if(QDELETED(bearer))
		return
	var/list/spec = mantis_rig_beat(move, new_beat, facing)
	if(!spec)
		return
	beat = new_beat
	set_raise(spec[MANTIS_RIG_RAISE])
	var/list/order = spec[MANTIS_RIG_ORDER]
	var/victim_at = order.Find("T")
	var/victim_layer = (victim && !QDELETED(victim)) ? victim.layer : bearer.layer
	var/list/used = list()
	for(var/i in 1 to length(order))
		var/key = order[i]
		if(key == "T")
			continue
		var/obj/effect/abstract/mantis_puppet/picture = puppet(key)
		if(key != "body")
			picture.icon_state = "[model]_[move]_[beat]_[key]"
			picture.dir = facing
		picture.layer = victim_layer + (i - victim_at) * MANTIS_RIG_LAYER_STEP
		used[key] = TRUE
	for(var/key in puppets.Copy())
		if(!used[key])
			qdel(puppets[key])
			puppets -= key
	lean_w = spec[MANTIS_RIG_BEARER_W] + extra_w
	lean_z = spec[MANTIS_RIG_BEARER_Z] + extra_z
	for(var/key in puppets)
		animate(puppets[key], pixel_w = base_w + lean_w, pixel_z = base_z + lean_z, time = time, easing = SINE_EASING)

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
