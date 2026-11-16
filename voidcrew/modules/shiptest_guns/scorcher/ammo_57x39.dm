// 5.7x39mm, the Heater's round, ported from Shiptest (shiptest-ss13/Shiptest).
// Shiptest's numbers converted to ours: 20 damage, its armor piercing 10 as our 12.

#ifndef CALIBER_57X39MM
#define CALIBER_57X39MM "5.7x39mm"
#endif

/obj/projectile/bullet/c57x39mm
	name = "5.7x39mm bullet"
	damage = 20
	armour_penetration = 12
	wound_bonus = -5
	exposed_wound_bonus = 5
	embed_falloff_tile = -4

/obj/item/ammo_casing/c57x39mm
	name = "5.7x39mm bullet casing"
	desc = "A 5.7x39mm bullet casing."
	caliber = CALIBER_57X39MM
	projectile_type = /obj/projectile/bullet/c57x39mm

/obj/item/ammo_box/magazine/heater
	name = "\improper Heater magazine (5.7x39mm)"
	desc = "A 30-round 5.7x39mm magazine for the Heater."
	icon = 'voidcrew/modules/shiptest_guns/scorcher/icons/magazines.dmi'
	icon_state = "heater_mag-full"
	base_icon_state = "heater_mag"
	multiple_sprite_use_base = TRUE
	ammo_type = /obj/item/ammo_casing/c57x39mm
	caliber = CALIBER_57X39MM
	max_ammo = 30
	multiple_sprites = AMMO_BOX_FULL_EMPTY

/obj/item/ammo_box/magazine/heater/empty
	start_empty = TRUE
