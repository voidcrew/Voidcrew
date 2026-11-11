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

/// A player body (a key, no client) at `where` with a Cascade lattice in it
/datum/unit_test/voidcrew_cyberware_timestop/proc/make_user(turf/where, key)
	var/mob/living/carbon/human/user = allocate(/mob/living/carbon/human/consistent, where)
	user.key = key
	var/obj/item/organ/cyberimp/cyberware/cascade/lattice = allocate(/obj/item/organ/cyberimp/cyberware/cascade)
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
