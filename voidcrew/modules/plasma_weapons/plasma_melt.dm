// Package: P1 bolt. The melt-off picture. The arm or leg comes off at once through tg's WOUND_BURN loss (state,
// damage and blood loss all as tg does them); the picture lags behind it. The limb as it was drawn heats up on the
// body, then melts in place from the hit joint: arms on a standing body hang and run off in gobbets that splash
// into a pool in front of the feet, legs and arms on a lying body slump into the pool. A molten stump bubbles,
// chars and stays on the body until the limb is put back or regrown. The pool cools into a lasting slag decal.
// tg's ash pile and its dismember blood splatter are not shown; the slag stands in for both.
// Every melt frame lives in plasma_melt.dmi in the body's own sprite space, so it turns with a lying body.
// Each body state comes as a pair: "<state>" holds the near facings and draws in front of the body,
// "<state>_far" holds only the facing where the limb is on the far side and draws behind it.

#define PLASMA_MELT_ICON 'voidcrew/modules/plasma_weapons/icons/plasma_melt.dmi'

/// Key moments, from the hit
#define PLASMA_MELT_HEAT_END (0.35 SECONDS)
#define PLASMA_MELT_GONE (1.6 SECONDS)
#define PLASMA_MELT_STUMP_COOL (2.4 SECONDS)
#define PLASMA_MELT_POOL_COOL (2.2 SECONDS)
#define PLASMA_MELT_COOLED (4.5 SECONDS)

/// Pool growth steps in the DMI (pool_1 .. pool_N)
#define PLASMA_MELT_POOL_STEPS 8
/// Feet row of a standing body, from the top of its 32x32 sprite (0-based)
#define PLASMA_MELT_FLOOR_ROW 30
/// How far below the feet the pool sits on a standing body, so it reads in front of them
#define PLASMA_MELT_POOL_FRONT 4
/// The same for a lying body: how far past where the limb lay, away from the body, so the body doesn't cover it
#define PLASMA_MELT_POOL_FRONT_LYING 4
/// Row and column of the pool's centre in its own 32x32 tile (pool, splat and slag states)
#define PLASMA_MELT_POOL_TILE_X 15
#define PLASMA_MELT_POOL_TILE_Y 21
/// Row and column of a falling drop's lowest pixel in its own tile
#define PLASMA_MELT_DROP_TILE 16
/// How long a body takes to slide one tile; drips from a moving body land after this
#define PLASMA_MELT_GLIDE_WAIT (0.4 SECONDS)

/// Most slag decals in the world at once; the oldest goes first
#define PLASMA_SLAG_GLOBAL_CAP 150

/// Per limb and facing, from the approved storyboard (melt_v4.py), in the body sprite's pixels from its top left:
/// list(pool column standing, limb middle x lying, limb middle y lying, list(drops: list(release time cs, size, x, start row)))
/// Drops only fall from arms on a standing body; a far arm has no late stump drip.
GLOBAL_LIST_INIT(plasma_melt_geometry, list(
	BODY_ZONE_R_ARM = list("2" = list(7, 8.5, 20.0, list(list(55, 1, 9, 22), list(78, 2, 9, 25), list(98, 2, 9, 24), list(114, 2, 9, 22), list(128, 2, 9, 19), list(140, 2, 9, 16), list(155, 3, 9, 14), list(195, 1, 9, 16))), "1" = list(23, 21.5, 20.0, list(list(55, 1, 21, 22), list(78, 2, 21, 25), list(98, 2, 21, 24), list(114, 2, 21, 22), list(128, 2, 21, 19), list(140, 2, 21, 16), list(155, 3, 21, 14), list(195, 1, 21, 16))), "4" = list(13, 13.5, 21.0, list(list(55, 1, 13, 22), list(78, 2, 13, 25), list(98, 2, 13, 24), list(114, 2, 13, 22), list(128, 2, 13, 20), list(140, 2, 13, 18), list(155, 3, 13, 16), list(195, 1, 13, 18))), "8" = list(11, 11.0, 21.0, list(list(55, 1, 11, 20), list(78, 2, 11, 21), list(98, 2, 11, 21), list(114, 2, 11, 20), list(128, 2, 11, 19), list(140, 2, 11, 18), list(155, 3, 11, 17)))),
	BODY_ZONE_L_ARM = list("2" = list(23, 21.5, 20.0, list(list(55, 1, 21, 22), list(78, 2, 21, 25), list(98, 2, 21, 24), list(114, 2, 21, 22), list(128, 2, 21, 19), list(140, 2, 21, 16), list(155, 3, 21, 14), list(195, 1, 21, 16))), "1" = list(7, 8.5, 20.0, list(list(55, 1, 9, 22), list(78, 2, 9, 25), list(98, 2, 9, 24), list(114, 2, 9, 22), list(128, 2, 9, 19), list(140, 2, 9, 16), list(155, 3, 9, 14), list(195, 1, 9, 16))), "4" = list(20, 20.0, 21.0, list(list(55, 1, 20, 20), list(78, 2, 20, 21), list(98, 2, 20, 21), list(114, 2, 20, 20), list(128, 2, 20, 19), list(140, 2, 20, 18), list(155, 3, 20, 17))), "8" = list(19, 17.5, 21.0, list(list(55, 1, 18, 22), list(78, 2, 18, 25), list(98, 2, 18, 24), list(114, 2, 19, 22), list(128, 2, 19, 20), list(140, 2, 19, 18), list(155, 3, 19, 16), list(195, 1, 19, 18)))),
	BODY_ZONE_R_LEG = list("2" = list(12, 11.5, 30.5, list()), "1" = list(19, 18.5, 30.5, list()), "4" = list(16, 15.5, 30.0, list()), "8" = list(12, 12.0, 30.0, list())),
	BODY_ZONE_L_LEG = list("2" = list(19, 18.5, 30.5, list()), "1" = list(12, 11.5, 30.5, list()), "4" = list(19, 19.0, 30.0, list()), "8" = list(16, 15.5, 30.0, list())),
))

