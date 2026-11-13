/**
 * Outpost recovery tests: the checkpoint gate emag and the trader stick-up (spec-rehydrate.md 9 and 10). Owner: R7.
 *
 * Every test loads a real outpost (police_loaded_outpost(), voidcrew_outpost_police_helpers.dm) and takes its
 * main trader and its checkpoints from it, so no test names the trader's type (R1 renames it). Nobody waits for
 * the 3 s hold to steady, the 30 s alarm or the 3 minute gate: a test calls the step it is about (hand_over(),
 * try_alarm(), end_disable()) with the mobs in place, except the one test that runs tg's own right-click hold-up.
 *
 * Defines are included after the tests: values are written out with a comment naming the define.
 */

/datum/unit_test/voidcrew_outpost_recovery_robbery
	abstract_type = /datum/unit_test/voidcrew_outpost_recovery_robbery
	var/obj/structure/overmap/trader_outpost/outpost
	var/datum/outpost_police/police
	/// The checkpoint under test (gate tests)
	var/datum/outpost_checkpoint/checkpoint
	var/obj/item/card/emag/emag
	/// The trader held up (stick-up tests), and its shop
	var/mob/living/trader
	var/datum/outpost_shop/shop
	/// The emagger, or the robber
	var/mob/living/carbon/human/person
	var/obj/item/gun/gun

/// A person with a mind at `where`
/datum/unit_test/voidcrew_outpost_recovery_robbery/proc/mind_person(turf/where)
	var/mob/living/carbon/human/made = allocate(/mob/living/carbon/human/consistent, where)
	made.mind_initialize()
	allocated += made.mind
	return made

/// Nobody and nothing sees: every camera but `keep_camera` is gone and every trader but `keep_trader` is out cold
/datum/unit_test/voidcrew_outpost_recovery_robbery/proc/quiet_witnesses(atom/keep_camera, mob/living/keep_trader)
	for(var/atom/camera as anything in police.perception.cameras())
		if(camera != keep_camera)
			qdel(camera)
	for(var/mob/living/other in outpost.traders)
		if(other != keep_trader)
			other.set_stat(UNCONSCIOUS)

// ===== THE GATE EMAG (spec 9) =====

/// A loaded outpost's checkpoint with a scanner and both doors (with a guard when asked), `person` in its chamber with an emag
/datum/unit_test/voidcrew_outpost_recovery_robbery/proc/gate_fixture(need_guard = FALSE)
	outpost = police_loaded_outpost()
	if(!outpost)
		return FALSE
	police = outpost.police
	for(var/checkpoint_id in outpost.checkpoints)
		var/datum/outpost_checkpoint/candidate = outpost.checkpoints[checkpoint_id]
		if(!candidate?.sensor || !candidate.outer_door || !candidate.inner_door || !length(candidate.chamber_turfs))
			continue
		if(need_guard && !candidate.guard)
			continue
		checkpoint = candidate
		break
	TEST_ASSERT_NOTNULL(checkpoint, "No checkpoint with a scanner[need_guard ? " and a guard" : ""] on the loaded outpost")
	checkpoint.outer_door.set_machine_stat(NONE)
	checkpoint.inner_door.set_machine_stat(NONE)
	person = mind_person(checkpoint.chamber_turfs[1])
	emag = allocate(/obj/item/card/emag)
	return TRUE

/// An emag on the scanner takes the gate down for 3 minutes: no scan, the light out, both doors answer a bump and a barred, armed mob crosses
/datum/unit_test/voidcrew_outpost_recovery_robbery/gate_down

