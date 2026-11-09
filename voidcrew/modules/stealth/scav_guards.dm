/**
 * # Scav den guards
 *
 * The first NPCs with the stealth controller (owner decisions 6 and 11). Placeholder dress until step 4
 * gives them their own look: the melee guard borrows the Syndicate sword table, the gunner the pistol one.
 */

/datum/human_npc_voice/scav
	lines = list(
		RUIN_NPC_BARK_SPOT = list("There! Get 'em!", "Intruder!", "Got you now!", "Over here!"),
		HUMAN_NPC_BARK_DOWNED = list("Ugh... I'm hit...", "Somebody..."),
		HUMAN_NPC_BARK_RECOVER = list("Still here.", "That all?"),
		HUMAN_NPC_BARK_CUFFED = list("You don't know who you're messing with."),
		STEALTH_BARK_SUSPICIOUS = list("Hm?", "Who's there?", "Thought I saw something."),
		STEALTH_BARK_GIVE_UP = list("Nothing.", "Jumpy tonight.", "Must be the rats."),
		STEALTH_BARK_LOST = list("Lost them!", "Where'd they go?"),
		STEALTH_BARK_SEARCH = list("Come on out.", "I know you're here."),
		STEALTH_BARK_HIT_UNSEEN = list("Contact!", "Where's that coming from?"),
		STEALTH_BARK_BODY = list("Man down!", "Who did this?"),
		STEALTH_BARK_CHATTER = list("Shipment's late again.", "My feet are killing me.", "You hear that? No? Good."),
		STEALTH_BARK_DOWNED = list("Got 'em.", "Stay down.", "That's handled."),
	)
	emotes = list(
		HUMAN_NPC_BARK_DOWNED = list("collapses."),
		STEALTH_BARK_SUSPICIOUS = list("squints into the dark.", "turns, frowning."),
		STEALTH_BARK_GIVE_UP = list("shrugs."),
		STEALTH_BARK_SEARCH = list("checks behind a crate."),
		STEALTH_BARK_HIT_UNSEEN = list("ducks."),
		STEALTH_BARK_CHATTER = list("yawns.", "stretches."),
		STEALTH_BARK_DOWNED = list("spits."),
	)
	chances = list(RUIN_NPC_BARK_SPOT = 100)

// A line and an emote together read as a script: for the stealth kinds, now one and now the other.
/datum/human_npc_voice/scav/emotes_for(kind)
	. = ..()
	if(length(.) && length(lines_for(kind)) && prob(60))
		return null

// The spot line always comes, even right after a stealth line.
/datum/human_npc_voice/scav/bark(mob/living/carbon/human/npc/speaker, kind, force = FALSE)
	return ..(speaker, kind, force || kind == RUIN_NPC_BARK_SPOT)

/datum/human_npc_voice/scav/lines_for(kind)
	. = ..()
	if(length(.) && length(emotes[kind]) && prob(30))
		return null

/mob/living/carbon/human/npc/ruin/trooper/scav
	name = "scav guard"
	npc_name = "Scav Guard"
	faction = list(FACTION_SCAV)
	ai_controller = /datum/ai_controller/basic_controller/human_npc/stealth
	npc_voice = /datum/human_npc_voice/scav
	npc_outfit_table = /datum/human_npc_outfit_table/ruin/syndicate/sword

/mob/living/carbon/human/npc/ruin/trooper/scav/gunner
	npc_outfit_table = /datum/human_npc_outfit_table/ruin/syndicate/pistol

/obj/effect/spawner/human_npc/ruin/scav
	name = "scav guard spawner"
	npc_type = /mob/living/carbon/human/npc/ruin/trooper/scav

/obj/effect/spawner/human_npc/ruin/scav/gunner
	name = "scav gunner spawner"
	npc_type = /mob/living/carbon/human/npc/ruin/trooper/scav/gunner
