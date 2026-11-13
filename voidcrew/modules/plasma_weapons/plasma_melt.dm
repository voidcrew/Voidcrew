// Package: P1 bolt. The melt-off picture. The arm or leg comes off at once through tg's WOUND_BURN loss (state,
// damage and blood loss all as tg does them); the picture lags behind it. The limb as it was drawn heats up on the
// body, then melts in place from the hit joint: arms on a standing body hang and run off in gobbets that splash
// into a pool in front of the feet, legs and arms on a lying body slump into the pool. A molten stump bubbles,
// chars and stays on the body until the limb is put back or regrown. The pool cools into a lasting slag decal.
// tg's ash pile and its dismember blood splatter are not shown; the slag stands in for both.
// Every melt frame lives in a plasma_melt_<zone>.dmi in the body's own sprite space, so it turns with a lying body.
// One file per limb: a client loads a whole icon file the first time it draws from it, and all four limbs in one file
// stalled it for a few hundred ms when the first melt began. The pool, drops and slag share plasma_melt.dmi.
// Each body state comes as a pair: "<state>" holds the near facings and draws in front of the body,
// "<state>_far" holds only the facing where the limb is on the far side and draws behind it.

#define PLASMA_MELT_ICON 'voidcrew/modules/plasma_weapons/icons/plasma_melt.dmi'
/// The body frames, stumps and sleeve mask of one limb
#define PLASMA_MELT_ZONE_ICON(zone) (zone == BODY_ZONE_R_ARM ? 'voidcrew/modules/plasma_weapons/icons/plasma_melt_r_arm.dmi' : (zone == BODY_ZONE_L_ARM ? 'voidcrew/modules/plasma_weapons/icons/plasma_melt_l_arm.dmi' : (zone == BODY_ZONE_R_LEG ? 'voidcrew/modules/plasma_weapons/icons/plasma_melt_r_leg.dmi' : 'voidcrew/modules/plasma_weapons/icons/plasma_melt_l_leg.dmi')))

/// Key moments, from the hit
#define PLASMA_MELT_HEAT_END (0.35 SECONDS)
#define PLASMA_MELT_GONE (1.6 SECONDS)
/// The hand has run off: a held item falls out of it (storyboard: the third gobbet, 1.14 s)
#define PLASMA_MELT_LET_GO (1.15 SECONDS)
#define PLASMA_MELT_STUMP_COOL (2.4 SECONDS)
#define PLASMA_MELT_POOL_COOL (2.2 SECONDS)
#define PLASMA_MELT_COOLED (4.5 SECONDS)

/// Pool growth steps in the DMI (pool_1 .. pool_N)
#define PLASMA_MELT_POOL_STEPS 8
/// Feet row of a standing body, from the top of its 32x32 sprite (0-based)
#define PLASMA_MELT_FLOOR_ROW 30
/// How far below the feet the pool sits on a standing body, so it reads in front of them
#define PLASMA_MELT_POOL_FRONT 4
/// The same for an arm on a lying body: how far out past where the arm lay, so the torso doesn't cover the pool.
/// A leg's pool stays on the leg's line at the foot end.
#define PLASMA_MELT_POOL_FRONT_LYING 2
/// Row and column of the pool's centre in its own 32x32 tile (pool, splat and slag states)
#define PLASMA_MELT_POOL_TILE_X 15
#define PLASMA_MELT_POOL_TILE_Y 21
/// Row and column of a falling drop's lowest pixel in its own tile
#define PLASMA_MELT_DROP_TILE 16
/// Rows (from the sprite top) where a standing body's hand and foot are, for a dropped item's fall
#define PLASMA_MELT_HAND_ROW 22
#define PLASMA_MELT_FOOT_ROW 30
/// Where a dropped item's middle comes to rest, below the sprite centre: beside the feet standing, under a lying body
#define PLASMA_MELT_ITEM_FLOOR -13
#define PLASMA_MELT_ITEM_FLOOR_LYING -16
/// How far to the side of a standing body's middle a dropped item comes to rest, clear of the other foot
#define PLASMA_MELT_ITEM_SIDE 11
/// Cooldown key: limbs melting off one body together make one melt sound
#define COOLDOWN_PLASMA_MELT_SOUND "plasma_melt_sound"
/// While the body slid onto its tile this recently, drips fall straight to the floor under it
#define PLASMA_MELT_GLIDE_WAIT (0.4 SECONDS)

