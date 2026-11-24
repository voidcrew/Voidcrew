// Xenoarchaeology tests: use.
//
// Test files compile before voidcrew/_DEFINES, so the values below are literals. They mirror
// voidcrew/_DEFINES/xenoarch.dm and the harvester's readout keys:
//   ARTIFACT_MAX_HARVESTS 3, ARTIFACT_BATTERY_CAPACITY 200, ARTIFACT_HARVEST_DRAW_RATE 2.5,
//   ARTIFACT_UTILIZER_DRAIN 0.5, ARTIFACT_UTILIZER_PULSE_FEED 1, ARTIFACT_UTILIZER_TOUCH_COST 20,
//   ARTIFACT_AURA_COST_PER_SECOND 1.5, COMSIG_ARTIFACT_HARVESTED "artifact_harvested",
//   release methods "touch", "aura", "pulse"; bands green 1, yellow 2, red 3.
//   readout: "ready", "quiet", "tangled", "unfit", "spent", "busy", "mismatch".

/// A battery fills only from a harvest, only from one source at a time, and a copy of it is empty.
/datum/unit_test/voidcrew_xenoarch_battery/Run()
	var/obj/item/anomaly_battery/battery = allocate(/obj/item/anomaly_battery)
	var/obj/machinery/artifact/find = allocate(/obj/machinery/artifact)
	find.replace_effects(/datum/artifact_effect/heal, /datum/artifact_effect/light, 2)
	var/datum/artifact_effect/heal = find.main_effect
	var/datum/artifact_effect/light = find.second_effect

	TEST_ASSERT_EQUAL(battery.stored_charge, 0, "a new battery came charged")
	TEST_ASSERT_EQUAL(battery.add_charge(50), 0, "a battery holding nothing took charge")
	TEST_ASSERT(battery.can_take(heal), "an empty battery refused an effect")

	battery.load_from(heal, find.serial)
	TEST_ASSERT(istype(battery.held_effect, /datum/artifact_effect/heal), "the battery does not hold a copy of the effect")
	TEST_ASSERT(battery.held_effect != heal, "the battery holds the artifact's own effect, not a copy")
	TEST_ASSERT_EQUAL(battery.held_effect.holder, battery, "the copy's holder is not the battery")
	TEST_ASSERT_EQUAL(battery.source_serial, find.serial, "the battery was not stamped with the find's serial")
	TEST_ASSERT_EQUAL(battery.add_charge(250), 200, "a battery took more than its capacity")
	TEST_ASSERT(battery.is_full(), "a battery at capacity is not full")
	TEST_ASSERT_EQUAL(battery.charge_level(), 100, "a full battery's gauge")
	TEST_ASSERT(!battery.can_take(heal), "a full battery took more")
	battery.use_charge(199)
	TEST_ASSERT_EQUAL(battery.charge_level(), 25, "any charge at all should show a quarter on the gauge")
	TEST_ASSERT(battery.can_take(heal), "a part-charged battery refused a top-up from its own source")
	TEST_ASSERT(!battery.can_take(light), "a part-charged battery took a second effect")
	battery.use_charge(5)
	TEST_ASSERT_EQUAL(battery.stored_charge, 0, "spending more than it held left charge behind")
	TEST_ASSERT(battery.can_take(light), "an empty battery refused a new effect")

	battery.add_charge(80)
	battery.purge()
	TEST_ASSERT_EQUAL(battery.stored_charge, 0, "a purged battery kept charge")
	TEST_ASSERT_NULL(battery.held_effect, "a purged battery kept its effect")
	TEST_ASSERT_NULL(battery.source_serial, "a purged battery kept its stamp")

	// Machines that copy an item (the experimentor) make a new one from its type: always empty.
	battery.load_from(heal, find.serial)
	battery.add_charge(200)
	var/obj/item/anomaly_battery/copy = allocate(battery.type)
	TEST_ASSERT_EQUAL(copy.stored_charge, 0, "a battery built from its type came charged")
	TEST_ASSERT_NULL(copy.held_effect, "a battery built from its type came holding an effect")

/// The harvester: the harvest cap, when a harvest is spent, the lock, refusals and cleanup.
/datum/unit_test/voidcrew_xenoarch_harvest
	var/harvest_signals = 0

