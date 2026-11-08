/**
 * # Bounty chrome: Meteor Piledriver
 *
 * The player's legendary leg frame (/obj/item/organ/cyberimp/cyberware/piledriver, ware_legend.dm) on
 * a bounty fighter, used the way the player version is: a leap onto a hunter that crushes whoever is
 * still under it and knocks everyone around flat.
 *
 * How a leap goes:
 * - In a fight, off cooldown, with its target BOUNTY_PILEDRIVER_MIN_RANGE to BOUNTY_PILEDRIVER_RANGE
 *   tiles off, in sight, with gravity, an open arc (no wall, window or shut door on the line; tables,
 *   crates and railings are cleared) and a safe tile to land on inside its leash.
 * - Crouch (BOUNTY_PILEDRIVER_CROUCH): it dips and trembles in an amber outline and the pistons
 *   whine. It stands still.
 * - Launch: the target's tile is locked (or the free tile beside them, if they stand on a table or
 *   sit in a mech), and the player implant's warning shadow covers everything the landing reaches.
 *   It rises for BOUNTY_PILEDRIVER_AIRTIME. If the target slipped out of reach during the crouch,
 *   the pistons settle and it tries again soon.
 * - Landing: it drops onto the locked tile. A hunter still on it is crushed; every hunter within
 *   BOUNTY_PILEDRIVER_RING tiles that the shockwave can reach (not through walls, windows or shut
 *   doors) is knocked down and pushed a tile back. Its own gang, other criminals, fauna and anyone
 *   down are never touched; a mech takes it on the hull.
 * - Recovery (BOUNTY_PILEDRIVER_RECOVERY): the pistons vent and it stands still, open to anything.
 *
 * Counterplay: step out of the shadow; stay close (it never leaps at someone within
 * BOUNTY_PILEDRIVER_MIN_RANGE); fight round corners, behind windows or across a door; no gravity, no
 * leap. Shutting a door across its arc while it is in the air, or an EMP then, drops it short in a
 * heap. Stunned, knocked down, downed or killed while crouched or in the air, it never lands: shot
 * down mid-air, it drops where it took off with a thud for everyone to see (fall()).
 *
 * A mini-boss runs the leap inside its busy state (bounty_boss.dm), so the leap and its kit's
 * abilities never overlap; anyone else is held still with its AI paused for the length of it.
 */

/// Closest a target may be for a leap: anyone nearer is fought hand to hand
#define BOUNTY_PILEDRIVER_MIN_RANGE 3
/// Furthest a leap reaches
#define BOUNTY_PILEDRIVER_RANGE 7
/// The crouch before it launches
#define BOUNTY_PILEDRIVER_CROUCH (0.6 SECONDS)
/// Time in the air, with the shadow on the floor: the window to step off it. The player version's is 0.8 s.
#define BOUNTY_PILEDRIVER_AIRTIME (1 SECONDS)
/// Standing still after landing while the pistons vent
#define BOUNTY_PILEDRIVER_RECOVERY (1.5 SECONDS)
/// Between leaps, counted from the launch. A mini-boss's stretches once it tires, as its own abilities do.
#define BOUNTY_PILEDRIVER_COOLDOWN (14 SECONDS)
#define BOUNTY_PILEDRIVER_BOSS_COOLDOWN (16 SECONDS)
/// How long into a fight before the first leap: early enough that it comes inside the fight
#define BOUNTY_PILEDRIVER_OPENING (1.5 SECONDS)
/// After a crouch that came to nothing (the target slipped out of reach), the next try
#define BOUNTY_PILEDRIVER_RETRY (4 SECONDS)
/// After an EMP wears off, before it may leap again
#define BOUNTY_PILEDRIVER_REBOOT_DELAY (3 SECONDS)
/// Pixels it rises, and dips in the crouch
#define BOUNTY_PILEDRIVER_HEIGHT 64
#define BOUNTY_PILEDRIVER_DIP 3
/// Tiles around the landing that the shockwave reaches
#define BOUNTY_PILEDRIVER_RING 2
/// The shockwave: brute to a leg through armour, a knockdown, and a tile's push
#define BOUNTY_PILEDRIVER_RING_DAMAGE 12
#define BOUNTY_PILEDRIVER_RING_KNOCKDOWN (1.5 SECONDS)
/// The shockwave on a mech's hull
#define BOUNTY_PILEDRIVER_MECH_DAMAGE 20
/// A direct hit: brute split over two limbs through armour, enough to crack bone, and pinned to the floor
#define BOUNTY_PILEDRIVER_CRUSH_DAMAGE 36
#define BOUNTY_PILEDRIVER_CRUSH_WOUND 5
#define BOUNTY_PILEDRIVER_CRUSH_PARALYZE (2 SECONDS)
#define BOUNTY_PILEDRIVER_CRUSH_SQUISH (10 SECONDS)
/// Dropped short (an EMP, a door shut across the arc): down this long, or a mini-boss reels this long taking this much more damage
#define BOUNTY_PILEDRIVER_CRASH (2.5 SECONDS)
#define BOUNTY_PILEDRIVER_CRASH_VULNERABLE 1.25
/// Trait and offset source while it leaps, and a mini-boss's busy state
#define BOUNTY_PILEDRIVER_SOURCE "bounty_chrome_piledriver"
/// The outline through the crouch, in piston amber, as the other pieces' wind-ups glow in theirs
#define BOUNTY_PILEDRIVER_GLOW_FILTER "bounty_piledriver_glow"
#define BOUNTY_PILEDRIVER_GLOW_COLOR "#ffb347"
/// What the leap is doing
#define BOUNTY_PILEDRIVER_IDLE 0
#define BOUNTY_PILEDRIVER_CROUCHING 1
#define BOUNTY_PILEDRIVER_AIRBORNE 2
#define BOUNTY_PILEDRIVER_RECOVERING 3