/// Every slag decal, oldest first
GLOBAL_LIST_EMPTY(plasma_slag_decals)
/// The carbon whose limb is melting off right now, while tg's dismember runs: its blood loss stays, its splatter doesn't
GLOBAL_DATUM(plasma_melt_no_splatter, /mob/living)

/// The plasma melts on this body by zone; each keeps its stump drawn until that limb comes back
/mob/living/carbon/var/list/plasma_melts

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
	GLOB.plasma_melt_no_splatter = victim
	melt.apply_dismember(limb, WOUND_BURN, FALSE, attack_direction)
	GLOB.plasma_melt_no_splatter = null
	// tg leaves an ash pile from the burnt limb; the slag is the remains here
	for(var/obj/effect/decal/cleanable/ash/pile in where)
		if(!(pile in old_ash))
			qdel(pile)
	if(QDELETED(victim) || victim.get_bodypart(zone) == limb)
		return FALSE
	new /datum/plasma_melt(victim, zone, drawn)
	return TRUE

/// tg's dismember bleeds the body; on a plasma melt the blood is lost but no splatter lands (the slag stands in)
/mob/living/add_splatter_floor(turf/splatter_turf, small_drip = FALSE)
	if(GLOB.plasma_melt_no_splatter == src)
		return
	return ..()

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
	var/mob/living/carbon/victim
	var/zone
	/// The limb as it was drawn, captured before it came off
	var/list/drawn
	/// What this melt has on the body right now
	var/list/shown = list()
	/// TRUE once the jumpsuit sleeve at this (arm) zone has burned away
	var/sleeve_burned = FALSE
	/// Facing and posture when the melt began running, which pick the melt frames, drops and pool spot
	var/melt_dir
	var/melt_lying = FALSE
	/// Pool offsets on the victim's turf
	var/pool_x = 0
	var/pool_y = 0
	/// Pool growth step shown (0 = none yet)
	var/pool_step = 0
	var/obj/effect/plasma_melt_pool/pool
	var/obj/effect/plasma_melt_light/limb_light
	/// Bumped whenever a new sequence starts, so the old one's pending frames stop
	var/play_id = 0
	/// Where the melt started: the pool and slag stay here even if the body moves on
	var/turf/start_turf
	/// Gobbets still falling (each with its column), so a body that moves doesn't leave one hanging in the air
	var/list/falling = list()
	/// world.time the body last changed tiles
	var/last_moved = -INFINITY

