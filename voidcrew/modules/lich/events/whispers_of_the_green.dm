/**
 * Ritual: Whispers of the Green — ship-scoped port of TG's Curse of Madness
 * (code/modules/events/wizard/madness.dm).
 *
 * He tells one crew something true about themselves, and their minds come apart along the
 * seam.
 *
 * The TG event is a two-line wrapper around the global `curse_of_madness()` proc
 * (code/modules/spells/spell_types/madness_curse.dm:3). That proc cannot be reused: it
 * filters victims with `is_station_level(curse_turf.z)`, which in this fork resolves TRUE
 * for every z-level a ship currently occupies — so a "ship-scoped" call would traumatise
 * every crew sharing the transit level plus anyone standing in a trader outpost. It also
 * sets `GLOB.curse_of_madness_triggered`, which permanently afflicts every future latejoiner
 * in the galaxy from a single ship's ritual.
 *
 * Changed from the original:
 * - curse_of_madness() is replaced by a direct loop over the target ship's crew. The
 *   per-victim half — `give_madness()` — IS reused unchanged; it has no station coupling and
 *   owns the trauma-roll table, so duplicating it would just let the two drift apart.
 * - GLOB.curse_of_madness_triggered is deliberately NOT set. The ritual afflicts the people
 *   who were aboard when it landed. Latejoiners galaxy-wide inheriting a trauma from a
 *   curse aimed at one hull is a station-shaped assumption, not a scoping detail.
 * - The horrifying truth is drawn from a lich-authored list instead of TG's
 *   `strings(REDPILL_FILE, "redpill_questions")`. The redpill file is generic
 *   fourth-wall-poking existential trivia; Ilthuun's revelations are about being meat that
 *   has not finished happening yet, which is the same mechanic with the correct mouth.
 * - The admin_setup text-input datum is dropped, per the port spec.
 * - Antimagic is honoured exactly as the original does, via can_block_magic() with
 *   MAGIC_RESISTANCE|MAGIC_RESISTANCE_MIND.
 *
 * Recoverability note: give_madness() applies traumas at TRAUMA_RESILIENCE_LOBOTOMY, which
 * is the original's severity. These are curable with ordinary medbay work (lobotomy, mannitol
 * for the mild tier), so the aftermath is a medical problem rather than a permanent one.
 */
/datum/round_event_control/voidcrew/lich/whispers_of_the_green
	name = "Ritual: Whispers of the Green"
	typepath = /datum/round_event/voidcrew/lich/whispers_of_the_green
	description = "Reveals a truth to everyone aboard the target ship, giving them a trauma."
	max_occurrences = 2
	event_scope = EVENT_SCOPE_SHIP
	min_wizard_trigger_potency = 2
	max_wizard_trigger_potency = 5

/datum/round_event/voidcrew/lich/whispers_of_the_green
	announce_when = 1
	/// The revelation. Picked at setup so announce() and start() agree on it.
	var/horrifying_truth
	/// Ilthuun's replacements for TG's redpill questions.
	var/static/list/green_revelations = list(
		"YOU HAVE ALREADY DIED. THE PART THAT NOTICED HAS NOT BEEN INFORMED.",
		"COUNT YOUR BONES. YOU WILL FIND ONE YOU CANNOT ACCOUNT FOR.",
		"EVERY BREATH IS A LOAN. I AM THE ONE WHO KEEPS THE LEDGER.",
		"THE THING WEARING YOUR NAME IS NOT THE THING THAT WAS BORN WITH IT.",
		"YOU ARE THE SOFT PART OF A SKELETON. THAT IS ALL YOU HAVE EVER BEEN.",
		"YOUR CREW WILL OUTLIVE YOU BY MINUTES. THEY ALREADY KNOW WHICH ONES.",
		"NOTHING IS BURIED. EVERYTHING IS SIMPLY WAITING WITH BETTER MANNERS.",
		"I HAVE SEEN THE INSIDE OF YOUR SKULL. IT IS UNREMARKABLE AND IT IS MINE.",
		"THE GREEN IS NOT A COLOUR. IT IS WHAT IS LEFT WHEN THE REST HAS ROTTED OFF.",
		"YOU WILL DREAM OF THIS SENTENCE ON THE NIGHT YOU DIE.",
	)

/datum/round_event/voidcrew/lich/whispers_of_the_green/setup()
	if(!horrifying_truth)
		horrifying_truth = pick(green_revelations)

/datum/round_event/voidcrew/lich/whispers_of_the_green/announce(fake)
	lich_announce_ship(
		"I am going to tell you something true. You have spent your whole life arranging \
		furniture so as not to see it. Sit down.",
		"Whispers of the Green",
		'sound/effects/magic/curse.ogg',
	)

/datum/round_event/voidcrew/lich/whispers_of_the_green/start()
	if(!target_valid())
		return

	deadchat_broadcast(
		"Ilthuun has whispered to the crew of [span_name(target_ship.display_name || target_ship.name)], \
		shattering their minds with the truth: \"<span class='big hypnophrase'>[horrifying_truth]</span>\"",
		message_type = DEADCHAT_ANNOUNCEMENT,
	)

	for(var/mob/living/aboard_mob as anything in target_ship.get_event_crew())
		if(!ishuman(aboard_mob) || QDELETED(aboard_mob))
			continue
		var/mob/living/carbon/human/victim = aboard_mob
		if(victim.stat == DEAD)
			continue
		if(victim.can_block_magic(MAGIC_RESISTANCE|MAGIC_RESISTANCE_MIND))
			to_chat(victim, span_notice("Something vast tries to tell you a secret. It slides off you like water."))
			continue
		give_madness(victim, horrifying_truth)
