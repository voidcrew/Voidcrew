/**
 * # Anomaly charts
 *
 * Boffin's other way to an anomaly core. A chart names one anomaly type. Buying
 * it uploads a sealed rumor to the buyer's ship like a ruin chart; the helm's
 * reveal button then picks the site, either a fresh ordinary derelict spawned in
 * the chart's zone band or a terrain planet already in that band, and charts it
 * under Rumors.
 *
 * Nothing spawns on reveal. The anomaly forms only when the BUYING hull docks at
 * that site, somewhere inside the derelict or out on the planet away from the
 * landing strip. A crew that gets there first finds an ordinary site. One chart
 * surfaces one anomaly, then the chart is spent.
 *
 * If the site is cleaned up before the buyer arrives (another crew loaded and
 * left a derelict, an admin deleted it), the chart goes back to the helm sealed
 * and can be revealed again for a new site. It dies with the buying hull.
 *
 * The anomalies are the site-bound planetary subtypes from
 * voidcrew/datums/mapgen/planet_anomalies.dm: immortal, stock behaviour, leashed
 * to the site they formed on.
 */

/// How far from the buyer's docking port a derelict anomaly prefers to form
#define ANOMALY_CHART_RUIN_MIN_DISTANCE 6
/// Rows of ground kept clear between a planet's landing strip and a chart anomaly
#define ANOMALY_CHART_PLANET_CLEARANCE 12
/// Random ground samples tried on a planet before giving up for this arrival
#define ANOMALY_CHART_PLANET_ATTEMPTS 400

/obj/structure/overmap/ship
	/// Revealed anomaly charts still waiting for this ship to dock at their site
	var/list/datum/rumor_chart/anomaly/active_anomaly_charts = list()

/datum/rumor_chart/anomaly
	name = "anomaly chart"
	reveal_noun = "anomaly site"
	keep_after_reveal = TRUE
	spawn_zone = ZONE_YELLOW
	/// The site-bound anomaly this chart surfaces
	var/obj/effect/anomaly/anomaly_type
	/// Percent chance the reveal tries a planet before a derelict
	var/planet_chance = 50
	/// The ship that revealed the chart; only its arrival surfaces the anomaly
	var/obj/structure/overmap/ship/buyer
	/// The revealed site
	var/datum/weakref/site_ref
	/// Set once the anomaly exists
	var/surfaced = FALSE

/datum/rumor_chart/anomaly/Destroy()
	release_site()
	if(buyer)
		UnregisterSignal(buyer, list(COMSIG_VOIDCREW_SHIP_DOCKED, COMSIG_QDELETING))
		buyer.active_anomaly_charts -= src
		buyer.pending_rumors -= src
		buyer = null
	return ..()

/datum/rumor_chart/anomaly/proc/waypoint_key()
	return "anomaly_[REF(src)]"

/datum/rumor_chart/anomaly/reveal(obj/structure/overmap/ship/ship)
	if(QDELETED(ship) || revealed || !ispath(anomaly_type, /obj/effect/anomaly))
		return null
	var/obj/structure/overmap/site = pick_site(ship)
	if(!site)
		return null

	revealed = TRUE
	buyer = ship
	site_ref = WEAKREF(site)
	ship.active_anomaly_charts |= src
	RegisterSignal(ship, COMSIG_VOIDCREW_SHIP_DOCKED, PROC_REF(on_buyer_docked))
	RegisterSignal(ship, COMSIG_QDELETING, PROC_REF(on_buyer_deleted))
	RegisterSignal(site, COMSIG_QDELETING, PROC_REF(on_site_deleted))

	var/list/coords = site.get_relative_overmap_coords()
	ship.add_waypoint(waypoint_key(), name, coords[1], coords[2], "Rumors", site)
	log_game("Anomaly chart '[name]' revealed for [ship]: [site] ([site.type]) at ([coords[1]], [coords[2]])")
	return site

/**
 * A planet or a fresh derelict in the chart's band, in random order, falling back
 * to the other kind when the first has nothing to offer.
 */
/datum/rumor_chart/anomaly/proc/pick_site(obj/structure/overmap/ship/ship)
	var/planet_first = prob(planet_chance)
	var/obj/structure/overmap/site = planet_first ? pick_planet(ship) : spawn_derelict()
	if(site)
		return site
	return planet_first ? spawn_derelict() : pick_planet(ship)

