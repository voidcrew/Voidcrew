/**
 * # Chrome interaction matrix
 *
 * Every piece of chrome against the things that happen to a body: an EMP, a brownout, death
 * and revival, a gib or a dusting, a lost limb, a pacifist trait, a stun or a ride in a mech.
 * The tests walk the whole roster (every non-fixture subtype of the three chrome organ bases),
 * so a new ware is covered the day it is added. What each column promises is in the test that
 * checks it. The same walk writes one line per ware and condition to data/matrix_observed.txt,
 * which is where the written matrix (kept with the cyberware notes) is built from.
 *
 * Unit-test files compile before voidcrew/_DEFINES/, so the fork defines this file needs are
 * restated below under MATRIX_ names.
 */

/// TRAIT_CYBER_CAMO and TRAIT_CYBER_ZOOMED.
#define MATRIX_TRAIT_CAMO "cyber_camo"
#define MATRIX_TRAIT_ZOOMED "cyber_zoomed"
/// ORGAN_SLOT_CYBERWARE_SKIN, the Ghostskin slot.
#define MATRIX_SLOT_SKIN "cyberware_skin"

/// Every chrome typepath the matrix and the soak walk: each non-fixture subtype of the three
/// chrome organ bases that has a body zone and a slot.
/proc/voidcrew_cyberware_pool()
	var/static/list/pool
	if(pool)
		return pool
	pool = list()
	for(var/base in list(/obj/item/organ/cyberimp/cyberware, /obj/item/organ/eyes/robotic/cyberware, /obj/item/organ/cyberimp/arm/toolkit/cyberware))
		for(var/ware_type in subtypesof(base))
			var/path_text = "[ware_type]"
			// Fixtures tests define (test_, the ballast pieces, voidcrew_*_test).
			if(findtext(path_text, "/test_") || findtext(path_text, "ballast") || findtext(path_text, "_test"))
				continue
			var/obj/item/organ/example = ware_type
			if(!initial(example.zone) || !initial(example.slot))
				continue
			pool += ware_type
	return pool

/// What a body looks like to the passive layer: physiology numbers and armour, movement and
/// action speed modifiers. Equal before a ware goes in and while it is dark.
/proc/voidcrew_cyberware_passive_state(mob/living/carbon/human/body)
	var/list/state = list()
	for(var/var_name in body.physiology.vars)
		var/value = body.physiology.vars[var_name]
		if(isnum(value))
			state["physiology [var_name]"] = value
	for(var/rating in ARMOR_LIST_ALL())
		state["armor [rating]"] = body.physiology.armor.get_rating(rating)
	// Damage, lying down and mood come and go on their own; they are not what the chrome put there
	// (a Redline crash dumps enough stamina to put its bearer on the floor).
	var/list/speed = list()
	for(var/modifier in body.movespeed_modification)
		if(!findtext("[modifier]", "damage_slowdown") && !findtext("[modifier]", "carbon_crawling"))
			speed += "[modifier]"
	state["movespeed"] = speed.Join(",")
	var/list/action_speed = list()
	for(var/modifier in body.actionspeed_modification)
		if(!findtext("[modifier]", "sanity_component"))
			action_speed += "[modifier]"
	state["actionspeed"] = action_speed.Join(",")
	return state

/// Every trait a ware itself is holding on its bearer.
/proc/voidcrew_cyberware_held_traits(mob/living/carbon/human/body, obj/item/organ/ware)
	var/list/held = list()
	var/ware_ref = REF(ware)
	for(var/trait in body._status_traits)
		if(ware_ref in body._status_traits[trait])
			held += "[trait]"
	return held

/// The differences between two passive states, as lines.
/proc/voidcrew_cyberware_state_diff(list/before, list/after)
	var/list/differences = list()
	for(var/key in before)
		if(before[key] != after[key])
			differences += "[key] [before[key]] -> [after[key]]"
	for(var/key in after)
		if(isnull(before[key]))
			differences += "[key] gained [after[key]]"
	return differences

/// Chrome-side datums still registered on a body they no longer belong to. Empty when the
/// body's signal table holds only what its current chrome put there.
/proc/voidcrew_cyberware_stale_listeners(mob/living/carbon/human/body)
	var/list/stale = list()
	for(var/signal in body._listen_lookup)
		var/looked_up = body._listen_lookup[signal]
		var/list/listeners = islist(looked_up) ? looked_up : list(looked_up)
		for(var/datum/listener as anything in listeners)
			if(QDELETED(listener))
				stale += "[signal]: deleted [listener.type]"
			else if(isorgan(listener))
				var/obj/item/organ/organ = listener
				if(organ.owner != body)
					stale += "[signal]: [organ.type] (not installed)"
			else if(istype(listener, /datum/component/cyberware))
				var/datum/component/cyberware/chrome = listener
				var/obj/item/organ/parent_ware = chrome.parent
				if(parent_ware?.owner != body)
					stale += "[signal]: cyberware component of [parent_ware?.type] (not installed)"
			else if(istype(listener, /datum/action))
				var/datum/action/ability = listener
				if(ability.owner != body)
					stale += "[signal]: action [ability.type] (not owned)"
			else if(istype(listener, /datum/status_effect))
				var/datum/status_effect/effect = listener
				if(effect.owner != body)
					stale += "[signal]: status [effect.type] (not applied)"
	return stale

