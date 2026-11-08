// Human NPC shared pieces, phase A2 (voidcrew/modules/human_npcs/). Unit tests compile before
// voidcrew/_DEFINES, so values from there are written out: zones ZONE_GREEN 1, ZONE_YELLOW 2,
// ZONE_RED 3; sites HUMAN_NPC_SITE_VACUUM 1, _BAD_AIR 2, _COLD 4; blackboard keys and bark kinds by
// their strings.

/// A voice with a death line, for the death hook.
/datum/human_npc_voice/unit_test
	emotes = list("death" = list("goes still."))

/// Dressed for vacuum wherever it spawns.
/mob/living/carbon/human/npc/sample/raider/unit_test_spacer
	npc_always_site = 1

/// Dressed for the cold wherever it spawns.
/mob/living/carbon/human/npc/sample/raider/unit_test_cold
	npc_always_site = 4

/// A skeleton dressed for vacuum: its species needs nothing.
/mob/living/carbon/human/npc/sample/raider/unit_test_skeleton
	npc_always_site = 1
	npc_look = /obj/effect/mob_spawn/corpse/human/old_pirate_captain

/// A prisoner: nothing it carries is locked (owner ruling OC-11).
/mob/living/carbon/human/npc/sample/gunner/unit_test_prisoner
	npc_gear_locked = FALSE

/// N4: dead, in crit or cuffed is out of the fight; stamcrit isn't; a basic mob is out only once dead.
/datum/unit_test/voidcrew_human_npc_out_of_fight

/datum/unit_test/voidcrew_human_npc_out_of_fight/Run()
	var/mob/living/carbon/human/npc/sample/gunner/npc = allocate(/mob/living/carbon/human/npc/sample/gunner)
	TEST_ASSERT(!human_npc_out_of_fight(npc), "A healthy human NPC counts as out of the fight")
	npc.adjustStaminaLoss(200)
	TEST_ASSERT(npc.has_status_effect(/datum/status_effect/incapacitating/stamcrit), "Test fixture: 200 stamina damage did not stamcrit the NPC")
	TEST_ASSERT(!human_npc_out_of_fight(npc), "A stamcrit NPC counts as out of the fight")
	npc.setStaminaLoss(0)

	npc.adjustToxLoss(110) // toxin, not oxygen: 50 oxygen damage knocks a carbon out (tg check_passout())
	TEST_ASSERT_EQUAL(npc.stat, SOFT_CRIT, "Test fixture: 110 toxin damage did not put the NPC in soft crit")
	TEST_ASSERT(human_npc_out_of_fight(npc), "An NPC in soft crit is still in the fight")
	npc.setToxLoss(0)
	TEST_ASSERT(!human_npc_out_of_fight(npc), "An NPC healed out of crit is still out of the fight")

	var/obj/item/restraints/handcuffs/cuffs = allocate(/obj/item/restraints/handcuffs)
	TEST_ASSERT(npc.equip_to_slot_if_possible(cuffs, ITEM_SLOT_HANDCUFFED), "Test fixture: the NPC could not be cuffed")
	TEST_ASSERT(human_npc_out_of_fight(npc), "A cuffed NPC is still in the fight")
	npc.uncuff()

	npc.death()
	TEST_ASSERT(human_npc_out_of_fight(npc), "A dead NPC is still in the fight")
	var/mob/living/basic/mouse/mouse = allocate(/mob/living/basic/mouse)
	TEST_ASSERT(!human_npc_out_of_fight(mouse), "A living basic mob counts as out of the fight")

/// Builds a human NPC on the test floor dressed for `zone`, whatever zone the test level has.
/datum/unit_test/proc/human_npc_build_in_zone(npc_type, zone)
	var/datum/human_npc_order/order = new /datum/human_npc_order(npc_type, run_loc_floor_bottom_left)
	order.zone = zone
	var/mob/living/carbon/human/npc/npc = order.fulfil()
	qdel(order)
	if(npc)
		allocated += npc
	return npc

/// N5: pirate-family NPCs keep shooting someone in crit; criminal-family NPCs stop.
/datum/unit_test/voidcrew_human_npc_target_stat

