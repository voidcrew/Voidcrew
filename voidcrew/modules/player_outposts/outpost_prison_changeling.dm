/**
 * # The changeling experiment
 *
 * The researcher's specimen (outpost_prison_experiments.dm): slipped into a prisoner's food, it
 * hatches inside them. Numbers are in voidcrew/_DEFINES/outpost_prison_changeling.dm.
 *
 * 1. Incubating. Eating the specimen starts a clock of a minute and a half to two minutes
 *    (outpost_changeling_infect()). The host complains of stomach pain after 30 seconds and coughs
 *    and retches after a minute. 22 seconds before the burst they go to their bunk and lie down,
 *    groaning, their belly heaving. They are down now and can be dragged. Their sentence is held so
 *    they are not released meanwhile, and a dead host is not collected before the burst.
 * 2. The burst. The host bursts in a spray of gore and a headslug drops out. It heads for the
 *    nearest vent and squeezes in over two seconds; any damage stops it and it tries again. The
 *    data fee is paid now (experiment_creature_appeared()). A host killed early bursts anyway,
 *    three seconds later. A host out of the cell block pauses the clock; a minute out and the
 *    specimen is lost.
 * 3. The vents. The slug moves between the wing's sealed vents (outpost_prison_vents.dm), never
 *    back to the one it just left, and gets louder as it grows: rattles every few seconds, then
 *    clangs, slime and prisoners pointing at the vent, then banging, dented covers, flickering
 *    lights and prisoners begging to be locked in. Wrenching the vent it is in forces it out; it
 *    stays a slug and fights (killing it pays the containment bonus). Left alone, a minute and a
 *    half after it went in, one vent strains for five seconds and the horror
 *    (outpost_prison_horror.dm) comes out. It never comes out of a vent in a bolted cell while
 *    there is another.
 * 4. The horror, until it dies for good. At 0 health it goes down regenerating and gets up again
 *    unless its body is destroyed or put out into open space off the outpost (in_open_space());
 *    the first time, the outpost is told it is down and still moving (horror_collapsed()).
 *    Prisoners shout when it gets back up.
 *
 * Every clock pauses while no member of the wing is home (crew_home()), except a dead host's last
 * three seconds. When it ends, prisoners who saw a death lose mood, each prisoner the creature
 * killed adds tension, and Kessler refits the vent covers.
 *
 * The event drives itself on SSprocessing, once a second. Tests stop that and call tick().
 * Payments go through S4a's API (outpost_prison_experiments.dm): experiment_creature_appeared() for
 * the headslug at the burst (the fee) and again for the horror, each before the host or the slug
 * is gone; the creature's death reports itself (the containment bonus); experiment_failed() when
 * the host is lost. With S4a in, its experiment_paused() decides when the clocks wait, and S4a
 * deletes this event when its experiment ends.
 */

/// What an activity's tick() wants next (outpost_prison_routine.dm)
#define ACTIVITY_CONTINUE 0
#define ACTIVITY_DONE 1

/// Trait source for the host going down on their bunk
#define CHANGELING_HOST_TRAIT "outpost_changeling_host"
/// Trait source for the slug waiting in a vent, and for squeezing into one
#define HEADSLUG_VENT_TRAIT "outpost_headslug_vent"
/// Blackboard key of the vent a headslug is heading for
#define BB_OUTPOST_HEADSLUG_VENT "BB_outpost_headslug_vent"

// ===== S4a's API, until it lands =====
// The experiments core (outpost_prison_experiments.dm) defines OUTPOST_EXPERIMENT_API in its
// defines file and these procs for real. Until then they do nothing, so the changeling runs alone.
#ifndef OUTPOST_EXPERIMENT_API
/// Pays the experiment's data fee, once; tracks the creature, and pays the containment bonus when it dies
/datum/outpost_prison/proc/experiment_creature_appeared(mob/living/creature, form)
	return
/// The experiment failed: no fee
/datum/outpost_prison/proc/experiment_failed(reason)
	return
#endif

/datum/outpost_prison
	/// The changeling experiment under way in the wing, or the last one, finished
	var/datum/outpost_changeling_event/active_changeling

/**
 * Starts the specimen hatching inside `host`, a prisoner of `prison`. S4a's start_experiment()
 * calls this once the host has eaten the tainted food. Returns the event, or null if it cannot
 * start (a dead host, someone else's prisoner, or a changeling already running in the wing).
 */
/proc/outpost_changeling_infect(mob/living/basic/outpost_prisoner/host, datum/outpost_prison/prison)
	if(QDELETED(host) || QDELETED(prison) || host.stat == DEAD || host.prison != prison)
		return null
	if(prison.active_changeling && prison.active_changeling.stage != "done")
		return null
	return new /datum/outpost_changeling_event(host, prison)

// ===== THE EVENT =====

/datum/outpost_changeling_event
	/// "incubating", "burst" (the slug is out, before or instead of the vents), "vents", "horror" or "done"
	var/stage = "incubating"
	/// Seconds on the running clock: to the burst while incubating, to the horror while in the vents,
	/// else null. A paused clock keeps its value.
	var/time_left
	/// Why it ended, once it has
	var/end_reason
	var/datum/outpost_prison/prison
	var/mob/living/basic/outpost_prisoner/host
	var/mob/living/basic/headslug/beakless/outpost/slug
	var/mob/living/basic/outpost_experiment/horror/horror
	/// The vent the slug is in, or the one that is giving way
	var/obj/structure/outpost_kessler_vent/vent
	/// Whether it drives itself on SSprocessing; tests turn this off and call tick()
	var/self_ticking = TRUE

	/// Incubation: its length, and how far along it is
	var/incubation_total = 0
	var/incubation_elapsed = 0
	var/said_pain = FALSE
	var/said_retch = FALSE
	/// Seconds to the host's next small complaint
	var/tell_left = 0
	/// The host is heading for their bunk, and has gone down
	var/bed_phase = FALSE
	var/host_down = FALSE
	/// Seconds left to reach the bunk, and to the next heave
	var/bed_walk_left = 0
	var/heave_left = 0
	/// Seconds the host has been out of the cell block
	var/host_outside = 0
	/// Seconds until a host who died early bursts, while they are dead and whole
	var/early_burst_left = 0

	/// Seconds the slug has left to find a vent, after the burst
	var/seek_left = 0
	/// The slug was wrenched out of a vent: it stays a slug and fights
	var/wrenched_out = FALSE
	/// Seconds in the vents so far, and to the next hop, rattle and remark
	var/vent_elapsed = 0
	var/dwell_left = 0
	var/rattle_left = 0
	var/remark_left = 0
	/// The prisoners have been sent to their cells
	var/panicked = FALSE
	/// The emergence vent is giving way, and the seconds it has left
	var/straining = FALSE
	var/strain_left = 0
	/// The horror has left the wing, and the outpost has been told
	var/breach_announced = FALSE
	/// The horror has gone down regenerating once, and the outpost has been told
	var/regen_announced = FALSE

	/// Deaths seen so far (REF = TRUE), prisoners the creature killed, and who saw a death (weakrefs)
	var/list/counted_deaths = list()
	var/kills = 0
	var/list/witnesses = list()
	/// Prisoners whose deaths are watched while a creature is loose
	var/list/watched_prisoners = list()

/datum/outpost_changeling_event/New(mob/living/basic/outpost_prisoner/new_host, datum/outpost_prison/new_prison)
	. = ..()
	prison = new_prison
	prison.active_changeling = src
	RegisterSignal(prison, COMSIG_QDELETING, PROC_REF(on_prison_deleted))
	incubation_total = rand(OUTPOST_CHANGELING_INCUBATION_MIN, OUTPOST_CHANGELING_INCUBATION_MAX)
	tell_left = rand(20, 35)
	link_host(new_host)
#ifndef OUTPOST_EXPERIMENT_API
	// S4a's start_experiment() logs this itself.
	prison.add_log("[host.real_name] ate the Kessler specimen.")
#endif
	log_game("PLAYER OUTPOST PRISON: the changeling specimen is incubating in [key_name(host)] at '[prison.outpost?.name]', [incubation_total] s")
	update_time_left()
	START_PROCESSING(SSprocessing, src)

