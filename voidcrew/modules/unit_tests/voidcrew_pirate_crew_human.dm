/**
 * Human NPC ship crews (voidcrew/modules/npc_ships/code/faction_pirates/faction_pirate_humans.dm and
 * pirate_crew_human.dm, human NPC migration phase B): how they are dressed, armed and ranked, how they
 * fire their real guns, how a hull's crew and a boarding wave count as beaten (dead, down or cuffed,
 * owner ruling OC-7), what happens to one spaced (no forced death, PI-3), how boarders come by pod, and
 * the bosses' real kit and finishers.
 *
 * Fork defines are included after the tests, so their values are written out: ranks
 * HUMAN_NPC_RANK_ELITE 1 and _BOSS 2; blackboard keys by their strings; combat states "boarding",
 * "boarding_cooldown"; HV_FINISHER_DAMAGED 3. Nothing waits on a timer or an AI walk.
 */

/// The boarding test controller from voidcrew_npc_boarding_docking.dm, with the turfs its pods may use
/datum/unit_test/voidcrew_pirate_crew/human_crew
	abstract_type = /datum/unit_test/voidcrew_pirate_crew/human_crew

// ===== DRESS, RANK AND KIT =====

/// Every faction's crew is dressed for its role, ranked and armed; boarders wear a sealed suit and air,
/// crew aboard their own hull don't; medieval footsoldiers refuse guns and their crossbowmen don't.
/datum/unit_test/voidcrew_pirate_crew/human_crew/dress

/datum/unit_test/voidcrew_pirate_crew/human_crew/dress/Run()
	for(var/faction in list("silverscale", "skeleton", "grey", "lustrous", "interdyne", "irs", "medieval"))
		var/melee_type = text2path("/mob/living/carbon/human/npc/faction_pirate/[faction]/melee")
		var/ranged_type = text2path("/mob/living/carbon/human/npc/faction_pirate/[faction]/ranged")
		var/captain_type = text2path("/mob/living/carbon/human/npc/faction_pirate/[faction]/captain")
		var/mob/living/carbon/human/npc/faction_pirate/melee = build_npc(melee_type, spot(0, 0))
		var/mob/living/carbon/human/npc/faction_pirate/ranged = build_npc(ranged_type, spot(1, 0))
		var/mob/living/carbon/human/npc/faction_pirate/captain = build_npc(captain_type, spot(2, 0))
		TEST_ASSERT(human_npc_held_melee_weapon(melee) && !human_npc_held_gun(melee), "[melee_type] isn't holding a blade or a club")
		TEST_ASSERT_NOTNULL(human_npc_held_gun(ranged), "[ranged_type] isn't holding a gun")
		var/obj/item/gun/ballistic/bullet_gun = human_npc_held_gun(ranged)
		if(istype(bullet_gun))
			TEST_ASSERT_NOTNULL(human_npc_find_ammo(ranged, bullet_gun), "[ranged_type] carries no spare ammunition")
		TEST_ASSERT_EQUAL(captain.npc_rank, 1, "[captain_type] isn't an elite")
		TEST_ASSERT_EQUAL(captain.npc_damage_taken, 0.8, "[captain_type] isn't as tough as a captain should be")
		TEST_ASSERT_EQUAL(melee.npc_rank, 0, "[melee_type] isn't rank and file")
		TEST_ASSERT_EQUAL(melee.ai_controller?.type, /datum/ai_controller/basic_controller/pirate_crew/human, "[melee_type] isn't on the human pirate crew controller")
		TEST_ASSERT(melee.npc_death_cash > 0 && ranged.npc_death_cash > 0 && captain.npc_death_cash > melee.npc_death_cash, "[faction] crew lost their plunder")
		// Their ID card names them, so a helmet doesn't make them "Unknown"
		var/obj/item/card/id/card = melee.wear_id
		TEST_ASSERT(istype(card) && card.registered_name == melee.real_name, "[melee_type] carries no ID card with its name")
		TEST_ASSERT(human_npc_gear_locked(card), "[melee_type]'s ID card isn't locked to it")
		// Aboard its own hull in good air: no space suit
		TEST_ASSERT(!istype(melee.wear_suit, /obj/item/clothing/suit/space), "[melee_type] wears a space suit in good air")
		// A boarder: sealed and on its own air, unless it is a skeleton
		var/mob/living/carbon/human/npc/faction_pirate/boarder = build_npc(melee_type, spot(3, 0), boarding_outfit_for(melee_type))
		if(faction == "skeleton")
			TEST_ASSERT(!istype(boarder.wear_suit, /obj/item/clothing/suit/space), "A skeleton boarder was given a space suit it doesn't need")
		else
			TEST_ASSERT(boarder.wear_suit && (boarder.wear_suit.clothing_flags & STOPSPRESSUREDAMAGE), "A [faction] boarder has no sealed suit")
			TEST_ASSERT(boarder.head && (boarder.head.clothing_flags & STOPSPRESSUREDAMAGE), "A [faction] boarder has no sealed helmet")
			TEST_ASSERT(boarder.can_breathe_internals() && length(boarder.get_all_contents_type(/obj/item/tank/internals)), "A [faction] boarder carries no air it can breathe")
		if(faction == "medieval")
			TEST_ASSERT(HAS_TRAIT(melee, TRAIT_NOGUNS), "A medieval footsoldier will use guns")
			TEST_ASSERT(HAS_TRAIT(captain, TRAIT_NOGUNS), "The medieval warlord will use guns")
			TEST_ASSERT(!HAS_TRAIT(ranged, TRAIT_NOGUNS), "A medieval crossbowman can't use his crossbow")
		for(var/mob/living/carbon/human/npc/built as anything in list(melee, ranged, captain, boarder))
			qdel(built)

