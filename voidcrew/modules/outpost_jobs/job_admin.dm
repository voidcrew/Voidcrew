/**
 * # Outpost jobs: admin and metrics
 *
 * Owner: P8. The "Fixer Jobs" admin verb (spec 12) and the two fixer job metric events (build plan 6.5). Admin text is
 * exempt from the player text rules.
 *
 * ## The panel
 *
 * Everything goes through /datum/fixer_admin_panel, the bounty panel's shape (bounties/bounty_admin.dm). The menu procs
 * (menu_*) ask the questions; the action procs (admin_*) take plain arguments, check the admin again, act, log and tell,
 * so a unit test can drive them without a client (it overrides authorized(), log_action(), tell() and the ask_*
 * prompts). An action that is refused returns null or FALSE and leaves the reason in `error`. Nothing is held across a
 * prompt but weakrefs.
 *
 * What it can do, and the package that owns the thing it touches:
 * - Give a job to a ship, staged now: GLOB.fixer_network.new_job() (P1), `giver_outpost` set, then the ship's own
 *   accept_mission() (P2's on_mission_started() does the roster, stage() and the ledger). See admin_make_job().
 * - Finish the deed: mark_deed() with a living roster member as the doer (P2).
 * - Set the noise: `admin_noise` below, read by noise() until it is cleared.
 * - Pay: pay_out() with a living roster member as the asker and the living fixer there (P2, P1's fixer_at()).
 * - Fail: fail_reason, then fail() (P2).
 * - Clear a crew's rest and burn, set its jobs paid: GLOB.fixer_network.clear_crew() and set_trust() (P1).
 * - Respawn a fixer: the ambient system's own role arrive() and settle() (P1's roles), after the dead fixer's place opens.
 * - Jump to a fixer, or to a thing a job placed (job_atoms).
 * - Print a job's ledger: ledger.report() (P2).
 *
 * ## The metrics
 *
 * Two rows, both METRIC_MISSION and written beside the mission shell's own rows (mission_completed, mission_failed):
 * - fixer_job_paid: the job was paid. subject = job_kind ("sabotage", "smuggle", "breakin", "hit", "evidence",
 *   "jailbreak"), zone = the job's outpost zone, ship = the crew's ship, ckey = the player who turned it in,
 *   credits = paid into the ship account, points = noise 0-3, quantity = 1. details: kind, outpost, seconds (accept to
 *   pay), and admin = 1 if an admin touched the job.
 * - fixer_job_failed: the job failed. subject = job_kind, zone and ship as above, ckey = the player who accepted it.
 *   details: reason (FIXER_FAIL_*), kind, outpost, seconds, and admin = 1 if an admin touched the job.
 * They are written from record_metric_completed() and record_metric_failed(), which the mission shell calls, so no
 * other package calls anything. An admin-forced pay or fail is marked and can be left out of a balance query.
 *
 * ## Two chained redefinitions
 *
 * noise() below is defined a second time on /datum/mission/fixer_job. DM chains duplicate definitions: this file is
 * included after _job_core.dm, so this body runs first and ..() reaches P2's. If P2's noise() ever moves to a file
 * included after this one, this body is skipped and "Set the noise" does nothing (the admin test catches it).
 * record_metric_completed() and record_metric_failed() are overrides of procs the metrics module declares earlier.
 */

/// Most questions one opening of the panel asks before it closes itself: a guard, never reached by hand
#define FIXER_ADMIN_MAX_STEPS 200
/// Most jobs paid an admin can set a crew to
#define FIXER_ADMIN_MAX_TRUST 99

// The main menu, in the order it shows
#define FIXER_ADMIN_MENU_GIVE "Give a job to a ship"
#define FIXER_ADMIN_MENU_JOBS "Live jobs"
#define FIXER_ADMIN_MENU_CREW "A crew's standing"
#define FIXER_ADMIN_MENU_FIXERS "The fixers"

// What can be done to a live job
#define FIXER_ADMIN_JOB_DEED "Finish the deed"
#define FIXER_ADMIN_JOB_NOISE "Set the noise"
#define FIXER_ADMIN_JOB_PAY "Pay it now"
#define FIXER_ADMIN_JOB_FAIL "Fail it"
#define FIXER_ADMIN_JOB_LEDGER "Print the ledger"
#define FIXER_ADMIN_JOB_ATOM "Jump to something of the job's"
#define FIXER_ADMIN_JOB_FIXER "Jump to a fixer"

// What can be done to a crew
#define FIXER_ADMIN_CREW_CLEAR "Clear rest and burn"
#define FIXER_ADMIN_CREW_TRUST "Set jobs paid"

// What can be done to an outpost's fixer
#define FIXER_ADMIN_FIXER_RESPAWN "Respawn the fixer"
#define FIXER_ADMIN_FIXER_JUMP "Jump to the fixer"

/// The noise menu's last entry: drop the admin's number and go back to the ledger's reading
#define FIXER_ADMIN_NOISE_LEDGER "Back to the ledger's reading"

