/**
 * Outpost police tests: police_life.dm (voidcrew/modules/outpost_police/). Owner: P3.
 * Helpers are in voidcrew_outpost_police_helpers.dm. Fork defines are included after the tests: use
 * literal values with a comment naming the define.
 *
 * The test room is the ambient tests' (ambient_test_outpost(), pa_tile(), pa_place(), pa_trader(), pa_npc()
 * in voidcrew_ambient_core.dm and voidcrew_ambient_outposts.dm): a 5 by 5 concourse whose hangar lift is its top
 * right corner. Its outposts have no police station until a test gives them a desk and a lift tile.
 */

/// An officer of `officer_type` at `where` in `outpost`'s place, on its roster and awake (nobody is on the concourse, so it starts held still)
/datum/unit_test/proc/police_awake_officer(obj/structure/overmap/trader_outpost/outpost, officer_type, turf/where)
	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/officer = police_officer(outpost, officer_type, where)
	officer.resume_routine()
	return officer

/// A headset on `officer`'s ears, which their radio lines go through: an officer's own (their kit locks it on), or a new one
/datum/unit_test/proc/police_headset_on(mob/living/carbon/human/officer)
	if(istype(officer.ears, /obj/item/radio/headset))
		return officer.ears
	var/obj/item/radio/headset/headset = allocate(/obj/item/radio/headset)
	TEST_ASSERT(officer.equip_to_slot_if_possible(headset, ITEM_SLOT_EARS), "A headset would not go on [officer]")
	return headset

// =========================================================================
// THE FILE
// =========================================================================

/// Every line kind has lines in every zone's voice; none can be taken for a radio key; only the radio calls carry tokens
/datum/unit_test/voidcrew_outpost_police_lines

/datum/unit_test/voidcrew_outpost_police_lines/Run()
	var/list/line_kinds = list(
		"warn", "order", "chase", "stun", "shots", "all_units", "marshal", "lost", "cuff", "walk", "make_way", "book",
		"release", "medic", "officer_down", "clear", "knock", "cell_alarm", "move_along", "radio_call", "radio_ack",
		"search", "evidence", "strip", "bail", "locker_thief", // POLICE_LINE_*
		"idle", "talk", "chat", "reply", "work", // AMBIENT_LINE_*
		"radio_call_hot", "check_in", "check_in_reply", "beat", "trader_reply", "guard", "guard_reply", "cell_check", "cell_reply", "talk_prior", // P3's own
		"stealth_suspicious", "stealth_give_up", "stealth_search", "stealth_hit_unseen", "stealth_body", "stealth_chatter",
		"stealth_target_downed", "stealth_closet_open", "stealth_closet_give_up", "stealth_heard", "stealth_heard_again",
		"stealth_gunfire", "stealth_hold", "stealth_help", "stealth_missing", "stealth_radio_report", "stealth_radio_alarm",
		"stealth_radio_missing", "stealth_copy", "stealth_radio_dead", // stealth's barks (police_stealth.dm)
	)
	// Kinds whose lines may carry a token: the desk's calls (%PLACE%, %LOOK%) and stealth's calls (%PLACE%, %NAME%)
	var/list/token_kinds = list("radio_call", "radio_call_hot", "stealth_missing", "stealth_radio_report", "stealth_radio_alarm", "stealth_radio_missing")
	for(var/section in list("halcyon", "quartermain", "undertow"))
		for(var/kind in line_kinds)
			var/list/lines = ambient_dialogue_lines("outpost_police.json", section, kind) // AMBIENT_STRINGS_POLICE
			TEST_ASSERT(length(lines) >= 3, "[section] has [length(lines)] lines for [kind], not 3 or more")
			var/plain = 0
			for(var/line in lines)
				TEST_ASSERT(istext(line) && length(line), "[section] has an empty line for [kind]")
				// A leading . : ; # or * would be read as a radio or channel key
				TEST_ASSERT(!(copytext(line, 1, 2) in list(".", ":", ";", "#", "*", "%")), "[section] [kind]: '[line]' starts like a radio key")
				TEST_ASSERT(!findtext(line, "<") && !findtext(line, "{"), "[section] [kind]: '[line]' carries markup")
				if(findtext(line, "%"))
					TEST_ASSERT(kind in token_kinds, "[section] [kind]: '[line]' has a token outside the radio calls")
				else
					plain++
			TEST_ASSERT(plain >= 3, "[section] has fewer than 3 plain lines for [kind]")
		var/list/entry = ambient_dialogue_section("outpost_police.json", section)
		TEST_ASSERT(length(entry["conversations"]) >= 3, "[section] has fewer than 3 conversations")

