/**
 * # The Reliquary — heretic vestige
 *
 * A shrine ship parked in front of a door to the Mansus that never opened.
 * The scholar aboard transcribed at that threshold for a lifetime while the
 * rust — the door's toll, paid in iron — ate the ship around them. The trials
 * are the Scrivener's own work, farmed out: spreading the rust, transcribing
 * locked doors, paying tolls; the boons are pages copied from the threshold: clean
 * heretic path spells granted directly where their cast chains carry no
 * IS_HERETIC gate (ash jaunt, ashen walk, shadow cloak — verified against
 * live code), and local ports where the upstream spell couples to the
 * heretic datum (the rusted grasp; see each spell's doc comment).
 */

// Tuning constants for the Scrivener's trials (file-local, #undef at bottom).
// The Rite of Rust's knob (VESTIGE_RUST_TURFS_NEEDED) lives in the shared defines.
/// Distinct locked doors the Rite of Transcription demands
#define VESTIGE_TRANSCRIBE_SENTENCES_NEEDED 6

// ===== PATRON =====

/mob/living/basic/vestige_patron/scrivener
	name = "the Scrivener"
	desc = "A robed figure at a lectern, quill still moving. The hand holding it rusted to the bone a long time ago, and kept writing anyway."
	gender = NEUTER
	outfit_path = /datum/outfit/job/curator
	appearance_tint = "#a06438"
	trial_types = list(
		/datum/vestige_trial/rite_of_rust,
		/datum/vestige_trial/rite_of_transcription,
		/datum/vestige_trial/rite_of_toll,
	)
	boon_types = list(
		/datum/vestige_boon/spell/ashen_passage,
		/datum/vestige_boon/spell/ashen_passage/walk,
		/datum/vestige_boon/spell/cloak_of_shadow,
		/datum/vestige_boon/spell/rusted_grasp,
		/datum/vestige_boon/spell/rusted_grasp/second_reading,
		/datum/vestige_boon/spell/iron_refusal,
	)
	idle_lines = list(
		"The door never opened. I used to think that was the tragedy. Now I understand: the rust WAS the answer. I was being replied to the entire time.",
		"Every lock is a sentence. Rust is how iron confesses.",
		"I transcribed four hundred volumes waiting at that threshold. The ship read them before I did. Look what it learned.",
		"Do not pity the corroded. Rust is just metal, remembering it used to be earth.",
		"Every threshold takes its toll. This ship paid in iron. I paid in years. The years, I promise you, are the heavier coin.",
	)
	accept_line = "Yes. Spread the reply. Let the iron confess."
	busy_line = "Your hand is already lent to another. I keep no palimpsests."
	fulfilled_line = "That page is written. I do not transcribe twice."
	renounce_line = "Blank pages burn just as well."
	claim_line = "Your annotation is owed. Collect it before you open a new volume."
	exhausted_line = "You have copied everything I kept. The rest belongs to the door."
	remember_line = "Death is an editor, not a censor. Your marginalia survived it."

// ===== RITE OF RUST =====

/datum/vestige_trial/rite_of_rust
	name = "Rite of Rust"
	// Keep the count in sync with VESTIGE_RUST_TURFS_NEEDED
	// (initial values must be constant, so no define interpolation here)
	desc = "Take the chrism. Anoint twenty surfaces — walls, floors, the Scrivener does not care whose — and let the rust read them. Everything opens eventually. Iron simply opens slowest."
	/// Surfaces successfully rusted so far
	var/turfs_rusted = 0

/datum/vestige_trial/rite_of_rust/on_accepted(mob/living/user)
	hand_over(user, new /obj/item/vestige_chrism(get_turf(user)))

/datum/vestige_trial/rite_of_rust/get_progress_text()
	return "The chrism has read [turfs_rusted] of [VESTIGE_RUST_TURFS_NEEDED] surfaces."

/// May complete (and delete) the trial
/datum/vestige_trial/rite_of_rust/proc/anoint()
	turfs_rusted++
	refresh_tracker()
	if(turfs_rusted >= VESTIGE_RUST_TURFS_NEEDED)
		complete()

