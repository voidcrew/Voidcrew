/**
 * Ship-scoped port of TG's Carp Migration (code/modules/events/carp_migration.dm).
 *
 * TG spawns a carp on every `/obj/effect/landmark/carpspawn` on the map and points the
 * school at the station. No voidcrew hull has those landmarks, and the global sweep would
 * seed carp across every loaded z-level anyway, so the shoal is built out of the debris
 * corridor instead (voidcrew/modules/dynamic_events/ship_debris.dm): carp appear in the
 * vacuum around the target ship, where they are a genuine problem for anyone doing EVA
 * and scenery for everyone else.
 *
 * Getting inside is handled by the frozen-carp meteor, which already exists upstream and
 * does exactly the right thing. Punches through the plating and leaves a live carp in
 * the compartment. That is the boarding half of the event; the swimmers outside are the
 * warning that it is coming.
 *
 * Carp are confined the same way rocks are, so one that loses interest and swims off is
 * removed rather than left to drift into the reservation next door. That reads as the
 * shoal moving on, which is what a migration does.
 */
/datum/round_event_control/voidcrew/carp_migration
	name = "Carp Migration"
	typepath = /datum/round_event/voidcrew/carp_migration
	weight = 6
	max_occurrences = 4
	earliest_start = 10 MINUTES
	category = EVENT_CATEGORY_ENTITIES
	description = "A school of space carp crosses the target ship."
	requires_flying = TRUE
	/// Not a green-band event: two in five ticks launch a carp frozen inside a rock, which
	/// comes through the hull rather than past it. Hostile boarders plus a breach to weld
	/// is not what the outer ring is for.
	allowed_zones = list(ZONE_YELLOW, ZONE_RED)
	/// Carp that get inside have to be fought in a corridor. On a hull with one room the
	/// first breach puts a carp on top of everybody at once.
	min_ship_mass = SHIP_MASS_SMALL
	min_wizard_trigger_potency = 0
	max_wizard_trigger_potency = 3

/datum/round_event/voidcrew/carp_migration
	announce_when = 3
	start_when = 12
	end_when = 40
	fakeable = TRUE
	/// Ordinary shoal member.
	var/mob/living/basic/carp/carp_type = /mob/living/basic/carp
	/// The rare one. Announced to ghosts in preference to the others.
	var/mob/living/basic/carp/boss_type = /mob/living/basic/carp/mega
	/// Whether a fish has already been shown to observers.
	var/announced_to_ghosts = FALSE

/datum/round_event/voidcrew/carp_migration/announce(fake)
	if(!target_valid())
		return
	var/signal = pick("Unknown biological entities", "A large biological mass", "Unidentified lifesigns", "Something with teeth")
	target_ship.ship_event_announce("[signal] detected closing on our position. Stay out of the airlocks.", "Lifesign Alert")

/// The shoal arrives outside all at once.
/datum/round_event/voidcrew/carp_migration/start()
	if(!target_valid())
		return
	for(var/i in 1 to rand(3, 6))
		spawn_shoal_member()

/**
 * Stragglers keep arriving for the length of the event, and every so often one of them
 * arrives frozen inside a rock and comes through the hull instead of past it.
 */
/datum/round_event/voidcrew/carp_migration/tick()
	if(!target_valid())
		return
	if(target_ship.state != OVERMAP_SHIP_FLYING || target_ship.docked)
		return
	if(activeFor % 6)
		return

	if(prob(40))
		target_ship.launch_ship_debris(/obj/effect/meteor/carp)
		return
	spawn_shoal_member()

/// Puts one carp in the vacuum around the hull.
/datum/round_event/voidcrew/carp_migration/proc/spawn_shoal_member()
	var/is_boss = prob(5)
	var/mob/living/basic/carp/fish = target_ship.launch_ship_debris(is_boss ? boss_type : carp_type)
	if(!fish)
		return
	// Prefer to show observers the big one.
	if(is_boss || !announced_to_ghosts)
		announce_to_ghosts(fish)
		announced_to_ghosts = TRUE
