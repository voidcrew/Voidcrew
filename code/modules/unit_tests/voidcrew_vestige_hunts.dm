/** Behavioral coverage for the Roost, Comb, Loom and Shambles trials. */

/// A stolen deployment kit must not replace the thief's own objective or consume its owner's kit.
/datum/unit_test/vestige_hunt_deployment_binding/Run()
	var/mob/living/carbon/human/keeper = allocate(/mob/living/carbon/human/consistent)
	var/mob/living/carbon/human/other_keeper = allocate(/mob/living/carbon/human/consistent)
	keeper.mind_initialize()
	other_keeper.mind_initialize()
	var/turf/ground = get_step(run_loc_floor_bottom_left, NORTH)
	var/list/kits = list(
		list(/datum/vestige_trial/broodwatch, /obj/item/vestige_dragon_egg, "egg_item"),
		list(/datum/vestige_trial/warm_season, /obj/item/vestige_comb_egg, "egg_item"),
		list(/datum/vestige_trial/loom_pantry, /obj/item/vestige_larder_bundle, "bundle"),
		list(/datum/vestige_trial/set_the_table, /obj/item/vestige_gambrel, "gambrel_item"),
	)
	for(var/list/kit_spec as anything in kits)
		var/datum/vestige_trial/keeper_trial = allocate(kit_spec[1], keeper.mind)
		var/datum/vestige_trial/other_trial = allocate(kit_spec[1], other_keeper.mind)
		keeper.mind.active_vestige_trial = keeper_trial
		other_keeper.mind.active_vestige_trial = other_trial
		var/obj/item/kit = allocate(kit_spec[2])
		kit.vars["bound_mind"] = keeper.mind
		keeper_trial.vars[kit_spec[3]] = kit
		keeper_trial.register_loan(kit)
		other_keeper.put_in_hands(kit)
		TEST_ASSERT_EQUAL(kit.interact_with_atom(ground, other_keeper, list()), ITEM_INTERACT_BLOCKING, "Another keeper's matching trial must not authorize this [kit.type] for deployment.")
		TEST_ASSERT(!QDELETED(kit), "Refusing a stolen [kit.type] must preserve its original owner's equipment.")
		TEST_ASSERT_EQUAL(keeper_trial.vars[kit_spec[3]], kit, "Refusing deployment must preserve the original trial's item pointer.")
		qdel(keeper_trial)
		qdel(other_trial)

/// A captured animal can acquire a player after wrapping; neither racking nor cleanup may erase them.
/datum/unit_test/vestige_pantry_late_mind/Run()
	var/mob/living/carbon/human/keeper = allocate(/mob/living/carbon/human/consistent)
	keeper.mind_initialize()
	var/datum/vestige_trial/loom_pantry/trial = allocate(/datum/vestige_trial/loom_pantry, keeper.mind)
	keeper.mind.active_vestige_trial = trial
	var/obj/structure/vestige_larder_rack/rack = allocate(/obj/structure/vestige_larder_rack)
	rack.bound_mind = keeper.mind
	trial.rack = rack
	var/mob/living/basic/carp/beast = allocate(/mob/living/basic/carp)
	var/obj/structure/vestige_silk_cocoon/parcel = allocate(/obj/structure/vestige_silk_cocoon)
	parcel.swaddle(beast, keeper.mind)
	trial.cocoons += parcel
	beast.mind_initialize()
	rack.tend(keeper)
	TEST_ASSERT_EQUAL(trial.stocked, 0, "A beast that gained a mind inside the cocoon must not stock the Pantry.")
	TEST_ASSERT(!QDELETED(beast), "Racking must release a newly minded captive rather than delete it.")
	TEST_ASSERT_EQUAL(beast.loc, run_loc_floor_bottom_left, "An ineligible captive must return to the floor.")
	TEST_ASSERT(!HAS_TRAIT(beast, TRAIT_AI_PAUSED), "Released captives must no longer carry the cocoon's AI pause.")
	var/obj/structure/vestige_silk_cocoon/forced_parcel = allocate(/obj/structure/vestige_silk_cocoon)
	forced_parcel.swaddle(beast, keeper.mind)
	forced_parcel.racked = TRUE
	qdel(forced_parcel)
	TEST_ASSERT(!QDELETED(beast), "Even racked cleanup must never delete a player-controlled captive.")
	TEST_ASSERT_EQUAL(beast.loc, run_loc_floor_bottom_left, "Racked cleanup must release an ineligible captive.")

/datum/unit_test/vestige_tremor_living_keeper/Run()
	var/mob/living/carbon/human/keeper = allocate(/mob/living/carbon/human/consistent)
	keeper.mind_initialize()
	var/datum/vestige_trial/loom_tremor/trial = allocate(/datum/vestige_trial/loom_tremor, keeper.mind)
	keeper.mind.active_vestige_trial = trial
	var/obj/structure/vestige_tremor_line/line = allocate(/obj/structure/vestige_tremor_line)
	var/mob/living/basic/vestige_silk_thief/thief = allocate(/mob/living/basic/vestige_silk_thief)
	trial.thieves[thief] = line
	keeper.death()
	trial.on_thief_died(thief)
	TEST_ASSERT_EQUAL(trial.answered, 0, "A keeper's nearby corpse cannot answer a tremor in person.")
	TEST_ASSERT_EQUAL(length(trial.thieves), 0, "An uncredited thief must still leave the active roster.")

/mob/living/basic/carp/vestige_ambush_test
	maxHealth = 100
	health = 100
	var/block_attacks = FALSE

/mob/living/basic/carp/vestige_ambush_test/check_block(atom/hit_by, damage, attack_text = "the attack", attack_type = MELEE_ATTACK, armour_penetration = 0, damage_type = BRUTE)
	return block_attacks || ..()

/mob/living/basic/carp/vestige_ambush_test/fragile
	maxHealth = 1
	health = 1
	basic_mob_flags = DEL_ON_DEATH

/// Set up an already qualified movement snapshot; attacks still use the real item/unarmed dispatch.
/datum/unit_test/vestige_trapdoor_attack_validation/proc/arm_ambush(datum/action/cooldown/spell/jaunt/bloodcrawl/vestige_trapdoor/crawl, mob/living/quarry)
	crawl.emerged_at = max(1, world.time)
	crawl.credited_this_rise = FALSE
	crawl.clear_snapshot(crawl.positions_at_rise)
	crawl.positions_at_rise = list()
	var/datum/vestige_trial/trapdoor_feast/trial = crawl.owner.mind.active_vestige_trial
	crawl.positions_at_rise[WEAKREF(quarry)] = trial.mark_turf(get_step(quarry, NORTH))

/datum/unit_test/vestige_trapdoor_attack_validation/Run()
	var/mob/living/carbon/human/keeper = allocate(/mob/living/carbon/human/consistent)
	keeper.mind_initialize()
	keeper.set_combat_mode(TRUE)
	var/datum/vestige_trial/trapdoor_feast/trial = allocate(/datum/vestige_trial/trapdoor_feast, keeper.mind)
	keeper.mind.active_vestige_trial = trial
	trial.on_accepted(keeper)
	var/mob/living/basic/carp/vestige_ambush_test/quarry = allocate(/mob/living/basic/carp/vestige_ambush_test, get_step(keeper, EAST))
	var/obj/item/knife/blade = allocate(/obj/item/knife)
	keeper.put_in_hands(blade)
	arm_ambush(trial.crawl, quarry)
	ADD_TRAIT(keeper, TRAIT_PACIFISM, TRAIT_GENERIC)
	blade.melee_attack_chain(keeper, quarry, list())
	TEST_ASSERT_EQUAL(trial.ambushes, 0, "A pacifist's rejected weapon attack must not count as an ambush.")
	REMOVE_TRAIT(keeper, TRAIT_PACIFISM, TRAIT_GENERIC)
	quarry.block_attacks = TRUE
	blade.melee_attack_chain(keeper, quarry, list())
	TEST_ASSERT_EQUAL(trial.ambushes, 0, "A blocked weapon attack must not count as an ambush.")
	quarry.block_attacks = FALSE
	blade.item_flags |= NOBLUDGEON
	blade.melee_attack_chain(keeper, quarry, list())
	TEST_ASSERT_EQUAL(trial.ambushes, 0, "A positive-force item that cannot bludgeon must not count merely because it was clicked.")
	blade.item_flags &= ~NOBLUDGEON
	quarry.damage_coeff[BRUTE] = 0
	blade.melee_attack_chain(keeper, quarry, list())
	TEST_ASSERT_EQUAL(trial.ambushes, 0, "A weapon hit causing no damage must not count.")
	quarry.damage_coeff[BRUTE] = 1
	blade.melee_attack_chain(keeper, quarry, list())
	TEST_ASSERT_EQUAL(trial.ambushes, 1, "An ordinary damaging weapon hit must count.")
	keeper.dropItemToGround(blade)
	arm_ambush(trial.crawl, quarry)
	ADD_TRAIT(keeper, TRAIT_PACIFISM, TRAIT_GENERIC)
	keeper.UnarmedAttack(quarry, TRUE, list())
	TEST_ASSERT_EQUAL(trial.ambushes, 1, "A pacifist's rejected punch must not count.")
	REMOVE_TRAIT(keeper, TRAIT_PACIFISM, TRAIT_GENERIC)
	quarry.block_attacks = TRUE
	keeper.UnarmedAttack(quarry, TRUE, list())
	TEST_ASSERT_EQUAL(trial.ambushes, 1, "A blocked punch must not count.")
	quarry.block_attacks = FALSE
	keeper.UnarmedAttack(quarry, TRUE, list(RIGHT_CLICK = TRUE))
	TEST_ASSERT_EQUAL(trial.ambushes, 1, "A right-click shove must not count as a landed ambush strike.")
	quarry.forceMove(get_step(keeper, EAST))
	arm_ambush(trial.crawl, quarry)
	var/obj/item/bodypart/hand = keeper.get_active_hand()
	hand.unarmed_damage_low = 5
	hand.unarmed_damage_high = 5
	keeper.UnarmedAttack(quarry, TRUE, list())
	TEST_ASSERT_EQUAL(trial.ambushes, 2, "An ordinary damaging punch must count.")

/datum/unit_test/vestige_trapdoor_attack_validation/lethal/Run()
	var/mob/living/carbon/human/keeper = allocate(/mob/living/carbon/human/consistent)
	keeper.mind_initialize()
	keeper.set_combat_mode(TRUE)
	var/datum/vestige_trial/trapdoor_feast/trial = allocate(/datum/vestige_trial/trapdoor_feast, keeper.mind)
	keeper.mind.active_vestige_trial = trial
	trial.on_accepted(keeper)
	var/mob/living/basic/carp/vestige_ambush_test/fragile/armed_quarry = allocate(/mob/living/basic/carp/vestige_ambush_test/fragile, get_step(keeper, EAST))
	var/obj/item/knife/blade = allocate(/obj/item/knife)
	keeper.put_in_hands(blade)
	arm_ambush(trial.crawl, armed_quarry)
	blade.melee_attack_chain(keeper, armed_quarry, list())
	TEST_ASSERT(QDELETED(armed_quarry), "The armed fixture must actually die and delete itself.")
	TEST_ASSERT_EQUAL(trial.ambushes, 1, "A lethal weapon hit must retain credit even when it deletes its quarry.")
	keeper.dropItemToGround(blade)
	var/mob/living/basic/carp/vestige_ambush_test/fragile/unarmed_quarry = allocate(/mob/living/basic/carp/vestige_ambush_test/fragile, get_step(keeper, EAST))
	arm_ambush(trial.crawl, unarmed_quarry)
	var/obj/item/bodypart/hand = keeper.get_active_hand()
	hand.unarmed_damage_low = 5
	hand.unarmed_damage_high = 5
	keeper.UnarmedAttack(unarmed_quarry, TRUE, list())
	TEST_ASSERT(QDELETED(unarmed_quarry), "The unarmed fixture must actually die and delete itself.")
	TEST_ASSERT_EQUAL(trial.ambushes, 2, "A lethal punch must retain credit even when it deletes its quarry.")

