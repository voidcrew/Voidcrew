/**
 * # Owner shop stock
 *
 * The powerless stock machine in the shop's staff room (outpost_shop.dm). Staff put real items in
 * it; the register on the counter sells them to visitors for credits paid into the treasury.
 *
 * Items are grouped into listings of interchangeable units. The key is type, name, stack merge type
 * and materials, plus the unit's state (reagents, charge, ammo, damage), so a poisoned syringe
 * never shares a listing with clean ones. Stacks are priced per unit. Units sell first in, first
 * out. An emptied listing keeps its price and category until staff forget it, so restocking puts
 * matching goods straight back on sale.
 *
 * Who does what (R1):
 * * Managers (owner, stewards) put stock in.
 * * Pricing users (owner, treasurers, pricers) set prices and categories, and take stock out.
 * * Either may open or close the shop.
 * * Managers and pricing users take stock free at the register; everyone else pays.
 *
 * This is deliberately not a smartfridge: that one vends to anyone who reaches it and dumps its
 * contents when pried open without power. Nothing leaves this machine except through a sale or a
 * staff eject, and anything that leaves another way is logged.
 */

/// One group of interchangeable units in the stock machine
/datum/outpost_shop_listing
	/// Serial number, sent to the UI as text
	var/id
	/// Grouping key (see /obj/machinery/outpost_shop_stock/proc/listing_key())
	var/key
	var/name
	/// Icon file and state of the first unit, for the UI's DmIcon
	var/icon_file
	var/icon_state
	/// Stacks are priced and sold per unit
	var/is_stack = FALSE
	/// The largest stack of this type, and the most units one purchase may take
	var/max_stack = 1
	/// Credits per item, or per unit for stacks. 0 is not for sale.
	var/price = 0
	var/category_id = "0"
	/// Stocked atoms, oldest first. Walks skip nulls and deleted entries.
	var/list/obj/item/units = list()

/datum/outpost_shop_listing/Destroy()
	units = null
	return ..()

/// Drops deleted and nulled entries (a hard delete nulls list entries in place)
/datum/outpost_shop_listing/proc/prune()
	for(var/index in length(units) to 1 step -1)
		var/obj/item/unit = units[index]
		if(QDELETED(unit))
			units.Cut(index, index + 1)

/// Units for sale: the sum of stack amounts, or the number of items
/datum/outpost_shop_listing/proc/unit_count()
	. = 0
	for(var/obj/item/unit as anything in units)
		if(QDELETED(unit))
			continue
		if(is_stack)
			var/obj/item/stack/stack = unit
			. += stack.amount
		else
			.++

/// The unit that sells next
/datum/outpost_shop_listing/proc/next_unit()
	for(var/obj/item/unit as anything in units)
		if(!QDELETED(unit))
			return unit
	return null

/// The newest stack, which incoming stacks top up first
/datum/outpost_shop_listing/proc/newest_stack()
	if(!is_stack)
		return null
	for(var/index in length(units) to 1 step -1)
		var/obj/item/stack/stack = units[index]
		if(!QDELETED(stack))
			return stack
	return null

/obj/machinery/outpost_shop_stock
	name = "shop stock unit"
	desc = "A sealed stock cabinet for the outpost shop."
	icon = 'icons/obj/machines/smartfridge.dmi'
	icon_state = "smartfridge"
	base_icon_state = "smartfridge"
	layer = BELOW_OBJ_LAYER
	density = TRUE
	anchored = TRUE
	use_power = NO_POWER_USE
	circuit = null
	can_atmos_pass = ATMOS_PASS_NO
	interaction_flags_machine = INTERACT_MACHINE_OPEN | INTERACT_MACHINE_OFFLINE
	// Set before Initialize: an explosion must never reach the stock
	flags_1 = PREVENT_CONTENTS_EXPLOSION_1
	resistance_flags = INDESTRUCTIBLE | LAVA_PROOF | FIRE_PROOF | UNACIDABLE | ACID_PROOF
	/// Listing id -> listing, in the order they were made
	var/list/datum/outpost_shop_listing/listings_by_id = list()
	/// Grouping key -> listing
	var/list/datum/outpost_shop_listing/listing_by_key = list()
	/// Stocked item -> its listing
	var/list/listing_of = list()
	/// Category id -> name, in display order. "0" is Unsorted and always first.
	var/list/categories = list("0" = "Unsorted")
	var/next_listing_id = 1
	var/next_category_id = 1
	/// The insert path is moving something in; anything else that arrives is bounced
	var/receiving = FALSE
	/// A sale or eject is moving something out; anything else that leaves is logged
	var/releasing = FALSE
	/// Newest last: list("when", "buyer", "name", "qty", "total", "taken")
	var/list/sales_log = list()

/obj/machinery/outpost_shop_stock/Initialize(mapload)
	. = ..()
	ADD_TRAIT(src, TRAIT_BLOCKS_RECALL, INNATE_TRAIT)
	RegisterSignal(src, COMSIG_STORAGE_DUMP_CONTENT, PROC_REF(on_storage_dump))
	RegisterSignal(src, COMSIG_ATOM_INTERNAL_EXPLOSION, PROC_REF(contain_explosion))
	update_appearance()