/datum/unit_test/voidcrew_outpost_recovery_robbery/gate_down/Run()
	if(!gate_fixture())
		return
	quiet_witnesses(checkpoint.sensor)
	// Barred (three stars) and carrying a laser: the scan would refuse them
	police_pin_warrant(police, person.mind, 60)
	var/obj/item/gun/energy/laser/rifle = allocate(/obj/item/gun/energy/laser)
	TEST_ASSERT(person.put_in_hands(rifle), "Could not give the emagger a laser")
	TEST_ASSERT(checkpoint.sensor.emag_act(person, emag), "An emag on the wall scanner did nothing")
	TEST_ASSERT(checkpoint.is_disabled(), "The gate is not down after the scanner was emagged")
	TEST_ASSERT_EQUAL(checkpoint.disabled_until, world.time + 1800, "The gate is not down for 3 minutes") // OUTPOST_CHECKPOINT_EMAG_TIME
	TEST_ASSERT_EQUAL(checkpoint.emag_ready_at, checkpoint.disabled_until + 3000, "The scanner can be emagged again before 5 minutes after it comes back") // OUTPOST_CHECKPOINT_EMAG_COOLDOWN
	TEST_ASSERT_EQUAL(checkpoint.sensor.look, "off", "The scanner's light is not out")
	TEST_ASSERT(!police.perception.is_camera(checkpoint.sensor), "A scanner that is down is still a camera")
	// The inner door answers a bump from the chamber with no scan, and the barred, armed mob crosses
	TEST_ASSERT(checkpoint.request_cycle(person), "The inner door did not answer a bump while the gate was down")
	TEST_ASSERT_EQUAL(checkpoint.state, "idle", "The chamber scanned someone while the gate was down") // CHECKPOINT_IDLE
	// ...and the outer door answers one too, with the inner door open: no interlock
	TEST_ASSERT(checkpoint.request_outer(person), "The outer door did not answer a bump while the gate was down")
	sleep(1.5 SECONDS)
	TEST_ASSERT(!checkpoint.inner_door.density, "The inner door stayed shut for a barred, armed mob while the gate was down")
	TEST_ASSERT(!checkpoint.outer_door.density, "The outer door stayed shut while the gate was down")

/// At the end time the light is back, both doors shut and the gate scans again
/datum/unit_test/voidcrew_outpost_recovery_robbery/gate_scans_again

/datum/unit_test/voidcrew_outpost_recovery_robbery/gate_scans_again/Run()
	if(!gate_fixture())
		return
	quiet_witnesses(checkpoint.sensor)
	TEST_ASSERT(checkpoint.sensor.emag_act(person, emag), "An emag on the wall scanner did nothing")
	TEST_ASSERT(checkpoint.request_cycle(person), "The inner door did not answer a bump while the gate was down")
	sleep(1 SECONDS)
	checkpoint.disabled_until = world.time
	checkpoint.end_disable()
	TEST_ASSERT(!checkpoint.is_disabled(), "The gate is still down at its end time")
	TEST_ASSERT_EQUAL(checkpoint.sensor.look, "idle", "The scanner's light did not come back")
	TEST_ASSERT(police.perception.is_camera(checkpoint.sensor), "A scanner that is back up is no camera")
	sleep(2 SECONDS)
	TEST_ASSERT(checkpoint.inner_door.density, "The inner door was left open when the gate came back")
	TEST_ASSERT(checkpoint.outer_door.density, "The outer door was left open when the gate came back")
	// Whoever stands in the chamber is scanned on the next cycle
	TEST_ASSERT(checkpoint.request_cycle(person), "The inner door did not take a scan request once the gate was back")
	TEST_ASSERT_EQUAL(checkpoint.state, "scanning", "The gate does not scan again after it came back") // CHECKPOINT_SCANNING

/// A second emag inside 5 minutes of the gate coming back (or while it is down) does nothing (M36)
/datum/unit_test/voidcrew_outpost_recovery_robbery/gate_cooldown

/datum/unit_test/voidcrew_outpost_recovery_robbery/gate_cooldown/Run()
	if(!gate_fixture())
		return
	quiet_witnesses(checkpoint.sensor)
	TEST_ASSERT(checkpoint.sensor.emag_act(person, emag), "An emag on the wall scanner did nothing")
	var/first_end = checkpoint.disabled_until
	TEST_ASSERT(!checkpoint.sensor.emag_act(person, emag), "A scanner that is already down took a second emag")
	TEST_ASSERT_EQUAL(checkpoint.disabled_until, first_end, "A second emag moved the end time")
	checkpoint.disabled_until = world.time
	checkpoint.end_disable()
	TEST_ASSERT(checkpoint.emag_ready_at > world.time, "The scanner can be emagged the moment it came back")
	TEST_ASSERT(!checkpoint.sensor.emag_act(person, emag), "A scanner took an emag inside 5 minutes of coming back")
	TEST_ASSERT(!checkpoint.is_disabled(), "A refused emag took the gate down")
	checkpoint.emag_ready_at = world.time
	TEST_ASSERT(checkpoint.sensor.emag_act(person, emag), "The scanner did not take an emag after the wait")

