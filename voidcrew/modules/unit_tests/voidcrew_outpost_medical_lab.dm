/**
 * Medical lab tests (spec 3.4, abuse review F-28 to F-31). Voidcrew defines are not visible here,
 * so prices, ids and times are literals: pass 300 cr for 30 minutes, room "medical_lab" at 2000 cr.
 */

/// The slab with a controllable player check: test mobs have no client.
/obj/machinery/outpost_autosurgeon/medlab_test
	/// Mobs this slab treats as not played
	var/list/absent = list()

/obj/machinery/outpost_autosurgeon/medlab_test/Destroy()
	absent = null
	return ..()

/obj/machinery/outpost_autosurgeon/medlab_test/has_player(mob/living/patient)
	return patient && !(patient in absent)

/// A claim owned by `owner_key` with a medical lab placed at `rotation`, or null after failing the test
/datum/unit_test/voidcrew_outpost_management/proc/medlab_test_lab(owner_key, rotation = 0)
	var/obj/structure/overmap/dynamic/player_outpost/home = market_test_claim(owner_key)
	if(!home)
		TEST_FAIL("The medical lab test claim did not load.")
		return null
	var/result = place_test_service_room(home, /datum/outpost_upgrade/service/medical_lab, list(rotation))
	if(!istype(result, /datum/outpost_upgrade/service/medical_lab))
		TEST_FAIL("The medical lab could not be placed at [rotation] degrees: [result]")
		return null
	return result

/// The first `type` in the lab's footprint
/datum/unit_test/voidcrew_outpost_management/proc/medlab_find(datum/outpost_upgrade/service/medical_lab/lab, type)
	for(var/turf/tile as anything in lab.room_turfs())
		var/atom/found = locate(type) in tile
		if(found)
			return found
	return null

/// A free floor tile beside `thing` for a test body, preferring the side it opens onto (away from its port)
/datum/unit_test/voidcrew_outpost_management/proc/medlab_open_beside(atom/thing)
	for(var/direction in list(REVERSE_DIR(thing.dir)) + GLOB.cardinals)
		var/turf/open/spot = get_step(thing, direction)
		if(istype(spot) && !spot.is_blocked_turf(exclude_mobs = TRUE))
			return spot
	return get_turf(thing)

/// Every `type` in the lab's footprint
/datum/unit_test/voidcrew_outpost_management/proc/medlab_find_all(datum/outpost_upgrade/service/medical_lab/lab, type)
	var/list/found = list()
	for(var/turf/tile as anything in lab.room_turfs())
		for(var/atom/thing as anything in tile)
			if(istype(thing, type))
				found += thing
	return found

/// A test slab on the lab's real slab tile, powered
/datum/unit_test/voidcrew_outpost_management/proc/medlab_test_slab(datum/outpost_upgrade/service/medical_lab/lab)
	var/obj/machinery/outpost_autosurgeon/real = medlab_find(lab, /obj/machinery/outpost_autosurgeon)
	if(!real)
		return null
	var/obj/machinery/outpost_autosurgeon/medlab_test/slab = allocate(/obj/machinery/outpost_autosurgeon/medlab_test, get_turf(real))
	slab.set_machine_stat(slab.machine_stat & ~NOPOWER)
	return slab

/// Puts `patient` on the slab
/datum/unit_test/voidcrew_outpost_management/proc/medlab_lie_down(obj/machinery/outpost_autosurgeon/slab, mob/living/carbon/patient)
	patient.forceMove(get_turf(slab))
	slab.buckle_mob(patient, force = TRUE)

/// Runs the slab's current procedure to its end (or `max_ticks` two-second ticks)
/datum/unit_test/voidcrew_outpost_management/proc/medlab_run_out(obj/machinery/outpost_autosurgeon/slab, max_ticks = 200)
	for(var/i in 1 to max_ticks)
		if(!slab.run)
			return TRUE
		slab.process(2)
	return !slab.run

// ===== CATALOG, PLACEMENT AND THE CRYO LOOP (spec 3.4.7 go/no-go) =====

/datum/unit_test/voidcrew_outpost_medical_lab_room
	parent_type = /datum/unit_test/voidcrew_outpost_management

