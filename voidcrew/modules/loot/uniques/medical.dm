/**
 * # Medical uniques: cold-chain pharmacy cache
 *
 * Rare-tier prizes for the medical loot cache (voidcrew/modules/loot/zone_loot.dm,
 * `loot_uniques` on /datum/loot_theme/medical). Not wired into any loot
 * table here, that's the coordinator's job once these are added to the .dme.
 *
 * Every item below carries TRAIT_NO_REPLICATE (voidcrew/_DEFINES/loot.dm) so
 * duplicators (Helios pattern stamp, etc.) refuse to copy them.
 *
 * Sprites: custom art in voidcrew/modules/loot/icons/uniques.dmi (worn states in
 * uniques_worn.dmi). Inhand states are still the stock ones where the vanilla
 * inhand reads correctly for the object.
 */

/// Trait applied briefly after a Winterkiss stasis ends, so the dose can't be
/// chain-reapplied to grief someone into indefinite stasis.
#define TRAIT_WINTERKISS_IMMUNE "winterkiss_immune"

// =========================================================================
// GREEN
// =========================================================================

/**
 * Night sister's watch: a fob watch that chimes once when someone on your
 * deck (z-level) drops into hard crit, with a rough directional hint.
 *
 * Sprite donor: /obj/item/clothing/neck/stethoscope ("stethoscope" icon_state,
 * icons/obj/clothing/neck.dmi), no fob-watch/pocket-watch sprite exists
 * anywhere in this codebase (verified via dmi_list_states on neck.dmi and a
 * repo-wide search for "watch"/"clock" assets), so this is the closest worn
 * medical neck item available. Flagged as a sprite mismatch in the report.
 *
 * Impl note: rather than hooking COMSIG_MOB_STATCHANGE on every mob in the
 * world (expensive to register/track safely for an item that can change
 * hands and z-levels at any time), this uses the doc's alternate suggestion:
 * a throttled processing scan of GLOB.mob_living_list filtered to the
 * wearer's z-level, diffed against the last scan to fire only on new crits.
 */
/obj/item/clothing/neck/night_sisters_watch
	name = "night sister's watch"
	desc = "A fob watch on a chain, pinned upside-down the way nurses wear them. It chimes when someone on your deck drops into crit."
	icon = 'voidcrew/modules/loot/icons/uniques.dmi'
	icon_state = "fob_watch"
	worn_icon = 'voidcrew/modules/loot/icons/uniques_worn.dmi'
	worn_icon_state = "fob_watch"
	/// How often we re-scan the deck for freshly-critical mobs.
	var/scan_interval = 4 SECONDS
	/// world.time of the next allowed scan.
	var/next_scan = 0
	/// Mobs we were already tracking as critical as of the last scan (direct refs, rebuilt every scan).
	var/list/known_crit = list()

/obj/item/clothing/neck/night_sisters_watch/Initialize(mapload)
	. = ..()
	ADD_TRAIT(src, TRAIT_NO_REPLICATE, INNATE_TRAIT)

/obj/item/clothing/neck/night_sisters_watch/equipped(mob/user, slot, initial)
	. = ..()
	if(slot == ITEM_SLOT_NECK)
		START_PROCESSING(SSobj, src)
	else
		STOP_PROCESSING(SSobj, src)
		known_crit = list()

/obj/item/clothing/neck/night_sisters_watch/dropped(mob/user, silent)
	. = ..()
	STOP_PROCESSING(SSobj, src)
	known_crit = list()

/obj/item/clothing/neck/night_sisters_watch/process(seconds_per_tick)
	if(!ismob(loc))
		return
	var/mob/living/wearer = loc
	if(wearer.get_item_by_slot(ITEM_SLOT_NECK) != src)
		return
	if(world.time < next_scan)
		return
	next_scan = world.time + scan_interval

	var/turf/wearer_turf = get_turf(wearer)
	if(!wearer_turf)
		return

	var/list/currently_critical = list()
	for(var/mob/living/candidate as anything in GLOB.mob_living_list)
		if(candidate == wearer || candidate.stat != HARD_CRIT)
			continue
		var/turf/candidate_turf = get_turf(candidate)
		if(!candidate_turf || candidate_turf.z != wearer_turf.z)
			continue
		currently_critical += candidate
		if(!(candidate in known_crit))
			var/direction = get_dir(wearer, candidate)
			to_chat(wearer, span_notice("[src] chimes softly. Someone on your deck just dropped into crit[direction ? " - somewhere to the [dir2text(direction)]" : ""]."))
	known_crit = currently_critical

