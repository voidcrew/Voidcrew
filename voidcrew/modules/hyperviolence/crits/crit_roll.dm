// Hyperviolence: aimed critical wounds.
//
// A big enough hit, aimed at the right spot with the right kind of weapon, can do one specific,
// lasting injury: tear out an eye, cut off the tongue, slit the throat, tear the aorta, cave in
// the skull or shatter the jaw. The design follows Roguetown's try_crit (BLACKSTONE,
// code/modules/surgery/bodyparts/bodypart_wounds.dm) and Vanderlin's per-wound crit data
// (code/datums/wounds/_wound.dm). Only the ideas were taken; no code, art or sound was copied.
//
// How a crit is rolled. These numbers are balance notes for developers and never go in player
// text.
// * Only aimed hits count. The attacker must be a carbon (something with a target doll) holding
//   the weapon or having fired the shot, must not be the victim, and the hit has to land on the
//   limb they aimed at. NPC basic mobs never land crits, so NPC fights keep tg's normal wounds.
// * The hit must be brute damage with a wound roll (wound_bonus not CANT_WOUND) and a weapon or
//   projectile behind it. Only the aorta can come from a projectile.
// * The roll is tg's own wound roll: rand(1, min(damage, 25) ^ 1.4), so 1 to 90. On top of the
//   weapon's wound_bonus we add up to +30 for how battered the limb already is (its damage over
//   its max damage) and +25 if the victim is helpless (lying down, in crit, stunned, cuffed or
//   held in an aggressive grab), +15 more if the attacker is the one holding them. Then tg's
//   check_woundings_mods() adds the limb's existing wound penalties and scales everything by
//   wound armour (worn WOUND ratings plus the limb's own resistance: head 5%, chest 10%).
// * Each crit has a threshold and a minimum damage after armour (crit_types.dm). A fresh,
//   standing, unarmoured target hit by a 25+ damage weapon tops out at about 85, so the face
//   crits (eye, tongue at 80, jaw at 75) land on roughly one such hit in ten to twenty, and the
//   throat (90), aorta (90, chest armour scales it to 81 max) and skull (95) need the victim
//   worn down or helpless first. A helpless target held by the attacker gets the throat about
//   one big slash in four. A 10-force kitchen knife tops out near 30 and never crits by roll.
// * Gear that covers the spot blocks a crit outright (see each crit's blocked_on_carbon()).
// * A crit never stacks on itself: the wound can only be on a limb once.

/// Most a battered limb adds to the roll, scaled by how much of its max damage it has taken.
#define HV_CRIT_BATTERED_BONUS 30
/// Added to the roll when the victim is helpless.
#define HV_CRIT_HELPLESS_BONUS 25
/// Added on top when the attacker holds the victim in an aggressive grab or tighter.
#define HV_CRIT_HELD_BONUS 15

/// Every aimed crit, one singleton per kind. See crit_types.dm.
GLOBAL_LIST_INIT(hv_crits, hv_crit_init_list())

/proc/hv_crit_init_list()
	var/list/crits = list()
	for(var/crit_type in subtypesof(/datum/hv_crit))
		crits += new crit_type
	return crits

/// One kind of aimed critical wound: where it must be aimed, what can cause it, how hard it is to
/// land, what stops it and what it does.
/datum/hv_crit
	/// Plain name, for logs.
	var/name = "aimed crit"
	/// The limb the hit has to land on.
	var/limb_zone = BODY_ZONE_HEAD
	/// What the attacker must have selected on their target doll.
	var/list/aim_zones = list()
	/// Wounding types (WOUND_SLASH, WOUND_PIERCE, WOUND_BLUNT) that can cause it.
	var/list/wounding_types = list()
	/// Least damage the hit must deal after armour.
	var/min_damage = 15
	/// The roll must reach this. See the notes at the top of this file.
	var/threshold = 90
	/// Can a projectile cause it?
	var/allow_projectiles = FALSE
	/// Can it happen to a corpse?
	var/allow_dead = FALSE
	/// The wound a carbon gets.
	var/datum/wound/wound_type
	/// The status effect a humanoid basic mob gets instead. See crit_basic.dm.
	var/datum/status_effect/basic_effect
	/// Size of the hit line: HV_LINE_BOLD or HV_LINE_HUGE.
	var/line_severity = HV_LINE_BOLD
	/// How far the hit line carries. As tg does for wounds: critical ones carry the full
	/// DEFAULT_MESSAGE_RANGE, lesser ones only the close combat range.
	var/line_range = COMBAT_MESSAGE_RANGE
	/// Played on the victim when it lands. Must be a sound already in the repo.
	var/hit_sound
	/// How long the victim's screen shakes, in deciseconds. 0 for none.
	var/shake = 0

