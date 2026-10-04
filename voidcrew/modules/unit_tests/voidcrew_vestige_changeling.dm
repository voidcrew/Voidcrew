/** Behavioral checks for biological sourcing, commanded development and adaptive counters. */

/datum/unit_test/vestige_chrysalis_tissue/Run()
	var/mob/living/carbon/human/keeper = allocate(/mob/living/carbon/human/consistent)
	keeper.mind_initialize()
	var/datum/vestige_trial/birth/trial = allocate(/datum/vestige_trial/birth, keeper.mind)
	keeper.mind.active_vestige_trial = trial
	trial.on_accepted(keeper)
	var/mob/living/basic/carp/carcass = allocate(/mob/living/basic/carp, get_step(keeper, NORTH))
	TEST_ASSERT(vestige_chrysalis_fauna(carcass, keeper), "Ordinary carp must provide a practical source without a human DNA datum.")
	TEST_ASSERT(!vestige_chrysalis_fauna(keeper, keeper), "Human players are not fauna tissue sources.")
	TEST_ASSERT(!trial.egg.sow(carcass, keeper), "A living host must never be consumed as a cradle.")
	carcass.death()
	var/meat_type = vestige_chrysalis_meat(carcass)
	var/meat_before = carcass.butcher_results[meat_type]
	TEST_ASSERT(trial.egg.sow(carcass, keeper), "An unharvested carp corpse must hatch a child.")
	TEST_ASSERT_EQUAL(carcass.butcher_results[meat_type], meat_before - 1, "Hatching must consume exactly one actual harvestable tissue yield.")
	TEST_ASSERT_EQUAL(trial.child.growth, 0, "Hatching alone must not grow the child.")
	TEST_ASSERT(!HAS_TRAIT(trial.child, TRAIT_VENTCRAWLER_ALWAYS), "The child must not inherit headslug vent escape.")
	var/turf/path_tile = get_step(keeper, EAST)
	var/original_type = path_tile.type
	path_tile = path_tile.ChangeTurf(/turf/open/space)
	var/can_follow_in_space = path_tile.can_cross_safely(trial.child)
	path_tile.ChangeTurf(original_type)
	TEST_ASSERT(can_follow_in_space, "The child's avoidance AI must permit the documented space-carp route.")
	TEST_ASSERT(trial.child.egg_lain && !trial.child.sentience_type, "The loan must not be a route to a fertile player headslug.")
	TEST_ASSERT(!length(trial.child.butcher_results) && !length(trial.child.guaranteed_butcher_results), "A loaned child must not provide free harvestable organs or meat.")
	TEST_ASSERT(!trial.egg.sow(carcass, keeper), "An existing live child must prevent a duplicate hatch.")
	TEST_ASSERT(!QDELETED(carcass), "Hatching must preserve the corpse and its remaining player property.")
	var/obj/item/vestige_egg/old_egg = trial.egg
	var/mob/living/basic/headslug/vestige_child/old_child = trial.child
	var/datum/vestige_trial/birth/replacement = allocate(/datum/vestige_trial/birth, keeper.mind)
	keeper.mind.active_vestige_trial = replacement
	TEST_ASSERT(!old_egg.get_trial(keeper), "An old egg cannot resolve a replacement trial of the same type.")
	TEST_ASSERT(!old_child.get_trial(), "An old child cannot develop under a replacement trial.")
	qdel(trial)
	TEST_ASSERT(QDELETED(old_egg) && QDELETED(old_child), "Ending the old trial must reclaim both original and deployed loans.")
	carcass.butcher_results.Cut()
	TEST_ASSERT_NULL(vestige_chrysalis_meat(carcass), "An exhausted carcass cannot provide imaginary tissue.")