/**
 * Triage pen: marks up to three patients at once. Marked patients have
 * their vitals streamed to the pen's current holder on a short interval, and
 * unmark automatically once they're stable again.
 *
 * Sprite: "triage_pen" in uniques.dmi. can_click is turned off because a grease
 * pencil has no clicker, that also stops /obj/item/pen's transforming component
 * from flipping icon_state to "triage_pen_retracted", a state that doesn't (and
 * shouldn't) exist. Inhand/ear-slot states stay on the stock pen sprites.
 *
 * Deviation (flagged): the doc's "every med HUD in the sector flags them"
 * would need a new HUD icon state, which isn't allowed here. Per the task's
 * explicit fallback, this streams vitals directly to the pen holder via
 * to_chat instead of a med HUD overlay or PDA app.
 */
/obj/item/pen/red/triage
	name = "triage pen"
	desc = "A red grease pencil, chewed at one end. Mark up to three patients and it reads their vitals back to whoever's holding it."
	icon = 'voidcrew/modules/loot/icons/uniques.dmi'
	icon_state = "triage_pen"
	can_click = FALSE
	/// Weakrefs to the (up to three) patients this specific pen is tracking.
	var/list/datum/weakref/marked_patients = list()
	/// Hard cap on simultaneous marks, "triage means choosing."
	var/static/max_marked = 3

/obj/item/pen/red/triage/Initialize(mapload)
	. = ..()
	ADD_TRAIT(src, TRAIT_NO_REPLICATE, INNATE_TRAIT)

/obj/item/pen/red/triage/attack(mob/living/target_mob, mob/living/user, list/modifiers, list/attack_modifiers)
	. = ..()
	if(!.)
		return
	try_mark_patient(target_mob, user)

/// Marks (or, if already marked by this pen, unmarks) a patient.
/obj/item/pen/red/triage/proc/try_mark_patient(mob/living/target, mob/living/user)
	cleanup_marked_list()

	var/datum/weakref/existing_ref = get_marked_ref(target)
	if(existing_ref)
		target.remove_status_effect(/datum/status_effect/triage_marked)
		marked_patients -= existing_ref
		balloon_alert(user, "unmarked")
		to_chat(user, span_notice("You stop tracking [target]."))
		return

	if(target.has_status_effect(/datum/status_effect/triage_marked))
		balloon_alert(user, "already marked")
		to_chat(user, span_warning("Someone's already tracking [target]."))
		return

	if(length(marked_patients) >= max_marked)
		balloon_alert(user, "tracking 3 already")
		to_chat(user, span_warning("[src] is already tracking three patients. Unmark one first."))
		return

	var/datum/status_effect/triage_marked/marked = target.apply_status_effect(/datum/status_effect/triage_marked, src)
	if(!marked)
		return
	marked_patients += WEAKREF(target)
	balloon_alert(user, "marked")
	to_chat(user, span_notice("You mark [target] for triage."))

/// Drops any weakrefs whose target no longer exists.
/obj/item/pen/red/triage/proc/cleanup_marked_list()
	var/list/stale = list()
	for(var/datum/weakref/ref as anything in marked_patients)
		if(!ref.resolve())
			stale += ref
	marked_patients -= stale

/obj/item/pen/red/triage/proc/get_marked_ref(mob/living/target)
	for(var/datum/weakref/ref as anything in marked_patients)
		if(ref.resolve() == target)
			return ref
	return null

/// Called by the status effect when it self-removes (patient stabilized, or deleted).
/obj/item/pen/red/triage/proc/forget_patient(mob/living/target)
	var/datum/weakref/ref = get_marked_ref(target)
	if(ref)
		marked_patients -= ref

/// Streams vitals to whoever is currently holding the marking pen; ends itself once the patient is stable.
/datum/status_effect/triage_marked
	id = "triage_marked"
	duration = STATUS_EFFECT_PERMANENT
	tick_interval = 4 SECONDS
	status_type = STATUS_EFFECT_UNIQUE
	alert_type = null
	/// Weakref back to the triage pen that marked us.
	var/datum/weakref/pen_ref

/datum/status_effect/triage_marked/on_creation(mob/living/new_owner, obj/item/pen/red/triage/marking_pen)
	. = ..()
	if(.)
		pen_ref = WEAKREF(marking_pen)

/datum/status_effect/triage_marked/tick(seconds_between_ticks)
	if(!owner)
		return
	// Stable = conscious and comfortably clear of crit. Auto-unmark.
	if(owner.stat != DEAD && owner.stat != HARD_CRIT && owner.health > (owner.crit_threshold + 10))
		qdel(src)
		return
	var/obj/item/pen/red/triage/pen = pen_ref?.resolve()
	if(!pen)
		return
	var/mob/holder = pen.loc
	if(!ismob(holder))
		return
	to_chat(holder, span_notice("[pen] streams: [owner.name] - [round(owner.health)]/[owner.maxHealth] health (brute [round(owner.getBruteLoss())], burn [round(owner.getFireLoss())], tox [round(owner.getToxLoss())], oxy [round(owner.getOxyLoss())])."))