/datum/unit_test/vestige_trapdoor_moving_frame/Run()
	var/mob/living/carbon/human/keeper = allocate(/mob/living/carbon/human/consistent)
	keeper.mind_initialize()
	var/datum/vestige_trial/trapdoor_feast/trial = allocate(/datum/vestige_trial/trapdoor_feast, keeper.mind)
	keeper.mind.active_vestige_trial = trial
	trial.on_accepted(keeper)
	var/mob/living/basic/carp/quarry = allocate(/mob/living/basic/carp, get_step(keeper, EAST))
	var/obj/effect/vestige_trial_marker/position = trial.mark_turf(get_turf(quarry))
	trial.crawl.emerged_at = max(1, world.time)
	trial.crawl.positions_at_rise = list()
	trial.crawl.positions_at_rise[WEAKREF(quarry)] = position
	TEST_ASSERT(!trial.crawl.can_pounce(keeper, quarry), "Standing still after surfacing must not qualify.")
	var/turf/moved_floor = get_step(quarry, NORTH)
	position.forceMove(moved_floor)
	quarry.forceMove(moved_floor)
	TEST_ASSERT(!trial.crawl.can_pounce(keeper, quarry), "Moving the deck and quarry together must not manufacture quarry movement.")
	quarry.forceMove(get_step(moved_floor, WEST))
	TEST_ASSERT(trial.crawl.can_pounce(keeper, quarry), "A quarry that moves relative to the relocated deck must qualify.")

/datum/unit_test/vestige_red_road_landed_cut/Run()
	var/mob/living/carbon/human/keeper = allocate(/mob/living/carbon/human/consistent)
	keeper.mind_initialize()
	var/datum/vestige_trial/red_road/trial = allocate(/datum/vestige_trial/red_road, keeper.mind)
	keeper.mind.active_vestige_trial = trial
	trial.on_accepted(keeper)
	var/obj/item/vestige_flensing_knife/blade = trial.knife
	var/turf/quarry_floor = get_step(keeper, EAST)
	var/mob/living/basic/carp/vestige_ambush_test/quarry = allocate(/mob/living/basic/carp/vestige_ambush_test, quarry_floor)
	ADD_TRAIT(keeper, TRAIT_PACIFISM, TRAIT_GENERIC)
	blade.melee_attack_chain(keeper, quarry, list())
	TEST_ASSERT(!(locate(/obj/effect/decal/cleanable/blood) in quarry_floor), "A pacifist's refused cut must not create blood.")
	REMOVE_TRAIT(keeper, TRAIT_PACIFISM, TRAIT_GENERIC)
	quarry.block_attacks = TRUE
	blade.melee_attack_chain(keeper, quarry, list())
	TEST_ASSERT(!(locate(/obj/effect/decal/cleanable/blood) in quarry_floor), "A blocked cut must not create blood.")
	quarry.block_attacks = FALSE
	blade.melee_attack_chain(keeper, quarry, list())
	TEST_ASSERT(locate(/obj/effect/decal/cleanable/blood) in quarry_floor, "A real wound must still lay the blood needed by the trial.")
	var/mob/living/basic/carp/vestige_ambush_test/fragile/dry_quarry = allocate(/mob/living/basic/carp/vestige_ambush_test/fragile, get_turf(keeper))
	TEST_ASSERT(!(locate(/obj/effect/decal/cleanable/blood) in get_turf(keeper)), "The finishing-blow fixture must start with dry footing.")
	blade.melee_attack_chain(keeper, dry_quarry, list())
	TEST_ASSERT(QDELETED(dry_quarry), "The dry-footing fixture must actually die.")
	TEST_ASSERT_EQUAL(length(trial.felled), 0, "A killing blow must not retroactively qualify using blood it just created beneath the hunter.")
	var/mob/living/basic/carp/vestige_ambush_test/fragile/wet_quarry = allocate(/mob/living/basic/carp/vestige_ambush_test/fragile, get_step(keeper, NORTH))
	blade.melee_attack_chain(keeper, wet_quarry, list())
	TEST_ASSERT(QDELETED(wet_quarry), "The wet-footing fixture must actually delete itself on death.")
	TEST_ASSERT_EQUAL(length(trial.felled), 1, "A proper wet-footing kill must retain its pre-death identity and count.")

/datum/unit_test/vestige_table_forced_buckle/Run()
	var/mob/living/carbon/human/keeper = allocate(/mob/living/carbon/human/consistent)
	keeper.mind_initialize()
	var/datum/vestige_trial/set_the_table/trial = allocate(/datum/vestige_trial/set_the_table, keeper.mind)
	keeper.mind.active_vestige_trial = trial
	var/obj/structure/vestige_gambrel/rack = allocate(/obj/structure/vestige_gambrel)
	rack.bound_mind = keeper.mind
	trial.gambrel_structure = rack
	var/mob/living/basic/carp/quarry = allocate(/mob/living/basic/carp)
	TEST_ASSERT(rack.buckle_mob(quarry, force = TRUE), "The fixture must exercise actual forced buckling.")
	TEST_ASSERT_EQUAL(trial.settings, 0, "Forced buckling a living beast must not bypass the fresh-carcass requirement.")
	rack.unbuckle_mob(quarry, force = TRUE)
	quarry.mind_initialize()
	quarry.death()
	TEST_ASSERT(rack.buckle_mob(quarry, force = TRUE), "The second fixture must actually reach post_buckle_mob.")
	TEST_ASSERT_EQUAL(trial.settings, 0, "Forced buckling a player-controlled carcass must not award a setting.")

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
	TEST_ASSERT_EQUAL(trial.complete_profiles, 1, "Both behaviors form exactly one profile.")
	qdel(trial)
	var/datum/vestige_trial/comb_census/new_trial = allocate(/datum/vestige_trial/comb_census, keeper.mind, "test patron", list(/datum/vestige_boon/spell/armblade))
	keeper.mind.active_vestige_trial = new_trial
	var/list/single_sightings = list()
	for(var/i in 1 to 4)
		var/mob/living/basic/carp/sighting = allocate(/mob/living/basic/carp)
		single_sightings += sighting
		TEST_ASSERT(new_trial.tally(sighting, "pursuit"), "A new specimen may start a partial profile.")
	TEST_ASSERT_EQUAL(keeper.mind.active_vestige_trial, new_trial, "Four distant pursuits must not finish the Census.")
	TEST_ASSERT_EQUAL(new_trial.complete_profiles, 0, "Single-behavior sightings are incomplete regardless of their count.")
	qdel(single_sightings[1])
	TEST_ASSERT(new_trial.tally(single_sightings[2], "commitment"), "An abandoned dead specimen must not block finishing another profile.")
	TEST_ASSERT_EQUAL(new_trial.complete_profiles, 1, "One completed profile is still insufficient.")
	TEST_ASSERT(new_trial.tally(single_sightings[3], "commitment"), "A second complete profile must finish the Census.")
	TEST_ASSERT(/datum/vestige_trial/comb_census in keeper.mind.completed_vestige_trials, "Two distinct complete profiles must satisfy the actual trial.")

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
	impact_prey.adjustBruteLoss(impact_prey.maxHealth - 4)
	var/obj/projectile/vestige_kiss_glob/glob = allocate(/obj/projectile/vestige_kiss_glob)
	glob.aim_projectile(impact_prey, keeper, list())
	glob.firer = keeper
	glob.fired_from = maw
	impact_prey.bullet_act(glob, BODY_ZONE_CHEST)
	TEST_ASSERT_EQUAL(impact_prey.stat, DEAD, "The first impact must actually be lethal for this fixture.")
	TEST_ASSERT_EQUAL(length(acid_trial.dissolved), 2, "A lethal first acid impact must preserve the mark-before-damage ordering.")


/mob/living/carbon/human/consistent/vestige_spit_block_test
	var/block_spit = TRUE

/mob/living/carbon/human/consistent/vestige_spit_block_test/check_block(atom/hit_by, damage, attack_text = "the attack", attack_type = MELEE_ATTACK, armour_penetration = 0, damage_type = BRUTE)
	return block_spit || ..()

/// Human shield dispatch still calls on_hit at 100% block; the coating must respect it.
/datum/unit_test/vestige_vitriol_block/Run()
	var/mob/living/carbon/human/consistent/vestige_spit_block_test/target = allocate(/mob/living/carbon/human/consistent/vestige_spit_block_test)
	var/mob/living/carbon/human/consistent/spitter = allocate(/mob/living/carbon/human/consistent, run_loc_floor_top_right)
	var/obj/projectile/vestige_caustic_spit/vitriol/glob = allocate(/obj/projectile/vestige_caustic_spit/vitriol, get_turf(spitter))
	glob.aim_projectile(target, spitter, list())
	glob.firer = spitter
	target.bullet_act(glob, BODY_ZONE_CHEST)
	TEST_ASSERT(!target.has_status_effect(/datum/status_effect/vestige_vitriol_coating), "A fully shield-blocked glob must not put persistent acid on its target.")
	TEST_ASSERT_EQUAL(target.getFireLoss(), 0, "The fixture must use the actual full-block damage path.")
	TEST_ASSERT(locate(/obj/effect/vestige_vitriol_residue) in get_turf(target), "A shielded splash must still leave the existing floor residue.")
	var/obj/projectile/vestige_caustic_spit/vitriol/second_glob = allocate(/obj/projectile/vestige_caustic_spit/vitriol, get_turf(spitter))
	second_glob.aim_projectile(target, spitter, list())
	second_glob.firer = spitter
	target.block_spit = FALSE
	target.bullet_act(second_glob, BODY_ZONE_CHEST)
	TEST_ASSERT(target.has_status_effect(/datum/status_effect/vestige_vitriol_coating), "An unblocked hit must still coat the target.")
	TEST_ASSERT(target.getFireLoss() > 0, "An unblocked glob must still deliver its impact burn.")

// Keep the real builder channel while making the shape menu deterministic.
/datum/action/cooldown/spell/pointed/vestige_resin_weaver/vestige_hunt_test/pick_shape()
	return /obj/structure/alien/resin/wall

/datum/action/cooldown/spell/pointed/vestige_resin_weaver/architect/vestige_hunt_test/pick_shape()
	return /obj/structure/alien/resin/wall

/datum/unit_test/vestige_hunt_channel_transfer
	var/mob/living/replacement

/datum/unit_test/vestige_hunt_channel_transfer/proc/transfer_during_channel(mob/living/source)
	SIGNAL_HANDLER
	source.mind.transfer_to(replacement)

/// Do_after watches a body, while the real action follows its mind to another body.
/datum/unit_test/vestige_hunt_channel_transfer/Run()
	var/turf/center = get_step(get_step(run_loc_floor_bottom_left, NORTH), EAST)
	var/turf/ground = get_step(center, EAST)
	var/list/channels = list(
		list(/datum/action/cooldown/spell/pointed/vestige_resin_weaver/vestige_hunt_test, "channel_time", "weaving"),
		list(/datum/action/cooldown/spell/pointed/vestige_resin_weaver/architect/vestige_hunt_test, "channel_time", "weaving"),
		list(/datum/action/cooldown/spell/pointed/vestige_silk_spin, "spin_time", "spinning"),
		list(/datum/action/cooldown/spell/pointed/vestige_silk_spin/master_weaver, "spin_time", "spinning"),
		list(/datum/action/cooldown/spell/pointed/vestige_carrion_feast, "channel_time", "feeding"),
		list(/datum/action/cooldown/spell/pointed/vestige_carrion_feast/marrow, "channel_time", "feeding"),
	)
	for(var/list/spec as anything in channels)
		var/mob/living/carbon/human/consistent/user = allocate(/mob/living/carbon/human/consistent, center)
		user.mind_initialize()
		replacement = allocate(/mob/living/carbon/human/consistent, center)
		var/datum/action/cooldown/spell/pointed/spell = allocate(spec[1], user.mind)
		spell.Grant(user)
		spell.vars[spec[2]] = 0.2 SECONDS
		var/atom/cast_target = ground
		var/mob/living/basic/carp/meal
		if(istype(spell, /datum/action/cooldown/spell/pointed/vestige_carrion_feast))
			meal = allocate(/mob/living/basic/carp, ground)
			meal.death()
			cast_target = meal
		RegisterSignal(user, COMSIG_DO_AFTER_BEGAN, PROC_REF(transfer_during_channel))
		TEST_ASSERT(!spell.PreActivate(cast_target), "[spell.type] must cancel a channel when its caster changes bodies, even to an adjacent body.")
		UnregisterSignal(user, COMSIG_DO_AFTER_BEGAN)
		TEST_ASSERT_EQUAL(spell.owner, replacement, "The fixture must perform a real mind transfer of [spell.type].")
		TEST_ASSERT(!spell.vars[spec[3]], "Canceled [spell.type] must release its busy guard.")
		TEST_ASSERT(!HAS_TRAIT(ground, TRAIT_SPINNING_WEB_TURF), "An interrupted spin must remove its turf reservation.")
		TEST_ASSERT(!(locate(/obj/structure/alien/resin) in ground) && !(locate(/obj/structure/spider/stickyweb) in ground), "An abandoned channel must not create construction.")
		if(meal)
			TEST_ASSERT(!HAS_TRAIT(meal, "vestige_devoured"), "An abandoned feeding must leave its meal unclaimed.")
		TEST_ASSERT(spell.PreActivate(cast_target), "The new body must be able to begin a fresh [spell.type] channel.")
		if(meal)
			TEST_ASSERT(HAS_TRAIT(meal, "vestige_devoured"), "A fresh completed feeding must claim its meal.")
		else
			var/obj/structure/work = locate(/obj/structure/alien/resin) in ground
			if(!work)
				work = locate(/obj/structure/spider/stickyweb) in ground
			TEST_ASSERT(work, "A fresh completed construction channel must place its work.")
			qdel(work)
		qdel(spell)
		if(meal)
			qdel(meal)
		qdel(user)
		qdel(replacement)

