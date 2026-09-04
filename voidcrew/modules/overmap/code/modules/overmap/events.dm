/obj/structure/overmap/event
	name = "generic overmap event"
	// Hazards show on the helm chart whenever they are inside the sensor bubble,
	// but sensor_detectable stays FALSE: no scan of ours can pin a storm, so one
	// you have flown clear of is lost until you go looking again, or until you
	// buy the region's star chart, which records them the same as anything else.
	sensor_category = "Hazards"

	/// Chance, per neighbouring tile, that a cluster of this event grows onto it.
	/// Decays with every step out from the seed - see SSovermap.grow_event_cluster()
	var/spread_chance = 0
	/// Most tiles one cluster of this event may cover, the seed tile included. Storms are
	/// kept small enough to fly around; a nebula is the one thing allowed to be a bank.
	var/max_cluster_size = 1
	/// Which storm the helm chart draws for this event. Each family gets its own
	/// silhouette, a rock field and an ion front are steered around differently,
	/// so they must not share a glyph.
	var/chart_variant = null
	/// 1 minor / 2 moderate / 3 majour. Sizes the glyph, nothing else.
	var/chart_severity = 2

/obj/structure/overmap/event/get_contact_variant()
	return chart_variant

/obj/structure/overmap/event/get_contact_severity()
	return chart_severity

/// Every meteor storm event on the overmap, loaded or not, zone resolution traces
/// field-interior turfs back to their event through this (see zone_controller.dm)
GLOBAL_LIST_EMPTY(meteor_fields)

/obj/structure/overmap/event/meteor
	name = "asteroid storm (moderate)"
	icon_state = "meteor1"
	spread_chance = 50
	max_cluster_size = 5
	chart_variant = "rock"
	parallax_theme = PARALLAX_THEME_ASTEROIDS // crews over/inside the field see drifting asteroids
	survey_value = 100
	/// Notable minerals shown on the survey report. Keep in sync with ore_weights
	var/mineral_types = list(/datum/material/iron, /datum/material/plasma, /datum/material/silver, /datum/material/titanium, /datum/material/gold)

	/// Map generator used to carve this severity's landable rock field (see AsteroidCaves.dm)
	var/datum/map_generator/cave_generator/asteroid_field/mapgen_type = /datum/map_generator/cave_generator/asteroid_field
	/// Weighted ore table seeded into this severity's rock (seed_asteroid_ore_block);
	/// higher severities carry rarer minerals. Braving the worse storm pays better
	var/list/ore_weights = list(
		/obj/item/stack/ore/iron = 40,
		/obj/item/stack/ore/plasma = 20,
		/obj/item/stack/ore/silver = 12,
		/obj/item/stack/ore/titanium = 12,
		/obj/item/stack/ore/gold = 10,
		/obj/item/stack/ore/uranium = 5,
		/obj/item/stack/ore/diamond = 2,
		/obj/item/stack/ore/bluespace_crystal = 1,
	)
	/// Fraction of the field's rock turfs seeded ore-bearing
	var/ore_target_ratio = EVENT_FIELD_ORE_TARGET_RATIO
	/// Chance (0-100) the field hides a zone-scaled expedition cache (zone_loot.dm)
	var/crate_chance = 40
	/// How many roaming zone-scaled mob packs guard the field: list(min, max)
	var/list/mob_pack_count = list(2, 3)
	/// The map zone backing the landable rock field, once loaded
	var/datum/map_zone/mapzone
	/// This field's rectangle inside that zone's level - the slot it was dealt. Every
	/// "is this turf mine?" question is answered from here rather than from the z-level,
	/// which a packed level shares with up to three neighbours. See /datum/map_footprint.
	var/datum/map_footprint/footprint
	/// This field's own /area/centcom/asteroid/voidcrew instance. Minted per load: the type
	/// used to carry UNIQUE_AREA, so every field in the galaxy shared ONE area straddling
	/// all of them, and area-scoped teardown, lighting and ambience conflated the lot.
	var/area/centcom/asteroid/voidcrew/field_area
	/// Primary docking port
	var/obj/docking_port/stationary/reserve_dock
	/// Secondary docking port
	var/obj/docking_port/stationary/reserve_dock_secondary
	/// Whether the field has been loaded
	var/loaded = FALSE
	/// Whether the field is currently loading
	var/loading = FALSE
	/// Track dock usage
	var/first_dock_taken = FALSE
	var/second_dock_taken = FALSE
	/// Which docking port the ship is occupying
	var/dock_index
	/// Bottom-left turf of the field's padded generation footprint (set by load_level, cleared on unload)
	var/turf/field_bottom_left
	/// Whether this field's ore and caches have already been rolled once. The rock
	/// regenerates on every dock (it is the hazard), but the payout does not - without
	/// this, undocking for 20 seconds and re-docking re-rolled a fresh ore-seeded field.
	var/field_mined = FALSE

/obj/structure/overmap/event/meteor/Initialize(mapload)
	. = ..()
	icon_state = "meteor[rand(1, 4)]"
	GLOB.meteor_fields += src

