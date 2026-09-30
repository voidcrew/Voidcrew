/// Deleting a reagent container while a non-instant reaction is active must not
/// invoke reagent-processing against the holder after its reagent list is nulled.
/datum/unit_test/reagent_holder_teardown/Run()
	var/obj/item/reagent_containers/cup/beaker/beaker = allocate(/obj/item/reagent_containers/cup/beaker)
	beaker.reagents.add_reagent(/datum/reagent/water, 10)
	beaker.reagents.add_reagent(/datum/reagent/silicon, 10)
	beaker.reagents.add_reagent(/datum/reagent/oxygen, 10)

	TEST_ASSERT(beaker.reagents.is_reacting, "The beaker did not start its ongoing lube reaction")
	TEST_ASSERT(length(beaker.reagents.reaction_list), "The beaker has no equilibrium to tear down")

	var/obj/item/reagent_containers/cup/beaker/control = allocate(/obj/item/reagent_containers/cup/beaker)
	control.reagents.add_reagent(/datum/reagent/australium, 1)
	control.reagents.add_reagent(/datum/reagent/medicine/rezadone, 1)
	TEST_ASSERT(control.reagents.has_reagent(/datum/reagent/inverse/rezadone), "A live holder stopped processing Australium's reagent_fire behavior")
	TEST_ASSERT(!control.reagents.has_reagent(/datum/reagent/medicine/rezadone), "Australium did not invert the control reagent")
	qdel(beaker)
