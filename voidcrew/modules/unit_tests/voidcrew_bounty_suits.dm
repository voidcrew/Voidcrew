/**
 * Bounty hunting: suits and company (voidcrew/modules/bounties/bounty_suits.dm, the company parts of
 * bounty_companions.dm, the kits' vacuum gear in bounty_boss_kits.dm, the pad in bounty_turn_in.dm).
 *
 * Criminals and companions are real human NPCs: these tests read what they really wear, and drive tg's
 * own strip menu and inventory. Fork defines are included after the tests, so a test uses the literal
 * value with a comment naming the define. A site is stood in for by a spawn context naming its type, as
 * spawn_bounty_criminal() makes one from the overmap object; no ruin or planet is loaded.
 */

/// Holds the helpers the suit tests share
/datum/unit_test/voidcrew_bounty_suits
	abstract_type = /datum/unit_test/voidcrew_bounty_suits

/// A spawn context as one made for a site of `site_type` (an overmap typepath), without the site itself
/datum/unit_test/voidcrew_bounty_suits/proc/site_context(site_type)
	var/datum/npc_spawn_context/context = new(run_loc_floor_bottom_left, 1, "ordinary") // ZONE_GREEN
	context.source_type = site_type
	context.source_id = null
	return context

/**
 * A human criminal of `archetype` and `tier` (the mini-boss of `kit` for a boss), made on the test floor
 * as one wanted at a site of `site_type` (null: no site), its AI off
 */
/datum/unit_test/voidcrew_bounty_suits/proc/new_criminal(archetype = "normal", tier = 1, kit, site_type)
	var/datum/bounty_record/record = generate_bounty_record(tier, archetype, "planet", /datum/species/human) // BOUNTY_PLACEMENT_PLANET
	record.archetype = archetype
	if(kit)
		record.kit = kit
	var/datum/npc_spawn_context/context = site_type ? site_context(site_type) : null
	var/datum/human_npc_order/order = spawn_human_npc(bounty_criminal_type(record, null), run_loc_floor_bottom_left, look = record, name = record.name, context = context, immediate = TRUE)
	var/mob/living/carbon/human/npc/bounty_criminal/criminal = order?.spawned_ref?.resolve()
	qdel(order)
	if(QDELETED(criminal))
		return null
	criminal.body_setup(record, null)
	criminal.ai_controller?.set_ai_status(AI_STATUS_OFF)
	allocated += criminal
	return criminal

/// Whether `item` is in the armoured class: melee or bullet armour of 30 or more (an armour vest has 35 and 30)
/datum/unit_test/voidcrew_bounty_suits/proc/armoured(obj/item/item)
	return !isnull(item) && max(item.get_armor_rating(MELEE), item.get_armor_rating(BULLET)) >= 30

/// Whether a mini-boss kit's `item` is in the armoured class: armoured, or energy armour of 30 or more (the Heavy's ablative coat and hood, C8)
/datum/unit_test/voidcrew_bounty_suits/proc/kit_armoured(obj/item/item)
	return armoured(item) || (!isnull(item) && item.get_armor_rating(ENERGY) >= 30)

/// Checks `npc` is sealed up for vacuum in real, locked gear: a pressure suit and helmet that keep out the cold of space, and a tank it can breathe
/datum/unit_test/voidcrew_bounty_suits/proc/check_sealed(mob/living/carbon/human/npc/npc, label)
	var/obj/item/clothing/suit = npc.wear_suit
	var/obj/item/clothing/helmet = npc.head
	TEST_ASSERT(istype(suit) && (suit.clothing_flags & STOPSPRESSUREDAMAGE), "[label] wears no pressure suit ([suit?.type])")
	TEST_ASSERT(istype(helmet) && (helmet.clothing_flags & STOPSPRESSUREDAMAGE), "[label] wears no pressure helmet ([helmet?.type])")
	TEST_ASSERT(suit.min_cold_protection_temperature <= 2 && helmet.min_cold_protection_temperature <= 2, "[label]'s [suit] and [helmet] don't keep out the cold of space") // SPACE_SUIT_MIN_TEMP_PROTECT, SPACE_HELM_MIN_TEMP_PROTECT
	TEST_ASSERT(istype(npc.s_store, /obj/item/tank/internals), "[label] carries no tank in its suit")
	TEST_ASSERT(npc.can_breathe_internals(), "[label] has nothing to breathe its tank through")
	TEST_ASSERT(human_npc_gear_locked(suit) && human_npc_gear_locked(helmet), "[label]'s suit isn't locked to it")

