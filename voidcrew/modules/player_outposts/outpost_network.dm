/**
 * # Outpost teleporter network
 *
 * Network pads send one person at a time from one outpost to another: the trading outposts
 * (a free public pad each, spawned into the concourse at load) and every player outpost with a
 * Teleporter room (outpost_teleporter.dm). Nothing else is on the network: never ships, planets,
 * ruins or anywhere else. Trips may cross zones. That is the one deliberate exception to the
 * cross-zone teleport block, scoped to this machine by outpost_network_may_cross().
 *
 * Rules (grounding-teleporter §3, plan.md R8/R9):
 * * People only, with what they carry. No carried or bagged mobs, no contract cargo, no ship keys.
 * * The traveller stands on the pad for a charge-up (5 s, or 10 s across zones). Moving off,
 *   taking damage, or falling unconscious cancels it; nothing is charged.
 * * The destination decides who arrives and what it costs. The fare is paid at departure from
 *   the traveller's ID account into the destination's treasury. Nobody pays to leave.
 * * They arrive on the destination's pad. A pad someone is leaving from, or someone is on the way
 *   to, is in use.
 * * Trader pads reach player pads only, never each other.
 * * A 2 minute cooldown per traveller.
 *
 * The pad needs no power: an owner who cut it could strand every visitor who arrived by it.
 */

/// Every network pad in the world, linked or not. Bounded by 3 traders + one per player outpost.
GLOBAL_LIST_EMPTY(outpost_network_pads)
/// ckey -> world.time the traveller may depart again
GLOBAL_LIST_EMPTY(outpost_network_ready_at)

// ===== LOCKS =====

/// Whether `user` crews any ship this outpost has banned
/obj/structure/overmap/dynamic/player_outpost/proc/crews_banned_ship(mob/user)
	if(!user?.mind || !length(banned_ships))
		return FALSE
	for(var/datum/team/voidcrew/team as anything in user.mind.ship_teams)
		if(team.ship && (team.ship in banned_ships))
			return TRUE
	return FALSE

/// Whether `user` crews a ship cleared to dock here in REQUEST mode
/obj/structure/overmap/dynamic/player_outpost/proc/crews_approved_ship(mob/user)
	if(!user?.mind || !length(approved_ships))
		return FALSE
	for(var/datum/team/voidcrew/team as anything in user.mind.ship_teams)
		if(team.ship && (team.ship in approved_ships))
			return TRUE
	return FALSE

// ===== THE ZONE EXCEPTION =====

/**
 * The outpost network is the one teleport allowed to cross an overmap zone boundary (plan.md M8).
 * TRUE only on the network's own channel, only for the traveller a pad is committing right now,
 * only from that pad's tile and only onto the destination's arrival tile. Code that reuses the
 * channel elsewhere still cannot cross. The cross-zone block's forced branch calls this.
 */
/proc/outpost_network_may_cross(atom/movable/teleatom, turf/destination, channel)
	if(channel != TELEPORT_CHANNEL_OUTPOST_NETWORK || !teleatom || !destination)
		return FALSE
	var/turf/origin = get_turf(teleatom)
	for(var/obj/machinery/outpost_network_pad/pad as anything in GLOB.outpost_network_pads)
		if(pad.committing_turf != destination || pad.committing_ref?.resolve() != teleatom)
			continue
		if(get_turf(pad) == origin)
			return TRUE
	return FALSE

// ===== THE PAD =====