/datum/plasma_melt/New(mob/living/carbon/victim, zone, list/drawn)
	src.victim = victim
	src.zone = zone
	src.drawn = drawn
	var/datum/plasma_melt/old = LAZYACCESS(victim.plasma_melts, zone)
	if(old)
		qdel(old)
	LAZYSET(victim.plasma_melts, zone, src)
	RegisterSignal(victim, COMSIG_CARBON_POST_ATTACH_LIMB, PROC_REF(on_attach))
	RegisterSignal(victim, COMSIG_QDELETING, PROC_REF(on_victim_deleted))
	RegisterSignal(victim, COMSIG_MOVABLE_MOVED, PROC_REF(on_moved))
	start_turf = get_turf(victim)
	pose_heat()
	addtimer(CALLBACK(src, PROC_REF(pose_melt)), PLASMA_MELT_HEAT_END)
	addtimer(CALLBACK(src, PROC_REF(pose_stump), "stump_bubble", TRUE), PLASMA_MELT_GONE)
	addtimer(CALLBACK(src, PROC_REF(pose_stump), "stump_cool", FALSE), PLASMA_MELT_STUMP_COOL)
	addtimer(CALLBACK(src, PROC_REF(pose_stump), "stump", FALSE), PLASMA_MELT_COOLED)
	addtimer(CALLBACK(src, PROC_REF(pool_cool)), PLASMA_MELT_POOL_COOL)
	addtimer(CALLBACK(src, PROC_REF(pool_set)), PLASMA_MELT_COOLED)
	var/turf/here = get_turf(victim)
	if(here)
		limb_light = new(here)
		limb_light.set_light_power(is_far() ? 0.3 : 0.5)

/datum/plasma_melt/Destroy()
	show(list())
	if(victim)
		if(LAZYACCESS(victim.plasma_melts, zone) == src)
			LAZYREMOVE(victim.plasma_melts, zone)
		UnregisterSignal(victim, list(COMSIG_CARBON_POST_ATTACH_LIMB, COMSIG_QDELETING, COMSIG_MOVABLE_MOVED))
		if(sleeve_burned && ishuman(victim) && !QDELETED(victim))
			sleeve_burned = FALSE
			var/mob/living/carbon/human/wearer = victim
			wearer.update_worn_undersuit()
	victim = null
	start_turf = null
	falling.Cut()
	QDEL_NULL(limb_light)
	if(!QDELETED(pool)) // a pool still hot when the melt ends sets where it is
		pool_set()
	pool = null
	return ..()

/datum/plasma_melt/proc/on_attach(mob/living/carbon/source, obj/item/bodypart/limb)
	SIGNAL_HANDLER
	if(limb.body_zone == zone)
		qdel(src)

/datum/plasma_melt/proc/on_victim_deleted(datum/source)
	SIGNAL_HANDLER
	qdel(src)

/// The limb, stump and sleeve ride on the body as overlays and the limb's light follows it. A gobbet still in the air
/// when the body moves would hang where the body was, so it is taken away and lands under the body as a drip once
/// the body has arrived.
/datum/plasma_melt/proc/on_moved(atom/movable/source, atom/old_loc, dir, forced, list/old_locs)
	SIGNAL_HANDLER
	last_moved = world.time
	var/turf/here = get_turf(victim)
	if(!here)
		return
	if(limb_light)
		limb_light.set_glide_size(victim.glide_size)
		limb_light.forceMove(here)
	for(var/obj/effect/temp_visual/plasma_melt_drop/drop as anything in falling)
		addtimer(CALLBACK(src, PROC_REF(drip_trail), falling[drop][1], falling[drop][2], PLASMA_MELT_POOL_TILE_Y - (PLASMA_MELT_FLOOR_ROW + PLASMA_MELT_POOL_FRONT), here), PLASMA_MELT_GLIDE_WAIT)
		qdel(drop)
	falling.Cut()

/// Whether the body changed tiles so recently that its sprite may still be sliding there
/datum/plasma_melt/proc/moving()
	return world.time - last_moved < PLASMA_MELT_GLIDE_WAIT

/// Whether the body is still where the melt started (so drips feed the pool)
/datum/plasma_melt/proc/at_start()
	return victim && get_turf(victim) == start_turf

/datum/plasma_melt/proc/is_arm()
	return zone == BODY_ZONE_R_ARM || zone == BODY_ZONE_L_ARM

/// The limb is on the side of the body away from the viewer
/datum/plasma_melt/proc/is_far()
	var/left = (zone == BODY_ZONE_L_ARM || zone == BODY_ZONE_L_LEG)
	return (victim.dir == EAST && left) || (victim.dir == WEST && !left)

