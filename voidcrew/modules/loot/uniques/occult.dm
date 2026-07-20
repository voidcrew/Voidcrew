/**
 * # Occult uniques — the reliquary casket
 *
 * The six named prizes for `/obj/structure/closet/crate/zone_loot/occult/rare`
 * (see `voidcrew/modules/loot/zone_loot.dm`). Every item here is a subtype of
 * an existing, already-sprited item so no new DMI assets are required; see
 * the per-item comment for its sprite donor and any flavor liberties taken
 * to make that donor fit.
 *
 * Every unique in this file carries TRAIT_NO_REPLICATE (voidcrew/_DEFINES/loot.dm)
 * so future duplicators (e.g. the Helios pattern stamp) refuse to copy them.
 */

// =========================================================================
// Local trait-source / tuning defines. Undefined at the bottom of the file
// so they don't leak into the global namespace (see zone_loot.dm for the
// same convention).
// =========================================================================
/// Trait source key for the stasis pallbearer's gloves apply to a carried corpse
#define PALLBEARER_STASIS_TRAIT "pallbearer_gloves"
/// Trait source key for the pacification confessor's stole applies to a grab victim
#define CONFESSOR_STOLE_TRAIT "confessor_stole"
/// How far the censer scans for wildlife to keep the peace with
#define CENSER_SCAN_RANGE 7
/// How long the parish stays cross with you after you strike first
#define CENSER_PATIENCE_BREAK_DURATION (5 MINUTES)
/// Trait source key for the vow ring's TRAIT_NODROP
#define VOW_RING_TRAIT "vow_ring"
/// Max combined brute+burn a single Vow pull can move from partner to wearer
#define VOW_PULL_CAP 30
/// Cooldown between Vow pulls
#define VOW_PULL_COOLDOWN (30 SECONDS)
/// Max beasts a single Shepherd's crook can keep in its flock at once
#define CROOK_MAX_FLOCK 3

// =========================================================================
// GREEN — Widow's candle
// Subtypes /obj/item/flashlight/flare/candle (code/game/objects/items/devices/flashlight.dm)
// wholesale: icon, icon_state, inhand states, wax-level overlay logic all
// inherited verbatim. Only the ignition hook and a one-shot ghost prompt are
// new.
// =========================================================================

/**
 * Light it beside a corpse and, if their ghost is still lingering and has a
 * client, the game offers them one tgui_input_text prompt (30s timeout) to
 * speak through the flame. Whatever they type (if anything) is broadcast as
 * an audible_message from the candle, then the candle gutters out. One offer
 * per candle — if the ghost doesn't answer or isn't there, the candle stays
 * an ordinary candle from then on.
 */
/obj/item/flashlight/flare/candle/widows
	name = "widow's candle"
	desc = "A squat candle of gray wax. The wick was braided by someone patient."
	icon_state = "candle1"
	/// Has this candle already made its one offer to speak for the dead?
	var/last_words_spoken = FALSE

/obj/item/flashlight/flare/candle/widows/Initialize(mapload)
	. = ..()
	ADD_TRAIT(src, TRAIT_NO_REPLICATE, INNATE_TRAIT)

/obj/item/flashlight/flare/candle/widows/try_light_candle(obj/item/fire_starter, mob/user)
	. = ..()
	// SUCCESS is a define local to flashlight.dm; a lit wick after the parent
	// call is the same signal, and last_words_spoken keeps the offer one-shot
	if(light_on && !last_words_spoken)
		INVOKE_ASYNC(src, PROC_REF(offer_last_words))

/// Looks for a corpse within a tile of the candle and, if their ghost is
/// reachable, offers a single tgui text prompt to speak through the flame.
/obj/item/flashlight/flare/candle/widows/proc/offer_last_words()
	var/mob/living/departed
	for(var/mob/living/candidate in range(1, get_turf(src)))
		if(candidate.stat != DEAD)
			continue
		departed = candidate
		break
	if(!departed)
		return

	var/mob/dead/observer/ghost = departed.get_ghost(ghosts_with_clients = TRUE)
	if(!istype(ghost) || !ghost.client)
		return

	// Consumed here, before the (blocking) prompt: the offer is one-shot
	// whether or not they take it, matching "before the light gutters."
	last_words_spoken = TRUE
	to_chat(ghost, span_purple(span_italics("A candle gutters to life beside your body. For a moment, the wax feels warm enough to speak through.")))
	var/final_words = tgui_input_text(
		ghost,
		"Speak through the candle's flame? Anyone nearby will hear it. Leave blank to stay silent.",
		"Last Words",
		"",
		max_length = 200,
		timeout = 30 SECONDS,
	)
	if(QDELETED(src) || QDELETED(departed) || !final_words || !length(final_words))
		return

	src.audible_message(span_purple(span_italics("The candle gutters, and a voice drifts from the flame: \"[final_words]\"")))
	if(fuel != INFINITY || !can_be_extinguished)
		turn_off()