/obj/machinery/outpost_network_pad
	name = "network pad"
	desc = "A teleporter pad on the outpost network."
	icon = 'voidcrew/modules/transporter/icons/transporter.dmi'
	icon_state = "transporter_pad"
	base_icon_state = "transporter_pad"
	density = FALSE
	anchored = TRUE
	use_power = NO_POWER_USE
	circuit = null
	resistance_flags = INDESTRUCTIBLE | LAVA_PROOF | FIRE_PROOF | UNACIDABLE | ACID_PROOF
	flags_1 = PREVENT_CONTENTS_EXPLOSION_1
	/// Trader pads are public and free, and never reach another trader
	var/is_trader = FALSE
	/// A short unique id for UIs and allow lists
	var/network_id
	/// The trader or player outpost this pad serves
	var/datum/weakref/host_ref
	/// Where arrivals land: the pad's own tile
	var/turf/arrival_turf
	/// Zone of the host's overmap tile, cached once known (outposts never move)
	var/zone_type

	// A departure charging on this pad
	var/datum/weakref/charging_ref
	var/datum/weakref/charge_target_ref
	/// The fare the traveller agreed to
	var/charge_fee = 0
	var/charge_timer
	var/charge_started = 0
	var/charge_ends = 0
	/// The traveller's alpha before the beam, handed back on cancel
	var/charge_alpha = 255
	/// Beam columns at both ends (weakrefs), removed on cancel
	var/list/datum/weakref/charge_beams
	/// A source pad charging toward this one
	var/datum/weakref/incoming_ref

	// Set only for the length of the do_teleport() call (outpost_network_may_cross())
	var/datum/weakref/committing_ref
	var/turf/committing_turf

/obj/machinery/outpost_network_pad/Initialize(mapload)
	. = ..()
	var/static/serial = 0
	network_id = "pad[++serial]"
	GLOB.outpost_network_pads += src
	var/static/list/loc_connections = list(COMSIG_ATOM_ENTERED = PROC_REF(on_entered))
	AddElement(/datum/element/connect_loc, loc_connections)

/obj/machinery/outpost_network_pad/Destroy()
	cancel_charge("The pad went offline.")
	var/obj/machinery/outpost_network_pad/source = incoming_ref?.resolve()
	incoming_ref = null
	source?.cancel_charge("The destination went offline.")
	GLOB.outpost_network_pads -= src
	host_ref = null
	arrival_turf = null
	committing_turf = null
	return ..()

/obj/machinery/outpost_network_pad/trader
	name = "public network pad"
	desc = "The trading outpost's public teleporter pad."
	is_trader = TRUE

/// Links the pad to its outpost. Player pads are linked by their Teleporter room, trader pads by spawn_network_pad().
/obj/machinery/outpost_network_pad/proc/link_host(obj/structure/overmap/host)
	host_ref = WEAKREF(host)
	arrival_turf = get_turf(src)
	zone_type = null
	get_zone()

/// The outpost this pad serves while it is on the network, else null
/obj/machinery/outpost_network_pad/proc/network_host()
	var/obj/structure/overmap/host = host_ref?.resolve()
	if(QDELETED(host) || !arrival_turf)
		return null
	if(is_trader)
		var/obj/structure/overmap/trader_outpost/market = host
		return (istype(market) && market.loaded) ? market : null
	var/obj/structure/overmap/dynamic/player_outpost/home = host
	if(!istype(home) || !home.loaded)
		return null
	var/datum/outpost_upgrade/service/teleporter/room = home.service_upgrade("teleporter")
	if(!istype(room) || room.pad_ref?.resolve() != src)
		return null
	return home

/// The player outpost this pad serves, or null (a trader pad, or offline)
/obj/machinery/outpost_network_pad/proc/player_host()
	var/obj/structure/overmap/dynamic/player_outpost/home = network_host()
	return istype(home) ? home : null

/obj/machinery/outpost_network_pad/proc/get_zone()
	if(isnull(zone_type))
		var/obj/structure/overmap/host = host_ref?.resolve()
		var/turf/overmap_turf = host && get_turf(host)
		if(overmap_turf && SSovermap_zones)
			zone_type = SSovermap_zones.resolve_zone_for_overmap_turf(overmap_turf)
	return zone_type

/proc/outpost_network_zone_name(zone)
	switch(zone)
		if(ZONE_GREEN)
			return ZONE_NAME_GREEN
		if(ZONE_YELLOW)
			return ZONE_NAME_YELLOW
		if(ZONE_RED)
			return ZONE_NAME_RED
	return "Unknown zone"

/// The host's display name
/obj/machinery/outpost_network_pad/proc/site_name()
	var/obj/structure/overmap/host = host_ref?.resolve()
	return host ? host.name : "Offline pad"

/// Charge-up for a trip from here to `destination`
/obj/machinery/outpost_network_pad/proc/charge_time_to(obj/machinery/outpost_network_pad/destination)
	var/here = get_zone()
	var/there = destination?.get_zone()
	if(here && there && here != there)
		return OUTPOST_NETWORK_CROSS_ZONE_CHARGE_TIME
	return OUTPOST_NETWORK_CHARGE_TIME

