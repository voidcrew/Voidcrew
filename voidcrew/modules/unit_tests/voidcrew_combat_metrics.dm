/// Combat metrics pick real hits out of log_combat() lines, name how a hit landed and why a player
/// died, attribute scoped revivals, and credit NPC kills to the player with the last hit.
/// No database: rows stay in SSmetrics' memory.
/datum/unit_test/voidcrew_combat_metrics
	var/was_accepting
	var/list/old_pending
	var/list/old_tallies
	var/list/old_deaths
	var/list/old_last_deaths
	var/old_flush_scheduled
	var/patient_number = 0
	var/shocks = 0
	var/nested_restored = FALSE
	var/obj/item/organ/cyberimp/cyberware/governor_delete/defib_governor

/datum/unit_test/voidcrew_combat_metrics/Run()
	for(var/hit in list("attacked", "shot", "threw and hit", "punched", "kicked"))
		TEST_ASSERT(metric_is_combat_hit(hit), "\"[hit]\" is a hit")
	for(var/not_hit in list("shaken", "grabbed", "shoved", "operated on", "handcuffed", "CPRed", "fired at", "hit ", "attempted to punch", "revived"))
		TEST_ASSERT(!metric_is_combat_hit(not_hit), "\"[not_hit]\" is not a hit")
	TEST_ASSERT(!metric_is_combat_hit(null), "a missing verb is not a hit")

	TEST_ASSERT_EQUAL(metric_hit_class(/obj/projectile/bullet, "shot"), "ranged", "projectiles are ranged")
	TEST_ASSERT_EQUAL(metric_hit_class(/obj/item/knife/kitchen, "threw and hit"), "thrown", "thrown items are thrown")
	TEST_ASSERT_EQUAL(metric_hit_class(/obj/item/knife/kitchen, "attacked"), "melee", "held weapons are melee")
	TEST_ASSERT_EQUAL(metric_hit_class("gorilla arms", "piston-punched"), "melee", "a logged weapon name is melee")
	TEST_ASSERT_EQUAL(metric_hit_class(null, "punched"), "unarmed", "no weapon is unarmed")

	TEST_ASSERT_EQUAL(metric_death_cause(TRUE, FALSE, "killer", /mob/living/carbon/human), "suicide", "suicide beats a recent attacker")
	TEST_ASSERT_EQUAL(metric_death_cause(FALSE, TRUE, "killer", /mob/living/carbon/human), "pvp", "a player's recent hit is pvp, even when gibbed")
	TEST_ASSERT_EQUAL(metric_death_cause(FALSE, FALSE, null, /mob/living/basic/carp), "npc", "an NPC's recent hit is npc")
	TEST_ASSERT_EQUAL(metric_death_cause(FALSE, TRUE, null, null), "gibbed", "gibbed with nobody around")
	TEST_ASSERT_EQUAL(metric_death_cause(FALSE, FALSE, null, null, 80, 60, 0, 40, 0, 2), "vacuum", "low pressure with no attacker")
	TEST_ASSERT_EQUAL(metric_death_cause(FALSE, FALSE, null, null, 0, 0, 0, 30, 200, 101), "brain", "brain damage at the lethal cap")
	TEST_ASSERT_EQUAL(metric_death_cause(FALSE, FALSE, null, null, 10, 20, 0, 150, 0, 101), "suffocation", "mostly oxygen damage")
	TEST_ASSERT_EQUAL(metric_death_cause(FALSE, FALSE, null, null, 10, 190, 0, 0), "burn", "mostly burn damage")
	TEST_ASSERT_EQUAL(metric_death_cause(FALSE, FALSE, null, null, 10, 0, 190, 0), "toxin", "mostly toxin damage")
	TEST_ASSERT_EQUAL(metric_death_cause(FALSE, FALSE, null, null, 190, 10, 0, 0), "brute", "mostly brute damage")
	TEST_ASSERT_EQUAL(metric_death_cause(FALSE, FALSE, null, null), "unknown", "no damage at all")

	was_accepting = SSmetrics.accepting
	old_pending = SSmetrics.pending
	old_tallies = SSmetrics.tallies
	SSmetrics.accepting = TRUE
	SSmetrics.pending = list()
	SSmetrics.tallies = list()
	old_deaths = GLOB.combat_metrics.pending_deaths
	old_last_deaths = GLOB.combat_metrics.last_death_by_ckey
	old_flush_scheduled = GLOB.combat_metrics.flush_scheduled
	GLOB.combat_metrics.pending_deaths = list()
	GLOB.combat_metrics.last_death_by_ckey = list()
	GLOB.combat_metrics.flush_scheduled = FALSE

	var/mob/living/carbon/human/player = allocate(/mob/living/carbon/human/consistent)
	player.mind_initialize()
	player.mind.key = "combattester"
	// Skip the overmap lookup: the test level isn't in a zone.
	player.metric_zone_cached = "red"
	player.metric_zone_expires = world.time + 1 MINUTES
	var/obj/item/knife/kitchen/knife = allocate(/obj/item/knife/kitchen)
	player.put_in_active_hand(knife)
	var/mob/living/carbon/human/npc = allocate(/mob/living/carbon/human/consistent)
	var/mob/living/carbon/human/other_npc = allocate(/mob/living/carbon/human/consistent)

	metric_combat_hit(player, npc, "shaken", knife.name)
	metric_combat_hit(npc, other_npc, "attacked")
	metric_combat_hit(player, player, "attacked", knife.name)
	TEST_ASSERT_EQUAL(length(SSmetrics.tallies), 0, "harmless actions, NPC fights and self-harm are not tallied")

	metric_combat_hit(player, npc, "attacked", knife.name)
	var/list/hit = find_tally("npc_hit_melee")
	TEST_ASSERT_NOTNULL(hit, "a player's knife hit on an NPC is tallied")
	TEST_ASSERT_EQUAL(hit["ckey"], "combattester", "the attacker is the ckey")
	TEST_ASSERT_EQUAL(hit["subject"], "[npc.type]", "the NPC's type is the subject")
	TEST_ASSERT_EQUAL(hit["zone"], "red", "the attacker's cached zone is used")
	TEST_ASSERT_EQUAL(npc.metric_hit_ckey, "combattester", "the NPC remembers who hit it")
	TEST_ASSERT_EQUAL(npc.metric_hit_weapon, knife.type, "the logged item name resolves to the held knife")

	// Killed after a player's hit, then an NPC nobody had touched killed by a blow logged after its death.
	npc.death()
	other_npc.death()
	metric_combat_hit(player, other_npc, "attacked", knife.name)
	GLOB.combat_metrics.flush_pending_deaths()
	var/list/kills = find_tally("npc_killed")
	TEST_ASSERT_NOTNULL(kills, "NPC kills are credited to the player")
	TEST_ASSERT_EQUAL(kills["ckey"], "combattester", "the killer is the ckey")
	TEST_ASSERT_EQUAL(kills["quantity"], 2, "both kills count, including the killing blow logged after the death")

	check_attribution()
	check_implant_clock()
	check_implant_callbacks()
	check_nanite_defib()