/datum/unit_test/voidcrew_outpost_medical_lab_room/Run()
	var/datum/outpost_upgrade/prototype = GLOB.outpost_upgrade_catalog["medical_lab"]
	TEST_ASSERT(istype(prototype, /datum/outpost_upgrade/service/medical_lab), "The medical lab is missing from the upgrade catalog")
	TEST_ASSERT_EQUAL(prototype.price, 2000, "The medical lab's price is wrong")
	var/datum/map_template/template = prototype.get_template()
	TEST_ASSERT_NOTNULL(template, "The medical lab map did not load")
	TEST_ASSERT(prototype.preview_asset(), "The medical lab's preview is missing")

	// The menu is code only
	var/list/expected = list("tend", "wounds", "shrapnel", "filter", "organs", "brain", "limb")
	var/list/menu = list()
	for(var/procedure_id in GLOB.outpost_autosurgeon_procedures)
		menu += procedure_id
	TEST_ASSERT_EQUAL(jointext(menu, ","), jointext(expected, ","), "The auto-surgeon menu changed")

	for(var/rotation in list(0, 90, 180, 270))
		var/datum/outpost_upgrade/service/medical_lab/lab = medlab_test_lab("medlabroom[rotation]", rotation)
		if(!lab)
			return
		var/obj/structure/overmap/dynamic/player_outpost/home = lab.outpost
		TEST_ASSERT(lab.installed_area && lab.installed_area != home.outpost_area, "The lab did not get an area of its own at [rotation]")
		TEST_ASSERT_NOTNULL(medlab_find(lab, /obj/machinery/outpost_autosurgeon), "No slab at [rotation]")
		TEST_ASSERT_NOTNULL(medlab_find(lab, /obj/machinery/computer/outpost_medlab_terminal), "No pass terminal at [rotation]")
		TEST_ASSERT_EQUAL(length(medlab_find_all(lab, /obj/machinery/sleeper/outpost/medical_lab)), 2, "Wrong sleeper count at [rotation]")
		var/obj/machinery/computer/outpost_autosurgeon/console = medlab_find(lab, /obj/machinery/computer/outpost_autosurgeon)
		TEST_ASSERT_NOTNULL(console, "No slab console at [rotation]")
		TEST_ASSERT_NOTNULL(console.find_slab(), "The slab console cannot find its slab at [rotation]")

		// Doors open from inside and answer to no controller
		var/inward = turn(lab.rotated_entrance(rotation), 180)
		for(var/obj/machinery/door/airlock/outpost/service/door as anything in medlab_find_all(lab, /obj/machinery/door/airlock/outpost/service))
			TEST_ASSERT(door.unres_sides & inward, "The lab door's open side does not point inside at [rotation]")
			TEST_ASSERT_NULL(door.id_tag, "The lab door has an id_tag at [rotation]")
		for(var/obj/fixture as anything in medlab_find_all(lab, /obj/machinery) + medlab_find_all(lab, /obj/structure))
			if(istype(fixture, /obj/structure/cable))
				continue
			TEST_ASSERT(HAS_TRAIT(fixture, "outpost_property"), "[fixture] is not outpost property at [rotation]")
			if(isstructure(fixture))
				TEST_ASSERT(fixture.anchored, "[fixture] is not anchored at [rotation]")

		// The loop: both canisters on their ports, both cells on the freezer's pipeline with gas
		var/obj/machinery/atmospherics/components/unary/thermomachine/freezer/on/outpost_lab/freezer = medlab_find(lab, /obj/machinery/atmospherics/components/unary/thermomachine/freezer/on/outpost_lab)
		TEST_ASSERT_NOTNULL(freezer, "No lab freezer at [rotation]")
		var/datum/pipeline/loop = freezer.parents[1]
		TEST_ASSERT_NOTNULL(loop, "The freezer has no pipeline at [rotation]")
		for(var/obj/machinery/portable_atmospherics/canister/canister as anything in medlab_find_all(lab, /obj/machinery/portable_atmospherics/canister))
			TEST_ASSERT_NOTNULL(canister.connected_port, "[canister] is not on its port at [rotation]")
		var/obj/machinery/portable_atmospherics/canister/anesthetic_mix/outpost_lab/supply = medlab_find(lab, /obj/machinery/portable_atmospherics/canister/anesthetic_mix/outpost_lab)
		TEST_ASSERT_EQUAL(supply?.connected_port?.parents[1], loop, "The anaesthetic supply is not on the freezer's pipeline at [rotation]")
		var/list/cells = medlab_find_all(lab, /obj/machinery/cryo_cell/outpost_lab)
		TEST_ASSERT_EQUAL(length(cells), 2, "Wrong cryo cell count at [rotation]")
		for(var/obj/machinery/cryo_cell/outpost_lab/cell as anything in cells)
			var/obj/machinery/atmospherics/components/unary/connector_node = cell.internal_connector.gas_connector
			TEST_ASSERT_EQUAL(connector_node.parents[1], loop, "A cryo cell is not on the loop at [rotation]")
			var/datum/gas_mixture/cell_air = connector_node.airs[1]
			TEST_ASSERT(cell_air.total_moles() > 5, "A cryo cell has [cell_air.total_moles()] moles at [rotation]")
			TEST_ASSERT(cell.has_cryoxadone(), "A cryo cell has no cryoxadone at [rotation]")

		// A sleeping, chilled member in a cell takes up cryoxadone
		var/obj/machinery/cryo_cell/outpost_lab/cell = cells[1]
		var/mob/living/carbon/human/patient = make_market_visitor(medlab_open_beside(cell), "medlabroom[rotation]", 0)
		patient.adjustBruteLoss(40)
		patient.SetSleeping(60 SECONDS)
		patient.bodytemperature = T0C - 60
		cell.close_machine(patient)
		TEST_ASSERT_EQUAL(cell.occupant, patient, "A member could not be closed in a cryo cell at [rotation]")
		for(var/i in 1 to 4)
			cell.process(2)
		TEST_ASSERT(patient.reagents.has_reagent(/datum/reagent/medicine/cryoxadone), "The cryo cell gave no cryoxadone at [rotation]")
		// Opening a running cell switches it off; the switch-off used to eject again, recursing until the server crashed
		cell.open_machine()
		TEST_ASSERT(cell.state_open && !cell.on, "Opening the cryo cell left it closed or running at [rotation]")
		TEST_ASSERT_NULL(cell.occupant, "Opening the cryo cell kept its patient at [rotation]")
		TEST_ASSERT(patient.loc != cell, "The patient stayed inside the opened cryo cell at [rotation]")
		// A power cut with a patient inside lets them out once
		cell.close_machine(patient)
		TEST_ASSERT(cell.on && cell.occupant == patient, "The cryo cell would not close on the patient again at [rotation]")
		cell.set_machine_stat(cell.machine_stat | NOPOWER)
		TEST_ASSERT(cell.state_open && !cell.on && isnull(cell.occupant), "A power cut did not let the patient out at [rotation]")
		cell.set_machine_stat(cell.machine_stat & ~NOPOWER)
		settle_room_air(lab.room_turfs())

