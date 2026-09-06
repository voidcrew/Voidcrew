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

/// The actual jaw cone marks three ordinary beasts, whose actual weapon deaths complete the hunt.
/datum/unit_test/vestige_ember_feast_complete_route/Run()
	var/mob/living/carbon/human/keeper = allocate(/mob/living/carbon/human/consistent)
	keeper.mind_initialize()
	var/datum/mind/hunter_mind = keeper.mind
	var/datum/vestige_trial/ember_feast/trial = allocate(/datum/vestige_trial/ember_feast, hunter_mind, "Test Unfed", list(/datum/vestige_boon/spell/armblade))
	hunter_mind.active_vestige_trial = trial
	trial.on_accepted(keeper)
	var/obj/item/vestige_ember_jaw/jaw = locate() in keeper.held_items
	TEST_ASSERT(jaw, "Accepting the pact must hand over its actual ember-jaw.")
	var/list/quarry = list()
	var/turf/prey_floor = get_turf(keeper)
	for(var/meal in 1 to 3)
		prey_floor = get_step(prey_floor, EAST)
		var/mob/living/basic/carp/beast = allocate(/mob/living/basic/carp, prey_floor)
		ADD_TRAIT(beast, TRAIT_AI_PAUSED, TRAIT_GENERIC)
		quarry += beast
	keeper.setDir(EAST)
	jaw.attack_self(keeper)
	TEST_ASSERT_EQUAL(length(jaw.marked_prey), 3, "The real in-hand breath must mark three ordinary carp in its cone.")
	var/obj/item/knife/combat/weapon = allocate(/obj/item/knife/combat)
	TEST_ASSERT(keeper.put_in_hands(weapon), "The route needs an ordinary held weapon beside the jaw.")
	for(var/mob/living/basic/carp/beast as anything in quarry)
		TEST_ASSERT(beast.on_fire && beast.stat != DEAD, "The breath must leave each carp alive and genuinely burning.")
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
