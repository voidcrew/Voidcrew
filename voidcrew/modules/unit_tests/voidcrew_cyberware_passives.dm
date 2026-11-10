/**
 * # Street passives (voidcrew/modules/cyberware/ware_street_passives.dm)
 *
 * Clotter node, Adrenal pump, Medic's palms, Cuffer's wrists, Subvocal mic and
 * Muffler ear: their slots, their effects while online, the failing-gated
 * passive layer taking them away on an EMP and handing them back on a tune-up,
 * the pump's wait surviving a refit, and the two speech hooks behind the mic.
 * Unit-test files compile before voidcrew/_DEFINES/, so the Subvocal trait is
 * written as its literal "cyber_subvocal" and the slots as theirs.
 */

/// A plain pair of earpieces: a worn item in the ears slot whose radio branch
/// needs no working radio behind it.
/obj/item/clothing/ears/voidcrew_test_subvocal_ears
	name = "test earpiece"

/// Shape: every piece sits in the slot the plan gives it, has an item state of
/// its own, carries no button, and the slot sharing is what the plan says.
/datum/unit_test/voidcrew_cyberware_passives_shape

/datum/unit_test/voidcrew_cyberware_passives_shape/Run()
	var/list/passives = list(
		/obj/item/organ/cyberimp/cyberware/clotter_node,
		/obj/item/organ/cyberimp/cyberware/adrenal_pump,
		/obj/item/organ/cyberimp/cyberware/medic_palms,
		/obj/item/organ/cyberimp/cyberware/cuffer_wrists,
		/obj/item/organ/cyberimp/cyberware/subvocal_mic,
		/obj/item/organ/cyberimp/cyberware/muffler_ear,
	)
	for(var/passive_path in passives)
		var/obj/item/organ/cyberimp/cyberware/ware = allocate(passive_path)
		TEST_ASSERT(ware.icon_state, "[passive_path] has no item state")
		TEST_ASSERT(ware.chrome_load > 0, "[passive_path] costs no neural load")
		TEST_ASSERT(!length(ware.actions), "[passive_path] grew an action button. These are passive")

	var/obj/item/organ/cyberimp/cyberware/clotter_node/clotter = allocate(/obj/item/organ/cyberimp/cyberware/clotter_node)
	var/obj/item/organ/cyberimp/cyberware/adrenal_pump/pump = allocate(/obj/item/organ/cyberimp/cyberware/adrenal_pump)
	var/obj/item/organ/cyberimp/cyberware/medic_palms/palms = allocate(/obj/item/organ/cyberimp/cyberware/medic_palms)
	var/obj/item/organ/cyberimp/cyberware/cuffer_wrists/wrists = allocate(/obj/item/organ/cyberimp/cyberware/cuffer_wrists)
	var/obj/item/organ/cyberimp/cyberware/subvocal_mic/mic = allocate(/obj/item/organ/cyberimp/cyberware/subvocal_mic)
	var/obj/item/organ/cyberimp/cyberware/muffler_ear/muffler = allocate(/obj/item/organ/cyberimp/cyberware/muffler_ear)
	var/obj/item/organ/cyberimp/cyberware/gecko/gecko = allocate(/obj/item/organ/cyberimp/cyberware/gecko)
	var/obj/item/organ/cyberimp/cyberware/doppler/doppler = allocate(/obj/item/organ/cyberimp/cyberware/doppler)

	// ORGAN_SLOT_CYBERWARE_HEART_AUX, _HANDS, _LARYNX and _EARS.
	TEST_ASSERT_EQUAL(clotter.slot, "cyberware_heart_aux", "Clotter node is not in the spare heart slot")
	TEST_ASSERT_EQUAL(pump.slot, clotter.slot, "The pump and the node can both be fitted. They share the heart slot")
	TEST_ASSERT_EQUAL(palms.slot, gecko.slot, "Medic's palms are not in the Gecko Grip's hands slot")
	TEST_ASSERT_EQUAL(wrists.slot, gecko.slot, "Cuffer's wrists are not in the Gecko Grip's hands slot")
	TEST_ASSERT_EQUAL(mic.slot, "cyberware_larynx", "Subvocal mic is not in the larynx slot")
	TEST_ASSERT_EQUAL(muffler.slot, doppler.slot, "Muffler ear is not in the Doppler's ears slot")

	// Cheap street chrome, T1 apart from the pump.
	TEST_ASSERT_EQUAL(pump.tier, 2, "The pump is not T2")
	for(var/obj/item/organ/cyberimp/cyberware/cheap as anything in list(clotter, palms, wrists, mic, muffler))
		TEST_ASSERT_EQUAL(cheap.tier, 1, "[cheap] is not T1")

	// The cradle quotes a credit price for each, and only the pump needs yellow.
	build_cyberware_price_index()
	for(var/obj/item/organ/cyberimp/cyberware/priced as anything in list(clotter, pump, palms, wrists, mic, muffler))
		var/list/price = get_cyberware_price(priced)
		TEST_ASSERT(price && price["credits"] > 0 && !price["vouchers"], "[priced] quotes no credit-only price at the cradle")
	var/datum/shop_sku/ripperdoc/adrenal_pump/pump_sku = allocate(/datum/shop_sku/ripperdoc/adrenal_pump)
	var/datum/shop_sku/ripperdoc/clotter_node/clotter_sku = allocate(/datum/shop_sku/ripperdoc/clotter_node)
	TEST_ASSERT_EQUAL(pump_sku.zone_permission, 1, "The pump is not sold at yellow permission") // ZONE_PERMISSION_YELLOW
	TEST_ASSERT_EQUAL(clotter_sku.zone_permission, 0, "The node is gated") // ZONE_PERMISSION_PUBLIC