/// Swaps what the melt draws on the body
/datum/plasma_melt/proc/show(list/pieces)
	if(victim)
		victim.cut_overlay(shown)
		victim.add_overlay(pieces)
	shown = pieces

/// One body frame as its near/far pair (and their glow while hot)
/datum/plasma_melt/proc/pair(near_state, far_state, hot)
	. = list(
		mutable_appearance(PLASMA_MELT_ICON, near_state, -BODY_FRONT_LAYER),
		mutable_appearance(PLASMA_MELT_ICON, far_state, -BODY_BEHIND_LAYER),
	)
	if(hot)
		. += emissive_appearance(PLASMA_MELT_ICON, near_state, victim, -BODY_FRONT_LAYER)
		. += emissive_appearance(PLASMA_MELT_ICON, far_state, victim, -BODY_BEHIND_LAYER)

/// Steps the body through `frames` single-frame states "<base>_<n>" (and "<base>_far_<n>"), `delay` apart.
/// An overlay runs on its parent's animation clock, so a one-shot DMI animation on a body would show only its last
/// frame; stepping states on timers plays it from the start. `heat` frames go over the limb as it was drawn.
/datum/plasma_melt/proc/play(base, frames, delay, hot = TRUE, heat = FALSE)
	play_id++
	play_frame(play_id, base, 1, frames, delay, hot, heat)

/datum/plasma_melt/proc/play_frame(id, base, frame, frames, delay, hot, heat)
	if(id != play_id || !victim)
		return
	var/list/pieces
	if(heat)
		pieces = list()
		for(var/mutable_appearance/source as anything in drawn)
			pieces += new /mutable_appearance(source)
		pieces += mutable_appearance(PLASMA_MELT_ICON, "[base]_[frame]", -BODY_FRONT_LAYER)
		pieces += emissive_appearance(PLASMA_MELT_ICON, "[base]_[frame]", victim, -BODY_FRONT_LAYER)
	else
		pieces = pair("[base]_[frame]", "[base]_far_[frame]", hot)
	show(pieces)
	if(frame < frames)
		addtimer(CALLBACK(src, PROC_REF(play_frame), id, base, frame + 1, frames, delay, hot, heat), delay)

/// 0 - 0.35 s: the limb as it was, heating from the joint outward
/datum/plasma_melt/proc/pose_heat()
	play("[zone]_heat", 7, 0.05 SECONDS, heat = TRUE)

/// 0.35 - 1.6 s: the limb loses its shape and runs off. Picks the frames, drops and pool spot for how the body lies now.
/datum/plasma_melt/proc/pose_melt()
	if(!victim)
		return
	melt_dir = victim.dir
	melt_lying = victim.body_position == LYING_DOWN
	play((is_arm() && melt_lying) ? "[zone]_melt_floor" : "[zone]_melt", 25, 0.05 SECONDS)
	if(is_arm())
		burn_sleeve()
	find_pool_spot()
	var/list/geometry = GLOB.plasma_melt_geometry[zone]?["[melt_dir]"]
	var/list/drop_list = (is_arm() && !melt_lying && geometry) ? geometry[4] : list()
	if(length(drop_list))
		var/total = 0
		for(var/list/drop as anything in drop_list)
			total += drop[2]
		var/landed = 0
		var/behind = is_far()
		for(var/list/drop as anything in drop_list)
			var/release = drop[1] * 0.01 SECONDS
			var/fall_time = plasma_melt_fall_time(pool_top_row() - drop[4])
			landed += drop[2]
			var/grow_to = clamp(CEILING(landed / total * PLASMA_MELT_POOL_STEPS, 1), 1, PLASMA_MELT_POOL_STEPS)
			addtimer(CALLBACK(src, PROC_REF(release_drop), drop[2], drop[3], drop[4], fall_time, grow_to, behind), max(release - PLASMA_MELT_HEAT_END, 1))
		return
	// legs, and any limb on a lying body: the pool grows with the melt (storyboard pool_growth)
	for(var/grow_to in 1 to PLASMA_MELT_POOL_STEPS)
		var/when = plasma_melt_growth_time(grow_to / PLASMA_MELT_POOL_STEPS, melt_lying)
		addtimer(CALLBACK(src, PROC_REF(grow_pool), grow_to), max(when - PLASMA_MELT_HEAT_END, 1))

