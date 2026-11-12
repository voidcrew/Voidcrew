/**
 * # Outpost jobs: the network
 *
 * Owner: P1. /datum/fixer_network (GLOB.fixer_network): what the three fixers know between them (spec 3). No
 * subsystem and nothing ticks: the slates are brought up to date when someone asks, rest and burn are "ready at"
 * times, and the burn comes from a signal handler on each fixer's police (COMSIG_OUTPOST_POLICE_CRIME).
 *
 * - The slate (3.1): each outpost's fixer holds FIXER_SLATE_SIZE made jobs, mission datums nobody has taken, never
 *   on a board. Two on a slate are never the same kind, and a kind already running at that outpost is not offered
 *   there (one live job of a kind per outpost; a smuggle is one per outpost pair). A taken entry comes back
 *   FIXER_SLATE_REFILL later; an entry nobody took for FIXER_OFFER_EXPIRY is swapped at once. Several crews can be
 *   offered one entry: the first to take it has it. L25: when none of the entries is open to the asking crew but some
 *   kind would be, the oldest entry nobody holds an offer on gives way to one that is (fit_entry()).
 * - Trust (3.3): jobs paid, per crew record. Rest (3.4): per crew record and outpost, only ever pushed later.
 *   Burn (3.5): per crew record and per mind, so a new crew record does not shed it.
 *
 * Crew records are keyed by their crew_id, minds by weakref and outposts by REF(), so nothing here holds a person
 * or a ship alive. The jobs on a slate are held hard until taken or swapped; a swapped job is deleted.
 */

/// Townspeople's lines about a finished job, by FIXER_JOB_* kind: a section of FIXER_STRINGS_FIXER beside the speakers
#define FIXER_VOICE_GOSSIP "gossip"

GLOBAL_DATUM_INIT(fixer_network, /datum/fixer_network, new)

/// One outpost's offers
/datum/fixer_slate
	/// The jobs on offer, oldest first
	var/list/datum/mission/fixer_job/entries = list()
	/// job -> world.time it came on the slate
	var/list/made_at = list()
	/// world.time each taken entry's replacement comes, one per taken entry
	var/list/refills = list()
	/// crew key -> list(job, world.time the offer closes): the one entry offered to that crew now
	var/list/offers = list()

/datum/fixer_slate/Destroy()
	clear()
	return ..()

/// Drops every offer and deletes every job nobody has taken
/datum/fixer_slate/proc/clear()
	offers.Cut()
	made_at.Cut()
	for(var/datum/mission/fixer_job/job as anything in entries)
		if(!QDELETED(job) && !job.active)
			qdel(job)
	entries.Cut()

/datum/fixer_network
	/// REF(outpost) -> /datum/fixer_slate
	var/list/slates = list()
	/// Living and dead fixers, until deleted
	var/list/mob/living/carbon/human/npc/ambient_npc/outpost/fixer/fixers = list()
	/// crew key -> jobs paid
	var/list/jobs_paid = list()
	/// "[crew key]|[REF(outpost)]" -> world.time that fixer has work for that crew again
	var/list/rest_until = list()
	/// "[crew key]|[REF(outpost)]" -> TRUE: that fixer says their "failed" line the next time that crew asks
	var/list/owed_failed = list()
	/// crew key -> world.time the burn ends
	var/list/burned_crews = list()
	/// mind weakref -> world.time the burn ends
	var/list/burned_minds = list()
	/// crew key -> TRUE while that crew's "I'll take it." is being worked through (abuse J14)
	var/list/accept_locks = list()
	/// Jobs being started right now -> TRUE, so a second crew can't take one mid-start
	var/list/taking = list()
	/// Police datums heard for crimes against fixers
	var/list/datum/outpost_police/watched_police = list()
	/// REF(outpost) -> TRUE once a fixer there has died: whoever comes after is a stand-in (spec 2.6)
	var/list/lost_originals = list()
	/// FALSE stops the slates filling themselves (tests set their own entries)
	var/auto_fill = TRUE

/datum/fixer_network/Destroy()
	for(var/datum/outpost_police/police as anything in watched_police)
		UnregisterSignal(police, list(COMSIG_OUTPOST_POLICE_CRIME, COMSIG_QDELETING))
	watched_police.Cut()
	for(var/key in slates)
		qdel(slates[key])
	slates.Cut()
	fixers.Cut()
	return ..()

// =========================================================================
// KEYS
// =========================================================================

/// The key a crew record is known by here
/proc/fixer_crew_key(datum/voidcrew_crew_record/crew)
	return crew ? "[crew.crew_id]" : null

/// The crew record `user` flies with, or null
/proc/fixer_crew_of(mob/user)
	return user?.mind?.get_reputation_crew()

/// The rest key of `crew` at `outpost`
/proc/fixer_rest_key(datum/voidcrew_crew_record/crew, obj/structure/overmap/trader_outpost/outpost)
	return (crew && outpost) ? "[crew.crew_id]|[REF(outpost)]" : null

