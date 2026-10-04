/**
 * # Outpost marketplace: prices, roles and payments
 *
 * The shared layer under the outpost's paid services (cloning bay, shop, medical lab, storage,
 * the ship bay's docking fee and the teleporter network). One price table, one membership test,
 * one charge proc and one income ledger.
 *
 * Members (the owner, residents and the owner's crews) use every service free. Visitors pay from
 * the account of the ID they present, into the outpost treasury. An ownerless outpost charges
 * nothing. The owner, treasurers and pricers set prices on the management console.
 *
 * No payout anywhere may be derived from service income: members could pad it.
 */

/obj/structure/overmap/dynamic/player_outpost
	/// Residents the owner lets set service prices (the Pricing tab)
	var/list/datum/mind/pricers = list()
	/// Price key -> whole credits. A missing key means the table default.
	var/list/outpost_prices = list()
	/// Income and price changes, newest last: list("time", "service", "label", "payer", "account", "amount")
	var/list/service_ledger = list()
	/// Service key -> list("total", "count") of what it has earned
	var/list/service_totals = list()
	/// list(world.time, amount) for every payment and refund in the last OUTPOST_INCOME_WINDOW, oldest first
	var/list/recent_income = list()
	/// Ckey -> world.time of their last price change
	var/list/price_set_times = list()
	/// Admin testing aid: this ckey is billed as a visitor, never a member. Set only by the manipulator.
	var/playtest_visitor_ckey

/// Every service price an outpost can set: key -> label, default, max and the service that sells it
GLOBAL_LIST_INIT(outpost_price_table, list(
	OUTPOST_PRICE_DOCK_BAY = list("label" = "Ship bay docking", "default" = OUTPOST_DOCK_FEE_DEFAULT, "max" = OUTPOST_DOCK_FEE_MAX, "service" = "ship_bay"),
	OUTPOST_PRICE_CLONE_IMPRINT = list("label" = "Cloning imprint", "default" = OUTPOST_CLONE_IMPRINT_DEFAULT, "max" = OUTPOST_CLONE_IMPRINT_MAX, "service" = "cloning_bay"),
	OUTPOST_PRICE_MEDLAB_PASS = list("label" = "Medical lab pass (30 min)", "default" = OUTPOST_MEDLAB_PASS_DEFAULT, "max" = OUTPOST_MEDLAB_PASS_MAX, "service" = "medical_lab"),
	OUTPOST_PRICE_STORAGE_RENT = list("label" = "Locker rental", "default" = OUTPOST_STORAGE_RENT_DEFAULT, "max" = OUTPOST_STORAGE_RENT_MAX, "service" = "storage"),
	OUTPOST_PRICE_TELEPORT_ARRIVAL = list("label" = "Teleporter arrival fare", "default" = OUTPOST_TELEPORT_ARRIVAL_DEFAULT, "max" = OUTPOST_TELEPORT_ARRIVAL_MAX, "service" = "teleporter"),
))

// ===== PRICES =====

/// The price set for `key`, or the table default. 0 for an unknown key.
/obj/structure/overmap/dynamic/player_outpost/proc/get_price(key)
	if(!istext(key))
		return 0
	var/list/row = GLOB.outpost_price_table[key]
	if(!row)
		return 0
	var/stored = outpost_prices[key]
	return isnum(stored) ? stored : row["default"]

/// Whether the service that charges `key` is installed here
/obj/structure/overmap/dynamic/player_outpost/proc/price_available(key)
	if(!istext(key))
		return FALSE
	var/list/row = GLOB.outpost_price_table[key]
	if(!row)
		return FALSE
	if(row["service"] == "ship_bay")
		return !!ship_bay_installed
	// Any installed upgrade with the service's id: the teleporter need not be a service room
	var/datum/outpost_upgrade/room = outpost_upgrades[row["service"]]
	return !!room?.installed

/**
 * Sets a service price. Returns null when it was set (or unchanged), else a short refusal.
 * UI params are decoded JSON, so the key and value are checked for type first.
 */
