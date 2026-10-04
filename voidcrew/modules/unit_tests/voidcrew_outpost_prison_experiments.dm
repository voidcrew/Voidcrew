/**
 * The prison wing's experiments: the researcher's offers, serums, specimens and their creatures.
 *
 * Voidcrew defines are not visible from test files, so tuning values appear as literals with
 * the define named beside them. Prisons are driven with experiments_tick(seconds) (or tick())
 * with their own processing stopped, never by waiting in real time, except for beams, which run on
 * timers. Nobody is on the level, so creatures' AI sleeps and the tests call their blows
 * themselves. The crew counts as home through crew_home_override, and the wing's condition scores
 * are pinned. Fixtures are in voidcrew_outpost_prison_helpers.dm.
 */

/// A prison claim whose crew counts as home and whose wing is spotless, lit and powered
/datum/unit_test/voidcrew_outpost_management/proc/experiment_test_claim(owner_key, trouble = FALSE)
	var/obj/structure/overmap/dynamic/player_outpost/home = trouble ? trouble_test_claim(owner_key) : prison_test_claim(owner_key)
	if(!home)
		return null
	var/datum/outpost_prison/prison = test_prison(home)
	prison.crew_home_override = TRUE
	prison.clean_score = 100
	prison.lit_score = 100
	prison.powered_score = 100
	return home

/// A researcher standing anywhere in the office
/datum/unit_test/voidcrew_outpost_management/proc/office_researcher(datum/outpost_prison/prison)
	for(var/turf/tile as anything in prison.wing_turfs())
		var/mob/living/basic/outpost_kessler_staff/researcher/doctor = locate() in tile
		if(doctor)
			return doctor
	return null

// ===== THE RESEARCHER =====

/datum/unit_test/voidcrew_outpost_prison_experiment_offers
	parent_type = /datum/unit_test/voidcrew_outpost_management

/datum/unit_test/voidcrew_outpost_prison_experiment_offers/Run()
	var/obj/structure/overmap/dynamic/player_outpost/home = experiment_test_claim("offerowner")
	TEST_ASSERT_NOTNULL(home, "The offer test prison did not load")
	var/datum/outpost_prison/prison = test_prison(home)
	prison.intake_open = TRUE
	var/mob/living/carbon/human/owner = make_player(prison_spot(home, 12, 3), "offerowner")
	var/mob/living/carbon/human/visitor = make_player(prison_spot(home, 13, 3), "offervisitor")

	// Visits are scheduled from the wing's first arrival, 15-25 minutes off, and wait for the crew.
	prison.experiments_tick(1)
	TEST_ASSERT(!prison.visits_started, "The researcher was scheduled before any prisoner arrived")
	var/mob/living/basic/outpost_prisoner/first = test_prisoner(prison, prison_spot(home, 8, 8))
	prison.experiments_tick(1)
	TEST_ASSERT(prison.visits_started, "The first arrival did not schedule the researcher")
	TEST_ASSERT(prison.researcher_wait >= 900 && prison.researcher_wait <= 1500, "The first visit is [prison.researcher_wait] s off, not 15-25 minutes") // OUTPOST_EXPERIMENT_FIRST_VISIT_MIN/_MAX
	var/wait = prison.researcher_wait
	prison.crew_home_override = FALSE
	prison.experiments_tick(600)
	TEST_ASSERT_EQUAL(prison.researcher_wait, wait, "The researcher's clock ran with nobody home")
	prison.crew_home_override = TRUE

	// A failed gate tries again in two minutes.
	prison.intake_open = FALSE
	prison.researcher_wait = 1
	prison.experiments_tick(1)
	TEST_ASSERT_NULL(prison.researcher, "The researcher came with intake shut")
	TEST_ASSERT_EQUAL(prison.researcher_wait, 120, "A failed gate did not retry in 2 minutes") // OUTPOST_EXPERIMENT_RETRY
	TEST_ASSERT_EQUAL(prison.researcher_gate_failure(), "intake", "Shut intake was not the failed gate")
	prison.intake_open = TRUE
	prison.riot_active = TRUE
	TEST_ASSERT_EQUAL(prison.researcher_gate_failure(), "trouble", "A riot did not keep the researcher away")
	prison.riot_active = FALSE
	prison.crew_home_override = FALSE
	TEST_ASSERT_EQUAL(prison.researcher_gate_failure(), "crew", "The researcher would come with nobody home")
	prison.crew_home_override = TRUE

	// A filthy wing gets one short visit and a complaint, then the gate retries quietly.
	prison.clean_score = 0
	prison.lit_score = 0
	prison.researcher_wait = 1
	prison.experiments_tick(1)
	TEST_ASSERT_NULL(prison.researcher, "The researcher offered work in a filthy wing")
	TEST_ASSERT(prison.pigsty_shown, "The researcher did not come to complain about the wing")
	TEST_ASSERT_EQUAL(prison.researcher_wait, 120, "The conditions gate did not retry in 2 minutes")
	var/mob/living/basic/outpost_kessler_staff/researcher/complainer = office_researcher(prison)
	TEST_ASSERT_NOTNULL(complainer, "Nobody came to look at the filthy wing")
	TEST_ASSERT_NULL(complainer.prison, "The complaining researcher held on to the prison")
	qdel(complainer)
	prison.researcher_wait = 1
	prison.experiments_tick(1)
	TEST_ASSERT_NULL(office_researcher(prison), "The researcher came back to complain twice")
	prison.clean_score = 100
	prison.lit_score = 100

	// A clean wing: the researcher comes to the office with a serum; the first offer is never a specimen.
	prison.researcher_wait = 1
	prison.experiments_tick(1)
	var/mob/living/basic/outpost_kessler_staff/researcher/doctor = prison.researcher
	TEST_ASSERT_NOTNULL(doctor, "The researcher did not come to a clean wing")
	TEST_ASSERT(prison.staff_ground[get_turf(doctor)], "The researcher did not come to the office")
	TEST_ASSERT(!prison.pigsty_shown, "The complaint flag outlived a proper visit")
	TEST_ASSERT_EQUAL(prison.offer_kind, "serum", "The wing's first offer was a specimen")
	TEST_ASSERT(prison.offer_form in list("hulk", "nightmare", "fly"), "The serum rolled [prison.offer_form]")
	var/list/block = prison.experiment_payload()
	TEST_ASSERT_EQUAL(block["stage"], "offered", "The console did not show the offer")
	TEST_ASSERT_EQUAL(block["form"], "unknown", "The console named the serum's form")
	TEST_ASSERT(block["researcher_present"], "The console did not show the researcher")
	TEST_ASSERT_EQUAL(block["time_left"], 180, "The researcher does not wait 3 minutes") // OUTPOST_EXPERIMENT_STAY
	// The offer is the researcher talking: a line or two with the fee, no card of hazards and terms.
	var/offer = prison.offer_text()
	TEST_ASSERT(findtext(offer, "300 to 600 cr"), "The serum offer does not give the fee: [offer]") // OUTPOST_EXPERIMENT_FEE_FLY, _HULK and _NIGHTMARE
	TEST_ASSERT(length(splittext(offer, " ")) <= 25, "The serum offer runs to [length(splittext(offer, " "))] words: [offer]")
	TEST_ASSERT(!findtext(offer, "\n") && !findtext(offer, "Hazard"), "The serum offer is still a card: [offer]")

	// Only managers get the offer; while one reads it nobody else can, and the researcher waits up to 5 minutes.
	TEST_ASSERT(!doctor.talk_to(visitor), "A visitor got the researcher's offer")
	TEST_ASSERT_NULL(prison.offer_claim, "A visitor claimed the offer")
	var/mob/living/carbon/human/steward = make_player(prison_spot(home, 11, 3), "offersteward")
	home.stewards += steward.mind
	prison.offer_claim = WEAKREF(owner)
	TEST_ASSERT(!prison.present_offer(steward), "A second manager opened an offer another was reading")
	TEST_ASSERT_EQUAL(prison.offer_claim?.resolve(), owner, "A second manager took the claim")
	prison.experiments_tick(200)
	TEST_ASSERT_EQUAL(prison.researcher, doctor, "The researcher left while a manager read the offer")
	TEST_ASSERT_EQUAL(prison.experiment_payload()["time_left"], 100, "The open offer does not run to 5 minutes") // OUTPOST_EXPERIMENT_STAY_OPEN
	prison.experiments_tick(100)
	TEST_ASSERT_NULL(prison.researcher, "The researcher waited past 5 minutes")
	TEST_ASSERT(doctor.leaving, "The researcher did not leave")
	TEST_ASSERT(abs(prison.sweetener - 0.1) < 0.001, "An ignored offer raised the next by [prison.sweetener], not 10%") // OUTPOST_EXPERIMENT_SWEETENER
	TEST_ASSERT(prison.researcher_wait >= 2100 && prison.researcher_wait <= 3000, "The next visit is [prison.researcher_wait] s off, not 35-50 minutes") // OUTPOST_EXPERIMENT_GAP_MIN/_MAX

	// Declines raise the next offer, up to 30%.
	for(var/i in 1 to 3)
		var/mob/living/basic/outpost_kessler_staff/researcher/visiting = prison.spawn_researcher(TRUE)
		TEST_ASSERT_NOTNULL(visiting, "An admin could not send the researcher")
		TEST_ASSERT(prison.decline_offer(owner), "Declining an offer failed")
	TEST_ASSERT(abs(prison.sweetener - 0.3) < 0.001, "Four passed offers raised the next by [prison.sweetener], not 30%") // OUTPOST_EXPERIMENT_SWEETENER_MAX

	// Taking it: the serum in hand, the sweetener spent on it, and no visits while it is out.
	var/mob/living/basic/outpost_kessler_staff/researcher/seller = prison.spawn_researcher(TRUE)
	TEST_ASSERT_NOTNULL(seller, "An admin could not send the researcher")
	prison.offer_kind = "serum"
	prison.offer_form = "fly"
	TEST_ASSERT(findtext(prison.offer_text(), "390"), "The sweetened offer does not show the fly's 300 cr fee raised by 30%")
	prison.offer_kind = "specimen"
	offer = prison.offer_text()
	TEST_ASSERT(findtext(offer, "780 cr"), "The sweetened specimen offer does not show its 600 cr fee raised by 30%: [offer]") // OUTPOST_EXPERIMENT_FEE_CHANGELING
	TEST_ASSERT(length(splittext(offer, " ")) <= 25 && !findtext(offer, "\n"), "The specimen offer is not short: [offer]")
	prison.offer_kind = "serum"
	var/obj/item/outpost_experiment/serum/serum = prison.accept_offer(owner)
	TEST_ASSERT(istype(serum), "Taking the offer gave no serum")
	TEST_ASSERT(owner.is_holding(serum), "The serum did not go into the manager's hands")
	TEST_ASSERT(abs(prison.pending_multiplier - 1.3) < 0.001, "The taken offer pays [prison.pending_multiplier]x, not 1.3x")
	TEST_ASSERT_EQUAL(prison.sweetener, 0, "Taking an offer did not reset the sweetener")
	TEST_ASSERT(seller.leaving, "The researcher stayed after the offer was taken")
	TEST_ASSERT_NULL(prison.researcher_wait, "The researcher was due again with the serum still out")
	TEST_ASSERT_EQUAL(prison.researcher_gate_failure(), "busy", "The researcher would come back with the serum still out")
	block = prison.experiment_payload()
	TEST_ASSERT_EQUAL(block["stage"], "offered", "The console did not show the serum out")
	TEST_ASSERT(!block["researcher_present"], "The console still showed the researcher")
	TEST_ASSERT_EQUAL(block["form"], "unknown", "The console named the serum's form")

	// Specimens: never the first offer, only with two prisoners, then about 30%.
	prison.offers_made = 0
	prison.roll_offer()
	TEST_ASSERT_EQUAL(prison.offer_kind, "serum", "The first offer was a specimen")
	var/specimens = 0
	for(var/i in 1 to 60)
		prison.roll_offer()
		if(prison.offer_kind == "specimen")
			specimens++
	TEST_ASSERT_EQUAL(specimens, 0, "A specimen was offered to a wing with one prisoner")
	var/mob/living/basic/outpost_prisoner/second = test_prisoner(prison, prison_spot(home, 10, 8))
	for(var/i in 1 to 60)
		prison.roll_offer()
		if(prison.offer_kind == "specimen")
			specimens++
			TEST_ASSERT_EQUAL(prison.offer_form, "changeling", "A specimen was not the changeling")
	TEST_ASSERT(specimens > 0 && specimens < 60, "[specimens] of 60 offers were specimens")
	TEST_ASSERT(first && second, "The prisoners vanished")

	// Hurt, the researcher leaves at once, unhurt, and the next offer is not sweeter for it.
	qdel(serum)
	var/mob/living/basic/outpost_kessler_staff/researcher/target = prison.spawn_researcher(TRUE)
	TEST_ASSERT_NOTNULL(target, "An admin could not send the researcher")
	var/sweet = prison.sweetener
	target.apply_damage(10, BRUTE)
	TEST_ASSERT(target.leaving, "A hurt researcher stayed")
	TEST_ASSERT_EQUAL(target.health, target.maxHealth, "The researcher could be hurt")
	TEST_ASSERT_NULL(prison.researcher, "A hurt researcher kept the offer open")
	TEST_ASSERT_EQUAL(prison.sweetener, sweet, "Hurting the researcher sweetened the next offer")

	// Deleted without leaving (gibbed, dusted, an admin): the next visit is still scheduled.
	var/mob/living/basic/outpost_kessler_staff/researcher/doomed = prison.spawn_researcher(TRUE)
	TEST_ASSERT_NOTNULL(doomed, "An admin could not send the researcher")
	TEST_ASSERT_NULL(prison.researcher_wait, "A visit was scheduled while the researcher waited")
	qdel(doomed)
	TEST_ASSERT_NULL(prison.researcher, "A deleted researcher kept the offer open")
	prison.experiments_tick(1)
	TEST_ASSERT(prison.researcher_wait >= 2100 && prison.researcher_wait <= 3000, "A deleted researcher left the next visit at [prison.researcher_wait], not 35-50 minutes off") // OUTPOST_EXPERIMENT_GAP_MIN/_MAX
	settle_prison_air(home)