/obj/structure/overmap/event/meteor/Destroy()
	GLOB.meteor_fields -= src
	field_bottom_left = null
	field_area = null
	// The orderly teardown (unload_level -> remove_mapzone) leaves both of these null. What
	// lands here with either still set is a field deleted OUT of that path - an admin Del, a
	// runtime mid-build - and it used to leak a quarter of a z-level nobody could ever be
	// dealt again. The ground is deliberately NOT swept: Destroy() can run mid-build and
	// clear_to_uninitialized_space() yields, so the next tenant's own fill repaints it.
	if(footprint || mapzone)
		var/datum/map_footprint/departing_footprint = footprint
		var/datum/map_zone/departing_zone = mapzone || departing_footprint?.zone
		log_mapping("SSovermap: asteroid field '[name]' was deleted while still holding [departing_footprint ? departing_footprint.describe() : "a map zone with no footprint"] - releasing the slot without a teardown sweep")
		footprint = null
		mapzone = null
		departing_zone?.release_slot(departing_footprint)
	return ..()

/obj/structure/overmap/event/meteor/get_interior_footprint()
	return footprint

/obj/structure/overmap/event/meteor/minor
	name = "asteroid storm (minor)"
	max_cluster_size = 4
	chart_severity = 1
	mapgen_type = /datum/map_generator/cave_generator/asteroid_field/minor
	mineral_types = list(/datum/material/iron, /datum/material/plasma, /datum/material/silver, /datum/material/titanium)
	// Common rock only: no uranium, diamond or bluespace this shallow
	ore_weights = list(
		/obj/item/stack/ore/iron = 50,
		/obj/item/stack/ore/plasma = 22,
		/obj/item/stack/ore/silver = 12,
		/obj/item/stack/ore/titanium = 12,
		/obj/item/stack/ore/gold = 4,
	)
	ore_target_ratio = 0.25
	crate_chance = 20
	mob_pack_count = list(1, 2)

/obj/structure/overmap/event/meteor/majour
	name = "asteroid storm (majour)"
	spread_chance = 25
	max_cluster_size = 7
	chart_severity = 3
	mineral_types = list(/datum/material/gold, /datum/material/uranium, /datum/material/diamond, /datum/material/bluespace)
	mapgen_type = /datum/map_generator/cave_generator/asteroid_field/majour
	// The deep-storm payout: still mostly working rock, but the precious tail
	// is fat enough that a full strip run banks real diamond/bluespace
	ore_weights = list(
		/obj/item/stack/ore/iron = 18,
		/obj/item/stack/ore/plasma = 14,
		/obj/item/stack/ore/silver = 12,
		/obj/item/stack/ore/titanium = 12,
		/obj/item/stack/ore/gold = 16,
		/obj/item/stack/ore/uranium = 14,
		/obj/item/stack/ore/diamond = 9,
		/obj/item/stack/ore/bluespace_crystal = 5,
	)
	ore_target_ratio = 0.4
	crate_chance = 65
	mob_pack_count = list(3, 4)

/**
 * === Landable asteroid fields (meteor storm hazard) ===
 *
 * Flying through a meteor storm already damages the ship (see ship_damage.dm
 * apply_meteor_damage()). This lets a ship dock INSIDE the storm's own hazard
 * tile and mine the rock that's causing the damage - braving live meteor traffic
 * is the toll for a denser payout than sitting at an undefended signal.
 *
 * Mirrors /obj/structure/overmap/space_ruin's map-slot docking pattern
 * (see space_ruin.dm) but the interior is generated procedurally by a proper
 * /datum/map_generator (AsteroidCaves.dm's asteroid_field generator - the same
 * cellular-automata rock/sand technique roundstart planets use) instead of a
 * static ruin template: one or more scattered rock blobs with real vacuum
 * between and around them, matching the upstream asteroid1-6.dmm palette
 * (regolith floor + mineral rock) without loading a fixed layout.
 */

/**
 * Loads (or reuses) the field's map slot: carves the procedural rock
 * field, seeds ore, and stands up docking ports on opposite sides - the same
 * recipe as /obj/structure/overmap/space_ruin/load_level(), minus the static template.
 *
 * Runs under the worldgen queue like every other survey. Sends
 * COMSIG_VOIDCREW_SITE_LOAD_FINISHED (TRUE/FALSE) on every exit except the in-flight
 * guard (that load owns the signal) - a ship may already be registered for it by
 * request_site_load() when this is entered, and a silent exit latches that ship out
 * of this site for the rest of the round. queue_timeout follows load_level's usual
 * contract: null takes the default, UI callers pass WORLDGEN_QUEUE_NO_WAIT.
 */
