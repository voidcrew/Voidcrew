/*
 * # Voidcrew ship-to-ship holo-calls
 *
 * Upstream holopads assume a single static station: the dial list is every
 * on-network pad in the world grouped by area, which on Voidcrew mixes every
 * ship, outpost and ruin in the galaxy into one meaningless area list.
 *
 * Instead the dial list is site-aware. A holopad resolves the "site" it is on
 * lazily, at dial time (nothing is cached, so mid-round construction and
 * z-hops can never leave a stale binding, same idiom as the per-ship camera
 * networks in voidcrew/edits/machinery/camera.dm):
 *
 * * Ships, via the mobile docking port (SSshuttle.get_containing_shuttle()).
 * * Outposts (trader or player-founded), via their interior footprints.
 * * Anything else (ruins, wrecks) is an unregistered site.
 *
 * The dial list then shows: pads on your own site by area (upstream intra-ship
 * behaviour), every other ship as one "[shipname] (ship)" entry that rings all
 * of that ship's pads at once, outposts likewise, and unregistered pads only
 * under "(nearby)" when they share your physical z-level. Ringing, accepting,
 * declining and hangup all reuse the stock /datum/holocall flow, which is
 * already location-agnostic.
 *
 * Range gating is a single proc (voidcrew_holocall_gate); calls are currently
 * allowed galaxy-wide, consistent with the infrastructure-free Wideband radio.
 * The gate is re-checked for the life of a cross-site call, and a cross-site
 * call drops gracefully the moment either endpoint physically moves (ship
 * jump, dock, undock), the fiction being that bluespace transit breaks the
 * carrier lock. Same-site calls are untouched: both ends move together.
 *
 * The only upstream change is the dial-list block of ui_act("holocall") in
 * code/game/machinery/hologram.dm (VOIDCREW EDIT markers there).
 */

// ===== SITE RESOLUTION =====

/// The voidcrew ship (mobile docking port) this holopad is physically aboard, or null.
/// Resolved live on every call: robust to mid-round construction and ship movement.
/obj/machinery/holopad/proc/voidcrew_ship_port()
	var/obj/docking_port/mobile/voidcrew/ship_port = SSshuttle.get_containing_shuttle(src)
	return istype(ship_port) ? ship_port : null

/// Holopad site API: does this overmap object's loaded interior contain the given turf?
/// FALSE by default; opt-in per overmap type below.
/obj/structure/overmap/proc/voidcrew_holopad_site_contains(turf/target)
	return FALSE

/obj/structure/overmap/trader_outpost/voidcrew_holopad_site_contains(turf/target)
	if(!template_bottom_left || !outpost_template?.width || !outpost_template?.height)
		return FALSE
	if(target.z != template_bottom_left.z)
		return FALSE
	return target.x >= template_bottom_left.x && target.y >= template_bottom_left.y \
		&& target.x < template_bottom_left.x + outpost_template.width \
		&& target.y < template_bottom_left.y + outpost_template.height

/obj/structure/overmap/dynamic/player_outpost/voidcrew_holopad_site_contains(turf/target)
	return is_turf_buildable(target)

/// The outpost whose interior this holopad sits in, or null. Ships are checked
/// separately (and first) by callers: a pad on a ship docked inside an outpost
/// still belongs to the ship.
/obj/machinery/holopad/proc/voidcrew_holopad_site()
	var/turf/our_turf = get_turf(src)
	if(!our_turf)
		return null
	for(var/obj/structure/overmap/trader_outpost/outpost as anything in GLOB.trader_outposts)
		if(outpost.voidcrew_holopad_site_contains(our_turf))
			return outpost
	for(var/obj/structure/overmap/dynamic/player_outpost/outpost as anything in GLOB.player_outposts)
		if(outpost.voidcrew_holopad_site_contains(our_turf))
			return outpost
	return null

/// TRUE if both pads are on the same site (same ship, same outpost, or both
/// unregistered on the same physical z-level). Same-site calls keep full
/// upstream behaviour; cross-site calls get the transit-drop and gate checks.
/obj/machinery/holopad/proc/voidcrew_shares_site(obj/machinery/holopad/other)
	if(QDELETED(other))
		return FALSE
	var/obj/docking_port/mobile/voidcrew/our_port = voidcrew_ship_port()
	var/obj/docking_port/mobile/voidcrew/other_port = other.voidcrew_ship_port()
	if(our_port || other_port)
		return our_port == other_port
	var/obj/structure/overmap/our_site = voidcrew_holopad_site()
	var/obj/structure/overmap/other_site = other.voidcrew_holopad_site()
	if(our_site || other_site)
		return our_site == other_site
	var/turf/our_turf = get_turf(src)
	var/turf/other_turf = get_turf(other)
	if(!our_turf || !other_turf || our_turf.z != other_turf.z)
		return FALSE
	// Two unregistered pads on the same PACKED z-level are two unrelated crews' ruins,
	// six turfs of cordon apart. Treating them as one site would skip the cross-site
	// transit-drop and gate checks entirely and hand them an intra-site hologram channel.
	// Refuses only a positively-different region, so a roundstart level, deep space and a
	// single-tenant z all answer exactly as they did before.
	return !map_region_excludes_turf(map_region_for_turf(our_turf), other_turf)

