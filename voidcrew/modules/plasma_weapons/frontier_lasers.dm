// Package: P4 frontier lasers. The Kestrel laser pistol and Hornet laser SMG, their casings and the
// Kestrel's projectile.
//
// Both are plain cell lasers that take a recharger. Neither subtypes /obj/item/gun/energy/laser, so the
// laser export and the laser slapcraft skip them. The Hornet fires the stock /obj/projectile/beam/laser.

/obj/item/gun/energy/frontier_laser
	vary_fire_sound = FALSE
	// The sprites have a full and an _empty state and no charge overlay states
	automatic_charge_overlays = FALSE

/obj/item/gun/energy/frontier_laser/update_icon_state()
	var/obj/item/ammo_casing/energy/shot = length(ammo_type) ? ammo_type[select] : null
	var/loaded = cell && istype(shot) && cell.charge >= shot.e_cost
	icon_state = "[initial(icon_state)][loaded ? "" : "_empty"]"
	return ..()

/// The stock energy gun drops the shot's pitch as the cell runs down; these stop at FRONTIER_LASER_MIN_PITCH and vary a little
/obj/item/gun/energy/frontier_laser/fire_sounds()
	var/pitch_to_use = 1
	var/obj/item/ammo_casing/energy/shot = ammo_type[select]
	var/shot_cost_percent = round(clamp(shot.e_cost / cell.maxcharge, 0, 1) * 100)
	if(shot_cost_percent > 0 && shot_cost_percent < 50)
		var/max_shots = round(100 / shot_cost_percent) - 1
		var/shots_left = round((round(clamp(cell.charge / cell.maxcharge, 0, 1) * 100)) / shot_cost_percent) - 1
		pitch_to_use = max(LERP(1, 0.3, (1 - (shots_left / max_shots)) ** 2), FRONTIER_LASER_MIN_PITCH)

	var/sound/playing_sound = sound(suppressed ? suppressed_sound : fire_sound)
	playing_sound.pitch = pitch_to_use
	if(suppressed)
		playsound(src, playing_sound, suppressed_volume, TRUE, ignore_walls = FALSE, extrarange = SILENCED_SOUND_EXTRARANGE, frequency = PLASMA_SHOT_FREQUENCY, falloff_distance = 0)
	else
		playsound(src, playing_sound, fire_sound_volume, TRUE, frequency = PLASMA_SHOT_FREQUENCY)

/obj/item/gun/energy/frontier_laser/shoot_live_shot(mob/living/user, pointblank = FALSE, atom/pbtarget = null, message = TRUE)
	. = ..()
	if(!suppressed)
		plasma_weapons_far_sound(src, far_fire_sound)

// ===== Kestrel laser pistol =====

/obj/item/gun/energy/frontier_laser/pistol
	w_class = WEIGHT_CLASS_NORMAL
	slot_flags = ITEM_SLOT_BELT
	weapon_weight = WEAPON_LIGHT
	force = 10
	spread = 0
	recoil = 0
	fire_sound_volume = 45
	far_fire_sound = 'voidcrew/modules/plasma_weapons/sound/kestrel_far.ogg'

/// Energy guns take fire_delay from the casing's delay (update_ammo_types), so the 0.5 s lives here.
/obj/item/ammo_casing/energy/frontier_laser
	e_cost = LASER_SHOTS(20, STANDARD_CELL_CHARGE)
	delay = 5
	select_name = "kill"
	fire_sound = 'voidcrew/modules/plasma_weapons/sound/kestrel_fire.ogg'

/obj/projectile/beam/laser/frontier_pistol
	damage = 20

// ===== Hornet laser SMG =====

/obj/item/gun/energy/frontier_laser/smg
	w_class = WEIGHT_CLASS_BULKY
	slot_flags = ITEM_SLOT_BACK
	weapon_weight = WEAPON_MEDIUM
	force = 12
	spread = 8
	recoil = 0
	fire_sound_volume = 45
	far_fire_sound = 'voidcrew/modules/plasma_weapons/sound/hornet_far.ogg'

/obj/item/gun/energy/frontier_laser/smg/Initialize(mapload)
	. = ..()
	AddComponent(/datum/component/automatic_fire, 0.35 SECONDS, allow_akimbo = FALSE)

/// Fires the stock laser (owner decision 3); only the cost and sound differ from the laser gun's casing.
/obj/item/ammo_casing/energy/lasergun/frontier_smg
	e_cost = LASER_SHOTS(20, STANDARD_CELL_CHARGE)
	fire_sound = 'voidcrew/modules/plasma_weapons/sound/hornet_fire.ogg'