/// Clotter node: halves the blood lost, only while online, with one multiply and
/// one divide however often the passive layer flips, and the pump evicts it.
/datum/unit_test/voidcrew_cyberware_clotter_node

/datum/unit_test/voidcrew_cyberware_clotter_node/Run()
	var/mob/living/carbon/human/bearer = allocate(/mob/living/carbon/human/consistent)
	var/obj/item/organ/cyberimp/cyberware/clotter_node/clotter = allocate(/obj/item/organ/cyberimp/cyberware/clotter_node)
	var/datum/component/cyberware/chrome = clotter.GetComponent(/datum/component/cyberware)
	TEST_ASSERT_EQUAL(bearer.physiology.bleed_mod, 1, "Test fixture: the bearer already bleeds differently")

	TEST_ASSERT(clotter.Insert(bearer, special = TRUE), "Test fixture: Clotter node staging insert was refused")
	TEST_ASSERT_EQUAL(bearer.physiology.bleed_mod, 0.5, "An installed Clotter node didn't halve the bleed")

	// Asked twice, applied once.
	clotter.chrome_passives_on(bearer)
	TEST_ASSERT_EQUAL(bearer.physiology.bleed_mod, 0.5, "The node's multiplier was applied twice")

	chrome.start_emp_reboot()
	TEST_ASSERT_EQUAL(bearer.physiology.bleed_mod, 1, "An EMP'd Clotter node kept the bleed halved")
	chrome.tune_up()
	TEST_ASSERT_EQUAL(bearer.physiology.bleed_mod, 0.5, "A tuned-up Clotter node didn't hand the bleed cut back")

	// Retuning a fitted organ takes off what was put on, not what the var says now.
	clotter.bleed_multiplier = 0.25
	clotter.Remove(bearer, special = TRUE)
	clotter.forceMove(run_loc_floor_bottom_left)
	TEST_ASSERT_EQUAL(bearer.physiology.bleed_mod, 1, "Pulling the node left the bleed changed")

	// The heart slot holds one: the pump evicts the node and its cut with it.
	clotter.bleed_multiplier = 0.5
	TEST_ASSERT(clotter.Insert(bearer, special = TRUE), "Test fixture: Clotter node refit was refused")
	TEST_ASSERT_EQUAL(bearer.physiology.bleed_mod, 0.5, "A refitted Clotter node didn't halve the bleed")
	var/obj/item/organ/cyberimp/cyberware/adrenal_pump/pump = allocate(/obj/item/organ/cyberimp/cyberware/adrenal_pump)
	TEST_ASSERT(pump.Insert(bearer, special = TRUE), "Test fixture: pump staging insert was refused")
	TEST_ASSERT(!clotter.owner, "The pump went in beside the node. They share a slot")
	TEST_ASSERT_EQUAL(bearer.physiology.bleed_mod, 1, "The evicted node left its bleed cut on the bearer")