/// Most slag decals in the world at once; the oldest goes first
#define PLASMA_SLAG_GLOBAL_CAP 150
/// A no-flesh limb's pool: it grows in this many steps this far apart, crusts, then sets into slag
#define PLASMA_DRY_POOL_STEPS 4
#define PLASMA_DRY_POOL_STEP_TIME (0.1 SECONDS)
#define PLASMA_DRY_POOL_COOL (1.2 SECONDS)
#define PLASMA_DRY_POOL_SET (3.5 SECONDS)

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
/// The carbon whose limb is melting off right now, while tg's dismember runs: its blood loss stays, its splatter doesn't.
/// A weakref, so a runtime inside the dismember can't leave a hard ref to the body behind.
GLOBAL_DATUM(plasma_melt_no_splatter, /datum/weakref)

/// The plasma melts on this body by zone; each keeps its stump drawn until that limb comes back
/mob/living/carbon/var/list/plasma_melts

/// Melts `limb` off its owner through tg's burn loss and plays the melt over the body. Returns TRUE if it came off.
/proc/plasma_melt_limb(obj/item/bodypart/limb, attack_direction)
	var/mob/living/carbon/victim = limb?.owner
	if(!victim)
		return FALSE
	var/zone = limb.body_zone
	if(!plasma_limb_is_flesh(limb))
		return plasma_melt_limb_dry(limb, attack_direction)
	var/list/drawn = plasma_melt_capture(victim, limb)
	// tg drops what this limb wore or held the moment it comes off; keep their look on the body while it melts
	var/list/worn_look = list()
	var/mutable_appearance/shoes_look
	var/list/may_drop = list()
	if(istype(limb, /obj/item/bodypart/arm))
		var/obj/item/bodypart/arm/arm = limb
		var/obj/item/held = victim.get_item_for_held_index(arm.held_index)
		if(held)
			var/icon_file = IS_RIGHT_INDEX(arm.held_index) ? held.righthand_file : held.lefthand_file
			worn_look += held.build_worn_icon(default_layer = HANDS_LAYER, default_icon_file = icon_file, isinhands = TRUE)
			may_drop[held] = "held"
		if(istype(victim.overlays_standing[GLOVES_LAYER], /mutable_appearance))
			worn_look += new /mutable_appearance(victim.overlays_standing[GLOVES_LAYER])
		if(victim.gloves)
			may_drop[victim.gloves] = "worn"
	else if(victim.shoes)
		if(istype(victim.overlays_standing[SHOES_LAYER], /mutable_appearance))
			shoes_look = new /mutable_appearance(victim.overlays_standing[SHOES_LAYER])
		may_drop[victim.shoes] = "worn"
	var/turf/where = get_turf(victim)
	var/list/old_ash = list()
	for(var/obj/effect/decal/cleanable/ash/pile in where)
		old_ash += pile
	var/datum/wound/loss/melt = new
	// The melt sound below is the only one: no tg dismember sound (see plasma_melt_in_progress())
	melt.sound_effect = null
	GLOB.plasma_melt_no_splatter = WEAKREF(victim)
	// Hyperviolence (#512): a melt is dry. hv_sever_spray holds back the spray a lost limb throws and the reel
	// a body gives (wire_seams.dm), and the stump is drawn seared, as a hot wire's is. TRAIT_HV_CLEAN_CUT
	// isn't used: mid clean cut the wire's own apply_dismember() would take the limb instead of the melt.
	var/old_sever_spray = victim.hv_sever_spray
	victim.hv_sever_spray = 0
	LAZYSET(victim.hv_stump_burnt, zone, TRUE)
	melt.apply_dismember(limb, WOUND_BURN, FALSE, attack_direction)
	GLOB.plasma_melt_no_splatter = null
	if(!QDELETED(victim))
		victim.hv_sever_spray = old_sever_spray
		if(victim.get_bodypart(zone) == limb)
			LAZYREMOVE(victim.hv_stump_burnt, zone)
		else
			// drop_limb() marked the stump fresh (wet); a seared stump never was
			LAZYREMOVE(victim.hv_stump_torn_at, zone)
			victim.hv_update_gore_overlays()
	// tg leaves an ash pile from the burnt limb; the slag is the remains here
	for(var/obj/effect/decal/cleanable/ash/pile in where)
		if(!(pile in old_ash))
			qdel(pile)
	if(QDELETED(victim) || victim.get_bodypart(zone) == limb)
		return FALSE
	var/list/dropped = list()
	for(var/obj/item/thing as anything in may_drop)
		if(!QDELETED(thing) && thing.loc != victim)
			dropped[thing] = may_drop[thing]
	new /datum/plasma_melt(victim, zone, drawn, worn_look, shoes_look, dropped)
	if(ishuman(victim))
		// Hyperviolence (#512) cut the sleeve the moment the arm came off; it stays until the melt burns it
		victim.hv_update_gore_overlays()
	if(!TIMER_COOLDOWN_RUNNING(victim, COOLDOWN_PLASMA_MELT_SOUND))
		TIMER_COOLDOWN_START(victim, COOLDOWN_PLASMA_MELT_SOUND, 0.5 SECONDS)
		playsound(victim, 'voidcrew/modules/plasma_weapons/sound/plasma_melt.ogg', 60, TRUE)
	return TRUE

