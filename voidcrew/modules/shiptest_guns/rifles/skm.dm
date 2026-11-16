// The SKM-24 assault rifle and its 7.62x40mm round, ported from Shiptest (shiptest-ss13/Shiptest).
// Art and sound credits are in attribution.txt next to icons/ and sound/.
// A cheap automatic rifle: four shots a second from 20 or 40 round magazines, or a 75 round drum.

#define CALIBER_A762X40 "7.62x40mm"

/obj/projectile/bullet/a762x40
	name = "7.62x40mm bullet"
	damage = 24
	armour_penetration = 22
	wound_bonus = -35
	speed = GUN_FEEL_SPEED_RIFLE

/obj/item/ammo_casing/a762x40
	name = "7.62x40mm bullet casing"
	desc = "A 7.62x40mm bullet casing."
	icon_state = "762-casing"
	caliber = CALIBER_A762X40
	projectile_type = /obj/projectile/bullet/a762x40

/obj/item/ammo_box/magazine/skm
	name = "\improper SKM magazine (7.62x40mm)"
	desc = "A slightly curved 20-round magazine for the SKM rifle."
	icon = 'voidcrew/modules/shiptest_guns/rifles/icons/ammo.dmi'
	icon_state = "skm_mag"
	ammo_type = /obj/item/ammo_casing/a762x40
	caliber = CALIBER_A762X40
	max_ammo = 20
	multiple_sprites = AMMO_BOX_FULL_EMPTY

/obj/item/ammo_box/magazine/skm/empty
	start_empty = TRUE

/obj/item/ammo_box/magazine/skm/extended
	name = "extended SKM magazine (7.62x40mm)"
	desc = "A long, very curved 40-round magazine for the SKM rifle."
	icon_state = "skm_extended_mag"
	max_ammo = 40
	w_class = WEIGHT_CLASS_SMALL

/obj/item/ammo_box/magazine/skm/extended/empty
	start_empty = TRUE

/obj/item/ammo_box/magazine/skm/drum
	name = "\improper SKM drum (7.62x40mm)"
	desc = "A heavy 75-round drum for the SKM rifle."
	icon_state = "skm_drum"
	max_ammo = 75
	w_class = WEIGHT_CLASS_NORMAL

/obj/item/ammo_box/magazine/skm/drum/empty
	start_empty = TRUE

/obj/item/ammo_box/a762x40
	name = "stripper clip (7.62x40mm)"
	desc = "Five 7.62x40mm rounds on a stripper clip."
	icon = 'voidcrew/modules/shiptest_guns/rifles/icons/ammo.dmi'
	icon_state = "300m"
	ammo_type = /obj/item/ammo_casing/a762x40
	caliber = CALIBER_A762X40
	max_ammo = 5
	multiple_sprites = AMMO_BOX_PER_BULLET

/obj/item/ammo_box/a762x40/empty
	start_empty = TRUE

/obj/item/gun/ballistic/automatic/skm
	name = "\improper SKM-24"
	desc = "An old assault rifle, cheap to make and hard to break. Surplus ones turn up all over the frontier. Chambered in 7.62x40mm."
	icon = 'voidcrew/modules/shiptest_guns/rifles/icons/skm.dmi'
	icon_state = "skm"
	inhand_icon_state = "skm"
	worn_icon_state = "skm"
	lefthand_file = 'voidcrew/modules/shiptest_guns/rifles/icons/rifles_lefthand.dmi'
	righthand_file = 'voidcrew/modules/shiptest_guns/rifles/icons/rifles_righthand.dmi'
	worn_icon = 'voidcrew/modules/shiptest_guns/rifles/icons/rifles_back.dmi'
	fire_sound = 'voidcrew/modules/shiptest_guns/rifles/sound/skm.ogg'
	load_sound = 'voidcrew/modules/shiptest_guns/rifles/sound/skm_reload.ogg'
	load_empty_sound = 'voidcrew/modules/shiptest_guns/rifles/sound/skm_reload.ogg'
	eject_sound = 'voidcrew/modules/shiptest_guns/rifles/sound/skm_unload.ogg'
	eject_empty_sound = 'voidcrew/modules/shiptest_guns/rifles/sound/skm_unload.ogg'
	w_class = WEIGHT_CLASS_BULKY
	weapon_weight = WEAPON_MEDIUM
	slot_flags = ITEM_SLOT_BACK
	accepted_magazine_type = /obj/item/ammo_box/magazine/skm
	// Each magazine draws its own overlay: skm_mag_<magazine icon_state>.
	special_mags = TRUE
	burst_size = 1
	fire_delay = 0.25 SECONDS
	spread = 1.4
	// Fires as long as the trigger is held, so no fire selector.
	actions_types = list()
	bolt_type = BOLT_TYPE_LOCKING
	// The art has no bolt states.
	show_bolt_icon = FALSE
	// The suppressor art sits at the left of its frame; this carries it to the muzzle.
	suppressor_x_offset = 23
	gun_feel_class = GUN_FEEL_CLASS_RIFLE

/obj/item/gun/ballistic/automatic/skm/Initialize(mapload)
	. = ..()
	AddComponent(/datum/component/automatic_fire, fire_delay)
	AddComponent(/datum/component/bayonet_attachable, offset_x = 38, offset_y = 13)

#undef CALIBER_A762X40
