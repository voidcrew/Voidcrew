/// Settle a ship order atomically before generating any goods or changing market stock.
/datum/supply_order/proc/settle_ship_order(datum/bank_account/account)
	ship_settlement_error = null
	if(!account || !isnull(ship_paid_cost))
		ship_settlement_error = "No paying account, or order already paid."
		return FALSE
	var/datum/supply_pack/custom/minerals/material_order = astype(pack)
	if(material_order)
		ship_settlement_error = material_order.ship_order_error()
		if(ship_settlement_error)
			return FALSE
	var/price = get_final_cost()
	if(!isnum(price) || price < 0)
		ship_settlement_error = "Invalid order price."
		return FALSE
	// adjust_money(0) reports failure, although a fully discounted order is valid.
	if(price > 0 && !account.adjust_money(-price))
		ship_settlement_error = "Insufficient credits; order remains in the cart."
		return FALSE
	ship_paid_cost = price
	material_order?.commit_ship_order()
	return TRUE

/// Cargo amounts arrive from a client; fractional, negative and unbounded orders are invalid.
/proc/valid_cargo_order_quantity(quantity, maximum)
	return isnum(quantity) && quantity >= 1 && quantity <= maximum && quantity == round(quantity)

/// A material order may contain at most ten physical stacks across all its materials.
/proc/valid_material_order_contents(list/ordered_materials)
	if(!length(ordered_materials))
		return FALSE
	var/stack_count = 0
	for(var/obj/item/stack/sheet/sheet_type as anything in ordered_materials)
		if(!ispath(sheet_type, /obj/item/stack/sheet))
			return FALSE
		var/quantity = ordered_materials[sheet_type]
		if(!valid_cargo_order_quantity(quantity, MAX_STACK_SIZE * 10))
			return FALSE
		if(!(initial(sheet_type.material_type) in SSstock_market.materials_prices))
			return FALSE
		stack_count += CEILING(quantity / MAX_STACK_SIZE, 1)
	return stack_count <= 10

/// Ship orders retain their pooled quote: either every requested sheet ships, or none does.
/datum/supply_pack/custom/minerals/proc/ship_order_error()
	if(!valid_material_order_contents(contains))
		return "Invalid material order quantities."
	for(var/obj/item/stack/sheet/sheet_type as anything in contains)
		if(contains[sheet_type] > SSstock_market.materials_quantity[initial(sheet_type.material_type)])
			return "Insufficient [initial(sheet_type.singular_name)] on the market; the whole order remains in the cart."
	return null

/// Called only after preflight and successful ship payment, without yielding in between.
/datum/supply_pack/custom/minerals/proc/commit_ship_order()
	for(var/obj/item/stack/sheet/sheet_type as anything in contains)
		SSstock_market.adjust_material_quantity(initial(sheet_type.material_type), -contains[sheet_type])
	// Independent market trends still move prices. An import must not raise its own
	// immediate resale price above the quote the buyer just paid.
