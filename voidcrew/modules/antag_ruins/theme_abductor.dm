/**
 * # The Menagerie — abductor vestige
 *
 * A two-abductor survey vessel gone quiet mid-study. The scientist is still
 * at its bench, keeping the log; the agent is unaccounted for, and so is the
 * occupant of the specimen cell that stands torn open — from the inside.
 * Trials are the survey's field protocols, run on the crew's own terms: a
 * catalogue reading (keep a tagged subject in a lens's focus), a benign graft
 * (gift a stranger a healing gland), and baseline telemetry (probe readings
 * off people still on their feet). Every protocol wants a live, minded
 * subject and releases them no worse than it found them — the Curator is a
 * cataloguer, not a butcher, and the ethics of HOW the subject is kept still
 * are left, pointedly, to the supplicant. The Curator's boons (the baton,
 * the anchor tag, the silence field, the gland graft) are defined with the
 * theme's boon datums; this file carries the patron and its protocols only.
 */

// How long the specimen tag takes to press home (the subject's window to object)
#define VESTIGE_TAG_APPLY_TIME (2.5 SECONDS)
// One unbroken reading, subject in focus throughout. Keep the trial desc's
// "thirty" in sync — initial() values must be compile-time constant, so no
// interpolation there.
#define VESTIGE_READING_DURATION (30 SECONDS)
// How far from the lens the subject may drift mid-reading. Keep the trial
// desc's "three tiles" in sync.
#define VESTIGE_READING_RADIUS 3
// The deployed lens is counterplay: breaking it aborts the reading
#define VESTIGE_LENS_INTEGRITY 80
// How long a bystander takes to wrench a mid-reading lens out of alignment
#define VESTIGE_LENS_DISRUPT_TIME (1 SECONDS)
// How long folding the lens back into its carried form takes
#define VESTIGE_LENS_FOLD_TIME (1.5 SECONDS)
// Bedside steps in the graft protocol. Keep the trial desc's "four" (and the
// step lists on the kit and trial) in sync.
#define VESTIGE_GRAFT_STEPS 4
// How long each graft step's channel runs
#define VESTIGE_GRAFT_STEP_TIME (5 SECONDS)
// Probe readings the Field Study demands. Keep the trial desc's "six" in sync.
#define VESTIGE_PROBE_READINGS_NEEDED 6
// Most readings any single subject can credit. Keep the trial desc's "two" in sync.
#define VESTIGE_PROBE_READINGS_PER_SUBJECT 2
// Stamina sting per credited probe reading — enough to make the reading
// honest, nowhere near enough to fold anyone
#define VESTIGE_PROBE_STING 15
// The probe recalibrates between readings; no machine-gunning a sparring partner
#define VESTIGE_PROBE_RECALIBRATE_TIME (3 SECONDS)

// ===== PATRON =====

/mob/living/basic/vestige_patron/abductor
	name = "the Curator"
	desc = "A grey figure in a laboratory smock, seated at its experiment table with the instruments laid out in perfect parallel. The chair beside it has been empty for a long time. The specimen cell behind it was opened from the inside."
	gender = NEUTER
	outfit_path = /datum/outfit/abductor/scientist
	appearance_tint = "#a9bdb4"
	trial_types = list(
		/datum/vestige_trial/acquisition,
		/datum/vestige_trial/vivisection,
		/datum/vestige_trial/field_study,
	)
	boon_types = list(
		/datum/vestige_boon/item/alien_baton,
		/datum/vestige_boon/item/alien_baton/perfected,
		/datum/vestige_boon/spell/anchor_tag,
		/datum/vestige_boon/spell/anchor_tag/paired,
		/datum/vestige_boon/spell/silence_field,
		/datum/vestige_boon/gland_graft,
	)
	idle_lines = list(
		"Log, supplemental: a subject has approached the bench unprompted. Curiosity remains the most effective bait in the catalogue. We have never needed a second.",
		"Specimen cell three stands open. It was opened from the inside. The occupant's file remains active, pending relocation of the occupant.",
		"My colleague stepped out mid-procedure, some while ago. The incision is still clamped. We do not close another researcher's work. It would be rude.",
		"The subject is reminded that the restraint field is currently decorative. This was not always so. Iteration is the heart of science.",
		"Subject displays initiative. Noted.",
		"Two researchers were assigned to this survey. One remains at the bench. The arithmetic of the remainder is under review.",
		"Do not touch the tray. The instruments are sterile, and they remember being used.",
	)
	accept_line = "Consent recorded. The subject is enrolled. Deviations from protocol will be observed with interest."
	busy_line = "The subject carries another researcher's open file. Parallel studies contaminate one another. Close one."
	fulfilled_line = "That protocol is closed. Re-running a closed study proves nothing but nostalgia."
	renounce_line = "Withdrawal recorded. The subject joins the control group. The control group has never produced anything. That is what it is for."
	claim_line = "Compensation is outstanding on the subject's file. Collect it. An unbalanced ledger invites review."
	exhausted_line = "Inventory is exhausted. The subject has been — the log searches for the clinical term — thorough."
	remember_line = "Subject expired; subject resumed. Noted without comment. The file was never closed. We do not close files over technicalities."

// ===== PROTOCOL: ACQUISITION =====

/datum/vestige_trial/acquisition
	name = "Protocol: Acquisition"
	// Keep the numbers in sync with VESTIGE_READING_DURATION / VESTIGE_READING_RADIUS
	// (initial values must be constant, so no define interpolation here)
	desc = "Take the tag and the lens. Select a live, conscious humanoid — the protocol requires someone behind the eyes — and affix the tag. Deploy the lens, begin the reading, and hold the subject within three tiles of it for thirty unbroken seconds, alive and out of collapse. How is the subject's own variable: barricades, bargains, a firm grip, or plain consent all produce identical data. A finished reading releases the subject intact. This is a catalogue, not a larder."
	/// The currently tagged subject (weakref; retagging moves the tag and restarts any reading)
	var/datum/weakref/tagged_ref
	/// Deciseconds of the current reading, zeroed whenever it aborts
	var/reading_progress = 0
	/// Whether a lens is mid-reading right now (set by the lens, read by progress text)
	var/reading_underway = FALSE

/datum/vestige_trial/acquisition/on_accepted(mob/living/user)
	hand_over(user, new /obj/item/vestige_specimen_tag(get_turf(user)))
	hand_over(user, new /obj/item/vestige_observation_lens(get_turf(user)))
	to_chat(user, span_notice("The applicator and the folded lens settle into your hands, humming at two slightly different pitches. Neither of them is idle."))

/datum/vestige_trial/acquisition/get_progress_text()
	var/mob/living/subject = tagged_ref?.resolve()
	if(!subject)
		return "No subject is tagged. Press the applicator to a live, conscious humanoid."
	if(reading_underway)
		return "The reading of [subject] stands at [round(reading_progress / 10)] of [VESTIGE_READING_DURATION / 10] seconds. Keep [subject.p_them()] within [VESTIGE_READING_RADIUS] tiles of the lens, alive and out of collapse."
	return "[subject] is tagged. Deploy the lens, begin the reading, and keep [subject.p_them()] in focus — however you can."

/// Tags a new subject. Restarts any reading in progress — a new specimen is a new file.
/datum/vestige_trial/acquisition/proc/tag_subject(mob/living/subject)
	tagged_ref = WEAKREF(subject)
	reading_progress = 0
	refresh_tracker()

/**
 * Accrues reading time from the lens. On a finished reading the subject is
 * released — politely, intact — and the trial completes (and deletes itself).
 * Returns TRUE when it did; the caller must not touch the trial after that.
 */
/datum/vestige_trial/acquisition/proc/advance_reading(deciseconds)
	reading_progress += deciseconds
	refresh_tracker()
	if(reading_progress < VESTIGE_READING_DURATION)
		return FALSE
	var/mob/living/subject = tagged_ref?.resolve()
	if(istype(subject))
		to_chat(subject, span_boldnotice("A polite chime, from everywhere at once: \"Specimen catalogued. Release authorized.\" The point of light under your skin winks out, leaving nothing behind."))
		playsound(subject, 'sound/machines/chime.ogg', 40, TRUE)
	tagged_ref = null
	complete()
	return TRUE

/// Zeroes the current reading. The attempt fails; the tag — and the trial — hold.
/datum/vestige_trial/acquisition/proc/abort_reading()
	reading_underway = FALSE
	var/lost = reading_progress
	reading_progress = 0
	refresh_tracker()
	if(lost < 50) // sub-five-second fumbles are beneath the log's notice
		return
	var/mob/living/user = owner?.current
	if(isliving(user))
		to_chat(user, span_warning("The reading collapses — [round(lost / 10)] seconds of telemetry, discarded. The tag holds. Begin again."))