/// What `traveller` pays to arrive on this pad: 0 at a trader, for members, while ownerless, or when the fare is 0
/obj/machinery/outpost_network_pad/proc/arrival_fee(mob/living/traveller)
	var/obj/structure/overmap/dynamic/player_outpost/home = player_host()
	if(!home)
		return 0
	return home.service_price_for(traveller, home.get_price(OUTPOST_PRICE_TELEPORT_ARRIVAL))

/obj/machinery/outpost_network_pad/proc/is_charging()
	return !!charging_ref?.resolve()

/obj/machinery/outpost_network_pad/proc/is_receiving()
	var/obj/machinery/outpost_network_pad/source = incoming_ref?.resolve()
	return !QDELETED(source) && source.charge_target_ref?.resolve() == src

// ===== WHO MAY LEAVE =====

/**
 * Why `traveller` cannot leave from this pad right now, or null. Rerun at every step. The source
 * outpost's owner has no say: only the destination decides who arrives.
 */
/obj/machinery/outpost_network_pad/proc/departure_denial(mob/living/traveller)
	if(!istype(traveller) || !(iscarbon(traveller) || iscyborg(traveller)))
		return "People only."
	if(!network_host())
		return "Pad offline."
	if(traveller.stat != CONSCIOUS || HAS_TRAIT(traveller, TRAIT_INCAPACITATED))
		return "You must be awake."
	var/mob/living/carbon/carbon_traveller = traveller
	if(HAS_TRAIT(traveller, TRAIT_RESTRAINED) || (istype(carbon_traveller) && carbon_traveller.handcuffed))
		return "Restrained."
	if(HAS_TRAIT(traveller, TRAIT_NO_TELEPORT))
		return "Something holds you in place."
	if(traveller.loc != get_turf(src))
		return "Stand on the pad."
	if(traveller.buckled)
		return "Get up first."
	if(traveller.has_buckled_mobs())
		return "Put them down first."
	if(traveller.pulling)
		return "Let go first."
	if(traveller.pulledby)
		return "Someone is holding you."
	var/mob/living/carried = carried_passenger(traveller)
	if(carried)
		return "You are carrying [carried.name]."
	var/obj/item/cargo = refused_cargo(traveller)
	if(cargo)
		return "The pad refuses [cargo.name]."
	var/ready_at = traveller.ckey && GLOB.outpost_network_ready_at[traveller.ckey]
	if(ready_at && world.time < ready_at)
		return "Recharging ([round((ready_at - world.time) / (1 SECONDS))] s)."
	var/mob/living/current = charging_ref?.resolve()
	if(current && current != traveller)
		return "Pad in use."
	// Someone on the way in lands on the pad
	if(is_receiving())
		return "Pad in use."
	return null

/// A mob the traveller carries at any depth (bags, holders, cards, body bags), or null. A cyborg's own brain is fine.
/obj/machinery/outpost_network_pad/proc/carried_passenger(mob/living/traveller)
	var/mob/living/own_brain
	if(iscyborg(traveller))
		var/mob/living/silicon/robot/borg = traveller
		own_brain = borg.mmi?.brainmob
	for(var/mob/living/passenger as anything in traveller.get_all_contents_type(/mob/living))
		if(passenger == traveller || passenger == own_brain)
			continue
		return passenger
	return null

/// Contract cargo and anything that must never leave the round, carried at any depth, or null
/obj/machinery/outpost_network_pad/proc/refused_cargo(mob/living/traveller)
	for(var/obj/item/carried as anything in traveller.get_all_contents_type(/obj/item))
		if(istype(carried, /obj/item/freight_pod) || istype(carried, /obj/item/mission_recovery) || is_type_in_typecache(carried, GLOB.cryo_undeletable_items))
			return carried
	return null

// ===== WHO MAY ARRIVE =====

/**
 * Why `traveller` cannot arrive on this pad from `source`, or null. First match wins.
 * `ignore_busy` skips the one-inbound-at-a-time rule (the committing trip held that claim).
 */
