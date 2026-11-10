// Combat sense for armed hostile human NPCs (voidcrew/modules/human_npcs/human_npc_combat_sense.dm).
// Unit tests compile before voidcrew/_DEFINES, so blackboard keys are written as their strings:
// BB_HUMAN_NPC_COVER "human_npc_cover", BB_HUMAN_NPC_STIM_ITEM "human_npc_stim_item",
// BB_HUMAN_NPC_STUN_SHOOTER "human_npc_stun_shooter". The test room is a 5x5 floor and a test world has
// no clients, so the AI is off: every test drives the subtree and the behaviours directly.

/// A pistol gunner with combat sense
/mob/living/carbon/human/npc/sample/gunner/combat_sense_test
	npc_combat_sense = /datum/npc_combat_sense

/// A knife fighter with combat sense: no gun, and nothing that blocks a bolt (a lit energy sword does)
/mob/living/carbon/human/npc/sample/swashbuckler/combat_sense_test
	npc_combat_sense = /datum/npc_combat_sense
	npc_outfit = /datum/outfit/human_npc/combat_sense_knife

/datum/outfit/human_npc/combat_sense_knife
	name = "Human NPC: knife fighter (combat sense test)"
	uniform = /obj/item/clothing/under/costume/pirate
	shoes = /obj/item/clothing/shoes/jackboots
	r_hand = /obj/item/knife/combat/survival

/// Rules that keep it off the tiles a test lists, the way a family's leash does
/datum/npc_combat_sense/unit_test_leash
	var/list/forbidden = list()

/datum/npc_combat_sense/unit_test_leash/tile_ok(mob/living/carbon/human/npc, datum/ai_controller/controller, turf/tile)
	return !(tile in forbidden) && ..()

/datum/unit_test/voidcrew_human_npc_combat_sense
	abstract_type = /datum/unit_test/voidcrew_human_npc_combat_sense
	/// Floor a test turned into wall, and what it was, put back when the test ends however it ends
	var/list/walled = list()

/datum/unit_test/voidcrew_human_npc_combat_sense/Destroy()
	for(var/turf/spot as anything in walled)
		var/list/was = walled[spot]
		spot.ChangeTurf(was[1], was[2])
	walled = null
	return ..()

/// The floor tile `dx`, `dy` from the room's bottom left
/datum/unit_test/voidcrew_human_npc_combat_sense/proc/tile(dx, dy)
	return locate(run_loc_floor_bottom_left.x + dx, run_loc_floor_bottom_left.y + dy, run_loc_floor_bottom_left.z)

/// Turns floor tile `dx`, `dy` into a wall until the test ends
/datum/unit_test/voidcrew_human_npc_combat_sense/proc/wall(dx, dy)
	var/turf/spot = tile(dx, dy)
	walled[spot] = list(spot.type, spot.baseturfs)
	spot.ChangeTurf(/turf/closed/wall)
	return spot

/// One disabler bolt from `hunter` into `target`'s chest, through tg's bullet_act as a real hit lands
/datum/unit_test/voidcrew_human_npc_combat_sense/proc/stun_hit(mob/living/target, mob/living/hunter)
	var/obj/projectile/beam/disabler/bolt = allocate(/obj/projectile/beam/disabler, get_turf(hunter))
	bolt.firer = hunter
	bolt.starting = get_turf(hunter)
	target.bullet_act(bolt, BODY_ZONE_CHEST)

/// A normal criminal of `tier` fighting in `style`, made the way production makes one (its record as its look)
/datum/unit_test/voidcrew_human_npc_combat_sense/proc/make_normal_criminal(tier, style, turf/where)
	var/datum/bounty_record/record = generate_bounty_record(tier, "normal", "planet", /datum/species/human) // BOUNTY_ARCHETYPE_NORMAL, BOUNTY_PLACEMENT_PLANET
	record.tier = tier
	record.style = style
	var/datum/human_npc_order/order = spawn_human_npc(/mob/living/carbon/human/npc/bounty_criminal/normal, where, look = record, immediate = TRUE)
	var/mob/living/carbon/human/npc/bounty_criminal/normal/criminal = order?.spawned_ref?.resolve()
	qdel(order)
	if(criminal)
		allocated += criminal
		criminal.ai_update_style()
	return criminal

