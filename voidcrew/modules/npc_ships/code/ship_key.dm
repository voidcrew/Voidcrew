/**
 * Ship Key - Used to claim ownership of an NPC ship
 *
 * Dropped by NPC ship captains on death. Can be inserted into the
 * helm console to claim the ship for player use.
 */
/obj/item/ship_key
	name = "ship authorization key"
	desc = "A cryptographic key that grants command authorization for a vessel. Insert into a helm console to claim ownership."
	icon = 'icons/obj/fluff/puzzle_small.dmi'
	icon_state = "keycard"
	w_class = WEIGHT_CLASS_SMALL

	/// Weak reference to the NPC ship this key belongs to
	var/datum/weakref/ship_ref

	/// Name of the ship (for display even if ship is destroyed)
	var/ship_name = "Unknown Vessel"

/obj/item/ship_key/Initialize(mapload, obj/structure/overmap/ship/npc/target_ship)
	. = ..()
	if(target_ship)
		set_ship(target_ship)

/obj/item/ship_key/examine(mob/user)
	. = ..()
	. += span_notice("This key grants authorization for: [ship_name]")
	var/obj/structure/overmap/ship/npc/ship = ship_ref?.resolve()
	if(!ship)
		. += span_warning("The associated vessel no longer exists.")
	else if(!ship.ai_controller)
		. += span_warning("This vessel has already been claimed.")
	else
		. += span_notice("Insert into the ship's helm console to claim ownership.")

/// Sets the ship this key belongs to
/obj/item/ship_key/proc/set_ship(obj/structure/overmap/ship/npc/target_ship)
	if(!target_ship)
		return
	ship_ref = WEAKREF(target_ship)
	ship_name = target_ship.name
	name = "[target_ship.name] authorization key"

/// Returns the ship if it still exists
/obj/item/ship_key/proc/get_ship()
	return ship_ref?.resolve()

/// Checks if this key is valid for claiming
/obj/item/ship_key/proc/is_valid()
	var/obj/structure/overmap/ship/npc/ship = get_ship()
	if(!ship || QDELETED(ship))
		return FALSE
	if(!ship.ai_controller)
		return FALSE  // Already claimed
	return TRUE