/// Real humans and real revival code; only the implant clock is simulated.
/datum/unit_test/voidcrew_combat_metrics/proc/patient()
	var/mob/living/carbon/human/consistent/voidcrew_revival_test/body = allocate(/mob/living/carbon/human/consistent/voidcrew_revival_test)
	body.mind_initialize()
	body.mind.key = "revivaltester[++patient_number]"
	return body

/datum/unit_test/voidcrew_combat_metrics/proc/revival_count(mob/living/body, method)
	var/count = 0
	for(var/list/row as anything in SSmetrics.pending)
		if(row["ckey"] == metric_ckey(body) && row["event"] == "revived" && (!method || row["subject"] == method))
			count += row["quantity"]
	for(var/key in SSmetrics.tallies)
		var/list/row = SSmetrics.tallies[key]
		if(row["ckey"] == metric_ckey(body) && row["event"] == "revived_repeat" && (!method || row["subject"] == method))
			count += row["quantity"]
	return count

/datum/unit_test/voidcrew_combat_metrics/proc/check_attribution()
	for(var/method in list("reviver_implant", "nanites", "defibrillator", "strange_reagent", "legion_core", "surgery", "reagent", "admin", "phylactery", "meridian_heart", "lazarus_line", "temporal_rewind"))
		var/mob/living/body = patient()
		body.death()
		TEST_ASSERT(body.revive_from(method), "[method] did not revive a healthy corpse")
		TEST_ASSERT_EQUAL(revival_count(body, method), 1, "[method] was not explicitly attributed")
		TEST_ASSERT_NULL(body.metric_revival_method, "[method] leaked its attribution")
		TEST_ASSERT(!body.metric_revive_was_dead, "[method] leaked its death context")
		body.revive_from("admin", ADMIN_HEAL_ALL)
		body.heal_and_revive_from("phylactery", 30)
		TEST_ASSERT_EQUAL(revival_count(body), 1, "Healing a living body recorded a revival")

	var/mob/living/carbon/human/consistent/voidcrew_revival_test/body = patient()
	body.setOxyLoss(250)
	body.death()
	TEST_ASSERT(!body.revive_from("nanites"), "An unhealed lethal corpse revived")
	TEST_ASSERT_NULL(body.metric_revival_method, "A failed revival leaked attribution")
	TEST_ASSERT_EQUAL(revival_count(body), 0, "A failed revival was recorded")
	TEST_ASSERT(body.heal_and_revive_from("phylactery", 30), "The scoped healing route did not revive")
	TEST_ASSERT_EQUAL(revival_count(body, "phylactery"), 1, "The healing route lost its method")
	TEST_ASSERT_NULL(body.metric_revival_method, "The healing route leaked attribution")

	var/mob/living/unknown = patient()
	unknown.death()
	TEST_ASSERT(unknown.revive(), "An unclassified route failed")
	TEST_ASSERT_EQUAL(revival_count(unknown, "other"), 1, "Unclassified routes must remain other")
	var/mob/living/clone = patient()
	metric_clone_revival(clone, unknown)
	TEST_ASSERT_EQUAL(revival_count(clone, "cloning_vat"), 1, "Cloning vat attribution changed")

	// A nested heal during the outer revival signal must restore both contexts.
	var/mob/living/nested = patient()
	RegisterSignal(nested, COMSIG_LIVING_REVIVE, PROC_REF(nested_heal))
	nested.death()
	TEST_ASSERT(nested.revive_from("surgery"), "The outer revival failed")
	TEST_ASSERT(nested_restored, "A nested living heal did not restore the enclosing method")
	TEST_ASSERT_EQUAL(revival_count(nested, "surgery"), 1, "The nested heal replaced the outer method")
	TEST_ASSERT_EQUAL(revival_count(nested), 1, "The nested living heal was counted")
	TEST_ASSERT_NULL(nested.metric_revival_method, "The nested revival leaked context")

	body.metric_revival_method = "enclosing"
	body.throw_on_revive = TRUE
	var/caught = FALSE
	try
		body.revive_from("admin")
	catch(var/exception/error)
		caught = !isnull(error)
	TEST_ASSERT(caught, "The exception fixture did not throw")
	TEST_ASSERT_EQUAL(body.metric_revival_method, "enclosing", "An exception lost the enclosing method")
	body.throw_on_revive = FALSE
	body.throw_on_heal = TRUE
	caught = FALSE
	try
		body.heal_and_revive_from("phylactery", 30)
	catch(var/exception/healing_error)
		caught = !isnull(healing_error)
	TEST_ASSERT(caught, "The healing exception fixture did not throw")
	TEST_ASSERT_EQUAL(body.metric_revival_method, "enclosing", "A healing exception lost the enclosing method")
	body.metric_revival_method = null
	body.throw_on_heal = FALSE

