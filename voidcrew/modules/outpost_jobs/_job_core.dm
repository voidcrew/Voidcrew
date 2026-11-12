/**
 * # Outpost jobs: the job shell
 *
 * Owner: P2. /datum/mission/fixer_job, the base of every fixer job (spec 4). A real mission held by the ship, paid by
 * finish_mission(), never on a board (weight 0) and never safe work. P0 declared every shared var and stubbed every
 * base proc so the game behaves as before: nothing makes a fixer job until the fixers and P2 land.
 *
 * Shared vars and procs are the build plan's section 5.2: callers in other packages use these names statically.
 * Do not rename a var or proc, or change a signature, without the lead.
 */

/datum/mission/fixer_job
	name = "Odd job"
	desc = "Work for a friend of a friend."
	weight = 0
	safe_work = FALSE
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

/datum/mission/fixer_job/Destroy()
	job_outpost = null
	pay_outpost = null
	giver_outpost = null
	QDEL_NULL(ledger)
	roster = null
	goods_ref = null
	job_atoms = null
	return ..()

/// Places the job's people and things and track()s each. FALSE if there is no room. Each job package overrides.
/datum/mission/fixer_job/proc/stage()
	return FALSE

/// Sends the job's people away in the world when watched and removes the rest. Each job package overrides, calling parent.
/datum/mission/fixer_job/proc/unstage()
	for(var/datum/weakref/ref as anything in job_atoms)
		var/atom/movable/thing = ref?.resolve()
		if(!QDELETED(thing))
			qdel(thing)
	job_atoms?.Cut()

/// Whether this job can be on `outpost`'s fixer's slate for `crew`. Each job package overrides.
/datum/mission/fixer_job/proc/allowed_at(obj/structure/overmap/trader_outpost/outpost, datum/voidcrew_crew_record/crew)
	return TRUE

/**
 * The offer's tokens: list(FIXER_TOKEN_NAME = ..., FIXER_TOKEN_LOOK = ..., FIXER_TOKEN_CLOCK = ..., FIXER_TOKEN_PLACE = ...,
 * FIXER_TOKEN_TO = ...), each already cut to its bound and html_encode()d. Each job package overrides.
 */
/datum/mission/fixer_job/proc/offer_tokens()
	return list()

/// Up to FIXER_NOTE_LINES strings for the note, each within FIXER_BOUND_NOTE_LINE. Each job package overrides.
/datum/mission/fixer_job/proc/note_lines()
	return list()

/// Time ran out before the deed: what the world shows, then parent. Each job package overrides.
/datum/mission/fixer_job/proc/on_deadline()
	fail_reason ||= FIXER_FAIL_DEADLINE
	fail()

/// Whether `who` was on the roster at accept, or is on the accepting crew record now. P2.
/datum/mission/fixer_job/proc/on_roster(datum/mind/who)
	return FALSE

/// Registers `thing` for cleanup and, if `scene`, as a victim the scene reading counts. P2.
/datum/mission/fixer_job/proc/track(atom/thing, scene = TRUE)
	return

/// The deed is done by `doer`: the hands rule, the deadline stops, the backstop starts, the port reading is taken. P2.
/datum/mission/fixer_job/proc/mark_deed(mob/living/doer)
	deed_done = TRUE

/// An outsider's hand did it: the job fails as FIXER_FAIL_SPOILED. P2.
/datum/mission/fixer_job/proc/spoil(mob/living/outsider)
	fail_reason = FIXER_FAIL_SPOILED
	fail()

/// Noise 0-3 (spec 5.2). P2.
/datum/mission/fixer_job/proc/noise()
	return 0

/// A FIXER_LINE_* refusal key if `user` cannot be paid by `fixer` now, or null. P2.
/datum/mission/fixer_job/proc/can_pay(mob/living/user, mob/fixer)
	return null

/// Sets `value`, turns the mission in with `fixer` as the anchor, returns the credits paid. P2.
/datum/mission/fixer_job/proc/pay_out(mob/living/user, mob/fixer)
	return 0

/// TRUE if the deadline was put off by FIXER_DEADLINE_HOLD (spec 4.6). P2.
/datum/mission/fixer_job/proc/hold_deadline()
	return FALSE
