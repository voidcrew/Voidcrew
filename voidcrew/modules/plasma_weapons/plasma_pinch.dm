// Package: P9 pinch. The barrel pinch when a plasma gun fires.
//
// A ball swells at the barrel with a flash on the hands and a small purple light, snaps small as the bolt
// leaves it, and a ring opens where the ball was.
//
// Placement is a local table of pixel offsets by facing, read off the wielded in-hand sprite. The
// pieces ride the shooter's vis_contents, so they stay at the barrel if the shooter moves or is turned
// over. When gun_feel's barrel placement is on master this table gives way to it.

/// When the ball snaps small, at the end of its swell frame. The bolt shows and the ring opens from here
#define PLASMA_PINCH_SNAP_TIME (0.14 SECONDS)
/// When the bolt's copy shows: a tick after the snap, as the client starts the ball's frames a little after our clock
#define PLASMA_PINCH_SHOW_TIME (PLASMA_PINCH_SNAP_TIME + 0.05 SECONDS)
/// How long the ring takes to open and fade
#define PLASMA_PINCH_RING_TIME (0.2 SECONDS)
/// Layer of a bolt while it leaves the pinch, just over the ball and ring
#define PLASMA_PINCH_BOLT_LAYER (ABOVE_MOB_LAYER + 0.01)
/// How long a bolt takes from the snap to close from the ball onto its own path, about the first tile of its flight
#define PLASMA_PINCH_CLOSE_TIME (0.12 SECONDS)
/// The pinch light's brightness as an overlay light's alpha (light_power 1)
#define PLASMA_PINCH_LIGHT_ALPHA 150
/// How long the light takes to grow from the pinch light to the bolt's, from the snap
#define PLASMA_PINCH_LIGHT_RAMP (0.2 SECONDS)

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

// A bolt from a gun with a pinch stays out of sight until the ball snaps: the ball is the bolt forming. By then the real
// bolt is most of a tile ahead, so a copy of it shows at the ball and closes onto it. The copy rides the real bolt's
// vis_contents with one sequence of its own, set at the shot and run on the client's clock like the ball's frames: an
// offset that holds it on the ball against the bolt's flight, shown at the snap, then closed to nothing over the first
// tile. Nothing waits on the server's moves. Once the copy lies on the bolt the bolt shows and the copy hides. Until then
// the bolt has no icon: it keeps its alpha, so its own fade at a hit takes the copy out with it. Nothing here animates
// the real bolt: its movement steps continue its newest animation sequence.
/obj/projectile/energy/plasma_bolt
	/// The copy we see while this bolt leaves the barrel pinch, null once its light has handed over
	var/obj/effect/abstract/plasma_pinch_bolt/pinch_copy
	/// How far our nose sits ahead of our icon centre
	var/pinch_nose = 7
	/// How far past the ball our nose shows when we appear
	var/pinch_lead = 7

/obj/projectile/energy/plasma_bolt/heavy
	pinch_nose = 13
	pinch_lead = 12

/obj/projectile/energy/plasma_bolt/fire(fire_angle, atom/direct_target)
	var/obj/item/gun/energy/plasma_weapon/gun = fired_from
	var/list/offset = istype(gun) && firer && gun.loc == firer ? gun.pinch_offset(firer) : null
	var/turf/barrel_turf = get_turf(firer)
	. = ..()
	if(!offset || QDELETED(src) || deletion_queued || !isturf(loc) || !movement_vector || !barrel_turf)
		return
	// The bolt leaves over the ring
	layer = PLASMA_PINCH_BOLT_LAYER
	addtimer(VARSET_CALLBACK(src, layer, initial(layer)), PLASMA_PINCH_SNAP_TIME + PLASMA_PINCH_RING_TIME)
	pinch_copy = new(null, src, barrel_turf, offset)

// plasma_bolt.dm's own move_animate() (the stop at an impact) runs first, through ..()
/obj/projectile/energy/plasma_bolt/move_animate(animate_x, animate_y, animate_time = world.tick_lag, deleting = FALSE)
	. = ..()
	if(deleting)
		pinch_copy?.land(animate_time)

/obj/projectile/energy/plasma_bolt/Destroy()
	QDEL_NULL(pinch_copy)
	return ..()