/// Whether `npc`'s rules let it act right now (false while a get-up do_after runs)
/datum/unit_test/voidcrew_human_npc_combat_sense/proc/sense_acts_mid_get_up(mob/living/carbon/human/npc/npc)
	if(!LAZYLEN(npc.do_afters))
		return FALSE
	var/datum/component/npc_combat_sense/sense = npc.GetComponent(/datum/component/npc_combat_sense)
	return sense.rules.can_act(npc, npc.ai_controller)

/// The combat sense subtree's shared instance
/datum/unit_test/voidcrew_human_npc_combat_sense/proc/sense_subtree()
	return GLOB.ai_subtrees[/datum/ai_planning_subtree/npc_combat_sense]

/// A stimulant it carries is used when it tires in a fight, and only then: the real pen, the real reagent.
/datum/unit_test/voidcrew_human_npc_combat_sense/stims

/datum/unit_test/voidcrew_human_npc_combat_sense/stims/Run()
	var/mob/living/carbon/human/npc/sample/gunner/combat_sense_test/npc = allocate(/mob/living/carbon/human/npc/sample/gunner/combat_sense_test, tile(2, 2))
	var/mob/living/carbon/human/consistent/hunter = allocate(/mob/living/carbon/human/consistent, tile(0, 2))
	var/datum/ai_controller/controller = npc.ai_controller
	var/datum/component/npc_combat_sense/sense = npc.GetComponent(/datum/component/npc_combat_sense)
	TEST_ASSERT_NOTNULL(sense, "An NPC type with combat sense didn't get it")
	var/datum/ai_planning_subtree/npc_combat_sense/subtree = sense_subtree()
	TEST_ASSERT(subtree in controller.planning_subtrees, "The human NPC controller doesn't plan combat sense")
	var/datum/ai_behavior/npc_combat_sense_stim/stim = GET_AI_BEHAVIOR(/datum/ai_behavior/npc_combat_sense_stim)
	var/obj/item/gun/gun = locate() in npc.held_items
	TEST_ASSERT_NOTNULL(gun, "Test fixture: the gunner holds no gun")
	controller.set_blackboard_key(BB_BASIC_MOB_CURRENT_TARGET, hunter)

	// Nothing to use: winded or not, nothing is planned
	npc.setStaminaLoss(60)
	TEST_ASSERT_NULL(subtree.SelectBehaviors(controller, 1), "Winded with no stimulant on it, it planned something")
	TEST_ASSERT(sense.next_stim_at > world.time, "Finding no stimulant, it will search its pockets again next plan")
	sense.next_stim_at = 0

	var/obj/item/reagent_containers/hypospray/medipen/stimpack/pen = allocate(/obj/item/reagent_containers/hypospray/medipen/stimpack)
	TEST_ASSERT(npc.equip_to_slot_if_possible(pen, ITEM_SLOT_LPOCKET, disable_warning = TRUE), "Test fixture: the stimpack didn't go in its pocket")
	npc.setStaminaLoss(40)
	TEST_ASSERT_NULL(subtree.SelectBehaviors(controller, 1), "Not yet winded (40 stamina), it reached for its stimulant")
	npc.setStaminaLoss(60)
	TEST_ASSERT_EQUAL(subtree.SelectBehaviors(controller, 1), SUBTREE_RETURN_FINISH_PLANNING, "Winded in a fight, it didn't reach for its stimulant")
	TEST_ASSERT(controller.current_behaviors[stim], "Winded in a fight, it didn't plan to use its stimulant")
	TEST_ASSERT_EQUAL(controller.blackboard["human_npc_stim_item"], pen, "It reached for something other than its stimpack")

	var/finished = FALSE
	for(var/step in 1 to 6)
		npc.next_move = 0
		npc.next_click = 0
		var/result = stim.perform(1, controller, "human_npc_stim_item")
		TEST_ASSERT(!(result & AI_BEHAVIOR_FAILED), "Using the stimulant failed at step [step]")
		if(result & AI_BEHAVIOR_SUCCEEDED)
			finished = TRUE
			break
	TEST_ASSERT(finished, "It never used its stimulant")
	stim.finish_action(controller, TRUE, "human_npc_stim_item")
	TEST_ASSERT(npc.reagents.has_reagent(/datum/reagent/medicine/ephedrine), "The stimpack's ephedrine isn't in its blood")
	TEST_ASSERT(pen.used_up, "The stimpack isn't spent")
	TEST_ASSERT(!npc.is_holding(pen), "It kept the spent stimpack in its hand")
	TEST_ASSERT(npc.is_holding(gun), "It let go of its gun to use the stimulant")
	TEST_ASSERT_EQUAL(sense.stims_used, 1, "The stimulant wasn't counted")

	// One in its blood: a second pen is left alone. Nobody to fight: left alone too. A plain medipen is no stimulant.
	var/obj/item/reagent_containers/hypospray/medipen/stimpack/spare = allocate(/obj/item/reagent_containers/hypospray/medipen/stimpack)
	TEST_ASSERT(npc.equip_to_slot_if_possible(spare, ITEM_SLOT_RPOCKET, disable_warning = TRUE), "Test fixture: the second stimpack didn't go in its pocket")
	TEST_ASSERT_NULL(subtree.SelectBehaviors(controller, 1), "With a stimulant already in its blood, it reached for another")
	npc.reagents.clear_reagents()
	controller.clear_blackboard_key(BB_BASIC_MOB_CURRENT_TARGET)
	TEST_ASSERT_NULL(subtree.SelectBehaviors(controller, 1), "With nobody to fight, it used a stimulant")
	var/obj/item/reagent_containers/hypospray/medipen/plain = allocate(/obj/item/reagent_containers/hypospray/medipen)
	TEST_ASSERT(!human_npc_is_stim(plain), "An epinephrine medipen counts as a stimulant")
	TEST_ASSERT(human_npc_is_stim(spare), "A stimpack doesn't count as a stimulant")
	npc.setStaminaLoss(0)

