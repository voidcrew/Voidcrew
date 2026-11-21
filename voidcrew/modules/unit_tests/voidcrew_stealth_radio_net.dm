// Stealth guards: the radio net, the call mark, the name in the alarm and the aware mark (stealth_radio.dm,
// stealth_meter.dm). Unit tests compile before voidcrew/_DEFINES, so values from there are written out:
// FREQ_SCAV_NET 1531, STEALTH_METER_RADIO_STATE "radio", STEALTH_METER_AWARE_STATE "ex_a", STEALTH_METER_RADIO_W 8,
// STEALTH_CALL_ALARM 3, STEALTH_CALL_NAME 4, blackboard key "stealth_wary".

#define STEALTH_TEST_LOOKOUT /mob/living/carbon/human/npc/ruin/trooper/scav/lookout

/// A lookout wears the scavs' earpiece: locked to their frequency, not locked to his body. Any other radio on him
/// doesn't put him on the net.
/datum/unit_test/voidcrew_stealth_radio_earpiece

/datum/unit_test/voidcrew_stealth_radio_earpiece/Run()
	var/mob/living/carbon/human/npc/lookout = allocate(STEALTH_TEST_LOOKOUT, run_loc_floor_bottom_left)
	var/obj/item/radio/headset/guard_net/scav/earpiece = lookout.ears
	TEST_ASSERT(istype(earpiece), "A lookout doesn't wear the scav earpiece")
	TEST_ASSERT_EQUAL(earpiece.get_frequency(), 1531, "The scav earpiece isn't on the scav frequency")
	TEST_ASSERT_EQUAL(earpiece.freqlock, RADIO_FREQENCY_LOCKED, "The scav earpiece can be retuned")
	TEST_ASSERT(!human_npc_gear_locked(earpiece), "The scav earpiece is locked to the guard's body")
	TEST_ASSERT(!HAS_TRAIT(earpiece, TRAIT_NO_STRIP), "The strip menu can't take the scav earpiece")
	TEST_ASSERT_NOTNULL(lookout.stealth_radio_ready(), "A lookout's own earpiece doesn't work")
	// Taken off, he has no radio and gets none back.
	lookout.dropItemToGround(earpiece)
	TEST_ASSERT_NULL(lookout.ears, "The earpiece didn't come off")
	TEST_ASSERT(!QDELETED(earpiece), "The earpiece was deleted when it came off")
	TEST_ASSERT_NULL(lookout.stealth_radio_ready(), "A lookout without his earpiece can still call")
	var/datum/ai_controller/basic_controller/human_npc/stealth/lookout_ai = lookout.ai_controller
	TEST_ASSERT(!lookout_ai.stealth_start_call(3, get_turf(lookout)), "A lookout without his earpiece raised a hand to it")
	// Someone else's headset on him doesn't count.
	var/obj/item/radio/headset/plain = allocate(/obj/item/radio/headset)
	lookout.equip_to_slot_if_possible(plain, ITEM_SLOT_EARS)
	TEST_ASSERT_EQUAL(lookout.ears, plain, "Test fixture: a plain headset didn't go on")
	TEST_ASSERT_NULL(lookout.stealth_radio_ready(), "A plain headset put the lookout back on the net")

/// A radio call goes into the earpiece and is said out loud in full; anything else he says on it is tg's headset mumble.
/datum/unit_test/voidcrew_stealth_radio_aloud

/datum/unit_test/voidcrew_stealth_radio_aloud/Run()
	var/mob/living/carbon/human/npc/lookout = allocate(STEALTH_TEST_LOOKOUT, run_loc_floor_bottom_left)
	var/list/mods = list(MODE_HEADSET = TRUE)
	var/mumbled = lookout.radio("Radio check.", mods.Copy(), list(), /datum/language/common)
	TEST_ASSERT(mumbled & REDUCE_RANGE, "Ordinary headset speech from a guard isn't tg's reduced range")
	lookout.stealth_calling_aloud = TRUE
	var/called = lookout.radio("Trouble!", mods.Copy(), list(), /datum/language/common)
	lookout.stealth_calling_aloud = FALSE
	TEST_ASSERT(!(called & (REDUCE_RANGE | ITALICS)), "A guard's radio call is only heard from the next tile")