/datum/unit_test/voidcrew_human_npc_target_stat/Run()
	var/mob/living/carbon/human/npc/sample/gunner/finisher = allocate(/mob/living/carbon/human/npc/sample/gunner)
	var/mob/living/carbon/human/npc/sample/thug/spare = allocate(/mob/living/carbon/human/npc/sample/thug, locate(run_loc_floor_bottom_left.x, run_loc_floor_bottom_left.y + 1, run_loc_floor_bottom_left.z))
	var/mob/living/carbon/human/consistent/victim = allocate(/mob/living/carbon/human/consistent, locate(run_loc_floor_bottom_left.x + 2, run_loc_floor_bottom_left.y, run_loc_floor_bottom_left.z))
	TEST_ASSERT_EQUAL(finisher.ai_controller.blackboard[BB_TARGET_MINIMUM_STAT], HARD_CRIT, "A pirate-family NPC's AI didn't get its target stat")
	TEST_ASSERT_EQUAL(spare.ai_controller.blackboard[BB_TARGET_MINIMUM_STAT], CONSCIOUS, "A criminal-family NPC's AI didn't get its target stat")
	var/datum/targeting_strategy/strategy = GET_TARGETING_STRATEGY(/datum/targeting_strategy/basic/human_npc)
	TEST_ASSERT(strategy.can_attack(finisher, victim), "Test fixture: the pirate-family NPC won't fight a healthy person")
	TEST_ASSERT(strategy.can_attack(spare, victim), "Test fixture: the criminal-family NPC won't fight a healthy person")
	victim.adjustToxLoss(110) // awake in soft crit; 50 oxygen damage would knock them out
	TEST_ASSERT_EQUAL(victim.stat, SOFT_CRIT, "Test fixture: the victim is not in soft crit")
	TEST_ASSERT(strategy.can_attack(finisher, victim), "A pirate-family NPC stopped attacking someone in soft crit")
	TEST_ASSERT(!strategy.can_attack(spare, victim), "A criminal-family NPC keeps attacking someone in crit")

/// N3: barks fire on real tg changes (crit, stamcrit, cuffs, working the cuffs, breaking a grab, death),
/// are rate-limited, and a mute NPC only shows its emotes.
/datum/unit_test/voidcrew_human_npc_barks

/datum/unit_test/voidcrew_human_npc_barks/Run()
	var/mob/living/carbon/human/npc/sample/gunner/npc = allocate(/mob/living/carbon/human/npc/sample/gunner)
	npc.adjustOxyLoss(110)
	TEST_ASSERT_EQUAL(npc.npc_last_bark, "downed", "Entering crit gave no downed line")
	npc.npc_bark_cooldown = 0
	npc.setOxyLoss(0)
	TEST_ASSERT_EQUAL(npc.npc_last_bark, "recover", "Leaving crit gave no recover line")

	npc.npc_last_bark = null
	npc.npc_bark_cooldown = 0
	npc.adjustStaminaLoss(200)
	npc.setStaminaLoss(0)
	TEST_ASSERT(!npc.has_status_effect(/datum/status_effect/incapacitating/stamcrit), "Test fixture: stamcrit did not end")
	TEST_ASSERT_EQUAL(npc.npc_last_bark, "recover", "Getting up from stamcrit gave no recover line")

	npc.npc_bark_cooldown = 0
	var/obj/item/restraints/handcuffs/cuffs = allocate(/obj/item/restraints/handcuffs)
	TEST_ASSERT(npc.equip_to_slot_if_possible(cuffs, ITEM_SLOT_HANDCUFFED), "Test fixture: the NPC could not be cuffed")
	TEST_ASSERT_EQUAL(npc.npc_last_bark, "cuffed", "Being cuffed gave no cuffed line")
	npc.npc_bark_cooldown = 0
	SEND_SIGNAL(npc, COMSIG_MOB_REMOVING_CUFFS, cuffs)
	TEST_ASSERT_EQUAL(npc.npc_last_bark, "slipping_cuffs", "Working at its cuffs gave no line")
	npc.npc_bark_cooldown = 0
	npc.uncuff()
	TEST_ASSERT_EQUAL(npc.npc_last_bark, "uncuffed", "Its cuffs coming off gave no line")

	// A passive grab breaks on the first resist, in the same call, for someone on their feet (prone, it
	// takes a roll). tg's get-up after the stamcrit is a second's do_after the test doesn't wait for.
	npc.get_up(instant = TRUE)
	TEST_ASSERT_EQUAL(npc.body_position, STANDING_UP, "Test fixture: the NPC did not get back up")
	var/mob/living/carbon/human/consistent/grabber = allocate(/mob/living/carbon/human/consistent, locate(run_loc_floor_bottom_left.x + 1, run_loc_floor_bottom_left.y, run_loc_floor_bottom_left.z))
	grabber.start_pulling(npc)
	TEST_ASSERT_EQUAL(npc.pulledby, grabber, "Test fixture: the grab didn't take")
	npc.npc_bark_cooldown = 0
	npc.next_move = 0
	npc.execute_resist()
	TEST_ASSERT_NULL(npc.pulledby, "Test fixture: resisting did not break the grab")
	TEST_ASSERT_EQUAL(npc.npc_last_bark, "pulled_free", "Pulling free of a grab gave no line")

	// Rate limit: straight after a line, the next waits; surrender and death don't.
	TEST_ASSERT(!npc.npc_bark("cuffed"), "A bark ignored the cooldown")
	TEST_ASSERT(npc.npc_bark("cuffed", force = TRUE), "A forced bark was held back by the cooldown")

	// Mute: a kind with only spoken lines gives nothing, one with an emote still shows it.
	npc.npc_bark_cooldown = 0
	ADD_TRAIT(npc, TRAIT_MUTE, TRAIT_SOURCE_UNIT_TESTS)
	TEST_ASSERT(!npc.npc_bark("cuffed"), "A mute NPC spoke")
	TEST_ASSERT(npc.npc_bark("downed"), "A mute NPC didn't show its emote")
	REMOVE_TRAIT(npc, TRAIT_MUTE, TRAIT_SOURCE_UNIT_TESTS)

	npc.npc_voice = /datum/human_npc_voice/unit_test
	npc.death()
	TEST_ASSERT_EQUAL(npc.npc_last_bark, "death", "Dying gave no death line")