/// The captain's key isn't gear: it is on him, not locked, and drops at his feet when he dies. Crew are
/// tracked by the hull as they are built.
/datum/unit_test/voidcrew_pirate_crew/human_crew/captain_key

/datum/unit_test/voidcrew_pirate_crew/human_crew/captain_key/Run()
	var/obj/structure/overmap/ship/npc/pirate/hull = allocate(/obj/structure/overmap/ship/npc/pirate)
	var/mob/living/carbon/human/npc/faction_pirate/grey/captain/captain = build_npc(/mob/living/carbon/human/npc/faction_pirate/grey/captain, spot(1, 1))
	hull.on_captain_built(captain)
	var/obj/item/ship_key/key = locate() in captain.get_all_contents()
	TEST_ASSERT_NOTNULL(key, "The captain doesn't carry the ship key")
	TEST_ASSERT(!human_npc_gear_locked(key) && !human_npc_gear_consumable(key), "The ship key was locked to the captain like his gear")
	// In a pocket, where a crew that cuffs or downs him can take it through the strip menu
	TEST_ASSERT(captain.get_slot_by_item(key) & ITEM_SLOT_POCKETS, "The captain doesn't keep the ship key in a pocket")
	TEST_ASSERT(!HAS_TRAIT(key, TRAIT_NO_STRIP), "The ship key is hidden from the strip menu")
	TEST_ASSERT(captain in hull.tracked_crew, "The hull doesn't track its captain")
	TEST_ASSERT(hull.crew_ever_spawned, "The hull doesn't know it has a crew")
	TEST_ASSERT_EQUAL(pirate_crew_of(hull)?.members[captain], "captain", "The captain isn't his crew's captain")
	captain.death()
	TEST_ASSERT_EQUAL(key.loc, get_turf(captain), "The ship key didn't drop at the dead captain's feet")
	qdel(pirate_crew_of(hull))

// ===== OUT OF THE FIGHT (OC-7) =====

/// A hull's crew is wiped once every crewman is dead, down or cuffed; crew still being built hold it open.
/datum/unit_test/voidcrew_pirate_crew/human_crew/crew_wipe

/datum/unit_test/voidcrew_pirate_crew/human_crew/crew_wipe/Run()
	var/obj/structure/overmap/ship/npc/pirate/hull = allocate(/obj/structure/overmap/ship/npc/pirate)
	var/mob/living/carbon/human/npc/faction_pirate/grey/melee/first = build_npc(/mob/living/carbon/human/npc/faction_pirate/grey/melee, spot(0, 1))
	var/mob/living/carbon/human/npc/faction_pirate/grey/ranged/second = build_npc(/mob/living/carbon/human/npc/faction_pirate/grey/ranged, spot(1, 1))
	hull.on_crewman_built(first)
	hull.on_crewman_built(second)
	// One more still waiting in the queue
	var/datum/human_npc_order/pending = new /datum/human_npc_order(/mob/living/carbon/human/npc/faction_pirate/grey/melee, spot(2, 1))
	hull.crew_orders += pending

	var/obj/item/restraints/handcuffs/cuffs = allocate(/obj/item/restraints/handcuffs)
	TEST_ASSERT(first.equip_to_slot_if_possible(cuffs, ITEM_SLOT_HANDCUFFED), "Test fixture: the crewman could not be cuffed")
	TEST_ASSERT(!hull.crew_wipe_handled, "Cuffing one of two crewmen wiped the crew")
	second.adjustOxyLoss(110)
	TEST_ASSERT_EQUAL(second.stat, SOFT_CRIT, "Test fixture: the second crewman isn't in soft crit")
	TEST_ASSERT(!hull.crew_wipe_handled, "The crew was wiped with another crewman still being built")
	qdel(pending)
	hull.check_crew_wipe()
	TEST_ASSERT(hull.crew_wipe_handled, "A crew all down or cuffed wasn't wiped")
	TEST_ASSERT_EQUAL(hull.count_live_crew_aboard(), 0, "Crew down or cuffed still count as aboard and fighting")
	qdel(pirate_crew_of(hull))