/// A terrain planet in the chart's band that the buyer is not already docked at
/datum/rumor_chart/anomaly/proc/pick_planet(obj/structure/overmap/ship/ship)
	var/list/candidates = list()
	for(var/obj/structure/overmap/planet/planet as anything in GLOB.overmap_planets)
		if(QDELETED(planet) || planet.unloading || !planet.is_terrain_planet())
			continue
		if(!istype(get_turf(planet), /turf/open/overmap))
			continue
		if(planet.get_effective_zone_band() != spawn_zone)
			continue
		// The anomaly waits for an arrival, so the site has to be somewhere to arrive at
		if(ship.docked == planet)
			continue
		candidates += planet
	if(!length(candidates))
		return null
	return pick(candidates)

/// A fresh ordinary derelict in the chart's band, left unloaded like any other signal
/datum/rumor_chart/anomaly/proc/spawn_derelict()
	var/list/live_templates = list()
	for(var/obj/structure/overmap/space_ruin/live as anything in GLOB.space_ruin_signals)
		if(!QDELETED(live) && live.ruin_template)
			live_templates[live.ruin_template] = TRUE

	var/list/weighted = list()
	var/list/weighted_duplicates = list()
	for(var/template_id in SSmapping.space_ruins_templates)
		var/datum/map_template/ruin/space/template = SSmapping.space_ruins_templates[template_id]
		if(!istype(template) || template.unpickable)
			continue
		// Oversized ruins take a whole z-level; keep charts to the ones that pack
		if(template.width && !SSovermap.ruin_fits_in_slot(template))
			continue
		if(live_templates[template])
			if(template.allow_duplicates)
				weighted_duplicates[template] = template.placement_weight || 1
			continue
		weighted[template] = template.placement_weight || 1
	if(!length(weighted))
		weighted = weighted_duplicates
	if(!length(weighted))
		return null

	var/turf/spawn_turf = SSovermap.get_unused_overmap_square_in_zone_band(spawn_zone)
	if(!spawn_turf)
		return null
	var/obj/structure/overmap/space_ruin/ruin = new(spawn_turf)
	ruin.set_ruin_template(pick_weight(weighted))
	ruin.no_replacement = TRUE
	return ruin

/datum/rumor_chart/anomaly/proc/on_buyer_docked(obj/structure/overmap/ship/source)
	SIGNAL_HANDLER
	if(surfaced)
		return
	var/obj/structure/overmap/site = site_ref?.resolve()
	if(!site || source.docked != site)
		return
	INVOKE_ASYNC(src, PROC_REF(surface_anomaly), site)

/**
 * The buyer has docked at the site: put the anomaly somewhere on it and tell the
 * crew. If no spot is found the chart stays live for the next arrival.
 */
/datum/rumor_chart/anomaly/proc/surface_anomaly(obj/structure/overmap/site)
	if(surfaced || QDELETED(src) || QDELETED(site) || QDELETED(buyer) || buyer.docked != site)
		return FALSE
	var/turf/spawn_turf = find_spawn_turf(site)
	if(!spawn_turf)
		buyer.ship_notify("Faint anomalous readings near [site.name], too unsteady to fix. They may settle on your next approach.", "SENSORS", SHIP_NOTIFY_WARNING, 'voidcrew/sound/warn.ogg', 25)
		return FALSE

	surfaced = TRUE
	var/obj/effect/anomaly/anomaly = new anomaly_type(spawn_turf)
	var/where = describe_position(spawn_turf)
	buyer.ship_notify("Anomalous readings: \a [anomaly] has formed [where].", "SENSORS", SHIP_NOTIFY_NOTICE, 'voidcrew/sound/notify.ogg', 50)
	log_game("Anomaly chart '[name]' surfaced [anomaly] at [AREACOORD(spawn_turf)] for [buyer]")
	qdel(src)
	return TRUE

/// "about 30 metres north of the ship", from the buyer's docking port
/datum/rumor_chart/anomaly/proc/describe_position(turf/spawn_turf)
	var/turf/ship_turf = get_turf(buyer?.shuttle)
	if(!ship_turf || ship_turf.z != spawn_turf.z)
		return "on the site"
	var/distance = get_dist(ship_turf, spawn_turf)
	var/direction = dir2text(get_dir(ship_turf, spawn_turf))
	if(!direction || distance < 2)
		return "right by the ship"
	return "about [distance] metres [direction] of the ship"

/datum/rumor_chart/anomaly/proc/find_spawn_turf(obj/structure/overmap/site)
	if(istype(site, /obj/structure/overmap/space_ruin))
		return find_derelict_turf(site)
	if(istype(site, /obj/structure/overmap/planet))
		return find_planet_turf(site)
	return null

