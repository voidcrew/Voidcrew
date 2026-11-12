// Package: P8 effects. Impact splash, wall glow, floor soot, gutter-out, vent puff, the near-miss
// hiss and the distant firing sound.
//
// Every effect here hangs off a real event (a hit, a bolt running out of range, a vent) and changes no
// game state. Lights are OVERLAY_LIGHT only, steam uses the shared particle pool, wall glows are capped
// per z-level and soot is capped globally.

/// Furthest a distant firing sound carries, in tiles
#define PLASMA_FAR_SOUND_RANGE 40
/// Distant sound volume at the near edge of its band
#define PLASMA_FAR_SOUND_VOL_NEAR 60
/// Distant sound volume at PLASMA_FAR_SOUND_RANGE
#define PLASMA_FAR_SOUND_VOL_FAR 30
/// A bolt must be this many tiles from where it was fired before it hisses past anyone
#define PLASMA_HISSBY_MIN_TRAVEL 3
/// Shared particle pool for the flesh splash's steam, kept apart because its holders take the splash's layer
#define PLASMA_SPLASH_STEAM_KEY "plasma_splash_steam"
/// Person-hit burst looks: molten splatter, flash and ring, burn-through
#define PLASMA_BURST_SPLATTER "A"
#define PLASMA_BURST_FLASH "B"
#define PLASMA_BURST_THROUGH "C"
/// Longest a burst's frames run, floor slag included
#define PLASMA_BURST_DURATION (2.7 SECONDS)
/// How long a burst waits after the hit before it shows: the bolt's sprite still has this far to fly on
/// the client, and the flash belongs where it stops
#define PLASMA_BURST_DELAY (1 TICKS)
/// How far up a shield splash behind a standing body sits, so it shows over the shoulders
#define PLASMA_SHIELD_BACK_RAISE 11

/// Live wall and soot glows per z-level, keyed by "[z]"
GLOBAL_LIST_EMPTY(plasma_wall_glows_by_z)

// ===== Bolt core =====

/obj/projectile/energy/plasma_bolt
	/// Emissive mask for the bolt's white core, so it stays bright in the dark
	var/core_state = "plasma_core"

/obj/projectile/energy/plasma_bolt/heavy
	core_state = "plasma_core_heavy"

/obj/projectile/energy/plasma_bolt/Initialize(mapload)
	. = ..()
	update_appearance(UPDATE_OVERLAYS)

/obj/projectile/energy/plasma_bolt/update_overlays()
	. = ..()
	. += emissive_appearance(icon, core_state, src)

// ===== Calls from the bolt (P1) =====

/// Splash, wall glow and soot for a bolt hitting `target`
/obj/projectile/energy/plasma_bolt/proc/plasma_impact_visuals(atom/target, blocked)
	var/turf/target_turf = get_turf(target)
	if(!target_turf)
		return

	var/splash_state = "splash_wall"
	var/turn_angle = angle
	var/behind_body = FALSE
	var/splash_x = impact_x
	var/splash_y = impact_y
	var/at_shield = FALSE
	if(ishuman(target))
		var/mob/living/carbon/human/victim = target
		var/side = REVERSE_DIR(angle2dir_cardinal(angle))
		if(blocked < 100)
			burst_ref = WEAKREF(new /obj/effect/temp_visual/plasma_burst(target_turf, victim, src, side))
			return
		plasma_take_back_block_star(target_turf)
		behind_body = (side == NORTH && !victim.lying_angle)
		// A held shield takes it on the shooter's side of the body
		var/obj/item/shield/shield = locate() in victim.held_items
		if(shield)
			at_shield = TRUE
			// Facing a shot from the south, the shield is out to one side of the chest, on the hand it is in
			var/list/hit = plasma_burst_hit(victim, (side == SOUTH && victim.dir == SOUTH && !victim.lying_angle) ? (IS_LEFT_INDEX(victim.get_held_index_of_item(shield)) ? EAST : WEST) : side, "c")
			splash_x = hit[4] - 16
			splash_y = hit[5] - 16
			// Behind a standing body, at the shoulders, so it shows over them
			if(behind_body)
				splash_y += PLASMA_SHIELD_BACK_RAISE
		// The bolt's sprite stops on the splash (above the head on a back hit, as a burst does), and the splash
		// waits for it there
		impact_point = list(splash_x, behind_body ? ICON_SIZE_Y / 2 : splash_y)
		impact_turf = target_turf
		addtimer(CALLBACK(GLOBAL_PROC, GLOBAL_PROC_REF(plasma_block_splash), target_turf, splash_x, splash_y, turn_angle, behind_body, at_shield), PLASMA_BURST_DELAY)
		return
	else if(isliving(target))
		if(blocked >= 100)
			splash_state = "splash_armour"
		else
			splash_state = "splash_flesh"
			turn_angle = 0 // steam rises; the flash has no direction
		// A bolt travelling south strikes the far side of the body, which the body hides
		behind_body = (angle > 135 && angle < 225)
	else if(istype(target, /obj/structure/window) || istype(target, /obj/machinery/door/window))
		splash_state = "splash_glass"
		playsound(target_turf, 'sound/effects/glass/glasshit.ogg', 50, TRUE, -1)

	new /obj/effect/temp_visual/plasma_splash(target_turf, splash_x, splash_y, splash_state, turn_angle, behind_body)

	if(!iswallturf(target))
		if(isopenturf(target))
			plasma_soot_at(target, impact_x, impact_y)
		return

	// One hit, one mark: the glow on the wall face, nothing on the floor in front of it
	plasma_wall_glow_at(target, impact_x, impact_y)

