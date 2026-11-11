/**
 * # The Cascade line's time dilation
 *
 * When a Cascade-line surge (ware_legend.dm, ware_line_sandy.dm) opens and no other player is within
 * SANDY_STOP_WITNESS_RANGE tiles, the world around the user slows down:
 *
 *   model        freeze  then slow-mo
 *   street       -       50% for 2 s
 *   service      -       35% for 3 s
 *   Cascade T4   1 s     20% for 3 s
 *
 * The rest of the window then runs as normal, then the crash. With another player near, the surge is the
 * plain one. Only a player's surge does this (the user needs a ckey): an NPC criminal's lattice never does.
 *
 * Built on tg's time stop field (code/datums/proximity_monitor/fields/timestop.dm), hosted on the user so
 * it follows them. Anything it touches stays slowed (or frozen) until the effect ends, even once the user
 * walks off. The field re-checks for players every tick and ends at once if one comes in.
 *
 * No shortcuts on people. A frozen mob gets tg's own TRAIT_IMMOBILIZED, TRAIT_HANDS_BLOCKED and
 * TRAIT_AI_PAUSED, never a fake state or a Stun. A slowed mob moves under a movespeed modifier, and every
 * tick the field pushes its timing deadlines back by the time it lost (next_move, ability cooldowns, AI
 * behaviour cooldowns and the blackboard deadlines listed in dilated_blackboard_keys(), ranged cooldowns).
 * Guns scale their fire and burst delays for a slowed shooter (VOIDCREW EDIT in gun.dm). Frozen and slowed
 * bodies take damage, wounds and bleeding through tg as normal. Not covered: do_after progress bars and
 * burst timers queued before the slow-mo started.
 *
 * Bosses (a finisher user, or a boss-rank human NPC) are held for SANDY_STOP_BOSS_HOLD at most.
 *
 * Look: affected things get a grey-green tint instead of tg's inversion. Floor items, blood decals and the
 * user are never touched, so they keep their colour, and so do the user's own shots. Shots the user fires
 * while the world is frozen fly a tile, hang there, and go on when it starts moving again.
 */

/// Another player within this many tiles of the user means no dilation.
#define SANDY_STOP_WITNESS_RANGE 11
/// Radius of the field around the user (a widescreen view is 9 tiles to each side).
#define SANDY_STOP_FIELD_RANGE 9
/// How long a boss stays frozen or slowed before it shrugs the field off.
#define SANDY_STOP_BOSS_HOLD (1 SECONDS)
/// How far, in pixels, the user's own shots fly before they hang in a frozen world.
#define SANDY_STOP_SHOT_HANG 32
/// Trait source for everything the dilation applies.
#define SANDY_STOP_TRAIT "sandevistan_time_stop"
/// Filter name of the user's edge glow.
#define SANDY_STOP_OUTLINE "sandy_time_stop_outline"

/// Every atom the dilation has hold of, to its field.
GLOBAL_LIST_EMPTY(cyberware_time_dilated)

/// How fast time runs for `thing`: 1 normally, 0 frozen, in between in slow-mo.
/proc/cyberware_time_scale(atom/thing)
	if(isnull(thing))
		return 1
	var/datum/proximity_monitor/advanced/timestop/sandevistan/field = GLOB.cyberware_time_dilated[thing]
	return field ? field.time_scale : 1

/// Whether a player other than `user` is within `range` tiles: any living body with a ckey, connected or not.
/proc/cyberware_time_stop_witnessed(mob/living/user, range = SANDY_STOP_WITNESS_RANGE)
	var/turf/here = get_turf(user)
	if(!here)
		return TRUE
	for(var/atom/movable/found as anything in SSspatial_grid.orthogonal_range_search(here, SPATIAL_GRID_CONTENTS_TYPE_HEARING, range))
		if(found == user)
			continue
		if(isliving(found))
			var/mob/living/body = found
			if(body.ckey)
				return TRUE
			continue
		if(ismob(found) || isitem(found)) // ghosts and camera eyes don't count; radios hold nobody
			continue
		// a locker or a mech with a player in it
		for(var/mob/living/inside in found.get_all_contents())
			if(inside != user && inside.ckey)
				return TRUE
	return FALSE