/datum/status_effect/triage_marked/on_remove()
	var/obj/item/pen/red/triage/pen = pen_ref?.resolve()
	pen?.forget_patient(owner)

// =========================================================================
// YELLOW
// =========================================================================

/**
 * Meridian drip: a wheeled IV stand with an internal chemistry unit that
 * synthesizes the right healer chem for the attached patient's worst damage
 * type, in small doses, straight from its own power (no beaker needed).
 *
 * Base: /obj/machinery/iv_drip (voidcrew doc suggested /obj/structure, but
 * the codebase's IV stand is /obj/machinery/iv_drip, deviated to match the
 * real base class rather than inventing a structure duplicate of it).
 *
 * Sprites: gold-and-brass custom art in uniques.dmi. The parent's
 * update_icon_state() builds "[base_icon_state]_injecting" / "_injectidle" (and
 * "_donating" / "_donateidle", which this drip can never reach, toggle_mode()
 * bails out early on inject_only stands), so base_icon_state points at the two
 * "meridian_drip_*" states. The parent's update_overlays() only draws the
 * beaker and reagent-fill overlays when there's an external reagent_container,
 * and this stand uses internal storage, so nothing needs re-anchoring: the lit
 * chemistry unit and the drop are painted into the "_injecting" state itself.
 *
 * "Folds into a carry item": no fold/deploy convention exists elsewhere in
 * this codebase, so this adds a bespoke pair, a verb to fold the structure
 * into /obj/item/meridian_drip, and attack_self() on that item to unfold it
 * back into the structure.
 */
/obj/machinery/iv_drip/meridian_drip
	name = "Meridian drip"
	desc = "A wheeled IV stand with a chemistry unit where the bag should hang. It doesn't take a beaker - it brews whatever the patient needs on its own."
	icon = 'voidcrew/modules/loot/icons/uniques.dmi'
	icon_state = "meridian_drip_injectidle"
	base_icon_state = "meridian_drip"
	use_internal_storage = TRUE
	inject_only = TRUE
	internal_volume_maximum = 30
	transfer_rate = 0.5
	/// Units of healer synthesized per second.
	var/dose_rate = 0.5
	/// Safety ceiling (in the patient's bloodstream) per healer chem, so the drip doesn't stack an overdose on top of itself.
	var/static/list/healer_caps = list(
		/datum/reagent/medicine/sal_acid = 20,
		/datum/reagent/medicine/c2/aiuri = 20,
		/datum/reagent/medicine/pen_acid = 15,
		/datum/reagent/medicine/salbutamol = 20,
	)

/obj/machinery/iv_drip/meridian_drip/Initialize(mapload)
	. = ..()
	ADD_TRAIT(src, TRAIT_NO_REPLICATE, INNATE_TRAIT)

/obj/machinery/iv_drip/meridian_drip/process(seconds_per_tick)
	if(attachment && isliving(attachment.attached_to))
		synthesize_dose(attachment.attached_to, seconds_per_tick)
	return ..()

/// Tops up our internal reagent store with whatever chem best matches the patient's worst damage type, respecting a safety cap.
/obj/machinery/iv_drip/meridian_drip/proc/synthesize_dose(mob/living/patient, seconds_per_tick)
	var/healer_type = get_target_healer(patient)
	if(!healer_type)
		return
	var/cap = healer_caps[healer_type]
	if(patient.reagents && patient.reagents.get_reagent_amount(healer_type) >= cap)
		return
	reagents.add_reagent(healer_type, dose_rate * seconds_per_tick)

/// Picks the healer reagent matching the patient's single worst damage type.
/obj/machinery/iv_drip/meridian_drip/proc/get_target_healer(mob/living/patient)
	var/brute = patient.getBruteLoss()
	var/burn = patient.getFireLoss()
	var/tox = patient.getToxLoss()
	var/oxy = patient.getOxyLoss()
	var/worst = max(brute, burn, tox, oxy)
	if(worst <= 0)
		return null
	if(worst == brute)
		return /datum/reagent/medicine/sal_acid
	if(worst == burn)
		return /datum/reagent/medicine/c2/aiuri
	if(worst == tox)
		return /datum/reagent/medicine/pen_acid
	return /datum/reagent/medicine/salbutamol

/obj/machinery/iv_drip/meridian_drip/verb/fold_up()
	set name = "Fold Up Drip Stand"
	set category = "Object"
	set src in view(1)

	if(!isliving(usr))
		to_chat(usr, span_warning("You can't do that!"))
		return
	if(!usr.can_perform_action(src) || usr.incapacitated)
		return
	if(attachment)
		to_chat(usr, span_warning("Detach [src] from its patient first!"))
		return

	var/obj/item/meridian_drip/folded = new(drop_location())
	usr.visible_message(span_notice("[usr] folds up [src]."), span_notice("You fold [src] down into something you can carry."))
	if(!usr.put_in_hands(folded))
		folded.forceMove(drop_location())
	qdel(src)