/// A guard who is awake sees it: 2 stars and the emag is evidence (he needs no radio: the officers are not there)
/datum/unit_test/voidcrew_outpost_recovery_robbery/gate_guard_sees

/datum/unit_test/voidcrew_outpost_recovery_robbery/gate_guard_sees/Run()
	if(!gate_fixture(TRUE))
		return
	quiet_witnesses(checkpoint.sensor, checkpoint.guard)
	TEST_ASSERT(checkpoint.sensor.emag_act(person, emag), "An emag on the wall scanner did nothing")
	TEST_ASSERT_EQUAL(police.get_stars(person.mind), 2, "An awake guard watching the emag did not make it a 2 star crime")
	var/datum/outpost_warrant/warrant = police.get_warrant(person.mind)
	TEST_ASSERT_NOTNULL(warrant, "The emagger has no warrant")
	TEST_ASSERT(WEAKREF(emag) in warrant.evidence, "The emag is not evidence against the emagger")

/// With the guard dead and nobody else watching, the gate is down and nobody is wanted
/datum/unit_test/voidcrew_outpost_recovery_robbery/gate_guard_dead

/datum/unit_test/voidcrew_outpost_recovery_robbery/gate_guard_dead/Run()
	if(!gate_fixture(TRUE))
		return
	quiet_witnesses(checkpoint.sensor)
	var/mob/living/guard = checkpoint.guard
	guard.death()
	TEST_ASSERT(checkpoint.sensor.emag_act(person, emag), "An emag on the wall scanner did nothing")
	TEST_ASSERT(checkpoint.is_disabled(), "The gate is not down after the scanner was emagged with the guard dead")
	TEST_ASSERT_NULL(police.get_warrant(person.mind), "The emagger is wanted with the guard dead and nobody watching")
	TEST_ASSERT_EQUAL(police.get_stars(person.mind), 0, "The emagger has stars with the guard dead and nobody watching")

/// Abuse SF1: someone tied up and dragged, or shut in a pulled locker, through a forced gate did not breach it; whoever moved them did
/datum/unit_test/voidcrew_outpost_recovery_robbery/gate_breach_mover

/datum/unit_test/voidcrew_outpost_recovery_robbery/gate_breach_mover/Run()
	if(!gate_fixture())
		return
	var/turf/chamber = checkpoint.chamber_turfs[1]
	checkpoint.state = "forced" // CHECKPOINT_FORCED
	// Tied up and dragged
	var/mob/living/carbon/human/dragger = mind_person(chamber)
	ADD_TRAIT(person, TRAIT_RESTRAINED, "outpost_police_test")
	person.pulledby = dragger
	checkpoint.on_breach_entry(person, chamber)
	person.pulledby = null
	TEST_ASSERT_NULL(police.get_warrant(person.mind), "Someone tied up and dragged through a forced gate was charged")
	TEST_ASSERT_NOTNULL(police.get_warrant(dragger.mind), "Whoever dragged someone through a forced gate was not charged")
	// Shut in a locker someone pulls
	var/mob/living/carbon/human/stuffed = mind_person(chamber)
	var/mob/living/carbon/human/hauler = mind_person(chamber)
	var/obj/structure/closet/locker = allocate(/obj/structure/closet, chamber)
	stuffed.forceMove(locker)
	locker.pulledby = hauler
	checkpoint.on_breach_entry(locker, chamber)
	locker.pulledby = null
	stuffed.forceMove(chamber)
	TEST_ASSERT_NULL(police.get_warrant(stuffed.mind), "Someone shut in a locker pulled through a forced gate was charged")
	TEST_ASSERT_NOTNULL(police.get_warrant(hauler.mind), "Whoever pulled a locker with someone in it through a forced gate was not charged")
	// Walking through on their own is still a breach
	REMOVE_TRAIT(person, TRAIT_RESTRAINED, "outpost_police_test")
	police.recent_reports.Cut()
	checkpoint.on_breach_entry(person, chamber)
	TEST_ASSERT_NOTNULL(police.get_warrant(person.mind), "Walking through a forced gate was not a breach")
	checkpoint.state = "idle" // CHECKPOINT_IDLE

// ===== THE STICK-UP (spec 10) =====

