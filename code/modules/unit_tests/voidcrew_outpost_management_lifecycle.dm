/// Console authority follows the current owner mind without granting remote actions.
/datum/unit_test/voidcrew_outpost_management_lifecycle
	var/obj/structure/overmap/dynamic/player_outpost/home
	var/mob/living/carbon/human/consistent/owner
	var/mob/living/carbon/human/consistent/steward
	var/mob/living/carbon/human/consistent/replacement_body
	var/mob/living/carbon/human/consistent/returning_owner

/datum/unit_test/voidcrew_outpost_management_lifecycle/Destroy()
	if(returning_owner)
		returning_owner.key = null
	if(replacement_body)
		replacement_body.key = null
	if(steward)
		steward.key = null
	if(owner)
		owner.key = null
	return ..()

/datum/unit_test/voidcrew_outpost_management_lifecycle/Run()
	var/turf/location = run_loc_floor_bottom_left
	home = allocate(__IMPLIED_TYPE__)
	owner = allocate(/mob/living/carbon/human/consistent, location)
	owner.key = "outpostlifecycleowner"
	owner.mind_initialize()
	steward = allocate(/mob/living/carbon/human/consistent, location)
	steward.key = "outpostlifecyclesteward"
	steward.mind_initialize()
	home.founder_ckey = owner.ckey
	home.founder_name = owner.real_name
	home.founder_mind = WEAKREF(owner.mind)
	home.residents |= list(owner.mind, steward.mind)
	home.stewards |= steward.mind
	TEST_ASSERT(home.is_current_management_user(steward), "A delegated steward cannot manage the outpost.")

	home.stewards -= steward.mind
	TEST_ASSERT(!home.is_current_management_user(steward), "A revoked steward can still manage the outpost.")
	home.stewards |= steward.mind
	TEST_ASSERT(home.is_current_management_user(steward), "A delegated steward cannot manage the outpost.")

	replacement_body = allocate(/mob/living/carbon/human/consistent, location)
	owner.mind.transfer_to(replacement_body, TRUE)
	TEST_ASSERT(!home.is_current_management_user(owner), "The former body retained console authority.")
	TEST_ASSERT(home.is_current_management_user(replacement_body), "Console authority did not follow the owner mind.")

	SEND_SIGNAL(replacement_body, COMSIG_MOB_LOGIN)
	TEST_ASSERT(home.is_current_management_user(replacement_body), "Login changed the current owner's console authority.")

	// Respawn may create a different mind; round-long ownership still follows the account.
	var/owner_key = replacement_body.key
	replacement_body.key = null
	returning_owner = allocate(/mob/living/carbon/human/consistent, location)
	returning_owner.key = owner_key
	returning_owner.mind_initialize()
	returning_owner.sync_player_outpost_owner()
	TEST_ASSERT(home.is_current_management_user(returning_owner), "A returning owner could not manage their claim.")
	TEST_ASSERT(!home.is_current_management_user(replacement_body), "The previous character kept current-owner access.")
	TEST_ASSERT_EQUAL(home.founder_mind.resolve(), returning_owner.mind, "Owner notifications retained the old character mind.")

	// Self-delegation must not preserve the former owner's authority after transfer.
	home.stewards |= returning_owner.mind
	home.treasurers |= list(returning_owner.mind, steward.mind)
	home.authorized_builder_ckeys |= list(returning_owner.ckey, steward.ckey)
	TEST_ASSERT(home.transfer_ownership(steward, returning_owner), "A live owner could not transfer the claim to an eligible delegate.")
	TEST_ASSERT(!home.can_manage(returning_owner) && !home.can_spend(returning_owner) && !home.can_build(returning_owner), "Self-delegation preserved a former owner's authority after transfer.")
	TEST_ASSERT((steward.mind in home.treasurers) && (steward.ckey in home.authorized_builder_ckeys), "Ownership transfer discarded another resident's delegated permissions.")
	TEST_ASSERT(home.is_current_management_user(steward), "The new owner did not retain management authority.")
	home.abandon(steward)
	TEST_ASSERT(!home.is_current_management_user(steward), "Abandonment retained management authority.")
