/**
 * Spawns ordered items into the cargo shuttle's cargo bay
 */
/obj/machinery/computer/voidcrew_cargo/proc/buy()
	SEND_SIGNAL(src, COMSIG_SUPPLY_SHUTTLE_BUY)

	if(!checkout_list.len)
		return FALSE

	if(!cargo_shuttle)
		return FALSE

	// Get cargo bay turf to spawn items
	var/turf/cargo_bay = cargo_shuttle.get_cargo_bay_turf()
	if(!cargo_bay)
		return FALSE

	var/value = 0
	var/purchases = 0

	for(var/datum/supply_order/spawning_order as anything in checkout_list)
		var/price = spawning_order.pack.get_cost()
		if(spawning_order.applied_coupon)
			price *= (1 - spawning_order.applied_coupon.discount_pct_off)

		if(spawning_order.paying_account)
			SSeconomy.track_purchase(bank_account_holder.synced_bank_account, price, spawning_order.pack.name)
		value += spawning_order.pack.get_cost()
		checkout_list -= spawning_order
		QDEL_NULL(spawning_order.applied_coupon)

		// Generate the order contents in the cargo bay
		spawning_order.generate(cargo_bay)

		SSblackbox.record_feedback("nested tally", "cargo_imports", 1, list("[spawning_order.pack.get_cost()]", "[spawning_order.pack.name]"))

		investigate_log("Order #[spawning_order.id] ([spawning_order.pack.name], placed by [key_name(spawning_order.orderer_ckey)]), paid by [bank_account_holder.synced_bank_account.account_holder] has shipped.", INVESTIGATE_CARGO)
		if(spawning_order.pack.dangerous)
			message_admins("\A [spawning_order.pack.name] ordered by [ADMIN_LOOKUPFLW(spawning_order.orderer_ckey)], paid by [bank_account_holder.synced_bank_account.account_holder] has shipped.")
		purchases++

	SSeconomy.import_total += value
	investigate_log("[purchases] orders in this shipment, worth [value] credits. [bank_account_holder.synced_bank_account.account_balance] credits left.", INVESTIGATE_CARGO)
	return TRUE

/**
 * Exports items from the cargo shuttle's cargo bay
 */
/obj/machinery/computer/voidcrew_cargo/proc/sell()
	if(!cargo_shuttle)
		return FALSE

	var/presale_points = bank_account_holder.synced_bank_account.account_balance

	if(!GLOB.exports_list.len) // No exports list? Generate it!
		setupExports()

	var/datum/export_report/ex = new

	// Get all turfs in the cargo bay
	var/list/cargo_turfs = cargo_shuttle.get_cargo_bay_turfs()

	for(var/turf/cargo_turf as anything in cargo_turfs)
		for(var/atom/movable/exporting_atom in cargo_turf)
			if(iscameramob(exporting_atom))
				continue
			if(exporting_atom.anchored)
				continue
			// Skip docking ports and other shuttle infrastructure
			if(istype(exporting_atom, /obj/docking_port))
				continue
			if(istype(exporting_atom, /obj/effect/landmark))
				continue
			export_item_and_contents(exporting_atom, dry_run = FALSE, external_report = ex)

	if(ex.exported_atoms)
		ex.exported_atoms += "." //ugh

	for(var/datum/export/exports as anything in ex.total_amount)
		if(!exports.total_printout(ex))
			continue
		bank_account_holder.synced_bank_account.adjust_money(ex.total_value[exports])

	SSeconomy.export_total += (bank_account_holder.synced_bank_account.account_balance - presale_points)
	investigate_log("contents sold for [bank_account_holder.synced_bank_account.account_balance - presale_points] credits. Contents: [ex.exported_atoms ? ex.exported_atoms.Join(",") + "." : "none."]", INVESTIGATE_CARGO)
	return TRUE
