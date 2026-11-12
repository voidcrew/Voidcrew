// Package: P2 guns and cartridges. The Cinder, Furnace and Old Furnace: loading and unloading,
// chamber access, spawn fills, EMP, sprite state, and the shot hooks into heat, sound and pinch.
//
// The chamber (`cell`) holds the seated cartridge's plasma while it is in the gun; the cartridge itself
// reads spent until it comes out, when the chamber is written back into it. So the plasma a gun and its
// cartridge hold together is always chamber_mol() + cartridge.stored, and nothing raises it.

/obj/item/gun/energy/plasma_weapon
	automatic_charge_overlays = FALSE
	vary_fire_sound = FALSE
	// A turret or emitter fires a gun's bolts off the power grid; plasma bolts only come from plasma
	gun_flags = TURRET_INCOMPATIBLE
	/// do_after to seat a cartridge
	var/cartridge_load_delay = PLASMA_LOAD_DELAY_PISTOL
	/// Spawn with a cartridge seated: full, or (spawn_fill_random) one shot to half full. Never set FALSE on a sold gun.
	var/spawn_with_cartridge = TRUE
	/// Loot guns spawn with a part-used cartridge
	var/spawn_fill_random = FALSE

/obj/item/gun/energy/plasma_weapon/pistol
	fire_sound = 'voidcrew/modules/plasma_weapons/sound/cinder_fire.ogg'
	far_fire_sound = 'voidcrew/modules/plasma_weapons/sound/cinder_far.ogg'
	fire_delay = 5
	spread = 5
	recoil = 0.5
	force = 10
	weapon_weight = WEAPON_LIGHT
	w_class = WEIGHT_CLASS_NORMAL
	slot_flags = ITEM_SLOT_BELT

/// A Cinder found in the field: its cartridge holds a shot or more, up to half full
/obj/item/gun/energy/plasma_weapon/pistol/loot
	spawn_fill_random = TRUE

/obj/item/gun/energy/plasma_weapon/rifle
	fire_sound = 'voidcrew/modules/plasma_weapons/sound/furnace_fire.ogg'
	far_fire_sound = 'voidcrew/modules/plasma_weapons/sound/furnace_far.ogg'
	fire_delay = 7
	spread = 2
	recoil = 0.75
	force = 15
	weapon_weight = WEAPON_HEAVY
	w_class = WEIGHT_CLASS_BULKY
	slot_flags = ITEM_SLOT_BACK
	cartridge_load_delay = PLASMA_LOAD_DELAY_RIFLE

/// A Furnace found in the field: its cartridge holds a shot or more, up to half full
/obj/item/gun/energy/plasma_weapon/rifle/loot
	spawn_fill_random = TRUE

/obj/item/gun/energy/plasma_weapon/rifle/old_furnace
	spread = 0

/obj/item/gun/energy/plasma_weapon/Initialize(mapload)
	. = ..()
	// Keep the sealed chamber out of contents; see plasma_chamber.dm. Exited() keeps `cell` set.
	cell?.moveToNullspace()
	if(spawn_with_cartridge)
		var/obj/item/plasma_cartridge/spawned = new(src)
		if(spawn_fill_random)
			spawned.stored = loot_fill()
		seat_cartridge(spawned)

/// A loot cartridge's plasma: whole shots for this gun, at least one, up to half a cartridge
/obj/item/gun/energy/plasma_weapon/proc/loot_fill()
	var/obj/item/ammo_casing/energy/shot = ammo_type[select]
	var/max_shots = max(1, round(PLASMA_CARTRIDGE_CAPACITY / 2 / shot.e_cost))
	return rand(1, max_shots) * shot.e_cost

/obj/item/gun/energy/plasma_weapon/Destroy()
	// Drop the cartridge with the chamber's plasma written back (Exited does the write-back)
	if(cartridge)
		var/atom/drop_at = drop_location()
		if(drop_at)
			cartridge.forceMove(drop_at)
		else
			QDEL_NULL(cartridge)
	return ..()

/obj/item/gun/energy/plasma_weapon/Exited(atom/movable/gone, direction)
	if(gone == cell)
		// The chamber leaves contents on purpose in Initialize and never leaves the gun's `cell`
		var/obj/item/stock_parts/power_store/kept = cell
		. = ..()
		cell = kept
		return
	. = ..()
	if(gone == cartridge)
		cartridge = null
		var/obj/item/plasma_cartridge/left = gone
		if(cell)
			left.stored = min(left.stored + cell.charge, PLASMA_CARTRIDGE_CAPACITY)
			cell.charge = 0
		left.update_appearance()
		chamber_changed()

/// The energy gun's own pick of fire sound and delay comes from the casing; these guns set their own
/obj/item/gun/energy/plasma_weapon/update_ammo_types()
	. = ..()
	if(initial(fire_sound))
		fire_sound = initial(fire_sound)
	fire_delay = initial(fire_delay)

