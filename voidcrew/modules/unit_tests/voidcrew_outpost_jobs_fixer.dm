/**
 * Outpost jobs tests: the fixers, the network, the talk and the strings (voidcrew/modules/outpost_jobs/). Owner: P1.
 * Helpers are in voidcrew_outpost_jobs_helpers.dm. Fork defines are included after the tests: use literal values
 * with a comment naming the define.
 *
 * Every test here runs on a network of its own (GLOB.fixer_network is swapped for the test and put back after),
 * with slates that never fill themselves: each test puts its own jobs on them.
 */

/datum/unit_test/voidcrew_outpost_jobs_fixer
	abstract_type = /datum/unit_test/voidcrew_outpost_jobs_fixer
	/// The round's network, put back in Destroy()
	var/datum/fixer_network/old_network
	/// The test's own network
	var/datum/fixer_network/network
	/// Ships made by crew(), taken apart in Destroy()
	var/list/ships = list()
	/// Jobs made by slate_job(), deleted in Destroy()
	var/list/jobs = list()

/datum/unit_test/voidcrew_outpost_jobs_fixer/New()
	. = ..()
	old_network = GLOB.fixer_network
	network = new
	network.auto_fill = FALSE
	GLOB.fixer_network = network

/datum/unit_test/voidcrew_outpost_jobs_fixer/Destroy()
	for(var/datum/mission/fixer_job/job in jobs)
		if(!QDELETED(job))
			qdel(job)
	jobs.Cut()
	jobs_cleanup(ships)
	ships.Cut()
	GLOB.fixer_network = old_network
	QDEL_NULL(network)
	return ..()

/// A fixer of `fixer_type` on the test room's tile 2,2, belonging to `outpost`
/datum/unit_test/voidcrew_outpost_jobs_fixer/proc/make_fixer(obj/structure/overmap/trader_outpost/outpost, fixer_type = /mob/living/carbon/human/npc/ambient_npc/outpost/fixer/nan)
	var/mob/living/carbon/human/npc/ambient_npc/outpost/fixer/fixer = allocate(fixer_type, jobs_spot(2, 2))
	fixer.set_place(SSambient_npcs.outpost_place(outpost))
	return fixer

/// A person at `dx`, `dy` flying with a crew of their own on a ship of their own
/datum/unit_test/voidcrew_outpost_jobs_fixer/proc/crew_person(dx = 2, dy = 3)
	var/mob/living/carbon/human/person = jobs_person(jobs_spot(dx, dy))
	ships += jobs_ship(list(person))
	return person

/// A job of `job_type` for `outpost`, put on its slate
/datum/unit_test/voidcrew_outpost_jobs_fixer/proc/slate_job(obj/structure/overmap/trader_outpost/outpost, job_type = /datum/mission/fixer_job/sabotage)
	var/datum/mission/fixer_job/job = network.new_job(job_type, outpost)
	if(!job)
		return null
	jobs += job
	var/datum/fixer_slate/slate = network.slate_for(outpost)
	slate.entries += job
	slate.made_at[job] = world.time
	return job

/// A job whose staging always finds room, so the take path is tested apart from any job package's staging. Weight 0:
/// never on a real slate.
/datum/mission/fixer_job/fixer_test
	job_kind = "sabotage" // FIXER_JOB_SABOTAGE
	slate_weight = 0

/datum/mission/fixer_job/fixer_test/stage()
	return TRUE

/// A second kind, for a slate of two
/datum/mission/fixer_job/fixer_test/other
	job_kind = "smuggle" // FIXER_JOB_SMUGGLE

/// The refusals come in spec 3.2's order: each check is only reached once every check before it passes
/datum/unit_test/voidcrew_outpost_jobs_fixer/refusal_order