/obj/item/vestige_specimen_tag
	name = "specimen tag applicator"
	desc = "A silver abductor instrument ending in a ring of fine, polite needles. It affixes nothing you could find again with a scalpel — just a point of violet light, filed under the skin, that something else can read from across a room."
	icon = 'icons/obj/antags/abductor.dmi'
	icon_state = "gizmo_mark"
	inhand_icon_state = "silencer"
	lefthand_file = 'icons/mob/inhands/antag/abductor_lefthand.dmi'
	righthand_file = 'icons/mob/inhands/antag/abductor_righthand.dmi'
	w_class = WEIGHT_CLASS_SMALL

/obj/item/vestige_specimen_tag/examine(mob/user)
	. = ..()
	var/datum/vestige_trial/acquisition/trial = user.mind?.active_vestige_trial
	if(!istype(trial))
		return
	var/mob/living/subject = trial.tagged_ref?.resolve()
	if(subject)
		. += span_notice("Its display reads, in tidy alien script: SUBJECT — [subject].")

/obj/item/vestige_specimen_tag/attack(mob/living/target, mob/living/user, list/modifiers, list/attack_modifiers)
	if(!ishuman(target) || target == user)
		return ..()
	var/datum/vestige_trial/acquisition/trial = user.mind?.active_vestige_trial
	if(!istype(trial))
		balloon_alert(user, "the applicator is dark!")
		return
	var/mob/living/carbon/human/subject = target
	// The protocol wants a person: awake, and someone home behind the eyes
	// (mind check — mindless monkeys and empty bodies produce no data)
	if(subject.stat != CONSCIOUS || !subject.mind)
		balloon_alert(user, "the protocol wants a conscious subject!")
		return
	if(trial.tagged_ref?.resolve() == subject)
		balloon_alert(user, "already tagged!")
		return
	// A short channel, in the open. The tag is not a secret; it is a selection —
	// the subject gets their whole window to object, flee, or shake hands.
	subject.visible_message(
		span_warning("[user] presses a small silver instrument against [subject]'s shoulder!"),
		span_userdanger("[user] presses something cold and precise against your shoulder!"),
	)
	if(!do_after(user, VESTIGE_TAG_APPLY_TIME, target = subject))
		return
	if(!user.is_holding(src))
		return
	// Re-resolve; the pact may have been renounced mid-press
	trial = user.mind?.active_vestige_trial
	if(!istype(trial))
		return
	if(subject.stat != CONSCIOUS)
		balloon_alert(user, "the moment passed!")
		return
	trial.tag_subject(subject)
	playsound(subject, 'sound/machines/ping.ogg', 30, TRUE)
	balloon_alert(user, "subject tagged")
	to_chat(user, span_notice("The applicator clicks once, satisfied. [subject] is on file. Now keep [subject.p_them()] where the lens can look."))
	to_chat(subject, span_warning("Something clicks shut against your shoulder, and a point of violet light settles under your skin. It doesn't hurt. It is very interested in you."))

/obj/item/vestige_observation_lens
	name = "folded observation lens"
	desc = "An abductor field instrument folded down into its carrying shape. It is warm on one side, like something sleeping with one eye open."
	icon = 'icons/obj/antags/abductor.dmi'
	icon_state = "beacon"
	w_class = WEIGHT_CLASS_SMALL

/obj/item/vestige_observation_lens/examine(mob/user)
	. = ..()
	. += span_notice("Use it in hand to unfold it on open flooring. It reads tagged specimens, and only tagged specimens.")

/obj/item/vestige_observation_lens/attack_self(mob/user)
	var/datum/vestige_trial/acquisition/trial = user.mind?.active_vestige_trial
	if(!istype(trial))
		balloon_alert(user, "the lens is dark!")
		return
	var/turf/here = get_turf(user)
	if(!isfloorturf(here))
		balloon_alert(user, "needs solid footing!")
		return
	for(var/obj/thing in here)
		if(thing.density || ismachinery(thing) || isstructure(thing))
			balloon_alert(user, "no room to unfold!")
			return
	var/obj/structure/vestige_observation_lens/lens = new(here)
	lens.keeper = user.mind
	playsound(here, 'sound/effects/phasein.ogg', 40, TRUE)
	user.visible_message(
		span_warning("[user] sets something small on the deck, and it unfolds — and unfolds, and unfolds — into an alien lens assembly."),
		span_notice("You set the lens down and it unfolds itself to working height, swiveling once around the room before settling into a patient rest position."),
	)
	qdel(src)

/**
 * The unfolded lens. Holds the keeper's MIND, never the trial (the wake-candle
 * exception) — the reading resolves the keeper's active pact every tick, so a
 * renounced pact powers it down and a completed one folds it away. Breaking it
 * or wrenching it off-target costs the attempt, never the trial: the folded
 * core always survives to be redeployed.
 */
/obj/structure/vestige_observation_lens
	name = "observation lens"
	desc = "An alien lens assembly unfolded to tripod height. Whatever it is looking at, it is looking at it very hard, and it has been doing so since before you noticed it."
	icon = 'icons/obj/antags/abductor.dmi'
	icon_state = "camera"
	anchored = TRUE
	density = FALSE
	max_integrity = VESTIGE_LENS_INTEGRITY
	/// Mind of the deploying supplicant (the wake-candle keeper exception; never a trial ref)
	var/datum/mind/keeper
	/// Whether a reading is underway
	var/scanning = FALSE

/obj/structure/vestige_observation_lens/Destroy()
	stop_reading(silent = TRUE)
	STOP_PROCESSING(SSobj, src)
	keeper = null
	return ..()

/obj/structure/vestige_observation_lens/examine(mob/user)
	. = ..()
	. += span_notice("A tap starts a reading — or disrupts one already running. Alt-click folds it back into its carried form.")
	if(scanning)
		. += span_warning("It is mid-reading, tracking something with total attention.")

/// Resolves the keeper's live acquisition pact, or null if it has ended
/obj/structure/vestige_observation_lens/proc/get_trial()
	var/datum/vestige_trial/acquisition/trial = keeper?.active_vestige_trial
	return istype(trial) ? trial : null

/// TRUE while the subject can be read: alive, out of collapse, and within the lens's reach
/obj/structure/vestige_observation_lens/proc/focus_holds(mob/living/subject)
	if(QDELETED(subject) || subject.stat == DEAD || HAS_TRAIT(subject, TRAIT_CRITICAL_CONDITION))
		return FALSE
	var/turf/here = get_turf(src)
	var/turf/there = get_turf(subject)
	if(!here || !there || here.z != there.z || get_dist(here, there) > VESTIGE_READING_RADIUS)
		return FALSE
	return TRUE

/obj/structure/vestige_observation_lens/attack_hand(mob/living/user, list/modifiers)
	if(user.combat_mode)
		return ..()
	if(scanning)
		// Disruption sleeps for bystanders; don't hold up the click chain
		INVOKE_ASYNC(src, PROC_REF(try_disrupt), user)
		return TRUE
	if(user.mind && user.mind == keeper)
		begin_reading(user)
		return TRUE
	to_chat(user, span_notice("The lens ignores you with what feels like professional courtesy."))
	return TRUE

/// Starts a reading on the keeper's tagged subject, with a word about anything missing
/obj/structure/vestige_observation_lens/proc/begin_reading(mob/living/user)
	var/datum/vestige_trial/acquisition/trial = get_trial()
	if(!trial)
		balloon_alert(user, "the lens is dark!")
		return
	var/mob/living/subject = trial.tagged_ref?.resolve()
	if(!istype(subject))
		balloon_alert(user, "no tagged subject!")
		return
	if(subject.stat == DEAD || HAS_TRAIT(subject, TRAIT_CRITICAL_CONDITION))
		balloon_alert(user, "the subject must be alive and stable!")
		return
	if(!focus_holds(subject))
		balloon_alert(user, "subject out of focus!")
		return
	scanning = TRUE
	trial.reading_underway = TRUE
	trial.refresh_tracker()
	set_light(2, 0.8, "#b46fd6", l_on = TRUE)
	START_PROCESSING(SSobj, src)
	playsound(src, 'sound/machines/terminal/terminal_processing.ogg', 40, TRUE)
	visible_message(
		span_warning("[src] swivels, finds its mark, and floods with violet light!"),
		)
	to_chat(subject, span_userdanger("The lens turns, finds you, and settles. You are being read. Something would prefer you stayed put for it."))

