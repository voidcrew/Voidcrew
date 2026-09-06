/// Supplies only the menu answer; the real capstone cast dispatches the command to visible listeners.
/datum/action/cooldown/spell/voice_of_the_word/unit_test_frenzy/choose_command(mob/living/user)
	return "TURN ON EACH OTHER"

/// Rejected possession must preserve the target and must not grant release immunity.
/datum/unit_test/vestige_word_frenzy_rejection/Run()
	restore_atmos()
	var/turf/center = get_step(get_step(run_loc_floor_bottom_left, NORTH), EAST)
	var/mob/living/carbon/human/consistent/speaker = allocate(/mob/living/carbon/human/consistent, center)
	speaker.mind_initialize()
	var/mob/living/carbon/human/consistent/protected = allocate(/mob/living/carbon/human/consistent, get_step(center, NORTH))
	var/obj/item/clothing/head/costume/foilhat/hat = allocate(/obj/item/clothing/head/costume/foilhat, center)
	TEST_ASSERT(protected.equip_to_slot_if_possible(hat, ITEM_SLOT_HEAD), "The rejection scenario must wear an actual mind-antimagic hat.")
	var/list/protected_faction = protected.faction.Copy()
	var/datum/ai_controller/protected_ai = protected.ai_controller
	TEST_ASSERT(!can_be_lich_thralled(protected), "The worn hat must reject actual possession eligibility.")
	var/mob/living/basic/carp/quarry = allocate(/mob/living/basic/carp, get_step(center, EAST))
	var/quarry_ai_type = quarry.ai_controller.type
	var/list/quarry_faction = quarry.faction.Copy()
	TEST_ASSERT(can_be_lich_thralled(quarry), "The same command needs a genuinely eligible stock-AI listener.")
	var/datum/action/cooldown/spell/voice_of_the_word/unit_test_frenzy/word = allocate(/datum/action/cooldown/spell/voice_of_the_word/unit_test_frenzy, speaker.mind)
	word.Grant(speaker)
	TEST_ASSERT(word.Activate(speaker), "The actual capstone cast must select and dispatch its frenzy command.")
	TEST_ASSERT_NULL(protected.has_status_effect(/datum/status_effect/lich_thrall), "The real tinfoil hat must stop the command's possession.")
	TEST_ASSERT(!HAS_TRAIT(protected, "lich_thrall_spent"), "Rejecting possession must not grant the ninety-second release immunity.")
	TEST_ASSERT_EQUAL(protected.ai_controller, protected_ai, "A rejected effect must preserve the original controller.")
	TEST_ASSERT_EQUAL(json_encode(protected.faction), json_encode(protected_faction), "A rejected effect must preserve the original factions.")
	TEST_ASSERT_NULL(protected.get_filter("voice_of_the_word_frenzy"), "A rejected effect must leave no possession outline.")
	var/datum/status_effect/lich_thrall/word_frenzy/possession = quarry.has_status_effect(/datum/status_effect/lich_thrall/word_frenzy)
	TEST_ASSERT(possession && quarry.ai_controller == possession.puppet_controller, "The same real command must actually possess its eligible listener.")
	TEST_ASSERT(quarry.get_filter("voice_of_the_word_frenzy"), "An applied possession must install its actual visible effect.")
	qdel(possession)
	TEST_ASSERT_EQUAL(quarry.ai_controller.type, quarry_ai_type, "Releasing a successful possession must restore the stock controller type.")
	TEST_ASSERT_EQUAL(json_encode(quarry.faction), json_encode(quarry_faction), "Successful release must restore the quarry's original factions.")
	TEST_ASSERT(HAS_TRAIT(quarry, "lich_thrall_spent"), "Successfully released victims must still receive ordinary chain-possession immunity.")
	TEST_ASSERT_NULL(quarry.get_filter("voice_of_the_word_frenzy"), "Successful release must remove its actual outline.")
	TEST_ASSERT(protected.dropItemToGround(hat), "The ordinary equipped hat must be removable after rejecting the command.")
	TEST_ASSERT(can_be_lich_thralled(protected), "Removing the hat must expose an otherwise eligible body immediately, without false release immunity.")

/// Reaches the real entry guards without loading or owning an arena reservation.
/datum/vestige_ascension_run/unit_test_entry
	var/load_calls = 0
	var/atom/movable/add_during_load
	var/mob/living/basic/guardian/link_during_load

/datum/vestige_ascension_run/unit_test_entry/load_arena(datum/map_template/vestige_arena/template)
	load_calls++
	if(add_during_load)
		add_during_load.forceMove(supplicant.current)
		return TRUE
	if(link_during_load)
		link_during_load.set_summoner(supplicant.current)
		link_during_load.manifest(forced = TRUE)
		return TRUE
	return FALSE

/// A real folded bodybag remains a passenger container even several inventory levels deep.
/datum/unit_test/vestige_ascension_passengers/Run()
	var/mob/living/carbon/human/user = allocate(/mob/living/carbon/human/consistent)
	user.mind_initialize()
	TEST_ASSERT(!vestige_ascension_passenger(user), "A plain human was mistaken for a passenger carrier")
	var/datum/vestige_ascension/offer = allocate(/datum/vestige_ascension/oracle)
	var/datum/vestige_ascension_run/unit_test_entry/plain_run = allocate(/datum/vestige_ascension_run/unit_test_entry, offer, user)
	plain_run.begin(user)
	TEST_ASSERT_EQUAL(plain_run.load_calls, 1, "An unaccompanied human could not reach arena loading")
	qdel(plain_run)

	var/obj/structure/closet/body_bag/bluespace/deployed = allocate(/obj/structure/closet/body_bag/bluespace, get_step(user, EAST))
	var/mob/living/carbon/human/passenger = allocate(/mob/living/carbon/human/consistent, deployed)
	TEST_ASSERT(deployed.attempt_fold(user), "The occupied bluespace bag could not fold")
	deployed.perform_fold(user)
	var/obj/item/bodybag/bluespace/folded = locate() in user.held_items
	TEST_ASSERT(folded && passenger.loc == folded, "Folding did not place the real passenger into a held bodybag")
	qdel(deployed)
	var/obj/item/storage/backpack/holding/outer = allocate(/obj/item/storage/backpack/holding, user)
	outer.atom_storage.attempt_insert(folded, user, messages = FALSE)
	TEST_ASSERT_EQUAL(folded.loc, outer, "The regression must nest the occupied bodybag in another container")
	TEST_ASSERT_EQUAL(vestige_ascension_passenger(user), passenger, "The entry check missed a passenger inside nested bags")
	var/datum/vestige_ascension_run/unit_test_entry/run = allocate(/datum/vestige_ascension_run/unit_test_entry, offer, user)
	TEST_ASSERT(!run.begin(user), "A nested passenger was admitted to a solo arena")
	TEST_ASSERT_EQUAL(run.load_calls, 0, "A rejected passenger still allocated arena loading work")
	TEST_ASSERT(!user.mind.active_ascension_run, "A rejected passenger locked the supplicant out of future attempts")
	passenger.death()
	TEST_ASSERT_EQUAL(vestige_ascension_passenger(user), passenger, "A revivable corpse bypassed the solo entry check")
	TEST_ASSERT(!run.begin(user), "A bodybag corpse was admitted for revival inside the arena")
	qdel(run)
	outer.forceMove(get_turf(user))
	TEST_ASSERT(!vestige_ascension_passenger(user), "Leaving the passenger outside did not clear entry")

	var/datum/vestige_ascension_run/unit_test_entry/late_run = allocate(/datum/vestige_ascension_run/unit_test_entry, offer, user)
	late_run.add_during_load = outer
	TEST_ASSERT(!late_run.begin(user), "A passenger added while the arena loaded was admitted")
	TEST_ASSERT_EQUAL(late_run.load_calls, 1, "The late passenger regression did not reach the yielding load boundary")
	TEST_ASSERT(!late_run.boss && !late_run.watched_supplicant, "A late passenger check ran after committing the arena encounter")
	qdel(late_run)
	TEST_ASSERT(!user.mind.active_ascension_run, "Failed entry cleanup retained the active run")

/// A deployed holoparasite remains recallable across the arena boundary despite standing outside inventory.
/datum/unit_test/vestige_ascension_guardian_entry/Run()
	var/mob/living/carbon/human/user = allocate(/mob/living/carbon/human/consistent)
	user.mind_initialize()
	var/mob/living/basic/guardian/standard/guardian = allocate(/mob/living/basic/guardian/standard, get_step(user, EAST))
	guardian.set_summoner(user)
	TEST_ASSERT_EQUAL(guardian.loc, user, "Linking the real guardian did not recall it into its summoner")
	TEST_ASSERT_EQUAL(vestige_ascension_passenger(user), guardian, "A recalled guardian bypassed solo entry")
	TEST_ASSERT(guardian.manifest(forced = TRUE), "The guardian regression could not manifest")
	TEST_ASSERT(!(guardian in user.get_all_contents_type(/mob/living)), "The deployed guardian must stand outside the inventory being scanned")
	TEST_ASSERT_EQUAL(vestige_ascension_passenger(user), guardian, "Manifesting a linked guardian bypassed solo entry")
	var/datum/vestige_ascension/offer = allocate(/datum/vestige_ascension/oracle)
	var/datum/vestige_ascension_run/unit_test_entry/run = allocate(/datum/vestige_ascension_run/unit_test_entry, offer, user)
	TEST_ASSERT(!run.begin(user) && !run.load_calls, "A deployed guardian's host began loading a solo encounter")
	TEST_ASSERT(!user.mind.active_ascension_run, "Rejecting a guardian host retained an active encounter")
	qdel(run)
	guardian.cut_summoner()
	TEST_ASSERT(!vestige_ascension_passenger(user), "An unrelated nearby guardian prevented solo entry")
	var/datum/vestige_ascension_run/unit_test_entry/late_run = allocate(/datum/vestige_ascension_run/unit_test_entry, offer, user)
	late_run.link_during_load = guardian
	TEST_ASSERT(!late_run.begin(user), "A guardian linked and manifested while arena loading yielded bypassed the second entry guard")
	TEST_ASSERT_EQUAL(late_run.load_calls, 1, "The late guardian regression did not reach arena loading")
	TEST_ASSERT(guardian.is_deployed() && guardian.summoner == user, "The late guardian fixture did not leave a real deployed companion")
	TEST_ASSERT(!late_run.boss && !late_run.watched_supplicant, "The late guardian rejection happened after committing the fight")
	qdel(late_run)
	TEST_ASSERT(!user.mind.active_ascension_run, "Late guardian rejection retained an active encounter")
	guardian.cut_summoner()
	qdel(guardian)

