/**
 * Ritual: Ossuary Rain: ship-scoped port of TG's Indoor Weather (code/modules/events/wizard/object_rain.dm).
 *
 * Bones fall out of the ceiling of one compartment, in drop pods, for about half a minute.
 *
 * The TG original picks a station department by area typepath out of a hardcoded
 * RAIN_TARGET_DEPARTMENTS list, snapshots every unblocked turf in it during setup(), and
 * pick_n_take()s from that cached list for the rest of the event. Neither half survives
 * here: ships have no department area types, and (the important one) a shuttle's turfs
 * are positional. The instant the ship docks, launches or moves, every cached turf ref
 * points at whatever now occupies that coordinate, which could be a planet surface, a
 * trader outpost's shop floor, or another crew's bridge. Dropping pods on those is exactly
 * the failure mode the port spec exists to prevent.
 *
 * Changed from the original:
 * - The target "region" is one of the ship's own areas, picked at setup. The AREA datum is
 *   what gets cached, never its turfs: shuttle areas travel with the ship, their turf sets
 *   do not.
 * - Landing turfs are resolved fresh on every single drop and re-checked with is_aboard()
 *   before the pod is spawned. A stale or off-ship turf simply skips that drop.
 * - Rain rate cut from 3/sec to 2/sec and the duration shortened, because a ship
 *   compartment is a handful of tiles rather than a station department.
 * - Reflavored from TG's four cosmetic variants (animals, food, cash, fish) to a single
 *   ossuary table. These are all real bone items already in the game, so the aftermath is
 *   a mess to sweep up rather than an unrecoverable state.
 * - What falls is registered with register_lich_leaving() (lich_loot.dm) and goes to dust
 *   when he dies. The table holds a skull helmet, bone armour and a bone axe, and a rite
 *   is pressure, it is not allowed to double as a supply drop. Anything the crew CRAFTS
 *   out of the bone sheets before then is theirs and survives; they did the work.
 * - The admin_setup listed-options datum is dropped, per the port spec: it exists to let
 *   an admin name a station department.
 */
/datum/round_event_control/voidcrew/lich/ossuary_rain
	name = "Ritual: Ossuary Rain"
	typepath = /datum/round_event/voidcrew/lich/ossuary_rain
	description = "Bones fall from the ceiling of one compartment aboard the target ship."
	max_occurrences = 2
	event_scope = EVENT_SCOPE_SHIP
	min_wizard_trigger_potency = 0
	max_wizard_trigger_potency = 3
	/// Two pods a tick for half a minute is a mess to sweep up in a compartment and a
	/// pile-driver in a hull that only has three tiles for the crew to stand on.
	min_ship_mass = SHIP_MASS_SMALL

/// Needs somewhere open aboard for a pod to land.
/datum/round_event_control/voidcrew/lich/ossuary_rain/is_valid_target(obj/structure/overmap/ship/ship)
	. = ..()
	if(!.)
		return FALSE
	return !isnull(ship.get_random_open_ship_turf())

/datum/round_event/voidcrew/lich/ossuary_rain
	announce_when = 1
	end_when = 14
	/// The ship area the rain falls in. An area, never a turf list, see the file header.
	var/area/rain_area
	/// Name of that area, kept for the announcement in case the area is gone by then.
	var/rain_area_name = "the lower decks"
	/// Most pods to drop per tick. TG uses 3 for a station department.
	var/max_things_per_tick = 2
	/// What falls. Weighted, all bone-flavored, all ordinary in-game items.
	var/static/list/ossuary_table = list(
		/obj/item/stack/sheet/bone = 40,
		/obj/item/food/meat/slab/human/mutant/skeleton = 25,
		/obj/item/stack/sheet/sinew = 10,
		/obj/item/knife/combat/bone = 8,
		/obj/item/clothing/head/helmet/skull = 5,
		/obj/item/clothing/gloves/bracer = 4,
		/obj/item/clothing/accessory/talisman = 4,
		/obj/item/spear/bonespear = 3,
		/obj/item/clothing/suit/armor/bone = 2,
		/obj/item/fireaxe/boneaxe = 1,
	)

/datum/round_event/voidcrew/lich/ossuary_rain/setup()
	if(!target_valid())
		kill()
		return
	rain_area = target_ship.get_random_ship_area()
	if(!rain_area)
		kill()
		return
	rain_area_name = rain_area.name

/datum/round_event/voidcrew/lich/ossuary_rain/announce(fake)
	lich_announce_ship(
		"There is a great deal of me that is no longer needed. I am shedding it into \
		[rain_area_name]. Do not mistake this for generosity. It is housekeeping, and you \
		are the bin.",
		"Ossuary Rain",
	)

/datum/round_event/voidcrew/lich/ossuary_rain/tick()
	if(!target_valid())
		return
	for(var/i in 1 to rand(0, max_things_per_tick))
		addtimer(CALLBACK(src, PROC_REF(drop_bone)), rand(0, 1 SECONDS))

/**
 * Drops one pod. Every turf is resolved at the moment of the drop and validated against
 * the ship, because this runs from a timer and the ship may have moved since tick().
 */
/datum/round_event/voidcrew/lich/ossuary_rain/proc/drop_bone()
	if(!target_valid())
		return
	var/turf/landing_turf = pick_rain_turf()
	if(!landing_turf)
		return
	var/bone_path = pick_weight(ossuary_table)
	if(!bone_path)
		return
	var/obj/structure/closet/supplypod/pod = podspawn(list(
		"target" = landing_turf,
		"style" = /datum/pod_style/seethrough,
		"spawn" = bone_path,
		"delays" = list(POD_TRANSIT = 0, POD_FALLING = (3 SECONDS), POD_OPENING = 0, POD_LEAVING = 0),
		"effectStealth" = TRUE,
		"effectQuiet" = TRUE,
	))
	// He is shedding this, not gifting it. The table holds a skull helmet, bone armour
	// and a bone axe, and none of it is allowed to outlive him. podspawn() hands back the
	// pod with the item already inside, which is the only moment there is a ref to catch.
	for(var/obj/item/shed_bone in pod)
		register_lich_leaving(shed_bone)

/**
 * A live, unblocked open turf inside the rain area, or null.
 *
 * Rebuilt from the area's current contents on every call rather than cached, that is the
 * whole point. Falls back to any open turf aboard if the chosen compartment has been
 * flooded, sealed or blown open since setup.
 */
/datum/round_event/voidcrew/lich/ossuary_rain/proc/pick_rain_turf()
	if(QDELETED(rain_area))
		return target_ship.get_random_open_ship_turf()
	var/list/candidates = list()
	for(var/turf/open/floor/candidate in rain_area)
		if(candidate.is_blocked_turf(exclude_mobs = TRUE))
			continue
		if(!target_ship.is_aboard(candidate))
			continue // The area outlived the ship's claim on this coordinate.
		candidates += candidate
	if(!length(candidates))
		return target_ship.get_random_open_ship_turf()
	return pick(candidates)