/// Whether `victim` is a boss: anything with a finisher, or a boss-rank human NPC.
/proc/cyberware_time_stop_boss(mob/living/victim)
	if(victim.GetComponent(/datum/component/hv_finisher_user))
		return TRUE
	if(istype(victim, /mob/living/carbon/human/npc))
		var/mob/living/carbon/human/npc/person = victim
		return person.npc_rank >= HUMAN_NPC_RANK_BOSS
	return FALSE

/// The grey-green wash on dilated things.
/proc/cyberware_time_stop_tint()
	var/static/list/tint = list(0.26,0.28,0.27, 0.52,0.56,0.54, 0.10,0.11,0.105, 0.02,0.05,0.04)
	return tint

/// Flattens a sprite to luminance and paints it the dilation's green (#5AFF96).
/proc/cyberware_time_stop_green()
	var/static/list/green
	if(!green)
		var/red = 90 / 255
		var/grn = 1
		var/blue = 150 / 255
		// gain + lift = 1, so white maps to the green itself and black to a dim green
		var/gain = 0.65
		var/lift = 0.35
		green = list(
			0.3 * gain * red, 0.3 * gain * grn, 0.3 * gain * blue,
			0.59 * gain * red, 0.59 * gain * grn, 0.59 * gain * blue,
			0.11 * gain * red, 0.11 * gain * grn, 0.11 * gain * blue,
			lift * red, lift * grn, lift * blue,
		)
	return green

/// Blackboard keys holding world.time deadlines that slow down with their owner.
/proc/dilated_blackboard_keys()
	var/static/list/keys = list(
		BB_HUMAN_NPC_NEXT_SHOT,
		BB_HUMAN_NPC_RELOAD_UNTIL,
		BB_HUMAN_NPC_ARMING_RETRY_AT,
		BB_HUMAN_NPC_NEXT_TREAT,
		BB_HUMAN_NPC_FLEE_UNTIL,
		BB_BOUNTY_NEXT_STEP_AT,
		BB_BOUNTY_BACKSTEP_AT,
		BB_BOUNTY_BOSS_HUNT_AT,
		BB_BOUNTY_BOSS_RELOAD_UNTIL,
		BB_BASIC_MOB_REINFORCEMENTS_COOLDOWN,
		// defined and undefined inside their own modules
		"convict_hit_until",
		"convict_lost_since",
		"pirate_windup_until",
		"pirate_breach_started",
		"pirate_no_path_at",
		"pirate_breach_progress_at",
	)
	return keys

/datum/movespeed_modifier/cyberware_dilation
	variable = TRUE

// =========================================================================
// THE EFFECT
// =========================================================================

/// Lives as long as the dilation, holds the field on the user, and ends it when deleted.
/obj/effect/timestop/sandevistan
	name = "stopped moment"
	desc = null
	hidden = TRUE
	alpha = 0
	freezerange = SANDY_STOP_FIELD_RANGE
	/// Whose dilation this is. The field is hosted on them.
	var/mob/living/user
	/// How long the world is frozen first.
	var/freeze_time = 0
	/// How fast the world runs after that.
	var/slow_scale = 1

/// `immune_atoms` must be list(user). `time` is the whole effect; `freeze` of it is frozen, the rest at `scale`.
/obj/effect/timestop/sandevistan/Initialize(mapload, radius, time, list/immune_atoms, start = TRUE, silent = TRUE, freeze = 0, scale = 1)
	if(length(immune_atoms))
		user = immune_atoms[1]
	freeze_time = freeze
	slow_scale = scale
	return ..(mapload, radius, time, immune_atoms, start, TRUE)

/obj/effect/timestop/sandevistan/Destroy()
	user = null
	return ..()

/obj/effect/timestop/sandevistan/timestop()
	target = get_turf(src)
	QDEL_IN(src, duration)
	if(QDELETED(user))
		return
	var/datum/proximity_monitor/advanced/timestop/sandevistan/field = new(user, freezerange, TRUE, immune, antimagic_flags, FALSE, freeze_time > 0 ? 0 : slow_scale)
	field.stopper = src
	field.slow_scale = slow_scale
	if(freeze_time > 0)
		field.thaw_at = world.time + freeze_time
	chronofield = field

// =========================================================================
// THE FIELD
// =========================================================================

