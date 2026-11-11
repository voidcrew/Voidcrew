/**
 * # Outpost recovery: the crews
 *
 * Owners: R3 (the MORGUE HALF below) and R4 (the JANITOR HALF below); each edits only its own half
 * (spec-rehydrate.md 3). The crew are ambient outpost NPCs on the ambient controller and its activities: they walk
 * with the ambient runner, ride lifts with police.ride() and come in through the staff lift doors, never the
 * checkpoint. Everything they wear or carry is locked gear or deletes itself; they carry no cash (4.3, M33).
 *
 * Frozen by R0: the types and the shared vars of the base type.
 * Behaviour at R0: none. No wave is ever called, so no crew member is made outside tests.
 */

/// A cleanup crew member. Abstract: the morgue crew is recovery_morgue.dm's, the janitor recovery_janitor.dm's.
/mob/living/carbon/human/npc/ambient_npc/outpost/recovery
	name = "outpost worker"
	desc = "Outpost maintenance staff."
	dialogue_file = AMBIENT_STRINGS_RECOVERY
	dialogue_section = "halcyon"
	death_cash_low = 0
	death_cash_high = 0
	/// The recovery that sent them (set when the wave is made)
	var/datum/outpost_recovery/outpost_recovery
	/// The wave they came with (R2 counts waves; a number)
	var/wave = 0

/mob/living/carbon/human/npc/ambient_npc/outpost/recovery/Destroy()
	outpost_recovery = null
	return ..()

// =========================================================================
// MORGUE HALF (R3)
// =========================================================================

// =========================================================================
// JANITOR HALF (R4)
// =========================================================================

// The janitors' kit. The type, its tools and its work are in recovery_janitor.dm. Everything below is locked gear
// (human_npc_gear.dm): nobody takes the mop, the bag or the headset off a janitor, and they go when it does.

/**
 * What a cleaning crew's ID opens: the police lift doors (ACCESS_OUTPOST_POLICE), which the crews come in by and
 * take a full bag out by. Nothing else carries that access but the officers' own IDs.
 */
/datum/id_trim/recovery_crew
	assignment = "Outpost Maintenance"
	trim_state = "trim_janitor"
	department_color = COLOR_SERVICE_LIME
	subdepartment_color = COLOR_SERVICE_LIME
	sechud_icon_state = SECHUD_JANITOR
	access = list(ACCESS_OUTPOST_POLICE)

/// A janitor on a cleanup: a mop in one hand, a trash bag in the other, a headset, galoshes. The ID opens the police lift doors.
/datum/outfit/recovery_janitor
	name = "Outpost cleaning crew"
	uniform = /obj/item/clothing/under/rank/civilian/janitor
	gloves = /obj/item/clothing/gloves/color/purple
	head = /obj/item/clothing/head/soft/purple
	shoes = /obj/item/clothing/shoes/galoshes
	ears = /obj/item/radio/headset
	id = /obj/item/card/id/advanced
	id_trim = /datum/id_trim/recovery_crew
	r_hand = /obj/item/mop
	l_hand = /obj/item/storage/bag/trash

/// Overalls and a beanie instead
/datum/outfit/recovery_janitor/overalls
	name = "Outpost cleaning crew (overalls)"
	uniform = /obj/item/clothing/under/misc/overalls
	suit = /obj/item/clothing/suit/apron/overalls
	head = /obj/item/clothing/head/beanie