/obj/item/vestige_chrism
	name = "corroding chrism"
	desc = "A flask of oil the colour of old blood. Whatever it touches starts remembering how to be dust."
	icon = 'icons/obj/drinks/bottles.dmi'
	icon_state = "holyflask"
	color = "#c46a33"
	w_class = WEIGHT_CLASS_SMALL

/obj/item/vestige_chrism/interact_with_atom(atom/interacting_with, mob/living/user, list/modifiers)
	if(!isturf(interacting_with))
		return NONE
	if(HAS_TRAIT(interacting_with, TRAIT_RUSTY))
		balloon_alert(user, "already read!")
		return ITEM_INTERACT_BLOCKING
	balloon_alert(user, "anointing...")
	if(!do_after(user, 2 SECONDS, interacting_with))
		return ITEM_INTERACT_BLOCKING
	interacting_with.rust_heretic_act()
	// Some turfs refuse the element (space, already-special turfs) — only credit a real conversion
	if(!HAS_TRAIT(interacting_with, TRAIT_RUSTY))
		balloon_alert(user, "it won't take!")
		return ITEM_INTERACT_BLOCKING
	user.visible_message(
		span_danger("[user] smears something dark across [interacting_with], and the rust follows [user.p_their()] hand."),
		span_notice("You anoint [interacting_with], and watch it start to confess."),
	)
	playsound(interacting_with, 'sound/effects/magic/curse.ogg', 25, TRUE)
	var/datum/vestige_trial/rite_of_rust/trial = user.mind?.active_vestige_trial
	if(istype(trial))
		trial.anoint()
	return ITEM_INTERACT_SUCCESS

// ===== RITE OF TRANSCRIPTION =====

/datum/vestige_trial/rite_of_transcription
	name = "Rite of Transcription"
	// Keep the count in sync with VESTIGE_TRANSCRIBE_SENTENCES_NEEDED
	// (initial values must be constant, so no define interpolation here)
	desc = "Take the quill. Find six doors that are shut against you — bolted, or barred to any hand without the proper badge — and hold it to each until the sentence comes through. Every lock is a sentence, and I will have them in fair copy. Mind the keepers: a door worth locking is always somebody's."
	/// Doors already transcribed (weakref -> TRUE), so no door is read twice
	var/list/transcribed = list()

/datum/vestige_trial/rite_of_transcription/on_accepted(mob/living/user)
	hand_over(user, new /obj/item/vestige_quill(get_turf(user)))
	to_chat(user, span_notice("The quill settles between your fingers nib-first, like something taking aim."))

/datum/vestige_trial/rite_of_transcription/get_progress_text()
	return "The quill has taken down [length(transcribed)] of [VESTIGE_TRANSCRIBE_SENTENCES_NEEDED] sentences."

/// May complete (and delete) the trial. Returns FALSE if this door was already transcribed.
/datum/vestige_trial/rite_of_transcription/proc/transcribe(obj/machinery/door/door)
	var/datum/weakref/key = WEAKREF(door)
	if(transcribed[key])
		return FALSE
	transcribed[key] = TRUE
	refresh_tracker()
	if(length(transcribed) >= VESTIGE_TRANSCRIBE_SENTENCES_NEEDED)
		complete()
	return TRUE

/obj/item/vestige_quill
	name = "rust-cut quill"
	desc = "A quill cut from no bird: a sliver of oxidized iron shaved fine enough to flex. It writes nothing of its own. It only takes dictation, and only from doors."
	icon = 'icons/obj/service/bureaucracy.dmi'
	icon_state = "feather"
	color = "#c46a33"
	w_class = WEIGHT_CLASS_TINY

/obj/item/vestige_quill/examine(mob/user)
	. = ..()
	. += span_notice("Held to a door that is shut against you — bolted, or barred behind an access lock — it takes the door's sentence down. Open doors, and doors that never refused anyone, have nothing to say.")

