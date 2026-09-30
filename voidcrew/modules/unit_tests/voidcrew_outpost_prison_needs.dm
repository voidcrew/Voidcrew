/**
 * Outpost prison needs: hunger, uniforms and the serving hatch, eating, mess, blood and first aid,
 * the routine and dialogue, and what needs do to mood; arrivals, food by quality, sport, the
 * hatch as the only stockpile, the Sustenance Vendor, and the prisoners' small routines (binning,
 * tidying, shared meals, sick calls, basketball with staff, the cycling thought bubble).
 *
 * Voidcrew defines are not visible from test files, so tuning values appear as literals with
 * the define named beside them. Prisons are driven with tick(seconds) with their own processing
 * stopped, never by waiting in real time, except for beams, which run on timers. Fixtures are
 * in voidcrew_outpost_prison_helpers.dm.
 */

// ===== NEEDS, THE HATCH, MESS, BLOOD AND FIRST AID =====

/datum/unit_test/voidcrew_outpost_prison_needs
	parent_type = /datum/unit_test/voidcrew_outpost_management

/datum/unit_test/voidcrew_outpost_prison_needs/Run()
	var/obj/structure/overmap/dynamic/player_outpost/home = prison_test_claim("needsowner")
	TEST_ASSERT_NOTNULL(home, "The needs test prison did not load")
	var/datum/outpost_prison/prison = test_prison(home)
	var/turf/yard_by_hatch = prison_spot(home, 5, 7)
	var/turf/hatch_turf = prison_spot(home, 5, 6)
	var/obj/structure/table/reinforced/prison_hatch/hatch = locate() in hatch_turf
	TEST_ASSERT_NOTNULL(hatch, "The serving hatch is not where the map puts it")
	var/mob/living/basic/outpost_prisoner/prisoner = test_prisoner(prison, yard_by_hatch)
	var/mob/living/carbon/human/warden = make_player(prison_spot(home, 5, 5), "needsowner")

	// Unit tests are parsed before voidcrew/_DEFINES, so the rates are read off one minute of play:
	// full to empty hunger in 20 minutes (PRISONER_HUNGER_DECAY 5 a minute), grime 2.5 a minute at rest.
	prison.tick(60)
	var/hunger_rate = 100 - prisoner.hunger
	var/grime_rate = prisoner.uniform_grime
	TEST_ASSERT(abs(hunger_rate - 5) < 0.01, "A minute took [hunger_rate] hunger, not 5")
	TEST_ASSERT(abs(grime_rate - 2.5) < 0.01, "A minute added [grime_rate] grime, not 2.5")
	prisoner.adjust_needs(19 * 60)
	TEST_ASSERT(prisoner.hunger < 0.01, "Twenty minutes did not empty hunger ([prisoner.hunger])")
	prisoner.set_uniform_grime(0)
	prisoner.adjust_needs(40 * 60)
	TEST_ASSERT(prisoner.uniform_grime > 99.99, "Forty minutes did not ruin the uniform ([prisoner.uniform_grime])")

	// The hatch is a security desk: a window door on each side of the counter.
	var/obj/machinery/door/window/yard_door = hatch.yard_windoor()
	var/obj/machinery/door/window/staff_door = hatch.staff_windoor()
	TEST_ASSERT(yard_door && staff_door, "The serving hatch is missing a window door")
	TEST_ASSERT_EQUAL(get_step(hatch, yard_door.dir), yard_by_hatch, "The yard-side window door does not face the yard")
	TEST_ASSERT_EQUAL(get_step(hatch, staff_door.dir), prison_spot(home, 5, 5), "The staff-side window door does not face the office")
	TEST_ASSERT_EQUAL(hatch.yard_side_turf(), yard_by_hatch, "The hatch does not know where prisoners reach in from")
	TEST_ASSERT(yard_door.allowed(prisoner), "The yard side refuses prisoners")
	TEST_ASSERT(!staff_door.allowed(prisoner), "The staff side opens for prisoners")
	TEST_ASSERT(staff_door.allowed(warden), "The staff side wants an ID")
	TEST_ASSERT(!hatch.both_sides_open(), "A shut hatch reads as open")
	// Staff can throw onto the counter through the shut office window; a prisoner's throw and an item
	// that isn't flying can't get through.
	var/obj/item/food/prison_ration/tossed = allocate(__IMPLIED_TYPE__, prison_spot(home, 5, 4))
	tossed.throwing = new /datum/thrownthing(tossed, hatch, get_dir(tossed, hatch), 5, 1, warden)
	TEST_ASSERT(staff_door.CanAllowThrough(tossed, staff_door.dir), "A member's throw did not get through the shut office window")
	tossed.throwing.thrower = WEAKREF(prisoner)
	TEST_ASSERT(!staff_door.CanAllowThrough(tossed, staff_door.dir), "A prisoner's throw got through the office window")
	QDEL_NULL(tossed.throwing)
	TEST_ASSERT(!staff_door.CanAllowThrough(tossed, staff_door.dir), "An item that was not thrown got through the office window")
	qdel(tossed)

	// Food they can reach: on the hatch, yes, through their own window door; on the office floor, no.
	prisoner.set_hunger(30)
	prisoner.set_uniform_grime(0)
	// Rations at 60 (PRISONER_FOOD_RATION). At mood 40 (50 after the meal's +10) wrappers stay on the
	// table, neither binned (PRISONER_BIN_MOOD 60) nor dropped (PRISONER_LITTER_MOOD 40).
	prisoner.set_mood(40)
	var/obj/item/food/prison_ration/office_food = allocate(__IMPLIED_TYPE__, prison_spot(home, 8, 5))
	prison.refresh_reach()
	TEST_ASSERT(prisoner.wants_food(), "A prisoner at 30 hunger did not want food")
	TEST_ASSERT_NULL(prison.find_supply(prisoner), "A prisoner went for food in the office, out of reach")
	var/obj/item/food/prison_ration/hatch_food = allocate(__IMPLIED_TYPE__, hatch_turf)
	TEST_ASSERT_EQUAL(prison.find_supply(prisoner), hatch_food, "A prisoner did not find food on the serving hatch")
	TEST_ASSERT(!prisoner.Adjacent(hatch_food), "Food behind the shut window door was within reach")
	TEST_ASSERT_EQUAL(prisoner.try_reach(hatch_food), 2, "Reaching for the hatch did not open the prisoner's side") // PRISONER_REACH_WAIT
	TEST_ASSERT(wait_until(CALLBACK(src, TYPE_PROC_REF(/datum/unit_test/voidcrew_outpost_management, windoor_open), yard_door)), "The yard-side window door never opened")
	TEST_ASSERT(staff_door.density, "Reaching in opened the staff side too")
	TEST_ASSERT_EQUAL(prisoner.try_reach(hatch_food), 1, "The prisoner could not reach through their open side") // PRISONER_REACH_OK
	staff_door.open()
	TEST_ASSERT(hatch.both_sides_open(), "Both sides open did not read as open")
	staff_door.close()
	qdel(office_food)

	// Eating: food carried from the hatch to a stool at a mess table, eaten there, crumbs left.
	var/datum/prisoner_activity/eat/meal = prisoner.start_activity(new /datum/prisoner_activity/eat(prisoner))
	TEST_ASSERT(meal.setup(), "A hungry prisoner would not go for food on the hatch")
	TEST_ASSERT_EQUAL(meal.spot, yard_by_hatch, "A prisoner went somewhere other than the hatch for food")
	var/list/walked = list()
	REMOVE_TRAIT(prisoner, TRAIT_IMMOBILIZED, TRAIT_SOURCE_UNIT_TESTS)
	meal.arrive()
	for(var/i in 1 to 20)
		var/result = meal.tick(1)
		if(result == 2) // ACTIVITY_MOVE
			break
		TEST_ASSERT_NOTEQUAL(result, 1, "The meal ended before the food was taken")
		// The AI ticks activities once a second; the hatch takes about that long to open.
		sleep(1 SECONDS)
	TEST_ASSERT_EQUAL(prisoner.held_item, hatch_food, "The prisoner did not take the food off the hatch")
	var/obj/structure/chair/stool/seat = locate() in meal.spot
	TEST_ASSERT_NOTNULL(seat, "The prisoner did not head for a stool")
	TEST_ASSERT_NOTNULL(prison.table_beside(seat), "The chosen stool is not at a mess table")
	walked += meal.spot
	prisoner.forceMove(meal.spot)
	meal.arrive()
	TEST_ASSERT_EQUAL(prisoner.buckled, seat, "The prisoner did not sit on the stool to eat")
	TEST_ASSERT_EQUAL(hatch_food.loc, meal.table_turf, "The meal was not put on the table")
	meal.eat_until = world.time
	TEST_ASSERT_EQUAL(meal.tick(1), 1, "The meal did not finish")
	prisoner.end_activity(cancel_ai = FALSE)
	TEST_ASSERT(QDELETED(hatch_food), "The meal was not eaten")
	TEST_ASSERT(abs(prisoner.hunger - 90) < 0.01, "Eating a ration did not add 60 hunger (now [prisoner.hunger])") // PRISONER_FOOD_RATION
	TEST_ASSERT_NULL(prisoner.buckled, "The prisoner stayed sat after the meal")
	// Wrappers are left often, not always.
	var/wrappers = 0
	for(var/i in 1 to 10)
		var/obj/item/food/prison_ration/sample = new(prison_spot(home, 8, 8))
		prisoner.leave_meal_mess(sample, prison_spot(home, 8, 8), prison_spot(home, 4, 9))
		qdel(sample)
	for(var/obj/item/trash/wrapper in prison_spot(home, 4, 9))
		wrappers++
		qdel(wrapper)
	TEST_ASSERT(wrappers >= 1, "Ten meals left no wrapper or tray on the table")
	for(var/obj/effect/decal/cleanable/food/crumbs/crumbs in prison_spot(home, 8, 8))
		qdel(crumbs)
	ADD_TRAIT(prisoner, TRAIT_IMMOBILIZED, TRAIT_SOURCE_UNIT_TESTS)
	prisoner.forceMove(yard_by_hatch)

	// With nobody on the level the AI sleeps, and the prison lets them help themselves instead.
	prisoner.set_hunger(30)
	prison.refresh_reach()
	var/obj/item/food/prison_ration/unwatched_food = allocate(__IMPLIED_TYPE__, hatch_turf)
	TEST_ASSERT_NOTEQUAL(prisoner.ai_controller.ai_status, AI_STATUS_ON, "The prisoner's AI runs in a world with no players")
	prison.tick(5)
	TEST_ASSERT(QDELETED(unwatched_food), "An unwatched prisoner did not eat reachable food")
	TEST_ASSERT(prisoner.hunger > 89, "Eating unwatched did not add 60 hunger (now [prisoner.hunger])")
	TEST_ASSERT(locate(/obj/effect/decal/cleanable/food/crumbs) in yard_by_hatch, "Eating standing up left no crumbs")

	// Handing food over: eaten when hungry, refused when full.
	prisoner.set_hunger(20)
	var/obj/item/food/prison_ration/handed = allocate(__IMPLIED_TYPE__)
	warden.forceMove(prison_spot(home, 6, 7))
	warden.put_in_active_hand(handed)
	click_wrapper(warden, prisoner)
	TEST_ASSERT(QDELETED(handed), "The prisoner did not eat food handed to them")
	TEST_ASSERT(abs(prisoner.hunger - 80) < 0.01, "Hand feeding a ration did not add 60 hunger (now [prisoner.hunger])")
	prisoner.set_hunger(95)
	var/obj/item/food/prison_ration/refused = allocate(__IMPLIED_TYPE__)
	warden.put_in_active_hand(refused)
	click_wrapper(warden, prisoner)
	TEST_ASSERT(!QDELETED(refused) && warden.is_holding(refused), "A full prisoner ate anyway")
	TEST_ASSERT(abs(prisoner.hunger - 95) < 0.01, "Refused food changed hunger")
	qdel(refused)

	// Uniforms: a clean one on the hatch is found and swapped, and the grimy one left in its place.
	prisoner.set_hunger(100)
	prisoner.set_uniform_grime(90)
	var/obj/item/clothing/under/rank/prisoner/outpost/fresh = allocate(__IMPLIED_TYPE__, hatch_turf)
	prison.refresh_reach()
	TEST_ASSERT_EQUAL(prison.find_supply(prisoner, TRUE), fresh, "A filthy prisoner did not find the clean uniform on the hatch")
	TEST_ASSERT(reach_until_ok(prisoner, fresh), "The prisoner could not reach the uniform through the hatch")
	TEST_ASSERT(prisoner.take_uniform(fresh), "The prisoner did not change at the hatch")
	TEST_ASSERT(QDELETED(fresh), "The clean uniform was not taken")
	TEST_ASSERT(prisoner.uniform_grime < 0.01, "Changing did not leave the prisoner clean ([prisoner.uniform_grime])")
	var/obj/item/clothing/under/rank/prisoner/outpost/left_behind = locate() in hatch_turf
	TEST_ASSERT_NOTNULL(left_behind, "The old uniform was not left on the hatch")
	TEST_ASSERT(abs(left_behind.grime - 90) < 0.01, "The uniform left behind has [left_behind.grime] grime, not 90")
	TEST_ASSERT_NULL(prison.find_supply(prisoner, TRUE), "A clean prisoner went looking for another uniform")

	// By hand: a cleaner one is taken and the old one handed back; a dirtier one is refused.
	prisoner.set_uniform_grime(70)
	var/obj/item/clothing/under/rank/prisoner/outpost/offered = allocate(__IMPLIED_TYPE__)
	offered.set_grime(10)
	warden.put_in_active_hand(offered)
	click_wrapper(warden, prisoner)
	TEST_ASSERT(abs(prisoner.uniform_grime - 10) < 0.01, "A handed-over uniform was not worn (grime [prisoner.uniform_grime])")
	var/obj/item/clothing/under/rank/prisoner/outpost/handed_back = warden.get_active_held_item()
	TEST_ASSERT(istype(handed_back), "The old uniform was not handed back")
	TEST_ASSERT(abs(handed_back.grime - 70) < 0.01, "The handed-back uniform has [handed_back.grime] grime, not 70")
	click_wrapper(warden, prisoner)
	TEST_ASSERT_EQUAL(warden.get_active_held_item(), handed_back, "A dirtier uniform was taken")

	// The wing's washing machine gets it clean.
	var/obj/machinery/washing_machine/washer = locate() in prison_spot(home, 3, 2)
	TEST_ASSERT_NOTNULL(washer, "The washing machine is not where the map puts it")
	warden.temporarilyRemoveItemFromInventory(handed_back)
	handed_back.forceMove(washer)
	washer.wash_cycle(warden)
	TEST_ASSERT(handed_back.grime < 0.01, "Washing left [handed_back.grime] grime")
	handed_back.forceMove(hatch_turf)
	qdel(handed_back)
	qdel(left_behind)

	// Thought bubbles: only when something needs attention; several needs take turns, every 4
	// seconds (PRISONER_BUBBLE_CYCLE), starting from the most urgent whenever the set changes.
	for(var/need in list("hungry", "dirty", "hurt", "riot", "experiment"))
		TEST_ASSERT_NOTNULL(outpost_prisoner_bubble_item(need), "The thought bubble has no item look for [need]")
	prisoner.set_hunger(10)
	prisoner.set_uniform_grime(90)
	prisoner.adjustBruteLoss(20)
	TEST_ASSERT_EQUAL(prisoner.bubble, "hungry", "Hunger did not come first among the needs")
	for(var/expected in list("hurt", "dirty", "hungry"))
		prisoner.bubble_clock += 4
		prisoner.update_bubble()
		TEST_ASSERT_EQUAL(prisoner.bubble, expected, "Four seconds on, the bubble showed [prisoner.bubble], not [expected]")
	prisoner.bubble_clock += 2
	prisoner.update_bubble()
	TEST_ASSERT_EQUAL(prisoner.bubble, "hungry", "The bubble changed before its 4 seconds were up")
	prisoner.experiment_subject = TRUE
	prisoner.update_bubble()
	TEST_ASSERT_EQUAL(prisoner.bubble, "experiment", "An experiment's subject did not show the syringe over their needs")
	prisoner.experiment_subject = FALSE
	prisoner.set_hunger(100)
	TEST_ASSERT_EQUAL(prisoner.bubble, "hurt", "The bubble did not start again at the injury when hunger was dealt with")
	prisoner.adjustBruteLoss(-20)
	TEST_ASSERT_EQUAL(prisoner.bubble, "dirty", "The bubble did not fall back to the dirty uniform")
	prisoner.set_uniform_grime(0)
	TEST_ASSERT_NULL(prisoner.bubble, "A well kept prisoner showed a bubble")
	prisoner.set_hunger(45)
	prisoner.set_uniform_grime(45)
	TEST_ASSERT_NULL(prisoner.bubble, "A prisoner above every threshold showed a bubble")

	// The bubble pops up now and then rather than staying: a need that has just come up pops it within
	// 3 seconds (PRISONER_BUBBLE_FRESH_DELAY), the next pop is 20 seconds or more away
	// (PRISONER_BUBBLE_GAP_MIN), and a need dealt with fades its bubble at once. They thanked the
	// warden for the uniform above; that has had its time over their head (see below).
	COOLDOWN_RESET(prisoner, bubble_hush)
	prisoner.set_hunger(10)
	if(!prisoner.popped_bubble)
		TEST_ASSERT(prisoner.bubble_next_pop <= world.time + 3 SECONDS, "A new need did not bring the bubble forward")
		prisoner.bubble_next_pop = world.time
		prisoner.update_bubble()
	TEST_ASSERT_EQUAL(prisoner.popped_bubble, "hungry", "The bubble did not pop up when it was due")
	TEST_ASSERT(prisoner.thought in prisoner.vis_contents, "The popped bubble is not drawn")
	TEST_ASSERT(prisoner.bubble_next_pop >= world.time + 20 SECONDS, "The next pop is under 20 seconds away")
	prisoner.update_bubble()
	TEST_ASSERT_EQUAL(prisoner.popped_bubble, "hungry", "The bubble popped again while it was up")
	prisoner.set_hunger(100)
	TEST_ASSERT_NULL(prisoner.popped_bubble, "The bubble stayed up after the need was dealt with")
	prisoner.end_bubble()
	TEST_ASSERT(!(prisoner.thought in prisoner.vis_contents), "The faded bubble was not taken down")

	// It sits over their head, a little to the right: its bottom edge (16 + rest_z - 16 x rest_scale)
	// clears their face (eyes about 26 px up), and it leans right without leaving the head. It never
	// shows while they talk (below), so runechat, which draws over it, never hides it.
	var/obj/effect/abstract/outpost_thought/thought = prisoner.thought
	TEST_ASSERT(thought.rest_scale >= 0.8, "The bubble settles at [thought.rest_scale] scale, too small to read")
	TEST_ASSERT(16 + thought.rest_z - 16 * thought.rest_scale >= 26, "The bubble's bottom edge is [16 + thought.rest_z - 16 * thought.rest_scale] px up, over their face")
	TEST_ASSERT(thought.pixel_w > 0 && thought.pixel_w <= 12, "The bubble is [thought.pixel_w] px to the side, not a little right of their head")

	// Talking puts it away: what they say goes up over their head, so a bubble that is up ducks out of
	// its way, and none pops for 5 seconds after they say or emote anything (PRISONER_BUBBLE_HUSH).
	prisoner.set_hunger(10)
	prisoner.bubble_next_pop = world.time
	prisoner.update_bubble()
	TEST_ASSERT_EQUAL(prisoner.popped_bubble, "hungry", "The hungry bubble did not pop up before they spoke")
	prisoner.say("Any chance of lunch in here?")
	TEST_ASSERT_NULL(prisoner.popped_bubble, "The bubble stayed up while they talked")
	TEST_ASSERT(prisoner.bubble_next_pop <= world.time + 8 SECONDS, "Talking put the next bubble off past the words and the fresh-need delay")
	prisoner.drop_bubble()
	prisoner.bubble_next_pop = world.time
	prisoner.update_bubble()
	TEST_ASSERT_NULL(prisoner.popped_bubble, "A bubble popped up over what they had just said")
	COOLDOWN_RESET(prisoner, bubble_hush)
	prisoner.update_bubble()
	TEST_ASSERT_EQUAL(prisoner.popped_bubble, "hungry", "The bubble did not come back once what they said had gone")
	prisoner.manual_emote("stares at the wall.")
	TEST_ASSERT_NULL(prisoner.popped_bubble, "The bubble stayed up through an emote")
	prisoner.drop_bubble()
	prisoner.bubble_next_pop = world.time
	prisoner.update_bubble()
	TEST_ASSERT_NULL(prisoner.popped_bubble, "A bubble popped up over their emote")
	COOLDOWN_RESET(prisoner, bubble_hush)
	prisoner.set_hunger(45)
	prisoner.drop_bubble()

	// Medical: the advanced med HUD tracks their health bar, and a bruise pack treats them.
	var/datum/atom_hud/medhud = GLOB.huds[DATA_HUD_MEDICAL_ADVANCED]
	TEST_ASSERT(medhud.hud_atoms_all_z_levels[prisoner], "The prisoner is not on the medical HUD")
	prisoner.adjustBruteLoss(40)
	var/image/health_bar = prisoner.hud_list[HEALTH_HUD]
	TEST_ASSERT_EQUAL(health_bar.icon_state, "hud[RoundHealth(prisoner)]", "The health bar did not follow the injury")
	TEST_ASSERT(abs(prisoner.care() - (200 + 60) / 3) < 0.01, "Care with 60 health was [prisoner.care()], not 86.7")
	prison.tick(10 * 60)
	TEST_ASSERT_EQUAL(prisoner.health, 60, "Health came back on its own")
	var/obj/item/stack/medical/bruise_pack/pack = allocate(__IMPLIED_TYPE__)
	TEST_ASSERT(pack.try_heal_checks(prisoner, warden, BODY_ZONE_CHEST, TRUE), "A bruise pack could not treat the prisoner")
	pack.heal_simplemob(prisoner, warden)
	TEST_ASSERT_EQUAL(prisoner.health, 100, "A bruise pack did not treat the prisoner")
	TEST_ASSERT_EQUAL(health_bar.icon_state, "hudhealth100", "The health bar did not recover")

	// Blood: a real brute hit leaves blood on the floor, and the wing counts it as mess.
	prisoner.forceMove(prison_spot(home, 10, 8))
	warden.forceMove(prison_spot(home, 10, 9))
	prison.refresh_conditions()
	var/mess_before = prison.mess_load
	var/obj/item/storage/toolbox/toolbox = allocate(__IMPLIED_TYPE__)
	warden.put_in_active_hand(toolbox)
	warden.set_combat_mode(TRUE)
	click_wrapper(warden, prisoner)
	warden.set_combat_mode(FALSE)
	TEST_ASSERT(prisoner.health < 100, "The toolbox did not hurt the prisoner")
	TEST_ASSERT(locate(/obj/effect/decal/cleanable/blood) in prison_spot(home, 10, 8), "A brute hit left no blood on the floor")
	prison.refresh_conditions()
	// Counted in the mess load; Clean itself only drops past PRISON_MESS_FREE units per 100 floor tiles.
	TEST_ASSERT(prison.mess_load > mess_before, "Blood on the floor did not count as mess")
	// Badly hurt and untreated, they drip; treated, they stop.
	prisoner.forceMove(prison_spot(home, 11, 8))
	prisoner.adjustBruteLoss(60 - prisoner.getBruteLoss())
	TEST_ASSERT(prisoner.maybe_drip(1000), "A prisoner at 40% health never dripped")
	TEST_ASSERT(locate(/obj/effect/decal/cleanable/blood) in prison_spot(home, 11, 8), "The drip left nothing on the floor")
	prisoner.adjustBruteLoss(-prisoner.getBruteLoss())
	TEST_ASSERT(!prisoner.maybe_drip(1000), "A treated prisoner still dripped")

	// The wing's first aid kit holds dressings and a scanner, nothing that goes in a mouth or vein.
	var/obj/item/storage/medkit/brute/outpost_prison/kit = locate() in prison_spot(home, 16, 2)
	TEST_ASSERT_NOTNULL(kit, "The prison first aid kit is not on the office table")
	TEST_ASSERT(locate(/obj/item/stack/medical/bruise_pack) in kit, "The prison kit has no bruise packs")
	TEST_ASSERT(locate(/obj/item/stack/medical/suture) in kit, "The prison kit has no sutures")
	for(var/obj/item/thing in kit)
		TEST_ASSERT(!istype(thing, /obj/item/reagent_containers) && !thing.reagents, "The prison kit holds [thing], which carries chemicals")
	settle_prison_air(home)