/obj/machinery/outpost_shop_stock/Destroy()
	// The contents go with the machine (M4); their Exited() calls are not thefts
	releasing = TRUE
	. = ..()
	QDEL_LIST_ASSOC_VAL(listings_by_id)
	listing_by_key = null
	listing_of = null

/obj/machinery/outpost_shop_stock/update_overlays()
	. = ..()
	. += mutable_appearance(icon, "[base_icon_state]-glass")
	. += mutable_appearance(icon, "[base_icon_state]-powered")
	. += emissive_appearance(icon, "[base_icon_state]-light-mask", src, alpha = src.alpha)

/obj/machinery/outpost_shop_stock/examine(mob/user)
	. = ..()
	. += span_notice("Staff only.")

// ===== NOTHING GETS OUT BY FORCE =====

// No power, prying or deconstruction ever empties it
/obj/machinery/outpost_shop_stock/dump_contents()
	return

/obj/machinery/outpost_shop_stock/dump_inventory_contents(list/subset)
	return

/obj/machinery/outpost_shop_stock/singularity_act()
	return 0

/obj/machinery/outpost_shop_stock/singularity_pull(atom/singularity, current_size)
	return

/// An explosion that starts inside the stock unit never leaves it
/obj/machinery/outpost_shop_stock/proc/contain_explosion(datum/source, list/arguments)
	SIGNAL_HANDLER
	var/atom/origin = arguments?[EXARG_KEY_ORIGIN]
	log_bomber(null, "An explosion from [origin || "something"] was contained by", src)
	visible_message(span_warning("[src] shudders with a muffled thump."))
	return COMSIG_CANCEL_EXPLOSION

// ===== WHERE IT STANDS =====

/obj/machinery/outpost_shop_stock/proc/get_outpost()
	return get_outpost_from_atom(src)

/// The installed shop room, or null (an admin can delete it and leave the machine)
/obj/machinery/outpost_shop_stock/proc/get_shop()
	var/obj/structure/overmap/dynamic/player_outpost/home = get_outpost()
	var/datum/outpost_upgrade/service/shop/shop = home?.service_upgrade("shop")
	return istype(shop) ? shop : null

/// Owner and stewards, in their current bodies
/obj/machinery/outpost_shop_stock/proc/can_stock(mob/user)
	var/obj/structure/overmap/dynamic/player_outpost/home = get_outpost()
	return !!home?.is_current_management_user(user)

/// Owner, treasurers and pricers, in their current bodies
/obj/machinery/outpost_shop_stock/proc/can_price(mob/user)
	var/obj/structure/overmap/dynamic/player_outpost/home = get_outpost()
	return !!home?.is_current_pricing_user(user)

/// Null while the shop sells; else a short reason for both windows
/obj/machinery/outpost_shop_stock/proc/closed_reason()
	var/obj/structure/overmap/dynamic/player_outpost/home = get_outpost()
	if(!home)
		return "Not on an outpost."
	if(!home.founder_ckey)
		return "The outpost has no owner."
	var/datum/outpost_upgrade/service/shop/shop = get_shop()
	if(!shop || shop.stock_ref?.resolve() != src)
		return "Shop not installed."
	if(!shop.is_open)
		return "Closed."
	return null

// ===== LISTINGS =====

/// Null when `item` may go into stock, else why not
/obj/machinery/outpost_shop_stock/proc/refusal_reason(obj/item/item)
	if(!isitem(item) || QDELETED(item))
		return "Not an item."
	if((item.item_flags & (ABSTRACT | DROPDEL)) || (item.flags_1 & HOLOGRAM_1))
		return "That can't be stocked."
	if(item.w_class > WEIGHT_CLASS_HUGE)
		return "Too big for the stock unit."
	if(length(item.get_all_contents_type(/mob)))
		return "Living things can't be sold."
	if(item.GetID() || length(item.get_all_contents_type(/obj/item/card/id)))
		return "IDs can't be sold."
	// Containers only go in empty, or one listing would hide a bag of other goods
	if(item.atom_storage && length(item.atom_storage.real_location?.contents))
		return "Empty it first."
	if(istype(item, /obj/item/storage) && length(item.contents))
		return "Empty it first."
	if(istype(item, /obj/item/bodybag) && length(item.contents))
		return "Empty it first."
	if(istype(item, /obj/item/stack/trade_voucher) || istype(item, /obj/item/stack/spacecash) || istype(item, /obj/item/holochip))
		return "Money can't be sold."
	if(isstack(item))
		var/obj/item/stack/stack = item
		if(stack.max_amount == INFINITY)
			return "Money can't be sold."
	for(var/obj/item/inner as anything in item.get_all_contents_type(/obj/item))
		if(is_type_in_typecache(inner, GLOB.cryo_undeletable_items))
			return "Ship keys and contract goods can't be sold."
		if(istype(inner, /obj/item/grenade))
			var/obj/item/grenade/grenade = inner
			if(grenade.active)
				return "It's armed."
		// Anything a remote signal could set off after the sale, or while it sits in stock
		if(istype(inner, /obj/item/bombcore))
			return "That can't be sold here."
		if(istype(inner, /obj/item/tank))
			var/obj/item/tank/tank = inner
			if(tank.tank_assembly)
				return "Take the assembly off first."
		if(inner == item)
			continue
		if(istype(inner, /obj/item/assembly_holder))
			return "Take the assembly off first."
		if(istype(inner, /obj/item/assembly) && !istype(inner, /obj/item/assembly/flash) && !istype(inner.loc, /obj/item/assembly_holder))
			return "Take the assembly off first."
	if(item.get_temperature() > 0)
		return "Put it out first."
	if(istype(item, /obj/item/transfer_valve) || istype(item, /obj/item/disk/nuclear))
		return "That can't be sold here."
	return null

