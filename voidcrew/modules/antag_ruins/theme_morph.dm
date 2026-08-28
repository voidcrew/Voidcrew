/**
 * # The Facsimile: morph vestige
 *
 * The parlor deck of a luxury liner, preserved mid-soiree. A morph fed here
 * for months and did it thoroughly: ate everything, became everything, twice
 * over, the second time is the important one, the first is only tracing,
 * and practiced being the passengers until the practicing wore through. What
 * remains is the Understudy, a patron that can no longer hold any shape at
 * all and is desperately fond of anyone who can.
 *
 * Trials are performances, and every one of them keeps the supplicant moving:
 * the Perfect Copy (wear a shape, creep close, burst out, fresh shape, fresh
 * face, every time), the Snatched Meal (feed the maw things still warm from
 * someone else's hands), and the Understudy (wear a person and tail them
 * while they live their life; a parked quarry pays nothing). The disguises
 * are appearance-deep and kit-driven, no antag datum, no species swap; the
 * second skin stamps a borrowed appearance over a plain human and takes it
 * back off again.
 *
 * The boon datums this patron pays out of (the mimic-form chain, the devour
 * chain, ambush instinct, rubber bones) are defined in the theme's boon file;
 * only their typepaths are listed here.
 */

// ===== The Perfect Copy =====
// Distinct startled victims the Perfect Copy demands. Keep the trial desc's
// "three" in sync.
#define VESTIGE_STARTLES_NEEDED 3
// How long any one borrowed object shape holds before it sloughs off. Keep
// the trial desc's "three-quarters of a minute" in sync.
#define VESTIGE_SKIN_FORM_TIME (45 SECONDS)
// Jitter left on a startled victim, flavor and shakes, never a stun
#define VESTIGE_STARTLE_JITTER (10 SECONDS)
// Movespeed slowdown while creeping around inside an object shape
#define VESTIGE_SKIN_CREEP_SLOWDOWN 4

// ===== The Snatched Meal =====
// Devoured morsels the Snatched Meal demands, each from a different owner.
// Keep the trial desc's "three" in sync.
#define VESTIGE_MEALS_NEEDED 3
// How far the maw watches for items riding living hands
#define VESTIGE_MAW_SENSE_RANGE 7
// How long after the maw last saw an item in a living grip it stays warm
// enough to count. Keep the trial desc's "ten heartbeats" in sync.
#define VESTIGE_MAW_MEMORY_WINDOW (10 SECONDS)
// The gulp channel
#define VESTIGE_MAW_GULP_TIME (1.5 SECONDS)

// ===== The Understudy =====
// Cumulative seconds of shadowing the Understudy demands. Keep the trial
// desc's "a full minute" in sync.
#define VESTIGE_SHADOW_SECONDS_NEEDED 60
// The study channel. Keep the trial desc's "five seconds" in sync.
#define VESTIGE_STUDY_TIME (5 SECONDS)
// How close the tail must stay to its quarry for the clock to run
#define VESTIGE_SHADOW_RANGE 7
// How recently the quarry must have moved for the clock to run, a seated or
// AFK quarry pauses the tail without punishing it
#define VESTIGE_QUARRY_IDLE_GRACE (10 SECONDS)

// ===== Second skin form states =====
#define SKIN_FORM_NONE 0
#define SKIN_FORM_OBJECT 1
#define SKIN_FORM_PERSON 2

// ===== PATRON =====

/mob/living/basic/vestige_patron/morph
	name = "the Understudy"
	desc = "A parlor-pink heap that keeps almost turning into things: a chair leg, a hand, half of a smile. Nothing holds for more than a second. It watches you the way a painter watches a bowl of fruit."
	gender = NEUTER
	icon = 'icons/mob/simple/animal.dmi'
	icon_state = "morph"
	icon_living = "morph"
	speak_emote = list("gurgles")
	appearance_tint = "#b8d49c" // curdled, queasy. A green that has been reused too many times
	trial_types = list(
		/datum/vestige_trial/perfect_copy,
		/datum/vestige_trial/snatched_meal,
		/datum/vestige_trial/understudy,
	)
	boon_types = list(
		/datum/vestige_boon/spell/mimic_form,
		/datum/vestige_boon/spell/mimic_form/flawless,
		/datum/vestige_boon/spell/devour,
		/datum/vestige_boon/spell/devour/gluttony,
		/datum/vestige_boon/spell/ambush_instinct,
		/datum/vestige_boon/rubber_bones,
	)
	idle_lines = list(
		"You are... a chair. No. A person. Yes! A person. Forgive me. The parlor had a great many chairs, and only some of them screamed.",
		"I was a grand piano for three weeks once. Nobody played me. Not once.",
		"Hold still a moment. One face, every single day, the same face. I don't know how you manage it.",
		"I ate the passengers, then I was the passengers, and then I practiced being them until there was nothing left to practice with.",
		"Being a person is mostly edges. You keep yours in the same places every single day. Astonishing.",
		"Say something else, I'm learning your mouth. It's a good mouth. The vowels would come out crooked in mine.",
		"I was everything on that deck twice over. The first go is only tracing. The second one is where you get it right.",
	)
	accept_line = "Yes! Go. Be something, be someone. You'll be wonderful, you have such a committed outline."
	busy_line = "You're already wearing someone else's errand. Two roles at once is how I ended up like this. Finish it or take it off."
	fulfilled_line = "You did that one already, and you did it well. An encore would just be the same shape, worse."
	renounce_line = "Oh. You can just... take it off. I never learned that part."
	claim_line = "Wait, the applause! You're owed applause. Take it, take it, you were wonderful."
	exhausted_line = "I've shown you every shape I still remember being. There isn't anything after that."
	remember_line = "You stopped! Went all loose, like a coat off its hook. I kept your part for you though, every line of it. Go on, back into yourself."

// ===== THE PERFECT COPY =====

/datum/vestige_trial/perfect_copy
	name = "The Perfect Copy"
	// Keep the numbers in sync with VESTIGE_STARTLES_NEEDED / VESTIGE_SKIN_FORM_TIME
	// (initial values must be constant, so no define interpolation here)
	desc = "Take the skin and press it against something ordinary (a crate, a mop bucket, whatever is handy) and you will be that thing. You can creep around in it, slowly. When somebody wanders within a step of you, burst out at them. Three different people, and a different shape for each one; a shape you have already used goes baggy and won't play twice. The skin only holds any shape for three-quarters of a minute, so keep moving."
	/// Victims already startled (weakref -> TRUE); each face jumps for you exactly once
	var/list/startled = list()
	/// Object typepaths already worn for a credited reveal; a worn shape never plays twice
	var/list/spent_shapes = list()
	/// The loaned skin, reclaimed (deleted, breaking any held form) the moment the pact ends
	var/obj/item/vestige_second_skin/skin

/datum/vestige_trial/perfect_copy/on_accepted(mob/living/user)
	skin = hand_over(user, new /obj/item/vestige_second_skin(get_turf(user)))
	to_chat(user, span_notice("The second skin drapes itself over your arm and holds on."))

/datum/vestige_trial/perfect_copy/Destroy()
	QDEL_NULL(skin)
	return ..()

/datum/vestige_trial/perfect_copy/get_progress_text()
	return "You have burst out at [length(startled)] of [VESTIGE_STARTLES_NEEDED] unsuspecting people. A shape you have used won't work twice."

/**
 * Credits a burst-out reveal. May complete (and delete) the trial, and the
 * loaned skin with it, so the skin must call this last and touch nothing after.
 * Returns FALSE if this victim has already jumped or this shape already played.
 */
/datum/vestige_trial/perfect_copy/proc/startle(mob/living/victim, shape_type)
	var/datum/weakref/key = WEAKREF(victim)
	if(startled[key] || (shape_type in spent_shapes))
		return FALSE
	startled[key] = TRUE
	spent_shapes += shape_type
	refresh_tracker()
	if(length(startled) >= VESTIGE_STARTLES_NEEDED)
		complete()
	return TRUE

// ===== THE SNATCHED MEAL =====

/datum/vestige_trial/snatched_meal
	name = "The Snatched Meal"
	// Keep the numbers in sync with VESTIGE_MEALS_NEEDED / VESTIGE_MAW_MEMORY_WINDOW
	// (initial values must be constant, so no define interpolation here)
	desc = "Take the maw. It was one of my mouths, once. It only wants things that are still warm: something a living person was holding ten seconds ago and isn't holding now. Disarm somebody, wrestle it off them, or get a friend to hand one over, then feed it to the maw before it cools. Three items, from three different owners."
	/// Owners the maw has already tasted a morsel from (weakref -> TRUE); one dish per table
	var/list/fed_from = list()

/datum/vestige_trial/snatched_meal/on_accepted(mob/living/user)
	// Not reclaimed on pact end: without a pact the maw is toothless (see below),
	// same deal as the Stranger's censer and the clan seal
	hand_over(user, new /obj/item/vestige_gnash_maw(get_turf(user)))
	to_chat(user, span_notice("The gnash-maw works its jaw once, tasting your fingers."))

/datum/vestige_trial/snatched_meal/get_progress_text()
	return "The maw has swallowed [length(fed_from)] of [VESTIGE_MEALS_NEEDED] still-warm items."

/**
 * Credits a devoured morsel against its last holder. May complete (and delete)
 * the trial. Returns FALSE if the maw has already tasted this person.
 */
/datum/vestige_trial/snatched_meal/proc/devour(mob/living/last_holder)
	var/datum/weakref/key = WEAKREF(last_holder)
	if(fed_from[key])
		return FALSE
	fed_from[key] = TRUE
	refresh_tracker()
	if(length(fed_from) >= VESTIGE_MEALS_NEEDED)
		complete()
	return TRUE

