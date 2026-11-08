// Human NPC base (voidcrew/modules/human_npcs/). Unit tests are included before voidcrew/_DEFINES, so
// these use the sample types and the module's procs, never its HUMAN_NPC_* defines.

/// Waits up to a second for `thing` to be deleted. Locked gear that leaves its NPC goes on the next tick.
/datum/unit_test/proc/human_npc_wait_deleted(datum/thing)
	for(var/i in 1 to 10)
		if(QDELETED(thing))
			return TRUE
		sleep(1)
	return QDELETED(thing)

/// Life() does nothing while no player is on the z-level and runs once one is; a corpse is dormant
/// the same way, and when it wakes it catches up the organ decay it slept through.
/datum/unit_test/voidcrew_human_npc_dormancy

/datum/unit_test/voidcrew_human_npc_dormancy/Run()
	var/mob/living/carbon/human/npc/sample/swashbuckler/npc = allocate(/mob/living/carbon/human/npc/sample/swashbuckler)
	var/turf/here = get_turf(npc)
	TEST_ASSERT(!length(SSmobs.clients_by_zlevel[here.z]), "Test fixture: a client is on the test z-level")
	TEST_ASSERT(npc.npc_dormant(), "An NPC with no player on its z-level is not dormant")

	npc.bodytemperature = 250
	npc.Life(SSMOBS_DT, 1)
	TEST_ASSERT_EQUAL(npc.bodytemperature, 250, "A dormant NPC's Life() ran its body temperature")
	TEST_ASSERT(npc.npc_dormant_since, "A dormant NPC did not note when it fell asleep")

	// A player arrives. The NPC stands in for them in the z-level's client list for the length of
	// one Life() call; nothing else runs in between.
	SSmobs.clients_by_zlevel[here.z] += npc
	var/awake = !npc.npc_dormant()
	npc.Life(SSMOBS_DT, 2)
	SSmobs.clients_by_zlevel[here.z] -= npc
	TEST_ASSERT(awake, "An NPC with a player on its z-level is dormant")
	TEST_ASSERT(npc.bodytemperature != 250, "An awake NPC's Life() did not run")
	TEST_ASSERT(!npc.npc_dormant_since, "An NPC that woke still thinks it is asleep")

	// Dead: dormant without a player, and a corpse that slept an hour has the organs of one dead an hour.
	npc.death()
	npc.bodytemperature = BODYTEMP_NORMAL
	var/obj/item/organ/heart/heart = npc.get_organ_slot(ORGAN_SLOT_HEART)
	TEST_ASSERT_NOTNULL(heart, "Test fixture: the NPC has no heart")
	npc.Life(SSMOBS_DT, 3)
	TEST_ASSERT(!(heart.organ_flags & ORGAN_FAILING), "A fresh corpse's heart has already failed")
	TEST_ASSERT(npc.npc_dormant_since, "A dormant corpse did not note when it fell asleep")
	npc.npc_dormant_since = world.time - 1 HOURS
	SSmobs.clients_by_zlevel[here.z] += npc
	npc.Life(SSMOBS_DT, 4)
	SSmobs.clients_by_zlevel[here.z] -= npc
	TEST_ASSERT(heart.organ_flags & ORGAN_FAILING, "A corpse that slept for an hour woke with a working heart")
	TEST_ASSERT(npc.can_defib() != DEFIB_POSSIBLE, "A corpse dead for an hour could still be defibrillated")

/// No mood and no hunger, and nothing done to stamina or stuns: a baton works on an NPC as on a player.
/datum/unit_test/voidcrew_human_npc_body_trims

