// Hyperviolence aimed crits: the wounds each crit leaves behind.
//
// These are ordinary tg wound subtypes, so health analyzers, examine text, treatment items,
// surgery and scars all handle them like any other wound. None of them can come from tg's random
// wound roll (can_be_randomly_generated = FALSE): only the aimed crit roll in crit_roll.dm applies
// them, and it applies them silently and adds its own hit line instead of tg's wound message.

// ---------------------------------------------------------------------------------------------
// Torn-out eye. tg keeps both eyes in one organ, so the first crit takes one eye (it scars that
// side, which leaves the victim nearsighted, the same as tg's own eye scarring) and the second
// takes the other and tears the whole organ out onto the floor.

/datum/wound/pierce/bleed/severe/eye/hv_gouged
	name = "Torn-Out Eye"
	undiagnosed_name = "Torn-Out Eye"
	desc = "Patient's eye has been torn from its socket. The socket is bleeding freely."
	treat_text = "Suture or cauterize the socket. Only a replacement pair of eyes will restore sight."
	treat_text_short = "Suture or cauterize the socket."
	simple_desc = "Patient's eye has been torn out."
	simple_treat_text = "<b>Suture</b> or <b>cauterize</b> the socket. Sight only returns with new eyes."
	homemade_treat_text = "Press <b>gauze</b> over the socket."
	occur_text = "loses an eye in a spray of blood"
	internal_bleeding_chance = 20
	/// Set once the second eye has gone too.
	var/both_gone = FALSE

/datum/wound/pierce/bleed/severe/eye/hv_gouged/apply_wound(obj/item/bodypart/limb, silent = FALSE, datum/wound/old_wound = null, smited = FALSE, attack_direction = null, wound_source = "Unknown", replacing = FALSE, right_side = FALSE)
	. = ..()
	if(.)
		update_socket_desc()

/// The second eye has been torn out as well.
/datum/wound/pierce/bleed/severe/eye/hv_gouged/proc/lose_other_eye()
	both_gone = TRUE
	set_blood_flow(max(blood_flow, initial_flow))
	update_socket_desc()

/datum/wound/pierce/bleed/severe/eye/hv_gouged/proc/update_socket_desc()
	if(both_gone)
		examine_desc = "has two empty eye sockets, weeping blood"
	else
		examine_desc = "has an empty [right_side ? "right" : "left"] eye socket, weeping blood"

/datum/wound_pregen_data/flesh_pierce/open_puncture/eye/hv_gouged
	wound_path_to_generate = /datum/wound/pierce/bleed/severe/eye/hv_gouged
	required_wounding_types = list(WOUND_PIERCE, WOUND_SLASH)
	wound_series = WOUND_SERIES_HV_EYE
	can_be_randomly_generated = FALSE

// ---------------------------------------------------------------------------------------------
// Severed tongue. The crit drops the tongue organ; tg's tongueless speech does the rest. The
// wound is the bleeding stump, which clots on its own like a light cut.

/datum/wound/slash/flesh/moderate/hv_tongue
	name = "Severed Tongue"
	undiagnosed_name = "Severed Tongue"
	desc = "Patient's tongue has been cut off. The stump is bleeding into the mouth."
	treat_text = "Suture or cauterize the stump. A new tongue can be implanted."
	treat_text_short = "Suture or cauterize the stump."
	simple_desc = "Patient's tongue has been cut off."
	simple_treat_text = "The bleeding stops on its own. A new tongue has to be implanted."
	homemade_treat_text = "Keep the head still and let it clot."
	examine_desc = "is bleeding from the mouth"
	occur_text = "loses its tongue"
	initial_flow = 2
	minimum_flow = 0.5
	clot_rate = 0.04

/datum/wound_pregen_data/flesh_slash/hv_tongue
	abstract = FALSE
	wound_path_to_generate = /datum/wound/slash/flesh/moderate/hv_tongue
	wound_series = WOUND_SERIES_HV_TONGUE
	viable_zones = list(BODY_ZONE_HEAD)
	can_be_randomly_generated = FALSE
	threshold_minimum = 20

// ---------------------------------------------------------------------------------------------
// Torn carotid (slit throat). Bleeds about as hard as tg's worst cut and never clots, spurts on a
// pulse, and gargles speech while it is open. A hemostat clamps it (a big cut to the bleeding),
// then sutures or cautery close it as with any cut. Untreated it kills in roughly two minutes.

/// Blood flow at or above which the throat spurts and the victim gargles.
#define HV_CAROTID_OPEN_FLOW 1.5

