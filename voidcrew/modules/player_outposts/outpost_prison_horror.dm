/**
 * # The horror
 *
 * What the changeling experiment's headslug grows into if nobody wrenches it out of the vents
 * (outpost_prison_changeling.dm): a person-shaped thing in black changeling chitin, an arm blade on
 * one arm and a bone shield on the other. A mini boss. Numbers are in
 * voidcrew/_DEFINES/outpost_prison_changeling.dm.
 *
 * It is a basic mob, not megafauna and not /mob/living/basic/boss: the outpost megafauna ban
 * (voidcrew/area/megafauna_ban.dm) would delete either the moment it entered the wing, and
 * turrets and plenty of helpers treat carbons as people. It wears tg's changeling items for the
 * look only (apply_dynamic_human_appearance()); its armour is a damage coefficient.
 *
 * Its kit, lich style: mob actions it uses on its own cooldowns, never two within
 * OUTPOST_HORROR_ABILITY_GAP of each other, each with a windup that shows where it lands:
 * - resonant shriek, from the start: confuses and jitters everyone who hears it, breaks lights;
 * - dissonant shriek, after the first absorb: drains energy weapons, silences headsets, breaks
 *   lights. It never opens doors or hits APCs and machines;
 * - fleshmend, after the second: below 60% health it kneels and knits for eight seconds, taking
 *   more damage meanwhile. Enough damage, or fire, breaks it;
 * - tentacle grip, after the third: a line to someone far off, then a tentacle along it that pulls
 *   them in, knocks them down and impales them. Step off the line.
 * Later absorbs only heal.
 *
 * Absorb: anyone human-shaped who is dead or down on the outpost's ground (prisoners, crew and
 * visitors alike) in three beats over OUTPOST_HORROR_ABSORB_TIME: the grab, the proboscis, the
 * husk. Enough damage, fire, or dragging the victim off their tile breaks it and staggers it.
 * Every absorb heals it to full and makes it a little bigger. Absorbing a non-member is logged to
 * admins. Ambient NPCs are killed, never absorbed.
 *
 * Its shield turns aside a quarter of the hits that come at its face, never from the side or back.
 * Fire hurts it double, standing or down (take_fire_damage()), and set alight it keeps burning for a
 * few seconds. Its burning counts as the crew's for the containment bonus when a player lit it or
 * hurt it lately (fire_credit()).
 * Doors that will not open for it, it pries; kept from its quarry, it breaks interior windows
 * toward them. It never breaches the prison wing's outer ring, never a wall or window with
 * anything but the outpost's own floor beyond, and never steps off the outpost's ground.
 *
 * It regenerates. At 0 health it collapses, but its flesh keeps moving: it lies on the floor unable
 * to act or absorb, turrets leave it alone, and after OUTPOST_HORROR_REGEN_TIME (counted only while
 * a member of the wing is home) it gets up with half its health and fights on. To kill it for good,
 * destroy the body while it is down (OUTPOST_HORROR_REMAINS more damage, and it bursts), gib or dust
 * it, or space it: drag, push or throw its body off the outpost into open space (a space tile in
 * none of the outpost's areas), where it freezes the moment it arrives. A vented room inside the
 * outpost does not count; it regenerates there as anywhere else. The containment bonus and the end
 * of the experiment come only with that final death. The first collapse is announced to the
 * outpost; prisoners go on hiding while it is down.
 */

/// Trait source for standing still: unfolding, winding up, channelling, staggered or prying
#define HORROR_BUSY_TRAIT "outpost_horror_busy"
/// Trait source for holding an absorb victim still
#define HORROR_GRIP_TRAIT "outpost_horror_grip"
/// The pulsing outline it has while it lies regenerating
#define HORROR_REGEN_FILTER "outpost_horror_regen"
/// The pale blue it turns, and what is seen, when it freezes out in space
#define HORROR_FROZEN_COLOUR "#a8c8f0"
#define HORROR_SPACED_MESSAGE "freezes solid in the cold of space, and its flesh stops moving."
/// The horror's faction: it fights everything else
#define FACTION_OUTPOST_HORROR "outpost_horror"
/// Blackboard keys
#define BB_OUTPOST_HORROR_ABILITY "BB_outpost_horror_ability"
#define BB_OUTPOST_HORROR_ABILITY_TARGET "BB_outpost_horror_ability_target"
#define BB_OUTPOST_HORROR_BODY "BB_outpost_horror_body"
#define BB_OUTPOST_HORROR_BARRIER "BB_outpost_horror_barrier"
#define BB_OUTPOST_HORROR_PREY "BB_outpost_horror_prey"
#define BB_OUTPOST_HORROR_HUNT_AT "BB_outpost_horror_hunt_at"

/datum/outfit/outpost_changeling_horror
	name = "Outpost changeling horror"
	suit = /obj/item/clothing/suit/armor/changeling
	head = /obj/item/clothing/head/helmet/changeling

/mob/living/basic/outpost_experiment/horror
	name = "horror"
	desc = "Something that used to be a person, now wrapped in glistening black chitin. One arm ends in a bone blade, the other in a shield of fused fingers."
	icon = 'icons/mob/simple/simple_human.dmi'
	gender = NEUTER
	mob_biotypes = MOB_ORGANIC | MOB_HUMANOID
	footstep_kind = FOOTSTEP_MOB_HEAVY
	footstep_volume = 0.8
	footstep_range = -5
#ifndef OUTPOST_EXPERIMENT_API
	// With S4a, the experiment creatures' OUTPOST_EXPERIMENT_NO_SENTIENCE: no potion or injector takes it.
	sentience_type = SENTIENCE_BOSS
#endif
	maxHealth = OUTPOST_HORROR_BASE_HEALTH
	health = OUTPOST_HORROR_BASE_HEALTH
	speed = OUTPOST_HORROR_SPEED
	damage_coeff = list(BRUTE = OUTPOST_HORROR_DAMAGE_COEFF, BURN = OUTPOST_HORROR_DAMAGE_COEFF, TOX = 0, STAMINA = 0, OXY = 0)
	melee_damage_lower = OUTPOST_HORROR_BLADE_DAMAGE
	melee_damage_upper = OUTPOST_HORROR_BLADE_DAMAGE
	melee_attack_cooldown = OUTPOST_HORROR_BLADE_COOLDOWN
	armour_penetration = OUTPOST_HORROR_BLADE_AP
	attack_verb_continuous = "slashes"
	attack_verb_simple = "slash"
	attack_sound = 'sound/items/weapons/bladeslice.ogg'
	attack_vis_effect = ATTACK_EFFECT_SLASH
	combat_mode = TRUE
	faction = list(FACTION_OUTPOST_HORROR)
	// Its own staggers are the only ones: batons and shoves do not stunlock a boss.
	status_flags = NONE
	mob_size = MOB_SIZE_LARGE
	move_force = MOVE_FORCE_VERY_STRONG
	move_resist = MOVE_FORCE_VERY_STRONG
	pull_force = MOVE_FORCE_VERY_STRONG
	// Doors and windows go through its own rules, never its blows.
	obj_damage = 0
	environment_smash = ENVIRONMENT_SMASH_NONE
	unsuitable_atmos_damage = 0
	unsuitable_cold_damage = 0
	unsuitable_heat_damage = 0
	// It catches fire, which breaks an absorb or a mend, and burns it (on_fire_stack()): it has no heat
	// damage for tg's fire to work through. It burns for a few seconds, not the moment most basic mobs get.
	basic_mob_flags = FLAMMABLE_MOB
	fire_stack_decay_rate = OUTPOST_HORROR_FIRE_DECAY
	mobility_flags = MOBILITY_FLAGS_REST_CAPABLE_DEFAULT
	rotate_on_lying = TRUE
	blood_volume = BLOOD_VOLUME_NORMAL
	speak_emote = list("shrieks")
	death_message = "shudders, and the chitin splits open down its back. It goes still."
	death_sound = 'sound/effects/magic/demon_dies.ogg'
	mouse_opacity = MOUSE_OPACITY_OPAQUE
	ai_controller = /datum/ai_controller/basic_controller/outpost_horror

	/// The experiment it came out of
	var/datum/outpost_changeling_event/event
	/// Its kit: key -> ability, granted one absorb at a time
	var/list/abilities = list()
	/// People absorbed so far
	var/absorbs = 0
	/// Standing still for something: "unfold", "windup", "absorb", "fleshmend", "stagger", "digest" or "pry"
	var/busy
	/// Bumped each time `busy` changes, so a stale timer knows it is stale
	var/busy_serial = 0
	var/busy_timer
	/// world.time before which no ability may start
	var/next_ability_at = 0
	/// world.time before which it cannot absorb again
	var/next_absorb_at = 0
	/// The absorb under way: the victim, where they lie, and the damage taken since it began
	var/mob/living/absorbing
	var/turf/absorb_turf
	var/channel_damage = 0
	/// tg's changeling absorb sounds, looping while the proboscis drains its victim
	var/datum/looping_sound/changeling_absorb/absorb_loop
	/// Seconds of fleshmend left
	var/mend_left = 0
	/// Who hurt it last, and when
	var/datum/weakref/last_attacker_ref
	var/last_attacked_at = 0
	/// Who it is after, and how close it has got: kept away for OUTPOST_HORROR_BREACH_AFTER, it breaks through
	var/datum/weakref/quarry_ref
	var/closest_to_quarry = INFINITY
	var/closing_since = 0
	/// Down at 0 health and regenerating: not dead, and up again after OUTPOST_HORROR_REGEN_TIME
	var/regenerating = FALSE
	/// Seconds until it gets up; they count only while a member of the wing is home
	var/regen_left = 0
	/// Damage its body can still take while it is down before it bursts
	var/remains = 0
	/// Seconds to its next twitch while it is down
	var/stasis_tell_left = 0
	/// It has warned, while down, that it is getting up
	var/rise_warned = FALSE
	/// The next death() is for good: an admin's kill, open space, or its body destroyed
	var/final_death = FALSE
	/// The last player who aimed a lit flamethrower at it, and when
	var/datum/weakref/fire_aimer_ref
	var/fire_aimed_at = 0
	/// The player who set it alight this time, if it could tell (on_ignited())
	var/datum/weakref/igniter_ref

/mob/living/basic/outpost_experiment/horror/Initialize(mapload)
	. = ..()
	// Its own numbers, whatever the experiment creatures it is filed under start with; emerge_for() scales them.
	maxHealth = OUTPOST_HORROR_BASE_HEALTH
	health = OUTPOST_HORROR_BASE_HEALTH
	add_traits(list(TRAIT_NOBREATH, TRAIT_RESISTLOWPRESSURE, TRAIT_RESISTHIGHPRESSURE), INNATE_TRAIT)
	ban_from_containment()
#ifndef OUTPOST_EXPERIMENT_API
	// With S4a, the experiment creatures' Initialize() calls build_look(), below.
	build_horror_look()
