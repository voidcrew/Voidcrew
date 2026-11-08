/**
 * # Bounty chrome: the Cascade lattice
 *
 * The player's sandevistan (/obj/item/organ/cyberimp/cyberware/cascade, ware_legend.dm) in a
 * criminal's spine, fought the way an NPC fights. Its look, sounds, afterimages and dodge are the
 * player lattice's own, so a hunter who has seen one in a crewmate knows this one.
 *
 * A surge, start to finish:
 * - Spin-up (BOUNTY_CASCADE_SPINUP_TIME): a violet outline and a rising whine. The beat a hunter
 *   gets: an EMP now crashes it before the window opens.
 * - Window (BOUNTY_CASCADE_WINDOW_TIME): the time-tear (the player lattice's sound, four tinted
 *   copies flying apart, a violet flash on the screens of hunters who see it), then speed, an
 *   afterimage on every step, the player lattice's dodge against shots while moving (never
 *   point-blank, cyberware_register_dodge_source()), quicker blows and quicker shots. A gunman at
 *   range sidesteps every BOUNTY_CASCADE_STRAFE_GAP, so it is always on the move, and anyone standing
 *   still between steps (a gunman aiming, a brawler swinging) keeps blurring with afterimages that
 *   slide off them (shimmer()), so the surge shows on every fighter, not only on one who runs.
 * - Held in place (TRAIT_IMMOBILIZED: a Piledriver crouch or leap, a lunge, a Gorilla stumble), it
 *   neither sidesteps nor dodges. A companion's steps stay on its criminal's leash; one whose
 *   criminal is gone has no leash left, so it neither sidesteps nor dodges.
 * - Crash (BOUNTY_CASCADE_CRASH_TIME): drained grey, slow, slower blows, a stamina dump, and
 *   stamina hits land BOUNTY_CASCADE_CRASH_STAMINA_MULT times as hard. The capture window.
 * An EMP during the spin-up or the window crashes it at once and re-arms the full cooldown, as it
 * does the player's. Going down, dying, or the piece coming out ends everything with no crash; the
 * fight ending mid-window (cuffed, surrendered, stamina-crit, fled) crashes it.
 *
 * The pace: its speed changes are movespeed modifiers of its own, on top of the AI's set_varspeed()
 * pace, so ai_set_pace() and a boss's tiredness keep working through a surge and nothing is left
 * behind when it ends. A fighter keeps up with a running hunter (BOUNTY_FIGHT_SPEED); in the window
 * it covers ground twice as fast, and in the crash it is down to a walk.
 */

/// The phases of a surge
#define BOUNTY_CASCADE_IDLE 0
#define BOUNTY_CASCADE_SPINUP 1
#define BOUNTY_CASCADE_WINDOW 2
#define BOUNTY_CASCADE_CRASH 3

