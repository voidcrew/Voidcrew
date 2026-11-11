// Tutorial checklist hooks: the Vestige pact item (entering a vestige, the pact,
// the trial and the boon). Overrides chain with any others of the same proc; each
// returns the parent's value unchanged.

/// Chains with the /area/ruin/Entered hook in hooks_world.dm.
/area/ruin/space/has_grav/vestige/Entered(atom/movable/arrived, area/old_area)
	. = ..()
	if(!ismob(arrived))
		return
	var/mob/visitor = arrived
	if(!visitor.ckey || SSvc_tutorials.progress[visitor.ckey]?[TUTORIAL_STEP_VESTIGE_FIND])
		return
	tutorial_credit(visitor, TUTORIAL_STEP_VESTIGE_FIND)

/datum/vestige_trial/begin(mob/living/user)
	. = ..()
	tutorial_credit(user, TUTORIAL_STEP_VESTIGE_PACT)

/// The trial qdels itself in the parent, so the owner and body are saved first.
/// `fulfilled` is set only when the completion really took.
/datum/vestige_trial/complete()
	var/was_fulfilled = fulfilled
	var/datum/mind/keeper = owner
	var/mob/body = owner?.current
	. = ..()
	if(was_fulfilled || !fulfilled || !keeper)
		return
	tutorial_credit(body || keeper.current, TUTORIAL_STEP_VESTIGE_TRIAL)

/// The parent qdels the action and may replace the claiming body (shapeshift upgrades).
/datum/action/vestige_reward/claim(mob/living/user, datum/mind/mind, datum/vestige_boon/choice_type)
	var/was_paid = paid
	. = ..()
	if(was_paid || !paid)
		return
	tutorial_credit(QDELETED(user) ? mind?.current : user, TUTORIAL_STEP_VESTIGE_CLAIM)

// ---------------------------------------------------------------------------
// Patron pointers for Make a pact (ruin-vestige). Patrons are godmode NPCs that
// never leave their altar, so pointing at one through a wall gives nothing away.
// ---------------------------------------------------------------------------

/// How far from the viewer a patron is still pointed at.
#define TUTORIAL_PATRON_RANGE 40

/// Every vestige patron in the world (one per loaded vestige).
GLOBAL_LIST_EMPTY(tutorial_vestige_patrons)

/mob/living/basic/vestige_patron/Initialize(mapload)
	. = ..()
	GLOB.tutorial_vestige_patrons += src

/mob/living/basic/vestige_patron/Destroy()
	GLOB.tutorial_vestige_patrons -= src
	return ..()

/// Patrons in the vestige the viewer stands in.
/proc/tutorial_nearby_patrons(mob/user)
	. = list()
	var/turf/here = get_turf(user)
	if(!here)
		return
	for(var/mob/living/basic/vestige_patron/patron as anything in GLOB.tutorial_vestige_patrons)
		var/turf/there = get_turf(patron)
		if(!there || there.z != here.z || get_dist(here, there) > TUTORIAL_PATRON_RANGE)
			continue
		if(tutorial_same_tenant(here, there))
			. += patron

#undef TUTORIAL_PATRON_RANGE
