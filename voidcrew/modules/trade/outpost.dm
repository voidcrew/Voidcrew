/**
 * # Trader Outpost
 *
 * Static, permanent, invincible trade station on the overmap. One-ish per zone;
 * the shop type matches the zone (deep-zone black market sells syndicate gear).
 *
 * Unlike space ruins, outposts never unload, never move and never respawn.
 * The interior is lazy-loaded on first dock and then stays for the round.
 * The structure is indestructible by construction (CentCom-style turfs and
 * machinery); the deterrent against aggression is economic (turrets plus a
 * per-ship trade embargo), not HP.
 */

/// All trader outposts on the overmap (used by vouchers/missions to list trader locations)
GLOBAL_LIST_EMPTY(trader_outposts)

/area/voidcrew/trader_outpost
	name = "\improper Trader Outpost"
	icon_state = "away"
	static_lighting = TRUE
	requires_power = FALSE
	default_gravity = STANDARD_GRAVITY
	area_flags = UNIQUE_AREA | NOTELEPORT
	flags_1 = NONE
	ambience_index = AMBIENCE_AWAY
	repels_megafauna = TRUE // voidcrew/area/megafauna_ban.dm

// Each zone variant loads its own interior (split from the old shared
// trader_outpost.dmm on 2026-07-06). Base type is abstract: no mappath.
/datum/map_template/trader_outpost
	name = "Trader Outpost"

/datum/map_template/trader_outpost/black_market
	name = "Trader Outpost - Undertow Exchange"
	mappath = "voidcrew/_maps/map_files/outposts/trader_outpost_black_market.dmm"

/datum/map_template/trader_outpost/outfitter
	name = "Trader Outpost - Quartermain Depot"
	mappath = "voidcrew/_maps/map_files/outposts/trader_outpost_outfitter.dmm"

/datum/map_template/trader_outpost/general
	name = "Trader Outpost - Waystation Halcyon"
	mappath = "voidcrew/_maps/map_files/outposts/trader_outpost_general.dmm"

/obj/structure/overmap/trader_outpost
	name = "trader outpost"
	desc = "An independent trade station broadcasting an open docking invitation. Its hull shrugs off weapons fire."
	icon_state = "station"
	// Outposts broadcast their position sector-wide, so the helm lists them from
	// GLOB.trader_outposts at any range: the sensor bubble would only duplicate it.
	sensor_visible = FALSE

	/// Shop datum type stocking this outpost (zone-specific)
	var/shop_type = /datum/outpost_shop/black_market
	/// The live shop (shared per-round stock everyone here trades against)
	var/datum/outpost_shop/shop
	/// Secondary vendor shops (the bar, the clinic, ...) keyed by shop typepath,
	/// created lazily when the interior links a machine that asks for one
	var/list/datum/outpost_shop/extra_shops = list()
	/// Interior template type (zone-specific)
	var/template_type = /datum/map_template/trader_outpost/black_market
	/// The loaded template instance
	var/datum/map_template/trader_outpost/outpost_template
	/// The turf reservation holding the interior
	var/datum/turf_reservation/reservation
	/// Whether the interior has been loaded
	var/loaded = FALSE
	/// Whether the interior is currently loading
	var/loading = FALSE
	// Berth/elevator host vars (berths, lobby_alcove_turfs, lobby_panels,
	// template_bottom_left) live on /obj/structure/overmap, see _overmap.dm.
	/// Ships under trade embargo: ship -> world.time the embargo ends
	var/list/embargoed_ships = list()
	/// Minds that committed violence here: mind -> TRUE (turret targets, refused service)
	var/list/aggressor_minds = list()
	/// Warning strikes accrued before turrets engage: mind -> infraction count
	var/list/aggressor_strikes = list()
	/// Last time each mind took a strike: mind -> world.time (see OUTPOST_AGGRESSION_GRACE)
	var/list/aggressor_strike_times = list()
	/// Posted (not yet accepted) contracts (see outpost_missions.dm / outpost_quests.dm)
	var/list/datum/mission/shop_offers = list()
	/// Linked trader NPC fronting the main shop (the outpost's "face")
	var/mob/living/basic/outpost_trader/trader
	/// All linked trader NPCs, main trader and vendor stalls alike
	var/list/mob/living/basic/outpost_trader/traders = list()
	/// Linked defense turrets
	var/list/obj/machinery/porta_turret/outpost/turrets = list()
	/// Looping timer id for the supply convoy restock
	var/restock_timer

