/**
 * Outpost jobs tests: admin and metrics (voidcrew/modules/outpost_jobs/job_admin.dm). Owner: P8.
 * Helpers are in voidcrew_outpost_jobs_helpers.dm. Fork defines are included after the tests: use literal values
 * with a comment naming the define.
 *
 * The Fixer Jobs panel runs without an admin client: /datum/fixer_admin_panel/unit_test answers its prompts from a list
 * and notes what it logged and said. The tests call the action procs straight, and the menus through their prompts.
 *
 * The tests stand on doubles so they hold whether the other packages are stubs or built: a job whose deed, pay and
 * can_pay are written down instead of done (/datum/mission/fixer_job/admin_test), a fixer network that answers
 * fixer_at(), trust_of() and the admin calls from its own variables, a ledger that prints a fixed report, and a ship
 * that keeps its notices to itself. What they check is that the panel asks those procs the right thing, refuses what it
 * should, and logs what it did. The pay, the ledger and the network themselves are tested by their own packages.
 */

// ===== DOUBLES =====

/// A fixer job for the admin tests: no generation, staging always works, and the deed, the pay and the refusal are written down
/datum/mission/fixer_job/admin_test
	name = "Admin test job"
	job_kind = "admin_test"
	/// Weakref to whoever mark_deed() was told did it
	var/datum/weakref/marked_by
	/// Weakrefs to whoever pay_out() was told asked, and to the fixer it was told paid
	var/datum/weakref/paid_to
	var/datum/weakref/paid_by
	/// What pay_out() pays
	var/pay_amount = 1860
	/// What can_pay() answers
	var/can_pay_answer
	/// What fail_reason held when the last fail() began (the job is deleted by the time anyone can ask)
	var/static/last_fail_reason

/datum/mission/fixer_job/admin_test/generate_mission_details()
	return

/datum/mission/fixer_job/admin_test/stage()
	return TRUE

/datum/mission/fixer_job/admin_test/mark_deed(mob/living/doer)
	marked_by = WEAKREF(doer)
	deed_done = TRUE

/datum/mission/fixer_job/admin_test/can_pay(mob/living/user, mob/fixer)
	return can_pay_answer

/datum/mission/fixer_job/admin_test/pay_out(mob/living/user, mob/fixer)
	paid_to = WEAKREF(user)
	paid_by = WEAKREF(fixer)
	return pay_amount

/datum/mission/fixer_job/admin_test/fail(reason = "Mission failed.")
	last_fail_reason = fail_reason
	return ..()

/// A smuggle for the admin tests: it names its kind, so the panel asks where it runs to
/datum/mission/fixer_job/admin_test/smuggle
	job_kind = "smuggle" // FIXER_JOB_SMUGGLE

/// A fixer network for the admin tests: the fixer it answers with, and what the panel told it
/datum/fixer_network/admin_test
	/// Weakref to the fixer fixer_at() answers with at every outpost, or null for none
	var/datum/weakref/fixer
	/// Crew records clear_crew() was told about
	var/list/cleared = list()
	/// Crew record -> the jobs paid set_trust() was told
	var/list/trust = list()

/datum/fixer_network/admin_test/fixer_at(obj/structure/overmap/trader_outpost/outpost)
	return fixer?.resolve()

/datum/fixer_network/admin_test/clear_crew(crew)
	cleared += crew

/datum/fixer_network/admin_test/set_trust(crew, amount)
	trust[crew] = amount

/datum/fixer_network/admin_test/trust_of(datum/voidcrew_crew_record/crew)
	return trust[crew] || 0

/datum/fixer_network/admin_test/Destroy()
	cleared.Cut()
	trust.Cut()
	return ..()

/// A ledger for the admin tests: it prints what it is told to
/datum/fixer_ledger/admin_test
	var/printed = ""

/datum/fixer_ledger/admin_test/New()
	return

/datum/fixer_ledger/admin_test/report()
	return printed

/// A ship that keeps its notices to itself
/obj/structure/overmap/ship/outpost_jobs_admin_test

/obj/structure/overmap/ship/outpost_jobs_admin_test/ship_notify(message, category = "ALERT", alert_level = 1, sound_file = null, volume = 100, anywhere = FALSE) // SHIP_NOTIFY_NOTICE
	return

/// The Fixer Jobs panel with no admin client: canned answers for its prompts, and a note of what it logged and said
/datum/fixer_admin_panel/unit_test
	/// FALSE stands for an admin who has lost R_ADMIN
	var/allow_actions = TRUE
	/// Answers the prompts take in order; an answer that is not an option is taken as the first option that contains it.
	/// Once they run out every prompt is cancelled.
	var/list/answers = list()
	/// Answers that matched no option
	var/list/missed = list()
	/// Every operation it logged
	var/list/operations = list()
	/// Everything it told the admin
	var/list/told = list()

/datum/fixer_admin_panel/unit_test/authorized(mob/user)
	return !QDELETED(src) && !isnull(user) && user == admin && allow_actions

/datum/fixer_admin_panel/unit_test/log_action(mob/user, operation)
	operations += operation

/datum/fixer_admin_panel/unit_test/tell(mob/user, message)
	told += message

/datum/fixer_admin_panel/unit_test/ask_list(mob/user, message, title, list/options)
	var/answer = next_answer()
	if(isnull(answer))
		return null
	if(answer in options)
		return answer
	for(var/option in options)
		if(findtext("[option]", "[answer]"))
			return option
	missed += "[answer] (asked: [message])"
	return null

/datum/fixer_admin_panel/unit_test/ask_number(mob/user, message, title, default, max_value, min_value)
	return next_answer()

/datum/fixer_admin_panel/unit_test/proc/next_answer()
	if(!length(answers))
		return null
	var/answer = answers[1]
	answers.Cut(1, 2)
	return answer

/// Whether anything it told the admin contains `text`
/datum/fixer_admin_panel/unit_test/proc/said(text)
	for(var/message in told)
		if(findtext("[message]", text))
			return TRUE
	return FALSE

// ===== THE TESTS =====