/// 1.6 s on: the stump bubbles, cools, then stays charred until the limb comes back
/datum/plasma_melt/proc/pose_stump(suffix, hot)
	if(!victim)
		return
	switch(suffix)
		if("stump_bubble")
			play("[zone]_stump_bubble", 16, 0.05 SECONDS)
		if("stump_cool")
			play("[zone]_stump_cool", 10, 0.2 SECONDS, hot = FALSE)
		else
			play_id++
			show(pair("[zone]_stump", "[zone]_stump_far", FALSE))
	if(suffix == "stump_bubble")
		limb_light?.set_light_power(is_far() ? 0.2 : 0.3)
	else if(suffix == "stump_cool")
		QDEL_NULL(limb_light)

/// Burns the jumpsuit sleeve away at this missing arm (masked on the uniform overlay, see update_worn_undersuit)
/datum/plasma_melt/proc/burn_sleeve()
	if(sleeve_burned || !ishuman(victim))
		return
	sleeve_burned = TRUE
	var/mob/living/carbon/human/wearer = victim
	wearer.update_worn_undersuit()

/// Where the pool lies on the victim's turf: in front of the feet standing, under the limb's place lying
/datum/plasma_melt/proc/find_pool_spot()
	var/list/geometry = GLOB.plasma_melt_geometry[zone]?["[melt_dir]"]
	if(!geometry)
		return
	var/body_x = victim.pixel_x + victim.pixel_w
	var/body_y = victim.pixel_y + victim.pixel_z
	if(!melt_lying)
		pool_x = round(geometry[1] - PLASMA_MELT_POOL_TILE_X + body_x)
		pool_y = round(PLASMA_MELT_POOL_TILE_Y - (PLASMA_MELT_FLOOR_ROW + PLASMA_MELT_POOL_FRONT) + body_y)
		return
	// the limb's middle, from the sprite centre (y up), through the body's lying turn
	var/u = geometry[2] - 15.5
	var/v = 15.5 - geometry[3]
	var/matrix/turn = victim.transform
	var/screen_x = turn.a * u + turn.b * v + turn.c
	var/screen_y = turn.d * u + turn.e * v + turn.f
	pool_x = round(screen_x + 0.5 + body_x)
	pool_y = round(screen_y + 5.5 + plasma_melt_lying_side(turn, u, v) * PLASMA_MELT_POOL_FRONT_LYING + body_y)

/// Row (sprite pixels from the top) where a drop lands: the top of the pool's middle
/datum/plasma_melt/proc/pool_top_row()
	return PLASMA_MELT_FLOOR_ROW + PLASMA_MELT_POOL_FRONT - 1

/// One gobbet leaves the hanging limb, falls and lands in the pool
/datum/plasma_melt/proc/release_drop(size, x, start_row, fall_time, grow_to, behind)
	if(!victim)
		return
	var/turf/here = get_turf(victim)
	if(!here)
		return
	if(moving())
		// a body on the move drips straight onto the floor under it, after it has arrived
		addtimer(CALLBACK(src, PROC_REF(drip_trail), size, x - PLASMA_MELT_POOL_TILE_X, PLASMA_MELT_POOL_TILE_Y - (PLASMA_MELT_FLOOR_ROW + PLASMA_MELT_POOL_FRONT), here), max(fall_time, PLASMA_MELT_GLIDE_WAIT))
		return
	var/body_x = victim.pixel_x + victim.pixel_w
	var/body_y = victim.pixel_y + victim.pixel_z
	var/obj/effect/temp_visual/plasma_melt_drop/drop = new(here, size, x - PLASMA_MELT_DROP_TILE + body_x, PLASMA_MELT_DROP_TILE - start_row + body_y, PLASMA_MELT_DROP_TILE - pool_top_row() + body_y, fall_time, behind)
	falling[drop] = list(size, x - PLASMA_MELT_POOL_TILE_X)
	addtimer(CALLBACK(src, PROC_REF(drop_landed), size, grow_to, drop, x), fall_time)

/datum/plasma_melt/proc/drop_landed(size, grow_to, obj/effect/temp_visual/plasma_melt_drop/drop, x)
	if(!(drop in falling)) // the body moved while it fell; it already landed under the body
		return
	falling -= drop
	if(!at_start())
		// the body moved on: the gobbet lands under it as a small splash that cools away
		if(!QDELETED(drop))
			qdel(drop)
		drip_trail(size, x - PLASMA_MELT_POOL_TILE_X, PLASMA_MELT_POOL_TILE_Y - (PLASMA_MELT_FLOOR_ROW + PLASMA_MELT_POOL_FRONT))
		return
	if(!pool)
		make_pool()
	if(!pool)
		return
	if(size > 1)
		new /obj/effect/temp_visual/plasma_melt_splat(pool.loc, pool.pixel_x, pool.pixel_y)
	grow_pool(grow_to)

