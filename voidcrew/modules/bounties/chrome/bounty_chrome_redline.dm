/**
 * # Redline core on a bounty fighter
 *
 * The rage OS from the ripperdoc (/obj/item/organ/cyberimp/cyberware/redline, ware_legend.dm),
 * fought the way an NPC fights: the same roar and the same collapse, over a shorter burn.
 *
 * It trips the first time a fight turns on them: a hit that leaves them at or under
 * REDLINE_TRIGGER_BELOW percent health (a mini-boss: the moment it tires, BOUNTY_BOSS_TIRED_BELOW),
 * or a stun, knockdown or stamina crit about to put them on the floor. That stun never lands. Only
 * in a fight: caught unaware, they go down like anyone else, though a fight they come into already
 * that badly hurt trips it at once (a blow lands before the fight it starts).
 * - The tell, REDLINE_WINDUP: the chest speaker charges, a red outline flickers over them, they shake
 *   and a dim red light comes up around them. Stuns slide off and brute and burn come in at
 *   REDLINE_DAMAGE_MULT already, so the rounds a hunter puts in while it charges don't finish the
 *   fight before it starts.
 * - The roar: the player implant's sounds. Hunters within REDLINE_ROAR_RANGE stagger.
 * - The burn, REDLINE_WINDOW (shorter than the player implant's CYBERWARE_REDLINE_WINDOW: an NPC's
 *   burn is the deadliest stretch of a capture, and the collapse is the hunters' reward for waiting
 *   it out): stuns, knockdowns and stamina crit slide off, stamina never slows them,
 *   brute and burn come in at REDLINE_DAMAGE_MULT (never under REDLINE_DAMAGE_FLOOR with a
 *   mini-boss's armour), every blow that lands does REDLINE_MELEE_BONUS more, and they neither give
 *   up nor run. A pulsing red outline and a red glow show it the whole time, and now and then a hit
 *   that barely moves them says so.
 * - The collapse: the player implant's crash line, then the floor in stamina crit (a knockdown where
 *   stamina crit can't land), so they can be cuffed, and slow for REDLINE_CRASH_SLOW. A companion in
 *   stamina crit gives up for good.
 * Counterplay: back off and wait for the collapse. An EMP in the tell or the burn drops them straight
 * into it; an EMP while it is armed knocks it offline for its reboot, so a stun lands meanwhile.
 *
 * Why it trips early and resists from the tell: real guns do 25-30 a round against 110-220 health,
 * so a line at 60% with an unprotected tell was crossed on the third round, the rounds fired while
 * it charged landed in full, and the burn began a round from the downed line (or, for a companion,
 * from death). The resistance is a little stronger than the player's for the same reason: an NPC's
 * whole fight lasts a few seconds of a crew's fire.
 *
 * The body's rules stand: the downed line, the mercy line and the cuffs are untouched, and a burn cut
 * off at the downed line ends quietly, with no collapse. It re-arms REDLINE_COOLDOWN after it trips.
 */

