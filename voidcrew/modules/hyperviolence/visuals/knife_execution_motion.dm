// Hyperviolence visuals: knife executions (overlays_exec/knife_executions.dm). Purely visual: nothing here
// changes what a body can do, and every body ends drawn exactly where it stands.
//
// From directly behind a standing victim (/datum/hv_knife_exec_vis):
// 1. Grab (0 - 0.35 s): the attacker steps in until he stands chest to back, his arms coming up as he closes. His
//    free hand takes the victim's shoulder and hauls him back; the knife hand goes to the throat. The victim's own
//    hand comes up at the knife hand.
// 2. Hold (to 1.5 s, the game's own wind-up): the victim jerks against the hold, the attacker's hands stay on him.
// 3. Cut (0.25 s, held 0.1 s): the blade draws across the throat and blood goes forward, the way the victim faces.
// 4. Let go (0.3 s): the attacker's hands come off and he steps back to the middle of his own tile. A victim still
//    on his feet stumbles forward to the middle of his, bent over, his hand at his throat. Falling is tg's business:
//    a victim the cut drops is drawn held up until the blade is through, then falls tg's own way.
// A broken wind-up puts everything back in 0.2 s, no blood.
//
// The attacker's arms are stand-ins: his own arm, sleeve and glove, read a pixel at a time from his own picture and
// drawn as upper arm, forearm and hand between his shoulder and wherever the hand is. The real arm is masked off (or,
// side on, covered with his own chest) while they show, and his held knife is drawn in the stand-in hand, turned to
// lie on the throat. Bodies and arms are tweened through the same moments with straight-line steps, so a hand stays
// on the spot it holds in every frame.
//
// The bodies are moved in their transform by the plain animation sequence (as hv_vis_play_over() does), not a named
// one: the move is played in two parts, the wind-up and then the cut, and a named sequence started while one of the
// same name still runs is sometimes added to it in the client instead of replacing it (seen in recordings: both
// bodies thrown twice as far at the cut). Every part ends on the body's real transform. Named sequences of other
// animations (a flinch, tg's offsets) keep running on top; tg's own turn when a body lies down takes the plain
// sequence over, which is when this one is over anyway.
//
// Draw order (SIDE_MAP sorts by tile row, then layer): from the north the attacker is on the row behind the victim, so
// pieces behind the victim go on the attacker's tile and pieces in front on the victim's. From the south it is the
// other way round and the knife hand goes under the victim: the cut is out of sight behind his head. Side on, both
// stand on one row; the attacker is put a hair under the victim and his far arm a hair under himself.
//
// A victim who is lying down, or an attacker at a back corner, gets the plain version: the attacker leans in, cuts
// and straightens up.

/mob/living
	/// Suppresses tg's attack lunge and floating item picture during the execution's own head stab.
	var/hv_vis_knife_executing = FALSE

/obj/item/knife
	/// The pictures of the execution this knife is doing from behind, while they run.
	var/datum/hv_knife_exec_vis/hv_vis_exec
	/// Weakref to the mob whose held picture of this knife is hidden while a stand-in hand holds it.
	var/datum/weakref/hv_vis_holder_ref
	/// TRUE while the stand-in hand holds the knife, so build_worn_icon() draws no second one.
	var/hv_vis_hide_inhand = FALSE
	/// Whether the current execution completed its cut, so hv_start_knife_execution() skips the broken clean-up.
	var/hv_vis_cut_landed = FALSE
	/// world.time before which a new wind-up gets the plain version: reading two bodies' pictures for the stand-in
	/// arms is not free, and a wind-up can be started and broken as fast as its holder can click.
	var/hv_vis_hold_after = 0
	/// TRUE while its holder leans in for the plain version (no hold from behind).
	var/hv_vis_pressing = FALSE

// feature/stealth's knife_executions.dm (decision 45's one backstab) sets hv_knife_exec_spray itself and drops the
// cover defines. Until this branch is merged there, the same number is worked out here; this block and the one in
// hv_finish_knife_execution() below compile out once the defines are gone.
#ifdef HV_KNIFE_EXECUTION_LOW_COVER
/obj/item/knife
	/// How far the last execution's throat blood sprays (0-2 tiles), by the worst cut it left on the head.
	var/hv_knife_exec_spray = 0
#endif

/obj/item/knife/Destroy()
	hv_vis_drop_exec()
	return ..()

/obj/item/knife/dropped(mob/user, silent = FALSE)
	if(hv_vis_exec || hv_vis_hide_inhand)
		hv_vis_drop_exec()
	return ..()

/obj/item/knife/equipped(mob/user, slot, initial = FALSE)
	if(hv_vis_exec || hv_vis_hide_inhand)
		hv_vis_drop_exec()
	return ..()

/obj/item/knife/build_worn_icon(
	default_layer = 0,
	default_icon_file = null,
	isinhands = FALSE,
	female_uniform = NO_FEMALE_UNIFORM,
	override_state = null,
	override_file = null,
)
	if(isinhands && hv_vis_hide_inhand)
		var/layer2use = alternate_worn_layer || default_layer
		return mutable_appearance(layer = -layer2use)
	return ..()

/// Ends the attacker's side of a running execution at once and gives the knife its held picture back.
/obj/item/knife/proc/hv_vis_drop_exec()
	if(hv_vis_exec && !QDELETED(hv_vis_exec))
		hv_vis_exec.end_attacker(at_once = TRUE)
	hv_vis_restore_held_sprite()

/// Hides this knife's held picture on `holder` while a stand-in hand holds it.
/obj/item/knife/proc/hv_vis_hide_held_sprite(mob/living/holder)
	if(QDELETED(holder))
		return
	var/mob/living/prev_holder = hv_vis_holder_ref?.resolve()
	if(prev_holder && prev_holder != holder)
		UnregisterSignal(prev_holder, COMSIG_QDELETING)
	hv_vis_hide_inhand = TRUE
	hv_vis_holder_ref = WEAKREF(holder)
	RegisterSignal(holder, COMSIG_QDELETING, PROC_REF(hv_on_holder_qdeleting), override = TRUE)
	holder.update_held_items()

/// Puts this knife's held picture back.
/obj/item/knife/proc/hv_vis_restore_held_sprite()
	var/was_hidden = hv_vis_hide_inhand
	hv_vis_hide_inhand = FALSE
	var/mob/living/holder = hv_vis_holder_ref?.resolve()
	hv_vis_holder_ref = null
	if(holder)
		UnregisterSignal(holder, COMSIG_QDELETING)
		if(was_hidden && !QDELETED(holder))
			holder.update_held_items()
	if(was_hidden && ismob(loc) && loc != holder && !QDELETED(loc))
		var/mob/current_mob = loc
		current_mob.update_held_items()

/obj/item/knife/proc/hv_on_holder_qdeleting(datum/source)
	SIGNAL_HANDLER
	hv_vis_drop_exec()

/mob/living/do_attack_animation(atom/A, visual_effect_icon, obj/item/used_item, no_effect)
	if(hv_vis_knife_executing)
		return
	return ..()

// ---- Hooks on the execution ----

/obj/item/knife/hv_start_knife_execution(mob/living/user, mob/living/carbon/victim, list/modifiers, list/attack_modifiers)
	var/staging = !DOING_INTERACTION(user, HV_KNIFE_EXECUTION_DOAFTER) && hv_knife_execution_possible(user, victim) && isturf(user.loc) && isturf(victim.loc)
	hv_vis_cut_landed = FALSE
	if(staging)
		hv_vis_begin_knife_windup(user, victim)
	. = ..()
	if(!staging)
		return
	if(!hv_vis_cut_landed)
		hv_vis_abort_knife_windup(user, victim)

/obj/item/knife/hv_finish_knife_execution(mob/living/user, mob/living/carbon/victim, list/modifiers, list/attack_modifiers)
	if(!isturf(user?.loc) || !isturf(victim?.loc))
		return ..()
	var/was_standing = victim.body_position == STANDING_UP
	var/pre_pixel_y = victim.pixel_y
	var/matrix/pre_base = matrix(victim.transform)
	var/obj/item/bodypart/head/head_before = victim.get_bodypart(BODY_ZONE_HEAD)
	var/skull_open_before = head_before?.hv_skull_open

	// The stab's own hit spray (hv_blood_on_damaged) is held back: the throat sprays forward instead.
	var/prev_spray_until = victim.hv_blood_spray_until
	var/prev_spray_strength = victim.hv_blood_spray_strength
	victim.hv_blood_spray_until = world.time + HV_BLOOD_SPRAY_WINDOW
	victim.hv_blood_spray_strength = HV_BLOOD_MAX_RANGE

	victim.hv_vis_execution_time = world.time
	user.hv_vis_knife_executing = TRUE
	. = ..()
	if(!QDELETED(user))
		user.hv_vis_knife_executing = FALSE
	if(!QDELETED(victim))
		victim.hv_blood_spray_until = prev_spray_until
		victim.hv_blood_spray_strength = prev_spray_strength
		// The picture is a cut throat, not a broken skull: the stab's damage is booked on the head, but it doesn't
		// open the skull wound a heavy blow to the head draws (gore_overlays.dm). Picture only.
		var/obj/item/bodypart/head/head_after = victim.get_bodypart(BODY_ZONE_HEAD)
		if(head_after && head_after == head_before && !skull_open_before && head_after.hv_skull_open)
			head_after.hv_skull_open = FALSE
			if(head_after.hv_update_skull_wound())
				victim.update_damage_overlays()
	if(!.)
		return