/// A loaded outpost's main trader at its counter, the keeper of its shop, and a robber with a gun beside it. Nobody else sees.
/datum/unit_test/voidcrew_outpost_recovery_robbery/proc/holdup_fixture()
	outpost = police_loaded_outpost()
	if(!outpost)
		return FALSE
	police = outpost.police
	TEST_ASSERT_NOTNULL(outpost.recovery, "The loaded outpost has no recovery")
	trader = outpost.trader
	TEST_ASSERT_NOTNULL(trader, "The loaded outpost has no main trader")
	shop = outpost_holdup_shop(trader)
	TEST_ASSERT_NOTNULL(shop, "The main trader's shop was not found")
	shop.set_keeper(trader)
	if(shop.keeper?.resolve() != trader)
		shop.keeper = WEAKREF(trader)
	var/turf/spot = get_turf(trader)
	for(var/turf/open/near in orange(2, trader))
		if(!near.is_blocked_turf(exclude_mobs = FALSE))
			spot = near
			if(get_dist(near, trader) <= 1)
				break
	person = mind_person(spot)
	gun = allocate(/obj/item/gun/energy/disabler)
	TEST_ASSERT(person.put_in_hands(gun), "Could not give the robber a gun")
	quiet_witnesses(null, trader)
	TEST_ASSERT(!length(police.perception.holdup_witnesses(person, trader)), "Someone other than the trader still sees the robber")
	return TRUE

/// The credits on the chip the robber was given, or null (in hand, or on the counter)
/datum/unit_test/voidcrew_outpost_recovery_robbery/proc/robbed_chip()
	for(var/obj/item/holochip/chip in person.get_all_contents())
		return chip
	for(var/obj/item/holochip/chip in range(2, trader))
		return chip
	return null

/datum/unit_test/voidcrew_outpost_recovery_robbery/proc/hold_up()
	shop.held_up(trader, person, gun)
	TEST_ASSERT_NOTNULL(shop.holdup, "A trader at its counter held up with a gun started no stick-up")
	return TRUE

/// The till pays 200 times the zone multiplier from the shared room, once; then one cheap shelf item; then nothing (SU1, M37)
/datum/unit_test/voidcrew_outpost_recovery_robbery/holdup_takings

/datum/unit_test/voidcrew_outpost_recovery_robbery/holdup_takings/Run()
	if(!holdup_fixture())
		return
	TEST_ASSERT_EQUAL(shop.till_ready_at, 0, "A fresh till is not full")
	var/room_before = outpost.recovery.loss_room()
	if(!hold_up())
		return
	var/pay = round(200 * police.profile.fine_multiplier) // OUTPOST_HOLDUP_TILL times the zone multiplier
	TEST_ASSERT(room_before >= pay, "The outpost has less loss room ([room_before]) than the till pays ([pay]) on a fresh round")
	shop.holdup.hand_over(trader, person)
	var/obj/item/holochip/chip = robbed_chip()
	TEST_ASSERT_NOTNULL(chip, "The till gave the robber nothing")
	TEST_ASSERT_EQUAL(chip.credits, pay, "The till paid the wrong amount")
	TEST_ASSERT_EQUAL(shop.till_ready_at, world.time + 18000, "The emptied till is not refilled in 30 minutes") // OUTPOST_HOLDUP_TILL_REFILL
	TEST_ASSERT_EQUAL(shop.till_robbed_by?.resolve(), person.mind, "The shop does not remember who emptied its till")
	TEST_ASSERT_EQUAL(room_before - outpost.recovery.loss_room(), pay, "The takings did not count against the outpost's loss room")
	TEST_ASSERT(WEAKREF(chip) in police.takings, "The takings are not stolen property")
	// The convoy forgets who emptied it
	SEND_SIGNAL(outpost, "trader_outpost_convoy") // COMSIG_TRADER_OUTPOST_CONVOY
	TEST_ASSERT_NULL(shop.till_robbed_by, "The supply convoy did not forget who emptied the till")
	// An empty till: one cheap shelf item if there is one, stock down by one, never more than 100 cr
	var/stock_before = shelf_stock()
	var/had_item = !!shop.holdup_pick_sku(outpost.recovery.loss_room())
	var/obj/item/second = shop.holdup_take(trader, person)
	if(had_item)
		TEST_ASSERT_NOTNULL(second, "An empty till with a cheap item on the shelf gave nothing")
		TEST_ASSERT(is_trader_good(second), "A shelf item handed over at gunpoint was not stamped as trader goods")
	else
		TEST_ASSERT_NULL(second, "An empty till gave something with no cheap item on the shelf")
	TEST_ASSERT_EQUAL(stock_before - shelf_stock(), had_item ? 1 : 0, "The shelf stock did not fall by one for the item")
	TEST_ASSERT_NULL(shop.holdup_take(trader, person), "A third hand-over from the same till still gave something")
	// The till refilling clears it too: the death drop is back
	shop.till_robbed_by = WEAKREF(person.mind)
	shop.till_ready_at = world.time + 100
	shop.till_refilled()
	TEST_ASSERT_NOTNULL(shop.till_robbed_by, "The shop forgot who emptied the till before it was full again")
	shop.till_ready_at = world.time
	shop.till_refilled()
	TEST_ASSERT_NULL(shop.till_robbed_by, "The shop still remembers who emptied a till that is full again")
	qdel(shop.holdup)