#endif
	AddElement(/datum/element/relay_attackers)
	RegisterSignal(src, COMSIG_ATOM_WAS_ATTACKED, PROC_REF(on_attacked), override = TRUE)
	RegisterSignal(src, COMSIG_MOVABLE_TELEPORTING, PROC_REF(refuse_horror_teleport), override = TRUE)
	RegisterSignal(src, COMSIG_LIVING_PRE_WABBAJACKED, PROC_REF(refuse_horror_polymorph), override = TRUE)
	RegisterSignal(src, COMSIG_PRE_MOB_CHANGED_TYPE, PROC_REF(refuse_horror_type_change), override = TRUE)
	RegisterSignal(src, COMSIG_MOVABLE_PRE_MOVE, PROC_REF(check_ground), override = TRUE)
	RegisterSignal(src, COMSIG_MOVABLE_MOVED, PROC_REF(on_moved), override = TRUE)
	RegisterSignal(src, COMSIG_MOVABLE_BUMP, PROC_REF(on_bump), override = TRUE)
	RegisterSignal(src, COMSIG_LIVING_CHECK_BLOCK, PROC_REF(on_check_block), override = TRUE)
	RegisterSignal(src, COMSIG_ATOM_PRE_BULLET_ACT, PROC_REF(on_pre_bullet_act), override = TRUE)
	RegisterSignal(src, COMSIG_LIVING_IGNITED, PROC_REF(on_ignited), override = TRUE)
	RegisterSignal(src, COMSIG_ATOM_RANGED_ITEM_INTERACTION, PROC_REF(on_ranged_item_used), override = TRUE)
	RegisterSignal(src, COMSIG_LIVING_REVIVE, PROC_REF(on_revived), override = TRUE)
	grant_ability("resonant", /datum/action/cooldown/mob_cooldown/outpost_horror/resonant_shriek)

/mob/living/basic/outpost_experiment/horror/Destroy()
	end_absorb()
	deltimer(busy_timer)
	busy_timer = null
	QDEL_LIST_ASSOC_VAL(abilities)
	event = null
	last_attacker_ref = null
	quarry_ref = null
	absorb_turf = null
	fire_aimer_ref = null
	igniter_ref = null
	return ..()

/**
 * Out of the vent for `new_event`: health for the players about (`extra_players` beyond the first),
 * then it unfolds, unable to act, and its first act is a resonant shriek.
 */
/mob/living/basic/outpost_experiment/horror/proc/emerge_for(datum/outpost_changeling_event/new_event, extra_players = 0)
	event = new_event
	var/scaled = OUTPOST_HORROR_BASE_HEALTH + OUTPOST_HORROR_HEALTH_PER_PLAYER * clamp(extra_players, 0, OUTPOST_HORROR_EXTRA_PLAYERS_MAX)
	maxHealth = scaled
	health = scaled
	adjust_health(-bruteloss)
	playsound(src, 'sound/effects/magic/mutate.ogg', 90, TRUE, 6)
	set_busy("unfold", OUTPOST_HORROR_UNFOLD_TIME)
	addtimer(CALLBACK(src, PROC_REF(first_shriek)), OUTPOST_HORROR_UNFOLD_TIME, TIMER_DELETE_ME)

/// Unfolded: the lights go out as the fight starts
/mob/living/basic/outpost_experiment/horror/proc/first_shriek()
	if(stat == DEAD)
		return
	if(busy == "unfold")
		clear_busy()
	var/datum/action/cooldown/mob_cooldown/outpost_horror/shriek = abilities["resonant"]
	shriek?.Trigger(target = src)

/// Black chitin, the arm blade and the shield: tg's changeling items, for the look only
/mob/living/basic/outpost_experiment/horror/proc/build_horror_look()
	apply_dynamic_human_appearance(src, /datum/outfit/outpost_changeling_horror, /datum/species/human, null, /obj/item/melee/arm_blade, /obj/item/shield/changeling)

#ifdef OUTPOST_EXPERIMENT_API
/mob/living/basic/outpost_experiment/horror/build_look(outfit_path)
	build_horror_look()
#endif

// ===== CONTAINMENT =====

/mob/living/basic/outpost_experiment/horror/proc/refuse_horror_teleport(datum/source, atom/destination, channel)
	SIGNAL_HANDLER
	return TRUE

/mob/living/basic/outpost_experiment/horror/proc/refuse_horror_polymorph(datum/source, what_to_randomize)
	SIGNAL_HANDLER
	return STOP_WABBAJACK

/mob/living/basic/outpost_experiment/horror/proc/refuse_horror_type_change(datum/source)
	SIGNAL_HANDLER
	return COMPONENT_BLOCK_MOB_CHANGE

/**
 * Never a step off the outpost's ground: no docked ships, no space. The one way off is for its body,
 * down and regenerating, to be dragged, pushed or thrown out into open space, where it dies
 * (on_moved()). Never onto a ship or any other ground.
 */
/mob/living/basic/outpost_experiment/horror/proc/check_ground(datum/source, atom/new_loc)
	SIGNAL_HANDLER
	if(!isturf(new_loc) || !event)
		return NONE
	if(!event.on_outpost_ground(loc) || event.on_outpost_ground(new_loc))
		return NONE
	if(can_be_spaced() && event.in_open_space(new_loc))
		return NONE
	return COMPONENT_MOVABLE_BLOCK_PRE_MOVE

/mob/living/basic/outpost_experiment/horror/can_be_revived()
	return FALSE

/mob/living/basic/outpost_experiment/horror/proc/on_revived(datum/source, full_heal_flags)
	SIGNAL_HANDLER
	INVOKE_ASYNC(src, PROC_REF(collect_remains))

/**
 * At 0 health it goes down regenerating (start_regenerating()) instead of dying, wherever it is on
 * the outpost, vented rooms included. While it is down, every update of its health lands here again
 * and changes nothing. It dies for good when gibbed or dusted, after die_for_good(), or when it
 * collapses out in open space off the outpost, where a downed body could not lie regenerating anyway.
 */
/mob/living/basic/outpost_experiment/horror/death(gibbed)
	if(stat != DEAD && !gibbed && !final_death)
		if(regenerating)
			return FALSE
		if(!in_open_space())
			start_regenerating()
			return FALSE
		final_death = TRUE
		add_atom_colour(HORROR_FROZEN_COLOUR, FIXED_COLOUR_PRIORITY)
		death_message = HORROR_SPACED_MESSAGE
	end_absorb()
	mend_left = 0
	clear_busy()
	// Still `regenerating` while the death signal goes out, so a gib counts what was left of its body (unspent_health()).
	. = ..()
	if(!.)
		return
	regenerating = FALSE
	end_regeneration_look()
	move_resist = MOVE_RESIST_DEFAULT
	if(!gibbed)
		addtimer(CALLBACK(src, PROC_REF(collect_remains)), OUTPOST_CHANGELING_REMAINS_TIME, TIMER_DELETE_ME)

/// Kessler takes the body
/mob/living/basic/outpost_experiment/horror/proc/collect_remains()
	if(QDELETED(src))
		return
	var/turf/spot = get_turf(src)
	if(spot)
		spot.visible_message(span_notice("[src] vanishes in a column of light. Kessler has collected its remains."))
		playsound(spot, 'sound/effects/magic/teleport_diss.ogg', 40, TRUE)
		new /obj/effect/temp_visual/transporter_beam(spot, 1.5 SECONDS)
	qdel(src)

// ===== REGENERATION =====

/**
 * Goes down regenerating: on the floor and out of it, its health held at 0. It cannot act or
 * absorb, and turrets leave it be. After OUTPOST_HORROR_REGEN_TIME (regen_tick()) it gets up with
 * OUTPOST_HORROR_REGEN_HEALTH of its health, unless its body is destroyed first (damage_remains())
 * or put out into open space (die_if_spaced()). Returns TRUE if it went down.
 */
/mob/living/basic/outpost_experiment/horror/proc/start_regenerating()
	if(regenerating || stat == DEAD || QDELETED(src))
		return FALSE
	regenerating = TRUE
	regen_left = OUTPOST_HORROR_REGEN_TIME
	remains = OUTPOST_HORROR_REMAINS
	rise_warned = FALSE
	stasis_tell_left = rand(2, 4)
	end_absorb()
	mend_left = 0
	clear_busy()
	set_quarry(null)
	ai_controller?.CancelActions()
	// Unconscious: floored, incapacitated and its AI stopped until it stands up again.
	set_stat(UNCONSCIOUS)
	bruteloss = maxHealth
	updatehealth()
	// Its body can be dragged about while it is down, but off the outpost's ground only into open space (check_ground()).
	move_resist = MOVE_RESIST_DEFAULT
	visible_message(span_boldwarning("[src] collapses, but its flesh keeps moving."))
	playsound(src, 'sound/effects/magic/demon_dies.ogg', 60, TRUE, 2)
	start_regeneration_look()
	log_game("PLAYER OUTPOST PRISON: the changeling horror went down regenerating at [AREACOORD(src)]")
	event?.horror_collapsed()
	return TRUE

/**
 * `seconds` down: fire eats at its body, it twitches, and if `home` (a member of the wing is home)
 * the clock to getting up runs, with a warning OUTPOST_HORROR_RISE_WARNING before. While it burns
 * or lies in flames the clock waits (fire_holds_down()), and it warns again once the fire is out.
 * Out in open space it dies instead, if on_moved() has not seen to that already.
 */
/mob/living/basic/outpost_experiment/horror/proc/regen_tick(seconds, home = TRUE)
	if(!regenerating || stat == DEAD || QDELETED(src) || HAS_TRAIT(src, TRAIT_GODMODE))
		return
	if(die_if_spaced())
		return
	// Burning eats its body, doubled like any fire on it.
	if(on_fire)
		take_fire_damage(OUTPOST_HORROR_REMAINS_BURN * seconds)
		if(QDELETED(src) || stat == DEAD)
			return
	stasis_tells(seconds)
	if(!home)
		return
	if(fire_holds_down())
		rise_warned = FALSE
		regen_left = max(regen_left, OUTPOST_HORROR_RISE_WARNING + 1)
		return
	regen_left -= seconds
	if(!rise_warned && regen_left <= OUTPOST_HORROR_RISE_WARNING)
		rise_warned = TRUE
		visible_message(span_userdanger("[src]'s limbs wrench back into shape. It's getting up!"))
		balloon_alert_to_viewers("getting up!")
		playsound(src, 'sound/effects/magic/enter_blood.ogg', 60, TRUE, 2)
		Shake(2, 1, 1 SECONDS)
		event?.horror_rising()
	if(regen_left <= 0)
		rise_again()

/// On fire, or lying in flames: its body cannot knit back together while it burns
/mob/living/basic/outpost_experiment/horror/proc/fire_holds_down()
	return on_fire || !!(locate(/obj/effect/hotspot) in loc)

/// Down, it twitches and heaves every few seconds, with wet noises
/mob/living/basic/outpost_experiment/horror/proc/stasis_tells(seconds)
	stasis_tell_left -= seconds
	if(stasis_tell_left > 0)
		return
	stasis_tell_left = rand(3, 5)
	Shake(1, 0, 0.6 SECONDS)
	playsound(src, pick('sound/effects/meatslap.ogg', 'sound/effects/splat.ogg', 'sound/effects/blob/attackblob.ogg'), 35, TRUE, -2)
	if(prob(40))
		visible_message(span_warning(pick(
			"[src] twitches.",
			"Something shifts under [src]'s chitin.",
			"[src]'s torn flesh crawls back together.",
			"[src]'s fingers curl and flex.",
		)))

