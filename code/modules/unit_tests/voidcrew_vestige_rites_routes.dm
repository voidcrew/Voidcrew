/** Full ordinary rites, sharing the biology route's kit and restored-floor helpers. */
/datum/unit_test/vestige_rites_route
	parent_type = /datum/unit_test/vestige_biology_route
	abstract_type = /datum/unit_test/vestige_rites_route
	var/list/puzzle_solution
	var/list/puzzle_seen
	var/puzzle_searches = 0

/datum/unit_test/vestige_rites_route/proc/open_room(radius = 4)
	center = locate(run_loc_floor_bottom_left.x + radius, run_loc_floor_bottom_left.y + radius, run_loc_floor_bottom_left.z)
	var/center_x = center.x
	var/center_y = center.y
	var/center_z = center.z
	for(var/turf/spot in RANGE_TURFS(radius, center))
		terrain_originals += list(list(spot.x, spot.y, spot.z, spot.type))
		var/turf/floor = spot.ChangeTurf(/turf/open/floor/plating)
		floor.AddElement(/datum/element/forced_gravity, 1)
	center = locate(center_x, center_y, center_z)
	user.forceMove(center)
	ADD_TRAIT(user, TRAIT_NOBREATH, TRAIT_SOURCE_UNIT_TESTS)
	ADD_TRAIT(user, TRAIT_RESISTLOWPRESSURE, TRAIT_SOURCE_UNIT_TESTS)
	ADD_TRAIT(user, TRAIT_RESISTCOLD, TRAIT_SOURCE_UNIT_TESTS)

/datum/unit_test/vestige_rites_route/proc/approach(atom/target)
	if(user.Adjacent(target))
		return TRUE
	for(var/direction in GLOB.cardinals)
		if(walk_route_to(get_step(target, direction)))
			return TRUE
	return FALSE

/// For the unobstructed larger vigil room, retain ordinary Move and pulling behavior.
/datum/unit_test/vestige_rites_route/proc/walk_straight(turf/destination)
	while(user.x != destination.x)
		var/direction = user.x < destination.x ? EAST : WEST
		if(!user.Move(get_step(user, direction), direction))
			return FALSE
	while(user.y != destination.y)
		var/direction = user.y < destination.y ? NORTH : SOUTH
		if(!user.Move(get_step(user, direction), direction))
			return FALSE
	return TRUE

/datum/unit_test/vestige_rites_route/offering/Run()
	var/datum/vestige_trial/offering/offering = prepare(/datum/vestige_trial/offering)
	var/obj/item/vestige_chalk/chalk = loan(/obj/item/vestige_chalk)
	TEST_ASSERT(hold(chalk), "The supplicant must take the chalk from the supplied satchel.")
	TEST_ASSERT(center.base_item_interaction(user, chalk, list()) & ITEM_INTERACT_SUCCESS, "The actual eight-second chalk channel must scribe a rune.")
	var/obj/structure/vestige_rune/rune = locate() in center
	TEST_ASSERT(rune && offering.rune_scribed, "The actual chalk must create the rite's rune.")
	var/list/candles = list()
	for(var/datum/weakref/ref as anything in offering.loan_refs)
		var/obj/item/flashlight/flare/candle/candle = ref.resolve()
		if(istype(candle))
			candles += candle
	TEST_ASSERT_EQUAL(length(candles), 3, "The real satchel must supply three candles.")
	for(var/obj/item/flashlight/flare/candle/candle as anything in candles)
		TEST_ASSERT(hold(candle), "Each candle must be removable from its supplied satchel.")
		user.dropItemToGround(candle)
	var/obj/item/lighter/lighter = loan(/obj/item/lighter)
	TEST_ASSERT(hold(lighter), "The supplicant must take the supplied lighter.")
	user.execute_mode()
	for(var/obj/item/flashlight/flare/candle/candle as anything in candles)
		TEST_ASSERT(candle.base_item_interaction(user, lighter, list()) & ITEM_INTERACT_SUCCESS, "The actual lit lighter must ignite each grounded candle.")
		TEST_ASSERT(candle.light_on, "Each ritual candle must actually be burning.")
	var/mob/living/basic/carp/corpse = allocate(/mob/living/basic/carp, center)
	corpse.death()
	var/obj/item/knife/ritual/vestige/knife = loan(/obj/item/knife/ritual/vestige)
	TEST_ASSERT(hold(knife), "The supplicant must hold the ritual knife for the offering.")
	knife.melee_attack_chain(user, rune, list())
	for(var/tick in 1 to 100)
		if(/datum/vestige_trial/offering in user.mind.completed_vestige_trials)
			break
		sleep(1)
	TEST_ASSERT(/datum/vestige_trial/offering in user.mind.completed_vestige_trials, "Actual chalk, lit candles, substantial remains and the knife channel must complete Offering.")

