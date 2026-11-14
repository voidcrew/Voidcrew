/**
 * Inmate work, social/pastime gates, tips and the lockup board (outpost_prison_work.dm, outpost_prison_social.dm,
 * outpost_prison_warden_tools.dm, outpost_prison_pastimes.dm, outpost_prison_contraband.dm, outpost_prison_leads.dm,
 * outpost_prison_host.dm).
 *
 * Voidcrew defines are included after the unit tests, so literal values appear with a comment naming the define.
 */

/// Open, clean yard floor tile in `prison` outside any cell
/datum/unit_test/voidcrew_outpost_management/proc/work_test_clean_yard_tile(datum/outpost_prison/prison)
	for(var/turf/tile as anything in prison.cell_block)
		if(!prison.cell_at(tile) && isopenturf(tile) && !tile.is_blocked_turf() && !(locate(/obj/effect/decal/cleanable) in tile))
			return tile
	return null

// =========================================================================
// 1. INMATE WORK JOBS, ABUSE BLOCKS (4 & 5), CAP, AND GUARD REMARK
// =========================================================================

/datum/unit_test/voidcrew_trade_prison_work_jobs
	parent_type = /datum/unit_test/voidcrew_outpost_management

/datum/unit_test/voidcrew_trade_prison_work_jobs/Run()
	var/obj/structure/overmap/trader_outpost/outpost = lockup_test_outpost()
	TEST_ASSERT_NOTNULL(outpost, "Quartermain Depot's interior did not load")
	var/datum/outpost_prison/prison = outpost.prison
	var/datum/outpost_police/police = outpost.police
	TEST_ASSERT_NOTNULL(prison, "Quartermain Depot has no lockup")
	TEST_ASSERT_NOTNULL(police, "Quartermain Depot has no police")

	var/turf/yard_tile = work_test_clean_yard_tile(prison)
	TEST_ASSERT_NOTNULL(yard_tile, "No open clean yard floor tile found in the lockup")
	var/turf/other_yard_tile
	for(var/turf/tile as anything in prison.cell_block)
		if(tile != yard_tile && !prison.cell_at(tile) && isopenturf(tile) && !tile.is_blocked_turf() && !(locate(/obj/effect/decal/cleanable) in tile))
			other_yard_tile = tile
			break
	TEST_ASSERT_NOTNULL(other_yard_tile, "No second open clean yard floor tile found in the lockup")

	var/mob/living/carbon/human/inmate = make_player(yard_tile, "lockupworker1")
	var/datum/outpost_warrant/warrant = police_pin_warrant(police, inmate.mind, 55) // 3 stars -> 600 s (OUTPOST_POLICE_JAIL[3])
	var/datum/prison_sentence/sentence = prison.admit_inmate_sentence(inmate, warrant, 3)
	TEST_ASSERT_EQUAL(sentence.total_seconds, 600, "Setup: three-star sentence is [sentence.total_seconds] s, not 600 s")

	var/mob/living/carbon/human/npc/outpost_prison_guard/guard = guard_test_spawn(prison, yard_tile)
	TEST_ASSERT_NOTNULL(guard, "No lockup guard spawned for the work remark and contraband hand-in tests")
	TEST_ASSERT(COOLDOWN_FINISHED(prison, work_say_cooldown), "work_say_cooldown was already running before any work")

	// 1. Mopping: unmarked player-made decal credits 0 s (abuse 4); wing-marked mess credits 10 s once and triggers guard remark cooldown
	var/obj/item/soap/soap = allocate(/obj/item/soap)
	var/datum/component/cleaner/cleaner = soap.GetComponent(/datum/component/cleaner)
	cleaner.base_cleaning_duration = 0

	var/obj/effect/decal/cleanable/dirt/unmarked_dirt = new(yard_tile)
	TEST_ASSERT(!prison.is_wing_mess(unmarked_dirt), "A decal spawned outside the wing's mess code counted as wing mess")
	cleaner.clean(soap, yard_tile, inmate)
	TEST_ASSERT(QDELETED(unmarked_dirt), "Cleaner did not remove the unmarked dirt decal")
	TEST_ASSERT_EQUAL(sentence.effective_worked_off(), 0, "Cleaning unmarked mess credited [sentence.effective_worked_off()] s instead of 0 s") // abuse 4

	var/obj/effect/decal/cleanable/dirt/marked_dirt = prison.spawn_wing_mess(/obj/effect/decal/cleanable/dirt, yard_tile)
	TEST_ASSERT_NOTNULL(marked_dirt, "spawn_wing_mess() did not create a dirt decal")
	TEST_ASSERT(prison.is_wing_mess(marked_dirt), "spawn_wing_mess() did not mark its decal")
	cleaner.clean(soap, yard_tile, inmate)
	TEST_ASSERT(QDELETED(marked_dirt), "Cleaner did not remove the wing-marked dirt decal")
	TEST_ASSERT_EQUAL(sentence.effective_worked_off(), 10, "Cleaning wing-marked mess credited [sentence.effective_worked_off()] s, not 10 s") // OUTPOST_PRISON_WORK_MOP_SECONDS
	TEST_ASSERT(!COOLDOWN_FINISHED(prison, work_say_cooldown), "An on-duty guard in sight did not start work_say_cooldown on inmate work")

	// 2. Washing: a clean uniform credits 0 s; washing two dirty prison-issue uniforms together credits 30 s once for the load
	var/obj/machinery/washing_machine/washer
	for(var/turf/tile as anything in prison.wing_turfs())
		washer = locate(/obj/machinery/washing_machine) in tile
		if(washer)
			break
	TEST_ASSERT_NOTNULL(washer, "Quartermain Depot's lockup yard has no washing machine")
	var/obj/item/clothing/under/rank/prisoner/outpost/clean_suit = allocate(/obj/item/clothing/under/rank/prisoner/outpost, washer)
	washer.wash_cycle(inmate)
	TEST_ASSERT_EQUAL(sentence.effective_worked_off(), 10, "Washing an already-clean uniform added work credit ([sentence.effective_worked_off()] s)")
	qdel(clean_suit)

	var/obj/item/clothing/under/rank/prisoner/outpost/dirty_one = allocate(/obj/item/clothing/under/rank/prisoner/outpost, washer)
	var/obj/item/clothing/under/rank/prisoner/outpost/dirty_two = allocate(/obj/item/clothing/under/rank/prisoner/outpost, washer)
	dirty_one.set_grime(60)
	dirty_two.set_grime(60)
	washer.wash_cycle(inmate)
	TEST_ASSERT_EQUAL(dirty_one.grime, 0, "Washing machine cycle did not clear grime on the first uniform")
	TEST_ASSERT_EQUAL(dirty_two.grime, 0, "Washing machine cycle did not clear grime on the second uniform")
	TEST_ASSERT_EQUAL(sentence.effective_worked_off(), 40, "Washing a load of dirty uniforms left worked_off at [sentence.effective_worked_off()] s, not 40 s") // +30 s (OUTPOST_PRISON_WORK_WASH_SECONDS)

	// 3. Mail delivery: handing a prisoner their wing letter credits 20 s once and records mail_delivered care
	var/mob/living/carbon/human/npc/outpost_prisoner/recipient = trouble_prisoner(prison, yard_tile)
	var/obj/item/paper/outpost_prison_letter/letter = prison.mail_make_letter(recipient, "good", null, yard_tile)
	var/obj/item/envelope = outpost_prison_letter_holder(letter)
	inmate.put_in_active_hand(envelope)
	TEST_ASSERT_EQUAL(prison.mail_hand_over(recipient, inmate, envelope, letter), ITEM_INTERACT_SUCCESS, "Handing a prisoner their letter did not succeed")
	TEST_ASSERT_EQUAL(sentence.effective_worked_off(), 60, "Delivering a wing letter left worked_off at [sentence.effective_worked_off()] s, not 60 s") // +20 s (OUTPOST_PRISON_WORK_LETTER_SECONDS)
	qdel(envelope)
	recipient.talking = FALSE

	// 4. Dressing or closing prisoner wounds: stocked gauze wraps a cut (+30 s once); stocked suture closes a second cut (+30 s once)
	var/datum/wound/slash/flesh/moderate/chest_cut = new
	chest_cut.apply_wound(recipient.get_bodypart(BODY_ZONE_CHEST), silent = TRUE)
	var/obj/item/stack/medical/gauze/outpost_prison/gauze = allocate(/obj/item/stack/medical/gauze/outpost_prison)
	gauze.other_delay = 0
	gauze.try_heal(recipient, inmate, BODY_ZONE_CHEST, TRUE, FALSE)
	TEST_ASSERT_NOTNULL(recipient.get_bodypart(BODY_ZONE_CHEST).current_gauze, "Stocked gauze did not wrap the prisoner's chest wound")
	TEST_ASSERT_EQUAL(sentence.effective_worked_off(), 90, "Bandaging a prisoner's cut left worked_off at [sentence.effective_worked_off()] s, not 90 s") // +30 s (OUTPOST_PRISON_WORK_WOUND_SECONDS)

	var/datum/wound/slash/flesh/moderate/arm_cut = new
	arm_cut.apply_wound(recipient.get_bodypart(BODY_ZONE_R_ARM), silent = TRUE)
	var/obj/item/stack/medical/suture/outpost_prison/suture = allocate(/obj/item/stack/medical/suture/outpost_prison)
	suture.stop_bleeding = 10
	TEST_ASSERT(suture.heal_carbon(recipient, inmate, BODY_ZONE_R_ARM), "Stocked sutures did not treat the prisoner's arm cut")
	TEST_ASSERT(QDELETED(arm_cut), "Suturing did not close the prisoner's moderate slash wound")
	TEST_ASSERT_EQUAL(sentence.effective_worked_off(), 120, "Suturing a prisoner's cut left worked_off at [sentence.effective_worked_off()] s, not 120 s") // +30 s (OUTPOST_PRISON_WORK_WOUND_SECONDS)

	// 5. Contraband hand-in: unmarked blade is confiscated for 0 s (abuse 5); wing-marked blade from mail credits 60 s once and 0 s if repeated
	inmate.set_combat_mode(FALSE)
	var/obj/item/outpost_prison_contraband/razor_blade/spawned_blade = allocate(/obj/item/outpost_prison_contraband/razor_blade)
	TEST_ASSERT(!prison.is_wing_contraband(spawned_blade), "A test-spawned razor blade counted as wing contraband")
	inmate.put_in_active_hand(spawned_blade)
	click_wrapper(inmate, guard)
	TEST_ASSERT_NULL(spawned_blade.loc, "Guard did not confiscate the unmarked razor blade out of play")
	TEST_ASSERT_EQUAL(sentence.effective_worked_off(), 120, "Handing in a test-spawned blade credited time off ([sentence.effective_worked_off()] s)") // abuse 5

	var/mob/living/carbon/human/npc/outpost_prisoner/smuggler = trouble_prisoner(prison, other_yard_tile)
	var/obj/item/paper/outpost_prison_letter/smuggled_letter = prison.mail_make_letter(smuggler, "contraband", /obj/item/outpost_prison_contraband/razor_blade, other_yard_tile)
	var/obj/item/mail/envelope/outpost_prison/smuggled_env = outpost_prison_letter_holder(smuggled_letter)
	var/obj/item/outpost_prison_contraband/razor_blade/mail_blade = locate() in smuggled_env
	TEST_ASSERT_NOTNULL(mail_blade, "Contraband mail envelope held no razor blade")
	TEST_ASSERT(prison.is_wing_contraband(mail_blade), "Contraband enclosed by mail_make_letter() was not marked as wing contraband")
	inmate.put_in_active_hand(mail_blade)
	click_wrapper(inmate, guard)
	TEST_ASSERT_NULL(mail_blade.loc, "Guard did not confiscate the wing-marked blade")
	TEST_ASSERT_EQUAL(sentence.effective_worked_off(), 180, "Handing in wing contraband left worked_off at [sentence.effective_worked_off()] s, not 180 s") // +60 s (OUTPOST_PRISON_WORK_CONTRABAND_SECONDS)
	TEST_ASSERT(prison.hand_in_contraband(inmate, mail_blade, guard), "Direct repeat hand_in_contraband() call failed")
	TEST_ASSERT_EQUAL(sentence.effective_worked_off(), 180, "Handing the same blade in a second time credited time off again ([sentence.effective_worked_off()] s)") // abuse 5
	qdel(smuggled_env)

	// 6. One-third sentence cap: a 600 s sentence caps worked_off at 200 s (round(total_seconds / 3))
	var/obj/item/knife/shiv/stashed_shiv = allocate(/obj/item/knife/shiv)
	prison.mark_wing_contraband(stashed_shiv)
	inmate.put_in_active_hand(stashed_shiv)
	click_wrapper(inmate, guard)
	TEST_ASSERT_EQUAL(sentence.effective_worked_off(), 200, "Second contraband hand-in did not cap worked_off at 200 s ([sentence.effective_worked_off()] s)")
	TEST_ASSERT_EQUAL(sentence.remaining_seconds(), 400, "Remaining sentence after 200 s worked off is [sentence.remaining_seconds()] s, not 400 s")

	var/obj/effect/decal/cleanable/dirt/over_cap_dirt = prison.spawn_wing_mess(/obj/effect/decal/cleanable/dirt, other_yard_tile)
	cleaner.clean(soap, other_yard_tile, inmate)
	TEST_ASSERT(QDELETED(over_cap_dirt), "Cleaner did not remove the post-cap dirt decal")
	TEST_ASSERT_EQUAL(sentence.effective_worked_off(), 200, "Work past the one-third cap pushed worked_off to [sentence.effective_worked_off()] s")

