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
		var/mob/living/carbon/human/npc/outpost_kessler_staff/researcher/doctor = locate() in tile
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
	var/mob/living/carbon/human/npc/outpost_prisoner/first = test_prisoner(prison, prison_spot(home, 8, 8))
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
	var/mob/living/carbon/human/npc/outpost_kessler_staff/researcher/complainer = office_researcher(prison)
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
	var/mob/living/carbon/human/npc/outpost_kessler_staff/researcher/doctor = prison.researcher
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
		var/mob/living/carbon/human/npc/outpost_kessler_staff/researcher/visiting = prison.spawn_researcher(TRUE)
		TEST_ASSERT_NOTNULL(visiting, "An admin could not send the researcher")
		TEST_ASSERT(prison.decline_offer(owner), "Declining an offer failed")
	TEST_ASSERT(abs(prison.sweetener - 0.3) < 0.001, "Four passed offers raised the next by [prison.sweetener], not 30%") // OUTPOST_EXPERIMENT_SWEETENER_MAX

	// Taking it: the serum in hand, the sweetener spent on it, and no visits while it is out.
	var/mob/living/carbon/human/npc/outpost_kessler_staff/researcher/seller = prison.spawn_researcher(TRUE)
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
	var/mob/living/carbon/human/npc/outpost_prisoner/second = test_prisoner(prison, prison_spot(home, 10, 8))
	for(var/i in 1 to 60)
		prison.roll_offer()
		if(prison.offer_kind == "specimen")
			specimens++
			TEST_ASSERT_EQUAL(prison.offer_form, "changeling", "A specimen was not the changeling")
	TEST_ASSERT(specimens > 0 && specimens < 60, "[specimens] of 60 offers were specimens")
	TEST_ASSERT(first && second, "The prisoners vanished")

	// Hurt for real (OC-3), the researcher says so and leaves, and the next offer is not sweeter for it.
	qdel(serum)
	var/mob/living/carbon/human/npc/outpost_kessler_staff/researcher/target = prison.spawn_researcher(TRUE)
	TEST_ASSERT_NOTNULL(target, "An admin could not send the researcher")
	var/sweet = prison.sweetener
	target.finish_beam_in()
	target.apply_damage(10, BRUTE)
	TEST_ASSERT(target.leaving, "A hurt researcher stayed")
	TEST_ASSERT(target.health < target.maxHealth, "The researcher's body took no damage")
	TEST_ASSERT_NULL(prison.researcher, "A hurt researcher kept the offer open")
	TEST_ASSERT_EQUAL(prison.sweetener, sweet, "Hurting the researcher sweetened the next offer")

	// Deleted without leaving (gibbed, dusted, an admin): the next visit is still scheduled.
	var/mob/living/carbon/human/npc/outpost_kessler_staff/researcher/doomed = prison.spawn_researcher(TRUE)
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
	var/mob/living/carbon/human/npc/outpost_prisoner/subject = test_prisoner(prison, yard)
	var/mob/living/carbon/human/npc/outpost_prisoner/stranger = allocate(/mob/living/carbon/human/npc/outpost_prisoner, prison_spot(home, 10, 8))

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

/// A prisoner of no wing turned into serum `form` for `prison` where they stand, the way the serum turns a
/// subject (outpost_prison_experiment_forms.dm), and tracked as the experiment's creature. Cleaned up with the test.
/datum/unit_test/voidcrew_outpost_management/proc/experiment_form_body(datum/outpost_prison/prison, turf/spot, form, track = FALSE)
	var/mob/living/carbon/human/npc/outpost_prisoner/body = allocate(/mob/living/carbon/human/npc/outpost_prisoner, spot)
	body.stand_down_for_experiment()
	QDEL_NULL(body.ai_controller)
	if(!outpost_experiment_turn(body, form, prison, null))
		return null
	if(track)
		prison.experiment_creature_appeared(body, form)
	return body

/// The form a serum put on `body`
/datum/unit_test/voidcrew_outpost_management/proc/form_of(mob/living/body)
	return body?.GetComponent(/datum/component/outpost_experiment_form)

/// The body on or beside `spot` that the serum turned into `form`
/datum/unit_test/voidcrew_outpost_management/proc/form_body_near(turf/spot, form)
	for(var/mob/living/carbon/human/body in range(1, spot))
		if(outpost_experiment_form_name(body) == form)
			return body
	return null

/datum/unit_test/voidcrew_outpost_prison_experiment_serum
	parent_type = /datum/unit_test/voidcrew_outpost_management