/// The splash of a bolt a person blocked, shown once the bolt's sprite has reached it
/proc/plasma_block_splash(turf/where, px, py, turn_angle, behind_body, at_shield)
	if(!where)
		return
	var/obj/effect/temp_visual/plasma_splash/splash = new(where, px, py, "splash_armour", turn_angle, behind_body)
	if(at_shield && !QDELETED(splash))
		// pixel_w/pixel_z keep it on the body's screen row, so the layer alone decides front or back
		splash.pixel_w = splash.pixel_x
		splash.pixel_z = splash.pixel_y
		splash.pixel_x = 0
		splash.pixel_y = 0

/// Removes tg's block star a held item made for this bolt in this tick: a plasma block shows only its splash
/proc/plasma_take_back_block_star(turf/where)
	for(var/obj/effect/temp_visual/block/star in where)
		if(star.creation_time == world.time)
			qdel(star)

/// The gutter-out where a bolt runs out of range
/obj/projectile/energy/plasma_bolt/proc/plasma_gutter_visual()
	var/turf/here = get_turf(src)
	if(!here)
		return
	new /obj/effect/temp_visual/plasma_gutter(here, src)

/// The hiss a bolt makes passing close by a mob, once per mob
/obj/projectile/energy/plasma_bolt/proc/plasma_hissby_check()
	if(QDELETED(src) || deletion_queued)
		return
	var/turf/here = get_turf(src)
	if(!here || !starting || get_dist(starting, here) < PLASMA_HISSBY_MIN_TRAVEL)
		return
	for(var/mob/living/listener in range(1, here))
		if(!listener.client || listener == firer)
			continue
		// Refs, not mobs, so a deleted listener never leaves a hard reference here
		var/listener_ref = REF(listener)
		if(LAZYFIND(hissed_mobs, listener_ref))
			continue
		LAZYADD(hissed_mobs, listener_ref)
		listener.playsound_local(here, 'sound/items/weapons/plasma_cutter.ogg', 25, TRUE)

// ===== Procs called by the guns (P2, P3, P4, P6) =====

/// A puff of vented plasma at `where`
/proc/plasma_vent_puff(turf/where)
	where = get_turf(where)
	if(!where)
		return
	return new /obj/effect/temp_visual/plasma_vent_puff(where)

/// Plays `far_file` to listeners too far away to hear `source`'s normal firing sound
/proc/plasma_weapons_far_sound(atom/source, far_file)
	if(!far_file)
		return
	var/turf/source_turf = get_turf(source)
	if(!source_turf || !islist(SSmobs.clients_by_zlevel) || source_turf.z > length(SSmobs.clients_by_zlevel))
		return
	var/list/candidates = SSmobs.clients_by_zlevel[source_turf.z] | SSmobs.dead_players_by_zlevel[source_turf.z]
	var/list/heard = plasma_far_sound_pick(source_turf, candidates)
	for(var/mob/listener as anything in heard)
		var/dist = max(get_dist(get_turf(listener), source_turf), 1)
		// The position only gives the direction; the volume comes from the band
		listener.playsound_local(source_turf, far_file, heard[listener], FALSE, pressure_affected = FALSE, distance_multiplier = 1 / dist)

/// Of `candidates`, the client mobs that hear a distant shot from `source_turf`, each with its volume
/proc/plasma_far_sound_pick(turf/source_turf, list/candidates)
	. = list()
	var/datum/gas_mixture/source_air = source_turf.return_air_readonly()
	var/source_pressure = source_air ? source_air.return_pressure() : 0
	for(var/mob/listener as anything in candidates)
		if(!listener)
			continue
		var/turf/listener_turf = get_turf(listener)
		if(!listener_turf || listener_turf.z != source_turf.z)
			continue
		var/volume = plasma_far_sound_volume(listener_turf, source_turf)
		if(!volume)
			continue
		// Thin air carries sound worse, by the same rule playsound_local uses
		var/datum/gas_mixture/listener_air = listener_turf.return_air_readonly()
		var/pressure = min(source_pressure, listener_air ? listener_air.return_pressure() : 0)
		if(pressure < ONE_ATMOSPHERE)
			volume *= max((pressure - SOUND_MINIMUM_PRESSURE) / (ONE_ATMOSPHERE - SOUND_MINIMUM_PRESSURE), 0)
		if(volume < SOUND_AUDIBLE_VOLUME_MIN)
			continue
		.[listener] = volume