/// Back on its feet with OUTPOST_HORROR_REGEN_HEALTH of its health, roaring, and the fight goes on. Returns TRUE if it got up.
/mob/living/basic/outpost_experiment/horror/proc/rise_again()
	if(!regenerating || stat == DEAD || QDELETED(src) || HAS_TRAIT(src, TRAIT_GODMODE))
		return FALSE
	regenerating = FALSE
	regen_left = 0
	remains = 0
	end_regeneration_look()
	pulledby?.stop_pulling()
	move_resist = initial(move_resist)
	// The update stands it up (update_stat() sets it conscious), and its AI starts again with it.
	bruteloss = round(maxHealth * (1 - OUTPOST_HORROR_REGEN_HEALTH), DAMAGE_PRECISION)
	updatehealth()
	visible_message(span_userdanger("[src] heaves itself up off the floor with a roar!"))
	playsound(src, 'sound/mobs/non-humanoids/space_dragon/space_dragon_roar.ogg', 70, TRUE, 4)
	for(var/mob/living/watcher in view(5, src))
		if(watcher.client)
			shake_camera(watcher, 3, 1)
	log_game("PLAYER OUTPOST PRISON: the changeling horror got up again at [AREACOORD(src)], [health] health")
	event?.horror_rose()
	return TRUE

/**
 * Damage while it is down wears away its body; with nothing left it bursts, dead for good. Healing
 * does nothing. Returns what adjust_health() would: the change in damage, negative for damage taken,
 * so the damage ledger counts hits on its body too.
 */
/mob/living/basic/outpost_experiment/horror/proc/damage_remains(amount, forced = FALSE)
	if(amount <= 0 || remains <= 0 || (!forced && HAS_TRAIT(src, TRAIT_GODMODE)))
		return 0
	var/taken = min(amount, remains)
	remains -= taken
	if(remains <= 0)
		burst_remains()
	return -taken

/// Its body is destroyed: it bursts apart in a spray of blood and guts, dead for good
/mob/living/basic/outpost_experiment/horror/proc/burst_remains()
	if(QDELETED(src) || stat == DEAD)
		return
	final_death = TRUE
	var/turf/spot = get_turf(src)
	visible_message(span_userdanger("[src]'s body bursts apart in a spray of blood and guts!"))
	if(spot)
		playsound(spot, 'sound/effects/splat.ogg', 80, TRUE, 3)
		for(var/turf/open/near in range(1, spot))
			if(prob(60) && !near.is_blocked_turf(TRUE))
				new /obj/effect/decal/cleanable/blood/splatter(near)
		new /obj/item/organ/heart(spot)
		new /obj/item/organ/liver(spot)
	log_game("PLAYER OUTPOST PRISON: the changeling horror's body was destroyed at [AREACOORD(src)]")
	gib()

/**
 * Whether its body, down, may be spaced: regenerating, and not dead or held by Kessler's team (or
 * an admin's godmode).
 */
/mob/living/basic/outpost_experiment/horror/proc/can_be_spaced()
	return regenerating && stat != DEAD && !QDELETED(src) && !HAS_TRAIT(src, TRAIT_GODMODE)

/**
 * Whether its body lies out in open space off the outpost (/datum/outpost_changeling_event/proc/in_open_space()).
 * One with no experiment goes by the tile alone: a space tile in space's own area.
 */
/mob/living/basic/outpost_experiment/horror/proc/in_open_space()
	if(event)
		return event.in_open_space(src)
	var/turf/here = get_turf(src)
	return isspaceturf(here) && istype(here.loc, /area/space)

/**
 * Down and out in open space off the outpost: it freezes solid, dead for good. That is its final
 * death like any other, so the containment bonus and the end of the experiment come with it.
 * Returns TRUE if it died.
 */
/mob/living/basic/outpost_experiment/horror/proc/die_if_spaced()
	if(!can_be_spaced() || !in_open_space())
		return FALSE
	add_atom_colour(HORROR_FROZEN_COLOUR, FIXED_COLOUR_PRIORITY)
	log_game("PLAYER OUTPOST PRISON: the changeling horror was spaced at [AREACOORD(src)]")
	return die_for_good(HORROR_SPACED_MESSAGE)

/**
 * Dies for good, down or not: an admin's kill, open space or its body destroyed. `message` replaces
 * its death message. Returns TRUE if it died.
 */
/mob/living/basic/outpost_experiment/horror/proc/die_for_good(message)
	if(QDELETED(src) || stat == DEAD)
		return FALSE
	final_death = TRUE
	if(message)
		death_message = message
	death()
	return stat == DEAD

/// A dark red outline that pulses while it lies regenerating
/mob/living/basic/outpost_experiment/horror/proc/start_regeneration_look()
	add_filter(HORROR_REGEN_FILTER, 2, list("type" = "outline", "color" = "#9c1a2cd0", "size" = 1))
	var/filter = get_filter(HORROR_REGEN_FILTER)
	if(filter)
		animate(filter, alpha = 40, time = 0.7 SECONDS, loop = -1)
		animate(alpha = 230, time = 0.7 SECONDS)

/mob/living/basic/outpost_experiment/horror/proc/end_regeneration_look()
	remove_filter(HORROR_REGEN_FILTER)

/mob/living/basic/outpost_experiment/horror/examine(mob/user)
	. = ..()
	if(stat == DEAD)
		return
	if(regenerating)
		. += span_warning("It's still moving.")
		if(fire_holds_down())
			. += span_notice("The flames keep its body from knitting back together.")
	. += span_notice("It shies away from fire.")

/// Down and regenerating, it is no target for turrets
/mob/living/basic/outpost_experiment/horror/turret_target()
	return !regenerating && ..()

/// Down, what is left of its body is what a gib takes without it counting as damage
/mob/living/basic/outpost_experiment/horror/unspent_health()
	return regenerating ? remains : ..()

/// Burst or blown apart, it leaves a person's remains
/mob/living/basic/outpost_experiment/horror/get_gibs_type(drop_bitflags = NONE)
	return /obj/effect/gibspawner/human

// ===== STANDING STILL =====

/**
 * Stands still for `state`, cancelling what its AI was doing. With a `duration` it ends on its
 * own. Returns the serial a timer checks against, so a stale one knows to do nothing.
 */
/mob/living/basic/outpost_experiment/horror/proc/set_busy(state, duration)
	busy = state
	busy_serial++
	deltimer(busy_timer)
	busy_timer = null
	ADD_TRAIT(src, TRAIT_IMMOBILIZED, HORROR_BUSY_TRAIT)
	ai_controller?.CancelActions()
	if(duration)
		busy_timer = addtimer(CALLBACK(src, PROC_REF(clear_busy), busy_serial), duration, TIMER_STOPPABLE|TIMER_DELETE_ME)
	return busy_serial

/// Free to move again, unless `serial` is stale
/mob/living/basic/outpost_experiment/horror/proc/clear_busy(serial)
	if(serial && serial != busy_serial)
		return FALSE
	busy = null
	deltimer(busy_timer)
	busy_timer = null
	REMOVE_TRAIT(src, TRAIT_IMMOBILIZED, HORROR_BUSY_TRAIT)
	return TRUE

/// Thrown off its stride: whatever it was channelling stops, and it stands reeling for `duration`
/mob/living/basic/outpost_experiment/horror/proc/stagger(duration, reason)
	if(stat == DEAD || regenerating)
		return
	end_absorb()
	mend_left = 0
	if(reason)
		visible_message(span_boldwarning("[src] reels back, [reason]!"))
	playsound(src, 'sound/effects/magic/demon_attack1.ogg', 50, TRUE)
	Shake(2, 1, duration)
	set_busy("stagger", duration)

// ===== ITS KIT =====

/mob/living/basic/outpost_experiment/horror/proc/grant_ability(key, ability_type)
	if(abilities[key])
		return abilities[key]
	var/datum/action/cooldown/mob_cooldown/outpost_horror/ability = new ability_type(src)
	ability.Grant(src)
	abilities[key] = ability
	return ability

/// Whether it may start an ability now: awake, free, not busy, and past the gap since the last
/mob/living/basic/outpost_experiment/horror/proc/can_use_ability()
	return stat == CONSCIOUS && !busy && world.time >= next_ability_at && !HAS_TRAIT(src, TRAIT_INCAPACITATED)

/// Starts an ability's windup. Returns the serial its timer checks, or 0 if it cannot start.
/mob/living/basic/outpost_experiment/horror/proc/begin_ability(windup)
	if(!can_use_ability())
		return 0
	next_ability_at = world.time + OUTPOST_HORROR_ABILITY_GAP
	return set_busy("windup", windup + 1 SECONDS)

/// The next ability an absorb teaches: dissonant shriek, then fleshmend, then tentacle grip
/mob/living/basic/outpost_experiment/horror/proc/learn_next_ability()
	switch(absorbs)
		if(1)
			grant_ability("dissonant", /datum/action/cooldown/mob_cooldown/outpost_horror/dissonant_shriek)
			return "dissonant"
		if(2)
			grant_ability("fleshmend", /datum/action/cooldown/mob_cooldown/outpost_horror/fleshmend)
			return "fleshmend"
		if(3)
			grant_ability("tentacle", /datum/action/cooldown/mob_cooldown/outpost_horror/tentacle)
			return "tentacle"
	return null

// ===== DAMAGE, THE SHIELD AND FIRE =====

/mob/living/basic/outpost_experiment/horror/adjust_health(amount, updating_health = TRUE, forced = FALSE)
	// Down and regenerating, its health stays at 0 and damage wears away its body instead.
	if(regenerating && stat != DEAD)
		return damage_remains(amount, forced)
	if(amount > 0 && !forced && busy == "fleshmend")
		amount *= OUTPOST_HORROR_FLESHMEND_VULNERABILITY
	. = ..()
	if(amount <= 0 || stat == DEAD)
		return
	switch(busy)
		if("absorb")
			channel_damage += amount
			if(channel_damage >= OUTPOST_HORROR_ABSORB_BREAK)
				INVOKE_ASYNC(src, PROC_REF(interrupt_absorb), "torn away from its meal")
		if("fleshmend")
			channel_damage += amount
			if(channel_damage >= OUTPOST_HORROR_FLESHMEND_BREAK)
				INVOKE_ASYNC(src, PROC_REF(stagger), OUTPOST_HORROR_FLESHMEND_STAGGER, "its wounds tearing open again")

/mob/living/basic/outpost_experiment/horror/proc/on_attacked(datum/source, atom/attacker, attack_flags)
	SIGNAL_HANDLER
	if(!isliving(attacker) || attacker == src || !(attack_flags & (ATTACKER_DAMAGING_ATTACK | ATTACKER_STAMINA_ATTACK)))
		return
	last_attacker_ref = WEAKREF(attacker)
	last_attacked_at = world.time

/// Whether its shield turns aside something coming from `from`: only from in front, and only sometimes
/mob/living/basic/outpost_experiment/horror/proc/shield_catches(atom/from)
	if(stat != CONSCIOUS || busy == "stagger" || busy == "fleshmend")
		return FALSE
	var/turf/source_turf = get_turf(from)
	var/turf/our_turf = get_turf(src)
	if(!source_turf || !our_turf || source_turf == our_turf)
		return FALSE
	var/difference = abs(get_angle(our_turf, source_turf) - dir2angle(dir))
	if(difference > 180)
		difference = 360 - difference
	if(difference > OUTPOST_HORROR_SHIELD_ARC)
		return FALSE
	return prob(OUTPOST_HORROR_SHIELD_CHANCE)