// =========================================================================
// GREEN — Pallbearer's gloves
// Subtypes /obj/item/clothing/gloves/color/black (code/modules/clothing/gloves/color.dm)
// verbatim for icon/icon_state/protection values.
// =========================================================================

/**
 * While worn: dragging or carrying anything doesn't slow the wearer down
 * (negates the game's normal "dragging a limp body" slowdown, not just for
 * corpses specifically — the gloves don't discriminate), and any corpse the
 * wearer is actively pulling is held in TRAIT_STASIS, which halts the
 * dead-metabolization/organ decay pass in Life() — i.e. it stops rotting
 * while in the wearer's care.
 *
 * Scope note: stasis is only applied/removed at the moment a pull starts or
 * stops. A living pull target who dies mid-drag isn't retroactively caught;
 * re-grabbing them (or a fresh pull) will.
 */
/obj/item/clothing/gloves/color/black/pallbearer
	name = "pallbearer's gloves"
	desc = "Black cotton gloves, worn thin at the palms. They've carried more than their share."
	/// The wearer's own slowed_by_drag value, saved so we can restore it exactly on removal
	var/restore_slowed_by_drag = TRUE
	/// Whether we're actually worn on the hands and negating drag right now —
	/// dropped() fires for hand-drops too, and must not "restore" anything then
	var/drag_negated = FALSE
	/// The corpse we've currently put into stasis for the wearer, if any
	var/mob/living/stasis_target

/obj/item/clothing/gloves/color/black/pallbearer/Initialize(mapload)
	. = ..()
	ADD_TRAIT(src, TRAIT_NO_REPLICATE, INNATE_TRAIT)

/obj/item/clothing/gloves/color/black/pallbearer/Destroy()
	release_stasis_target()
	return ..()

/obj/item/clothing/gloves/color/black/pallbearer/equipped(mob/living/user, slot, initial)
	. = ..()
	if(!(slot & ITEM_SLOT_GLOVES))
		return
	restore_slowed_by_drag = user.slowed_by_drag
	drag_negated = TRUE
	user.slowed_by_drag = FALSE
	user.update_pull_movespeed()
	RegisterSignal(user, COMSIG_ATOM_START_PULL, PROC_REF(on_start_pull))
	RegisterSignal(user, COMSIG_ATOM_NO_LONGER_PULLING, PROC_REF(on_stop_pulling))
	if(isliving(user.pulling))
		var/mob/living/already_pulling = user.pulling
		if(already_pulling.stat == DEAD)
			apply_stasis(already_pulling)

/obj/item/clothing/gloves/color/black/pallbearer/dropped(mob/living/user, silent = FALSE)
	. = ..()
	if(!drag_negated)
		return
	drag_negated = FALSE
	user.slowed_by_drag = restore_slowed_by_drag
	user.update_pull_movespeed()
	UnregisterSignal(user, list(COMSIG_ATOM_START_PULL, COMSIG_ATOM_NO_LONGER_PULLING))
	release_stasis_target()

/// Puts a freshly-grabbed corpse into stasis for as long as we're pulling it
/obj/item/clothing/gloves/color/black/pallbearer/proc/on_start_pull(mob/living/source, atom/movable/pulled_atom, state, force)
	SIGNAL_HANDLER
	release_stasis_target()
	if(!isliving(pulled_atom))
		return
	var/mob/living/corpse = pulled_atom
	if(corpse.stat == DEAD)
		apply_stasis(corpse)

