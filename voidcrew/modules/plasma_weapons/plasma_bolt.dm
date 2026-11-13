// Package: P1 bolt. The plasma bolts and their casings: stats, fuel ignition in Moved(), structure
// damage, melt registration in on_hit(), and the calls out to the P8 effects. A bolt never sets a
// person alight (design decision 6); its burns come through tg's own burn wounds.

/obj/projectile/energy/plasma_bolt
	damage = 32
	damage_type = BURN
	armor_flag = ENERGY
	armour_penetration = 10
	// Burn wounds through tg's roll (wounds.dm check_wounding); see plasma_sim.py section 9.
	wound_bonus = 10
	exposed_wound_bonus = 25
	// Scoped to structures and doors by get_demolition_modifier() below.
	demolition_mod = PLASMA_DEMOLITION_PISTOL
	speed = 1
	range = 20
	// Plasma is matter: no mirror turns it, and glass and grilles stop it (pass_flags stays PASSTABLE).
	reflectable = NONE
	dismemberment = 0
	hitsound = 'voidcrew/modules/plasma_weapons/sound/plasma_hit_pistol.ogg'
	hitsound_wall = PLASMA_SOUND_IMPACT_WALL
	impact_effect_type = null
	light_system = OVERLAY_LIGHT
	light_range = 2
	light_power = 1.2
	light_color = PLASMA_LIGHT_COLOR

/obj/projectile/energy/plasma_bolt/heavy
	damage = 45
	hitsound = 'voidcrew/modules/plasma_weapons/sound/plasma_hit_rifle.ogg'
	armour_penetration = 20
	wound_bonus = 20
	exposed_wound_bonus = 30
	demolition_mod = PLASMA_DEMOLITION_RIFLE
	range = 25
	splash_scale = 1
	light_range = 2.5
	light_power = 1.6

/obj/projectile/energy/plasma_bolt
	/// Where a person hit is struck, in pixels from the centre of their turf, set by the burst
	var/list/impact_point
	/// The turf impact_point is measured on
	var/turf/impact_turf
	/// Whether the sprite also slides sideways onto impact_point on its last step, as onto a held shield
	var/impact_slide = FALSE
	/// Size of its splash on a wall, a window or a body it doesn't burst on
	var/splash_scale = 0.6
	/// Played when it hits a window or windoor
	var/hitsound_glass = PLASMA_SOUND_IMPACT_GLASS
	/// Played to someone it passes close by
	var/near_miss_sound = PLASMA_SOUND_NEAR_MISS
	/// Played instead of a held shield's own block sound when one stops it; null keeps the shield's
	var/shield_block_sound = PLASMA_SOUND_SHIELD_BLOCK

/obj/projectile/energy/plasma_bolt/Destroy()
	hissed_mobs = null
	impact_turf = null
	return ..()

