/**
 * # Stealth guards: where noise comes from
 *
 * Every hook that turns one of tg's own sounds into a stealth_noise() guards can hear. Each is a chained
 * override: the same proc defined again on the same type in this later-compiled file, calling ..() (the
 * model is cyberware_stealth.dm). No upstream file is edited. Each hook costs one call that returns at once
 * while no stealth group is alive, and does no work per object in the room.
 *
 * Every reach is at or under how far a player hears the same tg sound (abuse H2): a guard never hears what
 * a player standing in its place could not.
 *
 * Not hooked: mech and ship weapons (a mech is seen all round anyway), speech, machines.
 */

// ===== Guns (owner decisions 2 and 7) =====

/obj/item/gun
	/// How loud it is to stealth guards when it isn't suppressed (STEALTH_NOISE_GUN_*). A gun that sets
	/// nothing is as loud as a pistol.
	var/stealth_loudness = STEALTH_NOISE_GUN_PISTOL

// Quiet by nature
/obj/item/gun/ballistic/bow
	stealth_loudness = STEALTH_NOISE_GUN_QUIET

/obj/item/gun/ballistic/rifle/rebarxbow
	stealth_loudness = STEALTH_NOISE_GUN_QUIET

/obj/item/gun/syringe
	stealth_loudness = STEALTH_NOISE_GUN_QUIET

/obj/item/gun/chem
	stealth_loudness = STEALTH_NOISE_GUN_QUIET

// SMGs: the automatic root, with its pistols set back
/obj/item/gun/ballistic/automatic
	stealth_loudness = STEALTH_NOISE_GUN_SMG

/obj/item/gun/ballistic/automatic/pistol
	stealth_loudness = STEALTH_NOISE_GUN_PISTOL

/obj/item/gun/ballistic/automatic/gyropistol
	stealth_loudness = STEALTH_NOISE_GUN_PISTOL

/obj/item/gun/ballistic/automatic/toy
	stealth_loudness = STEALTH_NOISE_GUN_QUIET

// Long guns, launchers and heavy energy
/obj/item/gun/ballistic/rifle
	stealth_loudness = STEALTH_NOISE_GUN_LONG

/obj/item/gun/ballistic/shotgun
	stealth_loudness = STEALTH_NOISE_GUN_LONG

/obj/item/gun/ballistic/shotgun/toy
	stealth_loudness = STEALTH_NOISE_GUN_QUIET

/obj/item/gun/ballistic/automatic/ar
	stealth_loudness = STEALTH_NOISE_GUN_LONG

/obj/item/gun/ballistic/automatic/battle_rifle
	stealth_loudness = STEALTH_NOISE_GUN_LONG

/obj/item/gun/ballistic/automatic/m90
	stealth_loudness = STEALTH_NOISE_GUN_LONG

/obj/item/gun/ballistic/automatic/l6_saw
	stealth_loudness = STEALTH_NOISE_GUN_LONG

/obj/item/gun/ballistic/automatic/smartgun
	stealth_loudness = STEALTH_NOISE_GUN_LONG

/obj/item/gun/ballistic/rocketlauncher
	stealth_loudness = STEALTH_NOISE_GUN_LONG

/obj/item/gun/ballistic/revolver/grenadelauncher
	stealth_loudness = STEALTH_NOISE_GUN_LONG

/obj/item/gun/grenadelauncher
	stealth_loudness = STEALTH_NOISE_GUN_LONG

/obj/item/gun/blastcannon
	stealth_loudness = STEALTH_NOISE_GUN_LONG

/obj/item/gun/energy/lasercannon
	stealth_loudness = STEALTH_NOISE_GUN_LONG

/obj/item/gun/energy/pulse
	stealth_loudness = STEALTH_NOISE_GUN_LONG

/obj/item/gun/energy/ionrifle
	stealth_loudness = STEALTH_NOISE_GUN_LONG

/obj/item/gun/energy/tesla_cannon
	stealth_loudness = STEALTH_NOISE_GUN_LONG

/obj/item/gun/energy/minigun
	stealth_loudness = STEALTH_NOISE_GUN_LONG

/**
 * list(noise kind, reach) for a shot from this gun now. Any suppressed gun is in the quietest tier, whatever
 * it is (owner decision 7): a fitted suppressor, an integral one, the syringe gun. The reach is never more
 * than how far tg plays the gun's own sound to players, so a quiet custom gun doesn't carry further for
 * guards than for people.
 */