/// Human-readable name of the site this pad transmits from, for ring announcements.
/obj/machinery/holopad/proc/voidcrew_site_name()
	var/obj/docking_port/mobile/voidcrew/ship_port = voidcrew_ship_port()
	if(ship_port)
		var/obj/structure/overmap/ship/ship = ship_port.current_ship
		if(ship)
			return ship.display_name || ship.name
		return ship_port.name
	var/obj/structure/overmap/site = voidcrew_holopad_site()
	if(site)
		return site.display_name || site.name
	var/area/our_area = get_area(src)
	return our_area ? "unregistered site ([format_text(our_area.name)])" : "unregistered site"

// ===== RANGE GATE =====

/**
 * The single range gate for holo-calls between sites. Return FALSE to make
 * `target` undialable from this pad (it also vanishes from the dial list).
 *
 * Currently galaxy-wide: the galaxy already has infrastructure-free
 * galaxy-wide voice (Wideband, voidcrew/modules/comms/comms.dm), so holo-calls
 * reaching just as far is consistent. To tighten later (e.g. same overmap
 * zone or sensor range only), put the check here. It is enforced when
 * building the dial list AND re-checked every process tick for the life of a
 * cross-site call, so an out-of-range mid-call ship drops automatically.
 */
/obj/machinery/holopad/proc/voidcrew_holocall_gate(obj/machinery/holopad/target)
	return TRUE

// ===== DIAL LIST =====

/**
 * Builds the holocall dial list: assoc list of "display name" -> list of pads
 * to ring. Replaces the upstream galaxy-wide area list (see the VOIDCREW EDIT
 * in /obj/machinery/holopad/ui_act("holocall")).
 *
 * Ordering: own-site areas first, then ships, then outposts, each sorted.
 */
/obj/machinery/holopad/proc/voidcrew_holocall_targets()
	var/obj/docking_port/mobile/voidcrew/our_ship = voidcrew_ship_port()
	var/obj/structure/overmap/our_site = our_ship ? null : voidcrew_holopad_site()
	var/area/our_area = get_area(src)
	var/turf/our_turf = get_turf(src)

	var/list/local_targets = list() // "area name" -> pads on our own site (or nearby unregistered)
	var/list/pads_by_ship = list() // mobile port -> pads aboard
	var/list/pads_by_outpost = list() // outpost overmap struct -> pads inside

	for(var/obj/machinery/holopad/pad as anything in holopads)
		if(pad == src || !pad.on_network || !pad.is_operational)
			continue
		if(!voidcrew_holocall_gate(pad))
			continue
		var/obj/docking_port/mobile/voidcrew/pad_ship = pad.voidcrew_ship_port()
		if(pad_ship)
			if(pad_ship == our_ship)
				var/area/pad_area = get_area(pad)
				if(pad_area && pad_area != our_area)
					var/key = format_text(pad_area.name)
					if(!local_targets[key])
						local_targets[key] = list()
					local_targets[key] += pad
			else
				if(!pads_by_ship[pad_ship])
					pads_by_ship[pad_ship] = list()
				pads_by_ship[pad_ship] += pad
			continue
		var/obj/structure/overmap/pad_site = pad.voidcrew_holopad_site()
		if(pad_site)
			if(pad_site == our_site)
				var/area/pad_area = get_area(pad)
				if(pad_area && pad_area != our_area)
					var/key = format_text(pad_area.name)
					if(!local_targets[key])
						local_targets[key] = list()
					local_targets[key] += pad
			else
				if(!pads_by_outpost[pad_site])
					pads_by_outpost[pad_site] = list()
				pads_by_outpost[pad_site] += pad
			continue
		// Unregistered pads (ruins, wrecks): no transponder to look up, so they
		// are only reachable from the same physical z-level ("nearby") - and, on a
		// packed z-level, from the same slot. A co-tenant's pad is not "nearby", it is
		// another crew's site behind five turfs of indestructible cordon.
		var/turf/pad_turf = get_turf(pad)
		if(pad_turf && our_turf && pad_turf.z == our_turf.z && !map_region_excludes_turf(map_region_for_turf(our_turf), pad_turf))
			var/area/pad_area = get_area(pad)
			if(pad_area && pad_area != our_area)
				var/key = "[format_text(pad_area.name)] (nearby)"
				if(!local_targets[key])
					local_targets[key] = list()
				local_targets[key] += pad

	var/list/targets = list()
	for(var/key in sort_list(local_targets))
		targets[key] = local_targets[key]

	var/list/ship_targets = list()
	for(var/obj/docking_port/mobile/voidcrew/ship_port as anything in pads_by_ship)
		var/obj/structure/overmap/ship/ship = ship_port.current_ship
		var/base_key = "[ship ? (ship.display_name || ship.name) : ship_port.name] (ship)"
		var/key = base_key
		var/suffix = 2
		while(!isnull(ship_targets[key])) // two ships sharing a name must not ring each other's pads
			key = "[base_key] [suffix]"
			suffix++
		ship_targets[key] = pads_by_ship[ship_port]
	for(var/key in sort_list(ship_targets))
		targets[key] = ship_targets[key]

	var/list/outpost_targets = list()
	for(var/obj/structure/overmap/outpost as anything in pads_by_outpost)
		var/base_key = "[outpost.display_name || outpost.name] (outpost)"
		var/key = base_key
		var/suffix = 2
		while(!isnull(outpost_targets[key]))
			key = "[base_key] [suffix]"
			suffix++
		outpost_targets[key] = pads_by_outpost[outpost]
	for(var/key in sort_list(outpost_targets))
		targets[key] = outpost_targets[key]

	return targets

