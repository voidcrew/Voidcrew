/**
 * # Outpost recovery: the morgue crew
 *
 * Owner: R3 (spec-rehydrate.md 3.1, M32, M35). Bag a body with a real body bag, pull it to a lift; an NPC body
 * leaves the round with the bag, a player's body goes to a tray in the morgue room (recovery.morgue_trays) and
 * is never deleted, stripped or taken off the outpost.
 *
 * How a worker does it (/datum/ambient_activity/recover_body, on the ambient runner):
 * - Pick: next_body(), officers' and traders' first, then the nearest; one worker per body (claim_body()).
 * - Bag: beside the body, a body bag in hand; a do_after, then the bag is unfolded on the body's tile and closed
 *   over it. tg's closet does the taking; the crew bag only lets in the body it was opened for and the limbs and
 *   organs picked up with it (M32: nothing living, nothing else on the tile).
 * - Haul: tg's pull. An NPC body goes to the nearest lift tile of its sector (the staff lift behind a police
 *   door, a berth's alcove or the lobby alcove) and down the lift. A player's body is pulled on foot out through
 *   the exit gate to the lobby (from a hangar berth, police.ride() to the lobby first) and goes into a free tray
 *   (the tray's own drag-onto and close), or onto the morgue floor when every tray is full.
 * - Steps that take time on a body (bagging, the lift, the tray) run as one action at a time (begin_action()),
 *   so the routine never sleeps.
 *
 * No roller bed: tg's roller bed buckles mobs only and a body bag can't be put on one, so the bag is pulled, as
 * a player pulls one.
 *
 * Nobody heals, defibs or preserves anything. Verified in code: tg's morgue tray cools its own air to -60 C
 * while shut (bodycontainer/morgue process()); a dead body still takes on the temperature around it (Life()
 * handle_environment()), and organs stop decaying at 0 C (organ on_death()) and rot pauses at -10 C
 * (/datum/component/rot). So a tray slows decay by tg's own rules; nothing is added here.
 *
 * M35 (verified, nothing to add): a berth wipe (outpost_hangar.dm eject_occupants()) moves every mob, dead ones
 * too, and every loose object holding a /mob/living (a body bag with a body) to the lobby alcove, where this crew
 * takes it to the morgue. A body aboard a docked ship leaves with the ship and is never touched (body_free()).
 *
 * The crew's lines (RECOVERY_LINE_FIRST_BODY, _OFFICER_BODY aloud; _BAGGED, _TRAY, _LIFT over the radio) are in
 * AMBIENT_STRINGS_RECOVERY, written by R4.
 */

/// The do_after to unfold a bag over a body
#define MORGUE_BAG_TIME (4 SECONDS)
/// One body's job is given up after this long (it is tried again later)
#define MORGUE_JOB_TIMEOUT (5 MINUTES)
/// An action that never came back (a runtime inside it) is let go after this long
#define MORGUE_ACTION_STUCK (1 MINUTES)
/// A lift ride that failed this many times gives the body up for now
#define MORGUE_RIDE_TRIES 3
/// Walks to a body that ended out of reach before it is given up for now
#define MORGUE_APPROACH_TRIES 3
/// A body that can't be bagged at all (too big for a bag) is left this long
#define MORGUE_UNBAGGABLE_RETRY (10 MINUTES)
/// An open crew bag with nothing in it goes after this long
#define MORGUE_EMPTY_BAG_TIME (2 MINUTES)
/// With no bodies left to collect they take the lift out after this long
#define MORGUE_IDLE_LEAVE (45 SECONDS)

/// The job's stages
#define MORGUE_STAGE_FETCH "fetch"
#define MORGUE_STAGE_HAUL "haul"
#define MORGUE_STAGE_DONE "done"

/// Where a haul is going
#define MORGUE_GOAL_LIFT_OUT "lift_out"
#define MORGUE_GOAL_RIDE "ride"
#define MORGUE_GOAL_TRAY "tray"
#define MORGUE_GOAL_FLOOR "floor"

// =========================================================================
// THE WORKER
// =========================================================================

/// Bags and carries the dead
/mob/living/carbon/human/npc/ambient_npc/outpost/recovery/morgue
	name = "morgue worker"
	desc = "Outpost morgue staff."
	outfit = /datum/outfit/outpost_morgue
	// On the station's radio net: what they see goes out on their headset, or not at all (stealth_radio.dm)
	stealth_radio = TRUE
	routine = list(/datum/ambient_activity/recover_body = 1)
	/// world.time since when they have had no body to collect, or 0
	var/idle_since = 0

/mob/living/carbon/human/npc/ambient_npc/outpost/recovery/morgue/Initialize(mapload, datum/human_npc_order/order)
	. = ..()
	// Their ID reads their name, as a person's does
	var/obj/item/card/id/card = wear_id
	if(istype(card))
		card.registered_name = real_name
		card.update_label()
	var/obj/item/radio/headset = ears
	if(istype(headset))
		headset.set_frequency(OUTPOST_POLICE_RADIO_FREQ)
	// The zone's voice, as its officers have
	var/obj/structure/overmap/trader_outpost/outpost = get_trader_outpost_for_turf(get_turf(src))
	var/section = outpost?.police?.profile?.voice_section
	if(section)
		dialogue_section = section

/mob/living/carbon/human/npc/ambient_npc/outpost/recovery/morgue/shift_times(delay)
	. = ..()
	idle_since = ambient_shifted(idle_since, delay)

/mob/living/carbon/human/npc/ambient_npc/outpost/recovery/morgue/get_lines(context)
	var/obj/structure/overmap/trader_outpost/outpost = morgue_recovery()?.outpost || get_outpost()
	var/section = outpost?.police?.profile?.voice_section
	if(section)
		dialogue_section = section
	var/static/list/morgue_contexts = list(
		"idle" = TRUE,
		"talk" = TRUE,
		"work" = TRUE,
		"chat" = TRUE,
		"reply" = TRUE,
		"attacked" = TRUE,
		"violence" = TRUE,
		"leave" = TRUE,
	)
	if(morgue_contexts[context])
		var/list/lines = ambient_dialogue_lines(dialogue_file, dialogue_section, "morgue_[context]")
		if(length(lines))
			return outpost_fresh_lines(lines, last_line)
	return ..()