/// The whine before the tear: the beat a hunter gets to react
#define BOUNTY_CASCADE_SPINUP_TIME (1.5 SECONDS)
/// The window, as long as the player lattice's
#define BOUNTY_CASCADE_WINDOW_TIME (8 SECONDS)
/// The crash, as long as the player lattice's
#define BOUNTY_CASCADE_CRASH_TIME (6 SECONDS)
/// From the start of one surge to the earliest start of the next
#define BOUNTY_CASCADE_COOLDOWN (45 SECONDS)
/// The first surge of a fight comes this long after it starts, somewhere between the two: the spin-up
/// whines inside the fight's opening seconds, so the window opens while there is still a fight
#define BOUNTY_CASCADE_FIRST_MIN (0.5 SECONDS)
#define BOUNTY_CASCADE_FIRST_MAX (1.5 SECONDS)
/// After an EMP reboot it waits at least this long before it may surge
#define BOUNTY_CASCADE_REBOOT_DELAY (4 SECONDS)
/// It only surges with its target this close and in sight
#define BOUNTY_CASCADE_RANGE 7
/// Chance in percent to dodge a shot while moving in the window, the player lattice's
#define BOUNTY_CASCADE_DODGE 40
/// Time between blows multiplied by this in the window and in the crash
#define BOUNTY_CASCADE_WINDOW_BLOWS 0.75
#define BOUNTY_CASCADE_CRASH_BLOWS 1.4
/// Time between shots multiplied by this in the window
#define BOUNTY_CASCADE_WINDOW_SHOTS 0.75
/// Stamina damage multiplied by this in the crash
#define BOUNTY_CASCADE_CRASH_STAMINA_MULT 2
/// Stamina the crash dumps on them as it starts, before their own stamina coefficient
#define BOUNTY_CASCADE_CRASH_STAMINA 20
/// The window's loop: it checks the fight is still on this often, and blurs a fighter who stood still since the last one
#define BOUNTY_CASCADE_PULSE (0.2 SECONDS)
/// A gunman at range sidesteps this often in the window
#define BOUNTY_CASCADE_STRAFE_GAP (0.8 SECONDS)
/// How far a standing fighter's blur slides off them, in pixels, and how long it takes
#define BOUNTY_CASCADE_SHIMMER_MIN 6
#define BOUNTY_CASCADE_SHIMMER_MAX 10
#define BOUNTY_CASCADE_SHIMMER_SLIDE (0.3 SECONDS)
/// Degrees the afterimage hue moves per step, the player lattice's
#define BOUNTY_CASCADE_HUE_STEP 25
/// The dodge source key on the shared arbiter
#define BOUNTY_CASCADE_DODGE_KEY "bounty_cascade"
/// Filter names on the fighter
#define BOUNTY_CASCADE_GLOW_FILTER "bounty_cascade_glow"
#define BOUNTY_CASCADE_CRASH_FILTER "bounty_cascade_crash"
/// The spin-up and window outline, and the flash on hunters' screens at the tear
#define BOUNTY_CASCADE_GLOW_COLOR "#c86bff"
#define BOUNTY_CASCADE_FLASH_COLOR "#c8a0ff"

/datum/bounty_chrome/cascade
	key = BOUNTY_CHROME_CASCADE
	name = "Cascade lattice"
	// A legend piece: rare, and only on the dangerous
	weight = 6
	min_tier = BOUNTY_TIER_WANTED
	archetypes = list(BOUNTY_ARCHETYPE_NORMAL, BOUNTY_ARCHETYPE_BOSS, BOUNTY_CHROME_COMPANION)
	// The Ghost already dodges and darts, and the Heavy's whole fight is being slow and flanked
	kits = list(BOUNTY_KIT_JUGGERNAUT, BOUNTY_KIT_PYROMANIAC, BOUNTY_KIT_DEMOLITIONIST)
	// Both are a burst window: one per fighter
	exclusive_with = list(BOUNTY_CHROME_REDLINE)
	organ_looks = list(/obj/item/organ/cyberimp/cyberware/cascade)
	/// BOUNTY_CASCADE_IDLE, _SPINUP, _WINDOW or _CRASH
	var/phase = BOUNTY_CASCADE_IDLE
	/// world.time the next surge may start
	var/next_surge_at = 0
	/// The timer that takes it to its next phase
	var/phase_timer
	/// The window's loop: the fight check, a gunman's sidestep and a standing fighter's blur
	var/strafe_timer
	/// Hue of the next afterimage, in degrees
	var/trail_hue = 0
	/// world.time of its last dodge roll: one a tick
	var/last_dodge_roll = -1
	/// world.time of its last step, and of the window's next sidestep
	var/last_step_at = 0
	var/next_strafe_at = 0

/datum/bounty_chrome/cascade/detach()
	end_surge()
	return ..()

/datum/bounty_chrome/cascade/on_fight_start(atom/target)
	var/opening = world.time + rand(BOUNTY_CASCADE_FIRST_MIN, BOUNTY_CASCADE_FIRST_MAX)
	if(opening <= next_surge_at)
		return
	next_surge_at = opening
	// Life() comes every two seconds: the first surge waits on its own timer, not on whichever tick comes after it
	addtimer(CALLBACK(src, PROC_REF(opening_check)), opening - world.time, TIMER_DELETE_ME)

/// The opening surge's own check, on time: what the next Life tick would do
/datum/bounty_chrome/cascade/proc/opening_check()
	if(online())
		on_tick(0, bounty_chrome_fighting(owner))