/datum/proximity_monitor/advanced/timestop/sandevistan
	/// The effect that owns this field. Deleting it ends the dilation.
	var/obj/effect/timestop/sandevistan/stopper
	/// How fast time runs in here right now. 0 is frozen.
	var/time_scale = 0
	/// The slow-mo scale the field drops to once the freeze ends.
	var/slow_scale = 1
	/// world.time the freeze ends and slow-mo starts, or 0.
	var/thaw_at = 0
	/// world.time of the last tick, for how much time each tick dilated.
	var/last_tick = 0
	/// The field's own clock. A timer, not SSfastprocess, which sleeps outside RUNLEVEL_GAME.
	var/tick_timer
	/// Mobs in hand.
	var/list/held_mobs = list()
	/// Projectiles in hand, to their own speed.
	var/list/held_shots = list()
	/// Thrown things in hand.
	var/list/held_throws = list()
	/// The user's own shots: never tinted.
	var/list/user_shots = list()
	/// Bosses in hand, to the world.time they shrug the field off.
	var/list/boss_holds = list()
	/// Bosses that already shrugged it off. The field leaves them be.
	var/list/released = list()

/datum/proximity_monitor/advanced/timestop/sandevistan/New(atom/_host, range, _ignore_if_not_on_turf = TRUE, list/immune, antimagic_flags, channelled, start_scale = 0)
	time_scale = start_scale
	last_tick = world.time
	. = ..()
	STOP_PROCESSING(SSfastprocess, src) // tick() runs on tick_timer instead
	tick_timer = addtimer(CALLBACK(src, PROC_REF(tick)), 0.2 SECONDS, TIMER_LOOP | TIMER_STOPPABLE | TIMER_DELETE_ME)
	RegisterSignal(host, COMSIG_PROJECTILE_FIRER_BEFORE_FIRE, PROC_REF(on_user_fire))

/datum/proximity_monitor/advanced/timestop/sandevistan/Destroy()
	deltimer(tick_timer)
	tick_timer = null
	if(host)
		UnregisterSignal(host, COMSIG_PROJECTILE_FIRER_BEFORE_FIRE)
	stopper = null
	. = ..() // unfreeze_all() lets everything go
	released.Cut()

/datum/proximity_monitor/advanced/timestop/sandevistan/freeze_atom(atom/movable/A)
	if(!istype(A) || GLOB.cyberware_time_dilated[A] || global_frozen_atoms[A] || released[A] || immune[A])
		return FALSE
	if(ismob(A))
		var/mob/M = A
		if(M.can_block_magic(antimagic_flags))
			immune[A] = TRUE
			return FALSE
	var/tint = TRUE
	if(isliving(A))
		hold_mob(A)
	else if(isprojectile(A))
		var/obj/projectile/shot = A
		if(shot.firer && immune[shot.firer])
			if(time_scale <= 0) // hang_shot takes these
				return FALSE
			user_shots[shot] = TRUE
			tint = FALSE
			escape_the_negative_zone(shot) // in case it was tinted before it had a firer
		hold_shot(shot)
	else if((ismachinery(A) && !istype(A, /obj/machinery/light)) || isstructure(A) || ismecha(A))
		frozen_structures += A // looks only
	else if(!A.throwing)
		return FALSE
	if(A.throwing)
		held_throws[A] = TRUE
		if(time_scale <= 0)
			A.throwing.paused = TRUE
	GLOB.cyberware_time_dilated[A] = src
	frozen_things[A] = TRUE
	if(tint)
		into_the_negative_zone(A)
	SEND_SIGNAL(A, COMSIG_ATOM_TIMESTOP_FREEZE, src)
	return TRUE

/datum/proximity_monitor/advanced/timestop/sandevistan/unfreeze_all()
	for(var/atom/movable/thing as anything in frozen_things)
		unfreeze_atom(thing)
	for(var/turf/ground as anything in frozen_turfs)
		unfreeze_turf(ground)
	frozen_turfs.Cut()

/datum/proximity_monitor/advanced/timestop/sandevistan/unfreeze_atom(atom/movable/A)
	if(held_mobs[A])
		let_go_mob(A)
	if(held_shots[A])
		let_go_shot(A)
	if(held_throws[A])
		var/datum/thrownthing/throw_datum = A.throwing
		if(throw_datum)
			throw_datum.paused = FALSE
		held_throws -= A
	frozen_structures -= A
	user_shots -= A
	escape_the_negative_zone(A)
	frozen_things -= A
	GLOB.cyberware_time_dilated -= A
	SEND_SIGNAL(A, COMSIG_ATOM_TIMESTOP_UNFREEZE, src)