/datum/wound/slash/flesh/critical/hv_carotid
	name = "Torn Carotid Artery"
	undiagnosed_name = "Slit Throat"
	desc = "Patient's throat is cut open through the carotid artery. Blood loss will kill within minutes."
	treat_text = "Clamp the artery with a hemostat, then suture or cauterize the wound. Transfuse blood."
	treat_text_short = "Clamp with a hemostat, then suture or cauterize."
	simple_desc = "Patient's throat is cut open and pumping blood."
	simple_treat_text = "<b>Clamp</b> the artery with a <b>hemostat</b>, then <b>suture</b> or <b>cauterize</b> it."
	homemade_treat_text = "Press hard on the wound and lie down."
	examine_desc = "has its throat slit open, pumping out blood"
	occur_text = "is slit open at the throat"
	sound_effect = 'sound/effects/wounds/blood3.ogg'
	initial_flow = 4.25
	minimum_flow = 0.5
	clot_rate = 0
	demotes_to = null
	treatable_tools = list(TOOL_CAUTERY, TOOL_HEMOSTAT)
	/// Set once someone has clamped the artery with a hemostat.
	var/clamped = FALSE
	/// world.time of the next spurt.
	var/next_spurt = 0

/datum/wound/slash/flesh/critical/hv_carotid/set_victim(new_victim)
	if(victim)
		UnregisterSignal(victim, COMSIG_LIVING_TREAT_MESSAGE)
	if(new_victim)
		RegisterSignal(new_victim, COMSIG_LIVING_TREAT_MESSAGE, PROC_REF(gargle_speech))
	return ..()

/datum/wound/slash/flesh/critical/hv_carotid/handle_process(seconds_per_tick, times_fired)
	. = ..()
	if(QDELETED(src) || !victim || !limb || victim.stat == DEAD || HAS_TRAIT(victim, TRAIT_STASIS))
		return
	if(clamped || blood_flow < HV_CAROTID_OPEN_FLOW || world.time < next_spurt || !limb.can_bleed())
		return
	next_spurt = world.time + rand(4 SECONDS, 7 SECONDS)
	victim.hv_blood_spray(pick(GLOB.alldirs), 2)

/datum/wound/slash/flesh/critical/hv_carotid/treat(obj/item/I, mob/user)
	if(I.tool_behaviour == TOOL_HEMOSTAT)
		return clamp_artery(I, user)
	return ..()

/// Someone clamps the torn artery shut with a hemostat.
/datum/wound/slash/flesh/critical/hv_carotid/proc/clamp_artery(obj/item/tool, mob/user)
	if(clamped)
		to_chat(user, span_warning("The artery is already clamped."))
		return TRUE
	var/whose = (user == victim) ? "your" : "[victim]'s"
	user.visible_message(span_danger("[user] reaches into [victim]'s throat with [tool]..."), span_warning("You reach into [whose] throat with [tool]..."))
	if(!do_after(user, base_treat_time * (user == victim ? 2 : 1.5), target = victim, extra_checks = CALLBACK(src, PROC_REF(still_exists))))
		return TRUE
	clamped = TRUE
	user.visible_message(span_green("[user] clamps the artery in [victim]'s throat."), span_green("You clamp the artery in [whose] throat."))
	adjust_blood_flow(-2.5)
	return TRUE

/datum/wound/slash/flesh/critical/hv_carotid/modify_desc_before_span(desc, mob/user)
	. = ..()
	if(clamped)
		. += ", held shut by a clamp"

/datum/wound/slash/flesh/critical/hv_carotid/proc/gargle_speech(datum/source, list/message_args)
	SIGNAL_HANDLER
	if(clamped || blood_flow < HV_CAROTID_OPEN_FLOW)
		return
	message_args[TREAT_MESSAGE_ARG] = hv_crit_gargle(message_args[TREAT_MESSAGE_ARG])

#undef HV_CAROTID_OPEN_FLOW

/datum/wound_pregen_data/flesh_slash/hv_carotid
	abstract = FALSE
	wound_path_to_generate = /datum/wound/slash/flesh/critical/hv_carotid
	wound_series = WOUND_SERIES_HV_CAROTID
	required_limb_biostate = (BIO_FLESH|BIO_BLOODED)
	ignore_cannot_bleed = FALSE
	viable_zones = list(BODY_ZONE_HEAD)
	can_be_randomly_generated = FALSE
	threshold_minimum = 80