// ===== ROUTINE AND DIALOGUE =====

/datum/unit_test/voidcrew_outpost_prison_routine
	parent_type = /datum/unit_test/voidcrew_outpost_management

/datum/unit_test/voidcrew_outpost_prison_routine/proc/has_activity(mob/living/basic/outpost_prisoner/prisoner)
	return prisoner.activity?.started

/datum/unit_test/voidcrew_outpost_prison_routine/proc/in_flight(datum/prisoner_activity/basketball/game)
	return QDELETED(game) || !game.in_flight

/datum/unit_test/voidcrew_outpost_prison_routine/Run()
	var/obj/structure/overmap/dynamic/player_outpost/home = prison_test_claim("routineowner")
	TEST_ASSERT_NOTNULL(home, "The routine test prison did not load")
	var/datum/outpost_prison/prison = test_prison(home)
	var/list/personalities = outpost_prisoner_dialogue("personalities")
	var/list/crimes = outpost_prisoner_dialogue("crimes")
	var/list/lines = outpost_prisoner_dialogue("lines")
	var/list/conversations = outpost_prisoner_dialogue("conversations")

	// The dialogue file loads, with every context the prisoners use.
	TEST_ASSERT(length(personalities) >= 5, "The dialogue file has [length(personalities)] personalities")
	TEST_ASSERT(length(crimes), "The dialogue file has no crimes")
	TEST_ASSERT(length(conversations), "The dialogue file has no conversations")
	var/list/contexts = list("idle", "arrival", "release_soon", "release", "hungry", "starving", "filthy", "hurt", "dark", "dirty_prison", "no_power", "staff_near", "thanks_food", "thanks_uniform", "thanks_treatment", "eating", "basketball", "basketball_score", "basketball_miss", "reading", "resting", "sleeping", "water", "window", "pacing", "hatch_wait", "locked_in")
	for(var/context in contexts)
		var/list/entry = lines[context]
		TEST_ASSERT(islist(entry) && length(entry["any"]), "The dialogue file has no shared lines for [context]")
	for(var/datum/prisoner_activity/activity_type as anything in GLOB.outpost_prisoner_leisure + list(/datum/prisoner_activity/eat, /datum/prisoner_activity/hatch_wait))
		var/context = initial(activity_type.context)
		// The extras' pastimes keep their lines in their own dialogue files (outpost_prison_extras.dm).
		if(context)
			TEST_ASSERT(islist(outpost_prisoner_context_lines(context)), "[activity_type] speaks in a context no dialogue file has: [context]")

	var/mob/living/basic/outpost_prisoner/talker = test_prisoner(prison, prison_spot(home, 7, 8))
	var/mob/living/basic/outpost_prisoner/listener = test_prisoner(prison, prison_spot(home, 9, 8))
	TEST_ASSERT(talker.personality in personalities, "A prisoner got the personality [talker.personality]")
	TEST_ASSERT(talker.crime in crimes, "A prisoner got the crime [talker.crime]")
	TEST_ASSERT_EQUAL(talker.cell, prison.cells[1], "The first booked prisoner is not in cell 1")
	TEST_ASSERT_EQUAL(listener.cell, prison.cells[2], "The second booked prisoner is not in cell 2")

	// Placeholders: their own first name and crime, the other's first name, the time left.
	talker.sentence_left = 600
	var/filled = talker.fill_line("{name}|{other}|{crime}|{time_left}", listener)
	TEST_ASSERT_EQUAL(filled, "[first_name(talker.real_name)]|[first_name(listener.real_name)]|[talker.crime]|10 minutes", "Placeholders were filled as [filled]")
	talker.sentence_left = 50
	TEST_ASSERT_EQUAL(talker.time_left_text(), "a minute", "50 seconds read as [talker.time_left_text()]")
	talker.sentence_left = 20
	TEST_ASSERT_EQUAL(talker.time_left_text(), "20 seconds", "20 seconds read as [talker.time_left_text()]")
	talker.sentence_left = 3600
	for(var/i in 1 to 40)
		var/alone = talker.pick_line("idle", null)
		TEST_ASSERT(alone && !findtext(alone, "{") && !findtext(alone, "}"), "An idle line came out unfilled or empty: [alone]")
		var/together = talker.pick_line("idle", listener)
		TEST_ASSERT(together && !findtext(together, "{"), "An idle line to another came out unfilled: [together]")
		var/reply = talker.pick_line("release_soon", null)
		TEST_ASSERT(reply && !findtext(reply, "{"), "A release_soon line came out unfilled: [reply]")
	TEST_ASSERT_NULL(talker.pick_line("no_such_context", null), "A missing context produced a line")

	// Two-person conversations: an opener, and a reply from the other a few seconds later.
	listener.last_line = null
	TEST_ASSERT(talker.start_conversation(listener), "A conversation did not start")
	TEST_ASSERT_NOTNULL(talker.last_line, "The opener was not said")
	TEST_ASSERT(!prison.wing_can_speak(), "A conversation did not start the wing's speech cooldown")
	sleep(6 SECONDS)
	TEST_ASSERT_NOTNULL(listener.last_line, "Nobody replied to the opener")
	var/replied = FALSE
	for(var/list/conversation as anything in conversations)
		if(listener.last_line in conversation["replies"])
			replied = TRUE
			break
	TEST_ASSERT(replied, "The reply was not one of the file's replies: [listener.last_line]")

	// Cooldowns: nothing spontaneous while the prisoner's or the wing's cooldown runs.
	COOLDOWN_START(talker, speech_cooldown, 1 MINUTES)
	talker.said_release_soon = TRUE
	for(var/i in 1 to 50)
		TEST_ASSERT(!talker.speech_tick(), "A prisoner spoke inside their own cooldown")
	COOLDOWN_RESET(talker, speech_cooldown)
	prison.note_speech()
	for(var/i in 1 to 50)
		TEST_ASSERT(!talker.speech_tick(), "A prisoner spoke inside the wing's cooldown")
	COOLDOWN_RESET(prison, wing_speech_cooldown)
	var/spoke = FALSE
	for(var/i in 1 to 200)
		if(talker.speech_tick())
			spoke = TRUE
			break
	TEST_ASSERT(spoke, "A prisoner with no cooldown never spoke")
	TEST_ASSERT(!COOLDOWN_FINISHED(talker, speech_cooldown), "Speaking did not start the prisoner's cooldown")
	// Needs and the wing come first.
	talker.set_hunger(5)
	var/list/said = list()
	for(var/i in 1 to 40)
		var/list/choice = talker.pick_speech()
		if(choice)
			said |= choice[1]
	TEST_ASSERT("starving" in said, "A starving prisoner never talked about food ([jointext(said, ", ")])")
	for(var/context in said)
		TEST_ASSERT(context in lines, "A prisoner picked the missing context [context]")
	talker.set_hunger(100)

	// The routine: every leisure activity that can be set up goes somewhere they can walk, in the wing.
	REMOVE_TRAIT(talker, TRAIT_IMMOBILIZED, TRAIT_SOURCE_UNIT_TESTS)
	prison.refresh_conditions()
	var/list/set_up = list()
	for(var/activity_type in GLOB.outpost_prisoner_leisure)
		var/datum/prisoner_activity/activity = new activity_type(talker)
		if(activity.setup())
			set_up += activity_type
			if(activity.spot)
				TEST_ASSERT(talker.walkable[activity.spot], "[activity_type] sent them somewhere they cannot walk")
				TEST_ASSERT_EQUAL(activity.spot.loc, prison.wing, "[activity_type] sent them out of the wing")
		qdel(activity)
	TEST_ASSERT_EQUAL(length(prison.claims), 0, "Activities that were set up and dropped left claims behind")
	for(var/activity_type in list(/datum/prisoner_activity/rest, /datum/prisoner_activity/rest/sleep, /datum/prisoner_activity/sit_cell, /datum/prisoner_activity/toilet, /datum/prisoner_activity/sink, /datum/prisoner_activity/basketball, /datum/prisoner_activity/read, /datum/prisoner_activity/water, /datum/prisoner_activity/chat, /datum/prisoner_activity/pace, /datum/prisoner_activity/window, /datum/prisoner_activity/wander))
		TEST_ASSERT(activity_type in set_up, "[activity_type] could not be set up in a fresh wing")
	// Picking by needs, personality and what is free always gives something valid.
	for(var/i in 1 to 30)
		var/datum/prisoner_activity/chosen = talker.choose_activity()
		TEST_ASSERT_NOTNULL(chosen, "The routine found nothing to do")
		if(chosen.spot)
			TEST_ASSERT(talker.walkable[chosen.spot] && chosen.spot.loc == prison.wing, "[chosen.type] was chosen with a spot out of reach")
		talker.end_activity(cancel_ai = FALSE)

	// Resting: on their own bed, lying down; getting up afterwards.
	var/datum/prisoner_activity/rest/nap = talker.start_activity(new /datum/prisoner_activity/rest(talker))
	TEST_ASSERT(nap.setup(), "Resting could not be set up")
	TEST_ASSERT_EQUAL(nap.spot, get_turf(talker.cell.bed()), "Resting did not go to their own bed")
	talker.forceMove(nap.spot)
	nap.arrive()
	TEST_ASSERT_EQUAL(talker.buckled, talker.cell.bed(), "Resting did not put them in bed")
	TEST_ASSERT_EQUAL(talker.body_position, LYING_DOWN, "Resting in bed was not lying down")
	TEST_ASSERT_EQUAL(nap.tick(1), 0, "Resting ended at once") // ACTIVITY_CONTINUE
	talker.end_activity(cancel_ai = FALSE)
	TEST_ASSERT_NULL(talker.buckled, "Getting up left them in bed")

	// Sitting in their cell: in its chair, facing the way it does; the bed is for lying down.
	var/obj/structure/chair/cell_chair = talker.cell.chair()
	TEST_ASSERT_NOTNULL(cell_chair, "The talker's cell has no chair")
	var/datum/prisoner_activity/sit_cell/sitting = talker.start_activity(new /datum/prisoner_activity/sit_cell(talker))
	TEST_ASSERT(sitting.setup(), "Sitting in the cell could not be set up")
	TEST_ASSERT_EQUAL(sitting.spot, get_turf(cell_chair), "Sitting in the cell did not go to its chair")
	talker.forceMove(sitting.spot)
	sitting.arrive()
	TEST_ASSERT_EQUAL(talker.buckled, cell_chair, "Sitting in the cell did not put them in its chair")
	TEST_ASSERT_EQUAL(talker.dir, cell_chair.dir, "Sitting in the chair, they did not face the way it does")
	TEST_ASSERT_EQUAL(sitting.tick(1), 0, "Sitting ended at once") // ACTIVITY_CONTINUE
	talker.end_activity(cancel_ai = FALSE)
	TEST_ASSERT_NULL(talker.buckled, "Getting up left them in the chair")
	// With the chair gone they lie on their bed instead, never stand on it.
	var/turf/chair_turf = get_turf(cell_chair)
	var/chair_dir = cell_chair.dir
	qdel(cell_chair)
	TEST_ASSERT_NULL(talker.cell.chair(), "The cell still has a chair")
	sitting = talker.start_activity(new /datum/prisoner_activity/sit_cell(talker))
	TEST_ASSERT(sitting.setup(), "With the chair gone, sitting in the cell could not be set up")
	TEST_ASSERT_EQUAL(sitting.spot, get_turf(talker.cell.bed()), "With the chair gone, they did not go to their bed")
	talker.forceMove(sitting.spot)
	sitting.arrive()
	TEST_ASSERT_EQUAL(talker.buckled, talker.cell.bed(), "With the chair gone, they did not lie on their bed")
	TEST_ASSERT_EQUAL(talker.body_position, LYING_DOWN, "On the bed with no chair, they were not lying down")
	talker.end_activity(cancel_ai = FALSE)
	var/obj/structure/chair/replacement = allocate(/obj/structure/chair, chair_turf)
	replacement.setDir(chair_dir)
	TEST_ASSERT_EQUAL(talker.cell.chair(), replacement, "A chair put back in the cell is not its chair")

	// Reading: a book off the shelf, read in the chair by the bookcase.
	talker.forceMove(prison_spot(home, 4, 8))
	prison.refresh_prisoner_reach(talker)
	var/obj/structure/bookcase/shelf = locate() in prison_spot(home, 2, 7)
	TEST_ASSERT_NOTNULL(shelf, "The bookcase is not where the map puts it")
	TEST_ASSERT(locate(/obj/item/book) in shelf, "The bookcase has no books")
	var/datum/prisoner_activity/read/reading = talker.start_activity(new /datum/prisoner_activity/read(talker))
	TEST_ASSERT(reading.setup(), "Reading could not be set up")
	for(var/i in 1 to 20)
		if(reading.stage == "reading")
			break
		if(reading.spot && talker.loc != reading.spot)
			talker.stand_up()
			talker.forceMove(reading.spot)
		if(reading.spot || !reading.started)
			reading.arrive()
			continue
		reading.tick(1)
	TEST_ASSERT_EQUAL(reading.stage, "reading", "The prisoner never sat down to read")
	TEST_ASSERT(istype(talker.held_item, /obj/item/book), "The prisoner is reading without a book")
	TEST_ASSERT(istype(talker.buckled, /obj/structure/chair/comfy), "The prisoner is not reading in the chair")
	reading.ends_at = world.time
	drive_activity(talker, reading)
	TEST_ASSERT_NULL(talker.activity, "Reading never ended")
	TEST_ASSERT_NULL(talker.held_item, "The book stayed in their hands after reading")

	// Basketball: the ball, a shot at the hoop, the rebound.
	talker.forceMove(prison_spot(home, 9, 8))
	prison.refresh_prisoner_reach(talker)
	var/obj/structure/hoop/hoop = locate() in prison_spot(home, 9, 11)
	TEST_ASSERT_NOTNULL(hoop, "The hoop is not where the map puts it")
	TEST_ASSERT_NOTNULL(locate(/obj/item/toy/basketball) in prison_spot(home, 9, 9), "The ball is not where the map puts it")
	var/datum/prisoner_activity/basketball/game = talker.start_activity(new /datum/prisoner_activity/basketball(talker))
	TEST_ASSERT(game.setup(), "Basketball could not be set up")
	game.arrive()
	var/shots = 0
	for(var/i in 1 to 40)
		if(game.in_flight)
			shots++
			TEST_ASSERT(wait_until(CALLBACK(src, PROC_REF(in_flight), game), 5 SECONDS), "A shot never landed")
			if(shots >= 2)
				break
		if(game.spot && talker.loc != game.spot)
			talker.forceMove(game.spot)
			game.arrive()
			continue
		game.tick(1)
	if(shots < 2)
		// Seen now and then (about one run in ten); say where everything was, to find out why.
		var/obj/item/toy/basketball/ball = game.ball_ref?.resolve()
		var/turf/ball_turf = get_turf(ball)
		var/list/on_ball_turf = list()
		for(var/atom/movable/thing as anything in ball_turf?.contents)
			on_ball_turf += "[thing.type]"
		TEST_FAIL("The prisoner took [shots] shot\s in 40 steps: prisoner at [talker.x],[talker.y] holding [talker.held_item || "nothing"], \
			spot [game.spot ? "[game.spot.x],[game.spot.y]" : "none"], ball [ball ? "in [ball.loc] at [ball_turf?.x],[ball_turf?.y] with [jointext(on_ball_turf, ", ")]" : "gone"], \
			ball walkable [!!talker.walkable?[ball_turf]], reach [ball ? talker.try_reach(ball) : "-"], claimed by other [prison.claimed_by_other(ball, talker)], \
			game over [world.time >= game.ends_at]")
		return
	talker.end_activity(cancel_ai = FALSE)
	TEST_ASSERT(!istype(talker.held_item, /obj/item/toy/basketball), "The ball stayed in their hands after the game")

	// Chatting: walks up to another prisoner, who stops to listen, and they face each other.
	listener.forceMove(prison_spot(home, 11, 8))
	talker.forceMove(prison_spot(home, 7, 8))
	REMOVE_TRAIT(listener, TRAIT_IMMOBILIZED, TRAIT_SOURCE_UNIT_TESTS)
	prison.refresh_reach()
	var/datum/prisoner_activity/chat/chat = talker.start_activity(new /datum/prisoner_activity/chat(talker))
	TEST_ASSERT(chat.setup(), "A chat could not be set up with another prisoner in the yard")
	TEST_ASSERT(get_dist(chat.spot, listener) <= 1, "The chat did not go up to the other prisoner")
	talker.forceMove(chat.spot)
	COOLDOWN_RESET(prison, wing_speech_cooldown)
	TEST_ASSERT(chat.arrive(), "The chat did not start on arrival")
	TEST_ASSERT(istype(listener.activity, /datum/prisoner_activity/chat/listen), "The other prisoner did not stop to listen")
	TEST_ASSERT_EQUAL(listener.activity.chat_partner(), talker, "The listener is not listening to the talker")
	TEST_ASSERT_EQUAL(chat.tick(1), 0, "The chat ended at once") // ACTIVITY_CONTINUE
	TEST_ASSERT_EQUAL(talker.dir, get_dir(talker, listener), "The talker does not face the listener")
	talker.end_activity(cancel_ai = FALSE)
	TEST_ASSERT_NULL(listener.activity, "The listener kept listening after the chat")

	// The live AI: with someone on the level, a prisoner picks something and walks to it.
	var/mob/living/carbon/human/watcher = make_player(prison_spot(home, 9, 4), "routineowner")
	var/z = talker.z
	SSmobs.clients_by_zlevel[z] |= watcher
	talker.end_activity(cancel_ai = FALSE)
	// Away from the listener: still beside them from the chat, a second chat would start where they
	// stand (approach_turf() gives their own tile) and they would never need to walk.
	talker.forceMove(prison_spot(home, 7, 8))
	prison.refresh_prisoner_reach(talker)
	talker.ai_controller.reset_ai_status()
	TEST_ASSERT_EQUAL(talker.ai_controller.ai_status, AI_STATUS_ON, "The prisoner's AI did not wake with someone on the level")
	var/turf/start_turf = talker.loc
	var/woke = wait_until(CALLBACK(src, PROC_REF(has_activity), talker), 20 SECONDS)
	SSmobs.clients_by_zlevel[z] -= watcher
	talker.ai_controller.reset_ai_status()
	TEST_ASSERT(woke, "The awake prisoner never started an activity (now [talker.activity?.name], at [talker.x],[talker.y])")
	TEST_ASSERT(talker.loc != start_turf || !talker.activity.spot, "The awake prisoner never walked anywhere")
	TEST_ASSERT_EQUAL(get_area(talker), prison.wing, "The awake prisoner left the wing")
	talker.end_activity()
	settle_prison_air(home)

