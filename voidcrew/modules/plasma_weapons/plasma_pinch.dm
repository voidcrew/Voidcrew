// Package: P9 pinch. The barrel pinch when a plasma gun fires.
//
// A ball swells at the barrel with a flash on the hands and a small purple light. As the bolt leaves it, the ball
// snaps into a ring that opens where it was. The bolt waits at the muzzle for the snap.
//
// Placement is a local table of pixel offsets by facing, read off the wielded in-hand sprite. The
// pieces ride the shooter's vis_contents, so they stay at the barrel if the shooter moves or is turned
// over. When gun_feel's barrel placement is on master this table gives way to it.

/// When the ball snaps, at the end of its swell frame. The bolt leaves and the ring opens from here
#define PLASMA_PINCH_SNAP_TIME (0.14 SECONDS)
/// How long the ring takes to open and fade
#define PLASMA_PINCH_RING_TIME (0.2 SECONDS)
/// Layer of a bolt while it leaves the pinch, just over the ball and ring
#define PLASMA_PINCH_BOLT_LAYER (ABOVE_MOB_LAYER + 0.01)
/// How long a bolt's copy takes from the snap to close from the ball onto the bolt's line, about its first tile. The
/// light grows to the bolt's own over the same time
#define PLASMA_PINCH_CLOSE_TIME (0.1 SECONDS)
/// The pinch light's brightness as an overlay light's alpha (light_power 1)
#define PLASMA_PINCH_LIGHT_ALPHA 150

/obj/item/gun/energy/plasma_weapon
	/// Where the pinch sits on the shooter, as "[dir]" = list(pixel_x, pixel_y), held in the right hand. Null for a
	/// gun with no pinch
	var/list/pinch_offsets
	/// The same for the north and south facings held in the left hand, where the gun lies across the body the other way
	var/list/pinch_offsets_left
	/// Size of the pinch and its light
	var/pinch_scale = 1

// Every offset is the muzzle of the held in-hand sprite: its farthest pixel the way the gun points, on that pixel's
// row. The Furnace's is the purple tip of its wielded sprite. Facing north or south both guns lie across the body,
// pointing to one side, so the ball forms at that side's tip and the bolt swings onto its path as it leaves.
/obj/item/gun/energy/plasma_weapon/rifle
	pinch_offsets = list(
		"1" = list(-15, 1),
		"2" = list(14, 1),
		"4" = list(15, 1),
		"8" = list(-16, 1),
	)
	pinch_offsets_left = list(
		"1" = list(13, 1),
		"2" = list(-15, 1),
	)

// The Cinder's pinch is the rifle's at the size of its small bursts
/obj/item/gun/energy/plasma_weapon/pistol
	pinch_offsets = list(
		"1" = list(13, -3),
		"2" = list(-15, -3),
		"4" = list(5, -3),
		"8" = list(-10, -3),
	)
	pinch_offsets_left = list(
		"1" = list(-15, -3),
		"2" = list(13, -3),
	)
	pinch_scale = 0.6

/// Where the pinch sits on `user` as they face now, or null
/obj/item/gun/energy/plasma_weapon/proc/pinch_offset(mob/living/user)
	if(!pinch_offsets || !istype(user))
		return null
	var/key = "[user.dir]"
	if(pinch_offsets_left?[key] && IS_LEFT_INDEX(user.get_held_index_of_item(src)))
		return pinch_offsets_left[key]
	return pinch_offsets[key]

/// The plasma ball and ring at the barrel as `user` fires at `target`
/obj/item/gun/energy/plasma_weapon/proc/plasma_pinch(mob/living/user, atom/target)
	if(loc != user || !isturf(user.loc))
		return
	var/list/offset = pinch_offset(user)
	if(!offset)
		return
	// The muzzle sticks out past the body in every facing
	new /obj/effect/temp_visual/plasma_pinch(null, user, offset[1], offset[2], ABOVE_MOB_LAYER, pinch_scale)

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

