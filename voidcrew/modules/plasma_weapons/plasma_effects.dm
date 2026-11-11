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
/// Light colour shared by the bolt's splash and gutter-out
#define PLASMA_EFFECT_LIGHT_COLOR "#B8FFD0"
/// Shared particle pool for the flesh splash's steam, kept apart because its holders take the splash's layer
#define PLASMA_SPLASH_STEAM_KEY "plasma_splash_steam"

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
	if(isliving(target))
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

	new /obj/effect/temp_visual/plasma_splash(target_turf, impact_x, impact_y, splash_state, turn_angle, behind_body)

	if(!iswallturf(target))
		if(isopenturf(target))
			plasma_soot_at(target, impact_x, impact_y)
		return

	plasma_wall_glow_at(target, impact_x, impact_y)
	// Soot falls on the open floor in front of the wall face, the tile the bolt was in
	var/turf/open/in_front = get_turf(src)
	if(isopenturf(in_front) && prob(50))
		plasma_soot_at(in_front, round(sin(angle) * 10), round(cos(angle) * 10))

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
	light_color = PLASMA_EFFECT_LIGHT_COLOR
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
	animate(src, color = "#33FF88", time = 0.5 SECONDS)
	animate(color = "#AA4422", time = 3.5 SECONDS)
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
	light_color = PLASMA_EFFECT_LIGHT_COLOR
	light_on = TRUE

/// Takes the look of `bolt`, shrinks with two flickers over 0.3 s, then curls into a wisp
/obj/effect/temp_visual/plasma_gutter/Initialize(mapload, obj/projectile/energy/plasma_bolt/bolt)
	. = ..()
	var/matrix/base = matrix()
	if(bolt)
		icon = bolt.icon
		icon_state = bolt.icon_state
		pixel_x = bolt.pixel_x
		pixel_y = bolt.pixel_y
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
	// The wisp is drawn upright, whichever way the bolt flew
	animate(icon_state = "wisp", transform = matrix(), alpha = 255, time = 0)
	animate(alpha = 0, time = 2)
	addtimer(CALLBACK(src, PROC_REF(snuff)), 0.3 SECONDS)

/obj/effect/temp_visual/plasma_gutter/proc/scaled_copy(matrix/base, scale)
	var/matrix/scaled = matrix(base)
	scaled.Scale(scale)
	return scaled

/// The core and its light go out when the wisp starts
/obj/effect/temp_visual/plasma_gutter/proc/snuff()
	cut_overlays()
	set_light_on(FALSE)

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
#undef PLASMA_EFFECT_LIGHT_COLOR
#undef PLASMA_SPLASH_STEAM_KEY