#ifdef HV_KNIFE_EXECUTION_LOW_COVER
	hv_knife_exec_spray = 0
	if(!QDELETED(victim))
		var/worst = 0
		var/obj/item/bodypart/head/cut_head = victim.get_bodypart(BODY_ZONE_HEAD)
		for(var/datum/wound/slash/slash in cut_head?.wounds)
			worst = max(worst, slash.severity)
		if(worst >= WOUND_SEVERITY_CRITICAL)
			hv_knife_exec_spray = 2
		else if(worst >= WOUND_SEVERITY_MODERATE)
			hv_knife_exec_spray = 1
#endif

	hv_vis_cut_landed = TRUE
	hv_vis_play_knife_cut(user, victim, was_standing, pre_pixel_y, pre_base)

/// Whether `user` can hold `victim` from behind for the full picture: both human and on their feet, the attacker on
/// the tile straight behind the victim and facing his back.
/proc/hv_vis_knife_can_hold(mob/living/user, mob/living/victim)
	if(!ishuman(user) || !ishuman(victim))
		return FALSE
	if(user.body_position != STANDING_UP || victim.body_position != STANDING_UP)
		return FALSE
	if(!(victim.dir in GLOB.cardinals) || user.dir != victim.dir)
		return FALSE
	if(get_step(victim, REVERSE_DIR(victim.dir)) != user.loc)
		return FALSE
	return !user.buckled && !victim.buckled && !HAS_TRAIT(user, TRAIT_MOVE_FLOATING) && !HAS_TRAIT(victim, TRAIT_MOVE_FLOATING)

/// The wind-up begins: the hold from behind, or the plain lean-in.
/obj/item/knife/proc/hv_vis_begin_knife_windup(mob/living/user, mob/living/carbon/victim)
	hv_vis_drop_exec()
	victim.hv_vis_stop(list(HV_VIS_TAG_TREMBLE))
	if(world.time >= hv_vis_hold_after && hv_vis_knife_can_hold(user, victim))
		hv_vis_hold_after = world.time + 1 SECONDS
		var/datum/hv_knife_exec_vis/exec = new(src, user, victim)
		if(!QDELETED(exec))
			return
	// The plain version: he leans in over the victim and stays there.
	if(HAS_TRAIT(user, TRAIT_MOVE_FLOATING) || user.body_position != STANDING_UP)
		return
	var/matrix/base = matrix(user.transform)
	var/matrix/leaned = hv_vis_knife_pressed(user, victim, base, HV_VIS_KNIFE_PRESS)
	hv_vis_pressing = TRUE
	animate(user, transform = leaned, time = HV_VIS_KNIFE_STEP_TIME, easing = QUAD_EASING|EASE_OUT)
	animate(transform = leaned, time = HV_KNIFE_EXECUTION_WINDUP + 3 SECONDS)
	animate(transform = base, time = HV_VIS_KNIFE_RELEASE_TIME, easing = SINE_EASING)

/// `base` moved `distance` pixels from `user` toward `victim`.
/proc/hv_vis_knife_pressed(mob/living/user, mob/living/victim, matrix/base, distance)
	var/toward = get_dir(user, victim) || user.dir || SOUTH
	var/matrix/pressed = matrix(base)
	pressed.Translate(HV_VIS_DX(toward) * distance, HV_VIS_DY(toward) * distance)
	return pressed

/// The wind-up broke: everything goes back, no blood.
/obj/item/knife/proc/hv_vis_abort_knife_windup(mob/living/user, mob/living/carbon/victim)
	if(hv_vis_exec && !QDELETED(hv_vis_exec))
		hv_vis_exec.abort()
		return
	if(hv_vis_pressing && !QDELETED(user))
		animate(user, transform = matrix(user.transform), time = HV_VIS_KNIFE_ABORT_TIME)
	hv_vis_pressing = FALSE

/// The cut landed: the blade's draw, the blood, the let-go.
/obj/item/knife/proc/hv_vis_play_knife_cut(mob/living/user, mob/living/carbon/victim, was_standing, pre_pixel_y, matrix/pre_base)
	if(!QDELETED(user))
		user.hv_vis_stop(list(HV_VIS_TAG_HITSTOP))
	var/datum/hv_knife_exec_vis/exec = hv_vis_exec
	var/held = exec && !QDELETED(exec) && !exec.attacker_done && exec.attacker == user && exec.victim == victim && !QDELETED(victim) && isturf(victim.loc)
	if(held)
		victim.hv_vis_stop(list(HV_VIS_TAG_FLINCH, HV_VIS_TAG_TREMBLE))
		exec.cut(was_standing, pre_pixel_y, pre_base)
	else
		hv_vis_drop_exec()
		if(hv_vis_pressing && !QDELETED(user) && isturf(user.loc) && !QDELETED(victim) && user.body_position == STANDING_UP)
			// The plain version: a short jab from the lean, then he straightens up.
			var/matrix/base = matrix(user.transform)
			var/matrix/leaned = hv_vis_knife_pressed(user, victim, base, HV_VIS_KNIFE_PRESS)
			animate(user, transform = leaned, time = 0)
			animate(transform = hv_vis_knife_pressed(user, victim, base, HV_VIS_KNIFE_PRESS + 2), time = 1, easing = QUAD_EASING|EASE_OUT)
			animate(transform = leaned, time = HV_VIS_KNIFE_CUT_TIME)
			animate(transform = base, time = HV_VIS_KNIFE_RELEASE_TIME, easing = SINE_EASING)
		hv_vis_pressing = FALSE
	if(QDELETED(victim) || !isturf(victim.loc))
		return

	// Blood from the throat, as the wound lands. Held from behind it goes the way he faces, away from the attacker;
	// otherwise away from the blade.
	var/spray_dir = held ? exec.facing : (QDELETED(user) ? victim.dir : get_dir(user, victim))
	if(!spray_dir)
		spray_dir = victim.dir || SOUTH
	// As much blood as the wound that landed (hv_knife_exec_spray): none without one.
	var/obj/item/bodypart/head/head_after = victim.get_bodypart(BODY_ZONE_HEAD)
	var/spray_tiles = hv_knife_exec_spray
	if(spray_tiles <= 0 || !(head_after ? head_after.can_bleed() : victim.can_bleed()))
		return
	victim.hv_blood_spray_until = 0
	victim.hv_blood_spray_strength = 0
	// A cut that armour kept shallow throws no spray of its own: tg's own splash off the wound (a tile or so, from
	// the stab) and the short jet below are all the blood there is.
	if(spray_tiles >= 2)
		victim.hv_blood_spray(spray_dir, spray_tiles)
	if(held && exec.facing != NORTH)
		var/list/throat = exec.throat_spot()
		var/blood_color = get_color_from_blood_list(victim.get_blood_dna_list()) || BLOOD_COLOR_RED
		new /obj/effect/temp_visual/hv_throat_spurt(get_turf(victim), throat[1], throat[2], spray_dir, blood_color, spray_tiles)

// ---- Small maths ----

/// Smoothstep from 0 to 1 as `x` goes from 0 to 1.
/proc/hv_ke_smooth(x)
	x = clamp(x, 0, 1)
	return x * x * (3 - 2 * x)

/// Fast start, eased stop, from 0 to 1 as `x` goes from 0 to 1.
/proc/hv_ke_ease_out(x)
	x = clamp(x, 0, 1)
	return 1 - (1 - x) * (1 - x)

/// Blends two points.
/proc/hv_ke_mix(list/a, list/b, t)
	return list(a[1] + (b[1] - a[1]) * t, a[2] + (b[2] - a[2]) * t)

/// The shortest turn from angle `start` to angle `finish`, degrees, counter-clockwise positive.
/proc/hv_ke_turn(start, finish)
	var/turn = (finish - start) % 360
	if(turn > 180)
		turn -= 360
	else if(turn <= -180)
		turn += 360
	return turn

/// A body's transform for a pose list(x, y, clockwise lean about the feet), over its own `base`.
/proc/hv_ke_body_matrix(matrix/base, list/pose)
	var/matrix/posed = matrix()
	if(pose[3])
		posed.Translate(0, -HV_VIS_FEET_Y)
		posed.Turn(pose[3])
		posed.Translate(0, HV_VIS_FEET_Y)
	posed.Translate(pose[1], pose[2])
	return posed * base