/obj/item/gun/proc/stealth_shot_noise()
	var/kind = suppressed ? STEALTH_NOISE_GUN_QUIET : stealth_loudness
	var/list/profile = stealth_noise_profile(kind)
	var/volume = suppressed ? suppressed_volume : fire_sound_volume
	if(isnull(profile) || volume <= SOUND_AUDIBLE_VOLUME_MIN)
		return list(kind, 0)
	// As fire_sounds() plays it. Plain numbers: the macro doesn't bracket its arguments.
	var/sound_range = SOUND_RANGE
	var/falloff = SOUND_DEFAULT_FALLOFF_DISTANCE
	if(suppressed)
		sound_range += SILENCED_SOUND_EXTRARANGE
		falloff = 0
	var/audible = CALCULATE_MAX_SOUND_AUDIBLE_DISTANCE(volume, sound_range, falloff, SOUND_FALLOFF_EXPONENT)
	return list(kind, min(profile[STEALTH_PROFILE_REACH], audible))

// Once per shot, bursts included, with the shooter. fire_sounds() is the wrong place: five types override it
// without calling the parent.
/obj/item/gun/shoot_live_shot(mob/living/user, pointblank = FALSE, atom/pbtarget = null, message = TRUE)
	. = ..()
	if(!length(GLOB.stealth_groups))
		return
	var/list/noise = stealth_shot_noise()
	stealth_noise(src, noise[1], noise[2], isliving(user) ? user : null)

// A round striking a wall, a window, a crate. A suppressed round's strike is nearly silent in tg (volume 5),
// so it is no lure; what it breaks is.
/obj/projectile/on_hit(atom/target, blocked = 0, pierce_hit)
	. = ..()
	if(!length(GLOB.stealth_groups) || isliving(target) || isnull(target))
		return
	stealth_noise(target, STEALTH_NOISE_IMPACT, suppressed ? STEALTH_NOISE_RANGE_IMPACT_QUIET : STEALTH_NOISE_RANGE_IMPACT, isliving(firer) ? firer : null)

// ===== Thrown things =====

/obj/item
	/// The noise it makes when a throw ends (STEALTH_NOISE_*), or null for a plain landing by its weight
	var/stealth_throw_noise

/// The noise this makes landing from a throw.
/obj/item/proc/stealth_throw_kind()
	return stealth_throw_noise || STEALTH_NOISE_THROWN

// A glass or a bottle smashes; a carton or a plastic bottle only lands.
/obj/item/reagent_containers/cup/glass/stealth_throw_kind()
	return isGlass ? STEALTH_NOISE_GLASS : ..()

// Landing, or hitting something that isn't a person. A throw that lands on a guard is a touch, which the
// guard's own controller deals with.
/obj/item/throw_impact(atom/hit_atom, datum/thrownthing/throwingdatum)
	// Read first: a bottle is gone once it has smashed.
	var/noisy = length(GLOB.stealth_groups) && !isliving(hit_atom)
	var/kind = noisy ? stealth_throw_kind() : null
	var/size = w_class
	. = ..()
	if(!noisy)
		return
	var/reach
	if(kind == STEALTH_NOISE_THROWN)
		if(size <= WEIGHT_CLASS_SMALL)
			reach = STEALTH_NOISE_RANGE_THROWN_SMALL
		else if(size == WEIGHT_CLASS_NORMAL)
			reach = STEALTH_NOISE_RANGE_THROWN_MEDIUM
		else
			reach = STEALTH_NOISE_RANGE_THROWN_HEAVY
	var/mob/living/thrower = throwingdatum?.get_thrower()
	stealth_noise(hit_atom, kind, reach, isliving(thrower) ? thrower : null)

// ===== Glass =====

/obj/structure/window/atom_deconstruct(disassembled = TRUE)
	if(!disassembled)
		stealth_noise(src, STEALTH_NOISE_GLASS)
	return ..()

// Shot out or smashed: only a tube that was whole makes the sound (tg's own rule).
/obj/machinery/light/break_light_tube(skip_sound_and_sparks = FALSE)
	var/whole = !skip_sound_and_sparks && (status == LIGHT_OK || status == LIGHT_BURNED)
	. = ..()
	if(whole)
		stealth_noise(src, STEALTH_NOISE_GLASS)

// Stepping on broken glass (decision 37): tg's own crunch, which plays at a walk too and through shoes. Shards of
// every kind and dropped bulbs and tubes are the things tg plays it for. Broken bottles hurt but make no sound in
// tg, so they make none here; prescription glasses crunch only under a running step, which is heard anyway.
/obj/item/shard/on_entered(datum/source, atom/movable/AM)
	. = ..()
	stealth_glass_step(src, AM)

/obj/item/light/on_entered(datum/source, atom/movable/moving_atom)
	. = ..()
	stealth_glass_step(src, moving_atom)

