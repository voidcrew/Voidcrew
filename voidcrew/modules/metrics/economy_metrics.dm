// Round metrics for money: ship account changes, cash deposits, trader purchases and buybacks,
// paid outpost services, gambling, and cargo orders, exports and loans, including the materials
// market. See voidcrew/modules/metrics/metrics_helpers.dm for record_metric() and tally_metric().
//
// Event catalog. `credits` and `vouchers` are signed: money gained is positive, money spent is
// negative. For cash events (prizes, bets, slot machines) they count cash, not an account.
// Every event is written once per occurrence unless it says "tallied" (summed per minute).
//
// METRIC_ECONOMY
// * ship_account_change: any change to a player ship's account, through adjust_money(),
//   transfer_money(), forced_withdraw() or an admin edit, commissioning funds included. This is
//   the ledger: its credits summed per ship give that ship's whole income and spending.
//   ship, zone (where the ship is), subject = the reason given, or the proc that moved the money
//   when the caller gave none, credits = the change, details: balance (after), source (the proc
//   that moved the money). It overlaps every event below that pays into or out of a ship
//   account, on purpose. NPC hulls are skipped until a crew claims one.
// * ship_account_drain (tallied): drains that take a little many times a minute from a player
//   ship's account: a data siphon, a bank terminal paying out a vault withdrawal, a mob that
//   steals credits on hit. ship, zone, subject as above, credits = the summed change,
//   quantity = how many times. Not also written as ship_account_change.
// * ship_account_closed: a hull was deleted with money still in its account.
//   ship, zone, subject = account holder, credits = minus the balance lost.
// * outpost_account_change, outpost_account_drain, outpost_account_closed: the same for a player
//   outpost treasury. ship is empty and details.outpost names the claim (not on the drain).
// * cash_deposit: cash, holochips or coins paid into an account through an ID card or PDA,
//   a money bag or a bank terminal. ckey = depositor, ship = the account's ship (the depositor's
//   when the account isn't a ship's), subject = item type, credits = value, quantity = items,
//   details: via, account (holder), outpost. Overlaps the account's *_account_change row.
// * slot_machine_insert, slot_machine_payout (tallied): cash fed into or paid out of a slot
//   machine. ckey = whoever last used it, zone, subject = machine type,
//   credits = minus the cash inserted, or the cash paid out.
//
// METRIC_CARGO
// * cargo_order: supply packs paid for when the cargo shuttle docks, one row per pack and
//   orderer per shipment. ckey = orderer, ship, zone, subject = pack type, credits = minus the
//   price paid, quantity = packs, details: pack (name), coupons.
// * cargo_market_order: a Galactic Materials Market order, paid when the shuttle docks.
//   ckey = orderer, ship, zone, subject = sheet type ("mixed" for more than one material),
//   credits = minus the price paid, quantity = sheets, details: sheets (type -> count),
//   quote (price of the sheets), crate_fee, unit_price (quote per sheet),
//   market_price (type -> market price when paid).
// * cargo_export: goods sold off the cargo shuttle, one row per export type and kind per trip.
//   ship, zone, subject = export datum type, credits = paid, quantity = units (sheets for
//   materials and stock blocks), details: kind ("stock_block", "material" or "goods"),
//   unit_name, items (type -> count), unit_price, market_price (materials market, after the sale).
// * cargo_loan: a shuttle loan accepted and its bonus paid. ckey = who accepted, ship, zone,
//   subject = loan type, credits = bonus, details: loan.
// Outpost freight writes cargo_order, cargo_market_order and cargo_export too, with an empty
// ship and details.outpost. Its orders are recorded on delivery: undelivered ones are refunded.
//
// METRIC_TRADE
// * shop_purchase: a trader SKU bought over the counter (the ripperdoc and the Colosseum stall
//   included) or through a Halcyon freight beacon. ckey = buyer, ship = buyer's crew, zone,
//   subject = item type (SKU type when it hands over no item), credits and vouchers = minus the
//   price paid, quantity = units, details: sku, name, shelf, shop, favor_tier, and when a
//   discount applied list_price, discount_pct and discount ("special" or "favor"); barter and
//   barter_amount for barter deals; via.
// * shop_buyback: goods sold to a trader's wanted ledger. ckey = seller, ship, zone,
//   subject = item type, credits and vouchers = paid out, quantity = items, details: name,
//   shop, sales.
// * mod_bench_upgrade: subject = upgrade id, details: name.
// * neural_imprint: subject = schematic name, details: from_cash (paid from loaded cash).
// * chrome_cradle_service: subject = service, details: from_cash.
// * locker_rental: subject = locker type.
//   The four above are paid outpost services: ckey = customer, ship, zone, credits and
//   vouchers = minus the fee.
// * outpost_advert: an outpost broadcast, paid from the outpost treasury. ckey = who bought it,
//   subject = outpost name, credits = minus the cost. No ship.
// * colosseum_prize: a winner's share of a match's prize pool, banked in the spoils vault.
//   ckey = winner (empty on a draw), ship = winner's crew, zone, subject = match mode type,
//   credits = cash, vouchers, quantity = ship parts, details: contestants, shares, mode.
// * colosseum_beast_bounty: the beast interlude's kill bounty, banked in the vault.
//   credits = cash, quantity = kills.
// * colosseum_bet: a stake placed with the bookmaker. ckey = bettor, other_ckey = the fighter
//   backed, credits = minus the stake.
// * colosseum_bet_payout: a winning slip cashed. ckey, other_ckey as above, credits = payout,
//   details: stake.

