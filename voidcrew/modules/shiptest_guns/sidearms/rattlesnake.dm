// The MP-84 'Rattlesnake' machine pistol and its magazine, ported from Shiptest (shiptest-ss13/Shiptest, AGPL-3.0).
// Art and sound credits are in attribution.txt.
// Semi-auto, three-round burst or full auto on our 9mm. Right-click in hand moves the selector; there is no
// action button. Full auto keeps the automatic_fire component on the gun and lets the click through in the
// other two modes, so semi and burst fire through the normal click path.

#define RATTLESNAKE_SEMI 1
#define RATTLESNAKE_BURST 2
#define RATTLESNAKE_AUTO 3

/obj/item/gun/ballistic/automatic/pistol/rattlesnake
	name = "\improper MP-84 'Rattlesnake'"
	desc = "A compact machine pistol fed from a long double-stack magazine. Chambered in 9mm."
	icon = 'voidcrew/modules/shiptest_guns/sidearms/icons/rattlesnake.dmi'
	icon_state = "rattlesnake"
	lefthand_file = 'voidcrew/modules/shiptest_guns/sidearms/icons/lefthand.dmi'
	righthand_file = 'voidcrew/modules/shiptest_guns/sidearms/icons/righthand.dmi'
	inhand_icon_state = "rattlesnake"
	fire_sound = 'voidcrew/modules/shiptest_guns/sidearms/sound/rattlesnake.ogg'
	w_class = WEIGHT_CLASS_NORMAL
	accepted_magazine_type = /obj/item/ammo_box/magazine/m9mm_rattlesnake
	// Shiptest's 9mm hits for 20 where ours hits for 30.
	projectile_damage_multiplier = 0.8
	// Shiptest spread 5, plus the extra a one-handed machine pistol earns here.
	spread = 14
	// A hard kick on every shot.
	recoil = 3
	burst_size = 1
	burst_delay = 1
	fire_delay = 0
	actions_types = list()
	// The suppressor art sits where tg draws it on a Makarov; these carry it to this barrel.
	suppressor_x_offset = 24
	suppressor_y_offset = 5
	gun_feel_class = GUN_FEEL_CLASS_PISTOL
	/// RATTLESNAKE_SEMI, RATTLESNAKE_BURST or RATTLESNAKE_AUTO.
	var/fire_select = RATTLESNAKE_SEMI

/obj/item/gun/ballistic/automatic/pistol/rattlesnake/Initialize(mapload)
	. = ..()
	// Shiptest fires every 0.07 s on a 0.05 s tick: ten rounds a second.
	AddComponent(/datum/component/automatic_fire, 0.1 SECONDS)

/obj/item/gun/ballistic/automatic/pistol/rattlesnake/examine(mob/user)
	. = ..()
	switch(fire_select)
		if(RATTLESNAKE_SEMI)
			. += "The selector is on single shots."
		if(RATTLESNAKE_BURST)
			. += "The selector is on three-round bursts."
		if(RATTLESNAKE_AUTO)
			. += "The selector is on full auto."

/obj/item/gun/ballistic/automatic/pistol/rattlesnake/attack_self_secondary(mob/user, modifiers)
	set_fire_select(fire_select % RATTLESNAKE_AUTO + 1, user)
	return SECONDARY_ATTACK_CANCEL_ATTACK_CHAIN

/// Moves the selector to `mode` and sets the burst and delay values for it.
/obj/item/gun/ballistic/automatic/pistol/rattlesnake/proc/set_fire_select(mode, mob/user)
	fire_select = mode
	switch(mode)
		if(RATTLESNAKE_SEMI)
			burst_size = 1
			fire_delay = 0
			if(user)
				balloon_alert(user, "single shots")
		if(RATTLESNAKE_BURST)
			burst_size = 3
			fire_delay = 0.3 SECONDS
			if(user)
				balloon_alert(user, "three-round burst")
		if(RATTLESNAKE_AUTO)
			burst_size = 1
			fire_delay = 0
			if(user)
				balloon_alert(user, "full auto")
	playsound(src, 'sound/items/weapons/empty.ogg', 100, TRUE)

/// Only full auto takes the mouse; in the other modes the click goes on to fire the gun normally.
/obj/item/gun/ballistic/automatic/pistol/rattlesnake/autofire_bypass_check(datum/source, client/clicker, atom/target, turf/location, control, params)
	SIGNAL_HANDLER
	if(fire_select != RATTLESNAKE_AUTO)
		return COMPONENT_AUTOFIRE_ONMOUSEDOWN_BYPASS
	return ..()

/obj/item/gun/ballistic/automatic/pistol/rattlesnake/no_mag
	spawnwithmagazine = FALSE

/obj/item/ammo_box/magazine/m9mm_rattlesnake
	name = "\improper MP-84 magazine (9mm)"
	desc = "A long 18-round double-stack magazine for the MP-84 machine pistol."
	icon = 'voidcrew/modules/shiptest_guns/sidearms/icons/magazines.dmi'
	icon_state = "rattlesnake_mag_18"
	base_icon_state = "rattlesnake_mag"
	ammo_type = /obj/item/ammo_casing/c9mm
	caliber = CALIBER_9MM
	max_ammo = 18

/// Drawn in steps of three rounds: rattlesnake_mag_0, _1, _3 ... _18.
/obj/item/ammo_box/magazine/m9mm_rattlesnake/update_icon_state()
	. = ..()
	var/rounds = ammo_count()
	icon_state = "[base_icon_state]_[rounds == 1 ? 1 : round(rounds, 3)]"

/obj/item/ammo_box/magazine/m9mm_rattlesnake/empty
	start_empty = TRUE

#undef RATTLESNAKE_SEMI
#undef RATTLESNAKE_BURST
#undef RATTLESNAKE_AUTO