/// A wave is over once every boarder is dead, down or cuffed, and none is still on its way.
/datum/unit_test/voidcrew_pirate_crew/human_crew/wave_out_of_fight

/datum/unit_test/voidcrew_pirate_crew/human_crew/wave_out_of_fight/Run()
	var/obj/structure/overmap/ship/npc/pirate/pirate = allocate(/obj/structure/overmap/ship/npc/pirate)
	var/obj/structure/overmap/ship/target = allocate(/obj/structure/overmap/ship)
	var/datum/ai_controller/npc_ship/boarding_docking_test/profile/controller = allocate(/datum/ai_controller/npc_ship/boarding_docking_test/profile, pirate)
	controller.test_zone = allocate(/datum/overmap_zone, 3)
	target.state = "flying"
	pirate.state = "flying"
	controller.set_target(target)
	controller.set_combat_state("boarding")
	var/list/wave = list()
	controller.blackboard["npc_boarding_wave_boarders"] = wave
	var/mob/living/carbon/human/npc/faction_pirate/irs/melee/boarder = build_npc(/mob/living/carbon/human/npc/faction_pirate/irs/melee, spot(1, 1))
	controller.track_wave_boarder(wave, boarder)
	TEST_ASSERT(boarder in wave, "The boarder didn't join its wave")

	var/datum/human_npc_order/coming = new /datum/human_npc_order(/mob/living/carbon/human/npc/faction_pirate/irs/melee, spot(2, 1))
	controller.wave_orders += coming
	var/obj/item/restraints/handcuffs/cuffs = allocate(/obj/item/restraints/handcuffs)
	TEST_ASSERT(boarder.equip_to_slot_if_possible(cuffs, ITEM_SLOT_HANDCUFFED), "Test fixture: the boarder could not be cuffed")
	TEST_ASSERT_EQUAL(controller.get_combat_state(), "boarding", "The wave ended with a boarder still on its way")
	qdel(coming)
	controller.check_wave_complete()
	TEST_ASSERT_EQUAL(controller.get_combat_state(), "boarding_cooldown", "A wave whose last boarder was cuffed didn't end")
	controller.clear_target()

/// Spaced boarders are dropped from their wave but not killed; one adrift where no player can see it is
/// cleaned up by its crew after a while.
/datum/unit_test/voidcrew_pirate_crew/human_crew/spaced

/datum/unit_test/voidcrew_pirate_crew/human_crew/spaced/Run()
	change_turf(spot(4, 4), /turf/open/space)
	var/obj/structure/overmap/ship/npc/pirate/pirate = allocate(/obj/structure/overmap/ship/npc/pirate)
	var/obj/structure/overmap/ship/target = allocate(/obj/structure/overmap/ship)
	var/datum/ai_controller/npc_ship/boarding_docking_test/profile/controller = allocate(/datum/ai_controller/npc_ship/boarding_docking_test/profile, pirate)
	controller.test_zone = allocate(/datum/overmap_zone, 3)
	target.state = "flying"
	pirate.state = "flying"
	controller.set_target(target)
	controller.set_combat_state("boarding")
	var/list/wave = list()
	controller.blackboard["npc_boarding_wave_boarders"] = wave
	var/mob/living/carbon/human/npc/faction_pirate/grey/melee/boarder = build_npc(/mob/living/carbon/human/npc/faction_pirate/grey/melee, spot(4, 4), /datum/human_npc_outfit_table/pirate/grey/boarding)
	TEST_ASSERT(pirate_crew_enlist_raider(boarder, target), "The boarder could not join the raid")
	controller.track_wave_boarder(wave, boarder)
	TEST_ASSERT(pirate_crew_member_adrift(boarder), "A boarder floating in space isn't adrift")
	controller.check_boarders_in_space()
	TEST_ASSERT(!(boarder in wave), "A spaced boarder still counts toward its wave")
	TEST_ASSERT(boarder.stat != DEAD, "A spaced boarder was killed")

	var/datum/pirate_crew/raid = pirate_crew_of(target, TRUE)
	raid.check_adrift()
	TEST_ASSERT(!QDELETED(boarder), "A boarder was cleaned up the moment it went adrift")
	raid.adrift_since[boarder] = world.time - 3 MINUTES
	raid.check_adrift()
	TEST_ASSERT(QDELETED(boarder), "A boarder adrift for minutes with nobody to see it wasn't cleaned up")
	controller.clear_target()