/mob/living/carbon/human/npc/ambient_npc/outpost/recovery/morgue/pick_conversation()
	var/list/entry = ambient_dialogue_section(dialogue_file, dialogue_section)
	var/list/conversations = entry?["morgue_conversations"]
	if(!length(conversations))
		return null
	var/list/conversation = pick(conversations)
	if(!islist(conversation) || !istext(conversation["opener"]))
		return null
	var/list/replies = conversation["replies"]
	return list(conversation["opener"], length(replies) ? pick(replies) : null)

/mob/living/carbon/human/npc/ambient_npc/outpost/recovery/morgue/pick_activity()
	var/datum/outpost_recovery/rec = morgue_recovery()
	var/mob/living/target = rec?.next_body(src)
	if(target && needs_checkpoint_cross(target))
		idle_since = 0
		var/datum/ambient_activity/cross = start_activity(new /datum/ambient_activity/cross_checkpoint(src))
		if(cross)
			return cross
	var/datum/ambient_activity/job = start_activity(new /datum/ambient_activity/recover_body(src))
	if(job)
		idle_since = 0
		return job
	if(!idle_since)
		idle_since = max(world.time, 1)
	if(world.time - idle_since >= MORGUE_IDLE_LEAVE && (!rec || (!length(rec.npc_bodies()) && !length(rec.player_bodies()))))
		morgue_radio(RECOVERY_LINE_LIFT)
		return start_activity(new /datum/ambient_activity/leave(src))
	return start_activity(new /datum/ambient_activity/idle(src))

/mob/living/carbon/human/npc/ambient_npc/outpost/recovery/morgue/death(gibbed)
	var/was_alive = stat != DEAD
	. = ..()
	if(was_alive && stat == DEAD)
		morgue_recovery()?.crew_lost(src)

/// The recovery they work for: the one that sent them, or the outpost's they stand at
/mob/living/carbon/human/npc/ambient_npc/outpost/recovery/morgue/proc/morgue_recovery()
	if(outpost_recovery && !QDELETED(outpost_recovery))
		return outpost_recovery
	var/obj/structure/overmap/trader_outpost/outpost = get_trader_outpost_for_turf(get_turf(src))
	return outpost?.ensure_recovery()

/// Anywhere on their outpost: the concourse, the lobby and the hangars, as an officer (the dead lie anywhere)
/mob/living/carbon/human/npc/ambient_npc/outpost/recovery/morgue/leash_ok(turf/tile)
	var/obj/structure/overmap/trader_outpost/keep = outpost_recovery?.outpost
	if(!keep)
		return ..()
	tile = get_turf(tile)
	return tile && get_trader_outpost_for_turf(tile) == keep

/**
 * Says a line of `context` over their headset, on the station's frequency. Nothing at all with the headset off,
 * EMPed or jammed, or when they can't talk (decision 19). TRUE if they spoke.
 */
/mob/living/carbon/human/npc/ambient_npc/outpost/recovery/morgue/proc/morgue_radio(context)
	return crew_radio(context)

// =========================================================================
// THE BAG
// =========================================================================

/// The bag they hold while walking to a body: a prop locked to them, gone when put away
/obj/item/bodybag/outpost_morgue
	unfoldedbag_path = /obj/structure/closet/body_bag/outpost_morgue

/**
 * The crew's body bag (4.3, M32, M33). It lets in only the body it was opened for and the parts picked up with
 * it, so it never takes a living person or anything else lying on the tile. It can't be folded into an item,
 * leaves no cloth, and is gone once it is shut with nothing in it, or left open and empty for a while.
 */
/obj/structure/closet/body_bag/outpost_morgue
	desc = "A heavy plastic bag with an outpost morgue seal."
	material_drop = null
	material_drop_amount = 0
	/// The body it was opened for
	var/datum/weakref/meant_for
	/// Limbs and organs picked up with that body (weakrefs)
	var/list/datum/weakref/allowed_parts
	/// Left in the morgue room (every tray full) or the lobby: its body is where it should be
	var/delivered = FALSE

/obj/structure/closet/body_bag/outpost_morgue/Initialize(mapload)
	. = ..()
	// One made and never filled (a ship save rebuilding it, a failed bagging) does not stay
	addtimer(CALLBACK(src, PROC_REF(vanish_if_empty)), 5 SECONDS, TIMER_DELETE_ME)

/obj/structure/closet/body_bag/outpost_morgue/Destroy()
	meant_for = null
	allowed_parts = null
	return ..()

/obj/structure/closet/body_bag/outpost_morgue/attempt_fold(mob/living/carbon/human/the_folder)
	if(istype(the_folder))
		to_chat(the_folder, span_warning("[src] won't fold up."))
	return FALSE

/obj/structure/closet/body_bag/outpost_morgue/insertion_allowed(atom/movable/thing)
	if(ismob(thing))
		var/mob/living/body = thing
		if(!isliving(body) || body.stat != DEAD || body != meant_for?.resolve())
			return FALSE
		return ..()
	if(isbodypart(thing) || isorgan(thing))
		if(!(WEAKREF(thing) in allowed_parts))
			return FALSE
		return ..()
	return FALSE

/obj/structure/closet/body_bag/outpost_morgue/after_close(mob/living/user)
	. = ..()
	if(!length(contents))
		qdel(src)

/obj/structure/closet/body_bag/outpost_morgue/after_open(mob/living/user, force)
	. = ..()
	if(!length(contents))
		addtimer(CALLBACK(src, PROC_REF(vanish_if_empty)), MORGUE_EMPTY_BAG_TIME, TIMER_DELETE_ME)

/// Gone if nothing is in it
/obj/structure/closet/body_bag/outpost_morgue/proc/vanish_if_empty()
	if(QDELETED(src) || length(contents))
		return
	qdel(src)

