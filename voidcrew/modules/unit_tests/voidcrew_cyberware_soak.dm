/**
 * # Chrome soak
 *
 * A long, loud, mostly random test for the cyberware module (voidcrew/modules/cyberware/).
 * Ten humans get random chrome loadouts and are then put through five minutes of game time of
 * everything players and the world do to chrome: every installed ability triggered (with real
 * targets, so click abilities fire), EMPs on bodies and on single pieces, forced brownouts,
 * cradle installs, removals and tune-ups, sell-backs at the ripperdoc ledgers, death and
 * revival, gibbing and dusting (chrome salvage), lost limbs, stuns, cuffs, pacifism, zoom,
 * a ride in a mech, speech. A sweep every two seconds checks that the ware's own bookkeeping
 * stays consistent. At the end the survivors are healed, stripped of chrome, left alone and
 * compared against a snapshot taken before they got any, and everything the soak made is
 * deleted and checked for being garbage collected.
 *
 * It is a SOAK, not a regression test: it fails on any runtime (the error handler fails
 * whichever test is running, see docs/UNIT_TESTING_LOCAL.md), on any inconsistency the sweep
 * finds, and on anything left behind. It is also slow, so it extends voidcrew_opt_in and is
 * left out of a general run. Run it on its own:
 *
 *   dd.exe tgstation.dmb -port <free port> -close -trusted -invisible \
 *     -params "log-directory=ci&test_only=/datum/unit_test/voidcrew_opt_in/cyberware_soak"
 *
 * Optional world params: soak_length (deciseconds of storm, default 3000) and soak_seed
 * (a number, to repeat a roll of the dice). The report is also written to data/soak_report.txt.
 *
 * Unit-test files compile before voidcrew/_DEFINES/, so the fork defines this file needs are
 * restated below under SOAK_ names.
 */

/// ORGAN_SLOT_CYBERWARE_SKIN, the Ghostskin slot.
#define SOAK_SLOT_SKIN "cyberware_skin"
/// TRAIT_CYBER_CAMO and TRAIT_CYBER_ZOOMED.
#define SOAK_TRAIT_CAMO "cyber_camo"
#define SOAK_TRAIT_ZOOMED "cyber_zoomed"
/// CYBERWARE_INSTALL_TIME, CYBERWARE_REMOVAL_TIME, CYBERWARE_EMP_DOWNTIME and CYBERWARE_TUNEUP_FEE.
#define SOAK_INSTALL_TIME (4 SECONDS)
#define SOAK_REMOVAL_TIME (3 SECONDS)
#define SOAK_EMP_DOWNTIME (9 SECONDS)
#define SOAK_TUNEUP_FEE 200
/// How long an inconsistency must hold before the sweep calls it a bug. SSmobs ticks every
/// two seconds and the ware's per-tick settle runs on it, so anything shorter is a race.
#define SOAK_PATIENCE (6 SECONDS)

/// Ballast for forcing a brownout: far over any body's capacity, in a slot nothing else uses,
/// with no ability of its own.
/obj/item/organ/cyberimp/cyberware/soak_ballast
	name = "soak ballast"
	zone = BODY_ZONE_CHEST
	slot = "voidcrew_soak_ballast"
	chrome_load = 25

/datum/unit_test/voidcrew_opt_in/cyberware_soak
	priority = TEST_LONGER
	/// Game time the storm runs for.
	var/storm_length = 3000
	/// Bodies kept in play.
	var/crew_size = 10
	/// FALSE once the storm is over, so late async events stand down.
	var/storming = FALSE
	/// Live bodies.
	var/list/crew = list()
	/// Body -> its snapshot from before it had any chrome.
	var/list/baselines = list()
	/// Chrome that came off a body or out of a gib and lies about, for the cradle to reinstall.
	var/list/loose_chrome = list()
	/// Weakrefs to everything this test made that must be collected at the end.
	var/list/made = list()
	/// Every installable chrome typepath.
	var/list/ware_pool = list()
	/// Floor turfs in the room.
	var/list/floor_turfs = list()
	/// Splice's ledgers (the street doc's are the same entries with other words).
	var/list/ledgers = list()
	/// Problem category -> how many times it was seen.
	var/list/problem_counts = list()
	/// Problem category -> the first example.
	var/list/problem_examples = list()
	/// Counters for the report.
	var/list/stats = list()
	/// Sweep keys seen in this sweep.
	var/list/seen_now = list()
	/// Sweep key -> world.time it was first seen.
	var/list/suspects = list()
	/// Sweep keys already reported.
	var/list/reported = list()
	var/obj/machinery/chrome_cradle/cradle
	/// The cradle is single-use at a time; this is the world.time its current user lets go.
	var/cradle_lease = 0
	var/mech_lease = 0
	var/next_index = 0
	var/runtimes_at_start = 0
	var/skipped_runtimes_at_start = 0
	var/timers_at_start = 0
	/// SSgarbage failure and hard-delete counts per type before the storm.
	var/list/gc_before = list()

// ---- Bookkeeping ---------------------------------------------------------

/datum/unit_test/voidcrew_opt_in/cyberware_soak/proc/note(category, detail)
	problem_counts[category] = (problem_counts[category] || 0) + 1
	if(!problem_examples[category])
		problem_examples[category] = detail
		log_world("SOAK PROBLEM: [category]: [detail]")

/datum/unit_test/voidcrew_opt_in/cyberware_soak/proc/count(what, amount = 1)
	stats[what] = (stats[what] || 0) + amount