/obj/structure/overmap/dynamic/player_outpost/proc/set_price(mob/living/user, key, value)
	if(!istext(key) || !GLOB.outpost_price_table[key])
		return "Unknown price."
	if(!is_current_pricing_user(user))
		return "Pricing access required."
	// isnum() accepts NaN
	if(!isnum(value) || isnan(value))
		return "Invalid price."
	var/list/row = GLOB.outpost_price_table[key]
	value = clamp(round(value, 1), 0, row["max"])
	var/setter = user.ckey || REF(user)
	var/last_set = price_set_times[setter]
	if(last_set && world.time < last_set + OUTPOST_PRICE_SET_COOLDOWN)
		return "Too many price changes."
	var/old_value = get_price(key)
	if(value == old_value)
		return null
	outpost_prices[key] = value
	price_set_times[setter] = world.time
	log_game("PLAYER OUTPOST: [key_name(user)] set the [row["label"]] price at '[name]' from [old_value] to [value] cr")
	add_service_ledger(key, "[row["label"]]: [old_value] cr to [value] cr", user.real_name, null, 0)
	return null

/// Every price back to its default (abandonment)
/obj/structure/overmap/dynamic/player_outpost/proc/reset_prices()
	outpost_prices.Cut()
	price_set_times.Cut()

// ===== ROLES =====

/obj/structure/overmap/dynamic/player_outpost/proc/can_set_prices(mob/user)
	return founder_ckey && (is_owner(user) || (user?.mind && ((user.mind in treasurers) || (user.mind in pricers))))

/// Pricing needs the role's current body; a retired owner body keeps its ckey but not the controls.
/obj/structure/overmap/dynamic/player_outpost/proc/is_current_pricing_user(mob/living/user)
	return istype(user) && user.mind?.current == user && can_set_prices(user) && (!is_owner(user) || is_current_management_user(user))

/**
 * Whether `user` uses this outpost's services free and passes its staff doors: the owner, a
 * resident, or anyone on one of the owner's ship crews. The playtest visitor and blocked
 * players never are.
 */
/obj/structure/overmap/dynamic/player_outpost/proc/is_outpost_member(mob/user)
	if(!user)
		return FALSE
	if(playtest_visitor_ckey && user.ckey == playtest_visitor_ckey)
		return FALSE
	// A player the owner blocked is out, whatever character or crew they are on
	if(user.ckey && (user.ckey in blocked_residents) && !is_owner(user))
		return FALSE
	if(is_resident(user))
		return TRUE
	var/datum/mind/owner_mind = founder_mind?.resolve()
	if(!owner_mind || !user.mind || !LAZYLEN(owner_mind.ship_teams))
		return FALSE
	for(var/datum/team/voidcrew/team as anything in user.mind.ship_teams)
		if(team in owner_mind.ship_teams)
			return TRUE
	return FALSE

/**
 * Whether `user` may take stock from the owner shop without paying: the owner, stewards,
 * treasurers and pricers, in their current bodies. Other members pay like visitors.
 */
/obj/structure/overmap/dynamic/player_outpost/proc/can_take_shop_stock(mob/user)
	if(!isliving(user))
		return FALSE
	if(playtest_visitor_ckey && user.ckey == playtest_visitor_ckey)
		return FALSE
	return is_current_management_user(user) || is_current_pricing_user(user)

/// The installed service room with this id, or null
/obj/structure/overmap/dynamic/player_outpost/proc/service_upgrade(id)
	// UI params are decoded JSON: a number here would index the list by position
	if(!istext(id))
		return null
	var/datum/outpost_upgrade/service/room = outpost_upgrades[id]
	if(!istype(room) || !room.installed)
		return null
	return room

// ===== PAYMENTS =====

/// What `user` owes for a service priced `current_price` here: 0 when free, a member, ownerless or price <= 0.
/obj/structure/overmap/dynamic/player_outpost/proc/service_price_for(mob/user, current_price)
	if(!founder_ckey || !isnum(current_price) || current_price <= 0)
		return 0
	if(is_outpost_member(user))
		return 0
	return current_price

/**
 * Charges a customer from the account of the ID they present, into the treasury.
 * Never sleeps, and never asks where the payer stands: a teleporter traveller pays the
 * destination's fare from the pad they leave.
 *
 * `current_price` is the LISTED price (get_price(), or the shop listing). `shown_price` is the
 * EFFECTIVE amount the customer saw: service_price_for(payer, listed price) at the time they were
 * shown it, so 0 for members. Pass the client param the UI echoed, or the value captured before a
 * prompt. The charge refuses unless `shown_price` equals what this payer owes now, so a price
 * change or a membership change between quote and charge never moves money the customer did not
 * agree to. Returns null when paid or free, else a short refusal for the customer.
 */