// ===== WHAT NEEDS DO TO MOOD =====

/datum/unit_test/voidcrew_outpost_prison_mood_needs
	parent_type = /datum/unit_test/voidcrew_outpost_management

/datum/unit_test/voidcrew_outpost_prison_mood_needs/Run()
	var/obj/structure/overmap/dynamic/player_outpost/home = trouble_test_claim("moodneedsowner")
	TEST_ASSERT_NOTNULL(home, "The needs mood test prison did not load")
	var/datum/outpost_prison/prison = test_prison(home)
	var/mob/living/basic/outpost_prisoner/prisoner = trouble_prisoner(prison, prison_spot(home, 8, 8))
	TEST_ASSERT(abs(prison.conditions_score() - 100) < 0.01, "The mood test wing is not in perfect condition")

	// Per minute: a well kept prisoner in a wing with every condition at 80+ gains 2.
	TEST_ASSERT(drift_is(prisoner, 2), "A well kept prisoner drifts [prisoner.mood_drift_per_minute()], not +2")
	prisoner.set_hunger(30)
	TEST_ASSERT(drift_is(prisoner, 2 - 3), "Hungry drifts [prisoner.mood_drift_per_minute()], not -1") // PRISONER_MOOD_HUNGRY
	prisoner.set_hunger(10)
	TEST_ASSERT(drift_is(prisoner, 2 - 8), "Starving drifts [prisoner.mood_drift_per_minute()], not -6") // PRISONER_MOOD_STARVING
	prisoner.set_hunger(100)
	prisoner.set_uniform_grime(60)
	TEST_ASSERT(drift_is(prisoner, 2 - 2), "A dirty uniform drifts [prisoner.mood_drift_per_minute()], not 0") // PRISONER_MOOD_DIRTY
	prisoner.set_uniform_grime(90)
	TEST_ASSERT(drift_is(prisoner, 2 - 5), "A filthy uniform drifts [prisoner.mood_drift_per_minute()], not -3") // PRISONER_MOOD_FILTHY
	prisoner.set_uniform_grime(0)
	// Injuries cost mood only below 75% health (PRISONER_HURT_MOOD_BELOW): 8 x (75 - health) / 75.
	prisoner.adjustBruteLoss(20)
	TEST_ASSERT(drift_is(prisoner, 2), "80% health drifts [prisoner.mood_drift_per_minute()], not +2")
	prisoner.adjustBruteLoss(30)
	TEST_ASSERT(drift_is(prisoner, 2 - 8 * 25 / 75), "Half health drifts [prisoner.mood_drift_per_minute()], not [2 - 8 * 25 / 75]") // PRISONER_MOOD_HURT
	prisoner.adjustBruteLoss(-50)

	// Instant changes: a meal +10, a clean uniform +8, treatment +8.
	prisoner.set_mood(40)
	prisoner.set_hunger(20)
	var/obj/item/food/prison_ration/meal = new(prison_spot(home, 8, 8))
	prisoner.finish_meal(meal, prison_spot(home, 8, 8), null)
	TEST_ASSERT(abs(prisoner.mood - 50) < 0.01, "A meal left mood at [prisoner.mood], not 50") // PRISONER_MOOD_FED
	prisoner.set_uniform_grime(80)
	var/obj/item/clothing/under/rank/prisoner/outpost/fresh = new(prison_spot(home, 8, 8))
	prisoner.swap_uniform(fresh, prison_spot(home, 8, 8))
	TEST_ASSERT(abs(prisoner.mood - 58) < 0.01, "A clean uniform left mood at [prisoner.mood], not 58") // PRISONER_MOOD_CLEAN_UNIFORM
	prisoner.adjustBruteLoss(30)
	COOLDOWN_START(prisoner, treatment_window, 20 SECONDS)
	prisoner.adjustBruteLoss(-30)
	TEST_ASSERT(abs(prisoner.mood - 66) < 0.01, "Treatment left mood at [prisoner.mood], not 66") // PRISONER_MOOD_TREATED
	settle_prison_air(home)