/datum/unit_test/voidcrew_opt_in/cyberware_soak/proc/track(datum/thing)
	made += WEAKREF(thing)
	return thing

/// A sweep finding that only counts once it has held for `patience`.
/datum/unit_test/voidcrew_opt_in/cyberware_soak/proc/suspect(key, category, detail, patience = SOAK_PATIENCE)
	seen_now[key] = TRUE
	if(!suspects[key])
		suspects[key] = world.time
		return
	if(world.time - suspects[key] >= patience && !reported[key])
		reported[key] = TRUE
		note(category, detail)

/datum/unit_test/voidcrew_opt_in/cyberware_soak/proc/rng_seed()
	var/seed = text2num(world.params["soak_seed"])
	if(isnull(seed))
		seed = rand(1, 999999)
	rand_seed(seed)
	log_world("SOAK seed [seed]")
	return seed

// ---- Setup ---------------------------------------------------------------

/datum/unit_test/voidcrew_opt_in/cyberware_soak/proc/build_pool()
	ware_pool = voidcrew_cyberware_pool().Copy()
	TEST_ASSERT(length(ware_pool) > 40, "The chrome pool is only [length(ware_pool)] types, the walk of the subtypes found too little")

/datum/unit_test/voidcrew_opt_in/cyberware_soak/proc/build_room()
	var/turf/low = run_loc_floor_bottom_left
	var/turf/high = run_loc_floor_top_right
	for(var/x in min(low.x, high.x) to max(low.x, high.x))
		for(var/y in min(low.y, high.y) to max(low.y, high.y))
			var/turf/candidate = locate(x, y, low.z)
			// The cradle's tile lifts whoever stands on it, which would be part of a snapshot.
			if(isfloorturf(candidate) && candidate != run_loc_floor_top_right)
				floor_turfs += candidate
	TEST_ASSERT(length(floor_turfs) >= 12, "The test room only has [length(floor_turfs)] floor tiles")

/// A fresh body. It stands bare for a few seconds first, so the snapshot it is later compared
/// with already has the modifiers every body picks up on its own (mood, for one).
/datum/unit_test/voidcrew_opt_in/cyberware_soak/proc/spawn_body()
	next_index++
	var/index = next_index
	var/mob/living/carbon/human/body = new /mob/living/carbon/human/consistent(pick(floor_turfs))
	track(body)
	body.fully_replace_character_name(body.real_name, "Soak [index]")
	var/obj/item/card/id/id = new(body)
	id.registered_account = allocate(/datum/bank_account, "Soak [index]", null, 1, FALSE)
	id.registered_account.account_balance = 50000
	body.equip_to_slot_or_del(id, ITEM_SLOT_ID)
	body.equip_to_slot_or_del(new /obj/item/clothing/under/color/grey(body), ITEM_SLOT_ICLOTHING)
	sleep(6 SECONDS)
	if(QDELETED(body) || !storming)
		return body
	baselines[body] = snapshot(body)
	crew += body
	random_loadout(body)
	return body

/// A random set of chrome in a random body. Most bodies fit their load; some are loaded
/// past capacity on purpose and start browned out.
/datum/unit_test/voidcrew_opt_in/cyberware_soak/proc/random_loadout(mob/living/carbon/human/body)
	var/overshoot = prob(25) ? rand(1, 8) : 0
	var/pieces = rand(2, 7)
	var/list/candidates = shuffle(ware_pool.Copy())
	for(var/ware_type in candidates)
		if(pieces <= 0)
			break
		var/obj/item/organ/ware = track(new ware_type(get_turf(body)))
		if(!body.get_bodypart(deprecise_zone(ware.zone)))
			qdel(ware)
			continue
		var/datum/component/cyberware/chrome = ware.GetComponent(/datum/component/cyberware)
		var/list/incumbents = ware.cyberware_get_incumbents(body)
		// Keep most loadouts free of evictions, they are not what is being tested here.
		if(length(incumbents) && prob(85))
			qdel(ware)
			continue
		var/projected = get_chrome_load(body) + (chrome?.chrome_load || 0)
		for(var/obj/item/organ/incumbent in incumbents)
			projected -= get_installed_capacity_cost(incumbent)
		if(projected > get_chrome_capacity(body) + (chrome?.capacity_bonus || 0) + overshoot)
			qdel(ware)
			continue
		if(!ware.Insert(body, special = TRUE))
			qdel(ware)
			continue
		pieces--
		count("pieces installed")

/// Everything that should be back to normal once a body has no chrome and has been left alone.
/datum/unit_test/voidcrew_opt_in/cyberware_soak/proc/snapshot(mob/living/carbon/human/body)
	var/list/snap = list()
	snap["filters"] = length(body.filters)
	snap["actions"] = length(body.actions)
	snap["vis_contents"] = length(body.vis_contents)
	var/list/statuses = list()
	for(var/datum/status_effect/effect as anything in body.status_effects)
		statuses += "[effect.type]"
	snap["status effects"] = statuses
	var/list/traits = list()
	for(var/trait in body._status_traits)
		traits[trait] = length(body._status_traits[trait])
	snap["traits"] = traits
	var/list/speed = list()
	for(var/modifier in body.movespeed_modification)
		speed += "[modifier]"
	snap["movespeed"] = speed
	var/list/action_speed = list()
	for(var/modifier in body.actionspeed_modification)
		// Mood's own modifier arrives on its own schedule.
		if(!findtext("[modifier]", "sanity_component"))
			action_speed += "[modifier]"
	snap["actionspeed"] = action_speed
	var/list/physiology = list()
	for(var/var_name in body.physiology.vars)
		var/value = body.physiology.vars[var_name]
		if(isnum(value))
			physiology[var_name] = value
	for(var/rating in ARMOR_LIST_ALL())
		physiology["armor [rating]"] = body.physiology.armor.get_rating(rating)
	snap["physiology"] = physiology
	var/list/components = list()
	for(var/component_type in body._datum_components)
		components += "[component_type]"
	snap["components"] = components
	var/list/loose = list()
	for(var/atom/movable/thing as anything in body.contents)
		if(isorgan(thing) || isbodypart(thing) || istype(thing, /obj/item/clothing) || istype(thing, /obj/item/card/id))
			continue
		loose += "[thing.type]"
	snap["carried"] = loose
	var/list/held = list()
	for(var/obj/item/thing in body.held_items)
		held += "[thing.type]"
	snap["held"] = held
	snap["intercept"] = body.click_intercept ? "[body.click_intercept.type]" : null
	return snap

