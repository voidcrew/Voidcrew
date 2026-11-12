/**
 * # Outpost jobs: the job shell
 *
 * Owner: P2. /datum/mission/fixer_job, the base of every fixer job (spec 4). A real mission held by the ship, paid by
 * finish_mission(), never on a board (weight 0) and never safe work.
 *
 * Shared vars and procs are the build plan's section 5.2: callers in other packages use these names statically.
 * Do not rename a var or proc, or change a signature, without the lead.
 *
 * How a job runs:
 * - P1 makes it (`new type()`), sets `job_outpost`, and accepts it through `ship.accept_mission()`. The outpost
 *   target is bound on first need (bind_target(), from can_accept_work() and start_mission()), so the zone rule of
 *   every mission gates it. Once bound, `value` is the quoted pay, the figure for the note: base x zone, to 10.
 * - On start: the roster is fixed, the ledger starts listening, then stage(). A stage() that finds no room fails the
 *   job as FIXER_FAIL_STAGING with no notice and no rest.
 * - The job package calls mark_deed(doer) when the deed is done: an outsider's hand spoils the job instead. The
 *   deadline gives way to the FIXER_COLLECT_TIME backstop and the ledger reads the port.
 * - P1's "It's done." asks can_pay(), then pay_out(): value by noise and zone, into the ship's account, with the
 *   fixer's receipt as the ship's notice.
 * - Any end (paid, failed, deleted) unstages: every tracked atom goes, the goods with them.
 *
 * A job package that walks its people out itself in unstage() takes them off `job_atoms` first
 * (`job_atoms -= WEAKREF(npc)`) and then calls parent, which removes the rest.
 */

/// Noise at which the bonus is gone (FIXER_GRADE_SHARE's last entry); noise() never reports more
#define FIXER_GRADE_LOUD_NOISE 3

/datum/mission/fixer_job
	name = "Odd job"
	desc = "Work for a friend of a friend."
	weight = 0
	safe_work = FALSE
	value_min = 0
	value_max = 0
	/// FIXER_JOB_*: set by the subtype
	var/job_kind
	/// The trader outpost the job is done at: set by P1 when the slate entry is made
	var/obj/structure/overmap/trader_outpost/job_outpost
	/// The outpost whose fixer pays, or null for any fixer: P4 sets it (the smuggle destination)
	var/obj/structure/overmap/trader_outpost/pay_outpost
	/// Green base pay (FIXER_PAY_*): the subtype
	var/base_pay = 0
	/// Noise below this is not counted (FIXER_JAILBREAK_FLOOR for the jailbreak): the subtype
	var/noise_floor = 0
	/// Jobs paid before a crew is offered this (0, FIXER_TRUST_TIER1 or FIXER_TRUST_TIER2): the subtype
	var/trust_tier = 0
	/// Weight on a fixer's slate (FIXER_WEIGHT_*): the subtype
	var/slate_weight = 0
	/// OUTPOST_CRIME_* counted as of the job's own kind wherever they happen at the job's outpost (spec 5.2 scene): the subtype
	var/list/scene_crimes = list()
	/// Weakrefs to the minds on the accepting crew at accept: P2
	var/list/datum/weakref/roster = list()
	/// The job's ledger: P2
	var/datum/fixer_ledger/ledger
	/// The deed is done: P2's mark_deed()
	var/deed_done = FALSE
	/// The goods' type (/obj/item/mission_recovery/fixer_goods/*), or null for a job with no goods: the subtype
	var/goods_type
	/// Weakref to the goods once made: P2
	var/datum/weakref/goods_ref
	/// Weakrefs to every atom the job placed: P2's track()
	var/list/datum/weakref/job_atoms = list()
	/// The outpost whose fixer gave the job: P1 at accept
	var/obj/structure/overmap/trader_outpost/giver_outpost
	/// FIXER_FAIL_*: P2
	var/fail_reason

	// ----- P2's own (not part of the shared API) -----
	/// Weakrefs to the job atoms a crime against counts for the scene reading (a subset of job_atoms)
	var/list/datum/weakref/scene_refs = list()
	/// world.time the deed was done, or 0
	var/deed_at = 0
	/// Weakref to the player who did the deed, or null for no player (a guard's stray round, a fall)
	var/datum/weakref/doer_ref
	/// The network has been told this job failed (note_failed() is called once)
	var/failure_noted = FALSE
	/// Set by pay_out() for the turn-in that follows: list(noise, fixer)
	var/list/paying
	/// The noise the job was paid at, kept for whoever asks noise() after the pay (the ledger is gone by then)
	var/paid_noise