ADMIN_VERB(fixer_jobs, R_ADMIN, "Fixer Jobs", "Give, finish, pay and fail fixer jobs, set a crew's standing with the fixers, and respawn or find a fixer.", ADMIN_CATEGORY_SHUTTLE)
	var/datum/fixer_admin_panel/panel = new(user.mob)
	BLACKBOX_LOG_ADMIN_VERB("Fixer Jobs")
	panel.run_menu(user.mob)
	qdel(panel)

/**
 * One opening of the Fixer Jobs panel by one admin. Holds nothing between actions but the admin and the last refusal;
 * it is deleted when the admin closes the menu.
 */
/datum/fixer_admin_panel
	/// The admin who opened it
	var/mob/admin
	/// Why the last action was refused, or null
	var/error

/datum/fixer_admin_panel/New(mob/user)
	. = ..()
	admin = user

/datum/fixer_admin_panel/Destroy()
	admin = null
	return ..()

// ===== CHECKS, LOGS AND PROMPTS =====
// A unit test overrides these to act without an admin client.

/// Whether `user` may use it now: the admin who opened it, still holding R_ADMIN. Checked again after every prompt.
/datum/fixer_admin_panel/proc/authorized(mob/user)
	return !QDELETED(src) && !isnull(user) && user == admin && check_rights_for(user.client, R_ADMIN)

/// Logs a done action
/datum/fixer_admin_panel/proc/log_action(mob/user, operation)
	log_admin("[key_name(user)] used Fixer Jobs to [operation].")
	message_admins("[key_name_admin(user)] used Fixer Jobs to [operation].")

/// Tells the admin something in chat
/datum/fixer_admin_panel/proc/tell(mob/user, message)
	to_chat(user, message)

/// A choice from `options` (the keys of an assoc list, or plain entries), or null if cancelled
/datum/fixer_admin_panel/proc/ask_list(mob/user, message, title, list/options)
	if(!length(options))
		return null
	return tgui_input_list(user, message, title || "Fixer Jobs", options)

/// A whole number from `min_value` to `max_value`, or null if cancelled
/datum/fixer_admin_panel/proc/ask_number(mob/user, message, title, default, max_value, min_value)
	return tgui_input_number(user, message, title || "Fixer Jobs", default, max_value, min_value)

/// Keeps `text` as the reason in `error` and tells the admin. Returns null, for `return refuse(...)`.
/datum/fixer_admin_panel/proc/refuse(mob/user, text)
	error = text
	tell(user, span_warning(text))
	return null

// ===== THE MENU =====

/// Asks what to do, does it and asks again, until the admin cancels
/datum/fixer_admin_panel/proc/run_menu(mob/user)
	var/static/list/menu = list(
		FIXER_ADMIN_MENU_GIVE,
		FIXER_ADMIN_MENU_JOBS,
		FIXER_ADMIN_MENU_CREW,
		FIXER_ADMIN_MENU_FIXERS,
	)
	for(var/asked in 1 to FIXER_ADMIN_MAX_STEPS)
		if(!authorized(user))
			return
		var/choice = ask_list(user, summary_text(), "Fixer Jobs", menu)
		if(!choice || !authorized(user))
			return
		error = null
		switch(choice)
			if(FIXER_ADMIN_MENU_GIVE)
				menu_give(user)
			if(FIXER_ADMIN_MENU_JOBS)
				menu_jobs(user)
			if(FIXER_ADMIN_MENU_CREW)
				menu_crew(user)
			if(FIXER_ADMIN_MENU_FIXERS)
				menu_fixers(user)

/// The menu's heading: how much is going on
/datum/fixer_admin_panel/proc/summary_text()
	var/live = length(live_jobs())
	var/fixers = 0
	for(var/obj/structure/overmap/trader_outpost/outpost as anything in GLOB.trader_outposts)
		if(!QDELETED(outpost) && GLOB.fixer_network.fixer_at(outpost))
			fixers++
	return "[live] live fixer job\s, [fixers] fixer\s alive."

/// Gives a job to a ship: which ship, which outpost's fixer gave it, which job, and for a smuggle where it runs to
/datum/fixer_admin_panel/proc/menu_give(mob/user)
	var/list/ships = ship_choices()
	if(!length(ships))
		refuse(user, "No ship with a crew exists.")
		return
	var/ship_choice = ask_list(user, "Give a job to which ship?", "Give a job", ships)
	if(!ship_choice || !authorized(user))
		return
	var/datum/weakref/ship_ref = ships[ship_choice]
	var/list/outposts = outpost_choices()
	if(!length(outposts))
		refuse(user, "There are no trader outposts.")
		return
	var/outpost_choice = ask_list(user, "Whose fixer gave it? The job is done at that outpost.", "Give a job", outposts)
	if(!outpost_choice || !authorized(user))
		return
	var/datum/weakref/outpost_ref = outposts[outpost_choice]
	var/list/jobs = job_type_choices()
	if(!length(jobs))
		refuse(user, "No fixer job has been built yet.")
		return
	var/job_choice = ask_list(user, "Which job?", "Give a job", jobs)
	if(!job_choice || !authorized(user))
		return
	var/datum/mission/fixer_job/job_type = jobs[job_choice]
	var/obj/structure/overmap/trader_outpost/destination
	if(initial(job_type.job_kind) == FIXER_JOB_SMUGGLE)
		var/list/others = outposts.Copy()
		others -= outpost_choice
		if(!length(others))
			refuse(user, "A smuggling run needs a second outpost to run to.")
			return
		var/destination_choice = ask_list(user, "Which outpost does the case run to?", "Give a job", others)
		if(!destination_choice || !authorized(user))
			return
		var/datum/weakref/destination_ref = others[destination_choice]
		destination = destination_ref?.resolve()
	admin_give_job(user, job_type, ship_ref?.resolve(), outpost_ref?.resolve(), destination)