/datum/unit_test/vestige_hunt_channel_reentrant
	var/datum/action/cooldown/spell/pointed/spell
	var/turf/other_ground
	var/reentrant_result

/datum/unit_test/vestige_hunt_channel_reentrant/proc/reenter_during_channel(mob/living/source)
	SIGNAL_HANDLER
	UnregisterSignal(source, COMSIG_DO_AFTER_BEGAN)
	reentrant_result = spell.before_cast(other_ground)

/datum/unit_test/vestige_hunt_channel_reentrant/Run()
	var/turf/center = get_step(get_step(run_loc_floor_bottom_left, NORTH), EAST)
	var/turf/ground = get_step(center, EAST)
	other_ground = get_step(center, NORTH)
	for(var/spell_type in list(/datum/action/cooldown/spell/pointed/vestige_resin_weaver/vestige_hunt_test, /datum/action/cooldown/spell/pointed/vestige_silk_spin))
		var/mob/living/carbon/human/consistent/user = allocate(/mob/living/carbon/human/consistent, center)
		user.mind_initialize()
		spell = allocate(spell_type, user.mind)
		spell.Grant(user)
		if(istype(spell, /datum/action/cooldown/spell/pointed/vestige_resin_weaver))
			spell.vars["channel_time"] = 0.2 SECONDS
		else
			spell.vars["spin_time"] = 0.2 SECONDS
		RegisterSignal(user, COMSIG_DO_AFTER_BEGAN, PROC_REF(reenter_during_channel))
		TEST_ASSERT(spell.PreActivate(ground), "The first construction must finish despite a concurrent activation attempt.")
		TEST_ASSERT(reentrant_result & SPELL_CANCEL_CAST, "An action must reject overlapping channels on distinct target tiles.")
		TEST_ASSERT(!(locate(/obj/structure/alien/resin) in other_ground) && !(locate(/obj/structure/spider/stickyweb) in other_ground), "Rejected reentry must not build a second work.")
		var/obj/structure/work = locate(/obj/structure/alien/resin) in ground
		if(!work)
			work = locate(/obj/structure/spider/stickyweb) in ground
		TEST_ASSERT(work, "Reentry must not clear the first cast's pending construction.")
		qdel(work)
		qdel(spell)
		qdel(user)

/datum/unit_test/vestige_claws_body_and_upgrade/Run()
	var/mob/living/carbon/human/consistent/user = allocate(/mob/living/carbon/human/consistent)
	user.mind_initialize()
	var/mob/living/carbon/human/consistent/replacement = allocate(/mob/living/carbon/human/consistent)
	var/datum/action/cooldown/spell/vestige_rending_claws/spell = allocate(/datum/action/cooldown/spell/vestige_rending_claws, user.mind)
	spell.Grant(user)
	TEST_ASSERT(spell.PreActivate(user), "The plain human must be able to grow the base claws.")
	var/obj/item/vestige_rending_claw/old_claw = locate() in user.held_items
	TEST_ASSERT(old_claw, "The actual cast must place claws in the owner's hand.")
	user.mind.transfer_to(replacement)
	TEST_ASSERT(QDELETED(old_claw), "Body transfer must reclaim the abandoned body's otherwise undismissable NODROP claws.")
	TEST_ASSERT_EQUAL(spell.owner, replacement, "The action must follow the real mind transfer.")
	spell.reset_spell_cooldown()
	TEST_ASSERT(spell.PreActivate(replacement), "The new body must be able to grow fresh claws.")
	var/obj/item/vestige_rending_claw/base_claw = locate() in replacement.held_items
	var/datum/vestige_boon/spell/rending_claws/butchers_rhythm/upgrade = allocate(/datum/vestige_boon/spell/rending_claws/butchers_rhythm)
	upgrade.grant(replacement, replacement.mind)
	TEST_ASSERT(QDELETED(base_claw), "Replacing the lesson must safely fold the old claws away.")
	var/datum/action/cooldown/spell/vestige_rending_claws/butchers/improved = locate() in replacement.actions
	TEST_ASSERT(improved && improved.PreActivate(replacement), "The upgraded action must grow its stronger claws normally.")
	var/obj/item/vestige_rending_claw/butchers/new_claw = locate() in replacement.held_items
	TEST_ASSERT(new_claw, "An upgrade must actually produce the butcher variant.")
	qdel(improved)
	TEST_ASSERT(QDELETED(new_claw), "Removing the final lesson must also remove its physical growth.")

/datum/unit_test/vestige_tremor_local_net/Run()
	var/mob/living/carbon/human/consistent/keeper = allocate(/mob/living/carbon/human/consistent)
	keeper.mind_initialize()
	var/datum/vestige_trial/loom_tremor/trial = allocate(/datum/vestige_trial/loom_tremor, keeper.mind)
	keeper.mind.active_vestige_trial = trial
	var/turf/remote = locate(1, 1, keeper.z == 1 ? 2 : 1)
	TEST_ASSERT(remote && remote.z != keeper.z, "The fixture needs an existing other z-level.")
	var/obj/structure/vestige_tremor_line/local_line = allocate(/obj/structure/vestige_tremor_line, get_step(keeper, NORTH))
	var/obj/structure/vestige_tremor_line/remote_one = allocate(/obj/structure/vestige_tremor_line, remote)
	var/obj/structure/vestige_tremor_line/remote_two = allocate(/obj/structure/vestige_tremor_line, remote)
	trial.lines = list(local_line, remote_one, remote_two)
	trial.check_night()
	TEST_ASSERT(!trial.night_begun, "One local line and two on another z-level must not wake a dispersed net.")
	trial.night_begun = TRUE
	trial.next_send_at = 0
	trial.loom_beat()
	TEST_ASSERT_EQUAL(length(trial.thieves), 0, "A previously started night must not send thieves against an undersized local net.")
	trial.night_begun = FALSE
	remote_one.forceMove(get_step(keeper, EAST))
	remote_two.forceMove(get_step(keeper, NORTHEAST))
	trial.check_night()
	TEST_ASSERT(trial.night_begun, "Three lines on the keeper's level must still wake the night.")
	trial.next_send_at = 0
	trial.loom_beat()
	TEST_ASSERT_EQUAL(length(trial.thieves), 1, "A whole local net must send a thief through the real heartbeat.")

/datum/unit_test/vestige_tremor_new_alarm/Run()
	var/mob/living/carbon/human/consistent/keeper = allocate(/mob/living/carbon/human/consistent)
	keeper.mind_initialize()
	var/datum/vestige_trial/loom_tremor/trial = allocate(/datum/vestige_trial/loom_tremor, keeper.mind)
	keeper.mind.active_vestige_trial = trial
	var/obj/structure/vestige_tremor_line/line = allocate(/obj/structure/vestige_tremor_line, get_step(keeper, NORTH))
	line.bound_mind = keeper.mind
	trial.lines += line
	line.pinged = TRUE
	trial.send_thief(line, keeper)
	TEST_ASSERT_EQUAL(length(trial.thieves), 1, "The fixture must send an actual thief against the previously bitten line.")
	TEST_ASSERT(!line.pinged, "A surviving line must reset its hard alarm for each new thief.")
	var/mob/living/basic/vestige_silk_thief/thief = trial.thieves[1]
	thief.forceMove(get_step(line, EAST))
	line.attack_basic_mob(thief)
	TEST_ASSERT(line.pinged, "The new thief's real first bite must ring the line again.")


/// Failed swings never build the consecutive-hit bonus, including real shields and pacifism.
/datum/unit_test/vestige_butcher_rhythm_landed_hits/Run()
	var/mob/living/carbon/human/consistent/user = allocate(/mob/living/carbon/human/consistent)
	user.set_combat_mode(TRUE)
	var/obj/item/vestige_rending_claw/butchers/claw = allocate(/obj/item/vestige_rending_claw/butchers)
	user.put_in_hands(claw)
	var/mob/living/basic/carp/vestige_ambush_test/quarry = allocate(/mob/living/basic/carp/vestige_ambush_test, get_step(user, EAST))
	quarry.maxHealth = 500
	quarry.health = 500
	ADD_TRAIT(user, TRAIT_PACIFISM, TRAIT_GENERIC)
	for(var/stroke in 1 to 4)
		claw.melee_attack_chain(user, quarry, list())
	TEST_ASSERT_EQUAL(claw.rhythm, 0, "Four pacifist refusals must not prepare a full rhythm.")
	TEST_ASSERT_NULL(claw.rhythm_prey, "A refused first swing must not begin a target's hit streak.")
	REMOVE_TRAIT(user, TRAIT_PACIFISM, TRAIT_GENERIC)
	quarry.block_attacks = TRUE
	for(var/stroke in 1 to 4)
		claw.melee_attack_chain(user, quarry, list())
	TEST_ASSERT_EQUAL(claw.rhythm, 0, "Four fully blocked swings must not build a rhythm.")
	TEST_ASSERT_EQUAL(quarry.health, 500, "The rejected swings must actually cause no damage.")
	quarry.block_attacks = FALSE
	quarry.damage_coeff[BRUTE] = 0
	claw.melee_attack_chain(user, quarry, list())
	TEST_ASSERT_NULL(claw.rhythm_prey, "An invulnerable target must not seed a damage streak either.")
	quarry.damage_coeff[BRUTE] = 1
	claw.melee_attack_chain(user, quarry, list())
	TEST_ASSERT_EQUAL(claw.rhythm, 0, "The first landed hit starts the same-target streak without a repeat bonus.")
	TEST_ASSERT_EQUAL(claw.rhythm_prey?.resolve(), quarry, "A real landed hit must record its target.")
	claw.melee_attack_chain(user, quarry, list())
	TEST_ASSERT_EQUAL(claw.rhythm, 5, "The second landed hit must gain one normal rhythm step.")
	quarry.block_attacks = TRUE
	claw.melee_attack_chain(user, quarry, list())
	TEST_ASSERT_EQUAL(claw.rhythm, 5, "A blocked follow-up must preserve, not advance, the successful-hit streak.")
	TEST_ASSERT_EQUAL(claw.wound_bonus, initial(claw.wound_bonus) + 5, "A rejected prospective bonus must not remain on the weapon.")
	quarry.block_attacks = FALSE
	for(var/stroke in 1 to 4)
		claw.melee_attack_chain(user, quarry, list())
	TEST_ASSERT_EQUAL(claw.rhythm, 15, "Successful repeated strikes must still reach and respect the existing cap.")
	var/mob/living/basic/carp/other = allocate(/mob/living/basic/carp, get_step(user, NORTH))
	claw.melee_attack_chain(user, other, list())
	TEST_ASSERT_EQUAL(claw.rhythm, 0, "A landed hit on a different living target must reset the rhythm.")
	TEST_ASSERT_EQUAL(claw.rhythm_prey?.resolve(), other, "The new target must become the start of the next streak.")

