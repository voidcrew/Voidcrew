/**
 * # Player-Created Bounty System
 *
 * Allows players to create bounties for other players to complete.
 * Two types of bounties:
 * - Preset Item Bounties: Select from predefined items, auto-complete when delivered
 * - Custom Bounties: Free-text objective, manually completed by creator
 */

/// Minimum reward for player bounties
#define PLAYER_BOUNTY_MIN_REWARD 100
/// Maximum reward for player bounties
#define PLAYER_BOUNTY_MAX_REWARD 50000

/**
 * Preset bounty items that can be selected via radial menu.
 * Format: type_path = list("name", icon_state, icon_file)
 * Amount is specified by the user when creating the bounty.
 */
GLOBAL_LIST_INIT(preset_bounty_items, list(
	// Common Materials
	/obj/item/stack/sheet/iron = list("Iron Sheets", "sheet-metal", 'icons/obj/stack_objects.dmi'),
	/obj/item/stack/sheet/glass = list("Glass Sheets", "sheet-glass", 'icons/obj/stack_objects.dmi'),
	/obj/item/stack/sheet/plasteel = list("Plasteel Sheets", "sheet-plasteel", 'icons/obj/stack_objects.dmi'),
	/obj/item/stack/sheet/mineral/plasma = list("Plasma Sheets", "sheet-plasma", 'icons/obj/stack_objects.dmi'),
	// Valuables
	/obj/item/stack/sheet/mineral/gold = list("Gold Sheets", "sheet-gold", 'icons/obj/stack_objects.dmi'),
	/obj/item/stack/sheet/mineral/silver = list("Silver Sheets", "sheet-silver", 'icons/obj/stack_objects.dmi'),
	/obj/item/stack/sheet/mineral/diamond = list("Diamonds", "sheet-diamond", 'icons/obj/stack_objects.dmi'),
	/obj/item/stack/sheet/mineral/uranium = list("Uranium Sheets", "sheet-uranium", 'icons/obj/stack_objects.dmi'),
	// Components
	/obj/item/stack/cable_coil = list("Cable Coil", "coil", 'icons/obj/stack_objects.dmi'),
	/obj/item/stock_parts/micro_laser = list("Micro-Laser", "micro_laser", 'icons/obj/devices/stock_parts.dmi'),
	/obj/item/stock_parts/capacitor = list("Capacitor", "capacitor", 'icons/obj/devices/stock_parts.dmi'),
	/obj/item/stock_parts/scanning_module = list("Scanning Module", "scan_module", 'icons/obj/devices/stock_parts.dmi'),
	// Medical
	/obj/item/reagent_containers/cup/bottle/epinephrine = list("Epinephrine Bottle", "bottle-4", 'icons/obj/medical/reagent_fillings.dmi'),
	/obj/item/stack/medical/suture = list("Sutures", "suture", 'icons/obj/medical/stack_medical.dmi'),
	/obj/item/stack/medical/mesh = list("Regen Mesh", "mesh", 'icons/obj/medical/stack_medical.dmi'),
	// Tools & Equipment
	/obj/item/multitool = list("Multitool", "multitool", 'icons/obj/devices/tool.dmi'),
	/obj/item/weldingtool = list("Welding Tool", "welder", 'icons/obj/tools.dmi'),
	/obj/item/crowbar = list("Crowbar", "crowbar", 'icons/obj/tools.dmi'),
))