// ----- mobs -----

/// Takes hold of a mob: frozen or slowed, whichever the field is doing.
/datum/proximity_monitor/advanced/timestop/sandevistan/proc/hold_mob(mob/living/victim)
	held_mobs[victim] = TRUE
	if(time_scale <= 0)
		freeze_mob(victim)
	else
		slow_mob(victim)
	if(cyberware_time_stop_boss(victim))
		boss_holds[victim] = world.time + SANDY_STOP_BOSS_HOLD

/datum/proximity_monitor/advanced/timestop/sandevistan/proc/let_go_mob(mob/living/victim)
	unfreeze_mob(victim)
	unslow_mob(victim)
	held_mobs -= victim
	boss_holds -= victim

/datum/proximity_monitor/advanced/timestop/sandevistan/freeze_mob(mob/living/victim)
	frozen_mobs[victim] = TRUE
	victim.add_traits(list(TRAIT_IMMOBILIZED, TRAIT_HANDS_BLOCKED, TRAIT_AI_PAUSED, TRAIT_MUTE, TRAIT_EMOTEMUTE), SANDY_STOP_TRAIT)
	GLOB.move_manager.stop_looping(victim)
	if(isanimal(victim)) // the old simple mob AI doesn't read TRAIT_AI_PAUSED
		var/mob/living/simple_animal/animal_victim = victim
		animal_victim.toggle_ai(AI_OFF)

/datum/proximity_monitor/advanced/timestop/sandevistan/unfreeze_mob(mob/living/victim)
	if(!frozen_mobs[victim])
		return
	frozen_mobs -= victim
	victim.remove_traits(list(TRAIT_IMMOBILIZED, TRAIT_HANDS_BLOCKED, TRAIT_AI_PAUSED, TRAIT_MUTE, TRAIT_EMOTEMUTE), SANDY_STOP_TRAIT)
	if(isanimal(victim))
		var/mob/living/simple_animal/animal_victim = victim
		animal_victim.toggle_ai(initial(animal_victim.AIStatus))

/// Slows a mob's walk to the field's pace. Its timers are pushed back every tick in process().
/datum/proximity_monitor/advanced/timestop/sandevistan/proc/slow_mob(mob/living/victim)
	var/base_delay = max(victim.cached_multiplicative_slowdown, 1)
	victim.add_or_update_variable_movespeed_modifier(/datum/movespeed_modifier/cyberware_dilation, multiplicative_slowdown = base_delay * (1 / time_scale - 1))
	if(istype(victim, /mob/living/simple_animal/hostile))
		var/mob/living/simple_animal/hostile/animal_victim = victim
		animal_victim.move_to_delay = initial(animal_victim.move_to_delay) / time_scale

/datum/proximity_monitor/advanced/timestop/sandevistan/proc/unslow_mob(mob/living/victim)
	victim.remove_movespeed_modifier(/datum/movespeed_modifier/cyberware_dilation)
	if(istype(victim, /mob/living/simple_animal/hostile))
		var/mob/living/simple_animal/hostile/animal_victim = victim
		animal_victim.move_to_delay = initial(animal_victim.move_to_delay)

/// Pushes every timing deadline `victim` has that hasn't passed yet back by `push` deciseconds.
/datum/proximity_monitor/advanced/timestop/sandevistan/proc/push_deadlines(mob/living/victim, push)
	var/now = world.time
	if(victim.next_move > now)
		victim.next_move += push
	for(var/datum/action/cooldown/ability in victim.actions)
		if(ability.next_use_time > now)
			ability.next_use_time += push
	var/datum/ai_controller/controller = victim.ai_controller
	if(controller)
		for(var/behavior in controller.behavior_cooldowns)
			if(controller.behavior_cooldowns[behavior] > now)
				controller.behavior_cooldowns[behavior] += push
		for(var/key in dilated_blackboard_keys())
			var/deadline = controller.blackboard[key]
			if(isnum(deadline) && deadline > now)
				controller.blackboard[key] = deadline + push
	var/datum/component/ranged_attacks/ranged = victim.GetComponent(/datum/component/ranged_attacks)
	if(ranged && ranged.fire_cooldown > now)
		ranged.fire_cooldown += push
	if(istype(victim, /mob/living/simple_animal/hostile))
		var/mob/living/simple_animal/hostile/animal_victim = victim
		if(animal_victim.ranged_cooldown > now)
			animal_victim.ranged_cooldown += push

