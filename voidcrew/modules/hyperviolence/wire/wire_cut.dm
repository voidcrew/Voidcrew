/**
 * # The Widowline's cut
 *
 * What a landed wire swing does to the bodies it passes through, on top of its damage
 * (cyberware/ware_military_arms.dm):
 * - It cuts clean (wire_seams.dm): no fan of blood, a thin line and a few drops.
 * - An aimed cut takes off an arm or leg that is already badly hurt (WIRE_SEVER_AT of its max damage before
 *   the hit), or less hurt on someone already down (WIRE_SEVER_AT_DOWN). Never a corpse, never through an
 *   Atlas frame (tg's can_dismember()), never an ally. The limb is off at the hit; it stays drawn on for a
 *   beat and slides off after (wire_sever_fx.dm).
 * - The Arc's charged wire sears the stump shut: little blood, no spray (wire_sever_fx.dm).
 * - It carries on into whoever stands right behind the target, and cleaves everyone else beside it, all as
 *   lines of the one hit message. Hurting someone at a trader outpost this way counts as an attack there.
 * - With a wire out in each hand, every third landed hit in a row crosses both through the target: an X of
 *   light, and the sever takes a limb at half the usual damage.
 * - The aimed sever, the crossing cut and the garrote are the wielder's moves, open to whoever
 *   hv_wire_moves_allowed() lets use them (wire_users.dm); the rest belongs to the weapon.
 *
 * The hooks run inside the hit: wire_cut_begin() before the parent attack(), on_cut() from the target's
 * own damage signal while tg resolves it, wire_cut_end() after.
 */

/obj/item/melee/cyberware_monowire
	/// The body this swing is cutting, from wire_cut_begin() to wire_cut_end().
	var/mob/living/cutting
	/// Whether that body was already dead when the swing began.
	var/cut_on_corpse = FALSE
	/// Whether that body was already down when the swing began.
	var/cut_on_downed = FALSE
	/// This swing will cross both wires through the target if it lands.
	var/crossing = FALSE
	/// The zone this swing was aimed at, read when it began: the target doll, or what wire_aimed_swing() was told.
	var/cut_aim
	/// The next landed hit crosses, whatever the count (wire_crossing_swing()).
	var/force_cross = FALSE

/mob/living
	/// Landed Widowline hits in a row with a wire out in each hand, and when the last one landed.
	var/wire_cross_hits = 0
	var/wire_cross_last = 0

/// Opens the cut on `target`: it cuts clean, and the damage signal tells us where it landed.
/obj/item/melee/cyberware_monowire/proc/wire_cut_begin(mob/living/target, mob/living/user)
	if(!isliving(target) || !isliving(user) || QDELETED(target))
		return
	cutting = target
	cut_on_corpse = target.stat == DEAD
	cut_on_downed = hv_finisher_is_down(target)
	cut_aim = user.zone_selected
	crossing = wire_cross_due(user)
	ADD_TRAIT(target, TRAIT_HV_CLEAN_CUT, REF(src))
	RegisterSignal(target, COMSIG_MOB_AFTER_APPLY_DAMAGE, PROC_REF(on_cut), override = TRUE)

/// Closes the cut on `target`.
/obj/item/melee/cyberware_monowire/proc/wire_cut_end(mob/living/target)
	if(isliving(target))
		UnregisterSignal(target, COMSIG_MOB_AFTER_APPLY_DAMAGE)
		REMOVE_TRAIT(target, TRAIT_HV_CLEAN_CUT, REF(src))
		target.hv_wire_owed_sever = null
	cutting = null
	crossing = FALSE
	cut_aim = null