/datum/outpost_changeling_event/Destroy()
	// Whoever deletes the event (S4a's experiment, when it fails) sees to the creatures.
	end_event("deleted")
	STOP_PROCESSING(SSprocessing, src)
	if(prison)
		UnregisterSignal(prison, COMSIG_QDELETING)
		if(prison.active_changeling == src)
			prison.active_changeling = null
	prison = null
	return ..()

/datum/outpost_changeling_event/process(seconds_per_tick)
	if(!self_ticking)
		return
	tick(seconds_per_tick)

/// Stops the event driving itself, so a test can drive it with tick()
/datum/outpost_changeling_event/proc/stop_self_ticking()
	self_ticking = FALSE
	STOP_PROCESSING(SSprocessing, src)

/// Advances the event by `seconds`. The clocks wait while no member of the wing is home.
/datum/outpost_changeling_event/proc/tick(seconds)
	if(stage == "done")
		return
	if(QDELETED(prison) || QDELETED(prison.outpost))
		end_event("the prison is gone", remove_creatures = TRUE)
		return
#ifdef OUTPOST_EXPERIMENT_API
	var/home = !prison.experiment_paused()
#else
	var/home = prison.crew_home()
#endif
	switch(stage)
		if("incubating")
			incubation_tick(seconds, home)
		if("burst")
			burst_tick(seconds, home)
		if("vents")
			vents_tick(seconds, home)
		if("horror")
			horror_tick(seconds, home)
	update_time_left()

/datum/outpost_changeling_event/proc/update_time_left()
	switch(stage)
		if("incubating")
			time_left = max(0, round(incubation_total - incubation_elapsed))
		if("vents")
			time_left = max(0, round(OUTPOST_CHANGELING_VENT_TIME - vent_elapsed))
		else
			time_left = null

/// The slug or the horror, whichever is about, or null
/datum/outpost_changeling_event/proc/current_creature()
	if(!QDELETED(horror))
		return horror
	if(!QDELETED(slug))
		return slug
	return null

/// Whether a slug or a horror is loose: hatched, and not dead or taken yet
/datum/outpost_changeling_event/proc/creature_loose()
	if(stage != "burst" && stage != "vents" && stage != "horror")
		return FALSE
	var/mob/living/creature = current_creature()
	return creature && creature.stat != DEAD

/**
 * An admin moves the event on: "burst" bursts an incubating host now; "horror" brings the horror
 * out now, from the slug's vent or wherever the slug is (bursting the host first if need be);
 * "done" ends it and Kessler takes whatever hatched. Returns TRUE if it did something.
 */
/datum/outpost_changeling_event/proc/force_stage(new_stage)
	switch(new_stage)
		if("burst")
			if(stage != "incubating")
				return FALSE
			return burst()
		if("horror")
			if(stage == "incubating" && !burst())
				return FALSE
			if(stage != "burst" && stage != "vents")
				return FALSE
			if(QDELETED(slug))
				return FALSE
			return emerge()
		if("done")
#ifdef OUTPOST_EXPERIMENT_API
			// The experiment is S4a's to call off: it takes the creatures and deletes this event.
			if(prison?.changeling_event() == src)
				prison.experiment_end_admin()
				return TRUE
#endif
			return end_event("ended by an admin", remove_creatures = TRUE)
	return FALSE

// ===== THE HOST =====

/datum/outpost_changeling_event/proc/link_host(mob/living/basic/outpost_prisoner/new_host)
	host = new_host
	host.experiment_subject = TRUE
	host.update_bubble()
	RegisterSignal(host, COMSIG_LIVING_DEATH, PROC_REF(on_host_death))
	RegisterSignal(host, COMSIG_QDELETING, PROC_REF(on_host_deleted))

/// Lets go of the host: signals off and back on their feet. `cured` also ends their part in the experiment.
/datum/outpost_changeling_event/proc/release_host(cured = FALSE)
	if(!host)
		return
	var/mob/living/basic/outpost_prisoner/was_host = host
	host = null
	UnregisterSignal(was_host, list(COMSIG_LIVING_DEATH, COMSIG_QDELETING))
	was_host.remove_traits(list(TRAIT_FLOORED, TRAIT_INCAPACITATED, TRAIT_IMMOBILIZED), CHANGELING_HOST_TRAIT)
	if(istype(was_host.activity, /datum/prisoner_activity/changeling_bed))
		was_host.end_activity()
	if(cured && !QDELETED(was_host))
		was_host.experiment_subject = FALSE
		was_host.update_bubble()

/datum/outpost_changeling_event/proc/incubation_tick(seconds, home)
	if(QDELETED(host))
		lose_specimen("the host is gone")
		return
	// Never released or sent home while it grows.
	host.sentence_left = max(host.sentence_left, OUTPOST_CHANGELING_HOST_SENTENCE_HOLD)
	// Out of the cell block, dead or alive, it waits: it never hatches aboard a ship or anywhere else.
	// The clock that loses it counts only while the crew is home. Not `home`: with S4a that is
	// also false while the host is out of the cell block.
	if(!prison.in_cell_block(host))
		if(prison.crew_home())
			host_outside += seconds
		if(host_outside >= OUTPOST_CHANGELING_HOST_LOST_AFTER)
			lose_specimen("the host was taken out of the cell block")
		return
	host_outside = 0
	if(early_burst_left > 0)
		early_burst_left -= seconds
		if(early_burst_left <= 0)
			burst()
		return
	if(host.stat == DEAD)
		early_burst_left = OUTPOST_CHANGELING_EARLY_BURST
		return
	if(!home)
		return
	incubation_elapsed += seconds
	host_tells(seconds)
	if(!bed_phase && incubation_elapsed >= incubation_total - OUTPOST_CHANGELING_BED_WARNING)
		start_bed_phase()
	if(bed_phase)
		bed_tick(seconds)
	if(incubation_elapsed >= incubation_total)
		burst()

/// The host's complaints: stomach pain after OUTPOST_CHANGELING_TELL_PAIN, coughing and retching after OUTPOST_CHANGELING_TELL_RETCH, and small signs between
/datum/outpost_changeling_event/proc/host_tells(seconds)
	if(host.stat != CONSCIOUS || host_down)
		return
	if(!said_pain && incubation_elapsed >= OUTPOST_CHANGELING_TELL_PAIN)
		said_pain = TRUE
		INVOKE_ASYNC(host, TYPE_PROC_REF(/atom, manual_emote), "rubs [host.p_their()] stomach and winces.")
		INVOKE_ASYNC(host, TYPE_PROC_REF(/mob/living/basic/outpost_prisoner, say_context), "experiment_dose")
		prison.add_log("[host.real_name] complains of stomach pain.")
		return
	if(!said_retch && incubation_elapsed >= OUTPOST_CHANGELING_TELL_RETCH)
		said_retch = TRUE
		playsound(host, 'sound/effects/splat.ogg', 20, TRUE)
		INVOKE_ASYNC(host, TYPE_PROC_REF(/atom, manual_emote), "doubles over, coughing wetly and clutching [host.p_their()] belly.")
		return
	if(!said_pain)
		return
	tell_left -= seconds
	if(tell_left > 0)
		return
	tell_left = rand(20, 35)
	var/list/tells = said_retch \
		? list("retches.", "coughs wetly.", "clutches [host.p_their()] belly.", "sways on [host.p_their()] feet.") \
		: list("winces.", "rubs [host.p_their()] stomach.", "burps, and looks worried about it.")
	INVOKE_ASYNC(host, TYPE_PROC_REF(/atom, manual_emote), pick(tells))

/// OUTPOST_CHANGELING_BED_WARNING seconds to go: the host heads for their bunk
/datum/outpost_changeling_event/proc/start_bed_phase()
	bed_phase = TRUE
	bed_walk_left = OUTPOST_CHANGELING_BED_WALK
	heave_left = 2
	prison.add_log("[host.real_name] went to lie down, clutching [host.p_their()] belly.")
	INVOKE_ASYNC(host, TYPE_PROC_REF(/atom, manual_emote), "clutches [host.p_their()] belly and staggers toward [host.p_their()] bunk.")
	if(host.stat != CONSCIOUS || host.can_be_dragged())
		host_lie_down()
		return
	var/datum/prisoner_activity/changeling_bed/to_bed = new(host)
	if(to_bed.setup())
		host.start_activity(to_bed)
	else
		qdel(to_bed)
		host_lie_down()

