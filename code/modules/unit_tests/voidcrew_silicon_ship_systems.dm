/**
 * # Silicons keep their ship
 *
 * Two invariants from voidcrew/edits/machinery/silicon_ship_systems.dm, both of which
 * fail silently and are only visible to someone who has already turned themselves into
 * an AI mid-round.
 *
 * ## The ship consoles must stay open to AIs
 *
 * /obj/machinery/computer/camera_advanced/attack_ai() is an upstream no-op, so the
 * weapons, survey and construction consoles are locked to silicons by default and the
 * helm - a plain computer - is not. Every one of those three needs its own override or
 * an AI is back to flying a ship it cannot fight, survey or repair with. Nothing warns
 * about this: the console simply does nothing when clicked, exactly like an unpowered
 * one. A retyped console, or a merge that reshuffles the camera_advanced tree, drops
 * the override without a compile error.
 *
 * ## The eye gate must key off the hull, not off `network`
 *
 * Camera scoping is enforced against the ship an AI is physically aboard
 * (is_in_shuttle_bounds), deliberately NOT against the AI's `network` var - `network`
 * is player-writable through the Jump To Network verb, so an implementation that
 * trusted it would hand the whole leak straight back. This is the sort of thing a
 * later "simplification" undoes, so pin it.
 *
 * Both are checked against source text rather than by flying a ship: a CIBUILDING world
 * boots MetaStation and has no overmap (see voidcrew_helpers.dm's header).
 */

/// The edit that opens the consoles up and scopes the eye.
#define SILICON_SHIP_EDIT_PATH "voidcrew/edits/machinery/silicon_ship_systems.dm"

/datum/unit_test/voidcrew_silicon_ship_systems

/datum/unit_test/voidcrew_silicon_ship_systems/Run()
	var/text = file2text(SILICON_SHIP_EDIT_PATH)
	TEST_ASSERT(text, "[SILICON_SHIP_EDIT_PATH] is missing - silicons are locked out of every ship console again")

	// The three camera_advanced consoles that make up a ship. The helm is absent on
	// purpose: it is a plain /obj/machinery/computer and was never blocked.
	var/static/list/ship_consoles = list(
		"/obj/machinery/computer/camera_advanced/ship_combat" = "the weapons console",
		"/obj/machinery/computer/camera_advanced/shuttle_docker/survey" = "the orbital survey console",
		"/obj/machinery/computer/camera_advanced/base_construction/ship" = "the hull construction console",
	)
	for(var/console_path in ship_consoles)
		TEST_ASSERT(findtext(text, "[console_path]/attack_ai"), \
			"[ship_consoles[console_path]] ([console_path]) has no attack_ai override, so upstream's no-op stub locks AIs out of it with no error shown")

	// The scope has to be read off the hull. `network` is retunable by the AI itself.
	TEST_ASSERT(findtext(text, "is_in_shuttle_bounds"), \
		"the AI camera scope no longer tests is_in_shuttle_bounds - if it moved to `network`, the Jump To Network verb re-opens every docked neighbour")
	TEST_ASSERT(findtext(text, "/mob/eye/camera/ai/setLoc"), \
		"the AI eye's setLoc override is gone - the eye can walk onto any hull sharing the z-level again")

	// Sight restoration on release. Upstream's AI reset_perspective() is
	// SHOULD_CALL_PARENT(FALSE) and never calls update_sight(), so an AI that leaves the
	// combat console keeps the BLIND that give_eye_control() set on it.
	TEST_ASSERT(findtext(text, "update_sight()"), \
		"nothing restores AI sight on perspective reset - an AI leaving the combat console stays blind, since its reset_perspective() never calls update_sight() upstream")

#undef SILICON_SHIP_EDIT_PATH
