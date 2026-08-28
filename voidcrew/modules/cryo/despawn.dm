/**
 * ##Returning to cryosleep
 *
 * A cryopod is how a crew member arrives; this is how they leave. Climb back in, confirm,
 * and the character is taken out of the round: the seat on the ship's roster reopens for
 * whoever wants it next, and everything the character was carrying goes into storage with
 * them. The player lands back in the lobby and can join again immediately.
 *
 * ###Gear goes with them, all of it
 *
 * The seat is the point of the feature and also its exploit: freeing a slot and walking
 * out with a full kit means the same player can cycle through the pod all round, drawing a
 * fresh loadout every time and stacking the old ones somewhere. So nothing they are
 * carrying is left behind - not dropped on the deck, not held in the pod for collection,
 * not stored in a console. It is deleted with them.
 *
 * That is a blunt rule, and it is blunt on purpose: any exception is a place to stash gear.
 * The cost is that a genuinely irreplaceable item would evaporate with its owner, so
 * instead of carving out exceptions, the pod refuses to close over anyone holding one. See
 * GLOB.cryo_undeletable_items - the list is deliberately tiny, and everything on it is an
 * item whose destruction breaks something outside its owner (a mission that can no longer
 * be completed, a pirate bounty whose key no longer exists). Ordinary kit - ID, headset,
 * weapons, whatever they bought - is theirs to take into the freezer.
 *
 * ###Only the occupant decides
 *
 * Nobody can be put in the freezer by someone else. The pod refuses a mob dragged in by
 * anyone but themselves, the confirmation prompt is answered by the person going in, and
 * they must be awake and connected the whole way through. Stuffing a corpse or a
 * cuffed prisoner into a cryopod does nothing at all.
 *
 * ###A cold-feet window, then a cooldown
 *
 * Confirming does not delete anyone on the spot. The pod seals and runs a fifteen-second
 * cryostasis cycle first; climbing out (resist or move) any time before it completes
 * cancels the whole thing with nothing lost. Only a cycle that finishes with the same
 * person still sealed inside takes them out of the round.
 *
 * Leaving also starts a rejoin cooldown on the player FOR THAT SHIP, checked at the join
 * menu. Without it the pod is a gear printer - strip your kit onto the deck, cryo out,
 * rejoin the freed seat, draw a fresh loadout, repeat. Ten minutes of bench time on the
 * hull they just left makes the loop useless, while switching to a different ship (or
 * requisitioning a new hull) stays instant - that is a fresh start, not a dupe.
 */

/// How long the pod's cryostasis cycle runs after confirmation - the climb-out-and-cancel window.
#define CRYO_DESPAWN_GRACE (15 SECONDS)
/// How long after a voluntary despawn the player is barred from rejoining the ship they left.
#define CRYO_REJOIN_COOLDOWN (10 MINUTES)

/// "ckey@shipref" -> world.time when that player may rejoin that ship, written on despawn.
GLOBAL_LIST_EMPTY(cryo_rejoin_cooldowns)

/**
 * Deciseconds until this ckey may rejoin this specific ship, or 0 if they are clear now.
 * Other ships are never gated - the cooldown exists to stop same-seat loadout cycling.
 */
/proc/cryo_rejoin_wait(ckey, obj/structure/overmap/ship/ship)
	if(!ship)
		return 0
	var/until = GLOB.cryo_rejoin_cooldowns["[ckey]@[REF(ship)]"]
	if(!until || world.time >= until)
		return 0
	return until - world.time

/**
 * Item types the pod will not take out of the round. Carrying one blocks the despawn
 * outright rather than being quietly dropped - a dropped exception is a gear-stash hole.
 *
 * * ship_key: claiming a captured hull and turning in pirate bounties both run through the
 *   physical key. Deleting one strands the bounty and the hull it names.
 * * mission_recovery: the payload of a recovery or delivery contract. The contract has no
 *   way to mint a replacement.
 */
GLOBAL_LIST_INIT(cryo_undeletable_items, typecacheof(list(
	/obj/item/ship_key,
	/obj/item/mission_recovery,
)))

/**
 * The first thing on this mob that must not be destroyed, or null if they are clear to go.
 */
/obj/machinery/cryopod/proc/find_cryo_blocking_item(mob/living/user)
	for(var/obj/item/carried as anything in user.get_all_contents_type(/obj/item))
		if(is_type_in_typecache(carried, GLOB.cryo_undeletable_items))
			return carried
	return null

/**
 * Another player being carried around in a bag does not get taken out of the round because
 * the person holding the bag pressed a button. Only the occupant leaves.
 */
/obj/machinery/cryopod/proc/find_carried_player(mob/living/user)
	for(var/mob/carried in user.get_all_contents())
		if(carried == user)
			continue
		if(carried.client)
			return carried
	return null

/**
 * Entry point for a crew member climbing back in. Both the hand click and the
 * drag-yourself-onto-it gesture land here.
 */
