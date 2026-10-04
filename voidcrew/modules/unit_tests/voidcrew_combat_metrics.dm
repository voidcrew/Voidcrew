/// Combat metrics pick real hits out of log_combat() lines, name how a hit landed and why a player
/// died, find what called revive(), and credit NPC kills to the player with the last hit.
/// No database: rows stay in SSmetrics' memory.
/datum/unit_test/voidcrew_combat_metrics
	var/was_accepting
	var/list/old_pending
	var/list/old_tallies

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

	var/list/site = revive()
	TEST_ASSERT_NOTNULL(site, "the call stack walk finds the proc that called revive()")
	TEST_ASSERT_EQUAL(site[1], src, "the caller's src is read off the stack")
	TEST_ASSERT_EQUAL(site[2], "Run", "the caller's proc name is read off the stack")
	TEST_ASSERT_EQUAL(metric_revive_method(null, "do_strange_reagent_revival"), "strange_reagent", "strange reagent is named by its proc")
	TEST_ASSERT_EQUAL(metric_revive_method(src, "Run"), "other", "unknown callers are other")

	was_accepting = SSmetrics.accepting
	old_pending = SSmetrics.pending
	old_tallies = SSmetrics.tallies
	SSmetrics.accepting = TRUE
	SSmetrics.pending = list()
	SSmetrics.tallies = list()

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

/datum/unit_test/voidcrew_combat_metrics/proc/revive()
	return metric_revive_site()

/datum/unit_test/voidcrew_combat_metrics/proc/find_tally(event)
	for(var/key in SSmetrics.tallies)
		var/list/row = SSmetrics.tallies[key]
		if(row["event"] == event)
			return row
	return null

/datum/unit_test/voidcrew_combat_metrics/Destroy()
	if(old_pending)
		SSmetrics.accepting = was_accepting
		SSmetrics.pending = old_pending
		SSmetrics.tallies = old_tallies
	return ..()
