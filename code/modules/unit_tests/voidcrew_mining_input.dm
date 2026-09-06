/// Instrument only tool selection; the real timed tool use and rock destruction still run.
/obj/item/pickaxe/bump_mining_test
	toolspeed = 0.1
	var/uses = 0

/obj/item/pickaxe/bump_mining_test/use_tool(atom/target, mob/living/user, delay, amount = 0, volume = 0, datum/callback/extra_checks)
	uses++
	return ..()

/datum/unit_test/voidcrew_offhand_bump_mining
	var/turf/mining_site
	var/original_turf_type
	var/list/original_baseturfs

/datum/unit_test/voidcrew_offhand_bump_mining/Destroy()
	if(mining_site && original_turf_type)
		mining_site.ChangeTurf(original_turf_type, original_baseturfs)
	return ..()

/datum/unit_test/voidcrew_offhand_bump_mining/proc/prepare_rock()
	var/turf/closed/mineral/rock = mining_site.ChangeTurf(/turf/closed/mineral)
	rock.baseturfs = /turf/open/floor/plating
	rock.mineralType = /obj/item/stack/ore/iron
	rock.mineralAmt = 1
	rock.tool_mine_speed = 1 SECONDS
	return rock

/datum/unit_test/voidcrew_offhand_bump_mining/Run()
	mining_site = get_step(run_loc_floor_bottom_left, EAST)
	original_turf_type = mining_site.type
	original_baseturfs = islist(mining_site.baseturfs) ? mining_site.baseturfs.Copy() : mining_site.baseturfs
	var/mob/living/carbon/human/consistent/miner = allocate(__IMPLIED_TYPE__)
	miner.mind_initialize()
	var/obj/item/gun/energy/laser/weapon = allocate(__IMPLIED_TYPE__)
	var/obj/item/pickaxe/bump_mining_test/offhand_pick = allocate(__IMPLIED_TYPE__)
	TEST_ASSERT(miner.put_in_active_hand(weapon), "The active-hand weapon must be held for this regression.")
	TEST_ASSERT(miner.put_in_inactive_hand(offhand_pick), "The mining tool must start in the inactive hand.")
	var/original_hand = miner.active_hand_index
	var/original_charge = weapon.cell.charge
	miner.set_combat_mode(TRUE)

	var/turf/closed/mineral/rock = prepare_rock()
	rock.Bumped(miner)
	UNTIL(!length(miner.do_afters)) // Bumped inherits waitfor = FALSE.
	TEST_ASSERT(isopenturf(mining_site), "Bumping rock with an off-hand pickaxe must mine the physical turf.")
	TEST_ASSERT(locate(/obj/item/stack/ore/iron) in mining_site, "Real bump mining must produce the rock's ore.")
	TEST_ASSERT_EQUAL(offhand_pick.uses, 1, "The off-hand pickaxe must perform the mining.")
	TEST_ASSERT_EQUAL(miner.get_active_held_item(), weapon, "Bump mining must not switch the active weapon.")
	TEST_ASSERT_EQUAL(miner.active_hand_index, original_hand, "Bump mining must preserve the selected hand.")
	TEST_ASSERT_EQUAL(weapon.cell.charge, original_charge, "Bump mining must not fire the active gun.")
	TEST_ASSERT(miner.combat_mode, "Bump mining must preserve combat mode.")

	miner.dropItemToGround(weapon)
	var/obj/item/pickaxe/bump_mining_test/active_pick = allocate(__IMPLIED_TYPE__)
	TEST_ASSERT(miner.put_in_active_hand(active_pick), "The selected pickaxe must be held.")
	offhand_pick.toolspeed = 0.05 // Faster, but it must not override the actively selected tool.
	rock = prepare_rock()
	rock.Bumped(miner)
	UNTIL(!length(miner.do_afters)) // Bumped inherits waitfor = FALSE.
	TEST_ASSERT(isopenturf(mining_site), "Selected-tool bump mining must still work.")
	TEST_ASSERT_EQUAL(active_pick.uses, 1, "The selected mining tool must take priority.")
	TEST_ASSERT_EQUAL(offhand_pick.uses, 1, "The faster off-hand tool must not replace an active mining tool.")

	miner.dropItemToGround(active_pick)
	rock = prepare_rock()
	rock.Bumped(miner)
	UNTIL(!length(miner.do_afters)) // Bumped inherits waitfor = FALSE.
	TEST_ASSERT(isopenturf(mining_site), "An empty active hand must still find the off-hand pickaxe.")
	TEST_ASSERT_NULL(miner.get_active_held_item(), "Off-hand mining must leave an empty active hand empty.")

	TEST_ASSERT(miner.put_in_active_hand(weapon), "The active weapon must be restored for cancellation checks.")
	offhand_pick.toolspeed = 1
	rock = prepare_rock()
	rock.tool_mine_speed = 4 SECONDS
	addtimer(CALLBACK(miner, TYPE_PROC_REF(/mob, dropItemToGround), offhand_pick), 0.2 SECONDS)
	rock.Bumped(miner)
	UNTIL(!length(miner.do_afters)) // Bumped inherits waitfor = FALSE.
	TEST_ASSERT(ismineralturf(mining_site), "Dropping the off-hand pickaxe during its timer must cancel mining.")
	TEST_ASSERT(!miner.is_holding(offhand_pick), "The cancellation timer must actually drop the mining tool.")
	TEST_ASSERT_EQUAL(miner.get_active_held_item(), weapon, "Cancelling off-hand mining must leave the weapon selected.")

	TEST_ASSERT(miner.put_in_inactive_hand(offhand_pick), "The pickaxe must be held again for the movement check.")
	addtimer(CALLBACK(miner, TYPE_PROC_REF(/atom/movable, forceMove), get_step(miner, NORTH)), 0.2 SECONDS)
	rock.Bumped(miner)
	UNTIL(!length(miner.do_afters)) // Bumped inherits waitfor = FALSE.
	TEST_ASSERT(ismineralturf(mining_site), "Moving during off-hand mining must still interrupt it.")
	miner.forceMove(run_loc_floor_bottom_left)
	miner.dropItemToGround(offhand_pick)
	rock.Bumped(miner)
	UNTIL(!length(miner.do_afters)) // Bumped inherits waitfor = FALSE.
	TEST_ASSERT(ismineralturf(mining_site), "A pickaxe lying nearby must not be used for bump mining.")
	TEST_ASSERT_EQUAL(weapon.cell.charge, original_charge, "A bump without a held mining tool must not fire the active gun.")