// ===== ITEMS =====

/datum/unit_test/voidcrew_outpost_prison_experiment_items
	parent_type = /datum/unit_test/voidcrew_outpost_management

/datum/unit_test/voidcrew_outpost_prison_experiment_items/Run()
	var/obj/structure/overmap/dynamic/player_outpost/home = experiment_test_claim("itemowner")
	TEST_ASSERT_NOTNULL(home, "The item test prison did not load")
	var/datum/outpost_prison/prison = test_prison(home)
	prison.visits_started = TRUE
	var/mob/living/carbon/human/owner = make_player(prison_spot(home, 8, 9), "itemowner")
	var/mob/living/carbon/human/visitor = make_player(prison_spot(home, 9, 9), "itemvisitor")
	var/turf/yard = prison_spot(home, 8, 8)
	var/mob/living/basic/outpost_prisoner/subject = test_prisoner(prison, yard)
	var/mob/living/basic/outpost_prisoner/stranger = allocate(/mob/living/basic/outpost_prisoner, prison_spot(home, 10, 8))

	// The serum: a member's hands, this wing's prisoners, the cell block.
	var/obj/item/outpost_experiment/serum/serum = new(prison_spot(home, 8, 9), prison, "fly")
	TEST_ASSERT(serum in prison.live_items(), "The prison does not track its serum")
	TEST_ASSERT_NOTNULL(serum.dose_error(visitor, subject), "A visitor could use the serum")
	TEST_ASSERT_NOTNULL(serum.dose_error(owner, visitor), "The serum went into someone who is not a prisoner")
	TEST_ASSERT_NOTNULL(serum.dose_error(owner, stranger), "The serum went into a prisoner of no wing")
	subject.forceMove(prison_spot(home, 9, 3))
	TEST_ASSERT_NOTNULL(serum.dose_error(owner, subject), "The serum went into a prisoner out of the cell block")
	subject.forceMove(yard)
	TEST_ASSERT_NULL(serum.dose_error(owner, subject), "The owner could not use the serum: [serum.dose_error(owner, subject)]")
	owner.put_in_active_hand(serum)
	TEST_ASSERT_EQUAL(serum.interact_with_atom(subject, owner), ITEM_INTERACT_SUCCESS, "Injecting the serum failed")
	TEST_ASSERT(QDELETED(serum), "The serum was not used up")
	TEST_ASSERT(prison.experiment_active(), "The serum started no experiment")
	TEST_ASSERT_EQUAL(prison.experiment.form, "fly", "The serum started a [prison.experiment.form], not its own form")
	TEST_ASSERT_EQUAL(prison.experiment.subject(), subject, "The serum's subject is someone else")
	TEST_ASSERT(prison.experiment_end_admin(), "The admin end found nothing to end")
	TEST_ASSERT_NULL(prison.experiment, "The admin end left the experiment")
	TEST_ASSERT(!subject.experiment_subject, "The subject stayed dosed after the experiment was called off")

	// Items spoil (a lapsed offer) and do not survive leaving the level.
	var/obj/item/outpost_experiment/serum/stale = new(prison_spot(home, 8, 9), prison, "hulk")
	var/datum/component/outpost_experiment_item/label = stale.item_tag()
	label.expires_at = world.time - 1
	prison.researcher_wait = null
	prison.experiments_tick(1)
	TEST_ASSERT(QDELETED(stale), "A serum outlived its 10 minutes")
	TEST_ASSERT(prison.researcher_wait >= 2100 && prison.researcher_wait <= 3000, "A spoiled serum did not schedule the next visit")
	// Gone before the prison noticed, and dropped from its list by a console refresh first: still scheduled.
	var/obj/item/outpost_experiment/serum/lost = new(prison_spot(home, 8, 9), prison, "hulk")
	prison.researcher_wait = null
	qdel(lost)
	prison.experiment_payload()
	TEST_ASSERT(!length(prison.experiment_items), "The console refresh did not drop the deleted serum")
	prison.experiments_tick(1)
	TEST_ASSERT(prison.researcher_wait >= 2100 && prison.researcher_wait <= 3000, "A serum lost before the prison noticed left no visit scheduled")
	TEST_ASSERT(run_loc_floor_bottom_left.z != prison.wing_z(), "The test floor is on the outpost's level")
	var/obj/item/outpost_experiment/specimen/traveller = new(prison_spot(home, 8, 9), prison, "changeling")
	traveller.forceMove(run_loc_floor_bottom_left)
	prison.experiments_tick(1)
	TEST_ASSERT(QDELETED(traveller), "A specimen jar survived leaving the level")

	// The specimen goes into food. A person who eats it throws it up.
	var/obj/item/outpost_experiment/specimen/jar = new(prison_spot(home, 8, 9), prison, "changeling")
	owner.put_in_active_hand(jar)
	var/obj/item/food/meal = allocate(/obj/item/food/prison_ration, prison_spot(home, 8, 9))
	TEST_ASSERT_EQUAL(jar.interact_with_atom(meal, visitor), ITEM_INTERACT_BLOCKING, "A visitor could open the specimen jar")
	TEST_ASSERT_EQUAL(jar.interact_with_atom(meal, owner), ITEM_INTERACT_SUCCESS, "Putting the specimen in food failed")
	TEST_ASSERT(QDELETED(jar), "The jar was not used up")
	var/datum/component/outpost_experiment_item/taint = meal.GetComponent(/datum/component/outpost_experiment_item)
	TEST_ASSERT_NOTNULL(taint, "The food did not take the specimen")
	TEST_ASSERT_EQUAL(taint.kind, "tainted", "The food's specimen is a [taint.kind]")
	TEST_ASSERT(meal in prison.live_items(), "The prison does not track the tainted food")
	var/list/looked = list()
	SEND_SIGNAL(meal, COMSIG_ATOM_EXAMINE_MORE, owner, looked)
	TEST_ASSERT(length(looked), "A close look at tainted food shows nothing")
	var/bitten = SEND_SIGNAL(meal, COMSIG_FOOD_EATEN, visitor, visitor, 0, 5)
	TEST_ASSERT(bitten & DESTROY_FOOD, "A person kept the specimen down")
	TEST_ASSERT_NULL(meal.GetComponent(/datum/component/outpost_experiment_item), "The specimen was still in the food after it came back up")
	TEST_ASSERT_NOTNULL(locate(/obj/effect/decal/cleanable/vomit) in range(1, visitor), "Nobody threw anything up")
	TEST_ASSERT(!prison.experiment_active(), "A person eating the specimen started an experiment")

	// One of the wing's prisoners eating it becomes the host; a prisoner of no wing throws it up.
	var/obj/item/food/dinner = allocate(/obj/item/food/prison_ration, prison_spot(home, 8, 9))
	dinner.AddComponent(/datum/component/outpost_experiment_item, prison, "tainted", "changeling", world.time + 10 MINUTES)
	subject.eat_food(dinner)
	TEST_ASSERT(prison.experiment_active(), "A prisoner eating the specimen started nothing")
	TEST_ASSERT_EQUAL(prison.experiment.form, "changeling", "The specimen started a [prison.experiment.form]")
	TEST_ASSERT_EQUAL(prison.experiment.stage, "incubating", "The host is not incubating")
	TEST_ASSERT_NOTNULL(prison.changeling_event(), "No changeling event started")
	TEST_ASSERT(subject.experiment_subject, "The host is not the experiment's subject")
	var/list/block = prison.experiment_payload()
	TEST_ASSERT_EQUAL(block["form"], "changeling", "The console does not show the specimen")
	TEST_ASSERT_EQUAL(block["stage"], "incubating", "The console does not show the incubation")
	prison.experiment_end_admin()
	var/obj/item/food/snack = allocate(/obj/item/food/prison_ration, prison_spot(home, 10, 9))
	snack.AddComponent(/datum/component/outpost_experiment_item, prison, "tainted", "changeling", world.time + 10 MINUTES)
	stranger.eat_food(snack)
	TEST_ASSERT(!prison.experiment_active(), "A prisoner of no wing hosted the specimen")
	TEST_ASSERT_NULL(snack.GetComponent(/datum/component/outpost_experiment_item), "The specimen survived a prisoner of no wing")
	settle_prison_air(home)

