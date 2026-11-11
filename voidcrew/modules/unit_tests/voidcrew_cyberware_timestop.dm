/**
 * # The Cascade line's time stop
 *
 * voidcrew/modules/cyberware/ware_sandy_timestop.dm. A player's surge with no other player near stops time:
 * the field spawns, a human NPC is stunned with its AI paused, the user can still act, and the NPC is let go
 * when the stop runs out. Another player near means no stop at all. Uses the street rig (2 s stop) to keep
 * the waits short.
 */
/datum/unit_test/voidcrew_cyberware_timestop
	abstract_type = /datum/unit_test/voidcrew_cyberware_timestop

/// A player body (a key, no client) at `where` with the street rig in it
/datum/unit_test/voidcrew_cyberware_timestop/proc/make_user(turf/where, key)
	var/mob/living/carbon/human/user = allocate(/mob/living/carbon/human/consistent, where)
	user.key = key
	var/obj/item/organ/cyberimp/cyberware/cascade/street/rig = allocate(/obj/item/organ/cyberimp/cyberware/cascade/street)
	TEST_ASSERT(rig.Insert(user, special = TRUE), "Test fixture: the reflex rig wouldn't go in")
	return user

/// Opens the rig's window the way its surge button does
/datum/unit_test/voidcrew_cyberware_timestop/proc/surge(mob/living/carbon/human/user)
	var/obj/item/organ/cyberimp/cyberware/cascade/rig = locate() in user.organs
	return user.apply_status_effect(/datum/status_effect/cyberware_cascade_window, rig)

/// A turf `dx`, `dy` from the bottom left of the test room
/datum/unit_test/voidcrew_cyberware_timestop/proc/spot(dx, dy)
	return locate(run_loc_floor_bottom_left.x + dx, run_loc_floor_bottom_left.y + dy, run_loc_floor_bottom_left.z)

/datum/unit_test/voidcrew_cyberware_timestop/Destroy()
	for(var/mob/living/body in allocated)
		body.key = null
	return ..()

/// Nobody else near: time stops, the NPC freezes with its AI paused, the user can still act, and it all ends on time
/datum/unit_test/voidcrew_cyberware_timestop/alone

/datum/unit_test/voidcrew_cyberware_timestop/alone/Run()
	var/mob/living/carbon/human/user = make_user(spot(0, 0), "sandytimestopuser")
	var/mob/living/carbon/human/npc/raider = allocate(/mob/living/carbon/human/npc, spot(2, 0))
	var/datum/status_effect/cyberware_cascade_window/window = surge(user)
	TEST_ASSERT_NOTNULL(window, "The rig's window didn't open")
	sleep(0.1 SECONDS) // the field starts async
	TEST_ASSERT_NOTNULL(window.time_stop, "Time didn't stop with nobody else near")
	TEST_ASSERT(istype(window.time_stop.chronofield, /datum/proximity_monitor/advanced/timestop/sandevistan), "The stop has no field")

	TEST_ASSERT(raider.IsStun(), "The NPC wasn't frozen")
	TEST_ASSERT(HAS_TRAIT(raider, TRAIT_AI_PAUSED), "The NPC's AI kept running in stopped time")
	TEST_ASSERT(!user.IsStun(), "The user froze in their own time stop")
	TEST_ASSERT(!HAS_TRAIT(user, TRAIT_AI_PAUSED), "The user's AI was paused")
	var/turf/start = get_turf(user)
	user.Move(spot(0, 1), NORTH)
	TEST_ASSERT(get_turf(user) != start, "The user couldn't move in stopped time")

	// Frozen bodies still get hurt through tg.
	var/brute_before = raider.getBruteLoss()
	raider.apply_damage(10, BRUTE, BODY_ZONE_CHEST)
	TEST_ASSERT(raider.getBruteLoss() > brute_before, "A frozen NPC didn't take damage")

	sleep(2.3 SECONDS) // the street rig stops time for 2 s
	TEST_ASSERT_NULL(window.time_stop, "The time stop outlived its 2 s")
	TEST_ASSERT(!raider.IsStun(), "The NPC stayed frozen after time restarted")
	TEST_ASSERT(!HAS_TRAIT(raider, TRAIT_AI_PAUSED), "The NPC's AI stayed paused after time restarted")
	TEST_ASSERT(user.has_status_effect(/datum/status_effect/cyberware_cascade_window), "The window didn't carry on after the stop")
	user.remove_status_effect(/datum/status_effect/cyberware_cascade_window)
	user.remove_status_effect(/datum/status_effect/cyberware_cascade_crash)

/// Another player near: the plain surge, no stop
/datum/unit_test/voidcrew_cyberware_timestop/witnessed

/datum/unit_test/voidcrew_cyberware_timestop/witnessed/Run()
	var/mob/living/carbon/human/user = make_user(spot(0, 0), "sandytimestopuser")
	var/mob/living/carbon/human/other = allocate(/mob/living/carbon/human/consistent, spot(3, 3))
	other.key = "sandytimestopother" // a player body, client or not
	var/mob/living/carbon/human/npc/raider = allocate(/mob/living/carbon/human/npc, spot(2, 0))
	var/datum/status_effect/cyberware_cascade_window/window = surge(user)
	TEST_ASSERT_NOTNULL(window, "The rig's window didn't open")
	sleep(0.1 SECONDS)
	TEST_ASSERT_NULL(window.time_stop, "Time stopped with another player in sight")
	TEST_ASSERT(!raider.IsStun(), "The NPC froze without a time stop")
	TEST_ASSERT(!(locate(/obj/effect/timestop/sandevistan) in world), "A time stop field spawned with another player in sight")
	user.remove_status_effect(/datum/status_effect/cyberware_cascade_window)
	user.remove_status_effect(/datum/status_effect/cyberware_cascade_crash)
