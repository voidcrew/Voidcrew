// Voidcrew defines are included after the test harness: zones below are 1/2/3.
/mob/living/basic/npc_zone_test
	health = 100
	maxHealth = 100
	melee_damage_lower = 10
	melee_damage_upper = 20
	combat_mode = TRUE
	faction = list(FACTION_HOSTILE)
	ai_controller = /datum/ai_controller/basic_controller/simple/simple_hostile
	unsuitable_atmos_damage = 0
	unsuitable_cold_damage = 0
	unsuitable_heat_damage = 0

/mob/living/simple_animal/hostile/npc_zone_test
	health = 100
	maxHealth = 100
	melee_damage_lower = 10
	melee_damage_upper = 20
	unsuitable_atmos_damage = 0
	unsuitable_cold_damage = 0
	unsuitable_heat_damage = 0

/// Deterministic equivalent of the wolf/ice-demon Initialize replacement rolls.
/mob/living/basic/npc_zone_test/replacement/Initialize(mapload)
	. = ..()
	new /mob/living/basic/npc_zone_test(loc)
	return INITIALIZE_HINT_QDEL

/obj/effect/spawner/random/npc_zone_test
	loot = list()

/obj/effect/spawner/random/npc_zone_test/Initialize(mapload)
	. = ..()
	return INITIALIZE_HINT_NORMAL

/datum/unit_test/voidcrew_npc_zone_profiles/Run()
	var/turf/location = run_loc_floor_bottom_left
	var/list/health_factors = list(list(1, 1.35, 1.8), list(1, 1.15, 1.3))
	var/list/damage_factors = list(list(1, 1.15, 1.35), list(1, 1.1, 1.2))
	for(var/mob_type in list(/mob/living/basic/npc_zone_test, /mob/living/simple_animal/hostile/npc_zone_test))
		for(var/role_index in 1 to 2)
			for(var/zone in 1 to 3)
				var/role = role_index == 1 ? "ordinary" : "boss"
				var/datum/npc_spawn_context/context = allocate(/datum/npc_spawn_context, src, zone, role)
				var/mob/living/body = spawn_npc_in_zone(mob_type, location, context, FALSE)
				body.setBruteLoss(40)
				context.finalize()
				var/health_factor = health_factors[role_index][zone]
				var/damage_factor = damage_factors[role_index][zone]
				TEST_ASSERT(abs(body.maxHealth - 100 * health_factor) < 0.001, "[mob_type]/[role]/[zone]: wrong max health")
				TEST_ASSERT(abs(body.health / body.maxHealth - 0.6) < 0.001, "Finalization healed a wounded [mob_type]")
				body.updatehealth()
				TEST_ASSERT(abs(body.health / body.maxHealth - 0.6) < 0.001, "updatehealth lost scaled damage")
				TEST_ASSERT(abs(body.melee_damage_upper - 20 * damage_factor) < 0.001, "Wrong melee factor")
				context.finalize()
				body.forceMove(run_loc_floor_top_right)
				body.finalize_npc_zone(allocate(/datum/npc_spawn_context, src, 1, "boss"))
				TEST_ASSERT_EQUAL(body.npc_spawn_context, context, "Movement/repeated calls replaced the pinned context")
				TEST_ASSERT(abs(body.maxHealth - 100 * health_factor) < 0.001, "Repeated finalization stacked health")
				body.fully_heal()
				TEST_ASSERT_EQUAL(body.health, body.maxHealth, "Healing lost the scaled maximum")
				body.death()
				body.revive(ADMIN_HEAL_ALL)
				TEST_ASSERT(abs(body.maxHealth - 100 * health_factor) < 0.001, "Revival selected a different maximum")
				body.setBruteLoss(body.maxHealth * 0.4)
				body.set_npc_zone_melee(30, 40)
				body.set_npc_zone_melee(30, 40)
				TEST_ASSERT(abs(body.melee_damage_upper - 40 * damage_factor) < 0.001, "Replacing a weapon stacked its raw force")
				body.set_npc_zone_health(200)
				TEST_ASSERT(abs(body.maxHealth - 200 * health_factor) < 0.001, "Raw posse/phase health lost its factor")
				TEST_ASSERT(abs(body.health / body.maxHealth - 0.6) < 0.001, "Raw health change healed the body")
				body.exempt_npc_zone()
				TEST_ASSERT_EQUAL(body.maxHealth, 200, "Exemption did not restore the current raw max health")
				TEST_ASSERT(abs(body.health / body.maxHealth - 0.6) < 0.001, "Exemption changed health fraction")
				TEST_ASSERT_EQUAL(body.melee_damage_upper, 40, "Exemption did not restore raw weapon force")
				context.finalize()
				TEST_ASSERT(!body.npc_zone_applied, "Exemption was reversed by repeated finalization")
				qdel(body)

/datum/unit_test/voidcrew_npc_zone_damage/Run()
	var/datum/npc_spawn_context/context = allocate(/datum/npc_spawn_context, src, 3)
	var/mob/living/body = spawn_npc_in_zone(/mob/living/basic/npc_zone_test, run_loc_floor_bottom_left, context)
	var/obj/projectile/bullet/projectile = allocate(/obj/projectile/bullet)
	var/raw_damage = projectile.damage
	SEND_SIGNAL(body, COMSIG_PROJECTILE_FIRER_BEFORE_FIRE, projectile)
	SEND_SIGNAL(body, COMSIG_PROJECTILE_FIRER_BEFORE_FIRE, projectile)
	TEST_ASSERT(abs(projectile.damage - raw_damage * 1.35) < 0.001, "A reused projectile multiplied damage twice")
	TEST_ASSERT_EQUAL(npc_zone_damage(10, body), 13.5, "Raw scripted ability did not scale")
	TEST_ASSERT_EQUAL(npc_zone_damage(13.5, body, TRUE), 13.5, "Already-scaled melee input scaled twice")
	var/delayed_factor = body.get_npc_zone_damage_factor()
	qdel(body)
	TEST_ASSERT_EQUAL(npc_zone_damage(10, delayed_factor), 13.5, "Delayed damage lost its numeric factor after creator deletion")