// ---- Account ownership -------------------------------------------------

/datum/bank_account/ship
	/// The ship that owns this account, cached by metric_account_ship().
	var/datum/weakref/metric_ship_ref
	/// The ship's id and class as the metrics table knows them. A hull being deleted has already
	/// let go of its shuttle and template when its account closes, so the closing row uses these.
	var/metric_ship_id
	var/metric_ship_class

/**
 * The ship that owns a ship account, or null. The account's job is the ship's first crew slot,
 * which points back at the ship; the fleet list covers an account whose job doesn't.
 * `deleting` also finds a ship that is part way through being deleted.
 */
/proc/metric_account_ship(datum/bank_account/ship/account, deleting = FALSE)
	if(!istype(account))
		return null
	var/obj/structure/overmap/ship/ship = deleting ? account.metric_ship_ref?.hard_resolve() : account.metric_ship_ref?.resolve()
	if(ship?.ship_account != account)
		ship = account.account_job?.crew_ship_ref?.resolve()
		if(ship?.ship_account != account)
			ship = null
			for(var/obj/structure/overmap/ship/candidate as anything in SSovermap.simulated_ships)
				if(candidate.ship_account == account)
					ship = candidate
					break
		if(ship)
			account.metric_ship_ref = WEAKREF(ship)
	if(ship?.shuttle && ship.source_template)
		account.metric_ship_id = metric_ship_id(ship)
		account.metric_ship_class = ship.source_template.name
	return ship

/// The player ship or player outpost an account belongs to, or null.
/proc/metric_account_owner(datum/bank_account/account)
	if(istype(account, /datum/bank_account/ship))
		return metric_account_ship(account)
	if(istype(account, /datum/bank_account/outpost))
		var/datum/bank_account/outpost/treasury = account
		return treasury.claim?.resolve()
	return null

/// TRUE for an NPC hull no crew has claimed. Its money isn't player money.
/proc/metric_is_npc_hull(obj/structure/overmap/ship/ship)
	var/obj/structure/overmap/ship/npc/npc = ship
	return istype(npc) && !npc.player_controlled

/// The ship a mind crews, or null.
/proc/metric_mind_ship(datum/mind/mind)
	for(var/datum/team/voidcrew/team as anything in mind?.ship_teams)
		if(team.ship)
			return team.ship
	return null

// ---- The ledger --------------------------------------------------------

/datum/bank_account/ship/adjust_money(amount, reason)
	var/balance_before = account_balance
	. = ..()
	if(. && SSmetrics?.accepting)
		metric_account_changed(src, account_balance - balance_before, reason, caller)

