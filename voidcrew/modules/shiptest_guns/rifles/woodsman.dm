// The Model 23 Woodsman semi-automatic hunting rifle and its 8x50mmR round, ported from Shiptest
// (shiptest-ss13/Shiptest). Art credits are in attribution.txt next to icons/.
// A scoped marksman rifle between the bolt-action Sakhnos and the automatic rifles: one aimed shot
// every 0.75 seconds from a 5 round magazine, and the round goes through a vest.

#define CALIBER_A8X50R "8x50mmR"

/obj/projectile/bullet/a8x50r
	name = "8x50mmR bullet"
	damage = 50
	armour_penetration = 30
	wound_bonus = -30
	speed = GUN_FEEL_SPEED_RIFLE

/obj/item/ammo_casing/a8x50r
	name = "8x50mmR bullet casing"
	desc = "An 8x50mmR bullet casing."
	icon_state = "762-casing"
	caliber = CALIBER_A8X50R
	projectile_type = /obj/projectile/bullet/a8x50r

/obj/item/ammo_box/magazine/m23
	name = "\improper Model 23 magazine (8x50mmR)"
	desc = "A 5-round magazine for the Model 23 Woodsman."
	icon = 'voidcrew/modules/shiptest_guns/rifles/icons/ammo.dmi'
	icon_state = "woodsman_mag"
	ammo_type = /obj/item/ammo_casing/a8x50r
	caliber = CALIBER_A8X50R
	max_ammo = 5
	multiple_sprites = AMMO_BOX_FULL_EMPTY

/obj/item/ammo_box/magazine/m23/empty
	start_empty = TRUE

/obj/item/ammo_box/a8x50r
	name = "stripper clip (8x50mmR)"
	desc = "Five 8x50mmR rounds on a stripper clip."
	icon = 'voidcrew/modules/shiptest_guns/rifles/icons/ammo.dmi'
	icon_state = "850"
	ammo_type = /obj/item/ammo_casing/a8x50r
	caliber = CALIBER_A8X50R
	max_ammo = 5
	multiple_sprites = AMMO_BOX_PER_BULLET

/obj/item/ammo_box/a8x50r/empty
	start_empty = TRUE

/obj/item/gun/ballistic/automatic/woodsman
	name = "\improper Model 23 Woodsman"
	desc = "A large semi-automatic hunting rifle with a fixed scope, built for big game. Chambered in 8x50mmR."
	icon = 'voidcrew/modules/shiptest_guns/rifles/icons/woodsman.dmi'
	icon_state = "woodsman"
	inhand_icon_state = "woodsman"
	worn_icon_state = "woodsman"
	lefthand_file = 'voidcrew/modules/shiptest_guns/rifles/icons/rifles_lefthand.dmi'
	righthand_file = 'voidcrew/modules/shiptest_guns/rifles/icons/rifles_righthand.dmi'
	worn_icon = 'voidcrew/modules/shiptest_guns/rifles/icons/rifles_back.dmi'
	fire_sound = 'sound/items/weapons/gun/rifle/shot.ogg'
	w_class = WEIGHT_CLASS_BULKY
	weapon_weight = WEAPON_MEDIUM
	slot_flags = ITEM_SLOT_BACK
	accepted_magazine_type = /obj/item/ammo_box/magazine/m23
	burst_size = 1
	fire_delay = 0.75 SECONDS
	recoil = 1
	// One shot per pull, so no fire selector.
	actions_types = list()
	can_suppress = FALSE
	bolt_type = BOLT_TYPE_LOCKING
	// The art has no bolt states.
	show_bolt_icon = FALSE
	// Semi-automatic and not a /rifle, so the guess would be an automatic rifle.
	gun_feel_class = GUN_FEEL_CLASS_MARKSMAN

/obj/item/gun/ballistic/automatic/woodsman/Initialize(mapload)
	. = ..()
	AddComponent(/datum/component/scope, range_modifier = 2)
	AddComponent(/datum/component/bayonet_attachable, offset_x = 36, offset_y = 14)

#undef CALIBER_A8X50R