/obj/structure/overmap/dynamic/player_outpost/proc/charge_service(mob/living/payer, service_key, current_price, shown_price, label)
	if(QDELETED(src) || !isliving(payer))
		return "Service unavailable."
	var/amount = service_price_for(payer, current_price)
	// isnum() accepts NaN, which is unequal to everything and so refuses here too
	if(!isnum(shown_price) || shown_price != amount)
		return "Price changed to [amount] cr."
	if(amount <= 0)
		return null
	var/datum/bank_account/account = payer.get_idcard(TRUE)?.registered_account
	if(!account)
		return "No bank account on your ID."
	ensure_home_services()
	if(account == treasury)
		return "Payment declined."
	if(!account.has_money(amount) || !account.adjust_money(-amount, "[label] at [name]"))
		return "Insufficient credits."
	receive_payment(amount, service_key, label, payer.real_name, account.account_holder)
	return null

/// Credits the treasury and writes the ledger, the treasury history line and the economy log. Shared with the dock fee capture.
/obj/structure/overmap/dynamic/player_outpost/proc/receive_payment(amount, service_key, label, payer_name, account_holder)
	if(!isnum(amount) || amount <= 0)
		return FALSE
	ensure_home_services()
	treasury.adjust_money(amount, "[label]: [payer_name] ([account_holder])")
	add_service_ledger(service_key, label, payer_name, account_holder, amount)
	var/list/totals = service_totals[service_key]
	if(!totals)
		totals = list("total" = 0, "count" = 0)
		service_totals[service_key] = totals
	totals["total"] += amount
	totals["count"] += 1
	note_recent_income(amount)
	log_econ("[amount] cr paid to [name] ([treasury.account_holder]) for [label] by [payer_name] ([account_holder])")
	return TRUE

/// Treasury -> `account`, exactly `amount`. FALSE, with nothing moved, when the treasury is short.
/obj/structure/overmap/dynamic/player_outpost/proc/refund_payment(datum/bank_account/account, amount, service_key, label)
	if(QDELETED(account) || !treasury || account == treasury || !isnum(amount) || amount <= 0)
		return FALSE
	if(!treasury.has_money(amount) || !treasury.adjust_money(-amount, "Refund: [label] to [account.account_holder]"))
		return FALSE
	account.adjust_money(amount, "Refund: [label] from [name]")
	add_service_ledger(service_key, "Refund: [label]", null, account.account_holder, -amount)
	var/list/totals = service_totals[service_key]
	if(totals)
		totals["total"] -= amount
	note_recent_income(-amount)
	log_econ("[amount] cr refunded by [name] ([treasury.account_holder]) for [label] to [account.account_holder]")
	return TRUE

/// Income already in the treasury that nobody was charged for (the prison wing's pay, cargo exports): into the ledger and the takings
/obj/structure/overmap/dynamic/player_outpost/proc/record_income(source_key, label, amount)
	if(!isnum(amount) || amount <= 0)
		return
	add_service_ledger(source_key, label, null, null, amount)
	var/list/totals = service_totals[source_key]
	if(!totals)
		totals = list("total" = 0, "count" = 0)
		service_totals[source_key] = totals
	totals["total"] += amount
	totals["count"] += 1
	note_recent_income(amount)

/// Remembers `amount` (negative for a refund) for the takings' last hour
/obj/structure/overmap/dynamic/player_outpost/proc/note_recent_income(amount)
	recent_income += list(list(world.time, amount))
	prune_recent_income()

/// Forgets income older than OUTPOST_INCOME_WINDOW
/obj/structure/overmap/dynamic/player_outpost/proc/prune_recent_income()
	var/cutoff = world.time - OUTPOST_INCOME_WINDOW
	var/stale = 0
	for(var/list/entry as anything in recent_income)
		if(entry[1] >= cutoff)
			break
		stale++
	if(stale)
		recent_income.Cut(1, stale + 1)

/// Credits taken in the last OUTPOST_INCOME_WINDOW, refunds taken off
/obj/structure/overmap/dynamic/player_outpost/proc/recent_income_total()
	prune_recent_income()
	. = 0
	for(var/list/entry as anything in recent_income)
		. += entry[2]