/obj/machinery/cryopod/proc/try_return_to_cryo(mob/living/user)
	if(!iscarbon(user) || !user.client)
		return
	if(occupant && occupant != user)
		balloon_alert(user, "already occupied!")
		return
	if(user.loc == src)
		// Already sealed in with the cycle running. Climbing out is the only input that
		// matters now - re-confirming would arm a second countdown timer.
		return
	// VOIDCREW EDIT: this was `stat != CONSCIOUS`, which covered knocked-out too.
	// Upstream (tg #97041) deleted the UNCONSCIOUS stat and made stat purely
	// health-derived, so a bare `stat != STABLE` is a strictly looser predicate and
	// let an unconscious player be cryoed - past a balloon alert that says "you must
	// be awake!". IS_UNCONSCIOUS_OR_CRIT() is upstream's own replacement for
	// `stat != CONSCIOUS` and carries both halves.
	if(IS_UNCONSCIOUS_OR_CRIT(user))
		balloon_alert(user, "you must be awake!")
		return
	if(!crew_can_modify(user))
		balloon_alert(user, "ship crew only!")
		return

	var/obj/item/blocker = find_cryo_blocking_item(user)
	if(blocker)
		to_chat(user, span_warning("[src] will not close over [blocker] - it is still needed aboard. Hand it to the crew or leave it somewhere safe first."))
		return
	var/mob/passenger = find_carried_player(user)
	if(passenger)
		to_chat(user, span_warning("You are still carrying [passenger]. Let them out before you climb in."))
		return

	var/confirm = tgui_alert(
		user,
		"Return to cryosleep? [user.real_name] leaves the round for good, and everything you are carrying goes into storage with you - nothing is left aboard. Your seat on the crew roster reopens. The pod takes [CRYO_DESPAWN_GRACE / 10] seconds to cycle - climbing out cancels it - and you will not be able to rejoin THIS ship for [CRYO_REJOIN_COOLDOWN / 600] minutes afterwards. Other ships stay open to you.",
		"Return to Cryosleep",
		list("Return to Cryosleep", "Stay Awake"),
		timeout = 30 SECONDS,
	)
	if(confirm != "Return to Cryosleep")
		return

	// Everything above can change while the box is open: they can be shot, cuffed, dragged
	// off, handed the mission item, or the pod can be filled by a joiner arriving.
	if(QDELETED(src) || QDELETED(user) || !user.client || IS_UNCONSCIOUS_OR_CRIT(user))
		return
	if(!user.Adjacent(src) || (occupant && occupant != user))
		balloon_alert(user, "can't reach!")
		return
	blocker = find_cryo_blocking_item(user)
	if(blocker)
		to_chat(user, span_warning("[src] will not close over [blocker]."))
		return
	passenger = find_carried_player(user)
	if(passenger)
		to_chat(user, span_warning("You are still carrying [passenger]."))
		return

	begin_cryo_countdown(user)

/**
 * Seals the confirmed leaver in and starts the cryostasis cycle. Nothing irreversible
 * happens here: for the length of the grace window they are an ordinary occupant, and
 * container_resist_act() / relaymove() let them climb straight back out, which makes
 * finish_cryo_countdown() find the pod empty and quietly drop the whole thing.
 */
/obj/machinery/cryopod/proc/begin_cryo_countdown(mob/living/carbon/user)
	// Sealed in before anything is taken apart, so that if an unequip handler decides to drop
	// something rather than let it be deleted, it lands in the pod and not on the deck. The
	// pod's contents are swept at despawn either way.
	user.visible_message(
		span_notice("[user] climbs into [src], and the lid swings shut."),
		span_notice("You climb into [src] and the cryostasis cycle begins. You have [CRYO_DESPAWN_GRACE / 10] seconds to climb back out if you change your mind."),
	)
	icon_state = close_state
	user.forceMove(src)
	set_occupant(user)
	addtimer(CALLBACK(src, PROC_REF(finish_cryo_countdown), user), CRYO_DESPAWN_GRACE)

/**
 * The end of the grace window. Anything that interrupted the cycle - they climbed out,
 * someone wrenched the pod apart, the hull went with the ship - cancels the despawn;
 * a leaver who lost their connection mid-cycle is released rather than deleted, since a
 * player who cannot cancel any more must not be held to a choice they cannot revisit.
 */
/obj/machinery/cryopod/proc/finish_cryo_countdown(mob/living/carbon/user)
	if(QDELETED(src) || QDELETED(user) || occupant != user || user.loc != src)
		return
	if(!user.client || IS_UNCONSCIOUS_OR_CRIT(user))
		visible_message(span_notice("[src] clicks and reopens without completing its cycle."))
		open_machine()
		return
	do_cryo_despawn(user)

/**
 * Takes the character out of the round. Assumed already validated and sealed in by the
 * countdown path above.
 */
