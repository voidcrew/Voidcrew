// The Heater PDW and the Scorcher, a Heater with a flamethrower bolted under it.
// Ported from Shiptest (shiptest-ss13/Shiptest, frontier_import/ballistics.dm and
// gun_attachments/flamethrower.dm). Art credits are in attribution.txt.
// The flamethrower is part of the gun: right-click sprays tg's flamethrower plume
// (the same projectile as the MOD flamethrower module) and burns welding fuel from a
// small internal tank, refilled from any container or tank holding welding fuel.

/// Fuel the Scorcher's tank holds, in units of welding fuel.
#define SCORCHER_MAX_FUEL 40
/// Fuel one spray burns.
#define SCORCHER_FUEL_PER_SPRAY 5
/// Time between sprays.
#define SCORCHER_SPRAY_COOLDOWN (2 SECONDS)

/obj/item/gun/ballistic/automatic/heater
	name = "\improper Heater"
	desc = "A compact frontier PDW with a closed bolt and no stock. Chambered in 5.7x39mm."
	icon = 'voidcrew/modules/shiptest_guns/scorcher/icons/scorcher.dmi'
	icon_state = "heater"
	inhand_icon_state = "heater"
	lefthand_file = 'voidcrew/modules/shiptest_guns/scorcher/icons/scorcher_lefthand.dmi'
	righthand_file = 'voidcrew/modules/shiptest_guns/scorcher/icons/scorcher_righthand.dmi'
	worn_icon = 'voidcrew/modules/shiptest_guns/scorcher/icons/scorcher_onmob.dmi'
	worn_icon_state = "heater"
	w_class = WEIGHT_CLASS_NORMAL
	weapon_weight = WEAPON_MEDIUM
	slot_flags = ITEM_SLOT_BACK | ITEM_SLOT_BELT
	accepted_magazine_type = /obj/item/ammo_box/magazine/heater
	burst_size = 1
	// Shiptest's 0.12 s fire delay fires every 0.15 s there; spread 4 there is about 6 here.
	fire_delay = 0.15 SECONDS
	spread = 6
	can_suppress = FALSE
	show_bolt_icon = FALSE
	// Fully automatic only, so no fire selector.
	actions_types = list()
	gun_feel_class = GUN_FEEL_CLASS_SMG

/obj/item/gun/ballistic/automatic/heater/Initialize(mapload)
	. = ..()
	AddComponent(/datum/component/automatic_fire, fire_delay)

/obj/item/gun/ballistic/automatic/heater/scorcher
	name = "\improper Scorcher"
	desc = "A Heater with a stock, a fuel tank and a flamethrower bolted on underneath. Chambered in 5.7x39mm."
	icon_state = "scorcher"
	inhand_icon_state = "scorcher"
	worn_icon_state = "scorcher"
	w_class = WEIGHT_CLASS_BULKY
	slot_flags = ITEM_SLOT_BACK
	/// Units of welding fuel in the flamethrower's tank.
	var/fuel = SCORCHER_MAX_FUEL
	COOLDOWN_DECLARE(spray_cooldown)

/obj/item/gun/ballistic/automatic/heater/scorcher/examine(mob/user)
	. = ..()
	if(fuel >= SCORCHER_MAX_FUEL)
		. += "The fuel tank is full."
	else if(fuel >= SCORCHER_MAX_FUEL * 0.6)
		. += "The fuel tank sloshes, most of the way full."
	else if(fuel >= SCORCHER_MAX_FUEL * 0.3)
		. += "The fuel tank sloshes, about half full."
	else if(fuel >= SCORCHER_FUEL_PER_SPRAY)
		. += "The fuel tank sloshes faintly, nearly dry."
	else
		. += "The fuel tank is dry."

// A beaker, jerrycan or other open container of welding fuel used on the gun.
/obj/item/gun/ballistic/automatic/heater/scorcher/item_interaction(mob/living/user, obj/item/tool, list/modifiers)
	if(is_reagent_container(tool) && tool.is_drainable())
		draw_fuel(tool, user)
		return ITEM_INTERACT_SUCCESS
	return ..()