/// Releases stasis the moment we stop pulling, regardless of why
/obj/item/clothing/gloves/color/black/pallbearer/proc/on_stop_pulling(mob/living/source, atom/movable/old_pulling)
	SIGNAL_HANDLER
	release_stasis_target()

/obj/item/clothing/gloves/color/black/pallbearer/proc/apply_stasis(mob/living/corpse)
	ADD_TRAIT(corpse, TRAIT_STASIS, PALLBEARER_STASIS_TRAIT)
	stasis_target = corpse

/obj/item/clothing/gloves/color/black/pallbearer/proc/release_stasis_target()
	if(!stasis_target)
		return
	if(!QDELETED(stasis_target))
		REMOVE_TRAIT(stasis_target, TRAIT_STASIS, PALLBEARER_STASIS_TRAIT)
	stasis_target = null

// =========================================================================
// YELLOW — Censer of the Quiet Parish
// Subtypes /obj/item/flashlight/lantern (code/game/objects/items/devices/flashlight.dm)
// for icon/icon_state/toggle behavior. Sprite deviation: it's a mining
// lantern, not a censer — see report for the acknowledged mismatch.
// =========================================================================

/**
 * While lit and worn on the belt: every non-megafauna hostile
 * /mob/living/basic fauna within CENSER_SCAN_RANGE has the wearer's ref
 * added to its own faction list (the same mechanism befriend()/lightgeist
 * use to make a specific mob stop treating a specific target as hostile —
 * see faction_check_atom, code/game/atoms_movable.dm), so it stops
 * initiating attacks on the wearer specifically. It re-scans every process
 * tick, so the truce follows whoever's actually nearby rather than being
 * permanent.
 *
 * If the wearer throws the first harm-intent hand or item attack at any
 * currently-peaceful fauna, the truce is revoked from everything at once and
 * the censer won't grant new peace for 5 minutes.
 *
 * Scope note: peace is scoped to /mob/living/basic (this fork's planet
 * fauna) and explicitly excludes ismegafauna() — a censer talking down a
 * megafauna boss felt like the wrong power level even though the doc didn't
 * name that exclusion for this item specifically.
 */
/obj/item/flashlight/lantern/censer_quiet_parish
	name = "censer of the quiet parish"
	desc = "A brass censer on a short chain, dented in a pattern suggesting it has been used as a censer and also not."
	icon = 'voidcrew/modules/loot/icons/uniques.dmi'
	icon_state = "censer"
	inhand_icon_state = null
	light_color = "#c9a768"
	/// Fauna we've currently granted peace to
	var/list/mob/living/basic/peaceful_fauna = list()
	/// world.time before which we refuse to grant new peace (parish is cross with you)
	var/patience_broken_until = 0
	/// Are we actively lit + belted right now?
	var/censer_active = FALSE
	/// The mob currently wearing us on their belt while lit, if any
	var/mob/living/current_wearer

/obj/item/flashlight/lantern/censer_quiet_parish/Initialize(mapload)
	. = ..()
	ADD_TRAIT(src, TRAIT_NO_REPLICATE, INNATE_TRAIT)

/obj/item/flashlight/lantern/censer_quiet_parish/Destroy()
	stop_incense()
	return ..()

/obj/item/flashlight/lantern/censer_quiet_parish/attack_self(mob/user)
	. = ..()
	refresh_state()

/obj/item/flashlight/lantern/censer_quiet_parish/equipped(mob/living/user, slot, initial)
	. = ..()
	refresh_state()

/obj/item/flashlight/lantern/censer_quiet_parish/dropped(mob/living/user, silent = FALSE)
	. = ..()
	refresh_state()

/// Figures out whether we should currently be keeping the peace (lit + on a belt) and starts/stops accordingly
/obj/item/flashlight/lantern/censer_quiet_parish/proc/refresh_state()
	// Destroy's unequip chain fires dropped() while the wearer still reads as
	// holding us belted+lit — without this guard the dying censer restarts itself
	if(QDELETED(src))
		return
	var/mob/living/wearer = ismob(loc) ? loc : null
	var/should_be_active = light_on && wearer && (wearer.get_item_by_slot(ITEM_SLOT_BELT) == src)
	if(should_be_active && !censer_active)
		start_incense(wearer)
	else if(!should_be_active && censer_active)
		stop_incense()

