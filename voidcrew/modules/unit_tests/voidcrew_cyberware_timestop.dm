/**
 * # The Cascade line's time dilation
 *
 * voidcrew/modules/cyberware/ware_sandy_timestop.dm. A player's surge with no other player near slows the
 * world: the Cascade lattice freezes it for 1 s (a human NPC is held by tg's immobilise, hand-block and
 * AI-pause traits, and its timers stop), then runs it at 20% for 3 s (the NPC walks under a movespeed
 * modifier), then lets go. The user can act the whole time. Another player near means no dilation at all.
 *
 * Unit-test files compile before voidcrew/_DEFINES/, so literals stand in for module defines.
 */
/datum/unit_test/voidcrew_cyberware_timestop
	abstract_type = /datum/unit_test/voidcrew_cyberware_timestop

/// A player body (a key, no client) at `where` with a Cascade lattice (or `lattice_type`) in it
/datum/unit_test/voidcrew_cyberware_timestop/proc/make_user(turf/where, key, lattice_type = /obj/item/organ/cyberimp/cyberware/cascade)
	var/mob/living/carbon/human/user = allocate(/mob/living/carbon/human/consistent, where)
	user.key = key
	var/obj/item/organ/cyberimp/cyberware/cascade/lattice = allocate(lattice_type)
	TEST_ASSERT(lattice.Insert(user, special = TRUE), "Test fixture: the lattice wouldn't go in")
	return user

/// Opens the lattice's window the way its surge button does
/datum/unit_test/voidcrew_cyberware_timestop/proc/surge(mob/living/carbon/human/user)
	var/obj/item/organ/cyberimp/cyberware/cascade/lattice = locate() in user.organs
	return user.apply_status_effect(/datum/status_effect/cyberware_cascade_window, lattice)

/// A turf `dx`, `dy` from the bottom left of the test room
/datum/unit_test/voidcrew_cyberware_timestop/proc/spot(dx, dy)
	return locate(run_loc_floor_bottom_left.x + dx, run_loc_floor_bottom_left.y + dy, run_loc_floor_bottom_left.z)

/datum/unit_test/voidcrew_cyberware_timestop/Destroy()
	for(var/mob/living/body in allocated)
		body.key = null
	return ..()

/// Nobody else near: the world freezes, then slows, then lets go on time; the user can act throughout
/datum/unit_test/voidcrew_cyberware_timestop/alone

/datum/unit_test/voidcrew_cyberware_timestop/alone/Run()
	var/mob/living/carbon/human/user = make_user(spot(0, 0), "sandytimestopuser")
	var/mob/living/carbon/human/npc/raider = allocate(/mob/living/carbon/human/npc, spot(2, 0))
	var/next_move_was = world.time + 5 SECONDS
	raider.next_move = next_move_was
	var/datum/status_effect/cyberware_cascade_window/window = surge(user)
	TEST_ASSERT_NOTNULL(window, "The lattice's window didn't open")
	sleep(0.1 SECONDS) // the field starts async
	TEST_ASSERT_NOTNULL(window.time_stop, "Time didn't slow with nobody else near")
	TEST_ASSERT(istype(window.time_stop.chronofield, /datum/proximity_monitor/advanced/timestop/sandevistan), "The dilation has no field")

	// The freeze: tg's own traits, no Stun.
	TEST_ASSERT(HAS_TRAIT(raider, TRAIT_IMMOBILIZED), "The NPC wasn't held still")
	TEST_ASSERT(HAS_TRAIT(raider, TRAIT_HANDS_BLOCKED), "The NPC's hands weren't stopped")
	TEST_ASSERT(HAS_TRAIT(raider, TRAIT_AI_PAUSED), "The NPC's AI kept running in frozen time")
	TEST_ASSERT(!raider.IsStun(), "The freeze stunned the NPC instead of holding it")
	TEST_ASSERT(!HAS_TRAIT(user, TRAIT_IMMOBILIZED) && !HAS_TRAIT(user, TRAIT_HANDS_BLOCKED), "The user froze in their own time stop")
	var/turf/start = get_turf(user)
	user.Move(spot(0, 1), NORTH)
	TEST_ASSERT(get_turf(user) != start, "The user couldn't move in frozen time")

	// Frozen bodies still get hurt through tg.
	var/brute_before = raider.getBruteLoss()
	raider.apply_damage(10, BRUTE, BODY_ZONE_CHEST)
	TEST_ASSERT(raider.getBruteLoss() > brute_before, "A frozen NPC didn't take damage")

	sleep(0.8 SECONDS) // still inside the Cascade's 1 s freeze
	TEST_ASSERT(raider.next_move > next_move_was + 0.5 SECONDS, "The NPC's timers ran on through frozen time")

	sleep(0.5 SECONDS) // then the world runs at 20%
	TEST_ASSERT_NOTNULL(window.time_stop, "The dilation ended with the freeze")
	TEST_ASSERT(!HAS_TRAIT(raider, TRAIT_IMMOBILIZED) && !HAS_TRAIT(raider, TRAIT_AI_PAUSED), "The NPC stayed frozen into the slow-mo")
	TEST_ASSERT(raider.has_movespeed_modifier(/datum/movespeed_modifier/cyberware_dilation), "The NPC isn't slowed in slow-mo")

	sleep(2.9 SECONDS) // the rest of the 3 s of slow-mo
	TEST_ASSERT_NULL(window.time_stop, "The dilation outlived its 4 s")
	TEST_ASSERT(!raider.has_movespeed_modifier(/datum/movespeed_modifier/cyberware_dilation), "The NPC stayed slow after the dilation")
	TEST_ASSERT(!HAS_TRAIT(raider, TRAIT_AI_PAUSED), "The NPC's AI stayed paused after the dilation")
	TEST_ASSERT(user.has_status_effect(/datum/status_effect/cyberware_cascade_window), "The window didn't carry on after the dilation")
	user.remove_status_effect(/datum/status_effect/cyberware_cascade_window)
	user.remove_status_effect(/datum/status_effect/cyberware_cascade_crash)