/// The carried, folded form of the Meridian drip.
/// Inhand state is the stock "rods" bundle. It's the right shape for a folded
/// pole and uniques_lefthand.dmi has no rod sprite.
/obj/item/meridian_drip
	name = "folded Meridian drip"
	desc = "A collapsed IV stand, chemistry unit tucked in against the frame. Unfold it and it's back to work."
	icon = 'voidcrew/modules/loot/icons/uniques.dmi'
	icon_state = "meridian_drip_folded"
	inhand_icon_state = "rods"
	w_class = WEIGHT_CLASS_BULKY
	custom_materials = list(/datum/material/iron = SMALL_MATERIAL_AMOUNT * 2)

/obj/item/meridian_drip/Initialize(mapload)
	. = ..()
	ADD_TRAIT(src, TRAIT_NO_REPLICATE, INNATE_TRAIT)

/obj/item/meridian_drip/attack_self(mob/living/user)
	. = ..()
	if(user.incapacitated)
		return
	new /obj/machinery/iv_drip/meridian_drip(get_turf(user))
	user.visible_message(span_notice("[user] unfolds [src] into a drip stand."), span_notice("You unfold [src] into a drip stand."))
	qdel(src)

/**
 * Hospice blanket: tuck in a downed patient and they stop deteriorating
 * (no bleeding out, no creeping organ failure) and mend slowly, until they
 * move or the blanket comes off.
 *
 * Base: /obj/item/bedsheet/medical: reuses its existing "cover a lying mob"
 * interaction (coverup/on_pickup/smooth_sheets), including its built-in
 * "ends when the sleeper moves, or the sheet is picked up" cleanup hooks,
 * for free.
 *
 * Sprites: custom cream-wool art, 4 dirs, in uniques.dmi (the draped-over-a-
 * patient sprite, which is the one players actually look at) and uniques_worn.dmi
 * (worn on the neck slot, recoloured from the vanilla worn sheet so the body-zone
 * layout stays correct). The inhand stays the stock bedsheet inhand. undyeable is
 * set because /obj/item/proc/dye_item overwrites icon, icon_state, name and desc
 * wholesale from whatever plain bedsheet you dyed it to. A washing machine would
 * otherwise strip this thing back down to a white sheet.
 */
/obj/item/bedsheet/medical/hospice
	name = "hospice blanket"
	desc = "A wool blanket with the hospital corners ironed in permanently. Tuck a downed patient in and they'll stop getting worse."
	icon = 'voidcrew/modules/loot/icons/uniques.dmi'
	icon_state = "hospice_blanket"
	worn_icon = 'voidcrew/modules/loot/icons/uniques_worn.dmi'
	worn_icon_state = "hospice_blanket"
	undyeable = TRUE
	dream_messages = list("warmth", "a steady hand", "borrowed time")

/obj/item/bedsheet/medical/hospice/Initialize(mapload)
	. = ..()
	ADD_TRAIT(src, TRAIT_NO_REPLICATE, INNATE_TRAIT)

/obj/item/bedsheet/medical/hospice/Destroy()
	// Burned, shredded or admin-deleted mid-tuck: don't strand the patient in stasis.
	var/mob/living/tucked_in = signal_sleeper?.resolve()
	tucked_in?.remove_status_effect(/datum/status_effect/hospice_tuck)
	return ..()

/obj/item/bedsheet/medical/hospice/coverup(mob/living/sleeper)
	..()
	sleeper.apply_status_effect(/datum/status_effect/hospice_tuck)

/obj/item/bedsheet/medical/hospice/smooth_sheets(mob/living/sleeper)
	SIGNAL_HANDLER
	var/mob/living/tucked_in = sleeper
	..()
	tucked_in?.remove_status_effect(/datum/status_effect/hospice_tuck)

/obj/item/bedsheet/medical/hospice/on_pickup(datum/source, mob/grabber)
	SIGNAL_HANDLER
	var/mob/living/tucked_in = signal_sleeper?.resolve()
	..()
	tucked_in?.remove_status_effect(/datum/status_effect/hospice_tuck)

/// Soft stasis: halts deterioration (via TRAIT_STASIS) and applies a slow, minor heal. Ends on movement/uncovering (handled by the blanket, not here).
/datum/status_effect/hospice_tuck
	id = "hospice_tuck"
	duration = STATUS_EFFECT_PERMANENT
	tick_interval = 2 SECONDS
	status_type = STATUS_EFFECT_UNIQUE
	alert_type = null

/datum/status_effect/hospice_tuck/on_apply()
	. = ..()
	if(!.)
		return
	ADD_TRAIT(owner, TRAIT_STASIS, TRAIT_STATUS_EFFECT(id))