/// FALSE for a limb with no flesh to melt: robotic, or bone, stone or plasma with no BIO_FLESH
/proc/plasma_limb_is_flesh(obj/item/bodypart/limb)
	return (limb.biological_state & BIO_FLESH) && !(limb.bodytype & BODYTYPE_ROBOTIC)

/// A limb with no flesh melts off without the flesh look: tg's dismember, a slag pool, sparks and a hiss of
/// hot metal. No gobbets, no stump and no wet sound. TRUE if it came off.
/proc/plasma_melt_limb_dry(obj/item/bodypart/limb, attack_direction)
	var/mob/living/carbon/victim = limb.owner
	var/zone = limb.body_zone
	var/turf/where = get_turf(victim)
	// where the limb runs off, taken before it comes off: a lost leg drops the body
	var/list/spot = plasma_melt_floor_spot(victim, zone)
	var/pool_x = spot[1] + victim.pixel_x + victim.pixel_w
	var/pool_y = spot[2] + victim.pixel_y + victim.pixel_z
	var/list/old_ash = list()
	for(var/obj/effect/decal/cleanable/ash/pile in where)
		old_ash += pile
	var/datum/wound/loss/melt = new
	melt.sound_effect = null
	GLOB.plasma_melt_no_splatter = WEAKREF(victim)
	// Hyperviolence (#512), as in plasma_melt_limb(): no reel, spray or hit-stop, and a seared stump, not a wet one
	var/old_sever_spray = victim.hv_sever_spray
	victim.hv_sever_spray = 0
	LAZYSET(victim.hv_stump_burnt, zone, TRUE)
	melt.apply_dismember(limb, WOUND_BURN, FALSE, attack_direction)
	GLOB.plasma_melt_no_splatter = null
	if(!QDELETED(victim))
		victim.hv_sever_spray = old_sever_spray
		if(victim.get_bodypart(zone) == limb)
			LAZYREMOVE(victim.hv_stump_burnt, zone)
		else
			LAZYREMOVE(victim.hv_stump_torn_at, zone)
			victim.hv_update_gore_overlays()
	for(var/obj/effect/decal/cleanable/ash/pile in where)
		if(!(pile in old_ash))
			qdel(pile)
	if(QDELETED(victim) || victim.get_bodypart(zone) == limb)
		return FALSE
	plasma_dry_pool(where, pool_x, pool_y)
	new /obj/effect/temp_visual/plasma_dry_sparks(where)
	if(!TIMER_COOLDOWN_RUNNING(victim, COOLDOWN_PLASMA_MELT_SOUND))
		TIMER_COOLDOWN_START(victim, COOLDOWN_PLASMA_MELT_SOUND, 0.5 SECONDS)
		playsound(victim, PLASMA_SOUND_METAL_MELT, 60, TRUE)
	return TRUE

/// TRUE while a plasma melt is taking this body's limb. tg's dismember() checks it to skip its own sound (VOIDCREW EDIT).
/proc/plasma_melt_in_progress(mob/living/body)
	return GLOB.plasma_melt_no_splatter && GLOB.plasma_melt_no_splatter.resolve() == body

