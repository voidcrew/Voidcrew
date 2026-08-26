/**
 * # Occult uniques: the reliquary casket
 *
 * The six named prizes for `loot_uniques` on /datum/loot_theme/occult
 * (see `voidcrew/modules/loot/zone_loot.dm`). Each item subtypes an existing
 * item for its behavior; the candle, gloves and crook carry custom sprites in
 * `voidcrew/modules/loot/icons/uniques.dmi` (plus a worn glove state in
 * `uniques_worn.dmi`), and the rest inherit their donor's sprite (see the)
 * per-item comment for which, and for any flavor liberties taken.
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
/// Blocker bit the gloves hand to /datum/component/rot to pause bodily rot.
/// That component's own blockers are bits 0-2 (code/datums/components/rot.dm), so bit 3 is ours alone.
#define PALLBEARER_ROT_BLOCKER (1 << 3)
/// Trait source key for the pacification confessor's stole applies to whoever it's pulling
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
/// Cooldown between taming taps with the crook
#define CROOK_TAME_COOLDOWN (5 SECONDS)

// =========================================================================
// GREEN: Widow's candle
// Subtypes /obj/item/flashlight/flare/candle (code/game/objects/items/devices/flashlight.dm)
// for its fuel/wax-level/ignition behavior. Custom sprites live in
// uniques.dmi as widow_candle1/2/3 plus a lit (3-frame flicker) state for
// each wax level, so every state the parent's update_icon_state can ask for
// exists. Inhand states stay the vanilla candle ones.
// =========================================================================

/**
 * Light it beside a corpse and, if their ghost is still lingering and has a
 * client, the game offers them one tgui_input_text prompt (30s timeout) to
 * speak through the flame. Whatever they type (if anything) is broadcast as
 * an audible_message from the candle, then the candle gutters out. One offer
 * per candle, if the ghost doesn't answer or isn't there, the candle stays
 * an ordinary candle from then on.
 */
/obj/item/flashlight/flare/candle/widows
	name = "widow's candle"
	desc = "A candle of gray wax with a plain cotton wick. Light it beside a corpse and the dead get one last chance to speak."
	icon = 'voidcrew/modules/loot/icons/uniques.dmi'
	icon_state = "widow_candle1"
	/// Has this candle already made its one offer to speak for the dead?
	var/last_words_spoken = FALSE

/obj/item/flashlight/flare/candle/widows/Initialize(mapload)
	. = ..()
	ADD_TRAIT(src, TRAIT_NO_REPLICATE, INNATE_TRAIT)

/// The parent points icon_state at the vanilla candle states; swap in ours.
/// Runs after the parent so its inhand_icon_state assignment (a vanilla state
/// in items_lefthand/righthand.dmi, which we don't override) still stands.
/obj/item/flashlight/flare/candle/widows/update_icon_state()
	. = ..()
	icon_state = "widow_candle[current_wax_level][light_on ? "_lit" : ""]"

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
	to_chat(ghost, span_purple(span_italics("Someone lit a candle next to your body. You have 30 seconds to say one last thing through it.")))
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

	src.audible_message(span_purple(span_italics("The flame dips, and a voice comes out of it: \"[final_words]\"")))
	if(fuel != INFINITY || !can_be_extinguished)
		turn_off()

// =========================================================================
// GREEN: Pallbearer's gloves
// Subtypes /obj/item/clothing/gloves/color/black (code/modules/clothing/gloves/color.dm)
// for its protection values; icon/worn_icon are custom states in uniques.dmi
// and uniques_worn.dmi. The parent's greyscale setup only feeds the inhand
// sprites, so overriding icon/icon_state here is safe.
// =========================================================================

/**
 * While worn: dragging or carrying anything doesn't slow the wearer down
 * (negates the game's normal "dragging a limp body" slowdown, not just for
 * corpses specifically, the gloves don't discriminate), and any corpse the
 * wearer is dragging or fireman-carrying is held out of decay until they let
 * go of it.
 *
 * "Held out of decay" means both of the game's corpse decay paths at once:
 * - TRAIT_STASIS, which makes /mob/living/carbon/Life() skip handle_organs(),
 *   the pass that runs organ decay on a dead body (code/modules/mob/living/carbon/life.dm).
 * - /datum/component/rot paused via its own rest()/start_up() blocker system,
 *   which is what actually rots a body and hands out diseases on contact. It
 *   runs off world.time, not Life(), so TRAIT_STASIS alone does nothing to it.
 *   rest() banks the elapsed time, so a body picked up and put down repeatedly
 *   doesn't lose or gain rot progress.
 *
 * Every mob the wearer is dragging or carrying is watched for death, revival
 * and deletion, so someone who dies mid-drag is caught without re-grabbing
 * them, and someone revived mid-drag comes straight back out of stasis.
 */