/datum/unit_test/voidcrew_npc_zone_exemptions/Run()
	var/turf/location = run_loc_floor_bottom_left
	// Producers for pets, recruits, guards, arenas and summons share this opt-out.
	for(var/child_role in list("ordinary", "boss"))
		var/datum/npc_spawn_context/context = allocate(/datum/npc_spawn_context, src, 3, "exempt")
		var/mob/living/body = spawn_npc_in_zone(/mob/living/basic/npc_zone_test, location, context)
		TEST_ASSERT(!body.npc_zone_applied, "Explicit source exemption failed")
		var/datum/npc_spawn_context/child_context = allocate(/datum/npc_spawn_context, body, 3, child_role)
		var/mob/living/child = spawn_npc_in_zone(/mob/living/basic/npc_zone_test, location, child_context)
		TEST_ASSERT(!child.npc_zone_applied, "An exempt descendant lost exemption to its [child_role] role")
		qdel(body)
		qdel(child)
	var/datum/npc_spawn_context/passive_context = allocate(/datum/npc_spawn_context, src, 3)
	var/mob/living/basic/passive = spawn_npc_in_zone(/mob/living/basic/npc_zone_test, location, passive_context, FALSE)
	passive.combat_mode = FALSE
	passive_context.finalize()
	TEST_ASSERT(!passive.npc_zone_applied, "Passive ambient fauna received a hostile profile")
	qdel(passive)
	var/datum/npc_spawn_context/context = allocate(/datum/npc_spawn_context, src, 3)
	var/mob/living/body = spawn_npc_in_zone(/mob/living/basic/npc_zone_test, location, context)
	body.setBruteLoss(90)
	var/mob/living/basic/friend = allocate(/mob/living/basic/npc_zone_test, location)
	friend.exempt_npc_zone()
	body.befriend(friend)
	TEST_ASSERT(!body.npc_zone_applied && body.npc_zone_exempt, "Player-owned taming did not remove the profile")
	TEST_ASSERT(abs(body.health / body.maxHealth - 0.5) < 0.001, "Taming healed the body")
	qdel(body)
	for(var/ownership_signal in list(COMSIG_MOB_LOGIN, COMSIG_MOB_MIND_TRANSFERRED_INTO))
		context = allocate(/datum/npc_spawn_context, src, 3)
		body = spawn_npc_in_zone(/mob/living/basic/npc_zone_test, location, context)
		SEND_SIGNAL(body, ownership_signal)
		TEST_ASSERT(!body.npc_zone_applied && body.npc_zone_exempt, "Ownership signal left a profile active")
		qdel(body)
	context = allocate(/datum/npc_spawn_context, src, 3)
	body = spawn_npc_in_zone(/mob/living/basic/npc_zone_test, location, context)
	body.mind_initialize()
	TEST_ASSERT(!body.npc_zone_applied && body.npc_zone_exempt, "Mind initialization left a profile active")
	qdel(body)

/datum/unit_test/voidcrew_npc_zone_bosses/Run()
	for(var/boss_type in list(
		/mob/living/simple_animal/hostile/megafauna,
		/mob/living/simple_animal/hostile/asteroid/elite,
		/mob/living/basic/boss,
		/mob/living/basic/trooper/pirate/faction/boss,
		/mob/living/basic/bounty_criminal/boss,
		/mob/living/basic/bounty_criminal/kingpin,
		/mob/living/basic/bounty_lair_boss,
		/mob/living/basic/lich,
		/mob/living/basic/trooper/pirate/faction/silverscale/captain,
		/mob/living/basic/trooper/pirate/faction/skeleton/captain,
		/mob/living/basic/trooper/pirate/faction/grey/captain,
		/mob/living/basic/trooper/pirate/faction/lustrous/captain,
		/mob/living/basic/trooper/pirate/faction/interdyne/captain,
		/mob/living/basic/trooper/pirate/faction/irs/captain,
		/mob/living/basic/trooper/pirate/faction/medieval/captain,
		/mob/living/simple_animal/hostile/asteroid/old_demon,
		/mob/living/basic/mining/wolf/alpha,
		/mob/living/simple_animal/hostile/asteroid/polarbear/warrior,
	))
		TEST_ASSERT(npc_zone_boss_type(boss_type), "Approved boss type missing: [boss_type]")
	TEST_ASSERT(!npc_zone_boss_type(/mob/living/basic/npc_zone_test), "An ordinary mob was classified as a boss")
	// Research's count overrides belong to W1, but its setpiece role is core policy.
	var/obj/effect/zone_mobs/bug/boss/research_marker = allocate(/obj/effect/zone_mobs/bug/boss)
	TEST_ASSERT_EQUAL(research_marker.npc_role, "boss", "Research marker did not select the explicit boss role")
	qdel(research_marker)
	var/datum/npc_spawn_context/context = allocate(/datum/npc_spawn_context, src, 3)
	var/mob/living/body = spawn_npc_in_zone(/mob/living/basic/npc_zone_test, run_loc_floor_bottom_left, context, FALSE)
	body.name = "Captain Boss Kingpin"
	body.setMaxHealth(10000)
	body.setBruteLoss(0)
	context.finalize()
	TEST_ASSERT_EQUAL(body.npc_zone_role, "ordinary", "Name/health inferred boss status")
	qdel(body)

/datum/unit_test/voidcrew_npc_zone_replacements/Run()
	var/datum/npc_spawn_context/context = allocate(/datum/npc_spawn_context, src, 2)
	var/mob/living/body = spawn_npc_in_zone(/mob/living/basic/npc_zone_test/replacement, run_loc_floor_bottom_left, context, FALSE)
	TEST_ASSERT(istype(body, /mob/living/basic/npc_zone_test) && !QDELETED(body), "Constructor failed to return the surviving replacement")
	TEST_ASSERT(!body.npc_zone_applied, "Replacement finalized before caller setup")
	body.setMaxHealth(200)
	body.setBruteLoss(50)
	context.finalize()
	TEST_ASSERT_EQUAL(body.maxHealth, 270, "Replacement lost context or caller health setup")
	TEST_ASSERT(abs(body.health / body.maxHealth - 0.75) < 0.001, "Replacement finalization lost existing damage")
	TEST_ASSERT_EQUAL(body.npc_spawn_context.source_id, context.source_id, "Replacement lost source identity")
	qdel(body)
	// A caller may spawn while map initialization is deferred. Its finalization
	// request must reach a replacement that did not exist when finalize() ran.
	context = allocate(/datum/npc_spawn_context, src, 3)
	var/old_state = SSatoms.initialized
	SSatoms.initialized = INITIALIZATION_INSSATOMS
	var/mob/living/pending = spawn_npc_in_zone(/mob/living/basic/npc_zone_test/replacement, run_loc_floor_bottom_left, context)
	SSatoms.initialized = old_state
	TEST_ASSERT(!pending.npc_zone_applied, "Deferred body finalized before Initialize")
	SSatoms.InitAtom(pending, FALSE, list(TRUE))
	body = locate(/mob/living/basic/npc_zone_test) in run_loc_floor_bottom_left
	TEST_ASSERT_NOTNULL(body, "Deferred constructor lost its replacement")
	if(body)
		TEST_ASSERT_EQUAL(body.maxHealth, 180, "Deferred replacement lost the earlier finalization request")
		qdel(body)