/// TRUE if a hit on hit_zone, aimed at aimed_zone, of this wounding type could cause this crit.
/datum/hv_crit/proc/matches(hit_zone, aimed_zone, wounding_type, from_projectile)
	if(hit_zone != limb_zone || !(aimed_zone in aim_zones) || !(wounding_type in wounding_types))
		return FALSE
	return !from_projectile || allow_projectiles

/// TRUE if something the victim wears stops this crit outright.
/datum/hv_crit/proc/blocked_on_carbon(mob/living/carbon/victim, obj/item/bodypart/limb, atom/source)
	return FALSE

/// TRUE if this crit's wound can go on this limb right now.
/datum/hv_crit/proc/can_apply_carbon(mob/living/carbon/victim, obj/item/bodypart/limb, wounding_type)
	var/datum/wound_pregen_data/pregen = GLOB.all_wound_pregen_data[wound_type]
	return !!pregen?.can_be_applied_to(limb, list(wounding_type))

/// TRUE if this crit happens on this hit without a roll (a ruined eye, say). Rolled each hit.
/datum/hv_crit/proc/happens_anyway(mob/living/carbon/victim, obj/item/bodypart/limb)
	return FALSE

/// Applies the crit to a carbon. Returns TRUE if it landed.
/datum/hv_crit/proc/apply_carbon(mob/living/carbon/victim, obj/item/bodypart/limb, damage, attack_direction, atom/source, mob/living/attacker)
	var/datum/wound/crit_wound = hv_crit_apply_wound(limb, wound_type, attack_direction, source)
	if(!crit_wound)
		return FALSE
	announce(victim, attack_direction)
	return TRUE

/// The line added to the hit message.
/datum/hv_crit/proc/hit_line(mob/living/victim)
	return "[victim] is badly hurt!"

/// What the victim reads in place of hit_line().
/datum/hv_crit/proc/self_line(mob/living/victim)
	return "You are badly hurt!"

/// Hit line, sound and shake. line and own_line override hit_line() and self_line().
/datum/hv_crit/proc/announce(mob/living/victim, attack_direction, line, own_line)
	victim.hv_add_hit_line(line || hit_line(victim), line_severity, own_line || self_line(victim), line_range)
	if(hit_sound)
		playsound(victim, hit_sound, 80, TRUE, falloff_exponent = SOUND_FALLOFF_EXPONENT + 2, ignore_walls = FALSE, falloff_distance = 0)
	if(shake)
		shake_camera(victim, shake, 1)

/// TRUE if a humanoid basic mob can take this crit right now.
/datum/hv_crit/proc/can_apply_basic(mob/living/basic/victim)
	return basic_effect && !victim.has_status_effect(basic_effect)

/// Applies the crit to a humanoid basic mob. Returns TRUE if it landed.
/datum/hv_crit/proc/apply_basic(mob/living/basic/victim, damage, attack_direction, atom/source, mob/living/attacker)
	if(!victim.apply_status_effect(basic_effect, attack_direction))
		return FALSE
	announce(victim, attack_direction)
	return TRUE

// ---------------------------------------------------------------------------------------------
// Helpers

/// Applies wound_type to limb the way tg's own roll does: it replaces a lesser wound of the same
/// series, and does nothing if one as bad is already there. Silent, since the crit adds its own
/// hit line. Returns the wound, or null.
/proc/hv_crit_apply_wound(obj/item/bodypart/limb, datum/wound/wound_type, attack_direction, atom/source, right_side)
	var/datum/wound_pregen_data/pregen = GLOB.all_wound_pregen_data[wound_type]
	if(!pregen)
		return null
	var/datum/wound/replaced
	for(var/datum/wound/existing as anything in limb.wounds)
		if(existing.get_pregen_data().wound_series != pregen.wound_series)
			continue
		if(existing.severity >= initial(wound_type.severity))
			return null
		replaced = existing
	var/datum/wound/new_wound = new wound_type
	if(replaced)
		// tg's replace_wound(), but silent: tg would print its own wound message on a promotion.
		replaced.already_scarred = TRUE
		replaced.remove_wound(replaced = TRUE)
		var/applied = new_wound.apply_wound(limb, silent = TRUE, old_wound = replaced, attack_direction = attack_direction, wound_source = source, replacing = TRUE)
		qdel(replaced)
		return applied ? new_wound : null
	if(!new_wound.apply_wound(limb, silent = TRUE, attack_direction = attack_direction, wound_source = source))
		return null
	return new_wound

/// The carbon who aimed this hit: whoever holds the weapon, or fired the projectile.
/proc/hv_crit_get_aimer(atom/source)
	var/atom/aimer
	if(isprojectile(source))
		var/obj/projectile/shot = source
		aimer = shot.firer
	else if(isitem(source))
		aimer = source.loc
	return iscarbon(aimer) ? aimer : null