/// The trader outpost `fixer` works at, or null
/proc/fixer_outpost_of(mob/living/fixer)
	var/mob/living/carbon/human/npc/ambient_npc/outpost/fixer/real = fixer
	return istype(real) ? real.get_outpost() : null

/// The zone `outpost` is in (ZONE_*), green if unknown
/proc/fixer_outpost_band(obj/structure/overmap/trader_outpost/outpost)
	var/band = outpost ? SSovermap_zones?.get_zone_type(get_turf(outpost)) : null
	return (band in list(ZONE_GREEN, ZONE_YELLOW, ZONE_RED)) ? band : ZONE_GREEN

/// Whether `outpost` is in trouble: shot up and not yet cleaned up, or shut after its crews were lost
/proc/fixer_outpost_in_trouble(obj/structure/overmap/trader_outpost/outpost)
	var/datum/outpost_recovery/recovery = outpost?.recovery
	if(!recovery)
		return FALSE
	if(recovery.port_shut_until > world.time)
		return TRUE
	return recovery.state == OUTPOST_RECOVERY_TROUBLE || recovery.state == OUTPOST_RECOVERY_CLEANUP

// =========================================================================
// THE FIXERS
// =========================================================================

/// The living fixer at `outpost`, or null
/datum/fixer_network/proc/fixer_at(obj/structure/overmap/trader_outpost/outpost)
	if(!outpost)
		return null
	for(var/mob/living/carbon/human/npc/ambient_npc/outpost/fixer/fixer as anything in fixers)
		if(!QDELETED(fixer) && fixer.stat != DEAD && !fixer.fading && fixer.get_outpost() == outpost)
			return fixer
	return null

/// Whether any fixer is alive anywhere
/datum/fixer_network/proc/any_fixer_alive()
	for(var/mob/living/carbon/human/npc/ambient_npc/outpost/fixer/fixer as anything in fixers)
		if(!QDELETED(fixer) && fixer.stat != DEAD && fixer.get_outpost())
			return TRUE
	return FALSE

/// A fixer joined `police`'s outpost: the network hears it for crimes against fixers
/datum/fixer_network/proc/watch_police(datum/outpost_police/police)
	if(QDELETED(police) || (police in watched_police))
		return
	watched_police += police
	RegisterSignal(police, COMSIG_OUTPOST_POLICE_CRIME, PROC_REF(on_crime))
	RegisterSignal(police, COMSIG_QDELETING, PROC_REF(on_police_deleted))

/datum/fixer_network/proc/on_police_deleted(datum/outpost_police/source)
	SIGNAL_HANDLER
	UnregisterSignal(source, list(COMSIG_OUTPOST_POLICE_CRIME, COMSIG_QDELETING))
	watched_police -= source

/// A counted crime with a fixer as its victim burns the offender and their crew (spec 3.5, L22). Unseen violence is never counted, so never heard.
/datum/fixer_network/proc/on_crime(datum/source, datum/mind/mind, crime, atom/victim, stars_after, derived)
	SIGNAL_HANDLER
	if(mind && istype(victim, /mob/living/carbon/human/npc/ambient_npc/outpost/fixer))
		burn(mind)

/// A fixer at `outpost` died: whoever comes after is a stand-in, and every offer they held is gone (spec 2.6). Jobs already taken stay good.
/datum/fixer_network/proc/fixer_died(obj/structure/overmap/trader_outpost/outpost)
	if(!outpost)
		return
	lost_originals[REF(outpost)] = TRUE
	var/datum/fixer_slate/slate = slates[REF(outpost)]
	slate?.clear()

// =========================================================================
// TRUST, REST, BURN
// =========================================================================

/// Jobs `crew` has been paid for
/datum/fixer_network/proc/trust_of(datum/voidcrew_crew_record/crew)
	var/key = fixer_crew_key(crew)
	return key ? (jobs_paid[key] || 0) : 0

/// Admin: sets `crew`'s jobs paid to `amount`
/datum/fixer_network/proc/set_trust(datum/voidcrew_crew_record/crew, amount)
	var/key = fixer_crew_key(crew)
	if(key)
		jobs_paid[key] = max(0, round(amount))

/// Admin: clears `crew`'s rest and burn everywhere, and the burn of everyone on it
/datum/fixer_network/proc/clear_crew(datum/voidcrew_crew_record/crew)
	var/key = fixer_crew_key(crew)
	if(!key)
		return
	burned_crews -= key
	for(var/datum/mind/member in crew.minds)
		burned_minds -= WEAKREF(member)
	var/prefix = "[key]|"
	for(var/rest_key in rest_until.Copy())
		if(findtext(rest_key, prefix) == 1)
			rest_until -= rest_key
			owed_failed -= rest_key