/datum/bank_account/outpost/adjust_money(amount, reason)
	var/balance_before = account_balance
	. = ..()
	if(. && SSmetrics?.accepting)
		metric_account_changed(src, account_balance - balance_before, reason, caller)

/datum/bank_account/vv_edit_var(var_name, var_value)
	var/balance_before = account_balance
	. = ..()
	if(. && var_name == NAMEOF(src, account_balance) && SSmetrics?.accepting)
		metric_account_changed(src, account_balance - balance_before, "Admin edit")

/datum/bank_account/ship/Destroy()
	metric_account_closed(src)
	return ..()

/datum/bank_account/outpost/Destroy()
	metric_account_closed(src)
	return ..()

/// Walks up from `frame` past the bank account's own procs to whatever asked for the money.
/proc/metric_money_frame(callee/frame)
	while(frame)
		if(!istype(frame.src, /datum/bank_account))
			return frame
		frame = frame.caller
	return null

/// TRUE for a drain that takes a little at a time, many times a minute: a data siphon on the
/// account, a bank terminal paying out a vault withdrawal (the terminal never takes money any
/// other way), or a mob that steals credits with every hit.
/proc/metric_is_drain(callee/frame, change)
	if(!frame || change >= 0)
		return FALSE
	var/datum/source = frame.src
	return istype(source, /obj/machinery/shuttle_scrambler) || istype(source, /obj/machinery/computer/bank_machine) || istype(source, /datum/component/plundering_attacks)

/**
 * Records a change to a player ship's or player outpost's account. Other accounts are ignored.
 * `frame` is the caller of the proc that changed the balance, and names where money moved
 * when the caller gave no reason.
 */
/proc/metric_account_changed(datum/bank_account/account, change, reason, callee/frame)
	if(!SSmetrics.accepting || !change)
		return
	var/prefix
	var/obj/structure/overmap/owner
	var/obj/structure/overmap/ship/ship
	if(istype(account, /datum/bank_account/ship))
		ship = metric_account_ship(account)
		if(ship && metric_is_npc_hull(ship))
			return
		owner = ship
		prefix = "ship_account"
	else if(istype(account, /datum/bank_account/outpost))
		owner = metric_account_owner(account)
		prefix = "outpost_account"
	else
		return
	frame = metric_money_frame(frame)
	var/source = frame ? "[frame.proc]" : null
	var/subject = reason || source
	var/zone = owner ? metric_zone(owner) : null
	if(metric_is_drain(frame, change))
		tally_metric(METRIC_ECONOMY, "[prefix]_drain", ship = ship, zone = zone, subject = subject, credits = change)
		return
	var/list/details = list("balance" = account.account_balance)
	if(source)
		details["source"] = source
	if(owner && !ship)
		details["outpost"] = owner.name
	record_metric(METRIC_ECONOMY, "[prefix]_change", ship = ship, zone = zone, subject = subject, credits = change, details = details)

/// Records the money that disappears with a player ship's or outpost's account.
/proc/metric_account_closed(datum/bank_account/account)
	if(!SSmetrics.accepting || account.account_balance <= 0)
		return
	var/datum/bank_account/ship/ship_account = account
	if(istype(ship_account))
		var/obj/structure/overmap/ship/ship = metric_account_ship(ship_account, deleting = TRUE)
		if(ship && metric_is_npc_hull(ship))
			return
		var/list/row = SSmetrics.build_row(METRIC_ECONOMY, "ship_account_closed", null, null, ship, ship ? metric_zone(ship) : null, account.account_holder, -account.account_balance, 0, 0, 0, null)
		// The hull has already detached its shuttle and template, which the id and class come from
		if(ship && ship_account.metric_ship_id)
			row["ship_id"] = ship_account.metric_ship_id
			row["ship_class"] = ship_account.metric_ship_class
		SSmetrics.queue_row(row)
		return
	var/datum/bank_account/outpost/treasury = account
	if(!istype(treasury))
		return
	var/obj/structure/overmap/outpost = treasury.claim?.hard_resolve()
	record_metric(METRIC_ECONOMY, "outpost_account_closed", zone = outpost ? metric_zone(outpost) : null, subject = account.account_holder, credits = -account.account_balance, details = outpost ? list("outpost" = outpost.name) : null)