#ifdef UNIT_TESTS
	/// Tests: what the base stage() returns (a job package's stage() ignores it)
	var/test_stage_result = FALSE
#endif

/datum/mission/fixer_job/Destroy()
	if(active && !completed && !failed && !failure_noted)
		fail_reason ||= FIXER_FAIL_GONE
		failure_noted = TRUE
		GLOB.fixer_network.note_failed(src, fail_reason)
	drop_goods()
	unstage()
	job_outpost = null
	pay_outpost = null
	giver_outpost = null
	QDEL_NULL(ledger)
	roster = null
	goods_ref = null
	job_atoms = null
	scene_refs = null
	doer_ref = null
	paying = null
	return ..()

// =========================================================================
// THE MISSION SHELL
// =========================================================================

/// The target is the job's own outpost, bound on first need (P1 sets job_outpost after New())
/datum/mission/fixer_job/setup_target()
	bind_target()
	return TRUE

/// No board quote: the pay is the job's own table (bind_target()), the zone is the job's outpost
/datum/mission/fixer_job/generate_details()
	return

/// Fixer jobs give no trade reputation (L14): no work receipt, so claim_work_receipt() gives 0
/datum/mission/fixer_job/prepare_work_receipt()
	return

/// Binds the target before the zone rule is read
/datum/mission/fixer_job/can_accept_work(obj/structure/overmap/ship/ship)
	if(!bind_target())
		return FALSE
	return ..()

/datum/mission/fixer_job/start_mission(obj/structure/overmap/ship/ship)
	if(!bind_target())
		return FALSE
	return ..()

/**
 * Makes `target` a fixed /datum/mission_target/outpost/fixer on job_outpost, the quote zone its zone and `value` the
 * quoted pay. TRUE when the job has its outpost. Idempotent.
 */
/datum/mission/fixer_job/proc/bind_target()
	if(QDELETED(job_outpost))
		return FALSE
	var/datum/mission_target/outpost/fixer/fixed = target
	if(istype(fixed) && fixed.outpost == job_outpost)
		return TRUE
	if(target)
		if(active)
			return FALSE // An active job never changes outposts
		QDEL_NULL(target)
	fixed = new(src)
	if(!fixed.resolve())
		qdel(fixed)
		return FALSE
	target = fixed
	quote_zone = fixed.get_zone_type()
	value = fixer_job_pay(base_pay, pay_zone(), FIXER_GRADE_LOUD_NOISE)
	update_text()
	return TRUE

/// No helm marker: the note is the whole interface (L2)
/datum/mission/fixer_job/get_waypoint_info()
	return null

/datum/mission/fixer_job/get_archetype()
	return "fixer"

/// Any living fixer takes "It's done." (L8); a smuggle's case goes only to its own (can_pay() says which)
/datum/mission/fixer_job/can_turn_in_at(atom/reward_anchor)
	return istype(reward_anchor, /mob/living/carbon/human/npc/ambient_npc/outpost/fixer)

/datum/mission/fixer_job/get_wrong_location_reason(atom/reward_anchor)
	return "Not here."

/// The outpost went away under the job
/datum/mission/fixer_job/on_target_lost()
	if(failed || completed)
		return
	fail_reason = FIXER_FAIL_GONE
	fail()

/// Outposts never move
/datum/mission/fixer_job/on_target_moved()
	return

/// The deadline, or the backstop after the deed, came due
/datum/mission/fixer_job/on_timeout()
	timeout_timer = null
	if(failed || completed)
		return
	if(hold_deadline())
		return
	if(deed_done)
		fail_reason = FIXER_FAIL_UNCOLLECTED
		fail()
		return
	on_deadline()

/**
 * Fails the job. The network hears it once (note_failed()), and the ship's notice is in the world's words, or none
 * at all for a job that never got going (FIXER_FAIL_STAGING). A fail with no reason set is a drop ("Forget it.", or
 * the ship's console).
 */
