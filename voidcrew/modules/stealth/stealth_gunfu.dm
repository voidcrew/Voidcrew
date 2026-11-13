/**
 * # Gun-fu (stealth step 3c, owner decisions 14-17 and 22)
 *
 * Close-quarters gunplay from a cyberware chip, the gun kata chip. Only a body with the chip running does the moves
 * (decision 16). They are tg's own controls with a gun in the active hand, and no action buttons:
 *
 * - Hip throw: hold someone in an aggressive grab, throw mode, click a tile. tg would throw the gun; the chip throws
 *   the person instead, through tg's own throw_at(), toward the click. They land and go down (tg's Knockdown()); a wall
 *   or a body in the way is tg's own crash.
 * - Shoulder flip: the same with a neck grab (they are on your tile). They go over your shoulder onto the next tile
 *   toward the click, flat on their back: brute through tg's armour and a longer knockdown.
 * - Wall slam: right-click (combat mode) someone next to you with the gun, with a wall or anything solid right behind
 *   them. tg's shove with a weapon (disarm()) knocks them down against it; the chip adds the wall's brute.
 * - Disarm: the same right-click with nothing solid behind them. tg's shove moves and staggers them; the chip knocks
 *   what they hold out of their hand and a couple of tiles away.
 * - Human shield: hold someone in a neck grab with the gun out. They are drawn in front of you, and shots coming at
 *   you from the front hit them instead (the bullet goes through tg's own hit on their body).
 *
 * After a throw, flip, slam or disarm, the mover's shots on that victim for GUNFU_MARK_TIME add to hyperviolence's
 * aimed crit roll (hv_crit_situation_bonus()). Nothing kills by itself: the roll still has to land, it goes in
 * before wound armour scales it, and each crit's own armour block still holds (decision 16). On anyone: players and
 * NPCs alike (decision 22); every move is logged with the zone.
 *
 * The motion is visual only (stealth_gunfu_motion.dm, hv_vis_play): nothing in it moves, stuns or hurts anyone.
 * An admin can fire any move on demand: "Gun-fu Moves" (stealth_gunfu_admin.dm).
 */

// ---------------------------------------------------------------------------------------------
// The chip

/obj/item/organ/cyberimp/cyberware/gun_kata
	name = "\improper gun kata chip"
	desc = "A combat chip seated at the base of the skull, loaded with close-quarters gunplay. The hands know where to go before you do."
	icon_state = "rigger"
	zone = BODY_ZONE_HEAD
	slot = ORGAN_SLOT_CYBERWARE_COMBAT_CHIP
	w_class = WEIGHT_CLASS_SMALL
	chrome_load = 4
	tier = CYBERWARE_TIER_3

/obj/item/organ/cyberimp/cyberware/gun_kata/on_mob_insert(mob/living/carbon/organ_owner, special = FALSE, movement_flags)
	. = ..()
	RegisterSignal(organ_owner, COMSIG_ATOM_PRE_BULLET_ACT, PROC_REF(on_owner_shot))
	RegisterSignal(organ_owner, COMSIG_ATOM_POST_DIR_CHANGE, PROC_REF(on_owner_turned))

/obj/item/organ/cyberimp/cyberware/gun_kata/on_mob_remove(mob/living/carbon/organ_owner, special = FALSE, movement_flags)
	. = ..()
	UnregisterSignal(organ_owner, list(COMSIG_ATOM_PRE_BULLET_ACT, COMSIG_ATOM_POST_DIR_CHANGE))
	if(isliving(organ_owner.pulling))
		organ_owner.set_pull_offsets(organ_owner.pulling, organ_owner.grab_state)

/// Whether the chip is in a head and running (not browned out, EMP-scrambled or broken).
/obj/item/organ/cyberimp/cyberware/gun_kata/proc/running()
	var/datum/component/cyberware/chrome = GetComponent(/datum/component/cyberware)
	return chrome?.is_running()

/// A shot coming at the bearer from the front, with a body held up as a shield, goes through to that body.
/obj/item/organ/cyberimp/cyberware/gun_kata/proc/on_owner_shot(mob/living/carbon/human/source, obj/projectile/shot, def_zone, piercing_hit, blocked)
	SIGNAL_HANDLER
	var/mob/living/shield = source.gunfu_shield_body()
	if(isnull(shield) || shot.firer == shield)
		return NONE
	if(abs(closer_angle_difference(dir2angle(source.dir), REVERSE_ANGLE(shot.angle))) > GUNFU_SHIELD_ARC)
		return NONE
	if(!shot.can_hit_target(shield, FALSE, TRUE))
		return NONE
	log_combat(source, shield, "used as a human shield", shot, "([get_area_name(source, TRUE)])")
	// The bullet passes the holder and tg's hit loop picks the next body on the tile: the one held up in front.
	return COMPONENT_BULLET_PIERCED

