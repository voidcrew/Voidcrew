/**
 * Computer
 */
/obj/machinery/computer/voidcrew_cargo
	name = "cargo console"
	desc = "Used to call and send freight from a ship."
	icon_screen = "supply"
	circuit = /obj/item/circuitboard/computer/voidcrew_cargo
	light_color = COLOR_BRIGHT_ORANGE

	///The machine we're connected to that holds our bank account.
	var/obj/machinery/computer/bank_machine/bank_account_holder

	///List of everything we're attempting to purchase.
	var/list/datum/supply_order/checkout_list = list()

	/// Whether contraband packs are available (set by emagging)
	var/contraband = FALSE

	/// Loaded coupons that can be applied to orders
	var/list/obj/item/coupon/loaded_coupons

/obj/machinery/computer/voidcrew_cargo/Destroy()
	if(bank_account_holder)
		on_bank_deletion(bank_account_holder)
	QDEL_LIST(checkout_list)
	QDEL_LAZYLIST(loaded_coupons)
	return ..()

/obj/machinery/computer/voidcrew_cargo/on_construction(mob/user)
	. = ..()
	var/obj/item/circuitboard/computer/voidcrew_cargo/board = circuit
	if(board?.contraband)
		contraband = TRUE
		obj_flags |= EMAGGED

/**
 * Gets the cargo shuttle for this console's ship
 * All consoles on the same ship share the same shuttle
 */
/obj/machinery/computer/voidcrew_cargo/proc/get_cargo_shuttle()
	var/obj/structure/overmap/ship/ship = get_ship_from_atom(src)
	if(!ship)
		return null
	return ship.get_cargo_shuttle()

/obj/machinery/computer/voidcrew_cargo/multitool_act(mob/living/user, obj/item/multitool/tool)
	if(QDELETED(tool.buffer) || !istype(tool.buffer, /obj/machinery/computer/bank_machine))
		return
	bank_account_holder = tool.buffer
	RegisterSignal(tool.buffer, COMSIG_QDELETING, PROC_REF(on_bank_deletion))
	playsound(user, 'sound/machines/ding.ogg', 40, TRUE)
	balloon_alert_to_viewers("new account synced")
	return TRUE

/obj/machinery/computer/voidcrew_cargo/emag_act(mob/user, obj/item/card/emag/emag_card)
	if(obj_flags & EMAGGED)
		return FALSE
	if(user)
		if(emag_card)
			user.visible_message(span_warning("[user] swipes [emag_card] through [src]!"))
		to_chat(user, span_notice("You adjust [src]'s routing and receiver spectrum, unlocking special supplies and contraband."))
	obj_flags |= EMAGGED
	contraband = TRUE
	// Also set on circuit board so it persists through deconstruction
	var/obj/item/circuitboard/computer/voidcrew_cargo/board = circuit
	if(board)
		board.contraband = TRUE
		board.obj_flags |= EMAGGED
	update_static_data(user)
	return TRUE

/obj/machinery/computer/voidcrew_cargo/item_interaction(mob/living/user, obj/item/tool, list/modifiers)
	// Handle trade chips
	if(istype(tool, /obj/item/trade_chip))
		var/obj/item/trade_chip/contract = tool
		contract.try_to_unlock_contract(user)
		return ITEM_INTERACT_SUCCESS
	// Handle coupons
	if(istype(tool, /obj/item/coupon))
		var/obj/item/coupon/coupon = tool
		coupon.inserted_console = src
		LAZYADD(loaded_coupons, coupon)
		say("Coupon for [initial(coupon.discounted_pack.name)] applied!")
		coupon.forceMove(src)
		return ITEM_INTERACT_SUCCESS
	return ..()

/obj/machinery/computer/voidcrew_cargo/Exited(atom/movable/gone, direction)
	. = ..()
	if(istype(gone, /obj/item/coupon))
		LAZYREMOVE(loaded_coupons, gone)

/obj/machinery/computer/voidcrew_cargo/proc/on_bank_deletion(atom/source)
	SIGNAL_HANDLER
	UnregisterSignal(source, COMSIG_QDELETING)
	bank_account_holder = null