/obj/structure/overmap/event/meteor/proc/load_level(mob/user, obj/structure/overmap/ship/waiting_ship, queue_timeout)
	if(mapzone)
		SEND_SIGNAL(src, COMSIG_VOIDCREW_SITE_LOAD_FINISHED, is_loaded())
		return
	if(loading)
		return // the in-flight load sends the completion signal
	loading = TRUE

	var/datum/worldgen_probe/probe = worldgen_begin("asteroid", "[name]")

	// Carving the field is planet-build-scale work - take the worldgen queue.
	if(!SSovermap.worldgen_claim(src, "asteroid field survey ([name])", user, queue_timeout, waiting_ship))
		loading = FALSE
		worldgen_end(probe, "queue-timeout")
		SEND_SIGNAL(src, COMSIG_VOIDCREW_SITE_LOAD_FINISHED, FALSE)
		return

	// The world moved while we queued: another caller may have loaded us already.
	if(mapzone)
		SSovermap.worldgen_release(src)
		loading = FALSE
		worldgen_end(probe, "already-loaded")
		SEND_SIGNAL(src, COMSIG_VOIDCREW_SITE_LOAD_FINISHED, TRUE)
		return

	// A lattice slot, not a turf reservation. A reservation big enough for a 48x48 field
	// plus a max-size berth on all four sides is 166x134, which is more than half the
	// 222x222 a reservation z-level can ever hand out - so every landable field minted a
	// permanent 255x255 z-level of its own, ~49 MB apiece, for a site smaller than a
	// shuttle. The slot lattice puts the two berths side by side along one edge instead
	// and packs four sites to a level. throttled = TRUE: we already hold the worldgen
	// queue, so the build shares the budget we took rather than running full speed on
	// top of it (see worldgen_yield()).
	var/list/encounter_values = SSovermap.spawn_dynamic_encounter(null, FALSE, throttled = TRUE, tenant_class = MAP_TENANT_CLASS_FLAT, tenant_owner = src)
	if(length(encounter_values) < 4 || !encounter_values[1] || !encounter_values[2] || !encounter_values[4])
		// Queue released FIRST, then the retry armed: the wait is for a free SLOT, not for
		// the worldgen queue, and a field must never end up queued behind a planet build.
		SSovermap.worldgen_release(src)
		loading = FALSE
		worldgen_end(probe, "slot-failed")
		site_load_refused_for_capacity(waiting_ship)
		SEND_SIGNAL(src, COMSIG_VOIDCREW_SITE_LOAD_FINISHED, FALSE)
		return
	mapzone = encounter_values[1]
	reserve_dock = encounter_values[2]
	reserve_dock_secondary = encounter_values[3]
	footprint = encounter_values[4]

	// The slot minus its two berths and their clearance collar - the same region a ruin
	// template is stamped into, and computed from the berth geometry rather than restated,
	// so a berth that moves takes the field's edge with it.
	var/list/region = SSovermap.slot_build_region(footprint)
	field_bottom_left = locate(region[1], region[2], footprint.z_value)
	var/turf/field_top_right = locate(region[3], region[4], footprint.z_value)
	if(!field_bottom_left || !field_top_right)
		log_mapping("SSovermap: asteroid field '[name]' could not resolve its terrain region inside [footprint.describe()] - load aborted")
		remove_docks()
		remove_mapzone()
		SSovermap.worldgen_release(src)
		loading = FALSE
		worldgen_end(probe, "region-failed")
		SEND_SIGNAL(src, COMSIG_VOIDCREW_SITE_LOAD_FINISHED, FALSE)
		return

	// No per-turf berth filtering any more: the region above already excludes the berth
	// band and its collar, so every turf in it is a legal candidate.
	var/list/field_candidates = block(field_bottom_left, field_top_right)

	// Carve the rock field via the map generator framework (same architecture as
	// planets - see AsteroidCaves.dm) then top up ore the same way asteroid space
	// ruin signals used to, before that category was retired in favor of this field.
	//
	// The area is OURS, minted per load. /area/centcom/asteroid/voidcrew used to be
	// UNIQUE_AREA, so every field alive at once shared one instance spanning all of them -
	// which teardown, lighting, ambience and power all read as a single place.
	field_area = new /area/centcom/asteroid/voidcrew
	var/datum/map_generator/cave_generator/asteroid_field/mapgen = new mapgen_type()
	var/list/field_turfs = mapgen.generate_terrain(field_candidates, field_area)
	if(length(field_turfs))
		mapgen.populate_terrain(field_turfs, field_area)
		// One payout per field per round: the rock (and the meteor hazard) come back on
		// every dock, but the ore roll and the cache extras only happen the first time.
		if(!field_mined)
			field_mined = TRUE
			seed_asteroid_ore_block(field_bottom_left, field_top_right, ore_target_ratio, "hazard field '[name]'", ore_weights)
			populate_field_extras(field_turfs)
	else
		// Nothing was carved, so nothing ever entered our area instance - and
		// reap_emptied_areas() only collects areas a teardown takes turfs AWAY from, so an
		// empty shell would sit there for the rest of the round.
		QDEL_NULL(field_area)

	// spawn_dynamic_encounter() already initialized the slot's space before we carved into
	// it, but the generator hands back rock and regolith on some of those turfs and leaves
	// the rest alone - sweep once more so nothing it touched is left uninitialized.
	footprint.level?.initialize_space_turfs(footprint)

	worldgen_end(probe)
	loaded = TRUE
	loading = FALSE
	SSovermap.worldgen_release(src)

	SEND_SIGNAL(src, COMSIG_VOIDCREW_PLANET_LOADED, TRUE)
	SEND_SIGNAL(src, COMSIG_VOIDCREW_SITE_LOAD_FINISHED, TRUE)

/obj/structure/overmap/event/meteor/start_level_load(mob/user, obj/structure/overmap/ship/waiting_ship)
	INVOKE_ASYNC(src, PROC_REF(load_level), user, waiting_ship)

