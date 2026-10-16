/**
 * # Rumor Charts
 *
 * Specific-ruin intel sold by outpost traders. Each chart names one rare ruin
 * template, a template that never seeds naturally, only through a chart.
 * Buying one uploads a sealed rumor to the buyer's ship; the helm's "reveal"
 * button then spawns the ruin at an uncharted square in the chart's zone band,
 * marks it on the helm readout and paints the overmap signal gold.
 *
 * Each template has one site per round, with normal ruin cleanup. Later charts
 * lead to that same site; once it retires, no chart can create another vault.
 * The generic coordinate-tip rumor (/datum/shop_sku/rumor) is a separate, much
 * cheaper thing and every outpost sells it. Both live in shop_catalog_charts.dm;
 * this file is the reveal machinery.
 */

#define COMSIG_RUIN_CHART_SITE_RETIRED "ruin_chart_site_retired"

/// Round-wide template registry. Entries survive ships and site cleanup as tombstones.
GLOBAL_LIST_EMPTY(ruin_chart_sites)

/proc/get_ruin_chart_site(template_path)
	var/datum/ruin_chart_site/entry = GLOB.ruin_chart_sites[template_path]
	if(!entry)
		entry = new(template_path)
		GLOB.ruin_chart_sites[template_path] = entry
	return entry

/datum/ruin_chart_site
	var/template_path
	var/datum/weakref/site_ref
	var/claimed = FALSE
	var/retired = FALSE

/datum/ruin_chart_site/New(template_path)
	src.template_path = template_path

/datum/ruin_chart_site/Destroy()
	var/obj/structure/overmap/space_ruin/site = site_ref?.resolve()
	if(site)
		UnregisterSignal(site, COMSIG_QDELETING)
	site_ref = null
	if(GLOB.ruin_chart_sites[template_path] == src)
		GLOB.ruin_chart_sites -= template_path
	return ..()

/// Claim before creation can yield. A competing reveal stays sealed and can retry.
/datum/ruin_chart_site/proc/get_or_create(spawn_zone)
	if(retired || claimed)
		return null
	var/obj/structure/overmap/space_ruin/site = site_ref?.resolve()
	if(site)
		return site
	claimed = TRUE
	site = create_site(spawn_zone)
	claimed = FALSE
	if(QDELETED(site))
		return null
	site_ref = WEAKREF(site)
	RegisterSignal(site, COMSIG_QDELETING, PROC_REF(on_site_retired))
	return site

/datum/ruin_chart_site/proc/create_site(spawn_zone)
	// SSmapping's instance is the canonical, size-preloaded template.
	var/datum/map_template/ruin/space/template
	for(var/template_name in SSmapping.space_ruins_templates)
		var/datum/map_template/ruin/space/candidate = SSmapping.space_ruins_templates[template_name]
		if(candidate.type == template_path)
			template = candidate
			break
	if(!template)
		stack_trace("Rumor chart points at unregistered ruin template [template_path]")
		return null
	var/turf/spawn_turf = SSovermap.get_unused_overmap_square_in_zone_band(spawn_zone)
	if(!spawn_turf)
		return null
	var/obj/structure/overmap/space_ruin/site = new(spawn_turf)
	if(QDELETED(site))
		return null
	site.set_ruin_template(template)
	site.mark_rare()
	return site

/datum/ruin_chart_site/proc/on_site_retired(datum/source)
	SIGNAL_HANDLER
	UnregisterSignal(source, COMSIG_QDELETING)
	site_ref = null
	retired = TRUE
	SEND_SIGNAL(src, COMSIG_RUIN_CHART_SITE_RETIRED)

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
	/// What the helm calls the revealed target in its readout
	var/reveal_noun = "rare signal"
	/// Charts with work left after the reveal (anomaly charts wait for the crew to
	/// arrive) manage their own lifetime instead of being deleted on reveal.
	var/keep_after_reveal = FALSE
	/// Exact payment and original recipients, used only while a named chart is sealed.
	var/paid_credits = 0
	var/paid_vouchers = 0
	var/datum/weakref/payment_account_ref
	var/datum/weakref/purchaser_ref
	var/datum/weakref/purchaser_mind_ref
	var/datum/weakref/pending_ship_ref
	var/datum/ruin_chart_site/registered_site