/datum/bounty_chrome/cascade/on_tick(seconds_per_tick, fighting)
	if(fighting && in_fight())
		if(phase == BOUNTY_CASCADE_IDLE && world.time >= next_surge_at && ready_to_surge())
			spin_up()
		return
	// Out of the fight: a surge winding up fizzles, and an open window crashes
	switch(phase)
		if(BOUNTY_CASCADE_SPINUP)
			end_surge()
		if(BOUNTY_CASCADE_WINDOW)
			start_crash()

/// Whether its owner is in a fight now. A companion counts only once it has joined one: bounty_chrome_fighting() is true for one sitting at the bar.
/datum/bounty_chrome/cascade/proc/in_fight()
	if(!owner || !bounty_chrome_fighting(owner))
		return FALSE
	var/mob/living/basic/bounty_companion/companion = owner
	return !istype(companion) || companion.ai_in_fight

/// Whether it may start a surge now: on its feet in the open, not busy with a boss ability, and its target close and in sight
/datum/bounty_chrome/cascade/proc/ready_to_surge()
	if(!isturf(owner.loc) || owner.stat != CONSCIOUS || owner.buckled)
		return FALSE
	var/mob/living/basic/bounty_criminal/boss/boss = owner
	if(istype(boss) && boss.boss_busy)
		return FALSE
	var/atom/target = bounty_chrome_target(owner)
	return !QDELETED(target) && bounty_ai_can_see(owner, target, BOUNTY_CASCADE_RANGE)

/// The tell: a violet outline and a rising whine, and the window opens BOUNTY_CASCADE_SPINUP_TIME later
/datum/bounty_chrome/cascade/proc/spin_up()
	phase = BOUNTY_CASCADE_SPINUP
	next_surge_at = world.time + BOUNTY_CASCADE_COOLDOWN
	owner.add_filter(BOUNTY_CASCADE_GLOW_FILTER, 2, outline_filter(1, BOUNTY_CASCADE_GLOW_COLOR))
	playsound(owner, 'sound/effects/magic/charge.ogg', 50, TRUE)
	owner.visible_message(span_warning("[owner]'s spine lights up with a rising whine."))
	deltimer(phase_timer)
	phase_timer = addtimer(CALLBACK(src, PROC_REF(open_window)), BOUNTY_CASCADE_SPINUP_TIME, TIMER_STOPPABLE | TIMER_DELETE_ME)

/// The time-tear: speed, afterimages, the dodge and quicker hands, until the crash
/datum/bounty_chrome/cascade/proc/open_window()
	if(phase != BOUNTY_CASCADE_SPINUP || !owner)
		return
	stop_timers()
	// Went down, got cuffed or lost the fight in the beat: it fizzles
	if(!online() || !in_fight() || !isturf(owner.loc))
		end_surge()
		return
	phase = BOUNTY_CASCADE_WINDOW
	trail_hue = rand(0, 359)
	last_step_at = world.time
	next_strafe_at = world.time + BOUNTY_CASCADE_STRAFE_GAP
	owner.add_movespeed_modifier(/datum/movespeed_modifier/bounty_cascade)
	set_blows(BOUNTY_CASCADE_WINDOW_BLOWS)
	cyberware_register_dodge_source(owner, BOUNTY_CASCADE_DODGE_KEY, CALLBACK(src, PROC_REF(dodge_chance)))
	RegisterSignal(owner, COMSIG_MOVABLE_MOVED, PROC_REF(on_moved), override = TRUE)
	// A criminal's own Move() already keeps it on its leash (leash_ok()); a companion's needs this for the dodge's sidestep
	if(!istype(owner, /mob/living/basic/bounty_criminal))
		RegisterSignal(owner, COMSIG_MOVABLE_PRE_MOVE, PROC_REF(on_pre_move), override = TRUE)
	time_tear()
	phase_timer = addtimer(CALLBACK(src, PROC_REF(start_crash)), BOUNTY_CASCADE_WINDOW_TIME, TIMER_STOPPABLE | TIMER_DELETE_ME)
	strafe_timer = addtimer(CALLBACK(src, PROC_REF(window_pulse)), BOUNTY_CASCADE_PULSE, TIMER_STOPPABLE | TIMER_DELETE_ME)