/// The Fixer Jobs panel's tests: a stand-in admin, a ship or two, a double network, and the panel's checks
/datum/unit_test/voidcrew_outpost_jobs_admin
	abstract_type = /datum/unit_test/voidcrew_outpost_jobs_admin
	/// Ships made by admin_ship(), taken apart in Destroy()
	var/list/ships = list()
	/// Jobs made by make_job(), deleted in Destroy()
	var/list/jobs = list()
	var/datum/fixer_network/admin_test/network
	var/datum/fixer_network/old_network
	/// The real outposts, set aside by isolate_outposts() so only the test's own are about
	var/list/old_outposts
	var/outposts_isolated = FALSE
	/// Ships a test put on the overmap's list, taken off again by Destroy()
	var/list/added_ships = list()
	/// The metrics queue, set aside by capture_metrics()
	var/metrics_captured = FALSE
	var/old_accepting
	var/list/old_pending
	var/list/old_tallies

/datum/unit_test/voidcrew_outpost_jobs_admin/Destroy()
	for(var/datum/mission/fixer_job/job as anything in jobs)
		if(!QDELETED(job))
			qdel(job)
	jobs.Cut()
	for(var/obj/structure/overmap/ship/ship as anything in added_ships)
		SSovermap.simulated_ships -= ship
	added_ships.Cut()
	jobs_cleanup(ships)
	ships.Cut()
	if(old_network)
		GLOB.fixer_network = old_network
		old_network = null
	QDEL_NULL(network)
	if(outposts_isolated)
		GLOB.trader_outposts.Cut()
		GLOB.trader_outposts += old_outposts
		outposts_isolated = FALSE
	if(metrics_captured)
		SSmetrics.accepting = old_accepting
		SSmetrics.pending = old_pending
		SSmetrics.tallies = old_tallies
		metrics_captured = FALSE
	return ..()

/// Sets the double network in place of the real one until Destroy()
/datum/unit_test/voidcrew_outpost_jobs_admin/proc/install_network()
	old_network = GLOB.fixer_network
	network = new
	GLOB.fixer_network = network
	return network

/// Sets the real outposts aside until Destroy(): the outposts the test makes after this are the only ones about
/datum/unit_test/voidcrew_outpost_jobs_admin/proc/isolate_outposts()
	old_outposts = GLOB.trader_outposts.Copy()
	GLOB.trader_outposts.Cut()
	outposts_isolated = TRUE

/// Empties the metrics queue and switches metrics on until Destroy()
/datum/unit_test/voidcrew_outpost_jobs_admin/proc/capture_metrics()
	old_accepting = SSmetrics.accepting
	old_pending = SSmetrics.pending
	old_tallies = SSmetrics.tallies
	metrics_captured = TRUE
	SSmetrics.accepting = TRUE
	SSmetrics.pending = list()
	SSmetrics.tallies = list()

/// The rows in the metrics queue under `event`
/datum/unit_test/voidcrew_outpost_jobs_admin/proc/rows_of(event)
	var/list/found = list()
	for(var/list/row as anything in SSmetrics.pending)
		if(row["event"] == event)
			found += list(row)
	return found

/datum/unit_test/voidcrew_outpost_jobs_admin/proc/make_operator(turf/spot)
	return allocate(/mob/living/carbon/human/consistent, spot)

/// A ship with a crew record and an account, the people on its crew, that keeps its notices to itself
/datum/unit_test/voidcrew_outpost_jobs_admin/proc/admin_ship(list/people, balance = 0)
	var/obj/structure/overmap/ship/outpost_jobs_admin_test/ship = allocate(/obj/structure/overmap/ship/outpost_jobs_admin_test)
	var/datum/team/voidcrew/team = allocate(/datum/team/voidcrew)
	team.ship = ship
	ship.ship_team = team
	var/datum/bank_account/account = allocate(/datum/bank_account, "Jobs admin test [REF(ship)]", null, 1, FALSE)
	account.account_balance = balance
	ship.ship_account = account
	for(var/mob/living/person as anything in people)
		team.join_member(person.mind)
	ships += ship
	return ship

/// A live admin test job on `ship`, done at `outpost`, with `crewman` on its roster. Made by hand, as a started job is.
/datum/unit_test/voidcrew_outpost_jobs_admin/proc/make_job(obj/structure/overmap/ship/ship, obj/structure/overmap/trader_outpost/outpost, mob/living/crewman)
	var/datum/mission/fixer_job/admin_test/job = new
	jobs += job
	job.servant = ship
	job.job_outpost = outpost
	job.giver_outpost = outpost
	job.active = TRUE
	job.time_started = world.time
	job.metric_accepted_by = "asker"
	if(crewman?.mind)
		job.roster += WEAKREF(crewman.mind)
	ship.active_missions += job
	SSmissions.all_active_missions += job
	return job

// ===== RIGHTS =====

/// Only the admin who opened the panel, still holding R_ADMIN, gets anything done; a refused action changes and logs nothing
/datum/unit_test/voidcrew_outpost_jobs_admin/rights

