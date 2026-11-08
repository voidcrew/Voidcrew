/**
 * # Bounty chrome: Mantis Blades
 *
 * Owner: C2 (Mantis Blades and Gorilla Arms). Built on the chrome core, bounty_chrome.dm.
 *
 * The player's Mantis Blades (voidcrew/modules/cyberware/ware_military_arms.dm), the real pair of forearm
 * housings, in a criminal or companion who fights up close (the piece rolls only on brawlers, knife and
 * club fighters). The NPC uses them the way a player does, through the housings' own buttons:
 * - Blades out (/datum/bounty_chrome_move/mantis_blades). Once its fight starts it presses each housing's
 *   button, and the blade comes out into that hand with the implant's own sound and line. From then on the
 *   blades are its weapon: its melee swings the strongest thing it holds, and a hardlight blade's force,
 *   edge and wound bonus are the blade's own, so its cuts are tg's slash wounds and bleed as those do. A
 *   knife in that hand goes back in its pocket first. A bat has nowhere to go on a body, so that arm keeps
 *   the bat and the other arm's blade does the work.
 * - The blades go back in when the fight is over, or it goes down, is cuffed or gives up: the button
 *   again, or the implant's own stow when it is past pressing buttons. An EMP stows them by itself (the
 *   implant), and they stay in through the reboot.
 * - They never leave its body. While out a blade is NODROP and indestructible (the toolkit's Extend()),
 *   and it is locked gear like the rest of its kit (human_npc_gear.dm): it can't be disarmed, stripped or
 *   dropped, and one forced out of its hand is deleted. When it dies, or a housing is cut or taken out of
 *   it, the housing burns out to scrap and its blade goes with it (the human NPC base).
 * - The lunge (/datum/bounty_chrome_move/mantis_lunge). With someone two to five tiles off in a clear
 *   line, it turns its blades on them in a blue outline and a blue line lights the floor up to them, then
 *   it presses a housing's own Mantis Lunge on them: the implant's telegraph, dash, cuts and knockdown and
 *   its 20 second cooldown, all as written. The AI only picks when: never at someone already on the floor,
 *   never down a line with anything solid on it (the dash would fall short), and never where the dash
 *   could carry it off its side's site or past a drop, lava or space (the implant moves its bearer by
 *   force, so the AI looks first). The first lunge may come a second into a fight.
 */

/// The lunge's reach in tiles: the player lunge's CYBERWARE_MANTIS_LUNGE_RANGE (ware_military_arms.dm)
#define BOUNTY_MANTIS_LUNGE_RANGE 5
/// The closest a target may be for a lunge: right beside them it is a swing, not a lunge
#define BOUNTY_MANTIS_LUNGE_MIN 2
/// The tell before the lunge, the line lit on the floor; the implant's own telegraph follows it
#define BOUNTY_MANTIS_LUNGE_TELL (0.9 SECONDS)
/// The first lunge of a fight may start this long after the fight does
#define BOUNTY_MANTIS_OPENING (1 SECONDS)
/// A hand it couldn't empty for a blade is left alone this long before it tries again
#define BOUNTY_MANTIS_STOW_RETRY (10 SECONDS)
/// The tell's outline, in the hardlight blade's blue
#define BOUNTY_MANTIS_COLOR "#6cb8ff"
/// The line on the floor: the mark art is pure red, which a plain colour only darkens, so a matrix turns it the blade's blue
#define BOUNTY_MANTIS_MARK_MATRIX list(0.42, 0.72, 1, 0, 0, 0, 0, 0, 0)

// ===== HELPERS =====

/// The Mantis Blade housings in `npc`'s arms
/proc/bounty_mantis_housings(mob/living/carbon/npc)
	. = list()
	if(QDELETED(npc))
		return
	for(var/obj/item/organ/cyberimp/arm/toolkit/cyberware/mantis/housing in npc.organs)
		. += housing

/// Whether `housing`'s chrome is running, so its blade can come out
/proc/bounty_mantis_running(obj/item/organ/cyberimp/arm/toolkit/cyberware/mantis/housing)
	var/datum/component/cyberware/chrome = housing?.GetComponent(/datum/component/cyberware)
	return !!chrome?.is_running()

/// `housing`'s own button, the one that puts its blade out and away
/proc/bounty_mantis_toggle(obj/item/organ/cyberimp/arm/toolkit/cyberware/mantis/housing)
	return locate(/datum/action/item_action/organ_action/toggle/toolkit) in housing?.actions