/// Shot with a disabler in the open, a gunner runs to a tile out of the line of fire, keeps down, then
/// looks out; seen there, it fights; three runs and it stands; it never takes cover off its leash.
/datum/unit_test/voidcrew_human_npc_combat_sense/cover

/datum/unit_test/voidcrew_human_npc_combat_sense/cover/Run()
	// A short wall east of the middle: the far corner behind it is out of a western hunter's line
	wall(3, 3)
	wall(3, 4)
	var/mob/living/carbon/human/npc/sample/gunner/combat_sense_test/npc = allocate(/mob/living/carbon/human/npc/sample/gunner/combat_sense_test, tile(2, 2))
	var/mob/living/carbon/human/consistent/hunter = allocate(/mob/living/carbon/human/consistent, tile(0, 2))
	var/datum/ai_controller/controller = npc.ai_controller
	var/datum/component/npc_combat_sense/sense = npc.GetComponent(/datum/component/npc_combat_sense)
	var/datum/ai_planning_subtree/npc_combat_sense/subtree = sense_subtree()
	var/beam_flags = PASSTABLE | PASSGLASS | PASSGRILLE
	controller.set_blackboard_key(BB_BASIC_MOB_CURRENT_TARGET, hunter)
	TEST_ASSERT(human_npc_line_of_fire(tile(0, 2), tile(2, 2), beam_flags), "Test fixture: the hunter has no line to the NPC")
	TEST_ASSERT(!human_npc_line_of_fire(tile(0, 2), tile(4, 4), beam_flags), "Test fixture: the wall doesn't hide the far corner")

	TEST_ASSERT_NULL(subtree.SelectBehaviors(controller, 1), "It took cover before anyone shot at it")
	stun_hit(npc, hunter)
	TEST_ASSERT_EQUAL(sense.hits, 1, "The disabler hit wasn't noticed")
	TEST_ASSERT(npc.getStaminaLoss() > 0, "Test fixture: the disabler bolt did no stamina damage")
	TEST_ASSERT_EQUAL(subtree.SelectBehaviors(controller, 1), SUBTREE_RETURN_FINISH_PLANNING, "Shot with a disabler in the open, it stood there")
	var/turf/cover = controller.blackboard["human_npc_cover"]
	TEST_ASSERT_NOTNULL(cover, "It picked no cover")
	TEST_ASSERT(cover != get_turf(npc), "It picked the tile it was shot on as cover")
	TEST_ASSERT(!human_npc_line_of_fire(get_turf(hunter), cover, beam_flags), "Its cover is in the hunter's line of fire")
	TEST_ASSERT(get_dist(npc, cover) <= 4, "Its cover is further away than it walks for cover")
	var/datum/ai_behavior/npc_combat_sense_take_cover/take = GET_AI_BEHAVIOR(/datum/ai_behavior/npc_combat_sense_take_cover)
	TEST_ASSERT(controller.current_behaviors[take], "It didn't set off for its cover")
	TEST_ASSERT_EQUAL(controller.current_movement_target, cover, "Its walk isn't to its cover")
	TEST_ASSERT_EQUAL(sense.cover_moves, 1, "The run for cover wasn't counted")
	// Hit again on the way: it keeps going, and that hit is answered by the run
	stun_hit(npc, hunter)
	TEST_ASSERT_EQUAL(subtree.SelectBehaviors(controller, 1), SUBTREE_RETURN_FINISH_PLANNING, "Hit on its way to cover, it stopped")
	TEST_ASSERT_EQUAL(sense.cover_moves, 1, "Hit on its way to cover, it picked new cover")

	// There: it keeps its head down, then looks out again
	npc.forceMove(cover)
	take.finish_action(controller, TRUE, "human_npc_cover")
	TEST_ASSERT_EQUAL(subtree.SelectBehaviors(controller, 1), SUBTREE_RETURN_FINISH_PLANNING, "In cover, it didn't keep its head down")
	TEST_ASSERT(controller.current_behaviors[GET_AI_BEHAVIOR(/datum/ai_behavior/npc_combat_sense_hold)], "In cover, it didn't hold still")
	// Winded, it keeps down past the usual moment (HUMAN_NPC_SENSE_PEEK_AFTER, 2.5 seconds), for tg's own stamina recovery
	sense.arrived_at = world.time - 3 SECONDS
	npc.setStaminaLoss(60)
	TEST_ASSERT_EQUAL(subtree.SelectBehaviors(controller, 1), SUBTREE_RETURN_FINISH_PLANNING, "Winded in cover, it looked out before it got its breath back")
	npc.setStaminaLoss(0)
	TEST_ASSERT_NULL(subtree.SelectBehaviors(controller, 1), "It never looked out of its cover")
	TEST_ASSERT_NULL(sense.cover, "Looking out, it kept its cover plan")

	// Back in cover, seen there: it fights rather than hide
	sense.take_cover(controller, cover)
	sense.arrived_at = world.time
	hunter.forceMove(tile(4, 0))
	TEST_ASSERT(human_npc_line_of_fire(tile(4, 0), cover, beam_flags), "Test fixture: the hunter can't see the cover from the south")
	TEST_ASSERT_NULL(subtree.SelectBehaviors(controller, 1), "Seen in its cover, it kept hiding instead of fighting")
	TEST_ASSERT_NULL(sense.cover, "Seen in its cover, it kept its cover plan")

	// Back in cover, out of the shooter's sight, with the one it fights beside it: it fights, not hides
	hunter.forceMove(tile(0, 2))
	sense.take_cover(controller, cover)
	sense.arrived_at = world.time
	var/mob/living/carbon/human/consistent/bystander = allocate(/mob/living/carbon/human/consistent, get_step(cover, SOUTH))
	controller.set_blackboard_key(BB_BASIC_MOB_CURRENT_TARGET, bystander)
	TEST_ASSERT_NULL(subtree.SelectBehaviors(controller, 1), "In cover with the one it fights beside it, it kept hiding")
	TEST_ASSERT_NULL(sense.cover, "In cover with the one it fights beside it, it kept its cover plan")
	controller.set_blackboard_key(BB_BASIC_MOB_CURRENT_TARGET, hunter)
	bystander.forceMove(tile(0, 0))

	// Out of runs: it stands and fights
	hunter.forceMove(tile(0, 2))
	npc.forceMove(tile(2, 2))
	sense.cover_moves = 3 // HUMAN_NPC_SENSE_COVER_MOVES
	stun_hit(npc, hunter)
	TEST_ASSERT_NULL(subtree.SelectBehaviors(controller, 1), "After three runs for cover it ran a fourth time")

	// A leash with the tiles behind the wall off it: there's no cover it may use, so it fights where it is
	sense.cover_moves = 0
	npc.AddComponent(/datum/component/npc_combat_sense, /datum/npc_combat_sense/unit_test_leash)
	var/datum/npc_combat_sense/unit_test_leash/leash = sense.rules
	TEST_ASSERT(istype(leash), "Test fixture: the rules weren't swapped")
	leash.forbidden = list(tile(4, 3), tile(4, 4))
	stun_hit(npc, hunter)
	var/result = subtree.SelectBehaviors(controller, 1)
	leash.forbidden = list()
	TEST_ASSERT_NULL(result, "It ran for cover off its leash")
	TEST_ASSERT_NULL(sense.cover, "It picked cover off its leash")
	npc.setStaminaLoss(0)