/// Another player near: the plain surge, no dilation
/datum/unit_test/voidcrew_cyberware_timestop/witnessed

/datum/unit_test/voidcrew_cyberware_timestop/witnessed/Run()
	var/mob/living/carbon/human/user = make_user(spot(0, 0), "sandytimestopuser")
	var/mob/living/carbon/human/other = allocate(/mob/living/carbon/human/consistent, spot(3, 3))
	other.key = "sandytimestopother" // a player body, client or not
	var/mob/living/carbon/human/npc/raider = allocate(/mob/living/carbon/human/npc, spot(2, 0))
	var/datum/status_effect/cyberware_cascade_window/window = surge(user)
	TEST_ASSERT_NOTNULL(window, "The lattice's window didn't open")
	sleep(0.1 SECONDS)
	TEST_ASSERT_NULL(window.time_stop, "Time slowed with another player in sight")
	TEST_ASSERT(!HAS_TRAIT(raider, TRAIT_IMMOBILIZED), "The NPC froze without a dilation")
	user.remove_status_effect(/datum/status_effect/cyberware_cascade_window)
	user.remove_status_effect(/datum/status_effect/cyberware_cascade_crash)

/// An NPC's surge never slows the world, whoever is near
/datum/unit_test/voidcrew_cyberware_timestop/npc_surge

/datum/unit_test/voidcrew_cyberware_timestop/npc_surge/Run()
	var/mob/living/carbon/human/user = make_user(spot(0, 0), null)
	var/datum/status_effect/cyberware_cascade_window/window = surge(user)
	TEST_ASSERT_NOTNULL(window, "The lattice's window didn't open")
	sleep(0.1 SECONDS)
	TEST_ASSERT_NULL(window.time_stop, "A surge with no player behind it slowed the world")
	user.remove_status_effect(/datum/status_effect/cyberware_cascade_window)
	user.remove_status_effect(/datum/status_effect/cyberware_cascade_crash)

/// Everything in the field runs on its own slowed clock: gore timing, do_after, bursts, mechs, turrets, fuses
/datum/unit_test/voidcrew_cyberware_timestop/slow_everything