/// Shapeshifting stores the caster inside the new form; it must not disable ascension.
/datum/unit_test/vestige_ascension_shapeshifter/Run()
	var/mob/living/carbon/human/user = allocate(/mob/living/carbon/human/consistent)
	user.mind_initialize()
	var/datum/mind/keeper = user.mind
	var/datum/action/cooldown/spell/shapeshift/shift = allocate(/datum/action/cooldown/spell/shapeshift)
	shift.shapeshift_type = /mob/living/basic/carp
	shift.Grant(user)
	var/mob/living/shape = shift.do_shapeshift(user)
	TEST_ASSERT(shape && keeper.current == shape && user.loc == shape, "The regression must use a real spell-held original body")
	TEST_ASSERT(!vestige_ascension_passenger(shape), "The keeper's original body was treated as another participant")
	var/datum/vestige_ascension/offer = allocate(/datum/vestige_ascension/oracle)
	var/datum/vestige_ascension_run/unit_test_entry/run = allocate(/datum/vestige_ascension_run/unit_test_entry, offer, shape)
	run.begin(shape)
	TEST_ASSERT_EQUAL(run.load_calls, 1, "The transformed keeper could not reach arena loading")
	qdel(run)
	var/obj/item/bodybag/bluespace/bag = allocate(/obj/item/bodybag/bluespace, user)
	var/mob/living/basic/carp/passenger = allocate(/mob/living/basic/carp, bag)
	TEST_ASSERT_EQUAL(vestige_ascension_passenger(shape), passenger, "The original body's inventory hid a second participant")
	shift.do_unshapeshift(shape)
	TEST_ASSERT_EQUAL(keeper.current, user, "Checking entry interfered with restoring the original body")

/// Installed inert brain mobs belong to a synthetic; a carried spare brain does not.
/datum/unit_test/vestige_ascension_synthetic/Run()
	var/mob/living/silicon/robot/robot = allocate(/mob/living/silicon/robot)
	TEST_ASSERT(robot.mmi?.brainmob, "The cyborg regression needs its actual installed MMI brain")
	TEST_ASSERT(!vestige_ascension_passenger(robot), "A cyborg's installed brain prevented solo entry")
	var/mob/living/carbon/human/android = allocate(/mob/living/carbon/human/consistent)
	android.set_species(/datum/species/android)
	TEST_ASSERT(!vestige_ascension_passenger(android), "Synthetic anatomy prevented solo entry")
	var/obj/item/mmi/spare = allocate(/obj/item/mmi, robot)
	var/mob/living/brain/spare_brain = allocate(/mob/living/brain, spare)
	spare.set_brainmob(spare_brain)
	TEST_ASSERT_EQUAL(vestige_ascension_passenger(robot), spare_brain, "A carried spare MMI bypassed the solo entry check")

/// Substitute input only: the real Activate chain still owns guards and cooldowns.
/datum/action/cooldown/spell/voice_of_the_word/unit_test_prompt
	var/prompt_behavior
	var/prompt_calls = 0
	var/cast_calls = 0
	var/nested_result
	var/mob/living/swap_to
	var/atom/last_cast_on

/datum/action/cooldown/spell/voice_of_the_word/unit_test_prompt/choose_command(mob/living/user)
	prompt_calls++
	switch(prompt_behavior)
		if("reenter")
			if(prompt_calls == 1)
				nested_result = Activate(user)
		if("cooldown", "cancel")
			StartCooldown(5 MINUTES)
		if("sleep")
			user.set_stat(UNCONSCIOUS)
		if("transfer")
			user.mind.transfer_to(swap_to)
	return prompt_behavior == "cancel" ? null : "HONK"

/datum/action/cooldown/spell/voice_of_the_word/unit_test_prompt/cast(atom/cast_on)
	// The regression concerns entering the cast chain, not honking at unrelated fixtures.
	cast_calls++
	last_cast_on = cast_on

/// A stale input cannot cast twice, refund another cast, or speak through an abandoned body.
/datum/unit_test/vestige_word_prompt_lifecycle/Run()
	var/mob/living/carbon/human/user = allocate(/mob/living/carbon/human/consistent)
	user.mind_initialize()
	var/mob/living/carbon/human/replacement = allocate(/mob/living/carbon/human/consistent)
	var/datum/action/cooldown/spell/voice_of_the_word/unit_test_prompt/word = allocate(/datum/action/cooldown/spell/voice_of_the_word/unit_test_prompt, user.mind)
	word.Grant(user)
	word.prompt_behavior = "reenter"
	TEST_ASSERT(word.Activate(user), "A valid selected order was rejected")
	TEST_ASSERT(!word.nested_result && word.prompt_calls == 1 && word.cast_calls == 1, "Two simultaneous prompts entered the Word's cast chain")
	TEST_ASSERT(word.next_use_time > world.time, "A successful order did not charge its cooldown")
	word.ResetCooldown()
	word.prompt_behavior = "cooldown"
	TEST_ASSERT(!word.Activate(user), "A selection bypassed a cooldown that began while its prompt slept")
	TEST_ASSERT_EQUAL(word.cast_calls, 1, "The stale order still reached cast")
	TEST_ASSERT(word.next_use_time >= world.time + 5 MINUTES, "The stale order shortened another cast's cooldown")
	word.ResetCooldown()
	word.prompt_behavior = "cancel"
	TEST_ASSERT(!word.Activate(user), "Canceling an order cast it")
	TEST_ASSERT(word.next_use_time >= world.time + 5 MINUTES, "Canceling an old prompt refunded another cast")
	word.ResetCooldown()
	word.prompt_behavior = "sleep"
	TEST_ASSERT(!word.Activate(user), "The Word cast after its owner became unconscious during input")
	user.set_stat(CONSCIOUS)
	word.prompt_behavior = "transfer"
	word.swap_to = replacement
	TEST_ASSERT(!word.Activate(user), "A stale prompt shouted through the old body after a mind transfer")
	TEST_ASSERT(word.owner == replacement && (word in replacement.actions), "Rejecting old input stripped the replacement body's valid action")
	word.prompt_behavior = null
	TEST_ASSERT(word.Activate(replacement), "The new owner could not make a fresh selection")
	TEST_ASSERT_EQUAL(word.last_cast_on, replacement, "The fresh order still cast through the old body")

/datum/action/cooldown/spell/machine_communion/unit_test_prompt
	var/prompt_behavior
	var/mob/living/swap_to

/datum/action/cooldown/spell/machine_communion/unit_test_prompt/choose_hack(mob/living/user, atom/cast_on, list/options)
	switch(prompt_behavior)
		if("sleep")
			user.set_stat(UNCONSCIOUS)
		if("cooldown")
			StartCooldown(5 MINUTES)
		if("transfer")
			user.mind.transfer_to(swap_to)
	return "Bolts"

/// Resolve a real door hack after changes that can happen while its radial is open.
/datum/unit_test/vestige_quickhack_prompt_lifecycle/Run()
	var/mob/living/carbon/human/user = allocate(/mob/living/carbon/human/consistent)
	user.mind_initialize()
	var/mob/living/carbon/human/replacement = allocate(/mob/living/carbon/human/consistent)
	var/obj/machinery/door/airlock/door = allocate(/obj/machinery/door/airlock, get_step(user, EAST))
	door.machine_stat = NONE
	door.locked = FALSE
	var/datum/action/cooldown/spell/machine_communion/unit_test_prompt/hack = allocate(/datum/action/cooldown/spell/machine_communion/unit_test_prompt, user.mind)
	hack.Grant(user)
	hack.prompt_behavior = "sleep"
	hack.open_hack_menu(door)
	TEST_ASSERT(!door.locked && !hack.next_use_time, "A quickhack executed after the caster lost consciousness")
	user.set_stat(CONSCIOUS)
	hack.prompt_behavior = "cooldown"
	hack.open_hack_menu(door)
	TEST_ASSERT(!door.locked, "A quickhack selection bypassed a cooldown begun during its radial")
	TEST_ASSERT(hack.next_use_time >= world.time + 5 MINUTES, "A stale quickhack changed another cast's cooldown")
	hack.ResetCooldown()
	hack.prompt_behavior = "transfer"
	hack.swap_to = replacement
	hack.open_hack_menu(door)
	TEST_ASSERT(!door.locked, "A stale quickhack executed through an abandoned body")
	TEST_ASSERT(hack.owner == replacement && HAS_TRAIT(replacement, TRAIT_AI_ACCESS) && !HAS_TRAIT(user, TRAIT_AI_ACCESS), "Mind transfer did not preserve only the new owner's machine access")
	hack.prompt_behavior = null
	hack.open_hack_menu(door)
	TEST_ASSERT(door.locked && hack.next_use_time > world.time, "A fresh quickhack from the replacement body failed to bolt the real door")

/datum/action/cooldown/spell/mass_hack/unit_test_prompt
	var/prompt_behavior
	var/mob/living/swap_to
	var/cast_calls = 0

/datum/action/cooldown/spell/mass_hack/unit_test_prompt/choose_hack(mob/living/user, list/options)
	switch(prompt_behavior)
		if("sleep")
			user.set_stat(UNCONSCIOUS)
		if("cooldown")
			StartCooldown(5 MINUTES)
		if("transfer")
			user.mind.transfer_to(swap_to)
	return "Overload the Room"

/datum/action/cooldown/spell/mass_hack/unit_test_prompt/cast(atom/cast_on)
	// Count the real cast dispatch without scheduling explosions across the test room.
	cast_calls++