/datum/mission/fixer_job/fail(reason = "Mission failed.")
	if(failed || completed)
		return
	fail_reason ||= FIXER_FAIL_DROPPED
	log_game("FIXER JOB: [name] ([type]) for [servant?.name || "no ship"] failed: [fail_reason].")
	if(!failure_noted)
		failure_noted = TRUE
		GLOB.fixer_network.note_failed(src, fail_reason)
	var/notice = fixer_job_fail_notice(fail_reason)
	if(!notice && servant)
		// No notice: as far as the crew can tell, the job never started
		var/obj/structure/overmap/ship/ship = servant
		ship.remove_waypoint(REF(src))
		ship.active_missions -= src
		servant = null
	return ..(notice || reason)

/// The fixer's receipt (spec 4.5): the one "Paid to the ship" line, to the whole crew wherever they are (the pay is
/// made at a fixer, not aboard). No reputation, no grade. Nothing else says it.
/datum/mission/fixer_job/notify_completed(reputation_gain)
	servant.ship_notify("Paid to the ship: [fixer_credits_text(value)] cr.", "ACCOUNT", SHIP_NOTIFY_NOTICE, 'voidcrew/sound/notify.ogg', 50, TRUE)

/// The network hears of the pay while the job still knows its crew and outposts (before the shell qdels it)
/datum/mission/fixer_job/finish_mission(atom/reward_anchor)
	if(QDELETED(src) || failed || completed)
		return
	if(paying)
		GLOB.fixer_network.note_paid(src, paying[1], paying[2])
	return ..()

/// Roster, ledger, then the job's people and things. A job with no room fails quietly (spec 4.2).
/datum/mission/fixer_job/on_mission_started()
	begin_job()

/// Fixes the roster, opens the ledger and stages the job. Tests call it with servant and accepting_crew set by hand.
/datum/mission/fixer_job/proc/begin_job()
	roster = list()
	if(accepting_crew)
		for(var/datum/mind/member as anything in accepting_crew.minds)
			if(!QDELETED(member))
				roster += WEAKREF(member)
	QDEL_NULL(ledger)
	ledger = new(src)
	if(job_outpost)
		ledger.watch(job_outpost.ensure_police())
	if(pay_outpost && pay_outpost != job_outpost)
		ledger.watch(pay_outpost.ensure_police())
	if(!stage())
		fail_reason = FIXER_FAIL_STAGING
		fail()
		return FALSE
	log_game("FIXER JOB: the [servant?.name || "no ship"] took [name] ([type]) at [job_outpost], [value] cr quoted.")
	return TRUE

// =========================================================================
// THE JOB'S OWN API (build plan 5.2)
// =========================================================================

/// Places the job's people and things and track()s each. FALSE if there is no room. Each job package overrides.
/datum/mission/fixer_job/proc/stage()
#ifdef UNIT_TESTS
	return test_stage_result
#else
	return FALSE
#endif

/**
 * Sends the job's people away in the world when watched and removes the rest. Each job package overrides, calling
 * parent. Here: every tracked atom is deleted, except one off its outpost with a player near, which goes once
 * nobody is (fixer_job_remove_unseen()).
 */
/datum/mission/fixer_job/proc/unstage()
	if(!job_atoms)
		return
	for(var/datum/weakref/ref as anything in job_atoms)
		var/atom/movable/thing = ref?.resolve()
		if(QDELETED(thing))
			continue
		var/turf/where = get_turf(thing)
		if(where && job_outpost && get_trader_outpost_for_turf(where) != job_outpost && human_npc_watched(thing))
			fixer_job_remove_unseen(thing)
			continue
		qdel(thing)
	job_atoms.Cut()
	scene_refs?.Cut()

/// Whether this job can be on `outpost`'s fixer's slate for `crew`. Each job package overrides.
/datum/mission/fixer_job/proc/allowed_at(obj/structure/overmap/trader_outpost/outpost, datum/voidcrew_crew_record/crew)
	return TRUE

/**
 * The offer's tokens: list(FIXER_TOKEN_NAME = ..., FIXER_TOKEN_LOOK = ..., FIXER_TOKEN_CLOCK = ..., FIXER_TOKEN_PLACE = ...,
 * FIXER_TOKEN_TO = ...), each already cut to its bound and html_encode()d. Each job package overrides.
 */
/datum/mission/fixer_job/proc/offer_tokens()
	return list()

/// Up to FIXER_NOTE_LINES strings for the note, each already cut to FIXER_BOUND_NOTE_LINE and then html_encode()d
/// (the job encodes; the note uses them as they are). Each job package overrides.
/datum/mission/fixer_job/proc/note_lines()
	return list()