/// N2: giving up stows the weapon (D3: never dropped), says the line and runs tg's *surrender; when the
/// paralysis ends uncuffed it decides again; cuffed, it doesn't.
/datum/unit_test/voidcrew_human_npc_surrender

/datum/unit_test/voidcrew_human_npc_surrender/Run()
	var/mob/living/carbon/human/npc/sample/thug/npc = allocate(/mob/living/carbon/human/npc/sample/thug)
	var/obj/item/gun/gun = locate() in npc.held_items
	TEST_ASSERT_NOTNULL(gun, "Test fixture: the thug holds no gun")
	var/datum/human_npc_surrender/rules = npc.npc_surrender_rules()
	TEST_ASSERT_NOTNULL(rules, "The thug has no surrender rules")

	TEST_ASSERT(!rules.hurt_enough(npc), "A healthy NPC thinks about giving up")
	npc.adjustToxLoss(70) // awake at 30 health; 50 oxygen damage would knock it out
	TEST_ASSERT(rules.hurt_enough(npc), "An NPC at 30 health doesn't think about giving up")
	TEST_ASSERT(!rules.should_consider(npc, list(1), list()), "One hostile is enough to make it think about giving up")
	TEST_ASSERT(rules.should_consider(npc, list(1, 2), list()), "Two hostiles aren't enough to make it think about giving up")
	TEST_ASSERT_EQUAL(rules.odds(npc, list(1, 2), list(), TRUE), 60, "The first roll's odds are wrong")
	TEST_ASSERT_EQUAL(rules.odds(npc, list(1, 2), list(1), TRUE), 40, "A standing friend doesn't lower the odds")
	TEST_ASSERT_EQUAL(rules.odds(npc, list(1, 2), list(), FALSE), 25, "A later roll's odds are wrong")
	TEST_ASSERT_EQUAL(rules.odds(npc, list(), list(), TRUE), 0, "It would give up with nobody there")

	TEST_ASSERT(npc.npc_surrender(), "The NPC would not give up")
	TEST_ASSERT(npc.IsParalyzed(), "*surrender did not paralyse the NPC")
	TEST_ASSERT_EQUAL(npc.npc_last_bark, "surrender", "Giving up gave no surrender line")
	TEST_ASSERT(!npc.is_holding(gun), "The NPC kept its gun in hand when it gave up")
	TEST_ASSERT_EQUAL(human_npc_holding(gun), npc, "The NPC's gun left its body when it gave up")
	TEST_ASSERT(!npc.npc_surrender(), "The NPC gave up twice at once")

	npc.SetParalyzed(0)
	TEST_ASSERT(!npc.npc_surrendering, "The NPC still counts as surrendering after the paralysis")
	TEST_ASSERT(npc.npc_surrender_redecide, "Uncuffed after the paralysis, the NPC did not decide again")

	// Given up and cuffed: taken, nothing to decide.
	npc.npc_surrender_redecide = FALSE
	npc.emotes_used = null // the emote spam limit, not a game rule
	TEST_ASSERT(npc.npc_surrender(), "The NPC would not give up a second time")
	var/obj/item/restraints/handcuffs/cuffs = allocate(/obj/item/restraints/handcuffs)
	TEST_ASSERT(npc.equip_to_slot_if_possible(cuffs, ITEM_SLOT_HANDCUFFED), "Test fixture: the NPC could not be cuffed")
	npc.SetParalyzed(0)
	TEST_ASSERT(!npc.npc_surrender_redecide, "A cuffed NPC decided again after giving up")
	TEST_ASSERT(!npc.npc_surrender(), "A cuffed NPC gave up again")

