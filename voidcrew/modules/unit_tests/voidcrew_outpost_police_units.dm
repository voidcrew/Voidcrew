/**
 * Outpost police tests: police_units.dm (voidcrew/modules/outpost_police/). Owner: P2.
 * Helpers are in voidcrew_outpost_police_helpers.dm. Fork defines are included after the tests: use
 * literal values with a comment naming the define.
 *
 * These tests build officers on the test room's floor, with a trader outpost of the zone under test mapped
 * onto the room (the way the ambient outpost tests do), and look at what the body is: kit, locks, profile,
 * what it leaves behind, how it takes a blow. None of them waits for an AI walk.
 */

// =========================================================================
// HELPERS
// =========================================================================

/// A trader outpost of `outpost_type` mapped onto the test room, with its police. Delete it before mapping the next: the first mapped over a tile answers for it.
/datum/unit_test/proc/police_units_room_outpost(outpost_type)
	var/obj/structure/overmap/trader_outpost/outpost = allocate(outpost_type)
	outpost.outpost_template = allocate(/datum/map_template/trader_outpost)
	outpost.outpost_template.width = run_loc_floor_top_right.x - run_loc_floor_bottom_left.x + 1
	outpost.outpost_template.height = run_loc_floor_top_right.y - run_loc_floor_bottom_left.y + 1
	outpost.template_bottom_left = run_loc_floor_bottom_left
	outpost.lobby_alcove_turfs = list(run_loc_floor_top_right)
	return outpost

/// The unit kinds, in order: POLICE_UNIT_BEAT, _SERGEANT, _OFFICER, _TACTICAL, _MARSHAL
/datum/unit_test/proc/police_units_kinds()
	return list("beat", "sergeant", "officer", "tactical", "marshal")

/// Unit kind -> the officer type
/datum/unit_test/proc/police_units_types()
	return list(
		"beat" = /mob/living/carbon/human/npc/ambient_npc/outpost/police/beat,
		"sergeant" = /mob/living/carbon/human/npc/ambient_npc/outpost/police/sergeant,
		"officer" = /mob/living/carbon/human/npc/ambient_npc/outpost/police/officer,
		"tactical" = /mob/living/carbon/human/npc/ambient_npc/outpost/police/tactical,
		"marshal" = /mob/living/carbon/human/npc/ambient_npc/outpost/police/marshal,
	)

/// Outpost type -> its profile type
/datum/unit_test/proc/police_units_zones()
	return list(
		/obj/structure/overmap/trader_outpost/general = /datum/outpost_police_profile/halcyon,
		/obj/structure/overmap/trader_outpost/outfitter = /datum/outpost_police_profile/quartermain,
		/obj/structure/overmap/trader_outpost/black_market = /datum/outpost_police_profile/undertow,
	)

/// Every item on `body` that is gear: not a body part, an organ, a spent or spare casing or an abstract item
/datum/unit_test/proc/police_units_gear(mob/living/carbon/body)
	. = list()
	for(var/obj/item/thing as anything in body.get_all_contents_type(/obj/item))
		if(isbodypart(thing) || isorgan(thing) || isammocasing(thing) || (thing.item_flags & ABSTRACT))
			continue
		. += thing

/**
 * Checks that `wearer`, dressed in `outfit`, wears and holds every item the outfit names, in the slot it names,
 * and carries what its belt and backpack lists name.
 */
/datum/unit_test/proc/police_units_check_outfit(mob/living/carbon/human/wearer, datum/outfit/outfit, label)
	var/list/slots = list(
		"uniform" = list(outfit.uniform, wearer.w_uniform),
		"suit" = list(outfit.suit, wearer.wear_suit),
		"belt" = list(outfit.belt, wearer.belt),
		"gloves" = list(outfit.gloves, wearer.gloves),
		"shoes" = list(outfit.shoes, wearer.shoes),
		"head" = list(outfit.head, wearer.head),
		"mask" = list(outfit.mask, wearer.wear_mask),
		"ears" = list(outfit.ears, wearer.ears),
		"glasses" = list(outfit.glasses, wearer.glasses),
		"back" = list(outfit.back, wearer.back),
		"id" = list(outfit.id, wearer.wear_id),
		"left pocket" = list(outfit.l_pocket, wearer.l_store),
		"right pocket" = list(outfit.r_pocket, wearer.r_store),
	)
	for(var/slot in slots)
		var/list/pair = slots[slot]
		var/expected = pair[1]
		var/obj/item/worn = pair[2]
		if(!expected)
			continue
		TEST_ASSERT(worn && worn.type == expected, "[label]'s [slot] is [worn ? worn.type : "empty"], not [expected]")
	for(var/hand_item in list(outfit.l_hand, outfit.r_hand))
		if(hand_item)
			TEST_ASSERT(wearer.is_holding_item_of_type(hand_item), "[label] is not holding [hand_item]")
	var/list/carried = list("belt" = list(wearer.belt, outfit.belt_contents), "backpack" = list(wearer.back, outfit.backpack_contents))
	for(var/place in carried)
		var/list/entry = carried[place]
		var/obj/item/holder = entry[1]
		var/list/wanted = entry[2]
		for(var/path in wanted)
			var/found = 0
			for(var/obj/item/stored in holder?.contents)
				if(stored.type == path)
					found++
			TEST_ASSERT(found >= (wanted[path] || 1), "[label]'s [place] holds [found] of [path], not [wanted[path] || 1]")

