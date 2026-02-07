/**
 * Ship Key - Used to claim ownership of a ship
 *
 * For NPC ships: Dropped by NPC ship captains on death. Can be inserted into the
 * helm console to claim the ship for player use.
 *
 * For player ships: Given to the captain on spawn. Can be used to reclaim the ship
 * if it becomes abandoned.
 *
 * The key serves as the single source of truth for NPC pirate ship lifecycle.
 * When destroyed (for any reason), it notifies the spawner subsystem to
 * spawn a replacement pirate of the same tier (NPC ships only).
 */
/obj/item/ship_key
	name = "ship authorization key"
	desc = "A cryptographic key that grants command authorization for a vessel. Insert into a helm console to claim ownership."
	icon = 'icons/obj/fluff/puzzle_small.dmi'
	icon_state = "keycard"
	w_class = WEIGHT_CLASS_SMALL

	/// Weak reference to the ship this key belongs to
	var/datum/weakref/ship_ref

	/// Name of the ship (for display even if ship is destroyed)
	var/ship_name = "Unknown Vessel"

	/// The type path of the NPC ship (for spawner replacement logic)
	var/ship_type_path

	/// Why this key is being destroyed (set before qdel for proper signaling)
	var/destruction_reason = KEY_DESTROYED_UNKNOWN

	/// Whether we've already notified the spawner (prevents double-notification)
	var/spawner_notified = FALSE

	/// Whether this key is for an NPC ship (affects claiming and spawner notification)
	var/is_npc_key = FALSE

/obj/item/ship_key/Initialize(mapload, obj/structure/overmap/ship/target_ship)
	. = ..()
	if(target_ship)
		set_ship(target_ship)

/obj/item/ship_key/Destroy()
	// Send signal before destruction so bounties can react
	var/obj/structure/overmap/ship/npc/ship = ship_ref?.resolve()
	SEND_SIGNAL(src, COMSIG_SHIP_KEY_DESTROYED, ship, destruction_reason)

	// Notify spawner to spawn replacement (if not already done)
	notify_spawner_resolved()

	return ..()

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
	ship_type_path = target_ship.type
	name = "[target_ship.name] authorization key"

/// Returns the ship if it still exists
/obj/item/ship_key/proc/get_ship()
	return ship_ref?.resolve()

/// Checks if this key is valid for claiming
/obj/item/ship_key/proc/is_valid()
	var/obj/structure/overmap/ship/npc/ship = get_ship()
	if(!ship || QDELETED(ship))
		return FALSE
	// Disabled ships are always claimable
	if(ship.is_disabled)
		return TRUE
	if(!ship.ai_controller)
		return FALSE  // Already claimed
	return TRUE

/**
 * Marks this key for destruction with a specific reason.
 * Call this before qdel() to properly signal why the key is being destroyed.
 * @param reason One of KEY_DESTROYED_UNKNOWN, KEY_DESTROYED_CLAIMED, KEY_DESTROYED_BOUNTY
 */
/obj/item/ship_key/proc/mark_destruction_reason(reason)
	destruction_reason = reason

/**
 * Notifies the spawner subsystem that this pirate has been resolved.
 * Called automatically during Destroy(), but can be called manually for
 * edge cases (like abandonment where key may persist).
 *
 * Only notifies once per key to prevent duplicate spawns.
 * Does NOT notify if ship was already abandoned (already resolved via abandonment).
 */
/obj/item/ship_key/proc/notify_spawner_resolved()
	if(spawner_notified)
		return
	if(!ship_type_path)
		return

	// Check if ship was already resolved via abandonment
	var/obj/structure/overmap/ship/npc/ship = ship_ref?.resolve()
	if(ship?.abandoned)
		return  // Ship was already resolved when abandoned

	spawner_notified = TRUE
	// Pass the ship's zone so replacement spawns in same zone
	var/resolved_zone_type
	if(ship)
		var/turf/ship_turf = get_turf(ship)
		var/datum/overmap_zone/zone = SSovermap_zones.get_zone(ship_turf)
		resolved_zone_type = zone?.zone_type
	SSnpc_ships.on_pirate_resolved(ship_type_path, resolved_zone_type)
