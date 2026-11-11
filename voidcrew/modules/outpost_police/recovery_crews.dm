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