/// What the takings call a source that has no price row
/proc/outpost_income_source_label(source_key)
	switch(source_key)
		if(OUTPOST_SERVICE_SHOP)
			return "Shop sales"
		if(OUTPOST_INCOME_PRISON)
			return "Prison wing"
		if(OUTPOST_INCOME_EXPORTS)
			return "Exports"
	return source_key

/// Appends a line to the income ledger, dropping the oldest past OUTPOST_SERVICE_LEDGER_MAX
/obj/structure/overmap/dynamic/player_outpost/proc/add_service_ledger(service_key, label, payer_name, account_holder, amount)
	service_ledger += list(list(
		"time" = station_time_timestamp("hh:mm"),
		"service" = service_key,
		"label" = label,
		"payer" = payer_name,
		"account" = account_holder,
		"amount" = amount,
	))
	if(length(service_ledger) > OUTPOST_SERVICE_LEDGER_MAX)
		service_ledger.Cut(1, length(service_ledger) - OUTPOST_SERVICE_LEDGER_MAX + 1)

// ===== MAGIC RECALL =====

/**
 * Whether the summon item spell must leave an item inside `holder` (the shop's stock machine,
 * rented storage lockers). Called from the spell's container walk (summonitem.dm), which is
 * upstream code and cannot see Voidcrew defines.
 */
/proc/blocks_magic_recall(atom/movable/holder)
	return HAS_TRAIT(holder, TRAIT_BLOCKS_RECALL)

// ===== ROLE BOOKKEEPING =====

/// The delegated role list a console or manipulator action names, or null
/obj/structure/overmap/dynamic/player_outpost/proc/delegated_role_list(role)
	switch(role)
		if("steward")
			return stewards
		if("treasurer")
			return treasurers
		if("pricer")
			return pricers
	return null

/// Takes a character off the resident roster and out of every delegated role
/obj/structure/overmap/dynamic/player_outpost/proc/strip_resident(datum/mind/member)
	residents -= member
	stewards -= member
	treasurers -= member
	pricers -= member

/// Strips every character `player_key` plays from the roster and roles (blocking a player). Never the owner.
/obj/structure/overmap/dynamic/player_outpost/proc/strip_resident_by_ckey(player_key)
	if(!player_key || player_key == founder_ckey)
		return
	for(var/datum/mind/member as anything in residents | stewards | treasurers | pricers)
		if(QDELETED(member) || ckey(member.key) != player_key)
			continue
		strip_resident(member)

/// Called by abandon(): no pricers, default prices, no playtest billing, every room and door back to its defaults
/obj/structure/overmap/dynamic/player_outpost/proc/reset_market_on_abandon()
	pricers.Cut()
	reset_prices()
	playtest_visitor_ckey = null
	stop_all_bay_evictions()
	reset_door_access()
	for(var/datum/outpost_upgrade/service/room as anything in installed_service_rooms())
		room.on_outpost_abandoned()

/// Installed service rooms: catalog order, then any room outside the catalog (test rooms)
/obj/structure/overmap/dynamic/player_outpost/proc/installed_service_rooms()
	var/list/rooms = list()
	for(var/upgrade_id in GLOB.outpost_upgrade_catalog)
		var/datum/outpost_upgrade/service/room = service_upgrade(upgrade_id)
		if(room)
			rooms += room
	for(var/upgrade_id in outpost_upgrades)
		if(GLOB.outpost_upgrade_catalog[upgrade_id])
			continue
		var/datum/outpost_upgrade/service/room = service_upgrade(upgrade_id)
		if(room)
			rooms += room
	return rooms

// ===== MANAGEMENT CONSOLE (Pricing tab, room settings, bay eviction) =====

/datum/player_outpost_management_ui
	/// Why the last pricing, service room or eviction action was refused, or null. The user is told in chat.
	var/market_error

/**
 * The marketplace half of the console's ui_data(). Everything is in ui_data, never static
 * (a static push remounts the window). Keys are the spec 3.1.4 contract.
 */
