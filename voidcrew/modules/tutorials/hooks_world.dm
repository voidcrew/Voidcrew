// Tutorial checklist hooks. Part C: closet, loot panel and ruin area hooks.
// Overrides chain with any others of the same proc; each returns the parent's value unchanged.

/// Opening an abandoned cache off-ship. Purchased caches are delivered aboard, so they don't count.
/obj/structure/closet/crate/zone_loot/open(mob/living/user, force = FALSE, special_effects = TRUE)
	. = ..()
	if(.)
		tutorial_credit_ruin_cache(src, user)

/obj/structure/closet/crate/secure/loot/open(mob/living/user, force = FALSE, special_effects = TRUE)
	. = ..()
	if(.)
		tutorial_credit_ruin_cache(src, user)

/proc/tutorial_credit_ruin_cache(obj/structure/closet/cache, mob/living/user)
	if(!ismob(user) || !user.ckey)
		return
	if(SSvc_tutorials.progress[user.ckey]?[TUTORIAL_STEP_RUIN_CACHE])
		return
	if(get_ship_from_atom(cache))
		return
	tutorial_credit(user, TUTORIAL_STEP_RUIN_CACHE)

/// Walking into a ruin. No ship maps /area/ruin.
/area/ruin/Entered(atom/movable/arrived, area/old_area)
	. = ..()
	if(!ismob(arrived))
		return
	var/mob/visitor = arrived
	if(!visitor.ckey || SSvc_tutorials.progress[visitor.ckey]?[TUTORIAL_STEP_RUIN_FIND])
		return
	tutorial_credit(visitor, TUTORIAL_STEP_RUIN_FIND)
