/**
 * The counterplay half of the port has to keep working by itself, because it is the part the whole
 * rework was justified by: the ported PR's argument was never that viruses were too strong, it was
 * that a victim had nothing to do but sit outside medbay. Three delivery routes were added - the
 * pill type, the survival box that hands it out, and the vendor stock - plus the reagent override
 * that makes the pill worth carrying.
 *
 * The vendor entry is asserted against `products`, not against `product_records`, deliberately:
 * `/obj/machinery/vending/Initialize` is shadowed by a four-line Voidcrew shim
 * (voidcrew/modules/vending/_vending.dm), so no mapped vendor builds stock at spawn and
 * `product_records` is empty for every vendor in the game. Asserting the products list is the part
 * this port owns; asserting records would only re-fail on a pre-existing bug. See the header of
 * voidcrew/edits/vending/medical.dm.
 *
 * Survival boxes populate themselves during allocation (code/game/objects/items/storage/storage.dm
 * calls PopulateContents() as the box is created), so box contents are asserted after `allocate`
 * rather than by calling the proc again - calling it twice would just add a second pill.
 *
 * `initial(typed_var.var)` is the codebase's idiom for reading a type-level var (see
 * build_inventory() in code/modules/vending/_vending.dm): the local has to be declared as the
 * concrete type, or the compiler cannot resolve the member.
 */
/datum/unit_test/voidcrew_virology_counterplay

/// Ticks to drive the spaceacillin cure roll for. It fires at prob(0.2) per tick, so 5000 ticks
/// leaves roughly a 1-in-20,000 chance of a false failure - effectively deterministic, and far
/// cheaper than refactoring the reagent's roll to be injectable.
#define SPACEACILLIN_CURE_TICKS 5000

/datum/unit_test/voidcrew_virology_counterplay/Run()
	// ---- the pill ----------------------------------------------------------------------------
	var/obj/item/reagent_containers/applicator/pill/antiviral/pill = allocate(/obj/item/reagent_containers/applicator/pill/antiviral)
	TEST_ASSERT_EQUAL(pill.list_reagents[/datum/reagent/medicine/spaceacillin], 10, "the spaceacillin pill should hold 10u")

	// ---- the survival box --------------------------------------------------------------------
	var/obj/item/storage/box/survival/box = allocate(/obj/item/storage/box/survival)
	TEST_ASSERT_NOTNULL(locate(/obj/item/reagent_containers/applicator/pill/antiviral) in box, "every survival box should hand out a spaceacillin pill")

	// A crafted box is a deliberately empty one. Whether allocation already filled it depends on
	// `crafted` being set before creation, so the assertion is that the call adds nothing.
	var/obj/item/storage/box/survival/crafted_box = allocate(/obj/item/storage/box/survival)
	crafted_box.crafted = TRUE
	var/pills_before = length(crafted_box.contents)
	crafted_box.PopulateContents()
	TEST_ASSERT_EQUAL(length(crafted_box.contents), pills_before, "PopulateContents() is not a no-op on a crafted survival box")

	// ---- the vendor data ---------------------------------------------------------------------
	var/obj/machinery/vending/medical/nanomed = /obj/machinery/vending/medical
	var/list/products = initial(nanomed.products)
	TEST_ASSERT_NOTNULL(products[/obj/item/reagent_containers/applicator/pill/antiviral], "NanoMed Plus should stock the spaceacillin pill")
	TEST_ASSERT_NOTNULL(products[/obj/item/reagent_containers/cup/bottle/random_symptom], "NanoMed Plus should stock isolated-symptom bottles")

	var/obj/machinery/vending/wallmed/wall_nanomed = /obj/machinery/vending/wallmed
	var/list/wall_products = initial(wall_nanomed.products)
	TEST_ASSERT_NOTNULL(wall_products[/obj/item/reagent_containers/applicator/pill/antiviral], "the wall-mounted Emergency NanoMed should stock the spaceacillin pill")

	// ---- the reagent override ----------------------------------------------------------------
	var/mob/living/carbon/human/patient = allocate(/mob/living/carbon/human/consistent)
	var/datum/reagent/medicine/spaceacillin/antibiotic = new()

	// Upstream's spaceacillin has no on_mob_life at all, so a toxin trickle is only possible if
	// this port's override is the live definition for the subtype.
	patient.setToxLoss(50, updating_health = FALSE)
	antibiotic.on_mob_life(patient, 1, 1)
	TEST_ASSERT(patient.getToxLoss() < 50, "spaceacillin's on_mob_life override did not run")

	// And the reason the pill is worth carrying: the cure roll. Driven hard, because prob(0.2) per
	// tick is unobservable in one call. Toxin damage is cleared first - the tox trickle
	// short-circuits the proc with an early return and would otherwise skip every roll.
	patient.setToxLoss(0, updating_health = FALSE)
	var/datum/disease/advance/illness = new()
	patient.diseases += illness
	illness.affected_mob = patient
	for(var/tick in 1 to SPACEACILLIN_CURE_TICKS)
		antibiotic.on_mob_life(patient, 1, 1)
		if(!length(patient.diseases))
			break
	TEST_ASSERT(!length(patient.diseases), "[SPACEACILLIN_CURE_TICKS] ticks of spaceacillin failed to cure a disease")

	qdel(antibiotic)

#undef SPACEACILLIN_CURE_TICKS