/**
 * The state part of a grouping key: units that differ inside (reagents, charge, ammo, damage)
 * never share a listing, so what Inspect shows is what sells.
 */
/obj/machinery/outpost_shop_stock/proc/state_signature(obj/item/item)
	var/list/state = list()
	if(item.reagents?.total_volume)
		var/list/mix = list()
		for(var/datum/reagent/reagent as anything in item.reagents.reagent_list)
			mix += "[reagent.type]=[round(reagent.volume, 0.1)]"
		state += "r:[jointext(sort_list(mix), ",")]"
	var/obj/item/stock_parts/power_store/cell = item.get_cell()
	if(istype(cell))
		state += "c:[round(cell.charge * 10 / max(cell.maxcharge, 1))]"
	if(istype(item, /obj/item/gun/ballistic))
		var/obj/item/gun/ballistic/gun = item
		state += "a:[gun.get_ammo()]"
	else if(istype(item, /obj/item/ammo_box/magazine))
		var/obj/item/ammo_box/magazine/magazine = item
		state += "a:[magazine.ammo_count(FALSE)]"
	else if(istype(item, /obj/item/ammo_box))
		var/obj/item/ammo_box/box = item
		state += "a:[length(box.stored_ammo)]"
	if(item.uses_integrity && item.atom_integrity < item.max_integrity)
		state += "dmg"
	// What is inside: a hypospray's vial, a grenade's beakers, a gun's magazine
	var/list/inner_parts = list()
	for(var/obj/item/inner as anything in item.get_all_contents_type(/obj/item) - item)
		var/list/inner_mix = list()
		for(var/datum/reagent/reagent as anything in inner.reagents?.reagent_list)
			inner_mix += "[reagent.type]=[round(reagent.volume, 0.1)]"
		inner_parts += "[inner.type]([jointext(sort_list(inner_mix), ",")])"
	if(length(inner_parts))
		state += "i:[jointext(sort_list(inner_parts), ",")]"
	return jointext(state, ";")

/// Items with the same key are interchangeable and share a listing
/obj/machinery/outpost_shop_stock/proc/listing_key(obj/item/item)
	var/list/parts = list("[item.type]", "[item.name]")
	if(isstack(item))
		var/obj/item/stack/stack = item
		parts += "m:[stack.merge_type]"
		if(length(stack.mats_per_unit))
			var/list/mats = list()
			for(var/material in stack.mats_per_unit)
				mats += "[isdatum(material) ? REF(material) : material]=[stack.mats_per_unit[material]]"
			parts += jointext(sort_list(mats), ",")
	parts += state_signature(item)
	return jointext(parts, "|")

/obj/machinery/outpost_shop_stock/proc/new_listing(obj/item/item, key)
	var/datum/outpost_shop_listing/listing = new
	listing.id = "[next_listing_id++]"
	listing.key = key
	listing.name = capitalize(format_text(item.name))
	listing.icon_file = "[item.icon]"
	listing.icon_state = item.icon_state
	if(isstack(item))
		var/obj/item/stack/stack = item
		listing.is_stack = TRUE
		listing.max_stack = stack.max_amount
	listings_by_id[listing.id] = listing
	listing_by_key[key] = listing
	return listing

/obj/machinery/outpost_shop_stock/proc/remove_listing(datum/outpost_shop_listing/listing)
	listings_by_id -= listing.id
	if(listing_by_key[listing.key] == listing)
		listing_by_key -= listing.key
	qdel(listing)

/obj/machinery/outpost_shop_stock/proc/track_unit(obj/item/item, datum/outpost_shop_listing/listing, oldest = FALSE)
	if(oldest)
		listing.units.Insert(1, item)
	else
		listing.units += item
	listing_of[item] = listing

/obj/machinery/outpost_shop_stock/proc/untrack_unit(obj/item/item, datum/outpost_shop_listing/listing)
	listing?.units -= item
	listing_of -= item

// ===== STOCKING =====