/// The fixer at `outpost` has nothing for `crew` for `time`: a "ready at" that is only ever pushed later, never brought nearer
/datum/fixer_network/proc/rest(datum/voidcrew_crew_record/crew, obj/structure/overmap/trader_outpost/outpost, time)
	var/key = fixer_rest_key(crew, outpost)
	if(key)
		rest_until[key] = max(rest_until[key] || 0, world.time + time)

/// world.time the fixer at `outpost` has work for `crew` again, or 0
/datum/fixer_network/proc/ready_at(datum/voidcrew_crew_record/crew, obj/structure/overmap/trader_outpost/outpost)
	var/key = fixer_rest_key(crew, outpost)
	return key ? (rest_until[key] || 0) : 0

/// `offender` and their crew record are burned with every fixer for FIXER_BURN_TIME. Money already owed is still paid.
/datum/fixer_network/proc/burn(datum/mind/offender)
	if(!offender)
		return
	var/until = world.time + FIXER_BURN_TIME
	var/datum/weakref/mind_ref = WEAKREF(offender)
	burned_minds[mind_ref] = max(burned_minds[mind_ref] || 0, until)
	var/key = fixer_crew_key(offender.get_reputation_crew())
	if(key)
		burned_crews[key] = max(burned_crews[key] || 0, until)

/// Whether `user` gets no offers for a burn: their own, their crew's, or anyone's on their crew (abuse J18)
/datum/fixer_network/proc/is_burned(mob/user)
	var/datum/mind/mind = user?.mind
	if(!mind)
		return FALSE
	if(mind_burned(mind))
		return TRUE
	var/datum/voidcrew_crew_record/crew = mind.get_reputation_crew()
	var/key = fixer_crew_key(crew)
	if(key && burned_crews[key] > world.time)
		return TRUE
	for(var/datum/mind/member in crew?.minds)
		if(mind_burned(member))
			return TRUE
	return FALSE

/// Whether `mind` itself is burned now
/datum/fixer_network/proc/mind_burned(datum/mind/mind)
	var/datum/weakref/mind_ref = WEAKREF(mind)
	return burned_minds[mind_ref] > world.time

// =========================================================================
// THE CREW'S JOB
// =========================================================================

/// The live fixer job `crew` holds on any of its ships, or null (FIXER_JOBS_PER_SHIP, held as one per crew record)
/datum/fixer_network/proc/crew_job(datum/voidcrew_crew_record/crew)
	if(!crew)
		return null
	for(var/datum/mission/fixer_job/job in SSmissions.all_active_missions)
		if(!QDELETED(job) && job.active && !job.failed && !job.completed && job.accepting_crew == crew)
			return job
	for(var/datum/team/voidcrew/team in crew.teams)
		var/obj/structure/overmap/ship/ship = team.ship
		if(QDELETED(ship))
			continue
		for(var/datum/mission/fixer_job/job in ship.active_missions)
			if(!QDELETED(job) && !job.failed && !job.completed)
				return job
	return null

/// Whether a job of `kind` is running at `outpost` (to `pay_outpost`, for a smuggle) other than `excluding`: one live job of a kind per outpost
/datum/fixer_network/proc/kind_live_at(kind, obj/structure/overmap/trader_outpost/outpost, obj/structure/overmap/trader_outpost/pay_outpost, datum/mission/fixer_job/excluding)
	for(var/datum/mission/fixer_job/job in SSmissions.all_active_missions)
		if(job == excluding || QDELETED(job) || !job.active || job.failed || job.completed)
			continue
		if(job.job_kind != kind || job.job_outpost != outpost)
			continue
		if(kind == FIXER_JOB_SMUGGLE && pay_outpost && job.pay_outpost && job.pay_outpost != pay_outpost)
			continue
		return TRUE
	return FALSE

// =========================================================================
// THE SLATE
// =========================================================================

/// The concrete job types, with their slate weights
/datum/fixer_network/proc/job_weights()
	var/static/list/weights
	if(!weights)
		weights = list()
		for(var/datum/mission/fixer_job/job_type as anything in subtypesof(/datum/mission/fixer_job))
			if(initial(job_type.job_kind) && initial(job_type.slate_weight) > 0)
				weights[job_type] = initial(job_type.slate_weight)
	return weights

/// `outpost`'s slate, brought up to date: gone and stale entries swapped, due refills made
/datum/fixer_network/proc/slate_for(obj/structure/overmap/trader_outpost/outpost)
	if(QDELETED(outpost))
		return null
	var/key = REF(outpost)
	var/datum/fixer_slate/slate = slates[key]
	if(!slate)
		slate = new
		slates[key] = slate
	refresh(slate, outpost)
	return slate