/datum/unit_test/vestige_rites_route/vigil/Run()
	var/datum/vestige_trial/vigil/vigil = prepare(/datum/vestige_trial/vigil)
	TEST_ASSERT(hold(vigil.votive), "The supplicant must hold the actual blood votive.")
	var/initial_blood = user.blood_volume
	user.execute_mode()
	TEST_ASSERT(vigil.running && length(vigil.clots) == 3, "Actual votive activation must create three real attackers.")
	TEST_ASSERT_EQUAL(user.blood_volume, initial_blood - 30, "The real blood rite must collect its stated payment.")
	var/obj/item/knife/ritual/vestige/knife = loan(/obj/item/knife/ritual/vestige)
	TEST_ASSERT(hold(knife), "The supplicant must select the supplied weapon.")
	var/list/clots = vigil.clots.Copy()
	for(var/mob/living/basic/carp/vestige_clot/clot as anything in clots)
		clot.ai_controller.PauseAi(1 MINUTES)
	for(var/mob/living/basic/carp/vestige_clot/clot as anything in clots)
		TEST_ASSERT(approach(clot), "The supplicant must physically approach the hostile clot.")
		for(var/strike in 1 to 10)
			if(QDELETED(clot) || clot.stat == DEAD)
				break
			knife.melee_attack_chain(user, clot, list())
	TEST_ASSERT(/datum/vestige_trial/vigil in user.mind.completed_vestige_trials, "Actual supplied-weapon deaths inside the blood circle must complete Vigil.")

/datum/unit_test/vestige_rites_route/last_breath/Run()
	prepare(/datum/vestige_trial/last_breath)
	var/obj/item/vestige_lantern/lantern = loan(/obj/item/vestige_lantern)
	TEST_ASSERT(hold(lantern), "The mourner must hold the actual supplied lantern.")
	for(var/index in 1 to 3)
		var/mob/living/basic/carp/corpse = allocate(/mob/living/basic/carp, get_step(center, NORTH))
		corpse.death()
		TEST_ASSERT(corpse.base_item_interaction(user, lantern, list()) & ITEM_INTERACT_SUCCESS, "The actual three-second lantern channel must collect each distinct substantial corpse's breath.")
	TEST_ASSERT(/datum/vestige_trial/last_breath in user.mind.completed_vestige_trials, "Three actual distinct corpse channels must complete Last Breath.")