/datum/player_outpost_management_ui/proc/market_ui_data(mob/user, list/data, can_manage)
	var/can_price = outpost.is_current_pricing_user(user)
	var/can_view_income = can_manage || can_price
	var/staff = can_view_income || outpost.is_current_treasury_user(user)
	data["can_view_income"] = can_view_income
	data["playtest_visitor"] = !!(outpost.playtest_visitor_ckey && user?.ckey == outpost.playtest_visitor_ckey)
	data["owner_crews"] = can_manage ? outpost.owner_crew_ui_data() : list()
	data["pricing"] = outpost.pricing_ui_data(user, can_view_income)
	data["services"] = staff ? service_rooms_ui_data(user, can_manage) : list()

/// One card per installed service room, with the room's own detail (service_ui_data())
/datum/player_outpost_management_ui/proc/service_rooms_ui_data(mob/user, can_manage)
	var/list/services = list()
	for(var/datum/outpost_upgrade/service/room as anything in outpost.installed_service_rooms())
		var/list/detail = room.service_ui_data(user)
		if(!islist(detail))
			detail = null
		services += list(list(
			"id" = room.id,
			"name" = room.name,
			"detail" = detail,
		))
	return services

/// Adds the bay's eviction state (the dock fee package fills it in) to its ship's `ships_here` row
/datum/player_outpost_management_ui/proc/bay_eviction_ui_data(datum/outpost_berth/ship_bay/bay, mob/user, list/row)
	row["evict_denial"] = "Not available."
	row["evicting"] = FALSE
	row["evict_eta"] = 0
	var/list/eviction = outpost.bay_eviction_row(bay, user)
	for(var/key in eviction)
		row[key] = eviction[key]

/**
 * Pricing, room settings and bay eviction actions. Each checks its own permission, so this runs
 * before the console's management gate. TRUE when the action was one of these. A refusal is kept
 * in market_error and told to the user in chat.
 */
/datum/player_outpost_management_ui/proc/market_action(action, list/params, mob/living/user)
	if(!(action in list("set_price", "service_act", "evict_bay_ship", "cancel_bay_eviction")))
		return FALSE
	market_error = null
	switch(action)
		if("set_price")
			market_error = outpost.set_price(user, params["key"], params["value"])
		if("service_act")
			var/datum/outpost_upgrade/service/room = outpost.service_upgrade(params["id"])
			var/service_action = params["service_action"]
			if(!room || !istext(service_action))
				market_error = "No such room."
			else
				room.service_ui_act(user, service_action, params)
		if("evict_bay_ship", "cancel_bay_eviction")
			var/datum/outpost_berth/ship_bay/bay = locate(params["ref"]) in outpost.bay_berths
			if(!outpost.is_current_management_user(user))
				market_error = "Not authorized."
			else if(!bay)
				market_error = "No such bay."
			else if(action == "evict_bay_ship")
				market_error = outpost.request_bay_eviction(user, bay)
			else
				market_error = outpost.cancel_bay_eviction(user, bay)
	if(market_error)
		to_chat(user, span_warning(market_error))
	return TRUE

/// The Pricing tab: every price, and income for those who may see it
/obj/structure/overmap/dynamic/player_outpost/proc/pricing_ui_data(mob/user, can_view_income)
	var/list/prices = list()
	for(var/key in GLOB.outpost_price_table)
		var/list/row = GLOB.outpost_price_table[key]
		prices += list(list(
			"key" = key,
			"label" = row["label"],
			"value" = get_price(key),
			"max" = row["max"],
			"available" = price_available(key),
		))
	var/list/ledger
	var/list/totals
	if(can_view_income)
		ledger = list()
		// Newest first, and only the last few
		var/oldest = max(1, length(service_ledger) - OUTPOST_SERVICE_LEDGER_SHOWN + 1)
		for(var/index in length(service_ledger) to oldest step -1)
			var/list/line = service_ledger[index]
			ledger += list(list(
				"time" = line["time"],
				"label" = line["label"],
				"who" = line["payer"] || line["account"],
				"amount" = line["amount"],
			))
		totals = list()
		for(var/service_key in service_totals)
			var/list/total = service_totals[service_key]
			var/list/price_row = GLOB.outpost_price_table[service_key]
			totals += list(list(
				"service" = service_key,
				"label" = price_row ? price_row["label"] : outpost_income_source_label(service_key),
				"total" = total["total"],
			))
	return list("prices" = prices, "ledger" = ledger, "totals" = totals, "last_hour" = can_view_income ? recent_income_total() : null)

