/// Backgrounds: owned by P3.

/**
 * The Marshal-class crew: a posse in dusters and bounty hats, sec HUDs over the eyes, cuffs on the belt.
 * No weapons [ECO-12]: the disablers, flashes and bolas are the hull's, in the marshal's locker
 * (marshal_brig.dm), stocked once per hull. A green-zone death respawns a hunter for free, so whatever
 * the outfit carries is minted again every life.
 *
 * The PDA moves to a pocket because the belt slot holds the cuffs. The Mechanic keeps his tool belt
 * and carries his cuffs in the pack.
 */

/// Marshal: the hard-worn suit with the sheriff's vest as the badge
/datum/outfit/job/captain/bounty_hunter
	name = "Marshal (Bounty Hunter)"
	uniform = /obj/item/clothing/under/rank/security/detective
	accessory = /obj/item/clothing/accessory/vest_sheriff
	suit = /obj/item/clothing/suit/toggle/jacket/det_trench
	head = /obj/item/clothing/head/cowboy/bounty
	shoes = /obj/item/clothing/shoes/cowboy/black
	glasses = /obj/item/clothing/glasses/hud/security
	gloves = null
	belt = /obj/item/storage/belt/security
	belt_contents = list(/obj/item/restraints/handcuffs = 2)
	l_pocket = /obj/item/modular_computer/pda/heads/captain
	pda_slot = ITEM_SLOT_LPOCKET
	backpack_contents = list()

/// Deputy: shirt and slacks, the deputy's armband as the badge
/datum/outfit/job/security/bounty_hunter
	name = "Deputy (Bounty Hunter)"
	uniform = /obj/item/clothing/under/rank/cargo/qm
	accessory = /obj/item/clothing/accessory/armband/deputy
	suit = /obj/item/clothing/suit/toggle/jacket/det_trench
	suit_store = null
	head = /obj/item/clothing/head/cowboy/bounty
	shoes = /obj/item/clothing/shoes/cowboy/black
	glasses = /obj/item/clothing/glasses/hud/security
	belt = /obj/item/storage/belt/security
	belt_contents = list(/obj/item/restraints/handcuffs = 2)
	l_pocket = /obj/item/modular_computer/pda/security
	r_pocket = null
	pda_slot = ITEM_SLOT_LPOCKET

/// Mechanic: the engineer's jumpsuit under the duster, tools on the belt
/datum/outfit/job/engineer/bounty_hunter
	name = "Mechanic (Bounty Hunter)"
	suit = /obj/item/clothing/suit/toggle/jacket/det_trench
	head = /obj/item/clothing/head/cowboy/bounty
	shoes = /obj/item/clothing/shoes/cowboy/black
	glasses = /obj/item/clothing/glasses/hud/security
	backpack_contents = list(
		/obj/item/construction/rcd/loaded = 1,
		/obj/item/restraints/handcuffs = 2,
	)

/// Tracker: a tan suit, nothing on the sleeve
/datum/outfit/job/assistant/bounty_hunter
	name = "Tracker (Bounty Hunter)"
	uniform = /obj/item/clothing/under/suit/tan
	suit = /obj/item/clothing/suit/toggle/jacket/det_trench
	head = /obj/item/clothing/head/cowboy/bounty
	shoes = /obj/item/clothing/shoes/cowboy/black
	glasses = /obj/item/clothing/glasses/hud/security
	belt = /obj/item/storage/belt/security
	belt_contents = list(/obj/item/restraints/handcuffs = 2)
	l_pocket = /obj/item/modular_computer/pda/assistant
	pda_slot = ITEM_SLOT_LPOCKET

// The tan suit stays: the assistant outfit would swap in a coloured jumpsuit
/datum/outfit/job/assistant/bounty_hunter/give_jumpsuit(mob/living/carbon/human/target)
	return
