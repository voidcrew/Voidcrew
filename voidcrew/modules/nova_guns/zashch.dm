// The 'Zashch' heavy pistol and its magazine, ported from Nova Sector (NovaSector/NovaSector).
// Art and sound credits are in attribution.txt next to icons/ and sound/.
// A slow 10mm pistol with a deep box magazine and a seclite that cannot be taken off.

/obj/item/gun/ballistic/automatic/pistol/zashch
	name = "\improper 'Zashch' heavy pistol"
	desc = "A hulking, self-loading 10mm handgun, designated 'Zashchitnik'. Feeds from large box magazines."
	icon = 'voidcrew/modules/nova_guns/icons/zashch.dmi'
	icon_state = "zashch"
	lefthand_file = 'voidcrew/modules/nova_guns/icons/zashch_lefthand.dmi'
	righthand_file = 'voidcrew/modules/nova_guns/icons/zashch_righthand.dmi'
	inhand_icon_state = "zashch"
	w_class = WEIGHT_CLASS_NORMAL
	accepted_magazine_type = /obj/item/ammo_box/magazine/zashch
	can_suppress = FALSE
	fire_delay = 1 SECONDS
	fire_sound = 'voidcrew/modules/nova_guns/sound/pistol_heavy.ogg'
	fire_sound_volume = 80
	rack_sound = 'sound/items/weapons/gun/pistol/rack.ogg'
	lock_back_sound = 'sound/items/weapons/gun/pistol/slide_lock.ogg'
	bolt_drop_sound = 'sound/items/weapons/gun/pistol/slide_drop.ogg'

/obj/item/gun/ballistic/automatic/pistol/zashch/add_seclight_point()
	AddComponent(/datum/component/seclite_attachable, \
		starting_light = new /obj/item/flashlight/seclite(src), \
		is_light_removable = FALSE, \
	)

/obj/item/ammo_box/magazine/zashch
	name = "\improper Zashch pistol magazine"
	desc = "A large 10mm box magazine for the 'Zashch' heavy pistol."
	icon = 'voidcrew/modules/nova_guns/icons/magazines.dmi'
	icon_state = "zashch_mag"
	base_icon_state = "zashch_mag"
	ammo_type = /obj/item/ammo_casing/c10mm
	caliber = CALIBER_10MM
	max_ammo = 20
	multiple_sprites = AMMO_BOX_FULL_EMPTY

/obj/item/ammo_box/magazine/zashch/empty
	start_empty = TRUE