// ===== THE SERUM =====

/datum/unit_test/voidcrew_outpost_prison_experiment_serum
	parent_type = /datum/unit_test/voidcrew_outpost_management

/datum/unit_test/voidcrew_outpost_prison_experiment_serum/Run()
	var/obj/structure/overmap/dynamic/player_outpost/home = experiment_test_claim("serumowner", trouble = TRUE)
	TEST_ASSERT_NOTNULL(home, "The serum test prison did not load")
	var/datum/outpost_prison/prison = test_prison(home)
	var/datum/bank_account/treasury = trouble_fund(home, 0)
	var/turf/yard = prison_spot(home, 8, 8)
	var/mob/living/basic/outpost_prisoner/subject = trouble_prisoner(prison, yard)
	var/mob/living/basic/outpost_prisoner/buddy = trouble_prisoner(prison, prison_spot(home, 12, 8))
	TEST_ASSERT_NULL(prison.experiment_payload(), "The console shows an experiment before there is one")

	TEST_ASSERT(prison.start_experiment("hulk", subject), "A prisoner in the yard could not be dosed")
	TEST_ASSERT(!prison.start_experiment("fly", buddy), "A second experiment started while one ran")
	TEST_ASSERT(subject.experiment_subject, "The subject is not marked")
	var/list/block = prison.experiment_payload()
	TEST_ASSERT_EQUAL(block["form"], "unknown", "The console named the serum before it showed")
	TEST_ASSERT_EQUAL(block["stage"], "dosed", "The console does not show the dose")
	TEST_ASSERT_EQUAL(block["subject"], subject.real_name, "The console names the wrong subject")
	TEST_ASSERT_EQUAL(block["time_left"], 60, "The twitch does not last 60 s") // OUTPOST_EXPERIMENT_TWITCH

	// While it runs the subject earns nothing, and nothing else waits for it: bolting prisoners in is
	// no protective custody (owner, 2026-09-25), and arrivals keep coming. Riots during an experiment
	// are in voidcrew_outpost_prison_panic.dm.
	TEST_ASSERT_EQUAL(prison.pay_factor(subject), 0, "A dosed prisoner still earned")
	TEST_ASSERT(!prison.protective_custody(), "An experiment made bolting prisoners in protective custody")
	prison.intake_open = TRUE
	TEST_ASSERT(prison.intake_state() != "experiment", "Arrivals waited for the experiment")
	prison.intake_open = FALSE

	// The twitch waits for the crew, and for the subject to be in the cell block.
	prison.crew_home_override = FALSE
	prison.experiments_tick(30)
	TEST_ASSERT_EQUAL(prison.experiment.twitch_left, 60, "The twitch ran with nobody home")
	prison.crew_home_override = TRUE
	prison.experiments_tick(25)
	TEST_ASSERT_EQUAL(prison.experiment.stage, "twitching", "The tells did not start 40 s before the change") // OUTPOST_EXPERIMENT_TELLS
	TEST_ASSERT_EQUAL(prison.experiment_payload()["form"], "unknown", "The console named the serum during the tells")
	subject.forceMove(prison_spot(home, 9, 3))
	prison.experiments_tick(20)
	TEST_ASSERT_EQUAL(prison.experiment.twitch_left, 35, "The twitch ran outside the cell block")
	subject.forceMove(yard)

	// The change: the hulk where they stood, and the fee paid. No clock: it stays until it is put down.
	prison.experiments_tick(35)
	var/mob/living/basic/outpost_experiment/hulk/hulk = locate() in yard
	TEST_ASSERT_NOTNULL(hulk, "The subject did not turn into a hulk")
	TEST_ASSERT(QDELETED(subject), "The subject stayed after the change")
	TEST_ASSERT_EQUAL(treasury.account_balance, 600, "The hulk's data fee was [treasury.account_balance], not 600") // OUTPOST_EXPERIMENT_FEE_HULK
	block = prison.experiment_payload()
	TEST_ASSERT_EQUAL(block["form"], "hulk", "The console did not name the hulk once it showed")
	TEST_ASSERT_EQUAL(block["stage"], "live", "The console does not show the hulk loose")
	TEST_ASSERT_NULL(block["time_left"], "The console shows a clock on a loose hulk ([block["time_left"]] s)")
	TEST_ASSERT_EQUAL(block["fee_paid"], 600, "The console does not show the fee")
	TEST_ASSERT_EQUAL(hulk.maxHealth, 350, "A hulk facing nobody has [hulk.maxHealth] health, not 350") // OUTPOST_HULK_HEALTH
	TEST_ASSERT(!ismegafauna(hulk), "The hulk counts as megafauna")
	sleep(2)
	TEST_ASSERT(!QDELETED(hulk), "The megafauna ban removed the hulk from the prison wing")
	// Loose in the yard in plain sight of them (outpost_prison_panic.dm)
	TEST_ASSERT(istype(buddy.activity, /datum/prisoner_activity/creature_panic), "A prisoner did not run from the hulk")

	// Put down by the crew: the containment bonus, once.
	var/mob/living/carbon/human/guard = make_player(prison_spot(home, 8, 9), "serumowner")
	hit_with_toolbox(guard, hulk)
	var/datum/component/experiment_damage_ledger/ledger = hulk.GetComponent(/datum/component/experiment_damage_ledger)
	TEST_ASSERT(ledger?.player_damage > 0, "A toolbox blow did not count as the crew's")
	hulk.death()
	TEST_ASSERT_EQUAL(treasury.account_balance, 2500, "The hulk's containment bonus came to [treasury.account_balance - 600], not 1900") // OUTPOST_EXPERIMENT_BONUS_HULK
	TEST_ASSERT_EQUAL(prison.experiment.stage, "contained", "Killing the hulk did not contain it")
	TEST_ASSERT(!prison.experiment_active(), "The experiment went on after the hulk died")
	TEST_ASSERT(!prison.experiment_creature_down(hulk), "The containment bonus could be claimed twice")
	TEST_ASSERT(prison.researcher_wait >= 2100 && prison.researcher_wait <= 3000, "The next visit was not scheduled 35-50 minutes off")

	// Mostly hurt by something other than the crew: no bonus.
	var/mob/living/basic/outpost_prisoner/second_subject = trouble_prisoner(prison, yard)
	TEST_ASSERT(prison.start_experiment("fly", second_subject), "A second experiment could not start after the first ended")
	prison.experiments_tick(60)
	var/mob/living/basic/outpost_experiment/fly/fly = locate() in yard
	TEST_ASSERT_NOTNULL(fly, "The subject did not turn into a fly person")
	var/balance = treasury.account_balance
	fly.apply_damage(50, BRUTE)
	sleep(1)
	fly.death()
	TEST_ASSERT_EQUAL(treasury.account_balance, balance, "A fly killed by no one paid a containment bonus")
	TEST_ASSERT_EQUAL(prison.experiment.bonus_paid, 0, "The console shows a bonus nobody earned")

	// Killed while dosed: no data, no fee and no fine.
	var/mob/living/basic/outpost_prisoner/unlucky = trouble_prisoner(prison, yard)
	balance = treasury.account_balance
	var/fined = prison.fined_total
	TEST_ASSERT(prison.start_experiment("nightmare", unlucky), "A third experiment could not start")
	unlucky.death()
	TEST_ASSERT_EQUAL(prison.experiment.stage, "failed", "A subject dying before the change did not fail the experiment")
	TEST_ASSERT_EQUAL(prison.experiment_payload()["form"], "unknown", "The console named a serum that never showed")
	TEST_ASSERT_EQUAL(treasury.account_balance, balance, "A dead subject paid something")
	TEST_ASSERT_EQUAL(prison.fined_total, fined, "A dead subject cost a fine")

	// A subject taken out of the cell block for a minute: the experiment fails, and they are theirs again.
	var/mob/living/basic/outpost_prisoner/taken = trouble_prisoner(prison, yard)
	TEST_ASSERT(prison.start_experiment("hulk", taken), "A fourth experiment could not start")
	taken.forceMove(prison_spot(home, 9, 3))
	prison.experiments_tick(30)
	TEST_ASSERT(prison.experiment_active(), "The experiment failed before a minute outside")
	prison.experiments_tick(30)
	TEST_ASSERT_EQUAL(prison.experiment.stage, "failed", "A subject a minute outside the cell block did not fail it") // OUTPOST_EXPERIMENT_OUTSIDE_LIMIT
	TEST_ASSERT(!taken.experiment_subject, "The lost subject stayed dosed")
	prison.experiments_tick(60)
	TEST_ASSERT_NULL(prison.experiment_payload(), "The console showed the result for more than a minute") // OUTPOST_EXPERIMENT_RESULT_SHOWN
	settle_prison_air(home)

