/**
 * Outpost police tests: police_property.dm (voidcrew/modules/outpost_police/). Owner: P12.
 * Helpers are in voidcrew_outpost_police_helpers.dm. Fork defines are included after the tests: use
 * literal values with a comment naming the define.
 *
 * The fixture is a bare police datum (no outpost), four property lockers and an evidence locker on the unit
 * test room's floor, and people with minds. The search and strip waits are turned down to a tick.
 */

/datum/unit_test/voidcrew_outpost_police_property
	abstract_type = /datum/unit_test/voidcrew_outpost_police_property
	var/datum/outpost_police/police
	var/obj/structure/closet/secure_closet/outpost_evidence/evidence
	var/list/obj/structure/closet/secure_closet/personal/outpost_police/bank = list()
	/// Floor tiles not used by the bank or the evidence locker
	var/list/turf/spare = list()
	var/saved_scale

/datum/unit_test/voidcrew_outpost_police_property/Destroy()
	GLOB.outpost_police_property_time_scale = saved_scale
	bank = null
	spare = null
	return ..()

/// Police with `locker_count` lockers and an evidence locker; the waits cut to a tick
/datum/unit_test/voidcrew_outpost_police_property/proc/fixture(locker_count = 4)
	saved_scale = GLOB.outpost_police_property_time_scale
	GLOB.outpost_police_property_time_scale = 0.01
	var/list/floor = list()
	for(var/turf/tile as anything in block(run_loc_floor_bottom_left, run_loc_floor_top_right))
		if(isfloorturf(tile))
			floor += tile
	TEST_ASSERT(length(floor) >= locker_count + 6, "The test room has only [length(floor)] floor tiles")
	police = allocate(/datum/outpost_police)
	for(var/index in 1 to locker_count)
		var/obj/structure/closet/secure_closet/personal/outpost_police/locker = allocate(/obj/structure/closet/secure_closet/personal/outpost_police, floor[index])
		bank += locker
		police.lockers += locker
	evidence = allocate(/obj/structure/closet/secure_closet/outpost_evidence, floor[locker_count + 1])
	police.evidence_locker = evidence
	police.build_property(police.lockers, evidence)
	for(var/index in (locker_count + 2) to length(floor))
		spare += floor[index]

/// A person with a mind at the next spare tile
/datum/unit_test/voidcrew_outpost_police_property/proc/person()
	var/mob/living/carbon/human/someone = allocate(/mob/living/carbon/human/consistent, spare[1])
	spare.Cut(1, 2)
	someone.mind_initialize()
	allocated += someone.mind
	return someone

/// A person in grey, boots, a bag, a belt, an ID in the ID slot, a pen in a pocket and a crowbar in hand
/datum/unit_test/voidcrew_outpost_police_property/proc/outfitted()
	var/mob/living/carbon/human/someone = person()
	someone.equip_to_slot_if_possible(allocate(/obj/item/clothing/under/color/grey), ITEM_SLOT_ICLOTHING, disable_warning = TRUE)
	someone.equip_to_slot_if_possible(allocate(/obj/item/clothing/shoes/sneakers/black), ITEM_SLOT_FEET, disable_warning = TRUE)
	someone.equip_to_slot_if_possible(allocate(/obj/item/storage/backpack), ITEM_SLOT_BACK, disable_warning = TRUE)
	someone.equip_to_slot_if_possible(allocate(/obj/item/storage/belt/utility), ITEM_SLOT_BELT, disable_warning = TRUE)
	someone.equip_to_slot_if_possible(allocate(/obj/item/card/id), ITEM_SLOT_ID, disable_warning = TRUE)
	someone.equip_to_slot_if_possible(allocate(/obj/item/pen), ITEM_SLOT_LPOCKET, disable_warning = TRUE)
	someone.put_in_hands(allocate(/obj/item/crowbar))
	return someone

/// The officer, one tile from `target`
/datum/unit_test/voidcrew_outpost_police_property/proc/officer_beside(mob/living/target)
	var/mob/living/carbon/human/officer = allocate(/mob/living/carbon/human/consistent, get_step(target, EAST) || get_step(target, WEST))
	return officer

/// A fresh locker holds nothing when opened, and nobody can pull, weld, rename, claim or lock it
/datum/unit_test/voidcrew_outpost_police_property/locker_fresh