/obj/item/flashlight/lantern/censer_quiet_parish/proc/start_incense(mob/living/wearer)
	censer_active = TRUE
	current_wearer = wearer
	// COMSIG_MOB_ATTACK_HAND only fires human-vs-human (species attack_hand) —
	// it never fires for punching a basic-mob beast. LIVING_UNARMED_ATTACK
	// fires on every empty-hand click regardless of target, gated below.
	RegisterSignal(wearer, COMSIG_LIVING_UNARMED_ATTACK, PROC_REF(on_wearer_unarmed_attack))
	RegisterSignal(wearer, COMSIG_MOB_ITEM_ATTACK, PROC_REF(on_wearer_item_attack))
	START_PROCESSING(SSobj, src)

/obj/item/flashlight/lantern/censer_quiet_parish/proc/stop_incense()
	censer_active = FALSE
	STOP_PROCESSING(SSobj, src)
	end_all_peace()
	if(current_wearer)
		UnregisterSignal(current_wearer, list(COMSIG_LIVING_UNARMED_ATTACK, COMSIG_MOB_ITEM_ATTACK))
	current_wearer = null

/obj/item/flashlight/lantern/censer_quiet_parish/process(seconds_per_tick)
	if(!censer_active || QDELETED(current_wearer))
		stop_incense()
		return
	reconcile_peace()

/// Recomputes which nearby hostile fauna should currently be at peace with the wearer, granting/revoking as needed
/obj/item/flashlight/lantern/censer_quiet_parish/proc/reconcile_peace()
	var/list/currently_near = list()
	if(world.time >= patience_broken_until)
		for(var/mob/living/basic/fauna in range(CENSER_SCAN_RANGE, get_turf(current_wearer)))
			if(ismegafauna(fauna) || fauna.stat == DEAD)
				continue
			currently_near += fauna

	for(var/mob/living/basic/fauna as anything in peaceful_fauna)
		if(!(fauna in currently_near))
			revoke_peace(fauna)
	for(var/mob/living/basic/fauna as anything in currently_near)
		if(!(fauna in peaceful_fauna))
			grant_peace(fauna)

/obj/item/flashlight/lantern/censer_quiet_parish/proc/grant_peace(mob/living/basic/fauna)
	fauna.faction |= REF(current_wearer)
	peaceful_fauna += fauna
	RegisterSignal(fauna, COMSIG_QDELETING, PROC_REF(on_peaceful_fauna_gone))

/obj/item/flashlight/lantern/censer_quiet_parish/proc/revoke_peace(mob/living/basic/fauna)
	if(!QDELETED(fauna))
		fauna.faction -= REF(current_wearer)
		UnregisterSignal(fauna, COMSIG_QDELETING)
	peaceful_fauna -= fauna

/obj/item/flashlight/lantern/censer_quiet_parish/proc/end_all_peace()
	for(var/mob/living/basic/fauna as anything in peaceful_fauna.Copy())
		revoke_peace(fauna)

/obj/item/flashlight/lantern/censer_quiet_parish/proc/on_peaceful_fauna_gone(datum/source)
	SIGNAL_HANDLER
	peaceful_fauna -= source

/// The wearer threw an unarmed strike — check if it broke the parish's patience.
/// Combat-mode gated so a help-intent pat on a peaceful beast doesn't count.
/obj/item/flashlight/lantern/censer_quiet_parish/proc/on_wearer_unarmed_attack(mob/living/source, atom/target, proximity, list/modifiers)
	SIGNAL_HANDLER
	if(!source.combat_mode || !isliving(target))
		return
	check_patience_broken(target)

/// The wearer hit something with a held item — same patience check
/obj/item/flashlight/lantern/censer_quiet_parish/proc/on_wearer_item_attack(mob/living/source, mob/living/target, mob/living/user, list/modifiers, list/attack_modifiers)
	SIGNAL_HANDLER
	check_patience_broken(target)

/obj/item/flashlight/lantern/censer_quiet_parish/proc/check_patience_broken(mob/living/target)
	if(!(target in peaceful_fauna))
		return
	patience_broken_until = world.time + CENSER_PATIENCE_BREAK_DURATION
	end_all_peace()
	if(current_wearer)
		to_chat(current_wearer, span_warning("The parish's patience with you ends."))