// ===== KESSLER =====

/datum/unit_test/voidcrew_outpost_prison_experiment_kessler
	parent_type = /datum/unit_test/voidcrew_outpost_management

/// Starts an admin experiment on a new prisoner in the yard and runs it to the creature
/datum/unit_test/voidcrew_outpost_prison_experiment_kessler/proc/creature_for(obj/structure/overmap/dynamic/player_outpost/home, form)
	var/datum/outpost_prison/prison = test_prison(home)
	var/turf/yard = prison_spot(home, 8, 8)
	var/mob/living/basic/outpost_prisoner/host = test_prisoner(prison, yard)
	if(!prison.start_experiment(form, host, forced = TRUE))
		return null
	prison.experiments_tick(60)
	return locate(/mob/living/basic/outpost_experiment) in yard

/// How many containment breaches the warden's log shows
/datum/unit_test/voidcrew_outpost_prison_experiment_kessler/proc/breaches_logged(datum/outpost_prison/prison)
	var/count = 0
	for(var/list/entry as anything in prison.entries)
		if(findtext(entry["text"], "got out of the wing"))
			count++
	return count

/datum/unit_test/voidcrew_outpost_prison_experiment_kessler/Run()
	var/obj/structure/overmap/dynamic/player_outpost/home = experiment_test_claim("kesslerowner")
	TEST_ASSERT_NOTNULL(home, "The Kessler test prison did not load")
	var/datum/outpost_prison/prison = test_prison(home)
	var/datum/bank_account/treasury = trouble_fund(home, 0)

	var/mob/living/basic/outpost_experiment/fly/fly = creature_for(home, "fly")
	TEST_ASSERT(istype(fly), "No fly person")
	TEST_ASSERT_EQUAL(treasury.account_balance, 300, "The fly's data fee was not 300") // OUTPOST_EXPERIMENT_FEE_FLY
	TEST_ASSERT_EQUAL(fly.maxHealth, 60, "The fly person has [fly.maxHealth] health, not 60") // OUTPOST_FLY_HEALTH

	// No clock: left well past the old 12 minutes, crew home or not, it stays and costs nothing.
	prison.crew_home_override = FALSE
	prison.experiments_tick(800)
	TEST_ASSERT(prison.experiment_active(), "Kessler recovered a creature while nobody was home")
	prison.crew_home_override = TRUE
	prison.experiments_tick(800)
	TEST_ASSERT(prison.experiment_active(), "Kessler recovered a creature left alone in the wing") // no OUTPOST_EXPERIMENT_KESSLER_TIME any more
	TEST_ASSERT(!HAS_TRAIT(fly, TRAIT_GODMODE), "Kessler came for a creature nobody took off the outpost")
	TEST_ASSERT_EQUAL(prison.treasury_debt(), 0, "Leaving a creature alone ran up [prison.treasury_debt()] cr of debt")
	TEST_ASSERT_EQUAL(treasury.account_balance, 300, "Leaving a creature alone cost [300 - treasury.account_balance] cr")
	TEST_ASSERT_NULL(prison.experiment_payload()["time_left"], "The console shows a clock on a creature in the wing")
	TEST_ASSERT(prison.experiment_end_admin(), "The fly's experiment could not be called off")
	TEST_ASSERT(wait_until(CALLBACK(GLOBAL_PROC, GLOBAL_PROC_REF(is_qdeleted_ref), WEAKREF(fly)), 12 SECONDS), "Kessler never took the called-off fly away")

	// Walked off the outpost: recovered at once, with the fee, which is debt when the treasury is short.
	var/mob/living/basic/outpost_experiment/hulk/hulk = creature_for(home, "hulk")
	TEST_ASSERT(istype(hulk), "No hulk")
	treasury.adjust_money(-treasury.account_balance, "Test")
	hulk.forceMove(run_loc_floor_bottom_left)
	prison.experiments_tick(1)
	TEST_ASSERT(!prison.experiment_active(), "A creature off the outpost was not recovered at once")
	TEST_ASSERT_EQUAL(prison.experiment.stage, "failed", "A recovered creature counted as contained")
	TEST_ASSERT_EQUAL(prison.treasury_debt(), 1500, "The hulk walking off was [prison.treasury_debt()] cr of debt, not 1500") // OUTPOST_EXPERIMENT_RECOVERY_HULK
	TEST_ASSERT(HAS_TRAIT(hulk, TRAIT_GODMODE), "A creature Kessler is taking could still be hurt")
	TEST_ASSERT(!is_hostile_creature(hulk), "A turret would shoot a creature Kessler is taking")
	TEST_ASSERT(wait_until(CALLBACK(GLOBAL_PROC, GLOBAL_PROC_REF(is_qdeleted_ref), WEAKREF(hulk)), 12 SECONDS), "Kessler never took the hulk away")
	treasury.account_debt = 0
	trouble_fund(home, 3500)

	// Carried off in something: recovered, but no fee.
	var/mob/living/basic/outpost_experiment/nightmare/nightmare = creature_for(home, "nightmare")
	TEST_ASSERT(istype(nightmare), "No nightmare")
	var/obj/structure/closet/crate/crate = allocate(/obj/structure/closet/crate, run_loc_floor_bottom_left)
	nightmare.forceMove(crate)
	var/balance = treasury.account_balance
	prison.experiments_tick(1)
	TEST_ASSERT(!prison.experiment_active(), "A creature carried off the outpost was not recovered")
	TEST_ASSERT_EQUAL(treasury.account_balance, balance, "A creature carried off cost a recovery fee")

	// Walked off while nobody from the wing is home (a visitor led it away): recovered, and no fee.
	var/mob/living/basic/outpost_experiment/hulk/stray = creature_for(home, "hulk")
	TEST_ASSERT(istype(stray), "No stray hulk")
	prison.crew_home_override = FALSE
	stray.forceMove(run_loc_floor_bottom_left)
	balance = treasury.account_balance
	prison.experiments_tick(1)
	TEST_ASSERT(!prison.experiment_active(), "A creature off the outpost was not recovered with nobody home")
	TEST_ASSERT_EQUAL(treasury.account_balance, balance, "A creature that walked off with nobody home cost a recovery fee")
	prison.crew_home_override = TRUE

	// Out of the wing onto the outpost's own floor: the containment breach alarm, once, and still no clock.
	var/mob/living/basic/outpost_experiment/fly/runner = creature_for(home, "fly")
	TEST_ASSERT(istype(runner), "No second fly person")
	runner.forceMove(get_turf(home.management_console))
	TEST_ASSERT(prison.outpost_holds(runner), "The outpost's own floor did not count as the outpost")
	prison.experiments_tick(1)
	TEST_ASSERT(prison.experiment.breach_announced, "Leaving the wing did not sound the containment breach")
	TEST_ASSERT_EQUAL(breaches_logged(prison), 1, "Leaving the wing logged [breaches_logged(prison)] breaches, not 1")
	prison.experiments_tick(400)
	TEST_ASSERT(prison.experiment_active(), "Kessler recovered a creature out of the wing") // no OUTPOST_EXPERIMENT_KESSLER_LOOSE_TIME any more
	TEST_ASSERT_NULL(prison.experiment_payload()["time_left"], "The console shows a clock on a creature out of the wing")
	TEST_ASSERT_EQUAL(breaches_logged(prison), 1, "Staying out of the wing sounded the breach again")
	TEST_ASSERT(prison.experiment_end_admin(), "The runner's experiment could not be called off")

	// Called off by an admin: no fee.
	var/mob/living/basic/outpost_experiment/hulk/last = creature_for(home, "hulk")
	TEST_ASSERT(istype(last), "No second hulk")
	balance = treasury.account_balance
	TEST_ASSERT(prison.experiment_end_admin(), "The admin end found nothing to end")
	TEST_ASSERT_NULL(prison.experiment, "The admin end left the experiment")
	TEST_ASSERT_EQUAL(treasury.account_balance, balance, "Calling the experiment off cost a fee")
	TEST_ASSERT(HAS_TRAIT(last, TRAIT_GODMODE), "The called-off hulk was not being taken away")
	settle_prison_air(home)

// ===== THE SUBJECT STAYS =====

/datum/unit_test/voidcrew_outpost_prison_experiment_holds
	parent_type = /datum/unit_test/voidcrew_outpost_management

