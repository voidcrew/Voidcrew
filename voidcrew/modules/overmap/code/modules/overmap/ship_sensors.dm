/**
 * # Ship Sensors & Discovery
 *
 * TWO RINGS, and keeping them apart is the whole design:
 *
 * - The **view ring** is SHIP_VIEW_RANGE (4) and never changes. It is free,
 *   passive and live, the radius the old camera console rendered. Everything
 *   physically inside it draws on the helm chart: planets, ruins, outposts,
 *   nebulas, storms, vessels. No research, no scanning, no memory. Fly away and
 *   it is gone from the chart, because nothing recorded it.
 * - The **sensor ring** is get_sensor_range(), starts equal to the view ring and
 *   grows to 10 with radar research. Nothing in it draws on its own. It is the
 *   reach of an active scan, which CHARTS what it finds into the waypoint list,
 *   where it persists at any distance, drawn faded once it falls out of sight.
 *
 * So sensors never widen what you can see. They reach past sight, and what they
 * bring back is a waypoint: knowledge of something you could not look at.
 *
 * **Sight itself is permanent.** Anything drawn in the view ring is recorded into
 * `discovered_contacts` and stays on the chart for the rest of the round, faded
 * once it drops out of sight, you chart the sector by flying it. That makes the
 * radar tree a purchase of REACH and IDENTITY rather than of memory: a scan is
 * worth running for what sits beyond the hull's own eyes, and at base radar (where
 * the two rings coincide) it buys nothing you couldn't get by flying over there
 * yourself. Deliberate; the alternative was a crew re-discovering the same storm
 * every time they passed it.
 *
 * The radar capability ladder is a dedicated R&D tree (see `radar_array*` nodes
 * in [[modules/research]]), read off the ship's techweb:
 * - higher tiers widen the SENSOR ring (get_sensor_range),
 * - the mid tier identifies space ruins (true name instead of "unknown signal"),
 * - the top tier tracks vessels: it both extends them to the sensor ring and
 *   identifies them automatically, instead of one scan at a time.
 *
 * Vessels are the one thing never recorded, whatever the radar tier: they move,
 * so keeping a position would be a lie. They are live contacts or nothing, and an
 * unscanned one is an anonymous blip rather than a named ship.
 *
 * The one thing that ignores both rings is a **distress beacon**: a hull with its
 * beacon lit draws on every other ship's chart at any distance, whatever their
 * radar tier (see ship_distress.dm). That is deliberate and it is the only
 * exception - it is a broadcast the hull is making about itself, not something
 * anybody's sensors found.
 *
 * Hazards are still unreachable by a SCAN (`sensor_detectable = FALSE`), our own
 * sensors cannot pin a storm, so one has to be flown past to enter the log. What
 * they can be reached by is a star chart, which is bought survey data rather than
 * a sweep and records the whole band (see chart_zone). That is the difference the
 * two flags encode, and the reason a chart is worth paying a trader for.
 */

/// Base scan radius, in overmap tiles, with no radar research.
#define SENSOR_RANGE_BASE 4
/// Scan radius granted by the tier-1 radar array node.
#define SENSOR_RANGE_ADVANCED 6
/// Scan radius granted by the tier-2 radar array node.
#define SENSOR_RANGE_SUPERIOR 8
/// Scan radius granted by the tier-3 radar array node.
#define SENSOR_RANGE_ELITE 10

/// Recharge between active scans.
#define SENSOR_SCAN_COOLDOWN (1 MINUTES)

/// How long a helm contact snapshot stays warm before it is rebuilt.
#define CONTACT_SNAPSHOT_LIFETIME (1 SECONDS)

/**
 * How long discoveries are batched before the helms get a static-data refresh.
 *
 * Deliberately slack. A static refresh costs a full UI update, and flying into
 * unexplored space finds something new almost every tile, so a short window puts
 * us straight back to the per-frame cost this split exists to avoid. Nothing is
 * lost by waiting: whatever was just discovered is still inside the view ring and
 * is already being drawn by the LIVE pass, so the static entry doesn't matter
 * until the ship leaves it behind.
 */
#define CHARTED_PUSH_COALESCE (5 SECONDS)

