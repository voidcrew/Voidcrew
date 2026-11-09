// Lever-action guns ported from Shiptest (shiptest-ss13/Shiptest, AGPL-3.0 code, CC BY-SA 3.0 art).
// Art credits are in attribution.txt beside icons/. Sounds are our own stock and gun-feel files.
//
// They sit on tg's pump shotgun: a tube magazine and a manual cycle per shot, with "lever" wording.
// Racking the lever spins the gun once.

/obj/item/gun/ballistic/shotgun/flaming_arrow
	name = "\improper HP Flaming Arrow"
	desc = "A light lever-action rifle with hand-stamped maker's marks on the receiver. Chambered in .38."
	sawn_desc = "A lever-action rifle sawn down to pistol size. It looks great, which was the point."
	icon = 'voidcrew/modules/shiptest_guns/shotguns/icons/shotguns.dmi'
	icon_state = "flamingarrow"
	base_icon_state = "flamingarrow"
	lefthand_file = 'voidcrew/modules/shiptest_guns/shotguns/icons/lefthand.dmi'
	righthand_file = 'voidcrew/modules/shiptest_guns/shotguns/icons/righthand.dmi'
	inhand_icon_state = "flamingarrow"
	inhand_x_dimension = 32
	inhand_y_dimension = 32
	worn_icon = 'voidcrew/modules/shiptest_guns/shotguns/icons/back.dmi'
	worn_icon_state = "flamingarrow"
	accepted_magazine_type = /obj/item/ammo_box/magazine/internal/shot/flaming_arrow
	fire_sound = 'sound/items/weapons/gun/revolver/shot.ogg'
	rack_sound = 'voidcrew/modules/gun_feel/sound/rifle/ar_cock.ogg'
	load_sound = 'sound/items/weapons/gun/revolver/load_bullet.ogg'
	bolt_wording = "lever"
	cartridge_wording = "bullet"
	can_be_sawn_off = TRUE
	weapon_weight = WEAPON_MEDIUM
	// A rifle, not a shotgun: no point-blank shove.
	pb_knockback = 0
	// A /shotgun subtype would pick the shotgun kick. This is a pistol-calibre carbine.
	gun_feel_class = GUN_FEEL_CLASS_RIFLE
	/// Spread once sawn off.
	var/sawn_spread = 6
	/// Recoil once sawn off.
	var/sawn_recoil = 1
	/// Tube capacity once sawn off. Null keeps the full tube.
	var/sawn_tube_capacity = 7

/obj/item/gun/ballistic/shotgun/flaming_arrow/rack(mob/user = null)
	. = ..()
	if(user)
		SpinAnimation(7, 1)

/obj/item/gun/ballistic/shotgun/flaming_arrow/sawoff(mob/user, obj/item/saw, handle_modifications = TRUE)
	. = ..()
	if(!.)
		return
	// tg's sawoff swaps in its own generic inhands; ours have sawn-off states.
	lefthand_file = initial(lefthand_file)
	righthand_file = initial(righthand_file)
	inhand_icon_state = "[base_icon_state]_sawn"
	worn_icon_state = "[base_icon_state]_sawn"
	weapon_weight = WEAPON_MEDIUM
	spread = sawn_spread
	recoil = sawn_recoil
	if(sawn_tube_capacity && magazine)
		magazine.max_ammo = sawn_tube_capacity
		var/atom/drop_turf = drop_location()
		while(length(magazine.stored_ammo) > magazine.max_ammo)
			var/obj/item/ammo_casing/extra = magazine.get_round()
			if(!extra)
				break
			magazine.stored_ammo -= extra
			extra.forceMove(drop_turf)
			extra.bounce_away(FALSE, NONE)
		magazine.update_appearance()
	update_appearance()

/obj/item/ammo_box/magazine/internal/shot/flaming_arrow
	name = "lever-action rifle tube"
	ammo_type = /obj/item/ammo_casing/c38
	caliber = CALIBER_38
	max_ammo = 18

/obj/item/gun/ballistic/shotgun/flaming_arrow/absolution
	name = "\improper HP Absolution"
	desc = "A big lever-action rifle with hand-stamped maker's marks on the receiver, built for game that bites back. Chambered in .357."
	sawn_desc = "A big lever-action rifle sawn down for the holster. You should probably have bought a revolver."
	icon_state = "absolution"
	base_icon_state = "absolution"
	inhand_icon_state = "absolution"
	worn_icon_state = "absolution"
	accepted_magazine_type = /obj/item/ammo_box/magazine/internal/shot/absolution
	fire_sound = 'sound/items/weapons/gun/revolver/shot_alt.ogg'
	sawn_tube_capacity = null

/obj/item/ammo_box/magazine/internal/shot/absolution
	name = "big lever-action rifle tube"
	ammo_type = /obj/item/ammo_casing/c357
	caliber = CALIBER_357
	max_ammo = 8

/obj/item/gun/ballistic/shotgun/flaming_arrow/conflagration
	name = "\improper HP Conflagration"
	desc = "A light lever-action shotgun with hand-stamped maker's marks on the receiver. Quick on the lever. Chambered in 12 gauge."
	sawn_desc = "A lever-action shotgun sawn down to a hand cannon. It spins nicely."
	icon_state = "conflagration"
	base_icon_state = "conflagration"
	inhand_icon_state = "conflagration"
	worn_icon_state = "conflagration"
	accepted_magazine_type = /obj/item/ammo_box/magazine/internal/shot/conflagration
	fire_sound = 'sound/items/weapons/gun/shotgun/shot.ogg'
	load_sound = 'sound/items/weapons/gun/shotgun/insert_shell.ogg'
	cartridge_wording = "shell"
	rack_delay = 4
	spread = 4
	projectile_damage_multiplier = 1.75
	pb_knockback = 2
	gun_feel_class = GUN_FEEL_CLASS_SHOTGUN
	sawn_spread = 11
	sawn_recoil = 2
	sawn_tube_capacity = 5

/obj/item/ammo_box/magazine/internal/shot/conflagration
	name = "lever-action shotgun tube"
	ammo_type = /obj/item/ammo_casing/shotgun/buckshot
	max_ammo = 6