/// Re-chambers after the plasma in the chamber changed outside of firing
/obj/item/gun/energy/plasma_weapon/proc/chamber_changed()
	chambered = null
	recharge_newshot(TRUE)
	update_appearance()

/// Puts `new_cartridge` (already inside the gun) in the seat and moves its plasma into the chamber
/obj/item/gun/energy/plasma_weapon/proc/seat_cartridge(obj/item/plasma_cartridge/new_cartridge)
	cartridge = new_cartridge
	if(cell)
		cell.charge = clamp(new_cartridge.stored, 0, cell.maxcharge)
		new_cartridge.stored = 0
	new_cartridge.update_appearance()
	chamber_changed()

/// Seats `new_cartridge` and moves its plasma into the chamber. TRUE on success.
/// A seated cartridge comes out first: to `user`'s hand, or at their feet if it is spent.
/obj/item/gun/energy/plasma_weapon/proc/load_cartridge(obj/item/plasma_cartridge/new_cartridge, mob/user)
	if(QDELETED(new_cartridge) || new_cartridge == cartridge || !cell)
		return FALSE
	if(new_cartridge.stored <= 0)
		if(user)
			balloon_alert(user, "it's spent")
		return FALSE
	if(user)
		if(!do_after(user, cartridge_load_delay, target = src))
			return FALSE
		if(QDELETED(new_cartridge) || new_cartridge.loc != user)
			return FALSE
	if(cartridge)
		unload_cartridge(user, drop_if_spent = TRUE)
	if(user)
		if(!user.transferItemToLoc(new_cartridge, src))
			return FALSE
	else
		new_cartridge.forceMove(src)
	seat_cartridge(new_cartridge)
	playsound(src, 'voidcrew/modules/plasma_weapons/sound/flask_load.ogg', 50, TRUE)
	return TRUE

/// Writes the chamber back into the seated cartridge and hands it to `user`. Returns the cartridge.
/// With drop_if_spent, a cartridge with nothing left falls at the gun's feet instead.
/obj/item/gun/energy/plasma_weapon/proc/unload_cartridge(mob/user, drop_if_spent = FALSE)
	if(!cartridge)
		return null
	var/obj/item/plasma_cartridge/out = cartridge
	var/spent = chamber_mol() <= 0
	// Exited() writes the chamber back as it leaves
	if(user && !(drop_if_spent && spent))
		user.put_in_hands(out)
	if(out.loc == src)
		out.forceMove(drop_location())
	playsound(src, 'voidcrew/modules/plasma_weapons/sound/flask_unload.ogg', 50, TRUE)
	return out

/// Mol of plasma in the chamber
/obj/item/gun/energy/plasma_weapon/proc/chamber_mol()
	return cell?.charge || 0

/// Removes up to `amount` mol from the chamber. Returns what it took.
/obj/item/gun/energy/plasma_weapon/proc/take_mol(amount)
	if(!cell || amount <= 0)
		return 0
	var/took = min(amount, cell.charge)
	if(took <= 0)
		return 0
	cell.charge -= took
	chamber_changed()
	return took

/// Plasma isn't charge: skip the energy gun's drain and keep what the chamber holds
/obj/item/gun/energy/plasma_weapon/emp_act(severity)
	var/held = cell?.charge
	. = ..()
	if(cell && !isnull(held))
		cell.charge = held
		chamber_changed()

/// Powerups and the like refill an energy gun's cell outright; this one only takes plasma
/obj/item/gun/energy/plasma_weapon/instant_recharge()
	SIGNAL_HANDLER
	return

/obj/item/gun/energy/plasma_weapon/update_icon_state()
	var/obj/item/ammo_casing/energy/shot = length(ammo_type) ? ammo_type[select] : null
	var/loaded = cell && istype(shot) && cell.charge >= shot.e_cost
	icon_state = "[initial(icon_state)][loaded ? "" : "_empty"]"
	return ..()

/obj/item/gun/energy/plasma_weapon/shoot_live_shot(mob/living/user, pointblank = FALSE, atom/pbtarget = null, message = TRUE)
	. = ..()
	if(uses_heat)
		add_heat(heat_per_shot)
	plasma_weapons_far_sound(src, far_fire_sound)
	// tg hands the shot's target in as pbtarget on every shot, point blank or not (process_fire, process_burst)
	plasma_pinch(user, pbtarget)

/obj/item/gun/energy/plasma_weapon/can_shoot()
	if(!can_fire_heat())
		return FALSE
	return ..()

/obj/item/gun/energy/plasma_weapon/item_interaction(mob/living/user, obj/item/tool, list/modifiers)
	if(istype(tool, /obj/item/plasma_cartridge))
		return load_cartridge(tool, user) ? ITEM_INTERACT_SUCCESS : ITEM_INTERACT_BLOCKING
	return ..()

/obj/item/gun/energy/plasma_weapon/click_alt(mob/user)
	if(!user.is_holding(src))
		return CLICK_ACTION_BLOCKING
	return unload_cartridge(user) ? CLICK_ACTION_SUCCESS : CLICK_ACTION_BLOCKING