/obj/structure/overmap
	/// Whether an active SCAN can chart this object, making it persist on the helm
	/// after it leaves the sensor bubble. Scannable statics only, set TRUE on
	/// planets and ruins. Hazards are visible up close but no sweep of ours can
	/// pin one; a bought star chart still records them (chart_zone reads
	/// sensor_visible instead, which is the whole point of buying one).
	var/sensor_detectable = FALSE
	/// Whether this object renders on the helm chart while it is inside the ship's
	/// VIEW ring: free, live, no research. TRUE for anything physically out there;
	/// cleared on objects the helm sources some other way (vessels, which need
	/// identity gating, and trader outposts, which broadcast sector-wide) or that
	/// aren't really present (empty-space placeholders).
	var/sensor_visible = TRUE
	/// Display category this object is grouped under on the helm readout, and
	/// the key an active scan matches against (e.g. "Planets", "Ruins").
	var/sensor_category = "Contacts"

/obj/structure/overmap/ship
	// Vessels are visible in the view ring like everything else, but they carry
	// identity the generic pass has no way to gate, so get_contact_snapshot gives
	// them their own pass rather than sourcing them from here.
	sensor_visible = FALSE
	/// Scan radius before R&D upgrades. See get_sensor_range().
	var/base_sensor_range = SENSOR_RANGE_BASE
	COOLDOWN_DECLARE(sensor_scan_cooldown)
	/// Cached techweb resolved from the onboard R&D server (see get_research_web).
	var/datum/weakref/research_web_ref
	COOLDOWN_DECLARE(research_web_search_cooldown)
	/// Cached contact list shared by every helm on this ship (get_contact_snapshot).
	var/list/contact_snapshot
	/// world.time the contact snapshot was last rebuilt.
	var/contact_snapshot_time = 0
	/// REF()s of vessels an active scan has identified, as an assoc set. Purely
	/// live: get_contact_snapshot rebuilds it from the ships still in contact, so
	/// a vessel that leaves the ring is forgotten and reads as unknown if it
	/// returns. Never charted, see the file header.
	var/list/identified_ships = list()
	/// Everything this ship has ever laid eyes on, as REF -> weakref. Recorded by
	/// the view-ring pass in get_contact_snapshot and kept for the round, so
	/// flying somewhere charts it permanently. Weakrefs rather than REF strings
	/// because BYOND recycles refs, and a recycled one would resolve to whatever
	/// took its place. Vessels are deliberately absent, see the file header.
	var/list/discovered_contacts = list()
	/// TRUE while a static-data refresh is already queued for this ship's helms.
	var/charted_push_queued = FALSE
	/// Which overmap tiles this ship's view ring has ever swept, as a flat grid
	/// indexed by ((y - 1) * OVERMAP_SIZE + x) in relative coordinates. Distinct
	/// from discovered_contacts, which can only record tiles that had something on
	/// them, empty space leaves no object behind, so "surveyed and empty" and
	/// "never looked" are otherwise the same thing. A flat list rather than an
	/// assoc of "x,y" keys: ~2600 slots is 20-odd KB and indexes in O(1).
	var/list/surveyed_tiles
	/// Tile the survey disc was last stamped from, so it's stamped once per move.
	var/surveyed_from_x = 0
	var/surveyed_from_y = 0

/**
 * Returns the ship's research techweb, the one hosted on its onboard R&D
 * server's disk, which is where radar nodes actually get researched. Cached by
 * weakref; the (potentially expensive) server search is throttled so a ship
 * with no R&D server doesn't rescan its whole hull every tick.
 */
/obj/structure/overmap/ship/proc/get_research_web()
	var/datum/techweb/web = research_web_ref?.resolve()
	if(web)
		return web
	if(!COOLDOWN_FINISHED(src, research_web_search_cooldown))
		return null
	COOLDOWN_START(src, research_web_search_cooldown, 10 SECONDS)
	web = find_research_web()
	if(web)
		research_web_ref = WEAKREF(web)
	return web

/**
 * Locates the techweb hosted by an R&D server somewhere on the ship's hull.
 *
 * Walks the server registry (GLOB.ship_research_servers, a handful of machines) and asks
 * which hull each one is standing in, rather than walking every turf of every shuttle
 * area and every turf's contents looking for one. The old form was O(hull turfs x turf
 * contents); on a Phalanx that is thousands of iterations, and get_research_web()'s
 * negative case - a hull with no server yet, which is most hulls for most of a round -
 * re-ran it every 10 seconds for every caller. It measured 5.7 ms per call and 8.99 s of
 * SSmissions' 9.05 s total across the ghost round.
 */
/obj/structure/overmap/ship/proc/find_research_web()
	if(!shuttle)
		return null
	for(var/obj/machinery/rnd/server/ship/server as anything in GLOB.ship_research_servers)
		if(QDELETED(server) || !server.stored_research)
			continue
		var/area/server_area = get_area(server)
		if(!server_area || !(server_area in shuttle.shuttle_areas))
			continue
		return server.stored_research
	return null