/datum/unit_test/voidcrew_outpost_jobs_admin/rights/Run()
	install_network()
	var/mob/living/carbon/human/operator = make_operator(run_loc_floor_top_right)
	var/mob/living/carbon/human/stranger = make_operator(jobs_spot(1, 1))
	var/mob/living/carbon/human/crewman = jobs_person(jobs_spot(0, 0))
	var/obj/structure/overmap/trader_outpost/outpost = jobs_outpost()
	var/obj/structure/overmap/ship/ship = admin_ship(list(crewman))
	var/obj/structure/overmap/ship/idle_ship = admin_ship(list())
	var/datum/mission/fixer_job/admin_test/job = make_job(ship, outpost, crewman)
	var/datum/voidcrew_crew_record/crew = ship.ship_team.crew_record
	var/datum/fixer_admin_panel/unit_test/panel = allocate(__IMPLIED_TYPE__, operator)
	panel.allow_actions = FALSE
	TEST_ASSERT_NULL(panel.admin_give_job(operator, /datum/mission/fixer_job/admin_test, idle_ship, outpost), "A panel without R_ADMIN gave a job")
	TEST_ASSERT(!panel.admin_finish_deed(operator, job), "A panel without R_ADMIN finished a deed")
	TEST_ASSERT(!panel.admin_set_noise(operator, job, 2), "A panel without R_ADMIN set the noise")
	TEST_ASSERT_NULL(panel.admin_pay(operator, job), "A panel without R_ADMIN paid a job")
	TEST_ASSERT(!panel.admin_fail(operator, job, "deadline"), "A panel without R_ADMIN failed a job") // FIXER_FAIL_DEADLINE
	TEST_ASSERT(!panel.admin_clear_crew(operator, crew), "A panel without R_ADMIN cleared a crew")
	TEST_ASSERT(!panel.admin_set_trust(operator, crew, 3), "A panel without R_ADMIN set a crew's jobs paid")
	TEST_ASSERT_NULL(panel.admin_respawn_fixer(operator, outpost), "A panel without R_ADMIN respawned a fixer")
	TEST_ASSERT(!panel.admin_jump(operator, crewman, "a crewman"), "A panel without R_ADMIN jumped")
	TEST_ASSERT(!panel.admin_print_ledger(operator, job), "A panel without R_ADMIN printed a ledger")
	TEST_ASSERT_EQUAL(length(panel.operations), 0, "A refused action was logged")
	TEST_ASSERT_EQUAL(length(panel.told), 0, "A refused action told the admin something")
	TEST_ASSERT(!job.deed_done && !job.admin_touched && isnull(job.admin_noise) && job.active, "A refused action changed the job")
	TEST_ASSERT_EQUAL(length(network.cleared) + length(network.trust), 0, "A refused action reached the network")
	TEST_ASSERT_EQUAL(get_turf(operator), run_loc_floor_top_right, "A refused jump moved the admin")

	// Someone other than the panel's admin is refused even with rights
	var/datum/fixer_admin_panel/unit_test/other = allocate(/datum/fixer_admin_panel/unit_test, operator)
	TEST_ASSERT(!other.admin_clear_crew(stranger, crew), "Someone else used the admin's panel")
	TEST_ASSERT_EQUAL(length(other.operations) + length(network.cleared), 0, "Someone else's use was logged or reached the network")

// ===== GIVING A JOB =====

/// A job is made for the outpost and started on the ship at once; a crew holds one; a smuggle needs somewhere to run to
/datum/unit_test/voidcrew_outpost_jobs_admin/give

/datum/unit_test/voidcrew_outpost_jobs_admin/give/Run()
	install_network()
	var/mob/living/carbon/human/operator = make_operator(run_loc_floor_top_right)
	var/mob/living/carbon/human/crewman = jobs_person(jobs_spot(0, 0))
	var/mob/living/carbon/human/other_crewman = jobs_person(jobs_spot(1, 0))
	var/obj/structure/overmap/trader_outpost/outpost = jobs_outpost()
	var/obj/structure/overmap/trader_outpost/far_outpost = allocate(/obj/structure/overmap/trader_outpost)
	var/obj/structure/overmap/ship/ship = admin_ship(list(crewman))
	var/obj/structure/overmap/ship/other_ship = admin_ship(list(other_crewman))
	var/datum/fixer_admin_panel/unit_test/panel = allocate(__IMPLIED_TYPE__, operator)

	// Only a fixer job, a ship with a crew and an outpost
	TEST_ASSERT_NULL(panel.admin_give_job(operator, /datum/mission, ship, outpost), "An ordinary mission was given as a fixer job")
	TEST_ASSERT_NULL(panel.admin_give_job(operator, /datum/mission/fixer_job, ship, outpost), "The base fixer job was given")
	var/obj/structure/overmap/ship/outpost_jobs_admin_test/crewless = allocate(/obj/structure/overmap/ship/outpost_jobs_admin_test)
	TEST_ASSERT_NULL(panel.admin_give_job(operator, /datum/mission/fixer_job/admin_test, crewless, outpost), "A ship with no crew was given a job")
	TEST_ASSERT_NULL(panel.admin_give_job(operator, /datum/mission/fixer_job/admin_test, ship, null), "A job was given with no outpost")
	TEST_ASSERT_EQUAL(length(panel.operations), 0, "A refused give was logged")

	var/datum/mission/fixer_job/job = panel.admin_give_job(operator, /datum/mission/fixer_job/admin_test, ship, outpost)
	TEST_ASSERT_NOTNULL(job, "The job was not given: [panel.error]")
	jobs += job
	TEST_ASSERT_EQUAL(job.type, /datum/mission/fixer_job/admin_test, "The wrong job was made")
	TEST_ASSERT(job.active, "The given job is not live")
	TEST_ASSERT_EQUAL(job.servant, ship, "The job is on another ship")
	TEST_ASSERT_EQUAL(job.job_outpost, outpost, "The job is not done at the chosen outpost")
	TEST_ASSERT_EQUAL(job.giver_outpost, outpost, "The chosen outpost's fixer did not give the job")
	TEST_ASSERT(job in ship.active_missions, "The ship does not hold the job")
	TEST_ASSERT(job.admin_touched, "A given job is not marked as an admin's")
	TEST_ASSERT_EQUAL(length(panel.operations), 1, "Giving a job was logged [length(panel.operations)] times")

	// A crew holds one at a time
	TEST_ASSERT_NULL(panel.admin_give_job(operator, /datum/mission/fixer_job/admin_test, ship, outpost), "A crew was given a second fixer job")
	TEST_ASSERT(findtext(panel.error, "already holds"), "The refusal did not say the ship holds a job: [panel.error]")
	TEST_ASSERT_EQUAL(length(panel.operations), 1, "A refused give was logged")

	// A smuggle runs to another outpost
	TEST_ASSERT_NULL(panel.admin_give_job(operator, /datum/mission/fixer_job/admin_test/smuggle, other_ship, outpost), "A smuggle was given with nowhere to run to")
	TEST_ASSERT_NULL(panel.admin_give_job(operator, /datum/mission/fixer_job/admin_test/smuggle, other_ship, outpost, outpost), "A smuggle was given running to its own outpost")
	var/datum/mission/fixer_job/run = panel.admin_give_job(operator, /datum/mission/fixer_job/admin_test/smuggle, other_ship, outpost, far_outpost)
	TEST_ASSERT_NOTNULL(run, "The smuggle was not given: [panel.error]")
	jobs += run
	TEST_ASSERT_EQUAL(run.pay_outpost, far_outpost, "The smuggle does not run to the chosen outpost")
	TEST_ASSERT_EQUAL(run.job_outpost, outpost, "The smuggle is not given at the chosen outpost")