/datum/unit_test/voidcrew_opt_in/cyberware_soak/Run()
	rng_seed()
	var/length_param = text2num(world.params["soak_length"])
	if(length_param)
		storm_length = length_param
	runtimes_at_start = GLOB.total_runtimes
	skipped_runtimes_at_start = GLOB.total_runtimes_skipped
	timers_at_start = length(SStimer.timer_id_dict)
	for(var/gc_type in SSgarbage.items)
		var/datum/qdel_item/item = SSgarbage.items[gc_type]
		gc_before[gc_type] = list(item.failures, item.hard_deletes)

	build_pool()
	build_room()
	for(var/ledger_type in typesof(/datum/shop_buyback/ripperdoc) - /datum/shop_buyback/ripperdoc)
		// Ratchet's entries are the same ledger in other words.
		if(findtext("[ledger_type]", "/street_doc"))
			continue
		ledgers += allocate(ledger_type)
	cradle = track(new /obj/machinery/chrome_cradle(run_loc_floor_top_right))
	storming = TRUE
	for(var/i in 1 to crew_size)
		INVOKE_ASYNC(src, PROC_REF(spawn_body))
	sleep(8 SECONDS)
	// Two bodies are pacifists for the whole storm.
	for(var/i in 1 to min(2, length(crew)))
		var/mob/living/carbon/human/pacifist = crew[i]
		ADD_TRAIT(pacifist, TRAIT_PACIFISM, "soak")

	var/end_time = world.time + storm_length
	var/next_sweep = world.time
	var/next_heal = world.time + 20 SECONDS
	while(world.time < end_time)
		sleep(1 SECONDS)
		storm_tick()
		if(world.time >= next_sweep)
			next_sweep = world.time + 2 SECONDS
			sweep()
		if(world.time >= next_heal)
			next_heal = world.time + 20 SECONDS
			top_up()
	storming = FALSE
	// Let the long events (a death waiting to revive, a brownout waiting to lift, a cradle
	// sequence) finish before anyone looks at the wreckage.
	sleep(15 SECONDS)
	sweep()
	sweep()

	audit_survivors()
	var/list/leaks = clean_up()
	report(leaks)

// ---- The storm -----------------------------------------------------------

/datum/unit_test/voidcrew_opt_in/cyberware_soak/proc/storm_tick()
	var/static/list/event_weights = list(
		"trigger" = 30, "swing" = 12, "wheel" = 4, "emp" = 8, "emp_one" = 4, "brownout" = 6,
		"cradle" = 5, "sell" = 3, "kill" = 5, "gib" = 2, "dust" = 1, "dismember" = 5, "stun" = 6,
		"cuff" = 3, "pacifist" = 2, "zoom" = 6, "damage" = 4, "mech" = 2, "speak" = 2, "swap" = 4,
	)
	for(var/mob/living/carbon/human/body as anything in crew.Copy())
		if(QDELETED(body))
			crew -= body
			baselines -= body
			INVOKE_ASYNC(src, PROC_REF(spawn_body))
			continue
		if(!prob(35))
			continue
		switch(pick_weight(event_weights))
			if("trigger")
				INVOKE_ASYNC(src, PROC_REF(ev_trigger), body)
			if("swing")
				INVOKE_ASYNC(src, PROC_REF(ev_swing), body)
			if("wheel")
				INVOKE_ASYNC(src, PROC_REF(ev_wheel), body)
			if("emp")
				INVOKE_ASYNC(src, PROC_REF(ev_emp), body)
			if("emp_one")
				INVOKE_ASYNC(src, PROC_REF(ev_emp_one), body)
			if("brownout")
				INVOKE_ASYNC(src, PROC_REF(ev_brownout), body)
			if("cradle")
				INVOKE_ASYNC(src, PROC_REF(ev_cradle), body)
			if("sell")
				INVOKE_ASYNC(src, PROC_REF(ev_sell), body)
			if("kill")
				INVOKE_ASYNC(src, PROC_REF(ev_kill), body)
			if("gib")
				INVOKE_ASYNC(src, PROC_REF(ev_gib), body, FALSE)
			if("dust")
				INVOKE_ASYNC(src, PROC_REF(ev_gib), body, TRUE)
			if("dismember")
				INVOKE_ASYNC(src, PROC_REF(ev_dismember), body)
			if("stun")
				INVOKE_ASYNC(src, PROC_REF(ev_stun), body)
			if("cuff")
				INVOKE_ASYNC(src, PROC_REF(ev_cuff), body)
			if("pacifist")
				INVOKE_ASYNC(src, PROC_REF(ev_pacifist), body)
			if("zoom")
				INVOKE_ASYNC(src, PROC_REF(ev_zoom), body)
			if("damage")
				INVOKE_ASYNC(src, PROC_REF(ev_damage), body)
			if("mech")
				INVOKE_ASYNC(src, PROC_REF(ev_mech), body)
			if("speak")
				INVOKE_ASYNC(src, PROC_REF(ev_speak), body)
			if("swap")
				INVOKE_ASYNC(src, PROC_REF(ev_swap), body)