/**
 * Checks `npc` wears a running MODsuit of `suit_type` on its back, every piece deployed and sealed, and
 * that none of it can become loot: the control unit, its pieces, core, cell and modules are locked to it
 * and hidden from the strip menu, and what its storage holds is locked or a consumable it can reach.
 */
/datum/unit_test/voidcrew_bounty_suits/proc/check_modsuit(mob/living/carbon/human/npc/npc, suit_type, label)
	var/obj/item/mod/control/suit = npc.back
	TEST_ASSERT(istype(suit, suit_type), "[label] wears [suit?.type] on its back, not its MODsuit [suit_type]")
	TEST_ASSERT(suit.active, "[label]'s MODsuit isn't running")
	TEST_ASSERT(suit.get_charge() > 0, "[label]'s MODsuit has no charge")
	TEST_ASSERT_EQUAL(suit.wearer, npc, "[label]'s MODsuit doesn't know its wearer")
	for(var/obj/item/part as anything in suit.get_parts())
		TEST_ASSERT_EQUAL(part.loc, npc, "[label]'s [part] isn't deployed")
		var/datum/mod_part/part_datum = suit.get_part_datum(part)
		TEST_ASSERT(part_datum?.sealed, "[label]'s [part] isn't sealed")
	TEST_ASSERT(istype(npc.wear_suit, /obj/item/clothing/suit/mod) && istype(npc.head, /obj/item/clothing/head/mod), "[label] isn't sealed in its MODsuit's chestplate and helmet")
	var/list/pieces = suit.get_parts(all = TRUE) + suit.modules + suit.core
	var/obj/item/mod/core/standard/core = suit.core
	TEST_ASSERT(istype(core) && istype(core.cell, /obj/item/stock_parts/power_store/cell), "[label]'s MODsuit has no cell in its core")
	pieces += core.cell
	for(var/obj/item/piece as anything in pieces)
		TEST_ASSERT(human_npc_gear_locked(piece), "[label]'s [piece] isn't locked to it")
		TEST_ASSERT(HAS_TRAIT(piece, TRAIT_NO_STRIP), "[label]'s [piece] shows in the strip menu")
	var/obj/item/mod/module/storage/pouch = locate() in suit.modules
	TEST_ASSERT_NOTNULL(pouch, "[label]'s MODsuit has no storage")
	for(var/obj/item/carried in pouch.contents)
		TEST_ASSERT(human_npc_gear_locked(carried) || human_npc_gear_consumable(carried), "[label]'s [carried] in its MODsuit isn't locked or issued to it")
		TEST_ASSERT(human_npc_can_draw(npc, carried), "[label] can't take its [carried] out of its MODsuit")

// ===== WHERE THEY ARE DRESSED FOR =====

/// At a space ruin a criminal and its companions arrive sealed up even on a tile with good air: a soft suit for a Petty one, an armoured one for a Wanted one
/datum/unit_test/voidcrew_bounty_suits/ruin