/datum/unit_test/vestige_rites_route/sitters_rounds/Run()
	var/datum/vestige_trial/sitters_rounds/sitter = prepare(/datum/vestige_trial/sitters_rounds)
	var/obj/item/vestige_cloth/cloth = loan(/obj/item/vestige_cloth)
	TEST_ASSERT(hold(cloth), "The caregiver must hold the issued cloth.")
	user.execute_mode()
	var/mob/living/carbon/human/vestige_patient/patient = sitter.patient
	TEST_ASSERT(patient && sitter.cot, "Actual cloth activation must deploy the injured patient and cot on pressurized floor.")
	TEST_ASSERT(sitter.cot.user_buckle_mob(patient, user), "The normal player buckle path must put the patient on the cot.")
	patient.base_item_interaction(user, cloth, list())
	TEST_ASSERT(patient.comforted, "The real cloth channel must settle the patient's shaking.")
	var/obj/item/healthanalyzer/scanner = loan(/obj/item/healthanalyzer)
	TEST_ASSERT(hold(scanner), "The caregiver must select the supplied health analyzer.")
	scanner.melee_attack_chain(user, patient, list())
	for(var/medicine_type in list(/obj/item/stack/medical/bruise_pack/vestige_sitter, /obj/item/stack/medical/ointment/vestige_sitter))
		var/obj/item/stack/medical/dressing = loan(medicine_type)
		TEST_ASSERT(hold(dressing), "The caregiver must select the appropriate supplied dressing.")
		for(var/application in 1 to 10)
			var/obj/item/bodypart/hurt_limb
			for(var/obj/item/bodypart/limb as anything in patient.bodyparts)
				if((dressing.heal_brute && limb.brute_dam) || (dressing.heal_burn && limb.burn_dam))
					hurt_limb = limb
					break
			if(!hurt_limb)
				break
			// The clientless HUD choice targets the actual injury displayed by the analyzer.
			user.zone_selected = hurt_limb.body_zone
			TEST_ASSERT(patient.base_item_interaction(user, dressing, list()) & ITEM_INTERACT_SUCCESS, "The real dressing interaction must start ordinary treatment on the selected injured limb.")
			for(var/tick in 1 to 200)
				if(!DOING_INTERACTION_WITH_TARGET(user, patient))
					break
				sleep(1)
	TEST_ASSERT(patient.getBruteLoss() + patient.getFireLoss() <= 10, "Actual dressing application must heal the patient's injuries into the discharge window.")
	TEST_ASSERT(hold(cloth), "The caregiver must return to the actual cloth for discharge.")
	patient.base_item_interaction(user, cloth, list())
	TEST_ASSERT(/datum/vestige_trial/sitters_rounds in user.mind.completed_vestige_trials, "Actual buckling, comfort, diagnosis, treatment and discharge must complete Sitter's Rounds.")

/datum/unit_test/vestige_rites_route/rite_of_toll/Run()
	var/datum/vestige_trial/rite_of_toll/toll = prepare(/datum/vestige_trial/rite_of_toll)
	var/obj/item/vestige_toll_casket/casket = toll.casket
	for(var/step in 1 to 14)
		if(!casket.pressure && !casket.tension)
			break
		var/obj/item/tool = casket.pressure >= casket.tension ? loan(/obj/item/wrench) : loan(/obj/item/screwdriver)
		TEST_ASSERT(hold(tool), "The supplicant must hold the supplied tool appropriate to the displayed force.")
		TEST_ASSERT(casket.base_item_interaction(user, tool, list()) & ITEM_INTERACT_SUCCESS, "The real two-second tool channel must work the lock.")
	TEST_ASSERT(!casket.pressure && !casket.tension && !casket.strain, "The supplied wrench and screwdriver must balance the real random lock without casing damage.")
	var/obj/item/payment = casket.last_tool?.resolve()
	TEST_ASSERT(user.is_holding(payment), "The actual final tool must remain available as the toll.")
	user.dropItemToGround(user.get_inactive_held_item())
	TEST_ASSERT(user.put_in_inactive_hand(casket), "The supplicant must take the casket with the last tool still in the other hand.")
	user.swap_hand(user.get_held_index_of_item(casket))
	user.execute_mode()
	TEST_ASSERT(QDELETED(payment), "The actual last tool must be consumed as payment.")
	TEST_ASSERT(/datum/vestige_trial/rite_of_toll in user.mind.completed_vestige_trials, "Actual balanced-tool channels and held-tool payment must complete the Toll.")