/// Pulled and held by the matrix tests: a heavy ballast piece that pushes any body past its
/// capacity (sized per body when it goes in). Separate from the soak's, so the two files
/// stand alone.
/obj/item/organ/cyberimp/cyberware/matrix_ballast
	name = "matrix ballast"
	zone = BODY_ZONE_CHEST
	slot = "voidcrew_matrix_ballast"
	chrome_load = 25

/datum/unit_test/voidcrew_cyberware_matrix
	abstract_type = /datum/unit_test/voidcrew_cyberware_matrix
	/// Which column of the matrix this test is.
	var/column = "?"
	/// Lines for data/matrix_observed.txt.
	var/list/observed = list()

/datum/unit_test/voidcrew_cyberware_matrix/Destroy()
	if(length(observed))
		var/text = "[observed.Join("\n")]\n"
		text2file(text, "data/matrix_observed.txt")
	return ..()

/// One cell: this ware, this condition, what happened.
/datum/unit_test/voidcrew_cyberware_matrix/proc/cell(ware_type, result)
	observed += "[column]\t[ware_type]\t[result]"

/// A fresh body with one ware special-inserted, or null when this ware has no home on it.
/datum/unit_test/voidcrew_cyberware_matrix/proc/fit(ware_type, list/out_ware)
	var/mob/living/carbon/human/body = allocate(/mob/living/carbon/human/consistent)
	var/obj/item/organ/ware = allocate(ware_type)
	if(!body.get_bodypart(deprecise_zone(ware.zone)) || !ware.Insert(body, special = TRUE))
		qdel(ware)
		qdel(body)
		return null
	out_ware += ware
	return body

/// The cooldown buttons of a ware, reset so only the chrome can stand in the way.
/datum/unit_test/voidcrew_cyberware_matrix/proc/buttons(obj/item/organ/ware)
	var/list/found = list()
	for(var/datum/action/cooldown/cyberware/ability in ware.actions)
		ability.next_use_time = 0
		found += ability
	return found

/// The deployable of an arm piece, if it has one.
/datum/unit_test/voidcrew_cyberware_matrix/proc/arm_item(obj/item/organ/ware)
	if(!istype(ware, /obj/item/organ/cyberimp/arm/toolkit/cyberware))
		return null
	return locate(/obj/item) in ware.contents

/// EMP: a pulse takes the whole ware dark and takes every passive with it, and the
/// repair brings it all back exactly as it was. Repeated, so a non-idempotent passive that
/// stacks on every reboot shows.
/datum/unit_test/voidcrew_cyberware_matrix/emp
	column = "emp"

/datum/unit_test/voidcrew_cyberware_matrix/emp/Run()
	var/mob/living/carbon/human/bare = allocate(/mob/living/carbon/human/consistent)
	var/list/bare_state = voidcrew_cyberware_passive_state(bare)
	for(var/ware_type in voidcrew_cyberware_pool())
		var/list/wares = list()
		var/mob/living/carbon/human/body = fit(ware_type, wares)
		if(!body)
			cell(ware_type, "no home on a plain body")
			continue
		var/obj/item/organ/ware = wares[1]
		var/datum/component/cyberware/chrome = ware.GetComponent(/datum/component/cyberware)
		TEST_ASSERT_NOTNULL(chrome, "[ware_type] carries no cyberware component")
		var/list/lit_state = voidcrew_cyberware_passive_state(body)
		var/list/problems = list()
		var/list/cooldowns = buttons(ware)
		var/list/ready_before = list()
		for(var/datum/action/cooldown/cyberware/ability as anything in cooldowns)
			if(ability.IsAvailable())
				ready_before += ability
		var/obj/item/arm_thing = arm_item(ware)
		var/obj/item/organ/cyberimp/arm/toolkit/cyberware/arm_ware = ware
		if(arm_thing)
			arm_ware.Extend(arm_thing)
		var/obj/item/organ/eyes/robotic/cyberware/optics = ware
		if(istype(optics))
			optics.engage_zoom(body)
		for(var/cycle in 1 to 3)
			body.emp_act(EMP_HEAVY)
			if(!chrome.emp_down || chrome.is_running() || !(ware.organ_flags & ORGAN_FAILING))
				problems += "a pulse left it running (emp_down [chrome.emp_down], flags [ware.organ_flags])"
			if(chrome.passives_online)
				problems += "passives stayed on through the pulse"
			// One heartbeat: the readout-style passives settle on the organ's own tick.
			ware.on_life(2, 1)
			var/list/held = voidcrew_cyberware_held_traits(body, ware)
			if(length(held))
				problems += "held traits through the pulse: [english_list(held)]"
			var/list/leaks = voidcrew_cyberware_state_diff(bare_state, voidcrew_cyberware_passive_state(body))
			if(length(leaks))
				problems += "the passive layer is not bare while dark: [english_list(leaks)]"
			for(var/datum/action/cooldown/cyberware/ability as anything in ready_before)
				if(ability.IsAvailable())
					problems += "[ability.type] still available while dark"
			if(arm_thing && arm_ware.active_item)
				problems += "the arm weapon stayed out through the pulse"
			if(istype(optics) && optics.is_zoomed())
				problems += "the zoom stayed on through the pulse"
			chrome.tune_up()
			if(!chrome.is_running() || !chrome.passives_online)
				problems += "a tune-up did not bring it back (running [chrome.is_running()], passives [chrome.passives_online])"
			var/list/restored = voidcrew_cyberware_state_diff(lit_state, voidcrew_cyberware_passive_state(body))
			if(length(restored))
				problems += "reboot number [cycle] did not restore the body exactly: [english_list(restored)]"
			if(arm_thing)
				arm_ware.Extend(arm_thing)
			if(istype(optics))
				optics.engage_zoom(body)
		if(length(problems))
			cell(ware_type, "FAIL: [problems[1]]")
			TEST_FAIL("[ware_type]: [english_list(problems)]")
		else
			cell(ware_type, "ok")
		qdel(body)