/datum/rumor_chart/Destroy()
	if(registered_site)
		UnregisterSignal(registered_site, COMSIG_RUIN_CHART_SITE_RETIRED)
	registered_site = null
	var/obj/structure/overmap/ship/ship = pending_ship_ref?.resolve()
	ship?.pending_rumors.Remove(src)
	payment_account_ref = null
	purchaser_ref = null
	purchaser_mind_ref = null
	pending_ship_ref = null
	return ..()

/// Subscribe before the first reveal, so outstanding paid copies are refunded.
/datum/rumor_chart/proc/watch_registered_site(obj/structure/overmap/ship/ship)
	pending_ship_ref = WEAKREF(ship)
	if(!ruin_template_path || registered_site)
		return
	registered_site = get_ruin_chart_site(ruin_template_path)
	RegisterSignal(registered_site, COMSIG_RUIN_CHART_SITE_RETIRED, PROC_REF(refund_retired_site))
	if(registered_site.retired)
		refund_retired_site()

/datum/rumor_chart/proc/refund_retired_site(datum/source)
	SIGNAL_HANDLER
	if(revealed || QDELETED(src))
		return
	// Consume the refund before creating physical currency or notifying anyone.
	var/credits = paid_credits
	var/vouchers = paid_vouchers
	paid_credits = 0
	paid_vouchers = 0
	var/datum/bank_account/account = payment_account_ref?.resolve()
	if(credits && account)
		account.adjust_money(credits, "Retired rumor: [name]")
	var/datum/mind/purchaser_mind = purchaser_mind_ref?.resolve()
	var/mob/living/purchaser = purchaser_mind?.current || purchaser_ref?.resolve()
	var/obj/structure/overmap/ship/ship = pending_ship_ref?.resolve()
	var/atom/refund_location = purchaser ? purchaser.drop_location() : get_turf(ship?.shuttle)
	if(vouchers && refund_location)
		var/obj/item/stack/trade_voucher/refund = new(refund_location, vouchers)
		purchaser?.put_in_hands(refund)
	if(purchaser)
		to_chat(purchaser, span_notice("The signal has gone dark. Your payment was returned."))
	qdel(src)

/**
 * Charts the template's round-wide site, creating it only on the first reveal.
 * Failed placement or a competing claim leaves the chart sealed for a retry.
 */
/datum/rumor_chart/proc/reveal(obj/structure/overmap/ship/ship)
	if(QDELETED(ship) || !ruin_template_path || revealed)
		return null

	var/datum/ruin_chart_site/entry = get_ruin_chart_site(ruin_template_path)
	if(entry.retired)
		refund_retired_site()
		return null
	var/obj/structure/overmap/space_ruin/ruin = entry.get_or_create(spawn_zone)
	if(QDELETED(ruin) || QDELETED(src) || QDELETED(ship))
		return null
	revealed = TRUE

	var/list/coords = ruin.get_relative_overmap_coords()
	ship.add_waypoint("rumor_[REF(ruin)]", name, coords[1], coords[2], "Rumors", ruin)
	log_mapping("Rumor chart revealed: charted rare ruin '[ruin.ruin_template.name]' at ([coords[1]], [coords[2]]) for [ship]")
	return ruin

/obj/structure/overmap/ship
	/// Sealed rumors bought from traders, waiting on the helm's reveal button
	var/list/datum/rumor_chart/pending_rumors = list()

/**
 * Uploads a sealed rumor to this ship and tells the crew it landed.
 */