/obj/machinery/outpost_network_pad/proc/arrival_denial(mob/living/traveller, obj/machinery/outpost_network_pad/source, ignore_busy = FALSE)
	var/obj/structure/overmap/host = network_host()
	if(!host)
		return "Offline"
	if(source == src || (is_trader && source?.is_trader))
		return "No route"
	if(is_trader)
		var/obj/structure/overmap/trader_outpost/market = host
		if(market.is_user_barred(traveller))
			return "Refused"
	else
		var/obj/structure/overmap/dynamic/player_outpost/home = host
		if(!home.founder_ckey)
			return "Closed"
		if(home.crews_banned_ship(traveller))
			return "Refused"
		if(!home.is_outpost_member(traveller))
			var/refusal = policy_denial(home, traveller, source)
			if(refusal)
				return refusal
	var/tile_denial = arrival_tile_denial()
	if(tile_denial)
		return tile_denial
	// Nobody arrives in a room they could not walk out of (abuse review F-03)
	var/obj/structure/overmap/dynamic/player_outpost/exit_home = host
	if(!is_trader)
		var/datum/outpost_upgrade/service/teleporter/room = exit_home.service_upgrade("teleporter")
		var/exit_denial = room?.exit_denial()
		if(exit_denial)
			return exit_denial
	// Arrivals land on the pad: not while someone is leaving from it, and one inbound trip at a time
	if(is_charging())
		return "Pad in use"
	if(!ignore_busy && is_receiving())
		return "Busy"
	return null

/// The owner's arrival rules for a non-member, or null when they are admitted
/obj/machinery/outpost_network_pad/proc/policy_denial(obj/structure/overmap/dynamic/player_outpost/home, mob/living/traveller, obj/machinery/outpost_network_pad/source)
	if(home.dock_mode == OUTPOST_DOCK_MODE_LOCKDOWN)
		return "Lockdown"
	var/datum/outpost_upgrade/service/teleporter/room = home.service_upgrade("teleporter")
	switch(room?.arrival_policy)
		if(OUTPOST_NETWORK_ARRIVALS_OPEN)
			// REQUEST docking vets ships; the pad vets their crews the same way (R9)
			if(home.dock_mode == OUTPOST_DOCK_MODE_REQUEST && !home.crews_approved_ship(traveller))
				return "Approved crews only"
			return null
		if(OUTPOST_NETWORK_ARRIVALS_MEMBERS)
			return "Members only"
		if(OUTPOST_NETWORK_ARRIVALS_ALLOWLIST)
			if(source && (source.network_id in room.allowed_pads))
				return null
			return "Not on the list"
	return "Closed"

/// Whether the arrival tile can take someone: open and clear of dense fixtures
/obj/machinery/outpost_network_pad/proc/arrival_tile_denial()
	var/turf/open/tile = arrival_turf
	if(!istype(tile))
		return "Arrival blocked"
	for(var/obj/thing in tile)
		if(outpost_exit_fixed_blocker(thing))
			return "Arrival blocked"
	return null

// ===== THE TRIP =====

/**
 * Starts the charge-up toward `destination`. `shown_fee` is the fare the traveller saw (0 for a
 * member). Returns null when charging, else a refusal. Never sleeps.
 */