/// Units on the shop's shelves, all together
/datum/unit_test/voidcrew_outpost_recovery_robbery/proc/shelf_stock()
	. = 0
	for(var/datum/shop_sku/sku in shop.skus)
		. += sku.stock

/// At the outpost's cap the till is empty, and so is the shelf
/datum/unit_test/voidcrew_outpost_recovery_robbery/holdup_cap

/datum/unit_test/voidcrew_outpost_recovery_robbery/holdup_cap/Run()
	if(!holdup_fixture())
		return
	outpost.recovery.losses = 1500 // OUTPOST_RECOVERY_LOSS_CAP
	if(!hold_up())
		return
	TEST_ASSERT_NULL(shop.holdup_take(trader, person), "A till at the outpost's cap gave something")
	TEST_ASSERT_EQUAL(shop.till_ready_at, 0, "A hand-over of nothing emptied the till")
	qdel(shop.holdup)

/// The alarm is the trader's report: 2 stars and the gun is evidence, once however often it is raised (M37, M38)
/datum/unit_test/voidcrew_outpost_recovery_robbery/holdup_alarm

/datum/unit_test/voidcrew_outpost_recovery_robbery/holdup_alarm/Run()
	if(!holdup_fixture())
		return
	if(!hold_up())
		return
	shop.holdup.hand_over(trader, person)
	TEST_ASSERT_NULL(police.get_warrant(person.mind), "The robber was wanted before anyone raised the alarm")
	shop.raise_holdup_alarm(trader)
	TEST_ASSERT_EQUAL(police.get_stars(person.mind), 2, "Armed robbery is not 2 stars")
	var/datum/outpost_warrant/warrant = police.get_warrant(person.mind)
	TEST_ASSERT_EQUAL(warrant.heat, 30, "Armed robbery is not 30 heat") // ARMED_ROBBERY points
	TEST_ASSERT(WEAKREF(gun) in warrant.evidence, "The gun is not evidence against the robber")
	shop.raise_holdup_alarm(trader)
	TEST_ASSERT_EQUAL(warrant.heat, 30, "A second alarm counted the robbery again")
	qdel(shop.holdup)

/// A trader that is dead, out cold or dragged off its counter raises no alarm (decision 19)
/datum/unit_test/voidcrew_outpost_recovery_robbery/holdup_silenced
	abstract_type = /datum/unit_test/voidcrew_outpost_recovery_robbery/holdup_silenced

/datum/unit_test/voidcrew_outpost_recovery_robbery/holdup_silenced/proc/silence()
	return

/datum/unit_test/voidcrew_outpost_recovery_robbery/holdup_silenced/Run()
	if(!holdup_fixture())
		return
	if(!hold_up())
		return
	shop.holdup.hand_over(trader, person)
	silence()
	shop.holdup.try_alarm(TRUE)
	TEST_ASSERT_NULL(police.get_warrant(person.mind), "A trader that could not reach the alarm raised it")
	TEST_ASSERT_EQUAL(police.get_stars(person.mind), 0, "The robber has stars though the trader could not reach the alarm")
	qdel(shop.holdup)

/datum/unit_test/voidcrew_outpost_recovery_robbery/holdup_silenced/dead

/datum/unit_test/voidcrew_outpost_recovery_robbery/holdup_silenced/dead/silence()
	trader.death()

/datum/unit_test/voidcrew_outpost_recovery_robbery/holdup_silenced/out_cold

/datum/unit_test/voidcrew_outpost_recovery_robbery/holdup_silenced/out_cold/silence()
	trader.set_stat(UNCONSCIOUS)

