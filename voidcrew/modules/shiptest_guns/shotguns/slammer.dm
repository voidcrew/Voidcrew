// The Slammer, ported from Shiptest (shiptest-ss13/Shiptest, AGPL-3.0 code, CC BY-SA 3.0 art).
// A pump shotgun that feeds from box magazines: pump between shots, swap magazines to reload.

/obj/item/gun/ballistic/shotgun/slammer
	name = "\improper Slammer"
	desc = "A dated riot shotgun that feeds from box magazines and still has to be pumped. Chambered in 12 gauge."
	icon = 'voidcrew/modules/shiptest_guns/shotguns/icons/shotguns.dmi'
	icon_state = "slammer"
	base_icon_state = "slammer"
	lefthand_file = 'voidcrew/modules/shiptest_guns/shotguns/icons/lefthand.dmi'
	righthand_file = 'voidcrew/modules/shiptest_guns/shotguns/icons/righthand.dmi'
	inhand_icon_state = "slammer"
	inhand_x_dimension = 32
	inhand_y_dimension = 32
	worn_icon = 'voidcrew/modules/shiptest_guns/shotguns/icons/back.dmi'
	worn_icon_state = "slammer"
	accepted_magazine_type = /obj/item/ammo_box/magazine/m12g_slammer
	internal_magazine = FALSE
	tac_reloads = TRUE
	mag_display = TRUE
	load_sound = 'voidcrew/modules/gun_feel/sound/rifle/ar_reload.ogg'
	load_empty_sound = 'voidcrew/modules/gun_feel/sound/rifle/ar_reload.ogg'
	eject_sound = 'voidcrew/modules/gun_feel/sound/rifle/ar_unload.ogg'
	eject_empty_sound = 'voidcrew/modules/gun_feel/sound/rifle/ar_unload.ogg'
	weapon_weight = WEAPON_MEDIUM
	rack_delay = 4
	spread = 4
	projectile_damage_multiplier = 1.75

/obj/item/ammo_box/magazine/m12g_slammer
	name = "slammer box magazine (12g buckshot)"
	desc = "A six-shell box magazine for the Slammer."
	icon = 'voidcrew/modules/shiptest_guns/shotguns/icons/magazines.dmi'
	icon_state = "slammer_mag-full"
	base_icon_state = "slammer_mag"
	ammo_type = /obj/item/ammo_casing/shotgun/buckshot
	caliber = CALIBER_SHOTGUN
	max_ammo = 6
	multiple_sprites = AMMO_BOX_FULL_EMPTY
	multiple_sprite_use_base = TRUE

/obj/item/ammo_box/magazine/m12g_slammer/empty
	start_empty = TRUE