/// Tokens fill from clean values; a line that needs a token the caller lacks is never picked
/datum/unit_test/voidcrew_outpost_police_tokens

/datum/unit_test/voidcrew_outpost_police_tokens/Run()
	var/list/values = outpost_police_values(list("look" = "grey jumpsuit", "%PLACE%" = "\improper The Chowder Pot", "bad" = list(1)))
	TEST_ASSERT_EQUAL(values["look"], "grey jumpsuit", "A look value was changed")
	TEST_ASSERT_EQUAL(values["place"], "The Chowder Pot", "A place value kept its markup or its percent signs")
	TEST_ASSERT_EQUAL(length(values), 2, "A value that is not text was kept")
	TEST_ASSERT_EQUAL(outpost_police_pick_line(list("%LOOK% by %PLACE%"), values), "grey jumpsuit by The Chowder Pot", "Tokens were not filled")
	TEST_ASSERT_NULL(outpost_police_pick_line(list("%LOOK% by %PLACE%"), list("look" = "grey jumpsuit")), "A line was picked that needs a place nobody gave")
	TEST_ASSERT_EQUAL(outpost_police_pick_line(list("%LOOK% by %PLACE%", "Quiet."), list()), "Quiet.", "A plain line was not picked when tokens were lacking")
	var/list/dirty = outpost_police_values(list("look" = "<b>loud</b> 100% jumpsuit and a very very very very long description of it"))
	TEST_ASSERT(!findtext(dirty["look"], "<") && !findtext(dirty["look"], ">") && !findtext(dirty["look"], "%"), "Markup or a percent sign survived in a value")
	TEST_ASSERT(length(dirty["look"]) <= 40, "A value was not bounded") // 40 characters

	// What a suspect wears is named by the type, never the item's own (renamed) name
	var/mob/living/carbon/human/suspect = allocate(/mob/living/carbon/human/consistent)
	var/obj/item/clothing/under/color/grey/jumpsuit = allocate(/obj/item/clothing/under/color/grey)
	jumpsuit.name = "Mr. Rude's best jumpsuit"
	TEST_ASSERT(suspect.equip_to_slot_if_possible(jumpsuit, ITEM_SLOT_ICLOTHING), "A jumpsuit would not go on")
	var/obj/item/clothing/under/color/grey/jumpsuit_type = /obj/item/clothing/under/color/grey
	TEST_ASSERT_EQUAL(outpost_police_look(suspect), initial(jumpsuit_type.name), "A suspect was described by a renamed item")

	// An officer's fall makes orders a level harder, in voice
	TEST_ASSERT_EQUAL(outpost_police_harder("knock"), "warn", "Knock is not one level below warn") // POLICE_LINE_KNOCK, _WARN
	TEST_ASSERT_EQUAL(outpost_police_harder("stun"), "shots", "Stun is not one level below shots") // POLICE_LINE_STUN, _SHOTS
	TEST_ASSERT_EQUAL(outpost_police_harder("cuff"), "cuff", "A line with no harder form changed") // POLICE_LINE_CUFF

// =========================================================================
// SPEECH AND THE RADIO
// =========================================================================

/// An officer speaks a line of the zone's voice; nobody says a line of one kind together or the same words twice; a fall makes orders harder
/datum/unit_test/voidcrew_outpost_police_say