/// Complete Red Road with actual cuts, a moving quarry, and the blood those cuts create.
/datum/unit_test/vestige_red_road_complete_route/Run()
	var/mob/living/carbon/human/keeper = allocate(/mob/living/carbon/human/consistent)
	keeper.mind_initialize()
	var/datum/mind/hunter_mind = keeper.mind
	var/datum/vestige_trial/red_road/trial = allocate(/datum/vestige_trial/red_road, hunter_mind, "Test Stain", list(/datum/vestige_boon/spell/rending_claws))
	hunter_mind.active_vestige_trial = trial
	trial.on_accepted(keeper)
	var/obj/item/vestige_flensing_knife/knife = trial.knife
	for(var/meal in 1 to 3)
		var/turf/cut_floor = get_step(keeper, EAST)
		var/mob/living/basic/carp/quarry = allocate(/mob/living/basic/carp, cut_floor)
		ADD_TRAIT(quarry, TRAIT_AI_PAUSED, TRAIT_GENERIC)
		knife.melee_attack_chain(keeper, quarry, list())
		TEST_ASSERT(quarry.stat != DEAD, "The first ordinary cut must leave a live beast to pursue.")
		var/obj/effect/decal/cleanable/blood/pool = locate() in cut_floor
		TEST_ASSERT(pool && !pool.dried, "The real initial cut must create wet footing.")
		TEST_ASSERT(step(quarry, NORTH), "The wounded beast must actually move off the painted floor.")
		TEST_ASSERT(keeper.Move(cut_floor, EAST), "The hunter must walk onto the real blood.")
		knife.attack_self(keeper)
		knife.melee_attack_chain(keeper, quarry, list())
		TEST_ASSERT_EQUAL(quarry.stat, DEAD, "The second real knife cut must kill the ordinary carp.")
		TEST_ASSERT_EQUAL(length(trial.felled), meal, "Each actual wet-footing kill must enter the ledger.")
	var/deadline = world.time + 3 SECONDS
	while(!QDELETED(trial) && world.time < deadline)
		sleep(world.tick_lag)
	TEST_ASSERT(/datum/vestige_trial/red_road in hunter_mind.completed_vestige_trials, "Three real wet-footing kills must complete through the scheduled conclusion.")
	TEST_ASSERT(QDELETED(trial) && QDELETED(knife), "Completion must reclaim the finished pact and its knife.")
	TEST_ASSERT(hunter_mind.vestige_pending_reward, "The successful route must leave its real reward claim.")

/// The actual jaw cone marks three flammable stock beasts, whose actual weapon deaths complete the hunt.
/datum/unit_test/vestige_ember_feast_complete_route/Run()
	var/mob/living/carbon/human/keeper = allocate(/mob/living/carbon/human/consistent)
	keeper.mind_initialize()
	var/datum/mind/hunter_mind = keeper.mind
	var/datum/vestige_trial/ember_feast/trial = allocate(/datum/vestige_trial/ember_feast, hunter_mind, "Test Unfed", list(/datum/vestige_boon/spell/armblade))
	hunter_mind.active_vestige_trial = trial
	trial.on_accepted(keeper)
	var/obj/item/vestige_ember_jaw/jaw = locate() in keeper.held_items
	TEST_ASSERT(jaw, "Accepting the pact must hand over its actual ember-jaw.")
	var/obj/item/knife/combat/weapon = allocate(/obj/item/knife/combat)
	TEST_ASSERT(keeper.put_in_hands(weapon), "The route needs an ordinary held weapon beside the jaw.")
	keeper.swap_hand(keeper.get_held_index_of_item(weapon))
	var/list/quarry = list()
	var/turf/breath_floor = get_turf(keeper)
	var/turf/prey_floor = breath_floor
	for(var/meal in 1 to 3)
		prey_floor = get_step(prey_floor, EAST)
		var/mob/living/basic/spider/giant/nurse/beast = allocate(/mob/living/basic/spider/giant/nurse, prey_floor)
		ADD_TRAIT(beast, TRAIT_AI_PAUSED, TRAIT_GENERIC)
		keeper.forceMove(get_step(prey_floor, WEST))
		weapon.melee_attack_chain(keeper, beast, list())
		TEST_ASSERT(beast.stat != DEAD && beast.health < beast.maxHealth, "An actual preparatory wound must leave the stock spider alive.")
		quarry += beast
	keeper.forceMove(breath_floor)
	keeper.swap_hand(keeper.get_held_index_of_item(jaw))
	keeper.setDir(EAST)
	jaw.attack_self(keeper)
	TEST_ASSERT_EQUAL(length(jaw.marked_prey), 3, "The real in-hand breath must mark three flammable stock spiders in its cone.")
	keeper.swap_hand(keeper.get_held_index_of_item(weapon))
	for(var/mob/living/basic/spider/giant/nurse/beast as anything in quarry)
		TEST_ASSERT(beast.on_fire && beast.stat != DEAD, "The breath must leave each stock spider alive and genuinely burning.")
		keeper.forceMove(get_step(beast, WEST))
		for(var/cut in 1 to 3)
			if(beast.stat == DEAD)
				break
			weapon.melee_attack_chain(keeper, beast, list())
		TEST_ASSERT_EQUAL(beast.stat, DEAD, "Ordinary weapon damage must finish the marked beast.")
	TEST_ASSERT(/datum/vestige_trial/ember_feast in hunter_mind.completed_vestige_trials, "The third actual burning death must complete the Ember Feast.")
	TEST_ASSERT(QDELETED(trial) && QDELETED(jaw), "Completion must reclaim the jaw even from inside its death signal.")
	TEST_ASSERT(hunter_mind.vestige_pending_reward && !QDELETED(weapon), "The route must pay its claim and preserve the hunter's weapon.")

/// Fire the real maw, wait for projectile impact, then finish its marked quarry with a weapon.
/datum/unit_test/vestige_boiling_kiss_complete_route/Run()
	var/mob/living/carbon/human/keeper = allocate(/mob/living/carbon/human/consistent)
	keeper.mind_initialize()
	var/datum/mind/hunter_mind = keeper.mind
	var/datum/vestige_trial/boiling_kiss/trial = allocate(/datum/vestige_trial/boiling_kiss, hunter_mind, "Test Dowager", list(/datum/vestige_boon/item/alien_baton))
	hunter_mind.active_vestige_trial = trial
	trial.on_accepted(keeper)
	var/obj/item/vestige_kiss_maw/maw = trial.maw
	var/obj/item/knife/combat/weapon = allocate(/obj/item/knife/combat)
	TEST_ASSERT(keeper.put_in_hands(weapon), "The route needs a normal weapon beside the loaned maw.")
	for(var/meal in 1 to 3)
		var/mob/living/basic/carp/quarry = allocate(/mob/living/basic/carp, get_step(keeper, EAST))
		ADD_TRAIT(quarry, TRAIT_AI_PAUSED, TRAIT_GENERIC)
		// Advance only recharge; attribution and progress still come from real impacts and deaths.
		COOLDOWN_RESET(maw, spit_cooldown)
		TEST_ASSERT_EQUAL(maw.interact_with_atom(quarry, keeper, list()), ITEM_INTERACT_SUCCESS, "The real adjacent item handler must fire the loaned maw.")
		var/deadline = world.time + 3 SECONDS
		while(!quarry.has_status_effect(/datum/status_effect/vestige_kiss_corrosion) && world.time < deadline)
			sleep(world.tick_lag)
		TEST_ASSERT(quarry.has_status_effect(/datum/status_effect/vestige_kiss_corrosion), "The actual fired projectile must hit and apply acid.")
		TEST_ASSERT_EQUAL(maw.marked_prey[quarry], hunter_mind, "The impact must attribute its mark to the keeper.")
		for(var/cut in 1 to 3)
			if(quarry.stat == DEAD)
				break
			weapon.melee_attack_chain(keeper, quarry, list())
		TEST_ASSERT_EQUAL(quarry.stat, DEAD, "The ordinary weapon must finish the corroding prey.")
		qdel(quarry) // Keep the next projectile's line clear of earlier corpses.
	TEST_ASSERT(/datum/vestige_trial/boiling_kiss in hunter_mind.completed_vestige_trials, "The third actual corroding death must complete the Boiling Kiss.")
	TEST_ASSERT(QDELETED(trial) && QDELETED(maw), "Completion must reclaim the trial and its maw.")
	TEST_ASSERT(hunter_mind.vestige_pending_reward && !QDELETED(weapon), "Completion must create a claim and preserve the ordinary weapon.")

/// Spin actual webs, let stock target-finding choose the keeper, and move the hunters into them.
/datum/unit_test/vestige_snare_complete_route/Run()
	var/turf/web_floor = get_step(get_step(run_loc_floor_bottom_left, NORTH), EAST)
	var/mob/living/carbon/human/keeper = allocate(/mob/living/carbon/human/consistent, web_floor)
	keeper.mind_initialize()
	var/datum/mind/keeper_mind = keeper.mind
	var/datum/vestige_trial/loom_snare/trial = allocate(/datum/vestige_trial/loom_snare, keeper_mind, "Test Weaver", list(/datum/vestige_boon/spell/armblade))
	keeper_mind.active_vestige_trial = trial
	trial.on_accepted(keeper)
	var/obj/item/vestige_snare_spinneret/spinneret = trial.spinneret
	var/datum/ai_behavior/find_potential_targets/targeting = GET_AI_BEHAVIOR(/datum/ai_behavior/find_potential_targets)
	for(var/catch_number in 1 to 3)
		keeper.forceMove(web_floor)
		spinneret.attack_self(keeper)
		var/obj/structure/spider/stickyweb/vestige_snare/web = locate() in web_floor
		TEST_ASSERT(web && !web.spent, "The real in-hand spinneret channel must create an unused snare.")
		TEST_ASSERT(keeper.Move(get_step(web_floor, NORTH), NORTH), "The keeper must leave the snare for its pursuer.")
		var/mob/living/basic/carp/quarry = allocate(/mob/living/basic/carp, get_step(web_floor, SOUTH))
		targeting.perform(0.1, quarry.ai_controller, BB_BASIC_MOB_CURRENT_TARGET, BB_TARGETING_STRATEGY, BB_BASIC_MOB_CURRENT_TARGET_HIDING_LOCATION)
		TEST_ASSERT_EQUAL(vestige_loom_hunted_prey(quarry), keeper, "Stock target-finding must actually identify the keeper as prey.")
		step(quarry, NORTH)
		TEST_ASSERT(HAS_TRAIT(quarry, TRAIT_IMMOBILIZED), "Actual attempted movement into the deployed snare must immobilize the hunter.")
		if(catch_number < 3)
			TEST_ASSERT_EQUAL(trial.catches, catch_number, "The movement-triggered spring must award one real catch.")
		qdel(quarry)
		var/deadline = world.time + 2 SECONDS
		while(!QDELETED(web) && world.time < deadline)
			sleep(world.tick_lag)
		TEST_ASSERT(QDELETED(web), "Spent snare silk must collapse before the next placement.")
	TEST_ASSERT(/datum/vestige_trial/loom_snare in keeper_mind.completed_vestige_trials, "Three actual movement-triggered catches must complete the Snare.")
	TEST_ASSERT(QDELETED(trial) && QDELETED(spinneret), "Completion must reclaim the snare kit and trial.")
	TEST_ASSERT(keeper_mind.vestige_pending_reward, "The successful Snare route must create its reward claim.")