/datum/player_bounty
	/// Display name for the bounty
	var/name = "Player Bounty"

	/// Description (for custom bounties, auto-generated for preset)
	var/desc = ""

	/// Credit reward for completing the bounty
	var/reward = 1000

	/// Weak reference to the ship that created this bounty
	var/datum/weakref/creator_ship_ref

	/// Weak reference to the creator's mission pad
	var/datum/weakref/creator_pad_ref

	/// List of ships (weakrefs) that have accepted this bounty
	var/list/datum/weakref/claiming_ships = list()

	/// List of ships (weakrefs) that have abandoned this bounty
	var/list/datum/weakref/abandoned_by = list()

	/// For preset bounties: the item type required
	var/target_item_type

	/// Display name for the target item
	var/target_item_name

	/// Required amount for stack items
	var/target_amount = 1

	/// Whether this is a custom text bounty (vs preset item)
	var/is_custom = FALSE

	/// When the bounty was created (world.time)
	var/creation_time

	/// Bounty status: "available", "completed", "cancelled"
	var/status = "available"

	/// Pending offers for custom bounties - list of offer data
	/// Each offer: list("ship_ref" = weakref, "pad_ref" = weakref, "items" = list of item descriptions, "time" = world.time)
	var/list/pending_offers = list()

/datum/player_bounty/New(obj/structure/overmap/ship/creator_ship, obj/machinery/mission_pad/creator_pad, reward_amount)
	. = ..()
	if(!creator_ship)
		qdel(src)
		return

	creator_ship_ref = WEAKREF(creator_ship)
	if(creator_pad)
		creator_pad_ref = WEAKREF(creator_pad)
	reward = clamp(reward_amount, PLAYER_BOUNTY_MIN_REWARD, PLAYER_BOUNTY_MAX_REWARD)
	creation_time = world.time

/datum/player_bounty/Destroy()
	creator_ship_ref = null
	creator_pad_ref = null
	claiming_ships.Cut()
	abandoned_by.Cut()
	pending_offers.Cut()
	return ..()

/**
 * Sets up this bounty as a preset item bounty.
 * @param item_type The type path of the required item
 * @param amount The amount required (for stacks)
 */
/datum/player_bounty/proc/setup_preset(item_type, amount = 1)
	if(!item_type || !(item_type in GLOB.preset_bounty_items))
		return FALSE

	target_item_type = item_type
	var/list/item_data = GLOB.preset_bounty_items[item_type]
	// Extract base name without the amount hint
	var/base_name = item_data[1]
	// Remove any existing amount hints like "(10)" from the display name
	var/paren_pos = findtext(base_name, " (")
	if(paren_pos)
		base_name = copytext(base_name, 1, paren_pos)

	target_amount = clamp(amount, 1, 100)
	is_custom = FALSE

	// Build display name with the user-specified amount
	if(ispath(item_type, /obj/item/stack))
		target_item_name = "[base_name] x[target_amount]"
	else
		target_item_name = base_name
		target_amount = 1 // Non-stackables are always 1

	name = "Wanted: [target_item_name]"
	desc = "Deliver [target_item_name] to the mission pad to collect your reward."

	return TRUE

/**
 * Sets up this bounty as a custom text bounty.
 * @param bounty_name The title for the bounty
 * @param bounty_desc The description/objective
 */
/datum/player_bounty/proc/setup_custom(bounty_name, bounty_desc)
	if(!bounty_name || !bounty_desc)
		return FALSE

	name = bounty_name
	desc = bounty_desc
	is_custom = TRUE
	target_item_type = null
	target_item_name = null
	target_amount = 1

	return TRUE

/**
 * Returns the creator ship if it still exists.
 */
/datum/player_bounty/proc/get_creator_ship()
	return creator_ship_ref?.resolve()

/**
 * Returns the creator's mission pad if it still exists.
 */
/datum/player_bounty/proc/get_creator_pad()
	return creator_pad_ref?.resolve()

/**
 * Checks if a ship is currently hunting this bounty.
 */
/datum/player_bounty/proc/is_claimant(obj/structure/overmap/ship/ship)
	for(var/datum/weakref/ref in claiming_ships)
		var/obj/structure/overmap/ship/resolved = ref.resolve()
		if(!resolved)
			claiming_ships -= ref
			continue
		if(resolved == ship)
			return TRUE
	return FALSE

/**
 * Checks if a ship has previously abandoned this bounty.
 */