/datum/unit_test/vestige_chrysalis_child_development/Run()
	var/mob/living/carbon/human/keeper = allocate(/mob/living/carbon/human/consistent)
	keeper.mind_initialize()
	var/datum/vestige_trial/birth/trial = allocate(/datum/vestige_trial/birth, keeper.mind)
	keeper.mind.active_vestige_trial = trial
	trial.on_accepted(keeper)
	var/mob/living/basic/headslug/vestige_child/child = allocate(/mob/living/basic/headslug/vestige_child)
	child.trial_ref = WEAKREF(trial)
	trial.child = child
	trial.register_loan(child)
	var/mob/living/basic/carp/prey = allocate(/mob/living/basic/carp, get_step(child, NORTH))
	var/undamaged_health = prey.health
	child.melee_attack(prey, ignore_cooldown = TRUE)
	TEST_ASSERT_EQUAL(prey.health, undamaged_health, "Direct melee calls cannot bypass the required current command.")
	TEST_ASSERT_EQUAL(child.growth, 0, "An uncommanded attack cannot advance growth.")
	TEST_ASSERT(trial.egg.command_child(prey, keeper), "The real egg control must establish the attack command.")
	prey.adjustBruteLoss(prey.maxHealth - 3)
	TEST_ASSERT(child.melee_attack(prey, ignore_cooldown = TRUE), "A commanded larva must perform a real attack.")
	TEST_ASSERT_EQUAL(prey.stat, DEAD, "The small prey must actually die in this setup.")
	TEST_ASSERT_EQUAL(child.growth, 3, "A nearly dead target provides only its remaining living tissue, not the full nominal hit.")
	child.melee_attack(prey, ignore_cooldown = TRUE)
	TEST_ASSERT_EQUAL(child.growth, 3, "Repeated corpse attacks must not develop the child.")
	child.adjust_health(30)
	keeper.dropItemToGround(keeper.get_inactive_held_item())
	var/obj/item/food/fishmeat/carp/food = allocate(/obj/item/food/fishmeat/carp)
	keeper.put_in_hands(food)
	TEST_ASSERT(child.nourish(food, keeper), "Ordinary carp fillets must provide recovery without a previous boon.")
	TEST_ASSERT_EQUAL(child.health, 40, "A meal heals exactly 25 of the child's 45 health.")
	TEST_ASSERT_EQUAL(child.growth, 3, "Feeding safe food cannot substitute for commanded hunting.")
	var/mob/living/basic/carp/next_prey = allocate(/mob/living/basic/carp, get_step(child, NORTH))
	child.prey_ref = WEAKREF(next_prey)
	next_prey.forceMove(get_step(get_step(child, EAST), EAST))
	TEST_ASSERT(!child.melee_attack(next_prey, ignore_cooldown = TRUE), "Direct melee calls must still require adjacency.")
	next_prey.forceMove(get_step(child, NORTH))
	keeper.death()
	TEST_ASSERT(!child.melee_attack(next_prey, ignore_cooldown = TRUE), "A dead keeper cannot keep earning development from autonomous attacks.")
	TEST_ASSERT_EQUAL(child.growth, 3, "Death must leave the previous progress unchanged.")