/obj/machinery/outpost_network_pad/proc/start_trip(mob/living/traveller, obj/machinery/outpost_network_pad/destination, shown_fee)
	if(QDELETED(destination) || !(destination in GLOB.outpost_network_pads))
		return "Destination offline."
	// One charge per pad: a second confirm would retarget the running charge (abuse review B-06)
	if(charging_ref?.resolve())
		return "Pad in use."
	var/denial = departure_denial(traveller) || destination.arrival_denial(traveller, src)
	if(denial)
		return denial
	var/fee = destination.arrival_fee(traveller)
	if(!isnum(shown_fee) || shown_fee != fee)
		return "Price changed to [fee] cr."
	var/pay_denial = payment_denial(traveller, fee, destination.player_host())
	if(pay_denial)
		return pay_denial
	var/charge_time = charge_time_to(destination)
	// Claim both ends before anything can yield
	charging_ref = WEAKREF(traveller)
	charge_target_ref = WEAKREF(destination)
	destination.incoming_ref = WEAKREF(src)
	charge_fee = fee
	charge_started = world.time
	charge_ends = world.time + charge_time
	RegisterSignals(traveller, list(COMSIG_MOVABLE_MOVED, COMSIG_QDELETING), PROC_REF(on_traveller_moved))
	RegisterSignal(traveller, COMSIG_MOB_APPLY_DAMAGE, PROC_REF(on_traveller_damaged))
	RegisterSignal(traveller, COMSIG_MOB_STATCHANGE, PROC_REF(on_traveller_stat))
	// Both ends glow for the whole charge, so the destination sees the arrival coming
	charge_beams = list()
	for(var/turf/beam_turf in list(get_turf(src), destination.arrival_turf))
		var/obj/effect/temp_visual/transporter_beam/beam = new(beam_turf, charge_time + 1 SECONDS)
		charge_beams += WEAKREF(beam)
	charge_alpha = transporter_dematerialise(traveller, charge_time)
	playsound(src, 'sound/machines/terminal/terminal_alert.ogg', 40, TRUE)
	playsound(destination.arrival_turf, 'sound/machines/terminal/terminal_alert.ogg', 40, TRUE)
	destination.arrival_turf.visible_message(span_notice("[destination] lights up. Someone is on the way."), vision_distance = 7)
	if(charge_timer)
		deltimer(charge_timer)
	charge_timer = addtimer(CALLBACK(src, PROC_REF(finish_trip)), charge_time, TIMER_STOPPABLE)
	update_appearance()
	destination.update_appearance()
	log_game("OUTPOST NETWORK: [key_name(traveller)] began a trip from [site_name()] ([AREACOORD(src)]) to [destination.site_name()], fare [fee] cr")
	return null

/// Whether `traveller` can pay `fee` from the ID they present, or null
/obj/machinery/outpost_network_pad/proc/payment_denial(mob/living/traveller, fee, obj/structure/overmap/dynamic/player_outpost/payee)
	if(fee <= 0)
		return null
	var/datum/bank_account/account = traveller.get_idcard(TRUE)?.registered_account
	if(!account)
		return "No bank account on your ID."
	if(payee && account == payee.treasury)
		return "Payment declined."
	if(!account.has_money(fee))
		return "Insufficient credits."
	return null

/// Drops this pad's charge claim and signals, returning the traveller. Visuals are the caller's.
/obj/machinery/outpost_network_pad/proc/release_charge()
	var/mob/living/traveller = charging_ref?.resolve()
	if(traveller)
		UnregisterSignal(traveller, list(COMSIG_MOVABLE_MOVED, COMSIG_QDELETING, COMSIG_MOB_APPLY_DAMAGE, COMSIG_MOB_STATCHANGE))
	var/obj/machinery/outpost_network_pad/destination = charge_target_ref?.resolve()
	if(destination && destination.incoming_ref?.resolve() == src)
		destination.incoming_ref = null
		destination.update_appearance()
	if(charge_timer)
		deltimer(charge_timer)
		charge_timer = null
	charging_ref = null
	charge_target_ref = null
	charge_fee = 0
	charge_started = 0
	charge_ends = 0
	update_appearance()
	return traveller

/// Stops a charge with nothing charged and puts the traveller back as they were
/obj/machinery/outpost_network_pad/proc/cancel_charge(reason)
	if(!charging_ref)
		return
	undo_charge_visuals(release_charge(), reason)

/// Clears the beams and gives the traveller back their look, telling them why
/obj/machinery/outpost_network_pad/proc/undo_charge_visuals(mob/living/traveller, reason)
	for(var/datum/weakref/beam_ref as anything in charge_beams)
		var/obj/effect/beam = beam_ref.resolve()
		if(!QDELETED(beam))
			qdel(beam)
	charge_beams = null
	if(!QDELETED(traveller))
		transporter_restore(traveller, charge_alpha)
		if(reason)
			traveller.balloon_alert(traveller, "trip cancelled")
			to_chat(traveller, span_warning("[reason] Trip cancelled."))
	playsound(src, 'sound/machines/terminal/terminal_error.ogg', 40, TRUE)

/obj/machinery/outpost_network_pad/proc/on_traveller_moved(mob/living/source)
	SIGNAL_HANDLER
	cancel_charge("You left the pad.")
	stamp_cancel_cooldown(source)