/datum/bounty_chrome/piledriver
	key = BOUNTY_CHROME_PILEDRIVER
	name = "Meteor Piledriver"
	// The rarest legendary: a Wanted criminal or worse, and never a meek one or a companion
	weight = 4
	min_tier = BOUNTY_TIER_WANTED
	archetypes = list(BOUNTY_ARCHETYPE_NORMAL, BOUNTY_ARCHETYPE_BOSS)
	// Of the mini-bosses, only the Pyromaniac: the Juggernaut already charges and slams, the Ghost
	// already dashes, and the Demolitionist and the Heavy fight from range or rely on being slow.
	kits = list(BOUNTY_KIT_PYROMANIAC)
	// Two gap-closers that knock people down would be one too many
	exclusive_with = list(BOUNTY_CHROME_MANTIS)
	organ_looks = list(/obj/item/organ/cyberimp/cyberware/piledriver)
	examine_text = "Heavy launch pistons are sleeved over %THEIR legs."
	/// BOUNTY_PILEDRIVER_IDLE, _CROUCHING, _AIRBORNE or _RECOVERING
	var/phase = BOUNTY_PILEDRIVER_IDLE
	/// Goes up when a leap starts or ends, so a timer from an earlier one does nothing
	var/serial = 0
	/// world.time the next leap may start
	var/next_leap_at = 0
	/// Who the crouch is aimed at
	var/datum/weakref/leap_target
	/// Where it launched from, and the tile it is coming down on
	var/turf/origin
	var/turf/landing
	/// The landing shadow showing now
	var/datum/weakref/shadow_ref
	/// A mini-boss's busy serial for this leap
	var/boss_serial = 0

/datum/bounty_chrome/piledriver/Destroy(force)
	end_leap()
	return ..()

/datum/bounty_chrome/piledriver/attach(mob/living/basic/fighter)
	. = ..()
	// Stunned, knocked down, downed or giving up mid-leap, it never lands
	RegisterSignals(fighter, list(
		SIGNAL_ADDTRAIT(TRAIT_FLOORED),
		SIGNAL_ADDTRAIT(TRAIT_INCAPACITATED),
		SIGNAL_ADDTRAIT(TRAIT_BOUNTY_SURRENDERED),
	), PROC_REF(on_grounded))

/datum/bounty_chrome/piledriver/detach()
	end_leap()
	if(owner)
		UnregisterSignal(owner, list(
			SIGNAL_ADDTRAIT(TRAIT_FLOORED),
			SIGNAL_ADDTRAIT(TRAIT_INCAPACITATED),
			SIGNAL_ADDTRAIT(TRAIT_BOUNTY_SURRENDERED),
		))
	return ..()

// ----- the hooks -----

/datum/bounty_chrome/piledriver/on_fight_start(atom/target)
	var/opening = world.time + BOUNTY_PILEDRIVER_OPENING
	if(opening <= next_leap_at)
		return
	next_leap_at = opening
	// Life() comes every two seconds: the first leap waits on its own timer, not on whichever tick comes after it
	addtimer(CALLBACK(src, PROC_REF(opening_check)), BOUNTY_PILEDRIVER_OPENING, TIMER_DELETE_ME)