/// Brownout: a body past its capacity takes every piece dark with the same bare passive
/// layer, and recovers when the load drops.
/datum/unit_test/voidcrew_cyberware_matrix/brownout
	column = "brownout"

/datum/unit_test/voidcrew_cyberware_matrix/brownout/Run()
	var/mob/living/carbon/human/bare = allocate(/mob/living/carbon/human/consistent)
	var/list/bare_state = voidcrew_cyberware_passive_state(bare)
	for(var/ware_type in voidcrew_cyberware_pool())
		var/list/wares = list()
		var/mob/living/carbon/human/body = fit(ware_type, wares)
		if(!body)
			cell(ware_type, "no home on a plain body")
			continue
		var/obj/item/organ/ware = wares[1]
		var/datum/component/cyberware/chrome = ware.GetComponent(/datum/component/cyberware)
		var/list/lit_state = voidcrew_cyberware_passive_state(body)
		var/list/problems = list()
		var/list/cooldowns = buttons(ware)
		var/list/ready_before = list()
		for(var/datum/action/cooldown/cyberware/ability as anything in cooldowns)
			if(ability.IsAvailable())
				ready_before += ability
		var/obj/item/arm_thing = arm_item(ware)
		var/obj/item/organ/cyberimp/arm/toolkit/cyberware/arm_ware = ware
		if(arm_thing)
			arm_ware.Extend(arm_thing)
		var/obj/item/organ/eyes/robotic/cyberware/optics = ware
		if(istype(optics))
			optics.engage_zoom(body)
		var/obj/item/organ/cyberimp/cyberware/matrix_ballast/ballast = allocate(/obj/item/organ/cyberimp/cyberware/matrix_ballast)
		var/datum/component/cyberware/ballast_chrome = ballast.GetComponent(/datum/component/cyberware)
		ballast_chrome.chrome_load = get_chrome_capacity(body) + 5
		ballast.Insert(body, special = TRUE)
		if(!chrome.browned_out || chrome.is_running() || !(ware.organ_flags & ORGAN_FAILING))
			problems += "an overloaded body left it running (browned_out [chrome.browned_out])"
		if(chrome.passives_online)
			problems += "passives stayed on through the brownout"
		ware.on_life(2, 1)
		var/list/held = voidcrew_cyberware_held_traits(body, ware)
		if(length(held))
			problems += "held traits through the brownout: [english_list(held)]"
		var/list/leaks = voidcrew_cyberware_state_diff(bare_state, voidcrew_cyberware_passive_state(body))
		// The ballast is a ware too, so its own (empty) layer is part of the picture.
		if(length(leaks))
			problems += "the passive layer is not bare while browned out: [english_list(leaks)]"
		for(var/datum/action/cooldown/cyberware/ability as anything in ready_before)
			if(ability.IsAvailable())
				problems += "[ability.type] still available while browned out"
		if(arm_thing && arm_ware.active_item)
			problems += "the arm weapon stayed out through the brownout"
		if(istype(optics) && optics.is_zoomed())
			problems += "the zoom stayed on through the brownout"
		ballast.Remove(body, special = TRUE)
		if(!chrome.is_running() || !chrome.passives_online)
			problems += "easing the load did not bring it back (running [chrome.is_running()], passives [chrome.passives_online])"
		var/list/restored = voidcrew_cyberware_state_diff(lit_state, voidcrew_cyberware_passive_state(body))
		if(length(restored))
			problems += "easing the load did not restore the body exactly: [english_list(restored)]"
		if(length(problems))
			cell(ware_type, "FAIL: [problems[1]]")
			TEST_FAIL("[ware_type]: [english_list(problems)]")
		else
			cell(ware_type, "ok")
		qdel(body)

