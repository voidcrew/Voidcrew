// Package: P9 pinch. The barrel pinch when a plasma gun fires.
//
// Blocking build: the key poses only. A ball swells at the barrel and snaps small, the bolt leaves, and
// a ring opens where the ball was. No hand flash, no light and no timing polish yet.
//
// Placement is a local table of pixel offsets by facing, read off the wielded in-hand sprite. The
// pieces ride the shooter's vis_contents, so they stay at the barrel if the shooter moves or is turned
// over. When gun_feel's barrel placement is on master this table gives way to it.

/// When the ball snaps small. The bolt shows and the ring opens from here
#define PLASMA_PINCH_SNAP_TIME (0.1 SECONDS)
/// How long the ring takes to open and fade
#define PLASMA_PINCH_RING_TIME (0.2 SECONDS)
/// Layer of a bolt while it leaves the pinch, just over the ball and ring
#define PLASMA_PINCH_BOLT_LAYER (ABOVE_MOB_LAYER + 0.01)

/obj/item/gun/energy/plasma_weapon
	/// Where the pinch sits on the shooter, as "[dir]" = list(pixel_x, pixel_y). Null for a gun with no pinch
	var/list/pinch_offsets

// The Furnace's emitter is the green tip of its wielded in-hand sprite: the east and west sprites end
// at (32, 17) and (1, 17) in icon pixels. Facing north or south the rifle lies across the body, so
// the ball forms on the bolt's path in front of the chest instead (design decision 5).
/obj/item/gun/energy/plasma_weapon/rifle
	pinch_offsets = list(
		"1" = list(0, 1),
		"2" = list(0, 1),
		"4" = list(15, 1),
		"8" = list(-16, 1),
	)

/// The plasma ball and ring at the barrel as `user` fires at `target`
/obj/item/gun/energy/plasma_weapon/proc/plasma_pinch(mob/living/user, atom/target)
	if(!pinch_offsets || !istype(user) || loc != user || !isturf(user.loc))
		return
	var/list/offset = pinch_offsets["[user.dir]"]
	if(!offset)
		return
	// Shooting away from the viewer, the muzzle is on the far side of the body
	var/pinch_layer = user.dir == NORTH ? BELOW_MOB_LAYER : ABOVE_MOB_LAYER
	new /obj/effect/temp_visual/plasma_pinch(null, user, offset[1], offset[2], pinch_layer)

/obj/effect/temp_visual/plasma_pinch
	name = "plasma"
	// Its "pinch" state (set with the type in plasma_types.dm) holds the whole move, ball, snap and ring, so the
	// timing is the client's and can't slip a tick
	duration = PLASMA_PINCH_SNAP_TIME + PLASMA_PINCH_RING_TIME
	randomdir = FALSE
	appearance_flags = KEEP_APART | RESET_COLOR | TILE_BOUND | PIXEL_SCALE
	vis_flags = VIS_INHERIT_PLANE
	/// Who we are drawn on
	var/atom/movable/shooter

/obj/effect/temp_visual/plasma_pinch/Initialize(mapload, atom/movable/on_whom, px = 0, py = 0, pinch_layer = ABOVE_MOB_LAYER)
	. = ..()
	pixel_x = px
	pixel_y = py
	layer = pinch_layer
	// Gone on the client's clock when the state ends, whenever the delete lands
	animate(src, time = duration)
	animate(alpha = 0, time = 0)
	if(!on_whom)
		return
	shooter = on_whom
	shooter.vis_contents += src
	RegisterSignal(shooter, COMSIG_QDELETING, PROC_REF(shooter_gone))

/obj/effect/temp_visual/plasma_pinch/Destroy()
	shooter_gone()
	return ..()

/obj/effect/temp_visual/plasma_pinch/proc/shooter_gone(datum/source)
	SIGNAL_HANDLER
	if(!shooter)
		return
	UnregisterSignal(shooter, COMSIG_QDELETING)
	shooter.vis_contents -= src
	shooter = null

// A bolt from a gun with a pinch stays out of sight until the ball snaps: the ball is the bolt forming.
/obj/projectile/energy/plasma_bolt/fire(fire_angle, atom/direct_target)
	var/obj/item/gun/energy/plasma_weapon/gun = fired_from
	if(istype(gun) && gun.pinch_offsets && firer && gun.loc == firer)
		// Timed on the client, beside the bolt's own movement animation
		var/shown_alpha = alpha
		alpha = 0
		animate(src, alpha = 0, time = PLASMA_PINCH_SNAP_TIME, flags = ANIMATION_PARALLEL)
		animate(alpha = shown_alpha, time = 0)
		// The bolt leaves over the ball and ring. Shot north it is past the body, on the row behind, by the time it shows
		if(firer.dir != NORTH)
			layer = PLASMA_PINCH_BOLT_LAYER
			addtimer(VARSET_CALLBACK(src, layer, initial(layer)), PLASMA_PINCH_SNAP_TIME + PLASMA_PINCH_RING_TIME)
	return ..()

#undef PLASMA_PINCH_SNAP_TIME
#undef PLASMA_PINCH_RING_TIME
#undef PLASMA_PINCH_BOLT_LAYER
