/mob/living/carbon/human/Initialize(mapload)
	. = ..()
	// This gives a random voice pack to a random created person
	if(!client && !voice_bark)
		voice_bark = new()
		voice_bark.randomise(src)

/mob/living/basic/cow/initial_voice_pack_id()
	return "goon.cow"

/*
	---- Changeling Profile ----
*/

/datum/changeling_profile
	var/datum/atom_voice/voice_bark

/datum/antagonist/changeling/create_profile(mob/living/carbon/human/target, protect = 0)
	. = ..()
	var/datum/changeling_profile/new_profile = .
	new_profile.voice_bark = new()
	new_profile.voice_bark.copy_from(target.get_voice_bark())

/datum/antagonist/changeling/transform(mob/living/carbon/human/user, datum/changeling_profile/chosen_profile)
	. = ..()
	user.get_voice_bark().copy_from(chosen_profile.voice_bark)

/*
	---- Admin Tools ----
*/

/datum/smite/normalvoicepack
	name = "Normalise voicepack"

/datum/smite/normalvoicepack/effect(client/user, mob/living/carbon/human/target)
	. = ..()
	target.get_voice_bark().randomise(target)

ADMIN_VERB(togglebark, R_SERVER, "Toggle Voices", "Toggles atom talk sounds.", ADMIN_CATEGORY_SERVER)
	GLOB.voices_enabled = !GLOB.voices_enabled
	to_chat(world, span_ooc("<B>Vocal barks have been globally [GLOB.voices_enabled ? "enabled" : "disabled"].</B>"))

	log_admin("[key_name(user)] toggled Voice Barks.")
	message_admins("[key_name_admin(user)] toggled Voice Barks.")
	SSblackbox.record_feedback("nested tally", "admin_toggle", 1, list("Toggle Voice Bark", "[GLOB.voices_enabled ? "Enabled" : "Disabled"]"))

ADMIN_VERB(reload_voice_packs_file, R_SERVER, "Reload Voice Packs", "Reloads voice packs from config.", ADMIN_CATEGORY_SERVER)
	GLOB.voice_pack_groups_visible = list()
	GLOB.voice_pack_groups_all = list()
	GLOB.random_voice_packs = list()
	GLOB.voice_pack_list = gen_voice_packs()