/**
 * Returns the scan radius in tiles, scaling with the ship's radar research tier.
 * Falls back to the base range with no radar nodes researched.
 */
/obj/structure/overmap/ship/proc/get_sensor_range()
	var/datum/techweb/web = get_research_web()
	if(web)
		if(TECHWEB_NODE_RADAR_ARRAY_ELITE in web.researched_nodes)
			return SENSOR_RANGE_ELITE
		if(TECHWEB_NODE_RADAR_ARRAY_ADV in web.researched_nodes)
			return SENSOR_RANGE_SUPERIOR
		if(TECHWEB_NODE_RADAR_ARRAY in web.researched_nodes)
			return SENSOR_RANGE_ADVANCED
	return base_sensor_range

/**
 * Whether the radar can identify space ruins (tier-2 radar node), revealing the
 * ruin's true name on the readout instead of the generic "unknown signal".
 */
/obj/structure/overmap/ship/proc/can_identify_ruins()
	var/datum/techweb/web = get_research_web()
	if(!web)
		return FALSE
	return (TECHWEB_NODE_RADAR_ARRAY_ADV in web.researched_nodes) || (TECHWEB_NODE_RADAR_ARRAY_ELITE in web.researched_nodes)

/**
 * Whether the radar can track live player-ship contacts (tier-3 radar node).
 */
/obj/structure/overmap/ship/proc/can_scan_ships()
	var/datum/techweb/web = get_research_web()
	if(!web)
		return FALSE
	return TECHWEB_NODE_RADAR_ARRAY_ELITE in web.researched_nodes

/**
 * Whether we know what another vessel IS, as opposed to merely that something is
 * out there. TRUE once an active scan has named it, once it has hailed us, once
 * we have held a weapons lock on it, or continuously at the top radar tier.
 *
 * This is the single gate every readout asks, and the reason it lives on the ship
 * rather than on the contact: identity is not a property of the hull out there,
 * it is a property of what THIS crew has done about it. A console that answers the
 * question for itself will always drift out of step with the chart, which is
 * exactly what the combat console used to do, naming hulls the helm still drew as
 * anonymous blips.
 */
/obj/structure/overmap/ship/proc/knows_vessel(obj/structure/overmap/ship/other)
	if(!other || other == src)
		return FALSE
	return can_scan_ships() || !!identified_ships[REF(other)]

/**
 * Records another vessel as identified, and drops the contact cache so the name
 * appears on the helm now rather than up to a second later. Returns TRUE only if
 * this was new knowledge.
 *
 * Anything that amounts to LOOKING at a hull should call this: an active scan, a
 * received hail, a completed weapons lock. Nothing here is permanent,
 * get_contact_snapshot rebuilds the set from what is still in contact, so a vessel
 * that drifts away is forgotten and comes back anonymous (see the file header).
 */
/obj/structure/overmap/ship/proc/mark_vessel_identified(obj/structure/overmap/ship/other)
	if(!other || other == src)
		return FALSE
	var/ship_ref = REF(other)
	if(identified_ships[ship_ref])
		return FALSE
	identified_ships[ship_ref] = TRUE
	contact_snapshot = null
	return TRUE

/**
 * How the helm's Dock button should name another vessel sharing our tile.
 *
 * Docking with a ship is still the request/accept handshake ship_act() runs on
 * /obj/structure/overmap/ship (see ship.dm), this only decides what the button
 * calls the option, and it keeps the same anonymity an unidentified contact has
 * everywhere else on the chart (see identify_vessels() above): sharing a tile
 * doesn't reveal a hull the crew hasn't scanned or tracked.
 */
/obj/structure/overmap/ship/proc/describe_dock_target(obj/structure/overmap/ship/other)
	if(!other || other == src)
		return null
	var/label = knows_vessel(other) ? other.display_name : "unknown vessel"
	return "[label] (request docking)"

/**
 * The categories a helm may ask an active scan for, and the only values the
 * console will pass through. Mirrors SCAN_TYPES in HelmComputer.tsx. Every other
 * sensor_category in use is deliberately not offered: hazards and nebulas are
 * `sensor_detectable = FALSE` (star charts are the only way to learn them) and
 * trader outposts are already permanently on every chart.
 *
 * An unfiltered scan is not one of the options. Passing no category at all makes
 * active_scan() sweep every category at once for a single cooldown, which is why
 * the console validates against this list rather than forwarding what it is given.
 */
GLOBAL_LIST_INIT(overmap_scan_categories, list("Planets", "Ruins", "Ships"))