/// The last stretch to an impact: the sprite stops with its nose where the burst or splash draws, then
/// goes out, so it never slides over the flash or into the body
/obj/projectile/energy/plasma_bolt/move_animate(animate_x, animate_y, animate_time = world.tick_lag, deleting = FALSE)
	if(!deleting || deletion_queued != PROJECTILE_IMPACT_DELETE || !movement_vector)
		return FALSE
	var/dx = movement_vector.pixel_x
	var/dy = movement_vector.pixel_y
	// Pixels from the sprite's centre to the front of its glow: 7 on the pistol bolt, 13 on the rifle's
	var/offset = istype(src, /obj/projectile/energy/plasma_bolt/heavy) ? 13 : 7
	var/full = (animate_x - pixel_x) * dx + (animate_y - pixel_y) * dy
	var/stop = full - offset
	if(impact_point && impact_turf == loc)
		stop = (impact_point[1] - pixel_x) * dx + (impact_point[2] - pixel_y) * dy - offset
	// A wall stops us in the turf before it: its face point is measured on the wall's turf, a tile on from ours. Without
	// this we would stop where tg put the hit, up to half a tile inside the wall
	else if(impact_point && isturf(loc) && impact_turf?.z == loc.z && get_dist(impact_turf, loc) == 1)
		var/face_x = impact_point[1] + (impact_turf.x - loc.x) * ICON_SIZE_X
		var/face_y = impact_point[2] + (impact_turf.y - loc.y) * ICON_SIZE_Y
		stop = (face_x - pixel_x) * dx + (face_y - pixel_y) * dy - offset
	stop = clamp(stop, 0, max(full, 0) + ICON_SIZE_ALL / 2)
	// Onto a held shield it slides a few pixels across its path, so it meets the shield and not the air beside it
	var/slide_x = 0
	var/slide_y = 0
	if(impact_slide && impact_point && impact_turf == loc)
		var/across = clamp((impact_point[1] - pixel_x) * dy - (impact_point[2] - pixel_y) * dx, -PLASMA_BOLT_MAX_SLIDE, PLASMA_BOLT_MAX_SLIDE)
		slide_x = dy * across
		slide_y = -dx * across
	var/anim_time = full > 0 ? animate_time * stop / full : 0
	// Drop this tick's earlier steps first: a step taken before the bolt crossed into the target's turf is in
	// the last turf's pixels, and chained after it this one would overshoot the stop by up to a tile
	animate(src)
	if(impact_slide && impact_turf == loc)
		// On the holder's own screen row, so its layer alone puts it in front of the holder or behind
		pixel_z += pixel_y
		pixel_y = 0
		animate(src, pixel_x = pixel_x + dx * stop + slide_x, pixel_z = pixel_z + dy * stop + slide_y, time = anim_time, flags = ANIMATION_PARALLEL)
	else
		animate(src, pixel_x = pixel_x + dx * stop + slide_x, pixel_y = pixel_y + dy * stop + slide_y, time = anim_time, flags = ANIMATION_PARALLEL)
	// A person's burst shows a tick after the hit (a splash shows at once): a bolt that stops early, as on the
	// near edge of a body lying down, waits at its stop until the burst is up instead of leaving empty frames.
	// The bolt is deleted by then anyway, so it never sits over the burst for more than a frame.
	if(impact_point && impact_turf == loc && anim_time < world.tick_lag)
		animate(alpha = 255, time = 2 * world.tick_lag - anim_time, flags = ANIMATION_CONTINUE)
	animate(alpha = 0, time = 0, flags = ANIMATION_CONTINUE)
	return TRUE

/obj/projectile/energy/plasma_bolt/Moved(atom/old_loc, movement_dir, forced, list/old_locs, momentum_change = TRUE)
	. = ..()
	if(!fired)
		return
	plasma_expose_turf(loc)

/// Lights real fuel gas on an open turf. Only hotspot_expose: clean air and vacuum never catch.
/obj/projectile/energy/plasma_bolt/proc/plasma_expose_turf(turf/open/where)
	if(!isopenturf(where))
		return
	where.hotspot_expose(PLASMA_BOLT_EXPOSE_TEMP, PLASMA_BOLT_EXPOSE_VOLUME)

/obj/projectile/energy/plasma_bolt/on_hit(atom/target, blocked = 0, pierce_hit)
	// One sound per hit. tg plays the person sound on anything that isn't a wall; here it is kept for a person the bolt
	// reaches, a block plays only the blocker's own sound, and anything else gets its surface sound below.
	var/person_sound = hitsound
	if(!isliving(target) || blocked >= 100)
		hitsound = null
	. = ..()
	hitsound = person_sound
	plasma_surface_sound(target)
	plasma_impact_visuals(target, blocked)
	plasma_expose_turf(get_turf(target))
	if(. != BULLET_ACT_HIT || !iscarbon(target) || blocked >= 100)
		return
	var/mob/living/carbon/victim = target
	// on_hit runs before the damage lands: note the limb's state now, then sear its cuts and check for a melt after it.
	var/obj/item/bodypart/limb = victim.get_bodypart(check_zone(def_zone))
	if(!limb)
		return
	ash_zone = limb.body_zone
	ash_prior_damage = limb.get_damage()
	ash_prior_critical = plasma_burn_through_ready(limb)
	RegisterSignal(victim, COMSIG_MOB_AFTER_APPLY_DAMAGE, PROC_REF(plasma_check_ash), override = TRUE)