/// Where the pixel `spot` (x, y from the bottom left of the icon) of a body drawn with `posed` is, the body's icon
/// standing with its bottom left corner on `origin`.
/proc/hv_ke_body_point(list/origin, matrix/posed, list/spot)
	var/x = spot[1] - 16
	var/y = spot[2] - 16
	return list(origin[1] + 16 + posed.a * x + posed.b * y + posed.c, origin[2] + 16 + posed.d * x + posed.e * y + posed.f)

/// The elbow of an arm from `shoulder` to `fist` with upper arm `upper` and forearm `fore` long, bent toward the side
/// (hint_x, hint_y) points to. Too far apart, both stretch evenly in a straight line.
/proc/hv_ke_elbow(list/shoulder, list/fist, upper, fore, hint_x, hint_y)
	var/dx = fist[1] - shoulder[1]
	var/dy = fist[2] - shoulder[2]
	var/reach = sqrt(dx * dx + dy * dy)
	if(reach < 0.01)
		return list(shoulder[1], shoulder[2] - upper)
	if(reach >= upper + fore)
		return list(shoulder[1] + dx * upper / (upper + fore), shoulder[2] + dy * upper / (upper + fore))
	var/along = clamp((upper * upper - fore * fore + reach * reach) / (2 * reach), -upper, upper)
	var/out = sqrt(max(upper * upper - along * along, 0))
	var/side_x = -dy / reach
	var/side_y = dx / reach
	if(side_x * hint_x + side_y * hint_y < 0)
		side_x = -side_x
		side_y = -side_y
	return list(shoulder[1] + dx * along / reach + side_x * out, shoulder[2] + dy * along / reach + side_y * out)

/// One arm of `flat` (a body's own picture): rows 11 to 20, the four columns from `first_col`, as colours or null.
/proc/hv_ke_arm_strip(icon/flat, first_col)
	var/list/strip = list()
	for(var/y in 11 to 20)
		var/list/row = new /list(4)
		for(var/x in 1 to 4)
			row[x] = flat.GetPixel(first_col + x - 1, y)
		strip["[y]"] = row
	return strip

/// One-pixel overlays that draw rows `rows` (top first) of an arm strip, four wide about the middle of an icon, the
/// top row's upper edge on the icon's middle line.
/proc/hv_ke_strip_dots(list/strip, list/rows)
	var/list/dots = list()
	for(var/k in 1 to length(rows))
		var/list/row = strip["[rows[k]]"]
		for(var/x in 1 to length(row))
			if(isnull(row[x]))
				continue
			var/mutable_appearance/dot = mutable_appearance(HV_VIS_KNIFE_PX, "px", FLOAT_LAYER)
			dot.pixel_w = 13 + x
			dot.pixel_z = 16 - k
			dot.color = row[x]
			dots += dot
	return dots

/// The pixel of a held knife's picture furthest from the hand that holds it: the tip. list(x, y) or null.
/proc/hv_ke_blade_tip(icon_file, state, facing, hand_x, hand_y)
	var/static/list/known = list()
	var/key = "[icon_file]|[state]|[facing]|[hand_x]|[hand_y]"
	var/found = known[key]
	if(found)
		return islist(found) ? found : null
	var/list/tip
	if(icon_exists(icon_file, state))
		var/icon/picture = icon(icon_file, state, facing)
		var/furthest = 2
		for(var/x in 1 to 32)
			for(var/y in 1 to 32)
				if(isnull(picture.GetPixel(x, y)))
					continue
				var/dx = x - 0.5 - hand_x
				var/dy = y - 0.5 - hand_y
				if(dx * dx + dy * dy > furthest)
					furthest = dx * dx + dy * dy
					tip = list(x - 0.5, y - 0.5)
	known[key] = tip || "none"
	return tip

// ---- Pieces ----

/// A piece of a stand-in arm: a strip of someone's own arm, drawn between two joints.
/obj/effect/abstract/hv_knife_exec_part
	name = "arm"
	icon = null
	plane = GAME_PLANE
	layer = HV_VIS_KNIFE_OVER_LAYER
	appearance_flags = PIXEL_SCALE | KEEP_TOGETHER
	mouse_opacity = MOUSE_OPACITY_TRANSPARENT
	animate_movement = NO_STEPS
	anchored = TRUE
	/// Read by the recording harness.
	var/hv_knife_exec_part = TRUE
	/// The middle of the icon this is drawn on, in the execution's own pixels.
	var/centre_x = 16
	var/centre_y = 16
	/// Rows from the strip's top edge down to its root joint, and from there to its tip joint.
	var/root_row = 0
	var/natural = 1

/obj/effect/abstract/hv_knife_exec_part/Initialize(mapload, list/dots, root_row = 0, natural = 1, draw_layer = HV_VIS_KNIFE_OVER_LAYER)
	. = ..()
	src.root_row = root_row
	src.natural = natural
	layer = draw_layer
	if(length(dots))
		add_overlay(dots)

/obj/effect/abstract/hv_knife_exec_part/ex_act(severity, target)
	return FALSE

/// The transform that draws this with its root joint on `root` and its tip joint on `tip`.
/obj/effect/abstract/hv_knife_exec_part/proc/span(list/root, list/tip)
	var/dx = tip[1] - root[1]
	var/dy = tip[2] - root[2]
	var/length = sqrt(dx * dx + dy * dy)
	var/matrix/placed = matrix()
	placed.Translate(0, root_row)
	placed.Scale(1, max(length, 0.5) / natural)
	// The strip points down; Turn() is clockwise.
	placed.Turn(length < 0.01 ? 0 : -(arctan(dx, dy) + 90))
	placed.Translate(root[1] - centre_x, root[2] - centre_y)
	return placed

/// The transform that draws this unstretched with its root joint on `spot`, pointing along `angle`.
/obj/effect/abstract/hv_knife_exec_part/proc/pin(list/spot, angle)
	var/matrix/placed = matrix()
	placed.Translate(0, root_row)
	placed.Turn(-(angle + 90))
	placed.Translate(spot[1] - centre_x, spot[2] - centre_y)
	return placed

/// The attacker's held knife, as tg draws it in his hand, carried by the stand-in hand.
/obj/effect/abstract/hv_knife_exec_part/blade
	name = "knife"
	appearance_flags = PIXEL_SCALE
	/// Read by the recording harness.
	var/hv_knife_exec_blade = TRUE
	/// The hand it is held in and its tip, pixels of its own icon.
	var/hand_x = 16
	var/hand_y = 16
	var/tip_x = 16
	var/tip_y = 16
	/// The way it points as held, degrees counter-clockwise from east, and how long it is from the hand.
	var/native_angle = 0
	var/reach = 1

/// The transform that draws the knife with its hand on `fist`, turned `turn` degrees counter-clockwise from how it
/// is held, and `squeeze` times as long along its own blade.
/obj/effect/abstract/hv_knife_exec_part/blade/proc/hold(list/fist, turn, squeeze = 1)
	var/matrix/placed = matrix()
	placed.Translate(16 - hand_x, 16 - hand_y)
	if(squeeze != 1)
		placed.Turn(native_angle)
		placed.Scale(squeeze, 1)
		placed.Turn(-native_angle)
	if(turn)
		placed.Turn(-turn)
	placed.Translate(fist[1] - centre_x, fist[2] - centre_y)
	return placed

/// One stand-in arm.
/datum/hv_knife_exec_arm
	/// Its name in a pose: "k" the knife arm, "f" the attacker's free arm, "v" the victim's own.
	var/id
	/// TRUE for the victim's own arm.
	var/on_victim = FALSE
	var/obj/effect/abstract/hv_knife_exec_part/upper
	var/obj/effect/abstract/hv_knife_exec_part/fore
	var/obj/effect/abstract/hv_knife_exec_part/hand
	/// The shoulder joint and the hanging fist, pixels of its owner's icon.
	var/list/shoulder
	var/list/hang
	/// Where the fist goes, pixels of the victim's icon: on the grab, and once the cut is through. For the victim's
	/// own arm: fighting the knife hand, and at his throat.
	var/list/hold
	var/list/after
	/// If set, the forearm ends here (pixels of the victim's icon) and the hand goes on from it: over a shoulder.
	var/list/wrist_hold
	var/list/wrist_after
	/// The side its elbow bends toward.
	var/hint_x = 0
	var/hint_y = -1

/datum/hv_knife_exec_arm/Destroy(force)
	QDEL_NULL(upper)
	QDEL_NULL(fore)
	QDEL_NULL(hand)
	return ..()

// ---- The execution from behind ----