/obj/item/clothing/gloves/color/black/pallbearer
	name = "pallbearer's gloves"
	desc = "Black cotton gloves, worn thin at the palms. Nothing you drag slows you down, and any corpse you're dragging or carrying stops decaying until you let go."
	icon = 'voidcrew/modules/loot/icons/uniques.dmi'
	icon_state = "pallbearer_gloves"
	worn_icon = 'voidcrew/modules/loot/icons/uniques_worn.dmi'
	worn_icon_state = "pallbearer_gloves"
	/// The wearer's own slowed_by_drag value, saved so we can restore it exactly on removal
	var/restore_slowed_by_drag = TRUE
	/// Whether we're actually worn on the hands and negating drag right now,
	/// dropped() fires for hand-drops too, and must not "restore" anything then
	var/drag_negated = FALSE
	/// Who's wearing us on their hands, if anyone
	var/mob/living/current_wearer
	/// Every mob the wearer is currently dragging or carrying, dead or alive. We hold death/revive/deletion hooks on all of them
	var/list/mob/living/watched = list()
	/// The subset of watched that is dead and currently held out of decay
	var/list/mob/living/preserved = list()

/obj/item/clothing/gloves/color/black/pallbearer/Initialize(mapload)
	. = ..()
	ADD_TRAIT(src, TRAIT_NO_REPLICATE, INNATE_TRAIT)

/obj/item/clothing/gloves/color/black/pallbearer/Destroy()
	unwatch_all()
	current_wearer = null
	return ..()

/obj/item/clothing/gloves/color/black/pallbearer/equipped(mob/living/user, slot, initial)
	. = ..()
	if(!(slot & ITEM_SLOT_GLOVES))
		return
	current_wearer = user
	restore_slowed_by_drag = user.slowed_by_drag
	drag_negated = TRUE
	user.slowed_by_drag = FALSE
	user.update_pull_movespeed()
	// /mob/living/start_pulling doesn't call its /atom/movable parent, so
	// COMSIG_ATOM_START_PULL never fires for a person pulling something,
	// COMSIG_LIVING_START_PULL is the one that does (code/modules/mob/living/living.dm).
	// The buckle pair covers fireman carries.
	RegisterSignals(user, list(
		COMSIG_LIVING_START_PULL,
		COMSIG_ATOM_NO_LONGER_PULLING,
		COMSIG_MOVABLE_BUCKLE,
		COMSIG_MOVABLE_UNBUCKLE,
	), PROC_REF(on_load_changed))
	refresh_pallbearing()

/obj/item/clothing/gloves/color/black/pallbearer/dropped(mob/living/user, silent = FALSE)
	. = ..()
	if(!drag_negated)
		return
	drag_negated = FALSE
	user.slowed_by_drag = restore_slowed_by_drag
	user.update_pull_movespeed()
	UnregisterSignal(user, list(
		COMSIG_LIVING_START_PULL,
		COMSIG_ATOM_NO_LONGER_PULLING,
		COMSIG_MOVABLE_BUCKLE,
		COMSIG_MOVABLE_UNBUCKLE,
	))
	current_wearer = null
	unwatch_all()

/// The wearer picked something up, put something down, or swapped what they're dragging
/obj/item/clothing/gloves/color/black/pallbearer/proc/on_load_changed(datum/source)
	SIGNAL_HANDLER
	refresh_pallbearing()

