/**
 * # Drug Run
 *
 * "Vex has a formula, a mothballed kitchen, and a buyer. You have a ship and
 * deniability. Three wild ingredients, one quiet cook, one handover."
 *
 * The contraband arc as a mission: [gather three planet-grown ingredients] ->
 * [cook the batch at a hidden lab the mission spawns for itself] -> [deliver
 * the product to the counter]. The recipe (recipe.dm) rolls the shopping
 * list from the planets actually flying this round; each ingredient gets a
 * pinned harvest site that field-spawns when its planet loads. The lab is a
 * rare, mission-locked space ruin raised at accept in the zone band the
 * contract rolled, the rumor-chart reveal steps, minus the chart.
 *
 * Phase 5 state: weight stays 0 (the black-market posting wires in later),
 * the cook runs through the lab session's full station chain (lab_session.dm),
 * mixer Simon, catalyst rhythm game, crystallizer catch game, with the
 * product printing beside the crystallizer; the customs patrol is a logged
 * roll (Phase 6). Loss policy is FAIL: one planet of each type per round
 * means a dead pin has nowhere to re-resolve.
 */
/datum/mission/drug_run
	name = "Drug Run"
	weight = 0 // never auto-rolled; posted only by the black-market board (extra_offer_mix)
	mission_limit = 1
	duration = 60 MINUTES
	quest_lost_policy = MISSION_QUEST_LOST_FAIL
	author = "Vex"
	// Contraband pays like contraband; the compressed zone table below keeps
	// deep-zone runs from doubling down on an already fat band
	value_min = 4000
	value_max = 5000
	voucher_count = 3
	// The batch's own beacon once cooked; harvest sites ride per-site tags
	gps_tag_prefix = "COOK"

	/// The rolled formula: ingredients, street name, minigame charts
	var/datum/drug_recipe/recipe
	/// One harvest site per recipe ingredient, pinned at generation
	var/list/datum/ingredient_site/sites = list()
	/// The live lab cook session: banked ingredients, stage, per-station scores
	var/datum/drug_lab_session/session
	/// The hidden lab's overmap signal, raised at mission start
	var/obj/structure/overmap/space_ruin/lab_ruin
	/// DRUG_PURITY_* the batch scored (set by the lab session before on_cook_finished())
	var/purity_tier = DRUG_PURITY_PURE
	/// The formula chip dispensed at accept
	var/obj/item/drug_formula/formula
	/// The customs patrol hunt manager, if the cook roll went badly
	var/datum/nt_patrol_director/patrol
	/// The shopping-list step
	var/datum/mission_objective/gather_ingredients/gather
	/// The cook step
	var/datum/mission_objective/drug_cook/cook
	/// The carry-home step
	var/datum/mission_objective/deliver/bound/drug_product/delivery

/datum/mission/drug_run/Destroy()
	// Site waypoints ride the servant's helm under per-site keys; the base
	// Destroy only drops the main REF(src) marker
	for(var/datum/ingredient_site/site as anything in sites)
		drop_site_waypoint(site)
		drop_site_gps_signal(site)
	QDEL_LIST(sites)
	release_lab()
	// Contract's over either way: the patrol has no quarrel left
	patrol?.stand_down()
	patrol = null
	gather = null
	cook = null
	delivery = null
	recipe = null
	formula = null
	QDEL_NULL(session)
	return ..()

/datum/mission/drug_run/get_archetype()
	return "smuggling"

/datum/mission/drug_run/setup_target()
	// The rolled coordinates only pick the zone band; the real target becomes
	// the lab ruin raised at mission start in that same band
	var/datum/mission_target/coords/coords = new(src)
	coords.zone_weights = list(
		"[ZONE_GREEN]" = 15,
		"[ZONE_YELLOW]" = 45,
		"[ZONE_RED]" = 40,
	)
	if(!coords.resolve())
		qdel(coords)
		return FALSE
	target = coords
	return TRUE

/**
 * Compressed zone table: green x1 / yellow x1.5 / red x2 instead of the
 * base's 1/1.7/2.6. The green band is already contraband-fat, so depth pads
 * the fee rather than multiplying it. Red keeps the base voucher bonus.
 */