/obj/item/organ/cyberimp/cyberware/gun_kata/proc/on_owner_turned(mob/living/carbon/human/source, old_dir, new_dir)
	SIGNAL_HANDLER
	if(old_dir == new_dir || !isliving(source.pulling))
		return
	source.set_pull_offsets(source.pulling, source.grab_state)

// ---------------------------------------------------------------------------------------------
// Who can move

/mob/living
	/// world.time until which a gun-fu throw or flip lands this body without a fresh knockdown.
	var/gunfu_down_grace_until = 0

/mob/living/carbon/human
	/// world.time the next gun-fu move is ready.
	var/gunfu_next_move = 0
	/// Weak reference to who last put this body through a gun-fu move, and until when their shots get the bonus.
	var/datum/weakref/gunfu_marked_by
	var/gunfu_mark_until = 0

/// The running gun kata chip in this body, or null.
/mob/living/carbon/human/proc/gunfu_chip()
	var/obj/item/organ/cyberimp/cyberware/gun_kata/chip = get_organ_slot(ORGAN_SLOT_CYBERWARE_COMBAT_CHIP)
	if(!istype(chip) || !chip.running())
		return null
	return chip

/// The gun in the active hand, if this body can do a gun-fu move with it now. `ignore_cooldown` for admin tools.
/mob/living/carbon/human/proc/gunfu_gun(ignore_cooldown = FALSE)
	if(stat != CONSCIOUS || incapacitated || body_position != STANDING_UP || !isturf(loc))
		return null
	if(HAS_TRAIT(src, TRAIT_PACIFISM) || isnull(gunfu_chip()))
		return null
	if(!ignore_cooldown && world.time < gunfu_next_move)
		return null
	var/obj/item/gun/gun = get_active_held_item()
	return isgun(gun) ? gun : null

/// The body this one holds up as a shield now: a neck grab or tighter on someone on its tile, gun out, chip running.
/mob/living/carbon/human/proc/gunfu_shield_body()
	var/mob/living/held = pulling
	if(!isliving(held) || grab_state < GRAB_NECK || held.loc != loc || held.buckled)
		return null
	if(stat != CONSCIOUS || HAS_TRAIT(src, TRAIT_PACIFISM) || isnull(gunfu_chip()))
		return null
	if(!isgun(get_active_held_item()) && !isgun(get_inactive_held_item()))
		return null
	return held

/// After a move: the cooldown, the crit mark on the victim, and the log.
/mob/living/carbon/human/proc/gunfu_after_move(mob/living/victim, move)
	gunfu_next_move = world.time + GUNFU_MOVE_COOLDOWN
	if(ishuman(victim))
		var/mob/living/carbon/human/marked = victim
		marked.gunfu_marked_by = WEAKREF(src)
		marked.gunfu_mark_until = world.time + GUNFU_MARK_TIME
	log_combat(src, victim, "gun-fu [move]", get_active_held_item(), "([get_area_name(src, TRUE)])")

// ---------------------------------------------------------------------------------------------
// The crit bonus (decision 16)

/// The gun-fu roll bonus for this blow, or 0: a shot from whoever just put this body through a move.
/mob/living/carbon/human/proc/gunfu_crit_bonus(mob/living/attacker, atom/source, obj/item/bodypart/limb)
	if(isnull(attacker) || world.time >= gunfu_mark_until || !isprojectile(source))
		return 0
	if(gunfu_marked_by?.resolve() != attacker)
		return 0
	. = GUNFU_CRIT_BONUS
	if(limb?.body_zone == BODY_ZONE_HEAD)
		. += GUNFU_CRIT_HEAD_BONUS

/mob/living/carbon/human/hv_crit_situation_bonus(mob/living/attacker, atom/source, obj/item/bodypart/limb)
	. = ..()
	var/bonus = gunfu_crit_bonus(attacker, source, limb)
	if(bonus)
		log_combat(attacker, src, "shot after a gun-fu move", source, "(crit roll +[bonus], [limb?.body_zone])")
		. += bonus

