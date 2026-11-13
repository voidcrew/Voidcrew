// Package: P0 seams. Every plasma and frontier laser type, its identity (name, desc, icons), the type
// paths that tie guns, casings, bolts and the chamber together, and the vars more than one package
// shares. Vars set here are final: packages never set them again on the same type, since two
// assignments in different files fight over include order.

/// Floor soot decals in the world, oldest first (written by P8, capped at PLASMA_SOOT_GLOBAL_CAP)
GLOBAL_LIST_EMPTY(plasma_soot_decals)

// ===== Bolts and casings (S1) =====

/obj/projectile/energy/plasma_bolt
	name = "plasma bolt"
	icon = 'voidcrew/modules/plasma_weapons/icons/projectiles.dmi'
	icon_state = "plasma_bolt"
	/// An arm or leg this close to its max damage after the hit melts, if it was already hurt before it
	var/ash_margin = PLASMA_ASH_MARGIN_PISTOL
	/// Whether this bolt also melts an arm or leg that already carried a Plasma Burn-Through with slag still in it
	var/ash_critical_burns = FALSE
	/// Zone (any, for searing cuts), damage and slagged burn-through state of the limb this bolt hit,
	/// read in on_hit before the damage lands
	var/ash_zone
	var/ash_prior_damage = 0
	var/ash_prior_critical = FALSE
	/// The burst this bolt left on the person it hit; a melt there plays the burn-through
	var/datum/weakref/burst_ref
	/// Lazy list of mobs this bolt has already hissed past
	var/list/hissed_mobs

/obj/projectile/energy/plasma_bolt/heavy
	icon_state = "plasma_bolt_heavy"
	ash_margin = PLASMA_ASH_MARGIN_RIFLE
	ash_critical_burns = TRUE

/obj/item/ammo_casing/energy/plasma_bolt
	projectile_type = /obj/projectile/energy/plasma_bolt

/obj/item/ammo_casing/energy/plasma_bolt/heavy
	projectile_type = /obj/projectile/energy/plasma_bolt/heavy

/obj/item/ammo_casing/energy/frontier_laser
	projectile_type = /obj/projectile/beam/laser/frontier_pistol

/obj/item/ammo_casing/energy/lasergun/frontier_smg
	projectile_type = /obj/projectile/beam/laser

/obj/projectile/beam/laser/frontier_pistol

// ===== Plasma guns (S2, S3, S6) =====

/obj/item/gun/energy/plasma_weapon
	name = "plasma weapon"
	icon = 'voidcrew/modules/plasma_weapons/icons/guns.dmi'
	lefthand_file = 'voidcrew/modules/plasma_weapons/icons/guns_lefthand.dmi'
	righthand_file = 'voidcrew/modules/plasma_weapons/icons/guns_righthand.dmi'
	cell_type = /obj/item/stock_parts/power_store/cell/plasma_chamber
	can_charge = FALSE
	/// The seated cartridge, if any
	var/obj/item/plasma_cartridge/cartridge
	/// Barrel heat; only guns with uses_heat gain it. Named barrel_heat because /obj/item/var/heat is the ignition temperature.
	var/barrel_heat = 0
	/// Heat one shot adds
	var/heat_per_shot = 0
	/// Whether this gun runs the heat model (the rifles do, the pistol doesn't)
	var/uses_heat = FALSE
	/// world.time of the next allowed manual vent
	var/next_vent_at = 0
	/// world.time until which a vent blocks firing
	var/vent_lock_until = 0
	/// Coil overlay step shown, 0 to 3
	var/heat_step = 0
	/// Sound distant listeners hear when this fires
	var/far_fire_sound

/obj/item/gun/energy/plasma_weapon/pistol
	name = "\improper Cinder plasma pistol"
	desc = "A plasma pistol with a glass cartridge seated behind the grip. The barrel smells of hot metal."
	icon_state = "cinder"
	inhand_icon_state = "cinder"
	ammo_type = list(/obj/item/ammo_casing/energy/plasma_bolt)

