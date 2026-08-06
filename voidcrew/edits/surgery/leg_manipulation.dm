/**
 * Organ manipulation on the legs.
 *
 * Between them, upstream's organ-manipulation surgeries cover the chest, head,
 * groin, eyes, mouth and both arms. No leg, and for good reason upstream: not a
 * single tg organ lives in one, so a leg incision would open onto nothing.
 *
 * This fork's chrome does live there. Shock Coils, Hopper Pistons and the Meteor
 * Piledriver all sit in the calves on ORGAN_SLOT_CYBERWARE_LEGS, and
 * manipulate_organs refuses any insert where the surgery's zone isn't the
 * organ's own. With no surgery whose possible_locs held a leg, the insert step
 * was unreachable: leg chrome could only ever go in at a Chrome Cradle, which
 * means at a ripperdoc parlor. Buy the Shock Coils off the first-tier catalog,
 * fly home, and there was no way to put them on.
 *
 * These two fill the gap with their parents' step lists untouched, so a leg
 * operates exactly like an arm does - same incisions, same tools, same times.
 * The organic one is the one that matters; the mechanic twin is here because
 * upstream's Hardware Manipulation has the identical hole, and a crewmate with
 * augmented legs should not be the one person who still can't fit pistons.
 */
/datum/surgery/organ_manipulation/soft/legs
	possible_locs = list(BODY_ZONE_L_LEG, BODY_ZONE_R_LEG)

/datum/surgery/organ_manipulation/mechanic/soft/legs
	possible_locs = list(BODY_ZONE_L_LEG, BODY_ZONE_R_LEG)