/datum/hv_knife_exec_vis
	var/obj/item/knife/knife
	var/mob/living/carbon/human/attacker
	var/mob/living/carbon/human/victim
	/// The way the victim faced when it began: the view the poses are drawn for.
	var/facing = SOUTH
	/// world.time it began, and of the cut (-1 before it).
	var/started = 0
	var/cut_time = -1
	/// The attacker's side (his arms, the knife, his step) and the victim's side (his arm, his pose) are over.
	var/attacker_done = FALSE
	var/victim_done = FALSE
	/// The wind-up broke and everything is easing back.
	var/aborting = FALSE
	/// The tile the victim stood on when it began.
	var/turf/vic_turf
	/// The cut dropped him: he is drawn held up through it, by tg's own fall after.
	var/victim_held = FALSE
	/// He is still on his feet after the cut: he stumbles forward bent over (and, with a free hand, clutches his throat).
	var/victim_hunches = FALSE
	/// Where each body's icon stands at rest (its bottom left corner), in pixels from the victim's tile's corner.
	var/list/att_origin
	var/list/vic_origin
	var/matrix/att_base
	var/matrix/vic_base
	/// The attacker's step in, the victim's haul back, pixels.
	var/step_x = 0
	var/step_y = 0
	var/pull_x = 0
	var/pull_y = 0
	/// Clockwise degrees: the attacker's lean in, the victim bent back.
	var/att_lean = 0
	var/vic_lean = 0
	/// The victim's jerks against the hold: pixels and degrees at their peak.
	var/jerk_x = 0
	var/jerk_y = 0
	var/jerk_lean = 0
	/// A survivor bent over the cut: pixels and degrees.
	var/hunch_x = 0
	var/hunch_y = 0
	var/hunch_lean = 0
	/// Arms by id (/datum/hv_knife_exec_arm).
	var/list/arms = list()
	var/obj/effect/abstract/hv_knife_exec_part/blade/blade
	/// The way the blade points on the victim's icon, degrees counter-clockwise from east: held, and after the cut.
	var/blade_hold_angle = 0
	var/blade_after_angle = 0
	/// How long the blade is drawn once the cut is through (it swings out of sight round the throat when under 1).
	var/blade_after_squeeze = 1
	/// Pixels the knife is drawn pushed back through the hand while held at the throat. The far hand shows only where
	/// it sticks out from behind the neck, and the blade should start at what shows of it.
	var/blade_slide = 0
	/// The layer the blade drops to as the hand lets go, if any.
	var/blade_release_layer
	/// The throat, pixels of the victim's icon: where the blood starts.
	var/list/throat = list(15.5, 21.5)
	/// Filters and cover overlays on each body, to take off again.
	var/list/att_filters = list()
	var/list/vic_filters = list()
	var/mutable_appearance/att_patch
	var/mutable_appearance/vic_patch
	/// The attacker's layer before he was put under the victim (side views), or null.
	var/att_layer

/datum/hv_knife_exec_vis/New(obj/item/knife/knife, mob/living/carbon/human/attacker, mob/living/carbon/human/victim)
	src.knife = knife
	src.attacker = attacker
	src.victim = victim
	facing = victim.dir
	started = world.time
	if(!set_up())
		qdel(src)
		return
	knife.hv_vis_exec = src
	RegisterSignals(attacker, list(COMSIG_QDELETING, COMSIG_MOVABLE_MOVED, COMSIG_ATOM_POST_DIR_CHANGE, COMSIG_LIVING_SET_BODY_POSITION), PROC_REF(on_attacker_change))
	RegisterSignals(victim, list(COMSIG_QDELETING, COMSIG_MOVABLE_MOVED, COMSIG_ATOM_POST_DIR_CHANGE, COMSIG_LIVING_SET_BODY_POSITION, COMSIG_LIVING_DEATH), PROC_REF(on_victim_change))
	RegisterSignal(knife, COMSIG_QDELETING, PROC_REF(on_knife_gone))
	// Nothing outlives the move, whatever happens to it.
	QDEL_IN(src, HV_KNIFE_EXECUTION_WINDUP + 5 SECONDS)
	play(windup_keys())

/datum/hv_knife_exec_vis/Destroy(force)
	end_attacker(at_once = TRUE)
	end_victim(at_once = TRUE)
	if(knife)
		UnregisterSignal(knife, COMSIG_QDELETING)
		if(knife.hv_vis_exec == src)
			knife.hv_vis_exec = null
	if(attacker)
		UnregisterSignal(attacker, list(COMSIG_QDELETING, COMSIG_MOVABLE_MOVED, COMSIG_ATOM_POST_DIR_CHANGE, COMSIG_LIVING_SET_BODY_POSITION))
	if(victim)
		UnregisterSignal(victim, list(COMSIG_QDELETING, COMSIG_MOVABLE_MOVED, COMSIG_ATOM_POST_DIR_CHANGE, COMSIG_LIVING_SET_BODY_POSITION, COMSIG_LIVING_DEATH))
	QDEL_LIST_ASSOC_VAL(arms)
	knife = null
	attacker = null
	victim = null
	vic_turf = null
	return ..()

/// The attacker moved, turned, fell or is gone: his side ends at once.
/datum/hv_knife_exec_vis/proc/on_attacker_change(datum/source)
	SIGNAL_HANDLER
	if(QDELETED(attacker))
		qdel(src)
		return
	end_attacker(at_once = TRUE)

/// The victim moved, turned, fell, died or is gone. During the wind-up that breaks the hold: everything eases back.
/// After the cut his own side ends at once.
/datum/hv_knife_exec_vis/proc/on_victim_change(datum/source)
	SIGNAL_HANDLER
	if(QDELETED(victim))
		qdel(src)
		return
	// Inside the cut's own tick tg may lay him down: cut() deals with that.
	if(cut_time == world.time || (cut_time < 0 && victim.hv_vis_execution_time == world.time))
		end_victim_arm()
		return
	if(cut_time < 0)
		abort()
		return
	end_victim(at_once = TRUE)

/datum/hv_knife_exec_vis/proc/on_knife_gone(datum/source)
	SIGNAL_HANDLER
	qdel(src)

// ---- Setting up ----

