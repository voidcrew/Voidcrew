/**
 * # The Scarlet Sepulcher — cult vestige
 *
 * A votive barge whose congregation bled out waiting for an ending. Trials
 * are rites: a remote ritual sacrifice, and a long tithe of the supplicant's
 * own blood. Boons are blood magic reimplemented without IS_CULTIST checks.
 */

// ===== PATRON =====

/mob/living/basic/vestige_patron/havel
	name = "Sister Havel"
	desc = "The last acolyte of the Sepulcher, chained at the wrist to her own altar. The chain has grown into the skin. She does not seem to mind."
	gender = FEMALE
	outfit_path = /datum/outfit/job/chaplain
	appearance_tint = "#e8d5d5"
	trial_types = list(
		/datum/vestige_trial/offering,
		/datum/vestige_trial/vigil,
	)
	idle_lines = list(
		"The congregation is still here. You're standing in them.",
		"Blood is the only coin that never inflates.",
		"We were promised an ending. We are still owed.",
		"The altar drinks. The altar remembers. The altar pays its debts.",
	)
	accept_line = "The Sepulcher witnesses your pact."
	busy_line = "You already owe. Pay first, or renounce."
	fulfilled_line = "That rite is already written in you."
	renounce_line = "The Sepulcher remembers cowards too."

// ===== RITE OF OFFERING =====

/datum/vestige_trial/offering
	name = "Rite of Offering"
	// Keep the count in sync with VESTIGE_OFFERING_CANDLES
	// (initial values must be constant, so no define interpolation here)
	desc = "Take the satchel: chalk, candles, a knife. Far from this place, scribe the rune, ring it in three lit candles, and give it a dead body that once held a soul. The rite must be worked beyond these walls — the Sepulcher may only watch from a distance."
	boon_type = /datum/vestige_boon/spell/crimson_step
	/// Whether the rune has been scribed somewhere
	var/rune_scribed = FALSE

/datum/vestige_trial/offering/on_accepted(mob/living/user)
	hand_over(user, new /obj/item/storage/box/vestige_ritual(get_turf(user)))

/datum/vestige_trial/offering/get_progress_text()
	return rune_scribed ? "The rune waits: candlelight, and a body that once held a soul." : "Scribe the rune somewhere far from the Sepulcher."

/obj/item/storage/box/vestige_ritual
	name = "ritual satchel"
	desc = "Chalk, candles, a knife and a light. Assembly is the easy part."

/obj/item/storage/box/vestige_ritual/PopulateContents()
	new /obj/item/vestige_chalk(src)
	for(var/i in 1 to VESTIGE_OFFERING_CANDLES)
		new /obj/item/flashlight/flare/candle(src)
	new /obj/item/knife/ritual/vestige(src)
	new /obj/item/lighter(src)

/obj/item/vestige_chalk
	name = "grave chalk"
	desc = "Chalk cut with ash and something darker. It only wants to draw one shape."
	icon = 'icons/obj/art/crayons.dmi'
	icon_state = "crayonwhite"
	w_class = WEIGHT_CLASS_TINY

/obj/item/vestige_chalk/interact_with_atom(atom/interacting_with, mob/living/user, list/modifiers)
	if(!isopenturf(interacting_with) || isspaceturf(interacting_with))
		return NONE
	var/turf/open/target_turf = interacting_with
	var/datum/vestige_trial/offering/trial = user.mind?.active_vestige_trial
	if(!istype(trial))
		balloon_alert(user, "the chalk refuses your hand!")
		return ITEM_INTERACT_BLOCKING
	if(istype(get_area(target_turf), /area/ruin/space/has_grav/vestige))
		balloon_alert(user, "too close to the sepulcher!")
		return ITEM_INTERACT_BLOCKING
	if(locate(/obj/structure/vestige_rune) in target_turf)
		balloon_alert(user, "already scribed!")
		return ITEM_INTERACT_BLOCKING
	balloon_alert(user, "scribing...")
	if(!do_after(user, 8 SECONDS, target = target_turf))
		return ITEM_INTERACT_BLOCKING
	// Re-resolve; the pact may have been renounced mid-scribe
	trial = user.mind?.active_vestige_trial
	if(!istype(trial))
		return ITEM_INTERACT_BLOCKING
	new /obj/structure/vestige_rune(target_turf)
	trial.rune_scribed = TRUE
	trial.refresh_tracker()
	user.visible_message(
		span_warning("[user] scribes a wide crimson rune across the floor."),
		span_notice("You scribe the rune. Candlelight next — then the offering."),
	)
	return ITEM_INTERACT_SUCCESS