/// A bystander (or the keeper) breaking off a reading in progress. Sleeps; call async.
/obj/structure/vestige_observation_lens/proc/try_disrupt(mob/living/user)
	// The keeper calls off their own reading instantly
	if(user.mind && user.mind == keeper)
		stop_reading()
		visible_message(span_notice("[src] powers down mid-reading and swings back to its rest position."))
		return
	// Anyone else needs a moment hands-on — the keeper's window to stop them
	balloon_alert(user, "wrenching the lens aside...")
	if(!do_after(user, VESTIGE_LENS_DISRUPT_TIME, target = src))
		return
	if(QDELETED(src) || !scanning)
		return
	stop_reading()
	user.visible_message(
		span_warning("[user] wrenches [src] out of alignment!"),
		span_notice("You wrench the lens out of alignment. The violet light dies."),
	)

/// Ends a reading in progress, zeroing the trial's count. Safe to call when idle.
/obj/structure/vestige_observation_lens/proc/stop_reading(silent = FALSE)
	if(!scanning)
		return
	scanning = FALSE
	STOP_PROCESSING(SSobj, src)
	set_light(l_on = FALSE)
	var/datum/vestige_trial/acquisition/trial = get_trial()
	trial?.abort_reading()
	if(!silent)
		playsound(src, 'sound/machines/buzz/buzz-sigh.ogg', 30, TRUE)

/// Collapses the lens back into its carried form on the spot
/obj/structure/vestige_observation_lens/proc/fold_up()
	new /obj/item/vestige_observation_lens(drop_location())
	playsound(src, 'sound/effects/phasein.ogg', 30, TRUE)
	qdel(src)

/obj/structure/vestige_observation_lens/click_alt(mob/user)
	if(!isliving(user))
		return CLICK_ACTION_BLOCKING
	// Folding sleeps; don't hold up the click chain
	INVOKE_ASYNC(src, PROC_REF(try_fold), user)
	return CLICK_ACTION_SUCCESS

/// Folds the lens back down — the keeper packing up, or anyone else confiscating it
/obj/structure/vestige_observation_lens/proc/try_fold(mob/living/user)
	balloon_alert(user, "folding the lens...")
	if(!do_after(user, VESTIGE_LENS_FOLD_TIME, target = src))
		return
	if(QDELETED(src))
		return
	stop_reading()
	user.visible_message(
		span_warning("[user] folds [src] back down into its carrying shape."),
		span_notice("You fold the lens back down. It goes reluctantly."),
	)
	fold_up()

// Breaking the housing costs the attempt, never the trial: the folded core
// survives the wreck to be redeployed
/obj/structure/vestige_observation_lens/handle_deconstruct(disassembled)
	if(!disassembled)
		visible_message(span_warning("[src] collapses in a spray of sparks, folding defensively back into its core!"))
	new /obj/item/vestige_observation_lens(drop_location())

/obj/structure/vestige_observation_lens/process(seconds_per_tick)
	var/datum/vestige_trial/acquisition/trial = get_trial()
	if(!trial) // the pact ended out from under the reading; pack up quietly
		stop_reading(silent = TRUE)
		fold_up()
		return
	var/mob/living/subject = trial.tagged_ref?.resolve()
	if(!istype(subject) || !focus_holds(subject))
		visible_message(span_warning("[src] chirps sourly and swings back to its rest position — the reading has lost its subject."))
		stop_reading()
		return
	// The tether advertises the reading to the whole room; keeping the subject
	// inside it — by rhetoric, barricade, or bear hug — is the supplicant's job
	if(SPT_PROB(60, seconds_per_tick))
		Beam(subject, icon_state = "purple_lightning", time = 1 SECONDS)
	if(SPT_PROB(8, seconds_per_tick))
		to_chat(subject, span_warning("The lens's regard rests on you like a hand on the back of your neck."))
	if(trial.advance_reading(seconds_per_tick * (1 SECONDS))) // may complete the pact, deleting the trial — touch it no further
		scanning = FALSE
		STOP_PROCESSING(SSobj, src)
		set_light(l_on = FALSE)
		playsound(src, 'sound/machines/chime.ogg', 50, TRUE)
		visible_message(span_boldnotice("[src] chimes once, politely, and begins folding itself flat. The catalogue is satisfied."))
		fold_up()

// ===== PROTOCOL: GRAFT =====

/datum/vestige_trial/vivisection
	name = "Protocol: Graft"
	// Keep the count in sync with VESTIGE_GRAFT_STEPS (initial values must be
	// constant, so no define interpolation here)
	desc = "Take the kit. Select a live humanoid subject — conscious, or sedated by arrangement — and lay them on a table or bed. The graft proceeds in four bedside steps: incise, calibrate, implant, seal. An interrupted step costs only that step. The implant is a replicator gland, and it is a gift: it will spend the rest of the subject's life quietly repairing the subject. We have taken so very much, over the years. The study of giving back is new, and the early data is promising."
	/// The subject mid-procedure (weakref; switching subjects restarts the graft)
	var/datum/weakref/patient_ref
	/// Steps completed on the current subject, of VESTIGE_GRAFT_STEPS
	var/steps_done = 0
	/// Step names, in procedure order (shared with the kit's flavor lists — keep aligned)
	var/static/list/step_names = list("incision", "calibration", "implantation", "seal")

/datum/vestige_trial/vivisection/on_accepted(mob/living/user)
	hand_over(user, new /obj/item/vestige_graft_kit(get_turf(user)))
	to_chat(user, span_notice("The kit is heavier than it looks. Something inside it is keeping itself warm."))

/datum/vestige_trial/vivisection/get_progress_text()
	var/mob/living/patient = patient_ref?.resolve()
	if(!patient || !steps_done)
		return "No graft is underway. Lay a live subject on a table or bed and begin: incise, calibrate, implant, seal."
	return "The graft on [patient] stands at [steps_done] of [VESTIGE_GRAFT_STEPS] steps. Next: [step_names[steps_done + 1]]."

/**
 * Credits one completed graft step on the given subject; a different subject
 * restarts the protocol from the top. May complete (and delete) the trial —
 * callers must not touch it after this.
 */
/datum/vestige_trial/vivisection/proc/advance_step(mob/living/patient)
	if(patient_ref?.resolve() != patient)
		patient_ref = WEAKREF(patient)
		steps_done = 0
	steps_done++
	refresh_tracker()
	if(steps_done >= VESTIGE_GRAFT_STEPS)
		complete()

/obj/item/vestige_graft_kit
	name = "xenograft kit"
	desc = "A hinged alien case with its instruments socketed in living velvet. Inside: one replicator gland, packed in something that is breathing slowly. There is no anesthetic. The kit's notes describe anesthetic as optional."
	icon = 'icons/obj/antags/abductor.dmi'
	icon_state = "belt"
	w_class = WEIGHT_CLASS_NORMAL
	/// Channel sounds, one per step — order matches /datum/vestige_trial/vivisection/step_names
	var/static/list/step_sounds = list(
		'sound/items/handling/surgery/scalpel1.ogg',
		'sound/machines/terminal/terminal_processing.ogg',
		'sound/items/handling/surgery/organ2.ogg',
		'sound/items/handling/surgery/cautery1.ogg',
	)
	/// What the room sees as each step begins — order matches step_names
	var/static/list/step_start_messages = list(
		"draws a glowing line down %PATIENT%'s sternum with an instrument from the kit",
		"holds a chattering instrument over the incision, letting it argue with %PATIENT%'s biology",
		"lifts a fist-sized gland from the kit and seats it, unhurried, in %PATIENT%'s chest",
		"draws a sealing wand along the incision, which closes without comment",
	)
	/// What the subject feels as each step begins — order matches step_names
	var/static/list/step_feel_messages = list(
		"A line of painless cold draws itself down your chest. It does not bleed. It waits.",
		"Something reads you, organ by organ, and takes notes.",
		"Something warm and patient settles in behind your ribs and introduces itself to your blood.",
		"The cold line on your chest zips itself shut. You are, as far as you can tell, exactly as you were. Almost.",
	)

/obj/item/vestige_graft_kit/examine(mob/user)
	. = ..()
	. += span_notice("Used on a live humanoid lying on a table or bed, it performs the graft in [VESTIGE_GRAFT_STEPS] bedside steps: incise, calibrate, implant, seal. The recipient keeps the gland. The gland keeps the recipient.")