// ===== PASSES =====

/datum/unit_test/voidcrew_outpost_medical_lab_pass
	parent_type = /datum/unit_test/voidcrew_outpost_management

/datum/unit_test/voidcrew_outpost_medical_lab_pass/Run()
	var/datum/outpost_upgrade/service/medical_lab/lab = medlab_test_lab("medlabpassowner")
	if(!lab)
		return
	var/obj/structure/overmap/dynamic/player_outpost/home = lab.outpost
	var/turf/inside = get_turf(medlab_find(lab, /obj/machinery/computer/outpost_medlab_terminal))
	var/mob/living/carbon/human/owner = make_player(inside, "medlabpassowner")
	var/mob/living/carbon/human/visitor = make_market_visitor(inside, "medlabpassvisitor", 1000)
	var/datum/bank_account/account = visitor.get_idcard(TRUE).registered_account
	var/treasury_before = home.treasury.account_balance

	TEST_ASSERT(!lab.has_lab_access(visitor), "A visitor had lab access without a pass")
	TEST_ASSERT(lab.has_lab_access(owner), "The owner needs a pass")
	TEST_ASSERT_NOTNULL(lab.sell_pass(owner, list(owner), 0), "The owner was sold a pass")

	// Nothing to treat: no sale (F-30)
	TEST_ASSERT_NOTNULL(lab.pass_denial(visitor), "An unhurt visitor could buy a pass")
	TEST_ASSERT_NOTNULL(lab.sell_pass(visitor, list(visitor), 300), "An unhurt visitor was sold a pass")
	visitor.adjustBruteLoss(30)

	// Price race: the shown price must be the price
	TEST_ASSERT_NOTNULL(lab.sell_pass(visitor, list(visitor), 250), "A pass sold at a stale price")
	TEST_ASSERT_EQUAL(account.account_balance, 1000, "A refused sale moved money")

	TEST_ASSERT_NULL(lab.sell_pass(visitor, list(visitor), 300), "A visitor could not buy a pass")
	TEST_ASSERT_EQUAL(account.account_balance, 700, "The pass was not charged exactly once")
	TEST_ASSERT_EQUAL(home.treasury.account_balance, treasury_before + 300, "The treasury was not paid once")
	TEST_ASSERT(lab.has_lab_access(visitor), "The paid pass gave no access")
	TEST_ASSERT_EQUAL(lab.pass_seconds_left(visitor), 1800, "The pass does not last 30 minutes")
	TEST_ASSERT_NOTNULL(lab.sell_pass(visitor, list(visitor), 300), "A second pass sold while the first is fresh")
	TEST_ASSERT_EQUAL(account.account_balance, 700, "A refused second pass moved money")

	// A pass holder reaches the lab whatever its entrance is keyed to; a visitor with no pass does not
	var/obj/machinery/door/airlock/outpost/service/entrance
	for(var/obj/machinery/door/airlock/outpost/service/lab_door as anything in medlab_find_all(lab, /obj/machinery/door/airlock/outpost/service))
		if(lab_door.door_policy == "public")
			entrance = lab_door
	TEST_ASSERT_NOTNULL(entrance, "The lab has no entrance")
	var/turf/entrance_outside = get_step(entrance, turn(entrance.unres_sides, 180))
	home.apply_door_access(entrance, "owner")
	visitor.forceMove(entrance_outside)
	var/mob/living/carbon/human/stranger = make_market_visitor(entrance_outside, "medlabpassstranger", 0)
	TEST_ASSERT(entrance.allowed(visitor), "An owner-only lab entrance refused a pass holder")
	TEST_ASSERT(!entrance.allowed(stranger), "An owner-only lab entrance let in a visitor with no pass")
	home.apply_door_access(entrance, "public")
	visitor.forceMove(inside)

	// Expiry
	var/list/entry = lab.passes[lab.pass_key(visitor)]
	entry["expiry"] = world.time - 1
	TEST_ASSERT(!lab.has_lab_access(visitor), "An expired pass still gave access")

	// Pay for both, and members cannot buy for visitors
	var/mob/living/carbon/human/friend = make_market_visitor(inside, "medlabpassfriend", 0)
	friend.adjustFireLoss(20)
	TEST_ASSERT_NOTNULL(lab.sell_pass(owner, list(friend), 0), "A member handed out a free pass")
	TEST_ASSERT_NULL(lab.sell_pass(visitor, list(visitor, friend), 300), "A visitor could not pay for both")
	TEST_ASSERT_EQUAL(account.account_balance, 100, "Paying for both did not charge twice")
	TEST_ASSERT(lab.has_lab_access(friend), "The friend's pass gave no access")

	// Short of money: no pass
	var/mob/living/carbon/human/broke = make_market_visitor(inside, "medlabpassbroke", 100)
	broke.adjustBruteLoss(10)
	TEST_ASSERT_NOTNULL(lab.sell_pass(broke, list(broke), 300), "A pass sold without the money")
	TEST_ASSERT(!lab.has_lab_access(broke), "A refused charge still gave a pass")

	// Ownerless: free for everyone
	home.founder_ckey = null
	TEST_ASSERT(lab.has_lab_access(broke), "An ownerless lab charged a visitor")
	home.founder_ckey = "medlabpassowner"

	// Every procedure is always on offer: the console has no lab settings
	TEST_ASSERT_NULL(lab.service_ui_data(owner), "The lab still has settings on the console")