/// Recomputes who we should be preserving right now: whatever the wearer is dragging, plus anyone they're carrying
/obj/item/clothing/gloves/color/black/pallbearer/proc/refresh_pallbearing()
	var/list/mob/living/carrying = list()
	if(current_wearer && !QDELETED(current_wearer))
		if(isliving(current_wearer.pulling))
			carrying += current_wearer.pulling
		for(var/mob/living/rider in current_wearer.buckled_mobs)
			carrying |= rider
	for(var/mob/living/let_go as anything in watched - carrying)
		unwatch(let_go)
	for(var/mob/living/held as anything in carrying)
		if(!(held in watched))
			watch(held)
		if(held.stat == DEAD)
			begin_preserving(held)
		else
			stop_preserving(held)

/// Starts tracking a mob the wearer has hold of, alive or dead
/obj/item/clothing/gloves/color/black/pallbearer/proc/watch(mob/living/held)
	watched |= held
	RegisterSignals(held, list(COMSIG_LIVING_DEATH, COMSIG_LIVING_REVIVE), PROC_REF(on_held_state_changed), override = TRUE)
	RegisterSignal(held, COMSIG_QDELETING, PROC_REF(on_held_deleted), override = TRUE)

/obj/item/clothing/gloves/color/black/pallbearer/proc/unwatch(mob/living/held)
	stop_preserving(held)
	watched -= held
	if(!QDELETED(held))
		UnregisterSignal(held, list(COMSIG_LIVING_DEATH, COMSIG_LIVING_REVIVE, COMSIG_QDELETING))

/obj/item/clothing/gloves/color/black/pallbearer/proc/unwatch_all()
	for(var/mob/living/held as anything in watched.Copy())
		unwatch(held)

/// Someone we're carrying just died or came back. Recheck whether they should be preserved
/obj/item/clothing/gloves/color/black/pallbearer/proc/on_held_state_changed(mob/living/source)
	SIGNAL_HANDLER
	refresh_pallbearing()

/obj/item/clothing/gloves/color/black/pallbearer/proc/on_held_deleted(datum/source)
	SIGNAL_HANDLER
	watched -= source
	preserved -= source

/// Stops both decay paths on a corpse for as long as the wearer has hold of it
/obj/item/clothing/gloves/color/black/pallbearer/proc/begin_preserving(mob/living/corpse)
	if(corpse in preserved)
		return
	preserved += corpse
	ADD_TRAIT(corpse, TRAIT_STASIS, PALLBEARER_STASIS_TRAIT)
	var/datum/component/rot/decay = corpse.GetComponent(/datum/component/rot)
	decay?.rest(PALLBEARER_ROT_BLOCKER)
	if(current_wearer)
		to_chat(current_wearer, span_notice("[corpse] stops decaying while you've got hold of [corpse.p_them()]."))

/obj/item/clothing/gloves/color/black/pallbearer/proc/stop_preserving(mob/living/corpse)
	if(!(corpse in preserved))
		return
	preserved -= corpse
	if(QDELETED(corpse))
		return
	REMOVE_TRAIT(corpse, TRAIT_STASIS, PALLBEARER_STASIS_TRAIT)
	// re-fetched rather than cached: reviving the mob deletes its rot component
	var/datum/component/rot/decay = corpse.GetComponent(/datum/component/rot)
	decay?.start_up(PALLBEARER_ROT_BLOCKER)

// =========================================================================
// YELLOW: Censer of the Quiet Parish
// Subtypes /obj/item/flashlight/lantern (code/game/objects/items/devices/flashlight.dm)
// for icon/icon_state/toggle behavior. Sprite deviation: it's a mining
// lantern, not a censer, see report for the acknowledged mismatch.
// =========================================================================

/**
 * While lit and worn on the belt: every non-megafauna hostile
 * /mob/living/basic fauna within CENSER_SCAN_RANGE has the wearer's ref
 * added to its own faction list (the same mechanism befriend()/lightgeist
 * use to make a specific mob stop treating a specific target as hostile.
 * See faction_check_atom, code/game/atoms_movable.dm), so it stops
 * initiating attacks on the wearer specifically. It re-scans every process
 * tick, so the truce follows whoever's actually nearby rather than being
 * permanent.
 *
 * If the wearer throws the first harm-intent hand or item attack at any
 * currently-peaceful fauna, the truce is revoked from everything at once and
 * the censer won't grant new peace for 5 minutes.
 *
 * Scope note: peace is scoped to /mob/living/basic (this fork's planet
 * fauna) and explicitly excludes ismegafauna(), a censer talking down a
 * megafauna boss felt like the wrong power level even though the doc didn't
 * name that exclusion for this item specifically.
 */