/obj/item/vestige_graft_kit/interact_with_atom(atom/interacting_with, mob/living/user, list/modifiers)
	if(!ishuman(interacting_with))
		return NONE
	var/mob/living/carbon/human/patient = interacting_with
	var/datum/vestige_trial/vivisection/trial = user.mind?.active_vestige_trial
	if(!istype(trial))
		balloon_alert(user, "the kit refuses to open!")
		return ITEM_INTERACT_BLOCKING
	if(patient == user)
		balloon_alert(user, "the protocol requires a second pair of hands!")
		return ITEM_INTERACT_BLOCKING
	if(!check_patient(patient, user))
		return ITEM_INTERACT_BLOCKING
	// A new subject starts from the incision, whatever an old file says
	var/step = (trial.patient_ref?.resolve() == patient) ? trial.steps_done + 1 : 1
	var/step_name = trial.step_names[step]
	playsound(patient, step_sounds[step], 40, TRUE)
	patient.visible_message(
		span_warning("[user] [replacetext(step_start_messages[step], "%PATIENT%", "[patient]")]."),
		span_userdanger(step_feel_messages[step]),
	)
	if(!do_after(user, VESTIGE_GRAFT_STEP_TIME, target = patient))
		balloon_alert(user, "the [step_name] was interrupted!")
		return ITEM_INTERACT_BLOCKING
	if(!user.is_holding(src))
		return ITEM_INTERACT_BLOCKING
	// Re-resolve; the pact may have been renounced mid-step
	trial = user.mind?.active_vestige_trial
	if(!istype(trial))
		return ITEM_INTERACT_BLOCKING
	if(!check_patient(patient, user))
		balloon_alert(user, "the [step_name] was lost!")
		return ITEM_INTERACT_BLOCKING
	if(step < VESTIGE_GRAFT_STEPS)
		trial.advance_step(patient)
		balloon_alert(user, "[step_name] complete")
		return ITEM_INTERACT_SUCCESS
	// The seal: the gland goes in for real, and the protocol closes
	if(!implant_gland(patient, user))
		return ITEM_INTERACT_BLOCKING
	trial.advance_step(patient) // completes (and deletes) the trial — nothing touches it after this
	return ITEM_INTERACT_SUCCESS

/// The graft's standing terms, checked before and after every step, with a word about whatever is missing
/obj/item/vestige_graft_kit/proc/check_patient(mob/living/carbon/human/patient, mob/living/user)
	if(patient.stat == DEAD)
		balloon_alert(user, "the protocol wants a living subject!")
		return FALSE
	if(HAS_TRAIT(patient, TRAIT_CRITICAL_CONDITION))
		balloon_alert(user, "stabilize the subject first!")
		return FALSE
	// Someone must be home to receive the gift (mind check — no monkey wards)
	if(!patient.mind)
		balloon_alert(user, "nobody home to graft for!")
		return FALSE
	if(patient.body_position != LYING_DOWN)
		balloon_alert(user, "lay the subject down!")
		return FALSE
	var/turf/patient_turf = get_turf(patient)
	if(!(locate(/obj/structure/table) in patient_turf) && !(locate(/obj/structure/bed) in patient_turf))
		balloon_alert(user, "the subject needs a table or bed!")
		return FALSE
	if(locate(/obj/item/organ/heart/gland) in patient.organs)
		balloon_alert(user, "already grafted!")
		return FALSE
	return TRUE

/**
 * Seats the replicator gland — the upstream abductor heal gland, which rides
 * the heart slot and self-starts on insert (uses = -1, on_mob_insert). The
 * subject's own heart comes back out of the graft intact and is handed to the
 * surgeon, neatly sleeved: no lasting harm means nothing of theirs is lost,
 * only upgraded. The compliance hardware ships decommissioned — this is a
 * gift, not a leash.
 */
/obj/item/vestige_graft_kit/proc/implant_gland(mob/living/carbon/human/patient, mob/living/user)
	var/obj/item/organ/old_heart = patient.get_organ_slot(ORGAN_SLOT_HEART)
	var/obj/item/organ/heart/gland/heal/gland = new()
	gland.mind_control_uses = 0
	if(!gland.Insert(patient))
		qdel(gland)
		balloon_alert(user, "the graft will not take!")
		return FALSE
	// Insert leaves the replaced heart at the subject's feet; hand it back sleeved
	if(old_heart && !QDELETED(old_heart))
		user.put_in_hands(old_heart)
		to_chat(user, span_notice("The kit sleeves [patient]'s original [old_heart.name] in preservative film and returns it to you. Its owner may want it back someday. The kit's notes doubt it."))
	playsound(patient, 'sound/machines/chime.ogg', 40, TRUE)
	patient.visible_message(
		span_notice("[patient]'s color improves at once, as if [patient.p_their()] body has just come under new management."),
		span_boldnotice("Something in your chest settles into a rhythm not quite yours, and begins — very quietly — to look after you."),
	)
	patient.add_mood_event("vestige_grafted", /datum/mood_event/vestige_grafted)
	return TRUE

/datum/mood_event/vestige_grafted
	description = "Something patient and foreign is keeping my body in working order."
	mood_change = 4
	timeout = 10 MINUTES

// ===== PROTOCOL: FIELD STUDY =====

/datum/vestige_trial/field_study
	name = "Protocol: Field Study"
	// Keep the counts in sync with VESTIGE_PROBE_READINGS_NEEDED /
	// VESTIGE_PROBE_READINGS_PER_SUBJECT (initial values must be constant, so
	// no define interpolation here)
	desc = "Take the probe. The catalogue requires baseline telemetry from humanoids under load — conscious, upright, unrestrained. Six readings, and no more than two from any one subject; a sample of one is an anecdote. The probe announces itself on contact. This is by design: a subject who knows it is being measured pushes back, and the pushing back is the data."
	/// Readings credited so far
	var/readings_taken = 0
	/// Readings credited per subject (weakref -> count), capping farm-a-friend
	var/list/readings_per_subject = list()

/datum/vestige_trial/field_study/on_accepted(mob/living/user)
	hand_over(user, new /obj/item/vestige_probe_baton(get_turf(user)))
	to_chat(user, span_notice("The probe clicks once, runs a self-test, and pronounces itself satisfied with you. Probably it does this to everyone."))

/datum/vestige_trial/field_study/get_progress_text()
	return "[readings_taken] of [VESTIGE_PROBE_READINGS_NEEDED] readings are on file."

/// Credits a probe reading. May complete (and delete) the trial. Returns FALSE if this subject's file is full.
/datum/vestige_trial/field_study/proc/record_reading(mob/living/subject)
	var/datum/weakref/key = WEAKREF(subject)
	var/prior = readings_per_subject[key] || 0
	if(prior >= VESTIGE_PROBE_READINGS_PER_SUBJECT)
		return FALSE
	readings_per_subject[key] = prior + 1
	readings_taken++
	refresh_tracker()
	if(readings_taken >= VESTIGE_PROBE_READINGS_NEEDED)
		complete()
	return TRUE

/obj/item/vestige_probe_baton
	name = "telemetric probe"
	desc = "An abductor probe-wand tuned all the way down: it cannot stun, it cannot cuff, and it has never once apologized. The tip drinks a reading on contact and stings just enough to make the reading honest."
	icon = 'icons/obj/antags/abductor.dmi'
	icon_state = "wonderprodProbe"
	inhand_icon_state = "wonderprodProbe"
	lefthand_file = 'icons/mob/inhands/antag/abductor_lefthand.dmi'
	righthand_file = 'icons/mob/inhands/antag/abductor_righthand.dmi'
	w_class = WEIGHT_CLASS_SMALL
	force = 0
	COOLDOWN_DECLARE(recalibration)

/obj/item/vestige_probe_baton/attack(mob/living/target, mob/living/user, list/modifiers, list/attack_modifiers)
	if(!ishuman(target) || target == user)
		return ..()
	var/datum/vestige_trial/field_study/trial = user.mind?.active_vestige_trial
	if(!istype(trial))
		balloon_alert(user, "the probe is dark!")
		return
	if(!COOLDOWN_FINISHED(src, recalibration))
		balloon_alert(user, "still recalibrating!")
		return
	var/mob/living/carbon/human/subject = target
	// Telemetry under load only: awake, on their feet, hands free, someone home
	// (mind check — cuffed captives, sleepers and monkey farms measure nothing)
	if(subject.stat != CONSCIOUS || subject.body_position != STANDING_UP)
		balloon_alert(user, "the protocol wants them upright!")
		return
	if(HAS_TRAIT(subject, TRAIT_RESTRAINED))
		balloon_alert(user, "restrained subjects measure nothing!")
		return
	if(!subject.mind)
		balloon_alert(user, "nobody home to measure!")
		return
	if(!trial.record_reading(subject)) // may complete (and delete) the trial — resolve it no further
		balloon_alert(user, "this subject's file is complete!")
		return
	COOLDOWN_START(src, recalibration, VESTIGE_PROBE_RECALIBRATE_TIME)
	subject.apply_damage(VESTIGE_PROBE_STING, STAMINA)
	playsound(subject, 'sound/items/pshoom/pshoom.ogg', 40, TRUE)
	subject.visible_message(
		span_danger("[user] presses a humming probe against [subject]!"),
		span_userdanger("You feel a cold instrument take a reading!"),
	)
	to_chat(user, span_notice("The probe drinks its reading and files it. Somewhere, a column fills in."))