// ===== AUTO-SURGEON =====

/datum/unit_test/voidcrew_outpost_medical_lab_autosurgeon
	parent_type = /datum/unit_test/voidcrew_outpost_management

/datum/unit_test/voidcrew_outpost_medical_lab_autosurgeon/Run()
	var/datum/outpost_upgrade/service/medical_lab/lab = medlab_test_lab("medlabslabowner")
	if(!lab)
		return
	var/obj/machinery/outpost_autosurgeon/medlab_test/slab = medlab_test_slab(lab)
	TEST_ASSERT_NOTNULL(slab, "The lab has no slab")
	TEST_ASSERT(slab.is_operational, "The test slab has no power")
	TEST_ASSERT(!(slab.datum_flags & DF_ISPROCESSING), "An idle slab is processing")
	var/turf/beside = medlab_open_beside(slab)
	make_player(beside, "medlabslabowner")
	var/mob/living/carbon/human/patient = make_market_visitor(beside, "medlabslabpatient", 0)
	var/mob/living/carbon/human/bystander = make_market_visitor(beside, "medlabslabbystander", 0)
	// All on one limb: a tend cycle, like tg's, heals one damaged limb, so spread damage heals less than the formula
	var/obj/item/bodypart/hurt_chest = patient.get_bodypart(BODY_ZONE_CHEST)
	hurt_chest.receive_damage(50, wound_bonus = CANT_WOUND)
	TEST_ASSERT_EQUAL(patient.getBruteLoss(), 50, "The patient did not take 50 brute on the chest")

	// No pass: refused, and anyone may take a no-pass occupant off (F-31)
	medlab_lie_down(slab, patient)
	TEST_ASSERT_EQUAL(slab.occupant, patient, "The patient did not lie on the slab")
	TEST_ASSERT_NOTNULL(slab.start_procedure(patient, "tend"), "A run started without a pass")
	TEST_ASSERT_NULL(slab.unbuckle_denial(bystander), "A no-pass occupant could not be taken off")
	lab.grant_pass(patient)
	slab.idle_since = world.time
	TEST_ASSERT_NOTNULL(slab.unbuckle_denial(bystander), "A bystander could take a fresh pass holder off")
	slab.idle_since = world.time - 61 SECONDS
	TEST_ASSERT_NULL(slab.unbuckle_denial(bystander), "An occupant idle for a minute could not be taken off")
	slab.idle_since = world.time

	// Consent rules, one at a time
	TEST_ASSERT_NOTNULL(slab.start_procedure(bystander, "tend"), "A bystander started a run on the occupant")
	ADD_TRAIT(patient, TRAIT_RESTRAINED, "medlab_test")
	TEST_ASSERT_NOTNULL(slab.start_procedure(patient, "tend"), "A restrained patient started a run")
	REMOVE_TRAIT(patient, TRAIT_RESTRAINED, "medlab_test")
	bystander.start_pulling(patient)
	bystander.setGrabState(GRAB_AGGRESSIVE)
	TEST_ASSERT_NOTNULL(slab.start_procedure(patient, "tend"), "A patient held down started a run")
	bystander.stop_pulling()
	slab.absent += patient
	TEST_ASSERT_NOTNULL(slab.start_procedure(patient, "tend"), "An unplayed patient started a run")
	slab.absent -= patient
	patient.SetSleeping(10 SECONDS)
	TEST_ASSERT_NOTNULL(slab.start_procedure(patient, "tend"), "A sleeping patient started a run")
	patient.SetSleeping(0)
	patient.set_stat(CONSCIOUS)
	var/datum/fake_surgery = allocate(/datum)
	LAZYADD(patient.surgeries, fake_surgery)
	TEST_ASSERT_NOTNULL(slab.start_procedure(patient, "tend"), "A run started over an open surgery")
	LAZYREMOVE(patient.surgeries, fake_surgery)
	slab.set_machine_stat(slab.machine_stat | NOPOWER)
	TEST_ASSERT_NOTNULL(slab.start_procedure(patient, "tend"), "An unpowered slab started a run")
	slab.set_machine_stat(slab.machine_stat & ~NOPOWER)
	TEST_ASSERT_NOTNULL(slab.start_procedure(patient, 1), "A numeric procedure id was accepted")
	TEST_ASSERT_NOTNULL(slab.start_procedure(patient, "amputate"), "An unknown procedure was accepted")

	// Tend: the tg basic formula per cycle, analgesia during the run
	TEST_ASSERT_NULL(slab.start_procedure(patient, "tend"), "A valid patient could not start tend")
	TEST_ASSERT(slab.datum_flags & DF_ISPROCESSING, "A running slab is not processing")
	TEST_ASSERT(HAS_TRAIT(patient, TRAIT_ANALGESIA), "No analgesia during a run")
	TEST_ASSERT_NOTNULL(slab.start_procedure(patient, "tend"), "A second run started over the first")
	TEST_ASSERT_NOTNULL(slab.unbuckle_denial(bystander), "A bystander could stop a running procedure")
	slab.process(2.5)
	TEST_ASSERT(abs(patient.getBruteLoss() - 41.5) < 0.2, "One tend cycle left [patient.getBruteLoss()] brute, expected 41.5")

	// Getting up stops it and keeps the healing
	slab.unbuckle_mob(patient)
	TEST_ASSERT_NULL(slab.run, "Getting up did not stop the run")
	TEST_ASSERT(!HAS_TRAIT(patient, TRAIT_ANALGESIA), "Analgesia outlived the run")
	TEST_ASSERT(abs(patient.getBruteLoss() - 41.5) < 0.2, "Stopping a run undid its healing")
	TEST_ASSERT(!(slab.datum_flags & DF_ISPROCESSING), "A stopped slab kept processing")

	// Power loss stops a run and keeps the healing
	medlab_lie_down(slab, patient)
	TEST_ASSERT_NULL(slab.start_procedure(patient, "tend"), "Tend could not restart")
	slab.process(2.5)
	var/brute_after_cycle = patient.getBruteLoss()
	slab.set_machine_stat(slab.machine_stat | NOPOWER)
	TEST_ASSERT_NULL(slab.run, "Power loss did not stop the run")
	TEST_ASSERT_EQUAL(patient.getBruteLoss(), brute_after_cycle, "Power loss changed the patient")
	slab.set_machine_stat(slab.machine_stat & ~NOPOWER)

	// A full tend run heals everything
	TEST_ASSERT_NULL(slab.start_procedure(patient, "tend"), "Tend could not restart after power came back")
	TEST_ASSERT(medlab_run_out(slab), "Tend never finished")
	TEST_ASSERT_EQUAL(patient.getBruteLoss(), 0, "A full tend run left brute damage")

	// Organs are atomic: a stopped run changes nothing, a finished one repairs to tg's value
	patient.setOrganLoss(ORGAN_SLOT_HEART, 80)
	TEST_ASSERT_NULL(slab.start_procedure(patient, "organs"), "Organ repair did not start")
	slab.process(2)
	slab.stop_run("test stop")
	TEST_ASSERT_EQUAL(patient.get_organ_loss(ORGAN_SLOT_HEART), 80, "A stopped organ run changed the heart")
	TEST_ASSERT_NULL(slab.start_procedure(patient, "organs"), "Organ repair did not restart")
	TEST_ASSERT(medlab_run_out(slab), "Organ repair never finished")
	TEST_ASSERT_EQUAL(patient.get_organ_loss(ORGAN_SLOT_HEART), 60, "The heart was not set to 60")
	var/obj/item/organ/heart/heart = patient.get_organ_slot(ORGAN_SLOT_HEART)
	TEST_ASSERT(heart.operated, "The heart was not marked operated")

	// Brain: 50 a cycle, kept when stopped
	patient.setOrganLoss(ORGAN_SLOT_BRAIN, 120)
	TEST_ASSERT_NULL(slab.start_procedure(patient, "brain"), "Brain repair did not start")
	slab.process(10)
	slab.stop_run("test stop")
	TEST_ASSERT_EQUAL(patient.get_organ_loss(ORGAN_SLOT_BRAIN), 70, "A stopped brain run did not keep its cycle")
	TEST_ASSERT_NULL(slab.start_procedure(patient, "brain"), "Brain repair did not restart")
	TEST_ASSERT(medlab_run_out(slab), "Brain repair never finished")
	TEST_ASSERT_EQUAL(patient.get_organ_loss(ORGAN_SLOT_BRAIN), 0, "Brain repair left damage")

	// Filter blood
	patient.reagents.add_reagent(/datum/reagent/toxin, 20)
	TEST_ASSERT_NULL(slab.start_procedure(patient, "filter"), "Filter did not start")
	slab.process(2.5)
	TEST_ASSERT(patient.reagents.get_reagent_amount(/datum/reagent/toxin) < 20, "Filtering removed nothing")
	TEST_ASSERT(medlab_run_out(slab), "Filter never finished")

	// Wounds and shrapnel
	var/obj/item/bodypart/chest = patient.get_bodypart(BODY_ZONE_CHEST)
	var/datum/wound/blunt/bone/severe/fracture = new
	fracture.apply_wound(chest)
	TEST_ASSERT(LAZYLEN(patient.all_wounds), "The test wound did not apply")
	TEST_ASSERT_NULL(slab.start_procedure(patient, "wounds"), "Treat wounds did not start")
	TEST_ASSERT(medlab_run_out(slab), "Treat wounds never finished")
	TEST_ASSERT(!LAZYLEN(patient.all_wounds), "Treat wounds left a wound")
	var/obj/item/throwing_star/star = allocate(/obj/item/throwing_star)
	star.force_embed(patient, chest)
	if(length(chest.embedded_objects))
		TEST_ASSERT_NULL(slab.start_procedure(patient, "shrapnel"), "Remove shrapnel did not start")
		TEST_ASSERT(medlab_run_out(slab), "Remove shrapnel never finished")
		TEST_ASSERT(!length(chest.embedded_objects), "Remove shrapnel left an object")

	// Limbs: healed before attaching, no rejection damage; implants refused (F-29)
	var/obj/item/bodypart/arm/left/arm = patient.get_bodypart(BODY_ZONE_L_ARM)
	patient.apply_damage(20, BRUTE, BODY_ZONE_L_ARM, wound_bonus = CANT_WOUND)
	arm.drop_limb()
	TEST_ASSERT(arm.brute_dam > 0, "The loose test arm carries no damage")
	// put_in_hands() tries the missing left hand and gives up, so hold it in the right one
	TEST_ASSERT(patient.put_in_r_hand(arm), "The patient could not hold the loose arm")
	var/health_before = patient.health
	var/tox_before = patient.getToxLoss()
	TEST_ASSERT_NULL(slab.start_procedure(patient, "limb"), "Reattach limb did not start")
	TEST_ASSERT(medlab_run_out(slab), "Reattach limb never finished")
	TEST_ASSERT_EQUAL(patient.get_bodypart(BODY_ZONE_L_ARM), arm, "The arm was not reattached")
	TEST_ASSERT(patient.health >= health_before, "Reattaching a limb hurt the patient")
	TEST_ASSERT_EQUAL(patient.getToxLoss(), tox_before, "Reattaching a limb added toxin damage")
	arm.drop_limb()
	var/obj/item/organ/implant = allocate(/obj/item/organ/heart)
	implant.forceMove(arm)
	TEST_ASSERT(patient.put_in_r_hand(arm), "The patient could not hold the implanted arm")
	var/datum/autosurgeon_procedure/limb_procedure = GLOB.outpost_autosurgeon_procedures["limb"]
	var/implant_refusal = limb_procedure.unavailable_reason(patient)
	TEST_ASSERT(findtext(implant_refusal, "implants"), "A limb with an implant inside was offered: [implant_refusal]")
	TEST_ASSERT_NOTNULL(slab.start_procedure(patient, "limb"), "A limb with an implant inside was attached")

	// No procedure ever leaves a tg surgery open
	TEST_ASSERT(!LAZYLEN(patient.surgeries), "The slab left a surgery open")

	slab.unbuckle_mob(patient)