/// The opening leap's own check, on time: what the next Life tick would do
/datum/bounty_chrome/piledriver/proc/opening_check()
	if(online())
		on_tick(0, bounty_chrome_fighting(owner))

/datum/bounty_chrome/piledriver/on_tick(seconds_per_tick, fighting)
	if(fighting && phase == BOUNTY_PILEDRIVER_IDLE && world.time >= next_leap_at)
		try_leap(bounty_chrome_target(owner))

/datum/bounty_chrome/piledriver/on_emp(severity)
	switch(phase)
		if(BOUNTY_PILEDRIVER_CROUCHING)
			end_leap()
		if(BOUNTY_PILEDRIVER_AIRBORNE)
			crash("[owner]'s pistons cut out and [owner.p_they()] drop[owner.p_s()] like a stone!")
	// Venting already, it finishes venting: an EMP never hands it the fight back early

/datum/bounty_chrome/piledriver/on_reboot()
	next_leap_at = max(next_leap_at, world.time + BOUNTY_PILEDRIVER_REBOOT_DELAY)

/datum/bounty_chrome/piledriver/on_downed()
	if(phase == BOUNTY_PILEDRIVER_AIRBORNE)
		fall()
		return
	end_leap()

/datum/bounty_chrome/piledriver/on_death()
	if(phase == BOUNTY_PILEDRIVER_AIRBORNE)
		fall()
		return
	end_leap()

/// Floored, stunned or giving up while crouched or in the air: it comes down where it stands, harmlessly. Out of the air, everyone sees and hears it drop.
/datum/bounty_chrome/piledriver/proc/on_grounded(datum/source)
	SIGNAL_HANDLER
	if(phase == BOUNTY_PILEDRIVER_AIRBORNE)
		fall()
	else if(phase == BOUNTY_PILEDRIVER_CROUCHING)
		end_leap()

/**
 * Shot, stunned or killed out of the air: it drops back onto the tile it took off from, with a thud
 * and a puff of dust, and nothing under the shadow is hit. Whatever brought it down already has it
 * on the floor, so nothing more is done to it.
 */
/datum/bounty_chrome/piledriver/proc/fall()
	var/mob/living/basic/fighter = owner
	end_leap()
	if(QDELETED(fighter))
		return
	var/turf/here = get_turf(fighter)
	playsound(here, 'sound/effects/bang.ogg', 50, TRUE)
	new /obj/effect/temp_visual/mook_dust/small(here)
	fighter.visible_message(span_warning("[fighter] drops out of the air!"))

// ----- the leap -----

/// Starts a leap at `target` if it can: a crouch now, the launch after BOUNTY_PILEDRIVER_CROUCH. Returns TRUE if it crouched.
/datum/bounty_chrome/piledriver/proc/try_leap(atom/movable/target)
	if(phase != BOUNTY_PILEDRIVER_IDLE || !online() || !free_to_leap())
		return FALSE
	if(!landing_for(target))
		return FALSE
	serial++
	phase = BOUNTY_PILEDRIVER_CROUCHING
	leap_target = WEAKREF(target)
	hold(BOUNTY_PILEDRIVER_CROUCH + BOUNTY_PILEDRIVER_AIRTIME + BOUNTY_PILEDRIVER_RECOVERY)
	owner.face_atom(target)
	owner.add_offsets(BOUNTY_PILEDRIVER_SOURCE, z_add = -BOUNTY_PILEDRIVER_DIP)
	owner.add_filter(BOUNTY_PILEDRIVER_GLOW_FILTER, 2, outline_filter(1, BOUNTY_PILEDRIVER_GLOW_COLOR))
	owner.Shake(1, 0, BOUNTY_PILEDRIVER_CROUCH)
	playsound(owner, 'sound/machines/piston/piston_lower.ogg', 60, TRUE)
	owner.visible_message(span_warning("[owner] drops into a crouch, [owner.p_their()] leg pistons whining."))
	addtimer(CALLBACK(src, PROC_REF(launch), serial), BOUNTY_PILEDRIVER_CROUCH, TIMER_DELETE_ME)
	return TRUE

