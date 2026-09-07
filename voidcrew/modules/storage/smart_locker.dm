/**
 * Smart lockers.
 *
 * A smartfridge that isn't picky about what it holds. Anything loose goes in and gets
 * catalogued in the usual smartfridge list, which beats a floor covered in toolboxes.
 *
 * The one thing it refuses is other storage: bags, boxes, belts and cases. Letting those
 * in would turn one machine slot into a whole backpack's worth of stuff, so they bounce.
 * Clicking with, or dragging, a storage container unloads accepted contents while
 * leaving the container and any refused or excess items where they were.
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

/obj/machinery/smartfridge/storage/Initialize(mapload)
	. = ..()
	RegisterSignal(src, COMSIG_STORAGE_DUMP_CONTENT, PROC_REF(on_storage_dump))

/obj/machinery/smartfridge/storage/attackby(obj/item/weapon, mob/living/user, list/modifiers, list/attack_modifiers)
	if(weapon.atom_storage && !accept_check(weapon))
		return load_storage(weapon.atom_storage, user) > 0
	return ..()

/// Intercept storage's normal floor-dumping path, including when nothing fits.
/obj/machinery/smartfridge/storage/proc/on_storage_dump(datum/source, datum/storage/storage, mob/user)
	SIGNAL_HANDLER
	load_storage(storage, user)
	return STORAGE_DUMP_HANDLED

/// Move only accepted loose items through the source storage's normal removal checks.
/obj/machinery/smartfridge/storage/proc/load_storage(datum/storage/storage, mob/user)
	if(!user.canUseStorage() || !user.can_perform_action(src, FORBID_TELEKINESIS_REACH))
		return 0
	if(machine_stat)
		balloon_alert(user, "not operational!")
		return 0
	if(storage.locked)
		balloon_alert(user, "container locked!")
		return 0
	if(!user.CanReach(storage.parent))
		return 0

	var/loaded = 0
	for(var/obj/item/to_store in storage.real_location.contents.Copy())
		if(visible_items() >= max_n_of_items)
			break
		if(!accept_check(to_store))
			continue
		if(storage.attempt_remove(to_store, src, silent = TRUE))
			loaded++

	if(loaded)
		add_fingerprint(user)
		to_chat(user, span_notice("You load [loaded] item[loaded == 1 ? "" : "s"] from [storage.parent] into [src]."))
		SStgui.update_uis(src)
	else if(visible_items() >= max_n_of_items)
		balloon_alert(user, "no space!")
	else
		balloon_alert(user, "no acceptable items!")
	return loaded

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
	. += span_notice("Drag a storage container onto it to unload loose items. It refuses bags, boxes and belts, and leaves excess or refused items in the container. Empty the pockets of anything you want to store.")

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
	id = "smartlocker"
	build_path = /obj/item/circuitboard/machine/smartfridge/storage
	category = list(
		RND_CATEGORY_MACHINE + RND_SUBCATEGORY_MACHINE_CARGO
	)
	departmental_flags = DEPARTMENT_BITFLAG_CARGO | DEPARTMENT_BITFLAG_SERVICE

// Rides along with the smartfridge board, since it is the same machine wearing a different hat.
/datum/techweb_node/food_proc/New()
	. = ..()
	design_ids += list(
		"smartlocker",
	)

#undef SMART_LOCKER_CAPACITY
