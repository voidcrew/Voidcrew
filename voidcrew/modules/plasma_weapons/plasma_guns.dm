// Package: P2 guns and flask. The Cinder, Furnace and Old Furnace: loading, unloading and feeding,
// chamber access, spawn fills, EMP, sprite state, and the shot hooks into heat, sound and pinch.

/// Seats `flask` and moves its plasma into the chamber. TRUE on success.
/obj/item/gun/energy/plasma_weapon/proc/load_flask(obj/item/plasma_flask/flask, mob/user)
	return FALSE

/// Writes the chamber back into the seated flask and hands it to `user`. Returns the flask.
/obj/item/gun/energy/plasma_weapon/proc/unload_flask(mob/user)
	return null

/// Feeds a plasma sheet or ore stack into the chamber, one unit per do_after. Returns mol added.
/obj/item/gun/energy/plasma_weapon/proc/feed_plasma(obj/item/stack/fuel, mob/user)
	return 0

/// Mol of plasma in the chamber
/obj/item/gun/energy/plasma_weapon/proc/chamber_mol()
	return cell?.charge || 0

/// Removes up to `amount` mol from the chamber. Returns what it took.
/obj/item/gun/energy/plasma_weapon/proc/take_mol(amount)
	return 0

/obj/item/gun/energy/plasma_weapon/shoot_live_shot(mob/living/user, pointblank = FALSE, atom/pbtarget = null, message = TRUE)
	. = ..()
	if(uses_heat)
		add_heat(heat_per_shot)
	plasma_weapons_far_sound(src, far_fire_sound)
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
	return unload_flask(user) ? CLICK_ACTION_SUCCESS : CLICK_ACTION_BLOCKING