/datum/unit_test/voidcrew_outpost_prison_experiment_serum/Run()
	var/obj/structure/overmap/dynamic/player_outpost/home = experiment_test_claim("serumowner", trouble = TRUE)
	TEST_ASSERT_NOTNULL(home, "The serum test prison did not load")
	var/datum/outpost_prison/prison = test_prison(home)
	var/datum/bank_account/treasury = trouble_fund(home, 0)
	var/turf/yard = prison_spot(home, 8, 8)
	var/mob/living/carbon/human/npc/outpost_prisoner/subject = trouble_prisoner(prison, yard)
	var/mob/living/carbon/human/npc/outpost_prisoner/buddy = trouble_prisoner(prison, prison_spot(home, 12, 8))
	var/subject_name = subject.real_name
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

	// The change: the subject's own body takes tg's hulk gene and gigantism where they stood, leaves the
	// roster but not the world, and the fee is paid. No clock: it stays until it is put down.
	prison.experiments_tick(35)
	var/mob/living/carbon/human/hulk = form_body_near(yard, "hulk")
	TEST_ASSERT_NOTNULL(hulk, "The subject did not turn into a hulk")
	allocated += hulk
	TEST_ASSERT_EQUAL(hulk, subject, "The serum turned some other body than the subject's own")
	TEST_ASSERT(!(subject in prison.prisoners), "The hulk is still on the prison's roster")
	TEST_ASSERT(!is_outpost_prisoner(subject), "The hulk still counts as an inmate")
	TEST_ASSERT_EQUAL(hulk.real_name, subject_name, "The hulk is not the subject")
	TEST_ASSERT(HAS_TRAIT(hulk, TRAIT_HULK), "The hulk has no hulk gene")
	TEST_ASSERT(HAS_TRAIT(hulk, TRAIT_GIANT), "The hulk did not grow")
	TEST_ASSERT_EQUAL(hulk.maxHealth, 100, "The hulk has [hulk.maxHealth] health, not a person's")
	TEST_ASSERT(abs(hulk.physiology.brute_mod - 0.6) < 0.01, "The hulk takes [hulk.physiology.brute_mod] of a person's brute, not 0.6") // OUTPOST_HULK_DAMAGE_TAKEN
	TEST_ASSERT_EQUAL(treasury.account_balance, 600, "The hulk's data fee was [treasury.account_balance], not 600") // OUTPOST_EXPERIMENT_FEE_HULK
	block = prison.experiment_payload()
	TEST_ASSERT_EQUAL(block["form"], "hulk", "The console did not name the hulk once it showed")
	TEST_ASSERT_EQUAL(block["stage"], "live", "The console does not show the hulk loose")
	TEST_ASSERT_NULL(block["time_left"], "The console shows a clock on a loose hulk ([block["time_left"]] s)")
	TEST_ASSERT_EQUAL(block["fee_paid"], 600, "The console does not show the fee")
	sleep(2)
	TEST_ASSERT(!QDELETED(hulk), "The megafauna ban removed the hulk from the prison wing")
	// Loose in the yard in plain sight of them (outpost_prison_panic.dm)
	TEST_ASSERT(istype(buddy.activity, /datum/prisoner_activity/creature_panic), "A prisoner did not run from the hulk")

	// Killed by the crew: the containment bonus at once, once, and it lies there for Kessler.
	var/mob/living/carbon/human/guard = make_player(prison_spot(home, 8, 9), "serumowner")
	hit_with_toolbox(guard, hulk)
	var/datum/component/experiment_damage_ledger/ledger = hulk.GetComponent(/datum/component/experiment_damage_ledger)
	TEST_ASSERT(ledger?.player_damage > 0, "A toolbox blow did not count as the crew's")
	hulk.death()
	TEST_ASSERT_EQUAL(treasury.account_balance, 2500, "The hulk's containment bonus came to [treasury.account_balance - 600], not 1900") // OUTPOST_EXPERIMENT_BONUS_HULK
	TEST_ASSERT_EQUAL(prison.experiment.stage, "contained", "Killing the hulk did not contain it")
	TEST_ASSERT_EQUAL(prison.experiment_payload()["pickup"], "down", "The console does not show the dead hulk awaiting pickup")
	TEST_ASSERT(!prison.experiment_active(), "The experiment went on after the hulk died")
	TEST_ASSERT(!prison.experiment_creature_down(hulk), "The containment bonus could be claimed twice")
	TEST_ASSERT(prison.researcher_wait >= 2100 && prison.researcher_wait <= 3000, "The next visit was not scheduled 35-50 minutes off")
	prison.kessler_finish_collect(WEAKREF(hulk))
	TEST_ASSERT_EQUAL(treasury.account_balance, 2500, "Kessler taking the hulk paid the bonus again")
	TEST_ASSERT(HAS_TRAIT_FROM(hulk, TRAIT_IMMOBILIZED, "outpost_kessler"), "Kessler's beam did not take the dead hulk") // OUTPOST_KESSLER_TRAIT
	TEST_ASSERT(!HAS_TRAIT(hulk, TRAIT_GODMODE), "Kessler's beam made the hulk invulnerable")

	// Mostly hurt by something other than the crew: no bonus.
	var/mob/living/carbon/human/npc/outpost_prisoner/second_subject = trouble_prisoner(prison, yard)
	TEST_ASSERT(prison.start_experiment("fly", second_subject), "A second experiment could not start after the first ended")
	prison.experiments_tick(60)
	var/mob/living/carbon/human/fly = form_body_near(yard, "fly")
	TEST_ASSERT_NOTNULL(fly, "The subject did not turn into a fly person")
	allocated += fly
	var/balance = treasury.account_balance
	fly.apply_damage(50, BRUTE)
	sleep(1)
	fly.death()
	TEST_ASSERT_EQUAL(treasury.account_balance, balance, "A fly killed by no one paid a containment bonus")
	TEST_ASSERT_EQUAL(prison.experiment.bonus_paid, 0, "The console shows a bonus nobody earned")

	// Killed while dosed: no data, no fee and no fine.
	var/mob/living/carbon/human/npc/outpost_prisoner/unlucky = trouble_prisoner(prison, yard)
	balance = treasury.account_balance
	var/fined = prison.fined_total
	TEST_ASSERT(prison.start_experiment("nightmare", unlucky), "A third experiment could not start")
	unlucky.death()
	TEST_ASSERT_EQUAL(prison.experiment.stage, "failed", "A subject dying before the change did not fail the experiment")
	TEST_ASSERT_EQUAL(prison.experiment_payload()["form"], "unknown", "The console named a serum that never showed")
	TEST_ASSERT_EQUAL(treasury.account_balance, balance, "A dead subject paid something")
	TEST_ASSERT_EQUAL(prison.fined_total, fined, "A dead subject cost a fine")

	// A subject taken out of the cell block for a minute: the experiment fails, and they are theirs again.
	var/mob/living/carbon/human/npc/outpost_prisoner/taken = trouble_prisoner(prison, yard)
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
	var/mob/living/carbon/human/npc/outpost_prisoner/host = test_prisoner(prison, yard)
	if(!prison.start_experiment(form, host, forced = TRUE))
		return null
	prison.experiments_tick(60)
	var/mob/living/carbon/human/body = form_body_near(yard, form)
	if(body)
		allocated += body
	return body

/// How many containment breaches the warden's log shows
/datum/unit_test/voidcrew_outpost_prison_experiment_kessler/proc/breaches_logged(datum/outpost_prison/prison)
	var/count = 0
	for(var/list/entry as anything in prison.entries)
		if(findtext(entry["text"], "got out of the wing"))
			count++
	return count

/// Whether Kessler's beam has `creature`: held still for it (OUTPOST_KESSLER_TRAIT), and never invulnerable
/datum/unit_test/voidcrew_outpost_prison_experiment_kessler/proc/being_taken(mob/living/creature)
	return HAS_TRAIT_FROM(creature, TRAIT_IMMOBILIZED, "outpost_kessler") && !HAS_TRAIT(creature, TRAIT_GODMODE)