/// Someone revived in a crew bag inside a closed morgue tray can always push the tray and bag open
/obj/structure/closet/body_bag/outpost_morgue/relaymove(mob/living/user, direction)
	if(user.stat)
		return
	if(istype(loc, /obj/structure/bodycontainer))
		container_resist_act(user)
		return
	return ..()

/obj/structure/closet/body_bag/outpost_morgue/container_resist_act(mob/living/user, loc_required = TRUE)
	var/obj/structure/bodycontainer/tray = loc
	if(!opened && istype(tray))
		if(!tray.locked)
			COOLDOWN_RESET(tray, open_close_cd)
			tray.open()
			if(isturf(loc) && !welded && !locked)
				open(user)
			return
		if(DOING_INTERACTION_WITH_TARGET(user, tray))
			return
		user.changeNext_move(CLICK_CD_BREAKOUT)
		user.last_special = world.time + CLICK_CD_BREAKOUT
		user.visible_message(null,
			span_notice("You lean on the back of [tray] and start pushing the tray open..."),
			span_hear("You hear a metallic creaking from [tray]."))
		if(!do_after(user, 1 MINUTES, target = tray))
			return
		if(QDELETED(user) || user.stat != CONSCIOUS || user.loc != src || loc != tray)
			return
		tray.locked = FALSE
		COOLDOWN_RESET(tray, open_close_cd)
		tray.open()
		if(isturf(loc) && !welded && !locked)
			open(user)
		return
	return ..()

// =========================================================================
// HELPERS
// =========================================================================

/// Whether `someone` is a person at the keyboard (or a disconnected one), not an NPC
/proc/morgue_is_player(mob/living/someone)
	return !!(someone.client || someone.ckey || someone.mock_client)

/// Whether `body` is an NPC's: a human NPC nobody ever played. Only these bodies ever leave the round.
/proc/morgue_npc_body(mob/living/body)
	if(!ishumannpc(body) || body.mind || body.ckey || body.client)
		return FALSE
	var/mob/living/carbon/carbon_body = body
	return !carbon_body.last_mind

/// Whether `thing` holds someone alive (M32): a mob in it, not dead. A brain in a jar or a severed head is not.
/proc/morgue_holds_life(atom/thing)
	for(var/mob/living/someone in thing)
		if(someone.stat != DEAD && !istype(someone, /mob/living/brain))
			return TRUE
	return FALSE

/// Whether `part` (a limb or organ) holds a person's mind: never deleted with an NPC
/proc/morgue_part_has_person(obj/item/part)
	for(var/mob/living/someone in part.get_all_contents())
		if(someone.mind || someone.ckey)
			return TRUE
	return FALSE

/**
 * Puts on `where` whatever in `thing` holds a person (a pAI card, an MMI, a bag with a player's pet in it), so nobody
 * leaves the round with an NPC body or its bag (abuse SF3, M32). A limb or organ with a person in it is
 * morgue_part_has_person()'s to keep.
 */
/proc/morgue_drop_persons(atom/movable/thing, turf/where)
	for(var/mob/living/someone in thing.get_all_contents())
		if(someone == thing || !(someone.mind || someone.ckey))
			continue
		var/atom/movable/holder = someone
		while(holder.loc && holder.loc != thing)
			holder = holder.loc
		if(holder.loc != thing || istype(holder, /obj/item/organ) || istype(holder, /obj/item/bodypart))
			continue
		if(ismob(thing) && isitem(holder))
			var/mob/wearer = thing
			wearer.dropItemToGround(holder, force = TRUE)
		holder.forceMove(where)

/// The atom a worker stands beside to bag `body`: the body, or the bag it lies in
/proc/morgue_bag_target(mob/living/body)
	return isturf(body.loc) ? body : body.loc

/// Whether `body` is in a morgue tray, or in a crew bag left where it belongs
/proc/morgue_body_done(mob/living/body)
	var/atom/holder = body.loc
	while(holder && !isturf(holder))
		if(istype(holder, /obj/structure/bodycontainer/morgue))
			return TRUE
		var/obj/structure/closet/body_bag/outpost_morgue/bag = holder
		if(istype(bag) && bag.delivered)
			return TRUE
		holder = holder.loc
	return FALSE

/// Whether one of `berth`'s own crew is awake in the berth
/proc/morgue_berth_crew_present(datum/outpost_berth/berth)
	var/datum/team/voidcrew/team = berth.ship?.ship_team
	for(var/datum/mind/member as anything in team?.members)
		var/mob/living/body = member?.current
		if(!isliving(body) || body.stat != CONSCIOUS)
			continue
		if(berth.contains_turf(get_turf(body)))
			return TRUE
	return FALSE

/// Whether `tray` can take a body: it has its tray, and nothing alive or dead in it or on it (an empty bag is lifted off)
/proc/morgue_tray_free(obj/structure/bodycontainer/morgue/tray)
	if(QDELETED(tray) || !tray.connected)
		return FALSE
	var/list/things = tray.get_all_contents()
	if(tray.connected.loc != tray)
		var/turf/tray_turf = get_turf(tray.connected)
		things += tray_turf.get_all_contents()
	for(var/atom/thing as anything in things)
		if(isliving(thing))
			return FALSE
	return TRUE

// =========================================================================
// THE API (frozen names)
// =========================================================================

/datum/outpost_recovery
	/// The wave whose first body was spoken of (RECOVERY_LINE_FIRST_BODY), or -1
	var/morgue_first_wave = -1

/**
 * Whether `body` may be taken now (3.1): dead (M32), at this outpost and not aboard a ship docked there, lying
 * loose or in a body bag nobody holds, not pulled, carried or buckled, not already in a tray, with no awake
 * player within OUTPOST_RECOVERY_FREE_RANGE and, in a berth, none of that berth's crew awake in it.
 */