/datum/unit_test/voidcrew_cyberware_timestop/slow_everything/Run()
	var/mob/living/carbon/human/user = make_user(spot(0, 0), "sandytimestopuser")
	var/mob/living/carbon/human/npc/raider = allocate(/mob/living/carbon/human/npc, spot(2, 0))
	var/obj/item/gun/ballistic/automatic/pistol/raider_gun = allocate(/obj/item/gun/ballistic/automatic/pistol)
	raider.put_in_hands(raider_gun)
	var/obj/item/gun/ballistic/automatic/pistol/user_gun = allocate(/obj/item/gun/ballistic/automatic/pistol)
	user.put_in_hands(user_gun)
	var/mob/living/basic/mouse/rat = allocate(/mob/living/basic/mouse, spot(1, 2))
	rat.AddComponent(/datum/component/ranged_attacks, projectile_type = /obj/projectile/beam, burst_shots = 3)
	var/obj/vehicle/sealed/mecha/ripley/mech = allocate(/obj/vehicle/sealed/mecha/ripley, spot(3, 2))
	var/obj/machinery/porta_turret/turret = allocate(/obj/machinery/porta_turret, spot(3, 1))
	var/obj/effect/decal/cleanable/blood/pool = allocate(/obj/effect/decal/cleanable/blood, spot(2, 1))
	var/obj/item/grenade/bomb = allocate(/obj/item/grenade, spot(1, 1))
	bomb.arm_grenade(null, 3 SECONDS, msg = FALSE)

	var/datum/status_effect/cyberware_cascade_window/window = surge(user)
	TEST_ASSERT_NOTNULL(window, "The lattice's window didn't open")
	sleep(0.1 SECONDS)
	TEST_ASSERT_NOTNULL(window.time_stop, "Time didn't slow with nobody else near")
	var/datum/proximity_monitor/advanced/timestop/sandevistan/field = window.time_stop.chronofield

	// The freeze: the NPC's own clock stands still, the user's doesn't.
	TEST_ASSERT_EQUAL(cyberware_time_lost(raider, 10), 10, "A frozen NPC's clock kept running")
	TEST_ASSERT_EQUAL(cyberware_time_lost(user, 10), 0, "The user's clock slowed")
	TEST_ASSERT_EQUAL(cyberware_dilated_time(user, 10), 10, "The user's animations would be slowed")
	TEST_ASSERT_NULL(cyberware_time_field(user_gun), "Something the user holds would be slowed")
	TEST_ASSERT(cyberware_dilated_time(raider, 1) > 5, "A frozen NPC's gore wouldn't wait out the freeze")
	TEST_ASSERT_NOTNULL(cyberware_time_field(pool), "Blood on the floor in the field isn't slowed")
	var/list/steps = cyberware_dilated_steps(raider, list(2, 2))
	TEST_ASSERT(length(steps) == 3 && steps[1] > 5 && steps[2] > 2, "A frozen NPC's flinch wouldn't hold, then play slow")

	// Bursts queued before the freeze wait for it.
	raider_gun.cyberware_burst_start = cyberware_burst_clock(raider)
	raider_gun.cyberware_burst_gap = 1
	var/datum/component/ranged_attacks/rat_gun = rat.GetComponent(/datum/component/ranged_attacks)
	rat_gun.cyberware_burst_start = cyberware_burst_clock(rat)
	var/gun_start = raider_gun.cyberware_burst_start
	var/rat_start = rat_gun.cyberware_burst_start

	// Machines and fuses.
	TEST_ASSERT(mech.completely_disabled, "A mech kept running in frozen time")
	TEST_ASSERT(turret.last_fired + turret.shot_delay > world.time, "A turret could fire in frozen time")
	TEST_ASSERT(field.held_grenades[bomb], "A lit grenade in the field wasn't taken")

	sleep(0.5 SECONDS)
	TEST_ASSERT(cyberware_burst_wait(raider, raider_gun.cyberware_burst_start, 1, 1) > 0, "A queued burst shot fired in frozen time")
	TEST_ASSERT(raider_gun.cyberware_burst_start > gun_start, "The NPC's burst clock wasn't pushed back")
	TEST_ASSERT(rat_gun.cyberware_burst_start > rat_start, "A basic mob's burst clock wasn't pushed back")
	TEST_ASSERT(turret.last_fired + turret.shot_delay > world.time, "A turret could fire in frozen time")

	sleep(0.6 SECONDS) // into the 20% slow-mo
	TEST_ASSERT(!mech.completely_disabled, "A mech stayed shut down into the slow-mo")
	var/lost = cyberware_time_lost(raider, 10)
	TEST_ASSERT(lost > 7.9 && lost < 8.1, "A slowed NPC's clock didn't run at 20% (lost [lost] of 10)")
	mech.cooldown_vehicle_move = world.time + 5
	var/move_at = mech.cooldown_vehicle_move
	sleep(0.5 SECONDS)
	TEST_ASSERT(mech.cooldown_vehicle_move > move_at, "A slowed mech's move cooldown wasn't pushed back")
	TEST_ASSERT(!(bomb.dud_flags & GRENADE_USED), "A grenade's fuse burned through at full speed")

	sleep(2.6 SECONDS) // past the end
	TEST_ASSERT_NULL(window.time_stop, "The dilation outlived its 4 s")
	TEST_ASSERT_EQUAL(cyberware_time_lost(raider, 10), 0, "The NPC's clock stayed slow after the dilation")
	TEST_ASSERT_NULL(cyberware_time_field(pool), "Blood stayed slowed after the dilation")
	TEST_ASSERT(!mech.completely_disabled, "The mech stayed shut down after the dilation")
	TEST_ASSERT(!(bomb.dud_flags & GRENADE_USED), "A grenade's fuse didn't lose its frozen and slowed time")
	TEST_ASSERT(bomb.cyberware_fuse_at > world.time, "A grenade's fuse has nothing left after losing time")
	bomb.cyberware_fuse_at = 0 // don't let it go off after the test
	user.remove_status_effect(/datum/status_effect/cyberware_cascade_window)
	user.remove_status_effect(/datum/status_effect/cyberware_cascade_crash)

/// Whether `thing` wears the dilation's tint
/datum/unit_test/voidcrew_cyberware_timestop/proc/tinted(atom/thing)
	return length(thing.atom_colours) >= TEMPORARY_COLOUR_PRIORITY && !isnull(thing.atom_colours[TEMPORARY_COLOUR_PRIORITY])

/// A raider NPC at `where` with its own Cascade lattice (or `lattice_type`)
/datum/unit_test/voidcrew_cyberware_timestop/proc/make_surger(turf/where, lattice_type = /obj/item/organ/cyberimp/cyberware/cascade)
	var/mob/living/carbon/human/npc/raider = allocate(/mob/living/carbon/human/npc, where)
	var/obj/item/organ/cyberimp/cyberware/cascade/lattice = allocate(lattice_type)
	TEST_ASSERT(lattice.Insert(raider, special = TRUE), "Test fixture: the lattice wouldn't go in the NPC")
	return raider

/// No reflex dodge while the user's own world is slowed; it comes back for the rest of the window
/datum/unit_test/voidcrew_cyberware_timestop/no_dodge_while_slowed