/datum/unit_test/voidcrew_outpost_police_property/locker_fresh/Run()
	fixture(1)
	var/obj/structure/closet/secure_closet/personal/outpost_police/locker = bank[1]
	TEST_ASSERT(locker.locked, "A new property locker is open to the world")
	TEST_ASSERT(locker.anchored, "A property locker can be dragged off")
	TEST_ASSERT(!locker.can_weld_shut, "A property locker can be welded shut")
	TEST_ASSERT(locker.resistance_flags & INDESTRUCTIBLE, "A property locker can be destroyed")
	TEST_ASSERT(isnull(locker.access_choices), "A property locker can be claimed with a card")
	locker.open(null, TRUE)
	TEST_ASSERT(!(locate(/obj/item) in get_turf(locker)), "A fresh property locker had starter contents")
	TEST_ASSERT(!length(locker.contents), "A fresh property locker still holds something")
	locker.close()
	locker.unlock()

	var/mob/living/carbon/human/user = person()
	TEST_ASSERT(!user.start_pulling(locker), "Someone pulled a property locker")
	var/obj/item/card/id/card = allocate(/obj/item/card/id)
	card.registered_name = "Claimant"
	user.put_in_hands(card)
	locker.tool_interact(card, user)
	TEST_ASSERT(isnull(locker.id_card), "A card claimed the property locker")
	TEST_ASSERT_EQUAL(locker.name, "property locker", "A card renamed the property locker")
	var/obj/item/pen/pen = allocate(/obj/item/pen)
	TEST_ASSERT(locker.tool_interact(pen, user), "A pen was not absorbed by the property locker")
	TEST_ASSERT_EQUAL(locker.name, "property locker", "A pen renamed the property locker")

	// A player unlocks, never locks
	locker.togglelock(user)
	TEST_ASSERT(!locker.locked, "A player locked a property locker")

/// The jail strip: jumpsuit and shoes, the ID back in its slot, everything else in the locker, nothing on the floor
/datum/unit_test/voidcrew_outpost_police_property/strip

/datum/unit_test/voidcrew_outpost_police_property/strip/Run()
	fixture(4)
	var/mob/living/carbon/human/prisoner = outfitted()
	var/mob/living/carbon/human/officer = officer_beside(prisoner)
	var/obj/item/card/id/card = prisoner.wear_id
	var/obj/item/storage/backpack/bag = prisoner.back
	var/obj/item/crowbar/crowbar = prisoner.get_active_held_item()
	var/obj/item/pen/pen = prisoner.l_store
	var/obj/item/clothing/under/old_suit = prisoner.w_uniform
	var/obj/item/clothing/shoes/old_shoes = prisoner.shoes
	var/obj/item/storage/belt/utility/belt = prisoner.belt
	var/obj/item/screwdriver/inside = allocate(/obj/item/screwdriver)
	bag.atom_storage.attempt_insert(inside, prisoner, TRUE)
	// tg's cuffs make them drop what they hold, where they are cuffed: the crowbar goes in a pocket first
	TEST_ASSERT(prisoner.equip_to_slot_if_possible(crowbar, ITEM_SLOT_RPOCKET, disable_warning = TRUE), "The fixture could not pocket the crowbar")
	var/obj/item/restraints/handcuffs/cuffs = allocate(/obj/item/restraints/handcuffs)
	cuffs.apply_cuffs(prisoner, officer, TRUE)
	TEST_ASSERT_NOTNULL(prisoner.handcuffed, "The fixture could not cuff the prisoner")
	TEST_ASSERT_NOTNULL(card, "The fixture prisoner has no ID")

	TEST_ASSERT(police.store_property(prisoner, officer), "store_property failed with free lockers")
	var/obj/structure/closet/secure_closet/personal/outpost_police/locker = police.property_locker_for(prisoner)
	TEST_ASSERT_NOTNULL(locker, "The prisoner has no locker")
	TEST_ASSERT(istype(prisoner.w_uniform, /obj/item/clothing/under/rank/prisoner/outpost_police), "The prisoner is not in the prison jumpsuit")
	TEST_ASSERT(istype(prisoner.shoes, /obj/item/clothing/shoes/sneakers/orange/outpost_police), "The prisoner is not in the prison shoes")
	TEST_ASSERT_EQUAL(prisoner.wear_id, card, "The ID is not back in the ID slot")
	TEST_ASSERT_NOTNULL(prisoner.handcuffed, "The strip took the cuffs")
	for(var/obj/item/kept as anything in list(bag, crowbar, pen, old_suit, old_shoes, belt))
		TEST_ASSERT_EQUAL(kept.loc, locker, "[kept] is not in the locker (it is in [kept.loc])")
		TEST_ASSERT(locker.holds(kept), "[kept] is not listed in the locker")
	TEST_ASSERT_EQUAL(inside.loc, bag, "A bagged item left its bag")
	TEST_ASSERT(locker.holds(inside), "Something inside a stored bag is not listed")
	for(var/obj/item/loose in get_turf(prisoner))
		TEST_FAIL("[loose] is lying on the cell floor after the strip")
	TEST_ASSERT(locker.locked, "The locker is open after the strip")
	TEST_ASSERT_EQUAL(locker.owner(), prisoner.mind, "The locker is not the prisoner's")
	TEST_ASSERT_EQUAL(locker.id_card?.resolve(), card, "The locker is not registered to the prisoner's card")
	// Booked again: the same locker, not a second one
	TEST_ASSERT_EQUAL(police.property_locker_for(prisoner), locker, "A second booking picked a different locker")

	// The issued clothes vanish when taken off (abuse M23)
	var/obj/item/issued = prisoner.w_uniform
	prisoner.dropItemToGround(issued)
	TEST_ASSERT(QDELETED(issued), "The issued jumpsuit survived being taken off")