/obj/structure/overmap/event/meteor/is_loading()
	return loading

/obj/structure/overmap/event/meteor/is_loaded()
	// All three, not just the flag: ship_act()'s dock path needs the slot and a berth to
	// exist, and request_site_load()'s fast path re-invokes ship_act off this answer -
	// answering "loaded" while the slot is gone would bounce the two procs off each other
	// in an unbroken INVOKE_ASYNC loop.
	return loaded && mapzone && reserve_dock

/// A wedged load or teardown leaves these flags latched (the watchdog force-released
/// the queue, but nothing else ever resets them), and ships may be registered for a
/// completion signal the dead job will now never send - so send the failure here, or
/// the site reads "survey underway" and holds its waiters for the rest of the round.
/obj/structure/overmap/event/meteor/on_worldgen_timeout()
	loading = FALSE
	concerned = FALSE
	SEND_SIGNAL(src, COMSIG_VOIDCREW_SITE_LOAD_FINISHED, FALSE)

/obj/structure/overmap/event/meteor/attack_ghost(mob/user)
	if(reserve_dock)
		user.forceMove(get_turf(reserve_dock))
		return TRUE
	else if(footprint)
		// The footprint's centre, not the level's: locate(world.maxx/2, world.maxy/2, z)
		// lands in the cordon gutter on a packed level.
		var/turf/center = footprint.get_center_turf()
		if(!center)
			return
		user.forceMove(center)
		return TRUE
	return

/**
 * Handles ship interaction with this field - mirrors /obj/structure/overmap/space_ruin/ship_act()
 */
/obj/structure/overmap/event/meteor/get_dock_description()
	return "[name] (mining anchorage)"

/obj/structure/overmap/event/meteor/ship_act(mob/user, obj/structure/overmap/ship/acting, obj/structure/overmap/ship/optional_partner)
	// dock() refuses interdicted ships only after the dock slot below is claimed -
	// refuse up front instead
	if(acting.is_interdicted)
		if(user)
			to_chat(user, span_warning("Cannot dock while interdicted!"))
		else
			acting.ship_notify("Cannot dock while interdicted!", "DOCKING", SHIP_NOTIFY_WARNING, 'voidcrew/sound/warn.ogg', 25)
		return
	if(concerned)
		if(user)
			to_chat(user, span_notice("Too much traffic, try again later!"))
		else
			acting.ship_notify("Approach on [name] aborted: too much traffic, try again later!", "DOCKING", SHIP_NOTIFY_WARNING, 'voidcrew/sound/warn.ogg', 25)
		return

	// Field not generated yet (or torn back down): request it in the background and
	// return the helm immediately. The ship stays fully controllable; request_site_load()
	// broadcasts the survey's progress and resumes this approach itself when the field
	// charts. Gated on the same is_loaded() the resume path re-checks, so the two can
	// never disagree about whether this field is dockable.
	if(!is_loaded())
		acting.request_site_load(src, user)
		return

	concerned = TRUE
	if(user)
		balloon_alert(user, "starting docking process..")

	var/is_survey = FALSE
	var/obj/docking_port/stationary/dock_to_use = null
	var/selected_dock_index = 0

	// Berths do not stay where they were built - see reset_free_reserve_docks_for(). Put the free
	// ones back before choosing one, or the last visitor's offset is carried into this placement
	// and compounds on every arrival.
	reset_free_reserve_docks_for(reserve_dock, reserve_dock_secondary, first_dock_taken, second_dock_taken)

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
		concerned = FALSE
		if(user)
			to_chat(user, span_notice("All potential docking locations occupied."))
		else
			acting.ship_notify("All potential docking locations at [name] are occupied.", "DOCKING", SHIP_NOTIFY_WARNING, 'voidcrew/sound/warn.ogg', 25)
		return

	// Adjust dock and check if shuttle can fit BEFORE committing to docking
	if(!is_survey)
		adjust_dock_to_shuttle(dock_to_use, acting.shuttle)

	// Check if shuttle can actually fit in the dock
	if(acting.shuttle.height > dock_to_use.height || acting.shuttle.width > dock_to_use.width)
		concerned = FALSE
		if(user)
			to_chat(user, span_warning("Ship is too large to dock at this location."))
		else
			acting.ship_notify("Ship is too large to dock at [name].", "DOCKING", SHIP_NOTIFY_WARNING, 'voidcrew/sound/warn.ogg', 25)
		return

	// Now that we know docking will work, set the flags
	if(selected_dock_index == 1)
		first_dock_taken = TRUE
		acting.dock_index = 1
	else if(selected_dock_index == 2)
		second_dock_taken = TRUE
		acting.dock_index = 2

	// dock() only returns a string when it refuses; a successful start is announced
	// to the whole crew by ship_notify()
	var/dock_result = acting.dock(src, dock_to_use)
	if(dock_result)
		if(user)
			to_chat(user, span_notice("[dock_result]"))
		else
			acting.ship_notify("[dock_result]", "DOCKING", SHIP_NOTIFY_WARNING, 'voidcrew/sound/warn.ogg', 25)

	concerned = FALSE

	if(optional_partner)
		ship_act(user, optional_partner)

/**
 * Adjusts dock position for the shuttle (shared helper; see _HELPERS/docking.dm)
 */