/**
 * Active scan: sweeps for static objects in the given category within sensor
 * range and adds each as a waypoint. Returns the count of newly-added contacts
 * (already-charted ones are refreshed in place, not recounted), or -1 if the
 * sensors are still recharging from a previous scan.
 */
/obj/structure/overmap/ship/proc/active_scan(category)
	if(state != OVERMAP_SHIP_FLYING)
		return 0
	if(!COOLDOWN_FINISHED(src, sensor_scan_cooldown))
		return -1
	var/turf/center = get_turf(src)
	if(!center)
		return 0
	// Vessels are identified rather than charted, and only out to the view ring:
	// there is nothing to interrogate past it, since an unscanned ship beyond
	// sight doesn't appear at all without the top radar tier.
	if(category == "Ships")
		return identify_vessels(center)
	var/found = 0
	for(var/obj/structure/overmap/candidate in range(get_sensor_range(), center))
		if(candidate == src || !candidate.sensor_detectable)
			continue
		if(category && candidate.sensor_category != category)
			continue
		if(chart_as_waypoint(candidate))
			found++
	// Only spend the cooldown on a productive scan. An empty sweep can retry.
	if(found > 0)
		COOLDOWN_START(src, sensor_scan_cooldown, SENSOR_SCAN_COOLDOWN)
	return found

/**
 * Resolves the identity of every vessel currently inside the view ring, lifting
 * them from "unknown contact" to a named ship with a hull readout and a hostile
 * flag. Returns the count newly identified.
 *
 * Nothing is charted and nothing is remembered past the contact itself: the
 * identification lives only as long as the ship stays in the ring. This is the
 * cheap, one-at-a-time version of what the top radar tier does continuously.
 */
/obj/structure/overmap/ship/proc/identify_vessels(turf/center)
	var/found = 0
	for(var/obj/structure/overmap/ship/other in range(SHIP_VIEW_RANGE, center))
		if(other == src || other.hidden_in_nebula)
			continue
		if(mark_vessel_identified(other))
			found++
	// As with static scans, an empty sweep costs nothing and can be retried.
	if(found > 0)
		COOLDOWN_START(src, sensor_scan_cooldown, SENSOR_SCAN_COOLDOWN)
	return found

/**
 * Adds a static object to the waypoint list, keyed by its ref so a re-scan
 * updates in place instead of stacking. Ruins resolve to their true name when
 * the radar can identify them. Returns TRUE only if the waypoint is new.
 */
/obj/structure/overmap/ship/proc/chart_as_waypoint(obj/structure/overmap/object)
	var/key = REF(object)
	var/was_charted = !isnull(get_waypoint(key))
	var/list/coords = object.get_relative_overmap_coords()
	if(!coords)
		return FALSE
	// Charted against the object rather than against bare coordinates. Everything
	// scannable is static, so nothing actually moves as a result. It is what lets
	// the readout keep asking the object what it is (terrain, storm family) after
	// the ship has flown out of sight of it.
	add_waypoint(key, get_contact_name(object), coords[1], coords[2], object.sensor_category, object)
	return !was_charted

/**
 * The label a charted contact shows. Identifies ruins by their true name when
 * radar identification is researched; otherwise uses the object's own name.
 */
/obj/structure/overmap/ship/proc/get_contact_name(obj/structure/overmap/object)
	if(istype(object, /obj/structure/overmap/space_ruin) && can_identify_ruins())
		var/obj/structure/overmap/space_ruin/ruin = object
		if(ruin.true_name)
			return ruin.true_name
	return object.name

/**
 * Records everything in the given zone band as discovered. Used by star charts.
 * Returns the count of things this ship did not already know about.
 *
 * The gate is `sensor_visible`, not `sensor_detectable`: a bought survey is not a
 * sensor sweep, and it covers everything that is physically out there, storms and
 * nebulas included, which no scan of ours can reach. What that flag still leaves
 * out is exactly what should be left out: vessels (they move, so a recorded
 * position would be a lie), trader outposts (already broadcast to every helm, and
 * charting one would draw it twice) and empty-space placeholders (not really there).
 *
 * Discoveries land in the charted table rather than the waypoint list, which is
 * where a SIGHTING goes, and buying the survey is meant to be worth the same as
 * having flown the region. It also keeps a region's worth of contacts out of the
 * per-frame payload, prunes itself when a ruin is consumed, and doesn't hand the
 * crew a hundred individual clear buttons for one purchase.
 */