/// What must stay on the prisoner stays: a stuck item, an implant, a ship key; a bag with a live mob is set down outside
/datum/unit_test/voidcrew_outpost_police_property/keeps

/datum/unit_test/voidcrew_outpost_police_property/keeps/Run()
	fixture(4)
	var/mob/living/carbon/human/prisoner = outfitted()
	var/mob/living/carbon/human/officer = officer_beside(prisoner)
	var/obj/item/clothing/glasses/sunglasses/stuck = allocate(/obj/item/clothing/glasses/sunglasses)
	prisoner.equip_to_slot_if_possible(stuck, ITEM_SLOT_EYES, disable_warning = TRUE)
	ADD_TRAIT(stuck, TRAIT_NODROP, TRAIT_GENERIC)
	var/obj/item/implant/mindshield/implant = allocate(/obj/item/implant/mindshield)
	implant.implant(prisoner, null, TRUE, TRUE)
	var/obj/item/ship_key/key = allocate(/obj/item/ship_key)
	prisoner.equip_to_slot_if_possible(key, ITEM_SLOT_RPOCKET, disable_warning = TRUE)
	var/obj/item/storage/box/carrier = allocate(/obj/item/storage/box)
	prisoner.put_in_hands(carrier)
	var/mob/living/basic/mouse/pet = allocate(/mob/living/basic/mouse)
	pet.forceMove(carrier)

	TEST_ASSERT(police.store_property(prisoner, officer), "store_property failed with free lockers")
	var/obj/structure/closet/secure_closet/personal/outpost_police/locker = police.property_locker_for(prisoner)
	TEST_ASSERT_EQUAL(prisoner.glasses, stuck, "A stuck item was taken")
	TEST_ASSERT(implant in prisoner.implants, "An implant was taken")
	TEST_ASSERT_EQUAL(key.loc, prisoner, "A ship key was taken")
	TEST_ASSERT(!locker.holds(key), "A ship key was listed in the locker")
	TEST_ASSERT(isturf(carrier.loc), "A bag holding a mob was not set down (it is in [carrier.loc])")
	TEST_ASSERT_EQUAL(pet.loc, carrier, "The mob in the bag was moved")
	TEST_ASSERT(!locker.holds(carrier), "A bag holding a mob went into the locker")

/// The owner opens it with no card, the registered card opens it in another hand, a stranger's card does not, an emag does and is reported, and the next booking resets the lock
/datum/unit_test/voidcrew_outpost_police_property/access

/datum/unit_test/voidcrew_outpost_police_property/access/Run()
	fixture(4)
	var/mob/living/carbon/human/owner = outfitted()
	var/mob/living/carbon/human/officer = officer_beside(owner)
	var/obj/item/card/id/card = owner.wear_id
	TEST_ASSERT(police.store_property(owner, officer), "store_property failed with free lockers")
	var/obj/structure/closet/secure_closet/personal/outpost_police/locker = police.property_locker_for(owner)

	// A stranger with another card
	var/mob/living/carbon/human/stranger = person()
	var/obj/item/card/id/other = allocate(/obj/item/card/id)
	other.registered_name = "Stranger"
	stranger.put_in_hands(other)
	locker.togglelock(stranger)
	TEST_ASSERT(locker.locked, "A stranger's card opened a property locker")

	// The registered card, in the stranger's hand
	stranger.dropItemToGround(other)
	owner.temporarilyRemoveItemFromInventory(card, TRUE)
	stranger.put_in_hands(card)
	locker.togglelock(stranger)
	TEST_ASSERT(!locker.locked, "The registered card did not open the locker in another hand")
	locker.lock()
	stranger.temporarilyRemoveItemFromInventory(card, TRUE)

	// The owner, with no card at all (it is destroyed): the lock does not go public
	qdel(card)
	locker.togglelock(stranger)
	TEST_ASSERT(locker.locked, "A deleted card made the locker public")
	locker.togglelock(owner)
	TEST_ASSERT(!locker.locked, "The owner could not open their locker without a card")
	locker.lock()

	// An emag opens it, and the break-in is on record for that person
	var/obj/item/card/emag/emag = allocate(/obj/item/card/emag)
	locker.emag_act(stranger, emag)
	TEST_ASSERT(locker.broken && !locker.locked, "An emag did not open the locker")
	TEST_ASSERT(LAZYACCESS(locker.thieves, WEAKREF(stranger.mind)), "The break-in was not put on record")

	// A broken free locker is reset at the next booking
	var/obj/structure/closet/secure_closet/personal/outpost_police/spare_locker = bank[2]
	spare_locker.emag_act(stranger, emag)
	TEST_ASSERT(spare_locker.broken, "The spare locker did not break")
	var/mob/living/carbon/human/next = outfitted()
	TEST_ASSERT(police.store_property(next, officer_beside(next)), "The next booking failed")
	TEST_ASSERT_EQUAL(police.property_locker_for(next), spare_locker, "The next booking did not take the broken locker")
	TEST_ASSERT(!spare_locker.broken && spare_locker.locked, "The broken lock was not reset at the booking")

