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
/// How long the ring takes to open and fade
#define PLASMA_PINCH_RING_TIME (0.2 SECONDS)
/// How far the bolt's nose sits ahead of its icon centre
#define PLASMA_PINCH_BOLT_NOSE 13
/// How far past the ball the bolt's nose shows when it appears
#define PLASMA_PINCH_BOLT_LEAD 12
/// Layer of a bolt while it leaves the pinch, just over the ball and ring
#define PLASMA_PINCH_BOLT_LAYER (ABOVE_MOB_LAYER + 0.01)
/// How much faster than the real bolt its copy closes on it, in pixels per decisecond (the bolt flies 32)
#define PLASMA_PINCH_CATCH_UP 12
/// Shot north, how far past the shooter's centre the bolt's centre is before it shows: its tail is clear of the head
#define PLASMA_PINCH_NORTH_CLEAR 32
/// The pinch light's brightness as an overlay light's alpha (light_power 1)
#define PLASMA_PINCH_LIGHT_ALPHA 150
/// How long the light takes to grow from the pinch light to the bolt's, from the snap
#define PLASMA_PINCH_LIGHT_RAMP (0.2 SECONDS)

/obj/item/gun/energy/plasma_weapon
	/// Where the pinch sits on the shooter, as "[dir]" = list(pixel_x, pixel_y). Null for a gun with no pinch
	var/list/pinch_offsets

// The Furnace's emitter is the purple tip of its wielded in-hand sprite: the east and west sprites end
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

/// The pinch's small purple light, on the ball. The bolt's copy takes the light over at this size when the ball snaps
/obj/effect/temp_visual/plasma_burst_light/pinch
	duration = PLASMA_PINCH_SNAP_TIME
	light_range = 1
	light_power = 1

// A bolt from a gun with a pinch stays out of sight until the ball snaps: the ball is the bolt forming. By then the
// real bolt is most of a tile ahead, so a copy of it shows at the ball and closes on it. The copy rides the real bolt's
// vis_contents. Every move the bolt makes, the copy queues a change of its offset over the same time, so the copy
// holds still at the ball and then closes on the bolt in step with the bolt's own moves, however late they come. The
// real bolt shows only once the copy has lain on it for a while. Until then the bolt has no icon: it keeps its alpha,
// so its own fade at a hit takes the copy out with it. Nothing here animates the real bolt: its movement steps continue
// its newest animation sequence, and a hold or offset of ours would make them queue.
/obj/projectile/energy/plasma_bolt
	/// The copy we see while this bolt leaves the barrel pinch, null once this bolt shows
	var/obj/effect/abstract/plasma_pinch_bolt/pinch_copy

/obj/projectile/energy/plasma_bolt/fire(fire_angle, atom/direct_target)
	var/obj/item/gun/energy/plasma_weapon/gun = fired_from
	var/list/offset = istype(gun) && firer && gun.loc == firer ? gun.pinch_offsets?["[firer.dir]"] : null
	var/turf/barrel_turf = get_turf(firer)
	var/shot_north = firer?.dir == NORTH
	. = ..()
	if(!offset || QDELETED(src) || deletion_queued || !isturf(loc) || !movement_vector || !barrel_turf)
		return
	// The bolt leaves over the ring. Shot north it is past the body, on the row behind, by the time it shows
	if(!shot_north)
		layer = PLASMA_PINCH_BOLT_LAYER
		addtimer(VARSET_CALLBACK(src, layer, initial(layer)), PLASMA_PINCH_SNAP_TIME + PLASMA_PINCH_RING_TIME)
	pinch_copy = new(null, src, barrel_turf, offset, shot_north)

// plasma_bolt.dm's own move_animate() (the stop at an impact) runs first, through ..()
/obj/projectile/energy/plasma_bolt/move_animate(animate_x, animate_y, animate_time = world.tick_lag, deleting = FALSE)
	var/from_x = pixel_x
	var/from_y = pixel_y
	. = ..()
	pinch_copy?.follow(from_x, from_y, animate_x, animate_y, animate_time, deleting)

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
	/// world.time of the shot. Times below are deciseconds after it, on the bolt's queue of moves
	var/fired_at = 0
	/// world.time of the bolt's last move, so we know how far it moves in a tick
	var/last_move_at = 0
	/// How many pixels the bolt moves this tick, over one tick
	var/tick_pixels = 0
	/// When the bolt's queued moves, and our offsets with them, end
	var/queued_to = 0
	/// Map pixel where our centre shows when the ball snaps, or null to show on the real bolt
	var/start_x
	var/start_y
	/// Our offset from the bolt when we show, null until the bolt's moves reach that point
	var/show_x
	var/show_y
	/// When we show, and how long we then take to close on the bolt
	var/show_at = PLASMA_PINCH_SNAP_TIME
	var/catch_up_time = 0
	/// Shot north: how far along the shot the bolt's centre is before we show
	var/north_clear
	/// Whether our queue shows us yet
	var/shown = FALSE
	/// Whether the real bolt shows. We stay on it, unseen, to carry its light until the light has grown
	var/handed_over = FALSE
	/// Carries the bolt's light on us, from the pinch light's size up to the bolt's
	var/obj/effect/abstract/glow_holder