/datum/outpost_changeling_event/proc/bed_tick(seconds)
	if(!host_down)
		bed_walk_left -= seconds
		var/obj/structure/bed/bunk = host.cell?.bed()
		if(bed_walk_left <= 0 || (bunk && bunk.loc == host.loc))
			host_lie_down()
		return
	heave_left -= seconds
	if(heave_left > 0)
		return
	heave_left = rand(3, 5)
	heave()

/// The host goes down, on their bunk if they got there: groaning, and draggable
/datum/outpost_changeling_event/proc/host_lie_down()
	if(host_down || QDELETED(host))
		return
	host_down = TRUE
	host.add_traits(list(TRAIT_FLOORED, TRAIT_INCAPACITATED, TRAIT_IMMOBILIZED), CHANGELING_HOST_TRAIT)
	host.visible_message(span_warning("[host] curls up, groaning, arms wrapped around [host.p_their()] belly."))

/// The host's belly heaves; now and then a neighbour notices
/datum/outpost_changeling_event/proc/heave()
	host.Shake(1, 0, 0.6 SECONDS)
	playsound(host, 'sound/effects/meatslap.ogg', 15, TRUE, -2)
	if(prob(50))
		host.visible_message(span_warning("Something moves under [host]'s jumpsuit. [host.p_Their()] belly heaves."))
	else
		INVOKE_ASYNC(host, TYPE_PROC_REF(/atom, manual_emote), pick("groans.", "moans.", "whimpers."))
	if(!prob(30))
		return
	for(var/mob/living/basic/outpost_prisoner/neighbour in shuffle(prison.prisoners))
		if(neighbour == host || neighbour.stat != CONSCIOUS || neighbour.phase != PRISONER_PRESENT || !(host in view(6, neighbour)))
			continue
		INVOKE_ASYNC(neighbour, TYPE_PROC_REF(/atom, manual_emote), pick("stares at [host].", "backs away from [host].", "covers [neighbour.p_their()] mouth.", "calls out to [host]. No answer."))
		break

/datum/outpost_changeling_event/proc/on_host_death(datum/source, gibbed)
	SIGNAL_HANDLER
	if(stage != "incubating" || gibbed || early_burst_left > 0)
		return
	early_burst_left = OUTPOST_CHANGELING_EARLY_BURST
	prison?.add_log("[host?.real_name || "The host"] died with the specimen still inside.")
	host?.visible_message(span_boldwarning("[host]'s body keeps moving after [host.p_they()] [host.p_have()] stopped."))

/datum/outpost_changeling_event/proc/on_host_deleted(datum/source)
	SIGNAL_HANDLER
	if(stage != "incubating")
		host = null
		return
	INVOKE_ASYNC(src, PROC_REF(lose_specimen), "the host is gone")

/// The specimen dies with nothing hatched: the experiment has failed
/datum/outpost_changeling_event/proc/lose_specimen(reason)
	if(stage != "incubating")
		return FALSE
	var/datum/outpost_prison/held = prison
	prison.add_log("The Kessler specimen was lost: [reason].")
	end_event(reason)
	held?.experiment_failed("subject lost")
	return TRUE

// ===== THE BURST =====

/// The host bursts and the headslug drops out. Pays the data fee.
/datum/outpost_changeling_event/proc/burst()
	if(stage != "incubating")
		return FALSE
	var/turf/spot = get_turf(host)
	if(!spot)
		lose_specimen("the host is gone")
		return FALSE
	var/mob/living/basic/outpost_prisoner/victim = host
	release_host()
	stage = "burst"
	early_burst_left = 0
	seek_left = OUTPOST_HEADSLUG_SEEK_TIME
	prison.add_log("[victim.real_name] burst open. Something crawled out.")
	log_game("PLAYER OUTPOST PRISON: the changeling specimen burst out of [key_name(victim)] at [AREACOORD(spot)]")
	spot.visible_message(span_boldwarning("[victim] convulses and bursts open! Something small and wet drops out of the mess."))
	playsound(spot, 'sound/effects/splat.ogg', 80, TRUE, 4)
	playsound(spot, 'sound/effects/magic/demon_consume.ogg', 60, TRUE, 2)
	note_death(victim, FALSE)
	// The slug first, and reported, while the host is still there to have hatched it.
	slug = new(spot)
	link_slug()
	prison.experiment_creature_appeared(slug, "headslug")
	spread_gore(spot)
	flicker_lights_near(spot, 3)
	scream_near(spot)
	victim.gib()
#ifndef OUTPOST_EXPERIMENT_API
	watch_prisoners()
#endif
	prison.announce("Prison wing: the specimen has hatched!", SHIP_NOTIFY_DANGER)
	update_time_left()
	return TRUE

/// Blood and worse, a few tiles around the burst
/datum/outpost_changeling_event/proc/spread_gore(turf/spot)
	new /obj/effect/decal/cleanable/blood/gibs(spot)
	var/list/around = list()
	for(var/turf/open/near in orange(1, spot))
		if(near.loc == spot.loc && !near.is_blocked_turf(TRUE))
			around += near
	for(var/i in 1 to min(3, length(around)))
		var/turf/splash = pick_n_take(around)
		new /obj/effect/decal/cleanable/blood/splatter(splash)

/datum/outpost_changeling_event/proc/flicker_lights_near(atom/center, range)
	for(var/obj/machinery/light/fixture in range(range, center))
		outpost_changeling_flicker(fixture, 3)

/**
 * Flickers a light `times` times, like tg's flicker(), but on timers that check the light is still
 * there at every step: tg's sleeps in a loop and runtimes on a light deleted mid-flicker.
 */
/proc/outpost_changeling_flicker(obj/machinery/light/fixture, times)
	if(QDELETED(fixture) || fixture.flickering || !fixture.on || fixture.status != LIGHT_OK)
		return FALSE
	fixture.flickering = TRUE
	outpost_changeling_flicker_step(WEAKREF(fixture), times * 2)
	return TRUE

/proc/outpost_changeling_flicker_step(datum/weakref/fixture_ref, steps_left)
	var/obj/machinery/light/fixture = fixture_ref?.resolve()
	if(QDELETED(fixture) || !isturf(fixture.loc))
		return
	if(steps_left <= 0 || fixture.status != LIGHT_OK || !fixture.has_power())
		fixture.on = fixture.status == LIGHT_OK && fixture.has_power()
		fixture.update(FALSE)
		fixture.flickering = FALSE
		return
	fixture.on = !fixture.on
	fixture.update(FALSE)
	addtimer(CALLBACK(GLOBAL_PROC, GLOBAL_PROC_REF(outpost_changeling_flicker_step), fixture_ref, steps_left - 1), rand(5, 15))

/// Prisoners who saw it scream
/datum/outpost_changeling_event/proc/scream_near(turf/spot)
	var/screamed = 0
	for(var/mob/living/basic/outpost_prisoner/witness in view(7, spot))
		if(witness.stat != CONSCIOUS || witness.phase != PRISONER_PRESENT || witness.can_be_dragged())
			continue
		INVOKE_ASYNC(witness, TYPE_PROC_REF(/atom, manual_emote), pick("screams!", "shrieks and scrambles back!", "yells in horror!"))
		if(++screamed >= 3)
			break

// ===== THE SLUG =====

/datum/outpost_changeling_event/proc/link_slug()
	slug.event = src
	RegisterSignal(slug, COMSIG_LIVING_DEATH, PROC_REF(on_slug_death))
	RegisterSignal(slug, COMSIG_QDELETING, PROC_REF(on_slug_deleted))

/datum/outpost_changeling_event/proc/unlink_slug()
	if(!slug)
		return
	UnregisterSignal(slug, list(COMSIG_LIVING_DEATH, COMSIG_QDELETING))
	if(slug.event == src)
		slug.event = null

/datum/outpost_changeling_event/proc/burst_tick(seconds, home)
	if(QDELETED(slug) || slug.stat == DEAD)
		return
#ifndef OUTPOST_EXPERIMENT_API
	leash_check(slug)
#endif
	if(wrenched_out || slug.mode != "seek" || !home)
		return
	seek_left -= seconds
	if(seek_left <= 0)
		// No vent it could reach: it gives up on them and fights where it is.
		slug.start_fighting()

