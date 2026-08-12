/**
 * Ritual event roster for The Verdigris, Ilthuun, the Verdigris Lich.
 *
 * These are the magic events the lich's ritual clock fires as his potency ramps from
 * 0 to 7. They are copy-adapted ports of /tg/'s wizard events (code/modules/events/wizard/),
 * never subtypes of them: DM has single inheritance, the TG datums hang off
 * /datum/round_event_control/wizard, and every one of them assumes a single station
 * z-level that this fork does not have. See voidcrew/GUIDES/dynamic_events_port_spec.md
 * for the porting rules and voidcrew/modules/dynamic_events/ for the framework.
 *
 * ## How these get fired
 *
 * NOT by SSdynamic_events. That subsystem builds its roster out of every
 * /datum/round_event_control/voidcrew in SSevents.control and rolls it on a weighted
 * timer; a lich curse landing on a crew with no lich in the galaxy is nonsense. Two
 * independent gates keep them out of it:
 *
 * 1. `wizardevent = TRUE`. Upstream's can_spawn_event() rejects any event whose
 *    `wizardevent` flag disagrees with SSevents.wizardmode unless the caller passes
 *    `allow_magic = TRUE`. SSdynamic_events calls can_spawn_event(players_amt) with the
 *    default, so every lich event fails there. This is the same mechanism TG's grand
 *    ritual rune relies on (code/modules/antagonists/wizard/grand_ritual/grand_rune.dm:205).
 * 2. `can_spawn_event()` additionally requires GLOB.lich_lair to exist. No lair, no rituals.
 *
 * The ritual clock selects from this roster: see
 * /obj/structure/overmap/space_ruin/lich_lair/proc/get_ritual_roster() in
 * voidcrew/modules/lich/lich_site.dm, which filters SSevents.control by
 * /datum/round_event_control/voidcrew/lich, applies the potency window inclusively, and
 * passes `allow_magic = TRUE`. That last part is load-bearing: any other caller that fires
 * one of these by hand must pass it too, or gate 1 above eats the entire roster silently.
 *
 * ## Cap policy: why max_occurrences is what it is
 *
 * The ritual clock plateaus. Potency climbs to LICH_MAX_POTENCY and then stays there, so a
 * lich nobody kills fires potency-7 rituals every LICH_RITUAL_INTERVAL for the rest of the
 * round. The roster has to be able to answer that indefinitely, and there is no relaxed
 * fallback pass to paper over it: if nothing in the band is eligible, the ritual fires
 * nothing, which is an acceptable miss but must not become the steady state.
 *
 * So the band splits into two kinds of event, deliberately:
 *
 * - **Repeatable pressure**: ship-scoped, self-terminating, recoverable with ordinary ship
 *   and medical tools. These carry high caps and are what a long-lived lich actually runs
 *   on: grave_dirt (20), grave_chill (12), grave_air (10), corpse_bloom (8). The three
 *   hazards are the spine of the roster; grave_air and corpse_bloom reach potency 7 with
 *   grave_dirt so the top band always has more than one repeatable answer.
 *   Caps count RITUALS, not hulls: a ship-scoped rite fires one event instance per crewed
 *   ship and fire_ritual_on_every_ship() puts `occurrences` back to one per ritual, so a
 *   busy galaxy does not burn through a cap faster than an empty one.
 * - **Round-warping one-shots**: galaxy-scoped and lasting for the round:
 *   tongues_of_the_dead, mockery_of_heroes, restless_dead, unquiet_menagerie. These stay
 *   at max_occurrences = 1 forever. They are the last things on the roster that outlive
 *   their own firing, and they survive rule 2 on the grounds that none of them costs a
 *   player an item, a limb or a brain: a scrambled language, a title under your feet, ghosts
 *   you can see, more cats than you had. If one of them starts reading as a chore rather
 *   than a round-long joke, it goes the same way the other four did. Firing them twice is not more interesting, and two of
 *   them install global controllers that must not be duplicated at all (their
 *   can_spawn_event() overrides refuse a second instance outright).
 *
 * If the top of the ramp ever feels thin, the correct fix is a new repeatable ship-scoped
 * hazard or another band widened upward, never a raised cap on a one-shot.
 *
 * ## Two rules about what a ritual may do
 *
 * **1. A ritual never hands the crew power.** Ilthuun does not arm his raiders. TG's wizard
 * roster includes Summon Magic (a random magical item to every crewmember) and Summon Guns;
 * a port of Summon Magic lived here and was removed, and Summon Guns was never ported. A
 * ritual that gives the crew a working weapon or spell inverts the whole pressure system.
 * The clock is supposed to make the galaxy worse until somebody goes and kills him, and the
 * reward for reaching him is his hoard plus the spell his death disperses (lich_loot.dm).
 * Handing that out for free on the way there costs the raid its only payoff and rewards
 * every crew that ignored him.
 *
 * **2. A ritual never leaves a permanent mark, on the crew's property or on the crew.**
 * No curses on items, no renaming or re-rolling what people own, and no lasting damage to a
 * body or a mind that outlives the rite. Four rites used to, and all four are gone:
 * grave_goods (nodrop cursed clothing forced onto everyone), grasping_bones (every item
 * aboard permanently barbed and renamed), mockery_of_treasure (every item in the galaxy
 * renamed and stat-rolled for the round), and whispers_of_the_green (brain traumas at
 * TRAUMA_RESILIENCE_LOBOTOMY: surgery or nothing, for the rest of the round).
 *
 * None of those were dangerous. They were *annoying*, which is worse: a crew spends the rest
 * of the round managing the leftovers of a rite that stopped being a threat forty seconds
 * after it fired, and no amount of playing well undoes any of it. A rite that is over should
 * be over.
 *
 * What is left is the shape the roster wants: **temporary hazards with a verb attached.**
 * The deck burns and you get on top of something (grave_dirt); the hull goes cold and you
 * put something on (grave_chill); the air rots and you close your mask (grave_air). Each
 * runs about a minute, ends on its own, costs damage that heals, and leaves the ship
 * exactly as it found it. New rites should look like those three. Animating the dead,
 * moving people around, taking a sense away for a while, all fine. Leaving a mess the
 * crew has to clean up after he is dead, not fine.
 *
 * ## Scoping: every ritual reaches every crew
 *
 * EVENT_SCOPE_SHIP events resolve every location through a target ship's shuttle areas,
 * so trader outposts, ruins and bystander structures are structurally untouchable. In the
 * ambient framework one victim ship is rolled per event. **The lich does not work that
 * way**: fire_ritual_on_every_ship() (lich_site.dm) runs a ship-scoped rite once per
 * crewed ship, one independent event instance each, so a rite lands on everybody flying
 * with people aboard. EVENT_SCOPE_GALAXY events have no target ship and reach everyone by
 * their own machinery. The two scopes are therefore a difference in plumbing, not in who
 * gets hit, a crew three sectors from the lair is not a spectator.
 *
 * The only crews a ship-scoped rite skips are those docked at a trader outpost
 * (`allow_in_safe_harbor = FALSE`, inherited): NPC outposts never take collateral, and
 * hostiles or hazards spawned aboard a docked ship can walk off it.
 *
 * Consequence worth knowing: every instance stamps its ship's `last_dynamic_event`, so
 * while Ilthuun is working the whole fleet is on ambient-event cooldown and
 * SSdynamic_events goes quiet. That is the intended reading, the lich owns the pressure
 * budget for as long as he is alive, and it reverses on its own when he dies.
 *
 * ## Voice
 *
 * Every announcement, chat line and flavor string is Ilthuun's: grandiose, contemptuous,
 * rotting, and green. No "wizard" wording survives anywhere in this directory.
 */