#undef VESTIGE_TAG_APPLY_TIME
#undef VESTIGE_READING_DURATION
#undef VESTIGE_READING_RADIUS
#undef VESTIGE_LENS_INTEGRITY
#undef VESTIGE_LENS_DISRUPT_TIME
#undef VESTIGE_LENS_FOLD_TIME
#undef VESTIGE_GRAFT_STEPS
#undef VESTIGE_GRAFT_STEP_TIME
#undef VESTIGE_PROBE_READINGS_NEEDED
#undef VESTIGE_PROBE_READINGS_PER_SUBJECT
#undef VESTIGE_PROBE_STING
#undef VESTIGE_PROBE_RECALIBRATE_TIME

/**
 * # The Menagerie — abductor vestige BOONS (patron: the Curator)
 *
 * The boon half of the abductor theme: the Curator pays out in equipment and
 * procedures, catalogued like everything else it owns. Upstream abductor gear
 * is gated hard behind TRAIT_ABDUCTOR_TRAINING (AbductorCheck / ScientistCheck,
 * verified in abductor_items.dm) and DM cannot skip a parent's override to
 * reach a grandparent, so the tools here are local re-ports built on the clean
 * base classes rather than subtypes of the locked gear. The heal gland is the
 * exception: its organ logic carries no abductor checks at all (verified in
 * equipment/gland.dm and glands/heal.dm), so The Gift implants the upstream
 * organ unmodified.
 *
 * Patron and trials live in the theme file; this file defines only boons and
 * their granted gear/spells.
 */

// Boon and gear descs quote these numbers literally — keep them in sync.
/// Recharge between successful motor-interruption (stun) discharges on the base instrument
#define VESTIGE_INSTRUMENT_STUN_RECHARGE (8 SECONDS)
/// Recharge between stun discharges on the perfected instrument
#define VESTIGE_INSTRUMENT_STUN_RECHARGE_PERFECTED (5 SECONDS)
/// Paralyze dealt by a stun discharge (upstream deals 14s; trimmed to crew tempo)
#define VESTIGE_INSTRUMENT_PARALYZE (6 SECONDS)
/// Sleep induced in an already-downed target (upstream deals 2 MINUTES; that deletes people from rounds)
#define VESTIGE_INSTRUMENT_SLEEP_TIME (30 SECONDS)
/// Recharge between successful sleep inductions
#define VESTIGE_INSTRUMENT_SLEEP_RECHARGE (20 SECONDS)
/// Channel time to fabricate restraints around a target's wrists (upstream: 3 seconds)
#define VESTIGE_INSTRUMENT_CUFF_TIME (3 SECONDS)
/// The recall anchor's short action cooldown — anti-spam on the button, NOT the teleport gate
#define VESTIGE_ANCHOR_BUTTON_COOLDOWN (2 SECONDS)
/// Recharge on the anchor's return-teleport half
#define VESTIGE_ANCHOR_RECALL_COOLDOWN (60 SECONDS)
/// Recharge on the paired anchor's return-teleport half
#define VESTIGE_ANCHOR_RECALL_COOLDOWN_PAIRED (40 SECONDS)
/// Radius of the null field, in tiles around the caster
#define VESTIGE_NULL_FIELD_RADIUS 3
/// How long the null field's silence holds those caught in it
#define VESTIGE_NULL_FIELD_DURATION (6 SECONDS)
/// Recharge between null fields
#define VESTIGE_NULL_FIELD_COOLDOWN (60 SECONDS)

// ===== BOONS =====

// The instrument is a local port of the abductor baton (abductor_items.dm):
// same sprite family, same mode structure, minus the training lock, the probe
// mode, and the worst of the numbers. Modes are trimmed from four to two —
// stun and sleep — with per-mode internal recharges so the tool is a scalpel,
// not a crowd-control firehose.
/datum/vestige_boon/item/alien_baton
	name = "The Instrument"
	// Keep the numbers in sync with VESTIGE_INSTRUMENT_STUN_RECHARGE /
	// VESTIGE_INSTRUMENT_SLEEP_TIME (initial values must be constant, so no
	// define interpolation here)
	desc = "The subject will be issued a two-setting handling tool. Setting one interrupts a target's motor function on contact; the instrument then meters its own recharge — eight seconds — because hurried collection damages the collection. Setting two induces half a minute of sleep, effective only on targets already down. Specimens acquired asleep file fewer complaints."
	grant_text = "A cool alien weight settles into your hand, already humming. Somewhere, a checklist is amended: ISSUED."
	item_type = /obj/item/melee/baton/vestige_instrument

/datum/vestige_boon/item/alien_baton/perfected
	name = "The Perfected Instrument"
	// Keep the number in sync with VESTIGE_INSTRUMENT_STUN_RECHARGE_PERFECTED
	// (initial values must be constant, so no define interpolation here)
	desc = "The same tool, post-revision: recharge interval reduced to five seconds, and a third setting added — restraints that assemble themselves around a target's wrists and object strenuously to being removed. The subject's previous unit will be reclaimed on issue. The Curator does not run a museum. Technically."
	grant_text = "Your instrument is revised. The replacement hums at a slightly more confident pitch."
	upgrades_from = /datum/vestige_boon/item/alien_baton
	item_type = /obj/item/melee/baton/vestige_instrument/perfected

/**
 * /datum/vestige_boon/item has no upgrade-replacement logic (only spells do),
 * so the perfected boon reclaims the superseded tool by hand: the first
 * carried base-pattern instrument (exact type — never another perfected) is
 * unmade before the new one is issued. A base instrument stashed off-body
 * (locker, floor) escapes the recall and lingers as a duplicate; acceptable —
 * the boon ledger still prevents the boon itself from being granted twice.
 */
/datum/vestige_boon/item/alien_baton/perfected/grant(mob/living/user, datum/mind/owner)
	for(var/obj/item/melee/baton/vestige_instrument/prior in user.get_all_contents())
		if(prior.type != /obj/item/melee/baton/vestige_instrument)
			continue
		to_chat(user, span_notice("Your instrument disassembles itself into a brief silver swarm and is reclaimed. The Curator does not issue duplicates."))
		qdel(prior)
		break
	return ..()

// The recall anchor is a rebuild of the OLD abductor vest's blink-back; this
// tree's vest (abductor_clothing.dm) carries only stealth/combat modes, so
// there is no upstream behavior left to match and the spell below sets its
// own rules. The anchor is a physical tag rather than a stored turf on
// purpose: this fork's ships are shuttles whose turfs are copied wholesale
// when they transit, so a turf ref would strand the anchor in the empty space
// the ship departed — a tag object rides the deck it is planted on.
/datum/vestige_boon/spell/anchor_tag
	name = "Recall Anchor"
	// Keep the duration in sync with VESTIGE_ANCHOR_RECALL_COOLDOWN
	// (initial values must be constant, so no define interpolation here)
	desc = "The subject will be taught to fix a return point: a tag, planted where the subject stands, and a pull, exercised from anywhere on the same celestial body. The pull requires a minute between uses and observes local wards; moving the tag is free, and the Curator encourages good exit hygiene. Right-click the ability to plant or move the tag."
	grant_text = "A small silver certainty is pressed into your understanding, the way a tool is pressed into a hand."
	spell_type = /datum/action/cooldown/spell/vestige_recall_anchor

/datum/vestige_boon/spell/anchor_tag/paired
	name = "Paired Anchor"
	// Keep the duration in sync with VESTIGE_ANCHOR_RECALL_COOLDOWN_PAIRED
	// (initial values must be constant, so no define interpolation here)
	desc = "The pull, recalibrated for two: whatever living thing the subject is holding onto — grabbed, or riding on the subject's back — arrives as well. Recharge interval reduced to forty seconds. The Curator notes that specimens transported this way arrive in measurably better condition than specimens dragged the whole distance."
	grant_text = "The tag learns a second signature. Plant it afresh; the Curator disapproves of stale coordinates."
	upgrades_from = /datum/vestige_boon/spell/anchor_tag
	spell_type = /datum/action/cooldown/spell/vestige_recall_anchor/paired