/datum/unit_test/voidcrew_bounty_suits/ruin/Run()
	TEST_ASSERT_EQUAL(human_npc_site_at(run_loc_floor_bottom_left), 0, "Test fixture: the test room's air counts as hostile")
	TEST_ASSERT_EQUAL(bounty_site_dress_for(site_context(/obj/structure/overmap/space_ruin)), 1, "A space ruin doesn't dress a criminal for vacuum") // HUMAN_NPC_SITE_VACUUM
	TEST_ASSERT_EQUAL(bounty_site_dress_for(site_context(/obj/structure/overmap/ship/npc/pirate)), 0, "A pirate ship dresses a criminal for vacuum")
	TEST_ASSERT_EQUAL(bounty_site_dress_for(null), 0, "No site dresses a criminal for vacuum")
	TEST_ASSERT_EQUAL(bounty_site_kind_of(site_context(/obj/structure/overmap/space_ruin)), "ruin", "A space ruin's context isn't a ruin's") // BOUNTY_PLACEMENT_RUIN
	TEST_ASSERT_EQUAL(bounty_site_kind_of(site_context(/obj/structure/overmap/ship/npc/pirate)), "npc_ship", "A pirate ship's context isn't a pirate ship's") // BOUNTY_PLACEMENT_NPC_SHIP

	var/mob/living/carbon/human/npc/bounty_criminal/petty = new_criminal("normal", 1, null, /obj/structure/overmap/space_ruin) // BOUNTY_TIER_PETTY
	TEST_ASSERT_NOTNULL(petty, "No Petty criminal was made")
	check_sealed(petty, "A Petty criminal at a space ruin")
	TEST_ASSERT(!armoured(petty.wear_suit), "A Petty criminal's soft suit is armoured ([petty.wear_suit.type])")
	TEST_ASSERT(petty.npc_site & 1, "A Petty criminal at a space ruin wasn't dressed for vacuum") // HUMAN_NPC_SITE_VACUUM

	var/mob/living/carbon/human/npc/bounty_criminal/wanted = new_criminal("normal", 2, null, /obj/structure/overmap/space_ruin) // BOUNTY_TIER_WANTED
	check_sealed(wanted, "A Wanted criminal at a space ruin")
	TEST_ASSERT(armoured(wanted.wear_suit) && armoured(wanted.head), "A Wanted criminal's space suit ([wanted.wear_suit.type]) is softer than the vest it wears in good air")

	// The same criminal in a room with good air and no site is in its clothes and vest
	var/mob/living/carbon/human/npc/bounty_criminal/at_home = new_criminal("normal", 2)
	TEST_ASSERT(istype(at_home.wear_suit, /obj/item/clothing/suit/armor/vest), "A Wanted criminal with good air and no site isn't in its vest ([at_home.wear_suit?.type])")
	TEST_ASSERT(!(at_home.npc_site & 1), "A criminal with good air and no site was dressed for vacuum") // HUMAN_NPC_SITE_VACUUM

	// Its companions are sealed up as their criminal is, in soft suits
	var/list/buddies = petty.spawn_companions(2, immediate = TRUE)
	TEST_ASSERT(length(buddies), "No companion spawned")
	for(var/mob/living/carbon/human/npc/bounty_companion/buddy as anything in buddies)
		allocated += buddy
		check_sealed(buddy, "A companion of a criminal at a space ruin")
		TEST_ASSERT(!armoured(buddy.wear_suit), "A companion's soft suit is armoured ([buddy.wear_suit.type])")
		TEST_ASSERT_EQUAL(buddy.company_site_kind, "ruin", "A companion doesn't know its criminal is at a ruin") // BOUNTY_PLACEMENT_RUIN

/**
 * Each mini-boss kit seals up in a running MODsuit of its own theme, of its own armour class: what protects
 * it in good air protects it in vacuum about as well. What its bag holds rides in the suit's storage, where
 * it reaches it, and none of the suit can be stripped or looted.
 */
/datum/unit_test/voidcrew_bounty_suits/kits