/// Medic's palms and Cuffer's wrists: their traits while online, gone on an EMP
/// and on removal, and the three hands-slot pieces evict one another.
/datum/unit_test/voidcrew_cyberware_hand_traits

/datum/unit_test/voidcrew_cyberware_hand_traits/Run()
	var/mob/living/carbon/human/bearer = allocate(/mob/living/carbon/human/consistent)
	var/obj/item/organ/cyberimp/cyberware/medic_palms/palms = allocate(/obj/item/organ/cyberimp/cyberware/medic_palms)
	var/obj/item/organ/cyberimp/cyberware/cuffer_wrists/wrists = allocate(/obj/item/organ/cyberimp/cyberware/cuffer_wrists)
	var/obj/item/organ/cyberimp/cyberware/gecko/gecko = allocate(/obj/item/organ/cyberimp/cyberware/gecko)

	TEST_ASSERT(palms.Insert(bearer, special = TRUE), "Test fixture: Medic's palms staging insert was refused")
	TEST_ASSERT(HAS_TRAIT(bearer, TRAIT_FASTMED), "Medic's palms didn't give the quicker chemistry trait")
	TEST_ASSERT(HAS_TRAIT(bearer, TRAIT_QUICKER_CARRY), "Medic's palms didn't give the quicker carry trait")
	TEST_ASSERT(!HAS_TRAIT(bearer, TRAIT_FAST_CUFFING), "Medic's palms give quicker cuffing")

	var/datum/component/cyberware/chrome = palms.GetComponent(/datum/component/cyberware)
	chrome.start_emp_reboot()
	TEST_ASSERT(!HAS_TRAIT(bearer, TRAIT_FASTMED) && !HAS_TRAIT(bearer, TRAIT_QUICKER_CARRY), "EMP'd Medic's palms kept their traits")
	chrome.tune_up()
	TEST_ASSERT(HAS_TRAIT(bearer, TRAIT_FASTMED) && HAS_TRAIT(bearer, TRAIT_QUICKER_CARRY), "Tuned-up Medic's palms didn't hand their traits back")

	// Cuffer's wrists evict the palms: same slot.
	TEST_ASSERT(wrists.Insert(bearer, special = TRUE), "Test fixture: Cuffer's wrists staging insert was refused")
	TEST_ASSERT(!palms.owner, "The wrists went in beside the palms. They share a slot")
	TEST_ASSERT(HAS_TRAIT(bearer, TRAIT_FAST_CUFFING), "Cuffer's wrists didn't give quicker cuffing")
	TEST_ASSERT(!HAS_TRAIT(bearer, TRAIT_FASTMED) && !HAS_TRAIT(bearer, TRAIT_QUICKER_CARRY), "The evicted palms left their traits on the bearer")

	// And the Gecko Grip evicts the wrists.
	TEST_ASSERT(gecko.Insert(bearer, special = TRUE), "Test fixture: Gecko Grip staging insert was refused")
	TEST_ASSERT(!wrists.owner, "The Gecko Grip went in beside the wrists. They share a slot")
	TEST_ASSERT(!HAS_TRAIT(bearer, TRAIT_FAST_CUFFING), "The evicted wrists left quicker cuffing on the bearer")

/// Muffler ear: a bang loses a point of intensity while the ear is online, the
/// same point earmuffs take off, and nothing when it is offline or pulled. The
/// intensity rides in a list, so the signal is read directly: the real
/// soundbang_act() also depends on the room's air.
/datum/unit_test/voidcrew_cyberware_muffler_ear