/obj/structure/vestige_rune
	name = "offering rune"
	desc = "A wide crimson rune. The floor under it feels like it's listening."
	icon = 'icons/obj/antags/cult/rune.dmi'
	icon_state = "1"
	anchored = TRUE
	density = FALSE
	plane = FLOOR_PLANE
	layer = RUNE_LAYER
	color = "#9e1a1a"
	resistance_flags = FIRE_PROOF

/obj/structure/vestige_rune/examine(mob/user)
	. = ..()
	. += span_notice("It wants a ring of [VESTIGE_OFFERING_CANDLES] lit candles, a dead humanoid that once held a soul laid upon it, and a knife with intent behind it.")

/obj/structure/vestige_rune/attackby(obj/item/attacking_item, mob/user, params)
	if(!istype(attacking_item, /obj/item/knife/ritual/vestige))
		return ..()
	INVOKE_ASYNC(src, PROC_REF(attempt_offering), user)
	return TRUE

/obj/structure/vestige_rune/proc/attempt_offering(mob/living/user)
	var/datum/vestige_trial/offering/trial = user.mind?.active_vestige_trial
	if(!istype(trial))
		balloon_alert(user, "the rune ignores you!")
		return
	var/lit_candles = 0
	for(var/obj/item/flashlight/flare/candle/candle in range(2, src))
		if(candle.light_on)
			lit_candles++
	if(lit_candles < VESTIGE_OFFERING_CANDLES)
		balloon_alert(user, "needs [VESTIGE_OFFERING_CANDLES] lit candles!")
		return
	var/mob/living/carbon/human/offering
	for(var/mob/living/carbon/human/body in get_turf(src))
		if(body.stat == DEAD && body.mind)
			offering = body
			break
	if(!offering)
		balloon_alert(user, "needs a soul-touched corpse on the rune!")
		return
	user.visible_message(
		span_bolddanger("[user] raises the knife over [offering] and begins a rite!"),
		span_danger("You begin the rite of offering."),
	)
	playsound(src, 'sound/effects/magic/enter_blood.ogg', 50, TRUE)
	if(!do_after(user, 8 SECONDS, target = src))
		return
	// Everything must still hold at the end of the channel
	trial = user.mind?.active_vestige_trial
	if(!istype(trial))
		return
	if(QDELETED(offering) || get_turf(offering) != get_turf(src) || offering.stat != DEAD || !offering.mind)
		balloon_alert(user, "the offering left the rune!")
		return
	offering.visible_message(span_bolddanger("[offering] collapses into a column of ash above the rune!"))
	playsound(src, 'sound/effects/magic/demon_consume.ogg', 60, TRUE)
	offering.dust(TRUE, TRUE)
	trial.complete()
	qdel(src)

/obj/item/knife/ritual/vestige
	name = "sepulcher knife"
	desc = "A ritual knife whose edge stays warm. It knows exactly one prayer."

// ===== VIGIL OF BLOOD =====

/datum/vestige_trial/vigil
	name = "Vigil of Blood"
	// Keep the amount in sync with VESTIGE_VIGIL_BLOOD_TOTAL
	// (initial values must be constant, so no define interpolation here)
	desc = "The altar drinks. Feed it 400 units of your own living blood — as many visits as it takes. It will not take from the dead, the borrowed or the bottled. Only you, only fresh."
	boon_type = /datum/vestige_boon/spell/sanguine_blade
	/// Blood donated so far
	var/blood_given = 0

/datum/vestige_trial/vigil/get_progress_text()
	return "The altar has drunk [blood_given] of [VESTIGE_VIGIL_BLOOD_TOTAL] units."

/// May complete (and delete) the trial
/datum/vestige_trial/vigil/proc/donate(amount)
	blood_given += amount
	refresh_tracker()
	if(blood_given >= VESTIGE_VIGIL_BLOOD_TOTAL)
		complete()

/obj/structure/vestige_altar
	name = "sepulcher altar"
	desc = "A stone altar with a groove worn smooth down the middle. It is very obviously a drain."
	icon = 'icons/obj/antags/cult/structures.dmi'
	icon_state = "talismanaltar"
	anchored = TRUE
	density = TRUE
	resistance_flags = INDESTRUCTIBLE | LAVA_PROOF | FIRE_PROOF | UNACIDABLE | ACID_PROOF

