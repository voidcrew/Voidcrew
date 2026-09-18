/obj/machinery/computer/order_console/mining
	// VOIDCREW EDIT ADDITION - ui_static_data quotes wares at cargo_cost_multiplier (0.65) while
	// purchase_items charges express_cost_multiplier (1), and this console forces express, so every
	// listed price was 35% under what you paid. Equalising them makes the listed price the charged one.
	cargo_cost_multiplier = 1
	purchase_tooltip = @{"Your purchases will arrive at cargo,
	and hopefully get delivered by them."}

/obj/machinery/computer/order_console/mining/Initialize(mapload)
	forced_express = TRUE
	return ..()