/datum/unit_test/voidcrew_npc_zone_routes/Run()
	var/turf/location = run_loc_floor_bottom_left
	// Random spawners use the same replacement-aware constructor.
	var/obj/effect/spawner/random/npc_zone_test/random_spawner = allocate(/obj/effect/spawner/random/npc_zone_test, location)
	random_spawner.npc_spawn_context = allocate(/datum/npc_spawn_context, src, 3)
	var/mob/living/body = random_spawner.make_item(location, /mob/living/basic/npc_zone_test/replacement)
	TEST_ASSERT_EQUAL(body.maxHealth, 180, "Random spawner replacement escaped the profile")
	qdel(body)
	// Biome and cave generation resolve their generating turf, never a z-only band.
	var/area/site_area = get_area(location)
	var/old_flags = site_area.area_flags
	site_area.area_flags |= MOB_SPAWN_ALLOWED
	var/datum/biome/biome = allocate(/datum/biome)
	biome.mob_spawn_list = list(/mob/living/basic/npc_zone_test = 1)
	biome.mob_spawn_chance = 100
	biome.generate_features(location)
	body = locate(/mob/living/basic/npc_zone_test) in location
	TEST_ASSERT_NOTNULL(body?.npc_spawn_context, "Biome route omitted spawn context")
	if(body)
		TEST_ASSERT_EQUAL(body.npc_spawn_context.source_turf, location, "Biome pinned the wrong site")
		body.npc_spawn_context.on_zone_resolved(2)
		TEST_ASSERT_EQUAL(body.maxHealth, 135, "Biome route did not finalize after resolution")
		qdel(body)
	var/datum/map_generator/cave_generator/cave = allocate(/datum/map_generator/cave_generator)
	cave.possible_biomes = null
	cave.open_turf_types = list(location.type)
	cave.mob_spawn_list = list(/mob/living/basic/npc_zone_test)
	cave.mob_spawn_chance = 100
	cave.populate_terrain(list(location), site_area)
	body = locate(/mob/living/basic/npc_zone_test) in location
	TEST_ASSERT_NOTNULL(body?.npc_spawn_context, "Cave/asteroid route omitted spawn context")
	if(body)
		body.npc_spawn_context.on_zone_resolved(3)
		TEST_ASSERT_EQUAL(body.maxHealth, 180, "Cave route did not finalize")
		qdel(body)
	site_area.area_flags = old_flags
	// All owned marker themes use 1-2, and explicit setpiece roles survive shared types.
	for(var/marker_type in list(/obj/effect/zone_mobs/wildlife, /obj/effect/zone_mobs/asteroid, /obj/effect/zone_mobs/wildlife/boss, /obj/effect/zone_mobs/robot/boss, /obj/effect/zone_mobs/cult/boss, /obj/effect/zone_mobs/undead/boss, /obj/effect/zone_mobs/pirate/boss, /obj/effect/zone_mobs/syndicate/boss))
		var/obj/effect/zone_mobs/marker = allocate(marker_type)
		if(npc_zone_boss_type(marker_type))
			TEST_ASSERT_EQUAL(marker.npc_role, "boss", "[marker_type] did not select the boss role")
		for(var/list/counts in list(marker.count_green, marker.count_yellow, marker.count_red))
			TEST_ASSERT_EQUAL(counts[1], 1, "[marker_type] minimum count differs")
			TEST_ASSERT_EQUAL(counts[2], 2, "[marker_type] maximum count differs")
		qdel(marker)
	// Initialize in nullspace so the resolver cannot race this explicit do_spawn().
	var/obj/effect/zone_mobs/marker = allocate(/obj/effect/zone_mobs, null, list(1, 2))
	marker.forceMove(location)
	marker.mobs_red = list(/mob/living/basic/npc_zone_test = 1)
	marker.npc_role = "boss"
	marker.do_spawn(3)
	var/count = 0
	for(var/mob/living/basic/npc_zone_test/guard in range(3, location))
		count++
		TEST_ASSERT_EQUAL(guard.npc_zone_role, "boss", "Marker setpiece role was lost")
		TEST_ASSERT_EQUAL(guard.maxHealth, 130, "Marker output used the ordinary factor")
		qdel(guard)
	TEST_ASSERT(count >= 1 && count <= 2, "Marker count escaped the 1-2 budget")
	qdel(marker)
	for(var/band in 1 to 3)
		TEST_ASSERT_EQUAL(SSplanet_mobs.mob_cap_for_band(band), 15, "Band [band] does not have the flat fauna cap")

/datum/unit_test/voidcrew_npc_zone_deferred/Run()
	var/turf/location = run_loc_floor_bottom_left
	var/datum/planet_mob_tracker/tracker = allocate(/datum/planet_mob_tracker)
	tracker.surface_z = location.z
	tracker.zone_band = 2
	tracker.mob_cap = 1
	tracker.surface_spawn_turfs[location] = /mob/living/basic/npc_zone_test/replacement
	var/old_total = SSplanet_mobs.total_managed_mobs
	SSplanet_mobs.total_managed_mobs = 0
	var/spawned = SSplanet_mobs.spawn_for_tracker(tracker)
	SSplanet_mobs.total_managed_mobs = old_total
	TEST_ASSERT_EQUAL(spawned, 1, "Deferred fauna fixture failed to emit a mob")
	var/mob/living/basic/npc_zone_test/body = locate() in location
	TEST_ASSERT_NOTNULL(body, "Deferred fauna lost the replacement")
	if(body)
		TEST_ASSERT_EQUAL(body.maxHealth, 135, "Deferred fauna ignored the tracker band")
		TEST_ASSERT_EQUAL(body.npc_spawn_context.source_id, REF(tracker), "Deferred fauna lost tracker identity")
		qdel(body)

/datum/unit_test/voidcrew_npc_zone_spawner
	var/mob/living/watcher
	var/watched_z

/datum/unit_test/voidcrew_npc_zone_spawner/Destroy()
	if(watched_z)
		SSmobs.clients_by_zlevel[watched_z] -= watcher
	return ..()

/datum/unit_test/voidcrew_npc_zone_spawner/proc/setup_body(mob/living/body)
	TEST_ASSERT(FACTION_HOSTILE in body.faction, "Spawner callback ran before faction assignment")
	TEST_ASSERT(!body.npc_zone_applied, "Spawner finalized before its setup callback")
	body.setMaxHealth(200)
	body.setBruteLoss(50)

/datum/unit_test/voidcrew_npc_zone_spawner/Run()
	var/turf/location = run_loc_floor_bottom_left
	watcher = allocate(/mob/living/basic, location)
	watched_z = location.z
	SSmobs.clients_by_zlevel[watched_z] |= watcher
	for(var/list/distances in list(list(1, 0), list(2, 1), list(2, 0)))
		var/obj/structure/parent = allocate(/obj/structure, location)
		parent.npc_spawn_context = allocate(/datum/npc_spawn_context, src, 3, "auto", FALSE, location)
		var/datum/component/spawner/spawner = parent.AddComponent(/datum/component/spawner, \
			spawn_types = list(/mob/living/basic/npc_zone_test/replacement), \
			faction = list(FACTION_HOSTILE), spawn_callback = CALLBACK(src, PROC_REF(setup_body)), \
			spawn_distance = distances[1], spawn_distance_exclude = distances[2])
		spawner.try_spawn_mob()
		TEST_ASSERT_EQUAL(length(spawner.spawned_things), 1, "Component branch [distances[1]]/[distances[2]] lost its output")
		for(var/datum/weakref/body_ref as anything in spawner.spawned_things)
			var/mob/living/body = body_ref.resolve()
			TEST_ASSERT_EQUAL(body.maxHealth, 360, "Component finalized before callback health setup")
			TEST_ASSERT(abs(body.health / body.maxHealth - 0.75) < 0.001, "Component scaling healed the output")
			qdel(body)
		qdel(parent)