/// A mass-hack radial cannot carry its authorization past sleep, cooldown or body transfer.
/datum/unit_test/vestige_masshack_prompt_lifecycle/Run()
	var/mob/living/carbon/human/user = allocate(/mob/living/carbon/human/consistent)
	user.mind_initialize()
	var/mob/living/carbon/human/replacement = allocate(/mob/living/carbon/human/consistent)
	allocate(/obj/machinery/door/airlock, get_step(user, EAST))
	var/datum/action/cooldown/spell/mass_hack/unit_test_prompt/hack = allocate(/datum/action/cooldown/spell/mass_hack/unit_test_prompt, user.mind)
	hack.Grant(user)
	hack.prompt_behavior = "sleep"
	TEST_ASSERT(!hack.Activate(user) && !hack.cast_calls, "A mass hack executed after its caster lost consciousness")
	user.set_stat(CONSCIOUS)
	hack.prompt_behavior = "cooldown"
	TEST_ASSERT(!hack.Activate(user) && !hack.cast_calls, "A mass-hack selection bypassed an active cooldown")
	TEST_ASSERT(hack.next_use_time >= world.time + 5 MINUTES, "A stale mass-hack selection changed another cast's cooldown")
	hack.ResetCooldown()
	hack.prompt_behavior = "transfer"
	hack.swap_to = replacement
	TEST_ASSERT(!hack.Activate(user) && !hack.cast_calls, "A mass hack executed after leaving its original body")
	TEST_ASSERT(hack.owner == replacement && (hack in replacement.actions), "Rejecting old input removed the new body's mass hack")
	hack.prompt_behavior = null
	TEST_ASSERT(hack.Activate(replacement) && hack.cast_calls == 1, "A fresh selection from the new body could not enter the mass-hack cast chain")

/// Death effects may be applied to corpses; only the successful death may roll boss loot.
/datum/unit_test/vestige_ascension_boss_death/Run()
	var/list/boss_loot = list(
		/mob/living/basic/vestige_oracle = /obj/item/clothing/head/oracle_hood,
		/mob/living/basic/vestige_mutant = /obj/item/clothing/neck/vestige_specimen_collar,
		/mob/living/basic/vestige_warframe = /obj/item/sparring_blade,
	)
	var/turf/floor = run_loc_floor_bottom_left
	for(var/boss_type in boss_loot)
		var/loot_type = boss_loot[boss_type]
		var/mob/living/basic/boss = allocate(boss_type, floor)
		var/before = length(floor.get_all_contents_type(loot_type))
		TEST_ASSERT(boss.death(), "[boss_type]'s first death failed")
		TEST_ASSERT_EQUAL(length(floor.get_all_contents_type(loot_type)), before + 1, "[boss_type]'s legitimate kill did not provide its guaranteed loot")
		TEST_ASSERT(!boss.death(), "[boss_type] reported another death after already dying")
		TEST_ASSERT_EQUAL(length(floor.get_all_contents_type(loot_type)), before + 1, "Applying death again to [boss_type] paid another loot roll")
		qdel(boss)

/// The defeated specimen cannot start another attack from an unfinished telegraph.
/datum/unit_test/vestige_ascension_mutant_pending_attacks/Run()
	var/mob/living/basic/vestige_mutant/boss = allocate(/mob/living/basic/vestige_mutant)
	var/mob/living/carbon/human/victor = allocate(/mob/living/carbon/human/consistent, get_step(boss, EAST))
	var/obj/item/crowbar/shot = allocate(/obj/item/crowbar, get_turf(boss))
	boss.begin_revision()
	boss.sweep.tracked_quarry = victor
	boss.sweep.lift_one(shot)
	boss.death()
	var/before = victor.health
	boss.sweep.fling_one(shot)
	TEST_ASSERT(!shot.throwing && !shot.get_filter("vestige_telekinesis"), "A dead specimen launched another sweep projectile or retained its ammunition booking")
	boss.pin.close_the_mark(get_turf(victor))
	TEST_ASSERT_EQUAL(victor.health, before, "A dead specimen completed its pin and damaged the victor")
	boss.confiscate.hand_it_back(shot, victor)
	TEST_ASSERT(!shot.throwing, "A dead specimen launched its confiscated weapon at the victor")

/// A finished match cannot turn a pending floor warning into a new damaging field.
/datum/unit_test/vestige_ascension_warframe_pending_floor/Run()
	var/mob/living/basic/vestige_warframe/boss = allocate(/mob/living/basic/vestige_warframe)
	var/turf/marked = get_step(boss, EAST)
	boss.live_floor.energise(list(marked))
	var/obj/effect/warframe_live_plate/live_plate = locate() in marked
	TEST_ASSERT(live_plate, "A living Warframe could not energise its marked floor")
	qdel(live_plate)
	boss.death()
	boss.live_floor.energise(list(marked))
	TEST_ASSERT(!(locate(/obj/effect/warframe_live_plate) in marked), "A dead Warframe turned a pending telegraph into new live floor")

/// A tracked boss must survive both transformation entry points and retain normal AI movement.
/datum/unit_test/vestige_ascension_boss_transform/Run()
	var/mob/living/carbon/human/user = allocate(/mob/living/carbon/human/consistent)
	user.mind_initialize()
	var/datum/vestige_ascension/offer = allocate(/datum/vestige_ascension/oracle)
	var/datum/vestige_ascension_run/run = allocate(/datum/vestige_ascension_run, offer, user)
	user.mind.active_ascension_run = run
	for(var/boss_type in list(/mob/living/basic/vestige_oracle, /mob/living/basic/vestige_mutant, /mob/living/basic/vestige_warframe))
		var/mob/living/basic/boss = allocate(boss_type, get_step(user, EAST))
		run.watch_boss(boss)
		var/datum/move_loop/has_target/dist_bound/movement = allocate(/datum/move_loop/has_target/dist_bound)
		movement.moving = boss
		movement.target = get_step(boss, NORTH)
		movement.extra_info = boss.ai_controller
		TEST_ASSERT(boss.ai_controller.ai_movement.allowed_to_move(movement), "Tracking [boss_type] disabled its AI movement")
		TEST_ASSERT(!boss.wabbajack(WABBAJACK_MONKEY), "Polymorph replaced the tracked [boss_type]")
		TEST_ASSERT(!boss.change_mob_type(/mob/living/basic/carp, get_turf(boss), delete_old_mob = TRUE), "A type change replaced the tracked [boss_type]")
		TEST_ASSERT(!QDELETED(boss) && run.boss == boss && !run.won, "A transformation broke the active boss encounter")
		TEST_ASSERT(boss.ai_controller.ai_movement.allowed_to_move(movement), "Rejecting transformation left [boss_type] unable to move")
		run.watch_boss(null)
		TEST_ASSERT(!(SEND_SIGNAL(boss, COMSIG_LIVING_PRE_WABBAJACKED) & STOP_WABBAJACK), "Untracking the boss retained the encounter's polymorph restriction")
		qdel(movement)
		qdel(boss)

/// Use the ordinary return path without reserving or releasing the shared test-room tiles.
/datum/vestige_ascension_run/unit_test_disappearance
	var/finish_calls = 0
	var/turf/fallback_turf

/datum/vestige_ascension_run/unit_test_disappearance/find_return_fallback()
	return fallback_turf

/datum/vestige_ascension_run/unit_test_disappearance/finish(reason)
	finish_calls++
	return ..()

/// Losing the encounter's only target returns its player and releases the run without paying a reward.
/datum/unit_test/vestige_ascension_boss_disappearance/Run()
	var/turf/home = run_loc_floor_bottom_left
	var/mob/living/carbon/human/user = allocate(/mob/living/carbon/human/consistent, home)
	user.mind_initialize()
	var/datum/mind/keeper = user.mind
	keeper.key = "vestige-boss-disappearance-unit-test"
	var/datum/vestige_record/record = get_vestige_record(keeper, create = TRUE)
	var/datum/vestige_ascension/offer = allocate(/datum/vestige_ascension/oracle)
	var/datum/vestige_ascension_run/unit_test_disappearance/run = allocate(/datum/vestige_ascension_run/unit_test_disappearance, offer, user)
	keeper.active_ascension_run = run
	var/datum/turf_reservation/reservation = allocate(/datum/turf_reservation/vestige_unit_test)
	run.reservation = reservation
	run.remember_origin(user)
	user.forceMove(get_step(home, EAST))
	reservation.bottom_left_turfs = list(get_turf(user))
	reservation.top_right_turfs = list(get_turf(user))
	var/mob/living/basic/boss = allocate(/mob/living/basic/vestige_oracle, get_step(user, EAST))
	run.watch_boss(boss)
	qdel(boss)
	// Defer reservation cleanup until the externally deleted boss's Destroy has returned.
	for(var/attempt in 1 to 10)
		if(QDELETED(run))
			break
		stoplag(1)
	TEST_ASSERT(QDELETED(run) && !keeper.active_ascension_run, "A missing boss left the player waiting for the normal time limit")
	TEST_ASSERT_EQUAL(run.finish_calls, 1, "Boss disappearance finished the run more than once")
	TEST_ASSERT(QDELETED(reservation), "Boss disappearance leaked the arena reservation")
	TEST_ASSERT(!QDELETED(user) && user.stat == CONSCIOUS && get_turf(user) == home, "Boss disappearance failed to return the intact supplicant")
	TEST_ASSERT(!record.ascension_boon && !length(record.boons) && !length(keeper.vestige_boons), "Deleting the boss awarded a capstone without defeating it")
	GLOB.vestige_records -= ckey(keeper.key)
	qdel(record)

/// Real containment checks on fixture tiles, without returning the shared test room to the allocator.
/datum/turf_reservation/vestige_unit_test/Release()
	bottom_left_turfs.Cut()
	top_right_turfs.Cut()
	reserved_turfs.Cut()
	cordon_turfs.Cut()