// ===== HELPERS FOR THE TESTS BELOW =====

/// Clears everything off a serving hatch and returns how many items it holds when empty
/datum/unit_test/voidcrew_outpost_management/proc/clear_hatch(obj/structure/table/reinforced/prison_hatch/hatch)
	for(var/obj/item/thing in hatch.loc)
		qdel(thing)
	return hatch.room_left()

/// Puts `count` rations on a serving hatch, bypassing its capacity check
/datum/unit_test/voidcrew_outpost_management/proc/stock_hatch(obj/structure/table/reinforced/prison_hatch/hatch, count)
	for(var/i in 1 to count)
		new /obj/item/food/prison_ration(hatch.loc)

/datum/unit_test/voidcrew_outpost_management/proc/count_on(turf/tile, item_type)
	var/count = 0
	for(var/obj/item/thing in tile)
		if(istype(thing, item_type))
			count++
	return count

// ===== ARRIVALS, HUNGER, GRIME, SPORT AND FOOD =====

/datum/unit_test/voidcrew_outpost_prison_arrivals_food
	parent_type = /datum/unit_test/voidcrew_outpost_management

/datum/unit_test/voidcrew_outpost_prison_arrivals_food/proc/present(mob/living/basic/outpost_prisoner/prisoner)
	return prisoner.phase == "present"

/datum/unit_test/voidcrew_outpost_prison_arrivals_food/Run()
	var/obj/structure/overmap/dynamic/player_outpost/home = prison_test_claim("arrivalowner")
	TEST_ASSERT_NOTNULL(home, "The arrivals test prison did not load")
	var/datum/outpost_prison/prison = test_prison(home)
	var/mob/living/basic/outpost_prisoner/prisoner = test_prisoner(prison, prison_spot(home, 8, 8))

	// Arrivals, 200 of them: hunger 35-75, a third in a stained uniform (55-70 grime, else 0-15), and a
	// fifth roughed up to 60-85% health (PRISONER_ARRIVAL_*, _STAINED_*, _HURT_ARRIVAL_*).
	var/stained = 0
	var/hurt = 0
	for(var/i in 1 to 200)
		prisoner.roll_arrival()
		TEST_ASSERT(prisoner.hunger >= 35 && prisoner.hunger <= 75, "An arrival came in at [prisoner.hunger] hunger")
		if(prisoner.arrived_stained)
			stained++
			TEST_ASSERT(prisoner.uniform_grime >= 55 && prisoner.uniform_grime <= 70, "A stained arrival had [prisoner.uniform_grime] grime")
		else
			TEST_ASSERT(prisoner.uniform_grime >= 0 && prisoner.uniform_grime <= 15, "An ordinary arrival had [prisoner.uniform_grime] grime")
		if(prisoner.arrival_brute)
			hurt++
			TEST_ASSERT(prisoner.arrival_brute >= 15 && prisoner.arrival_brute <= 40, "A roughed-up arrival carried [prisoner.arrival_brute] brute")
	TEST_ASSERT(stained >= 45 && stained <= 95, "[stained] of 200 arrivals came in stained, not about 70")
	TEST_ASSERT(hurt >= 20 && hurt <= 60, "[hurt] of 200 arrivals came in hurt, not about 40")
	// The injury lands as they beam in, with no attacker: no blood, and a hurt bubble.
	prisoner.roll_arrival()
	prisoner.arrival_brute = 25
	prisoner.beam_in()
	TEST_ASSERT_EQUAL(prisoner.health, 75, "Beaming in roughed up left [prisoner.health] health, not 75")
	TEST_ASSERT(prisoner.arrived_hurt, "A roughed-up arrival was not marked hurt")
	TEST_ASSERT_NULL(locate(/obj/effect/decal/cleanable/blood) in get_turf(prisoner), "A transfer injury bled on the floor")
	TEST_ASSERT(wait_until(CALLBACK(src, PROC_REF(present), prisoner), 6 SECONDS), "The arrival never finished beaming in")
	prisoner.set_hunger(100)
	prisoner.set_uniform_grime(0)
	TEST_ASSERT_EQUAL(prisoner.bubble, "hurt", "A roughed-up arrival did not show the hurt bubble")
	prisoner.adjustBruteLoss(-25)

	// Hunger 5 a minute (PRISONER_HUNGER_DECAY), paused while well fed.
	prisoner.adjust_needs(60)
	TEST_ASSERT(abs(prisoner.hunger - 95) < 0.01, "A minute took [100 - prisoner.hunger] hunger, not 5")
	prisoner.well_fed_left = 30
	prisoner.adjust_needs(60)
	TEST_ASSERT(abs(prisoner.hunger - 92.5) < 0.01, "Thirty seconds well fed still took hunger (now [prisoner.hunger])")
	TEST_ASSERT_EQUAL(prisoner.well_fed_left, 0, "Well fed did not run out")

	// Fed and clean fall to nothing at starving (15) and filthy (80).
	var/list/fed_points = list("40" = 100, "27.5" = 50, "15" = 0, "5" = 0, "90" = 100)
	for(var/point in fed_points)
		prisoner.set_hunger(text2num(point))
		TEST_ASSERT(abs(prisoner.fed_factor() - fed_points[point]) < 0.01, "Hunger [point] gave fed [prisoner.fed_factor()], not [fed_points[point]]")
	var/list/clean_points = list("49" = 100, "65" = 50, "80" = 0, "95" = 0)
	for(var/point in clean_points)
		prisoner.set_uniform_grime(text2num(point))
		TEST_ASSERT(abs(prisoner.clean_factor() - clean_points[point]) < 0.01, "Grime [point] gave clean [prisoner.clean_factor()], not [clean_points[point]]")
	prisoner.set_hunger(100)
	prisoner.set_uniform_grime(0)

	// Sport: three times the grime (PRISONER_GRIME_SPORT_MULT) at basketball or a workout, not pacing.
	// At 45% health they play carefully, so no injury gets in the way here (PRISONER_SPORT_INJURY_ABOVE).
	prisoner.adjustBruteLoss(55)
	var/datum/prisoner_activity/basketball/game = new(prisoner)
	game.started = TRUE
	prisoner.activity = game
	prisoner.adjust_needs(60)
	TEST_ASSERT(abs(prisoner.uniform_grime - 7.5) < 0.01, "A minute of basketball added [prisoner.uniform_grime] grime, not 7.5")
	prisoner.end_activity(cancel_ai = FALSE)
	var/datum/prisoner_activity/pace/walk = new(prisoner)
	walk.started = TRUE
	prisoner.activity = walk
	prisoner.set_uniform_grime(0)
	prisoner.adjust_needs(60)
	TEST_ASSERT(abs(prisoner.uniform_grime - 2.5) < 0.01, "A minute of pacing added [prisoner.uniform_grime] grime, not 2.5")
	walk.exercising = TRUE
	prisoner.set_uniform_grime(0)
	prisoner.adjust_needs(60)
	TEST_ASSERT(abs(prisoner.uniform_grime - 7.5) < 0.01, "A minute of working out added [prisoner.uniform_grime] grime, not 7.5")
	TEST_ASSERT(!prisoner.sport_injury(), "A badly hurt prisoner was injured at sport")
	// A sport injury: 8-15 brute (PRISONER_SPORT_INJURY_MIN/_MAX), no blood, and they stop.
	prisoner.adjustBruteLoss(-55)
	TEST_ASSERT(prisoner.sport_injury(), "A healthy prisoner working out could not be injured")
	TEST_ASSERT(prisoner.health >= 85 && prisoner.health <= 92, "A sport injury left [prisoner.health] health")
	TEST_ASSERT_NULL(prisoner.activity, "The injured prisoner kept working out")
	TEST_ASSERT_NULL(locate(/obj/effect/decal/cleanable/blood) in get_turf(prisoner), "A sport injury bled on the floor")
	prisoner.adjustBruteLoss(-prisoner.getBruteLoss())
	prisoner.set_uniform_grime(0)

	// Food by quality: the prison ration and the Sustenance Vendor's tofu and candy corn, cooked food, snacks and junk food,
	// and poor food, the vendor's moldy bread among it.
	var/list/tiers = list(
		/obj/item/food/prison_ration = "ration",
		/obj/item/food/tofu/prison = "ration",
		/obj/item/food/candy_corn/prison = "ration",
		/obj/item/food/burger/plain = "cooked",
		/obj/item/food/donkpocket = "cooked",
		/obj/item/food/chips = "snack",
		/obj/item/food/candy = "snack",
		/obj/item/food/breadslice/plain = "snack",
		/obj/item/food/meat/slab = "poor",
		/obj/item/food/grown/potato = "poor",
		/obj/item/food/badrecipe = "poor",
		/obj/item/food/breadslice/moldy = "poor",
	)
	var/turf/table = prison_spot(home, 5, 9)
	for(var/food_type in tiers)
		var/obj/item/food/sample = allocate(food_type, table)
		TEST_ASSERT_EQUAL(outpost_prisoner_food_tier(sample), tiers[food_type], "[food_type] counted as [outpost_prisoner_food_tier(sample)] food")
		qdel(sample)
	// Hunger and mood: ration 60/+10, cooked 60/+15 and 8 minutes well fed, snack 35/+5, poor 20/+0.
	var/list/values = list(
		/obj/item/food/prison_ration = list(60, 10, 0),
		/obj/item/food/tofu/prison = list(60, 10, 0),
		/obj/item/food/burger/plain = list(60, 15, 480),
		/obj/item/food/chips = list(35, 5, 0),
		/obj/item/food/meat/slab = list(20, 0, 0),
	)
	prisoner.set_mood(40)
	for(var/food_type in values)
		var/list/expected = values[food_type]
		prisoner.set_hunger(10)
		prisoner.set_mood(40)
		prisoner.well_fed_left = 0
		var/obj/item/food/meal = allocate(food_type, get_turf(prisoner))
		prisoner.finish_meal(meal, get_turf(prisoner), null)
		TEST_ASSERT(abs(prisoner.hunger - (10 + expected[1])) < 0.01, "[food_type] left hunger at [prisoner.hunger], not [10 + expected[1]]")
		TEST_ASSERT(abs(prisoner.mood - (40 + expected[2])) < 0.01, "[food_type] left mood at [prisoner.mood], not [40 + expected[2]]")
		TEST_ASSERT_EQUAL(prisoner.well_fed_left, expected[3], "[food_type] left them well fed for [prisoner.well_fed_left] seconds")
	// Well fed after cooked food: they don't go looking for food, and refuse it by hand.
	var/mob/living/carbon/human/warden = make_player(prison_spot(home, 9, 8), "arrivalowner")
	prisoner.set_hunger(20)
	prisoner.well_fed_left = 480
	TEST_ASSERT(!prisoner.wants_food(), "A well fed prisoner went looking for food")
	var/obj/item/food/prison_ration/refused = allocate(__IMPLIED_TYPE__)
	warden.put_in_active_hand(refused)
	click_wrapper(warden, prisoner)
	TEST_ASSERT(!QDELETED(refused) && warden.is_holding(refused), "A well fed prisoner ate a ration by hand")
	// By hand the tiers hold too: a cooked meal fed by hand keeps them full.
	prisoner.well_fed_left = 0
	warden.drop_all_held_items()
	var/obj/item/food/burger/plain/burger = allocate(__IMPLIED_TYPE__)
	warden.put_in_active_hand(burger)
	click_wrapper(warden, prisoner)
	TEST_ASSERT(QDELETED(burger), "The prisoner did not eat a burger handed to them")
	TEST_ASSERT(abs(prisoner.hunger - 80) < 0.01, "A burger by hand left hunger at [prisoner.hunger], not 80")
	TEST_ASSERT_EQUAL(prisoner.well_fed_left, 480, "A burger by hand did not keep them full")
	TEST_ASSERT_EQUAL(prisoner.last_carer_ref?.resolve(), warden, "Feeding by hand was not noted")
	settle_prison_air(home)