/datum/outpost_recovery/proc/body_free(mob/living/body)
	if(QDELETED(body) || !isliving(body) || body.stat != DEAD || !outpost)
		return FALSE
	var/turf/where = get_turf(body)
	if(!where || get_trader_outpost_for_turf(where) != outpost)
		return FALSE
	if(body.pulledby || body.buckled || body.has_buckled_mobs())
		return FALSE
	if(!isturf(body.loc))
		var/obj/structure/closet/body_bag/bag = body.loc
		if(!istype(bag) || !isturf(bag.loc) || bag.pulledby || bag.anchored)
			return FALSE
	if(morgue_body_done(body))
		return FALSE
	if(get_ship_from_atom(where))
		return FALSE
	for(var/mob/living/someone in range(OUTPOST_RECOVERY_FREE_RANGE, where))
		if(someone.stat == CONSCIOUS && morgue_is_player(someone))
			return FALSE
	for(var/datum/outpost_berth/berth as anything in outpost.berths)
		if(berth?.contains_turf(where))
			if(morgue_berth_crew_present(berth))
				return FALSE
			break
	return TRUE

/**
 * The body `worker` should go for next, or null: among this outpost's dead (npc_dead and player_dead) that no
 * other worker has, that are not waiting out a retry and are free, officers' and traders' first, then the
 * nearest. A body found not free waits OUTPOST_RECOVERY_BODY_RETRY before it is looked at again.
 */
/datum/outpost_recovery/proc/next_body(mob/living/worker)
	var/turf/from = get_turf(worker)
	var/datum/outpost_police/police = outpost?.police
	var/worker_sector = (from && police) ? police.sector_of(from) : null
	for(var/datum/weakref/old_ref as anything in retry_at.Copy())
		if(!old_ref?.resolve())
			retry_at -= old_ref
	var/mob/living/best
	var/best_score = INFINITY
	var/list/seen = list()
	for(var/datum/weakref/body_ref as anything in npc_dead + player_dead)
		var/mob/living/body = body_ref?.resolve()
		if(QDELETED(body) || seen[body])
			continue
		seen[body] = TRUE
		var/datum/weakref/key = WEAKREF(body)
		var/mob/living/holder = claim_holder(key)
		if(holder && holder != worker)
			continue
		if(retry_at[key] > world.time)
			continue
		if(morgue_body_done(body))
			continue
		if(!body_free(body))
			retry_at[key] = world.time + OUTPOST_RECOVERY_BODY_RETRY
			continue
		var/turf/body_turf = get_turf(body)
		var/score = (from && body_turf?.z == from.z) ? get_dist(from, body_turf) : 500
		if(police && worker_sector != police.sector_of(body_turf))
			score += 200
		// Officers and traders first
		if(istype(body, /mob/living/carbon/human/npc/ambient_npc/outpost/police) || istype(body, OUTPOST_TRADER_MOB))
			score -= 1000
		if(score < best_score)
			best = body
			best_score = score
	return best

/// `worker` takes `body`; TRUE if nobody else had it. One worker per body.
/datum/outpost_recovery/proc/claim_body(mob/living/body, mob/living/worker)
	if(QDELETED(body) || QDELETED(worker))
		return FALSE
	var/datum/weakref/key = WEAKREF(body)
	var/mob/living/holder = claim_holder(key)
	if(holder && holder != worker)
		return FALSE
	claims[key] = WEAKREF(worker)
	return TRUE

/// `body` is nobody's again
/datum/outpost_recovery/proc/release_body(mob/living/body)
	if(!QDELETED(body))
		claims -= WEAKREF(body)
	// A body gone meanwhile leaves its claim behind under a dead ref
	for(var/datum/weakref/key as anything in claims.Copy())
		if(!key?.resolve())
			claims -= key

/**
 * The worker holding the claim `key`, or null if nobody does. A claim lapses when its worker is gone or down, or
 * is busy with another body (a finished job lets its body go itself, in finish()).
 */
/datum/outpost_recovery/proc/claim_holder(datum/weakref/key)
	var/datum/weakref/worker_ref = claims[key]
	if(!worker_ref)
		return null
	var/mob/living/carbon/human/npc/ambient_npc/worker = worker_ref.resolve()
	var/valid = !QDELETED(worker) && worker.stat == CONSCIOUS
	if(valid && istype(worker))
		var/datum/ambient_activity/recover_body/job = worker.activity
		if(istype(job) && job.body_ref && job.body_ref != key)
			valid = FALSE
	if(!valid)
		claims -= key
		return null
	return worker

// =========================================================================
// THE JOB
// =========================================================================

/**
 * One body, from where it lies to a tray or down a lift. Ends by itself when the body is delivered or given up;
 * a reaction (a fight, leaving) replaces it, and finish() lets the body go for the next worker.
 */
/datum/ambient_activity/recover_body
	name = "collecting the dead"
	/// The recovery it is for
	var/datum/outpost_recovery/recovery
	/// The body (the claim key)
	var/datum/weakref/body_ref
	/// The crew bag it is in, once bagged
	var/datum/weakref/bag_ref
	/// MORGUE_STAGE_*
	var/stage = MORGUE_STAGE_FETCH
	/// MORGUE_GOAL_* of the haul, and the turf it goes to
	var/goal_kind
	var/turf/goal
	/// The tray it is going to, if any
	var/datum/weakref/tray_ref
	/// An action on the body is running (begin_action())
	var/acting = FALSE
	var/acting_since = 0
	/// world.time this body is given up
	var/give_up_at = 0
	var/approach_tries = 0
	var/ride_tries = 0
	/// Hangar berth or lobby sector being ridden to via the hangar elevator
	var/ride_sector