/// Percent of health at or under which a hit trips it (a mini-boss trips where it tires instead): a round or two into a gunfight
#define REDLINE_TRIGGER_BELOW 75
/// The tell before the roar
#define REDLINE_WINDUP (1.5 SECONDS)
/// The burn, from the roar to the collapse. The NPC's own: the player implant keeps CYBERWARE_REDLINE_WINDOW (ware_legend.dm)
#define REDLINE_WINDOW (8 SECONDS)
/// From tripping to being able to trip again (the player implant's cooldown)
#define REDLINE_COOLDOWN (90 SECONDS)
/// Incoming brute and burn multiplier from the tell to the collapse (the player implant's is 0.6)
#define REDLINE_DAMAGE_MULT 0.5
/// Brute and burn never come in at less than this, the fighter's own armour (damage_coeff) included
#define REDLINE_DAMAGE_FLOOR 0.5
/// Extra brute on every blow that lands during the burn (the player implant's)
#define REDLINE_MELEE_BONUS 8
/// Reach of the roar in tiles (the player implant's)
#define REDLINE_ROAR_RANGE 5
/// How long the roar staggers a hunter
#define REDLINE_ROAR_STAGGER (3 SECONDS)
/// How long they stay slow after the collapse, counted from the collapse
#define REDLINE_CRASH_SLOW (15 SECONDS)
/// The collapse where stamina crit can't land (a fresh mini-boss)
#define REDLINE_COLLAPSE_FALLBACK (10 SECONDS)
/// The red of the outline and the glow
#define REDLINE_COLOR "#ff2a2a"
/// The red glow's reach and strength through the burn, and the dimmer one that comes up in the tell: their own tile only (tg's falloff leaves a range under 1.5 dark)
#define REDLINE_GLOW_RANGE 2
#define REDLINE_GLOW_POWER 1
#define REDLINE_TELL_GLOW_RANGE 1.5
#define REDLINE_TELL_GLOW_POWER 1
/// Least time between two "barely flinches" lines
#define REDLINE_FLINCH_GAP (4 SECONDS)
/// Name of the outline filter
#define REDLINE_FILTER "bounty_chrome_redline"
/// Trait and immunity source
#define REDLINE_TRAIT "bounty_chrome_redline"
/// Its states
#define REDLINE_IDLE 0
#define REDLINE_WINDING 1
#define REDLINE_BURNING 2

/datum/bounty_chrome/redline
	key = BOUNTY_CHROME_REDLINE
	name = "Redline core"
	// A legend piece: rarer than the street chrome
	weight = 6
	min_tier = BOUNTY_TIER_WANTED
	archetypes = list(BOUNTY_ARCHETYPE_NORMAL, BOUNTY_ARCHETYPE_BOSS, BOUNTY_CHROME_COMPANION)
	// Not the Juggernaut's riot plates or the Heavy's armour: on top of those the burn is near-immortal
	kits = list(BOUNTY_KIT_PYROMANIAC, BOUNTY_KIT_DEMOLITIONIST, BOUNTY_KIT_GHOST)
	// The same OS slot as the Cascade lattice: one burst window per fighter
	exclusive_with = list(BOUNTY_CHROME_CASCADE)
	organ_looks = list(/obj/item/organ/cyberimp/cyberware/redline)
	/// REDLINE_IDLE, REDLINE_WINDING (the tell) or REDLINE_BURNING
	var/state = REDLINE_IDLE
	/// world.time it can trip again
	var/ready_at = 0
	/// The tell's timer, then the burn's
	var/burn_timer
	/// The end of the slow after the collapse
	var/crash_timer
	/// Their red glow, dim in the tell and full through the burn
	var/obj/effect/dummy/lighting_obj/moblight/glow
	/// Their health at the last update, so only a hit can trip it
	var/last_health
	/// Their surrender roll (a criminal) or run roll (a companion) from before the burn held it off
	var/held_roll = FALSE
	/// Whether the burn is holding that roll off now
	var/nerve_held = FALSE
	/// world.time the next "barely flinches" line may show
	var/next_flinch_at = 0

/datum/bounty_chrome/redline/Destroy(force)
	QDEL_NULL(glow)
	return ..()

/datum/bounty_chrome/redline/attach(mob/living/basic/fighter)
	..()
	last_health = fighter.health
	RegisterSignal(fighter, COMSIG_LIVING_HEALTH_UPDATE, PROC_REF(on_health_update))
	RegisterSignal(fighter, COMSIG_LIVING_GENERIC_STUN_CHECK, PROC_REF(on_stun_check))
	RegisterSignal(fighter, COMSIG_LIVING_STATUS_STUN, PROC_REF(on_stun))
	RegisterSignal(fighter, COMSIG_LIVING_STATUS_KNOCKDOWN, PROC_REF(on_knockdown))
	RegisterSignal(fighter, COMSIG_LIVING_STATUS_PARALYZE, PROC_REF(on_paralyze))

/datum/bounty_chrome/redline/detach()
	if(owner)
		end_burn(collapse = FALSE)
		end_crash()
		UnregisterSignal(owner, list(
			COMSIG_LIVING_HEALTH_UPDATE,
			COMSIG_LIVING_GENERIC_STUN_CHECK,
			COMSIG_LIVING_STATUS_STUN,
			COMSIG_LIVING_STATUS_KNOCKDOWN,
			COMSIG_LIVING_STATUS_PARALYZE,
		))
	..()