/// Lists the live jobs, then acts on one
/datum/fixer_admin_panel/proc/menu_jobs(mob/user)
	var/list/choices = list()
	for(var/datum/mission/fixer_job/job as anything in live_jobs())
		choices[unique_label(choices, job_label(job))] = WEAKREF(job)
	if(!length(choices))
		tell(user, span_notice("No fixer jobs are live."))
		return
	var/job_choice = ask_list(user, "Which job?", "Live fixer jobs", choices)
	if(!job_choice || !authorized(user))
		return
	var/datum/weakref/job_ref = choices[job_choice]
	var/static/list/actions = list(
		FIXER_ADMIN_JOB_DEED,
		FIXER_ADMIN_JOB_NOISE,
		FIXER_ADMIN_JOB_PAY,
		FIXER_ADMIN_JOB_FAIL,
		FIXER_ADMIN_JOB_LEDGER,
		FIXER_ADMIN_JOB_ATOM,
		FIXER_ADMIN_JOB_FIXER,
	)
	var/action = ask_list(user, "Do what with it?", "Live fixer jobs", actions)
	if(!action || !authorized(user))
		return
	var/datum/mission/fixer_job/job = job_ref?.resolve()
	if(QDELETED(job))
		refuse(user, "That job is over.")
		return
	switch(action)
		if(FIXER_ADMIN_JOB_DEED)
			admin_finish_deed(user, job)
		if(FIXER_ADMIN_JOB_NOISE)
			var/list/noises = noise_choices()
			var/noise_choice = ask_list(user, "Count this much noise? Nothing is sent to the police.", "Set the noise", noises)
			if(!noise_choice || !authorized(user))
				return
			admin_set_noise(user, job, noises[noise_choice])
		if(FIXER_ADMIN_JOB_PAY)
			admin_pay(user, job)
		if(FIXER_ADMIN_JOB_FAIL)
			var/list/reasons = fail_choices()
			var/reason_choice = ask_list(user, "Fail it as what?", "Fail a job", reasons)
			if(!reason_choice || !authorized(user))
				return
			admin_fail(user, job, reasons[reason_choice])
		if(FIXER_ADMIN_JOB_LEDGER)
			admin_print_ledger(user, job)
		if(FIXER_ADMIN_JOB_ATOM)
			var/list/atoms = job_atom_choices(job)
			if(!length(atoms))
				refuse(user, "The job has placed nothing yet.")
				return
			var/atom_choice = ask_list(user, "Jump to which?", "Jump to a job atom", atoms)
			if(!atom_choice || !authorized(user))
				return
			var/datum/weakref/atom_ref = atoms[atom_choice]
			admin_jump(user, atom_ref?.resolve(), atom_choice)
		if(FIXER_ADMIN_JOB_FIXER)
			var/mob/living/fixer = pay_fixer(job)
			if(!fixer)
				refuse(user, "No fixer is alive.")
				return
			admin_jump(user, fixer, "a fixer")

/// A crew's standing: clear its rest and burn, or set its jobs paid
/datum/fixer_admin_panel/proc/menu_crew(mob/user)
	var/list/crews = crew_choices()
	if(!length(crews))
		refuse(user, "No crew records exist.")
		return
	var/crew_choice = ask_list(user, "Which crew?", "A crew's standing", crews)
	if(!crew_choice || !authorized(user))
		return
	var/datum/weakref/crew_ref = crews[crew_choice]
	var/static/list/actions = list(FIXER_ADMIN_CREW_CLEAR, FIXER_ADMIN_CREW_TRUST)
	var/action = ask_list(user, "Do what with it?", "A crew's standing", actions)
	if(!action || !authorized(user))
		return
	var/datum/voidcrew_crew_record/crew = crew_ref?.resolve()
	if(QDELETED(crew))
		refuse(user, "That crew is gone.")
		return
	switch(action)
		if(FIXER_ADMIN_CREW_CLEAR)
			admin_clear_crew(user, crew)
		if(FIXER_ADMIN_CREW_TRUST)
			var/paid = GLOB.fixer_network.trust_of(crew)
			var/amount = ask_number(user, "How many jobs has the network been paid for this crew? Now [paid].", "Set jobs paid", paid, FIXER_ADMIN_MAX_TRUST, 0)
			if(isnull(amount) || !authorized(user))
				return
			admin_set_trust(user, crew, amount)