/datum/status_effect/hospice_tuck/on_remove()
	REMOVE_TRAIT(owner, TRAIT_STASIS, TRAIT_STATUS_EFFECT(id))

/datum/status_effect/hospice_tuck/tick(seconds_between_ticks)
	// The blanket normally ends this itself, but it can also be dragged, thrown or
	// deleted off the patient without ever firing those hooks. If nothing's covering
	// them any more, stop.
	var/turf/patient_turf = get_turf(owner)
	if(!patient_turf || !(locate(/obj/item/bedsheet/medical/hospice) in patient_turf))
		qdel(src)
		return
	var/mending = owner.getBruteLoss() || owner.getFireLoss()
	owner.adjustBruteLoss(-1 * seconds_between_ticks, updating_health = FALSE)
	owner.adjustFireLoss(-1 * seconds_between_ticks, updating_health = FALSE)
	owner.updatehealth()
	// Visible sign that the blanket is doing something - same pulse the lightgeist
	// and healing-touch effects use. Only while there's actually damage to mend.
	if(mending)
		new /obj/effect/temp_visual/heal(patient_turf, COLOR_HEALING_CYAN)

// =========================================================================
// RED
// =========================================================================

/**
 * The Meridian heart: holds one internal defib charge. Thirty seconds after
 * its owner dies, it fires on its own; recharges over 20 minutes of the owner
 * staying alive.
 *
 * Base: /obj/item/organ/heart/cybernetic (matches doc exactly). Revival
 * logic mirrors /obj/item/shockpaddles/proc/do_help's success branch
 * (code/game/objects/items/defib.dm), same health-redistribution math and
 * the same can_defib() gate, so DNR (TRAIT_SUICIDED), decapitation/no
 * brain, missing/failing heart, and blacklisting are all respected exactly
 * as they are for a normal defibrillator.
 *
 * Sprite: custom art in uniques.dmi. /obj/item/organ/heart/update_icon_state()
 * builds "[base_icon_state]-on" / "-off" off the beating flag, so both states
 * exist ("meridian_heart-on" is the 4-frame beat, "-off" is the stopped one).
 *
 * PLAYTEST FIX (2026-07-28), "1 hour recharge is crazy. do 20 minutes."
 * Recharge is now 20 minutes, and the item says so: the desc states the number,
 * examine prints the exact time left while it's charging, and the owner is told
 * the number when the charge is spent.
 */
/obj/item/organ/heart/cybernetic/meridian
	name = "Meridian heart"
	desc = "A cybernetic heart in a cold-chain crate, labeled DO NOT INSTALL IN STAFF. It carries one built-in defib charge that fires 30 seconds after its owner dies, then takes 20 minutes to recharge."
	icon = 'voidcrew/modules/loot/icons/uniques.dmi'
	icon_state = "meridian_heart-on"
	base_icon_state = "meridian_heart"
	/// Whether the internal defib charge is ready to fire.
	var/charge_available = TRUE
	/// How long the internal charge takes to come back after it fires.
	var/recharge_time = 20 MINUTES
	COOLDOWN_DECLARE(recharge_cd)

/obj/item/organ/heart/cybernetic/meridian/Initialize(mapload)
	. = ..()
	ADD_TRAIT(src, TRAIT_NO_REPLICATE, INNATE_TRAIT)

/obj/item/organ/heart/cybernetic/meridian/examine(mob/user)
	. = ..()
	if(charge_available)
		. += span_notice("The internal charge is ready. It fires 30 seconds after the owner dies.")
	else
		. += span_warning("The internal charge is spent. It recharges in [DisplayTimeText(COOLDOWN_TIMELEFT(src, recharge_cd))].")

/obj/item/organ/heart/cybernetic/meridian/on_life(seconds_per_tick, times_fired)
	. = ..()
	if(!charge_available && COOLDOWN_FINISHED(src, recharge_cd))
		charge_available = TRUE
		if(owner)
			to_chat(owner, span_notice("You feel a soft click in your chest. The Meridian heart is charged again."))

/obj/item/organ/heart/cybernetic/meridian/on_mob_insert(mob/living/carbon/organ_owner, special = FALSE, movement_flags)
	. = ..()
	RegisterSignal(organ_owner, COMSIG_MOB_STATCHANGE, PROC_REF(on_owner_statchange))

/obj/item/organ/heart/cybernetic/meridian/on_mob_remove(mob/living/carbon/organ_owner, special = FALSE, movement_flags)
	UnregisterSignal(organ_owner, COMSIG_MOB_STATCHANGE)
	return ..()

/obj/item/organ/heart/cybernetic/meridian/proc/on_owner_statchange(mob/living/carbon/source, new_stat, old_stat)
	SIGNAL_HANDLER
	if(new_stat != DEAD || !charge_available)
		return
	addtimer(CALLBACK(src, PROC_REF(attempt_revival), source), 30 SECONDS, TIMER_UNIQUE|TIMER_OVERRIDE)