/obj/item/flashlight/lantern/censer_quiet_parish
	name = "censer of the quiet parish"
	desc = "A brass censer on a short chain, dented from being swung at more than incense. Lit and hung on your belt, the local wildlife leaves you alone."
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
	// holding us belted+lit, without this guard the dying censer restarts itself
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
	// COMSIG_MOB_ATTACK_HAND only fires human-vs-human (species attack_hand).
	// It never fires for punching a basic-mob beast. LIVING_UNARMED_ATTACK
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

// add_faction()/remove_faction() rather than |= and -=: faction lists are interned by
// string_list() at Initialize(), so every mob with the same faction signature shares one list
// object. Editing it in place writes our wearer's REF into the shared entry and pacifies every
// mob of that type in the round. The API duplicates and re-interns instead.
/obj/item/flashlight/lantern/censer_quiet_parish/proc/grant_peace(mob/living/basic/fauna)
	fauna.add_faction(REF(current_wearer))
	peaceful_fauna += fauna
	RegisterSignal(fauna, COMSIG_QDELETING, PROC_REF(on_peaceful_fauna_gone))

/obj/item/flashlight/lantern/censer_quiet_parish/proc/revoke_peace(mob/living/basic/fauna)
	if(!QDELETED(fauna))
		fauna.remove_faction(REF(current_wearer))
		UnregisterSignal(fauna, COMSIG_QDELETING)
	peaceful_fauna -= fauna

/obj/item/flashlight/lantern/censer_quiet_parish/proc/end_all_peace()
	for(var/mob/living/basic/fauna as anything in peaceful_fauna.Copy())
		revoke_peace(fauna)

/obj/item/flashlight/lantern/censer_quiet_parish/proc/on_peaceful_fauna_gone(datum/source)
	SIGNAL_HANDLER
	peaceful_fauna -= source

/// The wearer threw an unarmed strike. Check if it broke the parish's patience.
/// Combat-mode gated so a help-intent pat on a peaceful beast doesn't count.
/obj/item/flashlight/lantern/censer_quiet_parish/proc/on_wearer_unarmed_attack(mob/living/source, atom/target, proximity, list/modifiers)
	SIGNAL_HANDLER
	if(!source.combat_mode || !isliving(target))
		return
	check_patience_broken(target)

/// The wearer hit something with a held item, same patience check
/obj/item/flashlight/lantern/censer_quiet_parish/proc/on_wearer_item_attack(mob/living/source, mob/living/target, mob/living/user, list/modifiers, list/attack_modifiers)
	SIGNAL_HANDLER
	check_patience_broken(target)

/obj/item/flashlight/lantern/censer_quiet_parish/proc/check_patience_broken(mob/living/target)
	if(!(target in peaceful_fauna))
		return
	patience_broken_until = world.time + CENSER_PATIENCE_BREAK_DURATION
	end_all_peace()
	if(current_wearer)
		to_chat(current_wearer, span_warning("You swung first. The censer stops keeping the peace for a while."))

// =========================================================================
// YELLOW: Confessor's stole
// Subtypes /obj/item/clothing/neck/scarf/purple (code/modules/clothing/neck/_neck.dm)
// for icon/icon_state/greyscale config; color re-tuned toward "gone gray"
// via the same greyscale system (not a new sprite).
// =========================================================================

/**
 * While worn: whoever the wearer is pulling gets TRAIT_PACIFISM for as long
 * as the pull lasts. They can't attack anyone, but they can still talk, walk
 * out of the pull, and resist out of a grab. Letting go (or the wearer taking
 * the stole off) lifts it immediately.
 *
 * Keyed to plain pulling rather than grab state: an aggressive grab already
 * locks the victim out of acting, so a pacifism rider on it did nothing. A
 * passive pull is the one hold where the victim can still fight back, so
 * that's where the stole is worth something.
 */