/**
 * Base control for every ritual event.
 *
 * Subtypes set `min_wizard_trigger_potency` / `max_wizard_trigger_potency` to place
 * themselves on the ramp. Those two vars already exist on /datum/round_event_control
 * (code/modules/events/_event.dm:29-31) and are otherwise unused in this fork.
 */
/datum/round_event_control/voidcrew/lich
	category = EVENT_CATEGORY_WIZARD
	/// Blocks natural SSdynamic_events rolls; see the file header. Track A must pass allow_magic = TRUE.
	wizardevent = TRUE
	earliest_start = 0 MINUTES
	min_players = 0
	weight = 10
	max_occurrences = 1
	event_scope = EVENT_SCOPE_SHIP
	min_crew_aboard = 1
	/**
	 * Exempt from the ambient per-ship cooldown (framework flag, event_base.dm).
	 *
	 * LICH_RITUAL_INTERVAL is 4 minutes and the ambient per-ship cooldown is longer than
	 * that, so on a single-crewed-ship server the ambient cooldown would refuse most
	 * ship-scoped rituals, and an unrelated SSdynamic_events event landing on that
	 * ship first would silently swallow the next one. The ritual clock is a driven
	 * pressure system with its own cadence and its own escalation ceiling, so the ambient
	 * anti-spam throttle is the wrong governor for it.
	 *
	 * These events still stamp last_dynamic_event, so ambient events keep backing off a
	 * ship the lich just hit. The exemption runs one way only, and the lich crowds out
	 * ambient noise rather than stacking with it.
	 */
	ignores_ship_cooldown = TRUE
	/**
	 * Null on purpose, unlike ordinary ported events.
	 *
	 * The port spec asks harmful events to restrict themselves to ZONE_YELLOW/ZONE_RED so
	 * the green outer ring stays a safe place to learn the game. A lich raid is explicitly
	 * a galaxy-wide threat announced to every crew alive, and the whole design of the
	 * feature is that the only way to make it stop is to go kill him. A crew that can opt
	 * out by parking in green has no reason to. The potency ramp is the safety valve here,
	 * not the zone band, and these events never fire from the natural roster where the
	 * zone rules matter.
	 */
	allowed_zones = null
	/// Left at the framework default: a ship docked at an NPC outpost is skipped and another victim is picked.
	/// Not out of mercy: hostiles and hazards spawned aboard a docked ship can walk off it, and outposts must never take collateral.
	allow_in_safe_harbor = FALSE