// ---- Cash --------------------------------------------------------------

/obj/item/card/id/insert_money(obj/item/money, mob/user)
	var/datum/bank_account/account = registered_account
	var/value = (account && money) ? money.get_item_credit_value() : 0
	var/money_type = money?.type
	. = ..()
	if(. && value)
		metric_cash_deposit(account, user, value, money_type, "ID card")

/obj/item/card/id/mass_insert_money(list/money, mob/user)
	var/datum/bank_account/account = registered_account
	var/count = length(money)
	. = ..()
	if(. > 0)
		metric_cash_deposit(account, user, ., /obj/item/storage/bag/money, "money bag", count)

/// Records cash paid into an account.
/proc/metric_cash_deposit(datum/bank_account/account, mob/user, value, item_type, via, quantity = 1)
	if(!SSmetrics.accepting || !account || value <= 0)
		return
	var/obj/structure/overmap/owner = metric_account_owner(account)
	var/obj/structure/overmap/ship/ship = istype(owner, /obj/structure/overmap/ship) ? owner : null
	var/list/details = list("via" = via, "account" = account.account_holder)
	if(owner && !ship)
		details["outpost"] = owner.name
	record_metric(METRIC_ECONOMY, "cash_deposit", ship = ship, subject = item_type, credits = value, quantity = quantity, details = details, actor = user)

// ---- Slot machines -----------------------------------------------------

/obj/machinery/computer/slot_machine
	/// Ckey of whoever last fed or spun this machine. Its payouts are credited to them.
	var/metric_player

/obj/machinery/computer/slot_machine/item_interaction(mob/living/user, obj/item/inserted, list/modifiers)
	var/balance_before = balance
	. = ..()
	if(balance > balance_before)
		metric_player = user?.ckey
		metric_slot_machine(src, "slot_machine_insert", balance_before - balance)

/obj/machinery/computer/slot_machine/spin(mob/user)
	if(user?.ckey)
		metric_player = user.ckey
	return ..()

/obj/machinery/computer/slot_machine/give_payout(amount)
	. = ..()
	// Holochips pay out the whole amount; coins return whatever they couldn't make change for.
	var/paid = ispath(cointype, /obj/item/holochip) ? amount : amount - .
	if(paid > 0)
		metric_slot_machine(src, "slot_machine_payout", paid)

/proc/metric_slot_machine(obj/machinery/computer/slot_machine/machine, event, credits)
	if(!SSmetrics.accepting || !credits)
		return
	tally_metric(METRIC_ECONOMY, event, ckey = machine.metric_player, zone = metric_zone(machine), subject = "[machine.type]", credits = credits)

// ---- Cargo orders ------------------------------------------------------

/**
 * Adds a paid cargo order to a shipment's `tally`, which metric_cargo_orders() writes once the
 * shipment is done: one row per pack type and orderer, and one per materials market order.
 */
/proc/metric_note_cargo_order(list/tally, datum/supply_order/order, price)
	if(!SSmetrics.accepting || !islist(tally) || !order?.pack)
		return
	var/datum/supply_pack/custom/minerals/materials = order.pack
	if(istype(materials))
		tally["market [order.id]"] = metric_market_order_entry(order, materials, price)
		return
	var/key = "[order.pack.type] [order.orderer_ckey]"
	var/list/entry = tally[key]
	if(!entry)
		entry = list(
			"event" = "cargo_order",
			"ckey" = order.orderer_ckey,
			"subject" = "[order.pack.type]",
			"credits" = 0,
			"quantity" = 0,
			"details" = list("pack" = order.pack.name),
		)
		tally[key] = entry
	entry["credits"] -= price
	entry["quantity"] += 1
	if(order.applied_coupon)
		var/list/details = entry["details"]
		details["coupons"] += 1