/datum/unit_test/voidcrew_human_npc_body_trims/Run()
	var/mob/living/carbon/human/npc/sample/gunner/npc = allocate(/mob/living/carbon/human/npc/sample/gunner)
	TEST_ASSERT_NULL(npc.mob_mood, "A human NPC has a mood datum")
	TEST_ASSERT(HAS_TRAIT(npc, TRAIT_NOHUNGER), "A human NPC gets hungry")
	TEST_ASSERT_EQUAL(npc.physiology.stamina_mod, 1, "A human NPC's stamina damage is scaled")
	TEST_ASSERT_EQUAL(npc.physiology.stun_mod, 1, "A human NPC's stuns are scaled")
	TEST_ASSERT_EQUAL(npc.physiology.brute_mod, 1, "A regular human NPC takes scaled brute damage")

	var/mob/living/carbon/human/npc/sample/elite/elite = allocate(/mob/living/carbon/human/npc/sample/elite)
	TEST_ASSERT_EQUAL(elite.physiology.brute_mod, 0.75, "The elite's toughness did not reach its brute mod")
	TEST_ASSERT_EQUAL(elite.physiology.burn_mod, 0.75, "The elite's toughness did not reach its burn mod")
	TEST_ASSERT_EQUAL(elite.physiology.stamina_mod, 1, "Toughness changed stamina damage")
	elite.set_npc_toughness(0.5)
	TEST_ASSERT_EQUAL(elite.physiology.brute_mod, 0.5, "set_npc_toughness() did not replace the old multiplier")

	npc.adjustStaminaLoss(200)
	TEST_ASSERT(npc.has_status_effect(/datum/status_effect/incapacitating/stamcrit), "200 stamina damage did not stamcrit a human NPC")
	TEST_ASSERT(npc.ai_controller.get_able_to_run() & AI_UNABLE_TO_RUN, "A stamcrit human NPC's AI can still act")

/// The strip menu never opens, the NPC never lets go of its kit, and kit forced off it is deleted,
/// unless it is straight back on the NPC (a tactical reload drops the old magazine and catches it).
/datum/unit_test/voidcrew_human_npc_gear_lock

/datum/unit_test/voidcrew_human_npc_gear_lock/Run()
	var/mob/living/carbon/human/npc/sample/gunner/npc = allocate(/mob/living/carbon/human/npc/sample/gunner)
	var/mob/living/carbon/human/consistent/player = allocate(/mob/living/carbon/human/consistent)
	var/obj/item/gun/gun = locate() in npc.held_items
	TEST_ASSERT_NOTNULL(gun, "The sample gunner holds no gun")
	var/obj/item/ammo_box/magazine/spare = locate() in npc.belt
	TEST_ASSERT_NOTNULL(spare, "The sample gunner carries no spare magazine")
	for(var/obj/item/kit as anything in list(gun, spare, npc.w_uniform, npc.wear_suit, npc.head, npc.shoes, npc.belt))
		TEST_ASSERT(human_npc_gear_locked(kit), "[kit] is not locked to the NPC")
	TEST_ASSERT(!human_npc_gear_locked(npc.get_bodypart(BODY_ZONE_CHEST)), "A body part was locked as gear")

	TEST_ASSERT(!npc.should_strip(player), "The strip menu would open on a human NPC")
	TEST_ASSERT(!npc.dropItemToGround(gun), "A human NPC let go of its gun")
	TEST_ASSERT(npc.is_holding(gun), "The gun left the NPC's hand")
	TEST_ASSERT(!npc.transferItemToLoc(gun, player), "A human NPC handed its gun over")
	TEST_ASSERT(!npc.dropItemToGround(npc.wear_suit), "A human NPC took off its armour")
	TEST_ASSERT(SEND_SIGNAL(gun, COMSIG_ITEM_PRE_EXPORT) & COMPONENT_STOP_EXPORT, "A human NPC's gun can be sold")

	// Moves that end on the NPC still work.
	TEST_ASSERT(npc.temporarilyRemoveItemFromInventory(gun), "The NPC could not move its own gun")
	TEST_ASSERT(npc.put_in_hands(gun), "The NPC could not take its gun back")

	// Forced out and straight back: kept.
	spare.forceMove(get_turf(npc))
	TEST_ASSERT(npc.put_in_hands(spare), "The NPC could not catch its magazine")
	sleep(2)
	TEST_ASSERT(!QDELETED(spare), "A magazine that left the NPC and came straight back was deleted")

	// Forced out for good: deleted.
	npc.dropItemToGround(gun, force = TRUE)
	TEST_ASSERT(isturf(gun.loc), "A forced drop did not put the gun on the floor")
	TEST_ASSERT(human_npc_wait_deleted(gun), "A human NPC's gun forced out of its hand was left lying around")