/// Reads both bodies, builds the arms and hides the real ones. FALSE if this pair can't be drawn.
/datum/hv_knife_exec_vis/proc/set_up()
	vic_turf = get_turf(victim)
	var/turf/att_turf = get_turf(attacker)
	if(!vic_turf || !att_turf)
		return FALSE
	var/knife_zone = attacker.get_hand_zone_of_item(knife)
	if(!knife_zone || !attacker.get_bodypart(knife_zone))
		return FALSE
	var/free_zone = knife_zone == BODY_ZONE_R_ARM ? BODY_ZONE_L_ARM : BODY_ZONE_R_ARM
	var/free_arm = attacker.get_bodypart(free_zone) && !attacker.get_item_for_held_index(free_zone == BODY_ZONE_L_ARM ? 1 : 2)

	att_base = matrix(attacker.transform)
	vic_base = matrix(victim.transform)
	vic_origin = list(victim.pixel_x + victim.pixel_w, victim.pixel_y + victim.pixel_z)
	att_origin = list(
		(att_turf.x - vic_turf.x) * ICON_SIZE_X + attacker.pixel_x + attacker.pixel_w,
		(att_turf.y - vic_turf.y) * ICON_SIZE_Y + attacker.pixel_y + attacker.pixel_z,
	)

	// The knife as tg draws it in his hand.
	var/left_hand = knife_zone == BODY_ZONE_L_ARM
	var/knife_file = left_hand ? knife.lefthand_file : knife.righthand_file
	var/knife_state = knife.inhand_icon_state || knife.icon_state

	// His own picture, without the knife, before anything is masked.
	knife.hv_vis_hide_held_sprite(attacker)
	var/icon/att_flat = getFlatIcon(attacker, facing, no_anim = TRUE)
	var/icon/vic_flat = getFlatIcon(victim, facing, no_anim = TRUE)
	if(!att_flat || !vic_flat)
		knife.hv_vis_restore_held_sprite()
		return FALSE

	var/list/victim_zones
	if(facing == NORTH || facing == SOUTH)
		// The side of the screen each arm is on: his right is on the left when he faces us.
		var/knife_side = ((facing == SOUTH) == (knife_zone == BODY_ZONE_R_ARM)) ? -1 : 1
		var/turf/north_turf = facing == SOUTH ? att_turf : vic_turf
		if(facing == SOUTH)
			step_y = -HV_VIS_KNIFE_STEP_SOUTH
			pull_y = HV_VIS_KNIFE_PULL_SOUTH
			hunch_y = -2
		else
			step_y = HV_VIS_KNIFE_STEP_NORTH
			pull_y = -HV_VIS_KNIFE_PULL_NORTH
			hunch_y = 2
		jerk_x = 1.5
		throat = list(15.5, 21.5)

		var/list/knife_strip = hv_ke_arm_strip(att_flat, knife_side < 0 ? 8 : 21)
		var/datum/hv_knife_exec_arm/knife_arm
		if(facing == SOUTH)
			// Behind the victim down to the wrist, the hand and blade in front of his neck.
			knife_arm = add_arm("k", knife_strip, north_turf, HV_VIS_KNIFE_OVER_LAYER, vic_turf, HV_VIS_KNIFE_OVER_LAYER)
		else
			// Over both down to the wrist, which lies on his shoulder; the hand goes on round his neck, out of sight.
			knife_arm = add_arm("k", knife_strip, att_turf, HV_VIS_KNIFE_OVER_LAYER, vic_turf, HV_VIS_KNIFE_UNDER_LAYER)
		knife_arm.shoulder = list(15.5 + knife_side * 6.5, 19)
		knife_arm.hang = list(15.5 + knife_side * 6.5, 12.5)
		knife_arm.hint_x = knife_side
		knife_arm.hint_y = 0
		add_blade(knife_file, knife_state, knife_arm, vic_turf, (facing == SOUTH ? HV_VIS_KNIFE_OVER_LAYER : HV_VIS_KNIFE_UNDER_LAYER) + HV_VIS_KNIFE_BLADE_OFFSET)
		var/blade_reach = blade ? blade.reach : 6
		if(facing == SOUTH)
			// The blade lies across the throat from the knife side, its tip on the far edge of the neck.
			blade_hold_angle = knife_side < 0 ? 0 : 180
			blade_after_angle = blade_hold_angle
			knife_arm.hold = list(15.5 - knife_side * 1.5 + knife_side * blade_reach, 20.6)
			knife_arm.after = list(knife_arm.hold[1] + knife_side * 2.8, 20.3)
		else
			blade_hold_angle = arctan(-knife_side * 0.95, 0.3)
			blade_after_angle = blade_hold_angle
			knife_arm.hold = list(15.5 + knife_side * 0.8, 23.5)
			knife_arm.after = list(15.5 + knife_side * 6, 22.5)
			knife_arm.wrist_hold = list(15.5 + knife_side * 5.3, 21.3)
			knife_arm.wrist_after = list(15.5 + knife_side * 8.3, 20.8)

		if(free_arm)
			var/list/free_strip = hv_ke_arm_strip(att_flat, knife_side < 0 ? 21 : 8)
			var/datum/hv_knife_exec_arm/free = add_arm("f", free_strip, facing == SOUTH ? north_turf : att_turf, HV_VIS_KNIFE_OVER_LAYER, facing == SOUTH ? vic_turf : att_turf, HV_VIS_KNIFE_OVER_LAYER)
			free.shoulder = list(15.5 - knife_side * 6.5, 19)
			free.hang = list(15.5 - knife_side * 6.5, 12.5)
			free.hint_x = -knife_side
			free.hint_y = 0
			// On the victim's other shoulder.
			free.hold = facing == SOUTH ? list(15.5 - knife_side * 6, 21) : list(15.5 - knife_side * 5.5, 20.8)
			free.after = free.hold
			add_mask(attacker, att_filters, "hv_knife_arms", 'voidcrew/modules/hyperviolence/overlays_exec/icons/knife_exec_mask_arms.dmi')
		else if(knife_side < 0)
			add_mask(attacker, att_filters, "hv_knife_arms", 'voidcrew/modules/hyperviolence/overlays_exec/icons/knife_exec_mask_arm_l.dmi')
		else
			add_mask(attacker, att_filters, "hv_knife_arms", 'voidcrew/modules/hyperviolence/overlays_exec/icons/knife_exec_mask_arm_r.dmi')

		// The victim's own arm, facing us: the one on the knife's side if that hand is empty, else the other.
		if(facing == SOUTH)
			var/near_zone = knife_side < 0 ? BODY_ZONE_R_ARM : BODY_ZONE_L_ARM
			victim_zones = list(near_zone, near_zone == BODY_ZONE_R_ARM ? BODY_ZONE_L_ARM : BODY_ZONE_R_ARM)
			for(var/zone in victim_zones)
				if(!victim.get_bodypart(zone) || victim.get_item_for_held_index(zone == BODY_ZONE_L_ARM ? 1 : 2))
					continue
				var/side = zone == BODY_ZONE_R_ARM ? -1 : 1
				var/datum/hv_knife_exec_arm/own = add_victim_arm(hv_ke_arm_strip(vic_flat, side < 0 ? 8 : 21))
				own.shoulder = list(15.5 + side * 6.5, 19)
				own.hang = list(15.5 + side * 6.5, 12.5)
				own.hold = side == knife_side ? list(knife_arm.hold[1] - knife_side * 0.3, knife_arm.hold[2] - 2.3) : list(15.5 + side * 2, 19.5)
				own.after = list(15.5 + side * 0.6, 21.2)
				add_mask(victim, vic_filters, "hv_knife_arm", side < 0 ? 'voidcrew/modules/hyperviolence/overlays_exec/icons/knife_exec_mask_arm_l.dmi' : 'voidcrew/modules/hyperviolence/overlays_exec/icons/knife_exec_mask_arm_r.dmi')
				break
	else
		// Side on. Everything below is written for a victim facing east and mirrored for west.
		var/east = facing == EAST
		var/way = east ? 1 : -1
		var/near_zone = east ? BODY_ZONE_R_ARM : BODY_ZONE_L_ARM
		var/near_cut = knife_zone == near_zone
		step_x = way * HV_VIS_KNIFE_STEP_SIDE
		pull_x = -way * HV_VIS_KNIFE_PULL_SIDE
		att_lean = way * HV_VIS_KNIFE_LEAN_ATTACKER
		vic_lean = -way * HV_VIS_KNIFE_LEAN_VICTIM
		jerk_x = way * 1.5
		jerk_lean = way * 3
		hunch_x = way * 2
		hunch_y = -1
		hunch_lean = way * HV_VIS_KNIFE_HUNCH_TILT
		throat = list(mirror(19.3, way), 21.6)
		// Both stand on one row: he is drawn a hair under the man he holds.
		if(attacker.layer == MOB_LAYER)
			att_layer = attacker.layer
			attacker.layer = HV_VIS_KNIFE_ATTACKER_LAYER

		var/list/near_strip = hv_ke_arm_strip(att_flat, east ? 13 : 17)
		if(near_cut)
			// His near arm comes over the victim's shoulder; the blade runs up the side of the neck to the throat.
			var/datum/hv_knife_exec_arm/knife_arm = add_arm("k", near_strip, vic_turf, HV_VIS_KNIFE_OVER_LAYER, vic_turf, HV_VIS_KNIFE_OVER_LAYER)
			knife_arm.shoulder = list(mirror(14, way), 19)
			knife_arm.hang = list(mirror(14, way), 12.5)
			knife_arm.hint_x = -way * 0.3
			add_blade(knife_file, knife_state, knife_arm, vic_turf, HV_VIS_KNIFE_OVER_LAYER + HV_VIS_KNIFE_BLADE_OFFSET)
			var/blade_reach = blade ? blade.reach : 7
			blade_hold_angle = east ? 15 : 165
			blade_after_angle = blade_hold_angle
			var/list/tip = list(mirror(19, way), 21.2)
			knife_arm.hold = list(tip[1] - blade_reach * cos(blade_hold_angle), tip[2] - blade_reach * sin(blade_hold_angle))
			knife_arm.after = list(knife_arm.hold[1] - 3.5 * cos(blade_hold_angle), knife_arm.hold[2] - 3.5 * sin(blade_hold_angle) - 0.5)
			add_patch(attacker, att_flat, east, FALSE)
		else
			// His far arm goes round the far side of the neck, out of sight behind both of them; the hand comes
			// round under the chin and the blade lies back along the throat. His near hand takes the shoulder.
			var/datum/hv_knife_exec_arm/knife_arm = add_arm("k", near_strip, vic_turf, HV_VIS_KNIFE_FAR_LAYER, vic_turf, HV_VIS_KNIFE_FAR_LAYER)
			knife_arm.shoulder = list(mirror(18.5, way), 19)
			knife_arm.hang = list(mirror(19.5, way), 12.5)
			knife_arm.hint_x = -way * 0.3
			add_blade(knife_file, knife_state, knife_arm, vic_turf, HV_VIS_KNIFE_OVER_LAYER + HV_VIS_KNIFE_BLADE_OFFSET)
			blade_hold_angle = east ? 176 : 4
			blade_after_angle = blade_hold_angle
			blade_after_squeeze = 0.15
			blade_slide = 1.3
			blade_release_layer = HV_VIS_KNIFE_FAR_LAYER + HV_VIS_KNIFE_BLADE_OFFSET
			knife_arm.hold = list(mirror(21.4, way), 21.4)
			knife_arm.after = knife_arm.hold
			add_mask(attacker, att_filters, "hv_knife_far", east ? 'voidcrew/modules/hyperviolence/overlays_exec/icons/knife_exec_mask_far_e.dmi' : 'voidcrew/modules/hyperviolence/overlays_exec/icons/knife_exec_mask_far_w.dmi')
			if(free_arm)
				var/datum/hv_knife_exec_arm/free = add_arm("f", near_strip, vic_turf, HV_VIS_KNIFE_OVER_LAYER, vic_turf, HV_VIS_KNIFE_OVER_LAYER)
				free.shoulder = list(mirror(14, way), 19)
				free.hang = list(mirror(14, way), 12.5)
				free.hint_x = -way * 0.3
				free.hold = list(mirror(13.5, way), 19.5)
				free.after = free.hold
				add_patch(attacker, att_flat, east, FALSE)

		// The victim's own near arm.
		if(victim.get_bodypart(near_zone) && !victim.get_item_for_held_index(near_zone == BODY_ZONE_L_ARM ? 1 : 2))
			var/datum/hv_knife_exec_arm/own = add_victim_arm(hv_ke_arm_strip(vic_flat, east ? 13 : 17))
			own.shoulder = list(mirror(14, way), 19)
			own.hang = list(mirror(14, way), 12.5)
			own.hold = list(mirror(18.5, way), 19.6)
			own.after = list(mirror(18.6, way), 21)
			add_patch(victim, vic_flat, east, TRUE)

	// Everything starts as it hangs.
	var/list/rest = snapshot(0, -1)
	for(var/id in arms)
		var/datum/hv_knife_exec_arm/arm = arms[id]
		arm.upper.transform = rest["[id]u"]
		arm.fore.transform = rest["[id]f"]
		arm.hand.transform = rest["[id]h"]
	if(blade)
		blade.transform = rest["blade"]
	return TRUE