/datum/unit_test/voidcrew_outpost_jobs_fixer/refusal_order/Run()
	var/obj/structure/overmap/trader_outpost/outpost = jobs_outpost()
	var/mob/living/carbon/human/npc/ambient_npc/outpost/fixer/fixer = make_fixer(outpost)
	var/mob/living/carbon/human/asker = jobs_person(jobs_spot(2, 3))

	// Burned and shipless: burned comes first
	network.burn(asker.mind)
	TEST_ASSERT_EQUAL(network.refusal(asker, fixer), "burned", "A burned asker heard something else first") // FIXER_LINE_BURNED
	network.burned_minds.Cut()
	TEST_ASSERT_EQUAL(network.refusal(asker, fixer), "no_ship", "An asker with no ship was not told so") // FIXER_LINE_NO_SHIP

	var/obj/structure/overmap/ship/ship = jobs_ship(list(asker))
	ships += ship
	var/datum/voidcrew_crew_record/crew = asker.mind.get_reputation_crew()
	TEST_ASSERT_NOTNULL(crew, "Setup: the asker has no crew record")

	// Wanted, an officer close, the port in trouble, busy, resting, nothing on the slate: all at once
	var/datum/outpost_warrant/warrant = outpost.police.ensure_warrant(asker.mind)
	warrant.heat = 10 // OUTPOST_POLICE_STAR_HEAT[1]: one star
	var/mob/living/carbon/human/officer = allocate(/mob/living/carbon/human/consistent, jobs_spot(3, 2))
	outpost.police.officers += officer
	if(outpost.recovery)
		outpost.recovery.state = 1 // OUTPOST_RECOVERY_TROUBLE
	ship.max_missions = 0
	network.rest(crew, outpost, 10 MINUTES)
	TEST_ASSERT_EQUAL(network.refusal(asker, fixer), "wanted", "A wanted crew heard something else first") // FIXER_LINE_WANTED

	warrant.heat = 0
	TEST_ASSERT_EQUAL(network.refusal(asker, fixer), "officer", "An officer beside the fixer did not stop the talk") // FIXER_LINE_OFFICER

	outpost.police.officers -= officer
	if(outpost.recovery)
		TEST_ASSERT_EQUAL(network.refusal(asker, fixer), "trouble", "A port in trouble did not stop the talk") // FIXER_LINE_TROUBLE
		outpost.recovery.state = 0 // OUTPOST_RECOVERY_NORMAL
	TEST_ASSERT_EQUAL(network.refusal(asker, fixer), "busy", "A ship at its job limit was not told it is busy") // FIXER_LINE_BUSY

	ship.max_missions = 3
	TEST_ASSERT_EQUAL(network.refusal(asker, fixer), "nothing", "A crew the fixer is resting was offered work") // FIXER_LINE_NOTHING

	network.rest_until.Cut()
	TEST_ASSERT(slate_job(outpost, /datum/mission/fixer_job/hit), "Setup: no hit could be made")
	TEST_ASSERT_EQUAL(network.refusal(asker, fixer), "no_trust", "A new crew was not told to start small") // FIXER_LINE_NO_TRUST

	TEST_ASSERT(slate_job(outpost, /datum/mission/fixer_job/sabotage), "Setup: no sabotage could be made")
	TEST_ASSERT_NULL(network.refusal(asker, fixer), "A crew that passes every check was refused")

/// The radial shows what the asker's state allows (spec 2.3), and a stale pick does nothing (abuse J22)
/datum/unit_test/voidcrew_outpost_jobs_fixer/radial