/datum/unit_test/voidcrew_cyberware_timestop/no_dodge_while_slowed/Run()
	var/mob/living/carbon/human/user = make_user(spot(0, 0), "sandytimestopuser")
	var/obj/item/knife/kitchen/knife = allocate(/obj/item/knife/kitchen, spot(1, 0))
	var/datum/status_effect/cyberware_cascade_window/window = surge(user)
	TEST_ASSERT_NOTNULL(window, "The lattice's window didn't open")
	window.dodge_chance = 100
	sleep(0.1 SECONDS)
	TEST_ASSERT_NOTNULL(window.time_stop, "Time didn't slow with nobody else near")
	var/datum/component/cyberware_dodge/arbiter = user.GetComponent(/datum/component/cyberware_dodge)
	TEST_ASSERT_NOTNULL(arbiter, "The window has no dodge")
	TEST_ASSERT(cyberware_time_stopping(user), "The user isn't marked as slowing time")
	TEST_ASSERT_EQUAL(arbiter.on_check_block(user, knife, 10, "the knife", MELEE_ATTACK), FAILED_BLOCK, "The user dodged a blow in frozen time")
	sleep(1.2 SECONDS)
	TEST_ASSERT_EQUAL(arbiter.on_check_block(user, knife, 10, "the knife", MELEE_ATTACK), FAILED_BLOCK, "The user dodged a blow in slow-mo")
	sleep(3 SECONDS) // past the dilation, still in the window
	TEST_ASSERT_NULL(window.time_stop, "The dilation outlived its 4 s")
	TEST_ASSERT(!cyberware_time_stopping(user), "The user still counts as slowing time")
	TEST_ASSERT_EQUAL(arbiter.on_check_block(user, knife, 10, "the knife", MELEE_ATTACK), SUCCESSFUL_BLOCK, "The dodge didn't come back after the dilation")
	user.remove_status_effect(/datum/status_effect/cyberware_cascade_window)
	user.remove_status_effect(/datum/status_effect/cyberware_cascade_crash)

/// An NPC already surging when the user slows the world runs at its own speed, and so do its shots
/datum/unit_test/voidcrew_cyberware_timestop/surging_npc_immune

/datum/unit_test/voidcrew_cyberware_timestop/surging_npc_immune/Run()
	var/mob/living/carbon/human/user = make_user(spot(0, 0), "sandytimestopuser")
	var/mob/living/carbon/human/npc/raider = make_surger(spot(2, 0))
	var/obj/projectile/bullet/shot = allocate(/obj/projectile/bullet, spot(1, 1))
	shot.firer = raider
	var/shot_speed = shot.speed
	TEST_ASSERT_NOTNULL(surge(raider), "The NPC's window didn't open")
	var/datum/status_effect/cyberware_cascade_window/window = surge(user)
	sleep(0.1 SECONDS)
	TEST_ASSERT_NOTNULL(window.time_stop, "Time didn't slow with nobody else near")
	var/datum/proximity_monitor/advanced/timestop/sandevistan/field = window.time_stop.chronofield
	TEST_ASSERT(field.surging[raider], "The field didn't notice the NPC's surge")
	TEST_ASSERT(!HAS_TRAIT(raider, TRAIT_IMMOBILIZED) && !HAS_TRAIT(raider, TRAIT_AI_PAUSED), "A surging NPC was frozen")
	TEST_ASSERT(!tinted(raider), "A surging NPC was tinted")
	TEST_ASSERT_EQUAL(cyberware_time_lost(raider, 10), 0, "A surging NPC's clock slowed")
	TEST_ASSERT_NULL(cyberware_time_field(raider), "A surging NPC's gore would be slowed")
	TEST_ASSERT(!field.held_shots[shot] && !shot.paused && shot.speed == shot_speed, "A surging NPC's shot was held")
	sleep(1.2 SECONDS) // into the slow-mo
	TEST_ASSERT(!raider.has_movespeed_modifier(/datum/movespeed_modifier/cyberware_dilation), "A surging NPC was slowed")

	// Its window closes: the field takes it like anyone else.
	raider.remove_status_effect(/datum/status_effect/cyberware_cascade_window)
	sleep(0.3 SECONDS)
	TEST_ASSERT(!field.surging[raider], "The field kept leaving the NPC be after its window closed")
	TEST_ASSERT(raider.has_movespeed_modifier(/datum/movespeed_modifier/cyberware_dilation), "The NPC wasn't slowed once its window closed")
	user.remove_status_effect(/datum/status_effect/cyberware_cascade_window)
	user.remove_status_effect(/datum/status_effect/cyberware_cascade_crash)
	raider.remove_status_effect(/datum/status_effect/cyberware_cascade_crash)

/// An NPC held in slow-mo that surges breaks free at once and drops every slow it carried
/datum/unit_test/voidcrew_cyberware_timestop/late_surge_breaks_free

