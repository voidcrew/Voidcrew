/**
 * # The Athenaeum: wizard vestige
 *
 * A library barge that burned from the inside out when its master mispronounced
 * something. The patron is what the mispronunciation left behind. The trials
 * are tuition in the three disciplines of the art, the price (paid in scorched
 * flesh), the delivery (spoken whole, while burning), and the harder lesson of
 * not speaking at all, and the boons are honest wizard spells, taught as words
 * of the art: granted as-is where upstream asks for no garb (fireball, knock,
 * forcewall), and locally subtyped where it does (blink) or where crew tempo
 * wants a retune.
 */

// Trial tuning (VESTIGE_SINGED_BURN_NEEDED lives in voidcrew/_DEFINES/antag_ruins.dm).
// Trial descs quote these numbers literally. Keep them in sync.
/// Verses the Trial of the Steady Tongue demands, spoken whole while burning
#define VESTIGE_TONGUE_VERSES_NEEDED 3
/// How long each verse must be held without stumbling
#define VESTIGE_TONGUE_VERSE_TIME (5 SECONDS)
/// Burn damage a stumbled verse bites back with
#define VESTIGE_TONGUE_BITE_BURN 5
/// Unbroken carried silence the Trial of the Swallowed Word demands
#define VESTIGE_WORD_SETTLE_TIME (4 MINUTES)
/// Burn damage the word scalds a busy mouth with on its way back up
#define VESTIGE_WORD_SCALD_BURN 5

// ===== PATRON =====

/mob/living/basic/vestige_patron/magister
	name = "the Magister's Echo"
	desc = "A wizard-shaped afterimage, like the shadow a flash burns onto a wall. It is still mid-gesture. It has been mid-gesture for a very long time."
	gender = NEUTER
	outfit_path = /datum/outfit/wizard
	appearance_tint = "#6a5480"
	trial_types = list(
		/datum/vestige_trial/singed_hand,
		/datum/vestige_trial/steady_tongue,
		/datum/vestige_trial/swallowed_word,
	)
	boon_types = list(
		/datum/vestige_boon/spell/fireball,
		/datum/vestige_boon/spell/fireball/refined,
		/datum/vestige_boon/spell/knock,
		/datum/vestige_boon/spell/knock/greater,
		/datum/vestige_boon/spell/word_of_passage,
		/datum/vestige_boon/spell/word_of_denial,
	)
	idle_lines = list(
		"I mispronounced one syllable. ONE. The rest of me is still apologizing for it somewhere.",
		"Four thousand books, and every one of them said the same thing: the price is flesh. I thought I was the exception. So does everyone.",
		"You want the words? The words are easy. Surviving your own mouth is the discipline.",
		"Don't lean on the shelves. The ash still thinks it's a library, and it's sentimental about it.",
		"The library kept silence for thirty years after the fire. Finest lecture ever delivered here. I took notes.",
	)
	accept_line = "Then burn. Properly, this time. Not like I did."
	busy_line = "You're already spoken for. I can smell the other pact on you."
	fulfilled_line = "You've learned that one. There's no learning it twice."
	renounce_line = "Unsinged. Unlettered. Unremarkable."
	claim_line = "Your tuition is paid. Collect your diploma before you sign up for another course."
	exhausted_line = "I've taught you every word I still remember how to say."
	remember_line = "Death mispronounced you. It happens. Your education was fireproof, at least."

// ===== TRIAL OF THE SINGED HAND =====

/datum/vestige_trial/singed_hand
	name = "Trial of the Singed Hand"
	// Keep the count in sync with VESTIGE_SINGED_BURN_NEEDED
	// (initial values must be constant, so no define interpolation here)
	desc = "Take the geode and keep it on you. It feeds on one thing: burns, yours specifically. Take a hundred points of burn damage with it on your person and you've paid the first law's tuition. I don't care how you catch fire."
	/// Burn damage drunk so far
	var/burn_drunk = 0

/datum/vestige_trial/singed_hand/on_accepted(mob/living/user)
	hand_over(user, new /obj/item/vestige_geode(get_turf(user)))

/datum/vestige_trial/singed_hand/get_progress_text()
	return "Burns fed to the geode: [round(burn_drunk)] of [VESTIGE_SINGED_BURN_NEEDED]."