/// The wing's sealed vents with their covers on, but for `except`
/datum/outpost_changeling_event/proc/closed_vents(obj/structure/outpost_kessler_vent/except)
	var/list/found = list()
	if(!prison?.wing)
		return found
	for(var/obj/structure/outpost_kessler_vent/candidate as anything in GLOB.outpost_kessler_vents)
		if(candidate == except || candidate.open || QDELETED(candidate))
			continue
		// A vent a rebuild walled over is no way out.
		if(get_area(candidate) != prison.wing || isclosedturf(get_turf(candidate)))
			continue
		found += candidate
	return found

/// The slug made it into a vent. Returns TRUE if it is in.
/datum/outpost_changeling_event/proc/slug_reached_vent(mob/living/basic/headslug/beakless/outpost/arrived, obj/structure/outpost_kessler_vent/into)
	if(stage == "done" || arrived != slug || QDELETED(into) || into.open || wrenched_out)
		return FALSE
	into.take_occupant(slug)
	vent = into
	slug.enter_vent_state()
	if(stage != "vents")
		stage = "vents"
		prison.add_log("The specimen crawled into the vents.")
	dwell_left = roll_dwell()
	rattle_left = OUTPOST_CHANGELING_RATTLE_GAP
	remark_left = OUTPOST_CHANGELING_REMARK_GAP
	into.clang(noise_level())
	update_time_left()
	return TRUE

/// Someone wrenched the slug out of its vent: it stays a slug now, and fights
/datum/outpost_changeling_event/proc/slug_wrenched_out(mob/living/basic/headslug/beakless/outpost/pulled, mob/living/user)
	if(stage == "done" || pulled != slug)
		return
	vent = null
	straining = FALSE
	wrenched_out = TRUE
	stage = "burst"
	prison.add_log("[user ? user.real_name : "Someone"] wrenched the specimen out of a vent.")
	update_time_left()

/// The vent the slug was in is gone: it drops out where it is and fights
/datum/outpost_changeling_event/proc/slug_lost_vent(mob/living/basic/headslug/beakless/outpost/dropped, obj/structure/outpost_kessler_vent/lost)
	if(stage == "done" || dropped != slug)
		return
	if(vent == lost)
		vent = null
	straining = FALSE
	stage = "burst"
	slug.start_fighting()
	update_time_left()

/// How loud the vents are: 1 until OUTPOST_CHANGELING_NOISE_LOUDER, 2 until OUTPOST_CHANGELING_NOISE_VIOLENT, 3 after
/datum/outpost_changeling_event/proc/noise_level()
	if(vent_elapsed < OUTPOST_CHANGELING_NOISE_LOUDER)
		return 1
	if(vent_elapsed < OUTPOST_CHANGELING_NOISE_VIOLENT)
		return 2
	return 3

/// Seconds the slug stays in a vent before moving on; shorter as it grows
/datum/outpost_changeling_event/proc/roll_dwell()
	switch(noise_level())
		if(1)
			return rand(15, 22)
		if(2)
			return rand(12, 18)
	return rand(9, 14)

/datum/outpost_changeling_event/proc/vents_tick(seconds, home)
	if(QDELETED(slug) || slug.stat == DEAD)
		return
	if(QDELETED(vent) || slug.loc != vent)
		// Out of the vents by some other road: loose, and fighting.
		vent = null
		straining = FALSE
		stage = "burst"
		slug.start_fighting()
		return
	if(!home)
		return
	vent_elapsed += seconds
	if(straining)
		strain_left -= seconds
		if(strain_left <= 0)
			emerge()
			return
		vent.strain_pulse()
		return
	if(vent_elapsed >= OUTPOST_CHANGELING_VENT_TIME - OUTPOST_CHANGELING_STRAIN_TIME)
		start_strain()
		return
	var/level = noise_level()
	rattle_left -= seconds
	if(rattle_left <= 0)
		rattle_left += OUTPOST_CHANGELING_RATTLE_GAP
		vent.rattle(level)
		if(level >= 2 && prob(35))
			drip(vent)
		if(level >= 3)
			vent.dent()
			flicker_lights_near(vent, 4)
	// The noises have their own flee: a slug in the vents frightens nobody by sight (outpost_prison_panic.dm).
	if(level >= 3 && !panicked)
		panic_prisoners()
	remark_left -= seconds
	if(remark_left <= 0)
		remark_left = OUTPOST_CHANGELING_REMARK_GAP + rand(0, 6)
		prisoner_remark(level)
	dwell_left -= seconds
	if(dwell_left <= 0)
		hop()

/// Slime from the occupied vent
/datum/outpost_changeling_event/proc/drip(obj/structure/outpost_kessler_vent/source)
	var/turf/spot = get_turf(source)
	if(!isopenturf(spot) || (locate(/obj/effect/decal/cleanable/blood/xeno) in spot))
		return
	new /obj/effect/decal/cleanable/blood/xeno(spot)
	playsound(spot, 'sound/effects/splat.ogg', 20, TRUE, -2)

/// A prisoner who heard it says so: "something's in the walls" at noise level 2, "lock me in" at 3
/datum/outpost_changeling_event/proc/prisoner_remark(level)
	if(level < 2 || !prison.wing_can_speak())
		return FALSE
	var/context = level >= 3 ? "creature_panic" : "vent_noise"
	for(var/mob/living/basic/outpost_prisoner/listener in shuffle(prison.prisoners))
		if(listener.stat != CONSCIOUS || listener.phase != PRISONER_PRESENT || listener.can_be_dragged() || !listener.ai_running())
			continue
		if(get_dist(listener, vent) > 7)
			continue
		prison.note_speech()
		INVOKE_ASYNC(listener, TYPE_PROC_REF(/mob/living/basic/outpost_prisoner, say_context), context)
		return TRUE
	return FALSE

/// The slug moves on to another vent, never straight back to the one it left
/datum/outpost_changeling_event/proc/hop()
	var/list/options = closed_vents(vent)
	if(!length(options))
		// Nowhere else to go: it stays put.
		dwell_left = roll_dwell()
		return FALSE
	move_slug_to(pick(options))
	return TRUE

/datum/outpost_changeling_event/proc/move_slug_to(obj/structure/outpost_kessler_vent/next)
	var/obj/structure/outpost_kessler_vent/left = vent
	if(left)
		left.release_occupant()
		left.scuttle()
	next.take_occupant(slug)
	vent = next
	dwell_left = roll_dwell()
	rattle_left = OUTPOST_CHANGELING_RATTLE_GAP
	next.clang(noise_level())

/// The vent the horror comes out of: the slug's own, unless it is in a bolted cell and another is not
/datum/outpost_changeling_event/proc/emergence_vent()
	if(vent && !vent_in_bolted_cell(vent) && !isclosedturf(get_turf(vent)))
		return vent
	var/list/options = list()
	for(var/obj/structure/outpost_kessler_vent/candidate as anything in closed_vents(vent))
		if(!vent_in_bolted_cell(candidate))
			options += candidate
	return length(options) ? pick(options) : vent

/datum/outpost_changeling_event/proc/vent_in_bolted_cell(obj/structure/outpost_kessler_vent/candidate)
	var/datum/outpost_prison_cell/holding = prison?.cell_at(get_turf(candidate))
	return !!holding?.is_bolted()

/// OUTPOST_CHANGELING_STRAIN_TIME seconds to go: one vent strains and bulges, as loud as it gets
/datum/outpost_changeling_event/proc/start_strain()
	var/obj/structure/outpost_kessler_vent/exit = emergence_vent()
	if(exit && exit != vent)
		move_slug_to(exit)
	straining = TRUE
	strain_left = OUTPOST_CHANGELING_STRAIN_TIME
	vent.visible_message(span_userdanger("Something much bigger is forcing its way up through [vent]!"))
	vent.balloon_alert_to_viewers("it's coming out!")
	vent.strain_pulse()
	prison.add_log("A vent is giving way.")
	prison.announce("Prison wing: something is forcing its way out of the vents!", SHIP_NOTIFY_DANGER)
	panic_prisoners()

// ===== THE HORROR =====

/**
 * The horror comes out of the slug's vent, or wherever the slug is if it is not in one. The cover
 * blows out, the slug is gone, and the horror unfolds for OUTPOST_HORROR_UNFOLD_TIME before it
 * shrieks. Returns TRUE if it came out.
 */