/**
 * Requires a lich to be conducting rituals. Track A creates GLOB.lich_lair when the site
 * surfaces; the site clears its own ritual chain on the boss's death, so existence is the
 * gate this side needs.
 */
/datum/round_event_control/voidcrew/lich/can_spawn_event(players_amt, allow_magic = FALSE)
	if(!lich_is_conducting())
		return FALSE
	return ..()

/// TRUE while a lich lair exists to be raided. Single place to extend if track A grows a "spent" flag.
/datum/round_event_control/voidcrew/lich/proc/lich_is_conducting()
	return !QDELETED(GLOB.lich_lair)

/// TRUE if this event sits on the ramp at the given ritual potency. Bounds are inclusive,
/// matching the comparison the grand rune and the ritual clock both use.
/datum/round_event_control/voidcrew/lich/proc/matches_potency(potency)
	return (min_wizard_trigger_potency <= potency) && (max_wizard_trigger_potency >= potency)

/// Base event datum. Ship-scoped subtypes must call target_valid() at the top of every lifecycle step.
/datum/round_event/voidcrew/lich
	/**
	 * Sender name on every announcement a ritual makes. He does not use your comms
	 * protocol; he simply arrives on it.
	 *
	 * Reuses track A's LICH_ANNOUNCER (voidcrew/_DEFINES/lich.dm) so a ritual's own
	 * announcement and the site's galaxy broadcast are signed by the same hand. Held on a
	 * var rather than referenced as a macro from each event file: the defines block is
	 * included well before the modules block so either would work, but one var means one
	 * place to look and no per-file dependency on include ordering.
	 */
	var/lich_sender = LICH_ANNOUNCER
	/// Appearances this rite has painted onto ship areas, one per plane offset. Built by
	/// build_rite_overlays(); null until a rite asks for paint.
	var/list/mutable_appearance/rite_overlays
	/// Areas painted so far, assoc area -> TRUE, so removal is exact and a compartment
	/// painted late in the rite is still stripped at the end.
	var/list/area/painted_areas = list()