// =========================================================================
// YELLOW — Confessor's stole
// Subtypes /obj/item/clothing/neck/scarf/purple (code/modules/clothing/neck/_neck.dm)
// for icon/icon_state/greyscale config; color re-tuned toward "gone gray"
// via the same greyscale system (not a new sprite).
// =========================================================================

/**
 * While worn: whoever the wearer holds in an aggressive-or-stronger grab
 * gets TRAIT_PACIFISM for the duration of that grab — they can't fight, but
 * they can still talk. Releasing the grab (or downgrading below aggressive,
 * or the wearer taking the stole off) lifts it immediately.
 */
/obj/item/clothing/neck/scarf/purple/confessor_stole
	name = "confessor's stole"
	desc = "A purple stole gone gray at the fold. It has heard everything and repeats none of it."
	greyscale_colors = "#6E6079#6E6079"
	/// Who we're currently pacifying, if anyone
	var/mob/living/confessed

/obj/item/clothing/neck/scarf/purple/confessor_stole/Initialize(mapload)
	. = ..()
	ADD_TRAIT(src, TRAIT_NO_REPLICATE, INNATE_TRAIT)

/obj/item/clothing/neck/scarf/purple/confessor_stole/Destroy()
	release_confession()
	return ..()

/obj/item/clothing/neck/scarf/purple/confessor_stole/equipped(mob/living/user, slot, initial)
	. = ..()
	if(!(slot & ITEM_SLOT_NECK))
		return
	RegisterSignal(user, COMSIG_MOVABLE_SET_GRAB_STATE, PROC_REF(on_wearer_grab_state))

/obj/item/clothing/neck/scarf/purple/confessor_stole/dropped(mob/living/user, silent = FALSE)
	. = ..()
	UnregisterSignal(user, COMSIG_MOVABLE_SET_GRAB_STATE)
	release_confession()

/// Fires whenever the wearer's own grab_state changes (grab_state and pulling live on the grabber, not the victim)
/obj/item/clothing/neck/scarf/purple/confessor_stole/proc/on_wearer_grab_state(mob/living/wearer, newstate)
	SIGNAL_HANDLER
	if(newstate < GRAB_AGGRESSIVE || !isliving(wearer.pulling))
		release_confession()
		return
	var/mob/living/target = wearer.pulling
	if(target == confessed)
		return
	release_confession()
	confessed = target
	ADD_TRAIT(confessed, TRAIT_PACIFISM, CONFESSOR_STOLE_TRAIT)
	to_chat(confessed, span_notice("Something in your captor's grip makes fighting seem pointless. You could talk, instead."))

/obj/item/clothing/neck/scarf/purple/confessor_stole/proc/release_confession()
	if(!confessed)
		return
	if(!QDELETED(confessed))
		REMOVE_TRAIT(confessed, TRAIT_PACIFISM, CONFESSOR_STOLE_TRAIT)
	confessed = null

// =========================================================================
// RED — The Vow (pair)
// Subtypes /obj/item/clothing/neck/beads (code/modules/clothing/neck/_neck.dm).
// Sprite/slot deviation: this codebase has no ring inventory slot, so the
// pair is reflavored as two iron rings threaded on a cord and worn at the
// throat rather than the finger — see report.
// =========================================================================

/**
 * Spawns as a linked pair (the second ring is created alongside the first,
 * weakref'd to each other). Once both rings are worn, either wearer can
 * click their own ring to speak the vow, which binds both: TRAIT_NODROP
 * goes on both rings, and clicking your ring afterward instead pulls a
 * capped amount of your partner's current brute/burn damage onto yourself
 * (cooldown-gated). Examining your own ring while bonded gives you a
 * direction/distance/health readout on your partner. The bond — and
 * TRAIT_NODROP — ends the moment either wearer dies (the funeral clause),
 * or if either wearer clicks their ring's secondary action to let go
 * (consent, from the only side that can actually act on it while both rings
 * are nodrop-locked).
 *
 * Scope note: "two willing wearers speak the vow" is simplified to "either
 * wearer speaks it once both rings are actually being worn" — a full
 * two-party handshake (both must separately confirm) would need extra
 * state and messaging beyond what the doc's balance knobs call for.
 */