// ---------------------------------------------------------------------------------------------
// Torn aorta. A deep chest bleed that never clots, shrugs off gauze, cannot be cauterized from
// outside and makes the victim cough blood. tg's "Repair puncture" surgery fixes it; blood and
// clotting drugs buy time.

/datum/wound/pierce/bleed/critical/hv_aorta
	name = "Torn Aorta"
	undiagnosed_name = "Chest Bleed"
	desc = "Patient's aorta is torn. The chest cavity is filling with blood."
	treat_text = "Repair the vessel surgically at once. Blood transfusions and clotting agents buy time."
	treat_text_short = "Surgical repair required."
	simple_desc = "A great artery in the chest is torn."
	simple_treat_text = "Needs <b>surgery</b> at once. <b>Blood</b> and <b>clotting drugs</b> buy time."
	homemade_treat_text = "Keep them lying still."
	examine_desc = "has a deep wound that pumps blood with every heartbeat"
	occur_text = "is torn open to the heart"
	initial_flow = 3.5
	gauzed_clot_rate = 0.1
	internal_bleeding_chance = 100
	internal_bleeding_coefficient = 2
	treatable_by = list()
	treatable_tools = list()
	wound_flags = (ACCEPTS_GAUZE | MANGLES_EXTERIOR)
	/// world.time of the next mouthful of blood.
	var/next_cough = 0

/datum/wound/pierce/bleed/critical/hv_aorta/wound_injury(datum/wound/old_wound = null, attack_direction = null)
	next_cough = world.time + rand(8 SECONDS, 15 SECONDS)
	return ..()

/datum/wound/pierce/bleed/critical/hv_aorta/check_grab_treatments(obj/item/I, mob/user)
	return FALSE // a hot knife on the skin does nothing for a torn aorta

/datum/wound/pierce/bleed/critical/hv_aorta/handle_process(seconds_per_tick, times_fired)
	. = ..()
	if(QDELETED(src) || !victim || !limb || victim.stat == DEAD || HAS_TRAIT(victim, TRAIT_STASIS))
		return
	if(world.time < next_cough || !limb.can_bleed())
		return
	next_cough = world.time + rand(15 SECONDS, 25 SECONDS)
	victim.visible_message(
		span_danger("[victim] coughs up a mouthful of blood!"),
		span_userdanger("You cough up a mouthful of blood!"),
		vision_distance = COMBAT_MESSAGE_RANGE,
	)
	victim.bleed(4)
	victim.add_splatter_floor(get_step(victim, victim.dir) || get_turf(victim))

/datum/wound_pregen_data/flesh_pierce/hv_aorta
	abstract = FALSE
	wound_path_to_generate = /datum/wound/pierce/bleed/critical/hv_aorta
	required_wounding_types = list(WOUND_PIERCE, WOUND_SLASH)
	wound_series = WOUND_SERIES_HV_AORTA
	required_limb_biostate = (BIO_FLESH|BIO_BLOODED)
	ignore_cannot_bleed = FALSE
	viable_zones = list(BODY_ZONE_CHEST)
	can_be_randomly_generated = FALSE
	threshold_minimum = 100

// ---------------------------------------------------------------------------------------------
// Caved-in skull. tg's compound fracture with heavy brain damage and a knockdown on top. It sits
// in tg's blunt bone series as a critical, so it replaces a lesser head fracture and gives tg's
// severe brain trauma cycle until the bone is fixed (compound fracture surgery or gel and tape).

/// Brain damage dealt when the skull caves in (brains die at 200).
#define HV_SKULL_BRAIN_DAMAGE 35

/datum/wound/blunt/bone/critical/hv_skull
	name = "Depressed Skull Fracture"
	undiagnosed_name = "Caved-In Skull"
	desc = "Patient's skull has been driven in against the brain."
	treat_text = "Repair surgically and treat the brain damage. Bone gel and surgical tape will hold it in an emergency."
	treat_text_short = "Repair surgically, or apply bone gel and surgical tape."
	simple_desc = "Patient's skull is caved in."
	simple_treat_text = "<b>Surgery</b>, or <b>bone gel</b> and <b>surgical tape</b>. Treat the brain as well."
	homemade_treat_text = "Keep them lying down."
	occur_text = "caves in"

/datum/wound/blunt/bone/critical/hv_skull/apply_wound(obj/item/bodypart/L, silent = FALSE, datum/wound/old_wound = null, smited = FALSE, attack_direction = null, wound_source = "Unknown", replacing = FALSE)
	. = ..()
	examine_desc = "is caved in, the skull driven into a deep dent"