/// The tear everyone sees and hears: the player lattice's sound, four tinted copies flying apart, and a violet flash for hunters who see it
/datum/bounty_chrome/cascade/proc/time_tear()
	playsound(owner, 'sound/effects/magic/timeparadox2.ogg', 70, TRUE)
	owner.visible_message(span_boldwarning("[owner] fractures into afterimages and blurs into motion!"))
	var/turf/here = get_turf(owner)
	var/static/list/shard_offsets = list(list(-8, 4), list(8, 4), list(-6, -6), list(6, -6))
	for(var/index in 1 to length(shard_offsets))
		var/list/offset = shard_offsets[index]
		var/obj/effect/temp_visual/decoy/fading/cascade/shard = new(here, owner, (trail_hue + index * 90) % 360)
		animate(shard, pixel_x = shard.pixel_x + offset[1], pixel_y = shard.pixel_y + offset[2], time = 0.4 SECONDS, flags = ANIMATION_PARALLEL)
	for(var/mob/living/viewer in get_hearers_in_view(DEFAULT_MESSAGE_RANGE, owner, RECURSIVE_CONTENTS_CLIENT_MOBS))
		if(viewer.is_blind() || !bounty_ai_is_hunter(viewer))
			continue
		flash_color(viewer, flash_color = BOUNTY_CASCADE_FLASH_COLOR, flash_time = 4)

/// The window's loop: crashes it if the fight stopped (cuffed, surrendered, stamina-crit, fled), keeps a gunman moving, and blurs anyone standing still
/datum/bounty_chrome/cascade/proc/window_pulse()
	if(phase != BOUNTY_CASCADE_WINDOW || !owner)
		return
	deltimer(strafe_timer)
	strafe_timer = null
	if(!in_fight())
		start_crash()
		return
	strafe_timer = addtimer(CALLBACK(src, PROC_REF(window_pulse)), BOUNTY_CASCADE_PULSE, TIMER_STOPPABLE | TIMER_DELETE_ME)
	if(world.time >= next_strafe_at)
		next_strafe_at = world.time + BOUNTY_CASCADE_STRAFE_GAP
		sidestep()
	if(world.time - last_step_at >= BOUNTY_CASCADE_PULSE)
		shimmer()

/// A fighter standing still in the window still blurs: an afterimage of them slides off to one side and fades, as their trail would if they ran
/datum/bounty_chrome/cascade/proc/shimmer()
	var/turf/here = get_turf(owner)
	if(!here || !isturf(owner.loc))
		return
	var/obj/effect/temp_visual/decoy/fading/cascade/blur = new(here, owner, trail_hue)
	// Behind them, so it shows at their edge and never over their face
	blur.layer = BELOW_MOB_LAYER
	trail_hue = (trail_hue + BOUNTY_CASCADE_HUE_STEP) % 360
	var/slide = pick(-1, 1) * rand(BOUNTY_CASCADE_SHIMMER_MIN, BOUNTY_CASCADE_SHIMMER_MAX)
	animate(blur, pixel_x = blur.pixel_x + slide, time = BOUNTY_CASCADE_SHIMMER_SLIDE, easing = QUAD_EASING | EASE_OUT, flags = ANIMATION_PARALLEL)