// =========================================================================
// PROFILES
// =========================================================================

/// Each zone's profile is picked from the outpost's type and carries every var the spec gives it
/datum/unit_test/voidcrew_outpost_police_units_profiles

/datum/unit_test/voidcrew_outpost_police_units_profiles/Run()
	// outpost type -> profile type, force name, beat officers, fine multiplier, time to comply, spares the downed, voice section
	var/list/expected = list(
		/obj/structure/overmap/trader_outpost/general = list(/datum/outpost_police_profile/halcyon, "Halcyon Security", 3, 1, 4 SECONDS, TRUE, "halcyon"),
		/obj/structure/overmap/trader_outpost/outfitter = list(/datum/outpost_police_profile/quartermain, "Quartermain Depot Security", 2, 1.5, 3 SECONDS, TRUE, "quartermain"),
		/obj/structure/overmap/trader_outpost/black_market = list(/datum/outpost_police_profile/undertow, "the Exchange's security", 2, 2, 2 SECONDS, FALSE, "undertow"),
	)
	var/list/beat_uniforms = list()
	for(var/outpost_type in expected)
		var/list/row = expected[outpost_type]
		var/obj/structure/overmap/trader_outpost/outpost = allocate(outpost_type)
		var/datum/outpost_police_profile/profile = outpost.police?.profile
		TEST_ASSERT_NOTNULL(profile, "[outpost_type] has no police profile")
		TEST_ASSERT_EQUAL(profile.type, row[1], "[outpost_type] has a [profile.type] profile, not [row[1]]")
		TEST_ASSERT_EQUAL(profile.force_name, row[2], "[outpost_type]'s force is called [profile.force_name]")
		TEST_ASSERT_EQUAL(profile.beat_count, row[3], "[outpost_type] walks [profile.beat_count] beat officers, not [row[3]]")
		TEST_ASSERT_EQUAL(profile.fine_multiplier, row[4], "[outpost_type]'s fine multiplier is [profile.fine_multiplier], not [row[4]]")
		TEST_ASSERT_EQUAL(profile.comply_time, row[5], "[outpost_type] gives [profile.comply_time] ds to comply, not [row[5]]")
		TEST_ASSERT_EQUAL(profile.spares_downed, row[6], "[outpost_type] gets spares_downed wrong")
		TEST_ASSERT_EQUAL(profile.voice_section, row[7], "[outpost_type] speaks from [profile.voice_section]")
		for(var/kind in police_units_kinds())
			TEST_ASSERT(ispath(profile.outfits[kind], /datum/outfit), "[outpost_type] has no outfit for a [kind]")
		var/datum/outfit/beat_outfit = profile.outfits["beat"]
		beat_uniforms[initial(beat_outfit.uniform)] = TRUE
	TEST_ASSERT_EQUAL(length(beat_uniforms), 3, "The three zones' beat officers do not all wear their own uniform")

	// A plain trader outpost (no zone) still has a profile that can dress officers
	var/obj/structure/overmap/trader_outpost/plain = allocate(/obj/structure/overmap/trader_outpost)
	TEST_ASSERT_EQUAL(plain.police?.profile?.type, /datum/outpost_police_profile, "A zoneless outpost has no base profile")
	for(var/kind in police_units_kinds())
		TEST_ASSERT(ispath(plain.police.profile.outfits[kind], /datum/outfit), "The base profile has no outfit for a [kind]")

// =========================================================================
// KIT
// =========================================================================

/// Every outfit of every zone equips whole, and carries what the spec gives its unit (baton, cuffs, energy gun, radio, an ID for the police doors, abuse M5)
/datum/unit_test/voidcrew_outpost_police_units_kit

/datum/unit_test/voidcrew_outpost_police_units_kit/Run()
	// Tactical officer and marshal: the long gun of the zone, ballistic in every one
	var/list/long_guns = list(
		/datum/outpost_police_profile/halcyon = /obj/item/gun/ballistic/automatic/ar,
		/datum/outpost_police_profile/quartermain = /obj/item/gun/ballistic/shotgun/automatic/combat,
		/datum/outpost_police_profile/undertow = /obj/item/gun/ballistic/automatic/wt550,
	)
	for(var/profile_type in long_guns)
		var/datum/outpost_police_profile/profile = allocate(profile_type)
		for(var/kind in police_units_kinds())
			var/outfit_type = profile.outfits[kind]
			var/label = "[profile_type]'s [kind]"
			TEST_ASSERT(ispath(outfit_type, /datum/outfit), "[label] has no outfit")
			var/mob/living/carbon/human/wearer = allocate(/mob/living/carbon/human/consistent)
			wearer.equipOutfit(outfit_type)
			police_units_check_outfit(wearer, new outfit_type, label)

			// Everyone
			var/obj/item/card/id/card = wearer.wear_id
			TEST_ASSERT(istype(card) && ("outpost_police" in card.GetAccess()), "[label]'s ID does not open the police doors") // ACCESS_OUTPOST_POLICE
			TEST_ASSERT(istype(wearer.ears, /obj/item/radio/headset), "[label] has no radio headset")
			TEST_ASSERT(locate(/obj/item/melee/baton) in wearer.get_all_contents(), "[label] has no baton")
			TEST_ASSERT(locate(/obj/item/restraints/handcuffs/outpost_police) in wearer.get_all_contents(), "[label] has no police cuffs")
			TEST_ASSERT(locate(/obj/item/gun/energy) in wearer.get_all_contents(), "[label] has no energy gun")

			// Response officers and up: a vest, a helmet and flash-proof eyes (abuse M5)
			if(kind == "officer" || kind == "tactical" || kind == "marshal")
				TEST_ASSERT(istype(wearer.wear_suit, /obj/item/clothing/suit/armor), "[label] wears no armour")
				TEST_ASSERT(istype(wearer.head, /obj/item/clothing/head/helmet), "[label] wears no helmet")
				TEST_ASSERT(wearer.glasses && wearer.glasses.flash_protect >= FLASH_PROTECTION_FLASH, "[label] wears no flash-proof eyewear")
			else
				TEST_ASSERT_NULL(wearer.wear_suit, "[label] wears armour")

			// Tactical officer and marshal: a gas mask and a ballistic long gun of the zone, spares in the pack (abuse M5)
			if(kind == "tactical" || kind == "marshal")
				TEST_ASSERT(istype(wearer.wear_mask, /obj/item/clothing/mask/gas), "[label] wears no gas mask")
				TEST_ASSERT(wearer.is_holding_item_of_type(long_guns[profile_type]), "[label] is not holding [long_guns[profile_type]]")
				TEST_ASSERT(!wearer.is_holding_item_of_type(/obj/item/gun/energy), "[label] holds an energy gun")
				TEST_ASSERT(length(wearer.back?.contents), "[label] carries no spare ammunition")
			else
				TEST_ASSERT_NULL(wearer.wear_mask, "[label] wears a mask")
			if(kind == "marshal")
				TEST_ASSERT(istype(wearer.wear_suit, /obj/item/clothing/suit/armor/vest/marine), "The marshal does not wear the heavy plate")