/datum/mission/drug_run/apply_zone_scaling(zone_type)
	var/static/list/zone_scaling = list(
		"[ZONE_GREEN]" = list("name" = ZONE_NAME_GREEN, "difficulty" = MISSION_DIFFICULTY_EASY, "value_mult" = 1, "voucher_bonus" = 0),
		"[ZONE_YELLOW]" = list("name" = ZONE_NAME_YELLOW, "difficulty" = MISSION_DIFFICULTY_MEDIUM, "value_mult" = 1.5, "voucher_bonus" = 0),
		"[ZONE_RED]" = list("name" = ZONE_NAME_RED, "difficulty" = MISSION_DIFFICULTY_HARD, "value_mult" = 2, "voucher_bonus" = 1),
	)
	var/list/row = zone_scaling["[zone_type]"] || zone_scaling["[ZONE_GREEN]"]
	target_zone_name = row["name"]
	difficulty = row["difficulty"]
	value_min = round(value_min * row["value_mult"], 10)
	value_max = round(value_max * row["value_mult"], 10)
	if(voucher_count > 0)
		voucher_count += row["voucher_bonus"]

/datum/mission/drug_run/generate_details()
	// Only offer runs when enough ingredient biomes fly this round; the
	// recipe needs three distinct ones from its pool
	var/list/present = list()
	for(var/obj/structure/overmap/planet/candidate as anything in GLOB.overmap_planets)
		if(QDELETED(candidate))
			continue
		if(!istype(get_turf(candidate), /turf/open/overmap))
			continue
		if(!candidate.planet)
			continue
		present |= candidate.planet
	recipe = new
	if(!recipe.generate(present))
		generation_failed = TRUE
		return

	// One harvest site per ingredient, each pinned to its planet NOW, a
	// missing planet means no valid contract
	for(var/list/entry in recipe.ingredients)
		var/datum/ingredient_site/site = new(src, entry)
		if(!site.resolve_target())
			qdel(site)
			generation_failed = TRUE
			return
		sites += site
	// The cook's batch state, alive from offer to turn-in; the lab machines
	// are wired to it by the cook objective whenever the ruin interior loads
	session = new(src)
	objective_name = "batch of [recipe.street_name]"

/datum/mission/drug_run/build_objectives()
	gather = new
	add_objective(gather)
	cook = new
	add_objective(cook)
	delivery = new
	add_objective(delivery)

/datum/mission/drug_run/update_text()
	if(!recipe)
		return
	var/list/shopping_list = list()
	for(var/list/entry in recipe.ingredients)
		var/datum/overmap/planet/biome = entry["biome"]
		shopping_list += "[entry["name"]] ([initial(biome.name)])"
	name = "Drug Run: [recipe.street_name]"
	desc = "Vex wants a batch of [recipe.street_name] cooked quietly and sold quietly. \
		The formula chip lands on your mission pad when you sign. \
		Shopping list: [english_list(shopping_list)]. \
		Cook it at the kitchen: [active ? "an encrypted signal at ([target.target_x], [target.target_y]) in the [target_zone_name]" : "coordinates transmitted on signing, somewhere in the [target_zone_name]"]. \
		Then hand the finished product to an outpost trader. No names on anything, no questions from anyone. \
		Tap a GPS unit on your mission board to upload located harvest-site beacons; the batch itself broadcasts ([gps_tag]) once cooked. \
		Payment includes [voucher_count] trade voucher[voucher_count > 1 ? "s" : ""]."

/datum/mission/drug_run/waypoint_label()
	return "Kitchen: [recipe?.street_name || "drug run"]"

/datum/mission/drug_run/on_mission_started()
	if(!spawn_lab_ruin())
		return // fail() already ran; the mission is mid-qdel
	dispense_formula()
	if(failed || QDELETED(src))
		return
	arm_all_sites()
	push_site_waypoints()

// =========================================================================
// TURN-IN GATING, outpost counters only
// =========================================================================

/datum/mission/drug_run/can_turn_in_at(atom/reward_anchor)
	if(!istype(reward_anchor, /mob/living/basic/outpost_trader))
		return FALSE
	if(!shop?.outpost) // TEMP until black-market offer wiring: any counter fences it
		return TRUE
	var/mob/living/basic/outpost_trader/npc = reward_anchor
	return npc.outpost == shop.outpost

