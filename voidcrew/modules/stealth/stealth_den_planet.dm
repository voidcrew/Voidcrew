/**
 * TEMPORARY PLAYTEST TOOL for the stealth branch (feature/stealth). Remove before merge.
 *
 * "Stealth: Scav Den Planet" (Debug) builds a fresh jungle planet through the normal overmap path and worldgen
 * queue, loads the scav chop shop (scav_den.dm) on it at a cleared spot, then dresses the admin in a mortal body
 * with the stealth playtest kit and drops them in the jungle south of the den's front airlock.
 */

/// Cleared ground around the den, so both airlocks and the arrival spot are open jungle
#define STEALTH_TEST_MARGIN 8
/// No ground fauna may spawn this close to the ruin
#define STEALTH_TEST_FAUNA_CLEARANCE 10
/// The ruin and its cleared margin stay at least this far from the planet's edge
#define STEALTH_TEST_EDGE 5
/// Structure spawners (nests, tendrils) are removed this close to the ruin
#define STEALTH_TEST_SPAWNER_CLEARANCE 20
/// How long the planet may take to come up, queue wait included
#define STEALTH_TEST_PLANET_TIMEOUT (8 MINUTES)
/// How long to wait for the guards to spawn before choosing the arrival spot
#define STEALTH_TEST_GUARD_WAIT (20 SECONDS)
/// The den's outer front airlock in map-local coordinates (1-based, from the bottom left)
#define STEALTH_TEST_DOOR_X 29
#define STEALTH_TEST_DOOR_Y 2

ADMIN_VERB(stealth_den_planet, R_ADMIN|R_DEBUG, "Stealth: Scav Den Planet", "TEMPORARY: build a jungle planet with the scav chop shop and drop you outside it in the stealth playtest kit.", ADMIN_CATEGORY_DEBUG)
	// The planet's overmap zone sets how sharp the guards are (green, yellow or red skill profile).
	var/static/list/zone_choices = list("Green" = ZONE_GREEN, "Yellow" = ZONE_YELLOW, "Red" = ZONE_RED)
	var/zone_name = tgui_input_list(user, "Which zone should the planet be in? Guards are sharper in harder zones.", "Stealth: Scav Den Planet", zone_choices, "Yellow")
	if(isnull(zone_name) || isnull(zone_choices[zone_name]))
		return
	message_admins("[key_name_admin(user)] is building a scav den test planet in the [zone_name] zone.")
	log_admin("[key_name(user)] is building a scav den test planet in the [zone_name] zone.")
	BLACKBOX_LOG_ADMIN_VERB("Stealth Scav Den Planet")
	INVOKE_ASYNC(GLOBAL_PROC, GLOBAL_PROC_REF(stealth_test_planet_for_client), user, zone_choices[zone_name])

/// Builds the site in `zone`, then gives `user` a mortal body there.
/proc/stealth_test_planet_for_client(client/user, zone = ZONE_YELLOW)
	var/turf/arrival = stealth_test_planet_build(user, zone)
	if(isnull(arrival) || QDELETED(user))
		return
	var/mob/living/carbon/human/body = stealth_test_planet_body(user, arrival)
	if(isnull(body))
		to_chat(user, span_warning("Stealth test: could not make you a body."))
		return
	to_chat(user, span_notice("Stealth test: you are on [get_area_name(arrival, TRUE)], in the jungle south of the scav den's front airlock."))
	message_admins("[key_name_admin(user)] arrived at the scav den test planet [ADMIN_VERBOSEJMP(arrival)].")

/**
 * Spawns a jungle planet on the overmap, builds it through load_level() (which queues on the worldgen
 * queue), and loads the scav den on a clear spot. Returns the arrival turf, or null.
 * `feedback` is told how it is going; it may be null (tests).
 */