/// The swing landed: the wire's brute damage was just applied to `source`.
/obj/item/melee/cyberware_monowire/proc/on_cut(mob/living/source, damage_dealt, damagetype, def_zone, blocked, wound_bonus, exposed_wound_bonus, sharpness, attack_direction, attacking_item, wound_clothing)
	SIGNAL_HANDLER
	if(source != cutting || attacking_item != src || damagetype != BRUTE)
		return
	// One cut per swing: the burn rider and anything the hit sets off are not cuts.
	UnregisterSignal(source, COMSIG_MOB_AFTER_APPLY_DAMAGE)
	var/mob/living/user = loc
	if(!isliving(user))
		return
	var/cross = wire_count_landed(user)
	if(cross && !crossing)
		wire_play_cross(user, source)
	wire_bloody(source, def_zone)
	wire_try_sever(source, user, def_zone, damage_dealt, attack_direction || get_dir(user, source), cross)
	wire_cleave(source, user)

// ---- The crossing cut ----

/// How many Widowlines `user` has out.
/proc/wire_count_held(mob/living/user)
	. = 0
	for(var/obj/item/melee/cyberware_monowire/wire in user.held_items)
		.++

/// Whether the next landed hit is the crossing one.
/obj/item/melee/cyberware_monowire/proc/wire_cross_due(mob/living/user)
	if(!hv_wire_moves_allowed(user) || wire_count_held(user) < 2)
		return FALSE
	if(force_cross)
		return TRUE
	return user.wire_cross_hits >= WIRE_CROSS_HITS - 1 && world.time - user.wire_cross_last <= WIRE_CROSS_WINDOW

/// Counts a landed hit. Returns TRUE if it is the crossing one.
/obj/item/melee/cyberware_monowire/proc/wire_count_landed(mob/living/user)
	if(wire_count_held(user) < 2 || !hv_wire_moves_allowed(user))
		user.wire_cross_hits = 0
		return FALSE
	if(force_cross)
		user.wire_cross_hits = 0
		return TRUE
	if(world.time - user.wire_cross_last > WIRE_CROSS_WINDOW)
		user.wire_cross_hits = 0
	user.wire_cross_hits++
	user.wire_cross_last = world.time
	if(user.wire_cross_hits < WIRE_CROSS_HITS)
		return FALSE
	user.wire_cross_hits = 0
	return TRUE

/// The X of light over the target, mirrored to the side the blow came from.
/obj/item/melee/cyberware_monowire/proc/wire_play_cross(atom/movable/attacker, atom/movable/target)
	var/obj/effect/abstract/cyberware_anim/cross = cyberware_anim_play(target, WIRE_GORE_ICON, cross_state(), WIRE_FX_LAYER, 0.5 SECONDS, glow = TRUE)
	if(!cross)
		return null
	cross.appearance_flags |= RESET_TRANSFORM
	if(get_dir(attacker, target) & WEST)
		cross.transform = matrix(-1, 0, 0, 0, 1, 0)
	if(isliving(attacker))
		var/mob/living/swinger = attacker
		swinger.mob_light(2, 1, cross_light_color(), 0.3 SECONDS)
		// Both wires go through: the other hand's lashes out too, beside this one's.
		for(var/obj/item/melee/cyberware_monowire/other in swinger.held_items)
			if(other == src)
				continue
			cyberware_monowire_lash_fx(swinger, target, origin_offset_x = 5)
			other.hide_inhand_for(0.5 SECONDS)
	playsound(target, 'sound/items/weapons/bladeslice.ogg', 60, TRUE)
	return cross

/obj/item/melee/cyberware_monowire/proc/cross_state()
	return "impact_widowline_cross"

/obj/item/melee/cyberware_monowire/proc/cross_light_color()
	return "#ff8cf8"

/obj/item/melee/cyberware_monowire/live/cross_state()
	return "impact_arc_cross"

/obj/item/melee/cyberware_monowire/live/cross_light_color()
	return "#9fe4ff"

// The crossing swing shows its X instead of the single wire's impact.
/obj/item/melee/cyberware_monowire/animate_attack(atom/movable/attacker, atom/attacked_atom, animation_type)
	if(crossing && ismovable(attacked_atom) && wire_play_cross(attacker, attacked_atom))
		return
	return ..()

/obj/item/melee/cyberware_monowire/live/animate_attack(atom/movable/attacker, atom/attacked_atom, animation_type)
	if(crossing && ismovable(attacked_atom) && wire_play_cross(attacker, attacked_atom))
		return
	return ..()