/// Deploy, capture through movement, wrap, drag and hoist three real live meals.
/datum/unit_test/vestige_pantry_complete_route/Run()
	var/turf/trap_floor = get_step(get_step(run_loc_floor_bottom_left, NORTH), EAST)
	var/turf/rack_floor = get_step(get_step(trap_floor, NORTHEAST), NORTHEAST)
	var/mob/living/carbon/human/keeper = allocate(/mob/living/carbon/human/consistent, get_step(rack_floor, WEST))
	keeper.mind_initialize()
	var/datum/mind/keeper_mind = keeper.mind
	var/datum/vestige_trial/loom_pantry/trial = allocate(/datum/vestige_trial/loom_pantry, keeper_mind, "Test Weaver", list(/datum/vestige_boon/spell/armblade))
	keeper_mind.active_vestige_trial = trial
	trial.on_accepted(keeper)
	var/obj/item/vestige_larder_bundle/bundle = trial.bundle
	keeper.swap_hand(keeper.get_held_index_of_item(bundle))
	TEST_ASSERT_EQUAL(bundle.interact_with_atom(rack_floor, keeper, list()), ITEM_INTERACT_SUCCESS, "The actual bundle channel must deploy a rack.")
	var/obj/structure/vestige_larder_rack/rack = trial.rack
	var/obj/item/vestige_wrap_spool/spool = trial.spool
	TEST_ASSERT(rack && QDELETED(bundle), "Deployment must replace the carried bundle with the real rack.")
	for(var/meal_number in 1 to 3)
		keeper.forceMove(trap_floor)
		if(trial.capture_web)
			TEST_ASSERT(!keeper.get_active_held_item(), "The keeper's free hand must remain available after hoisting.")
			trial.capture_web.attack_hand(keeper, list())
		keeper.swap_hand(keeper.get_held_index_of_item(spool))
		spool.attack_self(keeper)
		var/obj/structure/spider/stickyweb/vestige_capture/web = trial.capture_web
		TEST_ASSERT(web, "The real spool channel must create a capture web.")
		var/mob/living/basic/carp/quarry = allocate(/mob/living/basic/carp, get_step(trap_floor, SOUTH))
		step(quarry, NORTH)
		TEST_ASSERT_EQUAL(web.captive?.resolve(), quarry, "Actual movement into the web must trigger capture.")
		TEST_ASSERT(vestige_loom_is_held_fast(quarry), "The real capture must hold long enough for wrapping.")
		spool.melee_attack_chain(keeper, quarry, list())
		var/obj/structure/vestige_silk_cocoon/parcel = quarry.loc
		TEST_ASSERT(istype(parcel) && (parcel in trial.cocoons), "The actual wrap channel must put the living quarry inside its tracked cocoon.")
		TEST_ASSERT_EQUAL(get_dist(parcel, rack), 3, "The fixture must require hauling rather than already touching the rack.")
		keeper.swap_hand()
		keeper.start_pulling(parcel)
		TEST_ASSERT_EQUAL(keeper.pulling, parcel, "The keeper must grab the actual movable cocoon.")
		for(var/direction in list(EAST, NORTH, NORTH))
			TEST_ASSERT(keeper.Move(get_step(keeper, direction), direction), "The keeper must walk the cocoon toward the rack.")
		TEST_ASSERT(get_dist(parcel, rack) <= 1 && parcel.z == rack.z, "Ordinary pulling must deliver the fresh cocoon beside the rack.")
		rack.attack_hand(keeper, list())
		var/deadline = world.time + 5 SECONDS
		while(!QDELETED(parcel) && world.time < deadline)
			sleep(world.tick_lag)
		TEST_ASSERT(QDELETED(parcel) && QDELETED(quarry), "The real hoist must take its living meal whole.")
		if(meal_number < 3)
			TEST_ASSERT_EQUAL(trial.stocked, meal_number, "Each complete capture-wrap-haul-hoist must stock exactly one meal.")
	TEST_ASSERT(/datum/vestige_trial/loom_pantry in keeper_mind.completed_vestige_trials, "Three complete physical deliveries must finish the Pantry.")
	TEST_ASSERT(QDELETED(trial) && QDELETED(rack) && QDELETED(spool), "Completion must reclaim the rack and loaned capture kit.")
	TEST_ASSERT(keeper_mind.vestige_pending_reward, "The successful Pantry route must create its reward claim.")

/// Record both ranges through actual fired barbs, stock target selection, and real quarry movement.
/datum/unit_test/vestige_census_complete_route/Run()
	var/mob/living/carbon/human/keeper = allocate(/mob/living/carbon/human/consistent)
	keeper.mind_initialize()
	var/datum/mind/keeper_mind = keeper.mind
	var/datum/vestige_trial/comb_census/trial = allocate(/datum/vestige_trial/comb_census, keeper_mind, "Test Dowager", list(/datum/vestige_boon/item/alien_baton))
	keeper_mind.active_vestige_trial = trial
	trial.on_accepted(keeper)
	var/obj/item/vestige_census_stinger/stinger = trial.stinger
	var/turf/pursuit_floor = locate(keeper.x + 4, keeper.y, keeper.z)
	var/datum/ai_behavior/find_potential_targets/targeting = GET_AI_BEHAVIOR(/datum/ai_behavior/find_potential_targets)
	for(var/profile_number in 1 to 2)
		var/mob/living/basic/carp/quarry = allocate(/mob/living/basic/carp, pursuit_floor)
		targeting.perform(0.1, quarry.ai_controller, BB_BASIC_MOB_CURRENT_TARGET, BB_TARGETING_STRATEGY, BB_BASIC_MOB_CURRENT_TARGET_HIDING_LOCATION)
		TEST_ASSERT_EQUAL(vestige_loom_hunted_prey(quarry), keeper, "Stock target selection must start a real hunt before the Census shot.")
		for(var/behavior in list("pursuit", "commitment"))
			COOLDOWN_RESET(stinger, sting_cooldown)
			TEST_ASSERT_EQUAL(stinger.ranged_interact_with_atom(quarry, keeper, list()), ITEM_INTERACT_SUCCESS, "The actual stinger handler must accept the new hunting range.")
			var/deadline = world.time + 3 SECONDS
			while(!HAS_TRAIT(quarry, TRAIT_IMMOBILIZED) && world.time < deadline)
				sleep(world.tick_lag)
			TEST_ASSERT(HAS_TRAIT(quarry, TRAIT_IMMOBILIZED) && quarry.IsStun(), "The real barb must land and stun its ordinary carp subject ([profile_number], [behavior]).")
			if(behavior == "pursuit")
				var/list/observations = trial.entries_per_subject[WEAKREF(quarry)]
				TEST_ASSERT_EQUAL(length(observations), 1, "The distant impact must create only the pursuit observation.")
				TEST_ASSERT("pursuit" in observations, "The real distance must be recorded as a pursuit.")
				deadline = world.time + 3 SECONDS
				while(HAS_TRAIT(quarry, TRAIT_IMMOBILIZED) && world.time < deadline)
					sleep(world.tick_lag)
				TEST_ASSERT(step(quarry, WEST) && step(quarry, WEST), "The recovered beast must actually approach to commitment range.")
				TEST_ASSERT_EQUAL(get_dist(quarry, keeper), 2, "The second barb must use the two-tile commitment boundary.")
		if(profile_number == 1)
			TEST_ASSERT_EQUAL(trial.complete_profiles, 1, "Both real impact ranges must complete the first beast's profile.")
		qdel(quarry)
	TEST_ASSERT(/datum/vestige_trial/comb_census in keeper_mind.completed_vestige_trials, "Two actual two-range observations must complete the Census.")
	TEST_ASSERT(QDELETED(trial) && QDELETED(stinger), "The final projectile's appraisal must safely reclaim the trial and its stinger.")
	TEST_ASSERT(keeper_mind.vestige_pending_reward, "The completed Census must create its real reward claim.")

/// One real in-hand gust interrupts four independently selected hunts before reclaiming its own charm.
/datum/unit_test/vestige_wingbeat_complete_route
	var/list/throw_origins = list()

/datum/unit_test/vestige_wingbeat_complete_route/proc/on_throw(atom/movable/source, datum/thrownthing/flight)
	SIGNAL_HANDLER
	throw_origins[source] = get_turf(source)

/datum/unit_test/vestige_wingbeat_complete_route/Run()
	var/turf/center = get_step(get_step(run_loc_floor_bottom_left, NORTHEAST), NORTHEAST)
	var/mob/living/carbon/human/keeper = allocate(/mob/living/carbon/human/consistent, center)
	keeper.mind_initialize()
	var/datum/mind/keeper_mind = keeper.mind
	var/datum/vestige_trial/wingbeat/trial = allocate(/datum/vestige_trial/wingbeat, keeper_mind, "Test Unfed", list(/datum/vestige_boon/spell/armblade))
	keeper_mind.active_vestige_trial = trial
	trial.on_accepted(keeper)
	var/obj/item/vestige_gust_charm/charm = locate() in keeper.held_items
	TEST_ASSERT(charm, "Accepting the trial must hand over the actual gust charm.")
	var/list/menaces = list()
	var/datum/ai_behavior/find_potential_targets/targeting = GET_AI_BEHAVIOR(/datum/ai_behavior/find_potential_targets)
	for(var/direction in GLOB.cardinals)
		var/mob/living/basic/carp/quarry = allocate(/mob/living/basic/carp, get_step(center, direction))
		targeting.perform(0.1, quarry.ai_controller, BB_BASIC_MOB_CURRENT_TARGET, BB_TARGETING_STRATEGY, BB_BASIC_MOB_CURRENT_TARGET_HIDING_LOCATION)
		TEST_ASSERT_EQUAL(vestige_loom_hunted_prey(quarry), keeper, "Each ordinary carp must independently choose the keeper as its target.")
		RegisterSignal(quarry, COMSIG_MOVABLE_POST_THROW, PROC_REF(on_throw))
		menaces += quarry
	charm.attack_self(keeper)
	TEST_ASSERT(/datum/vestige_trial/wingbeat in keeper_mind.completed_vestige_trials, "The actual gust must count all four successfully thrown hunters.")
	TEST_ASSERT_EQUAL(length(throw_origins), 4, "Every counted hunter must emit a real throw-start event before the final credit completes the pact.")
	for(var/mob/living/basic/carp/quarry as anything in menaces)
		var/deadline = world.time + 3 SECONDS
		while(get_turf(quarry) == throw_origins[quarry] && world.time < deadline)
			sleep(world.tick_lag)
		TEST_ASSERT(get_turf(quarry) != throw_origins[quarry], "Every counted hunter must physically move, even if its quick-started throw already hit a wall.")
	TEST_ASSERT(QDELETED(trial) && QDELETED(charm), "The post-throw credit loop must safely reclaim the pact and charm.")
	TEST_ASSERT(keeper_mind.vestige_pending_reward, "The completed Wingbeat must create its real reward claim.")

/// Deploy the actual rack and hang three freshly killed ordinary carcasses through the drag-drop chain.
/datum/unit_test/vestige_table_complete_route/Run()
	var/turf/rack_floor = get_step(get_step(run_loc_floor_bottom_left, NORTH), EAST)
	var/mob/living/carbon/human/keeper = allocate(/mob/living/carbon/human/consistent, get_step(rack_floor, WEST))
	keeper.mind_initialize()
	var/datum/mind/keeper_mind = keeper.mind
	var/datum/vestige_trial/set_the_table/trial = allocate(/datum/vestige_trial/set_the_table, keeper_mind, "Test Stain", list(/datum/vestige_boon/spell/rending_claws))
	keeper_mind.active_vestige_trial = trial
	trial.on_accepted(keeper)
	var/obj/item/vestige_gambrel/bundle = trial.gambrel_item
	TEST_ASSERT_EQUAL(bundle.interact_with_atom(rack_floor, keeper, list()), ITEM_INTERACT_SUCCESS, "The real bundle channel must unfold the table.")
	var/obj/structure/vestige_gambrel/rack = trial.gambrel_structure
	TEST_ASSERT(rack && QDELETED(bundle), "The deployed rack must replace the carried kit.")
	var/obj/item/knife/combat/weapon = allocate(/obj/item/knife/combat)
	TEST_ASSERT(keeper.put_in_hands(weapon), "The hunter must equip an ordinary weapon.")
	var/list/carcasses = list()
	for(var/setting_number in 1 to 3)
		var/mob/living/basic/carp/quarry = allocate(/mob/living/basic/carp, get_step(rack_floor, SOUTHWEST))
		for(var/cut in 1 to 3)
			if(quarry.stat == DEAD)
				break
			weapon.melee_attack_chain(keeper, quarry, list())
		TEST_ASSERT_EQUAL(quarry.stat, DEAD, "The ordinary weapon must produce the fresh carcass.")
		TEST_ASSERT(rack.mouse_drop_receive(quarry, keeper, null), "The real drag-drop route must complete both hang and buckle channels.")
		TEST_ASSERT_EQUAL(quarry.buckled, rack, "The credited carcass must actually hang from the rack.")
		TEST_ASSERT_EQUAL(trial.settings, setting_number, "Each actual fresh hanging must credit one setting.")
		carcasses += quarry
	var/deadline = world.time + 3 SECONDS
	while(!QDELETED(trial) && world.time < deadline)
		sleep(world.tick_lag)
	TEST_ASSERT(/datum/vestige_trial/set_the_table in keeper_mind.completed_vestige_trials, "Three real fresh hangings must complete through the deferred conclusion.")
	TEST_ASSERT(QDELETED(trial) && QDELETED(rack), "The completed pact must reclaim its planted rack.")
	for(var/mob/living/basic/carp/quarry as anything in carcasses)
		TEST_ASSERT(!QDELETED(quarry) && !quarry.buckled && !HAS_TRAIT(quarry, TRAIT_MOVE_UPSIDE_DOWN), "Cleanup must drop and right every intact carcass for normal butchering.")
	TEST_ASSERT(keeper_mind.vestige_pending_reward && !QDELETED(weapon), "Completion must create its claim and preserve the hunter's weapon.")

/// The encounter routes need honest five-tile line spacing and open approaches beyond the 5x5 room.
/datum/unit_test/vestige_hunt_route
	abstract_type = /datum/unit_test/vestige_hunt_route
	var/list/restored_ground = list()

/datum/unit_test/vestige_hunt_route/Destroy()
	. = ..() // Reclaim every actor and kit before putting the surrounding terrain back.
	for(var/list/record as anything in restored_ground)
		var/turf/ground = locate(record[1], record[2], record[3])
		ground.ChangeTurf(record[4])
	restored_ground.Cut()
	restore_atmos()