/datum/outpost_changeling_event/proc/emerge()
	if(stage == "done" || QDELETED(slug))
		return FALSE
	var/obj/structure/outpost_kessler_vent/exit = (vent && slug.loc == vent) ? vent : null
	var/turf/spot = get_turf(exit || slug)
	if(!spot)
		return FALSE
	straining = FALSE
	vent = null
	horror = new(spot)
	link_horror()
	stage = "horror"
	horror.emerge_for(src, extra_players())
	// Reported before the slug goes, so the experiment always has its creature.
	prison.experiment_creature_appeared(horror, "horror")
	var/mob/living/basic/headslug/beakless/outpost/old_slug = slug
	unlink_slug()
	slug = null
	exit?.release_occupant()
	qdel(old_slug)
	if(exit)
		exit.blow_out()
		spot.visible_message(span_userdanger("The cover of [exit] blows out, and something unfolds out of the duct: a person, or the shape of one, in black chitin, with a blade for an arm!"))
	else
		spot.visible_message(span_userdanger("The headslug swells and splits, and something unfolds out of it: a person, or the shape of one, in black chitin, with a blade for an arm!"))
	prison.add_log("A horror came out of the vents.")
	log_game("PLAYER OUTPOST PRISON: the changeling horror emerged at [AREACOORD(spot)] ('[prison.outpost?.name]'), [horror.maxHealth] health")
	prison.announce("Prison wing: a horror has come out of the vents!", SHIP_NOTIFY_DANGER)
	prison.play_alarm()
#ifndef OUTPOST_EXPERIMENT_API
	panic_prisoners()
#endif
	update_time_left()
	return TRUE

/// Living players on the wing's level beyond the first, capped: the horror gets tougher for each
/datum/outpost_changeling_event/proc/extra_players()
	var/z = prison?.wing_z()
	if(!z || z > length(SSmobs.clients_by_zlevel))
		return 0
	var/players = 0
	for(var/mob/living/person as anything in SSmobs.clients_by_zlevel[z])
		if(QDELETED(person) || !isliving(person) || person.stat == DEAD || !person.client)
			continue
		players++
	return clamp(players - 1, 0, OUTPOST_HORROR_EXTRA_PLAYERS_MAX)

/datum/outpost_changeling_event/proc/link_horror()
	horror.event = src
	RegisterSignal(horror, COMSIG_LIVING_DEATH, PROC_REF(on_horror_death))
	RegisterSignal(horror, COMSIG_QDELETING, PROC_REF(on_horror_deleted))

/datum/outpost_changeling_event/proc/unlink_horror()
	if(!horror)
		return
	UnregisterSignal(horror, list(COMSIG_LIVING_DEATH, COMSIG_QDELETING))
	if(horror.event == src)
		horror.event = null

/datum/outpost_changeling_event/proc/horror_tick(seconds, home)
	if(QDELETED(horror) || horror.stat == DEAD)
		return
#ifndef OUTPOST_EXPERIMENT_API
	// With S4a, its creature tick keeps the leash and calls the breach.
	leash_check(horror)
	// Taken by Kessler, or dead out in space: it is over.
	if(stage == "done")
		return
	if(!breach_announced && prison.wing && get_area(horror) != prison.wing)
		breach_announced = TRUE
		prison.add_log("The horror got out of the prison wing.")
		prison.announce("CONTAINMENT BREACH: the Kessler specimen has left the prison wing!", SHIP_NOTIFY_DANGER)
		prison.play_alarm()
#endif
	// Down and regenerating: its own clock, which also checks for open space and fire whoever is home.
	if(horror.regenerating)
		horror.regen_tick(seconds, home)
		if(QDELETED(horror) || horror.stat == DEAD)
			return
	if(!home)
		return
	remark_left -= seconds
	if(remark_left > 0)
		return
	remark_left = rand(8, 14)
	horror_remark(horror.regenerating ? "horror_down" : "horror")

/// One prisoner who can see the horror says a `context` line. Returns TRUE if one did.
/datum/outpost_changeling_event/proc/horror_remark(context)
	if(QDELETED(horror) || QDELETED(prison) || !prison.wing_can_speak())
		return FALSE
	for(var/mob/living/basic/outpost_prisoner/witness in shuffle(prison.prisoners))
		if(witness.stat != CONSCIOUS || witness.phase != PRISONER_PRESENT || witness.can_be_dragged() || !witness.ai_running())
			continue
		if(!(horror in view(7, witness)))
			continue
		prison.note_speech()
		INVOKE_ASYNC(witness, TYPE_PROC_REF(/mob/living/basic/outpost_prisoner, say_context), context)
		return TRUE
	return FALSE

/**
 * The horror went down regenerating (outpost_prison_horror.dm). The first time, the outpost is told
 * it is down and still moving; how to finish it is for the crew to work out, from what they see and
 * hear (the prisoners' shouts, its examine, a Kessler agent's word if one is about).
 */
/datum/outpost_changeling_event/proc/horror_collapsed()
	if(stage != "horror" || QDELETED(prison))
		return
	prison.add_log("The horror went down, but it is regenerating.")
	// A prisoner remarks on it soon.
	remark_left = min(remark_left, 2)
	if(regen_announced)
		return
	regen_announced = TRUE
	prison.announce("Prison wing: the specimen is down, but it's still moving.", SHIP_NOTIFY_DANGER)

/// The horror is pushing itself back up: a prisoner who can see it shouts about it
/datum/outpost_changeling_event/proc/horror_rising()
	if(stage != "horror")
		return
	horror_remark("horror_rises")

/// The horror is back on its feet
/datum/outpost_changeling_event/proc/horror_rose()
	if(stage != "horror" || QDELETED(prison))
		return
	prison.add_log("The horror got back up.")

// ===== WHAT IS ON THE OUTPOST =====

/// Whether `place` is the outpost's own ground: its area, or an installed upgrade's, on the wing's level. Never a docked ship.
/datum/outpost_changeling_event/proc/on_outpost_ground(atom/place)
	var/turf/tile = get_turf(place)
	if(!tile || !prison?.wing)
		return FALSE
	var/area/zone = tile.loc
	if(zone == prison.wing)
		return TRUE
	if(tile.z != prison.wing_z())
		return FALSE
	var/obj/structure/overmap/dynamic/player_outpost/outpost = prison.outpost
	if(QDELETED(outpost))
		return FALSE
	if(zone == outpost.outpost_area)
		return TRUE
	for(var/upgrade_id in outpost.outpost_upgrades)
		var/datum/outpost_upgrade/upgrade = outpost.outpost_upgrades[upgrade_id]
		if(upgrade?.installed && upgrade.installed_area == zone)
			return TRUE
	return FALSE

/**
 * Whether `place` is out in open space off the outpost: a space tile in none of the outpost's areas,
 * in space's own area (so not a docked ship's, and not a breach in the outpost's own floor). The
 * horror's body, down, dies there for good; a vented room inside the outpost is not open space.
 */
/datum/outpost_changeling_event/proc/in_open_space(atom/place)
	var/turf/tile = get_turf(place)
	if(!isspaceturf(tile) || !istype(tile.loc, /area/space))
		return FALSE
	return !on_outpost_ground(tile)

/**
 * A creature that ended up off the outpost (thrown, carried, teleported by an admin) is taken by
 * Kessler at once. It could not have walked there, so no recovery fee. The horror's body, down and
 * out in open space, is not taken: it dies there for good. Returns TRUE if Kessler took it.
 */
/datum/outpost_changeling_event/proc/leash_check(mob/living/creature)
	// By where it is, not what it is in: a pod or a locker carried off counts too.
	if(QDELETED(creature) || creature.stat == DEAD || on_outpost_ground(creature))
		return FALSE
	var/mob/living/basic/outpost_experiment/horror/spaced = creature
	if(istype(spaced) && spaced.die_if_spaced())
		return FALSE
	var/datum/outpost_prison/held = prison
	prison.add_log("Kessler took the specimen back: it was found off the outpost.")
	end_event("taken off the outpost", remove_creatures = TRUE)
	held?.experiment_failed("specimen taken off the outpost")
	return TRUE

// ===== THE PRISONERS =====