/obj/item/gun/energy/plasma_weapon/rifle
	name = "\improper Furnace plasma rifle"
	desc = "A heavy plasma rifle. Its coils tick as they cool."
	icon = 'voidcrew/modules/plasma_weapons/icons/guns_wide.dmi'
	icon_state = "furnace"
	inhand_icon_state = "furnace_wielded"
	worn_icon = 'voidcrew/modules/plasma_weapons/icons/guns_back.dmi'
	worn_icon_state = "furnace"
	ammo_type = list(/obj/item/ammo_casing/energy/plasma_bolt/heavy)
	uses_heat = TRUE
	heat_per_shot = PLASMA_HEAT_PER_SHOT
	SET_BASE_PIXEL(-8, 0)

/obj/item/gun/energy/plasma_weapon/rifle/old_furnace
	name = "\improper Old Furnace"
	desc = "A Furnace rifle with a hand-wound coil and a pirate captain's tally burned into the stock."
	icon_state = "old_furnace"
	heat_per_shot = PLASMA_HEAT_PER_SHOT_UNIQUE

// ===== Frontier lasers (S2, S7) =====

/obj/item/gun/energy/frontier_laser
	name = "frontier laser"
	icon = 'voidcrew/modules/plasma_weapons/icons/guns.dmi'
	lefthand_file = 'voidcrew/modules/plasma_weapons/icons/guns_lefthand.dmi'
	righthand_file = 'voidcrew/modules/plasma_weapons/icons/guns_righthand.dmi'
	/// Sound distant listeners hear when this fires
	var/far_fire_sound

/obj/item/gun/energy/frontier_laser/pistol
	name = "\improper Kestrel laser pistol"
	desc = "A light laser pistol with a scuffed white grip."
	icon_state = "kestrel"
	inhand_icon_state = "kestrel"
	ammo_type = list(/obj/item/ammo_casing/energy/frontier_laser)

/obj/item/gun/energy/frontier_laser/smg
	name = "\improper Hornet laser SMG"
	desc = "A stubby laser gun built to empty its cell in a hurry."
	icon_state = "hornet"
	inhand_icon_state = "hornet_wielded"
	worn_icon = 'voidcrew/modules/plasma_weapons/icons/guns_back.dmi'
	worn_icon_state = "hornet"
	ammo_type = list(/obj/item/ammo_casing/energy/lasergun/frontier_smg)

// ===== Cartridge and chamber (S3) =====

/obj/item/plasma_cartridge
	name = "plasma cartridge"
	desc = "A glass cartridge of pressed plasma in a steel jacket."
	icon = 'voidcrew/modules/plasma_weapons/icons/cartridge.dmi'
	icon_state = "cartridge_3"
	custom_materials = list(/datum/material/iron = PLASMA_CARTRIDGE_IRON)
	/// Mol of plasma held. Only ever falls.
	var/stored = PLASMA_CARTRIDGE_CAPACITY

/obj/item/stock_parts/power_store/cell/plasma_chamber
	name = "plasma chamber"

// ===== Effects (S8) =====

/obj/effect/temp_visual/plasma_splash
	icon = 'voidcrew/modules/plasma_weapons/icons/effects.dmi'
	icon_state = "splash_wall"

/obj/effect/temp_visual/plasma_wall_glow
	icon = 'voidcrew/modules/plasma_weapons/icons/effects.dmi'
	icon_state = "wall_glow"

/obj/effect/decal/cleanable/plasma_soot
	name = "soot"
	icon = 'voidcrew/modules/plasma_weapons/icons/effects.dmi'
	icon_state = "soot"

/obj/effect/temp_visual/plasma_gutter
	icon = 'voidcrew/modules/plasma_weapons/icons/effects.dmi'
	icon_state = "gutter"

/obj/effect/temp_visual/plasma_vent_puff
	icon = 'voidcrew/modules/plasma_weapons/icons/effects.dmi'
	icon_state = "vent_puff"

/obj/effect/temp_visual/plasma_pinch
	icon = 'voidcrew/modules/plasma_weapons/icons/effects.dmi'
	icon_state = "pinch"

// ===== Pirate loadouts (S12) =====

/datum/pirate_gun_loadout/plasma_pistol
	gun_type = /obj/item/gun/energy/plasma_weapon/pistol
	energy_casing = /obj/item/ammo_casing/energy/plasma_bolt

/datum/pirate_gun_loadout/plasma_rifle
	gun_type = /obj/item/gun/energy/plasma_weapon/rifle
	energy_casing = /obj/item/ammo_casing/energy/plasma_bolt/heavy