/// The map parser constructs atoms before SSatoms initializes them. Exercise that
/// delayed path with a replacement, plus two adjacent site footprints on one z.
/datum/unit_test/voidcrew_npc_zone_packed
	var/list/sites = list()
	var/list/overmap_turfs = list()
	var/zones_were_active

/datum/unit_test/voidcrew_npc_zone_packed/Destroy()
	SSovermap_zones.zones_active = zones_were_active
	for(var/obj/structure/overmap/planet/site as anything in sites)
		site.mapzone = null
		site.footprint = null
	for(var/turf/open/overmap/tile as anything in overmap_turfs)
		tile.current_zone = null
		tile.ChangeTurf(overmap_turfs[tile])
	return ..()

/datum/unit_test/voidcrew_npc_zone_packed/Run()
	zones_were_active = SSovermap_zones.zones_active
	SSovermap_zones.zones_active = TRUE
	var/turf/base = run_loc_floor_bottom_left
	var/list/locations = list(get_step(base, NORTH), get_step(get_step(base, NORTH), EAST))
	for(var/band in list(1, 3))
		var/turf/token = band == 1 ? base : get_step(base, EAST)
		var/old_type = token.type
		var/turf/open/overmap/overmap_tile = token.ChangeTurf(/turf/open/overmap)
		overmap_turfs[overmap_tile] = old_type
		overmap_tile.current_zone = allocate(/datum/overmap_zone, band)
		var/turf/inside = locations[band == 1 ? 1 : 2]
		var/datum/map_zone/zone = allocate(/datum/map_zone)
		zone.z_levels = list(reservation)
		var/datum/map_footprint/footprint = allocate(/datum/map_footprint)
		footprint.z_value = inside.z
		footprint.set_rect(inside.x, inside.y, 1, 1)
		var/obj/structure/overmap/planet/site = allocate(/obj/structure/overmap/planet, overmap_tile)
		sites += site
		site.mapzone = zone
		site.footprint = footprint
		TEST_ASSERT_EQUAL(SSovermap_zones.get_zone_type_anywhere(inside), band, "Packed fixture resolved its neighbour's band")
		var/old_state = SSatoms.initialized
		SSatoms.initialized = INITIALIZATION_INSSATOMS
		var/mob/living/basic/npc_zone_test/mapped = new /mob/living/basic/npc_zone_test/replacement(inside)
		SSatoms.initialized = old_state
		SSatoms.InitAtom(mapped, FALSE, list(TRUE))
		var/mob/living/basic/npc_zone_test/body = locate() in inside
		TEST_ASSERT_NOTNULL(body, "Mapped Initialize replacement vanished")
		if(!body)
			continue
		body.npc_spawn_context.resolve_zone()
		TEST_ASSERT_EQUAL(body.npc_spawn_context.zone_type, band, "Mapped replacement resolved a different site")
		TEST_ASSERT_EQUAL(body.maxHealth, band == 1 ? 100 : 180, "Mapped replacement used its neighbour's factor")
		body.forceMove(locations[band == 1 ? 2 : 1])
		body.finalize_npc_zone()
		TEST_ASSERT_EQUAL(body.npc_spawn_context.zone_type, band, "Moving a mapped hostile retiered it")
		qdel(body)

/// Hull crews finalize after their key/setup, and nullspace pods use the captured raid band.
/datum/unit_test/voidcrew_npc_zone_ship_routes/Run()
	var/turf/location = run_loc_floor_bottom_left
	var/obj/structure/overmap/ship/npc/pirate/ship = allocate(/obj/structure/overmap/ship/npc/pirate)
	var/obj/structure/overmap/ship/target = allocate(/obj/structure/overmap/ship)
	var/obj/docking_port/mobile/voidcrew/port = allocate(/obj/docking_port/mobile/voidcrew, location)
	port.shuttle_areas = list((get_area(location)) = TRUE)
	ship.shuttle = port
	ship.pool_zone_type = 2
	ship.crew_min = 2
	ship.crew_max = 2
	ship.crew_types = list(/mob/living/basic/npc_zone_test)
	ship.captain_type = /mob/living/basic/npc_zone_test
	ship.spawn_crew()
	TEST_ASSERT_EQUAL(length(ship.tracked_crew), 2, "Hull crew fixture did not spawn its roster")
	for(var/mob/living/crew as anything in ship.tracked_crew)
		var/is_captain = locate(/obj/item/ship_key) in crew
		TEST_ASSERT_EQUAL(crew.npc_zone_role, is_captain ? "boss" : "ordinary", "Hull captain/crew role was lost")
		TEST_ASSERT(abs(crew.maxHealth - (is_captain ? 115 : 135)) < 0.001, "Hull crew retained the flat pirate multiplier")
		qdel(crew)
	ship.tracked_crew.Cut()
	ship.shuttle = null
	port.shuttle_areas = list()
	qdel(port, force = TRUE)
	var/datum/ai_controller/npc_ship/boarding_docking_test/profile/controller = allocate(/datum/ai_controller/npc_ship/boarding_docking_test/profile, ship)
	controller.test_floor = location
	ship.boss_type = /mob/living/basic/trooper/pirate/faction/boss/silverscale
	for(var/band in list(2, 3))
		ship.state = "flying"
		target.state = "flying"
		controller.test_zone = allocate(/datum/overmap_zone, band)
		controller.set_target(target)
		var/mob/living/boarder = create_boarding_pod(location, target, ship, /mob/living/basic/npc_zone_test)
		TEST_ASSERT_NOTNULL(boarder, "Ordinary pod route did not create a boarder")
		TEST_ASSERT_EQUAL(boarder.npc_spawn_context.zone_type, band, "A nullspace pod lost the target band")
		TEST_ASSERT(abs(boarder.maxHealth - (band == 2 ? 135 : 180)) < 0.001, "Ordinary pod used the old flat multiplier")
		var/mob/living/boss = create_boss_boarding_pod(location, target, ship, ship.boss_type)
		if(band == 3)
			TEST_ASSERT_NOTNULL(boss, "Red pod route omitted its boss")
			TEST_ASSERT_EQUAL(boss.npc_zone_role, "boss", "Boss pod lost its explicit role")
			TEST_ASSERT(abs(boss.maxHealth - boss.npc_zone_original_max_health * 1.3) < 0.001, "Boss initialization health was scaled incorrectly")
			TEST_ASSERT_NULL(create_boss_boarding_pod(location, target, ship, ship.boss_type), "A second boss escaped the engagement budget")
		else
			TEST_ASSERT_NULL(boss, "Yellow deployed a boss")
		target.state = "idle"
		for(var/obj/effect/pod_landingzone/boarding/landing in location)
			landing.cancel_if_target_docked()
		controller.clear_target()