/datum/unit_test/voidcrew_cyberware_muffler_ear/Run()
	var/mob/living/carbon/human/bearer = allocate(/mob/living/carbon/human/consistent)
	var/obj/item/organ/cyberimp/cyberware/muffler_ear/muffler = allocate(/obj/item/organ/cyberimp/cyberware/muffler_ear)
	var/datum/component/cyberware/chrome = muffler.GetComponent(/datum/component/cyberware)

	var/list/reflist = list(1)
	SEND_SIGNAL(bearer, COMSIG_CARBON_SOUNDBANG, reflist)
	TEST_ASSERT_EQUAL(reflist[1], 1, "A bare body took a point off a bang")

	TEST_ASSERT(muffler.Insert(bearer, special = TRUE), "Test fixture: Muffler ear staging insert was refused")
	reflist = list(1)
	SEND_SIGNAL(bearer, COMSIG_CARBON_SOUNDBANG, reflist)
	TEST_ASSERT_EQUAL(reflist[1], 0, "The Muffler ear didn't take a point off the bang")

	// A bigger bang loses the one point and no more.
	reflist = list(2)
	SEND_SIGNAL(bearer, COMSIG_CARBON_SOUNDBANG, reflist)
	TEST_ASSERT_EQUAL(reflist[1], 1, "The Muffler ear took more than a point off a bigger bang")

	chrome.start_emp_reboot()
	reflist = list(1)
	SEND_SIGNAL(bearer, COMSIG_CARBON_SOUNDBANG, reflist)
	TEST_ASSERT_EQUAL(reflist[1], 1, "An EMP'd Muffler ear still muffled the bang")
	chrome.tune_up()
	reflist = list(1)
	SEND_SIGNAL(bearer, COMSIG_CARBON_SOUNDBANG, reflist)
	TEST_ASSERT_EQUAL(reflist[1], 0, "A tuned-up Muffler ear didn't muffle the bang again")

	muffler.Remove(bearer, special = TRUE)
	reflist = list(1)
	SEND_SIGNAL(bearer, COMSIG_CARBON_SOUNDBANG, reflist)
	TEST_ASSERT_EQUAL(reflist[1], 1, "A pulled Muffler ear still muffled the bang")

/// Adrenal pump: quiet below its trigger, one answer to a bad run of stamina
/// damage, nothing inside the wait (a refit doesn't reset it), nothing while
/// offline, and everything back once the wait is over.
/datum/unit_test/voidcrew_cyberware_adrenal_pump

/datum/unit_test/voidcrew_cyberware_adrenal_pump/Run()
	var/mob/living/carbon/human/bearer = allocate(/mob/living/carbon/human/consistent)
	var/obj/item/organ/cyberimp/cyberware/adrenal_pump/pump = allocate(/obj/item/organ/cyberimp/cyberware/adrenal_pump)
	TEST_ASSERT(pump.Insert(bearer, special = TRUE), "Test fixture: Adrenal pump staging insert was refused")
	var/datum/component/cyberware/chrome = pump.GetComponent(/datum/component/cyberware)

	// Below the trigger: nothing.
	bearer.adjustStaminaLoss(50)
	sleep(0.5 SECONDS)
	TEST_ASSERT_EQUAL(pump.ready_at, 0, "The pump fired below its trigger level")
	TEST_ASSERT(!bearer.has_status_effect(/datum/status_effect/cyberware_adrenal_rush), "A rush started below the pump's trigger level")

	// Over it: part of the loss comes off, the bearer is quick and flushed, and
	// the wait starts.
	bearer.adjustStaminaLoss(30)
	sleep(0.5 SECONDS)
	TEST_ASSERT(bearer.getStaminaLoss() <= 45, "The pump didn't take stamina loss off ([bearer.getStaminaLoss()] left of 80)")
	TEST_ASSERT(bearer.has_status_effect(/datum/status_effect/cyberware_adrenal_rush), "The pump fired without a rush")
	TEST_ASSERT(bearer.has_movespeed_modifier(/datum/movespeed_modifier/cyberware_adrenal_rush), "The rush didn't speed the bearer up")
	TEST_ASSERT(pump.ready_at > world.time, "The pump didn't start its wait")

	// Inside the wait: another bad run gets no answer.
	bearer.adjustStaminaLoss(50)
	sleep(0.5 SECONDS)
	TEST_ASSERT(bearer.getStaminaLoss() >= 85, "The pump fired again inside its wait")

	// Pulled and refitted: still waiting. The clock lives on the organ.
	var/waiting_until = pump.ready_at
	pump.Remove(bearer, special = TRUE)
	pump.forceMove(run_loc_floor_bottom_left)
	TEST_ASSERT(pump.Insert(bearer, special = TRUE), "Test fixture: Adrenal pump refit was refused")
	TEST_ASSERT_EQUAL(pump.ready_at, waiting_until, "Refitting the pump reset its wait")
	bearer.adjustStaminaLoss(5)
	sleep(0.5 SECONDS)
	TEST_ASSERT(bearer.getStaminaLoss() >= 90, "A refitted pump fired inside its wait")

	// Offline: no answer, and the wait is not spent.
	bearer.setStaminaLoss(0)
	pump.ready_at = 0
	chrome.start_emp_reboot()
	bearer.adjustStaminaLoss(80)
	sleep(0.5 SECONDS)
	TEST_ASSERT_EQUAL(pump.ready_at, 0, "An EMP'd pump fired")
	TEST_ASSERT(bearer.getStaminaLoss() >= 75, "An EMP'd pump took stamina loss off")

	// Back online, the next bad run is answered.
	chrome.tune_up()
	bearer.adjustStaminaLoss(1)
	sleep(0.5 SECONDS)
	TEST_ASSERT(pump.ready_at > world.time, "A tuned-up pump didn't answer a bad run")
	TEST_ASSERT(bearer.getStaminaLoss() <= 45, "A tuned-up pump didn't take stamina loss off")