/// Death and revival: the buttons go dark with the body, and a revived body gets the same
/// passive layer back, however many times it dies.
/datum/unit_test/voidcrew_cyberware_matrix/death
	column = "death/revive"

/datum/unit_test/voidcrew_cyberware_matrix/death/Run()
	for(var/ware_type in voidcrew_cyberware_pool())
		var/list/wares = list()
		var/mob/living/carbon/human/body = fit(ware_type, wares)
		if(!body)
			cell(ware_type, "no home on a plain body")
			continue
		var/obj/item/organ/ware = wares[1]
		var/datum/component/cyberware/chrome = ware.GetComponent(/datum/component/cyberware)
		var/list/lit_state = voidcrew_cyberware_passive_state(body)
		var/list/lit_traits = voidcrew_cyberware_held_traits(body, ware)
		var/list/problems = list()
		var/list/cooldowns = buttons(ware)
		var/list/ready_before = list()
		for(var/datum/action/cooldown/cyberware/ability as anything in cooldowns)
			if(ability.IsAvailable())
				ready_before += ability
		var/obj/item/arm_thing = arm_item(ware)
		var/obj/item/organ/cyberimp/arm/toolkit/cyberware/arm_ware = ware
		var/obj/item/organ/eyes/robotic/cyberware/optics = ware
		for(var/cycle in 1 to 2)
			if(arm_thing)
				arm_ware.Extend(arm_thing)
			if(istype(optics))
				optics.engage_zoom(body)
			body.death()
			if(ware.owner != body)
				problems += "death took it out of the body"
			for(var/datum/action/cooldown/cyberware/ability as anything in ready_before)
				if(ability.IsAvailable())
					problems += "[ability.type] still available on a dead body"
			if(istype(optics) && optics.is_zoomed())
				problems += "the zoom stayed on through death"
			body.revive(ADMIN_HEAL_ALL)
			if(body.stat == DEAD)
				problems += "the fixture would not revive"
				break
			// Healing refreshes organs, which can clear the shared failing bit; the next tick puts it right.
			chrome.update_failing()
			if(!chrome.is_running() || chrome.passives_online != !!chrome.is_running())
				problems += "revival left it out of step (running [chrome.is_running()], passives [chrome.passives_online])"
			var/list/restored = voidcrew_cyberware_state_diff(lit_state, voidcrew_cyberware_passive_state(body))
			if(length(restored))
				problems += "death number [cycle] changed the passive layer: [english_list(restored)]"
			var/list/held_now = voidcrew_cyberware_held_traits(body, ware)
			if(length(held_now) != length(lit_traits) || length(held_now ^ lit_traits))
				problems += "death number [cycle] changed the traits it holds"
		if(length(problems))
			cell(ware_type, "FAIL: [problems[1]]")
			TEST_FAIL("[ware_type]: [english_list(problems)]")
		else
			cell(ware_type, "ok")
		qdel(body)

/// Gibbing and dusting: the chrome comes out whole on the floor.
/datum/unit_test/voidcrew_cyberware_matrix/gib
	column = "gib/dust"

/datum/unit_test/voidcrew_cyberware_matrix/gib/Run()
	for(var/ware_type in voidcrew_cyberware_pool())
		for(var/dusting in list(FALSE, TRUE))
			var/list/wares = list()
			var/mob/living/carbon/human/body = fit(ware_type, wares)
			if(!body)
				if(!dusting)
					cell(ware_type, "no home on a plain body")
				continue
			var/obj/item/organ/ware = wares[1]
			var/obj/item/arm_thing = arm_item(ware)
			var/obj/item/organ/cyberimp/arm/toolkit/cyberware/arm_ware = ware
			if(arm_thing)
				arm_ware.Extend(arm_thing)
			if(dusting)
				body.dust()
			else
				body.gib()
			var/problem
			if(QDELETED(ware))
				problem = "[dusting ? "dusting" : "gibbing"] destroyed it"
			else if(ware.owner)
				problem = "it is still owned by the corpse"
			else if(!isturf(ware.loc))
				problem = "it ended up in [ware.loc ? ware.loc.type : "nullspace"], not on the floor"
			else if(arm_thing && (QDELETED(arm_thing) || arm_thing.loc != ware))
				problem = "its deployed weapon did not go back into it"
			cell(ware_type, "[dusting ? "dust" : "gib"]: [problem ? "FAIL: [problem]" : "ok"]")
			if(problem)
				TEST_FAIL("[ware_type]: [problem]")

/// Limbs: a limb that is gone cannot take its chrome, and chrome in a limb that goes is let go
/// cleanly with every passive.
/datum/unit_test/voidcrew_cyberware_matrix/limb
	column = "missing limb"

