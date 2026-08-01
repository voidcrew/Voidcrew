/**
 * Ritual event roster for The Verdigris — Ilthuun, the Verdigris Lich.
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
 * ## Cap policy — why max_occurrences is what it is
 *
 * The ritual clock plateaus. Potency climbs to LICH_MAX_POTENCY and then stays there, so a
 * lich nobody kills fires potency-7 rituals every LICH_RITUAL_INTERVAL for the rest of the
 * round. The roster has to be able to answer that indefinitely, and there is no relaxed
 * fallback pass to paper over it: if nothing in the band is eligible, the ritual fires
 * nothing, which is an acceptable miss but must not become the steady state.
 *
 * So the band splits into two kinds of event, deliberately:
 *
 * - **Repeatable pressure** — ship-scoped, self-terminating, recoverable with ordinary ship
 *   and medical tools. These carry high caps and are what a long-lived lich actually runs
 *   on: grave_dirt (20), corpse_bloom (8), grave_goods (6). corpse_bloom and grave_goods
 *   both reach potency 7 specifically so the top band has more than one repeatable option.
 *   Caps count RITUALS, not hulls: a ship-scoped rite fires one event instance per crewed
 *   ship and fire_ritual_on_every_ship() puts `occurrences` back to one per ritual, so a
 *   busy galaxy does not burn through a cap faster than an empty one.
 * - **Round-warping one-shots** — galaxy-scoped and permanent for the round:
 *   tongues_of_the_dead, mockery_of_heroes, mockery_of_treasure. These stay
 *   at max_occurrences = 1 forever. Firing them twice is not more interesting, and two of
 *   them install global controllers that must not be duplicated at all (their
 *   can_spawn_event() overrides refuse a second instance outright).
 *
 * If the top of the ramp ever feels thin, the correct fix is a new repeatable ship-scoped
 * event or another band widened upward — never a raised cap on a one-shot.
 *
 * ## What a ritual may never do: hand the crew power
 *
 * Ilthuun does not arm his raiders. TG's wizard roster includes Summon Magic (a random
 * magical item to every crewmember) and Summon Guns; a port of Summon Magic lived here and
 * was removed, and Summon Guns was never ported. A ritual that gives the crew a working
 * weapon or spell inverts the whole pressure system — the clock is supposed to make the
 * galaxy worse until somebody goes and kills him, and the reward for reaching him is his
 * hoard (lich_loot.dm). Handing out that power for free on the way there costs the raid its
 * only payoff and hands every non-raiding crew a windfall for ignoring him.
 *
 * Rituals may take, curse, animate, rename, or maim. Items a ritual creates must be a
 * liability (grave_goods' nodrop funeral dress) rather than a gain. Nothing on this roster
 * should ever leave a crew stronger than it found them.
 *
 * ## Scoping — every ritual reaches every crew
 *
 * EVENT_SCOPE_SHIP events resolve every location through a target ship's shuttle areas,
 * so trader outposts, ruins and bystander structures are structurally untouchable. In the
 * ambient framework one victim ship is rolled per event. **The lich does not work that
 * way**: fire_ritual_on_every_ship() (lich_site.dm) runs a ship-scoped rite once per
 * crewed ship, one independent event instance each, so a rite lands on everybody flying
 * with people aboard. EVENT_SCOPE_GALAXY events have no target ship and reach everyone by
 * their own machinery. The two scopes are therefore a difference in plumbing, not in who
 * gets hit — a crew three sectors from the lair is not a spectator.
 *
 * The only crews a ship-scoped rite skips are those docked at a trader outpost
 * (`allow_in_safe_harbor = FALSE`, inherited): NPC outposts never take collateral, and
 * hostiles or hazards spawned aboard a docked ship can walk off it.
 *
 * Consequence worth knowing: every instance stamps its ship's `last_dynamic_event`, so
 * while Ilthuun is working the whole fleet is on ambient-event cooldown and
 * SSdynamic_events goes quiet. That is the intended reading — the lich owns the pressure
 * budget for as long as he is alive — and it reverses on its own when he dies.
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
	 * ship the lich just hit — the exemption runs one way only, and the lich crowds out
	 * ambient noise rather than stacking with it.
	 */
	ignores_ship_cooldown = TRUE
	/**
	 * Null on purpose, unlike ordinary ported events.
	 *
	 * The port spec asks harmful events to restrict themselves to ZONE_YELLOW/ZONE_RED so
	 * the green outer ring stays a safe place to learn the game. A lich raid is explicitly
	 * a galaxy-wide threat announced to every crew alive, and the whole design of the
	 * feature is that the only way to make it stop is to go kill him — a crew that can opt
	 * out by parking in green has no reason to. The potency ramp is the safety valve here,
	 * not the zone band, and these events never fire from the natural roster where the
	 * zone rules matter.
	 */
	allowed_zones = null
	/// Left at the framework default: a ship docked at an NPC outpost is skipped and another victim is picked.
	/// Not out of mercy — hostiles and hazards spawned aboard a docked ship can walk off it, and outposts must never take collateral.
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