/obj/structure/overmap/event/meteor/proc/adjust_dock_to_shuttle(obj/docking_port/stationary/dock_to_adjust, obj/docking_port/mobile/shuttle)
	adjust_reserve_dock_to_shuttle(dock_to_adjust, shuttle)

/**
 * Danger-scaled extras over the freshly carved rock: maybe a zone-tiered
 * expedition cache (with a mob pack standing guard) plus roaming zone-scaled
 * packs (zone_mobs.dm). Severity controls how MANY packs and whether a cache
 * drops at all; the overmap zone controls how nasty each pack rolls and what
 * the cache holds, resolution works because get_overmap_object_for_turf()
 * traces the field's footprint back to this event's overmap tile.
 */
/obj/structure/overmap/event/meteor/proc/populate_field_extras(list/field_turfs)
	var/list/open_turfs = list()
	for(var/turf/tile as anything in field_turfs)
		if(!isopenturf(tile) || tile.is_blocked_turf(exclude_mobs = TRUE))
			continue
		open_turfs += tile
	if(!length(open_turfs))
		return

	// The prize: a zone-scaled cache, never left unguarded. A field deep in
	// the red pays more and reaches higher out of the same table, that is
	// the whole of the scaling, so there is no separate rare crate to roll.
	if(prob(crate_chance))
		var/turf/crate_turf = pick_n_take(open_turfs)
		new /obj/structure/closet/crate/zone_loot/expedition(crate_turf)
		new /obj/effect/zone_mobs/asteroid(crate_turf)

	// Roaming packs scattered across the blobs
	for(var/_ in 1 to rand(mob_pack_count[1], mob_pack_count[2]))
		if(!length(open_turfs))
			break
		new /obj/effect/zone_mobs/asteroid(pick_n_take(open_turfs))

/**
 * Releases the field's map slot and docks when nobody's using it. Unlike space ruins,
 * the event itself is never deleted or moved - only its (lazily-loaded) interior is freed.
 */
/obj/structure/overmap/event/meteor/proc/can_release_interior()
	if(!mapzone || !footprint)
		return FALSE

	// Never while the interior is still being generated. worldgen_claim() is reentrant
	// by requester, so a teardown fired mid-load would be granted the queue instantly
	// (load and teardown both claim as src) and reset the ground out from under the
	// generator still carving into it.
	if(loading)
		return FALSE

	// A claimed berth means a ship is somewhere between "approach started" and "undock
	// complete" - possibly in hyperspace transit, which the contents and player checks
	// below are both blind to.
	if(first_dock_taken || second_dock_taken)
		return FALSE

	// Check if any ships are still docked
	for(var/obj/structure/overmap/ship/docked_ship in contents)
		return FALSE

	// Check for players within our own slot - a packed level carries up to four tenants,
	// so a level-wide check would false-positive on a neighbour's visitors
	if(turf_footprint_has_players(footprint))
		return FALSE

	// No ship hull may overlap the slot. The field never had this guard, which the space
	// ruin has had since round 803 - the overmap token leaves a full second before the
	// interior physically moves, so both checks above are blind to a hull mid-departure,
	// and the sweep below deletes every atom on the ground. That is how a departing ship
	// loses its thrusters. See footprint_blocking_hull_reason().
	var/blocking_reason = footprint_blocking_hull_reason(footprint)
	if(blocking_reason)
		log_mapping("SSovermap: asteroid field '[name]' teardown refused - [blocking_reason]")
		return FALSE

	return TRUE

/obj/structure/overmap/event/meteor/proc/unload_level()
	if(concerned)
		return

	if(!can_release_interior())
		// Already released - can_release_interior() refuses on a null map zone too,
		// and there is nothing left to come back for. Terminal, or the retry below
		// becomes a permanent heartbeat on every field that ever unloaded.
		if(!mapzone)
			return
		// Usually the departing shuttle is still mid-move, or the field is mid-build.
		// "The next undock re-triggers us" is not a retry: our callers are all one-shot
		// undock timers, so a field that was busy at this instant kept its slot,
		// both berths and every mob spawner until roundend. Same 30s re-arm the queue
		// timeout below uses - TIMER_UNIQUE, and the same callback, so they can't stack.
		addtimer(CALLBACK(src, PROC_REF(unload_level)), 30 SECONDS, TIMER_UNIQUE)
		return

	// Freeing the field's slot is survey-scale teardown work - queue it like
	// every other job rather than stacking it on top of a build in progress.
	//
	// `concerned` is only raised once the claim is granted: the wait can run for
	// minutes, and holding the flag through it would refuse every arriving ship for
	// a teardown that may yet stand down. An arrival mid-wait claims a berth, which
	// the re-check below reads as "occupied" and aborts on.
	//
	// A queue timeout must re-arm itself: our only callers are one-shot undock timers,
	// so giving up silently would leave the slot, both berths and every mob
	// spawner resident until roundend.
	if(!SSovermap.worldgen_claim(src, "asteroid field teardown ([name])"))
		addtimer(CALLBACK(src, PROC_REF(unload_level)), 30 SECONDS, TIMER_UNIQUE)
		return

	concerned = TRUE

	// Re-checked once the queue is held: the wait can run for minutes, and someone
	// docking back in mid-wait must stop the teardown.
	if(!can_release_interior())
		SSovermap.worldgen_release(src)
		concerned = FALSE
		// Same reason as the refusal at the top: the timer that got us here is spent.
		if(mapzone)
			addtimer(CALLBACK(src, PROC_REF(unload_level)), 30 SECONDS, TIMER_UNIQUE)
		return

	// Flag down before the sweep, not after (and before anything below can yield):
	// is_loaded() must read FALSE the moment the ground stops being safe to dock into,
	// or an arriving ship's fast path resumes an approach into turfs that are
	// mid-recycle.
	loaded = FALSE
	remove_docks()
	remove_mapzone()
	SSovermap.worldgen_release(src)
	concerned = FALSE