/// N5: in soft crit the AI keeps running and does only soft-crit things: a medipen, firing wild (elites),
/// crawling away. Hard crit stops it.
/datum/unit_test/voidcrew_human_npc_soft_crit

/datum/unit_test/voidcrew_human_npc_soft_crit/Run()
	var/mob/living/carbon/human/npc/sample/thug/npc = allocate(/mob/living/carbon/human/npc/sample/thug)
	var/datum/ai_controller/controller = npc.ai_controller
	npc.adjustToxLoss(110) // awake in soft crit; 50 oxygen damage would knock it out
	TEST_ASSERT_EQUAL(npc.stat, SOFT_CRIT, "Test fixture: the NPC is not in soft crit")
	TEST_ASSERT(!(controller.get_able_to_run() & AI_UNABLE_TO_RUN), "A human NPC's AI can't run in soft crit")
	var/obj/item/reagent_containers/hypospray/medipen/pen = human_npc_soft_crit_treatment(npc)
	TEST_ASSERT_NOTNULL(pen, "The NPC doesn't find the medipen in its pocket")
	TEST_ASSERT(human_npc_gear_consumable(pen), "The medipen wasn't issued as a consumable")

	var/datum/ai_planning_subtree/human_npc_soft_crit/soft = new
	TEST_ASSERT_EQUAL(soft.SelectBehaviors(controller, 1), SUBTREE_RETURN_FINISH_PLANNING, "The soft-crit subtree let other subtrees plan")
	var/datum/ai_behavior/human_npc_treat_self/treat = GET_AI_BEHAVIOR(/datum/ai_behavior/human_npc_treat_self)
	TEST_ASSERT(controller.current_behaviors[treat], "In soft crit with a medipen, the NPC didn't plan to use it")

	var/finished = FALSE
	for(var/step in 1 to 10)
		npc.next_move = 0
		npc.next_click = 0
		var/result = treat.perform(1, controller, "human_npc_treat_item")
		TEST_ASSERT(!(result & AI_BEHAVIOR_FAILED), "Using the medipen failed at step [step]")
		if(result & AI_BEHAVIOR_SUCCEEDED)
			finished = TRUE
			break
	TEST_ASSERT(finished, "The NPC never finished using its medipen")
	TEST_ASSERT(npc.reagents.has_reagent(/datum/reagent/medicine/epinephrine), "The medipen's epinephrine isn't in the NPC")
	TEST_ASSERT(pen.used_up, "The medipen isn't spent")

	npc.adjustOxyLoss(40)
	TEST_ASSERT_EQUAL(npc.stat, HARD_CRIT, "Test fixture: the NPC is not in hard crit")
	TEST_ASSERT(controller.get_able_to_run() & AI_UNABLE_TO_RUN, "A human NPC's AI runs in hard crit")

	// An elite fires from the floor at the ground around its attacker; a regular only crawls.
	var/mob/living/carbon/human/consistent/target = allocate(/mob/living/carbon/human/consistent, locate(run_loc_floor_bottom_left.x + 4, run_loc_floor_bottom_left.y + 2, run_loc_floor_bottom_left.z))
	var/mob/living/carbon/human/npc/sample/elite/elite = allocate(/mob/living/carbon/human/npc/sample/elite, locate(run_loc_floor_bottom_left.x, run_loc_floor_bottom_left.y + 2, run_loc_floor_bottom_left.z))
	var/mob/living/carbon/human/npc/sample/gunner/regular = allocate(/mob/living/carbon/human/npc/sample/gunner, locate(run_loc_floor_bottom_left.x, run_loc_floor_bottom_left.y + 3, run_loc_floor_bottom_left.z))
	var/datum/ai_behavior/human_npc_fire_wild/wild = GET_AI_BEHAVIOR(/datum/ai_behavior/human_npc_fire_wild)
	for(var/mob/living/carbon/human/npc/downed as anything in list(elite, regular))
		downed.adjustToxLoss(110)
		TEST_ASSERT_EQUAL(downed.stat, SOFT_CRIT, "Test fixture: [downed] is not in soft crit")
		downed.ai_controller.set_blackboard_key(BB_BASIC_MOB_CURRENT_TARGET, target)
		soft.SelectBehaviors(downed.ai_controller, 1)
	TEST_ASSERT(elite.ai_controller.current_behaviors[wild], "An elite in soft crit doesn't fire from the floor")
	TEST_ASSERT(!regular.ai_controller.current_behaviors[wild], "A regular NPC in soft crit fires from the floor")

	var/obj/item/gun/ballistic/elite_gun = locate() in elite.held_items
	TEST_ASSERT_NOTNULL(elite_gun, "Test fixture: the elite holds no ballistic gun")
	elite_gun.can_misfire = FALSE
	var/rounds_before = elite_gun.magazine.ammo_count(FALSE)
	elite.next_move = 0
	elite.next_click = 0
	wild.perform(1, elite.ai_controller, "human_npc_flee_from")
	TEST_ASSERT(elite_gun.magazine.ammo_count(FALSE) < rounds_before || !elite_gun.chambered?.loaded_projectile, "The elite in soft crit did not fire")