/datum/ambient_activity/recover_body/setup()
	var/mob/living/carbon/human/npc/ambient_npc/outpost/recovery/morgue/worker = doer
	if(!istype(worker) || !isturf(worker.loc))
		return FALSE
	recovery = worker.morgue_recovery()
	if(!recovery)
		return FALSE
	var/mob/living/body = recovery.next_body(worker)
	if(!body || !recovery.claim_body(body, worker))
		return FALSE
	body_ref = WEAKREF(body)
	give_up_at = world.time + MORGUE_JOB_TIMEOUT
	var/datum/outpost_police/police = recovery.outpost?.police
	var/worker_sector = police?.sector_of(worker)
	var/body_sector = police?.sector_of(body)
	var/berth_jump = police && worker_sector != body_sector && (istype(worker_sector, /datum/outpost_berth) || istype(body_sector, /datum/outpost_berth))
	var/obj/structure/closet/body_bag/outpost_morgue/crew_bag = body.loc
	if(istype(crew_bag))
		// Bagged already (its worker went down): haul it on
		bag_ref = WEAKREF(crew_bag)
		stage = MORGUE_STAGE_HAUL
		if(!berth_jump)
			go_to(get_turf(crew_bag), 1)
	else
		doer.set_held(/obj/item/bodybag/outpost_morgue)
		if(!berth_jump)
			go_to(get_turf(body), 1)
	speak_of(body)
	return TRUE

/datum/ambient_activity/recover_body/Destroy()
	recovery = null
	goal = null
	ride_sector = null
	return ..()

/// A word on finding a body: the first of the wave, or an officer
/datum/ambient_activity/recover_body/proc/speak_of(mob/living/body)
	var/mob/living/carbon/human/npc/ambient_npc/outpost/recovery/morgue/worker = doer
	if(!istype(worker))
		return
	if(istype(body, /mob/living/carbon/human/npc/ambient_npc/outpost/police) && worker.reaction_ready("officer_body", 2 MINUTES))
		worker.speak_context(RECOVERY_LINE_OFFICER_BODY, body, force = TRUE)
		recovery.morgue_first_wave = worker.wave
		return
	if(recovery.morgue_first_wave != worker.wave)
		recovery.morgue_first_wave = worker.wave
		worker.speak_context(RECOVERY_LINE_FIRST_BODY, body, force = TRUE)

/datum/ambient_activity/recover_body/finish()
	if(!QDELETED(doer))
		var/obj/structure/closet/body_bag/outpost_morgue/bag = bag_ref?.resolve()
		if(bag && doer.pulling == bag)
			doer.stop_pulling()
		doer.set_held(null)
	release()
	return ..()

/datum/ambient_activity/recover_body/spot_unreachable()
	. = ..()
	give_up(TRUE)

/datum/ambient_activity/recover_body/shift_times(delay)
	. = ..()
	give_up_at = ambient_shifted(give_up_at, delay)
	acting_since = ambient_shifted(acting_since, delay)

/// The body, if it is still about
/datum/ambient_activity/recover_body/proc/body()
	var/mob/living/body = body_ref?.resolve()
	return QDELETED(body) ? null : body

/// The crew bag, if it is still about
/datum/ambient_activity/recover_body/proc/bag()
	var/obj/structure/closet/body_bag/outpost_morgue/bag = bag_ref?.resolve()
	return QDELETED(bag) ? null : bag

/// Lets the body go for whoever comes next
/datum/ambient_activity/recover_body/proc/release()
	if(!recovery || !body_ref)
		return
	var/datum/weakref/holder_ref = recovery.claims[body_ref]
	if(holder_ref?.resolve() == doer)
		recovery.claims -= body_ref
	recovery.release_body(null)

/// Gives the body up; with `retry`, nobody looks at it again for `retry_time`
/datum/ambient_activity/recover_body/proc/give_up(retry = FALSE, retry_time = OUTPOST_RECOVERY_BODY_RETRY)
	if(retry && recovery && body_ref)
		recovery.retry_at[body_ref] = world.time + retry_time
	// A crew bag that ended up empty goes
	var/obj/structure/closet/body_bag/outpost_morgue/bag = bag()
	if(bag && !length(bag.contents) && !bag.opened)
		qdel(bag)
	if(!QDELETED(doer) && bag && doer.pulling == bag)
		doer.stop_pulling()
	release()
	stage = MORGUE_STAGE_DONE
	go_to(null)

/// Runs `action` (a proc of this activity that may sleep) on its own; act() waits for it
/datum/ambient_activity/recover_body/proc/begin_action(action)
	acting = TRUE
	acting_since = world.time
	go_to(null)
	INVOKE_ASYNC(src, PROC_REF(run_action), action)

/datum/ambient_activity/recover_body/proc/run_action(action)
	call(src, action)()
	if(!QDELETED(src))
		acting = FALSE

/datum/ambient_activity/recover_body/act(seconds)
	if(acting)
		if(world.time - acting_since < MORGUE_ACTION_STUCK)
			return AMBIENT_STEP_CONTINUE
		acting = FALSE
	if(stage == MORGUE_STAGE_DONE)
		return AMBIENT_STEP_DONE
	if(world.time >= give_up_at)
		give_up(TRUE)
		return AMBIENT_STEP_DONE
	var/mob/living/body = body()
	// Gone (taken away, revived, or someone else's now)
	if(!body || body.stat != DEAD || recovery?.claim_holder(body_ref) != doer)
		give_up()
		return AMBIENT_STEP_DONE
	if(stage == MORGUE_STAGE_FETCH)
		return fetch_step(body)
	return haul_step(body)

// ----- fetch -----

/// Beside the body: bag it. In a hangar berth (or heading into one): ride the hangar elevator. Otherwise: walk up.
/datum/ambient_activity/recover_body/proc/fetch_step(mob/living/body)
	var/atom/target = morgue_bag_target(body)
	var/datum/outpost_police/police = recovery?.outpost?.ensure_police()
	var/worker_sector = police?.sector_of(doer)
	var/body_sector = police?.sector_of(target)
	if(police && worker_sector != body_sector && (istype(worker_sector, /datum/outpost_berth) || istype(body_sector, /datum/outpost_berth)))
		var/next_sector = istype(worker_sector, /datum/outpost_berth) ? POLICE_SECTOR_LOBBY : body_sector
		var/lift_sector = istype(worker_sector, /datum/outpost_berth) ? worker_sector : POLICE_SECTOR_LOBBY
		var/turf/lift = police.dispatch_nearest_lift_point(lift_sector, doer)
		if(!lift)
			give_up(TRUE)
			return AMBIENT_STEP_DONE
		if(doer.loc != lift)
			go_to(lift)
			return AMBIENT_STEP_MOVE
		ride_sector = next_sector
		begin_action(PROC_REF(ride_for_body))
		return AMBIENT_STEP_CONTINUE
	if(!doer.Adjacent(target))
		if(++approach_tries > MORGUE_APPROACH_TRIES)
			give_up(TRUE)
			return AMBIENT_STEP_DONE
		var/turf/stand = doer.free_tile_beside(target, 1, failed_spots, TRUE)
		if(stand)
			go_to(stand)
		else
			go_to(get_turf(target), 1)
		return AMBIENT_STEP_MOVE
	begin_action(PROC_REF(bag_body))
	return AMBIENT_STEP_CONTINUE