/obj/structure/overmap/event/meteor/proc/remove_docks()
	if(reserve_dock)
		qdel(reserve_dock, TRUE)
		reserve_dock = null
	if(reserve_dock_secondary)
		qdel(reserve_dock_secondary, TRUE)
		reserve_dock_secondary = null

/obj/structure/overmap/event/meteor/proc/remove_mapzone()
	if(mapzone)
		var/datum/map_zone/departing_zone = mapzone
		var/datum/map_footprint/departing_footprint = footprint
		// A carved field brings no template ports of its own, but slots are recycled:
		// anything a previous tenant left standing in ours is ours to clear before the
		// ground goes back in the pool, and neither sweep below will touch a docking
		// port. See reap_footprint_docking_ports().
		reap_footprint_docking_ports(departing_footprint)
		// Per-slot: only our own rectangle goes back to uninitialized space unless we are
		// the last tenant on the level, in which case the whole level (cordon included) is
		// reset so the recycled zone starts clean. The footprint has to still be attached
		// while the sweep runs - it is what names the ground we own.
		departing_zone.clear_to_uninitialized_space(departing_footprint)
		departing_zone.release_slot(departing_footprint)
		mapzone = null
		footprint = null
	// The sweep above reparents our rock to space and reap_emptied_areas() collects the
	// emptied shell, so this is only dropping our reference to it.
	field_area = null
	field_bottom_left = null

/**
 * Seeds ore deposits into a rectangular block of rock turfs, converting barren
 * /turf/closed/mineral rock into ore deposits until target_ratio of the mineral
 * turfs in the block are ore-bearing. Originally shared with space ruin asteroid
 * signals; those were retired in favor of landable fields, so this is now solely
 * the field ore-seeding step, called from load_level() above.
 *
 * source_desc is a human-readable label for the mapping log line only.
 * ore_weights optionally overrides the default weighted ore table, the meteor
 * severity tiers pass their own so worse storms seed richer rock.
 *
 * Mining itself needs no z-level traits: off mining levels, prox_to_vent() returns 0 and
 * the mineral turf machinery falls back to flat random yields, so this works fine inside
 * a map slot on a shared encounter z-level.
 */
/proc/seed_asteroid_ore_block(turf/bottom_left, turf/top_right, target_ratio, source_desc, list/ore_weights)
	if(!bottom_left || !top_right)
		return

	// Default weighted ore table - iron/plasma-heavy like planet rock, no bananium, and
	// no gibtonite (its detonation admin-alerts are tuned for mining levels, and surprise
	// bombs shouldn't be procedurally injected into rock the mapper made inert)
	var/static/list/asteroid_ore_weights = list(
		/obj/item/stack/ore/iron = 40,
		/obj/item/stack/ore/plasma = 20,
		/obj/item/stack/ore/silver = 12,
		/obj/item/stack/ore/titanium = 12,
		/obj/item/stack/ore/gold = 10,
		/obj/item/stack/ore/uranium = 5,
		/obj/item/stack/ore/diamond = 2,
		/obj/item/stack/ore/bluespace_crystal = 1,
	)
	var/list/table = (length(ore_weights)) ? ore_weights : asteroid_ore_weights

	var/mineral_turf_count = 0
	var/ore_bearing_count = 0
	var/list/barren_rock = list()
	for(var/turf/closed/mineral/rock in block(bottom_left, top_right))
		mineral_turf_count++
		// Already has ore, a boulder, or is gibtonite (mineralType-less but very much not barren)
		if(rock.mineralType || rock.spawned_boulder || istype(rock, /turf/closed/mineral/gibtonite))
			ore_bearing_count++
			continue
		barren_rock += rock
		// Scans a whole site block mid-round - yield (see worldgen_yield())
		SSovermap.worldgen_yield()

	var/target = CEILING(mineral_turf_count * target_ratio, 1)
	var/to_seed = target - ore_bearing_count
	var/seeded = 0
	while(to_seed > 0 && length(barren_rock))
		var/turf/closed/mineral/rock = pick_n_take(barren_rock)
		rock.Change_Ore(pick_weight(table))
		rock.mineralAmt = rand(ASTEROID_ORE_AMOUNT_MIN, ASTEROID_ORE_AMOUNT_MAX)
		to_seed--
		seeded++

	if(seeded)
		log_mapping("SPACE RUIN: Seeded [seeded] ore deposits into [source_desc] ([ore_bearing_count]/[mineral_turf_count] rock was already ore-bearing)")