/// A drip that missed the pool because the body moved: a splash and a small cooling spot under the body, gone in a
/// few seconds (the pool on the start tile holds the lasting slag). `here` is the tile the body was sliding onto when
/// the drip fell, so a body that keeps walking doesn't get drips landing a tile ahead of it.
/datum/plasma_melt/proc/drip_trail(size, px, py, turf/here)
	if(!victim)
		return
	here ||= get_turf(victim)
	if(!isopenturf(here))
		return
	px += victim.pixel_x + victim.pixel_w
	py += victim.pixel_y + victim.pixel_z
	if(size > 1)
		new /obj/effect/temp_visual/plasma_melt_splat(here, px, py)
	new /obj/effect/temp_visual/plasma_melt_drip_spot(here, px, py, size)

/// Under the limb's place on the body as it lies or stands now, as offsets for the pool tile
/datum/plasma_melt/proc/spot_now()
	var/list/geometry = GLOB.plasma_melt_geometry[zone]?["[victim.dir]"]
	if(!geometry)
		return list(0, 0)
	if(victim.body_position != LYING_DOWN)
		return list(round(geometry[1] - PLASMA_MELT_POOL_TILE_X), PLASMA_MELT_POOL_TILE_Y - (PLASMA_MELT_FLOOR_ROW + PLASMA_MELT_POOL_FRONT))
	var/u = geometry[2] - 15.5
	var/v = 15.5 - geometry[3]
	var/matrix/turn = victim.transform
	return list(round(turn.a * u + turn.b * v + turn.c + 0.5), round(turn.d * u + turn.e * v + turn.f + 5.5 + plasma_melt_lying_side(turn, u, v) * PLASMA_MELT_POOL_FRONT_LYING))

/datum/plasma_melt/proc/make_pool()
	if(!isopenturf(start_turf))
		return
	pool = new(start_turf)
	pool.pixel_x = pool_x
	pool.pixel_y = pool_y

/datum/plasma_melt/proc/grow_pool(grow_to)
	if(victim && !at_start())
		// a slumping limb on a body that has moved on runs off under it instead
		if(grow_to % 2 == 0)
			var/list/spot = spot_now()
			if(moving())
				addtimer(CALLBACK(src, PROC_REF(drip_trail), 1, spot[1], spot[2], get_turf(victim)), PLASMA_MELT_GLIDE_WAIT)
			else
				drip_trail(1, spot[1], spot[2])
		return
	if(!pool)
		make_pool()
	if(!pool || grow_to <= pool_step)
		return
	pool_step = grow_to
	pool.grow(grow_to)

/// 2.2 s: the pool crusts from the rim inward
/datum/plasma_melt/proc/pool_cool()
	pool?.start_cooling()

/// 4.5 s: the pool sets into a lasting slag decal (one per turf, capped)
/datum/plasma_melt/proc/pool_set()
	if(QDELETED(pool))
		pool = null
		return
	var/turf/here = get_turf(pool)
	if(pool_step >= PLASMA_MELT_POOL_STEPS / 2)
		plasma_slag_at(here, pool.pixel_x, pool.pixel_y)
		QDEL_NULL(pool)
		return
	// too little reached the pool to leave slag (the body moved off early): it cools away
	var/obj/effect/plasma_melt_pool/small = pool
	pool = null
	animate(small, alpha = 0, color = "#3a2a20", time = 2 SECONDS)
	QDEL_IN(small, 2 SECONDS)

/// 1 if the limb's spot (u, v from the sprite centre) is above the lying body's middle on screen, else -1:
/// the pool goes out past that side so the body doesn't hide it
/proc/plasma_melt_lying_side(matrix/turn, u, v)
	return (turn.d * u + turn.e * v) > 0 ? 1 : -1

/// Deciseconds a drop takes to fall `rows` pixels: the storyboard's fall(dt) = 30 dt + 260 dt^2 (dt in seconds)
/proc/plasma_melt_fall_time(rows)
	rows = max(rows, 1)
	var/seconds = (-30 + sqrt(900 + 1040 * rows)) / 520
	return max(round(seconds * 20) / 20, 0.05) * 1 SECONDS