/datum/unit_test/voidcrew_outpost_prison_experiment_holds/Run()
	var/obj/structure/overmap/dynamic/player_outpost/home = experiment_test_claim("holdowner", trouble = TRUE)
	TEST_ASSERT_NOTNULL(home, "The hold test prison did not load")
	var/datum/outpost_prison/prison = test_prison(home)
	trouble_fund(home, 0)
	var/turf/yard = prison_spot(home, 8, 8)

	// A dosed subject whose sentence runs out: the sentence holds and they are not released.
	var/mob/living/basic/outpost_prisoner/subject = trouble_prisoner(prison, yard)
	TEST_ASSERT(prison.start_experiment("hulk", subject), "The subject could not be dosed")
	TEST_ASSERT(prison.held_for_experiment(subject), "The experiment does not hold its subject")
	subject.sentence_left = 5
	prison.tick(10)
	TEST_ASSERT_EQUAL(subject.phase, "present", "A dosed subject was released when their sentence ran out") // PRISONER_PRESENT
	TEST_ASSERT_EQUAL(subject.sentence_left, 5, "A dosed subject's sentence ran on to [subject.sentence_left] s")
	subject.sentence_left = 0
	prison.check_release(subject)
	TEST_ASSERT_EQUAL(subject.phase, "present", "A dosed subject was released at the end of their sentence")
	TEST_ASSERT_EQUAL(prison.release(subject), 0, "A dosed subject could be released")
	TEST_ASSERT_EQUAL(subject.phase, "present", "A dosed subject was beamed out by a release")

	// Rioting, they are not transferred out with the other rioters.
	var/mob/living/basic/outpost_prisoner/rioter = trouble_prisoner(prison, prison_spot(home, 12, 8))
	subject.trouble = "riot" // PRISONER_TROUBLE_RIOT
	rioter.trouble = "riot"
	prison.riot_active = TRUE
	prison.transfer_rioters()
	TEST_ASSERT_EQUAL(subject.phase, "present", "A dosed subject was transferred out with the rioters")
	TEST_ASSERT_EQUAL(rioter.phase, "leaving", "A rioter who was not a subject was not transferred") // PRISONER_LEAVING
	subject.trouble = null

	// Loose with their clock run out, they stay put, loose, until the experiment is over.
	subject.trouble = "loose" // PRISONER_TROUBLE_LOOSE
	subject.loose_left = 3
	prison.loose_tick(10)
	TEST_ASSERT_EQUAL(subject.phase, "present", "A loose subject got away for good")
	TEST_ASSERT_EQUAL(subject.trouble, "loose", "A loose subject stopped being loose")
	TEST_ASSERT(subject.loose_left > 0, "A loose subject's clock ran out")
	TEST_ASSERT(prison.experiment_end_admin(), "The subject's experiment could not be called off")
	TEST_ASSERT(!prison.held_for_experiment(subject), "The subject is still held once the experiment is over")
	prison.loose_tick(10)
	TEST_ASSERT_EQUAL(subject.phase, "leaving", "Once the experiment was over, the loose subject did not get away") // PRISONER_LEAVING

	// A specimen host who dies out of the cell block does not burst there, and stays on the roster meanwhile.
	var/mob/living/basic/outpost_prisoner/host = trouble_prisoner(prison, yard)
	TEST_ASSERT(prison.start_experiment("changeling", host), "The host could not take the specimen")
	var/datum/outpost_changeling_event/event = prison.changeling_event()
	TEST_ASSERT_NOTNULL(event, "No changeling event")
	event.stop_self_ticking()
	TEST_ASSERT(prison.held_for_experiment(host), "The experiment does not hold the specimen's host")
	host.forceMove(prison_spot(home, 12, 3))
	host.death()
	prison.tick(130)
	TEST_ASSERT(!QDELETED(host) && host.phase == "present" && (host in prison.prisoners), "The host's body left the roster before the burst")
	TEST_ASSERT(prison.experiment_active(), "The host dying called the specimen off")
	TEST_ASSERT(prison.experiment_end_admin(), "The specimen could not be called off")
	prison.tick(1)
	TEST_ASSERT(!(host in prison.prisoners), "A body out of the cell block that the experiment no longer needs stayed on the roster")
	qdel(host)
	settle_prison_air(home)

// ===== CREATURES =====

/datum/unit_test/voidcrew_outpost_prison_experiment_creatures
	parent_type = /datum/unit_test/voidcrew_outpost_management

/datum/unit_test/voidcrew_outpost_prison_experiment_creatures/Run()
	var/obj/structure/overmap/dynamic/player_outpost/home = experiment_test_claim("creatureowner", trouble = TRUE)
	TEST_ASSERT_NOTNULL(home, "The creature test prison did not load")
	var/datum/outpost_prison/prison = test_prison(home)
	trouble_fund(home, 0)
	var/mob/living/carbon/human/owner = make_player(prison_spot(home, 12, 3), "creatureowner")

	// Every creature: not megafauna, no sentience, no boxing, teleporting, polymorph, air or revival.
	for(var/creature_type in list(/mob/living/basic/outpost_experiment/hulk, /mob/living/basic/outpost_experiment/fly, /mob/living/basic/outpost_experiment/nightmare))
		var/turf/spot = prison_spot(home, 10, 10)
		var/mob/living/basic/outpost_experiment/creature = allocate(creature_type, spot, prison, null)
		TEST_ASSERT(!ismegafauna(creature), "[creature_type] counts as megafauna")
		TEST_ASSERT(!creature.compare_sentience_type(SENTIENCE_ORGANIC) && !creature.compare_sentience_type(SENTIENCE_HUMANOID), "[creature_type] takes a sentience potion")
		TEST_ASSERT(HAS_TRAIT(creature, "no_containment"), "[creature_type] can be boxed") // TRAIT_NO_CONTAINMENT
		TEST_ASSERT(is_outpost_experiment_mob(creature), "[creature_type] is not marked as an experiment's")
		TEST_ASSERT(!creature.unsuitable_atmos_damage && !creature.unsuitable_cold_damage && !creature.unsuitable_heat_damage, "[creature_type] needs air")
		TEST_ASSERT(!do_teleport(creature, prison_spot(home, 12, 10), no_effects = TRUE, channel = TELEPORT_CHANNEL_QUANTUM, forced = TRUE), "A forced teleport moved [creature_type]")
		TEST_ASSERT_EQUAL(creature.loc, spot, "A teleport moved [creature_type]")
		creature.wabbajack()
		TEST_ASSERT(!QDELETED(creature), "A polymorph bolt deleted [creature_type]")
		TEST_ASSERT_NULL(creature.change_mob_type(/mob/living/basic/mouse, delete_old_mob = TRUE), "[creature_type] was turned into another mob")
		TEST_ASSERT(!creature.can_be_revived(), "[creature_type] could be revived")
		TEST_ASSERT(is_hostile_creature(creature), "Turrets would leave [creature_type] alone") // interim turret rule
		sleep(2)
		TEST_ASSERT(!QDELETED(creature), "The megafauna ban removed [creature_type] from the prison wing")
		qdel(creature)

	// Kessler's people: no sentience potions, and they cannot be hurt.
	var/mob/living/basic/outpost_kessler_staff/researcher/doctor = allocate(/mob/living/basic/outpost_kessler_staff/researcher, prison_spot(home, 12, 4), null)
	TEST_ASSERT(!doctor.compare_sentience_type(SENTIENCE_ORGANIC), "The researcher takes a sentience potion")
	TEST_ASSERT(HAS_TRAIT(doctor, "no_containment"), "The researcher can be boxed")
	TEST_ASSERT(!do_teleport(doctor, prison_spot(home, 12, 5), no_effects = TRUE, channel = TELEPORT_CHANNEL_QUANTUM, forced = TRUE), "A forced teleport moved the researcher")
	doctor.apply_damage(30, BRUTE)
	TEST_ASSERT_EQUAL(doctor.health, doctor.maxHealth, "The researcher was hurt")

	// Only the outpost's inside breaks.
	TEST_ASSERT(!outpost_experiment_can_smash(prison_spot(home, 1, 7), prison), "The wing's outer wall counted as breakable")
	TEST_ASSERT(!outpost_experiment_can_smash(prison_spot(home, 1, 10), prison), "A window in the wing's outer wall counted as breakable")
	TEST_ASSERT(outpost_experiment_can_smash(prison_spot(home, 5, 14), prison), "A wall between two cells could not be broken")
	var/mob/living/basic/outpost_experiment/hulk/hulk = allocate(/mob/living/basic/outpost_experiment/hulk, prison_spot(home, 8, 9), prison, null)
	TEST_ASSERT(hulk.can_break(prison_spot(home, 5, 14)), "The hulk could not tear a wall between two cells")
	TEST_ASSERT(!hulk.can_break(prison_spot(home, 1, 7)), "The hulk could tear the wing's outer wall")
	var/list/hatches = prison.hatches()
	TEST_ASSERT(length(hatches), "The wing has no serving hatch")
	TEST_ASSERT(!hulk.can_break(hatches[1]), "The hulk could break a serving hatch's counter")

	// With nobody from the wing home it hunts nobody, but it fights back.
	var/mob/living/carbon/human/visitor = make_player(prison_spot(home, 10, 10), "creaturevisitor")
	prison.crew_home_override = FALSE
	TEST_ASSERT_NULL(hulk.choose_target(), "The hulk went after a visitor with nobody from the wing home")
	var/datum/component/experiment_damage_ledger/hulk_ledger = hulk.GetComponent(/datum/component/experiment_damage_ledger)
	hulk_ledger.note_attacker(visitor)
	TEST_ASSERT_EQUAL(hulk.choose_target(), visitor, "The hulk did not fight back with nobody from the wing home")
	prison.crew_home_override = TRUE
	visitor.key = null // a test key on a deleted mob is a runtime; the fixture only clears keys at the end
	qdel(visitor)

	// The hulk knocks prisoners flat and never kills them.
	var/mob/living/basic/outpost_prisoner/victim = trouble_prisoner(prison, prison_spot(home, 8, 8))
	var/mob/living/basic/outpost_prisoner/onlooker = trouble_prisoner(prison, prison_spot(home, 12, 8))
	TEST_ASSERT(hulk.can_target(victim), "The hulk ignored a prisoner on their feet")
	hulk.melee_attack(victim, ignore_cooldown = TRUE)
	TEST_ASSERT(victim.beaten_left > 0, "The hulk's blow did not knock the prisoner down")
	for(var/i in 1 to 10)
		hulk.knock_down_prisoner(victim)
	TEST_ASSERT(victim.stat != DEAD && victim.health >= 1, "The hulk killed a prisoner")
	TEST_ASSERT(!hulk.can_target(victim), "The hulk went after a prisoner who was already down")

	// Stamina does nothing until it is worn down; then it puts it down alive, for the bigger bonus.
	prison.experiment_creature_appeared(hulk, "hulk")
	TEST_ASSERT_EQUAL(prison.experiment.fee_paid, 600, "The hulk's fee was [prison.experiment.fee_paid]")
	hulk.apply_damage(200, STAMINA)
	TEST_ASSERT(!hulk.subdued, "Stamina put down a hulk that was not worn out")
	hulk.adjustBruteLoss(hulk.maxHealth * 0.8)
	TEST_ASSERT(hulk.exhausted, "A hulk at a fifth of its health was not exhausted") // OUTPOST_HULK_EXHAUSTED_AT
	// The crew's batons: stamina is no damage on the ledger, so the recent blow is what counts.
	hulk_ledger.note_attacker(owner)
	hulk.apply_damage(120, STAMINA)
	TEST_ASSERT(hulk.subdued, "Two baton hits' worth of stamina did not put the exhausted hulk down") // OUTPOST_HULK_STAMINA
	TEST_ASSERT(hulk.stat != DEAD, "Subduing the hulk killed it")
	TEST_ASSERT_EQUAL(hulk.body_position, LYING_DOWN, "The subdued hulk stayed on its feet")
	TEST_ASSERT_EQUAL(prison.experiment_payload()["pickup"], "subdued", "The console does not show the hulk subdued, awaiting pickup")
	TEST_ASSERT_EQUAL(prison.experiment.bonus_paid, 2400, "Subduing the hulk paid [prison.experiment.bonus_paid], not 2400") // OUTPOST_EXPERIMENT_BONUS_HULK_SUBDUED
	TEST_ASSERT(!is_hostile_creature(hulk), "A turret would shoot a subdued hulk")

	// The fly person: a flyswatter hits it thirty times harder, it eats what it finds, and it throws up.
	var/mob/living/basic/outpost_experiment/fly/fly = allocate(/mob/living/basic/outpost_experiment/fly, prison_spot(home, 11, 8), prison, null)
	var/obj/item/melee/flyswatter/swatter = allocate(/obj/item/melee/flyswatter)
	var/before = fly.health
	fly.apply_damage(1, BRUTE, attacking_item = swatter)
	TEST_ASSERT_EQUAL(before - fly.health, 30, "A swat did [before - fly.health] damage, not 30") // OUTPOST_FLY_SWATTER_MULT
	var/obj/item/food/snack = allocate(/obj/item/food/prison_ration, prison_spot(home, 10, 8))
	fly.melee_attack(snack, ignore_cooldown = TRUE)
	TEST_ASSERT(QDELETED(snack), "The fly person left the food alone")
	onlooker.set_mood(70)
	var/turf/splat = fly.throw_up()
	TEST_ASSERT_NOTNULL(locate(/obj/effect/decal/cleanable/vomit) in splat, "The fly person threw up nothing")
	TEST_ASSERT(onlooker.mood < 70, "Watching the fly person throw up bothered nobody")
	qdel(fly)

	// The nightmare puts lights out, burns from a flash, and kills prisoners without staff being blamed.
	var/mob/living/basic/outpost_experiment/nightmare/nightmare = allocate(/mob/living/basic/outpost_experiment/nightmare, prison_spot(home, 8, 9), prison, null)
	var/obj/machinery/light/fixture
	for(var/turf/tile as anything in prison.wing_turfs())
		fixture = locate(/obj/machinery/light) in tile
		if(fixture?.status == 0) // LIGHT_OK
			break
		fixture = null
	TEST_ASSERT_NOTNULL(fixture, "The wing has no working light")
	nightmare.melee_attack(fixture, ignore_cooldown = TRUE)
	TEST_ASSERT_EQUAL(fixture.status, LIGHT_BROKEN, "The nightmare left a light on")
	var/health = nightmare.health
	nightmare.flashed(owner)
	TEST_ASSERT_EQUAL(health - nightmare.health, 20, "A flash burned the nightmare for [health - nightmare.health], not 20") // OUTPOST_NIGHTMARE_FLASH_DAMAGE
	prison.experiment_end_admin()
	prison.experiment_creature_appeared(nightmare, "nightmare")
	var/fined = prison.fined_total
	onlooker.set_mood(70)
	for(var/i in 1 to 10)
		if(victim.stat == DEAD)
			break
		nightmare.melee_attack(victim, ignore_cooldown = TRUE)
	TEST_ASSERT_EQUAL(victim.stat, DEAD, "The nightmare could not kill a prisoner who was down")
	TEST_ASSERT(!victim.death_blamed, "The nightmare's kill was put down to staff")
	TEST_ASSERT_EQUAL(prison.fined_total, fined, "The nightmare's kill fined the treasury")
	TEST_ASSERT_EQUAL(prison.experiment.creature_kills, 1, "The nightmare's kill was not counted")
	TEST_ASSERT(prison.experiment.witnesses[REF(onlooker)], "The prisoner who saw the killing was not a witness")

	// What they saw lands when it is over.
	var/tension = prison.tension_spike
	nightmare.death()
	TEST_ASSERT_EQUAL(nightmare.body_position, LYING_DOWN, "The dead nightmare stayed on its feet")
	TEST_ASSERT_EQUAL(prison.experiment_payload()["pickup"], "down", "The console does not show the dead nightmare awaiting pickup")
	TEST_ASSERT(abs(onlooker.mood - 60) < 0.01, "A witness lost [70 - onlooker.mood] mood, not 10") // OUTPOST_EXPERIMENT_SAW_DEATH_MOOD
	TEST_ASSERT(prison.tension_spike >= tension + 15 - 0.01, "A creature's kill added [prison.tension_spike - tension] tension, not 15") // OUTPOST_EXPERIMENT_KILL_TENSION
	settle_prison_air(home)

