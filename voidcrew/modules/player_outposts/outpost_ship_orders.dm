/**
 * # Shipyard orders
 *
 * A new ship bought for credits at the shipyard console and built in the ship bay by its
 * drones, through the same staged construction that rebuilds checkpoints. The catalog is the
 * lobby shipyard's: every hull, theme and module a player could pick there, with the same
 * previews. Credits replace parts entirely: nothing needs unlocking.
 *
 * The order stands in for a ship record while the hidden copy loads. Upgrade slots read their
 * module and theme from SSshuttle.loading_order, so the copy is the map create_ship() would
 * load for the same choices, and no ship exists that anyone could join or claim until handover.
 * Nothing in the copy is scrubbed: a new ship comes with the starting supplies it spawns with.
 */

/// Pills are never built in a bay (user decision, 2026-09-24).
GLOBAL_LIST_INIT(ship_order_refused_hulls, typecacheof(list(
	/datum/map_template/shuttle/voidcrew/pill,
	/datum/map_template/shuttle/voidcrew/pill_black,
)))

/// Whether the shipyard console sells this hull: the lobby shelf, less the pills.
/proc/is_ship_order_hull(datum/map_template/shuttle/voidcrew/hull)
	return is_player_purchasable_ship(hull) && !is_type_in_typecache(hull, GLOB.ship_order_refused_hulls)

/// Every hull on the shipyard console's shelf, cheapest first.
/proc/get_ship_order_hulls()
	var/list/hulls = list()
	for(var/datum/map_template/shuttle/voidcrew/hull as anything in get_purchasable_ship_templates())
		if(is_ship_order_hull(hull))
			hulls += hull
	return hulls

/// Parts across every class in a part cost list.
/proc/ship_order_part_count(list/part_cost)
	. = 0
	for(var/part_class in part_cost)
		. += max(part_cost[part_class], 0)

/// Credits for a hull alone: its parts plus the shipyard fee.
/proc/ship_order_hull_price(datum/map_template/shuttle/voidcrew/hull)
	return ship_order_part_count(hull?.part_requirements) * OUTPOST_SHIP_ORDER_PART_PRICE + OUTPOST_SHIP_ORDER_FEE

/// Credits a theme adds. Default themes cost nothing.
/proc/ship_order_theme_price(datum/ship_theme/theme)
	if(!theme || theme.is_default)
		return 0
	return ship_order_part_count(theme.part_cost) * OUTPOST_SHIP_ORDER_PART_PRICE

/// Credits a module adds. Default modules cost nothing.
/proc/ship_order_module_price(datum/ship_upgrade_module/module)
	if(!module || module.is_default)
		return 0
	return ship_order_part_count(module.part_cost) * OUTPOST_SHIP_ORDER_PART_PRICE

/**
 * One configured ship: a hull from the shelf, its theme and a module per upgrade slot. The
 * same choices the lobby selector hands create_ship().
 */
/datum/ship_order
	/// The shelf's shared template. Read only; the build loads a fresh copy.
	var/datum/map_template/shuttle/voidcrew/hull
	var/hull_type
	var/datum/ship_theme/theme
	/// slot key -> /datum/ship_upgrade_module
	var/list/upgrade_selections = list()

/datum/ship_order/New(datum/map_template/shuttle/voidcrew/shelf_hull, datum/ship_theme/chosen_theme, list/selections)
	hull = shelf_hull
	hull_type = shelf_hull?.type
	theme = chosen_theme
	if(!theme && length(get_themes_for_ship(hull_type)))
		theme = get_default_theme_for_ship(hull_type)
	if(islist(selections))
		upgrade_selections = selections.Copy()
	else
		set_default_modules()

/datum/ship_order/Destroy()
	hull = null
	theme = null
	upgrade_selections = null
	return ..()

/datum/ship_order/proc/copy()
	return new /datum/ship_order(hull, theme, upgrade_selections)

/// The slots this hull loads under its theme.
/datum/ship_order/proc/slot_ids()
	if(!hull?.has_upgrade_slots)
		return list()
	return get_upgrade_slot_ids_for_theme(hull, theme)