/datum/unit_test/voidcrew_outpost_prison_experiment_kessler/Run()
	var/obj/structure/overmap/dynamic/player_outpost/home = experiment_test_claim("kesslerowner")
	TEST_ASSERT_NOTNULL(home, "The Kessler test prison did not load")
	var/datum/outpost_prison/prison = test_prison(home)
	var/datum/bank_account/treasury = trouble_fund(home, 0)

	var/mob/living/carbon/human/fly = creature_for(home, "fly")
	TEST_ASSERT_NOTNULL(fly, "No fly person")
	TEST_ASSERT_EQUAL(treasury.account_balance, 300, "The fly's data fee was not 300") // OUTPOST_EXPERIMENT_FEE_FLY

	// No clock: left well past the old 12 minutes, crew home or not, it stays and costs nothing.
	prison.crew_home_override = FALSE
	prison.experiments_tick(800)
	TEST_ASSERT(prison.experiment_active(), "Kessler recovered a creature while nobody was home")
	prison.crew_home_override = TRUE
	prison.experiments_tick(800)
	TEST_ASSERT(prison.experiment_active(), "Kessler recovered a creature left alone in the wing") // no OUTPOST_EXPERIMENT_KESSLER_TIME any more
	TEST_ASSERT(!being_taken(fly), "Kessler came for a creature nobody took off the outpost")
	TEST_ASSERT_EQUAL(prison.treasury_debt(), 0, "Leaving a creature alone ran up [prison.treasury_debt()] cr of debt")
	TEST_ASSERT_EQUAL(treasury.account_balance, 300, "Leaving a creature alone cost [300 - treasury.account_balance] cr")
	TEST_ASSERT_NULL(prison.experiment_payload()["time_left"], "The console shows a clock on a creature in the wing")
	TEST_ASSERT(prison.experiment_end_admin(), "The fly's experiment could not be called off")
	TEST_ASSERT(wait_until(CALLBACK(GLOBAL_PROC, GLOBAL_PROC_REF(is_qdeleted_ref), WEAKREF(fly)), 12 SECONDS), "Kessler never took the called-off fly away")

	// Walked off the outpost: recovered at once, with the fee, which is debt when the treasury is short.
	var/mob/living/carbon/human/hulk = creature_for(home, "hulk")
	TEST_ASSERT_NOTNULL(hulk, "No hulk")
	treasury.adjust_money(-treasury.account_balance, "Test")
	hulk.forceMove(run_loc_floor_bottom_left)
	prison.experiments_tick(1)
	TEST_ASSERT(!prison.experiment_active(), "A creature off the outpost was not recovered at once")
	TEST_ASSERT_EQUAL(prison.experiment.stage, "failed", "A recovered creature counted as contained")
	TEST_ASSERT_EQUAL(prison.treasury_debt(), 1500, "The hulk walking off was [prison.treasury_debt()] cr of debt, not 1500") // OUTPOST_EXPERIMENT_RECOVERY_HULK
	TEST_ASSERT(being_taken(hulk), "Kessler's beam did not hold the hulk still, or made it invulnerable")
	TEST_ASSERT(!is_hostile_creature(hulk), "A turret would shoot a creature Kessler is taking")
	TEST_ASSERT(wait_until(CALLBACK(GLOBAL_PROC, GLOBAL_PROC_REF(is_qdeleted_ref), WEAKREF(hulk)), 12 SECONDS), "Kessler never took the hulk away")
	treasury.account_debt = 0
	trouble_fund(home, 3500)

	// Carried off in something: recovered, but no fee.
	var/mob/living/carbon/human/nightmare = creature_for(home, "nightmare")
	TEST_ASSERT_NOTNULL(nightmare, "No nightmare")
	var/obj/structure/closet/crate/crate = allocate(/obj/structure/closet/crate, run_loc_floor_bottom_left)
	nightmare.forceMove(crate)
	var/balance = treasury.account_balance
	prison.experiments_tick(1)
	TEST_ASSERT(!prison.experiment_active(), "A creature carried off the outpost was not recovered")
	TEST_ASSERT_EQUAL(treasury.account_balance, balance, "A creature carried off cost a recovery fee")

	// Walked off while nobody from the wing is home (a visitor led it away): recovered, and no fee.
	var/mob/living/carbon/human/stray = creature_for(home, "hulk")
	TEST_ASSERT_NOTNULL(stray, "No stray hulk")
	prison.crew_home_override = FALSE
	stray.forceMove(run_loc_floor_bottom_left)
	balance = treasury.account_balance
	prison.experiments_tick(1)
	TEST_ASSERT(!prison.experiment_active(), "A creature off the outpost was not recovered with nobody home")
	TEST_ASSERT_EQUAL(treasury.account_balance, balance, "A creature that walked off with nobody home cost a recovery fee")
	prison.crew_home_override = TRUE

	// Out of the wing onto the outpost's own floor: the containment breach alarm, once, and still no clock.
	var/mob/living/carbon/human/runner = creature_for(home, "fly")
	TEST_ASSERT_NOTNULL(runner, "No second fly person")
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

	// Taken alive: beaten into crit and cuffed, it is subdued. Kessler pays the bigger bonus only once its beam
	// has the hulk, and its team darts it with real chloral hydrate first (owner ruling OC-3).
	var/mob/living/carbon/human/brute = creature_for(home, "hulk")
	TEST_ASSERT_NOTNULL(brute, "No third hulk")
	var/mob/living/carbon/human/crew = make_player(prison_spot(home, 12, 3), "kesslerowner")
	var/datum/component/experiment_damage_ledger/ledger = brute.GetComponent(/datum/component/experiment_damage_ledger)
	ledger.note_attacker(crew)
	ledger.add_damage(100, TRUE)
	brute.apply_damage(200, BRUTE, BODY_ZONE_CHEST, wound_bonus = CANT_WOUND)
	TEST_ASSERT(brute.stat >= SOFT_CRIT && brute.stat != DEAD, "Two hundred brute did not put the hulk into crit (stat [brute.stat])")
	// tg's hulk gene lets go below crit on its next tick of life; nobody is on the level, so the test ticks it.
	var/datum/mutation/hulk/gene = brute.dna.get_mutation(/datum/mutation/hulk)
	gene?.on_life(SSMOBS_DT, 0)
	TEST_ASSERT(!HAS_TRAIT(brute, TRAIT_HULK), "The hulk kept its gene in crit")
	var/obj/item/restraints/handcuffs/cuffs = allocate(/obj/item/restraints/handcuffs)
	TEST_ASSERT(brute.equip_to_slot_if_possible(cuffs, ITEM_SLOT_HANDCUFFED) && HAS_TRAIT(brute, TRAIT_RESTRAINED), "The hulk in crit could not be cuffed")
	balance = treasury.account_balance
	prison.experiments_tick(1)
	TEST_ASSERT(prison.experiment_awaiting_pickup(brute), "The hulk down in crit and cuffed is not awaiting pickup")
	TEST_ASSERT_EQUAL(prison.experiment_payload()["pickup"], "subdued", "The console does not show the hulk subdued")
	TEST_ASSERT_EQUAL(treasury.account_balance, balance, "Kessler paid for the hulk before it had it")
	prison.kessler_collect(WEAKREF(brute))
	var/darted = FALSE
	for(var/i in 1 to 10)
		if(brute.reagents.has_reagent(/datum/reagent/toxin/chloralhydrate))
			darted = TRUE
			break
		sleep(1)
	TEST_ASSERT(darted, "Kessler's team never darted the hulk with chloral hydrate")
	prison.kessler_finish_collect(WEAKREF(brute))
	TEST_ASSERT_EQUAL(treasury.account_balance - balance, 2400, "Taking the hulk alive and cuffed paid [treasury.account_balance - balance], not 2400") // OUTPOST_EXPERIMENT_BONUS_HULK_SUBDUED
	TEST_ASSERT(being_taken(brute), "Kessler's beam did not take the subdued hulk")
	TEST_ASSERT_EQUAL(prison.experiment.stage, "contained", "Taking the subdued hulk did not contain it")
	var/turf/brute_spot = get_turf(brute)
	TEST_ASSERT(wait_until(CALLBACK(GLOBAL_PROC, GLOBAL_PROC_REF(is_qdeleted_ref), WEAKREF(brute)), 12 SECONDS), "Kessler never took the subdued hulk away")
	TEST_ASSERT(cuffs.loc == brute_spot, "The crew's cuffs went with the hulk")

	// Down, then back on its feet before Kessler comes: loose again, and nothing paid.
	var/mob/living/carbon/human/sleeper = creature_for(home, "fly")
	TEST_ASSERT_NOTNULL(sleeper, "No third fly person")
	sleeper.Sleeping(5 SECONDS)
	prison.experiments_tick(1)
	TEST_ASSERT(prison.experiment_awaiting_pickup(sleeper), "A sleeping fly person is not awaiting pickup")
	sleeper.SetSleeping(0)
	balance = treasury.account_balance
	prison.kessler_collect(WEAKREF(sleeper))
	TEST_ASSERT(!prison.experiment_awaiting_pickup(sleeper), "A fly person back on its feet still awaits pickup")
	TEST_ASSERT(sleeper in prison.experiment.live_creatures(), "A fly person back on its feet is not loose again")
	TEST_ASSERT(!being_taken(sleeper), "Kessler took a fly person that was up and about")
	TEST_ASSERT_EQUAL(treasury.account_balance, balance, "A creature that got back up paid a bonus")
	TEST_ASSERT(prison.experiment_end_admin(), "The sleeper's experiment could not be called off")

	// Called off by an admin: no fee.
	var/mob/living/carbon/human/last = creature_for(home, "hulk")
	TEST_ASSERT_NOTNULL(last, "No last hulk")
	balance = treasury.account_balance
	TEST_ASSERT(prison.experiment_end_admin(), "The admin end found nothing to end")
	TEST_ASSERT_NULL(prison.experiment, "The admin end left the experiment")
	TEST_ASSERT_EQUAL(treasury.account_balance, balance, "Calling the experiment off cost a fee")
	TEST_ASSERT(being_taken(last), "The called-off hulk was not being taken away")
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
	var/mob/living/carbon/human/npc/outpost_prisoner/subject = trouble_prisoner(prison, yard)
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
	var/mob/living/carbon/human/npc/outpost_prisoner/rioter = trouble_prisoner(prison, prison_spot(home, 12, 8))
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
	var/mob/living/carbon/human/npc/outpost_prisoner/host = trouble_prisoner(prison, yard)
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

	// Every form: a person's body changed by tg's biology, on its side, out of boxes, teleports and
	// polymorphs, and revivable like anyone (EX-2).
	for(var/form in list("hulk", "fly", "nightmare"))
		var/turf/spot = prison_spot(home, 10, 10)
		var/mob/living/carbon/human/body = experiment_form_body(prison, spot, form)
		TEST_ASSERT_NOTNULL(body, "The [form] serum did not take on a body")
		TEST_ASSERT_EQUAL(outpost_experiment_form_name(body), form, "The [form] body does not read as a [form]")
		TEST_ASSERT(is_outpost_experiment_creature(body), "The [form] body is not an experiment's creature")
		TEST_ASSERT(HAS_TRAIT(body, "no_containment"), "The [form] body can be boxed") // TRAIT_NO_CONTAINMENT
		TEST_ASSERT(is_outpost_experiment_mob(body), "The [form] body is not marked as an experiment's")
		TEST_ASSERT(("outpost_experiment" in body.faction) && length(body.faction) == 1, "The [form] body is on [english_list(body.faction)]'s side") // FACTION_OUTPOST_EXPERIMENT
		TEST_ASSERT(istype(body.ai_controller, /datum/ai_controller/basic_controller/human_npc/outpost_experiment), "The [form] body does not think as a creature")
		TEST_ASSERT(!do_teleport(body, prison_spot(home, 12, 10), no_effects = TRUE, channel = TELEPORT_CHANNEL_QUANTUM, forced = TRUE), "A forced teleport moved the [form] body")
		TEST_ASSERT_EQUAL(body.loc, spot, "A teleport moved the [form] body")
		body.wabbajack()
		TEST_ASSERT(!QDELETED(body), "A polymorph bolt deleted the [form] body")
		TEST_ASSERT_NULL(body.change_mob_type(/mob/living/basic/mouse, delete_old_mob = TRUE), "The [form] body was turned into another mob")
		TEST_ASSERT(body.can_be_revived(), "The [form] body could not be revived")
		TEST_ASSERT(is_hostile_creature(body), "Turrets would leave the [form] body alone")
		switch(form)
			if("hulk")
				TEST_ASSERT(HAS_TRAIT(body, TRAIT_HULK) && HAS_TRAIT(body, TRAIT_STUNIMMUNE), "The hulk has no hulk gene")
				TEST_ASSERT(HAS_TRAIT(body, TRAIT_GIANT), "The hulk has no gigantism")
			if("fly")
				TEST_ASSERT(isflyperson(body), "The fly person is not tg's fly species")
				TEST_ASSERT_NOTNULL(locate(/obj/item/organ/cyberimp/cyberware/slipwire) in body.organs, "The fly person has no Slipwire to sidestep with")
			if("nightmare")
				TEST_ASSERT(isnightmare(body), "The nightmare is not tg's nightmare species")
				TEST_ASSERT_NOTNULL(locate(/obj/item/light_eater) in body.held_items, "The nightmare has no light eater")
		qdel(body)

	// Kessler's people: real bodies (OC-3) that keep out of lockers and teleporters while alive, and leave when hurt.
	var/mob/living/carbon/human/npc/outpost_kessler_staff/researcher/doctor = allocate(/mob/living/carbon/human/npc/outpost_kessler_staff/researcher, prison_spot(home, 12, 4), null)
	TEST_ASSERT(!doctor.compare_sentience_type(SENTIENCE_ORGANIC), "The researcher takes a sentience potion")
	TEST_ASSERT(HAS_TRAIT(doctor, "no_containment"), "The researcher can be boxed")
	TEST_ASSERT(!do_teleport(doctor, prison_spot(home, 12, 5), no_effects = TRUE, channel = TELEPORT_CHANNEL_QUANTUM, forced = TRUE), "A forced teleport moved the researcher")
	TEST_ASSERT(ishuman(doctor), "The researcher is not a real body")
	doctor.apply_damage(30, BRUTE)
	TEST_ASSERT(doctor.health < doctor.maxHealth, "The researcher could not be hurt")
	TEST_ASSERT(doctor.leaving, "A hurt researcher stayed")
	// An agent's tranquilliser gun holds a real chloral hydrate dart.
	var/mob/living/carbon/human/npc/outpost_kessler_staff/agent/agent = allocate(/mob/living/carbon/human/npc/outpost_kessler_staff/agent, prison_spot(home, 13, 4), null)
	var/obj/item/gun/syringe/dart_gun = locate() in agent.held_items
	TEST_ASSERT_NOTNULL(dart_gun, "A Kessler agent holds no tranquilliser gun")
	var/obj/item/reagent_containers/syringe/dart = length(dart_gun.syringes) ? dart_gun.syringes[1] : null
	TEST_ASSERT(dart?.reagents?.has_reagent(/datum/reagent/toxin/chloralhydrate), "A Kessler agent's dart holds no chloral hydrate")

	// The species can rename a body (tg's nightmares take a nightmare's name); the subject keeps theirs.
	var/mob/living/carbon/human/npc/outpost_prisoner/named = allocate(/mob/living/carbon/human/npc/outpost_prisoner, prison_spot(home, 10, 10))
	named.stand_down_for_experiment()
	var/name_before = named.real_name
	TEST_ASSERT_NOTNULL(outpost_experiment_turn(named, "nightmare", prison, null), "The nightmare serum did not take")
	TEST_ASSERT_EQUAL(named.real_name, name_before, "The nightmare took a new name")
	qdel(named)

	// Only the outpost's inside breaks.
	TEST_ASSERT(!outpost_experiment_can_smash(prison_spot(home, 1, 7), prison), "The wing's outer wall counted as breakable")
	TEST_ASSERT(!outpost_experiment_can_smash(prison_spot(home, 1, 10), prison), "A window in the wing's outer wall counted as breakable")
	TEST_ASSERT(outpost_experiment_can_smash(prison_spot(home, 5, 14), prison), "A wall between two cells could not be broken")
	var/mob/living/carbon/human/hulk = experiment_form_body(prison, prison_spot(home, 8, 9), "hulk")
	var/datum/component/outpost_experiment_form/hulk/hulk_form = form_of(hulk)
	TEST_ASSERT(hulk_form.can_break(prison_spot(home, 5, 14)), "The hulk could not tear a wall between two cells")
	TEST_ASSERT(!hulk_form.can_break(prison_spot(home, 1, 7)), "The hulk could tear the wing's outer wall")
	var/list/hatches = prison.hatches()
	TEST_ASSERT(length(hatches), "The wing has no serving hatch")
	TEST_ASSERT(!hulk_form.can_break(hatches[1]), "The hulk could break a serving hatch's counter")

	// With nobody from the wing home it hunts nobody, but it fights back.
	var/mob/living/carbon/human/visitor = make_player(prison_spot(home, 10, 10), "creaturevisitor")
	prison.crew_home_override = FALSE
	prison.experiment_creature_appeared(hulk, "hulk")
	TEST_ASSERT_NULL(hulk_form.choose_target(), "The hulk went after a visitor with nobody from the wing home")
	var/datum/component/experiment_damage_ledger/hulk_ledger = hulk.GetComponent(/datum/component/experiment_damage_ledger)
	hulk_ledger.note_attacker(visitor)
	TEST_ASSERT_EQUAL(hulk_form.choose_target(), visitor, "The hulk did not fight back with nobody from the wing home")
	prison.crew_home_override = TRUE
	visitor.key = null // a test key on a deleted mob is a runtime; the fixture only clears keys at the end
	qdel(visitor)

	// Its charge and its punches land through armour, at a body zone, and can wound (EX-7).
	var/mob/living/carbon/human/armoured = allocate(/mob/living/carbon/human/consistent, prison_spot(home, 9, 9))
	armoured.equip_to_slot_or_del(new /obj/item/clothing/suit/armor/vest(armoured), ITEM_SLOT_OCLOTHING)
	var/dealt = outpost_experiment_ability_hit(armoured, 20, zone = BODY_ZONE_CHEST, attacker = hulk)
	TEST_ASSERT(dealt > 0 && dealt < 20, "An ability hit on an armour vest dealt [dealt] of 20")
	var/obj/item/bodypart/chest = armoured.get_bodypart(BODY_ZONE_CHEST)
	TEST_ASSERT(chest.brute_dam > 0, "An ability hit on the chest left the chest unhurt")
	qdel(armoured)

	// A real hulk punch knocks a standing prisoner flat, and it leaves them be once they are down.
	var/mob/living/carbon/human/npc/outpost_prisoner/victim = trouble_prisoner(prison, prison_spot(home, 8, 8))
	var/mob/living/carbon/human/npc/outpost_prisoner/onlooker = trouble_prisoner(prison, prison_spot(home, 12, 8))
	TEST_ASSERT(hulk_form.can_target(victim), "The hulk ignored a prisoner on their feet")
	var/health_before = victim.health
	hulk.set_combat_mode(TRUE)
	hulk.UnarmedAttack(victim, TRUE)
	sleep(2)
	TEST_ASSERT(victim.health < health_before, "The hulk's punch did not hurt the prisoner")
	TEST_ASSERT_EQUAL(victim.body_position, LYING_DOWN, "The hulk's punch did not knock the prisoner flat")
	TEST_ASSERT(!hulk_form.can_target(victim), "The hulk went after a prisoner who was already down")

	// Beaten into crit, tg's hulk gene lets go: an ordinary person again, whom batons and cuffs work on.
	hulk.apply_damage(200, BRUTE, BODY_ZONE_CHEST, wound_bonus = CANT_WOUND)
	var/datum/mutation/hulk/gene = hulk.dna.get_mutation(/datum/mutation/hulk)
	gene?.on_life(SSMOBS_DT, 0)
	TEST_ASSERT(!HAS_TRAIT(hulk, TRAIT_HULK), "The hulk kept its gene in crit")
	TEST_ASSERT(!HAS_TRAIT(hulk, TRAIT_STUNIMMUNE), "The hulk shrugs off stuns in crit")
	TEST_ASSERT(!hulk_form.smashes_through(), "The hulk without its gene still smashes through walls")
	TEST_ASSERT_EQUAL(outpost_experiment_down_state(hulk), "down", "The hulk in crit is not down for Kessler") // OUTPOST_EXPERIMENT_DOWN_DOWN
	prison.experiment_end_admin()

	// The fly person: a flyswatter is thirty times worse for it (tg's fly species), and it eats real food.
	var/mob/living/carbon/human/fly = experiment_form_body(prison, prison_spot(home, 11, 8), "fly")
	var/datum/component/outpost_experiment_form/fly/fly_form = form_of(fly)
	var/obj/item/melee/flyswatter/swatter = allocate(/obj/item/melee/flyswatter)
	var/before = fly.health
	fly.apply_damage(1, BRUTE, BODY_ZONE_CHEST, attacking_item = swatter)
	TEST_ASSERT(before - fly.health >= 29, "A swat did [before - fly.health] damage, not 30")
	var/obj/item/food/snack = allocate(/obj/item/food/prison_ration, prison_spot(home, 10, 8))
	TEST_ASSERT_EQUAL(fly_form.find_meal(), snack, "The fly person did not spot the food beside it")
	TEST_ASSERT(fly_form.can_target(snack), "The fly person would not go for food on the floor")
	onlooker.set_mood(70)
	fly.vomit(MOB_VOMIT_MESSAGE | MOB_VOMIT_FORCE, lost_nutrition = 0)
	TEST_ASSERT(onlooker.mood < 70, "Watching the fly person throw up bothered nobody")
	qdel(fly)

	// The nightmare: its light eater breaks lights, and it kills prisoners without staff being blamed.
	var/mob/living/carbon/human/nightmare = experiment_form_body(prison, prison_spot(home, 8, 9), "nightmare")
	var/datum/component/outpost_experiment_form/nightmare/nightmare_form = form_of(nightmare)
	var/obj/machinery/light/fixture
	for(var/turf/tile as anything in prison.wing_turfs())
		fixture = locate(/obj/machinery/light) in tile
		if(fixture?.status == 0) // LIGHT_OK
			break
		fixture = null
	TEST_ASSERT_NOTNULL(fixture, "The wing has no working light")
	TEST_ASSERT(nightmare_form.can_target(fixture), "The nightmare would leave a working light alone")
	var/obj/item/light_eater/blade = locate() in nightmare.held_items
	TEST_ASSERT(nightmare_form.ready_to_hit(fixture) && nightmare.get_active_held_item() == blade, "The nightmare did not ready its light eater")
	nightmare.forceMove(get_turf(fixture))
	nightmare.set_combat_mode(TRUE)
	blade.melee_attack_chain(nightmare, fixture)
	TEST_ASSERT_EQUAL(fixture.status, LIGHT_BROKEN, "The nightmare's light eater left a light on")
	TEST_ASSERT(!nightmare_form.can_target(fixture), "The nightmare still wants a broken light")
	nightmare.forceMove(prison_spot(home, 8, 9))
	prison.experiment_creature_appeared(nightmare, "nightmare")
	var/fined = prison.fined_total
	onlooker.set_mood(70)
	nightmare.set_combat_mode(TRUE)
	for(var/i in 1 to 10)
		if(victim.stat == DEAD)
			break
		blade.melee_attack_chain(nightmare, victim)
	TEST_ASSERT_EQUAL(victim.stat, DEAD, "The nightmare's light eater could not kill a prisoner who was down")
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
	var/list/looked = nightmare.examine(owner)
	TEST_ASSERT(findtext(jointext(looked, " "), "will collect"), "The dead nightmare's examine does not say Kessler is coming for it")
	settle_prison_air(home)