/datum/unit_test/voidcrew_combat_metrics/proc/nested_heal(mob/living/source, full_heal_flags)
	SIGNAL_HANDLER
	UnregisterSignal(source, COMSIG_LIVING_REVIVE)
	var/outer_method = source.metric_revival_method
	source.revive_from("admin")
	nested_restored = source.metric_revival_method == outer_method && source.metric_revive_was_dead

/// Reproduce eleven death/revival requests across nine simulated minutes without sleeping.
/datum/unit_test/voidcrew_combat_metrics/proc/check_implant_clock()
	var/mob/living/carbon/human/consistent/voidcrew_revival_test/body = patient()
	var/obj/item/organ/cyberimp/chest/reviver/voidcrew_clock_test/implant = allocate(/obj/item/organ/cyberimp/chest/reviver/voidcrew_clock_test)
	implant.Insert(body)
	body.setOxyLoss(250)
	body.death()
	var/start_time = 1 HOURS
	var/list/attempt_times = list(0, 45 SECONDS, 90 SECONDS, 135 SECONDS, 180 SECONDS, 225 SECONDS, 270 SECONDS, 315 SECONDS, 360 SECONDS, 405 SECONDS, 450 SECONDS)
	var/attempts = 0
	var/succeeded_at
	var/cooldown_at_success
	var/healing_at_success
	var/reached_hardcrit = FALSE
	for(var/elapsed in 0 to (9 MINUTES) step (1 SECONDS))
		implant.clock = start_time + elapsed
		if(elapsed in attempt_times)
			attempts++
			if(body.stat != DEAD)
				body.setOxyLoss(250)
			body.death()
			implant.revive_dead()
		implant.on_death(1, elapsed / 10)
		implant.try_heal()
		var/timer_before = implant.heal_timer
		implant.try_heal()
		TEST_ASSERT_EQUAL(implant.heal_timer, timer_before, "Overlapping processing queued a second healing timer")
		if(implant.heal_timer && implant.clock >= implant.heal_due)
			implant.heal(WEAKREF(body), implant.activation_generation, implant.heal_generation)
			if(body.health == body.hardcrit_threshold)
				reached_hardcrit = TRUE
				TEST_ASSERT_EQUAL(body.stat, DEAD, "The implant revived at the hard-crit boundary")
		if(body.revive_calls && isnull(succeeded_at))
			succeeded_at = implant.clock
			cooldown_at_success = implant.reviver_cooldown
			healing_at_success = implant.revive_cost - 10 MINUTES
			TEST_ASSERT(body.stat != DEAD, "The implant's first attempt did not succeed")
			TEST_ASSERT(!implant.reviving && !implant.heal_timer, "Successful revival did not end the activation")
			TEST_ASSERT_EQUAL(cooldown_at_success, succeeded_at + 10 MINUTES + healing_at_success, "Cooldown did not begin at success")
		if(!isnull(succeeded_at))
			if(elapsed == 60 SECONDS)
				body.set_stat(CONSCIOUS)
			if(elapsed == 61 SECONDS)
				body.set_stat(HARD_CRIT)
			implant.try_heal()
			TEST_ASSERT_EQUAL(implant.reviver_cooldown, cooldown_at_success, "Consciousness or another death restarted the cooldown")
	TEST_ASSERT_EQUAL(attempts, 11, "The scenario did not exercise all eleven observed requests")
	TEST_ASSERT(reached_hardcrit, "The scenario never reached the exact hard-crit boundary")
	TEST_ASSERT_NOTNULL(succeeded_at, "The implant never revived after healing past hard crit")
	TEST_ASSERT_EQUAL(succeeded_at, start_time + 3 SECONDS + 24 * SSmobs.wait, "Single-callback scheduling changed the existing healing rate")
	TEST_ASSERT_EQUAL(body.hardcrit_revive_calls, 0, "revive() was attempted at hard-crit health")
	TEST_ASSERT_EQUAL(body.revive_calls, 1, "The implant attempted a second revival during cooldown")
	TEST_ASSERT_EQUAL(revival_count(body, "reviver_implant"), 1, "The scenario did not produce exactly one attributed success")
	TEST_ASSERT(healing_at_success > 0, "Accumulated healing was omitted from cooldown")
	TEST_ASSERT(implant.clock < implant.reviver_cooldown, "The nine-minute scenario outlasted the success cooldown")
	implant.Remove(body)
	implant.Insert(body)
	implant.try_heal()
	TEST_ASSERT_EQUAL(implant.reviver_cooldown, cooldown_at_success, "Reinsertion reset the successful revival cooldown")
	TEST_ASSERT(!implant.reviving && !implant.heal_timer, "Reinsertion bypassed the successful revival cooldown")