/// Time ran out before the deed: what the world shows, then parent. Each job package overrides.
/datum/mission/fixer_job/proc/on_deadline()
	fail_reason ||= FIXER_FAIL_DEADLINE
	fail()

/// Whether `who` was on the roster at accept, or is on the accepting crew record now
/datum/mission/fixer_job/proc/on_roster(datum/mind/who)
	if(QDELETED(who))
		return FALSE
	for(var/datum/weakref/ref as anything in roster)
		if(ref?.resolve() == who)
			return TRUE
	return !QDELETED(accepting_crew) && who.get_reputation_crew() == accepting_crew

/// Registers `thing` for cleanup and, if `scene`, as a victim the scene reading counts
/datum/mission/fixer_job/proc/track(atom/thing, scene = TRUE)
	if(QDELETED(thing) || QDELETED(src) || !job_atoms)
		return
	var/datum/weakref/ref = WEAKREF(thing)
	job_atoms |= ref
	if(scene)
		scene_refs |= ref

/**
 * The deed is done by `doer` (a mob, or null when no player did it). The hands rule (spec 4.3): a player off the
 * roster spoils the job instead. Otherwise the deadline gives way to the FIXER_COLLECT_TIME backstop and the ledger
 * takes its port reading where the deed was done. TRUE when the deed counts for the crew.
 */
/datum/mission/fixer_job/proc/mark_deed(mob/living/doer)
	if(QDELETED(src) || failed || completed || !active)
		return FALSE
	if(deed_done)
		return TRUE
	if(fixer_job_is_player(doer) && !on_roster(doer.mind))
		spoil(doer)
		return FALSE
	deed_done = TRUE
	deed_at = world.time
	doer_ref = fixer_job_is_player(doer) ? WEAKREF(doer) : null
	var/obj/structure/overmap/trader_outpost/where = doer ? get_trader_outpost_for_turf(get_turf(doer)) : null
	ledger?.take_port_reading(where?.police || job_outpost?.police)
	if(timeout_timer)
		deltimer(timeout_timer)
	timeout_timer = addtimer(CALLBACK(src, PROC_REF(on_timeout)), FIXER_COLLECT_TIME, TIMER_STOPPABLE)
	log_game("FIXER JOB: [name] for the [servant?.name || "no ship"] done by [doer ? key_name(doer) : "nobody"] at [AREACOORD(doer || job_outpost)].")
	return TRUE

/// An outsider's hand did it: the job fails as FIXER_FAIL_SPOILED
/datum/mission/fixer_job/proc/spoil(mob/living/outsider)
	if(QDELETED(src) || failed || completed)
		return
	log_game("FIXER JOB: [name] for the [servant?.name || "no ship"] spoiled by [outsider ? key_name(outsider) : "someone"].")
	fail_reason = FIXER_FAIL_SPOILED
	fail()

/**
 * Noise 0-3 (spec 5.2): the highest of the crew, scene and port readings and any report still on its way (5.4).
 * With a noise floor (the jailbreak), what is over the floor; otherwise 0 only when nothing was counted and the port
 * was quiet, else at least 1.
 */
/datum/mission/fixer_job/proc/noise()
	if(!isnull(paid_noise))
		return paid_noise
	if(!ledger)
		return 0
	var/pending = ledger.pending()
	var/raw = max(ledger.crew_reading, ledger.scene_reading, ledger.port_reading, pending)
	if(noise_floor > 0)
		return clamp(raw - noise_floor, 0, FIXER_GRADE_LOUD_NOISE)
	if(!ledger.counted && pending <= 0 && ledger.port_reading <= 0)
		return 0
	return clamp(raw, 1, FIXER_GRADE_LOUD_NOISE)

/**
 * A FIXER_LINE_* refusal key if `user` cannot be paid by `fixer` now, or null. Spec 4.5's order: the asker is on the
 * roster; nobody on the roster is wanted at the fixer's outpost and no officer is close; a smuggle's case is at its
 * own fixer; the deed is done (a smuggle's hand-over is its deed); the goods are in hand; no report is on its way.
 */
