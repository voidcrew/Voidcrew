/**
 * # Babel cure conformance
 *
 * The Verdigris used to port upstream's Tower of Babel as a galaxy-wide rite.
 * The rite is gone (the lich is a status beacon and an opt-in raid now), but it
 * exposed two real holes in upstream's cure path
 * (code/modules/spells/spell_types/tower_of_babel.dm), both of which strand a
 * player with a permanent language block that only an admin verb can lift.
 * This pins the fixes for the wizard event and the admin verb, which still use
 * that path:
 *
 * - **The cure sweep must walk GLOB.carbon_list, not GLOB.player_list.**
 *   player_list only holds mobs with a client, and a dead player who ghosted
 *   leaves their cursed body clientless, so they revive still babbling after
 *   the controller is destroyed (the original shipped bug).
 * - **cure_curse_of_babel() must cure a body with no mind.** The babel trait
 *   lives on the mind but the permanent status effect lives on the body, and
 *   /datum/mind/transfer_to() nulls the old body's mind pointer. A cure that
 *   early-outs on !mind permanently strands any body whose mind left mid-curse
 *   (respawn into a fresh hull, borging, a mind swap): whoever returns to that
 *   body is babbling with no controller left alive to cure them.
 */
/datum/unit_test/babel_cure

/datum/unit_test/babel_cure/Run()
	var/datum/tower_of_babel/preexisting = GLOB.tower_of_babel
	GLOB.tower_of_babel = null

	// A cursed body with no client: the state a dead-and-ghosted player's corpse
	// is in when the controller is destroyed.
	var/mob/living/carbon/human/consistent/clientless = allocate(/mob/living/carbon/human/consistent)
	clientless.mind_initialize()
	// A cursed body whose mind will leave mid-curse.
	var/mob/living/carbon/human/consistent/mindless = allocate(/mob/living/carbon/human/consistent)
	mindless.mind_initialize()

	GLOB.tower_of_babel = new /datum/tower_of_babel
	curse_of_babel(clientless)
	curse_of_babel(mindless)
	TEST_ASSERT(clientless.has_status_effect(/datum/status_effect/tower_of_babel/magical), "curse_of_babel() did not land on the clientless test victim, so the cure half of this test cannot run")
	TEST_ASSERT(mindless.has_status_effect(/datum/status_effect/tower_of_babel/magical), "curse_of_babel() did not land on the mind-null test victim, so the cure half of this test cannot run")

	// What /datum/mind/transfer_to() does to the body left behind: the mind
	// datum lives on (in the new body), the old body's pointer is nulled.
	var/datum/mind/departed_mind = mindless.mind
	mindless.mind = null

	// Destroying the controller is the only cure path the game ever runs.
	QDEL_NULL(GLOB.tower_of_babel)
	TEST_ASSERT(!clientless.has_status_effect(/datum/status_effect/tower_of_babel/magical), "the cure sweep missed a clientless cursed body. It has to walk GLOB.carbon_list, not GLOB.player_list: a dead player who ghosted is not on player_list, and revives still babbling")
	TEST_ASSERT(!mindless.has_status_effect(/datum/status_effect/tower_of_babel/magical), "cure_curse_of_babel() refused a cursed body with no mind. transfer_to() nulls the old body's mind pointer, so a respawned, borged or mind-swapped player's original body stays cursed forever with no controller left to cure it")

	// A minded body that was never cursed by this source must pass through the
	// cure untouched (the trait check is what protects it).
	cure_curse_of_babel(clientless)
	TEST_ASSERT(!clientless.has_status_effect(/datum/status_effect/tower_of_babel/magical), "a second cure call on an already-cured body did something. The trait early-out is broken")

	// Restore the pointer so allocate()'s teardown sees an ordinary mob.
	mindless.mind = departed_mind
	GLOB.tower_of_babel = preexisting