/// A late victory still receives an exit and grace if another encounter already settled the soul's capstone.
/datum/unit_test/vestige_ascension_existing_capstone_exit/Run()
	var/turf/home = run_loc_floor_bottom_left
	var/mob/living/carbon/human/user = allocate(/mob/living/carbon/human/consistent, home)
	user.mind_initialize()
	var/datum/mind/keeper = user.mind
	keeper.key = "vestige-existing-capstone-unit-test"
	var/datum/vestige_record/record = get_vestige_record(keeper, create = TRUE)
	var/previous_capstone = /datum/vestige_boon/spell/greater_telekinesis
	record.ascension_boon = previous_capstone
	record.boons |= previous_capstone
	var/datum/vestige_ascension/offer = allocate(/datum/vestige_ascension/oracle)
	var/datum/vestige_ascension_run/run = allocate(/datum/vestige_ascension_run, offer, user)
	keeper.active_ascension_run = run
	run.reservation = allocate(/datum/turf_reservation/vestige_unit_test)
	run.remember_origin(user)
	user.forceMove(get_step(home, EAST))
	run.reservation.bottom_left_turfs = list(get_turf(user))
	run.reservation.top_right_turfs = list(get_turf(user))
	run.watch_supplicant(user)
	var/mob/living/basic/vestige_oracle/boss = allocate(/mob/living/basic/vestige_oracle, get_step(user, EAST))
	run.watch_boss(boss)
	run.deadline_timer = addtimer(CALLBACK(run, TYPE_PROC_REF(/datum/vestige_ascension_run, on_deadline)), 10 SECONDS, TIMER_STOPPABLE)
	var/old_deadline = run.deadline_timer
	boss.death()
	for(var/attempt in 1 to 10)
		if(run.way_home)
			break
		stoplag(1)
	TEST_ASSERT(run.won && run.way_home?.run_ref.resolve() == run, "An already-paid soul's real boss kill did not open an exit")
	TEST_ASSERT(run.way_home.Adjacent(user), "The late victor's exit was not physically accessible")
	TEST_ASSERT(run.deadline_timer && run.deadline_timer != old_deadline && !timeleft(old_deadline), "The old encounter deadline was not replaced on late victory")
	// Keep in sync with the six-minute grace, whose define is included after unit tests.
	TEST_ASSERT(timeleft(run.deadline_timer) > 5 MINUTES && timeleft(run.deadline_timer) <= 6 MINUTES, "An already-paid soul did not receive the normal victory grace")
	TEST_ASSERT_EQUAL(record.ascension_boon, previous_capstone, "The late encounter replaced the soul's one capstone")
	TEST_ASSERT_EQUAL(length(record.boons), 1, "The late encounter added a second durable capstone")
	TEST_ASSERT(!length(keeper.vestige_boons) && !(locate(/datum/action/cooldown/spell/voice_of_the_word) in user.actions), "Opening the late victor's gate granted another capstone")
	run.finish("unit test completed")
	TEST_ASSERT(QDELETED(run) && get_turf(user) == home, "The late victor could not return home after receiving its exit")
	GLOB.vestige_records -= ckey(keeper.key)
	qdel(record)

/// Represent a movement refusal; the real run must verify where forceMove left its passenger.
/mob/living/carbon/human/consistent/vestige_return_test
	var/block_return = FALSE

/mob/living/carbon/human/consistent/vestige_return_test/forceMove(atom/destination)
	if(block_return)
		return FALSE
	return ..()

/// An origin marker follows the real shuttle-movement dispatch and cannot survive ruin deletion.
/datum/unit_test/vestige_ascension_return_origin/Run()
	var/turf/origin = run_loc_floor_bottom_left
	var/turf/arena_floor = get_step(origin, EAST)
	var/turf/moved_origin = get_step(origin, NORTH)
	var/mob/living/carbon/human/user = allocate(/mob/living/carbon/human/consistent, origin)
	user.mind_initialize()
	var/datum/vestige_ascension/offer = allocate(/datum/vestige_ascension/oracle)
	var/datum/vestige_ascension_run/unit_test_disappearance/run = allocate(/datum/vestige_ascension_run/unit_test_disappearance, offer, user)
	var/datum/turf_reservation/reservation = allocate(/datum/turf_reservation/vestige_unit_test)
	reservation.bottom_left_turfs = list(arena_floor)
	reservation.top_right_turfs = list(arena_floor)
	run.reservation = reservation
	run.remember_origin(user)
	var/obj/effect/vestige_trial_marker/marker = run.return_marker
	user.forceMove(arena_floor)
	marker.beforeShuttleMove(moved_origin, 180, MOVE_CONTENTS)
	marker.onShuttleMove(moved_origin, origin, list(), NORTH)
	marker.afterShuttleMove(origin, list(), SOUTH, NORTH, NORTH, 180)
	TEST_ASSERT(run.send_home(user) && get_turf(user) == moved_origin, "Returning used the old berth after its origin moved and rotated with a ship")
	user.forceMove(arena_floor)
	// Emptying a ruin deletes the marker; the same turf and area type can be reused immediately.
	moved_origin.empty(moved_origin.type)
	TEST_ASSERT(QDELETED(marker), "Clearing and reusing the origin turf did not remove its marker")
	TEST_ASSERT(!run.send_home(user), "A deleted origin marker returned the keeper to recycled ground")
	TEST_ASSERT_EQUAL(get_turf(user), arena_floor, "Failed origin recovery moved the keeper anyway")

/// The home vessel is found from the actual crew roster while the keeper stands off the ship.
/datum/unit_test/vestige_ascension_return_crew_ship/Run()
	var/turf/origin = run_loc_floor_bottom_left
	var/turf/arena_floor = get_step(origin, EAST)
	var/turf/old_deck = get_step(origin, NORTH)
	var/turf/new_deck = get_step(old_deck, EAST)
	var/mob/living/carbon/human/user = allocate(/mob/living/carbon/human/consistent, origin)
	user.mind_initialize()
	var/obj/structure/overmap/ship/ship = allocate(/obj/structure/overmap/ship)
	var/obj/docking_port/mobile/voidcrew/port = allocate(/obj/docking_port/mobile/voidcrew, old_deck)
	port.width = 1
	port.height = 1
	port.dwidth = 0
	port.dheight = 0
	port.current_ship = ship
	ship.shuttle = port
	var/datum/team/voidcrew/crew = allocate(/datum/team/voidcrew)
	crew.ship = ship
	user.mind.ship_teams = list(crew)
	TEST_ASSERT(!get_ship_from_atom(user), "The keeper must start off the ship for the crew fallback regression")
	var/datum/vestige_ascension/offer = allocate(/datum/vestige_ascension/oracle)
	var/datum/vestige_ascension_run/unit_test_disappearance/run = allocate(/datum/vestige_ascension_run/unit_test_disappearance, offer, user)
	var/datum/turf_reservation/reservation = allocate(/datum/turf_reservation/vestige_unit_test)
	reservation.bottom_left_turfs = list(arena_floor)
	reservation.top_right_turfs = list(arena_floor)
	run.reservation = reservation
	run.remember_origin(user)
	TEST_ASSERT_EQUAL(run.home_ship_ref?.resolve(), ship, "A keeper on ruin ground did not remember their registered crew ship")
	qdel(run.return_marker)
	user.forceMove(arena_floor)
	port.forceMove(new_deck)
	TEST_ASSERT(run.send_home(user) && get_turf(user) == new_deck, "An unloaded origin did not return the keeper to their vessel's current deck")
	ship.shuttle = null
	port.current_ship = null
	crew.ship = null

/// Invalid destinations and failed moves retain the living keeper and a retryable physical exit.
/datum/unit_test/vestige_ascension_return_failure
	var/area/forbidden_area
	var/area/original_area
	var/turf/forbidden_turf

/datum/unit_test/vestige_ascension_return_failure/Destroy()
	if(forbidden_turf && get_area(forbidden_turf) == forbidden_area)
		forbidden_turf.change_area(forbidden_area, original_area)
	QDEL_NULL(forbidden_area)
	return ..()

/datum/unit_test/vestige_ascension_return_failure/Run()
	var/turf/home = run_loc_floor_bottom_left
	var/turf/arena_floor = get_step(home, EAST)
	var/turf/other_arena = get_step(home, NORTH)
	var/mob/living/carbon/human/consistent/vestige_return_test/user = allocate(/mob/living/carbon/human/consistent/vestige_return_test, home)
	user.mind_initialize()
	var/datum/mind/keeper = user.mind
	var/datum/vestige_ascension/offer = allocate(/datum/vestige_ascension/oracle)
	var/datum/vestige_ascension_run/unit_test_disappearance/run = allocate(/datum/vestige_ascension_run/unit_test_disappearance, offer, user)
	keeper.active_ascension_run = run
	var/datum/turf_reservation/reservation = allocate(/datum/turf_reservation/vestige_unit_test)
	reservation.bottom_left_turfs = list(arena_floor)
	reservation.top_right_turfs = list(arena_floor)
	run.reservation = reservation
	run.remember_origin(user)
	user.forceMove(arena_floor)
	run.watch_supplicant(user)
	qdel(run.return_marker)
	run.fallback_turf = arena_floor
	TEST_ASSERT(!run.send_home(user), "A generic fallback was allowed to return the keeper into the arena being reclaimed")
	original_area = get_area(other_arena)
	forbidden_turf = other_arena
	// allocate() passes the test room's home turf as an atom's constructor loc, including areas.
	forbidden_area = new /area/ruin/space/has_grav/vestige/arena/oracle
	TEST_ASSERT_EQUAL(get_area(home), original_area, "Creating the forbidden area moved the safe exterior floor")
	other_arena.change_area(original_area, forbidden_area)
	run.fallback_turf = other_arena
	TEST_ASSERT(!run.send_home(user), "A generic fallback put the keeper into another NOTELEPORT arena")
	other_arena.change_area(forbidden_area, original_area)
	run.fallback_turf = home
	user.block_return = TRUE
	var/mob/living/basic/boss = allocate(/mob/living/basic/vestige_oracle, get_step(arena_floor, EAST))
	run.watch_boss(boss)
	TEST_ASSERT(!run.finish("unit test failed return"), "A failed forceMove was treated as a successful arena exit")
	TEST_ASSERT(!QDELETED(user) && user.stat == CONSCIOUS && get_turf(user) == arena_floor, "Failed return harmed or lost the supplicant")
	TEST_ASSERT(!QDELETED(run) && !QDELETED(reservation) && keeper.active_ascension_run == run, "Failed return released the occupied arena")
	TEST_ASSERT(run.awaiting_return && run.deadline_timer && !QDELETED(run.way_home), "Failed return did not offer and schedule another exit attempt")
	TEST_ASSERT(QDELETED(boss) && !run.boss && !run.won, "Failed return left a boss attacking or paid victory without a kill")
	TEST_ASSERT_EQUAL(run.watched_supplicant, user, "A failed return stopped watching the keeper's current body")
	user.block_return = FALSE
	TEST_ASSERT(run.safe_return_turf(home), "The retry fixture's exterior floor is no longer safe")
	TEST_ASSERT(!run.finishing, "The failed attempt retained its re-entry lock")
	TEST_ASSERT(run.way_home.Adjacent(user) && keeper.current == user && user.mind == keeper, "The retry fixture lost its gate adjacency or owning body")
	var/previous_attempts = run.finish_calls
	run.way_home.attack_hand(user, list())
	TEST_ASSERT_EQUAL(run.finish_calls, previous_attempts + 1, "The gate's real hand interaction did not attempt the retry")
	TEST_ASSERT_EQUAL(get_turf(user), home, "A retry through the gate did not return the intact keeper to the safe exterior floor")
	TEST_ASSERT(QDELETED(run), "Successful gate return left the run alive")
	TEST_ASSERT(QDELETED(reservation), "Successful gate return did not release its reservation")
	TEST_ASSERT(!keeper.active_ascension_run, "Successful retry retained the active run")