/// The give menu asks which ship, which outpost and which job
/datum/unit_test/voidcrew_outpost_jobs_admin/give_menu

/datum/unit_test/voidcrew_outpost_jobs_admin/give_menu/Run()
	install_network()
	isolate_outposts()
	var/mob/living/carbon/human/operator = make_operator(run_loc_floor_top_right)
	var/mob/living/carbon/human/crewman = jobs_person(jobs_spot(0, 0))
	var/obj/structure/overmap/trader_outpost/outpost = jobs_outpost()
	var/obj/structure/overmap/ship/ship = admin_ship(list(crewman))
	ship.name = "Admin Test Hull"
	ship.display_name = null
	SSovermap.simulated_ships += ship
	added_ships += ship
	var/datum/fixer_admin_panel/unit_test/panel = allocate(__IMPLIED_TYPE__, operator)
	// The menu, then the ship, the outpost (the only one: its label ends with its zone) and the job
	panel.answers = list("Give a job to a ship", "Admin Test Hull", ", green", "admin_test")
	panel.run_menu(operator)
	TEST_ASSERT_EQUAL(length(panel.missed), 0, "The give menu asked something the test did not expect: [panel.missed.Join("; ")]")
	var/datum/mission/fixer_job/job
	for(var/datum/mission/fixer_job/live in SSmissions.all_active_missions)
		if(live.servant == ship)
			job = live
	TEST_ASSERT_NOTNULL(job, "The give menu gave no job: [panel.error]")
	jobs += job
	TEST_ASSERT_EQUAL(job.type, /datum/mission/fixer_job/admin_test, "The give menu gave the wrong job")
	TEST_ASSERT_EQUAL(job.job_outpost, outpost, "The give menu used the wrong outpost")

// ===== THE DEED, THE NOISE, THE PAY, THE FAILURE =====

/// Finishing the deed is a living roster member doing it; it needs a live job, an undone deed and someone to have done it
/datum/unit_test/voidcrew_outpost_jobs_admin/deed

/datum/unit_test/voidcrew_outpost_jobs_admin/deed/Run()
	install_network()
	var/mob/living/carbon/human/operator = make_operator(run_loc_floor_top_right)
	var/mob/living/carbon/human/crewman = jobs_person(jobs_spot(0, 0))
	var/obj/structure/overmap/trader_outpost/outpost = jobs_outpost()
	var/obj/structure/overmap/ship/ship = admin_ship(list(crewman))
	var/datum/fixer_admin_panel/unit_test/panel = allocate(__IMPLIED_TYPE__, operator)

	var/datum/mission/fixer_job/admin_test/nobody = make_job(ship, outpost, null)
	TEST_ASSERT(!panel.admin_finish_deed(operator, nobody), "A deed was finished with nobody on the roster")
	TEST_ASSERT(!nobody.deed_done, "A refused deed was marked done")
	qdel(nobody)
	TEST_ASSERT(!panel.admin_finish_deed(operator, nobody), "A deed was finished on a deleted job")

	var/datum/mission/fixer_job/admin_test/job = make_job(ship, outpost, crewman)
	TEST_ASSERT(panel.admin_finish_deed(operator, job), "The deed was not finished: [panel.error]")
	TEST_ASSERT(job.deed_done, "The deed is not done")
	TEST_ASSERT(job.admin_touched, "A deed finished by an admin is not marked as an admin's")
	TEST_ASSERT_EQUAL(job.marked_by?.resolve(), crewman, "The deed was not marked as the roster member's")
	TEST_ASSERT_EQUAL(length(panel.operations), 1, "Finishing the deed was logged [length(panel.operations)] times")
	TEST_ASSERT(!panel.admin_finish_deed(operator, job), "A deed was finished twice")

	// A dead roster member does nothing
	var/datum/mission/fixer_job/admin_test/dead = make_job(ship, outpost, crewman)
	crewman.death()
	TEST_ASSERT(!panel.admin_finish_deed(operator, dead), "A dead roster member did the deed")

/// The noise an admin sets is the noise the job counts, until it is cleared; it must be 0 to 3
/datum/unit_test/voidcrew_outpost_jobs_admin/noise

/datum/unit_test/voidcrew_outpost_jobs_admin/noise/Run()
	install_network()
	var/mob/living/carbon/human/operator = make_operator(run_loc_floor_top_right)
	var/mob/living/carbon/human/crewman = jobs_person(jobs_spot(0, 0))
	var/obj/structure/overmap/trader_outpost/outpost = jobs_outpost()
	var/obj/structure/overmap/ship/ship = admin_ship(list(crewman))
	var/datum/fixer_admin_panel/unit_test/panel = allocate(__IMPLIED_TYPE__, operator)
	var/datum/mission/fixer_job/admin_test/job = make_job(ship, outpost, crewman)

	TEST_ASSERT(!panel.admin_set_noise(operator, job, 4), "Noise 4 was set")
	TEST_ASSERT(!panel.admin_set_noise(operator, job, -1), "Noise -1 was set")
	TEST_ASSERT(!panel.admin_set_noise(operator, job, "loud"), "Noise \"loud\" was set")
	TEST_ASSERT_NULL(job.admin_noise, "A refused noise was kept")
	TEST_ASSERT_EQUAL(length(panel.operations), 0, "A refused noise was logged")

	TEST_ASSERT(panel.admin_set_noise(operator, job, 2), "Noise 2 was not set: [panel.error]")
	TEST_ASSERT_EQUAL(job.admin_noise, 2, "The noise is not 2")
	TEST_ASSERT_EQUAL(job.noise(), 2, "noise() does not answer with the admin's number: the redefinition in job_admin.dm is not the outermost one")
	TEST_ASSERT(job.admin_touched, "A job with a set noise is not marked as an admin's")
	TEST_ASSERT(panel.admin_set_noise(operator, job, 0), "Noise 0 was not set")
	TEST_ASSERT_EQUAL(job.noise(), 0, "Noise 0 was taken for no noise set")
	TEST_ASSERT(panel.admin_set_noise(operator, job, null), "The noise was not given back to the ledger")
	TEST_ASSERT_NULL(job.admin_noise, "The noise was not cleared")
	TEST_ASSERT_EQUAL(length(panel.operations), 3, "The noise was logged [length(panel.operations)] times, not three")

