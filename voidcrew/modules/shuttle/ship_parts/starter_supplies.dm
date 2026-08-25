/**
 * # Ship starter supplies
 *
 * Runtime guarantee that no player ship launches without the basics needed to
 * survive its first emergency. Playtest rounds 2/4/6 (BAL-6): oxygen loss was
 * the single most common cause of death, and the Goon carries no oxygen tanks,
 * internals crates, emergency closets or gas canisters anywhere on its hull or
 * in any of its modules; its infirmary also maps a partial surgery set with no
 * saw or drill.
 *
 * This lives in code rather than in every hull .dmm on purpose: the modular
 * fleet rolls hull + theme + modules at random, so a map-side guarantee has to
 * be re-proven for every new hull, theme and module combination (and every
 * hull edit forces a ~13 minute purchase-preview regeneration). A load-time
 * audit instead inspects what actually loaded and only fills genuine gaps -
 * hulls that already stock breathing gear or a full surgical set get nothing.
 *
 * Called from SSshuttle.create_ship(), which is the single path every player
 * ship takes: the roundstart fleet, shop purchases, free requisitioned hulls
 * and admin spawns. NPC ships (spawner_subsystem) are deliberately untouched.
 */

/// Spare breathing gear guaranteed aboard any ship that loads with none.
/obj/structure/closet/crate/internals/ship_reserve
	name = "emergency internals crate"
	desc = "Spare breathing gear for hull breaches: oxygen tanks and masks."

/obj/structure/closet/crate/internals/ship_reserve/PopulateContents()
	. = ..()
	// Invented, unplaytested baseline: enough for a small crew to survive a
	// breach and refill from a canister, not enough to live off forever.
	for(var/i in 1 to 3)
		new /obj/item/tank/internals/oxygen(src)
		new /obj/item/clothing/mask/breath(src)
	new /obj/item/tank/internals/emergency_oxygen/engi(src)
	new /obj/item/tank/internals/emergency_oxygen/engi(src)

/**
 * Audits a freshly loaded ship and fills the survival gaps.
 *
 * Guarantees, in order:
 * * An oxygen supply: if nothing aboard provides breathing gear (no emergency
 *   closet, internals crate, survival box or loose oxygen tank), a stocked
 *   internals crate is spawned, plus an oxygen canister to refill from -
 *   printed tanks and drained rooms are both dead ends without a gas source.
 * * A surgical kit: if the ship has an operating table or stasis bed but not a
 *   full basic toolset (scalpel + saw + drill, or a surgical duffel), a
 *   surgical duffel bag is placed on it. Half a toolset is the observed
 *   failure: the Goon infirmary maps scalpel/hemostat/retractor/cautery and
 *   nothing that can cut bone.
 *
 * Container contents are invisible to this scan (closets populate lazily on
 * first open), so coverage is judged by container types and loose items - all
 * of which are exactly what hull maps place.
 */