/datum/unit_test/voidcrew_cyberware_timestop/late_surge_breaks_free/Run()
	var/mob/living/carbon/human/user = make_user(spot(0, 0), "sandytimestopuser")
	var/mob/living/carbon/human/npc/raider = make_surger(spot(2, 0))
	var/obj/projectile/bullet/shot = allocate(/obj/projectile/bullet, spot(1, 1))
	shot.firer = raider
	var/shot_speed = shot.speed
	var/datum/status_effect/cyberware_cascade_window/window = surge(user)
	sleep(0.1 SECONDS)
	TEST_ASSERT_NOTNULL(window.time_stop, "Time didn't slow with nobody else near")
	var/datum/proximity_monitor/advanced/timestop/sandevistan/field = window.time_stop.chronofield
	sleep(1.2 SECONDS) // into the slow-mo
	TEST_ASSERT(raider.has_movespeed_modifier(/datum/movespeed_modifier/cyberware_dilation), "Test fixture: the NPC isn't slowed")
	TEST_ASSERT(field.held_shots[shot], "Test fixture: the NPC's shot isn't held")
	raider.hv_vis_play("sandy_test_flinch", list(list(2, 0, matrix(), 2, LINEAR_EASING), list(0, 0, matrix(), 2, LINEAR_EASING)))
	TEST_ASSERT("sandy_test_flinch" in field.slowed_tags[raider], "A held NPC's slowed animation wasn't noted")

	TEST_ASSERT_NOTNULL(surge(raider), "The NPC's window didn't open")
	TEST_ASSERT(field.surging[raider], "The field didn't let the surging NPC go")
	TEST_ASSERT(!raider.has_movespeed_modifier(/datum/movespeed_modifier/cyberware_dilation), "The surging NPC stayed slowed")
	TEST_ASSERT(!HAS_TRAIT(raider, TRAIT_IMMOBILIZED) && !HAS_TRAIT(raider, TRAIT_AI_PAUSED), "The surging NPC stayed held")
	TEST_ASSERT(!tinted(raider), "The surging NPC stayed tinted")
	TEST_ASSERT_NULL(GLOB.cyberware_time_dilated[raider], "The surging NPC is still in the field's hands")
	TEST_ASSERT_EQUAL(cyberware_time_lost(raider, 10), 0, "The surging NPC's clock stayed slow")
	TEST_ASSERT_NULL(field.slowed_tags[raider], "The surging NPC's slowed animations weren't dropped")
	TEST_ASSERT(!field.held_shots[shot] && shot.speed == shot_speed, "The surging NPC's shot stayed slowed")
	sleep(0.5 SECONDS) // a few field ticks
	TEST_ASSERT(!raider.has_movespeed_modifier(/datum/movespeed_modifier/cyberware_dilation), "The field took the surging NPC back")
	user.remove_status_effect(/datum/status_effect/cyberware_cascade_window)
	user.remove_status_effect(/datum/status_effect/cyberware_cascade_crash)
	raider.remove_status_effect(/datum/status_effect/cyberware_cascade_window)
	raider.remove_status_effect(/datum/status_effect/cyberware_cascade_crash)

/// Ends `body`'s window and crash, for the end of a test
/datum/unit_test/voidcrew_cyberware_timestop/proc/end_surge(mob/living/body)
	body.remove_status_effect(/datum/status_effect/cyberware_cascade_window)
	body.remove_status_effect(/datum/status_effect/cyberware_cascade_crash)

/// A surging mob runs at its own multiplier over the user's, at most twice normal speed
/datum/unit_test/voidcrew_cyberware_timestop/relative_rates

/datum/unit_test/voidcrew_cyberware_timestop/relative_rates/Run()
	var/obj/item/organ/cyberimp/cyberware/cascade/street/street = allocate(/obj/item/organ/cyberimp/cyberware/cascade/street)
	var/obj/item/organ/cyberimp/cyberware/cascade/milspec/service = allocate(/obj/item/organ/cyberimp/cyberware/cascade/milspec)
	var/obj/item/organ/cyberimp/cyberware/cascade/cascade = allocate(/obj/item/organ/cyberimp/cyberware/cascade)
	TEST_ASSERT_EQUAL(street.time_multiplier, 2, "The street rig isn't 2x")
	TEST_ASSERT(abs(service.time_multiplier - 2.857) < 0.01, "The service lattice isn't about 2.86x ([service.time_multiplier])")
	TEST_ASSERT_EQUAL(cascade.time_multiplier, 5, "The Cascade isn't 5x")

	var/mob/living/carbon/human/user = make_user(spot(0, 0), "sandytimestopuser")
	var/datum/status_effect/cyberware_cascade_window/window = surge(user)
	sleep(0.1 SECONDS)
	TEST_ASSERT_NOTNULL(window.time_stop, "Time didn't slow with nobody else near")
	var/datum/proximity_monitor/advanced/timestop/sandevistan/field = window.time_stop.chronofield
	TEST_ASSERT_EQUAL(field.user_multiplier, 5, "A Cascade user's field doesn't know they run at 5x")
	TEST_ASSERT(abs(field.relative_rate(2) - 0.4) < 0.001, "A street surger in a Cascade's field isn't at 40%")
	TEST_ASSERT_EQUAL(field.relative_rate(5), 1, "An equal surger isn't at full speed")
	field.user_multiplier = 2 // as a street user's field
	TEST_ASSERT_EQUAL(field.relative_rate(5), 2, "A Cascade surger in a street user's field isn't capped at 200%")
	TEST_ASSERT(abs(field.relative_rate(1 / 0.35) - 1.4286) < 0.001, "A service surger in a street user's field isn't at about 143%")
	field.user_multiplier = 5
	end_surge(user)

/// A slower surger in the user's field is held at its relative rate through the freeze, never frozen or tinted
/datum/unit_test/voidcrew_cyberware_timestop/slower_surger