/// Distant-shot volume at `listener_turf`, or 0 inside normal hearing range or past the far range
/proc/plasma_far_sound_volume(turf/listener_turf, turf/source_turf)
	var/dist = get_dist(listener_turf, source_turf)
	if(dist <= SOUND_RANGE || dist > PLASMA_FAR_SOUND_RANGE)
		return 0
	var/near_edge = SOUND_RANGE + 1
	return PLASMA_FAR_SOUND_VOL_NEAR - (PLASMA_FAR_SOUND_VOL_NEAR - PLASMA_FAR_SOUND_VOL_FAR) * (dist - near_edge) / (PLASMA_FAR_SOUND_RANGE - near_edge)

// ===== Placement helpers (capped) =====

/// A cooling glow on a wall at the impact offset; skipped when the z-level already has `cap` glows
/proc/plasma_wall_glow_at(turf/where, px = 0, py = 0, cap = PLASMA_GLOW_CAP_PER_Z)
	if(!where || !plasma_glow_allowed(where.z, cap))
		return null
	var/obj/effect/temp_visual/plasma_wall_glow/glow = new(where, where.z)
	glow.pixel_x = px
	glow.pixel_y = py
	return glow

/// Whether one more glow fits on z-level `z`
/proc/plasma_glow_allowed(z, cap = PLASMA_GLOW_CAP_PER_Z)
	return GLOB.plasma_wall_glows_by_z["[z]"] < cap

/// Soot on `where`: refreshes the glow of soot already there, otherwise makes new soot, dropping the oldest over `cap`
/proc/plasma_soot_at(turf/open/where, px = 0, py = 0, cap = PLASMA_SOOT_GLOBAL_CAP)
	if(!isopenturf(where))
		return null
	var/obj/effect/decal/cleanable/plasma_soot/soot = locate() in where
	if(soot)
		soot.restart_glow()
		return soot
	while(length(GLOB.plasma_soot_decals) >= max(cap, 1))
		var/obj/effect/decal/cleanable/plasma_soot/oldest = GLOB.plasma_soot_decals[1]
		GLOB.plasma_soot_decals -= oldest
		qdel(oldest)
	soot = new(where)
	if(QDELETED(soot))
		return null
	soot.pixel_x = clamp(px, -12, 12)
	soot.pixel_y = clamp(py, -12, 12)
	return soot

// ===== Splash =====

/obj/effect/temp_visual/plasma_splash
	// Every splash state is six 0.1 s frames
	duration = 0.6 SECONDS
	randomdir = FALSE
	light_system = OVERLAY_LIGHT
	light_range = 1.5
	light_power = 1
	light_color = PLASMA_LIGHT_COLOR
	light_on = TRUE
	/// Whether this splash carries the steam pool, so Destroy gives it back
	var/steaming = FALSE

/obj/effect/temp_visual/plasma_splash/Initialize(mapload, px = 0, py = 0, splash_state = "splash_wall", turn_angle = 0, behind_body = FALSE)
	icon_state = splash_state
	. = ..()
	pixel_x = px
	pixel_y = py
	if(turn_angle)
		transform = matrix().Turn(turn_angle)
	// Walls and glass sit behind whoever stands in front of them; a body hit from behind hides its splash
	if(behind_body || splash_state == "splash_wall" || splash_state == "splash_glass")
		layer = BELOW_MOB_LAYER
	add_overlay(emissive_appearance(icon, icon_state, src))
	if(splash_state == "splash_flesh")
		steaming = TRUE
		// The shared holder draws above every mob unless it takes our layer; this pool's holders take it
		var/obj/effect/abstract/shared_particle_holder/steam = add_shared_particles(/particles/smoke/steam/mild, PLASMA_SPLASH_STEAM_KEY)
		steam?.vis_flags |= VIS_INHERIT_LAYER
	addtimer(CALLBACK(src, TYPE_PROC_REF(/atom, set_light_on), FALSE), 0.3 SECONDS)

/obj/effect/temp_visual/plasma_splash/Destroy()
	if(steaming)
		remove_shared_particles(PLASMA_SPLASH_STEAM_KEY)
	return ..()

// ===== Person-hit burst =====
// Three looks, baked from the approved drafts into one icon set per look: burst_<look>.dmi (rifle),
// burst_<look>_small.dmi (pistol, 0.6x) and burst_<look>_body.dmi. A: molten splatter. B: flash and
// ring. Ordinary hits alternate A and B on each victim. C, the burn-through, plays only when the hit
// gives the limb a critical burn or kills.
// Each burst is four images: the floor slag and anything behind the body below the mob, the flash and
// front globs above it, a soft additive bloom, and what sticks to the body in the mob's vis_contents, so it
// moves and turns with the body. It shows a tick after the hit, when the bolt's sprite reaches the body.

