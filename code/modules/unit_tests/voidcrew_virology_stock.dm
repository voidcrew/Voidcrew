/**
 * The stocking half of the port: both preloaded fridges, and the random-symptom preset that the
 * bottles carry.
 *
 * Fridge contents are plain type-path lists, so the failure mode is a renamed or mistyped bottle
 * going unnoticed until a doctor opens an empty fridge. Every entry is checked for resolving, and
 * the counts the port cares about are pinned.
 *
 * The preset check is behavioural, because it is the one piece of the port with a deliberate
 * divergence: it asks each candidate `can_generate_randomly()` so that a round type can keep a
 * symptom out of random generation (heal/radiation does exactly that during a radioactive nebula),
 * which the ported PR and upstream's sibling preset both skip. Generating a pile of them and
 * asserting every result opted in is the only way to catch that regressing.
 *
 * `initial(typed_var.var)` is the codebase's idiom for reading a type-level var (see
 * build_inventory() in code/modules/vending/_vending.dm): the local has to be declared as the
 * concrete type, or the compiler cannot resolve the member.
 */
/datum/unit_test/voidcrew_virology_stock

/// How many bottles to roll before trusting the preset's filtering.
#define VIROLOGY_STOCK_ROLLS 25

/datum/unit_test/voidcrew_virology_stock/Run()
	var/obj/machinery/smartfridge/chemistry/preloaded/chemistry_fridge = /obj/machinery/smartfridge/chemistry/preloaded
	var/list/chemistry_contents = initial(chemistry_fridge.initial_contents)
	TEST_ASSERT_NOTNULL(chemistry_contents, "the chemistry fridge lost its contents list")
	TEST_ASSERT_NOTNULL(chemistry_contents[/obj/item/reagent_containers/applicator/pill/antiviral], "the chemistry fridge should stock the spaceacillin pill")

	var/obj/machinery/smartfridge/chemistry/virology/preloaded/viro_fridge = /obj/machinery/smartfridge/chemistry/virology/preloaded
	var/list/viro_contents = initial(viro_fridge.initial_contents)
	TEST_ASSERT_NOTNULL(viro_contents, "the virology fridge lost its contents list")
	for(var/typekey in viro_contents)
		TEST_ASSERT(ispath(typekey), "[typekey] in the virology fridge is not a type path")
		TEST_ASSERT(viro_contents[typekey] > 0, "the virology fridge stocks [typekey] a non-positive number of times")

	// The bottles the restock exists for: the full virus-food ladder, and the two disease bottles.
	TEST_ASSERT_EQUAL(viro_contents[/obj/item/reagent_containers/cup/bottle/random_symptom], 10, "the virology fridge should hold ten isolated-symptom bottles")
	TEST_ASSERT_EQUAL(viro_contents[/obj/item/reagent_containers/cup/bottle/random_virus], 3, "the virology fridge should hold three experimental diseases")
	for(var/food_bottle in list(
		/obj/item/reagent_containers/cup/bottle/synaptizinevirusfood,
		/obj/item/reagent_containers/cup/bottle/mutagenvirusfood,
		/obj/item/reagent_containers/cup/bottle/mutagen,
		/obj/item/reagent_containers/cup/bottle/mutagenvirusfoodsugar,
		/obj/item/reagent_containers/cup/bottle/plasmavirusfoodweak,
		/obj/item/reagent_containers/cup/bottle/plasma,
		/obj/item/reagent_containers/cup/bottle/plasmavirusfood,
		/obj/item/reagent_containers/cup/bottle/uranium,
		/obj/item/reagent_containers/cup/bottle/uraniumvirusfoodunstable,
		/obj/item/reagent_containers/cup/bottle/uraniumvirusfood,
		/obj/item/reagent_containers/cup/bottle/uraniumvirusfoodstable,
	))
		TEST_ASSERT_NOTNULL(viro_contents[food_bottle], "the virology fridge is missing a rung of the virus-food ladder: [food_bottle]")

	// ---- the preset --------------------------------------------------------------------------
	for(var/roll in 1 to VIROLOGY_STOCK_ROLLS)
		var/datum/disease/advance/isolatedsymptom/bottle = new()
		TEST_ASSERT_EQUAL(length(bottle.symptoms), 1, "an isolated-symptom bottle should carry exactly one symptom")
		var/datum/symptom/rolled = bottle.symptoms[1]
		TEST_ASSERT(rolled.level > 0, "[rolled.type] is not obtainable but was rolled anyway")
		TEST_ASSERT(rolled.level <= 12, "[rolled.type] is above the preset's level ceiling")
		TEST_ASSERT(rolled.can_generate_randomly(), "[rolled.type] was rolled despite opting out of random generation")
		qdel(bottle)

#undef VIROLOGY_STOCK_ROLLS