// =========================================================================
// THE BODIES
// =========================================================================

/// An officer of each unit at each zone: dressed for the zone, kit locked to the body, nothing for it to drop, not a bystander, in the police's roster
/datum/unit_test/voidcrew_outpost_police_units_bodies

/datum/unit_test/voidcrew_outpost_police_units_bodies/Run()
	var/list/types = police_units_types()
	for(var/outpost_type in police_units_zones())
		var/obj/structure/overmap/trader_outpost/outpost = police_units_room_outpost(outpost_type)
		var/datum/outpost_police_profile/profile = outpost.police.profile
		var/list/officers = list()
		for(var/kind in types)
			var/mob/living/carbon/human/npc/ambient_npc/outpost/police/officer = allocate(types[kind], run_loc_floor_bottom_left)
			officers += officer
			var/label = "[officer.type] at [outpost_type]"
			TEST_ASSERT(officer.flags_1 & INITIALIZED_1, "[label] did not initialise")
			TEST_ASSERT_EQUAL(officer.unit_kind, kind, "[label] is a [officer.unit_kind], not a [kind]")
			TEST_ASSERT_EQUAL(officer.police, outpost.police, "[label] does not know the outpost's police")
			TEST_ASSERT(officer in outpost.police.officers, "[label] is not on the police roster")

			// The zone's look
			var/datum/outfit/outfit_type = profile.outfits[kind]
			TEST_ASSERT_EQUAL(officer.outfit, outfit_type, "[label] was not given the zone's outfit")
			TEST_ASSERT_EQUAL(officer.w_uniform?.type, initial(outfit_type.uniform), "[label] does not wear the zone's uniform")
			TEST_ASSERT_EQUAL(officer.dialogue_section, profile.voice_section, "[label] does not speak the zone's lines")
			TEST_ASSERT(findtext(officer.desc, profile.force_name), "[label] does not say who they work for ([officer.desc])")
			// CONSCIOUS and HARD_CRIT are HUMAN_NPC_SPARES_DOWNED and HUMAN_NPC_FINISHES_DOWNED
			var/wanted_stat = profile.spares_downed ? CONSCIOUS : HARD_CRIT
			TEST_ASSERT_EQUAL(officer.npc_target_stat, wanted_stat, "[label] has the wrong npc_target_stat")
			TEST_ASSERT_EQUAL(officer.ai_controller.blackboard[BB_TARGET_MINIMUM_STAT], wanted_stat, "[label]'s AI does not know whom to leave down")
			// HUMAN_NPC_RANK_ELITE and HUMAN_NPC_RANK_REGULAR
			TEST_ASSERT_EQUAL(officer.npc_rank, kind == "marshal" ? 1 : 0, "[label] has the wrong rank")

			// The ID reads their name and opens the police doors
			var/obj/item/card/id/card = officer.wear_id
			TEST_ASSERT(istype(card), "[label] has no ID")
			TEST_ASSERT_EQUAL(card.registered_name, officer.real_name, "[label]'s ID does not carry their name")
			TEST_ASSERT("outpost_police" in card.GetAccess(), "[label]'s ID does not open the police doors") // ACCESS_OUTPOST_POLICE

			// Nothing to drop, and the kit is locked to the body
			TEST_ASSERT(officer.npc_gear_locked, "[label]'s kit is not locked")
			TEST_ASSERT_EQUAL(officer.npc_death_cash, 0, "[label] drops cash")
			TEST_ASSERT_EQUAL(officer.death_cash_low, 0, "[label] drops cash (low)")
			TEST_ASSERT_EQUAL(officer.death_cash_high, 0, "[label] drops cash (high)")
			TEST_ASSERT(!length(officer.death_loot) && !length(officer.npc_death_loot), "[label] has death loot")
			TEST_ASSERT_EQUAL(officer.npc_corpse_lifetime, 3 MINUTES, "[label]'s body does not go in three minutes") // OUTPOST_POLICE_CORPSE_LIFETIME
			var/list/gear = police_units_gear(officer)
			TEST_ASSERT(length(gear) >= 6, "[label] carries only [length(gear)] items")
			for(var/obj/item/thing as anything in gear)
				TEST_ASSERT(human_npc_gear_locked(thing) || human_npc_gear_consumable(thing), "[label]'s [thing] is not locked to them")

			// Not a bystander: never stuffed in a locker or a bag
			TEST_ASSERT(HAS_TRAIT(officer, "no_containment"), "[label] can be put in a closet") // TRAIT_NO_CONTAINMENT
			TEST_ASSERT(HAS_TRAIT(officer, TRAIT_NO_STORAGE_INSERT), "[label] can be put in a bag")
		for(var/mob/officer as anything in officers)
			qdel(officer)
		qdel(outpost)

