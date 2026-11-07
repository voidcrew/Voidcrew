/// Stamp the delivery and its original contents, never later additions or crafted products.
/proc/mark_trader_goods(atom/movable/goods)
	if(QDELETED(goods))
		return
	ADD_TRAIT(goods, TRAIT_TRADER_GOODS, INNATE_TRAIT)
	// Closets defer their stock until first opening. Roll it here before handing it over.
	if(istype(goods, /obj/structure/closet))
		var/obj/structure/closet/container = goods
		if(!container.contents_initialized)
			container.contents_initialized = TRUE
			container.PopulateContents()
			SEND_SIGNAL(container, COMSIG_CLOSET_CONTENTS_INITIALIZED)
	for(var/atom/movable/inside in goods.contents)
		mark_trader_goods(inside)

/proc/is_trader_good(atom/goods)
	return goods && HAS_TRAIT(goods, TRAIT_TRADER_GOODS)

/// Stamp stacks before any automatic merge, including every stack in an oversized delivery.
/proc/create_trader_goods(item_type, atom/location, amount = 1)
	if(!ispath(item_type, /obj/item/stack))
		var/atom/movable/goods = new item_type(location)
		mark_trader_goods(goods)
		return goods
	var/obj/item/stack/stack_type = item_type
	var/remaining = amount > 1 ? amount : initial(stack_type.amount)
	while(remaining > 0)
		var/quantity = min(remaining, initial(stack_type.max_amount))
		var/obj/item/stack/goods = new item_type(location, quantity, FALSE)
		mark_trader_goods(goods)
		if(!.)
			. = goods
		remaining -= quantity

/datum/export/applies_to(obj/exported_item, apply_elastic = TRUE, export_market)
	if(is_trader_good(exported_item))
		return FALSE
	return ..()

// The materials market has its own ask floor; point-shop deliveries retain their resale stamp.
/datum/supply_pack/proc/is_order_console_delivery()
	return (istype(src, /datum/supply_pack/custom) && !istype(src, /datum/supply_pack/custom/minerals)) || istype(src, /datum/supply_pack/bitrunning)

/datum/supply_pack/generate(atom/A, datum/bank_account/paying_account)
	. = ..()
	if(is_order_console_delivery())
		mark_trader_goods(.)

// The manifest is generated after the pack's goods.
/datum/supply_order/generate(atom/A)
	. = ..()
	if(pack.is_order_console_delivery())
		mark_trader_goods(.)

// Shipping calls this after the market entry has finished assembling its bundle.
/datum/market_purchase/post_purchase_effects(atom/spawned_item)
	. = ..()
	mark_trader_goods(spawned_item)

/obj/item/stack/split_stack(amount)
	var/was_trader_good = is_trader_good(src)
	. = ..()
	if(was_trader_good && .)
		mark_trader_goods(.)

/obj/item/stack/merge_without_del(obj/item/stack/target_stack, limit)
	var/was_trader_good = is_trader_good(src)
	. = ..()
	if(. > 0 && was_trader_good)
		mark_trader_goods(target_stack)

// Limbgrowers print the same organic types as natural donors. Capture only this synchronous build's output.
/obj/machinery/limbgrower/build_item(list/modified_consumed_reagents_list)
	var/atom/output_location = loc
	var/list/previous_contents = output_location.contents.Copy()
	. = ..()
	for(var/obj/item/organ/printed in output_location.contents - previous_contents)
		ADD_TRAIT(printed, TRAIT_PRINTED_ORGAN, INNATE_TRAIT)