/datum/unit_test/voidcrew_cyberware_timestop/slower_surger/Run()
	var/mob/living/carbon/human/user = make_user(spot(0, 0), "sandytimestopuser")
	var/mob/living/carbon/human/npc/raider = make_surger(spot(2, 0), /obj/item/organ/cyberimp/cyberware/cascade/street)
	TEST_ASSERT_NOTNULL(surge(raider), "The NPC's window didn't open")
	var/datum/status_effect/cyberware_cascade_window/window = surge(user)
	sleep(0.1 SECONDS)
	TEST_ASSERT_NOTNULL(window.time_stop, "Time didn't slow with nobody else near")
	var/datum/proximity_monitor/advanced/timestop/sandevistan/field = window.time_stop.chronofield
	TEST_ASSERT(field.surging[raider], "The field didn't notice the NPC's surge")
	TEST_ASSERT(abs(cyberware_time_scale(raider) - 0.4) < 0.001, "A street surger in a Cascade's field isn't at 40% ([cyberware_time_scale(raider)])")
	TEST_ASSERT(!HAS_TRAIT(raider, TRAIT_IMMOBILIZED) && !HAS_TRAIT(raider, TRAIT_AI_PAUSED), "A surging NPC was frozen by the user's freeze")
	TEST_ASSERT(!tinted(raider), "A surging NPC was tinted")
	TEST_ASSERT(raider.has_movespeed_modifier(/datum/movespeed_modifier/cyberware_dilation), "A slower surger isn't slowed")
	var/lost = cyberware_time_lost(raider, 10)
	TEST_ASSERT(lost > 5.9 && lost < 6.1, "A slower surger's clock didn't run at 40% (lost [lost] of 10)")
	sleep(1.2 SECONDS) // into the user's slow-mo: the surger keeps its own rate
	TEST_ASSERT(abs(cyberware_time_scale(raider) - 0.4) < 0.001, "The thaw changed a surger's rate")
	end_surge(user)
	end_surge(raider)

/// A faster surger runs faster than normal: deadlines sooner, a quicker walk, quicker shots and gore
/datum/unit_test/voidcrew_cyberware_timestop/faster_surger

/datum/unit_test/voidcrew_cyberware_timestop/faster_surger/Run()
	var/mob/living/carbon/human/user = make_user(spot(0, 0), "sandytimestopuser", /obj/item/organ/cyberimp/cyberware/cascade/street)
	var/mob/living/carbon/human/npc/raider = make_surger(spot(2, 0))
	var/obj/projectile/bullet/shot = allocate(/obj/projectile/bullet, spot(1, 1))
	shot.firer = raider
	var/shot_speed = shot.speed
	var/datum/status_effect/cyberware_cascade_window/window = surge(user)
	sleep(0.1 SECONDS)
	TEST_ASSERT_NOTNULL(window.time_stop, "Time didn't slow with nobody else near")
	var/datum/proximity_monitor/advanced/timestop/sandevistan/field = window.time_stop.chronofield
	TEST_ASSERT_EQUAL(field.user_multiplier, 2, "A street user's field doesn't know they run at 2x")
	TEST_ASSERT(field.held_shots[shot], "Test fixture: the NPC's shot isn't held before it surges")

	TEST_ASSERT_NOTNULL(surge(raider), "The NPC's window didn't open")
	TEST_ASSERT_EQUAL(cyberware_time_scale(raider), 2, "A Cascade surger in a street user's field isn't capped at 200%")
	TEST_ASSERT(!tinted(raider), "A faster surger was tinted")
	TEST_ASSERT_EQUAL(cyberware_time_lost(raider, 10), -10, "A faster surger's clock doesn't run at double speed")
	TEST_ASSERT_EQUAL(cyberware_dilated_time(raider, 10), 5, "A faster surger's gore doesn't play at double speed")
	var/datum/movespeed_modifier/pace = raider.has_movespeed_modifier(/datum/movespeed_modifier/cyberware_dilation)
	TEST_ASSERT(pace && pace.multiplicative_slowdown <= 0, "A faster surger doesn't walk faster")
	TEST_ASSERT(field.held_shots[shot] && !shot.paused && shot.speed == shot_speed * field.time_scale, "A faster surger's shot doesn't fly at the field's pace")
	TEST_ASSERT(!tinted(shot), "A surger's shot was tinted")

	var/next_move_was = world.time + 5 SECONDS
	raider.next_move = next_move_was
	sleep(0.5 SECONDS) // a couple of field ticks
	TEST_ASSERT(raider.next_move < next_move_was - 0.3 SECONDS, "A faster surger's deadlines didn't come sooner")
	end_surge(user)
	end_surge(raider)

/// Every bullet in the field flies at the field's pace, whoever fired it: the user's and a surging NPC's alike, untinted
/datum/unit_test/voidcrew_cyberware_timestop/shots_at_field_pace