// ===== THE SERVING HATCH: THE ONLY STOCKPILE =====

/datum/unit_test/voidcrew_outpost_prison_hatch
	parent_type = /datum/unit_test/voidcrew_outpost_management

/datum/unit_test/voidcrew_outpost_prison_hatch/Run()
	var/obj/structure/overmap/dynamic/player_outpost/home = prison_test_claim("hatchowner")
	TEST_ASSERT_NOTNULL(home, "The hatch test prison did not load")
	var/datum/outpost_prison/prison = test_prison(home)
	var/turf/hatch_turf = prison_spot(home, 5, 6)
	var/turf/office_side = prison_spot(home, 5, 5)
	var/turf/yard_side = prison_spot(home, 5, 7)
	var/obj/structure/table/reinforced/prison_hatch/hatch = locate() in hatch_turf
	var/obj/structure/table/reinforced/prison_hatch/east_hatch = locate() in prison_spot(home, 13, 6)
	TEST_ASSERT(hatch && east_hatch, "The serving hatches are not where the map puts them")
	var/capacity = clear_hatch(hatch)
	clear_hatch(east_hatch)
	// OUTPOST_PRISON_HATCH_CAPACITY, read off an empty hatch so a retune does not break the tests.
	TEST_ASSERT(capacity >= 6, "An empty hatch holds only [capacity] items")
	var/mob/living/basic/outpost_prisoner/prisoner = test_prisoner(prison, yard_side)
	var/mob/living/carbon/human/warden = make_player(office_side, "hatchowner")

	// Food anywhere in the wing they can reach is theirs, for the AI's eating (setup) and for an
	// unwatched prisoner helping themself (fend_for_self). Uniforms only come off a hatch.
	prisoner.set_hunger(30)
	prisoner.set_uniform_grime(90)
	var/obj/item/food/prison_ration/floor_food = allocate(__IMPLIED_TYPE__, prison_spot(home, 6, 7))
	var/obj/item/food/prison_ration/table_food = allocate(__IMPLIED_TYPE__, prison_spot(home, 5, 9))
	var/obj/item/clothing/under/rank/prisoner/outpost/floor_suit = allocate(__IMPLIED_TYPE__, prison_spot(home, 6, 7))
	prison.refresh_reach()
	TEST_ASSERT(prisoner.reachable[get_turf(floor_food)] && prisoner.reachable[get_turf(table_food)], "The test food is out of the prisoner's reach")
	var/obj/item/food/found = prison.find_supply(prisoner)
	TEST_ASSERT(found == floor_food || found == table_food, "A prisoner would not go for food on the floor or a mess table")
	TEST_ASSERT_NULL(prison.find_supply(prisoner, TRUE), "A prisoner went for a uniform on the floor")
	var/datum/prisoner_activity/eat/meal = new(prisoner)
	TEST_ASSERT(meal.setup(), "The AI would not go for food on the floor or a mess table")
	qdel(meal)
	var/datum/prisoner_activity/change/change = new(prisoner)
	TEST_ASSERT(!change.setup(), "The AI set off to change into a uniform that was not on a hatch")
	qdel(change)
	TEST_ASSERT_NOTEQUAL(prisoner.ai_controller.ai_status, AI_STATUS_ON, "The prisoner's AI runs in a world with no players")
	prison.tick(5)
	TEST_ASSERT(QDELETED(floor_food) || QDELETED(table_food), "An unwatched prisoner did not eat food off the floor or a table")
	TEST_ASSERT(abs(prisoner.uniform_grime - 90) < 1, "An unwatched prisoner changed into a uniform off the floor")
	// Whatever is left goes; hungry again, the hatch's food is theirs too.
	if(!QDELETED(floor_food))
		qdel(floor_food)
	if(!QDELETED(table_food))
		qdel(table_food)
	prisoner.set_hunger(30)
	var/obj/item/food/prison_ration/hatch_food = allocate(__IMPLIED_TYPE__, hatch_turf)
	meal = new(prisoner)
	TEST_ASSERT(meal.setup(), "The AI would not go for food on the hatch")
	qdel(meal)
	prison.tick(5)
	TEST_ASSERT(QDELETED(hatch_food), "An unwatched prisoner did not eat food on the hatch")
	qdel(floor_suit)
	clear_hatch(hatch)

	// Capacity: by hand, the eleventh item is refused and stays in the hand.
	stock_hatch(hatch, capacity - 1)
	var/obj/item/clothing/under/rank/prisoner/outpost/fresh = new(hatch_turf)
	TEST_ASSERT_EQUAL(hatch.room_left(), 0, "A full hatch still had room")
	var/obj/item/food/prison_ration/extra = allocate(__IMPLIED_TYPE__)
	warden.put_in_active_hand(extra)
	TEST_ASSERT_EQUAL(hatch.table_place_act(warden, extra, list()), ITEM_INTERACT_BLOCKING, "A full hatch took another item")
	TEST_ASSERT(warden.is_holding(extra), "The refused item left the warden's hand")
	TEST_ASSERT_EQUAL(hatch.stock_count(), capacity, "The hatch holds [hatch.stock_count()] items after a refusal")
	// Dumped or thrown on, it slides back off where it came from.
	warden.dropItemToGround(extra)
	TEST_ASSERT_EQUAL(extra.loc, office_side, "The refused item was not dropped at the warden's feet")
	extra.forceMove(hatch_turf)
	TEST_ASSERT_EQUAL(extra.loc, office_side, "An item pushed onto a full hatch stayed on it")
	// A prisoner's swap on a full hatch goes through, one for one.
	prisoner.set_uniform_grime(90)
	prison.refresh_reach()
	TEST_ASSERT_EQUAL(prison.find_supply(prisoner, TRUE), fresh, "A dirty prisoner did not find the clean uniform on the full hatch")
	TEST_ASSERT(reach_until_ok(prisoner, fresh), "The prisoner could not reach the full hatch")
	TEST_ASSERT(prisoner.take_uniform(fresh), "A swap on a full hatch was refused")
	TEST_ASSERT(prisoner.uniform_grime < 0.01, "The swap did not leave the prisoner clean")
	var/obj/item/clothing/under/rank/prisoner/outpost/left = locate() in hatch_turf
	TEST_ASSERT(left && left.grime > 89, "The dirty uniform was not left on the hatch")
	TEST_ASSERT_EQUAL(hatch.stock_count(), capacity, "The swap changed the hatch's count to [hatch.stock_count()]")
	// A tray: as much as fits goes on, the rest stays on the tray.
	qdel(left)
	qdel(extra)
	var/obj/item/storage/bag/tray/tray = allocate(__IMPLIED_TYPE__)
	for(var/i in 1 to 3)
		new /obj/item/food/prison_ration(tray)
	warden.put_in_active_hand(tray)
	TEST_ASSERT_EQUAL(hatch.room_left(), 1, "The tray test hatch has the wrong room")
	TEST_ASSERT_EQUAL(hatch.tray_act(warden, tray), ITEM_INTERACT_SUCCESS, "A tray could not put anything on a hatch with room")
	TEST_ASSERT_EQUAL(hatch.stock_count(), capacity, "A tray overfilled or underfilled the hatch ([hatch.stock_count()])")
	TEST_ASSERT_EQUAL(length(tray.contents), 2, "The tray kept [length(tray.contents)] items, not the 2 that did not fit")
	clear_hatch(hatch)

	// Stock: meals, clean and dirty suits, capacity, and how long it lasts at 0.11 meals and 0.045
	// suits a prisoner-minute (OUTPOST_PRISON_MEAL_RATE / _SUIT_RATE).
	stock_hatch(hatch, 3)
	new /obj/item/clothing/under/rank/prisoner/outpost(hatch_turf)
	new /obj/item/clothing/under/rank/prisoner/outpost(prison_spot(home, 13, 6))
	var/obj/item/clothing/under/rank/prisoner/outpost/dirty = new(hatch_turf)
	dirty.set_grime(70)
	var/list/stock = prison.hatch_stock()
	TEST_ASSERT_EQUAL(stock["meals"], 3, "The stock counted [stock["meals"]] meals")
	TEST_ASSERT_EQUAL(stock["clean_suits"], 2, "The stock counted [stock["clean_suits"]] clean suits")
	TEST_ASSERT_EQUAL(stock["dirty_suits"], 1, "The stock counted [stock["dirty_suits"]] dirty suits")
	TEST_ASSERT_EQUAL(stock["capacity"], capacity * 2, "The stock capacity was [stock["capacity"]]")
	TEST_ASSERT_EQUAL(stock["lasts_minutes"], round(min(3 / 0.11, 2 / 0.045)), "One prisoner's stock lasts [stock["lasts_minutes"]] minutes")
	clear_hatch(hatch)
	clear_hatch(east_hatch)

	// Shortage: hungry with nothing on the hatches is a shortage, and the radio hears about it once.
	prisoner.set_hunger(30)
	prisoner.set_uniform_grime(0)
	prison.hatch_warning_left = 0
	prison.tick(5)
	TEST_ASSERT(prison.hatch_shortage(), "A hungry prisoner at empty hatches was not a shortage")
	TEST_ASSERT_EQUAL(prison.waiting_for_food, 1, "[prison.waiting_for_food] prisoners were counted waiting for food")
	TEST_ASSERT_EQUAL(prison.hatch_warning_text(), "The hatch is out of food and 1 prisoner is waiting.", "The warning read: [prison.hatch_warning_text()]")
	TEST_ASSERT(prison.hatch_warning_left > 590, "The empty hatch was not reported (or the next report is due in [prison.hatch_warning_left] s)")
	// The warning goes in the warden's log, not out over the outpost.
	var/list/hatch_entry = prison.entries[1]
	TEST_ASSERT_EQUAL(hatch_entry["text"], "The hatch is out of food and 1 prisoner is waiting.", "The empty hatch was not logged: [hatch_entry["text"]]")
	prison.tick(5)
	TEST_ASSERT(prison.hatch_warning_left > 580 && prison.hatch_warning_left < 600, "The log line did not wait out its 10 minutes")
	prisoner.set_uniform_grime(90)
	prison.tick(5)
	TEST_ASSERT_EQUAL(prison.hatch_warning_text(), "The hatch is out of food and clean uniforms and 1 prisoner is waiting.", "The warning read: [prison.hatch_warning_text()]")
	stock_hatch(east_hatch, 1)
	new /obj/item/clothing/under/rank/prisoner/outpost(prison_spot(home, 13, 6))
	prison.refresh_reach()
	prison.tick(5)
	TEST_ASSERT(!prison.hatch_shortage(), "Food and a suit on the other hatch still read as a shortage")
	// Bolted in, they can't reach a hatch, so they are not waiting at one.
	clear_hatch(east_hatch)
	prisoner.set_hunger(30)
	prisoner.forceMove(prisoner.cell.arrival_turf())
	prison.toggle_cell_bolts(prisoner.cell.number, warden)
	prison.tick(5)
	TEST_ASSERT(!prison.hatch_shortage(), "A prisoner bolted in their cell counted as waiting at the hatch")
	prison.toggle_cell_bolts(prisoner.cell.number, warden)
	prisoner.forceMove(yard_side)
	prison.refresh_reach()

	// Stocking gets a call-out from a prisoner who wants it, and thanks from one waiting at the hatch.
	var/mob/living/basic/outpost_prisoner/waiting = prisoner
	var/mob/living/basic/outpost_prisoner/watcher = test_prisoner(prison, prison_spot(home, 8, 8))
	var/mob/living/basic/outpost_prisoner/full = test_prisoner(prison, prison_spot(home, 7, 8))
	waiting.set_hunger(30)
	waiting.set_uniform_grime(0)
	watcher.set_hunger(30)
	full.set_hunger(100)
	var/datum/prisoner_activity/hatch_wait/wait = waiting.start_activity(new /datum/prisoner_activity/hatch_wait(waiting))
	wait.hatch_ref = WEAKREF(hatch)
	waiting.last_line = null
	COOLDOWN_RESET(waiting, thanks_cooldown)
	COOLDOWN_RESET(prison, hatch_call_cooldown)
	var/obj/item/food/prison_ration/stocked = new(hatch_turf)
	var/mob/living/basic/outpost_prisoner/crier = prison.on_hatch_stocked(hatch, list(stocked), warden)
	TEST_ASSERT_EQUAL(crier, watcher, "The call-out came from [crier || "nobody"], not the hungry prisoner watching")
	TEST_ASSERT(is_line_for(waiting.last_line, "thanks_food"), "The prisoner waiting at the hatch did not say thanks: [waiting.last_line]")
	TEST_ASSERT_EQUAL(waiting.last_carer_ref?.resolve(), warden, "The waiting prisoner did not note who stocked the hatch")
	TEST_ASSERT_NULL(prison.on_hatch_stocked(hatch, list(stocked), warden), "A second call-out came within 20 seconds") // OUTPOST_PRISON_HATCH_CALL_GAP
	// By hand, through the table: the call-out fires (its cooldown starts).
	COOLDOWN_RESET(prison, hatch_call_cooldown)
	var/obj/item/food/prison_ration/by_hand = allocate(__IMPLIED_TYPE__)
	warden.drop_all_held_items()
	warden.put_in_active_hand(by_hand)
	TEST_ASSERT_EQUAL(hatch.table_place_act(warden, by_hand, list()), ITEM_INTERACT_SUCCESS, "Putting a ration on a hatch with room failed")
	TEST_ASSERT(!COOLDOWN_FINISHED(prison, hatch_call_cooldown), "Stocking the hatch by hand drew no call-out")
	// A dirty uniform on the hatch is nothing to call about.
	COOLDOWN_RESET(prison, hatch_call_cooldown)
	var/obj/item/clothing/under/rank/prisoner/outpost/grubby = new(hatch_turf)
	grubby.set_grime(90)
	TEST_ASSERT_NULL(prison.on_hatch_stocked(hatch, list(grubby), warden), "A dirty uniform drew a call-out")
	waiting.end_activity(cancel_ai = FALSE)
	clear_hatch(hatch)

	// The admin fill: every hatch to capacity, mostly meals (OUTPOST_PRISON_FILL_MEAL_SHARE 0.7).
	prison.fill_hatches()
	stock = prison.hatch_stock()
	TEST_ASSERT_EQUAL(hatch.stock_count(), capacity, "The fill left the west hatch at [hatch.stock_count()]")
	TEST_ASSERT_EQUAL(east_hatch.stock_count(), capacity, "The fill left the east hatch at [east_hatch.stock_count()]")
	TEST_ASSERT_EQUAL(stock["meals"], 2 * round(capacity * 0.7, 1), "The fill put out [stock["meals"]] meals")
	TEST_ASSERT_EQUAL(stock["clean_suits"], 2 * (capacity - round(capacity * 0.7, 1)), "The fill put out [stock["clean_suits"]] clean suits")
	TEST_ASSERT_EQUAL(prison.fill_hatches(), 0, "Filling full hatches added more")
	clear_hatch(hatch)
	clear_hatch(east_hatch)
	settle_prison_air(home)