/// A gunman at range takes a step to one side of its target, never off its leash or onto lava, a chasm or space, and never while held in place
/datum/bounty_chrome/cascade/proc/sidestep()
	var/datum/bounty_style/style = bounty_ai_style(owner)
	if(!style?.ranged || !isturf(owner.loc) || owner.buckled || owner.pulledby || HAS_TRAIT(owner, TRAIT_IMMOBILIZED) || leashless())
		return
	// One step of its own at a time, shared with the step out of a friend's line of fire (bounty_ai_normal.dm)
	var/datum/ai_controller/controller = owner.ai_controller
	if(QDELETED(controller) || world.time < controller.blackboard[BB_BOUNTY_SIDESTEP_AT])
		return
	var/atom/target = bounty_chrome_target(owner)
	var/turf/target_turf = get_turf(target)
	if(!target_turf || target_turf.z != owner.z)
		return
	var/distance = get_dist(owner, target_turf)
	if(distance < 2 || distance > BOUNTY_FIGHT_VISION)
		return
	var/toward = get_dir(owner, target_turf)
	var/mob/living/basic/bounty_criminal/leash_holder = bounty_ai_side_of(owner)
	for(var/side in shuffle(list(turn(toward, 90), turn(toward, -90))))
		var/turf/spot = get_step(owner, side)
		if(!spot || spot.is_blocked_turf(source_atom = owner) || islava(spot) || ischasm(spot) || !spot.can_cross_safely(owner))
			continue
		if(leash_holder && !leash_holder.leash_ok(spot))
			continue
		if(owner.Move(spot, side))
			controller.set_blackboard_key(BB_BOUNTY_SIDESTEP_AT, world.time + owner.cached_multiplicative_slowdown)
			owner.face_atom(target)
			return

/// Their time between blows, through /mob/living/changeNext_move(): `mult` of it, or back to normal at 1
/datum/bounty_chrome/cascade/proc/set_blows(mult)
	if(mult == 1)
		owner.remove_status_effect(/datum/status_effect/bounty_cascade)
		return
	var/datum/status_effect/bounty_cascade/effect = owner.has_status_effect(/datum/status_effect/bounty_cascade) || owner.apply_status_effect(/datum/status_effect/bounty_cascade)
	effect?.blow_mult = mult

/**
 * The dodge source on the player lattice's arbiter: only in the window, and only while it is
 * fighting. One roll a tick: of a shell's pellets, or of shots landing together, only the first may be
 * dodged, so buckshot finds it and it never blurs two tiles at once. Never while held in place (the
 * dodge is a step aside), and never for a companion with no criminal's leash to keep that step on.
 */
/datum/bounty_chrome/cascade/proc/dodge_chance()
	if(phase != BOUNTY_CASCADE_WINDOW || !online() || !in_fight() || last_dodge_roll == world.time)
		return 0
	if(HAS_TRAIT(owner, TRAIT_IMMOBILIZED) || leashless())
		return 0
	last_dodge_roll = world.time
	return BOUNTY_CASCADE_DODGE

/// A companion whose criminal is gone: nothing holds its steps to a site any more
/datum/bounty_chrome/cascade/proc/leashless()
	return istype(owner, /mob/living/basic/bounty_companion) && !bounty_ai_side_of(owner)

/// One afterimage per step, the hue rolling on, as the player lattice's trail
/datum/bounty_chrome/cascade/proc/on_moved(atom/movable/source, atom/old_loc, dir, forced)
	SIGNAL_HANDLER
	last_step_at = world.time
	if(!isturf(old_loc))
		return
	new /obj/effect/temp_visual/decoy/fading/cascade(old_loc, owner, trail_hue)
	trail_hue = (trail_hue + BOUNTY_CASCADE_HUE_STEP) % 360

/**
 * A companion's own steps in the window stay on its criminal's leash (as a criminal's own Move()
 * does) and never go onto lava or into a chasm: the player lattice's dodge sidesteps blind. One
 * already off its leash may still step about, as a criminal may (body_move_allowed()).
 */
/datum/bounty_chrome/cascade/proc/on_pre_move(atom/movable/source, atom/new_loc)
	SIGNAL_HANDLER
	var/turf/destination = new_loc
	if(!isturf(destination) || !isturf(owner.loc) || owner.throwing || owner.pulledby || owner.buckled)
		return NONE
	if((islava(destination) || ischasm(destination)) && !destination.can_cross_safely(owner))
		return COMPONENT_MOVABLE_BLOCK_PRE_MOVE
	var/mob/living/basic/bounty_criminal/leader = bounty_ai_side_of(owner)
	if(leader && !leader.leash_ok(destination) && leader.leash_ok(owner.loc))
		return COMPONENT_MOVABLE_BLOCK_PRE_MOVE
	return NONE