/datum/unit_test/vestige_rites_route/true_vigil/Run()
	open_room(9)
	var/datum/vestige_trial/true_vigil/vigil = prepare(/datum/vestige_trial/true_vigil)
	var/mob/living/basic/carp/corpse = allocate(/mob/living/basic/carp, center)
	corpse.death()
	TEST_ASSERT(hold(vigil.candle), "The mourner must select the actual wake-candle.")
	corpse.base_item_interaction(user, vigil.candle, list())
	TEST_ASSERT(vigil.watched == corpse && length(vigil.rifts) == 3, "The actual candle input must open all three mourning rifts.")
	var/turf/retreat
	var/best_clearance = -1
	for(var/offset_x in list(-8, 8))
		for(var/offset_y in list(-8, 8))
			var/turf/candidate = locate(center.x + offset_x, center.y + offset_y, center.z)
			var/clearance = INFINITY
			for(var/obj/structure/vestige_mourning_rift/rift as anything in vigil.rifts)
				clearance = min(clearance, get_dist(candidate, rift))
			if(clearance > best_clearance)
				best_clearance = clearance
				retreat = candidate
	user.start_pulling(corpse)
	TEST_ASSERT_EQUAL(user.pulling, corpse, "The ordinary player pull must take the watched remains.")
	TEST_ASSERT(walk_straight(retreat), "Actual walking must pull the watched remains away from the rifts.")
	user.stop_pulling()
	for(var/obj/structure/vestige_mourning_rift/rift as anything in vigil.rifts)
		TEST_ASSERT(get_dist(corpse, rift) >= 6, "Real pulling must leave enough clearance for the three timed closures.")
	var/list/rifts = vigil.rifts.Copy()
	var/turf/body_before_closures = get_turf(corpse)
	for(var/obj/structure/vestige_mourning_rift/rift as anything in rifts)
		TEST_ASSERT(walk_straight(get_turf(rift)), "The mourner must physically carry the candle to each rift.")
		TEST_ASSERT(rift.base_item_interaction(user, vigil.candle, list()) & ITEM_INTERACT_SUCCESS, "Each actual three-second candle channel must close its rift while the others keep processing.")
	TEST_ASSERT(get_turf(corpse) != body_before_closures, "The remaining rifts must really pull during the timed closures.")
	TEST_ASSERT(!QDELETED(corpse), "Successful vigil completion must preserve the borrowed remains.")
	TEST_ASSERT(/datum/vestige_trial/true_vigil in user.mind.completed_vestige_trials, "Actual pulling and three live timed rift closures must complete True Vigil.")

/// A whole ship's group relocation is different from teleporting only its watched body.
/datum/unit_test/vestige_rites_route/true_vigil_group_transit/Run()
	open_room()
	var/datum/vestige_trial/true_vigil/vigil = prepare(/datum/vestige_trial/true_vigil)
	var/mob/living/basic/carp/corpse = allocate(/mob/living/basic/carp, center)
	corpse.death()
	TEST_ASSERT(hold(vigil.candle), "The mourner must hold the wake-candle.")
	corpse.base_item_interaction(user, vigil.candle, list())
	TEST_ASSERT_EQUAL(length(vigil.rifts), 3, "The actual candle must start the transit fixture.")
	STOP_PROCESSING(SSobj, vigil)
	var/other_z = center.z == 1 ? 2 : 1
	corpse.abstract_move(locate(corpse.x, corpse.y, other_z))
	for(var/obj/structure/vestige_mourning_rift/rift as anything in vigil.rifts)
		rift.abstract_move(locate(rift.x, rift.y, other_z))
		rift.next_pull = world.time + 10 SECONDS // Compare relocation independently of the pull clock.
	user.abstract_move(locate(user.x, user.y, other_z))
	vigil.process(0.2)
	TEST_ASSERT(vigil.watched == corpse && length(vigil.rifts) == 3, "Relocating the body and every rift together must retain the complete vigil.")
	var/obj/structure/vestige_mourning_rift/first = vigil.rifts[1]
	user.forceMove(get_turf(first))
	TEST_ASSERT(first.base_item_interaction(user, vigil.candle, list()) & ITEM_INTERACT_SUCCESS, "The carried candle must still close a rift after complete group transit.")
	TEST_ASSERT_EQUAL(vigil.closed_rifts, 1, "A same-level complete relocated field must preserve its normal progress.")

/// Intentionally exposes the split-z case before any production change; parent runs this probe.
/datum/unit_test/vestige_rites_route/true_vigil_split_z/Run()
	open_room()
	var/datum/vestige_trial/true_vigil/vigil = prepare(/datum/vestige_trial/true_vigil)
	var/mob/living/basic/carp/corpse = allocate(/mob/living/basic/carp, center)
	corpse.death()
	TEST_ASSERT(hold(vigil.candle), "The mourner must hold the wake-candle.")
	corpse.base_item_interaction(user, vigil.candle, list())
	TEST_ASSERT_EQUAL(length(vigil.rifts), 3, "The actual candle must start the split-z fixture.")
	STOP_PROCESSING(SSobj, vigil)
	var/obj/structure/vestige_mourning_rift/first = vigil.rifts[1]
	var/other_z = center.z == 1 ? 2 : 1
	corpse.forceMove(locate(corpse.x, corpse.y, other_z))
	var/turf/body_before = get_turf(corpse)
	var/distance_after_split = get_dist(corpse, first)
	user.forceMove(get_turf(first))
	var/candle_result = first.base_item_interaction(user, vigil.candle, list())
	var/closures_after_split = vigil.closed_rifts
	vigil.process(0.2)
	TEST_ASSERT_NULL(vigil.watched, "A body actually moved to a different z must release the split field for retry: native get_dist was [distance_after_split], candle result [candle_result], closures [closures_after_split], body moved during process: [get_turf(corpse) != body_before].")
	TEST_ASSERT_EQUAL(closures_after_split, 0, "A candle must not certify a closure against remains on another level.")
	TEST_ASSERT(!QDELETED(corpse), "Abandoning a split vigil must preserve the displaced remains.")