/datum/unit_test/voidcrew_outpost_recovery_robbery/holdup_silenced/dragged

/datum/unit_test/voidcrew_outpost_recovery_robbery/holdup_silenced/dragged/silence()
	trader.forceMove(locate(trader.x + 5, trader.y, trader.z))

/// Abuse SF6 (M38): a trader out cold or tied up when the 30 s alarm comes raises it the moment it can
/datum/unit_test/voidcrew_outpost_recovery_robbery/holdup_alarm_waits

/datum/unit_test/voidcrew_outpost_recovery_robbery/holdup_alarm_waits/Run()
	if(!holdup_fixture())
		return
	if(!hold_up())
		return
	var/datum/outpost_holdup/holdup = shop.holdup
	holdup.hand_over(trader, person)
	trader.set_stat(UNCONSCIOUS)
	holdup.timed_alarm()
	TEST_ASSERT_NULL(police.get_warrant(person.mind), "A trader out cold raised the alarm")
	TEST_ASSERT(!QDELETED(holdup) && !holdup.alarm_done, "The alarm was dropped because the trader was out cold at 30 seconds")
	if(QDELETED(holdup))
		return
	TEST_ASSERT(holdup.alarm_overdue, "The alarm is not waiting for the trader")
	TEST_ASSERT_NOTNULL(holdup.watch_timer, "Nothing tries the alarm again")
	holdup.watch_robber()
	TEST_ASSERT_NULL(police.get_warrant(person.mind), "A trader still out cold raised the alarm")
	trader.set_stat(CONSCIOUS)
	holdup.watch_robber()
	TEST_ASSERT_EQUAL(police.get_stars(person.mind), 2, "The trader did not raise the alarm once it could")
	if(!QDELETED(shop.holdup))
		qdel(shop.holdup)

/// Abuse SF6: trying to cuff a trader is assault on the staff
/datum/unit_test/voidcrew_outpost_recovery_robbery/holdup_cuff_is_assault

/datum/unit_test/voidcrew_outpost_recovery_robbery/holdup_cuff_is_assault/Run()
	if(!holdup_fixture())
		return
	SEND_SIGNAL(trader, COMSIG_CARBON_CUFF_ATTEMPTED, person)
	var/datum/outpost_warrant/warrant = police.get_warrant(person.mind)
	TEST_ASSERT_NOTNULL(warrant, "Trying to cuff a trader in front of it made no warrant")
	TEST_ASSERT(warrant?.heat > 0, "Trying to cuff a trader was not assault on the staff") // OUTPOST_CRIME_ASSAULT_STAFF

/// A gate guard has no till and nobody who is not a trader at its counter is robbed (M40)
/datum/unit_test/voidcrew_outpost_recovery_robbery/holdup_guard_has_no_till

/datum/unit_test/voidcrew_outpost_recovery_robbery/holdup_guard_has_no_till/Run()
	if(!gate_fixture(TRUE))
		return
	var/mob/living/guard = checkpoint.guard
	var/datum/outpost_shop/guard_shop = outpost_holdup_shop(guard)
	TEST_ASSERT_NOTNULL(guard_shop, "The guard's shop was not found")
	guard_shop.set_keeper(guard)
	if(guard_shop.keeper?.resolve() != guard)
		guard_shop.keeper = WEAKREF(guard)
	gun = allocate(/obj/item/gun/energy/disabler)
	TEST_ASSERT(person.put_in_hands(gun), "Could not give the robber a gun")
	guard_shop.held_up(guard, person, gun)
	TEST_ASSERT_NULL(guard_shop.holdup, "A checkpoint guard was held up for a till he does not have")
	// A trader who is not the shop's keeper (away from its counter) is not robbed either
	var/mob/living/main_trader = outpost.trader
	var/datum/outpost_shop/main_shop = outpost_holdup_shop(main_trader)
	main_shop.keeper = null
	main_shop.held_up(main_trader, person, gun)
	TEST_ASSERT_NULL(main_shop.holdup, "A keeper who is not the shop's keeper was held up for a till")
	// ...and a keeper dragged off its counter (a person's home is the counter tile they were put on)
	if(istype(main_trader, /mob/living/carbon/human/npc/ambient_npc))
		var/mob/living/carbon/human/npc/ambient_npc/main_npc = main_trader
		main_shop.keeper = WEAKREF(main_npc)
		if(main_npc.home)
			main_npc.forceMove(locate(main_npc.home.x + 5, main_npc.home.y, main_npc.home.z))
			main_shop.held_up(main_npc, person, gun)
			TEST_ASSERT_NULL(main_shop.holdup, "A trader dragged off its counter was held up for a till")