/// tg's wounding type for a brute hit. Eye stabs and a few other callers pass no sharpness to
/// apply_damage, so fall back to the weapon's own.
/proc/hv_crit_wounding_type(sharpness, atom/source)
	if(!sharpness && isitem(source))
		var/obj/item/weapon = source
		sharpness = weapon.get_sharpness()
	if(sharpness & SHARP_EDGED)
		return WOUND_SLASH
	if(sharpness & SHARP_POINTY)
		return WOUND_PIERCE
	return WOUND_BLUNT

/// The armour flag the hit is checked against.
/proc/hv_crit_attack_flag(atom/source)
	if(isprojectile(source))
		var/obj/projectile/shot = source
		return shot.armor_flag
	return MELEE

/// The hit's armour penetration.
/proc/hv_crit_armour_pen(atom/source)
	if(isprojectile(source))
		var/obj/projectile/shot = source
		return shot.armour_penetration
	if(isitem(source))
		var/obj/item/weapon = source
		return weapon.armour_penetration
	return 0

/// Best armour rating of armour_flag among the clothes covering limb, less armour_penetration.
/proc/hv_crit_cover_rating(mob/living/carbon/victim, obj/item/bodypart/limb, armour_flag, armour_penetration = 0)
	if(!ishuman(victim))
		return 0
	var/mob/living/carbon/human/human_victim = victim
	var/best = 0
	for(var/obj/item/clothing/worn as anything in human_victim.get_clothing_on_part(limb))
		best = max(best, worn.get_armor_rating(armour_flag))
	return best - armour_penetration

/// Roll bonus for a victim who cannot defend themselves.
/mob/living/proc/hv_crit_helpless_bonus(mob/living/attacker)
	. = 0
	if(incapacitated || body_position == LYING_DOWN || stat >= SOFT_CRIT)
		. += HV_CRIT_HELPLESS_BONUS
	if(attacker && attacker.pulling == src && attacker.grab_state >= GRAB_AGGRESSIVE)
		. += HV_CRIT_HELD_BONUS

/// The crit roll for this limb. tg's wound roll plus the battered and helpless bonuses, run
/// through check_woundings_mods() so wound armour and existing wounds count as they do for tg.
/obj/item/bodypart/proc/hv_crit_roll(wounding_type, damage, wound_bonus, exposed_wound_bonus, mob/living/attacker)
	var/easily_wounded = HAS_TRAIT(owner, TRAIT_EASILY_WOUNDED)
	var/hardly_wounded = HAS_TRAIT(owner, TRAIT_HARDLY_WOUNDED)
	if(easily_wounded && !hardly_wounded)
		damage *= 1.5
	else
		damage = min(damage, WOUND_MAX_CONSIDERED_DAMAGE)
	if(hardly_wounded && !easily_wounded)
		damage *= 0.85
	var/base_roll = rand(1, max(1, round(damage ** WOUND_DAMAGE_EXPONENT)))
	var/bonus = wound_bonus + round(HV_CRIT_BATTERED_BONUS * get_damage() / max(max_damage, 1)) + owner.hv_crit_helpless_bonus(attacker)
	return check_woundings_mods(wounding_type, base_roll, damage, bonus, exposed_wound_bonus, FALSE)

// ---------------------------------------------------------------------------------------------
// Entry point. Every damaging brute hit with a weapon or projectile behind it passes through
// here once, after tg has applied the damage and rolled its own wound for it.

/mob/living/apply_damage(
	damage = 0,
	damagetype = BRUTE,
	def_zone = null,
	blocked = 0,
	forced = FALSE,
	spread_damage = FALSE,
	wound_bonus = 0,
	exposed_wound_bonus = 0,
	sharpness = NONE,
	attack_direction = null,
	attacking_item,
	wound_clothing = TRUE,
)
	. = ..()
	if(. <= 0 || damagetype != BRUTE || forced || wound_bonus == CANT_WOUND || isnull(attacking_item) || QDELETED(src))
		return .
	hv_crit_check_hit(., def_zone, wound_bonus, exposed_wound_bonus, sharpness, attack_direction, attacking_item)
	return .

/// Decides whether this hit can be an aimed crit and rolls it. Only carbons and humanoid basic
/// mobs can take crits.
/mob/living/proc/hv_crit_check_hit(damage, def_zone, wound_bonus, exposed_wound_bonus, sharpness, attack_direction, atom/source)
	return

/mob/living/carbon/hv_crit_check_hit(damage, def_zone, wound_bonus, exposed_wound_bonus, sharpness, attack_direction, atom/source)
	if(!isbodypart(def_zone))
		return
	var/obj/item/bodypart/limb = def_zone
	if(limb.owner != src)
		return
	var/mob/living/carbon/attacker = hv_crit_get_aimer(source)
	if(isnull(attacker) || attacker == src)
		return
	var/wounding_type = hv_crit_wounding_type(sharpness, source)
	hv_try_aimed_crit(limb, attacker.zone_selected, wounding_type, damage, wound_bonus, exposed_wound_bonus, attack_direction || get_dir(attacker, src), source, attacker)