/mob/living/basic/outpost_experiment/horror/proc/show_deflect(attack_text)
	visible_message(span_warning("[src] turns [attack_text] aside with its shield!"))
	playsound(src, 'sound/items/weapons/parry.ogg', 60, TRUE)
	new /obj/effect/temp_visual/block(get_turf(src), COLOR_GRAY)

/mob/living/basic/outpost_experiment/horror/proc/on_check_block(datum/source, atom/hit_by, damage, attack_text, attack_type, armour_penetration, damage_type)
	SIGNAL_HANDLER
	if(!shield_catches(hit_by))
		return NONE
	show_deflect(attack_text)
	return SUCCESSFUL_BLOCK

/mob/living/basic/outpost_experiment/horror/proc/on_pre_bullet_act(datum/source, obj/projectile/shot, def_zone, piercing_hit, blocked)
	SIGNAL_HANDLER
	if(shot.firer == src || !shield_catches(shot.starting || shot.firer))
		return NONE
	show_deflect("\the [shot]")
	return COMPONENT_BULLET_BLOCKED

/**
 * Each tick of burning while it stands: OUTPOST_HORROR_FIRE_DAMAGE a second, doubled. tg's fire
 * only warms a basic mob (fire_act() and hotspots just light it), and it has no heat damage, so
 * this is all the harm fire does it. Down, regen_tick() burns its body instead.
 */
/mob/living/basic/outpost_experiment/horror/on_fire_stack(seconds_per_tick, datum/status_effect/fire_handler/fire_stacks/fire_handler)
	. = ..()
	if(stat != CONSCIOUS || regenerating)
		return
	take_fire_damage(OUTPOST_HORROR_FIRE_DAMAGE * seconds_per_tick)

/**
 * Burn damage from fire: `amount` times OUTPOST_HORROR_FIRE_MULT, past the chitin's
 * OUTPOST_HORROR_DAMAGE_COEFF, which only lasers and other burns get. Booked on its damage ledger
 * as the crew's when fire_credit() names a player, else as nobody's. Returns the damage done.
 */
/mob/living/basic/outpost_experiment/horror/proc/take_fire_damage(amount)
	if(amount <= 0 || stat == DEAD || HAS_TRAIT(src, TRAIT_GODMODE))
		return 0
	var/datum/component/experiment_damage_ledger/ledger = GetComponent(/datum/component/experiment_damage_ledger)
	if(ledger && fire_credit(ledger))
		ledger.crediting_players = TRUE
	. = apply_damage(amount * OUTPOST_HORROR_FIRE_MULT, BURN, forced = TRUE)
	if(ledger)
		ledger.crediting_players = FALSE

/**
 * The player its burning is credited to: whoever set it alight, if it could tell; else whoever
 * aimed a flamethrower at it or hurt it within OUTPOST_HORROR_FIRE_CREDIT_WINDOW. Null for nobody.
 */
/mob/living/basic/outpost_experiment/horror/proc/fire_credit(datum/component/experiment_damage_ledger/ledger)
	var/mob/living/igniter = igniter_ref?.resolve()
	if(igniter)
		return igniter
	var/mob/living/aimer = fire_aimer_ref?.resolve()
	if(aimer && world.time - fire_aimed_at <= OUTPOST_HORROR_FIRE_CREDIT_WINDOW)
		return aimer
	return ledger?.recent_player(OUTPOST_HORROR_FIRE_CREDIT_WINDOW)

/// A player aiming a lit flamethrower at it: if it catches fire in the next moment, they lit it
/mob/living/basic/outpost_experiment/horror/proc/on_ranged_item_used(datum/source, mob/living/user, obj/item/tool, list/modifiers)
	SIGNAL_HANDLER
	var/obj/item/flamethrower/flamer = tool
	if(!istype(flamer) || !flamer.lit || !outpost_experiment_is_player(user))
		return NONE
	fire_aimer_ref = WEAKREF(user)
	fire_aimed_at = world.time
	return NONE

/// Fire breaks an absorb or a mend. Set alight by a flamethrower just aimed at it, it knows who did it.
/mob/living/basic/outpost_experiment/horror/proc/on_ignited(datum/source)
	SIGNAL_HANDLER
	var/mob/living/aimer = fire_aimer_ref?.resolve()
	igniter_ref = (aimer && world.time - fire_aimed_at <= OUTPOST_HORROR_FIRE_AIM_WINDOW) ? WEAKREF(aimer) : null
	if(busy == "absorb")
		INVOKE_ASYNC(src, PROC_REF(interrupt_absorb), "shrieking as it burns")
	else if(busy == "fleshmend")
		INVOKE_ASYNC(src, PROC_REF(stagger), OUTPOST_HORROR_FLESHMEND_STAGGER, "shrieking as it burns")

// ===== ABSORB =====

/// Whether `victim` is dead or down: out of it, in crit, spent, or beaten flat
/proc/outpost_horror_victim_down(mob/living/victim)
	if(victim.stat != CONSCIOUS)
		return TRUE
	if(is_outpost_prisoner(victim))
		var/mob/living/basic/outpost_prisoner/prisoner = victim
		return prisoner.can_be_dragged()
	return HAS_TRAIT_FROM(victim, TRAIT_INCAPACITATED, STAMINA)

/**
 * Whether the horror could absorb `victim` at all: a prisoner or a person with a mind (crew and
 * visitors, players alive or dead), dead or down, not a husk already, lying on the outpost's
 * ground. Cyborgs, animals, creatures, the wing's guards and ambient NPCs never are.
 */
/mob/living/basic/outpost_experiment/horror/proc/absorbable(mob/living/victim)
	if(QDELETED(victim) || victim == src || !isturf(victim.loc) || HAS_TRAIT(victim, TRAIT_HUSK))
		return FALSE
	// The wing's guards (outpost_prison_guards.dm) are never absorbed, even with a mind put in them.
	if(is_outpost_prison_guard(victim))
		return FALSE
	if(!is_outpost_prisoner(victim) && !(ishuman(victim) && victim.mind))
		return FALSE
	if(!outpost_horror_victim_down(victim))
		return FALSE
	if(event && !event.on_outpost_ground(victim))
		return FALSE
	return TRUE

/**
 * Seizes `victim`, beside it, to absorb them: the grab now, the proboscis at
 * OUTPOST_HORROR_ABSORB_PROBOSCIS, the husk at OUTPOST_HORROR_ABSORB_TIME. Returns TRUE if it began.
 */
/mob/living/basic/outpost_experiment/horror/proc/start_absorb(mob/living/victim)
	if(stat != CONSCIOUS || busy || world.time < next_absorb_at || HAS_TRAIT(src, TRAIT_INCAPACITATED) || !absorbable(victim) || !Adjacent(victim))
		return FALSE
	var/serial = set_busy("absorb")
	absorbing = victim
	absorb_turf = victim.loc
	channel_damage = 0
	face_atom(victim)
	ADD_TRAIT(victim, TRAIT_IMMOBILIZED, HORROR_GRIP_TRAIT)
	RegisterSignal(victim, COMSIG_MOVABLE_MOVED, PROC_REF(on_victim_moved))
	RegisterSignal(victim, COMSIG_QDELETING, PROC_REF(on_victim_deleted))
	visible_message(
		span_userdanger("[src] seizes [victim] and pins [victim.p_them()] down!"),
		ignored_mobs = victim,
	)
	to_chat(victim, span_userdanger("[src] seizes you and pins you down!"))
	balloon_alert_to_viewers("absorbing!")
	playsound(src, 'sound/effects/magic/demon_attack1.ogg', 70, TRUE, 3)
	for(var/mob/living/watcher in view(5, src))
		if(watcher.client)
			shake_camera(watcher, 3, 1)
	if(is_outpost_prisoner(victim))
		var/mob/living/basic/outpost_prisoner/prisoner = victim
		INVOKE_ASYNC(prisoner, TYPE_PROC_REF(/mob/living/basic/outpost_prisoner, say_context), "absorbed")
	addtimer(CALLBACK(src, PROC_REF(absorb_proboscis), serial), OUTPOST_HORROR_ABSORB_PROBOSCIS, TIMER_DELETE_ME)
	addtimer(CALLBACK(src, PROC_REF(absorb_drained), serial), OUTPOST_HORROR_ABSORB_TIME, TIMER_DELETE_ME)
	return TRUE

/// Second beat: the proboscis goes in, and the victim starts to grey
/mob/living/basic/outpost_experiment/horror/proc/absorb_proboscis(serial)
	if(busy != "absorb" || serial != busy_serial || QDELETED(absorbing))
		return
	visible_message(span_userdanger("A proboscis slides out of [src]'s mouth and sinks into [absorbing]!"))
	playsound(src, 'sound/effects/magic/demon_consume.ogg', 80, TRUE, 4)
	QDEL_NULL(absorb_loop)
	absorb_loop = new(src, TRUE)
	absorbing.add_atom_colour(list(0.6,0.3,0.3,0, 0.3,0.6,0.3,0, 0.3,0.3,0.6,0, 0,0,0,1, 0,0,0,0), TEMPORARY_COLOUR_PRIORITY)

/// Third beat: the absorb completes
/mob/living/basic/outpost_experiment/horror/proc/absorb_drained(serial)
	if(busy != "absorb" || serial != busy_serial)
		return
	if(HAS_TRAIT(src, TRAIT_INCAPACITATED))
		// Held by Kessler's team, or otherwise out of it: the meal goes free.
		interrupt_absorb(null)
		return
	finish_absorb()

/**
 * Completes the absorb under way: the victim is husked and dead, and the horror heals to full,
 * grows and learns its next ability, then stands digesting a moment. Returns the victim.
 */
/mob/living/basic/outpost_experiment/horror/proc/finish_absorb()
	var/mob/living/victim = absorbing
	if(QDELETED(victim) || busy != "absorb")
		return null
	end_absorb()
	victim.visible_message(span_userdanger("[victim] shrivels into a dry, grey husk!"))
	playsound(victim, 'sound/effects/magic/demon_consume.ogg', 60, TRUE)
	husk(victim)
	absorbs++
	next_absorb_at = world.time + OUTPOST_HORROR_ABSORB_COOLDOWN
	adjust_health(-bruteloss)
	var/new_size = 1 + OUTPOST_HORROR_SIZE_PER_ABSORB * absorbs
	update_transform(new_size / current_size)
	var/learned = learn_next_ability()
	if(learned)
		visible_message(span_boldwarning("[src] swells, and its chitin shifts into a new shape."))
	log_absorb(victim)
	event?.note_absorb(victim)
	set_busy("digest", OUTPOST_HORROR_DIGEST_TIME)
	return victim

/// Husked and dead
/mob/living/basic/outpost_experiment/horror/proc/husk(mob/living/victim)
	victim.remove_atom_colour(TEMPORARY_COLOUR_PRIORITY)
	victim.become_husk(CHANGELING_DRAIN)
	if(!ishuman(victim))
		// A basic mob has no husk sprite: grey and dried out
		victim.add_atom_colour(list(0.35,0.35,0.35,0, 0.35,0.35,0.35,0, 0.35,0.35,0.35,0, 0,0,0,1, -0.05,-0.05,-0.05,0), FIXED_COLOUR_PRIORITY)
	victim.blood_volume = 0
	if(victim.stat != DEAD)
		victim.death()