/// The sound of a bolt hitting something that isn't alive. tg already plays hitsound_wall on a turf.
/obj/projectile/energy/plasma_bolt/proc/plasma_surface_sound(atom/target)
	if(isturf(target) || isliving(target))
		return
	var/turf/target_turf = get_turf(target)
	if(!target_turf)
		return
	if(istype(target, /obj/structure/window) || istype(target, /obj/machinery/door/window))
		playsound(target_turf, hitsound_glass, 50, TRUE, -1)
		return
	playsound(target_turf, hitsound_wall, clamp(vol_by_damage() + (suppressed ? 0 : 20), 0, 100), TRUE, -1)

/// The sound a held item plays when it blocks this, in place of its own block_sound; null keeps the item's.
/// Called from tg's /obj/item/proc/hit_reaction (VOIDCREW EDIT).
/atom/movable/proc/blocked_sound_for(obj/item/blocker)
	return null

/// A held shield that stops a bolt plays the bolt's shield sound instead of its own, when it has one
/obj/projectile/energy/plasma_bolt/blocked_sound_for(obj/item/blocker)
	if(istype(blocker, /obj/item/shield))
		return shield_block_sound
	return null

/// Plasma breaks structures and doors faster; mechs, turrets and other machines take normal damage.
/obj/projectile/energy/plasma_bolt/get_demolition_modifier(obj/target)
	if(isstructure(target) || istype(target, /obj/machinery/door))
		return ..()
	return 1

/obj/projectile/energy/plasma_bolt/on_range()
	plasma_gutter_visual()
	return ..()

/obj/projectile/energy/plasma_bolt/scan_moved_turf()
	. = ..()
	plasma_hissby_check()

// ===== Casings =====

/obj/item/ammo_casing/energy/plasma_bolt
	e_cost = PLASMA_SHOT_MOL_PISTOL
	select_name = "plasma"
	fire_sound = 'voidcrew/modules/plasma_weapons/sound/cinder_fire.ogg'
	// The barrel pinch (P9) is the muzzle effect; tg's red laser flash would clash with it.
	firing_effect_type = null

/obj/item/ammo_casing/energy/plasma_bolt/heavy
	e_cost = PLASMA_SHOT_MOL_RIFLE
	fire_sound = 'voidcrew/modules/plasma_weapons/sound/furnace_fire.ogg'

/// Sears the bleeding cuts on a limb a bolt just hit: each bleeding wound loses PLASMA_SEAR_FLOW blood flow,
/// and tg's own slash and pierce code closes or demotes it. One line if any cut closed or dropped a tier.
/proc/plasma_sear_cuts(obj/item/bodypart/limb)
	var/mob/living/carbon/victim = limb?.owner
	if(!victim || !LAZYLEN(limb.wounds))
		return
	var/seared = FALSE
	for(var/datum/wound/cut as anything in limb.wounds.Copy())
		if(cut.blood_flow <= 0)
			continue
		cut.adjust_blood_flow(-PLASMA_SEAR_FLOW)
		// A cut that closed is deleted; one that dropped a tier was replaced and left the limb
		if(QDELETED(cut) || !(cut in limb.wounds))
			seared = TRUE
	if(seared)
		victim.visible_message(span_warning("The cuts on [victim]'s [limb.plaintext_zone] sear shut!"), span_warning("The cuts on your [limb.plaintext_zone] sear shut!"))