/datum/mission/drug_run/get_wrong_location_reason(atom/reward_anchor)
	if(shop?.outpost)
		return "Vex only settles at [shop.outpost_name]'s counter, nobody else touches the product."
	return "Vex's buyers only work outpost counters, hand the product to an outpost trader."

// =========================================================================
// THE LAB: raise the kitchen, repoint the mission at it
// =========================================================================

/**
 * Spawns the hidden lab as a rare, mission-locked space ruin in the zone
 * band the contract rolled, then swaps the mission target from the rolled
 * coordinates to the live signal (the rumor-chart reveal() steps). Returns
 * FALSE after failing the mission if the template or a clear square is
 * missing.
 */
/datum/mission/drug_run/proc/spawn_lab_ruin()
	// SSmapping's instance is the canonical, size-preloaded template
	var/datum/map_template/ruin/space/template
	for(var/template_name in SSmapping.space_ruins_templates)
		var/datum/map_template/ruin/space/candidate = SSmapping.space_ruins_templates[template_name]
		if(candidate.type == /datum/map_template/ruin/space/drug_lab)
			template = candidate
			break
	if(!template)
		stack_trace("Drug run: drug_lab ruin template is not registered (missing drug_lab.dmm?)")
		fail("The kitchen's coordinates were a dud, contract void.")
		return FALSE

	var/band = ZONE_YELLOW
	var/datum/mission_target/coords/rolled = target
	if(istype(rolled))
		band = rolled.zone_type
	var/turf/spawn_turf = SSovermap.get_unused_overmap_square_in_zone_band(band, tries = 80) // red band is ~9% of tiles; 40 tries misses ~2% of the time
	if(!spawn_turf)
		fail("No quiet corner left to hide a kitchen in, contract void.")
		return FALSE

	lab_ruin = new(spawn_turf)
	lab_ruin.set_ruin_template(template)
	lab_ruin.mark_rare()
	lab_ruin.mission_locked = TRUE

	// Swap the rolled coordinates for the real signal
	var/datum/mission_target/space_ruin/prespawned/lab_target = new(src)
	lab_target.ruin = lab_ruin
	if(!lab_target.resolve())
		qdel(lab_target)
		release_lab()
		fail("The kitchen went dark before the run began, contract void.")
		return FALSE
	QDEL_NULL(target)
	target = lab_target
	update_text()
	push_waypoint()
	return TRUE

/**
 * Releases the hidden lab back to the overmap's normal lifecycle: drop our
 * claim and deletion hooks first so the cleanup can't loop back into the
 * mission, then let the empty-ruin check run (rare ruins never seed a
 * replacement). A lab nobody ever visited has no reservation for
 * check_and_respawn() to clean, so it gets deleted outright.
 */
/datum/mission/drug_run/proc/release_lab()
	if(!lab_ruin)
		return
	if(istype(target, /datum/mission_target/space_ruin/prespawned))
		var/datum/mission_target/space_ruin/prespawned/lab_target = target
		if(lab_target.ruin == lab_ruin)
			lab_target.unhook()
	var/obj/structure/overmap/space_ruin/lab = lab_ruin
	lab_ruin = null
	if(QDELETED(lab))
		return
	lab.mission_locked = FALSE
	if(!lab.mapzone)
		qdel(lab)
		return
	lab.check_and_respawn()

// =========================================================================
// THE FORMULA CHIP: the shopping list, delivered at accept
// =========================================================================

/**
 * Spawns the formula chip at the servant's mission pad (fallback: the ship's
 * own footprint, the courier-pod precedent).
 */
/datum/mission/drug_run/proc/dispense_formula()
	var/turf/chip_turf = get_pad_turf()
	if(!chip_turf)
		fail("No mission pad to deliver the formula chip to.")
		return
	formula = new(chip_turf)
	formula.recipe = recipe
	servant?.ship_notify("Formula chip for '[recipe.street_name]' delivered to your mission pad. Examine it for the shopping list.", "DRUG RUN", SHIP_NOTIFY_NOTICE, 'voidcrew/sound/notify.ogg', 50)