// ===== THE FLY PERSON =====

/// The fly person darts about the cell block, keeps away from people, dodges shots while it flies freely, and drops when put down
/datum/unit_test/voidcrew_outpost_prison_experiment_fly
	parent_type = /datum/unit_test/voidcrew_outpost_management

/datum/unit_test/voidcrew_outpost_prison_experiment_fly/Run()
	var/obj/structure/overmap/dynamic/player_outpost/home = experiment_test_claim("flyowner", trouble = TRUE)
	TEST_ASSERT_NOTNULL(home, "The fly test prison did not load")
	var/datum/outpost_prison/prison = test_prison(home)
	trouble_fund(home, 0)
	var/turf/yard = prison_spot(home, 8, 8)
	var/mob/living/basic/outpost_experiment/fly/fly = allocate(/mob/living/basic/outpost_experiment/fly, yard, prison, null)
	prison.experiment_creature_appeared(fly, "fly")
	var/datum/ai_controller/brain = fly.ai_controller
	// Four tiles off: not close enough to chase it off
	var/mob/living/carbon/human/owner = make_player(prison_spot(home, 12, 8), "flyowner")
	TEST_ASSERT(HAS_TRAIT(fly, TRAIT_MOVE_FLYING), "The fly person does not fly")
	TEST_ASSERT(fly.flying_freely(), "A fly person alone in the yard is not flying freely")
	TEST_ASSERT(fly.speed < 1.5, "The fly person moves at [fly.speed], no faster than a running person")
	var/list/looked = fly.examine(owner)
	TEST_ASSERT(findtext(jointext(looked, " "), "It never lands for long."), "The fly person's examine has no tell")
	TEST_ASSERT(!findtext(jointext(looked, " "), "Knock it out"), "The fly person's examine says how to put it down")

	// Its darts: two to five tiles, always in the cell block.
	for(var/i in 1 to 30)
		var/turf/spot = fly.dart_spot()
		TEST_ASSERT_NOTNULL(spot, "The fly person found nowhere to dart in the yard")
		TEST_ASSERT(prison.in_cell_block(spot), "The fly person darted out of the cell block to [spot.x],[spot.y]")
		var/distance = get_dist(fly, spot)
		TEST_ASSERT(distance >= 2 && distance <= 5, "A dart went [distance] tiles, not 2 to 5") // OUTPOST_FLY_DART_MIN/_MAX
	fly.ai_think(brain)
	TEST_ASSERT(brain.current_behaviors[GET_AI_BEHAVIOR(/datum/ai_behavior/outpost_fly_dart)], "The fly person alone did not dart about")
	brain.CancelActions()

	// Someone beside it: it darts away from them, to somewhere farther off.
	owner.forceMove(prison_spot(home, 9, 8))
	TEST_ASSERT_EQUAL(fly.nearest_threat(), owner, "The fly person paid no mind to someone beside it")
	for(var/i in 1 to 20)
		var/turf/away = fly.dart_spot(owner)
		TEST_ASSERT_NOTNULL(away, "The fly person had nowhere to go from someone beside it in the open yard")
		TEST_ASSERT(get_dist(away, owner) > 1, "The fly person darted no farther from the person beside it")
	fly.ai_think(brain)
	TEST_ASSERT(brain.current_behaviors[GET_AI_BEHAVIOR(/datum/ai_behavior/outpost_fly_dart/away)], "The fly person did not dart away from someone beside it")
	brain.CancelActions()

	// Hit, it keeps away from whoever did it even once they are out of reach.
	SEND_SIGNAL(fly, COMSIG_ATOM_WAS_ATTACKED, owner, ATTACKER_DAMAGING_ATTACK)
	owner.forceMove(prison_spot(home, 12, 8))
	TEST_ASSERT_NULL(fly.nearest_threat(), "Someone four tiles off still counts as close") // OUTPOST_FLY_FLEE_RANGE
	TEST_ASSERT_EQUAL(fly.flit_threat(), owner, "The fly person forgot who just hit it")
	fly.ai_think(brain)
	TEST_ASSERT(brain.current_behaviors[GET_AI_BEHAVIOR(/datum/ai_behavior/outpost_fly_dart/away)], "The fly person did not flit away from whoever hit it")
	brain.CancelActions()
	fly.flit_until = 0

	// Shots: it dodges some while it flies freely, and none while knocked down.
	var/obj/projectile/beam/disabler/shot = allocate(/obj/projectile/beam/disabler, prison_spot(home, 12, 8))
	var/dodged = 0
	for(var/i in 1 to 200)
		if(fly.dodge(fly, shot) & PROJECTILE_INTERRUPT_HIT_PHASE)
			dodged++
	TEST_ASSERT(dodged >= 40 && dodged <= 120, "The fly person dodged [dodged] of 200 shots, not about 40%") // OUTPOST_FLY_DODGE
	fly.Knockdown(5 SECONDS)
	TEST_ASSERT_EQUAL(fly.body_position, LYING_DOWN, "A baton's knockdown did not put the fly person on the floor")
	TEST_ASSERT(!HAS_TRAIT(fly, TRAIT_MOVE_FLYING), "The fly person flies while knocked down")
	for(var/i in 1 to 50)
		TEST_ASSERT(!(fly.dodge(fly, shot) & PROJECTILE_INTERRUPT_HIT_PHASE), "The fly person dodged a shot while knocked down")
	fly.SetKnockdown(0)
	fly.get_up(instant = TRUE)
	TEST_ASSERT_EQUAL(fly.body_position, STANDING_UP, "The fly person did not get back up")
	TEST_ASSERT(HAS_TRAIT(fly, TRAIT_MOVE_FLYING), "The fly person did not take off again")

	// Worn out: it drops out of the air and stays down, and the console says so until Kessler takes it.
	var/datum/component/experiment_damage_ledger/ledger = fly.GetComponent(/datum/component/experiment_damage_ledger)
	ledger.note_attacker(owner)
	fly.apply_damage(100, STAMINA) // OUTPOST_FLY_STAMINA
	TEST_ASSERT(fly.subdued, "A full load of stamina damage did not subdue the fly person")
	TEST_ASSERT_EQUAL(fly.body_position, LYING_DOWN, "The subdued fly person stayed in the air")
	TEST_ASSERT(!HAS_TRAIT(fly, TRAIT_MOVE_FLYING), "The subdued fly person is still flying")
	TEST_ASSERT(!fly.flying_freely(), "The subdued fly person could still fly off")
	fly.SetAllImmobility(0)
	fly.setStaminaLoss(0)
	TEST_ASSERT_EQUAL(fly.body_position, LYING_DOWN, "The subdued fly person got up once its stamina came back")
	TEST_ASSERT_EQUAL(prison.experiment.bonus_paid, 700, "Subduing the fly person paid [prison.experiment.bonus_paid], not 700") // OUTPOST_EXPERIMENT_BONUS_FLY
	var/list/block = prison.experiment_payload()
	TEST_ASSERT_EQUAL(block["stage"], "contained", "The subdued fly person did not contain the experiment")
	TEST_ASSERT_EQUAL(block["pickup"], "subdued", "The console does not show the fly person subdued, awaiting pickup")
	looked = fly.examine(owner)
	TEST_ASSERT(findtext(jointext(looked, " "), "will collect"), "The subdued fly person's examine does not say Kessler is coming for it")

	// Kessler's team beams in for it, and the beam takes it; then the console shows it contained.
	prison.kessler_collect(WEAKREF(fly))
	TEST_ASSERT(HAS_TRAIT(fly, TRAIT_GODMODE), "The fly person could be hurt while Kessler collected it")
	TEST_ASSERT_NOTNULL(locate(/mob/living/basic/outpost_kessler_staff/agent) in range(1, fly), "No Kessler agents beamed in for the fly person")
	var/logged = FALSE
	for(var/list/entry as anything in prison.entries)
		if(findtext(entry["text"], "Kessler Biolabs collected"))
			logged = TRUE
	TEST_ASSERT(logged, "The warden's log does not say Kessler collected the fly person")
	TEST_ASSERT(wait_until(CALLBACK(GLOBAL_PROC, GLOBAL_PROC_REF(is_qdeleted_ref), WEAKREF(fly)), 12 SECONDS), "Kessler never took the fly person away")
	TEST_ASSERT_NULL(prison.experiment_payload()["pickup"], "The console still shows the fly person awaiting pickup after Kessler took it")
	settle_prison_air(home)

