/// Management actions follow the same mind/body lifecycle as their ownership roles.
/datum/unit_test/voidcrew_outpost_management_lifecycle
	var/obj/structure/overmap/dynamic/player_outpost/home
	var/mob/living/carbon/human/consistent/owner
	var/mob/living/carbon/human/consistent/steward
	var/mob/living/carbon/human/consistent/replacement_body
	var/mob/living/carbon/human/consistent/returning_owner

/datum/unit_test/voidcrew_outpost_management_lifecycle/Destroy()
	if(owner)
		GLOB.player_outpost_founder_ckeys -= owner.ckey
	if(steward)
		GLOB.player_outpost_founder_ckeys -= steward.ckey
	if(returning_owner)
		returning_owner.key = null
	if(replacement_body)
		replacement_body.key = null
	if(steward)
		steward.key = null
	if(owner)
		owner.key = null
	return ..()

/datum/unit_test/voidcrew_outpost_management_lifecycle/proc/management_action_count(mob/user)
	var/count = 0
	for(var/datum/action/innate/player_outpost_management/action as anything in user.actions)
		count++
	return count

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
	home.sync_management_lifecycle()

	TEST_ASSERT(locate(/datum/action/innate/player_outpost_management) in owner.actions, "The owner did not receive an action after the lifecycle sync.")
	TEST_ASSERT(locate(/datum/action/innate/player_outpost_management) in steward.actions, "The steward did not receive an action after the lifecycle sync.")
	home.sync_management_lifecycle()
	TEST_ASSERT_EQUAL(management_action_count(owner), 1, "Repeated lifecycle refreshes stacked owner management actions.")
	TEST_ASSERT_EQUAL(management_action_count(steward), 1, "Repeated lifecycle refreshes stacked delegate management actions.")

	home.stewards -= steward.mind
	home.sync_management_lifecycle()
	TEST_ASSERT(!(locate(/datum/action/innate/player_outpost_management) in steward.actions), "Revoking steward authority left a stale action button.")
	home.stewards |= steward.mind
	home.sync_management_lifecycle()
	TEST_ASSERT(locate(/datum/action/innate/player_outpost_management) in steward.actions, "Restoring steward authority did not restore the action.")

	replacement_body = allocate(/mob/living/carbon/human/consistent, location)
	owner.mind.transfer_to(replacement_body, TRUE)
	TEST_ASSERT(!(locate(/datum/action/innate/player_outpost_management) in owner.actions), "The old owner body kept a management action after body transfer.")
	TEST_ASSERT(locate(/datum/action/innate/player_outpost_management) in replacement_body.actions, "The owner action did not follow the mind to its replacement body.")

	SEND_SIGNAL(replacement_body, COMSIG_MOB_LOGIN)
	TEST_ASSERT(locate(/datum/action/innate/player_outpost_management) in replacement_body.actions, "A returning owner body lost its management action on login refresh.")

	// Respawn may create a different mind; round-long ownership still follows the account.
	var/owner_key = replacement_body.key
	replacement_body.key = null
	returning_owner = allocate(/mob/living/carbon/human/consistent, location)
	returning_owner.key = owner_key
	returning_owner.mind_initialize()
	returning_owner.sync_player_outpost_management()
	TEST_ASSERT(locate(/datum/action/innate/player_outpost_management) in returning_owner.actions, "A returning owner's new character did not receive management controls.")
	TEST_ASSERT_EQUAL(home.founder_mind.resolve(), returning_owner.mind, "Owner notifications retained the old character mind.")
	TEST_ASSERT(!(locate(/datum/action/innate/player_outpost_management) in replacement_body.actions), "The abandoned old body retained owner controls after a new character returned.")

	TEST_ASSERT(home.transfer_ownership(steward, returning_owner), "A live owner could not transfer the claim to an eligible delegate.")
	TEST_ASSERT(!(locate(/datum/action/innate/player_outpost_management) in replacement_body.actions), "The former owner kept a management action after ownership transfer.")
	TEST_ASSERT(!(locate(/datum/action/innate/player_outpost_management) in returning_owner.actions), "The returning former owner retained management controls after transfer.")
	TEST_ASSERT_EQUAL(management_action_count(steward), 1, "Ownership transfer duplicated the recipient's existing delegate action.")
	home.abandon(steward)
	TEST_ASSERT(!(locate(/datum/action/innate/player_outpost_management) in replacement_body.actions), "Abandoning the claim left an owner action button behind.")
	TEST_ASSERT(!(locate(/datum/action/innate/player_outpost_management) in steward.actions), "Abandoning the claim left a delegate action button behind.")