/// Whether an anomaly may form on `candidate`: open walkable ground on the site itself
/datum/rumor_chart/anomaly/proc/is_valid_spot(turf/candidate, datum/map_footprint/footprint)
	if(!isopenturf(candidate) || isgroundlessturf(candidate) || isspaceturf(candidate))
		return FALSE
	if(islava(candidate) || istype(candidate, /turf/open/water))
		return FALSE
	if(candidate.is_blocked_turf(exclude_mobs = TRUE))
		return FALSE
	var/area/candidate_area = get_area(candidate)
	if(istype(candidate_area, /area/shuttle) || istype(candidate_area, /area/space))
		return FALSE
	if(footprint && !footprint.contains_turf(candidate))
		return FALSE
	if(locate(/obj/effect/anomaly) in candidate)
		return FALSE
	return TRUE

/// Open floor inside the derelict's own template, preferring a few steps from the ship
/datum/rumor_chart/anomaly/proc/find_derelict_turf(obj/structure/overmap/space_ruin/ruin)
	var/turf/corner = ruin.ruin_bottom_left
	if(!ruin.loaded || !corner || !ruin.ruin_template?.width || !ruin.ruin_template?.height)
		return null
	var/turf/far_corner = locate(corner.x + ruin.ruin_template.width - 1, corner.y + ruin.ruin_template.height - 1, corner.z)
	if(!far_corner)
		return null
	var/turf/ship_turf = get_turf(buyer?.shuttle)
	var/list/near = list()
	var/list/far = list()
	for(var/turf/candidate as anything in block(corner, far_corner))
		if(!is_valid_spot(candidate, ruin.footprint))
			continue
		if(ship_turf && get_dist(candidate, ship_turf) < ANOMALY_CHART_RUIN_MIN_DISTANCE)
			near += candidate
		else
			far += candidate
		CHECK_TICK
	if(length(far))
		return pick(far)
	if(length(near))
		return pick(near)
	return null

/// Open ground on the planet, well clear of the landing strip
/datum/rumor_chart/anomaly/proc/find_planet_turf(obj/structure/overmap/planet/planet)
	var/datum/map_footprint/footprint = planet.footprint
	if(!planet.loaded || !footprint || isnull(footprint.low_x))
		return null
	var/strip_top = planet.get_dock_strip_top_y(footprint.level)
	if(isnull(strip_top))
		strip_top = footprint.low_y
	var/min_x = footprint.low_x + 3
	var/max_x = footprint.high_x - 3
	var/max_y = footprint.high_y - 3
	var/min_y = min(strip_top + ANOMALY_CHART_PLANET_CLEARANCE, max_y)
	min_y = max(min_y, strip_top + 1)
	if(min_x > max_x || min_y > max_y)
		return null
	for(var/_ in 1 to ANOMALY_CHART_PLANET_ATTEMPTS)
		var/turf/candidate = locate(rand(min_x, max_x), rand(min_y, max_y), footprint.z_value)
		if(is_valid_spot(candidate, footprint))
			return candidate
	return null

/datum/rumor_chart/anomaly/proc/on_buyer_deleted(datum/source)
	SIGNAL_HANDLER
	qdel(src)

/datum/rumor_chart/anomaly/proc/on_site_deleted(datum/source)
	SIGNAL_HANDLER
	if(surfaced)
		return
	INVOKE_ASYNC(src, PROC_REF(reseal))

/// Forgets the site, drops the waypoint and stops listening to the site
/datum/rumor_chart/anomaly/proc/release_site()
	var/obj/structure/overmap/site = site_ref?.resolve()
	if(site)
		UnregisterSignal(site, COMSIG_QDELETING)
	site_ref = null
	if(buyer)
		var/datum/ship_waypoint/waypoint = buyer.get_waypoint(waypoint_key())
		if(waypoint)
			buyer.delete_waypoint(waypoint)

/**
 * The site vanished before the buyer arrived. The chart goes back on the helm,
 * sealed, so the crew can reveal it again for a new site.
 */
/datum/rumor_chart/anomaly/proc/reseal()
	if(QDELETED(src) || surfaced || QDELETED(buyer))
		return
	var/obj/structure/overmap/ship/ship = buyer
	release_site()
	UnregisterSignal(ship, list(COMSIG_VOIDCREW_SHIP_DOCKED, COMSIG_QDELETING))
	ship.active_anomaly_charts -= src
	buyer = null
	revealed = FALSE
	ship.pending_rumors |= src
	ship.ship_notify("The site on the \"[name]\" chart has dropped off the scopes. The chart is sealed again and can be revealed from the helm for a new fix.", "HELM", SHIP_NOTIFY_WARNING, 'voidcrew/sound/warn.ogg', 25)