/datum/unit_test/voidcrew_bounty_suits/kits/Run()
	var/list/suit_types = list(
		"juggernaut" = /obj/item/mod/control/pre_equipped/bounty_boss/security,
		"pyromaniac" = /obj/item/mod/control/pre_equipped/bounty_boss/atmospheric,
		"demolitionist" = /obj/item/mod/control/pre_equipped/bounty_boss/engineering,
		"ghost" = /obj/item/mod/control/pre_equipped/bounty_boss/civilian,
		"heavy" = /obj/item/mod/control/pre_equipped/bounty_boss/magnate,
	)
	for(var/kit in suit_types) // BOUNTY_KIT_*
		var/mob/living/carbon/human/npc/bounty_criminal/boss/in_air = new_criminal("boss", 3, kit) // BOUNTY_TIER_MOST_WANTED
		var/mob/living/carbon/human/npc/bounty_criminal/boss/in_vacuum = new_criminal("boss", 3, kit, /obj/structure/overmap/space_ruin)
		TEST_ASSERT(istype(in_air) && istype(in_vacuum), "No [kit] was made")
		TEST_ASSERT_EQUAL(in_vacuum.boss_kit, kit, "Test fixture: the [kit] came out as a [in_vacuum.boss_kit]")
		check_sealed(in_vacuum, "The [kit] at a space ruin")
		TEST_ASSERT_EQUAL(kit_armoured(in_vacuum.wear_suit), kit_armoured(in_air.wear_suit), "The [kit]'s space suit ([in_vacuum.wear_suit.type]) isn't in the armour class of its own suit ([in_air.wear_suit?.type])")
		TEST_ASSERT_EQUAL(kit_armoured(in_vacuum.head), kit_armoured(in_air.head), "The [kit]'s space helmet ([in_vacuum.head.type]) isn't in the armour class of its own headgear ([in_air.head?.type])")
		TEST_ASSERT(in_vacuum.boss_gear_text(), "The [kit] in its MODsuit has no gear line on examine")
		var/list/gear = bounty_vacuum_gear(in_vacuum)
		TEST_ASSERT(length(gear) == 1 && gear[1] == suit_types[kit], "The [kit] was given [jointext(gear, ", ")] for vacuum")
		check_modsuit(in_vacuum, suit_types[kit], "The [kit] at a space ruin")
		// Everything its bag holds in good air, it carries in vacuum too
		var/obj/item/bag = in_air.back
		TEST_ASSERT(bag?.atom_storage, "Test fixture: the [kit] carries no bag in good air")
		for(var/obj/item/packed as anything in bag.get_all_contents_type(/obj/item))
			if(packed == bag)
				continue
			TEST_ASSERT(length(in_vacuum.get_all_contents_type(packed.type)) >= length(bag.get_all_contents_type(packed.type)), "The [kit] left its [packed] behind for vacuum")
		TEST_ASSERT_EQUAL(exact_count(in_vacuum, /obj/item/reagent_containers/hypospray/medipen/stimpack/traitor), 1, "The [kit] doesn't carry its combat stimpack in vacuum") // BOUNTY_BOSS_COMBAT_STIMULANT
		// Paused while it is dormant, so its core doesn't run flat before anyone comes, and running again when it wakes
		var/obj/item/mod/control/suit = in_vacuum.back
		in_vacuum.npc_set_suit_heating(FALSE)
		TEST_ASSERT(!(suit.datum_flags & DF_ISPROCESSING), "The [kit]'s MODsuit runs while it is dormant")
		in_vacuum.npc_set_suit_heating(TRUE)
		TEST_ASSERT(suit.datum_flags & DF_ISPROCESSING, "The [kit]'s MODsuit didn't start again when it woke")
		if(kit == "heavy")
			// Its ablative coat and hood hold no pressure, and nothing goes over a MODsuit: out there it has the magnate suit's energy armour (C8)
			TEST_ASSERT(istype(in_air.head, /obj/item/clothing/head/hooded/ablative), "The Heavy's ablative hood isn't up in good air")
			TEST_ASSERT(in_vacuum.wear_suit.get_armor_rating(ENERGY) >= in_air.wear_suit.get_armor_rating(ENERGY), "The Heavy's MODsuit has less energy armour than its coat")
		if(kit == "pyromaniac")
			// Its gas mask and ID stay on under the suit, and its spare tanks are where it changes them from
			var/mob/living/carbon/human/npc/bounty_criminal/boss/pyromaniac/pyro = in_vacuum
			TEST_ASSERT(istype(pyro.wear_mask, /obj/item/clothing/mask/gas), "The Pyromaniac took its gas mask off for its MODsuit")
			TEST_ASSERT(istype(pyro.wear_id, /obj/item/card/id), "The Pyromaniac has no ID in its MODsuit")
			TEST_ASSERT(pyro.wear_suit.resistance_flags & FIRE_PROOF, "The Pyromaniac's MODsuit isn't fireproof")
			TEST_ASSERT_NOTNULL(pyro.boss_spare_tank(), "The Pyromaniac can't reach a spare tank in its MODsuit")
		qdel(in_air)
		qdel(in_vacuum)