/// tg's dismember bleeds the body; on a plasma melt the blood is lost but no splatter lands (the slag stands in)
/mob/living/add_splatter_floor(turf/splatter_turf, small_drip = FALSE)
	if(GLOB.plasma_melt_no_splatter && GLOB.plasma_melt_no_splatter.resolve() == src)
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
	/// TRUE once the jumpsuit and coat sleeves at this (arm) zone have burned away
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
	/// What the limb wore or held, drawn with it while it heats (gloves and the held item's in-hand look)
	var/list/worn_look
	/// The shoes as worn; tg drops both, so the other foot keeps this look (masked off the melting leg) until the snap
	var/mutable_appearance/shoes_look
	var/mutable_appearance/shoes_masked
	/// Items tg dropped when the limb came off, hidden until they fall out of the melt: item = "held" or "worn"
	var/list/hidden_items = list()
	/// world.time the body last changed tiles, the way it went and how long its slide takes
	var/last_moved = -INFINITY
	var/last_move_dir = 0
	var/glide_time = 0

/datum/plasma_melt/New(mob/living/carbon/victim, zone, list/drawn, list/worn_look, mutable_appearance/shoes_look, list/dropped)
	src.victim = victim
	src.zone = zone
	src.drawn = drawn
	src.worn_look = worn_look || list()
	src.shoes_look = shoes_look
	for(var/obj/item/thing as anything in dropped)
		hide_item(thing, dropped[thing])
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
		// with the melt gone, #512 masks the arm like any other lost arm (or not at all, if it came back)
		sleeve_burned = FALSE
		if(ishuman(victim) && !QDELETED(victim))
			victim.hv_update_gore_overlays()
	victim = null
	start_turf = null
	for(var/obj/item/thing as anything in hidden_items)
		if(hidden_items[thing] != "landed")
			on_hidden_item_moved(thing)
			continue
		// an item still lying where it fell stays put as a plain floor item: its drop goes into pixel_y
		UnregisterSignal(thing, list(COMSIG_MOVABLE_MOVED, COMSIG_QDELETING))
		animate(thing)
		thing.pixel_y += thing.pixel_z - thing.base_pixel_z
		thing.pixel_z = thing.base_pixel_z
		thing.transform = matrix(thing.transform).Turn(thing.icon_angle)
	hidden_items.Cut()
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
/// when the body moves would hang where the body was, so it drops onto the floor under the body right away.
/datum/plasma_melt/proc/on_moved(atom/movable/source, atom/old_loc, dir, forced, list/old_locs)
	SIGNAL_HANDLER
	var/turf/here = get_turf(victim)
	if(!here)
		return
	last_moved = world.time
	last_move_dir = get_dir(old_loc, here)
	glide_time = victim.glide_size > 0 ? (ICON_SIZE_X / victim.glide_size) * world.tick_lag : 0
	if(get_dist(old_loc, here) > 1)
		glide_time = 0 // a jump, not a slide
	if(limb_light)
		limb_light.set_glide_size(victim.glide_size)
		limb_light.forceMove(here)
	for(var/obj/effect/temp_visual/plasma_melt_drop/drop as anything in falling)
		drip_trail(falling[drop][1], falling[drop][2], PLASMA_MELT_POOL_TILE_Y - (PLASMA_MELT_FLOOR_ROW + PLASMA_MELT_POOL_FRONT))
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
		mutable_appearance(PLASMA_MELT_ZONE_ICON(zone), near_state, -BODY_FRONT_LAYER),
		mutable_appearance(PLASMA_MELT_ZONE_ICON(zone), far_state, -BODY_BEHIND_LAYER),
	)
	if(hot)
		. += emissive_appearance(PLASMA_MELT_ZONE_ICON(zone), near_state, victim, -BODY_FRONT_LAYER)
		. += emissive_appearance(PLASMA_MELT_ZONE_ICON(zone), far_state, victim, -BODY_BEHIND_LAYER)

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
		pieces += worn_look
		if(shoes_look)
			pieces += shoes_look
		pieces += mutable_appearance(PLASMA_MELT_ZONE_ICON(zone), "[base]_[frame]", -BODY_FRONT_LAYER)
		pieces += emissive_appearance(PLASMA_MELT_ZONE_ICON(zone), "[base]_[frame]", victim, -BODY_FRONT_LAYER)
	else
		pieces = pair("[base]_[frame]", "[base]_far_[frame]", hot)
		if(shoes_masked)
			pieces += shoes_masked
		// the held item stays in the slumping hand until it lets go (its in-hand look is first in worn_look)
		for(var/obj/item/thing as anything in hidden_items)
			if(hidden_items[thing] == "held")
				pieces += worn_look[1]
				break
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
	if(shoes_look)
		shoes_masked = mask_off_limb(shoes_look)
	melt_dir = victim.dir
	melt_lying = victim.body_position == LYING_DOWN
	play((is_arm() && melt_lying) ? "[zone]_melt_floor" : "[zone]_melt", 25, 0.05 SECONDS)
	if(is_arm())
		burn_sleeve()
	// a held item falls out once the hand has run off
	addtimer(CALLBACK(src, PROC_REF(reveal_items), "held"), PLASMA_MELT_LET_GO - PLASMA_MELT_HEAT_END)
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
			// the last of the limb lets go: what it wore lands on the floor
			shoes_masked = null
			reveal_items()
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