/// The name an alarm gives: the face tg shows, else the ID on someone whose face is covered, else none.
/datum/unit_test/voidcrew_stealth_radio_call_name

/datum/unit_test/voidcrew_stealth_radio_call_name/Run()
	var/mob/living/carbon/human/consistent/person = allocate(/mob/living/carbon/human/consistent, run_loc_floor_bottom_left)
	person.fully_replace_character_name(null, "Ivan Petrov")
	TEST_ASSERT_EQUAL(stealth_call_name(person), "Ivan Petrov", "An alarm doesn't name the face it saw")
	var/obj/item/clothing/under/color/grey/suit = allocate(/obj/item/clothing/under/color/grey)
	person.equip_to_slot_if_possible(suit, ITEM_SLOT_ICLOTHING)
	var/obj/item/clothing/mask/balaclava/mask = allocate(/obj/item/clothing/mask/balaclava)
	person.equip_to_slot_if_possible(mask, ITEM_SLOT_MASK)
	TEST_ASSERT_NULL(stealth_call_name(person), "An alarm names a covered face with no ID")
	var/obj/item/card/id/advanced/card = allocate(/obj/item/card/id/advanced)
	card.registered_name = "Oleg Sidorov"
	card.update_label()
	person.equip_to_slot_if_possible(card, ITEM_SLOT_ID)
	TEST_ASSERT_EQUAL(person.wear_id, card, "Test fixture: the ID didn't go on")
	TEST_ASSERT_EQUAL(person.wear_mask, mask, "Test fixture: the balaclava didn't go on")
	TEST_ASSERT_EQUAL(stealth_call_name(person), "Oleg Sidorov", "An alarm doesn't name the ID on a covered face")
	TEST_ASSERT_NULL(stealth_call_name(null), "An alarm names nobody")
	TEST_ASSERT_NULL(stealth_call_name(run_loc_floor_bottom_left), "An alarm names a turf")

/// When the dim amber "!" shows.
/datum/unit_test/voidcrew_stealth_radio_aware_rule

/datum/unit_test/voidcrew_stealth_radio_aware_rule/Run()
	TEST_ASSERT(stealth_meter_aware("unaware", TRUE, FALSE, 0), "A wary guard with nothing over his head has no amber !")
	TEST_ASSERT(stealth_meter_aware("suspicious", TRUE, FALSE, 0), "A wary suspicious guard showing nobody a ? has no amber !")
	TEST_ASSERT(!stealth_meter_aware("unaware", FALSE, FALSE, 0), "A calm guard shows the amber !")
	TEST_ASSERT(!stealth_meter_aware("unaware", TRUE, FALSE, 1), "The amber ! shows on top of someone's ?")
	TEST_ASSERT(!stealth_meter_aware("unaware", TRUE, TRUE, 0), "The amber ! shows on top of a public mark")
	TEST_ASSERT(!stealth_meter_aware("alert", TRUE, FALSE, 0), "An alert guard shows the amber !")
	TEST_ASSERT(!stealth_meter_aware("searching", TRUE, FALSE, 0), "A searching guard shows the amber !")

/// The meter: the amber "!" over a wary guard, the radio beside it while a call is pending, both gone after.
/datum/unit_test/voidcrew_stealth_radio_marks