/// tg's own right-click hold-up: hands up at once, the till when the hold steadies, and the trader stands still until it is lowered
/datum/unit_test/voidcrew_outpost_recovery_robbery/holdup_real_hold

/datum/unit_test/voidcrew_outpost_recovery_robbery/holdup_real_hold/Run()
	if(!holdup_fixture())
		return
	person.AddComponent(/datum/component/gunpoint, trader, gun)
	sleep(1 SECONDS)
	var/datum/outpost_holdup/held = shop.holdup
	TEST_ASSERT_NOTNULL(held, "tg's hold-up on the keeper started no stick-up")
	TEST_ASSERT(HAS_TRAIT_FROM(trader, TRAIT_AI_PAUSED, REF(held)), "The trader does not hold still while it is held up")
	TEST_ASSERT_NULL(robbed_chip(), "The till paid before the hold steadied")
	sleep(3 SECONDS)
	var/obj/item/holochip/chip = robbed_chip()
	TEST_ASSERT_NOTNULL(chip, "The till paid nothing when the hold steadied")
	TEST_ASSERT_EQUAL(chip.credits, round(200 * police.profile.fine_multiplier), "The till paid the wrong amount") // OUTPOST_HOLDUP_TILL times the zone multiplier
	// The robber lowers the gun: the alarm is still out, then it goes and the trader is free
	qdel(person.GetComponent(/datum/component/gunpoint))
	TEST_ASSERT_NOTNULL(shop.holdup, "The stick-up ended before its alarm")
	shop.raise_holdup_alarm(trader)
	TEST_ASSERT_EQUAL(police.get_stars(person.mind), 2, "Armed robbery is not 2 stars")
	TEST_ASSERT_NULL(shop.holdup, "The stick-up was not over after its alarm and the hold")
	TEST_ASSERT(!HAS_TRAIT_FROM(trader, TRAIT_AI_PAUSED, REF(held)), "The trader was left standing still")

/// Takings found on the robber go back to the till at the arrest (SU4)
/datum/unit_test/voidcrew_outpost_recovery_robbery/holdup_takings_go_back

/datum/unit_test/voidcrew_outpost_recovery_robbery/holdup_takings_go_back/Run()
	if(!holdup_fixture())
		return
	if(!hold_up())
		return
	shop.holdup.hand_over(trader, person)
	var/obj/item/holochip/chip = robbed_chip()
	TEST_ASSERT_NOTNULL(chip, "The till gave the robber nothing")
	TEST_ASSERT(chip in police.evidence_candidates(person), "The Search step does not take the stolen takings")
	var/obj/item/outpost_sealed_case/evidence/case = allocate(/obj/item/outpost_sealed_case/evidence)
	case.police_ref = WEAKREF(police)
	TEST_ASSERT(case.add_evidence(chip, person), "Could not put the takings in the evidence case")
	police.evidence_empty_case(case, get_turf(person))
	TEST_ASSERT(QDELETED(chip), "The stolen takings were not taken out of the world")
	TEST_ASSERT_EQUAL(shop.till_ready_at, 0, "The till is not full again once its takings are back")
	qdel(shop.holdup)

/// A stolen chip split down to 1 cr and seized gives back only its share of the till's wait, not the whole till
/datum/unit_test/voidcrew_outpost_recovery_robbery/holdup_takings_partial_return

/datum/unit_test/voidcrew_outpost_recovery_robbery/holdup_takings_partial_return/Run()
	if(!holdup_fixture())
		return
	if(!hold_up())
		return
	var/pay = round(200 * police.profile.fine_multiplier)
	shop.holdup.hand_over(trader, person)
	var/obj/item/holochip/chip = robbed_chip()
	TEST_ASSERT_NOTNULL(chip, "The till gave the robber nothing")
	chip.spend(pay - 1, TRUE) // the rest split off onto a chip nobody tracks
	var/obj/item/outpost_sealed_case/evidence/small_case = allocate(/obj/item/outpost_sealed_case/evidence)
	small_case.police_ref = WEAKREF(police)
	TEST_ASSERT(small_case.add_evidence(chip, person), "Could not seize the 1 cr chip")
	police.evidence_empty_case(small_case, get_turf(person))
	TEST_ASSERT(shop.till_ready_at > world.time + 15000, "Returning 1 cr refilled the 30 minute till")
	TEST_ASSERT_NOTNULL(shop.till_robbed_by, "Returning 1 cr cleared till_robbed_by")
	qdel(shop.holdup)