/datum/unit_test/voidcrew_outpost_police_say/Run()
	var/obj/structure/overmap/trader_outpost/outpost = ambient_test_outpost()
	var/datum/outpost_police/police = outpost.police
	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/beat/first = police_awake_officer(outpost, /mob/living/carbon/human/npc/ambient_npc/outpost/police/beat, pa_tile(0, 0))
	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/beat/second = police_awake_officer(outpost, /mob/living/carbon/human/npc/ambient_npc/outpost/police/beat, pa_tile(2, 0))
	TEST_ASSERT_EQUAL(first.life_voice_section(), "halcyon", "An officer of the base profile has no voice section")

	var/said = first.police_say("knock") // POLICE_LINE_KNOCK
	TEST_ASSERT(istext(said) && (said in first.get_lines("knock")), "An officer said '[said]', not a line of kind knock")
	TEST_ASSERT_NULL(second.police_say("knock"), "Two officers said a line of one kind together") // POLICE_LINE_KNOCK
	TEST_ASSERT(istext(second.police_say("cuff")), "A different kind of line was refused") // POLICE_LINE_CUFF

	// The zone's voice: the Undertow's officers speak the Undertow's lines
	police.profile.voice_section = "undertow"
	TEST_ASSERT(("Quiet. I hate quiet." in first.get_lines("idle")), "An Undertow officer does not speak the Undertow's voice")
	police.profile.voice_section = "halcyon"

	// A paused officer, a dead one and one who cannot speak say nothing
	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/beat/held = police_officer(outpost, /mob/living/carbon/human/npc/ambient_npc/outpost/police/beat, pa_tile(0, 2))
	TEST_ASSERT(held.paused_at, "An officer at an empty outpost is not held still")
	TEST_ASSERT_NULL(held.police_say("search"), "A held officer spoke") // POLICE_LINE_SEARCH

	// After a fall, orders run a level harder: knock is said as warn
	var/datum/outpost_police_voice/voice = police.life_voice()
	voice.context_free_at.Cut()
	voice.text_free_at.Cut()
	voice.harder_until = world.time + 1 MINUTES
	var/harder = second.police_say("knock") // POLICE_LINE_KNOCK
	TEST_ASSERT(istext(harder) && (harder in second.get_lines("warn")), "After an officer fell, knock was not said as warn")
	TEST_ASSERT_NULL(first.police_say("knock"), "A line of the harder kind was said twice together") // POLICE_LINE_KNOCK -> _WARN

/// A radio line goes out on the police frequency and the other officer's headset hears it
/datum/unit_test/voidcrew_outpost_police_radio
	/// Messages the listener's headset heard
	var/heard = 0

/datum/unit_test/voidcrew_outpost_police_radio/proc/on_radio(datum/source, list/data)
	SIGNAL_HANDLER
	heard++

/datum/unit_test/voidcrew_outpost_police_radio/Run()
	var/obj/structure/overmap/trader_outpost/outpost = ambient_test_outpost()
	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/speaker = police_awake_officer(outpost, /mob/living/carbon/human/npc/ambient_npc/outpost/police/sergeant, pa_tile(0, 0))
	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/listener = police_awake_officer(outpost, /mob/living/carbon/human/npc/ambient_npc/outpost/police/beat, pa_tile(3, 0))
	var/obj/item/radio/headset/speaker_set = police_headset_on(speaker)
	var/obj/item/radio/headset/listener_set = police_headset_on(listener)
	RegisterSignal(listener_set, COMSIG_RADIO_RECEIVE_MESSAGE, PROC_REF(on_radio))

	var/said = speaker.police_say("radio_ack", null, TRUE) // POLICE_LINE_RADIO_ACK
	TEST_ASSERT(istext(said), "The sergeant said nothing on the radio")
	TEST_ASSERT_EQUAL(speaker_set.frequency, 1473, "The speaker's headset was not tuned to the police frequency") // OUTPOST_POLICE_RADIO_FREQ
	TEST_ASSERT_EQUAL(listener_set.frequency, 1473, "The listener's headset was not tuned to the police frequency") // OUTPOST_POLICE_RADIO_FREQ
	sleep(2 SECONDS)
	TEST_ASSERT(heard > 0, "A radio call was not heard at the other officer's headset")

	// Not on the radio: nothing goes out
	var/before = heard
	speaker.police_say("walk") // POLICE_LINE_WALK
	sleep(2 SECONDS)
	TEST_ASSERT_EQUAL(heard, before, "A spoken line went out on the radio")

	// The desk: say_dispatch is the sergeant's voice
	outpost.police.life_voice().context_free_at.Cut()
	outpost.police.life_voice().text_free_at.Cut()
	TEST_ASSERT(istext(outpost.police.say_dispatch("check_in")), "The desk could not call the radio")
	TEST_ASSERT_EQUAL(outpost.police.life_dispatcher(), speaker, "The sergeant is not the one on the radio")