/// Paying needs the deed done, someone on the roster and a living fixer; it asks that fixer's can_pay() and pays through pay_out()
/datum/unit_test/voidcrew_outpost_jobs_admin/pay

/datum/unit_test/voidcrew_outpost_jobs_admin/pay/Run()
	install_network()
	isolate_outposts()
	var/mob/living/carbon/human/operator = make_operator(run_loc_floor_top_right)
	var/mob/living/carbon/human/crewman = jobs_person(jobs_spot(0, 0))
	var/mob/living/carbon/human/fixer = jobs_person(jobs_spot(2, 0))
	var/obj/structure/overmap/trader_outpost/outpost = jobs_outpost()
	var/obj/structure/overmap/ship/ship = admin_ship(list(crewman))
	var/datum/fixer_admin_panel/unit_test/panel = allocate(__IMPLIED_TYPE__, operator)
	var/datum/mission/fixer_job/admin_test/job = make_job(ship, outpost, crewman)

	// The deed first
	network.fixer = WEAKREF(fixer)
	TEST_ASSERT_NULL(panel.admin_pay(operator, job), "A job was paid before its deed")
	TEST_ASSERT(findtext(panel.error, "deed"), "The refusal did not mention the deed: [panel.error]")
	job.deed_done = TRUE

	// Then a fixer alive to pay it
	network.fixer = null
	TEST_ASSERT_NULL(panel.admin_pay(operator, job), "A job was paid with no fixer alive")
	TEST_ASSERT(findtext(panel.error, "fixer"), "The refusal did not mention the fixer: [panel.error]")
	TEST_ASSERT_NULL(job.paid_to, "pay_out() ran with no fixer alive")

	// Then someone on the roster to ask
	network.fixer = WEAKREF(fixer)
	var/datum/mission/fixer_job/admin_test/rosterless = make_job(ship, outpost, null)
	rosterless.deed_done = TRUE
	TEST_ASSERT_NULL(panel.admin_pay(operator, rosterless), "A job was paid with nobody on the roster")
	TEST_ASSERT_NULL(rosterless.paid_to, "pay_out() ran with nobody on the roster")
	qdel(rosterless)

	// The fixer's refusal is told, and does not stop an admin
	job.can_pay_answer = "wanted" // FIXER_LINE_WANTED
	TEST_ASSERT_EQUAL(panel.admin_pay(operator, job), 1860, "The job did not pay what pay_out() answered: [panel.error]")
	TEST_ASSERT_EQUAL(job.paid_to?.resolve(), crewman, "pay_out() was not told the roster member asked")
	TEST_ASSERT_EQUAL(job.paid_by?.resolve(), fixer, "pay_out() was not told the living fixer paid")
	TEST_ASSERT(job.admin_touched, "A job paid by an admin is not marked as an admin's")
	TEST_ASSERT(panel.said("1860"), "The admin was not told what was paid")
	TEST_ASSERT(panel.said("wanted"), "The admin was not told what the fixer would have said")
	TEST_ASSERT_EQUAL(length(panel.operations), 1, "Paying was logged [length(panel.operations)] times")

	// A pay that pays nothing is a refusal
	var/datum/mission/fixer_job/admin_test/broke = make_job(ship, outpost, crewman)
	broke.deed_done = TRUE
	broke.pay_amount = 0
	TEST_ASSERT_NULL(panel.admin_pay(operator, broke), "A pay of nothing was taken for a pay")
	TEST_ASSERT_EQUAL(length(panel.operations), 1, "A pay of nothing was logged")

/// Failing a job sets its reason and fails it for real; only the known reasons will do
/datum/unit_test/voidcrew_outpost_jobs_admin/fail

/datum/unit_test/voidcrew_outpost_jobs_admin/fail/Run()
	install_network()
	var/mob/living/carbon/human/operator = make_operator(run_loc_floor_top_right)
	var/mob/living/carbon/human/crewman = jobs_person(jobs_spot(0, 0))
	var/obj/structure/overmap/trader_outpost/outpost = jobs_outpost()
	var/obj/structure/overmap/ship/ship = admin_ship(list(crewman))
	var/datum/fixer_admin_panel/unit_test/panel = allocate(__IMPLIED_TYPE__, operator)
	var/datum/mission/fixer_job/admin_test/job = make_job(ship, outpost, crewman)

	TEST_ASSERT(!panel.admin_fail(operator, job, "because"), "A job failed for a reason that is not one")
	TEST_ASSERT(job.active && !job.failed, "A refused fail changed the job")
	TEST_ASSERT_EQUAL(length(panel.operations), 0, "A refused fail was logged")

	TEST_ASSERT(panel.admin_fail(operator, job, "spoiled"), "The job was not failed: [panel.error]") // FIXER_FAIL_SPOILED
	TEST_ASSERT(QDELETED(job), "A failed job is still about")
	TEST_ASSERT_EQUAL(job.last_fail_reason, "spoiled", "The job did not fail as the reason chosen") // FIXER_FAIL_SPOILED
	TEST_ASSERT(!(job in ship.active_missions), "The ship still holds a failed job")
	TEST_ASSERT_EQUAL(length(panel.operations), 1, "Failing was logged [length(panel.operations)] times")
	TEST_ASSERT(!panel.admin_fail(operator, job, "deadline"), "A job already over was failed again") // FIXER_FAIL_DEADLINE

	// Every reason the panel offers is one a job can fail as
	var/list/reasons = panel.fail_choices()
	for(var/label in reasons)
		var/datum/mission/fixer_job/admin_test/another = make_job(ship, outpost, crewman)
		TEST_ASSERT(panel.admin_fail(operator, another, reasons[label]), "[label] is not a reason a job can fail as: [panel.error]")