/// Each slot's default module, as the lobby selector starts out.
/datum/ship_order/proc/set_default_modules()
	upgrade_selections = list()
	for(var/slot_key in slot_ids())
		var/datum/ship_upgrade_module/default_module = get_default_module_for_ship_slot(hull_type, slot_key)
		if(default_module && is_module_available_for_theme(default_module, theme?.id))
			upgrade_selections[slot_key] = default_module

/// Changes theme; module choices go back to the new theme's defaults.
/datum/ship_order/proc/set_theme(datum/ship_theme/new_theme)
	theme = new_theme
	set_default_modules()

/// Whether a module can go in this slot of this hull under this theme.
/datum/ship_order/proc/module_fits(datum/ship_upgrade_module/module, slot_key)
	if(!istype(module) || module.slot != slot_key || !(slot_key in slot_ids()))
		return FALSE
	var/list/modules = get_modules_for_ship(hull_type)
	return modules[module.id] == module && is_module_available_for_theme(module, theme?.id)

/// Why this configuration cannot be ordered, or null.
/datum/ship_order/proc/denial()
	if(!is_ship_order_hull(hull))
		return "That hull is not for sale here."
	var/list/themes = get_themes_for_ship(hull_type)
	if(length(themes))
		if(!theme || themes[theme.id] != theme)
			return "Choose a theme."
	else if(theme)
		return "That theme does not fit this hull."
	for(var/slot_key in upgrade_selections)
		if(!module_fits(upgrade_selections[slot_key], slot_key))
			return "A module does not fit this hull."
	return null

/// Every charge in the order, as list(label, credits), in display order.
/datum/ship_order/proc/price_lines()
	var/list/lines = list()
	lines += list(list("Shipyard fee", OUTPOST_SHIP_ORDER_FEE))
	var/hull_parts = ship_order_part_count(hull?.part_requirements)
	if(hull_parts)
		lines += list(list("Hull: [hull.name]", hull_parts * OUTPOST_SHIP_ORDER_PART_PRICE))
	var/theme_price = ship_order_theme_price(theme)
	if(theme_price)
		lines += list(list("Theme: [theme.name]", theme_price))
	for(var/slot_key in upgrade_selections)
		var/datum/ship_upgrade_module/module = upgrade_selections[slot_key]
		var/module_price = ship_order_module_price(module)
		if(module_price)
			lines += list(list("Module: [module.name]", module_price))
	return lines

/datum/ship_order/proc/price()
	. = 0
	for(var/list/line as anything in price_lines())
		. += line[2]

/// A fresh hull template pointed at this theme's map, exactly as create_ship() prepares one.
/datum/ship_order/proc/make_template()
	var/datum/map_template/shuttle/voidcrew/instance = new hull_type()
	apply_ship_theme(instance, theme)
	return instance

// ===== CONSTRUCTION =====

/// Builds a new ship from an order. Everything but the source is the checkpoint rebuild's.
/datum/checkpoint_construction/order
	status_verb = "Building"
	build_noun = "Construction"
	var/datum/ship_order/order
	/// Credits charged at the first piece.
	var/price = 0
	/// The account charged at commitment.
	var/datum/weakref/payer_account_ref
	/// When a ship's account pays: that ship, which the buyer must still command at commitment.
	var/datum/weakref/payer_ship_ref
	var/datum/weakref/buyer_mind_ref
	/// Admin testing: nothing is charged.
	var/free = FALSE
	/// What was actually charged, for tests and logs.
	var/charged = 0
	/// What sweep_leftovers() carried aboard, for tests and logs.
	var/list/swept_leftovers
	/// Non-effect things off the hull's rooms that stay with the hidden copy, for tests.
	var/list/left_behind