/// In the window a shot readies the next one sooner (once a burst: later rounds of it find the gun already quick)
/datum/bounty_chrome/cascade/on_fire(obj/projectile/shot, atom/original)
	if(phase != BOUNTY_CASCADE_WINDOW)
		return
	var/datum/component/ranged_attacks/gun = owner.GetComponent(/datum/component/ranged_attacks)
	if(!gun?.cooldown_time)
		return
	var/quick = world.time + gun.cooldown_time * BOUNTY_CASCADE_WINDOW_SHOTS
	if(gun.fire_cooldown > quick)
		gun.fire_cooldown = quick

/// The heat bill: slow, slower blows, a stamina dump, and stamina hits land harder. The capture window.
/datum/bounty_chrome/cascade/proc/start_crash()
	if(!owner || phase == BOUNTY_CASCADE_CRASH)
		return
	stop_timers()
	clear_effects()
	if(owner.stat == DEAD)
		phase = BOUNTY_CASCADE_IDLE
		return
	phase = BOUNTY_CASCADE_CRASH
	owner.add_movespeed_modifier(/datum/movespeed_modifier/bounty_cascade_crash)
	set_blows(BOUNTY_CASCADE_CRASH_BLOWS)
	// Its own hook, not modify_damage(): an EMP's crash runs while the piece is offline
	RegisterSignal(owner, COMSIG_MOB_APPLY_DAMAGE_MODIFIERS, PROC_REF(on_crash_damage_mods), override = TRUE)
	// The player lattice's crash colours, on the body instead of the screen
	owner.add_filter(BOUNTY_CASCADE_CRASH_FILTER, 2, color_matrix_filter(list(0.55, 0.3, 0.25, 0.35, 0.55, 0.25, 0.25, 0.25, 0.5)))
	playsound(owner, 'sound/machines/warning-buzzer.ogg', 50, TRUE)
	owner.visible_message(span_warning("[owner] stumbles, suddenly slow and heavy."))
	owner.Shake(1, 0, 0.5 SECONDS)
	phase_timer = addtimer(CALLBACK(src, PROC_REF(end_crash)), BOUNTY_CASCADE_CRASH_TIME, TIMER_STOPPABLE | TIMER_DELETE_ME)
	// Last: a dump that stamina-crits a companion makes it give up, which ends the surge (on_downed())
	owner.adjustStaminaLoss(BOUNTY_CASCADE_CRASH_STAMINA)

/datum/bounty_chrome/cascade/proc/on_crash_damage_mods(datum/source, list/damage_mods, damage, damagetype, def_zone, sharpness, attack_direction, obj/item/attacking_item)
	SIGNAL_HANDLER
	if(damagetype == STAMINA)
		damage_mods += BOUNTY_CASCADE_CRASH_STAMINA_MULT

/// The crash wears off
/datum/bounty_chrome/cascade/proc/end_crash()
	if(phase != BOUNTY_CASCADE_CRASH || !owner)
		return
	end_surge()
	if(in_fight())
		owner.visible_message(span_notice("[owner] shakes it off."))

/// Ends whatever part of a surge is running, with no crash, and puts everything back
/datum/bounty_chrome/cascade/proc/end_surge()
	stop_timers()
	clear_effects()
	phase = BOUNTY_CASCADE_IDLE

/datum/bounty_chrome/cascade/proc/stop_timers()
	deltimer(phase_timer)
	phase_timer = null
	deltimer(strafe_timer)
	strafe_timer = null

/// Takes off everything a surge puts on its owner: both paces, the blow timing, the dodge, the trail, the outline and the crash colours
/datum/bounty_chrome/cascade/proc/clear_effects()
	if(!owner)
		return
	owner.remove_movespeed_modifier(/datum/movespeed_modifier/bounty_cascade)
	owner.remove_movespeed_modifier(/datum/movespeed_modifier/bounty_cascade_crash)
	set_blows(1)
	cyberware_unregister_dodge_source(owner, BOUNTY_CASCADE_DODGE_KEY)
	UnregisterSignal(owner, list(COMSIG_MOVABLE_MOVED, COMSIG_MOVABLE_PRE_MOVE, COMSIG_MOB_APPLY_DAMAGE_MODIFIERS))
	owner.remove_filter(list(BOUNTY_CASCADE_GLOW_FILTER, BOUNTY_CASCADE_CRASH_FILTER))

