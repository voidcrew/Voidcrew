/**
 * Ritual: Summon Magic — galaxy-scoped port of TG's Summon Magic
 * (code/modules/events/wizard/summons.dm).
 *
 * He arms the galaxy. Not out of sportsmanship — he wants to watch what they do to each
 * other with it first.
 *
 * The mechanic is upstream's `summon_magic()` proc, which installs a
 * /datum/summon_things_controller/item and hands a random magical item to every crewmember
 * mind, plus latejoiners for the rest of the round. There is nothing station-shaped in the
 * item-granting path itself, so the controller is reused rather than duplicated — this event
 * is the classic and the classic's whole point is that it uses the same summon plumbing as the
 * spellbook.
 *
 * Changed from the original:
 * - The `CONFIG_GET(flag/no_summon_magic)` check is kept exactly as TG does it, zeroing the
 *   weight in New(). It is additionally enforced as a hard refusal in can_spawn_event(),
 *   because this roster is not selected by weight — the ritual clock picks from the eligible
 *   list, where a weight of 0 would not stop anything.
 * - TG's sibling Summon Guns control is not ported. The contract's table lists Summon Magic.
 * - Gains a galaxy announcement in Ilthuun's voice.
 *
 * Known limitation, not worked around: `/datum/summon_things_controller/get_affected_minds()`
 * (code/modules/spells/spell_types/right_and_wrong.dm:290) filters candidates on
 * `is_station_level(z) || is_mining_level(z)`. In this fork ZTRAIT_STATION is applied to any
 * z-level currently occupied by a ship, so this reaches everybody aboard a ship anywhere in
 * the galaxy — which is the intended audience — but silently skips anyone standing in a ruin
 * or on a planet surface at the moment it fires. Fixing that means editing an upstream proc
 * shared with the wizard spellbook, which is out of scope for this track; it is recorded here
 * so nobody spends an evening wondering why the away team got nothing.
 *
 * Note that `survivor_probability = 10` is TG's value and is retained: one in ten recipients
 * without an existing antag datum becomes a magic survivalist. That is a deliberate part of
 * what this event is, and at potency 5+ the galaxy has bigger problems.
 */
/datum/round_event_control/voidcrew/lich/summon_magic
	name = "Ritual: Summon Magic"
	typepath = /datum/round_event/voidcrew/lich/summon_magic
	description = "Summons a magic item for everyone. Might turn people into survivalists."
	max_occurrences = 1
	event_scope = EVENT_SCOPE_GALAXY
	min_wizard_trigger_potency = 5
	max_wizard_trigger_potency = 7

/datum/round_event_control/voidcrew/lich/summon_magic/New()
	if(CONFIG_GET(flag/no_summon_magic))
		weight = 0
	return ..()

/**
 * The config flag has to be a hard refusal, not just a zeroed weight.
 * get_lich_ritual_events() builds a plain eligibility list for the ritual clock to pick from;
 * weight never enters into it, so weight = 0 alone would not honour the server setting.
 */
/datum/round_event_control/voidcrew/lich/summon_magic/can_spawn_event(players_amt, allow_magic = FALSE)
	if(CONFIG_GET(flag/no_summon_magic))
		return FALSE
	return ..()

/datum/round_event/voidcrew/lich/summon_magic
	announce_when = 1

/datum/round_event/voidcrew/lich/summon_magic/start()
	summon_magic(survivor_probability = 10)

/datum/round_event/voidcrew/lich/summon_magic/announce(fake)
	lich_announce_galaxy(
		"You have been dying of me very slowly and it has become tedious. Here — take a \
		little of what I am. Real power, in your soft hands, with no instruction whatsoever. \
		I expect most of you will not reach me. I expect several of you will not reach the \
		end of the corridor.",
		"An Unkind Gift",
		'sound/effects/magic/castsummon.ogg',
	)