/// Admins hear about every non-member it absorbs; the game log gets every absorb
/mob/living/basic/outpost_experiment/horror/proc/log_absorb(mob/living/victim)
	var/datum/outpost_prison/prison = event?.prison
	var/where = AREACOORD(victim)
	log_game("PLAYER OUTPOST PRISON: the changeling horror absorbed [key_name(victim)] at [where] ('[prison?.outpost?.name]')")
	if(is_outpost_prisoner(victim) || !victim.mind)
		return
	if(prison?.is_member(victim))
		return
	message_admins("Outpost prison horror absorbed non-member [ADMIN_LOOKUPFLW(victim)] at [ADMIN_VERBOSEJMP(victim)] (outpost '[prison?.outpost?.name]', owner [prison?.outpost?.founder_ckey || "none"]).")

/// Something broke the absorb: the victim goes free, and it staggers and waits before it tries again
/mob/living/basic/outpost_experiment/horror/proc/interrupt_absorb(reason)
	if(busy != "absorb")
		return FALSE
	var/mob/living/victim = absorbing
	next_absorb_at = world.time + OUTPOST_HORROR_ABSORB_COOLDOWN
	if(!QDELETED(victim))
		victim.visible_message(span_boldnotice("[victim] is torn free of [src]'s grip!"))
	stagger(OUTPOST_HORROR_ABSORB_STAGGER, reason)
	return TRUE

/// Lets go of the victim, if any
/mob/living/basic/outpost_experiment/horror/proc/end_absorb()
	QDEL_NULL(absorb_loop)
	var/mob/living/victim = absorbing
	absorbing = null
	absorb_turf = null
	channel_damage = 0
	if(QDELETED(victim))
		return
	UnregisterSignal(victim, list(COMSIG_MOVABLE_MOVED, COMSIG_QDELETING))
	REMOVE_TRAIT(victim, TRAIT_IMMOBILIZED, HORROR_GRIP_TRAIT)
	victim.remove_atom_colour(TEMPORARY_COLOUR_PRIORITY)

/mob/living/basic/outpost_experiment/horror/proc/on_victim_moved(atom/movable/source, atom/old_loc, dir, forced)
	SIGNAL_HANDLER
	if(source.loc == absorb_turf)
		return
	INVOKE_ASYNC(src, PROC_REF(interrupt_absorb), "its meal dragged out of its grip")

/mob/living/basic/outpost_experiment/horror/proc/on_victim_deleted(datum/source)
	SIGNAL_HANDLER
	INVOKE_ASYNC(src, PROC_REF(interrupt_absorb), null)

/// Moved off its spot mid-absorb: the grip breaks. Its body, down, moved out into open space: it dies on arrival.
/mob/living/basic/outpost_experiment/horror/proc/on_moved(datum/source, atom/old_loc, dir, forced)
	SIGNAL_HANDLER
	if(busy == "absorb")
		INVOKE_ASYNC(src, PROC_REF(interrupt_absorb), "knocked off its meal")
	if(can_be_spaced() && in_open_space())
		INVOKE_ASYNC(src, PROC_REF(die_if_spaced))

// ===== DOORS AND WINDOWS =====

/**
 * Whether it may break through `barrier_turf` coming from `from_turf`: the floor beyond has to be
 * the outpost's own open floor. Windows and grilles on the prison wing's outer ring never go, and
 * nor do walls anywhere. Doors on the ring may, if the outpost is on the other side.
 */
/mob/living/basic/outpost_experiment/horror/proc/may_breach(turf/barrier_turf, turf/from_turf, door = FALSE)
	if(!barrier_turf || !from_turf || isclosedturf(barrier_turf) || !event)
		return FALSE
	var/direction = get_dir(from_turf, barrier_turf)
	if(!direction)
		return FALSE
	var/turf/beyond = get_step(barrier_turf, direction)
	if(!isopenturf(beyond) || isspaceturf(beyond) || !event.on_outpost_ground(beyond) || !event.on_outpost_ground(from_turf))
		return FALSE
	if(!door && on_wing_ring(barrier_turf))
		return FALSE
	return TRUE

/// Whether a tile is on the prison wing's outer ring, its extensions' included (/datum/outpost_prison/proc/on_outer_ring())
/mob/living/basic/outpost_experiment/horror/proc/on_wing_ring(turf/tile)
	return !!event?.prison?.on_outer_ring(tile)

/// Walked into a door that did not open: once it has had a moment to open, it pries it
/mob/living/basic/outpost_experiment/horror/proc/on_bump(datum/source, atom/bumped)
	SIGNAL_HANDLER
	if(!istype(bumped, /obj/machinery/door/airlock) || busy || stat != CONSCIOUS)
		return
	addtimer(CALLBACK(src, PROC_REF(consider_pry), bumped), 0.5 SECONDS, TIMER_UNIQUE|TIMER_OVERRIDE|TIMER_DELETE_ME)

/mob/living/basic/outpost_experiment/horror/proc/consider_pry(obj/machinery/door/airlock/door)
	if(QDELETED(door) || !door.density || door.operating || busy || stat != CONSCIOUS || !Adjacent(door))
		return FALSE
	return start_pry(door)

/// A barrier in its way: doors are pried, windows and grilles are hacked at
/mob/living/basic/outpost_experiment/horror/proc/work_barrier(atom/barrier)
	if(istype(barrier, /obj/machinery/door/airlock))
		return start_pry(barrier)
	if(istype(barrier, /obj/structure/window) || istype(barrier, /obj/structure/grille))
		return hack_at(barrier)
	return FALSE

/**
 * Jams its blade into a door that will not open for it, and forces it: OUTPOST_HORROR_PRY_TIME, or
 * OUTPOST_HORROR_PRY_BOLTED_TIME if it is bolted, welded or dead. Returns TRUE if it started.
 */
/mob/living/basic/outpost_experiment/horror/proc/start_pry(obj/machinery/door/airlock/door)
	if(busy || stat != CONSCIOUS || QDELETED(door) || !door.density || !Adjacent(door))
		return FALSE
	if(!may_breach(get_turf(door), get_turf(src), door = TRUE))
		return FALSE
	var/stuck = door.locked || door.welded || !door.hasPower()
	var/pry_time = stuck ? OUTPOST_HORROR_PRY_BOLTED_TIME : OUTPOST_HORROR_PRY_TIME
	var/serial = set_busy("pry", pry_time + 1 SECONDS)
	face_atom(door)
	visible_message(span_boldwarning("[src] jams its blade into [door] and starts forcing it open!"))
	door.balloon_alert_to_viewers("being forced!")
	playsound(door, 'sound/machines/airlock/airlock_alien_prying.ogg', 100, TRUE, 4)
	door.Shake(1, 1, pry_time)
	addtimer(CALLBACK(src, PROC_REF(finish_pry), door, serial), pry_time, TIMER_DELETE_ME)
	return TRUE

/mob/living/basic/outpost_experiment/horror/proc/finish_pry(obj/machinery/door/airlock/door, serial)
	if(busy != "pry" || serial != busy_serial)
		return
	clear_busy()
	if(QDELETED(door) || !door.density || !Adjacent(door))
		return
	if(door.locked)
		door.unbolt()
	if(door.welded)
		door.welded = FALSE
		door.update_appearance()
	visible_message(span_boldwarning("[src] wrenches [door] open!"))
	playsound(door, 'sound/machines/airlock/airlockforced.ogg', 80, TRUE, 3)
	INVOKE_ASYNC(door, TYPE_PROC_REF(/obj/machinery/door/airlock, open), BYPASS_DOOR_CHECKS)

/// One blow at an interior window or grille: OUTPOST_HORROR_WINDOW_HITS of them bring a window down
/mob/living/basic/outpost_experiment/horror/proc/hack_at(obj/structure/barrier)
	if(busy || stat != CONSCIOUS || QDELETED(barrier) || !Adjacent(barrier) || world.time < next_move)
		return FALSE
	if(!may_breach(get_turf(barrier), get_turf(src)))
		return FALSE
	face_atom(barrier)
	do_attack_animation(barrier, ATTACK_EFFECT_SLASH)
	changeNext_move(melee_attack_cooldown)
	var/damage = istype(barrier, /obj/structure/grille) ? barrier.max_integrity : CEILING(barrier.max_integrity / OUTPOST_HORROR_WINDOW_HITS, 1) + 1
	// No armour roll: its blade takes a window down in OUTPOST_HORROR_WINDOW_HITS whatever it is made of.
	barrier.take_damage(damage, BRUTE, "", TRUE, get_dir(barrier, src))
	return TRUE

/**
 * The first thing between it and `quarry` it may break through: the door of the bolted cell they
 * hide in, else the first door, window or grille on the straight line toward them.
 */
/mob/living/basic/outpost_experiment/horror/proc/barrier_toward(atom/quarry)
	var/turf/our_turf = get_turf(src)
	var/turf/their_turf = get_turf(quarry)
	if(!our_turf || !their_turf || our_turf.z != their_turf.z)
		return null
	var/datum/outpost_prison/prison = event?.prison
	var/datum/outpost_prison_cell/holding = prison?.cell_at(their_turf)
	if(holding && !holding.contains(src))
		var/obj/machinery/door/airlock/cell_door = holding.door()
		if(cell_door?.density)
			return cell_door
	var/turf/previous = our_turf
	for(var/turf/step as anything in get_line(our_turf, their_turf))
		if(step == our_turf)
			continue
		if(step == their_turf || get_dist(our_turf, step) > 6)
			return null
		if(isclosedturf(step))
			return null
		var/obj/machinery/door/airlock/door = locate() in step
		if(door?.density)
			return may_breach(step, previous, door = TRUE) ? door : null
		for(var/obj/structure/barrier in step)
			if(!barrier.density || !(istype(barrier, /obj/structure/window) || istype(barrier, /obj/structure/grille)))
				continue
			return may_breach(step, previous) ? barrier : null
		previous = step
	return null

// ===== TARGETS =====

/// Whether a living thing is one of its own kind: the experiment's creatures leave each other alone
/proc/is_outpost_changeling_creature(mob/living/thing)
	return istype(thing, /mob/living/basic/outpost_experiment/horror) || istype(thing, /mob/living/basic/headslug/beakless/outpost)

/**
 * Whether it would swing at `target`: anything alive on the outpost's ground but its own kind,
 * and not someone down it could absorb instead. Ambient NPCs and animals it kills outright.
 */
/mob/living/basic/outpost_experiment/horror/proc/valid_quarry(mob/living/target)
	if(!isliving(target) || QDELETED(target) || target == src || target.stat == DEAD || !isturf(target.loc))
		return FALSE
	if(is_outpost_changeling_creature(target) || HAS_TRAIT(target, TRAIT_GODMODE))
		return FALSE
	if(target.z != z || (event && !event.on_outpost_ground(target)))
		return FALSE
	if(absorbable(target))
		return FALSE
	return TRUE

/// Whether a prisoner is shut in a bolted cell, which it leaves for last
/mob/living/basic/outpost_experiment/horror/proc/bolted_away(mob/living/target)
	var/mob/living/basic/outpost_prisoner/prisoner = target
	return istype(prisoner) && prisoner.in_bolted_cell()

/**
 * Whether anyone from the wing is home. While nobody is, it lies low: it fights back but hunts
 * nobody, so a loose horror is never a trap left for visitors to an empty outpost.
 */
/mob/living/basic/outpost_experiment/horror/proc/crew_about()
	var/datum/outpost_prison/prison = event?.prison
	return !prison || prison.crew_home()