/obj/item/clothing/neck/scarf/purple/confessor_stole
	name = "confessor's stole"
	desc = "A purple stole gone gray at the fold. Anyone you're pulling can't bring themselves to attack, though they can still talk and pull away."
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
	// COMSIG_LIVING_START_PULL, not COMSIG_ATOM_START_PULL: /mob/living/start_pulling
	// never calls its /atom/movable parent, so the atom-level one never fires for a person.
	RegisterSignal(user, COMSIG_LIVING_START_PULL, PROC_REF(on_wearer_pull))
	RegisterSignal(user, COMSIG_ATOM_NO_LONGER_PULLING, PROC_REF(on_wearer_let_go))
	if(isliving(user.pulling))
		begin_confession(user.pulling)

/obj/item/clothing/neck/scarf/purple/confessor_stole/dropped(mob/living/user, silent = FALSE)
	. = ..()
	UnregisterSignal(user, list(COMSIG_LIVING_START_PULL, COMSIG_ATOM_NO_LONGER_PULLING))
	release_confession()

/// The wearer started pulling something: any pull counts, passive included
/obj/item/clothing/neck/scarf/purple/confessor_stole/proc/on_wearer_pull(mob/living/wearer, atom/movable/pulled_atom, state, force)
	SIGNAL_HANDLER
	if(!isliving(pulled_atom))
		release_confession()
		return
	begin_confession(pulled_atom)

/obj/item/clothing/neck/scarf/purple/confessor_stole/proc/on_wearer_let_go(mob/living/wearer, atom/movable/old_pulling)
	SIGNAL_HANDLER
	release_confession()

/obj/item/clothing/neck/scarf/purple/confessor_stole/proc/begin_confession(mob/living/target)
	if(target == confessed)
		return
	release_confession()
	confessed = target
	ADD_TRAIT(confessed, TRAIT_PACIFISM, CONFESSOR_STOLE_TRAIT)
	RegisterSignal(confessed, COMSIG_QDELETING, PROC_REF(on_confessed_deleted), override = TRUE)
	to_chat(confessed, span_notice("The hold on you takes the fight right out of you. You can't attack anyone until you're loose, but you can still talk."))

/obj/item/clothing/neck/scarf/purple/confessor_stole/proc/release_confession()
	if(!confessed)
		return
	if(!QDELETED(confessed))
		REMOVE_TRAIT(confessed, TRAIT_PACIFISM, CONFESSOR_STOLE_TRAIT)
		UnregisterSignal(confessed, COMSIG_QDELETING)
		to_chat(confessed, span_notice("You could fight back now, if you wanted to."))
	confessed = null

/obj/item/clothing/neck/scarf/purple/confessor_stole/proc/on_confessed_deleted(datum/source)
	SIGNAL_HANDLER
	confessed = null

// =========================================================================
// RED: The Vow (pair)
// Subtypes /obj/item/clothing/neck/beads (code/modules/clothing/neck/_neck.dm).
// Sprite/slot deviation: this codebase has no ring inventory slot, so the
// pair is reflavored as two iron rings threaded on a cord and worn at the
// throat rather than the finger, see report.
// =========================================================================

/**
 * Spawns as a linked pair (the second ring is created alongside the first,
 * weakref'd to each other). Once both rings are worn, either wearer can
 * click their own ring to speak the vow, which binds both: TRAIT_NODROP
 * goes on both rings, and clicking your ring afterward instead pulls a
 * capped amount of your partner's current brute/burn damage onto yourself
 * (cooldown-gated). Examining your own ring while bonded gives you a
 * direction/distance/health readout on your partner. The bond, and
 * TRAIT_NODROP: ends the moment either wearer dies (the funeral clause),
 * or if either wearer clicks their ring's secondary action to let go
 * (consent, from the only side that can actually act on it while both rings
 * are nodrop-locked).
 *
 * Scope note: "two willing wearers speak the vow" is simplified to "either
 * wearer speaks it once both rings are actually being worn", a full
 * two-party handshake (both must separately confirm) would need extra
 * state and messaging beyond what the doc's balance knobs call for.
 */
/// Action button: speak the vow, or pull the partner's wounds once it's spoken.
/datum/action/item_action/vow_hold
	name = "Hold the Vow"
	desc = "Speak the vow with your ring's twin. Once it's spoken, this pulls your partner's wounds onto yourself instead."

/// Action button: voluntarily release the vow (the living consent path).
/datum/action/item_action/vow_release
	name = "Let Go of the Vow"
	desc = "Release the vow. Both rings loosen."