/// A copy of `look` with this limb's pixels cut out of it, in every facing
/datum/plasma_melt/proc/mask_off_limb(mutable_appearance/look)
	var/mutable_appearance/masked = new(look)
	var/static/atom/movable/limb_mask
	if(isnull(limb_mask))
		limb_mask = new(null)
	limb_mask.icon = PLASMA_MELT_ZONE_ICON(zone)
	limb_mask.icon_state = "[zone]_sleeve_mask"
	limb_mask.render_target = "*PlasmaMeltWorn [REF(victim)] [zone]"
	masked.add_overlay(limb_mask)
	masked.filters += filter(type = "alpha", render_source = limb_mask.render_target, flags = MASK_INVERSE)
	return masked

/// Hides an item tg dropped off the melting limb until it falls out of the melt. Only its look changes; anyone who
/// picks it up or moves it gets it back at once.
/datum/plasma_melt/proc/hide_item(obj/item/thing, kind)
	// A human NPC's gear is locked to its body (human_npc_gear.dm) and is deleted the tick it lands on the floor.
	// A look-alike that can't be touched falls out of the melt in its place and sinks into the slag.
	if(HAS_TRAIT(thing, TRAIT_HUMAN_NPC_GEAR) && isturf(thing.loc))
		thing = new /obj/item/plasma_melt_lost_gear(thing.loc, thing)
	hidden_items[thing] = kind
	thing.alpha = 0
	RegisterSignals(thing, list(COMSIG_MOVABLE_MOVED, COMSIG_QDELETING), PROC_REF(on_hidden_item_moved))

/// Shows a hidden item as it always looks. One that fell out of the melt lies drawn lower and turned flat on its
/// tile; once anyone moves it, it sits at its tile's middle with its own look.
/datum/plasma_melt/proc/on_hidden_item_moved(obj/item/source)
	SIGNAL_HANDLER
	UnregisterSignal(source, list(COMSIG_MOVABLE_MOVED, COMSIG_QDELETING))
	if(hidden_items[source] == "landed")
		animate(source)
		source.pixel_x = source.base_pixel_x
		source.pixel_y = source.base_pixel_y
		source.pixel_z = source.base_pixel_z
		source.transform = matrix(source.transform).Turn(source.icon_angle)
	hidden_items -= source
	source.alpha = initial(source.alpha)