/// An outpost's fixer: bring a new one, or go and look
/datum/fixer_admin_panel/proc/menu_fixers(mob/user)
	var/list/outposts = outpost_choices(TRUE)
	if(!length(outposts))
		refuse(user, "There are no trader outposts.")
		return
	var/outpost_choice = ask_list(user, "Which outpost?", "The fixers", outposts)
	if(!outpost_choice || !authorized(user))
		return
	var/datum/weakref/outpost_ref = outposts[outpost_choice]
	var/static/list/actions = list(FIXER_ADMIN_FIXER_RESPAWN, FIXER_ADMIN_FIXER_JUMP)
	var/action = ask_list(user, "Do what?", "The fixers", actions)
	if(!action || !authorized(user))
		return
	var/obj/structure/overmap/trader_outpost/outpost = outpost_ref?.resolve()
	if(QDELETED(outpost))
		refuse(user, "That outpost is gone.")
		return
	switch(action)
		if(FIXER_ADMIN_FIXER_RESPAWN)
			admin_respawn_fixer(user, outpost)
		if(FIXER_ADMIN_FIXER_JUMP)
			var/mob/living/fixer = GLOB.fixer_network.fixer_at(outpost)
			if(!fixer)
				refuse(user, "[outpost_name(outpost)] has no fixer alive.")
				return
			admin_jump(user, fixer, "the fixer at [outpost_name(outpost)]")

// ===== CHOICES =====

/// `label`, or `label (2)` and on if the list already has it: a tgui list needs unique entries
/datum/fixer_admin_panel/proc/unique_label(list/choices, label)
	if(!(label in choices))
		return label
	var/number = 2
	while("[label] ([number])" in choices)
		number++
	return "[label] ([number])"

/// Every live fixer job, on whichever ship holds it
/datum/fixer_admin_panel/proc/live_jobs()
	var/list/jobs = list()
	for(var/datum/mission/fixer_job/job in SSmissions.all_active_missions)
		if(!QDELETED(job))
			jobs += job
	return jobs

/// Every player ship that has a crew, for a job to be given to
/datum/fixer_admin_panel/proc/ship_choices()
	var/list/choices = list()
	for(var/obj/structure/overmap/ship/ship in SSovermap.simulated_ships)
		if(QDELETED(ship) || ship.abandoned || istype(ship, /obj/structure/overmap/ship/npc) || !ship.ship_team)
			continue
		choices[unique_label(choices, site_name(ship))] = WEAKREF(ship)
	return choices

/// Every trader outpost, labelled with its zone and, if `with_fixer`, whether its fixer is alive
/datum/fixer_admin_panel/proc/outpost_choices(with_fixer = FALSE)
	var/list/choices = list()
	for(var/obj/structure/overmap/trader_outpost/outpost as anything in GLOB.trader_outposts)
		if(QDELETED(outpost))
			continue
		var/label = "[outpost_name(outpost)], [zone_word(outpost)]"
		if(with_fixer)
			label += GLOB.fixer_network.fixer_at(outpost) ? ", fixer alive" : ", no fixer"
		choices[unique_label(choices, label)] = WEAKREF(outpost)
	return choices

/// The job types that can be given, labelled by kind: every subtype that names its kind
/datum/fixer_admin_panel/proc/job_type_choices()
	var/list/choices = list()
	for(var/datum/mission/fixer_job/job_type as anything in subtypesof(/datum/mission/fixer_job))
		var/kind = initial(job_type.job_kind)
		if(!kind)
			continue
		choices[unique_label(choices, kind)] = job_type
	return choices

/// Every crew record, with the jobs the network has been paid for it
/datum/fixer_admin_panel/proc/crew_choices()
	var/list/choices = list()
	for(var/datum/voidcrew_crew_record/crew in GLOB.voidcrew_crew_records)
		if(QDELETED(crew))
			continue
		var/leader_name = crew.leader?.current?.real_name || crew.leader?.name || "no leader"
		var/paid = GLOB.fixer_network.trust_of(crew)
		choices[unique_label(choices, "Crew #[crew.crew_id], led by [leader_name]: [paid] job\s paid")] = WEAKREF(crew)
	return choices

/// The noise an admin can count: 0 to 3, or back to the ledger's own reading (null)
/datum/fixer_admin_panel/proc/noise_choices()
	return list("0" = 0, "1" = 1, "2" = 2, "3" = 3, FIXER_ADMIN_NOISE_LEDGER = null)