// ===== THE SUSTENANCE VENDOR =====

/datum/unit_test/voidcrew_outpost_prison_vendor
	parent_type = /datum/unit_test/voidcrew_outpost_management

/// Buys one of `record` as `buyer` the way the vendor's window does. Returns what ended up in their hands, dropped and deleted.
/datum/unit_test/voidcrew_outpost_prison_vendor/proc/buy(obj/machinery/vending/sustenance/outpost_prison/vendor, mob/living/carbon/human/buyer, datum/data/vending_product/record)
	buyer.drop_all_held_items()
	world.push_usr(buyer, CALLBACK(vendor, TYPE_PROC_REF(/obj/machinery/vending, vend), list("ref" = REF(record))))
	// is_holding_item_of_type() answers FALSE, not null, when nothing was handed over
	var/obj/item/bought = buyer.is_holding_item_of_type(record.product_path)
	if(!bought)
		return null
	. = bought.type
	qdel(bought)

/datum/unit_test/voidcrew_outpost_prison_vendor/Run()
	var/obj/structure/overmap/dynamic/player_outpost/home = prison_test_claim("vendorowner")
	TEST_ASSERT_NOTNULL(home, "The vendor test prison did not load")
	var/datum/outpost_prison/prison = test_prison(home)
	var/datum/bank_account/treasury = home.treasury
	var/obj/machinery/vending/sustenance/outpost_prison/vendor = locate() in prison_spot(home, 4, 5)
	TEST_ASSERT_NOTNULL(vendor, "The Sustenance Vendor is not where the map puts it")
	TEST_ASSERT(vendor.resistance_flags & INDESTRUCTIBLE, "The prison's vendor is not outpost property") // /datum/element/outpost_property
	TEST_ASSERT(!length(vendor.hidden_records), "The prison's vendor has contraband to hack out")
	vendor.set_machine_stat(vendor.machine_stat & ~NOPOWER)
	// tg's stock at one treasury price (OUTPOST_PRISON_RATION_COST 25) an item.
	var/datum/data/vending_product/tofu
	for(var/datum/data/vending_product/record as anything in vendor.product_records)
		TEST_ASSERT_EQUAL(record.price, 25, "[record.name] costs [record.price], not 25")
		if(record.product_path == /obj/item/food/tofu/prison)
			tofu = record
	TEST_ASSERT_NOTNULL(tofu, "The vendor does not sell soggy tofu")
	var/mob/living/carbon/human/owner = make_player(prison_spot(home, 4, 4), "vendorowner")
	var/mob/living/carbon/human/resident = make_player(prison_spot(home, 5, 4), "vendorresident")
	var/mob/living/carbon/human/visitor = make_player(prison_spot(home, 3, 4), "vendorvisitor")
	home.residents += resident.mind
	treasury.adjust_money(5000, "Prison test")

	// A member buys: the tofu comes out into their hand and the treasury pays for it.
	var/start = treasury.account_balance
	var/stocked = tofu.amount
	TEST_ASSERT_EQUAL(buy(vendor, owner, tofu), /obj/item/food/tofu/prison, "The owner could not buy soggy tofu")
	TEST_ASSERT_EQUAL(start - treasury.account_balance, 25, "Soggy tofu cost the treasury [start - treasury.account_balance]")
	TEST_ASSERT_EQUAL(tofu.amount, stocked - 1, "The vendor's tofu went from [stocked] to [tofu.amount]")
	// Tofu feeds a prisoner like a ration.
	var/obj/item/food/tofu/prison/sample = allocate(__IMPLIED_TYPE__, prison_spot(home, 5, 9))
	TEST_ASSERT_EQUAL(outpost_prisoner_food_tier(sample), "ration", "Soggy tofu does not count as a ration")
	qdel(sample)

	// A visitor is refused, and nothing is billed.
	TEST_ASSERT(!vendor.may_vend(visitor), "A visitor may use the prison's vendor")
	TEST_ASSERT(!vendor.allowed(visitor), "The vendor allows a visitor in")
	TEST_ASSERT(vendor.allowed(owner), "The vendor keeps the owner out")
	TEST_ASSERT_EQUAL(vendor.charge(visitor, tofu), "members only", "A visitor was not told the vendor is for members")
	start = treasury.account_balance
	TEST_ASSERT_NULL(buy(vendor, visitor, tofu), "A visitor bought tofu on the treasury")
	TEST_ASSERT_EQUAL(treasury.account_balance, start, "A visitor's try was billed")

	// Residents take up to 8 items per 10 minutes between them (OUTPOST_PRISON_RESIDENT_ORDERS / _WINDOW);
	// managers are never held to it.
	for(var/i in 1 to 8)
		TEST_ASSERT_EQUAL(buy(vendor, resident, tofu), /obj/item/food/tofu/prison, "A resident could not buy item [i] of 8")
	start = treasury.account_balance
	TEST_ASSERT_EQUAL(vendor.charge(resident, tofu), "order limit reached", "A resident was not held to the limit")
	TEST_ASSERT_NULL(buy(vendor, resident, tofu), "A resident bought a ninth item inside ten minutes")
	TEST_ASSERT_EQUAL(treasury.account_balance, start, "A refused resident was billed")
	TEST_ASSERT_EQUAL(buy(vendor, owner, tofu), /obj/item/food/tofu/prison, "The owner was held to the residents' limit")
	for(var/i in 1 to length(prison.resident_orders))
		prison.resident_orders[i] -= 6000 // OUTPOST_PRISON_RESIDENT_ORDER_WINDOW
	TEST_ASSERT_EQUAL(buy(vendor, resident, tofu), /obj/item/food/tofu/prison, "A resident could not buy once the window had passed")
	TEST_ASSERT_EQUAL(prison.resident_orders_left(), 7, "The window did not start again after it passed")

	// An empty treasury buys nothing.
	treasury.adjust_money(-treasury.account_balance, "Prison test")
	stocked = tofu.amount
	TEST_ASSERT_EQUAL(vendor.charge(owner, tofu), "insufficient funds", "An empty treasury paid for tofu")
	TEST_ASSERT_NULL(buy(vendor, owner, tofu), "Tofu came out of a vendor on an empty treasury")
	TEST_ASSERT_EQUAL(tofu.amount, stocked, "A refused sale took tofu off the shelf")
	treasury.adjust_money(5000, "Prison test")

	// It restocks itself: one item a minute while powered (OUTPOST_PRISON_VENDOR_RESTOCK_TIME), nothing when full or unpowered.
	for(var/datum/data/vending_product/record as anything in vendor.product_records)
		record.amount = record.max_amount
	tofu.amount = tofu.max_amount - 2
	vendor.restock_progress = 0
	vendor.process(30)
	TEST_ASSERT_EQUAL(tofu.amount, tofu.max_amount - 2, "Half a minute restocked the vendor")
	vendor.process(30)
	TEST_ASSERT_EQUAL(tofu.amount, tofu.max_amount - 1, "A minute did not restock one tofu")
	vendor.set_machine_stat(vendor.machine_stat | NOPOWER)
	vendor.process(60)
	TEST_ASSERT_EQUAL(tofu.amount, tofu.max_amount - 1, "An unpowered vendor restocked")
	vendor.set_machine_stat(vendor.machine_stat & ~NOPOWER)
	vendor.process(60)
	TEST_ASSERT_EQUAL(tofu.amount, tofu.max_amount, "The vendor did not restock its last tofu")
	vendor.process(120)
	TEST_ASSERT_EQUAL(tofu.amount, tofu.max_amount, "A full vendor went over its stock")
	TEST_ASSERT_EQUAL(vendor.restock_progress, 0, "A full vendor saved up restocking time")
	settle_prison_air(home)

// ===== THE PRISONERS' SMALL ROUTINES =====

/datum/unit_test/voidcrew_outpost_prison_liveliness
	parent_type = /datum/unit_test/voidcrew_outpost_management

/datum/unit_test/voidcrew_outpost_prison_liveliness/proc/holds(mob/living/basic/outpost_prisoner/prisoner, obj/item/thing)
	return thing.loc == prisoner