/// A close fighter shot with a disabler charges the shooter it is fighting, then leaves the rest to its melee.
/datum/unit_test/voidcrew_human_npc_combat_sense/close_in

/datum/unit_test/voidcrew_human_npc_combat_sense/close_in/Run()
	var/mob/living/carbon/human/npc/sample/swashbuckler/combat_sense_test/npc = allocate(/mob/living/carbon/human/npc/sample/swashbuckler/combat_sense_test, tile(3, 2))
	var/mob/living/carbon/human/consistent/hunter = allocate(/mob/living/carbon/human/consistent, tile(0, 2))
	var/datum/ai_controller/controller = npc.ai_controller
	var/datum/component/npc_combat_sense/sense = npc.GetComponent(/datum/component/npc_combat_sense)
	var/datum/ai_planning_subtree/npc_combat_sense/subtree = sense_subtree()
	TEST_ASSERT_EQUAL(sense.rules.reach(npc, controller), 1, "A knife fighter with no gun counts as a gunner")
	controller.set_blackboard_key(BB_BASIC_MOB_CURRENT_TARGET, hunter)
	stun_hit(npc, hunter)
	TEST_ASSERT_EQUAL(subtree.SelectBehaviors(controller, 1), SUBTREE_RETURN_FINISH_PLANNING, "A knife fighter shot with a disabler didn't charge")
	TEST_ASSERT(controller.current_behaviors[GET_AI_BEHAVIOR(/datum/ai_behavior/human_npc_close_in)], "A knife fighter shot with a disabler isn't closing in")
	TEST_ASSERT_EQUAL(controller.blackboard["human_npc_stun_shooter"], hunter, "It's charging someone other than its shooter")
	TEST_ASSERT_EQUAL(controller.current_movement_target, hunter, "Its walk isn't at its shooter")
	TEST_ASSERT_NULL(controller.blackboard["human_npc_cover"], "A knife fighter ran for cover")
	npc.forceMove(tile(1, 2))
	TEST_ASSERT_NULL(subtree.SelectBehaviors(controller, 1), "Beside its shooter, it kept charging instead of fighting")
	// Someone it isn't fighting: it doesn't go after them
	var/mob/living/carbon/human/consistent/bystander = allocate(/mob/living/carbon/human/consistent, tile(4, 4))
	npc.forceMove(tile(3, 2))
	stun_hit(npc, bystander)
	TEST_ASSERT_NULL(subtree.SelectBehaviors(controller, 1), "It charged a shooter it wasn't fighting")
	npc.setStaminaLoss(0)