/// The pod cap counts the raid's boarders aboard still fighting, human or not.
/datum/unit_test/voidcrew_pirate_crew/human_crew/pod_cap

/datum/unit_test/voidcrew_pirate_crew/human_crew/pod_cap/Run()
	var/obj/structure/overmap/ship/target = allocate(/obj/structure/overmap/ship)
	var/obj/docking_port/mobile/voidcrew/port = allocate(/obj/docking_port/mobile/voidcrew, run_loc_floor_bottom_left)
	port.shuttle_areas = list((get_area(spot(1, 1))) = TRUE)
	target.shuttle = port
	var/mob/living/carbon/human/npc/faction_pirate/irs/melee/boarder = build_npc(/mob/living/carbon/human/npc/faction_pirate/irs/melee, spot(1, 1))
	TEST_ASSERT(pirate_crew_enlist_raider(boarder, target), "The boarder could not join the raid")
	var/datum/ai_behavior/npc_ship/fire_boarding_pods/pods = GET_AI_BEHAVIOR(/datum/ai_behavior/npc_ship/fire_boarding_pods)
	var/counted = pods.count_hostile_mobs_on_ship(target)
	boarder.adjustOxyLoss(110)
	var/counted_down = pods.count_hostile_mobs_on_ship(target)
	qdel(pirate_crew_of(target, TRUE))
	target.shuttle = null
	port.shuttle_areas = list()
	qdel(port, force = TRUE)
	TEST_ASSERT_EQUAL(counted, 1, "The pod cap didn't count a human boarder aboard")
	TEST_ASSERT_EQUAL(counted_down, 0, "The pod cap still counts a boarder in crit")

// ===== BOARDING PODS =====

/// A human boarder is queued, built, put in its pod and sent, and its caller hears about it; a raid called
/// off before it is built never sends it.
/datum/unit_test/voidcrew_pirate_crew/human_crew/pods

/datum/unit_test/voidcrew_pirate_crew/human_crew/pods/Run()
	var/obj/structure/overmap/ship/npc/pirate/pirate = allocate(/obj/structure/overmap/ship/npc/pirate)
	var/obj/structure/overmap/ship/target = allocate(/obj/structure/overmap/ship)
	var/datum/ai_controller/npc_ship/boarding_docking_test/profile/controller = allocate(/datum/ai_controller/npc_ship/boarding_docking_test/profile, pirate)
	controller.test_zone = allocate(/datum/overmap_zone, 3)
	target.state = "flying"
	pirate.state = "flying"
	controller.set_target(target)
	var/list/heard = list()
	controller.blackboard["npc_boarding_wave_boarders"] = heard
	var/sent = create_boarding_pod(spot(2, 2), target, pirate, /mob/living/carbon/human/npc/faction_pirate/lustrous/melee, on_boarder = CALLBACK(controller, TYPE_PROC_REF(/datum/ai_controller/npc_ship, track_wave_boarder), heard))
	TEST_ASSERT(istype(sent, /datum/human_npc_order), "A human boarder wasn't queued")
	var/datum/human_npc_order/order = sent
	TEST_ASSERT(order in controller.boarding_orders, "The encounter isn't tracking its queued boarder")
	var/mob/living/carbon/human/npc/faction_pirate/boarder = order.fulfil()
	TEST_ASSERT_NOTNULL(boarder, "The queued boarder wasn't built")
	TEST_ASSERT(istype(boarder.loc, /obj/structure/closet/supplypod/boarding), "The boarder isn't in its pod")
	TEST_ASSERT(boarder in heard, "The caller didn't hear about its boarder")
	TEST_ASSERT(boarder.wear_suit && (boarder.wear_suit.clothing_flags & STOPSPRESSUREDAMAGE), "A boarder came without a sealed suit")

	var/datum/human_npc_order/second = create_boarding_pod(spot(3, 2), target, pirate, /mob/living/carbon/human/npc/faction_pirate/lustrous/melee)
	TEST_ASSERT(istype(second), "The second boarder wasn't queued")
	controller.cancel_boarding_orders()
	TEST_ASSERT(QDELETED(second), "Calling the raid off left a boarder in the spawn queue")

	target.state = "idle"
	for(var/obj/effect/pod_landingzone/boarding/landing in spot(2, 2))
		landing.cancel_if_target_docked()
	controller.clear_target()

