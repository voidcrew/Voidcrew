/// Reaches the real entry guards without loading or owning an arena reservation.
/datum/vestige_ascension_run/unit_test_entry
	var/load_calls = 0
	var/atom/movable/add_during_load

/datum/vestige_ascension_run/unit_test_entry/load_arena(datum/map_template/vestige_arena/template)
	load_calls++
	if(add_during_load)
		add_during_load.forceMove(supplicant.current)
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
	boss.death()
	var/before = victor.health
	boss.sweep.fling_one(shot)
	TEST_ASSERT(!shot.throwing, "A dead specimen launched another sweep projectile")
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
	var/area/original_area = get_area(other_arena)
	var/area/ruin/space/has_grav/vestige/arena/oracle/forbidden_area = allocate(/area/ruin/space/has_grav/vestige/arena/oracle)
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
	run.way_home.attack_hand(user, list())
	TEST_ASSERT(QDELETED(run) && QDELETED(reservation) && get_turf(user) == home, "A retry through the gate did not finish the intact keeper's return")
	TEST_ASSERT(!keeper.active_ascension_run, "Successful retry retained the active run")

/// Every body admitted to the arena can take its own gate, using its actual unarmed dispatch.
/datum/unit_test/vestige_ascension_gate_bodies/Run()
	var/turf/arena_floor = run_loc_floor_bottom_left
	var/turf/home = get_step(arena_floor, NORTH)
	var/datum/vestige_ascension/offer = allocate(/datum/vestige_ascension/oracle)
	for(var/body_type in list(/mob/living/carbon/human/consistent, /mob/living/basic/carp, /mob/living/carbon/human/species/monkey, /mob/living/silicon/robot))
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
	TEST_ASSERT(check_teleport_valid(user, home, TELEPORT_CHANNEL_MAGIC), "The regression must start with an unprotected, teleportable reservation margin")
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
	TEST_ASSERT(field.lifting && captive in field.lifted && captive.orbiting?.parent == new_body, "The abandoned body's death shut down the replacement body's field")
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
	TEST_ASSERT(captive in first_field.lifted && HAS_TRAIT(captive, TRAIT_IMMOBILIZED), "The first caster did not establish its hold")
	second.next_click = -1
	second.ClickOn(captive, "")
	TEST_ASSERT(!(captive in first_field.lifted) && captive in second_field.lifted && captive.orbiting?.parent == second, "The real orbiter handoff did not transfer the held creature")
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
	TEST_ASSERT(!new_table.anchored && new_table in field.lifted && new_table.orbiting?.parent == new_body, "The old channel canceled or displaced the new body's legitimate rip")