/// Rides the hangar elevator between the lobby alcove and a hangar berth to reach a body there. Sleeps.
/datum/ambient_activity/recover_body/proc/ride_for_body()
	var/mob/living/carbon/human/npc/ambient_npc/outpost/recovery/morgue/worker = doer
	var/datum/outpost_police/police = recovery?.outpost?.ensure_police()
	if(!istype(worker) || !police || !ride_sector)
		give_up(TRUE)
		return FALSE
	worker.morgue_radio(RECOVERY_LINE_LIFT)
	var/arrived = police.ride(worker, ride_sector)
	if(QDELETED(src))
		return FALSE
	ride_sector = null
	if(!arrived)
		if(++ride_tries >= MORGUE_RIDE_TRIES)
			give_up(TRUE)
		return FALSE
	ride_tries = 0
	return TRUE

/**
 * Bags the body: a do_after beside it, then the bag is unfolded on its tile and closed over it with the limbs
 * and organs lying near (3.1). The dead only (M32). Sleeps. TRUE if the body is in a crew bag.
 */
/datum/ambient_activity/recover_body/proc/bag_body()
	var/mob/living/carbon/human/npc/ambient_npc/outpost/recovery/morgue/worker = doer
	var/mob/living/body = body()
	if(!istype(worker) || !body || !recovery)
		return FALSE
	var/obj/structure/closet/body_bag/outpost_morgue/crew_bag = body.loc
	if(istype(crew_bag))
		bag_ref = WEAKREF(crew_bag)
		set_stage_haul()
		return TRUE
	if(!recovery.body_free(body) || !worker.Adjacent(morgue_bag_target(body)))
		give_up(TRUE)
		return FALSE
	// Someone else's bag: out of it first, as anyone would
	var/obj/structure/closet/body_bag/other_bag = body.loc
	if(istype(other_bag) && !other_bag.opened)
		other_bag.open(worker)
		if(!isturf(body.loc))
			give_up(TRUE)
			return FALSE
	if(!do_after(worker, MORGUE_BAG_TIME, body))
		if(!QDELETED(src))
			give_up(TRUE)
		return FALSE
	if(QDELETED(src) || QDELETED(worker) || QDELETED(body))
		return FALSE
	var/turf/body_turf = get_turf(body)
	if(body.stat != DEAD || !isturf(body.loc) || !recovery.body_free(body) || !worker.Adjacent(body))
		give_up(TRUE)
		return FALSE
	var/list/parts = gather_parts(body, body_turf)
	worker.set_held(null)
	var/obj/structure/closet/body_bag/outpost_morgue/bag = new(body_turf)
	bag.meant_for = WEAKREF(body)
	bag.allowed_parts = parts
	if(!bag.opened)
		bag.open(worker)
	bag.close(worker)
	if(QDELETED(bag) || body.loc != bag)
		// Too big for a bag, or something on the tile stopped it closing
		if(!QDELETED(bag))
			bag.open(worker)
			qdel(bag)
		give_up(TRUE, MORGUE_UNBAGGABLE_RETRY)
		return FALSE
	bag.add_fingerprint(worker)
	bag_ref = WEAKREF(bag)
	set_stage_haul()
	worker.morgue_radio(RECOVERY_LINE_BAGGED)
	return TRUE

/**
 * The limbs and organs to bag with `body`, moved onto its tile (weakrefs): an NPC's own lost parts (they leave
 * the round with it, and none holding a person's mind); for a player, any loose ones within reach (they go to
 * the tray and are never deleted).
 */
/datum/ambient_activity/recover_body/proc/gather_parts(mob/living/body, turf/body_turf)
	return morgue_gather_parts(body, body_turf)

/// gather_parts() for anyone: the crew's hands, or the unseen recovery (recovery_offscreen.dm)
/proc/morgue_gather_parts(mob/living/body, turf/body_turf)
	var/list/parts = list()
	var/list/candidates = list()
	if(morgue_npc_body(body))
		var/mob/living/carbon/human/npc/npc_body = body
		for(var/datum/weakref/remain_ref as anything in npc_body.npc_remains)
			var/obj/item/part = remain_ref?.resolve()
			if(!QDELETED(part) && !morgue_part_has_person(part))
				candidates += part
	else
		for(var/obj/item/part in range(OUTPOST_RECOVERY_LIMB_RANGE, body_turf))
			if(isbodypart(part) || isorgan(part))
				candidates += part
	for(var/obj/item/part as anything in candidates)
		if(!isturf(part.loc) || part.pulledby || part.anchored || get_dist(part, body_turf) > OUTPOST_RECOVERY_LIMB_RANGE)
			continue
		var/obj/item/bodypart/limb = part
		if(istype(limb) && limb.owner)
			continue
		var/obj/item/organ/organ = part
		if(istype(organ) && organ.owner)
			continue
		part.forceMove(body_turf)
		parts += WEAKREF(part)
	return parts

/// Bagged: off to the lift or the morgue
/datum/ambient_activity/recover_body/proc/set_stage_haul()
	stage = MORGUE_STAGE_HAUL
	goal = null
	goal_kind = null
	tray_ref = null

// ----- haul -----

