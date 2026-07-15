/**
 * # Outpost Supply Contracts
 *
 * The shop-specific mission loop: each trader outpost posts a couple of
 * supply requests ("bring me X"), and the pay is a FREE ITEM off the shop's
 * own shelves rather than credits. Gives a ship a reason to detour to an
 * outpost even with empty pockets.
 *
 * The player-facing side is the trader NPC's Contracts radial (see
 * trader_npc.dm). Wiring rides the existing mission pipeline end to end:
 * accepting at the trader puts the mission in the ship's active list, and
 * turn-in happens at the trader or back at the ship's own mission board +
 * pad, where the reward item spawns exactly like voucher/item rewards do.
 */

/// How many contracts an outpost keeps posted at once
#define OUTPOST_SHOP_OFFER_COUNT 4

/**
 * # Outpost Supply Mission
 *
 * Delivery-style: haul the asked goods to your ship's mission pad. Pays no
 * credits — the reward is one free item rolled off the posting shop's SKU
 * list at creation time.
 */
/datum/mission/outpost_supply
	name = "Supply Request: %ITEM_NAME%"
	desc = "%AUTHOR% is paying in kit: deliver %ITEM_NAME% to your ship's mission pad and a %REWARD% comes off the shelf, free."
	weight = 0 // never rolled by the mission subsystem; outposts post these themselves
	requires_item = TRUE
	value_min = 0
	value_max = 0
	duration = 40 MINUTES

	/// The type of item required for delivery
	var/required_type
	/// Display name for the required item
	var/required_name
	/// Amount required (for stacks)
	var/required_amount = 1

/datum/mission/outpost_supply/get_archetype()
	return "procurement"

/datum/mission/outpost_supply/generate_mission_details()
	if(!shop)
		generation_failed = TRUE
		return
	author = shop.trader_name

	var/list/request = length(shop.mission_requests) ? pick(shop.mission_requests) : null
	if(!request)
		generation_failed = TRUE
		return
	required_type = request["type"]
	required_name = request["name"]
	required_amount = request["amount"] || 1
	difficulty = request["difficulty"] || MISSION_DIFFICULTY_MEDIUM

	// The pay: one free item off the shelf. Rolled from the SKU list so the
	// reward is always something the shop actually sells.
	var/list/reward_pool = list()
	for(var/datum/shop_sku/sku as anything in shop.skus)
		if(sku.item_path)
			reward_pool += sku.item_path
	if(!length(reward_pool))
		generation_failed = TRUE
		return
	mission_reward = pick(reward_pool)
	// Hard asks can upgrade the pay to something off the back shelf instead
	shop.maybe_attach_exclusive(src)

	. = ..()

/datum/mission/outpost_supply/apply_text_substitutions()
	. = ..()
	var/item_text = required_amount > 1 ? "[required_amount] [required_name]" : required_name
	name = replacetext(name, "%ITEM_NAME%", item_text)
	desc = replacetext(desc, "%ITEM_NAME%", item_text)

/datum/mission/outpost_supply/can_turn_in(obj/item/item)
	if(!item || !istype(item, required_type))
		return FALSE
	if(istype(item, /obj/item/stack))
		var/obj/item/stack/stack = item
		if(stack.amount < required_amount)
			return FALSE
	return TRUE

/datum/mission/outpost_supply/get_failure_reason(obj/item/item)
	if(!item)
		return "No item provided."
	if(!istype(item, required_type))
		return "Wrong item type."
	if(istype(item, /obj/item/stack))
		var/obj/item/stack/stack = item
		if(stack.amount < required_amount)
			return "Need [required_amount], only have [stack.amount]."
	return ..()

/datum/mission/outpost_supply/consume_turned_in_item(obj/item/item)
	if(istype(item, /obj/item/stack))
		var/obj/item/stack/stack = item
		stack.use(required_amount)
	else
		qdel(item)

/datum/mission/outpost_supply/get_progress_string()
	return "Deliver [required_amount > 1 ? "[required_amount] " : ""][required_name]"

// ===== OFFER MANAGEMENT (lives on the outpost) =====

/**
 * Keeps the outpost's posted contracts topped up with a mixed archetype
 * spread. Procurement stays the bread and butter; the rest is rolled.
 * Discards failed rolls (e.g. courier with no second outpost).
 */
/obj/structure/overmap/trader_outpost/proc/ensure_shop_offers()
	if(!shop)
		return
	var/static/list/offer_mix = list(
		/datum/mission/outpost_supply = 40,
		/datum/mission/recovery/kill/outpost = 25,
		/datum/mission/recovery/outpost = 20,
		/datum/mission/outpost_courier = 15,
	)
	var/safety = 12
	while(length(shop_offers) < OUTPOST_SHOP_OFFER_COUNT && safety-- > 0)
		// Always keep at least one plain supply request on the board
		var/offer_type = /datum/mission/outpost_supply
		if(has_posted_offer_type(/datum/mission/outpost_supply))
			offer_type = pick_weight(offer_mix)
		var/datum/mission/offer = new offer_type(shop)
		if(offer.generation_failed)
			qdel(offer)
			continue
		shop_offers += offer

/// Whether an offer of the exact given type is currently posted
/obj/structure/overmap/trader_outpost/proc/has_posted_offer_type(offer_type)
	for(var/datum/mission/offer as anything in shop_offers)
		if(offer.type == offer_type)
			return TRUE
	return FALSE

#undef OUTPOST_SHOP_OFFER_COUNT