/// Every body admitted to the arena can take its own gate, using its actual unarmed dispatch.
/datum/unit_test/vestige_ascension_gate_bodies/Run()
	var/turf/arena_floor = run_loc_floor_bottom_left
	var/turf/home = get_step(arena_floor, NORTH)
	var/datum/vestige_ascension/offer = allocate(/datum/vestige_ascension/oracle)
	for(var/body_type in list(/mob/living/carbon/human/consistent, /mob/living/basic/carp, /mob/living/carbon/human/species/monkey, /mob/living/silicon/robot, /mob/living/carbon/alien/larva))
		var/mob/living/user = allocate(body_type, arena_floor)
		user.mind_initialize()
		var/datum/vestige_ascension_run/unit_test_disappearance/run = allocate(/datum/vestige_ascension_run/unit_test_disappearance, offer, user)
		var/datum/turf_reservation/reservation = allocate(/datum/turf_reservation/vestige_unit_test)
		reservation.bottom_left_turfs = list(arena_floor)
		reservation.top_right_turfs = list(arena_floor)
		run.reservation = reservation
		run.fallback_turf = home
		run.won = TRUE
		user.mind.active_ascension_run = run
		run.open_the_gate()
		var/obj/structure/vestige_way_home/gate = run.way_home
		user.set_stat(UNCONSCIOUS)
		user.UnarmedAttack(gate, TRUE, list())
		TEST_ASSERT(!QDELETED(run), "An unconscious [body_type] entered the exit")
		user.set_stat(CONSCIOUS)
		if(iscyborg(user))
			user.forceMove(get_step(get_step(arena_floor, EAST), EAST))
			gate.attack_robot(user, list())
			TEST_ASSERT(!QDELETED(run), "A remote silicon click entered a physical doorway")
			user.forceMove(arena_floor)
		user.UnarmedAttack(gate, TRUE, list())
		TEST_ASSERT(QDELETED(run) && get_turf(user) == home, "[body_type]'s normal unarmed click could not take the offered exit")
		qdel(user)

/// A defeated Oracle cannot keep walking its victor toward the corpse; a name on the floor still can call.
/datum/unit_test/vestige_ascension_called_after_death/Run()
	var/turf/floor = run_loc_floor_bottom_left
	var/mob/living/carbon/human/user = allocate(/mob/living/carbon/human/consistent, floor)
	var/turf/caller_floor = get_step(get_step(floor, EAST), EAST)
	var/mob/living/basic/vestige_oracle/boss = allocate(/mob/living/basic/vestige_oracle, caller_floor)
	var/datum/status_effect/oracle_called/summons = user.apply_status_effect(/datum/status_effect/oracle_called, boss)
	TEST_ASSERT(summons, "A living Oracle could not apply its call")
	boss.death()
	summons.tick(1)
	TEST_ASSERT(QDELETED(summons) && get_turf(user) == floor, "The dead Oracle continued pulling its victor")
	qdel(boss)
	var/obj/structure/borrowed_name/name = allocate(/obj/structure/borrowed_name, caller_floor)
	summons = user.apply_status_effect(/datum/status_effect/oracle_called, name)
	summons.tick(1)
	TEST_ASSERT(!QDELETED(summons) && get_turf(user) == get_step(floor, EAST), "Ending a dead Oracle's call broke the nonmob borrowed-name caller")
	qdel(name)
	summons.tick(1)
	TEST_ASSERT(QDELETED(summons), "A deleted borrowed name retained its forced-walking effect")

/// Guard and live floor stop with their boss, while deployed player mines keep their own lifespan.
/datum/unit_test/vestige_ascension_warframe_after_death/Run()
	var/mob/living/basic/vestige_warframe/boss = allocate(/mob/living/basic/vestige_warframe)
	var/mob/living/carbon/human/user = allocate(/mob/living/carbon/human/consistent, get_step(boss, EAST))
	var/datum/status_effect/warframe_guard/guard = boss.apply_status_effect(/datum/status_effect/warframe_guard)
	TEST_ASSERT(boss.is_guarding(), "The live Warframe could not raise guard")
	var/obj/effect/warframe_live_plate/boss_plate = allocate(/obj/effect/warframe_live_plate, get_step(boss, NORTH), boss)
	var/obj/effect/warframe_live_plate/player_plate = allocate(/obj/effect/warframe_live_plate, get_step(user, NORTH), user)
	boss.death()
	var/before = user.health
	TEST_ASSERT(!boss.is_guarding() && !boss.check_block(user, 10), "A dead Warframe continued blocking attacks")
	guard.deflect(user, "a late strike")
	TEST_ASSERT_EQUAL(user.health, before, "The Warframe corpse riposted against its victor")
	TEST_ASSERT(QDELETED(boss_plate), "The boss's live floor remained energized after victory")
	user.death()
	TEST_ASSERT(!QDELETED(player_plate), "Boss field cleanup incorrectly removed a dead player's deployed mine")
	var/mob/living/basic/vestige_warframe/removed_boss = allocate(/mob/living/basic/vestige_warframe)
	var/obj/effect/warframe_live_plate/removed_plate = allocate(/obj/effect/warframe_live_plate, get_step(removed_boss, NORTH), removed_boss)
	qdel(removed_boss)
	TEST_ASSERT(QDELETED(removed_plate), "Removing an unfinished encounter left its boss's floor energized")

/// The real held actuator finishes a normal cut but cannot resume stale steps after an arena exit.
/datum/unit_test/vestige_ascension_actuator_relocation/Run()
	var/turf/start = run_loc_floor_bottom_left
	var/turf/first_step = get_step(start, EAST)
	var/turf/last_step = get_step(first_step, EAST)
	var/turf/home = get_step(start, NORTH)
	var/mob/living/carbon/human/user = allocate(/mob/living/carbon/human/consistent, start)
	user.mind_initialize()
	var/obj/item/warframe_actuator/actuator = allocate(/obj/item/warframe_actuator)
	user.put_in_hands(actuator)
	var/datum/action/cooldown/mob_cooldown/warframe_iai/held/cut = locate() in user.actions
	TEST_ASSERT(cut, "Holding the real actuator did not grant Drawn Cut")
	TEST_ASSERT(cut.Activate(last_step), "The held actuator could not start a valid cut")
	stoplag(0.5 SECONDS)
	TEST_ASSERT_EQUAL(get_turf(user), last_step, "The ordinary timed cut stopped before its endpoint")
	user.forceMove(start)
	cut.ResetCooldown()
	var/datum/vestige_ascension/offer = allocate(/datum/vestige_ascension/warframe)
	var/datum/vestige_ascension_run/unit_test_disappearance/run = allocate(/datum/vestige_ascension_run/unit_test_disappearance, offer, user)
	var/datum/turf_reservation/reservation = allocate(/datum/turf_reservation/vestige_unit_test)
	reservation.bottom_left_turfs = list(start)
	reservation.top_right_turfs = list(last_step)
	run.reservation = reservation
	run.fallback_turf = home
	run.won = TRUE
	user.mind.active_ascension_run = run
	run.open_the_gate()
	TEST_ASSERT(cut.Activate(last_step) && get_turf(user) == first_step, "The relocation regression did not reach the timed half of a real cut")
	run.way_home.attack_hand(user, list())
	TEST_ASSERT(QDELETED(run) && get_turf(user) == home, "The gate did not return the player between cut steps")
	stoplag(0.5 SECONDS)
	TEST_ASSERT_EQUAL(get_turf(user), home, "A pending actuator step pulled the victor back into the reclaimed arena")
	user.forceMove(start)
	cut.ResetCooldown()
	TEST_ASSERT(cut.Activate(last_step), "The actuator did not remain usable after canceling a relocated cut")
	user.beforeShuttleMove(home, 180, MOVE_CONTENTS)
	user.onShuttleMove(home, first_step, list(), NORTH)
	user.afterShuttleMove(first_step, list(), SOUTH, NORTH, NORTH, 180)
	stoplag(0.5 SECONDS)
	TEST_ASSERT_EQUAL(get_turf(user), home, "A pending actuator step returned its passenger to the ship's departed berth")
	user.forceMove(start)
	cut.ResetCooldown()
	TEST_ASSERT(cut.Activate(last_step), "The actuator did not start its holder-transfer regression")
	var/mob/living/carbon/human/recipient = allocate(/mob/living/carbon/human/consistent, home)
	user.dropItemToGround(actuator)
	recipient.put_in_hands(actuator)
	TEST_ASSERT_EQUAL(cut.owner, recipient, "Moving the real actuator did not transfer its granted action")
	stoplag(0.5 SECONDS)
	TEST_ASSERT(get_turf(recipient) == home && get_turf(user) == first_step, "A pending cut moved its new holder or continued through the abandoned holder")

/// Use the allocator's real padding and cordon, retaining original areas for fixture cleanup.
/datum/unit_test/vestige_ascension_arena_boundaries
	var/datum/turf_reservation/reserved
	var/area/arena_area
	var/list/original_areas = list()

/datum/unit_test/vestige_ascension_arena_boundaries/Destroy()
	for(var/turf/changed as anything in original_areas)
		if(get_area(changed) == arena_area)
			changed.change_area(arena_area, original_areas[changed])
	QDEL_NULL(arena_area)
	QDEL_NULL(reserved)
	return ..()