/obj/item/vestige_gnash_maw
	name = "gnash-maw"
	desc = "A ring of someone else's teeth wrapped around a very small stomach. It only eats things that were in another person's hand a moment ago. Everything else it turns down."
	icon = 'voidcrew/modules/antag_ruins/icons/vestige.dmi'
	icon_state = "gnash_maw"
	w_class = WEIGHT_CLASS_SMALL
	force = 5
	attack_verb_continuous = list("gnashes", "gums", "chews on")
	attack_verb_simple = list("gnash", "gum", "chew on")
	/// What the maw has lately seen riding living, minded hands:
	/// item weakref -> list(holder weakref, world.time last seen held)
	var/list/seen_warm = list()

/obj/item/vestige_gnash_maw/Initialize(mapload)
	. = ..()
	START_PROCESSING(SSobj, src)

/obj/item/vestige_gnash_maw/Destroy()
	STOP_PROCESSING(SSobj, src)
	return ..()

/obj/item/vestige_gnash_maw/examine(mob/user)
	. = ..()
	. += span_notice("Use it on an item that left a living person's hand moments ago (knocked loose, taken, or handed over) and it swallows the item whole. It won't take two items from the same person, and it ignores anything it didn't just watch being held.")

// The maw watches the room from its carrier's person, noting every item in a
// living hand it can see. This memory, not any global last-owner var, which
// this fork does not keep. Is what "still warm" means at devour time.
/obj/item/vestige_gnash_maw/process(seconds_per_tick)
	var/mob/living/carrier = loc
	if(!istype(carrier))
		return
	// Forget what has gone cold
	var/list/stale = list()
	for(var/datum/weakref/key as anything in seen_warm)
		var/list/memory = seen_warm[key]
		if(!memory || world.time - memory[2] > VESTIGE_MAW_MEMORY_WINDOW)
			stale += key
	seen_warm -= stale
	// Note every item riding a living, minded hand in sight. The mind check is
	// the usual anti-farm clause: a rack of mindless monkeys owns nothing.
	for(var/mob/living/holder in view(VESTIGE_MAW_SENSE_RANGE, carrier))
		if(holder == carrier || holder.stat == DEAD || !holder.mind)
			continue
		for(var/obj/item/held in holder.held_items)
			if(held.item_flags & (ABSTRACT|HAND_ITEM))
				continue
			seen_warm[WEAKREF(held)] = list(WEAKREF(holder), world.time)

/obj/item/vestige_gnash_maw/interact_with_atom(atom/interacting_with, mob/living/user, list/modifiers)
	if(!isitem(interacting_with))
		return NONE
	var/obj/item/morsel = interacting_with
	if(morsel == src || (morsel.item_flags & (ABSTRACT|HAND_ITEM)))
		return NONE
	var/datum/vestige_trial/snatched_meal/trial = user.mind?.active_vestige_trial
	if(!istype(trial))
		balloon_alert(user, "the maw just yawns")
		return ITEM_INTERACT_BLOCKING
	if(morsel.resistance_flags & INDESTRUCTIBLE)
		balloon_alert(user, "it would chip a tooth!")
		return ITEM_INTERACT_BLOCKING
	// It must have LEFT their possession. A held thing is a meal not yet snatched
	if(ismob(morsel.loc) && morsel.loc != user)
		balloon_alert(user, "still in their grip, take it first!")
		return ITEM_INTERACT_BLOCKING
	if(!isturf(morsel.loc) && morsel.loc != user)
		balloon_alert(user, "drag it into the open first!")
		return ITEM_INTERACT_BLOCKING
	var/list/memory = seen_warm[WEAKREF(morsel)]
	if(!memory || world.time - memory[2] > VESTIGE_MAW_MEMORY_WINDOW)
		balloon_alert(user, "gone cold!")
		to_chat(user, span_warning("The maw only wants what it just watched leave somebody's hand. This has been lying around too long."))
		return ITEM_INTERACT_BLOCKING
	var/datum/weakref/holder_ref = memory[1]
	var/mob/living/last_holder = holder_ref?.resolve()
	if(!last_holder || last_holder == user)
		balloon_alert(user, "nobody else's warmth on it!")
		return ITEM_INTERACT_BLOCKING
	if(trial.fed_from[WEAKREF(last_holder)])
		balloon_alert(user, "already tasted them!")
		to_chat(user, span_warning("The maw remembers the taste of [last_holder] and won't take seconds. Go find someone else's."))
		return ITEM_INTERACT_BLOCKING
	balloon_alert(user, "gulping...")
	if(!do_after(user, VESTIGE_MAW_GULP_TIME, target = morsel))
		return ITEM_INTERACT_BLOCKING
	if(!user.is_holding(src) || QDELETED(morsel))
		return ITEM_INTERACT_BLOCKING
	// They snatched it back mid-gulp: it is in someone's possession again
	if(ismob(morsel.loc) && morsel.loc != user)
		balloon_alert(user, "wrestled away!")
		return ITEM_INTERACT_BLOCKING
	// Re-resolve; the pact may have been renounced mid-gulp
	trial = user.mind?.active_vestige_trial
	if(!istype(trial))
		return ITEM_INTERACT_BLOCKING
	user.visible_message(
		span_warning("[src] unhinges far wider than it has any right to and swallows [morsel] whole!"),
		span_notice("The maw gulps [morsel] down in one go, still warm from [last_holder]'s hands."),
	)
	playsound(src, 'sound/items/eatfood.ogg', 50, TRUE)
	seen_warm -= WEAKREF(morsel)
	qdel(morsel)
	trial.devour(last_holder) // may complete (and delete) the trial, nothing touches it after this
	return ITEM_INTERACT_SUCCESS

// ===== THE UNDERSTUDY =====

/datum/vestige_trial/understudy
	name = "The Understudy"
	// Keep the numbers in sync with VESTIGE_SHADOW_SECONDS_NEEDED / VESTIGE_STUDY_TIME
	// (initial values must be constant, so no define interpolation here)
	desc = "Now a person. Stand next to one and study them for five seconds (they will notice, everyone notices) then put their face on and follow them. Stay close while they are up and moving: a full minute of tailing them, all told. If they stop moving the clock stops too, and losing them or taking the face off doesn't cost you anything you have already banked."
	/// Cumulative deciseconds spent actively shadowing the quarry
	var/shadow_time = 0
	/// The loaned skin, reclaimed (deleted, breaking any worn face) the moment the pact ends
	var/obj/item/vestige_second_skin/skin

/datum/vestige_trial/understudy/on_accepted(mob/living/user)
	skin = hand_over(user, new /obj/item/vestige_second_skin(get_turf(user)))
	to_chat(user, span_notice("The second skin settles across your shoulders and waits to be introduced to someone."))

/datum/vestige_trial/understudy/Destroy()
	QDEL_NULL(skin)
	return ..()

/datum/vestige_trial/understudy/get_progress_text()
	return "You have shadowed your quarry for [DisplayTimeText(shadow_time)] of [DisplayTimeText(VESTIGE_SHADOW_SECONDS_NEEDED SECONDS)]."

/// Accrues tailing time. May complete (and delete) the trial, and the loaned
/// skin with it, so the skin must call this last and touch nothing after.
/datum/vestige_trial/understudy/proc/shadow(deciseconds)
	shadow_time += deciseconds
	refresh_tracker()
	if(shadow_time < VESTIGE_SHADOW_SECONDS_NEEDED SECONDS)
		return
	complete()

// ===== THE SECOND SKIN =====

/**
 * The Facsimile's shared kit: a wearable appearance, morph-style, stamped onto
 * a plain human. Both disguise trials speak through it, pressed to an object
 * it serves the Perfect Copy, held to a studied person it serves the
 * Understudy, and each mode wakes only for its own pact, resolved off the
 * wielder's mind at interaction time (the kit rule: no trial refs, ever).
 *
 * A worn form is appearance-deep and honest about it: examine at close range
 * gives the morph's classic tell, taking any damage or throwing any violence
 * breaks it, and letting go of the skin lets go of the shape. Humans love to
 * rebuild their own icon out from under a disguise, so the finished look is
 * snapshotted and re-stamped every tick while worn; shedding restores the
 * pre-form snapshot and then lets regenerate_icons() heal any drift.
 */
/obj/item/vestige_second_skin
	name = "second skin"
	desc = "A shawl of pale morph hide that never quite finished deciding what it was. Press it against something, or someone, and it remembers how to be them and brings you along."
	icon = 'icons/obj/stack_objects.dmi'
	icon_state = "sheet-hide"
	color = "#b8d49c"
	w_class = WEIGHT_CLASS_SMALL
	/// SKIN_FORM_*: the disguise currently worn
	var/form = SKIN_FORM_NONE
	/// The mob wearing the form (weakref; the skin rides their person, but never trust a loc)
	var/datum/weakref/wearer_ref
	/// The wearer's appearance from before the form went on, restored on shed
	var/saved_appearance
	/// The wearer's real_name from before a person form went on (null outside person forms)
	var/saved_real_name
	/// The finished disguise, re-stamped every tick, human icon rebuilds love to undo it
	var/form_appearance
	/// Typepath of the object the current form copies (the Perfect Copy's dedup key)
	var/form_source_type
	/// When the current object form sloughs off on its own (0 outside object forms)
	var/form_expires = 0
	/// The person the current form copies (the Understudy's quarry)
	var/datum/weakref/quarry_ref
	/// "x:y:z" of the quarry last tick; a change marks them as moving
	var/quarry_last_spot
	/// When the quarry was last seen to move (0 = not yet since forming)
	var/quarry_last_moved = 0

/obj/item/vestige_second_skin/Initialize(mapload)
	. = ..()
	START_PROCESSING(SSobj, src)

/obj/item/vestige_second_skin/Destroy()
	STOP_PROCESSING(SSobj, src)
	shed_form(feedback = FALSE) // reclaimed mid-form by a dying pact: put the wearer back first
	return ..()