/// First linked mission pad's turf, else the ship's shuttle turf (courier fallback)
/datum/mission/drug_run/proc/get_pad_turf()
	for(var/obj/machinery/mission_pad/pad as anything in servant?.linked_mission_pads)
		if(QDELETED(pad))
			continue
		return get_turf(pad)
	return servant ? get_turf(servant.shuttle) : null

// =========================================================================
// HARVEST SITES: arming, waypoints, pickup bookkeeping
// =========================================================================

/// Arms every un-collected harvest site (idempotent; start and gather both call it)
/datum/mission/drug_run/proc/arm_all_sites()
	for(var/datum/ingredient_site/site as anything in sites)
		site.arm()

/// source_key for a site's helm waypoint (per-site, so collection drops just one)
/datum/mission/drug_run/proc/site_waypoint_key(datum/ingredient_site/site)
	return "[REF(src)]-site-[REF(site)]"

/// Pushes (or refreshes) one un-collected site's harvest waypoint
/datum/mission/drug_run/proc/push_site_waypoint(datum/ingredient_site/site)
	if(!servant || site.collected || !site.site_target)
		return
	servant.add_waypoint(site_waypoint_key(site), "Harvest: [site.ingredient_name]", site.site_target.target_x, site.site_target.target_y, "Missions")

/datum/mission/drug_run/proc/push_site_waypoints()
	for(var/datum/ingredient_site/site as anything in sites)
		push_site_waypoint(site)

/// Drops one site's waypoint (collected / cleanup)
/datum/mission/drug_run/proc/drop_site_waypoint(datum/ingredient_site/site)
	servant?.remove_waypoint(site_waypoint_key(site))

/**
 * Uploads this mission's beacons to a handheld GPS unit (player tapped the
 * unit on the mission board): the batch itself once cooked (base machinery),
 * plus every live harvest site under a per-site tag. Sites whose planet
 * hasn't loaded have no surface position yet, their beacon uploads when
 * the scene spawns (watch_item).
 */
/datum/mission/drug_run/link_gps_unit(datum/component/gps/item/gps_unit)
	. = ..()
	if(failed || completed || !gps_unit)
		return
	for(var/datum/ingredient_site/site as anything in sites)
		if(site.collected)
			continue
		var/obj/item/drug_ingredient/ingredient = site.item_ref?.resolve()
		if(ingredient)
			gps_unit.add_mission_signal(site_gps_tag(site), ingredient)

/// GPS beacon tag for one site (per-site, so collection drops just one)
/datum/mission/drug_run/proc/site_gps_tag(datum/ingredient_site/site)
	return "Harvest: [site.ingredient_name]"

/// Pushes (or retargets) one un-collected site's beacon on every linked GPS unit
/datum/mission/drug_run/proc/push_site_gps_signal(datum/ingredient_site/site)
	if(site.collected)
		return
	var/obj/item/drug_ingredient/ingredient = site.item_ref?.resolve()
	if(!ingredient)
		return
	for(var/datum/weakref/unit_ref as anything in linked_gps_units)
		var/datum/component/gps/item/unit = unit_ref.resolve()
		if(!unit)
			linked_gps_units -= unit_ref
			continue
		unit.add_mission_signal(site_gps_tag(site), ingredient)

/// Drops one site's beacon from every linked GPS unit (collected / cleanup)
/datum/mission/drug_run/proc/drop_site_gps_signal(datum/ingredient_site/site)
	for(var/datum/weakref/unit_ref as anything in linked_gps_units)
		var/datum/component/gps/item/unit = unit_ref.resolve()
		unit?.remove_mission_signal(site_gps_tag(site))

/// A site's ingredient was picked up: drop its marker, nudge the gather step
/datum/mission/drug_run/proc/on_site_collected(datum/ingredient_site/site)
	drop_site_waypoint(site)
	drop_site_gps_signal(site)
	servant?.ship_notify("[site.ingredient_name] secured ([count_collected_sites()]/[length(sites)]).", "DRUG RUN", SHIP_NOTIFY_NOTICE, 'voidcrew/sound/notify2.ogg', 25)
	gather?.check_progress()