/**
 * Puts `item` into stock, from `user`'s hands, a storage (`from_storage`) or the floor. Stacks top
 * up the listing's newest stack first. Returns null when stocked, else a refusal.
 */
/obj/machinery/outpost_shop_stock/proc/stock_item(obj/item/item, mob/living/user, datum/storage/from_storage)
	if(!can_stock(user))
		return "Staff only."
	var/refusal = refusal_reason(item)
	if(refusal)
		return refusal
	if(item.loc == src)
		return "Already in stock."
	if(HAS_TRAIT(item, TRAIT_NODROP))
		return "It's stuck to you."
	var/key = listing_key(item)
	var/datum/outpost_shop_listing/listing = listing_by_key[key]
	if(!listing && length(listings_by_id) >= OUTPOST_SHOP_MAX_LISTINGS)
		return "Too many listings."
	var/item_name = item.name
	// Stacks never merge inside machines on their own (can_merge() refuses), so top up by hand
	if(listing?.is_stack)
		var/obj/item/stack/incoming = item
		var/obj/item/stack/newest = listing.newest_stack()
		if(newest && newest.amount < newest.max_amount)
			var/merged = incoming.merge(newest)
			if(merged)
				mark_dirty()
			if(QDELETED(incoming) || incoming.amount <= 0)
				log_game("PLAYER OUTPOST: [key_name(user)] stocked [merged] [item_name] in the shop at [AREACOORD(src)]")
				return null
	if(length(listing_of) >= OUTPOST_SHOP_MAX_ITEMS)
		return "The stock unit is full."
	var/made_listing = FALSE
	if(!listing)
		listing = new_listing(item, key)
		made_listing = TRUE
	receiving = TRUE
	if(from_storage)
		from_storage.attempt_remove(item, src, silent = TRUE)
	else if(ismob(item.loc))
		var/mob/holder = item.loc
		holder.transferItemToLoc(item, src)
	else
		item.forceMove(src)
	receiving = FALSE
	// forceMove's return is unreliable for held items: check where it went
	if(QDELETED(item) || item.loc != src)
		if(made_listing)
			remove_listing(listing)
		return "It won't go in."
	track_unit(item, listing)
	log_game("PLAYER OUTPOST: [key_name(user)] stocked [item_name] ([item.type]) in the shop at [AREACOORD(src)]")
	mark_dirty()
	return null

/// Stocks every acceptable loose item in a bag. Returns how many went in.
/obj/machinery/outpost_shop_stock/proc/stock_from_storage(datum/storage/storage, mob/living/user)
	if(!can_stock(user))
		balloon_alert(user, "management only!")
		return 0
	if(storage.locked)
		balloon_alert(user, "container locked!")
		return 0
	if(!user.CanReach(storage.parent) || !user.CanReach(src))
		return 0
	var/loaded = 0
	var/last_refusal
	for(var/obj/item/stored in storage.real_location.contents.Copy())
		if(length(listing_of) >= OUTPOST_SHOP_MAX_ITEMS)
			last_refusal = "The stock unit is full."
			break
		var/refusal = stock_item(stored, user, storage)
		if(refusal)
			last_refusal = refusal
			continue
		loaded++
	if(loaded)
		to_chat(user, span_notice("You stock [loaded] item\s from [storage.parent]."))
	else
		balloon_alert(user, LOWER_TEXT(last_refusal || "nothing to stock"))
	return loaded

/obj/machinery/outpost_shop_stock/proc/on_storage_dump(datum/source, datum/storage/storage, mob/user)
	SIGNAL_HANDLER
	INVOKE_ASYNC(src, PROC_REF(stock_from_storage), storage, user)
	return STORAGE_DUMP_HANDLED

/obj/machinery/outpost_shop_stock/item_interaction(mob/living/user, obj/item/tool, list/modifiers)
	if(user.combat_mode)
		return NONE
	if(!can_stock(user))
		balloon_alert(user, "management only!")
		return ITEM_INTERACT_BLOCKING
	if(tool.atom_storage && refusal_reason(tool))
		return stock_from_storage(tool.atom_storage, user) ? ITEM_INTERACT_SUCCESS : ITEM_INTERACT_BLOCKING
	var/refusal = stock_item(tool, user)
	if(refusal)
		balloon_alert(user, LOWER_TEXT(refusal))
		return ITEM_INTERACT_BLOCKING
	playsound(src, 'sound/machines/machine_vend.ogg', 30, TRUE, extrarange = -3)
	return ITEM_INTERACT_SUCCESS

// ===== TRACKING =====

// Only the insert path puts things in; anything else is pushed back out
/obj/machinery/outpost_shop_stock/Entered(atom/movable/arrived, atom/old_loc, list/atom/old_locs)
	. = ..()
	if(receiving || listing_of[arrived] || iseffect(arrived))
		return
	arrived.forceMove(drop_location())