/obj/structure/overmap/event/emp
	name = "ion storm (moderate)"
	icon_state = "ion1"
	spread_chance = 20
	max_cluster_size = 4
	chart_variant = "ion"
	survey_value = 400
	var/intensity = 1

/obj/structure/overmap/event/emp/Initialize(mapload)
	. = ..()
	icon_state = "ion[rand(1, 4)]"

/obj/structure/overmap/event/emp/minor
	name = "ion storm (minor)"
	max_cluster_size = 3
	intensity = 1
	chart_severity = 1

/obj/structure/overmap/event/emp/majour
	name = "ion storm (majour)"
	max_cluster_size = 6
	intensity = 2
	chart_severity = 3

/obj/structure/overmap/event/electric
	name = "electrical storm (moderate)"
	icon_state = "electrical1"
	spread_chance = 30
	max_cluster_size = 4
	chart_variant = "electrical"
	survey_value = 250
	var/intensity = 1

/obj/structure/overmap/event/electric/Initialize(mapload)
	. = ..()
	icon_state = "electrical[rand(1, 4)]"

/obj/structure/overmap/event/electric/minor
	name = "electrical storm (minor)"
	spread_chance = 40
	max_cluster_size = 3
	intensity = 1
	chart_severity = 1

/obj/structure/overmap/event/electric/majour
	name = "electrical storm (majour)"
	spread_chance = 15
	max_cluster_size = 6
	intensity = 2
	chart_severity = 3

/**
 * === Gas-bearing nebulas ===
 *
 * Every nebula carries a harvestable gas: hold still inside one with a nebula
 * ram scoop mounted (see modules/shuttle/engine/gas_harvest.dm) and it feeds
 * the ship's pipenet. Which gas is rolled from the tile's zone band at spawn.
 * The safe outer ring is plasma fuel stops and inert wisps, the deep bands
 * carry tritium and the exotics no cargo console sells. Scooping is loud:
 * it blocks and breaks nebula concealment (see ship.dm notify_scoop_activity()),
 * so the fuel stop is also the ambush spot.
 */

/// Weighted gas tables per zone band. Deeper bands carry rarer gas
GLOBAL_LIST_INIT(nebula_gas_tables_by_band, list(
	"[ZONE_GREEN]" = list(
		/datum/gas/plasma = 55,
		/datum/gas/nitrogen = 30,
		/datum/gas/water_vapor = 15,
	),
	"[ZONE_YELLOW]" = list(
		/datum/gas/plasma = 40,
		/datum/gas/tritium = 30,
		/datum/gas/nitrogen = 15,
		/datum/gas/water_vapor = 10,
		/datum/gas/miasma = 5,
	),
	"[ZONE_RED]" = list(
		/datum/gas/tritium = 30,
		/datum/gas/hypernoblium = 20,
		/datum/gas/pluoxium = 15,
		/datum/gas/nitrium = 15,
		/datum/gas/plasma = 10,
		/datum/gas/miasma = 10,
	),
))

/// Moles per second a rating-1 ram scoop pulls from a nebula of each gas.
/// The precious stuff comes slower on top of already being red-band-only
GLOBAL_LIST_INIT(nebula_gas_scoop_rates, list(
	/datum/gas/plasma = 8,
	/datum/gas/nitrogen = 8,
	/datum/gas/water_vapor = 8,
	/datum/gas/miasma = 8,
	/datum/gas/tritium = 5,
	/datum/gas/hypernoblium = 3,
	/datum/gas/pluoxium = 3,
	/datum/gas/nitrium = 3,
))

/**
 * Nebula gases that dose the crew of a ship sitting in the cloud, and how hard.
 *
 * Tritium is the only one of the eight that is actually radioactive, so it is the only
 * entry - a plasma or nitrogen bank is unpleasant to breathe and nothing more. The number
 * is what a radioactive nebula shielder aboard subtracts from (shielding_strength 4, so one
 * working unit covers any of these); see apply_nebula_radiation() in ship_damage.dm.
 */
GLOBAL_LIST_INIT(nebula_gas_radioactivity, list(
	/datum/gas/tritium = 2,
))

/// All live nebula event tiles (gas-harvest missions poll this for what's scoopable)
GLOBAL_LIST_EMPTY(nebula_events)

/obj/structure/overmap/event/nebula
	name = "nebula"
	icon_state = "nebula"
	// Own group on the helm: nebulas are cover and fuel, not just something to
	// steer around, and the concealment control keys off standing in one.
	sensor_category = "Nebulae"
	// Nebula banks are the biggest hazard on the chart and the reason space read as walled
	// off. 12 tiles is what its spread rate is worth next to the other events; it is dealt 9,
	// a quarter under that, alongside the matching cut to its weight in overmap_event_pick_list
	max_cluster_size = 9
	spread_chance = 75
	opacity = TRUE
	parallax_theme = PARALLAX_THEME_SPACE_GAS // crews inside see space gas, tinted below
	survey_value = 50
	/// The /datum/gas typepath this nebula carries. Null rolls one from the
	/// zone band's table on Init; the fixed subtypes below force a specific gas.
	var/datum/gas/gas_type