/datum/unit_test/voidcrew_outpost_jobs_fixer/radial/Run()
	var/obj/structure/overmap/trader_outpost/outpost = jobs_outpost()
	var/mob/living/carbon/human/npc/ambient_npc/outpost/fixer/fixer = make_fixer(outpost)
	var/mob/living/carbon/human/asker = crew_person()
	var/datum/voidcrew_crew_record/crew = asker.mind.get_reputation_crew()
	var/datum/mission/fixer_job/first = slate_job(outpost, /datum/mission/fixer_job/fixer_test)
	var/datum/mission/fixer_job/second = slate_job(outpost, /datum/mission/fixer_job/fixer_test/other)
	TEST_ASSERT(first && second, "Setup: the slate jobs could not be made")

	var/list/options = fixer.talk_options(asker)
	TEST_ASSERT_EQUAL(length(options), 1, "Before any offer the radial held more than \"Got any work?\"")
	TEST_ASSERT(("Got any work?" in options), "The radial has no \"Got any work?\"") // FIXER_TALK_WORK

	fixer.talk(asker, "Got any work?") // FIXER_TALK_WORK
	TEST_ASSERT_EQUAL(network.live_offer(outpost, crew), first, "Asking for work did not offer the first job on the slate")
	options = fixer.talk_options(asker)
	TEST_ASSERT(("I'll take it." in options), "A live offer shows no \"I'll take it.\"") // FIXER_TALK_TAKE
	TEST_ASSERT(("What else?" in options), "A second job on the slate shows no \"What else?\"") // FIXER_TALK_ELSE
	TEST_ASSERT(!("It's done." in options) && !("Forget it." in options), "A crew with no job sees a job's options")

	fixer.talk(asker, "What else?") // FIXER_TALK_ELSE
	TEST_ASSERT_EQUAL(network.live_offer(outpost, crew), second, "\"What else?\" did not offer the other job")

	// The offer runs out while the radial is open: the pick is not on the radial any more
	var/datum/fixer_slate/slate = network.slate_for(outpost)
	var/list/offer = slate.offers[fixer_crew_key(crew)]
	offer[2] = world.time
	TEST_ASSERT(!("I'll take it." in fixer.talk_options(asker)), "A lapsed offer still shows \"I'll take it.\"")

	// Holding a job: "Forget it." before the deed, "It's done." after
	fixer.talk(asker, "Got any work?")
	var/datum/mission/fixer_job/job = network.accept(asker, fixer)
	TEST_ASSERT(istype(job), "Setup: the offered job could not be taken ([job])")
	jobs += job
	options = fixer.talk_options(asker)
	TEST_ASSERT(("Forget it." in options), "A crew holding a job sees no \"Forget it.\"") // FIXER_TALK_DROP
	TEST_ASSERT(!("It's done." in options), "A job not done shows \"It's done.\"")
	job.deed_done = TRUE
	options = fixer.talk_options(asker)
	TEST_ASSERT(("It's done." in options), "A done job shows no \"It's done.\"") // FIXER_TALK_DONE
	TEST_ASSERT(!("Forget it." in options), "A done job still shows \"Forget it.\"")
	TEST_ASSERT(length(options) <= 4, "The radial showed more than four options")

/// Two takes in one tick give one job: a second crew is beaten to it, a crewmate is busy, and a held lock refuses (abuse J14)
/datum/unit_test/voidcrew_outpost_jobs_fixer/one_accept

/datum/unit_test/voidcrew_outpost_jobs_fixer/one_accept/Run()
	var/obj/structure/overmap/trader_outpost/outpost = jobs_outpost()
	var/mob/living/carbon/human/npc/ambient_npc/outpost/fixer/fixer = make_fixer(outpost)
	var/mob/living/carbon/human/first = crew_person(2, 3)
	var/mob/living/carbon/human/rival = crew_person(1, 2)
	var/datum/mission/fixer_job/job = slate_job(outpost, /datum/mission/fixer_job/fixer_test)
	TEST_ASSERT(job, "Setup: the slate job could not be made")
	var/datum/voidcrew_crew_record/first_crew = first.mind.get_reputation_crew()
	var/datum/voidcrew_crew_record/rival_crew = rival.mind.get_reputation_crew()
	TEST_ASSERT(first_crew && rival_crew && first_crew != rival_crew, "Setup: the two askers do not fly with two crews")

	network.make_offer(outpost, first_crew, job)
	network.make_offer(outpost, rival_crew, job)
	// The lock is held: nothing starts
	network.accept_locks[fixer_crew_key(first_crew)] = TRUE
	TEST_ASSERT_EQUAL(network.accept(first, fixer), "busy", "A take went through while the crew's lock was held") // FIXER_LINE_BUSY
	TEST_ASSERT(!job.active, "A locked take started the job")
	network.accept_locks.Cut()

	var/datum/mission/fixer_job/taken = network.accept(first, fixer)
	TEST_ASSERT_EQUAL(taken, job, "The first take did not get the job")
	TEST_ASSERT(job.active, "The taken job did not start")
	TEST_ASSERT_EQUAL(network.accept(rival, fixer), "gone", "A second crew took a job already taken") // FIXER_LINE_GONE
	TEST_ASSERT(!length(network.accept_locks), "A take left its lock behind")
	TEST_ASSERT_EQUAL(length(network.slate_for(outpost).refills), 1, "A taken entry did not start its refill")

	// A crewmate in the same tick: the crew already holds its one job
	var/mob/living/carbon/human/crewmate = jobs_person(jobs_spot(3, 3))
	var/datum/team/voidcrew/team = first_crew.teams[1]
	team.join_member(crewmate.mind)
	var/datum/mission/fixer_job/another = slate_job(outpost, /datum/mission/fixer_job/fixer_test/other)
	network.make_offer(outpost, first_crew, another)
	TEST_ASSERT_EQUAL(network.accept(crewmate, fixer), "busy", "A crew holding a job took a second") // FIXER_LINE_BUSY
	TEST_ASSERT(!another.active, "A crew's second job started")