/// Something for an ability to be pointed at.
/datum/unit_test/voidcrew_opt_in/cyberware_soak/proc/some_target(mob/living/carbon/human/body)
	var/roll = rand(1, 10)
	if(roll <= 5)
		var/list/others = crew - body
		for(var/mob/living/carbon/human/other as anything in others.Copy())
			if(QDELETED(other))
				others -= other
		if(length(others))
			return pick(others)
	if(roll <= 7 && !QDELETED(cradle))
		return cradle
	// A click on yourself is a click like any other, and every button has to take it.
	if(roll == 10)
		return body
	return pick(floor_turfs)

/// Every installed ability, pointed at something.
/datum/unit_test/voidcrew_opt_in/cyberware_soak/proc/ev_trigger(mob/living/carbon/human/body)
	if(!storming || QDELETED(body))
		return
	for(var/obj/item/organ/ware as anything in get_installed_cyberware(body))
		for(var/datum/action/ability as anything in LAZYCOPY(ware.actions))
			if(QDELETED(ability) || ability.owner != body)
				continue
			// Cooldowns would stop most of these after the first press.
			if(istype(ability, /datum/action/cooldown) && prob(60))
				var/datum/action/cooldown/timed = ability
				timed.next_use_time = 0
			count("ability presses")
			INVOKE_ASYNC(ability, TYPE_PROC_REF(/datum/action, Trigger), body, NONE, some_target(body))

/// A melee swing or a shot, through the real click path, with whatever is in the hands.
/datum/unit_test/voidcrew_opt_in/cyberware_soak/proc/ev_swing(mob/living/carbon/human/body)
	if(!storming || QDELETED(body))
		return
	body.set_combat_mode(TRUE)
	count("clicks")
	click_wrapper(body, some_target(body))

/// The chrome wheel's Use OS chrome, the one wheel path that needs no screen.
/datum/unit_test/voidcrew_opt_in/cyberware_soak/proc/ev_wheel(mob/living/carbon/human/body)
	if(!storming || QDELETED(body))
		return
	var/datum/component/chrome_wheel/wheel = get_chrome_wheel(body)
	if(!wheel)
		return
	body.next_click = 0
	count("wheel presses")
	wheel.use_os()

/datum/unit_test/voidcrew_opt_in/cyberware_soak/proc/ev_emp(mob/living/carbon/human/body)
	if(!storming || QDELETED(body))
		return
	count("body emps")
	body.emp_act(prob(50) ? EMP_HEAVY : EMP_LIGHT)

/datum/unit_test/voidcrew_opt_in/cyberware_soak/proc/ev_emp_one(mob/living/carbon/human/body)
	if(!storming || QDELETED(body))
		return
	var/list/installed = get_installed_cyberware(body)
	if(!length(installed))
		return
	var/obj/item/organ/ware = pick(installed)
	count("piece emps")
	ware.emp_act(prob(50) ? EMP_HEAVY : EMP_LIGHT)

/datum/unit_test/voidcrew_opt_in/cyberware_soak/proc/ev_brownout(mob/living/carbon/human/body)
	if(!storming || QDELETED(body))
		return
	var/obj/item/organ/cyberimp/cyberware/soak_ballast/ballast = new /obj/item/organ/cyberimp/cyberware/soak_ballast(get_turf(body))
	track(ballast)
	if(!ballast.Insert(body, special = TRUE))
		qdel(ballast)
		return
	count("brownouts")
	sleep(rand(3 SECONDS, 9 SECONDS))
	if(QDELETED(ballast))
		return
	if(ballast.owner)
		ballast.Remove(ballast.owner, special = TRUE)
	qdel(ballast)

/// A cradle visit: lie down, then install something, take something out, or tune up.
/datum/unit_test/voidcrew_opt_in/cyberware_soak/proc/ev_cradle(mob/living/carbon/human/body)
	if(!storming || QDELETED(body) || QDELETED(cradle) || cradle_lease > world.time || !isturf(body.loc))
		return
	cradle_lease = world.time + 14 SECONDS
	body.forceMove(get_turf(cradle))
	if(!cradle.buckle_mob(body, force = TRUE, check_loc = FALSE))
		cradle_lease = 0
		return
	var/list/installed = get_installed_cyberware(body)
	var/roll = rand(1, 10)
	if(roll <= 2)
		count("tune-ups")
		var/obj/item/card/id/id = body.get_idcard(TRUE)
		var/before = id?.registered_account?.account_balance
		cradle.try_tune_up(body)
		var/after = id?.registered_account?.account_balance
		if(!isnull(before) && before != after && before - after != SOAK_TUNEUP_FEE)
			note("tune-up charged the wrong fee", "balance went from [before] to [after]")
	else if(roll <= 5 && length(installed))
		count("cradle removals")
		cradle.begin_removal(pick(installed))
		sleep(SOAK_REMOVAL_TIME + 1 SECONDS)
	else
		// A used piece from the floor when there is one, otherwise a fresh one.
		var/obj/item/organ/ware
		if(length(loose_chrome) && prob(50))
			ware = pick(loose_chrome)
			loose_chrome -= ware
		if(QDELETED(ware))
			ware = null
			for(var/attempt in 1 to 8)
				var/candidate_type = pick(ware_pool)
				var/obj/item/organ/candidate = track(new candidate_type(get_turf(cradle)))
				if(cyberware_insert_check(candidate, body, silent = TRUE))
					ware = candidate
					break
				qdel(candidate)
		if(ware)
			count("cradle installs")
			ware.forceMove(cradle)
			cradle.begin_install(ware)
			sleep(SOAK_INSTALL_TIME + 1 SECONDS)
	if(!QDELETED(body) && body.buckled == cradle)
		cradle.unbuckle_mob(body, force = TRUE)
	cradle_lease = 0