// ===== GUNS =====

/// Each kind of gun is handled its own way; a gunner fires its real gun in volleys, and a hit during a
/// shotgun's aim spoils the shot.
/datum/unit_test/voidcrew_pirate_crew/human_crew/guns

/datum/unit_test/voidcrew_pirate_crew/human_crew/guns/Run()
	var/list/expected = list(
		/obj/item/gun/ballistic/automatic/pistol = /datum/pirate_gun_handling/pistol,
		/obj/item/gun/ballistic/automatic/mini_uzi = /datum/pirate_gun_handling/smg,
		/obj/item/gun/ballistic/shotgun/lethal = /datum/pirate_gun_handling/shotgun,
		/obj/item/gun/energy/e_gun/lethal = /datum/pirate_gun_handling/energy,
		/obj/item/gun/energy/laser = /datum/pirate_gun_handling/energy,
		/obj/item/gun/energy/recharge/ebow/large = /datum/pirate_gun_handling/crossbow,
	)
	for(var/gun_type in expected)
		var/obj/item/gun/gun = allocate(gun_type, spot(4, 4))
		var/datum/pirate_gun_handling/handling = pirate_gun_handling_for(gun)
		TEST_ASSERT_EQUAL(handling.type, expected[gun_type], "[gun_type] is handled as [handling.type]")
		TEST_ASSERT(handling.shots >= 1 && handling.volley_gap > 0, "[gun_type] never fires")
	var/datum/pirate_gun_handling/shotgun_handling = pirate_gun_handling_for(allocate(/obj/item/gun/ballistic/shotgun/lethal, spot(4, 4)))
	TEST_ASSERT_EQUAL(shotgun_handling.close_range, 3, "A shotgunner doesn't walk in close")

	// A pistol volley: two pulls, a short gap between them, then a long one
	var/mob/living/carbon/human/npc/faction_pirate/gunner = build_npc(/mob/living/carbon/human/npc/faction_pirate/irs/ranged, spot(0, 0), /datum/outfit/piratecorpse/faction/irs/ranged/pistol)
	var/mob/living/carbon/human/consistent/mark = allocate(/mob/living/carbon/human/consistent, spot(4, 0))
	var/obj/item/gun/ballistic/automatic/pistol/pistol = locate() in gunner.held_items
	TEST_ASSERT_NOTNULL(pistol, "Test fixture: the gunner holds no pistol")
	pistol.can_misfire = FALSE
	var/datum/ai_controller/controller = gunner.ai_controller
	controller.set_blackboard_key(BB_BASIC_MOB_CURRENT_TARGET, mark)
	var/datum/ai_behavior/pirate_crew_human_shoot/shoot = GET_AI_BEHAVIOR(/datum/ai_behavior/pirate_crew_human_shoot)
	var/rounds = pistol.get_ammo()
	gunner.next_move = 0
	gunner.next_click = 0
	shoot.perform(1, controller, BB_BASIC_MOB_CURRENT_TARGET, BB_TARGETING_STRATEGY, BB_BASIC_MOB_CURRENT_TARGET_HIDING_LOCATION)
	TEST_ASSERT(pistol.get_ammo() < rounds, "The gunner's first pull didn't fire the pistol")
	TEST_ASSERT_EQUAL(controller.blackboard["pirate_volley_left"], 1, "A pistol volley isn't two shots")
	TEST_ASSERT(controller.blackboard["human_npc_next_shot"] <= world.time + 0.3 SECONDS, "The second shot of a pistol volley waits too long")
	rounds = pistol.get_ammo()
	shoot.perform(1, controller, BB_BASIC_MOB_CURRENT_TARGET, BB_TARGETING_STRATEGY, BB_BASIC_MOB_CURRENT_TARGET_HIDING_LOCATION)
	TEST_ASSERT_EQUAL(pistol.get_ammo(), rounds, "The gunner fired again before the gap between its shots")

	// A shotgun aims a moment first; a hit in that moment spoils it
	var/mob/living/carbon/human/npc/faction_pirate/shotgunner = build_npc(/mob/living/carbon/human/npc/faction_pirate/irs/ranged, spot(0, 2), /datum/outfit/piratecorpse/faction/irs/ranged/shotgun)
	var/datum/ai_controller/pump_controller = shotgunner.ai_controller
	pump_controller.set_blackboard_key(BB_BASIC_MOB_CURRENT_TARGET, mark)
	shotgunner.next_move = 0
	shotgunner.next_click = 0
	shoot.perform(1, pump_controller, BB_BASIC_MOB_CURRENT_TARGET, BB_TARGETING_STRATEGY, BB_BASIC_MOB_CURRENT_TARGET_HIDING_LOCATION)
	TEST_ASSERT(pump_controller.blackboard["pirate_windup_until"] > world.time, "A shotgun fired without aiming first")
	shotgunner.apply_damage(5, BRUTE, BODY_ZONE_CHEST)
	TEST_ASSERT(!pump_controller.blackboard["pirate_windup_until"], "A hit while aiming didn't spoil the shot")