// The gun used on a fuel tank, or on a container sitting on a table.
/obj/item/gun/ballistic/automatic/heater/scorcher/interact_with_atom(atom/interacting_with, mob/living/user, list/modifiers)
	if(!ismob(interacting_with) && interacting_with.is_drainable())
		draw_fuel(interacting_with, user)
		return ITEM_INTERACT_SUCCESS
	return ..()

/obj/item/gun/ballistic/automatic/heater/scorcher/interact_with_atom_secondary(atom/interacting_with, mob/living/user, list/modifiers)
	if(user.combat_mode && isliving(interacting_with))
		return ITEM_INTERACT_SKIP_TO_ATTACK // Gun bash, as on any gun
	spray_fire(interacting_with, user)
	return ITEM_INTERACT_SUCCESS

/obj/item/gun/ballistic/automatic/heater/scorcher/ranged_interact_with_atom_secondary(atom/interacting_with, mob/living/user, list/modifiers)
	spray_fire(interacting_with, user)
	return ITEM_INTERACT_SUCCESS

/// Pours welding fuel, and only welding fuel, from source into the tank.
/obj/item/gun/ballistic/automatic/heater/scorcher/proc/draw_fuel(atom/source, mob/living/user)
	var/space = SCORCHER_MAX_FUEL - fuel
	if(space <= 0)
		balloon_alert(user, "tank is full")
		return
	var/available = source.reagents?.get_reagent_amount(/datum/reagent/fuel) || 0
	if(available <= 0)
		balloon_alert(user, "no fuel in it")
		return
	var/taken = source.reagents.remove_reagent(/datum/reagent/fuel, min(space, available))
	if(!taken)
		return
	fuel = min(fuel + taken, SCORCHER_MAX_FUEL)
	playsound(src, 'sound/effects/refill.ogg', 40, TRUE)
	balloon_alert(user, "tank refilled")

/// Sprays a plume of burning fuel at target.
/obj/item/gun/ballistic/automatic/heater/scorcher/proc/spray_fire(atom/target, mob/living/user)
	var/turf/start = get_turf(user)
	var/turf/target_turf = get_turf(target)
	if(!isturf(user.loc) || isnull(target_turf) || target_turf == start)
		return
	if(HAS_TRAIT(user, TRAIT_PACIFISM))
		balloon_alert(user, "you don't want to hurt anyone!")
		return
	if(!can_trigger_gun(user))
		return
	if(!COOLDOWN_FINISHED(src, spray_cooldown))
		return
	if(fuel < SCORCHER_FUEL_PER_SPRAY)
		balloon_alert(user, "it sputters")
		playsound(src, 'sound/items/weapons/gun/general/dry_fire.ogg', 30, TRUE)
		return
	fuel -= SCORCHER_FUEL_PER_SPRAY
	COOLDOWN_START(src, spray_cooldown, SCORCHER_SPRAY_COOLDOWN)
	user.changeNext_move(CLICK_CD_RANGE)
	var/obj/projectile/flame = new /obj/projectile/bullet/incendiary/fire/scorcher(start)
	flame.aim_projectile(target, user)
	flame.firer = user
	flame.fired_from = src
	playsound(src, 'sound/items/modsuit/flamethrower.ogg', 75, TRUE)
	log_combat(user, target, "sprayed fire at", src)
	INVOKE_ASYNC(flame, TYPE_PROC_REF(/obj/projectile, fire))

/// The Scorcher's plume: tg's flamethrower plume, a tile shorter.
/obj/projectile/bullet/incendiary/fire/scorcher
	range = 5

#undef SCORCHER_MAX_FUEL
#undef SCORCHER_FUEL_PER_SPRAY
#undef SCORCHER_SPRAY_COOLDOWN