/datum/unit_test/voidcrew_cyberware_timestop/shots_at_field_pace/Run()
	var/mob/living/carbon/human/user = make_user(spot(0, 0), "sandytimestopuser")
	var/mob/living/carbon/human/npc/raider = make_surger(spot(3, 0))
	var/datum/status_effect/cyberware_cascade_window/window = surge(user)
	sleep(0.1 SECONDS)
	TEST_ASSERT_NOTNULL(window.time_stop, "Time didn't slow with nobody else near")
	var/datum/proximity_monitor/advanced/timestop/sandevistan/field = window.time_stop.chronofield
	TEST_ASSERT_NOTNULL(surge(raider), "The NPC's window didn't open")
	sleep(1.2 SECONDS) // into the slow-mo
	TEST_ASSERT(field.time_scale > 0 && field.time_scale < 1, "Test fixture: not in the slow-mo")

	var/obj/projectile/bullet/user_shot = allocate(/obj/projectile/bullet, spot(1, 0))
	user_shot.firer = user
	var/user_speed = user_shot.speed
	field.hang_shot(user_shot)
	TEST_ASSERT(field.held_shots[user_shot] && !user_shot.paused, "The user's slow-mo shot wasn't held")
	TEST_ASSERT_EQUAL(user_shot.speed, user_speed * field.time_scale, "The user's slow-mo shot doesn't crawl at the field's pace")
	TEST_ASSERT(!tinted(user_shot), "The user's slow-mo shot was tinted")

	var/obj/projectile/bullet/npc_shot = allocate(/obj/projectile/bullet, spot(2, 0))
	npc_shot.firer = raider
	var/npc_speed = npc_shot.speed
	field.freeze_atom(npc_shot)
	TEST_ASSERT(field.held_shots[npc_shot] && !npc_shot.paused, "A surging NPC's shot wasn't held")
	TEST_ASSERT_EQUAL(npc_shot.speed, npc_speed * field.time_scale, "A surging NPC's shot doesn't fly at the field's pace")
	TEST_ASSERT(!tinted(npc_shot), "A surging NPC's shot was tinted")

	sleep(3 SECONDS) // past the end
	TEST_ASSERT_NULL(window.time_stop, "The dilation outlived its 4 s")
	TEST_ASSERT_EQUAL(user_shot.speed, user_speed, "The user's shot didn't get its speed back")
	TEST_ASSERT_EQUAL(npc_shot.speed, npc_speed, "The NPC's shot didn't get its speed back")
	end_surge(user)
	end_surge(raider)

/// A surging NPC that dies is let go for good: its corpse isn't taken back and tinted
/datum/unit_test/voidcrew_cyberware_timestop/no_corpse_retake

/datum/unit_test/voidcrew_cyberware_timestop/no_corpse_retake/Run()
	var/mob/living/carbon/human/user = make_user(spot(0, 0), "sandytimestopuser")
	var/mob/living/carbon/human/npc/raider = make_surger(spot(2, 0), /obj/item/organ/cyberimp/cyberware/cascade/street)
	TEST_ASSERT_NOTNULL(surge(raider), "The NPC's window didn't open")
	var/datum/status_effect/cyberware_cascade_window/window = surge(user)
	sleep(0.1 SECONDS)
	TEST_ASSERT_NOTNULL(window.time_stop, "Time didn't slow with nobody else near")
	var/datum/proximity_monitor/advanced/timestop/sandevistan/field = window.time_stop.chronofield
	TEST_ASSERT(field.surging[raider], "Test fixture: the field didn't notice the NPC's surge")
	raider.death()
	sleep(0.5 SECONDS) // a couple of field ticks
	TEST_ASSERT(!field.surging[raider], "The field kept a dead surger as surging")
	TEST_ASSERT_NULL(GLOB.cyberware_time_dilated[raider], "The field took a dead surger back")
	TEST_ASSERT(!tinted(raider), "A dead surger's corpse was tinted")
	TEST_ASSERT(field.released[raider], "A dead surger wasn't let go for good")
	end_surge(user)
	end_surge(raider)

/// The user hears the slowed world slowed (ware_sandy_senses.dm): world sounds in the field take its pace and
/// a quiet low rumble in the freeze; their own sounds, sounds from outside the field and other listeners don't.
/datum/unit_test/voidcrew_cyberware_timestop/heard_slowed

