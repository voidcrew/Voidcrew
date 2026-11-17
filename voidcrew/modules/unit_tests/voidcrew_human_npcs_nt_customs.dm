// NT customs as human NPCs (voidcrew/modules/npc_ships/code/faction_pirates/nt_patrol.dm, human NPC
// migration phase E1). Unit tests compile before voidcrew/_DEFINES, so values from there are written out:
// zones 1 green, 2 yellow, 3 red; ranks 0 regular, 1 elite, 2 boss.

/**
 * The corvette's crew, boarders and the Compliance Director are human NPCs on the pirate crew AI, dressed
 * as tg's Nanotrasen troopers with the guns the basic mobs fired by zone, their CentCom ID cards locked to
 * them, on the Deathsquad side and never counted as pirates; boarders are sealed and carry air; only the
 * Director carries designed loot.
 */
/datum/unit_test/voidcrew_human_npc_nt_customs

/datum/unit_test/voidcrew_human_npc_nt_customs/Run()
	var/obj/structure/overmap/ship/npc/pirate/nt_patrol/patrol = allocate(/obj/structure/overmap/ship/npc/pirate/nt_patrol)
	TEST_ASSERT(ispath(patrol.captain_type, /mob/living/carbon/human/npc/faction_pirate/nt_customs), "The patrol's captain isn't a human customs NPC")
	TEST_ASSERT(ispath(patrol.boss_type, /mob/living/carbon/human/npc/faction_pirate/nt_customs/director), "The patrol's boss isn't the human Compliance Director")
	for(var/crew_type in patrol.crew_types + patrol.boarding_pod_mob_types)
		TEST_ASSERT(ispath(crew_type, /mob/living/carbon/human/npc/faction_pirate/nt_customs), "[crew_type] in the patrol's crew isn't a human customs NPC")

	for(var/zone in 1 to 3)
		var/mob/living/carbon/human/npc/faction_pirate/nt_customs/officer/officer = human_npc_build_in_zone(/mob/living/carbon/human/npc/faction_pirate/nt_customs/officer, zone)
		var/mob/living/carbon/human/npc/faction_pirate/nt_customs/inspector/inspector = human_npc_build_in_zone(/mob/living/carbon/human/npc/faction_pirate/nt_customs/inspector, zone)
		var/mob/living/carbon/human/npc/faction_pirate/nt_customs/sergeant/sergeant = human_npc_build_in_zone(/mob/living/carbon/human/npc/faction_pirate/nt_customs/sergeant, zone)
		TEST_ASSERT_NOTNULL(locate(/obj/item/melee/baton/security) in officer?.held_items, "A customs officer doesn't hold a stun baton in zone [zone]")
		var/obj/item/gun/ballistic/inspector_gun = human_npc_held_gun(inspector)
		var/obj/item/gun/ballistic/sergeant_gun = human_npc_held_gun(sergeant)
		if(zone == 3)
			TEST_ASSERT(istype(inspector_gun, /obj/item/gun/ballistic/automatic/wt550), "A red-zone customs inspector doesn't hold a WT-550")
			TEST_ASSERT(istype(sergeant_gun, /obj/item/gun/ballistic/automatic/ar), "A red-zone customs sergeant doesn't hold a rifle")
		else
			TEST_ASSERT(istype(inspector_gun, /obj/item/gun/ballistic/automatic/pistol/m1911), "A zone [zone] customs inspector doesn't hold the ladder pistol")
			TEST_ASSERT(istype(sergeant_gun, /obj/item/gun/ballistic/automatic/pistol/m1911), "A zone [zone] customs sergeant doesn't hold the ladder pistol")
		TEST_ASSERT_NOTNULL(human_npc_find_ammo(inspector, inspector_gun), "A customs inspector carries no spare magazine in zone [zone]")
		TEST_ASSERT_NOTNULL(human_npc_find_ammo(sergeant, sergeant_gun), "A customs sergeant carries no spare magazine in zone [zone]")
		TEST_ASSERT_EQUAL(sergeant?.npc_rank, 1, "The customs sergeant isn't an elite")
		for(var/mob/living/carbon/human/npc/faction_pirate/nt_customs/customs as anything in list(officer, inspector, sergeant))
			TEST_ASSERT_NOTNULL(customs, "A customs NPC wasn't built in zone [zone]")
			if(isnull(customs))
				continue
			TEST_ASSERT(ROLE_DEATHSQUAD in customs.faction, "[customs.type] isn't on the Deathsquad side its corvette is keyed to")
			TEST_ASSERT(!(FACTION_PIRATE in customs.faction), "[customs.type] counts as a pirate")
			TEST_ASSERT_EQUAL(customs.ai_controller?.type, /datum/ai_controller/basic_controller/pirate_crew/human, "[customs.type] isn't on the human crew AI")
			var/obj/item/card/id/advanced/centcom/card = customs.wear_id
			TEST_ASSERT(istype(card), "[customs.type] carries no CentCom ID card")
			TEST_ASSERT(human_npc_gear_locked(card), "[customs.type]'s CentCom ID card isn't locked to it")
			TEST_ASSERT(HAS_TRAIT(card, TRAIT_NO_STRIP), "[customs.type]'s CentCom ID card shows in the strip menu")
			TEST_ASSERT_EQUAL(card?.registered_name, customs.real_name, "[customs.type]'s ID card doesn't carry its name")
			TEST_ASSERT(human_npc_gear_locked(customs.w_uniform), "[customs.type]'s uniform isn't locked to it")
			TEST_ASSERT(!length(customs.npc_roll_death_loot()), "[customs.type] rolls death loot; a customs vessel is no prize")
			TEST_ASSERT_EQUAL(customs.npc_death_cash, 0, "[customs.type] carries cash")
			TEST_ASSERT_EQUAL(customs.maxHealth, 100, "[customs.type]'s max health isn't a person's")

	// Boarders cross space: sealed, with air they can breathe.
	var/datum/human_npc_order/order = new /datum/human_npc_order(/mob/living/carbon/human/npc/faction_pirate/nt_customs/officer, run_loc_floor_bottom_left)
	order.outfit = boarding_outfit_for(/mob/living/carbon/human/npc/faction_pirate/nt_customs/officer)
	order.zone = 2
	var/mob/living/carbon/human/npc/faction_pirate/nt_customs/officer/boarder = order.fulfil()
	qdel(order)
	allocated += boarder
	TEST_ASSERT(boarder?.wear_suit && (boarder.wear_suit.clothing_flags & STOPSPRESSUREDAMAGE), "A customs boarder has no sealed suit")
	TEST_ASSERT(boarder?.head && (boarder.head.clothing_flags & STOPSPRESSUREDAMAGE), "A customs boarder has no sealed helmet")
	TEST_ASSERT(boarder?.can_breathe_internals() && length(boarder.get_all_contents_type(/obj/item/tank/internals)), "A customs boarder carries no air it can breathe")

	// The Director: a boss with his e-gun, his baton and the fines.
	var/mob/living/carbon/human/npc/faction_pirate/nt_customs/director/director = human_npc_build_in_zone(/mob/living/carbon/human/npc/faction_pirate/nt_customs/director, 3)
	TEST_ASSERT_EQUAL(director?.npc_rank, 2, "The Compliance Director isn't a boss")
	TEST_ASSERT(istype(human_npc_held_gun(director), /obj/item/gun/energy/e_gun), "The Compliance Director doesn't hold an e-gun")
	TEST_ASSERT(istype(director?.wear_suit, /obj/item/clothing/suit/armor), "The Compliance Director wears no body armour")
	// Written inline: a list local here once tripped a DM compiler bug in the CI build (an "invalid variable"
	// error reported in an unrelated upstream file).
	TEST_ASSERT(/obj/item/gun/energy/e_gun in director?.npc_roll_death_loot(), "The Compliance Director lost his e-gun drop")
	TEST_ASSERT(/obj/item/melee/baton/security/loaded in director?.npc_roll_death_loot(), "The Compliance Director lost his baton drop")
	TEST_ASSERT_EQUAL(director?.npc_death_cash, 2000, "The Compliance Director's fines changed")