/// Cuffed, in soft crit, in stamcrit or knocked down it does nothing with its combat sense.
/datum/unit_test/voidcrew_human_npc_combat_sense/gate

/datum/unit_test/voidcrew_human_npc_combat_sense/gate/Run()
	var/mob/living/carbon/human/npc/sample/gunner/combat_sense_test/npc = allocate(/mob/living/carbon/human/npc/sample/gunner/combat_sense_test, tile(2, 2))
	var/mob/living/carbon/human/consistent/hunter = allocate(/mob/living/carbon/human/consistent, tile(0, 2))
	var/datum/ai_controller/controller = npc.ai_controller
	var/datum/ai_planning_subtree/npc_combat_sense/subtree = sense_subtree()
	var/datum/ai_behavior/npc_combat_sense_stim/stim = GET_AI_BEHAVIOR(/datum/ai_behavior/npc_combat_sense_stim)
	var/obj/item/reagent_containers/hypospray/medipen/stimpack/pen = allocate(/obj/item/reagent_containers/hypospray/medipen/stimpack)
	TEST_ASSERT(npc.equip_to_slot_if_possible(pen, ITEM_SLOT_LPOCKET, disable_warning = TRUE), "Test fixture: the stimpack didn't go in its pocket")
	controller.set_blackboard_key(BB_BASIC_MOB_CURRENT_TARGET, hunter)
	stun_hit(npc, hunter)

	var/obj/item/restraints/handcuffs/cuffs = allocate(/obj/item/restraints/handcuffs)
	TEST_ASSERT(npc.equip_to_slot_if_possible(cuffs, ITEM_SLOT_HANDCUFFED), "Test fixture: the NPC could not be cuffed")
	npc.setStaminaLoss(60)
	TEST_ASSERT_NULL(subtree.SelectBehaviors(controller, 1), "Cuffed, it still acted on its combat sense")
	TEST_ASSERT(!controller.current_behaviors[stim], "Cuffed, it went for its stimulant")
	TEST_ASSERT_NULL(controller.blackboard["human_npc_cover"], "Cuffed, it ran for cover")
	npc.uncuff()

	npc.adjustToxLoss(110) // awake in soft crit; 50 oxygen damage would knock it out
	TEST_ASSERT_EQUAL(npc.stat, SOFT_CRIT, "Test fixture: the NPC is not in soft crit")
	TEST_ASSERT_NULL(subtree.SelectBehaviors(controller, 1), "In soft crit, it acted on its combat sense")
	npc.setToxLoss(0)
	npc.get_up(instant = TRUE)

	npc.adjustStaminaLoss(200)
	TEST_ASSERT(npc.has_status_effect(/datum/status_effect/incapacitating/stamcrit), "Test fixture: 200 stamina damage did not stamcrit the NPC")
	TEST_ASSERT_NULL(subtree.SelectBehaviors(controller, 1), "In stamcrit, it acted on its combat sense")
	TEST_ASSERT(controller.get_able_to_run() & AI_UNABLE_TO_RUN, "Its AI runs in stamcrit")
	npc.setStaminaLoss(0)
	npc.get_up(instant = TRUE)

	npc.Knockdown(5 SECONDS)
	TEST_ASSERT_NULL(subtree.SelectBehaviors(controller, 1), "Knocked down, it acted on its combat sense")
	npc.SetKnockdown(0)
	npc.get_up(instant = TRUE)

	// tg's own get-up after the knockdown is a second's do_after, and nothing is planned through one
	TEST_ASSERT(!sense_acts_mid_get_up(npc), "Getting up, it acted on its combat sense")
	for(var/wait in 1 to 30)
		if(!LAZYLEN(npc.do_afters))
			break
		sleep(1)

	// Free, on its feet and winded again: the stimulant
	npc.setStaminaLoss(60)
	TEST_ASSERT_EQUAL(npc.body_position, STANDING_UP, "Test fixture: the NPC didn't get back up")
	var/datum/component/npc_combat_sense/sense = npc.GetComponent(/datum/component/npc_combat_sense)
	TEST_ASSERT(sense.rules.can_act(npc, controller), "Free and on its feet, it can't act (stat [npc.stat], traits: [english_list(assoc_to_keys(npc._status_traits))], pulled [npc.pulledby], buckled [npc.buckled], do_afters [LAZYLEN(npc.do_afters)])")
	TEST_ASSERT_NOTNULL(human_npc_find_stim(npc), "Test fixture: its stimpack is gone (it is in [pen.loc])")
	TEST_ASSERT(sense.rules.in_fight(npc, controller, sense), "With a target, it isn't in a fight")
	TEST_ASSERT_EQUAL(subtree.SelectBehaviors(controller, 1), SUBTREE_RETURN_FINISH_PLANNING, "Free and winded in a fight, it didn't go for its stimulant (next try at [sense.next_stim_at], now [world.time])")
	npc.setStaminaLoss(0)