/// N7: outfit tables pick by zone and rank; every pirate table dresses every rank in every zone, with a
/// real weapon and the ammunition it takes.
/datum/unit_test/voidcrew_human_npc_outfit_tables

/datum/unit_test/voidcrew_human_npc_outfit_tables/Run()
	var/datum/human_npc_outfit_table/raiders = human_npc_singleton(/datum/human_npc_outfit_table/sample_raiders)
	TEST_ASSERT_EQUAL(raiders.pick_outfit(null, 1), /datum/outfit/human_npc/raider, "Green raiders aren't in rags")
	TEST_ASSERT_EQUAL(raiders.pick_outfit(null, 2), /datum/outfit/human_npc/raider/vest, "Yellow raiders have no vest")
	TEST_ASSERT_EQUAL(raiders.pick_outfit(null, 3), /datum/outfit/human_npc/raider/armoured, "Red raiders aren't armoured")
	var/mob/living/carbon/human/npc/sample/elite/elite = allocate(/mob/living/carbon/human/npc/sample/elite)
	TEST_ASSERT_EQUAL(raiders.pick_outfit(elite, 1), /datum/outfit/human_npc/pirate_gunner, "An elite didn't get the elite outfit")

	// An order that knows its zone dresses for it.
	var/mob/living/carbon/human/npc/red_raider = human_npc_build_in_zone(/mob/living/carbon/human/npc/sample/raider, 3)
	TEST_ASSERT(istype(red_raider?.wear_suit, /obj/item/clothing/suit/armor/vest), "A red-zone raider wears no vest")
	TEST_ASSERT(istype(red_raider?.head, /obj/item/clothing/head/helmet), "A red-zone raider wears no helmet")
	TEST_ASSERT_NOTNULL(locate(/obj/item/gun/ballistic/automatic/mini_uzi) in red_raider?.held_items, "A red-zone raider holds no SMG")

	// A spawn context's zone reaches the outfit, and the zone multipliers never touch a human.
	var/datum/npc_spawn_context/context = new /datum/npc_spawn_context(run_loc_floor_bottom_left, 2)
	var/mob/living/carbon/human/npc/yellow_raider = spawn_npc_in_zone(/mob/living/carbon/human/npc/sample/raider, run_loc_floor_bottom_left, context)
	allocated += yellow_raider
	TEST_ASSERT(istype(yellow_raider?.wear_suit, /obj/item/clothing/suit/armor/vest), "A raider made in a yellow-zone context wears no vest")
	TEST_ASSERT(!istype(yellow_raider?.head, /obj/item/clothing/head/helmet), "A yellow-zone raider got the red-zone helmet")
	TEST_ASSERT_EQUAL(yellow_raider?.maxHealth, 100, "A human NPC's max health was changed by its zone")
	TEST_ASSERT(!yellow_raider?.npc_zone_applied, "A zone profile was applied to a human NPC")

	// An order whose context is still resolving its zone waits, then settles for green.
	var/turf_zone = get_zone_type_for_player_turf(run_loc_floor_bottom_left)
	var/datum/npc_spawn_context/unresolved = new /datum/npc_spawn_context(run_loc_floor_bottom_left)
	var/datum/human_npc_order/waiting = new /datum/human_npc_order(/mob/living/carbon/human/npc/sample/raider, run_loc_floor_bottom_left, null, null, null, null, null, unresolved)
	if(isnull(turf_zone))
		TEST_ASSERT(!waiting.ready(), "An order waiting on its zone was ready to build")
		waiting.queued_at = world.time - 61 SECONDS
		waiting.next_zone_check = 0
		TEST_ASSERT(waiting.ready(), "An order that waited a minute for its zone still isn't ready")
		TEST_ASSERT_EQUAL(waiting.zone, 1, "An order that gave up waiting wasn't dressed for green")
	else
		TEST_ASSERT(waiting.ready(), "An order on a turf with a zone wasn't ready")
	qdel(waiting)
	qdel(unresolved)

	// Every pirate table, every outfit in it worn once.
	var/list/outfits_seen = list()
	for(var/table_type in subtypesof(/datum/human_npc_outfit_table/pirate))
		var/datum/human_npc_outfit_table/pirate/table = human_npc_singleton(table_type)
		for(var/zone in 1 to 3)
			TEST_ASSERT(length(table.outfits_for(null, zone)), "[table_type] dresses nobody in zone [zone]")
		TEST_ASSERT(length(table.elite), "[table_type] has no captain")
		TEST_ASSERT(length(table.boss), "[table_type] has no boss")
		if(table.gunners_only)
			for(var/outfit_type in table.green)
				TEST_ASSERT(!(outfit_type in table.melee), "[table_type] hands out a melee outfit")
		for(var/list/choices in list(table.green, table.elite, table.boss))
			for(var/outfit_type in choices)
				outfits_seen |= outfit_type
	for(var/outfit_type in outfits_seen)
		TEST_ASSERT(ispath(outfit_type, /datum/outfit), "A pirate table lists [outfit_type], which is not an outfit")
		var/datum/human_npc_order/dressed = spawn_human_npc(/mob/living/carbon/human/npc/sample, run_loc_floor_bottom_left, outfit = outfit_type, immediate = TRUE)
		var/mob/living/carbon/human/npc/pirate = dressed.spawned_ref?.resolve()
		TEST_ASSERT_NOTNULL(pirate, "[outfit_type] built nobody")
		var/obj/item/gun/gun = human_npc_held_gun(pirate)
		TEST_ASSERT(gun || human_npc_held_melee_weapon(pirate), "[outfit_type] holds no weapon")
		if(istype(gun, /obj/item/gun/ballistic))
			TEST_ASSERT_NOTNULL(human_npc_find_ammo(pirate, gun), "[outfit_type] carries no spare ammunition for its [gun]")
		qdel(pirate)