/// May complete (and delete) the trial
/datum/vestige_trial/singed_hand/proc/drink(amount)
	burn_drunk += amount
	refresh_tracker()
	if(burn_drunk >= VESTIGE_SINGED_BURN_NEEDED)
		complete()

/obj/item/vestige_geode
	name = "mana geode"
	desc = "A cracked-open stone lined with crystal the colour of banked embers. It's warmer than it has any business being."
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

// ===== TRIAL OF THE STEADY TONGUE =====

/datum/vestige_trial/steady_tongue
	name = "Trial of the Steady Tongue"
	// Keep the count in sync with VESTIGE_TONGUE_VERSES_NEEDED (file-local, above)
	// (initial values must be constant, so no define interpolation here)
	desc = "Take the primer. Three verses of first-year liturgy, read out loud and finished properly, while you are on fire. I don't care how you catch fire. Stand still and don't stumble - the verses bite students who chew them."
	/// Verses recited whole so far
	var/verses_spoken = 0

/datum/vestige_trial/steady_tongue/on_accepted(mob/living/user)
	hand_over(user, new /obj/item/vestige_primer(get_turf(user)))
	to_chat(user, span_notice("The primer is warm. Books from the Athenaeum never really cooled."))

/datum/vestige_trial/steady_tongue/get_progress_text()
	return "Verses recited in full: [verses_spoken] of [VESTIGE_TONGUE_VERSES_NEEDED]."

/// May complete (and delete) the trial
/datum/vestige_trial/steady_tongue/proc/recite()
	verses_spoken++
	refresh_tracker()
	if(verses_spoken >= VESTIGE_TONGUE_VERSES_NEEDED)
		complete()

/obj/item/vestige_primer
	name = "singed primer"
	desc = "A pocket volume of the Athenaeum's first-year liturgy, scorched exactly to the margins. The margins are full of corrections."
	icon = 'icons/obj/service/library.dmi'
	icon_state = "book"
	color = "#b0663a"
	w_class = WEIGHT_CLASS_SMALL
	/// Whether a verse is currently being recited from these pages
	var/reciting = FALSE
	/// The liturgy, one verse per required recital
	var/static/list/verses = list(
		"ILN ASH VERBA... SOMA VESH ENNA.",
		"OXI ATH'ENNA MORI... VECTA UN'DAL RETH.",
		"SIC ITUR AD ASHTA... EX LIBRIS, EX OSSIBUS.",
	)
	/// The marginalia, one note per verse
	var/static/list/margin_notes = list(
		"The margin note reads: \"The flesh is kindling; the word is what burns.\" It is underlined twice.",
		"The margin note reads: \"Price first. Power after. No exceptions, no refunds.\" The hand is different. Shakier.",
		"The margin note reads: \"Mind the final syllable. MIND IT.\" The pen went through the paper.",
	)

/obj/item/vestige_primer/examine(mob/user)
	. = ..()
	. += span_notice("Embossed on the cover: THE STUDENT MUST BE ALIGHT. Each verse takes [DisplayTimeText(VESTIGE_TONGUE_VERSE_TIME)] of steady reading. Stand still, stay on fire, and don't get interrupted.")

/obj/item/vestige_primer/attack_self(mob/user, modifiers)
	. = ..()
	if(.)
		return
	if(!isliving(user))
		return
	// the recital sleeps (say, do_after); don't hold up the click chain
	INVOKE_ASYNC(src, PROC_REF(recite_verse), user)
	return TRUE