/datum/unit_test/voidcrew_xenoarch_harvest/proc/on_harvested(datum/source, datum/artifact_effect/effect, mob/user)
	SIGNAL_HANDLER
	harvest_signals++

/datum/unit_test/voidcrew_xenoarch_harvest/Run()
	var/obj/machinery/artifact_harvester/harvester = allocate(/obj/machinery/artifact_harvester)
	harvester.set_machine_stat(NONE)
	TEST_ASSERT(harvester.is_operational, "the harvester is not operational in the test room")
	var/turf/beside = locate(harvester.x + 1, harvester.y, harvester.z)
	var/obj/machinery/artifact/find = allocate(/obj/machinery/artifact, beside, 2)
	find.replace_effects(/datum/artifact_effect/heal, null, 2)
	RegisterSignal(find, "artifact_harvested", PROC_REF(on_harvested))
	var/price_before = artifact_sale_value(find)

	TEST_ASSERT(!harvester.start_draw(), "it drew with no battery")
	var/obj/item/anomaly_battery/battery = allocate(/obj/item/anomaly_battery)
	battery.forceMove(harvester)
	harvester.battery = battery

	TEST_ASSERT_EQUAL(harvester.find_source(), find, "it did not find the artifact beside it")
	TEST_ASSERT_EQUAL(harvester.source_state(find), "quiet", "a sleeping find did not read as quiet")
	TEST_ASSERT(!harvester.start_draw(), "it drew from a sleeping find")

	find.main_effect.wake(10 MINUTES)
	TEST_ASSERT_EQUAL(harvester.source_state(find), "ready", "an awake, harvestable find did not read as ready")
	TEST_ASSERT(harvester.start_draw(), "it would not draw from a ready find")
	TEST_ASSERT(harvester.drawing, "it is not drawing")
	TEST_ASSERT_EQUAL(find.locked_by?.resolve(), harvester, "it did not lock the find")
	TEST_ASSERT_EQUAL(find.harvests_left, 3, "a harvest was spent before any charge arrived")

	harvester.process(2)
	TEST_ASSERT_EQUAL(battery.stored_charge, 5, "two seconds on tier-1 parts should draw 5 charge")
	TEST_ASSERT_EQUAL(find.harvests_left, 2, "the first charge did not spend a harvest")
	TEST_ASSERT_EQUAL(harvest_signals, 1, "the harvest signal was not sent once")
	harvester.process(2)
	TEST_ASSERT_EQUAL(find.harvests_left, 2, "one draw spent two harvests")
	for(var/i in 1 to 50)
		if(!harvester.drawing)
			break
		harvester.process(2)
	TEST_ASSERT(!harvester.drawing, "it never finished filling the battery")
	TEST_ASSERT(battery.is_full(), "it stopped before the battery was full")
	TEST_ASSERT(!find.is_being_used(), "it kept the find locked after finishing")
	TEST_ASSERT(istype(battery.held_effect, /datum/artifact_effect/heal), "the battery does not hold the drawn effect")
	TEST_ASSERT(artifact_sale_value(find) < price_before, "a harvest did not lower the find's price")
	TEST_ASSERT_EQUAL(harvest_signals, 1, "one full draw sent more than one harvest signal")
	TEST_ASSERT(!harvester.start_draw(), "it drew into a full battery")

	// Stopping before any charge arrives costs nothing; stopping after costs the harvest.
	harvester.purge_battery()
	TEST_ASSERT_EQUAL(battery.stored_charge, 0, "purging left charge in the battery")
	TEST_ASSERT(harvester.start_draw(), "it would not draw into a purged battery")
	harvester.stop_draw()
	TEST_ASSERT_EQUAL(find.harvests_left, 2, "a draw stopped before any charge spent a harvest")
	TEST_ASSERT(!find.is_being_used(), "a stopped draw kept the find locked")
	TEST_ASSERT(harvester.start_draw(), "it would not start again")
	harvester.process(2)
	harvester.stop_draw()
	TEST_ASSERT_EQUAL(find.harvests_left, 1, "a draw stopped after charge arrived did not spend its harvest")
	TEST_ASSERT_EQUAL(battery.stored_charge, 5, "a stopped draw lost the charge it had drawn")

	// A part-charged battery only tops up from the effect it holds.
	find.main_effect.deactivate(quiet = TRUE)
	find.replace_effects(/datum/artifact_effect/heal, /datum/artifact_effect/light, 2)
	find.second_effect.wake(10 MINUTES)
	TEST_ASSERT_EQUAL(harvester.source_state(find), "mismatch", "a battery holding another effect read as ready")
	TEST_ASSERT(!harvester.start_draw(), "a part-charged battery took a second effect")
	find.main_effect.wake(10 MINUTES)
	TEST_ASSERT_EQUAL(harvester.source_state(find), "tangled", "two awake effects did not read as tangled")
	TEST_ASSERT(!harvester.start_draw(), "it drew with two effects awake")
	find.second_effect.deactivate(quiet = TRUE)
	find.main_effect.harvestable = FALSE
	TEST_ASSERT_EQUAL(harvester.source_state(find), "unfit", "an unharvestable effect did not read as unfit")
	TEST_ASSERT(!harvester.start_draw(), "it drew an unharvestable effect")
	find.main_effect.harvestable = TRUE
	harvester.purge_battery()

	// Someone else's lock, and a spent find.
	var/datum/other_locker = new
	TEST_ASSERT(find.try_lock(other_locker), "could not lock the find for the test")
	TEST_ASSERT_EQUAL(harvester.source_state(find), "busy", "a find locked by another machine did not read as busy")
	TEST_ASSERT(!harvester.start_draw(), "it drew from a find another machine held")
	find.release_lock(other_locker)
	qdel(other_locker)
	find.harvests_left = 0
	TEST_ASSERT_EQUAL(harvester.source_state(find), "spent", "a find with no harvests left did not read as spent")
	TEST_ASSERT(!harvester.start_draw(), "it drew past the harvest cap")
	find.harvests_left = 1

	// Hauling the find away mid-draw stops it and lets go.
	TEST_ASSERT(harvester.start_draw(), "it would not draw from the last harvest")
	find.forceMove(run_loc_floor_top_right)
	harvester.process(2)
	TEST_ASSERT(!harvester.drawing, "it kept drawing from a find out of reach")
	TEST_ASSERT(!find.is_being_used(), "it kept a find out of reach locked")
	TEST_ASSERT_EQUAL(find.harvests_left, 1, "a draw that never reached charge spent a harvest")

	// Deleting it mid-draw releases the find; ejecting hands the battery out.
	find.forceMove(beside)
	TEST_ASSERT(harvester.start_draw(), "it would not draw again")
	harvester.process(2)
	TEST_ASSERT_EQUAL(find.harvests_left, 0, "the last harvest was not spent")
	harvester.stop_draw()
	TEST_ASSERT(harvester.eject_battery(), "it would not eject its battery")
	TEST_ASSERT_NULL(harvester.battery, "it kept a reference to the ejected battery")
	TEST_ASSERT(!(battery in harvester.component_parts), "the battery counts as a part of the machine, so ship saves would keep it")
	battery.forceMove(harvester)
	harvester.battery = battery
	find.harvests_left = 1
	harvester.purge_battery()
	TEST_ASSERT(harvester.start_draw(), "it would not draw before deletion")
	qdel(harvester)
	TEST_ASSERT(!find.is_being_used(), "a deleted harvester kept the find locked")
	TEST_ASSERT(QDELETED(battery), "a deleted harvester left its battery in nullspace")
	UnregisterSignal(find, "artifact_harvested")