// ----- projectiles -----

/datum/proximity_monitor/advanced/timestop/sandevistan/proc/hold_shot(obj/projectile/shot)
	held_shots[shot] = shot.speed
	if(time_scale <= 0)
		shot.paused = TRUE
	else
		shot.speed = held_shots[shot] * time_scale

/datum/proximity_monitor/advanced/timestop/sandevistan/proc/let_go_shot(obj/projectile/shot)
	shot.speed = held_shots[shot]
	shot.paused = FALSE
	held_shots -= shot

/// Signal proc for [COMSIG_PROJECTILE_FIRER_BEFORE_FIRE] on the user: watch the shot leave the barrel.
/datum/proximity_monitor/advanced/timestop/sandevistan/proc/on_user_fire(datum/source, obj/projectile/shot, atom/fired_from, atom/original)
	SIGNAL_HANDLER
	if(time_scale <= 0)
		RegisterSignal(shot, COMSIG_PROJECTILE_FIRE, PROC_REF(hang_shot))

/// Signal proc for [COMSIG_PROJECTILE_FIRE]: in a frozen world the user's shot flies a tile, then hangs.
/datum/proximity_monitor/advanced/timestop/sandevistan/proc/hang_shot(obj/projectile/shot)
	SIGNAL_HANDLER
	UnregisterSignal(shot, COMSIG_PROJECTILE_FIRE)
	if(QDELETED(shot) || shot.deletion_queued)
		return
	// A hitscan beam takes its first step itself once paused (process_hitscan) and stops there.
	if(!shot.hitscan)
		shot.process_movement(SANDY_STOP_SHOT_HANG)
		if(QDELETED(shot) || shot.deletion_queued)
			return
	user_shots[shot] = TRUE
	escape_the_negative_zone(shot) // in case it was tinted before it had a firer
	if(!held_shots[shot])
		hold_shot(shot)
	GLOB.cyberware_time_dilated[shot] = src
	frozen_things[shot] = TRUE
	RegisterSignal(shot, COMSIG_QDELETING, PROC_REF(held_gone))

/// Forgets a held thing that got deleted.
/datum/proximity_monitor/advanced/timestop/sandevistan/proc/held_gone(atom/movable/thing)
	SIGNAL_HANDLER
	held_shots -= thing
	user_shots -= thing
	frozen_things -= thing
	GLOB.cyberware_time_dilated -= thing

// ----- the clock -----

/// Moves the whole field to a new pace: frozen things start moving, slowed things change speed.
/datum/proximity_monitor/advanced/timestop/sandevistan/proc/set_time_scale(new_scale)
	time_scale = new_scale
	for(var/mob/living/victim as anything in held_mobs)
		unfreeze_mob(victim)
		if(time_scale <= 0)
			unslow_mob(victim)
			freeze_mob(victim)
		else
			slow_mob(victim)
	for(var/obj/projectile/shot as anything in held_shots)
		shot.paused = time_scale <= 0
		if(time_scale > 0)
			shot.speed = held_shots[shot] * time_scale
	for(var/atom/movable/thing as anything in held_throws)
		if(thing.throwing)
			thing.throwing.paused = time_scale <= 0

/datum/proximity_monitor/advanced/timestop/sandevistan/process()
	return PROCESS_KILL

/// Every 0.2 s: end if a player came in, push back the timers of everything held, let bosses go, end the freeze.
/datum/proximity_monitor/advanced/timestop/sandevistan/proc/tick()
	if(QDELETED(host) || cyberware_time_stop_witnessed(host))
		if(!QDELETED(stopper))
			qdel(stopper) // takes this field with it
		return
	var/elapsed = world.time - last_tick
	last_tick = world.time
	var/push = elapsed * (1 - time_scale)
	if(push > 0)
		for(var/mob/living/victim as anything in held_mobs)
			push_deadlines(victim, push)
		for(var/atom/movable/thing as anything in held_throws)
			var/datum/thrownthing/throw_datum = thing.throwing
			if(throw_datum && !throw_datum.paused)
				throw_datum.start_time += push
	for(var/mob/living/boss as anything in boss_holds.Copy())
		if(world.time < boss_holds[boss])
			continue
		unfreeze_atom(boss)
		released[boss] = TRUE
	if(thaw_at && world.time >= thaw_at)
		thaw_at = 0
		set_time_scale(slow_scale)

