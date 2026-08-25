/**
 * Ship-scoped port of TG's Immovable Rod (code/modules/events/immovable_rod/).
 *
 * TG spawns the rod off the edge of the station z-level and aims it at the far side of
 * the map. Here it enters one wall of the target ship's debris corridor and leaves
 * through the other, and nothing outside that corridor ever sees it, see
 * voidcrew/modules/dynamic_events/ship_debris.dm.
 *
 * The rod phases through everything, so unlike a meteor it never runs out of hits and
 * stops; it needs a destination it can actually arrive at (it deletes itself on
 * arrival), which is why this is the one launch that aims past the hull rather than at
 * it. The corridor cull is the backstop if it somehow misses that turf.
 */
/datum/round_event_control/voidcrew/immovable_rod
	name = "Immovable Rod"
	typepath = /datum/round_event/voidcrew/immovable_rod
	// Admin-only. announce_when is 5 and start_when is 4, so the warning lands a tick AFTER
	// the rod has already crossed the hull, and the warning is a punchline rather than an
	// instruction. Whoever was standing in its path is dead before they are told anything.
	weight = 0
	max_occurrences = 0
	earliest_start = 30 MINUTES
	min_crew_aboard = 2
	category = EVENT_CATEGORY_SPACE
	description = "A rod passes clean through the target ship."
	allowed_zones = list(ZONE_RED)
	requires_flying = TRUE
	/// The rod cuts a line clean through whatever it enters. On a hull small enough for
	/// that line to be the whole ship, it is not an event, it is a delete key.
	min_ship_mass = SHIP_MASS_LARGE
	min_wizard_trigger_potency = 6
	max_wizard_trigger_potency = 7

/datum/round_event/voidcrew/immovable_rod
	announce_when = 5
	start_when = 4
	fakeable = FALSE

/datum/round_event/voidcrew/immovable_rod/announce(fake)
	if(!target_valid())
		return
	target_ship.ship_event_announce("What the fuck was that?!", "General Alert")

/datum/round_event/voidcrew/immovable_rod/start()
	if(!target_valid())
		return
	var/atom/rod = target_ship.launch_ship_debris(/obj/effect/immovablerod, aim_past_hull = TRUE)
	if(!rod)
		return
	announce_to_ghosts(rod)