/// Shows a hidden item falling out of the melt, from the hand or foot as the body stands or lies now, to the floor
/// beside the feet (standing) or under the body (lying). tg's own drop animation played while it was hidden, so this
/// stands in for it. The item stays on the body's row and drops through pixel_z, so it draws under the body the
/// whole way, as a dropped item does.
/datum/plasma_melt/proc/reveal_item(obj/item/thing)
	var/kind = hidden_items[thing]
	var/list/geometry = victim && GLOB.plasma_melt_geometry[zone]?["[victim.dir]"]
	if(!geometry || QDELETED(thing) || thing.loc != get_turf(victim) || moving())
		on_hidden_item_moved(thing)
		return
	hidden_items[thing] = "landed"
	thing.alpha = initial(thing.alpha)
	var/lying = victim.body_position == LYING_DOWN
	// the hand or foot, from the sprite centre (y up)
	var/u = geometry[1] - 15.5
	var/v = 15.5 - (is_arm() ? PLASMA_MELT_HAND_ROW : PLASMA_MELT_FOOT_ROW)
	if(lying)
		var/matrix/turn = victim.transform
		var/screen_x = geometry[2] - 15.5
		var/screen_y = 15.5 - geometry[3]
		u = turn.a * screen_x + turn.b * screen_y + turn.c
		v = turn.d * screen_x + turn.e * screen_y + turn.f
	else if(kind == "held" && length(geometry[4]))
		var/list/drop = geometry[4][1]
		u = drop[3] - 15.5
	var/body_x = victim.pixel_x + victim.pixel_w
	// beside the feet on the limb's side facing N or S, behind the heels facing E or W
	var/side = u < 0 ? -1 : 1
	if(victim.dir == EAST)
		side = -1
	else if(victim.dir == WEST)
		side = 1
	var/from_x = thing.base_pixel_x + round(u + body_x)
	var/from_y = thing.base_pixel_z + round(v + victim.pixel_z)
	var/to_x = thing.base_pixel_x + (lying ? clamp(round(u + body_x) + rand(-2, 2), -10, 10) : round(body_x) + side * (PLASMA_MELT_ITEM_SIDE + rand(0, 2)))
	var/to_y = thing.base_pixel_z + victim.pixel_z + (lying ? PLASMA_MELT_ITEM_FLOOR_LYING : PLASMA_MELT_ITEM_FLOOR) + rand(-1, 1)
	to_y = min(to_y, from_y - 1)
	// starts the size and angle it had in the hand (or on the foot) and ends flat on the floor
	var/matrix/old_transform = thing.transform
	var/matrix/animation_matrix = matrix(old_transform)
	animation_matrix.Scale(kind == "held" ? 0.6 : 0.85)
	animation_matrix.Turn(pick(-25, 25))
	animate(thing)
	thing.pixel_y = thing.base_pixel_y + victim.pixel_y
	thing.pixel_x = from_x
	thing.pixel_z = from_y
	thing.transform = animation_matrix
	old_transform = matrix(old_transform).Turn(-thing.icon_angle)
	var/fall_time = plasma_melt_fall_time(from_y - to_y)
	if(from_y - to_y < 6)
		// a short drop (shoes off a foot already at the floor) tips up and over to the side instead
		fall_time = 0.1 SECONDS
		animate(thing, pixel_x = (from_x + to_x) / 2, pixel_z = from_y + 3, transform = matrix(animation_matrix).Turn(pick(-15, 15)), time = fall_time, easing = QUAD_EASING | EASE_OUT)
		animate(pixel_x = to_x, pixel_z = to_y, transform = old_transform, time = fall_time + 0.05 SECONDS, easing = QUAD_EASING | EASE_IN)
	else
		// never quicker than 0.2 s, so it is seen shrinking out of the hand and turning flat as it drops
		animate(thing, pixel_x = to_x, pixel_z = to_y, transform = old_transform, time = max(fall_time, 0.2 SECONDS), easing = QUAD_EASING | EASE_IN)
	animate(pixel_z = to_y + 1, time = 0.05 SECONDS)
	animate(pixel_z = to_y, time = 0.05 SECONDS)

/// Lets the hidden items of one `kind`, or all of them, fall out of the melt
/datum/plasma_melt/proc/reveal_items(kind)
	for(var/obj/item/thing as anything in hidden_items)
		if(hidden_items[thing] != "landed" && (!kind || hidden_items[thing] == kind))
			reveal_item(thing)

/// Burns the jumpsuit and coat sleeves away at this missing arm. Hyperviolence (#512) does the cutting, with the mask it
/// uses for every lost arm (hv_mask_sleeves()); that mask leaves the chest's own pixels alone, so no chest is bared.
/datum/plasma_melt/proc/burn_sleeve()
	if(sleeve_burned || !ishuman(victim))
		return
	sleeve_burned = TRUE
	var/mob/living/carbon/human/wearer = victim
	wearer.hv_update_gore_overlays()