/datum/unit_test/voidcrew_combat_metrics/proc/check_implant_callbacks()
	var/mob/living/carbon/human/first = patient()
	var/mob/living/carbon/human/second = patient()
	first.setOxyLoss(200)
	second.setOxyLoss(200)
	first.death()
	second.death()
	var/obj/item/organ/cyberimp/chest/reviver/voidcrew_clock_test/implant = allocate(/obj/item/organ/cyberimp/chest/reviver/voidcrew_clock_test)
	implant.clock = 1 HOURS
	implant.Insert(first)
	implant.try_heal()
	implant.try_heal()
	var/generation = implant.activation_generation
	var/implantation = implant.implantation_generation
	var/callback_generation = implant.heal_generation
	var/old_timer = implant.heal_timer
	for(var/index in 1 to 11)
		implant.try_heal()
		TEST_ASSERT_EQUAL(implant.heal_timer, old_timer, "Processing queued overlapping callbacks")
	implant.Remove(first)
	TEST_ASSERT(!implant.heal_timer && !implant.reviving, "Removal did not cancel the pending activation")
	implant.Insert(second)
	implant.try_heal()
	implant.try_heal()
	var/new_timer = implant.heal_timer
	implant.heal(WEAKREF(first), generation, callback_generation)
	TEST_ASSERT_EQUAL(first.getOxyLoss(), 200, "A removed implant healed its former owner")
	TEST_ASSERT_EQUAL(second.getOxyLoss(), 200, "A stale callback healed the new owner")
	TEST_ASSERT_EQUAL(implant.heal_timer, new_timer, "A stale callback consumed the new owner's timer")
	second.set_heartattack(TRUE)
	implant.undo_heart_attack(WEAKREF(first), implantation)
	TEST_ASSERT(second.undergoing_cardiac_arrest(), "A stale EMP callback healed the new owner")
	callback_generation = implant.heal_generation
	implant.heal(WEAKREF(second), implant.activation_generation, implant.heal_generation)
	TEST_ASSERT_EQUAL(second.getOxyLoss(), 195, "One callback did not preserve the oxygen healing rate")
	TEST_ASSERT_EQUAL(implant.heal_due, implant.clock + SSmobs.wait, "A healing callback changed the existing pulse interval")
	implant.try_heal()
	implant.heal(WEAKREF(second), implant.activation_generation, callback_generation)
	TEST_ASSERT_EQUAL(second.getOxyLoss(), 195, "Replaying an earlier callback healed twice")
	generation = implant.activation_generation
	callback_generation = implant.heal_generation
	implantation = implant.implantation_generation
	implant.Remove(second)
	implant.Insert(second)
	implant.try_heal()
	implant.try_heal()
	TEST_ASSERT_EQUAL(implant.revive_cost, 5, "Reinsertion discarded accumulated healing cost")
	implant.heal(WEAKREF(second), generation, callback_generation)
	TEST_ASSERT_EQUAL(second.getOxyLoss(), 195, "Reinsertion into the same body accepted a stale generation")
	implant.undo_heart_attack(WEAKREF(second), implantation)
	TEST_ASSERT(second.undergoing_cardiac_arrest(), "Reinsertion accepted a stale EMP recovery")
	generation = implant.activation_generation
	callback_generation = implant.heal_generation
	qdel(implant)
	implant.heal(WEAKREF(second), generation, callback_generation)
	TEST_ASSERT_EQUAL(second.getOxyLoss(), 195, "A deleted implant healed its owner")

	var/mob/living/carbon/human/consistent/voidcrew_revival_test/failed = patient()
	failed.setBruteLoss(10)
	failed.setFireLoss(10)
	failed.setToxLoss(10, TRUE, FALSE, ALL)
	failed.setOxyLoss(100)
	failed.death()
	failed.deny_revival = TRUE
	var/obj/item/organ/cyberimp/chest/reviver/voidcrew_clock_test/failing_implant = allocate(/obj/item/organ/cyberimp/chest/reviver/voidcrew_clock_test)
	failing_implant.clock = 1 HOURS
	failing_implant.Insert(failed)
	failing_implant.try_heal()
	failing_implant.try_heal()
	failing_implant.clock += 8 SECONDS
	RegisterSignal(failed, COMSIG_LIVING_MINOR_SHOCK, PROC_REF(note_shock))
	failing_implant.heal(WEAKREF(failed), failing_implant.activation_generation, failing_implant.heal_generation)
	TEST_ASSERT_EQUAL(failed.getBruteLoss(), 8, "Implant brute healing changed")
	TEST_ASSERT_EQUAL(failed.getFireLoss(), 8, "Implant burn healing changed")
	TEST_ASSERT_EQUAL(failed.getToxLoss(), 9, "Implant toxin healing changed")
	TEST_ASSERT_EQUAL(failed.getOxyLoss(), 95, "Implant oxygen healing changed")
	TEST_ASSERT_EQUAL(failed.revive_calls, 1, "The failed implant revival was not attempted after healing")
	TEST_ASSERT_EQUAL(failing_implant.revive_cost, 125, "A failed revival added the success surcharge")
	TEST_ASSERT_EQUAL(failing_implant.reviver_cooldown, 0, "A failed revival began the success cooldown")
	TEST_ASSERT(failing_implant.reviving, "A failed revival ended its activation")
	TEST_ASSERT_EQUAL(revival_count(failed), 0, "A failed implant revival was recorded as success")
	TEST_ASSERT_EQUAL(shocks, 0, "A failed implant revival emitted a success shock")