// =========================================================================
// 2. SOCIAL, PASTIMES, CELL STASH GATES, TIPS (ABUSE 3), AND LOCKUP BOARD
// =========================================================================

/datum/unit_test/voidcrew_trade_prison_work_social_leads_and_board
	parent_type = /datum/unit_test/voidcrew_outpost_management

/datum/unit_test/voidcrew_trade_prison_work_social_leads_and_board/Run()
	var/obj/structure/overmap/trader_outpost/outpost = lockup_test_outpost()
	TEST_ASSERT_NOTNULL(outpost, "Quartermain Depot's interior did not load")
	var/datum/outpost_prison/prison = outpost.prison
	var/datum/outpost_police/police = outpost.police

	var/turf/yard_tile = work_test_clean_yard_tile(prison)
	TEST_ASSERT_NOTNULL(yard_tile, "No open clean yard floor tile found")

	var/mob/living/carbon/human/inmate = make_player(yard_tile, "lockupsocialinmate")
	var/datum/outpost_warrant/warrant = police_pin_warrant(police, inmate.mind, 55) // 3 stars -> 600 s
	var/datum/prison_sentence/sentence = prison.admit_inmate_sentence(inmate, warrant, 3)

	var/mob/living/carbon/human/visitor = make_player(yard_tile, "lockupsocialvisitor")
	var/mob/living/carbon/human/npc/outpost_prisoner/prisoner = trouble_prisoner(prison, yard_tile)
	prisoner.set_mood(80)

	// Talk menu & social reputation: held inmates are yard peers (chat + tip, never staff orders/patdown); non-inmate visitors are refused
	TEST_ASSERT(!prison.is_staff(inmate) && prison.is_inmate(inmate), "Held player inmate had wrong staff/inmate flags")
	TEST_ASSERT(!prison.is_staff(visitor) && !prison.is_inmate(visitor), "Unbooked player visitor had wrong staff/inmate flags")
	TEST_ASSERT(prisoner.talk_menu_allowed(inmate), "Prisoner refused the talk menu to a held inmate")
	TEST_ASSERT(!prisoner.talk_menu_allowed(visitor), "Prisoner opened the talk menu for a non-inmate visitor")

	var/list/choices = prisoner.talk_menu_choices(inmate)
	TEST_ASSERT(("How are you doing?" in choices) && ("What are you in for?" in choices) && ("Heard anything?" in choices), "Inmate's talk menu lacked prisoner chat or tip choices")
	TEST_ASSERT(!("Back to your cell" in choices) && !("Uncuff" in choices) && !("Search" in choices), "Inmate's talk menu exposed staff-only cell, uncuff or pat-down choices")

	TEST_ASSERT(!prison.note_staff_care(visitor, prisoner), "Yard reputation recorded care from a non-inmate visitor")
	TEST_ASSERT(prison.note_staff_care(inmate, prisoner), "Yard reputation refused care from a held inmate")

	// Cell stash searches refuse non-inmate visitors
	var/datum/outpost_prison_cell/cell = prison.cells[1]
	var/obj/structure/bed/cell_bed = cell.bed()
	TEST_ASSERT_NOTNULL(cell_bed, "Cell 1 has no bed")
	TEST_ASSERT_EQUAL(SEND_SIGNAL(cell_bed, COMSIG_ATOM_ATTACK_HAND, visitor, list(RIGHT_CLICK = TRUE)), COMPONENT_CANCEL_ATTACK_CHAIN, "Cell bed did not intercept a visitor's search click")
	TEST_ASSERT_NULL(prison.contraband_search_mattress(visitor, cell_bed), "contraband_search_mattress() ran for a non-inmate visitor")

	// Pastimes: both cards and dice deal in seated inmates and ignore seated visitors
	var/obj/structure/table/mess_table
	var/list/table_turfs
	var/list/obj/structure/chair/stools
	for(var/obj/structure/table/candidate in prison.fixtures_of("table"))
		if(isturf(candidate.loc) && prison.is_mess_table(candidate.loc))
			var/list/group = prison.mess_table_group(candidate.loc)
			var/list/found_stools = prison.stools_at(group)
			if(length(found_stools))
				mess_table = candidate
				table_turfs = group
				stools = found_stools
				break
	TEST_ASSERT_NOTNULL(mess_table, "Quartermain Depot's lockup yard has no mess table with stools")
	var/obj/structure/chair/stool = stools[1]

	var/datum/prisoner_activity/cards/cards_game = new(prisoner)
	cards_game.table_turfs = table_turfs
	var/datum/prisoner_activity/dice/dice_game = new(prisoner)
	dice_game.table_turfs = table_turfs
	TEST_ASSERT(cards_game.deals_in_members && dice_game.deals_in_members, "Cards or dice does not deal in seated inmates")

	visitor.forceMove(stool.loc)
	TEST_ASSERT(stool.buckle_mob(visitor, force = TRUE), "Could not seat visitor on mess-table stool")
	TEST_ASSERT_EQUAL(length(cards_game.seated_members()), 0, "Cards included a non-inmate visitor at the table")
	TEST_ASSERT_EQUAL(length(dice_game.seated_members()), 0, "Dice included a non-inmate visitor at the table")
	stool.unbuckle_mob(visitor, force = TRUE)

	inmate.forceMove(stool.loc)
	TEST_ASSERT(stool.buckle_mob(inmate, force = TRUE), "Could not seat inmate on mess-table stool")
	TEST_ASSERT_EQUAL(length(cards_game.seated_members()), 1, "Cards did not deal in a seated held inmate")
	TEST_ASSERT_EQUAL(length(dice_game.seated_members()), 1, "Dice did not deal in a seated held inmate")
	stool.unbuckle_mob(inmate, force = TRUE)
	inmate.forceMove(yard_tile)
	qdel(cards_game)
	qdel(dice_game)

	// Tips (abuse 3): visitors refused; shipless inmate gets a folded note; one tip per sentence; 40-min wing gap across inmates; ship inmate gets Rumors waypoint
	TEST_ASSERT(istype(outpost_lead_overmap_turf(30, 30), /turf/open/overmap), "Test world has no overmap for leads")
	leads_test_field()
	prisoner.carries_lead = TRUE
	prison.lead_ready_at = 0

	TEST_ASSERT(!prison.lead_can_ask(prisoner, visitor), "lead_can_ask() allowed a non-inmate visitor")
	TEST_ASSERT_EQUAL(prison.give_lead(prisoner, null, visitor), "invalid", "give_lead() gave a tip to a shipless visitor")
	TEST_ASSERT(prison.lead_can_ask(prisoner, inmate), "lead_can_ask() refused a held inmate")

	TEST_ASSERT_EQUAL(prison.give_lead(prisoner, null, inmate), "truth", "Shipless inmate did not receive a true tip from a content carrier")
	TEST_ASSERT(sentence.tip_given, "Receiving a tip did not mark sentence.tip_given")
	var/obj/item/paper/note = locate(/obj/item/paper) in inmate.held_items
	TEST_ASSERT_NOTNULL(note, "Shipless inmate was not handed a folded paper note with the tip")
	inmate.dropItemToGround(note)
	qdel(note)

	var/mob/living/carbon/human/second_inmate = make_player(yard_tile, "lockupsocialinmate2")
	var/datum/outpost_warrant/second_warrant = police_pin_warrant(police, second_inmate.mind, 55)
	var/datum/prison_sentence/second_sentence = prison.admit_inmate_sentence(second_inmate, second_warrant, 3)
	var/mob/living/carbon/human/npc/outpost_prisoner/second_carrier = trouble_prisoner(prison, yard_tile)
	second_carrier.set_mood(80)
	second_carrier.carries_lead = TRUE

	// Wing's 40-minute gap blocks another inmate right after the first tip
	TEST_ASSERT(prison.lead_ready_at > world.time, "Giving a tip did not start the wing's 40-minute lead gap")
	TEST_ASSERT_EQUAL(prison.give_lead(second_carrier, null, second_inmate), "none", "Second inmate bypassed the wing's 40-minute lead gap")

	// Even with the wing gap cleared, the first inmate cannot get a second tip on the same sentence
	prison.lead_ready_at = 0
	TEST_ASSERT_EQUAL(prison.give_lead(second_carrier, null, inmate), "none", "First inmate received a second tip on the same sentence")

	// Second inmate with a ship gets a Rumors waypoint once the wing gap is ready
	var/obj/structure/overmap/ship/ship = leads_test_ship(10, 10)
	TEST_ASSERT_EQUAL(prison.give_lead(second_carrier, ship, second_inmate), "truth", "Second inmate with a ship did not get a tip once the wing gap cleared")
	TEST_ASSERT(second_sentence.tip_given, "Second inmate's sentence did not record tip_given")
	var/datum/outpost_prison_lead/ship_lead = leads_newest(prison)
	var/datum/ship_waypoint/waypoint = ship_lead ? ship.get_waypoint(ship_lead.waypoint_key) : null
	TEST_ASSERT_NOTNULL(waypoint, "Ship-owning inmate's tip did not place a waypoint on their ship")
	TEST_ASSERT_EQUAL(waypoint.category, "Rumors", "Ship-owning inmate's tip waypoint is not in Rumors")

	// Lockup board: shows M:SS of soonest release, tells an active inmate their own remaining time on examine(), and blanks when empty
	TEST_ASSERT(length(prison.boards) >= 2, "Quartermain Depot's lockup registered [length(prison.boards)] boards, fewer than 2")
	var/obj/machinery/status_display/outpost_berth/lockup/board = prison.boards[1]
	sentence.seconds_served = 535 // 65 s left -> 1:05
	second_sentence.seconds_served = 300 // 300 s left -> 5:00
	prison.update_lockup_boards()
	TEST_ASSERT_EQUAL(board.message1, "1:05", "Lockup board showed '[board.message1]' instead of soonest release '1:05'")

	var/inmate_exam = jointext(board.examine(inmate), "\n")
	var/second_exam = jointext(board.examine(second_inmate), "\n")
	var/visitor_exam = jointext(board.examine(visitor), "\n")
	TEST_ASSERT(findtext(inmate_exam, "Your name is on the board. 1:05."), "Board examine for first inmate lacked their own time: [inmate_exam]")
	TEST_ASSERT(findtext(second_exam, "Your name is on the board. 5:00."), "Board examine for second inmate lacked their own time: [second_exam]")
	TEST_ASSERT(!findtext(visitor_exam, "Your name is on the board."), "Board examine told a non-inmate visitor their name was on the board")

	prison.release_inmate(inmate.mind, TRUE)
	prison.release_inmate(second_inmate.mind, TRUE)
	TEST_ASSERT_EQUAL(board.message1, "", "Lockup board stayed '[board.message1]' instead of blank after all inmates were released")