/// Taking a stored item: the owner frees the locker, a stranger is put on record, and an arrested thief's loot goes back, not into the evidence locker
/datum/unit_test/voidcrew_outpost_police_property/pickup

/datum/unit_test/voidcrew_outpost_police_property/pickup/Run()
	fixture(4)
	var/mob/living/carbon/human/owner = outfitted()
	var/mob/living/carbon/human/officer = officer_beside(owner)
	var/obj/item/crowbar/prize = owner.get_active_held_item()
	TEST_ASSERT(police.store_property(owner, officer), "store_property failed with free lockers")
	var/obj/structure/closet/secure_closet/personal/outpost_police/locker = police.property_locker_for(owner)

	// A thief takes the crowbar from the opened locker
	var/mob/living/carbon/human/thief = person()
	locker.open(null, TRUE)
	thief.put_in_hands(prize)
	TEST_ASSERT(LAZYACCESS(locker.thieves, WEAKREF(thief.mind)), "Taking another prisoner's gear was not put on record")
	TEST_ASSERT(locker.holds(prize), "A stolen item stopped being listed")
	// Abuse SF1: planted on someone else, it is still the thief's theft, not theirs
	var/mob/living/carbon/human/framed = person()
	thief.dropItemToGround(prize)
	framed.put_in_hands(prize)
	TEST_ASSERT_EQUAL(prize.loc, framed, "Setup: the stolen item did not reach the second person")
	TEST_ASSERT(!LAZYACCESS(locker.thieves, WEAKREF(framed.mind)), "Someone the stolen goods were planted on was put on record")
	framed.dropItemToGround(prize)
	thief.put_in_hands(prize)

	// Arrested: the loot is taken, and the thief's own crime tool with it
	var/obj/item/lighter/own_tool = allocate(/obj/item/lighter)
	thief.put_in_hands(own_tool)
	var/datum/outpost_warrant/warrant = police.warrants[thief.mind]
	if(!warrant)
		warrant = new
		warrant.mind = thief.mind
		police.warrants[thief.mind] = warrant
	warrant.evidence = list(WEAKREF(own_tool))
	var/mob/living/carbon/human/cop = officer_beside(thief)
	var/obj/item/outpost_sealed_case/evidence/case = police.confiscate(thief, cop)
	TEST_ASSERT_NOTNULL(case, "confiscate took nothing from a thief carrying stolen goods and a crime tool")
	TEST_ASSERT(prize in case.contents, "The stolen item was not taken")
	TEST_ASSERT(own_tool in case.contents, "The crime tool was not taken")
	police.dispose_evidence(cop)
	TEST_ASSERT(!QDELETED(prize), "Stolen property was deleted")
	TEST_ASSERT_EQUAL(prize.loc, locker, "Stolen property did not go back to its locker")
	TEST_ASSERT(locker.locked, "The lock was not reset after the goods came back")
	TEST_ASSERT_EQUAL(own_tool.loc, evidence, "The crime tool did not go in the evidence locker")
	TEST_ASSERT(QDELETED(case), "The case survived being emptied")

	// The owner collecting their things frees the locker once nothing of theirs is left
	locker.open(null, TRUE)
	owner.put_in_hands(prize)
	TEST_ASSERT(!locker.holds(prize), "The owner's own pickup left the item listed")
	locker.check_freed()
	TEST_ASSERT_NOTNULL(locker.owner(), "A locker with goods left in it was freed")
	for(var/obj/item/leftover as anything in locker.live_items())
		qdel(leftover)
	locker.check_freed()
	TEST_ASSERT(!locker.owner(), "A collected locker stayed the prisoner's")
	TEST_ASSERT(locker.is_free(), "A collected locker did not shut and lock again")
	TEST_ASSERT(locker.locked, "A collected locker was left unlocked")

/**
 * The Search step takes a recorded gun from a backpack and leaves an unrecorded one; at the evidence locker the gun
 * goes inside and the case is gone. The locker stays locked to anyone without a police ID, opens to one, and an emag
 * breaks it open (owner decision 30).
 */
/datum/unit_test/voidcrew_outpost_police_property/evidence_locker

