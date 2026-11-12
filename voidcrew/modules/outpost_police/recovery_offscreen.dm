/**
 * # Outpost recovery with nobody there (owner decision 32, playtest 1)
 *
 * With no player at the outpost, the recovery skips the crews and leaves the outpost the way they would have left
 * it, in one go: finish_unseen(). "At the outpost" is its concourse box and its hangar berths, docked ships in them
 * included (get_trader_outpost_for_turf()), not the z-level: the concourse is a turf reservation on a level it
 * shares with unrelated sites (outpost_security.dm says the same of its own checks). Observers and the dead don't
 * count; a living mob with a client anywhere at the outpost does.
 *
 * It waits RECOVERY_UNSEEN_WAIT (10 minutes, owner decision 40) of nobody being there, during which the crews stand
 * still, and for nobody wanted here to be holding the outpost in trouble (stars_present()), and for the port to be
 * open (a shut port sends nobody, seen or not). Then it runs in one call that never sleeps, so nobody can walk in
 * half way through it. The lost-wave ladder carries over.
 * Someone who comes back inside the wait finds the crews where they stood, carrying on from there (the ambient
 * system wakes them and the recovery's clocks move on, as before). So a player arriving never sees half of each.
 *
 * What it does, step for step what the crews end with:
 * - The crews of a wave still about go at once (nobody sees them leave).
 * - An NPC body that is free (body_free()) leaves the round with its own loose parts, as down a lift; anyone in
 *   something it carries is put on the floor first (morgue_drop_persons()). A body that is not free (buckled,
 *   aboard a ship) goes back to the base corpse sweep with finish_recovery(), as the acted version does.
 * - A player's body that is free is bagged in a crew bag with the loose parts near it and goes into a free tray of
 *   the morgue room; trays full, the shut bag is left on the morgue floor. Never deleted, never stripped.
 * - The outpost's people down in crit get a medic with the medic's kit (recovery_medic.dm treat_now()): the same
 *   items and procs, without the do_afters. A medic is made beside them for it and goes when done.
 * - Mess within reach of the patrol stops is washed with tg's own CLEAN_SCRUB (what the mop's stroke does), and
 *   litter there leaves with the trash bags. The whole box is looked at when the map has no stops.
 * - Every vacant counter and desk gets its replacement standing at it. The officers and residents come back by
 *   the ambient system's own fill-in-place for an empty outpost (settle_outpost()), which the recovery lets run once
 *   it is NORMAL again.
 */

/// Nobody has been at the outpost this long before the recovery finishes without them (owner decision 40)
#define RECOVERY_UNSEEN_WAIT (10 MINUTES)
/// A patient treated unseen is not treated unseen again for this long (a body the kit can't fix waits on tg)
#define RECOVERY_UNSEEN_PATIENT_RETRY (5 MINUTES)

/datum/outpost_recovery
	/// world.time nobody was first found at the outpost, or 0 while someone is
	var/unseen_since = 0
	/// How long nobody must be there before finish_unseen() (RECOVERY_UNSEEN_WAIT; the tests shorten it)
	var/unseen_wait = RECOVERY_UNSEEN_WAIT

/// Whether a living player with a client is at the outpost: its concourse box or its berths, docked ships included
/datum/outpost_recovery/proc/player_at_outpost()
	if(!outpost)
		return FALSE
	for(var/mob/living/player as anything in GLOB.alive_player_list)
		if(QDELETED(player) || !player.client || player.stat == DEAD)
			continue
		var/turf/where = get_turf(player)
		// OUTPOST FLOORS seam: someone up on a leased floor does not hold up the concourse (abuse A71)
		if(where && get_trader_outpost_for_turf(where) == outpost && !get_outpost_floor_for_turf(where))
			return TRUE
	return FALSE

/**
 * Whether the recovery should finish without its crews now: there is work, nobody has been at the outpost for
 * unseen_wait, the port is open, and nobody wanted here still holds it in trouble. Called once a second by tick().
 * While nobody is there the crews stand still (tick() pauses with the concourse empty); only this clock runs.
 */
