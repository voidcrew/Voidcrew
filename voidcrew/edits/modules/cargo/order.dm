// Voidcrew extensions to code/modules/cargo/order.dm.

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

/datum/supply_order
	/// Actual ship-account payment, also used by its manifest. Null until settled.
	var/ship_paid_cost
	/// Last refusal from ship settlement, for delivery feedback.
	var/ship_settlement_error
