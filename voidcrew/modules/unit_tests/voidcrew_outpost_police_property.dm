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

	// A case deleted any other way keeps nothing alive (abuse M24)
	var/obj/item/outpost_sealed_case/evidence/loose = new(get_turf(cop))
	loose.police_ref = WEAKREF(police)
	var/obj/item/screwdriver/tool = new(loose)
	qdel(loose)
	TEST_ASSERT(QDELETED(tool), "A deleted evidence case spilled its contents")
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