/**
 * Who it goes after: whoever hurt it last, if they are still about; else the nearest prisoner in
 * sight; else anyone else in sight; else a prisoner in a bolted cell. Null if nobody, and nobody
 * but its attacker while the wing's crew is away.
 */
/mob/living/basic/outpost_experiment/horror/proc/pick_quarry()
	var/mob/living/attacker = last_attacker_ref?.resolve()
	if(attacker && world.time - last_attacked_at <= 15 SECONDS && get_dist(src, attacker) <= 12 && valid_quarry(attacker))
		return attacker
	if(!crew_about())
		return null
	var/mob/living/nearest_prisoner
	var/mob/living/nearest_other
	var/mob/living/nearest_bolted
	var/prisoner_distance = INFINITY
	var/other_distance = INFINITY
	var/bolted_distance = INFINITY
	for(var/mob/living/candidate in oview(9, src))
		if(!valid_quarry(candidate))
			continue
		var/distance = get_dist(src, candidate)
		if(bolted_away(candidate))
			if(distance < bolted_distance)
				nearest_bolted = candidate
				bolted_distance = distance
		else if(is_outpost_prisoner(candidate))
			if(distance < prisoner_distance)
				nearest_prisoner = candidate
				prisoner_distance = distance
		else if(distance < other_distance)
			nearest_other = candidate
			other_distance = distance
	return nearest_prisoner || nearest_other || nearest_bolted

/// The nearest dead or downed body it could absorb within `range`, or null
/mob/living/basic/outpost_experiment/horror/proc/nearest_body(range = OUTPOST_HORROR_ABSORB_RANGE)
	var/mob/living/best
	var/best_distance = INFINITY
	for(var/mob/living/candidate in view(range, src))
		if(!absorbable(candidate))
			continue
		var/distance = get_dist(src, candidate)
		if(distance < best_distance)
			best = candidate
			best_distance = distance
	return best

/// Whether it would stop fighting to feed: hurt, or with nobody on their feet close by
/mob/living/basic/outpost_experiment/horror/proc/wants_to_feed()
	if(health < maxHealth * OUTPOST_HORROR_ABSORB_HURT_BELOW)
		return TRUE
	for(var/mob/living/carbon/human/person in view(OUTPOST_HORROR_ABSORB_CLEAR_RANGE, src))
		if(person.stat == CONSCIOUS && !outpost_horror_victim_down(person))
			return FALSE
	return TRUE

/**
 * Something to hunt when nobody is in sight: the nearest player on the outpost's ground, or failing
 * that the nearest prisoner outside a bolted cell.
 */
/mob/living/basic/outpost_experiment/horror/proc/find_prey()
	var/mob/living/best
	var/best_distance = INFINITY
	if(z <= length(SSmobs.clients_by_zlevel))
		for(var/mob/living/player as anything in SSmobs.clients_by_zlevel[z])
			if(!isliving(player) || !valid_quarry(player))
				continue
			var/distance = get_dist(src, player)
			if(distance < best_distance)
				best = player
				best_distance = distance
	if(best)
		return best
	for(var/mob/living/basic/outpost_prisoner/prisoner as anything in event?.prison?.prisoners)
		if(!valid_quarry(prisoner) || bolted_away(prisoner))
			continue
		var/distance = get_dist(src, prisoner)
		if(distance < best_distance)
			best = prisoner
			best_distance = distance
	return best

/mob/living/basic/outpost_experiment/horror/Life(seconds_per_tick = SSMOBS_DT, times_fired)
	. = ..()
	if(stat == DEAD || QDELETED(src))
		return
	if(regenerating)
		// An experiment's horror is driven by its event each second (horror_tick()); one without an experiment drives itself.
		if(!event)
			regen_tick(seconds_per_tick, crew_about())
		return
	check_progress()

/**
 * Kept from its quarry: if it has got no closer for OUTPOST_HORROR_BREACH_AFTER, it picks the
 * nearest door or window toward them to break through.
 */
/mob/living/basic/outpost_experiment/horror/proc/check_progress()
	var/mob/living/quarry = quarry_ref?.resolve()
	if(!quarry || busy || Adjacent(quarry))
		closest_to_quarry = INFINITY
		closing_since = world.time
		return
	var/distance = get_dist(src, quarry)
	if(distance < closest_to_quarry)
		closest_to_quarry = distance
		closing_since = world.time
		return
	if(world.time - closing_since < OUTPOST_HORROR_BREACH_AFTER)
		return
	closing_since = world.time
	var/atom/barrier = barrier_toward(quarry)
	if(barrier)
		ai_controller?.set_blackboard_key(BB_OUTPOST_HORROR_BARRIER, barrier)

/// Sets who it is after, resetting its progress when that changes
/mob/living/basic/outpost_experiment/horror/proc/set_quarry(mob/living/quarry)
	var/mob/living/old = quarry_ref?.resolve()
	if(old == quarry)
		return
	quarry_ref = quarry ? WEAKREF(quarry) : null
	closest_to_quarry = INFINITY
	closing_since = world.time

// ===== THE ABILITIES =====

/**
 * The horror's abilities. Each has a windup (telegraph() shows where it lands) and an effect(),
 * which runs when the windup is up unless the horror was staggered or killed meanwhile. Tests call
 * effect() directly.
 */
/datum/action/cooldown/mob_cooldown/outpost_horror
	name = "Horror ability"
	button_icon = 'icons/mob/actions/actions_changeling.dmi'
	background_icon_state = "bg_changeling"
	overlay_icon_state = "bg_changeling_border"
	cooldown_time = 20 SECONDS
	shared_cooldown = NONE
	melee_cooldown_time = 0
	click_to_activate = TRUE
	/// How long it stands winding up before the effect
	var/windup = 1 SECONDS

/datum/action/cooldown/mob_cooldown/outpost_horror/IsAvailable(feedback = FALSE)
	. = ..()
	if(!.)
		return FALSE
	var/mob/living/basic/outpost_experiment/horror/horror = owner
	return istype(horror) && horror.can_use_ability()

/// Whether it is worth using on `target` now
/datum/action/cooldown/mob_cooldown/outpost_horror/proc/worth_using(atom/target)
	return TRUE

/datum/action/cooldown/mob_cooldown/outpost_horror/Activate(atom/target)
	var/mob/living/basic/outpost_experiment/horror/horror = owner
	var/serial = horror.begin_ability(windup)
	if(!serial)
		return FALSE
	StartCooldown()
	telegraph(target)
	addtimer(CALLBACK(src, PROC_REF(resolve), target, serial), windup, TIMER_DELETE_ME)
	return TRUE

/datum/action/cooldown/mob_cooldown/outpost_horror/proc/resolve(atom/target, serial)
	var/mob/living/basic/outpost_experiment/horror/horror = owner
	if(QDELETED(horror) || horror.stat == DEAD || horror.busy != "windup" || horror.busy_serial != serial)
		return
	horror.clear_busy()
	effect(target)

/datum/action/cooldown/mob_cooldown/outpost_horror/proc/telegraph(atom/target)
	return

/datum/action/cooldown/mob_cooldown/outpost_horror/proc/effect(atom/target)
	return

/// Marks the floor the effect will cover, for as long as the windup lasts
/datum/action/cooldown/mob_cooldown/outpost_horror/proc/mark_area(radius, mark_color)
	for(var/turf/open/tile in view(radius, owner))
		new /obj/effect/temp_visual/outpost_horror_mark(tile, windup, mark_color)

/datum/action/cooldown/mob_cooldown/outpost_horror/proc/break_lights(radius)
	for(var/obj/machinery/light/fixture in range(radius, owner))
		if(fixture.status == LIGHT_OK)
			fixture.break_light_tube()

// ----- resonant shriek -----

/datum/action/cooldown/mob_cooldown/outpost_horror/resonant_shriek
	name = "Resonant Shriek"
	desc = "Shriek after a short windup. Everyone within 4 tiles who hears it is confused for 5 seconds and shaking, and lights within 4 tiles break."
	button_icon_state = "resonant_shriek"
	cooldown_time = OUTPOST_HORROR_RESONANT_COOLDOWN
	windup = OUTPOST_HORROR_RESONANT_WINDUP

/datum/action/cooldown/mob_cooldown/outpost_horror/resonant_shriek/worth_using(atom/target)
	return isliving(target) && get_dist(owner, target) <= OUTPOST_HORROR_RESONANT_RADIUS

/datum/action/cooldown/mob_cooldown/outpost_horror/resonant_shriek/telegraph(atom/target)
	owner.visible_message(span_boldwarning("[owner]'s throat swells, and a pale ring spreads across the floor around it!"))
	owner.balloon_alert_to_viewers("shriek!")
	playsound(owner, 'sound/effects/magic/tail_swing.ogg', 50, TRUE)
	mark_area(OUTPOST_HORROR_RESONANT_RADIUS, "#e8e2c8")
	var/matrix/rest = matrix(owner.transform)
	var/matrix/swell = matrix(owner.transform)
	swell.Scale(1.08, 1.04)
	animate(owner, transform = swell, time = windup * 0.8, easing = SINE_EASING, flags = ANIMATION_PARALLEL)
	animate(transform = rest, time = 0.2 SECONDS)

/datum/action/cooldown/mob_cooldown/outpost_horror/resonant_shriek/effect(atom/target)
	owner.visible_message(span_userdanger("[owner] lets out a piercing shriek!"))
	playsound(owner, 'sound/effects/screech.ogg', 100, TRUE, 6)
	for(var/mob/living/victim in get_hearers_in_view(OUTPOST_HORROR_RESONANT_RADIUS, owner))
		if(victim == owner || is_outpost_changeling_creature(victim))
			continue
		if(iscarbon(victim))
			var/mob/living/carbon/person = victim
			var/confusion = OUTPOST_HORROR_RESONANT_CONFUSION
			if(person.get_ear_protection() || HAS_TRAIT(person, TRAIT_DEAF))
				confusion *= 0.5
			person.adjust_confusion_up_to(confusion, confusion)
			person.set_jitter_if_lower(OUTPOST_HORROR_RESONANT_JITTER)
			var/obj/item/organ/ears/ears = person.get_organ_slot(ORGAN_SLOT_EARS)
			ears?.adjustEarDamage(0, 5)
			to_chat(person, span_userdanger("The shriek drills into your skull!"))
		else if(is_outpost_prisoner(victim) && victim.stat == CONSCIOUS)
			INVOKE_ASYNC(victim, TYPE_PROC_REF(/atom, manual_emote), "claps [victim.p_their()] hands over [victim.p_their()] ears.")
	break_lights(OUTPOST_HORROR_RESONANT_RADIUS)

// ----- dissonant shriek -----

/datum/action/cooldown/mob_cooldown/outpost_horror/dissonant_shriek
	name = "Dissonant Shriek"
	desc = "Shriek at a pitch that wrecks electronics, after a short windup. Energy weapons within 3 tiles lose 30% of their charge, headsets go dead for 10 seconds, and lights within 5 tiles break."
	button_icon_state = "dissonant_shriek"
	cooldown_time = OUTPOST_HORROR_DISSONANT_COOLDOWN
	windup = OUTPOST_HORROR_DISSONANT_WINDUP

/datum/action/cooldown/mob_cooldown/outpost_horror/dissonant_shriek/worth_using(atom/target)
	return isliving(target) && get_dist(owner, target) <= OUTPOST_HORROR_DISSONANT_RADIUS