/// Cutting off the gun arm or the head, death and gibbing never leave the NPC's kit for players; the
/// limbs and gore stay. Its designed death cash drops once, however often it dies.
/datum/unit_test/voidcrew_human_npc_gear_body

/datum/unit_test/voidcrew_human_npc_gear_body/Run()
	var/mob/living/carbon/human/npc/sample/gunner/npc = allocate(/mob/living/carbon/human/npc/sample/gunner)
	var/obj/item/gun/gun = locate() in npc.held_items
	var/obj/item/bodypart/arm = npc.hand_bodyparts[npc.get_held_index_of_item(gun)]
	TEST_ASSERT_NOTNULL(arm, "Test fixture: the gun is in no hand")
	TEST_ASSERT(arm.dismember(), "The gun arm would not come off")
	TEST_ASSERT(isturf(arm.loc), "The severed arm is not on the floor")
	TEST_ASSERT(human_npc_wait_deleted(gun), "A severed arm handed over the NPC's gun")

	var/obj/item/hat = npc.head
	var/obj/item/bodypart/head/head = npc.get_bodypart(BODY_ZONE_HEAD)
	TEST_ASSERT(head.dismember(), "The NPC's head would not come off")
	TEST_ASSERT(human_npc_wait_deleted(hat), "The NPC's hat was left behind when its head came off")

	// Death keeps everything on the body.
	// On its own tile: the first NPC died when its head came off, and dropped its own cash.
	var/turf/floor = locate(run_loc_floor_bottom_left.x + 2, run_loc_floor_bottom_left.y + 2, run_loc_floor_bottom_left.z)
	var/mob/living/carbon/human/npc/sample/gunner/victim = allocate(/mob/living/carbon/human/npc/sample/gunner, floor)
	var/list/kit = victim.get_equipped_items(INCLUDE_POCKETS | INCLUDE_HELD)
	victim.death()
	for(var/obj/item/worn as anything in kit)
		TEST_ASSERT(!QDELETED(worn) && human_npc_holding(worn) == victim, "[worn] came off the NPC when it died")
	var/obj/item/holochip/cash = locate() in floor
	TEST_ASSERT_NOTNULL(cash, "The NPC's death cash did not drop")
	qdel(cash)
	victim.revive(HEAL_ALL)
	victim.death()
	TEST_ASSERT_NULL(locate(/obj/item/holochip) in floor, "The NPC's death cash dropped a second time")

	// Gibbing deletes the kit with the body.
	var/mob/living/carbon/human/npc/sample/gunner/gibbed = allocate(/mob/living/carbon/human/npc/sample/gunner)
	var/list/gibbed_kit = list()
	for(var/obj/item/item as anything in gibbed.get_all_contents_type(/obj/item))
		if(human_npc_gear_locked(item))
			gibbed_kit += item
	TEST_ASSERT(length(gibbed_kit), "Test fixture: the gibbed NPC carried nothing locked")
	gibbed.gib(DROP_ALL_REMAINS)
	for(var/obj/item/item as anything in gibbed_kit)
		TEST_ASSERT(human_npc_wait_deleted(item), "[item] survived its NPC being gibbed")

/// D4: only elite and boss human NPCs land aimed crits; only bosses execute (OC-9). Players always can.
/datum/unit_test/voidcrew_human_npc_crit_policy

