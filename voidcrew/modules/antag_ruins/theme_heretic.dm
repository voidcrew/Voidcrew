/**
 * # The Reliquary — heretic vestige
 *
 * A shrine ship parked in front of a door to the Mansus that never opened.
 * The scholar aboard transcribed at that threshold for a lifetime while the
 * rust — the door's toll, paid in iron — ate the ship around them. The trial
 * spreads that toll; the boons are clean heretic path spells (ash jaunt and
 * shadow cloak both ship with spell_requirements = NONE and no IS_HERETIC
 * check — verified against live code).
 */

// ===== PATRON =====

/mob/living/basic/vestige_patron/scrivener
	name = "the Scrivener"
	desc = "A robed figure at a lectern, quill still moving. The hand holding it rusted to the bone a long time ago, and kept writing anyway."
	gender = NEUTER
	outfit_path = /datum/outfit/job/curator
	appearance_tint = "#a06438"
	trial_types = list(
		/datum/vestige_trial/rite_of_rust,
	)
	boon_types = list(
		/datum/vestige_boon/spell/ashen_passage,
		/datum/vestige_boon/spell/cloak_of_shadow,
	)
	idle_lines = list(
		"The door never opened. I used to think that was the tragedy. Now I understand: the rust WAS the answer. I was being replied to the entire time.",
		"Every lock is a sentence. Rust is how iron confesses.",
		"I transcribed four hundred volumes waiting at that threshold. The ship read them before I did. Look what it learned.",
		"Do not pity the corroded. Rust is just metal, remembering it used to be earth.",
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

// ===== BOONS =====

// Both spells are "clean" heretic magic: spell_requirements = NONE upstream,
// no IS_HERETIC gate anywhere in their cast chain.
/datum/vestige_boon/spell/ashen_passage
	name = "Ashen Passage"
	desc = "Scatter into ash and drift through the walls between you and elsewhere. Brief, but walls are only ever a brief problem."
	grant_text = "Your edges loosen. Walls begin to look like suggestions."
	spell_type = /datum/action/cooldown/spell/jaunt/ethereal_jaunt/ash

/datum/vestige_boon/spell/cloak_of_shadow
	name = "Cloak of Shadow"
	desc = "Wrap yourself in a shroud of dark that hides your name and face from anyone watching. The dark keeps secrets better than any door."
	grant_text = "The shadows take your measurements without asking."
	spell_type = /datum/action/cooldown/spell/shadow_cloak
