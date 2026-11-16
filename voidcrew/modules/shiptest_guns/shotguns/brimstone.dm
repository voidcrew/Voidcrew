// The HP Brimstone pump shotgun, ported from Shiptest (shiptest-ss13/Shiptest, AGPL-3.0 code, CC BY-SA 3.0 art).
//
// Slamfire: hold the trigger and every pump fires the moment a fresh shell is chambered.
// Built on tg's own automatic fire component, which already tracks a held mouse button:
// - Pressing the trigger starts it as on any automatic gun (on_autofire_start). With a spent or empty
//   chamber but shells in the tube it still starts, and waits, instead of dry-clicking.
// - Each tick the component asks do_autofire() for a shot. While the chamber holds no live shell but the
//   tube has some, we answer "still firing" without shooting, so the trigger stays held.
// - Pumping (attack_self -> rack, gated by rack_delay as usual) chambers a live shell; the next tick fires it.
// - When chamber and tube are both empty it dry-clicks and lets go, as any automatic gun does.
// Letting go of the button stops it. Racking with no trigger held is an ordinary pump.

/obj/item/gun/ballistic/shotgun/brimstone
	name = "\improper HP Brimstone"
	desc = "A plain, sturdy pump-action shotgun with hand-stamped maker's marks on the receiver. Chambered in 12 gauge."
	sawn_desc = "A pump shotgun with the stock and barrel hacked off. It kicks like a mule."
	icon = 'voidcrew/modules/shiptest_guns/shotguns/icons/shotguns.dmi'
	icon_state = "brimstone"
	base_icon_state = "brimstone"
	lefthand_file = 'voidcrew/modules/shiptest_guns/shotguns/icons/lefthand.dmi'
	righthand_file = 'voidcrew/modules/shiptest_guns/shotguns/icons/righthand.dmi'
	inhand_icon_state = "brimstone"
	inhand_x_dimension = 32
	inhand_y_dimension = 32
	worn_icon = 'voidcrew/modules/shiptest_guns/shotguns/icons/back.dmi'
	worn_icon_state = "brimstone"
	accepted_magazine_type = /obj/item/ammo_box/magazine/internal/shot/brimstone
	can_be_sawn_off = TRUE
	rack_delay = 4
	spread = 4

/obj/item/gun/ballistic/shotgun/brimstone/Initialize(mapload)
	. = ..()
	AddComponent(/datum/component/automatic_fire, 0.1 SECONDS)

/obj/item/gun/ballistic/shotgun/brimstone/sawoff(mob/user, obj/item/saw, handle_modifications = TRUE)
	. = ..()
	if(!.)
		return
	lefthand_file = initial(lefthand_file)
	righthand_file = initial(righthand_file)
	inhand_icon_state = "brimstone_sawn"
	worn_icon_state = "brimstone_sawn"
	weapon_weight = WEAPON_MEDIUM
	spread = 25
	recoil = 3
	update_appearance()

/// TRUE when the chamber can't fire but a pump would chamber a shell.
/obj/item/gun/ballistic/shotgun/brimstone/proc/waiting_on_pump()
	return !can_shoot() && magazine?.ammo_count()

/obj/item/gun/ballistic/shotgun/brimstone/on_autofire_start(mob/living/shooter)
	if(!waiting_on_pump())
		return ..()
	if(fire_cd || shooter.incapacitated || !can_trigger_gun(shooter))
		return FALSE
	var/obj/item/bodypart/other_hand = shooter.has_hand_for_held_index(shooter.get_inactive_hand_index())
	if(weapon_weight == WEAPON_HEAVY && (shooter.get_inactive_held_item() || !other_hand))
		balloon_alert(shooter, "use both hands!")
		return FALSE
	return TRUE

/obj/item/gun/ballistic/shotgun/brimstone/do_autofire(datum/source, atom/target, mob/living/shooter, allow_akimbo, params)
	if(waiting_on_pump() && !shooter.incapacitated)
		return COMPONENT_AUTOFIRE_SHOT_SUCCESS
	return ..()

/obj/item/ammo_box/magazine/internal/shot/brimstone
	name = "pump shotgun tube"
	ammo_type = /obj/item/ammo_casing/shotgun/buckshot
	max_ammo = 5