/// A sale at Splice's ledger: pull a credit-priced piece and hand it over.
/datum/unit_test/voidcrew_opt_in/cyberware_soak/proc/ev_sell(mob/living/carbon/human/body)
	if(!storming || QDELETED(body))
		return
	var/obj/item/card/id/id = body.get_idcard(TRUE)
	if(!id?.registered_account)
		return
	for(var/obj/item/organ/ware as anything in shuffle(get_installed_cyberware(body)))
		for(var/datum/shop_buyback/ledger as anything in ledgers)
			if(!ledger.matches(ware))
				continue
			ledger.demand = 50
			ware.Remove(body, special = TRUE)
			body.put_in_hands(ware)
			var/before = id.registered_account.account_balance
			var/sold = ledger.try_sell(body, null)
			var/gained = id.registered_account.account_balance - before
			if(sold)
				count("sell-backs")
				if(gained != ledger.pay_credits)
					note("sell-back paid the wrong amount", "[ware.type] paid [gained], the ledger says [ledger.pay_credits]")
			else
				if(gained)
					note("a refused sell-back still paid", "[ware.type] paid [gained]")
				// Not taken: it goes back on the floor for the cradle.
				loose_chrome += ware
				ware.forceMove(get_turf(body))
			return

/datum/unit_test/voidcrew_opt_in/cyberware_soak/proc/ev_kill(mob/living/carbon/human/body)
	if(!storming || QDELETED(body) || body.stat == DEAD)
		return
	count("deaths")
	body.death()
	sleep(rand(2 SECONDS, 9 SECONDS))
	if(QDELETED(body))
		return
	body.revive(HEAL_ALL)
	count("revives")

/// Gib or dust a body. Its chrome must come out whole; a fresh body takes its place.
/datum/unit_test/voidcrew_opt_in/cyberware_soak/proc/ev_gib(mob/living/carbon/human/body, dust = FALSE)
	if(!storming || QDELETED(body))
		return
	var/list/pieces = get_installed_cyberware(body)
	// The ballast belongs to its own event, which deletes it when it is done.
	for(var/obj/item/organ/ware as anything in pieces.Copy())
		if(istype(ware, /obj/item/organ/cyberimp/cyberware/soak_ballast))
			pieces -= ware
	count(dust ? "dustings" : "gibs")
	crew -= body
	baselines -= body
	if(dust)
		body.dust()
	else
		body.gib()
	sleep(1 SECONDS)
	for(var/obj/item/organ/ware as anything in pieces)
		if(QDELETED(ware))
			note("gibbing destroyed a piece of chrome", "[ware.type]")
			continue
		if(ware.owner)
			note("gibbed chrome is still owned by the corpse", "[ware.type]")
			continue
		if(!isturf(ware.loc))
			note("gibbed chrome did not land on the floor", "[ware.type] is in [ware.loc ? ware.loc.type : "nullspace"]")
			continue
		count("pieces salvaged")
		loose_chrome += ware
	spawn_body()

/datum/unit_test/voidcrew_opt_in/cyberware_soak/proc/ev_dismember(mob/living/carbon/human/body)
	if(!storming || QDELETED(body))
		return
	var/obj/item/bodypart/limb = body.get_bodypart(pick(BODY_ZONE_L_ARM, BODY_ZONE_R_ARM, BODY_ZONE_L_LEG, BODY_ZONE_R_LEG))
	if(!limb || !limb.dismember())
		return
	count("limbs lost")
	var/list/riders = list()
	for(var/obj/item/organ/ware in limb)
		riders += ware
	if(prob(40))
		// Burned up on the floor: the chrome has to come out of it.
		sleep(1 SECONDS)
		qdel(limb)
		for(var/obj/item/organ/ware as anything in riders)
			if(QDELETED(ware))
				note("destroying a severed limb destroyed its chrome", "[ware.type]")
			else if(!isturf(ware.loc))
				note("chrome from a destroyed limb did not land on the floor", "[ware.type] is in [ware.loc ? ware.loc.type : "nullspace"]")
			else
				loose_chrome += ware
	sleep(rand(3 SECONDS, 10 SECONDS))
	if(!QDELETED(body))
		body.regenerate_limbs()

/datum/unit_test/voidcrew_opt_in/cyberware_soak/proc/ev_stun(mob/living/carbon/human/body)
	if(!storming || QDELETED(body))
		return
	count("stuns")
	switch(rand(1, 3))
		if(1)
			body.Paralyze(rand(1 SECONDS, 5 SECONDS))
		if(2)
			body.Stun(rand(1 SECONDS, 4 SECONDS))
		if(3)
			body.Knockdown(rand(1 SECONDS, 4 SECONDS))