/**
 * A trip the traveller walked away from (or called off) costs a short recharge, so charging and
 * cancelling cannot hold two pads busy for free. Damage, passing out and a grab at the end
 * cancel without it: the traveller did not choose those.
 */
/obj/machinery/outpost_network_pad/proc/stamp_cancel_cooldown(mob/living/traveller)
	var/key = traveller?.ckey
	if(!key)
		return
	GLOB.outpost_network_ready_at[key] = max(GLOB.outpost_network_ready_at[key], world.time + OUTPOST_NETWORK_CANCEL_COOLDOWN)

/obj/machinery/outpost_network_pad/proc/on_traveller_damaged(mob/living/source, damage)
	SIGNAL_HANDLER
	if(damage > 0)
		cancel_charge("You were hurt.")

/obj/machinery/outpost_network_pad/proc/on_traveller_stat(mob/living/source, new_stat)
	SIGNAL_HANDLER
	if(new_stat != CONSCIOUS)
		cancel_charge("You passed out.")

/**
 * The end of the charge-up. Every check runs again, then the move, then the payment, with no yield
 * anywhere: a failed move charges nothing, so there is never a refund. Returns null on a trip,
 * else the refusal.
 */
/obj/machinery/outpost_network_pad/proc/finish_trip()
	// Called early (tests), the pending timer must not finish the trip twice. From the timer
	// itself this is a no-op: a spent one-shot timer is not deleted by deltimer().
	if(charge_timer)
		deltimer(charge_timer)
		charge_timer = null
	var/mob/living/traveller = charging_ref?.resolve()
	var/obj/machinery/outpost_network_pad/destination = charge_target_ref?.resolve()
	var/shown_fee = charge_fee
	if(!traveller)
		cancel_charge()
		return "No traveller."
	// Drop the claim first, so the rechecks do not see this trip as someone else's
	release_charge()
	var/denial
	if(QDELETED(destination) || !(destination in GLOB.outpost_network_pads))
		denial = "The destination went offline."
	else
		denial = departure_denial(traveller) || destination.arrival_denial(traveller, src, ignore_busy = TRUE)
	var/fee = denial ? 0 : destination.arrival_fee(traveller)
	if(!denial && fee != shown_fee)
		denial = "Price changed to [fee] cr."
	if(!denial)
		denial = payment_denial(traveller, fee, destination.player_host())
	if(denial)
		undo_charge_visuals(traveller, denial)
		return denial
	var/turf/departure = get_turf(src)
	var/turf/arrival = destination.arrival_turf
	committing_ref = WEAKREF(traveller)
	committing_turf = arrival
	var/moved = do_teleport(traveller, arrival, precision = 0, no_effects = TRUE, channel = TELEPORT_CHANNEL_OUTPOST_NETWORK, forced = TRUE)
	committing_ref = null
	committing_turf = null
	charge_beams = null
	if(!moved || get_turf(traveller) != arrival)
		transporter_restore(traveller, charge_alpha)
		to_chat(traveller, span_warning("The pad could not lock on to you."))
		playsound(src, 'sound/machines/terminal/terminal_error.ogg', 40, TRUE)
		log_game("OUTPOST NETWORK: [key_name(traveller)]'s trip from [site_name()] to [destination.site_name()] was refused by the teleport")
		return "The pad could not lock on."
	var/paid = 0
	var/obj/structure/overmap/dynamic/player_outpost/home = destination.player_host()
	if(fee > 0 && home)
		var/refusal = home.charge_service(traveller, OUTPOST_PRICE_TELEPORT_ARRIVAL, home.get_price(OUTPOST_PRICE_TELEPORT_ARRIVAL), fee, "Teleporter arrival fare")
		if(refusal)
			log_game("OUTPOST NETWORK: [key_name(traveller)] arrived at [home.name] without paying the [fee] cr fare: [refusal]")
		else
			paid = fee
	if(traveller.ckey)
		GLOB.outpost_network_ready_at[traveller.ckey] = world.time + OUTPOST_NETWORK_TRAVELLER_COOLDOWN
	count_trip(destination)
	new /obj/effect/temp_visual/transporter_flash/departure(departure)
	new /obj/effect/temp_visual/transporter_flash(arrival)
	transporter_sparks(arrival)
	transporter_materialise(traveller, charge_alpha)
	playsound(departure, 'sound/effects/magic/teleport_diss.ogg', 40, TRUE)
	playsound(arrival, 'sound/effects/magic/teleport_app.ogg', 40, TRUE)
	to_chat(traveller, span_notice("You arrive at [destination.site_name()].[paid ? " Fare: [paid] cr." : ""]"))
	log_game("OUTPOST NETWORK: [key_name(traveller)] travelled from [site_name()] ([outpost_network_zone_name(get_zone())]) to [destination.site_name()] ([outpost_network_zone_name(destination.get_zone())]), paid [paid] cr")
	return null