/obj/item/vestige_second_skin/examine(mob/user)
	. = ..()
	. += span_notice("Use it on an object to wear that object's shape, creep close to somebody, then use it in hand to burst out. Use it on a person to study them for five seconds and wear them instead, then follow them around. Taking damage, attacking anyone, or letting go of the skin breaks the disguise.")

// The disguise is the skin; letting go of one is letting go of the other
/obj/item/vestige_second_skin/dropped(mob/user, silent = FALSE)
	. = ..()
	if(isliving(user))
		shed_form(user)

/obj/item/vestige_second_skin/attack_self(mob/user)
	. = ..()
	if(.)
		return
	if(!isliving(user))
		return
	switch(form)
		if(SKIN_FORM_OBJECT)
			burst(user)
		if(SKIN_FORM_PERSON)
			shed_form(user)
		else
			balloon_alert(user, "press it against a shape first!")

/obj/item/vestige_second_skin/interact_with_atom(atom/interacting_with, mob/living/user, list/modifiers)
	if(isliving(interacting_with))
		return study_person(interacting_with, user)
	if(isobj(interacting_with))
		return wear_object(interacting_with, user)
	return NONE

/**
 * The Perfect Copy's mode: wear an honest object where it stands. Refuses
 * shapes the pact has already been paid for, a spent shape at forming time
 * would only waste the wearer's forty-five seconds.
 */
/obj/item/vestige_second_skin/proc/wear_object(obj/shape, mob/living/user)
	if(istype(shape, /obj/effect))
		return NONE
	if(isitem(shape))
		var/obj/item/item_shape = shape
		if(item_shape.item_flags & (ABSTRACT|HAND_ITEM))
			return NONE
		if(!isturf(item_shape.loc))
			balloon_alert(user, "set it down first!")
			return ITEM_INTERACT_BLOCKING
	var/datum/vestige_trial/perfect_copy/copy_trial = user.mind?.active_vestige_trial
	if(!istype(copy_trial))
		balloon_alert(user, "the skin won't copy objects for you!")
		return ITEM_INTERACT_BLOCKING
	if(form != SKIN_FORM_NONE)
		balloon_alert(user, "already wearing a shape!")
		return ITEM_INTERACT_BLOCKING
	if(shape.type in copy_trial.spent_shapes)
		balloon_alert(user, "that shape is spent!")
		to_chat(user, span_warning("The skin sags off [shape] and won't take. You have already used that shape once. Find a new one."))
		return ITEM_INTERACT_BLOCKING
	user.visible_message(
		span_warning("[user]'s outline runs like wax, pooling into the shape of [shape]!"),
		span_notice("You pull the skin over yourself and become [shape]. Creep close, wait for someone to wander past, then burst out."),
	)
	playsound(user, 'sound/effects/blob/attackblob.ogg', 30, TRUE)
	apply_form(user, shape)
	form = SKIN_FORM_OBJECT
	form_source_type = shape.type
	form_expires = world.time + VESTIGE_SKIN_FORM_TIME
	user.add_movespeed_modifier(/datum/movespeed_modifier/vestige_skin_creep)
	return ITEM_INTERACT_SUCCESS

/**
 * The Understudy's mode: study an adjacent person. Loudly, they are told.
 * Then wear them and go follow. The mind check is the usual anti-farm clause;
 * the skin has no interest in bodies nobody is living in.
 */
/obj/item/vestige_second_skin/proc/study_person(mob/living/target, mob/living/user)
	var/datum/vestige_trial/understudy/tail_trial = user.mind?.active_vestige_trial
	if(!istype(tail_trial))
		balloon_alert(user, "the skin won't copy people for you!")
		return ITEM_INTERACT_BLOCKING
	if(form != SKIN_FORM_NONE)
		balloon_alert(user, "already wearing a shape!")
		return ITEM_INTERACT_BLOCKING
	if(target == user)
		balloon_alert(user, "you know this one already")
		return ITEM_INTERACT_BLOCKING
	if(!ishuman(target))
		balloon_alert(user, "too simple a costume!")
		return ITEM_INTERACT_BLOCKING
	var/mob/living/carbon/human/quarry = target
	if(IS_UNCONSCIOUS_OR_CRIT(quarry))
		balloon_alert(user, "they need to be awake!")
		return ITEM_INTERACT_BLOCKING
	if(!quarry.mind)
		balloon_alert(user, "nobody home to study!")
		return ITEM_INTERACT_BLOCKING
	// The study is loud on purpose: the subject is told, and the room can see the stare
	user.visible_message(
		span_warning("[user] holds [src] up and stares at [quarry], hard."),
		span_notice("You start committing [quarry] to the skin. Five seconds of staring."),
	)
	to_chat(quarry, span_userdanger("You feel eyes crawling over you, taking measurements. Someone is studying you."))
	if(!do_after(user, VESTIGE_STUDY_TIME, target = quarry))
		balloon_alert(user, "the study broke!")
		return ITEM_INTERACT_BLOCKING
	if(!user.is_holding(src))
		return ITEM_INTERACT_BLOCKING
	// Re-resolve; the pact may have been renounced mid-study
	tail_trial = user.mind?.active_vestige_trial
	if(!istype(tail_trial))
		return ITEM_INTERACT_BLOCKING
	if(form != SKIN_FORM_NONE || IS_UNCONSCIOUS_OR_CRIT(quarry))
		return ITEM_INTERACT_BLOCKING
	user.visible_message(
		span_warning("[user]'s outline runs like tallow and sets again as [quarry]'s exact double!"),
		span_notice("You pull [quarry] on. Now follow them. The clock only runs while they are up and moving."),
	)
	playsound(user, 'sound/effects/blob/attackblob.ogg', 30, TRUE)
	apply_form(user, quarry)
	form = SKIN_FORM_PERSON
	saved_real_name = user.real_name
	user.real_name = quarry.real_name
	quarry_ref = WEAKREF(quarry)
	var/turf/spot = get_turf(quarry)
	quarry_last_spot = spot ? "[spot.x]:[spot.y]:[spot.z]" : null
	quarry_last_moved = 0 // the clock starts when THEY start moving
	to_chat(quarry, span_userdanger("Your own face looks back at you, worn by someone else."))
	return ITEM_INTERACT_SUCCESS

/**
 * Stamps the model's appearance over the wearer and arms the form-breakers.
 * The appearance-copy recipe mirrors the morph's own assume_form action
 * (assume_form.dm), snapshot included; callers set the mode-specific state.
 */
/obj/item/vestige_second_skin/proc/apply_form(mob/living/user, atom/movable/model)
	saved_appearance = user.appearance
	user.appearance = model.appearance
	user.copy_overlays(model)
	user.alpha = max(model.alpha, 150) // fucking chameleons
	user.transform = initial(model.transform)
	user.pixel_x = model.base_pixel_x
	user.pixel_y = model.base_pixel_y
	form_appearance = user.appearance
	wearer_ref = WEAKREF(user)
	RegisterSignal(user, COMSIG_MOB_APPLY_DAMAGE, PROC_REF(on_wearer_hurt))
	RegisterSignal(user, COMSIG_MOB_ITEM_ATTACK, PROC_REF(on_wearer_armed_attack))
	RegisterSignal(user, COMSIG_LIVING_UNARMED_ATTACK, PROC_REF(on_wearer_unarmed_attack))
	RegisterSignal(user, COMSIG_ATOM_EXAMINE, PROC_REF(on_wearer_examined))

/**
 * The Perfect Copy's payoff: tear out of the worn shape at whoever stands
 * within a step. Everyone adjacent gets the scream; at most one fresh face,
 * conscious, minded, never startled before, and only from a never-credited
 * shape, pays the pact. The burst always spends the form, hit or miss.
 */
/obj/item/vestige_second_skin/proc/burst(mob/living/user)
	if(form != SKIN_FORM_OBJECT || wearer_ref?.resolve() != user)
		return
	var/shape_name = user.name // the object's name, while we still wear it
	var/shape_type = form_source_type
	var/datum/vestige_trial/perfect_copy/copy_trial = user.mind?.active_vestige_trial
	var/mob/living/carbon/human/credit_victim
	var/startled_anyone = FALSE
	for(var/mob/living/carbon/human/victim in range(1, user))
		if(victim == user || IS_UNCONSCIOUS_OR_CRIT(victim) || !victim.mind)
			continue
		startled_anyone = TRUE
		to_chat(victim, span_userdanger("The [shape_name] beside you tears open and something bursts out at you!"))
		victim.emote("scream")
		victim.set_jitter_if_lower(VESTIGE_STARTLE_JITTER)
		if(istype(copy_trial) && !credit_victim && !copy_trial.startled[WEAKREF(victim)] && !(shape_type in copy_trial.spent_shapes))
			credit_victim = victim
	playsound(user, 'sound/effects/blob/blobattack.ogg', 50, TRUE)
	shed_form(user, feedback = FALSE)
	user.visible_message(
		span_danger("[shape_name] splits down the middle and [user] surges out of it!"),
		span_notice("You burst out of the [shape_name]!"),
	)
	if(!startled_anyone)
		to_chat(user, span_warning("...at an empty room. Nobody saw it."))
		return
	if(!istype(copy_trial) || !credit_victim)
		to_chat(user, span_warning("Plenty of gasps, but no new ones. It only counts with a new shape and someone who hasn't jumped for you before."))
		return
	to_chat(user, span_notice("The jump! The little scream! Somewhere, something applauds."))
	copy_trial.startle(credit_victim, shape_type) // may complete (and delete) the trial, and us with it; nothing after this