/// A market, as against a crew's own colony. Both are "Outposts" on the readout.
/obj/structure/overmap/trader_outpost/get_contact_variant()
	return "market"

/obj/structure/overmap/trader_outpost/Initialize(mapload)
	. = ..()
	GLOB.trader_outposts += src
	berths = new /list(OUTPOST_MAX_BERTHS)
	ensure_main_shop()
	restock_timer = addtimer(CALLBACK(src, PROC_REF(convoy_restock)), OUTPOST_RESTOCK_INTERVAL, TIMER_STOPPABLE | TIMER_LOOP)

/**
 * Creates the main shop on first need. SSovermap spawns outposts and pre-loads
 * their interiors during its own init, before SSatoms has run this structure's
 * Initialize, so interior linking and Initialize both route through here and
 * whichever happens first builds the shop.
 */
/obj/structure/overmap/trader_outpost/proc/ensure_main_shop()
	if(shop)
		return shop
	shop = new shop_type(src)
	name = shop.outpost_name
	desc = shop.outpost_desc
	return shop

/obj/structure/overmap/trader_outpost/Destroy()
	if(restock_timer)
		deltimer(restock_timer)
		restock_timer = null
	GLOB.trader_outposts -= src
	// Admin deletion must not leak six hangar reservations
	for(var/datum/outpost_berth/berth as anything in berths)
		if(berth)
			berth.release(force = TRUE)
	berths = null
	lobby_alcove_turfs.Cut()
	lobby_wall_turfs.Cut()
	lobby_panels.Cut()
	QDEL_NULL(shop)
	QDEL_LIST_ASSOC_VAL(extra_shops)
	template_bottom_left = null
	embargoed_ships.Cut()
	aggressor_minds.Cut()
	aggressor_strikes.Cut()
	aggressor_strike_times.Cut()
	QDEL_LIST(shop_offers)
	turrets.Cut()
	traders.Cut()
	trader = null
	return ..()

/obj/structure/overmap/trader_outpost/examine(mob/user)
	. = ..()
	. += span_notice("All vessels welcome. Vouchers and credits honored. Violence is bad for business.")

/**
 * Loads the outpost interior into a turf reservation (same approach as space ruins),
 * but permanently, outposts never unload.
 */
/obj/structure/overmap/trader_outpost/proc/load_level()
	if(reservation || loading)
		return
	loading = TRUE

	if(!outpost_template)
		outpost_template = new template_type

	if(!outpost_template.width || !outpost_template.height)
		log_mapping("TRADER OUTPOST: Template '[outpost_template.name]' has no dimensions, cannot load.")
		loading = FALSE
		return

	// Ships dock in per-ship hangar berths (outpost_hangar.dm), so the
	// reservation only needs to fit the interior itself.
	reservation = SSmapping.request_turf_block_reservation(outpost_template.width, outpost_template.height, 1)
	if(!reservation)
		loading = FALSE
		return

	var/turf/bottom_left = reservation.bottom_left_turfs[1]
	template_bottom_left = bottom_left

	var/load_success = FALSE
	try
		load_success = outpost_template.load(bottom_left)
	catch(var/exception/e)
		log_mapping("TRADER OUTPOST: Failed to load '[outpost_template.name]': [e]")
		load_success = FALSE

	if(!load_success)
		qdel(reservation)
		reservation = null
		template_bottom_left = null
		loading = FALSE
		return

	link_interior_machinery()

	loaded = TRUE
	loading = FALSE

/**
 * Finds the outpost machinery the template spawned and links it to this outpost.
 */