/datum/mission/fixer_job/proc/can_pay(mob/living/user, mob/fixer)
	if(QDELETED(src) || failed || completed || !active || QDELETED(user) || QDELETED(fixer))
		return FIXER_LINE_NOTHING
	if(QDELETED(servant) || QDELETED(servant.ship_account))
		return FIXER_LINE_NO_SHIP
	if(!on_roster(user.mind))
		return FIXER_LINE_NOT_YOURS
	var/obj/structure/overmap/trader_outpost/here = get_trader_outpost_for_turf(get_turf(fixer))
	var/datum/outpost_police/police = here?.police
	if(police)
		for(var/datum/mind/member as anything in roster_minds())
			if(police.get_stars(member) > 0)
				return FIXER_LINE_WANTED
		for(var/mob/living/carbon/human/npc/ambient_npc/outpost/police/officer in police.officers)
			if(QDELETED(officer) || officer.stat == DEAD || officer.fading)
				continue
			if(get_dist(officer, fixer) <= FIXER_OFFICER_RANGE && can_see(fixer, officer, FIXER_OFFICER_RANGE))
				return FIXER_LINE_OFFICER
	if(pay_outpost && here != pay_outpost)
		return FIXER_LINE_WRONG_FIXER
	if(!deed_done && !pay_outpost)
		return FIXER_LINE_NOTHING
	if(goods_type)
		var/obj/item/goods = goods_ref?.resolve()
		if(QDELETED(goods) || !(goods in user.held_items))
			return FIXER_LINE_WHERE
	if(ledger?.pending() > 0)
		return FIXER_LINE_WAIT
	return null

/// Sets `value` by noise and zone, turns the mission in with `fixer` as the anchor, returns the credits paid (0 if not)
/datum/mission/fixer_job/proc/pay_out(mob/living/user, mob/fixer)
	if(can_pay(user, fixer))
		return 0
	// A smuggle's hand-over is its deed (spec 6.2): deed and pay in one step
	if(!deed_done && !mark_deed(user))
		return 0
	var/job_noise = noise()
	value = fixer_job_pay(base_pay, pay_zone(), job_noise)
	// The goods go with the job when the shell deletes it (drop_goods())
	var/paid = value
	var/ship_name = servant?.name
	paying = list(job_noise, fixer)
	paid_noise = job_noise
	if(!turn_in(fixer) || !completed)
		paying = null
		paid_noise = null
		return 0
	log_game("FIXER JOB: [key_name(user)] of the [ship_name] was paid [paid] cr by [fixer] at noise [job_noise].")
	return paid

/**
 * TRUE if the deadline was put off by FIXER_DEADLINE_HOLD (spec 4.6): before the deed, the job's outpost is shut by
 * its recovery or a smuggle's destination has no living fixer; after it, no fixer is alive anywhere to pay.
 */
/datum/mission/fixer_job/proc/hold_deadline()
	if(failed || completed)
		return FALSE
	var/hold = FALSE
	if(deed_done)
		hold = !GLOB.fixer_network.any_fixer_alive()
	else
		var/datum/outpost_recovery/recovery = job_outpost?.recovery
		if(recovery && world.time < recovery.port_shut_until)
			hold = TRUE
		else if(pay_outpost && !GLOB.fixer_network.fixer_at(pay_outpost))
			hold = TRUE
	if(!hold)
		return FALSE
	if(timeout_timer)
		deltimer(timeout_timer)
	timeout_timer = addtimer(CALLBACK(src, PROC_REF(on_timeout)), FIXER_DEADLINE_HOLD, TIMER_STOPPABLE)
	return TRUE

// =========================================================================
// P2 HELPERS
// =========================================================================

/// The zone the job pays in: its outpost's, or the higher of both ends for a run to another outpost. Green if unknown.
/datum/mission/fixer_job/proc/pay_zone()
	. = fixer_outpost_zone(job_outpost)
	if(pay_outpost)
		. = max(., fixer_outpost_zone(pay_outpost))

/// Every mind the hands rule and the ledger treat as the crew's: the roster and whoever is on the accepting crew now
/datum/mission/fixer_job/proc/roster_minds()
	. = list()
	for(var/datum/weakref/ref as anything in roster)
		var/datum/mind/member = ref?.resolve()
		if(!QDELETED(member))
			. |= member
	if(!QDELETED(accepting_crew))
		for(var/datum/mind/member as anything in accepting_crew.minds)
			if(!QDELETED(member))
				. |= member

/// The scene atoms still in the world
/datum/mission/fixer_job/proc/scene_atoms()
	. = list()
	for(var/datum/weakref/ref as anything in scene_refs)
		var/atom/thing = ref?.resolve()
		if(!QDELETED(thing))
			. += thing