// ===== CREWS, FIXERS, JUMPING, LEDGERS =====

/// Clearing a crew and setting its jobs paid go to the network, and the number is kept within bounds
/datum/unit_test/voidcrew_outpost_jobs_admin/crew

/datum/unit_test/voidcrew_outpost_jobs_admin/crew/Run()
	install_network()
	var/mob/living/carbon/human/operator = make_operator(run_loc_floor_top_right)
	var/mob/living/carbon/human/crewman = jobs_person(jobs_spot(0, 0))
	var/obj/structure/overmap/ship/ship = admin_ship(list(crewman))
	var/datum/voidcrew_crew_record/crew = ship.ship_team.crew_record
	var/datum/fixer_admin_panel/unit_test/panel = allocate(__IMPLIED_TYPE__, operator)

	TEST_ASSERT(panel.admin_clear_crew(operator, crew), "The crew was not cleared: [panel.error]")
	TEST_ASSERT(crew in network.cleared, "The network was not told to clear the crew")
	TEST_ASSERT(!panel.admin_clear_crew(operator, null), "A crew that is gone was cleared")

	TEST_ASSERT(panel.admin_set_trust(operator, crew, 3), "The jobs paid were not set: [panel.error]")
	TEST_ASSERT_EQUAL(network.trust[crew], 3, "The network was told the wrong jobs paid")
	TEST_ASSERT(panel.admin_set_trust(operator, crew, 500), "A large number of jobs paid was refused")
	TEST_ASSERT_EQUAL(network.trust[crew], 99, "The jobs paid were not held to the most an admin can set") // FIXER_ADMIN_MAX_TRUST
	TEST_ASSERT(panel.admin_set_trust(operator, crew, -4), "A negative number of jobs paid was refused")
	TEST_ASSERT_EQUAL(network.trust[crew], 0, "A negative number of jobs paid was kept")
	TEST_ASSERT(!panel.admin_set_trust(operator, crew, "many"), "A word was set as the jobs paid")
	TEST_ASSERT_EQUAL(length(panel.operations), 4, "The crew actions were logged [length(panel.operations)] times, not four")

	// The menu
	network.trust[crew] = 1
	panel.answers = list("A crew's standing", "Crew #[crew.crew_id],", "Set jobs paid", 7)
	panel.run_menu(operator)
	TEST_ASSERT_EQUAL(length(panel.missed), 0, "The crew menu asked something the test did not expect: [panel.missed.Join("; ")]")
	TEST_ASSERT_EQUAL(network.trust[crew], 7, "The crew menu did not set the jobs paid")
	panel.answers = list("A crew's standing", "Crew #[crew.crew_id],", "Clear rest and burn")
	panel.run_menu(operator)
	TEST_ASSERT_EQUAL(length(network.cleared), 2, "The crew menu did not clear the crew")

/// A fixer is only brought back where one is missing and a fixer role is built; the menu shows who is alive and jumps to them
/datum/unit_test/voidcrew_outpost_jobs_admin/fixers

/datum/unit_test/voidcrew_outpost_jobs_admin/fixers/Run()
	install_network()
	isolate_outposts()
	var/mob/living/carbon/human/operator = make_operator(run_loc_floor_top_right)
	var/mob/living/carbon/human/fixer = jobs_person(jobs_spot(3, 3))
	var/obj/structure/overmap/trader_outpost/outpost = jobs_outpost()
	var/datum/fixer_admin_panel/unit_test/panel = allocate(__IMPLIED_TYPE__, operator)

	// A fixer alive is not replaced
	network.fixer = WEAKREF(fixer)
	TEST_ASSERT_NULL(panel.admin_respawn_fixer(operator, outpost), "A second fixer was brought to an outpost with one")
	TEST_ASSERT(findtext(panel.error, "already"), "The refusal did not say the fixer is alive: [panel.error]")
	// With none alive, a plain outpost has no fixer role: nothing comes, and nothing is left behind in the crowd
	network.fixer = null
	TEST_ASSERT_NULL(panel.admin_respawn_fixer(operator, outpost), "A fixer was brought to an outpost no fixer role serves")
	TEST_ASSERT(findtext(panel.error, "No fixer is built"), "The refusal did not say no fixer is built: [panel.error]")
	TEST_ASSERT_NULL(SSambient_npcs.outposts[outpost], "A refused respawn left a crowd behind for the outpost")
	TEST_ASSERT_NULL(panel.admin_respawn_fixer(operator, null), "A fixer was brought to an outpost that is gone")
	TEST_ASSERT_EQUAL(length(panel.operations), 0, "A refused respawn was logged")

	// The menu: the outpost's line says whether its fixer is alive, and jumping takes the admin to the fixer
	network.fixer = WEAKREF(fixer)
	panel.answers = list("The fixers", "fixer alive", "Jump to the fixer")
	panel.run_menu(operator)
	TEST_ASSERT_EQUAL(length(panel.missed), 0, "The fixers menu asked something the test did not expect: [panel.missed.Join("; ")]")
	TEST_ASSERT_EQUAL(get_turf(operator), get_turf(fixer), "Jumping to the fixer did not take the admin there")

/// Jumping moves the admin to the thing's turf; a thing with no place is refused
/datum/unit_test/voidcrew_outpost_jobs_admin/jump