/// Only a boss puts its gun to the head of someone down beside it; anyone else never aims there at point blank.
/datum/unit_test/voidcrew_pirate_crew/human_crew/executions

/datum/unit_test/voidcrew_pirate_crew/human_crew/executions/Run()
	var/mob/living/carbon/human/npc/faction_pirate/chief = build_npc(/mob/living/carbon/human/npc/faction_pirate/irs/boss, spot(1, 1))
	var/mob/living/carbon/human/npc/faction_pirate/agent = build_npc(/mob/living/carbon/human/npc/faction_pirate/irs/ranged, spot(1, 3), /datum/outfit/piratecorpse/faction/irs/ranged/energy_gun)
	var/mob/living/carbon/human/consistent/victim = allocate(/mob/living/carbon/human/consistent, spot(2, 2))
	victim.adjustOxyLoss(110)
	TEST_ASSERT_EQUAL(victim.stat, SOFT_CRIT, "Test fixture: the victim isn't in soft crit")
	TEST_ASSERT_EQUAL(chief.npc_rank, 2, "The Chief Auditor isn't a boss")
	TEST_ASSERT(pirate_crew_human_wants_execution(chief.ai_controller, chief, victim), "A boss gunner doesn't go for a downed hunter's head")
	TEST_ASSERT(!pirate_crew_human_wants_execution(agent.ai_controller, agent, victim), "An ordinary gunner tries to execute")
	for(var/i in 1 to 30)
		TEST_ASSERT(pirate_crew_human_aim_zone(agent, victim) != BODY_ZONE_HEAD, "An ordinary gunner aimed at the head of someone helpless beside it")

// ===== CAPTAINS AND BOSSES =====

/// Captains and bosses carry a stimulant and inject it once they have someone to fight; Davy Jones drinks
/// from his flask when hurt.
/datum/unit_test/voidcrew_pirate_crew/human_crew/self_care

