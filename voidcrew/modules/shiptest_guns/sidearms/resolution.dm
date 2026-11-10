// The PD46 'Resolution' personal defense weapon and its magazine, ported from Shiptest (shiptest-ss13/Shiptest, AGPL-3.0).
// Art and sound credits are in attribution.txt.
// Full auto 4.6x30mm with a built-in folding stock. Right-click in hand folds or unfolds it: folded it is a normal
// sized gun that kicks and wanders, unfolded it is bulky and steady. There is no action button.

/obj/item/gun/ballistic/automatic/resolution
	name = "\improper PD46 'Resolution'"
	desc = "A compact personal defense weapon with a folding stock and a magazine that lies along the top. Chambered in 4.6x30mm."
	icon = 'voidcrew/modules/shiptest_guns/sidearms/icons/resolution.dmi'
	icon_state = "resolution"
	lefthand_file = 'voidcrew/modules/shiptest_guns/sidearms/icons/lefthand.dmi'
	righthand_file = 'voidcrew/modules/shiptest_guns/sidearms/icons/righthand.dmi'
	inhand_icon_state = "resolution"
	fire_sound = 'voidcrew/modules/shiptest_guns/sidearms/sound/resolution.ogg'
	accepted_magazine_type = /obj/item/ammo_box/magazine/resolution
	bolt_type = BOLT_TYPE_LOCKING
	// The magazine and the open feed cover are drawn into the two base states instead.
	mag_display = FALSE
	show_bolt_icon = FALSE
	w_class = WEIGHT_CLASS_NORMAL
	weapon_weight = WEAPON_MEDIUM
	burst_size = 1
	// Shiptest spread 8 folded, 3 unfolded.
	spread = 11
	recoil = 1
	actions_types = list()
	// The suppressor art sits where tg draws it on a Saber; these carry it to this barrel.
	suppressor_x_offset = 17
	suppressor_y_offset = 1
	// A medium-weight automatic would pick the rifle kick and sounds. This is an SMG.
	gun_feel_class = GUN_FEEL_CLASS_SMG
	/// TRUE while the stock is out.
	var/stock_extended = FALSE

/obj/item/gun/ballistic/automatic/resolution/Initialize(mapload)
	. = ..()
	// Shiptest fires every 0.13 s on a 0.05 s tick: one shot every 0.15 s.
	AddComponent(/datum/component/automatic_fire, 0.15 SECONDS)

/obj/item/gun/ballistic/automatic/resolution/examine(mob/user)
	. = ..()
	. += "The stock is [stock_extended ? "extended" : "folded"]."

/obj/item/gun/ballistic/automatic/resolution/attack_self_secondary(mob/user, modifiers)
	set_stock(!stock_extended, user)
	return SECONDARY_ATTACK_CANCEL_ATTACK_CHAIN

/// Folds or unfolds the stock.
/obj/item/gun/ballistic/automatic/resolution/proc/set_stock(extend, mob/user)
	if(extend == stock_extended)
		return
	stock_extended = extend
	if(extend)
		update_weight_class(w_class + 1)
		spread = 4
		recoil = 0
	else
		update_weight_class(w_class - 1)
		spread = initial(spread)
		recoil = initial(recoil)
	if(user)
		balloon_alert(user, extend ? "stock extended" : "stock folded")
	playsound(src, 'sound/items/weapons/empty.ogg', 100, TRUE)
	update_appearance()

/obj/item/gun/ballistic/automatic/resolution/update_icon_state()
	. = ..()
	if(!magazine)
		icon_state = "[icon_state]_nomag"

/obj/item/gun/ballistic/automatic/resolution/update_overlays()
	. = ..()
	. += "resolution_stock_[stock_extended ? "extended" : "folded"]"

/obj/item/gun/ballistic/automatic/resolution/no_mag
	spawnwithmagazine = FALSE

/obj/item/ammo_box/magazine/resolution
	name = "\improper PD46 magazine (4.6x30mm)"
	desc = "A 30-round 4.6x30mm magazine for the PD46."
	icon = 'voidcrew/modules/shiptest_guns/sidearms/icons/magazines.dmi'
	icon_state = "resolution_mag"
	ammo_type = /obj/item/ammo_casing/c46x30mm
	caliber = CALIBER_46X30MM
	max_ammo = 30
	multiple_sprites = AMMO_BOX_FULL_EMPTY

/obj/item/ammo_box/magazine/resolution/empty
	start_empty = TRUE