/// N7: where the air can't keep a person alive the NPC gets a sealed suit and a tank; in the cold it gets
/// cold-weather wear; a species that needs neither is left alone. It minds its valve like a person: open
/// while the air would hurt it, shut while the air is fine (so the tank doesn't run dry in a good room).
/datum/unit_test/voidcrew_human_npc_site_layers

/datum/unit_test/voidcrew_human_npc_site_layers/Run()
	var/turf/open/floor = run_loc_floor_bottom_left
	TEST_ASSERT_EQUAL(human_npc_site_at(floor), 0, "The test room's air counts as hostile")
	var/datum/gas_mixture/air = floor.return_air()
	var/old_temperature = air.temperature
	air.temperature = 200
	var/cold_site = human_npc_site_at(floor)
	air.temperature = old_temperature
	TEST_ASSERT(cold_site & 4, "Air at 200 K doesn't count as cold")

	var/datum/outfit/human_npc/pirate_spacer/sealed_outfit = new()
	var/datum/outfit/human_npc/raider/rags_outfit = new()
	TEST_ASSERT(human_npc_outfit_sealed(sealed_outfit), "The pirate spacer's suit doesn't count as sealed")
	TEST_ASSERT(!human_npc_outfit_sealed(rags_outfit), "Rags count as sealed")
	TEST_ASSERT(human_npc_outfit_has_air(sealed_outfit), "The pirate spacer doesn't count as carrying air")

	var/mob/living/carbon/human/npc/sample/raider/unit_test_spacer/spacer = human_npc_build_in_zone(/mob/living/carbon/human/npc/sample/raider/unit_test_spacer, 1)
	TEST_ASSERT(istype(spacer.wear_suit, /obj/item/clothing/suit/space/pirate), "An NPC dressed for vacuum has no space suit")
	TEST_ASSERT(istype(spacer.head, /obj/item/clothing/head/helmet/space), "An NPC dressed for vacuum has no space helmet")
	TEST_ASSERT(istype(spacer.s_store, /obj/item/tank/internals), "An NPC dressed for vacuum carries no tank")
	TEST_ASSERT(spacer.can_breathe_internals(), "An NPC dressed for vacuum has nothing to breathe its tank through")
	TEST_ASSERT_NULL(spacer.internal, "An NPC dressed for vacuum keeps its tank open in good air")
	var/turf/spacer_turf = get_turf(spacer)
	var/datum/gas_mixture/room_air = spacer_turf.return_air()
	var/datum/gas_mixture/saved_air = room_air.copy()
	room_air.remove_ratio(1)
	spacer.npc_update_internals()
	TEST_ASSERT_NOTNULL(spacer.internal, "An NPC in vacuum didn't open its tank")
	room_air.copy_from(saved_air)
	spacer.npc_update_internals()
	TEST_ASSERT_NULL(spacer.internal, "An NPC back in good air didn't shut its tank")
	var/obj/item/clothing/suit/space/suit = spacer.wear_suit
	TEST_ASSERT(suit?.thermal_on, "An NPC dressed for vacuum didn't switch on its suit's heating")
	// Dormant, the regulator is off so the cell lasts; awake, it goes back on.
	var/turf/here = get_turf(spacer)
	spacer.Life(SSMOBS_DT, 1)
	TEST_ASSERT(!suit?.thermal_on, "A dormant NPC kept its suit's heating running")
	SSmobs.clients_by_zlevel[here.z] += spacer
	spacer.Life(SSMOBS_DT, 2)
	SSmobs.clients_by_zlevel[here.z] -= spacer
	TEST_ASSERT(suit?.thermal_on, "An NPC that woke didn't switch its suit's heating back on")
	TEST_ASSERT(human_npc_gear_locked(spacer.s_store), "The NPC's tank isn't locked to it")
	TEST_ASSERT_NOTNULL(human_npc_held_gun(spacer), "The suit layer took the NPC's gun")

	var/mob/living/carbon/human/npc/sample/raider/unit_test_cold/cold = human_npc_build_in_zone(/mob/living/carbon/human/npc/sample/raider/unit_test_cold, 1)
	TEST_ASSERT(istype(cold.wear_suit, /obj/item/clothing/suit/hooded/wintercoat), "An NPC dressed for the cold has no coat")
	TEST_ASSERT(istype(cold.shoes, /obj/item/clothing/shoes/winterboots), "An NPC dressed for the cold has no winter boots")
	TEST_ASSERT_NOTNULL(cold.gloves, "An NPC dressed for the cold has bare hands")

	var/mob/living/carbon/human/npc/sample/raider/unit_test_skeleton/skeleton = human_npc_build_in_zone(/mob/living/carbon/human/npc/sample/raider/unit_test_skeleton, 1)
	TEST_ASSERT(istype(skeleton.dna.species, /datum/species/skeleton), "Test fixture: the skeleton isn't a skeleton")
	TEST_ASSERT(!istype(skeleton.wear_suit, /obj/item/clothing/suit/space), "A skeleton was put in a space suit it doesn't need")

