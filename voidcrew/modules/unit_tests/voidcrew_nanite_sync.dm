/// A host over neural capacity still takes cloud removals and settings, and only the additions that fit.
/datum/unit_test/voidcrew_nanite_overcapacity_sync

/datum/unit_test/voidcrew_nanite_overcapacity_sync/Run()
	var/mob/living/carbon/human/patient = allocate(/mob/living/carbon/human/consistent)
	var/obj/item/organ/cyberimp/cyberware/governor_delete/governor = allocate(/obj/item/organ/cyberimp/cyberware/governor_delete)
	var/obj/item/organ/cyberimp/cyberware/test_heavy/heavy = allocate(/obj/item/organ/cyberimp/cyberware/test_heavy)
	governor.Insert(patient, TRUE)
	heavy.Insert(patient, TRUE)
	var/datum/component/nanites/nanites = patient.AddComponent(/datum/component/nanites)
	STOP_PROCESSING(SSnanites, nanites)
	var/datum/nanite_program/hardening/armor = allocate(/datum/nanite_program/hardening)
	var/datum/nanite_program/adrenaline/burst = allocate(/datum/nanite_program/adrenaline)
	var/datum/nanite_program/nervous/nerves = allocate(/datum/nanite_program/nervous)
	for(var/datum/nanite_program/program in list(armor, burst, nerves))
		TEST_ASSERT_EQUAL(nanites.add_program(null, program), 1, "Could not install [program] under the governor") // COMPONENT_PROGRAM_INSTALLED
	governor.Remove(patient, TRUE)
	TEST_ASSERT(get_chrome_load(patient) > get_chrome_capacity(patient), "Losing the governor didn't put the host over capacity")

	var/obj/machinery/computer/nanite_cloud_controller/controller = allocate(/obj/machinery/computer/nanite_cloud_controller)
	var/datum/nanite_cloud_backup/backup = allocate(/datum/nanite_cloud_backup, controller)
	var/datum/component/nanites/cloud = backup.AddComponent(/datum/component/nanites)
	backup.nanites = cloud
	var/datum/nanite_program/hardening/cloud_armor = allocate(/datum/nanite_program/hardening)
	var/datum/nanite_program/adrenaline/cloud_burst = allocate(/datum/nanite_program/adrenaline)
	cloud.add_program(null, cloud_armor)
	cloud.add_program(null, cloud_burst)

	// A removal that leaves the host still over capacity must go through.
	TEST_ASSERT_EQUAL(nanites.sync_programming(cloud), 2, "Over-capacity host refused a cloud removal") // NANITE_SYNC_REPLACED
	TEST_ASSERT(QDELETED(nerves), "Cloud removal didn't delete the program")
	TEST_ASSERT(get_chrome_load(patient) > get_chrome_capacity(patient), "Test setup no longer over capacity")

	// Remove another, change a setting, and add three: the costly one doesn't fit, the cheap and free ones do.
	qdel(cloud_burst)
	cloud_armor.activation_code = 7
	var/datum/nanite_program/nervous/cloud_heavy = allocate(/datum/nanite_program/nervous)
	var/datum/nanite_program/brain_heal/cloud_light = allocate(/datum/nanite_program/brain_heal)
	var/datum/nanite_program/monitoring/cloud_free = allocate(/datum/nanite_program/monitoring)
	for(var/datum/nanite_program/program in list(cloud_heavy, cloud_light, cloud_free))
		cloud.add_program(null, program)
	TEST_ASSERT_EQUAL(nanites.sync_programming(cloud), 7, "Partial sync didn't report removals, additions and refusal") // REFUSED | REPLACED | ADDED
	TEST_ASSERT(QDELETED(burst), "Partial sync kept a removed program")
	TEST_ASSERT_EQUAL(armor.activation_code, 7, "Partial sync didn't copy settings")
	TEST_ASSERT(!(locate(/datum/nanite_program/nervous) in nanites.programs), "Partial sync installed a program that doesn't fit")
	TEST_ASSERT(locate(/datum/nanite_program/brain_heal) in nanites.programs, "Partial sync refused a program that fits")
	TEST_ASSERT(locate(/datum/nanite_program/monitoring) in nanites.programs, "Partial sync refused a free program")
	TEST_ASSERT(get_chrome_load(patient) <= get_chrome_capacity(patient), "Partial sync left the host over capacity")

	// Once it fits, the refused program comes through on the next sync.
	var/datum/nanite_program/brain_heal/light = locate() in nanites.programs
	qdel(cloud_armor)
	TEST_ASSERT(nanites.sync_programming(cloud) & 1, "Freed capacity didn't admit the refused program") // NANITE_SYNC_ADDED
	TEST_ASSERT(locate(/datum/nanite_program/nervous) in nanites.programs, "Refused program never synced once it fit")
	TEST_ASSERT(QDELETED(armor), "Sync didn't remove the program dropped from the cloud")
	TEST_ASSERT(light in nanites.programs, "Resync replaced a kept program")

/// A public chamber's cloud change reaches its occupant's nanites.
/datum/unit_test/voidcrew_public_nanite_chamber_cloud

/datum/unit_test/voidcrew_public_nanite_chamber_cloud/Run()
	var/obj/machinery/public_nanite_chamber/chamber = allocate(/obj/machinery/public_nanite_chamber)
	var/mob/living/carbon/human/patient = allocate(/mob/living/carbon/human/consistent)
	var/mob/living/carbon/human/user_mob = allocate(/mob/living/carbon/human/consistent)
	var/datum/component/nanites/nanites = patient.AddComponent(/datum/component/nanites)
	STOP_PROCESSING(SSnanites, nanites)
	patient.forceMove(chamber)
	chamber.set_occupant(patient)
	chamber.cloud_id = 7
	chamber.complete_cloud_change(FALSE, user_mob)
	TEST_ASSERT_EQUAL(nanites.cloud_id, 7, "Public chamber didn't change the occupant's cloud")
	chamber.set_occupant(null)
	patient.forceMove(run_loc_floor_bottom_left)