/// The hands (RIGHT_HANDS or LEFT_HANDS) `housing`'s blade comes out into
/proc/bounty_mantis_side(obj/item/organ/cyberimp/arm/toolkit/cyberware/mantis/housing)
	return housing.zone == BODY_ZONE_R_ARM ? RIGHT_HANDS : LEFT_HANDS

/// The blades `housing` keeps, out or in (the toolkit's items_list)
/proc/bounty_mantis_blades(obj/item/organ/cyberimp/arm/toolkit/cyberware/mantis/housing)
	. = list()
	for(var/datum/weakref/blade_ref as anything in housing?.items_list)
		var/obj/item/blade = blade_ref?.resolve()
		if(!QDELETED(blade))
			. += blade

/**
 * Puts every blade of `npc`'s that is out back in its housing: the housing's own button, or, when it is
 * past pressing buttons (down in crit), the implant's own stow. Doesn't sleep.
 */
/proc/bounty_mantis_put_away(mob/living/carbon/npc)
	for(var/obj/item/organ/cyberimp/arm/toolkit/cyberware/mantis/housing as anything in bounty_mantis_housings(npc))
		if(!housing.blade_extended())
			continue
		var/datum/action/toggle = bounty_mantis_toggle(housing)
		if(toggle?.IsAvailable())
			toggle.Trigger()
		if(housing.blade_extended())
			housing.Retract()

/// Whether a dash must never cross `spot`: open space or a drop, lava, a chasm, space
/proc/bounty_mantis_drop(turf/spot)
	return isspaceturf(spot) || isopenspaceturf(spot) || isgroundlessturf(spot) || islava(spot) || ischasm(spot)

/// world.time `npc` last fired any chrome move, leaving out moves of `except_types`, or 0 if none has fired
/proc/bounty_melee_chrome_last_move_at(mob/living/carbon/human/npc/npc, list/except_types)
	. = 0
	var/datum/component/bounty_chrome/chrome = npc?.GetComponent(/datum/component/bounty_chrome)
	for(var/datum/bounty_chrome_move/move as anything in chrome?.moves)
		if(except_types && is_type_in_list(move, except_types))
			continue
		. = max(., move.last_fired)

/**
 * Whether `npc`'s other chrome lets a move whose own opener is at `opens_at` start now: past the gap the
 * last move to fire left (the component's next_move_at), or, with none fired since the fight started at
 * `fight_started_at`, past the move's own opener, which comes before the core's (BOUNTY_CHROME_OPENING).
 */
/proc/bounty_melee_chrome_may_start(mob/living/carbon/human/npc/npc, opens_at, fight_started_at)
	if(world.time < opens_at)
		return FALSE
	var/datum/component/bounty_chrome/chrome = npc?.GetComponent(/datum/component/bounty_chrome)
	if(!chrome || chrome.telling)
		return FALSE
	if(world.time >= chrome.next_move_at)
		return TRUE
	return bounty_melee_chrome_last_move_at(npc) < fight_started_at

// ===== BLADES OUT =====

/**
 * The blades, out for a fight and away after it. It plans nothing of its own: in a fight it presses a
 * housing's button for each blade still in (plan(), and on_tick() for a mini-boss, which plans no chrome
 * of its own), and out of it, down, cuffed or giving up it puts them away.
 */
/datum/bounty_chrome_move/mantis_blades
	piece_key = BOUNTY_CHROME_MANTIS
	name = "Mantis Blades"
	// No tell: putting a blade out hurts nobody, and the implant shows and sounds it
	boss_usable = FALSE
	/// REF() of a housing -> world.time it may try again to empty that hand for its blade
	var/list/stow_retry_at

/datum/bounty_chrome_move/mantis_blades/attach(mob/living/carbon/human/npc/npc)
	. = ..()
	// A body dressed before its housings went in (a test, an admin's install) has its blades locked now, like its other gear
	for(var/obj/item/organ/cyberimp/arm/toolkit/cyberware/mantis/housing as anything in bounty_mantis_housings(npc))
		for(var/obj/item/blade as anything in bounty_mantis_blades(housing))
			npc.npc_lock_item(blade)
	RegisterSignals(npc, list(SIGNAL_ADDTRAIT(TRAIT_RESTRAINED), COMSIG_HUMAN_NPC_SURRENDERED), PROC_REF(on_out_of_it))