/obj/structure/overmap/ship/proc/add_pending_rumor(datum/rumor_chart/chart)
	pending_rumors += chart
	chart.watch_registered_site(src)
	if(!QDELETED(chart))
		ship_notify("Encrypted rumor data received: \"[chart.name]\".", "HELM", SHIP_NOTIFY_NOTICE, 'voidcrew/sound/notify.ogg', 50)

/**
 * Reveals a pending rumor: spawns or picks its site, charts the waypoint and
 * consumes the sealed entry. Returns the site, or null on failure (entry is kept).
 */
/obj/structure/overmap/ship/proc/reveal_pending_rumor(datum/rumor_chart/chart)
	if(!(chart in pending_rumors))
		return null
	var/obj/structure/overmap/site = chart.reveal(src)
	if(!site)
		return null
	pending_rumors -= chart
	if(!chart.keep_after_reveal)
		qdel(chart)
	return site

/**
 * Gets an unused overmap square in the given zone band (ZONE_RED/YELLOW/GREEN).
 * Same contract as get_unused_overmap_square_in_green_zone, any band, except that it
 * only returns null when the band has no free square at all.
 */
/datum/controller/subsystem/overmap/proc/get_unused_overmap_square_in_zone_band(band, thing_not_to_have = /obj/structure/overmap, tries = MAX_OVERMAP_PLACEMENT_ATTEMPTS)
	var/list/turf/overmap_squares = block(locate(OVERMAP_LEFT_SIDE_COORD + 1, OVERMAP_SOUTH_SIDE_COORD + 1, OVERMAP_Z_LEVEL), locate(OVERMAP_RIGHT_SIDE_COORD - 1, OVERMAP_NORTH_SIDE_COORD - 1, OVERMAP_Z_LEVEL))
	for(var/_ in 1 to tries)
		var/turf/candidate = pick(overmap_squares)
		if(locate(thing_not_to_have) in candidate)
			continue
		if(get_zone_band_for_turf(candidate) != band)
			continue
		return candidate
	// Random picks over the whole chart often miss a narrow band. Green is ~9% of the
	// squares and every hull spawns there: with 130 green squares free, 40 picks still
	// found none about one time in nine. Check every square before giving up.
	var/list/turf/free_squares = list()
	for(var/turf/candidate as anything in overmap_squares)
		if(get_zone_band_for_turf(candidate) != band)
			continue
		if(locate(thing_not_to_have) in candidate)
			continue
		free_squares += candidate
	return length(free_squares) ? pick(free_squares) : null

/**
 * # Rumor chart SKU
 *
 * The storefront line for one specific rare ruin. No goods change hands: on
 * purchase the sealed rumor lands straight on the buyer's ship. All purchases
 * of a template chart the same site, until that site retires for the round.
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
	var/datum/ruin_chart_site/entry = GLOB.ruin_chart_sites[ruin_template_path]
	if(entry?.retired)
		return "That signal has gone dark."
	var/obj/structure/overmap/ship/ship = get_crew_ship(user)
	if(!ship)
		return "No crew registration."

/datum/shop_sku/ruin_chart/try_purchase(mob/living/user, mob/living/basic/outpost_trader/vendor)
	if(stock <= 0)
		return FALSE
	var/datum/ruin_chart_site/entry = GLOB.ruin_chart_sites[ruin_template_path]
	if(entry?.retired)
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
	chart.paid_credits = credit_price
	chart.paid_vouchers = price_vouchers
	chart.payment_account_ref = WEAKREF(account)
	chart.purchaser_ref = WEAKREF(user)
	chart.purchaser_mind_ref = WEAKREF(user.mind)
	ship.add_pending_rumor(chart)

	to_chat(user, span_notice("Encrypted rumor data received by [ship]."))
	metric_shop_purchase(src, user, credit_price, price_vouchers)
	return TRUE

#undef COMSIG_RUIN_CHART_SITE_RETIRED