/// When the pool of a slumping limb reaches `fraction` of its size (storyboard pool_growth), from the hit
/proc/plasma_melt_growth_time(fraction, lying)
	var/start = lying ? 0.08 : 0.2
	var/span = lying ? 0.92 : 0.8
	for(var/tick in 0 to 25)
		var/x = clamp((tick / 25 - start) / span, 0, 1)
		if(x * x * (3 - 2 * x) >= fraction - 0.001)
			return PLASMA_MELT_HEAT_END + tick * 0.05 SECONDS
	return PLASMA_MELT_GONE

/// Slag on `where`: keeps slag already there, otherwise makes new slag, dropping the oldest over `cap`
/proc/plasma_slag_at(turf/open/where, px = 0, py = 0, cap = PLASMA_SLAG_GLOBAL_CAP)
	if(!isopenturf(where))
		return null
	var/obj/effect/decal/cleanable/plasma_slag/slag = locate() in where
	if(slag)
		return slag
	while(length(GLOB.plasma_slag_decals) >= max(cap, 1))
		var/obj/effect/decal/cleanable/plasma_slag/oldest = GLOB.plasma_slag_decals[1]
		GLOB.plasma_slag_decals -= oldest
		qdel(oldest)
	slag = new(where)
	if(QDELETED(slag))
		return null
	slag.pixel_x = clamp(px, -16, 16)
	slag.pixel_y = clamp(py, -16, 16)
	return slag

// ===== Sleeve =====

/// A plasma-melted arm takes its jumpsuit sleeve with it: tg keeps the sleeve on a missing arm, so mask it off the
/// uniform overlay the way tg masks gloves on a missing hand. Only arms that melted, and only until they come back.
/mob/living/carbon/human/update_worn_undersuit(update_obscured = TRUE)
	. = ..(update_obscured)
	var/list/burned = list()
	for(var/zone in plasma_melts)
		var/datum/plasma_melt/melt = plasma_melts[zone]
		if(melt.sleeve_burned)
			burned += zone
	if(!length(burned))
		return
	var/mutable_appearance/uniform_overlay = overlays_standing[UNIFORM_LAYER]
	if(!istype(uniform_overlay))
		return
	remove_overlay(UNIFORM_LAYER)
	var/static/atom/movable/sleeve_mask
	if(isnull(sleeve_mask))
		sleeve_mask = new(null)
	for(var/zone in burned)
		sleeve_mask.icon = PLASMA_MELT_ICON
		sleeve_mask.icon_state = "[zone]_sleeve_mask"
		sleeve_mask.render_target = "*PlasmaSleeve [REF(src)] [zone]"
		uniform_overlay.add_overlay(sleeve_mask)
		uniform_overlay.filters += filter(type = "alpha", render_source = sleeve_mask.render_target, flags = MASK_INVERSE)
	overlays_standing[UNIFORM_LAYER] = uniform_overlay
	apply_overlay(UNIFORM_LAYER)

// ===== Effects =====

/// A gobbet falling off a hanging arm. Offsets use pixel_w/pixel_z so it keeps the body's row; layer alone puts it
/// in front of the body or, for a far arm, behind it.
/obj/effect/temp_visual/plasma_melt_drop
	icon = PLASMA_MELT_ICON
	icon_state = "drip_gob"
	layer = ABOVE_MOB_LAYER
	randomdir = FALSE
	duration = 1 SECONDS

/obj/effect/temp_visual/plasma_melt_drop/Initialize(mapload, size = 2, start_x = 0, start_y = 0, land_y = 0, fall_time = 0.2 SECONDS, behind = FALSE)
	duration = fall_time
	icon_state = list("drip_small", "drip_gob", "drip_big")[clamp(size, 1, 3)]
	. = ..()
	if(behind)
		layer = BELOW_MOB_LAYER
	pixel_w = start_x
	pixel_z = start_y
	add_overlay(emissive_appearance(icon, icon_state, src))
	animate(src, pixel_z = land_y, time = fall_time, easing = QUAD_EASING | EASE_IN)

/// The flash where a gobbet lands in the pool
/obj/effect/temp_visual/plasma_melt_splat
	icon = PLASMA_MELT_ICON
	icon_state = "splat"
	plane = FLOOR_PLANE
	layer = CLEANABLE_FLOOR_OBJECT_LAYER
	randomdir = FALSE
	duration = 0.15 SECONDS