/// A body built at no outpost still dresses, in Halcyon's kit, and joins no roster
/datum/unit_test/voidcrew_outpost_police_units_bare

/datum/unit_test/voidcrew_outpost_police_units_bare/Run()
	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/officer = allocate(/mob/living/carbon/human/npc/ambient_npc/outpost/police/beat, run_loc_floor_bottom_left)
	TEST_ASSERT(officer.flags_1 & INITIALIZED_1, "A beat officer built at no outpost did not initialise")
	TEST_ASSERT_NULL(officer.police, "A beat officer built at no outpost has police")
	TEST_ASSERT(istype(officer.w_uniform, /obj/item/clothing/under/rank/security/officer/spacepol), "A beat officer built at no outpost is not in Halcyon's uniform")
	TEST_ASSERT_NOTNULL(officer.get_baton(), "A beat officer built at no outpost has no baton")

// =========================================================================
// DEATH
// =========================================================================

/// Killed and gibbed, an officer of every unit leaves nothing a player can hold: no cash, no loot, no kit (abuse M8)
/datum/unit_test/voidcrew_outpost_police_units_death

/datum/unit_test/voidcrew_outpost_police_units_death/Run()
	var/obj/structure/overmap/trader_outpost/outpost = police_units_room_outpost(/obj/structure/overmap/trader_outpost/general)
	var/turf/spot = run_loc_floor_bottom_left
	var/list/types = police_units_types()
	var/list/officers = list()
	for(var/kind in types)
		var/mob/living/carbon/human/npc/ambient_npc/outpost/police/officer = allocate(types[kind], spot)
		officers += officer
		officer.apply_damage(officer.maxHealth * 2, BRUTE, BODY_ZONE_CHEST, wound_bonus = CANT_WOUND) // a limb takes no more than its own max damage
		TEST_ASSERT_EQUAL(officer.stat, DEAD, "A [kind] did not die of their wounds")
		// Dead at the outpost, the body is its morgue crew's to carry off, not the corpse sweep's (spec-rehydrate 2)
		TEST_ASSERT_EQUAL(officer.npc_corpse_lifetime, 0, "A dead [kind] at the outpost is still on the corpse sweep's clock")
		TEST_ASSERT(outpost.recovery && (WEAKREF(officer) in outpost.recovery.npc_dead), "A dead [kind] is not left for the morgue crew")
		for(var/obj/item/stack/spacecash/money in spot)
			TEST_FAIL("A dead [kind] dropped cash")
		for(var/obj/item/holochip/chip in spot)
			TEST_FAIL("A dead [kind] dropped a holochip")
		// What they wore is still on the body, locked: nobody can strip it off
		for(var/obj/item/thing as anything in police_units_gear(officer))
			TEST_ASSERT(human_npc_gear_locked(thing) || human_npc_gear_consumable(thing), "A dead [kind]'s [thing] is not locked to the body")
			TEST_ASSERT(HAS_TRAIT(thing, TRAIT_NO_STRIP), "A dead [kind]'s [thing] can be stripped")
		// Revived and killed again: still nothing
		officer.revive(ADMIN_HEAL_ALL)
		officer.death()
		for(var/obj/item/stack/spacecash/money in spot)
			TEST_FAIL("A revived and killed [kind] dropped cash")

	// Gibbed: the kit goes with the body, whatever a limb tears off with it
	for(var/mob/living/carbon/human/npc/ambient_npc/outpost/police/officer as anything in officers)
		officer.gib()
	sleep(2 SECONDS) // locked gear off its body is deleted on the next tick (human_npc_gear.dm)
	for(var/obj/item/loose in view(3, spot))
		if(isbodypart(loose) || isorgan(loose) || isammocasing(loose) || (loose.item_flags & ABSTRACT))
			continue
		// A map fixture or the test room's own furniture is not ours to judge: only what an officer carries is locked or a police pair of cuffs
		if(human_npc_gear_locked(loose) || human_npc_gear_consumable(loose) || istype(loose, /obj/item/restraints/handcuffs/outpost_police))
			TEST_FAIL("A gibbed officer left [loose] lying about")
	qdel(outpost)

// =========================================================================
// COMBAT HOOKS
// =========================================================================

/// A police that writes down what its officers tell it, in place of the real reporting
/datum/outpost_police/police_units_recorder
	/// list(officer, attacker, attack_flags) per officer_struck() call
	var/list/struck = list()
	/// list(officer, user) per officer_cuff_attempt() call
	var/list/cuff_attempts = list()