/// Every procedure only heals: no stage lowers health, removes a part or leaves a surgery open
/datum/unit_test/voidcrew_outpost_medical_lab_harmless

/datum/unit_test/voidcrew_outpost_medical_lab_harmless/Run()
	var/mob/living/carbon/human/healthy = allocate(/mob/living/carbon/human/consistent, run_loc_floor_bottom_left)
	for(var/procedure_id in GLOB.outpost_autosurgeon_procedures)
		var/datum/autosurgeon_procedure/procedure = GLOB.outpost_autosurgeon_procedures[procedure_id]
		TEST_ASSERT_NOTNULL(procedure.unavailable_reason(healthy), "[procedure_id] is offered to an unhurt patient")
	var/mob/living/carbon/human/hurt = allocate(/mob/living/carbon/human/consistent, run_loc_floor_bottom_left)
	hurt.adjustBruteLoss(60)
	hurt.adjustFireLoss(30)
	hurt.setOrganLoss(ORGAN_SLOT_LIVER, 70)
	hurt.setOrganLoss(ORGAN_SLOT_BRAIN, 80)
	hurt.reagents.add_reagent(/datum/reagent/medicine/c2/libital, 10)
	for(var/procedure_id in GLOB.outpost_autosurgeon_procedures)
		var/datum/autosurgeon_procedure/procedure = GLOB.outpost_autosurgeon_procedures[procedure_id]
		if(procedure.unavailable_reason(hurt))
			continue
		var/datum/autosurgeon_run/run = allocate(/datum/autosurgeon_run)
		run.procedure = procedure
		var/parts_before = length(hurt.bodyparts)
		var/organs_before = length(hurt.organs)
		for(var/i in 1 to 80)
			if(!procedure.next_stage(run, hurt))
				break
			var/health_before = hurt.health
			procedure.complete_stage(run, hurt)
			run.cycles++
			TEST_ASSERT(hurt.health >= health_before, "[procedure_id] lowered health from [health_before] to [hurt.health]")
		procedure.finish(run, hurt)
		TEST_ASSERT(length(hurt.bodyparts) >= parts_before, "[procedure_id] removed a bodypart")
		TEST_ASSERT(length(hurt.organs) >= organs_before, "[procedure_id] removed an organ")
		TEST_ASSERT(!LAZYLEN(hurt.surgeries), "[procedure_id] left a surgery open")