/// Where a hit lands on a standing human, in sprite pixels from the bottom left, by
/// "[body facing][side the shot came from][band]"; bands are h(ead), c(hest) and l(egs)
GLOBAL_LIST_INIT(plasma_burst_hits, list(
	"SSh" = list(15, 25), "SNh" = list(15, 25), "SEh" = list(19, 25), "SWh" = list(11, 25),
	"NSh" = list(15, 25), "NNh" = list(15, 25), "NEh" = list(19, 25), "NWh" = list(11, 25),
	"ESh" = list(16, 25), "ENh" = list(16, 25), "EEh" = list(19, 25), "EWh" = list(12, 25),
	"WSh" = list(16, 25), "WNh" = list(16, 25), "WEh" = list(19, 25), "WWh" = list(12, 25),
	"SSc" = list(15, 17), "SNc" = list(15, 17), "SEc" = list(22, 17), "SWc" = list(8, 17),
	"NSc" = list(15, 17), "NNc" = list(15, 17), "NEc" = list(22, 17), "NWc" = list(8, 17),
	"ESc" = list(15, 17), "ENc" = list(15, 17), "EEc" = list(19, 17), "EWc" = list(11, 17),
	"WSc" = list(16, 17), "WNc" = list(16, 17), "WEc" = list(20, 17), "WWc" = list(12, 17),
	"SSl" = list(15, 5), "SNl" = list(15, 5), "SEl" = list(19, 5), "SWl" = list(11, 5),
	"NSl" = list(15, 5), "NNl" = list(15, 5), "NEl" = list(19, 5), "NWl" = list(11, 5),
	"ESl" = list(15, 5), "ENl" = list(15, 5), "EEl" = list(17, 5), "EWl" = list(13, 5),
	"WSl" = list(16, 5), "WNl" = list(16, 5), "WEl" = list(18, 5), "WWl" = list(14, 5)
))

/mob/living/carbon/human
	/// The look of the last ordinary plasma burst on this body, so the next one differs
	var/plasma_last_burst

/// The letter a cardinal dir goes by in the burst states and hit table
/proc/plasma_burst_dir_letter(dir)
	switch(dir)
		if(NORTH)
			return "N"
		if(EAST)
			return "E"
		if(WEST)
			return "W"
	return "S"

/// The band a hit zone draws in
/proc/plasma_burst_band(zone)
	switch(check_zone(zone))
		if(BODY_ZONE_HEAD)
			return "h"
		if(BODY_ZONE_L_LEG, BODY_ZONE_R_LEG)
			return "l"
	return "c"

/// Where a bolt from `side` lands on `victim` in `band`: list(sprite x, sprite y, side in the body's own
/// frame, on-screen x, on-screen y). Sprite pixels are the body's own, before it is turned or scaled;
/// on-screen pixels are from the bottom left of the victim's turf.
/proc/plasma_burst_hit(mob/living/victim, side, band)
	var/local_side = side
	// A body lying down is turned by lying_angle; the side it was hit on turns with it
	if(victim.lying_angle)
		local_side = turn(side, victim.lying_angle)
	var/list/hit = GLOB.plasma_burst_hits["[plasma_burst_dir_letter(victim.dir)][plasma_burst_dir_letter(local_side)][band]"]
	// Transforms turn and scale about the icon's centre
	var/local_x = hit[1] + 0.5 - ICON_SIZE_X / 2
	var/local_y = hit[2] + 0.5 - ICON_SIZE_Y / 2
	var/matrix/turned = victim.transform
	var/screen_x = turned.a * local_x + turned.b * local_y + turned.c
	var/screen_y = turned.d * local_x + turned.e * local_y + turned.f
	return list(hit[1], hit[2], local_side, round(screen_x + ICON_SIZE_X / 2 - 0.5) + victim.pixel_x, round(screen_y + ICON_SIZE_Y / 2 - 0.5) + victim.pixel_y)

/// The icon for one part of a look: "spray" (rifle), "small" (pistol spray) or "body"
/proc/plasma_burst_icon(look, part)
	var/static/list/icons = list(
		"Aspray" = 'voidcrew/modules/plasma_weapons/icons/burst_a.dmi',
		"Asmall" = 'voidcrew/modules/plasma_weapons/icons/burst_a_small.dmi',
		"Abody" = 'voidcrew/modules/plasma_weapons/icons/burst_a_body.dmi',
		"Bspray" = 'voidcrew/modules/plasma_weapons/icons/burst_b.dmi',
		"Bsmall" = 'voidcrew/modules/plasma_weapons/icons/burst_b_small.dmi',
		"Bbody" = 'voidcrew/modules/plasma_weapons/icons/burst_b_body.dmi',
		"Cspray" = 'voidcrew/modules/plasma_weapons/icons/burst_c.dmi',
		"Csmall" = 'voidcrew/modules/plasma_weapons/icons/burst_c_small.dmi',
		"Cbody" = 'voidcrew/modules/plasma_weapons/icons/burst_c_body.dmi',
	)
	return icons["[look][part]"]

/// An ordinary burst for `victim`: A or B, never the one it had last
/proc/plasma_burst_pick(mob/living/carbon/human/victim)
	var/look
	switch(victim.plasma_last_burst)
		if(PLASMA_BURST_SPLATTER)
			look = PLASMA_BURST_FLASH
		if(PLASMA_BURST_FLASH)
			look = PLASMA_BURST_SPLATTER
		else
			look = pick(PLASMA_BURST_SPLATTER, PLASMA_BURST_FLASH)
	victim.plasma_last_burst = look
	return look