/obj/structure/overmap/ship/proc/chart_zone(zone_type)
	if(!SSovermap_zones?.initialized)
		return 0
	var/turf/low_corner = locate(OVERMAP_LEFT_SIDE_COORD, OVERMAP_SOUTH_SIDE_COORD, OVERMAP_Z_LEVEL)
	var/turf/high_corner = locate(OVERMAP_RIGHT_SIDE_COORD, OVERMAP_NORTH_SIDE_COORD, OVERMAP_Z_LEVEL)
	if(!low_corner || !high_corner)
		return 0
	var/found = 0
	for(var/turf/tile as anything in block(low_corner, high_corner))
		// Resolved once per tile rather than once per object: it is a plain read
		// off the overmap turf, and it lets a tile outside the band cost nothing.
		var/datum/overmap_zone/zone = SSovermap_zones.get_zone(tile)
		if(!zone || zone.zone_type != zone_type)
			continue
		for(var/obj/structure/overmap/candidate in tile)
			if(candidate == src || !candidate.sensor_visible)
				continue
			var/candidate_ref = REF(candidate)
			if(discovered_contacts[candidate_ref])
				continue
			// Nothing without a position on the overmap grid: get_charted_contacts
			// would silently drop it every read anyway.
			if(!candidate.get_relative_overmap_coords())
				continue
			discovered_contacts[candidate_ref] = WEAKREF(candidate)
			found++
	if(found)
		queue_charted_push()
	return found

/**
 * Maps a readout category onto the glyph the helm chart draws for it. Anything
 * unrecognised falls through to a generic marker rather than vanishing.
 */
/proc/contact_kind_for_category(category)
	switch(category)
		if("Outposts", "Trader")
			return "outpost"
		if("Ships")
			return "ship"
		if("Distress")
			return "distress"
		if("Bounties")
			return "bounty"
		if("Planets")
			return "planet"
		if("Ruins")
			return "ruin"
		if("Nebulae")
			return "nebula"
		if("Hazards")
			return "hazard"
		if("Missions")
			return "mission"
		if("Rumors")
			return "rumor"
		if("Events")
			return "event"
	return "marker"

/**
 * The finer glyph key the chart draws this object with, one step below
 * sensor_category: which terrain a planet is, which storm a hazard is, which gas
 * a nebula carries. Null means "nothing to refine" and the category's plain
 * glyph is drawn. See CONTACT_ART in HelmComputer.tsx for the receiving end.
 */
/obj/structure/overmap/proc/get_contact_variant()
	return null

/**
 * How bad this contact is on a 1-3 scale, or 0 where the idea doesn't apply.
 * Only storms use it, and only to size their glyph: a majour asteroid field has
 * to read as worse than a minor one without the navigator stopping to read a name.
 */
/obj/structure/overmap/proc/get_contact_severity()
	return 0

/**
 * One plain line about what this contact will do to a crew that goes there, or
 * null when there is nothing to warn about - which is most contacts.
 *
 * Sensor-grade information, not a mood piece: it rides the contact payload the
 * chart already sends and shows up in the contact row's tooltip, on the card for
 * anything sharing the ship's tile, and in the survey readout. Keep it to a
 * sentence, in the same voice as the planet descriptions.
 */
/obj/structure/overmap/proc/get_hazard_note()
	return null

/**
 * Whether a contact at `coords` is close enough to be seen rather than merely
 * known, the helm draws the difference as solid versus faded. Both arguments
 * are relative overmap coordinates; a null origin reads as "not in sight".
 */
/proc/in_view_ring(list/origin, list/coords)
	if(!origin || !coords)
		return FALSE
	var/dx = coords[1] - origin[1]
	var/dy = coords[2] - origin[2]
	return sqrt(dx * dx + dy * dy) <= SHIP_VIEW_RANGE

/**
 * Every contact the helm draws, the live view ring, permanent fixtures,
 * vessel tracking and charted waypoints, as one list, rebuilt at most once a
 * second and shared by all consoles on the ship.
 *
 * Entries carry coordinates only. Distance and bearing are derived per-read in
 * the helm, so a ship under thrust still shows live figures off a warm snapshot.
 * Anything already reported by the bubble is skipped by the later passes, so a
 * planet you have charted and are currently parked next to is one mark, not two.
 */