/// Swaps out what nobody took for FIXER_OFFER_EXPIRY, forgets taken and deleted entries, and fills up to FIXER_SLATE_SIZE less the refills still to come
/datum/fixer_network/proc/refresh(datum/fixer_slate/slate, obj/structure/overmap/trader_outpost/outpost)
	for(var/datum/mission/fixer_job/job as anything in slate.entries.Copy())
		if(QDELETED(job) || job.active || job.failed || job.completed)
			drop_entry(slate, job)
			continue
		if(world.time >= (slate.made_at[job] || 0) + FIXER_OFFER_EXPIRY)
			drop_entry(slate, job)
			qdel(job)
	for(var/crew_key in slate.offers.Copy())
		var/list/offer = slate.offers[crew_key]
		if(!islist(offer) || !(offer[1] in slate.entries) || world.time >= offer[2])
			slate.offers -= crew_key
	for(var/due in slate.refills.Copy())
		if(due <= world.time)
			slate.refills -= due
	if(!auto_fill)
		return
	var/tries = FIXER_SLATE_SIZE * 2
	while(length(slate.entries) + length(slate.refills) < FIXER_SLATE_SIZE && tries-- > 0)
		if(!make_entry(slate, outpost))
			break

/// Takes `job` off `slate` and every offer of it
/datum/fixer_network/proc/drop_entry(datum/fixer_slate/slate, datum/mission/fixer_job/job)
	slate.entries -= job
	slate.made_at -= job
	for(var/crew_key in slate.offers.Copy())
		var/list/offer = slate.offers[crew_key]
		if(!islist(offer) || offer[1] == job)
			slate.offers -= crew_key

/// Makes one job for `outpost`'s slate, of a kind not already on it nor running there. The job, or null.
/datum/fixer_network/proc/make_entry(datum/fixer_slate/slate, obj/structure/overmap/trader_outpost/outpost)
	var/list/weights = job_weights().Copy()
	var/list/held_kinds = list()
	for(var/datum/mission/fixer_job/held as anything in slate.entries)
		held_kinds[held.job_kind] = TRUE
	for(var/job_type in weights.Copy())
		var/datum/mission/fixer_job/cast = job_type
		var/kind = initial(cast.job_kind)
		// A smuggle's far end is not known before it is made, so a running one keeps another off this slate
		if(held_kinds[kind] || kind_live_at(kind, outpost))
			weights -= job_type
	if(!length(weights))
		return null
	var/datum/mission/fixer_job/job = new_job(pick_weight(weights), outpost)
	if(!job)
		return null
	slate.entries += job
	slate.made_at[job] = world.time
	return job

/**
 * A new job of `job_type` for `outpost`'s fixer, or null if it could not be made. INTEGRATION: the job shell (P2)
 * reads `job_outpost`; it is set here straight after New(), before anything else touches the job.
 */
/datum/fixer_network/proc/new_job(job_type, obj/structure/overmap/trader_outpost/outpost)
	var/datum/mission/fixer_job/job = new job_type()
	job.job_outpost = outpost
	if(job.generation_failed)
		qdel(job)
		return null
	return job

/// Whether `crew` may be offered `job` at `outpost`: trust, the zone rule every mission follows, and the job's own test
/datum/fixer_network/proc/entry_open_to(datum/mission/fixer_job/job, datum/voidcrew_crew_record/crew, obj/structure/overmap/trader_outpost/outpost)
	if(QDELETED(job) || job.active || job.failed || job.completed || !crew)
		return FALSE
	if(trust_of(crew) < job.trust_tier)
		return FALSE
	if(!crew.can_work_in_zone(fixer_outpost_band(job.job_outpost || outpost)))
		return FALSE
	return !!job.allowed_at(outpost, crew)

/// The entries on `outpost`'s slate `crew` may be offered, oldest first. With none, one is fitted for them (L25).
/datum/fixer_network/proc/open_entries(obj/structure/overmap/trader_outpost/outpost, datum/voidcrew_crew_record/crew)
	. = list()
	var/datum/fixer_slate/slate = slate_for(outpost)
	for(var/datum/mission/fixer_job/job as anything in slate?.entries)
		if(entry_open_to(job, crew, outpost))
			. += job
	if(!length(.) && auto_fill && crew && length(slate?.entries))
		var/datum/mission/fixer_job/fitted = fit_entry(slate, outpost, crew)
		if(fitted)
			. += fitted

/// Whether a crew holds a live offer of `job` on `slate`, or someone is taking it now
/datum/fixer_network/proc/entry_held(datum/fixer_slate/slate, datum/mission/fixer_job/job)
	if(taking[job])
		return TRUE
	for(var/crew_key in slate.offers)
		var/list/offer = slate.offers[crew_key]
		if(islist(offer) && offer[1] == job && world.time < offer[2])
			return TRUE
	return FALSE

/**
 * L25: a slate always holds a job the asking crew may take when any kind is allowed for them. The oldest entry no crew
 * holds an offer on gives way to a job of a kind `crew` may take (by trust, zone and the job's own test); with every
 * entry on offer, the new one joins the slate beside them. The job, or null when no kind is allowed for that crew here.
 */