/datum/unit_test/vestige_ascension_arena_boundaries/Run()
	var/pad = 3 // Keep in sync with VESTIGE_ASCENSION_ARENA_PADDING, defined after unit-test includes.
	reserved = SSmapping.request_turf_block_reservation(1 + 2 * pad, 1 + 2 * pad, 1)
	TEST_ASSERT(reserved, "Could not allocate the arena boundary fixture")
	var/turf/margin = reserved.bottom_left_turfs[1]
	var/turf/top_right = reserved.top_right_turfs[1]
	initialize_uninitialized_block_turfs(margin, top_right)
	for(var/turf/interior as anything in block(margin, top_right))
		original_areas[interior] = get_area(interior)
	var/turf/footprint = locate(margin.x + pad, margin.y + pad, margin.z)
	arena_area = new /area/ruin/space/has_grav/vestige/arena/oracle
	footprint.change_area(get_area(footprint), arena_area)
	var/turf/home = run_loc_floor_bottom_left
	var/mob/living/carbon/human/user = allocate(/mob/living/carbon/human/consistent, home)
	user.mind_initialize()
	var/datum/vestige_ascension/offer = allocate(/datum/vestige_ascension/oracle)
	var/datum/vestige_ascension_run/run = allocate(/datum/vestige_ascension_run, offer, user)
	run.reservation = reserved
	run.arena_bottom_left = footprint
	user.forceMove(margin)
	TEST_ASSERT_EQUAL(get_turf(user), margin, "The allocator fixture did not place its keeper on the margin")
	var/area/origin_area = get_area(margin)
	var/area/home_area = get_area(home)
	TEST_ASSERT(check_teleport_valid(user, home, TELEPORT_CHANNEL_MAGIC), "The initial margin was refused: origin [origin_area.type] flags=[origin_area.area_flags], destination [home_area.type] flags=[home_area.area_flags], no-teleport trait=[HAS_TRAIT(user, TRAIT_NO_TELEPORT)], VR origin=[SSbitrunning.is_domain_turf(margin)], VR destination=[SSbitrunning.is_domain_turf(home)]")
	TEST_ASSERT(run.extend_arena_area(), "The arena could not protect its reservation margin")
	TEST_ASSERT(!check_teleport_valid(user, home, TELEPORT_CHANNEL_MAGIC), "A breached wall still exposed a teleport escape through the reservation margin")
	var/turf/cordon = get_step(margin, WEST)
	TEST_ASSERT(istype(cordon, /turf/cordon) && istype(get_area(cordon), /area/misc/cordon), "Extending the arena overwrote the allocator's physical cordon")
	TEST_ASSERT(!user.Move(cordon, WEST) && get_turf(user) == margin && !QDELETED(user), "A keeper could walk from the margin through the allocator's cordon")
	user.forceMove(home)
	TEST_ASSERT(!check_teleport_valid(user, margin, TELEPORT_CHANNEL_MAGIC), "An outsider could teleport into the margin and walk through a breached arena wall")
	qdel(run)

/// Two real allocator-owned regions on one z-level must keep their hall levers independent.
/datum/unit_test/vestige_ascension_hall_gate_regions
	var/datum/turf_reservation/first_region
	var/datum/turf_reservation/second_region

/datum/unit_test/vestige_ascension_hall_gate_regions/Destroy()
	QDEL_NULL(first_region)
	QDEL_NULL(second_region)
	return ..()

/datum/unit_test/vestige_ascension_hall_gate_regions/Run()
	first_region = SSmapping.request_turf_block_reservation(3, 3, 1)
	TEST_ASSERT(first_region, "Could not allocate the first hall fixture")
	var/turf/first_floor = first_region.bottom_left_turfs[1]
	second_region = SSmapping.request_turf_block_reservation(3, 3, 1, first_floor.z)
	TEST_ASSERT(second_region, "Could not allocate a second hall on the same reserved level")
	var/turf/second_floor = second_region.bottom_left_turfs[1]
	initialize_uninitialized_block_turfs(first_floor, first_region.top_right_turfs[1])
	initialize_uninitialized_block_turfs(second_floor, second_region.top_right_turfs[1])
	var/obj/structure/warframe_lever/gate/lever = allocate(/obj/structure/warframe_lever/gate, first_floor)
	var/obj/structure/warframe_gate/near_gate = allocate(/obj/structure/warframe_gate, get_step(first_floor, EAST))
	var/obj/structure/warframe_gate/other_own_gate = allocate(/obj/structure/warframe_gate, get_step(first_floor, NORTH))
	var/obj/structure/warframe_gate/foreign_gate = allocate(/obj/structure/warframe_gate, second_floor)
	var/turf/home = run_loc_floor_bottom_left
	var/mob/living/carbon/human/user = allocate(/mob/living/carbon/human/consistent, first_floor)
	TEST_ASSERT(first_floor.z == second_floor.z && !map_regions_match(first_floor, second_floor), "The regression needs separate real reservations sharing a z-level")
	lever.attack_hand(user, list())
	TEST_ASSERT(near_gate.raised && other_own_gate.raised, "The hall lever failed to raise both gates belonging to its own arena")
	TEST_ASSERT(!foreign_gate.raised, "A hall lever opened another player's arena on the same reserved z-level")
	user.forceMove(home)

/// The stock transfer path must reattach before moving, including when two existing orbits merge.
/datum/unit_test/vestige_orbiter_transfer/Run()
	var/turf/floor = run_loc_floor_bottom_left
	for(var/merge_existing in list(FALSE, TRUE))
		var/obj/item/crowbar/old_anchor = allocate(/obj/item/crowbar, floor)
		var/obj/item/crowbar/new_anchor = allocate(/obj/item/crowbar, get_step(floor, EAST))
		var/obj/item/screwdriver/traveler = allocate(/obj/item/screwdriver, floor)
		var/obj/item/wrench/resident
		traveler.orbit(old_anchor)
		var/datum/component/orbiter/old_orbit = traveler.orbiting
		TEST_ASSERT(old_orbit?.parent == old_anchor, "The stock orbiter fixture did not begin orbiting")
		if(merge_existing)
			resident = allocate(/obj/item/wrench, get_turf(new_anchor))
			resident.orbit(new_anchor)
		old_anchor.transfer_observers_to(new_anchor)
		TEST_ASSERT(!old_anchor.orbiters, "Transfer left an orbiter component registered to the old anchor")
		TEST_ASSERT(traveler.orbiting?.parent == new_anchor, "Transfer ended the existing orbit while its parent was detached")
		TEST_ASSERT_EQUAL(get_turf(traveler), get_turf(new_anchor), "Transfer did not immediately resynchronize the orbiter's location")
		if(merge_existing)
			TEST_ASSERT(QDELETED(old_orbit), "Merging two orbits leaked the detached component")
			TEST_ASSERT(resident.orbiting == traveler.orbiting, "Merging lost the destination's existing orbiter")
		new_anchor.forceMove(get_step(get_turf(new_anchor), NORTH))
		TEST_ASSERT_EQUAL(get_turf(traveler), get_turf(new_anchor), "The transferred orbiter stopped following movement")
		if(resident)
			TEST_ASSERT_EQUAL(get_turf(resident), get_turf(new_anchor), "Merging stopped the resident orbiter from following movement")
		traveler.forceMove(floor)
		TEST_ASSERT(!traveler.orbiting && !HAS_TRAIT(traveler, TRAIT_NO_FLOATING_ANIM), "A transferred orbiter could not leave and clean up normally")
		if(resident)
			resident.forceMove(floor)
			TEST_ASSERT(!resident.orbiting, "The merged resident could not leave its orbit")
		TEST_ASSERT(!new_anchor.orbiters, "Removing every transferred orbiter leaked its component")
		qdel(old_anchor)
		qdel(new_anchor)
		qdel(traveler)
		QDEL_NULL(resident)

/// Mind transfer removes field signals from the body that registered them, not the new action owner.
/datum/unit_test/vestige_telekinesis_body_transfer/Run()
	var/turf/old_floor = run_loc_floor_bottom_left
	var/turf/new_floor = get_step(get_step(old_floor, NORTH), NORTH)
	var/mob/living/carbon/human/old_body = allocate(/mob/living/carbon/human/consistent, old_floor)
	var/mob/living/carbon/human/new_body = allocate(/mob/living/carbon/human/consistent, new_floor)
	var/mob/living/carbon/human/captive = allocate(/mob/living/carbon/human/consistent, get_step(new_floor, EAST))
	old_body.mind_initialize()
	var/datum/mind/keeper = old_body.mind
	var/datum/action/cooldown/spell/greater_telekinesis/field = allocate(/datum/action/cooldown/spell/greater_telekinesis, keeper)
	field.Grant(old_body)
	field.start_lifting()
	var/obj/item/crowbar/old_held = allocate(/obj/item/crowbar, get_step(old_floor, EAST))
	old_body.next_click = -1
	old_body.ClickOn(old_held, "")
	TEST_ASSERT(old_held in field.lifted, "The original body could not lift through its real click dispatch")
	keeper.transfer_to(new_body)
	TEST_ASSERT(field.owner == new_body && !field.lifting && !old_held.orbiting, "Mind transfer did not release the original body's field")
	field.start_lifting()
	new_body.next_click = -1
	new_body.ClickOn(captive, "")
	TEST_ASSERT(captive in field.lifted, "The replacement body could not raise a fresh field")
	old_body.next_click = -1
	old_body.ClickOn(old_held, "")
	TEST_ASSERT(!(old_held in field.lifted), "The abandoned body's click still controlled the replacement body's telekinesis")
	old_body.death()
	TEST_ASSERT(field.lifting, "The abandoned body's death shut down the replacement body's field")
	TEST_ASSERT(captive in field.lifted, "The abandoned body's death released the replacement body's captive")
	TEST_ASSERT_EQUAL(captive.orbiting?.parent, new_body, "The replacement body's captive was not orbiting its current caster")
	field.stop_lifting(silent = TRUE)
	TEST_ASSERT(!captive.orbiting && !HAS_TRAIT(captive, TRAIT_IMMOBILIZED), "Releasing the transferred field stranded its captive")

/// A new caster's hold must survive the previous orbit's real cleanup callbacks.
/datum/unit_test/vestige_telekinesis_handoff/Run()
	var/turf/floor = run_loc_floor_bottom_left
	var/mob/living/carbon/human/first = allocate(/mob/living/carbon/human/consistent, floor)
	var/mob/living/carbon/human/second = allocate(/mob/living/carbon/human/consistent, get_step(floor, EAST))
	var/mob/living/carbon/human/captive = allocate(/mob/living/carbon/human/consistent, get_step(floor, NORTH))
	var/datum/action/cooldown/spell/greater_telekinesis/first_field = allocate(/datum/action/cooldown/spell/greater_telekinesis, first)
	var/datum/action/cooldown/spell/greater_telekinesis/second_field = allocate(/datum/action/cooldown/spell/greater_telekinesis, second)
	first_field.Grant(first)
	second_field.Grant(second)
	first_field.start_lifting()
	second_field.start_lifting()
	first.next_click = -1
	first.ClickOn(captive, "")
	TEST_ASSERT(captive in first_field.lifted, "The first caster did not establish its hold")
	TEST_ASSERT(HAS_TRAIT(captive, TRAIT_IMMOBILIZED), "The first caster's hold did not immobilize its captive")
	second.next_click = -1
	second.ClickOn(captive, "")
	TEST_ASSERT(!(captive in first_field.lifted), "The real orbiter handoff left the captive in the first caster's field")
	TEST_ASSERT(captive in second_field.lifted, "The real orbiter handoff did not add the captive to the second caster's field")
	TEST_ASSERT_EQUAL(captive.orbiting?.parent, second, "The real orbiter handoff did not transfer the held creature")
	TEST_ASSERT(HAS_TRAIT(captive, TRAIT_IMMOBILIZED), "The first caster's cleanup removed the second caster's immobilization")
	TEST_ASSERT(captive.get_filter("vestige_telekinesis"), "The first caster's cleanup removed the new hold's outline")
	captive.execute_resist()
	TEST_ASSERT(!(captive in second_field.lifted) && !captive.orbiting && !HAS_TRAIT(captive, TRAIT_IMMOBILIZED), "The captive could not resist free after a hold changed casters")