/obj/structure/overmap/ship/proc/get_contact_snapshot()
	if(contact_snapshot && (world.time - contact_snapshot_time) < CONTACT_SNAPSHOT_LIFETIME)
		return contact_snapshot

	var/list/contacts = list()
	// REF()s reported by the bubble this rebuild, so the waypoint pass can drop
	// its duplicate of anything we can currently see for ourselves.
	var/list/live_refs = list()

	// The view ring: everything actually out there within sight, charted or not,
	// research or none. This is what stops the chart reading empty while the crew
	// is flying through a nebula bank. You see what is next to the hull.
	var/turf/our_turf = get_turf(src)
	var/list/own_position = get_relative_overmap_coords()
	var/sensor_range = get_sensor_range()
	mark_surveyed(own_position)
	if(our_turf && own_position)
		for(var/obj/structure/overmap/nearby in range(SHIP_VIEW_RANGE, our_turf))
			if(nearby == src || !nearby.sensor_visible)
				continue
			var/list/nearby_coords = nearby.get_relative_overmap_coords()
			if(!nearby_coords)
				continue
			// range() is a square; the helm draws the ring as a circle. Trim the
			// corners so what the crew sees matches the ring on the chart.
			var/view_dx = nearby_coords[1] - own_position[1]
			var/view_dy = nearby_coords[2] - own_position[2]
			if(sqrt(view_dx * view_dx + view_dy * view_dy) > SHIP_VIEW_RANGE)
				continue
			var/nearby_ref = REF(nearby)
			live_refs[nearby_ref] = TRUE
			// Seeing it charts it, for the rest of the round. This is the only
			// place discovery happens, which is why it reads off sensor_visible:
			// that flag already means "physically out there and drawable", so
			// vessels and broadcast fixtures stay out of it for free.
			if(!discovered_contacts[nearby_ref])
				discovered_contacts[nearby_ref] = WEAKREF(nearby)
				queue_charted_push()
			contacts += list(list(
				"name" = get_contact_name(nearby),
				"x" = nearby_coords[1],
				"y" = nearby_coords[2],
				"category" = nearby.sensor_category,
				"kind" = contact_kind_for_category(nearby.sensor_category),
				"variant" = nearby.get_contact_variant(),
				"severity" = nearby.get_contact_severity(),
				"hazard" = nearby.get_hazard_note(),
				"live" = TRUE,
				// No ref: sight owns this entry, so there is nothing to clear.
				"ref" = null,
				// The object itself, for the chart's context menu. Acting on it is
				// gated server-side on sharing our tile, see act_overmap in _helm.dm.
				"target" = REF(nearby),
			))

	// Trader outposts are permanent fixtures, always listed on every ship, with
	// no per-ship state and no clear button.
	for(var/obj/structure/overmap/trader_outpost/outpost as anything in GLOB.trader_outposts)
		if(live_refs[REF(outpost)])
			continue
		var/list/coords = outpost.get_relative_overmap_coords()
		if(!coords)
			continue
		contacts += list(list(
			"name" = "Trader [outpost.shop.trader_name]",
			"x" = coords[1],
			"y" = coords[2],
			"category" = "Outposts",
			"kind" = "outpost",
			"variant" = outpost.get_contact_variant(),
			"live" = in_view_ring(own_position, coords),
			"ref" = null,
			"target" = REF(outpost),
		))

	// Advertising player outposts buy their way onto every helm chart for the
	// advert's duration (see voidcrew/modules/player_outposts/outpost_adverts.dm)
	for(var/datum/outpost_advert/advert as anything in GLOB.outpost_adverts)
		contacts += list(list(
			"name" = advert.outpost_name,
			"x" = advert.coord_x,
			"y" = advert.coord_y,
			"category" = "Outposts",
			"kind" = "outpost",
			// Adverts are a broadcast, not a sighting: the object itself may be
			// nowhere near us, so the colony glyph is taken on the advert's word.
			"variant" = "colony",
			"live" = in_view_ring(own_position, list(advert.coord_x, advert.coord_y)),
			"ref" = null,
		))

	// Vessels. Two axes, and the radar tree moves both:
	//   reach, the view ring for free, the full sensor ring at the top tier.
	//   identity, an anonymous blip until an active scan names it, or always at
	//              the top tier, which is what "tracking" buys over "seeing".
	// Nebula-hidden ships stay concealed from either.
	var/tracking = can_scan_ships()
	var/vessel_reach = tracking ? sensor_range : SHIP_VIEW_RANGE
	// Rebuilt rather than pruned: a vessel that drifts out of contact drops its
	// identification, so it comes back as an unknown rather than a remembered name.
	var/list/still_identified = list()
	// REF()s the vessel pass has already drawn, so the distress pass below can
	// flag those entries in place instead of stacking a second mark on the tile.
	var/list/vessel_refs = list()
	if(own_position)
		for(var/obj/structure/overmap/ship/other as anything in SSovermap.simulated_ships)
			if(other == src || other.hidden_in_nebula)
				continue
			var/list/other_coords = other.get_relative_overmap_coords()
			if(!other_coords)
				continue
			var/dx = other_coords[1] - own_position[1]
			var/dy = other_coords[2] - own_position[2]
			if(sqrt(dx * dx + dy * dy) > vessel_reach)
				continue
			var/ship_ref = REF(other)
			var/scanned = !!identified_ships[ship_ref]
			if(scanned)
				still_identified[ship_ref] = TRUE
			vessel_refs[ship_ref] = TRUE
			var/list/entry = list(
				"x" = other_coords[1],
				"y" = other_coords[2],
				"category" = "Ships",
				"kind" = "ship",
				"live" = TRUE,
				"identified" = scanned || tracking || other.distress_active,
				"ref" = null,
				"target" = ship_ref,
			)
			if(scanned || tracking)
				// hostile only exists on NPC vessels; player ships read as neutral.
				var/is_hostile = FALSE
				if(istype(other, /obj/structure/overmap/ship/npc))
					var/obj/structure/overmap/ship/npc/npc_other = other
					is_hostile = npc_other.hostile
				entry["name"] = other.name
				entry["hostile"] = is_hostile
				entry["integrity"] = other.get_integrity_percent()
			else if(other.distress_active)
				// A lit beacon names its own hull - it is shouting into the galaxy -
				// but it says nothing about intent, so the hostile flag stays behind
				// the same scan every other vessel needs. That gap is the lure.
				entry["name"] = other.display_name || other.name
			else
				// A hull on the scope and nothing else. Withholding the hostile flag
				// is the point: you cannot tell a trader from a pirate until you look.
				entry["name"] = "unknown contact"
			if(other.distress_active)
				entry["sos"] = TRUE
				entry["sosMessage"] = other.distress_message
			contacts += list(entry)
	identified_ships = still_identified

	// Distress beacons, at any range at all. This is the one contact source that
	// ignores both rings and every radar tier: a lit beacon is meant to reach the
	// whole galaxy, which is exactly what makes answering one a decision rather
	// than a formality. Concealment does not stop it either - the beacon repeats
	// the hull's own coordinates on Wideband, so hiding while broadcasting them
	// would be the console arguing with the radio. See ship_distress.dm.
	for(var/obj/structure/overmap/ship/other as anything in SSovermap.simulated_ships)
		if(other == src || !other.distress_active)
			continue
		if(vessel_refs[REF(other)])
			continue
		var/list/distress_coords = other.get_relative_overmap_coords()
		if(!distress_coords)
			continue
		contacts += list(list(
			"name" = other.display_name || other.name,
			"x" = distress_coords[1],
			"y" = distress_coords[2],
			"category" = "Distress",
			"kind" = "distress",
			"live" = in_view_ring(own_position, distress_coords),
			"identified" = TRUE,
			"sos" = TRUE,
			"sosMessage" = other.distress_message,
			"ref" = null,
			"target" = REF(other),
		))

	// Charted waypoints: scan contacts, missions, bounties, revealed rumours.
	// Scan-charted entries key on REF(object), so anything the bubble already
	// reported drops out here rather than drawing a second mark on the same tile.
	for(var/datum/ship_waypoint/waypoint as anything in waypoints)
		if(live_refs[waypoint.source_key])
			continue
		var/list/waypoint_coords = waypoint.get_coords()
		// A charted waypoint keeps a weakref to what it was charted from, so a
		// remembered planet still knows it was a lava planet. A waypoint pushed at
		// bare coordinates (most missions) has nothing to ask and draws plain.
		var/obj/structure/overmap/charted_from = waypoint.tracked_target?.resolve()
		contacts += list(list(
			"name" = waypoint.name,
			"x" = waypoint_coords[1],
			"y" = waypoint_coords[2],
			"category" = waypoint.category,
			"kind" = contact_kind_for_category(waypoint.category),
			"variant" = charted_from?.get_contact_variant(),
			"severity" = charted_from?.get_contact_severity() || 0,
			"hazard" = charted_from?.get_hazard_note(),
			"live" = in_view_ring(own_position, waypoint_coords),
			"ref" = REF(waypoint),
			// The object this was charted from, so the client can drop the
			// static memory entry for the same thing.
			"target" = waypoint.source_key,
		))

	contact_snapshot = contacts
	contact_snapshot_time = world.time
	return contact_snapshot

