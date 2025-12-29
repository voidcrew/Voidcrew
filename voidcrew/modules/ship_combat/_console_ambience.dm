// Console Ambience System
// Plays occasional random sounds from a folder to add atmosphere
// Respects player volume preferences

/// A datum that plays random ambient sounds from a folder at random intervals
/datum/console_ambience
	/// The atom this sound originates from
	var/atom/source
	/// List of sound files to pick from
	var/list/sound_files
	/// Base volume of the sounds (0-100), scaled by player preference
	var/volume = 12
	/// How far the sound can be heard (in tiles)
	var/range = 4
	/// Minimum time between sounds (in deciseconds)
	var/min_interval = 1.5 MINUTES
	/// Maximum time between sounds (in deciseconds)
	var/max_interval = 5 MINUTES
	/// Whether the ambience is currently active
	var/active = FALSE
	/// Timer ID for the next sound
	var/next_sound_timer

/datum/console_ambience/New(atom/sound_source, list/sounds, vol = 12, hear_range = 4, min_time = 1.5 MINUTES, max_time = 5 MINUTES)
	source = sound_source
	sound_files = sounds
	volume = vol
	range = hear_range
	min_interval = min_time
	max_interval = max_time

	RegisterSignal(source, COMSIG_QDELETING, PROC_REF(on_source_deleted))

/datum/console_ambience/Destroy()
	stop()
	if(source)
		UnregisterSignal(source, COMSIG_QDELETING)
	source = null
	return ..()

/datum/console_ambience/proc/on_source_deleted(datum/src_datum)
	SIGNAL_HANDLER
	qdel(src)

/// Starts playing ambient sounds
/datum/console_ambience/proc/start()
	if(active)
		return
	active = TRUE
	schedule_next_sound()

/// Stops playing ambient sounds
/datum/console_ambience/proc/stop()
	if(!active)
		return
	active = FALSE
	if(next_sound_timer)
		deltimer(next_sound_timer)
		next_sound_timer = null

/// Schedules the next ambient sound
/datum/console_ambience/proc/schedule_next_sound()
	if(!active)
		return
	var/delay = rand(min_interval, max_interval)
	next_sound_timer = addtimer(CALLBACK(src, PROC_REF(play_ambient_sound)), delay, TIMER_STOPPABLE)

/// Plays a random ambient sound and schedules the next one
/datum/console_ambience/proc/play_ambient_sound()
	next_sound_timer = null
	if(!active || !source || QDELETED(source) || !length(sound_files))
		return

	// Pick a random sound
	var/sound_file = pick(sound_files)

	// Play to all nearby mobs who have the preference enabled
	for(var/mob/living/listener in range(range, source))
		if(!listener.client)
			continue
		// Skip deaf listeners
		if(HAS_TRAIT(listener, TRAIT_DEAF))
			continue
		// Check volume preference
		var/pref_volume = listener.client.prefs.read_preference(/datum/preference/numeric/volume/sound_ship_ambience_volume)
		if(!pref_volume)
			continue

		// Calculate actual volume
		var/actual_volume = volume * (pref_volume / 100)

		// Play the sound with positional audio
		var/turf/source_turf = get_turf(source)
		var/turf/listener_turf = get_turf(listener)
		if(source_turf && listener_turf && source_turf.z == listener_turf.z)
			var/sound/S = sound(sound_file)
			S.volume = actual_volume
			S.x = source_turf.x - listener_turf.x
			S.z = source_turf.y - listener_turf.y
			S.y = 0
			S.falloff = 1
			S.environment = SOUND_ENVIRONMENT_NONE
			S.channel = SSsounds.random_available_channel()
			SEND_SOUND(listener, S)

	// Schedule next sound
	schedule_next_sound()

/// Helper to get the standard console ambience sounds
/proc/get_console_ambience_sounds()
	return list(
		'voidcrew/sound/machines/ambiance/high_chirp_success.ogg',
		'voidcrew/sound/machines/ambiance/low_beeps.ogg',
		'voidcrew/sound/machines/ambiance/ping_pong.ogg',
		'voidcrew/sound/machines/ambiance/positive_chirp.ogg',
		'voidcrew/sound/machines/ambiance/processing.ogg',
		'voidcrew/sound/machines/ambiance/static_beeps.ogg',
	)