/// Pulling the bag on to where it goes, and what happens there
/datum/ambient_activity/recover_body/proc/haul_step(mob/living/body)
	var/obj/structure/closet/body_bag/outpost_morgue/bag = bag()
	if(!bag || !isturf(bag.loc))
		give_up(TRUE)
		return AMBIENT_STEP_DONE
	// M32: never anyone alive down a lift or into a tray
	if(morgue_holds_life(bag))
		bag.open(doer)
		give_up(TRUE)
		return AMBIENT_STEP_DONE
	if(bag.opened)
		// Someone opened it: zipped up again if the body is still in it, otherwise it starts over
		if(get_turf(body) != get_turf(bag) || !doer.Adjacent(bag))
			give_up()
			return AMBIENT_STEP_DONE
		bag.close(doer)
		if(QDELETED(bag) || body.loc != bag)
			give_up(TRUE)
			return AMBIENT_STEP_DONE
	if(doer.pulling != bag)
		if(get_dist(doer, bag) > 1 || !doer.Adjacent(bag))
			go_to(get_turf(bag), 1)
			return AMBIENT_STEP_MOVE
		doer.start_pulling(bag, supress_message = TRUE)
		if(doer.pulling != bag)
			give_up(TRUE)
			return AMBIENT_STEP_DONE
	if(!goal || !goal_still_good())
		if(!pick_goal(body))
			give_up(TRUE)
			return AMBIENT_STEP_DONE
	if(doer.loc != goal)
		go_to(goal)
		return AMBIENT_STEP_MOVE
	switch(goal_kind)
		if(MORGUE_GOAL_LIFT_OUT)
			begin_action(PROC_REF(send_down))
		if(MORGUE_GOAL_RIDE)
			begin_action(PROC_REF(ride_to_lobby))
		if(MORGUE_GOAL_TRAY)
			begin_action(PROC_REF(put_in_tray))
		if(MORGUE_GOAL_FLOOR)
			leave_bag()
	return AMBIENT_STEP_CONTINUE

/// Whether the haul's goal still stands (the tray is still free)
/datum/ambient_activity/recover_body/proc/goal_still_good()
	if(goal_kind != MORGUE_GOAL_TRAY)
		return TRUE
	var/obj/structure/bodycontainer/morgue/tray = tray_ref?.resolve()
	return !QDELETED(tray) && morgue_tray_free(tray)

/**
 * Where the bag goes from here: an NPC's down the nearest lift of the sector the worker stands in; a player's
 * pulled on foot through the exit gate and lobby to a free morgue tray or the morgue floor (riding the hangar
 * elevator to the lobby first only when bagged down in a hangar berth). FALSE when there is nowhere.
 */
/datum/ambient_activity/recover_body/proc/pick_goal(mob/living/body)
	goal = null
	goal_kind = null
	tray_ref = null
	var/datum/outpost_police/police = recovery?.outpost?.ensure_police()
	if(!police)
		return FALSE
	var/sector = police.sector_of(doer)
	if(sector == POLICE_SECTOR_OUTSIDE)
		sector = null
	if(morgue_npc_body(body))
		goal = police.dispatch_nearest_lift_point(sector, doer)
		goal_kind = MORGUE_GOAL_LIFT_OUT
		return !!goal
	if(istype(sector, /datum/outpost_berth))
		goal = police.dispatch_nearest_elevator_point(sector, doer, doer)
		goal_kind = MORGUE_GOAL_RIDE
		return !!goal
	var/obj/structure/bodycontainer/morgue/tray = free_tray()
	if(tray)
		var/turf/stand = tray_stand(get_step(tray, tray.dir), tray)
		if(stand)
			tray_ref = WEAKREF(tray)
			goal = stand
			goal_kind = MORGUE_GOAL_TRAY
			return TRUE
	goal = recovery.morgue_turf || get_turf(doer)
	goal_kind = MORGUE_GOAL_FLOOR
	return TRUE

/// A tile beside `tray_turf` to stand on and slide a bag in from: not the tray's own tile nor the morgue's
/datum/ambient_activity/recover_body/proc/tray_stand(turf/tray_turf, obj/structure/bodycontainer/morgue/tray)
	var/turf/best
	var/best_distance = INFINITY
	for(var/turf/tile as anything in RANGE_TURFS(1, tray_turf))
		if(tile == tray_turf || tile == get_turf(tray) || !tile.Adjacent(tray_turf))
			continue
		if(!doer.standable(tile, failed_spots, TRUE))
			continue
		var/distance = get_dist(doer, tile)
		if(distance < best_distance)
			best = tile
			best_distance = distance
	return best

/// The nearest of the morgue room's trays with no body in it (junk only is fine: it is lifted off), or null
/datum/ambient_activity/recover_body/proc/free_tray()
	var/obj/structure/bodycontainer/morgue/best
	var/best_distance = INFINITY
	for(var/obj/structure/bodycontainer/morgue/tray as anything in recovery?.morgue_trays)
		if(QDELETED(tray) || !morgue_tray_free(tray))
			continue
		var/distance = get_dist(doer, tray)
		if(distance < best_distance)
			best = tray
			best_distance = distance
	return best

/**
 * Sends the bag down the lift with its NPC body (3.1): the call, the car's wait, and bag and body leave the
 * round. Only an NPC's body (morgue_npc_body()), and never anything alive (M32). Sleeps. TRUE if it went.
 */