/// Hatching on a planet must permit the real AI attack path, not just direct melee calls.
/datum/unit_test/vestige_chrysalis_planet_hunting/Run()
	var/mob/living/carbon/human/keeper = allocate(/mob/living/carbon/human/consistent)
	keeper.mind_initialize()
	var/datum/vestige_trial/birth/trial = allocate(/datum/vestige_trial/birth, keeper.mind)
	keeper.mind.active_vestige_trial = trial
	trial.on_accepted(keeper)
	var/turf/cradle = get_step(keeper, NORTH)
	var/datum/space_level/test_level = SSmapping.z_list[cradle.z]
	TEST_ASSERT(test_level, "The hunting test needs a space level for its planetary footprint.")
	// Keep the visiting keeper outside the footprint, as with a crew member arriving by shuttle.
	var/datum/map_footprint/planet = allocate(/datum/map_footprint, null, "planet", 1)
	planet.attach_level(test_level)
	planet.set_rect(cradle.x, cradle.y, 1, 2)
	planet.enable_planetary_faction()
	var/mob/living/basic/carp/carcass = allocate(/mob/living/basic/carp, cradle)
	TEST_ASSERT(planet.planetary_faction in carcass.faction, "The cradle must actually belong to the planet's fauna alliance.")
	carcass.death()
	TEST_ASSERT(trial.egg.sow(carcass, keeper), "A planet-native carcass must hatch the commanded child.")
	var/mob/living/basic/headslug/vestige_child/child = trial.child
	TEST_ASSERT(!(planet.planetary_faction in child.faction), "The child must not join the alliance of the wildlife it needs to hunt.")
	TEST_ASSERT(REF(child) in child.faction, "Excluding the planet faction must preserve the child's own identity.")
	TEST_ASSERT(child.faction_check_atom(keeper), "The child must remain allied with its keeper.")
	planet.add_planetary_faction_to_existing_mobs()
	TEST_ASSERT(!(planet.planetary_faction in child.faction), "A later planet pass must not turn the child into native wildlife.")
	TEST_ASSERT(!inherit_planetary_faction(child), "An explicit faction refresh must also respect the child's allegiance.")
	var/datum/ai_controller/controller = child.ai_controller
	var/datum/targeting_strategy/strategy = GET_TARGETING_STRATEGY(controller.blackboard[BB_TARGETING_STRATEGY])
	var/datum/ai_behavior/basic_melee_attack/bite = GET_AI_BEHAVIOR(/datum/ai_behavior/basic_melee_attack)
	var/list/prey_types = list(/mob/living/basic/mining/goliath, /mob/living/basic/trooper/pirate/melee, /mob/living/basic/carp)
	for(var/prey_type in prey_types)
		var/mob/living/basic/prey = allocate(prey_type, get_step(cradle, NORTH))
		TEST_ASSERT(planet.planetary_faction in prey.faction, "The [prey.type] must retain its native planet alliance.")
		TEST_ASSERT(trial.egg.command_child(prey, keeper), "The egg must accept a hunt command for [prey.type].")
		controller.SelectBehaviors(0.2)
		TEST_ASSERT_EQUAL(controller.current_movement_target, prey, "The child must pursue the commanded [prey.type].")
		TEST_ASSERT(strategy.can_attack(child, prey), "The AI must allow the child to bite planet-native [prey.type].")
		var/health_before = prey.health
		var/growth_before = child.growth
		// Expire the bite windup and click cooldowns without bypassing AI validation or dispatch.
		controller.set_blackboard_key(BB_BASIC_MOB_MELEE_COOLDOWN_TIMER, world.time)
		child.next_move = 0
		child.next_click = 0
		controller.ProcessBehavior(0.2, bite)
		TEST_ASSERT_EQUAL(prey.health, health_before - 5, "The AI must land a real bite on [prey.type].")
		TEST_ASSERT_EQUAL(child.growth, growth_before + 5, "AI damage to [prey.type] must advance the trial.")
		qdel(prey)
	TEST_ASSERT(!trial.egg.command_child(keeper, keeper), "The faction exemption must not permit hunting the keeper.")
	var/mob/living/basic/carp/friend = allocate(/mob/living/basic/carp, get_step(cradle, NORTH))
	friend.faction |= REF(keeper)
	TEST_ASSERT(!trial.egg.command_child(friend, keeper), "The child must still refuse fauna allied with its keeper.")