/// The front of a burst: flash, ring and globs flying toward the shooter, drawn over the body. It waits
/// for the bolt's damage to land, in the same tick, to know whether the bolt burned through.
/obj/effect/temp_visual/plasma_burst
	icon = 'voidcrew/modules/plasma_weapons/icons/burst_a.dmi'
	icon_state = null
	duration = PLASMA_BURST_DURATION
	randomdir = FALSE
	/// Who was hit, until the look is picked
	var/mob/living/carbon/human/victim
	/// The limb hit
	var/obj/item/bodypart/limb
	/// Whether the limb already had a critical burn
	var/had_critical = FALSE
	/// Whether the victim was alive before the hit
	var/was_alive = FALSE
	/// The side the bolt came from
	var/side
	/// h, c or l
	var/band
	/// Pistol bolts make the 0.6x burst
	var/small = FALSE
	/// Whether the look has been picked and drawn
	var/drawn = FALSE
	/// Where the bolt landed, from plasma_burst_hit(), taken before the damage: a killing hit lays the body
	/// down in the same call, and the burst belongs where the bolt struck
	var/list/hit
	/// Whether the body was lying down, its layer and its facing when the bolt landed
	var/lying = FALSE
	var/body_layer = MOB_LAYER
	var/facing = SOUTH
	/// The look picked in the tick of the hit, shown PLASMA_BURST_DELAY later
	var/look
	/// Whether the bolt melted the hit limb: that counts as a burn-through
	var/melted = FALSE

/obj/effect/temp_visual/plasma_burst/Initialize(mapload, mob/living/carbon/human/struck, obj/projectile/energy/plasma_bolt/bolt, from_side)
	. = ..()
	if(!struck || !bolt)
		return INITIALIZE_HINT_QDEL
	victim = struck
	side = from_side
	band = plasma_burst_band(bolt.def_zone)
	small = !istype(bolt, /obj/projectile/energy/plasma_bolt/heavy)
	was_alive = victim.stat != DEAD
	limb = victim.get_bodypart(check_zone(bolt.def_zone))
	had_critical = plasma_limb_burned_through(limb)
	hit = plasma_burst_hit(victim, side, band)
	// The bolt's sprite stops where the burst draws; on a standing body's back it goes out behind the head
	// instead of running over it
	bolt.impact_point = list(hit[4] - ICON_SIZE_X / 2, side == NORTH && !victim.lying_angle ? ICON_SIZE_Y / 2 : hit[5] - ICON_SIZE_Y / 2)
	bolt.impact_turf = get_turf(victim)
	lying = !!victim.lying_angle
	body_layer = victim.layer
	facing = victim.dir
	// on_hit runs just before the damage lands, in the same tick
	RegisterSignal(victim, COMSIG_MOB_AFTER_APPLY_DAMAGE, PROC_REF(on_victim_damaged))
	RegisterSignal(victim, COMSIG_QDELETING, PROC_REF(on_victim_deleted))
	// No burn damage at all: an ordinary burst on the next tick
	addtimer(CALLBACK(src, PROC_REF(draw), FALSE), 0)

/obj/effect/temp_visual/plasma_burst/Destroy()
	forget_victim()
	limb = null
	return ..()

/obj/effect/temp_visual/plasma_burst/proc/forget_victim()
	if(!victim)
		return
	UnregisterSignal(victim, list(COMSIG_MOB_AFTER_APPLY_DAMAGE, COMSIG_QDELETING))
	victim = null

/obj/effect/temp_visual/plasma_burst/proc/on_victim_deleted(datum/source)
	SIGNAL_HANDLER
	forget_victim()
	if(!drawn)
		qdel(src)

/obj/effect/temp_visual/plasma_burst/proc/on_victim_damaged(mob/living/carbon/human/source, damage, damagetype)
	SIGNAL_HANDLER
	if(damagetype != BURN)
		return
	var/killed = was_alive && source.stat == DEAD
	var/burned = !had_critical && limb?.owner == source && plasma_limb_burned_through(limb)
	draw(killed || burned)

/// Picks the look in the tick of the hit, and shows it once the bolt's sprite has reached the body
/obj/effect/temp_visual/plasma_burst/proc/draw(burned_through)
	if(drawn || QDELETED(src))
		return
	drawn = TRUE
	if(!victim)
		qdel(src)
		return
	var/mob/living/carbon/human/hit_body = victim
	forget_victim()
	burned_through = burned_through || melted
	look = burned_through ? PLASMA_BURST_THROUGH : plasma_burst_pick(hit_body)
	// The burn-through sizzles on top of the hit
	if(burned_through)
		plasma_burst_sizzle(hit_body)
	addtimer(CALLBACK(src, PROC_REF(show), WEAKREF(hit_body)), PLASMA_BURST_DELAY)

