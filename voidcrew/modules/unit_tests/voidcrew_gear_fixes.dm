/// Gear that used to do nothing, or something other than what it said.
/datum/unit_test/voidcrew_gear_fixes
	var/last_nanite_code
	var/last_comm_message

/datum/unit_test/voidcrew_gear_fixes/Run()
	check_nanite_remotes()
	check_reviver_sleep()
	check_paywall_laser()
	check_bombcore_burn()
	check_clumsy_baton()
	check_plasmaman_refill()
	check_understudy_prints()
	check_ai_upgrade_disk()

/datum/unit_test/voidcrew_gear_fixes/proc/note_nanite_signal(datum/source, code, signal_source)
	SIGNAL_HANDLER
	last_nanite_code = code

/datum/unit_test/voidcrew_gear_fixes/proc/note_comm_signal(datum/source, code, message)
	SIGNAL_HANDLER
	last_comm_message = message

/// Both remotes send through a real click, and keep their targeting.
/datum/unit_test/voidcrew_gear_fixes/proc/check_nanite_remotes()
	var/mob/living/carbon/human/consistent/user = allocate(/mob/living/carbon/human/consistent)
	var/mob/living/carbon/human/consistent/host = allocate(/mob/living/carbon/human/consistent)
	// The test harness loads before voidcrew/_DEFINES, so these are COMSIG_NANITE_SIGNAL and COMSIG_NANITE_COMM_SIGNAL spelled out.
	RegisterSignal(host, "nanite_signal", PROC_REF(note_nanite_signal))
	RegisterSignal(host, "nanite_comm_signal", PROC_REF(note_comm_signal))

	var/obj/item/nanite_remote/remote = allocate(/obj/item/nanite_remote)
	user.put_in_active_hand(remote)
	remote.code = 77
	click_wrapper(user, host)
	TEST_ASSERT_NULL(last_nanite_code, "A remote switched off sent a signal")

	remote.mode = "Targeted"
	var/obj/item/storage/backpack/bag = allocate(/obj/item/storage/backpack)
	TEST_ASSERT_EQUAL(remote.interact_with_atom(bag, user, list()), NONE, "A targeted remote fired at a bag")
	TEST_ASSERT_EQUAL(remote.ranged_interact_with_atom(bag, user, list()), NONE, "A targeted remote fired at something that isn't alive")
	TEST_ASSERT_NULL(last_nanite_code, "A targeted remote signalled someone it wasn't pointed at")
	click_wrapper(user, host)
	TEST_ASSERT_EQUAL(last_nanite_code, 77, "Clicking someone with a targeted remote didn't signal them")

	remote.mode = "Local"
	TEST_ASSERT_EQUAL(remote.interact_with_atom(bag, user, list()), NONE, "A bag didn't get to take the remote")

	user.temporarilyRemoveItemFromInventory(remote, TRUE)
	var/obj/item/nanite_remote/comm/comm_remote = allocate(/obj/item/nanite_remote/comm)
	user.put_in_active_hand(comm_remote)
	comm_remote.mode = "Targeted"
	comm_remote.code = 78
	comm_remote.comm_message = "report in"
	click_wrapper(user, host)
	TEST_ASSERT_EQUAL(last_comm_message, "report in", "Clicking someone with a comm remote didn't message them")

/// Asleep and unhurt enough to be out of crit: healed for free. Asleep in crit: the implant is working, so it pays.
/datum/unit_test/voidcrew_gear_fixes/proc/check_reviver_sleep()
	var/mob/living/carbon/human/consistent/sleeper = allocate(/mob/living/carbon/human/consistent)
	sleeper.setBruteLoss(10)
	sleeper.Sleeping(5 MINUTES)
	TEST_ASSERT_EQUAL(sleeper.stat, UNCONSCIOUS, "The fixture isn't asleep")

	var/obj/item/organ/cyberimp/chest/reviver/voidcrew_clock_test/implant = allocate(/obj/item/organ/cyberimp/chest/reviver/voidcrew_clock_test)
	implant.clock = 1 HOURS
	implant.Insert(sleeper)
	implant.try_heal()
	implant.try_heal()
	implant.heal(WEAKREF(sleeper), implant.activation_generation, implant.heal_generation)
	TEST_ASSERT_EQUAL(sleeper.getBruteLoss(), 8, "The implant stopped healing someone who is asleep")
	TEST_ASSERT_EQUAL(implant.revive_cost, 0, "Healing someone who is only asleep ran up the recharge")

	// Limbs only count for three quarters of their damage, so this comes to about 117 against 100 health.
	sleeper.setBruteLoss(140)
	TEST_ASSERT_EQUAL(sleeper.stat, UNCONSCIOUS, "The fixture woke or fell past soft crit")
	TEST_ASSERT(sleeper.health <= sleeper.crit_threshold, "The fixture isn't in crit")
	implant.try_heal()
	implant.heal(WEAKREF(sleeper), implant.activation_generation, implant.heal_generation)
	TEST_ASSERT_EQUAL(implant.revive_cost, 40, "Healing someone asleep in crit didn't run up the recharge")