/obj/item/clothing/neck/beads/vow_ring
	name = "iron vow ring"
	desc = "A plain iron ring threaded on a cord and worn at the throat. It came as a pair, and the inscription inside is worn smooth."
	icon = 'voidcrew/modules/loot/icons/uniques.dmi'
	icon_state = "vow_ring"
	worn_icon = 'voidcrew/modules/loot/icons/uniques_worn.dmi'
	worn_icon_state = "vow_ring"
	custom_materials = list(/datum/material/iron = SMALL_MATERIAL_AMOUNT * 0.5)
	// attack_self is unreachable for a worn (and, once vowed, NODROP-locked)
	// neck item, the action buttons are the only reliable activation path
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
		. += span_notice("There's no one on the other end anymore.")
		return
	if(other.stat == DEAD)
		. += span_notice("You feel nothing from the other end. They're dead.")
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
	to_chat(user, span_notice("You'll always know where [other] is and how badly they're hurt."))
	to_chat(other, span_notice("You'll always know where [user] is and how badly they're hurt."))

/obj/item/clothing/neck/beads/vow_ring/proc/try_pull_wound(mob/living/user)
	var/obj/item/clothing/neck/beads/vow_ring/partner = partner_ref?.resolve()
	var/mob/living/other = partner?.bonded_wearer
	if(!other || QDELETED(other))
		to_chat(user, span_warning("There's no one on the other end of the vow."))
		return
	if(!COOLDOWN_FINISHED(src, pull_cooldown))
		balloon_alert(user, "still cooling down")
		return
	if(other.stat == DEAD)
		to_chat(user, span_warning("[other] is dead. There's nothing left to take."))
		return

	var/pulled = 0
	var/brute_pull = min(VOW_PULL_CAP, other.get_brute_loss())
	if(brute_pull > 0)
		other.adjust_brute_loss(-brute_pull, updating_health = TRUE)
		user.adjust_brute_loss(brute_pull, updating_health = TRUE)
		pulled += brute_pull

	var/remaining_cap = VOW_PULL_CAP - pulled
	if(remaining_cap > 0)
		var/burn_pull = min(remaining_cap, other.get_fire_loss())
		if(burn_pull > 0)
			other.adjust_fire_loss(-burn_pull, updating_health = TRUE)
			user.adjust_fire_loss(burn_pull, updating_health = TRUE)
			pulled += burn_pull

	if(!pulled)
		to_chat(user, span_notice("[other] isn't hurt right now."))
		return

	COOLDOWN_START(src, pull_cooldown, VOW_PULL_COOLDOWN)
	user.visible_message(span_notice("[user] flinches as [other]'s injuries open up on [user.p_their()] own body."))
	to_chat(other, span_notice("Your wounds close up. [user] is carrying them now."))

/// Funeral clause: either wearer dying ends the bond
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
// RED: Shepherd's crook
// Subtypes /obj/item/cane (code/game/objects/items/weaponry.dm) for its
// weight class, force and inhand states; the item sprite is a custom state in
// uniques.dmi. It's a WEIGHT_CLASS_SMALL cane, not an oversized two-hander,
// so the standard 32x32 melee inhand files still apply.
// =========================================================================

/**
 * A firm tap (melee hit) on a non-megafauna hostile /mob/living/basic beast
 * tames it instead of damaging it: befriend() + a full faction copy from the
 * wearer (the same trick this fork's own tamed goliaths and wolves use to
 * stop attacking their tamer, code/modules/mob/living/basic/lavaland/goliath/goliath.dm,
 * code/modules/mob/living/basic/icemoon/wolf/wolf.dm), plus the standard
 * obeys_commands component (follow + protect owner) if the beast has an
 * ai_controller. Megafauna, both /mob/living/simple_animal/hostile/megafauna
 * and this fork's /mob/living/basic/boss tier, per the ismegafauna() macro,
 * decline the tap outright: no taming, no damage, just a refusal.
 *
 * CROOK_MAX_FLOCK beasts at once, CROOK_TAME_COOLDOWN between taps. A full
 * flock refuses new taps rather than dropping an existing follower, since
 * silently losing the beast you spent a tap on reads worse than being told
 * no; using the crook in hand dismisses the whole flock to make room. A slot
 * also frees up when a follower dies or is deleted.
 */