/obj/machinery/cryopod/proc/do_cryo_despawn(mob/living/carbon/user)
	var/obj/structure/overmap/ship/owner = linked_ship?.current_ship
	var/datum/mind/leaving_mind = user.mind
	var/despawn_name = user.real_name
	var/player_key = user.key
	var/player_ckey = user.ckey

	user.visible_message(
		span_notice("[src] hums as the cryostasis cycle completes."),
		span_notice("The cold takes hold, and the round ends here for you."),
	)
	// The dupe-loop half of the anti-dupe rule: the seat this player just freed on THIS
	// hull is barred to them until the cooldown lapses. Checked at the join menu; every
	// other ship, and hull requisition, stays open to them immediately.
	if(owner)
		GLOB.cryo_rejoin_cooldowns["[player_ckey]@[REF(owner)]"] = world.time + CRYO_REJOIN_COOLDOWN

	// Announced before the roster edit, so the notice still reaches a crew of one.
	owner?.ship_notify("[despawn_name] has entered cryogenic storage.", "CREW UPDATE", SHIP_NOTIFY_NOTICE, 'voidcrew/sound/notify.ogg', 40)
	release_ship_seat(owner, leaving_mind)
	detach_from_crews(leaving_mind, despawn_name)
	GLOB.manifest.remove(despawn_name)

	// The client leaves before the body does: /mob/Destroy() stack traces on a mob that still
	// has one, and abandon_mob() is the established way back to the lobby. Anything they had
	// open aboard is shut rather than carried into the lobby with them.
	SStgui.close_user_uis(user)
	var/client/leaving_client = user.client
	leaving_client.screen.Cut()
	leaving_client.screen += leaving_client.void
	var/mob/dead/new_player/lobby = new()
	lobby.PossessByPlayer(player_key)

	// Every last thing they were carrying, deepest container first so a bag is emptied
	// before it is deleted. Their own anatomy is left alone - the mob deletion handles it.
	var/list/belongings = user.get_all_contents()
	for(var/i in length(belongings) to 1 step -1)
		var/atom/movable/thing = belongings[i]
		if(thing == user || QDELETED(thing))
			continue
		if(isbodypart(thing) || isorgan(thing))
			continue
		qdel(thing)

	log_shuttle("[player_ckey] / [despawn_name] returned to cryosleep aboard [owner?.name || "an unlinked pod"]")
	SSblackbox.record_feedback("tally", "cryo_despawn", 1, owner?.source_template?.name || "unknown")

	qdel(user)

	// Whatever an unequip handler shed into the pod on the way out goes with them as well.
	// This is the backstop on the whole anti-dupe rule: the pod is empty when it reopens.
	for(var/obj/item/leftover in contents)
		qdel(leftover)

	// Back to a spawn point ready for the next joiner.
	set_occupant(null)
	icon_state = initial(icon_state)
	update_appearance()

/**
 * Puts the leaver's seat back on the board.
 *
 * The slot is returned to the ship's own job_slots rather than left closed, since holding a
 * seat shut for a player who is no longer in the round is the thing this feature exists to
 * stop. It is capped where the cryo console's own slot editor caps it, so cycling through
 * the pod can never inflate a hull past the crew size it is allowed to carry.
 */
/obj/machinery/cryopod/proc/release_ship_seat(obj/structure/overmap/ship/owner, datum/mind/leaving_mind)
	var/datum/job/held_job = leaving_mind?.assigned_role
	if(QDELETED(owner) || !held_job || !(held_job in owner.job_slots))
		return
	var/ceiling = max(1, min((owner.initial_job_slots?[held_job] || 1) * 2, 6))
	owner.job_slots[held_job] = min(owner.job_slots[held_job] + 1, ceiling)
	held_job.current_positions = max(0, held_job.current_positions - 1)

/**
 * Takes the character off every crew they were on, not just the one whose pod they climbed
 * into. The body is about to stop existing, and a roster entry whose mind has no mob behind
 * it is a live trap: the derelict sweep would otherwise count a crew that cannot be
 * counted, and has_active_crew() reads this roster once a minute for every hull.
 */
/obj/machinery/cryopod/proc/detach_from_crews(datum/mind/leaving_mind, despawn_name)
	if(!leaving_mind)
		return
	// Copied: remove_member() mutates ship_teams as it goes.
	for(var/datum/team/voidcrew/crew as anything in leaving_mind.ship_teams?.Copy())
		var/obj/structure/overmap/ship/crewed_ship = crew.ship
		if(crewed_ship)
			crewed_ship.manifest -= despawn_name
			// remove_member() covers acting command and the Ship Management button; a claimed
			// captaincy is held separately and outlives the roster without this.
			if(crewed_ship.claimed_captain == leaving_mind)
				crewed_ship.claimed_captain = null
		crew.remove_member(leaving_mind)

// ===== INTERACTION =====

/obj/machinery/cryopod/interact(mob/user)
	if(!iscarbon(user))
		return ..()
	// Deliberately not chaining: the pod has no TGUI, so the parent's only remaining job on
	// this path is the fingerprint.
	add_fingerprint(user)
	try_return_to_cryo(user)
	return TRUE

/obj/machinery/cryopod/mouse_drop_receive(atom/dropped, mob/user, params)
	if(!isliving(user))
		return
	// Adjacency and usability are already settled by base_mouse_drop_handler().
	if(dropped != user)
		balloon_alert(user, "they have to climb in themselves!")
		return
	try_return_to_cryo(user)

#undef CRYO_DESPAWN_GRACE
#undef CRYO_REJOIN_COOLDOWN