/datum/player_bounty/proc/has_abandoned(obj/structure/overmap/ship/ship)
	for(var/datum/weakref/ref in abandoned_by)
		var/obj/structure/overmap/ship/resolved = ref.resolve()
		if(!resolved)
			abandoned_by -= ref
			continue
		if(resolved == ship)
			return TRUE
	return FALSE

/**
 * Gets the number of ships currently hunting this bounty.
 */
/datum/player_bounty/proc/get_hunter_count()
	var/count = 0
	for(var/datum/weakref/ref in claiming_ships)
		if(ref.resolve())
			count++
		else
			claiming_ships -= ref
	return count

/**
 * Checks if the bounty is still valid and available.
 */
/datum/player_bounty/proc/is_valid()
	if(status == "completed" || status == "cancelled")
		return FALSE

	// Check creator ship still exists
	var/obj/structure/overmap/ship/creator = get_creator_ship()
	if(!creator || QDELETED(creator))
		return FALSE

	return TRUE

/**
 * Attempts to claim this bounty for a ship.
 * @param ship The ship claiming the bounty
 * @return TRUE if successful, error message otherwise
 */
/datum/player_bounty/proc/claim(obj/structure/overmap/ship/ship)
	if(!ship || QDELETED(ship))
		return "invalid ship"

	if(status != "available")
		return "bounty not available"

	// Can't claim your own bounty
	if(ship == get_creator_ship())
		return "can't claim own bounty"

	// Check if already claiming
	if(is_claimant(ship))
		return "already hunting this"

	// Check if previously abandoned
	if(has_abandoned(ship))
		return "you abandoned this"

	// Check ship doesn't already have a claimed player bounty
	if(SSbounty?.ship_has_claimed_player_bounty(ship))
		return "already have active bounty"

	claiming_ships += WEAKREF(ship)
	return TRUE

/**
 * Abandons the bounty claim.
 * @param ship The ship abandoning
 */
/datum/player_bounty/proc/abandon(obj/structure/overmap/ship/ship)
	if(!is_claimant(ship))
		return FALSE

	for(var/datum/weakref/ref in claiming_ships)
		if(ref.resolve() == ship)
			claiming_ships -= ref
			abandoned_by += WEAKREF(ship)
			return TRUE
	return FALSE

/**
 * Checks if an item can be turned in for this bounty.
 * @param item The item being turned in
 * @param turner The ship turning it in
 */
/datum/player_bounty/proc/can_turn_in(obj/item/item, obj/structure/overmap/ship/turner)
	if(is_custom)
		return FALSE // Custom bounties can't be item-turned-in

	if(status != "available")
		return FALSE

	if(!is_claimant(turner))
		return FALSE

	if(!istype(item, target_item_type))
		return FALSE

	// Check stack amount if applicable
	if(isstack(item))
		var/obj/item/stack/S = item
		if(S.amount < target_amount)
			return FALSE

	return TRUE

/**
 * Completes the bounty via item turn-in.
 * Teleports items to creator's pad and awards credits.
 * @param turner_ship The ship completing the bounty
 * @param turner_pad The pad the items are on
 * @param items List of items being turned in (for stacks, may be multiple)
 */