/// The real sleeping rip cannot resume from its former body or cancel a replacement channel.
/datum/unit_test/vestige_telekinesis_rip_transfer/Run()
	var/turf/floor = run_loc_floor_bottom_left
	var/mob/living/carbon/human/old_body = allocate(/mob/living/carbon/human/consistent, floor)
	var/mob/living/carbon/human/new_body = allocate(/mob/living/carbon/human/consistent, get_step(floor, NORTH))
	old_body.mind_initialize()
	var/datum/action/cooldown/spell/greater_telekinesis/field = allocate(/datum/action/cooldown/spell/greater_telekinesis, old_body.mind)
	field.Grant(old_body)
	field.start_lifting()
	var/obj/structure/table/old_table = allocate(/obj/structure/table, get_step(floor, EAST))
	var/obj/structure/table/new_table = allocate(/obj/structure/table, get_step(new_body, EAST))
	old_body.next_click = -1
	old_body.ClickOn(old_table, "")
	TEST_ASSERT_EQUAL(field.ripping, old_table, "The old body's actual click did not begin the rip channel")
	old_body.mind.transfer_to(new_body)
	field.start_lifting()
	new_body.next_click = -1
	new_body.ClickOn(new_table, "")
	TEST_ASSERT_EQUAL(field.ripping, new_table, "The new body could not begin its own channel after transfer")
	stoplag(6 SECONDS)
	TEST_ASSERT(old_table.anchored && !(old_table in field.lifted), "A pre-transfer rip completed through the abandoned body")
	TEST_ASSERT(!new_table.anchored, "The new body's legitimate rip did not finish tearing its table loose")
	TEST_ASSERT(new_table in field.lifted, "The new body's legitimate rip did not raise its table")
	TEST_ASSERT_EQUAL(new_table.orbiting?.parent, new_body, "The new body's ripped table did not orbit its current caster")

/// Damage follows the real item warning's moved tile, and deleting that tile's marker cancels it.
/datum/unit_test/vestige_warning_transit
	abstract_type = /datum/unit_test/vestige_warning_transit
	var/item_type
	var/action_type
	var/visual_type

/datum/unit_test/vestige_warning_transit/palm_anchor
	item_type = /obj/item/vestige_palm_anchor
	action_type = /datum/action/cooldown/mob_cooldown/vestige_tk/pin/anchor
	visual_type = /obj/effect/temp_visual/vestige_pin_mark

/datum/unit_test/vestige_warning_transit/oracle_slate
	item_type = /obj/item/oracle_slate
	action_type = /datum/action/cooldown/mob_cooldown/oracle_word/antiphon/slate
	visual_type = /obj/effect/temp_visual/oracle_glyph

/datum/unit_test/vestige_warning_transit/Run()
	var/turf/floor = run_loc_floor_bottom_left
	var/turf/caster_floor = get_step(get_step(floor, NORTH), EAST)
	var/turf/marked_floor = get_step(caster_floor, EAST)
	var/turf/moved_floor = get_step(get_step(caster_floor, NORTH), NORTH)
	moved_floor = get_step(get_step(moved_floor, EAST), EAST)
	var/mob/living/carbon/human/user = allocate(/mob/living/carbon/human/consistent, caster_floor)
	var/mob/living/carbon/human/old_bystander = allocate(/mob/living/carbon/human/consistent, marked_floor)
	var/mob/living/carbon/human/new_bystander = allocate(/mob/living/carbon/human/consistent, moved_floor)
	var/obj/item/instrument = allocate(item_type)
	user.put_in_hands(instrument)
	var/datum/action/cooldown/ability = locate(action_type) in user.actions
	TEST_ASSERT(ability, "The real [item_type] did not grant its action")
	TEST_ASSERT(ability.Activate(marked_floor), "The real [item_type] could not begin its warning")
	var/obj/effect/vestige_trial_marker/marker = locate() in marked_floor
	var/obj/effect/warning = locate(visual_type) in marked_floor
	TEST_ASSERT(marker && warning, "The real warning did not retain its marked physical tile")
	for(var/atom/movable/moving as anything in list(marker, warning))
		moving.beforeShuttleMove(moved_floor, 180, MOVE_CONTENTS)
		moving.onShuttleMove(moved_floor, marked_floor, list(), NORTH)
		moving.afterShuttleMove(marked_floor, list(), SOUTH, NORTH, NORTH, 180)
	TEST_ASSERT(get_turf(marker) == moved_floor && get_turf(warning) == moved_floor, "The warning and its physical tile did not take the same real shuttle transform")
	var/old_health = old_bystander.health
	var/new_health = new_bystander.health
	stoplag(2 SECONDS)
	TEST_ASSERT_EQUAL(old_bystander.health, old_health, "A delayed [item_type] hit an unmarked bystander at the departed berth")
	TEST_ASSERT(new_bystander.health < new_health, "A delayed [item_type] missed the bystander standing on its moved warning")
	TEST_ASSERT(QDELETED(marker), "Resolving the warning leaked its physical marker")
	ability.ResetCooldown()
	TEST_ASSERT(ability.Activate(marked_floor), "The item could not begin its deletion regression")
	marker = locate(/obj/effect/vestige_trial_marker) in marked_floor
	TEST_ASSERT(marker, "The second warning did not mark its tile")
	qdel(marker)
	old_health = old_bystander.health
	stoplag(2 SECONDS)
	TEST_ASSERT_EQUAL(old_bystander.health, old_health, "A removed warning marker left delayed damage at its old coordinates")

/// Destroying a real harness releases its bookings without stripping a newer field's hold.
/datum/unit_test/vestige_debris_harness_booking_cleanup/Run()
	var/turf/floor = run_loc_floor_bottom_left
	var/mob/living/carbon/human/user = allocate(/mob/living/carbon/human/consistent, floor)
	var/mob/living/carbon/human/target = allocate(/mob/living/carbon/human/consistent, get_step(get_step(floor, EAST), EAST))
	var/obj/item/vestige_debris_harness/harness = allocate(/obj/item/vestige_debris_harness)
	user.put_in_hands(harness)
	var/datum/action/cooldown/mob_cooldown/vestige_tk/sweep/harness/sweep = locate() in user.actions
	TEST_ASSERT(sweep, "The real held debris harness did not grant its sweep")
	var/obj/item/crowbar/free_ammo = allocate(/obj/item/crowbar, get_step(floor, NORTH))
	var/obj/item/wrench/taken_ammo = allocate(/obj/item/wrench, get_step(floor, EAST))
	TEST_ASSERT(sweep.Activate(target), "The real debris harness did not begin a volley")
	TEST_ASSERT(free_ammo in sweep.booked_ammunition, "The volley did not book its loose crowbar")
	TEST_ASSERT(taken_ammo in sweep.booked_ammunition, "The volley did not book its loose wrench")
	// Rebuilding render filters must not make us lose ownership of our unchanged parameter list.
	free_ammo.add_filter("unit_test_other_outline", 1, list("type" = "outline", "color" = COLOR_RED, "size" = 1))
	var/datum/action/cooldown/spell/greater_telekinesis/field = allocate(/datum/action/cooldown/spell/greater_telekinesis, user)
	field.Grant(user)
	field.start_lifting()
	user.next_click = -1
	user.ClickOn(taken_ammo, "")
	TEST_ASSERT(taken_ammo in field.lifted, "A real telekinetic grab could not take the winding-up ammunition")
	qdel(harness)
	TEST_ASSERT(QDELETED(sweep), "Deleting the real harness did not delete its granted action")
	TEST_ASSERT(!free_ammo.get_filter("vestige_telekinesis"), "Deleting the harness stranded its surviving ammunition outline")
	TEST_ASSERT(free_ammo.get_filter("unit_test_other_outline"), "Sweep cleanup removed an unrelated effect")
	TEST_ASSERT(taken_ammo.get_filter("vestige_telekinesis") && taken_ammo.orbiting?.parent == user, "Sweep cleanup stripped the newer telekinetic hold")
	var/obj/item/vestige_debris_harness/replacement = allocate(/obj/item/vestige_debris_harness)
	user.put_in_hands(replacement)
	var/datum/action/cooldown/mob_cooldown/vestige_tk/sweep/harness/retry = locate() in user.actions
	TEST_ASSERT(retry && retry != sweep && retry.Activate(target), "A replacement harness could not retry with the released floor ammunition")
	TEST_ASSERT(free_ammo in retry.booked_ammunition, "The deleted harness left its old ammunition unavailable to the next sweep")
	user.next_click = -1
	user.ClickOn(free_ammo, "")
	TEST_ASSERT(free_ammo in field.lifted, "The new field could not take the retry's ammunition before launch")
	stoplag(retry.telegraph_time + retry.stagger_time + 1 SECONDS)
	TEST_ASSERT(free_ammo in field.lifted, "The old sweep callback stole ammunition from a newer telekinetic field")
	TEST_ASSERT(free_ammo.get_filter("vestige_telekinesis") && free_ammo.orbiting?.parent == user && !free_ammo.throwing, "The expired sweep booking changed a newer hold's outline or momentum")
	field.stop_lifting(silent = TRUE)
	TEST_ASSERT(!free_ammo.get_filter("vestige_telekinesis") && !taken_ammo.get_filter("vestige_telekinesis"), "The real field could not clean up after the old sweep bookings expired")

