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
 * - With a wire out in each hand, every third landed hit in a row crosses both through the target: both wires
 *   lash out, and the sever takes a limb at half the usual damage.
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
	/// The zone this swing was aimed at, read when it began: the target doll, or what wire_aimed_swing() was told.
	var/cut_aim
	/// The next landed hit crosses, whatever the count (wire_crossing_swing()).
	var/force_cross = FALSE
	/// The body zone the last landed cut went into, for the lash drawn after the hit (wire_lash_at()).
	var/lash_zone
	/// Where the next lash lands off its usual point, list(x, y) in pixels: a crossing cut parts the two lines.
	var/list/lash_end_shift

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
	ADD_TRAIT(target, TRAIT_HV_CLEAN_CUT, REF(src))
	RegisterSignal(target, COMSIG_MOB_AFTER_APPLY_DAMAGE, PROC_REF(on_cut), override = TRUE)

/// Closes the cut on `target`.
/obj/item/melee/cyberware_monowire/proc/wire_cut_end(mob/living/target)
	if(isliving(target))
		UnregisterSignal(target, COMSIG_MOB_AFTER_APPLY_DAMAGE)
		REMOVE_TRAIT(target, TRAIT_HV_CLEAN_CUT, REF(src))
		target.hv_wire_owed_sever = null
	cutting = null
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
	var/obj/item/bodypart/cut_part = isbodypart(def_zone) ? def_zone : null
	lash_zone = cut_part ? cut_part.body_zone : check_zone(def_zone)
	var/cross = wire_count_landed(user)
	if(cross)
		wire_cross_lash(user, source)
	if(wire_try_sever(source, user, def_zone, damage_dealt, attack_direction || get_dir(user, source), cross))
		// The cut shows when the limb slides off (wire_sever_fx.dm), and the wire comes away wet then too.
		addtimer(CALLBACK(src, PROC_REF(wire_bloody), source), WIRE_CUT_DELAY)
	else
		wire_bloody(source, def_zone)
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

/// The other wire's lash in a crossing cut follows this wire's by this much.
#define WIRE_CROSS_LASH_LAG (0.1 SECONDS)
/// Pixels each crossing lash lands off the cut, one each way.
#define WIRE_CROSS_PART 5

/**
 * The crossing cut: the other hand's wire lashes into the target beside this one's, a beat after it. Seen side on
 * the hands are a few pixels apart, so the two lines land apart too, each on its own hand's side: two lines, not one.
 */
/obj/item/melee/cyberware_monowire/proc/wire_cross_lash(mob/living/swinger, mob/living/target)
	swinger.mob_light(2, 1, cross_light_color(), 0.3 SECONDS)
	var/list/own_hand = wire_hand_point(swinger, held_side(swinger) || "right")
	for(var/obj/item/melee/cyberware_monowire/other in swinger.held_items)
		if(other == src)
			continue
		var/list/other_hand = wire_hand_point(swinger, other.held_side(swinger) || "left")
		var/list/shift = wire_cross_shift(own_hand, other_hand)
		lash_end_shift = shift
		addtimer(CALLBACK(other, PROC_REF(wire_lash_at), swinger, target, lash_zone, list(-shift[1], -shift[2])), WIRE_CROSS_LASH_LAG)
	playsound(target, 'sound/items/weapons/bladeslice.ogg', 60, TRUE)

/// How far from the cut the lash from `hand` lands, list(x, y), when the other hand's lash (from `other_hand`) lands as
/// far the other way: apart the way the hands are apart, more along the line between them that is shorter.
/proc/wire_cross_shift(list/hand, list/other_hand)
	var/dx = hand[1] - other_hand[1]
	var/dy = hand[2] - other_hand[2]
	// Side by side (a body facing toward or away): the lines already meet in a V.
	if(abs(dx) > 8)
		return list(0, 0)
	return list(0, dy >= 0 ? WIRE_CROSS_PART : -WIRE_CROSS_PART)

/obj/item/melee/cyberware_monowire/proc/cross_light_color()
	return "#ff8cf8"

/obj/item/melee/cyberware_monowire/live/cross_light_color()
	return "#9fe4ff"

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
	// tg pulls the shoes off a leg that comes off; they go with the leg.
	var/obj/item/shoes = (zone == BODY_ZONE_L_LEG || zone == BODY_ZONE_R_LEG) && ishuman(victim) ? victim.get_item_by_slot(ITEM_SLOT_FEET) : null
	// No blood on the floor yet: it starts when the limb slides off (wire_ghost/slide()).
	ADD_TRAIT(victim, TRAIT_HV_CLEAN_CUT, "wire_sever")
	var/obj/item/bodypart/severed = hv_wire_take_part(limb, seared ? WOUND_BURN : WOUND_SLASH, seared ? WIRE_ARC_BLEED_MULT : 1, splatter = FALSE)
	REMOVE_TRAIT(victim, TRAIT_HV_CLEAN_CUT, "wire_sever")
	if(!severed)
		LAZYREMOVE(victim.hv_stump_reveal_at, zone)
		LAZYREMOVE(victim.hv_stump_burnt, zone)
		qdel(ghost)
		return null
	if(seared)
		severed.wire_char()
	else
		severed.wire_clean_look()
	ghost?.hold_severed(severed)
	if(shoes)
		ghost?.hold_shoes(shoes)
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

#undef WIRE_CROSS_LASH_LAG
#undef WIRE_CROSS_PART