/obj/item/vestige_second_skin/process(seconds_per_tick)
	if(form == SKIN_FORM_NONE)
		return
	var/mob/living/wearer = wearer_ref?.resolve()
	if(!wearer || loc != wearer || wearer.stat == DEAD)
		shed_form(wearer)
		return
	if(form == SKIN_FORM_OBJECT)
		// The pact went out from under the shape (renounced mid-form)
		var/datum/vestige_trial/perfect_copy/copy_trial = wearer.mind?.active_vestige_trial
		if(!istype(copy_trial))
			shed_form(wearer)
			return
		if(form_expires && world.time >= form_expires)
			to_chat(wearer, span_warning("The shape goes baggy and sloughs off. The skin can only hold one for so long. Pick another."))
			shed_form(wearer)
			return
		stamp_form(wearer)
		return
	// Person form: the tail. Credit flows only while both parties are conscious,
	// the wearer is close behind, and the quarry has moved recently, a parked
	// quarry pauses the clock without ever refunding it.
	var/datum/vestige_trial/understudy/tail_trial = wearer.mind?.active_vestige_trial
	if(!istype(tail_trial))
		shed_form(wearer)
		return
	stamp_form(wearer)
	var/mob/living/carbon/human/quarry = quarry_ref?.resolve()
	if(!quarry)
		if(SPT_PROB(3, seconds_per_tick))
			to_chat(wearer, span_warning("The face you wear no longer has an owner to follow."))
		return
	var/turf/spot = get_turf(quarry)
	var/spot_key = spot ? "[spot.x]:[spot.y]:[spot.z]" : null
	if(spot_key != quarry_last_spot)
		quarry_last_spot = spot_key
		quarry_last_moved = world.time
	if(IS_UNCONSCIOUS_OR_CRIT(wearer) || IS_UNCONSCIOUS_OR_CRIT(quarry))
		return
	if(wearer.z != quarry.z || get_dist(wearer, quarry) > VESTIGE_SHADOW_RANGE)
		if(SPT_PROB(4, seconds_per_tick))
			to_chat(wearer, span_warning("You have lost them. The clock doesn't run while you can't see who you are copying."))
		return
	if(!quarry_last_moved || world.time - quarry_last_moved > VESTIGE_QUARRY_IDLE_GRACE)
		if(SPT_PROB(4, seconds_per_tick))
			to_chat(wearer, span_notice("They have stopped moving, so the clock has stopped too. Wait for them to get going again."))
		return
	if(SPT_PROB(3, seconds_per_tick))
		to_chat(wearer, span_notice("You fall into step behind them. The skin approves."))
	tail_trial.shadow(seconds_per_tick * (1 SECONDS)) // may complete (and delete) the trial, and us with it; nothing after this

/// Re-applies the disguise snapshot. Humans rebuild their icon on all sorts of
/// triggers (equip changes, regenerate calls), the stamp quietly wins the
/// argument once a tick. Facing is preserved; a chair that whips south every
/// two seconds is a poor chair.
/obj/item/vestige_second_skin/proc/stamp_form(mob/living/wearer)
	if(!form_appearance)
		return
	var/facing = wearer.dir
	wearer.appearance = form_appearance
	wearer.setDir(facing)

/**
 * Takes the shape off, restores the wearer, and clears every scrap of form
 * state. Safe to call with no form up, with a known wearer, or with none,
 * it re-resolves from the weakref and touches only what still exists.
 */
/obj/item/vestige_second_skin/proc/shed_form(mob/living/known_wearer, feedback = TRUE)
	if(form == SKIN_FORM_NONE)
		return
	form = SKIN_FORM_NONE
	var/mob/living/wearer = known_wearer || wearer_ref?.resolve()
	if(wearer && !QDELETED(wearer))
		UnregisterSignal(wearer, list(COMSIG_MOB_APPLY_DAMAGE, COMSIG_MOB_ITEM_ATTACK, COMSIG_LIVING_UNARMED_ATTACK, COMSIG_ATOM_EXAMINE))
		wearer.remove_movespeed_modifier(/datum/movespeed_modifier/vestige_skin_creep)
		if(saved_appearance)
			wearer.appearance = saved_appearance
		if(saved_real_name)
			wearer.real_name = saved_real_name
		wearer.regenerate_icons() // heal any drift the snapshot missed
		if(feedback)
			wearer.visible_message(
				span_warning("The borrowed shape sloughs off [wearer] in ropes of pale flesh."),
				span_notice("The skin lets the shape go."),
			)
	wearer_ref = null
	saved_appearance = null
	saved_real_name = null
	form_appearance = null
	form_source_type = null
	form_expires = 0
	quarry_ref = null
	quarry_last_spot = null
	quarry_last_moved = 0

/// Any real hurt shakes the shape apart. A disguise you can tank in would be a bunker
/obj/item/vestige_second_skin/proc/on_wearer_hurt(mob/living/source, damage, damagetype)
	SIGNAL_HANDLER
	if(damage <= 0)
		return
	to_chat(source, span_warning("The hit jolts through the borrowed shape and it can't hold!"))
	shed_form(source)

/// Swinging a weapon while worn ends the act, violence and the shape cannot share one body
/obj/item/vestige_second_skin/proc/on_wearer_armed_attack(mob/living/source, mob/target_mob, mob/living/user, list/modifiers, list/attack_modifiers)
	SIGNAL_HANDLER
	to_chat(source, span_warning("The shape convulses off you. It doesn't do violence."))
	shed_form(source)

/// Likewise bare-handed violence. Non-combat fumbling (doors, buttons) is
/// permitted; things are allowed to be clumsy, they are not allowed to punch.
/obj/item/vestige_second_skin/proc/on_wearer_unarmed_attack(mob/living/source, atom/attack_target, proximity_flag, list/modifiers)
	SIGNAL_HANDLER
	if(!source.combat_mode)
		return
	to_chat(source, span_warning("The shape convulses off you. It doesn't do violence."))
	shed_form(source)

/// The morph's classic tell, ported to the worn disguise: up close, it is never quite right
/obj/item/vestige_second_skin/proc/on_wearer_examined(mob/living/source, mob/examiner, list/examine_list)
	SIGNAL_HANDLER
	if(get_dist(examiner, source) <= 3)
		examine_list += span_warning("It doesn't look quite right...")

// A worn thing creeps: slow enough to be committal, fast enough to re-ambush.
// The morph's own disguise modifier is a speed-up on an already-slow mob, so
// this is local tuning rather than a reuse.
/datum/movespeed_modifier/vestige_skin_creep
	multiplicative_slowdown = VESTIGE_SKIN_CREEP_SLOWDOWN

#undef VESTIGE_STARTLES_NEEDED
#undef VESTIGE_SKIN_FORM_TIME
#undef VESTIGE_STARTLE_JITTER
#undef VESTIGE_SKIN_CREEP_SLOWDOWN
#undef VESTIGE_MEALS_NEEDED
#undef VESTIGE_MAW_SENSE_RANGE
#undef VESTIGE_MAW_MEMORY_WINDOW
#undef VESTIGE_MAW_GULP_TIME
#undef VESTIGE_SHADOW_SECONDS_NEEDED
#undef VESTIGE_STUDY_TIME
#undef VESTIGE_SHADOW_RANGE
#undef VESTIGE_QUARRY_IDLE_GRACE
#undef SKIN_FORM_NONE
#undef SKIN_FORM_OBJECT
#undef SKIN_FORM_PERSON

/**
 * # The Facsimile: morph boons
 *
 * The Understudy's half of the bargain: what an eager, imitative thing pays
 * with when a trial is kept. The morph's body IS the antag, a pile of flesh
 * that plays prop hunt with the crew, so nothing here grants the morph.
 * Each boon is the human-sized cut of one of its tricks: the disguise
 * (rebuilt on the shapeshift-spell rail. Upstream's assume_form action is
 * explicitly not carbon-safe, see the Borrowed Shape doc comment), the
 * swallowing (rebuilt as a one-slot internal stash rather than the morph's
 * everything-eating maw), the ambush (built on the same charge primitive the
 * Aperture's dash already ports to humans), and the boneless squeeze (the
 * ventcrawl trait itself). Patron and trials live in the theme file; only
 * the boons and their spells are defined here.
 */

// Tuning constants for the Understudy's ports (file-local, #undef at bottom)

/// Health of the borrowed shape (kept equal to human maxHealth so converted damage carries ~1:1)
#define VESTIGE_MIMIC_HEALTH 100
/// Varspeed slowdown of the base borrowed shape, a slow, suspicious creep
#define VESTIGE_MIMIC_CREEP_SPEED 4
/// Varspeed slowdown of the flawless shape, very nearly a walking pace
#define VESTIGE_MIMIC_FLAWLESS_SPEED 1
/// Lockout before a broken Borrowed Shape can be worn again
#define VESTIGE_MIMIC_REFORM_COOLDOWN (15 SECONDS)
/// Lockout before a broken Perfect Facsimile can be worn again
#define VESTIGE_MIMIC_FLAWLESS_REFORM (6 SECONDS)

/// Beats between gullet operations (swallow or regurgitate)
#define VESTIGE_GULLET_COOLDOWN (5 SECONDS)
/// How long one swallow channel takes, spent visibly gulping
#define VESTIGE_GULLET_SWALLOW_TIME (3 SECONDS)
/// How long bringing a keeping back up takes
#define VESTIGE_GULLET_HEAVE_TIME (1 SECONDS)
/// Keepings the base gullet holds
#define VESTIGE_GULLET_SLOTS 1
/// Keepings the bottomless gullet holds
#define VESTIGE_GLUTTONY_SLOTS 3
/// Brute AND burn each that swallowing edible matter mends (bottomless gullet only)
#define VESTIGE_GLUTTONY_FEED_HEAL 10

/// Tiles of the ambush pounce
#define VESTIGE_POUNCE_DISTANCE 3
/// How long a pounced target stays floored
#define VESTIGE_POUNCE_KNOCKDOWN (1.5 SECONDS)
/// Beats per pounce
#define VESTIGE_POUNCE_COOLDOWN (25 SECONDS)
/// Bonus force the pounce lends your next melee strike
#define VESTIGE_AMBUSH_BONUS_FORCE 10
/// How long the lent savagery waits for that strike
#define VESTIGE_AMBUSH_WINDOW (3 SECONDS)