// ---- Severing ----

/// Whether this wire may take `limb` off: an arm or leg, on a body that was alive when the swing began
/// (`corpse`), that can lose it (an Atlas frame can't), and that isn't the wielder's ally.
/obj/item/melee/cyberware_monowire/proc/wire_can_sever(obj/item/bodypart/limb, mob/living/user, corpse)
	if(isnull(corpse))
		corpse = cut_on_corpse
	var/mob/living/carbon/victim = limb?.owner
	if(!victim || corpse || !(limb.body_zone in GLOB.hv_wire_sever_zones))
		return FALSE
	if(!limb.can_dismember() || HAS_TRAIT(victim, TRAIT_GODMODE))
		return FALSE
	return !cyberware_is_ally(user, victim)

/**
 * Takes the limb the cut landed on, if it was aimed there and was hurt enough before the hit, or the limb tg's
 * own roll wanted off this hit. Returns the severed limb, or null.
 */
/obj/item/melee/cyberware_monowire/proc/wire_try_sever(mob/living/source, mob/living/user, def_zone, damage_dealt, spray_dir, cross)
	if(!iscarbon(source))
		return null
	var/mob/living/carbon/victim = source
	var/obj/item/bodypart/owed = victim.hv_wire_owed_sever
	victim.hv_wire_owed_sever = null
	if(owed?.owner == victim && wire_can_sever(owed, user))
		return wire_sever(owed, user, spray_dir, cross)
	// The aimed sever is a move of the wielder's (wire_users.dm); tg's own roll above is the weapon's.
	if(!hv_wire_moves_allowed(user))
		return null
	var/obj/item/bodypart/limb = isbodypart(def_zone) ? def_zone : victim.get_bodypart(check_zone(def_zone))
	if(!limb || limb.owner != victim || check_zone(cut_aim) != limb.body_zone)
		return null
	if(!wire_can_sever(limb, user))
		return null
	var/needed = cut_on_downed ? WIRE_SEVER_AT_DOWN : WIRE_SEVER_AT
	if(cross)
		needed = needed * WIRE_CROSS_SEVER_SHARE / 100
	if(round((limb.get_damage() - damage_dealt) * 100) < round(limb.max_damage * needed))
		return null
	return wire_sever(limb, user, spray_dir, cross)

// Its full penetration is for its cuts. At #509's crit gates a collar, helmet or plating counts against it as
// against any blade (owner D33): the crit roll treats it as no penetration at all.
/obj/item/melee/cyberware_monowire/hv_crit_armour_pen()
	return 0

/// Whether this wire sears what it cuts on `victim` shut. Only the Arc's charge, and only where its shock reaches.
/obj/item/melee/cyberware_monowire/proc/wire_sears(mob/living/victim)
	return FALSE

/obj/item/melee/cyberware_monowire/live/wire_sears(mob/living/victim)
	return !HAS_TRAIT(victim, TRAIT_SHOCKIMMUNE)

/**
 * Takes `limb` off at the hit. The body is real at once (the arm is gone, its hand's grip with it); the picture
 * lags: the limb stays drawn on until it slides off (wire_sever_fx.dm). Returns the severed limb, or null.
 */