// ----- tripping -----

/// Whether it may trip now: working, armed, and its fighter in a fight it can take part in
/datum/bounty_chrome/redline/proc/can_trip()
	return online() && state == REDLINE_IDLE && world.time >= ready_at && in_fight()

/// Whether its fighter is in a fight now. A companion counts as fighting whenever it is able to, so for one it also has to have joined a fight.
/datum/bounty_chrome/redline/proc/in_fight()
	var/mob/living/basic/bounty_companion/companion = owner
	if(istype(companion) && !companion.ai_in_fight)
		return FALSE
	return bounty_chrome_fighting(owner)

/// The health at or under which a hit trips it: a mini-boss's tired line, anyone else's REDLINE_TRIGGER_BELOW
/datum/bounty_chrome/redline/proc/trip_health()
	if(istype(owner, /mob/living/basic/bounty_criminal/boss))
		return owner.maxHealth * BOUNTY_BOSS_TIRED_BELOW / 100
	return owner.maxHealth * REDLINE_TRIGGER_BELOW / 100

/// Health lost: a hit that leaves them badly hurt trips it, and mid-burn a hit that barely moves them shows it
/datum/bounty_chrome/redline/proc/on_health_update(mob/living/basic/source)
	SIGNAL_HANDLER
	var/health_before = last_health
	last_health = source.health
	if(isnull(health_before) || source.health >= health_before)
		return
	if(state == REDLINE_IDLE)
		trip_if_hurt()
		return
	if(world.time < next_flinch_at || source.health <= down_health())
		return
	next_flinch_at = world.time + REDLINE_FLINCH_GAP
	source.visible_message(span_warning("[source] barely flinches."), vision_distance = COMBAT_MESSAGE_RANGE)

/// The health at which the body takes over: a criminal's downed line (body_check_downed() runs right after a health update), anyone else's death
/datum/bounty_chrome/redline/proc/down_health()
	var/mob/living/basic/bounty_criminal/criminal = owner
	return istype(criminal) ? criminal.body_downed_line() : 0

/// Trips it if they are badly hurt, still on their feet, and it may trip now. TRUE if it tripped.
/datum/bounty_chrome/redline/proc/trip_if_hurt()
	if(owner.health > trip_health() || owner.health <= down_health() || !can_trip())
		return FALSE
	start_tell()
	return TRUE

/**
 * Every stun check: through the tell and the burn nothing lands. Armed, in a fight, a stamina crit
 * about to land trips it instead (stamina crit checks CANSTUN here before it starts; any other stun
 * is caught by its own signal below).
 */
/datum/bounty_chrome/redline/proc/on_stun_check(mob/living/basic/source, check_flags, force_stun)
	SIGNAL_HANDLER
	if(state != REDLINE_IDLE)
		return online() ? COMPONENT_NO_STUN : NONE
	if(!(check_flags & CANSTUN) || source.staminaloss < source.stamina_crit_threshold)
		return NONE
	// Already in stamina crit (it is only listed once it has landed), or it would not land anyway
	if(source.has_status_effect(/datum/status_effect/incapacitating/stamcrit) || (source.status_flags & check_flags) != check_flags)
		return NONE
	if(!can_trip())
		return NONE
	start_tell()
	return COMPONENT_NO_STUN

/datum/bounty_chrome/redline/proc/on_stun(mob/living/basic/source, amount, ignore_canstun)
	SIGNAL_HANDLER
	return stun_landing(source, amount, ignore_canstun, CANSTUN)

/datum/bounty_chrome/redline/proc/on_knockdown(mob/living/basic/source, amount, ignore_canstun)
	SIGNAL_HANDLER
	return stun_landing(source, amount, ignore_canstun, CANKNOCKDOWN)

/datum/bounty_chrome/redline/proc/on_paralyze(mob/living/basic/source, amount, ignore_canstun)
	SIGNAL_HANDLER
	return stun_landing(source, amount, ignore_canstun, CANSTUN | CANKNOCKDOWN)