/datum/action/cooldown/mob_cooldown/outpost_horror/dissonant_shriek/telegraph(atom/target)
	owner.visible_message(span_boldwarning("Static crackles around [owner] and the lights begin to stutter!"))
	owner.balloon_alert_to_viewers("static!")
	playsound(owner, 'sound/effects/sparks/sparks1.ogg', 70, TRUE, 3)
	mark_area(OUTPOST_HORROR_DISSONANT_RADIUS, "#5aa0ff")
	for(var/obj/machinery/light/fixture in range(OUTPOST_HORROR_DISSONANT_LIGHT_RADIUS, owner))
		outpost_changeling_flicker(fixture, 2)

/datum/action/cooldown/mob_cooldown/outpost_horror/dissonant_shriek/effect(atom/target)
	owner.visible_message(span_userdanger("[owner] lets out a grinding, electric shriek!"))
	playsound(owner, 'sound/effects/screech.ogg', 80, TRUE, 5)
	playsound(owner, 'sound/effects/empulse.ogg', 60, TRUE, 3)
	var/list/drained = list()
	var/list/silenced = list()
	for(var/turf/tile as anything in RANGE_TURFS(OUTPOST_HORROR_DISSONANT_RADIUS, owner))
		for(var/obj/item/gun/energy/gun as anything in tile.get_all_contents_type(/obj/item/gun/energy))
			if(drained[gun] || !gun.cell)
				continue
			drained[gun] = TRUE
			gun.cell.use(gun.cell.maxcharge * OUTPOST_HORROR_DISSONANT_DRAIN, force = TRUE)
			gun.update_appearance()
		for(var/obj/item/radio/headset/headset as anything in tile.get_all_contents_type(/obj/item/radio/headset))
			if(silenced[headset] || !headset.on)
				continue
			silenced[headset] = TRUE
			fizzle_headset(headset)
	break_lights(OUTPOST_HORROR_DISSONANT_LIGHT_RADIUS)

/// Dead air for a while, as an EMP would do, without wiping its channels
/datum/action/cooldown/mob_cooldown/outpost_horror/dissonant_shriek/proc/fizzle_headset(obj/item/radio/headset/headset)
	headset.emped++
	var/this_fizzle = headset.emped
	headset.set_on(FALSE)
	if(ismob(headset.loc))
		to_chat(headset.loc, span_warning("[headset] crackles and goes dead."))
	addtimer(CALLBACK(headset, TYPE_PROC_REF(/obj/item/radio, end_emp_effect), this_fizzle), OUTPOST_HORROR_DISSONANT_HEADSET_TIME)

// ----- fleshmend -----

/datum/action/cooldown/mob_cooldown/outpost_horror/fleshmend
	name = "Fleshmend"
	desc = "Below 60% health, kneel and heal 10 health a second for 8 seconds. You take 25% more damage meanwhile, and 45 damage or fire breaks it."
	button_icon_state = "fleshmend"
	cooldown_time = OUTPOST_HORROR_FLESHMEND_COOLDOWN
	windup = 0

/datum/action/cooldown/mob_cooldown/outpost_horror/fleshmend/worth_using(atom/target)
	var/mob/living/basic/outpost_experiment/horror/horror = owner
	return horror.health < horror.maxHealth * OUTPOST_HORROR_FLESHMEND_BELOW

/datum/action/cooldown/mob_cooldown/outpost_horror/fleshmend/Activate(atom/target)
	var/mob/living/basic/outpost_experiment/horror/horror = owner
	if(!worth_using(target) || !horror.can_use_ability())
		return FALSE
	horror.next_ability_at = world.time + OUTPOST_HORROR_ABILITY_GAP
	StartCooldown()
	horror.start_fleshmend()
	return TRUE

/// Kneels and knits for OUTPOST_HORROR_FLESHMEND_TIME seconds
/mob/living/basic/outpost_experiment/horror/proc/start_fleshmend()
	var/serial = set_busy("fleshmend", (OUTPOST_HORROR_FLESHMEND_TIME + 1) SECONDS)
	mend_left = OUTPOST_HORROR_FLESHMEND_TIME
	channel_damage = 0
	visible_message(span_boldwarning("[src] drops to one knee, and its torn flesh starts crawling back together!"))
	balloon_alert_to_viewers("mending!")
	playsound(src, 'sound/effects/magic/enter_blood.ogg', 60, TRUE, 2)
	addtimer(CALLBACK(src, PROC_REF(mend_pulse), serial), 1 SECONDS, TIMER_DELETE_ME)

/mob/living/basic/outpost_experiment/horror/proc/mend_pulse(serial)
	if(busy != "fleshmend" || serial != busy_serial || stat == DEAD)
		return
	adjust_health(-OUTPOST_HORROR_FLESHMEND_HEAL)
	new /obj/effect/temp_visual/heal(get_turf(src), "#8fd18a")
	mend_left--
	if(mend_left <= 0)
		clear_busy()
		visible_message(span_warning("[src] rises, whole again."))
		return
	addtimer(CALLBACK(src, PROC_REF(mend_pulse), serial), 1 SECONDS, TIMER_DELETE_ME)

// ----- tentacle grip -----

/datum/action/cooldown/mob_cooldown/outpost_horror/tentacle
	name = "Tentacle Grip"
	desc = "Uncoil your arm along a line to someone up to 7 tiles away, then lash it out. Whoever is on the line is pulled in, knocked down and impaled for 22."
	button_icon_state = "tentacle"
	cooldown_time = OUTPOST_HORROR_TENTACLE_COOLDOWN
	windup = OUTPOST_HORROR_TENTACLE_WINDUP
	/// Where the line points, fixed when the windup starts
	var/turf/aimed_at

/datum/action/cooldown/mob_cooldown/outpost_horror/tentacle/Destroy()
	aimed_at = null
	return ..()

/datum/action/cooldown/mob_cooldown/outpost_horror/tentacle/worth_using(atom/target)
	if(!isliving(target))
		return FALSE
	var/distance = get_dist(owner, target)
	return distance >= 2 && distance <= OUTPOST_HORROR_TENTACLE_RANGE && (target in view(OUTPOST_HORROR_TENTACLE_RANGE, owner))

/datum/action/cooldown/mob_cooldown/outpost_horror/tentacle/telegraph(atom/target)
	aimed_at = get_turf(target)
	owner.face_atom(target)
	owner.visible_message(span_boldwarning("[owner]'s arm uncoils into a long, wet tentacle, pointing at [target]!"))
	owner.balloon_alert_to_viewers("tentacle!")
	playsound(owner, 'sound/effects/blob/blobattack.ogg', 60, TRUE)
	for(var/turf/tile as anything in get_line(get_turf(owner), aimed_at))
		if(tile != get_turf(owner) && isopenturf(tile))
			new /obj/effect/temp_visual/outpost_horror_mark(tile, windup, "#d0506a")

/datum/action/cooldown/mob_cooldown/outpost_horror/tentacle/effect(atom/target)
	var/turf/aim = aimed_at || get_turf(target)
	aimed_at = null
	var/turf/start = get_turf(owner)
	if(!aim || !start || aim == start)
		return
	playsound(owner, 'sound/effects/magic/tail_swing.ogg', 70, TRUE)
	var/obj/projectile/outpost_horror_tentacle/lash = new(start)
	lash.aim_projectile(aim, owner)
	lash.firer = owner
	lash.fired_from = owner
	lash.fire()

/// Pulled in, knocked down and impaled on the blade
/mob/living/basic/outpost_experiment/horror/proc/tentacle_hit(mob/living/victim)
	if(QDELETED(victim) || stat != CONSCIOUS)
		return
	victim.visible_message(
		span_userdanger("[victim] is caught by [src]'s tentacle and dragged in!"),
		span_userdanger("A tentacle wraps around you and drags you toward [src]!"),
	)
	victim.Knockdown(OUTPOST_HORROR_TENTACLE_KNOCKDOWN)
	var/blocked = victim.run_armor_check(BODY_ZONE_CHEST, MELEE, armour_penetration = OUTPOST_HORROR_BLADE_AP)
	victim.apply_damage(OUTPOST_HORROR_TENTACLE_DAMAGE, BRUTE, BODY_ZONE_CHEST, blocked, sharpness = SHARP_POINTY)
	playsound(victim, 'sound/items/weapons/bladeslice.ogg', 70, TRUE)
	if(!victim.anchored && get_dist(src, victim) > 1)
		victim.throw_at(get_step_towards(src, victim), OUTPOST_HORROR_TENTACLE_RANGE + 1, 2, src, gentle = TRUE, force = MOVE_FORCE_OVERPOWERING)

/obj/projectile/outpost_horror_tentacle
	name = "tentacle"
	icon_state = "tentacle_end"
	pass_flags = PASSTABLE
	damage = 0
	damage_type = BRUTE
	range = OUTPOST_HORROR_TENTACLE_RANGE
	hitsound = 'sound/items/weapons/shove.ogg'
	/// The fleshy rope back to the horror
	var/datum/beam/chain

/obj/projectile/outpost_horror_tentacle/fire(fire_angle, atom/direct_target)
	if(firer)
		chain = firer.Beam(src, icon_state = "tentacle", emissive = FALSE)
	return ..()

/obj/projectile/outpost_horror_tentacle/on_hit(atom/target, blocked = 0, pierce_hit)
	. = ..()
	if(. != BULLET_ACT_HIT || !isliving(target))
		return
	var/mob/living/basic/outpost_experiment/horror/horror = firer
	if(istype(horror))
		horror.tentacle_hit(target)

/obj/projectile/outpost_horror_tentacle/Destroy()
	QDEL_NULL(chain)
	return ..()

/// A tile the horror's next move will cover, marked for the length of the windup
/obj/effect/temp_visual/outpost_horror_mark
	icon = 'icons/mob/telegraphing/telegraph.dmi'
	icon_state = "blank_semi_transparent"
	layer = BELOW_MOB_LAYER
	plane = GAME_PLANE
	duration = 1.5 SECONDS

/obj/effect/temp_visual/outpost_horror_mark/Initialize(mapload, new_duration, new_color)
	if(new_duration)
		duration = new_duration
	if(new_color)
		color = new_color
	return ..()

// ===== ITS MIND =====

/**
 * Its planning: nothing at all while it stands still for something; then who to go after; then an
 * ability; then feeding on a body; then breaking toward a quarry it cannot reach; then the blade;
 * and with nobody in sight, the hunt.
 */
/datum/ai_controller/basic_controller/outpost_horror
	blackboard = list(
		BB_TARGETING_STRATEGY = /datum/targeting_strategy/basic/outpost_horror,
		BB_TARGET_MINIMUM_STAT = HARD_CRIT,
	)
	ai_movement = /datum/ai_movement/jps
	idle_behavior = null
	planning_subtrees = list(
		/datum/ai_planning_subtree/outpost_horror_busy,
		/datum/ai_planning_subtree/outpost_horror_quarry,
		/datum/ai_planning_subtree/outpost_horror_abilities,
		/datum/ai_planning_subtree/outpost_horror_absorb,
		/datum/ai_planning_subtree/outpost_horror_breach,
		/datum/ai_planning_subtree/basic_melee_attack_subtree,
		/datum/ai_planning_subtree/outpost_horror_hunt,
	)

