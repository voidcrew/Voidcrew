/// Management actions follow the same mind/body lifecycle as their ownership roles.
/datum/unit_test/voidcrew_outpost_management_lifecycle
	var/obj/structure/overmap/dynamic/player_outpost/home
	var/mob/living/carbon/human/consistent/owner
	var/mob/living/carbon/human/consistent/steward
	var/mob/living/carbon/human/consistent/replacement_body

/datum/unit_test/voidcrew_outpost_management_lifecycle/Destroy()
	if(owner)
		GLOB.player_outpost_founder_ckeys -= owner.ckey
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
	home.sync_management_lifecycle()

	TEST_ASSERT(locate(/datum/action/innate/player_outpost_management) in owner.actions, "The owner did not receive an action after the lifecycle sync.")
	TEST_ASSERT(locate(/datum/action/innate/player_outpost_management) in steward.actions, "The steward did not receive an action after the lifecycle sync.")

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

	home.abandon(replacement_body)
	TEST_ASSERT(!(locate(/datum/action/innate/player_outpost_management) in replacement_body.actions), "Abandoning the claim left an owner action button behind.")
	TEST_ASSERT(!(locate(/datum/action/innate/player_outpost_management) in steward.actions), "Abandoning the claim left a delegate action button behind.")