/obj/item/vestige_primer/proc/recite_verse(mob/living/user)
	if(reciting)
		balloon_alert(user, "already mid-verse!")
		return
	var/datum/vestige_trial/steady_tongue/trial = user.mind?.active_vestige_trial
	if(!istype(trial))
		balloon_alert(user, "the pages are blank!")
		return
	if(!user.can_speak())
		balloon_alert(user, "your voice fails you!")
		return
	if(!user.on_fire)
		balloon_alert(user, "you're not on fire!")
		to_chat(user, span_warning("The primer stays shut. The cover repeats itself: THE STUDENT MUST BE ALIGHT."))
		return
	var/verse_index = min(trial.verses_spoken + 1, length(verses))
	user.visible_message(
		span_warning("[user] opens [src] and begins to recite over the sound of [user.p_their()] own burning!"),
		span_notice("You open [src] and read aloud over the sound of your own burning."),
	)
	to_chat(user, span_notice(margin_notes[verse_index]))
	user.say(verses[verse_index], forced = "vestige recitation")
	reciting = TRUE
	var/spoke_whole = do_after(user, VESTIGE_TONGUE_VERSE_TIME, target = user)
	reciting = FALSE
	if(!spoke_whole)
		// The Magister's entire biography, in miniature
		to_chat(user, span_danger("You stumble mid-syllable, and the verse bites back!"))
		user.apply_damage(VESTIGE_TONGUE_BITE_BURN, BURN, BODY_ZONE_HEAD)
		playsound(user, 'sound/effects/wounds/sizzle1.ogg', 40, TRUE)
		return
	if(!user.is_holding(src))
		return
	if(!user.on_fire)
		to_chat(user, span_warning("The fire goes out before you finish, and the primer snaps shut."))
		return
	// Re-resolve; the pact may have been renounced mid-verse
	trial = user.mind?.active_vestige_trial
	if(!istype(trial))
		balloon_alert(user, "the pages are blank!")
		return
	user.say("OM.", forced = "vestige recitation")
	playsound(user, 'sound/effects/magic/fireball.ogg', 30, TRUE)
	to_chat(user, span_boldnotice("Every syllable comes out whole. Somewhere, a dead librarian stops wincing."))
	trial.recite()

// ===== TRIAL OF THE SWALLOWED WORD =====

/datum/vestige_trial/swallowed_word
	name = "Trial of the Swallowed Word"
	// Keep the duration in sync with VESTIGE_WORD_SETTLE_TIME (file-local, above)
	// (initial values must be constant, so no define interpolation here)
	desc = "The other half of the lesson: knowing when not to speak. Take the phial and keep it on you - pocket, belt or hand, never in a bag - and say nothing at all for four unbroken minutes. One word and it burns its way back up your throat and the clock starts over."
	/// world.time at which the carried word settles, or 0 while it isn't listening
	var/settle_at = 0
	/// Times the word has fled a mouth that could not stay shut
	var/escapes = 0
	/// The loaned phial, reclaimed (deleted) the moment the pact ends
	var/obj/item/vestige_syllable/phial

/datum/vestige_trial/swallowed_word/on_accepted(mob/living/user)
	to_chat(user, span_notice("[patron_name] hands it over with exaggerated care and, pointedly, says nothing at all."))
	phial = hand_over(user, new /obj/item/vestige_syllable(get_turf(user)))

/datum/vestige_trial/swallowed_word/Destroy()
	QDEL_NULL(phial)
	return ..()

/datum/vestige_trial/swallowed_word/get_progress_text()
	var/flights = escapes ? " It has escaped your mouth [escapes] time[escapes == 1 ? "" : "s"]." : ""
	if(!settle_at)
		return "The word isn't listening. Carry it on your person, never in a bag, and stay quiet.[flights]"
	return "The word is settling. [DisplayTimeText(max(settle_at - world.time, 1 SECONDS))] of silence to go.[flights]"

/obj/item/vestige_syllable
	name = "sealed syllable"
	desc = "A stoppered phial with something small and bright circling inside, mouthing itself over and over. It stops if you hold it up to your ear."
	icon = 'icons/obj/mining_zones/artefacts.dmi'
	icon_state = "vial"
	w_class = WEIGHT_CLASS_TINY
	light_range = 1.2
	light_power = 0.5
	light_color = "#ffd27f"
	/// Whose silence we're currently listening to (registered while carried)
	var/mob/living/listening_to

/obj/item/vestige_syllable/Destroy()
	// A destroyed phial mustn't leave a countdown that can never land
	var/datum/vestige_trial/swallowed_word/trial = listening_to?.mind?.active_vestige_trial
	if(istype(trial) && trial.settle_at)
		trial.settle_at = 0
		trial.refresh_tracker()
	stop_listening()
	return ..()