/obj/item/vestige_quill/interact_with_atom(atom/interacting_with, mob/living/user, list/modifiers)
	if(!istype(interacting_with, /obj/machinery/door))
		return NONE
	var/obj/machinery/door/door = interacting_with
	var/datum/vestige_trial/rite_of_transcription/trial = user.mind?.active_vestige_trial
	if(!istype(trial))
		balloon_alert(user, "the quill won't take your dictation!")
		return ITEM_INTERACT_BLOCKING
	// No pressing it to the vestige's own doors — those pages are the patron's, already written
	if(istype(get_area(door), /area/ruin/space/has_grav/vestige))
		balloon_alert(user, "already in the anthology!")
		return ITEM_INTERACT_BLOCKING
	if(trial.transcribed[WEAKREF(door)])
		balloon_alert(user, "already transcribed!")
		return ITEM_INTERACT_BLOCKING
	if(!has_sentence(door))
		balloon_alert(user, "no lock, no sentence!")
		return ITEM_INTERACT_BLOCKING
	// The reading is public: a stranger tracing a guarded door's seams looks exactly like what it is
	user.visible_message(
		span_warning("[user] presses [src] flat against [door] and begins tracing its seams."),
		span_notice("You press [src] to [door] and wait for the sentence to come through."),
	)
	playsound(door, 'sound/effects/page_turn/pageturn1.ogg', 40, TRUE)
	if(!do_after(user, 5 SECONDS, door)) // long enough for the door's keepers to take issue
		return ITEM_INTERACT_BLOCKING
	// Re-resolve; the pact may have been renounced mid-transcription
	trial = user.mind?.active_vestige_trial
	if(!istype(trial))
		return ITEM_INTERACT_BLOCKING
	// Opening the door mid-reading breaks the line — its keepers can foil the rite by simply using it
	if(!has_sentence(door))
		balloon_alert(user, "the sentence broke off!")
		return ITEM_INTERACT_BLOCKING
	if(!trial.transcribe(door))
		balloon_alert(user, "already transcribed!")
		return ITEM_INTERACT_BLOCKING
	user.visible_message(
		span_warning("A line of rust-red script crawls across [door] and fades."),
		span_notice("The sentence comes through: every refusal this door ever made, in fair copy."),
	)
	playsound(door, 'sound/effects/magic/curse.ogg', 25, TRUE)
	return ITEM_INTERACT_SUCCESS

/// A door has a sentence worth taking down while it stands shut against somebody: bolted, or access-restricted
/obj/item/vestige_quill/proc/has_sentence(obj/machinery/door/door)
	if(QDELETED(door) || !door.density)
		return FALSE
	return door.locked || !door.check_access(null)

// ===== RITE OF THE TOLL =====

/datum/vestige_trial/rite_of_toll
	name = "Rite of the Toll"
	// Keep the desc's "six" and its roll-call in sync with toll_instruments below
	// (initial values must be constant, so no define interpolation here)
	desc = "Every threshold takes a toll; this ship paid in iron, and I in years. Yours is lighter. Take the casket and feed it the six instruments of opening, no two alike — driver, wrench, cutters, prybar, torch, multitool — each one paid standing in some door's shadow. Openers are the only coin a threshold respects."
	/// Tool behaviours the toll accepts — the six instruments of opening
	var/list/toll_instruments = list(TOOL_SCREWDRIVER, TOOL_WRENCH, TOOL_WIRECUTTER, TOOL_CROWBAR, TOOL_WELDER, TOOL_MULTITOOL)
	/// Instruments already fed to the casket (tool behaviour -> TRUE) — duplicates are not payment
	var/list/instruments_paid = list()

/datum/vestige_trial/rite_of_toll/on_accepted(mob/living/user)
	hand_over(user, new /obj/item/vestige_toll_casket(get_turf(user)))

/datum/vestige_trial/rite_of_toll/get_progress_text()
	return "The toll stands at [length(instruments_paid)] of [length(toll_instruments)] instruments, no two alike."

