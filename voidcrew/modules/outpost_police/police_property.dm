/**
 * # Outpost police: property
 *
 * Owner: P12. Confiscation (the offending items), the evidence chute, the property lockers and the jail strip.
 * Spec 6.1, 6.3 and the locker half of 7.
 */

/// A prisoner's gear, locked to them (owner decision 7)
/obj/structure/closet/secure_closet/personal/outpost_police
	name = "property locker"
	/// Weakref to the mind of the prisoner whose gear this holds
	var/datum/weakref/owner_mind
	/// Weakrefs to what was put in it at the strip
	var/list/stored_items
	/// world.time its owner was let out, or 0 while they are still held
	var/released_at = 0

// Nothing comes with it (abuse M18)
/obj/structure/closet/secure_closet/personal/outpost_police/PopulateContents()
	return

/// The chute at the desk: crime tools go down it for good
/obj/machinery/outpost_police_evidence
	name = "evidence chute"
	icon = 'icons/obj/pipes_n_cables/disposal.dmi'
	icon_state = "intake"
	density = TRUE
	anchored = TRUE
	use_power = NO_POWER_USE

/// The case an officer carries what they took in
/obj/item/outpost_sealed_case/evidence

/// What a jailed prisoner wears
/obj/item/clothing/under/rank/prisoner/outpost_police

/obj/item/clothing/shoes/sneakers/orange/outpost_police

/// The Search step: takes the offending items off `suspect` into an evidence case in `officer`'s hand. Sleeps. Returns the case, or null.
/datum/outpost_police/proc/confiscate(mob/living/carbon/suspect, mob/living/officer)
	return null

/// At the desk: crime tools down the chute, stolen property back to its locker
/datum/outpost_police/proc/dispose_evidence(mob/living/officer)
	return

/// The jail strip: gear into a property locker, the prison jumpsuit on. Sleeps. TRUE if stripped, FALSE if no locker was free.
/datum/outpost_police/proc/store_property(mob/living/carbon/prisoner, mob/living/officer)
	return FALSE

/// For a later theft system: `thing` was stolen by `thief`. Unused in this build.
/datum/outpost_police/proc/mark_stolen(obj/item/thing, datum/mind/thief)
	return

/// Resets and locks the station's lockers (called by link_interior())
/datum/outpost_police/proc/build_property(list/locker_list, obj/machinery/outpost_police_evidence/evidence_chute)
	return
