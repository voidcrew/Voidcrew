// Package: P9 pinch. The barrel pinch when a plasma gun fires.
//
// A ball swells at the barrel with a flash on the hands and a small green light, snaps small as the bolt
// leaves it, and a ring opens where the ball was.
//
// Placement is a local table of pixel offsets by facing, read off the wielded in-hand sprite. The
// pieces ride the shooter's vis_contents, so they stay at the barrel if the shooter moves or is turned
// over. When gun_feel's barrel placement is on master this table gives way to it.

/// When the ball snaps small, at the end of its swell frame. The bolt shows and the ring opens from here
#define PLASMA_PINCH_SNAP_TIME (0.14 SECONDS)
/// How long the ring takes to open and fade
#define PLASMA_PINCH_RING_TIME (0.2 SECONDS)
/// When the real bolt takes over from its copy. A whole number of server ticks
#define PLASMA_PINCH_HANDOFF_TIME (0.25 SECONDS)
/// How far the bolt's nose sits ahead of its icon centre
#define PLASMA_PINCH_BOLT_NOSE 13
/// How far past the ball the bolt's nose shows when it appears
#define PLASMA_PINCH_BOLT_LEAD 12
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
	var/new_layer = user.dir == NORTH ? BELOW_MOB_LAYER : ABOVE_MOB_LAYER
	new /obj/effect/temp_visual/plasma_pinch(null, user, offset[1], offset[2], new_layer)

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

/obj/effect/temp_visual/plasma_pinch/Initialize(mapload, atom/movable/holder, px = 0, py = 0, new_layer = ABOVE_MOB_LAYER)
	. = ..()
	pixel_x = px
	pixel_y = py
	layer = new_layer
	// The state has a dir per facing: the ring opens a pixel ahead of the ball along the shot
	if(holder)
		dir = holder.dir
	// The flash on the hands, under the ball so it lights the hands and rifle but doesn't wash the ball out. The light
	// sits on the turf, so it still shows when the body hides the ball
	var/mutable_appearance/flash = mutable_appearance(icon, "pinch_glow")
	flash.blend_mode = BLEND_ADD
	underlays += flash
	add_overlay(emissive_appearance(icon, icon_state, src))
	// Gone on the client's clock when the state ends, whenever the delete lands
	animate(src, time = duration)
	animate(alpha = 0, time = 0)
	if(!holder)
		return
	var/obj/effect/temp_visual/plasma_burst_light/pinch/glow = new(holder.loc)
	glow.pixel_w = px
	glow.pixel_z = py
	shooter = holder
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

/// The pinch's small green light, on the ball
/obj/effect/temp_visual/plasma_burst_light/pinch
	duration = PLASMA_PINCH_SNAP_TIME + 0.05 SECONDS
	light_range = 1
	light_power = 1

// A bolt from a gun with a pinch stays out of sight until the ball snaps: the ball is the bolt forming. By then the
// real bolt is a tile or more ahead, so a copy of it leaves the ball and catches up, and the real one takes over
// where the copy meets it. Nothing here animates the real bolt: its movement steps continue its newest animation
// sequence, and a hold or offset of ours would make them queue up or flicker.
/obj/projectile/energy/plasma_bolt/fire(fire_angle, atom/direct_target)
	var/obj/item/gun/energy/plasma_weapon/gun = fired_from
	var/list/offset = istype(gun) && firer && gun.loc == firer ? gun.pinch_offsets?["[firer.dir]"] : null
	. = ..()
	if(!offset || QDELETED(src) || !isturf(loc))
		return
	// The bolt leaves over the ball and ring. Shot north it is past the body, on the row behind, by the time it shows
	if(firer?.dir != NORTH)
		layer = PLASMA_PINCH_BOLT_LAYER
		addtimer(VARSET_CALLBACK(src, layer, initial(layer)), PLASMA_PINCH_SNAP_TIME + PLASMA_PINCH_RING_TIME)
	var/old_alpha = alpha
	alpha = 0
	addtimer(CALLBACK(src, PROC_REF(plasma_pinch_reveal), old_alpha), PLASMA_PINCH_HANDOFF_TIME)
	var/dx = sin(angle)
	var/dy = cos(angle)
	// Where the copy shows: nose just past the ball. Where it hands over: where the real bolt is by then
	var/distance = offset[1] * dx + offset[2] * dy + PLASMA_PINCH_BOLT_LEAD - PLASMA_PINCH_BOLT_NOSE
	var/move_speed = SSprojectiles.pixels_per_decisecond * speed
	var/obj/effect/temp_visual/plasma_pinch_bolt/copy = new(loc)
	copy.appearance = appearance
	copy.mouse_opacity = MOUSE_OPACITY_TRANSPARENT
	// The bolt's light leaves with the bolt we see: the copy takes it when it shows, the real bolt when it takes over.
	// Until then only the pinch's own small light is on
	set_light_on(FALSE)
	copy.set_light_range(light_range)
	copy.set_light_power(light_power)
	copy.set_light_color(light_color)
	addtimer(CALLBACK(copy, TYPE_PROC_REF(/atom, set_light_on), TRUE), PLASMA_PINCH_SNAP_TIME)
	copy.pixel_x = dx * distance
	copy.pixel_y = dy * distance
	animate(copy, alpha = 0, time = PLASMA_PINCH_SNAP_TIME)
	animate(alpha = old_alpha, time = 0)
	animate(pixel_x = pixel_x + dx * move_speed * PLASMA_PINCH_HANDOFF_TIME, pixel_y = pixel_y + dy * move_speed * PLASMA_PINCH_HANDOFF_TIME, time = PLASMA_PINCH_HANDOFF_TIME - PLASMA_PINCH_SNAP_TIME)
	// One more tick beside the real bolt, so neither blinks out at the handover
	animate(pixel_x = pixel_x + dx * move_speed * (PLASMA_PINCH_HANDOFF_TIME + world.tick_lag), pixel_y = pixel_y + dy * move_speed * (PLASMA_PINCH_HANDOFF_TIME + world.tick_lag), time = world.tick_lag)
	animate(alpha = 0, time = 0)
	copy.RegisterSignals(src, list(COMSIG_PROJECTILE_SELF_ON_HIT, COMSIG_QDELETING), TYPE_PROC_REF(/obj/effect/temp_visual/plasma_pinch_bolt, bolt_gone))

/// The real bolt shows where its copy meets it, unless it has already hit something
/obj/projectile/energy/plasma_bolt/proc/plasma_pinch_reveal(old_alpha)
	if(deletion_queued)
		return
	alpha = old_alpha
	set_light_on(TRUE)

/// The bolt's copy from the ball to where the real bolt is
/obj/effect/temp_visual/plasma_pinch_bolt
	duration = PLASMA_PINCH_HANDOFF_TIME + 0.1 SECONDS
	randomdir = FALSE
	light_system = OVERLAY_LIGHT
	light_on = FALSE

/obj/effect/temp_visual/plasma_pinch_bolt/proc/bolt_gone(datum/source)
	SIGNAL_HANDLER
	qdel(src)

#undef PLASMA_PINCH_SNAP_TIME
#undef PLASMA_PINCH_RING_TIME
#undef PLASMA_PINCH_BOLT_LAYER
#undef PLASMA_PINCH_HANDOFF_TIME
#undef PLASMA_PINCH_BOLT_NOSE
#undef PLASMA_PINCH_BOLT_LEAD