/datum/unit_test/voidcrew_opt_in/cyberware_soak/proc/ev_cuff(mob/living/carbon/human/body)
	if(!storming || QDELETED(body) || body.handcuffed)
		return
	var/obj/item/restraints/handcuffs/cuffs = new(body)
	body.set_handcuffed(cuffs)
	count("cuffings")
	sleep(rand(3 SECONDS, 8 SECONDS))
	if(!QDELETED(body) && body.handcuffed == cuffs)
		body.set_handcuffed(null)
	qdel(cuffs)

/datum/unit_test/voidcrew_opt_in/cyberware_soak/proc/ev_pacifist(mob/living/carbon/human/body)
	if(!storming || QDELETED(body))
		return
	// The first two bodies keep it for the whole storm.
	if(crew.Find(body) <= 2)
		return
	if(HAS_TRAIT_FROM(body, TRAIT_PACIFISM, "soak"))
		REMOVE_TRAIT(body, TRAIT_PACIFISM, "soak")
	else
		ADD_TRAIT(body, TRAIT_PACIFISM, "soak")
	count("pacifism flips")

/// Optics zoom. There is no client for tg's scope, so the optics' own half is driven.
/datum/unit_test/voidcrew_opt_in/cyberware_soak/proc/ev_zoom(mob/living/carbon/human/body)
	if(!storming || QDELETED(body))
		return
	var/obj/item/organ/eyes/robotic/cyberware/optics = body.get_organ_slot(ORGAN_SLOT_EYES)
	if(!istype(optics))
		return
	count("zoom flips")
	if(optics.is_zoomed())
		optics.stop_zoom(body)
		return
	var/datum/component/cyberware/chrome = optics.GetComponent(/datum/component/cyberware)
	if(chrome?.is_running() && body.stat == CONSCIOUS)
		optics.engage_zoom(body)

/// Damage on a piece until it fails, then it is repaired a moment later.
/datum/unit_test/voidcrew_opt_in/cyberware_soak/proc/ev_damage(mob/living/carbon/human/body)
	if(!storming || QDELETED(body))
		return
	var/list/installed = get_installed_cyberware(body)
	if(!length(installed))
		return
	var/obj/item/organ/ware = pick(installed)
	count("damaged pieces")
	ware.apply_organ_damage(ware.maxHealth)
	sleep(rand(2 SECONDS, 7 SECONDS))
	if(!QDELETED(ware))
		ware.set_organ_damage(0)

/// A short ride in a mech, with the abilities going the whole time.
/datum/unit_test/voidcrew_opt_in/cyberware_soak/proc/ev_mech(mob/living/carbon/human/body)
	if(!storming || QDELETED(body) || mech_lease > world.time || !isturf(body.loc))
		return
	mech_lease = world.time + 12 SECONDS
	var/obj/vehicle/sealed/mecha/ripley/mech = new /obj/vehicle/sealed/mecha/ripley(get_turf(body))
	track(mech)
	if(!mech.mob_enter(body, silent = TRUE))
		qdel(mech)
		mech_lease = 0
		return
	count("mech rides")
	for(var/i in 1 to 4)
		sleep(1 SECONDS)
		if(QDELETED(body) || body.loc != mech)
			break
		ev_trigger(body)
		ev_swing(body)
	if(!QDELETED(body) && body.loc == mech)
		mech.mob_exit(body, silent = TRUE)
	qdel(mech)
	mech_lease = 0

/datum/unit_test/voidcrew_opt_in/cyberware_soak/proc/ev_speak(mob/living/carbon/human/body)
	// A dead mouth goes to deadchat, which asks for a ckey this test body never has.
	if(!storming || QDELETED(body) || body.stat == DEAD)
		return
	count("lines spoken")
	body.say(prob(50) ? ";soak check, over" : "soak check")

/// Chrome in or out by hand: what an autosurgeon with a context, a surgeon or an admin does.
/datum/unit_test/voidcrew_opt_in/cyberware_soak/proc/ev_swap(mob/living/carbon/human/body)
	if(!storming || QDELETED(body))
		return
	var/list/installed = get_installed_cyberware(body)
	if(length(installed) && prob(50))
		var/obj/item/organ/ware = pick(installed)
		ware.Remove(body, special = TRUE)
		ware.forceMove(get_turf(body))
		loose_chrome += ware
		count("pieces pulled")
		return
	var/candidate_type = pick(ware_pool)
	var/obj/item/organ/ware = track(new candidate_type(get_turf(body)))
	if(!body.get_bodypart(deprecise_zone(ware.zone)) || !cyberware_insert_check(ware, body, silent = TRUE) || !ware.Insert(body, special = TRUE))
		qdel(ware)
		return
	count("pieces slotted")

/// Keeps the bodies fit enough to keep going without undoing the chrome's own state.
/datum/unit_test/voidcrew_opt_in/cyberware_soak/proc/top_up()
	for(var/mob/living/carbon/human/body as anything in crew)
		if(QDELETED(body) || body.stat == DEAD)
			continue
		body.adjustBruteLoss(-60, updating_health = FALSE, forced = TRUE)
		body.adjustFireLoss(-60, updating_health = FALSE, forced = TRUE)
		body.adjustToxLoss(-30, updating_health = FALSE, forced = TRUE)
		body.adjustOxyLoss(-60, updating_health = FALSE, forced = TRUE)
		body.updatehealth()

// ---- The sweep -----------------------------------------------------------