/datum/unit_test/voidcrew_combat_metrics/proc/note_shock(mob/living/source)
	SIGNAL_HANDLER
	shocks++

/datum/unit_test/voidcrew_combat_metrics/proc/check_nanite_defib()
	var/list/failures = list("suicide" = DEFIB_FAIL_SUICIDE, "husk" = DEFIB_FAIL_HUSK, "no heart" = DEFIB_FAIL_NO_HEART, "bad heart" = DEFIB_FAIL_FAILING_HEART, "no brain" = DEFIB_FAIL_NO_BRAIN, "bad brain" = DEFIB_FAIL_FAILING_BRAIN, "brute" = DEFIB_FAIL_TISSUE_DAMAGE, "burn" = DEFIB_FAIL_TISSUE_DAMAGE, "blacklist" = DEFIB_FAIL_BLACKLISTED, "no intelligence" = DEFIB_FAIL_NO_INTELLIGENCE)
	var/datum/nanite_program/defib/program = allocate(/datum/nanite_program/defib)
	for(var/failure in failures)
		var/mob/living/carbon/body = patient()
		body.setOxyLoss(250)
		body.death()
		var/obj/item/organ/heart/heart = body.get_organ_slot(ORGAN_SLOT_HEART)
		var/obj/item/organ/brain/brain = body.get_organ_slot(ORGAN_SLOT_BRAIN)
		switch(failure)
			if("suicide")
				ADD_TRAIT(body, TRAIT_SUICIDED, INNATE_TRAIT)
			if("husk")
				ADD_TRAIT(body, TRAIT_HUSK, INNATE_TRAIT)
			if("no heart")
				heart.Remove(body, special = TRUE)
			if("bad heart")
				heart.set_organ_damage(heart.maxHealth)
			if("no brain")
				brain.Remove(body, special = TRUE)
			if("bad brain")
				brain.set_organ_damage(brain.maxHealth)
			if("brute")
				body.setBruteLoss(MAX_REVIVE_BRUTE_DAMAGE)
			if("burn")
				body.setFireLoss(MAX_REVIVE_FIRE_DAMAGE)
			if("blacklist")
				ADD_TRAIT(body, TRAIT_DEFIB_BLACKLISTED, INNATE_TRAIT)
			if("no intelligence")
				brain.suicided = TRUE
		program.host_mob = body
		RegisterSignal(body, COMSIG_LIVING_MINOR_SHOCK, PROC_REF(note_shock))
		var/health_before = body.health
		TEST_ASSERT_EQUAL(body.can_defib(), failures[failure], "The [failure] fixture did not reach its intended rejection")
		TEST_ASSERT(!program.check_revivable(), "Nanites accepted [failure] as eligible")
		TEST_ASSERT(!program.defibrillate(), "Nanites revived despite [failure]")
		TEST_ASSERT_EQUAL(body.health, health_before, "Nanites healed a body rejected for [failure]")
		TEST_ASSERT_EQUAL(body.stat, DEAD, "Nanites revived a body rejected for [failure]")
		TEST_ASSERT_EQUAL(revival_count(body), 0, "A nanite failure was logged as success: [failure]")
	TEST_ASSERT_EQUAL(shocks, 0, "A rejected nanite attempt emitted a success shock")

	// Eligibility can pass and revive() can still fail. No success effects may escape.
	var/mob/living/carbon/human/consistent/voidcrew_revival_test/failed = patient()
	failed.setOxyLoss(250)
	failed.death()
	failed.deny_revival = TRUE
	program.host_mob = failed
	RegisterSignal(failed, COMSIG_LIVING_MINOR_SHOCK, PROC_REF(note_shock))
	TEST_ASSERT(program.check_revivable(), "The failed-revive fixture was ineligible")
	TEST_ASSERT(!program.defibrillate(), "A failing revive() reported nanite success")
	TEST_ASSERT_EQUAL(failed.stat, DEAD, "A failing revive() brought the body back")
	TEST_ASSERT_EQUAL(shocks, 0, "A failing revive() emitted success effects")
	TEST_ASSERT(!failed.has_status_effect(/datum/status_effect/jitter), "A failing revive() applied success jitter")
	TEST_ASSERT_EQUAL(revival_count(failed), 0, "A failing revive() emitted a success row")
	TEST_ASSERT_NULL(failed.metric_revival_method, "A failed nanite revival leaked attribution")

	// Both sides exercise their production revival path on identical mixed injuries.
	var/mob/living/carbon/nanite_body = patient()
	var/mob/living/carbon/paddle_body = patient()
	var/obj/item/shockpaddles/cyborg/paddles = allocate(/obj/item/shockpaddles/cyborg)
	for(var/mob/living/carbon/body in list(nanite_body, paddle_body))
		body.death()
		var/obj/item/organ/liver = body.get_organ_slot(ORGAN_SLOT_LIVER)
		liver.Remove(body, special = TRUE)
		var/obj/item/bodypart/arm = body.get_bodypart(BODY_ZONE_L_ARM)
		arm.drop_limb()
		body.setBruteLoss(80)
		body.setFireLoss(40)
		body.setToxLoss(30, TRUE, FALSE, ALL)
		body.setOxyLoss(110)
		body.get_organ_slot(ORGAN_SLOT_HEART).set_organ_damage(20)
		body.get_organ_slot(ORGAN_SLOT_BRAIN).set_organ_damage(20)
		ADD_TRAIT(body, TRAIT_DEAF, INNATE_TRAIT)
	program.host_mob = nanite_body
	RegisterSignal(nanite_body, COMSIG_LIVING_MINOR_SHOCK, PROC_REF(note_shock))
	TEST_ASSERT(program.defibrillate(), "Eligible nanites did not revive")
	TEST_ASSERT(paddles.revive_patient(paddle_body, paddle_body.can_defib()), "Eligible paddles did not revive")
	TEST_ASSERT_EQUAL(shocks, 1, "Successful nanites did not emit exactly one success shock")
	TEST_ASSERT(abs(nanite_body.health + 50) <= 4 * DAMAGE_PRECISION, "Nanites did not target -50 health within damage rounding")
	TEST_ASSERT_EQUAL(nanite_body.getBruteLoss(), paddle_body.getBruteLoss(), "Nanite brute redistribution differs from paddles")
	TEST_ASSERT_EQUAL(nanite_body.getFireLoss(), paddle_body.getFireLoss(), "Nanite burn redistribution differs from paddles")
	TEST_ASSERT_EQUAL(nanite_body.getToxLoss(), paddle_body.getToxLoss(), "Nanite toxin redistribution differs from paddles")
	TEST_ASSERT_EQUAL(nanite_body.getOxyLoss(), paddle_body.getOxyLoss(), "Nanite oxygen redistribution differs from paddles")
	for(var/mob/living/carbon/body in list(nanite_body, paddle_body))
		TEST_ASSERT_NULL(body.get_organ_slot(ORGAN_SLOT_LIVER), "Defib restored an unrelated missing organ")
		TEST_ASSERT_NULL(body.get_bodypart(BODY_ZONE_L_ARM), "Defib restored a missing limb")
		TEST_ASSERT_EQUAL(body.get_organ_loss(ORGAN_SLOT_HEART), 20, "Defib cured unrelated heart damage")
		TEST_ASSERT_EQUAL(body.get_organ_loss(ORGAN_SLOT_BRAIN), 20, "Defib cured unrelated brain damage")
		TEST_ASSERT(HAS_TRAIT(body, TRAIT_DEAF), "Defib cured unrelated deafness")
	TEST_ASSERT_EQUAL(revival_count(nanite_body, "nanites"), 1, "Successful nanites lost their attribution")
	TEST_ASSERT_EQUAL(revival_count(paddle_body, "defibrillator"), 1, "Successful paddles lost their attribution")

	// A healthy corpse gets the same oxygen penalty in both paths.
	var/mob/living/carbon/healthy = patient()
	healthy.death()
	program.host_mob = healthy
	TEST_ASSERT(program.defibrillate(), "Nanites failed on a repaired corpse")
	TEST_ASSERT_EQUAL(healthy.health, -50, "A repaired corpse was not brought to -50 health")
	TEST_ASSERT(!program.check_revivable(), "Nanites accepted a living host")

	// The admin-ghost special case remains eligible without forcing its ghost home.
	var/mob/living/carbon/human/consistent/voidcrew_revival_test/aghost = patient()
	aghost.defib_override = DEFIB_NOGRAB_AGHOST
	aghost.death()
	program.host_mob = aghost
	TEST_ASSERT(program.check_revivable(), "The admin-ghost special case was rejected")
	TEST_ASSERT(program.defibrillate(), "The admin-ghost special case could not revive")

	// Change eligibility while the real zap() is in its charge windup.
	var/mob/living/carbon/windup = patient()
	windup.death()
	program.host_mob = windup
	shocks = 0
	RegisterSignal(windup, COMSIG_LIVING_MINOR_SHOCK, PROC_REF(note_shock))
	addtimer(CALLBACK(src, PROC_REF(blacklist_during_windup), windup), 1)
	program.zap(WEAKREF(windup))
	TEST_ASSERT_EQUAL(windup.stat, DEAD, "Nanites ignored a blacklist added during windup")
	TEST_ASSERT_EQUAL(windup.health, 100, "Nanites healed after failing their windup recheck")
	TEST_ASSERT_EQUAL(shocks, 0, "A windup failure emitted success effects")
	TEST_ASSERT_EQUAL(revival_count(windup), 0, "A windup failure was logged as success")
	program.host_mob = null
	check_nanite_capacity_windup()