/// An x on an icon written for a body facing east, as it is for one facing `way` (1 east, -1 west).
/datum/hv_knife_exec_vis/proc/mirror(x, way)
	return 16 + way * (x - 16)

/// The middle of `place`'s tile in the execution's own pixels (from the corner of the victim's tile).
/datum/hv_knife_exec_vis/proc/tile_centre(turf/place)
	return list((place.x - vic_turf.x) * ICON_SIZE_X + 16, (place.y - vic_turf.y) * ICON_SIZE_Y + 16)

/// Builds one of the attacker's arms from `strip`: upper arm and forearm on `arm_turf`, the hand on `hand_turf`.
/datum/hv_knife_exec_vis/proc/add_arm(id, list/strip, turf/arm_turf, arm_layer, turf/hand_turf, hand_layer)
	var/datum/hv_knife_exec_arm/arm = new
	arm.id = id
	arm.upper = new(arm_turf, hv_ke_strip_dots(strip, list(20, 19, 18, 17, 16)), 1, HV_VIS_KNIFE_UPPER_ARM, arm_layer)
	arm.fore = new(arm_turf, hv_ke_strip_dots(strip, list(16, 15, 14)), 0.5, HV_VIS_KNIFE_FOREARM - 0.5, arm_layer)
	arm.hand = new(hand_turf, hv_ke_strip_dots(strip, list(14, 13, 12, 11)), 1.5, 1, hand_layer)
	for(var/obj/effect/abstract/hv_knife_exec_part/part as anything in list(arm.upper, arm.fore, arm.hand))
		var/list/centre = tile_centre(part.loc)
		part.centre_x = centre[1]
		part.centre_y = centre[2]
	arms[id] = arm
	return arm

/// Builds the victim's own arm from `strip`, on his tile, just over him and under the attacker's hands. (Pieces in
/// his vis_contents would not follow a named animation of his transform.)
/datum/hv_knife_exec_vis/proc/add_victim_arm(list/strip)
	var/datum/hv_knife_exec_arm/arm = add_arm("v", strip, get_turf(victim), HV_VIS_KNIFE_VICTIM_ARM_LAYER, get_turf(victim), HV_VIS_KNIFE_VICTIM_ARM_LAYER)
	arm.on_victim = TRUE
	return arm

/// The held knife's picture, carried by `arm`'s hand.
/datum/hv_knife_exec_vis/proc/add_blade(knife_file, knife_state, datum/hv_knife_exec_arm/arm, turf/place, draw_layer)
	if(!knife_file || !knife_state)
		return
	// tg draws a held thing around the hand of the arm's own sprite: the near hand side on, else the hanging fist.
	var/list/held_at = arm.hang
	if(facing == EAST || facing == WEST)
		var/way = facing == EAST ? 1 : -1
		var/near_zone = facing == EAST ? BODY_ZONE_R_ARM : BODY_ZONE_L_ARM
		if(attacker.get_hand_zone_of_item(knife) != near_zone)
			held_at = list(mirror(20.5, way), 12.5)
	var/list/tip = hv_ke_blade_tip(knife_file, knife_state, facing, held_at[1], held_at[2])
	if(!tip)
		return
	blade = new(place, null, 0, 1, draw_layer)
	blade.icon = knife_file
	blade.icon_state = knife_state
	blade.setDir(facing)
	blade.color = knife.color
	// The picture is carried by the fist: where the fist hangs is where its own hand is.
	blade.hand_x = arm.hang[1]
	blade.hand_y = arm.hang[2]
	blade.tip_x = tip[1]
	blade.tip_y = tip[2]
	blade.native_angle = arctan(tip[1] - arm.hang[1], tip[2] - arm.hang[2])
	blade.reach = sqrt((tip[1] - arm.hang[1]) ** 2 + (tip[2] - arm.hang[2]) ** 2)
	var/list/centre = tile_centre(place)
	blade.centre_x = centre[1]
	blade.centre_y = centre[2]

/// Cuts a hanging arm out of `body`'s picture with the mask `mask_file`.
/datum/hv_knife_exec_vis/proc/add_mask(mob/living/body, list/names, name, mask_file)
	body.add_filter(name, 30, alpha_mask_filter(icon = mask_file, flags = MASK_INVERSE))
	names |= name

/// Side on, the near arm hangs over the body: covers it with the body's own chest, four pixels further forward.
/datum/hv_knife_exec_vis/proc/add_patch(mob/living/carbon/human/body, icon/flat, east, on_victim)
	if(on_victim ? vic_patch : att_patch)
		return
	var/first_col = east ? 13 : 17
	var/shift = east ? 4 : -4
	var/mutable_appearance/patch = mutable_appearance(layer = -(SUIT_LAYER - 0.5))
	for(var/row in 11 to 19)
		for(var/col in first_col to first_col + 3)
			if(isnull(flat.GetPixel(col, row)))
				continue
			var/colour = flat.GetPixel(col + shift, row)
			if(isnull(colour))
				continue
			var/mutable_appearance/dot = mutable_appearance(HV_VIS_KNIFE_PX, "px", FLOAT_LAYER)
			dot.pixel_w = col - 1
			dot.pixel_z = row - 1
			dot.color = colour
			patch.overlays += dot
	body.add_overlay(patch)
	if(on_victim)
		vic_patch = patch
	else
		att_patch = patch

// ---- Poses ----

/// The attacker's pose `since` deciseconds in, `after` deciseconds after the cut (-1 before it): list(x, y, lean).
/datum/hv_knife_exec_vis/proc/attacker_pose(since, after)
	var/weight = hv_ke_ease_out(since / HV_VIS_KNIFE_STEP_TIME)
	if(after >= 0)
		weight *= 1 - hv_ke_smooth((after - HV_VIS_KNIFE_CUT_TIME - HV_VIS_KNIFE_CUT_HOLD) / HV_VIS_KNIFE_RELEASE_TIME)
	return list(step_x * weight, step_y * weight, att_lean * weight)

/// How hard the victim is jerking against the hold `since` deciseconds in: -1 to 1.
/datum/hv_knife_exec_vis/proc/jerk(since)
	var/static/list/jerks = list(6, 8, 10.5, 12.5)
	for(var/i in 1 to length(jerks))
		var/into = since - jerks[i]
		if(into <= 0 || into >= 1.5)
			continue
		var/size = into < 0.5 ? into / 0.5 : 1 - (into - 0.5)
		return (i % 2) ? size : -size
	return 0

/// The victim's pose: list(x, y, lean).
/datum/hv_knife_exec_vis/proc/victim_pose(since, after)
	var/weight = hv_ke_ease_out((since - HV_VIS_KNIFE_PULL_START) / HV_VIS_KNIFE_PULL_TIME)
	var/let_go = HV_VIS_KNIFE_CUT_TIME + HV_VIS_KNIFE_CUT_HOLD
	if(after >= 0 && !victim_held)
		weight *= 1 - hv_ke_smooth((after - let_go) / HV_VIS_KNIFE_VICTIM_BACK_TIME)
	var/list/pose = list(pull_x * weight, pull_y * weight, vic_lean * weight)
	if(after < 0)
		var/struggle = jerk(since)
		pose[1] += jerk_x * struggle
		pose[2] += jerk_y * struggle
		pose[3] += jerk_lean * struggle
	else if(victim_hunches)
		var/bent = hv_ke_smooth((after - let_go) / HV_VIS_KNIFE_CLUTCH_IN) * (1 - hv_ke_smooth((after - HV_VIS_KNIFE_HUNCH_END) / HV_VIS_KNIFE_HUNCH_OUT))
		pose[1] += hunch_x * bent
		pose[2] += hunch_y * bent
		pose[3] += hunch_lean * bent
	return pose