/// Checks the ware's own bookkeeping on every body. Each finding has to hold for a while
/// before it counts, because the ware settles itself on SSmobs' two-second tick.
/datum/unit_test/voidcrew_opt_in/cyberware_soak/proc/sweep()
	seen_now = list()
	for(var/mob/living/carbon/human/body as anything in crew)
		if(QDELETED(body))
			continue
		var/over = get_chrome_load(body) > get_chrome_capacity(body)
		for(var/obj/item/organ/ware as anything in get_installed_cyberware(body))
			var/datum/component/cyberware/chrome = ware.GetComponent(/datum/component/cyberware)
			if(!chrome)
				continue
			var/ware_ref = REF(ware)
			if(ware.owner != body)
				suspect("[ware_ref]|owner", "installed chrome whose owner is not its bearer", "[ware.type] owner [ware.owner || "none"] in [body]")
			var/running = !!chrome.is_running()
			if(!!chrome.passives_online != running)
				suspect("[ware_ref]|passives", "passive layer out of step with the ware", "[ware.type] passives_online [chrome.passives_online], running [running] (emp [chrome.emp_down], brownout [chrome.browned_out], damage [ware.damage]/[ware.maxHealth], flags [ware.organ_flags])")
			if(!!chrome.browned_out != over)
				suspect("[ware_ref]|brownout", "brownout flag out of step with the body's load", "[ware.type] browned_out [chrome.browned_out], load [get_chrome_load(body)] of [get_chrome_capacity(body)]")
			if(chrome.emp_down && !chrome.emp_timer)
				suspect("[ware_ref]|emptimer", "EMP downtime with no reboot timer", "[ware.type]")
			if(chrome.emp_down)
				suspect("[ware_ref]|empstuck", "EMP downtime that never ended", "[ware.type] still down", SOAK_EMP_DOWNTIME + 8 SECONDS)
			if(istype(ware, /obj/item/organ/cyberimp/arm/toolkit/cyberware))
				var/obj/item/organ/cyberimp/arm/toolkit/cyberware/arm = ware
				if(arm.active_item && !running && arm.active_item.loc == body)
					suspect("[ware_ref]|armweapon", "arm weapon deployed on offline chrome", "[ware.type] holding [arm.active_item.type]")
		if(HAS_TRAIT(body, SOAK_TRAIT_ZOOMED))
			var/obj/item/organ/eyes/robotic/cyberware/optics = body.get_organ_slot(ORGAN_SLOT_EYES)
			var/datum/component/cyberware/optic_chrome = istype(optics) ? optics.GetComponent(/datum/component/cyberware) : null
			if(!istype(optics) || !optics.is_zoomed())
				suspect("[REF(body)]|zoomtrait", "zoom trait with no zoomed optics behind it", "[body]")
			else if(!optic_chrome?.is_running())
				suspect("[REF(body)]|zoomoffline", "zoom held open on offline optics", "[optics.type]")
			else if(body.stat != CONSCIOUS)
				suspect("[REF(body)]|zoomstat", "zoom held open on a body that is not awake", "[body] stat [body.stat]")
		if(HAS_TRAIT(body, SOAK_TRAIT_CAMO))
			var/obj/item/organ/cyberimp/cyberware/ghostskin/weave = body.get_organ_slot(SOAK_SLOT_SKIN)
			var/datum/component/cyberware/weave_chrome = istype(weave) ? weave.GetComponent(/datum/component/cyberware) : null
			if(!istype(weave) || !weave.camo_active)
				suspect("[REF(body)]|camotrait", "camo trait with no engaged weave behind it", "[body]")
			else if(!weave_chrome?.is_running())
				suspect("[REF(body)]|camooffline", "camo held on an offline weave", "[weave.type]")
	for(var/key in suspects.Copy())
		if(!seen_now[key])
			suspects -= key
			reported -= key

// ---- The audit -----------------------------------------------------------

/// Heal the survivors, take all their chrome out, leave them alone and compare with the
/// snapshot from before they had any.
/datum/unit_test/voidcrew_opt_in/cyberware_soak/proc/audit_survivors()
	var/list/survivors = list()
	for(var/mob/living/carbon/human/body as anything in crew)
		if(QDELETED(body) || !baselines[body])
			continue
		survivors += body
		body.drop_all_held_items()
		body.forceMove(run_loc_floor_bottom_left)
		body.set_handcuffed(null)
		REMOVE_TRAIT(body, TRAIT_PACIFISM, "soak")
		body.revive(ADMIN_HEAL_ALL)
		body.regenerate_limbs()
		var/index = 0
		for(var/obj/item/organ/ware as anything in get_installed_cyberware(body))
			index++
			// Half through the normal removal, half the way a dying body does it.
			ware.Remove(body, special = (index % 2 == 0))
			ware.forceMove(get_turf(body))
			loose_chrome += ware
		if(get_chrome_load(body) != 0)
			note("a body still carries load with no chrome in it", "[body] carries [get_chrome_load(body)]")
	log_world("SOAK auditing [length(survivors)] survivors after a 20 second quiet")
	sleep(20 SECONDS)
	for(var/mob/living/carbon/human/body as anything in survivors)
		if(QDELETED(body))
			continue
		var/list/before = baselines[body]
		var/list/now = snapshot(body)
		for(var/key in before)
			var/old_value = before[key]
			var/new_value = now[key]
			if(islist(old_value))
				var/list/old_list = old_value
				var/list/new_list = new_value
				var/list/gained = list()
				var/list/lost = list()
				if(key == "traits" || key == "physiology")
					for(var/entry in new_list)
						if(new_list[entry] != old_list[entry])
							gained += "[entry] [old_list[entry]] -> [new_list[entry]]"
					for(var/entry in old_list)
						if(isnull(new_list[entry]))
							lost += "[entry]"
				else
					var/list/remaining = old_list.Copy()
					for(var/entry in new_list)
						if(entry in remaining)
							remaining -= entry
						else
							gained += "[entry]"
					lost = remaining
				if(length(gained) || length(lost))
					// The chrome wheel is made on first use and kept for the body's life.
					if(key == "components")
						gained -= "[/datum/component/chrome_wheel]"
					// A baseline taken mid-fight can hold a passing effect (a stagger); only
					// what was ADDED by the chrome and never left counts for these.
					if(key == "status effects" || key == "movespeed" || key == "actionspeed")
						lost = list()
					if(length(gained) || length(lost))
						note("after stripping the chrome, [key] differ from before it", "[body]: gained [english_list(gained)], lost [english_list(lost)]")
			else if(old_value != new_value)
				note("after stripping the chrome, [key] differs from before it", "[body]: was [old_value], now [new_value]")
		for(var/stale in voidcrew_cyberware_stale_listeners(body))
			note("a stripped body still has chrome listening to it", "[body]: [stale]")