/// Rules hold their program, so deleting either side must leave no reference behind.
/datum/unit_test/voidcrew_nanite_rule_cleanup

/datum/unit_test/voidcrew_nanite_rule_cleanup/Run()
	var/datum/nanite_program/hardening/program = new
	var/datum/nanite_rule/health/health_rule = new(program)
	var/datum/nanite_rule/crit/crit_rule = new(program)
	TEST_ASSERT_EQUAL(length(program.rules), 2, "Rules didn't register on their program")

	var/datum/nanite_program/hardening/copy = program.copy()
	TEST_ASSERT_EQUAL(length(copy.rules), 2, "Copy didn't copy the rules")
	var/datum/nanite_rule/old_copy_rule = copy.rules[1]
	TEST_ASSERT_EQUAL(old_copy_rule.program, copy, "Copied rule points at the wrong program")
	program.copy_programming(copy)
	TEST_ASSERT(QDELETED(old_copy_rule), "Reprogramming left the old rule alive")
	TEST_ASSERT_NULL(old_copy_rule.program, "Replaced rule kept its program")
	TEST_ASSERT_EQUAL(length(copy.rules), 2, "Reprogramming didn't rebuild the rules")

	qdel(crit_rule)
	TEST_ASSERT_NULL(crit_rule.program, "Deleted rule kept its program")
	TEST_ASSERT(!(crit_rule in program.rules), "Deleted rule stayed on its program")

	qdel(program)
	TEST_ASSERT(QDELETED(health_rule), "Deleting a program left its rule alive")
	TEST_ASSERT_NULL(health_rule.program, "Program's rule kept a reference to it")
	TEST_ASSERT_EQUAL(length(program.rules), 0, "Deleted program kept its rules")

	var/list/copy_rules = copy.rules.Copy()
	qdel(copy)
	for(var/datum/nanite_rule/rule as anything in copy_rules)
		TEST_ASSERT(QDELETED(rule), "Deleting a copied program left a rule alive")
		TEST_ASSERT_NULL(rule.program, "Copied program's rule kept a reference to it")

/// Cloud order decides which program a full host keeps, and the skipped one reads as not installed.
/datum/unit_test/voidcrew_nanite_cloud_order

/datum/unit_test/voidcrew_nanite_cloud_order/Run()
	var/obj/machinery/computer/nanite_cloud_controller/controller = allocate(/obj/machinery/computer/nanite_cloud_controller)
	var/datum/nanite_cloud_backup/backup = allocate(/datum/nanite_cloud_backup, controller)
	var/datum/component/nanites/cloud = backup.AddComponent(/datum/component/nanites)
	backup.nanites = cloud
	var/datum/nanite_program/nervous/cloud_nerves = allocate(/datum/nanite_program/nervous)
	var/datum/nanite_program/hardening/cloud_armor = allocate(/datum/nanite_program/hardening)
	cloud.add_program(null, cloud_nerves)
	cloud.add_program(null, cloud_armor)

	var/datum/component/nanites/first_host = make_full_host()
	first_host.sync_programming(cloud)
	TEST_ASSERT(locate(/datum/nanite_program/nervous) in first_host.programs, "First cloud program didn't install")
	TEST_ASSERT(!(locate(/datum/nanite_program/hardening) in first_host.programs), "Second cloud program installed past capacity")
	var/list/missing = first_host.get_missing_cloud_programs(cloud)
	TEST_ASSERT_EQUAL(length(missing), 1, "Not-installed list has the wrong length")
	TEST_ASSERT_EQUAL(missing[1], cloud_armor, "Not-installed list doesn't name the skipped program")

	TEST_ASSERT(!controller.move_backup_program(cloud, cloud_nerves, -1), "Moved the first program above the top")
	TEST_ASSERT(!controller.move_backup_program(cloud, cloud_armor, 1), "Moved the last program below the bottom")
	cloud_armor.activation_code = 55
	TEST_ASSERT(controller.move_backup_program(cloud, cloud_armor, -1), "Couldn't move a program up")
	TEST_ASSERT_EQUAL(cloud.programs[1], cloud_armor, "Move didn't reorder the backup")
	TEST_ASSERT_EQUAL(cloud_armor.activation_code, 55, "Move changed the program's settings")

	var/datum/component/nanites/second_host = make_full_host()
	second_host.sync_programming(cloud)
	TEST_ASSERT(locate(/datum/nanite_program/hardening) in second_host.programs, "Reordered program didn't take priority")
	TEST_ASSERT(!(locate(/datum/nanite_program/nervous) in second_host.programs), "Lower program installed past capacity")
	missing = second_host.get_missing_cloud_programs(cloud)
	TEST_ASSERT_EQUAL(length(missing), 1, "Not-installed list has the wrong length after reorder")
	TEST_ASSERT_EQUAL(missing[1], cloud_nerves, "Not-installed list doesn't name the newly skipped program")

/// A host whose chrome leaves room for one 3-load program, not two.
/datum/unit_test/voidcrew_nanite_cloud_order/proc/make_full_host()
	var/mob/living/carbon/human/patient = allocate(/mob/living/carbon/human/consistent)
	var/obj/item/organ/cyberimp/cyberware/test_heavy/heavy = allocate(/obj/item/organ/cyberimp/cyberware/test_heavy)
	heavy.Insert(patient, TRUE)
	var/datum/component/nanites/nanites = patient.AddComponent(/datum/component/nanites)
	STOP_PROCESSING(SSnanites, nanites)
	return nanites