/// The ways a job can fail, by what an admin reads
/datum/fixer_admin_panel/proc/fail_choices()
	return list(
		"The deadline passed" = FIXER_FAIL_DEADLINE,
		"Dropped (forget it)" = FIXER_FAIL_DROPPED,
		"Its subject is lost" = FIXER_FAIL_LOST,
		"Spoiled by an outsider" = FIXER_FAIL_SPOILED,
		"No room to stage it" = FIXER_FAIL_STAGING,
		"The outpost or ship is gone" = FIXER_FAIL_GONE,
		"Nobody came for the money" = FIXER_FAIL_UNCOLLECTED,
	)

/// Whether `reason` is one of the FIXER_FAIL_* reasons
/datum/fixer_admin_panel/proc/valid_fail_reason(reason)
	var/list/choices = fail_choices()
	for(var/label in choices)
		if(choices[label] == reason)
			return TRUE
	return FALSE

/// What a live job has placed that an admin can jump to
/datum/fixer_admin_panel/proc/job_atom_choices(datum/mission/fixer_job/job)
	var/list/choices = list()
	for(var/datum/weakref/ref as anything in job.job_atoms)
		var/atom/thing = ref?.resolve()
		if(QDELETED(thing) || !get_turf(thing))
			continue
		choices[unique_label(choices, "[thing.name] ([thing.type])")] = ref
	return choices

// ===== DESCRIPTIONS =====

/datum/fixer_admin_panel/proc/site_name(obj/structure/overmap/site)
	if(QDELETED(site))
		return "no site"
	return site.display_name || site.name

/datum/fixer_admin_panel/proc/outpost_name(obj/structure/overmap/trader_outpost/outpost)
	if(QDELETED(outpost))
		return "no outpost"
	return outpost.display_name || outpost.name

/// "green", "yellow" or "red": the zone an outpost sits in, which sets its jobs' pay
/datum/fixer_admin_panel/proc/zone_word(obj/structure/overmap/trader_outpost/outpost)
	var/turf/where = get_turf(outpost)
	switch(where ? SSovermap_zones?.get_zone_type(where) : null)
		if(ZONE_YELLOW)
			return "yellow"
		if(ZONE_RED)
			return "red"
	return "green"

/// "sabotage at Waystation Halcyon for the ship, open"
/datum/fixer_admin_panel/proc/job_label(datum/mission/fixer_job/job)
	return "[job.job_kind || "job"] at [outpost_name(job.job_outpost)] for [site_name(job.servant)], [job.deed_done ? "deed done" : "open"]"

// ===== LOOKUPS =====

/// The fixer job `ship`'s crew holds, or null
/datum/fixer_admin_panel/proc/crew_job(obj/structure/overmap/ship/ship)
	var/datum/voidcrew_crew_record/record = ship.ship_team?.crew_record
	for(var/datum/mission/fixer_job/job in SSmissions.all_active_missions)
		if(QDELETED(job))
			continue
		if(job.servant == ship || (record && job.accepting_crew == record))
			return job
	return null

/// A living body of someone on the job's roster: the doer of the deed, and the asker who is paid
/datum/fixer_admin_panel/proc/roster_body(datum/mission/fixer_job/job)
	for(var/datum/weakref/ref as anything in job.roster)
		var/datum/mind/who = ref?.resolve()
		var/mob/living/body = who?.current
		if(isliving(body) && !QDELETED(body) && body.stat != DEAD)
			return body
	return null

/// The living fixer who pays `job`: the far end's for a smuggle, else the giver's, else anyone's. Null if none lives.
/datum/fixer_admin_panel/proc/pay_fixer(datum/mission/fixer_job/job)
	var/list/preferred = list(job.pay_outpost, job.giver_outpost, job.job_outpost)
	for(var/obj/structure/overmap/trader_outpost/outpost as anything in preferred)
		if(QDELETED(outpost))
			continue
		var/mob/living/fixer = GLOB.fixer_network.fixer_at(outpost)
		if(fixer)
			return fixer
	for(var/obj/structure/overmap/trader_outpost/outpost as anything in GLOB.trader_outposts)
		if(QDELETED(outpost))
			continue
		var/mob/living/fixer = GLOB.fixer_network.fixer_at(outpost)
		if(fixer)
			return fixer
	return null

/// The fixer role that sends a fixer to `outpost`, or null if none is built (a role with no npc_type never comes)
/datum/fixer_admin_panel/proc/fixer_role_for(obj/structure/overmap/trader_outpost/outpost)
	for(var/datum/ambient_outpost_role/fixer/role in SSambient_npcs.get_outpost_roles())
		if(role.npc_type && role.applies_to(outpost))
			return role
	return null

// ===== ACTIONS =====

/**
 * Makes a `job_type` job for `outpost`'s fixer, not yet started, the way a slate entry is made
 * (GLOB.fixer_network.new_job()): `job_outpost` and `giver_outpost` are the outpost, and a smuggle's `pay_outpost`
 * is `destination`. The target and quote zone are bound when the ship accepts it. Named and signed as the fixer
 * there would sign it. Returns the job, or null if it could not be generated.
 */