/// A change of level is called by the desk, an officer falls and is called down, the outpost goes quiet and reports clear
/datum/unit_test/voidcrew_outpost_police_dispatch_chatter

/datum/unit_test/voidcrew_outpost_police_dispatch_chatter/Run()
	var/obj/structure/overmap/trader_outpost/outpost = ambient_test_outpost()
	var/datum/outpost_police/police = outpost.police
	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/sergeant/desk = police_awake_officer(outpost, /mob/living/carbon/human/npc/ambient_npc/outpost/police/sergeant, pa_tile(0, 0))
	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/beat/beat = police_awake_officer(outpost, /mob/living/carbon/human/npc/ambient_npc/outpost/police/beat, pa_tile(2, 0))
	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/beat/watcher = police_awake_officer(outpost, /mob/living/carbon/human/npc/ambient_npc/outpost/police/beat, pa_tile(3, 2))
	var/datum/outpost_police_voice/voice = police.life_voice()

	// The level rises: the desk calls it
	police.life_call_level(1, 0)
	TEST_ASSERT(voice.context_free_at["radio_call"] > world.time, "The desk did not call a level rising") // POLICE_LINE_RADIO_CALL
	voice.context_free_at.Cut()
	police.life_call_level(3, 1)
	TEST_ASSERT(voice.context_free_at["radio_call_hot"] > world.time, "The desk did not call a hot level") // radio_call_hot
	TEST_ASSERT(voice.context_free_at["shots"] > world.time, "Nobody called shots fired when the level reached three") // POLICE_LINE_SHOTS

	// An officer falls: someone nearby calls it, and orders run harder for a while
	voice.context_free_at.Cut()
	voice.text_free_at.Cut()
	beat.death()
	TEST_ASSERT(voice.harder_until > world.time, "An officer's fall did not make orders harder")
	TEST_ASSERT(voice.context_free_at["officer_down"] > world.time, "Nobody called an officer down") // POLICE_LINE_OFFICER_DOWN
	TEST_ASSERT_EQUAL(length(voice.called_down), 1, "An officer down was not remembered")
	police.life_call_officer_down(beat)
	TEST_ASSERT_EQUAL(length(voice.called_down), 1, "The same officer was called down twice")

	// The all clear: one of the others reports it, and the desk answers
	voice.context_free_at.Cut()
	voice.text_free_at.Cut()
	police.life_call_clear()
	TEST_ASSERT(voice.context_free_at["clear"] > world.time, "Nobody reported clear") // POLICE_LINE_CLEAR
	TEST_ASSERT(desk.stat == CONSCIOUS && watcher.stat == CONSCIOUS, "The test has no officers left to report")

	// The tick with nothing going on says nothing and does not runtime
	voice.context_free_at.Cut()
	police.tick_life()
	TEST_ASSERT_EQUAL(length(voice.context_free_at), 0, "A tick with no level change spoke")

