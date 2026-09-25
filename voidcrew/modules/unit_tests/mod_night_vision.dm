/datum/unit_test/mod_night_vision_traits/Run()
	var/mob/living/carbon/human/wearer = allocate(/mob/living/carbon/human/consistent)
	var/obj/item/mod/control/suit = allocate(/obj/item/mod/control)
	var/obj/item/mod/module/night/night_vision = allocate(/obj/item/mod/module/night)
	night_vision.mod = suit
	suit.wearer = wearer
	night_vision.on_activation()
	TEST_ASSERT(HAS_TRAIT_FROM(wearer, TRAIT_TRUE_NIGHT_VISION, REF(night_vision)), "Activating built-in MOD night vision did not give night sight")
	ADD_TRAIT(wearer, TRAIT_TRUE_NIGHT_VISION, "unit_test_other_source")
	night_vision.on_deactivation()
	TEST_ASSERT(!HAS_TRAIT_FROM(wearer, TRAIT_TRUE_NIGHT_VISION, REF(night_vision)), "Deactivating the module left its night sight applied")
	TEST_ASSERT(HAS_TRAIT_FROM(wearer, TRAIT_TRUE_NIGHT_VISION, "unit_test_other_source"), "Deactivating the module removed another night-vision source")
	REMOVE_TRAIT(wearer, TRAIT_TRUE_NIGHT_VISION, "unit_test_other_source")
	night_vision.mod = null
	suit.wearer = null