/datum/fixer_network/proc/fit_entry(datum/fixer_slate/slate, obj/structure/overmap/trader_outpost/outpost, datum/voidcrew_crew_record/crew)
	if(!slate || !crew || !crew.can_work_in_zone(fixer_outpost_band(outpost)))
		return null
	var/datum/mission/fixer_job/gives_way
	for(var/datum/mission/fixer_job/entry as anything in slate.entries)
		if(!entry_held(slate, entry))
			gives_way = entry
			break
	var/list/held_kinds = list()
	for(var/datum/mission/fixer_job/held as anything in slate.entries)
		if(held != gives_way)
			held_kinds[held.job_kind] = TRUE
	var/trust = trust_of(crew)
	var/list/weights = job_weights().Copy()
	for(var/job_type in weights.Copy())
		var/datum/mission/fixer_job/cast = job_type
		var/kind = initial(cast.job_kind)
		if(trust < initial(cast.trust_tier) || held_kinds[kind] || kind_live_at(kind, outpost))
			weights -= job_type
	while(length(weights))
		var/job_type = pick_weight(weights)
		weights -= job_type
		var/datum/mission/fixer_job/job = new_job(job_type, outpost)
		if(!job)
			continue
		if(!entry_open_to(job, crew, outpost))
			qdel(job)
			continue
		if(gives_way)
			drop_entry(slate, gives_way)
			qdel(gives_way)
		slate.entries += job
		slate.made_at[job] = world.time
		return job
	return null

/// The entry offered to `crew` at `outpost` and still open, or null
/datum/fixer_network/proc/live_offer(obj/structure/overmap/trader_outpost/outpost, datum/voidcrew_crew_record/crew)
	var/datum/fixer_slate/slate = slate_for(outpost)
	var/key = fixer_crew_key(crew)
	var/list/offer = (slate && key) ? slate.offers[key] : null
	if(!islist(offer))
		return null
	var/datum/mission/fixer_job/job = offer[1]
	return (world.time < offer[2] && entry_open_to(job, crew, outpost)) ? job : null

/// Offers `job` to `crew` at `outpost` for FIXER_OFFER_TIME
/datum/fixer_network/proc/make_offer(obj/structure/overmap/trader_outpost/outpost, datum/voidcrew_crew_record/crew, datum/mission/fixer_job/job)
	var/datum/fixer_slate/slate = slate_for(outpost)
	var/key = fixer_crew_key(crew)
	if(slate && key && (job in slate.entries))
		slate.offers[key] = list(job, world.time + FIXER_OFFER_TIME)

/// `job` was taken off `outpost`'s slate: its place comes back FIXER_SLATE_REFILL from now
/datum/fixer_network/proc/entry_taken(obj/structure/overmap/trader_outpost/outpost, datum/mission/fixer_job/job)
	var/datum/fixer_slate/slate = outpost ? slates[REF(outpost)] : null
	if(!slate || !(job in slate.entries))
		return
	drop_entry(slate, job)
	slate.refills += world.time + FIXER_SLATE_REFILL

/**
 * "I'll take it.": `user`'s crew takes the job `fixer` offered it, through the ship's own accept (the kingpin's way,
 * ship.accept_mission()), behind a per-crew lock set before anything can sleep, so two crewmates at two fixers
 * cannot both win (abuse J14). Returns the started job, or the FIXER_LINE_* key the fixer answers with. Can sleep
 * (the job stages itself as it starts).
 */
/datum/fixer_network/proc/accept(mob/living/user, mob/fixer)
	var/datum/voidcrew_crew_record/crew = fixer_crew_of(user)
	var/crew_key = fixer_crew_key(crew)
	if(!crew_key)
		return FIXER_LINE_NO_SHIP
	if(accept_locks[crew_key])
		return FIXER_LINE_BUSY
	accept_locks[crew_key] = TRUE
	. = do_accept(user, fixer, crew)
	accept_locks -= crew_key

/datum/fixer_network/proc/do_accept(mob/living/user, mob/fixer, datum/voidcrew_crew_record/crew)
	PRIVATE_PROC(TRUE)
	. = basic_refusal(user, fixer)
	if(.)
		return
	var/obj/structure/overmap/trader_outpost/outpost = fixer_outpost_of(fixer)
	var/datum/mission/fixer_job/job = live_offer(outpost, crew)
	// Beaten to it, or the offer ran out
	if(!job || job.active || (job in taking))
		return FIXER_LINE_GONE
	var/datum/fixer_slate/slate = slates[REF(outpost)]
	if(kind_live_at(job.job_kind, outpost, job.pay_outpost))
		drop_entry(slate, job)
		qdel(job)
		return FIXER_LINE_GONE
	var/obj/structure/overmap/ship/ship = get_crew_ship(user)
	var/mob/living/carbon/human/npc/ambient_npc/outpost/fixer/giver = fixer
	job.giver_outpost = outpost
	if(istype(giver))
		job.author = giver.speech_name()
		job.name = "A favour for [giver.speech_name()]"
		job.desc = "See the note."
	taking[job] = TRUE
	ship.available_missions += job
	var/result = ship.accept_mission(job)
	taking -= job
	if(result != TRUE)
		ship.available_missions -= job
		// It could not start (no room to stage it): the entry is dropped, and nobody rests
		if(slate)
			drop_entry(slate, job)
		if(!QDELETED(job) && !job.active)
			qdel(job)
		return FIXER_LINE_NOTHING
	entry_taken(outpost, job)
	log_game("FIXER: [key_name(user)] of the [ship.name] took [job.type] from [fixer] at [AREACOORD(fixer)]")
	return job