/datum/unit_test/voidcrew_npc_zone_bounty_routes/Run()
	var/turf/location = run_loc_floor_bottom_left
	var/datum/bounty_record/record = allocate(/datum/bounty_record)
	record.tier = 2 // BOUNTY_TIER_WANTED
	record.style = "brawler"
	var/mob/living/basic/bounty_criminal/criminal = spawn_bounty_criminal(record, location, null)
	allocated += criminal
	var/raw_health = criminal.body_tier_health()
	criminal.npc_spawn_context.on_zone_resolved(3)
	TEST_ASSERT(abs(criminal.maxHealth - raw_health * 1.8) < 0.001, "Criminal route finalized before body_setup")
	criminal.setBruteLoss(criminal.maxHealth / 2)
	var/mob/living/basic/bounty_criminal/decoy/decoy = allocate(/mob/living/basic/bounty_criminal/decoy, location)
	decoy.body_match(criminal)
	decoy.body_match(criminal)
	TEST_ASSERT_EQUAL(decoy.npc_spawn_context.source_id, criminal.npc_spawn_context.source_id, "Decoy lost the fugitive source")
	TEST_ASSERT_EQUAL(decoy.maxHealth, criminal.maxHealth, "Repeated body_match multiplied copied health")
	TEST_ASSERT(abs(decoy.health / decoy.maxHealth - criminal.health / criminal.maxHealth) < 0.001, "Decoy copy changed health fraction")
	var/mob/living/carbon/human/consistent/admin = allocate(/mob/living/carbon/human/consistent, run_loc_floor_top_right)
	var/datum/bounty_admin_panel/unit_test/panel = allocate(/datum/bounty_admin_panel/unit_test, admin)
	var/mob/living/basic/bounty_criminal/decoy/admin_decoy = panel.admin_spawn_decoy(admin, criminal)
	TEST_ASSERT_NOTNULL(admin_decoy, "Admin decoy fixture failed")
	allocated += admin_decoy
	TEST_ASSERT_EQUAL(admin_decoy.maxHealth, criminal.maxHealth, "Admin decoy route stacked the copied pool")
	var/datum/bounty_real_weapon/knife = bounty_real_weapon(/obj/item/knife/combat)
	knife.apply_melee(criminal)
	knife.apply_melee(criminal)
	TEST_ASSERT(abs(criminal.melee_damage_upper - knife.force_high * 1.35) < 0.001, "Bounty weapon replacement stacked or lost the profile")
	var/mob/living/basic/bounty_criminal/kingpin/kingpin = bounty_kingpin_setup(location, list(), null)
	allocated += kingpin
	kingpin.npc_spawn_context.on_zone_resolved(2)
	TEST_ASSERT_EQUAL(kingpin.npc_zone_role, "boss", "The neutral lounge kingpin missed its explicit boss profile")
	var/mob/living/basic/bounty_kingpin_goon/goon = kingpin.kingpin_crew.spawn_goon(run_loc_floor_top_right)
	allocated += goon
	TEST_ASSERT_EQUAL(goon.npc_spawn_context.zone_type, 2, "Replacement goon lost its kingpin's site band")
	TEST_ASSERT_EQUAL(goon.npc_zone_role, "ordinary", "Goon inherited the kingpin's boss role")
	TEST_ASSERT(abs(goon.maxHealth - goon.npc_zone_original_max_health * 1.35) < 0.001, "Replacement goon did not finalize")
	kingpin.exempt_npc_zone()
	var/mob/living/basic/bounty_kingpin_goon/owned_goon = kingpin.kingpin_crew.spawn_goon(location)
	allocated += owned_goon
	TEST_ASSERT(!owned_goon.npc_zone_applied && owned_goon.npc_zone_exempt, "Player ownership did not propagate to goons")

/datum/unit_test/voidcrew_npc_zone_bounty_damage/Run()
	var/turf/location = run_loc_floor_bottom_left
	var/datum/npc_spawn_context/context = allocate(/datum/npc_spawn_context, src, 3, "boss")
	var/mob/living/basic/bounty_criminal/boss/boss = spawn_npc_in_zone(/mob/living/basic/bounty_criminal/boss/juggernaut, location, context)
	allocated += boss
	var/mob/living/basic/npc_zone_test/victim = allocate(/mob/living/basic/npc_zone_test, run_loc_floor_top_right)
	boss.boss_hit(victim, 10)
	TEST_ASSERT_EQUAL(victim.getBruteLoss(), 12, "Raw boss ability escaped scaling")
	boss.boss_hit(victim, 12, already_scaled = TRUE)
	TEST_ASSERT_EQUAL(victim.getBruteLoss(), 24, "Scaled melee input multiplied twice")
	var/list/table = boss.boss_health_table()
	boss.boss_engaged = list("first" = TRUE, "second" = TRUE)
	boss.boss_apply_posse_health(FALSE)
	TEST_ASSERT(abs(boss.maxHealth - table[2] * 1.3) < 0.001, "Posse health lost the boss factor")
	var/obj/effect/bounty_boss_explosive/explosive = allocate(/obj/effect/bounty_boss_explosive, location, boss)
	var/obj/effect/bounty_boss_fire_pool/pool = allocate(/obj/effect/bounty_boss_fire_pool, location, list(location), 5 SECONDS, boss)
	var/factor = boss.get_npc_zone_damage_factor()
	qdel(boss)
	TEST_ASSERT_EQUAL(explosive.damage_factor, factor, "Delayed explosive lost its creator's factor")
	TEST_ASSERT_EQUAL(pool.damage_factor, factor, "Delayed fire lost its creator's factor")
	victim.setMaxHealth(1000)
	victim.updatehealth()
	victim.mind_initialize()
	victim.forceMove(location)
	var/before_blast = victim.getBruteLoss()
	var/raw_blast = explosive.damage
	explosive.detonate()
	TEST_ASSERT(abs(victim.getBruteLoss() - before_blast - raw_blast * factor) < 0.001, "Orphaned explosive fallback lost or doubled its captured factor")
	var/before_fire = victim.getBruteLoss()
	pool.scorch(10)
	TEST_ASSERT(abs(victim.getBruteLoss() - before_fire - 10 * factor) < 0.001, "Orphaned fire pool lost its captured factor")
	var/datum/status_effect/bounty_boss_burning/burning = victim.apply_status_effect(/datum/status_effect/bounty_boss_burning, factor)
	// scorch already applied the refreshable effect.
	burning = victim.has_status_effect(/datum/status_effect/bounty_boss_burning)
	var/before = victim.getBruteLoss()
	burning.tick(1)
	TEST_ASSERT(abs(victim.getBruteLoss() - before - 3 * factor) < 0.001, "Lingering fire did not retain its numeric factor") // BOUNTY_BOSS_BURNING_DAMAGE

