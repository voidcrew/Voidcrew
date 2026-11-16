/**
 * # Cyberware text
 *
 * Wares are described the way a person in the world would describe them: no figures and no talk
 * of load, tiers, slots or EMPs. Ability buttons are the one place numbers belong, so they are not
 * checked here.
 */
/datum/unit_test/voidcrew_cyberware_text

/datum/unit_test/voidcrew_cyberware_text/Run()
	var/list/roots = list(
		/obj/item/organ/cyberimp/cyberware,
		/obj/item/organ/eyes/robotic/cyberware,
		/obj/item/organ/cyberimp/arm/toolkit/cyberware,
	)
	for(var/root in roots)
		for(var/obj/item/organ/ware_path as anything in typesof(root))
			var/ware_desc = initial(ware_path.desc)
			TEST_ASSERT(!findtext(ware_desc, regex("\[0-9]")), "[ware_path]'s description has a figure in it: [ware_desc]")
			TEST_ASSERT(!findtext(ware_desc, regex("\b(tier|load|slot|EMP)\b", "i")), "[ware_path]'s description talks about game rules: [ware_desc]")