/// Talking to an officer gets an answer from their voice; the sergeant answers a prisoner
/datum/unit_test/voidcrew_outpost_police_talk

/datum/unit_test/voidcrew_outpost_police_talk/Run()
	var/obj/structure/overmap/trader_outpost/outpost = ambient_test_outpost()
	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/beat/officer = police_awake_officer(outpost, /mob/living/carbon/human/npc/ambient_npc/outpost/police/beat, pa_tile(1, 1))
	var/mob/living/carbon/human/visitor = allocate(/mob/living/carbon/human/consistent, pa_tile(1, 2))
	officer.next_line_at = 0
	officer.talked_to(visitor)
	TEST_ASSERT(officer.next_line_at > 0, "An officer did not answer someone who talked to them")
	// Someone with a record gets the other answer
	TEST_ASSERT(length(officer.get_lines("talk_prior")) >= 3, "An officer has no answers for someone with a record")

// =========================================================================
// ROLES AND THE CAP
// =========================================================================

/// Officers apply only where the map has a police station, are counted apart from the crowd and are settled at their posts even when the concourse is full
/datum/unit_test/voidcrew_outpost_police_roles

/datum/unit_test/voidcrew_outpost_police_roles/Run()
	var/obj/structure/overmap/trader_outpost/outpost = ambient_test_outpost()
	var/datum/outpost_police/police = outpost.police
	var/datum/ambient_place/outpost/place = pa_place(outpost)
	var/datum/ambient_outpost_role/police_beat/beat_role = allocate(/datum/ambient_outpost_role/police_beat)
	var/datum/ambient_outpost_role/police_sergeant/desk_role = allocate(/datum/ambient_outpost_role/police_sergeant)

	// No station, no officers: the ambient roles test sums only roles that apply
	TEST_ASSERT(!beat_role.applies_to(outpost), "The beat applies to an outpost with no police station")
	TEST_ASSERT(!desk_role.applies_to(outpost), "The desk applies to an outpost with no police station")
	TEST_ASSERT_EQUAL(beat_role.wanted(place), 0, "The beat wants officers at an outpost with no police station")
	TEST_ASSERT(ispath(beat_role.npc_type, /mob/living/carbon/human/npc/ambient_npc/outpost/police/beat), "The beat brings the wrong officer")
	TEST_ASSERT(ispath(desk_role.npc_type, /mob/living/carbon/human/npc/ambient_npc/outpost/police/sergeant), "The desk brings the wrong officer")

	// A station: a desk and a lift
	var/turf/desk = pa_tile(1, 1)
	var/turf/lift = pa_tile(0, 4)
	police.desk_turf = desk
	police.lift_turfs = list(lift)
	police.profile.beat_count = 3
	TEST_ASSERT(beat_role.applies_to(outpost) && desk_role.applies_to(outpost), "The roles do not apply to an outpost with a police station")
	TEST_ASSERT_EQUAL(beat_role.wanted(place), 3, "The beat is not short of the profile's three")
	TEST_ASSERT_EQUAL(desk_role.wanted(place), 1, "The desk is not short of its one")

	// A full concourse: eight of the crowd, and the officers are still settled and the crowd's count stays eight
	var/list/crowd = list()
	for(var/i in 0 to 7)
		crowd += pa_npc(/mob/living/carbon/human/npc/ambient_npc/core_test, pa_tile(i % 5, i < 5 ? 0 : 3), place)
	TEST_ASSERT_EQUAL(length(place.living_npcs()), 8, "The crowd is not eight") // AMBIENT_OUTPOST_TRANSIENT_CAP
	var/made = SSambient_npcs.settle_outpost(place, null, 10)
	TEST_ASSERT_EQUAL(made, 4, "[made] officers were settled, not the desk and three of the beat")
	TEST_ASSERT_EQUAL(length(police.officers), 4, "The roster has [length(police.officers)] officers, not four")
	TEST_ASSERT_EQUAL(length(place.living_npcs()), 8, "Officers were counted in the crowd")
	TEST_ASSERT_EQUAL(length(place.npcs), 12, "The place does not hold the crowd and the officers")
	TEST_ASSERT_EQUAL(police.life_standing("sergeant"), 1, "The desk is not manned") // POLICE_UNIT_SERGEANT
	TEST_ASSERT_EQUAL(police.life_standing("beat"), 3, "The beat is not out") // POLICE_UNIT_BEAT
	TEST_ASSERT_EQUAL(beat_role.wanted(place), 0, "The beat is still short once it is out")
	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/sergeant/sergeant = locate() in police.officers
	TEST_ASSERT_NOTNULL(sergeant, "No sergeant was made")
	TEST_ASSERT_EQUAL(get_turf(sergeant), desk, "The sergeant was not found on the desk tile")
	TEST_ASSERT(istype(sergeant.activity, /datum/ambient_activity/police_desk), "The sergeant is not at the desk")
	TEST_ASSERT_EQUAL(sergeant.role, /datum/ambient_outpost_role/police_sergeant, "The sergeant does not know their role")
	for(var/mob/living/carbon/human/npc/ambient_npc/outpost/police/beat/patrol in police.officers)
		TEST_ASSERT(patrol.place == place, "A beat officer is not in the place")
		TEST_ASSERT_EQUAL(patrol.role, /datum/ambient_outpost_role/police_beat, "A beat officer does not know their role")
	// Settling again makes nobody more
	place.needs_settling = TRUE
	TEST_ASSERT_EQUAL(SSambient_npcs.settle_outpost(place, null, 10), 0, "Officers were made when none were short")

	// Roles handed over by a test are not touched by the wrapper
	TEST_ASSERT_EQUAL(SSambient_npcs.settle_outpost(place, list(allocate(/datum/ambient_outpost_role/core_test)), 10), 0, "A pass with its own roles made someone")

	// A replacement steps off a police lift, never the public one; with the lift blocked nobody comes
	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/beat/gone = locate() in police.officers
	qdel(gone)
	TEST_ASSERT_EQUAL(beat_role.wanted(place), 1, "The beat is not short of the one who left")
	var/mob/living/carbon/human/blocker = allocate(/mob/living/carbon/human/consistent, lift)
	TEST_ASSERT_NULL(beat_role.arrive(place, pa_tile(4, 4)), "A replacement came off the public lift while a police lift was blocked")
	qdel(blocker)
	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/beat/replacement = beat_role.arrive(place, pa_tile(4, 4))
	TEST_ASSERT_NOTNULL(replacement, "A replacement did not come off the police lift (on the lift: [english_list(lift.contents)], blocked [lift.is_blocked_turf(exclude_mobs = FALSE)])")
	TEST_ASSERT_EQUAL(get_turf(replacement), lift, "A replacement did not step off the police lift")
	TEST_ASSERT(replacement in police.officers, "A replacement is not on the roster")
	qdel(replacement)