/// The crouch is over: it locks the tile and goes up, or settles if its target got out of reach. Returns TRUE if it launched.
/datum/bounty_chrome/piledriver/proc/launch(leap_serial)
	if(leap_serial != serial || phase != BOUNTY_PILEDRIVER_CROUCHING)
		return FALSE
	owner.remove_offsets(BOUNTY_PILEDRIVER_SOURCE, animate = FALSE)
	owner.remove_filter(BOUNTY_PILEDRIVER_GLOW_FILTER)
	if(!still_held() || !able())
		end_leap()
		return FALSE
	var/turf/spot = landing_for(leap_target?.resolve())
	if(!spot)
		end_leap()
		next_leap_at = world.time + BOUNTY_PILEDRIVER_RETRY
		playsound(owner, 'sound/machines/steam_hiss.ogg', 40, TRUE)
		owner.visible_message(span_notice("[owner]'s leg pistons hiss and settle."))
		return FALSE
	phase = BOUNTY_PILEDRIVER_AIRBORNE
	origin = get_turf(owner)
	landing = spot
	next_leap_at = world.time + leap_cooldown()
	owner.face_atom(spot)
	playsound(origin, 'sound/effects/gravhit.ogg', 70, TRUE)
	playsound(origin, 'sound/machines/piston/piston_raise.ogg', 50, TRUE)
	new /obj/effect/temp_visual/mook_dust(origin)
	shadow_ref = WEAKREF(new /obj/effect/temp_visual/cyberware_piledriver_shadow/bounty(spot))
	// Up over its own tile, as the player version goes. Coming down puts its offsets back (remove_offsets()).
	animate(owner, pixel_z = BOUNTY_PILEDRIVER_HEIGHT, time = BOUNTY_PILEDRIVER_AIRTIME * 0.5, easing = QUAD_EASING|EASE_OUT, flags = ANIMATION_RELATIVE|ANIMATION_PARALLEL)
	owner.visible_message(span_boldwarning("[owner]'s leg pistons crack the floor and [owner.p_they()] launch[owner.p_es()] into the air!"))
	addtimer(CALLBACK(src, PROC_REF(land), serial), BOUNTY_PILEDRIVER_AIRTIME, TIMER_DELETE_ME)
	return TRUE

/// The air time is over: it comes down on the locked tile, or beside it if that was blocked meanwhile. Returns TRUE if it landed.
/datum/bounty_chrome/piledriver/proc/land(leap_serial)
	if(leap_serial != serial || phase != BOUNTY_PILEDRIVER_AIRBORNE)
		return FALSE
	if(!still_held() || !able())
		end_leap()
		return FALSE
	var/turf/final = landing
	if(!safe_landing(final) || arc_blocked(origin, final))
		final = free_tile_beside(landing, origin)
	if(!final)
		// A door shut across the arc, or the floor went: it comes down short
		crash("[owner] comes down short and crashes to the floor!")
		return FALSE
	impact(final)
	return TRUE

/// Comes down on `final`: whoever it may hurt there is crushed, everyone else in reach is knocked flat
/datum/bounty_chrome/piledriver/proc/impact(turf/final)
	var/list/crushed = list()
	for(var/mob/living/pinned in final)
		if(may_hit(pinned, leap_target?.resolve()))
			crushed += pinned
	// Gathered before anyone is pushed, so nobody is caught twice
	var/list/shaken = list()
	for(var/turf/spot as anything in RANGE_TURFS(BOUNTY_PILEDRIVER_RING, final))
		if(spot == final)
			continue
		var/list/caught = list()
		for(var/atom/movable/thing in spot)
			if((isliving(thing) || ismecha(thing)) && may_hit(thing, leap_target?.resolve()))
				caught += thing
		if(length(caught) && !arc_blocked(final, spot))
			shaken += caught
	owner.forceMove(final)
	clear_shadow()
	owner.remove_offsets(BOUNTY_PILEDRIVER_SOURCE)
	phase = BOUNTY_PILEDRIVER_RECOVERING
	playsound(final, 'sound/effects/meteorimpact.ogg', 90, TRUE)
	new /obj/effect/temp_visual/mook_dust(final)
	new /obj/effect/temp_visual/circle_wave/bounty_piledriver(final)
	owner.visible_message(span_boldwarning("[owner] lands like a meteor and the floor jumps!"))
	for(var/mob/living/victim as anything in crushed)
		crush(victim)
	for(var/atom/movable/victim as anything in shaken)
		shockwave(victim)
	for(var/mob/living/witness in SSspatial_grid.orthogonal_range_search(final, SPATIAL_GRID_CONTENTS_TYPE_CLIENTS, 7))
		if(get_dist(witness, final) <= 7)
			shake_camera(witness, 3, 1)
	// The vent: it stands there a moment, open to anything
	playsound(final, 'sound/machines/steam_hiss.ogg', 50, TRUE)
	new /obj/effect/temp_visual/small_smoke/halfsecond(final)
	addtimer(CALLBACK(src, PROC_REF(recover), serial), BOUNTY_PILEDRIVER_RECOVERY, TIMER_DELETE_ME)