/datum/player_bounty/proc/complete_preset(obj/structure/overmap/ship/turner_ship, obj/machinery/mission_pad/turner_pad, list/items)
	if(is_custom)
		return FALSE
	if(status != "available")
		return FALSE
	if(!is_claimant(turner_ship))
		return FALSE

	var/obj/structure/overmap/ship/creator_ship = get_creator_ship()
	var/obj/machinery/mission_pad/creator_pad = get_creator_pad()

	// Award credits to turner
	turner_ship.ship_account?.adjust_money(reward)

	// Handle item transfer - consume required amount from stacks
	var/remaining_to_take = target_amount
	var/turf/dest_turf = creator_pad ? get_turf(creator_pad) : null

	for(var/obj/item/item in items)
		if(remaining_to_take <= 0)
			break

		if(isstack(item))
			var/obj/item/stack/S = item
			var/take_from_this = min(S.amount, remaining_to_take)

			if(dest_turf)
				// Transfer to creator's pad
				if(S.amount <= take_from_this)
					// Take the whole stack
					S.forceMove(dest_turf)
					remaining_to_take -= S.amount
				else
					// Split the stack
					var/obj/item/stack/taken = S.split_stack(null, take_from_this)
					if(taken)
						taken.forceMove(dest_turf)
					remaining_to_take -= take_from_this
			else
				// No creator pad - just consume
				S.use(take_from_this)
				remaining_to_take -= take_from_this
		else
			// Non-stack item
			if(dest_turf)
				item.forceMove(dest_turf)
			else
				qdel(item)
			remaining_to_take = 0

	// Effects
	if(creator_pad)
		creator_pad.do_teleport_effect()
	turner_pad?.do_teleport_effect()

	// Announcements
	turner_ship.ship_announce("BOUNTY COMPLETE: [name] - [reward] credits awarded!", "MISSION CONTROL")
	creator_ship?.ship_announce("BOUNTY FULFILLED: [name] - Item delivered to your mission pad.", "MISSION CONTROL")

	// Notify other claimants they lost
	for(var/datum/weakref/ref in claiming_ships)
		var/obj/structure/overmap/ship/loser = ref.resolve()
		if(loser && loser != turner_ship)
			loser.ship_announce("BOUNTY LOST: [name] - Another crew completed the bounty first.", "MISSION CONTROL")

	status = "completed"
	SSbounty?.remove_player_bounty(src)

	return TRUE

/**
 * Creates an offer for the bounty creator to review (for custom bounties).
 * Items stay on the sender's pad until the creator approves.
 * @param items List of items being offered
 * @param sender_pad The pad with the items
 * @param sender_ship The ship making the offer
 * @return TRUE if offer created, FALSE otherwise
 */
/datum/player_bounty/proc/make_offer(list/items, obj/machinery/mission_pad/sender_pad, obj/structure/overmap/ship/sender_ship)
	if(!is_custom)
		return FALSE
	if(status != "available")
		return FALSE
	if(!is_claimant(sender_ship))
		return FALSE
	if(!length(items))
		return FALSE

	// Check if this ship already has a pending offer
	for(var/list/offer in pending_offers)
		var/datum/weakref/existing_ref = offer["ship_ref"]
		if(existing_ref?.resolve() == sender_ship)
			return FALSE // Already has pending offer

	// Build item descriptions
	var/list/item_descriptions = list()
	for(var/obj/item/item in items)
		if(isstack(item))
			var/obj/item/stack/S = item
			item_descriptions += "[S.name] x[S.amount]"
		else
			item_descriptions += item.name

	// Create the offer
	var/list/new_offer = list(
		"ship_ref" = WEAKREF(sender_ship),
		"pad_ref" = WEAKREF(sender_pad),
		"items" = item_descriptions,
		"time" = world.time,
	)
	pending_offers += list(new_offer)

	// Notify both parties
	var/obj/structure/overmap/ship/creator = get_creator_ship()
	var/items_str = jointext(item_descriptions, ", ")
	sender_ship?.ship_announce("BOUNTY: Offer submitted to bounty creator. Awaiting approval.", "MISSION CONTROL")
	creator?.ship_announce("BOUNTY: [sender_ship?.name || "Unknown"] offers: [items_str] for '[name]'. Review at mission console.", "MISSION CONTROL")

	return TRUE

/**
 * Gets the pending offer from a specific ship.
 */
/datum/player_bounty/proc/get_offer_from_ship(obj/structure/overmap/ship/ship)
	for(var/list/offer in pending_offers)
		var/datum/weakref/ship_ref = offer["ship_ref"]
		if(ship_ref?.resolve() == ship)
			return offer
	return null

