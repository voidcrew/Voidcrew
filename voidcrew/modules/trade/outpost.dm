/**
 * # Trader Outpost
 *
 * Static, permanent, invincible trade station on the overmap. One-ish per zone;
 * the shop type matches the zone (deep-zone black market sells syndicate gear).
 *
 * Unlike space ruins, outposts never unload, never move and never respawn —
 * the interior is lazy-loaded on first dock and then stays for the round.
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

	/// Shop datum type stocking this outpost (zone-specific)
	var/shop_type = /datum/outpost_shop/black_market
	/// The live shop (shared per-round stock for all terminals here)
	var/datum/outpost_shop/shop
	/// Interior template type (zone-specific)
	var/template_type = /datum/map_template/trader_outpost/black_market
	/// The loaded template instance
	var/datum/map_template/trader_outpost/outpost_template
	/// The turf reservation holding the interior + docks
	var/datum/turf_reservation/reservation
	/// Primary docking port
	var/obj/docking_port/stationary/reserve_dock
	/// Secondary docking port
	var/obj/docking_port/stationary/reserve_dock_secondary
	/// Whether the interior has been loaded
	var/loaded = FALSE
	/// Whether the interior is currently loading
	var/loading = FALSE
	/// Track dock usage (mirrors space_ruin/planet bookkeeping in ship.dm)
	var/first_dock_taken = FALSE
	var/second_dock_taken = FALSE
	/// Bottom-left turf of the loaded template footprint
	var/turf/template_bottom_left
	/// Ships under trade embargo: ship -> world.time the embargo ends
	var/list/embargoed_ships = list()
	/// Minds that attacked outpost property: mind -> TRUE (turret targets, refused service)
	var/list/aggressor_minds = list()
	/// Warning strikes accrued before turrets engage: mind -> infraction count
	var/list/aggressor_strikes = list()
	/// Linked shop terminals inside the outpost
	var/list/obj/machinery/computer/outpost_shop_terminal/terminals = list()
	/// Linked supply request boards inside the outpost
	var/list/obj/machinery/computer/outpost_mission_board/mission_boards = list()
	/// Posted (not yet accepted) supply request missions (see outpost_missions.dm)
	var/list/datum/mission/outpost_supply/shop_offers = list()
	/// Linked trader hologram
	var/obj/machinery/outpost_trader/trader
	/// Linked defense turrets
	var/list/obj/machinery/porta_turret/outpost/turrets = list()

/obj/structure/overmap/trader_outpost/Initialize(mapload)
	. = ..()
	GLOB.trader_outposts += src
	shop = new shop_type(src)
	name = shop.outpost_name
	desc = shop.outpost_desc

/obj/structure/overmap/trader_outpost/Destroy()
	GLOB.trader_outposts -= src
	QDEL_NULL(shop)
	template_bottom_left = null
	embargoed_ships.Cut()
	aggressor_minds.Cut()
	aggressor_strikes.Cut()
	terminals.Cut()
	mission_boards.Cut()
	QDEL_LIST(shop_offers)
	turrets.Cut()
	trader = null
	return ..()

/obj/structure/overmap/trader_outpost/examine(mob/user)
	. = ..()
	. += span_notice("All vessels welcome. Vouchers and credits honored. Violence is bad for business.")

/**
 * Loads the outpost interior into a turf reservation (same approach as space ruins),
 * but permanently — outposts never unload.
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

	// Interior + buffer for docking on two sides (same dock sizes as planets/ruins)
	var/reserve_width = outpost_template.width + (RESERVE_DOCK_MAX_SIZE_LONG * 2) + (RESERVE_DOCK_DEFAULT_PADDING * 2)
	var/reserve_height = outpost_template.height + (RESERVE_DOCK_MAX_SIZE_SHORT * 2) + (RESERVE_DOCK_DEFAULT_PADDING * 2)

	reservation = SSmapping.request_turf_block_reservation(reserve_width, reserve_height, 1)
	if(!reservation)
		loading = FALSE
		return

	var/turf/bottom_left = reservation.bottom_left_turfs[1]

	var/template_x = bottom_left.x + RESERVE_DOCK_MAX_SIZE_LONG + RESERVE_DOCK_DEFAULT_PADDING
	var/template_y = bottom_left.y + RESERVE_DOCK_MAX_SIZE_SHORT + RESERVE_DOCK_DEFAULT_PADDING
	var/turf/template_turf = locate(template_x, template_y, bottom_left.z)
	template_bottom_left = template_turf

	var/load_success = FALSE
	try
		load_success = outpost_template.load(template_turf)
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

	// Docking ports on opposite corners of the reservation, like space ruins
	var/turf/primary_dock_turf = locate(
		bottom_left.x + RESERVE_DOCK_DEFAULT_PADDING,
		bottom_left.y + RESERVE_DOCK_DEFAULT_PADDING,
		bottom_left.z
	)
	reserve_dock = new /obj/docking_port/stationary(primary_dock_turf)
	reserve_dock.dir = NORTH
	reserve_dock.name = "[name] Landing Pad One"
	reserve_dock.width = RESERVE_DOCK_MAX_SIZE_LONG
	reserve_dock.height = RESERVE_DOCK_MAX_SIZE_SHORT
	reserve_dock.dheight = 0
	reserve_dock.dwidth = 0

	var/turf/secondary_dock_turf = locate(
		bottom_left.x + reserve_width - RESERVE_DOCK_MAX_SIZE_LONG - RESERVE_DOCK_DEFAULT_PADDING,
		bottom_left.y + reserve_height - RESERVE_DOCK_MAX_SIZE_SHORT - RESERVE_DOCK_DEFAULT_PADDING,
		bottom_left.z
	)
	reserve_dock_secondary = new /obj/docking_port/stationary(secondary_dock_turf)
	reserve_dock_secondary.dir = NORTH
	reserve_dock_secondary.name = "[name] Landing Pad Two"
	reserve_dock_secondary.width = RESERVE_DOCK_MAX_SIZE_LONG
	reserve_dock_secondary.height = RESERVE_DOCK_MAX_SIZE_SHORT
	reserve_dock_secondary.dheight = 0
	reserve_dock_secondary.dwidth = 0

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
		for(var/obj/machinery/machine in interior_turf)
			if(istype(machine, /obj/machinery/computer/outpost_shop_terminal))
				var/obj/machinery/computer/outpost_shop_terminal/terminal = machine
				terminal.outpost = src
				terminals += terminal
			else if(istype(machine, /obj/machinery/computer/outpost_mission_board))
				var/obj/machinery/computer/outpost_mission_board/board = machine
				board.outpost = src
				mission_boards += board
			else if(istype(machine, /obj/machinery/outpost_trader))
				trader = machine
				trader.outpost = src
				trader.update_appearance(UPDATE_NAME)
			else if(istype(machine, /obj/machinery/porta_turret/outpost))
				var/obj/machinery/porta_turret/outpost/turret = machine
				turret.outpost = src
				turrets += turret
			else if(istype(machine, /obj/machinery/door/airlock/outpost))
				var/obj/machinery/door/airlock/outpost/door = machine
				door.outpost = src
	// The projection's appearance depends on the shop, so it spawns post-link
	trader?.activate_hologram()

/obj/structure/overmap/trader_outpost/attack_ghost(mob/user)
	if(reserve_dock)
		user.forceMove(get_turf(reserve_dock))
		return TRUE
	if(template_bottom_left)
		user.forceMove(template_bottom_left)
		return TRUE
	return

/**
 * Handles ship docking, mirroring the space ruin flow (lazy-load, two reserve docks).
 */