/**
 * Records the view ring's footprint around `origin` (relative coordinates) as
 * surveyed. Cheap and idempotent: it no-ops unless the ship has actually changed
 * tile since the last stamp.
 */
/obj/structure/overmap/ship/proc/mark_surveyed(list/origin)
	if(!origin)
		return
	if(surveyed_from_x == origin[1] && surveyed_from_y == origin[2])
		return
	surveyed_from_x = origin[1]
	surveyed_from_y = origin[2]
	if(!surveyed_tiles)
		surveyed_tiles = new /list(OVERMAP_SIZE * OVERMAP_SIZE)
	for(var/offset_x in -SHIP_VIEW_RANGE to SHIP_VIEW_RANGE)
		for(var/offset_y in -SHIP_VIEW_RANGE to SHIP_VIEW_RANGE)
			// Same circular trim the view-ring pass uses, so "surveyed" means
			// exactly the area the crew was actually shown.
			if(offset_x * offset_x + offset_y * offset_y > SHIP_VIEW_RANGE * SHIP_VIEW_RANGE)
				continue
			var/tile_x = origin[1] + offset_x
			var/tile_y = origin[2] + offset_y
			if(tile_x < 1 || tile_x > OVERMAP_SIZE || tile_y < 1 || tile_y > OVERMAP_SIZE)
				continue
			surveyed_tiles[(tile_y - 1) * OVERMAP_SIZE + tile_x] = TRUE