/obj/structure/overmap/trader_outpost/proc/link_interior_machinery()
	if(!template_bottom_left || !outpost_template?.width || !outpost_template?.height)
		return
	var/turf/top_right = locate(
		template_bottom_left.x + outpost_template.width - 1,
		template_bottom_left.y + outpost_template.height - 1,
		template_bottom_left.z
	)
	if(!top_right)
		return
	for(var/turf/interior_turf as anything in block(template_bottom_left, top_right))
		// block() iterates y-major then x, same order the hangar-side alcove
		// collects in, so the elevator can map alcove turf i to alcove turf i.
		for(var/obj/effect/landmark/outpost_elevator_alcove/alcove_mark in interior_turf)
			lobby_alcove_turfs += interior_turf
			qdel(alcove_mark)
		for(var/mob/living/basic/outpost_trader/npc in interior_turf)
			npc.outpost = src
			npc.shop = get_shop(npc.shop_type)
			npc.shop.trader_npc = npc
			traders += npc
			if(isnull(npc.shop_type)) // the main shop's trader is the outpost's face
				trader = npc
		for(var/obj/machinery/machine in interior_turf)
			if(istype(machine, /obj/machinery/porta_turret/outpost))
				var/obj/machinery/porta_turret/outpost/turret = machine
				turret.outpost = src
				turrets += turret
			else if(istype(machine, /obj/machinery/door/airlock/outpost))
				var/obj/machinery/door/airlock/outpost/door = machine
				door.outpost = src
			else if(istype(machine, /obj/machinery/outpost_elevator))
				var/obj/machinery/outpost_elevator/panel = machine
				panel.outpost = src
				panel.is_lobby = TRUE
				lobby_panels += panel
		// Everything the template placed is outpost property, swept here so the
		// bare tg types on the maps (door fans, seating, lockers) are covered
		// without a subtype each. The door fans are load-bearing: the sanctuary
		// has no atmos plant, so a wrenched-off fan would vent it for good.
		// Anything spawned after load (shop purchases, restock goods) is
		// deliberately left loose.
		for(var/obj/fixture in interior_turf)
			if(ismachinery(fixture) || isstructure(fixture))
				fixture.AddElement(/datum/element/outpost_property)
	// The traders' names/appearances depend on their shops, so setup runs
	// post-link. In the roundstart pre-load path the mobs haven't initialized
	// yet, dressing the appearance dummy that early is unsafe, so those
	// traders run setup_from_shop in Initialize instead.
	for(var/mob/living/basic/outpost_trader/npc as anything in traders)
		if(npc.flags_1 & INITIALIZED_1)
			npc.setup_from_shop()

/**
 * Resolves the shop a linked machine sells for. A null shop_type means the
 * outpost's main shop; a /datum/outpost_shop typepath means a vendor stall
 * (the bar, the clinic, ...), created on first request and shared by every
 * machine in the interior that asks for the same type.
 */
/obj/structure/overmap/trader_outpost/proc/get_shop(shop_type)
	if(isnull(shop_type))
		return ensure_main_shop()
	var/datum/outpost_shop/vendor_shop = extra_shops[shop_type]
	if(!vendor_shop)
		vendor_shop = new shop_type(src)
		extra_shops[shop_type] = vendor_shop
	return vendor_shop

/**
 * Every live shop here: the main shop plus any vendor stalls.
 */
/obj/structure/overmap/trader_outpost/proc/get_all_shops()
	var/list/all_shops = list(shop)
	for(var/shop_type in extra_shops)
		all_shops += extra_shops[shop_type]
	return all_shops

/obj/structure/overmap/trader_outpost/attack_ghost(mob/user)
	if(length(lobby_alcove_turfs))
		user.forceMove(pick(lobby_alcove_turfs))
		return TRUE
	if(template_bottom_left)
		user.forceMove(template_bottom_left)
		return TRUE
	return

/**
 * Handles ship docking: lazy-loads the interior, then allocates the ship its
 * own hangar berth (see outpost_hangar.dm) and docks it there.
 */
/obj/structure/overmap/trader_outpost/get_dock_description()
	return "Trader [shop?.trader_name || name] (hangar berth)"

/// The hangar deck holds a berthed ship down on its own, /area/voidcrew/trader_outpost
/// and its hangar are STANDARD_GRAVITY.
/obj/structure/overmap/trader_outpost/has_ambient_gravity()
	return TRUE