/// Trip counters on the player rooms at both ends
/obj/machinery/outpost_network_pad/proc/count_trip(obj/machinery/outpost_network_pad/destination)
	var/obj/structure/overmap/dynamic/player_outpost/home = player_host()
	var/datum/outpost_upgrade/service/teleporter/room = home?.service_upgrade("teleporter")
	if(istype(room))
		room.trips_out++
	home = destination.player_host()
	room = home?.service_upgrade("teleporter")
	if(istype(room))
		room.trips_in++

// ===== CLEAR PAD =====

/**
 * Steps an idle occupant off the pad so `waiting` can use it: someone with no client, or inactive
 * for OUTPOST_NETWORK_IDLE_CLEAR. Never someone charging or buckled. Returns the mob moved, or null.
 */
/obj/machinery/outpost_network_pad/proc/clear_idle_occupant(mob/living/waiting)
	var/turf/pad_turf = get_turf(src)
	var/mob/living/traveller = charging_ref?.resolve()
	for(var/mob/living/occupant in pad_turf)
		if(occupant == waiting || occupant == traveller || occupant.buckled)
			continue
		if(occupant.client && occupant.client.inactivity < OUTPOST_NETWORK_IDLE_CLEAR)
			continue
		var/turf/aside = pad_step_off_turf()
		if(!aside)
			return null
		occupant.forceMove(aside)
		occupant.visible_message(span_notice("[src] nudges [occupant] off the pad."))
		log_game("OUTPOST NETWORK: [key_name(occupant)] was moved off the idle pad at [site_name()] for [key_name(waiting)]")
		return occupant
	return null

/// A free open tile beside the pad, or null
/obj/machinery/outpost_network_pad/proc/pad_step_off_turf()
	for(var/direction in GLOB.cardinals)
		var/turf/open/aside = get_step(src, direction)
		if(!istype(aside) || aside == arrival_turf || aside.is_blocked_turf(exclude_mobs = FALSE))
			continue
		return aside
	return null

// ===== MACHINE =====

/obj/machinery/outpost_network_pad/update_icon_state()
	icon_state = (is_charging() || is_receiving()) ? "[base_icon_state]_active" : base_icon_state
	return ..()

/obj/machinery/outpost_network_pad/examine(mob/user)
	. = ..()
	if(!network_host())
		. += span_warning("It is not linked to the network.")
		return
	. += span_notice("It serves [site_name()] in the [outpost_network_zone_name(get_zone())].")
	var/obj/structure/overmap/dynamic/player_outpost/home = player_host()
	var/fare = home?.get_price(OUTPOST_PRICE_TELEPORT_ARRIVAL)
	if(fare)
		. += span_notice("Arrival fare: [fare] cr.")

/obj/machinery/outpost_network_pad/emag_act(mob/user, obj/item/card/emag/emag_card)
	balloon_alert(user, "no effect")
	return FALSE

/obj/machinery/outpost_network_pad/multitool_act(mob/living/user, obj/item/tool)
	return ITEM_INTERACT_BLOCKING

/obj/machinery/outpost_network_pad/singularity_act()
	return 0

/obj/machinery/outpost_network_pad/singularity_pull(atom/singularity, current_size)
	return

