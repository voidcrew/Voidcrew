/**
 * # What a Sandevistan sounds like
 *
 * The user hears his own surge come on, a loop for as long as his slow-mo runs, and the slow-mo ending. The
 * loop climbs in pitch as the slow-mo runs toward its end (sandy_slowmo_progress()).
 * Those go to him alone, straight to his client: never slowed by his own
 * slow-mo (ware_sandy_senses.dm slows sounds in playsound_local) and never recorded for its replay (ware_sandy_replay.dm
 * records playsound()), which is the outside view. An NPC surger has no client and gets none of them.
 *
 * Everyone else near hears a short snap from the surger's tile as he surges and as he bursts off. A crewmate slowed in
 * his slow-mo is someone else too; in a shared slow-mo each member hears the other's snap and never his own. The
 * replay plays the same snap to its viewers when the replayed surger bursts off after a pause
 * (sandy_replay/proc/surger_frame()).
 */

/// The user's own cues.
#define SANDY_SOUND_ACTIVATION_VOLUME 70
#define SANDY_SOUND_LOOP_VOLUME 50
#define SANDY_SOUND_DEACTIVATE_VOLUME 60

#ifdef UNIT_TESTS
/// Every Sandevistan cue sent, as list(mob, /sound), whether or not the mob has a client.
GLOBAL_LIST_EMPTY(sandy_cues_sent)
#endif

/datum/status_effect/cyberware_cascade_window
	/// The user's slow-mo sounds are on: the loop plays (sandy_sound_sync()).
	var/slowmo_sounding = FALSE
	/// The channel the loop plays on, reserved while it does.
	var/loop_channel
	/// The ckey whose client the loop went to, to stop it wherever that client is now.
	var/loop_ckey
	/// world.time of the last external cue.
	var/last_burst_cue = 0
	/// How far the slow-mo has run toward its end, 0 to 1, as last read (sandy_slowmo_progress()).
	var/pitch_progress = 0
	/// world.time pitch_progress was last read.
	var/pitch_progress_at = 0
	/// The timer that updates the playing loop's pitch.
	var/pitch_timer

/datum/sound_effect/sandevistan_external
	key = SANDEVISTAN_EXTERNAL_SOUND
	file_paths = list(
		'voidcrew/sound/cyberware/sandevistan_external_1.ogg',
		'voidcrew/sound/cyberware/sandevistan_external_2.ogg',
		'voidcrew/sound/cyberware/sandevistan_external_3.ogg',
	)

/// A cue as it goes out: `file` at `volume`, its pitch moved by up to `spread` hundredths.
/proc/sandy_cue(file, volume, spread = 0, channel = 0)
	var/sound/cue = sound(file)
	cue.volume = volume
	cue.channel = channel
	cue.wait = 0
	if(spread)
		cue.frequency = rand(100 - spread, 100 + spread) / 100
	return cue

/// The frequency multiplier for a slow-mo `progress` (0 to 1) of the way to its end.
/proc/sandy_pitch_for(progress)
	progress = clamp(progress, 0, 1)
	return 1 + (SANDEVISTAN_PITCH_END - 1) * progress * progress

/// Sends `cue` to `listener` alone.
/proc/sandy_cue_send(mob/listener, sound/cue)
#ifdef UNIT_TESTS
	GLOB.sandy_cues_sent += list(list(listener, cue))
#endif
	if(listener?.client)
		SEND_SOUND(listener, cue)

/**
 * The snap, from `surger`'s tile, to everyone who would hear a sound there but him, placed and faded as playsound()
 * does (sandy_replay_sound_for()). Not recorded for a replay: the replay plays its own.
 */
/proc/sandy_external_cue(mob/living/surger)
	var/turf/source = get_turf(surger)
	if(!source)
		return
	var/frequency = rand(100 - SANDEVISTAN_EXTERNAL_SPREAD, 100 + SANDEVISTAN_EXTERNAL_SPREAD) / 100
	var/list/listeners = get_hearers_in_range(SOUND_RANGE, source, RECURSIVE_CONTENTS_CLIENT_MOBS)
#ifdef UNIT_TESTS
	listeners |= get_hearers_in_range(SOUND_RANGE, source) // test bodies have no clients
#endif
	var/datum/region = map_region_for_turf(source)
	for(var/mob/listener in listeners)
		if(listener == surger)
			continue
		var/turf/there = get_turf(listener)
		if(!there || (region && there.z == source.z && map_region_excludes_turf(region, there)))
			continue
		var/sound/heard = sandy_replay_sound_for(listener, there, source, SANDEVISTAN_EXTERNAL_SOUND, SANDEVISTAN_EXTERNAL_VOLUME, TRUE, 0, SOUND_FALLOFF_EXPONENT, frequency, TRUE, TRUE, SOUND_DEFAULT_FALLOFF_DISTANCE, TRUE)
		if(heard && (!listener.client || listener.can_hear()))
			sandy_cue_send(listener, heard)

/// The surge comes on: the user hears it start, everyone else the snap.
/datum/status_effect/cyberware_cascade_window/proc/sandy_surge_sounds()
	last_burst_cue = world.time
	if(owner.ckey)
		sandy_cue_send(owner, sandy_cue(SANDEVISTAN_ACTIVATION_SOUND, SANDY_SOUND_ACTIVATION_VOLUME))
	sandy_external_cue(owner)