/datum/unit_test/voidcrew_outpost_police_property/evidence_locker/Run()
	fixture(4)
	var/mob/living/carbon/human/suspect = outfitted()
	var/mob/living/carbon/human/cop = officer_beside(suspect)
	var/obj/item/storage/backpack/bag = suspect.back
	var/obj/item/gun/ballistic/automatic/pistol/recorded = allocate(/obj/item/gun/ballistic/automatic/pistol)
	var/obj/item/gun/ballistic/automatic/pistol/unrecorded = allocate(/obj/item/gun/ballistic/automatic/pistol)
	bag.atom_storage.attempt_insert(recorded, suspect, TRUE)
	bag.atom_storage.attempt_insert(unrecorded, suspect, TRUE)
	var/obj/item/ship_key/key = allocate(/obj/item/ship_key)
	bag.atom_storage.attempt_insert(key, suspect, TRUE)
	var/datum/outpost_warrant/warrant = new
	warrant.mind = suspect.mind
	warrant.evidence = list(WEAKREF(recorded))
	police.warrants[suspect.mind] = warrant

	var/obj/item/outpost_sealed_case/evidence/case = police.confiscate(suspect, cop)
	TEST_ASSERT_NOTNULL(case, "confiscate took nothing")
	TEST_ASSERT(recorded in case.contents, "The recorded gun was not taken from the backpack")
	TEST_ASSERT_EQUAL(unrecorded.loc, bag, "An unrecorded gun was taken")
	TEST_ASSERT(cop.is_holding(case), "The evidence case is not in the officer's hand")
	TEST_ASSERT(!(key in case.contents), "A ship key went into the case")

	// Into the locker, standing open or not: the gun inside, nothing on the floor, the case gone
	evidence.open(null, TRUE)
	police.dispose_evidence(cop)
	TEST_ASSERT_EQUAL(recorded.loc, evidence, "The recorded gun is in [recorded.loc], not the evidence locker")
	TEST_ASSERT(!evidence.opened, "The evidence locker was left open")
	TEST_ASSERT(QDELETED(case), "The case survived being emptied")
	TEST_ASSERT(!(locate(/obj/item/gun) in get_turf(cop)), "A gun was left on the floor")
	TEST_ASSERT(!QDELETED(unrecorded) && !QDELETED(key), "More than the evidence was taken")

	// A visitor's card does nothing; a police card opens it; an emag breaks it open
	evidence.locked = TRUE
	evidence.update_appearance()
	var/obj/item/card/id/advanced/visitor_card = allocate(/obj/item/card/id/advanced)
	TEST_ASSERT(!evidence.check_access(visitor_card), "A card with no police access opens the evidence locker")
	var/obj/item/card/id/advanced/police_card = allocate(/obj/item/card/id/advanced)
	police_card.access = list("outpost_police") // ACCESS_OUTPOST_POLICE
	TEST_ASSERT(evidence.check_access(police_card), "A police card does not open the evidence locker")
	TEST_ASSERT(evidence.emag_act(suspect, allocate(/obj/item/card/emag)), "An emag did nothing to the evidence locker")
	TEST_ASSERT(!evidence.locked, "An emag left the evidence locker locked")

	// A case deleted any other way never spills (abuse M24): what it held goes to the evidence locker (review S1)
	var/obj/item/outpost_sealed_case/evidence/loose = new(get_turf(cop))
	loose.police_ref = WEAKREF(police)
	var/obj/item/screwdriver/tool = allocate(/obj/item/screwdriver)
	tool.forceMove(loose)
	qdel(loose)
	TEST_ASSERT(!QDELETED(tool), "A deleted evidence case destroyed the tool in it")
	TEST_ASSERT_EQUAL(tool.loc, evidence, "A deleted evidence case put its tool in [tool.loc], not the evidence locker")
	TEST_ASSERT(!(locate(/obj/item/screwdriver) in get_turf(cop)), "A deleted evidence case left an item on the floor")

/// With every locker held by someone still in the cells nobody else is stripped; once one is let out, the longest-released locker is emptied onto the floor and reused
/datum/unit_test/voidcrew_outpost_police_property/full

/datum/unit_test/voidcrew_outpost_police_property/full/Run()
	fixture(4)
	var/datum/outpost_police_cell/cell = new
	police.cells += cell
	var/list/inmates = list()
	for(var/index in 1 to 4)
		var/mob/living/carbon/human/inmate = outfitted()
		cell.prisoners[inmate.mind] = world.time + 10 MINUTES
		TEST_ASSERT(police.store_property(inmate, officer_beside(inmate)), "Prisoner [index] could not be stripped")
		inmates += inmate

	var/mob/living/carbon/human/fifth = outfitted()
	var/obj/item/clothing/under/own_suit = fifth.w_uniform
	TEST_ASSERT(!police.store_property(fifth, officer_beside(fifth)), "A fifth prisoner was stripped with every locker taken")
	TEST_ASSERT_EQUAL(fifth.w_uniform, own_suit, "A prisoner with no locker free lost their clothes")

	// The first inmate walks free long ago; their locker is the one reused
	var/mob/living/carbon/human/first = inmates[1]
	var/obj/structure/closet/secure_closet/personal/outpost_police/first_locker = police.property_locker_for(first)
	var/obj/item/crowbar/first_crowbar = locate() in first_locker.contents
	cell.prisoners -= first.mind
	first_locker.released_at = world.time - 5 MINUTES
	TEST_ASSERT(police.store_property(fifth, officer_beside(fifth)), "A fifth prisoner was not stripped once a locker was left behind")
	TEST_ASSERT_EQUAL(police.property_locker_for(fifth), first_locker, "The fifth prisoner did not get the longest-released locker")
	TEST_ASSERT(!first_crowbar || !QDELETED(first_crowbar), "The evicted prisoner's gear was deleted")
	TEST_ASSERT(!first_crowbar || !(first_crowbar in first_locker.contents), "The evicted gear is still in the reused locker")