/// N8: a living NPC walking out is deleted on its exit or out of sight, never while down, cuffed or
/// dragged; what isn't gear drops where it stood.
/datum/unit_test/voidcrew_human_npc_walk_out
	var/left_called = FALSE

/datum/unit_test/voidcrew_human_npc_walk_out/proc/on_left(mob/living/carbon/human/npc/leaver)
	left_called = TRUE

/datum/unit_test/voidcrew_human_npc_walk_out/Run()
	var/turf/exit = locate(run_loc_floor_bottom_left.x + 3, run_loc_floor_bottom_left.y, run_loc_floor_bottom_left.z)
	var/mob/living/carbon/human/npc/sample/gunner/npc = allocate(/mob/living/carbon/human/npc/sample/gunner)
	var/obj/item/ship_key/key = allocate(/obj/item/ship_key)
	TEST_ASSERT(npc.equip_to_slot_if_possible(key, ITEM_SLOT_LPOCKET), "Test fixture: the key would not go in the NPC's pocket")
	TEST_ASSERT(!npc.npc_may_vanish(), "An NPC that isn't leaving may vanish")
	TEST_ASSERT(npc.npc_walk_out(exit, CALLBACK(src, PROC_REF(on_left))), "The NPC would not walk out")
	TEST_ASSERT(npc in SShuman_npcs.leavers, "A leaving NPC isn't tracked")
	TEST_ASSERT_EQUAL(npc.ai_controller.blackboard["human_npc_exit"], exit, "The NPC's AI doesn't know its exit")

	var/obj/item/restraints/handcuffs/cuffs = allocate(/obj/item/restraints/handcuffs)
	TEST_ASSERT(npc.equip_to_slot_if_possible(cuffs, ITEM_SLOT_HANDCUFFED), "Test fixture: the NPC could not be cuffed")
	TEST_ASSERT(!npc.npc_may_vanish(), "A cuffed NPC may vanish")
	npc.uncuff()
	var/mob/living/carbon/human/consistent/dragger = allocate(/mob/living/carbon/human/consistent, locate(run_loc_floor_bottom_left.x + 1, run_loc_floor_bottom_left.y, run_loc_floor_bottom_left.z))
	dragger.start_pulling(npc)
	TEST_ASSERT(!npc.npc_may_vanish(), "An NPC being dragged may vanish")
	dragger.stop_pulling()
	npc.adjustOxyLoss(110)
	TEST_ASSERT(!npc.npc_may_vanish(), "An NPC in crit may vanish")
	npc.setOxyLoss(0)

	// Free and with no player on the test level to see it: it may go.
	TEST_ASSERT(npc.npc_may_vanish(), "A free NPC nobody can see may not vanish")
	npc.npc_stop_leaving()
	TEST_ASSERT(!npc.npc_may_vanish(), "An NPC called back may still vanish")
	TEST_ASSERT(!(npc in SShuman_npcs.leavers), "An NPC called back is still tracked as leaving")

	npc.npc_walk_out(exit, CALLBACK(src, PROC_REF(on_left)))
	SShuman_npcs.sweep_leavers()
	TEST_ASSERT(QDELETED(npc), "The sweep left a free, unwatched NPC that was walking out")
	TEST_ASSERT(left_called, "Walking out didn't call back")
	TEST_ASSERT(!QDELETED(key) && isturf(key.loc), "The ship key went with the NPC that walked out")