/datum/unit_test/voidcrew_outpost_jobs_admin/jump/Run()
	var/mob/living/carbon/human/operator = make_operator(run_loc_floor_top_right)
	var/mob/living/carbon/human/target = jobs_person(jobs_spot(3, 3))
	var/datum/fixer_admin_panel/unit_test/panel = allocate(__IMPLIED_TYPE__, operator)
	TEST_ASSERT(panel.admin_jump(operator, target, "a target"), "The admin did not jump: [panel.error]")
	TEST_ASSERT_EQUAL(get_turf(operator), jobs_spot(3, 3), "The admin did not land on the target's turf")
	TEST_ASSERT_EQUAL(length(panel.operations), 1, "Jumping was logged [length(panel.operations)] times")
	// allocate() always places an atom on the test floor: this one is made in nullspace
	var/obj/item/paper/nowhere = new(null)
	allocated += nowhere
	TEST_ASSERT(!panel.admin_jump(operator, nowhere, "a paper"), "The admin jumped to a thing in nullspace")
	TEST_ASSERT(!panel.admin_jump(operator, null, "nothing"), "The admin jumped to nothing")
	TEST_ASSERT_EQUAL(get_turf(operator), jobs_spot(3, 3), "A refused jump moved the admin")

/// The ledger prints through the panel; a job with none, or one that heard nothing, says so
/datum/unit_test/voidcrew_outpost_jobs_admin/ledger

/datum/unit_test/voidcrew_outpost_jobs_admin/ledger/Run()
	install_network()
	var/mob/living/carbon/human/operator = make_operator(run_loc_floor_top_right)
	var/mob/living/carbon/human/crewman = jobs_person(jobs_spot(0, 0))
	var/obj/structure/overmap/trader_outpost/outpost = jobs_outpost()
	var/obj/structure/overmap/ship/ship = admin_ship(list(crewman))
	var/datum/fixer_admin_panel/unit_test/panel = allocate(__IMPLIED_TYPE__, operator)
	var/datum/mission/fixer_job/admin_test/job = make_job(ship, outpost, crewman)

	TEST_ASSERT(!panel.admin_print_ledger(operator, job), "A job with no ledger printed one")
	var/datum/fixer_ledger/admin_test/ledger = new
	job.ledger = ledger
	TEST_ASSERT(panel.admin_print_ledger(operator, job), "A ledger that heard nothing was refused: [panel.error]")
	TEST_ASSERT(panel.said("heard nothing"), "The admin was not told the ledger heard nothing")
	ledger.printed = "assault on the clerk"
	TEST_ASSERT(panel.admin_print_ledger(operator, job), "The ledger did not print: [panel.error]")
	TEST_ASSERT(panel.said("assault on the clerk"), "The ledger's report did not reach the admin")

// ===== THE MENU =====

/// The menu counts the live jobs, lists them, and acts on the one chosen
/datum/unit_test/voidcrew_outpost_jobs_admin/menu

/datum/unit_test/voidcrew_outpost_jobs_admin/menu/Run()
	install_network()
	isolate_outposts()
	var/mob/living/carbon/human/operator = make_operator(run_loc_floor_top_right)
	var/mob/living/carbon/human/crewman = jobs_person(jobs_spot(0, 0))
	var/obj/structure/overmap/trader_outpost/outpost = jobs_outpost()
	var/obj/structure/overmap/ship/ship = admin_ship(list(crewman))
	var/datum/fixer_admin_panel/unit_test/panel = allocate(__IMPLIED_TYPE__, operator)

	var/summary = panel.summary_text()
	TEST_ASSERT(findtext(summary, "0 live fixer jobs"), "The summary did not count no jobs: [summary]")
	panel.answers = list("Live jobs")
	panel.run_menu(operator)
	TEST_ASSERT(panel.said("No fixer jobs are live"), "The jobs menu did not say no job is live")

	var/datum/mission/fixer_job/admin_test/job = make_job(ship, outpost, crewman)
	summary = panel.summary_text()
	TEST_ASSERT(findtext(summary, "1 live fixer job,"), "The summary did not count the job: [summary]")
	panel.told.Cut()
	panel.answers = list("Live jobs", "admin_test at", "Finish the deed", "Live jobs", "admin_test at", "Set the noise", "2", "Live jobs", "admin_test at", "Print the ledger")
	panel.run_menu(operator)
	TEST_ASSERT_EQUAL(length(panel.missed), 0, "The jobs menu asked something the test did not expect: [panel.missed.Join("; ")]")
	TEST_ASSERT(job.deed_done, "The jobs menu did not finish the deed")
	TEST_ASSERT_EQUAL(job.admin_noise, 2, "The jobs menu did not set the noise")
	TEST_ASSERT(panel.said("no ledger"), "The jobs menu did not say the job has no ledger")
	panel.answers = list("Live jobs", "admin_test at", "Fail it", "Dropped")
	panel.run_menu(operator)
	TEST_ASSERT_EQUAL(length(panel.missed), 0, "The fail menu asked something the test did not expect: [panel.missed.Join("; ")]")
	TEST_ASSERT(QDELETED(job), "The jobs menu did not fail the job")

// ===== THE METRICS =====

/// A paid job writes one fixer_job_paid row, beside the shell's own: kind, zone, ship, asker, credits, noise
/datum/unit_test/voidcrew_outpost_jobs_admin/metrics_paid

