/** Behavioral coverage for the Roost, Comb, Loom and Shambles trials. */

/datum/unit_test/vestige_hunt_quarry_safety/Run()
	var/mob/living/carbon/human/keeper = allocate(/mob/living/carbon/human/consistent)
	var/mob/living/basic/carp/beast = allocate(/mob/living/basic/carp)
	TEST_ASSERT(vestige_is_wild_quarry(beast, keeper), "Ordinary wild carp must remain available to a solo hunter.")
	TEST_ASSERT(vestige_comb_quarry(beast, keeper), "The Comb must accept ordinary wild carp.")
	TEST_ASSERT(vestige_is_shambles_quarry(beast, keeper), "The Shambles must accept ordinary wild carp.")
	beast.mind_initialize()
	TEST_ASSERT(!vestige_is_wild_quarry(beast, keeper), "A player-controlled animal must not count as wild quarry.")
	TEST_ASSERT(!vestige_comb_quarry(beast, keeper), "The Comb must reject a minded animal.")
	TEST_ASSERT(!vestige_is_shambles_quarry(beast, keeper), "The Shambles must reject a minded animal.")
	TEST_ASSERT(!vestige_loom_is_wild_quarry(beast, keeper), "The Pantry must never take a player animal.")

/datum/unit_test/vestige_pantry_capture/Run()
	var/mob/living/carbon/human/keeper = allocate(/mob/living/carbon/human/consistent)
	keeper.mind_initialize()
	var/datum/vestige_trial/loom_pantry/trial = allocate(/datum/vestige_trial/loom_pantry, keeper.mind)
	keeper.mind.active_vestige_trial = trial
	var/mob/living/basic/carp/beast = allocate(/mob/living/basic/carp)
	var/obj/structure/spider/stickyweb/ordinary_web = allocate(/obj/structure/spider/stickyweb)
	TEST_ASSERT(!vestige_loom_is_held_fast(beast), "Merely standing on ordinary probabilistic webbing is not sustained restraint.")
	qdel(ordinary_web)
	var/obj/structure/spider/stickyweb/vestige_capture/web = allocate(/obj/structure/spider/stickyweb/vestige_capture)
	web.bound_mind = keeper.mind
	trial.capture_web = web
	TEST_ASSERT(web.try_capture(beast), "The supplied trap must capture ordinary carp without a previous boon.")
	TEST_ASSERT(vestige_loom_is_held_fast(beast), "The loaned trap must satisfy the actual wrap continuation predicate.")
	var/datum/status_effect/hold = beast.has_status_effect(/datum/status_effect/incapacitating/paralyzed/vestige_pantry)
	TEST_ASSERT(hold && hold.duration >= world.time + 4 SECONDS, "The hold must leave enough time to finish a four-second wrap.")
	TEST_ASSERT(!web.try_capture(keeper), "The trap must not capture people.")
	var/obj/structure/vestige_silk_cocoon/cocoon = allocate(/obj/structure/vestige_silk_cocoon)
	cocoon.swaddle(beast, keeper.mind)
	trial.cocoons += cocoon
	TEST_ASSERT_EQUAL(beast.loc, cocoon, "Wrapping must transport a live animal into the cocoon.")
	qdel(web)
	TEST_ASSERT(!beast.has_status_effect(/datum/status_effect/incapacitating/paralyzed/vestige_pantry), "Deleting the trap must remove only its own restraint.")
	qdel(cocoon)
	TEST_ASSERT_EQUAL(beast.loc, run_loc_floor_bottom_left, "An abandoned cocoon must release its animal onto the floor.")
	TEST_ASSERT(beast.stat != DEAD, "An abandoned capture must release its animal alive.")
	TEST_ASSERT(!HAS_TRAIT_FROM(beast, TRAIT_AI_PAUSED, REF(cocoon)), "Release must remove the cocoon's AI pause.")

/datum/unit_test/vestige_hunt_connected_approach/Run()
	var/turf/center = get_step(get_step(run_loc_floor_bottom_left, NORTH), EAST)
	var/obj/structure/vestige_comb_egg/egg = allocate(/obj/structure/vestige_comb_egg, center)
	TEST_ASSERT(length(vestige_hunt_approaches(egg, 4)), "An open room must offer connected approaches three tiles from the objective.")
	var/list/walls = list()
	for(var/direction in GLOB.cardinals)
		walls += allocate(/obj/structure/vestige_comb_resin, get_step(center, direction))
	TEST_ASSERT(!length(vestige_hunt_approaches(egg, 4)), "A sealed objective must never fall back to spawning attackers on itself.")
	TEST_ASSERT(length(vestige_hunt_approaches(egg, 4, chew_resin = TRUE)), "Comb chewers may approach through destructible trial resin.")
	var/obj/structure/vestige_comb_resin/wall = walls[1]
	var/mob/living/basic/hivebot/vestige_comb_chewer/cutter = allocate(/mob/living/basic/hivebot/vestige_comb_chewer)
	for(var/bite in 1 to 8)
		wall.take_damage(cutter.obj_damage, BRUTE, MELEE)
	TEST_ASSERT(!QDELETED(wall) && wall.atom_integrity > 0, "A resin wall must survive several real cutter bites so rebuilding can matter.")

