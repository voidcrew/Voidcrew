/**
 * # Trader Outpost
 *
 * Static, permanent, invincible trade station on the overmap. One-ish per zone;
 * the shop type matches the zone (deep-zone black market sells syndicate gear).
 *
 * Unlike space ruins, outposts never unload, never move and never respawn.
 * The interior is lazy-loaded on first dock and then stays for the round.
 * The structure is indestructible by construction (CentCom-style turfs and
 * machinery); the deterrent against aggression is its police (voidcrew/modules/outpost_police/)
 * and a per-ship trade embargo, not HP.
 */

/// All trader outposts on the overmap (used by vouchers/missions to list trader locations)
GLOBAL_LIST_EMPTY(trader_outposts)

/area/voidcrew/trader_outpost
	name = "\improper Trader Outpost"
	icon_state = "away"
	static_lighting = TRUE
	requires_power = FALSE
	default_gravity = STANDARD_GRAVITY
	area_flags = UNIQUE_AREA | NOTELEPORT | NO_BOH
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
	/// Personal retaliation exemptions: defender mind -> (attacker mind -> expiry time).
	var/list/self_defense_targets = list()
	/// Posted (not yet accepted) contracts (see outpost_missions.dm / outpost_quests.dm)
	var/list/datum/mission/shop_offers = list()
	/// Linked trader NPC fronting the main shop (the outpost's "face")
	var/mob/living/carbon/human/npc/ambient_npc/outpost/trader/trader
	/// All linked trader NPCs, main trader and vendor stalls alike
	var/list/mob/living/carbon/human/npc/ambient_npc/outpost/trader/traders = list()
	/// Looping timer id for the supply convoy restock
	var/restock_timer
	/// Board clock is independent of visits, acceptance and the supply convoy.
	var/next_contract_refill = 0
	var/contract_refill_timer
	// OUTPOST FLOORS seam (voidcrew/modules/trade_floors): the floors above the concourse
	/// This outpost's floors: floors\[n] is floor n, or null once it is deleted. Made by make_floors() (floor_registry.dm).
	var/list/datum/outpost_floor/floors = list()
	/// How many floors this outpost has
	var/floor_count = OUTPOST_FLOORS_PER_OUTPOST

/// A market, as against a crew's own colony. Both are "Outposts" on the readout.
/obj/structure/overmap/trader_outpost/get_contact_variant()
	return "market"

/obj/structure/overmap/trader_outpost/contains_site_turf(turf/location)
	return ..() || reservation?.contains_turf(location)

/obj/structure/overmap/trader_outpost/Initialize(mapload)
	. = ..()
	GLOB.trader_outposts += src
	berths = new /list(OUTPOST_MAX_BERTHS)
	ensure_main_shop()
	ensure_police()
	ensure_recovery()
	if(SSovermap_zones.initialized)
		start_contract_offers()
	else
		RegisterSignal(SSovermap_zones, COMSIG_SUBSYSTEM_POST_INITIALIZE, PROC_REF(on_contract_zones_ready))
	restock_timer = addtimer(CALLBACK(src, PROC_REF(convoy_restock)), OUTPOST_RESTOCK_INTERVAL, TIMER_STOPPABLE | TIMER_LOOP | TIMER_DELETE_ME)

/// Overmap construction precedes zone assignment; no contract may quote an unzoned site.
/obj/structure/overmap/trader_outpost/proc/on_contract_zones_ready(datum/source)
	SIGNAL_HANDLER
	UnregisterSignal(source, COMSIG_SUBSYSTEM_POST_INITIALIZE)
	INVOKE_ASYNC(src, PROC_REF(start_contract_offers))

