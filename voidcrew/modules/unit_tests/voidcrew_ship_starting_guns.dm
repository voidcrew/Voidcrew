/// Inspect finished inventories so the shared equip hook cannot silently delete guns.
/datum/unit_test/voidcrew_ship_starting_guns/Run()
	var/list/suit_guns = list(
		/datum/outfit/job/hos = /obj/item/gun/energy/e_gun,
		/datum/outfit/job/captain/syndicate = /obj/item/gun/ballistic/revolver/mateba,
		/datum/outfit/job/assistant/syndicate = /obj/item/gun/ballistic/automatic/pistol,
		/datum/outfit/job/workshop_hiryu_class_carrier_job_20 = /obj/item/gun/ballistic/shotgun/doublebarrel,
		/datum/outfit/job/workshop_hiryu_class_carrier_job_12 = /obj/item/gun/ballistic/shotgun/doublebarrel,
		/datum/outfit/job/workshop_hiryu_class_carrier_job_14 = /obj/item/gun/ballistic/shotgun/doublebarrel,
	)
	for(var/outfit_type in suit_guns)
		var/datum/outfit/job/outfit = allocate(outfit_type)
		var/mob/living/carbon/human/consistent/wearer = allocate(__IMPLIED_TYPE__)
		outfit.equip(wearer)
		TEST_ASSERT(istype(wearer.s_store, suit_guns[outfit_type]), "[outfit_type] lost its starting gun after equip.")
		if(outfit_type == /datum/outfit/job/assistant/syndicate)
			TEST_ASSERT(istype(wearer.l_store, /obj/item/ammo_box/magazine/m10mm), "The syndicate crew member lost their spare magazine.")
		if(ispath(outfit_type, /datum/outfit/job/workshop_hiryu_class_carrier_job_20) || ispath(outfit_type, /datum/outfit/job/workshop_hiryu_class_carrier_job_12) || ispath(outfit_type, /datum/outfit/job/workshop_hiryu_class_carrier_job_14))
			TEST_ASSERT(locate(/obj/item/storage/box/lethalshot) in wearer.get_all_contents(), "[outfit_type] lost its shotgun ammunition.")
	var/datum/outfit/job/bridge_assistant/bridge_outfit = allocate(__IMPLIED_TYPE__)
	var/mob/living/carbon/human/consistent/bridge_wearer = allocate(__IMPLIED_TYPE__)
	bridge_outfit.equip(bridge_wearer)
	TEST_ASSERT(istype(bridge_wearer.l_store, /obj/item/gun/energy/e_gun/mini), "The bridge assistant lost their pocket gun.")

/// Locker contents are generated at different times; check both immediate and lazy stock.
/datum/unit_test/voidcrew_ship_starting_lockers/Run()
	var/list/locker_guns = list(
		/obj/structure/closet/secure_closet/captains = /obj/item/gun/energy/e_gun,
		/obj/structure/closet/secure_closet/hop = /obj/item/gun/energy/e_gun,
		/obj/structure/closet/secure_closet/hos = /obj/item/gun/energy/e_gun/hos,
		/obj/structure/closet/secure_closet/armory2 = /obj/item/gun/ballistic/shotgun/riot,
	)
	for(var/locker_type in locker_guns)
		var/obj/structure/closet/locker = allocate(locker_type)
		if(!locker.contents_initialized)
			locker.contents_initialized = TRUE
			locker.PopulateContents()
			SEND_SIGNAL(locker, COMSIG_CLOSET_CONTENTS_INITIALIZED)
		TEST_ASSERT(locate(locker_guns[locker_type]) in locker.get_all_contents(), "[locker_type] lost its starting gun.")
		if(locker_type == /obj/structure/closet/secure_closet/armory2)
			TEST_ASSERT(locate(/obj/item/storage/box/rubbershot) in locker, "The ballistics locker lost its shell boxes.")

/// Marine vouchers retain each faction's original choices and spare ammunition.
/datum/unit_test/voidcrew_ship_starting_vouchers/Run()
	var/obj/machinery/vending/security/marine/syndicate = allocate(__IMPLIED_TYPE__)
	var/list/syndicate_choices = list(
		"M-90gl Carbine" = /obj/item/gun/ballistic/automatic/m90/unrestricted,
		"sniper rifle" = /obj/item/gun/ballistic/rifle/sniper_rifle,
		"C-20r SMG" = /obj/item/gun/ballistic/automatic/c20r/unrestricted,
		"Bulldog Shotgun" = /obj/item/gun/ballistic/shotgun/bulldog/unrestricted,
	)
	TEST_ASSERT_EQUAL(length(syndicate.voucher_items), length(syndicate_choices), "The syndicate vendor has the wrong voucher options.")
	for(var/choice in syndicate_choices)
		TEST_ASSERT_EQUAL(syndicate.voucher_items[choice], syndicate_choices[choice], "The syndicate vendor lost [choice].")
	for(var/magazine in list(/obj/item/ammo_box/magazine/m9mm, /obj/item/ammo_box/magazine/m10mm, /obj/item/ammo_box/magazine/smgm45, /obj/item/ammo_box/magazine/sniper_rounds, /obj/item/ammo_box/magazine/m12g))
		TEST_ASSERT_EQUAL(syndicate.products[magazine], 3, "The syndicate vendor lost spare [magazine].")
	var/obj/machinery/vending/security/marine/solgov/solgov = allocate(__IMPLIED_TYPE__)
	var/list/solgov_choices = list(
		"Tactical Energy Gun" = /obj/item/gun/energy/e_gun/stun,
		"Inferno Pistol" = /obj/item/gun/energy/laser/thermal/inferno,
		"Cryo Pistol" = /obj/item/gun/energy/laser/thermal/cryo,
	)
	TEST_ASSERT_EQUAL(length(solgov.voucher_items), length(solgov_choices), "The SolGov vendor has the wrong voucher options.")
	for(var/choice in solgov_choices)
		TEST_ASSERT_EQUAL(solgov.voucher_items[choice], solgov_choices[choice], "The SolGov vendor lost [choice].")
