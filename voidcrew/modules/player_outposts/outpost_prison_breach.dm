/**
 * # Prison breaches: emergency air
 *
 * Prisoners breathe like anyone (they are real human bodies): a breach, a fire or a plasma leak in the
 * cell block suffocates, freezes and burns them the way it does the crew. Owner ruling Q3: the cell
 * block has emergency lockers of breath masks and air tanks, and a prisoner on bad air who isn't busy
 * making trouble goes and gets one, puts the mask on, and breathes from the tank (the human NPC base
 * opens a worn tank while the air is bad). The wing gets one locker per PRISON_EMERGENCY_LOCKER_TILES
 * floor tiles of its cell block when the corrections service lays it out, against a yard wall.
 *
 * Nothing here heals or shields anyone: a prisoner who can't reach a locker, or finds it emptied,
 * suffocates.
 */

/// Floor tiles of cell block per emergency locker
#define PRISON_EMERGENCY_LOCKER_TILES 60
/// How often a prisoner on bad air may try again for a locker after failing to get to one
#define PRISON_EMERGENCY_RETRY (15 SECONDS)

/// The cell block's emergency locker: breath masks and air tanks, the same every time
/obj/structure/closet/emcloset/outpost_prison
	name = "emergency locker"
	desc = "Breath masks and air tanks for the cell block, for when the air goes bad."
	anchored = TRUE

/obj/structure/closet/emcloset/outpost_prison/Initialize(mapload)
	. = ..()
	AddElement(/datum/element/outpost_property)

// Stocked when it is placed, not on first opening (tg's closets fill lazily), so a prisoner can tell from
// the yard which locker still has air in it (emergency_locker_for()).
/obj/structure/closet/emcloset/outpost_prison/populate_contents_immediate()
	. = ..()
	for(var/i in 1 to 4)
		new /obj/item/clothing/mask/breath(src)
		new /obj/item/tank/internals/emergency_oxygen(src)

/obj/structure/closet/emcloset/outpost_prison/PopulateContents()
	return

/datum/outpost_prison
	/// The emergency lockers the wing's cell block has (weakrefs)
	var/list/emergency_lockers = list()

/**
 * Makes sure the cell block has its emergency lockers: one per PRISON_EMERGENCY_LOCKER_TILES of floor,
 * counting any already standing there (mapped or placed), each new one against a yard wall away from the
 * others. Called when the cell block is worked out.
 */
/datum/outpost_prison/proc/ensure_emergency_lockers()
	if(!length(cell_block))
		return
	var/list/standing = list()
	var/floor = 0
	for(var/turf/tile as anything in cell_block)
		if(isclosedturf(tile))
			continue
		floor++
		for(var/obj/structure/closet/emcloset/locker in tile)
			standing += locker
	emergency_lockers.Cut()
	for(var/obj/structure/closet/emcloset/locker as anything in standing)
		emergency_lockers += WEAKREF(locker)
	var/wanted = max(1, round(floor / PRISON_EMERGENCY_LOCKER_TILES))
	while(length(standing) < wanted)
		var/turf/spot = emergency_locker_spot(standing)
		if(!spot)
			return
		var/obj/structure/closet/emcloset/outpost_prison/locker = new(spot)
		standing += locker
		emergency_lockers += WEAKREF(locker)

/// A yard tile against a wall, in no cell, with nothing on it and no door beside it, furthest from `others`
/datum/outpost_prison/proc/emergency_locker_spot(list/others)
	var/turf/best
	var/best_distance = -1
	for(var/turf/open/tile in cell_block)
		if(cell_at(tile) || tile.is_blocked_turf(TRUE) || length(tile.contents))
			continue
		var/against_wall = FALSE
		var/by_door = FALSE
		for(var/direction in GLOB.cardinals)
			var/turf/beside = get_step(tile, direction)
			if(isclosedturf(beside))
				against_wall = TRUE
			if(locate(/obj/machinery/door) in beside)
				by_door = TRUE
		if(!against_wall || by_door)
			continue
		var/nearest = INFINITY
		for(var/atom/other as anything in others)
			nearest = min(nearest, get_dist(other, tile))
		if(nearest > best_distance)
			best = tile
			best_distance = nearest
	return best