/// May complete (and delete) the trial. Returns FALSE if this kind of instrument is not owed.
/datum/vestige_trial/rite_of_toll/proc/pay(instrument_kind)
	if(!(instrument_kind in toll_instruments) || instruments_paid[instrument_kind])
		return FALSE
	instruments_paid[instrument_kind] = TRUE
	refresh_tracker()
	if(length(instruments_paid) >= length(toll_instruments))
		complete()
	return TRUE

/obj/item/vestige_toll_casket
	name = "toll-casket"
	desc = "A lockbox with no key, no hinge, and no bottom you can find — only a slot. Whatever is on the far side of the slot is owed, and knows it."
	icon = 'icons/obj/storage/case.dmi'
	icon_state = "lockbox+l"
	color = "#c46a33"
	w_class = WEIGHT_CLASS_NORMAL

/obj/item/vestige_toll_casket/examine(mob/user)
	. = ..()
	. += span_notice("The slot takes tools — a screwdriver, a wrench, wirecutters, a crowbar, a welding tool and a multitool, one of each — and only within a step of a door. What goes in does not come back.")

/obj/item/vestige_toll_casket/item_interaction(mob/living/user, obj/item/tool, list/modifiers)
	if(!tool.tool_behaviour)
		return NONE
	var/datum/vestige_trial/rite_of_toll/trial = user.mind?.active_vestige_trial
	if(!istype(trial))
		balloon_alert(user, "the slot stays shut!")
		return ITEM_INTERACT_BLOCKING
	if(!(tool.tool_behaviour in trial.toll_instruments))
		balloon_alert(user, "not an instrument of opening!")
		return ITEM_INTERACT_BLOCKING
	if(trial.instruments_paid[tool.tool_behaviour])
		balloon_alert(user, "that coin is already paid!")
		return ITEM_INTERACT_BLOCKING
	if(!at_threshold())
		balloon_alert(user, "pay at a threshold!")
		return ITEM_INTERACT_BLOCKING
	// Paying is public: the toll is fed in doorways, where everyone walks
	user.visible_message(
		span_warning("[user] feeds [tool] into [src]'s slot..."),
		span_notice("You feed [tool] to the toll."),
	)
	if(!do_after(user, 3 SECONDS, src))
		return ITEM_INTERACT_BLOCKING
	// Re-run everything: the pact may have been renounced, the tool's mode toggled, the threshold left behind
	trial = user.mind?.active_vestige_trial
	if(!istype(trial) || !user.is_holding(tool) || !at_threshold())
		return ITEM_INTERACT_BLOCKING
	var/instrument_kind = tool.tool_behaviour
	if(!(instrument_kind in trial.toll_instruments) || trial.instruments_paid[instrument_kind])
		return ITEM_INTERACT_BLOCKING
	// Take the payment before crediting it — a tool that refuses to leave the hand pays nothing
	if(!user.temporarilyRemoveItemFromInventory(tool))
		balloon_alert(user, "it won't come free of you!")
		return ITEM_INTERACT_BLOCKING
	user.visible_message(
		span_warning("[src] grinds [tool] down into red filings, with a sound like a lock giving up."),
		span_notice("[src] takes [tool]. Somewhere on the far side of the slot, a tally is amended."),
	)
	playsound(src, 'sound/items/tools/welder.ogg', 50, TRUE)
	qdel(tool)
	trial.pay(instrument_kind) // may complete (and delete) the trial — nothing below may touch it
	return ITEM_INTERACT_SUCCESS

/// The toll is paid in a door's shadow: TRUE if any door stands within a step of the casket
/obj/item/vestige_toll_casket/proc/at_threshold()
	var/turf/here = get_turf(src)
	if(!here)
		return FALSE
	for(var/turf/nearby as anything in RANGE_TURFS(1, here))
		if(locate(/obj/machinery/door) in nearby)
			return TRUE
	return FALSE

// ===== BOONS =====