/// Whether this ship has ever had eyes on the given relative overmap tile.
/obj/structure/overmap/ship/proc/is_tile_surveyed(tile_x, tile_y)
	if(!surveyed_tiles)
		return FALSE
	if(tile_x < 1 || tile_x > OVERMAP_SIZE || tile_y < 1 || tile_y > OVERMAP_SIZE)
		return FALSE
	return !!surveyed_tiles[(tile_y - 1) * OVERMAP_SIZE + tile_x]

/**
 * Everything this ship has ever seen, as the helm's STATIC contact table.
 *
 * This set only changes when the ship discovers something new, so it rides
 * `ui_static_data` and is pushed on discovery rather than re-sent with every
 * frame. That matters because it is by far the largest thing the helm sends,
 * up to a couple of hundred entries once a ship has explored, against a live set
 * that is usually a handful.
 *
 * The entries carry no distance or bearing, which is what made this possible:
 * those are derived from the ship's own position and so changed every tile,
 * making an otherwise static table look dynamic. The helm computes them
 * client-side from coordinates it already has.
 *
 * Nothing here is de-duplicated against the live set, static data cannot know
 * what is in sight this second. The client drops any charted entry whose `target`
 * is already on the live list.
 */
/obj/structure/overmap/ship/proc/get_charted_contacts()
	var/list/charted = list()
	// Collected rather than removed inline: dropping keys from a list part-way
	// through iterating it is undefined behaviour in DM.
	var/list/forgotten = null
	for(var/contact_ref in discovered_contacts)
		var/datum/weakref/remembered = discovered_contacts[contact_ref]
		var/obj/structure/overmap/object = remembered?.resolve()
		if(!object)
			// Gone for good: a ruin consumed, an event cleaned up.
			LAZYADD(forgotten, contact_ref)
			continue
		var/list/remembered_coords = object.get_relative_overmap_coords()
		if(!remembered_coords)
			continue
		charted += list(list(
			"name" = get_contact_name(object),
			"x" = remembered_coords[1],
			"y" = remembered_coords[2],
			"category" = object.sensor_category,
			"kind" = contact_kind_for_category(object.sensor_category),
			"variant" = object.get_contact_variant(),
			"severity" = object.get_contact_severity(),
			"hazard" = object.get_hazard_note(),
			"target" = contact_ref,
		))
	if(forgotten)
		discovered_contacts -= forgotten
	return charted

/**
 * Queues a static-data refresh for every helm on this ship, coalescing a burst of
 * discoveries into one push.
 *
 * Deferred rather than immediate because discovery happens inside
 * get_contact_snapshot(), which itself runs from ui_data(), refreshing static
 * data from there would re-enter the UI update that is currently running.
 */
/obj/structure/overmap/ship/proc/queue_charted_push()
	if(charted_push_queued)
		return
	charted_push_queued = TRUE
	addtimer(CALLBACK(src, PROC_REF(push_charted_static)), CHARTED_PUSH_COALESCE)

/obj/structure/overmap/ship/proc/push_charted_static()
	charted_push_queued = FALSE
	for(var/obj/machinery/computer/helm/console as anything in helm_consoles)
		console.update_static_data_for_all_viewers()

#undef SENSOR_RANGE_BASE
#undef SENSOR_RANGE_ADVANCED
#undef SENSOR_RANGE_SUPERIOR
#undef SENSOR_RANGE_ELITE
#undef SENSOR_SCAN_COOLDOWN
#undef CONTACT_SNAPSHOT_LIFETIME
#undef CHARTED_PUSH_COALESCE