/// How many of exactly `item_type` (not its subtypes) `holder` carries
/datum/unit_test/voidcrew_bounty_suits/proc/exact_count(mob/living/holder, item_type)
	. = 0
	for(var/obj/item/thing as anything in holder.get_all_contents_type(item_type))
		if(thing.type == item_type)
			.++

/**
 * A mini-boss's MODsuit never becomes loot: a core, cell or module forced out of it (the only way one
 * leaves it on a body nobody can open) is gone by the next tick, and what spills from its storage is
 * gone too, a consumable once it is in anyone's hands. A hunter suiting up a cuffed boss takes the whole
 * MODsuit off with its helmet or chestplate, and it is gone, the gloves and boots it covered going back on.
 */
/datum/unit_test/voidcrew_bounty_suits/modsuit_loot

/datum/unit_test/voidcrew_bounty_suits/modsuit_loot/Run()
	var/mob/living/carbon/human/npc/bounty_criminal/boss/boss = new_criminal("boss", 3, "juggernaut", /obj/structure/overmap/space_ruin) // BOUNTY_TIER_MOST_WANTED, BOUNTY_KIT_JUGGERNAUT
	TEST_ASSERT_NOTNULL(boss, "No Juggernaut was made")
	var/obj/item/mod/control/suit = boss.back
	TEST_ASSERT(istype(suit), "Test fixture: the Juggernaut wears no MODsuit")
	var/turf/floor = get_turf(boss)
	var/obj/item/mod/core/standard/core = suit.core
	var/obj/item/cell = core.cell
	var/obj/item/mod/module/storage/pouch = locate() in suit.modules
	var/list/spilled = pouch.contents.Copy()
	for(var/obj/item/piece as anything in list(cell, core, pouch))
		piece.forceMove(floor)
		human_npc_gear_settle(piece)
		TEST_ASSERT(QDELETED(piece), "A [piece] taken out of the Juggernaut's MODsuit is still about")
	var/mob/living/carbon/human/consistent/hunter = allocate(/mob/living/carbon/human/consistent, get_step(floor, EAST))
	for(var/obj/item/thing as anything in spilled)
		if(QDELETED(thing))
			continue
		if(isturf(thing.loc) && human_npc_gear_consumable(thing))
			hunter.put_in_active_hand(thing)
		human_npc_gear_settle(thing)
		TEST_ASSERT(QDELETED(thing), "The [thing] from the Juggernaut's MODsuit storage became loot")
	qdel(boss)

	// Suiting up a cuffed boss: its MODsuit comes off whole and is gone
	boss = new_criminal("boss", 3, "juggernaut", /obj/structure/overmap/space_ruin)
	suit = boss.back
	var/list/parts = suit.get_parts(all = TRUE)
	var/obj/item/chestplate = boss.wear_suit
	TEST_ASSERT(chestplate in parts, "Test fixture: the Juggernaut's chestplate isn't its MODsuit's")
	var/obj/item/clothing/suit/space/hunter_suit = allocate(/obj/item/clothing/suit/space)
	hunter.put_in_active_hand(hunter_suit)
	TEST_ASSERT_EQUAL(boss.suits_garment_offered(hunter, chestplate), hunter_suit, "A space suit in hand wasn't offered for the MODsuit's chestplate")
	TEST_ASSERT(!boss.suits_swap_now(hunter, chestplate, hunter_suit), "A space suit went on a free boss")
	TEST_ASSERT_EQUAL(boss.back, suit, "A free boss lost its MODsuit")
	board_test_cuff(boss)
	TEST_ASSERT(boss.suits_swap_now(hunter, chestplate, hunter_suit), "A space suit wouldn't go on a cuffed boss in a MODsuit")
	TEST_ASSERT_EQUAL(boss.wear_suit, hunter_suit, "The hunter's suit isn't on the boss")
	for(var/obj/item/part as anything in parts)
		TEST_ASSERT(QDELETED(part), "The boss's [part] is still about after its MODsuit came off")
	TEST_ASSERT_NULL(boss.back, "The boss still wears [boss.back] on its back")
	TEST_ASSERT_NULL(boss.head, "The boss still wears [boss.head] after its MODsuit came off")
	TEST_ASSERT(istype(boss.gloves, /obj/item/clothing/gloves/combat) && human_npc_gear_locked(boss.gloves), "The Juggernaut's own gloves didn't go back on")
	TEST_ASSERT(istype(boss.shoes, /obj/item/clothing/shoes/jackboots) && human_npc_gear_locked(boss.shoes), "The Juggernaut's own boots didn't go back on")
	TEST_ASSERT(!human_npc_gear_locked(hunter_suit), "The hunter's suit was locked to the boss")