/datum/unit_test/vestige_rites_route/singed_hand/Run()
	open_room()
	var/datum/vestige_trial/singed_hand/lesson = prepare(/datum/vestige_trial/singed_hand)
	var/obj/item/vestige_geode/geode = loan(/obj/item/vestige_geode)
	TEST_ASSERT(hold(geode), "The student must select the actual geode.")
	user.execute_mode()
	TEST_ASSERT(lesson.focus && length(lesson.manifestations) == 3, "The actual geode activation must deploy the complete lesson.")
	for(var/obj/structure/vestige_miscast/miscast as anything in lesson.manifestations)
		TEST_ASSERT_EQUAL(get_dist(miscast, center), 3, "The real manifestation search must place each hazard on its stated three-tile perimeter.")
		miscast.process(0.2)
		TEST_ASSERT(miscast.warning && miscast.strike_at, "Each actual miscast must mark the student's initial footing.")
	var/stamina_before = user.getStaminaLoss()
	TEST_ASSERT(user.Move(get_step(user, EAST), EAST), "The student must actually leave the visible flare tile.")
	sleep(2 SECONDS)
	for(var/obj/structure/vestige_miscast/miscast as anything in lesson.manifestations)
		miscast.process(0.2)
		TEST_ASSERT(miscast.spent_until > world.time, "The real flare must leave each miscast blue and catchable.")
	TEST_ASSERT_EQUAL(user.getStaminaLoss(), stamina_before, "Actually leaving the marked tile must avoid the flare's stamina hit.")
	TEST_ASSERT(user.Move(center, WEST), "The student must return to the well once the real flares have ended.")
	var/list/miscasts = lesson.manifestations.Copy()
	for(var/index in 1 to 3)
		var/obj/structure/vestige_miscast/miscast = miscasts[index]
		miscast.base_ranged_item_interaction(user, geode, list())
		TEST_ASSERT(QDELETED(miscast), "Actual ranged geode input must capture each spent manifestation.")
		if(index == 2 || index == 3)
			lesson.focus.base_item_interaction(user, geode, list())
			if(index == 2)
				TEST_ASSERT_EQUAL(lesson.resolved, 2, "The actual well must empty the two-slot geode before the third catch.")
	TEST_ASSERT(/datum/vestige_trial/singed_hand in user.mind.completed_vestige_trials, "Actual flares, dodge, ranged captures and two well visits must complete Singed Hand.")