/obj/structure/overmap/trader_outpost/ship_act(mob/user, obj/structure/overmap/ship/acting, obj/structure/overmap/ship/optional_partner)
	if(concerned)
		to_chat(user, span_notice("Too much traffic, try again later!"))
		return
	concerned = TRUE

	var/prev_state = acting.state
	acting.state = OVERMAP_SHIP_ACTING
	balloon_alert(user, "starting docking process..")

	load_level()

	if(!reservation || !reserve_dock)
		acting.state = prev_state
		concerned = FALSE
		to_chat(user, span_warning("Failed to load the location."))
		return

	var/is_survey = FALSE
	var/obj/docking_port/stationary/dock_to_use = null
	var/selected_dock_index = 0

	// Port destinations are set by survey console
	if(acting.shuttle.port_destinations)
		dock_to_use = acting.shuttle.port_destinations
		is_survey = TRUE
	else
		if(!reserve_dock.get_docked() && !first_dock_taken)
			dock_to_use = reserve_dock
			selected_dock_index = 1
		else if(!reserve_dock_secondary.get_docked() && !second_dock_taken)
			dock_to_use = reserve_dock_secondary
			selected_dock_index = 2

	if(!dock_to_use)
		acting.state = prev_state
		concerned = FALSE
		to_chat(user, span_notice("All landing pads occupied."))
		return

	if(!is_survey)
		adjust_reserve_dock_to_shuttle(dock_to_use, acting.shuttle)

	if(acting.shuttle.height > dock_to_use.height || acting.shuttle.width > dock_to_use.width)
		acting.state = prev_state
		concerned = FALSE
		to_chat(user, span_warning("Ship is too large to dock at this location."))
		return

	if(selected_dock_index == 1)
		first_dock_taken = TRUE
		acting.dock_index = 1
	else if(selected_dock_index == 2)
		second_dock_taken = TRUE
		acting.dock_index = 2

	to_chat(user, span_notice("[acting.dock(src, dock_to_use)]"))

	concerned = FALSE

	if(trader && !is_ship_embargoed(acting))
		trader.speak_line(TRADER_LINE_GREETING)

	if(optional_partner)
		ship_act(user, optional_partner)