/// Every prisoner who can still walk goes to their cell and asks to be locked in. Anyone already running from a creature they can see keeps to that (outpost_prison_panic.dm).
/datum/outpost_changeling_event/proc/panic_prisoners()
	panicked = TRUE
	var/shouts = 0
	for(var/mob/living/basic/outpost_prisoner/prisoner in prison.prisoners)
		if(prisoner == host || !prisoner.routine_allowed() || prisoner.is_confined())
			continue
		if(istype(prisoner.activity, /datum/prisoner_activity/flee_creature) || istype(prisoner.activity, /datum/prisoner_activity/creature_panic))
			continue
		var/datum/prisoner_activity/flee_creature/flee = new(prisoner)
		if(!flee.setup())
			qdel(flee)
			continue
		prisoner.start_activity(flee)
		if(shouts < 2 && prisoner.ai_running())
			shouts++
			INVOKE_ASYNC(prisoner, TYPE_PROC_REF(/mob/living/basic/outpost_prisoner, say_context), "creature_panic")

/// Watches the prisoners' deaths while a creature is loose
/datum/outpost_changeling_event/proc/watch_prisoners()
	for(var/mob/living/basic/outpost_prisoner/prisoner in prison.prisoners)
		if(prisoner.stat == DEAD || watched_prisoners[prisoner])
			continue
		watched_prisoners[prisoner] = TRUE
		RegisterSignal(prisoner, COMSIG_LIVING_DEATH, PROC_REF(on_prisoner_died))
		RegisterSignal(prisoner, COMSIG_QDELETING, PROC_REF(on_watched_prisoner_deleted))

/datum/outpost_changeling_event/proc/unwatch_prisoners()
	for(var/mob/living/basic/outpost_prisoner/prisoner as anything in watched_prisoners)
		UnregisterSignal(prisoner, list(COMSIG_LIVING_DEATH, COMSIG_QDELETING))
	watched_prisoners.Cut()

/datum/outpost_changeling_event/proc/on_watched_prisoner_deleted(datum/source)
	SIGNAL_HANDLER
	UnregisterSignal(source, list(COMSIG_LIVING_DEATH, COMSIG_QDELETING))
	watched_prisoners -= source

/// A prisoner died while a creature was loose: the creature's kill if it was beside them
/datum/outpost_changeling_event/proc/on_prisoner_died(mob/living/basic/outpost_prisoner/victim, gibbed)
	SIGNAL_HANDLER
	var/mob/living/creature = current_creature()
	note_death(victim, creature && get_dist(creature, victim) <= 2)

/**
 * Records a death for the aftermath: the prisoners who saw it, and whether the creature did it.
 * Each death counts once.
 */
/datum/outpost_changeling_event/proc/note_death(mob/living/victim, by_creature)
	var/key = REF(victim)
	if(counted_deaths[key])
		return FALSE
	counted_deaths[key] = TRUE
	if(by_creature)
		kills++
	var/turf/spot = get_turf(victim)
	if(!spot)
		return TRUE
	for(var/mob/living/basic/outpost_prisoner/witness in view(7, spot))
		if(witness == victim || witness.stat != CONSCIOUS || witness.phase != PRISONER_PRESENT)
			continue
		witnesses |= WEAKREF(witness)
	return TRUE

/// The creature absorbed someone
/datum/outpost_changeling_event/proc/note_absorb(mob/living/victim)
	note_death(victim, TRUE)
	prison?.add_log(is_outpost_prisoner(victim) ? "The horror absorbed [victim.real_name]." : "The horror absorbed someone.")

/// What the prisoners saw sticks with them: mood for each witness, tension for each kill
/datum/outpost_changeling_event/proc/apply_aftermath()
	if(QDELETED(prison))
		return
	for(var/datum/weakref/ref as anything in witnesses)
		var/mob/living/basic/outpost_prisoner/witness = ref.resolve()
		if(QDELETED(witness) || witness.stat == DEAD || !(witness in prison.prisoners))
			continue
		witness.adjust_mood(-OUTPOST_CHANGELING_WITNESS_MOOD)
	if(kills)
		prison.add_tension_spike(OUTPOST_CHANGELING_KILL_TENSION * kills)
	witnesses.Cut()

// ===== THE END =====

/datum/outpost_changeling_event/proc/on_slug_death(datum/source, gibbed)
	SIGNAL_HANDLER
	if(stage == "done")
		return
	// The containment bonus is S4a's: it watches the death of every creature reported to it.
	prison.add_log("The headslug was killed.")
	end_event("the headslug was killed")

/datum/outpost_changeling_event/proc/on_slug_deleted(datum/source)
	SIGNAL_HANDLER
	slug = null
	if(stage == "done")
		return
	// Taken by Kessler's recovery, or by an admin.
	end_event("the headslug was taken")

/datum/outpost_changeling_event/proc/on_horror_death(datum/source, gibbed)
	SIGNAL_HANDLER
	if(stage == "done")
		return
	prison.add_log("The horror was killed.")
	end_event("the horror was killed")

/datum/outpost_changeling_event/proc/on_horror_deleted(datum/source)
	SIGNAL_HANDLER
	horror = null
	if(stage == "done")
		return
	end_event("the horror was taken")

/datum/outpost_changeling_event/proc/on_prison_deleted(datum/source)
	SIGNAL_HANDLER
	end_event("the prison is gone", remove_creatures = TRUE)
	if(prison)
		UnregisterSignal(prison, COMSIG_QDELETING)
	prison = null

/**
 * Ends the experiment: the clocks stop, a host still alive is let off, Kessler refits the vent
 * covers, and what the prisoners saw sinks in. `remove_creatures` has Kessler take the slug or the
 * horror too, alive or dead. Returns FALSE if it had already ended.
 */
/datum/outpost_changeling_event/proc/end_event(reason, remove_creatures = FALSE)
	if(stage == "done")
		return FALSE
	stage = "done"
	end_reason = reason
	time_left = null
	straining = FALSE
	STOP_PROCESSING(SSprocessing, src)
	release_host(cured = TRUE)
	vent?.release_occupant()
	vent = null
	var/mob/living/basic/headslug/beakless/outpost/old_slug = slug
	var/mob/living/basic/outpost_experiment/horror/old_horror = horror
	unlink_slug()
	unlink_horror()
	slug = null
	horror = null
	// A slug still in the ducts has nowhere to go once it is over: Kessler takes it whatever else happens.
	if(!remove_creatures && istype(old_slug?.loc, /obj/structure/outpost_kessler_vent))
		kessler_take(old_slug)
	if(remove_creatures)
		for(var/mob/living/creature as anything in list(old_slug, old_horror))
			if(!QDELETED(creature))
				kessler_take(creature)
	unwatch_prisoners()
	if(!QDELETED(prison))
		refit_vents()
#ifndef OUTPOST_EXPERIMENT_API
		// With S4a, resolve_experiment() does the aftermath for every creature.
		apply_aftermath()
#endif
	log_game("PLAYER OUTPOST PRISON: the changeling experiment at '[prison?.outpost?.name]' ended: [reason]")
	return TRUE

/// Kessler beams a creature out, alive or dead
/datum/outpost_changeling_event/proc/kessler_take(mob/living/creature)
	var/turf/spot = get_turf(creature)
	if(spot)
		playsound(spot, 'sound/effects/magic/teleport_diss.ogg', 40, TRUE)
		new /obj/effect/temp_visual/transporter_beam(spot, 1.5 SECONDS)
	qdel(creature)

/// New covers on every vent that lost one
/datum/outpost_changeling_event/proc/refit_vents()
	var/refitted = 0
	for(var/obj/structure/outpost_kessler_vent/fitting as anything in GLOB.outpost_kessler_vents)
		if(QDELETED(fitting) || get_area(fitting) != prison.wing)
			continue
		if(fitting.refit())
			refitted++
			fitting.visible_message(span_notice("A fresh Kessler cover clicks into place over [fitting]."))
	if(refitted)
		prison.add_log("Kessler refitted [refitted] vent cover\s.")

// ===== THE HOST'S LAST WALK =====

/// The host staggering to their bunk before the burst
/datum/prisoner_activity/changeling_bed
	name = "doubled up on their bunk"
	weight = 0
	interruptible = FALSE
	var/datum/weakref/bed_ref