/// Action button: speak the vow, or pull the partner's wounds once it's spoken.
/datum/action/item_action/vow_hold
	name = "Hold the Vow"
	desc = "Speak the vow with your ring's twin — or, once spoken, pull your partner's fresh wounds onto yourself."

/// Action button: voluntarily release the vow (the living consent path).
/datum/action/item_action/vow_release
	name = "Let Go of the Vow"
	desc = "Release the vow. Both rings loosen."

/obj/item/clothing/neck/beads/vow_ring
	name = "iron vow ring"
	desc = "A plain iron ring, threaded on a cord and worn at the throat. The inscription inside has worn smooth against its twin."
	icon = 'voidcrew/modules/loot/icons/uniques.dmi'
	icon_state = "vow_ring"
	worn_icon = 'voidcrew/modules/loot/icons/uniques_worn.dmi'
	worn_icon_state = "vow_ring"
	custom_materials = list(/datum/material/iron = SMALL_MATERIAL_AMOUNT * 0.5)
	// attack_self is unreachable for a worn (and, once vowed, NODROP-locked)
	// neck item — the action buttons are the only reliable activation path
	actions_types = list(/datum/action/item_action/vow_hold, /datum/action/item_action/vow_release)
	/// Weakref to our other half
	var/datum/weakref/partner_ref
	/// Who's currently wearing us, if anyone
	var/mob/living/bonded_wearer
	/// Has the vow actually been spoken (both rings bound) yet?
	var/vow_spoken = FALSE
	COOLDOWN_DECLARE(pull_cooldown)

/obj/item/clothing/neck/beads/vow_ring/Initialize(mapload, make_partner = TRUE)
	. = ..()
	ADD_TRAIT(src, TRAIT_NO_REPLICATE, INNATE_TRAIT)
	if(make_partner)
		var/obj/item/clothing/neck/beads/vow_ring/partner = new type(loc, FALSE)
		partner_ref = WEAKREF(partner)
		partner.partner_ref = WEAKREF(src)

/obj/item/clothing/neck/beads/vow_ring/Destroy()
	end_vow()
	partner_ref = null
	bonded_wearer = null
	return ..()

/obj/item/clothing/neck/beads/vow_ring/equipped(mob/living/user, slot, initial)
	. = ..()
	if(!(slot & ITEM_SLOT_NECK))
		return
	bonded_wearer = user
	RegisterSignal(user, COMSIG_LIVING_DEATH, PROC_REF(on_wearer_death))

/obj/item/clothing/neck/beads/vow_ring/dropped(mob/living/user, silent = FALSE)
	. = ..()
	UnregisterSignal(user, COMSIG_LIVING_DEATH)
	if(bonded_wearer == user)
		bonded_wearer = null
	// Normally unreachable while vow_spoken (TRAIT_NODROP blocks unequip),
	// but this is the safety net for forced removal.
	if(vow_spoken)
		end_vow()

/obj/item/clothing/neck/beads/vow_ring/examine(mob/user)
	. = ..()
	if(!vow_spoken || bonded_wearer != user)
		return
	var/obj/item/clothing/neck/beads/vow_ring/partner = partner_ref?.resolve()
	var/mob/living/other = partner?.bonded_wearer
	if(!other || QDELETED(other))
		. += span_notice("The vow has nothing left to hold onto.")
		return
	if(other.stat == DEAD)
		. += span_notice("You feel nothing from the other end. The vow waits on a funeral.")
		return
	var/dist = get_dist(user, other)
	var/dir_text = dir2text(get_dir(user, other))
	var/health_percent = other.maxHealth ? round((other.health / other.maxHealth) * 100) : 0
	. += span_notice("Through the vow, you feel [other] [dir_text ? "to the [dir_text], " : "right beside you, "][dist] tile\s away, at [health_percent]% health.")

/// Routes the two worn-slot action buttons; also reachable via attack_self in-hand pre-vow.
/obj/item/clothing/neck/beads/vow_ring/ui_action_click(mob/user, datum/action/action)
	if(bonded_wearer != user)
		balloon_alert(user, "wear it first!")
		return
	if(istype(action, /datum/action/item_action/vow_release))
		if(!vow_spoken)
			balloon_alert(user, "no vow to release")
			return
		to_chat(user, span_notice("You let go of the vow."))
		end_vow()
		return
	if(!vow_spoken)
		try_speak_vow(user)
		return
	try_pull_wound(user)