/// The ship crews the owner's character belongs to. Everyone on them is a member here.
/obj/structure/overmap/dynamic/player_outpost/proc/owner_crew_ui_data()
	var/list/crews = list()
	var/datum/mind/owner_mind = founder_mind?.resolve()
	if(!owner_mind)
		return crews
	for(var/datum/team/voidcrew/team as anything in owner_mind.ship_teams)
		if(QDELETED(team))
			continue
		var/obj/structure/overmap/ship/ship = team.ship
		crews += ship ? ship.name : team.name
	return crews

// ===== OUTPOST MANIPULATOR (admin) =====

/// Adds the playtest billing toggle and each installed room's admin rows to the manipulator's selected outpost
/datum/outpost_manipulator/proc/market_admin_data(obj/structure/overmap/dynamic/player_outpost/home, list/selected_data)
	selected_data["playtest_visitor"] = home.playtest_visitor_ckey
	var/list/services = list()
	for(var/datum/outpost_upgrade/service/room as anything in home.installed_service_rooms())
		var/list/rows = room.admin_ui_data()
		services += list(list(
			"id" = room.id,
			"name" = room.name,
			"rows" = islist(rows) ? rows : list(),
		))
	selected_data["services"] = services

/datum/outpost_manipulator/proc/manage_market(obj/structure/overmap/dynamic/player_outpost/home, mob/user, action, list/params)
	switch(action)
		if("playtest_visitor")
			if(!user.ckey)
				return
			// Billing only: management and pricing permission are untouched
			var/billing = home.playtest_visitor_ckey != user.ckey
			home.playtest_visitor_ckey = billing ? user.ckey : null
			record(user, home, billing ? "bill themself as a visitor" : "stop billing themself as a visitor")
		if("service_admin")
			var/datum/outpost_upgrade/service/room = home.service_upgrade(params["id"])
			var/service_action = params["service_action"]
			if(!room || !istext(service_action))
				error = "No such room."
				return
			if(room.admin_ui_act(user, service_action, params) && !QDELETED(home))
				record(user, home, "[service_action] in the [room.name]")

/**
 * Voids every summon mark made on `item` before now: the next recall breaks the mark instead of
 * pulling the item. The shop's sale path calls this on each unit it sells, so a seller cannot mark
 * an item, sell it and recall it. Marks made after the sale (the buyer's own) still work. A plain
 * ADD_TRAIT(TRAIT_RECALL_SEVERED) only severs the first time; this re-adds it so every sale counts.
 */
/proc/sever_magic_recall(obj/item)
	if(QDELETED(item))
		return
	REMOVE_TRAIT(item, TRAIT_RECALL_SEVERED, null)
	ADD_TRAIT(item, TRAIT_RECALL_SEVERED, OUTPOST_SERVICE_TRAIT)

/datum/action/cooldown/spell/summonitem
	/// TRUE once the marked item gained TRAIT_RECALL_SEVERED after it was marked (sold by an outpost shop)
	var/mark_severed = FALSE

/datum/action/cooldown/spell/summonitem/mark_item(obj/to_mark)
	mark_severed = FALSE
	. = ..()
	RegisterSignal(to_mark, SIGNAL_ADDTRAIT(TRAIT_RECALL_SEVERED), PROC_REF(on_mark_severed))

/datum/action/cooldown/spell/summonitem/unmark_item()
	if(marked_item)
		UnregisterSignal(marked_item, SIGNAL_ADDTRAIT(TRAIT_RECALL_SEVERED))
	mark_severed = FALSE
	return ..()

/datum/action/cooldown/spell/summonitem/proc/on_mark_severed(datum/source)
	SIGNAL_HANDLER
	mark_severed = TRUE

/**
 * Called first in try_recall_item() (summonitem.dm, upstream, which cannot see Voidcrew defines).
 * TRUE when the mark was made before the item was sold: the mark is removed and the recall refused.
 */
/datum/action/cooldown/spell/summonitem/proc/recall_severed(mob/living/caster)
	if(!mark_severed || !marked_item || !HAS_TRAIT(marked_item, TRAIT_RECALL_SEVERED))
		return FALSE
	if(caster)
		to_chat(caster, span_warning("The mark broke when [marked_item] changed hands."))
	unmark_item()
	return TRUE