/// Whether a crime against `victim` is a crime against the job
/datum/mission/fixer_job/proc/is_scene_victim(atom/victim)
	if(!victim || !length(scene_refs))
		return FALSE
	for(var/datum/weakref/ref as anything in scene_refs)
		if(ref?.resolve() == victim)
			return TRUE
	return FALSE

/// The goods go with the job, wherever they are (spec 4.7). Goods in the middle of a pickup go a moment later.
/datum/mission/fixer_job/proc/drop_goods()
	var/obj/item/mission_recovery/fixer_goods/goods = goods_ref?.resolve()
	goods_ref = null
	if(QDELETED(goods))
		return
	job_atoms -= WEAKREF(goods)
	goods.job_ref = null
	if(goods.handling)
		QDEL_IN(goods, 1)
	else
		qdel(goods)

// =========================================================================
// THE TARGET: the job's own outpost, never another
// =========================================================================

/datum/mission_target/outpost/fixer

/datum/mission_target/outpost/fixer/resolve()
	unhook()
	var/datum/mission/fixer_job/job = mission
	if(!istype(job) || QDELETED(job.job_outpost))
		return FALSE
	outpost = job.job_outpost
	cache_coords_from(outpost)
	RegisterSignal(outpost, COMSIG_QDELETING, PROC_REF(on_outpost_deleted))
	return TRUE

/// The zone the job is gated and paid by: the same reading as pay_zone() (green when the outpost's tile has no zone)
/datum/mission_target/outpost/fixer/get_zone_type()
	if(!outpost)
		return null
	return fixer_outpost_zone(outpost)

// =========================================================================
// GLOBAL HELPERS
// =========================================================================

/// Credits paid for a job of green base `base` in `zone` (ZONE_*) at `noise`: base x zone x (1 + bonus x grade share), to 10
/proc/fixer_job_pay(base, zone, noise)
	var/list/zone_pay = FIXER_ZONE_PAY
	var/list/grade_share = FIXER_GRADE_SHARE
	var/zone_mult = zone_pay[clamp(isnum(zone) ? zone : ZONE_GREEN, 1, length(zone_pay))]
	var/share = grade_share[clamp(round(noise) + 1, 1, length(grade_share))]
	return round(base * zone_mult * (1 + FIXER_BONUS_SHARE * share), 10)

/// `outpost`'s zone (ZONE_*), green if it cannot be told
/proc/fixer_outpost_zone(obj/structure/overmap/trader_outpost/outpost)
	if(QDELETED(outpost))
		return ZONE_GREEN
	var/zone = SSovermap_zones?.get_zone_type(get_turf(outpost))
	return (zone in list(ZONE_GREEN, ZONE_YELLOW, ZONE_RED)) ? zone : ZONE_GREEN

/// Whether `who` is a player for the hands rule: a living mob with a mind that is not one of the town's NPCs
/proc/fixer_job_is_player(mob/living/who)
	return isliving(who) && !QDELETED(who) && !!who.mind && !ishumannpc(who)

/// The ship's notice for a job that failed for `reason` (FIXER_FAIL_*), or null for none
/proc/fixer_job_fail_notice(reason)
	switch(reason)
		if(FIXER_FAIL_STAGING)
			return null
		if(FIXER_FAIL_DEADLINE)
			return "Too late. The work is off."
		if(FIXER_FAIL_DROPPED)
			return "Dropped."
		if(FIXER_FAIL_LOST)
			return "It fell through."
		if(FIXER_FAIL_SPOILED)
			return "Somebody else got there first."
		if(FIXER_FAIL_UNCOLLECTED)
			return "Nobody came for the money."
	return "The work is off."

/**
 * Removes `thing` once no player is near it (human_npc_watched()), looking again every 10 seconds, and after
 * 10 minutes regardless. For a job's leftovers off its outpost (spec 4.7).
 */
/proc/fixer_job_remove_unseen(atom/movable/thing, tries = 60)
	if(QDELETED(thing))
		return
	if(tries <= 0 || !human_npc_watched(thing))
		qdel(thing)
		return
	addtimer(CALLBACK(GLOBAL_PROC, GLOBAL_PROC_REF(fixer_job_remove_unseen), thing, tries - 1), 10 SECONDS)

#undef FIXER_GRADE_LOUD_NOISE