/// The factory pin is in its gun and knows which gun that is.
/datum/unit_test/voidcrew_gear_fixes/proc/check_paywall_laser()
	var/obj/item/gun/energy/laser/luxurypaywall/laser = allocate(/obj/item/gun/energy/laser/luxurypaywall)
	var/obj/item/firing_pin/paywall/pin = laser.pin
	TEST_ASSERT(istype(pin), "The luxury laser has no paywall pin")
	TEST_ASSERT_EQUAL(pin.gun, laser, "The paywall pin doesn't know its gun")
	TEST_ASSERT_EQUAL(pin.loc, laser, "The paywall pin fell out of its gun")

/datum/unit_test/voidcrew_gear_fixes/proc/check_bombcore_burn()
	var/obj/item/bombcore/syndicate/voidcrew_burn_test/core = allocate(/obj/item/bombcore/syndicate/voidcrew_burn_test)
	core.burn()
	TEST_ASSERT(!core.detonated, "A stable bomb core detonated from burning")
	TEST_ASSERT(QDELETED(core), "A burnt bomb core is still around")

/obj/item/bombcore/syndicate/voidcrew_burn_test
	var/detonated = FALSE

/obj/item/bombcore/syndicate/voidcrew_burn_test/detonate()
	detonated = TRUE

/// A clumsy user's own hit counts: it spends the charge and stops the swing.
/datum/unit_test/voidcrew_gear_fixes/proc/check_clumsy_baton()
	var/mob/living/carbon/human/consistent/clown = allocate(/mob/living/carbon/human/consistent)
	ADD_TRAIT(clown, TRAIT_CLUMSY, TRAIT_SOURCE_UNIT_TESTS)
	var/obj/item/melee/baton/security/loaded/baton = allocate(/obj/item/melee/baton/security/loaded)
	baton.active = TRUE
	var/charge_before = baton.cell.charge
	var/hit_self = FALSE
	for(var/attempt in 1 to 100)
		if(baton.clumsy_check(clown))
			hit_self = TRUE
			break
	TEST_ASSERT(hit_self, "A clumsy user's own hit didn't report itself")
	TEST_ASSERT(baton.cell.charge < charge_before, "A clumsy user's own hit didn't spend the charge")

/datum/unit_test/voidcrew_gear_fixes/proc/check_plasmaman_refill()
	var/mob/living/carbon/human/consistent/user = allocate(/mob/living/carbon/human/consistent)
	var/obj/item/clothing/suit/space/eva/plasmaman/suit = allocate(/obj/item/clothing/suit/space/eva/plasmaman)
	var/obj/item/extinguisher_refill/refill = allocate(/obj/item/extinguisher_refill)
	var/starting_charges = suit.extinguishes_left
	suit.extinguishes_left = starting_charges - 1
	suit.item_interaction(user, refill, list())
	TEST_ASSERT_EQUAL(suit.extinguishes_left, starting_charges, "A refill left fewer charges than the suit started with")

/datum/unit_test/voidcrew_gear_fixes/proc/check_understudy_prints()
	var/mob/living/carbon/human/consistent/user = allocate(/mob/living/carbon/human/consistent)
	var/obj/item/knife/understudy/knife = allocate(/obj/item/knife/understudy)
	knife.add_fingerprint(user, TRUE)
	TEST_ASSERT(!length(knife.forensics?.fingerprints), "The knife took a fingerprint")

/// An AI that already has an ability still gets the upgrade the disk is spent on.
/datum/unit_test/voidcrew_gear_fixes/proc/check_ai_upgrade_disk()
	var/mob/living/carbon/human/consistent/user = allocate(/mob/living/carbon/human/consistent)
	var/mob/dead/observer/fake_ghost = allocate(__IMPLIED_TYPE__) // ai must be passed a mob in /new
	var/mob/living/silicon/ai/subject = allocate(__IMPLIED_TYPE__, run_loc_floor_top_right, null, fake_ghost)
	var/datum/action/innate/ai/ranged/power_apc/ability = new
	ability.Grant(subject)
	var/obj/item/aiupgrade/surveillance_upgrade/disk = allocate(__IMPLIED_TYPE__)
	TEST_ASSERT(disk.pre_attack(subject, user, list(), list()), "The disk didn't install")
	TEST_ASSERT(subject.eyeobj.relay_speech, "The disk was used up without upgrading an AI that already had an ability")
