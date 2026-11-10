/**
 * # Chrome test kit (voidcrew/modules/admin/chrome_test_kit.dm)
 *
 * The verb itself needs a client and a menu, so these tests hold the parts under it: every
 * ready-made build is made of real chrome, fits one body without evicting itself, comes out
 * running, and what does not fit is handed back rather than lost; a body missing a limb is
 * not forced to take chrome for it; "everything" really is the whole shelf.
 */

/datum/unit_test/voidcrew_cyberware_kit_loadouts

/datum/unit_test/voidcrew_cyberware_kit_loadouts/Run()
	TEST_ASSERT(length(GLOB.chrome_test_loadouts) >= 3, "The kit offers only [length(GLOB.chrome_test_loadouts)] builds")
	for(var/loadout_name in GLOB.chrome_test_loadouts)
		var/list/ware_types = GLOB.chrome_test_loadouts[loadout_name]
		TEST_ASSERT(length(ware_types), "The [loadout_name] build is empty")
		// No two pieces of a build may want the same slot, or one would evict the other.
		var/list/slots = list()
		for(var/ware_type in ware_types)
			TEST_ASSERT(ispath(ware_type, /obj/item/organ), "[loadout_name]: [ware_type] is not an organ")
			var/obj/item/organ/example = ware_type
			var/slot_name = initial(example.slot)
			TEST_ASSERT(!slots[slot_name], "[loadout_name]: [ware_type] and [slots[slot_name]] share the slot [slot_name]")
			slots[slot_name] = "[ware_type]"
		var/mob/living/carbon/human/body = allocate(/mob/living/carbon/human/consistent)
		var/list/report = list()
		var/list/left_over = chrome_kit_install(body, ware_types, report)
		for(var/obj/item/organ/spare as anything in left_over)
			TEST_ASSERT(!QDELETED(spare) && !spare.owner, "[loadout_name]: a piece left over is deleted or still owned")
			qdel(spare)
		TEST_ASSERT_EQUAL(length(get_installed_cyberware(body)) + length(left_over), length(ware_types), "[loadout_name]: pieces went missing between the list and the body")
		TEST_ASSERT(get_chrome_load(body) <= get_chrome_capacity(body), "[loadout_name]: the kit left the body over capacity ([get_chrome_load(body)] of [get_chrome_capacity(body)])")
		for(var/obj/item/organ/ware as anything in get_installed_cyberware(body))
			var/datum/component/cyberware/chrome = ware.GetComponent(/datum/component/cyberware)
			TEST_ASSERT(chrome.is_running(), "[loadout_name]: [ware.type] came out of the kit dark")
		// The first piece listed is the one the build is named for; it must always make it.
		var/first_type = ware_types[1]
		TEST_ASSERT(locate(first_type) in body.organs, "[loadout_name]: its first piece, [first_type], did not install")

/// A body with no left arm takes the right-arm pieces and hands the left-arm ones back.
/datum/unit_test/voidcrew_cyberware_kit_limbs

/datum/unit_test/voidcrew_cyberware_kit_limbs/Run()
	var/mob/living/carbon/human/body = allocate(/mob/living/carbon/human/consistent)
	var/obj/item/bodypart/arm = body.get_bodypart(BODY_ZONE_L_ARM)
	arm.drop_limb()
	qdel(arm)
	var/list/report = list()
	var/list/left_over = chrome_kit_install(body, list(
		/obj/item/organ/cyberimp/arm/toolkit/cyberware/mantis,
		/obj/item/organ/cyberimp/arm/toolkit/cyberware/mantis/left,
	), report)
	TEST_ASSERT_EQUAL(length(left_over), 1, "The left housing should have been handed back, got [length(left_over)] pieces")
	var/obj/item/organ/handed_back = left_over[1]
	TEST_ASSERT(istype(handed_back, /obj/item/organ/cyberimp/arm/toolkit/cyberware/mantis/left), "The wrong piece was handed back: [handed_back.type]")
	TEST_ASSERT(!handed_back.owner && isturf(handed_back.loc), "The handed-back housing is not loose on the floor")
	TEST_ASSERT_EQUAL(length(report), 1, "The kit should name the piece it left out, got [length(report)] lines")
	TEST_ASSERT(findtext(report[1], "no limb"), "The kit did not say it was the missing limb: [report[1]]")
	TEST_ASSERT_EQUAL(length(get_installed_cyberware(body)), 1, "The right housing did not install on its own")
	qdel(handed_back)

/// The "everything" crate covers every organ any ripperdoc shelf sells, once.
/datum/unit_test/voidcrew_cyberware_kit_everything

/datum/unit_test/voidcrew_cyberware_kit_everything/Run()
	var/list/everything = chrome_kit_everything_types()
	TEST_ASSERT(length(everything) > 40, "The everything crate holds only [length(everything)] kinds")
	for(var/datum/shop_sku/sku_type as anything in subtypesof(/datum/shop_sku/ripperdoc))
		var/item_path = initial(sku_type.item_path)
		if(ispath(item_path, /obj/item/organ) || ispath(item_path, /obj/item/cyberware_pair_case) || ispath(item_path, /obj/item/storage/case/cyberware))
			TEST_ASSERT(item_path in everything, "The everything crate is missing [item_path], which [sku_type] sells")
	TEST_ASSERT(/obj/item/organ/cyberimp/cyberware/piledriver in everything, "The everything crate is missing the Piledriver, which no shelf sells")
	// Built the way the verb builds it, the crate's contents are loose, real chrome.
	var/list/made = list()
	for(var/ware_type in everything)
		made += allocate(ware_type)
	var/obj/structure/closet/crate/crate = chrome_kit_crate(run_loc_floor_bottom_left, made, "test crate")
	allocated += crate
	TEST_ASSERT_EQUAL(length(crate.contents), length(everything), "The crate lost items on the way in")