/**
 * Checks if a ship has a pending offer.
 */
/datum/player_bounty/proc/has_pending_offer(obj/structure/overmap/ship/ship)
	return !!get_offer_from_ship(ship)

/**
 * Approves an offer - teleports items and completes the bounty.
 * @param sender_ship The ship whose offer is being approved
 * @return TRUE if successful, error message otherwise
 */
/datum/player_bounty/proc/approve_offer(obj/structure/overmap/ship/sender_ship)
	if(!is_custom)
		return "not a custom bounty"
	if(status != "available")
		return "bounty not available"

	var/list/offer = get_offer_from_ship(sender_ship)
	if(!offer)
		return "no pending offer"

	var/datum/weakref/pad_ref = offer["pad_ref"]
	var/obj/machinery/mission_pad/sender_pad = pad_ref?.resolve()
	if(!sender_pad || QDELETED(sender_pad))
		// Remove invalid offer
		pending_offers -= list(offer)
		return "sender's pad no longer exists"

	// Get items currently on sender's pad
	var/list/items_on_pad = sender_pad.get_items_on_pad()
	if(!length(items_on_pad))
		// Remove offer since items are gone
		pending_offers -= list(offer)
		return "items no longer on pad"

	// Get creator's pad for receiving items
	var/obj/machinery/mission_pad/creator_pad = get_creator_pad()
	var/turf/dest_turf = creator_pad ? get_turf(creator_pad) : null

	// Transfer items
	var/sent_count = 0
	for(var/obj/item/item in items_on_pad)
		if(dest_turf)
			item.forceMove(dest_turf)
		sent_count++

	// Effects
	if(sent_count > 0)
		sender_pad.do_teleport_effect()
		creator_pad?.do_teleport_effect()

	// Award credits
	sender_ship.ship_account?.adjust_money(reward)

	// Announcements
	var/obj/structure/overmap/ship/creator_ship = get_creator_ship()
	sender_ship.ship_announce("BOUNTY COMPLETE: [name] - [reward] credits awarded! Items delivered.", "MISSION CONTROL")
	creator_ship?.ship_announce("BOUNTY COMPLETED: [name] - Received [sent_count] item(s), paid [reward] cr to [sender_ship.name].", "MISSION CONTROL")

	// Notify other claimants they lost
	for(var/datum/weakref/ref in claiming_ships)
		var/obj/structure/overmap/ship/loser = ref.resolve()
		if(loser && loser != sender_ship)
			loser.ship_announce("BOUNTY LOST: [name] - Creator accepted another crew's offer.", "MISSION CONTROL")

	status = "completed"
	SSbounty?.remove_player_bounty(src)

	return TRUE

/**
 * Rejects an offer from a ship.
 * @param sender_ship The ship whose offer is being rejected
 */
/datum/player_bounty/proc/reject_offer(obj/structure/overmap/ship/sender_ship)
	var/list/offer = get_offer_from_ship(sender_ship)
	if(!offer)
		return FALSE

	pending_offers -= list(offer)

	// Notify the sender
	sender_ship?.ship_announce("BOUNTY: Your offer for '[name]' was rejected by the creator.", "MISSION CONTROL")

	return TRUE

/**
 * Withdraws the ship's own pending offer.
 * @param ship The ship withdrawing their offer
 */
/datum/player_bounty/proc/withdraw_offer(obj/structure/overmap/ship/ship)
	var/list/offer = get_offer_from_ship(ship)
	if(!offer)
		return FALSE

	pending_offers -= list(offer)

	// Notify the creator
	var/obj/structure/overmap/ship/creator = get_creator_ship()
	creator?.ship_announce("BOUNTY: [ship.name] withdrew their offer for '[name]'.", "MISSION CONTROL")

	return TRUE

/**
 * Completes a custom bounty manually (creator confirms completion for a specific claimant).
 * @param winner_ship The ship to award the bounty to
 */