/**
 * Rolls every crit that fits this hit and applies the first one that lands. Returns that crit's
 * datum, or null.
 *
 * * limb - the limb that was hit
 * * aimed_zone - what the attacker had selected
 * * forced_roll - for tests: use this number instead of rolling
 */
/mob/living/carbon/proc/hv_try_aimed_crit(obj/item/bodypart/limb, aimed_zone, wounding_type, damage, wound_bonus, exposed_wound_bonus, attack_direction, atom/source, mob/living/attacker, forced_roll)
	if(check_zone(aimed_zone) != limb.body_zone)
		return null
	var/from_projectile = isprojectile(source)
	var/roll
	for(var/datum/hv_crit/crit as anything in GLOB.hv_crits)
		if(!crit.matches(limb.body_zone, aimed_zone, wounding_type, from_projectile))
			continue
		if(stat == DEAD && !crit.allow_dead)
			continue
		if(crit.blocked_on_carbon(src, limb, source))
			continue
		if(!crit.can_apply_carbon(src, limb, wounding_type))
			continue
		if(!crit.happens_anyway(src, limb))
			if(damage < crit.min_damage)
				continue
			if(isnull(roll))
				roll = isnull(forced_roll) ? limb.hv_crit_roll(wounding_type, damage, wound_bonus, exposed_wound_bonus, attacker) : forced_roll
			if(roll < crit.threshold)
				continue
		if(!crit.apply_carbon(src, limb, damage, attack_direction, source, attacker))
			continue
		log_combat(attacker, src, "landed an aimed crit on", source, "([crit.name], roll [isnull(roll) ? "none" : roll])")
		return crit
	return null

/mob/living/basic/hv_crit_check_hit(damage, def_zone, wound_bonus, exposed_wound_bonus, sharpness, attack_direction, atom/source)
	if(!(mob_biotypes & MOB_HUMANOID) || !(mob_biotypes & MOB_ORGANIC) || stat == DEAD)
		return
	var/mob/living/carbon/attacker = hv_crit_get_aimer(source)
	if(isnull(attacker) || attacker == src)
		return
	var/aimed_zone = attacker.zone_selected
	var/hit_zone = check_zone(aimed_zone)
	if(isprojectile(source))
		// Shots know where they landed; it has to be where they were aimed.
		if(check_zone(def_zone) != hit_zone)
			return
	else if(hit_zone != BODY_ZONE_CHEST && !prob(80))
		// Simple mobs have no limbs for a blow to stray onto, so give them the same 80% a carbon gets.
		return
	var/wounding_type = hv_crit_wounding_type(sharpness, source)
	hv_try_basic_crit(hit_zone, aimed_zone, wounding_type, damage, wound_bonus, attack_direction || get_dir(attacker, src), source, attacker)

/// The basic mob version of hv_try_aimed_crit(). No limbs and no worn armour, so the roll is the
/// same tg roll and bonuses with health standing in for limb damage.
/mob/living/basic/proc/hv_try_basic_crit(hit_zone, aimed_zone, wounding_type, damage, wound_bonus, attack_direction, atom/source, mob/living/attacker, forced_roll)
	var/from_projectile = isprojectile(source)
	var/roll
	for(var/datum/hv_crit/crit as anything in GLOB.hv_crits)
		if(!crit.matches(hit_zone, aimed_zone, wounding_type, from_projectile))
			continue
		if(!crit.can_apply_basic(src) || damage < crit.min_damage)
			continue
		if(isnull(roll))
			if(isnull(forced_roll))
				var/base_roll = rand(1, round(min(damage, WOUND_MAX_CONSIDERED_DAMAGE) ** WOUND_DAMAGE_EXPONENT))
				var/battered = round(HV_CRIT_BATTERED_BONUS * (1 - health / max(maxHealth, 1)))
				roll = (base_roll + wound_bonus + battered + hv_crit_helpless_bonus(attacker)) * (hit_zone == BODY_ZONE_CHEST ? 0.9 : 0.95)
			else
				roll = forced_roll
		if(roll < crit.threshold)
			continue
		if(!crit.apply_basic(src, damage, attack_direction, source, attacker))
			continue
		log_combat(attacker, src, "landed an aimed crit on", source, "([crit.name], roll [roll])")
		return crit
	return null

#undef HV_CRIT_BATTERED_BONUS
#undef HV_CRIT_HELPLESS_BONUS
#undef HV_CRIT_HELD_BONUS