// ===== THE CHANGELING'S SIDE OF THE API =====

/datum/unit_test/voidcrew_outpost_prison_experiment_api
	parent_type = /datum/unit_test/voidcrew_outpost_management

/datum/unit_test/voidcrew_outpost_prison_experiment_api/Run()
	var/obj/structure/overmap/dynamic/player_outpost/home = experiment_test_claim("apiowner")
	TEST_ASSERT_NOTNULL(home, "The API test prison did not load")
	var/datum/outpost_prison/prison = test_prison(home)
	var/datum/bank_account/treasury = trouble_fund(home, 0)
	var/turf/yard = prison_spot(home, 8, 8)
	var/mob/living/carbon/human/crew = make_player(prison_spot(home, 12, 3), "apiowner")

	// A specimen host: the changeling event runs it.
	var/mob/living/basic/outpost_prisoner/host = test_prisoner(prison, yard)
	TEST_ASSERT(prison.start_experiment("changeling", host, forced = TRUE), "The specimen could not start")
	var/datum/outpost_changeling_event/event = prison.changeling_event()
	TEST_ASSERT_NOTNULL(event, "No changeling event")
	TEST_ASSERT_EQUAL(prison.experiment_payload()["stage"], "incubating", "The console does not show the incubation")

	// Bolted in while it incubates, with no creature about, the lock-in clock counts as it always does:
	// an experiment is no protective custody (owner, 2026-09-25).
	var/mob/living/basic/outpost_prisoner/inmate = test_prisoner(prison, prison_spot(home, 3, 14))
	var/datum/outpost_prison_cell/cell_one = prison.cells[1]
	var/obj/machinery/door/airlock/cell_door = cell_one.door()
	cell_door.bolt()
	prison.refresh_reach()
	if(inmate.is_confined())
		prison.update_locked_in(inmate, 150)
		TEST_ASSERT_EQUAL(inmate.locked_in_seconds, 150, "Bolting a prisoner in during an experiment counted [inmate.locked_in_seconds] s, not 150")
	inmate.locked_in_seconds = 0
	cell_door.unbolt()

	// The burst: the headslug shows and pays the fee, with no Kessler clock of its own.
	var/mob/living/basic/headslug/slug = allocate(/mob/living/basic/headslug/beakless, prison_spot(home, 8, 9))
	event.stage = "burst"
	TEST_ASSERT(prison.experiment_creature_appeared(slug, "changeling"), "The headslug was not tracked")
	TEST_ASSERT_EQUAL(treasury.account_balance, 600, "The burst paid [treasury.account_balance], not 600") // OUTPOST_EXPERIMENT_FEE_CHANGELING
	TEST_ASSERT_EQUAL(prison.experiment_payload()["stage"], "live", "The console does not show the burst")
	TEST_ASSERT(prison.experiment_creature_appeared(slug, "changeling"), "Reporting the headslug twice failed")
	TEST_ASSERT_EQUAL(treasury.account_balance, 600, "Reporting the headslug twice paid twice")

	// The horror: no second fee, and losing the slug to it ends nothing.
	var/mob/living/basic/horror = allocate(/mob/living/basic/mouse, prison_spot(home, 9, 9))
	event.stage = "horror"
	TEST_ASSERT(prison.experiment_creature_appeared(horror, "horror"), "The horror was not tracked")
	TEST_ASSERT_EQUAL(treasury.account_balance, 600, "The horror paid a second fee")
	TEST_ASSERT_EQUAL(prison.experiment_payload()["stage"], "horror", "The console does not show the horror")
	qdel(slug)
	TEST_ASSERT(prison.experiment_active(), "Losing the headslug ended the specimen")

	// The horror put down by the crew: 3,900. Nothing is on its ledger, so the crew's recent blow is what counts.
	var/datum/component/experiment_damage_ledger/horror_ledger = horror.GetComponent(/datum/component/experiment_damage_ledger)
	horror_ledger.note_attacker(crew)
	TEST_ASSERT(prison.experiment_creature_down(horror), "Putting the horror down did not count")
	TEST_ASSERT_EQUAL(treasury.account_balance, 4500, "The horror's bonus came to [treasury.account_balance - 600], not 3900") // OUTPOST_EXPERIMENT_BONUS_HORROR
	TEST_ASSERT_EQUAL(prison.experiment_payload()["stage"], "contained", "The console does not show the horror contained")

	// A headslug caught before it grows, after a blow from the crew: 900.
	var/mob/living/basic/outpost_prisoner/second_host = test_prisoner(prison, yard)
	TEST_ASSERT(prison.start_experiment("changeling", second_host, forced = TRUE), "The second specimen could not start")
	var/mob/living/basic/headslug/early = allocate(/mob/living/basic/headslug/beakless, prison_spot(home, 8, 9))
	prison.experiment_creature_appeared(early, "headslug")
	var/datum/component/experiment_damage_ledger/early_ledger = early.GetComponent(/datum/component/experiment_damage_ledger)
	early_ledger.note_attacker(crew)
	early.death()
	TEST_ASSERT_EQUAL(treasury.account_balance, 6000, "A caught headslug paid [treasury.account_balance - 5100], not 900") // OUTPOST_EXPERIMENT_BONUS_HEADSLUG

	// Dead with nothing on its ledger and no blow from the crew: no bonus.
	var/mob/living/basic/outpost_prisoner/unhit_host = test_prisoner(prison, yard)
	TEST_ASSERT(prison.start_experiment("changeling", unhit_host, forced = TRUE), "The unhit specimen could not start")
	var/mob/living/basic/headslug/unhit = allocate(/mob/living/basic/headslug/beakless, prison_spot(home, 8, 9))
	prison.experiment_creature_appeared(unhit, "headslug")
	var/balance = treasury.account_balance
	unhit.death()
	TEST_ASSERT_EQUAL(treasury.account_balance, balance, "A headslug nobody touched paid a containment bonus")

	// Blown apart after one small hit from the crew: the blast did the rest, so no bonus.
	var/mob/living/basic/outpost_prisoner/bombed_host = test_prisoner(prison, yard)
	TEST_ASSERT(prison.start_experiment("changeling", bombed_host, forced = TRUE), "The bombed specimen could not start")
	var/mob/living/basic/headslug/bombed = allocate(/mob/living/basic/headslug/beakless, prison_spot(home, 8, 9))
	prison.experiment_creature_appeared(bombed, "headslug")
	var/datum/component/experiment_damage_ledger/bombed_ledger = bombed.GetComponent(/datum/component/experiment_damage_ledger)
	bombed_ledger.note_attacker(crew)
	bombed_ledger.add_damage(1, TRUE)
	balance = treasury.account_balance
	bombed.gib()
	TEST_ASSERT_EQUAL(treasury.account_balance, balance, "A headslug blown apart after one small hit paid a containment bonus")
	TEST_ASSERT_EQUAL(prison.experiment.stage, "contained", "The blown apart headslug did not end the specimen")

	// A host killed before the burst does not end the specimen: it bursts from the body.
	var/mob/living/basic/outpost_prisoner/third_host = test_prisoner(prison, yard)
	TEST_ASSERT(prison.start_experiment("changeling", third_host, forced = TRUE), "The third specimen could not start")
	third_host.death()
	prison.experiments_tick(1)
	TEST_ASSERT(prison.experiment_active(), "Killing the host early called the specimen off")

	// The horror recovered by Kessler: 2,500.
	var/mob/living/basic/late_horror = allocate(/mob/living/basic/mouse, prison_spot(home, 9, 9))
	prison.experiment_creature_appeared(late_horror, "horror")
	balance = treasury.account_balance
	prison.experiment_recover()
	TEST_ASSERT_EQUAL(balance - treasury.account_balance, 2500, "Recovering the horror cost [balance - treasury.account_balance], not 2500") // OUTPOST_EXPERIMENT_RECOVERY_HORROR

	// Abandoning the outpost ends everything, with no fee.
	var/obj/item/outpost_experiment/serum/leftover = new(yard, prison, "fly")
	prison.spawn_researcher(TRUE)
	balance = treasury.account_balance
	prison.on_outpost_abandoned()
	TEST_ASSERT_NULL(prison.experiment, "Abandoning the outpost left the experiment")
	TEST_ASSERT_NULL(prison.researcher, "Abandoning the outpost left the researcher waiting")
	TEST_ASSERT(QDELETED(leftover), "Abandoning the outpost left the serum")
	TEST_ASSERT_EQUAL(treasury.account_balance, balance, "Abandoning the outpost cost a fee")
	settle_prison_air(home)