/datum/unit_test/vestige_hunt_route/proc/prepare_ground()
	var/turf/corner = run_loc_floor_bottom_left
	for(var/turf/ground as anything in block(locate(corner.x - 1, corner.y - 1, corner.z), locate(corner.x + 9, corner.y + 9, corner.z)))
		if(isfloorturf(ground))
			continue
		restored_ground += list(list(ground.x, ground.y, ground.z, ground.type))
		ground.ChangeTurf(/turf/open/floor/plating)
	return locate(corner.x + 4, corner.y + 4, corner.z)

/// Retain the production callback and arguments, shortening only an existing scheduled delay.
/datum/unit_test/vestige_hunt_route/proc/run_pending_callback(datum/source, callback_proc)
	for(var/datum/timedevent/scheduled as anything in source._active_timers?.Copy())
		if(scheduled.callBack?.delegate != callback_proc)
			continue
		var/datum/callback/pending = scheduled.callBack
		qdel(scheduled)
		var/timer_id = addtimer(pending, 1, TIMER_STOPPABLE)
		var/datum/timedevent/expedited = SStimer.timer_id_dict[timer_id]
		var/deadline = world.time + 3 SECONDS
		while(!QDELETED(expedited) && world.time < deadline)
			sleep(world.tick_lag)
		return QDELETED(expedited)
	return FALSE

/// Real deployed shell, scheduled waves, carp bites, two empty-hand repairs, combat deaths and hatching.
/datum/unit_test/vestige_hunt_route/broodwatch/Run()
	var/turf/nest_floor = prepare_ground()
	var/mob/living/carbon/human/keeper = allocate(/mob/living/carbon/human/consistent, get_step(nest_floor, WEST))
	ADD_TRAIT(keeper, TRAIT_NOBREATH, TRAIT_SOURCE_UNIT_TESTS)
	ADD_TRAIT(keeper, TRAIT_SPACEWALK, TRAIT_SOURCE_UNIT_TESTS)
	keeper.mind_initialize()
	var/datum/mind/keeper_mind = keeper.mind
	var/datum/vestige_trial/broodwatch/trial = allocate(/datum/vestige_trial/broodwatch, keeper_mind, "Test Unfed", list(/datum/vestige_boon/spell/armblade))
	keeper_mind.active_vestige_trial = trial
	trial.on_accepted(keeper)
	var/obj/item/vestige_dragon_egg/carried = trial.egg_item
	TEST_ASSERT_EQUAL(carried.interact_with_atom(nest_floor, keeper, list()), ITEM_INTERACT_SUCCESS, "The real carried egg must channel into a planted shell.")
	var/obj/structure/vestige_dragon_egg/nest = trial.egg_structure
	TEST_ASSERT(nest && QDELETED(carried), "Planting must consume the carried egg and register the nest.")
	// This is the selected 'Wake it' branch; the test world has no client to answer a TGUI alert.
	nest.begin_assault(keeper)
	TEST_ASSERT(run_pending_callback(nest, TYPE_PROC_REF(/obj/structure/vestige_dragon_egg, herald_wave)), "Waking must schedule a real first herald.")
	var/obj/item/knife/combat/weapon = allocate(/obj/item/knife/combat)
	TEST_ASSERT(keeper.put_in_hands(weapon), "The defender must equip an ordinary weapon.")
	for(var/wave_number in 1 to 3)
		if(wave_number > 1)
			keeper.forceMove(get_step(nest_floor, WEST))
			keeper.swap_hand()
			TEST_ASSERT_NULL(keeper.get_active_held_item(), "Calling the next wave must use a real empty hand.")
			nest.next_wave_at = world.time // Advance only the rebuilding rest period.
			nest.attack_hand(keeper, list())
		TEST_ASSERT(nest.wave_pending, "The actual herald must announce each wave before spawning it.")
		TEST_ASSERT(run_pending_callback(nest, TYPE_PROC_REF(/obj/structure/vestige_dragon_egg, unleash_wave)), "The pending arrival must execute through its real scheduled callback.")
		TEST_ASSERT_EQUAL(nest.stage, wave_number, "Only the actual arrival may advance the wave number.")
		TEST_ASSERT_EQUAL(length(nest.brood), 2, "Each real wave must supply exactly two brood carp.")
		var/mob/living/basic/carp/vestige_brood/biter = nest.brood[2]
		TEST_ASSERT_EQUAL(biter.ai_controller.blackboard[BB_BASIC_MOB_CURRENT_TARGET], nest, "The egg-bound carp must spawn with the real shell target.")
		if(wave_number < 3)
			biter.forceMove(get_step(nest_floor, EAST))
			biter.melee_attack(nest, list())
			TEST_ASSERT(nest.atom_integrity < nest.max_integrity, "The actual carp attack must damage the planted shell.")
			keeper.forceMove(get_step(nest_floor, WEST))
			if(keeper.get_active_held_item())
				keeper.swap_hand()
			nest.attack_hand(keeper, list())
			var/deadline = world.time + 5 SECONDS
			while(nest.repairing && world.time < deadline)
				sleep(world.tick_lag)
			TEST_ASSERT_EQUAL(nest.atom_integrity, nest.max_integrity, "The real empty-hand patch channel must repair the shell.")
			TEST_ASSERT_EQUAL(nest.repairs_left, 2 - wave_number, "Each actual patch must spend one of the two repairs.")
		keeper.swap_hand(keeper.get_held_index_of_item(weapon))
		for(var/mob/living/basic/carp/vestige_brood/quarry as anything in nest.brood.Copy())
			keeper.forceMove(get_step(quarry, SOUTH))
			for(var/cut in 1 to 5)
				if(QDELETED(quarry))
					break
				weapon.melee_attack_chain(keeper, quarry, list())
			TEST_ASSERT(QDELETED(quarry), "Real weapon damage must kill and dissolve every spawned carp.")
		TEST_ASSERT_EQUAL(length(nest.brood), 0, "Actual death signals must clear the entire wave roster.")
	TEST_ASSERT(nest.hatching, "The sixth actual carp death must arm the hatch.")
	TEST_ASSERT(run_pending_callback(nest, TYPE_PROC_REF(/obj/structure/vestige_dragon_egg, hatch)), "The actual hatch callback must finish the watch.")
	var/mob/living/basic/carp/pet/vestige_hatchling/heir = locate() in nest_floor
	TEST_ASSERT(heir && heir.stat != DEAD, "Successful defense must leave its real living hatchling.")
	TEST_ASSERT(/datum/vestige_trial/broodwatch in keeper_mind.completed_vestige_trials, "Three complete real waves must complete Broodwatch.")
	TEST_ASSERT(QDELETED(trial) && QDELETED(nest) && !QDELETED(weapon), "Hatching must reclaim the encounter while preserving the defender's weapon.")
	TEST_ASSERT(keeper_mind.vestige_pending_reward, "The defended hatch must create its real reward claim.")

/// Real resin, cutter damage, resin repair, four scheduled gangs and the harmless hatchling reward.
/datum/unit_test/vestige_hunt_route/warm_season/Run()
	var/turf/nest_floor = prepare_ground()
	var/mob/living/carbon/human/keeper = allocate(/mob/living/carbon/human/consistent, get_step(nest_floor, WEST))
	ADD_TRAIT(keeper, TRAIT_NOBREATH, TRAIT_SOURCE_UNIT_TESTS)
	ADD_TRAIT(keeper, TRAIT_SPACEWALK, TRAIT_SOURCE_UNIT_TESTS)
	keeper.mind_initialize()
	var/datum/mind/keeper_mind = keeper.mind
	var/datum/vestige_trial/warm_season/trial = allocate(/datum/vestige_trial/warm_season, keeper_mind, "Test Dowager", list(/datum/vestige_boon/item/alien_baton))
	keeper_mind.active_vestige_trial = trial
	trial.on_accepted(keeper)
	var/obj/item/vestige_comb_egg/carried = trial.egg_item
	TEST_ASSERT_EQUAL(carried.interact_with_atom(nest_floor, keeper, list()), ITEM_INTERACT_SUCCESS, "The actual egg channel must plant the clutch.")
	var/obj/structure/vestige_comb_egg/nest = trial.egg_structure
	var/obj/item/vestige_comb_spinneret/spinneret = trial.spinneret
	TEST_ASSERT(nest && QDELETED(carried), "The planted clutch must replace the carried egg.")
	keeper.swap_hand(keeper.get_held_index_of_item(spinneret))
	var/turf/resin_floor = get_step(nest_floor, NORTH)
	TEST_ASSERT_EQUAL(spinneret.interact_with_atom(resin_floor, keeper, list()), ITEM_INTERACT_SUCCESS, "The actual spinneret must channel a real defensive resin wall.")
	var/obj/structure/vestige_comb_resin/resin = locate() in resin_floor
	TEST_ASSERT(resin && (resin in trial.woven), "The actual woven wall must join the trial's cleanup ledger.")
	// This is the selected 'Warm it' branch; no client exists to answer its TGUI alert.
	nest.begin_season(keeper)
	TEST_ASSERT(run_pending_callback(nest, TYPE_PROC_REF(/obj/structure/vestige_comb_egg, herald_squad)), "Warming must schedule a real first gang warning.")
	var/obj/item/knife/combat/weapon = allocate(/obj/item/knife/combat)
	TEST_ASSERT(keeper.put_in_hands(weapon), "The defender must equip an ordinary weapon beside the spinneret.")
	var/list/gang_sizes = list(1, 2, 2, 3)
	for(var/gang_number in 1 to 4)
		if(gang_number > 1)
			keeper.forceMove(get_step(nest_floor, WEST))
			keeper.swap_hand(keeper.get_held_index_of_item(weapon))
			TEST_ASSERT(keeper.dropItemToGround(weapon), "Calling a new gang must first free the defender's active hand.")
			nest.next_squad_at = world.time // Advance only the rebuilding rest period.
			nest.attack_hand(keeper, list())
			TEST_ASSERT(keeper.put_in_hands(weapon), "The defender must recover the ordinary weapon after calling the gang.")
		TEST_ASSERT(nest.squad_pending, "Each real herald must announce its gang before arrival.")
		TEST_ASSERT(run_pending_callback(nest, TYPE_PROC_REF(/obj/structure/vestige_comb_egg, land_squad)), "The actual scheduled arrival must create the gang.")
		TEST_ASSERT_EQUAL(length(nest.chewers), gang_sizes[gang_number], "The real gangs must retain their authored 1/2/2/3 sizes.")
		TEST_ASSERT_EQUAL(nest.squads_landed, gang_number, "Only actual gang arrivals may advance the season.")
		if(gang_number == 1)
			var/mob/living/basic/hivebot/vestige_comb_chewer/biter = nest.chewers[1]
			TEST_ASSERT_EQUAL(biter.ai_controller.blackboard[BB_BASIC_MOB_CURRENT_TARGET], nest, "The spawned cutter must receive its real shell directive.")
			biter.forceMove(get_step(resin_floor, NORTH))
			biter.melee_attack(resin, list())
			TEST_ASSERT(resin.atom_integrity < resin.max_integrity, "The cutter must actually damage the woven resin through normal basic-mob combat.")
			biter.forceMove(get_step(nest_floor, EAST))
			biter.melee_attack(nest, list())
			TEST_ASSERT(nest.atom_integrity < nest.max_integrity, "An actual cutter attack must also damage the shell.")
			keeper.swap_hand(keeper.get_held_index_of_item(spinneret))
			TEST_ASSERT_EQUAL(spinneret.interact_with_atom(nest, keeper, list()), ITEM_INTERACT_SUCCESS, "The real spinneret repair channel must mend the damaged shell.")
			TEST_ASSERT_EQUAL(nest.atom_integrity, nest.max_integrity, "The mending channel must restore the actual lost integrity.")
		keeper.swap_hand(keeper.get_held_index_of_item(weapon))
		for(var/mob/living/basic/hivebot/vestige_comb_chewer/quarry as anything in nest.chewers.Copy())
			keeper.forceMove(get_step(quarry, SOUTH))
			for(var/cut in 1 to 10)
				if(QDELETED(quarry))
					break
				weapon.melee_attack_chain(keeper, quarry, list())
			TEST_ASSERT(QDELETED(quarry), "Real weapon attacks must destroy every spawned cutter.")
		TEST_ASSERT_EQUAL(length(nest.chewers), 0, "The actual cutter death signals must clear the gang roster.")
	TEST_ASSERT(nest.hatching, "Defeating all eight real cutters must arm the hatch.")
	TEST_ASSERT(run_pending_callback(nest, TYPE_PROC_REF(/obj/structure/vestige_comb_egg, hatch)), "The actual scheduled hatch must finish the Warm Season.")
	var/obj/item/clothing/mask/facehugger/vestige_comb_heir/heir = locate() in nest_floor
	TEST_ASSERT(heir && !QDELETED(heir), "The completed season must leave its actual harmless heir.")
	TEST_ASSERT(/datum/vestige_trial/warm_season in keeper_mind.completed_vestige_trials, "Four complete real gangs must complete the Warm Season.")
	TEST_ASSERT(QDELETED(trial) && QDELETED(nest) && QDELETED(spinneret) && QDELETED(resin), "Hatching must reclaim the shell, spinneret and woven defenses.")
	TEST_ASSERT(keeper_mind.vestige_pending_reward && !QDELETED(weapon), "The successful season must create its claim and preserve the defender's weapon.")