/// Every transform of the move `since` deciseconds in and `after` deciseconds after the cut (-1 before it): "A" and
/// "V" the bodies, "[arm id]u", "[arm id]f" and "[arm id]h" each arm's pieces, "blade" the knife.
/datum/hv_knife_exec_vis/proc/snapshot(since, after)
	var/list/snap = list()
	var/list/att_pose = attacker_pose(since, after)
	var/list/vic_pose = victim_pose(since, after)
	var/matrix/att_matrix = hv_ke_body_matrix(att_base, att_pose)
	var/matrix/vic_matrix = hv_ke_body_matrix(vic_base, vic_pose)
	snap["A"] = att_matrix
	snap["V"] = vic_matrix
	var/let_go = HV_VIS_KNIFE_CUT_TIME + HV_VIS_KNIFE_CUT_HOLD
	var/through = 0
	var/held = hv_ke_smooth((since - HV_VIS_KNIFE_REACH_START) / HV_VIS_KNIFE_REACH_TIME)
	if(after >= 0)
		through = hv_ke_smooth(after / HV_VIS_KNIFE_CUT_TIME)
		held *= 1 - hv_ke_smooth((after - let_go) / HV_VIS_KNIFE_RELEASE_TIME)
	for(var/id in arms)
		var/datum/hv_knife_exec_arm/arm = arms[id]
		if(arm.on_victim)
			// His own arm: up at the knife hand, then to his throat, then down.
			var/list/goal = arm.hold
			var/up = hv_ke_smooth((since - HV_VIS_KNIFE_GUARD_START) / HV_VIS_KNIFE_GUARD_TIME)
			if(after >= 0)
				if(victim_hunches)
					goal = hv_ke_mix(arm.hold, arm.after, hv_ke_smooth((after - let_go) / HV_VIS_KNIFE_CLUTCH_IN))
					up = 1 - hv_ke_smooth((after - HV_VIS_KNIFE_CLUTCH_END) / HV_VIS_KNIFE_CLUTCH_OUT)
				else
					up *= 1 - hv_ke_smooth((after - let_go) / HV_VIS_KNIFE_VICTIM_BACK_TIME)
			var/list/own_fist = hv_ke_body_point(vic_origin, vic_matrix, hv_ke_mix(arm.hang, goal, up))
			place_arm(arm, snap, hv_ke_body_point(vic_origin, vic_matrix, arm.shoulder), own_fist, null)
			continue
		var/list/shoulder = hv_ke_body_point(att_origin, att_matrix, arm.shoulder)
		var/list/hang = hv_ke_body_point(att_origin, att_matrix, arm.hang)
		var/list/target = hv_ke_body_point(vic_origin, vic_matrix, hv_ke_mix(arm.hold, arm.after, through))
		var/list/wrist
		if(arm.wrist_hold)
			var/list/wrist_target = hv_ke_body_point(vic_origin, vic_matrix, hv_ke_mix(arm.wrist_hold, arm.wrist_after, through))
			wrist = hv_ke_mix(list(hang[1], hang[2] + 0.5), wrist_target, held)
		var/list/fist = place_arm(arm, snap, shoulder, hv_ke_mix(hang, target, held), wrist)
		if(id == "k" && blade)
			// As he holds it at his side, turning with his hand to lie on the throat.
			var/from_angle = blade.native_angle - att_pose[3]
			var/to_angle = blade_hold_angle + (blade_after_angle - blade_hold_angle) * through - vic_pose[3]
			var/angle = from_angle + hv_ke_turn(from_angle, to_angle) * held
			var/squeeze = 1 - (1 - blade_after_squeeze) * through * held
			var/list/held_at = fist
			if(blade_slide)
				held_at = list(fist[1] - blade_slide * held * cos(angle), fist[2] - blade_slide * held * sin(angle))
			snap["blade"] = blade.hold(held_at, angle - blade.native_angle, squeeze)
	return snap

/// Works out one arm from `shoulder` to `fist` (through `wrist`, if given) and writes its pieces' transforms into
/// `snap`. An arm never stretches past HV_VIS_KNIFE_ARM_STRETCH: the hand stops short instead. Returns the fist.
/datum/hv_knife_exec_vis/proc/place_arm(datum/hv_knife_exec_arm/arm, list/snap, list/shoulder, list/fist, list/wrist)
	var/list/end = wrist || fist
	var/fore_length = wrist ? HV_VIS_KNIFE_FOREARM - 0.5 : HV_VIS_KNIFE_FOREARM
	var/longest = (HV_VIS_KNIFE_UPPER_ARM + fore_length) * HV_VIS_KNIFE_ARM_STRETCH
	var/dx = end[1] - shoulder[1]
	var/dy = end[2] - shoulder[2]
	var/reach = sqrt(dx * dx + dy * dy)
	if(reach > longest)
		var/short_x = dx * (longest / reach - 1)
		var/short_y = dy * (longest / reach - 1)
		end = list(end[1] + short_x, end[2] + short_y)
		fist = wrist ? list(fist[1] + short_x, fist[2] + short_y) : end
	var/list/elbow = hv_ke_elbow(shoulder, end, HV_VIS_KNIFE_UPPER_ARM, fore_length, arm.hint_x, arm.hint_y)
	var/fore_x = end[1] - elbow[1]
	var/fore_y = end[2] - elbow[2]
	var/fore_angle = (abs(fore_x) + abs(fore_y) < 0.01) ? -90 : arctan(fore_x, fore_y)
	var/list/wrist_at
	var/hand_angle = fore_angle
	if(wrist)
		wrist_at = end
		var/hand_x = fist[1] - end[1]
		var/hand_y = fist[2] - end[2]
		if(hand_x * hand_x + hand_y * hand_y > 0.09)
			hand_angle = arctan(hand_x, hand_y)
	else
		wrist_at = list(fist[1] - 0.5 * cos(fore_angle), fist[2] - 0.5 * sin(fore_angle))
	snap["[arm.id]u"] = arm.upper.span(shoulder, elbow)
	snap["[arm.id]f"] = arm.fore.span(elbow, wrist_at)
	snap["[arm.id]h"] = arm.hand.pin(fist, hand_angle)
	return fist

/// Where the blood starts: the throat as he is held, pixels from the middle of his tile.
/datum/hv_knife_exec_vis/proc/throat_spot()
	var/list/spot = hv_ke_body_point(vic_origin, hv_ke_body_matrix(vic_base, victim_pose(HV_KNIFE_EXECUTION_WINDUP, -1)), throat)
	return list(spot[1] - 16, spot[2] - 16)

// ---- Playing ----

/// Keys for play(): each list(deciseconds since the key before, since, after).
/datum/hv_knife_exec_vis/proc/keys_at(list/moments, after_cut)
	var/list/keys = list()
	var/last = moments[1]
	for(var/moment in moments)
		if(after_cut)
			keys[++keys.len] = list(moment - last, HV_KNIFE_EXECUTION_WINDUP, moment)
		else
			keys[++keys.len] = list(moment - last, moment, -1)
		last = moment
	return keys

/// The wind-up: the grab, then the hold with the victim's jerks, then (should the cut never come) everything back.
/// The hold is kept well past the wind-up: on a lagging server the cut comes late by a client's clock.
/datum/hv_knife_exec_vis/proc/windup_keys()
	var/list/keys = keys_at(list(0, 0.5, 1, 1.5, 2, 2.5, 3, 3.5, 4, 4.5, 5, 6, 6.5, 7.5, 8, 8.5, 9.5, 10.5, 11, 12, 12.5, 13, 14, HV_KNIFE_EXECUTION_WINDUP + 3 SECONDS), FALSE)
	keys[++keys.len] = list(HV_VIS_KNIFE_ABORT_TIME, 0, -1)
	return keys