/obj/machinery/computer/voidcrew_cargo/ui_interact(mob/user, datum/tgui/ui)
	. = ..()
	ui = SStgui.try_update_ui(user, src, ui)
	if(!ui)
		ui = new(user, src, "VoidcrewCargo", name)
		ui.open()

/obj/machinery/computer/voidcrew_cargo/ui_static_data(mob/user)
	var/list/data = list()
	data["max_order"] = CARGO_MAX_ORDER
	return data

/**
 * Returns a list of supply packs for a certain group
 */
/obj/machinery/computer/voidcrew_cargo/proc/get_packs_data(group)
	var/list/packs = list()
	for(var/pack_id in SSshuttle.supply_packs)
		var/datum/supply_pack/pack = SSshuttle.supply_packs[pack_id]
		if(pack.group != group)
			continue
		if((pack.hidden && !(obj_flags & EMAGGED)) || (pack.special && !pack.special_enabled) || pack.drop_pod_only)
			continue
		if(pack.contraband && !contraband)
			continue
		var/obj/item/first_item = length(pack.contains) > 0 ? pack.contains[1] : null
		packs += list(list(
			"name" = pack.name,
			"cost" = pack.get_cost(),
			"id" = pack_id,
			"desc" = pack.desc || pack.name,
			"first_item_icon" = first_item?.icon,
			"first_item_icon_state" = first_item?.icon_state,
			"goody" = pack.goody,
			"access" = pack.access,
			"contraband" = pack.contraband,
			"small_item" = FALSE,
			"contains" = pack.get_contents_ui_data(),
		))
	return packs

/obj/machinery/computer/voidcrew_cargo/ui_data(mob/user)
	var/list/data = list()

	// Build supplies list (in ui_data to ensure SSshuttle is initialized)
	data["supplies"] = list()
	for(var/pack_id in SSshuttle.supply_packs)
		var/datum/supply_pack/pack = SSshuttle.supply_packs[pack_id]
		if(!data["supplies"][pack.group])
			data["supplies"][pack.group] = list(
				"name" = pack.group,
				"packs" = get_packs_data(pack.group),
			)

	data["has_bank_account"] = !!bank_account_holder
	if(!bank_account_holder?.synced_bank_account)
		data["shuttle_error"] = "NO BANK ACCOUNT CONNECTED"
		return data

	data["points"] = bank_account_holder.synced_bank_account.account_balance

	// CargoCatalog compatibility - we don't use private buying for voidcrew
	data["self_paid"] = FALSE
	data["app_cost"] = FALSE

	// Track amounts in cart by name for max_order checking
	var/list/amount_by_name = list()
	for(var/datum/supply_order/order as anything in checkout_list)
		amount_by_name[order.pack.name] = (amount_by_name[order.pack.name] || 0) + 1
	data["amount_by_name"] = amount_by_name

	// Shuttle status
	var/datum/voidcrew_cargo_shuttle/cargo_shuttle = get_cargo_shuttle()
	var/shuttle_state = cargo_shuttle?.state || CARGO_SHUTTLE_AWAY
	data["shuttle_state"] = shuttle_state
	data["shuttle_timer"] = cargo_shuttle?.get_remaining_time() || 0
	data["can_call_shuttle"] = can_call_cargo_shuttle()
	data["shuttle_error"] = get_shuttle_error_message()

	// Transaction history
	data["history"] = cargo_shuttle?.transaction_history || list()

	// Shuttle loan offers
	if(cargo_shuttle?.pending_loan)
		var/datum/voidcrew_shuttle_loan/loan = cargo_shuttle.pending_loan
		data["loan"] = list(
			"sender" = loan.sender,
			"announcement" = loan.announcement_text,
			"bonus_credits" = loan.bonus_credits,
			"accepted" = cargo_shuttle.loan_accepted,
		)
	else
		data["loan"] = null

	// Shuttle state text for UI
	switch(shuttle_state)
		if(CARGO_SHUTTLE_AWAY)
			data["shuttle_status"] = "Away"
		if(CARGO_SHUTTLE_ARRIVING)
			data["shuttle_status"] = "Arriving"
		if(CARGO_SHUTTLE_DOCKED)
			data["shuttle_status"] = "Docked"
		if(CARGO_SHUTTLE_DEPARTING)
			data["shuttle_status"] = "Departing"

	var/cart_list = list()
	for(var/datum/supply_order/order as anything in checkout_list)
		if(cart_list[order.pack.name])
			cart_list[order.pack.name][1]["amount"]++
			cart_list[order.pack.name][1]["cost"] += order.get_final_cost()
			if(order.department_destination)
				cart_list[order.pack.name][1]["dep_order"]++
			if(!isnull(order.paying_account))
				cart_list[order.pack.name][1]["paid"]++
			continue

		cart_list[order.pack.name] = list(list(
			"cost_type" = order.cost_type,
			"object" = order.pack.name,
			"cost" = order.get_final_cost(),
			"id" = order.id,
			"amount" = 1,
			"orderer" = order.orderer,
			"paid" = !isnull(order.paying_account) ? 1 : 0, //number of orders purchased privatly
			"dep_order" = order.department_destination ? 1 : 0, //number of orders purchased by a department
			"can_be_cancelled" = order.can_be_cancelled,
		))
	data["cart"] = list()
	for(var/item_id in cart_list)
		data["cart"] += cart_list[item_id]

	return data