// ---------------------------------------------------------------------------------------------
// Throw mode with someone held: the hip throw and the flip

/mob/living/carbon/human/throw_item(atom/target)
	var/mob/living/held = pulling
	if(!isliving(held) || grab_state < GRAB_AGGRESSIVE || held.buckled || isnull(target) || isnull(gunfu_gun()))
		return ..()
	var/turf/toward = get_turf(target)
	if(isnull(toward) || toward == get_turf(src))
		return ..()
	throw_mode_off(THROW_MODE_TOGGLE)
	if(grab_state >= GRAB_NECK && held.loc == loc)
		return gunfu_flip(held, toward)
	return gunfu_hip_throw(held, toward)

/// Hip throw: lets go of `victim` and throws them toward `toward` with tg's throw; they go down where they land.
/mob/living/carbon/human/proc/gunfu_hip_throw(mob/living/victim, turf/toward)
	setDir(get_cardinal_dir(src, toward))
	stop_pulling()
	visible_message(
		span_danger("[src] throws [victim] over [p_their()] hip!"),
		span_danger("You throw [victim] over your hip!"),
		span_hear("You hear a scuffle and a thud!"), COMBAT_MESSAGE_RANGE, victim)
	to_chat(victim, span_userdanger("[src] throws you over [p_their()] hip!"))
	playsound(src, 'sound/items/weapons/thudswoosh.ogg', 50, TRUE, -1)
	gunfu_after_move(victim, GUNFU_MOVE_HIP_THROW)
	gunfu_vis_hip_throw(victim, toward)
	victim.throw_at(toward, GUNFU_HIP_THROW_RANGE, 1, src, spin = FALSE, callback = CALLBACK(src, PROC_REF(gunfu_landed), victim, GUNFU_HIP_THROW_KNOCKDOWN, GUNFU_HIP_THROW_DAMAGE))
	return TRUE

/// Shoulder flip: `victim`, held on this tile, goes over onto the next tile toward `toward` (the way the mover turns to
/// face) and lands flat.
/mob/living/carbon/human/proc/gunfu_flip(mob/living/victim, turf/toward)
	var/flip_dir = get_cardinal_dir(src, toward)
	var/turf/landing = get_step(src, flip_dir)
	setDir(flip_dir)
	stop_pulling()
	visible_message(
		span_danger("[src] flips [victim] over [p_their()] shoulder!"),
		span_danger("You flip [victim] over your shoulder!"),
		span_hear("You hear a heavy slam!"), COMBAT_MESSAGE_RANGE, victim)
	to_chat(victim, span_userdanger("[src] flips you over [p_their()] shoulder!"))
	playsound(src, 'sound/items/weapons/thudswoosh.ogg', 60, TRUE, -1)
	gunfu_after_move(victim, GUNFU_MOVE_FLIP)
	gunfu_vis_flip(victim, landing)
	victim.throw_at(landing, 1, 1, src, spin = FALSE, callback = CALLBACK(src, PROC_REF(gunfu_landed), victim, GUNFU_FLIP_KNOCKDOWN, GUNFU_FLIP_DAMAGE, BODY_ZONE_CHEST, FALSE))
	return TRUE

/// A thrown or flipped body hits the floor: tg's knockdown and the fall's brute through its armour. A throw that hit
/// a wall or a body already got tg's own crash; the floor still puts them down.
/mob/living/carbon/human/proc/gunfu_landed(mob/living/victim, knockdown, damage, zone, thud = TRUE)
	if(QDELETED(victim) || victim.stat == DEAD)
		return
	if(damage)
		var/hit_zone = zone || pick(BODY_ZONE_CHEST, BODY_ZONE_L_ARM, BODY_ZONE_R_ARM, BODY_ZONE_L_LEG, BODY_ZONE_R_LEG)
		var/armour = victim.run_armor_check(hit_zone, MELEE, silent = TRUE)
		victim.apply_damage(damage, BRUTE, hit_zone, armour)
	// A body just put down by a throw or flip lands without a fresh knockdown, so throws can't chain into a stunlock.
	if(world.time >= victim.gunfu_down_grace_until)
		victim.Knockdown(knockdown)
		victim.gunfu_down_grace_until = world.time + knockdown + GUNFU_KNOCKDOWN_GRACE
	// The flip's slam sound is played by its picture, on the frame the body hits the floor (stealth_gunfu_motion_flip.dm).
	if(thud)
		playsound(victim, 'sound/effects/hit_kick.ogg', 50, TRUE, -1)