/// Exercise the mafia override in a real club room, which bypasses base marker spawning.
/datum/unit_test/voidcrew_npc_zone_mafia_room
	var/turf/room_floor
	var/area/original_area

/datum/unit_test/voidcrew_npc_zone_mafia_room/Destroy()
	if(room_floor && original_area)
		room_floor.change_area(get_area(room_floor), original_area)
	return ..()

/datum/unit_test/voidcrew_npc_zone_mafia_room/Run()
	room_floor = run_loc_floor_bottom_left
	original_area = get_area(room_floor)
	var/area/ruin/space/has_grav/powered/mafia_club/casino/room = allocate(/area/ruin/space/has_grav/powered/mafia_club/casino)
	room_floor.change_area(original_area, room)
	var/obj/effect/zone_mobs/mafia/marker = allocate(/obj/effect/zone_mobs/mafia)
	marker.forceMove(room_floor)
	marker.do_spawn(3)
	var/count = 0
	var/list/roster = bounty_mafia_room_crew(room.type)
	for(var/mob/living/basic/trooper/russian/mafia/goon in room_floor)
		allocated += goon
		count++
		TEST_ASSERT(roster[goon.type], "Custom mafia marker escaped its existing room roster")
		TEST_ASSERT_EQUAL(goon.npc_zone_role, "ordinary", "Custom mafia room output missed finalization")
		TEST_ASSERT(abs(goon.maxHealth - goon.npc_zone_original_max_health * 1.8) < 0.001, "Custom mafia room output missed the selected factor")
	TEST_ASSERT(count >= 1 && count <= 2, "Custom mafia marker escaped the 1-2 output budget")

/// Field-route fixtures suppress offer generation, retaining the real spawn/tracking paths.
/datum/mission/npc_zone_test/generate_mission_details()
	return

/datum/mission_target/npc_zone_test
	var/band = 3

/datum/mission_target/npc_zone_test/get_zone_type()
	return band

/datum/unit_test/voidcrew_npc_zone_mission_routes/Run()
	var/turf/location = run_loc_floor_bottom_left
	var/datum/mission/mission = allocate(/datum/mission/npc_zone_test)
	mission.objective_name = "Test quarry"
	var/datum/mission_target/npc_zone_test/site = allocate(/datum/mission_target/npc_zone_test, mission)
	mission.target = site
	for(var/objective_type in list(/datum/mission_objective/field/kill_named, /datum/mission_objective/field/kill_named/big_game))
		var/datum/mission_objective/field/kill_named/objective = allocate(objective_type)
		objective.mission = mission
		objective.target_mob_type = /mob/living/basic/npc_zone_test/replacement
		objective.guard_types = list(/mob/living/basic/npc_zone_test/replacement)
		var/is_hunt = istype(objective, /datum/mission_objective/field/kill_named/big_game)
		if(is_hunt)
			var/datum/mission_objective/field/kill_named/big_game/hunt = objective
			hunt.health_override = 450
		objective.spawn_field_objects(location)
		var/mob/living/body = objective.target_mob
		TEST_ASSERT_NOTNULL(body, "[objective_type] lost its replacement target")
		TEST_ASSERT_EQUAL(body.npc_spawn_context.source_id, REF(site), "Mission target lost site identity")
		TEST_ASSERT_EQUAL(body.npc_spawn_context.zone_type, 3, "Mission used its spawn turf instead of its site's band")
		TEST_ASSERT(abs(body.maxHealth - (is_hunt ? 810 : 180)) < 0.001, "Mission finalized before hunt health setup")
		var/guards = 0
		for(var/mob/living/basic/npc_zone_test/guard in range(3, location))
			if(guard == body)
				continue
			guards++
			TEST_ASSERT_EQUAL(guard.maxHealth, 180, "Mission guard replacement missed finalization")
			qdel(guard)
		TEST_ASSERT_EQUAL(guards, 1, "Mission lost an entourage output")
		mission.forget_quest_atom(body)
		objective.deactivate()
		qdel(body)
		qdel(objective)
	// Auto role profiles hostile specimens while passive captures remain baseline.
	for(var/specimen_type in list(/mob/living/basic/npc_zone_test/replacement, /mob/living/basic/butterfly))
		var/datum/mission_objective/field/capture_beast/capture = allocate(/datum/mission_objective/field/capture_beast)
		capture.mission = mission
		capture.target_mob_type = specimen_type
		capture.spawn_field_objects(location)
		var/mob/living/body = capture.target_mob
		var/hostile = specimen_type == /mob/living/basic/npc_zone_test/replacement
		TEST_ASSERT_EQUAL(body.npc_zone_applied, hostile, "Capture route ignored the environmental hostile gate")
		if(hostile)
			TEST_ASSERT_EQUAL(body.maxHealth, 180, "Hostile capture lost the site band")
		else
			TEST_ASSERT_EQUAL(body.maxHealth, initial(body.maxHealth), "Passive specimen was scaled")
		mission.forget_quest_atom(body)
		capture.deactivate()
		qdel(body)
		qdel(capture)
	var/datum/mission_objective/field/wipe_camp/camp = allocate(/datum/mission_objective/field/wipe_camp)
	camp.mission = mission
	camp.squad_types = list(/mob/living/simple_animal/hostile/npc_zone_test)
	camp.squad_names = list("Test poacher")
	// A hostile type makes a missing rescue exemption visible.
	camp.critter_type = /mob/living/basic/npc_zone_test/replacement
	camp.spawn_field_objects(location)
	TEST_ASSERT_EQUAL(length(camp.squad), 1, "Camp did not retain its squad")
	var/mob/living/poacher = camp.squad[1]
	TEST_ASSERT_EQUAL(poacher.maxHealth, 180, "Poacher missed camp-band finalization")
	var/cages = 0
	for(var/obj/item/pet_carrier/cage in range(3, location))
		for(var/mob/living/rescued in cage)
			cages++
			TEST_ASSERT(rescued.npc_zone_exempt && !rescued.npc_zone_applied, "Rescued cage replacement received a hostile profile")
			TEST_ASSERT_EQUAL(rescued.maxHealth, 100, "Rescued animal health was scaled")
	TEST_ASSERT(cages >= 1, "Camp fixture did not produce a rescued animal")
	mission.forget_quest_atom(mission.quest_atom)
	camp.deactivate()
	qdel(poacher)