/**
 * # Anomaly chart SKU
 *
 * Sold on Boffin's chart rotation. No goods change hands: the sealed chart goes
 * straight to the buyer's ship, and its reveal and arrival do the rest. Stock is
 * one, and a sold chart's slot turns over to a different anomaly at the next
 * convoy rather than refilling (see /datum/shop_rotation).
 */
/datum/shop_sku/anomaly_chart
	category = "Anomalies"
	icon_override = 'icons/obj/scrolls.dmi'
	icon_state_override = "blueprints"
	is_chart = TRUE
	stock_min = 1
	stock_max = 1
	contract_reward = FALSE
	/// The site-bound anomaly the chart surfaces
	var/obj/effect/anomaly/anomaly_type
	/// Zone band the chart's site is found in
	var/spawn_zone = ZONE_YELLOW

/datum/shop_sku/anomaly_chart/New()
	. = ..()
	if(!anomaly_type)
		return
	var/anomaly_name = initial(anomaly_type.name)
	var/band_name = spawn_zone == ZONE_RED ? ZONE_NAME_RED : ZONE_NAME_YELLOW
	name = "anomaly chart: [anomaly_name]"
	desc = "Sensor logs on \a [anomaly_name] settling somewhere in the [band_name], either aboard a derelict or out on a planet. Uploaded sealed to your helm. The readings only firm up once your own ship is docked at the site."

/datum/shop_sku/anomaly_chart/get_denial_reason(mob/living/user)
	. = ..()
	if(.)
		return
	if(!get_crew_ship(user))
		return "No crew registration, you need a ship to upload the chart to."

/datum/shop_sku/anomaly_chart/try_purchase(mob/living/user, mob/living/basic/outpost_trader/vendor)
	if(stock <= 0)
		return FALSE
	var/obj/structure/overmap/ship/ship = get_crew_ship(user)
	if(!ship)
		return FALSE

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
	ship.add_pending_rumor(create_chart())
	to_chat(user, span_notice("The chart is encrypted and beamed to [ship]'s helm console. Reveal it when your crew is ready to move."))
	return TRUE

/// A fresh sealed chart for one purchase
/datum/shop_sku/anomaly_chart/proc/create_chart()
	var/datum/rumor_chart/anomaly/chart = new
	var/anomaly_name = initial(anomaly_type.name)
	chart.name = capitalize(anomaly_name)
	chart.desc = "[capitalize("\a [anomaly_name]")] in the [spawn_zone == ZONE_RED ? ZONE_NAME_RED : ZONE_NAME_YELLOW]. Nothing will show on the site until your ship docks there."
	chart.anomaly_type = anomaly_type
	chart.spawn_zone = spawn_zone
	return chart

// Three bands, the same as the raw cores, at half the core's list price. Normal
// favor discounts and specials apply.
// The two rarest point into the lawless deep.

/datum/shop_sku/anomaly_chart/flux
	anomaly_type = /obj/effect/anomaly/flux/planetary
	price_credits = 12500

/datum/shop_sku/anomaly_chart/grav
	anomaly_type = /obj/effect/anomaly/grav/planetary
	price_credits = 12500

/datum/shop_sku/anomaly_chart/hallucination
	anomaly_type = /obj/effect/anomaly/hallucination/planetary
	price_credits = 12500

/datum/shop_sku/anomaly_chart/pyro
	anomaly_type = /obj/effect/anomaly/pyro/planetary
	price_credits = 12500

/datum/shop_sku/anomaly_chart/bioscrambler
	anomaly_type = /obj/effect/anomaly/bioscrambler/planetary
	price_credits = 15000

/datum/shop_sku/anomaly_chart/ectoplasm
	anomaly_type = /obj/effect/anomaly/ectoplasm/planetary
	price_credits = 15000

/datum/shop_sku/anomaly_chart/dimensional
	anomaly_type = /obj/effect/anomaly/dimensional/planetary
	price_credits = 15000

/datum/shop_sku/anomaly_chart/bluespace
	anomaly_type = /obj/effect/anomaly/bluespace/planetary
	price_credits = 17500
	spawn_zone = ZONE_RED

/datum/shop_sku/anomaly_chart/vortex
	anomaly_type = /obj/effect/anomaly/bhole/planetary
	price_credits = 17500
	spawn_zone = ZONE_RED

#undef ANOMALY_CHART_RUIN_MIN_DISTANCE
#undef ANOMALY_CHART_PLANET_CLEARANCE
#undef ANOMALY_CHART_PLANET_ATTEMPTS