/obj/effect/temp_visual/plasma_pinch/Initialize(mapload, atom/movable/holder, px = 0, py = 0, new_layer = ABOVE_MOB_LAYER, scale = 1)
	. = ..()
	pixel_x = px
	pixel_y = py
	// The ball is centred on the icon, so it shrinks in place. Shrunk, it is smoothed: a few hard pixels read as a square
	if(scale != 1)
		transform = matrix() * scale
		appearance_flags &= ~PIXEL_SCALE
	layer = new_layer
	// In front of the body we draw above the lighting, off the game world's ambient occlusion: its drop shadow under
	// a bright ball darkened the floor around it. Behind the body we stay on the shooter's plane so the body hides us
	if(holder && new_layer != BELOW_MOB_LAYER)
		vis_flags = NONE
		SET_PLANE_EXPLICIT(src, ABOVE_LIGHTING_PLANE, holder)
	// The state has a dir per facing: the ring opens a pixel ahead of the ball along the shot
	if(holder)
		dir = holder.dir
	// The flash on the hands, under the ball so it lights the hands and rifle but doesn't wash the ball out. The light
	// sits on the turf, so it still shows when the body hides the ball
	var/mutable_appearance/flash = mutable_appearance(icon, "pinch_glow")
	flash.blend_mode = BLEND_ADD
	underlays += flash
	// No bloom: the flash and the light already glow
	add_overlay(emissive_appearance(icon, icon_state, src, effect_type = EMISSIVE_NO_BLOOM))
	// Gone on the client's clock when the state ends, whenever the delete lands
	animate(src, time = duration)
	animate(alpha = 0, time = 0)
	if(!holder)
		return
	// The ball's light is the bolt's own, carried by the bolt's copy from the shot (plasma_pinch_bolt)
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

// A bolt from a gun with a pinch waits at the muzzle, out of sight, until the ball snaps: the ball is the bolt forming, and
// the bolt leaves it as it snaps. It waits moved up its line to level with the ball. Facing north or south the muzzle is
// off to one side of the bolt's line, so a copy of the bolt shows at the ball and closes sideways onto the bolt's line
// while keeping pace with it; then the bolt shows under it and the copy goes. The copy sits on the barrel's turf and
// flies one path, set at the shot and run on the client's clock like the ball's frames. Nothing rides the bolt: its
// sprite jumps a tile for a frame as it crosses into a new turf. The copy also carries the bolt's light, from the ball's
// small one up to the bolt's own. Nothing here animates the real bolt: its movement steps continue its newest animation
// sequence.
/obj/projectile/energy/plasma_bolt
	/// The copy we see while this bolt leaves the barrel pinch, null once it has handed over
	var/obj/effect/abstract/plasma_pinch_bolt/pinch_copy
	/// How far our nose sits ahead of our icon centre
	var/pinch_nose = 7
	/// How far past the ball our nose shows when we appear
	var/pinch_lead = 7
	/// Whether our light has been moved forward onto our head
	var/nose_lit = FALSE

/obj/projectile/energy/plasma_bolt/heavy
	pinch_nose = 13
	pinch_lead = 12

/obj/projectile/energy/plasma_bolt/fire(fire_angle, atom/direct_target)
	var/obj/item/gun/energy/plasma_weapon/gun = fired_from
	var/list/offset = istype(gun) && firer && gun.loc == firer ? gun.pinch_offset(firer) : null
	var/turf/barrel_turf = get_turf(firer)
	. = ..()
	if(!offset || QDELETED(src) || deletion_queued || !barrel_turf || loc != barrel_turf || !movement_vector)
		nose_light()
		return
	var/dx = movement_vector.pixel_x
	var/dy = movement_vector.pixel_y
	// Up our line to level with the ball, where the copy's centre shows, as far as our own turf allows
	var/room = ICON_SIZE_ALL / 2 - 1
	var/ahead = (offset[1] * dx + offset[2] * dy) + (pinch_lead - pinch_nose) - (pixel_x * dx + pixel_y * dy)
	ahead = clamp(ahead, -room, room)
	animate(src)
	pixel_x = clamp(pixel_x + dx * ahead, -room, room)
	pixel_y = clamp(pixel_y + dy * ahead, -room, room)
	// We wait for the snap. Paused, the projectile subsystem holds us and counts no time, so we leave at our pace
	paused = TRUE
	addtimer(CALLBACK(src, PROC_REF(leave_pinch)), PLASMA_PINCH_SNAP_TIME)
	// The bolt leaves over the ring
	layer = PLASMA_PINCH_BOLT_LAYER
	addtimer(VARSET_CALLBACK(src, layer, initial(layer)), PLASMA_PINCH_SNAP_TIME + PLASMA_PINCH_RING_TIME)
	pinch_copy = new(barrel_turf, src, barrel_turf, offset)