/datum/ambient_activity/recover_body/proc/send_down()
	var/mob/living/carbon/human/npc/ambient_npc/outpost/recovery/morgue/worker = doer
	var/obj/structure/closet/body_bag/outpost_morgue/bag = bag()
	var/mob/living/body = body()
	if(!istype(worker) || !bag || !body || body.loc != bag || !morgue_npc_body(body))
		give_up(TRUE)
		return FALSE
	var/turf/start = get_turf(worker)
	worker.morgue_radio(RECOVERY_LINE_LIFT)
	playsound(start, 'sound/machines/chime.ogg', 50, TRUE)
	if(!do_after(worker, OUTPOST_ELEVATOR_TRAVEL_TIME, bag))
		if(!QDELETED(src))
			give_up(TRUE)
		return FALSE
	if(QDELETED(src) || QDELETED(worker) || QDELETED(bag) || QDELETED(body))
		return FALSE
	if(get_turf(worker) != start || get_dist(bag, worker) > 1 || bag.opened || body.loc != bag || !morgue_npc_body(body) || morgue_holds_life(bag))
		give_up(TRUE)
		return FALSE
	if(worker.pulling == bag)
		worker.stop_pulling()
	// Down the lift: bag, body and its parts leave the round
	for(var/atom/movable/inside as anything in bag.contents.Copy())
		// Never a person, nor a limb or organ with one in it: let it out where it is
		if((ismob(inside) && !morgue_npc_body(inside)) || (isitem(inside) && morgue_part_has_person(inside)))
			inside.forceMove(get_turf(bag))
			continue
		// Nor anyone in something it holds (abuse SF3)
		morgue_drop_persons(inside, get_turf(bag))
		qdel(inside)
	qdel(bag)
	playsound(start, 'sound/machines/ding.ogg', 50, TRUE)
	release()
	stage = MORGUE_STAGE_DONE
	return TRUE

/// Rides the lift to the lobby with the bag (police.ride() takes what they pull). Sleeps. TRUE on arrival.
/datum/ambient_activity/recover_body/proc/ride_to_lobby()
	var/mob/living/carbon/human/npc/ambient_npc/outpost/recovery/morgue/worker = doer
	var/obj/structure/closet/body_bag/outpost_morgue/bag = bag()
	var/datum/outpost_police/police = recovery?.outpost?.ensure_police()
	if(!istype(worker) || !bag || !police || morgue_holds_life(bag))
		give_up(TRUE)
		return FALSE
	worker.morgue_radio(RECOVERY_LINE_LIFT)
	var/arrived = police.ride(worker, POLICE_SECTOR_LOBBY)
	if(QDELETED(src))
		return FALSE
	goal = null
	if(!arrived || QDELETED(bag) || get_dist(bag, worker) > 1)
		if(++ride_tries >= MORGUE_RIDE_TRIES)
			give_up(TRUE)
		return FALSE
	ride_tries = 0
	return TRUE

/**
 * Slides the bag into its tray (the tray's own drag-onto and close) from beside the tray: the tray is pulled
 * out first, anything but a body lying on it is lifted off onto the floor (R9), nobody alive goes in (M32).
 * Sleeps. TRUE if the bag is in the tray.
 */
/datum/ambient_activity/recover_body/proc/put_in_tray()
	var/mob/living/carbon/human/npc/ambient_npc/outpost/recovery/morgue/worker = doer
	var/obj/structure/closet/body_bag/outpost_morgue/bag = bag()
	var/obj/structure/bodycontainer/morgue/tray = tray_ref?.resolve()
	if(!istype(worker) || !bag || QDELETED(tray) || !tray.connected || morgue_holds_life(bag))
		give_up(TRUE)
		return FALSE
	var/turf/tray_turf = get_step(tray, tray.dir)
	if(!worker.Adjacent(tray_turf) || get_dist(bag, worker) > 1 || !morgue_tray_free(tray))
		goal = null
		return FALSE
	if(tray.connected.loc == tray)
		tray.open()
		sleep(0.6 SECONDS)
		if(QDELETED(src) || QDELETED(worker) || QDELETED(bag) || QDELETED(tray) || !tray.connected)
			return FALSE
	tray_turf = get_turf(tray.connected)
	// Nobody may be on it; loose things and empty bags are lifted off
	if(locate(/mob/living) in tray_turf)
		goal = null
		return FALSE
	for(var/obj/item/junk in tray_turf)
		if(!junk.anchored)
			junk.forceMove(get_turf(worker))
	for(var/obj/structure/closet/body_bag/empty_bag in tray_turf)
		if(empty_bag != bag && !empty_bag.anchored && !(locate(/mob/living) in empty_bag))
			empty_bag.forceMove(get_turf(worker))
	if(!worker.Adjacent(tray_turf) || get_dist(bag, worker) > 1 || bag.opened || morgue_holds_life(bag))
		goal = null
		return FALSE
	if(worker.pulling == bag)
		worker.stop_pulling()
	tray.connected.mouse_drop_receive(bag, worker)
	if(bag.loc != tray_turf)
		goal = null
		return FALSE
	if(!tray.close())
		sleep(0.6 SECONDS)
		if(QDELETED(src) || QDELETED(tray))
			return FALSE
		tray.close()
	if(bag.loc != tray)
		goal = null
		return FALSE
	worker.morgue_radio(RECOVERY_LINE_TRAY)
	release()
	stage = MORGUE_STAGE_DONE
	return TRUE

/// Every tray is full (or the map has no morgue): the shut bag is left on the morgue floor, or where it is
/datum/ambient_activity/recover_body/proc/leave_bag()
	var/mob/living/carbon/human/npc/ambient_npc/outpost/recovery/morgue/worker = doer
	var/obj/structure/closet/body_bag/outpost_morgue/bag = bag()
	if(!bag)
		give_up(TRUE)
		return
	if(doer.pulling == bag)
		doer.stop_pulling()
	bag.delivered = TRUE
	if(istype(worker))
		worker.morgue_radio(RECOVERY_LINE_TRAY)
	release()
	stage = MORGUE_STAGE_DONE

#undef MORGUE_BAG_TIME
#undef MORGUE_JOB_TIMEOUT
#undef MORGUE_ACTION_STUCK
#undef MORGUE_RIDE_TRIES
#undef MORGUE_APPROACH_TRIES
#undef MORGUE_UNBAGGABLE_RETRY
#undef MORGUE_EMPTY_BAG_TIME
#undef MORGUE_IDLE_LEAVE
#undef MORGUE_STAGE_FETCH
#undef MORGUE_STAGE_HAUL
#undef MORGUE_STAGE_DONE
#undef MORGUE_GOAL_LIFT_OUT
#undef MORGUE_GOAL_RIDE
#undef MORGUE_GOAL_TRAY
#undef MORGUE_GOAL_FLOOR