/// Review S1 and abuse SF5: an officer deleted with evidence on him, in his hand or his belt, sends it to the evidence locker
/datum/unit_test/voidcrew_outpost_police_property/evidence_on_officer

/datum/unit_test/voidcrew_outpost_police_property/evidence_on_officer/Run()
	fixture(1)
	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/officer = allocate(/mob/living/carbon/human/npc/ambient_npc/outpost/police/beat, spare[1])
	TEST_ASSERT_NOTNULL(officer.belt, "Test fixture: the officer has no belt")
	var/obj/item/gun/ballistic/automatic/pistol/in_hand = allocate(/obj/item/gun/ballistic/automatic/pistol)
	var/obj/item/gun/ballistic/automatic/pistol/in_belt = allocate(/obj/item/gun/ballistic/automatic/pistol)
	var/obj/item/outpost_sealed_case/evidence/held_case = new(get_turf(officer))
	held_case.police_ref = WEAKREF(police)
	TEST_ASSERT(held_case.add_evidence(in_hand, null), "Test fixture: the first gun did not go in its case")
	TEST_ASSERT(officer.put_in_hands(held_case), "Test fixture: the officer could not hold the case")
	var/obj/item/outpost_sealed_case/evidence/belt_case = new(get_turf(officer))
	belt_case.police_ref = WEAKREF(police)
	TEST_ASSERT(belt_case.add_evidence(in_belt, null), "Test fixture: the second gun did not go in its case")
	belt_case.forceMove(officer.belt)
	var/turf/floor = get_turf(officer)

	qdel(officer)
	for(var/obj/item/gun/gun as anything in list(in_hand, in_belt))
		TEST_ASSERT(!QDELETED(gun), "Evidence was deleted with the officer carrying it")
		TEST_ASSERT_EQUAL(gun.loc, evidence, "Evidence on a deleted officer went to [gun.loc], not the evidence locker")
	TEST_ASSERT(!(locate(/obj/item/gun) in floor), "Evidence on a deleted officer was left on the floor")

/// Review S2: a locker that cannot shut (an emagged door held open by a crate, a person in the doorway) still takes the evidence, never deletes it, and never locks anyone in
/datum/unit_test/voidcrew_outpost_police_property/evidence_blocked

/datum/unit_test/voidcrew_outpost_police_property/evidence_blocked/Run()
	fixture(1)
	var/mob/living/carbon/human/cop = person()
	TEST_ASSERT(evidence.emag_act(cop, allocate(/obj/item/card/emag)), "Test fixture: the emag did nothing")
	TEST_ASSERT(evidence.open(null, TRUE), "Test fixture: the broken locker would not open")
	var/obj/structure/closet/crate/crate = allocate(/obj/structure/closet/crate, get_turf(evidence))
	TEST_ASSERT(!evidence.can_close(), "Test fixture: the crate does not hold the door open")

	var/obj/item/outpost_sealed_case/evidence/case = new(get_turf(cop))
	case.police_ref = WEAKREF(police)
	var/obj/item/gun/ballistic/automatic/pistol/gun = allocate(/obj/item/gun/ballistic/automatic/pistol)
	case.add_evidence(gun, null)
	TEST_ASSERT(cop.put_in_hands(case), "Test fixture: the officer could not hold the case")
	police.dispose_evidence(cop)
	TEST_ASSERT(!QDELETED(gun), "A blocked evidence locker had the evidence deleted")
	TEST_ASSERT_EQUAL(gun.loc, evidence, "Evidence for a blocked locker went to [gun.loc]")

	// Someone in the doorway: the door is not shut on them, and they are not locked in
	qdel(crate)
	var/mob/living/carbon/human/bystander = person()
	bystander.forceMove(get_turf(evidence))
	var/obj/item/screwdriver/tool = allocate(/obj/item/screwdriver)
	TEST_ASSERT(evidence.take_evidence(tool), "The evidence locker refused a tool with someone in the doorway")
	TEST_ASSERT_EQUAL(tool.loc, evidence, "The tool is not in the evidence locker")
	TEST_ASSERT(isturf(bystander.loc), "The evidence locker shut someone in")

	// The lock mends: shut and locked once the doorway is clear, never with someone in it
	evidence.mend_lock()
	TEST_ASSERT(!evidence.broken, "The emagged lock did not mend")
	TEST_ASSERT(evidence.opened, "The evidence locker shut with someone in the doorway")
	TEST_ASSERT(isturf(bystander.loc), "The mending lock shut someone in")
	bystander.forceMove(spare[1])
	evidence.shut_when_clear()
	TEST_ASSERT(!evidence.opened, "The mended evidence locker did not shut once its doorway was clear")
	TEST_ASSERT(evidence.locked, "The mended evidence locker did not lock")
	TEST_ASSERT_EQUAL(gun.loc, evidence, "The evidence left the locker while it mended")

/// Review S3: a ship key or mission item in a bag is not locked away with the bag; it stays on the prisoner
/datum/unit_test/voidcrew_outpost_police_property/strip_keepsakes