/datum/prisoner_activity/changeling_bed/setup()
	var/obj/structure/bed/bunk = prisoner.find_bed()
	if(!bunk || !claim(bunk))
		return FALSE
	bed_ref = WEAKREF(bunk)
	spot = get_turf(bunk)
	return TRUE

/datum/prisoner_activity/changeling_bed/begin()
	started = TRUE
	ends_at = INFINITY
	prisoner.prison?.active_changeling?.host_lie_down()

/datum/prisoner_activity/changeling_bed/tick(seconds)
	return ACTIVITY_CONTINUE

// ===== HIDING FROM IT =====

/**
 * Something is loose: back to their own cell, into its chair (or onto the bunk), shouting to be
 * locked in until somebody bolts the door. Over when the creature is dead or taken; with the
 * experiments core in, over once the slug is out of the vents, when the creature itself frightens
 * them instead (outpost_prison_panic.dm). Bolted in their own cell meanwhile, the lock-in costs
 * them nothing.
 */
/datum/prisoner_activity/flee_creature
	name = "hiding in their cell"
	context = "creature_panic"
	weight = 0
	interruptible = FALSE
	/// Their cell's chair or bunk
	var/datum/weakref/seat_ref
	/// Seconds to the next shout
	var/shout_left = 0

/datum/prisoner_activity/flee_creature/setup()
	var/datum/outpost_prison_cell/home = prisoner.cell
	if(!home)
		return FALSE
	var/obj/structure/seat = prisoner.home_seat()
	if(seat && claim(seat))
		seat_ref = WEAKREF(seat)
		spot = get_turf(seat)
		return TRUE
	for(var/turf/tile as anything in home.turfs)
		if(prisoner.walkable?[tile] && (tile == prisoner.loc || !prisoner.tile_taken(tile)))
			spot = tile
			return TRUE
	return FALSE

/datum/prisoner_activity/flee_creature/begin()
	started = TRUE
	ends_at = INFINITY
	shout_left = rand(4, 10)
	if(seat_ref?.resolve())
		var/obj/machinery/door/door = prisoner.cell?.door()
		prisoner.sit_in_cell(door ? get_cardinal_dir(prisoner, door) : SOUTH)

/datum/prisoner_activity/flee_creature/tick(seconds)
	var/datum/outpost_prison/prison = prisoner.prison
	var/datum/outpost_changeling_event/event = prison?.active_changeling
#ifdef OUTPOST_EXPERIMENT_API
	if(event?.stage != "vents")
		return ACTIVITY_DONE
#endif
	if(!event?.creature_loose())
		return ACTIVITY_DONE
	shout_left -= seconds
	if(shout_left > 0)
		return ACTIVITY_CONTINUE
	shout_left = rand(15, 30)
	if(!prisoner.in_bolted_cell() && prison.wing_can_speak())
		prison.note_speech()
		prisoner.say_context("creature_panic")
	return ACTIVITY_CONTINUE

// ===== THE HEADSLUG =====

/**
 * The specimen once it has hatched: tg's beakless headslug, so it never lays an egg in anyone.
 * It heads for the nearest sealed vent and waits in the ducts while the event moves it about.
 * Wrenched out, it stays out and bites whoever is nearest. It never crawls tg's own vents, never
 * leaves the outpost's ground, and cannot be boxed, teleported, polymorphed, taken over or brought
 * back; its body is collected OUTPOST_CHANGELING_REMAINS_TIME after it dies.
 */
/mob/living/basic/headslug/beakless/outpost
	desc = "A small, slug-like creature with a large, gaping maw, still slick with whatever it came out of."
	maxHealth = OUTPOST_HEADSLUG_HEALTH
	health = OUTPOST_HEADSLUG_HEALTH
	speed = OUTPOST_HEADSLUG_SPEED
#ifdef OUTPOST_EXPERIMENT_API
	sentience_type = OUTPOST_EXPERIMENT_NO_SENTIENCE
#else
	sentience_type = SENTIENCE_BOSS
#endif
	unsuitable_atmos_damage = 0
	unsuitable_cold_damage = 0
	unsuitable_heat_damage = 0
	ai_controller = /datum/ai_controller/basic_controller/outpost_headslug
	/// The experiment it hatched from
	var/datum/outpost_changeling_event/event
	/// "seek" (heading for a vent), "vent" (in one) or "fight" (out for good)
	var/mode = "seek"
	/// The vent it is squeezing into, and the timer that finishes it
	var/obj/structure/outpost_kessler_vent/entering
	var/entry_timer
	/// Vents it could not get to: vent -> world.time it tries again
	var/list/unreachable_vents

/mob/living/basic/headslug/beakless/outpost/Initialize(mapload)
	. = ..()
	// The sealed Kessler vents only; tg's own vents would take it anywhere.
	REMOVE_TRAIT(src, TRAIT_VENTCRAWLER_ALWAYS, INNATE_TRAIT)
	ban_from_containment()
	AddElement(/datum/element/ai_retaliate)
	// A wet slither out of the vents; the footstep element stays quiet while it ventcrawls.
	AddElement(/datum/element/footstep, footstep_type = FOOTSTEP_MOB_SLIME, volume = 0.3)
	RegisterSignal(src, COMSIG_MOVABLE_TELEPORTING, PROC_REF(refuse_teleport), override = TRUE)
	RegisterSignal(src, COMSIG_LIVING_PRE_WABBAJACKED, PROC_REF(refuse_polymorph), override = TRUE)
	RegisterSignal(src, COMSIG_PRE_MOB_CHANGED_TYPE, PROC_REF(refuse_type_change), override = TRUE)
	RegisterSignal(src, COMSIG_MOVABLE_PRE_MOVE, PROC_REF(check_ground), override = TRUE)
	RegisterSignal(src, COMSIG_LIVING_REVIVE, PROC_REF(on_revived), override = TRUE)

/mob/living/basic/headslug/beakless/outpost/Destroy()
	cancel_vent_entry()
	unreachable_vents = null
	event = null
	return ..()

/mob/living/basic/headslug/beakless/outpost/examine(mob/user)
	. = ..()
	if(mode == "fight" && stat != DEAD)
		. += span_warning("It's out for blood.")

/mob/living/basic/headslug/beakless/outpost/proc/refuse_teleport(datum/source, atom/destination, channel)
	SIGNAL_HANDLER
	return TRUE

/mob/living/basic/headslug/beakless/outpost/proc/refuse_polymorph(datum/source, what_to_randomize)
	SIGNAL_HANDLER
	return STOP_WABBAJACK

/mob/living/basic/headslug/beakless/outpost/proc/refuse_type_change(datum/source)
	SIGNAL_HANDLER
	return COMPONENT_BLOCK_MOB_CHANGE

/// Never a step off the outpost's ground, walking, pulled or thrown
/mob/living/basic/headslug/beakless/outpost/proc/check_ground(datum/source, atom/new_loc)
	SIGNAL_HANDLER
	if(!isturf(new_loc) || !event)
		return NONE
	if(!event.on_outpost_ground(loc) || event.on_outpost_ground(new_loc))
		return NONE
	return COMPONENT_MOVABLE_BLOCK_PRE_MOVE

/mob/living/basic/headslug/beakless/outpost/can_be_revived()
	return FALSE

/mob/living/basic/headslug/beakless/outpost/proc/on_revived(datum/source, full_heal_flags)
	SIGNAL_HANDLER
	// Something brought it back anyway: Kessler takes it at once.
	INVOKE_ASYNC(src, PROC_REF(collect_remains))

/mob/living/basic/headslug/beakless/outpost/adjust_health(amount, updating_health = TRUE, forced = FALSE)
	. = ..()
	if(amount > 0 && entering)
		cancel_vent_entry(interrupted = TRUE)

/mob/living/basic/headslug/beakless/outpost/death(gibbed)
	cancel_vent_entry()
	. = ..()
	move_resist = MOVE_RESIST_DEFAULT
	if(!gibbed)
		addtimer(CALLBACK(src, PROC_REF(collect_remains)), OUTPOST_CHANGELING_REMAINS_TIME, TIMER_DELETE_ME)

