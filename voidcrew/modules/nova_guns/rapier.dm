// The M-94 'Rapier' submachinegun and its magazine, ported from Nova Sector (NovaSector/NovaSector).
// Art and sound credits are in attribution.txt next to icons/ and sound/.
// A lighter-hitting WT-550 in the same 4.6x30mm, with 30 round magazines and a threaded barrel.

/obj/item/gun/ballistic/automatic/rapier
	name = "\improper M-94 'Rapier' submachinegun"
	desc = "An elegant automatic submachinegun, popular with the roguish and unsavory sort. Uses 4.6x30mm rounds."
	icon = 'voidcrew/modules/nova_guns/icons/rapier.dmi'
	icon_state = "rapier"
	inhand_icon_state = "arg"
	fire_sound = 'voidcrew/modules/nova_guns/sound/smg_light.ogg'
	bolt_type = BOLT_TYPE_LOCKING
	w_class = WEIGHT_CLASS_BULKY
	weapon_weight = WEAPON_MEDIUM
	burst_size = 1
	fire_delay = 0.3 SECONDS
	projectile_damage_multiplier = 0.8
	projectile_speed_multiplier = 1.1
	accepted_magazine_type = /obj/item/ammo_box/magazine/rapier
	// One shot per pull, so no fire selector.
	actions_types = list()
	// The suppressor art sits at the left of its frame; these carry it to the end of the barrel.
	suppressor_x_offset = 20
	suppressor_y_offset = 2
	// Bulky and automatic would pick the rifle kick and sounds. This is an SMG.
	gun_feel_class = GUN_FEEL_CLASS_SMG

/obj/item/gun/ballistic/automatic/rapier/Initialize(mapload)
	. = ..()
	AddComponent(/datum/component/automatic_fire, fire_delay)

/obj/item/ammo_box/magazine/rapier
	name = "\improper M-94 'Rapier' magazine"
	desc = "A 4.6x30mm magazine for the M-94 'Rapier'."
	icon = 'voidcrew/modules/nova_guns/icons/magazines.dmi'
	icon_state = "rapier"
	ammo_type = /obj/item/ammo_casing/c46x30mm
	caliber = CALIBER_46X30MM
	max_ammo = 30
	multiple_sprites = AMMO_BOX_FULL_EMPTY

/obj/item/ammo_box/magazine/rapier/empty
	start_empty = TRUE