/// The row for one materials market order, with the market's prices when it was paid.
/proc/metric_market_order_entry(datum/supply_order/order, datum/supply_pack/custom/minerals/materials, price)
	var/list/sheets = list()
	var/list/market_prices = list()
	var/total_sheets = 0
	var/subject
	for(var/obj/item/stack/sheet/sheet_type as anything in materials.contains)
		var/count = materials.contains[sheet_type]
		sheets["[sheet_type]"] = count
		total_sheets += count
		market_prices["[sheet_type]"] = SSstock_market.materials_prices[initial(sheet_type.material_type)]
		subject = subject ? "mixed" : "[sheet_type]"
	var/quote = round(materials.cost)
	var/list/details = list(
		"sheets" = sheets,
		"quote" = quote,
		"crate_fee" = price - quote,
		"market_price" = market_prices,
	)
	if(total_sheets)
		details["unit_price"] = round(quote / total_sheets, 0.01)
	return list(
		"event" = "cargo_market_order",
		"ckey" = order.orderer_ckey,
		"subject" = subject,
		"credits" = -price,
		"quantity" = total_sheets,
		"details" = details,
	)

/// Writes the rows noted by metric_note_cargo_order(). `location` is the console or outpost.
/proc/metric_cargo_orders(list/tally, datum/bank_account/account, atom/location)
	if(!SSmetrics.accepting || !length(tally))
		return
	var/obj/structure/overmap/owner = metric_account_owner(account)
	var/obj/structure/overmap/ship/ship = istype(owner, /obj/structure/overmap/ship) ? owner : null
	if(!owner)
		ship = get_ship_from_atom(location)
	var/zone = metric_zone(location || owner)
	for(var/key in tally)
		var/list/entry = tally[key]
		var/list/details = entry["details"]
		if(owner && !ship)
			details["outpost"] = owner.name
		record_metric(METRIC_CARGO, entry["event"], ckey = entry["ckey"], ship = ship, zone = zone, subject = entry["subject"], credits = entry["credits"], quantity = entry["quantity"], details = details)

/// One order delivered by an outpost's freight service.
/proc/metric_outpost_cargo_order(obj/structure/overmap/dynamic/player_outpost/outpost, datum/supply_order/order)
	if(!SSmetrics.accepting || !outpost || isnull(order?.ship_paid_cost))
		return
	var/list/tally = list()
	metric_note_cargo_order(tally, order, order.ship_paid_cost)
	metric_cargo_orders(tally, outpost.treasury, outpost)

/// A shuttle loan accepted, with its bonus paid into `account`.
/proc/metric_cargo_loan(datum/voidcrew_shuttle_loan/loan, datum/bank_account/account, mob/user)
	if(!SSmetrics.accepting || !loan)
		return
	var/obj/structure/overmap/ship/ship = metric_account_ship(account)
	record_metric(METRIC_CARGO, "cargo_loan", ship = ship, subject = "[loan.type]", credits = loan.bonus_credits, quantity = 1, details = list("loan" = loan.logging_desc), actor = user, location = ship)

// ---- Cargo exports -----------------------------------------------------

/datum/export_report
	/// Sales by export type and kind, kept only while round metrics watch this report.
	/// See metric_watch_exports().
	var/list/metric_sales

/// Starts collecting a sale-by-sale breakdown on `report`, for metric_cargo_exports().
/proc/metric_watch_exports(datum/export_report/report)
	if(SSmetrics.accepting && report)
		report.metric_sales = list()

/datum/export/sell_object(obj/sold_item, datum/export_report/report, dry_run = TRUE, apply_elastic = TRUE)
	if(dry_run || isnull(report?.metric_sales))
		return ..()
	var/value_before = report.total_value[src] || 0
	var/amount_before = report.total_amount[src] || 0
	. = ..()
	if(.)
		metric_note_export(report, src, sold_item, (report.total_value[src] || 0) - value_before, (report.total_amount[src] || 0) - amount_before)