/datum/proximity_monitor/advanced/timestop/sandevistan/into_the_negative_zone(atom/A)
	A.add_atom_colour(cyberware_time_stop_tint(), TEMPORARY_COLOUR_PRIORITY)

// =========================================================================
// THE WINDOW'S SIDE
// =========================================================================

/datum/status_effect/cyberware_cascade_window
	/// How long the world is frozen if nobody else is near when the window opens. Copied from the lattice.
	var/dilation_freeze = 1 SECONDS
	/// How long slow-mo runs after the freeze.
	var/dilation_time = 3 SECONDS
	/// How fast the world runs in slow-mo.
	var/dilation_scale = 0.2
	/// The running dilation, if any.
	var/obj/effect/timestop/sandevistan/time_stop

/// Slows the world if the bearer is a player and nobody else is near. Called as the window opens.
/datum/status_effect/cyberware_cascade_window/proc/try_time_stop()
	if(dilation_freeze + dilation_time <= 0 || !owner.ckey || time_stop)
		return FALSE
	if(cyberware_time_stop_witnessed(owner))
		return FALSE
	var/turf/here = get_turf(owner)
	if(!here)
		return FALSE
	time_stop = new(here, SANDY_STOP_FIELD_RANGE, dilation_freeze + dilation_time, list(owner), TRUE, TRUE, dilation_freeze, dilation_scale)
	if(QDELETED(time_stop))
		time_stop = null
		return FALSE
	RegisterSignal(time_stop, COMSIG_QDELETING, PROC_REF(time_stop_over))
	owner.remove_client_colour(id) // the user sees the slowed world as it is
	owner.add_filter(SANDY_STOP_OUTLINE, 2, outline_filter(1, "#5AFF96D2"))
	return TRUE

/// Signal proc for [COMSIG_QDELETING] on the dilation: time runs normally and the rest of the window carries on.
/datum/status_effect/cyberware_cascade_window/proc/time_stop_over(datum/source)
	SIGNAL_HANDLER
	time_stop = null
	if(QDELETED(owner))
		return
	owner.remove_filter(SANDY_STOP_OUTLINE)
	owner.add_client_colour(colour_type, id)

/// Ends the dilation early (the window is closing).
/datum/status_effect/cyberware_cascade_window/proc/end_time_stop()
	if(!time_stop)
		return
	UnregisterSignal(time_stop, COMSIG_QDELETING)
	QDEL_NULL(time_stop)
	if(!QDELETED(owner))
		owner.remove_filter(SANDY_STOP_OUTLINE)

/// One afterimage while time is dilated: green, gone in 0.4 s. It sits on the user's own tile, shifted back to
/// where they were, so it sorts on their row and draws behind them in every facing.
/datum/status_effect/cyberware_cascade_window/proc/stopped_afterimage(turf/old_loc)
	var/turf/here = get_turf(owner)
	if(!here)
		return
	var/obj/effect/temp_visual/decoy/fading/cascade/stopped/image = new(here, owner, 0, afterimage_alpha)
	image.color = cyberware_time_stop_green()
	image.filters = null
	image.pixel_w = owner.pixel_w + (old_loc.x - here.x) * ICON_SIZE_X
	image.pixel_z = owner.pixel_z + (old_loc.y - here.y) * ICON_SIZE_Y
	image.layer = owner.layer - 0.01

/// The afterimage left while time is dilated.
/obj/effect/temp_visual/decoy/fading/cascade/stopped
	duration = 4

#undef SANDY_STOP_WITNESS_RANGE
#undef SANDY_STOP_FIELD_RANGE
#undef SANDY_STOP_BOSS_HOLD
#undef SANDY_STOP_SHOT_HANG
#undef SANDY_STOP_TRAIT
#undef SANDY_STOP_OUTLINE
