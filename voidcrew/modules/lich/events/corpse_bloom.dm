/**
 * Ritual: Corpse Bloom: ship-scoped reflavor of TG's Zombie Outbreak
 * (code/modules/events/wizard/blobies.dm).
 *
 * The dead aboard one ship sit up as skeletons. Their bodies stay where they fell.
 *
 * TG's original is three lines: walk GLOB.dead_mob_list and put a
 * /mob/living/basic/blob_minion/spore/minion on top of every human corpse in the world. The
 * spore is a floating fungus that ventcrawls, explodes into a reagent cloud when killed, and
 * converts any corpse it touches into a blob zombie. None of that reads as necromancy, and
 * the contract calls for the deliberate reflavor: corpses rise as skeletons.
 *
 * Changed from the original:
 * - No blob. The riser is /mob/living/basic/skeleton: an existing ruin-defender mob with
 *   FACTION_SKELETON, 40 HP and a claw attack. Nothing about it spreads, ventcrawls, or
 *   converts further corpses, so the event cannot snowball out of the compartment it
 *   started in. That is a real reduction in danger versus TG's spore, and an intentional
 *   one: an unkillable self-spreading swarm inside a hull is not recoverable with ship tools.
 * - Corpses are NOT consumed. The skeleton tears out of the body and leaves it behind, so
 *   a defibrillator or cloner still works afterwards. TG's spore does eventually eat the
 *   corpse it zombifies; this one costs the crew the fight, not the crewmate.
 * - Scoped to the target ship's own dead, found through get_all_mobs_aboard(include_dead =
 *   TRUE). GLOB.dead_mob_list would raise every corpse in the galaxy including those lying
 *   in ruins, on planet surfaces and inside the lich's own lair.
 * - Spawn count capped at crew aboard + 2. A ship that has been through a bad fight can
 *   have a dozen bodies in the medbay; raising all of them at once is an instant wipe.
 * - The risers get /datum/component/ghost_direct_control, preserving the intent of TG's
 *   "Creates zombies which ghosts can control" comment. Ghosts who take one are the crew's
 *   own dead, which is the joke and the horror.
 */
/datum/round_event_control/voidcrew/lich/corpse_bloom
	name = "Ritual: Corpse Bloom"
	typepath = /datum/round_event/voidcrew/lich/corpse_bloom
	description = "Every corpse aboard the target ship rises as a skeleton, leaving the body behind."
	/**
	 * Generous, because corpse availability is already a harder throttle than any number
	 * here: is_valid_target() refuses any ship with nothing to raise, so this cannot fire
	 * on a crew that has not been losing people. Each firing is additionally capped at
	 * crew + 2 risers, the risers are 40 HP and DEL_ON_DEATH, and the bodies are left
	 * revivable. See the cap policy note in lich_events.dm.
	 */
	max_occurrences = 8
	event_scope = EVENT_SCOPE_SHIP
	min_wizard_trigger_potency = 3
	/**
	 * Extended to the top of the ramp rather than stopping at 6.
	 *
	 * Raising the dead is the most on-theme thing a lich can be doing at maximum potency,
	 * if any event belongs at 7 it is this one, and it gives the top band a repeatable
	 * SHIP-scoped option next to grave_dirt, so a long-lived lich keeps producing pressure
	 * from events authored to repeat instead of re-firing a one-shot.
	 */
	max_wizard_trigger_potency = 7

/// No corpses aboard, no bloom. Checked per-ship so the roster skips ships with nothing to raise.
/datum/round_event_control/voidcrew/lich/corpse_bloom/is_valid_target(obj/structure/overmap/ship/ship)
	. = ..()
	if(!.)
		return FALSE
	return length(get_ship_corpses(ship)) > 0

/// Human corpses lying inside the given ship's shuttle areas.
/datum/round_event_control/voidcrew/lich/corpse_bloom/proc/get_ship_corpses(obj/structure/overmap/ship/ship)
	var/list/corpses = list()
	for(var/mob/living/aboard_mob as anything in ship.get_all_mobs_aboard(include_dead = TRUE))
		if(!ishuman(aboard_mob) || QDELETED(aboard_mob))
			continue
		if(aboard_mob.stat != DEAD)
			continue
		corpses += aboard_mob
	return corpses

/datum/round_event/voidcrew/lich/corpse_bloom
	announce_when = 1
	/// Hard ceiling on risers, set from the crew aboard when the ritual lands.
	var/riser_cap = 0

/datum/round_event/voidcrew/lich/corpse_bloom/announce(fake)
	lich_announce_ship(
		"You have been storing my property in your freezer. I am collecting it. \
		The meat is yours to keep. I have never had any use for the meat.",
		"Corpse Bloom",
		'sound/effects/magic/RATTLEMEBONES.ogg',
	)

/datum/round_event/voidcrew/lich/corpse_bloom/start()
	if(!target_valid())
		return

	riser_cap = length(target_ship.get_event_crew()) + 2

	var/datum/round_event_control/voidcrew/lich/corpse_bloom/bloom_control = control
	var/list/corpses = istype(bloom_control) ? bloom_control.get_ship_corpses(target_ship) : list()
	if(!length(corpses))
		return
	shuffle_inplace(corpses) // Don't always raise the same end of the morgue.

	var/raised = 0
	for(var/mob/living/carbon/human/corpse as anything in corpses)
		if(raised >= riser_cap)
			break
		if(QDELETED(corpse))
			continue
		// Corpses can be dragged off the ship between validation and here.
		var/turf/rise_turf = get_turf(corpse)
		if(!rise_turf || !target_ship.is_aboard(rise_turf))
			continue
		if(!raise_skeleton(corpse, rise_turf))
			continue
		raised++

/**
 * Tears one skeleton out of one corpse. The corpse is left intact and revivable.
 * Returns TRUE if a riser was created.
 */
/datum/round_event/voidcrew/lich/corpse_bloom/proc/raise_skeleton(mob/living/carbon/human/corpse, turf/rise_turf)
	var/mob/living/basic/skeleton/riser = new(rise_turf)
	if(QDELETED(riser))
		return FALSE

	riser.name = "risen [corpse.real_name || corpse.name]"
	riser.desc = "The skeleton of [corpse.real_name || corpse.name], up and walking without the rest of them. \
		There's a faint green light where the eyes should be."
	rise_turf.visible_message(span_boldwarning("The bones tear their way out of [corpse] and stand up!"))
	playsound(rise_turf, 'sound/effects/magic/RATTLEMEBONES2.ogg', 60, TRUE)
	do_smoke(0, holder = riser, location = rise_turf)

	riser.AddComponent(\
		/datum/component/ghost_direct_control,\
		role_name = "risen skeleton",\
		poll_question = "Do you want to play as the skeleton of [corpse.real_name || corpse.name], raised by Ilthuun?",\
		assumed_control_message = span_boldwarning("You are the bones of [corpse.real_name || corpse.name]. \
			Something green is holding the pieces together, and it is not on your side."),\
	)
	announce_to_ghosts(riser)
	return TRUE