// ===== SLEEPERS, CRYO AND THE LOOP =====

/datum/unit_test/voidcrew_outpost_medical_lab_machines
	parent_type = /datum/unit_test/voidcrew_outpost_management

/datum/unit_test/voidcrew_outpost_medical_lab_machines/Run()
	var/datum/outpost_upgrade/service/medical_lab/lab = medlab_test_lab("medlabkitowner")
	if(!lab)
		return
	var/turf/inside = get_turf(medlab_find(lab, /obj/machinery/computer/outpost_medlab_terminal))
	var/mob/living/carbon/human/owner = make_player(inside, "medlabkitowner")
	var/mob/living/carbon/human/visitor = make_market_visitor(inside, "medlabkitvisitor", 0)
	var/mob/living/carbon/human/patient = make_market_visitor(inside, "medlabkitpatient", 0)
	patient.adjustBruteLoss(30)

	// Lab sleeper: no morphine; only the occupant or a member injects, only with a pass; no emag
	var/obj/machinery/sleeper/outpost/medical_lab/sleeper = medlab_find(lab, /obj/machinery/sleeper/outpost/medical_lab)
	TEST_ASSERT(!(/datum/reagent/medicine/morphine in sleeper.available_chems), "The lab sleeper offers morphine")
	TEST_ASSERT(length(sleeper.available_chems), "The lab sleeper offers nothing")
	patient.forceMove(get_turf(sleeper))
	sleeper.close_machine(patient)
	TEST_ASSERT_EQUAL(sleeper.occupant, patient, "The patient did not get into the sleeper")
	var/chem = /datum/reagent/medicine/c2/libital
	TEST_ASSERT(!sleeper.inject_chem(chem, patient), "A patient without a pass injected")
	lab.grant_pass(patient)
	TEST_ASSERT(!sleeper.inject_chem(chem, visitor), "A visitor injected into the occupant")
	TEST_ASSERT(sleeper.inject_chem(chem, patient), "The occupant could not inject with a pass")
	TEST_ASSERT(sleeper.inject_chem(/datum/reagent/medicine/c2/aiuri, owner), "A member could not inject")
	TEST_ASSERT(!sleeper.emag_act(visitor), "The lab sleeper took an emag")
	// F-28: a visitor's alt-click neither opens nor closes it
	sleeper.click_alt(visitor)
	TEST_ASSERT(!sleeper.state_open, "A visitor opened the sleeper on its occupant")
	sleeper.click_alt(patient)
	TEST_ASSERT(sleeper.state_open, "The occupant could not get out")
	sleeper.click_alt(visitor)
	TEST_ASSERT(sleeper.state_open, "A visitor closed the sleeper")

	// Lab cryo: no pass, no stay
	var/obj/machinery/cryo_cell/outpost_lab/cell = medlab_find(lab, /obj/machinery/cryo_cell/outpost_lab)
	var/mob/living/carbon/human/unpaid = make_market_visitor(medlab_open_beside(cell), "medlabkitunpaid", 0)
	unpaid.adjustBruteLoss(10)
	cell.close_machine(unpaid)
	TEST_ASSERT(cell.state_open && !cell.occupant, "A patient without a pass stayed in the cryo cell")
	var/datum/tgui/cell_ui = allocate(/datum/tgui, owner, cell, "Cryo")
	cell.ui_act("autoeject", list(), cell_ui, GLOB.default_state)
	TEST_ASSERT(cell.autoeject, "Autoeject was switched off")
	// Self entry
	patient.forceMove(medlab_open_beside(cell))
	cell.self_enter(patient)
	TEST_ASSERT_EQUAL(cell.occupant, patient, "A conscious patient could not climb into the cell")
	// F-28: visitors cannot switch it off or open it on the patient
	cell.click_ctrl(visitor)
	TEST_ASSERT(cell.on, "A visitor switched the cryo cell off")
	cell.click_alt(visitor)
	TEST_ASSERT(!cell.state_open, "A visitor opened the cryo cell on its patient")
	// Switch-off ejects
	cell.click_ctrl(owner)
	TEST_ASSERT(cell.state_open && !cell.occupant, "Switching the cell off did not eject its patient")
	// The time limit ejects
	cell.close_machine(patient)
	TEST_ASSERT_EQUAL(cell.occupant, patient, "The patient could not get back in")
	cell.entered_at = world.time - 11 MINUTES
	cell.process(2)
	TEST_ASSERT(cell.state_open && !cell.occupant, "The cell kept its patient past the time limit")
	// The occupant opens their own cell
	cell.close_machine(patient)
	cell.click_alt(patient)
	TEST_ASSERT(cell.state_open, "The occupant could not open their own cell")
	// Beakers are members only
	var/obj/item/reagent_containers/cup/beaker/spare = allocate(/obj/item/reagent_containers/cup/beaker)
	visitor.put_in_hands(spare)
	var/obj/item/old_beaker = cell.beaker
	TEST_ASSERT_EQUAL(cell.item_interaction(visitor, spare), ITEM_INTERACT_BLOCKING, "A visitor could use a beaker on the cell")
	TEST_ASSERT_EQUAL(cell.beaker, old_beaker, "A visitor changed the cell's beaker")
	cell.ui_act("eject", list(), allocate(/datum/tgui, visitor, cell, "Cryo"), GLOB.default_state)
	TEST_ASSERT_EQUAL(cell.beaker, old_beaker, "A visitor took the cell's beaker")

	// F-28: the loop answers to members only
	var/obj/machinery/atmospherics/components/unary/thermomachine/freezer/on/outpost_lab/freezer = medlab_find(lab, /obj/machinery/atmospherics/components/unary/thermomachine/freezer/on/outpost_lab)
	var/was_on = freezer.on
	var/old_target = freezer.target_temperature
	freezer.click_ctrl(visitor)
	freezer.click_alt(visitor)
	TEST_ASSERT_EQUAL(freezer.on, was_on, "A visitor switched the freezer")
	TEST_ASSERT_EQUAL(freezer.target_temperature, old_target, "A visitor changed the freezer's temperature")
	TEST_ASSERT(freezer.ui_status(visitor, GLOB.default_state) <= UI_UPDATE, "A visitor can work the freezer's window")
	freezer.click_ctrl(owner)
	TEST_ASSERT_NOTEQUAL(freezer.on, was_on, "A member could not switch the freezer")
	freezer.click_ctrl(owner)
	var/obj/machinery/atmospherics/components/trinary/filter/atmos/co2/outpost_lab/filter = medlab_find(lab, /obj/machinery/atmospherics/components/trinary/filter/atmos/co2/outpost_lab)
	var/filter_on = filter.on
	var/old_rate = filter.transfer_rate
	filter.transfer_rate = old_rate / 2
	filter.click_ctrl(visitor)
	filter.click_alt(visitor)
	TEST_ASSERT_EQUAL(filter.on, filter_on, "A visitor switched the filter")
	TEST_ASSERT_EQUAL(filter.transfer_rate, old_rate / 2, "A visitor changed the filter's rate")
	filter.transfer_rate = old_rate
	for(var/obj/machinery/portable_atmospherics/canister/canister as anything in medlab_find_all(lab, /obj/machinery/portable_atmospherics/canister))
		TEST_ASSERT(canister.ui_status(visitor, GLOB.default_state) <= UI_UPDATE, "A visitor can work [canister]'s window")
		var/obj/item/tank/internals/oxygen/tank = allocate(/obj/item/tank/internals/oxygen)
		visitor.put_in_hands(tank)
		canister.attackby(tank, visitor)
		TEST_ASSERT_NULL(canister.holding, "A visitor put a tank in [canister]")
	settle_room_air(lab.room_turfs())