/// Kessler takes the body
/mob/living/basic/headslug/beakless/outpost/proc/collect_remains()
	if(QDELETED(src))
		return
	var/turf/spot = get_turf(src)
	if(spot)
		spot.visible_message(span_notice("[src] vanishes in a column of light. Kessler has collected its remains."))
		playsound(spot, 'sound/effects/magic/teleport_diss.ogg', 40, TRUE)
		new /obj/effect/temp_visual/transporter_beam(spot, 1.5 SECONDS)
	qdel(src)

/// The nearest sealed vent it has not given up on, or null
/mob/living/basic/headslug/beakless/outpost/proc/nearest_vent()
	if(!event)
		return null
	var/obj/structure/outpost_kessler_vent/best
	var/best_distance = INFINITY
	for(var/obj/structure/outpost_kessler_vent/candidate as anything in event.closed_vents())
		if(LAZYACCESS(unreachable_vents, candidate) > world.time)
			continue
		var/distance = get_dist(src, candidate)
		if(distance < best_distance)
			best = candidate
			best_distance = distance
	return best

/// Could not get to `vent`: it tries the others first for a while
/mob/living/basic/headslug/beakless/outpost/proc/give_up_on_vent(obj/structure/outpost_kessler_vent/vent)
	if(vent)
		LAZYSET(unreachable_vents, vent, world.time + 10 SECONDS)

/// On the vent's tile: squeezes in over OUTPOST_HEADSLUG_VENT_ENTRY, unless something hurts it first
/mob/living/basic/headslug/beakless/outpost/proc/start_vent_entry(obj/structure/outpost_kessler_vent/vent)
	if(entering || mode != "seek" || stat != CONSCIOUS || QDELETED(vent) || vent.open || loc != vent.loc)
		return FALSE
	entering = vent
	ADD_TRAIT(src, TRAIT_IMMOBILIZED, HEADSLUG_VENT_TRAIT)
	visible_message(span_warning("[src] squeezes itself through the slats of [vent]!"))
	playsound(src, 'sound/machines/ventcrawl.ogg', 40, TRUE)
	Shake(1, 0, OUTPOST_HEADSLUG_VENT_ENTRY)
	entry_timer = addtimer(CALLBACK(src, PROC_REF(finish_vent_entry), vent), OUTPOST_HEADSLUG_VENT_ENTRY, TIMER_STOPPABLE|TIMER_DELETE_ME)
	return TRUE

/mob/living/basic/headslug/beakless/outpost/proc/finish_vent_entry(obj/structure/outpost_kessler_vent/vent)
	entry_timer = null
	if(entering != vent)
		return
	entering = null
	REMOVE_TRAIT(src, TRAIT_IMMOBILIZED, HEADSLUG_VENT_TRAIT)
	if(stat != CONSCIOUS || QDELETED(vent) || vent.open || loc != vent.loc || mode != "seek")
		return
	if(!event?.slug_reached_vent(src, vent))
		give_up_on_vent(vent)

/// Stops squeezing into a vent; `interrupted` means it was hurt and pops back out
/mob/living/basic/headslug/beakless/outpost/proc/cancel_vent_entry(interrupted = FALSE)
	if(entry_timer)
		deltimer(entry_timer)
		entry_timer = null
	var/obj/structure/outpost_kessler_vent/was_entering = entering
	entering = null
	REMOVE_TRAIT(src, TRAIT_IMMOBILIZED, HEADSLUG_VENT_TRAIT)
	if(interrupted && was_entering && stat == CONSCIOUS)
		visible_message(span_warning("[src] is knocked back out of [was_entering]!"))

/// Down in the ducts: the event moves it about, and its own mind waits
/mob/living/basic/headslug/beakless/outpost/proc/enter_vent_state()
	cancel_vent_entry()
	mode = "vent"
	ADD_TRAIT(src, TRAIT_AI_PAUSED, HEADSLUG_VENT_TRAIT)
	ai_controller?.CancelActions()

/// Out for good: it bites whoever is nearest, and whoever hurts it
/mob/living/basic/headslug/beakless/outpost/proc/start_fighting()
	cancel_vent_entry()
	mode = "fight"
	REMOVE_TRAIT(src, TRAIT_AI_PAUSED, HEADSLUG_VENT_TRAIT)
	ai_controller?.CancelActions()

/// Wrenched out of its vent (outpost_prison_vents.dm): stunned a moment, then it goes for the one holding the wrench
/mob/living/basic/headslug/beakless/outpost/proc/wrenched_out(mob/living/user)
	start_fighting()
	ADD_TRAIT(src, TRAIT_IMMOBILIZED, HEADSLUG_VENT_TRAIT)
	addtimer(TRAIT_CALLBACK_REMOVE(src, TRAIT_IMMOBILIZED, HEADSLUG_VENT_TRAIT), OUTPOST_HEADSLUG_WRENCHED_STUN, TIMER_DELETE_ME)
	if(istype(user) && ai_controller)
		ai_controller.set_blackboard_key(BB_BASIC_MOB_CURRENT_TARGET, user)
	event?.slug_wrenched_out(src, user)

// ----- its mind -----

/datum/ai_controller/basic_controller/outpost_headslug
	blackboard = list(
		BB_TARGETING_STRATEGY = /datum/targeting_strategy/basic,
		BB_TARGET_MINIMUM_STAT = HARD_CRIT,
	)
	ai_movement = /datum/ai_movement/jps
	idle_behavior = null
	planning_subtrees = list(
		/datum/ai_planning_subtree/outpost_headslug_vent,
		/datum/ai_planning_subtree/target_retaliate,
		/datum/ai_planning_subtree/simple_find_target,
		/datum/ai_planning_subtree/basic_melee_attack_subtree,
	)

/// Seeking a vent: walk onto the nearest and squeeze in. Nothing else while it is at it.
/datum/ai_planning_subtree/outpost_headslug_vent

/datum/ai_planning_subtree/outpost_headslug_vent/SelectBehaviors(datum/ai_controller/controller, seconds_per_tick)
	var/mob/living/basic/headslug/beakless/outpost/slug = controller.pawn
	if(!istype(slug) || slug.mode != "seek")
		return
	if(slug.entering)
		return SUBTREE_RETURN_FINISH_PLANNING
	var/obj/structure/outpost_kessler_vent/vent = slug.nearest_vent()
	if(!vent)
		return
	controller.set_blackboard_key(BB_OUTPOST_HEADSLUG_VENT, vent)
	controller.queue_behavior(/datum/ai_behavior/outpost_headslug_enter_vent, BB_OUTPOST_HEADSLUG_VENT)
	return SUBTREE_RETURN_FINISH_PLANNING

/datum/ai_behavior/outpost_headslug_enter_vent
	behavior_flags = AI_BEHAVIOR_REQUIRE_MOVEMENT
	required_distance = 0
	action_cooldown = 0.5 SECONDS

/datum/ai_behavior/outpost_headslug_enter_vent/setup(datum/ai_controller/controller, vent_key)
	var/obj/structure/outpost_kessler_vent/vent = controller.blackboard[vent_key]
	if(QDELETED(vent))
		return FALSE
	set_movement_target(controller, vent)
	return TRUE

/datum/ai_behavior/outpost_headslug_enter_vent/perform(seconds_per_tick, datum/ai_controller/controller, vent_key)
	var/mob/living/basic/headslug/beakless/outpost/slug = controller.pawn
	var/obj/structure/outpost_kessler_vent/vent = controller.blackboard[vent_key]
	if(QDELETED(vent) || slug.loc != vent.loc)
		return AI_BEHAVIOR_DELAY | AI_BEHAVIOR_FAILED
	if(!slug.start_vent_entry(vent))
		return AI_BEHAVIOR_DELAY | AI_BEHAVIOR_FAILED
	return AI_BEHAVIOR_DELAY | AI_BEHAVIOR_SUCCEEDED

/datum/ai_behavior/outpost_headslug_enter_vent/finish_action(datum/ai_controller/controller, succeeded, vent_key)
	. = ..()
	if(!succeeded)
		var/mob/living/basic/headslug/beakless/outpost/slug = controller.pawn
		slug?.give_up_on_vent(controller.blackboard[vent_key])
	controller.clear_blackboard_key(vent_key)

#undef ACTIVITY_CONTINUE
#undef ACTIVITY_DONE
#undef CHANGELING_HOST_TRAIT
#undef HEADSLUG_VENT_TRAIT
#undef BB_OUTPOST_HEADSLUG_VENT
