// Package: P1 bolt. The melt-off picture. The arm or leg comes off at once through tg's WOUND_BURN loss (state,
// damage, ash decal all as tg does them); the picture lags behind it. A copy of the limb as it was drawn on the
// body plays the melt on the body (glow, sag, forearm drops, gone), and tg's ash decal shows under it as the forearm lands.
// The copy is built from the limb's own cached overlays, so it sits exactly where the limb was in every facing,
// standing or lying, and takes the body's turn when the victim falls.
// Blocking build: key poses only, no drips, pool, steam or light yet.

/// When each key pose starts, from the hit
#define PLASMA_MELT_SAG (0.3 SECONDS)
#define PLASMA_MELT_SAG_FULL (0.6 SECONDS)
#define PLASMA_MELT_DROP (0.9 SECONDS)
#define PLASMA_MELT_GONE (1.4 SECONDS)
#define PLASMA_MELT_COOLED (3 SECONDS)

/// Icon rows (from the bottom, 1-32) at and below which a limb counts as its lower half: forearm and hand, shin and foot
#define PLASMA_MELT_ARM_JOINT 16
#define PLASMA_MELT_LEG_JOINT 6

/// Additive tint on the glowing limb
#define PLASMA_MELT_GLOW_COLOR "#3ccf78"

/// Limb centre in pixels from the sprite's centre (x right, y up) per facing, for the human body shape.
/// Measured from bodyparts_greyscale.dmi (limb plus hand). Places the ash under the limb.
GLOBAL_LIST_INIT(plasma_melt_anchor, list(
	BODY_ZONE_R_ARM = list("1" = list(6, -1), "2" = list(-7, -1), "4" = list(-3, -2), "8" = list(-5, -4)),
	BODY_ZONE_L_ARM = list("1" = list(-7, -1), "2" = list(6, -1), "4" = list(5, -4), "8" = list(3, -2)),
	BODY_ZONE_R_LEG = list("1" = list(2, -12), "2" = list(-3, -12), "4" = list(0, -11), "8" = list(0, -12)),
	BODY_ZONE_L_LEG = list("1" = list(-3, -12), "2" = list(2, -12), "4" = list(0, -12), "8" = list(0, -11)),
))

/// Cropped halves of limb icons, by icon, state and half
GLOBAL_LIST_EMPTY(plasma_melt_halves)

/// Melts `limb` off its owner through tg's burn loss and plays the melt over the body. Returns TRUE if it came off.
/proc/plasma_melt_limb(obj/item/bodypart/limb, attack_direction)
	var/mob/living/carbon/victim = limb?.owner
	if(!victim)
		return FALSE
	var/zone = limb.body_zone
	var/list/drawn = plasma_melt_capture(victim, limb)
	var/turf/where = get_turf(victim)
	var/list/old_ash = list()
	for(var/obj/effect/decal/cleanable/ash/pile in where)
		old_ash += pile
	var/datum/wound/loss/melt = new
	melt.apply_dismember(limb, WOUND_BURN, FALSE, attack_direction)
	if(QDELETED(victim) || victim.get_bodypart(zone) == limb)
		return FALSE
	var/obj/effect/decal/cleanable/ash/new_ash
	for(var/obj/effect/decal/cleanable/ash/pile in where)
		if(!(pile in old_ash))
			new_ash = pile
			break
	if(length(drawn))
		new /datum/plasma_melt(victim, zone, drawn, new_ash)
	return TRUE

/// The limb's overlays exactly as the body draws them now (leg layer masks included, emissive blockers left out)
/proc/plasma_melt_capture(mob/living/carbon/victim, obj/item/bodypart/limb)
	var/list/source = victim.limb_icon_cache?[victim.icon_render_keys?[limb.body_zone]]
	if(!length(source))
		source = limb.get_limb_icon(dropped = FALSE, update_on = victim)
	. = list()
	for(var/image/piece in source)
		if(piece.plane != FLOAT_PLANE)
			continue
		. += new /mutable_appearance(piece)