/obj/machinery/outpost_shop_stock/Exited(atom/movable/gone, direction)
	. = ..()
	var/datum/outpost_shop_listing/listing = listing_of?[gone]
	if(!listing)
		return
	untrack_unit(gone, listing)
	if(!releasing)
		log_game("PLAYER OUTPOST: [gone] ([gone.type]) left the shop stock at [AREACOORD(src)] without a sale or eject[QDELETED(gone) ? " (deleted)" : ""]")
	mark_dirty()

// ===== TAKING STOCK OUT =====

/**
 * Takes up to `limit` atoms of a listing out to `user` (hands when adjacent, else the floor).
 * Returns how many atoms moved.
 */
/obj/machinery/outpost_shop_stock/proc/eject_listing(datum/outpost_shop_listing/listing, mob/living/user, limit)
	var/moved = 0
	var/adjacent = user && Adjacent(user)
	var/turf/floor = adjacent ? user.drop_location() : drop_location()
	for(var/obj/item/unit as anything in listing.units.Copy())
		if(moved >= limit)
			break
		if(QDELETED(unit) || unit.loc != src)
			continue
		releasing = TRUE
		unit.forceMove(floor)
		releasing = FALSE
		if(QDELETED(unit) || unit.loc != src)
			moved++
			if(adjacent && !QDELETED(unit) && unit.loc == floor)
				user.put_in_hands(unit)
	listing.prune()
	if(moved)
		log_game("PLAYER OUTPOST: [key_name(user)] ejected [moved] [listing.name] from the shop at [AREACOORD(src)]")
		mark_dirty()
	return moved

/**
 * Sells `quantity` units of `listing` to `buyer` at `register`. `shown_unit_price` is the price per
 * unit the buyer saw: 0 for staff who take stock free (R1), else the listed price. Never sleeps.
 *
 * Goods are staged in nullspace, paid for, then delivered. A refused payment puts them back, so
 * nothing ever reaches a hand or a turf (where stacks merge) before the money moves.
 * Returns null when sold, else a short refusal. Nothing moves on a refusal.
 */
/obj/machinery/outpost_shop_stock/proc/sell(datum/outpost_shop_listing/listing, quantity, shown_unit_price, mob/living/buyer, obj/machinery/computer/outpost_shop_register/register)
	var/closed = closed_reason()
	if(closed)
		return closed
	var/obj/structure/overmap/dynamic/player_outpost/home = get_outpost()
	if(!isliving(buyer) || buyer.stat == DEAD)
		return "No customer."
	if(QDELETED(register) || !register.Adjacent(buyer))
		return "Step up to the register."
	// The door decides who reaches the register (outpost_door_access.dm)
	var/member = home.is_outpost_member(buyer)
	if(!member && (get_crew_ship(buyer) in home.banned_ships))
		return "Your crew is banned here."
	if(QDELETED(listing) || listings_by_id[listing.id] != listing)
		return "That listing is gone."
	if(listing.price <= 0)
		return "Not for sale."
	var/taker = home.can_take_shop_stock(buyer)
	var/unit_price = taker ? 0 : listing.price
	if(!isnum(shown_unit_price) || shown_unit_price != unit_price)
		return "Price changed to [unit_price] cr."
	var/cap = listing.is_stack ? listing.max_stack : OUTPOST_SHOP_MAX_BUY
	if(!valid_cargo_order_quantity(quantity, cap))
		return "Invalid quantity."
	listing.prune()
	var/available = listing.unit_count()
	if(quantity > available)
		return available ? "Only [available] left." : "Sold out."
	var/total = unit_price * quantity
	if(total > OUTPOST_SHOP_MAX_TOTAL)
		return "That purchase is too large."
	var/datum/bank_account/account
	if(total > 0)
		account = buyer.get_idcard(TRUE)?.registered_account
		if(!account)
			return "No bank account on your ID."
		home.ensure_home_services()
		if(account == home.treasury)
			return "Payment declined."
		if(!account.has_money(total))
			return "Insufficient credits."

	var/list/goods = stage_units(listing, quantity)
	if(!goods)
		return "Stock error. Try again."
	var/label = "Shop: [quantity]x [listing.name]"
	if(total > 0)
		var/refusal = take_payment(buyer, account, total, label)
		if(refusal)
			restore_units(goods, listing)
			return refusal

	for(var/obj/item/good as anything in goods)
		if(QDELETED(good))
			continue
		// A marked item must not be recalled out of the buyer's hands and sold again. A mark on a
		// part (a cell, a magazine, a vial) would recall the whole item with it.
		for(var/obj/item/part as anything in good.get_all_contents_type(/obj/item))
			sever_magic_recall(part)
		if(!buyer.put_in_hands(good))
			good.forceMove(buyer.drop_location())
	record_sale(buyer, listing.name, quantity, total, taker)
	if(taker)
		log_game("PLAYER OUTPOST: [key_name(buyer)] took [quantity]x [listing.name] from the shop at '[home.name]' free")
	else
		log_game("PLAYER OUTPOST: [key_name(buyer)] bought [quantity]x [listing.name] for [total] cr from the shop at '[home.name]' ([account?.account_holder])")
	mark_dirty()
	return null