/proc/stealth_test_planet_build(client/feedback, zone = ZONE_YELLOW)
	var/mob/feedback_mob = feedback?.mob
	var/datum/map_template/ruin/template
	for(var/name in SSmapping.ruins_templates)
		var/datum/map_template/ruin/candidate = SSmapping.ruins_templates[name]
		if(istype(candidate, /datum/map_template/ruin/space/rare/scav_den))
			template = candidate
			break
	if(isnull(template) || !template.width || !template.height)
		stealth_test_say(feedback, "the scav den template is missing.", TRUE)
		return null

	// strict_band: the guards read the zone from the planet's overmap square, so it must really be in that band.
	var/obj/structure/overmap/planet/planet = SSovermap.spawn_dynamic_planet(/obj/structure/overmap/planet/jungle, 1, zone, strict_band = TRUE)
	if(isnull(planet))
		stealth_test_say(feedback, "no free overmap square for a planet in that zone.", TRUE)
		return null
	// Kept until an admin unloads it, so a test run is not torn down while the tester walks around.
	planet.preserve_level = TRUE
	var/started = world.time
	stealth_test_say(feedback, "building [planet.name] at overmap ([planet.x], [planet.y]), [list("green", "yellow", "red")[clamp(SSovermap_zones.get_zone_type_anywhere(get_turf(planet)) || ZONE_GREEN, ZONE_GREEN, ZONE_RED)]] zone. This takes about a minute.")
	INVOKE_ASYNC(planet, TYPE_PROC_REF(/obj/structure/overmap/planet, load_level), feedback_mob, 5 MINUTES)
	var/next_note = world.time + 30 SECONDS
	while(!planet.loaded)
		if(QDELETED(planet) || (!planet.loading && !planet.loaded))
			stealth_test_say(feedback, "the planet failed to build (see the mapping log).", TRUE)
			return null
		if(world.time > started + STEALTH_TEST_PLANET_TIMEOUT)
			stealth_test_say(feedback, "gave up waiting for the planet after [DisplayTimeText(world.time - started)].", TRUE)
			return null
		if(world.time >= next_note)
			next_note = world.time + 30 SECONDS
			stealth_test_say(feedback, "still building ([DisplayTimeText(world.time - started)] so far).")
		sleep(1 SECONDS)
	var/datum/map_footprint/footprint = planet.footprint
	var/z = footprint?.z_value
	if(!z)
		stealth_test_say(feedback, "the planet loaded without a footprint.", TRUE)
		return null
	stealth_test_say(feedback, "planet up in [DisplayTimeText(world.time - started)]. Loading the den.")

	if(!SSovermap.worldgen_claim(planet, "scav den test ([planet.name])", feedback_mob, 2 MINUTES))
		stealth_test_say(feedback, "the worldgen queue stayed busy; the planet is up but the den was not loaded.", TRUE)
		return null
	var/datum/space_level/level = SSmapping.get_level(z)
	var/turf/center = stealth_test_pick_site(planet, level, template)
	if(isnull(center))
		SSovermap.worldgen_release(planet)
		stealth_test_say(feedback, "found no clear spot for the den on the planet.", TRUE)
		return null
	var/area/surface_area = get_area(center)
	var/list/ruin_rect = stealth_test_ruin_rect(center, template)
	stealth_test_clear_site(ruin_rect, z)

	// Loaded straight over the ground, the way try_to_place() loads a ruin once it has picked a spot.
	planet_ruin_area_instancing_begin(z)
	var/loaded = template.load(center, centered = TRUE)
	planet_ruin_area_instancing_end(z)
	if(!loaded)
		SSovermap.worldgen_release(planet)
		stealth_test_say(feedback, "the den failed to load at [center.x],[center.y].", TRUE)
		return null
	template.loaded++
	for(var/turf/ruin_turf as anything in template.get_affected_turfs(center, TRUE))
		ruin_turf.turf_flags |= NO_RUINS
	new /obj/effect/landmark/ruin(center, template)
	planet.generate_ruin_terrain(level)
	planet.light_ruin_terrain(level, surface_area)
	footprint.add_planetary_faction_to_existing_mobs()
	stealth_test_prune_fauna(planet, ruin_rect)
	SSovermap.worldgen_release(planet)

	// The guards come through the human NPC spawn queue a moment after the load.
	var/list/door = stealth_test_door_coords(center, template)
	var/turf/door_turf = locate(door[1], door[2], z)
	var/guard_deadline = world.time + STEALTH_TEST_GUARD_WAIT
	var/list/guards = stealth_test_guards_near(door_turf)
	while(length(guards) < 8 && world.time < guard_deadline)
		sleep(1 SECONDS)
		guards = stealth_test_guards_near(door_turf)

	var/turf/arrival
	for(var/south in list(5, 4, 6, 7))
		for(var/east in list(0, -1, 1, -2, 2))
			var/turf/spot = locate(door[1] + east, door[2] - south, z)
			if(isnull(spot) || spot.is_blocked_turf(exclude_mobs = FALSE) || stealth_test_watched(spot, guards))
				continue
			arrival = spot
			break
		if(arrival)
			break
	if(isnull(arrival))
		arrival = locate(door[1], door[2] - 5, z)
	log_admin("Scav den test planet '[planet.name]' built: den at [center.x],[center.y],[z], [length(guards)] guards, [DisplayTimeText(world.time - started)].")
	return arrival

/proc/stealth_test_say(client/feedback, text, failed = FALSE)
	if(feedback)
		to_chat(feedback, failed ? span_warning("Stealth test: [text]") : span_notice("Stealth test: [text]"))
	if(failed)
		log_admin("Stealth test planet: [text]")