// The passage, the walk and the cloak are "clean" heretic magic used directly:
// spell_requirements = NONE upstream, no IS_HERETIC gate anywhere in their
// cast chains (the whole spell_types/jaunt/ module is antag-free — verified).
// The rust boons further down are local ports; each spell's doc comment
// records exactly what upstream coupling forced the copy.
/datum/vestige_boon/spell/ashen_passage
	name = "Ashen Passage"
	desc = "Scatter into ash and drift through the walls between you and elsewhere. Brief, but walls are only ever a brief problem."
	grant_text = "Your edges loosen. Walls begin to look like suggestions."
	spell_type = /datum/action/cooldown/spell/jaunt/ethereal_jaunt/ash

// The jaunt's own upstream upgrade (ethereal_jaunt/ash/long): identical clean
// cast chain, the drift simply holds for 5 seconds instead of 1.1.
/datum/vestige_boon/spell/ashen_passage/walk
	name = "Ashen Walk"
	desc = "The passage, unabridged. Drift as ash through wall after wall — not one line of the corridor but the whole page. Doors were only ever punctuation."
	grant_text = "The ash learns patience. Whole corridors begin to read as a single sentence."
	upgrades_from = /datum/vestige_boon/spell/ashen_passage
	spell_type = /datum/action/cooldown/spell/jaunt/ethereal_jaunt/ash/long

/datum/vestige_boon/spell/cloak_of_shadow
	name = "Cloak of Shadow"
	desc = "Wrap yourself in a shroud of dark that hides your name and face from anyone watching. The dark keeps secrets better than any door."
	grant_text = "The shadows take your measurements without asking."
	spell_type = /datum/action/cooldown/spell/shadow_cloak

/datum/vestige_boon/spell/rusted_grasp
	name = "Rusted Grasp"
	desc = "Lend your hand to the rust and let it read whatever you touch. The living are sapped and speak briefly in oxide; doors forget their locks for a minute; iron surfaces and machinery confess and corrode. Every reading leaves a mark."
	grant_text = "Red script settles into the creases of your palm. From now on, touching is reading."
	spell_type = /datum/action/cooldown/spell/touch/vestige_rusted_grasp

/datum/vestige_boon/spell/rusted_grasp/second_reading
	name = "Second Reading"
	desc = "Read the iron twice — the second reading is always deeper. Reinforced metal confesses, machines shed twice the filings, and the living buckle at the knees to listen. No margin survives a careful editor."
	grant_text = "The script on your palm rewrites itself: smaller, denser, twice-checked. Second editions correct the first."
	upgrades_from = /datum/vestige_boon/spell/rusted_grasp
	spell_type = /datum/action/cooldown/spell/touch/vestige_rusted_grasp/second_reading

/datum/vestige_boon/spell/iron_refusal
	name = "Iron Refusal"
	desc = "Any floor the rust has already read will stand up if you ask it to — a wall of rusted iron, raised mid-sentence, that knocks aside whoever presumed to stand there. Every door is a wall that learned manners."
	grant_text = "You learn the word a door says when it means no. Rusted floors have been waiting to hear it."
	spell_type = /datum/action/cooldown/spell/pointed/rust_construction/vestige

// ===== BOON SPELLS =====

/**
 * A rust-fist in the Scrivener's style, standing in for the Mansus grasp. The
 * upstream grasp is hard-coupled — its can_cast_spell demands IS_HERETIC or
 * IS_LUNATIC, and all of its interesting effects ride heretic knowledge
 * signals — so this is a fresh touch spell on the same chassis (the touch
 * base class in _touch.dm carries no antag checks — verified).
 *
 * One hand, four confessions, all tuned below the antag original (which
 * deals 80 stamina plus a 5-second knockdown on a 10-second loop):
 * - the living: a stamina sap and a rusted tongue; no knockdown at this tier
 * - airlocks: loseMainPower — ~60 seconds without power, pryable meanwhile
 * - machines and structures: moderate corrosion damage, deliberately far
 *   below the flat 500 the heretic rust_heretic_act deals to machinery
 * - walls and floors: a single aimed turf rusted, the same strength-1 act
 *   as the trial chrism — no sprawling spread to eat a ship with
 */