/// String the actual dispersed net, answer four real bite alarms on foot, and kill the supplied thieves.
/datum/unit_test/vestige_hunt_route/tremor/Run()
	var/turf/center = prepare_ground()
	var/list/line_floors = list(locate(center.x - 3, center.y - 3, center.z), locate(center.x + 2, center.y - 3, center.z), locate(center.x - 3, center.y + 2, center.z))
	var/mob/living/carbon/human/keeper = allocate(/mob/living/carbon/human/consistent, center)
	ADD_TRAIT(keeper, TRAIT_NOBREATH, TRAIT_SOURCE_UNIT_TESTS)
	ADD_TRAIT(keeper, TRAIT_SPACEWALK, TRAIT_SOURCE_UNIT_TESTS)
	keeper.mind_initialize()
	var/datum/mind/keeper_mind = keeper.mind
	var/datum/vestige_trial/loom_tremor/trial = allocate(/datum/vestige_trial/loom_tremor, keeper_mind, "Test Weaver", list(/datum/vestige_boon/spell/armblade))
	keeper_mind.active_vestige_trial = trial
	trial.on_accepted(keeper)
	var/obj/item/vestige_tremor_spool/spool = trial.spool
	for(var/turf/line_floor as anything in line_floors)
		keeper.forceMove(line_floor)
		spool.attack_self(keeper)
	TEST_ASSERT_EQUAL(length(trial.lines), 3, "The real placement channels must string all three lines at their authored spacing.")
	TEST_ASSERT(trial.night_begun, "The actual third line must start the night.")
	var/list/lines = trial.lines.Copy()
	var/obj/item/knife/combat/weapon = allocate(/obj/item/knife/combat)
	TEST_ASSERT(keeper.put_in_hands(weapon), "The keeper must equip an ordinary weapon beside the spool.")
	keeper.swap_hand(keeper.get_held_index_of_item(weapon))
	for(var/answer_number in 1 to 4)
		trial.next_send_at = world.time // Advance only the pause between thieves.
		TEST_ASSERT(run_pending_callback(trial, TYPE_PROC_REF(/datum/vestige_trial/loom_tremor, loom_beat)), "The existing heartbeat timer must send the next actual thief.")
		TEST_ASSERT_EQUAL(length(trial.thieves), 1, "The actual heartbeat must supply one thief at a time.")
		var/mob/living/basic/vestige_silk_thief/thief = trial.thieves[1]
		var/obj/structure/vestige_tremor_line/line = trial.thieves[thief]
		TEST_ASSERT_EQUAL(thief.ai_controller.blackboard[BB_BASIC_MOB_CURRENT_TARGET], line, "The spawned thief must receive its real assigned-line directive.")
		TEST_ASSERT(!line.pinged, "Each new thief must begin with a fresh alarm.")
		for(var/pace in 1 to 15)
			if(thief.Adjacent(line))
				break
			step_towards(thief, line)
		TEST_ASSERT(thief.Adjacent(line), "The supplied thief must have an actual traversable approach to its line.")
		thief.melee_attack(line, list())
		TEST_ASSERT(line.pinged && line.atom_integrity < line.max_integrity, "The real basic-mob bite must damage the line and ring its tremor.")
		for(var/pace in 1 to 20)
			if(keeper.Adjacent(thief))
				break
			step_towards(keeper, thief)
		TEST_ASSERT(keeper.Adjacent(thief), "The keeper must reach the actual thief on foot before answering.")
		for(var/cut in 1 to 5)
			if(QDELETED(thief))
				break
			weapon.melee_attack_chain(keeper, thief, list())
		TEST_ASSERT(QDELETED(thief), "The normal weapon must actually kill and dissolve the supplied thief.")
		if(answer_number < 4)
			TEST_ASSERT_EQUAL(trial.answered, answer_number, "Each in-person combat death must answer exactly one tremor.")
	TEST_ASSERT(/datum/vestige_trial/loom_tremor in keeper_mind.completed_vestige_trials, "Four actual alarms answered in person must complete the Tremor Line.")
	for(var/obj/structure/vestige_tremor_line/line as anything in lines)
		TEST_ASSERT(QDELETED(line), "Completion must reclaim every strung line.")
	TEST_ASSERT(QDELETED(trial) && QDELETED(spool), "Completion must reclaim the night and its borrowed spool.")
	TEST_ASSERT(keeper_mind.vestige_pending_reward && !QDELETED(weapon), "The completed net must create its claim and preserve the keeper's weapon.")

/// Cast the borrowed action through both real jaunt transitions and land three moving-quarry strikes.
/datum/unit_test/vestige_trapdoor_complete_route/Run()
	var/turf/door_floor = get_step(get_step(run_loc_floor_bottom_left, NORTH), EAST)
	var/mob/living/carbon/human/keeper = allocate(/mob/living/carbon/human/consistent, door_floor)
	keeper.mind_initialize()
	var/datum/mind/keeper_mind = keeper.mind
	var/datum/vestige_trial/trapdoor_feast/trial = allocate(/datum/vestige_trial/trapdoor_feast, keeper_mind, "Test Stain", list(/datum/vestige_boon/spell/rending_claws))
	keeper_mind.active_vestige_trial = trial
	trial.on_accepted(keeper)
	var/datum/action/cooldown/spell/jaunt/bloodcrawl/vestige_trapdoor/crawl = trial.crawl
	var/obj/item/knife/combat/weapon = allocate(/obj/item/knife/combat)
	TEST_ASSERT(keeper.put_in_hands(weapon), "The apprentice must carry an actual weapon into the blood.")
	var/datum/ai_behavior/find_potential_targets/targeting = GET_AI_BEHAVIOR(/datum/ai_behavior/find_potential_targets)
	for(var/pounce_number in 1 to 3)
		var/mob/living/basic/carp/quarry = allocate(/mob/living/basic/carp, get_step(door_floor, NORTHEAST))
		targeting.perform(0.1, quarry.ai_controller, BB_BASIC_MOB_CURRENT_TARGET, BB_TARGETING_STRATEGY, BB_BASIC_MOB_CURRENT_TARGET_HIDING_LOCATION)
		TEST_ASSERT_EQUAL(vestige_loom_hunted_prey(quarry), keeper, "The ordinary carp must begin a real hunt before the dive.")
		crawl.reset_spell_cooldown() // Advance only the action's recharge between real casts.
		TEST_ASSERT(crawl.IsAvailable(), "The normal action availability gates must allow the dive.")
		TEST_ASSERT(crawl.PreActivate(keeper), "The actual borrowed action must accept its dive cast.")
		var/obj/effect/dummy/phased_mob/blood/holder = keeper.loc
		TEST_ASSERT(istype(holder), "The cast must physically place the keeper in its real blood holder.")
		TEST_ASSERT_EQUAL(keeper.get_active_held_item(), weapon, "The Trapdoor dive must preserve the real held weapon.")
		if(pounce_number == 1)
			TEST_ASSERT_EQUAL(keeper.getBruteLoss(), 5, "The first real cast must pay the exact five-brute self-cut toll.")
			var/obj/effect/decal/cleanable/blood/door = locate() in door_floor
			TEST_ASSERT(door && door.can_bloodcrawl_in(), "The first cast must create an actual crawlable blood door.")
		TEST_ASSERT(step(quarry, SOUTH), "The hunting beast must actually move during the dive.")
		crawl.reset_spell_cooldown()
		TEST_ASSERT(crawl.IsAvailable(), "The normal action availability gates must allow the submerged keeper to rise.")
		TEST_ASSERT(crawl.PreActivate(keeper), "The actual borrowed action must accept its voluntary rise cast.")
		TEST_ASSERT(QDELETED(holder) && isturf(keeper.loc), "The rise must eject the keeper and reclaim its physical blood holder.")
		TEST_ASSERT(crawl.can_pounce(keeper, quarry), "Actual dive and rise snapshots must recognize the beast's movement without assigned progress.")
		weapon.melee_attack_chain(keeper, quarry, list())
		TEST_ASSERT(quarry.health < quarry.maxHealth, "The real held-weapon strike must actually damage the moving quarry.")
		TEST_ASSERT_EQUAL(trial.ambushes, pounce_number, "Each real rise-and-hit chain must grant one pounce.")
		qdel(quarry)
	var/deadline = world.time + 3 SECONDS
	while(!QDELETED(trial) && world.time < deadline)
		sleep(world.tick_lag)
	TEST_ASSERT(/datum/vestige_trial/trapdoor_feast in keeper_mind.completed_vestige_trials, "Three actual moving-quarry ambushes must complete the Trapdoor Feast.")
	TEST_ASSERT(QDELETED(trial) && QDELETED(crawl), "The deferred completion must reclaim the trial and its granted crawl.")
	TEST_ASSERT(isturf(keeper.loc) && !HAS_TRAIT(keeper, TRAIT_IMMOBILIZED), "The completed apprentice must remain fully surfaced and mobile.")
	TEST_ASSERT(keeper_mind.vestige_pending_reward && keeper.is_holding(weapon), "Completion must create its claim and leave the ordinary weapon in hand.")

/// The real six-second recharge must leave a voluntary exit window before ten-second forced ejection.
/datum/unit_test/vestige_trapdoor_real_timing/Run()
	var/turf/door_floor = get_step(get_step(run_loc_floor_bottom_left, NORTH), EAST)
	var/mob/living/carbon/human/keeper = allocate(/mob/living/carbon/human/consistent, door_floor)
	keeper.mind_initialize()
	var/datum/vestige_trial/trapdoor_feast/trial = allocate(/datum/vestige_trial/trapdoor_feast, keeper.mind)
	keeper.mind.active_vestige_trial = trial
	trial.on_accepted(keeper)
	var/datum/action/cooldown/spell/jaunt/bloodcrawl/vestige_trapdoor/crawl = trial.crawl
	var/obj/item/knife/combat/weapon = allocate(/obj/item/knife/combat)
	TEST_ASSERT(keeper.put_in_hands(weapon), "The apprentice must hold a real weapon throughout the timing scenario.")
	var/datum/ai_behavior/find_potential_targets/targeting = GET_AI_BEHAVIOR(/datum/ai_behavior/find_potential_targets)
	for(var/forced_exit in list(FALSE, TRUE))
		var/mob/living/basic/carp/quarry = allocate(/mob/living/basic/carp, get_step(door_floor, NORTHEAST))
		targeting.perform(0.1, quarry.ai_controller, BB_BASIC_MOB_CURRENT_TARGET, BB_TARGETING_STRATEGY, BB_BASIC_MOB_CURRENT_TARGET_HIDING_LOCATION)
		TEST_ASSERT_EQUAL(vestige_loom_hunted_prey(quarry), keeper, "The actual AI target must exist before each timed dive.")
		var/deadline = world.time + crawl.cooldown_time + 2 SECONDS
		while(!crawl.IsAvailable() && world.time < deadline)
			sleep(world.tick_lag)
		TEST_ASSERT(crawl.Trigger(), "The real action trigger must allow a dive after natural recharge.")
		var/obj/effect/dummy/phased_mob/blood/holder = keeper.loc
		TEST_ASSERT(istype(holder), "The timed cast must actually submerge the keeper.")
		TEST_ASSERT(!crawl.Trigger(), "An immediate second button press must respect the real dive cooldown.")
		TEST_ASSERT_EQUAL(keeper.loc, holder, "The cooldown refusal must leave the keeper submerged.")
		TEST_ASSERT(step(quarry, SOUTH), "The hunting beast must actually move during the timed dive.")
		if(forced_exit)
			deadline = world.time + 12 SECONDS
			while(!QDELETED(holder) && world.time < deadline)
				sleep(world.tick_lag)
			TEST_ASSERT(QDELETED(holder), "The untouched real lurk timer must forcibly eject its keeper.")
			TEST_ASSERT(!crawl.IsAvailable(), "Automatic ejection must charge the normal rise cooldown.")
		else
			deadline = world.time + crawl.cooldown_time + 2 SECONDS
			while(!crawl.IsAvailable() && world.time < deadline)
				sleep(world.tick_lag)
			TEST_ASSERT_EQUAL(keeper.loc, holder, "Natural recharge must finish before the real lurk timer ejects the keeper.")
			TEST_ASSERT(crawl.Trigger(), "A second normal button press after natural recharge must voluntarily surface.")
			TEST_ASSERT(QDELETED(holder), "The voluntary cast must reclaim the real holder.")
		TEST_ASSERT(isturf(keeper.loc), "Both real exit routes must land the apprentice directly on the floor.")
		// Do not reset the normal click/move cooldowns: this is the first real click after surfacing.
		keeper.ClickOn(quarry, list2params(list(LEFT_CLICK = 1, BUTTON = LEFT_CLICK)))
		TEST_ASSERT_EQUAL(trial.ambushes, forced_exit ? 2 : 1, "The real first weapon click must still fit inside the three-second post-exit strike window.")
		qdel(quarry)
	TEST_ASSERT(!QDELETED(trial) && !trial.fulfilled, "Two honest timed strikes must leave the three-strike trial unfinished.")
	TEST_ASSERT(keeper.is_holding(weapon) && !HAS_TRAIT(keeper, TRAIT_IMMOBILIZED), "Natural dive/exit timing must preserve the weapon and release all movement restraints.")