/datum/unit_test/vestige_rites_route/steady_tongue/Run()
	open_room()
	var/datum/vestige_trial/steady_tongue/lesson = prepare(/datum/vestige_trial/steady_tongue)
	var/obj/item/vestige_primer/primer = loan(/obj/item/vestige_primer)
	TEST_ASSERT(hold(primer), "The student must select the actual primer.")
	user.execute_mode()
	TEST_ASSERT(lesson.focus && length(lesson.manifestations) == 3, "The primer must deploy the complete brazier exercise.")
	var/list/miscasts = lesson.manifestations.Copy()
	// Isolate directional words; the companion geode route exercises live flare timing.
	for(var/obj/structure/vestige_miscast/miscast as anything in miscasts)
		STOP_PROCESSING(SSobj, miscast)
	for(var/obj/structure/vestige_miscast/miscast as anything in miscasts)
		for(var/push in 1 to 6)
			if(QDELETED(miscast))
				break
			var/push_direction
			if(miscast.x != center.x)
				push_direction = miscast.x < center.x ? EAST : WEST
			else
				push_direction = miscast.y < center.y ? NORTH : SOUTH
			TEST_ASSERT(walk_route_to(get_step(miscast, REVERSE_DIR(push_direction))), "The student must physically line up behind the manifestation.")
			if(world.time < primer.next_word)
				sleep(primer.next_word - world.time)
			var/turf/expected = get_step(miscast, push_direction)
			TEST_ASSERT(miscast.base_item_interaction(user, primer, list()) & ITEM_INTERACT_SUCCESS, "The actual ready spoken word must repel the manifestation.")
			if(!QDELETED(miscast))
				TEST_ASSERT_EQUAL(get_turf(miscast), expected, "The real word must move exactly one cardinal tile away from the speaker.")
		TEST_ASSERT(QDELETED(miscast), "A sequence of legal spoken pushes must deliver the manifestation into the brazier.")
	TEST_ASSERT(/datum/vestige_trial/steady_tongue in user.mind.completed_vestige_trials, "Actual aligned words and their real cooldown must complete all three Steady Tongue deliveries.")

/// IDA* over the visible numbered board; never mutates live inscription state.
/datum/unit_test/vestige_rites_route/proc/find_puzzle_route(list/board, gap, previous_gap, remaining, list/path)
	puzzle_searches++
	if(puzzle_searches > 2000000)
		return FALSE
	CHECK_TICK
	var/distance = 0
	for(var/index in 1 to 9)
		var/number = board[index]
		if(number == 9)
			continue
		distance += abs((index - 1) % 3 - (number - 1) % 3) + abs(FLOOR((index - 1) / 3, 1) - FLOOR((number - 1) / 3, 1))
	if(distance > remaining)
		return FALSE
	if(!distance)
		puzzle_solution = path.Copy()
		return TRUE
	var/key = jointext(board, "")
	if(puzzle_seen[key] >= remaining + 1)
		return FALSE
	puzzle_seen[key] = remaining + 1
	for(var/next in list(gap - 3, gap + 3, gap - 1, gap + 1))
		if(next < 1 || next > 9 || next == previous_gap || (abs(next - gap) == 1 && FLOOR((next - 1) / 3, 1) != FLOOR((gap - 1) / 3, 1)))
			continue
		var/number = board[next]
		board[gap] = number
		board[next] = 9
		path += number
		if(find_puzzle_route(board, next, gap, remaining - 1, path))
			return TRUE
		path.Cut(length(path), length(path) + 1)
		board[next] = number
		board[gap] = 9
	return FALSE

/datum/unit_test/vestige_rites_route/swallowed_word/Run()
	var/datum/vestige_trial/swallowed_word/puzzle = prepare(/datum/vestige_trial/swallowed_word)
	var/obj/item/vestige_syllable/phial = loan(/obj/item/vestige_syllable)
	TEST_ASSERT(hold(phial), "The student must select the actual syllable phial.")
	user.execute_mode()
	TEST_ASSERT_EQUAL(length(puzzle.syllables), 9, "The actual phial must deploy and scramble the complete inscription.")
	var/list/board = list()
	var/gap
	for(var/index in 1 to 9)
		var/obj/structure/vestige_silent_glyph/home_piece = puzzle.syllables[index]
		var/obj/structure/vestige_silent_glyph/current = locate() in get_turf(home_piece.home)
		TEST_ASSERT(current, "Every actual board cell must contain a numbered syllable or the gap.")
		board += current.number
		if(current.number == 9)
			gap = index
	for(var/depth in 0 to 31)
		puzzle_seen = list()
		if(find_puzzle_route(board.Copy(), gap, 0, depth, list()))
			break
	TEST_ASSERT(!isnull(puzzle_solution), "The actual scrambled inscription must admit a legal sliding solution.")
	for(var/number in puzzle_solution)
		var/obj/structure/vestige_silent_glyph/glyph = puzzle.syllables[number]
		TEST_ASSERT(glyph.base_item_interaction(user, phial, list()) & ITEM_INTERACT_SUCCESS, "Every computed slide must succeed through actual adjacent phial dispatch.")
	TEST_ASSERT(/datum/vestige_trial/swallowed_word in user.mind.completed_vestige_trials, "Restoring the actual randomized inscription through legal item inputs must complete Swallowed Word.")

