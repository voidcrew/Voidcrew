/**
 * Cyberware against the human NPCs and the gore layer.
 *
 * Human NPCs (voidcrew/modules/human_npcs/) are real human bodies, so the chrome works on them as on
 * a player, but an NPC's chrome burns out to scrap (/obj/item/burnt_chrome) when it dies or a piece
 * leaves its body by any route. These tests pin that the burn-out beats the chrome salvage (gib,
 * dust, a lost limb), that the scrap is no chrome (nothing reinstalls it, no ledger buys it), and
 * that Chrome Read and a deck's Glitch work on an NPC. The kit's chrome dummy is such a body.
 *
 * The gore layer (voidcrew/modules/hyperviolence/): the Atlas frame's dismember immunity stops head
 * bursts; the street Strut frame holds the bones only, so it stops fractures (the skull and jaw
 * crits included) but not a burst; Hardweave plating counts toward the crit armour gate; a Lazarus
 * node never brings back a body whose head burst during its wind-up; and the blades cut as blades.
 *
 * Literals (unit tests are included before the fork's defines): CYBERWARE_SCAN_ITEMIZED is 2; the
 * Lazarus wind-up is 1 second.
 */

/// Shared helpers; not a test itself
/datum/unit_test/voidcrew_cyberware_npcs
	abstract_type = /datum/unit_test/voidcrew_cyberware_npcs

/// The floor `dx`, `dy` tiles from the test room's bottom-left corner
/datum/unit_test/voidcrew_cyberware_npcs/proc/spot(dx, dy)
	return locate(run_loc_floor_bottom_left.x + dx, run_loc_floor_bottom_left.y + dy, run_loc_floor_bottom_left.z)

/// The kit's chrome dummy carrying `ware_types`, cleaned up with the test
/datum/unit_test/voidcrew_cyberware_npcs/proc/dummy_with(list/ware_types, turf/where)
	var/list/report = list()
	var/mob/living/carbon/human/npc/chrome_dummy/dummy = chrome_kit_make_dummy(where || run_loc_floor_bottom_left, ware_types, report)
	allocated += dummy
	TEST_ASSERT(!length(report), "The dummy turned chrome away: [jointext(report, "; ")]")
	return dummy

/// Every piece of chrome lying loose (owned by nobody) in or near the test room, however deep it sits
/datum/unit_test/voidcrew_cyberware_npcs/proc/loose_chrome()
	. = list()
	for(var/turf/floor in range(6, run_loc_floor_bottom_left))
		for(var/obj/item/organ/ware in floor.get_all_contents())
			if(!ware.owner && ware.GetComponent(/datum/component/cyberware))
				. += ware

/// The burnt-out scrap in or near the test room
/datum/unit_test/voidcrew_cyberware_npcs/proc/scrap_count()
	. = 0
	for(var/turf/floor in range(6, run_loc_floor_bottom_left))
		for(var/obj/item/burnt_chrome/scrap in floor.get_all_contents())
			.++

/// An NPC's chrome burns out when it dies; Chrome Read and Glitch work on it while it lives; the
/// scrap is not chrome and no ledger buys it.
/datum/unit_test/voidcrew_cyberware_npcs/burn_out