/datum/fixer_admin_panel/proc/admin_make_job(job_type, obj/structure/overmap/trader_outpost/outpost, obj/structure/overmap/trader_outpost/destination)
	var/datum/mission/fixer_job/job = GLOB.fixer_network.new_job(job_type, outpost)
	if(!job)
		return null
	job.giver_outpost = outpost
	if(!QDELETED(destination))
		job.pay_outpost = destination
	var/mob/living/carbon/human/npc/ambient_npc/outpost/fixer/giver = GLOB.fixer_network.fixer_at(outpost)
	if(istype(giver))
		job.author = giver.speech_name()
		job.name = "A favour for [giver.speech_name()]"
		job.desc = "See the note."
	return job

/**
 * Gives `ship` a `job_type` job from `outpost`'s fixer, started now (its people and things are staged at once). A
 * smuggle runs to `destination`. Refused if the ship's crew already holds a fixer job. Returns the job, or null.
 */
/datum/fixer_admin_panel/proc/admin_give_job(mob/user, datum/mission/fixer_job/job_type, obj/structure/overmap/ship/ship, obj/structure/overmap/trader_outpost/outpost, obj/structure/overmap/trader_outpost/destination)
	error = null
	if(!authorized(user))
		return null
	if(!ispath(job_type, /datum/mission/fixer_job) || job_type == /datum/mission/fixer_job)
		return refuse(user, "That is not a job a fixer gives.")
	if(QDELETED(ship) || !ship.ship_team)
		return refuse(user, "That ship is gone, or has no crew.")
	if(QDELETED(outpost))
		return refuse(user, "That outpost is gone.")
	var/kind = initial(job_type.job_kind) || "fixer"
	if(kind == FIXER_JOB_SMUGGLE && (QDELETED(destination) || destination == outpost))
		return refuse(user, "A smuggling run needs another outpost to run to.")
	if(crew_job(ship))
		return refuse(user, "[site_name(ship)] already holds a fixer job.")
	var/datum/mission/fixer_job/job = admin_make_job(job_type, outpost, destination)
	if(!job)
		return refuse(user, "A [kind] job could not be made right now.")
	job.admin_touched = TRUE
	// The ship's own accept, as a fixer's "I'll take it." does (fixer_network do_accept())
	ship.available_missions += job
	var/result = ship.accept_mission(job)
	if(result != TRUE)
		ship.available_missions -= job
		if(!QDELETED(job))
			qdel(job)
		return refuse(user, "[site_name(ship)] could not start the [kind] job: [istext(result) ? result : "the job found no room"]")
	log_action(user, "give a [kind] job at [outpost_name(outpost)] to [site_name(ship)]")
	tell(user, span_notice("[site_name(ship)] now holds a [kind] job from [outpost_name(outpost)]'s fixer."))
	return job

/// Marks the deed done, as a living roster member doing it. Returns TRUE if it was marked.
/datum/fixer_admin_panel/proc/admin_finish_deed(mob/user, datum/mission/fixer_job/job)
	error = null
	if(!authorized(user))
		return FALSE
	if(QDELETED(job) || !job.active)
		return refuse(user, "That job is over.")
	if(job.deed_done)
		return refuse(user, "That job's deed is already done.")
	var/mob/living/doer = roster_body(job)
	if(!doer)
		return refuse(user, "Nobody on that job's roster is alive to have done it.")
	var/ship_name = site_name(job.servant)
	var/kind = job.job_kind
	job.admin_touched = TRUE
	job.mark_deed(doer)
	log_action(user, "finish the deed of [ship_name]'s [kind] job as [key_name(doer)]")
	tell(user, span_notice("The deed is marked done by [doer.real_name]."))
	return TRUE

/// Sets the noise the job counts to `noise` (0-3), or back to the ledger's own reading if null. Returns TRUE if set.
/datum/fixer_admin_panel/proc/admin_set_noise(mob/user, datum/mission/fixer_job/job, noise)
	error = null
	if(!authorized(user))
		return FALSE
	if(QDELETED(job))
		return refuse(user, "That job is over.")
	if(!isnull(noise))
		if(!isnum(noise) || noise < 0 || noise > 3)
			return refuse(user, "Noise runs from 0 to 3.")
		noise = round(noise)
	job.admin_touched = TRUE
	job.admin_noise = noise
	if(isnull(noise))
		log_action(user, "give the ledger's noise reading back on [site_name(job.servant)]'s [job.job_kind] job")
		tell(user, span_notice("The job counts the ledger's own reading again."))
	else
		log_action(user, "set the noise to [noise] on [site_name(job.servant)]'s [job.job_kind] job")
		tell(user, span_notice("The job counts noise [noise] until you set it back."))
	return TRUE

/**
 * Pays the job now, to its ship, as a living roster member asking the living fixer who would pay it. The deed must be
 * done. The fixer's own checks (a wanted crew, an officer close, the port still noisy) are skipped; the one that would
 * have refused is told to the admin. Returns the credits paid, or null.
 */
