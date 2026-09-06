/**
 * # Rumor Charts
 *
 * Specific-ruin intel sold by outpost traders. Each chart names one rare ruin
 * template, a template that never seeds naturally, only through a chart.
 * Buying one uploads a sealed rumor to the buyer's ship; the helm's "reveal"
 * button then spawns the ruin at an uncharted square in the chart's zone band,
 * marks it on the helm readout and paints the overmap signal gold.
 *
 * Each purchased chart reveals one fresh encounter, with normal ruin cleanup.
 * The generic coordinate-tip rumor (/datum/shop_sku/rumor) is a separate, much
 * cheaper thing and every outpost sells it. Both live in shop_catalog_charts.dm;
 * this file is the reveal machinery.
 */

/**
 * # Sealed rumor
 *
 * One purchased-but-unrevealed rumor riding on a ship, shown on the helm with
 * a reveal button. Revealing spawns the rare ruin and converts this datum into
 * a charted waypoint.
 */
/datum/rumor_chart
	/// Rumor title shown on the helm and used as the waypoint name
	var/name = "sealed rumor"
	/// Flavor blurb shown on the helm before reveal
	var/desc = ""
	/// The rare ruin template revealing this chart spawns
	var/datum/map_template/ruin/space/ruin_template_path
	/// Zone band the ruin spawns in (rare tips point at the dangerous deep)
	var/spawn_zone = ZONE_RED
	/// One successful reveal per paid chart; failed placement remains retryable.
	var/revealed = FALSE

/**
 * Spawns the chart's ruin at an unused square in the chart's zone band and
 * charts it on the ship's helm. Returns the new overmap ruin, or null if no
 * clear square could be found (the rumor stays sealed so it can be retried).
 */
/datum/rumor_chart/proc/reveal(obj/structure/overmap/ship/ship)
	if(QDELETED(ship) || !ruin_template_path || revealed)
		return null

	// SSmapping's instance is the canonical, size-preloaded template
	var/datum/map_template/ruin/space/template
	for(var/template_name in SSmapping.space_ruins_templates)
		var/datum/map_template/ruin/space/candidate = SSmapping.space_ruins_templates[template_name]
		if(candidate.type == ruin_template_path)
			template = candidate
			break
	if(!template)
		stack_trace("Rumor chart [name] points at unregistered ruin template [ruin_template_path]")
		return null

	var/turf/spawn_turf = SSovermap.get_unused_overmap_square_in_zone_band(spawn_zone)
	if(!spawn_turf)
		return null

	var/obj/structure/overmap/space_ruin/ruin = new(spawn_turf)
	ruin.set_ruin_template(template)
	ruin.mark_rare()
	revealed = TRUE

	var/list/coords = ruin.get_relative_overmap_coords()
	ship.add_waypoint("rumor_[REF(ruin)]", name, coords[1], coords[2], "Rumors", ruin)
	log_mapping("Rumor chart revealed: spawned rare ruin '[template.name]' at ([coords[1]], [coords[2]]) for [ship]")
	return ruin

/obj/structure/overmap/ship
	/// Sealed rumors bought from traders, waiting on the helm's reveal button
	var/list/datum/rumor_chart/pending_rumors = list()

/**
 * Uploads a sealed rumor to this ship and tells the crew it landed.
 */
/obj/structure/overmap/ship/proc/add_pending_rumor(datum/rumor_chart/chart)
	pending_rumors += chart
	ship_notify("Encrypted rumor data received: \"[chart.name]\". Reveal it from the helm console when ready.", "HELM", SHIP_NOTIFY_NOTICE, 'voidcrew/sound/notify.ogg', 50)

/**
 * Reveals a pending rumor: spawns its ruin, charts the waypoint and consumes
 * the sealed entry. Returns the ruin, or null on failure (entry is kept).
 */
/obj/structure/overmap/ship/proc/reveal_pending_rumor(datum/rumor_chart/chart)
	if(!(chart in pending_rumors))
		return null
	var/obj/structure/overmap/space_ruin/ruin = chart.reveal(src)
	if(!ruin)
		return null
	pending_rumors -= chart
	qdel(chart)
	return ruin

/**
 * Gets an unused overmap square in the given zone band (ZONE_RED/YELLOW/GREEN).
 * Same contract as get_unused_overmap_square_in_green_zone, any band.
 */
/datum/controller/subsystem/overmap/proc/get_unused_overmap_square_in_zone_band(band, thing_not_to_have = /obj/structure/overmap, tries = MAX_OVERMAP_PLACEMENT_ATTEMPTS)
	for(var/_ in 1 to tries)
		var/turf/candidate = pick(block(locate(OVERMAP_LEFT_SIDE_COORD + 1, OVERMAP_SOUTH_SIDE_COORD + 1, OVERMAP_Z_LEVEL), locate(OVERMAP_RIGHT_SIDE_COORD - 1, OVERMAP_NORTH_SIDE_COORD - 1, OVERMAP_Z_LEVEL)))
		if(locate(thing_not_to_have) in candidate)
			continue
		if(get_zone_band_for_turf(candidate) != band)
			continue
		return candidate
	return null

/**
 * # Rumor chart SKU
 *
 * The storefront line for one specific rare ruin. No goods change hands: on
 * purchase the sealed rumor lands straight on the buyer's ship. Each purchase
 * reveals a fresh instance, even if this crew or another already visited one.
 */
/datum/shop_sku/ruin_chart
	category = "Intel & Charts"
	icon_override = 'icons/obj/scrolls.dmi'
	icon_state_override = "blueprints"
	is_chart = TRUE
	stock_min = 1
	stock_max = 1
	/// The rare ruin template this chart reveals
	var/ruin_template_path
	/// Rumor title pushed to the helm (defaults to the SKU name)
	var/rumor_name
	/// Rumor blurb pushed to the helm (defaults to the SKU desc)
	var/rumor_desc
	/// Zone band the ruin spawns in on reveal
	var/spawn_zone = ZONE_RED

/datum/shop_sku/ruin_chart/get_denial_reason(mob/living/user)
	. = ..()
	if(.)
		return
	var/obj/structure/overmap/ship/ship = get_crew_ship(user)
	if(!ship)
		return "No crew registration, you need a ship to upload the rumor to."

/datum/shop_sku/ruin_chart/try_purchase(mob/living/user, mob/living/basic/outpost_trader/vendor)
	if(stock <= 0)
		return FALSE
	var/obj/structure/overmap/ship/ship = get_crew_ship(user)
	if(!ship)
		return FALSE

	// Validate the credit half before consuming any vouchers. User passed so
	// the charge matches the favor-discounted price the UI shows them.
	var/credit_price = get_credit_price(user)
	var/datum/bank_account/account
	if(credit_price > 0)
		account = get_account(user)
		if(!account || !account.has_money(credit_price))
			return FALSE

	if(price_vouchers > 0 && !consume_trade_vouchers(user, price_vouchers))
		return FALSE
	if(credit_price > 0 && !account.adjust_money(-credit_price, "Trader Outpost: [name]"))
		return FALSE

	stock--

	var/datum/rumor_chart/chart = new
	chart.name = rumor_name || name
	chart.desc = rumor_desc || desc
	chart.ruin_template_path = ruin_template_path
	chart.spawn_zone = spawn_zone
	ship.add_pending_rumor(chart)

	to_chat(user, span_notice("The rumor data is encrypted and beamed to [ship]'s helm console. Reveal it when your crew is ready to move."))
	return TRUE