/datum/unit_test/voidcrew_outpost_police_property/strip_keepsakes/Run()
	fixture(4)
	var/mob/living/carbon/human/prisoner = outfitted()
	var/mob/living/carbon/human/officer = officer_beside(prisoner)
	var/obj/item/storage/backpack/bag = prisoner.back
	var/obj/item/ship_key/key = allocate(/obj/item/ship_key)
	var/obj/item/screwdriver/tool = allocate(/obj/item/screwdriver)
	bag.atom_storage.attempt_insert(key, prisoner, TRUE)
	bag.atom_storage.attempt_insert(tool, prisoner, TRUE)
	TEST_ASSERT_EQUAL(key.loc, bag, "Test fixture: the key is not in the bag")

	TEST_ASSERT(police.store_property(prisoner, officer), "store_property failed with free lockers")
	var/obj/structure/closet/secure_closet/personal/outpost_police/locker = police.property_locker_for(prisoner)
	TEST_ASSERT_EQUAL(bag.loc, locker, "The bag did not go in the locker")
	TEST_ASSERT_EQUAL(tool.loc, bag, "The rest of the bag did not go with it")
	TEST_ASSERT_EQUAL(get_atom_on_turf(key), prisoner, "A ship key in a bag was locked away (it is in [key.loc])")
	TEST_ASSERT(prisoner.is_holding(key) || prisoner.l_store == key || prisoner.r_store == key, "The ship key is on the prisoner but not in a pocket or hand")
	TEST_ASSERT(!locker.holds(key), "A ship key is listed in the locker")

/// Owner bug 1: searching a suspect downed in soft or hard crit takes pending-report weapons and dropped stolen locker loot
/datum/unit_test/voidcrew_outpost_police_property/confiscate_crit

/datum/unit_test/voidcrew_outpost_police_property/confiscate_crit/Run()
	fixture(4)
	var/mob/living/carbon/human/victim = outfitted()
	var/obj/item/crowbar/stolen_crowbar = victim.get_active_held_item()
	TEST_ASSERT(police.store_property(victim, officer_beside(victim)), "Setup: victim could not be stripped")
	var/obj/structure/closet/secure_closet/personal/outpost_police/victim_locker = police.property_locker_for(victim)

	var/mob/living/carbon/human/suspect = outfitted()
	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/cop = allocate(/mob/living/carbon/human/npc/ambient_npc/outpost/police/beat, get_step(suspect, EAST) || get_step(suspect, WEST))
	victim_locker.open(null, TRUE)
	suspect.put_in_hands(stolen_crowbar)
	// Going into crit drops held items onto the floor
	suspect.dropItemToGround(stolen_crowbar)

	var/obj/item/gun/ballistic/automatic/pistol/dropped_gun = allocate(/obj/item/gun/ballistic/automatic/pistol, get_turf(suspect))
	var/obj/item/screwdriver/bag_knife = allocate(/obj/item/screwdriver)
	var/obj/item/storage/backpack/bag = suspect.back
	bag.atom_storage.attempt_insert(bag_knife, suspect, TRUE)

	// Witnessed by `cop` in a pending report before the radio call finishes
	var/datum/outpost_pending_report/pending = new
	pending.crime = "assault" // OUTPOST_CRIME_ASSAULT
	pending.offender = WEAKREF(suspect)
	pending.source = WEAKREF(dropped_gun)
	pending.folded_sources = list(WEAKREF(bag_knife))
	pending.witnesses = list(WEAKREF(cop))
	pending.due = world.time + 300
	pending.expires = world.time + 600
	police.pending_reports += pending

	ADD_TRAIT(suspect, TRAIT_CRITICAL_CONDITION, "outpost_police_test")
	suspect.set_stat(SOFT_CRIT)
	var/obj/item/outpost_sealed_case/evidence/case = police.confiscate(suspect, cop)
	TEST_ASSERT_NOTNULL(case, "confiscate failed on a suspect downed in soft crit")
	TEST_ASSERT(dropped_gun in case.contents, "Dropped weapon from a pending witness report was not confiscated in crit")
	TEST_ASSERT(bag_knife in case.contents, "Backpack weapon from a folded pending report was not confiscated in crit")
	TEST_ASSERT(stolen_crowbar in case.contents, "Stolen locker gear dropped when entering crit was not confiscated")

	police.dispose_evidence(cop)
	TEST_ASSERT_EQUAL(stolen_crowbar.loc, victim_locker, "Recovered stolen locker gear did not return to the victim's locker")
	TEST_ASSERT_EQUAL(dropped_gun.loc, evidence, "Confiscated gun from crit suspect did not reach the evidence locker")
	TEST_ASSERT_EQUAL(bag_knife.loc, evidence, "Confiscated knife from crit suspect did not reach the evidence locker")
	police.pending_reports -= pending
	qdel(pending)

	// Hard crit / unconscious pat-down also works
	var/mob/living/carbon/human/hard_crit = outfitted()
	var/mob/living/carbon/human/hard_cop = officer_beside(hard_crit)
	var/obj/item/gun/ballistic/automatic/pistol/hard_gun = allocate(/obj/item/gun/ballistic/automatic/pistol, get_turf(hard_crit))
	var/datum/outpost_warrant/warrant = new
	warrant.mind = hard_crit.mind
	warrant.evidence = list(WEAKREF(hard_gun))
	police.warrants[hard_crit.mind] = warrant
	ADD_TRAIT(hard_crit, TRAIT_CRITICAL_CONDITION, "outpost_police_test")
	hard_crit.set_stat(UNCONSCIOUS)
	var/obj/item/outpost_sealed_case/evidence/hard_case = police.confiscate(hard_crit, hard_cop)
	TEST_ASSERT_NOTNULL(hard_case, "confiscate failed on an unconscious suspect in hard crit")
	TEST_ASSERT(hard_gun in hard_case.contents, "Hard-crit pat-down did not take the recorded weapon")

