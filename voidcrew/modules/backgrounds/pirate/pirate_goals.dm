/// Backgrounds: owned by P4. See data/backgrounds/spec.md.

// The pirate goal: credits taken off other ships. Counted from COMSIG_BACKGROUND_CREDITS_TAKEN,
// which the siphon sends when a run ends (pirate_siphon.dm) and a hauler sends when it
// surrenders its hold. pirate_flag_hull() registers this on every flagged hull.

/datum/background/pirate/proc/on_credits_taken(obj/structure/overmap/ship/hull, obj/structure/overmap/ship/target, amount, source)
	SIGNAL_HANDLER
	if(!isnum(amount) || amount <= 0 || !hull.pirate_crew)
		return
	// The state procs refresh memories and record metrics; keep them off the signal's stack
	INVOKE_ASYNC(src, PROC_REF(count_take), hull, target, amount)

/// Adds one take to every playing pirate aboard the hull that took it
/datum/background/pirate/proc/count_take(obj/structure/overmap/ship/hull, obj/structure/overmap/ship/target, amount)
	if(QDELETED(hull) || !take_counts_for_goal(hull, target))
		return
	for(var/datum/mind/member in hull.ship_team?.members)
		var/datum/background_state/state = member.background_state
		if(!state || state.ended || state.key != BACKGROUND_PIRATE)
			continue
		state.add_progress(amount)
		record_metric(METRIC_BACKGROUND, "siphon_goal", ckey = state.ckey, ship = hull, subject = BACKGROUND_PIRATE, credits = amount, quantity = state.progress)

/**
 * ECO-10: a take counts unless it came off another pirate hull, or off a hull that shares a
 * player with this one (a friend lending his balance). NPC hulls always count. A mark that was
 * gone before the link closed still counts: the money left a real account.
 */
/datum/background/pirate/proc/take_counts_for_goal(obj/structure/overmap/ship/hull, obj/structure/overmap/ship/target)
	if(isnull(target))
		return TRUE
	if(target == hull || target.pirate_crew)
		return FALSE
	if(istype(target, /obj/structure/overmap/ship/npc))
		return TRUE
	var/list/ours = roster_ckeys(hull)
	if(!length(ours))
		return TRUE
	for(var/their_ckey in roster_ckeys(target))
		if(ours[their_ckey])
			return FALSE
	return TRUE

/// ckey -> TRUE for everyone ever counted aboard this hull and everyone on its roster now
/datum/background/pirate/proc/roster_ckeys(obj/structure/overmap/ship/hull)
	var/list/ckeys = list()
	for(var/entry in hull.background_ever_crew)
		if(istext(entry))
			ckeys[ckey(entry)] = TRUE
	for(var/datum/mind/member in hull.ship_team?.members)
		if(member.key)
			ckeys[ckey(member.key)] = TRUE
	return ckeys