/datum/checkpoint_construction/order/New(datum/ship_checkpoint_ui/terminal, obj/structure/overmap/dynamic/player_outpost/site, datum/ship_order/new_order, mob/living/buyer, datum/bank_account/payer, obj/structure/overmap/ship/payer_ship, manual_drive = FALSE, free_build = FALSE)
	panel_ref = terminal ? WEAKREF(terminal) : null
	operator_ref = WEAKREF(buyer)
	order = new_order
	home = site
	captain_ckey = buyer?.ckey
	ship_name = order?.hull?.name || "New ship"
	manual = manual_drive
	free = free_build
	price = free ? 0 : order?.price()
	payer_account_ref = payer ? WEAKREF(payer) : null
	payer_ship_ref = payer_ship ? WEAKREF(payer_ship) : null
	buyer_mind_ref = buyer?.mind ? WEAKREF(buyer.mind) : null
	// Claim the bay before any yield, so a second request cannot reserve it too.
	bay = home?.reserve_rebuild_bay(src)
	if(!bay)
		state = CHECKPOINT_BUILD_FAILED
		return
	home.checkpoint_jobs += src
	RegisterSignal(home, COMSIG_QDELETING, PROC_REF(on_site_deleted))
	RegisterSignal(bay, COMSIG_QDELETING, PROC_REF(on_site_deleted))

/datum/checkpoint_construction/order/Destroy(force)
	. = ..()
	if(. == QDEL_HINT_LETMELIVE)
		return
	order = null

/datum/checkpoint_construction/order/source_denial()
	var/denial = order ? order.denial() : "The order is no longer available."
	if(denial)
		return denial
	return payer_denial()

/// Why the chosen payer cannot pay, or null. A ship's account pays only while the buyer commands it.
/datum/checkpoint_construction/order/proc/payer_denial()
	if(free)
		return null
	var/datum/bank_account/account = payer_account_ref?.resolve()
	if(QDELETED(account))
		return "The paying account is no longer available."
	if(payer_ship_ref)
		var/obj/structure/overmap/ship/paying_ship = payer_ship_ref.resolve()
		if(QDELETED(paying_ship) || paying_ship.abandoned || paying_ship.ship_account != account || !paying_ship.is_ship_captain_mind(buyer_mind_ref?.resolve()))
			return "You no longer command the paying ship."
	if(!account.has_money(price))
		return "Insufficient credits: [price] cr needed."
	return null

/datum/checkpoint_construction/order/unspent_note()
	return "Nothing was charged."

/datum/checkpoint_construction/order/create_template()
	return order.make_template()

/// Upgrade slots find their module and theme on the order while the copy loads.
/datum/checkpoint_construction/order/load_copy(datum/shuttle_template_load/load_owner)
	SSshuttle.loading_ship = null
	SSshuttle.loading_order = order
	. = load_hidden_copy(load_owner)
	SSshuttle.loading_order = null

/// Nothing is scrubbed or restored: the ship is built as it spawns, starting supplies included.
/datum/checkpoint_construction/order/prepare_copy()
	return

/// Charged once, here, immediately before the first piece. Short funds stop the job unpaid.
/datum/checkpoint_construction/order/consume_source()
	var/denial = payer_denial()
	if(denial)
		error = "[denial] [unspent_note()]"
		return FALSE
	if(!free)
		var/datum/bank_account/account = payer_account_ref.resolve()
		if(!account.adjust_money(-price, "Shipyard: [order.hull.name] at [home.name]"))
			error = "The payment was declined. [unspent_note()]"
			return FALSE
		charged = price
	committed = TRUE
	log_game("[captain_ckey] paid [charged] credits for a [order.hull.name] ([order.theme?.id || "no theme"]) at [home.name].")
	return TRUE

/// No refund once building starts; nothing was charged before.
/datum/checkpoint_construction/order/release_source()
	return

/// A new ship's loose supplies and creatures come aboard with the rest of its fittings.
/datum/checkpoint_construction/order/cargo_stage(atom/movable/thing)
	return CHECKPOINT_STAGE_FITTINGS

/// Creatures wander the hidden copy while they wait; each boards at the tile it was mapped on.
/datum/checkpoint_construction/order/place_piece(atom/movable/piece, turf/source, turf/target)
	if(!ismob(piece))
		return ..()
	if(QDELETED(piece) || !isturf(piece.loc) || !(piece.loc in source_turfs))
		return FALSE
	piece.forceMove(target)
	return TRUE

/**
 * Before the hidden copy is released: anything still on one of its hull tiles came into being
 * or moved there after planning (a creature that wandered, something a fitting made or pushed).
 * A whole-ship move would have carried it, so it comes aboard on its paired bay tile.
 */
