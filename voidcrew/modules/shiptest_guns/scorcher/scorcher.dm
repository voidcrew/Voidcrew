// The Heater PDW and the Scorcher, a Heater with a flamethrower bolted under it.
// Ported from Shiptest (shiptest-ss13/Shiptest, frontier_import/ballistics.dm and
// gun_attachments/flamethrower.dm). Art credits are in attribution.txt.
// The flamethrower is part of the gun: holding right mouse sprays tg's flamethrower plume
// (the same projectile as the MOD flamethrower module), one puff per SSfastprocess tick
// (0.2 s) toward the cursor, and burns welding fuel from a small internal tank, refilled
// from any container or tank holding welding fuel. Left mouse stays the bullet full-auto
// (/datum/component/automatic_fire ignores right clicks).

/// Fuel the Scorcher's tank holds, in units of welding fuel.
#define SCORCHER_MAX_FUEL 40
/// Fuel one puff of the spray burns.
#define SCORCHER_FUEL_PER_SPRAY 1
/// While the button is held, the spray sound plays once every this many puffs.
#define SCORCHER_SOUND_EVERY 4

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
	/// The mob holding the gun in a hand, whose right mouse button we watch. Cleared on drop and Destroy.
	var/mob/living/spray_holder
	/// spray_holder's client while it has one. Cleared on logout, drop and Destroy.
	var/client/spray_client
	/// TRUE while the flamethrower is spraying.
	var/spraying = FALSE
	/// What the spray is aimed at.
	var/atom/spray_target
	/// The turf spray_target was on when aimed, so a moving target doesn't drag the aim.
	var/turf/spray_target_turf
	/// Puffs since the spray started, for the sound cadence.
	var/spray_puffs = 0

/obj/item/gun/ballistic/automatic/heater/scorcher/Destroy()
	unwatch_holder()
	return ..()

/obj/item/gun/ballistic/automatic/heater/scorcher/equipped(mob/user, slot, initial)
	. = ..()
	if((slot & ITEM_SLOT_HANDS) && isliving(user))
		watch_holder(user)
	else
		unwatch_holder()

/obj/item/gun/ballistic/automatic/heater/scorcher/dropped(mob/user, silent)
	unwatch_holder()
	return ..()

// One trigger at a time: no bullets while the flamethrower is spraying.
/obj/item/gun/ballistic/automatic/heater/scorcher/process_fire(atom/target, mob/living/user, message = TRUE, params = null, zone_override = "", bonus_spread = 0)
	if(spraying)
		return FALSE
	return ..()

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

// A player's right click is normally taken by the held spray (on_spray_mouse_down), so these
// only run for clicks it lets through and for callers without a mouse: one puff each.
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

/// Starts watching user's right mouse button while the gun is in one of their hands.
/obj/item/gun/ballistic/automatic/heater/scorcher/proc/watch_holder(mob/living/user)
	if(spray_holder == user)
		return
	unwatch_holder()
	spray_holder = user
	RegisterSignal(user, COMSIG_MOB_LOGIN, PROC_REF(on_holder_login))
	RegisterSignal(user, COMSIG_MOB_LOGOUT, PROC_REF(on_holder_logout))
	RegisterSignal(user, COMSIG_QDELETING, PROC_REF(unwatch_holder))
	if(user.client)
		watch_client(user.client)

/// Stops the spray and drops every signal and reference to the holder and their client.
/obj/item/gun/ballistic/automatic/heater/scorcher/proc/unwatch_holder(datum/source)
	SIGNAL_HANDLER
	unwatch_client()
	if(spray_holder)
		UnregisterSignal(spray_holder, list(COMSIG_MOB_LOGIN, COMSIG_MOB_LOGOUT, COMSIG_QDELETING, COMSIG_MOB_SWAP_HANDS))
	spray_holder = null

/obj/item/gun/ballistic/automatic/heater/scorcher/proc/watch_client(client/user_client)
	if(spray_client == user_client)
		return
	unwatch_client()
	spray_client = user_client
	RegisterSignal(user_client, COMSIG_CLIENT_MOUSEDOWN, PROC_REF(on_spray_mouse_down))