/// The existing stack-menu callback stands in for choosing "wall girders (anchored)".
/// Both construction channels, material consumption and cladding use their stock paths.
/datum/unit_test/vestige_rites_route/proc/build_iron_wall(turf/site, obj/item/stack/sheet/iron/iron)
	var/site_x = site.x
	var/site_y = site.y
	var/site_z = site.z
	if(!walk_route_to(site) || !hold(iron))
		return FALSE
	var/datum/stack_recipe/girder_recipe
	for(var/datum/stack_recipe/recipe as anything in iron.recipes)
		if(istype(recipe) && recipe.result_type == /obj/structure/girder)
			girder_recipe = recipe
			break
	if(!girder_recipe)
		return FALSE
	iron.make_item(user, girder_recipe, 1)
	var/obj/structure/girder/girder = locate() in site
	if(!girder || !user.Move(get_step(site, WEST), WEST))
		return FALSE
	iron.melee_attack_chain(user, girder, list())
	return istype(locate(site_x, site_y, site_z), /turf/closed/wall)

/datum/unit_test/vestige_rites_route/rite_of_rust/Run()
	open_room()
	var/datum/vestige_trial/rite_of_rust/rust = prepare(/datum/vestige_trial/rite_of_rust)
	var/obj/item/stack/sheet/iron/iron = loan(/obj/item/stack/sheet/iron)
	var/turf/site = get_step(center, EAST)
	TEST_ASSERT(build_iron_wall(site, iron), "The supplied stack must build an internal test wall through actual girder construction and cladding.")
	TEST_ASSERT_EQUAL(iron.get_amount(), 6, "The real initial wall must consume four of the ten supplied sheets.")
	TEST_ASSERT(hold(rust.weight), "The supplicant must place the actual weight beside the test wall.")
	user.dropItemToGround(rust.weight)
	TEST_ASSERT_EQUAL(rust.weight.loc, center, "The actual dropped weight must be on the starting side.")
	var/obj/item/vestige_chrism/chrism = loan(/obj/item/vestige_chrism)
	TEST_ASSERT(hold(chrism), "The supplicant must take the actual corroding chrism.")
	for(var/anointing in 1 to 2)
		var/turf/wall = locate(center.x + 1, center.y, center.z)
		TEST_ASSERT(wall.base_item_interaction(user, chrism, list()) & ITEM_INTERACT_SUCCESS, "Each actual two-second anointing must rust the ordinary wall.")
	TEST_ASSERT(rust.opened && rust.guardian && isopenturf(get_turf(rust.passage)), "The second real anointing must open the marked breach and release its guardian.")
	get_turf(rust.passage).AddElement(/datum/element/forced_gravity, 1)
	// The mission explicitly permits bringing a weapon. Keep the actual combat deterministic.
	var/mob/living/basic/hivebot/vestige_threshold_guardian/guardian = rust.guardian
	guardian.ai_controller.PauseAi(1 MINUTES)
	var/obj/item/knife/kitchen/knife = allocate(/obj/item/knife/kitchen, user.loc)
	TEST_ASSERT(hold(knife), "The supplicant must draw their own ordinary weapon.")
	for(var/strike in 1 to 15)
		if(QDELETED(guardian) || guardian.stat == DEAD)
			break
		knife.melee_attack_chain(user, guardian, list())
	TEST_ASSERT(QDELETED(guardian) || guardian.stat == DEAD, "Actual weapon hits must defeat the guardian before rebuilding.")
	user.start_pulling(rust.weight)
	TEST_ASSERT_EQUAL(user.pulling, rust.weight, "The normal player pull must take the grounded weight.")
	for(var/step in 1 to 3)
		TEST_ASSERT(user.Move(get_step(user, EAST), EAST), "Actual walking must pull the weight through the dissolved wall.")
	user.stop_pulling()
	TEST_ASSERT(rust.crossed && rust.weight.loc == get_turf(rust.destination), "The weight's actual crossing signal must leave it on the first far-side floor.")
	site = get_turf(rust.passage)
	TEST_ASSERT(build_iron_wall(site, iron), "The remaining supplied iron must rebuild an actual wall behind the crossed weight.")
	if(!QDELETED(rust))
		rust.process(0.2)
	TEST_ASSERT(/datum/vestige_trial/rite_of_rust in user.mind.completed_vestige_trials, "Actual initial construction, two anointings, combat, pulling and rebuilding must complete Rust.")

