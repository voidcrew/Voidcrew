/**
 * # The Athenaeum — wizard vestige
 *
 * A library barge that burned from the inside out when its master mispronounced
 * something. The patron is what the mispronunciation left behind. The trial
 * teaches the first law of the art — magic is paid for in scorched flesh — and
 * the boons are honest wizard spells, granted as-is (neither fireball nor knock
 * requires wizard garb, only the absence of antimagic).
 */

// ===== PATRON =====

/mob/living/basic/vestige_patron/magister
	name = "the Magister's Echo"
	desc = "A wizard-shaped afterimage, like the shadow a flash burns onto a wall. It is still mid-gesture. It has been mid-gesture for a very long time."
	gender = NEUTER
	outfit_path = /datum/outfit/wizard
	appearance_tint = "#6a5480"
	trial_types = list(
		/datum/vestige_trial/singed_hand,
	)
	boon_types = list(
		/datum/vestige_boon/spell/fireball,
		/datum/vestige_boon/spell/knock,
	)
	idle_lines = list(
		"I mispronounced one syllable. ONE. The rest of me is still apologizing for it somewhere.",
		"Four thousand books, and every one of them said the same thing: the price is flesh. I thought I was the exception. So does everyone.",
		"You want the words? The words are easy. Surviving your own mouth is the discipline.",
		"Do not lean on the shelves. The ash remembers being a library, and it is sentimental.",
	)
	accept_line = "Then burn. Properly, this time. Not like I did."
	busy_line = "You are already spoken for. I can smell the other pact on you."
	fulfilled_line = "That lesson is learned. There is no learning it twice."
	renounce_line = "Unsinged. Unlettered. Unremarkable."
	claim_line = "Your tuition is paid. Collect your diploma before you ask for another course."
	exhausted_line = "I have taught you every word I still remember how to say."
	remember_line = "Death mispronounced you back. It happens. Your education, at least, was fireproof."

// ===== TRIAL OF THE SINGED HAND =====

/datum/vestige_trial/singed_hand
	name = "Trial of the Singed Hand"
	// Keep the count in sync with VESTIGE_SINGED_BURN_NEEDED
	// (initial values must be constant, so no define interpolation here)
	desc = "Take the geode. It drinks one thing only: fire that burns YOU. Feed it a hundred measures of burns suffered while it rides on your person — flame, plasma, a welder held wrong, the Echo is not particular — and you will have learned the first law well enough to be taught a word."
	/// Burn damage drunk so far
	var/burn_drunk = 0

/datum/vestige_trial/singed_hand/on_accepted(mob/living/user)
	hand_over(user, new /obj/item/vestige_geode(get_turf(user)))

/datum/vestige_trial/singed_hand/get_progress_text()
	return "The geode has drunk [round(burn_drunk)] of [VESTIGE_SINGED_BURN_NEEDED] measures of fire."

/// May complete (and delete) the trial
/datum/vestige_trial/singed_hand/proc/drink(amount)
	burn_drunk += amount
	refresh_tracker()
	if(burn_drunk >= VESTIGE_SINGED_BURN_NEEDED)
		complete()

/obj/item/vestige_geode
	name = "mana geode"
	desc = "A cracked-open stone lined with crystal the colour of a banked fire. It is warm in exactly the way a hand on your shoulder shouldn't be."
	icon = 'icons/obj/ore.dmi'
	icon_state = "diamond"
	color = "#ff9a4d"
	w_class = WEIGHT_CLASS_SMALL
	light_range = 1.4
	light_power = 0.6
	light_color = "#ff9a4d"
	/// Whose burns we're currently drinking (registered while carried)
	var/mob/living/listening_to

/obj/item/vestige_geode/Destroy()
	stop_listening()
	return ..()

/obj/item/vestige_geode/equipped(mob/user, slot, initial)
	. = ..()
	if(listening_to == user)
		return
	stop_listening()
	if(isliving(user))
		listening_to = user
		RegisterSignal(user, COMSIG_MOB_APPLY_DAMAGE, PROC_REF(on_holder_burned))

/obj/item/vestige_geode/dropped(mob/user)
	. = ..()
	// dropped also fires on slot-to-slot moves; equipped() re-registers right after
	stop_listening()

/obj/item/vestige_geode/proc/stop_listening()
	if(!listening_to)
		return
	UnregisterSignal(listening_to, COMSIG_MOB_APPLY_DAMAGE)
	listening_to = null

/obj/item/vestige_geode/proc/on_holder_burned(mob/living/source, damage, damagetype)
	SIGNAL_HANDLER
	if(damagetype != BURN || damage <= 0)
		return
	var/datum/vestige_trial/singed_hand/trial = source.mind?.active_vestige_trial
	if(!istype(trial))
		return
	if(prob(25))
		to_chat(source, span_notice("[src] pulses warmly, savoring the burn."))
	trial.drink(damage)

// ===== BOONS =====

// Fireball and knock require no wizard garb — only SPELL_REQUIRES_NO_ANTIMAGIC —
// so both grant to a plain human exactly as upstream ships them.
/datum/vestige_boon/spell/fireball
	name = "Fireball"
	desc = "The first word of destruction: point, speak, and a sphere of flame unmakes whatever it lands on. The Echo recommends not standing next to anything you are pointing at."
	grant_text = "A word settles in behind your teeth, hot as a swallowed coal."
	spell_type = /datum/action/cooldown/spell/pointed/projectile/fireball

/datum/vestige_boon/spell/knock
	name = "Knock"
	desc = "The first word of opening. Speak it, and every bolt, lock and latch nearby remembers that it used to be loose."
	grant_text = "A word settles in behind your teeth. Every door in earshot feels briefly nervous."
	spell_type = /datum/action/cooldown/spell/aoe/knock
