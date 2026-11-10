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
		STEALTH_BARK_CHATTER = list("Shipment's late again.", "My feet are killing me.", "You hear that? No? Good.", "Radio check.", "Quiet tonight. I hate quiet."),
		STEALTH_BARK_DOWNED = list("Got 'em.", "Stay down.", "That's handled."),
		STEALTH_BARK_HEARD = list("What was that?", "You hear that?", "Hm."),
		STEALTH_BARK_HEARD_AGAIN = list("Again?", "That's twice now."),
		STEALTH_BARK_GUNFIRE = list("Shots!", "That's gunfire!", "Shots, %SIDE% side!"),
		STEALTH_BARK_HOLD = list("Stay put.", "Eyes open."),
		STEALTH_BARK_HELP = list("Over here!", "Need a hand!"),
		STEALTH_BARK_MISSING = list("%NAME%? ...%NAME%!", "Where's %NAME% got to?", "Should've been back by now."),
		STEALTH_BARK_RADIO_REPORT = list("Checking something, %SIDE% side.", "Checking something."),
		STEALTH_BARK_RADIO_ALARM = list("Contact, %SIDE% side! Get over here!", "Trouble, %SIDE% side!", "Trouble! Get over here!"),
		STEALTH_BARK_RADIO_MISSING = list("%NAME%, come in.", "%NAME%'s not answering.", "Got one not answering."),
		STEALTH_BARK_COPY = list("Copy.", "Moving.", "On my way."),
		STEALTH_BARK_RADIO_DEAD = list("Radio's dead.", "Nothing but static."),
	)
	emotes = list(
		HUMAN_NPC_BARK_DOWNED = list("collapses."),
		STEALTH_BARK_SUSPICIOUS = list("squints into the dark.", "turns, frowning."),
		STEALTH_BARK_GIVE_UP = list("shrugs."),
		STEALTH_BARK_SEARCH = list("checks behind a crate."),
		STEALTH_BARK_HIT_UNSEEN = list("ducks."),
		STEALTH_BARK_CHATTER = list("yawns.", "stretches."),
		STEALTH_BARK_DOWNED = list("spits."),
		STEALTH_BARK_HEARD = list("cocks their head.", "looks round."),
		STEALTH_BARK_GUNFIRE = list("flinches."),
		STEALTH_BARK_HOLD = list("shifts their grip."),
		STEALTH_BARK_RADIO_DEAD = list("taps their earpiece."),
	)
	chances = list(RUIN_NPC_BARK_SPOT = 100)

/datum/human_npc_voice/scav
	/// For the bark being said now: "line" or "emote" when its kind has both, else null
	var/say_as
	/// For the bark being said now: the side of the den a line names ("east"), or null
	var/fill_side
	/// For the bark being said now: the friend a line asks after, or null. A guard's own name, never player text.
	var/fill_name

// A line and an emote together read as a script: a kind with both gets one or the other, picked once a bark.
// The spot line always comes, even right after a stealth line.
/datum/human_npc_voice/scav/bark(mob/living/carbon/human/npc/speaker, kind, force = FALSE)
	say_as = null
	if(length(lines[kind]) && length(emotes[kind]))
		say_as = (human_npc_can_talk(speaker) && prob(70)) ? "line" : "emote"
	. = ..(speaker, kind, force || kind == RUIN_NPC_BARK_SPOT)
	say_as = null

/datum/human_npc_voice/scav/emotes_for(kind)
	return say_as == "line" ? null : ..()

// A line that names a side of the den ("%SIDE%") or a friend ("%NAME%") is only said when there is one to name.
/datum/human_npc_voice/scav/lines_for(kind)
	if(say_as == "emote")
		return null
	var/list/written = ..()
	if(!length(written))
		return written
	. = list()
	for(var/line in written)
		if(findtext(line, "%SIDE%"))
			if(!fill_side)
				continue
			line = replacetext(line, "%SIDE%", fill_side)
		if(findtext(line, "%NAME%"))
			if(!fill_name)
				continue
			line = replacetext(line, "%NAME%", fill_name) // xss-safe: an NPC guard's own name, set by code, never player text
		. += line

/mob/living/carbon/human/npc/ruin/trooper/scav
	name = "scav guard"
	npc_name = "Scav Guard"
	faction = list(FACTION_SCAV)
	ai_controller = /datum/ai_controller/basic_controller/human_npc/stealth
	npc_voice = /datum/human_npc_voice/scav
	npc_outfit_table = /datum/human_npc_outfit_table/ruin/syndicate/sword

/// Every scav guard carries a seclite it switches on in the dark (stealth_light.dm, decision 31).
/mob/living/carbon/human/npc/ruin/trooper/scav/npc_dress(datum/human_npc_order/order)
	. = ..()
	stealth_give_light()

/mob/living/carbon/human/npc/ruin/trooper/scav/gunner
	npc_outfit_table = /datum/human_npc_outfit_table/ruin/syndicate/pistol

/// A gunner with an earpiece: on its group's radio net (stealth_radio.dm).
/mob/living/carbon/human/npc/ruin/trooper/scav/lookout
	name = "scav lookout"
	npc_name = "Scav Lookout"
	npc_outfit_table = /datum/human_npc_outfit_table/ruin/syndicate/pistol
	stealth_radio = TRUE

/mob/living/carbon/human/npc/ruin/trooper/scav/lookout/npc_dress(datum/human_npc_order/order)
	. = ..()
	if(isnull(ears))
		equip_to_slot_or_del(new /obj/item/radio/headset(src), ITEM_SLOT_EARS)

/obj/effect/spawner/human_npc/ruin/scav
	name = "scav guard spawner"
	npc_type = /mob/living/carbon/human/npc/ruin/trooper/scav

/obj/effect/spawner/human_npc/ruin/scav/gunner
	name = "scav gunner spawner"
	npc_type = /mob/living/carbon/human/npc/ruin/trooper/scav/gunner

/obj/effect/spawner/human_npc/ruin/scav/lookout
	name = "scav lookout spawner"
	npc_type = /mob/living/carbon/human/npc/ruin/trooper/scav/lookout