// Hyperviolence (#512) cuts a lost arm's sleeve off the jumpsuit and suit at once (sleeve_mask.dm). A melting arm keeps
// its sleeve until the sleeve burns (burn_sleeve()), so the melt plays on the arm as it was dressed. Under #512 this is the
// only sleeve cut: #540's own jumpsuit and coat masks are left out here, and the redraws go through
// hv_update_gore_overlays() so #512's record of what it last cut stays true.
/mob/living/carbon/human/hv_sleeve_mask_zones()
	. = ..()
	for(var/zone in plasma_melts)
		var/datum/plasma_melt/melt = plasma_melts[zone]
		if(melt.is_arm() && !melt.sleeve_burned)
			. -= zone

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
	pool_y = round(screen_y + 5.5 + plasma_melt_lying_side(turn, u, v) * lying_front() + body_y)

/// How far a lying body's pool sits out past the limb's place: arms clear the torso, legs stay on the leg's line
/datum/plasma_melt/proc/lying_front()
	return is_arm() ? PLASMA_MELT_POOL_FRONT_LYING : 0

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
		// a body on the move drips onto the floor under wherever it is when the drip lands
		addtimer(CALLBACK(src, PROC_REF(drip_trail), size, x - PLASMA_MELT_POOL_TILE_X, PLASMA_MELT_POOL_TILE_Y - (PLASMA_MELT_FLOOR_ROW + PLASMA_MELT_POOL_FRONT)), fall_time)
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
/// few seconds (the pool on the start tile holds the lasting slag). A body still sliding onto its tile is drawn
/// part of the way back, so the drip lands under where the body is seen, not where its tile is.
/datum/plasma_melt/proc/drip_trail(size, px, py)
	if(!victim)
		return
	var/turf/here = get_turf(victim)
	if(!isopenturf(here))
		return
	px += victim.pixel_x + victim.pixel_w
	py += victim.pixel_y + victim.pixel_z
	var/left = glide_time - (world.time - last_moved)
	if(left > 0 && last_move_dir)
		var/behind = ICON_SIZE_X * left / glide_time
		if(last_move_dir & EAST)
			px -= behind
		if(last_move_dir & WEST)
			px += behind
		if(last_move_dir & NORTH)
			py -= behind
		if(last_move_dir & SOUTH)
			py += behind
	px = round(px)
	py = round(py)
	if(size > 1)
		new /obj/effect/temp_visual/plasma_melt_splat(here, px, py)
	new /obj/effect/temp_visual/plasma_melt_drip_spot(here, px, py, size)

/// Under the limb's place on the body as it lies or stands now, as offsets for the pool tile
/datum/plasma_melt/proc/spot_now()
	return plasma_melt_floor_spot(victim, zone)

/// Where a melting `zone` of `victim` runs onto the floor, as it stands or lies now, as offsets for the pool tile: in
/// front of the feet standing, under the limb's place lying (an arm out past it, so the torso doesn't cover the pool)
/proc/plasma_melt_floor_spot(mob/living/carbon/victim, zone)
	var/list/geometry = GLOB.plasma_melt_geometry[zone]?["[victim.dir]"]
	if(!geometry)
		return list(0, 0)
	if(victim.body_position != LYING_DOWN)
		return list(round(geometry[1] - PLASMA_MELT_POOL_TILE_X), PLASMA_MELT_POOL_TILE_Y - (PLASMA_MELT_FLOOR_ROW + PLASMA_MELT_POOL_FRONT))
	var/u = geometry[2] - 15.5
	var/v = 15.5 - geometry[3]
	var/matrix/turn = victim.transform
	var/front = (zone == BODY_ZONE_R_ARM || zone == BODY_ZONE_L_ARM) ? PLASMA_MELT_POOL_FRONT_LYING : 0
	return list(round(turn.a * u + turn.b * v + turn.c + 0.5), round(turn.d * u + turn.e * v + turn.f + 5.5 + plasma_melt_lying_side(turn, u, v) * front))

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