/**
 * Check if the cargo shuttle can be called
 */
/obj/machinery/computer/voidcrew_cargo/proc/can_call_cargo_shuttle()
	var/obj/structure/overmap/ship/ship = get_ship_from_atom(src)
	if(!ship)
		return FALSE
	if(!istype(ship.docked, /obj/structure/overmap/planet/empty))
		return FALSE
	if(ship.state != OVERMAP_SHIP_IDLE)
		return FALSE
	return TRUE

/**
 * Get error message for shuttle restrictions
 */
/obj/machinery/computer/voidcrew_cargo/proc/get_shuttle_error_message()
	var/obj/structure/overmap/ship/ship = get_ship_from_atom(src)
	if(!ship)
		return "Not on a registered ship"
	// Check location first - more meaningful error when in hyperspace
	if(!istype(ship.docked, /obj/structure/overmap/planet/empty))
		return "Must be docked in space"
	if(ship.state != OVERMAP_SHIP_IDLE)
		return "Ship cannot be moving"
	return null

/**
 * Calculate total cost of all items in the checkout cart
 */
/obj/machinery/computer/voidcrew_cargo/proc/get_cart_total()
	var/total = 0
	for(var/datum/supply_order/order as anything in checkout_list)
		total += order.get_final_cost()
	return total