/datum/unit_test/voidcrew_cyberware_timestop/heard_slowed/Run()
	var/mob/living/carbon/human/user = make_user(spot(0, 0), "sandytimestopuser")
	var/mob/living/carbon/human/npc/raider = allocate(/mob/living/carbon/human/npc, spot(3, 0))
	var/turf/far = locate(user.x + 40, user.y, user.z) || locate(1, user.y, user.z)
	TEST_ASSERT_EQUAL(cyberware_heard_speed(user, get_turf(raider), raider), 1, "A sound was slowed with no dilation running")
	var/datum/status_effect/cyberware_cascade_window/window = surge(user)
	sleep(0.1 SECONDS)
	TEST_ASSERT_NOTNULL(window.time_stop, "Time didn't slow with nobody else near")
	var/datum/proximity_monitor/advanced/timestop/sandevistan/field = window.time_stop.chronofield
	TEST_ASSERT_NOTNULL(field.senses, "The field has no senses for its user")

	// The freeze: a quiet, low rumble.
	var/frozen_speed = cyberware_heard_speed(user, get_turf(raider), raider)
	TEST_ASSERT(frozen_speed > 0 && frozen_speed < 0.5, "A world sound in the freeze played at [frozen_speed]")
	var/sound/shot = sound('sound/items/weapons/gun/pistol/shot.ogg')
	shot.volume = 100
	cyberware_dilate_heard(user, get_turf(raider), shot, raider)
	TEST_ASSERT(shot.frequency == frozen_speed, "A world sound in the freeze went out at frequency [shot.frequency]")
	TEST_ASSERT(shot.volume < 50, "A world sound in the freeze stayed loud ([shot.volume])")
	TEST_ASSERT_EQUAL(field.senses.loop_speed, frozen_speed, "The user's loops didn't slow in the freeze")

	// The user's own sounds, other listeners and far sounds stay as they are.
	TEST_ASSERT_EQUAL(cyberware_heard_speed(user, get_turf(user), raider), 1, "A sound on the user's own tile was slowed")
	TEST_ASSERT_EQUAL(cyberware_heard_speed(user, get_turf(raider), user), 1, "A sound the user set off was slowed")
	TEST_ASSERT_EQUAL(cyberware_heard_speed(raider, get_turf(raider), null), 1, "Someone other than the user heard it slowed")
	if(far && get_dist(far, user) > field.current_range)
		TEST_ASSERT_EQUAL(cyberware_heard_speed(user, far, null), 1, "A sound from outside the field was slowed")
	TEST_ASSERT_EQUAL(cyberware_scaled_frequency(44100, 0.5), 22050, "A rate in Hz didn't scale")
	TEST_ASSERT_EQUAL(cyberware_scaled_frequency(0, 0.2), 0.2, "An as-is sound didn't scale")

	sleep(1.2 SECONDS) // into the 20% slow-mo
	TEST_ASSERT_EQUAL(cyberware_heard_speed(user, get_turf(raider), raider), field.time_scale, "A world sound didn't take the slow-mo pace")
	TEST_ASSERT_EQUAL(field.senses.loop_speed, field.time_scale, "The user's loops didn't take the slow-mo pace")

	user.remove_status_effect(/datum/status_effect/cyberware_cascade_window)
	user.remove_status_effect(/datum/status_effect/cyberware_cascade_crash)
	TEST_ASSERT_NULL(window.time_stop, "Test fixture: the dilation outlived its window")
	TEST_ASSERT_EQUAL(cyberware_heard_speed(user, get_turf(raider), raider), 1, "Sounds stayed slowed after the dilation")

/// The user sees the weather slowed through a private override image per area; the area itself never changes,
/// and the images go when the dilation ends.
/datum/unit_test/voidcrew_cyberware_timestop/weather_slowed

/datum/unit_test/voidcrew_cyberware_timestop/weather_slowed/Run()
	var/mob/living/carbon/human/user = make_user(spot(1, 1), "sandytimestopuser")
	var/area/place = get_area(user)
	var/datum/weather/rain_storm/rain = new(list(user.z), list("areas" = list(place), "weather_flags" = WEATHER_INDOORS))
	TEST_ASSERT(rain.impacted_areas_lookup[place], "Test fixture: the rain didn't take the test room")
	rain.stage = MAIN_STAGE
	rain.update_areas()
	SSweather.processing |= rain
	var/list/area_overlays = place.overlays.Copy()

	var/datum/status_effect/cyberware_cascade_window/window = surge(user)
	sleep(0.1 SECONDS)
	TEST_ASSERT_NOTNULL(window.time_stop, "Time didn't slow with nobody else near")
	var/datum/proximity_monitor/advanced/timestop/sandevistan/field = window.time_stop.chronofield
	field.senses.refresh_weather(force = TRUE) // no client in a unit test
	var/image/frozen = field.senses.area_images[place]
	TEST_ASSERT_NOTNULL(frozen, "The rained-on area got no image")
	TEST_ASSERT(frozen.override, "The weather image doesn't replace the area's look")
	TEST_ASSERT(weather_states(frozen).Find("rain_high_still"), "The freeze didn't show still rain: [jointext(weather_states(frozen), ",")]")
	TEST_ASSERT(!weather_states(frozen).Find("rain_high"), "The fast rain is still in the freeze image")
	TEST_ASSERT_EQUAL(length(place.overlays), length(area_overlays), "The area's own overlays changed")

	sleep(1.2 SECONDS) // into the 20% slow-mo
	field.senses.refresh_weather(force = TRUE)
	var/image/slowed = field.senses.area_images[place]
	TEST_ASSERT(weather_states(slowed).Find("rain_high_s20"), "The slow-mo didn't show slowed rain: [jointext(weather_states(slowed), ",")]")

	user.remove_status_effect(/datum/status_effect/cyberware_cascade_window)
	user.remove_status_effect(/datum/status_effect/cyberware_cascade_crash)
	TEST_ASSERT_NULL(window.time_stop, "Test fixture: the dilation outlived its window")
	TEST_ASSERT_NULL(field.senses, "The senses outlived the dilation")
	TEST_ASSERT_EQUAL(length(place.overlays), length(area_overlays), "The area's own overlays changed after the dilation")

	SSweather.processing -= rain
	rain.stage = END_STAGE
	rain.update_areas()
	qdel(rain)

/// The icon states of `slowed`'s overlays.
/datum/unit_test/voidcrew_cyberware_timestop/weather_slowed/proc/weather_states(image/slowed)
	. = list()
	for(var/overlay in slowed.overlays)
		. += overlay:icon_state