/datum/unit_test/voidcrew_combat_metrics/proc/check_nanite_capacity_windup()
	var/mob/living/carbon/human/consistent/voidcrew_revival_test/body = patient()
	defib_governor = allocate(/obj/item/organ/cyberimp/cyberware/governor_delete)
	var/obj/item/organ/cyberimp/cyberware/test_heavy/heavy = allocate(/obj/item/organ/cyberimp/cyberware/test_heavy)
	TEST_ASSERT(defib_governor.Insert(body, TRUE), "Could not install the defib capacity governor")
	TEST_ASSERT(heavy.Insert(body, TRUE), "Could not install the defib capacity load")
	var/datum/component/nanites/swarm = body.AddComponent(/datum/component/nanites)
	STOP_PROCESSING(SSnanites, swarm)
	swarm.regen_rate = 0
	var/datum/nanite_program/defib/program = allocate(/datum/nanite_program/defib)
	TEST_ASSERT_EQUAL(swarm.add_program(null, program), 1, "Could not install the capacity defib fixture") // COMPONENT_PROGRAM_INSTALLED
	body.setOxyLoss(250)
	body.death()
	TEST_ASSERT(program.check_revivable() && !program.capacity_blocked(), "The capacity defib fixture cannot start")
	shocks = 0
	RegisterSignal(body, COMSIG_LIVING_MINOR_SHOCK, PROC_REF(note_shock))
	var/health_before = body.health
	addtimer(CALLBACK(defib_governor, TYPE_PROC_REF(/obj/item/organ, Remove), body, TRUE), 1)
	program.zap(WEAKREF(body))
	TEST_ASSERT(program.capacity_blocked(), "Removing Governor Delete did not overload the defib host")
	TEST_ASSERT_EQUAL(body.health, health_before, "Nanites healed after losing capacity during windup")
	TEST_ASSERT(!program.defibrillate(), "Direct defibrillation ignored the capacity gate")
	TEST_ASSERT_EQUAL(body.health, health_before, "Direct defibrillation healed an overloaded host")
	TEST_ASSERT_EQUAL(body.revive_calls, 0, "An overloaded nanite program attempted revival")
	TEST_ASSERT_EQUAL(body.stat, DEAD, "Nanites revived after losing capacity during windup")
	TEST_ASSERT_EQUAL(shocks, 0, "A capacity windup failure emitted success effects")
	TEST_ASSERT_EQUAL(revival_count(body), 0, "A capacity windup failure was logged as success")

	// Healing can notify other systems; capacity must still hold when revival is attempted.
	TEST_ASSERT(defib_governor.Insert(body, TRUE), "Could not restore capacity before healing")
	RegisterSignal(body, COMSIG_LIVING_HEALTH_UPDATE, PROC_REF(remove_defib_governor_on_heal))
	TEST_ASSERT(!program.defibrillate(), "Nanites revived after losing capacity during healing")
	TEST_ASSERT(program.capacity_blocked(), "The healing callback did not remove capacity")
	TEST_ASSERT(body.health > health_before, "The capacity callback did not run during healing")
	TEST_ASSERT_EQUAL(body.revive_calls, 0, "Nanites attempted revival after healing removed capacity")
	TEST_ASSERT_EQUAL(body.stat, DEAD, "Healing capacity loss revived the host")
	TEST_ASSERT_EQUAL(shocks, 0, "Healing capacity loss emitted success effects")
	TEST_ASSERT_EQUAL(revival_count(body), 0, "Healing capacity loss was logged as success")
	TEST_ASSERT(defib_governor.Insert(body, TRUE), "Could not restore capacity after healing")
	TEST_ASSERT(program.defibrillate(), "Nanite defibrillation did not recover with capacity")
	TEST_ASSERT_EQUAL(revival_count(body, "nanites"), 1, "Recovered defibrillation lost its attribution")
	defib_governor = null