/**
 * Pays for a sale: `total` from `account` into the treasury. Returns null when paid, else a refusal.
 * The shared charge proc exempts every member; the shop charges every member but staff (R1), so
 * it moves the money here and books it through the shared receive_payment().
 */
/obj/machinery/outpost_shop_stock/proc/take_payment(mob/living/buyer, datum/bank_account/account, total, label)
	var/obj/structure/overmap/dynamic/player_outpost/home = get_outpost()
	if(!home || QDELETED(account))
		return "Payment failed."
	if(!account.has_money(total) || !account.adjust_money(-total, "[label] at [home.name]"))
		return "Insufficient credits."
	var/fee = round(total * OUTPOST_SHOP_SALE_FEE_PCT / 100)
	if(total - fee > 0)
		home.receive_payment(total - fee, OUTPOST_SERVICE_SHOP, label, buyer.real_name, account.account_holder)
	return null

/**
 * Takes exactly `quantity` units out of the machine into nullspace, splitting a stack when needed.
 * Returns list(item -> the stack it was split from, or null), or null with everything put back.
 */
/obj/machinery/outpost_shop_stock/proc/stage_units(datum/outpost_shop_listing/listing, quantity)
	var/list/staged = list()
	var/remaining = quantity
	releasing = TRUE
	for(var/obj/item/unit as anything in listing.units.Copy())
		if(remaining <= 0)
			break
		if(QDELETED(unit) || unit.loc != src)
			continue
		if(!listing.is_stack)
			unit.moveToNullspace()
			staged[unit] = null
			remaining--
			continue
		var/obj/item/stack/stack = unit
		if(stack.amount <= remaining)
			remaining -= stack.amount
			stack.moveToNullspace()
			staged[stack] = null
			continue
		var/obj/item/stack/part = stack.split_stack(remaining)
		if(!part)
			break
		staged[part] = stack
		remaining = 0
	releasing = FALSE
	var/intact = (remaining <= 0)
	for(var/obj/item/good as anything in staged)
		if(QDELETED(good) || good.loc)
			intact = FALSE
	if(!intact)
		restore_units(staged, listing)
		return null
	return staged

/// Puts staged goods back into stock, oldest first, merging split parts into the stacks they came from
/obj/machinery/outpost_shop_stock/proc/restore_units(list/staged, datum/outpost_shop_listing/listing)
	var/list/goods = list()
	for(var/obj/item/good as anything in staged)
		goods.Insert(1, good)
	for(var/obj/item/good as anything in goods)
		if(QDELETED(good))
			continue
		var/obj/item/stack/origin = staged[good]
		if(origin && !QDELETED(origin) && origin.loc == src)
			var/obj/item/stack/part = good
			part.merge(origin)
			if(QDELETED(part))
				continue
		receiving = TRUE
		good.forceMove(src)
		receiving = FALSE
		if(good.loc == src)
			if(QDELETED(listing) || listings_by_id[listing.id] != listing)
				var/key = listing_key(good)
				listing = listing_by_key[key] || new_listing(good, key)
			track_unit(good, listing, oldest = TRUE)
		else
			good.forceMove(drop_location())
	mark_dirty()

/obj/machinery/outpost_shop_stock/proc/record_sale(mob/living/buyer, item_name, quantity, total, taken)
	sales_log += list(list(
		"when" = station_time_timestamp("hh:mm"),
		"buyer" = buyer.real_name,
		"name" = item_name,
		"qty" = quantity,
		"total" = total,
		"taken" = !!taken,
	))
	if(length(sales_log) > OUTPOST_SHOP_SALES_LOG)
		sales_log.Cut(1, length(sales_log) - OUTPOST_SHOP_SALES_LOG + 1)

// ===== UI =====

/// Batches UI pushes: every change arms one flush for both windows
/obj/machinery/outpost_shop_stock/proc/mark_dirty()
	if(QDELETED(src))
		return
	addtimer(CALLBACK(src, PROC_REF(flush_ui)), OUTPOST_SHOP_UI_FLUSH, TIMER_UNIQUE)

/obj/machinery/outpost_shop_stock/proc/flush_ui()
	SStgui.update_uis(src)
	var/datum/outpost_upgrade/service/shop/shop = get_shop()
	var/obj/machinery/computer/outpost_shop_register/register = shop?.register_ref?.resolve()
	if(register)
		SStgui.update_uis(register)

/obj/machinery/outpost_shop_stock/proc/shop_title()
	var/obj/structure/overmap/dynamic/player_outpost/home = get_outpost()
	return home ? "[home.name] shop" : "Shop"

/obj/machinery/outpost_shop_stock/ui_state(mob/user)
	return GLOB.physical_state

/obj/machinery/outpost_shop_stock/ui_interact(mob/user, datum/tgui/ui)
	if(!isAdminGhostAI(user) && !can_stock(user) && !can_price(user))
		balloon_alert(user, "staff only!")
		return
	ui = SStgui.try_update_ui(user, src, ui)
	if(!ui)
		ui = new(user, src, "OutpostShopStock", name)
		ui.set_autoupdate(FALSE)
		ui.open()