/datum/checkpoint_construction/order/begin_commissioning()
	if(state == CHECKPOINT_BUILD_BUILDING && !QDELETED(port))
		sweep_leftovers()
	return ..()

/datum/checkpoint_construction/order/proc/sweep_leftovers()
	var/list/swept = list()
	for(var/index in hull_indices)
		var/turf/source = source_turfs[index]
		var/turf/target = bay_turfs[index]
		for(var/atom/movable/thing as anything in source.contents.Copy())
			if(thing == port || QDELETED(thing) || thing.loc != source)
				continue
			if(place_piece(thing, source, target))
				swept["[thing.type]"]++
	// What a real landing would leave behind too: anything off the hull's own rooms.
	var/list/left = list()
	for(var/turf/source as anything in source_turfs)
		if(source && port.shuttle_areas[source.loc])
			continue
		for(var/atom/movable/thing as anything in source?.contents)
			if(!iseffect(thing))
				left["[thing.type]"]++
	if(length(left))
		var/list/left_names = list()
		for(var/type_name in left)
			left_names += "[type_name] x[left[type_name]]"
		left_behind = left_names
	if(length(swept))
		var/list/names = list()
		for(var/type_name in swept)
			names += "[type_name] x[swept[type_name]]"
		log_game("[build_noun] of [ship_name] carried leftovers from the hidden copy: [names.Join(", ")]")
		swept_leftovers = names

/// A ship map can have fittings outside its rooms; nothing carries them out of the hidden copy.
/datum/checkpoint_construction/order/discard_source()
	clear_off_hull()
	return ..()

/// Batteries and fuel stay as the ship spawned with them.
/datum/checkpoint_construction/order/provision_machine(obj/machinery/machine)
	return

/// The same record create_ship() makes for these choices, starting funds included.
/datum/checkpoint_construction/order/create_vessel()
	var/obj/structure/overmap/ship/record = new(get_turf(home))
	if(length(order.upgrade_selections))
		record.upgrade_selections = order.upgrade_selections.Copy()
	record.theme = order.theme?.id || template.theme
	if(!record.setup_from_template(template, order.theme))
		qdel(record)
		return null
	return record

/// A new ship takes its hull's name, as a spawned one does.
/datum/checkpoint_construction/order/name_vessel()
	vessel.name = port.name
	ship_name = vessel.name

/datum/checkpoint_construction/order/after_ship_loaded()
	place_ship_landmarks(port)

/datum/checkpoint_construction/order/finished_text()
	return "built to order[free ? " (free)" : " for [charged] credits"]"

// ===== CONSOLE =====

/datum/ship_checkpoint_ui
	/// The configuration on the New ship tab.
	var/datum/ship_order/cart
	/// "personal", or the REF() of a ship the user commands.
	var/payer_choice = "personal"

/// Starts on the first hull of the shelf with its defaults.
/datum/ship_checkpoint_ui/proc/ensure_cart()
	if(cart)
		return cart
	var/list/hulls = get_ship_order_hulls()
	if(length(hulls))
		cart = new(hulls[1])
	return cart

/// Every account the user may pay with: their ID's, and each ship they command.
/datum/ship_checkpoint_ui/proc/payer_options(mob/living/user)
	var/list/options = list()
	var/datum/bank_account/personal = istype(user) ? user.get_bank_account() : null
	options += list(list("id" = "personal", "name" = "Personal account", "balance" = personal?.account_balance || 0, "available" = !!personal))
	for(var/obj/structure/overmap/ship/ship as anything in SSovermap.simulated_ships)
		if(QDELETED(ship) || ship.abandoned || QDELETED(ship.ship_account) || !ship.is_ship_captain(user))
			continue
		options += list(list("id" = REF(ship), "name" = "[ship.name] account", "balance" = ship.ship_account.account_balance, "available" = TRUE))
	return options