/datum/unit_test/vestige_chrysalis_adaptive_counter/Run()
	var/mob/living/carbon/human/keeper = allocate(/mob/living/carbon/human/consistent)
	keeper.mind_initialize()
	var/datum/vestige_trial/faces/trial = allocate(/datum/vestige_trial/faces, keeper.mind)
	keeper.mind.active_vestige_trial = trial
	trial.on_accepted(keeper)
	var/obj/item/vestige_proboscis/organ = trial.proboscis
	var/mob/living/basic/carp/prey = allocate(/mob/living/basic/carp, get_step(keeper, NORTH))
	TEST_ASSERT(!organ.begin_brace(keeper), "The adaptation needs actual sampled tissue first.")
	trial.sampled = TRUE
	TEST_ASSERT(!organ.counter_lash(prey, keeper), "Repeated unprepared pokes cannot award tissue.")
	TEST_ASSERT(organ.begin_brace(keeper), "A sampled organ must offer the defensive form.")
	TEST_ASSERT(HAS_TRAIT(keeper, TRAIT_IMMOBILIZED), "Bracing must impose its real movement cost.")
	var/before = keeper.getBruteLoss()
	prey.melee_attack(keeper, ignore_cooldown = TRUE)
	TEST_ASSERT_EQUAL(keeper.getBruteLoss(), before, "The brace must block a real basic-fauna melee strike.")
	TEST_ASSERT(!HAS_TRAIT(keeper, TRAIT_IMMOBILIZED), "Catching a bite must release the brace for repositioning.")
	TEST_ASSERT_EQUAL(organ.attacker_ref?.resolve(), prey, "The counter must be bound to the actual attacker.")
	TEST_ASSERT(!organ.counter_lash(prey, keeper), "Standing at the impact point must not finish the counter.")
	var/turf/retreat = get_step(get_step(keeper, EAST), EAST)
	keeper.forceMove(retreat)
	var/mob/living/basic/carp/other = allocate(/mob/living/basic/carp, get_step(keeper, NORTH))
	TEST_ASSERT(!organ.counter_lash(other, keeper), "A different animal cannot be substituted after a safe block.")
	TEST_ASSERT(organ.counter_lash(prey, keeper), "Moving away and countering the same live attacker must assimilate real tissue.")
	TEST_ASSERT_EQUAL(trial.assimilated, 20, "The counter credits actual damage.")
	TEST_ASSERT(!organ.counter_lash(prey, keeper), "A counter is consumed exactly once.")
	var/tissue_before_ordinary_hit = trial.assimilated
	prey.adjustBruteLoss(1)
	TEST_ASSERT_EQUAL(trial.assimilated, tissue_before_ordinary_hit, "Ordinary combat damage cannot advance the adaptation trial.")
	prey.adjustBruteLoss(-1)
	organ.brace_ready_at = world.time
	prey.forceMove(get_step(keeper, NORTH))
	TEST_ASSERT(organ.begin_brace(keeper), "The form can be retried once its cooldown ends.")
	prey.melee_attack(keeper, ignore_cooldown = TRUE)
	keeper.forceMove(get_step(get_step(keeper, EAST), EAST))
	TEST_ASSERT(organ.counter_lash(prey, keeper), "The remaining living tissue can be assimilated in a second actual counter.")
	TEST_ASSERT_EQUAL(trial.assimilated, 25, "A five-health target must not provide twenty more tissue.")

/datum/unit_test/vestige_chrysalis_adaptation_cleanup/Run()
	var/mob/living/carbon/human/keeper = allocate(/mob/living/carbon/human/consistent)
	keeper.mind_initialize()
	var/datum/vestige_trial/faces/trial = allocate(/datum/vestige_trial/faces, keeper.mind)
	keeper.mind.active_vestige_trial = trial
	trial.on_accepted(keeper)
	trial.sampled = TRUE
	var/obj/item/vestige_proboscis/organ = trial.proboscis
	TEST_ASSERT(organ.begin_brace(keeper), "Begin the old body's brace.")
	var/mob/living/carbon/human/new_body = allocate(/mob/living/carbon/human/consistent)
	keeper.mind.transfer_to(new_body)
	TEST_ASSERT(!HAS_TRAIT(keeper, TRAIT_IMMOBILIZED), "Body transfer must clean the old body's root immediately.")
	TEST_ASSERT_NULL(organ.body_ref, "A body transfer must discard the old counter, not transfer a borrowed defensive state.")
	TEST_ASSERT(!organ.get_trial(keeper), "The old body may not use a mind-bound kit.")
	keeper.dropItemToGround(organ)
	new_body.put_in_hands(organ)
	organ.brace_ready_at = world.time
	TEST_ASSERT(organ.begin_brace(new_body), "The same mind can explicitly use its organ in the new body.")
	new_body.dropItemToGround(organ)
	TEST_ASSERT(!HAS_TRAIT(new_body, TRAIT_IMMOBILIZED), "Dropping the loan must immediately remove its temporary root.")
	new_body.put_in_hands(organ)
	organ.brace_ready_at = world.time
	organ.begin_brace(new_body)
	var/mob/living/basic/carp/attacker = allocate(/mob/living/basic/carp, get_step(new_body, NORTH))
	attacker.melee_attack(new_body, ignore_cooldown = TRUE)
	TEST_ASSERT(organ.attacker_ref, "Prepare a real pending counter before death.")
	new_body.death()
	TEST_ASSERT_NULL(organ.attacker_ref, "Death must discard even a counter whose brace has already ended.")
	qdel(trial)
	TEST_ASSERT(QDELETED(organ), "Ending the attempt must reclaim its adaptation organ.")
	TEST_ASSERT(!HAS_TRAIT_FROM(new_body, TRAIT_IMMOBILIZED, TRAIT_STATUS_EFFECT("vestige_chrysalis_brace")), "Reclaiming the organ must remove its own brace restraint.")
	TEST_ASSERT(HAS_TRAIT_FROM(new_body, TRAIT_IMMOBILIZED, TRAIT_KNOCKEDOUT), "Removing the brace must preserve the body's legitimate death restraint.")

