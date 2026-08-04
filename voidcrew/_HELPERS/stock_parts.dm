/**
 * Sums the tier of every installed stock part belonging to one category.
 *
 * component_parts stores two different representations of the same part. Anything installed with
 * an RPED becomes a /datum/stock_part singleton, while anything installed by hand or spawned with
 * the machine stays an /obj/item/stock_parts. A RefreshParts() that only walks one of those forms
 * reads a rating of zero on machines built the other way - it compiles, it runs, and the machine
 * quietly comes out with no output. Go through here instead of writing the loop by hand.
 *
 * Pass the category datum path, e.g. /datum/stock_part/capacitor; the matching object path is
 * derived from it, and subtypes of both (tier 2, tier 3, tier 4) are counted.
 */
/obj/machinery/proc/total_part_rating(datum/stock_part/category)
	. = 0
	if(!length(component_parts))
		return
	var/obj/item/object_category = initial(category.physical_object_base_type)
	for(var/part in component_parts)
		if(istype(part, category))
			var/datum/stock_part/datum_part = part
			. += datum_part.tier
		else if(object_category && istype(part, object_category))
			var/obj/item/stock_parts/object_part = part
			. += object_part.rating
