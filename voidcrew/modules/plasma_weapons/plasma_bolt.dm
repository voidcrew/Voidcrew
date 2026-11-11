// Package: P1 bolt. The plasma bolts and their casings: stats, fuel ignition in Moved(), fire stacks
// and ash registration in on_hit(), and the calls out to the P8 effects.

/obj/projectile/energy/plasma_bolt
	damage = 30
	damage_type = BURN
	armor_flag = ENERGY
	armour_penetration = 10
	wound_bonus = 0
	exposed_wound_bonus = 15
	speed = 1
	range = 20
	// Plasma is matter: no mirror turns it, and glass and grilles stop it (pass_flags stays PASSTABLE).
	reflectable = NONE
	dismemberment = 0
	hitsound = 'sound/items/weapons/sear.ogg'
	hitsound_wall = 'sound/items/weapons/effects/searwall.ogg'
	impact_effect_type = null
	light_system = OVERLAY_LIGHT
	light_range = 2
	light_power = 1.2
	light_color = PLASMA_LIGHT_COLOR

/obj/projectile/energy/plasma_bolt/heavy
	damage = 45
	armour_penetration = 20
	wound_bonus = 5
	exposed_wound_bonus = 20
	range = 25
	light_range = 2.5
	light_power = 1.6

/obj/projectile/energy/plasma_bolt/Destroy()
	hissed_mobs = null
	return ..()

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
	if(fire_stacks_on_hit)
		victim.adjust_fire_stacks(fire_stacks_on_hit)
		victim.ignite_mob()
	// on_hit runs before the damage lands, so the ash check waits for it.
	RegisterSignal(victim, COMSIG_MOB_AFTER_APPLY_DAMAGE, PROC_REF(plasma_check_ash), override = TRUE)

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