/// The two hall controls share physical interaction rules across every admitted body.
/datum/unit_test/vestige_warframe_lever_bodies/Run()
	var/turf/floor = run_loc_floor_bottom_left
	for(var/body_type in list(/mob/living/carbon/human/consistent, /mob/living/basic/carp, /mob/living/carbon/human/species/monkey, /mob/living/silicon/robot, /mob/living/carbon/alien/larva))
		var/obj/structure/warframe_lever/lever = allocate(/obj/structure/warframe_lever, floor)
		var/mob/living/user = allocate(body_type, get_step(floor, EAST))
		user.set_stat(UNCONSCIOUS)
		user.UnarmedAttack(lever, TRUE, list())
		TEST_ASSERT(!lever.pulled, "An unconscious [body_type] pulled a hall lever")
		user.set_stat(CONSCIOUS)
		user.forceMove(get_step(get_step(floor, EAST), EAST))
		if(iscyborg(user))
			lever.attack_robot(user, list())
		else
			lever.pull_lever(user)
		TEST_ASSERT(!lever.pulled, "A distant [body_type] operated a physical hall lever")
		user.forceMove(get_step(floor, EAST))
		user.UnarmedAttack(lever, TRUE, list())
		TEST_ASSERT(lever.pulled, "[body_type]'s real unarmed click could not pull the hall controls")
		qdel(user)
		qdel(lever)

/// Two rooms separated by real opaque walls distinguish the charged deck from its departed berth.
/datum/unit_test/vestige_communion_arc_movement
	var/list/wall_types = list()

/datum/unit_test/vestige_communion_arc_movement/Destroy()
	for(var/turf/wall as anything in wall_types)
		wall.ChangeTurf(wall_types[wall])
	return ..()

/datum/unit_test/vestige_communion_arc_movement/Run()
	var/turf/old_center = run_loc_floor_bottom_left
	var/turf/new_center = run_loc_floor_top_right
	for(var/y_coord in old_center.y to new_center.y)
		var/turf/divider = locate(old_center.x + 2, y_coord, old_center.z)
		wall_types[divider] = divider.type
		divider.ChangeTurf(/turf/closed/indestructible)
	var/mob/living/carbon/human/caster = allocate(/mob/living/carbon/human/consistent, old_center)
	var/mob/living/carbon/human/old_bystander = allocate(/mob/living/carbon/human/consistent, get_step(old_center, NORTH))
	var/mob/living/carbon/human/new_bystander = allocate(/mob/living/carbon/human/consistent, get_step(new_center, SOUTH))
	var/obj/machinery/photocopier/old_machine = allocate(/obj/machinery/photocopier, get_step(old_center, EAST))
	var/obj/machinery/photocopier/new_machine = allocate(/obj/machinery/photocopier, get_step(new_center, WEST))
	TEST_ASSERT(old_machine.is_operational && new_machine.is_operational, "Arc regression requires powered machines in both rooms")
	TEST_ASSERT(!can_see(old_center, new_center, 9), "The separated rooms must not share an arc's sightline")
	var/datum/machine_masshack/arc_flash/hack = allocate(/datum/machine_masshack/arc_flash)
	TEST_ASSERT(hack.execute(caster, old_center), "The actual Arc Flash could not charge a powered room")
	var/obj/effect/vestige_trial_marker/room = locate() in old_center
	TEST_ASSERT(room, "Arc Flash did not retain a physical charged-room marker")
	stoplag(0.5 SECONDS)
	TEST_ASSERT(old_bystander.getFireLoss() > 0 && !new_bystander.getFireLoss(), "The initial volley did not remain inside its original room")
	var/old_burn = old_bystander.getFireLoss()
	room.beforeShuttleMove(new_center, 180, MOVE_CONTENTS)
	room.onShuttleMove(new_center, old_center, list(), NORTH)
	room.afterShuttleMove(old_center, list(), SOUTH, NORTH, NORTH, 180)
	caster.forceMove(new_center)
	stoplag(1.6 SECONDS)
	TEST_ASSERT_EQUAL(old_bystander.getFireLoss(), old_burn, "A remaining arc struck occupants at the ship's departed berth")
	TEST_ASSERT(new_bystander.getFireLoss() > 0, "Remaining real Arc Flash timers did not follow the moving charged room")
	var/new_burn = new_bystander.getFireLoss()
	qdel(room)
	stoplag(1.6 SECONDS)
	TEST_ASSERT_EQUAL(new_bystander.getFireLoss(), new_burn, "Deleting the charged room left later volleys using its old coordinates")

/// A real resurrection bolt revives the defeated mob without refilling its already-paid equipment.
/datum/unit_test/vestige_ascension_resurrection_loot/Run()
	var/list/boss_loot = list(
		/mob/living/basic/vestige_oracle = /obj/item/clothing/head/oracle_hood,
		/mob/living/basic/vestige_mutant = /obj/item/clothing/neck/vestige_specimen_collar,
		/mob/living/basic/vestige_warframe = /obj/item/sparring_blade,
	)
	var/turf/floor = run_loc_floor_bottom_left
	for(var/boss_type in boss_loot)
		var/loot_type = boss_loot[boss_type]
		var/mob/living/basic/boss = allocate(boss_type, floor)
		var/before = length(floor.get_all_contents_type(loot_type))
		TEST_ASSERT(boss.death(), "[boss_type] could not die normally")
		TEST_ASSERT_EQUAL(length(floor.get_all_contents_type(loot_type)), before + 1, "The first defeated [boss_type] did not pay its ordinary loot")
		var/obj/projectile/magic/resurrection/bolt = allocate(/obj/projectile/magic/resurrection, floor)
		bolt.on_hit(boss)
		TEST_ASSERT(boss.stat != DEAD, "The real resurrection projectile must still revive [boss_type]")
		TEST_ASSERT(boss.death(), "The revived [boss_type] could not die a second time")
		TEST_ASSERT_EQUAL(length(floor.get_all_contents_type(loot_type)), before + 1, "Reviving and killing [boss_type] again printed another equipment payment")
		qdel(boss)

/// The actual bridle may temporarily possess a boss, but cannot permanently strip its attack rotation.
/datum/unit_test/vestige_ascension_bridle_recovery/Run()
	var/turf/floor = run_loc_floor_bottom_left
	var/mob/living/carbon/human/user = allocate(/mob/living/carbon/human/consistent, floor)
	user.mind_initialize()
	for(var/boss_type in list(/mob/living/basic/vestige_oracle, /mob/living/basic/vestige_mutant, /mob/living/basic/vestige_warframe))
		for(var/phase in 1 to 2)
			var/mob/living/basic/boss = allocate(boss_type, get_step(floor, EAST))
			if(phase == 2)
				if(istype(boss, /mob/living/basic/vestige_oracle))
					var/mob/living/basic/vestige_oracle/oracle = boss
					oracle.begin_stammer()
				else if(istype(boss, /mob/living/basic/vestige_mutant))
					var/mob/living/basic/vestige_mutant/specimen = boss
					specimen.begin_revision()
				else
					var/mob/living/basic/vestige_warframe/warframe = boss
					warframe.begin_second_round()
					warframe.end_round_change()
			var/list/expected_kit = get_boss_kit(boss)
			var/datum/ai_controller/old_controller = boss.ai_controller
			for(var/key in expected_kit)
				TEST_ASSERT_EQUAL(old_controller.blackboard[key], expected_kit[key], "[boss_type] phase [phase] started with an incorrect ability reference")
			var/obj/item/verdigris_bridle/bridle = allocate(/obj/item/verdigris_bridle)
			TEST_ASSERT(user.put_in_hands(bridle), "Could not equip the real bridle")
			var/datum/action/cooldown/spell/pointed/lich_corruption/bridle/rein = locate() in user.actions
			TEST_ASSERT(rein && rein.IsAvailable(feedback = FALSE) && rein.is_valid_target(boss), "The equipped bridle did not accept [boss_type] as a normal target")
			TEST_ASSERT(rein && rein.Activate(boss), "The real bridle could not cast on [boss_type] phase [phase]")
			var/datum/status_effect/lich_thrall/bridle/possession = boss.has_status_effect(/datum/status_effect/lich_thrall/bridle)
			TEST_ASSERT(possession && QDELETED(old_controller) && boss.ai_controller == possession.puppet_controller, "The bridle did not actually replace [boss_type]'s AI controller")
			var/list/cooldowns = list()
			for(var/key in expected_kit)
				var/datum/action/cooldown/ability = expected_kit[key]
				if(ability)
					ability.StartCooldown(17 SECONDS)
					cooldowns[ability] = ability.next_use_time
			qdel(possession)
			TEST_ASSERT(istype(boss.ai_controller, old_controller.type) && boss.ai_controller != old_controller, "The original controller type did not return after [boss_type]'s possession")
			for(var/key in expected_kit)
				TEST_ASSERT_EQUAL(boss.ai_controller.blackboard[key], expected_kit[key], "Restoring [boss_type] phase [phase] lost or prematurely unlocked [key]")
			for(var/datum/action/cooldown/ability as anything in cooldowns)
				TEST_ASSERT_EQUAL(ability.next_use_time, cooldowns[ability], "Restoring the controller reset a real boss action cooldown")
			qdel(bridle)
			qdel(boss)

/// Local blackboard defines are below the test include; record their exact keys with real mob-owned actions.
/datum/unit_test/vestige_ascension_bridle_recovery/proc/get_boss_kit(mob/living/basic/boss)
	if(istype(boss, /mob/living/basic/vestige_oracle))
		var/mob/living/basic/vestige_oracle/oracle = boss
		return list("BB_oracle_word_of_falling" = oracle.word_of_falling, "BB_oracle_antiphon" = oracle.antiphon, "BB_oracle_called_word" = oracle.called_word, "BB_oracle_last_line" = oracle.last_line)
	if(istype(boss, /mob/living/basic/vestige_mutant))
		var/mob/living/basic/vestige_mutant/specimen = boss
		return list("BB_mutant_sweep" = specimen.sweep, "BB_mutant_pin" = specimen.pin, "BB_mutant_repulse" = specimen.repulse, "BB_mutant_confiscate" = specimen.confiscate)
	var/mob/living/basic/vestige_warframe/warframe = boss
	return list("BB_warframe_iai" = warframe.iai, "BB_warframe_guard" = warframe.guard, "BB_warframe_sweep" = warframe.sweep, "BB_warframe_live_floor" = warframe.round_number >= 2 ? warframe.live_floor : null)