/datum/unit_test/voidcrew_pirate_crew/human_crew/self_care/Run()
	var/mob/living/carbon/human/npc/faction_pirate/noble = build_npc(/mob/living/carbon/human/npc/faction_pirate/silverscale/captain, spot(1, 1))
	var/mob/living/carbon/human/consistent/foe = allocate(/mob/living/carbon/human/consistent, spot(4, 4))
	TEST_ASSERT_NOTNULL(pirate_crew_human_stimulant(noble), "A captain carries no stimulant")
	var/datum/ai_controller/controller = noble.ai_controller
	var/datum/ai_planning_subtree/pirate_crew_human_self_care/care = new
	TEST_ASSERT_NULL(care.SelectBehaviors(controller, 1), "A captain with nobody to fight injected its stimulant")
	controller.set_blackboard_key(BB_BASIC_MOB_CURRENT_TARGET, foe)
	TEST_ASSERT_EQUAL(care.SelectBehaviors(controller, 1), SUBTREE_RETURN_FINISH_PLANNING, "A captain in a fight didn't reach for its stimulant")
	var/datum/ai_behavior/pirate_crew_human_use_on_self/use = GET_AI_BEHAVIOR(/datum/ai_behavior/pirate_crew_human_use_on_self)
	var/finished = FALSE
	for(var/step in 1 to 6)
		noble.next_move = 0
		noble.next_click = 0
		var/result = use.perform(1, controller, "pirate_self_item")
		TEST_ASSERT(!(result & AI_BEHAVIOR_FAILED), "Using the stimulant failed at step [step]")
		if(result & AI_BEHAVIOR_SUCCEEDED)
			finished = TRUE
			break
	TEST_ASSERT(finished, "The captain never used its stimulant")
	TEST_ASSERT(noble.reagents.has_reagent(/datum/reagent/medicine/stimulants), "The stimulant isn't in the captain's blood")
	TEST_ASSERT(human_npc_held_melee_weapon(noble), "The captain didn't take up its sabre again")

	var/mob/living/carbon/human/npc/faction_pirate/davy = build_npc(/mob/living/carbon/human/npc/faction_pirate/skeleton/boss, spot(1, 3))
	var/obj/item/reagent_containers/cup/glass/flask/flask = pirate_crew_human_flask(davy)
	TEST_ASSERT_NOTNULL(flask, "Davy Jones has no flask")
	TEST_ASSERT(flask.reagents.has_reagent(/datum/reagent/medicine/omnizine/cursed_grog), "Davy Jones's flask has no grog in it")
	TEST_ASSERT(human_npc_gear_locked(flask), "Davy Jones's flask isn't locked to him")
	var/full = flask.reagents.total_volume
	// Already stimmed, and hurt: he drinks
	davy.reagents.add_reagent(/datum/reagent/medicine/stimulants, 5)
	davy.adjustBruteLoss(80)
	var/datum/ai_controller/davy_controller = davy.ai_controller
	davy_controller.set_blackboard_key(BB_BASIC_MOB_CURRENT_TARGET, foe)
	TEST_ASSERT_EQUAL(care.SelectBehaviors(davy_controller, 1), SUBTREE_RETURN_FINISH_PLANNING, "A hurt Davy Jones doesn't reach for his flask")
	TEST_ASSERT_EQUAL(davy_controller.blackboard["pirate_self_item"], flask, "Davy Jones reached for something other than his flask")
	for(var/step in 1 to 6)
		davy.next_move = 0
		davy.next_click = 0
		if(use.perform(1, davy_controller, "pirate_self_item") & AI_BEHAVIOR_SUCCEEDED)
			break
	TEST_ASSERT(flask.reagents.total_volume < full, "Davy Jones didn't drink from his flask")

/// The bosses' real kit: rank and toughness, the Black Knight's hulk and size and his refusal of guns, the
/// finishers of the Black Knight and the Robust One, and a stimulant for the rest.
/datum/unit_test/voidcrew_pirate_crew/human_crew/bosses

/datum/unit_test/voidcrew_pirate_crew/human_crew/bosses/Run()
	for(var/faction in list("silverscale", "skeleton", "grey", "lustrous", "interdyne", "irs", "medieval"))
		var/boss_type = text2path("/mob/living/carbon/human/npc/faction_pirate/[faction]/boss")
		var/mob/living/carbon/human/npc/faction_pirate/boss = build_npc(boss_type, spot(2, 2))
		TEST_ASSERT_NOTNULL(boss, "[boss_type] wasn't built")
		TEST_ASSERT_EQUAL(boss.npc_rank, 2, "[boss_type] isn't a boss")
		TEST_ASSERT(boss.npc_damage_taken < 0.8, "[boss_type] is no tougher than a captain")
		TEST_ASSERT(human_npc_held_melee_weapon(boss) || human_npc_held_gun(boss), "[boss_type] holds no weapon")
		TEST_ASSERT(boss.maxHealth == 100, "[boss_type] was given a health pool")
		TEST_ASSERT(!HAS_TRAIT_FROM(boss, TRAIT_STUNIMMUNE, INNATE_TRAIT), "[boss_type] is innately stun immune")
		TEST_ASSERT(boss.npc_death_cash >= 3000, "[boss_type] lost its plunder")
		if(faction == "medieval")
			TEST_ASSERT(boss.dna.check_mutation(/datum/mutation/hulk), "The Black Knight isn't a hulk")
			TEST_ASSERT(boss.dna.check_mutation(/datum/mutation/gigantism), "The Black Knight isn't huge")
			TEST_ASSERT(HAS_TRAIT(boss, TRAIT_NOGUNS), "The Black Knight will use guns")
		else
			TEST_ASSERT_NOTNULL(pirate_crew_human_stimulant(boss), "[boss_type] carries no stimulant")
		if(faction == "medieval" || faction == "grey")
			TEST_ASSERT_NOTNULL(boss.GetComponent(/datum/component/hv_finisher_user), "[boss_type] has no finisher")
		qdel(boss)