// ===== SUITING UP A CATCH =====

/**
 * A hunter can put their own space suit and helmet on a cuffed criminal in place of its own locked vest
 * and helmet, which are gone; it pulls away while free; the suit comes off again through tg's strip menu;
 * and the pad leaves the crew's things behind while the criminal's own go with it, as does the board when
 * it takes a criminal away.
 */
/datum/unit_test/voidcrew_bounty_suits/suit_up

/datum/unit_test/voidcrew_bounty_suits/suit_up/Run()
	var/mob/living/carbon/human/npc/bounty_criminal/criminal = new_criminal("normal", 3) // BOUNTY_TIER_MOST_WANTED: a vest and a helmet
	// Whatever else it rolled (anything that bares its torso), it wears a locked suit for this test to reach for
	if(!criminal.wear_suit && criminal.equip_to_slot_or_del(new /obj/item/clothing/suit/armor/vest(criminal), ITEM_SLOT_OCLOTHING))
		criminal.npc_lock_item(criminal.wear_suit)
	var/obj/item/jacket = criminal.wear_suit
	var/obj/item/hat = criminal.head
	TEST_ASSERT(human_npc_gear_locked(jacket) && human_npc_gear_locked(hat), "Test fixture: the criminal's vest and helmet aren't locked to it")
	var/mob/living/carbon/human/consistent/hunter = allocate(/mob/living/carbon/human/consistent, get_step(run_loc_floor_bottom_left, EAST))
	var/obj/item/clothing/suit/space/suit = allocate(/obj/item/clothing/suit/space)
	var/obj/item/clothing/head/helmet/space/helmet = allocate(/obj/item/clothing/head/helmet/space)
	var/obj/item/clothing/suit/jacket/leather/coat = allocate(/obj/item/clothing/suit/jacket/leather)

	// Not a pressure suit: the strip menu is tg's, which can't take the locked vest
	hunter.put_in_active_hand(coat)
	TEST_ASSERT_NULL(criminal.suits_garment_offered(hunter, jacket), "A leather jacket was taken for a pressure suit")
	TEST_ASSERT(!(SEND_SIGNAL(criminal, COMSIG_BEING_STRIPPED, hunter, jacket) & COMPONENT_CANT_STRIP), "The strip hook took over a reach with a leather jacket")
	qdel(coat)
	hunter.put_in_active_hand(suit)
	TEST_ASSERT_EQUAL(criminal.suits_garment_offered(hunter, jacket), suit, "A space suit in hand wasn't offered for the vest")

	// Free, it pulls away: the hook takes the reach, and nothing changes
	TEST_ASSERT_EQUAL(criminal.capture_state(), "free", "Test fixture: the criminal isn't free") // BOUNTY_STATE_FREE
	TEST_ASSERT(SEND_SIGNAL(criminal, COMSIG_BEING_STRIPPED, hunter, jacket) & COMPONENT_CANT_STRIP, "The strip hook left a reach for the locked vest to tg")
	TEST_ASSERT(!criminal.suits_swap_now(hunter, jacket, suit), "A space suit went on a free criminal")
	TEST_ASSERT_EQUAL(criminal.wear_suit, jacket, "A free criminal lost its vest")

	// Cuffed, the hunter's suit goes on in its place, and the vest is gone rather than loot
	board_test_cuff(criminal)
	TEST_ASSERT_EQUAL(criminal.capture_state(), "restrained", "Test fixture: the cuffed criminal isn't restrained") // BOUNTY_STATE_RESTRAINED
	TEST_ASSERT(criminal.suits_swap_now(hunter, jacket, suit), "A space suit wouldn't go on a cuffed criminal")
	TEST_ASSERT_EQUAL(criminal.wear_suit, suit, "The hunter's suit isn't on the criminal")
	TEST_ASSERT(QDELETED(jacket), "The criminal's own vest is still about")
	TEST_ASSERT(!human_npc_gear_locked(suit), "The hunter's suit was locked to the criminal")
	hunter.put_in_active_hand(helmet)
	TEST_ASSERT(criminal.suits_swap_now(hunter, hat, helmet), "A space helmet wouldn't go on a cuffed criminal")
	TEST_ASSERT_EQUAL(criminal.head, helmet, "The hunter's helmet isn't on the criminal")
	TEST_ASSERT(QDELETED(hat), "The criminal's own helmet is still about")

	// The hunter's suit is an ordinary item on it: tg's strip menu shows it and would take it off again
	var/datum/strippable_item/suit_slot = GLOB.strippable_human_items[STRIPPABLE_ITEM_SUIT]
	TEST_ASSERT_EQUAL(suit_slot.get_item(criminal), suit, "The strip menu doesn't see the hunter's suit")
	TEST_ASSERT(suit_slot.try_unequip(criminal, hunter), "The strip menu won't take the hunter's suit off again")

	// A tank in its suit storage, then the pad: the crew's things are left there, the criminal's own go with it
	var/obj/item/tank/internals/oxygen/tank = allocate(/obj/item/tank/internals/oxygen)
	TEST_ASSERT(criminal.equip_to_slot_if_possible(tank, ITEM_SLOT_SUITSTORE, disable_warning = TRUE), "Test fixture: a tank wouldn't go in the hunter's suit")
	var/obj/item/cuffs = criminal.handcuffed
	var/obj/item/own_uniform = criminal.w_uniform
	TEST_ASSERT(human_npc_gear_locked(own_uniform), "Test fixture: the criminal's clothes aren't locked to it")
	var/turf/pad_spot = get_turf(criminal)
	criminal.board_finish_beam_out()
	TEST_ASSERT(QDELETED(criminal), "The pad didn't take the criminal")
	for(var/obj/item/crew_item as anything in list(suit, helmet, tank, cuffs))
		TEST_ASSERT(!QDELETED(crew_item) && crew_item.loc == pad_spot, "The pad didn't leave the crew's [crew_item] behind")
	TEST_ASSERT(QDELETED(own_uniform), "The criminal's own clothes were left on the pad")

	// Taken away by the board instead (a relist, the clock running out): the crew's things are left there too
	criminal = new_criminal("normal", 1) // BOUNTY_TIER_PETTY
	if(!criminal.wear_suit && criminal.equip_to_slot_or_del(new /obj/item/clothing/suit/jacket/leather(criminal), ITEM_SLOT_OCLOTHING))
		criminal.npc_lock_item(criminal.wear_suit)
	TEST_ASSERT(human_npc_gear_locked(criminal.wear_suit), "Test fixture: the second criminal wears no locked suit")
	board_test_cuff(criminal)
	cuffs = criminal.handcuffed
	hunter.put_in_active_hand(suit)
	TEST_ASSERT(criminal.suits_swap_now(hunter, criminal.wear_suit, suit), "A space suit wouldn't go on a second cuffed criminal")
	var/datum/criminal_bounty/posting = allocate(/datum/criminal_bounty)
	posting.board_dispose_mob(criminal)
	TEST_ASSERT(QDELETED(criminal), "The board didn't take the criminal away")
	TEST_ASSERT(!QDELETED(suit) && suit.loc == pad_spot, "The board took the crew's suit away with the criminal")
	TEST_ASSERT(!QDELETED(cuffs) && cuffs.loc == pad_spot, "The board took the crew's cuffs away with the criminal")