/// The nearest emergency locker `prisoner` can walk to that still has a mask and a tank in it
/datum/outpost_prison/proc/emergency_locker_for(mob/living/carbon/human/npc/outpost_prisoner/prisoner)
	var/obj/structure/closet/best
	var/best_distance = INFINITY
	for(var/datum/weakref/locker_ref as anything in emergency_lockers)
		var/obj/structure/closet/locker = locker_ref.resolve()
		if(QDELETED(locker) || !prisoner.approach_turf(locker))
			continue
		// A locker nobody has opened yet (tg fills them on first opening) is worth a look.
		if(locker.contents_initialized || locker.opened)
			var/atom/inside = locker.opened ? get_turf(locker) : locker
			if(!(locate(/obj/item/clothing/mask/breath) in inside) && !(locate(/obj/item/clothing/mask/gas) in inside))
				continue
			if(!(locate(/obj/item/tank/internals) in inside))
				continue
		var/distance = get_dist(prisoner, locker)
		if(distance < best_distance)
			best = locker
			best_distance = distance
	return best

/mob/living/carbon/human/npc/outpost_prisoner
	/// world.time they may next go for an emergency locker
	var/next_emergency_try = 0

/// Whether they wear a mask they could breathe a tank through, and carry a tank
/mob/living/carbon/human/npc/outpost_prisoner/proc/has_emergency_air()
	if(!can_breathe_internals())
		return FALSE
	for(var/obj/item/tank/internals/tank in get_equipped_items(INCLUDE_POCKETS | INCLUDE_HELD))
		return TRUE
	return FALSE

/**
 * The air where they stand is bad (air_tick()). Wearing a mask and a tank, they breathe from it.
 * Otherwise, unless they are busy with trouble, they go for the nearest emergency locker.
 */
/mob/living/carbon/human/npc/outpost_prisoner/proc/on_bad_air()
	if(stat != CONSCIOUS)
		return
	if(has_emergency_air())
		if(!internal)
			npc_open_internals()
		return
	if(world.time < next_emergency_try || istype(activity, /datum/prisoner_activity/emergency_air) || !routine_allowed())
		return
	var/datum/prisoner_activity/emergency_air/dash = new(src)
	if(!dash.setup())
		qdel(dash)
		next_emergency_try = world.time + PRISON_EMERGENCY_RETRY
		return
	start_activity(dash)

/// To the emergency locker: open it, take a mask and a tank, put them on and breathe
/datum/prisoner_activity/emergency_air
	name = "getting emergency air"
	interruptible = FALSE
	min_duration = 3 SECONDS
	max_duration = 3 SECONDS
	var/datum/weakref/locker_ref

/datum/prisoner_activity/emergency_air/setup()
	var/obj/structure/closet/locker = prisoner.prison?.emergency_locker_for(prisoner)
	if(!locker)
		return FALSE
	locker_ref = WEAKREF(locker)
	spot = prisoner.approach_turf(locker)
	return !!spot

/datum/prisoner_activity/emergency_air/begin()
	. = ..()
	var/obj/structure/closet/locker = locker_ref?.resolve()
	if(QDELETED(locker) || get_dist(prisoner, locker) > 1)
		return
	prisoner.face_atom(locker)
	if(!locker.opened)
		locker.open(prisoner)
	var/turf/inside = get_turf(locker)
	var/obj/item/clothing/mask/mask = locate(/obj/item/clothing/mask/breath) in inside
	mask ||= locate(/obj/item/clothing/mask/gas) in inside
	var/obj/item/tank/internals/tank = locate(/obj/item/tank/internals) in inside
	if(!mask || !tank)
		return
	prisoner.visible_message(span_notice("[prisoner] grabs [mask] and [tank] out of [locker]."))
	if(prisoner.wear_mask && !prisoner.can_breathe_internals())
		prisoner.dropItemToGround(prisoner.wear_mask)
	if(!prisoner.wear_mask)
		mask.forceMove(prisoner)
		if(!prisoner.equip_to_slot_if_possible(mask, ITEM_SLOT_MASK, disable_warning = TRUE))
			mask.forceMove(inside)
	tank.forceMove(prisoner)
	if(!prisoner.equip_to_slot_if_possible(tank, ITEM_SLOT_BELT, disable_warning = TRUE) && !prisoner.equip_to_slot_if_possible(tank, ITEM_SLOT_LPOCKET, disable_warning = TRUE) && !prisoner.equip_to_slot_if_possible(tank, ITEM_SLOT_RPOCKET, disable_warning = TRUE) && !prisoner.put_in_hands(tank))
		tank.forceMove(inside)
	prisoner.npc_open_internals()

/datum/prisoner_activity/emergency_air/Destroy()
	locker_ref = null
	return ..()

#undef PRISON_EMERGENCY_LOCKER_TILES
#undef PRISON_EMERGENCY_RETRY