/// Trust: sabotage and smuggle from 0 jobs paid, the safe and hits from 2, evidence and jailbreak from 5 (spec 3.3)
/datum/unit_test/voidcrew_outpost_jobs_fixer/trust_tiers

/datum/unit_test/voidcrew_outpost_jobs_fixer/trust_tiers/Run()
	var/obj/structure/overmap/trader_outpost/outpost = jobs_outpost()
	// What the evidence job and the jailbreak need at an outpost before they are offered at all: a locker and a cell
	outpost.police.evidence_locker = allocate(/obj/structure/closet/secure_closet/outpost_evidence, jobs_spot(4, 4))
	TEST_ASSERT_NOTNULL(jobs_cells(outpost.police), "Setup: the outpost has no cells")
	var/mob/living/carbon/human/asker = crew_person()
	var/datum/voidcrew_crew_record/crew = asker.mind.get_reputation_crew()
	var/list/expect = list(
		/datum/mission/fixer_job/sabotage = 0,
		/datum/mission/fixer_job/smuggle = 0,
		/datum/mission/fixer_job/breakin = 2, // FIXER_TRUST_TIER1
		/datum/mission/fixer_job/hit = 2,
		/datum/mission/fixer_job/breakin/evidence = 5, // FIXER_TRUST_TIER2
		/datum/mission/fixer_job/jailbreak = 5,
	)
	for(var/job_type in expect)
		var/datum/mission/fixer_job/job = slate_job(outpost, job_type)
		TEST_ASSERT(job, "Setup: [job_type] could not be made")
		for(var/paid in list(0, 2, 5))
			network.set_trust(crew, paid)
			TEST_ASSERT_EQUAL(network.trust_of(crew), paid, "set_trust() did not set [paid]")
			var/open = network.entry_open_to(job, crew, outpost)
			TEST_ASSERT_EQUAL(!!open, paid >= expect[job_type], "[job_type] at [paid] jobs paid: offered is [open ? "yes" : "no"]")

	// Paying counts: one more job paid
	network.set_trust(crew, 1)
	var/datum/mission/fixer_job/paid_job = jobs[1]
	paid_job.accepting_crew = crew
	network.note_paid(paid_job, 0, null)
	paid_job.accepting_crew = null
	TEST_ASSERT_EQUAL(network.trust_of(crew), 2, "A paid job did not add to trust")

/// Rest is a "ready at" time asking never brings nearer, and a later, shorter rest never shortens (spec 3.4)
/datum/unit_test/voidcrew_outpost_jobs_fixer/rest

/datum/unit_test/voidcrew_outpost_jobs_fixer/rest/Run()
	var/obj/structure/overmap/trader_outpost/outpost = jobs_outpost()
	var/mob/living/carbon/human/npc/ambient_npc/outpost/fixer/fixer = make_fixer(outpost)
	var/mob/living/carbon/human/asker = crew_person()
	var/datum/voidcrew_crew_record/crew = asker.mind.get_reputation_crew()
	var/datum/mission/fixer_job/job = slate_job(outpost, /datum/mission/fixer_job/sabotage)
	job.giver_outpost = outpost
	job.accepting_crew = crew

	network.note_failed(job, "deadline") // FIXER_FAIL_DEADLINE
	var/ready = network.ready_at(crew, outpost)
	TEST_ASSERT(ready >= world.time + 10 MINUTES, "A failed job did not rest the crew at the giving fixer for ten minutes") // FIXER_REST_FAILED
	TEST_ASSERT_EQUAL(network.refusal(asker, fixer), "failed", "The fixer did not bring up the failed job") // FIXER_LINE_FAILED
	fixer.talk(asker, "Got any work?") // FIXER_TALK_WORK
	TEST_ASSERT_EQUAL(network.refusal(asker, fixer), "nothing", "The failed line was said twice") // FIXER_LINE_NOTHING
	for(var/i in 1 to 3)
		network.refusal(asker, fixer)
	TEST_ASSERT_EQUAL(network.ready_at(crew, outpost), ready, "Asking moved the rest")

	network.note_paid(job, 0, fixer)
	TEST_ASSERT_EQUAL(network.ready_at(crew, outpost), ready, "A shorter rest after a pay brought the ready time nearer")

	// A spoiled job rests nobody
	network.rest_until.Cut()
	network.note_failed(job, "spoiled") // FIXER_FAIL_SPOILED
	TEST_ASSERT_EQUAL(network.ready_at(crew, outpost), 0, "A spoiled job rested the crew")
	job.accepting_crew = null