/datum/unit_test/vestige_hunt_expiry_is_not_victory/Run()
	var/obj/structure/vestige_dragon_egg/dragon_egg = allocate(/obj/structure/vestige_dragon_egg)
	dragon_egg.assault_underway = TRUE
	dragon_egg.stage = 3
	var/mob/living/basic/carp/vestige_brood/carp = allocate(/mob/living/basic/carp/vestige_brood)
	dragon_egg.enlist(carp)
	qdel(carp)
	TEST_ASSERT_EQUAL(dragon_egg.stage, 2, "A despawned last-wave carp must require that wave again.")
	TEST_ASSERT(!dragon_egg.hatching, "Waiting for an attacker's lifespan must not finish Broodwatch.")
	var/obj/structure/vestige_comb_egg/comb_egg = allocate(/obj/structure/vestige_comb_egg)
	comb_egg.assault_underway = TRUE
	comb_egg.squads_landed = 4
	var/mob/living/basic/hivebot/vestige_comb_chewer/cutter = allocate(/mob/living/basic/hivebot/vestige_comb_chewer)
	comb_egg.enlist(cutter)
	qdel(cutter)
	TEST_ASSERT_EQUAL(comb_egg.squads_landed, 3, "A vanished final gang must be replayed.")
	TEST_ASSERT(!comb_egg.hatching, "Waiting for cutters to expire must not finish Warm Season.")

/datum/unit_test/vestige_census_distinct_behaviors/Run()
	var/mob/living/carbon/human/keeper = allocate(/mob/living/carbon/human/consistent)
	keeper.mind_initialize()
	var/datum/vestige_trial/comb_census/trial = allocate(/datum/vestige_trial/comb_census, keeper.mind)
	keeper.mind.active_vestige_trial = trial
	var/obj/item/vestige_census_stinger/stinger = allocate(/obj/item/vestige_census_stinger)
	var/mob/living/basic/carp/beast = allocate(/mob/living/basic/carp, run_loc_floor_top_right)
	beast.ai_controller.set_blackboard_key(BB_BASIC_MOB_CURRENT_TARGET, keeper)
	TEST_ASSERT_EQUAL(stinger.observed_behavior(beast), "pursuit", "Distant active pursuit must have a readable observation.")
	TEST_ASSERT(trial.tally(beast, "pursuit"), "First pursuit should count.")
	TEST_ASSERT(!trial.tally(beast, "pursuit"), "Repeated shots during the same behavior must not count again.")
	beast.forceMove(get_step(keeper, NORTH))
	TEST_ASSERT_EQUAL(stinger.observed_behavior(beast), "commitment", "Close commitment must be distinct from distant pursuit.")
	TEST_ASSERT(trial.tally(beast, "commitment"), "A different behavior from the same quarry should count.")
	TEST_ASSERT_EQUAL(trial.entries, 2, "One beast must contribute exactly two distinct behaviors.")

/datum/unit_test/vestige_hunt_helper_marks/Run()
	var/mob/living/carbon/human/keeper = allocate(/mob/living/carbon/human/consistent)
	keeper.mind_initialize()
	var/datum/vestige_trial/ember_feast/fire_trial = allocate(/datum/vestige_trial/ember_feast, keeper.mind)
	keeper.mind.active_vestige_trial = fire_trial
	var/obj/item/vestige_ember_jaw/jaw = allocate(/obj/item/vestige_ember_jaw)
	var/mob/living/basic/carp/fire_prey = allocate(/mob/living/basic/carp)
	fire_prey.on_fire = TRUE
	jaw.mark_prey(fire_prey, keeper.mind)
	fire_prey.death()
	TEST_ASSERT_EQUAL(length(fire_trial.devoured), 1, "A death while marked must credit the hunter regardless of final-blow source.")
	TEST_ASSERT(!fire_trial.savor(fire_prey), "The same corpse must not count twice.")
	qdel(fire_trial)
	var/datum/vestige_trial/boiling_kiss/acid_trial = allocate(/datum/vestige_trial/boiling_kiss, keeper.mind)
	keeper.mind.active_vestige_trial = acid_trial
	var/obj/item/vestige_kiss_maw/maw = allocate(/obj/item/vestige_kiss_maw)
	maw.bound_mind = keeper.mind
	acid_trial.maw = maw
	var/mob/living/basic/carp/acid_prey = allocate(/mob/living/basic/carp)
	acid_prey.apply_status_effect(/datum/status_effect/vestige_kiss_corrosion)
	maw.mark_prey(acid_prey, keeper.mind)
	acid_prey.death()
	TEST_ASSERT_EQUAL(length(acid_trial.dissolved), 1, "A helper's kill during corrosion must count.")
	var/mob/living/basic/carp/dry_prey = allocate(/mob/living/basic/carp)
	dry_prey.apply_status_effect(/datum/status_effect/vestige_kiss_corrosion)
	maw.mark_prey(dry_prey, keeper.mind)
	dry_prey.remove_status_effect(/datum/status_effect/vestige_kiss_corrosion)
	dry_prey.death()
	TEST_ASSERT_EQUAL(length(acid_trial.dissolved), 1, "A death after the acid dries must not count.")
	var/mob/living/basic/carp/impact_prey = allocate(/mob/living/basic/carp, run_loc_floor_top_right)
	impact_prey.health = 4
	var/obj/projectile/vestige_kiss_glob/glob = allocate(/obj/projectile/vestige_kiss_glob)
	glob.aim_projectile(impact_prey, keeper, list())
	glob.firer = keeper
	glob.fired_from = maw
	impact_prey.bullet_act(glob, BODY_ZONE_CHEST)
	TEST_ASSERT_EQUAL(length(acid_trial.dissolved), 2, "A lethal first acid impact must preserve the mark-before-damage ordering.")
