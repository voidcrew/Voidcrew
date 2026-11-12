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
	hitsound_wall = 'sound/items/weapons/effects/searwall.ogg'
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
	light_range = 2.5
	light_power = 1.6

/obj/projectile/energy/plasma_bolt
	/// Where a person hit is struck, in pixels from the centre of their turf, set by the burst
	var/list/impact_point
	/// The turf impact_point is measured on
	var/turf/impact_turf

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
	stop = clamp(stop, 0, max(full, 0) + ICON_SIZE_ALL / 2)
	var/anim_time = full > 0 ? animate_time * stop / full : 0
	// Drop this tick's earlier steps first: a step taken before the bolt crossed into the target's turf is in
	// the last turf's pixels, and chained after it this one would overshoot the stop by up to a tile
	animate(src)
	animate(src, pixel_x = pixel_x + dx * stop, pixel_y = pixel_y + dy * stop, time = anim_time, flags = ANIMATION_PARALLEL)
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
	. = ..()
	plasma_impact_visuals(target, blocked)
	plasma_expose_turf(get_turf(target))
	if(. != BULLET_ACT_HIT || !iscarbon(target) || blocked >= 100)
		return
	var/mob/living/carbon/victim = target
	// on_hit runs before the damage lands: note the limb's state now, and check for a melt after it.
	var/obj/item/bodypart/limb = victim.get_bodypart(check_zone(def_zone))
	if(!limb || !(limb.body_zone in GLOB.limb_zones))
		return
	ash_zone = limb.body_zone
	ash_prior_damage = limb.get_damage()
	ash_prior_critical = !!limb.get_wound_type(/datum/wound/burn/flesh/critical)
	RegisterSignal(victim, COMSIG_MOB_AFTER_APPLY_DAMAGE, PROC_REF(plasma_check_ash), override = TRUE)

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

/// Sears the bleeding cuts on a limb a bolt just hit. Seam stub; the bolt hooks fill it in.
/proc/plasma_sear_cuts(obj/item/bodypart/limb)
	return