/// The bolt as it leaves the pinch, drawn on the real bolt at an offset that closes to nothing
/obj/effect/abstract/plasma_pinch_bolt
	name = "plasma"
	mouse_opacity = MOUSE_OPACITY_TRANSPARENT
	/// The real bolt we ride
	var/obj/projectile/energy/plasma_bolt/bolt
	/// The real bolt's icon, given back at the handover
	var/bolt_icon
	/// Whether the real bolt shows. We stay on it, unseen, to carry its light until the light has grown
	var/handed_over = FALSE
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
	// Our own turn, so our offsets are map pixels whatever way the bolt is turned. We take the bolt's alpha
	appearance_flags |= RESET_TRANSFORM | RESET_COLOR | KEEP_APART
	vis_flags = NONE
	mouse_opacity = MOUSE_OPACITY_TRANSPARENT
	pixel_x = 0
	pixel_y = 0
	var/dx = bolt.movement_vector.pixel_x
	var/dy = bolt.movement_vector.pixel_y
	// Where our centre shows when the ball snaps: our nose just past the ball, along the shot
	var/lead = bolt.pinch_lead - bolt.pinch_nose
	var/start_x = barrel_turf.x * ICON_SIZE_X + offset[1] + dx * lead
	var/start_y = barrel_turf.y * ICON_SIZE_Y + offset[2] + dy * lead
	// fire() has moved the bolt its first pixel over a tick. From then it flies at its pace, so where it is at the snap
	// is known now
	var/flown = SSprojectiles.pixels_per_decisecond * bolt.speed * max(PLASMA_PINCH_SHOW_TIME - world.tick_lag, 0)
	var/now_x = start_x - (bolt.loc.x * ICON_SIZE_X + bolt.pixel_x)
	var/now_y = start_y - (bolt.loc.y * ICON_SIZE_Y + bolt.pixel_y)
	alpha = 0
	pixel_w = now_x
	pixel_z = now_y
	animate(src, pixel_w = now_x - dx * flown, pixel_z = now_y - dy * flown, time = PLASMA_PINCH_SHOW_TIME)
	animate(alpha = 255, time = 0)
	animate(pixel_w = 0, pixel_z = 0, time = PLASMA_PINCH_CLOSE_TIME)
	// The bolt's light mask: the ball's small light from the shot, grown to the bolt's own from the snap. We sit on the
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
		animate(glow_holder, time = PLASMA_PINCH_SHOW_TIME)
		animate(alpha = 255, transform = matrix(), time = PLASMA_PINCH_LIGHT_RAMP)
		vis_contents += glow_holder
	bolt_icon = bolt.icon
	bolt.icon = null
	bolt.update_appearance(UPDATE_OVERLAYS)
	bolt.vis_contents += src
	// We lie on the bolt from the end of the close. A tick later the bolt shows, so a client a little behind never sees
	// a gap
	addtimer(CALLBACK(src, PROC_REF(handover)), PLASMA_PINCH_SHOW_TIME + PLASMA_PINCH_CLOSE_TIME + world.tick_lag)

/obj/effect/abstract/plasma_pinch_bolt/Destroy()
	if(bolt)
		bolt.vis_contents -= src
		if(!handed_over)
			bolt.icon = bolt_icon
			bolt.update_appearance(UPDATE_OVERLAYS)
		if(bolt.pinch_copy == src)
			bolt.pinch_copy = null
		bolt = null
	if(glow_holder)
		vis_contents -= glow_holder
		QDEL_NULL(glow_holder)
	return ..()

/// The bolt hits something before we lie on it: from wherever we are we close onto its stop over its last stretch
/obj/effect/abstract/plasma_pinch_bolt/proc/land(time)
	if(handed_over)
		return
	animate(src, pixel_w = 0, pixel_z = 0, alpha = 255, time = time)

/// The real bolt shows where we lie on it. We hide and carry its light until the light has grown to the bolt's own
/obj/effect/abstract/plasma_pinch_bolt/proc/handover()
	if(handed_over || QDELETED(bolt))
		return
	handed_over = TRUE
	bolt.icon = bolt_icon
	bolt.update_appearance(UPDATE_OVERLAYS)
	animate(src, alpha = 0, time = 0)
	var/light_left = PLASMA_PINCH_LIGHT_RAMP - PLASMA_PINCH_CLOSE_TIME - world.tick_lag
	if(!glow_holder || light_left <= 0)
		light_handover()
		return
	addtimer(CALLBACK(src, PROC_REF(light_handover)), light_left)

/// The bolt's own light takes over from ours at the same size and brightness, and we go
/obj/effect/abstract/plasma_pinch_bolt/proc/light_handover()
	if(QDELETED(src))
		return
	if(!QDELETED(bolt))
		bolt.set_light_on(TRUE)
	qdel(src)

#undef PLASMA_PINCH_SNAP_TIME
#undef PLASMA_PINCH_SHOW_TIME
#undef PLASMA_PINCH_RING_TIME
#undef PLASMA_PINCH_BOLT_LAYER
#undef PLASMA_PINCH_CLOSE_TIME
#undef PLASMA_PINCH_LIGHT_ALPHA
#undef PLASMA_PINCH_LIGHT_RAMP