/// Adds one sold object to its report's breakdown, split by what kind of sale it was.
/proc/metric_note_export(datum/export_report/report, datum/export/export, obj/sold_item, value, amount)
	var/kind = "goods"
	if(istype(sold_item, /obj/item/stock_block))
		kind = "stock_block"
	else if(istype(export, /datum/export/material))
		kind = "material"
	var/key = "[export.type] [kind]"
	var/list/line = report.metric_sales[key]
	if(!line)
		line = list("export" = export, "kind" = kind, "value" = 0, "units" = 0, "items" = list())
		report.metric_sales[key] = line
	line["value"] += value
	line["units"] += amount / (export.amount_report_multiplier || 1)
	var/list/items = line["items"]
	items["[sold_item.type]"] += 1

/**
 * Writes one cargo_export row per export type and kind in a finished sale. Skips export types
 * the seller wasn't paid for, the same test sell() applies before paying.
 * `location` is the console or outpost.
 */
/proc/metric_cargo_exports(datum/export_report/report, datum/bank_account/account, atom/location)
	if(!SSmetrics.accepting || !length(report?.metric_sales))
		return
	var/obj/structure/overmap/owner = metric_account_owner(account)
	var/obj/structure/overmap/ship/ship = istype(owner, /obj/structure/overmap/ship) ? owner : null
	if(!owner)
		ship = get_ship_from_atom(location)
	var/zone = metric_zone(location || owner)
	for(var/key in report.metric_sales)
		var/list/line = report.metric_sales[key]
		var/datum/export/export = line["export"]
		if(!report.total_amount[export] || !report.total_value[export])
			continue
		var/value = line["value"]
		var/units = line["units"]
		var/list/details = list("kind" = line["kind"], "items" = line["items"])
		if(export.unit_name)
			details["unit_name"] = export.unit_name
		if(units)
			details["unit_price"] = round(value / units, 0.01)
		var/datum/export/material/material_export = export
		if(istype(material_export) && (material_export.material_id in SSstock_market.materials_prices))
			details["market_price"] = SSstock_market.materials_prices[material_export.material_id]
		if(owner && !ship)
			details["outpost"] = owner.name
		record_metric(METRIC_CARGO, "cargo_export", ship = ship, zone = zone, subject = "[export.type]", credits = value, quantity = units, details = details)

// ---- Trader shops ------------------------------------------------------

/// A SKU sold to `user`. Call after the goods are handed over.
/proc/metric_shop_purchase(datum/shop_sku/sku, mob/living/user, credits_paid = 0, vouchers_paid = 0, via)
	if(!SSmetrics.accepting || !sku)
		return
	var/list/details = list("sku" = "[sku.type]", "name" = sku.name, "shelf" = sku.shelf)
	var/datum/outpost_shop/shop = sku.shop
	if(shop)
		details["shop"] = "[shop.type]"
		var/obj/structure/overmap/ship/crew_ship = get_crew_ship(user)
		details["favor_tier"] = shop.get_favor_tier(crew_ship)
		var/favor_pct = shop.get_discount_pct(crew_ship)
		var/applied_pct = max(sku.discount_pct, favor_pct)
		if(credits_paid > 0 && applied_pct)
			details["list_price"] = sku.price_credits
			details["discount_pct"] = applied_pct
			details["discount"] = favor_pct > sku.discount_pct ? "favor" : "special"
	var/datum/shop_sku/barter/barter = sku
	if(istype(barter))
		details["barter"] = "[barter.barter_path]"
		details["barter_amount"] = barter.barter_amount
	if(via)
		details["via"] = via
	var/quantity = (sku.dispense_amount > 1 && ispath(sku.item_path, /obj/item/stack)) ? sku.dispense_amount : 1
	record_metric(METRIC_TRADE, "shop_purchase", subject = sku.item_path || sku.type, credits = -credits_paid, vouchers = -vouchers_paid, quantity = quantity, details = details, actor = user)