/datum/unit_test/vestige_rites_route/rite_of_transcription/Run()
	var/datum/vestige_trial/rite_of_transcription/transcription = prepare(/datum/vestige_trial/rite_of_transcription)
	var/obj/machinery/door/airlock/door = allocate(/obj/machinery/door/airlock, get_step(center, EAST))
	door.req_access = list(ACCESS_ENGINE) // The fixture is a real door which denies this unequipped human's ID.
	var/obj/item/vestige_quill/quill = loan(/obj/item/vestige_quill)
	TEST_ASSERT(hold(quill), "The scrivener must hold the actual supplied quill.")
	TEST_ASSERT(door.base_item_interaction(user, quill, list()) & ITEM_INTERACT_SUCCESS, "The real five-second first reading must register the access-restricted threshold.")
	TEST_ASSERT_EQUAL(transcription.threshold, door, "The actual quill reading must choose this threshold.")
	var/obj/item/screwdriver/screwdriver = loan(/obj/item/screwdriver)
	TEST_ASSERT(hold(screwdriver), "The scrivener must retrieve the screwdriver from the supplied toolbox.")
	TEST_ASSERT(door.base_item_interaction(user, screwdriver, list()) & ITEM_INTERACT_SUCCESS, "The actual screwdriver must open the engineering panel.")
	TEST_ASSERT(door.panel_open, "The real panel must be open before the wires can be operated.")
	var/obj/item/wirecutters/cutters = loan(/obj/item/wirecutters)
	TEST_ASSERT(hold(cutters), "The scrivener must retrieve the supplied wirecutters.")
	TEST_ASSERT(door.wires.interactable(user), "The real open panel must expose its wiring to this player.")
	// Headless selection seam: select the identified main and backup power wires in the existing UI callback.
	// The toolbox, open-panel check, held cutters and both native on_cut effects are real.
	door.wires.cut_color(door.wires.get_color_of_wire(WIRE_POWER1), user)
	door.wires.cut_color(door.wires.get_color_of_wire(WIRE_BACKUP1), user)
	TEST_ASSERT(!door.hasPower(), "Cutting the real main and backup wires must disable both door supplies.")
	var/obj/item/crowbar/crowbar = loan(/obj/item/crowbar)
	TEST_ASSERT(hold(crowbar), "The scrivener must retrieve the supplied crowbar.")
	TEST_ASSERT(door.base_item_interaction(user, crowbar, list()) & ITEM_INTERACT_SUCCESS, "The actual crowbar tool dispatch must pry the disabled door.")
	for(var/tick in 1 to 30)
		if(!door.density && !door.operating)
			break
		sleep(1)
	TEST_ASSERT(transcription.breached && !door.density, "The real successful airlock-open signal must certify the witnessed manual breach.")
	TEST_ASSERT(user.Move(get_turf(door), EAST), "The scrivener must actually step through the open threshold.")
	TEST_ASSERT(user.Move(get_step(door, EAST), EAST), "The scrivener must emerge on the opposite side.")
	TEST_ASSERT(transcription.crossed, "Only the actual movement across the threshold must certify the crossing.")
	TEST_ASSERT(door.base_item_interaction(user, crowbar, list()) & ITEM_INTERACT_SUCCESS, "The same actual crowbar must close the disabled airlock.")
	for(var/tick in 1 to 30)
		if(door.density && !door.operating)
			break
		sleep(1)
	TEST_ASSERT(door.density && !door.allowed(user), "The threshold must again stand closed and deny this player's ID.")
	TEST_ASSERT(hold(quill), "The scrivener must return to the quill after shutting the door.")
	TEST_ASSERT(door.base_item_interaction(user, quill, list()) & ITEM_INTERACT_SUCCESS, "The real opposite-side five-second reading must transcribe the restored refusal.")
	TEST_ASSERT(/datum/vestige_trial/rite_of_transcription in user.mind.completed_vestige_trials, "Actual quill readings, panel work, wire cutting, manual prying, crossing and closing must complete Transcription.")