// ===== EMBARGO / AGGRESSION =====

/**
 * Called when someone attacks outpost property. The first infractions only issue
 * a warning; once the offender racks up OUTPOST_AGGRESSION_STRIKES the outpost
 * marks them and embargoes every ship whose crew they belong to. Idempotent once
 * marked — confirmed aggressors short-circuit here.
 */
/obj/structure/overmap/trader_outpost/proc/register_aggression(mob/living/offender)
	if(!istype(offender) || !offender.mind)
		return
	if(aggressor_minds[offender.mind])
		return

	var/strikes = aggressor_strikes[offender.mind] + 1
	aggressor_strikes[offender.mind] = strikes

	// Not over the line yet — warn and give them a chance to stand down.
	if(strikes < OUTPOST_AGGRESSION_STRIKES)
		var/remaining = OUTPOST_AGGRESSION_STRIKES - strikes
		to_chat(offender, span_userdanger("Outpost defense systems train on you in warning. [remaining] more infraction\s and they fire."))
		if(trader)
			trader.speak_line(TRADER_LINE_WARNING)
		return

	// Final strike — mark them and embargo their crew's ships.
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
 * embargoed ships — an embargo means shot on sight, not just refused service.
 */
/obj/structure/overmap/trader_outpost/proc/is_turret_target(mob/living/target)
	return istype(target) && is_user_barred(target)

/**
 * Resolves which trader outpost a turf belongs to by checking each outpost's
 * loaded template footprint. Used by outpost turfs (walls), which can't hold
 * a back-reference. Cheap: there are only a handful of outposts per round.
 */
/proc/get_trader_outpost_for_turf(turf/T)
	if(!T)
		return null
	for(var/obj/structure/overmap/trader_outpost/outpost as anything in GLOB.trader_outposts)
		var/turf/bottom_left = outpost.template_bottom_left
		if(!bottom_left || bottom_left.z != T.z)
			continue
		if(T.x < bottom_left.x || T.x >= bottom_left.x + outpost.outpost_template.width)
			continue
		if(T.y < bottom_left.y || T.y >= bottom_left.y + outpost.outpost_template.height)
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