// ===== COMPANY =====

/// Criminals hide only aboard plain pirate crews' ships, never a themed crew's
/datum/unit_test/voidcrew_bounty_suits/plain_pirates

/datum/unit_test/voidcrew_bounty_suits/plain_pirates/Run()
	var/obj/structure/overmap/ship/npc/pirate/pirate = allocate(/obj/structure/overmap/ship/npc/pirate)
	// Already resolved, so deleting the test hull doesn't make the pirate pool spawn a replacement
	pirate.spawner_resolved = TRUE
	TEST_ASSERT(bounty_ship_hides_criminals(pirate), "A plain pirate ship won't hide a criminal")
	pirate.pirate_faction = "skeleton"
	TEST_ASSERT(!bounty_ship_hides_criminals(pirate), "A skeleton crew's ship hides a criminal")
	pirate.pirate_faction = null
	TEST_ASSERT(!bounty_ship_hides_criminals(null), "Nothing hides a criminal")
	// Crews of ordinary people hide one; themed crews never do
	for(var/faction in list("grey", "interdyne"))
		pirate.pirate_faction = faction
		TEST_ASSERT(bounty_ship_hides_criminals(pirate), "A [faction] crew's ship won't hide a criminal")
	for(var/faction in list("silverscale", "skeleton", "lustrous", "irs", "medieval", "nt_patrol"))
		pirate.pirate_faction = faction
		TEST_ASSERT(!bounty_ship_hides_criminals(pirate), "A [faction] crew's ship hides a criminal")
	// The spawner's grey and Interdyne ships carry the factions the board looks for
	TEST_ASSERT_EQUAL(initial(/obj/structure/overmap/ship/npc/pirate/grey::pirate_faction), "grey", "The grey ship's crew changed name")
	TEST_ASSERT_EQUAL(initial(/obj/structure/overmap/ship/npc/pirate/interdyne::pirate_faction), "interdyne", "The Interdyne ship's crew changed name")

