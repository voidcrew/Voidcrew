/// A failed founding releases the player reservation; a successful retry retains one claim.
/datum/unit_test/voidcrew_outpost_founding_recovery
	var/founder_key = "outpostfoundingtest"
	var/mob/living/carbon/human/founder
	var/mob/living/carbon/human/recipient

/datum/unit_test/voidcrew_outpost_founding_recovery/Destroy()
	GLOB.player_outpost_founder_ckeys -= founder_key
	GLOB.player_outpost_founder_ckeys -= "[founder_key]recipient"
	if(!QDELETED(founder))
		founder.key = null
	if(!QDELETED(recipient))
		recipient.key = null
	return ..()

/datum/unit_test/voidcrew_outpost_founding_recovery/proc/prepare_founder()
	founder = allocate(/mob/living/carbon/human/consistent)
	founder.key = founder_key
	founder.mind_initialize()
	return founder.ckey == founder_key && founder.mind

/datum/unit_test/voidcrew_outpost_founding_recovery/Run()
	TEST_ASSERT(prepare_founder(), "Could not establish the founding fixture's player identity")
	var/datum/map_template/player_outpost/invalid_shell = allocate(/datum/map_template/player_outpost/small/refused_founding_fixture)
	var/obj/structure/overmap/dynamic/player_outpost/failed = allocate(/obj/structure/overmap/dynamic/player_outpost)
	TEST_ASSERT(!failed.found(founder, invalid_shell, "Failed claim"), "A refused shell completed founding")
	TEST_ASSERT(QDELETED(failed), "Failed founding retained an incomplete claim")
	TEST_ASSERT_NULL(failed.mapzone, "Failed founding retained its reserved map zone")
	TEST_ASSERT(!(founder_key in GLOB.player_outpost_founder_ckeys), "Failed founding consumed the player's claim allowance")
	var/datum/map_template/player_outpost/small/shell = allocate(/datum/map_template/player_outpost/small)
	var/obj/structure/overmap/dynamic/player_outpost/home = allocate(/obj/structure/overmap/dynamic/player_outpost)
	TEST_ASSERT(home.found(founder, shell, "Retried claim"), "A failed attempt prevented founding a valid home")
	TEST_ASSERT(home.loaded && home.home_bundle_installed, "Successful founding omitted the purchased home services")
	TEST_ASSERT(home.can_manage(founder) && home.is_resident(founder), "Founding did not register its actual owner and resident")
	TEST_ASSERT(founder_key in GLOB.player_outpost_founder_ckeys, "Successful founding released its one-claim reservation")
	var/datum/bank_account/account = home.treasury
	var/obj/structure/overmap/dynamic/player_outpost/duplicate = allocate(/obj/structure/overmap/dynamic/player_outpost)
	TEST_ASSERT(!duplicate.found(founder, shell, "Duplicate claim"), "A second deed created another claim for the same player")
	TEST_ASSERT(QDELETED(duplicate), "Duplicate founding retained another claim")
	TEST_ASSERT_EQUAL(home.treasury, account, "Duplicate founding replaced the first home's account")
	TEST_ASSERT(founder_key in GLOB.player_outpost_founder_ckeys, "A duplicate attempt released the successful claim's reservation")
	account.adjust_money(73, "Founding lifecycle fixture")
	founder.forceMove(home.arrival_turf)
	TEST_ASSERT(home.set_outpost_name("Renamed claim", founder), "The owner could not rename the purchased home")
	TEST_ASSERT_EQUAL(home.treasury, account, "Renaming replaced the claim's account")
	TEST_ASSERT_EQUAL(account.account_balance, 73, "Renaming changed the claim's funds")
	recipient = allocate(/mob/living/carbon/human/consistent, home.arrival_turf)
	recipient.key = "[founder_key]recipient"
	recipient.mind_initialize()
	TEST_ASSERT(home.transfer_ownership(recipient, founder), "The owner could not transfer the actual purchased home")
	TEST_ASSERT(home.can_manage(recipient) && home.can_spend(recipient), "The new owner did not receive management and treasury authority")
	TEST_ASSERT(!home.can_spend(founder), "The former owner retained implicit treasury authority")
	TEST_ASSERT_EQUAL(home.treasury, account, "Ownership transfer replaced the claim's account")
	TEST_ASSERT_EQUAL(account.account_balance, 73, "Ownership transfer changed the claim's funds")

/// Exercise refusal after the claim allocates its map zone, without logging a malformed map.
/datum/map_template/player_outpost/small/refused_founding_fixture/load(turf/target, centered = FALSE)
	return FALSE