/obj/machinery/computer/voidcrew_cargo/ui_act(action, params, datum/tgui/ui)
	. = ..()
	if(.)
		return
	if(!bank_account_holder?.synced_bank_account)
		balloon_alert(usr, "no bank account connected.")
		usr.playsound_local(src, 'sound/machines/buzz/buzz-sigh.ogg', 50, TRUE, -1)
		return

	switch(action)
		/**
		 * CARGO ORDERING
		 */
		if("add")
			return add_item(params)
		if("add_by_name")
			var/supply_pack_id = name_to_id(params["order_name"])
			if(!supply_pack_id)
				return
			return add_item(list("id" = supply_pack_id, "amount" = 1))
		if("remove")
			var/order_name = params["order_name"]
			for(var/datum/supply_order/order as anything in checkout_list)
				if(order.pack.name != order_name)
					continue
				if(remove_item(list("id" = order.id)))
					return TRUE

			return TRUE
		if("modify")
			var/order_name = params["order_name"]
			//clear out all orders with the above mentioned order_name name to make space for the new amount
			for(var/datum/supply_order/order as anything in checkout_list) //find corresponding order id for the order name
				if(order.pack.name == order_name)
					remove_item(list("id" = "[order.id]"))

			//now add the new amount stuff
			var/amount = text2num(params["amount"])
			if(!amount)
				return TRUE
			var/supply_pack_id = name_to_id(order_name) //map order name to supply pack id for adding
			if(!supply_pack_id)
				return FALSE
			return add_item(list("id" = supply_pack_id, "amount" = amount))
		if("clear")
			//create copy of list else we will get runtimes when iterating & removing items on the same list checkout_list
			for(var/datum/supply_order/cancelled_order as anything in checkout_list)
				if(!cancelled_order.can_be_cancelled)
					continue //don't cancel other department's orders or orders that can't be cancelled
				if(remove_item(list("id" = "[cancelled_order.id]")))
					return TRUE
			return TRUE
		if("toggleprivate")
			// Not used for voidcrew cargo - all purchases use ship's bank account
			return TRUE

		/**
		 * SHUTTLE LOAN HANDLING
		 */
		if("accept_loan")
			var/datum/voidcrew_cargo_shuttle/cargo_shuttle = get_cargo_shuttle()
			if(!cargo_shuttle?.pending_loan)
				say("No loan offer available.")
				return TRUE
			if(cargo_shuttle.accept_loan())
				say("Loan offer accepted. Your shuttle will bring the cargo on its next arrival.")
			else
				say("Error: Could not accept loan offer.")
			return TRUE

		if("decline_loan")
			var/datum/voidcrew_cargo_shuttle/cargo_shuttle = get_cargo_shuttle()
			if(!cargo_shuttle?.pending_loan)
				return TRUE
			cargo_shuttle.decline_loan()
			say("Loan offer declined.")
			return TRUE

		/**
		 * CARGO SHUTTLE HANDLING
		 */
		if("send")
			var/obj/structure/overmap/ship/ship = get_ship_from_atom(src)

			if(!can_call_cargo_shuttle())
				say("Error: [get_shuttle_error_message()]")
				usr.playsound_local(src, 'sound/machines/buzz/buzz-sigh.ogg', 50, TRUE, -1)
				return TRUE

			// Get shuttle from ship (shared between all consoles on the ship)
			var/datum/voidcrew_cargo_shuttle/cargo_shuttle = get_cargo_shuttle()
			if(!cargo_shuttle)
				say("Error: Could not access cargo shuttle system.")
				return TRUE

			// Set linked console for callbacks
			cargo_shuttle.linked_console = src

			switch(cargo_shuttle.state)
				if(CARGO_SHUTTLE_AWAY)
					// Call the shuttle with our orders (allow empty cart if loan accepted)
					if(!length(checkout_list) && !cargo_shuttle.loan_accepted)
						say("Error: No orders in cart.")
						return TRUE

					// Check if we have enough credits for the order
					var/total_cost = get_cart_total()
					var/available = bank_account_holder.synced_bank_account.account_balance
					if(total_cost > available)
						say("Error: Insufficient credits. Need [total_cost], have [available].")
						return TRUE

					// Call the shuttle - buy() will be called after successful docking
					if(cargo_shuttle.call_shuttle(ship))
						say("Cargo shuttle called. ETA 30 seconds.")
						usr.investigate_log("called the [bank_account_holder.synced_bank_account.account_holder] cargo shuttle.", INVESTIGATE_CARGO)
					else
						say("Error: Could not call cargo shuttle.")

				if(CARGO_SHUTTLE_DOCKED)
					// Check for living mobs before sending
					if(cargo_shuttle.has_living_mobs())
						say("Error: Living organic(s) detected on cargo shuttle. Clear the shuttle before departure.")
						return TRUE
					// Send shuttle away
					if(cargo_shuttle.send_shuttle())
						say("Cargo shuttle departing. Exports will be processed shortly.")
						usr.investigate_log("sent the [bank_account_holder.synced_bank_account.account_holder] cargo shuttle away.", INVESTIGATE_CARGO)
					else
						say("Error: Could not send cargo shuttle.")

				if(CARGO_SHUTTLE_ARRIVING)
					say("Cargo shuttle is currently arriving. Please wait.")

				if(CARGO_SHUTTLE_DEPARTING)
					say("Cargo shuttle is currently departing. Please wait.")

			return TRUE