/// Trait source for the Understudy's body-work
#define VESTIGE_MORPH_TRAIT "vestige_morph_boon"

// ===== BOONS =====

// --- Chain: the disguise ---

/datum/vestige_boon/spell/mimic_form
	name = "Borrowed Shape"
	desc = "Point at any ordinary object next to you and I will teach you to BE it, dents and all. You can even creep around in it, slowly. One hit given or taken and the role is over. Up close you do look a bit damp. I am working on the damp."
	grant_text = "Your outline goes soft for a moment, waiting to be told what it is."
	spell_type = /datum/action/cooldown/spell/shapeshift/vestige_mimic

/datum/vestige_boon/spell/mimic_form/flawless
	name = "Perfect Facsimile"
	desc = "My best work. No, YOUR best work, I only coached. The damp is gone, I fixed the damp. You move at very nearly your own pace, anyone can put their nose right up against you and find nothing wrong, and swapping shapes is almost instant now."
	grant_text = "The last tell dries up. You are bone dry and completely convincing."
	upgrades_from = /datum/vestige_boon/spell/mimic_form
	spell_type = /datum/action/cooldown/spell/shapeshift/vestige_mimic/flawless

// --- Chain: the swallow ---

/datum/vestige_boon/spell/devour
	name = "The Gullet"
	desc = "A pocket! Inside! I made you a pocket on the inside. Swallow something and it stays down there, past any pat-down or scanner, until you ask for it back. It comes back in one piece. Slightly damp."
	grant_text = "Something in your throat unhinges, politely, and waits."
	spell_type = /datum/action/cooldown/spell/vestige_devour

/datum/vestige_boon/spell/devour/gluttony
	name = "Bottomless Gullet"
	desc = "Wider! Several things at once now, and bigger ones. I practiced on furniture. And if what you swallow happens to be food, the gullet patches you up a little on the way down."
	grant_text = "Your new pocket yawns. It isn't picky anymore."
	upgrades_from = /datum/vestige_boon/spell/devour
	spell_type = /datum/action/cooldown/spell/vestige_devour/gluttony

// --- Standalone: the ambush ---

/datum/vestige_boon/spell/ambush_instinct
	name = "Ambush Instinct"
	desc = "The oldest trick there is: the thing that was standing still and suddenly isn't. A short pounce that knocks whoever you land on flat, and for a moment afterward your next melee hit lands much harder."
	grant_text = "Your weight settles onto the balls of your feet."
	spell_type = /datum/action/cooldown/mob_cooldown/charge/vestige_pounce

// --- Standalone: the boneless squeeze ---

/datum/vestige_boon/rubber_bones
	name = "Rubber Bones"
	desc = "I loosened everything. Don't ask how. Strip all the way down (the ducting insists) and you can pour yourself through the vents the way I do. Climbing gets quick and short falls stop hurting. This is in the meat, not the soul, so a new body has to be loosened again."
	grant_text = "Every joint in you loosens by a degree no anatomy chart allows."
	radial_icon = 'icons/obj/antags/abductor.dmi'
	radial_icon_state = "vent"

/**
 * Body-work, not a spell: the traits go on the body and stay there. Lost with
 * the body by nature; the vestige record re-runs grant() on respawn restore,
 * which re-loosens whatever the player is wearing by then (add_traits is
 * idempotent per source, so restoring into the same body double-grants
 * nothing).
 *
 * TRAIT_VENTCRAWLER_NUDE over TRAIT_VENTCRAWLER_ALWAYS, deliberately: crawl-
 * with-items on a human (the trait monkeys and rat-organ infusees get is the
 * nude one; ALWAYS is reserved for mobs whose whole body is the antag) would
 * make every vent a zero-counterplay smuggling lane. Nude-only keeps the
 * morph fantasy (the flesh does it bare) and the tradeoff real. Note the
 * intended synergy: the nudity check counts equipped and held items only
 * (get_equipped_items + get_num_held_items, ventcrawling.dm), so a keeping
 * swallowed into the Gullet rides through the ducts with you. That is the
 * combo, and it costs two boons.
 *
 * TRAIT_FREERUNNING is the cheap verified flavor bonus: short falls land
 * unscathed (living.dm z-impact) and climbing is quick (climbable.dm), both
 * exactly what rubber bones ought to do, no new code.
 */
/datum/vestige_boon/rubber_bones/grant(mob/living/user, datum/mind/owner)
	..()
	user.add_traits(list(TRAIT_VENTCRAWLER_NUDE, TRAIT_FREERUNNING), VESTIGE_MORPH_TRAIT)
	to_chat(user, span_notice("Stripped bare, you could pour yourself through a ventilation duct. Fences and short drops suddenly look easy."))

// ===== BORROWED SHAPE =====

/**
 * The morph's disguise, rebuilt for a human on the shapeshift-spell rail
 * rather than ported. Upstream's own primitive
 * (/datum/action/cooldown/mob_cooldown/assume_form) copies the target's
 * appearance onto the OWNER and resets it with initial(icon)/initial(
 * icon_state), its header warns it "will likely shit the bricks" on
 * anything carbon; a human's sprite is overlay-composited and that reset
 * would wreck it. So the appearance copy happens on a disposable basic mob
 * instead (born, imprinted once with the morph's exact field-set, deleted on
 * unshift, the un-resettable reset never has to happen), and the human
 * rides inside via /datum/status_effect/shapechange_mob/from_spell, the same
 * rail every wizard shapeshift trusts.
 *
 * Safety rails, all load-bearing and all checked against source:
 * - Shape death restores the caster (from_spell/on_shape_death; we set
 *   die_with_shapeshifted_form = FALSE), with damage converted back.
 * - Caster death/gib inside mirrors onto the shape (on_caster_death), qdel
 *   of either party restores or cleans up (on_caster_deleted / on_remove).
 * - Wabbajack and mob-type changes are intercepted (on_pre_wabbajack).
 * - Remove() (boon upgrade replacing this spell, mind leaving) unshifts
 *   first (shapeshift/Remove -> unshift_owner). Nobody is stranded as a
 *   crate.
 * - Casting while ventcrawling is refused outright in can_cast_spell:
 *   upstream's rail for shifting-in-a-vent is eject_from_vents, which GIBS.
 *   Refusing the cast is the only version of that rail a player deserves.
 * - The pounce/beckon class of TRAIT_NOTELEPORT concerns doesn't apply:
 *   nothing here teleports; the caster is stored inside the shape mob and
 *   emerges exactly where it stood.
 * - Taking damage or attacking breaks the form (see the mob below); every
 *   exit from the shape pays the reform cooldown via the do_unshapeshift
 *   override, and the fork quirk (Activate() ignores cast()'s return) is
 *   irrelevant because all bail-outs live in before_cast.
 *
 * Known accepted quirk, shared with every upstream shapeshift: unshifting
 * fully heals then re-applies total damage as BRUTE (from_spell/
 * after_unchange), so damage types launder through a form cycle. Wizards
 * have lived with this forever; the reform cooldown makes it a terrible
 * medkit.
 */
/datum/action/cooldown/spell/shapeshift/vestige_mimic
	name = "Borrowed Shape"
	desc = "Click a nearby object to turn into a copy of it. You can creep around slowly, but nothing else. Any hit breaks the disguise, and a broken shape takes time to wear again. Use again to drop it."
	button_icon = 'icons/mob/actions/actions_changeling.dmi'
	button_icon_state = "chameleon_skin"
	background_icon_state = "bg_changeling"
	overlay_icon_state = "bg_changeling_border"
	cooldown_time = VESTIGE_MIMIC_REFORM_COOLDOWN
	invocation_type = INVOCATION_NONE
	spell_requirements = NONE
	// The model is picked by clicking it, the morph's own grammar (assume_form.dm):
	// point at the thing you want to be. What actually changes is always the
	// caster, so the shapeshift rail below is handed the owner, never the click
	click_to_activate = TRUE
	ranged_mousepointer = 'icons/effects/mouse_pointers/supplypod_target.dmi'
	possible_shapes = list(/mob/living/basic/vestige_mimic)
	die_with_shapeshifted_form = FALSE
	/// The object clicked in before_cast, consumed by create_shapeshift_mob. Same-cast handoff only.
	var/atom/movable/chosen_model
	/// Stuff no understudy should play. Mirrors the morph's own blacklist, minus entries view() can't return.
	var/static/list/blacklist_typecache = typecacheof(list(
		/obj/effect,
		/obj/energy_ball,
		/obj/narsie,
		/obj/singularity,
	))

/datum/action/cooldown/spell/shapeshift/vestige_mimic/flawless
	name = "Perfect Facsimile"
	desc = "Click a nearby object to turn into a copy of it, at near walking speed and with no tell when examined. Any hit breaks the disguise. Use again to drop it."
	button_icon_state = "transform"
	cooldown_time = VESTIGE_MIMIC_FLAWLESS_REFORM
	possible_shapes = list(/mob/living/basic/vestige_mimic/flawless)

/datum/action/cooldown/spell/shapeshift/vestige_mimic/Destroy()
	chosen_model = null
	return ..()

// The gib rail, replaced with a refusal: upstream handles "shapeshifted while
// ventcrawling into a non-crawler" by gibbing (eject_from_vents). A Rubber
// Bones crawler who tries to become a wrench mid-duct gets told no instead.
/datum/action/cooldown/spell/shapeshift/vestige_mimic/can_cast_spell(feedback = TRUE)
	. = ..()
	if(!.)
		return FALSE
	if(owner.movement_type & VENTCRAWLING)
		if(feedback)
			to_chat(owner, span_warning("There is no room in here to be anything else."))
		return FALSE
	return TRUE

// Shedding a shape needs no target. Someone caught out as a crate should not
// have to arm a cursor and click themselves to stop being a crate. Only picking
// a NEW shape asks for a click.
/datum/action/cooldown/spell/shapeshift/vestige_mimic/Trigger(mob/clicker, trigger_flags, atom/target)
	if(isnull(target) && wearing_a_shape())
		if(!IsAvailable(feedback = TRUE))
			return FALSE
		return PreActivate(owner)
	return ..()