/// A counted crime against a fixer burns the offender and their crew, and the burn outlives the crew record (abuse J18)
/datum/unit_test/voidcrew_outpost_jobs_fixer/burn

/datum/unit_test/voidcrew_outpost_jobs_fixer/burn/Run()
	var/obj/structure/overmap/trader_outpost/outpost = jobs_outpost()
	var/mob/living/carbon/human/npc/ambient_npc/outpost/fixer/fixer = make_fixer(outpost)
	TEST_ASSERT((outpost.police in network.watched_police), "A fixer's police are not heard")
	var/mob/living/carbon/human/offender = jobs_person(jobs_spot(2, 3))
	var/mob/living/carbon/human/crewmate = jobs_person(jobs_spot(3, 3))
	var/mob/living/carbon/human/bystander = jobs_person(jobs_spot(4, 4))
	var/obj/structure/overmap/ship/ship = jobs_ship(list(offender, crewmate))
	ships += ship

	outpost.police.count_crime(bystander, "unarmed", offender) // OUTPOST_CRIME_ASSAULT_UNARMED
	TEST_ASSERT(!network.is_burned(bystander), "A crime against someone else burned the offender")

	outpost.police.count_crime(offender, "unarmed", fixer) // OUTPOST_CRIME_ASSAULT_UNARMED
	TEST_ASSERT(network.is_burned(offender), "Hitting a fixer did not burn the offender")
	TEST_ASSERT(network.is_burned(crewmate), "Hitting a fixer did not burn the offender's crew")
	TEST_ASSERT_EQUAL(network.refusal(crewmate, fixer), "burned", "A burned crew was offered work") // FIXER_LINE_BURNED

	// The crew re-forms under a new record: the offender is still burned, and so is any crew they fly with
	jobs_cleanup(list(ship))
	ships -= ship
	var/obj/structure/overmap/ship/new_ship = jobs_ship(list(offender, crewmate))
	ships += new_ship
	TEST_ASSERT(network.is_burned(offender), "A new crew record shed the offender's burn")
	TEST_ASSERT(network.is_burned(crewmate), "A new crew with a burned person on it is offered work")

	network.clear_crew(offender.mind.get_reputation_crew())
	TEST_ASSERT(!network.is_burned(crewmate), "Clearing the crew left a burn on it")

/// A living fixer can't be shut in a closet or carried off in a bag; a dead one can, like any body (abuse J20)
/datum/unit_test/voidcrew_outpost_jobs_fixer/closet

/datum/unit_test/voidcrew_outpost_jobs_fixer/closet/Run()
	var/obj/structure/overmap/trader_outpost/outpost = jobs_outpost()
	var/mob/living/carbon/human/npc/ambient_npc/outpost/fixer/fixer = make_fixer(outpost, /mob/living/carbon/human/npc/ambient_npc/outpost/fixer/quill)
	TEST_ASSERT(HAS_TRAIT(fixer, "no_containment"), "A living fixer can be shut in a closet") // TRAIT_NO_CONTAINMENT
	TEST_ASSERT(HAS_TRAIT(fixer, "no_storage_insert"), "A living fixer can be put in a bag") // TRAIT_NO_STORAGE_INSERT
	var/obj/structure/closet/closet = allocate(/obj/structure/closet, get_turf(fixer))
	closet.open()
	closet.close()
	TEST_ASSERT(fixer.loc != closet, "A living fixer was shut in a closet")

	fixer.death()
	TEST_ASSERT(!HAS_TRAIT(fixer, "no_containment"), "A fixer's body can't be bagged") // TRAIT_NO_CONTAINMENT
	TEST_ASSERT(network.lost_originals[REF(outpost)], "A fixer's death did not leave the seat to a stand-in")

/// Fixers are not counted in the crowd's cap, and their role has room for one only while none is there (L24)
/datum/unit_test/voidcrew_outpost_jobs_fixer/crowd