/// Resolves a payer choice: list(account, ship or null), or null.
/datum/ship_checkpoint_ui/proc/resolve_payer(mob/living/user, choice)
	if(choice == "personal")
		var/datum/bank_account/personal = istype(user) ? user.get_bank_account() : null
		return personal ? list(personal, null) : null
	var/obj/structure/overmap/ship/ship = locate(choice) in SSovermap.simulated_ships
	if(QDELETED(ship) || ship.abandoned || QDELETED(ship.ship_account) || !ship.is_ship_captain(user))
		return null
	return list(ship.ship_account, ship)

/// Why the user cannot order this now, or null.
/datum/ship_checkpoint_ui/proc/order_denial(mob/living/user, datum/ship_order/order, choice)
	if(QDELETED(src) || ui_status(user, GLOB.always_state) != UI_INTERACTIVE)
		return "Shipyard console unavailable."
	if(!order)
		return "Choose a hull."
	var/denial = order.denial()
	if(denial)
		return denial
	if(!outpost.available_ship_bay())
		return "The ship bay is occupied or reserved."
	var/list/payer = resolve_payer(user, choice)
	if(!payer)
		return choice == "personal" ? "Hold your ID to pay from your account." : "You do not command that ship."
	var/datum/bank_account/account = payer[1]
	if(!account.has_money(order.price()))
		return "Insufficient credits."
	return null

/datum/ship_checkpoint_ui/proc/confirm_order(mob/user, prompt_text)
	return tgui_alert(user, prompt_text, "Shipyard", list("Confirm", "Cancel")) == "Confirm"

/datum/ship_checkpoint_ui/proc/create_order_job(mob/living/user, datum/ship_order/order, datum/bank_account/account, obj/structure/overmap/ship/paying_ship)
	return new /datum/checkpoint_construction/order(src, outpost, order, user, account, paying_ship)

/// Orders the cart. Returns TRUE once the hidden copy is loaded and marked out. Nothing is
/// charged until the first piece is placed.
/datum/ship_checkpoint_ui/proc/place_order(mob/living/user)
	if(working)
		return FALSE
	error = order_denial(user, cart, payer_choice)
	if(error)
		return FALSE
	var/datum/ship_order/order = cart.copy()
	var/choice = payer_choice
	var/price = order.price()
	var/list/payer = resolve_payer(user, choice)
	var/obj/structure/overmap/ship/paying_ship = payer[2]
	working = TRUE
	notice = null
	var/accepted = confirm_order(user, "Order a [order.hull.name][order.theme ? " ([order.theme.name])" : ""] for [price] credits from [paying_ship ? "the [paying_ship.name] account" : "your personal account"]? The credits are spent when construction begins.")
	if(QDELETED(src))
		qdel(order)
		return FALSE
	working = FALSE
	if(!accepted)
		qdel(order)
		return FALSE
	// Anything may have changed while the prompt was open.
	error = order_denial(user, order, choice)
	payer = resolve_payer(user, choice)
	if(!error && (payer?[2] != paying_ship || order.price() != price))
		error = "The order changed. Try again."
	if(error)
		qdel(order)
		return FALSE
	working = TRUE
	var/datum/checkpoint_construction/order/job = create_order_job(user, order, payer[1], paying_ship)
	var/started = FALSE
	if(job.bay)
		started = job.prepare()
	else
		job.error = "The ship bay is occupied or reserved."
		qdel(job)
	if(QDELETED(src))
		return started
	working = FALSE
	if(started)
		error = null
		notice = "Construction started. [price] cr is charged when the first piece is placed."
		log_game("[key_name(user)] ordered a [order.hull.name] at [outpost.name] for [price] credits.")
	else
		error = job.error || "Construction failed. Nothing was charged."
	return started