/obj/item/vestige_syllable/examine(mob/user)
	. = ..()
	. += span_notice("It only settles for someone who stays quiet. Keep it on your person, never in a bag, and say nothing for [DisplayTimeText(VESTIGE_WORD_SETTLE_TIME)]. Speaking or putting it down restarts the clock.")

/obj/item/vestige_syllable/equipped(mob/user, slot, initial)
	. = ..()
	if(!isliving(user))
		return
	if(listening_to != user)
		stop_listening()
		listening_to = user
		RegisterSignal(user, COMSIG_MOB_SAY, PROC_REF(on_holder_spoke))
	var/datum/vestige_trial/swallowed_word/trial = user.mind?.active_vestige_trial
	if(istype(trial) && !trial.settle_at)
		begin_settling(trial, user)

/obj/item/vestige_syllable/dropped(mob/user)
	. = ..()
	if(!isliving(user))
		return
	// dropped also fires on slot-to-slot moves; give equipped() a tick to land before judging
	addtimer(CALLBACK(src, PROC_REF(check_still_carried), user), 1)

/// A nudge for the stuck cases (renounced and re-accepted mid-carry): restart or report
/obj/item/vestige_syllable/attack_self(mob/user, modifiers)
	. = ..()
	if(.)
		return
	if(!isliving(user))
		return
	var/datum/vestige_trial/swallowed_word/trial = user.mind?.active_vestige_trial
	if(!istype(trial))
		balloon_alert(user, "it doesn't know your voice!")
		return TRUE
	if(!trial.settle_at && listening_to == user)
		begin_settling(trial, user)
	else
		to_chat(user, span_notice(trial.get_progress_text()))
	return TRUE

/obj/item/vestige_syllable/proc/stop_listening()
	if(!listening_to)
		return
	UnregisterSignal(listening_to, COMSIG_MOB_SAY)
	listening_to = null

/**
 * (Re)starts the settling clock. Every (re)start schedules its own settle check;
 * stale checks from older clocks fail the settle_at deadline test and die quietly
 * (the same trick the chrysalis egg's hatch_at plays).
 */
/obj/item/vestige_syllable/proc/begin_settling(datum/vestige_trial/swallowed_word/trial, mob/living/user)
	trial.settle_at = world.time + VESTIGE_WORD_SETTLE_TIME
	trial.refresh_tracker()
	to_chat(user, span_notice("[src] goes quiet against you. It's listening now."))
	addtimer(CALLBACK(src, PROC_REF(try_settle)), VESTIGE_WORD_SETTLE_TIME + 1)

/// The word left this mob's person, or only changed slots, in which case equipped() beat us
/// here and loc is still the mob. A true departure voids the vigil.
/obj/item/vestige_syllable/proc/check_still_carried(mob/living/former)
	if(QDELETED(src) || QDELETED(former))
		return
	if(loc == former)
		return
	if(listening_to == former)
		stop_listening()
	var/datum/vestige_trial/swallowed_word/trial = former.mind?.active_vestige_trial
	if(istype(trial) && trial.settle_at)
		trial.settle_at = 0
		trial.refresh_tracker()
		to_chat(former, span_warning("[src] stirs again the moment it leaves your person. The word has stopped listening."))

/obj/item/vestige_syllable/proc/on_holder_spoke(mob/living/source, list/say_args)
	SIGNAL_HANDLER
	var/datum/vestige_trial/swallowed_word/trial = source.mind?.active_vestige_trial
	if(!istype(trial) || !trial.settle_at)
		return
	trial.settle_at = world.time + VESTIGE_WORD_SETTLE_TIME
	trial.escapes++
	trial.refresh_tracker()
	source.apply_damage(VESTIGE_WORD_SCALD_BURN, BURN, BODY_ZONE_HEAD)
	to_chat(source, span_danger("The word bolts back up your throat, scalding on the way. It won't settle in a mouth that keeps talking."))
	playsound(source, 'sound/effects/wounds/sizzle1.ogg', 30, TRUE)
	addtimer(CALLBACK(src, PROC_REF(try_settle)), VESTIGE_WORD_SETTLE_TIME + 1)