/// list(low_x, low_y, high_x, high_y) of the ruin when loaded centred on `center`
/proc/stealth_test_ruin_rect(turf/center, datum/map_template/template)
	var/low_x = center.x - round(template.width / 2)
	var/low_y = center.y - round(template.height / 2)
	return list(low_x, low_y, low_x + template.width - 1, low_y + template.height - 1)

/// World x,y of the front airlock when the ruin is loaded centred on `center`
/proc/stealth_test_door_coords(turf/center, datum/map_template/template)
	var/list/rect = stealth_test_ruin_rect(center, template)
	return list(rect[1] + STEALTH_TEST_DOOR_X - 1, rect[2] + STEALTH_TEST_DOOR_Y - 1)

/proc/stealth_test_block(list/rect, pad, z)
	return block(rect[1] - pad, rect[2] - pad, z, rect[3] + pad, rect[4] + pad, z)

/**
 * The ruin's centre turf: the middle of the planet, moved up clear of the dock strip if needed, and kept far
 * enough in that the ruin and its cleared margin sit at least STEALTH_TEST_EDGE tiles from the planet's edge.
 * The load overwrites whatever is there.
 */
/proc/stealth_test_pick_site(obj/structure/overmap/planet/planet, datum/space_level/level, datum/map_template/template)
	var/list/bounds = planet.get_terrain_bounds(level)
	if(length(bounds) < 4)
		return null
	var/rect_pad = STEALTH_TEST_MARGIN + STEALTH_TEST_EDGE
	var/half_w = round(template.width / 2)
	var/half_h = round(template.height / 2)
	var/min_x = bounds[1] + rect_pad + half_w
	var/max_x = bounds[3] - rect_pad - (template.width - half_w - 1)
	var/min_y = bounds[2] + rect_pad + half_h
	var/max_y = bounds[4] - rect_pad - (template.height - half_h - 1)
	if(min_x > max_x || min_y > max_y)
		return null
	var/center_x = round((bounds[1] + bounds[3]) / 2)
	var/center_y = max(round((bounds[2] + bounds[4]) / 2), planet.get_dock_strip_top_y(level) + 1 + STEALTH_TEST_FAUNA_CLEARANCE + half_h)
	return locate(clamp(center_x, min_x, max_x), clamp(center_y, min_y, max_y), level.z_value)

/// Clears the ruin's block plus the margin to open jungle ground, and fauna and nests further out.
/proc/stealth_test_clear_site(list/rect, z)
	for(var/turf/tile as anything in stealth_test_block(rect, STEALTH_TEST_SPAWNER_CLEARANCE, z))
		for(var/atom/movable/thing as anything in tile)
			if(thing.GetComponent(/datum/component/spawner) || istype(thing, /obj/structure/spawner))
				qdel(thing)
		CHECK_TICK
	for(var/turf/tile as anything in stealth_test_block(rect, STEALTH_TEST_FAUNA_CLEARANCE, z))
		for(var/mob/living/critter in tile)
			if(!critter.key && !critter.client)
				qdel(critter)
		CHECK_TICK
	// Under the den and its margin, everything goes but the ground itself: items, structures, machines,
	// flora, NPCs and anything a seeded ruin left there. Non-ground turfs (another ruin's walls or floors)
	// become jungle grass. Players and abstract effects stay.
	for(var/turf/tile as anything in stealth_test_block(rect, STEALTH_TEST_MARGIN, z))
		for(var/atom/movable/thing as anything in tile)
			if(ismob(thing))
				var/mob/occupant = thing
				if(occupant.key || occupant.client)
					continue
			else if(!isobj(thing) || istype(thing, /obj/effect/abstract))
				continue
			qdel(thing)
		if(!istype(tile, /turf/open/misc/grass) && !istype(tile, /turf/open/misc/dirt))
			tile.ChangeTurf(/turf/open/misc/grass/jungle)
		CHECK_TICK

/// Drops this planet's deferred fauna spawn points near the ruin.
/proc/stealth_test_prune_fauna(obj/structure/overmap/planet/planet, list/rect)
	var/datum/planet_mob_tracker/tracker = SSplanet_mobs.tracked_planets[planet.planet_key]
	if(isnull(tracker))
		return
	var/pad = STEALTH_TEST_FAUNA_CLEARANCE
	for(var/turf/tile as anything in tracker.surface_spawn_turfs.Copy())
		if(tile.x >= rect[1] - pad && tile.x <= rect[3] + pad && tile.y >= rect[2] - pad && tile.y <= rect[4] + pad)
			tracker.surface_spawn_turfs -= tile