/datum/unit_test/voidcrew_combat_metrics/proc/remove_defib_governor_on_heal(mob/living/carbon/body)
	SIGNAL_HANDLER
	UnregisterSignal(body, COMSIG_LIVING_HEALTH_UPDATE)
	defib_governor.Remove(body, TRUE)

/datum/unit_test/voidcrew_combat_metrics/proc/blacklist_during_windup(mob/living/body)
	ADD_TRAIT(body, TRAIT_DEFIB_BLACKLISTED, INNATE_TRAIT)

/// Simulate time without modifying world.time or replacing the implant's healing/revival code.
/obj/item/organ/cyberimp/chest/reviver/voidcrew_clock_test
	var/clock = 0

/obj/item/organ/cyberimp/chest/reviver/voidcrew_clock_test/reviver_time()
	return clock

/mob/living/carbon/human/consistent/voidcrew_revival_test
	var/deny_revival = FALSE
	var/throw_on_revive = FALSE
	var/throw_on_heal = FALSE
	var/defib_override
	var/revive_calls = 0
	var/hardcrit_revive_calls = 0

/mob/living/carbon/human/consistent/voidcrew_revival_test/can_be_revived()
	return !deny_revival && ..()

/mob/living/carbon/human/consistent/voidcrew_revival_test/can_defib()
	if(!isnull(defib_override))
		return defib_override
	return ..()