/obj/structure/overmap/trader_outpost/ship_act(mob/user, obj/structure/overmap/ship/acting, obj/structure/overmap/ship/optional_partner)
	// dock() refuses interdicted ships only after a berth below is claimed
	// and the ship is locked into ACTING - refuse up front instead
	if(acting.is_interdicted)
		to_chat(user, span_warning("Cannot dock while interdicted!"))
		return
	if(concerned)
		to_chat(user, span_notice("Too much traffic, try again later!"))
		return
	concerned = TRUE

	var/prev_state = acting.state
	acting.state = OVERMAP_SHIP_ACTING
	balloon_alert(user, "starting docking process..")

	load_level()

	if(!reservation || !loaded)
		acting.state = prev_state
		concerned = FALSE
		to_chat(user, span_warning("Failed to load the location."))
		return

	var/obj/docking_port/stationary/dock_to_use = null
	var/datum/outpost_berth/berth = null

	// Port destinations are set by survey console
	if(acting.shuttle.port_destinations)
		dock_to_use = acting.shuttle.port_destinations
	else
		// Cheap size gate before spending a reservation on a ship that can't fit
		var/long_axis = max(acting.shuttle.width, acting.shuttle.height)
		var/short_axis = min(acting.shuttle.width, acting.shuttle.height)
		if(long_axis > RESERVE_DOCK_MAX_SIZE_LONG || short_axis > RESERVE_DOCK_MAX_SIZE_SHORT)
			acting.state = prev_state
			concerned = FALSE
			to_chat(user, span_warning("Ship is too large for [name]'s hangar berths."))
			return

		berth = allocate_berth(acting)
		if(!berth)
			acting.state = prev_state
			concerned = FALSE
			to_chat(user, span_notice("[name] traffic control: all hangar berths are occupied. Try again later."))
			return
		adjust_reserve_dock_to_shuttle(berth.dock, acting.shuttle)
		dock_to_use = berth.dock

	if(acting.shuttle.height > dock_to_use.height || acting.shuttle.width > dock_to_use.width)
		berth?.release(force = TRUE) // nothing has landed yet, safe to free immediately
		acting.state = prev_state
		concerned = FALSE
		to_chat(user, span_warning("Ship is too large to dock at this location."))
		return

	// dock() only returns a string when it refuses; a successful start is announced
	// to the whole crew by ship_notify()
	var/dock_result = acting.dock(src, dock_to_use)
	if(dock_result)
		to_chat(user, span_notice("[dock_result]"))

	concerned = FALSE

	if(trader && !is_ship_embargoed(acting))
		trader.speak_line(TRADER_LINE_GREETING)

	if(optional_partner)
		ship_act(user, optional_partner)

/**
 * The supply convoy arrives: shelves refill, one rotating slot rotates, the
 * special rerolls, buyback demand relaxes. The trader announces it and every
 * berthed ship gets a nudge, a standing reason to swing back past the shop.
 */
/obj/structure/overmap/trader_outpost/proc/convoy_restock()
	if(!shop)
		return
	for(var/datum/outpost_shop/stocked_shop as anything in get_all_shops())
		stocked_shop.convoy_restock()
		stocked_shop.trader_npc?.speak_line(TRADER_LINE_RESTOCK)
	for(var/datum/outpost_berth/berth as anything in berths)
		if(berth?.ship)
			berth.ship.ship_notify("[name]: supply convoy arrived, shelves restocked, new items rotated in.", "CONVOY ARRIVAL", SHIP_NOTIFY_NOTICE, 'voidcrew/sound/notify.ogg', 30)
	// Open storefront UIs are looking at a stale catalog now; refresh them
	for(var/mob/living/basic/outpost_trader/npc as anything in traders)
		npc.shop_ui?.update_static_data_for_all_viewers()

// ===== EMBARGO / AGGRESSION =====

/**
 * Called when someone attacks outpost property or another visitor. The first
 * infractions only issue a warning; once the offender racks up
 * OUTPOST_AGGRESSION_STRIKES the outpost marks them and embargoes every ship
 * whose crew they belong to. Idempotent once marked, confirmed aggressors
 * short-circuit here.
 */
/obj/structure/overmap/trader_outpost/register_aggression(mob/living/offender)
	if(!istype(offender) || !offender.mind)
		return
	if(aggressor_minds[offender.mind])
		return

	// One swing can arrive here down several routes, and holding the mouse down
	// shouldn't spend the whole warning ladder in a tick.
	var/last_strike = aggressor_strike_times[offender.mind]
	if(last_strike && world.time < last_strike + OUTPOST_AGGRESSION_GRACE)
		return
	aggressor_strike_times[offender.mind] = world.time

	var/strikes = aggressor_strikes[offender.mind] + 1
	aggressor_strikes[offender.mind] = strikes

	// Not over the line yet: warn and give them a chance to stand down.
	if(strikes < OUTPOST_AGGRESSION_STRIKES)
		var/remaining = OUTPOST_AGGRESSION_STRIKES - strikes
		to_chat(offender, span_userdanger("Outpost defense systems train on you in warning. [remaining] more infraction\s and they fire."))
		if(trader)
			trader.speak_line(TRADER_LINE_WARNING)
		return

	// Final strike: mark them and embargo their crew's ships.
	aggressor_minds[offender.mind] = TRUE

	for(var/datum/team/voidcrew/team as anything in offender.mind.ship_teams)
		if(team.ship)
			embargo_ship(team.ship)

	to_chat(offender, span_userdanger("Outpost defense systems lock onto you. Your trade privileges have been revoked."))
	if(trader)
		trader.speak_line(TRADER_LINE_AGGRESSION)

