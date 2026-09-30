/**
 * The experimental dissection ladder must offer exactly one tier: the best one the
 * operating computer knows about. The elite tier used to inherit the base tier's
 * replaced_by, so once Advanced Dissection was known the elite tier hid itself while
 * still hiding the superior tier beneath it, and a crew that researched Elite Dissection
 * lost every dissection at once.
 */
/datum/unit_test/voidcrew_dissection_tiers

/datum/unit_test/voidcrew_dissection_tiers/Run()
	var/mob/living/carbon/human/surgeon = allocate(/mob/living/carbon/human/consistent)
	var/mob/living/carbon/human/corpse = allocate(/mob/living/carbon/human/consistent)
	var/obj/structure/table/optable/table = allocate(/obj/structure/table/optable)
	var/obj/machinery/computer/operating/computer = allocate(/obj/machinery/computer/operating)
	// The computer finds its table positionally; both sit on the same test turf, so wire
	// them directly and keep the computer powered for the whole test.
	table.computer = computer
	computer.table = table
	computer.use_power = NO_POWER_USE
	computer.machine_stat &= ~(NOPOWER | BROKEN)
	computer.advanced_surgeries = list()
	corpse.death()
	surgeon.zone_selected = BODY_ZONE_CHEST
	var/obj/item/surgical_drapes/drapes = allocate(/obj/item/surgical_drapes)
	var/datum/component/surgery_initiator/initiator = drapes.GetComponent(/datum/component/surgery_initiator)
	TEST_ASSERT_NOTNULL(initiator, "Surgical drapes have no surgery initiator")

	expect_tiers(initiator, surgeon, corpse, list(/datum/surgery/advanced/experimental_dissection), "with nothing researched")

	computer.advanced_surgeries |= /datum/surgery/advanced/experimental_dissection/advanced
	expect_tiers(initiator, surgeon, corpse, list(/datum/surgery/advanced/experimental_dissection/advanced), "after Advanced Dissection")

	computer.advanced_surgeries |= /datum/surgery/advanced/experimental_dissection/superior
	expect_tiers(initiator, surgeon, corpse, list(/datum/surgery/advanced/experimental_dissection/superior), "after Superior Dissection")

	computer.advanced_surgeries |= /datum/surgery/advanced/experimental_dissection/elite
	expect_tiers(initiator, surgeon, corpse, list(/datum/surgery/advanced/experimental_dissection/elite), "after Elite Dissection")

	// Alien Surgery does not require the lower surgery nodes, so a crew can hold the elite
	// tier without ever researching the middle ones.
	computer.advanced_surgeries = list(/datum/surgery/advanced/experimental_dissection/elite)
	var/list/skipped_tiers = visible_tiers(initiator, surgeon, corpse)
	TEST_ASSERT(/datum/surgery/advanced/experimental_dissection/elite in skipped_tiers, "Elite Dissection is hidden when researched without the lower tiers: [json_encode(skipped_tiers)]")

/// Every experimental dissection tier currently offered to the surgeon for the corpse.
/datum/unit_test/voidcrew_dissection_tiers/proc/visible_tiers(datum/component/surgery_initiator/initiator, mob/living/surgeon, mob/living/corpse)
	var/list/tiers = list()
	for(var/datum/surgery/surgery as anything in initiator.get_available_surgeries(surgeon, corpse))
		if(istype(surgery, /datum/surgery/advanced/experimental_dissection))
			tiers += surgery.type
	return tiers

/datum/unit_test/voidcrew_dissection_tiers/proc/expect_tiers(datum/component/surgery_initiator/initiator, mob/living/surgeon, mob/living/corpse, list/expected, when)
	var/list/tiers = visible_tiers(initiator, surgeon, corpse)
	TEST_ASSERT_EQUAL(json_encode(tiers), json_encode(expected), "Wrong dissection tiers offered [when]")