/// The Cascade and Redline crashes dump stamina as their own price. The pump
/// stands down for them: it is a bar against outside damage, not a way out of
/// the legend ware's bill.
/datum/unit_test/voidcrew_cyberware_adrenal_pump_crash

/datum/unit_test/voidcrew_cyberware_adrenal_pump_crash/Run()
	var/mob/living/carbon/human/bearer = allocate(/mob/living/carbon/human/consistent)
	var/obj/item/organ/cyberimp/cyberware/adrenal_pump/pump = allocate(/obj/item/organ/cyberimp/cyberware/adrenal_pump)
	TEST_ASSERT(pump.Insert(bearer, special = TRUE), "Test fixture: Adrenal pump staging insert was refused")

	bearer.apply_status_effect(/datum/status_effect/cyberware_cascade_crash)
	sleep(0.5 SECONDS)
	TEST_ASSERT(bearer.has_status_effect(/datum/status_effect/cyberware_cascade_crash), "Test fixture: the Cascade crash isn't running")
	TEST_ASSERT(bearer.getStaminaLoss() >= 70, "Test fixture: the Cascade crash dumped no stamina")
	TEST_ASSERT_EQUAL(pump.ready_at, 0, "The pump answered the Cascade crash's own stamina dump")
	TEST_ASSERT(!bearer.has_status_effect(/datum/status_effect/cyberware_adrenal_rush), "The pump started a rush in the middle of a Cascade crash")
	bearer.remove_status_effect(/datum/status_effect/cyberware_cascade_crash)

	var/mob/living/carbon/human/redliner = allocate(/mob/living/carbon/human/consistent)
	var/obj/item/organ/cyberimp/cyberware/adrenal_pump/second_pump = allocate(/obj/item/organ/cyberimp/cyberware/adrenal_pump)
	TEST_ASSERT(second_pump.Insert(redliner, special = TRUE), "Test fixture: second pump staging insert was refused")
	redliner.apply_status_effect(/datum/status_effect/cyberware_redline_crash)
	sleep(0.5 SECONDS)
	TEST_ASSERT(redliner.has_status_effect(/datum/status_effect/cyberware_redline_crash), "Test fixture: the Redline crash isn't running")
	TEST_ASSERT_EQUAL(second_pump.ready_at, 0, "The pump answered the Redline crash's own stamina dump")
	redliner.remove_status_effect(/datum/status_effect/cyberware_redline_crash)

/// Subvocal mic: a radio line from a bearer is spoken at range 0, anything else
/// they say, and every line from a body without the mic, keeps its range. The
/// mark the radio branch leaves is spent by the one send_speech() that follows.
/datum/unit_test/voidcrew_cyberware_subvocal_mic
	/// The range the speaker's own Hear() was handed, or null before any line.
	var/heard_range