/// Living stealth guards near the front door. Read from the mobs themselves, not the patrol groups: a guard only
/// joins its group on its first think (stealth_setup()), and dormant AI doesn't think until someone is near.
/proc/stealth_test_guards_near(turf/door_turf)
	. = list()
	if(isnull(door_turf))
		return
	for(var/mob/living/guard as anything in GLOB.mob_living_list)
		if(guard.stat == DEAD || !istype(guard.ai_controller, /datum/ai_controller/basic_controller/human_npc/stealth))
			continue
		var/turf/where = get_turf(guard)
		if(where?.z == door_turf.z && get_dist(where, door_turf) <= 30)
			. += guard

/// Whether any of `guards` has `spot` in its sight cone right now
/proc/stealth_test_watched(turf/spot, list/guards)
	for(var/mob/living/guard as anything in guards)
		var/datum/ai_controller/basic_controller/human_npc/stealth/stealth_ai = guard.ai_controller
		if(!istype(stealth_ai) || !stealth_ai.stealth_eyes_open())
			continue
		var/datum/stealth_skill/profile = stealth_ai.stealth_skill()
		var/turf/eye = get_turf(guard)
		if(get_dist(eye, spot) > profile.sight_range)
			continue
		if(stealth_in_cone(guard, spot, stealth_ai.stealth_half_angle()) && stealth_can_see(eye, spot, profile.sight_range))
			return TRUE
	return FALSE

/**
 * Gives `user` a mortal human body at `arrival` in the playtest kit. A living human is re-dressed and healed;
 * a ghost, a lobby player or any other mob gets a new body from their character preferences.
 */
/proc/stealth_test_planet_body(client/user, turf/arrival)
	var/mob/living/carbon/human/body = user.mob
	if(ishuman(body) && body.stat != DEAD)
		body.delete_equipment()
		body.revive(ADMIN_HEAL_ALL)
		body.forceMove(arrival)
	else
		body = new /mob/living/carbon/human(arrival)
		user.prefs.safe_transfer_prefs_to(body, is_antag = TRUE)
		body.PossessByPlayer(user.key)
	stealth_test_dress(body)
	return body

/// Mortal and dressed in the playtest kit
/proc/stealth_test_dress(mob/living/carbon/human/body)
	// Guards ignore godmode targets, so the tester must be mortal.
	REMOVE_TRAIT(body, TRAIT_GODMODE, null)
	body.equipOutfit(/datum/outfit/stealth_playtest)

/// The stealth baseline: no night vision, no armour, no cloak.
/datum/outfit/stealth_playtest
	name = "Stealth Playtest"
	uniform = /obj/item/clothing/under/syndicate/camo
	shoes = /obj/item/clothing/shoes/jackboots
	gloves = /obj/item/clothing/gloves/fingerless
	ears = /obj/item/radio/headset
	id = /obj/item/card/id/advanced
	id_trim = /datum/id_trim/admin
	back = /obj/item/storage/backpack
	backpack_contents = list(
		/obj/item/gun/ballistic/automatic/pistol = 1,
		/obj/item/ammo_box/magazine/m9mm = 3,
		/obj/item/reagent_containers/cup/glass/bottle/beer = 3,
		/obj/item/storage/medkit/regular = 1,
		/obj/item/wirecutters = 1,
		/obj/item/grenade/empgrenade = 1,
	)
	belt = /obj/item/storage/belt/military
	belt_contents = list(
		/obj/item/grenade/empgrenade = 1,
		/obj/item/grenade/flashbang = 1,
		/obj/item/jammer = 1,
		/obj/item/restraints/handcuffs/cable/zipties = 1,
		/obj/item/weldingtool = 1,
		/obj/item/crowbar = 1,
	)
	l_pocket = /obj/item/knife/combat
	r_pocket = /obj/item/flashlight

/datum/outfit/stealth_playtest/post_equip(mob/living/carbon/human/user, visuals_only = FALSE)
	if(visuals_only)
		return
	var/obj/item/gun/ballistic/automatic/pistol/pistol = locate() in user.back
	if(pistol && !pistol.suppressed)
		var/obj/item/suppressor/suppressor = new(pistol)
		pistol.install_suppressor(suppressor)
	var/obj/item/card/id/card = user.wear_id
	if(istype(card))
		card.registered_name = user.real_name
		card.update_label()

#undef STEALTH_TEST_MARGIN
#undef STEALTH_TEST_FAUNA_CLEARANCE
#undef STEALTH_TEST_SPAWNER_CLEARANCE
#undef STEALTH_TEST_EDGE
#undef STEALTH_TEST_PLANET_TIMEOUT
#undef STEALTH_TEST_GUARD_WAIT
#undef STEALTH_TEST_DOOR_X
#undef STEALTH_TEST_DOOR_Y