/datum/unit_test/voidcrew_cyberware_npcs/burn_out/Run()
	var/mob/living/carbon/human/npc/chrome_dummy/dummy = dummy_with(list(
		/obj/item/organ/cyberimp/cyberware/slipwire,
		/obj/item/organ/cyberimp/cyberware/dermal_mesh,
		/obj/item/organ/cyberimp/arm/toolkit/cyberware/mantis,
	), spot(2, 2))
	TEST_ASSERT(istype(dummy, /mob/living/carbon/human/npc), "The kit's chrome dummy isn't a human NPC body")
	TEST_ASSERT_NULL(dummy.ai_controller, "The kit's chrome dummy has an AI")
	TEST_ASSERT_EQUAL(length(get_installed_cyberware(dummy)), 3, "The dummy didn't take its three pieces")

	// Chrome Read reads an NPC like anyone else.
	var/mob/living/carbon/human/reader = allocate(/mob/living/carbon/human/consistent, spot(0, 0))
	var/obj/item/organ/eyes/robotic/cyberware/deadeye/optics = allocate(/obj/item/organ/eyes/robotic/cyberware/deadeye)
	TEST_ASSERT(optics.Insert(reader, special = TRUE), "Deadeye staging insert was refused")
	var/list/report = cyberware_scan_report(dummy, 2)
	TEST_ASSERT_EQUAL(report["count"], 3, "Chrome Read miscounted an NPC's chrome")
	var/datum/action/cooldown/cyberware/chrome_read/read = locate() in optics.actions
	TEST_ASSERT_NOTNULL(read, "The Deadeye link lost its chrome read")
	TEST_ASSERT(read.PreActivate(dummy), "The chrome read didn't run on an NPC in reach")
	TEST_ASSERT_NOTNULL(read.current_readout, "The chrome read drew nothing over an NPC")

	// A deck's Glitch drops a piece of an NPC's chrome into a reboot.
	var/datum/machine_quickhack/glitch/glitch
	for(var/datum/machine_quickhack/hack as anything in get_machine_quickhacks())
		if(istype(hack, /datum/machine_quickhack/glitch))
			glitch = hack
	TEST_ASSERT_NOTNULL(glitch, "Glitch is not a quickhack")
	TEST_ASSERT(glitch.valid_for(dummy, reader), "Glitch was not offered on a chromed NPC")
	TEST_ASSERT(glitch.execute(dummy, reader), "Glitch did not land on an NPC")
	var/rebooting = 0
	for(var/obj/item/organ/ware as anything in get_installed_cyberware(dummy))
		var/datum/component/cyberware/chrome = ware.GetComponent(/datum/component/cyberware)
		if(chrome?.emp_down)
			rebooting++
	TEST_ASSERT_EQUAL(rebooting, 1, "Glitch didn't reboot exactly one piece of an NPC's chrome")

	// Death: every piece comes out as scrap, nothing intact is left anywhere.
	dummy.death()
	TEST_ASSERT(!length(get_installed_cyberware(dummy)), "A dead NPC kept chrome in its body")
	sleep(0.5 SECONDS)
	TEST_ASSERT(!length(loose_chrome()), "A dead NPC left working chrome behind")
	TEST_ASSERT_EQUAL(scrap_count(), 3, "A dead NPC didn't leave one burnt-out scrap per piece")

	// The scrap is no chrome: nothing can install it, and no ledger anywhere buys it.
	var/obj/item/burnt_chrome/scrap = locate() in range(6, run_loc_floor_bottom_left)
	TEST_ASSERT_NOTNULL(scrap, "Fixture: no scrap to offer")
	TEST_ASSERT(!istype(scrap, /obj/item/organ), "Burnt-out chrome is still an organ")
	TEST_ASSERT_NULL(scrap.GetComponent(/datum/component/cyberware), "Burnt-out chrome still counts as chrome")
	for(var/buyback_type in subtypesof(/datum/shop_buyback))
		var/datum/shop_buyback/ledger = new buyback_type
		if(ledger.item_path && ledger.matches(scrap))
			TEST_FAIL("[buyback_type] buys burnt-out chrome")
		qdel(ledger)

/// Chrome the salvage throws loose (gib, dust) or a lost limb carries off burns out all the same.
/datum/unit_test/voidcrew_cyberware_npcs/salvage

/datum/unit_test/voidcrew_cyberware_npcs/salvage/Run()
	// A lost arm takes its chrome with it, and the chrome burns where the arm lies.
	var/mob/living/carbon/human/npc/chrome_dummy/maimed = dummy_with(list(/obj/item/organ/cyberimp/arm/toolkit/cyberware/mantis), spot(1, 1))
	var/obj/item/bodypart/arm = maimed.get_bodypart(BODY_ZONE_R_ARM)
	TEST_ASSERT(arm.dismember(), "Fixture: the dummy's arm wouldn't come off")
	sleep(0.5 SECONDS)
	TEST_ASSERT(!length(loose_chrome()), "Chrome in an NPC's lost arm stayed working")
	TEST_ASSERT_EQUAL(scrap_count(), 1, "Chrome in an NPC's lost arm didn't burn out")
	qdel(maimed)

	// Gibbed: the salvage throws the chrome loose, and it burns out where it lands.
	var/mob/living/carbon/human/npc/chrome_dummy/gibbed = dummy_with(list(
		/obj/item/organ/cyberimp/cyberware/slipwire,
		/obj/item/organ/cyberimp/cyberware/atlas/street,
	), spot(2, 2))
	gibbed.gib()
	sleep(0.5 SECONDS)
	TEST_ASSERT(!length(loose_chrome()), "A gibbed NPC left working chrome behind")
	TEST_ASSERT_EQUAL(scrap_count(), 3, "A gibbed NPC's chrome didn't burn out")

	// Dusted: the same.
	var/mob/living/carbon/human/npc/chrome_dummy/dusted = dummy_with(list(/obj/item/organ/cyberimp/cyberware/dermal_mesh), spot(3, 3))
	dusted.dust()
	sleep(0.5 SECONDS)
	TEST_ASSERT(!length(loose_chrome()), "A dusted NPC left working chrome behind")
	TEST_ASSERT_EQUAL(scrap_count(), 4, "A dusted NPC's chrome didn't burn out")