/datum/plasma_melt
	var/datum/weakref/victim_ref
	var/zone
	/// The limb as it was drawn, captured before it came off
	var/list/drawn
	/// What this melt has on the body right now
	var/list/shown = list()
	var/datum/weakref/ash_ref

/datum/plasma_melt/New(mob/living/carbon/victim, zone, list/drawn, obj/effect/decal/cleanable/ash/ash)
	victim_ref = WEAKREF(victim)
	src.zone = zone
	src.drawn = drawn
	if(ash)
		ash_ref = WEAKREF(ash)
		ash.alpha = 0
	pose_glow()
	addtimer(CALLBACK(src, PROC_REF(pose_sag), 1), PLASMA_MELT_SAG)
	addtimer(CALLBACK(src, PROC_REF(pose_sag), 3), PLASMA_MELT_SAG_FULL)
	addtimer(CALLBACK(src, PROC_REF(pose_drop), 1), PLASMA_MELT_DROP)
	addtimer(CALLBACK(src, PROC_REF(pose_drop), 2), PLASMA_MELT_DROP + 0.15 SECONDS)
	addtimer(CALLBACK(src, PROC_REF(pose_drop), 3), PLASMA_MELT_DROP + 0.3 SECONDS)
	addtimer(CALLBACK(src, PROC_REF(pose_gone)), PLASMA_MELT_GONE)
	addtimer(CALLBACK(src, PROC_REF(pose_cooled)), PLASMA_MELT_COOLED)

/datum/plasma_melt/Destroy()
	show(list())
	var/obj/effect/decal/cleanable/ash/ash = ash_ref?.resolve()
	if(ash)
		ash.alpha = 255
	return ..()

/// Swaps what the melt draws on the body
/datum/plasma_melt/proc/show(list/pieces)
	var/mob/living/carbon/victim = victim_ref?.resolve()
	if(victim)
		victim.cut_overlay(shown)
		victim.add_overlay(pieces)
	shown = pieces

/datum/plasma_melt/proc/is_arm()
	return zone == BODY_ZONE_R_ARM || zone == BODY_ZONE_L_ARM

/// The limb is on the side of the body away from the viewer, so pieces that move draw behind the body
/datum/plasma_melt/proc/is_far(mob/living/carbon/victim)
	if(victim.body_position == LYING_DOWN)
		return FALSE
	var/left = (zone == BODY_ZONE_L_ARM || zone == BODY_ZONE_L_LEG)
	return (victim.dir == EAST && left) || (victim.dir == WEST && !left)

/// One captured piece, whole or one half, pixel-shifted along the limb (y, local to the body) and optionally glowing
/datum/plasma_melt/proc/piece(mutable_appearance/source, half, shift = 0, glow = FALSE, behind = FALSE)
	var/mutable_appearance/copy = new(source)
	if(half)
		var/list/cut = plasma_melt_half(source.icon, source.icon_state, half, is_arm() ? PLASMA_MELT_ARM_JOINT : PLASMA_MELT_LEG_JOINT)
		copy.icon = cut[1]
		copy.icon_state = cut[2]
	copy.pixel_y += shift
	if(behind)
		copy.layer = -BODY_BEHIND_LAYER
	. = list(copy)
	if(glow)
		var/mutable_appearance/hot = new(copy)
		hot.color = PLASMA_MELT_GLOW_COLOR
		hot.blend_mode = BLEND_ADD
		. += hot

/// Pose 1: the whole limb glows
/datum/plasma_melt/proc/pose_glow()
	var/list/pieces = list()
	for(var/mutable_appearance/source as anything in drawn)
		pieces += piece(source, null, 0, TRUE)
	show(pieces)