/obj/machinery/outpost_shop_stock/ui_status(mob/user, datum/ui_state/state)
	. = ..()
	if(. <= UI_CLOSE || isAdminGhostAI(user))
		return
	if(!can_stock(user) && !can_price(user))
		return UI_CLOSE

/obj/machinery/outpost_shop_stock/ui_data(mob/user)
	var/datum/outpost_upgrade/service/shop/shop = get_shop()
	var/list/category_rows = list()
	for(var/category_id in categories)
		category_rows += list(list("id" = category_id, "name" = categories[category_id]))
	var/list/listing_rows = list()
	for(var/id in listings_by_id)
		var/datum/outpost_shop_listing/listing = listings_by_id[id]
		listing.prune()
		listing_rows += list(list(
			"id" = listing.id,
			"name" = listing.name,
			"category" = listing.category_id,
			"icon" = listing.icon_file,
			"icon_state" = listing.icon_state,
			"count" = length(listing.units),
			"units" = listing.unit_count(),
			"per_unit" = listing.is_stack,
			"price" = listing.price,
		))
	var/list/sale_rows = list()
	for(var/index in length(sales_log) to 1 step -1)
		sale_rows += list(sales_log[index])
	return list(
		"shop_name" = shop_title(),
		"open" = !!shop?.is_open,
		"can_stock" = can_stock(user),
		"can_price" = can_price(user),
		"category_limit" = OUTPOST_SHOP_MAX_CATEGORIES,
		"max_price" = OUTPOST_SHOP_MAX_PRICE,
		"categories" = category_rows,
		"listings" = listing_rows,
		"sales" = sale_rows,
	)

/// The listings a UI action names, or null when the list is malformed
/obj/machinery/outpost_shop_stock/proc/listings_from_ids(list/ids)
	if(!islist(ids) || !length(ids) || length(ids) > OUTPOST_SHOP_MAX_LISTINGS)
		return null
	var/list/found = list()
	for(var/id in ids)
		// Decoded JSON: a number would index the list by position
		if(!istext(id))
			return null
		var/datum/outpost_shop_listing/listing = listings_by_id[id]
		if(listing)
			found |= listing
	return found

/obj/machinery/outpost_shop_stock/proc/clean_category_name(name)
	if(!istext(name))
		return null
	name = trim(copytext(sanitize(name), 1, OUTPOST_SHOP_CATEGORY_NAME_LEN))
	return length(name) ? name : null

/obj/machinery/outpost_shop_stock/ui_act(action, list/params, datum/tgui/ui, datum/ui_state/state)
	. = ..()
	if(.)
		return
	var/mob/living/user = ui.user
	var/refusal = owner_action(user, action, params)
	if(refusal)
		balloon_alert(user, LOWER_TEXT(refusal))
	mark_dirty()
	return TRUE