/// The ball snaps: we fly
/obj/projectile/energy/plasma_bolt/proc/leave_pinch()
	if(QDELETED(src))
		return
	paused = FALSE
	last_projectile_move = world.time

// plasma_bolt.dm's own move_animate() (the stop at an impact) runs first, through ..(), and leaves our pixel vars on
// the stop
/obj/projectile/energy/plasma_bolt/move_animate(animate_x, animate_y, animate_time = world.tick_lag, deleting = FALSE)
	. = ..()
	if(deleting && isturf(loc))
		pinch_copy?.land(loc.x * ICON_SIZE_X + pixel_x, loc.y * ICON_SIZE_Y + pixel_y + pixel_z, animate_time)

/obj/projectile/energy/plasma_bolt/Destroy()
	QDEL_NULL(pinch_copy)
	return ..()

/// How far ahead of our icon centre our light sits: on the round head, a little behind the nose
/obj/projectile/energy/plasma_bolt/proc/light_lead()
	return pinch_nose - 2

/// Moves our light forward from our icon centre onto our head, along the shot, so it never trails the bolt. The light's
/// mask ignores our turn, so it moves in screen pixels
/obj/projectile/energy/plasma_bolt/proc/nose_light()
	if(nose_lit || QDELETED(src) || !movement_vector)
		return
	var/datum/component/overlay_lighting/lighting = GetComponent(/datum/component/overlay_lighting)
	if(!lighting?.visible_mask)
		return
	nose_lit = TRUE
	var/was_on = light_on
	if(was_on)
		set_light_on(FALSE)
	var/matrix/moved = lighting.visible_mask.transform ? matrix(lighting.visible_mask.transform) : matrix()
	moved.Translate(movement_vector.pixel_x * light_lead(), movement_vector.pixel_y * light_lead())
	lighting.visible_mask.transform = moved
	if(was_on)
		set_light_on(TRUE)

/// The bolt as it leaves the pinch, flying from the ball onto the real bolt
/obj/effect/abstract/plasma_pinch_bolt
	name = "plasma"
	mouse_opacity = MOUSE_OPACITY_TRANSPARENT
	/// The real bolt we ride
	var/obj/projectile/energy/plasma_bolt/bolt
	/// The real bolt's icon, given back at the handover
	var/bolt_icon
	/// Map pixel of our turf's corner, to turn map pixels into our offsets
	var/base_x = 0
	var/base_y = 0
	/// Carries the bolt's light on us, from the pinch light's size up to the bolt's
	var/obj/effect/abstract/glow_holder