/datum/unit_test/voidcrew_human_npc_crit_policy/Run()
	var/mob/living/carbon/human/consistent/victim = allocate(/mob/living/carbon/human/consistent)
	var/mob/living/carbon/human/npc/sample/gunner/regular = allocate(/mob/living/carbon/human/npc/sample/gunner)
	var/mob/living/carbon/human/npc/sample/elite/elite = allocate(/mob/living/carbon/human/npc/sample/elite)
	var/obj/item/bodypart/head = victim.get_bodypart(BODY_ZONE_HEAD)
	var/obj/item/spear/spear = allocate(/obj/item/spear)

	TEST_ASSERT(regular.put_in_hands(spear), "Test fixture: the regular NPC can't hold a spear")
	TEST_ASSERT_NULL(hv_crit_get_aimer(spear), "A regular human NPC counts as aiming its hits")
	regular.zone_selected = BODY_ZONE_PRECISE_EYES
	// As in the crit tests: +90 keeps the roll over the eye threshold and under a dismember.
	victim.apply_damage(15, BRUTE, head, wound_bonus = 90, sharpness = SHARP_POINTY, attacking_item = spear)
	TEST_ASSERT_NULL(head.get_wound_type(/datum/wound/pierce/bleed/severe/eye/hv_gouged), "A regular human NPC tore an eye out")

	TEST_ASSERT(regular.dropItemToGround(spear), "Test fixture: the NPC kept a spear it was handed")
	TEST_ASSERT(elite.put_in_hands(spear), "Test fixture: the elite can't hold a spear")
	TEST_ASSERT_EQUAL(hv_crit_get_aimer(spear), elite, "An elite human NPC doesn't count as aiming its hits")
	elite.zone_selected = BODY_ZONE_PRECISE_EYES
	victim.apply_damage(15, BRUTE, head, wound_bonus = 90, sharpness = SHARP_POINTY, attacking_item = spear)
	TEST_ASSERT_NOTNULL(head.get_wound_type(/datum/wound/pierce/bleed/severe/eye/hv_gouged), "An elite human NPC could not land an eye crit")

	var/obj/item/gun/regular_gun = locate() in regular.held_items
	var/obj/item/gun/elite_gun = locate() in elite.held_items
	victim.Knockdown(30 SECONDS)
	TEST_ASSERT(!regular_gun.hv_execution_possible(regular, victim), "A regular human NPC can execute a downed player")
	TEST_ASSERT(!elite_gun.hv_execution_possible(elite, victim), "An elite human NPC can execute a downed player; only bosses may")
	elite.npc_rank = 2 // HUMAN_NPC_RANK_BOSS; tests compile before voidcrew defines
	TEST_ASSERT(elite_gun.hv_execution_possible(elite, victim), "A boss human NPC can't execute a downed player")

/// spawn_human_npc() queues bodies; the subsystem builds them a budget at a time, and a cancelled
/// order builds nothing.
/datum/unit_test/voidcrew_human_npc_spawn_queue

/datum/unit_test/voidcrew_human_npc_spawn_queue/Run()
	TEST_ASSERT(!length(SSmobs.clients_by_zlevel[run_loc_floor_bottom_left.z]), "Test fixture: a client is on the test z-level")
	TEST_ASSERT(!length(SShuman_npcs.queue), "Test fixture: the human NPC queue is not empty")
	var/list/datum/human_npc_order/orders = list()
	for(var/i in 1 to 3)
		orders += spawn_human_npc(/mob/living/carbon/human/npc/sample/swashbuckler, run_loc_floor_bottom_left)
	for(var/datum/human_npc_order/order as anything in orders)
		TEST_ASSERT_NULL(order.spawned_ref, "spawn_human_npc() built a body at once")
	TEST_ASSERT_EQUAL(SShuman_npcs.process_spawns(1), 1, "A budget of one built [length(orders) - length(SShuman_npcs.queue)] bodies")
	TEST_ASSERT_EQUAL(length(SShuman_npcs.queue), 2, "The queue did not keep the rest")
	TEST_ASSERT_EQUAL(SShuman_npcs.process_spawns(10), 2, "The queue did not build the rest")
	for(var/datum/human_npc_order/order as anything in orders)
		var/mob/living/carbon/human/npc/built = order.spawned_ref?.resolve()
		TEST_ASSERT(istype(built, /mob/living/carbon/human/npc/sample/swashbuckler), "An order built [built || "nothing"]")
		TEST_ASSERT_EQUAL(get_turf(built), run_loc_floor_bottom_left, "A queued NPC appeared in the wrong place")
		allocated += built

	var/datum/human_npc_order/cancelled = spawn_human_npc(/mob/living/carbon/human/npc/sample/swashbuckler, run_loc_floor_bottom_left)
	qdel(cancelled)
	TEST_ASSERT_EQUAL(SShuman_npcs.process_spawns(5), 0, "A cancelled order was built")

	// An order's overrides reach the body, and a spawner path dresses it.
	var/datum/human_npc_order/dressed = spawn_human_npc(/mob/living/carbon/human/npc/sample/gunner, run_loc_floor_bottom_left, name = "Test Name", faction = list("human_npc_test"), immediate = TRUE)
	var/mob/living/carbon/human/npc/dressed_npc = dressed.spawned_ref?.resolve()
	TEST_ASSERT_NOTNULL(dressed_npc, "An immediate order built nothing")
	allocated += dressed_npc
	TEST_ASSERT_EQUAL(dressed_npc.real_name, "Test Name", "The order's name did not stick")
	TEST_ASSERT(("human_npc_test" in dressed_npc.faction) && !(FACTION_PIRATE in dressed_npc.faction), "The order's faction did not replace the type's")

	var/datum/human_npc_order/skeleton = spawn_human_npc(/mob/living/carbon/human/npc/sample/swashbuckler, run_loc_floor_bottom_left, look = /obj/effect/mob_spawn/corpse/human/old_pirate_captain, immediate = TRUE)
	var/mob/living/carbon/human/npc/skeleton_npc = skeleton.spawned_ref?.resolve()
	allocated += skeleton_npc
	TEST_ASSERT(istype(skeleton_npc?.dna.species, /datum/species/skeleton), "A spawner look did not give the spawner's species")