/// `sales` sale-units sold to a trader's wanted ledger. Call after the seller is paid.
/proc/metric_shop_buyback(datum/shop_buyback/buyback, mob/living/user, mob/living/basic/outpost_trader/vendor, sales)
	if(!SSmetrics.accepting || !buyback || sales <= 0)
		return
	var/list/details = list("name" = buyback.name, "sales" = sales)
	if(vendor?.shop)
		details["shop"] = "[vendor.shop.type]"
	var/items = ispath(buyback.item_path, /obj/item/stack) ? sales * buyback.amount : sales
	record_metric(METRIC_TRADE, "shop_buyback", subject = buyback.item_path, credits = buyback.pay_credits * sales, vouchers = buyback.pay_vouchers * sales, quantity = items, details = details, actor = user)

// ---- Outpost services --------------------------------------------------

/// A paid outpost service. `credits_paid` and `vouchers_paid` are the fee, as positive numbers.
/proc/metric_outpost_service(event, mob/user, atom/location, credits_paid = 0, vouchers_paid = 0, subject, list/details)
	if(!SSmetrics.accepting)
		return
	record_metric(METRIC_TRADE, event, subject = subject, credits = -credits_paid, vouchers = -vouchers_paid, quantity = 1, details = details, actor = user, location = location)

/// An outpost broadcast, paid from the outpost's treasury rather than a ship.
/proc/metric_outpost_advert(obj/structure/overmap/dynamic/player_outpost/outpost, mob/user, cost)
	if(!SSmetrics.accepting || !outpost)
		return
	record_metric(METRIC_TRADE, "outpost_advert", ckey = metric_ckey(user), subject = outpost.name, credits = -cost, quantity = 1, location = outpost)

// ---- The Colosseum -----------------------------------------------------

/// One row per winner's share of a match's prize pool, split the way award_prizes() splits it.
/proc/metric_colosseum_prizes(datum/colosseum_controller/controller, contestant_count, parts, credits, vouchers)
	if(!SSmetrics.accepting || !controller)
		return
	var/atom/vault = controller.site?.spoils_vault
	var/zone = vault ? metric_zone(vault) : null
	var/list/winners = controller.winner_minds
	var/shares = max(1, length(winners))
	var/list/details = list("contestants" = contestant_count, "shares" = shares, "mode" = controller.mode?.name)
	var/mode_type = controller.mode ? "[controller.mode.type]" : null
	for(var/i in 1 to shares)
		var/datum/mind/winner = i <= length(winners) ? winners[i] : null
		var/credit_share = round(credits / shares) + (i <= (credits % shares) ? 1 : 0)
		var/voucher_share = round(vouchers / shares) + (i <= (vouchers % shares) ? 1 : 0)
		var/part_share = round(parts / shares) + (i <= (parts % shares) ? 1 : 0)
		record_metric(METRIC_TRADE, "colosseum_prize", ckey = winner?.key ? ckey(winner.key) : null, ship = metric_mind_ship(winner), zone = zone, subject = mode_type, credits = credit_share, vouchers = voucher_share, quantity = part_share, details = details)

/proc/metric_colosseum_bounty(atom/vault, credits, kills)
	if(!SSmetrics.accepting)
		return
	record_metric(METRIC_TRADE, "colosseum_beast_bounty", credits = credits, quantity = kills, location = vault)

/proc/metric_colosseum_bet(mob/living/user, stake, datum/mind/backed, atom/bookmaker)
	if(!SSmetrics.accepting)
		return
	record_metric(METRIC_TRADE, "colosseum_bet", other_ckey = backed?.key ? ckey(backed.key) : null, credits = -stake, quantity = 1, actor = user, location = bookmaker)

/proc/metric_colosseum_bet_payout(mob/living/user, payout, stake, datum/mind/backed, atom/bookmaker)
	if(!SSmetrics.accepting)
		return
	record_metric(METRIC_TRADE, "colosseum_bet_payout", other_ckey = backed?.key ? ckey(backed.key) : null, credits = payout, quantity = 1, details = list("stake" = stake), actor = user, location = bookmaker)