/// N1 and OC-11: papers aren't gear and drop when the NPC dies; medical stacks are consumables; an NPC
/// whose gear isn't locked (a prisoner) carries ordinary items players can take.
/datum/unit_test/voidcrew_human_npc_gear_rules

/datum/unit_test/voidcrew_human_npc_gear_rules/Run()
	var/mob/living/carbon/human/npc/sample/gunner/npc = allocate(/mob/living/carbon/human/npc/sample/gunner)
	var/obj/item/paper/note = allocate(/obj/item/paper)
	TEST_ASSERT(npc.equip_to_slot_if_possible(note, ITEM_SLOT_LPOCKET), "Test fixture: the paper would not go in the NPC's pocket")
	TEST_ASSERT(!npc.npc_lock_item(note), "A paper was locked to an NPC as gear")
	var/obj/item/stack/medical/bruise_pack/pack = allocate(/obj/item/stack/medical/bruise_pack)
	TEST_ASSERT(npc.put_in_hands(pack), "Test fixture: the NPC could not hold a bruise pack")
	TEST_ASSERT(npc.npc_lock_item(pack) && human_npc_gear_consumable(pack), "A bruise pack wasn't issued as a consumable")
	npc.death()
	TEST_ASSERT(!QDELETED(note) && isturf(note.loc), "A paper didn't drop when its NPC died")

	var/mob/living/carbon/human/npc/sample/gunner/unit_test_prisoner/prisoner = allocate(/mob/living/carbon/human/npc/sample/gunner/unit_test_prisoner, locate(run_loc_floor_bottom_left.x + 1, run_loc_floor_bottom_left.y, run_loc_floor_bottom_left.z))
	var/mob/living/carbon/human/consistent/guard = allocate(/mob/living/carbon/human/consistent)
	var/obj/item/gun/gun = locate() in prisoner.held_items
	TEST_ASSERT_NOTNULL(gun, "Test fixture: the prisoner holds nothing")
	TEST_ASSERT(!human_npc_gear_locked(gun), "An unlocked NPC's gun is locked")
	TEST_ASSERT(!human_npc_gear_locked(prisoner.w_uniform), "An unlocked NPC's jumpsuit is locked")
	TEST_ASSERT(prisoner.should_strip(guard), "An unlocked NPC can't be searched")
	TEST_ASSERT(prisoner.dropItemToGround(gun), "An unlocked NPC can't let go of its gun")
	sleep(2)
	TEST_ASSERT(!QDELETED(gun) && isturf(gun.loc), "An unlocked NPC's dropped gun was deleted")

/**
 * Phase E follow-ups to the spawn queue: an order built later checks that its spot is still the place it
 * was queued for (a ruin unloaded while it waited), and the NPC faces the way it was told (a mapped
 * spawner's dir).
 */
/datum/unit_test/voidcrew_human_npc_order_spot

/datum/unit_test/voidcrew_human_npc_order_spot/Run()
	var/datum/human_npc_order/facing = spawn_human_npc(/mob/living/carbon/human/npc/sample/gunner, run_loc_floor_bottom_left, immediate = TRUE, dir = EAST)
	var/mob/living/carbon/human/npc/facer = facing.spawned_ref?.resolve()
	TEST_ASSERT_NOTNULL(facer, "An order for the test floor built nothing")
	if(facer)
		allocated += facer
		TEST_ASSERT_EQUAL(facer.dir, EAST, "An NPC built with a dir doesn't face it")
	var/datum/human_npc_order/moved_on = new /datum/human_npc_order(/mob/living/carbon/human/npc/sample/gunner, run_loc_floor_bottom_left)
	TEST_ASSERT(moved_on.spot_still_valid(), "A fresh order's spot doesn't count as its own")
	// The ground was reused while it waited: its area is not the one it was queued in.
	moved_on.where_area = null
	TEST_ASSERT_NULL(moved_on.fulfil(), "An order whose spot was reused still built its NPC there")
	qdel(moved_on)