/// Delete everything this test made, wait for the garbage collector, and return what survived.
/datum/unit_test/voidcrew_opt_in/cyberware_soak/proc/clean_up()
	// The cradle's own loose ends first.
	var/tray_strays = 0
	if(!QDELETED(cradle))
		if(cradle.busy)
			note("the cradle ended the soak mid-sequence", "[cradle.busy_action]")
		list_clear_nulls(cradle.tray)
		for(var/obj/item/organ/stray in cradle.tray)
			if(QDELETED(stray))
				tray_strays++
	if(tray_strays)
		note("the cradle's tray holds deleted chrome", "[tray_strays] pieces")
	crew.Cut()
	baselines.Cut()
	loose_chrome.Cut()
	suspects.Cut()
	reported.Cut()
	seen_now.Cut()
	// The cradle first, because its tray empties onto the floor when it goes.
	qdel(cradle)
	cradle = null
	// Everything in the room goes, bodies and chrome and gibs. Twice: the first pass can drop
	// things (a dead body's pockets, a limb's chrome) that the second one picks up.
	for(var/pass in 1 to 2)
		for(var/turf/where as anything in floor_turfs + run_loc_floor_top_right)
			for(var/atom/movable/thing as anything in where.contents.Copy())
				if(istype(thing, /obj/effect/landmark))
					continue
				qdel(thing)
	floor_turfs.Cut()
	ledgers.Cut()
	// Past the longest queue the collector has, plus a margin.
	sleep(45 SECONDS)
	var/list/leaks = list()
	for(var/datum/weakref/ref as anything in made)
		var/datum/survivor = ref.resolve()
		if(survivor)
			leaks["[survivor.type]"] = (leaks["[survivor.type]"] || 0) + 1
	made.Cut()
	// Anything that ran out of patience with the collector is counted per type.
	for(var/gc_type in SSgarbage.items)
		var/datum/qdel_item/item = SSgarbage.items[gc_type]
		var/list/before = gc_before[gc_type] || list(0, 0)
		if(item.failures > before[1] || item.hard_deletes > before[2])
			var/path_text = "[gc_type]"
			if(findtext(path_text, "cyberware") || findtext(path_text, "chrome") || findtext(path_text, "/mob/living/carbon/human") || findtext(path_text, "quickhack") || findtext(path_text, "shop_buyback"))
				leaks["GC [path_text]: [item.failures - before[1]] failures, [item.hard_deletes - before[2]] hard deletes"] = 1
	// A timer pointing at an object that is already gone should not exist.
	var/orphaned = 0
	for(var/timer_id in SStimer.timer_id_dict)
		var/datum/timedevent/timer = SStimer.timer_id_dict[timer_id]
		var/datum/object = timer?.callBack?.object
		if(isdatum(object) && QDELETED(object))
			orphaned++
	if(orphaned)
		leaks["timers aimed at deleted objects"] = orphaned
	stats["timers before"] = timers_at_start
	stats["timers after"] = length(SStimer.timer_id_dict)
	return leaks

/datum/unit_test/voidcrew_opt_in/cyberware_soak/proc/report(list/leaks)
	var/list/lines = list()
	lines += "CHROME SOAK REPORT"
	lines += "storm length [storm_length / 10] s, [crew_size] bodies, [length(ware_pool)] kinds of chrome in the pool"
	lines += "runtimes during the soak: [GLOB.total_runtimes - runtimes_at_start] (plus [GLOB.total_runtimes_skipped - skipped_runtimes_at_start] silenced as repeats)"
	lines += "-- what was done"
	for(var/what in stats)
		lines += "  [what]: [stats[what]]"
	lines += "-- problems ([length(problem_counts)] kinds)"
	for(var/category in problem_counts)
		lines += "  [category] x[problem_counts[category]]: [problem_examples[category]]"
	lines += "-- left behind ([length(leaks)] kinds)"
	for(var/leak in leaks)
		lines += "  [leak]: [leaks[leak]]"
	var/text = lines.Join("\n")
	fdel("data/soak_report.txt")
	text2file(text, "data/soak_report.txt")
	log_world(text)
	for(var/category in problem_counts)
		Fail("[category] (x[problem_counts[category]]): [problem_examples[category]]")
	for(var/leak in leaks)
		Fail("left behind: [leak]: [leaks[leak]]")

#undef SOAK_SLOT_SKIN
#undef SOAK_TRAIT_CAMO
#undef SOAK_TRAIT_ZOOMED
#undef SOAK_INSTALL_TIME
#undef SOAK_REMOVAL_TIME
#undef SOAK_EMP_DOWNTIME
#undef SOAK_TUNEUP_FEE
#undef SOAK_PATIENCE
