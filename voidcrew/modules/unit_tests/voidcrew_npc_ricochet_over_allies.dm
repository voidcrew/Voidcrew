// A shot an NPC fired that bounces (rubber shot off a crate) does not home in on the NPC's own side
// (voidcrew/edits/modules/projectiles/projectile_npc_allies.dm). tg's bounce aims the shot at the mob nearest its new
// heading within ricochet_auto_aim_range and makes that mob the shot's `original`, which can_hit_target() hits as the
// direct target, past the side's pass-over and past the rule that a shot flies over people lying down. Soak pass 15:
// a tactical officer's rubber shot bounced off a crate beside its line and two pellets hit a colleague lying in crit
// on the officer's own tile.

/datum/unit_test/voidcrew_npc_ricochet_over_allies

/datum/unit_test/voidcrew_npc_ricochet_over_allies/Run()
	var/turf/start = run_loc_floor_bottom_left
	// crate (0,0) | empty (1,0) | shooter + ally lying (2,0) | enemy (3,0) | aimed past the crate at (0,0)
	var/obj/structure/closet/crate/crate = allocate(/obj/structure/closet/crate, start)
	TEST_ASSERT(crate.density, "Test fixture: the crate is not solid")
	var/turf/shooter_turf = locate(start.x + 2, start.y, start.z)
	// The ally was down there before the shooter stepped onto the tile, as in the soak: first in the tile's contents,
	// so first to be picked by the bounce's aim
	var/mob/living/carbon/human/consistent/ally = allocate(/mob/living/carbon/human/consistent, shooter_turf)
	var/mob/living/carbon/human/consistent/shooter = allocate(/mob/living/carbon/human/consistent, shooter_turf)
	var/mob/living/carbon/human/consistent/enemy = allocate(/mob/living/carbon/human/consistent, locate(start.x + 3, start.y, start.z))
	shooter.faction = list("npc_ricochet_test_side")
	ally.faction = list("npc_ricochet_test_side")
	enemy.faction = list("npc_ricochet_test_other")
	// Down as an officer in stamina crit is: floored, still able to move a hand
	ally.Knockdown(30 SECONDS)
	TEST_ASSERT_EQUAL(ally.body_position, LYING_DOWN, "Test fixture: the ally isn't lying down")
	shooter.set_combat_mode(TRUE)

	// A rubber shot pellet that bounces off the crate every time and straight back: tg's chance and angle rules for a
	// bounce are not what this test is about, only where the bounce sends the pellet
	var/obj/projectile/bullet/pellet/shotgun_rubbershot/pellet = allocate(/obj/projectile/bullet/pellet/shotgun_rubbershot, shooter_turf)
	pellet.ricochet_chance = 1000
	pellet.ricochet_incidence_leeway = 0
	pellet.firer = shooter
	pellet.fired_from = shooter
	pellet.hit_prone_targets = TRUE
	pellet.def_zone = BODY_ZONE_CHEST
	pellet.aim_projectile(start, shooter)
	pellet.fire()
	for(var/i in 1 to 30)
		if(QDELETED(pellet) || enemy.getBruteLoss() > 0 || enemy.getStaminaLoss() > 0)
			break
		sleep(0.1 SECONDS)
	TEST_ASSERT(pellet.ricochets > 0, "Test fixture: the pellet never bounced off the crate")
	TEST_ASSERT_EQUAL(ally.getBruteLoss() + ally.getStaminaLoss(), 0, "The NPC's bounced pellet homed in on its ally lying on the NPC's own tile")
	TEST_ASSERT_EQUAL(shooter.getBruteLoss() + shooter.getStaminaLoss(), 0, "The NPC's bounced pellet homed in on the NPC itself")
	TEST_ASSERT(enemy.getBruteLoss() + enemy.getStaminaLoss() > 0, "The NPC's bounced pellet no longer homes in on someone not of its side")