/**
 * Builds the paint for a hazard rite: one appearance per plane offset, from
 * icons/effects/weather_effects.dmi. Call once, at start().
 *
 * Layer/plane default to the weather base class's over-everything convention
 * (AREA_LAYER / WEATHER_PLANE, weather.dm:80-82). Floor-level hazards pass
 * ABOVE_OPEN_TURF_LAYER / FLOOR_PLANE, which is what /datum/weather/floor_is_lava does.
 */
/datum/round_event/voidcrew/lich/proc/build_rite_overlays(overlay_state, overlay_color = LICH_GREEN, overlay_alpha = 255, overlay_layer = AREA_LAYER, overlay_plane = WEATHER_PLANE)
	rite_overlays = list()
	for(var/offset in 0 to SSmapping.max_plane_offset)
		var/mutable_appearance/paint = mutable_appearance(
			'icons/effects/weather_effects.dmi',
			overlay_state,
			overlay_layer,
			plane = overlay_plane,
			offset_const = offset,
		)
		paint.color = overlay_color
		paint.alpha = overlay_alpha
		rite_overlays += paint

/**
 * Paints every one of the target ship's areas, and repaints the ones already painted.
 *
 * Call this every tick, not once at start(), and note that it re-reads
 * `shuttle.shuttle_areas` each time rather than a list cached when the rite began. Both are
 * deliberate, and both address the same reported bug: a compartment showing no effect for
 * the whole minute while the rooms next to it burn.
 *
 * - Re-adding heals a room that lost the paint. `overlays` is a raw appearance list with no
 *   owner; anything that rebuilds an area's appearance drops whatever it did not put there,
 *   and a one-shot paint has no way to notice or recover. TG's weather has the same exposure
 *   and papers over it by re-running update_areas() at every stage transition, the same
 *   trick, just at a coarser interval.
 * - Re-reading the area list picks up a compartment that joined the hull after the rite began
 *   (blueprints, hull construction, a shuttle expansion), which the cached list never could.
 *
 * The remove-then-add is what makes it idempotent: `overlays -= rite_overlays` is a no-op on
 * an area that does not have them and strips exactly one copy from one that does, so
 * repainting 30 times never stacks 30 copies. Cost is two list ops per area per second on one
 * hull, which is nothing.
 */
/datum/round_event/voidcrew/lich/proc/refresh_rite_overlays()
	if(!length(rite_overlays) || !target_valid())
		return
	for(var/area/ship_area as anything in target_ship.shuttle.shuttle_areas)
		if(QDELETED(ship_area))
			continue
		ship_area.overlays -= rite_overlays
		ship_area.overlays += rite_overlays
		painted_areas[ship_area] = TRUE

/// Strips exactly the overlays this rite added, from exactly the areas it added them to.
/// Safe to call on a rite that never painted, and on one whose ship has been destroyed.
/// Shuttle areas outlive their turfs, which is why nothing here caches a turf.
/datum/round_event/voidcrew/lich/proc/remove_rite_overlays()
	if(!length(rite_overlays))
		return
	for(var/area/ship_area as anything in painted_areas)
		if(QDELETED(ship_area))
			continue
		ship_area.overlays -= rite_overlays
	painted_areas = null
	rite_overlays = null

/**
 * Announcement heard only by the target ship's crew, in Ilthuun's voice.
 * Ship-scoped subtypes use this instead of touching priority_announce directly.
 */
/datum/round_event/voidcrew/lich/proc/lich_announce_ship(text, title = "Necromantic Resonance", sound)
	if(!target_valid())
		return
	target_ship.ship_event_announce(text, title, sound, sender_override = lich_sender)

/// Announcement heard by everyone alive, in Ilthuun's voice. For EVENT_SCOPE_GALAXY subtypes.
/datum/round_event/voidcrew/lich/proc/lich_announce_galaxy(text, title = "Necromantic Resonance", sound)
	priority_announce(text, title, sound, sender_override = lich_sender)