/datum/fixer_admin_panel/proc/admin_pay(mob/user, datum/mission/fixer_job/job)
	error = null
	if(!authorized(user))
		return null
	if(QDELETED(job) || !job.active)
		return refuse(user, "That job is over.")
	if(!job.deed_done)
		return refuse(user, "The deed isn't done. Finish it first.")
	var/mob/living/asker = roster_body(job)
	if(!asker)
		return refuse(user, "Nobody on that job's roster is alive to ask for the money.")
	var/mob/living/fixer = pay_fixer(job)
	if(!fixer)
		return refuse(user, "No fixer is alive to pay it.")
	var/ship_name = site_name(job.servant)
	var/kind = job.job_kind
	var/would_refuse = job.can_pay(asker, fixer)
	job.admin_touched = TRUE
	var/paid = job.pay_out(asker, fixer)
	if(!paid)
		return refuse(user, "The job paid nothing.")
	log_action(user, "pay [ship_name]'s [kind] job, [paid] cr")
	tell(user, span_notice("Paid [paid] cr to [ship_name].[would_refuse ? " The fixer would have refused: [would_refuse]." : ""]"))
	return paid

/// Fails the job as `reason` (FIXER_FAIL_*), the way the world would have. Returns TRUE if it was failed.
/datum/fixer_admin_panel/proc/admin_fail(mob/user, datum/mission/fixer_job/job, reason)
	error = null
	if(!authorized(user))
		return FALSE
	if(QDELETED(job) || !job.active)
		return refuse(user, "That job is over.")
	if(!valid_fail_reason(reason))
		return refuse(user, "[reason] is not a way for a job to fail.")
	var/ship_name = site_name(job.servant)
	var/kind = job.job_kind
	job.admin_touched = TRUE
	job.fail_reason = reason
	job.fail("Called off.")
	log_action(user, "fail [ship_name]'s [kind] job as [reason]")
	tell(user, span_notice("The job failed as [reason]."))
	return TRUE

/// Clears `crew`'s rest and burn at every fixer. Returns TRUE if done.
/datum/fixer_admin_panel/proc/admin_clear_crew(mob/user, datum/voidcrew_crew_record/crew)
	error = null
	if(!authorized(user))
		return FALSE
	if(QDELETED(crew))
		return refuse(user, "That crew is gone.")
	GLOB.fixer_network.clear_crew(crew)
	log_action(user, "clear the rest and burn of crew #[crew.crew_id]")
	tell(user, span_notice("Crew #[crew.crew_id] is clear with every fixer."))
	return TRUE

/// Sets the jobs paid the network counts for `crew` (0 to FIXER_ADMIN_MAX_TRUST). Returns TRUE if set.
/datum/fixer_admin_panel/proc/admin_set_trust(mob/user, datum/voidcrew_crew_record/crew, amount)
	error = null
	if(!authorized(user))
		return FALSE
	if(QDELETED(crew))
		return refuse(user, "That crew is gone.")
	if(!isnum(amount))
		return refuse(user, "That is not a number of jobs.")
	amount = clamp(round(amount), 0, FIXER_ADMIN_MAX_TRUST)
	GLOB.fixer_network.set_trust(crew, amount)
	log_action(user, "set the jobs paid of crew #[crew.crew_id] to [amount]")
	tell(user, span_notice("Crew #[crew.crew_id] has [amount] job\s paid."))
	return TRUE

/**
 * Brings `outpost`'s fixer back: the dead one's place opens at once and the role sends a new one off the lift (or onto
 * the concourse when the lift is busy), as it would after the wait. Refused while the outpost has a fixer alive, or no
 * fixer role is built for it. Returns the fixer, or null.
 */
/datum/fixer_admin_panel/proc/admin_respawn_fixer(mob/user, obj/structure/overmap/trader_outpost/outpost)
	error = null
	if(!authorized(user))
		return null
	if(QDELETED(outpost))
		return refuse(user, "That outpost is gone.")
	if(GLOB.fixer_network.fixer_at(outpost))
		return refuse(user, "[outpost_name(outpost)] already has its fixer.")
	var/datum/ambient_outpost_role/fixer/role = fixer_role_for(outpost)
	if(!role)
		return refuse(user, "No fixer is built for [outpost_name(outpost)].")
	var/datum/ambient_place/outpost/place = SSambient_npcs.outpost_place(outpost)
	if(!place)
		return refuse(user, "[outpost_name(outpost)] has no crowd to join.")
	place.killed_until -= role.type
	var/turf/arrival = SSambient_npcs.lift_arrival_turf(outpost)
	var/mob/living/carbon/human/npc/ambient_npc/fixer = arrival ? role.arrive(place, arrival) : role.settle(place)
	if(!fixer)
		return refuse(user, "There was no room at [outpost_name(outpost)] to bring one in.")
	log_action(user, "respawn the fixer at [outpost_name(outpost)]")
	tell(user, span_notice("[fixer.real_name] is at [outpost_name(outpost)]."))
	return fixer