// The null field translates the abductor silencer (abductor_items.dm) for
// crew hands. Upstream shuts down radio HARDWARE; the boon enforces silence
// on the speakers themselves — the mute status effect
// (/datum/status_effect/silenced, applied via set_silence_if_lower, verified
// in status_effects.dm) — which reads the same in play and cannot be undone
// by toggling a headset back on.
/datum/vestige_boon/spell/silence_field
	name = "Null Field"
	// Keep the numbers in sync with VESTIGE_NULL_FIELD_RADIUS /
	// VESTIGE_NULL_FIELD_DURATION (initial values must be constant, so no
	// define interpolation here)
	desc = "On command, every voice within three paces of the subject — excepting the subject's own — declines to function for six seconds. No harm is recorded. No sound is, either. The Curator finds most procedures go smoother without commentary."
	grant_text = "A word is removed from the room's future. You are holding the gap where it was."
	spell_type = /datum/action/cooldown/spell/aoe/vestige_null_field

/**
 * The Gift: the upstream abductor HEAL gland (/obj/item/organ/heart/gland/heal,
 * glands/heal.dm), implanted directly. The organ carries no antag coupling —
 * its activate() loop runs off owner alone, ejecting implants, regrowing
 * failing organs and limbs, and purging toxins/restoring blood on a 20-40
 * second cycle (verified in gland.dm/heal.dm; on_mob_insert Start()s it for
 * any non-surgical insertion). It replaces the heart in-slot: the displaced
 * original is dropped at the subject's feet (default unflagged Insert()
 * behavior, verified in organ_movement.dm) rather than destroyed, so the
 * squeamish can reverse the procedure surgically later.
 *
 * Body-bound by nature: the gland lives in the flesh, not the mind, so it is
 * lost with the body — the vestige record re-runs grant() on respawn restore,
 * which implants a fresh one. The desc says so honestly.
 */
/datum/vestige_boon/gland_graft
	name = "The Gift"
	desc = "A replicator gland, grafted in place of the subject's original pump. It ejects foreign implants, regrows failing organs and limbs, and replaces lost blood — enthusiastically, and usually via the mouth. The original pump is returned to the subject at installation. The subject will find the modification persists poorly across bodies; reapplication is complimentary."
	grant_text = "Something turns over in your chest, twice, and settles into a rhythm that is almost — not quite — yours."
	radial_icon = 'icons/obj/antags/abductor.dmi'
	radial_icon_state = "health"

/datum/vestige_boon/gland_graft/grant(mob/living/user, datum/mind/owner)
	..()
	var/obj/item/organ/heart/gland/heal/gift = new()
	// Decommissioned like the trial kit's graft: the upstream gland ships with
	// 3 mind-control charges any abductor console could spend on the bearer
	gift.mind_control_uses = 0
	// Boons must land on plain humans, and they will — but a granting ritual
	// should never eat the pick on an exotic body. Non-carbons get the organ
	// in hand for later surgical installation instead.
	if(!iscarbon(user))
		user.put_in_hands(gift)
		to_chat(user, span_warning("The Curator's voice, faintly annoyed: \"Incompatible chassis. Installation is left as an exercise.\""))
		return
	var/mob/living/carbon/subject = user
	if(!gift.Insert(subject)) // paranoia; carbon is checked above
		user.put_in_hands(gift)
		return
	playsound(subject, 'sound/effects/splat.ogg', 50, TRUE)
	subject.visible_message(
		span_warning("[subject] clutches [subject.p_their()] chest as something under the ribs rearranges itself!"),
		span_userdanger("Something slides into place behind your sternum and begins, methodically, to beat. Your original is set down at your feet. The Curator suggests a jar."),
	)

// ===== THE INSTRUMENT =====

/**
 * The Curator's handling tool: the abductor baton, re-ported without the
 * training lock. Built on the clean baton base rather than the abductor
 * subtype because AbductorCheck lives in that subtype's can_baton()/toggle()
 * and DM offers no way to call past it to the grandparent.
 *
 * The base pipeline's shared stun cooldown (var/cooldown) gates EVERY
 * left-click mode behind one timer, which would break the tool's identity
 * combo (stun, switch settings, sleep) — so it is zeroed, upstream-style, and
 * each mode meters itself inside baton_effect() instead. A stun attempt
 * during recharge is a harmless zero-force bonk with a balloon.
 */
/obj/item/melee/baton/vestige_instrument
	name = "alien instrument"
	desc = "A slim alien rod that drinks the light. Two settings: one for stopping a specimen, one for putting a stopped specimen to sleep. Between uses it hums quietly to itself, counting."
	desc_controls = "Left-click to apply the active setting. Right-click to strike. Use in hand to switch settings."
	icon = 'icons/obj/antags/abductor.dmi'
	icon_state = "wonderprodStun"
	inhand_icon_state = "wonderprodStun"
	lefthand_file = 'icons/mob/inhands/antag/abductor_lefthand.dmi'
	righthand_file = 'icons/mob/inhands/antag/abductor_righthand.dmi'
	icon_angle = -45
	force = 7
	wound_bonus = 0
	cooldown = 0 SECONDS // per-mode recharges are metered in baton_effect instead
	stamina_damage = 0
	on_stun_sound = 'sound/items/weapons/egloves.ogg'
	affect_cyborg = TRUE
	actions_types = list(/datum/action/item_action/toggle_mode)
	action_slots = ALL
	/// Current setting: BATON_STUN or BATON_SLEEP (the perfected pattern adds BATON_CUFF)
	var/mode = BATON_STUN
	/// How many settings the cycle covers (the global mode defines run 0..n-1 in cycle order)
	var/mode_count = 2
	/// Recharge between successful stun discharges
	var/stun_recharge = VESTIGE_INSTRUMENT_STUN_RECHARGE
	/// Ready-time gate on the stun setting
	COOLDOWN_DECLARE(stun_ready)
	/// Ready-time gate on the sleep setting
	COOLDOWN_DECLARE(sleep_ready)

/obj/item/melee/baton/vestige_instrument/Initialize(mapload)
	. = ..()
	AddElement(/datum/element/update_icon_updates_onmob)

/obj/item/melee/baton/vestige_instrument/update_icon_state()
	. = ..()
	switch(mode)
		if(BATON_STUN)
			icon_state = "wonderprodStun"
			inhand_icon_state = "wonderprodStun"
		if(BATON_SLEEP)
			icon_state = "wonderprodSleep"
			inhand_icon_state = "wonderprodSleep"
		if(BATON_CUFF)
			icon_state = "wonderprodCuff"
			inhand_icon_state = "wonderprodCuff"

/obj/item/melee/baton/vestige_instrument/examine(mob/user)
	. = ..()
	switch(mode)
		if(BATON_STUN)
			. += span_notice("It is set to motor interruption.")
			if(!COOLDOWN_FINISHED(src, stun_ready))
				. += span_warning("The charge indicator is dim: [DisplayTimeText(COOLDOWN_TIMELEFT(src, stun_ready))] to ready.")
		if(BATON_SLEEP)
			. += span_notice("It is set to sleep induction. It takes hold fully only on someone already down.")
			if(!COOLDOWN_FINISHED(src, sleep_ready))
				. += span_warning("The sedative reservoir is cycling: [DisplayTimeText(COOLDOWN_TIMELEFT(src, sleep_ready))] to ready.")
		if(BATON_CUFF)
			. += span_notice("It is set to restraint fabrication.")

/obj/item/melee/baton/vestige_instrument/attack_self(mob/living/user)
	. = ..()
	toggle(user)

/// Cycles to the next setting. No training check: the Curator issues, it does not gatekeep.
/obj/item/melee/baton/vestige_instrument/proc/toggle(mob/living/user)
	mode = (mode + 1) % mode_count
	var/setting
	switch(mode)
		if(BATON_STUN)
			setting = "motor interruption"
		if(BATON_SLEEP)
			setting = "sleep induction"
		if(BATON_CUFF)
			setting = "restraint fabrication"
	var/is_stun_mode = mode == BATON_STUN
	affect_cyborg = is_stun_mode
	log_stun_attack = is_stun_mode // sleep and cuffs write their own log lines
	on_stun_sound = (mode == BATON_CUFF) ? null : 'sound/items/weapons/egloves.ogg'
	balloon_alert(user, "set to [setting]")
	update_appearance()

// Messages are handled per-mode in baton_effect and its helpers, upstream-style
/obj/item/melee/baton/vestige_instrument/get_stun_description(mob/living/target, mob/living/user)
	return

/obj/item/melee/baton/vestige_instrument/get_cyborg_stun_description(mob/living/target, mob/living/user)
	return