/// A stun, knockdown or paralysis of `amount` needing `flags` is about to land: it trips instead, if armed and in a fight. A forced one (an admin's) always lands.
/datum/bounty_chrome/redline/proc/stun_landing(mob/living/basic/source, amount, ignore_canstun, flags)
	if(ignore_canstun || amount <= 0)
		return NONE
	if(state != REDLINE_IDLE)
		return online() ? COMPONENT_NO_STUN : NONE
	if(!can_trip() || source.check_stun_immunity(flags))
		return NONE
	start_tell()
	return COMPONENT_NO_STUN

// ----- the tell, the roar and the burn -----

/// It trips: stuns slide off and hits are resisted from now, the cooldown starts, and the chest speaker charges for REDLINE_WINDUP
/datum/bounty_chrome/redline/proc/start_tell()
	state = REDLINE_WINDING
	ready_at = world.time + REDLINE_COOLDOWN
	owner.add_traits(list(TRAIT_STUNIMMUNE, TRAIT_BATON_RESISTANCE), REDLINE_TRAIT)
	owner.add_movespeed_mod_immunities(REDLINE_TRAIT, /datum/movespeed_modifier/basic_stamina_slowdown)
	hold_nerve()
	show_outline(steady = FALSE)
	QDEL_NULL(glow)
	glow = owner.mob_light(REDLINE_TELL_GLOW_RANGE, REDLINE_TELL_GLOW_POWER, REDLINE_COLOR)
	owner.Shake(1, 0, REDLINE_WINDUP)
	playsound(owner, 'sound/effects/seedling_chargeup.ogg', 60, TRUE)
	owner.visible_message(span_boldwarning("[owner]'s chest speaker crackles and starts to glow red."))
	burn_timer = addtimer(CALLBACK(src, PROC_REF(roar)), REDLINE_WINDUP, TIMER_STOPPABLE | TIMER_DELETE_ME)

/// The tell is over: the roar, and the burn
/datum/bounty_chrome/redline/proc/roar()
	burn_timer = null
	if(state != REDLINE_WINDING || !online())
		return
	state = REDLINE_BURNING
	show_outline(steady = TRUE)
	QDEL_NULL(glow)
	glow = owner.mob_light(REDLINE_GLOW_RANGE, REDLINE_GLOW_POWER, REDLINE_COLOR)
	playsound(owner, 'sound/effects/magic/demon_attack1.ogg', 90, TRUE)
	playsound(owner, 'sound/effects/magic/repulse.ogg', 60, TRUE)
	owner.visible_message(span_boldwarning("[owner]'s eyes flood red and [owner.p_their()] chest speaker lets out a deafening ROAR!"))
	for(var/mob/living/hunter in ohearers(REDLINE_ROAR_RANGE, owner))
		if(!bounty_ai_is_hunter(hunter) || !bounty_ai_may_hit(owner, hunter))
			continue
		hunter.apply_status_effect(/datum/status_effect/staggered, REDLINE_ROAR_STAGGER)
		shake_camera(hunter, 3, 1)
		to_chat(hunter, span_userdanger("The roar hits you like a wall!"))
	burn_timer = addtimer(CALLBACK(src, PROC_REF(burn_out)), REDLINE_WINDOW, TIMER_STOPPABLE | TIMER_DELETE_ME)

/// The burn ran its course
/datum/bounty_chrome/redline/proc/burn_out()
	burn_timer = null
	end_burn(collapse = TRUE)

/// The red outline: flickering through the tell, a slow pulse through the burn
/datum/bounty_chrome/redline/proc/show_outline(steady)
	owner.remove_filter(REDLINE_FILTER)
	owner.add_filter(REDLINE_FILTER, 3, outline_filter(1, REDLINE_COLOR))
	var/filter = owner.get_filter(REDLINE_FILTER)
	if(!filter)
		return
	if(steady)
		animate(filter, size = 2, time = 0.5 SECONDS, loop = -1)
		animate(size = 1, time = 0.5 SECONDS)
	else
		animate(filter, size = 0, time = 0.1 SECONDS, loop = -1)
		animate(size = 1, time = 0.1 SECONDS)