/mob/living/carbon/human/consistent/voidcrew_revival_test/revive(full_heal_flags = NONE, excess_healing = 0, force_grab_ghost = FALSE)
	if(throw_on_revive)
		throw EXCEPTION("Revival scope cleanup fixture")
	revive_calls++
	if(health <= hardcrit_threshold)
		hardcrit_revive_calls++
	return ..()

/mob/living/carbon/human/consistent/voidcrew_revival_test/heal_and_revive(heal_to = 75, revive_message)
	if(throw_on_heal)
		throw EXCEPTION("Healing scope cleanup fixture")
	return ..()

/datum/unit_test/voidcrew_combat_metrics/proc/find_tally(event)
	for(var/key in SSmetrics.tallies)
		var/list/row = SSmetrics.tallies[key]
		if(row["event"] == event)
			return row
	return null

/datum/unit_test/voidcrew_combat_metrics/Destroy()
	if(old_pending)
		GLOB.combat_metrics.pending_deaths = old_deaths
		GLOB.combat_metrics.last_death_by_ckey = old_last_deaths
		GLOB.combat_metrics.flush_scheduled = old_flush_scheduled
		SSmetrics.accepting = was_accepting
		SSmetrics.pending = old_pending
		SSmetrics.tallies = old_tallies
	return ..()