/// The stop activities: coffee is a real mug carried on, the desk sits with a clipboard, a sleeper is looked in on
/datum/unit_test/voidcrew_outpost_police_routines

/datum/unit_test/voidcrew_outpost_police_routines/Run()
	var/obj/structure/overmap/trader_outpost/outpost = ambient_test_outpost()
	var/datum/outpost_police/police = outpost.police
	var/datum/ambient_place/outpost/place = pa_place(outpost)
	police.desk_turf = pa_tile(1, 1)
	pa_trader(outpost, pa_tile(2, 4), pa_tile(2, 3), /datum/outpost_shop/vendor/bait_shop)

	// The beat itself is a stealth route (voidcrew_outpost_police_stealth.dm); here, what is done at its stops
	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/beat/patrol = police_awake_officer(outpost, /mob/living/carbon/human/npc/ambient_npc/outpost/police/beat, pa_tile(0, 0))

	// Coffee: a real mug of real coffee, carried on by one who takes it along, put away by the next thing they do
	var/obj/machinery/vending/coffee/machine = allocate(/obj/machinery/vending/coffee, pa_tile(3, 1))
	TEST_ASSERT_EQUAL(patrol.life_coffee_machine(), machine, "An officer did not find the coffee machine")
	var/datum/ambient_activity/police_coffee/coffee = patrol.start_activity(new /datum/ambient_activity/police_coffee(patrol, machine))
	TEST_ASSERT_NOTNULL(coffee, "An officer could not go for a coffee")
	TEST_ASSERT(get_dist(coffee.spot, machine) <= 1, "An officer's coffee spot is not beside the machine")
	coffee.carry_on = TRUE
	patrol.forceMove(coffee.spot)
	patrol.activity_step(1)
	var/obj/item/reagent_containers/cup/glass/drinkingglass/mug = patrol.held_item
	TEST_ASSERT(istype(mug) && mug.reagents.has_reagent(/datum/reagent/consumable/coffee), "An officer at the coffee machine holds no coffee")
	patrol.end_activity()
	TEST_ASSERT(!QDELETED(mug) && patrol.held_item == mug, "An officer who took their coffee along put it down at once")
	patrol.start_activity(new /datum/ambient_activity/idle(patrol))
	patrol.end_activity()
	TEST_ASSERT(isnull(patrol.held_item) && QDELETED(mug), "The mug was not put away by the next thing they did")

	// The desk: sits on the chair, a clipboard in hand
	allocate(/obj/structure/chair, police.desk_turf)
	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/sergeant/sergeant = police_awake_officer(outpost, /mob/living/carbon/human/npc/ambient_npc/outpost/police/sergeant, pa_tile(3, 0))
	var/datum/ambient_activity/police_desk/at_desk = sergeant.start_activity(new /datum/ambient_activity/police_desk(sergeant))
	TEST_ASSERT_NOTNULL(at_desk, "The sergeant could not take the desk")
	TEST_ASSERT_EQUAL(at_desk.spot, police.desk_turf, "The desk activity is not at the desk tile")
	sergeant.forceMove(police.desk_turf)
	sergeant.activity_step(1)
	TEST_ASSERT_NOTNULL(sergeant.buckled, "The sergeant did not sit")
	TEST_ASSERT(istype(sergeant.held_prop, /obj/item/clipboard), "The sergeant holds no clipboard")
	sergeant.end_activity()
	TEST_ASSERT_NULL(sergeant.held_prop, "The sergeant kept the clipboard after leaving the desk")

	// A sleeper is looked in on: words only
	// Clear of the bait shop's counter: nobody without business there stands within its reach (ambient_outpost_tile_avoided())
	var/mob/living/carbon/human/sleeper = allocate(/mob/living/carbon/human/consistent, pa_tile(0, 0))
	sleeper.Sleeping(5 MINUTES)
	var/datum/ambient_activity/police_check/check = patrol.start_activity(new /datum/ambient_activity/police_check(patrol))
	TEST_ASSERT_NOTNULL(check, "An officer did not notice someone asleep (sleeper seen: [patrol.life_sleeper_near() || "nobody"], asleep [sleeper.IsSleeping()], stat [sleeper.stat], [get_dist(patrol, sleeper)] tiles, line [can_see(patrol, sleeper, 8)], doing [patrol.activity?.type || "nothing"], beside: [police_spot_report(patrol, sleeper)])")
	TEST_ASSERT_EQUAL(check.target_ref.resolve(), sleeper, "An officer is checking on the wrong person")
	var/health_before = sleeper.health
	patrol.forceMove(check.spot)
	patrol.activity_step(1)
	TEST_ASSERT(sleeper.IsSleeping() && sleeper.health == health_before, "Checking on a sleeper did something to them")
	patrol.end_activity()
	TEST_ASSERT_NULL(patrol.start_activity(new /datum/ambient_activity/police_check(patrol)), "An officer nagged the same sleeper again at once")
	TEST_ASSERT_NOTNULL(place, "The place went missing")