/// In-hand fallback for the pre-vow case (once vowed the ring is NODROP and only the buttons work)
/obj/item/clothing/neck/beads/vow_ring/attack_self(mob/user)
	if(bonded_wearer != user)
		return
	if(!vow_spoken)
		try_speak_vow(user)
		return
	try_pull_wound(user)

/obj/item/clothing/neck/beads/vow_ring/proc/try_speak_vow(mob/living/user)
	var/obj/item/clothing/neck/beads/vow_ring/partner = partner_ref?.resolve()
	if(!partner || QDELETED(partner) || !partner.bonded_wearer)
		to_chat(user, span_warning("[src] has no one to bind to yet."))
		return
	if(vow_spoken || partner.vow_spoken)
		return
	vow_spoken = TRUE
	partner.vow_spoken = TRUE
	ADD_TRAIT(src, TRAIT_NODROP, VOW_RING_TRAIT)
	ADD_TRAIT(partner, TRAIT_NODROP, VOW_RING_TRAIT)
	var/mob/living/other = partner.bonded_wearer
	user.visible_message(span_notice("[user] and [other] speak a quiet vow together."))
	to_chat(user, span_notice("You will always know where [other] is, and what it's costing them."))
	to_chat(other, span_notice("You will always know where [user] is, and what it's costing them."))

/obj/item/clothing/neck/beads/vow_ring/proc/try_pull_wound(mob/living/user)
	var/obj/item/clothing/neck/beads/vow_ring/partner = partner_ref?.resolve()
	var/mob/living/other = partner?.bonded_wearer
	if(!other || QDELETED(other))
		to_chat(user, span_warning("There's no one on the other end of the vow."))
		return
	if(!COOLDOWN_FINISHED(src, pull_cooldown))
		balloon_alert(user, "still theirs to bear")
		return
	if(other.stat == DEAD)
		to_chat(user, span_warning("[other] is beyond this."))
		return

	var/pulled = 0
	var/brute_pull = min(VOW_PULL_CAP, other.getBruteLoss())
	if(brute_pull > 0)
		other.adjustBruteLoss(-brute_pull, updating_health = TRUE)
		user.adjustBruteLoss(brute_pull, updating_health = TRUE)
		pulled += brute_pull

	var/remaining_cap = VOW_PULL_CAP - pulled
	if(remaining_cap > 0)
		var/burn_pull = min(remaining_cap, other.getFireLoss())
		if(burn_pull > 0)
			other.adjustFireLoss(-burn_pull, updating_health = TRUE)
			user.adjustFireLoss(burn_pull, updating_health = TRUE)
			pulled += burn_pull

	if(!pulled)
		to_chat(user, span_notice("There's nothing fresh to take from [other] right now."))
		return

	COOLDOWN_START(src, pull_cooldown, VOW_PULL_COOLDOWN)
	user.visible_message(span_notice("[user] flinches as [other]'s hurt becomes [user.p_their()] own."))
	to_chat(other, span_notice("A weight lifts, taken up by [user]."))

/// Funeral clause — either wearer dying ends the bond
/obj/item/clothing/neck/beads/vow_ring/proc/on_wearer_death(mob/living/source, gibbed)
	SIGNAL_HANDLER
	end_vow()

/obj/item/clothing/neck/beads/vow_ring/proc/end_vow()
	var/obj/item/clothing/neck/beads/vow_ring/partner = partner_ref?.resolve()
	if(vow_spoken)
		REMOVE_TRAIT(src, TRAIT_NODROP, VOW_RING_TRAIT)
	vow_spoken = FALSE
	if(partner && !QDELETED(partner))
		if(partner.vow_spoken)
			REMOVE_TRAIT(partner, TRAIT_NODROP, VOW_RING_TRAIT)
		partner.vow_spoken = FALSE

// =========================================================================
// RED — Shepherd's crook
// Subtypes /obj/item/cane (code/game/objects/items/weaponry.dm) verbatim for
// icon/icon_state/inhand states.
// =========================================================================