// =========================================================================
// WHO GETS WORK (spec 3.2)
// =========================================================================

/// Whether anyone on `user`'s crew (or `user`, with none) is wanted at `outpost` now
/datum/fixer_network/proc/crew_wanted_at(mob/user, obj/structure/overmap/trader_outpost/outpost)
	var/datum/outpost_police/police = outpost?.police
	if(!police || !user?.mind)
		return FALSE
	if(police.get_stars(user.mind) > 0)
		return TRUE
	var/datum/voidcrew_crew_record/crew = fixer_crew_of(user)
	for(var/datum/mind/member in crew?.minds)
		if(police.get_stars(member) > 0)
			return TRUE
	return FALSE

/// The first officer of `fixer`'s outpost within FIXER_OFFICER_RANGE of them and in their sight, or null
/datum/fixer_network/proc/officer_near(mob/living/fixer)
	var/obj/structure/overmap/trader_outpost/outpost = fixer_outpost_of(fixer)
	var/turf/here = get_turf(fixer)
	if(!outpost?.police || !here)
		return null
	for(var/mob/living/officer in outpost.police.officers)
		if(QDELETED(officer) || officer.stat != CONSCIOUS || officer.z != here.z)
			continue
		if(get_dist(officer, here) > FIXER_OFFICER_RANGE)
			continue
		if(can_see(fixer, officer, FIXER_OFFICER_RANGE))
			return officer
	return null

/// The first of spec 3.2's checks 1-7 that fails for `user` asking `fixer`, as a FIXER_LINE_* key, or null
/datum/fixer_network/proc/basic_refusal(mob/living/user, mob/fixer)
	if(is_burned(user))
		return FIXER_LINE_BURNED
	var/obj/structure/overmap/ship/ship = get_crew_ship(user)
	var/datum/voidcrew_crew_record/crew = fixer_crew_of(user)
	if(!ship || !crew)
		return FIXER_LINE_NO_SHIP
	var/obj/structure/overmap/trader_outpost/outpost = fixer_outpost_of(fixer)
	if(!outpost)
		return FIXER_LINE_NOTHING
	if(crew_wanted_at(user, outpost))
		return FIXER_LINE_WANTED
	if(officer_near(fixer))
		return FIXER_LINE_OFFICER
	if(fixer_outpost_in_trouble(outpost))
		return FIXER_LINE_TROUBLE
	if(crew_job(crew) || length(ship.active_missions) >= ship.max_missions)
		return FIXER_LINE_BUSY
	if(ready_at(crew, outpost) > world.time)
		return owed_failed[fixer_rest_key(crew, outpost)] ? FIXER_LINE_FAILED : FIXER_LINE_NOTHING
	return null

/// The first failing check of spec 3.2 for `user` asking `fixer`, as a FIXER_LINE_* key, or null
/datum/fixer_network/proc/refusal(mob/living/user, mob/fixer)
	. = basic_refusal(user, fixer)
	if(.)
		return
	var/obj/structure/overmap/trader_outpost/outpost = fixer_outpost_of(fixer)
	var/datum/voidcrew_crew_record/crew = fixer_crew_of(user)
	if(length(open_entries(outpost, crew)))
		return null
	// Something is on the slate, held back only by trust
	var/datum/fixer_slate/slate = slates[REF(outpost)]
	for(var/datum/mission/fixer_job/job as anything in slate?.entries)
		if(!QDELETED(job) && !job.active && trust_of(crew) < job.trust_tier)
			return FIXER_LINE_NO_TRUST
	return FIXER_LINE_NOTHING

/// A "failed" line owed to `crew` at `outpost` was said
/datum/fixer_network/proc/failed_line_said(datum/voidcrew_crew_record/crew, obj/structure/overmap/trader_outpost/outpost)
	owed_failed -= fixer_rest_key(crew, outpost)

// =========================================================================
// THE JOB SHELL'S CALLS (P2)
// =========================================================================

/// `job` was paid by `fixer` at `noise`: trust +1, rest at the paying fixer, and the port talks about it
/datum/fixer_network/proc/note_paid(datum/mission/fixer_job/job, noise, mob/fixer)
	var/datum/voidcrew_crew_record/crew = job?.accepting_crew
	var/key = fixer_crew_key(crew)
	if(key)
		jobs_paid[key] = (jobs_paid[key] || 0) + 1
		rest(crew, fixer_outpost_of(fixer) || job.giver_outpost, noise > 0 ? FIXER_REST_NOISY : FIXER_REST_CLEAN)
	gossip(job)