/obj/structure/vestige_altar/attack_hand(mob/living/user, list/modifiers)
	. = ..()
	if(.)
		return
	INVOKE_ASYNC(src, PROC_REF(attempt_donation), user)
	return TRUE

/obj/structure/vestige_altar/proc/attempt_donation(mob/living/carbon/human/user)
	if(!ishuman(user))
		return
	var/datum/vestige_trial/vigil/trial = user.mind?.active_vestige_trial
	if(!istype(trial))
		to_chat(user, span_warning("You press a palm to the stone. Nothing happens — no pact binds your blood to it."))
		return
	if(HAS_TRAIT(user, TRAIT_NOBLOOD) || !user.blood_volume)
		to_chat(user, span_warning("The altar finds nothing in you worth drinking."))
		return
	if(user.blood_volume < BLOOD_VOLUME_SAFE)
		to_chat(user, span_warning("You are too drained. The altar refuses dregs — come back fuller."))
		return
	user.visible_message(
		span_warning("[user] presses [user.p_their()] palm into the altar's groove..."),
		span_danger("The altar bites."),
	)
	if(!do_after(user, 4 SECONDS, target = src))
		return
	trial = user.mind?.active_vestige_trial
	if(!istype(trial) || user.blood_volume < BLOOD_VOLUME_SAFE)
		return
	user.blood_volume -= VESTIGE_VIGIL_BLOOD_PER_DONATION
	playsound(src, 'sound/effects/magic/enter_blood.ogg', 50, TRUE)
	to_chat(user, span_notice("Your blood runs along the groove and disappears. The altar drinks deep."))
	trial.donate(VESTIGE_VIGIL_BLOOD_PER_DONATION)

// ===== BOONS =====

/datum/vestige_boon/spell/crimson_step
	name = "Crimson Step"
	grant_text = "The space behind your eyes folds. Distance is a suggestion now, and it is written in red."
	spell_type = /datum/action/cooldown/spell/teleport/radius_turf/blink/crimson

// The wizard blink, paced down from spammable to deliberate
/datum/action/cooldown/spell/teleport/radius_turf/blink/crimson
	name = "Crimson Step"
	desc = "Fold yourself a short distance through somewhere red and wet."
	button_icon = 'icons/mob/actions/actions_cult.dmi'
	button_icon_state = "tele"
	cooldown_time = 15 SECONDS
	cooldown_reduction_per_rank = 0 SECONDS
	outer_tele_radius = 5
	spell_requirements = SPELL_REQUIRES_NO_ANTIMAGIC

/datum/vestige_boon/spell/sanguine_blade
	name = "Sanguine Blade"
	grant_text = "A knife-shaped absence settles against your palm. It will come when called."
	spell_type = /datum/action/cooldown/spell/vestige_sanguine_blade

/datum/action/cooldown/spell/vestige_sanguine_blade
	name = "Sanguine Blade"
	desc = "Call the Sepulcher's knife into your hand, or send it back."
	button_icon = 'icons/mob/actions/actions_cult.dmi'
	button_icon_state = "dagger"
	school = SCHOOL_CONJURATION
	cooldown_time = 10 SECONDS
	invocation_type = INVOCATION_NONE
	spell_requirements = NONE

/datum/action/cooldown/spell/vestige_sanguine_blade/is_valid_target(atom/cast_on)
	return iscarbon(cast_on)

/datum/action/cooldown/spell/vestige_sanguine_blade/cast(mob/living/carbon/cast_on)
	. = ..()
	var/obj/item/knife/ritual/vestige/bound/blade = locate() in cast_on.held_items
	if(blade)
		cast_on.visible_message(span_warning("[blade] dissolves into red mist!"), span_notice("You send the knife back."))
		qdel(blade)
		return
	var/obj/item/knife/ritual/vestige/bound/new_blade = new(cast_on)
	if(!cast_on.put_in_hands(new_blade))
		if(!QDELETED(new_blade)) // DROPDEL usually beat us to it
			qdel(new_blade)
		cast_on.balloon_alert(cast_on, "no free hand!")
		reset_spell_cooldown()
		return
	cast_on.visible_message(
		span_warning("A knife condenses out of red mist in [cast_on]'s hand!"),
		span_notice("The knife answers."),
	)
	playsound(cast_on, 'sound/effects/magic/enter_blood.ogg', 30, TRUE)

/obj/item/knife/ritual/vestige/bound
	name = "sanguine blade"
	desc = "The Sepulcher's knife, bound to a pact. It goes home when it leaves the hand."
	force = 18
	item_flags = ABSTRACT | DROPDEL