// =========================================================================
// 3. YARD LIFE FOR INMATES & BYSTANDERS: MAPPED MESS, HATCH, MEDIC, WINDOWS
// =========================================================================

/datum/unit_test/voidcrew_trade_prison_work_yard_life
	parent_type = /datum/unit_test/voidcrew_outpost_management

/datum/unit_test/voidcrew_trade_prison_work_yard_life/Run()
	var/obj/structure/overmap/trader_outpost/outpost = lockup_test_outpost()
	TEST_ASSERT_NOTNULL(outpost, "Quartermain Depot's interior did not load")
	var/datum/outpost_prison/prison = outpost.prison
	var/datum/outpost_police/police = outpost.police
	TEST_ASSERT_NOTNULL(prison, "Quartermain Depot has no lockup")
	TEST_ASSERT_NOTNULL(police, "Quartermain Depot has no police")

	var/turf/yard_tile = work_test_clean_yard_tile(prison)
	TEST_ASSERT_NOTNULL(yard_tile, "No open clean yard floor tile found")

	// Pre-mapped yard dirt decals start marked by work_setup() and credit 10 s when cleaned by an inmate
	var/list/obj/effect/decal/cleanable/dirt/mapped_dirts = list()
	for(var/turf/tile as anything in prison.cell_block)
		if(!isopenturf(tile))
			continue
		for(var/obj/effect/decal/cleanable/dirt/decal in tile)
			mapped_dirts += decal
	TEST_ASSERT(length(mapped_dirts) >= 4, "Quartermain Depot's lockup had [length(mapped_dirts)] mapped yard dirt decals, fewer than 4")
	for(var/obj/effect/decal/cleanable/dirt/decal as anything in mapped_dirts)
		TEST_ASSERT(prison.is_wing_mess(decal), "Pre-mapped yard dirt decal was not marked by work_setup()")

	var/mob/living/carbon/human/inmate = make_player(yard_tile, "lockupyardlifeinmate")
	var/datum/outpost_warrant/warrant = police_pin_warrant(police, inmate.mind, 55) // 3 stars -> 600 s
	var/datum/prison_sentence/sentence = prison.admit_inmate_sentence(inmate, warrant, 3)
	var/mob/living/carbon/human/visitor = make_player(yard_tile, "lockupyardlifevisitor")

	var/obj/item/soap/soap = allocate(/obj/item/soap)
	var/datum/component/cleaner/cleaner = soap.GetComponent(/datum/component/cleaner)
	cleaner.base_cleaning_duration = 0
	var/obj/effect/decal/cleanable/dirt/first_mapped = mapped_dirts[1]
	cleaner.clean(soap, get_turf(first_mapped), inmate)
	TEST_ASSERT(QDELETED(first_mapped), "Cleaner did not remove the pre-mapped yard dirt decal")
	TEST_ASSERT_EQUAL(sentence.effective_worked_off(), 10, "Cleaning pre-mapped yard dirt credited [sentence.effective_worked_off()] s, not 10 s") // OUTPOST_PRISON_WORK_MOP_SECONDS

	// Serving hatch stocking accepts held inmates (reputation + prisoner call-out) and ignores non-inmate visitors
	var/list/hatches = prison.fixtures_of("hatch")
	TEST_ASSERT(length(hatches) >= 1, "Quartermain Depot's lockup registered no serving hatches")
	var/obj/structure/table/reinforced/prison_hatch/hatch = hatches[1]
	var/turf/hatch_spot = hatch.yard_side_turf()
	TEST_ASSERT_NOTNULL(hatch_spot, "Serving hatch had no yard-side floor tile")
	var/mob/living/carbon/human/npc/outpost_prisoner/prisoner = trouble_prisoner(prison, hatch_spot)
	prisoner.set_uniform_grime(60) // >= 40 (PRISONER_GRIME_DIRTY)
	prison.refresh_prisoner_reach(prisoner)

	var/obj/item/clothing/under/rank/prisoner/outpost/stocked_suit = allocate(/obj/item/clothing/under/rank/prisoner/outpost, get_turf(hatch))
	TEST_ASSERT_NULL(prison.on_hatch_stocked(hatch, list(stocked_suit), visitor), "on_hatch_stocked() accepted a non-inmate visitor")
	TEST_ASSERT_NULL(prison.rep_record_for(visitor), "on_hatch_stocked() created a yard reputation record for a visitor")

	var/mob/living/carbon/human/npc/outpost_prisoner/crier = prison.on_hatch_stocked(hatch, list(stocked_suit), inmate)
	TEST_ASSERT_EQUAL(crier, prisoner, "on_hatch_stocked() did not let a dirty prisoner call out a suit stocked by an inmate")
	var/datum/prison_staff_record/inmate_rep = prison.rep_record_for(inmate)
	TEST_ASSERT_NOTNULL(inmate_rep, "on_hatch_stocked() did not record yard reputation for a held inmate")
	TEST_ASSERT(!isnull(inmate_rep.stocked_at) && inmate_rep.score > 0, "on_hatch_stocked() did not apply PRISON_REP_STOCK to the inmate's record")
	qdel(stocked_suit)

	// Hurt prisoners recognize a held inmate with medical dressings as a medic, never an unbooked visitor
	prisoner.forceMove(yard_tile)
	prison.refresh_prisoner_reach(prisoner)
	prisoner.adjustBruteLoss(35) // health 65/100 < 0.85 (PRISONER_INJURED_BELOW)
	var/obj/item/stack/medical/gauze/outpost_prison/visitor_gauze = allocate(/obj/item/stack/medical/gauze/outpost_prison)
	var/obj/item/stack/medical/gauze/outpost_prison/inmate_gauze = allocate(/obj/item/stack/medical/gauze/outpost_prison)
	visitor.put_in_active_hand(visitor_gauze)
	inmate.put_in_active_hand(inmate_gauze)
	TEST_ASSERT(!prisoner.is_medic(visitor), "is_medic() accepted an unbooked visitor holding dressings")
	TEST_ASSERT(prisoner.is_medic(inmate), "is_medic() refused a held inmate holding dressings in the cell block")
	var/datum/prisoner_activity/sick_call/sick = new(prisoner)
	TEST_ASSERT(sick.setup(), "sick_call/setup() did not approach a held inmate holding dressings")
	TEST_ASSERT_EQUAL(sick.medic_ref?.resolve(), inmate, "sick_call targeted [sick.medic_ref?.resolve()] instead of the held inmate")
	qdel(sick)
	visitor.drop_all_held_items()
	inmate.drop_all_held_items()

	// Gallery and front-room opsglass register as window fixtures so prisoners walk up and face viewers outside
	var/list/windows = prison.fixtures_of("window")
	TEST_ASSERT(length(windows) >= 17, "Quartermain Depot's lockup registered [length(windows)] window fixtures, fewer than 17 opsglass tiles")
	var/datum/prisoner_activity/window/gaze = new(prisoner)
	TEST_ASSERT(gaze.setup(), "window/setup() failed on Quartermain Depot's lockup")
	var/atom/gaze_window = gaze.window_ref?.resolve()
	TEST_ASSERT(istype(gaze_window, /turf/closed/indestructible/opsglass), "window/setup() picked [gaze_window?.type] instead of lockup opsglass")
	TEST_ASSERT_NOTNULL(gaze.spot, "window/setup() set no standing spot beside the glass")
	prisoner.forceMove(gaze.spot)
	TEST_ASSERT(gaze.arrive(), "window/arrive() failed at the glass spot")
	TEST_ASSERT_EQUAL(prisoner.dir, get_dir(prisoner, gaze_window), "window/begin() left prisoner facing [prisoner.dir] instead of [get_dir(prisoner, gaze_window)]")
	qdel(gaze)

	prison.release_inmate(inmate.mind, TRUE)