/obj/structure/overmap/event/nebula/Initialize(mapload)
	. = ..()
	GLOB.nebula_events += src
	if(!gas_type)
		var/band = SSovermap.get_zone_band_for_turf(get_turf(src))
		var/list/table = GLOB.nebula_gas_tables_by_band["[band]"] || GLOB.nebula_gas_tables_by_band["[ZONE_GREEN]"]
		gas_type = pick_weight(table)
	name = "[LOWER_TEXT(get_gas_name())] nebula"
	color = initial(gas_type.primary_color)

/obj/structure/overmap/event/nebula/Destroy()
	GLOB.nebula_events -= src
	return ..()

/**
 * The chart tints a nebula with the gas it carries, so a crew hunting tritium can
 * pick the right cloud out of a bank without flying into each one. The gas `id`
 * rather than its display name: it is a stable key, and the helm holds the
 * palette (see NEBULA_COLOR in HelmComputer.tsx).
 */
/obj/structure/overmap/event/nebula/get_contact_variant()
	return gas_type ? initial(gas_type.id) : null

/// Nebulas are cover and fuel, not a storm to be graded.
/obj/structure/overmap/event/nebula/get_contact_severity()
	return 0

/// Display name of the carried gas, for survey readouts and examine
/obj/structure/overmap/event/nebula/proc/get_gas_name()
	if(!gas_type)
		return "unknown"
	return initial(gas_type.name)

/// Base harvest rate (mol/s at stock parts) for this nebula's gas
/obj/structure/overmap/event/nebula/proc/get_scoop_rate()
	return GLOB.nebula_gas_scoop_rates[gas_type] || 0

/// Tint the crew's space-gas parallax with the carried gas' color (set in Initialize)
/obj/structure/overmap/event/nebula/configure_parallax_layer(atom/movable/screen/parallax_layer/layer)
	if(color)
		layer.add_atom_colour(color, ADMIN_COLOUR_PRIORITY)

// Fixed-gas variants for admin spawning / mapped encounters, natural spawns
// stay the base type and roll from their zone band's table instead
/obj/structure/overmap/event/nebula/plasma
	gas_type = /datum/gas/plasma
/obj/structure/overmap/event/nebula/nitrogen
	gas_type = /datum/gas/nitrogen
/obj/structure/overmap/event/nebula/water_vapor
	gas_type = /datum/gas/water_vapor
/obj/structure/overmap/event/nebula/miasma
	gas_type = /datum/gas/miasma
/obj/structure/overmap/event/nebula/tritium
	gas_type = /datum/gas/tritium
/obj/structure/overmap/event/nebula/hypernoblium
	gas_type = /datum/gas/hypernoblium
/obj/structure/overmap/event/nebula/pluoxium
	gas_type = /datum/gas/pluoxium
/obj/structure/overmap/event/nebula/nitrium
	gas_type = /datum/gas/nitrium

/obj/structure/overmap/event/nebula/ship_act(mob/user, obj/structure/overmap/ship/acting)
	// If already hidden, unhide
	if(acting.hidden_in_nebula)
		if(acting.unhide_from_nebula())
			return
		to_chat(user, span_warning("Failed to emerge from nebula concealment."))
		return

	// Try to hide
	if(!acting.can_hide_in_nebula())
		if(acting.is_interdicted)
			to_chat(user, span_warning("Cannot hide while interdicted!"))
		else if(acting.is_scoop_hot())
			to_chat(user, span_warning("Cannot hide while the ram scoop is running!"))
		else
			to_chat(user, span_warning("Cannot engage nebula concealment here."))
		return

	if(acting.hide_in_nebula())
		return

	to_chat(user, span_warning("Failed to engage nebula concealment."))

// voidcrew TODO: reimplement wormholes once ships are working again

/// List of event types that MUST spawn at least once - ensures map diversity
GLOBAL_LIST_INIT(overmap_event_guaranteed_list, list(
	/obj/structure/overmap/event/nebula,
	/obj/structure/overmap/event/meteor/minor,
	/obj/structure/overmap/event/meteor,
	/obj/structure/overmap/event/meteor/majour,
	/obj/structure/overmap/event/emp/minor,
	/obj/structure/overmap/event/emp,
	/obj/structure/overmap/event/emp/majour,
	/obj/structure/overmap/event/electric/minor,
	/obj/structure/overmap/event/electric,
	/obj/structure/overmap/event/electric/majour,
))

/// Weighted list for random event selection after guaranteed spawns
GLOBAL_LIST_INIT(overmap_event_pick_list, list(
	// 60 before: a nebula came up more often than anything else AND covered more ground
	// than anything else. Its bank size came down a quarter (max_cluster_size above) and
	// so does this, which puts a nebula on a par with a moderate storm instead of above one.
	/obj/structure/overmap/event/nebula = 45,
	/obj/structure/overmap/event/electric/minor = 45,
	/obj/structure/overmap/event/electric = 40,
	/obj/structure/overmap/event/electric/majour = 35,
	/obj/structure/overmap/event/emp/minor = 45,
	/obj/structure/overmap/event/emp = 40,
	/obj/structure/overmap/event/emp/majour = 45,
	/obj/structure/overmap/event/meteor/minor = 45,
	/obj/structure/overmap/event/meteor = 40,
	/obj/structure/overmap/event/meteor/majour = 35
))