/// Who has it: the armed hostile families, each on an AI that plans it; never a civilian or a prisoner.
/datum/unit_test/voidcrew_human_npc_combat_sense/who

/datum/unit_test/voidcrew_human_npc_combat_sense/who/Run()
	var/list/never = list(
		/mob/living/carbon/human/npc/ambient_npc,
		/mob/living/carbon/human/npc/outpost_prisoner,
		/mob/living/carbon/human/npc/bounty_criminal/meek,
		/mob/living/carbon/human/npc/bounty_criminal/decoy,
		/mob/living/carbon/human/npc/mission_survivor,
	)
	var/datum/ai_planning_subtree/npc_combat_sense/subtree = sense_subtree()
	var/list/checked = list()
	for(var/npc_type in subtypesof(/mob/living/carbon/human/npc))
		var/mob/living/carbon/human/npc/npc_path = npc_type
		var/rules = initial(npc_path.npc_combat_sense)
		for(var/civilian_root in never)
			if(ispath(npc_type, civilian_root))
				TEST_ASSERT_NULL(rules, "[npc_type] is a civilian or a prisoner and has combat sense")
		if(isnull(rules))
			continue
		var/controller_type = initial(npc_path.ai_controller)
		if(checked[controller_type])
			continue
		checked[controller_type] = TRUE
		var/datum/ai_controller/brain = new controller_type()
		var/plans = (subtree in brain.planning_subtrees)
		qdel(brain)
		TEST_ASSERT(plans, "[npc_type] has combat sense but its AI ([controller_type]) never plans it")
	for(var/armed_type in list(
		/mob/living/carbon/human/npc/faction_pirate/silverscale/ranged,
		/mob/living/carbon/human/npc/faction_pirate/grey/captain,
		/mob/living/carbon/human/npc/ruin/trooper/syndicate,
		/mob/living/carbon/human/npc/bounty_criminal/normal,
		/mob/living/carbon/human/npc/bounty_companion,
		/mob/living/carbon/human/npc/outpost_prison_guard,
	))
		var/mob/living/carbon/human/npc/armed_path = armed_type
		TEST_ASSERT_NOTNULL(initial(armed_path.npc_combat_sense), "[armed_type] is an armed hostile without combat sense")

	// A townsperson shot with a disabler has nothing to react with
	var/mob/living/carbon/human/npc/ambient_npc/core_test/civilian = allocate(/mob/living/carbon/human/npc/ambient_npc/core_test, tile(2, 2))
	var/mob/living/carbon/human/consistent/hunter = allocate(/mob/living/carbon/human/consistent, tile(0, 2))
	stun_hit(civilian, hunter)
	TEST_ASSERT_NULL(civilian.GetComponent(/datum/component/npc_combat_sense), "A townsperson has combat sense")
	TEST_ASSERT_NULL(civilian.ai_controller?.blackboard["human_npc_cover"], "A townsperson ran for cover")