/// Human NPCs take wounds, bleed, lose limbs and have their heads burst as a player does.
/datum/unit_test/voidcrew_human_npc_gore

/datum/unit_test/voidcrew_human_npc_gore/Run()
	var/mob/living/carbon/human/npc/sample/swashbuckler/npc = allocate(/mob/living/carbon/human/npc/sample/swashbuckler)
	var/obj/item/bodypart/arm = npc.get_bodypart(BODY_ZONE_L_ARM)
	npc.apply_damage(25, BRUTE, arm, wound_bonus = 60, sharpness = SHARP_EDGED)
	TEST_ASSERT(length(arm.wounds), "A heavy cut left no wound on a human NPC")
	var/blood_before = npc.blood_volume
	npc.bleed(20)
	TEST_ASSERT(npc.blood_volume < blood_before, "A human NPC did not lose blood")
	TEST_ASSERT(arm.dismember(), "A human NPC's arm would not come off")
	TEST_ASSERT_NULL(npc.get_bodypart(BODY_ZONE_L_ARM), "The arm is still on")

	npc.death()
	var/obj/item/organ/brain/brain = npc.get_organ_slot(ORGAN_SLOT_BRAIN)
	TEST_ASSERT(npc.hv_burst_head(NORTH), "A dead human NPC's head would not burst")
	TEST_ASSERT_NULL(npc.get_bodypart(BODY_ZONE_HEAD), "The burst head is still on")
	TEST_ASSERT(!QDELETED(brain) && isturf(brain.loc), "The burst head did not throw its brain out")

/// The AI keeps working the cuffs when cuffed (tg's escape_captivity) and reloads its gun from the
/// magazines it carries through the gun's own reload path, then fires the real gun.
/datum/unit_test/voidcrew_human_npc_ai_hands