/obj/item/melee/baton/vestige_instrument/baton_effect(mob/living/target, mob/living/user, modifiers, stun_override)
	switch(mode)
		if(BATON_STUN)
			if(!COOLDOWN_FINISHED(src, stun_ready))
				balloon_alert(user, "still charging!")
				return FALSE
			COOLDOWN_START(src, stun_ready, stun_recharge)
			target.visible_message(
				span_danger("[user] stuns [target] with [src]!"),
				span_userdanger("[user] stuns you with [src]!"),
				visible_message_flags = ALWAYS_SHOW_SELF_MESSAGE,
			)
			// Upstream's stun package, trimmed: 6s paralyze against upstream's 14
			target.set_jitter_if_lower(20 SECONDS)
			target.set_confusion_if_lower(8 SECONDS)
			target.set_stutter_if_lower(10 SECONDS)
			SEND_SIGNAL(target, COMSIG_LIVING_MINOR_SHOCK)
			target.Paralyze(VESTIGE_INSTRUMENT_PARALYZE * (HAS_TRAIT(target, TRAIT_BATON_RESISTANCE) ? 0.1 : 1))
			return TRUE
		if(BATON_SLEEP)
			sleep_attack(target, user)
		if(BATON_CUFF)
			cuff_attack(target, user)
	return FALSE

/**
 * Sleep induction, ported from upstream SleepAttack with the round-deleting
 * edges filed off: full effect only lands on a target already stopped —
 * incapacitated (ignoring mere cuffs or grabs, upstream's own test) or flat
 * on the deck — sleeps for 30 seconds instead of two minutes, and the
 * inducer recharges 20 seconds between doses. Standing targets get token
 * drowsiness; the stun setting exists for a reason.
 */
/obj/item/melee/baton/vestige_instrument/proc/sleep_attack(mob/living/target, mob/living/user)
	if(!COOLDOWN_FINISHED(src, sleep_ready))
		balloon_alert(user, "sedative cycling!")
		return
	if(INCAPACITATED_IGNORING(target, INCAPABLE_RESTRAINTS|INCAPABLE_GRAB) || target.body_position == LYING_DOWN)
		if(target.can_block_magic(MAGIC_RESISTANCE_MIND))
			to_chat(user, span_warning("Something in [target]'s head shrugs the inducer off. It seems you've been foiled."))
			target.visible_message(
				span_danger("[user] tried to induce sleep in [target] with [src], but is unsuccessful!"),
				span_userdanger("You feel a strange wave of heavy drowsiness wash over you!"),
			)
			target.adjust_drowsiness(4 SECONDS)
			return
		target.visible_message(
			span_danger("[user] induces sleep in [target] with [src]!"),
			span_userdanger("You suddenly feel very drowsy!"),
		)
		target.Sleeping(VESTIGE_INSTRUMENT_SLEEP_TIME)
		COOLDOWN_START(src, sleep_ready, VESTIGE_INSTRUMENT_SLEEP_RECHARGE)
		log_combat(user, target, "put to sleep", src.name)
		return
	// Standing and struggling: token drowsiness only, no recharge spent
	if(target.can_block_magic(MAGIC_RESISTANCE_MIND, charge_cost = 0))
		to_chat(user, span_warning("Something in [target]'s head blocks the inducer entirely. It seems you've been foiled."))
		return
	target.adjust_drowsiness(2 SECONDS)
	to_chat(user, span_warning("The inducer takes hold fully only on specimens already down."))
	target.visible_message(
		span_danger("[user] waves [src] over [target] to little effect!"),
		span_userdanger("You suddenly feel drowsy!"),
	)

/**
 * Restraint fabrication (perfected pattern only), ported from upstream
 * CuffAttack unchanged in the ways that matter: a 3 second channel, then
 * upstream's self-tightening hard-light restraints — 45 second breakout,
 * and they discharge into sparks the moment they come off (energy/used is
 * DROPDEL; verified in abductor_items.dm).
 */
/obj/item/melee/baton/vestige_instrument/proc/cuff_attack(mob/living/victim, mob/living/user)
	if(!iscarbon(victim))
		balloon_alert(user, "no compatible wrists!")
		return
	var/mob/living/carbon/carbon_victim = victim
	if(carbon_victim.handcuffed)
		balloon_alert(user, "already restrained!")
		return
	if(!carbon_victim.canBeHandcuffed())
		to_chat(user, span_warning("[carbon_victim] doesn't have two hands..."))
		return
	playsound(src, 'sound/items/weapons/cablecuff.ogg', 30, TRUE, -2)
	carbon_victim.visible_message(
		span_danger("[user] begins restraining [carbon_victim] with [src]!"),
		span_userdanger("[user] begins shaping an energy field around your hands!"),
	)
	if(!do_after(user, VESTIGE_INSTRUMENT_CUFF_TIME, carbon_victim) || !carbon_victim.canBeHandcuffed() || carbon_victim.handcuffed)
		to_chat(user, span_warning("You fail to restrain [carbon_victim]."))
		return
	carbon_victim.set_handcuffed(new /obj/item/restraints/handcuffs/energy/used(carbon_victim))
	carbon_victim.update_handcuffed()
	to_chat(user, span_notice("You restrain [carbon_victim]."))
	log_combat(user, carbon_victim, "handcuffed", src.name)

// The revised pattern: quicker between discharges, and the restraint
// fabricator is unlocked as a third setting in the cycle.
/obj/item/melee/baton/vestige_instrument/perfected
	name = "perfected alien instrument"
	desc = "A slim alien rod that drinks the light. Three settings: stopping a specimen, putting a stopped specimen to sleep, and fabricating restraints that assemble themselves. The hum between uses is shorter now, and sounds faintly pleased about it."
	mode_count = 3
	stun_recharge = VESTIGE_INSTRUMENT_STUN_RECHARGE_PERFECTED

// ===== RECALL ANCHOR =====

/**
 * A two-stage return spell rebuilt from the retired abductor vest blink-back.
 * Left-click (or keybind) pulls the caster to the planted tag; right-clicking
 * the button plants or moves the tag (the same input split the heretic living
 * heart uses). With no tag planted, any cast plants one.
 *
 * Only the PULL pays the long recharge: the action's own cooldown is a token
 * anti-spam tick, and the 60 second gate lives on a separate cooldown checked
 * in before_cast — this fork's Activate() ignores cast()'s return value, so
 * per-outcome cooldown control has to happen before the cast, not after.
 *
 * The pull refuses to cross z-levels. There is no upstream rule to match
 * (this tree's vest lost its blink-back), and in an overmap fork a cross-z
 * recall is a free ride home from anywhere in the galaxy. Because the tag is
 * a physical object, it transits WITH a ship that moves — so "same z" always
 * reads as "same local space", and a ship undocking without you honestly
 * strands you. do_teleport runs unforced on the magic channel: NOTELEPORT
 * areas and TRAIT_NO_TELEPORT keep their veto.
 */
/datum/action/cooldown/spell/vestige_recall_anchor
	name = "Recall Anchor"
	desc = "Cast to return to your planted anchor tag; right-click the ability to plant the tag where you stand, or move it. Returning recharges slowly. Moving the tag is free. The pull cannot reach across the void between celestial bodies."
	button_icon = 'icons/mob/actions/actions_items.dmi'
	button_icon_state = "vortex_recall"
	background_icon_state = "bg_alien"
	overlay_icon_state = "bg_alien_border"
	school = SCHOOL_TRANSLOCATION
	cooldown_time = VESTIGE_ANCHOR_BUTTON_COOLDOWN
	invocation_type = INVOCATION_NONE
	spell_requirements = NONE
	/// Recharge on the return half; planting rides only the short action cooldown
	var/recall_cooldown_time = VESTIGE_ANCHOR_RECALL_COOLDOWN
	/// Ready-time gate on the return half
	COOLDOWN_DECLARE(recall_ready)
	/// The planted tag. A physical object so it rides whatever deck it is planted on.
	var/obj/effect/vestige_anchor_tag/anchor
	/// Whether the activation in flight arrived via right-click (a replant request)
	var/replant_requested = FALSE
	/// Resolved intent for the cast in flight: TRUE plants/moves the tag, FALSE pulls to it
	var/planting_this_cast = TRUE

/datum/action/cooldown/spell/vestige_recall_anchor/Destroy()
	QDEL_NULL(anchor)
	return ..()

/datum/action/cooldown/spell/vestige_recall_anchor/Trigger(mob/clicker, trigger_flags, atom/target)
	replant_requested = !!(trigger_flags & TRIGGER_SECONDARY_ACTION)
	return ..()

/// The tag's current turf, or null while it is unplanted (or has somehow been destroyed)
/datum/action/cooldown/spell/vestige_recall_anchor/proc/get_anchor_turf()
	if(QDELETED(anchor))
		anchor = null
		return null
	return get_turf(anchor)