/obj/item/gun/ballistic/automatic/heater/scorcher/proc/unwatch_client()
	stop_spraying()
	if(spray_client && !QDELETED(spray_client))
		UnregisterSignal(spray_client, list(COMSIG_CLIENT_MOUSEDOWN, COMSIG_CLIENT_MOUSEUP, COMSIG_CLIENT_MOUSEDRAG))
	spray_client = null

/obj/item/gun/ballistic/automatic/heater/scorcher/proc/on_holder_login(mob/source)
	SIGNAL_HANDLER
	if(source.client)
		watch_client(source.client)

/obj/item/gun/ballistic/automatic/heater/scorcher/proc/on_holder_logout(mob/source)
	SIGNAL_HANDLER
	unwatch_client()

/// Right mouse pressed: start spraying at what is under the cursor.
/obj/item/gun/ballistic/automatic/heater/scorcher/proc/on_spray_mouse_down(client/source, atom/target, turf/location, control, params)
	SIGNAL_HANDLER
	if(!isatom(target))
		return
	var/list/modifiers = params2list(params)
	if(!LAZYACCESS(modifiers, RIGHT_CLICK))
		return
	if(LAZYACCESS(modifiers, SHIFT_CLICK) || LAZYACCESS(modifiers, CTRL_CLICK) || LAZYACCESS(modifiers, ALT_CLICK) || LAZYACCESS(modifiers, MIDDLE_CLICK))
		return
	var/mob/living/user = spray_holder
	if(QDELETED(user) || source.mob != user || user.get_active_held_item() != src)
		return
	if(user.throw_mode || !isturf(user.loc)) // In a locker or a mech, right click does what it normally does.
		return
	if(isnull(location) || istype(target, /atom/movable/screen))
		if(target.plane != CLICKCATCHER_PLANE)
			return // A HUD or inventory click.
		target = parse_caught_click_modifiers(modifiers, get_turf(source.eye), source)
		if(!target)
			return
	else if(!isturf(target) && !isturf(target.loc))
		return // Something inside a bag or a container.
	if(user.combat_mode && isliving(target) && user.Adjacent(target))
		return // Gun bash, through the normal click.
	// The click itself would fire another puff through interact_with_atom_secondary.
	source.click_intercept_time = world.time
	RegisterSignal(source, COMSIG_CLIENT_MOUSEUP, PROC_REF(on_spray_mouse_up), override = TRUE)
	start_spraying(target)

/obj/item/gun/ballistic/automatic/heater/scorcher/proc/on_spray_mouse_up(client/source, atom/object, turf/location, control, params)
	SIGNAL_HANDLER
	var/list/modifiers = params2list(params)
	if(!LAZYACCESS(modifiers, RIGHT_CLICK))
		return
	UnregisterSignal(source, COMSIG_CLIENT_MOUSEUP)
	stop_spraying()
	return COMPONENT_CLIENT_MOUSEUP_INTERCEPT // Releasing the button is the click; don't let it puff again.

/// Follows the cursor while the button is held.
/obj/item/gun/ballistic/automatic/heater/scorcher/proc/on_spray_mouse_drag(client/source, atom/src_object, atom/over_object, turf/src_location, turf/over_location, src_control, over_control, params)
	SIGNAL_HANDLER
	if(isnull(over_location)) // Over a screen object or deep darkness.
		var/list/modifiers = params2list(params)
		var/turf/new_target = parse_caught_click_modifiers(modifiers, get_turf(source.eye), source)
		if(new_target)
			spray_target = new_target
			spray_target_turf = new_target
		return
	spray_target = over_object
	spray_target_turf = get_turf(over_object)