/datum/unit_test/voidcrew_human_npc_ai_hands/Run()
	var/mob/living/carbon/human/npc/sample/swashbuckler/cuffed = allocate(/mob/living/carbon/human/npc/sample/swashbuckler)
	var/obj/item/restraints/handcuffs/cuffs = allocate(/obj/item/restraints/handcuffs)
	TEST_ASSERT(cuffed.equip_to_slot_if_possible(cuffs, ITEM_SLOT_HANDCUFFED), "Test fixture: the NPC could not be cuffed")
	TEST_ASSERT(HAS_TRAIT(cuffed, TRAIT_RESTRAINED), "A cuffed NPC isn't restrained")
	TEST_ASSERT(!(cuffed.ai_controller.get_able_to_run() & AI_UNABLE_TO_RUN), "A cuffed NPC's AI stopped, so it can't work at the cuffs")

	var/mob/living/carbon/human/npc/sample/gunner/npc = allocate(/mob/living/carbon/human/npc/sample/gunner)
	var/obj/item/gun/ballistic/automatic/pistol/gun = locate() in npc.held_items
	TEST_ASSERT_NOTNULL(gun, "The sample gunner holds no pistol")
	gun.can_misfire = FALSE
	var/obj/item/ammo_box/magazine/first_mag = gun.magazine
	// Spend it, as firing it dry would.
	var/obj/item/ammo_casing/round = first_mag.get_round()
	while(round)
		qdel(round)
		round = first_mag.get_round()
	QDEL_NULL(gun.chambered)
	TEST_ASSERT(!gun.can_shoot(), "Test fixture: the pistol can still fire")
	var/obj/item/ammo_box/magazine/spare = human_npc_find_ammo(npc, gun)
	TEST_ASSERT_NOTNULL(spare, "The gunner can't find its spare magazines")

	var/datum/ai_controller/controller = npc.ai_controller
	var/datum/ai_behavior/human_npc_reload/reload = GET_AI_BEHAVIOR(/datum/ai_behavior/human_npc_reload)
	TEST_ASSERT(reload.setup(controller), "The reload would not start")
	var/finished = FALSE
	for(var/step in 1 to 10)
		// The waits between steps that the controller's cooldowns would give
		npc.next_click = 0
		npc.next_move = 0
		var/result = reload.perform(1, controller)
		TEST_ASSERT(!(result & AI_BEHAVIOR_FAILED), "The reload failed at step [step]")
		if(result & AI_BEHAVIOR_SUCCEEDED)
			finished = TRUE
			break
	TEST_ASSERT(finished, "The reload never finished")
	TEST_ASSERT(gun.can_shoot(), "The reload left the pistol unable to fire")
	TEST_ASSERT_EQUAL(gun.magazine, spare, "The pistol doesn't hold the spare magazine")
	TEST_ASSERT(!npc.is_holding(first_mag), "The NPC kept hold of the empty magazine")
	TEST_ASSERT(human_npc_wait_deleted(first_mag), "The dropped empty magazine was left for players")

	// One click fires the real gun.
	var/mob/living/carbon/human/consistent/target = allocate(/mob/living/carbon/human/consistent, locate(run_loc_floor_bottom_left.x + 2, run_loc_floor_bottom_left.y, run_loc_floor_bottom_left.z))
	var/rounds_before = spare.ammo_count(FALSE)
	npc.next_click = 0
	npc.next_move = 0
	human_npc_ready_item(npc, gun)
	controller.ai_interact(target = target, combat_mode = TRUE)
	TEST_ASSERT(spare.ammo_count(FALSE) < rounds_before || !gun.chambered?.loaded_projectile, "A click with the pistol did not fire it")

/// Corpses are cleaned up after their lifetime when nobody is near, with the limbs they lost, but
/// never while dragged.
/datum/unit_test/voidcrew_human_npc_corpse_cleanup

/datum/unit_test/voidcrew_human_npc_corpse_cleanup/Run()
	var/mob/living/carbon/human/npc/sample/swashbuckler/npc = allocate(/mob/living/carbon/human/npc/sample/swashbuckler)
	TEST_ASSERT(!npc.npc_corpse_expired(), "A living NPC can be cleaned up")
	var/obj/item/bodypart/leg = npc.get_bodypart(BODY_ZONE_L_LEG)
	TEST_ASSERT(leg.dismember(), "Test fixture: the leg would not come off")
	npc.death()
	TEST_ASSERT(npc in SShuman_npcs.corpses, "A dead NPC's corpse is not tracked")
	TEST_ASSERT(!npc.npc_corpse_expired(), "A fresh corpse can be cleaned up")
	npc.npc_died_at = world.time - npc.npc_corpse_lifetime - 1
	TEST_ASSERT(npc.npc_corpse_expired(), "An old corpse nobody is near can't be cleaned up")

	var/mob/living/carbon/human/consistent/dragger = allocate(/mob/living/carbon/human/consistent)
	dragger.start_pulling(npc)
	TEST_ASSERT(!npc.npc_corpse_expired(), "A corpse being dragged can be cleaned up")
	dragger.stop_pulling()

	npc.revive(HEAL_ALL)
	TEST_ASSERT(!(npc in SShuman_npcs.corpses), "A revived NPC is still tracked as a corpse")
	npc.death()
	npc.npc_died_at = world.time - npc.npc_corpse_lifetime - 1
	npc.npc_fade()
	TEST_ASSERT(QDELETED(npc), "npc_fade() left the corpse")
	TEST_ASSERT(QDELETED(leg), "npc_fade() left the leg the NPC lost")

