/**
 * Organ manipulation on the legs - closed by the 2026 upstream surgery rework, kept as a note.
 *
 * The old /datum/surgery API gated each surgery on a `possible_locs` whitelist, and between
 * them upstream's organ-manipulation surgeries covered the chest, head, groin, eyes, mouth
 * and both arms - no leg, since no tg organ lives in one. This fork's chrome does: Shock
 * Coils, Hopper Pistons and the Meteor Piledriver all sit in the calves on
 * ORGAN_SLOT_CYBERWARE_LEGS, so with no leg surgery the insert step was unreachable and leg
 * chrome could only be fitted at a Chrome Cradle. This file used to add the two missing
 * whitelist entries.
 *
 * /datum/surgery_operation/limb/organ_manipulation replaced all of that: it is generic over
 * whichever limb the surgeon is working on and decides what may go in via zone_check()
 * against the organ's own zone, so a leg is operable with no fork edit at all.
 *
 * Kept (empty) rather than deleted so the next person to go looking for "why can't I fit
 * pistons" finds the answer instead of the hole.
 */