/datum/unit_test/voidcrew_outpost_prison_liveliness/Run()
	var/obj/structure/overmap/dynamic/player_outpost/home = prison_test_claim("livelyowner")
	TEST_ASSERT_NOTNULL(home, "The liveliness test prison did not load")
	var/datum/outpost_prison/prison = test_prison(home)
	var/turf/table = prison_spot(home, 5, 9)
	var/turf/seat = prison_spot(home, 5, 10)
	var/mob/living/basic/outpost_prisoner/prisoner = test_prisoner(prison, prison_spot(home, 8, 8))
	// The map's own bin (if any) moves aside for a known one.
	for(var/turf/tile as anything in prison.wing_turfs())
		for(var/obj/structure/closet/crate/bin/map_bin in tile)
			qdel(map_bin)
	var/obj/structure/closet/crate/bin/bin = allocate(/obj/structure/closet/crate/bin, prison_spot(home, 8, 10))
	prison.refresh_reach()
	TEST_ASSERT_EQUAL(prison.find_bin(prisoner), bin, "The prisoner cannot find the yard bin")

	// Binning: at mood 60+ (PRISONER_BIN_MOOD) a wrapper is often meant for the bin (70%,
	// PRISONER_BIN_CHANCE); below it never; below 40 (PRISONER_LITTER_MOOD) it goes on the floor.
	var/meant_for_bin = 0
	var/crumbs = 0
	prisoner.set_mood(80)
	for(var/obj/effect/decal/cleanable/food/crumbs/old_crumb in seat)
		qdel(old_crumb)
	for(var/i in 1 to 40)
		var/obj/item/food/prison_ration/sample = new(null)
		var/obj/item/trash = prisoner.leave_meal_mess(sample, seat, table)
		qdel(sample)
		if(trash)
			meant_for_bin++
			TEST_ASSERT_EQUAL(trash.loc, table, "A wrapper meant for the bin was not left on the table first")
		// Crumbs on one tile merge into one decal, so count them meal by meal.
		var/obj/effect/decal/cleanable/food/crumbs/crumb = locate() in seat
		if(crumb)
			crumbs++
			qdel(crumb)
	TEST_ASSERT(meant_for_bin >= 10 && meant_for_bin <= 36, "A content prisoner meant [meant_for_bin] of 40 wrappers for the bin, not about 24")
	TEST_ASSERT(crumbs >= 5 && crumbs <= 35, "Forty meals at a table left crumbs [crumbs] times, not about 20") // PRISONER_TABLE_CRUMB_CHANCE 50
	prisoner.set_mood(59)
	for(var/i in 1 to 20)
		var/obj/item/food/prison_ration/sample = new(null)
		TEST_ASSERT_NULL(prisoner.leave_meal_mess(sample, seat, table), "A prisoner at mood 59 meant a wrapper for the bin")
		qdel(sample)
	for(var/obj/item/trash/left_out in table)
		qdel(left_out)
	prisoner.set_mood(30)
	var/on_floor = 0
	for(var/i in 1 to 20)
		var/obj/item/food/prison_ration/sample = new(null)
		prisoner.leave_meal_mess(sample, seat, table)
		qdel(sample)
	TEST_ASSERT_NULL(locate(/obj/item/trash) in table, "An unhappy prisoner left a wrapper on the table")
	for(var/obj/item/trash/dropped in seat)
		on_floor++
		qdel(dropped)
	TEST_ASSERT(on_floor >= 5, "An unhappy prisoner dropped [on_floor] of 20 wrappers on the floor")
	for(var/obj/effect/decal/cleanable/food/crumbs/crumb in seat)
		qdel(crumb)
	// A full bin: they say so and leave it.
	bin.storage_capacity = length(bin.contents)
	prisoner.set_mood(80)
	for(var/i in 1 to 20)
		var/obj/item/food/prison_ration/sample = new(null)
		TEST_ASSERT_NULL(prisoner.leave_meal_mess(sample, seat, table), "A prisoner meant a wrapper for a full bin")
		qdel(sample)
	bin.storage_capacity = initial(bin.storage_capacity)
	for(var/obj/item/trash/left_out in table)
		qdel(left_out)
	for(var/obj/effect/decal/cleanable/food/crumbs/crumb in seat)
		qdel(crumb)
	// After a meal: the wrapper carried to the bin and put in. They finish on the stool, within
	// reach of the wrapper on the table; nothing is picked up from further off.
	prisoner.forceMove(seat)
	var/datum/prisoner_activity/eat/meal = prisoner.start_activity(new /datum/prisoner_activity/eat(prisoner))
	var/obj/item/trash/wrapper = new /obj/item/trash/fleet_ration(table)
	TEST_ASSERT_EQUAL(meal.carry_to_bin(wrapper), 2, "The prisoner did not set off for the bin") // ACTIVITY_MOVE
	TEST_ASSERT_EQUAL(prisoner.held_item, wrapper, "The prisoner is not carrying the wrapper")
	TEST_ASSERT(get_dist(meal.spot, bin) <= 1 && prisoner.walkable[meal.spot], "The prisoner is not headed to the bin")
	prisoner.forceMove(meal.spot)
	meal.arrive()
	TEST_ASSERT_EQUAL(wrapper.loc, bin, "The wrapper did not go in the bin")
	TEST_ASSERT_EQUAL(meal.tick(1), 1, "The meal did not end after binning") // ACTIVITY_DONE
	prisoner.end_activity(cancel_ai = FALSE)
	// Unwatched, straight in.
	var/obj/item/trash/raisins/unwatched = new(prisoner.loc)
	TEST_ASSERT(prisoner.bin_litter(unwatched), "An unwatched prisoner could not bin a wrapper")
	TEST_ASSERT_EQUAL(unwatched.loc, bin, "The unwatched wrapper did not go in the bin")

	// Tidying: at mood 75+ (PRISONER_TIDY_MOOD), one piece of litter to the bin, then not again for 5 minutes.
	prisoner.forceMove(prison_spot(home, 8, 8))
	prison.refresh_reach()
	var/obj/item/trash/chips/litter = new(prison_spot(home, 11, 7))
	prisoner.set_mood(74)
	var/datum/prisoner_activity/tidy/tidy = new(prisoner)
	TEST_ASSERT_EQUAL(tidy.get_weight(), 0, "A prisoner at mood 74 felt like tidying")
	prisoner.set_mood(80)
	TEST_ASSERT(tidy.get_weight() > 0, "A prisoner at mood 80 did not feel like tidying")
	TEST_ASSERT(tidy.setup(), "Tidying could not be set up with litter and a bin in the yard")
	TEST_ASSERT_EQUAL(tidy.spot, get_turf(litter), "Tidying did not go for the litter")
	prisoner.start_activity(tidy)
	TEST_ASSERT_EQUAL(drive_activity(prisoner, tidy), 1, "Tidying never finished")
	TEST_ASSERT_EQUAL(litter.loc, bin, "The litter did not end up in the bin")
	TEST_ASSERT_NULL(prisoner.held_item, "The prisoner kept hold of something after tidying")
	var/datum/prisoner_activity/tidy/again = new(prisoner)
	TEST_ASSERT_EQUAL(again.get_weight(), 0, "A prisoner felt like tidying again straight away")
	qdel(again)

	// Shared meals: three at the tables within a minute each cheer up by 3, once (PRISONER_MOOD_SHARED_MEAL).
	var/mob/living/basic/outpost_prisoner/second = test_prisoner(prison, prison_spot(home, 4, 10))
	var/mob/living/basic/outpost_prisoner/third = test_prisoner(prison, prison_spot(home, 6, 10))
	var/mob/living/basic/outpost_prisoner/fourth = test_prisoner(prison, prison_spot(home, 4, 8))
	set_moods(list(prisoner, second, third, fourth), 50)
	TEST_ASSERT_EQUAL(length(prison.note_table_meal(prisoner)), 0, "One prisoner eating alone made a shared meal")
	TEST_ASSERT_EQUAL(length(prison.note_table_meal(second)), 0, "Two prisoners eating made a shared meal")
	var/list/lifted = prison.note_table_meal(third)
	TEST_ASSERT_EQUAL(length(lifted), 3, "Three prisoners at the tables lifted [length(lifted)]")
	for(var/mob/living/basic/outpost_prisoner/diner as anything in list(prisoner, second, third))
		TEST_ASSERT(abs(diner.mood - 53) < 0.01, "A shared meal left [diner] at [diner.mood], not 53")
	lifted = prison.note_table_meal(fourth)
	TEST_ASSERT(length(lifted) == 1 && lifted[1] == fourth, "The fourth at the table did not get the lift alone")
	TEST_ASSERT(abs(prisoner.mood - 53) < 0.01, "A shared meal lifted the same prisoner twice")

	// Sick call: a hurt prisoner goes over to a member of staff holding dressings in the yard, asks,
	// and waits until treated.
	var/mob/living/carbon/human/medic = make_player(prison_spot(home, 12, 8), "livelyowner")
	prisoner.forceMove(prison_spot(home, 8, 8))
	prison.refresh_reach()
	prisoner.adjustBruteLoss(30)
	TEST_ASSERT(!prisoner.start_sick_call(), "A hurt prisoner asked for treatment from someone holding no dressings")
	var/obj/item/stack/medical/bruise_pack/dressing = allocate(__IMPLIED_TYPE__)
	medic.put_in_active_hand(dressing)
	TEST_ASSERT(prisoner.start_sick_call(), "A hurt prisoner did not go to someone holding a bruise pack")
	var/datum/prisoner_activity/sick_call/asking = prisoner.activity
	TEST_ASSERT(istype(asking), "The sick call is not their activity")
	TEST_ASSERT(get_dist(asking.spot, medic) <= 1, "The sick call did not head for the medic")
	prisoner.forceMove(asking.spot)
	asking.arrive()
	TEST_ASSERT_EQUAL(asking.tick(1), 0, "The sick call ended before treatment") // ACTIVITY_CONTINUE
	TEST_ASSERT(asking.asked, "The prisoner did not ask for treatment")
	TEST_ASSERT_EQUAL(prisoner.dir, get_dir(prisoner, medic), "The prisoner is not facing the medic")
	prisoner.adjustBruteLoss(-30)
	TEST_ASSERT_EQUAL(asking.tick(1), 1, "The sick call went on after treatment") // ACTIVITY_DONE
	prisoner.end_activity(cancel_ai = FALSE)
	// Not again straight away, not for a scrape, and not for staff out of the cell block.
	prisoner.adjustBruteLoss(30)
	TEST_ASSERT(!prisoner.start_sick_call(), "A prisoner asked for the medic again straight away")
	COOLDOWN_RESET(prisoner, sick_call_cooldown)
	medic.forceMove(prison_spot(home, 12, 4))
	TEST_ASSERT(!prisoner.start_sick_call(), "A prisoner asked staff in the office for treatment")
	medic.forceMove(prison_spot(home, 12, 8))
	prisoner.adjustBruteLoss(-25)
	TEST_ASSERT(!prisoner.start_sick_call(), "A prisoner at 95% health asked for treatment")
	prisoner.adjustBruteLoss(-prisoner.getBruteLoss())
	medic.drop_all_held_items()

	// Basketball with staff: a member sinking a shot while two play cheers them up by 10, once per
	// 5 minutes (PRISONER_MOOD_STAFF_BASKET, OUTPOST_PRISON_STAFF_BASKET_GAP).
	var/obj/structure/hoop/hoop = locate() in prison_spot(home, 9, 11)
	TEST_ASSERT_NOTNULL(hoop, "The hoop is not where the map puts it")
	set_moods(list(prisoner, second), 50)
	prisoner.start_activity(new /datum/prisoner_activity/basketball(prisoner))
	TEST_ASSERT(!prison.staff_basket(medic, hoop), "A basket with one prisoner playing cheered them")
	second.start_activity(new /datum/prisoner_activity/basketball(second))
	TEST_ASSERT(!prison.staff_basket(third, hoop), "A prisoner's own basket counted as staff's")
	TEST_ASSERT(prison.staff_basket(medic, hoop), "A staff basket with two playing did not count")
	TEST_ASSERT(abs(prisoner.mood - 60) < 0.01 && abs(second.mood - 60) < 0.01, "A staff basket left the players at [prisoner.mood] and [second.mood], not 60")
	TEST_ASSERT(!prison.staff_basket(medic, hoop), "A second staff basket inside 5 minutes counted")
	second.end_activity(cancel_ai = FALSE)
	prisoner.end_activity(cancel_ai = FALSE)
	// A ball thrown to a playing prisoner is caught and the game goes on.
	var/obj/item/toy/basketball/ball = locate() in prison_spot(home, 9, 9)
	TEST_ASSERT_NOTNULL(ball, "The ball is not where the map puts it")
	prisoner.forceMove(prison_spot(home, 9, 8))
	prison.refresh_prisoner_reach(prisoner)
	var/datum/prisoner_activity/basketball/game = prisoner.start_activity(new /datum/prisoner_activity/basketball(prisoner))
	TEST_ASSERT(game.setup(), "Basketball could not be set up for the catch")
	game.arrive()
	medic.forceMove(prison_spot(home, 12, 8))
	medic.put_in_active_hand(ball)
	TEST_ASSERT(game.tick(1) != 1, "The game ended as soon as staff picked up the ball") // ACTIVITY_DONE
	medic.dropItemToGround(ball)
	ball.throw_at(prisoner, 5, 1, medic)
	TEST_ASSERT(wait_until(CALLBACK(src, PROC_REF(holds), prisoner, ball), 5 SECONDS), "The playing prisoner did not catch the ball")
	TEST_ASSERT_EQUAL(prisoner.held_item, ball, "The caught ball is not in the prisoner's hands")
	TEST_ASSERT_EQUAL(prisoner.activity, game, "Catching the ball ended the game")
	prisoner.end_activity(cancel_ai = FALSE)
	TEST_ASSERT(isturf(ball.loc), "The ball stayed with the prisoner after the game")
	settle_prison_air(home)

// ===== NOTHING WARPS INTO THEIR HANDS =====

/**
 * Prisoners only take what is within arm's reach. Food two tiles away can't be reached or taken,
 * and a meal set on it gives up rather than taking it; a hatch two tiles away stays shut. Beside
 * the hatch, they wait for the window door to finish opening, face the counter and hold out a hand
 * for a tick before the food is theirs. With someone on the level and their AI blinking off after a
 * plan that queued nothing, they never help themselves off the hatch without walking over.
 */
/datum/unit_test/voidcrew_outpost_prison_reach
	parent_type = /datum/unit_test/voidcrew_outpost_management