/// How many harvest sites have had their ingredient picked up
/datum/mission/drug_run/proc/count_collected_sites()
	. = 0
	for(var/datum/ingredient_site/site as anything in sites)
		if(site.collected)
			.++

// =========================================================================
// THE COOK: purity payout, product hand-off, the customs roll
// =========================================================================

/**
 * The batch is cooked (the lab session calls this after setting purity_tier).
 * Applies the purity payout, advances past the cook step, prints the product
 * (at `product_turf`, the session passes a tile beside the crystallizer when
 * the lab is loaded), and rolls the customs patrol.
 */
/datum/mission/drug_run/proc/on_cook_finished(turf/product_turf)
	if(failed || completed || !cook || cook.completed)
		return
	switch(purity_tier)
		if(DRUG_PURITY_STREET)
			value = round(value * DRUG_PAYOUT_MULT_STREET, 10)
		if(DRUG_PURITY_PRIMO)
			value = round(value * DRUG_PAYOUT_MULT_PRIMO, 10)
			voucher_count += 1
		else
			value = round(value * DRUG_PAYOUT_MULT_PURE, 10)
	cook.complete()
	spawn_product(product_turf)
	if(failed || QDELETED(src))
		return
	// The cook lights up somebody's sensor net
#ifdef DRUG_COP_FORCE_ROLL
	dispatch_patrol()
#else
	if(prob(DRUG_COP_CHANCE))
		dispatch_patrol()
#endif

/**
 * Prints the finished batch. `preferred_turf` is where the cook physically
 * ended, the lab session passes a tile beside its crystallizer machine when
 * the lab interior is loaded; with no preference (lab unloaded mid-finish)
 * the batch falls back to the ship's pad, the courier-pod precedent. The
 * product IS a quest atom: losing it after the cook voids the contract
 * (FAIL policy), that includes leaving it behind in a lab that unloads.
 */
/datum/mission/drug_run/proc/spawn_product(turf/preferred_turf)
	var/turf/product_turf = preferred_turf || get_pad_turf()
	if(!product_turf)
		fail("Nowhere to deliver the finished batch, contract void.")
		return
	var/obj/item/mission_recovery/drug_product/product = new(product_turf)
	product.configure(recipe, purity_tier)
	bind_item(product)
	register_quest_atom(product)
	if(preferred_turf)
		servant?.ship_notify("The batch of [recipe.street_name] is packaged. Collect it from the crystallization chamber and get it to Vex's counter. Don't leave it behind.", "DRUG RUN", SHIP_NOTIFY_NOTICE, 'voidcrew/sound/notify.ogg', 50)
	else
		servant?.ship_notify("The batch of [recipe.street_name] is packaged and delivered to your mission pad. Get it to Vex's counter.", "DRUG RUN", SHIP_NOTIFY_NOTICE, 'voidcrew/sound/notify.ogg', 50)

/**
 * The cook tripped somebody's sensor net: an NT customs corvette spawns near
 * the servant and runs the full shakedown, hail, fine (or surrender the
 * contraband), interdiction and boarding on refusal. The shuttle load can
 * sleep, and this is reached from the crystallizer's ui_act, so the actual
 * dispatch runs async.
 */
/datum/mission/drug_run/proc/dispatch_patrol()
	if(!servant || patrol)
		return
	var/fine = clamp(round(value * DRUG_COP_FINE_FRACTION, 100), DRUG_COP_FINE_MIN, DRUG_COP_FINE_MAX)
	INVOKE_ASYNC(src, PROC_REF(do_dispatch_patrol), fine)

/datum/mission/drug_run/proc/do_dispatch_patrol(fine)
	patrol = dispatch_nt_patrol(
		servant,
		fine,
		list(/obj/item/mission_recovery/drug_product, 1, "the contraband shipment"),
	)
	if(!patrol)
		// No clear spawn turf or the shuttle load failed. The crew gets away clean
		message_admins("Drug run '[name]': customs patrol roll hit but dispatch failed; no patrol this run.")

// =========================================================================
// INGREDIENT SITE: one recipe ingredient's spot in the wild
// =========================================================================

/**
 * One harvest site: pinned to the planet type that grows its ingredient,
 * field-spawning a small scene when that planet's interior loads, and
 * reporting the pickup back to the mission. Ingredients are NOT quest atoms:
 * an un-collected one that's destroyed burns the site's single respawn, then
 * the contract; one destroyed after pickup is the crew's own problem.
 */