/// May complete the trial, which reclaims (deletes) this phial with it
/obj/item/vestige_syllable/proc/try_settle()
	if(QDELETED(src))
		return
	var/mob/living/holder = listening_to
	if(!holder || loc != holder)
		return
	var/datum/vestige_trial/swallowed_word/trial = holder.mind?.active_vestige_trial
	if(!istype(trial) || !trial.settle_at || world.time < trial.settle_at)
		return
	holder.visible_message(
		span_warning("[src] cracks with a sound like a struck bell."),
		span_notice("The glass parts, and the word slips down your throat and settles, warm as a swallowed coal."),
	)
	playsound(holder, 'sound/effects/magic/fireball.ogg', 20, TRUE)
	trial.complete()

// ===== BOONS =====

// Upstream coupling, verified against code/modules/spells/spell.dm: the base
// spell cast chain has no antag checks and no resource costs, garb is only
// demanded when SPELL_REQUIRES_WIZARD_GARB is set. Fireball, knock and
// forcewall all override spell_requirements down to
// SPELL_REQUIRES_NO_ANTIMAGIC, so they grant to a plain human exactly as
// upstream ships them. Blink never overrides the base default
// (GARB|NO_ANTIMAGIC), so its local subtype below relaxes the garb half.
/datum/vestige_boon/spell/fireball
	name = "Fireball"
	desc = "Point at something and throw a ball of fire at it. Don't stand next to whatever you're pointing at."
	grant_text = "A word settles in behind your teeth, hot as a swallowed coal."
	spell_type = /datum/action/cooldown/spell/pointed/projectile/fireball/vestige

/datum/vestige_boon/spell/fireball/refined
	name = "Refined Fireball"
	desc = "The same fireball on a shorter cooldown, cast with a whisper instead of a shout, and with a tighter blast that wrecks less of what's around the target."
	grant_text = "The coal behind your teeth settles and stops crackling."
	upgrades_from = /datum/vestige_boon/spell/fireball
	spell_type = /datum/action/cooldown/spell/pointed/projectile/fireball/vestige/refined

/datum/vestige_boon/spell/knock
	name = "Knock"
	desc = "Speak the word and every door, locker and lock nearby pops open."
	grant_text = "A word settles in behind your teeth. Every door in earshot feels briefly nervous."
	spell_type = /datum/action/cooldown/spell/aoe/knock

/datum/vestige_boon/spell/knock/greater
	name = "Greater Knock"
	desc = "The same word with more range and a shorter cooldown, and it unbolts bolted airlocks on the way through. Welded or unpowered doors still hold."
	grant_text = "The word behind your teeth grows a second syllable."
	upgrades_from = /datum/vestige_boon/spell/knock
	spell_type = /datum/action/cooldown/spell/aoe/knock/vestige_greater

/datum/vestige_boon/spell/word_of_passage
	name = "Word of Passage"
	desc = "Teleport a short distance. You don't get to pick where - the spell does, and it isn't careful about it."
	grant_text = "A word settles in behind your teeth, and immediately starts fidgeting."
	spell_type = /datum/action/cooldown/spell/teleport/radius_turf/blink/vestige_passage

/datum/vestige_boon/spell/word_of_denial
	name = "Word of Denial"
	desc = "Raise a short barrier that nobody but you can walk through. It holds for a while."
	grant_text = "A word settles in behind your teeth, flat and immovable."
	spell_type = /datum/action/cooldown/spell/forcewall/vestige_denial

// ===== LOCAL SPELLS =====

/**
 * The word of destruction, slowed to something a crew can live around.
 * Upstream fireball's whole chain is clean, pointed/_pointed.dm and
 * projectile/magic.dm carry no antag or garb coupling, and antimagic_flags
 * propagate onto the bolt, so the only thing this subtype changes is the
 * tempo. Upstream speaks it every SIX seconds, which is a wizard mid-ascension
 * with a spellbook to answer for; a permanent ranged explosive on a six second
 * loop in crew hands is not a boon, it is artillery. Forty-five seconds puts it
 * with the other heavy boons (rusted grasp, ashen passage) and makes each cast
 * a decision. Subtyped rather than retuned in place so the wizard's own
 * fireball keeps upstream's numbers, and rank scaling is switched off since a
 * boon has no spellbook to level.
 */