/datum/unit_test/voidcrew_cyberware_matrix/limb/Run()
	for(var/ware_type in voidcrew_cyberware_pool())
		var/obj/item/organ/example = ware_type
		var/zone = initial(example.zone)
		if(!(zone in list(BODY_ZONE_L_ARM, BODY_ZONE_R_ARM, BODY_ZONE_L_LEG, BODY_ZONE_R_LEG)))
			cell(ware_type, "n/a (not in a limb)")
			continue
		// A body with no such limb is offered the chrome the real way.
		var/mob/living/carbon/human/maimed = allocate(/mob/living/carbon/human/consistent)
		var/obj/item/bodypart/gone = maimed.get_bodypart(zone)
		gone.drop_limb()
		qdel(gone)
		var/obj/item/organ/offered = allocate(ware_type)
		var/datum/component/cyberware/offered_chrome = offered.GetComponent(/datum/component/cyberware)
		offered_chrome.grant_install_context(maimed)
		var/list/problems = list()
		var/took = offered.Insert(maimed)
		if(took)
			problems += "it installed into a body with no [zone]"
		if(offered.owner || (offered in maimed.organs))
			problems += "a refused install still left it on the body"
		if(QDELETED(offered))
			problems += "a refused install destroyed it"
		else if(!isturf(offered.loc))
			problems += "a refused install left it in [offered.loc ? offered.loc.type : "nullspace"]"
		if(get_chrome_load(maimed) != 0)
			problems += "the maimed body carries load [get_chrome_load(maimed)] for chrome it does not hold"
		// Chrome in a limb that is then lost.
		var/list/wares = list()
		var/mob/living/carbon/human/body = fit(ware_type, wares)
		if(body)
			var/obj/item/organ/ware = wares[1]
			var/obj/item/arm_thing = arm_item(ware)
			var/obj/item/organ/cyberimp/arm/toolkit/cyberware/arm_ware = ware
			if(arm_thing)
				arm_ware.Extend(arm_thing)
			var/obj/item/bodypart/limb = body.get_bodypart(zone)
			limb.dismember()
			if(ware.owner)
				problems += "it stayed owned by a body that lost the limb"
			if(length(voidcrew_cyberware_held_traits(body, ware)))
				problems += "it still held traits on a body that lost the limb"
			if(get_chrome_load(body) != 0)
				problems += "the body kept load [get_chrome_load(body)] after the limb went"
			if(arm_thing && !QDELETED(arm_thing) && arm_thing.loc == body)
				problems += "the deployed weapon stayed in the hand of a body that lost the arm"
			qdel(limb)
			if(QDELETED(ware))
				problems += "burning up the limb destroyed it"
			qdel(body)
		if(length(problems))
			cell(ware_type, "FAIL: [problems[1]]")
			TEST_FAIL("[ware_type]: [english_list(problems)]")
		else
			cell(ware_type, "ok")
		qdel(maimed)

/// Pacifists: a body that cannot hurt anyone cannot hurt anyone with chrome either. Every
/// ware gets the usual ways to hurt: a punch or swing at an adjacent body, then each of its
/// buttons pointed at that body, then a few seconds for any leap to land.
/datum/unit_test/voidcrew_cyberware_matrix/pacifist
	column = "pacifist"

/datum/unit_test/voidcrew_cyberware_matrix/pacifist/Run()
	for(var/ware_type in voidcrew_cyberware_pool())
		var/list/wares = list()
		var/mob/living/carbon/human/body = fit(ware_type, wares)
		if(!body)
			cell(ware_type, "no home on a plain body")
			continue
		var/obj/item/organ/ware = wares[1]
		// A second window, so the click lands: the victim stands beside the body.
		var/mob/living/carbon/human/victim = allocate(/mob/living/carbon/human/consistent, get_step(body, EAST))
		ADD_TRAIT(body, TRAIT_PACIFISM, TRAIT_SOURCE_UNIT_TESTS)
		body.set_combat_mode(TRUE)
		body.face_atom(victim)
		var/obj/item/arm_thing = arm_item(ware)
		var/obj/item/organ/cyberimp/arm/toolkit/cyberware/arm_ware = ware
		if(arm_thing)
			arm_ware.Extend(arm_thing)
		click_wrapper(body, victim)
		var/launched = FALSE
		for(var/datum/action/cooldown/cyberware/ability as anything in buttons(ware))
			ability.Trigger(body, NONE, victim)
			if(ability.next_use_time > world.time)
				launched = TRUE
		click_wrapper(body, victim)
		if(launched)
			sleep(3 SECONDS)
		var/harm = victim.getBruteLoss() + victim.getFireLoss() + victim.getToxLoss() + victim.getOxyLoss() + victim.getStaminaLoss()
		var/knocked = victim.IsKnockdown() || victim.IsParalyzed() || victim.IsStun()
		if(harm > 0 || knocked)
			cell(ware_type, "FAIL: hurt someone while a pacifist ([harm] damage[knocked ? ", knocked down" : ""])")
			TEST_FAIL("[ware_type]: a pacifist hurt a bystander with it ([harm] damage[knocked ? ", knocked down" : ""])")
		else
			cell(ware_type, "ok")
		qdel(victim)
		qdel(body)