/datum/ingredient_site
	/// The drug run this site belongs to
	var/datum/mission/drug_run/mission
	/// /obj/item/drug_ingredient subtype growing here
	var/ingredient_type
	/// Display name of the ingredient
	var/ingredient_name
	/// /datum/overmap/planet typepath the ingredient grows on
	var/biome
	/// The pinned planet target (resolved at mission generation)
	var/datum/mission_target/planet/ingredient_site/site_target
	/// Whether the harvest scene is placed at the current interior load
	var/spawned = FALSE
	/// Whether the crew has picked the ingredient up
	var/collected = FALSE
	/// The live field ingredient, while one is out
	var/datum/weakref/item_ref
	/// In-place replacements left before a destroyed ingredient voids the run
	var/respawns_left = 1
	/// Guard so notify_when_loaded() is never double-registered
	var/awaiting_load = FALSE

/datum/ingredient_site/New(datum/mission/drug_run/mission, list/entry)
	..()
	src.mission = mission
	ingredient_type = entry["type"]
	ingredient_name = entry["name"]
	biome = entry["biome"]

/datum/ingredient_site/Destroy()
	release_item(delete_uncollected = TRUE)
	QDEL_NULL(site_target)
	mission = null
	return ..()

/**
 * Pins this site to its planet. Called once at mission generation; FALSE
 * fails the whole mission's generation (no planet, no contract).
 */
/datum/ingredient_site/proc/resolve_target()
	site_target = new(mission)
	site_target.owner = src
	site_target.wanted_planet = biome
	if(!site_target.resolve())
		QDEL_NULL(site_target)
		return FALSE
	return TRUE

/**
 * Spawns now if the planet's interior is up, otherwise waits for it to load.
 * Idempotent: mission start and the gather objective both call it.
 */
/datum/ingredient_site/proc/arm()
	if(spawned || collected || !site_target?.is_valid())
		return
	if(site_target.is_interior_loaded())
		spawn_scene()
	else if(!awaiting_load)
		awaiting_load = TRUE
		site_target.notify_when_loaded()

/// The pinned planet's interior just loaded (relayed by the site target)
/datum/ingredient_site/proc/on_site_loaded()
	awaiting_load = FALSE
	if(!spawned && !collected)
		spawn_scene()

/**
 * Places the harvest scene: the stash prop, the ingredient beside it, some
 * camp litter, and one small wildlife pack on guard.
 */
/datum/ingredient_site/proc/spawn_scene()
	var/turf/scene_turf = site_target?.get_spawn_turf()
	if(!scene_turf)
		// Interior reported loaded but offered no clear ground; try next load
		awaiting_load = TRUE
		site_target?.notify_when_loaded()
		return
	spawned = TRUE
	new /obj/structure/ingredient_cache(scene_turf)
	var/obj/item/drug_ingredient/ingredient = new ingredient_type(get_nearby_open_turf(scene_turf))
	watch_item(ingredient)
	// Dressing: a cold cook-fire and a windbreak from the last crew through
	new /obj/structure/bonfire(get_nearby_open_turf(scene_turf, 2))
	new /obj/structure/barricade/wooden/crude(get_nearby_open_turf(scene_turf, 2))
	// The local wildlife has opinions about the smell
	new /obj/effect/zone_mobs/wildlife(scene_turf, list(1, 2))
	mission?.servant?.ship_notify("Harvest site located: [ingredient_name] at ([site_target.target_x], [site_target.target_y]).", "DRUG RUN", SHIP_NOTIFY_NOTICE, 'voidcrew/sound/notify2.ogg', 25)

/// Tracks a live field ingredient for pickup and destruction
/datum/ingredient_site/proc/watch_item(obj/item/drug_ingredient/ingredient)
	item_ref = WEAKREF(ingredient)
	// STORED too: scooping the specimen straight off the ground into a bag
	// never fires PICKUP, and the site must count either as collection
	RegisterSignals(ingredient, list(COMSIG_ITEM_PICKUP, COMSIG_ITEM_STORED), PROC_REF(on_collected))
	RegisterSignal(ingredient, COMSIG_QDELETING, PROC_REF(on_ingredient_deleted))
	// Fresh specimen in the field: (re)upload its beacon to every linked GPS
	mission?.push_site_gps_signal(src)