/// The burn-through's sizzle
/proc/plasma_burst_sizzle(atom/where)
	playsound(where, pick('voidcrew/modules/plasma_weapons/sound/plasma_burnthrough_1.ogg', 'voidcrew/modules/plasma_weapons/sound/plasma_burnthrough_2.ogg'), 60, TRUE)

/// The bolt melted the hit limb (plasma_check_ash). A melt is a burn-through: before the look is picked this
/// sets it up; after, it swaps a picked look for the burn-through, as long as nothing is on screen yet.
/obj/effect/temp_visual/plasma_burst/proc/limb_melted()
	if(QDELETED(src))
		return
	melted = TRUE
	if(!drawn || icon_state || look == PLASMA_BURST_THROUGH)
		return
	look = PLASMA_BURST_THROUGH
	plasma_burst_sizzle(src)

/// Draws the spray, the bloom and what sticks to the body
/obj/effect/temp_visual/plasma_burst/proc/show(datum/weakref/body_ref)
	// icon_state stays null until the look is on screen
	if(icon_state || QDELETED(src))
		return
	var/mob/living/carbon/human/hit_body = body_ref?.resolve()
	// The spray falls to the floor; a body lying down is already near it
	var/spray_band = lying ? "l" : band
	var/flipped = side == WEST
	var/spray_state = "sp_[look][small ? "p" : "r"]_[spray_band]_[plasma_burst_dir_letter(flipped ? EAST : side)]"
	var/canvas_icon = plasma_burst_icon(look, small ? "small" : "spray")
	// The hit point sits in the centre column, one row below the centre, of the spray canvas
	var/half = small ? 32 : 48
	var/spray_x = hit[4] - half + (flipped ? 1 : 0)
	var/spray_y = hit[5] - (half - 1)

	icon = canvas_icon
	layer = body_layer + 0.01
	plasma_burst_place(src, "[spray_state]_hi", spray_x, spray_y, flipped)
	var/obj/effect/temp_visual/plasma_burst_low/low = new(loc)
	low.icon = canvas_icon
	low.layer = body_layer - 0.01
	plasma_burst_place(low, "[spray_state]_lo", spray_x, spray_y, flipped)

	// The soft bloom on the flash; a hit on a standing body's back lights only the rim around it
	var/obj/effect/temp_visual/plasma_burst_bloom/bloom = new(loc)
	bloom.icon = canvas_icon
	bloom.layer = (side == NORTH && !lying) ? body_layer - 0.02 : body_layer + 0.02
	plasma_burst_place(bloom, "bl_[look][small ? "p" : "r"]", spray_x, spray_y, flipped, overlay_state = "bl_[look][small ? "p" : "r"]")

	// What sticks rides the body and turns with it; its frames for a side the viewer can't see are empty
	if(hit_body && !QDELETED(hit_body))
		var/body_side = hit[3]
		if(body_side == NORTH && lying)
			body_side = SOUTH
		new /obj/effect/temp_visual/plasma_burst_body(null, hit_body, plasma_burst_icon(look, "body"), "bd_[look][small ? "p" : "r"]_[plasma_burst_dir_letter(plasma_burst_body_side(body_side, facing))][band]")

	// The light sits on the hit itself: on the spray it would ride the canvas offset a tile or two off the body
	var/obj/effect/temp_visual/plasma_burst_light/glow = new(loc)
	glow.pixel_w = hit[4] - ICON_SIZE_X / 2
	glow.pixel_z = hit[5] - ICON_SIZE_Y / 2
	// It dims over its last few ticks instead of snapping off
	var/fade_time = look == PLASMA_BURST_SPLATTER ? 0.2 SECONDS : 0.25 SECONDS
	for(var/steps in 1 to 4)
		addtimer(CALLBACK(glow, TYPE_PROC_REF(/atom, set_light_power), glow.light_power * (1 - steps * 0.2)), fade_time + (steps - 1) * world.tick_lag)
	addtimer(CALLBACK(glow, TYPE_PROC_REF(/atom, set_light_on), FALSE), fade_time + 4 * world.tick_lag)

/// The side `side` of a body facing `facing`, named as the same side of a body facing south: the body
/// states are named by it and hold one dir per facing
/proc/plasma_burst_body_side(side, facing)
	return turn(side, dir2angle(facing) - 180)

/// Shows `state` and its glow on `burst_part` at the given offset, mirrored for a shot from the west.
/// The offset goes in pixel_w/pixel_z: pixel_y would move it to another screen row and sort it past the body.
/proc/plasma_burst_place(obj/effect/burst_part, state, px, py, flipped, overlay_state = "[state]_e")
	burst_part.icon_state = state
	burst_part.pixel_w = px
	burst_part.pixel_z = py
	if(flipped)
		burst_part.transform = matrix(-1, 0, 0, 0, 1, 0)
	burst_part.add_overlay(emissive_appearance(burst_part.icon, overlay_state, burst_part))

/// The burst's light, on the hit point
/obj/effect/temp_visual/plasma_burst_light
	icon = null
	icon_state = null
	duration = 0.6 SECONDS
	randomdir = FALSE
	light_system = OVERLAY_LIGHT
	light_range = 2
	light_power = 1.5
	light_color = PLASMA_LIGHT_COLOR
	light_on = TRUE