/obj/item/cane/shepherds_crook
	name = "shepherd's crook"
	desc = "A tall crook of black wood, worn smooth as a church rail. Tap a hostile beast with it and it'll follow you instead. It handles three at a time, with 5 seconds between taps."
	icon = 'voidcrew/modules/loot/icons/uniques.dmi'
	icon_state = "shepherds_crook"
	/// The beasts currently following us
	var/list/mob/living/basic/flock = list()
	COOLDOWN_DECLARE(tame_cooldown)

/obj/item/cane/shepherds_crook/Initialize(mapload)
	. = ..()
	ADD_TRAIT(src, TRAIT_NO_REPLICATE, INNATE_TRAIT)

/obj/item/cane/shepherds_crook/Destroy()
	for(var/mob/living/basic/beast as anything in flock)
		UnregisterSignal(beast, list(COMSIG_LIVING_DEATH, COMSIG_QDELETING))
	flock = null
	return ..()

/obj/item/cane/shepherds_crook/examine(mob/user, thats)
	. = ..()
	. += span_notice("Following you: [length(flock)] of [CROOK_MAX_FLOCK]. Use it in your hand to send them all away.")
	if(!COOLDOWN_FINISHED(src, tame_cooldown))
		. += span_notice("Ready to tame again in [DisplayTimeText(COOLDOWN_TIMELEFT(src, tame_cooldown))].")

/obj/item/cane/shepherds_crook/attack_self(mob/user, modifiers)
	. = ..()
	if(!length(flock))
		balloon_alert(user, "nothing following you")
		return
	var/sent_off = length(flock)
	dismiss_flock()
	balloon_alert(user, "flock dismissed ([sent_off])")
	user.visible_message(
		span_notice("[user] waves [src], and the beasts following [user.p_them()] wander off."),
		span_notice("You wave [src]. The beasts following you wander off. They won't turn on you."),
	)

/// Sends every follower away: frees their slots and stops the follow behavior. They stay friendly, they just stop tagging along.
/obj/item/cane/shepherds_crook/proc/dismiss_flock()
	for(var/mob/living/basic/beast as anything in flock.Copy())
		if(!QDELETED(beast))
			qdel(beast.GetComponent(/datum/component/obeys_commands))
		release_flock_member(beast)

/obj/item/cane/shepherds_crook/attack(mob/living/target_mob, mob/living/user, list/modifiers, list/attack_modifiers)
	if(try_tame(target_mob, user))
		return TRUE
	return ..()

/// Returns TRUE if we handled the swing ourselves (taming attempt, success or not), FALSE means "hit it normally"
/obj/item/cane/shepherds_crook/proc/try_tame(mob/living/target_mob, mob/living/user)
	if(!isliving(target_mob))
		return FALSE
	if(ismegafauna(target_mob))
		balloon_alert(user, "won't be herded")
		to_chat(user, span_notice("[target_mob] is not going to follow anyone anywhere."))
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
		// Already friendly to us (someone else's pet, neutral critter, etc). Let a normal hit happen instead of pretending to tame it.
		return FALSE
	if(length(flock) >= CROOK_MAX_FLOCK)
		balloon_alert(user, "flock full ([length(flock)]/[CROOK_MAX_FLOCK])")
		to_chat(user, span_warning("[src] only handles [CROOK_MAX_FLOCK] beasts at a time. Use it in your hand to send the ones you have away."))
		return TRUE
	if(!COOLDOWN_FINISHED(src, tame_cooldown))
		balloon_alert(user, "[DisplayTimeText(COOLDOWN_TIMELEFT(src, tame_cooldown))] left")
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

	COOLDOWN_START(src, tame_cooldown, CROOK_TAME_COOLDOWN)
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
#undef PALLBEARER_ROT_BLOCKER
#undef CONFESSOR_STOLE_TRAIT
#undef CENSER_SCAN_RANGE
#undef CENSER_PATIENCE_BREAK_DURATION
#undef VOW_RING_TRAIT
#undef VOW_PULL_CAP
#undef VOW_PULL_COOLDOWN
#undef CROOK_MAX_FLOCK
#undef CROOK_TAME_COOLDOWN