/// A direct hit on `victim`: the player version's crush, with armour counted and a shorter pin
/datum/bounty_chrome/piledriver/proc/crush(mob/living/victim)
	if(QDELETED(victim))
		return
	var/damage = npc_zone_damage(BOUNTY_PILEDRIVER_CRUSH_DAMAGE, owner)
	if(iscarbon(victim))
		for(var/i in 1 to 2)
			var/zone = pick(BODY_ZONE_CHEST, BODY_ZONE_L_ARM, BODY_ZONE_R_ARM, BODY_ZONE_L_LEG, BODY_ZONE_R_LEG)
			victim.apply_damage(damage / 2, BRUTE, zone, victim.run_armor_check(zone, MELEE, silent = TRUE), wound_bonus = BOUNTY_PILEDRIVER_CRUSH_WOUND, attack_direction = owner.dir)
		victim.AddElement(/datum/element/squish, BOUNTY_PILEDRIVER_CRUSH_SQUISH)
	else
		victim.apply_damage(damage, BRUTE, null, victim.run_armor_check(null, MELEE, silent = TRUE), attack_direction = owner.dir)
	victim.Paralyze(BOUNTY_PILEDRIVER_CRUSH_PARALYZE)
	victim.emote("scream")
	playsound(victim, 'sound/effects/blob/blobattack.ogg', 40, TRUE)
	playsound(victim, 'sound/effects/splat.ogg', 50, TRUE)
	shake_camera(victim, 6, 2)
	victim.visible_message(
		span_danger("[owner] comes down square on top of [victim]!"),
		span_userdanger("[owner] lands square on top of you!"),
	)
	log_combat(owner, victim, "crushed with a Meteor Piledriver landing")

/// The shockwave reaching `victim`: a hunter is hurt, knocked down and pushed a tile back (never onto a hazard); a mech takes it on the hull
/datum/bounty_chrome/piledriver/proc/shockwave(atom/movable/victim)
	if(QDELETED(victim))
		return
	if(ismecha(victim))
		var/obj/vehicle/sealed/mecha/mech = victim
		mech.take_damage(npc_zone_damage(BOUNTY_PILEDRIVER_MECH_DAMAGE, owner), BRUTE, MELEE, TRUE, get_dir(mech, owner))
		return
	var/mob/living/person = victim
	var/zone = pick(BODY_ZONE_L_LEG, BODY_ZONE_R_LEG)
	person.apply_damage(npc_zone_damage(BOUNTY_PILEDRIVER_RING_DAMAGE, owner), BRUTE, zone, person.run_armor_check(zone, MELEE, silent = TRUE), attack_direction = get_dir(owner, person))
	person.Knockdown(BOUNTY_PILEDRIVER_RING_KNOCKDOWN)
	bounty_throw_back(owner, person, 1, 1, gentle = TRUE)
	shake_camera(person, 4, 2)
	person.visible_message(
		span_warning("The shockwave takes [person] off [person.p_their()] feet!"),
		span_userdanger("The floor jumps under you and throws you flat!"),
	)
	log_combat(owner, person, "knocked down with a Meteor Piledriver landing")

/// The vent is over: it fights on. Returns TRUE if that ended the leap.
/datum/bounty_chrome/piledriver/proc/recover(leap_serial)
	if(leap_serial != serial || phase != BOUNTY_PILEDRIVER_RECOVERING)
		return FALSE
	end_leap()
	return TRUE

/// Dropped short (an EMP, a door shut across the arc): down where it stands, saying `message`. A mini-boss reels instead, as off a wall.
/datum/bounty_chrome/piledriver/proc/crash(message)
	var/mob/living/basic/fighter = owner
	end_leap()
	if(QDELETED(fighter) || fighter.stat == DEAD)
		return
	playsound(fighter, 'sound/effects/bang.ogg', 60, TRUE)
	new /obj/effect/temp_visual/mook_dust/small(get_turf(fighter))
	fighter.visible_message(span_danger(message))
	if(istype(fighter, /mob/living/basic/bounty_criminal/boss))
		var/mob/living/basic/bounty_criminal/boss/boss = fighter
		boss.boss_stagger(BOUNTY_PILEDRIVER_CRASH, BOUNTY_PILEDRIVER_CRASH_VULNERABLE)
		return
	fighter.Knockdown(BOUNTY_PILEDRIVER_CRASH)