/// Floor slag and anything the body hides
/obj/effect/temp_visual/plasma_burst_low
	icon = 'voidcrew/modules/plasma_weapons/icons/burst_a.dmi'
	icon_state = null
	duration = PLASMA_BURST_DURATION
	randomdir = FALSE

/// The soft additive bloom on the flash, as the drafts' glow; its emissive keeps it bright in the dark
/obj/effect/temp_visual/plasma_burst_bloom
	icon = 'voidcrew/modules/plasma_weapons/icons/burst_a.dmi'
	icon_state = null
	duration = 1.5 SECONDS
	randomdir = FALSE
	blend_mode = BLEND_ADD
	mouse_opacity = MOUSE_OPACITY_TRANSPARENT

/// What sticks to the body; it rides in the body's vis_contents, so it moves, turns and lies down with it
/obj/effect/temp_visual/plasma_burst_body
	icon = 'voidcrew/modules/plasma_weapons/icons/burst_a_body.dmi'
	icon_state = null
	duration = PLASMA_BURST_DURATION
	randomdir = FALSE
	layer = FLOAT_LAYER
	plane = FLOAT_PLANE
	// Each state holds one dir per facing of the body, so it follows the body turning
	vis_flags = VIS_INHERIT_PLANE | VIS_INHERIT_ID | VIS_INHERIT_DIR
	/// The body it is stuck to
	var/mob/living/carbon/human/stuck_to

/obj/effect/temp_visual/plasma_burst_body/Initialize(mapload, mob/living/carbon/human/body, look_icon, state)
	. = ..()
	if(!body)
		return INITIALIZE_HINT_QDEL
	stuck_to = body
	icon = look_icon
	icon_state = state
	dir = body.dir
	add_overlay(emissive_appearance(icon, "[state]_e", body))
	stuck_to.vis_contents += src
	RegisterSignal(stuck_to, COMSIG_QDELETING, PROC_REF(on_body_deleted))

/obj/effect/temp_visual/plasma_burst_body/Destroy()
	if(stuck_to)
		UnregisterSignal(stuck_to, COMSIG_QDELETING)
		stuck_to.vis_contents -= src
		stuck_to = null
	return ..()

/obj/effect/temp_visual/plasma_burst_body/proc/on_body_deleted(datum/source)
	SIGNAL_HANDLER
	qdel(src)

// ===== tg's block star =====

/obj/effect/temp_visual/block
	/// The tick it appeared, so a blocked plasma bolt can take back its own star
	var/creation_time

/obj/effect/temp_visual/block/Initialize(mapload, set_color)
	creation_time = world.time
	return ..()

// ===== Wall glow =====

/obj/effect/temp_visual/plasma_wall_glow
	duration = PLASMA_GLOW_DURATION
	randomdir = FALSE
	layer = BELOW_MOB_LAYER
	color = COLOR_WHITE
	/// The z-level key this glow counts against
	var/glow_z_key

/// `z_level` is the level the glow counts against; `spokesman` is the atom it draws with, for emissive planes
/obj/effect/temp_visual/plasma_wall_glow/Initialize(mapload, z_level, atom/spokesman)
	. = ..()
	glow_z_key = "[z_level || z]"
	GLOB.plasma_wall_glows_by_z[glow_z_key] += 1
	// The emissive keeps the ember lit in the dark; it fades with our alpha and keeps its own colour
	add_overlay(emissive_appearance(icon, icon_state, spokesman || src))
	// It cools down the plasma's own ramp: green, deep green, then char
	animate(src, color = "#33FF88", time = 0.5 SECONDS)
	animate(color = "#1E873E", time = 1.5 SECONDS)
	animate(color = "#2C3427", time = 2 SECONDS)
	animate(alpha = 0, time = PLASMA_GLOW_DURATION - 4 SECONDS)

/obj/effect/temp_visual/plasma_wall_glow/Destroy()
	if(glow_z_key)
		GLOB.plasma_wall_glows_by_z[glow_z_key] -= 1
		if(GLOB.plasma_wall_glows_by_z[glow_z_key] <= 0)
			GLOB.plasma_wall_glows_by_z -= glow_z_key
		glow_z_key = null
	return ..()

/// The glow inside a soot decal's vis_contents; it lives in nullspace and draws with the decal
/obj/effect/temp_visual/plasma_wall_glow/soot
	layer = FLOAT_LAYER
	plane = FLOAT_PLANE
	vis_flags = VIS_INHERIT_PLANE | VIS_INHERIT_LAYER | VIS_INHERIT_ID

// ===== Soot =====

/obj/effect/decal/cleanable/plasma_soot
	desc = "A black scorch mark."
	/// The cooling glow over the soot, while it still burns
	var/obj/effect/temp_visual/plasma_wall_glow/soot/glow

/obj/effect/decal/cleanable/plasma_soot/Initialize(mapload, list/datum/disease/diseases)
	. = ..()
	if(. == INITIALIZE_HINT_QDEL)
		return
	GLOB.plasma_soot_decals += src
	restart_glow()