/obj/effect/abstract/plasma_pinch_bolt/Initialize(mapload, obj/projectile/energy/plasma_bolt/real_bolt, turf/barrel_turf, list/offset, shot_north)
	. = ..()
	if(!real_bolt || !isturf(real_bolt.loc) || !real_bolt.movement_vector || !barrel_turf)
		return INITIALIZE_HINT_QDEL
	bolt = real_bolt
	fired_at = world.time
	last_move_at = world.time
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
	if(shot_north)
		// The ball is behind the body: we show on the bolt itself once its tail is clear of the head
		north_clear = barrel_turf.x * ICON_SIZE_X * dx + barrel_turf.y * ICON_SIZE_Y * dy + PLASMA_PINCH_NORTH_CLEAR
	else
		// Our nose shows just past the ball, on the bolt's path
		var/distance = offset[1] * dx + offset[2] * dy + PLASMA_PINCH_BOLT_LEAD - PLASMA_PINCH_BOLT_NOSE
		start_x = barrel_turf.x * ICON_SIZE_X + dx * distance
		start_y = barrel_turf.y * ICON_SIZE_Y + dy * distance
	alpha = 0
	// fire() moved the bolt its first pixel over a tick. We start our queue with that move, in the same message
	var/bolt_x = bolt.loc.x * ICON_SIZE_X + bolt.pixel_x
	var/bolt_y = bolt.loc.y * ICON_SIZE_Y + bolt.pixel_y
	if(!isnull(start_x))
		pixel_w = start_x - (bolt_x - dx)
		pixel_z = start_y - (bolt_y - dy)
		animate(src, pixel_w = start_x - bolt_x, pixel_z = start_y - bolt_y, time = world.tick_lag, flags = ANIMATION_PARALLEL)
	else
		animate(src, time = world.tick_lag, flags = ANIMATION_PARALLEL)
	queued_to = world.tick_lag
	// The bolt's light mask, shown at the pinch light's size and brightness when the ball snaps, then grown to the
	// bolt's. The holder's alpha and size carry over to the mask
	var/datum/component/overlay_lighting/lighting = bolt.GetComponent(/datum/component/overlay_lighting)
	if(lighting?.visible_mask)
		var/mutable_appearance/mask = new(lighting.visible_mask)
		mask.appearance_flags = RESET_COLOR
		glow_holder = new(null)
		glow_holder.appearance_flags = RESET_ALPHA | RESET_TRANSFORM | RESET_COLOR | KEEP_APART
		glow_holder.underlays += mask
		glow_holder.alpha = 0
		var/mask_size = (lighting.range - 1) * 64 + 32
		glow_holder.transform = matrix() * (ICON_SIZE_X / mask_size)
		animate(glow_holder, time = PLASMA_PINCH_SNAP_TIME)
		animate(alpha = min(255, 255 * PLASMA_PINCH_LIGHT_ALPHA / max(lighting.set_alpha, 1)), time = 0)
		animate(alpha = 255, transform = matrix(), time = PLASMA_PINCH_LIGHT_RAMP)
		vis_contents += glow_holder
	bolt_icon = bolt.icon
	bolt.icon = null
	bolt.vis_contents += src

/obj/effect/abstract/plasma_pinch_bolt/Destroy()
	if(bolt)
		bolt.vis_contents -= src
		if(!handed_over)
			bolt.icon = bolt_icon
		if(bolt.pinch_copy == src)
			bolt.pinch_copy = null
		bolt = null
	if(glow_holder)
		vis_contents -= glow_holder
		QDEL_NULL(glow_holder)
	return ..()

/// Our offset from the bolt `at` after the shot, while the bolt's centre is at map pixel (bolt_x, bolt_y)
/obj/effect/abstract/plasma_pinch_bolt/proc/offset_at(at, bolt_x, bolt_y)
	if(isnull(start_x))
		return list(0, 0)
	if(isnull(show_x) || at <= show_at)
		return list(start_x - bolt_x, start_y - bolt_y)
	var/left = catch_up_time > 0 ? max(0, 1 - (at - show_at) / catch_up_time) : 0
	return list(show_x * left, show_y * left)

