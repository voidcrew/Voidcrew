/**
 * Extraction Case
 *
 * A secure case specifically designed for ship part extraction.
 * - Only holds ship parts
 * - Limited capacity (5 parts max)
 * - Lockable with a 5-digit PIN (set by player)
 * - Can be hacked: screwdriver to open panel, then multitool (40 seconds)
 * - Can be broken into via EMAG (lock destroyed permanently)
 * - Only parts inside this case are extracted on bluespace jump / round end
 */

/// Storage datum for extraction case - only accepts ship parts
/datum/storage/briefcase/extraction
	max_slots = 5
	max_total_storage = 10
	max_specific_storage = WEIGHT_CLASS_NORMAL

/datum/storage/briefcase/extraction/New(atom/parent, max_slots, max_specific_storage, max_total_storage, rustle_sound, remove_rustle_sound)
	. = ..()
	set_holdable(/obj/item/ship_parts)

/// The extraction case item - based on secure briefcase for PIN locking
/obj/item/storage/briefcase/secure/extraction
	name = "extraction case"
	desc = "A compact secure case designed for ship part extraction. Upon extraction the contents will be scanned and deposited into your storage."
	icon_state = "secure"
	base_icon_state = "secure"
	inhand_icon_state = "sec-case"
	w_class = WEIGHT_CLASS_NORMAL // Fits in backpack
	storage_type = /datum/storage/briefcase/extraction

/obj/item/storage/briefcase/secure/extraction/PopulateContents()
	// Start empty
	return

/obj/item/storage/briefcase/secure/extraction/examine(mob/user)
	. = ..()
	. += span_notice("This case can hold up to 5 ship parts.")
	. += span_notice("You can only have one of these on you when you leave.")
	. += span_notice("Use in-hand to set a PIN code and lock it.")

	// Show contents count
	var/part_count = 0
	for(var/obj/item/ship_parts/part in contents)
		part_count++
	. += span_notice("Currently holding [part_count]/5 ship parts.")

/// Spawner for placing extraction cases on maps
/obj/effect/spawner/extraction_case
	name = "extraction case spawner"
	icon = 'icons/obj/storage/case.dmi'
	icon_state = "secure"

/obj/effect/spawner/extraction_case/Initialize(mapload)
	. = ..()
	new /obj/item/storage/briefcase/secure/extraction(loc)
	return INITIALIZE_HINT_QDEL