/datum/action/cooldown/spell/touch/vestige_rusted_grasp
	name = "Rusted Grasp"
	desc = "A touch that saps the living, depowers airlocks for a minute, corrodes machines and structures, and rusts basic walls and floors."
	button_icon = 'icons/mob/actions/actions_ecult.dmi'
	button_icon_state = "mansus_grasp"
	background_icon_state = "bg_heretic"
	overlay_icon_state = "bg_heretic_border"
	sound = 'sound/items/tools/welder.ogg'
	school = SCHOOL_FORBIDDEN
	cooldown_time = 16 SECONDS
	invocation_type = INVOCATION_NONE
	spell_requirements = SPELL_REQUIRES_NO_ANTIMAGIC
	antimagic_flags = MAGIC_RESISTANCE | MAGIC_RESISTANCE_HOLY
	hand_path = /obj/item/melee/touch_attack/vestige_rust
	/// Strength passed to rust_heretic_act — 1 reads basic iron, 2 (the second reading) reads reinforced
	var/rust_strength = 1
	/// Stamina sapped from living victims
	var/stamina_sap = 50
	/// Brute dealt to machines and structures
	var/corrosion_damage = 60
	/// Knockdown applied to living victims — 0 until the second reading
	var/knockdown_time = 0

/**
 * The second reading: mastery, not arithmetic. The loop tightens, the rust
 * learns reinforced iron, and the living buckle for a moment — still well
 * short of the antag grasp's 5-second drop.
 */
/datum/action/cooldown/spell/touch/vestige_rusted_grasp/second_reading
	name = "Second Reading"
	desc = "A touch that saps and briefly downs the living, depowers airlocks for a minute, heavily corrodes machines, and rusts even reinforced walls and floors."
	button_icon_state = "corrode"
	cooldown_time = 10 SECONDS
	rust_strength = 2
	stamina_sap = 70
	corrosion_damage = 90
	knockdown_time = 1.5 SECONDS

/datum/action/cooldown/spell/touch/vestige_rusted_grasp/is_valid_target(atom/cast_on)
	return TRUE // sorting out what the rust can and cannot read happens on hit

/datum/action/cooldown/spell/touch/vestige_rusted_grasp/on_antimagic_triggered(obj/item/melee/touch_attack/hand, atom/victim, mob/living/carbon/caster)
	victim.visible_message(
		span_danger("The rust recoils from [victim], unread!"),
		span_danger("The rust recoils from you, unread!"),
	)

/datum/action/cooldown/spell/touch/vestige_rusted_grasp/cast_on_hand_hit(obj/item/melee/touch_attack/hand, atom/victim, mob/living/carbon/caster)
	if(isliving(victim))
		return grasp_living(victim, caster)
	if(istype(victim, /obj/machinery/door/airlock))
		return grasp_airlock(victim, caster)
	if(isturf(victim))
		return grasp_turf(victim, caster)
	if(ismachinery(victim) || isstructure(victim))
		return grasp_object(victim, caster)
	caster.balloon_alert(caster, "nothing to read!")
	return FALSE // no confession in it — keep the hand

/// The living confess in stamina: a sap, a rusted tongue, and (once upgraded) buckled knees
/datum/action/cooldown/spell/touch/vestige_rusted_grasp/proc/grasp_living(mob/living/victim, mob/living/carbon/caster)
	victim.apply_damage(stamina_sap, STAMINA)
	victim.adjust_timed_status_effect(4 SECONDS, /datum/status_effect/speech/slurring/heretic)
	if(knockdown_time)
		victim.Knockdown(knockdown_time)
	victim.visible_message(
		span_danger("[caster]'s rusted hand closes on [victim], and the strength runs out of [victim.p_them()] like filings!"),
		span_userdanger("A rusted grip closes on you, and your strength runs out like filings!"),
	)
	playsound(victim, 'sound/effects/magic/curse.ogg', 40, TRUE)
	return TRUE

