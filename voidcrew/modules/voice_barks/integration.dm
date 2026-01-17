// Voice bark integration hooks - ported from Monkestation
// These hooks initialize bark voices for humans and silicons

/mob/living/carbon/human/Initialize(mapload)
	. = ..()
	// This gives a random voice pack to a randomly created person
	if(!client && !bark_voice)
		bark_voice = new()
		bark_voice.randomise(src)

/mob/living/silicon/Login()
	. = ..()
	if(!bark_voice)
		bark_voice = new()
	// This is the only found function that updates the client for borgs.
	bark_voice.set_from_prefs(client?.prefs)

// Cow specific voice pack
/mob/living/basic/cow/initial_voice_pack_id()
	return "goon.cow"

/*
	---- Changeling Profile ----
*/

/datum/changeling_profile
	var/datum/atom_voice/bark_voice

/datum/antagonist/changeling/create_profile(mob/living/carbon/human/target, protect = 0)
	. = ..()
	var/datum/changeling_profile/new_profile = .
	new_profile.bark_voice = new()
	new_profile.bark_voice.copy_from(target.get_bark_voice())

/datum/antagonist/changeling/transform(mob/living/carbon/human/user, datum/changeling_profile/chosen_profile)
	. = ..()
	if(chosen_profile?.bark_voice)
		user.get_bark_voice().copy_from(chosen_profile.bark_voice)

/*
	---- Admin Tools ----
*/

/datum/smite/normalvoicepack
	name = "Normalise voicepack"

/datum/smite/normalvoicepack/effect(client/user, mob/living/carbon/human/target)
	. = ..()
	if(!istype(target))
		return
	target.get_bark_voice().randomise(target)

ADMIN_VERB(togglebark, R_SERVER, "Toggle Voice Barks", "Toggles atom talk sounds.", ADMIN_CATEGORY_SERVER)
	GLOB.voices_enabled = !GLOB.voices_enabled
	to_chat(world, span_ooc("<B>Voice barks have been globally [GLOB.voices_enabled ? "enabled" : "disabled"].</B>"))

	log_admin("[key_name(user)] toggled Voice Barks.")
	message_admins("[key_name_admin(user)] toggled Voice Barks.")
	SSblackbox.record_feedback("nested tally", "admin_toggle", 1, list("Toggle Voice Bark", "[GLOB.voices_enabled ? "Enabled" : "Disabled"]"))

ADMIN_VERB(reload_voice_packs_file, R_SERVER, "Reload Voice Packs", "Reloads voice packs from config file.", ADMIN_CATEGORY_SERVER)
	GLOB.voice_pack_groups_visible = list()
	GLOB.voice_pack_groups_all = list()
	GLOB.random_voice_packs = list()
	GLOB.voice_pack_list = gen_voice_packs()
	to_chat(user, span_adminnotice("Voice packs reloaded. [length(GLOB.voice_pack_list)] packs loaded."))
	log_admin("[key_name(user)] reloaded voice packs.")