/// The whole shelf, sent once: hulls, themes, modules, prices and preview art.
/datum/ship_checkpoint_ui/proc/shop_static_data()
	var/list/hulls = list()
	for(var/datum/map_template/shuttle/voidcrew/hull as anything in get_ship_order_hulls())
		var/list/themes = list()
		var/list/theme_list = get_themes_for_ship(hull.type)
		var/list/slots_by_theme = list()
		for(var/theme_id in theme_list)
			var/datum/ship_theme/theme = theme_list[theme_id]
			var/crew = 0
			for(var/list/job_definition in theme.job_slots)
				crew += job_definition["slots"]
			themes += list(list(
				"id" = theme.id,
				"name" = theme.name,
				"desc" = theme.desc,
				"is_default" = theme.is_default,
				"price" = ship_order_theme_price(theme),
				"crew" = crew,
			))
			slots_by_theme[theme.id] = hull.has_upgrade_slots ? get_upgrade_slot_ids_for_theme(hull, theme) : list()
		if(!length(theme_list))
			slots_by_theme[""] = hull.has_upgrade_slots ? hull.upgrade_slot_ids : list()
		var/list/modules = list()
		var/list/module_list = get_modules_for_ship(hull.type)
		for(var/module_id in module_list)
			var/datum/ship_upgrade_module/module = module_list[module_id]
			var/list/for_themes = islist(module.for_theme) ? module.for_theme : (module.for_theme ? list(module.for_theme) : list())
			modules += list(list(
				"id" = module.id,
				"name" = module.name,
				"desc" = module.desc,
				"slot" = module.slot,
				"is_default" = module.is_default,
				"price" = ship_order_module_price(module),
				"themes" = for_themes,
			))
		var/crew = 0
		var/list/crew_slots = hull.job_slots
		if(!length(crew_slots) && length(theme_list))
			var/datum/ship_theme/default_theme = get_default_theme_for_ship(hull.type)
			crew_slots = default_theme?.job_slots
		for(var/list/job_definition in crew_slots)
			crew += job_definition["slots"]
		hulls += list(list(
			"id" = "[hull.type]",
			"name" = hull.name,
			"description" = hull.catalog_desc || generate_ship_description(hull),
			"price" = ship_order_hull_price(hull),
			"crew" = crew,
			"themes" = themes,
			"slots_by_theme" = slots_by_theme,
			"modules" = modules,
			"preview" = build_ship_preview_data(hull),
		))
	return list("catalog" = hulls, "part_price" = OUTPOST_SHIP_ORDER_PART_PRICE, "order_fee" = OUTPOST_SHIP_ORDER_FEE)

/// The cart and the payers, small enough to send every update.
/datum/ship_checkpoint_ui/proc/shop_data(mob/living/user)
	var/datum/ship_order/order = ensure_cart()
	if(!order)
		return null
	var/list/selections = list()
	for(var/slot_key in order.upgrade_selections)
		var/datum/ship_upgrade_module/module = order.upgrade_selections[slot_key]
		selections[slot_key] = module.id
	var/list/lines = list()
	for(var/list/line as anything in order.price_lines())
		lines += list(list("label" = line[1], "amount" = line[2]))
	return list(
		"hull" = "[order.hull_type]",
		"theme" = order.theme?.id,
		"selections" = selections,
		"lines" = lines,
		"price" = order.price(),
		"payers" = payer_options(user),
		"payer" = payer_choice,
		"denial" = order_denial(user, order, payer_choice),
	)

/// Shop actions. Returns TRUE when the action was one of them.
/datum/ship_checkpoint_ui/proc/shop_act(mob/living/user, action, list/params)
	switch(action)
		if("shop_hull")
			for(var/datum/map_template/shuttle/voidcrew/hull as anything in get_ship_order_hulls())
				if("[hull.type]" == params["id"])
					QDEL_NULL(cart)
					cart = new(hull)
					break
			return TRUE
		if("shop_theme")
			var/datum/ship_order/order = ensure_cart()
			var/list/themes = get_themes_for_ship(order?.hull_type)
			var/datum/ship_theme/theme = themes[params["id"]]
			if(theme)
				order.set_theme(theme)
			return TRUE
		if("shop_module")
			var/datum/ship_order/order = ensure_cart()
			var/list/modules = get_modules_for_ship(order?.hull_type)
			var/datum/ship_upgrade_module/module = modules[params["id"]]
			if(order?.module_fits(module, params["slot"]))
				order.upgrade_selections[params["slot"]] = module
			return TRUE
		if("shop_payer")
			payer_choice = params["id"] == "personal" ? "personal" : "[params["id"]]"
			return TRUE
		if("shop_buy")
			place_order(user)
			return TRUE
	return FALSE