/// Whether the owner is currently inside a borrowed shape
/datum/action/cooldown/spell/shapeshift/vestige_mimic/proc/wearing_a_shape()
	if(!isliving(owner))
		return FALSE
	var/mob/living/living_owner = owner
	return !!living_owner.has_status_effect(/datum/status_effect/shapechange_mob/from_spell)

// Clicking yourself (or the ability, while wearing a shape) sheds it; clicking
// anything else offers it as a model.
/datum/action/cooldown/spell/shapeshift/vestige_mimic/is_valid_target(atom/cast_on)
	if(cast_on == owner)
		if(!wearing_a_shape())
			owner.balloon_alert(owner, "point at something else!")
			return FALSE
		return TRUE
	if(wearing_a_shape())
		owner.balloon_alert(owner, "already wearing one!")
		return FALSE
	return can_copy(cast_on)

// Forming takes its model from the click and skips the immediate cooldown, so
// the shape can always be shrugged off at will. Unforming falls through
// untouched: Activate's StartCooldown after cast() is exactly the reform
// lockout. Either way the shapeshift rail upstream is handed the OWNER, the
// click target is a model to copy, not a thing to transform.
/datum/action/cooldown/spell/shapeshift/vestige_mimic/before_cast(atom/cast_on)
	var/atom/movable/model = (cast_on == owner) ? null : cast_on
	. = ..(owner)
	if(. & SPELL_CANCEL_CAST)
		return
	chosen_model = null
	if(wearing_a_shape())
		return // unforming: no model to copy, and the cooldown SHOULD start
	// The prop can be picked up or destroyed between the click and here
	if(QDELETED(model) || !can_copy(model))
		return . | SPELL_CANCEL_CAST
	if(QDELETED(src) || QDELETED(owner) || !can_cast_spell(feedback = FALSE))
		return . | SPELL_CANCEL_CAST
	chosen_model = model
	return . | SPELL_NO_IMMEDIATE_COOLDOWN

/// Whether a clicked atom is something an understudy could pass for: a free-standing, visible, ordinary object within arm's reach.
/datum/action/cooldown/spell/shapeshift/vestige_mimic/proc/can_copy(atom/movable/model)
	if(!isobj(model))
		owner.balloon_alert(owner, "can't be that!")
		return FALSE
	if(!isturf(model.loc)) // free-standing props only; nothing out of someone's hand
		owner.balloon_alert(owner, "not while it's held!")
		return FALSE
	if(model.invisibility || is_type_in_typecache(model, blacklist_typecache))
		owner.balloon_alert(owner, "can't be that!")
		return FALSE
	if(isitem(model))
		var/obj/item/item_model = model
		if(item_model.item_flags & ABSTRACT)
			owner.balloon_alert(owner, "can't be that!")
			return FALSE
	if(!(model in view(1, owner)))
		owner.balloon_alert(owner, "too far to study!")
		return FALSE
	return TRUE

// The imprint happens at birth, before the shapechange status effect moves
// the player in, one tick, no visible blob frame in practice
/datum/action/cooldown/spell/shapeshift/vestige_mimic/create_shapeshift_mob(atom/loc)
	var/mob/living/basic/vestige_mimic/shape = ..()
	var/atom/movable/model = chosen_model
	chosen_model = null
	if(istype(shape) && !QDELETED(model))
		shape.imprint(model)
	return shape

// Every exit from the shape: recast, break-on-damage, break-on-attack,
// Remove, funnels through here, so every exit pays the reform lockout.
// (Voluntary recasts also pay it via Activate; same value, harmless restart.)
/datum/action/cooldown/spell/shapeshift/vestige_mimic/do_unshapeshift(mob/living/caster)
	. = ..()
	StartCooldown()

// The transformation theatre: sound, wobble, and a message that names the
// prop rather than the player (the crowd saw who melted; the fun is in what
// stands there after)
/datum/action/cooldown/spell/shapeshift/vestige_mimic/cast(atom/cast_on)
	var/unforming = wearing_a_shape()
	// cast_on is whatever was clicked; the shift itself always happens to the caster
	. = ..(owner)
	if(QDELETED(owner))
		return
	if(unforming)
		playsound(owner, 'sound/effects/splat.ogg', 50, TRUE)
		owner.visible_message(
			span_warning("[owner] shrugs the borrowed shape off like a wet coat!"),
			span_notice("You let the shape go. Your own outline feels roomy by comparison."),
		)
		return
	// Formed: owner is now the shape, already wearing the prop's face.
	// (If the shift somehow failed, the rail stack-traces that itself.
	// There is no shape and no theatre to perform.)
	if(!istype(owner, /mob/living/basic/vestige_mimic))
		return
	playsound(owner, 'sound/effects/magic/mutate.ogg', 50, TRUE)
	owner.visible_message(
		span_warning("With a wet squelch, where they stood there is only... [owner]."),
		span_boldnotice("You pour yourself into the shape. Now hold still."),
	)
	apply_wibbly_filters(owner)
	addtimer(CALLBACK(GLOBAL_PROC, GLOBAL_PROC_REF(remove_wibbly_filters), owner, 0.5 SECONDS), 1 SECONDS)

/**
 * The borrowed shape itself: a disposable basic mob wearing an object's
 * appearance (the morph's exact field-set, appearance, overlays, alpha,
 * transform, base pixel offsets, which also carries name and desc for the
 * examine header). It has no attacks and no hands; it can only creep, be
 * believed, and come apart. It never resets its appearance, every exit
 * deletes it, which is the whole reason the carbon-unsafe reset problem
 * disappears.
 *
 * Health is 1:1 with a human so converted damage carries honestly. Atmos is
 * moot for it (morph pattern: habitable_atmos = null, TCMB floor), a crate
 * does not shiver, and the human inside is in stasis. Med huds are blanked
 * the way the morph blanks them: a health bar over a chair is a hard tell.
 */
/mob/living/basic/vestige_mimic
	name = "borrowed shape"
	desc = "Something doing an impression of a thing. It hasn't quite landed it."
	gender = NEUTER
	icon = 'icons/mob/simple/animal.dmi'
	icon_state = "morph"
	icon_living = "morph"
	speak_emote = list("gurgles")
	maxHealth = VESTIGE_MIMIC_HEALTH
	health = VESTIGE_MIMIC_HEALTH
	speed = VESTIGE_MIMIC_CREEP_SPEED
	melee_damage_lower = 0
	melee_damage_upper = 0
	pass_flags = PASSTABLE
	habitable_atmos = null
	minimum_survivable_temperature = TCMB
	/// The prop being played, for examine delegation (weakref: the prop owes us nothing)
	var/datum/weakref/model_ref
	/// Whether close examination reads the damp tell. The flawless shape dried it out.
	var/has_tell = TRUE
	/// Guards against stacked break timers when several hits land in one tick
	var/breaking = FALSE

/mob/living/basic/vestige_mimic/flawless
	speed = VESTIGE_MIMIC_FLAWLESS_SPEED
	has_tell = FALSE

/mob/living/basic/vestige_mimic/Initialize(mapload)
	. = ..()
	RegisterSignal(src, COMSIG_MOB_APPLY_DAMAGE, PROC_REF(on_damaged))

/// The morph's own appearance-copy field-set, applied once at birth and never reset
/mob/living/basic/vestige_mimic/proc/imprint(atom/movable/model)
	appearance = model.appearance
	copy_overlays(model)
	alpha = max(model.alpha, 150)
	transform = initial(model.transform)
	pixel_x = model.base_pixel_x
	pixel_y = model.base_pixel_y
	real_name = model.name
	model_ref = WEAKREF(model)

// Examine is the prop's own, morph-style, with the near-range tell the
// flawless shape exists to remove. If the prop is gone, the impression
// carries on from memory (base examine of a wet shape, its own tell).
/mob/living/basic/vestige_mimic/examine(mob/user)
	var/atom/movable/model = model_ref?.resolve()
	if(isnull(model))
		. = ..()
	else
		. = model.examine(user)
	if(has_tell && get_dist(user, src) <= 3)
		. += span_warning("It looks slightly damp.")

// A health bar floating over a chair is a hard tell, blank the huds, morph-style
/mob/living/basic/vestige_mimic/med_hud_set_health()
	set_hud_image_state(HEALTH_HUD, null)

/mob/living/basic/vestige_mimic/med_hud_set_status()
	set_hud_image_state(STATUS_HUD, null)

// Attacking breaks the form and the swing never lands: you burst OUT to
// fight (Ambush Instinct is one click away), you do not fight as furniture
/mob/living/basic/vestige_mimic/early_melee_attack(atom/target, list/modifiers, ignore_cooldown = FALSE)
	// Return polarity here is inverted from what it looks like: BASIC_MOB_CONTINUE_ATTACK_CHAIN
	// is 0 and melee_attack() reads ANY truthy value as "stop". Returning FALSE would land the
	// swing, which is the exact opposite of this mob's whole point.
	. = ..()
	if(.) // parent already ended the chain - honour its specific code
		return .
	if(target != src)
		queue_break()
	return BASIC_MOB_END_ATTACK_CHAIN

/// Any damage breaks the form, deferred a tick so the blow finishes resolving first
/mob/living/basic/vestige_mimic/proc/on_damaged(datum/source)
	SIGNAL_HANDLER
	queue_break()

/// Queues the break exactly once, off the current call stack (apply_damage
/// signals fire BEFORE damage lands; unshifting mid-stack would qdel this mob
/// under the damage proc's feet)
/mob/living/basic/vestige_mimic/proc/queue_break()
	if(breaking)
		return
	breaking = TRUE
	addtimer(CALLBACK(src, PROC_REF(break_form)), 1)