/obj/item/melee/cyberware_monowire/proc/wire_sever(obj/item/bodypart/limb, mob/living/user, spray_dir, cross)
	var/mob/living/carbon/victim = limb.owner
	var/zone = limb.body_zone
	var/zone_name = limb.plaintext_zone
	var/seared = wire_sears(victim)
	// Drawn while the limb is still on, so it can be held there.
	var/obj/effect/abstract/cyberware_anim/wire_ghost/ghost = wire_ghost_limb(victim, limb, seared, spray_dir)
	LAZYSET(victim.hv_stump_reveal_at, zone, world.time + WIRE_CUT_DELAY)
	if(seared)
		LAZYSET(victim.hv_stump_burnt, zone, TRUE)
	var/obj/item/bodypart/severed = hv_wire_take_part(limb, seared ? WOUND_BURN : WOUND_SLASH, seared ? WIRE_ARC_BLEED_MULT : 1, !seared)
	if(!severed)
		LAZYREMOVE(victim.hv_stump_reveal_at, zone)
		LAZYREMOVE(victim.hv_stump_burnt, zone)
		qdel(ghost)
		return null
	if(seared)
		severed.wire_char()
	ghost?.hold_severed(severed)
	wire_seam_fx(victim, zone, seared)
	if(seared)
		victim.hv_add_hit_line("[victim]'s [zone_name] drops away, the stump seared shut!", HV_LINE_HUGE, "Your [zone_name] drops away, the stump seared shut!", DEFAULT_MESSAGE_RANGE)
	else
		victim.hv_add_hit_line("[victim]'s [zone_name] comes away clean!", HV_LINE_HUGE, "Your [zone_name] comes away clean!", DEFAULT_MESSAGE_RANGE)
	log_combat(user, victim, "severed the [zone_name] of", src, cross ? "(crossing cut)" : null)
	return severed

// ---- Through and around ----

/**
 * The wire carries on past the target: whoever stands right behind it (along the swing) takes the through-cut,
 * a line of light then blood through both bodies; anyone else beside the target takes the plain cleave. Both
 * deal the wire's cleave share and cut clean. Lines join the hit's message.
 */
/obj/item/melee/cyberware_monowire/proc/wire_cleave(mob/living/target, mob/living/user)
	var/direction = get_dir(user, target) || user.dir
	var/turf/target_turf = get_step(target, direction)
	var/mob/living/behind
	var/cleaved = FALSE
	for(var/mob/living/nearby in orange(1, target))
		if(nearby == user || nearby == target || nearby.stat == DEAD)
			continue
		if(!can_see(target, nearby, 1))
			continue
		if(cyberware_is_ally(user, nearby))
			continue
		wire_cleave_cut(nearby, user)
		if(QDELETED(nearby))
			continue
		if(!behind && get_turf(nearby) == target_turf)
			behind = nearby
		else
			to_chat(nearby, span_userdanger("[user]'s monowire carries through into you!"))
			cleaved = TRUE
	if(behind)
		wire_through_fx(target, behind, direction)
		target.hv_add_hit_line("The wire carries through into [behind]!", HV_LINE_BOLD)
		to_chat(behind, span_userdanger("The wire carries through into you!"))
	if(cleaved)
		target.hv_add_hit_line("The wire sings through everything beside [target]!")
	if(behind || cleaved)
		playsound(target, 'sound/items/weapons/bladeslice.ogg', 50, TRUE)

/// One cleave cut on `nearby`: both halves of the wire's damage at the cleave share, one armour roll, cut clean.
/obj/item/melee/cyberware_monowire/proc/wire_cleave_cut(mob/living/nearby, mob/living/user)
	// A cleave is an attack like the swing itself, so trader outposts see it.
	GLOB.outpost_pvp_enforcement?.register_pvp_aggression(nearby, user)
	var/cleave_block = nearby.run_armor_check(BODY_ZONE_CHEST, MELEE, armour_penetration = armour_penetration)
	ADD_TRAIT(nearby, TRAIT_HV_CLEAN_CUT, REF(src))
	nearby.apply_damage(force * cleave_mult, BRUTE, BODY_ZONE_CHEST, cleave_block, wound_bonus = wound_bonus, sharpness = SHARP_EDGED, attack_direction = get_dir(user, nearby))
	if(!QDELETED(nearby))
		nearby.apply_damage(charge_burn * cleave_mult, BURN, BODY_ZONE_CHEST, cleave_block)
	if(QDELETED(nearby))
		return
	REMOVE_TRAIT(nearby, TRAIT_HV_CLEAN_CUT, REF(src))
	// tg's roll may have wanted a limb: it comes off clean, as it would have come off anyway.
	var/obj/item/bodypart/owed = nearby.hv_wire_owed_sever
	nearby.hv_wire_owed_sever = null
	if(owed?.owner == nearby && wire_can_sever(owed, user, corpse = FALSE))
		wire_sever(owed, user, get_dir(user, nearby), FALSE)