/// For pathing only: every door is a way through, since what does not open for it, it pries
/datum/ai_controller/basic_controller/outpost_horror/get_access()
	return SSid_access.get_region_access_list(list(REGION_ALL_GLOBAL))

/datum/targeting_strategy/basic/outpost_horror
	ignore_sight = TRUE

/datum/targeting_strategy/basic/outpost_horror/can_attack(mob/living/living_mob, atom/the_target, vision_range)
	var/mob/living/basic/outpost_experiment/horror/horror = living_mob
	if(!istype(horror) || !isliving(the_target))
		return FALSE
	if(!horror.valid_quarry(the_target))
		return FALSE
	return ..()

/datum/ai_planning_subtree/outpost_horror_busy

/datum/ai_planning_subtree/outpost_horror_busy/SelectBehaviors(datum/ai_controller/controller, seconds_per_tick)
	var/mob/living/basic/outpost_experiment/horror/horror = controller.pawn
	if(!istype(horror) || horror.busy || horror.stat != CONSCIOUS)
		return SUBTREE_RETURN_FINISH_PLANNING

/datum/ai_planning_subtree/outpost_horror_quarry

/datum/ai_planning_subtree/outpost_horror_quarry/SelectBehaviors(datum/ai_controller/controller, seconds_per_tick)
	var/mob/living/basic/outpost_experiment/horror/horror = controller.pawn
	var/mob/living/quarry = horror.pick_quarry()
	horror.set_quarry(quarry)
	if(quarry)
		controller.set_blackboard_key(BB_BASIC_MOB_CURRENT_TARGET, quarry)
	else
		controller.clear_blackboard_key(BB_BASIC_MOB_CURRENT_TARGET)

/**
 * One of its abilities, if one is ready and worth it: fleshmend when hurt, the tentacle at whoever
 * is furthest off, a shriek when people are close. Never the same one twice running if another will do.
 */
/datum/ai_planning_subtree/outpost_horror_abilities

/datum/ai_planning_subtree/outpost_horror_abilities/SelectBehaviors(datum/ai_controller/controller, seconds_per_tick)
	var/mob/living/basic/outpost_experiment/horror/horror = controller.pawn
	if(!horror.can_use_ability())
		return
	var/mob/living/quarry = controller.blackboard[BB_BASIC_MOB_CURRENT_TARGET]
	var/list/options = list()
	for(var/key in horror.abilities)
		var/datum/action/cooldown/mob_cooldown/outpost_horror/ability = horror.abilities[key]
		if(QDELETED(ability) || !ability.IsAvailable())
			continue
		var/atom/aim = quarry
		if(key == "tentacle")
			aim = horror.furthest_in_reach(OUTPOST_HORROR_TENTACLE_RANGE)
		else if(key == "fleshmend")
			aim = horror
		if(!aim || !ability.worth_using(aim))
			continue
		options[key] = aim
	if(!length(options))
		return
	var/last = controller.blackboard[BB_OUTPOST_HORROR_ABILITY]
	if(last && length(options) > 1 && options[last])
		options -= last
	var/chosen = pick(options)
	controller.set_blackboard_key(BB_OUTPOST_HORROR_ABILITY, chosen)
	controller.set_blackboard_key(BB_OUTPOST_HORROR_ABILITY_TARGET, options[chosen])
	controller.queue_behavior(/datum/ai_behavior/outpost_horror_ability, chosen, BB_OUTPOST_HORROR_ABILITY_TARGET)
	return SUBTREE_RETURN_FINISH_PLANNING

/// The furthest person it could lash with the tentacle, for pulling in someone hanging back
/mob/living/basic/outpost_experiment/horror/proc/furthest_in_reach(range)
	var/mob/living/best
	var/best_distance = 1
	for(var/mob/living/candidate in oview(range, src))
		if(!valid_quarry(candidate) || bolted_away(candidate))
			continue
		var/distance = get_dist(src, candidate)
		if(distance > best_distance)
			best = candidate
			best_distance = distance
	return best

/datum/ai_behavior/outpost_horror_ability

/datum/ai_behavior/outpost_horror_ability/perform(seconds_per_tick, datum/ai_controller/controller, ability_key, target_key)
	var/mob/living/basic/outpost_experiment/horror/horror = controller.pawn
	var/datum/action/cooldown/mob_cooldown/outpost_horror/ability = horror.abilities[ability_key]
	var/atom/target = controller.blackboard[target_key]
	if(QDELETED(ability) || QDELETED(target))
		return AI_BEHAVIOR_INSTANT | AI_BEHAVIOR_FAILED
	horror.face_atom(target)
	return ability.Trigger(target = target) ? (AI_BEHAVIOR_INSTANT | AI_BEHAVIOR_SUCCEEDED) : (AI_BEHAVIOR_INSTANT | AI_BEHAVIOR_FAILED)

/datum/ai_behavior/outpost_horror_ability/finish_action(datum/ai_controller/controller, succeeded, ability_key, target_key)
	. = ..()
	controller.clear_blackboard_key(target_key)

/// Feeding: a body close by, when it is hurt or nobody is standing near
/datum/ai_planning_subtree/outpost_horror_absorb

/datum/ai_planning_subtree/outpost_horror_absorb/SelectBehaviors(datum/ai_controller/controller, seconds_per_tick)
	var/mob/living/basic/outpost_experiment/horror/horror = controller.pawn
	if(world.time < horror.next_absorb_at || !horror.wants_to_feed())
		return
	var/mob/living/body = horror.nearest_body()
	if(!body)
		return
	controller.set_blackboard_key(BB_OUTPOST_HORROR_BODY, body)
	controller.queue_behavior(/datum/ai_behavior/outpost_horror_absorb, BB_OUTPOST_HORROR_BODY)
	return SUBTREE_RETURN_FINISH_PLANNING

/datum/ai_behavior/outpost_horror_absorb
	behavior_flags = AI_BEHAVIOR_REQUIRE_MOVEMENT
	required_distance = 1
	action_cooldown = 0.5 SECONDS

/datum/ai_behavior/outpost_horror_absorb/setup(datum/ai_controller/controller, body_key)
	var/atom/body = controller.blackboard[body_key]
	if(QDELETED(body))
		return FALSE
	set_movement_target(controller, body)
	return TRUE

/datum/ai_behavior/outpost_horror_absorb/perform(seconds_per_tick, datum/ai_controller/controller, body_key)
	var/mob/living/basic/outpost_experiment/horror/horror = controller.pawn
	var/mob/living/body = controller.blackboard[body_key]
	if(!horror.start_absorb(body))
		return AI_BEHAVIOR_DELAY | AI_BEHAVIOR_FAILED
	return AI_BEHAVIOR_DELAY | AI_BEHAVIOR_SUCCEEDED

/datum/ai_behavior/outpost_horror_absorb/finish_action(datum/ai_controller/controller, succeeded, body_key)
	. = ..()
	controller.clear_blackboard_key(body_key)

/// Breaking through toward a quarry it cannot reach: pry the door or hack at the window
/datum/ai_planning_subtree/outpost_horror_breach

/datum/ai_planning_subtree/outpost_horror_breach/SelectBehaviors(datum/ai_controller/controller, seconds_per_tick)
	var/atom/barrier = controller.blackboard[BB_OUTPOST_HORROR_BARRIER]
	if(QDELETED(barrier) || !barrier.density)
		controller.clear_blackboard_key(BB_OUTPOST_HORROR_BARRIER)
		return
	controller.queue_behavior(/datum/ai_behavior/outpost_horror_breach, BB_OUTPOST_HORROR_BARRIER)
	return SUBTREE_RETURN_FINISH_PLANNING

/datum/ai_behavior/outpost_horror_breach
	behavior_flags = AI_BEHAVIOR_REQUIRE_MOVEMENT
	required_distance = 1
	action_cooldown = 0.5 SECONDS

/datum/ai_behavior/outpost_horror_breach/setup(datum/ai_controller/controller, barrier_key)
	var/atom/barrier = controller.blackboard[barrier_key]
	if(QDELETED(barrier))
		return FALSE
	set_movement_target(controller, barrier)
	return TRUE

/datum/ai_behavior/outpost_horror_breach/perform(seconds_per_tick, datum/ai_controller/controller, barrier_key)
	var/mob/living/basic/outpost_experiment/horror/horror = controller.pawn
	var/atom/barrier = controller.blackboard[barrier_key]
	if(QDELETED(barrier) || !barrier.density)
		return AI_BEHAVIOR_DELAY | AI_BEHAVIOR_SUCCEEDED
	if(!horror.Adjacent(barrier))
		return AI_BEHAVIOR_DELAY | AI_BEHAVIOR_FAILED
	if(istype(barrier, /obj/machinery/door/airlock))
		return horror.work_barrier(barrier) ? (AI_BEHAVIOR_DELAY | AI_BEHAVIOR_SUCCEEDED) : (AI_BEHAVIOR_DELAY | AI_BEHAVIOR_FAILED)
	// Windows take a few blows; keep at it until it gives.
	if(!horror.may_breach(get_turf(barrier), get_turf(horror)))
		return AI_BEHAVIOR_DELAY | AI_BEHAVIOR_FAILED
	horror.work_barrier(barrier)
	return AI_BEHAVIOR_DELAY

/datum/ai_behavior/outpost_horror_breach/finish_action(datum/ai_controller/controller, succeeded, barrier_key)
	. = ..()
	controller.clear_blackboard_key(barrier_key)

/// Nobody in sight: it goes looking, toward the nearest player on the outpost
/datum/ai_planning_subtree/outpost_horror_hunt

/datum/ai_planning_subtree/outpost_horror_hunt/SelectBehaviors(datum/ai_controller/controller, seconds_per_tick)
	var/mob/living/basic/outpost_experiment/horror/horror = controller.pawn
	if(controller.blackboard_key_exists(BB_BASIC_MOB_CURRENT_TARGET) || !horror.crew_about())
		return
	var/mob/living/prey = controller.blackboard[BB_OUTPOST_HORROR_PREY]
	if(world.time >= controller.blackboard[BB_OUTPOST_HORROR_HUNT_AT] || QDELETED(prey) || !horror.valid_quarry(prey))
		controller.set_blackboard_key(BB_OUTPOST_HORROR_HUNT_AT, world.time + 5 SECONDS)
		prey = horror.find_prey()
		if(prey)
			controller.set_blackboard_key(BB_OUTPOST_HORROR_PREY, prey)
		else
			controller.clear_blackboard_key(BB_OUTPOST_HORROR_PREY)
	if(QDELETED(prey))
		return
	horror.set_quarry(prey)
	controller.queue_behavior(/datum/ai_behavior/travel_towards/adjacent, BB_OUTPOST_HORROR_PREY)
	return SUBTREE_RETURN_FINISH_PLANNING

#undef HORROR_BUSY_TRAIT
#undef HORROR_GRIP_TRAIT
#undef HORROR_REGEN_FILTER
#undef HORROR_FROZEN_COLOUR
#undef HORROR_SPACED_MESSAGE
#undef FACTION_OUTPOST_HORROR
#undef BB_OUTPOST_HORROR_ABILITY
#undef BB_OUTPOST_HORROR_ABILITY_TARGET
#undef BB_OUTPOST_HORROR_BODY
#undef BB_OUTPOST_HORROR_BARRIER
#undef BB_OUTPOST_HORROR_PREY
#undef BB_OUTPOST_HORROR_HUNT_AT