// ===== CALL DATUM =====

/**
 * Holocall subtype every player-dialed call uses on Voidcrew (constructed in
 * the VOIDCREW EDIT in ui_act("holocall")). Same-site calls behave exactly
 * like upstream. For cross-site calls it additionally:
 *
 * * refuses keycard-auth forced auto-connection (nobody projects onto someone
 *   else's ship uninvited, the receiving crew always chooses to answer),
 * * announces the caller's site name on the ringing pads,
 * * drops the call gracefully if either endpoint physically moves (the far
 *   ship jumping, docking or undocking mid-call) or the range gate closes,
 *   checked from the calling pad's process() for the life of the call.
 */
/datum/holocall/voidcrew
	/// pad -> the turf it occupied at dial time; a cross-site endpoint on any other turf has moved (ship transit) and severs the link
	var/list/endpoint_turfs
	/// lazy list of dialed pads that did not share the caller's site at dial time
	var/list/cross_site_pads

/datum/holocall/voidcrew/New(mob/living/call_source, obj/machinery/holopad/calling_pad, list/callees, elevated_access = FALSE)
	if(elevated_access)
		for(var/obj/machinery/holopad/pad as anything in callees)
			if(!calling_pad.voidcrew_shares_site(pad))
				elevated_access = FALSE
				break
	..(call_source, calling_pad, callees, elevated_access)
	if(QDELETED(src))
		return
	endpoint_turfs = list()
	endpoint_turfs[calling_holopad] = get_turf(calling_holopad)
	for(var/obj/machinery/holopad/pad as anything in dialed_holopads)
		endpoint_turfs[pad] = get_turf(pad)
		if(!calling_pad.voidcrew_shares_site(pad))
			LAZYADD(cross_site_pads, pad)
			pad.say("Signal origin: [calling_pad.voidcrew_site_name()].")

/datum/holocall/voidcrew/Destroy()
	endpoint_turfs = null
	cross_site_pads = null
	return ..()

/**
 * A dialed pad that drops out mid-ring is only pruned from `dialed_holopads` by the
 * parent; our two lists would keep hard-referencing it for the rest of the call, which
 * is a harddel if the pad was destroyed. Every teardown path, Disconnect(), a pad
 * going non-operational in Check(), Answer() dropping the pads that lost the race.
 * Funnels through here, so this is the one place that needs to forget it.
 */
/datum/holocall/voidcrew/ConnectionFailure(obj/machinery/holopad/disconnected_holopad, graceful = FALSE)
	if(endpoint_turfs)
		endpoint_turfs -= disconnected_holopad
	LAZYREMOVE(cross_site_pads, disconnected_holopad)
	return ..()

/datum/holocall/voidcrew/Check()
	. = ..()
	if(!. || QDELETED(src) || !LAZYLEN(cross_site_pads))
		return
	// Cross-site link: either endpoint moving (ship jump/dock/undock) or the
	// range gate closing severs the carrier. Same-site calls never get here.
	if(get_turf(calling_holopad) != endpoint_turfs[calling_holopad])
		return sever_link()
	for(var/obj/machinery/holopad/pad as anything in dialed_holopads)
		if(!(pad in cross_site_pads))
			continue
		if(get_turf(pad) != endpoint_turfs[pad] || !calling_holopad.voidcrew_holocall_gate(pad))
			return sever_link()

/// Gracefully drops a cross-site call whose carrier broke (endpoint in transit
/// or out of range). Both ends are told why; Destroy() does the actual cleanup.
/datum/holocall/voidcrew/proc/sever_link()
	if(!QDELETED(calling_holopad))
		calling_holopad.say("Carrier lost: remote pad in transit or out of range.")
	if(connected_holopad && !QDELETED(connected_holopad))
		connected_holopad.say("Carrier lost: link severed.")
	qdel(src)
	return FALSE