/datum/outpost_recovery/proc/unseen_ready()
	if(state == OUTPOST_RECOVERY_NORMAL || QDELETED(outpost) || !outpost.loaded)
		unseen_since = 0
		return FALSE
	if(player_at_outpost())
		unseen_since = 0
		return FALSE
	if(!unseen_since)
		unseen_since = max(world.time, 1)
	if(world.time - unseen_since < unseen_wait)
		return FALSE
	// The port is shut after four lost waves: nobody comes, seen or not (review SF3)
	if(world.time < port_shut_until)
		return FALSE
	return !stars_present()

/**
 * The recovery, done with nobody there to see it (see the file's header). Never sleeps: nobody can arrive half
 * way. Leaves the outpost NORMAL, with the ambient system free to fill its people back in place.
 */
/datum/outpost_recovery/proc/finish_unseen()
	SHOULD_NOT_SLEEP(TRUE)
	if(QDELETED(src) || QDELETED(outpost))
		return
	unseen_since = 0
	paused_at = 0
	log_game("OUTPOST RECOVERY: [outpost.name] recovered with nobody there ([length(npc_bodies())] NPC bodies, [length(player_bodies())] player bodies).")
	// The crews go first, so nothing is still held or pulled
	for(var/datum/weakref/ref as anything in crew.Copy())
		var/mob/living/carbon/human/npc/ambient_npc/outpost/recovery/worker = ref.resolve()
		if(istype(worker) && !QDELETED(worker))
			if(worker.pulling)
				worker.stop_pulling()
			// A worker a player has taken over is theirs now: off the crew, never deleted (review S4)
			if(outpost_npc_played(worker, "unseen recovery"))
				crew -= ref
				continue
			worker.npc_drop_not_gear()
			worker.fade_out(instant = TRUE)
	claims.Cut()
	retry_at.Cut()
	patient_claims.Cut()
	prune_dead()
	for(var/mob/living/body as anything in npc_bodies())
		if(body_free(body))
			unseen_npc_body(body)
	for(var/mob/living/body as anything in player_bodies())
		if(body_free(body))
			unseen_player_body(body)
	unseen_treat()
	unseen_clean()
	unseen_staff()
	// The waves are over; whoever was not built yet is not coming
	wave_active = FALSE
	wave_morgue_left = 0
	wave_janitors_left = 0
	wave_medics_left = 0
	wave_escort_left = 0
	prune_dead()
	quiet_since = world.time
	// The lost-wave ladder is not wiped by leaving (review SF3): only a wave that does its job resets it
	var/kept_losses = waves_lost
	set_state(OUTPOST_RECOVERY_NORMAL)
	waves_lost = kept_losses
	var/datum/ambient_place/outpost/place = recovery_place()
	if(place)
		place.needs_settling = TRUE

/// An NPC body goes as down the lift: its loose parts with it, anyone in what it carries put on the floor first
/datum/outpost_recovery/proc/unseen_npc_body(mob/living/body)
	if(!morgue_npc_body(body))
		return
	var/turf/where = get_turf(body)
	// Someone else's bag is opened and left, as a crew member does
	var/obj/structure/closet/body_bag/other_bag = body.loc
	if(istype(other_bag) && !istype(other_bag, /obj/structure/closet/body_bag/outpost_morgue))
		other_bag.open(null, force = TRUE)
		if(!isturf(body.loc))
			return
	var/obj/structure/closet/body_bag/outpost_morgue/crew_bag = body.loc
	for(var/datum/weakref/part_ref as anything in morgue_gather_parts(body, where))
		var/obj/item/part = part_ref.resolve()
		if(QDELETED(part))
			continue
		morgue_drop_persons(part, where)
		qdel(part)
	morgue_drop_persons(body, where)
	npc_dead -= WEAKREF(body)
	qdel(body)
	if(istype(crew_bag) && !QDELETED(crew_bag))
		// Anything else in it that is a person stays; the bag goes with the body when nothing else is in it
		for(var/atom/movable/inside as anything in crew_bag.contents.Copy())
			if(ismob(inside) || morgue_part_has_person(inside))
				inside.forceMove(where)
			else
				qdel(inside)
		qdel(crew_bag)