/**
 * Places a ship under trade embargo for OUTPOST_EMBARGO_DURATION.
 */
/obj/structure/overmap/trader_outpost/proc/embargo_ship(obj/structure/overmap/ship/ship)
	if(!istype(ship))
		return
	embargoed_ships[ship] = world.time + OUTPOST_EMBARGO_DURATION
	ship.ship_notify("[name] has placed your vessel under trade embargo for [OUTPOST_EMBARGO_DURATION / (1 MINUTES)] minutes.", "TRADE EMBARGO", SHIP_NOTIFY_WARNING, 'voidcrew/sound/notify2.ogg', 25)

/**
 * Whether a ship is currently embargoed here. Expired entries are pruned lazily.
 */
/obj/structure/overmap/trader_outpost/proc/is_ship_embargoed(obj/structure/overmap/ship/ship)
	if(!ship || !embargoed_ships[ship])
		return FALSE
	if(world.time >= embargoed_ships[ship])
		embargoed_ships -= ship
		return FALSE
	return TRUE

/**
 * Whether this user is refused service: personally marked as an aggressor,
 * or crew of an embargoed ship.
 */
/obj/structure/overmap/trader_outpost/proc/is_user_barred(mob/user)
	if(!user?.mind)
		return FALSE
	if(aggressor_minds[user.mind])
		return TRUE
	for(var/datum/team/voidcrew/team as anything in user.mind.ship_teams)
		if(team.ship && is_ship_embargoed(team.ship))
			return TRUE
	return FALSE

/**
 * Whether this mob is a valid turret target: marked aggressors AND crew of
 * embargoed ships, an embargo means shot on sight, not just refused service.
 */
/obj/structure/overmap/trader_outpost/proc/is_turret_target(mob/living/target)
	return istype(target) && is_user_barred(target)

/**
 * Resolves which trader outpost protects a turf by checking its concourse and
 * allocated hangar footprints. Coordinate checks intentionally include docked
 * ship turfs, whose areas still belong to the ship. Cheap: there are only a
 * handful of outposts and berths per round.
 */
/proc/get_trader_outpost_for_turf(turf/T)
	if(!T)
		return null
	for(var/obj/structure/overmap/trader_outpost/outpost as anything in GLOB.trader_outposts)
		var/turf/bottom_left = outpost.template_bottom_left
		if(bottom_left?.z == T.z \
			&& T.x >= bottom_left.x && T.x < bottom_left.x + outpost.outpost_template.width \
			&& T.y >= bottom_left.y && T.y < bottom_left.y + outpost.outpost_template.height)
			return outpost
		for(var/datum/outpost_berth/berth as anything in outpost.berths)
			var/turf/hangar_bottom_left = berth?.hangar_bottom_left
			var/datum/turf_reservation/reservation = berth?.reservation
			if(!hangar_bottom_left || !reservation || hangar_bottom_left.z != T.z)
				continue
			if(T.x < hangar_bottom_left.x || T.x >= hangar_bottom_left.x + reservation.width)
				continue
			if(T.y < hangar_bottom_left.y || T.y >= hangar_bottom_left.y + reservation.height)
				continue
			return outpost
	return null

// ===== ZONE VARIANTS =====

/obj/structure/overmap/trader_outpost/black_market
	shop_type = /datum/outpost_shop/black_market
	template_type = /datum/map_template/trader_outpost/black_market

/obj/structure/overmap/trader_outpost/outfitter
	shop_type = /datum/outpost_shop/outfitter
	template_type = /datum/map_template/trader_outpost/outfitter

/obj/structure/overmap/trader_outpost/general
	shop_type = /datum/outpost_shop/general
	template_type = /datum/map_template/trader_outpost/general