/// Some eligible wildlife disappears immediately on death; the killing bite still fed the child.
/mob/living/basic/carp/vestige_chrysalis_fleeting
	basic_mob_flags = DEL_ON_DEATH

/datum/unit_test/vestige_chrysalis_lethal_development/Run()
	var/mob/living/carbon/human/keeper = allocate(/mob/living/carbon/human/consistent)
	keeper.mind_initialize()
	var/datum/vestige_trial/birth/trial = allocate(/datum/vestige_trial/birth, keeper.mind)
	keeper.mind.active_vestige_trial = trial
	trial.on_accepted(keeper)
	var/mob/living/basic/headslug/vestige_child/child = allocate(/mob/living/basic/headslug/vestige_child, get_turf(keeper))
	trial.child = trial.register_loan(child)
	child.trial_ref = WEAKREF(trial)
	var/mob/living/basic/carp/vestige_chrysalis_fleeting/prey = allocate(/mob/living/basic/carp/vestige_chrysalis_fleeting, get_step(child, NORTH))
	prey.adjustBruteLoss(prey.maxHealth - 3)
	TEST_ASSERT(trial.egg.command_child(prey, keeper), "A self-deleting wild animal must accept an ordinary hunt command.")
	TEST_ASSERT(child.melee_attack(prey, ignore_cooldown = TRUE), "The commanded child must land the killing bite.")
	TEST_ASSERT(QDELETED(prey), "The wildlife must really delete itself in the damage pipeline.")
	TEST_ASSERT_EQUAL(child.growth, 3, "Immediate deletion must not discard the remaining three points of living tissue.")
	child.growth = 40
	child.mind_initialize()
	trial.egg.attack_self(keeper)
	TEST_ASSERT(!trial.fulfilled, "A child that acquired a player mind must not be sent home as a disposable loan.")

/// The counter measures movement relative to its ship and counts a lethal lash before actor cleanup.
/datum/unit_test/vestige_chrysalis_moving_counter/Run()
	var/mob/living/carbon/human/keeper = allocate(/mob/living/carbon/human/consistent, get_step(run_loc_floor_bottom_left, NORTH))
	keeper.mind_initialize()
	var/datum/vestige_trial/faces/trial = allocate(/datum/vestige_trial/faces, keeper.mind)
	keeper.mind.active_vestige_trial = trial
	trial.on_accepted(keeper)
	trial.sampled = TRUE
	var/obj/item/vestige_proboscis/organ = trial.proboscis
	var/mob/living/basic/carp/vestige_chrysalis_fleeting/prey = allocate(/mob/living/basic/carp/vestige_chrysalis_fleeting, get_step(keeper, NORTH))
	prey.adjustBruteLoss(prey.maxHealth - 3)
	TEST_ASSERT(organ.begin_brace(keeper), "Prepare an ordinary defensive adaptation.")
	prey.melee_attack(keeper, ignore_cooldown = TRUE)
	var/obj/effect/vestige_trial_marker/impact = organ.impact_point
	TEST_ASSERT(impact, "A real bite must mark its impact on the deck.")
	keeper.forceMove(get_step(get_step(keeper, EAST), EAST))
	prey.forceMove(get_step(keeper, NORTH))
	impact.forceMove(get_turf(keeper))
	TEST_ASSERT(!organ.counter_lash(prey, keeper), "Transporting the keeper and impact together must not substitute for retreating.")
	keeper.forceMove(get_step(get_step(keeper, EAST), EAST))
	TEST_ASSERT(organ.counter_lash(prey, keeper), "Moving away from the transported impact must permit the counter.")
	TEST_ASSERT(QDELETED(prey), "The actual lash must delete this fragile target.")
	TEST_ASSERT_EQUAL(trial.assimilated, 3, "A self-deleting target contributes exactly its remaining living tissue.")
	TEST_ASSERT(QDELETED(impact), "Consuming a counter must reclaim its temporary spatial marker.")