/// Companions are people of the criminals' species mix, in rough clothes picked by their criminal's site, and never carry what those clothes came with
/datum/unit_test/voidcrew_bounty_suits/company

/datum/unit_test/voidcrew_bounty_suits/company/Run()
	var/list/species_seen = list()
	for(var/i in 1 to 60)
		var/species = bounty_company_species()
		TEST_ASSERT(species in GLOB.bounty_species_weights, "A companion rolled [species], which no criminal can be")
		species_seen |= species
	TEST_ASSERT(length(species_seen) > 1, "Sixty companions were all [species_seen[1]]")

	var/mob/living/carbon/human/npc/bounty_criminal/leader = new_criminal("normal", 1)
	var/datum/criminal_bounty/posting = new
	posting.placement_kind = "planet" // BOUNTY_PLACEMENT_PLANET
	leader.posting_ref = WEAKREF(posting)
	for(var/site_kind in list("planet", "npc_ship")) // BOUNTY_PLACEMENT_PLANET, BOUNTY_PLACEMENT_NPC_SHIP
		posting.placement_kind = site_kind
		var/list/buddies = leader.spawn_companions(2, immediate = TRUE)
		TEST_ASSERT(length(buddies), "No companion spawned at a [site_kind]")
		for(var/mob/living/carbon/human/npc/bounty_companion/buddy as anything in buddies)
			TEST_ASSERT(buddy.dna.species.type in GLOB.bounty_species_weights, "A companion is a [buddy.dna.species.type], which no criminal can be")
			TEST_ASSERT(length(buddy.real_name) && buddy.real_name != initial(buddy.name), "A companion has no name of their own ([buddy.real_name])")
			TEST_ASSERT_EQUAL(buddy.company_site_kind, site_kind, "A companion doesn't know its criminal's site")
			TEST_ASSERT(buddy.company_clothes in bounty_company_clothes(site_kind), "A companion at a [site_kind] wears [buddy.company_clothes]")
			var/datum/outfit/clothes = buddy.company_clothes
			var/suit_type = initial(clothes.suit)
			if(suit_type)
				TEST_ASSERT(istype(buddy.wear_suit, suit_type), "A companion in [clothes]'s clothes wears [buddy.wear_suit?.type], not [suit_type]")
			TEST_ASSERT(!(locate(/obj/item/claymore/cutlass) in buddy.get_all_contents()), "A companion carries the off-duty pirate's cutlass")
			TEST_ASSERT(!(locate(/obj/item/flashlight/glowstick) in buddy.get_all_contents()), "A companion carries the hermit's glowstick")
			qdel(buddy)
	leader.posting_ref = null
	qdel(posting)