/datum/outpost_police/police_units_recorder/officer_struck(mob/living/officer, atom/attacker, attack_flags)
	struck += list(list(officer, attacker, attack_flags))

/datum/outpost_police/police_units_recorder/officer_cuff_attempt(mob/living/officer, mob/living/user)
	cuff_attempts += list(list(officer, user))

/// A blow, a stamina hit or a shove on an officer reaches the police; so does a cuff attempt (abuse M3); the officer never ducks, flees or takes cover (abuse M17)
/datum/unit_test/voidcrew_outpost_police_units_hooks

/datum/unit_test/voidcrew_outpost_police_units_hooks/Run()
	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/officer = allocate(/mob/living/carbon/human/npc/ambient_npc/outpost/police/beat, run_loc_floor_bottom_left)
	var/datum/outpost_police/police_units_recorder/recorder = allocate(/datum/outpost_police/police_units_recorder)
	recorder.add_officer(officer)
	var/mob/living/carbon/human/attacker = allocate(/mob/living/carbon/human/consistent)

	// Hurt (ATTACKER_DAMAGING_ATTACK), stunned (ATTACKER_STAMINA_ATTACK) and shoved (ATTACKER_SHOVING) all count
	for(var/flags in list(ATTACKER_DAMAGING_ATTACK, ATTACKER_STAMINA_ATTACK, ATTACKER_SHOVING))
		recorder.struck.Cut()
		SEND_SIGNAL(officer, COMSIG_ATOM_WAS_ATTACKED, attacker, flags)
		TEST_ASSERT_EQUAL(length(recorder.struck), 1, "A hit with flags [flags] did not reach the police")
		var/list/blow = recorder.struck[1]
		TEST_ASSERT_EQUAL(blow[1], officer, "The police were told the wrong officer was struck")
		TEST_ASSERT_EQUAL(blow[2], attacker, "The police were told the wrong attacker")
		TEST_ASSERT_EQUAL(blow[3], flags, "The police were told the wrong kind of blow")
	// Something that is none of those is not a blow
	recorder.struck.Cut()
	SEND_SIGNAL(officer, COMSIG_ATOM_WAS_ATTACKED, attacker, 0)
	TEST_ASSERT_EQUAL(length(recorder.struck), 0, "A non-blow reached the police")

	// A cuff attempt reaches the police, unless it is their own
	SEND_SIGNAL(officer, COMSIG_CARBON_CUFF_ATTEMPTED, attacker)
	TEST_ASSERT_EQUAL(length(recorder.cuff_attempts), 1, "A cuff attempt did not reach the police")
	var/list/attempt = recorder.cuff_attempts[1]
	TEST_ASSERT_EQUAL(attempt[1], officer, "The police were told the wrong officer was cuffed")
	TEST_ASSERT_EQUAL(attempt[2], attacker, "The police were told the wrong person cuffed")
	SEND_SIGNAL(officer, COMSIG_CARBON_CUFF_ATTEMPTED, officer)
	TEST_ASSERT_EQUAL(length(recorder.cuff_attempts), 1, "An officer cuffing themselves counted as someone cuffing them")

	// The three bystander reactions do nothing at all: no duck, no flight, no cover, no line
	officer.react_attacked(attacker)
	officer.react_violence(attacker)
	officer.react_shootout(run_loc_floor_top_right)
	TEST_ASSERT_NULL(officer.activity, "An officer started [officer.activity?.type] when something happened near them")
	TEST_ASSERT(!officer.crouching, "An officer ducked")
	TEST_ASSERT_NULL(officer.reaction_cooldowns, "An officer reacted to something as a bystander would")

// =========================================================================
// COMBAT GEAR
// =========================================================================

/// get_baton(), get_cuffs(), get_sidearm() and get_longgun() find the right item; get_cuffs() is never the pair an officer is wearing or a pair already on someone
/datum/unit_test/voidcrew_outpost_police_units_gear

/datum/unit_test/voidcrew_outpost_police_units_gear/Run()
	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/beat/officer = allocate(/mob/living/carbon/human/npc/ambient_npc/outpost/police/beat, run_loc_floor_bottom_left)
	TEST_ASSERT(istype(officer.get_baton(), /obj/item/melee/baton), "A beat officer's baton is [officer.get_baton()]")
	var/obj/item/restraints/handcuffs/cuffs = officer.get_cuffs()
	TEST_ASSERT(istype(cuffs, /obj/item/restraints/handcuffs/outpost_police), "A beat officer's cuffs are [cuffs]")
	TEST_ASSERT(!istype(cuffs, /obj/item/restraints/handcuffs/outpost_police/used), "A beat officer's cuffs are a used pair")
	TEST_ASSERT(istype(officer.get_sidearm(), /obj/item/gun/energy), "A beat officer's sidearm is [officer.get_sidearm()]")
	TEST_ASSERT_NULL(officer.get_longgun(), "A beat officer has a long gun")

	// Cuffed by someone, the pair they wear is not theirs to cuff with
	var/obj/item/restraints/handcuffs/worn_pair = new(officer)
	officer.equip_to_slot(worn_pair, ITEM_SLOT_HANDCUFFED)
	TEST_ASSERT_EQUAL(officer.handcuffed, worn_pair, "Test fixture: the officer is not cuffed")
	TEST_ASSERT_EQUAL(officer.get_cuffs(), cuffs, "A cuffed officer's cuffs are the pair they wear")
	// ...nor is the police pair on their wrists, when it was police cuffs that went on
	officer.uncuff()
	qdel(worn_pair)
	officer.equip_to_slot(new /obj/item/restraints/handcuffs/outpost_police/used(officer), ITEM_SLOT_HANDCUFFED)
	TEST_ASSERT_EQUAL(officer.get_cuffs(), cuffs, "A cuffed officer's cuffs are the police pair they wear")

	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/tactical/heavy = allocate(/mob/living/carbon/human/npc/ambient_npc/outpost/police/tactical, run_loc_floor_bottom_left)
	TEST_ASSERT(istype(heavy.get_longgun(), /obj/item/gun/ballistic), "A tactical officer's long gun is [heavy.get_longgun()]")
	TEST_ASSERT(istype(heavy.get_sidearm(), /obj/item/gun/energy), "A tactical officer has no energy gun to arrest with")
	TEST_ASSERT(istype(heavy.get_cuffs(), /obj/item/restraints/handcuffs/outpost_police), "A tactical officer has no cuffs")