/// Pose 2: the lower half sags `amount` px out of the upper half, stretched over the gap
/datum/plasma_melt/proc/pose_sag(amount)
	var/list/pieces = list()
	for(var/mutable_appearance/source as anything in drawn)
		pieces += piece(source, "upper", 0, TRUE)
		for(var/step in 0 to amount)
			pieces += piece(source, "lower", -step, TRUE)
	show(pieces)

/// Pose 3: the lower half comes away and falls; the upper half still glows. Standing, it falls to the floor;
/// lying, it slides out along the limb. A far limb's falling half draws behind the body.
/datum/plasma_melt/proc/pose_drop(stage)
	var/mob/living/carbon/victim = victim_ref?.resolve()
	if(!victim)
		return
	var/fall
	if(victim.body_position == LYING_DOWN)
		fall = 3 + stage
	else if(is_arm())
		fall = list(5, 8, 11)[stage]
	else
		fall = list(4, 5, 6)[stage]
	var/behind = is_far(victim)
	var/list/pieces = list()
	for(var/mutable_appearance/source as anything in drawn)
		pieces += piece(source, "upper", 0, TRUE)
		pieces += piece(source, "lower", -fall, TRUE, behind)
	show(pieces)
	if(stage == 3)
		place_ash(victim)

/// Pose 4: the limb is gone; tg draws no stump
/datum/plasma_melt/proc/pose_gone()
	show(list())

/// Pose 5: the melt is over (the ash already landed with the forearm)
/datum/plasma_melt/proc/pose_cooled()
	qdel(src)

/// Moves tg's ash decal under the limb, from the limb's place on the body for the victim's facing and turn
/datum/plasma_melt/proc/place_ash(mob/living/carbon/victim)
	var/obj/effect/decal/cleanable/ash/ash = ash_ref?.resolve()
	if(!ash)
		return
	// the ash lands with the falling forearm, not after the cool-down
	animate(ash, alpha = 255, time = 0.1 SECONDS)
	if(ash.loc != get_turf(victim))
		return
	var/list/anchor = GLOB.plasma_melt_anchor[zone]?["[victim.dir]"]
	if(!anchor)
		return
	var/x = anchor[1]
	var/y = anchor[2]
	var/matrix/turn = victim.transform
	var/screen_x = turn.a * x + turn.b * y + turn.c
	var/screen_y = turn.d * x + turn.e * y + turn.f
	if(victim.body_position != LYING_DOWN)
		screen_y = -13 // by the feet
	// the ash sprite's pile sits 6 px below its centre
	ash.pixel_x = round(screen_x + victim.pixel_x + victim.pixel_w)
	ash.pixel_y = round(screen_y + 6 + victim.pixel_y + victim.pixel_z)

/// One half of a limb icon: "upper" keeps the rows above `joint`, "lower" keeps `joint` and below.
/// Returns list(icon, its state name).
/proc/plasma_melt_half(icon_source, icon_state, half, joint)
	var/key = "[isfile(icon_source) ? icon_source : REF(icon_source)]|[icon_state]|[half]|[joint]"
	if(GLOB.plasma_melt_halves[key])
		return GLOB.plasma_melt_halves[key]
	var/icon/cut = icon(icon_source, icon_state)
	if(half == "upper")
		cut.DrawBox(null, 1, 1, ICON_SIZE_X, joint)
	else
		cut.DrawBox(null, 1, joint + 1, ICON_SIZE_X, ICON_SIZE_Y)
	var/list/states = icon_states(cut)
	. = list(cut, length(states) ? states[1] : "")
	GLOB.plasma_melt_halves[key] = .

#undef PLASMA_MELT_SAG
#undef PLASMA_MELT_SAG_FULL
#undef PLASMA_MELT_DROP
#undef PLASMA_MELT_GONE
#undef PLASMA_MELT_COOLED
#undef PLASMA_MELT_ARM_JOINT
#undef PLASMA_MELT_LEG_JOINT
#undef PLASMA_MELT_GLOW_COLOR