// ===== THE LEDGER AND PRISONERS =====

/// A prisoner's blows on a creature are left out of the crew's share: they neither help nor hurt the bonus
/datum/unit_test/voidcrew_outpost_prison_ledger_prisoners
	parent_type = /datum/unit_test/voidcrew_outpost_management

/datum/unit_test/voidcrew_outpost_prison_ledger_prisoners/Run()
	var/mob/living/basic/cow/creature = allocate(/mob/living/basic/cow, run_loc_floor_bottom_left)
	var/datum/component/experiment_damage_ledger/ledger = creature.AddComponent(/datum/component/experiment_damage_ledger)
	var/mob/living/basic/outpost_prisoner/rioter = allocate(/mob/living/basic/outpost_prisoner, run_loc_floor_bottom_left)
	var/mob/living/carbon/human/crew = make_player(run_loc_floor_bottom_left, "ledgercrew")
	ledger.note_attacker(crew)
	creature.apply_damage(10, BRUTE)
	TEST_ASSERT_EQUAL(ledger.player_damage, 10, "The crew's blow went on the ledger as [ledger.player_damage]")
	ledger.note_attacker(rioter)
	creature.apply_damage(10, BRUTE)
	TEST_ASSERT_EQUAL(ledger.player_damage, 10, "A prisoner's blow counted as the crew's")
	TEST_ASSERT_EQUAL(ledger.other_damage, 0, "A prisoner's blow counted against the crew's share")
	TEST_ASSERT_EQUAL(ledger.player_share(), 1, "The crew's share fell to [ledger.player_share()] after a prisoner's blow")

// ===== REACH =====

/**
 * A prisoner locked in a bolted cell an experiment creature is not in is off-limits, and a target it
 * makes no progress toward for a while is written off so it picks something else: find_light() and
 * choose_target() both skip it. The hulk smashes through, so neither rule slows it down.
 */
/datum/unit_test/voidcrew_outpost_prison_experiment_reach
	parent_type = /datum/unit_test/voidcrew_outpost_management

/datum/unit_test/voidcrew_outpost_prison_experiment_reach/Run()
	var/obj/structure/overmap/dynamic/player_outpost/home = experiment_test_claim("reachowner")
	TEST_ASSERT_NOTNULL(home, "The reach test prison did not load")
	var/datum/outpost_prison/prison = test_prison(home)
	var/turf/yard = prison_spot(home, 8, 8)
	var/mob/living/basic/outpost_experiment/nightmare/nightmare = allocate(/mob/living/basic/outpost_experiment/nightmare, prison_spot(home, 9, 8), prison, null)

	// A prisoner locked in a bolted cell the nightmare is not in is off-limits; the same door unbolted is not.
	var/mob/living/basic/outpost_prisoner/locked = test_prisoner(prison, yard)
	TEST_ASSERT_NOTNULL(locked.cell, "The locked prisoner was not booked into a cell")
	locked.forceMove(locked.cell.arrival_turf())
	var/mob/living/basic/outpost_prisoner/open_prisoner = test_prisoner(prison, yard)
	TEST_ASSERT(nightmare.can_target(locked), "The nightmare ignored a prisoner in an unbolted cell")
	TEST_ASSERT(prison.toggle_cell_bolts(locked.cell.number, null), "The test cell would not bolt")
	TEST_ASSERT(locked.cell.is_bolted(), "The test cell did not report itself bolted")
	TEST_ASSERT(!nightmare.can_target(locked), "The nightmare went after a prisoner locked in a bolted cell")
	TEST_ASSERT(nightmare.can_target(open_prisoner), "A bolted cell elsewhere stopped the nightmare targeting someone in the open")

	// Standing in the cell with them, its own occupant is fair game again.
	var/turf/outside = get_turf(nightmare)
	nightmare.forceMove(locked.cell.arrival_turf())
	TEST_ASSERT(nightmare.can_target(locked), "The nightmare in the cell still could not reach its own occupant")
	nightmare.forceMove(outside)

	// The hulk smashes in regardless of the bolt.
	var/mob/living/basic/outpost_experiment/hulk/hulk = allocate(/mob/living/basic/outpost_experiment/hulk, prison_spot(home, 11, 8), prison, null)
	TEST_ASSERT(hulk.can_target(locked), "A bolted cell kept the hulk out")
	qdel(hulk)

	// A target it makes no progress toward for a while is written off, and another is picked instead.
	var/mob/living/basic/outpost_prisoner/stuck_prisoner = test_prisoner(prison, prison_spot(home, 10, 10))
	var/datum/ai_controller/brain = nightmare.ai_controller
	brain.set_blackboard_key(BB_BASIC_MOB_CURRENT_TARGET, stuck_prisoner)
	nightmare.track_reach(brain)
	TEST_ASSERT(!nightmare.target_unreachable(stuck_prisoner), "A target was written off before it had any chance to be reached")
	nightmare.chase_progress_time -= 5 SECONDS // OUTPOST_EXPERIMENT_STUCK_TIME is 4 seconds
	nightmare.track_reach(brain)
	TEST_ASSERT(nightmare.target_unreachable(stuck_prisoner), "A target that never got any closer was not written off")
	TEST_ASSERT_EQUAL(nightmare.choose_target(), open_prisoner, "choose_target() still offered a target written off as unreachable")

	// On the move, it is chasing: a target that keeps its distance is not written off
	var/turf/was_at = nightmare.loc
	brain.set_blackboard_key(BB_BASIC_MOB_CURRENT_TARGET, open_prisoner)
	nightmare.track_reach(brain)
	nightmare.chase_progress_time -= 5 SECONDS
	nightmare.forceMove(get_step_away(nightmare, open_prisoner) || get_step(nightmare, NORTH))
	nightmare.track_reach(brain)
	TEST_ASSERT(!nightmare.target_unreachable(open_prisoner), "A target it was following was written off")
	nightmare.forceMove(was_at)
	brain.clear_blackboard_key(BB_BASIC_MOB_CURRENT_TARGET)

	// find_light() skips the same list, so lights behind glass do not trap it forever.
	var/obj/machinery/light/near_light = allocate(/obj/machinery/light, prison_spot(home, 10, 8))
	var/obj/machinery/light/far_light = allocate(/obj/machinery/light, prison_spot(home, 12, 8))
	TEST_ASSERT_EQUAL(nightmare.find_light(), near_light, "find_light() did not prefer the nearer light")
	nightmare.mark_unreachable(near_light)
	TEST_ASSERT_EQUAL(nightmare.find_light(), far_light, "find_light() still offered a light written off as unreachable")
	qdel(near_light)
	qdel(far_light)

	// The hulk smashes through, so it never writes a target off as unreachable either.
	var/mob/living/basic/outpost_experiment/hulk/patient_hulk = allocate(/mob/living/basic/outpost_experiment/hulk, prison_spot(home, 11, 8), prison, null)
	var/datum/ai_controller/hulk_brain = patient_hulk.ai_controller
	hulk_brain.set_blackboard_key(BB_BASIC_MOB_CURRENT_TARGET, stuck_prisoner)
	patient_hulk.track_reach(hulk_brain)
	patient_hulk.chase_progress_time -= 5 SECONDS
	patient_hulk.track_reach(hulk_brain)
	TEST_ASSERT(!patient_hulk.target_unreachable(stuck_prisoner), "The hulk wrote a target off as unreachable")
	qdel(patient_hulk)
	settle_prison_air(home)