/// Actual in-hand activation and normal attack cooldowns must permit finishing a flammable stock beast.
/datum/unit_test/vestige_ember_real_timing/Run()
	var/turf/breath_floor = get_step(get_step(run_loc_floor_bottom_left, NORTH), EAST)
	var/mob/living/carbon/human/keeper = allocate(/mob/living/carbon/human/consistent, breath_floor)
	keeper.mind_initialize()
	var/datum/vestige_trial/ember_feast/trial = allocate(/datum/vestige_trial/ember_feast, keeper.mind)
	keeper.mind.active_vestige_trial = trial
	trial.on_accepted(keeper)
	var/obj/item/vestige_ember_jaw/jaw = locate() in keeper.held_items
	TEST_ASSERT(jaw, "The timing route must use the real issued jaw.")
	var/obj/item/knife/combat/weapon = allocate(/obj/item/knife/combat)
	TEST_ASSERT(keeper.put_in_hands(weapon), "The keeper must have a normal weapon ready in the other hand.")
	var/mob/living/basic/spider/giant/nurse/quarry = allocate(/mob/living/basic/spider/giant/nurse, get_step(breath_floor, EAST))
	ADD_TRAIT(quarry, TRAIT_AI_PAUSED, TRAIT_SOURCE_UNIT_TESTS)
	var/mob/living/basic/carp/fireproof = allocate(/mob/living/basic/carp, get_step(quarry, EAST))
	ADD_TRAIT(fireproof, TRAIT_AI_PAUSED, TRAIT_SOURCE_UNIT_TESTS)
	TEST_ASSERT(jaw.can_hold_flame(quarry) && !jaw.can_hold_flame(fireproof), "The eligibility feedback must distinguish flammable stock spiders from stock carp.")
	keeper.setDir(EAST)
	var/click_params = list2params(list(LEFT_CLICK = 1, BUTTON = LEFT_CLICK))
	keeper.ClickOn(jaw, click_params)
	TEST_ASSERT(quarry.on_fire && jaw.marked_prey[quarry], "The real item click must ignite and mark the stock spider.")
	TEST_ASSERT(!fireproof.on_fire && !jaw.marked_prey[fireproof], "The same real cone must preserve the carp's intrinsic fire immunity and refuse its credit.")
	TEST_ASSERT(!(fireproof.basic_mob_flags & FLAMMABLE_MOB), "The jaw must never change the stock carp's flammability flag.")
	var/ignited_at = world.time
	keeper.swap_hand(keeper.get_held_index_of_item(weapon))
	for(var/cut in 1 to 2)
		var/deadline = world.time + 3 SECONDS
		while((world.time < keeper.next_move || world.time <= keeper.next_click) && world.time < deadline)
			sleep(world.tick_lag)
		TEST_ASSERT(quarry.on_fire, "The real flame must remain active when the normal weapon click becomes available.")
		keeper.ClickOn(quarry, click_params)
	TEST_ASSERT_EQUAL(quarry.stat, DEAD, "Two normally timed combat-knife clicks must finish the genuinely burning stock nurse spider.")
	TEST_ASSERT_EQUAL(length(trial.devoured), 1, "Only the actual burning kill may enter the meal ledger.")
	TEST_ASSERT(world.time > ignited_at, "This route must allow real time and attack cooldowns to pass after ignition.")
	TEST_ASSERT(!trial.fulfilled, "One real meal must leave the three-meal hunt unfinished.")

/// Stun-immune wild quarry still supplies an actual projectile observation without false immobilization.
/datum/unit_test/vestige_census_immune_observation/Run()
	var/mob/living/carbon/human/keeper = allocate(/mob/living/carbon/human/consistent)
	keeper.mind_initialize()
	var/datum/vestige_trial/comb_census/trial = allocate(/datum/vestige_trial/comb_census, keeper.mind)
	keeper.mind.active_vestige_trial = trial
	trial.on_accepted(keeper)
	var/obj/item/vestige_census_stinger/stinger = trial.stinger
	var/mob/living/basic/spider/giant/nurse/quarry = allocate(/mob/living/basic/spider/giant/nurse, locate(keeper.x + 4, keeper.y, keeper.z))
	TEST_ASSERT(!(quarry.status_flags & CANSTUN), "The route must use a stock beast with intrinsic stun immunity.")
	var/datum/ai_behavior/find_potential_targets/targeting = GET_AI_BEHAVIOR(/datum/ai_behavior/find_potential_targets)
	targeting.perform(0.1, quarry.ai_controller, BB_BASIC_MOB_CURRENT_TARGET, BB_TARGETING_STRATEGY, BB_BASIC_MOB_CURRENT_TARGET_HIDING_LOCATION)
	TEST_ASSERT_EQUAL(vestige_loom_hunted_prey(quarry), keeper, "Stock target selection must establish the real pursuit before firing.")
	TEST_ASSERT_EQUAL(stinger.ranged_interact_with_atom(quarry, keeper, list()), ITEM_INTERACT_SUCCESS, "The actual stinger handler must fire at a new immune pursuer.")
	var/deadline = world.time + 3 SECONDS
	while(!trial.entries && world.time < deadline)
		sleep(world.tick_lag)
	TEST_ASSERT_EQUAL(trial.entries, 1, "The actual projectile impact must still record its eligible pursuit.")
	var/list/observations = trial.entries_per_subject[WEAKREF(quarry)]
	TEST_ASSERT("pursuit" in observations, "The immune beast's earned observation must use its real hunting distance.")
	TEST_ASSERT(!quarry.IsStun() && !HAS_TRAIT(quarry, TRAIT_IMMOBILIZED), "The counted barb must preserve the stock beast's innate stun immunity.")
	TEST_ASSERT(!(quarry.status_flags & CANSTUN), "The Census must never alter a target's intrinsic stun flags.")
	TEST_ASSERT(!trial.fulfilled && !trial.complete_profiles, "One immune pursuit must not complete a profile or the trial.")

/// Let the supplied thief actually path and bite, then answer from a different line at normal movement/attack cadence.
/datum/unit_test/vestige_hunt_route/tremor_autonomous/Run()
	var/turf/center = prepare_ground()
	var/list/line_floors = list(locate(center.x - 3, center.y - 3, center.z), locate(center.x + 2, center.y - 3, center.z), locate(center.x - 3, center.y + 2, center.z))
	var/mob/living/carbon/human/keeper = allocate(/mob/living/carbon/human/consistent, center)
	ADD_TRAIT(keeper, TRAIT_NOBREATH, TRAIT_SOURCE_UNIT_TESTS)
	ADD_TRAIT(keeper, TRAIT_SPACEWALK, TRAIT_SOURCE_UNIT_TESTS)
	keeper.mind_initialize()
	var/datum/vestige_trial/loom_tremor/trial = allocate(/datum/vestige_trial/loom_tremor, keeper.mind)
	keeper.mind.active_vestige_trial = trial
	trial.on_accepted(keeper)
	for(var/turf/line_floor as anything in line_floors)
		keeper.forceMove(line_floor)
		trial.spool.attack_self(keeper)
	TEST_ASSERT_EQUAL(length(trial.lines), 3, "The autonomous route must begin with a normally deployed dispersed net.")
	var/obj/item/knife/combat/weapon = allocate(/obj/item/knife/combat)
	TEST_ASSERT(keeper.put_in_hands(weapon), "The keeper must equip an ordinary knife for the response.")
	keeper.swap_hand(keeper.get_held_index_of_item(weapon))
	trial.next_send_at = world.time // Only initial waiting is shortened; combat and travel run on the real clock.
	TEST_ASSERT(run_pending_callback(trial, TYPE_PROC_REF(/datum/vestige_trial/loom_tremor, loom_beat)), "The actual heartbeat must supply the thief.")
	TEST_ASSERT_EQUAL(length(trial.thieves), 1, "The autonomous route must use the actual single spawned thief.")
	var/mob/living/basic/vestige_silk_thief/thief = trial.thieves[1]
	var/obj/structure/vestige_tremor_line/line = trial.thieves[thief]
	var/turf/thief_start = get_turf(thief)
	var/turf/keeper_start = line_floors[1]
	for(var/turf/candidate as anything in line_floors)
		if(get_dist(candidate, line) > get_dist(keeper_start, line))
			keeper_start = candidate
	keeper.forceMove(keeper_start)
	TEST_ASSERT(get_dist(keeper, line) >= 5, "The response must start at another properly separated line.")
	// As in mouse_bite_cable, clientless unit-test z-levels need an explicit AI wake.
	thief.ai_controller.can_idle = FALSE
	thief.ai_controller.set_ai_status(AI_STATUS_ON)
	thief.ai_controller.SelectBehaviors(SSai_controllers.wait * 0.1)
	var/deadline = world.time + 30 SECONDS
	while(!QDELETED(line) && !line.pinged && world.time < deadline)
		sleep(world.tick_lag)
	TEST_ASSERT(!QDELETED(line) && line.pinged && line.atom_integrity < line.max_integrity, "The real AI must navigate its approach and bite the line without a test-issued attack.")
	TEST_ASSERT(get_turf(thief) != thief_start, "The autonomous thief must physically travel from its announced approach.")
	var/alarm_at = world.time
	for(var/pace in 1 to 15)
		if(QDELETED(thief) || keeper.Adjacent(thief))
			break
		TEST_ASSERT(!QDELETED(line) && (keeper.mobility_flags & MOBILITY_MOVE), "The real line and the keeper's movement must survive the response.")
		var/direction = get_dir(keeper, thief)
		var/step_delay = keeper.cached_multiplicative_slowdown
		if(NSCOMPONENT(direction) && EWCOMPONENT(direction))
			step_delay *= sqrt(2)
		TEST_ASSERT(keeper.Process_Spacemove(direction) && step(keeper, direction), "The keeper must take a valid ordinary step toward the gnawing thief.")
		sleep(max(world.tick_lag, step_delay))
	TEST_ASSERT(!QDELETED(thief) && keeper.Adjacent(thief), "Normally paced travel from another line must reach the actual gnawing thief.")
	var/click_params = list2params(list(LEFT_CLICK = 1, BUTTON = LEFT_CLICK))
	for(var/cut in 1 to 2)
		deadline = world.time + 3 SECONDS
		while((world.time < keeper.next_move || world.time <= keeper.next_click) && world.time < deadline)
			sleep(world.tick_lag)
		TEST_ASSERT(!QDELETED(line), "The responding keeper must finish before the real AI chews through the line.")
		keeper.ClickOn(thief, click_params)
	TEST_ASSERT(QDELETED(thief), "The two normally timed weapon clicks must actually kill the autonomous thief.")
	TEST_ASSERT_EQUAL(trial.answered, 1, "A real alarm, normal travel and actual weapon death must award one in-person answer.")
	TEST_ASSERT(!QDELETED(line) && world.time > alarm_at, "The answer must preserve its line after real response time has elapsed.")
	TEST_ASSERT(!trial.fulfilled, "One autonomous answer must leave the four-answer night unfinished.")