/obj/effect/abstract/plasma_pinch_bolt/Initialize(mapload, obj/projectile/energy/plasma_bolt/real_bolt, turf/barrel_turf, list/offset)
	. = ..()
	if(!real_bolt || !isturf(real_bolt.loc) || !real_bolt.movement_vector || !barrel_turf)
		return INITIALIZE_HINT_QDEL
	bolt = real_bolt
	// The bolt's light goes with us until the handover. Off before we take its look, or its light comes along
	bolt.set_light_on(FALSE)
	appearance = bolt.appearance
	mouse_opacity = MOUSE_OPACITY_TRANSPARENT
	pixel_x = 0
	pixel_y = 0
	base_x = barrel_turf.x * ICON_SIZE_X
	base_y = barrel_turf.y * ICON_SIZE_Y
	var/dx = bolt.movement_vector.pixel_x
	var/dy = bolt.movement_vector.pixel_y
	// Where our centre shows when the ball snaps: our nose just past the ball, along the shot
	var/lead = bolt.pinch_lead - bolt.pinch_nose
	var/start_x = base_x + offset[1] + dx * lead
	var/start_y = base_y + offset[2] + dy * lead
	// The bolt waits where it is until the snap and then flies at its pace, so where it will be is known
	var/pace = SSprojectiles.pixels_per_decisecond * bolt.speed
	var/bolt_x = bolt.loc.x * ICON_SIZE_X + bolt.pixel_x
	var/bolt_y = bolt.loc.y * ICON_SIZE_Y + bolt.pixel_y
	var/fly_to = PLASMA_PINCH_CLOSE_TIME + 3 * world.tick_lag
	alpha = 0
	pixel_w = start_x - base_x
	pixel_z = start_y - base_y
	animate(src, time = PLASMA_PINCH_SNAP_TIME)
	animate(alpha = 255, time = 0)
	animate(pixel_w = bolt_x + dx * pace * PLASMA_PINCH_CLOSE_TIME - base_x, pixel_z = bolt_y + dy * pace * PLASMA_PINCH_CLOSE_TIME - base_y, time = PLASMA_PINCH_CLOSE_TIME)
	animate(pixel_w = bolt_x + dx * pace * fly_to - base_x, pixel_z = bolt_y + dy * pace * fly_to - base_y, time = fly_to - PLASMA_PINCH_CLOSE_TIME)
	// The bolt's light mask: the ball's small light from the shot, grown to the bolt's own as we close. We sit on the
	// ball until the snap, so the light does too. The holder's alpha and size carry over to the mask
	var/datum/component/overlay_lighting/lighting = bolt.GetComponent(/datum/component/overlay_lighting)
	if(lighting?.visible_mask)
		var/mutable_appearance/mask = new(lighting.visible_mask)
		mask.appearance_flags = RESET_COLOR
		glow_holder = new(null)
		glow_holder.appearance_flags = RESET_ALPHA | RESET_TRANSFORM | RESET_COLOR | KEEP_APART
		glow_holder.underlays += mask
		glow_holder.alpha = min(255, 255 * PLASMA_PINCH_LIGHT_ALPHA / max(lighting.set_alpha, 1))
		var/mask_size = (lighting.range - 1) * 64 + 32
		// The client scales the mask about the middle of its own icon, which its transform has moved half a size up and
		// right of ours. Moved back by what the scale leaves of that, it shrinks about our centre and grows back in place
		var/scale = ICON_SIZE_X / mask_size
		var/pivot = (1 - scale) * (mask_size - ICON_SIZE_X) / 2
		var/matrix/small = matrix() * scale
		small.Translate(-pivot, -pivot)
		glow_holder.transform = small
		animate(glow_holder, time = PLASMA_PINCH_SNAP_TIME)
		animate(alpha = 255, transform = matrix(), time = PLASMA_PINCH_CLOSE_TIME)
		// On the ball until the snap, then forward onto the head as we close, where the bolt's own light takes over
		animate(glow_holder, time = PLASMA_PINCH_SNAP_TIME, flags = ANIMATION_PARALLEL)
		animate(pixel_w = dx * bolt.light_lead(), pixel_z = dy * bolt.light_lead(), time = PLASMA_PINCH_CLOSE_TIME)
		vis_contents += glow_holder
	bolt_icon = bolt.icon
	bolt.icon = null
	bolt.update_appearance(UPDATE_OVERLAYS)
	// We lie on the bolt from the end of the close. Then the bolt shows under us with its own light, and a tick later,
	// so a client a little behind never sees a gap, we go
	addtimer(CALLBACK(src, PROC_REF(handover)), PLASMA_PINCH_SNAP_TIME + PLASMA_PINCH_CLOSE_TIME)

/obj/effect/abstract/plasma_pinch_bolt/Destroy()
	if(bolt)
		show_bolt()
		if(bolt.pinch_copy == src)
			bolt.pinch_copy = null
		bolt = null
	if(glow_holder)
		vis_contents -= glow_holder
		QDEL_NULL(glow_holder)
	return ..()

/// The bolt hits something while we fly: from wherever we are we go to its stop, map pixel (stop_x, stop_y), over its last
/// stretch, and go out with it
/obj/effect/abstract/plasma_pinch_bolt/proc/land(stop_x, stop_y, time)
	animate(src, pixel_w = stop_x - base_x, pixel_z = stop_y - base_y, alpha = 255, time = time)
	animate(alpha = 0, time = 0)

/// The real bolt shows where we lie on it, with its own light, and we go a tick later
/obj/effect/abstract/plasma_pinch_bolt/proc/handover()
	if(QDELETED(src))
		return
	show_bolt()
	QDEL_IN(src, world.tick_lag)

/// Gives the bolt back its look and its light, once
/obj/effect/abstract/plasma_pinch_bolt/proc/show_bolt()
	if(QDELETED(bolt) || isnull(bolt_icon))
		return
	bolt.icon = bolt_icon
	bolt_icon = null
	bolt.update_appearance(UPDATE_OVERLAYS)
	bolt.nose_light()
	bolt.set_light_on(TRUE)

#undef PLASMA_PINCH_SNAP_TIME
#undef PLASMA_PINCH_RING_TIME
#undef PLASMA_PINCH_BOLT_LAYER
#undef PLASMA_PINCH_CLOSE_TIME
#undef PLASMA_PINCH_LIGHT_ALPHA
