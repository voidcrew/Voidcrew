/**
 * Ritual: Grave Air: ship-scoped, no upstream original.
 *
 * The air aboard goes to rot for a minute. Anyone breathing it is slowly poisoned; anyone
 * on internals is fine.
 *
 * The third hazard rite, and the third distinct verb: The Floor Is Grave-Dirt is answered
 * by getting off the floor, The Cold of the Ground by putting something on, and this one by
 * closing your mask. All three self-terminate, damage nothing structural, and leave the ship
 * exactly as they found it, which is the whole roster policy after the item-cursing rites
 * were cut (see lich_events.dm).
 *
 * It is not an atmospherics event and deliberately touches no gas mixture. Editing the air
 * in a hull would outlive the rite: scrubbers have to chew through it, a breach vents it,
 * and a crew that undocks mid-rite carries the mess with them. The poison is applied
 * directly to mobs for exactly as long as the rite runs, so "it stops when it stops" is
 * true without any cleanup pass at all.
 *
 * Internals are checked through `carbon.internal || carbon.external`
 * (carbon_defines.dm:37-39), the same pair the breath code uses, so a tank on the back with
 * the mask down protects you and a tank in your bag does not. Non-carbons have no internals
 * and no mask; they are hit and there is nothing they can do about it, which is the same
 * deal the other two rites give ship fauna.
 */

/// Toxin per tick to anything breathing ship air. Two seconds a tick, ~30 ticks of rite:
/// a crewmember who ignores it entirely ends the minute badly hurt but alive and curable,
/// which is the ceiling every hazard rite is written to.
#define GRAVE_AIR_TOXIN 1.5

/datum/round_event_control/voidcrew/lich/grave_air
	name = "Ritual: Grave Air"
	typepath = /datum/round_event/voidcrew/lich/grave_air
	description = "The air aboard the target ship turns to rot for about a minute. Internals answer it."
	/// Repeatable for the same reasons as the other two hazards, and one of the three
	/// answers the top band needs, see the cap policy in lich_events.dm.
	max_occurrences = 10
	event_scope = EVENT_SCOPE_SHIP
	min_wizard_trigger_potency = 3
	max_wizard_trigger_potency = 7

/datum/round_event/voidcrew/lich/grave_air
	announce_when = 1
	/// Fifteen seconds to find a mask, matching the other hazard rites' telegraph.
	start_when = 8
	/// About a minute of bad air.
	end_when = 38

/datum/round_event/voidcrew/lich/grave_air/announce(fake)
	lich_announce_ship(
		"You are all breathing the same room. I have put something of mine in it. \
		Nothing clever: it is only the smell of a grave, and what comes with the smell. \
		Close your masks or don't; it is a minute either way.",
		"Grave Air",
		'sound/effects/magic/curse.ogg',
	)
	for(var/mob/living/warned as anything in target_ship.get_all_mobs_aboard())
		to_chat(warned, span_warning("The air thickens and starts to smell like turned soil. Internals would fix this."))

/datum/round_event/voidcrew/lich/grave_air/start()
	if(!target_valid())
		kill()
		return
	build_rite_overlays("ash_storm", overlay_alpha = 80)
	refresh_rite_overlays()
	for(var/mob/living/victim as anything in target_ship.get_all_mobs_aboard())
		to_chat(victim, span_userdanger("The air goes rotten. Get on internals!"))

/datum/round_event/voidcrew/lich/grave_air/tick()
	if(!target_valid())
		return
	refresh_rite_overlays()
	for(var/mob/living/victim as anything in target_ship.get_all_mobs_aboard())
		if(QDELETED(victim) || !is_breathing_it(victim))
			continue
		victim.adjustToxLoss(GRAVE_AIR_TOXIN, forced = TRUE)
		if(prob(12))
			victim.emote("cough")

/datum/round_event/voidcrew/lich/grave_air/end()
	remove_rite_overlays()
	if(!target_valid())
		return
	for(var/mob/living/victim as anything in target_ship.get_all_mobs_aboard())
		to_chat(victim, span_notice("The air thins out and stops tasting of soil."))

/// TRUE if this mob is taking the rotten air into itself right now.
/datum/round_event/voidcrew/lich/grave_air/proc/is_breathing_it(mob/living/victim)
	if(issilicon(victim))
		return FALSE
	if(HAS_TRAIT(victim, TRAIT_NOBREATH) || HAS_TRAIT(victim, TRAIT_WEATHER_IMMUNE))
		return FALSE
	if(iscarbon(victim))
		var/mob/living/carbon/carbon_victim = victim
		if(carbon_victim.internal || carbon_victim.external)
			return FALSE // On a tank. That is the whole counterplay.
	// A mob inside a locker, a mech or a sleeper is breathing that thing's air, not the
	// room's; a mob that has left the hull since the last tick is not breathing this at all.
	if(!isturf(victim.loc))
		return FALSE
	return target_ship.is_aboard(victim.loc)

#undef GRAVE_AIR_TOXIN
