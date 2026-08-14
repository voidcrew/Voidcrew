/**
 * Spawns ordered items into the cargo shuttle's cargo bay
 */
/obj/machinery/computer/voidcrew_cargo/proc/buy()
	SEND_SIGNAL(src, COMSIG_SUPPLY_SHUTTLE_BUY)

	if(!checkout_list.len)
		return FALSE

	var/datum/voidcrew_cargo_shuttle/cargo_shuttle = get_cargo_shuttle()
	if(!cargo_shuttle)
		return FALSE

	// Get all empty cargo bay turfs to distribute items across
	var/list/cargo_turfs = list()
	for(var/turf/open/floor/cargo_turf in cargo_shuttle.get_cargo_bay_turfs())
		if(cargo_turf.is_blocked_turf())
			continue
		cargo_turfs += cargo_turf
	if(!length(cargo_turfs))
		return FALSE

	var/value = 0
	var/purchases = 0

	// Group orders by pack name for cleaner history
	var/list/order_counts = list()
	var/list/order_costs = list()

	for(var/datum/supply_order/spawning_order as anything in checkout_list)
		var/price = spawning_order.pack.get_cost()
		if(spawning_order.applied_coupon)
			price *= (1 - spawning_order.applied_coupon.discount_pct_off)

		// Actually deduct the cost from the bank account
		bank_account_holder.synced_bank_account.adjust_money(-price)

		SSeconomy.track_purchase(bank_account_holder.synced_bank_account, price, spawning_order.pack.name)
		value += price
		checkout_list -= spawning_order
		QDEL_NULL(spawning_order.applied_coupon)

		// Track for history
		order_counts[spawning_order.pack.name] = (order_counts[spawning_order.pack.name] || 0) + 1
		order_costs[spawning_order.pack.name] = (order_costs[spawning_order.pack.name] || 0) + price

		// Generate the order contents on a random cargo bay turf. Forty-odd packs ship
		// in a secure crate type, which arrives locked - anyone aboard can toggle it
		// open, but the crew shouldn't have to unlock cargo they just paid for.
		var/turf/spawn_turf = pick(cargo_turfs)
		if(spawning_order.pack.goody)
			// Goody packs have no crate type: upstream never routes them through
			// generate() (it hand-packs them into account-locked cases), so calling
			// it here CRASHed and the whole shipment loop died with the money spent.
			// Ship-paid orders belong to the whole crew, so a plain box does.
			var/obj/item/storage/box/goody_box = new(spawn_turf)
			goody_box.name = "goody package - [spawning_order.pack.name]"
			// Manifest errors can qdel contents; a goody is often a single item
			ADD_TRAIT(goody_box, TRAIT_NO_MISSING_ITEM_ERROR, TRAIT_GENERIC)
			ADD_TRAIT(goody_box, TRAIT_NO_MANIFEST_CONTENTS_ERROR, TRAIT_GENERIC)
			spawning_order.pack.fill(goody_box)
			spawning_order.generateManifest(goody_box, "Cargo", spawning_order.pack, price)
		else
			var/obj/structure/closet/crate/delivered_crate = spawning_order.generate(spawn_turf)
			if(delivered_crate?.locked)
				delivered_crate.locked = FALSE
				delivered_crate.update_appearance()

		SSblackbox.record_feedback("nested tally", "cargo_imports", 1, list("[price]", "[spawning_order.pack.name]"))

		investigate_log("Order #[spawning_order.id] ([spawning_order.pack.name], placed by [key_name(spawning_order.orderer_ckey)]), paid by [bank_account_holder.synced_bank_account.account_holder] has shipped.", INVESTIGATE_CARGO)
		if(spawning_order.pack.dangerous)
			message_admins("\A [spawning_order.pack.name] ordered by [ADMIN_LOOKUPFLW(spawning_order.orderer_ckey)], paid by [bank_account_holder.synced_bank_account.account_holder] has shipped.")
		purchases++

	// Record purchases in history
	for(var/pack_name in order_counts)
		cargo_shuttle.record_transaction("buy", pack_name, order_counts[pack_name], order_costs[pack_name])

	SSeconomy.import_total += value
	investigate_log("[purchases] orders in this shipment, worth [value] credits. [bank_account_holder.synced_bank_account.account_balance] credits left.", INVESTIGATE_CARGO)
	return TRUE

/**
 * Exports items from the cargo shuttle's cargo bay
 */
/obj/machinery/computer/voidcrew_cargo/proc/sell()
	var/datum/voidcrew_cargo_shuttle/cargo_shuttle = get_cargo_shuttle()
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

	// Build export feedback message
	var/list/export_lines = list()
	for(var/datum/export/exports as anything in ex.total_amount)
		var/printout = exports.total_printout(ex)
		if(!printout)
			continue
		bank_account_holder.synced_bank_account.adjust_money(ex.total_value[exports])
		export_lines += printout
		// Record each export type in history
		var/export_name = exports.unit_name || "items"
		cargo_shuttle.record_transaction("sell", export_name, ex.total_amount[exports], ex.total_value[exports])

	var/total_profit = bank_account_holder.synced_bank_account.account_balance - presale_points

	// Announce exports to the ship
	var/obj/structure/overmap/ship/ship = get_ship_from_atom(src)
	if(ship && (length(export_lines) || total_profit > 0))
		var/announcement = ""
		if(length(export_lines))
			announcement = export_lines.Join("\n")
		if(total_profit > 0)
			announcement += "\n\nTotal earnings: [total_profit] credits"
			announcement += "\nNew balance: [bank_account_holder.synced_bank_account.account_balance] credits"
		else if(total_profit == 0 && !length(export_lines))
			announcement = "No exportable items were found on the cargo shuttle."
		ship.ship_notify(announcement, "CARGO", SHIP_NOTIFY_NOTICE, 'voidcrew/sound/notify.ogg', 50)

	SSeconomy.export_total += total_profit
	investigate_log("contents sold for [total_profit] credits. Contents: [ex.exported_atoms ? ex.exported_atoms.Join(",") + "." : "none."]", INVESTIGATE_CARGO)
	return TRUE