/// Fires the internal charge, if the owner is still dead, still ours, and still defib-eligible.
/obj/item/organ/heart/cybernetic/meridian/proc/attempt_revival(mob/living/carbon/patient)
	if(QDELETED(src) || QDELETED(patient) || !charge_available)
		return
	if(owner != patient)
		return // heart isn't in them anymore
	if(patient.stat != DEAD)
		return // already handled some other way
	if(patient.can_defib() != DEFIB_POSSIBLE)
		return // DNR, decapitated/no brain, husk, blacklisted, etc - same gate a real defib respects

	charge_available = FALSE
	COOLDOWN_START(src, recharge_cd, recharge_time)

	playsound(patient, 'sound/machines/defib/defib_zap.ogg', 50, TRUE, -1)
	patient.visible_message(
		span_boldwarning("[patient] convulses as something inside [patient.p_their()] chest discharges!"),
		span_userdanger("Something inside your chest jolts, hard. You gasp back to life."),
	)
	to_chat(patient, span_notice("The Meridian heart is out of charge. It'll be ready again in 20 minutes."))

	// Same health redistribution as a normal defib "help" revival (defib.dm do_help()).
	var/target_health = (HEALTH_THRESHOLD_CRIT + HEALTH_THRESHOLD_DEAD) * 0.5
	var/total_brute = patient.getBruteLoss()
	var/total_burn = patient.getFireLoss()
	if(patient.health > target_health)
		patient.adjustOxyLoss(patient.health - target_health, updating_health = FALSE)
	else
		var/overall_damage = total_brute + total_burn + patient.getToxLoss() + patient.getOxyLoss()
		if(overall_damage > 0)
			var/mobhealth = patient.health
			patient.adjustOxyLoss((mobhealth - target_health) * (patient.getOxyLoss() / overall_damage), updating_health = FALSE)
			patient.adjustToxLoss((mobhealth - target_health) * (patient.getToxLoss() / overall_damage), updating_health = FALSE, forced = TRUE)
			patient.adjustFireLoss((mobhealth - target_health) * (total_burn / overall_damage), updating_health = FALSE)
			patient.adjustBruteLoss((mobhealth - target_health) * (total_brute / overall_damage), updating_health = FALSE)

	patient.updatehealth()
	patient.set_heartattack(FALSE)
	patient.grab_ghost()
	patient.revive()
	patient.emote("gasp")
	patient.set_jitter_if_lower(200 SECONDS)
	SEND_SIGNAL(patient, COMSIG_LIVING_MINOR_SHOCK)

/**
 * Winterkiss ampoule: one dose drops the subject into hard stasis where
 * they stand: frozen, untouchable, unhurtable, for exactly five minutes.
 *
 * Nests under /obj/item/reagent_containers/cup/tube so it inherits full,
 * working cup/syringe-draw behavior instead of hand-rolling the
 * reagent_containers base vars (deviation from the doc's bare
 * /obj/item/reagent_containers/winterkiss typepath).
 *
 * Sprite: custom art in uniques.dmi, two states - full and drained. The tube's
 * inherited fill_icon_thresholds are cleared, because those overlays come out of
 * icons/obj/medical/reagent_fillings.dmi and are drawn to fit the vanilla test
 * tube silhouette; the ampoule shows its contents through the icon state instead.
 *
 * The hard stasis reuses the real /datum/status_effect/grouped/stasis (the
 * same one the stasis bed uses) via a dedicated subtype with a fixed 5
 * MINUTE duration, plus TRAIT_GODMODE for the "unhurtable" part. On expiry
 * it grants a 1-minute TRAIT_WINTERKISS_IMMUNE window so the dose can't be
 * chain-reapplied to lock someone in stasis indefinitely.
 */
/obj/item/reagent_containers/cup/tube/winterkiss
	name = "Winterkiss ampoule"
	desc = "A frosted glass ampoule from the bottom of the cold-chain drawer. One dose freezes the patient where they stand for five minutes, safe from everything."
	icon = 'voidcrew/modules/loot/icons/uniques.dmi'
	icon_state = "winterkiss"
	fill_icon_thresholds = null
	volume = 15
	// The ampoule is one dose, so it pours all 15 by default; 5 is there for anyone
	// splitting it across syringes.
	amount_per_transfer_from_this = 15
	possible_transfer_amounts = list(5, 15)
	list_reagents = list(/datum/reagent/winterkiss = 15)

/obj/item/reagent_containers/cup/tube/winterkiss/Initialize(mapload)
	. = ..()
	ADD_TRAIT(src, TRAIT_NO_REPLICATE, INNATE_TRAIT)