/// Lowering the gun unpauses the trader's AI while keeping the first robber's alarm, and a second robber can still hold the trader up
/datum/unit_test/voidcrew_outpost_recovery_robbery/holdup_second_robber

/datum/unit_test/voidcrew_outpost_recovery_robbery/holdup_second_robber/Run()
	if(!holdup_fixture())
		return
	if(!hold_up())
		return
	var/datum/outpost_holdup/first_hold = shop.holdup
	first_hold.hand_over(trader, person)
	trader.apply_status_effect(/datum/status_effect/grouped/heldup, REF(person))
	trader.remove_status_effect(/datum/status_effect/grouped/heldup, REF(person))
	TEST_ASSERT(!HAS_TRAIT_FROM(trader, TRAIT_AI_PAUSED, REF(first_hold)), "Trader stayed AI-paused after gunpoint ended")

	var/mob/living/carbon/human/second_robber = mind_person(get_turf(person))
	var/obj/item/gun/energy/disabler/second_gun = allocate(/obj/item/gun/energy/disabler)
	second_robber.put_in_hands(second_gun)
	shop.held_up(trader, second_robber, second_gun)
	TEST_ASSERT(shop.holdup && shop.holdup != first_hold, "A second robber aiming at the trader started no hold-up")
	TEST_ASSERT(HAS_TRAIT_FROM(trader, TRAIT_AI_PAUSED, REF(shop.holdup)), "Trader did not pause for the second robber's gunpoint")
	shop.raise_holdup_alarm(trader)
	TEST_ASSERT_EQUAL(police.get_stars(person.mind), 2, "First robber's alarm was lost when a second robber aimed")
	TEST_ASSERT_EQUAL(police.get_stars(second_robber.mind), 2, "Second robber's alarm did not fire")
	if(!QDELETED(first_hold))
		qdel(first_hold)
	if(!QDELETED(shop.holdup))
		qdel(shop.holdup)

/// Crowbarring or emagging the inner door while the gate is already down from a scanner emag never starts a breach
/datum/unit_test/voidcrew_outpost_recovery_robbery/gate_down_no_breach

/datum/unit_test/voidcrew_outpost_recovery_robbery/gate_down_no_breach/Run()
	if(!gate_fixture())
		return
	quiet_witnesses(checkpoint.sensor)
	TEST_ASSERT(checkpoint.sensor.emag_act(person, emag), "An emag on the wall scanner did nothing")
	TEST_ASSERT(!checkpoint.inner_door.emag_act(person, emag), "The inner door took an emag while the gate was already down")
	var/obj/item/crowbar/crowbar = allocate(/obj/item/crowbar, person)
	TEST_ASSERT_EQUAL(checkpoint.inner_door.crowbar_act(person, crowbar), ITEM_INTERACT_SUCCESS, "Crowbarring a disabled inner door failed")
	TEST_ASSERT(!checkpoint.forcing && checkpoint.state != "forced", "Crowbarring a disabled inner door started a forced breach") // CHECKPOINT_FORCED

/// Every zone has four or more lines for each kind, and an alarm line that needs no place or look
/datum/unit_test/voidcrew_outpost_recovery_robbery_lines

/datum/unit_test/voidcrew_outpost_recovery_robbery_lines/Run()
	for(var/section in list("halcyon", "quartermain", "undertow"))
		for(var/key in list("hands_up", "hand_over", "empty", "alarm", "gate_down"))
			var/list/lines = ambient_dialogue_lines("outpost_robbery.json", section, key) // AMBIENT_STRINGS_ROBBERY
			TEST_ASSERT(length(lines) >= 4, "[section] has [length(lines)] '[key]' lines, not 4 or more")
			for(var/line in lines)
				TEST_ASSERT(istext(line) && length(line) > 0 && length(line) <= 80, "[section] '[key]' has a line that is not a short piece of text")
			TEST_ASSERT(istext(outpost_police_pick_line(lines, list())), "[section] '[key]' has no line for a robber with no place or look")
