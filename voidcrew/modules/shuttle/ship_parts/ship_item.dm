/**
 * Ship Parts Items - Class-Based System
 *
 * Physical items that can be picked up and traded between players.
 * Uses part classes: combat, science, trade, misc
 * Parts are NOT automatically redeemed - they must be:
 * 1. Placed in an extraction briefcase
 * 2. Extracted via bluespace jump or round end
 * Parts NOT in a briefcase will be lost!
 */
/obj/item/ship_parts
	name = "ship parts"
	desc = "Ship parts used for unlocking ships. Put these in an extraction briefcase before jumping - loose parts won't be extracted!"
	icon = 'voidcrew/modules/shuttle/ship_parts/icons/ship_item.dmi'
	icon_state = "misc"
	w_class = WEIGHT_CLASS_SMALL

	/// The class of this ship part (combat, science, trade, misc)
	var/part_class = PART_CLASS_MISC

/obj/item/ship_parts/examine(mob/user)
	. = ..()
	. += span_notice("This is a [part_class]-class ship part.")
	. += span_warning("Must be stored in an extraction briefcase to be extracted!")
	. += span_notice("Parts are extracted when you bluespace jump or when the round ends.")
	. += span_notice("No briefcase? Get a free one with the Request Extraction Case verb in the IC tab.")

// Combat parts (red) - found in wrecks, combat zones
/obj/item/ship_parts/combat
	name = "combat ship parts"
	desc = "Military-grade ship components. Used for unlocking warships and combat vessels. Found in wrecks and combat zones. Store in an extraction briefcase!"
	icon_state = "combat"
	part_class = PART_CLASS_COMBAT

// Science parts (blue) - found in labs, research sites
/obj/item/ship_parts/science
	name = "science ship parts"
	desc = "Advanced research components. Used for unlocking research vessels and science ships. Found in laboratories and research sites. Store in an extraction briefcase!"
	icon_state = "science"
	part_class = PART_CLASS_SCIENCE

// Trade parts (gold) - found in stations, trade posts
/obj/item/ship_parts/trade
	name = "trade ship parts"
	desc = "Commercial-grade ship components. Used for unlocking cargo haulers and trade vessels. Found at stations and trade posts. Store in an extraction briefcase!"
	icon_state = "trade"
	part_class = PART_CLASS_TRADE

// Misc parts (gray) - found in general loot areas
/obj/item/ship_parts/misc
	name = "miscellaneous ship parts"
	desc = "General purpose ship components. Used for various ship unlocks. Found in general loot areas. Store in an extraction briefcase!"
	icon_state = "misc"
	part_class = PART_CLASS_MISC
