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