/obj/structure/overmap/trader_outpost/proc/start_contract_offers()
	if(QDELETED(src) || contract_refill_timer || !SSovermap_zones.initialized)
		return
	ensure_shop_offers()
	contract_refill_timer = addtimer(CALLBACK(src, PROC_REF(ensure_shop_offers)), OUTPOST_CONTRACT_REFILL_INTERVAL, TIMER_STOPPABLE | TIMER_LOOP | TIMER_DELETE_ME)

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
	UnregisterSignal(SSovermap_zones, COMSIG_SUBSYSTEM_POST_INITIALIZE)
	if(contract_refill_timer)
		deltimer(contract_refill_timer)
		contract_refill_timer = null
	if(restock_timer)
		deltimer(restock_timer)
		restock_timer = null
	// OUTPOST FLOORS seam: the floors go first, while the outpost they point at is still whole (abuse A35)
	QDEL_LIST(floors)
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
	clear_checkpoint_state()
	QDEL_NULL(police)
	QDEL_NULL(recovery)
	self_defense_targets.Cut()
	QDEL_LIST(shop_offers)
	traders.Cut()
	trader = null
	loaded = FALSE
	QDEL_NULL(reservation)
	QDEL_NULL(outpost_template)
	return ..()

/obj/structure/overmap/trader_outpost/examine(mob/user)
	. = ..()
	. += span_notice("All vessels welcome. Vouchers and credits honored. Violence is bad for business.")

/obj/structure/overmap/trader_outpost/start_level_load(mob/user, obj/structure/overmap/ship/waiting_ship)
	INVOKE_ASYNC(src, PROC_REF(load_level))

/obj/structure/overmap/trader_outpost/is_loading()
	return loading

/obj/structure/overmap/trader_outpost/is_loaded()
	return loaded

/**
 * Loads the outpost interior into a turf reservation (same approach as space ruins),
 * but permanently, outposts never unload.
 */