/obj/effect/decal/cleanable/plasma_soot/Destroy()
	GLOB.plasma_soot_decals -= src
	clear_glow()
	return ..()

/// Starts the cooling glow over, if the z-level has room for one
/obj/effect/decal/cleanable/plasma_soot/proc/restart_glow()
	clear_glow()
	var/turf/here = get_turf(src)
	if(!here || !plasma_glow_allowed(here.z))
		return
	glow = new(null, here.z, src)
	vis_contents += glow
	RegisterSignal(glow, COMSIG_QDELETING, PROC_REF(on_glow_deleted))

/// Drops the current glow, if any
/obj/effect/decal/cleanable/plasma_soot/proc/clear_glow()
	if(!glow)
		return
	var/obj/effect/temp_visual/plasma_wall_glow/soot/old_glow = glow
	UnregisterSignal(old_glow, COMSIG_QDELETING)
	vis_contents -= old_glow
	glow = null
	qdel(old_glow)

/obj/effect/decal/cleanable/plasma_soot/proc/on_glow_deleted(datum/source)
	SIGNAL_HANDLER
	vis_contents -= source
	glow = null

// ===== Gutter-out =====

/obj/effect/temp_visual/plasma_gutter
	duration = 0.5 SECONDS
	randomdir = FALSE
	light_system = OVERLAY_LIGHT
	light_range = 1.5
	light_power = 1
	light_color = PLASMA_LIGHT_COLOR
	light_on = TRUE

/// Takes the look of `bolt`, shrinks with two flickers over 0.3 s, then curls into a wisp
/obj/effect/temp_visual/plasma_gutter/Initialize(mapload, obj/projectile/energy/plasma_bolt/bolt)
	. = ..()
	var/matrix/base = matrix()
	if(bolt)
		icon = bolt.icon
		icon_state = bolt.icon_state
		// tg's range-out hop (delete_distance in projectile.dm) leaves the bolt a tile less twice its
		// overshoot short of where it ran out, often behind where it was last drawn; start from that point
		var/shortfall = clamp(ICON_SIZE_ALL - 2 * bolt.pixels_moved_last_tile, 0, ICON_SIZE_ALL)
		pixel_x = bolt.pixel_x + round(bolt.movement_vector?.pixel_x * shortfall)
		pixel_y = bolt.pixel_y + round(bolt.movement_vector?.pixel_y * shortfall)
		layer = bolt.layer
		plane = bolt.plane
		base = matrix(bolt.transform)
		set_light_range(bolt.light_range)
		add_overlay(emissive_appearance(bolt.icon, bolt.core_state, src))
	transform = base
	animate(src, transform = scaled_copy(base, 0.85), alpha = 90, time = 0.5)
	animate(transform = scaled_copy(base, 0.7), alpha = 255, time = 0.5)
	animate(transform = scaled_copy(base, 0.55), alpha = 90, time = 0.5)
	animate(transform = scaled_copy(base, 0.45), alpha = 255, time = 0.5)
	animate(transform = scaled_copy(base, 0.3), alpha = 200, time = 1)
	addtimer(CALLBACK(src, PROC_REF(snuff)), 0.3 SECONDS)

/obj/effect/temp_visual/plasma_gutter/proc/scaled_copy(matrix/base, scale)
	var/matrix/scaled = matrix(base)
	scaled.Scale(scale)
	return scaled

/// The core and its light go out and what is left curls into a wisp, all in one update: turning the
/// sprite upright any earlier would flash the core's emissive upright for a frame
/obj/effect/temp_visual/plasma_gutter/proc/snuff()
	cut_overlays()
	set_light_on(FALSE)
	// The wisp is drawn upright, whichever way the bolt flew, and fades out in its own frames
	// The bolt's look came from the projectile icon; the wisp is in ours
	icon = initial(icon)
	icon_state = "wisp"
	// A new animation replaces the shrink
	animate(src, transform = matrix(), alpha = 255, time = 0)

// ===== Vent puff =====

/obj/effect/temp_visual/plasma_vent_puff
	duration = 0.6 SECONDS
	randomdir = FALSE

/obj/effect/temp_visual/plasma_vent_puff/Initialize(mapload)
	. = ..()
	add_shared_particles(/particles/smoke/steam/mild)

/obj/effect/temp_visual/plasma_vent_puff/Destroy()
	remove_shared_particles(/particles/smoke/steam/mild)
	return ..()

#undef PLASMA_FAR_SOUND_RANGE
#undef PLASMA_FAR_SOUND_VOL_NEAR
#undef PLASMA_FAR_SOUND_VOL_FAR
#undef PLASMA_HISSBY_MIN_TRAVEL
#undef PLASMA_SPLASH_STEAM_KEY
#undef PLASMA_BURST_SPLATTER
#undef PLASMA_BURST_FLASH
#undef PLASMA_BURST_THROUGH
#undef PLASMA_BURST_DURATION
#undef PLASMA_BURST_DELAY
#undef PLASMA_SHIELD_BACK_RAISE