/// Tweens everything through `keys`, in step: each body and piece gets the same moments with straight-line steps
/// between them, so what holds what stays together in every frame.
/datum/hv_knife_exec_vis/proc/play(list/keys, attacker_side = TRUE, victim_side = TRUE)
	var/list/snaps = list()
	for(var/list/key as anything in keys)
		snaps[++snaps.len] = snapshot(key[2], key[3])
	if(attacker_side && !attacker_done)
		play_on(attacker, "A", keys, snaps, att_base)
		for(var/id in arms)
			var/datum/hv_knife_exec_arm/arm = arms[id]
			if(arm.on_victim)
				continue
			play_on(arm.upper, "[id]u", keys, snaps)
			play_on(arm.fore, "[id]f", keys, snaps)
			play_on(arm.hand, "[id]h", keys, snaps)
		if(blade)
			play_on(blade, "blade", keys, snaps)
	if(victim_side && !victim_done)
		if(!victim_held)
			play_on(victim, "V", keys, snaps, vic_base)
		var/datum/hv_knife_exec_arm/own = arms["v"]
		if(own)
			play_on(own.upper, "vu", keys, snaps)
			play_on(own.fore, "vf", keys, snaps)
			play_on(own.hand, "vh", keys, snaps)

/// One thing's tween through `keys`, on its plain animation sequence. A body's ends on `rest`, its real transform.
/datum/hv_knife_exec_vis/proc/play_on(atom/movable/thing, name, list/keys, list/snaps, matrix/rest)
	if(QDELETED(thing))
		return
	for(var/i in 1 to length(keys))
		var/list/key = keys[i]
		var/list/snap = snaps[i]
		var/matrix/pose = snap[name]
		if(i > 1)
			animate(transform = pose, time = key[1], flags = ANIMATION_LINEAR_TRANSFORM)
		else
			animate(thing, transform = pose, time = key[1], flags = ANIMATION_LINEAR_TRANSFORM)
	if(rest)
		animate(transform = rest, time = 0)

/// Puts a body straight back on its real transform, whatever part of the move it was in.
/datum/hv_knife_exec_vis/proc/settle(mob/living/body)
	if(!QDELETED(body))
		animate(body, transform = matrix(body.transform), time = 1)

// ---- The cut, the let-go, the ends ----

/// The cut landed. `was_standing`, `pre_pixel_y` and `pre_base` are the victim as he stood just before it.
/datum/hv_knife_exec_vis/proc/cut(was_standing, pre_pixel_y, matrix/pre_base)
	if(cut_time >= 0 || attacker_done)
		return
	cut_time = world.time
	var/let_go = HV_VIS_KNIFE_CUT_TIME + HV_VIS_KNIFE_CUT_HOLD
	var/on_his_feet = !QDELETED(victim) && victim.stat != DEAD && victim.body_position == STANDING_UP && victim.dir == facing
	if(on_his_feet && !victim_done)
		victim_hunches = TRUE
	else
		// He is going down (tg's fall) or already gone: his arm drops, and he is drawn held up until the blade is through.
		victim_held = TRUE
		end_victim_arm()
		if(!QDELETED(victim))
			if(was_standing && victim.body_position == LYING_DOWN && victim.hv_vis_can_hold_fall())
				var/matrix/held_up = hv_ke_body_matrix(pre_base, victim_pose(HV_KNIFE_EXECUTION_WINDUP, -1))
				victim.hv_vis_play_over(list(
					list(pre_pixel_y, held_up, 0, LINEAR_EASING),
					list(pre_pixel_y, held_up, let_go, LINEAR_EASING),
					list(victim.pixel_y, matrix(victim.transform), 3, QUAD_EASING|EASE_IN),
				))
			else
				settle(victim)
		victim_done = TRUE

	var/list/attacker_moments = list(0, 0.5, 1, 1.5, 2, 2.5, let_go)
	for(var/i in 1 to 6)
		attacker_moments += let_go + i * HV_VIS_KNIFE_RELEASE_TIME / 6
	play(keys_at(attacker_moments, TRUE), TRUE, FALSE)
	addtimer(CALLBACK(src, PROC_REF(end_attacker)), let_go + HV_VIS_KNIFE_RELEASE_TIME, TIMER_DELETE_ME)
	if(blade && !isnull(blade_release_layer))
		addtimer(VARSET_CALLBACK(blade, layer, blade_release_layer), let_go, TIMER_DELETE_ME)

	if(victim_hunches)
		var/list/victim_moments = list(0, 0.5, 1, 1.5, 2, 2.5, let_go)
		for(var/i in 1 to 6)
			victim_moments += let_go + i * 0.5
		for(var/i in 0 to 4)
			victim_moments += HV_VIS_KNIFE_HUNCH_END + i * HV_VIS_KNIFE_HUNCH_OUT / 4
		for(var/i in 0 to 4)
			victim_moments += HV_VIS_KNIFE_CLUTCH_END + i * HV_VIS_KNIFE_CLUTCH_OUT / 4
		play(keys_at(victim_moments, TRUE), FALSE, TRUE)
		addtimer(CALLBACK(src, PROC_REF(end_victim)), HV_VIS_KNIFE_CLUTCH_END + HV_VIS_KNIFE_CLUTCH_OUT, TIMER_DELETE_ME)

/// The wind-up broke: everything eases back from where it has got to.
/datum/hv_knife_exec_vis/proc/abort()
	if(cut_time >= 0 || aborting)
		return
	aborting = TRUE
	if(attacker_done && victim_done)
		qdel(src)
		return
	var/since = min(world.time - started, HV_KNIFE_EXECUTION_WINDUP)
	if(QDELETED(victim) || victim.body_position != STANDING_UP)
		// He is gone or going down: tg has his transform now.
		end_victim_arm()
		victim_done = TRUE
	else if(victim.dir != facing || get_turf(victim) != vic_turf)
		// His own stand-in arm was drawn for the way he faced, where he stood.
		end_victim_arm()
	var/list/keys = list(list(0, since, -1), list(HV_VIS_KNIFE_ABORT_TIME, 0, -1))
	play(keys)
	QDEL_IN(src, HV_VIS_KNIFE_ABORT_TIME)

/// The attacker's arms, knife and step are over: his real arms and held knife show again.
/datum/hv_knife_exec_vis/proc/end_attacker(at_once = FALSE)
	if(attacker_done)
		return
	attacker_done = TRUE
	for(var/id in arms)
		var/datum/hv_knife_exec_arm/arm = arms[id]
		if(arm.on_victim)
			continue
		arms -= id
		qdel(arm)
	QDEL_NULL(blade)
	if(!QDELETED(attacker))
		for(var/name in att_filters)
			attacker.remove_filter(name)
		if(att_patch)
			attacker.cut_overlay(att_patch)
		if(!isnull(att_layer) && attacker.layer == HV_VIS_KNIFE_ATTACKER_LAYER)
			attacker.layer = attacker.body_position == LYING_DOWN ? LYING_MOB_LAYER : att_layer
		if(at_once)
			settle(attacker)
	att_filters = list()
	att_patch = null
	att_layer = null
	if(knife && !QDELETED(knife))
		knife.hv_vis_restore_held_sprite()
	if(victim_done && !QDELETED(src) && !at_once)
		qdel(src)

/// The victim's own stand-in arm goes; his real one shows again.
/datum/hv_knife_exec_vis/proc/end_victim_arm()
	var/datum/hv_knife_exec_arm/own = arms["v"]
	if(own)
		arms -= "v"
		qdel(own)
	if(!QDELETED(victim))
		for(var/name in vic_filters)
			victim.remove_filter(name)
		if(vic_patch)
			victim.cut_overlay(vic_patch)
	vic_filters = list()
	vic_patch = null

/// The victim's side is over.
/datum/hv_knife_exec_vis/proc/end_victim(at_once = FALSE)
	if(victim_done)
		return
	victim_done = TRUE
	end_victim_arm()
	if(at_once && !victim_held)
		settle(victim)
	if(attacker_done && !QDELETED(src) && !at_once)
		qdel(src)

// ---- Blood ----

/// A short jet of blood off the front of the neck, the way the victim faces.
/obj/effect/temp_visual/hv_throat_spurt
	name = "arterial spray"
	icon = HV_BLOOD_SPRAY_ICON
	icon_state = "squirt_greyscale"
	plane = GAME_PLANE
	layer = ABOVE_MOB_LAYER
	randomdir = FALSE
	duration = 4

/obj/effect/temp_visual/hv_throat_spurt/Initialize(mapload, throat_w = 0, throat_z = 0, spray_dir = SOUTH, blood_color = BLOOD_COLOR_RED, strength = 2)
	. = ..()
	setDir(spray_dir || SOUTH)
	color = blood_color
	var/dx = HV_VIS_DX(dir)
	var/dy = HV_VIS_DY(dir)
	var/start_reach = 2
	var/end_reach = (dir & SOUTH) ? (2 + strength) : (3 + strength)
	var/matrix/start = matrix()
	start.Scale(0.14, 0.14)
	start.Translate(throat_w + dx * start_reach, throat_z + dy * start_reach)
	transform = start
	var/matrix/end_mat = matrix()
	end_mat.Scale(0.18 + strength * 0.03, 0.18 + strength * 0.03)
	end_mat.Translate(throat_w + dx * end_reach, throat_z + dy * end_reach)
	animate(src, transform = end_mat, alpha = 0, time = duration, easing = QUAD_EASING|EASE_OUT)