/datum/player_bounty/proc/complete_custom(obj/structure/overmap/ship/winner_ship)
	if(!is_custom)
		return FALSE

	if(status != "available")
		return FALSE

	if(!winner_ship || !is_claimant(winner_ship))
		return FALSE

	var/obj/structure/overmap/ship/creator_ship = get_creator_ship()

	// Award credits
	winner_ship.ship_account?.adjust_money(reward)

	// Announcements
	winner_ship.ship_announce("BOUNTY COMPLETE: [name] - [reward] credits awarded!", "MISSION CONTROL")
	creator_ship?.ship_announce("BOUNTY COMPLETED: [name] - Reward paid to [winner_ship.name].", "MISSION CONTROL")

	// Notify other claimants they lost
	for(var/datum/weakref/ref in claiming_ships)
		var/obj/structure/overmap/ship/loser = ref.resolve()
		if(loser && loser != winner_ship)
			loser.ship_announce("BOUNTY LOST: [name] - Creator awarded bounty to another crew.", "MISSION CONTROL")

	status = "completed"
	SSbounty?.remove_player_bounty(src)

	return TRUE

/**
 * Cancels the bounty (creator cancels).
 * Refunds reward to creator.
 */
/datum/player_bounty/proc/cancel()
	var/obj/structure/overmap/ship/creator_ship = get_creator_ship()

	// Refund the creator
	if(status == "available" && creator_ship)
		creator_ship.ship_account?.adjust_money(reward)

	// Notify all claimants that the bounty was cancelled
	for(var/datum/weakref/ref in claiming_ships)
		var/obj/structure/overmap/ship/claimer = ref.resolve()
		if(claimer)
			claimer.ship_announce("BOUNTY CANCELLED: [name] - The bounty creator has cancelled this bounty.", "MISSION CONTROL")

	status = "cancelled"
	SSbounty?.remove_player_bounty(src)

	return TRUE

/**
 * Gets UI data for this bounty.
 * @param for_ship Optional ship to include relationship data for
 */
/datum/player_bounty/proc/get_ui_data(obj/structure/overmap/ship/for_ship = null)
	var/list/data = list(
		"ref" = REF(src),
		"name" = name,
		"desc" = desc,
		"reward" = reward,
		"is_custom" = is_custom,
		"status" = status,
		"target_item_name" = target_item_name,
		"target_amount" = target_amount,
		"hunter_count" = get_hunter_count(),
	)

	// Add creator info
	var/obj/structure/overmap/ship/creator = get_creator_ship()
	if(creator)
		data["creator_name"] = creator.name

	// Add relationship data
	if(for_ship)
		data["is_creator"] = (for_ship == creator)
		data["is_claimer"] = is_claimant(for_ship)
		data["was_abandoned"] = has_abandoned(for_ship)
		data["has_pending_offer"] = has_pending_offer(for_ship)
		// Can claim if: status available, not creator, not already a claimant, hasn't abandoned, and doesn't have another claimed bounty
		data["can_claim"] = (status == "available" && for_ship != creator && !is_claimant(for_ship) && !has_abandoned(for_ship) && !SSbounty?.ship_has_claimed_player_bounty(for_ship))

	// For custom bounties with creator viewing, include pending offers
	if(is_custom && for_ship == creator && length(pending_offers) > 0)
		var/list/offers_data = list()
		for(var/list/offer in pending_offers)
			var/datum/weakref/ship_ref = offer["ship_ref"]
			var/obj/structure/overmap/ship/offer_ship = ship_ref?.resolve()
			if(offer_ship)
				offers_data += list(list(
					"ship_ref" = REF(offer_ship),
					"ship_name" = offer_ship.name,
					"items" = offer["items"],
				))
		data["pending_offers"] = offers_data

	return data

#undef PLAYER_BOUNTY_MIN_REWARD
#undef PLAYER_BOUNTY_MAX_REWARD