/datum/unit_test/voidcrew_cyberware_subvocal_mic/proc/on_heard(datum/source, list/hear_args)
	SIGNAL_HANDLER
	heard_range = hear_args[HEARING_RANGE]

/// One radio line the way say() sends it: the radio branch first, then the
/// whisper-range send. Returns the range the speaker's own Hear() was given.
/datum/unit_test/voidcrew_cyberware_subvocal_mic/proc/speak_on_radio(mob/living/carbon/human/speaker)
	heard_range = null
	var/radio_flags = speaker.radio("test", list(MODE_HEADSET = TRUE), list(), null)
	TEST_ASSERT(radio_flags & REDUCE_RANGE, "Test fixture: the radio branch didn't shorten the range")
	speaker.send_speech("test", 1, speaker, speaker.bubble_icon, list(), null, list(WHISPER_MODE = MODE_WHISPER))
	return heard_range

/datum/unit_test/voidcrew_cyberware_subvocal_mic/Run()
	var/mob/living/carbon/human/speaker = allocate(/mob/living/carbon/human/consistent, run_loc_floor_bottom_left)
	var/obj/item/clothing/ears/voidcrew_test_subvocal_ears/earpiece = allocate(/obj/item/clothing/ears/voidcrew_test_subvocal_ears)
	speaker.equip_to_slot_if_possible(earpiece, ITEM_SLOT_EARS, qdel_on_fail = FALSE, disable_warning = TRUE)
	TEST_ASSERT_EQUAL(speaker.ears, earpiece, "Test fixture: the earpiece didn't equip")
	RegisterSignal(speaker, COMSIG_MOVABLE_PRE_HEAR, PROC_REF(on_heard))

	// No mic: radio talk is whispered at range 1, as ever.
	TEST_ASSERT_EQUAL(speak_on_radio(speaker), 1, "A body without the mic changed its radio range")
	TEST_ASSERT(!speaker.cyberware_subvocal_pending, "A body without the mic left a mark behind")

	var/obj/item/organ/cyberimp/cyberware/subvocal_mic/mic = allocate(/obj/item/organ/cyberimp/cyberware/subvocal_mic)
	TEST_ASSERT(mic.Insert(speaker, special = TRUE), "Test fixture: Subvocal mic staging insert was refused")
	TEST_ASSERT(HAS_TRAIT(speaker, "cyber_subvocal"), "The Subvocal mic didn't give its trait") // TRAIT_CYBER_SUBVOCAL

	// Mic: the radio line is spoken at range 0, and the mark is spent.
	TEST_ASSERT_EQUAL(speak_on_radio(speaker), 0, "A radio line from a Subvocal mic bearer kept its range")
	TEST_ASSERT(!speaker.cyberware_subvocal_pending, "The radio line's mark outlived its send")

	// An ordinary line right after is not quieted.
	heard_range = null
	speaker.send_speech("test", 6, speaker, speaker.bubble_icon, list(), null, list())
	TEST_ASSERT_EQUAL(heard_range, 6, "A spoken line after a radio line was quieted")

	// A mark nobody sent is cleared by the next radio branch rather than quieting a plain line.
	speaker.cyberware_subvocal_pending = TRUE
	speaker.radio("test", list(), list(), null)
	TEST_ASSERT(!speaker.cyberware_subvocal_pending, "A stale mark survived a radio branch that sent nothing")

	// Offline: radio talk is overheard again.
	var/datum/component/cyberware/chrome = mic.GetComponent(/datum/component/cyberware)
	chrome.start_emp_reboot()
	TEST_ASSERT_EQUAL(speak_on_radio(speaker), 1, "An EMP'd Subvocal mic still quieted the radio")
	chrome.tune_up()
	TEST_ASSERT_EQUAL(speak_on_radio(speaker), 0, "A tuned-up Subvocal mic didn't quiet the radio again")

	mic.Remove(speaker, special = TRUE)
	TEST_ASSERT_EQUAL(speak_on_radio(speaker), 1, "A pulled Subvocal mic still quieted the radio")