// ---------------------------------------------------------------------------------------------
// Right-click with the gun: the wall slam and the disarm

/obj/item/gun/attack_secondary(mob/living/victim, mob/living/user, list/modifiers, list/attack_modifiers)
	if(ishuman(user) && isliving(victim) && victim != user && user.combat_mode)
		var/mob/living/carbon/human/mover = user
		if(mover.get_active_held_item() == src && mover.gunfu_gun() && mover.gunfu_shove(victim, src))
			return SECONDARY_ATTACK_CANCEL_ATTACK_CHAIN
	return ..()

/// Shoves `victim` with the gun through tg's disarm(): a slam if something solid is right behind them, else a disarm.
/// FALSE if it can't (not next to them, on their tile, or nothing to do).
/mob/living/carbon/human/proc/gunfu_shove(mob/living/victim, obj/item/gun/gun)
	if(!Adjacent(victim) || victim.loc == loc || !can_disarm(victim))
		return FALSE
	var/shove_dir = get_dir(src, victim)
	var/turf/behind = get_step(victim, shove_dir)
	if(gunfu_solid_behind(victim, behind, shove_dir))
		return gunfu_wall_slam(victim, gun, behind)
	var/obj/item/held = victim.get_active_held_item() || victim.get_inactive_held_item()
	if(isnull(held))
		return FALSE
	return gunfu_disarm(victim, gun, held)

/// Whether a shove from `shove_dir` would drive `victim` into something solid on `behind`.
/mob/living/carbon/human/proc/gunfu_solid_behind(mob/living/victim, turf/behind, shove_dir)
	if(isnull(behind) || behind.density)
		return TRUE
	for(var/atom/movable/thing as anything in behind)
		if(thing.density && !isliving(thing) && !(thing.flags_1 & ON_BORDER_1))
			return TRUE
		if((thing.flags_1 & ON_BORDER_1) && thing.density && thing.dir == REVERSE_DIR(shove_dir))
			return TRUE
	return FALSE

/// Wall slam: tg's shove into something solid knocks them down; the chip adds the wall's brute, through armour.
/mob/living/carbon/human/proc/gunfu_wall_slam(mob/living/victim, obj/item/gun/gun, turf/wall)
	gunfu_after_move(victim, GUNFU_MOVE_WALL_SLAM)
	gunfu_vis_wall_slam(victim, wall)
	disarm(victim, gun)
	if(QDELETED(victim))
		return TRUE
	var/hit_zone = pick(BODY_ZONE_HEAD, BODY_ZONE_CHEST)
	var/armour = victim.run_armor_check(hit_zone, MELEE, silent = TRUE)
	victim.apply_damage(GUNFU_SLAM_DAMAGE, BRUTE, hit_zone, armour, attack_direction = get_dir(src, victim))
	return TRUE

/// Disarm: tg's shove moves and staggers them; the chip knocks `held` out of their hand and a couple of tiles off.
/mob/living/carbon/human/proc/gunfu_disarm(mob/living/victim, obj/item/gun/gun, obj/item/held)
	gunfu_after_move(victim, GUNFU_MOVE_DISARM)
	gunfu_vis_disarm(victim, held)
	disarm(victim, gun)
	if(QDELETED(victim) || QDELETED(held) || held.loc != victim)
		return TRUE
	if(!victim.dropItemToGround(held))
		return TRUE
	victim.visible_message(span_danger("[src] knocks [held] out of [victim]'s hand!"),
		span_userdanger("[src] knocks [held] out of your hand!"), null, COMBAT_MESSAGE_RANGE, src)
	var/turf/away = get_ranged_target_turf(victim, turn(get_dir(src, victim), pick(-45, 45)), GUNFU_DISARM_THROW_RANGE)
	held.throw_at(away, GUNFU_DISARM_THROW_RANGE, 2, src, spin = TRUE)
	return TRUE

/// Scav den loot (decision 51's hook, decision 54): a den vault may pay the gun kata chip.
/obj/structure/closet/crate/secure/scav_vault/scav_vault_stealth_loot()
	. = ..()
	.[/obj/item/organ/cyberimp/cyberware/gun_kata] = 2