// =========================================================================
// CUFFS
// =========================================================================

/// Police cuffs always dispense a fresh /used pair, keep the officer's own, put nothing else on a cuffed person, and the pair on a wrist is gone the moment it comes off
/datum/unit_test/voidcrew_outpost_police_units_cuffs

/datum/unit_test/voidcrew_outpost_police_units_cuffs/Run()
	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/beat/officer = allocate(/mob/living/carbon/human/npc/ambient_npc/outpost/police/beat, run_loc_floor_bottom_left)
	var/mob/living/carbon/human/victim = allocate(/mob/living/carbon/human/consistent)
	var/obj/item/restraints/handcuffs/outpost_police/cuffs = officer.get_cuffs()
	TEST_ASSERT_NOTNULL(cuffs, "The officer has no cuffs")
	TEST_ASSERT_EQUAL(cuffs.trashtype, /obj/item/restraints/handcuffs/outpost_police/used, "The police cuffs do not turn into a used pair")

	// With the pair in the officer's hand, as when they cuff someone
	TEST_ASSERT(human_npc_take_in_hand(officer, cuffs), "Test fixture: the officer could not take their cuffs in hand")
	cuffs.apply_cuffs(victim, officer)
	var/obj/item/restraints/handcuffs/worn = victim.handcuffed
	TEST_ASSERT(istype(worn, /obj/item/restraints/handcuffs/outpost_police/used), "The suspect was cuffed with [worn], not a used pair")
	TEST_ASSERT(worn != cuffs, "The suspect was cuffed with the officer's own pair")
	TEST_ASSERT(worn.item_flags & DROPDEL, "The pair on the suspect does not vanish when it comes off")
	TEST_ASSERT(!QDELETED(cuffs) && officer.is_holding(cuffs), "The officer lost their own pair when they cuffed someone")
	TEST_ASSERT_EQUAL(officer.get_cuffs(), cuffs, "The officer's cuffs are not their own pair after cuffing")

	// Cuffing someone already cuffed puts nothing more on them
	cuffs.apply_cuffs(victim, officer)
	TEST_ASSERT_EQUAL(victim.handcuffed, worn, "A second pair of cuffs replaced the first")

	// Taken off, the pair is gone
	victim.uncuff()
	TEST_ASSERT_NULL(victim.handcuffed, "The suspect is still cuffed")
	TEST_ASSERT(QDELETED(worn), "A police pair taken off a wrist is still lying about")

	// A used pair cuffs nobody
	var/obj/item/restraints/handcuffs/outpost_police/used/spent = allocate(/obj/item/restraints/handcuffs/outpost_police/used)
	spent.apply_cuffs(victim, officer)
	TEST_ASSERT_NULL(victim.handcuffed, "A used pair cuffed someone")

// =========================================================================
// THE LEASH
// =========================================================================

/// An officer's leash is the whole outpost, the lobby, the concourse and a berth, and nothing past it
/datum/unit_test/voidcrew_outpost_police_units_leash

/datum/unit_test/voidcrew_outpost_police_units_leash/Run()
	var/obj/structure/overmap/trader_outpost/outpost = police_units_room_outpost(/obj/structure/overmap/trader_outpost/general)
	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/officer = allocate(/mob/living/carbon/human/npc/ambient_npc/outpost/police/beat, run_loc_floor_bottom_left)
	TEST_ASSERT_EQUAL(officer.police, outpost.police, "Test fixture: the officer does not keep this outpost")

	// On the outpost: the room
	TEST_ASSERT(officer.leash_ok(run_loc_floor_bottom_left), "An officer may not stand on their own outpost's floor")
	TEST_ASSERT(officer.leash_ok(run_loc_floor_top_right), "An officer may not stand at the far end of their outpost")
	TEST_ASSERT(!officer.leash_ok(null), "An officer may stand on no turf")

	// Off it: a tile outside the room's rectangle
	var/turf/outside = locate(run_loc_floor_bottom_left.x - 3, run_loc_floor_bottom_left.y - 3, run_loc_floor_bottom_left.z)
	if(outside && get_trader_outpost_for_turf(outside) != outpost)
		TEST_ASSERT(!officer.leash_ok(outside), "An officer may walk off their outpost")

	// A hangar berth is on the outpost: a reservation standing in for the berth's ground
	var/datum/turf_reservation/reservation = SSmapping.request_turf_block_reservation(3, 3, 1)
	TEST_ASSERT_NOTNULL(reservation, "Test fixture: no space for a berth's ground")
	var/datum/outpost_berth/berth = new(outpost, 1, null)
	berth.reservation = reservation
	outpost.berths[1] = berth
	var/turf/berth_tile = reservation.bottom_left_turfs[1]
	// A berth has a floor; a fresh reservation is open space, which no officer walks on
	berth_tile = berth_tile.ChangeTurf(/turf/open/floor/iron)
	TEST_ASSERT_EQUAL(get_trader_outpost_for_turf(berth_tile), outpost, "Test fixture: the berth's ground is not part of the outpost")
	TEST_ASSERT(officer.leash_ok(berth_tile), "An officer may not walk into a hangar berth")
	outpost.berths[1] = null
	berth.reservation = null
	qdel(reservation)

	// Carried off with nobody to see it: gone, quietly. (Nobody in the test world has a client, so nobody is watching.)
	officer.give_up_leash()
	TEST_ASSERT(QDELETED(officer), "An officer carried off their outpost, unseen, did not go")
	qdel(outpost)