/// A traveller stepping on gets the destination list
/obj/machinery/outpost_network_pad/proc/on_entered(datum/source, atom/movable/arrived, atom/old_loc)
	SIGNAL_HANDLER
	var/mob/living/visitor = arrived
	if(!istype(visitor) || !visitor.client || !network_host())
		return
	// The window is for stepping onto the pad, not for arriving on it
	var/turf/came_from = get_turf(old_loc)
	if(!came_from || came_from.z != z || get_dist(came_from, src) > 1)
		return
	INVOKE_ASYNC(src, TYPE_PROC_REF(/datum, ui_interact), visitor)

// ===== TRADER PADS =====

/obj/structure/overmap/trader_outpost
	/// This outpost's public network pad
	var/datum/weakref/network_pad_ref

/**
 * Puts this trading outpost's network pad in its concourse. Called once the interior has loaded,
 * outside the load's try block: a runtime inside it would unwind the whole load. The trader maps
 * are regenerated from plans, so the pad is placed here rather than mapped: a breadth-first walk
 * from the elevator alcove to the first clear tile 2 to 4 steps out, against a wall where one is
 * available, with a clear arrival spot beside it.
 */
/obj/structure/overmap/trader_outpost/proc/spawn_network_pad()
	var/obj/machinery/outpost_network_pad/existing = network_pad_ref?.resolve()
	if(!QDELETED(existing))
		return existing
	var/list/spot = find_network_pad_spot()
	if(!spot)
		log_mapping("OUTPOST NETWORK: no free concourse tile for [name]'s network pad; it is off the network.")
		return null
	var/obj/machinery/outpost_network_pad/trader/pad = new(spot[1])
	pad.link_host(src)
	// The same protection as a service room's fixtures: property, explosion and singularity proof
	var/datum/outpost_upgrade/service/teleporter/prototype = GLOB.outpost_upgrade_catalog["teleporter"]
	if(istype(prototype))
		prototype.protect_fixture(pad)
	else
		pad.AddElement(/datum/element/outpost_property)
	network_pad_ref = WEAKREF(pad)
	return pad

/// Whether a trader concourse tile could hold the pad or its arrival spot
/obj/structure/overmap/trader_outpost/proc/network_pad_tile_clear(turf/tile)
	if(!isopenturf(tile) || !istype(tile.loc, /area/voidcrew/trader_outpost) || (tile in lobby_alcove_turfs))
		return FALSE
	for(var/atom/movable/thing as anything in tile)
		if(isliving(thing) || istype(thing, /obj/machinery/door))
			return FALSE
		if(iseffect(thing))
			continue
		if(thing.density || thing.anchored)
			return FALSE
	return TRUE

/// list(pad turf, arrival turf) for the network pad, or null
/obj/structure/overmap/trader_outpost/proc/find_network_pad_spot()
	if(!length(lobby_alcove_turfs))
		return null
	var/list/distance = list()
	var/list/queue = list()
	for(var/turf/alcove as anything in lobby_alcove_turfs)
		distance[alcove] = 0
		queue += alcove
	var/list/candidates = list()
	var/index = 1
	while(index <= length(queue))
		var/turf/current = queue[index++]
		var/steps = distance[current]
		if(steps >= 4)
			continue
		for(var/direction in GLOB.cardinals)
			var/turf/next = get_step(current, direction)
			if(!next || !isnull(distance[next]) || !isopenturf(next) || !istype(next.loc, /area/voidcrew/trader_outpost))
				continue
			var/walkable = TRUE
			for(var/atom/movable/thing as anything in next)
				if(thing.density && !istype(thing, /obj/machinery/door) && !isliving(thing))
					walkable = FALSE
					break
			if(!walkable)
				continue
			distance[next] = steps + 1
			queue += next
			if(steps + 1 >= 2 && network_pad_tile_clear(next))
				candidates += next
	var/list/fallback
	for(var/turf/candidate as anything in candidates)
		var/turf/arrival
		for(var/direction in GLOB.cardinals)
			var/turf/beside = get_step(candidate, direction)
			if(beside && network_pad_tile_clear(beside))
				arrival = beside
				break
		if(!arrival)
			continue
		// Prefer a tile against a wall, out of the walking lanes
		for(var/direction in GLOB.cardinals)
			if(isclosedturf(get_step(candidate, direction)))
				return list(candidate, arrival)
		if(!fallback)
			fallback = list(candidate, arrival)
	return fallback