/// The frames against the gore layer: Atlas stops bursts; the Strut frame stops fractures, the skull
/// and jaw crits included, but a head still bursts and a limb still comes off.
/datum/unit_test/voidcrew_cyberware_npcs/frames

/datum/unit_test/voidcrew_cyberware_npcs/frames/Run()
	var/datum/hv_crit/skull = locate(/datum/hv_crit/skull) in GLOB.hv_crits
	var/datum/hv_crit/jaw = locate(/datum/hv_crit/jaw) in GLOB.hv_crits
	TEST_ASSERT(skull && jaw, "The skull and jaw crits are gone")

	var/mob/living/carbon/human/plain = allocate(/mob/living/carbon/human/consistent, spot(0, 0))
	TEST_ASSERT(skull.can_apply_carbon(plain, plain.get_bodypart(BODY_ZONE_HEAD), WOUND_BLUNT), "Fixture: a plain head can't take the skull crit")

	// Strut: bones only.
	var/mob/living/carbon/human/strut_bearer = allocate(/mob/living/carbon/human/consistent, spot(1, 0))
	var/obj/item/organ/cyberimp/cyberware/atlas/street/strut = allocate(/obj/item/organ/cyberimp/cyberware/atlas/street)
	TEST_ASSERT(strut.Insert(strut_bearer, special = TRUE), "Strut frame staging insert was refused")
	var/obj/item/bodypart/strut_head = strut_bearer.get_bodypart(BODY_ZONE_HEAD)
	TEST_ASSERT(!skull.can_apply_carbon(strut_bearer, strut_head, WOUND_BLUNT), "The skull caved in under a Strut frame")
	TEST_ASSERT(!jaw.can_apply_carbon(strut_bearer, strut_head, WOUND_BLUNT), "The jaw shattered under a Strut frame")
	var/datum/wound_pregen_data/fracture = GLOB.all_wound_pregen_data[/datum/wound/blunt/bone/severe]
	TEST_ASSERT(!fracture.can_be_applied_to(strut_bearer.get_bodypart(BODY_ZONE_L_ARM), list(WOUND_BLUNT)), "An arm fractured under a Strut frame")
	TEST_ASSERT(strut_head.can_dismember(), "A Strut frame made the head impossible to take off")
	var/obj/item/bodypart/strut_leg = strut_bearer.get_bodypart(BODY_ZONE_R_LEG)
	TEST_ASSERT(strut_leg.dismember(), "A Strut frame kept a leg on")
	strut_bearer.adjustOxyLoss(160)
	TEST_ASSERT_EQUAL(strut_bearer.stat, HARD_CRIT, "Fixture: the Strut bearer isn't in hard crit")
	TEST_ASSERT(strut_bearer.hv_burst_head(NORTH), "A Strut frame stopped a head burst")
	TEST_ASSERT_NULL(strut_bearer.get_bodypart(BODY_ZONE_HEAD), "A burst head is still on")

	// Atlas: nothing comes off, nothing bursts.
	var/mob/living/carbon/human/atlas_bearer = allocate(/mob/living/carbon/human/consistent, spot(2, 0))
	var/obj/item/organ/cyberimp/cyberware/atlas/atlas = allocate(/obj/item/organ/cyberimp/cyberware/atlas)
	TEST_ASSERT(atlas.Insert(atlas_bearer, special = TRUE), "Atlas frame staging insert was refused")
	TEST_ASSERT(!skull.can_apply_carbon(atlas_bearer, atlas_bearer.get_bodypart(BODY_ZONE_HEAD), WOUND_BLUNT), "The skull caved in under an Atlas frame")
	atlas_bearer.adjustOxyLoss(160)
	TEST_ASSERT_EQUAL(atlas_bearer.stat, HARD_CRIT, "Fixture: the Atlas bearer isn't in hard crit")
	TEST_ASSERT(!atlas_bearer.hv_burst_head(NORTH), "A head burst under an Atlas frame")
	TEST_ASSERT_NOTNULL(atlas_bearer.get_bodypart(BODY_ZONE_HEAD), "An Atlas bearer lost the head")