/obj/item/reagent_containers/cup/tube/winterkiss/update_icon_state()
	// on_reagent_change() calls update_appearance() for us whenever it's drawn from.
	icon_state = reagents?.total_volume ? "winterkiss" : "winterkiss_empty"
	return ..()

/// One dose, injected any way (syringe, syringe gun, direct contact) triggers hard stasis on first metabolization tick.
/datum/reagent/winterkiss
	name = "Winterkiss"
	description = "A frosted, syrupy solution that drops the subject into a hard, protective stasis for five minutes."
	color = "#BFEFFF"
	taste_description = "bitter frost"
	metabolization_rate = 0.5 * REAGENTS_METABOLISM
	ph = 6.8
	/// Have we already fired for this dose? Prevents re-triggering every metabolism tick.
	var/triggered = FALSE

/datum/reagent/winterkiss/on_mob_life(mob/living/carbon/affected_mob, seconds_per_tick, times_fired)
	. = ..()
	if(triggered)
		return
	if(HAS_TRAIT(affected_mob, TRAIT_WINTERKISS_IMMUNE))
		return
	if(affected_mob.has_status_effect(/datum/status_effect/grouped/stasis/winterkiss))
		return
	triggered = TRUE
	affected_mob.visible_message(
		span_notice("[affected_mob] goes rigid and still, frost blooming faintly across [affected_mob.p_their()] skin."),
		span_notice("The cold spreads through you and you can't move a muscle."),
	)
	affected_mob.apply_status_effect(/datum/status_effect/grouped/stasis/winterkiss, REF(src))

/**
 * PLAYTEST FIX (2026-07-28), "when i click around and im stasis'd i can look
 * around (aka move what direction im facing)."
 *
 * The parent stasis effect adds TRAIT_IMMOBILIZED and TRAIT_HANDS_BLOCKED, which
 * kill arrow-key movement and item use, but neither one touches facing: clicking
 * a tile runs face_atom() -> setDir(), which nothing was blocking. Same fix the
 * unobserved_actor component uses for its "can't turn while watched" case, hook
 * COMSIG_ATOM_PRE_DIR_CHANGE and return COMPONENT_ATOM_BLOCK_DIR_CHANGE, which
 * /atom/proc/setDir checks before it does anything. Unregistered on removal, and
 * the registration lives on this datum, which is built fresh per application.
 */
/datum/status_effect/grouped/stasis/winterkiss
	id = "winterkiss_stasis"
	duration = 5 MINUTES

/datum/status_effect/grouped/stasis/winterkiss/on_apply()
	. = ..()
	if(!.)
		return
	ADD_TRAIT(owner, TRAIT_GODMODE, TRAIT_STATUS_EFFECT(id))
	RegisterSignal(owner, COMSIG_ATOM_PRE_DIR_CHANGE, PROC_REF(block_turning))

/// Frozen means frozen - no turning to face what you clicked on.
/datum/status_effect/grouped/stasis/winterkiss/proc/block_turning(atom/source, old_dir, new_dir)
	SIGNAL_HANDLER
	return COMPONENT_ATOM_BLOCK_DIR_CHANGE

/datum/status_effect/grouped/stasis/winterkiss/on_remove()
	UnregisterSignal(owner, COMSIG_ATOM_PRE_DIR_CHANGE)
	REMOVE_TRAIT(owner, TRAIT_GODMODE, TRAIT_STATUS_EFFECT(id))
	ADD_TRAIT(owner, TRAIT_WINTERKISS_IMMUNE, TRAIT_STATUS_EFFECT(id))
	addtimer(TRAIT_CALLBACK_REMOVE(owner, TRAIT_WINTERKISS_IMMUNE, TRAIT_STATUS_EFFECT(id)), 1 MINUTES)
	return ..()

/**
 * Lazarus line: one-use bypass revival for the long-dead: no defib window,
 * no husk complaints, no decay excuses. Still respects DNR (TRAIT_SUICIDED)
 * and decapitation (no brain to reach). The returned keep a permanent flatline
 * scar and take 10% more of everything, forever.
 *
 * Base: /obj/item/reagent_containers/syringe (matches doc exactly). This is
 * intentionally reagent-free and mechanical rather than reagent-triggered:
 * reagents only metabolize on living carbons (see
 * /datum/reagents/proc/metabolize), so a reagent payload can't reliably fire on
 * an already-dead target. The syringe instead performs the revival directly as
 * an item interaction, then permanently empties/spends itself.
 *
 * Sprite: custom art in uniques.dmi, one state for the loaded syringe and one
 * for the spent one. The parent's update_icon_state() drives icon_state off the
 * volume in the barrel ("[base_icon_state]_0/_5/_10/_15"), so this overrides it
 * afterwards and keeps base_icon_state on "syringe" - inhand_icon_state is built
 * from the same string and has to keep resolving inside the stock medical inhand
 * dmis. update_reagent_overlay() is dropped for the same reason: those fill
 * overlays are drawn to sit on the vanilla syringe silhouette.
 */