/// Each map's checkpoint guard wears a police card for the booth door, locked to the body: not strippable, gone once out of it
/datum/unit_test/voidcrew_outpost_police_guard_card

/datum/unit_test/voidcrew_outpost_police_guard_card/Run()
	for(var/outpost_type in list(
		/obj/structure/overmap/trader_outpost/general,
		/obj/structure/overmap/trader_outpost/outfitter,
		/obj/structure/overmap/trader_outpost/black_market,
	))
		var/obj/structure/overmap/trader_outpost/outpost = police_loaded_outpost(outpost_type)
		if(!outpost)
			return
		var/mob/living/carbon/human/npc/ambient_npc/outpost/trader/checkpoint_guard/guard = locate() in outpost.traders
		TEST_ASSERT_NOTNULL(guard, "[outpost_type] has no checkpoint guard")
		var/obj/item/card/id/card = guard.wear_id
		TEST_ASSERT(istype(card) && ("outpost_police" in card.GetAccess()), "[outpost_type]'s guard has no card for the police doors") // ACCESS_OUTPOST_POLICE
		TEST_ASSERT(human_npc_gear_locked(card), "[outpost_type]'s guard's card is not locked to the body")
		TEST_ASSERT(HAS_TRAIT(card, TRAIT_NO_STRIP), "[outpost_type]'s guard's card can be stripped")
		guard.death()
		// Through the inventory, so the body lets go of it (a bare forceMove left wear_id on the card: a hard delete)
		guard.dropItemToGround(card, force = TRUE)
		TEST_ASSERT_NULL(guard.wear_id, "[outpost_type]'s dead guard still wears the card")
		sleep(2)
		TEST_ASSERT(QDELETED(card), "[outpost_type]'s dead guard's card survived being taken off the body")
		qdel(outpost)

// =========================================================================
// POCKETS AND HOLSTERING (owner bug 2)
// =========================================================================

/// Officers never carry or stow gear in a pocket, and locked NPC pocket items never show an untakeable strip-menu bulge
/datum/unit_test/voidcrew_outpost_police_units_pockets_and_holster