/obj/structure/overmap/trader_outpost/proc/load_level()
	if(loaded || loading)
		return loaded
	loading = TRUE
	var/load_success = FALSE
	try
		if(!outpost_template)
			outpost_template = new template_type
		if(!outpost_template.width || !outpost_template.height)
			log_mapping("TRADER OUTPOST: Template '[outpost_template.name]' has no dimensions, cannot load.")
		else
			// Ships use separate hangar reservations; this block is only the concourse.
			reservation = SSmapping.request_turf_block_reservation(outpost_template.width, outpost_template.height, 1, requester = "trader outpost '[name]' concourse")
			if(reservation)
				template_bottom_left = reservation.bottom_left_turfs[1]
				if(outpost_template.load(template_bottom_left))
					link_interior_machinery()
					load_success = TRUE
	catch(var/exception/e)
		log_mapping("TRADER OUTPOST: Failed to load '[name]': [e]")
	if(!load_success)
		QDEL_NULL(reservation)
		template_bottom_left = null
	loaded = load_success
	// Outside the try: a runtime there unwinds the whole load (outpost_network.dm)
	if(loaded)
		spawn_network_pad()
	loading = FALSE
	SEND_SIGNAL(src, COMSIG_VOIDCREW_SITE_LOAD_FINISHED, loaded)
	return loaded

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
	var/list/obj/machinery/door/airlock/outpost/checkpoint/checkpoint_doors = list()
	var/list/obj/effect/landmark/outpost_checkpoint_chamber/checkpoint_chambers = list()
	var/list/obj/machinery/outpost_checkpoint_sensor/checkpoint_sensors = list()
	// The police station's parts (voidcrew/modules/outpost_police/police_core.dm, link_interior())
	var/list/obj/effect/landmark/police_landmarks = list()
	var/list/obj/machinery/door/airlock/outpost/police_doors = list()
	var/list/obj/machinery/status_display/outpost_berth/police_cell/police_signs = list()
	var/list/obj/structure/closet/secure_closet/personal/outpost_police/police_lockers = list()
	var/obj/structure/closet/secure_closet/outpost_evidence/police_evidence
	// The morgue room and janitor closet (voidcrew/modules/outpost_police/recovery_core.dm, link_rooms())
	var/list/obj/effect/landmark/recovery_landmarks = list()
	for(var/turf/interior_turf as anything in block(template_bottom_left, top_right))
		// block() iterates y-major then x, same order the hangar-side alcove
		// collects in, so the elevator can map alcove turf i to alcove turf i.
		for(var/obj/effect/landmark/outpost_elevator_alcove/alcove_mark in interior_turf)
			lobby_alcove_turfs += interior_turf
			qdel(alcove_mark)
		for(var/obj/effect/landmark/outpost_network_pad_spot/pad_mark in interior_turf)
			network_pad_spot = interior_turf
			qdel(pad_mark)
		for(var/obj/effect/landmark/outpost_checkpoint_chamber/chamber_mark in interior_turf)
			checkpoint_chambers += chamber_mark
		for(var/obj/effect/landmark/outpost_police_lift/police_mark in interior_turf)
			police_landmarks += police_mark
		for(var/obj/effect/landmark/outpost_police_desk/police_mark in interior_turf)
			police_landmarks += police_mark
		for(var/obj/effect/landmark/outpost_police_cell/police_mark in interior_turf)
			police_landmarks += police_mark
		for(var/obj/structure/closet/secure_closet/personal/outpost_police/locker in interior_turf)
			police_lockers += locker
		police_evidence ||= locate(/obj/structure/closet/secure_closet/outpost_evidence) in interior_turf
		for(var/obj/effect/landmark/outpost_morgue/recovery_mark in interior_turf)
			recovery_landmarks += recovery_mark
		for(var/obj/effect/landmark/outpost_janitor_closet/recovery_mark in interior_turf)
			recovery_landmarks += recovery_mark
		for(var/mob/living/carbon/human/npc/ambient_npc/outpost/trader/npc in interior_turf)
			npc.outpost = src
			npc.shop = get_shop(npc.shop_type)
			npc.shop.trader_npc = npc
			traders += npc
			if(isnull(npc.shop_type)) // the main shop's trader is the outpost's face
				trader = npc
		for(var/obj/machinery/machine in interior_turf)
			if(istype(machine, /obj/machinery/door/airlock/outpost))
				var/obj/machinery/door/airlock/outpost/door = machine
				door.outpost = src
				if(istype(door, /obj/machinery/door/airlock/outpost/checkpoint))
					checkpoint_doors += door
				else if(istype(door, /obj/machinery/door/airlock/outpost/police) || istype(door, /obj/machinery/door/airlock/outpost/glass/police_cell))
					police_doors += door
			else if(istype(machine, /obj/machinery/status_display/outpost_berth/police_cell))
				police_signs += machine
			else if(istype(machine, /obj/machinery/outpost_checkpoint_sensor))
				checkpoint_sensors += machine
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
	// Only parts collected from this concourse reservation form a checkpoint
	// (outpost_checkpoint.dm); the guards linked above are matched to theirs.
	build_checkpoints(checkpoint_doors, checkpoint_chambers, checkpoint_sensors)
	ensure_police().link_interior(police_landmarks, police_doors, police_signs, police_lockers, police_evidence)
	ensure_recovery().link_rooms(recovery_landmarks)
	start_armed_sweep()
	// The traders' names/appearances depend on their shops, so setup runs
	// post-link. In the roundstart pre-load path the mobs haven't initialized
	// yet, dressing the appearance dummy that early is unsafe, so those
	// traders run setup_from_shop in Initialize instead.
	for(var/mob/living/carbon/human/npc/ambient_npc/outpost/trader/npc as anything in traders)
		if(npc.flags_1 & INITIALIZED_1)
			npc.setup_from_shop()
	make_floors() // OUTPOST FLOORS seam: the floors to let (trade_floors/floor_registry.dm)

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
	if(concerned || admin_operation || loading)
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
	for(var/mob/living/carbon/human/npc/ambient_npc/outpost/trader/npc as anything in traders)
		npc.shop_ui?.update_static_data_for_all_viewers()
	// World population (voidcrew/modules/ambient_npcs): the dock workers unload it
	SEND_SIGNAL(src, COMSIG_TRADER_OUTPOST_CONVOY)

// ===== EMBARGO / AGGRESSION =====