/// A player's body is bagged and goes into a free tray, or onto the morgue floor in its shut bag
/datum/outpost_recovery/proc/unseen_player_body(mob/living/body)
	var/turf/where = get_turf(body)
	var/obj/structure/closet/body_bag/outpost_morgue/bag = body.loc
	if(!istype(bag))
		var/obj/structure/closet/body_bag/other_bag = body.loc
		if(istype(other_bag))
			other_bag.open(null, force = TRUE)
		if(!isturf(body.loc))
			return
		bag = new(where)
		bag.meant_for = WEAKREF(body)
		bag.allowed_parts = morgue_gather_parts(body, where)
		if(!bag.opened)
			bag.open(null, force = TRUE)
		bag.close()
		if(QDELETED(bag) || body.loc != bag)
			// Too big for a bag: left where it lies, as the crew leaves it
			if(!QDELETED(bag))
				bag.open(null, force = TRUE)
				qdel(bag)
			return
	if(bag.opened)
		bag.close()
		if(bag.opened)
			return
	for(var/obj/structure/bodycontainer/morgue/tray as anything in morgue_trays)
		if(!morgue_tray_free(tray))
			continue
		if(tray.connected.loc == tray)
			bag.forceMove(tray)
			tray.update_appearance()
			return
		bag.forceMove(get_turf(tray.connected))
		if(tray.close() && bag.loc == tray)
			return
		break
	bag.forceMove(morgue_turf || get_turf(bag))
	bag.delivered = TRUE

/// The outpost's people down in crit get a medic's kit, one or two medics' worth as a wave would bring
/datum/outpost_recovery/proc/unseen_treat()
	var/list/hurt = patients_due()
	if(!length(hurt))
		return
	var/medics = length(hurt) > RECOVERY_MEDIC_SECOND_AT ? 2 : 1
	var/per_medic = CEILING(length(hurt) / medics, 1)
	var/mob/living/carbon/human/npc/ambient_npc/outpost/recovery/medic/medic
	var/treated_by_this = 0
	for(var/mob/living/carbon/patient as anything in hurt)
		var/turf/beside = get_turf(patient)
		if(!medic || treated_by_this >= per_medic)
			if(medic)
				medic.fade_out(instant = TRUE)
			medic = new(beside)
			medic.outpost_recovery = src
			treated_by_this = 0
		else
			medic.forceMove(beside)
		medic.treat_now(patient)
		treated_by_this++
		patient_retry[WEAKREF(patient)] = world.time + RECOVERY_UNSEEN_PATIENT_RETRY
	if(medic && !QDELETED(medic))
		medic.fade_out(instant = TRUE)

/// Washes the mess and takes the litter within reach of the patrol stops (the whole box with no stops)
/datum/outpost_recovery/proc/unseen_clean()
	var/list/tiles = list()
	var/list/stops = work_stops()
	if(length(stops))
		for(var/turf/stop as anything in stops)
			for(var/turf/tile as anything in RANGE_TURFS(OUTPOST_RECOVERY_STOP_RANGE, stop))
				tiles[tile] = TRUE
	else
		var/list/bounds = bounty_outpost_bounds(outpost)
		if(bounds)
			for(var/turf/tile as anything in block(locate(bounds[1], bounds[2], bounds[5]), locate(bounds[3], bounds[4], bounds[5])))
				tiles[tile] = TRUE
	for(var/turf/tile as anything in tiles)
		if(length(recovery_mess_on(tile)))
			tile.wash(CLEAN_SCRUB)
		for(var/obj/item/litter as anything in recovery_litter_on(tile))
			qdel(litter)
	dirty_stops.Cut()
	for(var/turf/stop as anything in stops)
		mark_clean(stop)

/// Every vacant counter and desk gets its replacement, standing at it
/datum/outpost_recovery/proc/unseen_staff()
	register_posts()
	for(var/datum/outpost_recovery_post/post as anything in vacant_posts())
		if(!ispath(post.keeper_type, /mob/living) || !post.spot || QDELETED(post.shop))
			continue
		var/mob/living/replacement = new post.keeper_type(post.spot)
		post.replacement = WEAKREF(replacement)
		post.replacement_at = world.time
		post.away_since = 0
		post.shop.set_keeper(replacement)

#undef RECOVERY_UNSEEN_WAIT
#undef RECOVERY_UNSEEN_PATIENT_RETRY