/obj/docking_port/mobile/voidcrew/proc/ensure_starter_supplies()
	var/has_oxygen_supply = FALSE
	var/has_gas_source = FALSE
	var/has_scalpel = FALSE
	var/has_saw = FALSE
	var/has_drill = FALSE
	var/has_surgery_duffel = FALSE
	var/atom/surgery_site
	var/list/turf/floor_tiles = list()

	for(var/turf/tile as anything in return_ordered_turfs(x, y, z, dir))
		if(isnull(tile) || !shuttle_areas[tile.loc])
			continue
		var/tile_open = isopenturf(tile) && !tile.density
		for(var/atom/movable/thing as anything in tile.contents)
			if(thing.density && !ismob(thing))
				tile_open = FALSE
			if(istype(thing, /obj/structure/closet/emcloset) \
				|| istype(thing, /obj/structure/closet/crate/internals) \
				|| istype(thing, /obj/item/storage/box/survival) \
				|| istype(thing, /obj/item/tank/internals/oxygen))
				has_oxygen_supply = TRUE
			else if(istype(thing, /obj/machinery/portable_atmospherics/canister/oxygen) \
				|| istype(thing, /obj/machinery/portable_atmospherics/canister/air))
				has_gas_source = TRUE
			else if(istype(thing, /obj/structure/table/optable))
				surgery_site = thing
			else if(istype(thing, /obj/machinery/stasis) && !surgery_site)
				surgery_site = thing
			else if(istype(thing, /obj/item/scalpel))
				has_scalpel = TRUE
			else if(istype(thing, /obj/item/circular_saw))
				has_saw = TRUE
			else if(istype(thing, /obj/item/surgicaldrill))
				has_drill = TRUE
			else if(istype(thing, /obj/item/storage/backpack/duffelbag/sec/surgery) \
				|| istype(thing, /obj/item/storage/backpack/duffelbag/syndie/surgery))
				has_surgery_duffel = TRUE
		if(tile_open)
			floor_tiles += tile

	if(!has_oxygen_supply)
		var/turf/crate_turf = pick_supply_drop_turf(floor_tiles)
		if(crate_turf)
			new /obj/structure/closet/crate/internals/ship_reserve(crate_turf)
			log_shuttle("[name]: loaded with no oxygen supply, spawned reserve internals crate at [COORD(crate_turf)]")
			if(!has_gas_source)
				var/turf/canister_turf = pick_supply_drop_turf(floor_tiles - crate_turf) || crate_turf
				new /obj/machinery/portable_atmospherics/canister/oxygen(canister_turf)
				log_shuttle("[name]: loaded with no gas source, spawned oxygen canister at [COORD(canister_turf)]")

	if(surgery_site && !has_surgery_duffel && !(has_scalpel && has_saw && has_drill))
		new /obj/item/storage/backpack/duffelbag/sec/surgery(get_turf(surgery_site))
		log_shuttle("[name]: loaded without a full surgical toolset, spawned surgical duffel on [surgery_site]")

/**
 * Picks a turf to drop guaranteed supplies on.
 *
 * Prefers open floor near the ship's cryopods (crew spawn there, so the gear
 * is found), and only tiles with at least three passable cardinal neighbours,
 * so a dense crate can never seal a one-wide corridor or a cryopod approach.
 * Falls back through progressively looser standards - tiny gag hulls have no
 * tile with three open sides - and in the worst case uses the docking port's
 * own tile, which hull conformance tests require to be real deck.
 */
/obj/docking_port/mobile/voidcrew/proc/pick_supply_drop_turf(list/turf/floor_tiles)
	var/list/spawn_areas = list()
	for(var/obj/machinery/cryopod/pod as anything in spawn_points)
		spawn_areas[get_area(pod)] = TRUE

	var/list/turf/preferred = list()
	var/list/turf/acceptable = list()
	var/list/turf/cramped = list()
	for(var/turf/tile as anything in floor_tiles)
		var/open_neighbors = 0
		for(var/cardinal in GLOB.cardinals)
			var/turf/adjacent = get_step(tile, cardinal)
			if(isnull(adjacent) || !shuttle_areas[adjacent.loc] || !isopenturf(adjacent) || adjacent.density)
				continue
			var/blocked = FALSE
			for(var/atom/movable/thing as anything in adjacent.contents)
				if(thing.density && !ismob(thing))
					blocked = TRUE
					break
			if(!blocked)
				open_neighbors++
		if(open_neighbors >= 3)
			if(spawn_areas[tile.loc])
				preferred += tile
			else
				acceptable += tile
		else if(open_neighbors >= 2)
			cramped += tile

	if(length(preferred))
		return pick(preferred)
	if(length(acceptable))
		return pick(acceptable)
	if(length(cramped))
		return pick(cramped)
	if(length(floor_tiles))
		return pick(floor_tiles)
	return get_turf(src)