// ===== THE FLY PERSON =====

/// The fly person darts about the cell block, keeps away from people and from whoever hit it, and stays still only when it can't move
/datum/unit_test/voidcrew_outpost_prison_experiment_fly
	parent_type = /datum/unit_test/voidcrew_outpost_management

/datum/unit_test/voidcrew_outpost_prison_experiment_fly/Run()
	var/obj/structure/overmap/dynamic/player_outpost/home = experiment_test_claim("flyowner", trouble = TRUE)
	TEST_ASSERT_NOTNULL(home, "The fly test prison did not load")
	var/datum/outpost_prison/prison = test_prison(home)
	trouble_fund(home, 0)
	var/turf/yard = prison_spot(home, 8, 8)
	var/mob/living/carbon/human/fly = experiment_form_body(prison, yard, "fly", track = TRUE)
	var/datum/component/outpost_experiment_form/fly/fly_form = form_of(fly)
	var/datum/ai_controller/brain = fly.ai_controller
	// Four tiles off: not close enough to chase it off
	var/mob/living/carbon/human/owner = make_player(prison_spot(home, 12, 8), "flyowner")
	TEST_ASSERT(fly_form.free_to_dart(), "A fly person alone in the yard is not free to move")
	var/list/looked = fly.examine(owner)
	TEST_ASSERT(findtext(jointext(looked, " "), "never stays still"), "The fly person's examine has no tell")
	TEST_ASSERT(!findtext(jointext(looked, " "), "Knock it out"), "The fly person's examine says how to put it down")

	// Its darts: two to five tiles, always in the cell block.
	for(var/i in 1 to 30)
		var/turf/spot = fly_form.dart_spot()
		TEST_ASSERT_NOTNULL(spot, "The fly person found nowhere to dart in the yard")
		TEST_ASSERT(prison.in_cell_block(spot), "The fly person darted out of the cell block to [spot.x],[spot.y]")
		var/distance = get_dist(fly, spot)
		TEST_ASSERT(distance >= 2 && distance <= 5, "A dart went [distance] tiles, not 2 to 5") // OUTPOST_FLY_DART_MIN/_MAX
	fly_form.ai_think(brain)
	TEST_ASSERT(brain.current_behaviors[GET_AI_BEHAVIOR(/datum/ai_behavior/outpost_fly_dart)], "The fly person alone did not dart about")
	brain.CancelActions()

	// Someone beside it: it darts away from them, to somewhere farther off.
	owner.forceMove(prison_spot(home, 9, 8))
	TEST_ASSERT_EQUAL(fly_form.nearest_threat(), owner, "The fly person paid no mind to someone beside it")
	for(var/i in 1 to 20)
		var/turf/away = fly_form.dart_spot(owner)
		TEST_ASSERT_NOTNULL(away, "The fly person had nowhere to go from someone beside it in the open yard")
		TEST_ASSERT(get_dist(away, owner) > 1, "The fly person darted no farther from the person beside it")
	fly_form.ai_think(brain)
	TEST_ASSERT(brain.current_behaviors[GET_AI_BEHAVIOR(/datum/ai_behavior/outpost_fly_dart/away)], "The fly person did not dart away from someone beside it")
	brain.CancelActions()

	// Hit, it keeps away from whoever did it even once they are out of reach.
	SEND_SIGNAL(fly, COMSIG_ATOM_WAS_ATTACKED, owner, ATTACKER_DAMAGING_ATTACK)
	owner.forceMove(prison_spot(home, 12, 8))
	TEST_ASSERT_NULL(fly_form.nearest_threat(), "Someone four tiles off still counts as close") // OUTPOST_FLY_FLEE_RANGE
	TEST_ASSERT_EQUAL(fly_form.flit_threat(), owner, "The fly person forgot who just hit it")
	fly_form.ai_think(brain)
	TEST_ASSERT(brain.current_behaviors[GET_AI_BEHAVIOR(/datum/ai_behavior/outpost_fly_dart/away)], "The fly person did not flit away from whoever hit it")
	brain.CancelActions()
	fly_form.flit_until = 0

	// Food in sight: it goes and eats it, the way anyone does.
	var/obj/item/food/snack = allocate(/obj/item/food/prison_ration, prison_spot(home, 10, 8))
	fly_form.ai_think(brain)
	TEST_ASSERT(brain.current_behaviors[GET_AI_BEHAVIOR(/datum/ai_behavior/outpost_fly_eat)], "The fly person did not go for the food it saw")
	brain.CancelActions()
	qdel(snack)

	// Knocked down by a baton's worth of stamina it is down: it darts nowhere and, cuffed, it is subdued.
	fly.Knockdown(5 SECONDS)
	TEST_ASSERT_EQUAL(fly.body_position, LYING_DOWN, "A knockdown did not put the fly person on the floor")
	TEST_ASSERT(!fly_form.free_to_dart(), "The fly person could dart off while knocked down")
	fly.SetKnockdown(0)
	fly.get_up(instant = TRUE)
	TEST_ASSERT(fly_form.free_to_dart(), "The fly person could not move again once it got up")
	var/datum/component/experiment_damage_ledger/ledger = fly.GetComponent(/datum/component/experiment_damage_ledger)
	ledger.note_attacker(owner)
	fly.apply_damage(150, STAMINA)
	TEST_ASSERT(HAS_TRAIT_FROM(fly, TRAIT_INCAPACITATED, STAMINA), "A full load of stamina damage did not put the fly person in stamcrit")
	TEST_ASSERT_EQUAL(outpost_experiment_down_state(fly), "down", "The fly person in stamcrit is not down for Kessler") // OUTPOST_EXPERIMENT_DOWN_DOWN
	var/obj/item/restraints/handcuffs/cuffs = allocate(/obj/item/restraints/handcuffs)
	TEST_ASSERT(fly.equip_to_slot_if_possible(cuffs, ITEM_SLOT_HANDCUFFED), "The fly person in stamcrit could not be cuffed")
	TEST_ASSERT_EQUAL(outpost_experiment_down_state(fly), "subdued", "The fly person in stamcrit and cuffed is not subdued") // OUTPOST_EXPERIMENT_DOWN_SUBDUED
	prison.experiments_tick(1)
	var/list/block = prison.experiment_payload()
	TEST_ASSERT_EQUAL(block["pickup"], "subdued", "The console does not show the fly person subdued, awaiting pickup")
	TEST_ASSERT_EQUAL(block["stage"], "live", "The fly person down alive contained the experiment before Kessler had it")
	looked = fly.examine(owner)
	TEST_ASSERT(findtext(jointext(looked, " "), "will collect"), "The subdued fly person's examine does not say Kessler is coming for it")

	// Kessler's team beams in, and its beam takes it; then the bonus, and the console shows it contained.
	prison.kessler_collect(WEAKREF(fly))
	TEST_ASSERT_NOTNULL(locate(/mob/living/carbon/human/npc/outpost_kessler_staff/agent) in range(1, fly), "No Kessler agents beamed in for the fly person")
	prison.kessler_finish_collect(WEAKREF(fly))
	TEST_ASSERT_EQUAL(prison.experiment.bonus_paid, 700, "Subduing the fly person paid [prison.experiment.bonus_paid], not 700") // OUTPOST_EXPERIMENT_BONUS_FLY
	TEST_ASSERT_EQUAL(prison.experiment_payload()["stage"], "contained", "Taking the subdued fly person did not contain the experiment")
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
	var/mob/living/carbon/human/npc/outpost_prisoner/host = test_prisoner(prison, yard)
	TEST_ASSERT(prison.start_experiment("changeling", host, forced = TRUE), "The specimen could not start")
	var/datum/outpost_changeling_event/event = prison.changeling_event()
	TEST_ASSERT_NOTNULL(event, "No changeling event")
	TEST_ASSERT_EQUAL(prison.experiment_payload()["stage"], "incubating", "The console does not show the incubation")

	// Bolted in while it incubates, with no creature about, the lock-in clock counts as it always does:
	// an experiment is no protective custody (owner, 2026-09-25).
	var/mob/living/carbon/human/npc/outpost_prisoner/inmate = test_prisoner(prison, prison_spot(home, 3, 14))
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
	var/mob/living/carbon/human/npc/outpost_prisoner/second_host = test_prisoner(prison, yard)
	TEST_ASSERT(prison.start_experiment("changeling", second_host, forced = TRUE), "The second specimen could not start")
	var/mob/living/basic/headslug/early = allocate(/mob/living/basic/headslug/beakless, prison_spot(home, 8, 9))
	prison.experiment_creature_appeared(early, "headslug")
	var/datum/component/experiment_damage_ledger/early_ledger = early.GetComponent(/datum/component/experiment_damage_ledger)
	early_ledger.note_attacker(crew)
	early.death()
	TEST_ASSERT_EQUAL(treasury.account_balance, 6000, "A caught headslug paid [treasury.account_balance - 5100], not 900") // OUTPOST_EXPERIMENT_BONUS_HEADSLUG

	// Dead with nothing on its ledger and no blow from the crew: no bonus.
	var/mob/living/carbon/human/npc/outpost_prisoner/unhit_host = test_prisoner(prison, yard)
	TEST_ASSERT(prison.start_experiment("changeling", unhit_host, forced = TRUE), "The unhit specimen could not start")
	var/mob/living/basic/headslug/unhit = allocate(/mob/living/basic/headslug/beakless, prison_spot(home, 8, 9))
	prison.experiment_creature_appeared(unhit, "headslug")
	var/balance = treasury.account_balance
	unhit.death()
	TEST_ASSERT_EQUAL(treasury.account_balance, balance, "A headslug nobody touched paid a containment bonus")

	// Blown apart after one small hit from the crew: the blast did the rest, so no bonus.
	var/mob/living/carbon/human/npc/outpost_prisoner/bombed_host = test_prisoner(prison, yard)
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
	var/mob/living/carbon/human/npc/outpost_prisoner/third_host = test_prisoner(prison, yard)
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
	var/mob/living/carbon/human/npc/outpost_prisoner/rioter = allocate(/mob/living/carbon/human/npc/outpost_prisoner, run_loc_floor_bottom_left)
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
	var/mob/living/carbon/human/nightmare = experiment_form_body(prison, prison_spot(home, 9, 8), "nightmare")
	var/datum/component/outpost_experiment_form/nightmare/nightmare_form = form_of(nightmare)

	// A prisoner locked in a bolted cell the nightmare is not in is off-limits; the same door unbolted is not.
	var/mob/living/carbon/human/npc/outpost_prisoner/locked = test_prisoner(prison, yard)
	TEST_ASSERT_NOTNULL(locked.cell, "The locked prisoner was not booked into a cell")
	locked.forceMove(locked.cell.arrival_turf())
	var/mob/living/carbon/human/npc/outpost_prisoner/open_prisoner = test_prisoner(prison, yard)
	TEST_ASSERT(nightmare_form.can_target(locked), "The nightmare ignored a prisoner in an unbolted cell")
	TEST_ASSERT(prison.toggle_cell_bolts(locked.cell.number, null), "The test cell would not bolt")
	TEST_ASSERT(locked.cell.is_bolted(), "The test cell did not report itself bolted")
	TEST_ASSERT(!nightmare_form.can_target(locked), "The nightmare went after a prisoner locked in a bolted cell")
	TEST_ASSERT(nightmare_form.can_target(open_prisoner), "A bolted cell elsewhere stopped the nightmare targeting someone in the open")

	// Standing in the cell with them, its own occupant is fair game again.
	var/turf/outside = get_turf(nightmare)
	nightmare.forceMove(locked.cell.arrival_turf())
	TEST_ASSERT(nightmare_form.can_target(locked), "The nightmare in the cell still could not reach its own occupant")
	nightmare.forceMove(outside)

	// The hulk smashes in regardless of the bolt.
	var/mob/living/carbon/human/hulk = experiment_form_body(prison, prison_spot(home, 11, 8), "hulk")
	var/datum/component/outpost_experiment_form/hulk_form = form_of(hulk)
	TEST_ASSERT(hulk_form.can_target(locked), "A bolted cell kept the hulk out")

	// A target it makes no progress toward for a while is written off, and another is picked instead.
	var/mob/living/carbon/human/npc/outpost_prisoner/stuck_prisoner = test_prisoner(prison, prison_spot(home, 10, 10))
	var/datum/ai_controller/brain = nightmare.ai_controller
	brain.set_blackboard_key(BB_BASIC_MOB_CURRENT_TARGET, stuck_prisoner)
	nightmare_form.track_reach(brain)
	TEST_ASSERT(!nightmare_form.target_unreachable(stuck_prisoner), "A target was written off before it had any chance to be reached")
	nightmare_form.chase_progress_time -= 5 SECONDS // OUTPOST_EXPERIMENT_STUCK_TIME is 4 seconds
	nightmare_form.track_reach(brain)
	TEST_ASSERT(nightmare_form.target_unreachable(stuck_prisoner), "A target that never got any closer was not written off")
	TEST_ASSERT_EQUAL(nightmare_form.choose_target(), open_prisoner, "choose_target() still offered a target written off as unreachable")

	// On the move, it is chasing: a target that keeps its distance is not written off
	var/turf/was_at = nightmare.loc
	brain.set_blackboard_key(BB_BASIC_MOB_CURRENT_TARGET, open_prisoner)
	nightmare_form.track_reach(brain)
	nightmare_form.chase_progress_time -= 5 SECONDS
	nightmare.forceMove(get_step_away(nightmare, open_prisoner) || get_step(nightmare, NORTH))
	nightmare_form.track_reach(brain)
	TEST_ASSERT(!nightmare_form.target_unreachable(open_prisoner), "A target it was following was written off")
	nightmare.forceMove(was_at)
	brain.clear_blackboard_key(BB_BASIC_MOB_CURRENT_TARGET)

	// find_light() skips the same list, so lights behind glass do not trap it forever.
	var/obj/machinery/light/near_light = allocate(/obj/machinery/light, prison_spot(home, 10, 8))
	var/obj/machinery/light/far_light = allocate(/obj/machinery/light, prison_spot(home, 12, 8))
	TEST_ASSERT_EQUAL(nightmare_form.find_light(), near_light, "find_light() did not prefer the nearer light")
	nightmare_form.mark_unreachable(near_light)
	TEST_ASSERT_EQUAL(nightmare_form.find_light(), far_light, "find_light() still offered a light written off as unreachable")
	qdel(near_light)
	qdel(far_light)

	// The hulk smashes through, so it never writes a target off as unreachable either.
	var/datum/ai_controller/hulk_brain = hulk.ai_controller
	hulk_brain.set_blackboard_key(BB_BASIC_MOB_CURRENT_TARGET, stuck_prisoner)
	hulk_form.track_reach(hulk_brain)
	hulk_form.chase_progress_time -= 5 SECONDS
	hulk_form.track_reach(hulk_brain)
	TEST_ASSERT(!hulk_form.target_unreachable(stuck_prisoner), "The hulk wrote a target off as unreachable")
	settle_prison_air(home)