/datum/unit_test/voidcrew_outpost_jobs_admin/metrics_paid/Run()
	capture_metrics()
	var/mob/living/carbon/human/crewman = jobs_person(jobs_spot(0, 0))
	var/obj/structure/overmap/trader_outpost/outpost = jobs_outpost()
	var/obj/structure/overmap/ship/ship = admin_ship(list(crewman))
	var/datum/mission/fixer_job/admin_test/job = make_job(ship, outpost, crewman)
	job.value = 1860
	job.quote_zone = 3 // ZONE_RED
	job.admin_noise = 2
	job.admin_touched = TRUE
	job.finish_mission(run_loc_floor_bottom_left)
	TEST_ASSERT_EQUAL(length(rows_of("mission_completed")), 1, "The shell's own mission_completed row went missing")
	var/list/paid = rows_of("fixer_job_paid")
	TEST_ASSERT_EQUAL(length(paid), 1, "A paid job wrote [length(paid)] fixer_job_paid rows, not one")
	var/list/row = paid[1]
	TEST_ASSERT_EQUAL(row["category"], "mission", "The paid row is not a mission row") // METRIC_MISSION
	TEST_ASSERT_EQUAL(row["subject"], "admin_test", "The paid row's subject is not the job's kind")
	TEST_ASSERT_EQUAL(row["credits"], 1860, "The paid row does not carry what was paid")
	TEST_ASSERT_EQUAL(row["points"], 2, "The paid row does not carry the noise")
	TEST_ASSERT_EQUAL(row["quantity"], 1, "The paid row does not count one job")
	TEST_ASSERT_EQUAL(row["zone"], "red", "The paid row does not carry the job's zone")
	TEST_ASSERT_EQUAL(row["ckey"], "asker", "The paid row does not carry the player who asked")
	TEST_ASSERT_EQUAL(row["ship_name"], ship.name, "The paid row does not carry the crew's ship")
	var/list/details = json_decode(row["details"])
	TEST_ASSERT_EQUAL(details["kind"], "admin_test", "The paid row's details lose the kind")
	TEST_ASSERT_EQUAL(details["admin"], 1, "A job an admin touched is not marked in its paid row")

	// A job paid with the ship gone is still one row, with nothing paid
	SSmetrics.pending = list()
	var/datum/mission/fixer_job/admin_test/unpaid = new
	unpaid.time_started = world.time
	unpaid.active = TRUE
	unpaid.value = 500
	unpaid.finish_mission(null)
	var/list/unpaid_rows = rows_of("fixer_job_paid")
	TEST_ASSERT_EQUAL(length(unpaid_rows), 1, "A job paid to no ship wrote [length(unpaid_rows)] fixer_job_paid rows, not one")
	row = unpaid_rows[1]
	TEST_ASSERT_EQUAL(row["credits"], 0, "A job paid to no ship was credited")
	TEST_ASSERT_EQUAL(row["points"], 0, "A job with no ledger was given noise")
	details = json_decode(row["details"])
	TEST_ASSERT_NULL(details["admin"], "A job no admin touched is marked as one")

	// An ordinary mission writes no fixer row
	SSmetrics.pending = list()
	var/datum/mission/ordinary = new
	ordinary.time_started = world.time
	ordinary.active = TRUE
	ordinary.finish_mission(null)
	TEST_ASSERT_EQUAL(length(rows_of("fixer_job_paid")), 0, "An ordinary mission wrote a fixer_job_paid row")

/// A failed job writes one fixer_job_failed row with the reason; an offer never accepted writes none
/datum/unit_test/voidcrew_outpost_jobs_admin/metrics_failed

/datum/unit_test/voidcrew_outpost_jobs_admin/metrics_failed/Run()
	capture_metrics()
	var/mob/living/carbon/human/crewman = jobs_person(jobs_spot(0, 0))
	var/obj/structure/overmap/trader_outpost/outpost = jobs_outpost()
	var/obj/structure/overmap/ship/ship = admin_ship(list(crewman))

	// With the reason set
	var/datum/mission/fixer_job/admin_test/job = make_job(ship, outpost, crewman)
	job.fail_reason = "deadline" // FIXER_FAIL_DEADLINE
	job.timeout_timer = addtimer(CALLBACK(job, TYPE_PROC_REF(/datum/mission, on_timeout)), 10 MINUTES, TIMER_STOPPABLE)
	job.fail("Called off.")
	TEST_ASSERT_EQUAL(length(rows_of("mission_failed")), 1, "The shell's own mission_failed row went missing")
	var/list/failed = rows_of("fixer_job_failed")
	TEST_ASSERT_EQUAL(length(failed), 1, "A failed job wrote [length(failed)] fixer_job_failed rows, not one")
	var/list/row = failed[1]
	TEST_ASSERT_EQUAL(row["category"], "mission", "The failed row is not a mission row") // METRIC_MISSION
	TEST_ASSERT_EQUAL(row["subject"], "admin_test", "The failed row's subject is not the job's kind")
	TEST_ASSERT_EQUAL(row["ckey"], "asker", "The failed row does not carry the player who accepted")
	TEST_ASSERT_EQUAL(row["ship_name"], ship.name, "The failed row does not carry the crew's ship")
	var/list/details = json_decode(row["details"])
	TEST_ASSERT_EQUAL(details["reason"], "deadline", "The failed row does not carry the reason") // FIXER_FAIL_DEADLINE
	TEST_ASSERT_EQUAL(details["kind"], "admin_test", "The failed row's details lose the kind")

	// With no reason set: the clock running out (the shell's on_timeout()) is the deadline, and any other fail is a
	// drop ("Forget it.", or the ship's console)
	SSmetrics.pending = list()
	var/datum/mission/fixer_job/admin_test/timed_out = make_job(ship, outpost, crewman)
	timed_out.on_timeout()
	failed = rows_of("fixer_job_failed")
	TEST_ASSERT_EQUAL(length(failed), 1, "A job whose clock ran out wrote [length(failed)] fixer_job_failed rows, not one")
	row = failed[1]
	details = json_decode(row["details"])
	TEST_ASSERT_EQUAL(details["reason"], "deadline", "A job whose clock ran out was not failed as the deadline") // FIXER_FAIL_DEADLINE
	SSmetrics.pending = list()
	var/datum/mission/fixer_job/admin_test/dropped = make_job(ship, outpost, crewman)
	dropped.timeout_timer = addtimer(CALLBACK(dropped, TYPE_PROC_REF(/datum/mission, on_timeout)), 10 MINUTES, TIMER_STOPPABLE)
	dropped.fail("Dropped.")
	failed = rows_of("fixer_job_failed")
	TEST_ASSERT_EQUAL(length(failed), 1, "A job failed with no reason wrote [length(failed)] fixer_job_failed rows, not one")
	row = failed[1]
	details = json_decode(row["details"])
	TEST_ASSERT_EQUAL(details["reason"], "dropped", "A job failed with no reason was not a drop") // FIXER_FAIL_DROPPED

	// An offer nobody accepted writes nothing
	SSmetrics.pending = list()
	var/datum/mission/fixer_job/admin_test/offer = new
	offer.fail("Called off.")
	TEST_ASSERT_EQUAL(length(SSmetrics.pending), 0, "A job that was never accepted wrote a row")
