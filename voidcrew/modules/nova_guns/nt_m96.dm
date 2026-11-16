// The NT M-96, ported from Nova Sector (NovaSector/NovaSector), where it is called the c96.
// Art and sound credits are in attribution.txt next to icons/ and sound/.
// A self-loading 9mm with a ten round internal magazine. It is a rifle subtype to get the bolt and
// internal magazine handling: the bolt locks open on an empty gun, and rounds go in with it open.

/obj/item/gun/ballistic/rifle/nt_m96
	name = "\improper NT M-96"
	desc = "A reproduction of an antique pistol, built under a long-expired patent for collectors. Cheaper than the original, and still not cheap."
	icon = 'voidcrew/modules/nova_guns/icons/nt_m96.dmi'
	icon_state = "mauser"
	inhand_icon_state = "gun"
	worn_icon_state = "gun"
	fire_sound = 'voidcrew/modules/nova_guns/sound/bay_gunshot_magnum.ogg'
	fire_sound_volume = 80
	w_class = WEIGHT_CLASS_NORMAL
	slot_flags = ITEM_SLOT_BELT
	accepted_magazine_type = /obj/item/ammo_box/magazine/internal/nt_m96
	can_suppress = FALSE
	need_bolt_lock_to_interact = TRUE
	weapon_weight = WEAPON_MEDIUM
	// A self-loader: each spent case is ejected as it fires and the next round is chambered.
	semi_auto = TRUE
	fire_delay = 0.45 SECONDS
	projectile_damage_multiplier = 0.75
	spread = 3.5
	// A /rifle subtype would pick the marksman kick. This handles like a pistol.
	gun_feel_class = GUN_FEEL_CLASS_PISTOL

/obj/item/ammo_box/magazine/internal/nt_m96
	name = "\improper NT M-96 internal magazine"
	desc = "Oh god, this shouldn't be here"
	ammo_type = /obj/item/ammo_casing/c9mm
	caliber = CALIBER_9MM
	max_ammo = 10