/// Moving and striking buttons refuse a body that is stunned, paralysed, immobilised or
/// riding a mech, and still work for a healthy one. Only the buttons that carry the bearer
/// across the floor or into a blow are walked: the rest are covered by the other columns.
/datum/unit_test/voidcrew_cyberware_matrix/incapacitated
	column = "stunned/mech"

/datum/unit_test/voidcrew_cyberware_matrix/incapacitated/Run()
	var/static/list/movers = list(
		/datum/action/cooldown/cyberware/hopper_leap,
		/datum/action/cooldown/cyberware/piledriver_leap,
		/datum/action/cooldown/cyberware/mantis_lunge,
		/datum/action/cooldown/cyberware/skyhook,
	)
	for(var/ware_type in voidcrew_cyberware_pool())
		var/list/wares = list()
		var/mob/living/carbon/human/body = fit(ware_type, wares)
		if(!body)
			continue
		var/obj/item/organ/ware = wares[1]
		var/list/walked = list()
		for(var/datum/action/cooldown/cyberware/ability as anything in buttons(ware))
			for(var/mover_type in movers)
				if(istype(ability, mover_type))
					walked += ability
		if(!length(walked))
			qdel(body)
			continue
		var/turf/start = get_turf(body)
		var/mob/living/carbon/human/victim = allocate(/mob/living/carbon/human/consistent, locate(start.x, start.y + 2, start.z))
		var/obj/item/arm_thing = arm_item(ware)
		var/obj/item/organ/cyberimp/arm/toolkit/cyberware/arm_ware = ware
		var/turf/landing = locate(start.x + 3, start.y, start.z)
		var/turf/far_wall = locate(start.x, start.y + 5, start.z)
		for(var/datum/action/cooldown/cyberware/ability as anything in walked)
			var/list/results = list()
			for(var/condition in list("healthy", "stunned", "paralyzed", "immobilized", "cuffed", "in a mech"))
				body.forceMove(start)
				body.SetStun(0)
				body.SetParalyzed(0)
				body.SetImmobilized(0)
				body.set_handcuffed(null)
				// The blade comes out while the body is still well.
				if(arm_thing && !arm_ware.active_item)
					arm_ware.Extend(arm_thing)
				var/obj/vehicle/sealed/mecha/ripley/mech
				switch(condition)
					if("stunned")
						body.Stun(30 SECONDS)
					if("paralyzed")
						body.Paralyze(30 SECONDS)
					if("immobilized")
						body.Immobilize(30 SECONDS)
					if("cuffed")
						body.set_handcuffed(new /obj/item/restraints/handcuffs(body))
					if("in a mech")
						mech = new /obj/vehicle/sealed/mecha/ripley(start)
						mech.mob_enter(body, silent = TRUE)
				ability.next_use_time = 0
				ability.Trigger(body, NONE, victim)
				var/fired = ability.next_use_time > world.time
				if(!fired)
					ability.next_use_time = 0
					ability.Trigger(body, NONE, landing)
					fired = ability.next_use_time > world.time
				if(!fired)
					// The winch wants a wall: the far side of the room.
					ability.next_use_time = 0
					ability.Trigger(body, NONE, far_wall)
					fired = ability.next_use_time > world.time
				results[condition] = fired
				if(fired)
					sleep(2 SECONDS)
				if(mech)
					mech.mob_exit(body, silent = TRUE)
					qdel(mech)
				body.SetStun(0)
				body.SetParalyzed(0)
				body.SetImmobilized(0)
				body.set_handcuffed(null)
			var/list/line = list()
			for(var/condition in results)
				line += "[condition] [results[condition] ? "fires" : "refuses"]"
			if(!results["healthy"])
				// The fixture could not aim it; say so rather than pass quietly.
				cell("[ware_type] / [ability.type]", "inconclusive, did not fire for a healthy body")
				continue
			cell("[ware_type] / [ability.type]", english_list(line))
			for(var/condition in list("stunned", "paralyzed", "immobilized", "in a mech"))
				if(results[condition])
					TEST_FAIL("[ware_type] / [ability.type] fired for a body that is [condition]")
		qdel(victim)
		qdel(body)

/// A button aimed at its own bearer. Click abilities get clicked on yourself, and every one has
/// to take it without a runtime and without leaving the bearer worse for it than a refusal
/// would. (The Angler's barb used to run a line from the bearer to the bearer.)
/datum/unit_test/voidcrew_cyberware_matrix/self_click
	column = "self click"