/**
 * Ends the tell or the burn: the stun immunity, the outline, the glow and the held-off nerve go.
 * With `collapse`, and alive and not down at the downed line, they collapse. Returns TRUE if it was
 * running. Must not sleep: it runs from signal handlers.
 */
/datum/bounty_chrome/redline/proc/end_burn(collapse = FALSE)
	if(state == REDLINE_IDLE)
		return FALSE
	state = REDLINE_IDLE
	deltimer(burn_timer)
	burn_timer = null
	QDEL_NULL(glow)
	owner.remove_traits(list(TRAIT_STUNIMMUNE, TRAIT_BATON_RESISTANCE), REDLINE_TRAIT)
	owner.remove_movespeed_mod_immunities(REDLINE_TRAIT, /datum/movespeed_modifier/basic_stamina_slowdown)
	owner.remove_filter(REDLINE_FILTER)
	release_nerve()
	if(!collapse || QDELETED(owner) || owner.stat == DEAD)
		return TRUE
	var/mob/living/basic/bounty_criminal/criminal = owner
	if(istype(criminal) && criminal.downed)
		return TRUE
	crash()
	return TRUE

/// The collapse: down in stamina crit (a knockdown where that can't land), and slow for a while after
/datum/bounty_chrome/redline/proc/crash()
	playsound(owner, 'sound/machines/steam_hiss.ogg', 50, TRUE)
	owner.visible_message(span_warning("[owner] sags as the red drains out of [owner.p_their()] eyes."))
	owner.add_movespeed_modifier(/datum/movespeed_modifier/cyberware_redline_crash)
	deltimer(crash_timer)
	crash_timer = addtimer(CALLBACK(src, PROC_REF(end_crash)), REDLINE_CRASH_SLOW, TIMER_STOPPABLE | TIMER_DELETE_ME)
	owner.adjustStaminaLoss(owner.max_stamina, forced = TRUE)
	if(!owner.has_status_effect(/datum/status_effect/incapacitating/stamcrit))
		owner.Knockdown(REDLINE_COLLAPSE_FALLBACK, ignore_canstun = TRUE)
	var/mob/living/basic/bounty_criminal/criminal = owner
	if(istype(criminal))
		criminal.body_alert_hunters("burnt out")

/// The slow after the collapse is over
/datum/bounty_chrome/redline/proc/end_crash()
	deltimer(crash_timer)
	crash_timer = null
	owner?.remove_movespeed_modifier(/datum/movespeed_modifier/cyberware_redline_crash)

/**
 * Nobody gives up mid-roar: a criminal's surrender roll (P3's ai_surrender_rolled and
 * ai_next_surrender_roll) and a companion's run roll (ai_flee_rolled) are held off through the burn,
 * and put back as they were after. A crossing made during the burn is not rolled again; later hits
 * roll as usual.
 */
/datum/bounty_chrome/redline/proc/hold_nerve()
	if(nerve_held)
		return
	var/mob/living/basic/bounty_criminal/criminal = owner
	if(istype(criminal))
		held_roll = criminal.ai_surrender_rolled
		criminal.ai_surrender_rolled = TRUE
		criminal.ai_next_surrender_roll = max(criminal.ai_next_surrender_roll, world.time + REDLINE_WINDUP + REDLINE_WINDOW)
		nerve_held = TRUE
		return
	var/mob/living/basic/bounty_companion/companion = owner
	if(istype(companion))
		held_roll = companion.ai_flee_rolled
		companion.ai_flee_rolled = TRUE
		nerve_held = TRUE

/datum/bounty_chrome/redline/proc/release_nerve()
	if(!nerve_held)
		return
	nerve_held = FALSE
	var/mob/living/basic/bounty_criminal/criminal = owner
	if(istype(criminal))
		criminal.ai_surrender_rolled = held_roll
		return
	var/mob/living/basic/bounty_companion/companion = owner
	if(istype(companion))
		companion.ai_flee_rolled = held_roll

// ----- the framework's hooks -----