/// The crew picked the ingredient up (hand or bag): the site is done
/datum/ingredient_site/proc/on_collected(obj/item/source)
	SIGNAL_HANDLER
	if(collected)
		return
	collected = TRUE
	// From here the ingredient is ordinary cargo: destroying it is the
	// crew's loss, not a contract event (quest-atom rules never applied)
	UnregisterSignal(source, list(COMSIG_ITEM_PICKUP, COMSIG_ITEM_STORED, COMSIG_QDELETING))
	mission?.on_site_collected(src)

/**
 * An un-collected field ingredient is being destroyed. Lava, weather and
 * wildlife get one free pass (an in-place respawn); a site despawning with
 * the planet interior just re-arms the scene for the next landing; after
 * that the trail is dead and the contract dies with it.
 */
/datum/ingredient_site/proc/on_ingredient_deleted(obj/item/source)
	SIGNAL_HANDLER
	item_ref = null
	if(collected || !mission || mission.failed || mission.completed)
		return
	// The interior is unloading (or never counted as loaded): not a loss,
	// the scene respawns fresh, guards and all, on the next landing.
	// `concerned` is the only reliable teardown marker: planets keep `loaded`
	// and `mapzone` set while clear_reservation() qdels their contents.
	var/obj/structure/overmap/planet/site_planet = site_target?.planet
	if(!site_planet || site_planet.concerned || !site_target.is_interior_loaded())
		spawned = FALSE
		if(!awaiting_load && site_target?.is_valid())
			awaiting_load = TRUE
			site_target.notify_when_loaded()
		return
	if(respawns_left > 0)
		var/turf/retry_turf = site_target.get_spawn_turf()
		if(retry_turf)
			respawns_left--
			var/obj/item/drug_ingredient/replacement = new ingredient_type(retry_turf)
			watch_item(replacement)
			mission.servant?.ship_notify("The [ingredient_name] was destroyed. Scans found one more specimen nearby. Don't waste it.", "DRUG RUN", SHIP_NOTIFY_WARNING, 'voidcrew/sound/notify2.ogg', 50)
			return
		// Loaded but no clear ground to regrow on: treat it like an unload
		spawned = FALSE
		if(!awaiting_load)
			awaiting_load = TRUE
			site_target.notify_when_loaded()
		return
	mission.fail("The last [ingredient_name] on [site_target?.planet?.name || "the planet"] was destroyed, the formula is short an ingredient. Contract void.")

/**
 * The pinned planet itself died. One planet of each type flies per round, so
 * there is nowhere to re-pin. The contract is void (FAIL policy).
 */
/datum/ingredient_site/proc/on_site_lost()
	if(!mission || mission.failed || mission.completed)
		return
	mission.fail("The planet growing the [ingredient_name] is gone. The formula can't be filled. Contract void.")

/// The pinned planet relocated after unloading: move the helm marker with it
/datum/ingredient_site/proc/on_site_moved()
	if(!mission || collected)
		return
	if(mission.active)
		mission.push_site_waypoint(src)

/// Stops watching the live field ingredient; optionally removes it outright
/datum/ingredient_site/proc/release_item(delete_uncollected = FALSE)
	var/obj/item/drug_ingredient/ingredient = item_ref?.resolve()
	item_ref = null
	if(!ingredient)
		return
	UnregisterSignal(ingredient, list(COMSIG_ITEM_PICKUP, COMSIG_ITEM_STORED, COMSIG_QDELETING))
	if(delete_uncollected && !collected)
		qdel(ingredient)

/// Open turfs near the scene anchor (the field objective's scatter helper)
/datum/ingredient_site/proc/get_nearby_open_turf(turf/around, radius = 1)
	var/list/open_turfs = list()
	for(var/turf/open/tile in RANGE_TURFS(radius, around))
		if(!tile.is_blocked_turf(exclude_mobs = TRUE))
			open_turfs += tile
	return length(open_turfs) ? pick(open_turfs) : around