/datum/action/cooldown/spell/vestige_recall_anchor/before_cast(atom/cast_on)
	. = ..()
	planting_this_cast = replant_requested || !get_anchor_turf()
	replant_requested = FALSE // never let a stale right-click steer a later keybind cast
	if(. & SPELL_CANCEL_CAST)
		return
	if(planting_this_cast)
		return
	// The pull half meters itself here — cancelling in before_cast leaves the
	// (short) action cooldown untouched, so a refused pull never eats the button
	if(!COOLDOWN_FINISHED(src, recall_ready))
		owner.balloon_alert(owner, "pull recharging!")
		to_chat(owner, span_warning("The pull is spent for another [DisplayTimeText(COOLDOWN_TIMELEFT(src, recall_ready))]."))
		return . | SPELL_CANCEL_CAST
	var/turf/here = get_turf(cast_on)
	var/turf/destination = get_anchor_turf()
	if(here == destination)
		owner.balloon_alert(owner, "already at the anchor!")
		return . | SPELL_CANCEL_CAST
	if(!here || here.z != destination.z)
		owner.balloon_alert(owner, "anchor out of reach!")
		to_chat(owner, span_warning("The tag answers faintly, from somewhere the pull cannot reach."))
		return . | SPELL_CANCEL_CAST

/datum/action/cooldown/spell/vestige_recall_anchor/cast(mob/living/cast_on)
	. = ..()
	if(planting_this_cast)
		plant_tag(cast_on)
	else
		pull_to_tag(cast_on)

/// Plants the tag at the caster's feet, or drags the existing one over
/datum/action/cooldown/spell/vestige_recall_anchor/proc/plant_tag(mob/living/user)
	var/turf/spot = get_turf(user)
	if(!spot)
		return
	if(QDELETED(anchor))
		anchor = new(spot)
	else
		anchor.forceMove(spot)
	playsound(spot, 'sound/machines/click.ogg', 30, TRUE)
	user.balloon_alert(user, "anchor planted")
	// A tag in a warded area plants fine and then refuses every pull —
	// complain now, not at the worst possible moment
	var/area/spot_area = get_area(spot)
	if(spot_area.area_flags & NOTELEPORT)
		to_chat(user, span_warning("The tag buzzes unhappily: something about this place refuses arrivals. The pull will not land here."))

/// The pull. Buckled riders (fireman carries, piggybacks) come along via
/// do_teleport's own rider handling; a grabbed passenger is the paired
/// pattern's business, captured before the jump breaks the pull.
/datum/action/cooldown/spell/vestige_recall_anchor/proc/pull_to_tag(mob/living/user)
	var/turf/destination = get_anchor_turf()
	if(!destination)
		return
	var/mob/living/passenger = gather_passenger(user)
	if(!do_teleport(user, destination, asoundout = 'sound/effects/phasein.ogg', channel = TELEPORT_CHANNEL_MAGIC))
		// do_teleport balloons the refusal itself; a refused pull spends no recharge
		return
	COOLDOWN_START(src, recall_ready, recall_cooldown_time)
	if(!passenger || QDELETED(passenger))
		return
	if(do_teleport(passenger, destination, channel = TELEPORT_CHANNEL_MAGIC, no_effects = TRUE))
		user.start_pulling(passenger, supress_message = TRUE)
		to_chat(passenger, span_warning("The deck blinks, and you are somewhere else. You are still held."))
	else
		to_chat(user, span_warning("The pull arrives alone — your passenger was refused."))

/// Who comes along for the pull. The base anchor takes nobody.
/datum/action/cooldown/spell/vestige_recall_anchor/proc/gather_passenger(mob/living/user)
	return null

/datum/action/cooldown/spell/vestige_recall_anchor/paired
	name = "Paired Anchor"
	desc = "Cast to return to your planted anchor tag, carrying whoever you are grabbing or carrying; right-click the ability to plant or move the tag. Returning recharges slowly. Moving the tag is free. The pull cannot reach across the void between celestial bodies."
	recall_cooldown_time = VESTIGE_ANCHOR_RECALL_COOLDOWN_PAIRED

// Grabbed-or-willing, by this fork's own teleport grammar: a pulled living
// thing (grabs are adjacency by definition) is ferried by hand below, and
// willing riders buckled on for a carry are ferried by do_teleport natively.
/datum/action/cooldown/spell/vestige_recall_anchor/paired/gather_passenger(mob/living/user)
	if(isliving(user.pulling))
		return user.pulling
	return null

/// The planted half of the recall anchor. A physical object on purpose:
/// shuttle transits carry it with the deck it is planted on, where a stored
/// turf ref would point forever at the tile the ship left behind. Effects
/// are indestructible and immovable by default, so the counterplay is
/// spotting it (it glows, faintly) and camping it — not breaking it.
/obj/effect/vestige_anchor_tag
	name = "recall anchor"
	desc = "A stubby alien beacon, planted with a surveyor's confidence. It is fixed to this spot the way a filing label is fixed to a drawer: it does not care where the drawer goes, only that it can be found again."
	icon = 'icons/obj/antags/abductor.dmi'
	icon_state = "beacon"
	layer = LOW_OBJ_LAYER
	anchored = TRUE
	alpha = 160
	light_range = 1.2
	light_power = 0.4
	light_color = "#9fd8cf"

// ===== NULL FIELD =====

/**
 * The abductor silencer, translated from hardware to procedure. Upstream
 * (abductor_items.dm) switches off radios in a small view radius; the boon
 * spec reads that as enforced silence and applies the mute status effect
 * (/datum/status_effect/silenced — TRAIT_MUTE under a timer, cleared on
 * death/fullheal) to everyone caught in the field at cast. One application,
 * no lingering zone, no damage, and — deliberately — no sound or room-wide
 * message: a silencer that announced itself would be a contradiction. The
 * caster is exempt, as upstream exempts its user.
 *
 * Mind-antimagic bearers shrug it off (charge-free check, the same courtesy
 * the instrument's sleep inducer pays) so a warded target keeps their voice.
 * range() rather than view(): it is a field, and glass or a shut door is no
 * defense against six seconds of nothing.
 */
/datum/action/cooldown/spell/aoe/vestige_null_field
	name = "Null Field"
	desc = "Enforce six seconds of silence on every voice within three paces of you. Yours still works. No one will hear what they were about to say."
	button_icon = 'icons/mob/actions/actions_mime.dmi'
	button_icon_state = "mime_speech"
	background_icon_state = "bg_alien"
	overlay_icon_state = "bg_alien_border"
	cooldown_time = VESTIGE_NULL_FIELD_COOLDOWN
	invocation_type = INVOCATION_NONE
	spell_requirements = NONE
	antimagic_flags = MAGIC_RESISTANCE_MIND
	aoe_radius = VESTIGE_NULL_FIELD_RADIUS

/datum/action/cooldown/spell/aoe/vestige_null_field/get_things_to_cast_on(atom/center)
	var/list/things = list()
	for(var/mob/living/nearby in range(aoe_radius, center))
		if(nearby == owner || nearby == center || nearby.stat == DEAD)
			continue
		things += nearby
	return things

/datum/action/cooldown/spell/aoe/vestige_null_field/cast_on_thing_in_aoe(mob/living/victim, atom/caster)
	if(victim.can_block_magic(antimagic_flags, charge_cost = 0))
		to_chat(victim, span_notice("A pressure closes around your throat for a heartbeat — and something you carry shrugs it away."))
		return
	victim.set_silence_if_lower(VESTIGE_NULL_FIELD_DURATION)
	to_chat(victim, span_warning("Your voice is filed away somewhere you cannot reach. The room has gone perfectly, wrongly quiet."))

/datum/action/cooldown/spell/aoe/vestige_null_field/after_cast(atom/cast_on)
	. = ..()
	owner.balloon_alert(owner, "the field takes hold")

#undef VESTIGE_INSTRUMENT_STUN_RECHARGE
#undef VESTIGE_INSTRUMENT_STUN_RECHARGE_PERFECTED
#undef VESTIGE_INSTRUMENT_PARALYZE
#undef VESTIGE_INSTRUMENT_SLEEP_TIME
#undef VESTIGE_INSTRUMENT_SLEEP_RECHARGE
#undef VESTIGE_INSTRUMENT_CUFF_TIME
#undef VESTIGE_ANCHOR_BUTTON_COOLDOWN
#undef VESTIGE_ANCHOR_RECALL_COOLDOWN
#undef VESTIGE_ANCHOR_RECALL_COOLDOWN_PAIRED
#undef VESTIGE_NULL_FIELD_RADIUS
#undef VESTIGE_NULL_FIELD_DURATION
#undef VESTIGE_NULL_FIELD_COOLDOWN