/// Moves the admin to `thing`, called `label` in the log. Returns TRUE if they moved.
/datum/fixer_admin_panel/proc/admin_jump(mob/user, atom/thing, label)
	error = null
	if(!authorized(user))
		return FALSE
	var/turf/spot = get_turf(thing)
	if(QDELETED(thing) || !spot)
		return refuse(user, "There is nothing to jump to.")
	user.abstract_move(spot)
	log_action(user, "jump to [label] at [AREACOORD(spot)]")
	return TRUE

/// Prints every counted crime the job's ledger heard. Returns TRUE if it printed (or said it heard nothing).
/datum/fixer_admin_panel/proc/admin_print_ledger(mob/user, datum/mission/fixer_job/job)
	error = null
	if(!authorized(user))
		return FALSE
	if(QDELETED(job))
		return refuse(user, "That job is over.")
	if(QDELETED(job.ledger))
		return refuse(user, "That job has no ledger.")
	var/report = job.ledger.report()
	if(!length(report))
		tell(user, span_notice("The ledger has heard nothing."))
		return TRUE
	tell(user, boxed_message("<b>[job.job_kind] ledger</b><br>[report]"))
	return TRUE

// ===== ON THE JOB: THE ADMIN'S HAND AND THE METRICS =====

/datum/mission/fixer_job
	/// An admin gave, finished, paid or failed this job: its metric rows say so, so a balance query can leave it out
	var/admin_touched = FALSE
	/// The noise an admin set, or null to count the ledger's reading
	var/admin_noise

/// An admin's noise wins over the ledger's reading until it is cleared (P2's noise() runs through ..()). See the header.
/datum/mission/fixer_job/noise()
	if(!isnull(admin_noise))
		return admin_noise
	return ..()

/**
 * Queues one METRIC_MISSION row about this job under its own event name, with the job's kind as the subject
 * (record_mission_metric() would put the type path there). A job that is being deleted keeps the ship columns from
 * when it was accepted, as the shell's own rows do.
 */
/datum/mission/fixer_job/proc/record_fixer_metric(event, ckey, credits = 0, points = 0, list/details)
	if(!SSmetrics.accepting)
		return
	var/obj/structure/overmap/ship/ship = QDELETED(servant) ? null : servant
	var/list/row_details = details ? details.Copy() : list()
	row_details["kind"] = job_kind
	if(!QDELETED(job_outpost))
		row_details["outpost"] = job_outpost.display_name || job_outpost.name
	row_details["seconds"] = metric_seconds_active()
	if(admin_touched)
		row_details["admin"] = 1
	var/list/row = SSmetrics.build_row(METRIC_MISSION, event, ckey, null, ship, metric_target_zone(), job_kind || "[type]", credits, 0, points, 1, row_details)
	if(!ship && metric_ship_fields)
		row["ship_id"] = metric_ship_fields["ship_id"]
		row["ship_name"] = metric_ship_fields["ship_name"]
		row["ship_class"] = metric_ship_fields["ship_class"]
	SSmetrics.queue_row(row)

/// fixer_job_paid, beside the shell's mission_completed. The shell calls this from finish_mission() once the ship is paid.
/datum/mission/fixer_job/record_metric_completed(atom/reward_anchor)
	. = ..()
	if(!SSmetrics.accepting)
		return
	var/paid_credits = (servant?.ship_account && value > 0) ? value : 0
	var/noise_now = (ledger || !isnull(admin_noise)) ? noise() : 0
	record_fixer_metric("fixer_job_paid", metric_acting_ckey() || metric_accepted_by, paid_credits, noise_now)

/// fixer_job_failed, beside the shell's mission_failed. The shell calls this from fail(), for an accepted job only.
/datum/mission/fixer_job/record_metric_failed(reason)
	. = ..()
	if(!SSmetrics.accepting || !time_started)
		return
	var/timed_out = active && isnull(timeout_timer)
	record_fixer_metric("fixer_job_failed", metric_accepted_by, details = list("reason" = fail_reason || (timed_out ? FIXER_FAIL_DEADLINE : "unknown")))

#undef FIXER_ADMIN_MAX_STEPS
#undef FIXER_ADMIN_MAX_TRUST
#undef FIXER_ADMIN_MENU_GIVE
#undef FIXER_ADMIN_MENU_JOBS
#undef FIXER_ADMIN_MENU_CREW
#undef FIXER_ADMIN_MENU_FIXERS
#undef FIXER_ADMIN_JOB_DEED
#undef FIXER_ADMIN_JOB_NOISE
#undef FIXER_ADMIN_JOB_PAY
#undef FIXER_ADMIN_JOB_FAIL
#undef FIXER_ADMIN_JOB_LEDGER
#undef FIXER_ADMIN_JOB_ATOM
#undef FIXER_ADMIN_JOB_FIXER
#undef FIXER_ADMIN_CREW_CLEAR
#undef FIXER_ADMIN_CREW_TRUST
#undef FIXER_ADMIN_FIXER_RESPAWN
#undef FIXER_ADMIN_FIXER_JUMP
#undef FIXER_ADMIN_NOISE_LEDGER