/// An EMP in the spin-up or the window crashes it at once and re-arms the whole cooldown, as it does the player's
/datum/bounty_chrome/cascade/on_emp(severity)
	if(phase != BOUNTY_CASCADE_SPINUP && phase != BOUNTY_CASCADE_WINDOW)
		return
	start_crash()
	next_surge_at = max(next_surge_at, world.time + BOUNTY_CASCADE_COOLDOWN)

/datum/bounty_chrome/cascade/on_reboot()
	next_surge_at = max(next_surge_at, world.time + BOUNTY_CASCADE_REBOOT_DELAY)

/datum/bounty_chrome/cascade/on_downed()
	end_surge()

/datum/bounty_chrome/cascade/on_death()
	end_surge()

/datum/bounty_chrome/cascade/examine_line()
	if(!online())
		return "The chrome at the base of %THEIR neck is dark."
	switch(phase)
		if(BOUNTY_CASCADE_SPINUP, BOUNTY_CASCADE_WINDOW)
			return "The chrome at the base of %THEIR neck burns violet."
		if(BOUNTY_CASCADE_CRASH)
			return "The chrome at the base of %THEIR neck ticks as it cools."
	return "Chrome ports glint at the base of %THEIR neck."

/// The window's pace, on top of the AI's own: a fighter's steps (RUN_DELAY 1.5 apart) come twice as fast, so it runs a hunter down or leaves them behind. Short of the player lattice's -1.
/datum/movespeed_modifier/bounty_cascade
	multiplicative_slowdown = -0.75

/// The crash's pace, on top of the AI's own: a fighter is down to a walking person's pace (WALK_DELAY 4)
/datum/movespeed_modifier/bounty_cascade_crash
	multiplicative_slowdown = 2.5

/**
 * A Cascade fighter's blow timing in a surge: /mob/living/changeNext_move() multiplies the time
 * between blows by blow_mult. Put on and taken off by /datum/bounty_chrome/cascade only.
 */
/datum/status_effect/bounty_cascade
	id = "bounty_cascade"
	duration = STATUS_EFFECT_PERMANENT
	tick_interval = STATUS_EFFECT_NO_TICK
	alert_type = null
	/// Time between blows multiplied by this
	var/blow_mult = 1

/datum/status_effect/bounty_cascade/nextmove_modifier()
	return blow_mult

#undef BOUNTY_CASCADE_IDLE
#undef BOUNTY_CASCADE_SPINUP
#undef BOUNTY_CASCADE_WINDOW
#undef BOUNTY_CASCADE_CRASH
#undef BOUNTY_CASCADE_SPINUP_TIME
#undef BOUNTY_CASCADE_WINDOW_TIME
#undef BOUNTY_CASCADE_CRASH_TIME
#undef BOUNTY_CASCADE_COOLDOWN
#undef BOUNTY_CASCADE_FIRST_MIN
#undef BOUNTY_CASCADE_FIRST_MAX
#undef BOUNTY_CASCADE_REBOOT_DELAY
#undef BOUNTY_CASCADE_RANGE
#undef BOUNTY_CASCADE_DODGE
#undef BOUNTY_CASCADE_WINDOW_BLOWS
#undef BOUNTY_CASCADE_CRASH_BLOWS
#undef BOUNTY_CASCADE_WINDOW_SHOTS
#undef BOUNTY_CASCADE_CRASH_STAMINA_MULT
#undef BOUNTY_CASCADE_CRASH_STAMINA
#undef BOUNTY_CASCADE_PULSE
#undef BOUNTY_CASCADE_STRAFE_GAP
#undef BOUNTY_CASCADE_SHIMMER_MIN
#undef BOUNTY_CASCADE_SHIMMER_MAX
#undef BOUNTY_CASCADE_SHIMMER_SLIDE
#undef BOUNTY_CASCADE_HUE_STEP
#undef BOUNTY_CASCADE_DODGE_KEY
#undef BOUNTY_CASCADE_GLOW_FILTER
#undef BOUNTY_CASCADE_CRASH_FILTER
#undef BOUNTY_CASCADE_GLOW_COLOR
#undef BOUNTY_CASCADE_FLASH_COLOR
