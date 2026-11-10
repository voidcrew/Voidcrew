// NPC shots pass over their own side (voidcrew/edits/modules/projectiles/projectile_npc_allies.dm).
// A mob nobody plays (no ckey) is an NPC; a mob with a ckey is a player.

/datum/unit_test/voidcrew_npc_fire_over_allies

/datum/unit_test/voidcrew_npc_fire_over_allies/Run()
	var/turf/start = run_loc_floor_bottom_left
	var/mob/living/carbon/human/consistent/shooter = allocate(/mob/living/carbon/human/consistent, start)
	var/mob/living/carbon/human/consistent/ally = allocate(/mob/living/carbon/human/consistent, locate(start.x + 2, start.y, start.z))
	var/mob/living/carbon/human/consistent/target = allocate(/mob/living/carbon/human/consistent, locate(start.x + 4, start.y, start.z))
	shooter.faction = list("npc_fire_test_side")
	ally.faction = list("npc_fire_test_side")
	target.faction = list("npc_fire_test_other")

	// An NPC's bullet flies past its ally and hits the player behind
	var/obj/item/ammo_casing/c38/round = allocate(/obj/item/ammo_casing/c38)
	TEST_ASSERT(round.fire_casing(target, shooter, null, 0, TRUE, BODY_ZONE_CHEST, 0, shooter), "The NPC's round didn't fire")
	wait_for_hit(target)
	TEST_ASSERT(target.getBruteLoss() > 0, "The NPC's bullet never reached the target behind its ally")
	TEST_ASSERT_EQUAL(ally.getBruteLoss(), 0, "The NPC's bullet hit its own ally on the way")

	// Buckshot: every pellet flies past the ally
	target.fully_heal()
	var/obj/item/ammo_casing/shotgun/buckshot/shell = allocate(/obj/item/ammo_casing/shotgun/buckshot)
	shell.variance = 0
	TEST_ASSERT(shell.fire_casing(target, shooter, null, 0, TRUE, BODY_ZONE_CHEST, 0, shooter), "The NPC's shell didn't fire")
	wait_for_hit(target)
	TEST_ASSERT(target.getBruteLoss() > 0, "The NPC's buckshot never reached the target behind its ally")
	TEST_ASSERT_EQUAL(ally.getBruteLoss(), 0, "The NPC's buckshot hit its own ally on the way")

	// Aimed at its ally, it hits its ally
	var/obj/item/ammo_casing/c38/aimed = allocate(/obj/item/ammo_casing/c38)
	TEST_ASSERT(aimed.fire_casing(ally, shooter, null, 0, TRUE, BODY_ZONE_CHEST, 0, shooter), "The NPC's aimed round didn't fire")
	wait_for_hit(ally)
	TEST_ASSERT(ally.getBruteLoss() > 0, "An NPC's shot aimed at its own ally passed over it")

	// A player on the same side still hits the ally in the way
	ally.fully_heal()
	target.fully_heal()
	shooter.key = "NpcFireOverAlliesTestKey"
	var/obj/item/ammo_casing/c38/player_round = allocate(/obj/item/ammo_casing/c38)
	TEST_ASSERT(player_round.fire_casing(target, shooter, null, 0, TRUE, BODY_ZONE_CHEST, 0, shooter), "The player's round didn't fire")
	wait_for_hit(ally)
	shooter.key = null
	TEST_ASSERT(ally.getBruteLoss() > 0, "A player's bullet passed over the ally in the way")
	TEST_ASSERT_EQUAL(target.getBruteLoss(), 0, "A player's bullet went through the ally in the way")

	// A shot someone else turns around stops sparing the NPC's side
	var/obj/projectile/bullet/c38/turned = allocate(/obj/projectile/bullet/c38, locate(start.x + 1, start.y, start.z))
	turned.impacted = list()
	turned.ignored_factions = shooter.faction.Copy()
	turned.npc_side_shooter = WEAKREF(shooter)
	turned.firer = shooter
	TEST_ASSERT(!turned.can_hit_target(ally, FALSE, TRUE), "Test fixture: the NPC's shot would hit its ally")
	turned.firer = target
	TEST_ASSERT(turned.can_hit_target(ally, FALSE, TRUE), "A reflected NPC shot still passes over the NPC's side")
	turned.firer = null

/// Waits up to two seconds for `victim` to take brute damage.
/datum/unit_test/voidcrew_npc_fire_over_allies/proc/wait_for_hit(mob/living/victim)
	for(var/i in 1 to 20)
		if(victim.getBruteLoss() > 0)
			return
		sleep(0.1 SECONDS)