/// Systems built for basic-mob NPCs treat human NPCs as the NPCs they are: hull turrets shoot them,
/// weather reaches them while they are awake, and pirate crews can take them on.
/datum/unit_test/voidcrew_human_npc_world_gates

/datum/unit_test/voidcrew_human_npc_world_gates/Run()
	var/obj/machinery/porta_turret/ship_defense/turret = allocate(/obj/machinery/porta_turret/ship_defense)
	var/mob/living/carbon/human/npc/sample/gunner/npc = allocate(/mob/living/carbon/human/npc/sample/gunner)
	var/mob/living/carbon/human/consistent/person = allocate(/mob/living/carbon/human/consistent)
	TEST_ASSERT(turret.valid_target(npc), "A hull turret won't shoot a human NPC boarder")
	TEST_ASSERT(!turret.valid_target(person), "A hull turret would shoot a person")
	var/mob/living/carbon/human/npc/sample/gunner/possessed = allocate(/mob/living/carbon/human/npc/sample/gunner)
	possessed.mind_initialize()
	TEST_ASSERT(!turret.valid_target(possessed), "A hull turret would shoot a human NPC body with a mind in it")

	TEST_ASSERT(!human_npc_weathered(npc), "Weather reaches a dormant human NPC")
	var/turf/here = get_turf(npc)
	SSmobs.clients_by_zlevel[here.z] += npc
	var/weathered = human_npc_weathered(npc)
	SSmobs.clients_by_zlevel[here.z] -= npc
	TEST_ASSERT(weathered, "Weather doesn't reach an awake human NPC")
	TEST_ASSERT(!human_npc_weathered(person), "human_npc_weathered() took in a person")

	TEST_ASSERT(pirate_crew_can_enlist(npc), "A pirate crew can't take on a human NPC")

/// D3's exceptions: a ship key isn't gear and drops when the NPC dies; a grenade is a consumable the NPC
/// can drop and throw, that no player can keep, and that goes when its NPC does.
/datum/unit_test/voidcrew_human_npc_gear_exceptions