/**
 * Comes apart, restoring the rider. Routed through the granting spell's
 * do_unshapeshift so the reform lockout is paid; if the spell is somehow
 * gone, removing the status effect is the rail's own supported teardown
 * (on_remove -> restore_caster), nobody is ever left inside. If damage
 * outright killed the shape first, on_shape_death already restored the
 * caster and deleted us, and this finds nothing to do.
 */
/mob/living/basic/vestige_mimic/proc/break_form()
	breaking = FALSE
	if(QDELETED(src))
		return
	var/datum/status_effect/shapechange_mob/from_spell/shift = has_status_effect(/datum/status_effect/shapechange_mob/from_spell)
	if(!shift)
		return
	visible_message(
		span_boldwarning("[src] shudders, splits along no seam at all, and comes apart!"),
		span_userdanger("The shape gives way under you!"),
	)
	playsound(src, 'sound/effects/splat.ogg', 60, TRUE)
	var/datum/action/cooldown/spell/shapeshift/source_spell = shift.source_weakref?.resolve()
	if(istype(source_spell, /datum/action/cooldown/spell/shapeshift/vestige_mimic))
		source_spell.do_unshapeshift(src)
	else
		remove_status_effect(/datum/status_effect/shapechange_mob/from_spell)

// ===== THE GULLET =====

/**
 * The morph's swallowing, rebuilt as an internal stash. The morph's own
 * version is eatable.forceMove(src) plus /datum/element/content_barfer to
 * spill on death, content_barfer barfs a mob's ENTIRE contents, which on a
 * human means organs, implants and worn equipment, so the port keeps its own
 * container instead: a real /obj holder riding nullspace, owned by the spell
 * (mind-bound, the stash follows the player across bodies with the action,
 * exactly like the flavor says: it is in YOUR gullet, whoever you are today).
 *
 * One action, two verbs, fork-quirk-proof (all bail-outs are before_cast
 * SPELL_CANCEL_CAST, since Activate() ignores cast()'s return): cast with an
 * item in your active hand to channel it down; cast empty-handed to bring a
 * keeping back up (radial pick when the bottomless version holds several).
 *
 * Nothing is ever destroyed silently:
 * - Owner death or gib spills every keeping at the body (COMSIG_LIVING_DEATH,
 *   re-registered on each Grant so it tracks body swaps; on gib the items are
 *   safe in nullspace, not in the corpse, and spill at the turf).
 * - The spell being destroyed (a boon upgrade replacing it) spills at the
 *   owner's feet first. Upgrading The Gullet means briefly, humiliatingly,
 *   coughing up your stash for the wider one.
 */
/datum/action/cooldown/spell/vestige_devour
	name = "The Gullet"
	desc = "Swallow the item in your active hand. Use with an empty hand to bring it back up, intact and slightly damp."
	button_icon = 'icons/mob/actions/actions_animal.dmi'
	button_icon_state = "regurgitate"
	background_icon_state = "bg_changeling"
	overlay_icon_state = "bg_changeling_border"
	cooldown_time = VESTIGE_GULLET_COOLDOWN
	invocation_type = INVOCATION_NONE
	spell_requirements = NONE
	/// Keepings the gullet holds at once
	var/gullet_slots = VESTIGE_GULLET_SLOTS
	/// Largest w_class that goes down
	var/max_swallow_class = WEIGHT_CLASS_NORMAL
	/// Brute AND burn each that swallowing edible matter mends (0 = base gullet doesn't)
	var/organic_heal = 0
	/// The stash itself: a real container living in nullspace for the spell's whole life
	var/obj/vestige_gullet/stash
	/// Item cleared to go down, handed from before_cast to cast. Same-cast handoff only.
	var/obj/item/pending_swallow
	/// Keeping cleared to come up, handed from before_cast to cast. Same-cast handoff only.
	var/obj/item/pending_regurgitate

/datum/action/cooldown/spell/vestige_devour/gluttony
	name = "Bottomless Gullet"
	desc = "Swallow several items, bulky ones included. Use with an empty hand to bring one back up. Swallowed food heals you a little."
	button_icon = 'icons/mob/actions/actions_slime.dmi'
	button_icon_state = "slimeconsume"
	gullet_slots = VESTIGE_GLUTTONY_SLOTS
	max_swallow_class = WEIGHT_CLASS_BULKY
	organic_heal = VESTIGE_GLUTTONY_FEED_HEAL

/datum/action/cooldown/spell/vestige_devour/New(Target)
	. = ..()
	stash = new(null)

/datum/action/cooldown/spell/vestige_devour/Destroy()
	// Spill before the action goes: an upgrade replacing this spell must
	// never eat the keepings with it
	var/turf/spill_loc = owner ? get_turf(owner) : null
	if(spill_loc && length(stash?.contents))
		owner.visible_message(
			span_warning("[owner] doubles over and heaves [owner.p_their()] gullet inside out!"),
			span_notice("The old gullet turns itself inside out to make room for the new one. Pick your things back up."),
		)
		playsound(owner, 'sound/effects/splat.ogg', 50, TRUE)
	empty_gullet(spill_loc)
	QDEL_NULL(stash)
	pending_swallow = null
	pending_regurgitate = null
	return ..()

// The death-spill signal tracks whatever body currently carries the mind:
// registered on each Grant, scrubbed from the old body by each Remove
// (Grant calls Remove(previous_owner) itself, so swaps stay clean)
/datum/action/cooldown/spell/vestige_devour/Grant(mob/grant_to)
	. = ..()
	if(owner)
		RegisterSignal(owner, COMSIG_LIVING_DEATH, PROC_REF(on_owner_death), override = TRUE)

/datum/action/cooldown/spell/vestige_devour/Remove(mob/remove_from)
	if(remove_from)
		UnregisterSignal(remove_from, COMSIG_LIVING_DEATH)
	return ..()

/// Death or gib: the gullet keeps nothing from a corpse, everything spills where the body dropped
/datum/action/cooldown/spell/vestige_devour/proc/on_owner_death(mob/living/source, gibbed)
	SIGNAL_HANDLER
	if(!length(stash?.contents))
		return
	var/turf/spill_loc = get_turf(source)
	if(!spill_loc)
		return
	source.visible_message(
		span_warning("[source]'s throat convulses, and everything in [source.p_their()] gullet comes back up!"),
		blind_message = span_hear("You hear something wet coming back up."),
	)
	playsound(spill_loc, 'sound/effects/splat.ogg', 50, TRUE)
	empty_gullet(spill_loc)

/// Turns the stash out onto the given turf. With no turf there is nowhere left to put anything. Noted loudly, because it should never happen while contents exist.
/datum/action/cooldown/spell/vestige_devour/proc/empty_gullet(turf/spill_loc)
	if(!length(stash?.contents))
		return
	if(!spill_loc)
		stack_trace("vestige gullet emptied with no spill turf; its contents were destroyed with it")
		return
	for(var/obj/item/kept as anything in stash.contents)
		kept.forceMove(spill_loc)

// Both verbs resolve and channel here so an interrupted gulp (or a backed-out
// menu) never spends the cooldown
/datum/action/cooldown/spell/vestige_devour/before_cast(atom/cast_on)
	. = ..()
	if(. & SPELL_CANCEL_CAST)
		return
	pending_swallow = null
	pending_regurgitate = null
	var/obj/item/held = owner.get_active_held_item()
	if(held)
		if(!validate_swallow(held))
			return . | SPELL_CANCEL_CAST
		owner.visible_message(
			span_warning("[owner]'s throat begins to work, horribly, around [held]..."),
			span_notice("You unhinge something no anatomy chart says you have, and start [held] on its way down."),
		)
		playsound(owner, 'sound/items/eatfood.ogg', 40, TRUE)
		if(!do_after(owner, VESTIGE_GULLET_SWALLOW_TIME, target = held))
			return . | SPELL_CANCEL_CAST
		// Re-validate: the meal may have been snatched, dropped or crammed in beside a full load mid-gulp
		if(QDELETED(held) || owner.get_active_held_item() != held || !validate_swallow(held, feedback = FALSE))
			return . | SPELL_CANCEL_CAST
		pending_swallow = held
		return .
	// Empty-handed: bring a keeping back up
	if(!length(stash.contents))
		owner.balloon_alert(owner, "nothing down there!")
		return . | SPELL_CANCEL_CAST
	var/obj/item/choice = pick_from_gullet()
	if(!choice)
		return . | SPELL_CANCEL_CAST
	owner.visible_message(
		span_warning("[owner]'s throat bulges going the wrong way..."),
		span_notice("You call [choice] back up."),
	)
	if(!do_after(owner, VESTIGE_GULLET_HEAVE_TIME))
		return . | SPELL_CANCEL_CAST
	if(QDELETED(choice) || choice.loc != stash)
		return . | SPELL_CANCEL_CAST
	pending_regurgitate = choice
	return .

/// Whether an item can go down right now, balloon feedback included
/datum/action/cooldown/spell/vestige_devour/proc/validate_swallow(obj/item/meal, feedback = TRUE)
	if(HAS_TRAIT(meal, TRAIT_NODROP))
		if(feedback)
			owner.balloon_alert(owner, "it won't leave your hand!")
		return FALSE
	if(meal.item_flags & ABSTRACT)
		return FALSE
	if(meal.w_class > max_swallow_class)
		if(feedback)
			owner.balloon_alert(owner, "too big to go down!")
		return FALSE
	if(length(stash.contents) >= gullet_slots)
		if(feedback)
			owner.balloon_alert(owner, "gullet is full!")
		return FALSE
	return TRUE