/datum/bounty_chrome_move/mantis_blades/detach()
	if(owner)
		UnregisterSignal(owner, list(SIGNAL_ADDTRAIT(TRAIT_RESTRAINED), COMSIG_HUMAN_NPC_SURRENDERED))
		if(!QDELETED(owner))
			bounty_mantis_put_away(owner)
	stow_retry_at = null
	return ..()

/datum/bounty_chrome_move/mantis_blades/plan(datum/ai_controller/controller, atom/target)
	// In its fight and able to act: a blade out is this moment's click
	if(!bounty_chrome_in_fight(owner) || !bounty_chrome_can_act(owner))
		return FALSE
	return draw_one()

/datum/bounty_chrome_move/mantis_blades/on_tick(seconds_per_tick, fighting, atom/target)
	if(fighting && !blades_go_away())
		if(bounty_chrome_can_act(owner))
			draw_one()
		return
	bounty_mantis_put_away(owner)

/datum/bounty_chrome_move/mantis_blades/on_fight_end()
	bounty_mantis_put_away(owner)

/datum/bounty_chrome_move/mantis_blades/on_downed()
	bounty_mantis_put_away(owner)

/datum/bounty_chrome_move/mantis_blades/on_death()
	bounty_mantis_put_away(owner)

/// Whether the blades go away for now: down in crit, cuffed, giving up or dead. A knockdown or a stun keeps them out, as it would a player's.
/datum/bounty_chrome_move/mantis_blades/proc/blades_go_away()
	return QDELETED(owner) || owner.stat != CONSCIOUS || HAS_TRAIT(owner, TRAIT_CRITICAL_CONDITION) || HAS_TRAIT(owner, TRAIT_RESTRAINED) || owner.npc_surrendering

/// Cuffed, or giving up: the blades go in. Inside a signal handler.
/datum/bounty_chrome_move/mantis_blades/proc/on_out_of_it(datum/source)
	SIGNAL_HANDLER
	INVOKE_ASYNC(GLOBAL_PROC, GLOBAL_PROC_REF(bounty_mantis_put_away), owner)

/**
 * Puts out one blade that is still in, the way a player's button does: its housing's chrome running and
 * its hand free. Returns TRUE if a blade came out.
 */
/datum/bounty_chrome_move/mantis_blades/proc/draw_one()
	if(QDELETED(owner))
		return FALSE
	for(var/obj/item/organ/cyberimp/arm/toolkit/cyberware/mantis/housing as anything in bounty_mantis_housings(owner))
		if(housing.blade_extended() || !bounty_mantis_running(housing))
			continue
		var/datum/action/toggle = bounty_mantis_toggle(housing)
		if(!toggle?.IsAvailable() || !free_hand_for(housing))
			continue
		toggle.Trigger()
		if(housing.blade_extended())
			return TRUE
	return FALSE

/**
 * Whether the hand `housing`'s blade comes out into is free, first putting away what it holds there if
 * that has somewhere to go on its body (a knife into a pocket). Never drops anything.
 */
/datum/bounty_chrome_move/mantis_blades/proc/free_hand_for(obj/item/organ/cyberimp/arm/toolkit/cyberware/mantis/housing)
	var/side = bounty_mantis_side(housing)
	if(owner.get_empty_held_index_for_side(side))
		return TRUE
	var/key = REF(housing)
	if(world.time < LAZYACCESS(stow_retry_at, key))
		return FALSE
	for(var/obj/item/held as anything in owner.get_held_items_for_side(side, all = TRUE))
		if(HAS_TRAIT(held, TRAIT_NODROP) || !held.equip_to_best_slot(owner))
			LAZYSET(stow_retry_at, key, world.time + BOUNTY_MANTIS_STOW_RETRY)
			return FALSE
	return !!owner.get_empty_held_index_for_side(side)

// ===== THE LUNGE =====

/**
 * The Mantis Lunge: the line lit on the floor and a blue outline for BOUNTY_MANTIS_LUNGE_TELL, then a
 * housing's own Mantis Lunge pressed on the target, the housing with its blade out.
 */
/datum/bounty_chrome_move/mantis_lunge
	piece_key = BOUNTY_CHROME_MANTIS
	name = "Mantis Lunge"
	action_type = /datum/action/cooldown/cyberware/mantis_lunge
	tell_time = BOUNTY_MANTIS_LUNGE_TELL
	tell_color = BOUNTY_MANTIS_COLOR
	tell_lines = list("Hold still.", "You're mine.", "Got you now.")
	max_range = BOUNTY_MANTIS_LUNGE_RANGE
	min_range = BOUNTY_MANTIS_LUNGE_MIN
	/// world.time its first lunge of this fight may start
	var/opens_at = 0
	/// world.time this fight started
	var/fight_started_at = 0