/**
 * Only the attacked person may retaliate, and only against their attacker.
 * Check the exemption before recording aggression so defending oneself never
 * gives the original attacker a reciprocal exemption or extends the fight.
 * The victim's window opens before the police hear of it, seen or not (abuse M14).
 * `crime` is an OUTPOST_CRIME_* and `source` the item the hit was done with, if any.
 */
/obj/structure/overmap/trader_outpost/proc/register_pvp_aggression(mob/living/victim, mob/living/offender, crime = OUTPOST_CRIME_ASSAULT_ARMED, obj/item/source)
	if(!victim?.mind || !offender?.mind || victim.mind == offender.mind)
		return
	var/list/allowed_targets = self_defense_targets[offender.mind]
	var/defense_until = LAZYACCESS(allowed_targets, victim.mind)
	if(defense_until > world.time)
		return
	if(defense_until)
		allowed_targets -= victim.mind
		if(!length(allowed_targets))
			self_defense_targets -= offender.mind

	var/list/victim_targets = self_defense_targets[victim.mind]
	if(!victim_targets)
		victim_targets = list()
		self_defense_targets[victim.mind] = victim_targets
	// Even hits the police fold together or never see renew the victim's
	// permission to defend themselves.
	victim_targets[offender.mind] = world.time + OUTPOST_SELF_DEFENSE_DURATION
	register_aggression(offender, crime, victim, source)

/**
 * Called when someone attacks outpost property, its people or another visitor. The
 * outpost police decide whether it counted (a witness, the dedupe) and what it does
 * to the offender's wanted level (voidcrew/modules/outpost_police/police_wanted.dm).
 * A counted crime tells the bystanders to duck; the trader has a word for a scuffle
 * still under one star, and another when someone first reaches three.
 */
/obj/structure/overmap/trader_outpost/register_aggression(mob/living/offender, crime = OUTPOST_CRIME_VANDALISM, atom/victim, obj/item/source)
	if(!istype(offender) || !offender.mind)
		return
	if(bounty_kingpin_excuses_aggression(src, offender)) return // BOUNTY P9 (kingpin): no property strikes for hunters in his shootout; PvP still counts
	if(!police)
		return
	var/stars_before = police.get_stars(offender.mind)
	var/stars_after = police.report_crime(offender, crime, victim, source)
	if(isnull(stars_after))
		return
	// World population (voidcrew/modules/ambient_npcs): bystanders near the fight duck and leave
	SEND_SIGNAL(src, COMSIG_TRADER_OUTPOST_VIOLENCE, offender)
	if(!trader)
		return
	if(stars_after < 1)
		trader.speak_line(TRADER_LINE_WARNING)
	else if(stars_before < 3 && stars_after >= 3)
		trader.speak_line(TRADER_LINE_AGGRESSION)

/**
 * Places a ship under trade embargo for `duration` (admins set their own, see overmap_management_bans.dm).
 */
/obj/structure/overmap/trader_outpost/proc/embargo_ship(obj/structure/overmap/ship/ship, duration = OUTPOST_EMBARGO_DURATION)
	if(!istype(ship))
		return
	embargoed_ships[ship] = world.time + duration
	ship.ship_notify("[name] has placed your vessel under trade embargo.", "TRADE EMBARGO", SHIP_NOTIFY_WARNING, 'voidcrew/sound/notify2.ogg', 25)

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
 * Whether this user is refused service: the police answer it (stars, a bar, or crew
 * of an embargoed ship; voidcrew/modules/outpost_police/police_wanted.dm).
 */
/obj/structure/overmap/trader_outpost/proc/is_user_barred(mob/user)
	if(!user?.mind || !police)
		return FALSE
	return police.is_barred(user)

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
			if(berth?.contains_turf(T))
				return outpost
		// OUTPOST FLOORS seam (voidcrew/modules/trade_floors): a floor is this outpost's ground for the law only
		// while it is public ground or a warrant is in force on it. get_outpost_floor_for_turf() finds it always.
		for(var/datum/outpost_floor/floor in outpost.floors)
			if((floor.public_ground || floor.warrant_in_force) && floor.contains_turf(T))
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