/// Doors confess their wiring: loseMainPower cuts the lock for ~a minute, prying allowed meanwhile
/datum/action/cooldown/spell/touch/vestige_rusted_grasp/proc/grasp_airlock(obj/machinery/door/airlock/lock, mob/living/carbon/caster)
	lock.loseMainPower()
	do_sparks(3, FALSE, lock)
	lock.visible_message(span_danger("Rust crawls into the seams of [lock], and its lights gutter out!"))
	lock.balloon_alert(caster, "the lock forgets")
	playsound(lock, 'sound/items/tools/welder.ogg', 50, TRUE)
	return TRUE

/// Surfaces confess to having been earth: the same aimed single-turf rust act as the trial chrism
/datum/action/cooldown/spell/touch/vestige_rusted_grasp/proc/grasp_turf(turf/surface, mob/living/carbon/caster)
	if(HAS_TRAIT(surface, TRAIT_RUSTY))
		caster.balloon_alert(caster, "already read!")
		return FALSE
	surface.rust_heretic_act(rust_strength)
	// Titanium and special turfs refuse the reading — keep the hand rather than waste it
	if(!HAS_TRAIT(surface, TRAIT_RUSTY))
		caster.balloon_alert(caster, "it won't take!")
		return FALSE
	surface.visible_message(span_danger("Rust spreads out from [caster]'s palm across [surface]."))
	playsound(surface, 'sound/effects/magic/curse.ogg', 25, TRUE)
	return TRUE

/// Machines and structures confess in filings: real corrosion damage, tuned far below the heretic act's flat 500
/datum/action/cooldown/spell/touch/vestige_rusted_grasp/proc/grasp_object(obj/target, mob/living/carbon/caster)
	target.take_damage(corrosion_damage, BRUTE, MELEE, TRUE)
	target.visible_message(span_danger("[target] corrodes under [caster]'s rusted grip!"))
	playsound(target, 'sound/items/tools/welder.ogg', 50, TRUE)
	return TRUE

/obj/item/melee/touch_attack/vestige_rust
	name = "rusted grasp"
	desc = "A hand the colour of old blood and older iron. Whatever it touches next is going to confess."
	icon_state = "mansus"
	inhand_icon_state = "mansus"
	color = "#c46a33" // the chrism's oxide, moved into the palm

/**
 * Rust Formation, re-covenanted. The upstream spell is requirement-free
 * (spell_requirements = NONE, no IS_HERETIC anywhere in the raise-a-wall
 * path), but its cast-at-a-wall branch routes through do_rust_heretic_act,
 * which resolves a null rust_strength for anyone without a heretic datum and
 * silently does nothing. This subtype refuses closed turfs up front so every
 * cast takes the branch that actually works for a plain crewman, adds the
 * standard antimagic hooks, and slows the heretic's 8-second loop down to
 * something a whole crew can be trusted with.
 */
/datum/action/cooldown/spell/pointed/rust_construction/vestige
	name = "Iron Refusal"
	desc = "Command a rusted floor to stand up as a wall of rusted iron. Anyone on it is knocked aside as it rises."
	background_icon_state = "bg_heretic"
	overlay_icon_state = "bg_heretic_border"
	cooldown_time = 20 SECONDS
	spell_requirements = SPELL_REQUIRES_NO_ANTIMAGIC
	antimagic_flags = MAGIC_RESISTANCE | MAGIC_RESISTANCE_HOLY

/datum/action/cooldown/spell/pointed/rust_construction/vestige/is_valid_target(atom/cast_on)
	// The parent would crumble closed turfs through the heretic-only path — refuse them up front
	if(isclosedturf(cast_on))
		if(owner)
			cast_on.balloon_alert(owner, "already standing!")
		return FALSE
	return ..()

#undef VESTIGE_TRANSCRIBE_SENTENCES_NEEDED