/**
 * Ends whatever part of a leap is under way and puts everything back: no shadow, its offsets as they
 * were (down from the air if it was up), the hold let go, and every timer from it stale. Safe at any
 * time, its owner being deleted included.
 */
/datum/bounty_chrome/piledriver/proc/end_leap()
	var/was_leaping = phase != BOUNTY_PILEDRIVER_IDLE
	phase = BOUNTY_PILEDRIVER_IDLE
	serial++
	leap_target = null
	origin = null
	landing = null
	clear_shadow()
	if(!owner || !was_leaping)
		return
	owner.remove_offsets(BOUNTY_PILEDRIVER_SOURCE)
	owner.remove_filter(BOUNTY_PILEDRIVER_GLOW_FILTER)
	release()

/// Takes the landing shadow off the floor, if it is still there
/datum/bounty_chrome/piledriver/proc/clear_shadow()
	var/obj/effect/shadow = shadow_ref?.resolve()
	shadow_ref = null
	if(!QDELETED(shadow))
		qdel(shadow)

// ----- holding it still -----

/// Holds it still for a leap of `duration`: a mini-boss in its busy state, anyone else with its AI paused
/datum/bounty_chrome/piledriver/proc/hold(duration)
	if(istype(owner, /mob/living/basic/bounty_criminal/boss))
		var/mob/living/basic/bounty_criminal/boss/boss = owner
		boss_serial = boss.boss_set_busy(BOUNTY_PILEDRIVER_SOURCE, duration + 1 SECONDS)
		boss.boss_next_ability_at = max(boss.boss_next_ability_at, world.time + duration + rand(BOUNTY_BOSS_ABILITY_GAP_MIN, BOUNTY_BOSS_ABILITY_GAP_MAX))
		return
	owner.add_traits(list(TRAIT_IMMOBILIZED, TRAIT_AI_PAUSED), BOUNTY_PILEDRIVER_SOURCE)

/// Lets go of the hold, if it is still its own
/datum/bounty_chrome/piledriver/proc/release()
	if(istype(owner, /mob/living/basic/bounty_criminal/boss))
		var/mob/living/basic/bounty_criminal/boss/boss = owner
		if(boss_serial && boss.boss_busy == BOUNTY_PILEDRIVER_SOURCE && boss.boss_busy_serial == boss_serial)
			boss.boss_clear_busy(boss_serial)
		boss_serial = 0
		return
	owner.remove_traits(list(TRAIT_IMMOBILIZED, TRAIT_AI_PAUSED), BOUNTY_PILEDRIVER_SOURCE)

/// Whether its hold is still on: a mini-boss interrupted out of its busy state has lost it
/datum/bounty_chrome/piledriver/proc/still_held()
	if(istype(owner, /mob/living/basic/bounty_criminal/boss))
		var/mob/living/basic/bounty_criminal/boss/boss = owner
		return boss_serial && boss.boss_busy == BOUNTY_PILEDRIVER_SOURCE && boss.boss_busy_serial == boss_serial
	return HAS_TRAIT_FROM(owner, TRAIT_AI_PAUSED, BOUNTY_PILEDRIVER_SOURCE)

// ----- the rules -----

/// Whether it can act at all: alive and awake on a turf, not buckled or dragged, and by its kind's own rules not down, cuffed, stunned, giving up, hiding or blending in
/datum/bounty_chrome/piledriver/proc/able()
	if(QDELETED(owner) || owner.stat != CONSCIOUS || !isturf(owner.loc) || owner.buckled || owner.pulledby)
		return FALSE
	if(istype(owner, /mob/living/basic/bounty_criminal/boss))
		var/mob/living/basic/bounty_criminal/boss/boss = owner
		return boss.boss_can_act()
	if(istype(owner, /mob/living/basic/bounty_criminal))
		var/mob/living/basic/bounty_criminal/criminal = owner
		return criminal.ai_can_act() && !criminal.hidden && !criminal.blended
	if(istype(owner, /mob/living/basic/bounty_companion))
		var/mob/living/basic/bounty_companion/companion = owner
		return companion.ai_can_fight()
	return FALSE