/datum/unit_test/voidcrew_cyberware_matrix/self_click/Run()
	for(var/ware_type in voidcrew_cyberware_pool())
		var/list/wares = list()
		var/mob/living/carbon/human/body = fit(ware_type, wares)
		if(!body)
			continue
		var/obj/item/organ/ware = wares[1]
		var/obj/item/arm_thing = arm_item(ware)
		var/obj/item/organ/cyberimp/arm/toolkit/cyberware/arm_ware = ware
		if(arm_thing)
			arm_ware.Extend(arm_thing)
		var/turf/before = get_turf(body)
		for(var/datum/action/cooldown/cyberware/ability as anything in buttons(ware))
			ability.Trigger(body, NONE, body)
			// Whatever it did, it did not carry the bearer off or take the bearer apart.
			TEST_ASSERT(!QDELETED(body) && body.stat != DEAD, "[ware_type] / [ability.type] aimed at its own bearer killed or deleted them")
		if(ware_type in list(/obj/item/organ/cyberimp/arm/toolkit/cyberware/angler))
			TEST_ASSERT_EQUAL(get_turf(body), before, "The Angler's barb moved a bearer who fired it at themselves")
		cell(ware_type, "self click: ok")
		sleep(1)
		qdel(body)

/// Taking a ware out, either way, leaves nothing of it listening to the body it left.
/datum/unit_test/voidcrew_cyberware_matrix/listeners
	column = "removal"

/datum/unit_test/voidcrew_cyberware_matrix/listeners/Run()
	var/list/bare_state = voidcrew_cyberware_passive_state(allocate(/mob/living/carbon/human/consistent))
	for(var/ware_type in voidcrew_cyberware_pool())
		for(var/quick in list(FALSE, TRUE))
			var/list/wares = list()
			var/mob/living/carbon/human/body = fit(ware_type, wares)
			if(!body)
				if(!quick)
					cell(ware_type, "no home on a plain body")
				continue
			var/obj/item/organ/ware = wares[1]
			var/obj/item/arm_thing = arm_item(ware)
			var/obj/item/organ/cyberimp/arm/toolkit/cyberware/arm_ware = ware
			if(arm_thing)
				arm_ware.Extend(arm_thing)
			for(var/datum/action/cooldown/cyberware/ability as anything in buttons(ware))
				ability.Trigger(body, NONE, body)
			var/list/problems = list()
			ware.Remove(body, special = quick)
			var/list/stale = voidcrew_cyberware_stale_listeners(body)
			if(length(stale))
				problems += "left listening to the body it was pulled from: [english_list(stale)]"
			if(length(voidcrew_cyberware_held_traits(body, ware)))
				problems += "left traits on the body it was pulled from"
			if(length(body.actions))
				problems += "left [length(body.actions)] buttons on the body it was pulled from"
			if(arm_thing && arm_ware.active_item)
				problems += "still holds its deployed weapon after removal"
			if(body.click_intercept)
				problems += "left a targeting mode on the body it was pulled from"
			var/list/leaks = voidcrew_cyberware_state_diff(bare_state, voidcrew_cyberware_passive_state(body))
			if(length(leaks))
				problems += "left the body changed: [english_list(leaks)]"
			cell(ware_type, "[quick ? "quick" : "normal"] removal: [length(problems) ? "FAIL: [problems[1]]" : "ok"]")
			if(length(problems))
				TEST_FAIL("[ware_type] ([quick ? "quick" : "normal"] removal): [english_list(problems)]")
			qdel(ware)
			qdel(body)

/// Ship saves: a hull checkpoint rebuilds machinery and structures and wipes every loose item,
/// so chrome lying about on a ship is cleared like any other stock and bodies are never
/// kept. The one fitting is the cradle, which a saved ship must never rebuild.
/datum/unit_test/voidcrew_cyberware_matrix/ship_save
	column = "ship save"

/datum/unit_test/voidcrew_cyberware_matrix/ship_save/Run()
	var/obj/machinery/chrome_cradle/cradle = allocate(/obj/machinery/chrome_cradle)
	TEST_ASSERT(!outpost_checkpoint_saves(cradle), "A ship checkpoint would keep a chrome cradle")
	TEST_ASSERT_NULL(cradle.checkpoint_type(), "A chrome cradle has a type to be rebuilt as")
	cell("/obj/machinery/chrome_cradle", "not saved by a checkpoint")
	// Every chrome organ is a plain item, which the clear-out takes, and none of them is a
	// machine or a structure that the checkpoint would keep as a fitting.
	for(var/ware_type in voidcrew_cyberware_pool())
		TEST_ASSERT(ispath(ware_type, /obj/item/organ), "[ware_type] is not an organ item")
		TEST_ASSERT(!ispath(ware_type, /obj/machinery) && !ispath(ware_type, /obj/structure), "[ware_type] is a machine or structure")
	cell("every ware", "organ items: cleared with the loose stock, never kept")

/// The camo weave's own columns: what ends it.
/datum/unit_test/voidcrew_cyberware_matrix/camo
	column = "camo"