/// The families' rules: a Wanted criminal carries a stimpack and keeps cover on its leash; a Petty one
/// carries none; a pirate holding its ground stays put, and a pirate with no crew keeps near home.
/datum/unit_test/voidcrew_human_npc_combat_sense/families

/datum/unit_test/voidcrew_human_npc_combat_sense/families/Run()
	// BOUNTY_TIER_WANTED 2, BOUNTY_STYLE_BRAWLER: a free pocket for the stimpack
	var/mob/living/carbon/human/npc/bounty_criminal/normal/wanted = make_normal_criminal(2, "brawler", tile(2, 2))
	TEST_ASSERT_NOTNULL(wanted, "Test fixture: no Wanted criminal was made")
	var/obj/item/reagent_containers/hypospray/medipen/wanted_stim = human_npc_find_stim(wanted)
	TEST_ASSERT_NOTNULL(wanted_stim, "A Wanted brawler carries no stimpack it can reach")
	TEST_ASSERT_EQUAL(wanted_stim.type, /obj/item/reagent_containers/hypospray/medipen/stimpack, "A Wanted brawler carries the wrong stimulant")
	var/datum/component/npc_combat_sense/sense = wanted.GetComponent(/datum/component/npc_combat_sense)
	TEST_ASSERT_NOTNULL(sense, "A Wanted criminal has no combat sense")
	TEST_ASSERT_EQUAL(sense.rules.reach(wanted, wanted.ai_controller), 1, "A brawler counts as a gunner")
	var/turf/corner = tile(1, 1)
	var/turf/far_corner = tile(3, 3)
	wanted.site_bounds = list(corner.x, corner.y, far_corner.x, far_corner.y, corner.z)
	TEST_ASSERT(sense.rules.tile_ok(wanted, wanted.ai_controller, tile(2, 3)), "A tile on the criminal's leash is refused")
	TEST_ASSERT(!sense.rules.tile_ok(wanted, wanted.ai_controller, tile(4, 4)), "A tile off the criminal's leash is allowed")

	var/mob/living/carbon/human/npc/bounty_criminal/normal/petty = make_normal_criminal(1, "brawler", tile(0, 0)) // BOUNTY_TIER_PETTY
	TEST_ASSERT_NOTNULL(petty, "Test fixture: no Petty criminal was made")
	TEST_ASSERT_NULL(human_npc_find_stim(petty), "A Petty criminal carries a stimpack")
	TEST_ASSERT_NOTNULL(petty.GetComponent(/datum/component/npc_combat_sense), "A Petty criminal has no combat sense")

	var/mob/living/carbon/human/npc/bounty_criminal/normal/most_wanted = make_normal_criminal(3, "club", tile(0, 4)) // BOUNTY_TIER_MOST_WANTED
	TEST_ASSERT_NOTNULL(most_wanted, "Test fixture: no Most Wanted criminal was made")
	// Every Most Wanted is a mini-boss, which carries the combat stimpack (boss_supplies()); a plain one made by hand carries none
	TEST_ASSERT_NULL(human_npc_find_stim(most_wanted), "A plain Most Wanted club fighter carries a stimulant")

	var/mob/living/carbon/human/npc/bounty_criminal/normal/gunman = make_normal_criminal(2, "pistol", tile(4, 4)) // BOUNTY_STYLE_PISTOL
	TEST_ASSERT_NOTNULL(gunman, "Test fixture: no Wanted gunman was made")
	var/datum/component/npc_combat_sense/gunman_sense = gunman.GetComponent(/datum/component/npc_combat_sense)
	TEST_ASSERT(gunman_sense.rules.reach(gunman, gunman.ai_controller) > 3, "A pistol criminal counts as a close fighter") // HUMAN_NPC_SENSE_CLOSE_IN_REACH

	var/datum/human_npc_order/order = spawn_human_npc(/mob/living/carbon/human/npc/faction_pirate/grey/ranged, tile(4, 0), immediate = TRUE)
	var/mob/living/carbon/human/npc/faction_pirate/grey/ranged/pirate = order?.spawned_ref?.resolve()
	qdel(order)
	TEST_ASSERT_NOTNULL(pirate, "Test fixture: no pirate was made")
	allocated += pirate
	var/datum/ai_controller/basic_controller/pirate_crew/brain = pirate.ai_controller
	TEST_ASSERT(istype(brain), "Test fixture: the pirate isn't on the crew AI")
	TEST_ASSERT(sense_subtree() in brain.planning_subtrees, "The pirate crew AI doesn't plan combat sense")
	var/datum/component/npc_combat_sense/pirate_sense = pirate.GetComponent(/datum/component/npc_combat_sense)
	TEST_ASSERT_NOTNULL(pirate_sense, "A pirate has no combat sense")
	TEST_ASSERT(pirate_sense.rules.may_move(pirate, brain), "A pirate may never move for cover")
	brain.target_hold_ground = TRUE
	TEST_ASSERT(!pirate_sense.rules.may_move(pirate, brain), "A pirate holding its ground moves for cover")
	brain.target_hold_ground = FALSE
	brain.set_blackboard_key("pirate_crewless_home", tile(4, 0)) // BB_PIRATE_CREWLESS_HOME
	TEST_ASSERT(pirate_sense.rules.tile_ok(pirate, brain, tile(4, 4)), "A crewless pirate may not take cover near home")
	// Home 15 tiles off, past PIRATE_CREWLESS_LEASH (10): the room is too far from it
	var/turf/far_home = locate(pirate.x + 15, pirate.y, pirate.z) || locate(pirate.x - 15, pirate.y, pirate.z)
	TEST_ASSERT_NOTNULL(far_home, "Test fixture: no tile 15 away from the pirate")
	brain.set_blackboard_key("pirate_crewless_home", far_home)
	TEST_ASSERT(!pirate_sense.rules.tile_ok(pirate, brain, tile(4, 4)), "A crewless pirate takes cover far from home")