/datum/wound/blunt/bone/critical/hv_skull/wound_injury(datum/wound/old_wound = null, attack_direction = null)
	. = ..()
	if(!victim)
		return
	victim.adjustOrganLoss(ORGAN_SLOT_BRAIN, HV_SKULL_BRAIN_DAMAGE)
	if(victim.stat == DEAD)
		return
	victim.Knockdown(3 SECONDS)
	victim.set_confusion_if_lower(15 SECONDS)
	victim.adjust_eye_blur(10 SECONDS)

#undef HV_SKULL_BRAIN_DAMAGE

/datum/wound_pregen_data/bone/hv_skull
	abstract = FALSE
	wound_path_to_generate = /datum/wound/blunt/bone/critical/hv_skull
	viable_zones = list(BODY_ZONE_HEAD)
	can_be_randomly_generated = FALSE
	threshold_minimum = 115

// ---------------------------------------------------------------------------------------------
// Shattered jaw. tg's hairline fracture on the head without its brain traumas, plus mumbled
// speech while it lasts. Heals like any hairline fracture (surgery, or bone gel and tape).
// tg has no teeth item, so no teeth fly.

/datum/wound/blunt/bone/severe/hv_jaw
	name = "Shattered Jaw"
	undiagnosed_name = "Broken Jaw"
	desc = "Patient's jaw is broken in several places."
	treat_text = "Repair surgically, or set it with bone gel and surgical tape."
	treat_text_short = "Repair surgically, or apply bone gel and surgical tape."
	simple_desc = "Patient's jaw is broken."
	simple_treat_text = "<b>Surgery</b>, or <b>bone gel</b> and <b>surgical tape</b>."
	homemade_treat_text = "Keep them off solid food."
	examine_desc = "hangs open on a shattered jaw"
	occur_text = "has its jaw shattered"
	sound_effect = 'sound/effects/wounds/crack1.ogg'
	brain_trauma_group = null

/datum/wound/blunt/bone/severe/hv_jaw/set_victim(new_victim)
	if(victim)
		UnregisterSignal(victim, COMSIG_LIVING_TREAT_MESSAGE)
	if(new_victim)
		RegisterSignal(new_victim, COMSIG_LIVING_TREAT_MESSAGE, PROC_REF(mumble_speech))
	return ..()

/datum/wound/blunt/bone/severe/hv_jaw/get_scanner_description(mob/user)
	. = ..()
	// tg's bone wounds report brain traumas for any head fracture; a broken jaw gives none.
	. = replacetext(., "Cranial Trauma Detected: Patient will suffer random bouts of mild brain traumas until bone is repaired.", "")

/datum/wound/blunt/bone/severe/hv_jaw/proc/mumble_speech(datum/source, list/message_args)
	SIGNAL_HANDLER
	message_args[TREAT_MESSAGE_ARG] = hv_crit_mumble(message_args[TREAT_MESSAGE_ARG])

/datum/wound_pregen_data/bone/hv_jaw
	abstract = FALSE
	wound_path_to_generate = /datum/wound/blunt/bone/severe/hv_jaw
	viable_zones = list(BODY_ZONE_HEAD)
	can_be_randomly_generated = FALSE
	threshold_minimum = 60

// ---------------------------------------------------------------------------------------------
// Speech mangling for the throat and jaw. Mirrors tg's speech status effects: decode, walk the
// characters (multi-byte safe), re-sanitize.

/// Speech through a cut throat: words drown in blood.
/proc/hv_crit_gargle(message)
	var/static/list/vowels = list("a", "e", "i", "o", "u")
	var/phrase = html_decode(message)
	if(!length(phrase))
		return message
	var/output = ""
	var/char = ""
	for(var/i = 1, i <= length(phrase), i += length(char))
		char = phrase[i]
		if((LOWER_TEXT(char) in vowels) && prob(40))
			output += pick("gh", "rgl", "hl")
		else
			output += char
	return sanitize(output)

/// Speech through a broken jaw: the mouth barely moves.
/proc/hv_crit_mumble(message)
	var/static/list/hard_sounds = list("t", "d", "s", "z", "k", "g", "c", "j", "x", "q")
	var/phrase = html_decode(message)
	if(!length(phrase))
		return message
	var/output = ""
	var/char = ""
	for(var/i = 1, i <= length(phrase), i += length(char))
		char = phrase[i]
		var/lower = LOWER_TEXT(char)
		if((lower in hard_sounds) && prob(60))
			output += (char == lower) ? pick("m", "h", "f") : pick("M", "H", "F")
		else
			output += char
	return sanitize(output)