/**
 * A firm tap (melee hit) on a non-megafauna hostile /mob/living/basic beast
 * tames it instead of damaging it: befriend() + a full faction copy from the
 * wearer (the same trick this fork's own tamed goliaths and wolves use to
 * stop attacking their tamer — code/modules/mob/living/basic/lavaland/goliath/goliath.dm,
 * code/modules/mob/living/basic/icemoon/wolf/wolf.dm), plus the standard
 * obeys_commands component (follow + protect owner) if the beast has an
 * ai_controller. Up to CROOK_MAX_FLOCK beasts at once; one dying (or being
 * deleted) frees its slot. Megafauna — both /mob/living/simple_animal/hostile/megafauna
 * and this fork's /mob/living/basic/boss tier, per the ismegafauna() macro —
 * decline the tap outright: no taming, no damage, just a refusal.
 */
/obj/item/cane/shepherds_crook
	name = "shepherd's crook"
	desc = "A tall crook of black wood, smooth as a church rail. Flocks are a matter of perspective."
	/// The beasts currently following us
	var/list/mob/living/basic/flock = list()

/obj/item/cane/shepherds_crook/Initialize(mapload)
	. = ..()
	ADD_TRAIT(src, TRAIT_NO_REPLICATE, INNATE_TRAIT)

/obj/item/cane/shepherds_crook/Destroy()
	for(var/mob/living/basic/beast as anything in flock)
		UnregisterSignal(beast, list(COMSIG_LIVING_DEATH, COMSIG_QDELETING))
	flock = null
	return ..()

/obj/item/cane/shepherds_crook/attack(mob/living/target_mob, mob/living/user, list/modifiers, list/attack_modifiers)
	if(try_tame(target_mob, user))
		return TRUE
	return ..()

/// Returns TRUE if we handled the swing ourselves (taming attempt, success or not) — FALSE means "hit it normally"
/obj/item/cane/shepherds_crook/proc/try_tame(mob/living/target_mob, mob/living/user)
	if(!isliving(target_mob))
		return FALSE
	if(ismegafauna(target_mob))
		balloon_alert(user, "declines, firmly")
		to_chat(user, span_notice("[target_mob] declines the invitation. Firmly."))
		return TRUE
	if(!istype(target_mob, /mob/living/basic))
		return FALSE

	var/mob/living/basic/beast = target_mob
	if(beast.stat == DEAD)
		return FALSE
	if(beast in flock)
		balloon_alert(user, "already follows you")
		return TRUE
	if(beast.faction_check_atom(user))
		// Already friendly to us (someone else's pet, neutral critter, etc) — let a normal hit happen instead of pretending to tame it.
		return FALSE
	if(length(flock) >= CROOK_MAX_FLOCK)
		balloon_alert(user, "the flock is full")
		return TRUE

	if(beast.ai_controller)
		beast.AddComponent(/datum/component/obeys_commands, list(
			/datum/pet_command/idle,
			/datum/pet_command/free,
			/datum/pet_command/follow/start_active,
			/datum/pet_command/protect_owner,
		))
	beast.befriend(user)
	beast.faction = user.faction.Copy()

	flock += beast
	RegisterSignal(beast, COMSIG_LIVING_DEATH, PROC_REF(on_flock_member_death))
	RegisterSignal(beast, COMSIG_QDELETING, PROC_REF(on_flock_member_gone))
	user.visible_message(span_notice("[user] taps [beast] with [src], and it settles at [user.p_their()] side."))
	return TRUE

/obj/item/cane/shepherds_crook/proc/on_flock_member_death(mob/living/basic/source, gibbed)
	SIGNAL_HANDLER
	release_flock_member(source)

/obj/item/cane/shepherds_crook/proc/on_flock_member_gone(datum/source)
	SIGNAL_HANDLER
	release_flock_member(source)

/obj/item/cane/shepherds_crook/proc/release_flock_member(mob/living/basic/beast)
	if(!(beast in flock))
		return
	flock -= beast
	UnregisterSignal(beast, list(COMSIG_LIVING_DEATH, COMSIG_QDELETING))

#undef PALLBEARER_STASIS_TRAIT
#undef CONFESSOR_STOLE_TRAIT
#undef CENSER_SCAN_RANGE
#undef CENSER_PATIENCE_BREAK_DURATION
#undef VOW_RING_TRAIT
#undef VOW_PULL_CAP
#undef VOW_PULL_COOLDOWN
#undef CROOK_MAX_FLOCK