/// The pool of a limb with no flesh (plasma_melt_limb_dry()): the metal or bone runs out at once, crusts and sets into slag
/proc/plasma_dry_pool(turf/open/where, px, py)
	if(!isopenturf(where))
		return null
	var/obj/effect/plasma_melt_pool/pool = new(where)
	pool.pixel_x = clamp(px, -16, 16)
	pool.pixel_y = clamp(py, -16, 16)
	for(var/step in 1 to PLASMA_DRY_POOL_STEPS)
		var/grow_to = round(step * PLASMA_MELT_POOL_STEPS / PLASMA_DRY_POOL_STEPS)
		addtimer(CALLBACK(pool, TYPE_PROC_REF(/obj/effect/plasma_melt_pool, grow), grow_to), (step - 1) * PLASMA_DRY_POOL_STEP_TIME)
	addtimer(CALLBACK(pool, TYPE_PROC_REF(/obj/effect/plasma_melt_pool, start_cooling)), PLASMA_DRY_POOL_COOL)
	addtimer(CALLBACK(pool, TYPE_PROC_REF(/obj/effect/plasma_melt_pool, set_slag)), PLASMA_DRY_POOL_SET)
	return pool

/// The sparks of a limb with no flesh melting off. tg's do_sparks() sparks drift for two seconds with their light on;
/// these burst once where the limb was and go out. They still heat the floor as sparks do, so they can light a fire.
/obj/effect/temp_visual/plasma_dry_sparks
	icon = 'icons/effects/effects.dmi'
	icon_state = "sparks"
	layer = ABOVE_MOB_LAYER
	duration = 0.7 SECONDS
	light_system = OVERLAY_LIGHT
	light_range = 1.5
	light_power = 0.8
	light_color = LIGHT_COLOR_FIRE
	light_on = TRUE

/obj/effect/temp_visual/plasma_dry_sparks/Initialize(mapload)
	. = ..()
	flick(icon_state, src)
	playsound(src, SFX_SPARKS, 100, TRUE, SHORT_RANGE_SOUND_EXTRARANGE)
	var/turf/open/where = loc
	if(isopenturf(where))
		where.hotspot_expose(1000, 100)
	addtimer(CALLBACK(src, TYPE_PROC_REF(/atom, set_light_power), 0.4), 0.2 SECONDS)
	addtimer(CALLBACK(src, TYPE_PROC_REF(/atom, set_light_on), FALSE), 0.4 SECONDS)

/// The pool sets into a lasting slag decal where it lies
/obj/effect/plasma_melt_pool/proc/set_slag()
	plasma_slag_at(get_turf(src), pixel_x, pixel_y)
	qdel(src)

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
	desc = "A puddle of purple-black slag, cooled hard."
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
#undef PLASMA_MELT_ZONE_ICON
#undef PLASMA_MELT_HEAT_END
#undef PLASMA_MELT_GONE
#undef PLASMA_MELT_LET_GO
#undef PLASMA_MELT_HAND_ROW
#undef PLASMA_MELT_FOOT_ROW
#undef PLASMA_MELT_ITEM_FLOOR
#undef PLASMA_MELT_ITEM_FLOOR_LYING
#undef PLASMA_MELT_ITEM_SIDE
#undef COOLDOWN_PLASMA_MELT_SOUND
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
#undef PLASMA_DRY_POOL_STEPS
#undef PLASMA_DRY_POOL_STEP_TIME
#undef PLASMA_DRY_POOL_COOL
#undef PLASMA_DRY_POOL_SET

/// The look of a human NPC's locked gear (human_npc_gear.dm) falling out of a melt. It can't be clicked, picked up or
/// moved, and sinks into the slag a moment after it lands, so the gear is never loot.
/obj/item/plasma_melt_lost_gear
	item_flags = ABSTRACT
	anchored = TRUE
	move_resist = INFINITY
	resistance_flags = INDESTRUCTIBLE | LAVA_PROOF | FIRE_PROOF | ACID_PROOF

/obj/item/plasma_melt_lost_gear/Initialize(mapload, obj/item/gear)
	. = ..()
	if(gear)
		appearance = gear.appearance
		base_pixel_x = gear.base_pixel_x
		base_pixel_y = gear.base_pixel_y
		base_pixel_z = gear.base_pixel_z
		icon_angle = gear.icon_angle
	mouse_opacity = MOUSE_OPACITY_TRANSPARENT
	addtimer(CALLBACK(src, PROC_REF(sink)), 2.6 SECONDS)

/obj/item/plasma_melt_lost_gear/proc/sink()
	animate(src, alpha = 0, time = 0.6 SECONDS, flags = ANIMATION_PARALLEL)
	QDEL_IN(src, 0.6 SECONDS)