/// One owner window action. Returns null when done, else a refusal.
/obj/machinery/outpost_shop_stock/proc/owner_action(mob/living/user, action, list/params)
	var/stocker = can_stock(user)
	var/pricer = can_price(user)
	if(!stocker && !pricer)
		return "Staff only."
	switch(action)
		if("insert_held")
			if(!stocker)
				return "Staff only."
			var/obj/item/held = user.get_active_held_item()
			if(!held)
				return "Hold something to stock it."
			if(held.atom_storage && refusal_reason(held))
				return stock_from_storage(held.atom_storage, user) ? null : "Nothing in it can be stocked."
			return stock_item(held, user)
		if("toggle_open")
			var/datum/outpost_upgrade/service/shop/shop = get_shop()
			if(!shop)
				return "Shop not installed."
			return shop.set_open(user, !shop.is_open)

	// Everything below is for pricing users
	if(!pricer)
		return "Not authorised."
	switch(action)
		if("set_price")
			var/list/chosen = listings_from_ids(params["ids"])
			if(!chosen)
				return "Invalid selection."
			var/price = params["price"]
			if(!isnum(price) || isnan(price))
				return "Invalid price."
			price = round(price, 1)
			if(price < 1 || price > OUTPOST_SHOP_MAX_PRICE)
				return "Prices run from 1 to [OUTPOST_SHOP_MAX_PRICE] cr."
			for(var/datum/outpost_shop_listing/listing as anything in chosen)
				listing.price = price
			log_game("PLAYER OUTPOST: [key_name(user)] priced [length(chosen)] shop listing\s at [price] cr at [AREACOORD(src)]")
			return null
		if("unlist")
			var/list/chosen = listings_from_ids(params["ids"])
			if(!chosen)
				return "Invalid selection."
			for(var/datum/outpost_shop_listing/listing as anything in chosen)
				listing.price = 0
			log_game("PLAYER OUTPOST: [key_name(user)] took [length(chosen)] shop listing\s off sale at [AREACOORD(src)]")
			return null
		if("move")
			var/list/chosen = listings_from_ids(params["ids"])
			var/category_id = params["category"]
			if(!chosen)
				return "Invalid selection."
			if(!istext(category_id) || !categories[category_id])
				return "Unknown category."
			for(var/datum/outpost_shop_listing/listing as anything in chosen)
				listing.category_id = category_id
			return null
		if("eject")
			var/list/chosen = listings_from_ids(params["ids"])
			if(!chosen)
				return "Invalid selection."
			var/budget = OUTPOST_SHOP_EJECT_LIMIT
			for(var/datum/outpost_shop_listing/listing as anything in chosen)
				if(budget <= 0)
					break
				budget -= eject_listing(listing, user, budget)
			if(budget == OUTPOST_SHOP_EJECT_LIMIT)
				return "Nothing to take out."
			playsound(src, 'sound/machines/machine_vend.ogg', 30, TRUE, extrarange = -3)
			return null
		if("forget")
			var/list/chosen = listings_from_ids(params["ids"])
			if(!chosen)
				return "Invalid selection."
			var/forgotten = 0
			for(var/datum/outpost_shop_listing/listing as anything in chosen)
				listing.prune()
				if(length(listing.units))
					continue
				remove_listing(listing)
				forgotten++
			return forgotten ? null : "Not empty."
		if("add_category")
			if(length(categories) - 1 >= OUTPOST_SHOP_MAX_CATEGORIES)
				return "Too many categories."
			var/category_name = clean_category_name(params["name"])
			if(!category_name)
				return "Invalid name."
			categories["c[next_category_id++]"] = category_name
			return null
		if("rename_category")
			var/category_id = params["id"]
			if(!istext(category_id) || category_id == "0" || !categories[category_id])
				return "Unknown category."
			var/category_name = clean_category_name(params["name"])
			if(!category_name)
				return "Invalid name."
			categories[category_id] = category_name
			return null
		if("delete_category")
			var/category_id = params["id"]
			if(!istext(category_id) || category_id == "0" || !categories[category_id])
				return "Unknown category."
			categories -= category_id
			for(var/id in listings_by_id)
				var/datum/outpost_shop_listing/listing = listings_by_id[id]
				if(listing.category_id == category_id)
					listing.category_id = "0"
			return null
		if("move_category")
			var/category_id = params["id"]
			var/index = params["index"]
			if(!istext(category_id) || category_id == "0" || !categories[category_id])
				return "Unknown category."
			if(!isnum(index) || isnan(index))
				return "Invalid position."
			var/list/order = list()
			for(var/other_id in categories)
				if(other_id != "0" && other_id != category_id)
					order += other_id
			index = clamp(round(index, 1), 1, length(order) + 1)
			order.Insert(index, category_id)
			var/list/reordered = list("0" = categories["0"])
			for(var/other_id in order)
				reordered[other_id] = categories[other_id]
			categories = reordered
			return null
	return "Unknown action."

/**
 * The buyer window's data (OutpostShop, hosted by the register). Per viewer only in the wallet and
 * the free-take flag; the listings are the same for everyone.
 */
/obj/machinery/outpost_shop_stock/proc/buyer_ui_data(mob/user)
	var/obj/structure/overmap/dynamic/player_outpost/home = get_outpost()
	var/closed = closed_reason()
	var/taker = !!home?.can_take_shop_stock(user)
	var/mob/living/viewer = isliving(user) ? user : null
	var/datum/bank_account/account = viewer?.get_idcard(TRUE)?.registered_account
	var/list/category_rows = list()
	var/list/listing_rows = list()
	if(!closed)
		var/list/used_categories = list()
		for(var/id in listings_by_id)
			var/datum/outpost_shop_listing/listing = listings_by_id[id]
			if(listing.price <= 0)
				continue
			used_categories[listing.category_id] = TRUE
			listing_rows += list(list(
				"id" = listing.id,
				"name" = listing.name,
				"category" = listing.category_id,
				"icon" = listing.icon_file,
				"icon_state" = listing.icon_state,
				"price" = taker ? 0 : listing.price,
				"per_unit" = listing.is_stack,
				"available" = listing.unit_count(),
				"max_per_buy" = listing.is_stack ? listing.max_stack : OUTPOST_SHOP_MAX_BUY,
			))
		for(var/category_id in categories)
			if(used_categories[category_id])
				category_rows += list(list("id" = category_id, "name" = categories[category_id]))
	return list(
		"shop_name" = shop_title(),
		"open" = !closed,
		"closed_reason" = closed,
		"free_take" = taker,
		"account_credits" = account?.account_balance,
		"confirm_total" = OUTPOST_SHOP_CONFIRM_TOTAL,
		"categories" = category_rows,
		"listings" = listing_rows,
	)

/// What Inspect shows: the examine text of the unit that sells next
/obj/machinery/outpost_shop_stock/proc/inspect_listing(datum/outpost_shop_listing/listing, mob/user)
	var/obj/item/unit = listing?.next_unit()
	if(!unit)
		return FALSE
	var/list/lines = unit.examine(user)
	to_chat(user, boxed_message(jointext(lines, "\n")))
	return TRUE