/// Nested items in a stolen bag do not frame a bystander; unanchored crates do not jam open lockers; active MODsuits and extra cuffs strip cleanly
/datum/unit_test/voidcrew_outpost_police_property/nested_framing_and_modsuit

/datum/unit_test/voidcrew_outpost_police_property/nested_framing_and_modsuit/Run()
	fixture(4)
	var/mob/living/carbon/human/owner = outfitted()
	var/obj/item/storage/backpack/bag = owner.back
	var/obj/item/screwdriver/nested_tool = allocate(/obj/item/screwdriver)
	bag.atom_storage.attempt_insert(nested_tool, owner, TRUE)
	TEST_ASSERT(police.store_property(owner, officer_beside(owner)), "Setup: owner could not be stripped")
	var/obj/structure/closet/secure_closet/personal/outpost_police/locker = police.property_locker_for(owner)

	var/mob/living/carbon/human/thief = person()
	var/mob/living/carbon/human/bystander = person()
	locker.open(null, TRUE)
	thief.put_in_hands(bag)
	TEST_ASSERT(LAZYACCESS(locker.thieves, WEAKREF(thief.mind)), "Thief taking the bag was not recorded")
	thief.dropItemToGround(bag)
	bystander.put_in_hands(bag)
	bystander.put_in_hands(nested_tool)
	TEST_ASSERT(!LAZYACCESS(locker.thieves, WEAKREF(bystander.mind)), "Bystander removing an item from a stolen bag was falsely framed for locker theft")

	// Unanchored crate on an open free locker is pushed clear when reserving it
	var/obj/structure/closet/secure_closet/personal/outpost_police/second_locker = bank[2]
	// Faces open floor, as a mapped locker does: the crate needs somewhere to go
	for(var/facing in GLOB.cardinals)
		var/turf/ahead = get_step(second_locker, facing)
		if(isfloorturf(ahead) && !ahead.is_blocked_turf(exclude_mobs = TRUE) && !(locate(/obj/structure/closet) in ahead))
			second_locker.setDir(facing)
			break
	second_locker.open(null, TRUE)
	var/obj/structure/closet/crate/crate = allocate(/obj/structure/closet/crate, get_turf(second_locker))
	var/mob/living/carbon/human/mod_prisoner = person()
	mod_prisoner.equip_to_slot_if_possible(allocate(/obj/item/card/id), ITEM_SLOT_ID, disable_warning = TRUE)
	var/obj/item/mod/control/pre_equipped/standard/mod_suit = allocate(/obj/item/mod/control/pre_equipped/standard)
	TEST_ASSERT(mod_prisoner.equip_to_slot_if_possible(mod_suit, ITEM_SLOT_BACK, disable_warning = TRUE), "Setup: MODsuit did not equip to back")
	mod_suit.quick_activation()
	TEST_ASSERT(mod_suit.active, "Setup: MODsuit did not activate")
	var/obj/item/restraints/handcuffs/extra_cuffs = allocate(/obj/item/restraints/handcuffs, get_turf(mod_prisoner))

	TEST_ASSERT(second_locker.reserve_for(mod_prisoner), "Unanchored crate on an open property locker blocked reserve_for()")
	TEST_ASSERT(get_turf(crate) != get_turf(second_locker) || !second_locker.opened, "Unanchored crate prevented the property locker from closing")
	second_locker.release_reservation()

	TEST_ASSERT(police.store_property(mod_prisoner, officer_beside(mod_prisoner)), "store_property failed on a prisoner wearing an active MODsuit")
	var/obj/structure/closet/secure_closet/personal/outpost_police/mod_locker = police.property_locker_for(mod_prisoner)
	TEST_ASSERT(!mod_suit.active, "Active MODsuit remained sealed on a jailed prisoner")
	TEST_ASSERT_EQUAL(mod_suit.loc, mod_locker, "Retracted MODsuit did not go into the property locker")
	TEST_ASSERT(police.store_extra_property(mod_prisoner, extra_cuffs), "store_extra_property did not store non-police cuffs")
	TEST_ASSERT_EQUAL(extra_cuffs.loc, mod_locker, "Non-police cuffs removed at booking did not enter the property locker")
	TEST_ASSERT(mod_locker.holds(extra_cuffs), "Stored non-police cuffs are not recorded by the property locker")

