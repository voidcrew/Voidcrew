/**
 * Ship Parts Items - Rarity-Based System
 *
 * Physical items that can be picked up and redeemed for ship parts.
 * Uses rarity tiers: common, uncommon, rare, epic, legendary
 * Parts are stored in the database via GLOB.ship_economy_db
 */
/obj/item/ship_parts
	name = "ship parts"
	desc = "Ship parts, use them in hand to redeem them. Used for building ships."
	icon = 'voidcrew/modules/shuttle/ship_parts/icons/ship_item.dmi'
	icon_state = "ship"

	/// The rarity tier of this ship part
	var/part_rarity = RARITY_COMMON

/obj/item/ship_parts/attack_self(mob/user)
	. = ..()
	if(!user.client)
		to_chat(user, span_warning("You need to be logged in to redeem ship parts!"))
		return

	var/ckey = user.client.ckey
	if(!ckey)
		to_chat(user, span_warning("Unable to identify your account!"))
		return

	// Add part to database
	if(GLOB.ship_economy_db?.add_part(ckey, part_rarity, 1, "item_redemption"))
		to_chat(user, span_notice("You have redeemed [src]! One [part_rarity] part has been added to your account."))
		qdel(src)
	else
		to_chat(user, span_warning("Failed to redeem ship part. Please try again or contact an administrator."))

/obj/item/ship_parts/examine(mob/user)
	. = ..()
	. += span_notice("This is a [part_rarity] rarity ship part.")
	. += span_notice("Use it in hand to add it to your account.")

// Common parts (gray/white)
/obj/item/ship_parts/common
	name = "common ship parts"
	desc = "Common quality ship parts. These are basic components for smaller vessels."
	color = "#9d9d9d"
	part_rarity = RARITY_COMMON

// Uncommon parts (green)
/obj/item/ship_parts/uncommon
	name = "uncommon ship parts"
	desc = "Uncommon quality ship parts. Better than basic, suitable for mid-tier ships."
	color = "#1eff00"
	part_rarity = RARITY_UNCOMMON

// Rare parts (blue)
/obj/item/ship_parts/rare
	name = "rare ship parts"
	desc = "Rare quality ship parts. High-grade components for advanced vessels."
	color = "#0070dd"
	part_rarity = RARITY_RARE

// Epic parts (purple)
/obj/item/ship_parts/epic
	name = "epic ship parts"
	desc = "Epic quality ship parts. Premium components for elite vessels."
	color = "#a335ee"
	part_rarity = RARITY_EPIC

// Legendary parts (orange)
/obj/item/ship_parts/legendary
	name = "legendary ship parts"
	desc = "Legendary quality ship parts. The finest components for the most powerful ships."
	color = "#ff8000"
	part_rarity = RARITY_LEGENDARY
