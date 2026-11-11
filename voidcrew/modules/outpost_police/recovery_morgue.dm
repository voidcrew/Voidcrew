/**
 * # Outpost recovery: the morgue crew
 *
 * Owner: R3 (spec-rehydrate.md 3.1, M32, M35). Bag a body with a real body bag, wheel it to a staff lift; an NPC
 * body leaves the round with the bag, a player's body goes to a tray in the morgue room (recovery.morgue_trays) and
 * is never deleted, stripped or taken off the outpost.
 *
 * Frozen by R0: the type and the proc names and signatures below. Behaviour at R0: none.
 */

/// Bags and carries the dead
/mob/living/carbon/human/npc/ambient_npc/outpost/recovery/morgue
	name = "morgue worker"
	desc = "Outpost morgue staff."

/// Whether `body` may be taken now: 3.1's free-body rule
/datum/outpost_recovery/proc/body_free(mob/living/body)
	return FALSE

/// The body `worker` should go for next (officers' and traders' first), or null
/datum/outpost_recovery/proc/next_body(mob/living/worker)
	return null

/// `worker` takes `body`; TRUE if nobody else had it. One worker per body.
/datum/outpost_recovery/proc/claim_body(mob/living/body, mob/living/worker)
	return FALSE

/// `body` is nobody's again
/datum/outpost_recovery/proc/release_body(mob/living/body)
	return