/datum/unit_test/voidcrew_cyberware_matrix/camo/Run()
	var/obj/item/organ/cyberimp/cyberware/ghostskin/weave
	for(var/weave_type in list(/obj/item/organ/cyberimp/cyberware/ghostskin, /obj/item/organ/cyberimp/cyberware/ghostskin/street))
		for(var/condition in list("emp", "brownout", "death", "stun", "paralyze", "cuffs", "mech", "zoom", "gib"))
			var/mob/living/carbon/human/body = allocate(/mob/living/carbon/human/consistent)
			weave = allocate(weave_type)
			weave.Insert(body, special = TRUE)
			weave.engage_camo(body)
			var/engaged = HAS_TRAIT(body, MATRIX_TRAIT_CAMO)
			var/obj/vehicle/sealed/mecha/ripley/mech
			switch(condition)
				if("emp")
					body.emp_act(EMP_HEAVY)
				if("brownout")
					var/obj/item/organ/cyberimp/cyberware/matrix_ballast/ballast = allocate(/obj/item/organ/cyberimp/cyberware/matrix_ballast)
					ballast.Insert(body, special = TRUE)
				if("death")
					body.death()
				if("stun")
					body.Stun(5 SECONDS)
				if("paralyze")
					body.Paralyze(5 SECONDS)
				if("cuffs")
					body.set_handcuffed(new /obj/item/restraints/handcuffs(body))
				if("mech")
					mech = new /obj/vehicle/sealed/mecha/ripley(get_turf(body))
					mech.mob_enter(body, silent = TRUE)
				if("zoom")
					var/obj/item/organ/eyes/robotic/cyberware/spyglass/eyes = allocate(/obj/item/organ/eyes/robotic/cyberware/spyglass)
					eyes.Insert(body, special = TRUE)
					eyes.engage_zoom(body)
				if("gib")
					body.gib()
			var/still = HAS_TRAIT(body, MATRIX_TRAIT_CAMO)
			cell("[weave_type]", "[condition]: camo [engaged ? "was on" : "never came on"], then [still ? "stayed on" : "dropped"]")
			if(weave_type == /obj/item/organ/cyberimp/cyberware/ghostskin)
				TEST_ASSERT(engaged, "Ghostskin would not engage on a healthy body")
				// Hard stops: a dark weave, a dead wearer, a stripped body.
				if(condition in list("emp", "brownout", "death", "gib"))
					TEST_ASSERT(!still, "Ghostskin stayed engaged through [condition]")
			else
				TEST_ASSERT(!engaged, "the street weave grants camo it should not")
			if(mech)
				mech.mob_exit(body, silent = TRUE)
				qdel(mech)
			qdel(body)
			qdel(weave)

/// Doing harm from inside the field drops it, whichever ware does the harm: a punch from a
/// fist that skips the ordinary attack chain, a lunge, a landing.
/datum/unit_test/voidcrew_cyberware_matrix/camo_harm
	column = "camo (harm)"

/datum/unit_test/voidcrew_cyberware_matrix/camo_harm/Run()
	for(var/ware_type in list(
		/obj/item/organ/cyberimp/cyberware/gorilla_arms,
		/obj/item/organ/cyberimp/cyberware/gorilla_arms/street,
		/obj/item/organ/cyberimp/cyberware/scrapper,
		/obj/item/organ/cyberimp/arm/toolkit/cyberware/mantis,
		/obj/item/organ/cyberimp/cyberware/piledriver,
	))
		var/mob/living/carbon/human/body = allocate(/mob/living/carbon/human/consistent)
		var/mob/living/carbon/human/victim = allocate(/mob/living/carbon/human/consistent, get_step(body, EAST))
		var/obj/item/organ/cyberimp/cyberware/ghostskin/weave = allocate(/obj/item/organ/cyberimp/cyberware/ghostskin)
		weave.Insert(body, special = TRUE)
		var/obj/item/organ/ware = allocate(ware_type)
		TEST_ASSERT(ware.Insert(body, special = TRUE), "[ware_type] would not install beside the weave")
		var/obj/item/organ/cyberimp/arm/toolkit/cyberware/arm_ware = ware
		if(istype(arm_ware))
			var/obj/item/blade = locate(/obj/item) in arm_ware.contents
			arm_ware.Extend(blade)
		body.set_combat_mode(TRUE)
		body.face_atom(victim)
		weave.engage_camo(body)
		TEST_ASSERT(HAS_TRAIT(body, MATRIX_TRAIT_CAMO), "Ghostskin would not engage for [ware_type]")
		if(ispath(ware_type, /obj/item/organ/cyberimp/cyberware/piledriver) || istype(arm_ware))
			for(var/datum/action/cooldown/cyberware/ability as anything in buttons(ware))
				ability.Trigger(body, NONE, victim)
		else
			click_wrapper(body, victim)
		var/dropped = !HAS_TRAIT(body, MATRIX_TRAIT_CAMO)
		cell("[ware_type]", "camo [dropped ? "dropped" : "stayed up"] when it hurt someone")
		if(!dropped)
			TEST_FAIL("[ware_type]: the field stayed up while the bearer attacked")
		if(ispath(ware_type, /obj/item/organ/cyberimp/cyberware/piledriver) || istype(arm_ware))
			sleep(3 SECONDS)
		qdel(body)
		qdel(victim)

#undef MATRIX_TRAIT_CAMO
#undef MATRIX_TRAIT_ZOOMED
#undef MATRIX_SLOT_SKIN