/datum/bounty_chrome_move/mantis_lunge/on_fight_start(atom/target)
	fight_started_at = world.time
	opens_at = world.time + BOUNTY_MANTIS_OPENING

/// A housing's Mantis Lunge it can press now: one whose blade is out, its chrome running and the lunge off cooldown
/datum/bounty_chrome_move/mantis_lunge/proc/lunge_action()
	for(var/obj/item/organ/cyberimp/arm/toolkit/cyberware/mantis/housing as anything in bounty_mantis_housings(owner))
		if(!housing.blade_extended())
			continue
		var/datum/action/cooldown/cyberware/mantis_lunge/lunge = locate() in housing.actions
		if(lunge?.owner == owner && lunge.IsAvailable())
			return lunge
	return null

/datum/bounty_chrome_move/mantis_lunge/ready()
	return !!lunge_action()

/datum/bounty_chrome_move/mantis_lunge/can_start(atom/target)
	var/mob/living/victim = target
	// The blades pass over someone on the floor: no lunge at them
	if(!isliving(victim) || !isturf(victim.loc) || victim.body_position == LYING_DOWN)
		return FALSE
	if(!..())
		return FALSE
	return line_clear(victim)

/**
 * Whether the implant's dash at `victim` carries it only over its own ground: nothing solid on the way
 * (or it falls short), every tile on its side's leash, and no drop, lava or space beside the line either,
 * since they may step aside during the tell and the dash goes where they are then.
 */
/datum/bounty_chrome_move/mantis_lunge/proc/line_clear(mob/living/victim)
	var/mob/living/carbon/human/npc/bounty_criminal/side = bounty_ai_side_of(owner)
	var/turf/start = get_turf(owner)
	var/turf/aim = get_turf(victim)
	// A companion whose criminal is gone has no ground of its own to dash over
	if(!side || !start || !aim || start.z != aim.z)
		return FALSE
	for(var/turf/spot as anything in get_line(start, aim))
		if(spot == start)
			continue
		if(spot == aim)
			break
		if(spot.is_blocked_turf(exclude_mobs = TRUE) || !side.leash_ok(spot))
			return FALSE
		for(var/turf/beside as anything in RANGE_TURFS(1, spot))
			if(bounty_mantis_drop(beside))
				return FALSE
	return TRUE

/datum/bounty_chrome_move/mantis_lunge/plan(datum/ai_controller/controller, atom/target)
	// Its own opener, a little before the core's: early enough to show inside a short fight
	if(!bounty_melee_chrome_may_start(owner, opens_at, fight_started_at) || !can_start(target))
		return FALSE
	var/datum/component/bounty_chrome/chrome = owner.GetComponent(/datum/component/bounty_chrome)
	return !!chrome?.start_move(src, target)

/datum/bounty_chrome_move/mantis_lunge/tell_text(atom/target)
	return "[owner] turns [owner.p_their()] blades on [target]."

/datum/bounty_chrome_move/mantis_lunge/tell(atom/target)
	..()
	var/turf/start = get_turf(owner)
	var/turf/aim = get_turf(target)
	if(!start || !aim)
		return
	// The way it will come, lit up to whoever it is aimed at
	for(var/turf/spot as anything in get_line(start, aim))
		if(spot == start)
			continue
		add_mark(new /obj/effect/temp_visual/bounty_boss_mark(spot, tell_time + 1, BOUNTY_MANTIS_MARK_MATRIX, spot == aim ? "target_circle" : null))

/datum/bounty_chrome_move/mantis_lunge/effect(atom/target)
	var/datum/action/cooldown/cyberware/mantis_lunge/lunge = lunge_action()
	if(!lunge || !isliving(target) || QDELETED(target))
		return FALSE
	return !!lunge.Trigger(target = target)

#undef BOUNTY_MANTIS_LUNGE_RANGE
#undef BOUNTY_MANTIS_LUNGE_MIN
#undef BOUNTY_MANTIS_LUNGE_TELL
#undef BOUNTY_MANTIS_OPENING
#undef BOUNTY_MANTIS_STOW_RETRY
#undef BOUNTY_MANTIS_COLOR
#undef BOUNTY_MANTIS_MARK_MATRIX