/obj/item/reagent_containers/syringe/lazarus_line
	name = "Lazarus line"
	desc = "One glass syringe in a velvet case. It'll bring back the long dead, once, and then it's finished."
	icon = 'voidcrew/modules/loot/icons/uniques.dmi'
	icon_state = "lazarus_line"
	volume = 5
	amount_per_transfer_from_this = 5
	possible_transfer_amounts = list()
	has_variable_transfer_amount = FALSE // one fixed dose, like the other single-use syringes
	/// Whether this syringe has already been used. One-shot only.
	var/spent = FALSE

/obj/item/reagent_containers/syringe/lazarus_line/Initialize(mapload)
	. = ..()
	ADD_TRAIT(src, TRAIT_NO_REPLICATE, INNATE_TRAIT)

/obj/item/reagent_containers/syringe/lazarus_line/update_icon_state()
	. = ..()
	icon_state = spent ? "lazarus_line_spent" : "lazarus_line"

/obj/item/reagent_containers/syringe/lazarus_line/update_reagent_overlay()
	return null

/obj/item/reagent_containers/syringe/lazarus_line/interact_with_atom(atom/target, mob/living/user, list/modifiers)
	if(spent)
		to_chat(user, span_warning("[src] is spent. There's nothing left in it."))
		return ITEM_INTERACT_BLOCKING
	if(!isliving(target) || !iscarbon(target))
		return ..()
	var/mob/living/carbon/patient = target
	if(patient.stat != DEAD)
		return ..()

	user.visible_message(
		span_notice("[user] presses [src] against [patient]'s chest..."),
		span_notice("You press [src] against [patient]'s chest and press down the plunger..."),
	)
	if(!do_after(user, 3 SECONDS, patient))
		return ITEM_INTERACT_BLOCKING
	if(spent)
		return ITEM_INTERACT_BLOCKING

	if(attempt_lazarus_revival(patient, user))
		spent = TRUE
		name = "spent Lazarus line"
		desc = "An empty glass syringe in a velvet case. Whatever was in it is gone."
		update_appearance(UPDATE_ICON)
	return ITEM_INTERACT_SUCCESS

/// The bypass revival itself. Returns TRUE on a successful revival.
/obj/item/reagent_containers/syringe/lazarus_line/proc/attempt_lazarus_revival(mob/living/carbon/target, mob/living/user)
	if(QDELETED(target) || target.stat != DEAD)
		return FALSE
	if(HAS_TRAIT(target, TRAIT_SUICIDED) || HAS_TRAIT(target, TRAIT_DEFIB_BLACKLISTED))
		to_chat(user, span_warning("Nothing in [target] responds. They don't want to come back."))
		return FALSE
	var/obj/item/organ/brain/target_brain = target.get_organ_slot(ORGAN_SLOT_BRAIN)
	if(!target_brain || (target_brain.organ_flags & ORGAN_FAILING))
		to_chat(user, span_warning("[target]'s brain is gone. There's nothing left to bring back."))
		return FALSE

	target.grab_ghost(force = TRUE)
	target.fully_heal(HEAL_ALL) // also cures husk, unconditionally - see /mob/living/proc/fully_heal
	target.revive(force_grab_ghost = TRUE)
	if(target.stat == DEAD)
		to_chat(user, span_warning("[target] convulses, then lies still. It didn't take."))
		return FALSE

	target.visible_message(
		span_boldnotice("[target] draws a sudden breath, alive again!"),
		span_boldnotice("You're alive again, and you feel worse for it."),
	)
	target.emote("gasp")
	apply_lazarus_fragility(target)
	return TRUE

/// Permanent +10% incoming brute/burn, plus a bespoke scar, marking a Lazarus revival.
/obj/item/reagent_containers/syringe/lazarus_line/proc/apply_lazarus_fragility(mob/living/carbon/target)
	to_chat(target, span_userdanger("Something in you feels thinner than it was. You'll take more damage from now on."))
	if(!ishuman(target))
		return
	var/mob/living/carbon/human/human_target = target
	human_target.physiology.brute_mod *= 1.1
	human_target.physiology.burn_mod *= 1.1

	var/obj/item/bodypart/chest_part = human_target.get_bodypart(BODY_ZONE_CHEST)
	if(!chest_part || !chest_part.scarrable)
		return
	var/datum/scar/flatline_scar = new()
	flatline_scar.load(
		chest_part,
		SCAR_CURRENT_VERSION,
		"a flatline scar",
		"sternum",
		WOUND_SEVERITY_SEVERE,
		BIO_STANDARD_UNJOINTED,
		human_target.mind?.original_character_slot_index,
		FALSE,
	)

#undef TRAIT_WINTERKISS_IMMUNE