/// `job` failed for `reason` (FIXER_FAIL_*): rest at the giving fixer unless spoiled, unstaged or gone
/datum/fixer_network/proc/note_failed(datum/mission/fixer_job/job, reason)
	if(!job)
		return
	if(job.deed_done)
		gossip(job)
	if(reason == FIXER_FAIL_SPOILED || reason == FIXER_FAIL_STAGING || reason == FIXER_FAIL_GONE)
		return
	var/datum/voidcrew_crew_record/crew = job.accepting_crew
	var/obj/structure/overmap/trader_outpost/giver = job.giver_outpost || job.job_outpost
	if(!crew || !giver)
		return
	rest(crew, giver, FIXER_REST_FAILED)
	owed_failed[fixer_rest_key(crew, giver)] = TRUE

// =========================================================================
// GOSSIP (spec 8)
// =========================================================================

/// Up to two townspeople at `job`'s outpost say a line about it some time in the next FIXER_GOSSIP_TIME
/datum/fixer_network/proc/gossip(datum/mission/fixer_job/job)
	var/obj/structure/overmap/trader_outpost/outpost = job?.job_outpost
	var/datum/ambient_place/outpost/place = outpost ? SSambient_npcs.outposts[outpost] : null
	if(!place || !job.job_kind)
		return
	var/list/lines = fixer_lines(FIXER_VOICE_GOSSIP, job.job_kind)
	if(!length(lines))
		return
	var/list/talkers = list()
	for(var/mob/living/carbon/human/npc/ambient_npc/npc as anything in place.living_npcs())
		if(istype(npc, /mob/living/carbon/human/npc/ambient_npc/outpost/trader) || fixer_crowd_exempt(npc))
			continue
		talkers += npc
	for(var/count in 1 to min(2, length(talkers)))
		var/mob/living/carbon/human/npc/ambient_npc/talker = pick_n_take(talkers)
		addtimer(CALLBACK(src, PROC_REF(say_gossip), WEAKREF(talker), pick(lines)), rand(30 SECONDS, FIXER_GOSSIP_TIME), TIMER_DELETE_ME)

/// `talker` says `line`, if they are still about at an outpost someone is at
/datum/fixer_network/proc/say_gossip(datum/weakref/talker_ref, line)
	var/mob/living/carbon/human/npc/ambient_npc/talker = talker_ref?.resolve()
	if(QDELETED(talker) || !talker.can_act())
		return
	var/datum/ambient_place/outpost/place = talker.place
	if(!istype(place) || !place.occupied)
		return
	talker.say_line(fixer_cut(line, FIXER_BOUND_LINE))

// =========================================================================
// STRINGS (spec 6.1)
// =========================================================================

/// FIXER_STRINGS_FIXER, loaded into GLOB.string_cache (ambient_dialogue_section() reads only AMBIENT_STRINGS_DIR), or null
/proc/fixer_strings()
	if(!(FIXER_STRINGS_FIXER in GLOB.string_cache))
		if(!fexists("[FIXER_STRINGS_DIR]/[FIXER_STRINGS_FIXER]"))
			return null
		load_strings_file(FIXER_STRINGS_FIXER, FIXER_STRINGS_DIR)
	var/list/cache = GLOB.string_cache?[FIXER_STRINGS_FIXER]
	return islist(cache) ? cache : null

/// `voice`'s lines for `key`, falling back to the stand-in's, or an empty list
/proc/fixer_lines(voice, key)
	var/list/all = fixer_strings()
	var/list/section = all?[voice]
	var/list/lines = islist(section) ? section[key] : null
	if(!length(lines) && voice != FIXER_VOICE_STAND_IN && voice != FIXER_VOICE_GOSSIP)
		section = all?[FIXER_VOICE_STAND_IN]
		lines = islist(section) ? section[key] : null
	return islist(lines) ? lines : list()

/// One of `voice`'s lines for `key` with its tokens filled from `tokens` (missing ones get plain words), cut to FIXER_BOUND_LINE; "..." if there is none
/proc/fixer_line(voice, key, list/tokens)
	var/list/lines = fixer_lines(voice, key)
	var/line = length(lines) ? pick(lines) : null
	if(!istext(line))
		return "..."
	return fixer_cut(fixer_fill(line, tokens), FIXER_BOUND_LINE)

/// `line` with each token replaced: from `tokens`, else a plain word
/proc/fixer_fill(line, list/tokens)
	var/static/list/plain = list(
		FIXER_TOKEN_NAME = "a man",
		FIXER_TOKEN_LOOK = "you'll know him",
		FIXER_TOKEN_CLOCK = "next",
		FIXER_TOKEN_PLACE = "here",
		FIXER_TOKEN_TO = "the next port",
	)
	for(var/token in plain)
		if(!findtext(line, token))
			continue
		var/value = tokens?[token]
		line = replacetext(line, token, (istext(value) && length(value)) ? value : plain[token])
	return line