/datum/unit_test/voidcrew_outpost_police_units_pockets_and_holster/Run()
	var/obj/structure/overmap/trader_outpost/outpost = police_units_room_outpost(/obj/structure/overmap/trader_outpost/general)
	var/list/types = police_units_types()
	var/datum/strippable_item/mob_item_slot/pocket/left/left_slot = new
	var/datum/strippable_item/mob_item_slot/pocket/right/right_slot = new
	var/mob/living/carbon/human/player = allocate(/mob/living/carbon/human/consistent, run_loc_floor_bottom_left)
	for(var/kind in types)
		var/mob/living/carbon/human/npc/ambient_npc/outpost/police/officer = allocate(types[kind], run_loc_floor_bottom_left)
		var/label = "[kind] officer"
		TEST_ASSERT_NULL(officer.l_store, "[label] spawned with [officer.l_store] in left pocket")
		TEST_ASSERT_NULL(officer.r_store, "[label] spawned with [officer.r_store] in right pocket")
		TEST_ASSERT(locate(/obj/item/gun/energy/e_gun/mini) in officer.belt?.contents, "[label] does not carry their mini energy gun in their belt")
		TEST_ASSERT_EQUAL(left_slot.get_obscuring(officer), STRIPPABLE_OBSCURING_NONE, "[label] shows a left pocket bulge with empty pockets")
		TEST_ASSERT_EQUAL(right_slot.get_obscuring(officer), STRIPPABLE_OBSCURING_NONE, "[label] shows a right pocket bulge with empty pockets")

		// Draw and holster across every force level and explicit put-away: pockets must stay empty
		for(var/level in list(1, 2, 3, 0)) // POLICE_FORCE_ARREST, _STUN, _LETHAL, _NONE
			officer.set_force(level)
			TEST_ASSERT_NULL(officer.l_store, "[label] put [officer.l_store] in left pocket at force [level]")
			TEST_ASSERT_NULL(officer.r_store, "[label] put [officer.r_store] in right pocket at force [level]")
		for(var/obj/item/tool as anything in list(officer.get_cuffs(), officer.get_baton(), officer.get_sidearm()))
			if(!tool)
				continue
			if(human_npc_take_in_hand(officer, tool))
				TEST_ASSERT(officer.police_put_away(tool), "[label] could not put [tool] away without pockets")
			TEST_ASSERT_NULL(officer.l_store, "[label] stowed [officer.l_store] into left pocket")
			TEST_ASSERT_NULL(officer.r_store, "[label] stowed [officer.r_store] into right pocket")
		qdel(officer)

	// Even if locked NPC gear is placed in a pocket, players see no pocket bulge and cannot start pickpocketing it,
	// whereas ordinary unlocked items still behave like normal tg pocket items
	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/beat/tester = allocate(/mob/living/carbon/human/npc/ambient_npc/outpost/police/beat, run_loc_floor_bottom_left)
	var/obj/item/pen/locked_pen = allocate(/obj/item/pen)
	ADD_TRAIT(locked_pen, TRAIT_NO_STRIP, "outpost_police_test")
	tester.equip_to_slot_if_possible(locked_pen, ITEM_SLOT_LPOCKET, disable_warning = TRUE)
	TEST_ASSERT_EQUAL(tester.l_store, locked_pen, "Test fixture: locked pen was not placed in left pocket")
	TEST_ASSERT_EQUAL(left_slot.get_obscuring(tester), STRIPPABLE_OBSCURING_NONE, "A TRAIT_NO_STRIP item in left pocket still shows an untakeable bulge")
	TEST_ASSERT(!left_slot.start_unequip(tester, player), "A TRAIT_NO_STRIP item in left pocket started pickpocketing")
	tester.dropItemToGround(locked_pen, force = TRUE)

	var/obj/item/pen/normal_pen = allocate(/obj/item/pen)
	// Pockets hang off a jumpsuit
	player.equip_to_slot_if_possible(allocate(/obj/item/clothing/under/color/grey), ITEM_SLOT_ICLOTHING, disable_warning = TRUE)
	player.equip_to_slot_if_possible(normal_pen, ITEM_SLOT_LPOCKET, disable_warning = TRUE)
	TEST_ASSERT_EQUAL(player.l_store, normal_pen, "Test fixture: the ordinary pen was not placed in the left pocket")
	TEST_ASSERT_EQUAL(left_slot.get_obscuring(player), STRIPPABLE_OBSCURING_HIDDEN, "An ordinary unlocked pocket item no longer obscures the pocket")
	qdel(left_slot)
	qdel(right_slot)
	qdel(tester)
	qdel(outpost)

/// Dismembered officers stow and draw with their remaining hand instead of treating a missing arm as an empty hand or dropping evidence on the floor
/datum/unit_test/voidcrew_outpost_police_units_one_armed_hands

/datum/unit_test/voidcrew_outpost_police_units_one_armed_hands/Run()
	var/obj/structure/overmap/trader_outpost/outpost = police_units_room_outpost(/obj/structure/overmap/trader_outpost/general)
	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/officer/cop = allocate(/mob/living/carbon/human/npc/ambient_npc/outpost/police/officer, run_loc_floor_bottom_left)
	// Remove left arm (hand index 1, the default active hand) so only index 2 works
	qdel(cop.get_bodypart(BODY_ZONE_L_ARM))
	TEST_ASSERT_EQUAL(cop.usable_hands, 1, "Setup: dismembered officer does not have 1 usable hand")
	var/obj/item/melee/baton/baton = cop.get_baton()
	var/obj/item/gun/energy/sidearm = cop.get_sidearm()
	TEST_ASSERT(baton && sidearm, "Setup: officer is missing baton or sidearm")
	TEST_ASSERT(cop.police_draw(baton, null) && cop.is_holding(baton), "One-armed officer could not draw baton into their remaining hand")
	// With baton filling their only working hand, police_draw(sidearm, baton) must stow baton and draw sidearm
	TEST_ASSERT(cop.police_draw(sidearm, baton) && cop.is_holding(sidearm), "One-armed officer holding baton failed to stow it and draw sidearm")
	TEST_ASSERT(!cop.is_holding(baton) && (baton in cop.get_all_contents()), "Stowed baton left the one-armed officer's inventory")

	var/obj/item/outpost_sealed_case/evidence/case_box = allocate(/obj/item/outpost_sealed_case/evidence, run_loc_floor_bottom_left)
	TEST_ASSERT(cop.police_carry(case_box), "One-armed officer could not carry an evidence case")
	TEST_ASSERT(cop.is_holding(case_box) && !isturf(case_box.loc), "One-armed officer dropped the evidence case onto the floor instead of holding it")

	// Zero-armed tactical officer: police_free_hand is FALSE and police_carry stores in backpack without dropping on the floor
	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/tactical/armless = allocate(/mob/living/carbon/human/npc/ambient_npc/outpost/police/tactical, run_loc_floor_bottom_left)
	qdel(armless.get_bodypart(BODY_ZONE_L_ARM))
	qdel(armless.get_bodypart(BODY_ZONE_R_ARM))
	TEST_ASSERT(!armless.police_free_hand(), "Zero-armed officer reported a free hand")
	var/obj/item/outpost_sealed_case/evidence/bag_box = allocate(/obj/item/outpost_sealed_case/evidence, armless)
	TEST_ASSERT(armless.police_carry(bag_box), "Zero-armed tactical officer could not store evidence in their backpack")
	TEST_ASSERT_EQUAL(bag_box.loc, armless.back, "Zero-armed tactical officer did not put evidence into their backpack")
	qdel(cop)
	qdel(armless)
	qdel(outpost)