/// Whether a leap may start now: able, nobody playing it (an admin who took it over is never thrown about), and a mini-boss free of its own abilities
/datum/bounty_chrome/piledriver/proc/free_to_leap()
	if(!able() || owner.client)
		return FALSE
	if(istype(owner, /mob/living/basic/bounty_criminal/boss))
		var/mob/living/basic/bounty_criminal/boss/boss = owner
		return boss.boss_can_use_ability()
	return TRUE

/// Time to the next leap after a launch
/datum/bounty_chrome/piledriver/proc/leap_cooldown()
	if(istype(owner, /mob/living/basic/bounty_criminal/boss))
		var/mob/living/basic/bounty_criminal/boss/boss = owner
		return BOUNTY_PILEDRIVER_BOSS_COOLDOWN * boss.boss_cooldown_mult()
	return BOUNTY_PILEDRIVER_COOLDOWN

/**
 * Whether the landing may hurt `victim`: a hunter (someone played, awake, not a criminal or one of
 * their friends, not on its side) its kind may attack from where it stands, or a mech with one
 * aboard. A mini-boss goes by its own rules (boss_can_hurt()). Never anyone standing in a ship, a
 * hangar or an outpost, and never a bystander: only the one it is `aimed` at, or someone else in the
 * fight (bounty_chrome_may_splash()).
 */
/datum/bounty_chrome/piledriver/proc/may_hit(atom/movable/victim, atom/aimed)
	if(QDELETED(victim) || victim == owner)
		return FALSE
	if(istype(owner, /mob/living/basic/bounty_criminal/boss))
		var/mob/living/basic/bounty_criminal/boss/boss = owner
		return boss.boss_can_hurt(victim) && bounty_chrome_in_posse(owner, victim, aimed)
	var/mob/living/basic/bounty_criminal/side = bounty_ai_side_of(owner)
	if(side?.body_forbidden_turf(get_turf(victim)))
		return FALSE
	if(ismecha(victim))
		var/obj/vehicle/sealed/mecha/mech = victim
		for(var/mob/living/pilot in mech.occupants)
			if(bounty_ai_is_hunter(pilot) && !owner.faction_check_atom(pilot))
				return bounty_chrome_may_splash(owner, mech, aimed)
		return FALSE
	var/mob/living/person = victim
	if(!isliving(person) || !bounty_ai_is_hunter(person) || HAS_TRAIT(person, TRAIT_GODMODE) || owner.faction_check_atom(person))
		return FALSE
	return bounty_chrome_may_splash(owner, person, aimed)

/**
 * The tile a leap at `target` comes down on, or null if there is no leap to make: a hunter (or a
 * mech with one) it may hurt, BOUNTY_PILEDRIVER_MIN_RANGE to BOUNTY_PILEDRIVER_RANGE tiles off and
 * in sight, with gravity under it. Their own tile if it can land there with an open arc, else the
 * nearest such tile beside them.
 */
/datum/bounty_chrome/piledriver/proc/landing_for(atom/movable/target)
	if(QDELETED(target) || !(isliving(target) || ismecha(target)) || !may_hit(target, target))
		return null
	var/turf/here = get_turf(owner)
	var/turf/aim = get_turf(target)
	if(!here || !aim || here.z != aim.z || !here.has_gravity())
		return null
	var/distance = get_dist(here, aim)
	if(distance < BOUNTY_PILEDRIVER_MIN_RANGE || distance > BOUNTY_PILEDRIVER_RANGE || !can_see(owner, aim, BOUNTY_PILEDRIVER_RANGE))
		return null
	if(safe_landing(aim) && !arc_blocked(here, aim))
		return aim
	return free_tile_beside(aim, here)

/// The tile beside `center` nearest `start` that it can land on with an open arc from `start`, or null. Never `start` or a tile next to it.
/datum/bounty_chrome/piledriver/proc/free_tile_beside(turf/center, turf/start)
	if(!center || !start)
		return null
	var/turf/best
	var/best_distance = INFINITY
	for(var/turf/beside as anything in RANGE_TURFS(1, center))
		var/from_here = get_dist(start, beside)
		if(beside == center || from_here < 2 || from_here >= best_distance)
			continue
		if(!safe_landing(beside) || arc_blocked(start, beside))
			continue
		best = beside
		best_distance = from_here
	return best

/// Whether it can come down on `spot`: solid floor with gravity, nothing dense on it but people, never lava, a chasm or space, and inside its leash
/datum/bounty_chrome/piledriver/proc/safe_landing(turf/spot)
	if(!spot || spot.density || isspaceturf(spot) || isopenspaceturf(spot) || isgroundlessturf(spot) || islava(spot) || ischasm(spot))
		return FALSE
	if(spot.is_blocked_turf(exclude_mobs = TRUE) || !spot.has_gravity())
		return FALSE
	var/mob/living/basic/bounty_criminal/side = bounty_ai_side_of(owner)
	if(side)
		return side.leash_ok(spot)
	return spot.can_cross_safely(owner)