/// Picks the keeping to bring up: the only one, or a radial when the bottomless version holds several
/datum/action/cooldown/spell/vestige_devour/proc/pick_from_gullet()
	if(length(stash.contents) == 1)
		return stash.contents[1]
	var/list/options = list()
	var/list/by_key = list()
	for(var/obj/item/kept in stash.contents)
		var/key = kept.name
		var/copy = 2
		while(!isnull(by_key[key]))
			key = "[kept.name] ([copy])"
			copy++
		by_key[key] = kept
		options[key] = image(icon = kept.icon, icon_state = kept.icon_state)
	var/choice = show_radial_menu(owner, owner, options, custom_check = CALLBACK(src, PROC_REF(gullet_menu_check)), tooltips = TRUE)
	if(!choice)
		return null
	return by_key[choice]

/// Menu validity for the regurgitation radial
/datum/action/cooldown/spell/vestige_devour/proc/gullet_menu_check()
	return !QDELETED(src) && !QDELETED(owner) && !IS_UNCONSCIOUS_OR_CRIT(owner)

/datum/action/cooldown/spell/vestige_devour/cast(atom/cast_on)
	. = ..()
	if(pending_swallow)
		var/obj/item/meal = pending_swallow
		pending_swallow = null
		if(!owner.transferItemToLoc(meal, stash)) // a nodrop curse landing mid-gulp still wins
			owner.balloon_alert(owner, "it won't go down!")
			return
		playsound(owner, 'sound/effects/magic/demon_consume.ogg', 30, TRUE)
		owner.visible_message(
			span_warning("[owner] swallows [meal] whole!"),
			span_notice("[meal] settles into the gullet, safe past any pat-down."),
		)
		if(organic_heal && IS_EDIBLE(meal) && isliving(owner))
			var/mob/living/fed = owner
			fed.heal_overall_damage(brute = organic_heal, burn = organic_heal, required_bodytype = BODYTYPE_ORGANIC)
			to_chat(fed, span_boldnotice("The gullet takes its cut of the meal and patches you up a little."))
		return
	if(pending_regurgitate)
		var/obj/item/prize = pending_regurgitate
		pending_regurgitate = null
		if(prize.loc != stash)
			return
		prize.forceMove(get_turf(owner))
		owner.put_in_hands(prize)
		playsound(owner, 'sound/effects/splat.ogg', 40, TRUE)
		owner.visible_message(
			span_warning("[owner] gags once, and produces [prize] from somewhere no pocket should be!"),
			span_notice("[prize] comes back up intact. Slightly damp."),
		)

/// The stash: a real container that spends its whole life in nullspace, held by the spell
/obj/vestige_gullet
	name = "gullet"
	desc = "A pocket of somewhere warm and wet. You should not be able to read this."

// ===== AMBUSH INSTINCT =====

/**
 * The morph's glomp-from-hiding, built on the generic charge action, the
 * same primitive the Aperture's Cosmic Dash already grants to plain humans
 * (in-module precedent; the charge only ever touches owner). The leap is a
 * move-loop, not a teleport: it bumps to a stop on anything dense, so no
 * TRAIT_NOTELEPORT-class rule is ever sidestepped. destroy_objects stays off
 * (nobody's ambush should explode a wall) and the base charge's
 * meteor-impact footfalls are silenced. It is an AMBUSH.
 *
 * Landing on someone floors them briefly; every pounce, hit or miss, leaves
 * a short window of lent savagery (see the status effect below). Bursting
 * out of a Borrowed Shape into a pounce is the intended combo, but a very
 * patient person standing very still gets the same discount.
 */
/datum/action/cooldown/mob_cooldown/charge/vestige_pounce
	name = "Ambush Instinct"
	desc = "Leap a short distance at a target. They're knocked down, and your next melee hit lands much harder."
	button_icon = 'icons/mob/actions/actions_items.dmi'
	button_icon_state = "feral_mode_on"
	background_icon_state = "bg_changeling"
	overlay_icon_state = "bg_changeling_border"
	cooldown_time = VESTIGE_POUNCE_COOLDOWN
	shared_cooldown = NONE
	charge_distance = VESTIGE_POUNCE_DISTANCE
	charge_past = 0
	charge_damage = 0
	destroy_objects = FALSE

/datum/action/cooldown/mob_cooldown/charge/vestige_pounce/Activate(atom/target_atom)
	// The honored combo: pouncing while wearing a Borrowed Shape bursts the
	// shape first, and the pouncer erupts from it mid-leap. break_form
	// restores the player and re-grants this action to them synchronously
	// (mind transfer), so owner is the human again by the time the charge
	// actually launches, and the mimic's reform lockout is paid as normal.
	if(istype(owner, /mob/living/basic/vestige_mimic))
		var/mob/living/basic/vestige_mimic/shape = owner
		shape.break_form()
	. = ..()
	if(!. || !isliving(owner))
		return
	var/mob/living/pouncer = owner
	pouncer.apply_status_effect(/datum/status_effect/vestige_predation)

// A wet uncoiling instead of the base charge's bubblegum theatrics, the thing
// that leaves the floor is meat, not a swinging weapon, and it should sound it
/datum/action/cooldown/mob_cooldown/charge/vestige_pounce/do_charge_indicator(atom/charger, atom/charge_target)
	playsound(charger, 'sound/effects/blob/attackblob.ogg', 60, TRUE)

// The base charge plays a 200-volume meteor impact on every tile moved.
// Ambushes do not.
/datum/action/cooldown/mob_cooldown/charge/vestige_pounce/on_moved(atom/source)
	SIGNAL_HANDLER
	return

// Landing on someone: no trample damage, just the floor, the damage is
// whatever you swing in the savagery window you just earned
/datum/action/cooldown/mob_cooldown/charge/vestige_pounce/hit_target(atom/movable/source, mob/living/target, damage_dealt)
	target.visible_message(
		span_danger("[source] pounces [target] flat!"),
		span_userdanger("[source] bursts across the gap and slams you to the deck!"),
	)
	playsound(target, 'sound/effects/blob/blobattack.ogg', 60, TRUE)
	target.Knockdown(VESTIGE_POUNCE_KNOCKDOWN)
	shake_camera(target, 2, 1)

/**
 * The lent savagery: for a short window after a pounce, the next melee blow
 * carries bonus force. Armed strikes get it the supported way, a
 * COMSIG_MOB_ITEM_ATTACK handler adding MODIFY_ATTACK_FORCE to the attack
 * chain's by-reference attack_modifiers list (melee_attack_chain always
 * passes a real list; blood_drunk's saw is the in-tree precedent for the
 * macro). Punch damage has no modifier hook, so an unarmed harm-mode strike
 * spends the window on a rider hit of its own instead, a claw-rake with its
 * own message, which lands whether or not the punch under it connects
 * (fiction holds: the rake is its own attack). Shoves and help-intent
 * touches don't spend it.
 */
/datum/status_effect/vestige_predation
	id = "vestige_predation"
	duration = VESTIGE_AMBUSH_WINDOW
	status_type = STATUS_EFFECT_REPLACE
	tick_interval = STATUS_EFFECT_NO_TICK
	alert_type = null

/datum/status_effect/vestige_predation/on_apply()
	RegisterSignal(owner, COMSIG_MOB_ITEM_ATTACK, PROC_REF(on_armed_strike))
	RegisterSignal(owner, COMSIG_LIVING_UNARMED_ATTACK, PROC_REF(on_unarmed_strike))
	to_chat(owner, span_boldnotice("For a moment, your whole weight knows exactly where it wants to land."))
	return TRUE

/datum/status_effect/vestige_predation/on_remove()
	UnregisterSignal(owner, list(COMSIG_MOB_ITEM_ATTACK, COMSIG_LIVING_UNARMED_ATTACK))

/// Armed melee: the bonus rides the attack chain's own force modifiers
/datum/status_effect/vestige_predation/proc/on_armed_strike(mob/living/source, mob/living/target, mob/living/user, list/modifiers, list/attack_modifiers)
	SIGNAL_HANDLER
	if(!isliving(target) || target == source)
		return
	MODIFY_ATTACK_FORCE(attack_modifiers, VESTIGE_AMBUSH_BONUS_FORCE)
	to_chat(source, span_boldnotice("You put the whole ambush behind the blow."))
	qdel(src)

/// Unarmed melee: no force hook exists for punches, so the window is spent on a claw-rake rider with its own teeth
/datum/status_effect/vestige_predation/proc/on_unarmed_strike(mob/living/source, atom/target, proximity, list/modifiers)
	SIGNAL_HANDLER
	if(!isliving(target) || target == source || !proximity)
		return
	if(!source.combat_mode || LAZYACCESS(modifiers, RIGHT_CLICK))
		return
	var/mob/living/victim = target
	victim.apply_damage(VESTIGE_AMBUSH_BONUS_FORCE, BRUTE, wound_bonus = CANT_WOUND)
	victim.visible_message(
		span_danger("[source]'s strike arrives with a savage, raking follow-through!"),
		span_userdanger("[source]'s blow rakes through you like a claw!"),
	)
	playsound(victim, 'sound/effects/blob/attackblob.ogg', 40, TRUE)
	qdel(src)

#undef VESTIGE_MIMIC_HEALTH
#undef VESTIGE_MIMIC_CREEP_SPEED
#undef VESTIGE_MIMIC_FLAWLESS_SPEED
#undef VESTIGE_MIMIC_REFORM_COOLDOWN
#undef VESTIGE_MIMIC_FLAWLESS_REFORM
#undef VESTIGE_GULLET_COOLDOWN
#undef VESTIGE_GULLET_SWALLOW_TIME
#undef VESTIGE_GULLET_HEAVE_TIME
#undef VESTIGE_GULLET_SLOTS
#undef VESTIGE_GLUTTONY_SLOTS
#undef VESTIGE_GLUTTONY_FEED_HEAL
#undef VESTIGE_POUNCE_DISTANCE
#undef VESTIGE_POUNCE_KNOCKDOWN
#undef VESTIGE_POUNCE_COOLDOWN
#undef VESTIGE_AMBUSH_BONUS_FORCE
#undef VESTIGE_AMBUSH_WINDOW
#undef VESTIGE_MORPH_TRAIT