/datum/unit_test/voidcrew_human_npc_gear_exceptions/Run()
	var/mob/living/carbon/human/npc/sample/gunner/npc = allocate(/mob/living/carbon/human/npc/sample/gunner)
	var/mob/living/carbon/human/consistent/player = allocate(/mob/living/carbon/human/consistent, locate(run_loc_floor_bottom_left.x + 1, run_loc_floor_bottom_left.y, run_loc_floor_bottom_left.z))
	var/obj/item/ship_key/key = allocate(/obj/item/ship_key)
	TEST_ASSERT(npc.equip_to_slot_if_possible(key, ITEM_SLOT_LPOCKET), "Test fixture: the key would not go in the NPC's pocket")
	TEST_ASSERT(!npc.npc_lock_item(key), "A ship key was locked to an NPC as gear")
	TEST_ASSERT(!human_npc_gear_locked(key) && !human_npc_gear_consumable(key), "A ship key was locked to an NPC")

	var/obj/item/grenade/smokebomb/grenade = allocate(/obj/item/grenade/smokebomb)
	TEST_ASSERT(npc.put_in_hands(grenade), "Test fixture: the NPC could not hold a grenade")
	TEST_ASSERT(npc.npc_lock_item(grenade), "A grenade handed to an NPC was not issued")
	TEST_ASSERT(human_npc_gear_consumable(grenade) && !human_npc_gear_locked(grenade), "A grenade was locked like gear instead of issued as a consumable")
	TEST_ASSERT(HAS_TRAIT(npc, TRAIT_CAN_THROW_ITEMS), "Test fixture: the NPC can't throw")
	TEST_ASSERT(human_npc_ready_item(npc, grenade), "Test fixture: the grenade is not in the NPC's hand")
	npc.throw_item(locate(run_loc_floor_bottom_left.x + 3, run_loc_floor_bottom_left.y + 3, run_loc_floor_bottom_left.z))
	TEST_ASSERT(!npc.is_holding(grenade), "The NPC could not throw its grenade")
	sleep(1 SECONDS)
	TEST_ASSERT(!QDELETED(grenade) && isturf(grenade.loc), "A thrown grenade was deleted where it landed")
	player.put_in_hands(grenade)
	TEST_ASSERT(human_npc_wait_deleted(grenade), "A player kept an NPC's grenade")

	// Dropped like anyone's, and gone with its NPC.
	var/obj/item/grenade/smokebomb/dropped = allocate(/obj/item/grenade/smokebomb)
	npc.put_in_hands(dropped)
	npc.npc_lock_item(dropped)
	TEST_ASSERT(npc.dropItemToGround(dropped), "An NPC could not let go of a grenade")
	sleep(2)
	TEST_ASSERT(!QDELETED(dropped), "A grenade an NPC dropped was deleted on the floor")

	var/obj/item/gun/gun = locate() in npc.held_items
	npc.death()
	TEST_ASSERT(isturf(key.loc), "The ship key did not drop when the NPC died")
	TEST_ASSERT(human_npc_holding(gun) == npc, "The NPC's gun came off when it died")
	qdel(npc)
	TEST_ASSERT(QDELETED(dropped), "A loose grenade outlived the NPC that carried it")

/// Owner ruling: an NPC's chrome works like a player's in life (a dodge shunt dodges) and burns out to
/// scrap when it dies or the ware is taken out of it.
/datum/unit_test/voidcrew_human_npc_chrome

/datum/unit_test/voidcrew_human_npc_chrome/Run()
	var/mob/living/carbon/human/npc/sample/swashbuckler/npc = allocate(/mob/living/carbon/human/npc/sample/swashbuckler)
	var/obj/item/organ/cyberimp/cyberware/slipwire/shunt = npc.npc_install_cyberware(/obj/item/organ/cyberimp/cyberware/slipwire)
	TEST_ASSERT_NOTNULL(shunt, "A dodge shunt would not install in an NPC")
	TEST_ASSERT_EQUAL(shunt.owner, npc, "The dodge shunt is not in the NPC")
	TEST_ASSERT_NOTNULL(npc.GetComponent(/datum/component/cyberware_dodge), "An NPC's dodge shunt registered no dodge")
	TEST_ASSERT(shunt.get_dodge_chance() > 0, "An NPC's working dodge shunt gives no dodge chance")

	var/turf/floor = get_turf(npc)
	npc.death()
	TEST_ASSERT(QDELETED(shunt), "An NPC's chrome came through its death working")
	TEST_ASSERT_NOTNULL(locate(/obj/item/burnt_chrome) in floor, "An NPC's chrome left no scrap")
	TEST_ASSERT_NULL(npc.GetComponent(/datum/component/cyberware_dodge), "A dead NPC still dodges")

	// Taken out of a living NPC: scrap too.
	var/turf/elsewhere = locate(run_loc_floor_bottom_left.x + 2, run_loc_floor_bottom_left.y, run_loc_floor_bottom_left.z)
	var/mob/living/carbon/human/npc/sample/swashbuckler/patient = allocate(/mob/living/carbon/human/npc/sample/swashbuckler, elsewhere)
	var/obj/item/organ/ware = patient.npc_install_cyberware(/obj/item/organ/cyberimp/cyberware/slipwire)
	TEST_ASSERT_NOTNULL(ware, "Test fixture: the second shunt would not install")
	ware.Remove(patient)
	ware.forceMove(elsewhere)
	TEST_ASSERT(human_npc_wait_deleted(ware), "Chrome taken out of a living NPC stayed working")
	TEST_ASSERT_NOTNULL(locate(/obj/item/burnt_chrome) in elsewhere, "Chrome taken out of a living NPC left no scrap")