/// Actual fauna replacement rolls must defer finalization until the caller finishes setup.
/datum/unit_test/voidcrew_npc_zone_fauna_routes/Run()
	var/list/replacement_types = list(
		/mob/living/basic/mining/wolf/random = /mob/living/basic/mining/wolf/alpha,
		/mob/living/basic/mining/wolf/wasteland/random = /mob/living/basic/mining/wolf/alpha/wasteland,
		/mob/living/simple_animal/hostile/asteroid/polarbear/random = /mob/living/simple_animal/hostile/asteroid/polarbear/warrior,
		/mob/living/simple_animal/hostile/asteroid/hermit/survivor/random = /mob/living/simple_animal/hostile/asteroid/hermit/ranged,
	)
	for(var/spawn_type in replacement_types)
		var/found_replacement = FALSE
		// Stop at the first replacement. Even the 15% rolls miss all 256 with probability < 1e-18.
		for(var/attempt in 1 to 256)
			var/datum/npc_spawn_context/context = allocate(/datum/npc_spawn_context, src, 2)
			var/mob/living/body = spawn_npc_in_zone(spawn_type, run_loc_floor_bottom_left, context, FALSE)
			TEST_ASSERT(!body.npc_zone_applied, "[spawn_type] finalized during its replacement roll")
			found_replacement = istype(body, replacement_types[spawn_type])
			body.setMaxHealth(200)
			body.setBruteLoss(50)
			context.finalize()
			var/is_boss = npc_zone_boss_type(body.type)
			TEST_ASSERT(abs(body.maxHealth - (is_boss ? 230 : 270)) < 0.001, "[spawn_type] lost replacement role or caller setup")
			TEST_ASSERT(abs(body.health / body.maxHealth - 0.75) < 0.001, "[spawn_type] healed during finalization")
			TEST_ASSERT_EQUAL(body.npc_spawn_context, context, "Replacement acquired a second context")
			qdel(body)
			if(found_replacement)
				break
		TEST_ASSERT(found_replacement, "[spawn_type] never exercised its replacement route")

/datum/unit_test/voidcrew_npc_zone_crystal_route/Run()
	var/turf/location = run_loc_floor_bottom_left
	var/obj/structure/spawner/sea_crystal/crystal = allocate(/obj/structure/spawner/sea_crystal, location)
	crystal.npc_spawn_context.on_zone_resolved(3)
	var/source_id = crystal.npc_spawn_context.source_id
	crystal.summon_count = 1
	TEST_ASSERT(crystal.summon_minions(), "Crystal could not commit a retaliation wave")
	qdel(crystal)
	sleep(4 SECONDS)
	var/mob/living/basic/mining/hivelord/beach/hivelord = locate() in range(1, location)
	TEST_ASSERT_NOTNULL(hivelord, "Committed crystal retaliation vanished with its source")
	TEST_ASSERT_EQUAL(hivelord.npc_spawn_context.source_id, source_id, "Delayed retaliation lost crystal identity")
	TEST_ASSERT_EQUAL(hivelord.npc_spawn_context.zone_type, 3, "Delayed retaliation resolved against its landing turf")
	TEST_ASSERT(abs(hivelord.maxHealth - hivelord.npc_zone_original_max_health * 1.8) < 0.001, "Delayed retaliation did not finalize")
	allocated += hivelord

/datum/unit_test/voidcrew_npc_zone_ambush_route/Run()
	var/turf/location = run_loc_floor_bottom_left
	var/datum/ambient_place/site/site = allocate(/datum/ambient_place/site, null, location)
	site.band = 2
	var/mob/living/basic/ambient_npc/planet/peddler/peddler = allocate(/mob/living/basic/ambient_npc/planet/peddler, location)
	peddler.set_place(site)
	var/mob/living/basic/bait = allocate(/mob/living/basic, run_loc_floor_top_right)
	var/datum/ambient_activity/caravan_ambush/ambush = allocate(/datum/ambient_activity/caravan_ambush, peddler)
	var/mob/living/raider = ambush.spawn_raider(/mob/living/basic/npc_zone_test/replacement, run_loc_floor_top_right, bait)
	allocated += raider
	// spawn_pack owns this ledger and Destroy unregisters the pack's attack signal.
	ambush.pack += WEAKREF(raider)
	TEST_ASSERT_EQUAL(raider.npc_spawn_context.source_id, REF(site), "Caravan ambusher lost site identity")
	TEST_ASSERT_EQUAL(raider.maxHealth, 135, "Caravan ambusher ignored the site band")
	TEST_ASSERT(raider.GetComponent(/datum/component/leash), "Caravan ambusher missed its setup")
	TEST_ASSERT_EQUAL(raider.ai_controller.blackboard[BB_BASIC_MOB_CURRENT_TARGET], bait, "Caravan target setup was lost")
	for(var/faction_token in raider.faction)
		TEST_ASSERT(!findtext("[faction_token]", "planetary_"), "Caravan ambusher kept the planet's faction")

/// A hull fixture provides floor and crew, with real overmap resolution for its token.
/obj/structure/overmap/ship/npc_zone_test
	var/turf/test_floor

/obj/structure/overmap/ship/npc_zone_test/get_random_open_ship_turf(max_tries = 20)
	return test_floor

/obj/structure/overmap/ship/npc_zone_test/is_aboard(atom/thing)
	return get_turf(thing) == test_floor

/obj/structure/overmap/ship/npc_zone_test/get_event_crew()
	return list(1, 2, 3, 4, 5)

/datum/round_event/voidcrew/vent_clog/npc_zone_test
	var/obj/machinery/atmospherics/components/unary/vent_pump/test_vent

/datum/round_event/voidcrew/vent_clog/npc_zone_test/get_vent()
	return test_vent

/datum/voidcrew_cargo_shuttle/npc_zone_test
	var/list/test_turfs

/datum/voidcrew_cargo_shuttle/npc_zone_test/get_cargo_bay_turfs()
	return test_turfs.Copy()

/datum/unit_test/voidcrew_npc_zone_event_routes
	parent_type = /datum/unit_test/voidcrew_npc_zone_packed