/// Plating: Hardweave sits in the body's physiology armour, so the crit gate counts it.
/datum/unit_test/voidcrew_cyberware_npcs/plating

/datum/unit_test/voidcrew_cyberware_npcs/plating/Run()
	var/mob/living/carbon/human/bearer = allocate(/mob/living/carbon/human/consistent, spot(0, 0))
	var/obj/item/bodypart/chest = bearer.get_bodypart(BODY_ZONE_CHEST)
	TEST_ASSERT_EQUAL(round(hv_crit_cover_rating(bearer, chest, MELEE)), 0, "Fixture: a bare body has crit cover")
	var/obj/item/organ/cyberimp/cyberware/dermal_mesh/hardweave/plating = allocate(/obj/item/organ/cyberimp/cyberware/dermal_mesh/hardweave)
	TEST_ASSERT(plating.Insert(bearer, special = TRUE), "Hardweave staging insert was refused")
	TEST_ASSERT_EQUAL(round(hv_crit_cover_rating(bearer, chest, MELEE)), 20, "Hardweave plating doesn't count toward the crit gate")

/// A Lazarus node winds up as its bearer goes down, but a head that bursts in that second stays burst.
/datum/unit_test/voidcrew_cyberware_npcs/lazarus

/datum/unit_test/voidcrew_cyberware_npcs/lazarus/Run()
	var/mob/living/carbon/human/bearer = allocate(/mob/living/carbon/human/consistent, spot(0, 0))
	var/obj/item/organ/cyberimp/cyberware/lazarus/node = allocate(/obj/item/organ/cyberimp/cyberware/lazarus)
	TEST_ASSERT(node.Insert(bearer, special = TRUE), "Lazarus staging insert was refused")
	bearer.adjustOxyLoss(160)
	TEST_ASSERT_EQUAL(bearer.stat, HARD_CRIT, "Fixture: the Lazarus bearer isn't in hard crit")
	TEST_ASSERT(node.jolting, "The Lazarus node didn't wind up as its bearer went down")
	TEST_ASSERT(bearer.hv_burst_head(NORTH), "Fixture: the head didn't burst")
	TEST_ASSERT_EQUAL(bearer.stat, DEAD, "A burst head didn't kill")
	sleep(2 SECONDS)
	TEST_ASSERT_EQUAL(bearer.stat, DEAD, "A Lazarus node brought back a body with a burst head")
	TEST_ASSERT_NULL(bearer.get_bodypart(BODY_ZONE_HEAD), "A burst head came back")

/// The blades cut as blades: brute, edged, so they bleed, spray and slash. An aimed Mantis cut at
/// the head can open the throat.
/datum/unit_test/voidcrew_cyberware_npcs/blades

/datum/unit_test/voidcrew_cyberware_npcs/blades/Run()
	var/static/list/blade_types = list(
		/obj/item/melee/energy/blade/hardlight/cyberware_mantis,
		/obj/item/melee/energy/blade/hardlight/cyberware_mantis/street,
		/obj/item/melee/energy/blade/hardlight/cyberware_mantis/scorch,
		/obj/item/melee/cyberware_monowire,
		/obj/item/melee/cyberware_monowire/live,
	)
	for(var/blade_type in blade_types)
		var/obj/item/blade = allocate(blade_type)
		TEST_ASSERT_EQUAL(blade.damtype, BRUTE, "[blade_type] doesn't cut for brute, so it never bleeds")
		TEST_ASSERT_EQUAL(hv_crit_wounding_type(NONE, blade), WOUND_SLASH, "[blade_type] doesn't slash")

	var/mob/living/carbon/human/user = allocate(/mob/living/carbon/human/consistent, spot(0, 0))
	var/mob/living/carbon/human/victim = allocate(/mob/living/carbon/human/consistent, spot(1, 0))
	var/obj/item/mantis = allocate(/obj/item/melee/energy/blade/hardlight/cyberware_mantis)
	TEST_ASSERT(user.put_in_active_hand(mantis), "Fixture: the user couldn't hold the blade")
	user.zone_selected = BODY_ZONE_HEAD
	var/obj/item/bodypart/head = victim.get_bodypart(BODY_ZONE_HEAD)
	var/datum/hv_crit/landed = victim.hv_try_aimed_crit(head, BODY_ZONE_HEAD, WOUND_SLASH, mantis.force, mantis.wound_bonus, 0, EAST, mantis, user, 95)
	TEST_ASSERT(istype(landed, /datum/hv_crit/throat), "An aimed Mantis cut at the head couldn't open the throat")