/datum/unit_test/voidcrew_outpost_prison_reach/Run()
	var/obj/structure/overmap/dynamic/player_outpost/home = prison_test_claim("reachowner")
	TEST_ASSERT_NOTNULL(home, "The reach test prison did not load")
	var/datum/outpost_prison/prison = test_prison(home)
	var/turf/hatch_turf = prison_spot(home, 5, 6)
	var/obj/structure/table/reinforced/prison_hatch/hatch = locate() in hatch_turf
	TEST_ASSERT_NOTNULL(hatch, "The serving hatch is not where the map puts it")
	var/obj/machinery/door/window/yard_door = hatch.yard_windoor()
	TEST_ASSERT_NOTNULL(yard_door, "The serving hatch has no yard-side window door")
	var/mob/living/basic/outpost_prisoner/prisoner = test_prisoner(prison, prison_spot(home, 8, 8))
	prison.refresh_reach()

	// Two tiles away on the yard floor: out of reach, not taken, and it stays put.
	var/turf/far_turf = prison_spot(home, 10, 8)
	var/obj/item/food/prison_ration/far = allocate(__IMPLIED_TYPE__, far_turf)
	TEST_ASSERT(prisoner.reachable[far_turf], "The far food is not somewhere the prisoner could walk to")
	TEST_ASSERT_EQUAL(prisoner.try_reach(far), 0, "Food two tiles away was within reach") // PRISONER_REACH_FAILED
	TEST_ASSERT(!prisoner.take_item(far), "The prisoner took food from two tiles away")
	TEST_ASSERT_EQUAL(far.loc, far_turf, "Food two tiles away moved")
	TEST_ASSERT_NULL(prisoner.held_item, "The prisoner holds food they could not reach")
	// A meal already set on it gives up instead of taking it.
	prisoner.set_hunger(30)
	var/datum/prisoner_activity/eat/meal = prisoner.start_activity(new /datum/prisoner_activity/eat(prisoner))
	meal.food_ref = WEAKREF(far)
	meal.started = TRUE
	TEST_ASSERT_EQUAL(meal.tick(1), 1, "A meal two tiles off did not give up") // ACTIVITY_DONE
	prisoner.end_activity(cancel_ai = FALSE)
	TEST_ASSERT_EQUAL(far.loc, far_turf, "A meal two tiles off was taken anyway")
	qdel(far)

	// Two tiles from the hatch: out of reach, and the yard side stays shut.
	var/obj/item/food/prison_ration/hatch_food = allocate(__IMPLIED_TYPE__, hatch_turf)
	prisoner.forceMove(prison_spot(home, 5, 8))
	prison.refresh_prisoner_reach(prisoner)
	TEST_ASSERT_EQUAL(prisoner.try_reach(hatch_food), 0, "The hatch was within reach from two tiles away") // PRISONER_REACH_FAILED
	TEST_ASSERT(!prisoner.take_item(hatch_food), "The prisoner took food off the hatch from two tiles away")
	TEST_ASSERT(yard_door.density && !yard_door.operating, "Reaching from two tiles away opened the hatch")
	TEST_ASSERT_EQUAL(hatch_food.loc, hatch_turf, "Food on the hatch moved while nobody was beside it")

	// Beside it: the door opens all the way first, then a hand goes out, then the food is taken.
	prisoner.forceMove(prison_spot(home, 5, 7))
	prison.refresh_prisoner_reach(prisoner)
	TEST_ASSERT_EQUAL(prisoner.reach_for(hatch_food), 2, "Reaching for the shut hatch did not wait for it to open") // PRISONER_REACH_WAIT
	TEST_ASSERT_EQUAL(prisoner.reach_for(hatch_food), 2, "Food was in reach while the window door was still opening") // PRISONER_REACH_WAIT
	TEST_ASSERT(wait_until(CALLBACK(src, TYPE_PROC_REF(/datum/unit_test/voidcrew_outpost_management, windoor_open), yard_door)), "The yard-side window door never opened")
	TEST_ASSERT_EQUAL(prisoner.reach_for(hatch_food), 2, "The food was taken with no moment reaching for it") // PRISONER_REACH_WAIT
	TEST_ASSERT_EQUAL(prisoner.dir, SOUTH, "The prisoner is not facing the hatch they reach into")
	TEST_ASSERT_EQUAL(prisoner.reach_for(hatch_food), 1, "The food was out of reach after the hand went out") // PRISONER_REACH_OK
	TEST_ASSERT(prisoner.take_item(hatch_food, announce = TRUE), "The prisoner could not take the food beside them")
	TEST_ASSERT_EQUAL(prisoner.held_item, hatch_food, "The food is not in the prisoner's hands")
	qdel(hatch_food)
	TEST_ASSERT_NULL(prisoner.held_item, "The prisoner still holds the deleted food")

	// Someone on the level while tg has their AI switched off after a failed plan: that is not
	// "nobody here", so they don't help themselves off the hatch from across the yard.
	prisoner.forceMove(prison_spot(home, 12, 8))
	prison.refresh_prisoner_reach(prisoner)
	prisoner.set_hunger(30)
	var/obj/item/food/prison_ration/unwatched_food = allocate(__IMPLIED_TYPE__, hatch_turf)
	TEST_ASSERT_NOTEQUAL(prisoner.ai_controller.ai_status, AI_STATUS_ON, "The prisoner's AI runs in a world with no players")
	var/turf/level_turf = get_turf(prisoner)
	var/mob/living/carbon/human/consistent/onlooker = allocate(/mob/living/carbon/human/consistent, prison_spot(home, 8, 3))
	SSmobs.clients_by_zlevel[level_turf.z] += onlooker
	var/counted_running = prisoner.ai_running()
	prison.tick(5)
	var/ate_watched = QDELETED(unwatched_food)
	SSmobs.clients_by_zlevel[level_turf.z] -= onlooker
	TEST_ASSERT(counted_running, "A prisoner whose AI blinked off with someone on the level counted as asleep")
	TEST_ASSERT(!ate_watched, "A prisoner ate food off the hatch from across the yard with someone on the level")
	// With nobody on the level, nobody sees it: they still help themselves.
	TEST_ASSERT(!prisoner.ai_running(), "A prisoner's AI counted as running with nobody on the level")
	prison.tick(5)
	TEST_ASSERT(QDELETED(unwatched_food), "A prisoner left alone on an empty level did not eat off the hatch")
	settle_prison_air(home)

// ===== NOTHING UNTIL THEY ARE ALL THE WAY IN =====

/**
 * A prisoner beaming in knits together inside the column over the beam's 3 seconds
 * (OUTPOST_PRISON_BEAM_TIME), hidden under the transporter's mask from the first frame, and does
 * nothing at all until the knit is over. Until then the routine plans nothing, they say nothing,
 * show no thought bubble and are held still; after it they are solid, free and able to talk.
 * Beaming out, the same holds from the start. Guards and Kessler staff beaming in keep quiet too.
 */
/datum/unit_test/voidcrew_outpost_prison_beam_gates
	parent_type = /datum/unit_test/voidcrew_outpost_management

/datum/unit_test/voidcrew_outpost_prison_beam_gates/proc/knitting(atom/movable/arrival)
	return !!arrival.get_filter("transporter_dissolve")

/datum/unit_test/voidcrew_outpost_prison_beam_gates/proc/all_in(mob/living/basic/outpost_prisoner/prisoner, mob/living/basic/outpost_prison_guard/guard, mob/living/basic/outpost_kessler_staff/doctor)
	return prisoner.phase == "present" && guard.phase == "present" && !doctor.beaming

/// Whether nothing about the prisoner can act, talk or show: the gates an arriving or leaving prisoner must fail
/datum/unit_test/voidcrew_outpost_prison_beam_gates/proc/check_held(mob/living/basic/outpost_prisoner/prisoner, when)
	var/datum/ai_planning_subtree/outpost_prisoner_routine/routine = GLOB.ai_subtrees[/datum/ai_planning_subtree/outpost_prisoner_routine]
	TEST_ASSERT(!prisoner.routine_allowed(), "The routine was allowed [when]")
	TEST_ASSERT_NULL(routine.SelectBehaviors(prisoner.ai_controller, 1), "The routine planned something [when]")
	TEST_ASSERT_NULL(prisoner.activity, "The prisoner started an activity [when]")
	TEST_ASSERT(!prisoner.may_speak(), "The prisoner could speak [when]")
	TEST_ASSERT(!prisoner.say_context("arrival"), "The prisoner said something [when]")
	TEST_ASSERT(HAS_TRAIT(prisoner, TRAIT_IMMOBILIZED), "The prisoner could move [when]")
	TEST_ASSERT_NULL(prisoner.bubble, "A thought bubble was due [when]")
	TEST_ASSERT_NULL(prisoner.popped_bubble, "A thought bubble showed [when]")

/datum/unit_test/voidcrew_outpost_prison_beam_gates/Run()
	var/obj/structure/overmap/dynamic/player_outpost/home = prison_test_claim("beamgateowner")
	TEST_ASSERT_NOTNULL(home, "The beam gate test prison did not load")
	var/datum/outpost_prison/prison = test_prison(home)
	var/mob/living/basic/outpost_prisoner/prisoner = test_prisoner(prison, prison_spot(home, 8, 8))
	var/mob/living/basic/outpost_prisoner/other = test_prisoner(prison, prison_spot(home, 9, 8))
	REMOVE_TRAIT(prisoner, TRAIT_IMMOBILIZED, TRAIT_SOURCE_UNIT_TESTS)
	prison.refresh_reach()
	// Hungry (PRISONER_HUNGER_HUNGRY 40), so a meal and a thought bubble would both be due.
	prisoner.arrival_brute = 0
	prisoner.set_hunger(20)
	prisoner.beam_in()
	var/datum/outpost_guard_record/record = prison.add_guard_record(TRUE, /mob/living/basic/outpost_prison_guard)
	var/mob/living/basic/outpost_prison_guard/guard = record?.guard
	TEST_ASSERT_NOTNULL(guard, "The test guard did not beam in")
	var/mob/living/basic/outpost_kessler_staff/researcher/doctor = allocate(/mob/living/basic/outpost_kessler_staff/researcher, prison_spot(home, 12, 3), null)
	doctor.beam_in()

	// In the beam they are knitting together from the start, under the mask at its lowest
	// (TRANSPORTER_MASK_TRAVEL -58), so nothing of them shows before the beam does: arriving, and held.
	for(var/mob/living/arrival as anything in list(prisoner, guard, doctor))
		TEST_ASSERT(knitting(arrival), "[arrival] was not knitting together inside the beam")
		TEST_ASSERT_EQUAL(arrival.filter_data?["transporter_dissolve"]?["y"], -58, "[arrival]'s knit did not start hidden under the mask")
	TEST_ASSERT_EQUAL(prisoner.phase, "arriving", "Beaming in did not make the prisoner arriving") // PRISONER_ARRIVING
	check_held(prisoner, "in the beam")
	TEST_ASSERT(!other.start_conversation(prisoner), "A prisoner opened a conversation with one still beaming in")
	TEST_ASSERT_EQUAL(guard.phase, "arriving", "The guard skipped the beam") // OUTPOST_GUARD_ARRIVING
	TEST_ASSERT(!guard.say_guard("arrival"), "A guard still beaming in spoke")
	TEST_ASSERT(!guard.on_duty(), "A guard still beaming in was on duty")
	TEST_ASSERT(doctor.beaming, "The researcher skipped the beam")
	TEST_ASSERT_NULL(doctor.say_line("researcher_offer"), "A researcher still beaming in spoke")

	// Most of the way through the knit: still arriving, still held.
	sleep(2 SECONDS)
	TEST_ASSERT(knitting(prisoner), "The prisoner stopped knitting together before the beam was over")
	TEST_ASSERT_EQUAL(prisoner.phase, "arriving", "The prisoner was present before they finished knitting together")
	check_held(prisoner, "while knitting together")
	TEST_ASSERT_EQUAL(guard.phase, "arriving", "The guard was on duty before they finished knitting together")
	TEST_ASSERT(!guard.say_guard("arrival"), "A guard spoke while knitting together")
	TEST_ASSERT(doctor.beaming, "The researcher finished beaming in before the knit was over")
	TEST_ASSERT_NULL(doctor.say_line("researcher_offer"), "A researcher spoke while knitting together")

	// All the way in as the beam ends: solid, free and able to talk.
	TEST_ASSERT(wait_until(CALLBACK(src, PROC_REF(all_in), prisoner, guard, doctor), 3 SECONDS), "The arrivals never finished beaming in")
	TEST_ASSERT_EQUAL(prisoner.alpha, 255, "The prisoner is not solid once in")
	TEST_ASSERT_NULL(prisoner.get_filter("transporter_dissolve"), "The prisoner still wears the knit once in")
	TEST_ASSERT(!HAS_TRAIT(prisoner, TRAIT_IMMOBILIZED), "The prisoner is still held once in")
	TEST_ASSERT(prisoner.routine_allowed(), "The prisoner's routine did not start once in")
	TEST_ASSERT(prisoner.may_speak(), "The prisoner cannot speak once in")
	TEST_ASSERT_EQUAL(prisoner.bubble, "hungry", "The hungry arrival has no thought bubble once in")
	TEST_ASSERT(guard.on_duty(), "The guard is not on duty once in")
	TEST_ASSERT_EQUAL(guard.alpha, 255, "The guard is not solid once in")
	TEST_ASSERT(!HAS_TRAIT(doctor, TRAIT_IMMOBILIZED), "The researcher is still held once in")

	// Beaming out: held, silent and without a bubble from the start.
	prisoner.beam_out()
	TEST_ASSERT_EQUAL(prisoner.phase, "leaving", "Beaming out did not make the prisoner leaving") // PRISONER_LEAVING
	check_held(prisoner, "beaming out")
	TEST_ASSERT(!other.start_conversation(prisoner), "A prisoner opened a conversation with one beaming out")
	guard.beam_out()
	TEST_ASSERT(!guard.say_guard("recalled"), "A guard beaming out spoke")
	doctor.beam_out()
	TEST_ASSERT_NULL(doctor.say_line("researcher_leave"), "A researcher beaming out spoke")
	settle_prison_air(home)