/datum/action/cooldown/spell/pointed/projectile/fireball/vestige
	name = "Crude Fireball"
	cooldown_time = 45 SECONDS
	cooldown_reduction_per_rank = 0 SECONDS

/**
 * The refined word: the same bolt, thirty seconds instead of forty-five, a
 * whispered invocation in place of the shout, and a tighter blast. Contact
 * damage is untouched, the upgrade buys tempo and control, not more damage.
 */
/datum/action/cooldown/spell/pointed/projectile/fireball/vestige/refined
	name = "Refined Fireball"
	desc = "Throw a fireball. A shorter wait between casts, whispered instead of shouted, and a tighter blast."
	cooldown_time = 30 SECONDS
	invocation = "oni soma."
	invocation_type = INVOCATION_WHISPER
	projectile_type = /obj/projectile/magic/fireball/vestige_refined

/// The refined fireball's bolt: same flame and contact damage, smaller
/// structural splash. Mastery reads as control, and ships only have one hull.
/obj/projectile/magic/fireball/vestige_refined
	exp_light = 1 // upstream 2
	exp_flash = 2 // upstream 3

/**
 * The greater word of opening. Upstream knock's cast chain is clean (garb-free,
 * turf-signal based), so this subtype extends it: wider reach, shorter
 * cooldown, and airlock bolts are thrown before the door is asked to open.
 * Base knock's COMSIG_ATOM_MAGICALLY_UNLOCKED handler calls open(), which
 * refuses while locked (verified in door.dm / airlock.dm). Welded, sealed and
 * unpowered doors still hold, so a determined defender keeps counterplay.
 */
/datum/action/cooldown/spell/aoe/knock/vestige_greater
	name = "Greater Knock"
	desc = "Opens nearby doors and closets, and throws the bolts on bolted airlocks."
	cooldown_time = 8 SECONDS // upstream 10
	invocation = "AULIE OXIN FIERA, OMNE!"
	aoe_radius = 4 // upstream 3

/datum/action/cooldown/spell/aoe/knock/vestige_greater/cast_on_thing_in_aoe(turf/victim, atom/caster)
	for(var/obj/machinery/door/airlock/bolted in victim)
		if(bolted.locked)
			bolted.unbolt()
	return ..()

/**
 * The word of passage. Upstream blink's cast chain is clean (_teleport.dm +
 * blink.dm: pick a random nearby turf, do_teleport on the magic channel), but
 * the spell never overrides the base-spell default spell_requirements of
 * SPELL_REQUIRES_WIZARD_GARB|SPELL_REQUIRES_NO_ANTIMAGIC, so as shipped it is
 * garb-locked. This subtype drops the garb half, keeps the antimagic hook, and
 * slows the word to crew tempo, the wizard version recasts every 2 seconds.
 * The destination stays random: the word says away, not where.
 */
/datum/action/cooldown/spell/teleport/radius_turf/blink/vestige_passage
	name = "Word of Passage"
	desc = "Teleports you a short distance in a random direction."
	cooldown_time = 10 SECONDS
	invocation = "sic itur."
	invocation_type = INVOCATION_WHISPER
	spell_requirements = SPELL_REQUIRES_NO_ANTIMAGIC

/**
 * The word of denial. Upstream forcewall is already garb-free
 * (SPELL_REQUIRES_NO_ANTIMAGIC) and its cast is clean: three caster-keyed
 * /obj/effect/forcefield/wizard with a 30 second lifetime, which antimagic
 * bearers simply walk through. Only the cooldown is retuned, upstream's 10
 * seconds lets several wall-lines stand at once, so this word matches its
 * cooldown to the wall's lifetime. One denial at a time; no corridor lockdown.
 */
/datum/action/cooldown/spell/forcewall/vestige_denial
	name = "Word of Denial"
	desc = "Raise a barrier only you can pass through. It holds for a while."
	cooldown_time = 30 SECONDS // upstream 10; matched to the wall's 30 second lifetime

#undef VESTIGE_TONGUE_VERSES_NEEDED
#undef VESTIGE_TONGUE_VERSE_TIME
#undef VESTIGE_TONGUE_BITE_BURN
#undef VESTIGE_WORD_SETTLE_TIME
#undef VESTIGE_WORD_SCALD_BURN