/obj/effect/temp_visual/plasma_melt_splat/Initialize(mapload, px = 0, py = 0)
	. = ..()
	pixel_x = px
	pixel_y = py
	add_overlay(emissive_appearance(icon, icon_state, src))

/// A drip that landed away from the pool: a small hot spot that darkens and fades
/obj/effect/temp_visual/plasma_melt_drip_spot
	icon = PLASMA_MELT_ICON
	icon_state = "pool_1"
	plane = FLOOR_PLANE
	layer = CLEANABLE_FLOOR_OBJECT_LAYER
	randomdir = FALSE
	duration = 3 SECONDS

/obj/effect/temp_visual/plasma_melt_drip_spot/Initialize(mapload, px = 0, py = 0, size = 1)
	icon_state = size > 1 ? "pool_2" : "pool_1"
	. = ..()
	pixel_x = px
	pixel_y = py
	animate(src, color = "#3a2a20", time = 1.5 SECONDS)
	animate(alpha = 0, time = 1.5 SECONDS)

/// The molten pool while it grows and cools; it becomes slag when the melt sets
/obj/effect/plasma_melt_pool
	name = "molten slag"
	icon = PLASMA_MELT_ICON
	icon_state = null
	plane = FLOOR_PLANE
	layer = CLEANABLE_FLOOR_OBJECT_LAYER
	anchored = TRUE
	mouse_opacity = MOUSE_OPACITY_TRANSPARENT
	light_system = OVERLAY_LIGHT
	light_range = 1
	light_power = 0.2
	light_color = PLASMA_LIGHT_COLOR
	light_on = FALSE

/obj/effect/plasma_melt_pool/proc/grow(grow_to)
	icon_state = grow_to >= PLASMA_MELT_POOL_STEPS ? "pool_hot" : "pool_[grow_to]"
	glow()
	set_light_power(0.2 + 0.3 * grow_to / PLASMA_MELT_POOL_STEPS)
	set_light_on(TRUE)

/obj/effect/plasma_melt_pool/proc/start_cooling()
	icon_state = "slag_cool"
	glow()
	set_light_power(0.25)
	addtimer(CALLBACK(src, TYPE_PROC_REF(/atom, set_light_power), 0.12), 0.8 SECONDS)
	addtimer(CALLBACK(src, TYPE_PROC_REF(/atom, set_light_on), FALSE), 1.4 SECONDS)

/obj/effect/plasma_melt_pool/proc/glow()
	cut_overlays()
	add_overlay(emissive_appearance(icon, icon_state, src))

/// Light at the melting limb
/obj/effect/plasma_melt_light
	anchored = TRUE
	mouse_opacity = MOUSE_OPACITY_TRANSPARENT
	light_system = OVERLAY_LIGHT
	light_range = 1
	light_power = 0.5
	light_color = PLASMA_LIGHT_COLOR
	light_on = TRUE

/// What a plasma melt leaves on the floor
/obj/effect/decal/cleanable/plasma_slag
	name = "slag"
	desc = "A puddle of green-black slag, cooled hard."
	icon = PLASMA_MELT_ICON
	icon_state = "slag"
	beauty = -50

/obj/effect/decal/cleanable/plasma_slag/Initialize(mapload, list/datum/disease/diseases)
	. = ..()
	if(. == INITIALIZE_HINT_QDEL)
		return
	GLOB.plasma_slag_decals += src

/obj/effect/decal/cleanable/plasma_slag/Destroy()
	GLOB.plasma_slag_decals -= src
	return ..()

#undef PLASMA_MELT_ICON
#undef PLASMA_MELT_HEAT_END
#undef PLASMA_MELT_GONE
#undef PLASMA_MELT_STUMP_COOL
#undef PLASMA_MELT_POOL_COOL
#undef PLASMA_MELT_COOLED
#undef PLASMA_MELT_POOL_STEPS
#undef PLASMA_MELT_FLOOR_ROW
#undef PLASMA_MELT_POOL_FRONT
#undef PLASMA_MELT_POOL_FRONT_LYING
#undef PLASMA_MELT_POOL_TILE_X
#undef PLASMA_MELT_POOL_TILE_Y
#undef PLASMA_MELT_DROP_TILE
#undef PLASMA_MELT_GLIDE_WAIT
#undef PLASMA_SLAG_GLOBAL_CAP