// ===== THE LOOP STAYS SEALED (abuse review B-02, B-03, B-25) =====

/datum/unit_test/voidcrew_outpost_medical_lab_loop_seal
	parent_type = /datum/unit_test/voidcrew_outpost_management

/datum/unit_test/voidcrew_outpost_medical_lab_loop_seal/Run()
	var/datum/outpost_upgrade/service/medical_lab/lab = medlab_test_lab("medlabsealowner")
	if(!lab)
		return
	var/turf/inside = get_turf(medlab_find(lab, /obj/machinery/computer/outpost_medlab_terminal))
	var/mob/living/carbon/human/visitor = make_market_visitor(inside, "medlabsealvisitor", 0)
	var/obj/machinery/atmospherics/components/trinary/filter/atmos/co2/outpost_lab/filter = medlab_find(lab, /obj/machinery/atmospherics/components/trinary/filter/atmos/co2/outpost_lab)
	var/obj/machinery/atmospherics/pipe/smart/pipe = medlab_find(lab, /obj/machinery/atmospherics/pipe/smart)
	TEST_ASSERT_NOTNULL(filter, "The lab has no CO2 filter")
	TEST_ASSERT_NOTNULL(pipe, "The lab has no loop pipe")

	// B-02: the RPD's unwrench upgrade and the console's Remove Pipe both go through can_unwrench()
	var/obj/item/pipe_dispenser/rpd = allocate(/obj/item/pipe_dispenser)
	rpd.upgrade_flags |= RPD_UPGRADE_UNWRENCH
	visitor.put_in_hands(rpd)
	filter.on = FALSE
	for(var/obj/machinery/atmospherics/part as anything in list(filter, pipe))
		var/turf/was_at = part.loc
		TEST_ASSERT(!part.can_unwrench(visitor), "[part] can be unwrenched")
		part.wrench_act(visitor, rpd)
		TEST_ASSERT(!QDELETED(part), "An RPD unwrenched [part]")
		TEST_ASSERT_EQUAL(part.loc, was_at, "An RPD moved [part]")
		TEST_ASSERT_EQUAL(SEND_SIGNAL(part, COMSIG_ATOM_ITEM_INTERACTION, visitor, rpd, list()), ITEM_INTERACT_BLOCKING, "An RPD click on [part] was not refused")
	filter.on = TRUE

	// B-03: every loop pipe is locked to the links it had at install
	for(var/obj/machinery/atmospherics/pipe/smart/loop_pipe as anything in medlab_find_all(lab, /obj/machinery/atmospherics/pipe/smart))
		var/linked = NONE
		for(var/obj/machinery/atmospherics/node as anything in loop_pipe.nodes)
			if(node)
				linked |= get_dir(loop_pipe, node)
		TEST_ASSERT_EQUAL(loop_pipe.initialize_directions, linked, "The loop pipe at [loop_pipe.x],[loop_pipe.y] still links on its free sides")

	// B-03: a vent wrenched down beside a loop pipe, facing it, does not join the loop
	var/list/room = lab.room_turfs()
	var/obj/machinery/atmospherics/pipe/smart/tapped
	var/turf/open/tap_spot
	for(var/obj/machinery/atmospherics/pipe/smart/loop_pipe as anything in medlab_find_all(lab, /obj/machinery/atmospherics/pipe/smart))
		for(var/direction in GLOB.cardinals)
			if(loop_pipe.initialize_directions & direction)
				continue
			var/turf/open/spot = get_step(loop_pipe, direction)
			if(!istype(spot) || !(spot in room) || (locate(/obj/machinery/atmospherics) in spot))
				continue
			tapped = loop_pipe
			tap_spot = spot
			break
		if(tapped)
			break
	TEST_ASSERT_NOTNULL(tap_spot, "No free tile beside a loop pipe to test a tap on")
	var/obj/machinery/atmospherics/components/unary/passive_vent/tap = allocate(/obj/machinery/atmospherics/components/unary/passive_vent, tap_spot, TRUE, get_dir(tap_spot, tapped))
	tap.atmos_init()
	TEST_ASSERT_NULL(tap.nodes[1], "A visitor's vent linked to the lab loop")
	TEST_ASSERT(!(tap in tapped.nodes), "The lab loop took a visitor's vent as a node")
	TEST_ASSERT(tap.parents[1] != tapped.parent, "A visitor's vent joined the lab loop's pipeline")

	// B-25: every lab canister is bolted down
	for(var/obj/machinery/portable_atmospherics/canister/canister as anything in medlab_find_all(lab, /obj/machinery/portable_atmospherics/canister))
		TEST_ASSERT(canister.anchored, "[canister] is not bolted down")