/**
 * A step, `step_time` after the last one. A forced move (thrown, pulled, carried) is never a burst. Everyone else
 * hears the snap on the first step after standing still, and then every SANDEVISTAN_BURST_GAP while he keeps moving.
 */
/datum/status_effect/cyberware_cascade_window/proc/sandy_step_sounds(step_time, forced)
	if(forced)
		return
	if(world.time - last_burst_cue < SANDEVISTAN_BURST_GAP)
		return
	last_burst_cue = world.time
	sandy_external_cue(owner)

/**
 * Starts the user's slow-mo sounds when his slow-mo has started, and ends them when it has ended. Call wherever
 * `time_stop` is set or cleared. `off` ends them whatever, and `quiet` without the closing cue (logout, death).
 */
/datum/status_effect/cyberware_cascade_window/proc/sandy_sound_sync(off = FALSE, quiet = FALSE)
	var/on = !off && time_stop && !QDELETED(owner) && owner.ckey && owner.stat != DEAD
	if(on && !slowmo_sounding)
		slowmo_sounding = TRUE
		loop_ckey = owner.ckey
		pitch_progress = 0
		pitch_progress_at = world.time
		RegisterSignal(owner, COMSIG_MOB_LOGOUT, PROC_REF(sandy_sound_logout))
		loop_channel = SSsounds.reserve_sound_channel(src)
		if(!loop_channel)
			return // no channel to stop it on: no loop
		var/sound/loop = sandy_cue(SANDEVISTAN_LOOP_SOUND, SANDY_SOUND_LOOP_VOLUME, channel = loop_channel)
		loop.repeat = TRUE
		loop.frequency = sandy_pitch_for(sandy_slowmo_progress())
		sandy_cue_send(owner, loop)
		pitch_timer = addtimer(CALLBACK(src, PROC_REF(sandy_pitch_update)), SANDEVISTAN_PITCH_UPDATE, TIMER_LOOP | TIMER_STOPPABLE | TIMER_DELETE_ME)
		return
	if(on || !slowmo_sounding)
		return
	slowmo_sounding = FALSE
	deltimer(pitch_timer)
	pitch_timer = null
	if(!QDELETED(owner))
		UnregisterSignal(owner, COMSIG_MOB_LOGOUT)
	var/mob/listener = sandy_loop_listener()
	if(loop_channel)
		var/sound/stop = sound(null)
		stop.channel = loop_channel
		sandy_cue_send(listener, stop)
		SSsounds.free_sound_channel(loop_channel)
		loop_channel = null
	loop_ckey = null
	if(!quiet && !QDELETED(owner) && listener == owner && owner.stat != DEAD)
		sandy_cue_send(owner, sandy_cue(SANDEVISTAN_DEACTIVATE_SOUND, SANDY_SOUND_DEACTIVATE_VOLUME))

/// Whoever has the client the loop went to, wherever it is now.
/datum/status_effect/cyberware_cascade_window/proc/sandy_loop_listener()
	var/client/heard_by = GLOB.directory[loop_ckey]
	. = heard_by?.mob
#ifdef UNIT_TESTS
	. ||= owner // test bodies have keys but no clients
#endif

/**
 * How far the slow-mo has run toward its end, 0 at its start and 1 at its end, read against its end as it stands now
 * (the field's ends_at: a hold or a shared slow-mo can move it later). It never goes down: when the end moves, what is
 * left climbs from where it stood to 1 at the new end.
 */
/datum/status_effect/cyberware_cascade_window/proc/sandy_slowmo_progress()
	var/ends = natural_end
	var/datum/proximity_monitor/advanced/timestop/sandevistan/field = time_stop?.chronofield
	if(field && field.ends_at != INFINITY)
		ends = field.ends_at
	var/now = world.time
	if(now <= pitch_progress_at)
		return pitch_progress
	if(ends <= now)
		pitch_progress = 1
	else
		pitch_progress = min(1, pitch_progress + (1 - pitch_progress) * (now - pitch_progress_at) / (ends - pitch_progress_at))
	pitch_progress_at = now
	return pitch_progress

/// Every SANDEVISTAN_PITCH_UPDATE while the loop plays: its pitch follows the slow-mo toward its end, without restarting.
/datum/status_effect/cyberware_cascade_window/proc/sandy_pitch_update()
	if(!slowmo_sounding || !loop_channel)
		deltimer(pitch_timer)
		pitch_timer = null
		return
	var/sound/update = sound(SANDEVISTAN_LOOP_SOUND, TRUE, 0, loop_channel, SANDY_SOUND_LOOP_VOLUME)
	update.frequency = sandy_pitch_for(sandy_slowmo_progress())
	update.status = SOUND_UPDATE
	sandy_cue_send(sandy_loop_listener(), update)

/// Signal proc for [COMSIG_MOB_LOGOUT]: the loop stops with him, wherever his client goes.
/datum/status_effect/cyberware_cascade_window/proc/sandy_sound_logout(datum/source)
	SIGNAL_HANDLER
	sandy_sound_sync(off = TRUE, quiet = TRUE)

#undef SANDY_SOUND_ACTIVATION_VOLUME
#undef SANDY_SOUND_LOOP_VOLUME
#undef SANDY_SOUND_DEACTIVATE_VOLUME