/// `stepper` walked onto `glass`: the crunch tg played, under tg's own rule for when it plays.
/proc/stealth_glass_step(atom/glass, atom/movable/stepper)
	if(!length(GLOB.stealth_groups) || !isliving(stepper) || QDELETED(glass))
		return
	var/mob/living/walker = stepper
	if((walker.movement_type & MOVETYPES_NOT_TOUCHING_GROUND) && !walker.buckled)
		return
	// A mouse or a roach on the glass is no lure: only something that weighs something carries.
	if(walker.mob_size <= MOB_SIZE_TINY)
		return
	var/reach = HAS_TRAIT(walker, TRAIT_LIGHT_STEP) ? STEALTH_NOISE_RANGE_CRUNCH_LIGHT : STEALTH_NOISE_RANGE_CRUNCH
	INVOKE_ASYNC(GLOBAL_PROC, GLOBAL_PROC_REF(stealth_noise), get_turf(glass), STEALTH_NOISE_CRUNCH, reach, walker)

// ===== Knocks =====

// Knuckles on a window with combat mode off, a fist with it on. Repeats the parent's two guards.
/obj/structure/window/attack_hand(mob/living/user, list/modifiers)
	. = ..()
	if(. || !length(GLOB.stealth_groups) || !can_be_reached(user))
		return
	stealth_noise(src, user.combat_mode ? STEALTH_NOISE_BASH : STEALTH_NOISE_KNOCK, null, user)

// "You push the wall but nothing happens!"
/turf/closed/wall/attack_hand(mob/user, list/modifiers)
	. = ..()
	if(. || !length(GLOB.stealth_groups))
		return
	stealth_noise(src, STEALTH_NOISE_KNOCK, null, isliving(user) ? user : null)

// An airlock refusing someone, or being forced. Nobody is named: a door with one of the group beside it is one
// of their own going through (stealth_noise()). An airlock opening or closing is every door's hook (stealth_doors.dm).
/obj/machinery/door/airlock/animation_effects(animation, force_type = DEFAULT_DOOR_CHECKS)
	. = ..()
	if(!length(GLOB.stealth_groups))
		return
	if(force_type == BYPASS_DOOR_CHECKS)
		stealth_noise(src, STEALTH_NOISE_BASH)
		return
	if(animation == DOOR_DENY_ANIMATION)
		stealth_noise(src, STEALTH_NOISE_KNOCK)

// Tools at work: a wrench or a crowbar is a knock, a welder or a drill is louder. Breaking in is a choice
// between slow and quiet, and fast and loud. Guards don't use tools.
/obj/item/play_tool_sound(atom/target, volume = 50)
	. = ..()
	if(!length(GLOB.stealth_groups) || !target || !usesound || !volume)
		return
	var/loud = tool_behaviour == TOOL_WELDER || tool_behaviour == TOOL_DRILL || tool_behaviour == TOOL_MINING
	stealth_noise(target, loud ? STEALTH_NOISE_BASH : STEALTH_NOISE_KNOCK, null, isliving(loc) ? loc : null)

// ===== Bodies and voices =====

// A body hitting the floor. Someone held in an aggressive grab or tighter is let down by whoever holds them:
// no thud. That is a rule about noise only; what happened to the body is whatever tg did to it.
/turf/handle_fall(mob/faller)
	. = ..()
	if(!length(GLOB.stealth_groups) || !isliving(faller) || !has_gravity(src))
		return
	if(faller.pulledby && faller.pulledby.grab_state >= GRAB_AGGRESSIVE)
		return
	stealth_noise(src, STEALTH_NOISE_THUD, null, faller)

// A whistle, a clap, a snap, a cough, a laugh, a scream: any emote whose sound tg plays now, under tg's own
// rules for when it plays (its cooldowns included).
/datum/emote/run_emote(mob/user, params, type_override, intentional = FALSE)
	var/sounded = FALSE
	if(length(GLOB.stealth_groups) && isliving(user))
		sounded = get_sound(user) && should_play_sound(user, intentional) && TIMER_COOLDOWN_FINISHED(user, "general_emote_audio_cooldown") && TIMER_COOLDOWN_FINISHED(user, type)
	. = ..()
	if(!sounded || QDELETED(user))
		return
	var/kind = STEALTH_NOISE_VOICE
	switch(key)
		if("scream", "screech")
			kind = STEALTH_NOISE_SCREAM
		if("deathgasp")
			kind = STEALTH_NOISE_THUD
	stealth_noise(user, kind, null, user)

// ===== Blasts =====
// Explosions: each group listens for COMSIG_GLOB_EXPLOSION (stealth_noise.dm).

// The parent deletes the grenade, and deafens whoever it catches before anyone hears it.
/obj/item/grenade/flashbang/detonate(mob/living/lanced_by)
	var/turf/where = get_turf(src)
	. = ..()
	if(. && where)
		stealth_noise(where, STEALTH_NOISE_BLAST)