/datum/unit_test/voidcrew_npc_zone_event_routes/Run()
	zones_were_active = SSovermap_zones.zones_active
	SSovermap_zones.zones_active = TRUE
	var/turf/base = run_loc_floor_bottom_left
	var/original_type = base.type
	var/turf/open/overmap/token = base.ChangeTurf(/turf/open/overmap)
	overmap_turfs[token] = original_type
	var/datum/overmap_zone/red = allocate(/datum/overmap_zone, 3)
	var/datum/overmap_zone/green = allocate(/datum/overmap_zone, 1)
	token.current_zone = red
	var/turf/location = run_loc_floor_top_right
	var/obj/structure/overmap/ship/npc_zone_test/ship = allocate(/obj/structure/overmap/ship/npc_zone_test, token)
	ship.test_floor = location
	var/obj/docking_port/mobile/voidcrew/port = allocate(/obj/docking_port/mobile/voidcrew, location)
	ship.shuttle = port
	var/datum/round_event/voidcrew/portal_storm/storm = allocate(/datum/round_event/voidcrew/portal_storm, FALSE)
	storm.target_ship = ship
	storm.setup()
	storm.hostile_types = list(/mob/living/basic/npc_zone_test/replacement = 1)
	storm.boss_types = list(/mob/living/basic/npc_zone_test/replacement = 1)
	storm.mob_cap = 2
	storm.spawn_slots_remaining = 2
	storm.pulses_remaining = 1
	storm.boss_pending = TRUE
	token.current_zone = green
	storm.spawn_pulse()
	var/list/roles = list()
	for(var/mob/living/basic/npc_zone_test/body in location)
		roles += body.npc_zone_role
		TEST_ASSERT_EQUAL(body.npc_spawn_context.zone_type, 3, "Portal pulse retiered after the ship moved bands")
		TEST_ASSERT(abs(body.maxHealth - (body.npc_zone_role == "boss" ? 130 : 180)) < 0.001, "Portal slot lost its explicit role")
		qdel(body)
	TEST_ASSERT_EQUAL(length(roles), 2, "Portal fixture lost an output")
	TEST_ASSERT(("ordinary" in roles) && ("boss" in roles), "Portal boss and ordinary slots used the same role")
	storm.kill()
	qdel(storm)
	// Docked tokens are nested in their destination; the hull floor need not resolve at all.
	token.current_zone = red
	var/obj/structure/overmap/planet/site = allocate(/obj/structure/overmap/planet, token)
	ship.forceMove(site)
	ship.docked = site
	var/obj/machinery/atmospherics/components/unary/vent_pump/vent = allocate(/obj/machinery/atmospherics/components/unary/vent_pump, location)
	var/datum/round_event/voidcrew/vent_clog/npc_zone_test/clog = allocate(/datum/round_event/voidcrew/vent_clog/npc_zone_test, FALSE)
	clog.target_ship = ship
	clog.test_vent = vent
	clog.setup()
	ship.forceMove(token)
	ship.docked = null
	ship.state = "transit"
	token.current_zone = green
	clog.spawned_mob = /mob/living/basic/npc_zone_test/replacement
	clog.produce_mob()
	TEST_ASSERT_EQUAL(length(clog.living_mobs), 1, "Vent fixture did not emit a hostile")
	for(var/datum/weakref/body_ref as anything in clog.living_mobs)
		var/mob/living/body = body_ref.resolve()
		TEST_ASSERT_EQUAL(body.npc_spawn_context.zone_type, 3, "Vent used transit floor or the new ship band")
		TEST_ASSERT_EQUAL(body.maxHealth, 180, "Vent replacement missed finalization")
		qdel(body)
	clog.life_check()
	clog.spawned_mob = /mob/living/basic/butterfly
	clog.produce_mob()
	for(var/datum/weakref/body_ref as anything in clog.living_mobs)
		var/mob/living/body = body_ref.resolve()
		TEST_ASSERT(!body.npc_zone_applied, "Harmless vent fauna was scaled")
		qdel(body)
	clog.kill()
	qdel(clog)
	qdel(vent)
	// Exercise each complete hostile loan roster, including optional additions.
	var/datum/voidcrew_cargo_shuttle/npc_zone_test/cargo = allocate(/datum/voidcrew_cargo_shuttle/npc_zone_test)
	cargo.target_ship = ship
	cargo.test_turfs = block(get_step(token, NORTH), get_step(location, WEST))
	for(var/loan_type in list(/datum/voidcrew_shuttle_loan/syndiehijacking, /datum/voidcrew_shuttle_loan/lots_of_bees, /datum/voidcrew_shuttle_loan/russian_party, /datum/voidcrew_shuttle_loan/spider_gift))
		token.current_zone = red
		var/datum/voidcrew_shuttle_loan/loan = allocate(loan_type)
		loan.spawn_items(cargo)
		var/hostiles = 0
		for(var/turf/tile as anything in cargo.test_turfs)
			for(var/mob/living/body in tile)
				if(!isbasicmob(body) && !isanimal(body))
					continue
				if(!body.npc_spawn_context || body.npc_zone_exempt)
					continue
				hostiles++
				TEST_ASSERT_EQUAL(body.npc_spawn_context.zone_type, 3, "[loan_type] resolved against the cargo bay")
				TEST_ASSERT_EQUAL(body.npc_spawn_context.source_id, REF(cargo), "[loan_type] lost its delivery identity")
				TEST_ASSERT(body.npc_zone_applied, "[loan_type] missed its explicit hostile encounter role")
				if(body.npc_zone_applied)
					TEST_ASSERT(abs(body.maxHealth - body.npc_zone_original_max_health * 1.8) < 0.001, "[loan_type] missed ordinary scaling")
				qdel(body)
		TEST_ASSERT(hostiles >= 1, "[loan_type] did not emit profiled cargo")
		token.current_zone = green
		var/mob/living/late = loan.spawn_hostile(/mob/living/basic/npc_zone_test, location, cargo)
		TEST_ASSERT_EQUAL(late.maxHealth, 180, "A later loan output selected a different host band")
		qdel(late)
		qdel(loan)
	ship.shuttle = null
	qdel(port, force = TRUE)

/datum/unit_test/voidcrew_npc_zone_recruit_route/Run()
	var/obj/structure/overmap/ship/ship = strays_test_ship(ambient_test_room_bounds())
	var/mob/living/carbon/human/consistent/leader = allocate(/mob/living/carbon/human/consistent, run_loc_floor_top_right)
	var/datum/npc_spawn_context/context = allocate(/datum/npc_spawn_context, src, 3, "ordinary")
	var/mob/living/basic/ambient_npc/stray/stranded/stray = spawn_npc_in_zone(/mob/living/basic/ambient_npc/stray/stranded, run_loc_floor_bottom_left, context, FALSE)
	allocated += stray
	stray.faction = list(FACTION_HOSTILE)
	context.finalize()
	TEST_ASSERT(stray.npc_zone_applied, "Recruit fixture did not begin profiled")
	stray.setBruteLoss(stray.maxHealth / 2)
	TEST_ASSERT(stray.accept_offer(leader, ship), "Recruit fixture could not join")
	TEST_ASSERT(stray.npc_zone_exempt && !stray.npc_zone_applied, "Recruitment retained a hostile profile")
	TEST_ASSERT(abs(stray.health / stray.maxHealth - 0.5) < 0.001, "Recruitment healed the recruit")
	var/datum/npc_spawn_context/child_context = allocate(/datum/npc_spawn_context, stray, 3)
	var/mob/living/child = spawn_npc_in_zone(/mob/living/basic/npc_zone_test/replacement, run_loc_floor_bottom_left, child_context)
	allocated += child
	TEST_ASSERT(child.npc_zone_exempt && !child.npc_zone_applied, "Recruit descendants lost exemption")
