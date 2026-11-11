/**
 * # Outpost police: witnesses
 *
 * Owner: P1. The whole "did anyone see it" test (owner decision 6, spec 3 and 18). This is the only police
 * file that names can_see, cyberware_camo_hides or a witness range; the stealth merge adds one subtype here
 * and changes one line in make_perception(), nothing else.
 */

/// The witness test this police uses
/datum/outpost_police/proc/make_perception()
	// The stealth merge returns its subtype here (spec 18)
	return new /datum/outpost_police_perception(src)

/// Who, if anyone, witnessed `offender` doing `crime`: POLICE_WITNESS_*. Sets `last_witness`.
/datum/outpost_police_perception/proc/witness_of(mob/living/offender, crime, atom/victim, obj/item/source)
	last_witness = null
	return POLICE_WITNESS_SAW

/// Whether `viewer` (an officer, an NPC, a camera) sees `target` now
/datum/outpost_police_perception/proc/sees(atom/viewer, mob/living/target)
	return FALSE

/// Whether `listener` hears `offender` doing `crime` with `source`
/datum/outpost_police_perception/proc/hears(atom/listener, mob/living/offender, crime, obj/item/source)
	return FALSE

/// What watches for the police besides people: the checkpoint scanners and panels
/datum/outpost_police_perception/proc/cameras()
	return list()

/// How long `witness` takes to report `crime`; 0 is at once
/datum/outpost_police_perception/proc/report_delay(atom/witness, crime)
	return 0

/// Whether `witness` can still make its report
/datum/outpost_police_perception/proc/can_report(atom/witness)
	return TRUE