// A fight that starts with them already badly hurt: a blow lands before the fight it starts (an item's hit, an ambush)
/datum/bounty_chrome/redline/on_fight_start(atom/target)
	if(state == REDLINE_IDLE)
		trip_if_hurt()

/datum/bounty_chrome/redline/on_tick(seconds_per_tick, fighting)
	if(state == REDLINE_IDLE)
		return
	// Cuffed, given up or passing as someone else mid-burn (an admin, a script): it stops, quietly
	var/mob/living/basic/bounty_criminal/criminal = owner
	if(istype(criminal) && (criminal.is_restrained() || HAS_TRAIT(criminal, TRAIT_BOUNTY_SURRENDERED) || criminal.hidden || criminal.blended))
		end_burn(collapse = FALSE)

// From the tell on: the rounds that land while it charges are resisted too
/datum/bounty_chrome/redline/modify_damage(list/damage_mods, damage, damagetype)
	if(state == REDLINE_IDLE || !(damagetype in list(BRUTE, BURN)))
		return
	damage_mods += damage_mult(damagetype)

/// The burn's multiplier on `damagetype`: REDLINE_DAMAGE_MULT, eased off so their own armour and it together never go under REDLINE_DAMAGE_FLOOR
/datum/bounty_chrome/redline/proc/damage_mult(damagetype)
	var/coeff = owner.damage_coeff?[damagetype]
	if(isnull(coeff) || coeff <= 0)
		return REDLINE_DAMAGE_MULT
	return clamp(REDLINE_DAMAGE_FLOOR / coeff, REDLINE_DAMAGE_MULT, 1)

/// Every blow that lands in the burn hits harder: REDLINE_MELEE_BONUS more brute, through armour, no second wound
/datum/bounty_chrome/redline/on_melee_hit(mob/living/target)
	if(state != REDLINE_BURNING || QDELETED(owner) || QDELETED(target) || target.stat == DEAD)
		return
	var/zone = target.get_random_valid_zone(owner.zone_selected)
	var/armour = target.run_armor_check(zone, MELEE, armour_penetration = owner.armour_penetration, silent = TRUE)
	target.apply_damage(npc_zone_damage(REDLINE_MELEE_BONUS, owner), BRUTE, zone, armour, wound_bonus = CANT_WOUND)

// Down at the downed line, or a companion gave up: the burn ends there, with no collapse
/datum/bounty_chrome/redline/on_downed()
	end_burn(collapse = FALSE)

/datum/bounty_chrome/redline/on_death()
	end_burn(collapse = FALSE)
	end_crash()

// A pulse in the tell or the burn scrambles the core: straight into the collapse, and the full cooldown again
/datum/bounty_chrome/redline/on_emp(severity)
	if(state == REDLINE_IDLE)
		return
	ready_at = world.time + REDLINE_COOLDOWN
	end_burn(collapse = TRUE)

/datum/bounty_chrome/redline/examine_line()
	if(state != REDLINE_IDLE)
		return "Red light pours out of the speaker grille in %THEIR chest."
	if(!online() || world.time < ready_at)
		return "The speaker grille in %THEIR chest is dark."
	return "A red-lit speaker grille sits in %THEIR chest."

#undef REDLINE_TRIGGER_BELOW
#undef REDLINE_WINDUP
#undef REDLINE_WINDOW
#undef REDLINE_COOLDOWN
#undef REDLINE_DAMAGE_MULT
#undef REDLINE_DAMAGE_FLOOR
#undef REDLINE_MELEE_BONUS
#undef REDLINE_ROAR_RANGE
#undef REDLINE_ROAR_STAGGER
#undef REDLINE_CRASH_SLOW
#undef REDLINE_COLLAPSE_FALLBACK
#undef REDLINE_COLOR
#undef REDLINE_GLOW_RANGE
#undef REDLINE_GLOW_POWER
#undef REDLINE_TELL_GLOW_RANGE
#undef REDLINE_TELL_GLOW_POWER
#undef REDLINE_FLINCH_GAP
#undef REDLINE_FILTER
#undef REDLINE_TRAIT
#undef REDLINE_IDLE
#undef REDLINE_WINDING
#undef REDLINE_BURNING
