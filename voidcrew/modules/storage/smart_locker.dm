/**
 * Smart lockers.
 *
 * A smartfridge that isn't picky about what it holds. Anything loose goes in and gets
 * catalogued in the usual smartfridge list, which beats a floor covered in toolboxes.
 *
 * The one thing it refuses is other storage: bags, boxes, belts and cases. Letting those
 * in would turn one machine slot into a whole backpack's worth of stuff, so they bounce.
 * Handing it a bag still works the way it does on every other smartfridge - the bag's
 * contents get unloaded into the locker and the bag stays in your hand.
 */

/// Items a single-tier smart locker holds. Scales with the matter bin like every smartfridge.
#define SMART_LOCKER_CAPACITY 50

/obj/machinery/smartfridge/storage
	name = "smart locker"
	desc = "A general purpose storage unit that catalogues everything dropped into it. It won't take bags, boxes or belts - only loose gear."
	circuit = /obj/item/circuitboard/machine/smartfridge/storage
	base_build_path = /obj/machinery/smartfridge/storage
	max_n_of_items = SMART_LOCKER_CAPACITY
	// There is no "pile of assorted junk" fill sprite to draw, so the front stays clear.
	visible_contents = FALSE
	contents_overlay_icon = null
	/// Heaviest thing the locker will swallow.
	var/max_item_weight = WEIGHT_CLASS_HUGE

/obj/machinery/smartfridge/storage/accept_check(obj/item/weapon)
	if(!isitem(weapon) || QDELETED(weapon))
		return FALSE
	if(weapon.item_flags & (ABSTRACT | DROPDEL))
		return FALSE
	if(weapon.flags_1 & HOLOGRAM_1)
		return FALSE
	if(weapon.w_class > max_item_weight)
		return FALSE
	// Bags, boxes, belts, cases - the whole point of these is holding other items, and
	// a locker full of full backpacks is how you fit a cargo bay into one tile.
	if(istype(weapon, /obj/item/storage))
		return FALSE
	// Pocketed clothing and the like is fine, but only once you've emptied the pockets.
	if(weapon.atom_storage && length(weapon.contents))
		return FALSE
	return TRUE

/obj/machinery/smartfridge/storage/examine(mob/user)
	. = ..()
	. += span_notice("It refuses bags, boxes and belts. Empty the pockets of anything you want to store.")

/*
 * Board and research
 */

/obj/item/circuitboard/machine/smartfridge/storage
	name = "Smart Locker"
	build_path = /obj/machinery/smartfridge/storage
	// Not one of the screwdriver-cycled fridge flavours, so it stays what it is.
	is_special_type = TRUE

/datum/design/board/smartlocker
	name = "Smart Locker Board"
	desc = "The circuit board for a smart locker."
	build_path = /obj/item/circuitboard/machine/smartfridge/storage
	category = list(
		RND_CATEGORY_MACHINE + RND_SUBCATEGORY_MACHINE_CARGO
	)
	departmental_flags = DEPARTMENT_BITFLAG_CARGO | DEPARTMENT_BITFLAG_SERVICE

// Rides along with the smartfridge board, since it is the same machine wearing a different hat.
/datum/techweb_node/food_proc/New()
	unlocked_designs += list(
		/datum/design/board/smartlocker,
	)
	return ..()

#undef SMART_LOCKER_CAPACITY