/// The bolt is about to move from (from_x, from_y) to (to_x, to_y) on its turf, once its queued moves end. We queue
/// our offset over the same time, split where we show and where we land on the bolt
/obj/effect/abstract/plasma_pinch_bolt/proc/follow(from_x, from_y, to_x, to_y, time_given, deleting)
	if(handed_over || QDELETED(bolt) || !isturf(bolt.loc))
		return
	var/now = world.time - fired_at
	// The bolt's moves in a tick take one tick between them, each by its share of the tick's pixels. We can't see
	// that total, but at a whole number of pixels per tick it is what the time since the last move gives
	if(world.time != last_move_at)
		tick_pixels = min((world.time - last_move_at) * SSprojectiles.pixels_per_decisecond * bolt.speed, SSprojectiles.max_pixels_per_tick)
		last_move_at = world.time
	var/turf/bolt_turf = bolt.loc
	var/x0 = bolt_turf.x * ICON_SIZE_X + from_x
	var/y0 = bolt_turf.y * ICON_SIZE_Y + from_y
	var/x1 = bolt_turf.x * ICON_SIZE_X + to_x
	var/y1 = bolt_turf.y * ICON_SIZE_Y + to_y
	var/time = deleting ? time_given : world.tick_lag * sqrt((x1 - x0) ** 2 + (y1 - y0) ** 2) / max(tick_pixels, 1)
	var/move_start = max(now, queued_to)
	var/move_end = move_start + time
	// We have lain on the bolt for two ticks of its moves: it shows from here, even if the client runs a little behind
	if(shown && !deleting && move_start >= show_at + catch_up_time + 2 * world.tick_lag)
		handover()
		return
	queued_to = move_end
	var/dx = bolt.movement_vector.pixel_x
	var/dy = bolt.movement_vector.pixel_y
	// Shot north we show when the bolt's centre passes the head
	if(!shown && !isnull(north_clear))
		var/along0 = x0 * dx + y0 * dy
		var/along1 = x1 * dx + y1 * dy
		show_at = INFINITY
		if(along1 >= north_clear)
			show_at = along1 > along0 ? move_start + time * clamp((north_clear - along0) / (along1 - along0), 0, 1) : move_start
	// The snap falls in this move: our offset from the bolt then sets how long we take to close it
	if(isnull(show_x) && move_end >= show_at)
		var/progress = time > 0 ? clamp((show_at - move_start) / time, 0, 1) : 1
		var/list/show_offset = offset_at(show_at, x0 + (x1 - x0) * progress, y0 + (y1 - y0) * progress)
		show_x = show_offset[1]
		show_y = show_offset[2]
		catch_up_time = sqrt(show_x ** 2 + show_y ** 2) / PLASMA_PINCH_CATCH_UP
	var/list/stops = list()
	for(var/stop in list(show_at, show_at + catch_up_time))
		if(stop > move_start && stop < move_end)
			stops += stop
	stops += move_end
	var/last = move_start
	for(var/stop in stops)
		var/progress = time > 0 ? (stop - move_start) / time : 1
		var/list/offset = offset_at(stop, x0 + (x1 - x0) * progress, y0 + (y1 - y0) * progress)
		animate(src, pixel_w = offset[1], pixel_z = offset[2], time = max(stop - last, 0), flags = ANIMATION_PARALLEL | ANIMATION_CONTINUE)
		if(!shown && stop >= show_at)
			animate(alpha = 255, time = 0, flags = ANIMATION_CONTINUE)
			shown = TRUE
		last = stop

/// The real bolt shows where we lie on it. We hide and carry its light until the light has grown to the bolt's own
/obj/effect/abstract/plasma_pinch_bolt/proc/handover()
	if(handed_over || QDELETED(bolt))
		return
	handed_over = TRUE
	bolt.icon = bolt_icon
	animate(src, alpha = 0, time = 0)
	var/light_left = fired_at + PLASMA_PINCH_SNAP_TIME + PLASMA_PINCH_LIGHT_RAMP - world.time
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
#undef PLASMA_PINCH_RING_TIME
#undef PLASMA_PINCH_BOLT_LAYER
#undef PLASMA_PINCH_BOLT_NOSE
#undef PLASMA_PINCH_BOLT_LEAD
#undef PLASMA_PINCH_CATCH_UP
#undef PLASMA_PINCH_NORTH_CLEAR
#undef PLASMA_PINCH_LIGHT_ALPHA
#undef PLASMA_PINCH_LIGHT_RAMP