/datum/unit_test/voidcrew_stealth_radio_marks/Run()
	var/datum/turf_reservation/block = stealth_block(6, 3)
	TEST_ASSERT_NOTNULL(block, "No room for the test")
	var/mob/living/carbon/human/npc/lookout = allocate(STEALTH_TEST_LOOKOUT, stealth_at(block, 2, 1))
	var/datum/ai_controller/basic_controller/human_npc/stealth/lookout_ai = lookout.ai_controller
	var/datum/stealth_meter/meter = rebuild_meter(lookout_ai, lookout)
	TEST_ASSERT_NULL(meter.mark, "A calm guard has a mark")
	TEST_ASSERT_NULL(meter.call_mark, "A guard with no call has a radio over him")
	lookout_ai.stealth_set_wary()
	meter.update()
	TEST_ASSERT_EQUAL(meter.mark?.icon_state, "ex_a", "A wary guard has no amber !")
	// Calling it in: the radio beside the mark, from the raised hand.
	TEST_ASSERT(lookout_ai.stealth_start_call(3, stealth_at(block, 4, 1)), "A lookout couldn't start a call")
	meter = rebuild_meter(lookout_ai, lookout)
	TEST_ASSERT_EQUAL(meter.mark?.icon_state, "ex_a", "The radio took the place of the head mark")
	TEST_ASSERT_NOTNULL(meter.call_mark, "A guard calling it in has no radio over him")
	TEST_ASSERT_EQUAL(meter.call_mark.icon_state, "radio", "The call mark isn't the radio")
	TEST_ASSERT_EQUAL(meter.call_mark.pixel_w, 8, "The radio isn't beside the head mark")
	TEST_ASSERT(meter.call_mark in lookout.vis_contents, "The radio isn't drawn on the guard")
	var/obj/effect/abstract/stealth_mark/call_mark = meter.call_mark
	lookout_ai.stealth_drop_call()
	TEST_ASSERT_NULL(lookout_ai.pending_call, "A dropped call is still pending")
	meter = rebuild_meter(lookout_ai, lookout)
	TEST_ASSERT_NULL(meter.call_mark, "A dropped call left the radio up")
	TEST_ASSERT(QDELETED(call_mark), "A dropped call's radio wasn't deleted")
	// Calm again: the amber ! goes.
	lookout_ai.stealth_clear_wary()
	meter.update()
	TEST_ASSERT_NULL(meter.mark, "A guard that calmed down kept the amber !")
	qdel(block)

/// The meter, built by hand (no client is near in a test, so the AI drops it whenever it looks).
/datum/unit_test/voidcrew_stealth_radio_marks/proc/rebuild_meter(datum/ai_controller/basic_controller/human_npc/stealth/guard_ai, mob/living/guard)
	if(isnull(guard_ai.meter))
		guard_ai.meter = new /datum/stealth_meter(guard_ai, guard)
	guard_ai.meter.update()
	return guard_ai.meter

/// The calls are tg radio speech on the scav frequency: a scav earpiece on the same site hears the alarm, by name.
/datum/unit_test/voidcrew_stealth_radio_speech

/datum/unit_test/voidcrew_stealth_radio_speech/Run()
	var/datum/turf_reservation/block = stealth_block(8, 3)
	TEST_ASSERT_NOTNULL(block, "No room for the test")
	var/mob/living/carbon/human/npc/lookout = allocate(STEALTH_TEST_LOOKOUT, stealth_at(block, 1, 1))
	var/datum/ai_controller/basic_controller/human_npc/stealth/lookout_ai = lookout.ai_controller
	// Worn by someone: tg headsets only listen while on a mob (possibly_deactivate_in_loc()), so one on the floor hears nothing.
	var/mob/living/carbon/human/consistent/thief = allocate(/mob/living/carbon/human/consistent, stealth_at(block, 6, 1))
	var/obj/item/radio/headset/guard_net/scav/stolen = allocate(/obj/item/radio/headset/guard_net/scav)
	thief.equip_to_slot_if_possible(stolen, ITEM_SLOT_EARS)
	TEST_ASSERT_EQUAL(thief.ears, stolen, "Test fixture: the stolen earpiece didn't go on")
	TEST_ASSERT(stolen.get_listening(), "Test fixture: a worn scav earpiece isn't listening")
	var/list/heard = list()
	RegisterSignal(stolen, COMSIG_RADIO_RECEIVE_MESSAGE, PROC_REF(on_heard))
	heard_into = heard
	lookout_ai.stealth_start_call(3, stealth_at(block, 4, 1), "Ivan Petrov")
	lookout_ai.pending_call[3] = world.time
	lookout_ai.stealth_deliver_call()
	UnregisterSignal(stolen, COMSIG_RADIO_RECEIVE_MESSAGE)
	heard_into = null
	TEST_ASSERT(length(heard), "A scav earpiece on the same site didn't hear the alarm")
	TEST_ASSERT(findtext(heard[1], "Ivan Petrov"), "The alarm didn't name who the lookout saw (heard: [heard[1]])")
	qdel(block)

/datum/unit_test/voidcrew_stealth_radio_speech
	/// Where on_heard() writes what the earpiece received
	var/list/heard_into

/datum/unit_test/voidcrew_stealth_radio_speech/proc/on_heard(datum/source, list/data)
	SIGNAL_HANDLER
	if(heard_into)
		heard_into += "[data["message"]]"

#undef STEALTH_TEST_LOOKOUT