/// Starts the held spray at target. The first puff goes off at once.
/obj/item/gun/ballistic/automatic/heater/scorcher/proc/start_spraying(atom/target)
	stop_spraying()
	var/mob/living/user = spray_holder
	if(QDELETED(user) || QDELETED(target))
		return
	spraying = TRUE
	spray_puffs = 0
	spray_target = target
	spray_target_turf = get_turf(target)
	RegisterSignal(user, COMSIG_MOB_SWAP_HANDS, PROC_REF(stop_spraying))
	if(spray_client)
		RegisterSignal(spray_client, COMSIG_CLIENT_MOUSEDRAG, PROC_REF(on_spray_mouse_drag))
	if(!spray_puff())
		stop_spraying()
		return
	log_combat(user, target, "started spraying fire at", src)
	START_PROCESSING(SSfastprocess, src)

/obj/item/gun/ballistic/automatic/heater/scorcher/proc/stop_spraying(datum/source)
	SIGNAL_HANDLER
	if(!spraying)
		return
	spraying = FALSE
	STOP_PROCESSING(SSfastprocess, src)
	if(spray_holder)
		UnregisterSignal(spray_holder, COMSIG_MOB_SWAP_HANDS)
	if(spray_client && !QDELETED(spray_client))
		UnregisterSignal(spray_client, COMSIG_CLIENT_MOUSEDRAG)
	spray_target = null
	spray_target_turf = null

/obj/item/gun/ballistic/automatic/heater/scorcher/process(seconds_per_tick)
	if(!spraying)
		return PROCESS_KILL
	if(!spray_puff())
		stop_spraying()

/// One puff of the held spray. Returns FALSE when the spray should stop.
/obj/item/gun/ballistic/automatic/heater/scorcher/proc/spray_puff()
	var/mob/living/user = spray_holder
	if(QDELETED(user) || user.get_active_held_item() != src || user.incapacitated)
		return FALSE
	if(QDELETED(spray_target) || get_turf(spray_target) != spray_target_turf)
		spray_target = spray_target_turf // Keep spraying the tile until the cursor moves.
	var/atom/aim = spray_target
	if(isnull(aim))
		return FALSE
	if(get_turf(aim) == get_turf(user))
		aim = get_step(user, user.dir) // Cursor on our own tile: spray the way we face.
		if(isnull(aim))
			return FALSE
	else if(!CAN_THEY_SEE(aim, user))
		return FALSE
	user.face_atom(aim)
	return spray_fire(aim, user, held = TRUE)

/// Sprays a puff of burning fuel at target. Returns TRUE if it fired. held is TRUE for the held spray's puffs.
/obj/item/gun/ballistic/automatic/heater/scorcher/proc/spray_fire(atom/target, mob/living/user, held = FALSE)
	var/turf/start = get_turf(user)
	var/turf/target_turf = get_turf(target)
	if(!isturf(user.loc) || isnull(target_turf) || target_turf == start)
		return FALSE
	if(HAS_TRAIT(user, TRAIT_PACIFISM))
		balloon_alert(user, "you don't want to hurt anyone!")
		return FALSE
	if(!can_trigger_gun(user))
		return FALSE
	if(fuel < SCORCHER_FUEL_PER_SPRAY)
		balloon_alert(user, "it sputters")
		playsound(src, 'sound/items/weapons/gun/general/dry_fire.ogg', 30, TRUE)
		return FALSE
	fuel -= SCORCHER_FUEL_PER_SPRAY
	var/obj/projectile/flame = new /obj/projectile/bullet/incendiary/fire/scorcher(start)
	flame.aim_projectile(target, user)
	flame.firer = user
	flame.fired_from = src
	if(held)
		if(spray_puffs++ % SCORCHER_SOUND_EVERY == 0)
			playsound(src, 'sound/items/modsuit/flamethrower.ogg', 60, TRUE)
	else
		user.changeNext_move(CLICK_CD_RANGE)
		playsound(src, 'sound/items/modsuit/flamethrower.ogg', 60, TRUE)
		log_combat(user, target, "sprayed fire at", src)
	INVOKE_ASYNC(flame, TYPE_PROC_REF(/obj/projectile, fire))
	return TRUE

/// The Scorcher's plume: tg's flamethrower plume, a tile shorter.
/obj/projectile/bullet/incendiary/fire/scorcher
	range = 5

#undef SCORCHER_MAX_FUEL
#undef SCORCHER_FUEL_PER_SPRAY
#undef SCORCHER_SOUND_EVERY
