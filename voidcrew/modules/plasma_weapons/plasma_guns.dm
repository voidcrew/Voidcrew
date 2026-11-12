// Package: P2 guns and flask. The Cinder, Furnace and Old Furnace: loading, unloading and feeding,
// chamber access, spawn fills, EMP, sprite state, and the shot hooks into heat, sound and pinch.
//
// The chamber (`cell`) holds the seated flask's plasma while it is in the gun; the flask itself reads
// empty until it comes out, when the chamber is written back into it. So the plasma a gun and its flask
// hold together is always chamber_mol() + flask.stored, and only feeding raises it.

/obj/item/gun/energy/plasma_weapon
	automatic_charge_overlays = FALSE
	vary_fire_sound = FALSE
	// A turret or emitter fires a gun's bolts off the power grid; plasma bolts only come from plasma
	gun_flags = TURRET_INCOMPATIBLE
	/// do_after to seat a flask
	var/flask_load_delay = PLASMA_LOAD_DELAY_PISTOL
	/// Spawn with a flask seated: full, or (spawn_fill_random) 0-50% full. Never set FALSE on a sold gun.
	var/spawn_with_flask = TRUE
	/// Loot guns spawn with a part-filled flask
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

/// A Cinder found in the field: its flask is anywhere from empty to half full
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
	flask_load_delay = PLASMA_LOAD_DELAY_RIFLE

/// A Furnace found in the field: its flask is anywhere from empty to half full
/obj/item/gun/energy/plasma_weapon/rifle/loot
	spawn_fill_random = TRUE

/obj/item/gun/energy/plasma_weapon/rifle/old_furnace
	spread = 0

/obj/item/gun/energy/plasma_weapon/Initialize(mapload)
	. = ..()
	// Keep the sealed chamber out of contents; see plasma_chamber.dm. Exited() keeps `cell` set.
	cell?.moveToNullspace()
	if(spawn_with_flask)
		var/obj/item/plasma_flask/spawned = new(src)
		spawned.stored = spawn_fill_random ? rand(0, round(PLASMA_FLASK_CAPACITY / 2)) : PLASMA_FLASK_CAPACITY
		seat_flask(spawned)

/obj/item/gun/energy/plasma_weapon/Destroy()
	// Drop the flask with the chamber's plasma written back (Exited does the write-back)
	if(flask)
		var/atom/drop_at = drop_location()
		if(drop_at)
			flask.forceMove(drop_at)
		else
			QDEL_NULL(flask)
	return ..()

/obj/item/gun/energy/plasma_weapon/Exited(atom/movable/gone, direction)
	if(gone == cell)
		// The chamber leaves contents on purpose in Initialize and never leaves the gun's `cell`
		var/obj/item/stock_parts/power_store/kept = cell
		. = ..()
		cell = kept
		return
	. = ..()
	if(gone == flask)
		flask = null
		var/obj/item/plasma_flask/left = gone
		if(cell)
			left.stored = min(left.stored + cell.charge, PLASMA_FLASK_CAPACITY)
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

/// Puts `new_flask` (already inside the gun) in the seat and moves its plasma into the chamber
/obj/item/gun/energy/plasma_weapon/proc/seat_flask(obj/item/plasma_flask/new_flask)
	flask = new_flask
	if(cell)
		cell.charge = clamp(new_flask.stored, 0, cell.maxcharge)
		new_flask.stored = 0
	chamber_changed()

/// Seats `flask` and moves its plasma into the chamber. TRUE on success.
/obj/item/gun/energy/plasma_weapon/proc/load_flask(obj/item/plasma_flask/new_flask, mob/user)
	if(QDELETED(new_flask) || new_flask == flask || !cell)
		return FALSE
	if(user)
		if(!do_after(user, flask_load_delay, target = src))
			return FALSE
		if(QDELETED(new_flask) || new_flask.loc != user)
			return FALSE
	if(flask)
		unload_flask(user)
	if(user)
		if(!user.transferItemToLoc(new_flask, src))
			return FALSE
	else
		new_flask.forceMove(src)
	seat_flask(new_flask)
	playsound(src, 'voidcrew/modules/plasma_weapons/sound/flask_load.ogg', 50, TRUE)
	return TRUE

/// Writes the chamber back into the seated flask and hands it to `user`. Returns the flask.
/obj/item/gun/energy/plasma_weapon/proc/unload_flask(mob/user)
	if(!flask)
		return null
	var/obj/item/plasma_flask/out = flask
	// Exited() writes the chamber back as it leaves
	if(user)
		user.put_in_hands(out)
	if(out.loc == src)
		out.forceMove(drop_location())
	playsound(src, 'voidcrew/modules/plasma_weapons/sound/flask_unload.ogg', 50, TRUE)
	return out

/// Feeds a plasma sheet or ore stack into the chamber, one unit per do_after. Returns mol added.
/// Needs a seated flask. A unit goes in only when there is room for all of it. No user, no delay.
/obj/item/gun/energy/plasma_weapon/proc/feed_plasma(obj/item/stack/fuel, mob/user)
	var/per_unit = plasma_fuel_mol_per_unit(fuel)
	if(!per_unit || !cell)
		return 0
	if(!flask)
		if(user)
			balloon_alert(user, "no flask")
		return 0
	var/added = 0
	while(!QDELETED(fuel) && fuel.get_amount() > 0)
		if(!flask || cell.charge + per_unit > cell.maxcharge)
			if(!added && user && flask)
				balloon_alert(user, "it's full")
			break
		if(user && !do_after(user, PLASMA_FEED_DELAY, target = src))
			break
		if(QDELETED(fuel) || !flask || cell.charge + per_unit > cell.maxcharge || !fuel.use(1))
			break
		cell.charge += per_unit
		added += per_unit
		playsound(src, PLASMA_SOUND_FEED_SHEET, 20, TRUE)
	if(added)
		playsound(src, PLASMA_SOUND_FEED_CLICK, 30, TRUE)
		chamber_changed()
	return added

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
	if(istype(tool, /obj/item/plasma_flask))
		return load_flask(tool, user) ? ITEM_INTERACT_SUCCESS : ITEM_INTERACT_BLOCKING
	if(istype(tool, /obj/item/stack/sheet/mineral/plasma) || istype(tool, /obj/item/stack/ore/plasma))
		feed_plasma(tool, user)
		return ITEM_INTERACT_SUCCESS
	return ..()

/obj/item/gun/energy/plasma_weapon/click_alt(mob/user)
	if(!user.is_holding(src))
		return CLICK_ACTION_BLOCKING
	return unload_flask(user) ? CLICK_ACTION_SUCCESS : CLICK_ACTION_BLOCKING