/// `text` cut to `bound` characters, the last one an ellipsis when it was longer
/proc/fixer_cut(text, bound)
	if(!istext(text))
		return ""
	if(length_char(text) <= bound)
		return text
	return "[copytext_char(text, 1, bound)]…"

/// `amount` with a thousands separator: 6240 -> "6,240"
/proc/fixer_credits_text(amount)
	var/digits = num2text(round(abs(amount)), 12)
	var/out = ""
	while(length(digits) > 3)
		out = ",[copytext(digits, -3)][out]"
		digits = copytext(digits, 1, -3)
	return "[amount < 0 ? "-" : ""][digits][out]"

/**
 * What is wrong with FIXER_STRINGS_FIXER (the loader test): a speaker missing a key or holding fewer than two lines
 * for it, a line over FIXER_BOUND_LINE with every token at its bound, a banned word (spec 11), or a job kind with
 * no gossip. An empty list when it is right.
 */
/proc/fixer_strings_problems()
	. = list()
	var/list/all = fixer_strings()
	if(!all)
		return list("[FIXER_STRINGS_FIXER] is missing or not a JSON object")
	var/static/list/keys = list(
		FIXER_LINE_NO_SHIP, FIXER_LINE_NO_TRUST, FIXER_LINE_WANTED, FIXER_LINE_OFFICER, FIXER_LINE_NOTHING,
		FIXER_LINE_BURNED, FIXER_LINE_TROUBLE, FIXER_LINE_BUSY, FIXER_LINE_GONE, FIXER_LINE_TAKEN,
		FIXER_LINE_PAY_CLEAN, FIXER_LINE_PAY_SOME, FIXER_LINE_PAY_LOUD, FIXER_LINE_FAILED, FIXER_LINE_SPOILED,
		FIXER_LINE_WAIT, FIXER_LINE_NOT_YOURS, FIXER_LINE_WRONG_FIXER, FIXER_LINE_WHERE, FIXER_LINE_OFFER_SABOTAGE,
		FIXER_LINE_OFFER_SMUGGLE, FIXER_LINE_OFFER_BREAKIN, FIXER_LINE_OFFER_HIT, FIXER_LINE_OFFER_EVIDENCE,
		FIXER_LINE_OFFER_JAILBREAK, FIXER_LINE_REPEAT, FIXER_LINE_IDLE,
	)
	var/static/list/longest = list(
		FIXER_TOKEN_NAME = FIXER_BOUND_NAME,
		FIXER_TOKEN_LOOK = FIXER_BOUND_LOOK,
		FIXER_TOKEN_CLOCK = 5,
		FIXER_TOKEN_PLACE = FIXER_BOUND_PLACE,
		FIXER_TOKEN_TO = FIXER_BOUND_TO,
	)
	var/list/at_bounds = list()
	for(var/token in longest)
		var/filler = ""
		for(var/i in 1 to longest[token])
			filler += "x"
		at_bounds[token] = filler
	for(var/voice in list(FIXER_VOICE_NAN, FIXER_VOICE_LOT, FIXER_VOICE_QUILL, FIXER_VOICE_STAND_IN))
		var/list/section = all[voice]
		if(!islist(section))
			. += "speaker [voice] is missing"
			continue
		for(var/key in keys)
			var/list/lines = section[key]
			if(!islist(lines) || length(lines) < 2)
				. += "[voice]/[key] has fewer than two lines"
		for(var/key in section)
			. += fixer_line_problems("[voice]/[key]", section[key], at_bounds)
	var/list/gossip = all[FIXER_VOICE_GOSSIP]
	for(var/kind in list(FIXER_JOB_SABOTAGE, FIXER_JOB_SMUGGLE, FIXER_JOB_BREAKIN, FIXER_JOB_HIT, FIXER_JOB_EVIDENCE, FIXER_JOB_JAILBREAK))
		var/list/lines = islist(gossip) ? gossip[kind] : null
		if(!length(lines))
			. += "gossip/[kind] has no lines"
		else
			. += fixer_line_problems("gossip/[kind]", lines, at_bounds)

/// The problems with `lines` (under `label`): not text, too long with every token at its bound, or a banned word
/proc/fixer_line_problems(label, list/lines, list/at_bounds)
	. = list()
	var/static/regex/banned = regex(@"\b(bonus|clean|stars?|witness(es)?|noise|grade|tier|trust|cooldown|missions?|fixers?)\b", "i")
	if(!islist(lines))
		return list("[label] is not a list")
	for(var/line in lines)
		if(!istext(line))
			. += "[label] holds something that is not a line"
			continue
		var/filled = line
		for(var/token in at_bounds)
			filled = replacetext(filled, token, at_bounds[token])
		if(length_char(filled) > FIXER_BOUND_LINE)
			. += "[label] line over [FIXER_BOUND_LINE] characters: [line]"
		if(banned.Find(line))
			. += "[label] line has a banned word: [line]"

#undef FIXER_VOICE_GOSSIP