/// HV-4 and HV-5: a human boss's finisher pins with a real aggressive grab and strikes with the real weapon
/// in its hand; it isn't rooted, takes no extra damage, and doesn't reel when made to let go.
/datum/unit_test/voidcrew_pirate_crew/human_crew/finisher

/datum/unit_test/voidcrew_pirate_crew/human_crew/finisher/Run()
	var/mob/living/carbon/human/npc/faction_pirate/robust = build_npc(/mob/living/carbon/human/npc/faction_pirate/grey/boss, spot(1, 1))
	var/mob/living/carbon/human/consistent/victim = allocate(/mob/living/carbon/human/consistent, spot(2, 1))
	victim.adjustOxyLoss(110)
	TEST_ASSERT_EQUAL(victim.stat, SOFT_CRIT, "Test fixture: the victim isn't down")
	var/datum/hv_finisher/robust_one/finisher = new(robust, victim)
	TEST_ASSERT(finisher.real_hits, "A human boss's finisher isn't done with real hits")
	TEST_ASSERT(finisher.start(), "The Robust One's finisher wouldn't start on someone down beside it")
	var/datum/status_effect/hv_finishing/busy = robust.has_status_effect(/datum/status_effect/hv_finishing)
	TEST_ASSERT_NOTNULL(busy, "The Robust One isn't busy with its finisher")
	TEST_ASSERT_EQUAL(busy.vulnerability, 1, "A human boss takes extra damage while it finishes someone")
	TEST_ASSERT(!HAS_TRAIT(robust, TRAIT_IMMOBILIZED), "A human boss is rooted while it finishes someone")

	TEST_ASSERT(finisher.take_grip(), "The Robust One couldn't get hold of the victim")
	TEST_ASSERT_EQUAL(robust.pulling, victim, "The pin isn't a real grab")
	TEST_ASSERT(robust.grab_state >= GRAB_AGGRESSIVE, "The pin isn't an aggressive grab")
	TEST_ASSERT(!HAS_TRAIT(victim, TRAIT_IMMOBILIZED), "The victim is held by a trait as well as the grab")

	var/obj/item/bodypart/head/head = victim.get_bodypart(BODY_ZONE_HEAD)
	var/head_before = head.get_damage()
	TEST_ASSERT(finisher.real_blow(BODY_ZONE_HEAD), "The Robust One didn't swing its toolbox")
	TEST_ASSERT(head.get_damage() > head_before, "The toolbox blow didn't hurt the victim's head")

	// A heavy hit makes it let go: the grab breaks, and it doesn't reel
	robust.apply_damage(100, BRUTE, BODY_ZONE_CHEST)
	TEST_ASSERT(!finisher.running, "A heavy hit didn't make the Robust One let go")
	TEST_ASSERT_EQUAL(finisher.result, 3, "The finisher didn't end because the boss was hurt")
	TEST_ASSERT(robust.pulling != victim, "The Robust One kept hold of the victim after letting go")
	TEST_ASSERT(!robust.has_status_effect(/datum/status_effect/hv_finisher_reeling), "A human boss reeled after letting go")
	qdel(finisher)

/// AM-15: suppression sweeps count the human pirate crews.
/datum/unit_test/voidcrew_pirate_crew/human_crew/suppression_counts

/datum/unit_test/voidcrew_pirate_crew/human_crew/suppression_counts/Run()
	var/datum/mission_objective/kill_count/counter = allocate(/datum/mission_objective/kill_count)
	var/mob/living/carbon/human/npc/crewman = human_npc_build_in_zone(/mob/living/carbon/human/npc/faction_pirate/grey/melee, 2)
	TEST_ASSERT_NOTNULL(crewman, "Test fixture: the grey tider wasn't built")
	TEST_ASSERT(counter.counts_victim(crewman), "A suppression sweep doesn't count the human pirate crews")
	var/mob/living/basic/trooper/pirate/faction/basic_pirate = allocate(/mob/living/basic/trooper/pirate/faction/grey/melee)
	TEST_ASSERT(counter.counts_victim(basic_pirate), "A suppression sweep stopped counting the basic faction pirates")