/// The utilizer: field drain, healing through the shared cap, bursts, contact uses and cleanup.
/datum/unit_test/voidcrew_xenoarch_utilizer/Run()
	var/obj/machinery/artifact/find = allocate(/obj/machinery/artifact)
	find.replace_effects(/datum/artifact_effect/heal, null, 2)
	find.main_effect.release_method = "aura"
	find.main_effect.range = 3
	var/obj/item/anomaly_battery/battery = allocate(/obj/item/anomaly_battery)
	battery.load_from(find.main_effect, find.serial)
	battery.add_charge(200)
	find.moveToNullspace()

	var/obj/item/anomaly_utilizer/utilizer = allocate(/obj/item/anomaly_utilizer)
	TEST_ASSERT(!utilizer.switch_on(), "it switched on with no battery")
	battery.forceMove(utilizer)
	utilizer.battery = battery
	var/datum/artifact_effect/effect = battery.held_effect

	var/mob/living/carbon/human/consistent/patient = allocate(/mob/living/carbon/human/consistent)
	patient.adjustBruteLoss(50)
	var/damage_before = patient.getBruteLoss() + patient.getFireLoss()

	TEST_ASSERT(utilizer.switch_on(), "it would not switch on")
	TEST_ASSERT(effect.activated, "switching on did not wake the battery's effect")
	utilizer.process(2)
	TEST_ASSERT_EQUAL(battery.stored_charge, 199, "a field should cost 0.5 charge a second")
	for(var/i in 1 to 60)
		utilizer.process(2)
	var/healed = damage_before - (patient.getBruteLoss() + patient.getFireLoss())
	TEST_ASSERT(healed > 0, "a heal field healed nobody")
	TEST_ASSERT(healed <= 30.1, "a heal field healed [healed], past the shared cap")
	TEST_ASSERT(effect.activated, "the field lapsed while switched on")

	// Running dry switches it off.
	battery.stored_charge = 0.5
	utilizer.process(2)
	TEST_ASSERT(!utilizer.emitting, "it kept running on an empty battery")
	TEST_ASSERT(!effect.activated, "its effect stayed awake after it went dark")
	TEST_ASSERT(!utilizer.switch_on(), "it switched on with an empty battery")

	// Bursts build up at the utilizer's own rate and let go when full.
	battery.stored_charge = 200
	effect.release_method = "pulse"
	effect.maximum_charges = 6
	effect.current_charge = 0
	TEST_ASSERT(utilizer.switch_on(), "it would not switch on for bursts")
	utilizer.process(2)
	TEST_ASSERT_EQUAL(effect.current_charge, 2, "bursts should build at 1 charge a second")
	utilizer.process(2)
	utilizer.process(2)
	TEST_ASSERT_EQUAL(effect.current_charge, 0, "a full store did not let go")
	utilizer.switch_off()

	// Contact: one use per press, paid from the battery, and nothing while switched off.
	var/mob/living/carbon/human/consistent/holder = allocate(/mob/living/carbon/human/consistent)
	effect.release_method = "touch"
	TEST_ASSERT_EQUAL(utilizer.interact_with_atom(patient, holder), NONE, "a switched-off utilizer acted on contact")
	TEST_ASSERT(utilizer.switch_on(holder), "it would not switch on for contact")
	var/charge_before = battery.stored_charge
	utilizer.process(2)
	TEST_ASSERT_EQUAL(battery.stored_charge, charge_before, "a contact effect drained while waiting")
	TEST_ASSERT_EQUAL(utilizer.interact_with_atom(patient, holder), ITEM_INTERACT_SUCCESS, "pressing it to someone did nothing")
	TEST_ASSERT_EQUAL(battery.stored_charge, charge_before - 20, "a contact use should cost 20 charge")
	TEST_ASSERT_EQUAL(effect.get_responsible(), holder, "the person pressing it does not answer for it")
	TEST_ASSERT_EQUAL(utilizer.interact_with_atom(find, holder), NONE, "it acted on contact with an object")

	// Ejecting while running switches it off; deleting it takes the battery with it.
	TEST_ASSERT(utilizer.eject_battery(holder), "it would not eject its battery")
	TEST_ASSERT(!utilizer.emitting, "it kept running with its battery out")
	TEST_ASSERT(!effect.activated, "the battery's effect stayed awake out of the utilizer")
	TEST_ASSERT_NULL(utilizer.battery, "it kept a reference to the ejected battery")
	if(battery.loc == holder)
		holder.transferItemToLoc(battery, utilizer, force = TRUE)
	else
		battery.forceMove(utilizer)
	utilizer.battery = battery
	TEST_ASSERT(utilizer.switch_on(holder), "it would not switch on again")
	qdel(utilizer)
	TEST_ASSERT(QDELETED(battery), "a deleted utilizer left its battery behind")