/**
 * Prints a requisition form for the current orders
 */
/obj/machinery/computer/voidcrew_cargo/proc/print_requisition_form()
	if(!length(checkout_list))
		return

	var/list/cart_list = list()
	for(var/datum/supply_order/order as anything in checkout_list)
		if(cart_list[order.pack.name])
			cart_list[order.pack.name]["amount"]++
			continue
		cart_list[order.pack.name] = list(
			"order" = order,
			"amount" = 1,
		)

	var/obj/item/paper/requisition_paper = new(get_turf(src))
	requisition_paper.name = "requisition form"
	var/requisition_text = "<h2>[station_name()] Supply Requisition</h2>"
	requisition_text += "<hr/>"
	requisition_text += "Time of Order: [station_time_timestamp()]<br/>"
	for(var/order_name in cart_list)
		var/datum/supply_order/order = cart_list[order_name]["order"]
		requisition_text += "[cart_list[order_name]["amount"]] [order.pack.name]("
		requisition_text += "Access Restrictions: [SSid_access.get_access_desc(order.pack.access)])</br>"
	requisition_paper.add_raw_text(requisition_text)
	requisition_paper.update_appearance()

/**
 * Adds an item to the grocery list
 */
/obj/machinery/computer/voidcrew_cargo/proc/add_item(params)
	var/id = params["id"]
	id = text2path(id) || id
	var/datum/supply_pack/pack = SSshuttle.supply_packs[id]
	if(!istype(pack))
		CRASH("Unknown supply pack id given by order console ui. ID: [params["id"]]")

	var/name = "*None Provided*"
	var/rank = "*None Provided*"
	if(ishuman(usr))
		var/mob/living/carbon/human/human = usr
		name = human.get_authentification_name()
		rank = human.get_assignment(hand_first = TRUE)
	else if(issilicon(usr))
		name = usr.real_name
		rank = "Silicon"
	else
		name = usr.real_name
		rank = "Unknown"

	var/amount = text2num(params["amount"]) || 1
	for(var/count in 1 to amount)
		// Check for matching coupon
		var/obj/item/coupon/applied_coupon
		for(var/obj/item/coupon/coupon_check in loaded_coupons)
			if(pack.type == coupon_check.discounted_pack)
				say("Coupon found! [round(coupon_check.discount_pct_off * 100)]% off applied!")
				applied_coupon = coupon_check
				LAZYREMOVE(loaded_coupons, coupon_check)
				coupon_check.inserted_console = null
				break

		var/datum/supply_order/new_order = new(
			pack = pack,
			orderer = name,
			orderer_rank = rank,
			orderer_ckey = usr.ckey,
			paying_account = bank_account_holder.synced_bank_account,
			coupon = applied_coupon,
		)
		checkout_list += new_order

	return TRUE

/**
 * Removes an item from the grocery list
 */
/obj/machinery/computer/voidcrew_cargo/proc/remove_item(params)
	var/id = text2num(params["id"])
	for(var/datum/supply_order/order as anything in checkout_list)
		if(order.id != id)
			continue
		checkout_list -= order
		. = TRUE
		break

/**
 * Finds an item in the grocery list using their name
 */
/obj/machinery/computer/voidcrew_cargo/proc/name_to_id(order_name)
	for(var/pack in SSshuttle.supply_packs)
		var/datum/supply_pack/supply = SSshuttle.supply_packs[pack]
		if(order_name == supply.name)
			return pack
	return null

/**
 * Circuit board
 */
/obj/item/circuitboard/computer/voidcrew_cargo
	name = "Supply Console"
	greyscale_colors = CIRCUIT_COLOR_SUPPLY
	build_path = /obj/machinery/computer/voidcrew_cargo
	/// Whether the console should have contraband enabled (set by emagging)
	var/contraband = FALSE

/obj/item/circuitboard/computer/voidcrew_cargo/examine(mob/user)
	. = ..()
	if(obj_flags & EMAGGED)
		. += span_warning("It has been modified to access illegal supply channels.")