/datum/unit_test/voidcrew_outpost_jobs_fixer/crowd/Run()
	var/obj/structure/overmap/trader_outpost/outpost = jobs_outpost()
	var/datum/ambient_place/outpost/place = SSambient_npcs.outpost_place(outpost)
	var/datum/ambient_outpost_role/fixer/nan/role = allocate(/datum/ambient_outpost_role/fixer/nan)
	TEST_ASSERT_EQUAL(place.open_slots(role), 1, "An outpost with no fixer has no room for one")
	var/mob/living/carbon/human/npc/ambient_npc/outpost/fixer/fixer = make_fixer(outpost)
	fixer.role = role.type
	TEST_ASSERT((fixer in place.living_npcs()), "A fixer is not one of the town's people outside the cap count")
	TEST_ASSERT((fixer in place.living_fixers()), "A fixer is not among the place's fixers")
	TEST_ASSERT_EQUAL(place.open_slots(role), 0, "An outpost with its fixer has room for another")
	place.fixer_cap_count = TRUE
	TEST_ASSERT(!(fixer in place.living_npcs()), "A fixer counts against the crowd's cap")
	TEST_ASSERT_EQUAL(place.open_slots(role), 0, "While the cap is counted, an outpost with its fixer has room for another")
	TEST_ASSERT_EQUAL(place.crowd_count(get_turf(fixer)), INFINITY, "Someone could settle on a fixer's tile")
	place.fixer_cap_count = FALSE

/// L25: a crew that may take some kind of job always finds one on the slate, even when the slate held only work above it
/datum/unit_test/voidcrew_outpost_jobs_fixer/fitted_slate

/datum/unit_test/voidcrew_outpost_jobs_fixer/fitted_slate/Run()
	var/obj/structure/overmap/trader_outpost/outpost = jobs_outpost()
	var/mob/living/carbon/human/asker = crew_person()
	var/datum/voidcrew_crew_record/crew = asker.mind.get_reputation_crew()
	network.set_trust(crew, 0)
	var/datum/mission/fixer_job/hit = slate_job(outpost, /datum/mission/fixer_job/hit)
	var/datum/mission/fixer_job/evidence = slate_job(outpost, /datum/mission/fixer_job/breakin/evidence)
	TEST_ASSERT(hit && evidence, "Setup: the slate's jobs could not be made")
	TEST_ASSERT(!length(network.open_entries(outpost, crew)), "Setup: a new crew was offered work above it")

	// Whether any kind is open to this crew here at all (a job package's own test may say no in this room)
	var/any_kind = FALSE
	for(var/job_type in network.job_weights())
		var/datum/mission/fixer_job/probe = network.new_job(job_type, outpost)
		if(probe && network.entry_open_to(probe, crew, outpost))
			any_kind = TRUE
		qdel(probe)

	network.auto_fill = TRUE
	var/list/open = network.open_entries(outpost, crew)
	network.auto_fill = FALSE
	var/datum/fixer_slate/slate = network.slate_for(outpost)
	jobs |= slate.entries
	if(!any_kind)
		TEST_ASSERT(!length(open), "A crew no kind is open to was fitted a job")
		return
	TEST_ASSERT_EQUAL(length(open), 1, "A crew that may take some kind found nothing on the slate")
	var/datum/mission/fixer_job/fitted = open[1]
	TEST_ASSERT(fitted in slate.entries, "The fitted job is not on the slate")
	TEST_ASSERT_EQUAL(length(slate.entries), 2, "Fitting a job did not swap out an entry") // FIXER_SLATE_SIZE
	TEST_ASSERT(QDELETED(hit), "The oldest entry nobody held did not give way")
	TEST_ASSERT(!QDELETED(evidence) && (evidence in slate.entries), "An entry that did not need to give way was dropped")

/// The strings: every speaker has every line, at least two of each, inside the bounds and free of the rules' words
/datum/unit_test/voidcrew_outpost_jobs_fixer/strings

/datum/unit_test/voidcrew_outpost_jobs_fixer/strings/Run()
	var/list/problems = fixer_strings_problems()
	for(var/problem in problems)
		TEST_FAIL(problem)
	TEST_ASSERT_EQUAL(fixer_cut("abcdef", 4), "abc…", "A cut line does not end in an ellipsis inside its bound")
	TEST_ASSERT_EQUAL(fixer_credits_text(6240), "6,240", "Credits have no thousands separator")
	TEST_ASSERT_EQUAL(fixer_credits_text(980), "980", "Small credits gained a separator")
	TEST_ASSERT_EQUAL(fixer_credits_text(1234567), "1,234,567", "Large credits are separated wrong")