/**
 * Whether something stops an arc from `start` to `finish` (both turfs): a wall, a window or a shut
 * door anywhere on the line, or anything else dense that a thrown thing wouldn't sail over and
 * nobody could climb. The player version's rule (/datum/action/cooldown/cyberware/proc/arc_blocker),
 * except that a window or a shut door stops it on whichever edge of its tile it stands. People
 * never do.
 */
/datum/bounty_chrome/piledriver/proc/arc_blocked(turf/start, turf/finish)
	if(!start || !finish || start.z != finish.z)
		return TRUE
	for(var/turf/crossed as anything in get_line(start, finish))
		if(crossed == start)
			continue
		if(crossed.density)
			return TRUE
		for(var/obj/obstacle in crossed)
			if(!obstacle.density)
				continue
			if(istype(obstacle, /obj/machinery/door) || istype(obstacle, /obj/structure/window))
				return TRUE
			if((obstacle.flags_1 & ON_BORDER_1) || (obstacle.pass_flags_self & LETPASSTHROW) || HAS_TRAIT(obstacle, TRAIT_CLIMBABLE))
				continue
			return TRUE
	return FALSE

// ===== VISUALS =====

/// The player implant's landing shadow, held for the NPC's longer air time and grown to cover everything the landing reaches
/obj/effect/temp_visual/cyberware_piledriver_shadow/bounty
	duration = BOUNTY_PILEDRIVER_AIRTIME

/obj/effect/temp_visual/cyberware_piledriver_shadow/bounty/Initialize(mapload)
	appearance_flags |= PIXEL_SCALE
	// The sprite covers three tiles across; the shockwave reaches BOUNTY_PILEDRIVER_RING tiles out
	transform = matrix().Scale((BOUNTY_PILEDRIVER_RING * 2 + 1) / 3)
	return ..()

/// The shockwave rolling out from the landing, as far as it reaches
/obj/effect/temp_visual/circle_wave/bounty_piledriver
	color = "#b8a48a"
	duration = 0.4 SECONDS
	max_alpha = 200
	// The ring sprite is two tiles across
	amount_to_scale = (BOUNTY_PILEDRIVER_RING * 2 + 1) / 2

#undef BOUNTY_PILEDRIVER_MIN_RANGE
#undef BOUNTY_PILEDRIVER_RANGE
#undef BOUNTY_PILEDRIVER_CROUCH
#undef BOUNTY_PILEDRIVER_AIRTIME
#undef BOUNTY_PILEDRIVER_RECOVERY
#undef BOUNTY_PILEDRIVER_COOLDOWN
#undef BOUNTY_PILEDRIVER_BOSS_COOLDOWN
#undef BOUNTY_PILEDRIVER_OPENING
#undef BOUNTY_PILEDRIVER_RETRY
#undef BOUNTY_PILEDRIVER_REBOOT_DELAY
#undef BOUNTY_PILEDRIVER_HEIGHT
#undef BOUNTY_PILEDRIVER_DIP
#undef BOUNTY_PILEDRIVER_RING
#undef BOUNTY_PILEDRIVER_RING_DAMAGE
#undef BOUNTY_PILEDRIVER_RING_KNOCKDOWN
#undef BOUNTY_PILEDRIVER_MECH_DAMAGE
#undef BOUNTY_PILEDRIVER_CRUSH_DAMAGE
#undef BOUNTY_PILEDRIVER_CRUSH_WOUND
#undef BOUNTY_PILEDRIVER_CRUSH_PARALYZE
#undef BOUNTY_PILEDRIVER_CRUSH_SQUISH
#undef BOUNTY_PILEDRIVER_CRASH
#undef BOUNTY_PILEDRIVER_CRASH_VULNERABLE
#undef BOUNTY_PILEDRIVER_SOURCE
#undef BOUNTY_PILEDRIVER_GLOW_FILTER
#undef BOUNTY_PILEDRIVER_GLOW_COLOR
#undef BOUNTY_PILEDRIVER_IDLE
#undef BOUNTY_PILEDRIVER_CROUCHING
#undef BOUNTY_PILEDRIVER_AIRBORNE
#undef BOUNTY_PILEDRIVER_RECOVERING