/// The upgrade must retain upstream armor penetration as it replaces an already formed blade.
/datum/unit_test/vestige_chrysalis_armblade_upgrade/Run()
	var/mob/living/carbon/human/keeper = allocate(/mob/living/carbon/human/consistent)
	keeper.mind_initialize()
	var/datum/action/cooldown/spell/vestige_armblade/base = allocate(/datum/action/cooldown/spell/vestige_armblade, keeper.mind)
	base.Grant(keeper)
	TEST_ASSERT(base.Activate(keeper), "The base boon must form its blade through the ordinary spell chain.")
	var/obj/item/melee/arm_blade/original = locate() in keeper.held_items
	TEST_ASSERT(original, "The initial cast did not equip a blade.")
	var/original_penetration = original.armour_penetration
	var/original_force = original.force
	var/datum/action/cooldown/spell/vestige_armblade/perfected/upgrade = allocate(/datum/action/cooldown/spell/vestige_armblade/perfected, keeper.mind)
	upgrade.Grant(keeper)
	TEST_ASSERT(upgrade.Activate(keeper), "The upgraded spell must reshape the held old blade.")
	var/obj/item/melee/arm_blade/vestige_perfected/replacement = locate() in keeper.held_items
	TEST_ASSERT(QDELETED(original) && replacement, "An upgrade cast must replace the obsolete NODROP blade in place.")
	TEST_ASSERT(replacement.armour_penetration >= original_penetration, "Perfecting the blade must not reduce upstream armor penetration.")
	TEST_ASSERT(replacement.force >= original_force, "The perfected blade must not reduce melee force.")

/// A mind-bound growth must not strand an undismissable armblade in an abandoned body.
/datum/unit_test/vestige_chrysalis_armblade_body_and_upgrade/Run()
	var/mob/living/carbon/human/keeper = allocate(/mob/living/carbon/human/consistent)
	keeper.mind_initialize()
	var/mob/living/carbon/human/replacement = allocate(/mob/living/carbon/human/consistent)
	var/datum/action/cooldown/spell/vestige_armblade/base = allocate(/datum/action/cooldown/spell/vestige_armblade, keeper.mind)
	base.Grant(keeper)
	TEST_ASSERT(base.Activate(keeper), "The base action must form an actual held blade.")
	var/obj/item/melee/arm_blade/abandoned = locate() in keeper.held_items
	TEST_ASSERT(abandoned, "The base blade was not equipped.")
	keeper.mind.transfer_to(replacement)
	TEST_ASSERT(QDELETED(abandoned), "Transferring the mind must retract its old body's NODROP blade.")
	TEST_ASSERT_EQUAL(base.owner, replacement, "The armblade action must follow the real mind transfer.")
	base.reset_spell_cooldown()
	TEST_ASSERT(base.Activate(replacement), "The replacement body must be able to grow a fresh blade.")
	var/obj/item/melee/arm_blade/prior = locate() in replacement.held_items
	var/datum/vestige_boon/spell/armblade/perfected/upgrade = allocate(/datum/vestige_boon/spell/armblade/perfected)
	upgrade.grant(replacement, replacement.mind)
	TEST_ASSERT(QDELETED(prior), "The real boon upgrade must retract the obsolete growth before replacing its action.")
	var/datum/action/cooldown/spell/vestige_armblade/perfected/improved = locate() in replacement.actions
	TEST_ASSERT(improved && improved.Activate(replacement), "The actual upgraded action must form the perfected blade.")
	var/obj/item/melee/arm_blade/vestige_perfected/perfected_blade = locate() in replacement.held_items
	TEST_ASSERT(perfected_blade, "The upgrade did not equip its stronger blade.")
	var/obj/item/melee/arm_blade/independent = allocate(/obj/item/melee/arm_blade, replacement)
	TEST_ASSERT(replacement.put_in_hands(independent), "The fixture needs an unrelated armblade in the other hand.")
	qdel(improved)
	TEST_ASSERT(QDELETED(perfected_blade), "Deleting the action must retract its own growth.")
	TEST_ASSERT(!QDELETED(independent), "Action removal must preserve an independently granted armblade.")
